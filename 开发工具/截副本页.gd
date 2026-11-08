extends "res://开发工具/量具基类.gd"

## 量「副本传送」窗（原版 `com/mxw/uifl/controls/copy/CopyWindow.as`，`super(570,283)` 在 `:69`）。
## 骨架与口径在 `开发工具/量具基类.gd`；这里只放这一页的表。
## 逐件出处见 `测试/截图/副本_对照/真值对照表.md` 与 `game-client/真值/窗口/副本.md`。
##
## ⚠ 三条本页特有的口径（写在这儿，生成器和离线门都读同一份）：
##   1. **标题是「副本传送」不是「挑战副本」** —— `窗口尺寸.json` 原来写的「挑战副本」是
##      NPC 菜单项 `COPY_JINRU` 那类的串，`COPY_WINDOW_TITLE` 才是窗标题（`CopyWindow.as:138`）。
##   2. **列头四枚 MLabel 的颜色 16565145 = `#FCB799` 不在语言表里**，是 `:139/142/145/148`
##      字面量 ⇒ 只能像下面 `文案色` 这样单独钉。
##   3. **行是数据驱动但必须烘进场景**（编辑器=运行期）：9 行 = `数据/副本.json` 的「副本」，
##      原版 `getAllFuBenObj` + `filterData` 之后正好 9 条；只有「次数」列是运行期填的。
##
## 用法（不能加 --headless）：
##   Godot --path . --script res://开发工具/截副本页.gd -- --出目录=res://测试/截图/副本

const 抬 := 29			# 「副本」在 窗口尺寸.json 里 `整框: true` ⇒ 场景 y = 窗口 y − 29
const 行高 := 20			# `CopyWindowCell.as:58/83/89` 三块底都写死 height=20
const 行宽 := 298			# `:57/82/88` width=298（`setSize()` 是空实现 ⇒ 不随列表宽变）
const 行列 := [0, 132, 177, 232]		# `:65/70/75/80` 四列 x
const 行宽列 := [124, 42, 60, 63]		# 同上行宽
const 星位 := 7			# 数据里最大 stars=6 ⇒ 烘 7 槽，运行期只翻 visible
const 星宽 := 14			# `StarLevelIconF`(693) / `StarHollowF`(782) 原生 14×13
const 星高 := 13
const 钮字色 := Color(0.988235, 0.956863, 0.611765, 1)		# #fcf49c `MButton3.as:69`

## 语言表原文（`数据/界面/副本_文案.json`，键名照抄原版）。
const 原文 := {
	"列头_名称": "副本名称",			# COPY_NAME			`:139`
	"列头_等级": "等级",			# PETWINDOW_LEVEL		`:142`
	"列头_组队": "组队",			# TROOP_TITLE			`:145`
	"列头_次数": "次数",			# COPYWINDOW_COUNT		`:148`
	"星级标题": "副本内奖励丰厚度：",		# COPY_MEED			`:157`
	"奖励标题": "通关奖励：",			# COPY_TONGGUAN_JIANGLI	`:186`
	"勾选": "只显示我可以参与的副本",		# COPY_MCHECK			`:222`
	"进入钮": "进入",				# COPY_JINRU			`:239`
	"密卷钮": "副本密卷进入",			# COPY_MIJUAN_JINRU		`:247`
	"排行钮": "查看副本竞速榜",			# COPY_PAIHANG			`:231`（原版 visible=false）
}

## 件名 → 文字必须落到的颜色（无 BBCode 的件只能这么校；色值都不在语言表里）。
const 文案色 := {
	"列头_名称": Color(0.988235, 0.717647, 0.6, 1),	# 16565145 #FCB799	`:139`
	"列头_等级": Color(0.988235, 0.717647, 0.6, 1),	# 同上		`:142`
	"列头_组队": Color(0.988235, 0.717647, 0.6, 1),	# 同上		`:145`
	"列头_次数": Color(0.988235, 0.717647, 0.6, 1),	# 同上		`:148`
	"星级标题": Color(1, 0.6, 0, 1),		# UI_ORANGE 16748800	`:157`
	"奖励标题": Color(1, 0.6, 0, 1),		# UI_ORANGE		`:186`
	"勾选": Color(1, 0.941176, 0, 1),		# UI_YELLOW 16773120	`:223`
	# 三枚钮的字色 = `MButton3.as:69` upTextColor #fcf49c。**这里必须写 Color 字面量**：
	# 生成器按 `"键": Color(...)` 正则抓本表，写标识符（钮字色）会静默漏抓。
	"进入钮": Color(0.988235, 0.956863, 0.611765, 1),
	"密卷钮": Color(0.988235, 0.956863, 0.611765, 1),
	"排行钮": Color(0.988235, 0.956863, 0.611765, 1),
}

## 行内四列的字色（`CopyWindowCell.as:63/68/73/78`）。
const 列色 := {
	"名": Color(0.117647, 0.564706, 1, 1),	# UI_BLUE 2003199 = #1E90FF
	"等级": Color(1, 1, 1, 1),		# UI_WHITE
	"组队": Color(1, 1, 1, 1),		# UI_WHITE
	"次数": Color(0, 1, 0, 1),		# UI_GREEN
}

const 件路径 := {
	"内容底": "内容底",
	"列表面板": "列表面板",
	"详情面板": "详情面板",
	"列头底": "列头底",
	"列头_名称": "列头_名称",
	"列头_等级": "列头_等级",
	"列头_组队": "列头_组队",
	"列头_次数": "列头_次数",
	"列分隔1": "列分隔1",
	"列分隔2": "列分隔2",
	"列分隔3": "列分隔3",
	"星级标题": "星级标题",
	"星级分隔": "星级分隔",
	"星容器": "星容器",
	"详情滚动": "详情滚动",
	"奖励标题": "详情滚动/详情内容/奖励标题",
	"奖励": "详情滚动/详情内容/奖励",
	"说明": "详情滚动/详情内容/说明",
	"勾选": "勾选",
	"排行钮": "排行钮",
	"进入钮": "进入钮",
	"密卷钮": "密卷钮",
	"列表": "列表",
	"行容器": "列表/行容器",
	"行1": "列表/行容器/行1",
	"行1/名": "列表/行容器/行1/名",
	"行1/选中底": "列表/行容器/行1/选中底",
	# ↓ 三枚是**本工程既有的 819 副本流程钮**（确认/取消/领取），原版 `CopyWindow` 没有 ⇒
	#   不参与原版对证，只钉「静止态必须全部隐藏」，位置取底栏 (190..305, 213) 那段空档。
	"确认钮": "确认钮",
	"取消钮": "取消钮",
	"领取钮": "领取钮",
}

const 页面件 := {0: ["内容底", "列表面板", "详情面板", "列头底", "列头_名称", "列头_等级",
	"列头_组队", "列头_次数", "列分隔1", "列分隔2", "列分隔3", "星级标题", "星级分隔",
	"星容器", "详情滚动", "奖励标题", "勾选", "进入钮", "密卷钮", "列表", "行容器"]}
const 页面文案 := {0: ["列头_名称", "列头_等级", "列头_组队", "列头_次数", "星级标题",
	"奖励标题", "勾选", "进入钮", "密卷钮"]}

## 页面局部矩形 = 窗口坐标 − (0, 29)。算式逐条见真值对照表。
const 件期望 := {
	"内容底": [6, 10, 558, 240],		# `:127` (6,39) 570−12 × 283−43
	"列表面板": [11, 14, 313, 204],		# `:130` (11,43) 313×204
	"详情面板": [325, 14, 235, 229],		# `:133` x=11+313+1，(43) 235×229
	"列头底": [13, 14, 305, 24],		# `:136` (13,43) 305×24
	"列头_名称": [12, 16, 124, 18],		# `:141`
	"列头_等级": [147, 16, 36, 18],		# `:144`
	"列头_组队": [202, 16, 36, 18],		# `:147`
	"列头_次数": [257, 16, 36, 18],		# `:150`
	"列分隔1": [140, 16, 2, 20],		# `:152`
	"列分隔2": [191, 16, 2, 20],		# `:154`
	"列分隔3": [242, 16, 2, 20],		# `:156`
	"星级标题": [328, 14, 235, 18],		# `:161-164` x=详情面板.x+3，宽=235，高 18
	"星级分隔": [328, 61, 225, 2],		# `:167-169` (328,90) width=225（LineHPicF 整帧拉）
	"星容器": [359, 38, 98, 13],		# `:172-173` x=详情面板.x+34=359，y=67；宽=7×14
	"详情滚动": [328, 67, 224, 142],		# `:177-180` (328,96) 224×142
	"奖励标题": [331, 65, 76, 18],		# container 局部 (3,−2) ⇒ 窗口 (331,94)
	"进入钮": [330, 213, 37, 22],		# `:235-238` (330,242) btn_width_two=37
	"密卷钮": [410, 213, 82, 22],		# `:243-246` (410,242) btn_width_six=82
	"排行钮": [190, 220, 94, 22],		# `:227-230` (190,249) btn_width_seven=94，visible=false
	"勾选": [15, 220, 156, 19],		# `:220-222` (15,249)；宽 = 19 皮 + 5 间隙 + 11 字×12
	"列表": [14, 36, 302, 167],		# `:251-254` (14,65) setSize(302,167)
	"行容器": [14, 36, 298, 180],		# 9 行 × 20；比视口高 13 ⇒ 出竖滚条（与实机一致）
	"行1": [14, 36, 298, 20],		# 第 1 行 = 列表原点 + (0,0)
	"行1/名": [14, 36, 124, 18],		# 列 0
	"行1/选中底": [14, 36, 298, 20],
	"确认钮": [190, 213, 37, 22],		# 本工程既有 819 流程，静止隐藏
	"取消钮": [229, 213, 37, 22],
	"领取钮": [268, 213, 37, 22],
}


func 页名() -> String:
	return "副本"


func 根节点名() -> String:
	return "原版副本内容"


func 期望() -> Dictionary:
	## `行容器` 的高 = 行数 × 行高，而**行数来自数据**（2.2.3 版滤完是 8 行、V2.6 是 9 行）
	## ⇒ 不能写死在 const 表里，否则换数据源就凭空红一条。其余都是常量矩形。
	var 出 := 件期望.duplicate(true)
	出["行容器"] = [14.0, 36.0, 行宽, float(_读配置().size() * int(行高))]
	return 出


func 路径() -> Dictionary:
	return 件路径


func 页面件表() -> Dictionary:
	return 页面件


func 页面文案表() -> Dictionary:
	return 页面文案


func 文案表() -> Dictionary:
	return 原文


func 有页签() -> bool:
	return false


func 公共件() -> Array[String]:
	return ["内容底"]


## 本页特有的门：行数据、列色、星级算法、隐藏钮、勾选框皮。
func 额外校验(页: Control, _页号: int) -> void:
	var 列 := 页.get_node_or_null(件路径["行容器"]) as Control
	if 列 == null:
		_错("取不到 行容器")
		return
	var 行们: Array[Control] = []
	for 子 in 列.get_children():
		if 子 is Control:
			行们.append(子 as Control)
	# 原版 `getAllFuBenObj()`（连号到缺号停）+ `filterData()`（删 show==0）⇒ 9 条
	var 配置 := _读配置()
	var 数对 := 行们.size() == 配置.size()
	有错 = 有错 or (not 数对)
	行.append("  行数=%d 配置=%d（getAllFuBenObj 连号到缺号停 + filterData 删 show=0）%s" % [
		行们.size(), 配置.size(), "√" if 数对 else "!! 不符"])
	for i in mini(行们.size(), 配置.size()):
		var 行件: Control = 行们[i]
		var 条: Dictionary = 配置[i]
		var 矩 := [14.0, float(36 + i * 行高), float(行宽), float(行高)]
		量(页, 行件, "行%d" % (i + 1), 矩)
		# ⚠ 用 `str()` 不用 `String()`：Godot 4.7 的 `String(整数)` 会报
		#   `Invalid call 'String' constructor`（实测 `String(条["reqLevel"])` 直接把整轮门打断，
		#   而报错里打出来的"参数"是上一行的件名，看日志会误判成场景问题）。
		# ⚠ `JSON.parse_string` 把所有数字都解成 float ⇒ `str(条["reqLevel"])` 会得到 "15.0"。
		#   原版那列是整数 ⇒ 两边都必须 `int()` 再转串（只改控制器不改门 = 双双打错还互相对得上）。
		var 想列 := [["名", str(条["name"])], ["等级", str(int(条["reqLevel"]))],
			["组队", _组队(str(条["teamType"]))], ["次数", "0/%d次" % _上限(条)]]
		for c in 4:
			var 件 := 行件.get_node_or_null(想列[c][0]) as Label
			if 件 == null:
				_错("行%d 缺列 %s" % [i + 1, 想列[c][0]])
				continue
			量(页, 件, "行%d/%s" % [i + 1, 想列[c][0]],
				[14.0 + float(行列[c]), 36.0 + i * 行高, float(行宽列[c]), 18.0])
			var 同 := 件.text == String(想列[c][1])
			有错 = 有错 or (not 同)
			行.append("  行%d/%-4s %s（应 %s）%s" % [i + 1, 想列[c][0], 件.text, 想列[c][1],
					"√" if 同 else "!! 与配置/语言表不符"])
			var 想色: Color = 列色[想列[c][0]]
			var 色 := 件.get_theme_color(&"font_color")
			有错 = 有错 or (色 != 想色)
			行.append("  行%d/%s 色=%s（应 %s）%s" % [i + 1, 想列[c][0], 色.to_html(false),
					想色.to_html(false), "√" if 色 == 想色 else "!! 不符"])
	# 星级：`newStars()` `:279-314` —— ceil(stars) 枚，最后一枚在 `stars == ceil` 时才用实心
	var 首条: Dictionary = 配置[0]
	var 星数: float = float(首条["stars"])
	var 枚 := int(ceil(星数))
	var 容 := 页.get_node_or_null(件路径["星容器"]) as Control
	if 容 == null:
		_错("取不到 星容器")
		return
	var 槽们: Array = []
	for 子 in 容.get_children():
		if 子 is Control:
			槽们.append(子)
	var 亮 := 0
	var 错星 := 0
	for i in 槽们.size():
		var 槽 := 槽们[i] as TextureRect
		var 该: bool = i < 枚
		var 想皮 := "星实心.png" if (该 and (i < 枚 - 1 or 星数 == float(枚))) else "星空心.png"
		量(页, 槽, "星%d" % (i + 1), [359.0 + i * 星宽, 38.0, float(星宽), float(星高)])
		if 槽.visible != 该:
			错星 += 1
		var 槽图 := 槽.texture
		var 槽名 := "" if 槽图 == null else String(槽图.resource_path.get_file())
		if 该 and 槽名 != 想皮:
			错星 += 1
		if 该:
			亮 += 1
	有错 = 有错 or (错星 > 0) or (亮 != 枚)
	行.append("  星：stars=%s ⇒ ceil=%d 枚、末枚%s；亮 %d 槽 %d，错位 %d %s" % [
		星数, 枚, "实心" if 星数 == float(枚) else "空心", 亮, 槽们.size(), 错星,
		"√" if 错星 == 0 and 亮 == 枚 else "!! 不符"])
	# 排行钮：原版 `:232` `visible = false` ⇒ 烘在场景里但必须不可见，且不许被删
	var 排 := 页.get_node_or_null(件路径["排行钮"]) as Button
	if 排 == null:
		_错("排行钮不在场景里（原版是 visible=false，不是没有这颗钮）")
	else:
		有错 = 有错 or bool(排.visible)
		行.append("  排行钮 visible=%s（`:232` 写死 false）%s" % [排.visible,
				"√" if not 排.visible else "!! 应隐藏"])
	# 详情区那两块文字是**运行期按选中行填**的（`:543-545`），高度跟着文本走 ⇒
	# 不钉死高度，改钉原版那三条算式：奖励 @(20,17) 宽 170、说明 宽 200、
	# `copySay.y = tongGuanJiangli.y + textHeight + 1`（`:544`）。
	var 奖 := 页.get_node_or_null(件路径["奖励"]) as RichTextLabel
	var 说 := 页.get_node_or_null(件路径["说明"]) as RichTextLabel
	if 奖 == null or 说 == null:
		_错("详情区 奖励/说明 取不到")
		return
	var 原点 := 页.get_global_position()
	var 奖位 := 奖.get_global_position() - 原点
	var 说位 := 说.get_global_position() - 原点
	var 三对 := absf(奖位.x - 348.0) < 0.01 and absf(奖位.y - 84.0) < 0.01 \
			and absf(奖.size.x - 170.0) < 0.01 and absf(说位.x - 331.0) < 0.01 \
			and absf(说.size.x - 200.0) < 0.01
	var 式对 := absf(说位.y - (奖位.y + 奖.size.y + 1.0)) < 0.01
	有错 = 有错 or (not 三对) or (not 式对)
	行.append("  奖励 @(%.0f,%.0f)%.0fx%.0f（应 x348 y84 w170）%s" % [
		奖位.x, 奖位.y, 奖.size.x, 奖.size.y, "√" if 三对 else "!! 不符"])
	行.append("  说明 y=%.0f = 奖励y+奖励高+1=%.0f（`:544`）%s" % [
		说位.y, 奖位.y + 奖.size.y + 1.0, "√" if 式对 else "!! 没跟着文本走"])
	# 高度必须按 `行数 × 17`（与生成器同一条），**不许**用 `get_content_height()`：
	# RichTextLabel 的 min 宽被 autowrap 压小 ⇒ 内容高暴涨，把 说明 整块推出裁剪区
	# （2026-10-03 实测：改完控制器后「副本说明」凭空消失，而门照样全绿）。
	var 首条2: Dictionary = _读配置()[0]
	# 每条奖励 `【名×量】` 在 170 宽里占不满一行 ⇒ 行数 = 条数（无奖励时 1 行「无」）
	var 想奖 := float(maxi(1, (首条2["prize"] as Array).size()) * 17)
	var 想说 := float(_行数(_格式串(String(首条2["desc"])), 200) * 17)
	var 高对 := absf(奖.size.y - 想奖) < 0.01 and absf(说.size.y - 想说) < 0.01
	有错 = 有错 or (not 高对)
	行.append("  奖励高=%.0f（期 %.0f）说明高=%.0f（期 %.0f，行数×17）%s" % [
		奖.size.y, 想奖, 说.size.y, 想说, "√" if 高对 else "!! 用了 Godot 布局高，会把说明推出裁剪区"])
	行.append("  说明 宽=%.0f（`:211` 200）%s" % [说.size.x, "√" if absf(说.size.x - 200.0) < 0.01 else "!! 不符"])
	# 本工程既有的 819 流程三枚钮：静止态必须全隐藏（原版这扇窗只有 进入 + 密卷进入）
	for 名 in ["确认钮", "取消钮", "领取钮"]:
		var 件 := 页.get_node_or_null(件路径[名]) as Button
		if 件 == null:
			_错("%s 不在场景里（本工程既有 819 流程要用它）" % 名)
			continue
		量(页, 件, 名, 期望()[名])
		有错 = 有错 or bool(件.visible)
		行.append("  %-6s visible=%s（静止应隐藏；本工程既有流程，不参与原版对证）%s" % [
			名, 件.visible, "√" if not 件.visible else "!! 静止就露出来了"])


## `BaseUtil.formatStr`（`BaseUtil.as:378-392`）：删字面 `\r` 与真 `\r`，再把**字面 `\n`
## （两个字符）**换成换行。⚠ desc 在数据里存的就是字面 `\n` ⇒ 三方（生成器/控制器/门）
## 都必须先过这一道，否则行数算少、说明高度对不上。
func _格式串(文: String) -> String:
	文 = 文.replace("\\r", "").replace("\r", "")
	return 文.replace("\\n", "\n")


## 与 `开发工具/生成副本场景.py::行数` / 控制器 `_行数` 同一条：每行 `floor(宽/12)` 字
## （12px 宋体一个汉字正好占满 12px）。三边同源，改一处必须改三处。
func _行数(文: String, 宽: int) -> int:
	var 每行 := maxi(1, int(宽 / 12.0))
	var 总 := 0
	for 段 in 文.split("\n"):
		总 += maxi(1, int(ceil(float(段.length()) / float(每行))))
	return 总


func _读配置() -> Array:
	var f := FileAccess.open("res://数据/副本.json", FileAccess.READ)
	if f == null:
		_错("读不到 数据/副本.json（先跑 开发工具/导出副本配置.py）")
		return []
	var 体: Variant = JSON.parse_string(f.get_as_text())
	if typeof(体) != TYPE_DICTIONARY:
		_错("数据/副本.json 不是对象")
		return []
	return (体 as Dictionary).get("副本", []) as Array


## `CopyWindowCell.as:135-145`：teamType "1"→单人、"2"→组队、"3"→混合（其它→空串）
func _组队(类型: String) -> String:
	match 类型:
		"1":
			return "单人"
		"2":
			return "组队"
		"3":
			return "混合"
	return ""


## `:111-118`：`enter.through > 0` 用它当上限，否则用 `totalCount`（=`setData` 第二参）。
## 本工程 `totalCount` 取服务端 819 帧的 `maximum`；量具/门离线跑时没有它 ⇒ 用 1
## （用户实机截图整列都是 `0/1次`，与 `_copy_free_limit` 的最大值一致）。
func _上限(条: Dictionary) -> int:
	var 穿: int = int(((条["enter"] as Dictionary)).get("through", 0))
	return 穿 if 穿 > 0 else 1


## 基类排完步后追加两步：**真鼠标点第 3 行**，隔帧后验选中框真的挪过去了。
## 为什么必须真事件：上一版 `gui_input.connect(_点行.bind(i))` 的形参写成了
## `(序号, 事件)` —— `bind` 是往**参数表末尾**追加，实参错位 ⇒ 点谁都选不中，
## 而所有静态判据照样全绿（用户报的 bug2）。`emit()` 演不出来这一类错。
func _队列尾() -> void:
	super()
	队列.append(_步点第3行)
	队列.append(_步验点行)


func _步点第3行() -> void:
	var 页 := 页根()
	if 页 == null:
		return
	var 行 := 页.get_node_or_null(取路径("行容器") + "/行3") as Control
	if 行 == null:
		_错("点行步：取不到 行3")
		return
	var 中 := 行.get_global_rect().get_center()
	for 按下 in [true, false]:
		var 事 := InputEventMouseButton.new()
		事.button_index = MOUSE_BUTTON_LEFT
		事.pressed = 按下
		事.position = 中
		事.global_position = 中
		root.push_input(事)
	行.append("  已对 行3 中心 %s 发左键按下+松开" % 中)
	等待 = 4


func _步验点行() -> void:
	var 页 := 页根()
	if 页 == null:
		return
	var 容 := 页.get_node_or_null(取路径("行容器")) as Control
	var 一 := (容.get_node("行1/选中底") as Control).visible
	var 三 := (容.get_node("行3/选中底") as Control).visible
	var 对: bool = (not 一) and 三
	有错 = 有错 or (not 对)
	行.append("  点完 行3：行1选中=%s 行3选中=%s %s" % [一, 三,
			"√ 选中框挪过去了" if 对 else "!! 点行没生效（检查 gui_input 的形参顺序）"])
	# 右侧详情必须跟着换到第 3 条（秽土转生的通关奖励 = 写轮眼灵符×3）——
	# 证明 `_选()` 整条链（选中框 / 奖励 / 说明 / 星级 / 密卷钮可见性）都跑通了。
	var 奖 := 页.get_node_or_null(取路径("奖励")) as RichTextLabel
	var 换了: bool = 奖 != null and String(奖.text).contains("【写轮眼灵符×3】")
	行.append("  奖励文本随选中换页 = %s %s" % [str(奖.text).left(24).replace("\n", "↵"),
			"√" if 换了 else "!! 还是第 1 行的奖励"])
	有错 = 有错 or (not 换了)
	var 密 := 页.get_node_or_null(取路径("密卷钮")) as Button
	# 秽土转生 enter.needItemId = 0 ⇒ 原版 `:546-553` 这时要把「副本密卷进入」藏掉
	var 藏对: bool = 密 != null and not 密.visible
	行.append("  密卷钮按 needItemId 隐藏 = %s %s" % [密.visible if 密 else "null",
			"√" if 藏对 else "!! 该藏没藏"])
	有错 = 有错 or (not 藏对)


func 收尾校验(页: Control) -> void:
	行.append("=== 皮肤接线 / 尺寸表 ===")
	var 底 := 页.get_node_or_null("内容底") as Panel
	var 列板 := 页.get_node_or_null("列表面板") as Panel
	var 详板 := 页.get_node_or_null("详情面板") as Panel
	var 头 := 页.get_node_or_null("列头底") as Panel
	for 组 in [[底, "内容底", "内容面板.png", "MYellow_background `:126`"],
			[列板, "列表面板", "子面板.png", "MPane_background `:129`"],
			[详板, "详情面板", "子面板.png", "MPane_background `:132`"],
			[头, "列头底", "列表分隔.png", "ListSeparator_background(779) `:135`"]]:
		var 件 := 组[0] as Panel
		if 件 == null:
			_错("%s 取不到" % 组[1])
			continue
		var 名 := 皮(件, &"panel")
		有错 = 有错 or (名 != String(组[2]))
		行.append("  %-10s 皮=%s（应 %s，%s）%s" % [组[1], 名, 组[2], 组[3],
				"√" if 名 == String(组[2]) else "!! 不是原版皮"])
	# 三块行底都是同一张 MSelected_background1(705)；backBg 那张 alpha=0 ⇒ 不烘（见真值表）
	var 行1 := 页.get_node_or_null(件路径["行1"]) as Control
	if 行1 != null:
		for 名 in ["悬停底", "选中底"]:
			var 件 := 行1.get_node_or_null(名) as TextureRect
			if 件 == null:
				_错("行1 缺 %s" % 名)
				continue
			var 图 := 件.texture
			var 文 := "" if 图 == null else str(图.resource_path.get_file())
			# 悬停档静止隐藏；选中档第 1 行**必须可见**（`setListData` 末尾 selectedIndex=0）
			var 该露: bool = str(名) == "选中底"
			var 对: bool = 文 == "选中条1.png" and bool(件.visible) == 该露
			有错 = 有错 or (not 对)
			行.append("  行1/%s 皮=%s visible=%s（应 %s）%s" % [名, 文, 件.visible,
					"露出" if 该露 else "隐藏", "√" if 对 else "!! 皮或可见性不对"])
		有错 = 有错 or (行1.get_child(0).name != String("悬停底"))
		行.append("  行1 子件序=%s（原版 名/等级/组队/次数 之后才 add 悬停框、选中框 `:81-91`）%s" % [
			行1.get_child(0).name, "√" if 行1.get_child(0).name == &"悬停底" else "!! 第一枚不是悬停底"])
	for 组 in [[页.get_node_or_null("列分隔1") as TextureRect, "竖向分隔线.png", "TableSeparatorLineF(593) 2×20"],
			[页.get_node_or_null("星级分隔") as TextureRect, "横向分隔线.png", "LineHPicF(133) 整帧拉宽"]]:
		var 件 := 组[0] as TextureRect
		if 件 == null:
			continue
		var 文 := "" if 件.texture == null else String(件.texture.resource_path.get_file())
		有错 = 有错 or (文 != String(组[1]))
		行.append("  %-10s 图=%s（应 %s，%s）%s" % ["分隔线", 文, 组[1], 组[2],
				"√" if 文 == String(组[1]) else "!! 不是"])
	# 钮：`isScale9Grid = false` ⇒ 必须是**预烘到目标宽**的整帧皮，三档齐全
	# （原版这两枚从不 `enabled=false` ⇒ 不烘禁用档，别自造第四档）
	var 皮表 := {"进入钮": "钮_进入", "密卷钮": "钮_密卷", "排行钮": "钮_进入"}
	for 名 in ["进入钮", "密卷钮"]:
		var 件 := 页.get_node_or_null(件路径[名]) as Button
		if 件 == null:
			_错("%s 取不到" % 名)
			continue
		var 缺: Array[String] = []
		for 槽 in ["normal", "hover", "pressed"]:
			var 想 := "%s.png" % 皮表[名] if 槽 == "normal" else "%s_%s.png" % [皮表[名],
					{"hover": "悬停", "pressed": "按下"}[槽]]
			if 皮(件, StringName(槽)) != 想:
				缺.append("%s→%s(实 %s)" % [槽, 想, 皮(件, StringName(槽))])
		有错 = 有错 or (not 缺.is_empty())
		行.append("  %-8s 三态+禁用皮 %s" % [名, "√ 齐" if 缺.is_empty() else "!! " + ", ".join(缺)])
		有错 = 有错 or (件.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND)
		行.append("  %-8s 手型=%s %s" % [名, 件.mouse_default_cursor_shape,
				"√" if 件.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND else "!! 不是手型"])
	# 勾选框：MCheckBoxF 的方框就是那张 19×19（`复选框未选.png`）
	var 勾 := 页.get_node_or_null(件路径["勾选"]) as CheckBox
	if 勾 != null:
		var 图 := 勾.get_theme_icon(&"unchecked")
		var 文 := "" if 图 == null else String(图.resource_path.get_file())
		有错 = 有错 or (文 != "复选框未选.png")
		行.append("  勾选框皮=%s（MCheckBoxF 左端 19×19）%s" % [文,
				"√" if 文 == "复选框未选.png" else "!! 不是"])
	行.append("")


func 皮(件: Control, 键: StringName) -> String:
	var 箱 := 件.get_theme_stylebox(键) as StyleBoxTexture
	return "" if 箱 == null or 箱.texture == null else 箱.texture.resource_path.get_file()
