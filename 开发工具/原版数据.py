# -*- coding: utf-8 -*-
"""读 2.2.3 原版 GameData.dat（AMF3）与语言表的公共件。

为什么单独拆一个模块
--------------------
`导出技能数据.py` 与 `导出技能文案.py` 都要读同一份 GameData，共用两条口径：

1. **AMF3 读取逻辑照抄服务端**（`2.2.3/tools/fake_flash_server.py:5102-5231` 的 `Amf3Reader`），
   不去 import 那个 6 万行脚本（import 会因 dataclass 的模块注册问题炸掉）。
2. **每个分组的载荷是 zlib 压缩的 AMF3 字节串**，不是直接的对象；解压后还要再解一层。
   不知道这一点会得到"每组 0 条"的假象。

这两条重复写两份迟早会漂，所以放这里一份。

语言表
------
`2.2.3/map_extract/out/mainlib_as/scripts/en_US$message_properties.as` 是游戏内
`LangUtil.get("message", KEY)` 读的那张表；`en_US$ui_properties.as` 对应
`LangUtilUI.get(KEY)`（Bundle 名 "ui"）。两者都是 AS3 字面量，这里按
`"KEY":"VALUE"` 逐行解析（**值里可以有 `\\"` 转义**，281 行有这种情况，别用无脑正则）。

用法
----
    from 原版数据 import 读根, 取字符串段, 取顶层段, 解载荷, 语言
"""

import io
import os
import re
import struct
import zlib
from datetime import datetime
from typing import Any

def _找(环境变量: str, 候选: list, 标记文件: str) -> str:
    """原版目录不写死在本仓库里；按 环境变量 → 候选列表 逐个试，
    全落空时返回 ""，由调用方决定报错还是降级。"""
    列表 = ([环境变量值] if (环境变量值 := os.environ.get(环境变量)) else []) + 候选
    for 目录 in 列表:
        if 目录 and os.path.exists(os.path.join(目录, 标记文件)):
            return 目录
    return ""


## 上游单机端目录：优先 NARUTO_GAME_ROOT，否则找工程根下的 `2.2.3/`。
## 数据真值以所用服务端内的 GameData.dat 为准。
原版根 = _找("NARUTO_GAME_ROOT", [
    os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "2.2.3"),
], os.path.join("www", "act_web_nya_208_isolated", "dat", "GameData.dat"))
dat目录 = os.path.join(原版根, "www", "act_web_nya_208_isolated", "dat") if 原版根 else ""
数据源 = os.path.join(dat目录, "GameData.dat") if 原版根 else ""
反编译目录 = _找("NARUTO_AS_ROOT", [
    os.path.join(原版根, "map_extract", "out", "mainlib_as", "scripts") if 原版根 else "",
], "en_US$message_properties.as")
语言文件 = {
    "message": os.path.join(反编译目录, "en_US$message_properties.as"),
    "ui": os.path.join(反编译目录, "en_US$ui_properties.as"),
    # `LangUtilCore.get()` 读的是这第三个包（3346 条 message / ui 里**没有** `PVP_*_NO_ATTACK`
    # 这些键 —— 10-25 做 PK 判定才发现：只查 message+ui 会把"原版没这句"误判出来）。
    "core": os.path.join(反编译目录, "en_US$core_properties.as"),
}

## 有些原版静态表（SkillReqTable 等）不在 GameData 里，只能从反编译的 .as 源码抠。
## 两处解包目录都有，谁在先用谁。
_反编译候选 = [反编译目录]


def AS文件(*相对路径: str) -> str:
    """按相对路径（如 `com, mxw, data, SkillReqTable.as`）找反编译源文件，找不到返回 ""。"""
    for 根 in _反编译候选:
        if 根:
            路径 = os.path.join(根, *相对路径)
            if os.path.exists(路径):
                return 路径
    return ""


class Amf3Reader:
    """最小 AMF3 读取器。照抄 2.2.3/tools/fake_flash_server.py 的 Amf3Reader。"""

    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0
        self.string_refs: list = []
        self.object_refs: list = []
        self.trait_refs: list = []

    def read_value(self) -> Any:
        marker = self._read_u8()
        if marker in (0x00, 0x01):
            return None
        if marker == 0x02:
            return False
        if marker == 0x03:
            return True
        if marker == 0x04:
            value = self._read_u29()
            return value - 0x20000000 if value & 0x10000000 else value
        if marker == 0x05:
            return struct.unpack(">d", self._read(8))[0]
        if marker == 0x06:
            return self._read_string()
        if marker == 0x08:
            return self._read_date()
        if marker == 0x09:
            return self._read_array()
        if marker == 0x0A:
            return self._read_object()
        if marker == 0x0C:
            return self._read_byte_array()
        raise ValueError("Unsupported AMF3 marker: 0x%02x" % marker)

    def _read_date(self) -> datetime:
        header = self._read_u29()
        if not header & 1:
            return self.object_refs[header >> 1]
        value = datetime.fromtimestamp(struct.unpack(">d", self._read(8))[0] / 1000.0)
        self.object_refs.append(value)
        return value

    def _read_byte_array(self) -> bytes:
        header = self._read_u29()
        if not header & 1:
            return self.object_refs[header >> 1]
        value = self._read(header >> 1)
        self.object_refs.append(value)
        return value

    def _read_array(self) -> list:
        header = self._read_u29()
        if not header & 1:
            return self.object_refs[header >> 1]
        dense_count = header >> 1
        while self._read_string():
            self.read_value()
        items = [self.read_value() for _ in range(dense_count)]
        self.object_refs.append(items)
        return items

    def _read_object(self) -> dict:
        trait_info = self._read_u29()
        if not trait_info & 1:
            return self.object_refs[trait_info >> 1]
        if not trait_info & 2:
            trait = self.trait_refs[trait_info >> 2]
            sealed_names = trait["sealed_names"]
            is_dynamic = trait["dynamic"]
        else:
            is_dynamic = bool(trait_info & 0x08)
            sealed_count = trait_info >> 4
            self._read_string()
            sealed_names = [self._read_string() for _ in range(sealed_count)]
            self.trait_refs.append({"sealed_names": sealed_names, "dynamic": is_dynamic})

        obj: dict = {}
        self.object_refs.append(obj)
        for name in sealed_names:
            obj[name] = self.read_value()
        if is_dynamic:
            while True:
                name = self._read_string()
                if not name:
                    break
                obj[name] = self.read_value()
        return obj

    def _read_string(self) -> str:
        header = self._read_u29()
        if not header & 1:
            return self.string_refs[header >> 1]
        length = header >> 1
        if length == 0:
            return ""
        value = self._read(length).decode("utf-8", errors="replace")
        self.string_refs.append(value)
        return value

    def _read_u29(self) -> int:
        value = 0
        for index in range(4):
            byte = self._read_u8()
            if index == 3:
                return (value << 8) | byte
            value = (value << 7) | (byte & 0x7F)
            if not byte & 0x80:
                return value
        return value

    def _read_u8(self) -> int:
        return self._read(1)[0]

    def _read(self, size: int) -> bytes:
        if self.pos + size > len(self.data):
            raise ValueError("Truncated AMF3 packet")
        chunk = self.data[self.pos : self.pos + size]
        self.pos += size
        return chunk


_根缓存: dict = {}
_语言缓存: dict = {}


def 读根() -> dict:
    """GameData.dat 的顶层字典（缓存）。"""
    if "根" not in _根缓存:
        if not 数据源 or not os.path.exists(数据源):
            raise FileNotFoundError(
                "找不到原版 GameData.dat（当前解析到：%s）\n"
                "设 NARUTO_GAME_ROOT=原版 HYSJ 目录 即可，例如 <单机端目录>" % (数据源 or "未找到")
            )
        根 = Amf3Reader(open(数据源, "rb").read()).read_value()
        if not isinstance(根, dict):
            raise ValueError("GameData 根节点不是 AMF3 对象")
        _根缓存["根"] = 根
    return _根缓存["根"]


def 解载荷(载荷: Any) -> Any:
    """分组的载荷可能是 zlib 压缩过的 AMF3 字节串；是就再解一层，不是就原样返回。"""
    if isinstance(载荷, bytes):
        try:
            return Amf3Reader(zlib.decompress(载荷)).read_value()
        except Exception as 错:
            return {"__解压失败__": str(错)}
    return 载荷


def 取顶层段(名: str) -> Any:
    return 解载荷(读根().get(名))


def 取字符串段(名: str) -> dict:
    """GameData 顶层 `String` 段下的子表，如 Skill / JiNengShu / Npc。"""
    字符串段 = 读根().get("String")
    if not isinstance(字符串段, dict):
        return {}
    子表 = 解载荷(字符串段.get(名))
    return 子表 if isinstance(子表, dict) else {}


# AS3 字符串字面量：允许值里带 \" \\ \n \r \t \' 等转义
_语言行 = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*:\s*"((?:[^"\\]|\\.)*)"\s*,?\s*$')
_转义 = {"n": "\n", "r": "\r", "t": "\t", '"': '"', "'": "'", "\\": "\\", "/": "/"}


def _反转义(文本: str) -> str:
    out = []
    i = 0
    while i < len(文本):
        ch = 文本[i]
        if ch == "\\" and i + 1 < len(文本):
            nxt = 文本[i + 1]
            if nxt == "u" and i + 5 < len(文本) + 1:
                try:
                    out.append(chr(int(文本[i + 2 : i + 6], 16)))
                    i += 6
                    continue
                except ValueError:
                    pass
            out.append(_转义.get(nxt, nxt))
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def 读语言表(包: str = "message") -> dict:
    """解析 AS3 语言表字面量 → {KEY: 文案}（缓存）。"""
    if 包 in _语言缓存:
        return _语言缓存[包]
    路径 = 语言文件.get(包)
    表: dict = {}
    if 路径 and os.path.exists(路径):
        for 行 in io.open(路径, encoding="utf-8"):
            匹配 = _语言行.match(行.rstrip("\n"))
            if 匹配:
                表[匹配.group(1)] = _反转义(匹配.group(2))
    _语言缓存[包] = 表
    return 表


def 语言(键: str, 兜底: str = "") -> str:
    """`LangUtil.get` / `LangUtilUI.get` / `LangUtilCore.get` 的等价物：查不到就返回兜底
    （AS3 是返回键名本身）。三个包按 message → ui → core 顺序找。"""
    for 包 in ("message", "ui", "core"):
        表 = 读语言表(包)
        if 键 in 表:
            return 表[键]
    return 兜底 if 兜底 else 键
