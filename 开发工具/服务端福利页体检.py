# -*- coding: utf-8 -*-
"""福利页（开心有礼）「场景烘的字面量 ↔ 服务端表」体检。

为什么要有这一条：GDScript 门**读不到 .py**，Python 体检又读不到 .tscn 的语义 ——
但本轮改的门槛数字恰好**两边各存一份**（服务端 `LIMITED_ACTIVITY_BOSS_TOTAL/_EACH`，
场景里烘成「活动期间累计击杀**N**只BOSS」那排文案）。两边漂了，玩家看到的就是
"页面写 100、服务端按 8 只算"。所以：
  * 数字层由本脚本钉（能读 .py）；
  * 行为层由 `测试/福利页去充值回归测试.gd` 钉（能跑 .gd）。
门里那两串 `累计门槛 / 额度门槛` 常量与本脚本读的是同一张表 —— 任一处改了，
跑一遍本脚本就会红。

用法（仓库根目录）：python 开发工具/服务端福利页体检.py
读三处：`fake_flash_server.py`（表 + 发的键）、`福利窗口.tscn`（烘的字面量）、
`活动窗口.gd`（客户端读的键）—— 两头对齐只有这里能同时看到。
"""
import ast
import io
import os
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
服务端 = os.path.join(根, "服务端", "runtime", "tools", "fake_flash_server.py")
场景路 = os.path.join(根, "场景", "界面", "窗口", "福利", "福利窗口.tscn")

红 = []


def 读(路):
    if not os.path.exists(路):
        raise SystemExit("!! 读不到 %s（脚本要从仓库根目录跑）" % 路)
    return io.open(路, encoding="utf-8", newline="").read()


def 表(源码, 名):
    """从服务端源码里取一个模块级字面量赋值（`NAME = (…)`）并求值。"""
    树 = ast.parse(源码)
    for 节 in 树.body:
        if isinstance(节, ast.Assign) and any(
                isinstance(目, ast.Name) and 目.id == 名 for 目 in 节.targets):
            return ast.literal_eval(节.value)
    raise SystemExit("!! 服务端源码里没有模块级赋值 %s" % 名)


服 = 读(服务端)
场 = 读(场景路)

# ── 1. 限时大奖：两张门槛表 ↔ 场景文案里烘的数字 ────────────────────────────
总表 = 表(服, "LIMITED_ACTIVITY_BOSS_TOTAL")
每表 = 表(服, "LIMITED_ACTIVITY_BOSS_EACH")
总门槛 = [int(t[0]) for t in 总表]
每门槛 = [int(t[0]) for t in 每表]

场景累计 = [int(x) for x in re.findall(r"累计击杀\[color=#ff0000\](\d+)\[/color\]只BOSS", 场)]
场景额度 = [int(x) for x in re.findall(r"每击杀满\[color=#ff0000\](\d+)\[/color\]只BOSS", 场)]
if 场景累计 != 总门槛:
    红.append("限时大奖累计档：场景烘的 %s ≠ 服务端 LIMITED_ACTIVITY_BOSS_TOTAL 的 %s" % (场景累计, 总门槛))
if 场景额度 != 每门槛:
    红.append("限时大奖额度档：场景烘的 %s ≠ 服务端 LIMITED_ACTIVITY_BOSS_EACH 的 %s" % (场景额度, 每门槛))
if len(场景累计) != 9 or len(场景额度) != 4:
    红.append("限时大奖档位数不对：累计 %d 条、额度 %d 条（原版是 9 + 4）" % (len(场景累计), len(场景额度)))

# ── 2. 场景里不许再有充值口径的字面量 ──────────────────────────────────────
for 禁 in ["累计充值", "充值元宝", "首次充值", "点券数", "元宝，获得以下物品"]:
    if 禁 in 场:
        红.append("场景里还留着 %r" % 禁)

# ── 3. 首杀礼包：场景文案 ↔ 服务端口径（2026-10-31 用户改：首日 → 首杀，条件 = 击杀一只 BOSS）──
首杀id = 表(服, "FIRST_DAY_GIFT_ITEM_ID")
if "首杀礼包" not in 场:
    红.append("场景里没有「首杀礼包」（页签/标题还是旧口径「首日礼包」）")
if "击杀任意BOSS一只即可领取" not in 场:
    红.append("场景「奖励说明」没写清首杀条件 —— 离线时玩家能看到的只有这一行")
if "首杀礼包" not in 服:
    红.append("服务端 config 的 fc.info.desc 不再提「首杀礼包」（页面引导与领奖条件对不上）")

# ── 4. 新服有礼免费档：送的是物品，场景得画同一件 ──────────────────────────
奖励 = 表(服, "NYA_CAPTURED_NEW_SERVER_REWARDS")
物id = 奖励[6000057][2][0][0]
if str(物id) not in 场:
    红.append("服务端 6000057 送的是 %d，场景「每档1」那格却没引用它（图标对不上）" % 物id)

# ── 5. 键名两头对齐：服务端发的键 ↔ 客户端读的键 ────────────────────────────
# GDScript 那边读的是 `活.get("bossKills", 0)` 这类**字面键名**，拼错了不报错、只读到 0。
# 离线门喂的是门里自己写的假载荷 ⇒ **只有这里**能同时看到两头。
客路 = os.path.join(根, "脚本", "界面", "窗口", "活动窗口.gd")
客 = 读(客路)
def 去注释(文, 前缀="#"):
    """只留代码行 —— 注释里还得留着讲原版行为（`# 原版读 chargeTotal…`），连着禁就成假红。"""
    return "\n".join(
        一 for 一 in 文.split("\n") if not 一.strip().startswith(前缀))


服码 = 去注释(服, "#")
客码 = 去注释(客, "#")
对齐 = [
    ("bossKills", "限时大奖 / 首杀礼包的击杀数"),
]
for 键, 说明 in 对齐:
    if 键 not in 服码:
        红.append("服务端不再下发 %r（%s），客户端还在读它就是静默读 0" % (键, 说明))
    if 键 not in 客码:
        红.append("客户端没读 %r（%s）—— 服务端发了也没人画" % (键, 说明))
# 桶名只有客户端有：服务端按 command 号分桶，名字是客户端 `_handle_czhuodong_dictionary` 起的。
if "first_kill" not in 客码:
    红.append("客户端没把 cmd 4 收进 first_kill 桶（首杀礼包页读到的是空 dict、永远置灰）")
for 旧 in ["cashbindRemaining", "chargeTotal", "first_gift_day_key", '"expired"', '"firstDay"', "first_day"]:
    if 旧 in 服码 or 旧 in 客码:
        红.append("%r 还在代码里（服务端发或客户端读）—— 这轮口径已退休，留着就是两头错位" % 旧)


def 函数段(名):
    树 = ast.parse(服)
    for 节 in ast.walk(树):
        if isinstance(节, (ast.FunctionDef, ast.AsyncFunctionDef)) and 节.name == 名:
            return ast.get_source_segment(服, 节) or ""
    return ""


# ── 6. 新服免费档的 count 必须是 1 ─────────────────────────────────────────
# 原版 `PrizeXinFuWindow.clickHandler:254-262`：`count == 0` 只弹「尚未达到领取条件」、**不发协议**。
# 服务端一度把 count 写成"领过没有"，于是这两条免费档永远领不到（§3.304 顺带修的）。
段 = 函数段("_send_czhuodong_new_server_status")
if not 段:
    红.append("服务端里找不到 _send_czhuodong_new_server_status（这条判据空转）")
else:
    if 段.count('"count": 1') != 2 or '"count": 0' in 段:
        红.append("新服免费档的 count 不再是恒 1（应两条 `\"count\": 1`，实际 %d 条，另有 0：%s）"
                  % (段.count('"count": 1'), '"count": 0' in 段))

# ── 7. 首杀礼包：状态载荷 + 领取门槛（击杀 ≥1 只 BOSS）─────────────────────
段 = 函数段("_send_czhuodong_first_kill_status")
if not 段:
    红.append("服务端里找不到 _send_czhuodong_first_kill_status（这条判据空转）")
else:
    if '"bossKills": state.activity_boss_kills' not in 段:
        红.append("cmd 4 没把 `bossKills` 发给客户端（首杀页拿不到当前击杀数，按钮永远灰）")
    if '"active": int(state.first_charge_claimed)' not in 段:
        红.append("cmd 4 的 `active` 不再读 `first_charge_claimed`（已领状态会丢）")
    if "expired" in 段 or "firstDay" in 段:
        红.append("cmd 4 还在发 `expired`/`firstDay` —— 这两个键随「建号当天」规则一起退休了")
if 函数段("_send_czhuodong_first_day_status"):
    红.append("旧函数 `_send_czhuodong_first_day_status` 没删干净（同名概念两套，后面必漂）")
handle = 函数段("handle_czhuodong")
if "activity_boss_kills < 1" not in handle:
    红.append("首杀礼包的领取门槛不再是「击杀 ≥1 只 BOSS」（cmd 4 的门没判击杀数）")
# ⚠️ 不能只查 `"activity_boss_kills" in handle` —— 同一函数里 cmd 4 的 `< 1` 也算命中，
#    把 cmd 1 那条 `table[gain_id][0]` 的比较删了照样绿（2026-10-31 反向对照 M16 实测）。
if "state.activity_boss_kills < table[gain_id][0]" not in handle:
    红.append("限时大奖领取的门槛不再比 `activity_boss_kills`（还是按充值额放行？）")


# ── 8. 限时大奖活动期 = 本月月初到月末（行为层：把函数真跑一遍）───────────────
# 静态 grep 只能证明"提到了 now.year/month"；真正的口径是返回值 ⇒ 这里 exec 那段源码再调用。
import textwrap
from datetime import datetime as _dt, timedelta as _td

起 = 止 = None
段 = 函数段("_limited_activity_period")
if not 段:
    红.append("服务端里找不到 _limited_activity_period（活动期这条判据空转）")
else:
    节 = ast.parse(textwrap.dedent(段)).body[0]
    命名 = {"datetime": _dt, "timedelta": _td}
    exec(compile(ast.Module(body=[节], type_ignores=[]), "<活动期>", "exec"), 命名)
    起, 止 = 命名["_limited_activity_period"]()
    今 = _dt.now()
    应起 = _dt(今.year, 今.month, 1)
    应止 = (_dt(今.year + 1, 1, 1) if 今.month == 12 else _dt(今.year, 今.month + 1, 1)) - _td(seconds=1)
    if (起, 止) != (应起, 应止):
        红.append("限时大奖活动期不是本月月初到月末：%s ~ %s（应 %s ~ %s）" % (起, 止, 应起, 应止))

if 红:
    for 一 in 红:
        print("!! " + 一)
    print("服务端福利页体检：失败 %d 项" % len(红))
    raise SystemExit(1)
print("服务端福利页体检：通过（累计 %s / 额度 %s 与场景一致 · 无充值字面量 · 首杀 %d · "
      "新服免费档送 %d · 活动期 %s ~ %s）" % (总门槛, 每门槛, 首杀id, 物id, 起, 止))
