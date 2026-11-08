# -*- coding: utf-8 -*-
"""把两张截图各裁一块、并排放大拼成一张对比图（原版 vs 移植版）。

背景（2026-09-21 踩的坑）：这类对证图以前是在会话里现打 heredoc 拼的。
第二版漏掉了 `总宽 = cw*2` 那一行 —— IHDR 按 `cw`(=586) 写，可行循环
**每个源图各写 `cw` 像素、两个源图就是 2×cw(=1172)**。写出来的文件
PNG 结构完整、三个 chunk 的 CRC 全对，却自相矛盾：

    IHDR 586x640 depth=8 colortype=2
    IDAT 解压 2250880 字节 = 640 行 × (1 + 1172×3)   ← 每行 1172 像素

PIL 报 `unrecognized data stream contents`，Anthropic API 报
`unsupported image`。更要命的是这张图作为 tool_result 进了会话历史后，
**之后每个请求都会把它重新发一遍**，那个会话就永久卡在同一个 400 上，
重试、说"继续"、说"暂停上传"都没用 —— 只能回退或改会话记录。

所以本工具的规矩：**写完必须把落盘的文件读回来验一遍**（见 `验证`），
不通过就抛异常并把坏图改名 `.bad`，绝不留一张自相矛盾的图在盘上。

用法：
    python 开发工具/拼对比图.py \\
        --左 测试/截图/原版tooltip/悬停武器.png:1124,660,1417,980 \\
        --右 测试/截图/装备提示框_职业符合.png:20,20,313,260 \\
        --出 测试/截图/_tooltip对证2.png [--放大 2]

    # 也可以当模块用（工具链里拼图就 import 它，别再写 heredoc）：
    from 拼对比图 import 拼对比图
    拼对比图((左图, (x0, y0, x1, y1)), (右图, (x0, y0, x1, y1)), 出图, S=2)

版式：左原版、右移植版，各占一半宽；块高取两侧较大者，右侧不足处留黑。
输出一律 8bit RGB（colortype 2），丢 alpha —— 对证看的是版面不是透明度。
"""

import argparse
import importlib.util
import struct
import sys
import zlib
from pathlib import Path

# 裁图/取像素复用已有的解码器，不另起一套
_解码器 = Path(__file__).with_name("定位原版装备格.py")
_spec = importlib.util.spec_from_file_location("_定位原版装备格", _解码器)
_m = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_m)


def _做块(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)


def 验证(路径):
    """把落盘的 PNG 读回来，验 IHDR 与 IDAT 自洽。不通过就抛异常。

    **不能只调 `解码PNG`** —— 它无条件信任 IHDR 的宽，喂它那张自相矛盾的图
    会"成功"解出一堆错行而不报错（真值优先：查不出来的检查等于没查）。
    真正的判据是解压后的字节数对不对得上 IHDR：
        len(解压) == h × (1 + w × 3)      # 非隔行、8bit RGB
    """
    raw = Path(路径).read_bytes()
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{路径}: 不是 PNG")
    w, h = struct.unpack(">II", raw[16:24])
    bd, ct, _, _, il = raw[24], raw[25], raw[26], raw[27], raw[28]
    idat = b""
    i = 8
    while i + 8 <= len(raw):
        ln, typ = struct.unpack(">I4s", raw[i : i + 8])
        if typ == b"IHDR":
            if bd != 8 or ct != 2 or il != 0:
                raise ValueError(f"{路径}: 期望 8bit RGB 非隔行，实际 bitdepth={bd} colortype={ct} interlace={il}")
        elif typ == b"IDAT":
            idat += raw[i + 8 : i + 8 + ln]
        i += 12 + ln
        if typ == b"IEND":
            break
    预期 = h * (1 + w * 3)
    实际 = len(zlib.decompress(idat))
    if 实际 != 预期:
        # 这条信息就是当年那张图的病历：差成整数倍多半是行宽写错了
        倍 = 实际 / 预期
        raise ValueError(
            f"{路径}: IHDR 与 IDAT 对不上 —— IHDR 说 {w}x{h}（应 {预期} 字节），"
            f"实际解压 {实际} 字节（{倍:.3f}×）。八成是 IHDR 宽度没算对（两个源图并排 → 宽应 ×2）"
        )
    try:  # PIL 若在，再让它独立认一遍（它比我们严，能抓出别的问题）
        from PIL import Image

        im = Image.open(路径)
        im.load()
        if im.size != (w, h):
            raise ValueError(f"{路径}: PIL 读回尺寸 {im.size} != IHDR {w}x{h}")
    except ImportError:
        pass
    return w, h


def 拼对比图(左, 右, 出, S=2):
    """左/右 = (图路径, (x0,y0,x1,y1))；S = 放大倍数。返回 (总宽, 块高)。"""
    (左图, 盒左), (右图, 盒右) = 左, 右
    出 = Path(出)

    def 裁(路径, 盒):
        w, h, bpp, 行 = _m.解码PNG(路径)
        x0, y0, x1, y1 = 盒
        x1, y1 = min(x1, w), min(y1, h)
        if x1 <= x0 or y1 <= y0:
            raise ValueError(f"{路径}: 裁剪区域 {盒} 在 {w}x{h} 之外")
        return 行, bpp, x0, y0, x1 - x0, y1 - y0

    行甲, bpp甲, ax0, ay0, aw, ah = 裁(左图, 盒左)
    行乙, bpp乙, bx0, by0, bw, bh = 裁(右图, 盒右)

    块宽 = max(aw, bw) * S
    块高 = max(ah, bh) * S
    总宽 = 块宽 * 2  # ← 两个源图并排。当年就是漏了这行，别删

    raw = bytearray()
    for y in range(块高):
        raw.append(0)  # 行过滤字节：None
        for (行, bpp, x0, y0, 源宽, 源高) in ((行甲, bpp甲, ax0, ay0, aw, ah), (行乙, bpp乙, bx0, by0, bw, bh)):
            if y >= 源高 * S:  # 这一侧比另一侧矮：补黑
                raw += bytes(块宽 * 3)
                continue
            for x in range(块宽):
                raw += bytes(_m.取像素(行, bpp, x0 + min(x // S, 源宽 - 1), y0 + y // S))

    if len(raw) != 块高 * (1 + 总宽 * 3):  # 自检：行数据必须与 IHDR 对得上
        raise AssertionError(f"内部错误：行数据 {len(raw)} 字节，按 {总宽}x{块高} 应为 {块高 * (1 + 总宽 * 3)}")

    出.parent.mkdir(parents=True, exist_ok=True)
    出.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + _做块(b"IHDR", struct.pack(">IIBBBBB", 总宽, 块高, 8, 2, 0, 0, 0))
        + _做块(b"IDAT", zlib.compress(bytes(raw), 6))
        + _做块(b"IEND", b"")
    )
    try:
        验证(出)
    except Exception:
        坏 = 出.with_suffix(出.suffix + ".bad")
        出.replace(坏)
        raise AssertionError(f"写出的图没通过自检，已改名 {坏}（别再去 Read 它）")
    return 总宽, 块高


def _解析(串):
    """`路径:1124,660,1417,980` → (路径, (x0,y0,x1,y1))"""
    路径, _, 盒 = 串.rpartition(":")
    if not 路径:
        sys.exit(f"--左/--右 要写成 路径:x0,y0,x1,y1，收到的是 {串!r}")
    try:
        x0, y0, x1, y1 = (int(v) for v in 盒.split(","))
    except ValueError:
        sys.exit(f"裁剪区域要四个整数，收到 {盒!r}")
    return 路径, (x0, y0, x1, y1)


def 主():
    ap = argparse.ArgumentParser(description="裁两块并排拼成对比图（写完自动验证）")
    ap.add_argument("--左", required=True, help="原版：路径:x0,y0,x1,y1")
    ap.add_argument("--右", required=True, help="移植版：路径:x0,y0,x1,y1")
    ap.add_argument("--出", required=True, help="输出 PNG 路径")
    ap.add_argument("--放大", type=int, default=2, help="放大倍数（默认 2）")
    a = ap.parse_args()
    总宽, 块高 = 拼对比图(_解析(a.左), _解析(a.右), a.出, S=a.放大)
    print(f"已拼 {a.出}  {总宽}x{块高}  自检通过")


if __name__ == "__main__":
    主()
