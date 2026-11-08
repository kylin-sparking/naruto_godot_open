extends RefCounted
## 八门页的两段文案 —— **全部取自 Flash 原版**，不要改写。
##
## 出处（可复查）
## ------------
## 1. 门说明 = 原版 `JingMaiPanel.as` 里：
##      `_maiDescTextArea.htmlText = "<font color='#ffffff'>" + 门.name + "：<br/>" + 门.desc + "</font>"`
##    其中 `desc` 来自客户端数据 `GameData.dat` → 顶层段 `Mai` → `<脉>/mai/<序号>/desc`
##    （`JingMaiSource.getMaiSource()` 就是 `ImgUtil.getImg(ImgType.Mai, listId)` 再取 `mai.<n>`）。
##    读法：`开发工具/原版数据.py` 的 `取顶层段("Mai")` + `解载荷()`。
## 2. 修炼提示 = 原版语言键 `JINGMAI_PANE1_SAY`：
##      "%1内所有穴道开通后，将获得额外属性提升：%2"（白）
##      "<br/>" + "按一下穴道名称对应点开通穴道，每个穴道开通都可获得对应属性提升"（橙 #ff9100）
##    %1 = 门名，%2 = `JingMaiSource.getPropString(attr, value)` = 属性名 + "+" + 数值。
## 3. 属性名对照见 `JingMaiSource.getPropString()`：
##      maxhp→生命(CN.JINGMAI_SOURCE_HP)  maxmp→查克拉  def→防御  atk→攻击  avd→闪避  bsk→暴击
##
## 门级数值从表里现取
## ----------------
## `Mai/<脉>/mai/<序号>/value`（表八门：154/128/38/38/38/38/51/13，里/魂/印/仙各不同）
## 已经随客户端数据落在 `数据/经脉.json`（`<阶>/mai/<序号>/value`）⇒ **按门名查表**，
## 不再需要一张手抄的「门序号」表；换脉（阶）时把 `阶` 传进来即可。

const 游戏数据表 := preload("res://脚本/单例/游戏数据.gd")

## 门名 → {desc = 原版 desc 原文, attr = 原版 attr 字段}
const 说明 := {
	"开门": {"desc": "开门居西北干宫，五行属金，干宫门为开门，喻万物开始之意", "attr": "maxhp"},
	"休门": {"desc": "休门居北方坎宫，五行属水，坎宫门为休门，乃修养生息之地", "attr": "maxhp"},
	"生门": {"desc": "生门居北方艮宫，五行属土，艮宫门为生门，为万物复苏之始", "attr": "def"},
	"伤门": {"desc": "伤门居东方震宫，五行属木，震宫门为伤门，属凶门动则易伤", "attr": "atk"},
	"杜门": {"desc": "杜门居东南巽宫，五行属木，巽宫门为杜门，已藏形避难之方", "attr": "avd"},
	"景门": {"desc": "景门居南方离宫，五行属火，离宫门为景门，当日升中天之时", "attr": "atk"},
	"惊门": {"desc": "惊门居西方兑宫，五行属金，兑宫门为惊门，行寒气肃杀之应", "attr": "maxmp"},
	"死门": {"desc": "死门居中西南坤宫，五行属土，坤宫门为死门，主刑戮征战之宜", "attr": "bsk"},
}

## 原版 getPropString() 的 attr → 属性名
const 属性名 := {
	"maxhp": "生命",
	"maxmp": "查克拉",
	"def": "防御",
	"atk": "攻击",
	"avd": "闪避",
	"bsk": "暴击",
}

const 修炼提示后缀 := "按一下穴道名称对应点开通穴道，每个穴道开通都可获得对应属性提升"


## 「生命+154」里的 154。原版是 `Mai/<脉>/mai/<序号>/value`，随脉变（表/里/魂/印/仙）。
static func 数值(门名: String, 阶: int = 0) -> String:
	var 条 := 门条(门名, 阶)
	if not 条.has("value"):
		return ""
	return str(int(条.get("value", 0)))


## 某阶某门的配置行（`mai/<序号>`，含 name/desc/attr/value）。
## 按**门名**找，调用方不用再抄一份门序号表。
static func 门条(门名: String, 阶: int = 0) -> Dictionary:
	var 阶条: Dictionary = 游戏数据表.取表("经脉").get(str(阶), {}) as Dictionary
	for 键 in (阶条.get("mai", {}) as Dictionary):
		var 条: Dictionary = 阶条["mai"][键] as Dictionary
		if String(条.get("name", "")) == 门名:
			return 条
	return {}


static func 属性(门名: String) -> String:
	var 条: Dictionary = 说明.get(门名, {})
	return String(属性名.get(String(条.get("attr", "")), String(条.get("attr", ""))))


## 门说明面板的正文：原版 = 门名 + "：" + 换行 + desc
static func 门说明(门名: String) -> String:
	var 条: Dictionary = 说明.get(门名, {})
	return "%s：\n%s" % [门名, String(条.get("desc", ""))]


## 修炼提示面板的正文 —— **bbcode**（这个节点是 RichTextLabel）。
## 原版 JINGMAI_PANE1_SAY：第一行白 #ffffff，第二行橙 #ff9100。
static func 修炼提示(门名: String, 阶: int = 0) -> String:
	return "[color=#ffffff]%s内所有穴道开通后，将获得额外属性提升：%s[/color]\n[color=#ff9100]%s[/color]" % [
		门名, 加成(门名, 阶), 修炼提示后缀,
	]


## **门级**加成串，例如「生命+154」（`updateMai:314` 只把它写进「修炼提示」那一行）。
## ⚠️ 右下角「提升属性」那一格是**穴位级**的，走 `穴位加成()`，别用这个。
static func 加成(门名: String, 阶: int = 0) -> String:
	return "%s+%s" % [属性(门名), 数值(门名, 阶)]

# ── 「开通穴道」弹窗那几条（原版 `ChongMaiWindow`）───────────────────────────────
# 出处（可复查）：原版语言表键 `CHONG_MAI_PROMPT_1/2/3`、
# `CHONG_MAI_WINDOW_BENCI_XIAOHAO_1`（三处原文见下，**不要改写**）。
# ⚠️ 运行期不能 import 2.2.3 ⇒ 与 `说明` 一样，**把原文烘在这里**。
const 开通提示 := [
	"温馨提示：在你开通穴道操作成功时，处于你附近的玩家将获得大量的经验奖励",	# CHONG_MAI_PROMPT_1
	"开启里•八门时带来的经验是普通八门的1.5倍",	# CHONG_MAI_PROMPT_2（listId == 1）
	"开启魂•八门时带来的经验是普通八门的2倍",	# CHONG_MAI_PROMPT_3（其余阶）
]
## `CHONG_MAI_WINDOW_BENCI_XIAOHAO_1` 的 bbcode 形态（原版是 `<font color='A'>B</font>`）。
## A = 消耗那一串的颜色（够绿 #00ff00 / 不够红 #ff0000）、B = 消耗的精华、C = 成功率%。
## ⚠️ 原版同一行还有一处 `<font color='#ffffff'>` 外层 —— RichTextLabel 的 bbcode 直接给默认色即可。
const 消耗与几率模板 := "本次操作消耗精华：[color=A]B[/color]
本次操作成功几率：C%"


## **按穴位**的属性+数值 —— 「开通穴道」弹窗那一格。
## 原版 `ChongMaiWindow.showWindow:109` `_gainItem.contentText = getPropString(strengthProp, strengthValue)`，
## 数据是**穴位级**的（`Mai/<阶>/mai/<门>/pts/<穴>/attr|value`）。
## ⚠️ 别与 `加成(门名)` 混用：那个是**门**级的（`mai/<门>/value`），两者数值不同。
static func 穴位加成(属性: String, 值: int) -> String:
	return "%s+%d" % [String(属性名.get(属性, 属性)), 值]


# ── 「突破瓶颈」弹窗（原版 `ThroughAllMaiWindow.as:74-113/160-193`）─────────────
# ⚠️ 下面每一条**数组下标 = 当前脉**（0 表八门→开里•八门、1 里→开魂、2 魂→开印、3 印→开仙），
#   照的是原版那串 `if(listId==0)/else if(1)/else if(2)/else`；满脉（4）原版根本不开这个窗
#   （入口钮按 `JingMaiPanel.as:266` 的判据直接隐藏）。
# ⚠️ 原文的间隔号是 U+2022「•」（与 `数据/*.json` 同源）；场景里烘的是 U+00B7「·」，
#   运行期整条覆盖 —— 承第二十二条「设计师烘的示例值会骗人」。

const 突破标题 := [
	"开启里•八门",	# THROUGHALLMAI_WINDOW_TITLE
	"开启魂•八门",	# THROUGHALLMAI_WINDOW_TITLE_2
	"开启印•八门",	# THROUGHALLMAI_WINDOW_TITLE_3
	"开启仙•八门",	# THROUGHALLMAI_WINDOW_TITLE_4
]
const 突破脉名 := ["里•八门", "魂•八门", "印•八门", "仙•八门"]	# ..._LI/HUN/YIN/XIAN_BAMEN

## 块3 那行橙字（`THROUGHALLMAI_WINDOW_LABEL_3` 一族）。
const 突破开通说明 := [
	"开通里•八门内穴道与每一门内穴道完整开通你将获得属性加成：",
	"开通魂•八门内穴道与每一门内穴道完整开通你将获得属性加成：",
	"开通印•八门内穴道与每一门内穴道完整开通你将获得属性加成：",
	"开通仙•八门内穴道与每一门内穴道完整开通你将获得属性加成：",
]

## 块3 那段绿字（`THROUGHALLMAI_WINDOW_MIDDLE` / `_2` / `_3` / `_4`，剥掉 `<font>`/`<br/>`）。
const 突破打通奖励 := [
	"全部里•八门内穴道打通后，所有忍术的当前层数+1层\n如：忍术内某一项为80层，获得里•八门加成后为81层\n该忍术提升至81层时，里•八门加成后为82层",
	"全部魂•八门内穴道打通后，所有忍术的当前层数+3层\n如：忍术内某一项为80层，获得魂•八门加成后为83层\n该忍术提升至81层时，魂•八门加成后为84层",
	"全部印•八门内穴道打通后，所有忍术的当前层数+5层\n如：忍术内某一项为80层，获得印•八门加成后为85层\n该忍术提升至81层时，印•八门加成后为86层",
	"全部仙•八门内穴道打通后，所有忍术的当前层数+6层\n如：忍术内某一项为80层，获得仙•八门加成后为86层\n该忍术提升至81层时，仙•八门加成后为87层",
]

## `THROUGHALLMAI_WINDOW_SAY` 的前两行（第三行"八门神符可通过…"是场景里那个 `获取方式` 标签，
## 本来就烘好了）：%1/%4 = 要开的脉名、%2 = 神符张数、%3 = 查克拉精华、%5 = 几率。
const 突破消耗模板 := "开启%s需要消耗八门神符%s张，查克拉精华%s\n开启%s成功几率：%s"

## 块1 那行橙字 `JINGMAI_SOURCE_SAY_1`（场景里已经烘了同一句，留着给填弹窗当依据）。
const 已提升说明 := "当前开通的穴道与开启的八门已为你提升属性："

## 属性两行的排版 = 原版 `JingMaiSource.getCurrentMaiProps:557-565` /
## `getTroughMaiString:356-391` 那同一串 `CN.CHARACTOR_ATK + "：" + …` 剥掉 `<font>`/`<br/>`。
## 块1 拆成两个 Label（属性栏1/属性栏2）、块3 是一个两行 Label（属性栏）⇒ 都由这两行拼。
const 属性行一 := "攻击：%d 防御：%d  暴击：%d  闪避：%d"
const 属性行二 := "生命上限：%d  查克拉上限：%d"

## 原版 `JingMaiSource.MAX_MAI`（脉的上限；`listId >= 它` 就没有下一脉可开）。
const 最大脉 := 4


## 属性字典（`maxhp/maxmp/atk/def/bsk/avd`）→ 那两行文字。缺键按 0 算。
static func 属性两行(属性表: Dictionary) -> Array:
	return [
		属性行一 % [int(属性表.get("atk", 0)), int(属性表.get("def", 0)),
			int(属性表.get("bsk", 0)), int(属性表.get("avd", 0))],
		属性行二 % [int(属性表.get("maxhp", 0)), int(属性表.get("maxmp", 0))],
	]

# ── 总览页（原版 `JingMaiSource.getZongLanString:299-315`，语言表 `JINGMAI_SOURCE_SAY_2..6`）──
# ⚠️ 原文里那处「精华 ，  消耗」的空格是语言表自带的（一个半角空格 + 一个全角逗号 + 两个半角空格），
#   照抄不"顺手纠正"—— 承 §0 第 1 条，原文是唯一真值。
const 总览说明一 := "在查克拉流动的经络系统中存在著抑制及控制体内查克拉的八门，通过打坐及修行可以获得查克拉精华 ，  消耗一定量的查克拉精华可以点击相应穴道进行开通操作，点击开通穴道面板内按钮“开通穴道”，将增加人物能力。"	# SAY_2（绿 #00ff00）
const 总览说明二 := "操作成功后即可获得该穴道的对应提升的属性奖励"	# SAY_3（橙 #ff9100）
## SAY_4 原版一条 htmlText 里带一个 `<br/>`，场景把它拆成 `块3/说明1` 两行 ⇒ 这里也存两行。
const 总览散开 := [
	"成功开通穴道的同时，查克拉精华会向四周散开",
	"此时处于周围范围内的人物将同时获得经验奖励",
]	# SAY_4（#CF944E）
const 总览分享模板 := "每日可进行24次经验分享，当前累计剩余%d次"	# SAY_5（黄 #fff000）
const 总览经验模板 := "累计已获得开通穴道的分享经验值：%d"	# SAY_6（黄 #fff000）

## `JingMaiSource.getBaMenImage(listId)`：0=表 1=里 2=魂 3/4=印（原版 `case 4` 与 `case 3` 同图）。
const 八卦图 := [
	"res://素材/界面/原版窗口/人物/八门/八门/人体图/表八门.png",
	"res://素材/界面/原版窗口/人物/八门/八门/人体图/里八门.png",
	"res://素材/界面/原版窗口/人物/八门/八门/人体图/魂八门.png",
	"res://素材/界面/原版窗口/人物/八门/八门/人体图/印八门.png",
]


static func 八卦图路径(脉: int) -> String:
	if 脉 < 0 or 脉 >= 最大脉:
		return String(八卦图[0])
	if 脉 >= 3:
		return String(八卦图[3])
	return String(八卦图[脉])
