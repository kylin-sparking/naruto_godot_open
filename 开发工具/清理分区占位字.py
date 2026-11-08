# -*- coding: utf-8 -*-
"""剔除 Flash 分区面板导出里的设计期占位字。

Flash 库符号（CharSecondAttributePaneF 等）在时间轴上带着"一二三四""999"这类
占位文本，真机运行时这些文本域会被 setData 覆盖，但 ffdec 导出成 PNG 后占位字
就永久烘进去了。本脚本按颜色把这些字刷掉：

  · 透明行（面板内部镂空，只留左右边框）→ 直接挖成 alpha=0
  · 实色行（横向色带）→ 从同一行最近的干净像素复制过来，保住色带自身的噪声，
    比回填单一主色更不容易看出残影

用法：python 开发工具/清理分区占位字.py <输入.png> <输出.png>
"""
import sys
from collections import Counter

from PIL import Image

边框列 = 3  # 左右各保留几列结构


def 是亮字(r: int, g: int, b: int) -> bool:
    """透明行里的占位字：纯橙标签字或灰白数值字。"""
    if r < 140:
        return False
    return (r - g >= 50 and b <= 60) or max(r, g, b) - min(r, g, b) <= 25


def 清理(输入: str, 输出: str) -> None:
    图 = Image.open(输入).convert("RGBA")
    宽, 高 = 图.size
    像素 = 图.load()
    挖空 = 复制 = 0
    for y in range(高):
        行 = [像素[x, y] for x in range(宽)]
        内部 = [p for p in 行[边框列:宽 - 边框列] if p[3] > 0]
        if not 内部:
            continue
        色带行 = len(内部) >= 宽 - 2 * 边框列
        if 色带行:
            主色 = Counter(p[:3] for p in 内部).most_common(1)[0][0]
            脏 = [x for x in range(边框列, 宽 - 边框列)
                  if 行[x][3] > 0 and sum(abs(a - b) for a, b in zip(行[x][:3], 主色)) > 28]
            净 = [x for x in range(边框列, 宽 - 边框列) if x not in set(脏)]
            for x in 脏:
                源 = min(净, key=lambda c: abs(c - x)) if 净 else None
                if 源 is None:
                    continue
                像素[x, y] = 像素[源, y]
                复制 += 1
        else:
            for x in range(边框列, 宽 - 边框列):
                if 行[x][3] > 0 and 是亮字(*行[x][:3]):
                    像素[x, y] = (0, 0, 0, 0)
                    挖空 += 1
    图.save(输出)
    print("%s -> %s  尺寸=%dx%d  挖空=%d  复制=%d" % (输入, 输出, 宽, 高, 挖空, 复制))


if __name__ == "__main__":
    清理(sys.argv[1], sys.argv[2])
