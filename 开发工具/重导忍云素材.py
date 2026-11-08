"""从原版 Effect_PaiHangBang.swf 重导 25 张忍云素材。

为什么不能用 ffdec 的 `-export sprite`：
  这些条目的 bitmap 是 **预乘 alpha 存储**（透明处 RGB=0；实测 asset≈stored/alpha，
  各 alpha 分箱的 asset/stored 中位数与 255/a 吻合到 ±10%）。ffdec 的 sprite/图片导出
  会把 RGB 再除一次 alpha 得到"直通版"PNG；Godot 渲染是直通 alpha，于是游戏里
  云两侧（低 alpha 处）被放大成刺眼的彩色噪点，颜色也整体发亮偏色。
  实测：PNG 内嵌的那几条（如十大灵兽/忍术仙人/传说忍者/十大瞳术）更严重，
  连 alpha≈1 的垃圾 RGB 都被放大成蓝/绿/红点。

本工具只做一件事：**PNG 的 alpha 保持 ffdec sprite 导出的形状裁切**（与 SWF 的
DefineBitsJPEG3 alpha/PNG 自带 alpha 逐像素相等，实测 25/25 全部 MAE=0），
把 RGB 换回 SWF 里原封不动的存储值。这样 Godot 直通合成
    out = 存储RGB * a + 背景 * (1-a)
与原版 Flash 解码 DefineBitsJPEG3 后的合成完全一致。

用法（项目根目录）：
    python 开发工具/重导忍云素材.py            # 只看对比表，不写盘
    python 开发工具/重导忍云素材.py --写        # 覆盖 素材/特效/Effect_PaiHangBang/*/1.png

⚠ 只改 1.png 的 RGB，尺寸与 alpha 一个字节都不动；重导后要重开 Godot 让它重新导入。
"""

from __future__ import annotations

import argparse
import io
import struct
import sys
import zlib
from pathlib import Path

import numpy as np
from PIL import Image

SWF = Path(r"2.2.3\www\act_web_nya_208_isolated\swf\Effect\Effect_PaiHangBang.swf")
素材根 = Path(__file__).resolve().parents[1] / "素材" / "特效" / "Effect_PaiHangBang"
徽记数 = 25


def 读标签(数据: bytes):
    """逐个产出 (tagCode, body)；自动解压 CWS。"""
    if 数据[:3] == b"CWS":
        数据 = 数据[:8] + zlib.decompress(数据[8:])
    elif 数据[:3] == b"ZWS":
        raise SystemExit("不支持 LZMA 压缩的 SWF")
    pos = 8
    位宽 = 数据[pos] >> 3
    pos += (5 + 4 * 位宽 + 7) // 8 + 4  # RECT + frameRate/frameCount
    while pos + 2 <= len(数据):
        码长 = struct.unpack("<H", 数据[pos : pos + 2])[0]
        pos += 2
        code, ln = 码长 >> 6, 码长 & 0x3F
        if ln == 0x3F:
            ln = struct.unpack("<I", 数据[pos : pos + 4])[0]
            pos += 4
        body = 数据[pos : pos + ln]
        pos += ln
        yield code, body
        if code == 0:
            return


def 解全部位图(swf: Path):
    """返回 [(characterID, 像素RGBA, 来源)]；来源=JPEG3 / PNG3。

    DefineBitsJPEG3 的 imageData 允许是 JPEG，也允许是这个私服客户端塞进去的 PNG
    （实测 15/25 是 PNG）。PNG 自带的 alpha 与单独的 bitmapAlphaData 相乘。
    """
    出 = []
    for code, body in 读标签(swf.read_bytes()):
        if code != 35:
            continue
        cid, off = struct.unpack("<HI", body[:6])
        img = body[6 : 6 + off]
        单独alpha = body[6 + off :]
        if img[:8] == b"\x89PNG\r\n\x1a\n":
            来源 = "PNG3"
        elif img[:2] == b"\xff\xd8":
            来源 = "JPEG3"
        else:
            raise SystemExit("未知图像格式 charId=%d" % cid)
        im = Image.open(io.BytesIO(img)).convert("RGBA")
        im.load()
        rgba = np.asarray(im).copy()
        if 单独alpha:
            al = zlib.decompress(单独alpha)
            h, w = rgba.shape[:2]
            if al:
                if len(al) != w * h:
                    raise SystemExit("charId=%d alpha 长度 %d 与 %dx%d 不符" % (cid, len(al), w, h))
                a = np.frombuffer(al, dtype=np.uint8).reshape(h, w)
                rgba[..., 3] = (rgba[..., 3].astype(np.uint16) * a // 255).astype(np.uint8)
            # 空 alpha 数据 = 该位图不透明；PNG 版位图自带 alpha，照用
        出.append((cid, rgba, 来源))
    return 出


def 找位图(asset: np.ndarray, 位图们):
    """用 alpha 通道找这个徽记对应哪张位图（25 张云形相同，只有颜色不同）。"""
    H, W = asset.shape[:2]
    最差 = None
    for cid, bmp, 来源 in 位图们:
        h, w = bmp.shape[:2]
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                y0, y1 = max(0, dy), min(H, h + dy)
                x0, x1 = max(0, dx), min(W, w + dx)
                if y1 - y0 <= 0 or x1 - x0 <= 0:
                    continue
                差 = np.abs(
                    asset[y0:y1, x0:x1, 3].astype(int) - bmp[y0 - dy : y1 - dy, x0 - dx : x1 - dx, 3].astype(int)
                ).mean()
                if 最差 is None or 差 < 最差[0]:
                    最差 = (差, cid, bmp, 来源, dx, dy)
    差, cid, bmp, 来源, dx, dy = 最差
    return 差, cid, bmp, 来源, dx, dy


def 合成新图(asset: np.ndarray, bmp: np.ndarray, dx: int, dy: int) -> np.ndarray:
    """RGB 换成位图存储值（越界按边缘夹取，实测越界处 alpha≤11，肉眼不可见）。"""
    H, W = asset.shape[:2]
    h, w = bmp.shape[:2]
    新 = asset.copy()
    for y in range(H):
        sy = min(max(y + dy, 0), h - 1)
        for x in range(W):
            sx = min(max(x + dx, 0), w - 1)
            新[y, x, :3] = bmp[sy, sx, :3]
    return 新


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--写", action="store_true", dest="写盘", help="覆盖素材文件")
    args = parser.parse_args()

    位图们 = 解全部位图(SWF)
    print("SWF 位图 %d 张：%s" % (len(位图们), ", ".join("%s%d" % (s, c) for c, _, s in 位图们)))
    总差 = 0
    for i in range(徽记数):
        路 = 素材根 / ("Effect_PaiHangBang_%d" % i) / "1.png"
        asset = np.asarray(Image.open(路).convert("RGBA"))
        差, cid, bmp, 来源, dx, dy = 找位图(asset, 位图们)
        if 差 != 0:
            print("✗ %s 找不到 alpha 完全相等的位图，最小差 %.3f" % (路.parent.name, 差))
            return 1
        新 = 合成新图(asset, bmp, dx, dy)
        变化 = np.abs(新[..., :3].astype(int) - asset[..., :3].astype(int)).mean()
        # 合成后的"可见噪声"：把图像按直通 alpha 叠到中立灰上，再看中值滤波残差
        def 可见噪声(rgba):
            灰 = np.full_like(rgba[..., :3], 128, dtype=np.uint8)
            a = rgba[..., 3:4].astype(np.uint16)
            合 = (rgba[..., :3].astype(np.uint16) * a + 灰.astype(np.uint16) * (255 - a)) // 255
            图 = Image.fromarray(合.astype(np.uint8))
            from PIL import ImageFilter
            中 = np.asarray(图.filter(ImageFilter.MedianFilter(3))).astype(int)
            return np.abs(合.astype(int) - 中).mean()
        旧噪, 新噪 = 可见噪声(asset), 可见噪声(新)
        总差 += 变化
        print(
            "%-26s %-5s charId %2d off(%d,%d) RGB改动MAE=%5.1f 灰底可见噪声 %.2f → %.2f"
            % (路.parent.name, 来源, cid, dx, dy, 变化, 旧噪, 新噪)
        )
        if args.写盘:
            Image.fromarray(新, "RGBA").save(路, optimize=True)
    print("RGB 总改动 MAE = %.1f" % 总差)
    if not args.写盘:
        print("（未写盘；加 --写 才覆盖素材）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
