# -*- coding: utf-8 -*-
"""从**实机 MainLib.swf** 里取 `KEYBOARD_SCHEME_*` 六条文案 → `数据/界面/快捷键_补文案.json`。

为什么要有这个工具：`真值文档/UI/texts/message.json`（3340 键）里**根本没有** SCHEME 这一族，
而 `KeyboardFrame.as:766-793` 的方案钮文案全走 `CN.KEYBOARD_SCHEME_*`
⇒ 早先的快捷键窗把 5 枚方案钮 + 保存方案渲成了**空标签**，看着像没做完。
`LangUtil.as:22-38` 的兜底是「查不到就回键名本身」，所以原版绝不会显示空白 —— 空白是移植的错，
不是原版的错，更不是可以自造中文的理由。

这六条其实在 SWF 里：Flex 的 `message` ResourceBundle 编进了 ABC 常量池，
键名与值都是 ULEB128 长度前缀串。锚点取最后一个 getter 特征名，往后顺读 6 条，
并断言第 6 条后面紧跟 `keySchemes`（下一族符号名）—— 读歪一位就整条工具报错，不会静默出错值。

跑法：python 开发工具/出快捷键补文案.py
"""
import io
import json
import os
import sys
import zlib

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
原版根 = os.environ.get("NARUTO_GAME_ROOT") or os.path.join(工程, "..", "2.2.3")
SWF = os.path.join(原版根, "www", "act_web_nya_208_isolated", "asset", "MainLib.swf")
出 = os.path.join(工程, "数据", "界面", "快捷键_补文案.json")

# 锚点：ABC 里最后一个 SCHEME getter 特征名（`类/成员/get`），它后面就是这批值串
锚 = b"com.mxw.common.gameCommon.language:CN/KEYBOARD_SCHEME_SAVE_CONFIRM/get"
# 特征名出现顺序 == 值串顺序（键名块与 getter 块同序，见下面对第 6 条之后紧跟串的断言）
序 = ["KEYBOARD_SCHEME_PREFIX", "KEYBOARD_SCHEME_SAVE", "KEYBOARD_SCHEME_EMPTY_SUFFIX",
      "KEYBOARD_SCHEME_EMPTY_NOTICE", "KEYBOARD_SCHEME_SAVED_NOTICE", "KEYBOARD_SCHEME_SAVE_CONFIRM"]
尾 = b"keySchemes"


def 读串(buf, i):
    """ABC 常量池条目：ULEB128 长度 + 该长度的 modified-UTF8 字节。返回 (文本, 新下标)。"""
    n = 0
    移 = 0
    while True:
        b = buf[i]
        i += 1
        n |= (b & 0x7F) << 移
        移 += 7
        if not b & 0x80:
            break
    文 = buf[i:i + n]
    if len(文) != n:
        raise SystemExit("长度前缀越界：n=%d 剩=%d" % (n, len(文)))
    return 文.decode("utf-8"), i + n


def 主():
    buf = open(SWF, "rb").read()
    if buf[:3] != b"CWS":
        raise SystemExit("预期 CWS（zlib 压缩）SWF，实际 %r" % buf[:3])
    p = zlib.decompress(buf[8:])
    if p.count(锚) != 1:
        raise SystemExit("锚点命中 %d 次，不是唯一一处 ⇒ 别猜，先查 SWF 版本" % p.count(锚))
    i = p.index(锚) + len(锚)
    表 = {}
    for 键 in 序:
        文, i = 读串(p, i)
        if not 文:
            raise SystemExit("读到空串，位置歪了：%s" % 键)
        表[键] = 文
    后, _ = 读串(p, i)
    if 后 != 尾.decode("utf-8"):
        raise SystemExit("第 6 条之后不是 %r 而是 %r ⇒ 顺读错位，值不可信" % (尾.decode(), 后))
    # 内容自证：这三条的语义只有一种排法对得上，排错位就会撞到这条
    if 表["KEYBOARD_SCHEME_SAVE"] != "保存方案" or 表["KEYBOARD_SCHEME_PREFIX"] != "方案":
        raise SystemExit("取到的值与语义不符（SAVE 应为「保存方案」、PREFIX 应为「方案」）：%s" % 表)
    with io.open(出, "w", encoding="utf-8") as f:
        json.dump({"出处": "MainLib.swf ABC 常量池（Flex message ResourceBundle），锚点 %r" % 锚.decode(),
                   "说明": "真值文档/UI/texts 那份导出表缺这一族，LangUtil 查不到会回键名本身 ⇒ 原版不空白",
                   "表": 表}, f, ensure_ascii=False, indent=1)
    for 键 in 序:
        print("   %-32s 「%s」" % (键, 表[键]))
    print("→ %s（%d 条）" % (出, len(表)))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    主()
