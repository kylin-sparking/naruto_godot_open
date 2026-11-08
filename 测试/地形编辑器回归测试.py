# -*- coding: utf-8 -*-
"""地形编辑器回归门（2026-11-05）——只读浏览的坐标与素材解析。

地形浏览器（`开发工具/数据编辑器/静态/terrain.html` + `服务.py` 的 `/api/terrain/*`）
只读展示 `数据/地图` 与 `素材/地图`。编辑器里看到的位置如果和客户端不一致，
运营照着量出来的坐标就是错的 —— 所以本门钉四件事：

  ① 地图清单：174 张图、索引与显示名一一对应、目录都在；
  ② 坐标与层级：木叶村逐条钉值（瓦片/物件/脚点/传送门/出生点/背景），
     以及 `渲染配置.gd` 的 z 公式与「同层物件必须在瓦片之下」；
  ③ 素材解析：索引键优先、本地回退、帧文件排序、只放行 `素材/地图` 下的图片；
  ④ HTTP 只读面：页面、口令 401、正常 200、越界/非图片 400、写接口 404，
     并逐字节核对数据文件与真 project.json 没被动过。

⚠️ 地形浏览本身不写任何文件；本门仍把编辑器的 WORKSPACE/PROJECT_JSON 指到
`tempfile`，导入 `服务.py` 产生的 GM 状态也落临时目录，真工程文件全程只读。

用法（被 `测试/地形编辑器回归测试.gd` 调，也可手跑）：
    python 测试/地形编辑器回归测试.py
退出码：0 = 全绿；1 = 有断言不符。
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import shutil
import sys
import tempfile
import traceback
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import quote, unquote

REPO = Path(__file__).resolve().parents[1]
REAL_PROJECT = REPO / "服务端" / "runtime" / "www" / "editor_workspace" / "project.json"
REAL_BYTES = REAL_PROJECT.read_bytes() if REAL_PROJECT.is_file() else b""

DATA = REPO / "数据"
MAP_ROOT = DATA / "地图"
INDEX_PATH = DATA / "地图索引.json"
NAMES_PATH = DATA / "地图名.json"
ASSET_INDEX_PATH = DATA / "地图素材索引.json"
MARKERS_PATH = DATA / "背景层标记.json"
TILE_Z_PATH = DATA / "地图块描述符z.json"
MUYE_DIR = MAP_ROOT / "木叶村"
MUYE_FILES = [MUYE_DIR / name for name in ("地图.json", "地图块.json", "物件.json")]


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


TRACKED = [INDEX_PATH, NAMES_PATH, ASSET_INDEX_PATH, MARKERS_PATH, TILE_Z_PATH, *MUYE_FILES]
BEFORE = {str(path): _sha(path) for path in TRACKED if path.is_file()}

TMP = Path(tempfile.mkdtemp(prefix="terrain-gate-"))
os.environ["NARUTO_GM_STATE_PATH"] = str(TMP / "gm-state.json")

spec = importlib.util.spec_from_file_location(
    "naruto_terrain_service", REPO / "开发工具" / "数据编辑器" / "服务.py"
)
svc = importlib.util.module_from_spec(spec)
sys.modules["naruto_terrain_service"] = svc
spec.loader.exec_module(svc)

svc.WORKSPACE = TMP
svc.PROJECT_JSON = TMP / "project.json"
svc.BACKUP_DIR = TMP / "backups"
svc.PROJECT_JSON.write_text('{"revision": 1, "overrides": {}}\n', encoding="utf-8", newline="\n")

失败: list[str] = []
断言数 = 0


def 查(条件: bool, 说明: str) -> None:
    global 断言数
    断言数 += 1
    if not 条件:
        失败.append(说明)


def 摘要(map_id: str) -> dict:
    return svc._terrain_map_summary(map_id, svc._map_folder(map_id))


def 值(rows: list[dict], **条件) -> dict | None:
    for row in rows:
        if all(row.get(key) == value for key, value in 条件.items()):
            return row
    return None


MUYE = "100000000"


def 主流程() -> None:
    # ── ① 地图清单 ──────────────────────────────────────────────────────────
    index = svc._map_folders()
    names = svc._map_names()
    查(len(index) == 174, "地图索引应登记 174 张图（数据集快照，改图后同步更新本条）")
    查(len(names) == 174, "地图显示名应登记 174 条")
    查(set(index) == set(names), "地图索引与显示名必须是同一组 id")
    查(all((MAP_ROOT / folder).is_dir() for folder in index.values()), "索引里的每个地图目录都必须存在")

    清单 = svc._terrain_maps()
    查(清单["count"] == 174 and len(清单["maps"]) == 174, "地图清单接口应返回 174 张图")
    查([row["id"] for row in 清单["maps"]] == sorted(index), "地图清单必须按 id 升序返回")
    查(all(isinstance(row["baked"], bool) and isinstance(row["tiles"], int) for row in 清单["maps"]),
       "清单每行都应带烘焙场景存在性与瓦片数")

    木叶 = 摘要(MUYE)
    查(木叶["name"] == "木叶村" and 木叶["folder"] == "木叶村", "100000000 应是木叶村")
    查(
        {key: 木叶[key] for key in ("tiles", "objects", "footholds", "portals", "life", "backgrounds", "baked")}
        == {"tiles": 525, "objects": 211, "footholds": 75, "portals": 9, "life": 26,
            "backgrounds": 4, "baked": True},
        "木叶村摘要应钉在 525/211/75/9/26/4 且已有烘焙场景",
    )
    终结谷 = 摘要("101010000")
    查(
        (终结谷["name"], 终结谷["tiles"], 终结谷["objects"], 终结谷["footholds"],
         终结谷["portals"], 终结谷["life"], 终结谷["backgrounds"], 终结谷["baked"])
        == ("终结谷浅滩", 201, 109, 55, 5, 9, 4, True),
        "终结谷浅滩摘要应钉在 201/109/55/5/9/4 且已有烘焙场景",
    )

    # ── ② 坐标与层级（木叶村逐条钉值） ──────────────────────────────────────
    地图 = svc._terrain_map(MUYE)
    查(地图["readOnly"] is True, "地图详情必须标记 readOnly")
    查(地图["vr"] == {"left": 28, "top": -70, "right": 4885, "bottom": 1552}, "木叶村可视区应钉在 28,-70,4885,1552")
    查(地图["info"].get("bgm") == "1" and 地图["info"].get("reqLevel") == 10, "木叶村 BGM/等级限制应来自 地图.json")
    查(地图["missing"] == {"tiles": 0, "objects": 0, "backgrounds": 0}, "木叶村不应有解析不到的素材")
    查(地图["bakedPath"] == "res://场景/生成/地图_100000000_烘焙.tscn"
       and 地图["playableScene"] == 地图["bakedPath"], "已有烘焙场景时应直接指向它")
    查(地图["minimap"] is not None
       and 地图["minimap"]["assetPath"] == "res://素材/地图/木叶村/小地图.png", "小地图应解析到 素材/地图/木叶村/小地图.png")

    层数 = {}
    for tile in 地图["tiles"]:
        层数[tile["layer"]] = 层数.get(tile["layer"], 0) + 1
    查(层数 == {0: 190, 2: 335}, "木叶村瓦片层应为 0:190、2:335")
    物件层数 = {}
    for obj in 地图["objects"]:
        物件层数[obj["layer"]] = 物件层数.get(obj["layer"], 0) + 1
    查(物件层数 == {0: 143, 3: 68}, "木叶村物件层应为 0:143、3:68")

    瓦片 = 地图["tiles"][0]
    查(
        {key: 瓦片[key] for key in ("layer", "tS", "u", "no", "x", "y", "zM", "ox", "oy", "descriptorZ", "z")}
        == {"layer": 0, "tS": "woodMarble", "u": "enH0", "no": 3, "x": 2394, "y": 441,
            "zM": 0, "ox": 0, "oy": 63, "descriptorZ": -3, "z": 189},
        "木叶村首块瓦片应钉在 woodMarble/enH0/3 @2394,441，描述符 z=-3，层 z=189",
    )
    查(瓦片["assetPath"] == "res://素材/地图/木叶村/地图块/Tile_woodMarble_enH0_3.png",
       "首块瓦片素材应解析到 Tile_woodMarble_enH0_3.png（jpg 优先、png 回退）")

    物件 = 地图["objects"][0]
    查(
        {key: 物件[key] for key in ("layer", "base", "x", "y", "z", "mapZ", "flip", "ox", "oy")}
        == {"layer": 0, "base": "Obj_acc_muye_nature_0", "x": 3021, "y": 454,
            "z": 64, "mapZ": 0, "flip": False, "ox": 0, "oy": 0},
        "木叶村首个物件应钉在 Obj_acc_muye_nature_0 @3021,454，层 z=64",
    )
    查([frame["path"] for frame in 物件["frames"]]
       == ["res://素材/地图/木叶村/地图物件/Obj_acc_muye_nature_0/Obj_acc_muye_nature_0_0.png"],
       "首物件帧应解析到 Obj_acc_muye_nature_0_0.png")

    梯子 = 值(地图["objects"], base="Obj_connect_ladder_0_0")
    查(梯子 is not None
       and (梯子["layer"], 梯子["x"], 梯子["y"], 梯子["z"], 梯子["ox"], 梯子["oy"])
       == (3, 2800, 872, 1600, 28, 11),
       "3 层梯子 Obj_connect_ladder_0_0 应钉在 2800,872，z=3*512+64=1600")

    脚点 = {(row["layer"], row["group"], row["id"]): row for row in 地图["footholds"]}
    查(
        (脚点[(0, "0", "6")]["x1"], 脚点[(0, "0", "6")]["y1"],
         脚点[(0, "0", "6")]["x2"], 脚点[(0, "0", "6")]["y2"],
         脚点[(0, "0", "6")]["prev"], 脚点[(0, "0", "6")]["next"])
        == (1763, 458, 1763, 494, 35, 0),
        "木叶村脚点 0/0/6 应为竖段 1763,458→1763,494（prev 35）",
    )
    查(
        (脚点[(0, "0", "7")]["x1"], 脚点[(0, "0", "7")]["y1"],
         脚点[(0, "0", "7")]["x2"], 脚点[(0, "0", "7")]["y2"],
         脚点[(0, "0", "7")]["prev"], 脚点[(0, "0", "7")]["next"])
        == (2728, 922, 2728, 886, 0, 8)
        and (脚点[(0, "0", "8")]["x2"], 脚点[(0, "0", "8")]["y2"],
             脚点[(0, "0", "8")]["prev"], 脚点[(0, "0", "8")]["next"])
        == (3548, 886, 7, 9),
        "脚点 7→8 必须保留 prev/next 链接（编辑器画连线靠它）",
    )

    传送门 = {(row["key"]): row for row in 地图["portals"]}
    查({key: 传送门["0"].get(key) for key in ("pn", "pt", "tm", "tn", "x", "y")}
       == {"pn": "sp", "pt": 0, "tm": 999999999, "tn": "", "x": 2372, "y": 1209},
       "木叶村 0 号传送门应为出生点 sp @2372,1209")
    查({key: 传送门["1"].get(key) for key in ("pn", "pt", "tm", "tn", "x", "y")}
       == {"pn": "west00", "pt": 2, "tm": 101010000, "tn": "west01", "x": 379, "y": 1269},
       "1 号传送门应指向终结谷浅滩 west01 @379,1269")

    出生 = {(row["key"]): row for row in 地图["life"]}
    查({key: 出生["1"].get(key) for key in ("type", "id", "x", "y", "fh", "rx0", "rx1")}
       == {"type": "n", "id": "00000013", "x": 3943, "y": 818, "fh": 29, "rx0": 2085, "rx1": 2085},
       "木叶村 1 号出生点应是 NPC 00000013 @3943,818")
    查(all(row.get("type") == "n" for row in 地图["life"]), "木叶村 26 个出生点应全是 NPC（type=n）")

    背景 = [(row["key"], row["no"], row["type"], row["x"], row["y"], row["次序"], row["类别"])
            for row in 地图["backgrounds"]]
    查(背景 == [
        ("0", 0, 3, 0, 0, 0, "纯色底块"),
        ("1", 2, 1, 0, -600, 1, "天空"),
        ("2", 3, 1, 0, -270, 2, "后景"),
        ("3", 1, 0, 0, -300, 3, "后景"),
    ], "木叶村 4 层背景的编号/类型/位置/点击次序必须与 背景层标记.json 一致")
    查(all(row["asset"] and row["assetPath"].startswith("res://素材/地图/木叶村/背景/")
            for row in 地图["backgrounds"]), "4 层背景素材都应解析到 木叶村/背景/Back_zhucheng_*")

    查(svc._tile_z(0, 0) == 192 and svc._tile_z(2, -63) == 1153,
       "瓦片 z = layer*512 + 128 + clamp(描述符z,-63..63) + 64")
    查(svc._object_z(0, 0) == 64 and svc._object_z(3, 0) == 1600,
       "物件 z = layer*512 + clamp(地图z,-63..63) + 64")
    查(svc._clamp_terrain_z(999) == 63 and svc._clamp_terrain_z(-999) == -63,
       "地形 z 必须夹在 -63..63")
    查(svc._tile_descriptor_z("woodMarble", "enH0", 3) == -3,
       "瓦片描述符 z 必须读 地图块描述符z.json")
    for layer in sorted(set(层数) | set(物件层数)):
        zs = [tile["z"] for tile in 地图["tiles"] if tile["layer"] == layer]
        os_ = [obj["z"] for obj in 地图["objects"] if obj["layer"] == layer]
        if zs and os_:
            查(max(os_) < min(zs), "同层（%d）物件最大 z 必须小于瓦片最小 z" % layer)

    终结谷详情 = svc._terrain_map("101010000")
    查(终结谷详情["missing"] == {"tiles": 0, "objects": 0, "backgrounds": 0}, "终结谷浅滩不应有解析不到的素材")
    多帧 = 值(终结谷详情["objects"], base="Obj_acc_zhongjiezhigu_artificiality_2")
    查(多帧 is not None and [frame["path"].rsplit("/", 1)[-1] for frame in 多帧["frames"]]
       == ["Obj_acc_zhongjiezhigu_artificiality_2_0.png", "Obj_acc_zhongjiezhigu_artificiality_2_1.png"],
       "多帧物件帧必须按数字序排好（_0、_1）")

    帧测 = TMP / "frames"
    帧测.mkdir()
    (帧测 / "Obj_x_0.png").write_bytes(b"0")
    (帧测 / "Obj_x_2.png").write_bytes(b"2")
    (帧测 / "Obj_x_1.png").write_bytes(b"1")
    (帧测 / "Obj_x.import").write_text("x", encoding="utf-8")
    查([path.name for path in svc._object_frames(帧测, "Obj_x")]
       == ["Obj_x_0.png", "Obj_x_1.png", "Obj_x_2.png"], "物件帧必须按编号升序，忽略 .import")
    帧回退 = TMP / "frame_fallback"
    帧回退.mkdir()
    (帧回退 / "Obj_y.png").write_bytes(b"0")
    查([path.name for path in svc._object_frames(帧回退, "Obj_y")] == ["Obj_y.png"],
       "没有 _0 帧时应把同名无编号图当第 0 帧")

    # ── ③ 素材解析与白名单 ─────────────────────────────────────────────────
    查(svc._find_tile_asset("木叶村", "woodMarble", "enH0", 3)
       == REPO / "素材" / "地图" / "木叶村" / "地图块" / "Tile_woodMarble_enH0_3.png",
       "_find_tile_asset 应命中索引/本地的 Tile_woodMarble_enH0_3.png")
    查(svc._find_map_asset_dir("木叶村", "地图物件", "Obj_acc_muye_nature_0")
       == REPO / "素材" / "地图" / "木叶村" / "地图物件" / "Obj_acc_muye_nature_0",
       "物件目录应优先走索引，再回退到本地目录")
    查(svc._find_map_asset_dir("木叶村", "地图物件", "Obj_not_a_real_object_0_0_0") is None,
       "不存在的物件目录应返回 None（不能拿错目录冒充）")

    解出 = unquote(瓦片["asset"].split("path=", 1)[1])
    查(瓦片["asset"].startswith("/api/terrain/asset?path=") and 解出
       == "素材/地图/木叶村/地图块/Tile_woodMarble_enH0_3.png", "素材 URL 必须整段百分号编码仓内相对路径")

    白名单 = svc._resolve_terrain_asset("素材/地图/木叶村/小地图.png")
    查(白名单 == REPO / "素材" / "地图" / "木叶村" / "小地图.png", "素材白名单应放行 素材/地图 下的图片")
    # 越界目标必须真是一张图，否则「穿越被拒」可能只是被扩展名挡掉，腿就空转。
    越界图 = "素材/角色动画/非玩家角色/小悟_00000004/Npc_00000004.swf_1_Npc_00000004_stand_5.png"
    穿越路径 = "素材/地图/../" + 越界图[len("素材/"):]
    查((REPO / 越界图).is_file(), "越界对照用的 素材/地图 外图片必须存在")
    拒绝 = [
        ("", "空路径"),
        (str(REPO / "素材" / "地图" / "木叶村" / "小地图.png"), "绝对路径"),
        ("res://素材/地图/木叶村/小地图.png", "res:// 路径"),
        (穿越路径, "目录穿越"),
        ("素材/地图/木叶村/小地图.png.import", "非图片扩展名"),
        ("素材/地图/木叶村/不存在.png", "不存在的文件"),
    ]
    for 路径, 说明 in 拒绝:
        try:
            svc._resolve_terrain_asset(路径)
            放行 = True
            原因 = ""
        except ValueError as error:
            放行 = False
            原因 = str(error)
        查(not 放行 and bool(原因), "非法素材路径必须拒绝：" + 说明)

    # ── ④ HTTP 只读面 ───────────────────────────────────────────────────────
    口令 = "terrain-gate-pw"
    server = svc._serve(0, 口令)
    端口 = server.server_address[1]
    根 = "http://127.0.0.1:%d" % 端口

    def 请求(路径: str, 密码: str = "", 数据: bytes | None = None):
        request = urllib.request.Request(根 + 路径, data=数据)
        if 密码:
            request.add_header("X-Naruto-Editor-Password", 密码)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.status, response.headers.get("Content-Type", ""), response.read()
        except urllib.error.HTTPError as error:
            return error.code, error.headers.get("Content-Type", ""), error.read()

    try:
        码, 类型, 正文 = 请求("/editor/terrain")
        查(码 == 200 and "text/html" in 类型 and "地形浏览器" in 正文.decode("utf-8", "replace")
           and "不写任何文件" in 正文.decode("utf-8", "replace"), "地形页应可匿名打开，并明说只读")
        码, 类型, 正文 = 请求("/api/terrain/maps")
        查(码 == 401, "地形 JSON 接口没带口令必须 401")
        码, 类型, 正文 = 请求("/api/terrain/maps", 口令)
        清单2 = json.loads(正文.decode("utf-8"))
        查(码 == 200 and 清单2.get("ok") and 清单2.get("count") == 174 and len(清单2.get("maps", [])) == 174,
           "带口令取地图清单应 200 且 174 张图")
        码, 类型, 正文 = 请求("/api/terrain/map?id=" + MUYE, 口令)
        地图2 = json.loads(正文.decode("utf-8")).get("map") or {}
        查(码 == 200 and len(地图2.get("tiles", [])) == 525 and 地图2.get("missing")
           == {"tiles": 0, "objects": 0, "backgrounds": 0}, "带口令取木叶村详情应 200 且 525 块瓦片")
        码, 类型, 正文 = 请求("/api/terrain/map?id=" + quote("../数据/地图索引.json"), 口令)
        查(码 == 400, "地图 id 带 .. 必须 400")
        码, 类型, 正文 = 请求("/api/terrain/map?id=999999999", 口令)
        查(码 == 400, "不存在的地图 id 必须 400")
        码, 类型, 正文 = 请求("/api/terrain/nope", 口令)
        查(码 == 404, "未知地形接口必须 404")
        码, 类型, 正文 = 请求(瓦片["asset"])
        查(码 == 200 and "image/png" in 类型 and 正文.startswith(b"\x89PNG\r\n\x1a\n"),
           "素材图片必须能匿名读（<img> 带不了口令头），且返回真 PNG")
        码, 类型, 正文 = 请求("/api/terrain/asset?path=" + quote("素材/地图/木叶村/小地图.png.import"))
        查(码 == 400, "素材接口不得下发 .import")
        码, 类型, 正文 = 请求("/api/terrain/asset?path=" + quote(穿越路径))
        查(码 == 400, "素材接口不得穿越到 素材/地图 之外（哪怕目标仍是图片）")
        码, 类型, 正文 = 请求("/api/terrain/save", 口令, b"{}")
        查(码 == 404, "地形写接口不应存在（只读）")
        码, 类型, 正文 = 请求("/editor/")
        查(码 == 200 and "text/html" in 类型, "原数据编辑器页面应不受地形路由影响")
    finally:
        server.shutdown()
        server.server_close()

    # ── 只读核对 ────────────────────────────────────────────────────────────
    查(svc.PROJECT_JSON != REAL_PROJECT, "门必须把编辑器 project.json 指到临时目录")
    查(svc.PROJECT_JSON.read_text(encoding="utf-8") == '{"revision": 1, "overrides": {}}\n'
       and not svc.BACKUP_DIR.exists(), "地形浏览不应写 project.json 或生成备份")
    真 = REAL_PROJECT.read_bytes() if REAL_PROJECT.is_file() else b""
    查(真 == REAL_BYTES, "真 project.json 必须逐字节不变")
    for path in TRACKED:
        查(path.is_file() and _sha(path) == BEFORE.get(str(path)),
           path.name + " 必须逐字节不变（地形浏览只读）")


def main() -> int:
    global 失败
    try:
        主流程()
    except Exception:
        失败.append("地形锤执行异常：\n" + traceback.format_exc())
    finally:
        shutil.rmtree(TMP, ignore_errors=True)
    for line in 失败:
        print("[红] " + line)
    print("断言数：%d，失败：%d" % (断言数, len(失败)))
    if 失败:
        print("地形编辑器回归测试：失败（%d 条）" % len(失败))
        return 1
    print("地形编辑器回归测试：通过（%d 条断言）" % 断言数)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
