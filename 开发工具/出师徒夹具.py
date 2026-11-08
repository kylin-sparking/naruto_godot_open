# -*- coding: utf-8 -*-
"""生成 `数据/界面/师徒夹具.json` —— 师徒族五条下行帧的**原文**，段序从服务端源码逐 token 反查。

为什么不手写：手写的那份改了服务端也不会红（10-14 那次 187 偏一格、305 条门全绿而实机死）。
这里把 `fake_flash_server.py` 里那几段拼接式**按行区间抠出来**、拆成 token 一比一比对，
对不上或行号过期（`send_text(` 找不到）就直接 `SystemExit(1)`。

跑法：`python 开发工具/出师徒夹具.py` → 写 `数据/界面/师徒夹具.json`，全过 exit 0。
"""
import io
import json
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
服务端源 = os.path.join(工程, "服务端", "runtime", "tools", "fake_flash_server.py")
常量源 = os.path.join(工程, "服务端", "runtime", "tools", "multiplayer_backend.py")
出 = os.path.join(工程, "数据", "界面", "师徒夹具.json")

## 帧名 → (起行, 止行, 期望 token 列表)。行号 = 2026-10-15 现查这一份 `fake_flash_server.py`。
## ⚠ 行号过期不会静默：`send_text(` 找不到 ⇒ 直接红并点名去核源码。
帧表 = {
    "推荐师傅": (22460, 22478,
            ["{op(ServerOpcode.TUTOR)}", ":", "{action}", ":", "{rows}", ":", "{suffix}"]),
    "推荐徒弟": (22460, 22478,
            ["{op(ServerOpcode.TUTOR)}", ":", "{action}", ":", "{rows}", ":", "{suffix}"]),
    "拜师申请": (22729, 22732,
            ["{op(ServerOpcode.TUTOR)}", ":4:", "{self.character.character_id}",
             ":", "{self.character.name}"]),
    "收徒申请": (22755, 22758,
            ["{op(ServerOpcode.TUTOR)}", ":5:", "{self.character.character_id}",
             ":", "{self.character.name}"]),
    "关系列表": (22353, 22373,
            ["{op(ServerOpcode.TUTOR)}", ":14:", "{'@'.join(rows)or'-'}"]),
}
## 两种"一行"的段序（`"&".join(str(v) for v in (...))` 那个元组）
行表 = {
    "推荐行": (22444, 22459, ["name", "id", "face", "level", "job"]),
    "关系行": (22327, 22352, ["id", "name", "level", "job", "face", "line_id",
            "gender", "relation_type", "1", "0", "createdAt"]),
}
## 等级带常量（谁能进候选、徒弟上限）
常量表 = {"TUTOR_STUDENT_MIN_LEVEL": 10, "TUTOR_LEVEL": 60, "TUTOR_MAX_STUDENTS": 5}

全部行 = io.open(服务端源, encoding="utf-8").readlines()


def 抠(起, 止):
    return "".join(全部行[起 - 1:止])


def 拆模板(文本):
    """把 `f"{op(..)}:4:{a}:{b}"` 拆成 token 列表；相邻 f-string 先拼起来再拆。"""
    词, 缓, i = [], "", 0
    while i < len(文本):
        c = 文本[i]
        if c == "{":
            if 缓:
                词.append(缓)
                缓 = ""
            j = 文本.index("}", i)
            词.append("{%s}" % 文本[i + 1:j].strip().replace(" ", ""))
            i = j + 1
        else:
            缓 += c
            i += 1
    if 缓:
        词.append(缓)
    return 词


def 反查帧(名):
    起, 止, 期望 = 帧表[名]
    文 = 抠(起, 止)
    处 = 文.find("send_text(")
    if 处 < 0:
        raise SystemExit("反查失败：%s 的行区间 %d-%d 里没有 `send_text(` ⇒ 服务端行号过期了，先去核源码"
                % (名, 起, 止))
    串 = re.findall(r'f?"((?:[^"\\]|\\.)*)"', 文[处:], re.S)
    if not 串:
        raise SystemExit("反查失败：%s 那段没提出 f-string" % 名)
    实 = 拆模板("".join(串))
    净 = [re.sub(r"\s+", "", t) for t in 期望]
    if 实 != 净:
        raise SystemExit("%s 的段序与服务端源码不一致：\n  源码 = %s\n  夹具 = %s" % (名, 实, 净))
    return 净


def 元组段(正文, 起搜="for value in ("):
    """取 `for value in (…)` 括号里那串，按**顶层逗号**切，再把每段压成键名。"""
    处 = 正文.find(起搜)
    if 处 < 0:
        raise SystemExit("抠不到 `%s` ⇒ 那一行的拼法变了，先去核源码" % 起搜)
    开 = 处 + len(起搜) - 1        # 指向那个 `(`
    深, 体 = 0, ""
    for i in range(开, len(正文)):
        c = 正文[i]
        if c == "(":
            深 += 1
            if 深 == 1:
                continue
        elif c == ")":
            深 -= 1
            if 深 == 0:
                break
        if 深 >= 1:
            体 += c
    段, 缓, 深 = [], "", 0
    for c in 体:
        if c in "([{":
            深 += 1
        elif c in ")]}":
            深 -= 1
        if c == "," and 深 == 0:
            段.append(缓)
            缓 = ""
        else:
            缓 += c
    if 缓.strip():
        段.append(缓)
    键 = []
    for s in 段:
        ## ⚠ **别先删空格再取键名**：`online.line_id if online is not None else -1`
        ## 删掉空格会粘成 `line_idifonlineisnotNoneelse`，取出来的键名就成了天书。
        m = re.search(r'get\("([^"]+)"', s)
        if not m:
            m = re.search(r"\(\s*([A-Za-z_]\w*)", s)
        if not m:
            m = re.search(r"\.([A-Za-z_]\w*)", s)
        键.append(m.group(1) if m else re.sub(r"\s+", "", s).replace('"', ""))
    return 键


def 反查行(名):
    起, 止, 期望 = 行表[名]
    实 = 元组段(抠(起, 止))
    if 实 != 期望:
        raise SystemExit("%s 的段序与服务端源码不一致：\n  源码 = %s\n  夹具 = %s" % (名, 实, 期望))
    return 实


def 读常量():
    文 = io.open(常量源, encoding="utf-8").read()
    得 = {}
    for 名, 值 in 常量表.items():
        m = re.search(r"^%s\s*=\s*(\d+)" % 名, 文, re.M)
        if not m:
            raise SystemExit("常量 %s 在 multiplayer_backend.py 里找不到了" % 名)
        if int(m.group(1)) != 值:
            raise SystemExit("常量 %s 变了：源码 = %s，夹具期望 = %s" % (名, m.group(1), 值))
        得[名] = 值
    return 得


for 名 in 帧表:
    反查帧(名)
段序 = {名: 反查行(名) for 名 in 行表}
带 = 读常量()

# ── 出夹具（号/名与交易、摆摊那两份一致，方便两个号对测）─────────────────
我号, 我名, 我脸, 我职, 我等 = 1001, "木叶忍者", 10000201, 100, 72
他号, 他名, 他脸, 他职, 他等 = 1002, "油女澪", 10000204, 200, 23
另号, 另名, 另脸, 另职, 另等 = 1003, "夕日光", 10000205, 300, 12


def 推行(名, 号, 脸, 等, 职):
    return "%s&%d&%d&%d&%d" % (名, 号, 脸, 等, 职)


def 关系行(名, 号, 等, 职, 脸, 关):
    return "&".join(str(v) for v in (号, 名, 等, 职, 脸, 0, 0, 关, 1, 0, 1700000000000))


原文 = {
    "推荐师傅": "77:17:%s:%d" % ("@".join([推行(他名, 他号, 他脸, 他等, 他职),
            推行(另名, 另号, 另脸, 12, 另职)]), 1),
    "推荐徒弟": "77:18:%s:%d" % (推行(他名, 他号, 他脸, 他等, 他职), 1),
    "拜师申请": "77:4:%d:%s" % (他号, 他名),
    "收徒申请": "77:5:%d:%s" % (我号, 我名),
    "关系列表": "77:14:%s" % "@".join([关系行(他名, 他号, 他等, 他职, 他脸, -2),
            关系行(另名, 另号, 12, 另职, 另脸, -1)]),
    "空推荐": "77:17:-:0",
}
期望师傅行 = [{"name": 他名, "charId": 他号, "face": 他脸, "level": 他等, "job": 他职},
        {"name": 另名, "charId": 另号, "face": 另脸, "level": 12, "job": 另职}]
期望徒弟行 = [{"name": 他名, "charId": 他号, "face": 他脸, "level": 他等, "job": 他职}]

数 = {
    "_说明": "由 开发工具/出师徒夹具.py 生成；每条帧的段序都与服务端逐 token 反查过"
             "（`_tutor_recommended_row` / `_send_tutor_recommendations` / `_tutor_relation_row`"
             " / `_send_tutor_relation_list` / `handle_tutor` 的 action 3、4），"
             "改服务端那几段拼接式会让生成器直接红。离线门把这些原文喂进 `后端连接._handle_bridge_text`。",
    "帧行区间": {k: [v[0], v[1]] for k, v in 帧表.items()},
    "推荐行段": 段序["推荐行"],
    "关系行段": 段序["关系行"],
    "等级带": 带,
    "我号": 我号, "我名": 我名, "他号": 他号, "他名": 他名, "另号": 另号, "另名": 另名,
    "原文": 原文,
    "期望师傅行": 期望师傅行,
    "期望徒弟行": 期望徒弟行,
    "期望在线数": 1, "期望带徒数": 1,
    "期望关系": [{"charId": 他号, "relation": -2}, {"charId": 另号, "relation": -1}],
}

# ── 自审：每条原文自己再解一遍，段数/键名必须对得上 ────────────────────
自 = []
for 名, 帧 in 原文.items():
    if not 帧.startswith("77:"):
        自.append("%s 首段不是 77" % 名)
for 名, 期 in [("推荐师傅", 4), ("推荐徒弟", 4), ("拜师申请", 3), ("收徒申请", 3), ("空推荐", 3)]:
    if len(原文[名].split(":", 期 - 1)) != 期:
        自.append("%s 不是 %d 段" % (名, 期))
解 = []
行串 = 原文["推荐师傅"].split(":")[2]
for 一 in 行串.split("@"):
    段 = 一.split("&")
    if len(段) != len(段序["推荐行"]):
        自.append("推荐师傅一行不是 %d 段：%s" % (len(段序["推荐行"]), 一))
        continue
    解.append(dict(zip(["name", "charId", "face", "level", "job"], 段)))
for 一, 期 in zip(解, 期望师傅行):
    if int(一["charId"]) != 期["charId"] or int(一["job"]) != 期["job"] \
            or str(一["name"]) != 期["name"]:
        自.append("推荐师傅行解回来对不上：%s vs %s" % (一, 期))
关系 = 原文["关系列表"].split(":", 2)[2]
for 一 in 关系.split("@"):
    if len(一.split("&")) != len(段序["关系行"]):
        自.append("关系一行段数不对：%s" % 一)
if 原文["空推荐"].split(":")[2] != "-":
    自.append("空推荐那一格不是 `-`（客户端按这个判空表）")

io.open(出, "w", encoding="utf-8", newline="\n").write(
    json.dumps(数, ensure_ascii=False, indent=1) + "\n")
print("写了 数据/界面/师徒夹具.json（%d 条原文）" % len(原文))
if 自:
    print("自审红：")
    for e in 自:
        print("  -", e)
    raise SystemExit(1)
print("自审：全部原文解回一致（推荐行 5 段、关系行 11 段、常量三条对得上），退出码 0")
