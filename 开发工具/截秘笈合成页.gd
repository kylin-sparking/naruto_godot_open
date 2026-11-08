extends "res://开发工具/量具基类.gd"

## 量「秘笈合成」窗（原版 `JiNengCompositeWindow.as`，340×381，一个页签）。
## 骨架与口径在 `开发工具/量具基类.gd`；这里只放这一页的表。
## 逐件出处见 `测试/截图/秘笈合成_对照/真值对照表.md`。
##
## 用法（不能加 --headless）：
##   Godot --path . --script res://开发工具/截秘笈合成页.gd -- --出目录=res://测试/截图/秘笈合成

const 内 := Vector2(5, 29)	# `_contentBox` 的页面局部位置：页内件 = 内 + 源码相对值

## `en_US$message_properties.as` 原文（htmlText），基类里 `译文为BBCode()` 译一遍再逐字对。
const 原文 := {
	"说明": "<font color='#ff9100'>秘笈合成可以将忍术残卷合成为忍术秘笈<br/>合成成功则你将获得忍术秘笈<br/>合成失败将回收辅残卷，不回收主残卷</font>",
	# `EQUIP_UPGRADE_CAILIAO_DESCS_2` 里的 `"5"` 是占位符，`:128` 换成 `_fu4.label.text`
	# = `StringTool.getItemString(configInfo.helpItemId)`，而 helpItemId=16000015 = 幸运符
	# （`数据/原版杂项.json` 的 CanJuanHeCheng + `数据/物品.json` 的 16000015）。
	"材料说明": "<font color='#ffffff'>辅残卷需要和主残卷同类型<br/>幸运符：提高合成的成功概率</font>",
	# `EQUIP_STRENGTH_DESC_TEMPLATE_1`：`￥`/`$` 是占位符，空态都替换成 0 ⇒ 这就是原版空态。
	"结果": "<font color='#ffffff'>本次操作消耗精华：￥<br/>本次操作成功几率：$%</font>",
	## ── 短标签：正文一律取语言表；颜色另存（无 BBCode 的件只能校属性）
	"放入残卷": "放入残卷",				# EQUIP_STRENGTH_DROP_ITEM_BTN_NAMES_3（取出态是 _4）
	"开始合成": "开始合成",				# EQUIP_STRENGTH_STRENGTH_BTN_NAMES_5；AS3 取数组下标 [4]
	"购买": "购买",					# SHOP_BUY（只有第 4 格有，`ItemCaiLiaoBox(true)`）
	"使用幸运符": "本次操作使用",			# EQUIP_STRENGTH_DESC_TEMPLATE_2；`:235-238`
									# ⚠ **不是**"使用幸运符"：与右边下拉 + 「个幸运符」连成一句
	"单位": "个幸运符",					# COMMON_GE「个%1」填 COMMON_ITEM_NAMES_1 = 幸运符（`:259-262`）
	"材料格标签": "<font color='#ff9900'>辅残卷</font>",		# COMMON_ITEM_NAMES_2；色 = `ItemCaiLiaoBox.as:131` UI_ORANGE（**语言表里没有色**）
}

## 件名 → 文字必须落到的颜色（只校无 BBCode 的 `Label` / `Button` 族；
## `RichTextLabel` 的颜色在上面 `原文` 的 `<font>` 段里，逐字比对已覆盖）。
const 文案色 := {
	"材料格标签": Color(1, 0.6, 0, 1),		# UI_ORANGE 16748800	`ItemCaiLiaoBox.as:131`
	"使用幸运符": Color(1, 1, 1, 1),		# `:237` textColor = 16777215
	"单位": Color(1, 1, 1, 1),			# `:260` MGlowLabel.color = 16777215
}

const 页签文字色 := Color(0.988235, 0.956863, 0.611765, 1)	# #fcf49c，`MTabButton.as:12` 四态同色

## 唯一那枚页签：文案 = `EQUIP_UPGRADE_TAB_NAMES_1`（`CN.as:3109-3112` 是长度 1 的数组）；
## 宽 = 文字宽 + 6（`MButton3.as:383`，工程宋体 12px 实量 48）。生成器与离线门都读这张表。
const 页签真值 := {
	"页签0": ["秘笈合成", 54],
}

## 四格材料排的标签（生成器与门同源）：1..3 = `COMMON_ITEM_NAMES_2`，
## 第 4 格不是语言表键，是 `StringTool.getItemString(configInfo.helpItemId)`，
## helpItemId = 16000015 = 幸运符（`数据/原版杂项.json` 的 `CanJuanHeCheng` + `数据/物品.json`）。
const 材料格文案 := ["辅残卷", "辅残卷", "辅残卷", "幸运符"]

## 结果区下拉的四态皮（fl `ComboBox.defaultStyles:28-31`；原生 116×21、有 scaling grid，
## 右帽 22 上下就是箭头 ⇒ 45 宽只压扁中间字段）。字色白 + 左对齐（`MComboBox.as:22/53-54` 硬灌）。
const 下拉皮 := {
	"normal": "下拉框.png",
	"hover": "下拉框悬停.png",
	"pressed": "下拉框按下.png",
	"disabled": "下拉框禁用.png",
}

const 件路径 := {
	"内容框": "内容框",
	"开始合成": "开始合成",
	"说明": "内容框/说明",
	"说明分隔线": "内容框/说明分隔线",
	"放入残卷区": "内容框/放入残卷区",
	"放入残卷": "内容框/放入残卷区/放入残卷",
	"主残卷格": "内容框/放入残卷区/主残卷格",
	"方向箭头": "内容框/放入残卷区/方向箭头",
	"秘籍格": "内容框/放入残卷区/秘籍格",
	"材料格1": "内容框/材料格1",
	"材料格2": "内容框/材料格2",
	"材料格3": "内容框/材料格3",
	"材料格4": "内容框/材料格4",
	"材料格标签": "内容框/材料格1/标签",
	"材料格物品格": "内容框/材料格1/物品格",
	"购买": "内容框/材料格4/购买",
	"材料说明": "内容框/材料说明",
	"结果区": "内容框/结果区",
	"结果": "内容框/结果区/结果",
	"使用幸运符": "内容框/结果区/使用幸运符",
	"幸运符数量": "内容框/结果区/幸运符数量",
	"单位": "内容框/结果区/单位",
}

## 每页要量的件 / 要逐字对文案的件。**写成 const** 是为了让离线门
## `测试/秘笈合成页回归测试.gd` 能用 `get_script_constant_map()` 读到同一份（函数体读不到）。
const 页面件 := {0: ["说明", "说明分隔线", "放入残卷区", "放入残卷", "主残卷格", "方向箭头", "秘籍格",
	"材料格1", "材料格2", "材料格3", "材料格4", "材料格标签", "材料格物品格", "购买",
	"材料说明", "结果区", "结果", "使用幸运符", "幸运符数量", "单位"]}
const 页面文案 := {0: ["说明", "材料说明", "结果", "放入残卷", "开始合成", "购买",
	"材料格标签", "使用幸运符", "单位"]}
## 页面局部矩形 = 内 + 源码相对值（算式在真值对照表里逐条注了）。
const 件期望 := {
	"内容框": [5, 29, 330, 290],			# (5,58) w=340−5×2 h=381−91
	"开始合成": [274, 325, 61, 22],			# x=340−btn_width_four 61−5，y=381−22−5
	"说明": [13, 37, 324, 57],				# setSize(340−16,58)；3 行 ⇒ 文本盒 15·3+2·4+4=57
	"说明分隔线": [13, 96, 324, 2],			# line.y = 0+57+2 = 59（组件内）
	"放入残卷区": [13, 99, 83, 214],			# ItemDropBox(true) @(8,70)
	"放入残卷": [24, 109, 61, 22],			# x=(83−61)/2，y=10
	"主残卷格": [34.5, 136, 40, 40],			# x=(83−40)/2，y=10+22+5
	"方向箭头": [47.5, 176, 14, 87],			# x=(83−14)/2，y=37+40，h=214−127
	"秘籍格": [34.5, 263, 40, 40],			# y=arrow.y+arrow.h=164
	"材料格1": [100, 99, 56, 88],			# HBox @(95,70) gap=2 ⇒ x=0/58/116/174
	"材料格2": [158, 99, 56, 88],
	"材料格3": [216, 99, 56, 88],
	"材料格4": [274, 99, 56, 88],
	"材料格标签": [100, 99, 56, 20],			# MLabel 默认高 20、adjustContent=false
	"材料格物品格": [108, 119, 40, 40],		# x=(56−40)/2=8，y=20
	"购买": [283.5, 162, 37, 22],			# 只有 _fu4 有：x=(56−37)/2，y=cell.y+40+3
	"材料说明": [100, 161, 180, 38],			# @(95,70+91−29=132) 180×77、line 隐藏；2 行 ⇒ 38
	"结果区": [100, 241, 229, 70],			# @(95,132+80=212) 宽=340−8−83−20=229
	"结果": [106, 247, 207, 38],			# (2,2)+padding4；2 行 ⇒ 15·2+4+4=38
	"使用幸运符": [104, 289, 98, 19],			# MCheckBoxF width=98 @(4,48)，高=图标皮 19
	"幸运符数量": [202, 285, 45, 22],			# MComboBox width=45 @(102,44)
	"单位": [247, 289, 52, 20],				# MGlowLabel @(102+45,48)，宽=文字宽+4
}


func 页名() -> String:
	return "技能书"


func 根节点名() -> String:
	return "原版秘籍合成内容"


func 期望() -> Dictionary:
	return 件期望


func 路径() -> Dictionary:
	return 件路径


func 页面件表() -> Dictionary:
	return 页面件


func 页面文案表() -> Dictionary:
	return 页面文案


func 文案表() -> Dictionary:
	return {
		"说明": 原文["说明"],
		"材料说明": 原文["材料说明"],
		"结果": 原文["结果"].replace("￥", "0").replace("$", "0"),
		"放入残卷": 原文["放入残卷"],
		"开始合成": 原文["开始合成"],
		"购买": 原文["购买"],
		"材料格标签": 原文["材料格标签"],
		"使用幸运符": 原文["使用幸运符"],
		"单位": 原文["单位"],
	}


func 公共件() -> Array[String]:
	return ["内容框", "开始合成"]


## 原版只有 1 个页签 ⇒ 基类跳过子页可见性；这里补本页特有的门。
func 额外校验(页: Control, _页号: int) -> void:
	var 页签 := _第几(页.get_node_or_null("分页"), 0) as Button
	if 页签 != null:
		有错 = 有错 or (not bool(页签.button_pressed))
		行.append("  页签0 pressed=%s（`createChildren` 末尾 selectedIndex=0）%s" % [
			页签.button_pressed, "√" if 页签.button_pressed else "!! 错"])
		# 基类的"页签宽按文字"是**拿现场文字反算**的 ⇒ 文字写错它跟着错（自证）。
		# 所以文案与宽度另钉一次 `页签真值`（生成器读同一张表）。
		var 项: Array = 页签真值["页签0"] as Array
		var 字对 := 页签.text == String(项[0])
		var 宽对 := absf(页签.size.x - float(项[1])) <= 0.01
		有错 = 有错 or (not 字对) or (not 宽对)
		行.append("  页签0 文案=%s 宽=%.1f（应 %s / %s = 文字宽+6）%s" % [
			页签.text, 页签.size.x, 项[0], 项[1], "√" if 字对 and 宽对 else "!! 错"])
	var 勾 := 页.get_node_or_null(件路径["使用幸运符"]) as CheckBox
	var 下拉 := 页.get_node_or_null(件路径["幸运符数量"]) as MenuButton
	if 勾 == null or 下拉 == null:
		_错("缺 使用幸运符 或 幸运符数量（下拉不是 MenuButton？）")
		return
	# `:93-94` 初始 = userCfg.canJuan.useXingYunFu（默认 false）⇒ 未勾 + 下拉锁 + 显示第 1 项
	var 项数 := 下拉.get_popup().get_item_count()
	var 齐 := (not bool(勾.button_pressed)) and 下拉.disabled and 项数 == 9 and 下拉.text == "1"
	有错 = 有错 or (not 齐)
	行.append("  下拉初始 勾=%s disabled=%s 项数=%d 文字=%s（原版 1..9、enabled=false）%s" % [
		勾.button_pressed, 下拉.disabled, 项数, 下拉.text, "√" if 齐 else "!! 错"])
	勾.set_pressed_no_signal(true)
	勾.emit_signal("toggled", true)
	有错 = 有错 or 下拉.disabled
	行.append("  勾上后 disabled=%s %s" % [下拉.disabled, "√" if not 下拉.disabled else "!! 仍锁着"])
	勾.set_pressed_no_signal(false)
	勾.emit_signal("toggled", false)
	有错 = 有错 or (not 下拉.disabled)
	# 标签文案：`COMMON_ITEM_NAMES_2`=辅残卷 ×3，第 4 格 = helpItem 名（幸运符，
	# `StringTool.getItemString(configInfo.helpItemId=16000015)`，见 `数据/原版杂项.json` 的 CanJuanHeCheng）
	for i in 4:
		var 标 := 页.get_node_or_null(取路径("材料格%d" % (i + 1)) + "/标签") as Label
		_验标签(标, 材料格文案[i], "材料格%d标签" % (i + 1))
	# 无 BBCode 件的字色（`文案色` 表逐条带 AS3 行号；颜色不在语言表里，只能这么校）
	for 名 in 文案色:
		var 件 := 页.get_node_or_null(取路径(String(名))) as Control
		if 件 == null:
			_错("%s 取不到（校字色）" % 名)
			continue
		var 想: Color = 文案色[名]
		var 色 := 件.get_theme_color(&"font_color")
		有错 = 有错 or (色 != 想)
		行.append("  %-16s %s（应为 %s）%s" % [String(名) + ".色", 色.to_html(false),
				想.to_html(false), "√" if 色 == 想 else "!! 不符"])


func _验标签(标: Label, 想: String, 名: String) -> void:
	if 标 == null:
		_错("%s 取不到" % 名)
		return
	var 同 := 标.text == 想
	有错 = 有错 or (not 同)
	行.append("  %-16s %s %s" % [名, 标.text, "√" if 同 else "!! 应为 %s" % 想])


## 页签三态皮肤接线（与宝石工艺同一套 `MTabButton` 规则）。
func 收尾校验(页: Control) -> void:
	行.append("=== 页签三态接线 ===")
	var 钮 := _第几(页.get_node_or_null("分页"), 0) as Button
	if 钮 == null:
		_错("页签 0 取不到")
		return
	var 常 := 皮(钮, &"normal")
	var 悬 := 皮(钮, &"hover")
	var 选 := 皮(钮, &"pressed")
	var 选悬 := 皮(钮, &"hover_pressed")
	var 色对 := true
	for 键 in [&"font_color", &"font_hover_color", &"font_pressed_color",
		&"font_hover_pressed_color", &"font_disabled_color"]:
		if 钮.get_theme_color(键) != 页签文字色:
			色对 = false
	var 齐 := 常 != "" and 悬 != "" and 常 != 悬 and 选 != "" and 选悬 == 选
	有错 = 有错 or (not 齐) or (not 色对)
	行.append("  页签0 常=%s 悬=%s 选中=%s 选中悬=%s 四态文字同色=%s %s" % [
		常, 悬, 选, 选悬, 色对, "√" if 齐 and 色对 else "!! 悬停没换亮皮 / 选中态不一致"])
	var 内容盒 := 页.get_node_or_null("内容框") as Panel
	if 内容盒 != null:
		var 内容皮 := 皮(内容盒, &"panel")
		var 内容对 := 内容皮 == "内容面板.png"
		有错 = 有错 or (not 内容对)
		行.append("  内容框皮=%s（MYellow_background ⇒ 内容面板.png）%s" % [内容皮, "√" if 内容对 else "!! 不是"])
	var 区 := 页.get_node_or_null(件路径["放入残卷区"]) as Panel
	if 区 != null:
		var 子皮 := 皮(区, &"panel")
		var 子对 := 子皮 == "子面板.png"
		有错 = 有错 or (not 子对)
		行.append("  放入残卷区皮=%s（MPane_background ⇒ 子面板.png）%s" % [子皮, "√" if 子对 else "!! 不是"])
	var 结果盒 := 页.get_node_or_null(件路径["结果区"]) as Panel
	if 结果盒 != null:
		var 结皮 := 皮(结果盒, &"panel")
		var 结对 := 结皮 == "子面板.png"
		有错 = 有错 or (not 结对)
		行.append("  结果区皮=%s（`_resultBox.setSkin(MPane_background)` `:234`）%s" % [结皮, "√" if 结对 else "!! 不是"])
	# 下拉四态皮：`MenuButton` **默认 flat=true ⇒ 接了皮也整块不画**（宝石工艺页实测），
	# 所以这里既比文件名也钉 `flat=false`；字色白 + 左对齐（`MComboBox.as:22` 的 TextFormat 硬灌）。
	var 下拉 := 页.get_node_or_null(件路径["幸运符数量"]) as MenuButton
	if 下拉 == null:
		_错("幸运符数量 不是 MenuButton（OptionButton 有 64px 最小宽地板，会压住「个幸运符」）")
	else:
		var 皮齐 := true
		for 槽 in 下拉皮:
			var 名 := 皮(下拉, StringName(槽))
			皮齐 = 皮齐 and 名 == String(下拉皮[槽])
			行.append("  下拉 %s 皮=%s（应 %s）%s" % [槽, 名, 下拉皮[槽],
					"√" if 名 == String(下拉皮[槽]) else "!! 没接上原版皮"])
		var 白 := Color(1, 1, 1, 1)
		var 装对 := (not 下拉.flat) and 下拉.alignment == HORIZONTAL_ALIGNMENT_LEFT \
				and 下拉.get_theme_color(&"font_color") == 白 \
				and 下拉.get_theme_color(&"font_disabled_color") == 白
		有错 = 有错 or (not 皮齐) or (not 装对)
		行.append("  下拉 flat=%s 左对齐=%s 字色=%s %s" % [str(下拉.flat),
				str(下拉.alignment == HORIZONTAL_ALIGNMENT_LEFT),
				下拉.get_theme_color(&"font_color").to_html(false),
				"√" if 装对 and 皮齐 else "!! flat/对齐/字色 有一项不对"])
	行.append("")


func 皮(件: Control, 键: StringName) -> String:
	var 箱 := 件.get_theme_stylebox(键) as StyleBoxTexture
	return "" if 箱 == null or 箱.texture == null else 箱.texture.resource_path.get_file()
