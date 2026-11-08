"""文字坐标审计（颜色过滤版）：按每个 Label 的**实际渲染色**取墨迹，避免被格子边框/相邻文字污染。

用法：python 开发工具/文字坐标审计.py <控件.json> <我方.png> <基线.png> <偏移x> <偏移y> [余量]

基线坐标 = 我方坐标 + 偏移。输出 dx/dy 为「我方墨迹 - 原版墨迹」，0 表示完全对齐。
原版取不到同色墨迹时退回高对比度墨迹，并在 色不符 列标出（这类多半是颜色没对上）。
"""
import io
import json
import sys
from collections import Counter

from PIL import Image


def 背景色(图, x0, y0, x1, y1):
    计 = Counter()
    for x in range(x0, x1):
        计[图.getpixel((x, y0))] += 1
        计[图.getpixel((x, y1 - 1))] += 1
    for y in range(y0, y1):
        计[图.getpixel((x0, y))] += 1
        计[图.getpixel((x1 - 1, y))] += 1
    return 计.most_common(1)[0][0]


def 墨迹盒(图, 区, 判据):
    x0, y0, x1, y1 = 区
    左 = 右 = 上 = 下 = None
    点 = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            if 判据(图.getpixel((x, y))):
                点 += 1
                左 = x if 左 is None else min(左, x)
                右 = x if 右 is None else max(右, x)
                上 = y if 上 is None else min(上, y)
                下 = y if 下 is None else max(下, y)
    if 左 is None or 点 < 6:
        return None
    return (左, 上, 右, 下, 点)


def 同色(目标, 容差=58):
    return lambda p: max(abs(p[0] - 目标[0]), abs(p[1] - 目标[1]), abs(p[2] - 目标[2])) <= 容差


def main():
    控件表 = json.load(io.open(sys.argv[1], encoding='utf-8'))
    我方 = Image.open(sys.argv[2]).convert('RGB')
    基线 = Image.open(sys.argv[3]).convert('RGB')
    偏x, 偏y = int(sys.argv[4]), int(sys.argv[5])
    余量 = int(sys.argv[6]) if len(sys.argv) > 6 else 2
    结果 = []
    for 控 in 控件表['控件']:
        if 控['类'] != 'Label':
            continue
        x, y, w, h = [int(round(v)) for v in 控['矩形']]
        色 = 控.get('色')
        if w <= 1 or h <= 1 or not 色:
            continue
        a = (max(0, x - 余量), max(0, y - 余量), min(我方.width, x + w + 余量), min(我方.height, y + h + 余量))
        b = (max(0, a[0] + 偏x), max(0, a[1] + 偏y), min(基线.width, a[2] + 偏x), min(基线.height, a[3] + 偏y))
        判 = 同色(色)
        盒我 = 墨迹盒(我方, a, 判)
        盒基 = 墨迹盒(基线, b, 判)
        色不符 = 盒基 is None
        if 色不符:
            底 = 背景色(基线, b[0], b[1], b[2], b[3])
            盒基 = 墨迹盒(基线, b, lambda p, 底=底: sum(abs(p[i] - 底[i]) for i in range(3)) > 170)
        if 盒我 is None or 盒基 is None:
            结果.append({'路径': 控['路径'], '文本': 控.get('文本'), '色': 色, 'dx': None, 'dy': None,
                         '宽差': None, '色不符': 色不符, '备注': '我方' if 盒我 is None else '原版'})
            continue
        结果.append({
            '路径': 控['路径'], '文本': 控.get('文本'), '色': 色, '字号': 控.get('字号'),
            '矩形': 控['矩形'], '我方墨迹': list(盒我), '原版墨迹': list(盒基),
            'dx': 盒我[0] + 偏x - 盒基[0],
            'dy': round((盒我[1] + 盒我[3]) / 2.0 + 偏y - (盒基[1] + 盒基[3]) / 2.0, 1),
            '宽差': 盒我[2] - 盒我[0] - (盒基[2] - 盒基[0]),
            '高差': 盒我[3] - 盒我[1] - (盒基[3] - 盒基[1]),
            '色不符': 色不符,
        })
    可测 = [r for r in 结果 if r['dx'] is not None]
    可测.sort(key=lambda v: v['dx'])
    按y = sorted(可测, key=lambda v: v['dy'])
    print('Label %d，可测 %d，色不符 %d' % (len(结果), len(可测), sum(1 for r in 结果 if r.get('色不符'))))
    print('整体中位数 dx=%s dy=%s（非 0 说明配准偏了，该改 --偏移 而不是逐条挪文字）'
          % (可测[len(可测) // 2]['dx'], 按y[len(按y) // 2]['dy']))
    print('%-4s %-5s %-5s %-5s %-5s %s' % ('dx', 'dy', '宽差', '高差', '色', '路径 / 文本'))
    for r in sorted(可测, key=lambda v: -(abs(v['dx']) + abs(v['dy']))):
        if abs(r['dx']) <= 1 and abs(r['dy']) <= 1 and not r['色不符']:
            continue
        print('%-4s %-5s %-5s %-5s %-5s %s' % (r['dx'], r['dy'], r['宽差'], r['高差'],
              'Y' if r['色不符'] else '', '%s | %s' % (r['路径'].split('/')[-1], r['文本'])))
    io.open('开发工具/_文字坐标审计全表.json', 'w', encoding='utf-8').write(json.dumps(结果, ensure_ascii=False, indent=1))


main()
