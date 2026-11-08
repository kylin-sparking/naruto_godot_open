#!/usr/bin/env python3
"""数据可视化编辑器 —— 直接读写服务端热加载的 `editor_workspace/project.json`。

设计约束（与 `编辑` 那套 2.2.3 GM 后台保持一致）：
* 只写 overrides；基础值永远从 GameData 实时解码，不复制进项目文件。
* 每次写入先备份当前 project.json，再原子替换；revision +1 触发服务端热加载。
* 记录 id 与全局单例都走白名单；unknown 字段、删除基础字段、过深 JSON 一律拒绝。
* 绑定 127.0.0.1，读写接口要口令（`NARUTO_EDITOR_PASSWORD`，默认 123456）。

启动：
    python 开发工具/数据编辑器/服务.py --port 18691
"""
from __future__ import annotations

import argparse
import copy
import hmac
import json
import os
import re
import shutil
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, quote, unquote, urlsplit


PROJECT_ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = PROJECT_ROOT / "服务端" / "runtime" / "tools"
WORKSPACE = PROJECT_ROOT / "服务端" / "runtime" / "www" / "editor_workspace"
PROJECT_JSON = WORKSPACE / "project.json"
BACKUP_DIR = WORKSPACE / "backups"
STATIC_INDEX = Path(__file__).resolve().parent / "静态" / "index.html"
STATIC_TERRAIN = Path(__file__).resolve().parent / "静态" / "terrain.html"
NPC_TABLE = PROJECT_ROOT / "数据" / "NPC.json"

# ── 地形只读浏览：数据源与素材根 ─────────────────────────────────────────────
DATA_DIR = PROJECT_ROOT / "数据"
MAP_DATA_ROOT = DATA_DIR / "地图"
MAP_INDEX_PATH = DATA_DIR / "地图索引.json"
MAP_NAMES_PATH = DATA_DIR / "地图名.json"
MAP_ASSET_INDEX_PATH = DATA_DIR / "地图素材索引.json"
MAP_ASSET_ROOT = PROJECT_ROOT / "素材" / "地图"
BAKED_SCENE_ROOT = PROJECT_ROOT / "场景" / "生成"
BACKGROUND_MARKERS_PATH = DATA_DIR / "背景层标记.json"
TILE_DESCRIPTOR_Z_PATH = DATA_DIR / "地图块描述符z.json"
ASSET_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp"}
ASSET_CONTENT_TYPES = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".webp": "image/webp",
}

MAX_RECORD_BYTES = 256 * 1024
MAX_PATCH_BYTES = 128 * 1024
MAX_DEPTH = 12
MAX_BACKUPS = 100
ID_PATTERN = re.compile(r"^[0-9A-Za-z_.-]{1,64}$")
BACKUP_PATTERN = re.compile(r"^project-r\d+-\d{8}-\d{6}(?:-pre-restore)?\.json$")

# Import the real catalog so base values and names match the game server exactly.
# Point GM state elsewhere first: importing the server module constructs GM_STATE,
# which would otherwise rewrite the live `save/gm-state.json`.
os.environ.setdefault("NARUTO_GM_STATE_PATH", str(WORKSPACE / ".editor-gm-state.json"))
sys.path.insert(0, str(TOOLS_DIR))
import fake_flash_server as game  # noqa: E402

CATALOG = game.GAME_DATA_CATALOG
BALANCE_DEFAULTS = game.BALANCE_DEFAULTS
CASH_OVERRIDE_FIELDS = game.CASH_SHOP_OVERRIDE_FIELDS

_STORE_LOCK = threading.RLock()
_INDEX_CACHE: dict[str, list[dict[str, Any]]] = {}
_NPC_NAMES: dict[int, dict[str, str]] | None = None


# ---------------------------------------------------------------- helpers

def _deep_merge(base: Any, patch: Any) -> Any:
    return game.runtime_deep_merge(base, patch)


def _decode(raw: Any) -> Any:
    return CATALOG._decode_section(raw)


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return default


def _json_equal(left: Any, right: Any) -> bool:
    return json.dumps(left, sort_keys=True, ensure_ascii=False) == json.dumps(
        right, sort_keys=True, ensure_ascii=False
    )


def _depth(value: Any, level: int = 1) -> int:
    if isinstance(value, dict):
        return max([level] + [_depth(v, level + 1) for v in value.values()])
    if isinstance(value, list):
        return max([level] + [_depth(v, level + 1) for v in value])
    return level


# ---------------------------------------------------------------- terrain (read-only)
#
# 地形浏览只读：地图 JSON / 素材索引 / 素材图片都直接从工程里现读，不写任何文件。
# 坐标与叠放顺序必须和客户端一致，所以这里逐条照抄：
#   `脚本/地图/地图资源.gd find_asset/find_asset_directory`
#   `脚本/地图/地图块.gd` 瓦片文件名与位置
#   `脚本/地图/地图物件.gd` 物件基名、帧文件、翻转位置
#   `脚本/调试/渲染配置.gd 物件z/瓦片z`
# 改了客户端那几条规则，这里要跟着改，否则编辑器里看到的位置会骗人。

PROJECT_ROOT_RESOLVED = PROJECT_ROOT.resolve()
LAYER_BAND = 512
OBJECT_SLOT = 128
TILE_SLOT = 128
TERRAIN_Z_ZERO = 64
BACK_ALIGN_MIN = (-812.0, -1068.0)

_JSON_CACHE: dict[str, tuple[float, int, Any]] = {}


def _load_json_file(path: Path, default: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return default


def _cached_json(path: Path, default: Any) -> Any:
    key = str(path)
    try:
        stat = path.stat()
    except OSError:
        return default
    hit = _JSON_CACHE.get(key)
    if hit is not None and hit[0] == stat.st_mtime and hit[1] == stat.st_size:
        return hit[2]
    value = _load_json_file(path, default)
    _JSON_CACHE[key] = (stat.st_mtime, stat.st_size, value)
    return value


def _map_folders() -> dict[str, str]:
    raw = _cached_json(MAP_INDEX_PATH, {})
    if not isinstance(raw, dict):
        return {}
    return {str(key): str(value) for key, value in raw.items()}


def _map_names() -> dict[str, str]:
    raw = _cached_json(MAP_NAMES_PATH, {})
    if not isinstance(raw, dict):
        return {}
    return {str(key): str(value) for key, value in raw.items()}


def _map_folder(map_id: str) -> str:
    folder = _map_folders().get(map_id)
    if not folder:
        raise ValueError("地图不存在")
    root = MAP_DATA_ROOT.resolve()
    path = (MAP_DATA_ROOT / folder).resolve()
    try:
        path.relative_to(root)
    except ValueError as error:
        raise ValueError("地图目录越界") from error
    if not path.is_dir():
        raise ValueError("地图数据目录缺失")
    return folder


def _repo_res_file(value: Any) -> Path | None:
    if not isinstance(value, str) or not value.startswith("res://"):
        return None
    path = (PROJECT_ROOT / value[len("res://"):]).resolve()
    return path if path.is_file() else None


def _repo_res_dir(value: Any) -> Path | None:
    if not isinstance(value, str) or not value.startswith("res://"):
        return None
    path = (PROJECT_ROOT / value[len("res://"):]).resolve()
    return path if path.is_dir() else None


def _res_path(path: Path) -> str:
    return "res://" + path.resolve().relative_to(PROJECT_ROOT_RESOLVED).as_posix()


def _asset_url(path: Path) -> str:
    relative = path.resolve().relative_to(PROJECT_ROOT_RESOLVED).as_posix()
    return "/api/terrain/asset?path=" + quote(relative, safe="")


def _map_asset_index() -> dict[str, str]:
    raw = _cached_json(MAP_ASSET_INDEX_PATH, {})
    if not isinstance(raw, dict):
        return {}
    return {str(key): str(value) for key, value in raw.items()}


def _find_map_asset(folder: str, category: str, file_name: str) -> Path | None:
    indexed = _repo_res_file(_map_asset_index().get(f"{category}/{Path(file_name).stem}"))
    if indexed is not None:
        return indexed
    local = MAP_ASSET_ROOT / folder / category / file_name
    return local.resolve() if local.is_file() else None


def _find_map_asset_dir(folder: str, category: str, directory_name: str) -> Path | None:
    indexed = _repo_res_dir(_map_asset_index().get(f"{category}/{directory_name}"))
    if indexed is not None:
        return indexed
    local = MAP_ASSET_ROOT / folder / category / directory_name
    return local.resolve() if local.is_dir() else None


def _clamp_terrain_z(value: Any) -> int:
    return max(-TERRAIN_Z_ZERO + 1, min(TERRAIN_Z_ZERO - 1, _safe_int(value, 0)))


def _object_z(layer: int, map_z: Any) -> int:
    return layer * LAYER_BAND + _clamp_terrain_z(map_z) + TERRAIN_Z_ZERO


def _tile_z(layer: int, map_z: Any) -> int:
    return layer * LAYER_BAND + OBJECT_SLOT + _clamp_terrain_z(map_z) + TERRAIN_Z_ZERO


def _tile_descriptor_z(tile_set_name: str, u: str, no: int) -> int:
    raw = _cached_json(TILE_DESCRIPTOR_Z_PATH, {})
    if not isinstance(raw, dict):
        return 0
    return _safe_int(raw.get(f"{tile_set_name}/{u}/{no}"), 0)


def _find_tile_asset(folder: str, tile_set_name: str, u: str, no: int) -> Path | None:
    for extension in ("jpg", "png"):
        path = _find_map_asset(folder, "地图块", f"Tile_{tile_set_name}_{u}_{no}.{extension}")
        if path is not None:
            return path
    return None


def _object_frames(folder: Path | None, base: str) -> list[Path]:
    found: dict[int, Path] = {}
    if folder is not None:
        try:
            entries = list(folder.iterdir())
        except OSError:
            entries = []
        for path in entries:
            if not path.is_file() or path.suffix.lower() not in ASSET_SUFFIXES:
                continue
            if not path.name.startswith(base + "_"):
                continue
            body = path.name[len(base) + 1:].rsplit(".", 1)[0]
            if body.isdigit():
                found.setdefault(int(body), path)
        if 0 not in found:
            for extension in ("png", "jpg", "jpeg"):
                single = folder / f"{base}.{extension}"
                if single.is_file():
                    found[0] = single
                    break
    return [found[key] for key in sorted(found)]


def _baked_scene(map_id: str) -> Path:
    return BAKED_SCENE_ROOT / f"地图_{map_id}_烘焙.tscn"


def _foothold_entries(data: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    foothold = data.get("foothold")
    if not isinstance(foothold, dict):
        return rows
    for layer_key, groups in foothold.items():
        if not isinstance(groups, dict):
            continue
        for group_key, segments in groups.items():
            if not isinstance(segments, dict):
                continue
            for segment_key, segment in segments.items():
                if not isinstance(segment, dict):
                    continue
                rows.append(
                    {
                        "layer": _safe_int(layer_key, 0),
                        "group": str(group_key),
                        "id": str(segment_key),
                        "x1": _safe_int(segment.get("x1"), 0),
                        "y1": _safe_int(segment.get("y1"), 0),
                        "x2": _safe_int(segment.get("x2"), 0),
                        "y2": _safe_int(segment.get("y2"), 0),
                        "prev": _safe_int(segment.get("prev"), 0),
                        "next": _safe_int(segment.get("next"), 0),
                    }
                )
    return rows


def _numbered_entries(raw: Any) -> list[dict[str, Any]]:
    if isinstance(raw, dict):
        pairs = raw.items()
    elif isinstance(raw, list):
        pairs = enumerate(raw)
    else:
        return []
    rows: list[dict[str, Any]] = []
    for key, value in pairs:
        if not isinstance(value, dict):
            continue
        row = dict(value)
        row["key"] = str(key)
        rows.append(row)
    return rows


def _background_entries(map_id: str, folder: str, data: dict[str, Any]) -> list[dict[str, Any]]:
    back = data.get("back")
    if not isinstance(back, dict):
        return []
    keys = sorted(back.keys(), key=lambda key: (_safe_int(key, 0), str(key)))
    b_s = "unknown"
    for key in keys:
        value = back[key]
        if isinstance(value, dict):
            b_s = str(value.get("bS", b_s))
            break
    markers_raw = _cached_json(BACKGROUND_MARKERS_PATH, {})
    marker_layers = ((markers_raw.get(map_id) or {}).get("层", [])) if isinstance(markers_raw, dict) else []
    markers: dict[str, dict[str, Any]] = {}
    if isinstance(marker_layers, list):
        for marker in marker_layers:
            if isinstance(marker, dict):
                markers[str(_safe_int(marker.get("键"), -1))] = marker

    rows: list[dict[str, Any]] = []
    for index, key in enumerate(keys):
        value = back[key]
        if not isinstance(value, dict):
            continue
        no = _safe_int(value.get("no"), -1)
        asset = None
        for extension in ("png", "jpg"):
            asset = _find_map_asset(folder, "背景", f"Back_{b_s}_back_{no}.{extension}")
            if asset is not None:
                break
        marker = markers.get(str(_safe_int(key, -1)), {})
        rows.append(
            {
                "key": str(key),
                "no": no,
                "bS": b_s,
                "type": _safe_int(value.get("type"), 0),
                "x": _safe_int(value.get("x"), 0),
                "y": _safe_int(value.get("y"), 0),
                "f": _safe_int(value.get("f"), 0),
                "a": _safe_int(value.get("a"), 255),
                "rx": _safe_int(value.get("rx"), 0),
                "ry": _safe_int(value.get("ry"), 0),
                "scale": float(value.get("scale", 1.0) or 1.0),
                "次序": _safe_int(marker.get("次序"), index),
                "类别": str(marker.get("类别", "")),
                "asset": _asset_url(asset) if asset is not None else None,
                "assetPath": _res_path(asset) if asset is not None else "",
            }
        )
    return rows


def _terrain_map_summary(map_id: str, folder: str) -> dict[str, Any]:
    data = _cached_json(MAP_DATA_ROOT / folder / "地图.json", {})
    tiles = _cached_json(MAP_DATA_ROOT / folder / "地图块.json", [])
    objects = _cached_json(MAP_DATA_ROOT / folder / "物件.json", [])
    if not isinstance(data, dict):
        data = {}
    if not isinstance(tiles, list):
        tiles = []
    if not isinstance(objects, list):
        objects = []
    baked = _baked_scene(map_id)
    return {
        "id": map_id,
        "name": _map_names().get(map_id, folder),
        "folder": folder,
        "tiles": len(tiles),
        "objects": len(objects),
        "footholds": len(_foothold_entries(data)),
        "portals": len(_numbered_entries(data.get("portal"))),
        "life": len(_numbered_entries(data.get("life"))),
        "backgrounds": len(_background_entries(map_id, folder, data)),
        "baked": baked.is_file(),
        "playableScene": _res_path(baked) if baked.is_file() else "res://场景/地图/地图场景.tscn",
    }


def _terrain_maps() -> dict[str, Any]:
    folders = _map_folders()
    rows = []
    for map_id in sorted(folders):
        folder = folders[map_id]
        if not (MAP_DATA_ROOT / folder).is_dir():
            continue
        rows.append(_terrain_map_summary(map_id, folder))
    return {"count": len(rows), "maps": rows}


def _terrain_map(map_id: str) -> dict[str, Any]:
    if not ID_PATTERN.match(map_id or ""):
        raise ValueError("地图 ID 无效")
    folder = _map_folder(map_id)
    data = _cached_json(MAP_DATA_ROOT / folder / "地图.json", {})
    tiles_raw = _cached_json(MAP_DATA_ROOT / folder / "地图块.json", [])
    objects_raw = _cached_json(MAP_DATA_ROOT / folder / "物件.json", [])
    if not isinstance(data, dict):
        data = {}
    if not isinstance(tiles_raw, list):
        tiles_raw = []
    if not isinstance(objects_raw, list):
        objects_raw = []

    tiles = []
    tiles_missing = 0
    for value in tiles_raw:
        if not isinstance(value, dict):
            continue
        tile_set_name = str(value.get("tS", ""))
        u = str(value.get("u", ""))
        no = _safe_int(value.get("no"), 0)
        layer = _safe_int(value.get("layer"), 0)
        descriptor_z = _tile_descriptor_z(tile_set_name, u, no)
        asset = _find_tile_asset(folder, tile_set_name, u, no)
        if asset is None:
            tiles_missing += 1
        tiles.append(
            {
                "layer": layer,
                "tS": tile_set_name,
                "u": u,
                "no": no,
                "x": _safe_int(value.get("x"), 0),
                "y": _safe_int(value.get("y"), 0),
                "zM": _safe_int(value.get("zM"), 0),
                "ox": _safe_int(value.get("ox"), 0),
                "oy": _safe_int(value.get("oy"), 0),
                "descriptorZ": descriptor_z,
                "z": _tile_z(layer, descriptor_z),
                "asset": _asset_url(asset) if asset is not None else None,
                "assetPath": _res_path(asset) if asset is not None else "",
            }
        )

    objects = []
    objects_missing = 0
    for value in objects_raw:
        if not isinstance(value, dict):
            continue
        base = "Obj_%s_%s_%s_%s" % (
            value.get("oS", ""),
            value.get("l0", ""),
            value.get("l1", ""),
            _safe_int(value.get("l2"), 0),
        )
        frames = _object_frames(_find_map_asset_dir(folder, "地图物件", base), base)
        if not frames:
            objects_missing += 1
        layer = _safe_int(value.get("layer"), 0)
        objects.append(
            {
                "layer": layer,
                "base": base,
                "x": _safe_int(value.get("x"), 0),
                "y": _safe_int(value.get("y"), 0),
                "z": _object_z(layer, value.get("z")),
                "mapZ": _safe_int(value.get("z"), 0),
                "flip": bool(value.get("flip", False)),
                "ox": _safe_int(value.get("ox"), 0),
                "oy": _safe_int(value.get("oy"), 0),
                "frames": [
                    {"path": _res_path(frame), "url": _asset_url(frame)} for frame in frames
                ],
            }
        )

    info = data.get("info")
    if not isinstance(info, dict):
        info = {}
    backgrounds = _background_entries(map_id, folder, data)
    minimap = _repo_res_file(_map_asset_index().get(f"小地图/Map_{map_id}_miniMap_canvas"))
    baked = _baked_scene(map_id)

    return {
        "id": map_id,
        "name": _map_names().get(map_id, folder),
        "folder": folder,
        "readOnly": True,
        "info": info,
        "vr": {
            "left": _safe_int(info.get("VRLeft"), 0),
            "top": _safe_int(info.get("VRTop"), 0),
            "right": _safe_int(info.get("VRRight"), 0),
            "bottom": _safe_int(info.get("VRBottom"), 0),
        },
        "tiles": tiles,
        "objects": objects,
        "footholds": _foothold_entries(data),
        "portals": _numbered_entries(data.get("portal")),
        "life": _numbered_entries(data.get("life")),
        "backgrounds": backgrounds,
        "minimap": (
            {"asset": _asset_url(minimap), "assetPath": _res_path(minimap)}
            if minimap is not None
            else None
        ),
        "baked": baked.is_file(),
        "bakedPath": _res_path(baked),
        "playableScene": _res_path(baked) if baked.is_file() else "res://场景/地图/地图场景.tscn",
        "missing": {
            "tiles": tiles_missing,
            "objects": objects_missing,
            "backgrounds": sum(1 for row in backgrounds if row["asset"] is None),
        },
    }


def _resolve_terrain_asset(relative: str) -> Path:
    """Only files under 素材/地图 may be served; rejects traversal and non-image files."""
    if not isinstance(relative, str) or not relative or "\x00" in relative:
        raise ValueError("素材路径无效")
    if os.path.isabs(relative) or relative.startswith("res://"):
        raise ValueError("素材路径无效")
    candidate = (PROJECT_ROOT / relative).resolve()
    try:
        candidate.relative_to(MAP_ASSET_ROOT.resolve())
    except ValueError as error:
        raise ValueError("素材路径不在 素材/地图 下") from error
    if not candidate.is_file():
        raise ValueError("素材不存在")
    if candidate.suffix.lower() not in ASSET_SUFFIXES:
        raise ValueError("不支持的素材类型")
    return candidate


def _read_project() -> dict[str, Any]:
    with _STORE_LOCK:
        try:
            payload = json.loads(PROJECT_JSON.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError):
            payload = {}
        if not isinstance(payload, dict):
            payload = {}
        overrides = payload.get("overrides")
        if not isinstance(overrides, dict):
            overrides = {}
        normalized = {
            "revision": max(0, _safe_int(payload.get("revision"), 0)),
            "overrides": {},
        }
        for entity, records in overrides.items():
            if not isinstance(entity, str) or not isinstance(records, dict):
                continue
            clean = {
                str(key): value
                for key, value in records.items()
                if isinstance(value, dict) and value.get("$deleted") is not True
            }
            if clean:
                normalized["overrides"][entity] = clean
        return normalized


def _override_of(project: dict[str, Any], entity: str, record_id: Any) -> dict[str, Any]:
    value = project["overrides"].get(entity, {}).get(str(record_id), {})
    return copy.deepcopy(value) if isinstance(value, dict) else {}


def _write_project(project: dict[str, Any]) -> str:
    """Back up the current file, then replace it atomically. Returns backup name."""
    with _STORE_LOCK:
        WORKSPACE.mkdir(parents=True, exist_ok=True)
        BACKUP_DIR.mkdir(parents=True, exist_ok=True)
        backup_name = ""
        if PROJECT_JSON.is_file():
            stamp = time.strftime("%Y%m%d-%H%M%S")
            backup_name = f"project-r{_read_project()['revision']}-{stamp}.json"
            # 用 copyfile 而不是 copy2：备份时间列要的是「这份备份何时生成」，不是源文件的修改时间。
            shutil.copyfile(PROJECT_JSON, BACKUP_DIR / backup_name)
        temporary = WORKSPACE / f".project.{os.getpid()}.{threading.get_ident()}.tmp"
        try:
            temporary.write_text(
                json.dumps(project, ensure_ascii=False, indent=1) + "\n",
                encoding="utf-8",
                newline="\n",
            )
            os.replace(temporary, PROJECT_JSON)
        finally:
            temporary.unlink(missing_ok=True)
        _prune_backups()
        return backup_name


def _prune_backups() -> None:
    backups = sorted(
        (path for path in BACKUP_DIR.glob("project-r*.json") if BACKUP_PATTERN.match(path.name)),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    for path in backups[MAX_BACKUPS:]:
        path.unlink(missing_ok=True)


def _diff(base: Any, edited: Any, path: tuple[str, ...] = ()) -> tuple[Any, list[str]]:
    """Return a minimal patch plus human-readable deletions of base fields."""
    if isinstance(base, dict) and isinstance(edited, dict):
        patch: dict[str, Any] = {}
        deletions: list[str] = []
        for key, value in edited.items():
            if key not in base:
                patch[key] = copy.deepcopy(value)
                continue
            child, child_deletions = _diff(base[key], value, path + (str(key),))
            deletions.extend(child_deletions)
            if child is not _NO_CHANGE:
                patch[key] = child
        for key in base:
            if key not in edited:
                deletions.append(".".join(path + (str(key),)))
        if not patch and not deletions:
            return _NO_CHANGE, []
        return patch, deletions
    if _json_equal(base, edited):
        return _NO_CHANGE, []
    return copy.deepcopy(edited), []


class _NoChange:
    pass


_NO_CHANGE = _NoChange()


def _validate_payload(value: Any, label: str) -> None:
    size = len(json.dumps(value, ensure_ascii=False).encode("utf-8"))
    if size > MAX_RECORD_BYTES:
        raise ValueError(f"{label} 超过 {MAX_RECORD_BYTES // 1024}KB")
    if _depth(value) > MAX_DEPTH:
        raise ValueError(f"{label} 嵌套超过 {MAX_DEPTH} 层")
    text = json.dumps(value, ensure_ascii=False)
    if '"$deleted"' in text:
        raise ValueError("不允许写入 $deleted 标记")


# ---------------------------------------------------------------- base indexes

def _item_names() -> dict[int, str]:
    names: dict[int, str] = {}
    for section_name, strings in CATALOG.item_strings.items():
        for key, text in strings.items():
            if not isinstance(text, dict):
                continue
            name = str(text.get("name") or "").strip()
            if name and str(key).isdigit():
                names[_safe_int(key)] = name
    return names


def _item_section(item_id: int) -> str | None:
    key = f"{item_id:08d}"
    for section_name, section in CATALOG.raw_item_sections.items():
        if key in section:
            return section_name
    return None


def _attach_item_text(decoded: dict[str, Any], section_name: str, item_id: int) -> dict[str, Any]:
    """把名字/描述从文案表补进记录，编辑时才能看到现有值。

    服务端取名的顺序是 `decoded.name or 文案表.name`，所以这两个键本来就允许覆盖。
    """
    text = CATALOG.item_strings.get(section_name, {}).get(str(int(item_id)), {})
    if not isinstance(text, dict):
        return decoded
    if not decoded.get("name"):
        decoded["name"] = str(text.get("name") or "")
    if not decoded.get("description"):
        decoded["description"] = str(text.get("desc") or "")
    return decoded


def _item_base(item_id: int) -> dict[str, Any] | None:
    key = f"{item_id:08d}"
    for section_name, section in CATALOG.raw_item_sections.items():
        raw = section.get(key)
        if raw is not None:
            decoded = _decode(raw)
            return _attach_item_text(decoded, section_name, item_id) if isinstance(decoded, dict) else None
    return None


def _equipment_base(item_id: int) -> dict[str, Any] | None:
    raw = CATALOG.raw_equipment.get(f"{item_id:08d}")
    if raw is None:
        return None
    decoded = _decode(raw)
    return decoded if isinstance(decoded, dict) else None


def _quest_base(quest_id: int) -> dict[str, Any] | None:
    raw = CATALOG.raw_quests.get(str(quest_id))
    if raw is None:
        return None
    decoded = _decode(raw)
    return decoded if isinstance(decoded, dict) else None


def _gift_base(item_id: int) -> dict[str, Any] | None:
    raw = CATALOG.raw_item_sections.get("LiBao", {}).get(f"{item_id:08d}")
    if raw is None:
        return None
    decoded = _decode(raw)
    return _attach_item_text(decoded, "LiBao", item_id) if isinstance(decoded, dict) else None


def _item_index() -> list[dict[str, Any]]:
    cached = _INDEX_CACHE.get("items")
    if cached is not None:
        return cached
    rows: list[dict[str, Any]] = []
    for section_name, section in CATALOG.raw_item_sections.items():
        if section_name == "LiBao":
            continue
        for raw_id in section:
            if not str(raw_id).isdigit():
                continue
            definition = CATALOG.get_item_definition(_safe_int(raw_id))
            if definition is None:
                continue
            rows.append(
                {
                    "id": str(_safe_int(raw_id)),
                    "name": definition.name,
                    "summary": f"{section_name} · {definition.price} 金 · Lv.{definition.required_level}",
                }
            )
    rows.sort(key=lambda row: _safe_int(row["id"]))
    _INDEX_CACHE["items"] = rows
    return rows


def _gift_index() -> list[dict[str, Any]]:
    cached = _INDEX_CACHE.get("gift_packs")
    if cached is not None:
        return cached
    rows: list[dict[str, Any]] = []
    for raw_id in CATALOG.raw_item_sections.get("LiBao", {}):
        if not str(raw_id).isdigit():
            continue
        definition = CATALOG.get_item_definition(_safe_int(raw_id))
        if definition is None:
            continue
        rows.append(
            {
                "id": str(_safe_int(raw_id)),
                "name": definition.name,
                "summary": f"{len(definition.contents)} 种奖励 · Lv.{definition.required_level}",
            }
        )
    rows.sort(key=lambda row: _safe_int(row["id"]))
    _INDEX_CACHE["gift_packs"] = rows
    return rows


def _equipment_index() -> list[dict[str, Any]]:
    cached = _INDEX_CACHE.get("equipment")
    if cached is not None:
        return cached
    rows: list[dict[str, Any]] = []
    for raw_id in CATALOG.raw_equipment:
        if not str(raw_id).isdigit():
            continue
        item_id = _safe_int(raw_id)
        definition = CATALOG.get_equipment_definition(item_id)
        if definition is None:
            continue
        name = CATALOG.get_item_definition(item_id)
        rows.append(
            {
                "id": str(item_id),
                "name": name.name if name is not None else str(item_id),
                "summary": f"{definition.type_name} · 阶段 {definition.stage} · Lv.{definition.required_level}",
            }
        )
    rows.sort(key=lambda row: _safe_int(row["id"]))
    _INDEX_CACHE["equipment"] = rows
    return rows


def _quest_index() -> list[dict[str, Any]]:
    cached = _INDEX_CACHE.get("quests")
    if cached is not None:
        return cached
    rows: list[dict[str, Any]] = []
    for raw_id in CATALOG.raw_quests:
        if not str(raw_id).isdigit():
            continue
        definition = CATALOG.get_quest_definition(_safe_int(raw_id))
        if definition is None:
            continue
        rows.append(
            {
                "id": str(_safe_int(raw_id)),
                "name": definition.name,
                "summary": f"{definition.quest_type} · Lv.{definition.min_level}-{definition.max_level} · 经验 {definition.reward_exp}",
            }
        )
    rows.sort(key=lambda row: _safe_int(row["id"]))
    _INDEX_CACHE["quests"] = rows
    return rows


def _cash_index() -> list[dict[str, Any]]:
    cached = _INDEX_CACHE.get("cash_shop")
    if cached is not None:
        return cached
    rows: list[dict[str, Any]] = []
    category_names = {int(category): str(category) for category in game.CashShopCategory}
    for category, items in game.NYA208_CASH_CATALOG.items():
        for row in items:
            definition = CATALOG.get_item_definition(_safe_int(row.get("item_id")))
            if definition is None:
                continue
            rows.append(
                {
                    "id": str(_safe_int(row.get("sn"))),
                    "name": definition.name,
                    "summary": f"分类 {category_names.get(int(category), category)} · 现价 {row.get('now_price')} 元宝 · sn {row.get('sn')} · item {row.get('item_id')}",
                    "sortKey": (int(category), _safe_int(row.get("sn"))),
                }
            )
    rows.sort(key=lambda row: row["sortKey"])
    for row in rows:
        row.pop("sortKey", None)
    _INDEX_CACHE["cash_shop"] = rows
    return rows


def _npc_names() -> dict[int, dict[str, str]]:
    global _NPC_NAMES
    if _NPC_NAMES is None:
        _NPC_NAMES = {}
        try:
            payload = json.loads(NPC_TABLE.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError):
            payload = {}
        if isinstance(payload, dict):
            for key, value in payload.items():
                if isinstance(value, dict) and str(key).isdigit():
                    _NPC_NAMES[_safe_int(key)] = {
                        "name": str(value.get("name") or ""),
                        "title": str(value.get("title") or ""),
                        "service": str(value.get("service") or ""),
                    }
    return _NPC_NAMES


def _npc_shop_base(npc_id: int) -> dict[str, Any] | None:
    captured = game.NYA208_MERCHANT_CATALOG.get(npc_id)
    if captured is not None:
        tabs: list[dict[str, Any]] = []
        prices: dict[str, int] = {}
        for captured_tab in captured.get("tabs", ()):
            items = [
                dict(item)
                for item in captured_tab.get("items", ())
                if isinstance(item, dict)
            ]
            tabs.append(
                {
                    "name": str(captured_tab.get("name") or "商品"),
                    "enabled": True,
                    "itemIds": [int(item["item_id"]) for item in items],
                    "items": items,
                }
            )
            prices.update({str(item["item_id"]): int(item["price"]) for item in items})
        return {
            "shop_id": npc_id,
            "tabs": tabs,
            "prices": prices,
            "buy_multiplier": 1.0,
            "sell_multiplier": 0.5,
        }
    layout = game.FakeFlashSession.MERCHANT_SHOP_LAYOUT.get(npc_id)
    if layout is None:
        _, role = CATALOG.npc_functions.get(npc_id, ("", ""))
        template_id = game.FakeFlashSession.MERCHANT_ROLE_LAYOUT_TEMPLATE_IDS.get(role)
        layout = game.FakeFlashSession.MERCHANT_SHOP_LAYOUT.get(template_id)
    if layout is None:
        return None
    tabs = []
    for tab_name, section_name, prefixes, maximum in layout:
        item_ids = CATALOG.merchant_item_ids(section_name, prefixes, maximum)
        if npc_id == 14 and section_name == "XiaoHao":
            item_ids = tuple(
                item_id
                for item_id in item_ids
                if (
                    (definition := CATALOG.get_item_definition(item_id)) is not None
                    and (definition.hp_restore > 0 or definition.mp_restore > 0)
                )
            )
        tabs.append(
            {
                "name": tab_name,
                "enabled": True,
                "itemIds": list(item_ids[:maximum]),
                "items": [],
            }
        )
    return {
        "shop_id": npc_id,
        "tabs": tabs,
        "prices": {},
        "buy_multiplier": 1.0,
        "sell_multiplier": 0.5,
    }


def _npc_shop_ids() -> list[int]:
    ids = set(game.NYA208_MERCHANT_CATALOG)
    ids.update(game.FakeFlashSession.MERCHANT_SHOP_LAYOUT)
    for npc_id, (_, role) in CATALOG.npc_functions.items():
        template_id = game.FakeFlashSession.MERCHANT_ROLE_LAYOUT_TEMPLATE_IDS.get(role)
        if template_id in game.FakeFlashSession.MERCHANT_SHOP_LAYOUT:
            ids.add(int(npc_id))
    return sorted(int(value) for value in ids)


def _npc_shop_index() -> list[dict[str, Any]]:
    cached = _INDEX_CACHE.get("npc_shops")
    if cached is not None:
        return cached
    names = _npc_names()
    rows: list[dict[str, Any]] = []
    for npc_id in _npc_shop_ids():
        info = names.get(npc_id, {})
        base = _npc_shop_base(npc_id)
        item_count = sum(len(tab.get("itemIds", ())) for tab in (base or {}).get("tabs", ()))
        rows.append(
            {
                "id": str(npc_id),
                "name": info.get("title") or info.get("name") or f"NPC {npc_id}",
                "summary": f"{info.get('name', '')} · {item_count} 件商品 · {len((base or {}).get('tabs', ()))} 个页签",
            }
        )
    _INDEX_CACHE["npc_shops"] = rows
    return rows


def _pool_index() -> list[dict[str, Any]]:
    project = _read_project()
    records = project["overrides"].get("drop_pools", {})
    rows = []
    for key, record in sorted(records.items(), key=lambda pair: _safe_int(pair[0])):
        items = record.get("items") if isinstance(record.get("items"), list) else []
        rows.append(
            {
                "id": key,
                "name": str(record.get("name") or f"掉落池 {key}"),
                "summary": f"{len(items)} 条物品 · {record.get('description', '')}".strip(" ·"),
            }
        )
    return rows


def _bind_index() -> list[dict[str, Any]]:
    project = _read_project()
    records = project["overrides"].get("drop_pool_binds", {})
    rows = []
    for key, record in sorted(records.items(), key=lambda pair: _safe_int(pair[0])):
        pools = record.get("pools") if isinstance(record.get("pools"), list) else []
        definition = CATALOG.get_monster_definition(_safe_int(key))
        name = getattr(definition, "name", "") or f"怪物 {key}"
        rows.append(
            {
                "id": key,
                "name": str(record.get("name") or name),
                "summary": f"{len(pools)} 个掉落池 · 模板 {key}",
            }
        )
    return rows


# ---------------------------------------------------------------- table registry

def _field(path: str, label: str, kind: str = "text", hint: str = "") -> dict[str, str]:
    return {"path": path, "label": label, "kind": kind, "hint": hint}


ITEMS_FIELDS = [
    _field("name", "名称"),
    _field("description", "描述", "textarea"),
    _field("info.price", "金币价", "number"),
    _field("info.reqLevel", "需求等级", "number"),
    _field("info.slotMax", "堆叠上限", "number"),
    _field("info.timeLimit", "时限（秒）", "number"),
    _field("info.useAll", "一次用全部（0/1）", "number"),
    _field("info.preview", "开箱预览（0/1）", "number"),
    _field("spec.type", "使用类型"),
    _field("spec.skillid", "学会技能 ID", "number"),
    _field("spec.params.hp", "回复 HP", "number"),
    _field("spec.params.mp", "回复 MP", "number"),
    _field("spec.params", "其余使用参数", "json"),
]

EQUIPMENT_FIELDS = [
    _field("info.reqLevel", "需求等级", "number"),
    _field("info.reqJob", "需求职业（0 不限）", "number"),
    _field("info.stage", "阶段", "number"),
    _field("info.free", "是否免费", "number"),
    _field("info.price", "金币价", "number"),
    _field("info.timeLimit", "时限（秒）", "number"),
    _field("info.face", "外观 face", "number"),
    _field("info.addAttr", "附加属性", "textarea", "形如 atk:666;def:222"),
    _field("info.baseAttr", "基础属性", "textarea", "神器/灵器/忍具的基础属性"),
    _field("info.specialAttr", "特殊属性", "textarea", "灵器/忍具的 specialAttr"),
]

QUEST_FIELDS = [
    _field("info.name", "任务名"),
    _field("info.type", "任务类型", "text", "trunk / branch 等"),
    _field("info.desc", "任务描述", "json"),
    _field("act", "奖励节点", "json"),
    _field("check", "条件节点", "json"),
    _field("say", "对白节点", "json"),
    _field("npc", "NPC 节点", "json"),
]

GIFT_FIELDS = [
    _field("info.price", "金币价", "number"),
    _field("info.reqLevel", "需求等级", "number"),
    _field("info.slotMax", "堆叠上限", "number"),
    _field("info.preview", "开箱预览（0/1）", "number"),
    _field("info.drop", "可掉落（0/1）", "number"),
    _field("info.useAll", "一次用全部（0/1）", "number"),
    _field("spec.params.money", "货币奖励", "json"),
    _field("spec.params.items", "物品奖励（按职业分组）", "json"),
]

DROP_FIELDS = [
    _field("designVersion", "设计版本"),
    _field("skillBookRatePerMillion", "技能书（每百万）", "number"),
    _field("rouquanBookRatePerMillion", "柔拳秘籍（每百万）", "number"),
    _field("fragmentRatePerMillion", "残卷碎片（每百万）", "number"),
    _field("spiritRatePerMillion", "精华（每百万）", "number"),
    _field("cardRatePerMillion", "卡片（每百万）", "number"),
    _field("foodMaterialRatePerMillion", "料理素材（每百万）", "number"),
    _field("heroCopyInsectRatePer10000", "英雄副本昆虫（每万）", "number"),
    _field("normalItemRatePerMillion", "普通物品（每百万）", "number"),
    _field("doubleDropRateMultiplier", "双倍掉落倍率", "number"),
    _field("doubleExperienceMultiplier", "双倍经验倍率", "number"),
    _field("weekendDays", "周活动日"),
    _field("weekendStartTime", "周活动开始"),
    _field("weekendEndTime", "周活动结束"),
    _field("holidayDates", "节日日期"),
    _field("specialDrops", "怪物固定掉落 / 动态池", "json"),
    _field("dropOverrides", "整只怪物的掉落替换", "json"),
]

CASH_FIELDS = [
    _field("now_price", "现价（元宝）", "number"),
    _field("orig_price", "原价（元宝）", "number"),
    _field("is_discount", "打折标记", "number"),
    _field("is_time_limited", "限时标记", "number"),
    _field("time_begin", "开始时间戳", "number"),
    _field("time_end", "结束时间戳", "number"),
    _field("is_count_limited", "限量标记", "number"),
    _field("total_count", "总限量", "number"),
    _field("sell_count", "已售数量", "number"),
    _field("is_new", "新品标记", "number"),
    _field("is_hot", "热卖标记", "number"),
    _field("is_lijin", "礼金品（扣点券）", "number"),
    _field("expire_days", "有效期（天）", "number"),
    _field("is_package", "礼包标记", "number"),
    _field("hidden", "下架该行", "bool"),
]

NPC_FIELDS = [
    _field("tabs", "页签与商品", "json", "覆盖整个页签数组；每项含 name/enabled/itemIds"),
    _field("itemPrices", "指定物品价格", "json", "形如 {\"3000001\": 12}"),
    _field("buyPriceMultiplier", "买入价倍率", "number"),
    _field("sellPriceMultiplier", "卖出价倍率", "number"),
    _field("enabled", "关闭商店", "bool"),
]

POOL_FIELDS = [
    _field("name", "掉落池名称"),
    _field("description", "说明", "textarea"),
    _field("items", "物品行", "json", "每行：itemId 或 pool、count/minCount/maxCount、prob10000、bind"),
]

BIND_FIELDS = [
    _field("name", "说明"),
    _field("pools", "绑定掉落池 ID", "json", "形如 [\"9001\", \"9002\"]"),
]


TABLES: dict[str, dict[str, Any]] = {
    "items": {
        "title": "物品",
        "entity": "items",
        "creatable": False,
        "fields": ITEMS_FIELDS,
        "note": "物品基础信息与使用效果。礼包单独在「礼包」表，避免两套覆盖互相打架。",
        "index": _item_index,
        "base": lambda rid: _item_base(_safe_int(rid)),
        "merged": None,
    },
    "equipment": {
        "title": "装备数值",
        "entity": "equipment",
        "creatable": False,
        "fields": EQUIPMENT_FIELDS,
        "note": "只列常规装备。神器/灵器/忍具/魂戒的名称与描述走「物品」表；它们的数值定义目前不受覆盖通道影响。",
        "index": _equipment_index,
        "base": lambda rid: _equipment_base(_safe_int(rid)),
        "merged": None,
    },
    "quests": {
        "title": "任务",
        "entity": "quests",
        "creatable": False,
        "fields": QUEST_FIELDS,
        "note": "act/check/say/npc 是原版节点结构，修改时保持键结构完整。",
        "index": _quest_index,
        "base": lambda rid: _quest_base(_safe_int(rid)),
        "merged": None,
    },
    "gift_packs": {
        "title": "礼包",
        "entity": "gift_packs",
        "creatable": False,
        "fields": GIFT_FIELDS,
        "note": "覆盖 LiBao 分区的开箱内容；装备类礼包同时可在「物品」表改名称/描述。",
        "index": _gift_index,
        "base": lambda rid: _gift_base(_safe_int(rid)),
        "merged": None,
    },
    "drops_global": {
        "title": "掉落 · 全局规则",
        "entity": "balance_rules",
        "creatable": False,
        "fixedId": "monster_drops",
        "fields": DROP_FIELDS,
        "note": "全局掉率、双倍活动窗口，以及 specialDrops / dropOverrides 两张怪物表。",
        "index": lambda: [
            {
                "id": "monster_drops",
                "name": "怪物掉落与双倍活动",
                "summary": "全局掉率 · 特殊掉落 · 整怪替换",
            }
        ],
        "base": lambda rid: copy.deepcopy(BALANCE_DEFAULTS["monster_drops"]),
        "merged": None,
    },
    "cash_shop": {
        "title": "商城 · 元宝商城",
        "entity": "cash_shop",
        "creatable": False,
        "fields": CASH_FIELDS,
        "note": "按 sn 覆盖原版抓包货架；hidden 可下架。新增 SKU 需另做批次。",
        "index": _cash_index,
        "base": None,
        "merged": None,
    },
    "npc_shops": {
        "title": "商城 · NPC 商店",
        "entity": "npc_shops",
        "creatable": False,
        "fields": NPC_FIELDS,
        "note": "覆盖 NPC 商店页签、指定物品价格与买卖倍率；关闭商店用 enabled=false。",
        "index": _npc_shop_index,
        "base": lambda rid: _npc_shop_base(_safe_int(rid)),
        "merged": None,
    },
    "drop_pools": {
        "title": "掉落 · 掉落池",
        "entity": "drop_pools",
        "creatable": True,
        "fields": POOL_FIELDS,
        "note": "可复用掉落池只存在于 overrides；新建后到「怪物绑定」把池 ID 绑给怪物。",
        "index": _pool_index,
        "base": lambda rid: {},
        "merged": None,
    },
    "drop_pool_binds": {
        "title": "掉落 · 怪物绑定",
        "entity": "drop_pool_binds",
        "creatable": True,
        "fields": BIND_FIELDS,
        "note": "键是怪物模板 ID；pools 里的掉落池会在每次掉落时展开。",
        "index": _bind_index,
        "base": lambda rid: {},
        "merged": None,
    },
}


def _table_entry(table_id: str) -> dict[str, Any]:
    table = TABLES.get(table_id)
    if table is None:
        raise ValueError("未知的数据表")
    return table


def _base_record(table: dict[str, Any], record_id: str) -> dict[str, Any]:
    provider = table.get("base")
    if provider is None:
        if table["entity"] == "cash_shop":
            return _cash_base(record_id)
        return {}
    base = provider(record_id)
    return base if isinstance(base, dict) else {}


def _cash_base(record_id: str) -> dict[str, Any]:
    sn = _safe_int(record_id)
    for items in game.NYA208_CASH_CATALOG.values():
        for row in items:
            if _safe_int(row.get("sn")) == sn:
                return dict(row)
    return {}


def _merged_record(table: dict[str, Any], record_id: str, base: dict[str, Any]) -> dict[str, Any]:
    project = _read_project()
    override = _override_of(project, table["entity"], record_id)
    if table["entity"] == "cash_shop":
        merged = dict(base)
        if override.get("hidden") is True:
            merged["hidden"] = True
        for key in CASH_OVERRIDE_FIELDS:
            if key in override:
                try:
                    merged[key] = int(override[key])
                except (TypeError, ValueError):
                    pass
        return merged
    if table["entity"] == "npc_shops":
        return _apply_npc_override(base, override)
    return _deep_merge(base, override)


def _apply_npc_override(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    merged = copy.deepcopy(base)
    if isinstance(override.get("tabs"), list):
        merged["tabs"] = copy.deepcopy(override["tabs"])
    if override.get("enabled") is False:
        merged["enabled"] = False
    if isinstance(override.get("itemPrices"), dict):
        prices = merged.get("prices") if isinstance(merged.get("prices"), dict) else {}
        prices.update(override["itemPrices"])
        merged["prices"] = prices
        # 覆盖里存的是「指定物品价格」，原样回显给编辑字段，避免整张价格表被再存一遍。
        merged["itemPrices"] = copy.deepcopy(override["itemPrices"])
    for key, target in (("buyPriceMultiplier", "buy_multiplier"), ("sellPriceMultiplier", "sell_multiplier")):
        if key in override:
            try:
                merged[target] = float(override[key])
            except (TypeError, ValueError):
                continue
            merged[key] = copy.deepcopy(override[key])
    return merged


def _list_records(table_id: str, query: str, offset: int, limit: int) -> dict[str, Any]:
    table = _table_entry(table_id)
    rows = table["index"]()
    project = _read_project()
    overridden = project["overrides"].get(table["entity"], {})
    keyword = str(query).strip().casefold()
    if keyword:
        rows = [
            row
            for row in rows
            if keyword in str(row["name"]).casefold()
            or keyword in str(row["id"]).casefold()
            or keyword in str(row.get("summary", "")).casefold()
        ]
    total = len(rows)
    offset = max(0, offset)
    limit = min(500, max(1, limit))
    page = copy.deepcopy(rows[offset : offset + limit])
    for row in page:
        row["overridden"] = str(row["id"]) in overridden
        if row["overridden"] and table_id in {"items", "equipment", "quests", "gift_packs"}:
            merged = _merged_record(table, str(row["id"]), _base_record(table, str(row["id"])))
            if isinstance(merged.get("name"), str) and merged["name"]:
                row["name"] = merged["name"]
            if table_id == "quests" and isinstance(merged.get("info"), dict):
                name = merged["info"].get("name")
                if isinstance(name, str) and name:
                    row["name"] = name
    return {
        "total": total,
        "offset": offset,
        "limit": limit,
        "records": page,
        "overridden": sorted(overridden),
    }


def _record_payload(table_id: str, record_id: str) -> dict[str, Any]:
    table = _table_entry(table_id)
    if not ID_PATTERN.match(record_id):
        raise ValueError("记录 ID 无效")
    fixed = table.get("fixedId")
    if fixed is not None and record_id != fixed:
        record_id = fixed
    base = _base_record(table, record_id)
    project = _read_project()
    override = _override_of(project, table["entity"], record_id)
    merged = _merged_record(table, record_id, base)
    return {
        "table": table_id,
        "id": record_id,
        "base": base,
        "merged": merged,
        "override": override,
        "hasOverride": bool(override),
        "fields": table["fields"],
        "note": table.get("note", ""),
        "creatable": bool(table.get("creatable")),
        "projectRevision": project["revision"],
    }


def _validate_patch(table: dict[str, Any], record_id: str, patch: dict[str, Any]) -> None:
    _validate_payload(patch, "覆盖补丁")
    entity = table["entity"]
    if entity == "cash_shop":
        unknown = sorted(set(patch) - CASH_OVERRIDE_FIELDS - {"hidden"})
        if unknown:
            raise ValueError(f"商城行不支持字段：{', '.join(unknown)}")
        for key, value in patch.items():
            if key == "hidden":
                if not isinstance(value, bool):
                    raise ValueError("hidden 必须是 true/false")
                continue
            if not isinstance(value, int) or isinstance(value, bool):
                raise ValueError(f"{key} 必须是整数")
    if entity == "npc_shops":
        for key in ("buyPriceMultiplier", "sellPriceMultiplier"):
            if key in patch and not isinstance(patch[key], (int, float)):
                raise ValueError(f"{key} 必须是数字")
        if "enabled" in patch and not isinstance(patch["enabled"], bool):
            raise ValueError("enabled 必须是 true/false")
        for key in ("tabs", "itemPrices"):
            if key in patch and not isinstance(patch[key], (list, dict)):
                raise ValueError(f"{key} 结构无效")
    if entity == "balance_rules":
        for key in ("specialDrops", "dropOverrides"):
            if key in patch and not isinstance(patch[key], dict):
                raise ValueError(f"{key} 必须是对象")
        for key, value in patch.items():
            if key in {"specialDrops", "dropOverrides", "weekendDays", "weekendStartTime", "weekendEndTime", "holidayDates", "designVersion"}:
                continue
            if not isinstance(value, (int, float)) or isinstance(value, bool):
                raise ValueError(f"{key} 必须是数字")


def _save_record(
    table_id: str,
    record_id: str,
    record: dict[str, Any],
    expected_override: dict[str, Any] | None,
) -> dict[str, Any]:
    table = _table_entry(table_id)
    if not isinstance(record, dict):
        raise ValueError("记录必须是 JSON 对象")
    if not ID_PATTERN.match(record_id):
        raise ValueError("记录 ID 无效")
    if table.get("fixedId") and record_id != table["fixedId"]:
        record_id = table["fixedId"]
    _validate_payload(record, "记录")
    base = _base_record(table, record_id)
    entity = table["entity"]
    if entity == "npc_shops":
        # 合并视图里的 prices / *_multiplier 是展示用的派生键；写回时按基础值还原，
        # 免得把整张价格表当成补丁存进覆盖。
        record = dict(record)
        for key in ("prices", "buy_multiplier", "sell_multiplier"):
            if key in base:
                record[key] = copy.deepcopy(base[key])
            else:
                record.pop(key, None)
        if record.get("enabled") is True:
            record.pop("enabled", None)
    patch, deletions = _diff(base, record)
    if deletions:
        preview = ", ".join(deletions[:6])
        raise ValueError(f"不支持删除基础字段：{preview}")
    if patch is _NO_CHANGE:
        patch = {}
    _validate_patch(table, record_id, patch)
    if patch and len(json.dumps(patch, ensure_ascii=False).encode("utf-8")) > MAX_PATCH_BYTES:
        raise ValueError(f"覆盖补丁超过 {MAX_PATCH_BYTES // 1024}KB")

    entity = table["entity"]
    with _STORE_LOCK:
        project = _read_project()
        current = _override_of(project, entity, record_id)
        if not _json_equal(current, expected_override or {}):
            raise _Conflict("这条记录已被其他窗口修改，请刷新后再保存")
        if patch:
            project["overrides"].setdefault(entity, {})[record_id] = patch
        else:
            project["overrides"].get(entity, {}).pop(record_id, None)
            if not project["overrides"].get(entity):
                project["overrides"].pop(entity, None)
        project["revision"] += 1
        backup = _write_project(project)
        if entity in _INDEX_CACHE and table_id not in {"drops_global"}:
            _INDEX_CACHE.pop(table_id, None)
    return {
        "revision": project["revision"],
        "patch": patch,
        "backup": backup,
        "hasOverride": bool(patch),
    }


def _reset_record(table_id: str, record_id: str, expected_override: dict[str, Any] | None) -> dict[str, Any]:
    table = _table_entry(table_id)
    if table.get("fixedId") and record_id != table["fixedId"]:
        record_id = table["fixedId"]
    entity = table["entity"]
    with _STORE_LOCK:
        project = _read_project()
        current = _override_of(project, entity, record_id)
        if not _json_equal(current, expected_override or {}):
            raise _Conflict("这条记录已被其他窗口修改，请刷新后再还原")
        if not current:
            return {"revision": project["revision"], "hasOverride": False, "backup": ""}
        project["overrides"].get(entity, {}).pop(record_id, None)
        if not project["overrides"].get(entity):
            project["overrides"].pop(entity, None)
        project["revision"] += 1
        backup = _write_project(project)
        if table_id in _INDEX_CACHE and table_id not in {"drops_global"}:
            _INDEX_CACHE.pop(table_id, None)
    return {"revision": project["revision"], "hasOverride": False, "backup": backup}


class _Conflict(Exception):
    pass


# ---------------------------------------------------------------- HTTP

def _json_body(handler: BaseHTTPRequestHandler) -> dict[str, Any]:
    length = int(handler.headers.get("Content-Length", "0"))
    if length <= 0 or length > MAX_RECORD_BYTES + 64 * 1024:
        raise ValueError("请求内容无效")
    payload = json.loads(handler.rfile.read(length).decode("utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("请求内容无效")
    return payload


def _backup_rows() -> list[dict[str, Any]]:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    rows = []
    for path in BACKUP_DIR.glob("project-r*.json"):
        if not BACKUP_PATTERN.match(path.name):
            continue
        try:
            stat = path.stat()
            payload = json.loads(path.read_text(encoding="utf-8"))
            revision = _safe_int(payload.get("revision"), 0) if isinstance(payload, dict) else 0
        except (OSError, UnicodeError, json.JSONDecodeError):
            continue
        rows.append(
            {
                "name": path.name,
                "size": stat.st_size,
                "time": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(stat.st_mtime)),
                "revision": revision,
            }
        )
    rows.sort(key=lambda row: row["time"], reverse=True)
    return rows


def _restore_backup(name: str) -> dict[str, Any]:
    if not BACKUP_PATTERN.match(name):
        raise ValueError("备份文件名无效")
    path = BACKUP_DIR / name
    if not path.is_file():
        raise ValueError("备份不存在")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError("备份内容不是有效 JSON") from error
    if not isinstance(payload, dict) or not isinstance(payload.get("overrides", {}), dict):
        raise ValueError("备份缺少 overrides")
    with _STORE_LOCK:
        current = _read_project()
        payload["revision"] = max(current["revision"], _safe_int(payload.get("revision"), 0)) + 1
        payload.setdefault("overrides", {})
        stamp = time.strftime("%Y%m%d-%H%M%S")
        if PROJECT_JSON.is_file():
            shutil.copyfile(PROJECT_JSON, BACKUP_DIR / f"project-r{current['revision']}-{stamp}-pre-restore.json")
        temporary = WORKSPACE / f".project.restore.{os.getpid()}.tmp"
        try:
            temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
            os.replace(temporary, PROJECT_JSON)
        finally:
            temporary.unlink(missing_ok=True)
        _INDEX_CACHE.clear()
    return {"revision": payload["revision"]}


def _table_summaries() -> list[dict[str, Any]]:
    project = _read_project()
    rows = []
    for table_id, table in TABLES.items():
        entity = table["entity"]
        if table.get("index") in {_pool_index, _bind_index}:
            count = len(project["overrides"].get(entity, {}))
        elif table_id == "drops_global":
            count = 1
        elif table_id == "cash_shop":
            count = sum(len(items) for items in game.NYA208_CASH_CATALOG.values())
        elif table_id == "npc_shops":
            count = len(_npc_shop_ids())
        else:
            count = len(table["index"]())
        rows.append(
            {
                "id": table_id,
                "title": table["title"],
                "entity": entity,
                "count": count,
                "creatable": bool(table.get("creatable")),
                "note": table.get("note", ""),
            }
        )
    return rows


def _serve(port: int, password: str) -> ThreadingHTTPServer:
    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"
        server_version = "NarutoDataEditor/1"

        def log_message(self, fmt, *args):
            pass

        def _send(self, status: int, payload: Any, content_type: str = "application/json; charset=utf-8"):
            body = payload if isinstance(payload, bytes) else json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def _error(self, message: str, status: int = 400):
            self._send(status, {"ok": False, "error": message or "请求失败"})

        def _authorized(self) -> bool:
            supplied = self.headers.get("X-Naruto-Editor-Password", "")
            if supplied and hmac.compare_digest(str(supplied), password):
                return True
            self._send(401, {"ok": False, "error": "编辑器口令错误"})
            return False

        def do_GET(self):
            parsed = urlsplit(self.path)
            route = parsed.path
            if route in ("/", "/editor", "/editor/", "/editor/index.html"):
                if not STATIC_INDEX.is_file():
                    self._error("编辑器页面缺失", 500)
                    return
                self._send(200, STATIC_INDEX.read_bytes(), "text/html; charset=utf-8")
                return
            if route in ("/editor/terrain", "/editor/terrain.html"):
                if not STATIC_TERRAIN.is_file():
                    self._error("地形浏览页面缺失", 500)
                    return
                self._send(200, STATIC_TERRAIN.read_bytes(), "text/html; charset=utf-8")
                return
            query = parse_qs(parsed.query)
            if route.startswith("/api/terrain/"):
                if route == "/api/terrain/asset":
                    # 素材直接喂给 <img>，标签带不了自定义口令头；这里只放行
                    # `素材/地图` 下的图片文件，别的路径与扩展名一律拒绝。
                    try:
                        asset = _resolve_terrain_asset(str(query.get("path", [""])[0]))
                        self._send(
                            200,
                            asset.read_bytes(),
                            ASSET_CONTENT_TYPES.get(asset.suffix.lower(), "application/octet-stream"),
                        )
                    except ValueError as error:
                        self._error(str(error))
                    except OSError as error:
                        self._error(str(error) or "素材读取失败", 500)
                    return
                if not self._authorized():
                    return
                try:
                    if route == "/api/terrain/maps":
                        self._send(200, {"ok": True, **_terrain_maps()})
                    elif route == "/api/terrain/map":
                        map_id = str(query.get("id", [""])[0])
                        self._send(200, {"ok": True, "map": _terrain_map(map_id)})
                    else:
                        self._error("查无此接口", 404)
                except ValueError as error:
                    self._error(str(error) or "请求失败")
                except (OSError, TypeError, AttributeError) as error:
                    self._error(str(error) or "地形读取失败", 500)
                return
            if not route.startswith("/api/editor/"):
                self._error("查无此接口", 404)
                return
            if not self._authorized():
                return
            try:
                if route == "/api/editor/tables":
                    self._send(200, {"ok": True, "tables": _table_summaries()})
                elif route == "/api/editor/records":
                    table = str(query.get("table", [""])[0])
                    self._send(
                        200,
                        {
                            "ok": True,
                            **_list_records(
                                table,
                                str(query.get("q", [""])[0]),
                                _safe_int(query.get("offset", ["0"])[0]),
                                _safe_int(query.get("limit", ["120"])[0], 120),
                            ),
                        },
                    )
                elif route == "/api/editor/record":
                    table = str(query.get("table", [""])[0])
                    record_id = str(query.get("id", [""])[0])
                    self._send(200, {"ok": True, "record": _record_payload(table, record_id)})
                elif route == "/api/editor/backups":
                    self._send(200, {"ok": True, "backups": _backup_rows()})
                elif route == "/api/editor/status":
                    project = _read_project()
                    self._send(
                        200,
                        {
                            "ok": True,
                            "revision": project["revision"],
                            "projectPath": str(PROJECT_JSON),
                            "backupCount": len(_backup_rows()),
                            "tableCount": len(TABLES),
                        },
                    )
                else:
                    self._error("查无此接口", 404)
            except ValueError as error:
                self._error(str(error) or "请求失败")
            except (ImportError, AttributeError, OSError, TypeError) as error:
                self._error(str(error) or "编辑器读取失败", 500)

        def do_POST(self):
            route = urlsplit(self.path).path
            if not route.startswith("/api/editor/"):
                self._error("查无此接口", 404)
                return
            if not self._authorized():
                return
            try:
                payload = _json_body(self)
                if route == "/api/editor/save":
                    result = _save_record(
                        str(payload.get("table", "")),
                        str(payload.get("id", "")),
                        payload.get("record"),
                        payload.get("expectedOverride") or {},
                    )
                    self._send(200, {"ok": True, **result})
                elif route == "/api/editor/reset":
                    result = _reset_record(
                        str(payload.get("table", "")),
                        str(payload.get("id", "")),
                        payload.get("expectedOverride") or {},
                    )
                    self._send(200, {"ok": True, **result})
                elif route == "/api/editor/restore":
                    result = _restore_backup(str(payload.get("name", "")))
                    self._send(200, {"ok": True, **result})
                else:
                    self._error("查无此接口", 404)
            except _Conflict as error:
                self._error(str(error), 409)
            except ValueError as error:
                self._error(str(error) or "请求失败")
            except (UnicodeError, json.JSONDecodeError, TypeError) as error:
                self._error(str(error) or "请求内容无效")
            except (ImportError, AttributeError, OSError) as error:
                self._error(str(error) or "编辑器写入失败", 500)

    server = ThreadingHTTPServer(("127.0.0.1", int(port)), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="火影世界数据可视化编辑器")
    parser.add_argument("--port", type=int, default=18691)
    parser.add_argument("--password", default=os.environ.get("NARUTO_EDITOR_PASSWORD", "123456"))
    args = parser.parse_args(argv)
    server = _serve(args.port, args.password)
    print(f"数据编辑器已监听 http://127.0.0.1:{args.port}/editor/ （口令 {args.password}）")
    print(f"覆盖文件：{PROJECT_JSON}")
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        server.shutdown()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
