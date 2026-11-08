# -*- coding: utf-8 -*-
"""摆摊回帧夹具生成器 —— **样本串不许手写猜**。

为什么要有这个文件（工程里已经栽过：187 那条夹具的段序偏一格，305 条判据全绿而真机是死的）：
离线门要喂给 `_handle_stall_text` 的那条 `1296:1:` 原文，段序/分隔符必须和**服务端真发的那一条**一致。
所以这里不直接拼字符串，而是先把服务端 `_send_stall` 的 f-string 从源码里抠出来，
拆成「字面量 + 占位符」的序列，和我这边声明的模板逐 token 比；比不过就红着退出（exit 1）。
服务端哪天改了拼接式，这里立刻红 ⇒ 门不会悄悄跟着过期。

跑法：`python 开发工具/出错摊夹具.py`（幂等，重跑字节不变）
产物：`数据/界面/摆摊夹具.json` = {"原文": 服务端形状的一条帧, "摊主号", "摊主名", "摊名", "期望行": [...]}
"""
import io
import json
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
服务端源 = os.path.join(工程, "服务端", "runtime", "tools", "fake_flash_server.py")
出 = os.path.join(工程, "数据", "界面", "摆摊夹具.json")

# 我对「摊位内容」这一帧的理解（真值：`真值/窗口/随身摊位窗.md` §⑥）。
# 这张表**照的是服务端源码 token 的原样**（字面量段连冒号一起算一段），
# 所以 `反查()` 是逐 token 比字符串，不是比"意思差不多"。
行模板 = ["{op(ServerOpcode.STALL_ACTION)}", ":1:", "{stall.owner_id}", ":", "{stall.owner_name}",
          ":", "{stall.name}", ":", "{@.join(rows) or '-'}", ":", "{@.join(stall.logs[-30:]) or '-'}"]
## 客户端解出来的段序（`后端连接._handle_stall_text`）：fields[0]=1296、[1]=子命令 1、
## [2]=摊主号、[3]=摊主名、[4]=摊名、[5]=行表、[6]=日志 ⇒ 整帧按 `:` 切必须正好 7 段。
客户端段序 = ["opcode", "子命令=1", "摊主号", "摊主名", "摊名", "行表", "日志"]


def 抠源码片段(起, 止):
    """按行号区间取源码文本（行号 1 起，含端点）。"""
    with io.open(服务端源, encoding="utf-8") as f:
        return "".join(f.readlines()[起 - 1:止])


def 拆模板(文本):
    """把 `f"{op(...)}:1:{a}:{b}"` 这种串拆成 token 列表；`@`.join(...) 归一成 `{@.join(...)}`。"""
    tokens = []
    buf = ""
    i = 0
    while i < len(文本):
        c = 文本[i]
        if c == "{":
            if buf:
                tokens.append(buf)
                buf = ""
            j = 文本.index("}", i)
            内 = 文本[i + 1:j].strip()
            内 = 内.replace("'@'", "@").replace('"@"', "@").replace(" or '-'", " or '-'")
            tokens.append("{%s}" % 内)
            i = j + 1
        else:
            buf += c
            i += 1
    if buf:
        tokens.append(buf)
    return tokens


def 反查():
    文 = 抠源码片段(25777, 25812)
    # 服务端那条 send_text 是**两个相邻 f-string 隐式拼接**（跨行），只取第一个会少一半段。
    起 = 文.index("send_text(")
    串 = re.findall(r'f?"((?:[^"\\]|\\.)*)"', 文[起:], re.S)
    if not 串:
        raise SystemExit("反查失败：服务端里找不到 `_send_stall` 的那条 send_text ⇒ 行号过期了，先去核源码")
    实 = 拆模板("".join(串))
    if 实 != 行模板:
        raise SystemExit("摊位内容帧的段序与服务端源码不一致：\n  源码 = %s\n  夹具 = %s" % (实, 行模板))
    # 行的列序：`"."join(( str(..), …, encoded ))` 里那六项 —— 前五套 str()、第六项是裸变量
    列文 = 抠源码片段(25797, 25808)
    列实 = [t.strip() for t in re.findall(r'str\(([A-Za-z_0-9.]+)\)', 列文)]
    对应 = ["listing.uid", "stall.owner_id", "listing.item_type",
            "listing.point_price", "listing.cash_price"]
    if 列实 != 对应:
        raise SystemExit("挂牌那一行前五列的列序与服务端源码不一致：源码 %s vs 夹具 %s" % (列实, 对应))
    if not re.search(r'listing\.cash_price\),\s*encoded,', 列文):
        raise SystemExit("挂牌行第六列不是裸的 `encoded` ⇒ 负载位置要重核")
    # 负载里 `&` 被换成 `!`（防把行分隔符吃掉）
    if "&\" , \"!" not in 文 and 'replace("&", "!")' not in 文:
        raise SystemExit("没在服务端 `_send_stall` 里看到 `replace(\"&\", \"!\")` ⇒ 还原口径要重核")
    return 实


def 物品行(uid, 摊主号, 物品号, 数量, 积分价, 现金价):
    """负载 = 服务端 `_encode_item_payload` 的段序：`族&物品号&槽&数量&0&0&可交易&主人&0&唯一号`（`:50832-50843`）。"""
    负 = "&".join(["2", str(物品号), "7", str(数量), "0", "0", "1", "油女澪", "0", str(uid)])
    return "&".join([str(uid), str(摊主号), "2", str(积分价), str(现金价), 负.replace("&", "!")])


def 宠物行(uid, 摊主号, 宠物种, 宠物名, 等级, 积分价, 现金价):
    """负载 = `_encode_pet` 的**前 12 段**（`:50855+`）：`宠物号&位置&1&0&0&可交易&主人&0&唯一号&主人号&宠物名&等级`。
    行渲染只用到第 0/8/10 段，后面那一大串属性本轮不画 ⇒ 截到这里，门里核对的也只有这几段。"""
    负 = "&".join([str(宠物种), "5", "1", "0", "0", "1", "油女澪", "0", str(uid), str(摊主号), 宠物名, str(等级)])
    return "&".join([str(uid), str(摊主号), "3", str(积分价), str(现金价), 负.replace("&", "!")])


def 货币行(uid, 摊主号, 是金币, 金币数, 元宝数):
    """货币档负载 = `是否金币!金币数!元宝数`（`:25787-25791`，本身就是 `!` 分隔）。"""
    return "&".join([str(uid), str(摊主号), "10", "0", "0",
                     "%d!%d!%d" % (是金币, 金币数, 元宝数)])


def 主():
    if not os.path.isfile(服务端源):
        raise SystemExit("找不到服务端源：%s" % 服务端源)
    实 = 反查()
    摊主号, 摊主名, 摊名 = 1002, "油女澪", "澪的杂货摊"
    列 = [
        物品行(5001, 摊主号, 10000001, 5, 1000, 0),		# 熊皮 ×5，1000 铜钱
        物品行(5002, 摊主号, 10000002, 1, 500, 20),		# 裂开的蛇皮 ×1，500 铜钱 + 20 元宝
        宠物行(5003, 摊主号, 101, "蜃", 12, 8888, 0),
        货币行(5004, 摊主号, 1, 10000, 30),				# 卖 1 万金币，要 30 元宝
    ]
    日志 = "油女渚购买了熊皮×5"
    原文 = ":".join([str(1296), "1", str(摊主号), 摊主名, 摊名, "@".join(列), 日志])
    期望 = [
        {"uid": 5001, "kind": 2, "point_price": 1000, "cash_price": 0},
        {"uid": 5002, "kind": 2, "point_price": 500, "cash_price": 20},
        {"uid": 5003, "kind": 3, "point_price": 8888, "cash_price": 0},
        {"uid": 5004, "kind": 10, "point_price": 0, "cash_price": 0},
    ]
    # 自检：这条原文按 `:` 切必须是 7 段（第 6 段里不许有冒号 ⇒ 摊名/日志都不许带冒号）
    if len(原文.split(":")) != 7:
        raise SystemExit("夹具自审失败：整帧应该是 7 段，实得 %d 段" % len(原文.split(":")))
    数据 = {
        "_说明": ("由 开发工具/出错摊夹具.py 生成；段序与服务端 `_send_stall`（fake_flash_server.py:25797）"
                "逐 token 反查过，改服务端那段代码会让生成器直接红。离线门把它喂进真后端的解析入口。"),
        "模板": 实,
        "摊主号": 摊主号, "摊主名": 摊主名, "摊名": 摊名, "日志": 日志,
        "原文": 原文, "期望行": 期望,
    }
    os.makedirs(os.path.dirname(出), exist_ok=True)
    with io.open(出, "w", encoding="utf-8") as f:
        json.dump(数据, f, ensure_ascii=False, indent=1, sort_keys=False)
        f.write("\n")
    print("反查通过：段序 %s" % 实)
    print("写出 %s（原文 %d 字节，行 %d 条）" % (os.path.relpath(出, 工程), len(原文.encode("utf-8")), len(列)))


主()
