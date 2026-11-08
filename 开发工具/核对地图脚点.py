# -*- coding: utf-8 -*-
"""把客户端 `数据/地图/<地图目录>/地图.json` 的 foothold 与 2.2.3 GameData.dat 的原始
foothold 逐条对照，确认客户端地形几何没有在导出过程中被改写。

用法: python 开发工具/核对地图脚点.py [地图id ...]   （默认全部有目录的地图）
输出: 只打印结论；逐条差异落 .scratch/脚点对照_<id>.txt
"""
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

GC = r"."
NYA = r"2.2.3"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # 服务端目录在本目录

import 服务端目录  # noqa: E402
fs = 服务端目录.加载()  # 项目内那份 fake_flash_server

INDEX = os.path.join(GC, "数据", "地图索引.json")
ROOT = os.path.join(GC, "数据", "地图")
SCRATCH = os.path.join(GC, ".scratch")

FIELDS = ("x1", "y1", "x2", "y2", "prev", "next")


def flatten(fh):
    """把 {层:{组:{id:{...}}}} 摊平成 {id: {...}}，与客户端导出结构一致。"""
    out = {}
    for i1, d1 in fh.items():
        if not isinstance(d1, dict):
            continue
        for i2, d2 in d1.items():
            if not isinstance(d2, dict):
                continue
            for fid, s in d2.items():
                if isinstance(s, dict):
                    out[str(fid)] = s
    return out


def main():
    with open(INDEX, encoding="utf-8-sig") as f:
        index = json.load(f)
    ids = sys.argv[1:] or sorted(index.keys())
    os.makedirs(SCRATCH, exist_ok=True)
    bad = []
    for mid in ids:
        folder = index.get(mid, mid)
        p = os.path.join(ROOT, folder, "地图.json")
        if not os.path.exists(p):
            print("!! %s 无客户端目录" % mid)
            continue
        with open(p, encoding="utf-8-sig") as f:
            client = json.load(f)
        raw = fs.GAME_DATA_CATALOG.raw_maps.get(int(mid))
        if raw is None:
            print("!! %s 不在 GameData" % mid)
            continue
        if isinstance(raw, bytes):
            raw = fs.GAME_DATA_CATALOG._decode_section(raw)
        orig = flatten(raw.get("foothold", {}))
        cli = flatten(client.get("foothold", {}))

        diffs = []
        for fid in sorted(set(orig) | set(cli), key=lambda s: int(s) if s.isdigit() else 0):
            o, c = orig.get(fid), cli.get(fid)
            if o is None:
                diffs.append("只在客户端: %s %s" % (fid, c))
                continue
            if c is None:
                diffs.append("只在原版:   %s %s" % (fid, o))
                continue
            for k in FIELDS:
                if int(o.get(k, 0)) != int(c.get(k, 0)):
                    diffs.append("字段差 %s.%s 原版=%s 客户端=%s" % (fid, k, o.get(k), c.get(k)))
        # 原始层/组结构也记一笔（客户端摊平了）
        lay = sorted(raw.get("foothold", {}).keys())
        if len(orig) != len(cli) or diffs:
            bad.append(mid)
            with open(os.path.join(SCRATCH, "脚点对照_%s.txt" % mid), "w", encoding="utf-8") as f:
                f.write("\n".join(diffs))
        print("%s  原版=%d 客户端=%d 层=%s 差异=%d" % (mid, len(orig), len(cli), lay, len(diffs)))
    print("\n有差异的地图 %d 个: %s" % (len(bad), bad[:30]))


if __name__ == "__main__":
    main()
