# -*- coding: utf-8 -*-
"""把 swf 里的 DefineBitsLossless / Lossless2 位图直接解成 PNG（ffdec 的 image 导出对这类元件会卡在交互重试上）。

用法： python 开发工具/swf位图直解.py <某个.swf> <输出目录>
产物命名与 ffdec 一致： <chid>_<SymbolClass 名>.png —— 这样 补齐原版素材.mjs 不用区分是谁解的。

只处理本工程实际碰到的两种格式：format 3（8 位索引 + 调色板）、format 5（32 位 ARGB，预乘）。
"""
import os
import struct
import sys
import zlib

from PIL import Image

标签位图 = 20      # DefineBitsLossless
标签位图2 = 36     # DefineBitsLossless2
标签JPEG3 = 35     # DefineBitsJPEG3（JPEG 图 + 独立 zlib(alpha) 通道）



def 读标签(正文):
    """从 swf 正文（已解压）逐 tag 走，产出 (tag 类型, tag 体)。"""
    位宽 = 正文[8] >> 3
    偏 = 8 + (5 + 4 * 位宽 + 7) // 8 + 4          # RECT + fps(u16) + 帧数(u16)
    while 偏 + 2 <= len(正文):
        头 = struct.unpack("<H", 正文[偏:偏 + 2])[0]
        偏 += 2
        长 = 头 & 0x3F
        if 长 == 0x3F:
            长 = struct.unpack("<I", 正文[偏:偏 + 4])[0]
            偏 += 4
        yield 头 >> 6, 正文[偏:偏 + 长]
        偏 += 长
        if 头 >> 6 == 0:
            return


def 解位图(体):
    """返回 (chid, PIL 图)。认不得的格式返回 None。"""
    chid = struct.unpack("<H", 体[0:2])[0]
    格式 = 体[2]
    宽 = struct.unpack("<H", 体[3:5])[0]
    高 = struct.unpack("<H", 体[5:7])[0]
    剩 = 体[7:]
    if 格式 == 3:
        色数 = struct.unpack("<H", 剩[0:2])[0]
        调色 = 剩[2:2 + 色数 * 4]
        像素 = zlib.decompress(剩[2 + 色数 * 4:])
        图 = Image.new("RGBA", (宽, 高))
        列 = []
        行距 = 宽 + (4 - 宽 % 4) % 4                                   # 8 位索引才需要按 4 字节补行尾
        for 行 in range(高):
            起 = 行 * 行距
            for i in range(起, 起 + 宽):
                a, r, g, b = 调色[像素[i] * 4:像素[i] * 4 + 4]
                列.append((r, g, b, a))
        图.putdata(列)
        return chid, 图
    if 格式 == 5:
        裸 = zlib.decompress(剩)
        # 32 位 ARGB 每行本来就是 4 的倍数，没有补行尾；行距就是 宽*4
        每行 = 宽 * 4
        列 = []
        for 行 in range(高):
            for 列号 in range(宽):
                a, r, g, b = 裸[行 * 每行 + 列号 * 4:行 * 每行 + 列号 * 4 + 4]
                if a == 0:
                    列.append((0, 0, 0, 0))
                else:                                                 # Flash 存的是预乘，还原成直通
                    列.append((min(255, r * 255 // a), min(255, g * 255 // a), min(255, b * 255 // a), a))
        图 = Image.new("RGBA", (宽, 高))
        图.putdata(列)
        return chid, 图
    return None


def 解JPEG3(体):
    """DefineBitsJPEG3：chid(u16) + alpha偏移(u32) + JPEG + zlib(alpha)。
    alpha 是**非预乘**的单通道，直接当作 RGBA 的 A。认不得的（内嵌 GIF/PNG 的无损分支）返回 None。

    ⚠️ 为什么必须有这条：`UISwf_*` 那一批全用 JPEG3 存图（`UISwf_KeYinHelp.swf` 就是），
    只认 DefineBitsLossless 的话会**直解出 0 张**、看着像"这 SWF 里没图"。
    """
    import io
    chid = struct.unpack("<H", 体[0:2])[0]
    偏移 = struct.unpack("<I", 体[2:6])[0]
    jpeg = 体[6:6 + 偏移]
    if not jpeg.startswith(b"\xff\xd8"):           # 不是裸 JPEG（GIF/PNG 内嵌分支）⇒ 不硬猜
        return None
    图 = Image.open(io.BytesIO(jpeg)).convert("RGB")
    if 6 + 偏移 < len(体):
        宽, 高 = 图.size
        try:
            alpha = zlib.decompress(体[6 + 偏移:])
        except Exception:
            return chid, 图.convert("RGBA")
        if len(alpha) >= 宽 * 高:
            带A = 图.convert("RGBA")
            带A.putalpha(Image.frombytes("L", (宽, 高), alpha[:宽 * 高]))
            图 = 带A
    return chid, 图


def main(swf, 输出目录):
    正文 = open(swf, "rb").read()
    if 正文[:3] == b"CWS":
        正文 = 正文[:8] + zlib.decompress(正文[8:])
    elif 正文[:3] == b"ZWS":
        import lzma
        性质 = 正文[9]
        字典 = struct.unpack("<I", 正文[10:14])[0]
        d = lzma.LZMADecompressor(format=lzma.FORMAT_RAW,
                                  filters=[{"id": lzma.FILTER_LZMA1, "dict_size": 字典, "props": bytes([性质])}])
        正文 = 正文[:8] + d.decompress(正文[22:])
    名 = {}
    for 类型, 体 in 读标签(正文):
        if 类型 == 76:                               # SymbolClass：chid → 导出类名
            对数 = struct.unpack("<H", 体[0:2])[0]
            偏 = 2
            for _ in range(对数):
                chid = struct.unpack("<H", 体[偏:偏 + 2])[0]
                偏 += 2
                止 = 体.index(b"\x00", 偏)
                名[chid] = 体[偏:止].decode()
                偏 = 止 + 1
    os.makedirs(输出目录, exist_ok=True)
    数 = 0
    for 类型, 体 in 读标签(正文):
        if 类型 in (标签位图, 标签位图2):
            解器 = 解位图
        elif 类型 == 标签JPEG3:
            解器 = 解JPEG3
        else:
            continue
        try:
            解 = 解器(体)
        except Exception as e:                       # 认不得的排布不硬猜，交给上层报"解不出"
            print("跳过 %s chid%d：%s" % (os.path.basename(swf), struct.unpack("<H", 体[0:2])[0], e), file=sys.stderr)
            continue
        if not 解:
            continue
        chid, 图 = 解
        图.save(os.path.join(输出目录, "%d_%s.png" % (chid, 名.get(chid, "chid%d" % chid))))
        数 += 1
    print("%s：直解出 %d 张位图" % (os.path.basename(swf), 数))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
