# -*- coding: utf-8 -*-
"""导 `数据/界面/木叶村NPC.json` —— 木叶村（地图 100000000）全部 25 枚 NPC 的**真菜单表**。

## 为什么这张表必须存在（而不是"看着截图写菜单"）
原版客户端里**没有** 「service 字符串 → 窗口类」这张映射表（全树 grep `service` 在 .as 里 0 命中，
`NPCSpawnInfo.as:10-38` 只有 npcId/foothold/position/rx0/rx1/dir/objectId）。
真实链条是：
    点 NPC → NPCTalkProcessor.as:34-53 → Client.as:3416-3419 → UIMain2.as:3366-3370
          → QuestDialog.showDialog（`extends Sprite`、无窗壳）
    点菜单行 → QuestDialog.as:129-135 → requestNPCMoreTalkEx(NPCTalkCmdType.MENU=2, value)
          → **回服务端**，那扇窗由**后续回帧**才打开（`Client.as:1149/1210` 两条就是实例）。
而菜单内容**全在服务端组装**：`fake_flash_server.py:_send_current_npc_dialog():51690-51727`
    服务菜单(NPC_SERVICE_MENUS[template_id]) → 仓库补行 → 物品交易补行 → 卡片补行 → 「离开」

⇒ 所以本工程只能**照抄服务端那五步组装**，逐条带行号；任何"从画面上数出来的菜单"都不算真值。

## 已验证的对应关系（阳性对照，别改成"更合理"的版本）
`template_id == NPC.json 的八位编号` —— 13 条对得上才敢这么钉：
    11 伊鲁卡=变身卡与道具兑换 / 12 鸣人=跨服忍界大战 / 13 小樱=打开仓库 /
    17 李洛克=中忍考试 / 18 纲手=挑战副本+挑战精英副本 / 19 静音=勾玉炼制 /
    20 阿凯=生命料理 / 21 卡卡西=亲热天堂 / 22 三代=重置潜能点 / 28 自来也=百炼忍传 /
    29 鹿丸=卡片套册收集 / 30 佐助=神器战场 / 32 木叶丸=徽章打造
唯一例外：**76 = 转职导师**（服务端在 `:8913-8915` 显式覆盖名字与台词，且它不在木叶村）。

重跑：`python 开发工具/出木叶村NPC表.py`

## 2026-10-04 夜：数据源从 `nya-go` 换到 **2.2.3优化版 自带的服务端**
用户下单「按 2.2.3优化版 制作，不要按分发版」。盘上有三份 `fake_flash_server.py`
（2.2.3优化版 2,685,523 / nya-go 2,725,438 / V2.6分发版 2,857,155，行数 62096 / 62938 / 64774），
`开发工具/核菜单版本.py` 实测：**这四枚动作值三版一致**（`ITEM_EXCHANGE=9`、
`TRANSFORM_CARD_SWAP=31`、`TRANSFORM_CARD_SPECIAL_SWAP=32`、`CARD_COLLECTION=8`），
但**每一条的行号都不同** ⇒ 本文件与 `真值/窗口/木叶村NPC.md` 的行号一律改成 2.2.3 那一列
（`NpcMenuAction :1110-1149`、`NPC_SERVICE_MENUS :10929-10951` + 追加 `:10952/:10957`、
`_send_current_npc_dialog :51690-51727`、转职导师覆盖 `:8913-8915`）。
换源后重导一次，产物 json **逐字节不变** —— 这条就是"表没被版本带偏"的证据，
而不是"我以为它没被带偏"。
"""
import io
import json
import os
import re
import sys

项目 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
原版根 = os.environ.get("NARUTO_GAME_ROOT") or os.path.join(项目, "..", "2.2.3")
服务端 = os.path.join(原版根, "tools", "fake_flash_server.py")
落 = os.path.join(项目, "数据", "界面", "木叶村NPC.json")

木叶村 = 100000000		# 数据/地图名.json

# ── 动作值（`fake_flash_server.py:1112` class NpcMenuAction，逐条抄，别算） ───
动作 = {
    "LEAVE": -1, "QUEST": 0, "SHOP": 1, "STORAGE": 2, "TELEPORT": 3, "ORIGINAL_QUEST": 4,
    "PROGRESSION": 5, "SOLO_TRIAL": 6, "ACHIEVEMENTS": 7, "CARD_COLLECTION": 8,
    "ITEM_EXCHANGE": 9, "JOB_TRANSFER": 10, "PVE": 11, "COPY": 12, "BADGE": 13,
    "TREASURE": 14, "COOKING": 15, "ESCORT": 16, "JADE": 17, "WAR": 18,
    "ARTIFACT_WAR": 19, "CHUNIN_EXAM": 20, "JOB_FIRE": 21, "JOB_WATER": 22,
    "JOB_THUNDER": 23, "JOB_WIND": 24, "TOTSUKA_EXCHANGE": 25, "WASH_POINT": 26,
    "ARTIFACT_INFO": 27, "RENJU_EXCHANGE": 28, "JOB_EQUIPMENT_CONVERT": 29,
    "ELITE_COPY": 30, "TRANSFORM_CARD_SWAP": 31, "TRANSFORM_CARD_SPECIAL_SWAP": 32,
}

# ── 服务菜单（`fake_flash_server.py:10926` NPC_SERVICE_MENUS，含两条 :10952/:10957 追加；
#    卡片补行那支看 :10928 `CARD_COLLECTION_NPC_TEMPLATE_IDS = {29}`） ─
服务菜单 = {
    11: [("变身卡与道具兑换", "ITEM_EXCHANGE"),
         ("变身卡属性交换", "TRANSFORM_CARD_SWAP"),
         ("变身卡特殊属性交换", "TRANSFORM_CARD_SPECIAL_SWAP")],
    12: [("跨服忍界大战", "WAR")],
    13: [("打开仓库", "STORAGE")],
    17: [("中忍考试", "CHUNIN_EXAM")],
    18: [("挑战副本", "COPY"), ("挑战精英副本", "ELITE_COPY")],
    19: [("勾玉炼制", "JADE")],
    20: [("生命料理", "COOKING")],
    21: [("亲热天堂", "TREASURE")],
    22: [("重置潜能点", "WASH_POINT")],
    28: [("百炼忍传", "PVE")],
    30: [("神器战场", "ARTIFACT_WAR")],
    32: [("徽章打造", "BADGE")],
    59: [("灵器介绍", "ARTIFACT_INFO"), ("兑换十拳剑", "TOTSUKA_EXCHANGE"),
         ("兑换忍具", "RENJU_EXCHANGE")],
    76: [("忍者转职", "JOB_TRANSFER"), ("职业装备转换", "JOB_EQUIPMENT_CONVERT")],
}

# ── 环任务行（**不在 `NPC_SERVICE_MENUS` 里**，是 `_npc_quest_selections` 的 selection 段）──────
# 服务端 `fake_flash_server.py` 里 `template_id == 27` 那一段（起 :51413，两行 :51433 / :51442）
# 硬编码给宇智波富岳两行：`每日环任务&8001&…&20&8001`（lv≥20）、`周试炼任务&8002&…&100&8002`（lv≥35）。
# ⚠ `&` 后面那个数是 **questId**，不是 `NpcMenuAction` ⇒ 别拿它去查动作码。
# ⚠ 原版显示顺序是「menu 行在前、selection 行在后」（`QuestDialog.as:215-236` 再 `:256-275`），
#    而且 selection **不是一行一个按钮**，是一整块带链接的富文本 ⇒ 客户端按 `任务行` 这个键单独存。
环任务行 = {
    # 落地页两格在 **2026-10-05 建完两扇窗后翻成页名**（之前留空 ⇒ 点行只出「还没移植」通知条、
    # 不去开一扇不存在的页）。
    # 后三列 = 客户端画 selection 链接块要的三个数（原版从任务配置里查，我们直接烘进表）：
    #   类型 = `数据/任务.json` 的 `info.type`（daily / weekly ⇒ 决定前缀 `[日环]` / `[周环]`
    #          与要不要拼 `(次数/上限)`，`QuestDialog.as:258-313`）；
    #   上限 = `info.loopCount`（20 / 100，与服务端行里那个硬编码上限同源）；
    #   次数 = 服务端 `min(已接+1, 上限)`（`fake_flash_server.py:51432-51447`）在**新号（已接=0）**
    #          时的值 ⇒ 1；在线时这个数由 328 帧第 6 段覆盖，不许拿它当玩家进度。
    27: [dict(文字="每日环任务", 任务id=8001, 键="QUEST_DAILY", 门槛=20,
              原版类="component/RefreshDailyQuestWindow", 尺寸="355×407", 落地页="日环任务",
              类型="daily", 上限=20, 次数=1, 任务状态=0),
         dict(文字="周试炼任务", 任务id=8002, 键="QUEST_WEEKLY", 门槛=35,
              原版类="component/DailyQuestWindow", 尺寸="355×367", 落地页="周试炼任务",
              类型="weekly", 上限=100, 次数=1, 任务状态=0)],
    # 油女志乃（23）的**护送行**：也不在 `NPC_SERVICE_MENUS` 里（模板 23 根本没有服务菜单，
    # 对话窗只有「离开」）。服务端 `:51444-51466` 在 `npc.template_id == 护送起始NPC`
    # （`_escort_start_npc_id():34640` = quest 8100 的 `start_npc_id`，`数据/任务.json` 里 8100
    # `npc.0 = 23`；查无定义才兜底 23）且 `level >= 30` 时补
    # `护送任务&8100&{status}&{min(完成+1,3)}&3&8100` ⇒ 上限 3 环、第八位 8100 是 questId。
    # ⚠ 这一行的**点击不走协议**：客户端在 HUSONG_QUEST 分支里把 value 强制改成 -1
    #   （`QuestDialog.as:301-305`，只在 status==0 时），于是 `:107-110` 直接本地
    #   `showHuSongQuestWindow(loopid,total)`；status 1/2 时 value 仍是 8100 ⇒ 发 SELECTION 8100，
    #   服务端 `:56417` 回 `_send_mixin_state()`。本工程按范围只做 UI+按钮 ⇒ 两种都本地开窗、不发帧。
    23: [dict(文字="护送任务", 任务id=8100, 键="ESCORT", 门槛=30,
              原版类="husong/HuSongQuestWindow", 尺寸="578×342", 落地页="护送任务",
              类型="mixin", 上限=3, 次数=1, 任务状态=0)],
}

商人模板 = {2, 3, 4, 7, 8, 10, 14, 15, 24, 25, 26, 31, 58}		# :10928 MERCHANT_NPC_TEMPLATE_IDS
仓库模板 = {13}									# :10888
卡片模板 = {29}									# :10889

# ── 动作 → 落地（原版类 + 尺寸 + 本工程页名 + 状态）─────────────────────────
# 原版类与尺寸全部来自 game-client 反编译脚本的行号（见 真值/窗口/木叶村NPC.md）；
# 「本工程」空 = 还没有这扇窗（状态里写清是哪一种）：
#   待建   = 原版类与尺寸都查实了，只是还没移植
#   查无   = 原版到底哪扇窗没定论 ⇒ **不许自造**，点了只给状态行
#   协议   = 不发帧的那一类（本工程范围：只做 UI 与按钮交互，协议要点头）
落地 = {
    "QUEST": ("MQuestionWindow", "524×396", "任务", "已有"),
    "SHOP": ("ShopWindow2", "275×325", "NPC商店", "已有"),
    "STORAGE": ("StorageWindow2", "275×394", "NPC仓库", "已有"),
    "COPY": ("copy/CopyWindow", "570×283", "副本", "已有(10-03)"),
    "ELITE_COPY": ("copy/EliteCopyWindow", "500×426", "精英副本", "已有(10-03)"),
    "TREASURE": ("TreasureBoxWindow", "357×338", "藏宝图", "已有"),
    "ITEM_EXCHANGE": ("exchangeShop/ExchangeShopWindow", "720×540", "兑换商店",
        "已建(2026-10-04 深夜：与本工程「兑换」=lingQi/DuiHuanWindow **不是同一扇**，两条落地页各自独立。"
        "行数据只有服务端 1820 那一帧有 ⇒ 离线是空态，量具/门喂 数据/界面/兑换商店_夹具.json)"),
    "TRANSFORM_CARD_SWAP": ("UIMain2 内联 _swapWindow", "420×395", "变身卡属性互换",
        "已建(双实现已择一：走 UIMain2 内联这一版，`equip/TransformCardSwapWindow` 280×200 那版不建)"),
    "TRANSFORM_CARD_SPECIAL_SWAP": ("UIMain2 内联 _swapWindow(特殊)", "420×495", "变身卡特性互换",
        "已建(同一 builder 的特殊模式；窗标题是「变身卡特性属性互换」，菜单行是「变身卡特殊属性交换」，两个都是原文)"),
    "WAR": ("kuafu/KuaFuChannelWindow", "595×451", "跨服频道",
        "已建(2026-10-06：⚠ 尺寸**不是 :39 的 595×414** —— `KuaFuChannelWindow.newView():65` "
        "第一句 `setSize(595,451)` ⇒ 稳态 451 高、内容底跟着长成 579×383（`UIWindow.setSize:50-55`"
        "→`drawWindowLayout:57-67` 只重算宽高、**不换 y** ⇒ 底顶仍是默认 38）。"
        "那一跳是**收到回帧才开窗**：点行发 `57:2:18` ⇒ 服务端 `:51881-51882` 直接转 "
        "`handle_war_panel_action(\"1825:0\")` ⇒ 回 `1825:0:1&忍界战场&{在线}:100` ⇒ "
        "`Client.as:4200-4203` → `KuaFuManager.onWarPanel_warServerInfo:516-527`"
        "（没开就 `showEnterBattleView()`、开了就 `setData`）。本工程照 副本/日环 口径"
        "**本地直开、不发帧**；两颗钮的**客户端闸门**（号>27 才卡 60~80 级 / 刷新 20 秒节流）已照搬，"
        "发帧那两支（`1825` 子命令 0 取列表 / 1 选服进场）未点头)"),
    "CHUNIN_EXAM": ("kuafu/ZhongRenJoinWindow", "280×150", "", "待建(+Rule/TimeRule/Description/ZhuWei 四副窗)"),
    "JADE": ("equip/YuLianJinJieWindow", "360×407", "勾玉炼制", "已建(2026-10-05 三页签:玉链升阶/勾玉合成/勾玉重置)"),
    "COOKING": ("equip/LiaoLiMadeWindow", "241×319", "生命料理",
                "已建(2026-10-06)：窗标题不是这一行的文字 —— `LiaoLiMadeWindow.as:308` "
                "`LIAOLIMADEWINDOW_TITLE` =「神 秘 料 理」（`message_properties.as:3307`，三字间各一个半角空格），"
                "菜单行「生命料理」、称号「生命の料理」是三个词。`super(241,319,true)`（`:56-59`）⇒ 宿主画内容底，"
                "**无 setSize / 无 setContentBgPos** ⇒ 稳态就是 241×319、底在 (8,38) 225×251。"
                "入口链（逐条）：服务端 `fake_flash_server.py:1131` 枚举 `COOKING = 15`、`:10933` 菜单表 "
                "`20: ((\"生命料理\", COOKING),)`、`:51543` 派发 ⇒ **只回 `1822:1:0`**"
                "（`BUFF_HECHENG`，常量 `:749/:919`）⇒ 客户端 `Client.as:10695-10698 onBuffHeCheng_showPanel` → "
                "`UIMain2.as:3928-3940 showLiaoLiWindow()` ⇒ **`centerTwoWindow(料理窗, ITEM_WINDOW2_F)` = 连背包成对摆位**"
                "（已加进 `窗口管理.gd` 的 `伴随背包`）；`:3930` 那句 `if (inKuaFuBattle()) return` 不移植（本地无跨服态）。"
                "⚠ 客户端里**没有 15→料理 的硬编码映射**（全树 grep `COOKING` 查无），开窗完全由服务端那一句 `1822:1` 驱动。"
                "三枚格（材料×2 + 成品×1）开窗就建、建了空着（`SimpleItemCell.hideIcon` ⇒ countLabel 是一个空格）；"
                "「放入材料」⇄「取出料理」同一颗钮换文案、两支都**不发帧**（拖放属 #8 未做）；"
                "「制作」⇒ `showLoadingBar(…, 500)` 后发 `1822:1 {item0,item1}`（`SendOpCodes.as:262`，"
                "`BuffHeChengProcessor.as:19-25,35-38`）⇒ **未点头 ⇒ 只回显**。"),
    "WASH_POINT": ("washPoint/WashPointWindow", "275×324", "洗点",
                "已建(2026-10-06)：⚠ 窗标题是「洗点」（`WashPointWindow.as:102` `CN.WASH_POINT`，"
                "`message_properties.as:2663`），菜单行写「重置潜能点」⇒ 两个词别互相顶掉；确认弹**同一个键**。"
                "⚠ 这扇**不是 `UIWindow` 族而是 `MWindow` 族**：`:73-77` `super(); init();`"
                "（`MWindow.as:65` 无参）⇒ 没有\"第三参\"可抄，尺寸唯一来源 `:265-266` 275×324，"
                "内容底是手工 MYellow `(6,39) 263×251`（⚠ y=39，不是 UIWindow 默认的 38）⇒ 尺寸表 `内容底: false`。"
                "入口链（服务端行号出自**钉住的** `2.2.3优化版/HYSJ/tools/fake_flash_server.py`，md5 前缀 399d5f55；"
                "机器上另有一份 `nya-go/fake_flash_server.py`（4f94592d）行号不同 ⇒ 别混）："
                "`:1140` 枚举、`:10938` 菜单表 `22: ((\"重置潜能点\", WASH_POINT),)`、`:51873-51876` 派发 ⇒ "
                "回 `1332:<npc对象id>:4`（panelId **4**）⇒ 客户端 `Client.as:5894` 的 `:5908-5910 case 4: "
                "setDOShow(UIConfig.WASH_POINT_WINDOW_F, true)`（`UIConfig.as:568`）。"
                "⚠ **走 `setDOShow`、没有 `centerTwoWindow` ⇒ 不连背包**（与 生命料理/徽章打造 正相反，行为门钉这一条）。"
                "另有第二扇 `washPoint/WashPointConfrimWindow`（⚠ 类名拼写照抄原版 `Confrim`）240×169 ⇒ "
                "点「开始洗点」本地弹（`:240-247`，`PopUpMananger.centerWindow(w,true)` = 居中 + 遮罩、点遮罩=取消），"
                "**没有 NPC 入口** ⇒ SPEC 用 `入口` 那格声明。四行属性 = `WashPointWindowCell`"
                "（2 张输入底 + 4 颗纯图钮 + 3 枚文字，行距 23 是字面量）；±/双± **全是本地算术不发帧**；"
                "真发帧在确认弹点「确定」之后 ⇒ `REWASH_AP = 83`（`SendOpCodes.as:80`）4×`writeShort`"
                "（apAtk,apDef,apDex,apPhy），服务端 `:686` 枚举、`:11657` 注册、`:12400` 解码、"
                "`:34475-34529` 处理 ⇒ **本机确实在处理**，本工程未点头 ⇒ 只回显。"),
    "PVE": ("copy/BailianWindow", "500×426", "", "待建(与精英副本同尺寸、格皮同源 UISwf_BailianCopy.swf)"),
    "BADGE": ("beastBadge/BeastBadgeWindow", "340×400", "徽章打造",
                "已建(2026-10-06)：窗标题「徽章打造合成」（`BeastBadgeWindow.as:139` `BEASTBADGE_WINDOW_TITTLE`，⚠ 键名拼错 TITTLE 照抄）—— 菜单行「徽章打造」、两枚页签「打造石合成 / 徽章强化」是**四个不同的词**（页签那枚语言键叫 `BEASTBADGE_CREATE`、中文却是「徽章强化」，别照键名写成「打造」）。"
                "`:33` `super(340,400,false)` ⇒ **UIWindow 不画内容底**、`:147-152` 类里手工 `new MYellow_background()` 摆 (5,60) 330×310 ⇒ 尺寸表 `内容底: false`；全链**无 `setSize`** ⇒ 340×400 就是稳态。⚠ 层序：`:146` tabBar **早于** `:152` 内容底 ⇒ 页签与底顶重叠那 2px 由**底压页签**（原版如此）。"
                "入口链（服务端行号出自**钉住的** `2.2.3优化版/HYSJ/tools/fake_flash_server.py`，md5 前缀 399d5f55；机器上另有一份 `nya-go/fake_flash_server.py`（4f94592d）行号不同 ⇒ 别混）：`fake_flash_server.py:1127` 枚举 `BADGE = 13`、`:10941` 菜单表 `32: ((徽章打造, BADGE),)`、`:51862-51865` 派发 ⇒ 回 `1332:<npc对象id>:11`（panelId **11**）⇒ `Client.as:5894 onShowNpcTriggerPanel` 的 `:5935-5937 case 11: API.ui.content.showBeastBadgeCreateWindow()` ⇒ `UIMain2.as:4547-4565`：**没开着就 `centerTwoWindow(BEASTBADGE_CREATE_WINDOW, ITEM_WINDOW2_F)` + `init()`（连背包成对摆位），已开着就 `deleteTwoWindow(…)`（成对关）** ⇒ 已加进 `窗口管理.gd` 的 `伴随背包`。"
                "⚠ 方法名 `showBeastBadgeCreateWindow` 里的 Create **不是类名** —— 类是 `UIConfig.as:558` `BEASTBADGE_CREATE_WINDOW = com.mxw.uifl.controls.beastBadge.BeastBadgeWindow`（照方法名去找文件会查无）。第二入口：背包右键「合成」(石头)/「强化」(徽章) ⇒ `ItemWindow2.as:786-790 / 813-816` → `UIMain2.as:5676-5688 showBeastBadgeCreateWindowWithData(tab, item)`（也成对、带参投料）。"
                "两页 pane（`StoneComposePane` / `BadgeComposePane`）**懒建后重挂、不重建**（`BeastBadgeWindow.as:60-99`），默认开页 **0 = 打造石合成**（`:101-103` `init(param1 = 0)`）；⚠ 每次切页都会调 `_badgeComposePane.backItemToEquip()`（`:83`/`:96`）⇒ **徽章投放位每次切页被清空**，原版如此。两页**共用算式但不是一组件**：绿/白两块文字的颜色（石页 UI_GREEN/UI_WHITE、徽页两枚都 UI_ORANGE）与 x 偏移（石页 +3、徽页 +2）都不同 ⇒ 逐件照抄，别合并。"
                "发帧面：页1「开始打造」⇒ `ITEM_CHANGE 1040` 子命令 **27** + int position（`BadgeComposePane:237`→`Client.as:2379-2384`→`ItemChangeProcessor.as:297-303`）；页0「开始合成」⇒ **1040:26**（`StoneComposePane:243`→`Client.as:9810-9815`→`:241-247`）；石页放入合格石头还旁路发 `HUODONG_ACTION 1809` 子命令 0（`:104`）。回帧 `HUI_ZHANG_STONE_MERGE_RES = 2317`（4×int：succCnt/succStoneId/leftCnt/leftStoneId）只喂页0 那两枚格，页1 **无专属回帧**、靠背包 `UPDATE_INVENTORY` 刷新。⇒ **本机 2.2.3 服务端全程都在处理**（`:1581-1582` 枚举、`:53859-53864` 派发、`:54240-54287` 三合一合成、`:54288-54335` 升阶且**只耗材料不扣金币**），本工程未点头 ⇒ 两颗钮只回显。"),
    "CARD_COLLECTION": ("guwan/GuwanshoujiWindow", "534×384", "卡片套册",
                        "已建(2026-10-04 夜：SPEC 生成场景 + 卡片套册窗.gd 现填树与右列；"
                        "提交/领取两枚钮的 COMMITITEM/GAIN 未接，只回状态行)"),
    "TOTSUKA_EXCHANGE": ("lingQi/DuiHuanWindow", "420×250", "十拳剑兑换", "已有(10-04)"),
    "RENJU_EXCHANGE": ("renJu/RenJuDuiHuanWindow", "420×250", "忍具兑换", "已有(10-04)"),
    "ARTIFACT_WAR": ("（原版**不开任何窗**）", "—", "",
        "查到底(2026-10-06)：这一跳不是开窗，是**传送进场 + 头顶倒计时**。"
        "服务端 `:51883-51884` `elif action == ARTIFACT_WAR: self._enter_artifact_warfield()`"
        "（`:52141`）⇒ 全程**不发 `SHOW_NPC_PANEL`、不发任何开窗 opcode**，只发聊天文本或 "
        "`OPEN_PVP_ACTION:8`（`:52179`）/ `_enter_scheduled_warfield(warfield,神器战场)`"
        "（`:52163` → `:52055` → `_warp_to_map`）。19 这个值在服务端全文只出现 5 处"
        "（`:62`/`:63` 开赛日常量、`:1133` 枚举、`:10940` 菜单、`:51883` 分支）⇒ 没有第二处。"
        "客户端**根本没有 `NpcMenuAction`**（全树 grep 命中 0）⇒ 按构造不可能有「19→某窗」映射；"
        "回帧开窗的开关是 `Client.as:5894-5953` 的 panelId switch，全集 "
        "{1,2,3,4,5,6,7,8,9,10,11,50,51,60,61,100,101,102} 没有一枚对应。"
        "三个候选各自被独立入口证据排除：`pvp/PvpWindow` 只由 `SmallMapButtonBox.as:467`"
        "（小地图「进入竞技场」）与 `ActivityTaskPaneCell.as:98` 开；"
        "`muyedazhan/ZhanChangWindow` 只由 `MuYeDaZhanManager.as:615/652/720` 开（木叶大战浮标）；"
        "`ShowShenQiPvpTime` `extends MWindow` 但 `super()` **无定尺**、"
        "`mouseEnabled = mouseChildren = false`、倒计时归零自关 ⇒ 是战场图内 HUD"
        "（`UIMain2.as:3094` ← `OPEN_PVP_ACTION` cmd 9）。"
        "原版数据自证：`Huodong.json`「草薙剑争夺战」desc = "
        "**在3线木叶村-佐助处传送可进入战场**、`reqLevel 45`、`days = 3,6`。"
        "⇒ **没有页面可移植**（本工程范围＝UI＋按钮交互），点它只回显这一条结论"),
    "ARTIFACT_INFO": ("?", "?", "", "查无独立类(lingQi/ 只有 洗练/开光/灵化 三扇 520×345)"),
    "ESCORT": ("husong/HuSongQuestWindow", "578×342", "护送任务",
        "已建(2026-10-05：入口**不是菜单动作**、是 selection 段的护送行 ⇒ 挂在 志乃(23) 的 `任务行` 上。"
        "原版 `QuestDialog.as:304-305` 在 status==0 时把链接 value 强改成 -1，"
        "`:107-110` 就地 `HuSongQuestManager.showHuSongQuestWindow(loopid,total)` **不发帧**；"
        "status 1/2 才走 `requestNPCMoreTalkEx(SELECTION,8100)`(服务端 :56417 回 mixin 状态)。"
        "品质/剩余时间/奖励只在服务端 mixin 状态帧里 ⇒ 本地开出来是空态，本轮只建 UI)"),
    "QUEST_DAILY": ("component/RefreshDailyQuestWindow", "355×407", "日环任务",
        "已建(2026-10-05：入口是 328 帧的 **selection 段**、不是服务菜单 ⇒ 上一版「富岳没有菜单行」是错的；"
        "点行原版发 `57:3:8001` 等 `42:1` 回帧才开，本轮**只本地直开、不发协议**。"
        "运行期数字（第几环/星级/剩余秒/奖励物品）只在服务端 444 任务信息帧里 ⇒ 本地开出来是空态)"),
    "QUEST_WEEKLY": ("component/DailyQuestWindow", "355×367", "周试炼任务",
        "已建(2026-10-05：⚠ 类名叫 Daily 但走的是 weekly 那一支，分流在 `QuestDataManager.as:284-288`。"
        "降难度/提回报那两支原版是打开 EnlargeWindow 收 QuestLoop 材料(`QuestDataManager.as:169-177`)⇒ 未接)"),
    "TELEPORT": ("?", "?", "", "协议(传送走 map_change,不造菜单)"),
}


# ── selection 链接块的显示文案（**Python 侧独立实现一份**，与 GDScript 那份互为对照）────────────
# 出处 `QuestDialog.as:256-306`：前缀按 quest 类型、五类拼 `(loopId/loopCount)`、末尾拼状态后缀。
# 语言键逐字：主线 :937 / 支线 :1068 / 日环 :1705 / 周环 :255 / 月环 :1006 / 挂机 :2160 /
#            护送 :1676 / 家族 :531 / 可接 :1658 / 进行中 :2676 / 可交 :602 / 对话 :2856。
选择前缀 = {"trunk": "[主线]", "branch": "[支线]", "daily": "[日环]", "weekly": "[周环]",
            "monthly": "[月环]", "loop": "[挂机]", "mixin": "[护送]", "banghui": "[家族]"}
选择带计数 = {"daily", "weekly", "loop", "mixin", "banghui"}
选择后缀 = {0: "（可接）", 1: "（进行中）", 2: "（可交）", 4: "（对话）"}


def NPC对话窗选择文案(条: dict) -> str:
    类 = str(条.get("类型", ""))
    文 = 选择前缀.get(类, "") + str(条.get("文字", ""))
    if 类 in 选择带计数:
        文 = "%s(%s/%s)" % (文, 条.get("次数", 0), 条.get("上限", 0))
    # ⚠ 读的是 `任务状态`（0=可接 1=进行中 2=可交 4=对话），**不是**表里那列移植说明 `状态`
    return 文 + 选择后缀.get(int(条.get("任务状态", 0)), "")


def 菜单(模板: int, service: str) -> list:
    """按服务端 `_send_current_npc_dialog` 那一段的**顺序**组装，末尾固定「离开」。
    行号别写死（见 `组装出处()`：换一份服务端整段平移）。顺序错了 = 行号错位。"""
    行 = [(标, 动作[码]) for 标, 码 in 服务菜单.get(模板, ())]
    if 模板 in 仓库模板 and not any(码 == "STORAGE" for _, 码 in 服务菜单.get(模板, ())):
        行.append(("打开仓库", 动作["STORAGE"]))
    if 模板 in 商人模板 or service == "物品交易":
        行.append(("物品交易", 动作["SHOP"]))
    if 模板 in 卡片模板:
        行.append(("卡片套册收集", 动作["CARD_COLLECTION"]))
    行.append(("离开", 动作["LEAVE"]))
    return [{"文字": 标, "动作": 码} for 标, 码 in 行]


def 组装出处(文: str) -> str:
    """**从服务端文件里算出**那段组装的行号（不是手抄的常数）。

    为什么必须算：换一份服务端（2.2.3优化版 / nya-go / V2.6分发版 是三份不同的文件）
    同一段代码的行号就整体平移（实测 :51697-51712 / :52313-52329 / :53144-53160），
    手写的数字一定会漂。而 `测试/木叶村NPC回归测试.gd` 以前把 `52313` 钉死 ⇒
    换源换版时门会红在"出处"上而不是红在"菜单内容"上 —— 那是门自己在报错位置。
    """
    行们 = 文.splitlines()
    定义 = next((i for i, l in enumerate(行们)
                 if re.match(r"^\s*def _send_current_npc_dialog", l)), None)
    if 定义 is None:
        raise SystemExit("服务端里没有 _send_current_npc_dialog ⇒ 这份不是同一版服务端")
    起 = next((i for i in range(定义, len(行们)) if "menu_entries = [" in 行们[i]), None)
    if 起 is None:
        raise SystemExit("找不到 menu_entries = [ 那行 ⇒ 组装段的开头形状变了，先重核")
    止 = next((i for i in range(起, len(行们))
               if "menu_entries.append" in 行们[i] and "LEAVE" in 行们[i]), None)
    if 止 is None:
        raise SystemExit("找不到「离开」那行 append ⇒ 组装段的末尾形状变了，先重核")
    return "%s:%d-%d" % (os.path.basename(服务端), 起 + 1, 止 + 1)


def 主():
    文 = io.open(服务端, encoding="utf-8").read()		# 存在性检查：菜单表是抄这份的，文件不在就别导
    if "分发版" in 服务端 or "Nya-wdnmd" in 服务端:
        raise SystemExit("服务端不能用分发版 ⇒ 用户明令「按 2.2.3优化版、不要按分发版」，"
                         "数据源必须是 2.2.3 自带的 tools/fake_flash_server.py（当前：%s）" % 服务端)
    出处 = 组装出处(文)
    NPC = json.load(io.open(os.path.join(项目, "数据", "NPC.json"), encoding="utf-8"))
    摆点 = json.load(io.open(os.path.join(项目, "数据", "原版杂项.json"), encoding="utf-8"))["NpcLocation"]

    出 = []
    for 编号, 图 in sorted(摆点.items()):
        图id = list(图.values())[0] if isinstance(图, dict) and 图 else 图
        if int(图id) != 木叶村:
            continue
        n = NPC.get(编号)
        if n is None:
            raise SystemExit("NpcLocation 里有 %s，但 数据/NPC.json 没有这条 ⇒ 数据漂移" % 编号)
        模板 = int(编号)
        行 = 菜单(模板, str(n.get("service", "")))
        目标 = []
        for r in 行:
            码 = next(k for k, v in 动作.items() if v == r["动作"])
            原, 尺, 页, 态 = 落地.get(码, ("?", "?", "", "未登记"))
            目标.append(dict(r, 键=码, 原版类=原, 尺寸=尺, 落地页=页, 状态=态))
        出.append({
            "id": 编号, "模板": 模板, "名": n["name"], "称号": n.get("title", ""),
            "台词": n.get("dialogue", ""), "service": n.get("service", ""),
            "有服务菜单": 模板 in 服务菜单, "菜单": 目标,
            # selection 段单独一个键 ⇒ 现有的「菜单序列 == 钉死表」自检与「离开恒在最后」都不受影响
            # 逐键原样带出去，只补一列「移植状态」（键名 `状态` 与上面的菜单行同一含义）
            "任务行": [dict(r, 状态=落地.get(r["键"], ("?", "?", "", "未登记"))[3])
                       for r in 环任务行.get(模板, ())],
        })

    # ── 自检：钉死的都是**已在实机/真值文档里见过**的，换服务端版本就会红 ─────────
    def 找(编号):
        return next(x for x in 出 if x["id"] == 编号)
    要 = [("00000018", ["挑战副本", "挑战精英副本", "离开"]),
          ("00000013", ["打开仓库", "离开"]),
          ("00000014", ["物品交易", "离开"]),
          ("00000029", ["卡片套册收集", "离开"]),
          ("00000011", ["变身卡与道具兑换", "变身卡属性交换", "变身卡特殊属性交换", "离开"]),
          ("00000016", ["离开"]),
          ("00000059", ["灵器介绍", "兑换十拳剑", "兑换忍具", "离开"])]
    for 编号, 期望 in 要:
        实 = [r["文字"] for r in 找(编号)["菜单"]]
        if 实 != 期望:
            raise SystemExit("菜单对不上 %s：%s ≠ %s（服务端 NPC_SERVICE_MENUS 换版了？先重核行号）"
                             % (编号, 实, 期望))
    # 台词逐字回**服务端那条优先级**（`fake_flash_server.py:9026` `d0 or n0 or 兜底`）。
    # 2026-10-05 用户实机图打回时抓到：`数据/NPC.json` 当年按 **n0** 存 ⇒ 76 枚里 62 枚台词是错的
    # （富岳该显示 d0「警所事务繁忙，要来帮忙吗？」，表里是 n0「“团扇”是代表宇智波家荣誉的家徽！」）。
    # ⇒ 重算工具 `开发工具/出NPC台词.py`；这一条自检保证**改了 NPC.json 忘了重导表**会红在这里。
    句 = json.load(io.open(os.path.join(os.path.dirname(项目), "真值文档", "GameData",
                                        "String.json"), encoding="utf-8"))["items"]["Npc"]
    歪句 = []
    for 条 in 出:
        s = 句.get(条["id"], {})
        真 = str(s.get("d0") or s.get("n0") or "")
        if 真 and 条["台词"] != 真:
            歪句.append((条["id"], 条["台词"][:18], 真[:18]))
    if 歪句:
        raise SystemExit("台词与服务端优先级(d0→n0)不一致 %d 枚：%s ⇒ 跑 python 开发工具/出NPC台词.py 再重导"
                         % (len(歪句), 歪句[:3]))
    # 环任务行是**硬编码在 if 里**的，换一份服务端就可能没有 ⇒ 直接钉服务端源码里的三处字面
    for 特征 in ["npc.template_id == 27", 'f"每日环任务&8001&"', 'f"周试炼任务&8002&"']:
        if 特征 not in 文:
            raise SystemExit("服务端里找不到环任务行的特征 %s ⇒ 这一版富岳可能不给这两行，先重核"
                             % 特征)
    富 = 找("00000027")
    # selection 链接块的**整条显示文案**钉死（用户 2026-10-05 给的实机截图就是这两行）
    富句 = [NPC对话窗选择文案(r) for r in 富["任务行"]]
    if 富句 != ["[日环]每日环任务(1/20)（可接）", "[周环]周试炼任务(1/100)（可接）"]:
        raise SystemExit("富岳 selection 文案对不上：%s（前缀 / (次数/上限) / 状态后缀 逐字，"
                         "出处 QuestDialog.as:256-306 + 实机截图）" % 富句)
    if [r["文字"] for r in 富["任务行"]] != ["每日环任务", "周试炼任务"]:
        raise SystemExit("富岳的环任务行变了：%s" % [r["文字"] for r in 富["任务行"]])
    if any(int(r["任务id"]) not in (8001, 8002) for r in 富["任务行"]):
        raise SystemExit("任务id 不再是 8001/8002 ⇒ 去核 _npc_quest_selections")
    # 志乃的护送行同一套路：钉服务端字面 + 钉整条显示文案。
    # 起始 NPC **不写死 23**：服务端是 `get_quest_definition(8100).start_npc_id or 23`
    # （`_escort_start_npc_id():34640`），所以这里从 `数据/任务.json` 现查 8100 的 `npc.0`
    # 再回头要求「表里有这么一枚、而且它带护送行」—— 换数据版会红在真处。
    for 特征 in ['f"护送任务&8100&', "escort_start_npc_id"]:
        if 特征 not in 文:
            raise SystemExit("服务端里找不到护送行的特征 %s ⇒ 这一版志乃可能不给护送行，先重核"
                             % 特征)
    任 = json.load(io.open(os.path.join(项目, "数据", "任务.json"), encoding="utf-8"))
    护送 = 任.get("8100")
    if 护送 is None:
        raise SystemExit("数据/任务.json 里没有 8100 ⇒ 护送行的 questId 无源，先重核数据源")
    起NPC = "%08d" % int(护送["npc"]["0"])		# 表里的 id 是八位补零串，任务表里是整数
    if str(护送["info"]["type"]) != "mixin" or int(护送["info"]["loopCount"]) != 3:
        raise SystemExit("8100 的类型/环数变了（type=%s loopCount=%s）⇒ 前缀 `[护送]` 与 (x/3) 都要重算"
                         % (护送["info"]["type"], 护送["info"]["loopCount"]))
    志 = next((x for x in 出 if x["id"] == 起NPC), None)
    if 志 is None:
        raise SystemExit("护送起始 NPC %s 不在木叶村 25 枚里 ⇒ 表要按它所在地图另导，先重核" % 起NPC)
    if [r["文字"] for r in 志["任务行"]] != ["护送任务"]:
        raise SystemExit("护送起始 NPC %s 的任务行不是「护送任务」这一行：%s ⇒ 去核 _npc_quest_selections"
                         % (起NPC, [r["文字"] for r in 志["任务行"]]))
    if NPC对话窗选择文案(志["任务行"][0]) != "[护送]护送任务(1/3)（可接）":
        raise SystemExit("志乃护送行文案对不上：%s（QuestDialog.as:296-306 + 服务端 :51466）"
                         % NPC对话窗选择文案(志["任务行"][0]))
    if [r["文字"] for r in 志["菜单"]] != ["离开"]:
        raise SystemExit("志乃的服务菜单不再是「只有离开」：%s ⇒ 护送入口若变成菜单行要重核 NPC_SERVICE_MENUS"
                         % [r["文字"] for r in 志["菜单"]])
    if len(出) != 25:
        raise SystemExit("木叶村 NPC 数 = %d，与 2026-10-03 实查的 25 不符 ⇒ 换版本或换数据源了" % len(出))
    if sum(1 for x in 出 if x["有服务菜单"]) != 13:
        raise SystemExit("有服务菜单的枚数变了（钉 13 枚：11/12/13/17/18/19/20/21/22/28/29/30/32/59 里去掉 13 是补行 ⇒ 实算）")

    json.dump({"地图": 木叶村, "地图名": "木叶村",
               "组装规则": "%s（服务菜单→仓库→物品交易→卡片→离开）" % 出处,
               "npc": 出},
              io.open(落, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    总行 = sum(len(x["菜单"]) for x in 出)
    print("木叶村 %d 枚 NPC、%d 行菜单 → %s" % (len(出), 总行, 落))
    for x in 出:
        print("  %s %-6s %-8s %s" % (x["id"], x["名"], x["称号"],
                                     " / ".join(r["文字"] for r in x["菜单"])))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    主()
