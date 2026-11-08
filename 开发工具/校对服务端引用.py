#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""体检：全项目里 `fake_flash_server.py:NNNNN` 行号引用，是否还落在【项目内服务端拷贝】的合理位置。

为什么需要（2026-10-03，§3.89）：文档/代码注释里散落着几十个 `fake_flash_server.py:NNNNN`。
服务端拷贝一改（哪怕只在中间插几行），其后所有行号就集体漂移，引用会悄悄指错。
本脚本不做自动纠正（纠正要懂语义，机器容易帮倒忙），只做**体检**：
逐条打印"引用处 + 拷贝里该行现在的内容"，改过服务端后跑一遍、肉眼扫一遍即可。

用法：
    运行时/python/python.exe 开发工具/校对服务端引用.py
可选：`--only-def` 只报落在 def 上的（最常用锚点）；无 --only-def 时全列。
退出码恒 0（这是体检、不是断言门）。
"""
import io
import os
import re
import sys
from pathlib import Path

项目根 = Path(__file__).resolve().parent.parent
拷贝 = 项目根 / "服务端" / "runtime" / "tools" / "fake_flash_server.py"
引用式 = re.compile(r"fake_flash_server\.py:(\d{2,6})(?:[-–](\d{2,6}))?")
扫描目录 = ["移植进度与计划.md", "docs", "脚本", "测试", "开发工具", "场景", "数据"]
跳过后缀 = (".png", ".ttf", ".TTC", ".dat", ".swf", ".import", ".uid")


def 主():
    只看def = "--only-def" in sys.argv
    行 = io.open(拷贝, encoding="utf-8").read().splitlines()
    命中 = 0
    for 项 in 扫描目录:
        p = 项目根 / 项
        paths = [p] if p.is_file() else (list(p.rglob("*")) if p.is_dir() else [])
        for f in paths:
            if not f.is_file() or f.suffix in 跳过后缀 or f == 拷贝:
                continue
            try:
                txt = io.open(f, encoding="utf-8").read()
            except (UnicodeDecodeError, OSError):
                continue
            for m in 引用式.finditer(txt):
                n = int(m.group(1))
                content = 行[n - 1].strip() if 1 <= n <= len(行) else "<越界>"
                if 只看def and not content.startswith(("def ", "class ", "@")):
                    continue
                命中 += 1
                rel = os.path.relpath(f, 项目根)
                print(f"  {rel} → :{n}  | {content[:76]}")
    print(f"\n共 {命中} 处行号引用（对照 服务端/runtime/tools/fake_flash_server.py 当前 {len(行)} 行）。")
    print("提示：改过服务端后若有漂移，逐条按内容核对；新引用优先写『函数名』，行号只当辅助注。")
    return 0


if __name__ == "__main__":
    sys.exit(主())
