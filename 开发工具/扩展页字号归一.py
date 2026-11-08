# -*- coding: utf-8 -*-
"""把人物扩展页（秘术 / 血继界限那七页 + 页内弹窗）里烘进 `.tscn` 的小字号统一抬到 **12**。

为什么是 12：原版这几页**没有任何一处文字小于 12** ——
`MLabel.initUI:218-223`、`TextArea2.createTf:77-82`、`MButton.init:148-155`、`MButton3:123-131`
全部 `size=12 + font=COMMON_FONT(宋体)`；`MBar.labelFormat`（`RouQuanPanel.as:455-459`、
`JieYinPanel.as:502-513`）压根不设 size ⇒ 吃 Flash 默认 12；语言表里的 html 只带 `color=`、
**没有一处带 `size=`**。而他那一版场景烘的是 8/9/10/11，宋体在这些号上**打不中内嵌点阵**
（`素材/界面/simsun_原版.ttf` 有 EBDT/EBLC，命中表以 12 为主），于是退回轮廓 + 灰度抗锯齿，
观感就是用户 2026-10-17 报的「小、暗、不清晰」（§3.184 第 1 条同族，那轮只治了八门的门钮）。

用法：
    python 开发工具/扩展页字号归一.py          # 就地改（保留每个文件自己的行尾）
    python 开发工具/扩展页字号归一.py --检查    # 只报告，不改；有漂移时退出码 1
"""
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")

目录 = "场景/界面/窗口/人物/页面/"
文件们 = [
    "八门页.tscn", "手里剑页.tscn", "写轮眼页.tscn", "结印页.tscn",
    "柔拳页.tscn", "寄坏之术页.tscn", "轮回六道页.tscn",
    "开通穴道弹窗.tscn", "修炼提速弹窗.tscn", "手里剑突破瓶颈弹窗.tscn",
]
# 只抬 theme_override 的两条 key；>=12 的一律不动（22/15 那两处是大标题）。
# 末尾用 `(?=\r?$)` 而不是 `$`：`寄坏之术页.tscn` 是 CRLF，`$` 会把 `\r` 吃进匹配里。
正则 = re.compile(r"(theme_override_font_sizes/(?:font_size|normal_font_size) = )(?:[89]|10|11)(?![0-9.])(?=\r?$)", re.M)
检查 = "--检查" in sys.argv
总改 = 0
for 名 in 文件们:
    路径 = 目录 + 名
    字节 = open(路径, "rb").read()
    文本 = 字节.decode("utf-8")
    新, 次数 = 正则.subn(lambda m: m.group(1) + "12", 文本)
    总改 += 次数
    print("%-28s 抬升 %d 处" % (名, 次数))
    if 次数 and not 检查:
        open(路径, "wb").write(新.encode("utf-8"))
print("合计 %d 处%s" % (总改, "" if not 检查 else "（--检查：未写盘）"))
sys.exit(1 if (检查 and 总改) else 0)
