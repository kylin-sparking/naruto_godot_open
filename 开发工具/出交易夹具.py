# -*- coding: utf-8 -*-
"""交易回帧夹具生成器 —— **样本串不许手写猜**（同 `出错摊夹具.py` 的手法，换一族帧）。

离线门要喂给 `后端连接._handle_trade_text` 的那些 `335:…` 原文，段序/分隔符必须和
**服务端真发的那一条**一致。所以这里不直接拼字符串，而是把服务端源码里的 f-string
抠出来拆成「字面量 + 占位符」的 token 序列，和这边声明的模板**逐 token 比**；
比不过就红着退出（exit 1）。服务端哪天改了拼接式或挪了行号，这里立刻红
⇒ 门不会悄悄跟着过期（工程里已经栽过一次：187 那条夹具段序偏一格，305 条判据全绿而真机是死的）。

顺手把两条**负载**的段序也钉住：
· 物品 `_encode_item_payload` 的 `common_fields` 十段（`:50832-50843`）；
· 宠物 `_encode_pet` 的三十一段（`:16960-16969`）—— ⚠ 客户端的 `_parse_pet_fields`
  要求 **≥31 段**才返回非空（`后端连接.gd:3260`），所以宠物负载不许像摊位夹具那样截到 12 段，
  截短了门会看到"喂了帧、格子里却没东西"。

跑法：`python 开发工具/出交易夹具.py`（幂等，重跑字节不变）
产物：`数据/界面/交易夹具.json` = 每条帧的原文 + 客户端该解出什么。
"""
import io
import json
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
服务端源 = os.path.join(工程, "服务端", "runtime", "tools", "fake_flash_server.py")
出 = os.path.join(工程, "数据", "界面", "交易夹具.json")

PI = "{op(ServerOpcode.PLAYER_INTERACTION)}"

## 帧模板表：名 → (源码行区间起, 止, 期望 token 序列)。
## token 就是 f-string 拆出来的样子：`{…}` 是占位符，其它是连冒号一起算的字面量。
帧表 = {
	"邀请": (23801, 23804, [PI, ":3:", "{character_id}", ":", "{self.character.name}"]),
	"婉拒后取消": (23811, 23813, [PI, ":9:0"]),
	"开始给邀请者": (23826, 23830, [PI, ":22:0:", "{inviter.character.character_id}", ":",
					"{inviter.character.name}", ":1:", "{character_id}", ":", "{self.character.name}"]),
	"开始给接受者": (23831, 23835, [PI, ":22:0:", "{character_id}", ":", "{self.character.name}",
					":1:", "{inviter.character.character_id}", ":", "{inviter.character.name}"]),
	"退出后取消": (23846, 23848, [PI, ":9:0"]),
	"快照金币": (23760, 23763, [PI, ":4:", "{player_slot}", ":", "{trade.offered_money.get(owner_id, 0)}"]),
	"快照元宝": (23764, 23767, [PI, ":6:", "{player_slot}", ":", "{trade.offered_cash_money.get(owner_id, 0)}"]),
	"快照放物": (23777, 23780, [PI, ":5:", "{player_slot}", ":", "{encoded}"]),
	"快照放宠": (23784, 23787, [PI, ":10:", "{player_slot}", ":", "{owner._encode_pet(pet)}"]),
	"取回物品": (23901, 23903, [PI, ":21:", "{slot}", ":", "{encoded}"]),
	"取回宠物": (23927, 23930, [PI, ":11:", "{slot}", ":", "{self._encode_pet(pet)}"]),
	"双方锁定": (23938, 23940, [PI, ":7"]),
	"成交完成": (23947, 23949, [PI, ":8"]),
}

## `PlayerAction.as:6-32` —— 上行动作号（门里断言"点这颗钮发的是哪一段"要用）。
动作号 = {
	"CREATE": 0, "INVITE": 2, "DECLINE": 3, "VISIT": 4, "CHAT": 6, "LOCK": 9, "EXIT": 10,
	"SET_CASH": 13, "SET_ITEMS": 14, "SET_COCONUTS": 15, "CONFIRM": 16,
	"TAKE_ITEM_BACK_TRADE": 17, "SET_PET": 18, "TAKE_PET_BACK_TRADE": 19,
}


def 读源码():
    if not os.path.isfile(服务端源):
        raise SystemExit("找不到服务端源：%s" % 服务端源)
    with io.open(服务端源, encoding="utf-8") as f:
        return f.readlines()


全部行 = 读源码()


def 抠(起, 止):
    """按行号区间取源码文本（1 起、含端点）。行号过期时下面的 `send_text(` 找不到 ⇒ 直接红。"""
    return "".join(全部行[起 - 1:止])


def 拆模板(文本):
    """把 `f"{op(..)}:3:{a}:{b}"` 拆成 token 列表；相邻 f-string 先拼起来再拆。"""
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
            内 = 文本[i + 1:j].strip().replace(" ", "")
            tokens.append("{%s}" % 内)
            i = j + 1
        else:
            buf += c
            i += 1
    if buf:
        tokens.append(buf)
    return tokens


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
    return 期望


def 抠列表片段(起, 止, 变量):
    """取 `变量: list[int | str] = [ … ]` 里那一段，按**顶层逗号**切token（嵌套括号/字符串不切）。"""
    文 = 抠(起, 止)
    头 = 文.index(变量)
    # ⚠ 必须跳到 `=` **之后**的那个 `[`：声明写的是 `fields: list[int | str] = [`，
    # 直接从变量名往后找 `[` 会先撞进类型标注那个 `list[…]`，切出来的"段"就是 `int|str`。
    开 = 文.index("[", 文.index("=", 头))
    深 = 0
    for i in range(开, len(文)):
        c = 文[i]
        if c in "[(":
            深 += 1
        elif c in "])":
            深 -= 1
            if 深 == 0:
                体 = 文[开 + 1:i]
                break
    else:
        raise SystemExit("找不到 `%s` 列表的右括号（行区间 %d-%d 过期）" % (变量, 起, 止))
    项 = []
    buf = ""
    深 = 0
    for c in 体:
        if c in "[(":
            深 += 1
        elif c in "])":
            深 -= 1
        if c == "," and 深 == 0:
            项.append(buf.strip())
            buf = ""
        else:
            buf += c
    if buf.strip():
        项.append(buf.strip())
    return [re.sub(r"\s+", "", t) for t in 项]


def 反查负载():
    """物品负载十段 + 宠物负载三十一段，逐 token 对服务端源码。"""
    物期 = ["op(ItemCodecType.ITEM)", "item.item_id", "item.slot", "quantity", "0", "0",
            "int(item.can_trade)", "owner", "0", "item.unique_id"]
    物实 = 抠列表片段(50832, 50844, "common_fields")
    if 物实 != 物期:
        raise SystemExit("物品负载的段序与服务端源码不一致：\n  源码 = %s\n  夹具 = %s" % (物实, 物期))
    宠期 = ["pet.item_id", "pet.position", "1", "0", "0", "int(pet.can_trade)", "self.character.name",
            "0", "pet.unique_id", "self.character.character_id", "pet.name", "pet.level", "0",
            "self.character.foothold", "pet.blessing", "pet.aptitude", "pet.savvy", "pet.experience",
            "pet.fullness", "pet.potential_real_atk", "pet.potential_real_def",
            "pet.potential_real_dex", "pet.potential_real_str", "pet.potential_total_atk",
            "pet.potential_total_def", "pet.potential_total_dex", "pet.potential_total_str",
            "self._pet_skin(pet)", "equipment", "skills", "pet.dream"]
    宠实 = 抠列表片段(16960, 16970, "fields")
    if 宠实 != 宠期:
        raise SystemExit("宠物负载的段序与服务端源码不一致：\n  源码 = %s\n  夹具 = %s" % (宠实, 宠期))
    if len(宠实) < 31:
        raise SystemExit("宠物负载不足 31 段 ⇒ 客户端 `_parse_pet_fields` 会整条丢掉")
    return 物期, 宠期


def 物品负载(槽, 数量, 可交易=1, 物品号="10000001", 主人="油女澪", 唯一号=7001):
    """按 `common_fields` 那十段拼（非装备档就是这十段，`:50870`）。"""
    return "&".join(["2", 物品号, str(槽), str(数量), "0", "0", str(可交易), 主人, "0", str(唯一号)])


def 宠物负载(主人="油女澪", 主人号=1002, 宠物种=101, 宠物名="蜃", 等级=12, 唯一号=8101, 资质=3):
    """31 段，逐段对应 `_encode_pet`。渲染只读 0/8/10/11/15 段，其余填 0/`-` 也要**占位**，
    少一段客户端解出来就是空 ⇒ 门会红在"喂了帧、格子里没东西"。"""
    列 = [宠物种, 5, 1, 0, 0, 1, 主人, 0, 唯一号, 主人号, 宠物名, 等级, 0, 0,
         0, 资质, 60, 0, 0, 10, 10, 10, 10, 20, 20, 20, 20, 宠物种, "-", "-", 0]
    if len(列) != 31:
        raise SystemExit("宠物负载自己数不对：%d 段（该 31）" % len(列))
    return "&".join(str(v) for v in 列)


def 主():
    帧 = {}
    for 名 in 帧表:
        帧[名] = 反查帧(名)
    物期, 宠期 = 反查负载()

    我号, 我名, 他号, 他名 = 1001, "木叶忍者", 1002, "油女澪"
    金钱, 元宝 = 200000, 30

    def 帧文(前缀, *余):
        return ":".join([str(335), str(前缀)] + [str(v) for v in 余])

    样本 = {
        "邀请": 帧文(3, 他号, 他名),
        "开始": "335:22:0:%d:%s:1:%d:%s" % (我号, 我名, 他号, 他名),
        "我方金币": 帧文(4, 0, 金钱),
        "对方金币": 帧文(4, 1, 1500),
        "我方元宝": 帧文(6, 0, 元宝),
        "对方元宝": 帧文(6, 1, 5),
        "我方放物": "335:5:0:%s" % 物品负载(2, 5),
        "对方放物": "335:5:1:%s" % 物品负载(3, 1, 物品号="10000002", 唯一号=7002),
        "我方取回": "335:21:0:%s" % 物品负载(2, 5),
        "我方放宠": "335:10:0:%s" % 宠物负载(),
        "对方放宠": "335:10:1:%s" % 宠物负载(主人=我名, 主人号=我号, 宠物种=102, 宠物名="蛤龙", 唯一号=8102),
        "双方锁定": "335:7",
        "成交": "335:8",
        "取消": "335:9:0",
    }
    # 自审：帧里除负载内部（`&` 分隔）不许出现冒号，段数必须和模板对得上
    if 样本["邀请"].count(":") != 3:
        raise SystemExit("邀请帧自审失败：应该是 `335:3:号:名` 四段")
    if 样本["开始"].count(":") != 7:
        raise SystemExit("开始帧自审失败：应该是 8 段")
    if len(样本["我方放宠"].split(":", 3)[3].split("&")) != 31:
        raise SystemExit("宠物帧的负载段数不是 31")
    if len(样本["我方放物"].split(":", 3)[3].split("&")) != 10:
        raise SystemExit("物品帧的负载段数不是 10")
    数据 = {
        "_说明": ("由 开发工具/出交易夹具.py 生成；每条帧的段序都与服务端源码逐 token 反查过"
            "（`handle_player_interaction` / `_broadcast_trade_snapshot`），"
            "改服务端那几段拼接式会让生成器直接红。离线门把这些原文喂进 `后端连接._handle_trade_text`。"),
        "模板": 帧,
        "上行动作号": 动作号,
        "物品负载段": 物期,
        "宠物负载段": 宠期,
        "我号": 我号, "我名": 我名, "他号": 他号, "他名": 他名,
        "原文": 样本,
    }
    with io.open(出, "w", encoding="utf-8") as f:
        json.dump(数据, f, ensure_ascii=False, indent=1, sort_keys=False)
        f.write("\n")
    print("反查通过：%d 条帧 + 物品 %d 段 + 宠物 %d 段" % (len(帧), len(物期), len(宠期)))
    print("写出 %s（样本 %d 条）" % (os.path.relpath(出, 工程), len(样本)))


主()
