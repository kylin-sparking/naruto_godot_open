extends "res://开发工具/量具基类.gd"

## 量「精英副本」窗（原版 `com/mxw/uifl/controls/copy/EliteCopyWindow.as`，`super(500,426)` `:57`）。
## 骨架在 `开发工具/量具基类.gd`；逐件出处见 `测试/截图/精英副本_对照/真值对照表.md`
## 与 `game-client/真值/窗口/精英副本.md`。
##
## 三条本页特有口径：
##   1. **格位不是等距网格** —— `createCell()`（`:101-149`）那个带状态循环让第 1 行只有 4 枚、
##      第 2 行起 5 枚且第一枚落在 x=0。所有格位/线位/内容高只认
##      `数据/界面/精英副本_布局.json`（由 `开发工具/出精英副本布局.py` 现算），
##      量具 / 生成器 / 控制器三方共读这一份。
##   2. **页签是 `MTabButtonF` 且 `isScale9Grid=false`**（`:329-331`）⇒ 宽恒 `btn_width_five`=70、
##      整帧拉伸皮；选中 = `enabled=false` ⇒ 显示 `selectedUpSkin`（那张名叫 `*_disabled` 的皮），
##      **不推灰度**（`MTabButton.as:38` + 子类 `updateState`）。
##   3. **格内头像本机缺 15 张**（5200001~5200014、5200045）⇒ 头像槽留空、只钉尺寸，
##      这条挂未决，不许拿别的怪头像凑。
##
## 用法（不能加 --headless）：
##   Godot --path . --script res://开发工具/截精英副本页.gd -- --出目录=res://测试/截图/精英副本

const 布局路径 := "res://数据/界面/精英副本_布局.json"
const 文案路径 := "res://数据/界面/副本_文案.json"
const 抬 := 29
const 格宽 := 84
const 格高 := 124
const 页签宽 := 70
const 页签x0 := 17
const 页签y := 45 - 29
const 名宽 := 84
const 子面板 := [11, 65 - 29, 478, 336]
const 格内 := {
	"格底": [0, 0, 84, 81],
	"锁": [0, 0, 84, 81],
	"选中底": [0, 0, 84, 81],
	"名": [0, 84, 84, 18],
	"章节": [21, 64, 43, 18],
	"头像": [11, 5, 62, 62],
	"次数": [0, 100, 84, 20],
}
const 名色 := Color(0.988235, 0.717647, 0.6, 1)		# 16630681 #FDB799	`BailianCell.as:105`
const 白 := Color(1, 1, 1, 1)					# `:118` / `:25` 默认 16777215
const 页签字色 := Color(0.988235, 0.956863, 0.611765, 1)	# #fcf49c `MTabButton.as:12` 四态同色

var _布局: Dictionary = {}
var _文案表: Dictionary = {}


func _布局页() -> Array:
	if _布局.is_empty():
		var f := FileAccess.open(布局路径, FileAccess.READ)
		if f == null:
			_错("读不到 %s（先跑 开发工具/出精英副本布局.py）" % 布局路径)
			return []
		var 体: Variant = JSON.parse_string(f.get_as_text())
		_布局 = 体 if typeof(体) == TYPE_DICTIONARY else {}
	return (_布局.get("页", []) as Array)


func _页(n: int) -> Dictionary:
	var 页 := _布局页()
	return (页[n] as Dictionary) if n < 页.size() else {}


func 页名() -> String:
	return "精英副本"


func 根节点名() -> String:
	return "原版精英副本内容"


func 页签数() -> int:
	return _布局页().size()


func 有子页() -> bool:
	return true


func 内容容器名() -> String:
	return "格容器"


## 页签宽是写死的 70（`isScale9Grid=false`）⇒ 基类那套「文字宽+6」不适用。
func 页签宽按文字() -> bool:
	return false


func 页签容器名() -> String:
	return "分页"


func 公共件() -> Array[String]:
	return ["内容底", "子面板", "格滚动", "副本名"]


func 期望() -> Dictionary:
	var 出 := {
		"内容底": [5, 39 - 抬, 488, 381],
		"子面板": 子面板,
		"格滚动": 子面板,
		"格容器": [11, 36, 478, float(_页(当前页号).get("内容高", 336))],
	}
	# 副本名跟着**当前页**走（`setCopyName():300-305`：高 = textHeight+5、
	# y = 子面板.y + (110 − 高)/2）⇒ 只能按 当前页号 取，不能一次给四页各存一份。
	var 当页 := _页(当前页号)
	if not 当页.is_empty():
		出["副本名"] = [11.0, float(int(当页["名y"]) - 抬), float(名宽), float(int(当页["名高"]))]
	for n in 页签数():
		var 页: Dictionary = _页(n)
		出["页签%d" % n] = [float(页签x0 + n * 页签宽), float(页签y), float(页签宽), 22.0]
		for 格 in (页["格"] as Array):
			# ⚠ 键必须带页号：四页的 "格1" 不是同一枚，共用键会让后一页把前一页的期望顶掉
			var 名 := "页%d/格%d" % [n, int((格 as Dictionary)["序号"])]
			出[名] = [11.0 + float(格["x"]), 36.0 + float(格["y"]), float(格宽), float(格高)]
			for 件 in 格内:
				var 内: Array = 格内[件]
				if 件 == "头像":
					# 每张头像按**自己原生尺寸 + origin 对齐**（`PortraitHead.as:80-94`：
					# `_w/_h = -1` ⇒ 不缩放）。实测 21 张有 11 种尺寸 ⇒ 不能套固定 62×62
					# 的框去拉（用户 2026-10-03 报：图1 的头比图2 大、还糊）。
					内 = [float(格["头像位"][0]), float(格["头像位"][1]),
						float(格["头像尺寸"][0]), float(格["头像尺寸"][1])]
				出["%s/%s" % [名, 件]] = [11.0 + float(格["x"]) + 内[0],
					36.0 + float(格["y"]) + 内[1], 内[2], 内[3]]
			for j in (页["线"] as Array).size():
				出["页%d/线%d" % [n, j]] = [11.0, 36.0 + float((页["线"][j] as Array)[1]),
					478.0, 2.0]
	return 出


func 路径() -> Dictionary:
	var 出 := {"内容底": "内容底", "子面板": "子面板", "格滚动": "格滚动",
		"格容器": "格滚动/格容器", "副本名": "副本名", "分页": "分页"}
	for n in 页签数():
		出["页签%d" % n] = "分页/页签%d" % n
		出["页%d" % n] = "格滚动/格容器/页%d" % n
		var 页: Dictionary = _页(n)
		for 格 in (页["格"] as Array):
			var 短 := "格%d" % int((格 as Dictionary)["序号"])
			var 名 := "页%d/%s" % [n, 短]
			出[名] = "格滚动/格容器/页%d/%s" % [n, 短]
			for 件 in 格内:
				出["%s/%s" % [名, 件]] = "格滚动/格容器/页%d/%s/%s" % [n, 短, 件]
			for j in (页["线"] as Array).size():
				出["页%d/线%d" % [n, j]] = "格滚动/格容器/页%d/线%d" % [n, j]
	return 出


func 页面件表() -> Dictionary:
	var 出 := {}
	for n in 页签数():
		var 页: Dictionary = _页(n)
		var 列: Array = []
		for 格 in (页["格"] as Array):
			var 名 := "页%d/格%d" % [n, int((格 as Dictionary)["序号"])]
			列.append(名)
			for 件 in 格内:
				列.append("%s/%s" % [名, 件])
		for j in (页["线"] as Array).size():
			列.append("页%d/线%d" % [n, j])
		出[n] = 列
	return 出


func 页面文案表() -> Dictionary:
	var 出 := {}
	for n in 页签数():
		出[n] = ["副本名"]
	return 出


func 文案表() -> Dictionary:
	return {"副本名": str(_页(当前页号).get("名文本", ""))}


## 顺手把「当前页号」记下来：基类的 `_步验页` 在 `_量件表` **之前**调本函数，
## 而本页的 `期望()` / `文案表()` 都要按当前页取副本名高度与格位。
func 页签序号(页号: int) -> int:
	当前页号 = 页号
	return 页号


func 额外校验(页: Control, 页号: int) -> void:
	var 页据: Dictionary = _页(页号)
	# 页签枚数/文字来自数据表 ⇒ 必须烘进场景（编辑器=运行期），枚数不符就是漂移
	var 缺: Array[String] = []
	for n in 页签数():
		var 钮 := _第几(页.get_node_or_null("分页"), n) as Button
		if 钮 == null:
			缺.append("页签%d" % n)
			continue
		var 想 := str(_页(n)["页签"])
		if 钮.text != 想:
			缺.append("页签%d 文字 %s≠%s" % [n, 钮.text, 想])
		var 该选: bool = n == 页号
		if bool(钮.button_pressed) != 该选 and bool(钮.disabled) != 该选:
			缺.append("页签%d 选中态没落对（pressed=%s disabled=%s 应 %s）" % [
				n, 钮.button_pressed, 钮.disabled, 该选])
	有错 = 有错 or (not 缺.is_empty())
	行.append("  页签 %d 枚（数据 %d 枚）%s" % [页签数(), 页签数(),
			"√" if 缺.is_empty() else "!! " + ", ".join(缺)])
	# 格内件：颜色 + 文案 + 头像有无
	for 格 in (页据["格"] as Array):
		var 名 := "页%d/格%d" % [页号, int(格["序号"])]
		var 件 := 页.get_node_or_null(取路径(名)) as Control
		if 件 == null:
			_错("%s 取不到" % 名)
			continue
		var 标 := 件.get_node_or_null("名") as Label
		var 章 := 件.get_node_or_null("章节") as Label
		var 次 := 件.get_node_or_null("次数") as Label
		var 头 := 件.get_node_or_null("头像") as TextureRect
		var 错: Array[String] = []
		if 标 == null or 标.text != str(格["名"]):
			错.append("名=%s 应 %s" % [标.text if 标 else "null", 格["名"]])
		if 章 == null or 章.text != str(格["章"]):
			错.append("章=%s 应 %s" % [章.text if 章 else "null", 格["章"]])
		if 次 == null or 次.text != str(格["次数"]):
			错.append("次数=%s 应 %s" % [次.text if 次 else "null", 格["次数"]])
		if 标 != null and 标.get_theme_color(&"font_color") != 名色:
			错.append("名色 %s≠#FDB799" % 标.get_theme_color(&"font_color").to_html(false))
		for 组 in [[章, 白], [次, 白]]:
			if 组[0] != null and 组[0].get_theme_color(&"font_color") != 组[1]:
				错.append("%s 色不是白" % 组[0].name)
		var 有头: bool = 头 != null and 头.texture != null
		if 有头 != (str(格["头像"]) != ""):
			错.append("头像有=%s 数据有=%s" % [有头, str(格["头像"]) != ""])
		# 「不许缩放」：矩形尺寸必须 == 位图原生尺寸，否则就是塞进固定框里拉过
		if 头 != null and 头.texture != null:
			var 原: Vector2i = Vector2i(int(头.texture.get_width()), int(头.texture.get_height()))
			if 原.x != int(格["头像尺寸"][0]) or 原.y != int(格["头像尺寸"][1]) \
					or int(头.size.x) != 原.x or int(头.size.y) != 原.y:
				错.append("头像被缩放 框%dx%d 图%dx%d 数据%dx%d" % [
					int(头.size.x), int(头.size.y), 原.x, 原.y,
					int(格["头像尺寸"][0]), int(格["头像尺寸"][1])])
		有错 = 有错 or (not 错.is_empty())
		行.append("  %-4s %s%s" % [名, "√ 名/章/次数/色/头像都对" if 错.is_empty() else "!! ",
				", ".join(错)])
	# 分隔线跟着 `createCell` 走：5 枚以上的页才有，且宽 = 滚动区宽
	var 线数 := (页据["线"] as Array).size()
	var 实线 := 0
	var 容 := 页.get_node_or_null("格滚动/格容器/页%d" % 页号) as Control
	if 容 != null:
		for 子 in 容.get_children():
			if 子.name.begins_with("线"):
				实线 += 1
	有错 = 有错 or (实线 != 线数)
	行.append("  页%d 分隔线 %d 根（`createCell:114-122` 应 %d）%s" % [页号, 实线, 线数,
			"√" if 实线 == 线数 else "!! 不符"])


func 收尾校验(页: Control) -> void:
	行.append("=== 皮肤接线 ===")
	var 组 := [["内容底", "内容面板.png", "MYellow_background `:371`"],
			["子面板", "子面板.png", "MPane_background `:377`"]]
	for 项 in 组:
		var 件 := 页.get_node_or_null(String(项[0])) as Panel
		if 件 == null:
			_错("%s 取不到" % 项[0])
			continue
		var 名 := 皮(件, &"panel")
		有错 = 有错 or (名 != String(项[1]))
		行.append("  %-8s 皮=%s（应 %s，%s）%s" % [项[0], 名, 项[1], 项[2],
				"√" if 名 == String(项[1]) else "!! 不是"])
	# 页签四档：normal=未选、hover=+30、pressed/disabled=选中皮（selectedUpSkin 原色）
	var 钮0 := _第几(页.get_node_or_null("分页"), 0) as Button
	if 钮0 != null:
		var 槽 := {"normal": "页签_未选.png", "hover": "页签_未选_悬停.png",
				"pressed": "页签_选中.png", "disabled": "页签_选中.png"}
		var 错: Array[String] = []
		for k in 槽:
			if 皮(钮0, StringName(k)) != String(槽[k]):
				错.append("%s→%s" % [k, 皮(钮0, StringName(k))])
		var 色错 := false
		for k in [&"font_color", &"font_hover_color", &"font_pressed_color",
			&"font_hover_pressed_color", &"font_disabled_color"]:
			if 钮0.get_theme_color(k) != 页签字色:
				色错 = true
		有错 = 有错 or (not 错.is_empty()) or 色错
		行.append("  页签四档皮 %s；五档字色同 #fcf49c=%s %s" % [
			"√ 齐" if 错.is_empty() else "!! " + ", ".join(错), not 色错,
			"" if 错.is_empty() and not 色错 else ""])
		for n in 页签数():
			var 钮 := _第几(页.get_node_or_null("分页"), n) as Button
			if 钮 != null and 钮.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
				有错 = true
				行.append("  !! 页签%d 不是手型光标（`MButton3.init:135`）" % n)
	# 格三张皮：底 / 锁 / 选中底
	var 格一 := 页.get_node_or_null(取路径("页0/格1")) as Control
	if 格一 != null:
		for 项 in [["格底", "精英格底.png"], ["锁", "精英格锁.png"], ["选中底", "精英格选中.png"]]:
			var 件 := 格一.get_node_or_null(String(项[0])) as TextureRect
			if 件 == null:
				_错("格1/%s 取不到" % 项[0])
				continue
			var 名 := "" if 件.texture == null else str(件.texture.resource_path.get_file())
			var 该隐: bool = String(项[0]) != "格底"
			var 对: bool = 名 == String(项[1]) and bool(件.visible) != 该隐
			有错 = 有错 or (not 对)
			行.append("  格1/%-6s 图=%s visible=%s（应 %s / %s）%s" % [项[0], 名, 件.visible,
					项[1], "隐" if 该隐 else "露", "√" if 对 else "!! 不符"])
		var 序: Array = []
		for 子 in 格一.get_children():
			序.append(str(子.name))
		var 想序 := ["格底", "锁", "选中底", "名", "章节", "头像", "次数"]
		有错 = 有错 or (序 != 想序)
		行.append("  格1 子件序=%s（`BailianCell.as:81-131` + `EliteCopyWindowCell.as:32`）%s" % [
			"/".join(序), "√" if 序 == 想序 else "!! 应为 " + "/".join(想序)])
	行.append("")


func 皮(件: Control, 键: StringName) -> String:
	var 箱 := 件.get_theme_stylebox(键) as StyleBoxTexture
	return "" if 箱 == null or 箱.texture == null else 箱.texture.resource_path.get_file()
