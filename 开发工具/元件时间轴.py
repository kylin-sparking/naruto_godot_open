# -*- coding: utf-8 -*-
"""`开发工具/元件时间轴.py` —— 从 .swf 里读**时间轴实例坐标**（元件图里每个命名件的落点）。

为什么需要它：一批老页面（设置 `SystemConfigWindowF`、商城、背包、任务…）不是 AS3 代码拼的，
是 Flash 时间轴拖出来的 —— `.as` 里只有 `public var tabBtn1:MTabButton;` 这种**按名字绑定**的声明，
**代码里根本没有 x/y**。想还原就得读 SWF 的 PlaceObject2/3 记录：
`真值文档/ART/*.svg` 只是壳（ffdec 把形状压平了，命名件丢了），所以直接解 tag。

用法：
    python 开发工具/元件时间轴.py <符号名> [--swf 路径] [--树] [--twip]
    python 开发工具/元件时间轴.py SystemConfigWindowF            # 列命名实例 + 坐标（px）
    python 开发工具/元件时间轴.py SystemConfigWindowF --树        # 连未命名实例一起按出栈序列（= 层级/兄弟序）
    python 开发工具/元件时间轴.py --找 CheckBox                   # 按名字子串搜符号名
    python 开发工具/元件时间轴.py --列表                          # 全部导出符号（含 tag 号）

口径：
  · 符号存在性只认导出表（SymbolClass 76 ∪ ExportAssets 56），别拿目录里有没有文件当存在；
  · 坐标 = PlaceObject 的矩阵平移，单位 twip ⇒ **÷20 得 px**（Flash 与本工程都是 px，twip 只在原始值里）；
  · `characterId=0` 是**修改记录**（同一实例换位置/换皮），也照实列出并标 `改`；
  · 只解第 1 帧（这批 UI 元件都是单帧静态件）；多帧会在日志里提醒。
"""
import io
import os
import shutil
import struct
import sys
import zlib

默认SWF = os.path.join(os.environ.get("NARUTO_GAME_ROOT", ""),
                   "www", "act_web_nya_208_isolated", "asset", "MainLib.swf")

# 关心的 tag 号（标准值；本客户端的精灵号见下面注释）
T_END, T_SHOWFRAME = 0, 1
T_PLACE_OBJECT, T_REMOVE_OBJECT = 26, 28
T_EXPORT_ASSETS, T_PLACE_OBJECT3 = 56, 35
T_DOINIT_TAG, T_DOABC, T_DOABC2 = 86, 72, 82
T_SYMBOL_CLASS = 76
T_DEFINE_SPRITE = 32			# 标准号


class 位读:
    """SWF 里的 MATRIX / 标志位都是**从低位往高位**取的 bit field。"""

    def __init__(self, 字节):
        self.b = 字节
        self.i = 0
        self.bit = 0

    def u1(self):
        v = (self.b[self.i] >> self.bit) & 1
        self.bit += 1
        if self.bit == 8:
            self.i += 1
            self.bit = 0
        return v

    def bits(self, n):
        v = 0
        for k in range(n):
            v |= self.u1() << k
        return v

    def sbits(self, n):
        if n == 0:
            return 0
        v = self.bits(n)
        if v >> (n - 1):
            v -= 1 << n
        return v


def 读矩阵(位):
    """返回 (tx, ty) px；缩放/旋转原样带出（这批 UI 件全是 1.0，非 1 要单独看）。"""
    缩 = 位.u1()
    旋 = 位.u1()
    移 = 位.u1()
    sx = sy = 1.0
    if 缩:
        n = 位.bits(5)
        sx = 位.sbits(n) / 65536.0
        sy = 位.sbits(n) / 65536.0
    if 旋:
        n = 位.bits(5)
        位.sbits(n)
        位.sbits(n)
    tx = ty = 0.0
    if 移:
        n = 位.bits(5)
        tx = 位.sbits(n) / 20.0
        ty = 位.sbits(n) / 20.0
    return tx, ty, sx, sy


class 字节读:
    def __init__(self, 字节, 起=0, 基=0):
        self.b = 字节
        self.i = 起
        self.基 = 基			# 这块切片在**整包**里的起始下标（精灵的内层要按整包走）

    def u8(self):
        v = self.b[self.i]
        self.i += 1
        return v

    def u16(self):
        v = struct.unpack_from("<H", self.b, self.i)[0]
        self.i += 2
        return v

    def u32(self):
        v = struct.unpack_from("<I", self.b, self.i)[0]
        self.i += 4
        return v

    def s16(self):
        v = struct.unpack_from("<h", self.b, self.i)[0]
        self.i += 2
        return v

    def str0(self):
        j = self.b.index(0, self.i)
        v = self.b[self.i:j].decode("utf-8", "replace")
        self.i = j + 1
        return v

    def skip(self, n):
        self.i += n

    def 子(self, n):
        r = 字节读(self.b[self.i:self.i + n], 基=self.基 + self.i)
        self.i += n
        return r

    @property
    def 绝对(self):
        return self.基 + self.i


def 去矩形(读):
    n = 读.u8() >> 1
    读.skip((n * 4 + 7) // 8)


def 展开(路径):
    原 = io.open(路径, "rb").read()
    签 = 原[:3]
    if 签 == b"CWS":
        体 = zlib.decompress(原[8:])
    elif 签 == b"ZWS":
        体 = zlib.decompressobj().decompress(原[8:])		# 少见
    elif 签 == b"FWS":
        体 = 原[8:]
    else:
        raise SystemExit("不是 SWF：" + 路径)
    头 = 字节读(体)
    # ⚠ `体` 已经是"sig+version+fileLength 之后"，第一个字段就是 **RECT（帧框）**，
    #    别再 u8()+u32() 跳 version/length —— 那样整个 tag 流会整体错 9 字节，
    #    解出来的 tag 号全是假的（DefineFont3 504 个、tag84 一个没有 就是这个症状）。
    去矩形(头)
    头.u16()						# 帧率
    帧数 = 头.u16()
    return 体, 头.i, 帧数


def 遍历标签(体, 起):
    """yield (tag号, 载荷字节读)。"""
    读 = 字节读(体, 起)
    while 读.i < len(体):
        头 = 读.u16()
        号 = 头 >> 6
        长 = 头 & 0x3F
        if 长 == 0x3F:
            长 = 读.u32()
        yield 号, 读.子(长)


精灵候选 = (32, 39)


def 内层合法(体, 起, 长):
    """载荷能完整走到底、且最后一个 tag 是 END ⇒ 才认它是精灵。"""
    读 = 字节读(体, 起)
    末 = None
    个 = 0
    while 读.i < 起 + 长:
        头 = 读.u16()
        号 = 头 >> 6
        长2 = 头 & 0x3F
        if 长2 == 0x3F:
            长2 = 读.u32()
        if 号 > 100 or 读.i + 长2 > 起 + 长:
            return False
        末 = 号
        读.i += 长2
        个 += 1
        if 号 == T_END:
            break
    return 末 == T_END and 个 >= 1


class 库:
    def __init__(self, 路径):
        体, 起, 帧数 = 展开(路径)
        self.体 = 体
        self.起 = 起
        self.帧数 = 帧数
        self.符号 = {}			# 名 → tag 号
        self.反查 = {}			# tag 号 → 名（导出表里最后一个名字为准）
        self.精灵 = {}			# tag 号 → (载荷起点, 长度)
        self.文本 = {}			# tag 号 → 文本元件信息
        self._扫(体, 起, 顶层=True)
        self._xml = None			# 懒加载：33MB 的 XML 只有查实例时才需要

    def _扫(self, 体, 起, 顶层):
        for 号, 载荷 in 遍历标签(体, 起):
            位 = 载荷.i
            if 号 == T_END:
                if not 顶层:
                    return
                continue
            if 号 == T_DEFINE_SPRITE:
                字 = 载荷.u16()
                载荷.u16()
                载 = len(载荷.b) - 载荷.i
                self.精灵[字] = (载荷.绝对, 载)
                载荷.skip(载)
            elif 号 in 精灵候选 and 号 != T_DEFINE_SPRITE:
                字 = 载荷.u16()
                帧 = 载荷.u16()			# ⚠ 第二个 u16 是**帧数**，不是内层长度；内层长度 = 载荷剩下的全部
                载 = len(载荷.b) - 载荷.i
                if 字 not in self.精灵 and 内层合法(载荷.b, 载荷.i, 载):
                    self.精灵[字] = (载荷.绝对, 载)
                载荷.skip(载)
            elif 号 == T_EXPORT_ASSETS:
                for _ in range(载荷.u16()):
                    字 = 载荷.u16()
                    名 = 载荷.str0()
                    self.符号.setdefault(名, 字)
                    self.反查[字] = 名
            elif 号 in (T_DOINIT_TAG, T_DOABC, T_DOABC2):
                if 载荷.u16() != 0:		# 只顶层 SWF 的（0）才要
                    continue
                while 载荷.i < len(载荷.b):
                    内 = 遍历标签(载荷.b, 载荷.i)
                    找 = next(内, None)
                    if 找 is None:
                        break
                    内号, 内载 = 找
                    载荷.i = 内载.i
                    if 内号 == T_SYMBOL_CLASS:
                        内载.u16()
                        for _ in range(内载.u16()):
                            字 = 内载.u16()
                            名 = 内载.str0()
                            self.符号.setdefault(名, 字)
                            self.反查[字] = 名
                        break
                    if 内号 == T_END:
                        break
            elif 号 in (11, 22, 25, 26, 32, 33, 35, 36, 37, 39, 43, 46, 56, 76, 82, 83, 86, 87, 88):
                pass
            if 顶层 and 号 == 0:
                return

    def 实例(self, 符号名, 钻=False):
        """该元件第 1 帧的**直接**实例列表（按出栈序 = 显示层级序），坐标已换成 px。

        实例坐标不自己解 tag：SWF 的 MATRIX 标志位是**高位先出**、且各家编码器的
        PlaceObject 变体位不一致（手解错过一次：整片 x/y 读成 0）。
        ⇒ 用 ffdec `-swf2xml` 的产物（它把矩阵解好了），只从**导出表**认符号名 → spriteId。
        """
        字 = self.符号.get(符号名)
        if 字 is None:
            raise SystemExit("导出表里没有这个符号：%s（先跑 --找 确认名字）" % 符号名)
        列 = []
        for 要 in self._xml.iter():
            if 要.get("type") != "DefineSpriteTag" or 要.get("spriteId") != str(字):
                continue
            内 = 要.find("subTags")
            if 内 is None:
                内 = 要.find("tags")		# 导出表用 <tags>、精灵内层用 <subTags>
            if 内 is None:
                break
            for 子 in 内:
                类 = 子.get("type") or ""
                if not 类.startswith("PlaceObject"):
                    continue
                矩 = 子.find("matrix")
                列.append({
                    "名": 子.get("name") or "",
                    "号": int(子.get("characterId", 0) or 0),
                    "符号名": self.反查.get(int(子.get("characterId", 0) or 0), ""),
                    "x": float(矩.get("translateX", 0)) / 20.0 if 矩 is not None else 0.0,
                    "y": float(矩.get("translateY", 0)) / 20.0 if 矩 is not None else 0.0,
                    "sx": float(矩.get("scaleX", 1)) if 矩 is not None else 1.0,
                    "sy": float(矩.get("scaleY", 1)) if 矩 is not None else 1.0,
                    "深": int(子.get("depth", 0) or 0),
                    "改位": (子.get("placeFlagMove") == "true")})
            break
        if not 列:
            print("tag %d「%s」在 XML 里没有实例（不是精灵，或 XML 不是这个 SWF 出的）" % (字, 符号名))
            sys.exit(1)
        return 字, 列


ffdecCLI = r"E:fdecfdec-cli.exe"


def 取XML(swf):
    """SWF → ffdec 的 XML（缓存到 swf 同目录的 .xml）。33MB 级，只在要实例坐标时才解。"""
    路 = os.path.splitext(swf)[0] + ".ffdec.xml"
    if not os.path.isfile(路):
        if not os.path.isfile(ffdecCLI):
            raise SystemExit("缺 ffdec（%s）⇒ 手动跑：ffdec-cli -swf2xml %s %s" % (ffdecCLI, swf, 路))
        import subprocess
        旧 = os.path.abspath(swf)
        if any(ord(c) > 127 for c in 旧):		# ffdec 吃不下中文路径：先拷到 ASCII 目录
            缓 = r"E:fdec\_set"
            os.makedirs(缓, exist_ok=True)
            副 = os.path.join(缓, os.path.basename(旧))
            shutil.copy2(旧, 副)
            出 = os.path.join(缓, os.path.basename(路))
            subprocess.run([ffdecCLI, "-swf2xml", os.path.basename(副), 出], cwd=缓, check=True)
            shutil.copy2(出, 路)
        else:
            subprocess.run([ffdecCLI, "-swf2xml", 旧, 路], check=True)
    import xml.etree.ElementTree as ET
    return ET.parse(路)


def 主():
    sys.stdout.reconfigure(encoding="utf-8")
    参 = sys.argv[1:]
    if not 参:
        print(__doc__)
        raise SystemExit(2)
    路 = 默认SWF
    if "--swf" in 参:
        i = 参.index("--swf")
        路 = 参[i + 1]
        del 参[i:i + 2]
    库_ = 库(路)
    if 参[0] == "--列表":
        for 名 in sorted(库_.符号):
            print("%-52s tag=%d" % (名, 库_.符号[名]))
        return
    if 参[0] == "--找":
        关键 = 参[1].lower()
        for 名 in sorted(库_.符号):
            if 关键 in 名.lower():
                print("%-52s tag=%d" % (名, 库_.符号[名]))
        return
    名 = 参[0]
    钻 = "--树" in 参
    库_._xml = 取XML(路)
    字, 列 = 库_.实例(名, 钻)
    if "--json" in 参:			# 给生成器直接吃，别再手抄坐标
        import json as _j
        出 = {}
        for 实 in 列:
            if not 实["名"]:
                continue
            出[实["名"]] = [实["号"], 实["符号名"], 实["x"], 实["y"], 实["sx"], 实["sy"]]
        print(_j.dumps({"符号": 名, "tag": 字, "件": 出}, ensure_ascii=False, indent=1))
        return
    print("「%s」tag=%d　第 1 帧 %d 个实例（坐标 px；twip 原值另列）" % (名, 字, len(列)))
    for k, 实 in enumerate(列):
        print("  %2d %-28s 号=%-5d %-26s x=%-8.2f y=%-8.2f 缩放=%s,%s%s" % (
            k, 实["名"] or "（未命名）", 实["号"], 实["符号名"], 实["x"], 实["y"], 实["sx"], 实["sy"],
            "  [改位]" if 实["改位"] else ""))


if __name__ == "__main__":
    主()
