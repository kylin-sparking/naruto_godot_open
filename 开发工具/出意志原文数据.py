# -*- coding: utf-8 -*-
"""从量具表取 YIZHI_LEAVE_DESC 原文 → 落成双方共用的纯文本真值文件。

为什么要这个文件：让 生成器(Python) 与 量具(GDScript) 各写一遍字符串转义，
两边都要处理 \\' \\r，已经反复写坏。改成**原文只存一份纯文本**，两边都直接读，
转义只发生这一次（AS3 → 本文件）。

扫描器按字符走、认反斜杠转义，不用正则（正则的字符类在 shell 里被转过一次就废了）。
"""
import io
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
源 = "开发工具/截意志学习页.gd"
出 = "数据/界面/意志_说明原文.txt"
src = open(源, encoding="utf-8").read()
i = src.find("const 说明原文 := (")
assert i > 0, "量具表里没有 说明原文 常量"
j = src.find("# YIZHI_LEAVE_DESC", i)
段 = src[i:j]

拼, 在串, 缓 = [], False, ""
for 字 in 段:
    if 缓:                      # 上一个字符是反斜杠：原样带进当前串
        if 在串:
            拼.append("\\" + 字)
        缓 = ""
        continue
    if 字 == "\\":              # GDScript 的 \' \r \n：先留字面，末尾统一解
        缓 = "\\"
        continue
    if 字 == '"':
        在串 = not 在串
        continue
    if 在串:
        拼.append(字)
文 = "".join(拼)
文 = 文.replace("\\r\\n", "\n").replace("\\r", "\n").replace("\\'", "'")
assert "font color" in 文 and "离开教室" in 文, "取到的原文不完整: " + 文[:80]
open(出, "w", encoding="utf-8", newline="\n").write(文)
print("写入 %s：%d 字" % (出, len(文)))
print(文.replace("\n", "\\n"))
