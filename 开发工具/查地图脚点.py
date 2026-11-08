# -*- coding: utf-8 -*-
"""检查客户端地图 JSON 的 foothold 结构（层/组/id 是否唯一），并可选对照原版层结构。

用法: python 开发工具/查地图脚点.py [地图id ...]
铁律: 只打印结论，明细落盘到 .scratch/脚点明细_<id>.txt
"""
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

GC = r"."
NYA = r"2.2.3"
sys.path.insert(0, os.path.join(NYA, "tools"))

ROOT = os.path.join(GC, "数据", "地图")
INDEX = os.path.join(GC, "数据", "地图索引.json")
SCRATCH = os.path.join(GC, ".scratch")


def load(map_id, index):
    folder = index.get(map_id, map_id)
    with open(os.path.join(ROOT, folder, "地图.json"), encoding="utf-8-sig") as f:
        return folder, json.load(f)


def main():
    with open(INDEX, encoding="utf-8-sig") as f:
        index = json.load(f)
    ids = sys.argv[1:] or ["101010000"]
    os.makedirs(SCRATCH, exist_ok=True)
    for mid in ids:
        folder, d = load(mid, index)
        print("=== map_id=%s folder=%s" % (mid, folder))
        print("  info:", d.get("info"))
        fh = d.get("foothold", {})
        rows = []
        for i1 in fh:
            for i2 in fh[i1]:
                for fid in fh[i1][i2]:
                    rows.append((i1, i2, str(fid), fh[i1][i2][fid]))
        n = len(rows)
        seen = {}
        dup = []
        for r in rows:
            key = r[2]
            if key in seen:
                dup.append((key, seen[key], (r[0], r[1])))
            seen[key] = (r[0], r[1])
        print("  层=%s  组=%s  segments=%d  重号=%d" % (
            sorted(fh.keys()), sorted({r[1] for r in rows}), n, len(dup)))

        def dx(r):
            return abs(float(r[3]["x1"]) - float(r[3]["x2"]))

        def dy(r):
            return abs(float(r[3]["y1"]) - float(r[3]["y2"]))

        vert = [r for r in rows if dx(r) <= 0.5 and dy(r) > 0.5]
        horiz = [r for r in rows if dy(r) <= 0.5]
        slope = [r for r in rows if r not in vert and r not in horiz]
        print("  vertical=%d horizontal=%d slope=%d" % (len(vert), len(horiz), len(slope)))
        print("  ladders=%d portals=%d life=%d" % (len(d.get("ladderRope", {})),
                                                   len(d.get("portal", {})), len(d.get("life", {}))))
        if rows:
            print("  first seg:", json.dumps(rows[0][3], ensure_ascii=False))
        out = os.path.join(SCRATCH, "脚点明细_%s.txt" % mid)
        with open(out, "w", encoding="utf-8") as f:
            for r in rows:
                f.write("%s/%s/%s  %s\n" % (r[0], r[1], r[2], json.dumps(r[3], ensure_ascii=False)))
        print("  明细 -> %s (%d 行)" % (out, n))


if __name__ == "__main__":
    main()
