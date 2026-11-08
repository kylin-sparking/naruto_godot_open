#!/usr/bin/env python3
"""起一份隔离的本地游戏服务端，并备好在线回归用例需要的账号、角色与数据。

一般由 `开发工具/跑在线用例.ps1` 调用，不手工执行。也可单独用它起服务端供手工试玩：

    python 开发工具/本地服务端夹具.py --root .fixture --print-only

隔离原则：启动服务端之前把 NARUTO_MULTIPLAYER_ROOT / NARUTO_SAVE_PATH /
NARUTO_SERVER_PORT 等指向 --root，**绝不触碰 2.2.3 里的真实存档**。
所有造号动作都走服务端自带的 gm_admin，不自己拼存档格式。

用法：
    --root <目录>        隔离存档根（必填）
    --port <端口>        默认 18684（客户端默认端口）
    --state-out <json>   把角色编号等写到这里供 ps1 读取
    --reset              先清空 --root 再建
    --print-only         只造数据不起服务端（用于排查）
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import threading
import time
from pathlib import Path

# 服务端与 GM 工具的来源 = **项目内** 服务端/runtime/tools（见 服务端/README.md、§3.89）。
# 2026-10-03 起不再从 2.2.3 运行期 import 代码（2.2.3 退回纯原版参考）；
# 寻径统一走 开发工具/服务端目录.py，它会校验加载的确实是项目内那份。
sys.path.insert(0, str(Path(__file__).resolve().parent))
import 服务端目录  # noqa: E402

MAIN_ACCOUNT = "a33047518511@gmail.com"
MAIN_PASSWORD = "123456"
MAIN_CHARACTER_NAME = "木叶忍者"

# 社交/传承用例需要第二个账号（用例自己会连它）。
# 注意：用例里的 PEER_NAME 是 "CodexSocialPeer"，超过服务端 12 字符上限，
# 所以这里用合法名字建角色；用例查不到同名角色时会用 NW_SOCIAL_PEER_ID 兜底。
PEER_ACCOUNT = "naruto"
PEER_PASSWORD = "123456"
PEER_CHARACTER_NAME = "社交同伴"

# 同伴名下的家族（家族列表窗「申请加入」用例要"列表里有族、而主角没入族"）。
# 名字里不能带 `:`/`@`/`&`（协议分隔符），这是服务端 `CHARACTER_NAME_PATTERN` 之外的
# 真实约束 —— `create_family` 只过滤 `:`，而列表行是 `&`/`@` 拼的。
PEER_FAMILY_NAME = "同伴家族"
PEER_FAMILY_FLAG_STYLE = 1000
PEER_FAMILY_FLAG_NAME = "同伴旗帜"

# 主角名下的家族（`--main-family`；族旗安插在线门要"主角自己是族长"）。
# 与同伴那个族同时存在没关系 —— 一个账号只能入一个族，两边互不影响。
MAIN_FAMILY_NAME = "主角家族"
MAIN_FAMILY_FLAG_NAME = "主角旗帜"
# 传承用例是"双客户端双修"，需要两个**同时在线**的连接。服务端 enter_world 按**账号**
# 踢会话（sessions_by_account，"kick an older account session"），同一账号不可能在线两次
# ——真实游戏里双修本来也是两个玩家。所以传承的第二条连接必须用独立账号。
LEGACY_PEER_ACCOUNT = "naruto2"
LEGACY_PEER_PASSWORD = "123456"
LEGACY_PEER_CHARACTER_NAME = "传承同伴"

# 主角色要预置的背包物品：(item_id, 数量)
#   3000001  拉面（小）   —— 商城用例的商品、仓库存取用例的种子
#   2010010  轻藤兽铠     —— 宠物用例要求背包里有一件宠物装备
#   12100000 千手柱间卡   —— 传承用例要求 20 张
#   16000053 宝箱钥匙     —— 传承用例要求 1 个
#
#   ⚠️ 2026-09-28 更正：宠物用例原来钉的 16010013「九尾残魂」是**数据_扩展里的自造 id**，
#   2.2.3 目录里没有 —— 那不是"快照缺口"，是**用例钉错了口径**。
#   真值（`Pet.00000404.info.evolution`，服务端 `_fuse_pet_soul` 读的同一行）：
#   九尾融魂 = 尾兽残魂(九尾) **16000178 × 6000** + 金币 **30,000,000**。
#   `stack_max` 是 9999，6000 个只占一格。
MAIN_ITEMS: tuple[tuple[int, int], ...] = (
    (3000001, 20),
    (2010010, 1),
    #   16000178 尾兽残魂(九尾) —— **宠物融魂用例**要 6000 个（见上面那段的真值）。
    #   名字与 id 都取自 `数据/物品.json`（导出源是同一份 GameData）。
    (16000178, 6000),
    #   01010013 —— **装备部位在线回归测试**要穿一件真武器（位置 -1）。
    #   ⚠️ 两条坑，都踩过：
    #     ① 物品编号是**八位补零**的写法（前两位是大类），写成 7 位 `1010011` 服务端认不出、静默不发；
    #     ② 武器 id 的末位就是**职业**（`10100XY` → `required_job = Y×100`，实测服务端目录），
    #        夹具主角色是 job=300，所以 `01010011`(job 100) 会被 `_can_equip` 拒掉，必须用 300 的。
    (1010013, 1),
    #   01010023 长太刀 —— **精炼验证**要一件**已经 10 星**的紫装（见 seed_forge_ready_weapon）。
    #   同职业（末位 3 = job 300）、req_lv 20 远低于角色 100 级，穿得上。
    #   ⚠️ 单开一件、**不升级 01010013** —— 装备打造用例硬断言那件初始 0 星。
    (1010023, 1),
    #   15028002 精炼锤 —— 精炼那两步的材料：百炼(10→11) 与 提升附加属性 都吃它，每次 1 个。
    #   两发都**带概率**（3% / 7%），用例要"重试到成功"，所以给满一组 99（`stack_max` 就是 99）。
    (15028002, 99),
    #   16000016 强化灵珠 / 16000019 升阶灵珠 —— **装备打造在线回归测试**要真打造一件装备。
    #   数量照 `EquipSystem.strength` 的消耗给足：level1..10 依次要 1/2/5/10/20/40/60/80/120/180。
    #   （出处见 数据/装备打造.json，生成器 开发工具/导出装备强化表.py）
    #   ⚠️ 2026-09-23 从 200 提到 9999：**全流程体检**要从白板一路强化到 10 星，
    #   0→10 总共只要 518 颗，但**失败也扣**（8/9/10 级只有 35/30/25%），实际要一千多。
    (16000016, 9999),
    (16000019, 10),
    #   下面这几件是**全流程体检**（`测试/装备打造全流程体检.gd`）沿途要用的材料，
    #   材料 id 一律照 `数据/装备打造.json` 的各段取，别手抄：
    #     天生   → `born.needItemId`（每次 2、25%）
    #     洗附加属性 → `changeAptitude.needItemId`
    #     洗附加数值 → `plus.washvalue.needItemId`
    #     刻印   → `carve.req.stage*.needItemId`（每次 4）+ `keepItemId` 保级道具
    #     幸运符 → 好几处共用的 `helpItemId`
    (16000033, 40),   # 天生灵珠
    (16000018, 60),   # 洗附加属性（重生灵珠）：紫色档每次要 4 颗、70%，一次体检要试好几发
    (16000034, 20),   # 洗附加数值
    (16000035, 40),   # 刻印
    (16000021, 10),   # 刻印·保级道具
    (16000015, 40),   # 幸运符
    (16000004, 20),  # 扩充密卷：商城的 1084 是"扩充背包"，每页消耗 2/6/18…
    #   16000278..16000283 八咫镜碎片一~六 —— **忍具兑换在线用例**要它们各 1 件
    #   （服务端 `handle_renju` 的 COMBINE：六种各扣 1、发 65000001 八咫镜）。
    #   id 逐字取自原版 `RenJuDuiHuanWindow.as:22` 的 `RENJU_DEBRIS_IDS`。
    #   16000110..16000115 十拳剑碎片一~六 —— **十拳剑兑换在线用例**要它们各 1 件
    #   （服务端 `_combine_ling_qi` 的 COMBINE：六种各扣 1、发 20100001 十拳剑）。
    #   id 取自服务端 `ItemId.TOTSUKA_FRAGMENT_1..6`，与物品表「十拳剑碎片一..六」逐条对得上。
    (16000110, 1),
    (16000111, 1),
    (16000112, 1),
    (16000113, 1),
    (16000114, 1),
    (16000115, 1),
    (16000278, 1),
    (16000279, 1),
    (16000280, 1),
    (16000281, 1),
    (16000282, 1),
    (16000283, 1),
    (12100000, 20),
    (16000053, 1),
    #   15020001 手里剑修炼符 —— **传承在线回归测试**的暗器那步要它。
    #   服务端 `_train_an_qi`（fake_flash_server.py:52076）每张 +50 熟练度，
    #   id 与增量取自 GameData `Etc.AnQi.common.speedUp = {needItemId: 15020001, addMaster: 50}`
    #   （**与客户端 `手里剑数据.gd` 的 `提速` 一项吻合**）。
    #   用例断言"一次 use_all 就做到 stage1 的 4 级满"：4 级 × `master_max` 5000 = 20000 熟练度
    #   → 400 张；给足一点。
    #   ⚠️ 少了它，服务端 `_train_an_qi` 第一句就是 `available <= 0` → 回"手里剑修炼符不足"、
    #      消耗 0 张 —— 表现是"自动培养没反应"，**看着像客户端坏了，其实是夹具有没有给料**。
    (15020001, 500),
    # 家徽升级要的四种家族材料：帮会用例先捐进家族才升得动（捐献见 action 12）。
    (16000023, 1),
    (16000024, 1),
    (16000025, 1),
    (16000026, 1),
    #   13000000 白色宝石(1级) —— **道具真实事务**的绑定那步（2026-10-02 实装菜单「绑定」）。
    #   选它的原因：类型 13 在客户端 `menuArr` 里**带「绑定」项**，且它**不在 BindItems**
    #   （名单见 `数据/原版杂项.json`），发放后 `can_trade=True`（服务端 `_add_inventory_item:47076-47079`）
    #   —— 既能钉"绑定置位"，也能钉"绑定后菜单去不掉「绑定」"那个回包解析 bug。
    (13000000, 1),
    #   11000156 「388点券」礼包 —— **道具真实事务**的点券那步（2026-10-02）。
    #   `use_type=libao`、`coupon_reward=388`、`use_all=True`、无 contents（`fake_flash_server.py:8427-8428`）；
    #   `_use_authored_gift_item` 尾部 `_send_stats({CASH_BIND=30})`。用它钉客户端
    #   `_handle_stats_text` 补登记字段号 30 之后，点券才会真落进 `player_stats.cash_bind`（背包/商城那行读它）。
    (11000156, 3),
    #   11000241 金币大礼包 —— 同一步的**金币**对照：`money_reward=20000`、`required_level=30`（角色 100 级够）、
    #   带 contents。服务端发放时 `_send_stats({MONEY=27})`（早登记过），用来证明"点券特殊、金币本来就通"。
    (11000241, 1),
    #   13010000 黄色宝石(1级) ×30 —— **道具真实事务**的宝石合成那步（2026-10-03 实装合成窗）。
    #   `_merge_equipment_stone:54099-54113` 一次请求**吃 3 颗**、按 `merge.level2.prob=80` 掷一次、
    #   成功加 1 颗 `inlay.next`（=13000001 那支的下一级 13010001）。给 30 颗 = 10 次机会：
    #   用例要**重试到看见成功**（80% 一发，3 次不中就 0.8% 假红，给足余量）。
    #   ⚠️ 单独用 1301 这支，别拿 13000000 —— 那颗被「绑定」那步钉着件数==1。
    #   2026-10-11 §3.100 从 30 提到 60：**宝石幸运合成**那一节还要再吃几发（一次 3 颗）。
    #   现有断言全部**动态读基数**（`成基 := _件数(...)`），所以加量不动判据。
    (13010000, 60),
    #   13000009 红色宝石(影10级) —— 合成页的**满级闸**：`inlay.next=0`（链顶），
    #   服务端原话「该宝石已达到最高等级。」（`:54078`）；客户端开门也要先判这颗不开窗。
    (13000009, 3),
    #   13020000 绿色宝石(1级) ×2 —— **不足 3 颗**那句原话（`:54081`「合成需要三个同等级宝石。」）。
    (13020000, 2),
    #   16000556 宝石幸运符 —— **宝石幸运合成**（ITEM_CHANGE 子命令 31，2026-10-11 §3.100 实装）的料。
    #   真值：原版 `StoneLuckyCompositeWindow.as:31-37` 的常量（`LUCKY_HELP_ITEM_ID=16000556` /
    #   `LUCKY_MAX_COUNT=20` / `LUCKY_RATIO_PER_CHARM=3`），与物品表那句
    #   「使用一张增加3%宝石合成成功几率，最大允许使用20张。」逐字吻合。
    #   给 40 张 > 上限 20：门要同时验"夹到 20"与"只扣真扣掉的那些"。
    (16000556, 40),
    #   8000011 《五行封印术》残卷 ×60 —— **秘笈合成在线**门（2026-10-03 接 `1352`）。
    #   `skill_fragment_recipe` → (book=6000026, need=3)：一发吃 3 条 + 100 精华（zq 已预置 2 万）、
    #   ⚠️ 2026-10-11 §3.101 改：原来 `handle_can_juan_action` **硬编码 base 30%**，而表
    #   （`Etc.CanJuanHeCheng.prob`）是 **25** —— 客户端按表显示几率、服务端按另一套掷，
    #   玩家看到的成功率是错的。现在读表（`_authored_probability`）。⇒ 单发成功率 0.25。
    #   60 条 = 20 发：一直不见成功的概率 0.75^20 ≈ 0.3%（仍在可接受的假红范围内）。
    #   失败照扣 need-1=2 条（夹具口径、门钉它）。
    (8000011, 60),
    #   16000015 幸运符 ×30 —— 同门勾幸运符那发（每符 +3%、最多 9）；也给"勾了但不够"留对照余量。
    (16000015, 30),
)

# 预置忍术：WARP_CHAR_INFO 的 legacy 字段序第 41 项要求非空。
MAIN_SKILLS: tuple[int, ...] = (9029, 9030)

# 宠物：三条正规十阶线 + 四只尾兽的终极形态（与 make_testfull_complete 同源做法）。
TERMINAL_PET_IDS: tuple[int, ...] = (110, 210, 310, 401, 402, 403, 404)

#   金币：**九尾融魂要 3000 万**（GameData `Pet.00000404.info.evolution.needMoney`），
#   原来是 20 万，宠物用例根本付不起 —— 别按"够买东西就行"往下调。
MAIN_MONEY = 40_000_000   # 帮会用例要求 ≥ 100000；宠物融魂要求 ≥ 30,000,000
MAIN_CASH_MONEY = 100_000  # 商城用例要求点券够买东西
MAIN_COUPON_MONEY = 50_000

# 角色等级：服务端 _warp_to_map 有等级门槛（木叶村 100000000 要求 10 级），
# 1 级角色会被静默挡在门外——只发一条系统聊天、不发切图帧。
MAIN_LEVEL = 100

# 在线暴击红字（`后端接入回归测试` 的战斗段）要**服务端真掷出一次暴击**才能验，而夹具角色
# 默认 ap 全 0 ⇒ 暴击率恒 0、永远等不到 `bsk=1`。`seed_combat_stats` 把敏捷点到这个值。
MAIN_AP_DEX = 1000

# 罪恶值（服务端 `StatType.CRIME = 33`，`fake_flash_server.py:1086`）。
# **取一个不可能是默认值的数** —— 0 会让"接上了"和"没接上"分不开（假绿）。
# 人物属性窗「罪恶值」那行、以及 warp 包 `fields[29]` 都走它。
MAIN_CRIME = 123

# 容量：**不能拉满**。服务端 _extend_item_capacity 在 current >= maximum 时只发
# 一句"已达上限"就返回，不发容量帧——商城用例请求的 1084 正是"扩充背包"，
# 拉满会让它永远收不到回包。上限为 背包 810（90 格/页 × 9 页，2026-10-31）/
# 仓库 246 / 宠物 20；夹具取**恰好一页** 90。
MAIN_BAG_CAPACITY = 90      # ⚠️ 必须**大于** MAIN_ITEMS 占的格数 + 建角自带的 13 件（见下）
                            # 2026-10-15 实测：`MAIN_ITEMS` 现在要占 **47 格**，而建角自带
                            # `11000001..11000012` + `15008001` 共 **13 格** ⇒ 47+13 = **60**
                            # 与旧值**恰好撑满、零余量** ⇒ 任何"要领东西"的用例都被服务端
                            # `_has_inventory_capacity`（`fake_flash_server.py:47505`）判"背包满"、
                            # 发一句系统聊天就返回、**什么都不发**。
                            # 表现极难认：`福利在线` 单跑恒红"领每日签到后累计天数没涨（0 → 0）"，
                            # 看着像签到坏了，其实是**夹具有没有留空格**（同 `grant_items` 那条教训）。
                            # 主线上 §3.100 幸运符 / §3.119-3.123 那 12 片碎片 / 15020001 陆续加料
                            # 把预算吃光，而在线套件自 10-04 起没复跑过 ⇒ 直到 10-15 才暴露。
                            # 60 → 90 → 100 → 90（2026-10-31 每页回到 90 格）：留 30 格余量，远低于上限 810。
MAIN_STORAGE_CAPACITY = 96  # 服务端默认值，> 0 且可扩充
MAIN_PET_CAPACITY = 10      # 要容纳 7 只宠物，且留捕捉余位


def log(message: str) -> None:
    文 = f"[夹具] {message}"
    try:
        print(文, flush=True)
    except UnicodeEncodeError:
        ## 控制台是 GBK 时 `⇒`/`│` 这类字符编不出来 ⇒ **一次打印绝不能把服务端进程带走**
        ## （10-24 自审那条就是这个原因崩的；启动器一崩，玩家侧现象就是"连接不上服务器"）。
        编 = sys.stdout.encoding or "gbk"
        print(文.encode(编, "replace").decode(编, "replace"), flush=True)


def prepare_environment(root: Path, port: int) -> None:
    """在 import 服务端之前把路径与端口指向隔离目录。"""
    root.mkdir(parents=True, exist_ok=True)
    os.environ["NARUTO_MULTIPLAYER_ROOT"] = str(root / "multiplayer")
    os.environ["NARUTO_SAVE_PATH"] = str(root / "save.json")
    os.environ["NARUTO_SERVER_PORT"] = str(port)
    os.environ["NARUTO_NATIVE_LOGIN_PORT"] = str(port)
    os.environ["NARUTO_CHANNEL_PORT"] = str(port)


def load_server_modules():
    # 项目内那份服务端 + GM（服务端目录.加载模块 会把外部/2.2.3 的同名模块挡在外面并校验）
    server = 服务端目录.加载模块("fake_flash_server")
    gm = 服务端目录.加载模块("gm_admin")
    return server, gm


def find_account(service, username: str):
    for account in service.data["accounts"].values():
        if account.get("username") == username:
            return account
    return None


def ensure_account(service, username: str, password: str, *, first_character_id: int | None = None):
    """注册账号（文本登录路径不会自动注册，必须在这里建）。

    first_character_id 用于把角色编号钉死成用例期望的值；服务端默认从 1001 起。
    """
    account = find_account(service, username)
    if account is None:
        if first_character_id is not None:
            service.data["nextCharacterId"] = first_character_id
        registered = service.register(username, password)
        account = service.account_by_id(int(registered["id"]))
        log(f"注册账号 {username} (id={account['id']})")
    return account


def ensure_character(service, account, name: str) -> dict:
    characters = list(account.get("characters", []))
    if characters:
        return characters[0]
    character = service.create_character(account, name, 300, 0, 1, 0)
    log(f"创建角色 {name} (id={character['id']})")
    return character


def seed_character_identity(gm, character_id: int, name: str) -> None:
    """把**账号里那个 id/名字**写进角色档内部的 `character.character_id` / `.name`。

    服务端 `create_character` 建出来的那份档里这两位是**模板值**（实测 id=8、名字=木叶忍者），
    只有这个号**真登录过一次**才会被登录流程改对。夹具建的同伴/传承同伴从不登录 ⇒
    一直留着模板值。别的门读的是 `accounts.json` 里的 summary，所以没暴露；
    竞技场会暴露：服务端 `_arena_snapshot_for_character` 拿的是**档内**那两位
    （`fake_flash_server.py:29129-29151`），于是候选行报出 `charId=8`，
    而 `_start_arena_challenge(8,…)` 再 `character_owner(8)` 查无此人 ⇒ 永远只回面板、
    进不了对战（10-24 在线腿第一次跑就是这么红的）。
    """
    store, _summary, _session = gm._store(character_id)
    with store.lock:
        角色 = store.state.character
        if int(getattr(角色, "character_id", -1) or -1) == character_id \
                and getattr(角色, "name", None) == name:
            return
        角色.character_id = int(character_id)
        角色.name = name
        store.save()
    log(f"角色 {character_id} 的档内身份已钉成 (id={character_id}, name={name})")


# 对端（`社交同伴`，peer_id）背包里要有的东西。
#   01010013 苦无(300 职业) —— **查看信息在线回归测试**要它**真穿在身上**：
#   服务端 `_character_info_equipment:20284-20289` 只把 `slot < 0` 的装备拼进 58:0 的段 29，
#   背包里放着不算 ⇒ 对端不穿装备的话那一发永远是 `-`，"看别人"窗的二十个装备格就恒空。
#   10-16 现查：上一版夹具**根本没给对端发过任何物品**，而在线门那句
#   `装备串.length() > 0` 被 `"-"`（长度 1）蒙过去了 ⇒ 假绿。
#   职业末位与主角色同为 300（`create_character(account, name, 300, …)`），所以这件穿得上。
#   01310006 寄坏虫 / 01310005 甲虫 —— **看别人窗「寄坏之术」那一页要它们穿在虫槽上**。
#   同一段道理：虫件也进段 29，但要看别人那一页四格按 **slot_index ∈ −200..−203** 认槽
#   （`人物窗口.他人昆虫()`），不落到那几个格子那一页就恒空。
#   ⚠ 这两件**不能靠协议穿**：`物品.json` 里六只寄坏虫的 `required_level` 全是 **40**，
#   而对端 `社交同伴` 是 1 级 —— 服务端 `_can_equip:47837-47839` 直接回
#   「需要达到 40 级才能装备」⇒ 走协议这条路只会红。把对端升到 40/100 级又会连带改它的
#   血蓝经验，而别的在线门钉过那些数 ⇒ **这里按存档直接把槽位写成 −200/−201**
#   （与 `seed_peer_family` / `追踪背包` 同一类"夹具直接写状态"）。
#   ⚠ 这**不是手写协议串**：段 29 那串仍由服务端 `_character_info_equipment` 自己拼，
#   门喂给离线门的还是**真帧原文**；夹具只是让这个角色"已经穿着两只虫"。
PEER_ITEMS: tuple[tuple[int, int], ...] = (
    (1010013, 1),
    (1310006, 1),
    (1310005, 1),
    #   19010001 并肩而立对戒（1 阶）—— **求婚（羁绊）那一腿**要对端真能发 `127:20:<我的号>:19010001`。
    #   服务端那道闸是 `_is_bond_pair_item:22926-22928`（只认 `190[1-8]0001` 八个号）
    #   + `_bond_pair_item:22930-22938`（**必须在背包格上**且数量 > 0 ⇒ 不能预先穿走），
    #   缺这一件 ⇒ 服务端只回一句「羁绊申请失败…」而**我这侧什么都收不到**，看着像"客户端没接上"。
    #   逐件真值 = `真值/窗口/求婚窗.md` §②。
    (19010001, 1),
)

## 对端穿在虫槽上的两件：`物品编号 → 槽位`（`KUN_CHONG_EQUIPPED_POSITIONS` 的前两格）。
PEER_KUN_CHONG: tuple[tuple[int, int], ...] = (
    (1310006, -200),
    (1310005, -201),
)


def wear_peer_kun_chong(gm, character_id: int) -> dict:
    """把对端背包里的两只寄坏虫挪到虫槽 −200 / −201（幂等：已经在槽上就不动）。

    ⚠ **`inventory` 是「槽位 → 物品」的字典，光改 `item.slot` 没用**：
    落盘写的槽位取的是**字典的键**，10-16 实测第一次只改了 `item.slot` ⇒
    日志说"已穿到虫槽"、存档里两件仍是 `slot: 2 / 3`、段 29 还是只有一件武器。
    ⇒ 必须 `pop(旧键)` 再以新槽位为键放回去（与服务端自己那两处移动
    `fake_flash_server.py:47514` / `:20984` 同一个形状）。
    """
    store, _summary, _session = gm._store(character_id)
    落的: dict[int, int] = {}
    with store.lock:
        for 编号, 槽 in PEER_KUN_CHONG:
            if int(getattr(store.state.inventory.get(槽), "item_id", -1)) == 编号:
                continue        # 已经穿在这一格上了
            旧键 = next(
                (键 for 键, 件 in store.state.inventory.items()
                 if int(件.item_id) == 编号 and int(键) > 0),
                None,
            )
            if 旧键 is None or 槽 in store.state.inventory:
                continue
            件 = store.state.inventory.pop(旧键)
            件.slot = 槽
            store.state.inventory[槽] = 件
            落的[编号] = 槽
        if 落的:
            store.save()
    if 落的:
        log(f"角色 {character_id} 的寄坏虫已穿到虫槽：{落的}")
    else:
        log(f"角色 {character_id} 的寄坏虫已在虫槽上（或背包里根本没有）")
    return 落的


def seed_peer_family(service, peer_account) -> dict | None:
    """给**同伴**造一个家族，主角色**不在里面**。

    为什么要有：家族列表窗的「申请加入」只有"当前角色没入族、列表里又确实有族"时才走得通
    （`FamillyManager.joinFamilly` 第一句就是 `myFamillyInfo.id != 0` ⇒ 只提示不申请）。
    同伴自己建族要 1000 金币，而金币只播给主角色（角色默认 money=0），所以直接写数据。

    ⚠️ **主角色的一切状态都不动**（`familyId` 保持 0）—— 别的在线用例断言的
    「初始未入族」不受影响。同伴是 `naruto` 那个账号。
    """
    if int(peer_account.get("familyId", 0)):
        return None
    family = service.create_family(
        int(peer_account["id"]),
        PEER_FAMILY_NAME,
        PEER_FAMILY_FLAG_STYLE,
        PEER_FAMILY_FLAG_NAME,
    )
    log(f"同伴家族已造：{family['name']} (id={family['id']})，主角色不在其中")
    return family


def seed_main_family(service, main_account) -> dict | None:
    """给**主角色**造一个家族，主角色自己当族长（`--main-family`，族旗安插在线门用）。

    为什么不能复用 `seed_peer_family`：那个族的族长是**同伴账号**，而
    `fake_flash_server.handle_map_flag_action` 第一句就要求
    `family["leaderAccountId"] == 自己账号`（「只有族长可以操作族旗。」）。
    这里同样直接写数据（`create_family`），不走原版"1000 金币建族"那一跳。

    ⚠️ 只有显式打开 `--main-family` 时才造：其余在线用例断言的
    「初始未入族」（家族列表「申请加入」等）不受影响。
    """
    if int(main_account.get("familyId", 0)):
        return None
    family = service.create_family(
        int(main_account["id"]),
        MAIN_FAMILY_NAME,
        PEER_FAMILY_FLAG_STYLE,
        MAIN_FAMILY_FLAG_NAME,
    )
    log(f"主角家族已造：{family['name']} (id={family['id']})，主角是族长")
    return family


def ensure_second_character(service, account, name: str) -> dict:
    """账号下的第二个角色（传承用例两条连接同账号各选一个）。"""
    characters = list(account.get("characters", []))
    if len(characters) >= 2:
        return characters[1]
    character = service.create_character(account, name, 300, 0, 1, 0)
    log(f"创建第二角色 {name} (id={character['id']})")
    return character


def seed_pets(server, gm, character_id: int) -> None:
    """直接按存档状态造宠物：gm_admin 没有发放宠物的动作。"""
    store, _summary, _session = gm._store(character_id)
    catalog = server.GAME_DATA_CATALOG
    with store.lock:
        state = store.state
        if state.pets:
            log(f"角色 {character_id} 已有 {len(state.pets)} 只宠物，跳过")
            return
        state.pet_capacity = MAIN_PET_CAPACITY
        # ⚠️ **只抬不压**：玩档根每次启动都会跑这里（该根没有宠物），直接赋值会把玩家
        #    存档里扩充过的容量（如 128）改回种子值 ⇒ 背包标题的总格数每启动一次就错一次
        #    （2026-10-31 用户报「背包的总格子数还是错的」的真因）。
        state.bag_capacity = max(int(state.bag_capacity or 0), MAIN_BAG_CAPACITY)
        state.storage_capacity = MAIN_STORAGE_CAPACITY
        pets: dict[int, object] = {}
        for index, pet_id in enumerate(TERMINAL_PET_IDS, start=1):
            maximum = max(1, catalog.get_pet_maximum_potential(pet_id, 4))
            skills = {
                skill_id: server.SkillState(skill_id=skill_id, level=120)
                for skill_id in catalog.get_pet_default_skills(pet_id)
                if skill_id > 0
            }
            unique_id = 910_000 + index
            pets[unique_id] = server.PetState(
                unique_id=unique_id,
                item_id=pet_id,
                name=catalog.get_pet_name(pet_id) or f"通灵兽{pet_id}",
                level=120,
                experience=0,
                position=int(
                    server.PetPosition.ATTACHED
                    if pet_id == TERMINAL_PET_IDS[-1]
                    else server.PetPosition.BAG
                ),
                fullness=100,
                aptitude=4,
                savvy=100,
                blessing=1000,
                # **梦幻度**：融魂门槛要求总梦幻度 ≥ 70（`_fuse_pet_soul`），
                # 算式 = 悟性/10(10) + 四项潜力 real/总 比×100/3(33.3) + 技能数×1.25 + dream。
                # 光靠前两项只有 ~45，所以这里把 dream 给到 30（梦幻灵珠那一项）。
                dream=30,
                can_trade=False,
                potential_real_atk=maximum,
                potential_real_def=maximum,
                potential_real_dex=maximum,
                potential_real_str=maximum,
                potential_total_atk=maximum,
                potential_total_def=maximum,
                potential_total_dex=maximum,
                potential_total_str=maximum,
                skills=skills,
            )
        state.pets = pets
        store.save()
    log(f"角色 {character_id} 造了 {len(TERMINAL_PET_IDS)} 只宠物")


def seed_peer_pets(server, gm, character_id: int, count: int = 3) -> None:
    """给**对端**造几只宠物 —— 「看别人」那扇的宠物页得有他的数据可画（`58:0` 的段 32）。

    刻意**不复用** `seed_pets`：那两个角色在门里必须一眼分得开。
    · `unique_id` 用另一串 `920_000 + i`（主角色是 `910_000 + i`）
      —— 两串**故意不同**，"把他的窗画成我的数"才会被抓住；
    · 等级 **33 / 44 / 55**（主角色七只全 120）；
    · 位置**三只全放背包(1)**：给一只出战/附身就把服务端当场打崩（见下面那条 ⚠）；
    · 只造 `count` 只、**不动 `pet_capacity`、不动背包**
      —— 他的背包是交易/看摊那几道门共用的夹具，别在这里顺手改。
    """
    store, _summary, _session = gm._store(character_id)
    catalog = server.GAME_DATA_CATALOG
    档位 = [
        (33, int(server.PetPosition.BAG)),
        (44, int(server.PetPosition.BAG)),
        (55, int(server.PetPosition.BAG)),
    ]
    ## ⚠ **不给对端造"附身"那只**（`PetPosition.ATTACHED = 0`）：实测对端一登录，
    ## 服务端 `_send_all_stats → _current_attack_speed → _equipped_attribute_bonus`
    ## 就在遍历装备字典时被附身流程改了大小 ⇒
    ## `RuntimeError: dictionary changed size during iteration`，对端那条连接当场断，
    ## 后面的"真穿武器"整条链全红（2026-10-16 现查）。那是**服务端本体**的并发缺陷，
    ## 改它要点头 —— 所以这里绕开：出战(125) 与 背包(1) 都能把行首那个状态图标测出来，
    ## 附身那一档由主角色那七只（`seed_pets` 里最后一只就是 ATTACHED）在别的门上覆盖。
    with store.lock:
        state = store.state
        if state.pets:
            log(f"角色 {character_id} 已有 {len(state.pets)} 只宠物，跳过")
            return
        pets: dict[int, object] = {}
        for index, pet_id in enumerate(TERMINAL_PET_IDS[:count], start=1):
            等级, 位置 = 档位[index - 1]
            maximum = max(1, catalog.get_pet_maximum_potential(pet_id, 2))
            pets[920_000 + index] = server.PetState(
                unique_id=920_000 + index,
                item_id=pet_id,
                name=catalog.get_pet_name(pet_id) or f"通灵兽{pet_id}",
                level=等级,
                experience=0,
                position=位置,
                fullness=100,
                aptitude=2,
                savvy=等级,
                blessing=500,
                dream=5,
                can_trade=False,
                potential_real_atk=maximum,
                potential_real_def=maximum,
                potential_real_dex=maximum,
                potential_real_str=maximum,
                potential_total_atk=maximum,
                potential_total_def=maximum,
                potential_total_dex=maximum,
                potential_total_str=maximum,
                skills={
                    skill_id: server.SkillState(skill_id=skill_id, level=等级)
                    for skill_id in catalog.get_pet_default_skills(pet_id)
                    if skill_id > 0
                },
            )
        state.pets = pets
        store.save()
    log(f"角色 {character_id}（对端）造了 {len(pets)} 只宠物，等级 33/44/55、三只全在背包"
        f"（附身/出战会当场打死对端那条连接，见函数注释）")


## 精炼验证要用的那件武器（长太刀）。单独一件，别和 01010013 混。
精炼测试武器 = 1010023


def _造附加属性(server, catalog, *, 阶数: int, 部位: str, 条数: int = 0) -> list[list[int]]:
    """照 `plus.stage<阶>.<部位>` 造一组附加属性（取 `valueFrom..valueTo` 的**中值**）。

    ⚠️ **不要写满**（原来取 `valueTo`，2026-11-01 改）：服务端 `_wash_plus_values` 对
    `旧值 >= 上限` 的条目**原样返回**（页面说明原话「达到满属性后再次重置将不会改变」）
    ⇒ 写满的装备点"开始重置"，预览和旧值一模一样、保存也一点不变，
    看起来就是"洗附加数值没实装"（用户 2026-11-01 报的正是这个）。
    取中值后上升/下降两条分支都走得通，门里才能断言"数值确实变了"。
    **不在** `plus` 表里的属性不造 —— 原版那边它们本就没有上限。

    ⚠️ 2026-10-09 改（紫装池子）：`条数` 现在照**真实紫装**给 **6 条**；池子只有 3~4 条时
    **按序循环取**，于是天然带上**重复类型**（参考存档 4 阶 22 件里 14 件带重复）。
    旧注释那句"条数要小于候选池"的理由已作废 —— 服务端改**可重复抽**后，紫装 6 条本来就会重。
    """
    段 = (catalog.get_equipment_system_config("plus") or {}).get(f"stage{阶数}") or {}
    上限 = 段.get(部位) or {}
    池: list[list[int]] = []
    for _, 条目 in sorted(上限.items()):
        if not isinstance(条目, dict):
            continue
        属性 = server.EQUIPMENT_ATTRIBUTE_BY_NAME.get(str(条目.get("type", "")).lower())
        if 属性 is None:
            continue
        下限 = int(条目.get("valueFrom", 0))
        上限 = int(条目.get("valueTo", 0))
        值 = (下限 + 上限) // 2
        if 值 >= 上限 and 下限 < 上限:
            值 = 上限 - 1          # 见函数注释：写满 ⇒ 洗附加数值永远不变
        池.append([int(属性), 值])
    if 条数 <= 0 or not 池:
        return 池
    return [list(池[位 % len(池)]) for 位 in range(条数)]


def seed_forge_ready_weapon(server, gm, character_id: int) -> None:
    """把长太刀预置成**10 星紫装**（幂等：每次都覆盖成同一组值）。

    为什么需要它：服务端 `_forge_additive`（精炼·提升附加属性）第一句就是
    `if item.strength_level < 11 … 直接回失败` —— 也就是说"精炼成功"这条路**有前置**：
    得先走 `_forge_level_eleven`（百炼，10→11）。而从 0 星一路强化到 10 星要几十次带概率的
    重试（level8/9/10 只有 35%/30%/25%），塞进用例里又慢又吵。
    夹具一次性把前提造好，用例就只跑**百炼 + 精炼**这两步，跑得快也读得懂。

    ⚠️ 只碰 01010023；01010013 那件留 0 星（装备打造用例硬断言过）。
    """
    store, _summary, _session = gm._store(character_id)
    catalog = server.GAME_DATA_CATALOG
    with store.lock:
        for item in store.state.inventory.values():
            if int(item.item_id) != 精炼测试武器:
                continue
            item.aptitude = 4                 # `EquipAptitudeType.PURPLE` = 4（原版枚举）
            item.strength_level = 10
            item.strength_info = [True] * 10
            item.forge_additive_ratio = 0     # 精炼要涨的就是这个
            item.crash_time = 0               # 破碎了会被 `_forge_additive` 挡掉
            # `strength_value` 照服务端 `_forge_strength_level` 的公式补上，
            # 别让它停在 0（"10 星却 0 加成"是自相矛盾的数据）：
            #   `round(base_attr_value * addRatio / 100)`，addRatio 取 `strength.level10`
            config = catalog.get_equipment_system_config("strength").get("level10") or {}
            item.strength_value = round(
                int(item.base_attr_value) * int(config.get("addRatio", 0)) / 100
            )
            # **给这件真的带上附加属性**。为什么非有不可：
            # 服务端 `_forge_wash_plus_attributes`（洗附加数值）第一句就是
            # `if len(item.plus_attributes) <= 0: 发一句"该装备没有可洗练的附加属性"; return`。
            # 而**白板拿不到附加属性** —— 能发附加属性的 `_forge_change_aptitude`（洗附加属性）
            # 那条路在服务端被停用了，只发一句提示就 return（见 §3.18.21）。
            # 所以不预置一件带附加属性的，"洗附加数值到底能不能用"就永远验不到。
            # 取值照 `plus.stage2.EquipA` 的 `valueFrom..valueTo` **中值**（不写满，见
            # `_造附加属性` 注释）；类型走服务端自己的
            # `EQUIPMENT_ATTRIBUTE_BY_NAME`，别手抄那份映射。条数照真实紫装 = 6。
            item.plus_attributes = _造附加属性(server, catalog, 阶数=2, 部位="EquipA", 条数=6)
            store.save()
            log(
                f"角色 {character_id} 的长太刀({精炼测试武器}) 预置为 "
                f"{item.strength_level} 星 / 资质 {item.aptitude}(紫) / "
                f"base={item.base_attr_value} strength_value={item.strength_value} / "
                f"附加比例={item.forge_additive_ratio}"
            )
            return
    log(f"⚠️ 背包里没有 {精炼测试武器}，精炼验证的前置没造上（是不是用了 --items 覆盖？）")


def seed_skills(server, gm, character_id: int, *, skills=None, reset_xinfa_default: bool = False) -> None:
    """预置**已学**技能。默认那份是给 WARP_CHAR_INFO 第 41 项凑非空用的两条忍术；
    某条用例要的材料不在里面时走 `--skills` 覆盖（口径同 `--items`），别改 MAIN_SKILLS。
    心法那条就需要 `xinfa==1` 的编号（9029/9030 都不是心法 ⇒ 服务端 _default_xinfa_id 恒 0）。

    `reset_xinfa_default` 把存档里那行 `defaultXinfaId` 抹掉 —— 服务端
    `_default_xinfa_id()`（`fake_flash_server.py:34885`）**优先用已存的这颗**，只有没存过
    才回落到「已学里编号最小的那枚心法」。夹具的角色存档是**跨轮次复用**的，上一轮切过的心法
    会留在这；不抹掉 ⇒ 在线门里"服务端自己挑的那颗"这个参照值就每轮都不一样（实测 10-14：
    期望 1000、拿到 1004），门红得毫无道理。
    """
    清单 = tuple(skills) if skills else MAIN_SKILLS
    store, _summary, _session = gm._store(character_id)
    with store.lock:
        for skill_id in 清单:
            store.state.skills.setdefault(
                skill_id, server.SkillState(skill_id=skill_id, level=1, master_level=0)
            )
        if reset_xinfa_default:
            旧 = store.state.character_config.pop("defaultXinfaId", None)
            if 旧 is not None:
                log(f"角色 {character_id} 抹掉存档里已存的 defaultXinfaId={旧}（让服务端走它自己的回落分支）")
        store.save()
    log(f"角色 {character_id} 预置已学技能 {list(清单)}")


def seed_items(server, gm, character_id: int, *, items=None) -> None:
    """缺什么补什么，重复执行不会越加越多。"""
    plan = MAIN_ITEMS if items is None else tuple(items)
    store, _summary, _session = gm._store(character_id)
    with store.lock:
        owned: dict[int, int] = {}
        for item in store.state.inventory.values():
            owned[int(item.item_id)] = owned.get(int(item.item_id), 0) + int(item.quantity)
    grant_items(server, gm, character_id, plan, owned, 标签="物品")
    log(f"角色 {character_id} 背包物品已备齐")


def seed_worn_damage(server, gm, character_id: int, spec) -> None:
    """把背包里的装备**挪到身上**并把耐久扣掉若干（在线「装备修理」门用）。

    为什么要有这一条：`--items` 发出来的装备是**满耐久、躺在背包里**的，而 NPC 商店的
    「装备修理」算的是**身上**那一份（`MendEtcWindow.setData()` 遍历 `equippedItems`，
    服务端 `_repair_all_equipped` 扫 `-199 <= slot < 0`）⇒ 不预置"穿着且破了"，
    在线门压根没有可修的对象，只能空跑。
    槽位取装备自己的 `definition.position`（原版就是负数槽），与 `_send_equipped_info`
    下发给客户端的那份**同一个键**。
    """
    for item_id, missing in spec:
        store, _summary, _session = gm._store(character_id)
        with store.lock:
            件 = next(
                (value for value in store.state.inventory.values()
                 if value.slot > 0 and int(value.item_id) == item_id),
                None,
            )
            if 件 is None:
                log(f"⚠️ 背包里没有 {item_id}，穿不上（--items 是不是漏了这件？）")
                continue
            definition = server.GAME_DATA_CATALOG.get_equipment_definition(item_id)
            if definition is None:
                log(f"⚠️ {item_id} 不是角色装备，穿不上")
                continue
            位置 = int(definition.position)
            if 位置 not in range(-199, 0):
                log(f"⚠️ {item_id} 的位置 {位置} 不在角色装备槽里，穿不上")
                continue
            if 位置 in store.state.inventory:
                # 夹具里直接顶掉原来穿着的那件（真客户端不会这么穿，但修理门只关心"身上有破件"）。
                del store.state.inventory[位置]
            del store.state.inventory[件.slot]
            件.slot = 位置
            件.endure = max(0, int(件.max_endure) - int(missing))
            store.state.inventory[位置] = 件
            store.save()
            log(f"角色 {character_id} 穿上 {item_id}（槽 {位置}），耐久 {件.endure}/{件.max_endure}")


def grant_items(server, gm, character_id: int, plan, owned: dict, *, 标签: str) -> None:
    """按 plan 补齐物品。**按每个物品自己的"有效堆叠上限"分批发**。

    ⚠️ GM 的 `item` 是**一次性发放**：请求量超过该物品的**单次堆叠上限**就**整条失败**
    —— 不是"发 99 剩下不发"，而是**一个都不发**（只在日志里留一行）。
    实测 2026-09-25：`(15020001, 500)` → 「单次发放堆叠上限为 99；请求数量为 500，本次未发放」，
    表现是"用例说没材料，其实是夹具没发" —— 极难往夹具上想。

    上限**必须取 `server._item_stack_limit(id)` 而不是 `definition.stack_max`**：前者才是 GM 与结算真正
    认的那个数（`fake_flash_server.py:2075`，里面还叠了"99/999 抬到 9999"这条用户要求的偏离，
    登记在 `真值/物品/堆叠上限.md`）。拿原始 `stack_max` 分批会**比服务端更保守**：
    作者值 99 的东西被切成 101 发，`(16000016, 9999)` 那类还可能整条发失败。
    """
    for item_id, quantity in plan:
        missing = quantity - owned.get(item_id, 0)
        if missing <= 0:
            continue
        per = int(server._item_stack_limit(int(item_id)) or 0)
        if per <= 0:
            per = 99   # 目录里查不到时退一个保守值，并记一笔
            log(f"物品 {item_id} 的堆叠上限取不到，按 {per} 分批发放")
        remaining = missing
        while remaining > 0:
            chunk = min(remaining, per)
            try:
                gm.run_action("item", {"characterId": character_id, "itemId": item_id, "quantity": chunk})
            except ValueError as error:
                log(f"{标签} {item_id}×{chunk} 发放失败：{error}")
                break
            remaining -= chunk


def seed_level(gm, character_id: int, amount: int = MAIN_LEVEL) -> None:
    """设等级：服务端有进图等级门槛，1 级角色进不了木叶村。

    `amount` 可给低档 —— 「头像信息在线」要把**对端**放在 10~59 这一段：
    服务端 `handle_tutor:22755-22768` 对收徒申请（上行 `77:4`）有两道等级闸
    （发起方 `>= TUTOR_LEVEL`、对面落在 `[TUTOR_STUDENT_MIN_LEVEL, TUTOR_LEVEL)`，
    常数在 `multiplayer_backend.py:34-36` = 10 / 60），
    对端是默认的 1 级时**整条申请帧被静默丢掉** ⇒ 师徒那一腿永远收不到东西。
    ⚠ 这条只许由 `--peer-level` 单独开启：别的在线门钉过对端的 1 级血量与「需要 40 级」那条负例。
    """
    store, _summary, _session = gm._store(character_id)
    with store.lock:
        current = int(getattr(store.state.character, "level", 0) or 0)
    if current == amount:
        log(f"角色 {character_id} 已是 {current} 级，跳过")
        return
    gm.run_action("level", {"characterId": character_id, "operation": "set", "amount": amount})
    log(f"角色 {character_id} 等级设为 {amount}")


def seed_mai_opened(gm, character_id: int, plan: list[tuple[int, int]]) -> None:
    """把「某几门已经开了几枚穴位」写进存档（`--mai-opened "1:17"`，八门开通在线门用）。

    为什么要有这个开关：穴位成功率是**表里的真值**（`数据/经脉.json` 每枚的 `prob`，
    10~100），而**没有任何一枚是 0** ⇒「开通失败」那一支在服务端（`_attempt_mai_point`
    的 `pending is None`）只在 `probability <= 0` 时才**必然**走到。想在一门新号上验证
    "失败到底出不出声、已开数会不会被骗"，只有两条路：把号挪到低概率穴位，或者连点几十次赌运气。
    前者是这条开关，后者会把在线门拖成两三分钟还留 0.1% 的随机红 —— 选了前者。

    写的是 `progression.stage_progress["八门:<list>:<门>"]`，**就是服务端自己读的那两处**：
    `_attempt_mai_point` 的 `point_id != 已开数 ⇒ 必须按顺序开通`，与 `_send_mai_statistics`
    里拼 `exploded` 的那一圈 ⇒ 客户端统计帧跟着变，不是只骗得过发包。
    `list` 恒 **0**：`_current_mai_list_id()` = `stages.get("八门", 0)`，夹具角色从没突破过门 ⇒ 就是 0。
    """
    store, _summary, _session = gm._store(character_id)
    with store.lock:
        for mai_id, count in plan:
            store.state.progression.stage_progress[f"八门:0:{mai_id}"] = int(count)
    log(f"角色 {character_id} 的八门已开数已铺成 {plan}（当前列表 0）")


def seed_ling_qi_appearance(server, gm, character_id: int, stage: int = 6) -> None:
    """给「十拳剑改变外观」铺前置：**开光十拳剑真的穿在灵器槽(-23)**、写轮眼阶数到 6。

    这两条就是服务端 `_ling_qi_appearance_unlocked` 的全部闸门（`fake_flash_server.py:52454`）：
      · 槽 -23 的 item_id == 20200001（开光那件；未开光 20100001 不算）
      · `progression.stages["写轮眼"]` >= 该脸要求的阶数；脸 10000038/10000067 要 6、
        10000074 要 7、10000075 要 8 ⇒ 6 阶正好是「前两档解锁、后两档灰」的判据。
    直接改存档（与 `--wear-damage` / `seed_mai_opened` 同一类夹具造态），不走协议：
    客户端要验的是**这个状态下的 UI 与协议**，不是「怎么穿上去」。
    """
    gm.run_action("item", {"characterId": character_id, "itemId": 20_200_001, "quantity": 1})
    store, _summary, _session = gm._store(character_id)
    with store.lock:
        old_key = next(
            (key for key, item in store.state.inventory.items()
             if int(getattr(item, "item_id", -1)) == 20_200_001 and int(key) > 0),
            None,
        )
        if old_key is None and int(getattr(store.state.inventory.get(-23), "item_id", -1)) != 20_200_001:
            log("⚠️ 开光十拳剑没发出来，灵器外观那条腿的前置没造上")
            return
        if old_key is not None:
            if -23 in store.state.inventory:
                del store.state.inventory[-23]
            item = store.state.inventory.pop(old_key)
            item.slot = -23
            store.state.inventory[-23] = item
        store.state.progression.stages["写轮眼"] = int(stage)
        store.save()
    log(f"角色 {character_id} 已穿开光十拳剑（槽 -23），写轮眼设为 {stage} 阶")


def seed_legacy(server, gm, character_id: int) -> dict:
    """给"传承在线"用的角色备料：卡牌节点 40 的五种材料、宝箱钥匙、双槽料理食材、ZQ。

    依据（都是服务端数据，不是猜的）：
    - 卡牌节点 40「火影套卡」要求 12100000×20 / 12100001×15 / 12100002×10 /
      12100003×5 / 12100004×2，奖励 10 AP（get_card_node(40,0)）。
    - 双槽料理要求两件 `item_id // 10000 == 1601` 的不同食材，产物由
      cooking_result() 决定；16010002 + 16010005 → 15003016「糯米丸子」，
      烹饪消耗 2000 金币。
    - 结印一次扣 1000 ZQ，用例断言扣完剩 19000，所以预置 20000。
    """
    plan = (
        (12100000, 20),
        (12100001, 15),
        (12100002, 10),
        (12100003, 5),
        (12100004, 2),
        (16000053, 1),   # 宝箱钥匙：服务端只在箱子未打开时才扣，而"关闭"是空操作，
                         # 所以开两次也只消耗 1 个（用例断言初始恰好 1 个）
        (16010002, 1),   # 双槽料理第一格
        (16010005, 1),   # 双槽料理第二格
        #   15020001 手里剑修炼符 —— **暗器那步要它**。服务端 `_train_an_qi`
        #   （`fake_flash_server.py:51827`）每张 +50 熟练度，id 与增量取自
        #   GameData `Etc.AnQi.common.speedUp = {needItemId: 15020001, addMaster: 50}`
        #   —— **与客户端 `手里剑数据.gd` 的 `提速` 一项吻合**。
        #   用例断言"一次 use_all 就做到 stage1 的 4 级满"：4 级 × `master_max` 5000
        #   = 20000 熟练度 → 400 张，给足一点。
        (15020001, 500),
    )
    store, _summary, _session = gm._store(character_id)
    with store.lock:
        owned: dict[int, int] = {}
        for item in store.state.inventory.values():
            owned[int(item.item_id)] = owned.get(int(item.item_id), 0) + int(item.quantity)
    grant_items(server, gm, character_id, plan, owned, 标签="传承材料")

    gm.run_action("currency", {"characterId": character_id, "currency": "zq", "operation": "set", "amount": 20000})

    store, _summary, _session = gm._store(character_id)
    with store.lock:
        slots: dict[int, int] = {}
        for item in store.state.inventory.values():
            if int(item.item_id) in (16010002, 16010005) and int(item.slot) > 0:
                slots.setdefault(int(item.item_id), int(item.slot))
    log(f"角色 {character_id} 传承材料已备（融合槽位 {slots}）")
    return {
        "legacy_fusion_first_slot": slots.get(16010002, 0),
        "legacy_fusion_second_slot": slots.get(16010005, 0),
    }


def seed_currency(gm, character_id: int) -> None:
    for currency, amount in (
        ("money", MAIN_MONEY),
        ("cash_money", MAIN_CASH_MONEY),
        ("coupon_money", MAIN_COUPON_MONEY),
        #   zq（查克拉精华）以前只给"传承同伴"(角色2)种过（seed_legacy）——主角色恒 0，
        #   `handle_can_juan_action` 的精华闸（needZq=100/发）把「秘笈合成在线」门整条挡死。
        ("zq", 20000),
    ):
        gm.run_action(
            "currency",
            {"characterId": character_id, "currency": currency, "operation": "set", "amount": amount},
        )
    log(f"角色 {character_id} 货币已设置（金币 {MAIN_MONEY} / 点券 {MAIN_CASH_MONEY} / 精华 20000）")


def seed_spirit(gm, character_id: int) -> None:
    """给「意志在线」门铺路（2026-10-03 接 1823）：`complete-pve`（gm_admin `complete_pve`）
    把 pve_points（阅历）灌到 999999 —— 新档阅历恒 0，`_gain_spirit_from_teacher` 必被
    "阅历不足"分支挡（那一支回 pve 状态帧、不动面板），action2→cmd1→拾取 链路就没法钉。
    ⚠️ 顺带把 pve_progress 设为满档：**只影响 pve 状态帧的显示值**，
    现有绿门里没人断言 pve_points/pve_progress 的具体数（全量 21+3 验证过）。"""
    gm.run_action("complete-pve", {"characterId": character_id})
    log(f"角色 {character_id} 阅历已灌满（complete-pve，意志学习前置）")


def seed_boss_kills(gm, character_id: int, count: int) -> None:
    """把存档里的 BOSS 击杀计数钉成 `count`（首杀礼包的领取条件读它）。

    为什么不走 GM：`gm_admin` 没有「+击杀数」这个动作，而首杀礼包的服务端闸
    `state.activity_boss_kills < 1` 只看这个数。给 0 ⇒ 验「一只都没杀，领不到」；
    给 3 ⇒ 验「达标能领、且只能领一次」。没传 `--boss-kills` 就不动存档（恒 0 = 新档默认）。
    """
    store, _summary, _session = gm._store(character_id)
    with store.lock:
        store.state.activity_boss_kills = int(count)
        store.save()
    log(f"角色 {character_id} BOSS 击杀数设为 {count}（首杀礼包条件）")


def seed_combat_stats(gm, character_id: int) -> None:
    """把主角的敏捷点上去，让**在线暴击**真能发生（否则红字那条门永远等不到 `bsk=1`）。

    为什么非做不可：暴击率 = `min(500, 每5点敏捷4‰)`（服务端 `_base_attribute_bonuses`
    → `_roll_combat_rate`），而夹具角色**默认 ap 全 0** ⇒ `_roll_combat_rate(0)` 恒 false
    ⇒ 243 第 4 段永远是 0 ⇒ "在线见过一次暴击红字"这条断言要么写不成、要么被写成
    "没见到也绿"的假绿。敏捷点到 `MAIN_AP_DEX=1000` ⇒ 800‰ 被原版上限夹到 **500‰（50%/刀）**，
    连打十余刀一次不暴的概率 0.5^12≈0.02%，够稳；副作用只是这个测试号打得狠一点。
    ⚠️ 直接写 `ap_dex`（GM 没有加点动作）；`from_dict` 的加载期只会把它夹到 [0,0xFFFF]，1000 稳过。
    """
    store, _summary, _session = gm._store(character_id)
    with store.lock:
        store.state.character.ap_dex = max(
            int(getattr(store.state.character, "ap_dex", 0) or 0), MAIN_AP_DEX
        )
        # 罪恶值（服务端 `StatType.CRIME = 33`）。**必须给非零**，否则门分不出
        # "接上了、值真是 0" 和 "根本没接上、躺在默认 0" —— 那是**假绿**的形状。
        # 人物属性窗那行读的就是它（原版 `DataCenter.as:1464` `fame = stats.crime`）。
        store.state.character.crime = MAIN_CRIME
        store.save()
    log(f"角色 {character_id} 敏捷设为 {MAIN_AP_DEX}（暴击率夹到原版上限 500‰，供在线暴击红字验证）"
        f"、罪恶值设为 {MAIN_CRIME}（供「罪恶值」那一行的在线断言）")


class 追踪背包(dict):
    """排查用：背包字典被改写时打印调用栈。

    服务端在 enter_game 里遍历 inventory.values()，若期间有别的代码改动这个字典，
    CPython 会抛 "dictionary changed size during iteration"。用它定位是谁在改。
    """

    def __setitem__(self, key, value):  # noqa: D105
        import traceback

        print(f"[夹具-背包改写] set {key}", flush=True)
        traceback.print_stack()
        super().__setitem__(key, value)

    def __delitem__(self, key):  # noqa: D105
        import traceback

        print(f"[夹具-背包改写] del {key}", flush=True)
        traceback.print_stack()
        super().__delitem__(key)


def build_fixture(server, gm, *, items=None, skills=None, with_pets: bool = True, trace_inventory: bool = False,
                  reset_xinfa_default: bool = False, wear_damage=None,
                  with_main_family: bool = False, mai_opened=None, ling_qi_appearance: bool = False,
                  peer_level: int = 0, peer_gold: int = 0, with_peers: bool = True,
                  boss_kills: int = 0) -> dict:
    service = server.ACCOUNT_SERVICE

    main_account = ensure_account(service, MAIN_ACCOUNT, MAIN_PASSWORD, first_character_id=1)
    main_character = ensure_character(service, main_account, MAIN_CHARACTER_NAME)
    main_id = int(main_character["id"])
    seed_character_identity(gm, main_id, MAIN_CHARACTER_NAME)

    if with_pets:
        seed_pets(server, gm, main_id)
    seed_skills(server, gm, main_id, skills=skills, reset_xinfa_default=reset_xinfa_default)

    seed_level(gm, main_id)
    seed_items(server, gm, main_id, items=items)
    seed_forge_ready_weapon(server, gm, main_id)
    if wear_damage:
        seed_worn_damage(server, gm, main_id, wear_damage)
    seed_currency(gm, main_id)
    seed_spirit(gm, main_id)
    seed_combat_stats(gm, main_id)
    if mai_opened:
        seed_mai_opened(gm, main_id, mai_opened)
    if ling_qi_appearance:
        seed_ling_qi_appearance(server, gm, main_id)
    # 首杀礼包在线门：0 = 未达标腿（领不到），>0 = 达标腿（能领、且只能领一次）。
    seed_boss_kills(gm, main_id, int(boss_kills or 0))

    ## 两个测试同伴（`社交同伴` = 对端、`传承同伴` = 老门禁那条腿的对端）**只给门禁根造**。
    ## 10-24 用户实机报：竞技场排名里冒出一个他没见过的角色 —— 查下来就是启动器用
    ## `.fixture-play`（他的玩档根）跑这份夹具，把 `传承同伴`（100 级）也种了进去，
    ## 而服务端 `_arena_snapshots:29175-29190` 的规则是“全服角色 level>=45 都进候选池”。
    ## 玩档根加 `--no-peers` ⇒ 只种主角色；门禁根（`.fixture`）照旧两条腿都要。
    peer_account = None
    peer_id = 0
    peer_family = None
    main_family = None        # ⚠ 这一枚以前只在 `if with_peers:` 里赋值，`--no-peers` 时
                              #    下面那句 `int(main_family["id"]) if main_family else 0` 直接
                              #    UnboundLocalError ⇒ **夹具一启动就崩、服务端根本没监听**
                              #    ⇒ 玩家侧现象是"连接不上服务器"（10-24 我自己踩出来的）
    legacy_state: dict = {}
    legacy_peer_id = 0
    if with_peers:
        peer_account = ensure_account(service, PEER_ACCOUNT, PEER_PASSWORD)
        peer_character = ensure_character(service, peer_account, PEER_CHARACTER_NAME)
        peer_id = int(peer_character["id"])
        seed_character_identity(gm, peer_id, PEER_CHARACTER_NAME)
        ## 对端等级：默认不动（恒 1 级，别的门钉过他的 1 级血量与「需要 40 级」那条负例）；
        ## 只有 `--peer-level` 明确给了数才升（师徒那条腿要他坐在 10~59 这一档，见 `seed_level` 的注）。
        if peer_level:
            seed_level(gm, peer_id, peer_level)
        ## 对端金币：**默认一个子都不给**（恒 0，别的门钉过"他买不起"这类负例）。
        ## 只有 `--peer-gold` 明确给数才种 —— 「看摊」那条腿要他**真买得起**：
        ## 服务端 `_buy_stall_listing:25891-25896` 余额不够就 `return False`，
        ## 而 action 7 那支（`:25616-25625`）对失败**一个字都不回** ⇒ 不给钱的话
        ## 现象是"点了购买什么都没发生"，门会以为代码坏了（其实是夹具缺前置）。
        if peer_gold:
            gm.run_action("currency", {"characterId": peer_id, "currency": "money",
                                       "operation": "set", "amount": peer_gold})
            log(f"角色 {peer_id} 金币已设为 {peer_gold}（看摊那条腿要他买得起）")
        seed_items(server, gm, peer_id, items=PEER_ITEMS)
        wear_peer_kun_chong(gm, peer_id)
        ## 对端也得有宠物：`58:0` 的段 32 是服务端按**他**的存档编的，他没宠物时那一串就是 `-`，
        ## 「看别人」那扇的宠物页在门里就永远是空态（与装备格、虫槽同一族教训：空态不是判据）。
        seed_peer_pets(server, gm, peer_id)
        peer_family = seed_peer_family(service, peer_account)
        main_family = seed_main_family(service, main_account) if with_main_family else None
        legacy_state = seed_legacy(server, gm, peer_id)

        legacy_peer_account = ensure_account(service, LEGACY_PEER_ACCOUNT, LEGACY_PEER_PASSWORD)
        legacy_peer_character = ensure_character(service, legacy_peer_account, LEGACY_PEER_CHARACTER_NAME)
        legacy_peer_id = int(legacy_peer_character["id"])
        seed_character_identity(gm, legacy_peer_id, LEGACY_PEER_CHARACTER_NAME)
        seed_level(gm, legacy_peer_id)  # 要能跟着主角色切图（木叶村要求 10 级）

    if trace_inventory:
        store, _summary, _session = gm._store(main_id)
        with store.lock:
            store.state.inventory = 追踪背包(store.state.inventory)
        log(f"已给角色 {main_id} 的背包挂上追踪（会打印改写调用栈）")

    return {
        "main_account": MAIN_ACCOUNT,
        "main_character_id": main_id,
        "main_character_name": MAIN_CHARACTER_NAME,
        "peer_account": PEER_ACCOUNT,
        "peer_character_id": peer_id,
        "peer_character_name": PEER_CHARACTER_NAME,
        "peer_family_id": int(peer_family["id"]) if peer_family else 0,
        "peer_family_name": str(peer_family["name"]) if peer_family else "",
        "main_family_id": int(main_family["id"]) if main_family else 0,
        "main_family_name": str(main_family["name"]) if main_family else "",
        "legacy_main_character_id": peer_id,
        "legacy_peer_character_id": legacy_peer_id,
        "legacy_peer_character_name": LEGACY_PEER_CHARACTER_NAME,
        "legacy_peer_account": LEGACY_PEER_ACCOUNT,
        "legacy_peer_password": LEGACY_PEER_PASSWORD,
        **legacy_state,
        "port": int(os.environ["NARUTO_SERVER_PORT"]),
        "boss_kills": int(boss_kills or 0),
    }


def assert_port_free(port: int) -> None:
    """端口必须空闲，否则夹具自己的服务端起不来，而用例会**静默连到别人**。

    这个坑真踩过：手工试玩时留在后台的夹具占着 18684，随后跑用例时新夹具绑不上端口，
    但 wait_for_listener 只判断"端口有人在听"，被残留服务端满足，于是用例连到了
    试玩用的旧存档上，表现为一堆莫名其妙的断言失败（例如战斗结算不回包）。
    """
    import socket

    with socket.socket() as probe:
        probe.settimeout(0.5)
        if probe.connect_ex(("127.0.0.1", port)) == 0:
            raise SystemExit(
                f"端口 {port} 已被占用：可能是上一次的夹具、或手工试玩时起的服务端还在跑。"
                "先把它停掉再跑用例，否则用例会连到那个旧服务端上。"
            )


def wait_for_listener(port: int, timeout: float = 30.0) -> bool:
    import socket

    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.5):
                return True
        except OSError:
            time.sleep(0.2)
    return False


def run_godot(godot: str, client_root: Path, script: str, state: dict) -> int:
    """用夹具导出的编号作环境变量跑一条 Godot 用例，返回它的退出码。"""
    import subprocess

    env = dict(os.environ)
    env["NW_SOCIAL_PEER_ID"] = str(state["peer_character_id"])
    # 角色名要给用例：服务端限 2-12 位，"CodexSocialPeer" 这类长名建不出来，
    # 而加好友是按名字查找的，名字不一致就永远找不到对方。
    env["NW_SOCIAL_PEER_NAME"] = str(state.get("peer_character_name", ""))
    # 同伴名下的家族（`seed_peer_family`）—— 「申请加入」用例要申请它。
    env["NW_PEER_FAMILY_ID"] = str(state.get("peer_family_id", 0))
    env["NW_PEER_FAMILY_NAME"] = str(state.get("peer_family_name", ""))
    # 主角色当族长的族（`--main-family`）—— 族旗安插在线门要它。
    env["NW_MAIN_FAMILY_ID"] = str(state.get("main_family_id", 0))
    env["NW_MAIN_FAMILY_NAME"] = str(state.get("main_family_name", ""))
    # 同伴背包里那枚**羁绊对戒**（`PEER_ITEMS` 里 `190[1-8]0001` 那一位）——
    # 「羁绊在线」那一腿要拿它当参照值：门里手写第二个数，改了 夹具 那一头就悄悄对不上（10-17 定例）。
    # 取法与服务端同一条闸（`_is_bond_pair_item`：号域 + 末四位 0001），不另写一套正则。
    env["NW_PEER_RING_ID"] = str(next(
        (件号 for 件号, _数 in PEER_ITEMS if 19010001 <= 件号 <= 19080001 and 件号 % 10000 == 1),
        0,
    ))
    env["NW_LEGACY_MAIN_ID"] = str(state.get("legacy_main_character_id", state["peer_character_id"]))
    env["NW_LEGACY_PEER_ID"] = str(state.get("legacy_peer_character_id", state["peer_character_id"]))
    env["NW_LEGACY_PEER_ACCOUNT"] = str(state.get("legacy_peer_account", "naruto"))
    # 注册走的是**控制台口**的 HTTP（原版注册本来就是网页那条，游戏 TCP 没有这一号）
    # ⇒ 要测「注册 → 建角」的用例得知道它是几号；没起控制台时是 0，用例自己判。
    env["NARUTO_GM_HTTP"] = str(state.get("gm_http", 0))
    # 首杀礼包在线门按这个数分腿：0 ⇒ 验「领不到」，>0 ⇒ 验「能领且不重发」。
    env["NW_BOSS_KILLS"] = str(state.get("boss_kills", 0))
    env["NW_LEGACY_PEER_PASSWORD"] = str(state.get("legacy_peer_password", "123456"))
    for key in ("legacy_fusion_first_slot", "legacy_fusion_second_slot"):
        if key in state:
            env["NW_" + key.upper()] = str(state[key])
    log(f"跑用例 {script}")
    return subprocess.call(
        [godot, "--headless", "--path", str(client_root), "--script", script], env=env
    )


def 自审() -> int:
    """两种模式各起一个**真**服务端到临时根，只判一件事：日志里出现「服务端已监听」。

    为什么要这么一道：10-24 我加 `--no-peers` 时把 `main_family` 留在 `if with_peers:` 里面，
    而它在外层被无条件引用 ⇒ `UnboundLocalError` ⇒ **夹具一启动就崩、端口根本没监听**，
    用户侧现象就是"连接不上服务器"。而所有在线门/门禁走的都是默认那条（带同伴）⇒ **门全绿**。
    ⇒ 启动器用的那条路只有这里覆盖得到，改 `build_fixture` 的参数分支后必须跑这一条。
    """
    import subprocess
    import tempfile

    码 = 0
    for 带同伴 in (False, True):
        临时 = Path(tempfile.mkdtemp(prefix="夹具自审_"))
        端 = 18995 if 带同伴 else 18993
        命 = [sys.executable, str(Path(__file__).resolve()), "--root", str(临时), "--reset",
             "--port", str(端), "--gm-http", str(端 + 1)]
        if not 带同伴:
            命.append("--no-peers")
        进 = subprocess.Popen(命, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, encoding="utf-8", errors="replace")
        出 = ""
        好 = False
        截 = time.time() + 120
        while time.time() < 截:
            行 = 进.stdout.readline()
            if not 行:
                break
            出 += 行
            if "服务端已监听" in 行:
                好 = True
                break
        进.terminate()
        try:
            进.wait(timeout=10)
        except Exception:
            进.kill()
        shutil.rmtree(临时, ignore_errors=True)
        if 好:
            log(f"自审：{'带同伴（门禁那条路）' if 带同伴 else '--no-peers（启动器那条路）'}"
                f" 起得来，端口 {端} 已监听")
        else:
            码 = 1
            log(f"自审：{'带同伴' if 带同伴 else '--no-peers'} **起不来**，端口 {端} 没监听。输出尾部：")
            for 行 in 出.splitlines()[-12:]:
                log("  | " + 行)
    log("自审：" + ("两种模式都起得来" if 码 == 0 else "有模式起不来 -> 别发给用户"))
    return 码


def main() -> None:
    自审模式 = "--self-check" in sys.argv
    parser = argparse.ArgumentParser(description="隔离的本地服务端夹具")
    parser.add_argument("--root", required=not 自审模式, help="隔离存档根目录")
    parser.add_argument("--self-check", action="store_true",
                        help="只冒烟：带同伴 / --no-peers 两种模式各起一次服务端，判端口有没有监听")
    parser.add_argument("--port", type=int, default=18684)
    parser.add_argument("--state-out", default="")
    parser.add_argument("--reset", action="store_true")
    parser.add_argument("--print-only", action="store_true")
    parser.add_argument("--no-pets", action="store_true", help="不造宠物（排查用）")
    parser.add_argument("--no-peers", action="store_true",
                        help="不造两个测试同伴（启动器的玩档根用这条，免得测试号混进竞技场排名）")
    parser.add_argument("--items", default="", help='覆盖背包物品，形如 "3000001:20,2010010:1"（排查用）')
    parser.add_argument("--wear-damage", default="",
                        help='把背包里的装备穿上并扣掉耐久，形如 "1010013:10,1010033:5"（在线修理门用）')
    parser.add_argument("--skills", default="", help='覆盖预置已学技能，形如 "9029,1000,1001"（心法那条要用 xinfa 编号）')
    parser.add_argument("--peer-gold", type=int, default=0,
                        help="给对端种这么多金币（默认 0 = 不动）。"
                             "「看摊购买」那条腿要用：服务端余额不够就静默不成交")
    parser.add_argument("--peer-level", type=int, default=0,
                        help="把对端（社交同伴）升到这个等级（默认 0 = 不动，保持 1 级）。"
                             "师徒那条腿要用：服务端对 77:3/77:4 两道等级闸见 seed_level 的注")
    parser.add_argument("--reset-xinfa-default", action="store_true",
                        help="抹掉存档里的 defaultXinfaId，让服务端走它自己的回落分支（心法在线那条用）")
    parser.add_argument("--trace-inventory", action="store_true", help="背包被改写时打印调用栈（排查用）")
    parser.add_argument("--main-family", action="store_true",
                        help="给主角造一个自己当族长的家族（族旗安插在线门用）")
    parser.add_argument("--ling-qi-appearance", action="store_true",
                        help="主角色穿开光十拳剑到灵器槽(-23)、写轮眼 6 阶（十拳剑改变外观门用）")
    parser.add_argument("--mai-opened", default="",
                        help='把八门某几门的已开穴位数写进存档，形如 "1:17"（在线开通的失败腿用）')
    parser.add_argument("--boss-kills", type=int, default=0,
                        help="把主角存档的 BOSS 击杀数钉成 N（首杀礼包在线门：0=未达标腿，3=达标腿）")
    parser.add_argument("--gm-http", type=int, default=0,
                        help="顺带起 GM 网页控制台（0=不起），如 18680")
    parser.add_argument("--run", default="", help='跑一条用例，如 "res://测试/商城真实事务回归测试.gd"')
    parser.add_argument("--godot", default="", help="Godot console 可执行文件路径（配合 --run）")
    parser.add_argument("--client-root", default=str(Path(__file__).resolve().parent.parent))
    args = parser.parse_args()

    if args.self_check:
        raise SystemExit(自审())

    items = None
    if args.items:
        items = []
        for piece in args.items.split(","):
            item_id, _, quantity = piece.partition(":")
            items.append((int(item_id), int(quantity or 1)))

    skills = None
    if args.skills:
        skills = [int(x) for x in args.skills.split(",") if x.strip()]

    wear_damage = None
    if args.wear_damage:
        wear_damage = []
        for piece in args.wear_damage.split(","):
            item_id, _, missing = piece.partition(":")
            wear_damage.append((int(item_id), int(missing or 1)))

    mai_opened = None
    if args.mai_opened:
        mai_opened = []
        for piece in args.mai_opened.split(","):
            mai_id, _, count = piece.partition(":")
            mai_opened.append((int(mai_id), int(count or 0)))

    root = Path(args.root).resolve()
    assert_port_free(args.port)
    if args.reset and root.exists():
        shutil.rmtree(root)
        log(f"已清空 {root}")
    prepare_environment(root, args.port)

    server, gm = load_server_modules()
    state = build_fixture(
        server, gm, items=items, skills=skills, with_pets=not args.no_pets, trace_inventory=args.trace_inventory,
        reset_xinfa_default=args.reset_xinfa_default, wear_damage=wear_damage,
        with_main_family=args.main_family,
        mai_opened=mai_opened,
        ling_qi_appearance=bool(args.ling_qi_appearance),
        peer_level=int(args.peer_level or 0),
        peer_gold=int(args.peer_gold or 0),
        with_peers=not args.no_peers,
        boss_kills=int(args.boss_kills or 0),
    )

    if args.state_out:
        Path(args.state_out).write_text(
            json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        log(f"状态已写入 {args.state_out}")
    log(f"主角色 id={state['main_character_id']}，同伴角色 id={state['peer_character_id']}"
        + ("" if state["peer_character_id"] else "（--no-peers：本根不造测试同伴）"))
    if int(state.get("main_family_id", 0)) > 0:
        log(f"主角家族 id={state['main_family_id']}（{state.get('main_family_name', '')}，主角色是族长）")

    if args.print_only:
        return

    threading.Thread(target=server.serve_forever, daemon=True).start()
    if not wait_for_listener(args.port):
        raise SystemExit(f"服务端没能在 {args.port} 上监听")
    log(f"服务端已监听 127.0.0.1:{args.port}")

    if args.gm_http:
        # GM 控制台必须在本进程里起：gm_admin 拿的是内存中的 store 与在线 session，
        # 另起一个进程写档会被跑着的服务端下一次 save 顶掉。
        assert_port_free(args.gm_http)
        import GM控制台服务

        GM控制台服务.起服务(args.gm_http, gm, log, 服务端=server)

    state["gm_http"] = int(args.gm_http or 0)

    if args.run:
        if not args.godot:
            raise SystemExit("--run 需要同时给 --godot <console.exe>")
        code = run_godot(args.godot, Path(args.client_root), args.run, state)
        log(f"用例退出码 {code}")
        raise SystemExit(code)

    print(f"READY {state['main_character_id']}", flush=True)
    while True:
        time.sleep(60)


if __name__ == "__main__":
    main()
