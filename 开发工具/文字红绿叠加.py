"""红绿叠加图：我方走红通道、原版走绿通道，配准后对齐的文字呈黄色，错位的会分出红/绿边。

用法：python 开发工具/文字红绿叠加.py <我方.png> <基线.png> <偏移x> <偏移y> <输出.png> [x,y,w,h]
"""
import sys

from PIL import Image


def main():
    我 = Image.open(sys.argv[1]).convert('RGB')
    基 = Image.open(sys.argv[2]).convert('RGB')
    偏x, 偏y = int(sys.argv[3]), int(sys.argv[4])
    输出 = sys.argv[5]
    if len(sys.argv) > 6:
        x, y, w, h = [int(v) for v in sys.argv[6].split(',')]
    else:
        x, y, w, h = 0, 0, min(我.width, 基.width - 偏x), min(我.height, 基.height - 偏y)
    a = 我.crop((x, y, x + w, y + h))
    b = 基.crop((x + 偏x, y + 偏y, x + 偏x + w, y + 偏y + h))
    出 = Image.new('RGB', (w, h))
    出.putdata([(p[0], q[1], q[2]) for p, q in zip(list(a.getdata()), list(b.getdata()))])
    出.save(输出)
    print('已写 %s（%dx%d，取自我方 %d,%d 起）' % (输出, w, h, x, y))


main()
