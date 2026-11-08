# -*- coding: utf-8 -*-
"""从一张图里裁一块，再整数倍放大（NEAREST，不引入插值），用于"单个元件"级的对证。

§0.0c 红线②：并排全景图证明不了"元件贴合"，任何对证都要再配一张 **8 倍以上**的单件样本。
这个工具就是出那张单件样本的——**别再用肉眼看缩略图**（§3.3.0h 的教训）。

用法:
    python 开发工具/裁图放大.py --入 a.png --框 1179,851,1240,873 --倍 8 --出 a_8x.png
    # 多个框一次出，用 --框 重复：
    python 开发工具/裁图放大.py --入 a.png --框 1,2,3,4 --框 5,6,7,8 --倍 8 --出目录 out/

--框 的格式是 `左,上,右,下`（右/下不含），和 PIL 的 crop 一致，也就是"裁出来宽=右-左"。
"""
import argparse
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

from PIL import Image  # noqa: E402


def 解析框(文本: str):
    数 = [int(v) for v in 文本.replace("，", ",").split(",")]
    if len(数) != 4:
        raise SystemExit("--框 要四个整数 左,上,右,下：%s" % 文本)
    return tuple(数)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--入", dest="src", required=True)
    ap.add_argument("--框", dest="boxes", action="append", required=True,
                    help="左,上,右,下（可重复；给了多个就必须用 --出目录）")
    ap.add_argument("--倍", dest="zoom", type=int, default=8)
    ap.add_argument("--出", dest="out")
    ap.add_argument("--出目录", dest="outdir")
    args = ap.parse_args()

    图 = Image.open(args.src).convert("RGBA")
    框们 = [解析框(b) for b in args.boxes]
    if len(框们) > 1 and not args.outdir:
        raise SystemExit("多个 --框 时请给 --出目录")

    出 = []
    for i, 框 in enumerate(框们):
        if 框[2] <= 框[0] or 框[3] <= 框[1]:
            raise SystemExit("框 %s 为空" % (框,))
        片 = 图.crop(框)
        大 = 片.resize((片.width * args.zoom, 片.height * args.zoom), Image.NEAREST)
        目标 = args.out
        if args.outdir:
            目标 = os.path.join(args.outdir, "%s_%d.png" % (os.path.splitext(os.path.basename(args.src))[0], i))
        os.makedirs(os.path.dirname(os.path.abspath(目标)), exist_ok=True)
        大.save(目标)
        出.append((目标, 片.size, 大.size))
        print("框 %s  %dx%d → %dx%d  %s" % (框, 片.width, 片.height, 大.width, 大.height, 目标))
    return 0


if __name__ == "__main__":
    sys.exit(main())
