# -*- coding: utf-8 -*-
"""用 2.2.3 的 render_frame.py 生成参照帧，但**可以只出前景**。

为什么需要它：`2.2.3/map_extract/render_frame.py:63` 的背景公式是屏幕空间近似
（只算视差增量、没算相机基准位移），cx≠0 时背景层不可信（见 开发记录（本地） §3.4.1）。
所以校验"地形（瓦片/物件）摆位"时必须把背景层关掉，否则背景的错会被算到地形头上。

用法:
  python 开发工具/生成参照帧.py --map 100000000 --cx 2450 --cy 1100 --前景 --出 <png>
  python 开发工具/生成参照帧.py --map 100000000 --cx 2450 --cy 1100 --全       --出 <png>
"""
import argparse
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

NYA = r"2.2.3"
sys.path.insert(0, os.path.join(NYA, "map_extract"))

import json  # noqa: E402
from pathlib import Path  # noqa: E402

import render_frame as rf  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", type=int, default=100000000)
    ap.add_argument("--cx", type=int, default=2450)
    ap.add_argument("--cy", type=int, default=1100)
    ap.add_argument("--前景", dest="fg", action="store_true", help="只画瓦片/物件（关掉背景层）")
    ap.add_argument("--全", dest="full", action="store_true", help="背景+前景都画")
    ap.add_argument("--出", dest="out", required=True)
    args = ap.parse_args()

    out_root = Path(NYA) / "map_extract" / "out"
    scene = json.loads((out_root / ("mapscene_%d.json" % args.map)).read_text(encoding="utf-8"))
    img, (rx, ry) = rf.frame(scene, out_root / "cache", args.cx, args.cy,
                             tile_on=True, back_on=args.full)
    out = Path(args.out)
    os.makedirs(str(out.parent), exist_ok=True)
    img.save(str(out))
    print("参照帧 -> %s  相机可见区左上角=(%d,%d)  背景=%s" % (out, rx, ry, "开" if args.full else "关"))


if __name__ == "__main__":
    main()
