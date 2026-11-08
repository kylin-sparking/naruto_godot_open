# -*- coding: utf-8 -*-
"""把客户端 `数据/地图/<目录>/地图.json` 的 back 表与 2.2.3 GameData 的逐字段对照。

背景是分层来的（每层一个 no / type / rx / ry / x / y），少一层、no 写错一个数，
画出来就是"这地图的后景不对"。用与脚点相同的办法查。

用法: python 开发工具/核对地图背景.py
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

FIELDS = ("bS", "no", "type", "rx", "ry", "x", "y", "a", "f", "cx", "cy", "front", "ani")
INDEX = json.load(open(os.path.join(GC, "数据", "地图索引.json"), encoding="utf-8-sig"))


def main():
    bad = []
    rows = []
    for mid, folder in sorted(INDEX.items()):
        p = os.path.join(GC, "数据", "地图", folder, "地图.json")
        if not os.path.exists(p):
            continue
        cli = json.load(open(p, encoding="utf-8-sig")).get("back", {})
        raw = fs.GAME_DATA_CATALOG.raw_maps.get(int(mid))
        if raw is None:
            continue
        if isinstance(raw, bytes):
            raw = fs.GAME_DATA_CATALOG._decode_section(raw)
        orig = raw.get("back", {})
        diffs = []
        for k in sorted(set(map(str, orig)) | set(map(str, cli)), key=lambda s: int(s) if s.isdigit() else 0):
            o, c = orig.get(k), cli.get(k)
            if o is None:
                diffs.append("只在客户端: 层%s %s" % (k, c)); continue
            if c is None:
                diffs.append("只在原版:   层%s %s" % (k, o)); continue
            for f in FIELDS:
                if str(o.get(f, "")) != str(c.get(f, "")):
                    diffs.append("层%s.%s 原版=%s 客户端=%s" % (k, f, o.get(f), c.get(f)))
        if diffs:
            bad.append((folder, diffs))
        rows.append((folder, len(orig), len(cli)))
    print("对照 %d 张图" % len(rows))
    print("back 表有差异的地图 %d 张：" % len(bad))
    for folder, diffs in bad:
        print("  %s" % folder)
        for d in diffs[:6]:
            print("     " + d)


if __name__ == "__main__":
    main()
