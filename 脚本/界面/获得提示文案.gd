extends RefCounted

## 原版右下角那列「获得提示」的**文案生成**（纯函数，差值由 `后端连接` 算好后传进来）。
##
## 两条出处，一条都不许凭印象改：
## * 模板 = 语言包 `as3_MainLib/scripts/en_US$message_properties.as`（Flex `en_US$message` 资源束，
##   `LangUtil.get()` 走的就是它），原样是 htmlText 的 `<font color=…>`，这里逐条翻成 BBCode。
## * 该不该提示、符号怎么带 = `DataCenter.updateOneStatu`（`DataCenter.as:2399-2792`）里
##   每个 `case CocoStatType.*` 的判断；字段号 = `CocoStatType.as:12-70`。
##
## 差值口径（原版逐条抄）：
##   经验 25        **只在变多时**提示，且恒带 `+`（`:2432-2441`）
##   其余属性       差 != 0 就提示，正数补 `+`、负数自带 `-`
##   攻速 20/移速 21  `(d > 0 ? "+" : "") + d` —— 与上一条同形（0 到不了这里）
##   HP 6 / MP 7 / 攻 16 / 防 17 / 暴 18 / 闪 19
##                  **不进这一列**：原版只给角色头顶飘字（`player_addAttriChangeTip`），
##                  列表里一个像素都没有（`:2447-2469`、`:2485-2494`、`:2707-2754`）
##   等级 4 / 职业 5  也不进这一列（升级放 `Effect_levelUp`，`PROM_LEVE_UP` 在这版客户端**没有任何调用点**）

## 语言包里的两档色（`:1326` 等行的 `#00cc33` / `#f0dd06`）
const 主色 := "#00cc33"
const 高亮 := "#f0dd06"

const 绿 := "[color=" + 主色 + "]"
const 黄 := "[color=" + 高亮 + "]"
const 收 := "[/color]"

## 属性字段号 → 模板。模板里 `%1` = 带符号的差值（照 `CN.replaceString` 的占位符）。
const 属性表 := {
	# PROM_MAXHP_GET（语言包 :3253）/ DataCenter :2470-2483
	13: "[color=#00cc33]生命值上限 [color=#f0dd06]%1[/color][/color]",
	# PROM_MAXMP_GET（:2435）/ :2495-2508
	14: "[color=#00cc33]查克拉上限 [color=#f0dd06]%1[/color][/color]",
	# PROM_ATKS（:718）/ :2755-2768
	20: "[color=#00cc33]攻击速度 [color=#f0dd06]%1[/color][/color]",
	# PROM_WLKS（:2619）/ :2770-2781
	21: "[color=#00cc33]移动速度 [color=#f0dd06]%1[/color][/color]",
	# PROM_ZQ_GET（:445）/ :2690-2705
	22: "[color=#00cc33]精华 [color=#f0dd06]%1[/color][/color]",
	# PROM_EXT（:2438）/ :2432-2446 —— **只有变多才提示**
	25: "[color=#00cc33]经验 [color=#f0dd06]%1[/color][/color]",
	# PROM_MONEY_GET（:3331）/ :2588-2612
	27: "[color=#00cc33]金币 [color=#f0dd06]%1[/color][/color]",
	# PROM_BIND_MONEY_GET（:2016）/ :2613-2624
	28: "[color=#00cc33]绑定金币 [color=#f0dd06]%1[/color][/color]",
	# PROM_BAND_MONEY_GET（:1613）= 点券 / :2625-2644
	30: "[color=#00cc33]点券 [color=#f0dd06]%1[/color][/color]",
	# PROM_CRIMBE_GET（:1637）/ :2417-2431
	33: "[color=#00cc33]罪恶值 [color=#f0dd06]%1[/color][/color]",
}

## 恒正档：这一族原版写死 `"+" + 差值`，负数根本进不来（只有 `差 > 0` 才走到 addNotice）。
const 恒正字段 := [25]

## 原版只飘字、不进这一列的字段（留给门当反向对照：它们必须返回空串）。
const 只飘字字段 := [6, 7, 16, 17, 18, 19]


## 这个字段号在原版那一列里**到底出不出**（HP/MP/攻/防/暴/闪/等级都不出）。
## 单独给一句，是为了让调用方**先挑出要记基准值的字段**，而不是拿"差值算出来是空"当判据。
static func 会提示(字段号: int) -> bool:
	return 属性表.has(字段号)


## 差值 → 带符号文本。正数补 `+`，负数自带 `-`（`str(-5)` = "-5"）。
static func 带符号(差值: int, 恒正: bool = false) -> String:
	if 恒正:
		return "+" + str(差值)
	return ("+" + str(差值)) if 差值 > 0 else str(差值)


## 属性差值 → 一行 BBCode；返回空串 = **不提示**（字段不在这列、或该档被原版判掉了）。
static func 属性(字段号: int, 差值: int) -> String:
	if not 属性表.has(字段号):
		return ""
	var 恒正: bool = 恒正字段.has(字段号)
	if 恒正:
		## `DataCenter.as:2434` 的 `if(_loc4_ > 0)` —— 经验变少（升级扣满值）不出提示
		if 差值 <= 0:
			return ""
	elif 差值 == 0:
		return ""
	return 填(String(属性表[字段号]), 带符号(差值, 恒正))


## 元宝（`Client.onCashMoneyInfo:9062-9070`）：PROM_YUANBAO_GET（语言包 :1310），差 != 0 就提示。
static func 元宝(差值: int) -> String:
	if 差值 == 0:
		return ""
	return 填("[color=#00cc33]元宝 [color=#f0dd06]%1[/color][/color]", 带符号(差值))


## 心法熟练度（`DataCenter.as:1588` 那句 `addNotice(CN.replaceString(CN.PROM_XINFA_GET, 名, 层))`）。
## 语言包 `PROM_XINFA_GET` 原样 = `<font color='#00cc33'>%1心法熟练度 <font color='#f0dd06'>+%2</font></font>`
## ⇒ 两条容易写反的地方：① `%1` 是技能名**直接拼在前面、中间没有空格**；
##   ② 正负号是模板里**写死的 `+`**（原版只在涨层那个 `if` 里调，掉层根本到不了这一行）。
static func 心法熟练度(名: String, 增量: int) -> String:
	if 增量 <= 0 or 名 == "":
		return ""
	return 填两项("[color=#00cc33]%1心法熟练度 [color=#f0dd06]+%2[/color][/color]", 名, str(增量))


## PROM_ITEM_GET（:1326）`获得了 N 个名称` —— **注意原版这里没有空格**。
static func 道具获得(数量: int, 名称: String) -> String:
	return 填两项("[color=#00cc33]获得了[color=#f0dd06]%1[/color]个[color=#f0dd06]%2[/color][/color]",
		str(数量), 名称)


## PROM_ITEM_LOST（:1551）`失去了 N 个名称`
static func 道具失去(数量: int, 名称: String) -> String:
	return 填两项("[color=#00cc33]失去了[color=#f0dd06]%1[/color]个[color=#f0dd06]%2[/color][/color]",
		str(数量), 名称)


## `CN.replaceString`（`CN.as:5392-5404`）：按顺序把 `%1 %2 …` 换成参数。
static func 填(模板: String, 值: String) -> String:
	return 模板.replace("%1", 值)


static func 填两项(模板: String, 值一: String, 值二: String) -> String:
	return 模板.replace("%1", 值一).replace("%2", 值二)
