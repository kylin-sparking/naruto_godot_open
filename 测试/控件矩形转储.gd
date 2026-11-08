extends SceneTree

## 转储某个功能页里全部可见控件的全局矩形，用来定位空白条、越界控件和错位。
##
## 运行：
##   Godot --headless --path . --script res://测试/控件矩形转储.gd -- \
##       --page=人物 [--最小面积=0] [--调用=_set_prize_tab,1] [--只看问题]
##
## `--调用=<方法>[,<整数参数>]`：开页之后、转储之前调一次，用来切到带页签的页。
##   例：福利窗的「在线有礼」是第 1 个页签 → `--调用=_set_prize_tab,1`。
## `--只看问题`：只打印查出问题的那几行。
## `--查提示`：额外报"可交互控件但 tooltip_text 为空"（默认关，开了噪音大）。
##
## 查什么、以及**哪几条可信**（2026-09-25 对着真实输出逐条校过）
##
## | 检查 | 默认 | 可信度 |
## |---|---|---|
## | **文本溢出**（文字比框宽 → 画到框外压住旁边，即玩家说的"UI 重叠"） | 开 | ✅ **反向对照验过**，且逮到过真缺陷 |
## | **半成品按钮**（可点，但 `pressed`/`toggled`/`item_selected` 都没连） | 开 | ✅ **反向对照验过** |
## | **占位符残留**（文本里露 `%1`/`null`/`{` 这类模板） | 开 | ⚠️ 未反向对照过，但假报源少 |
## | 文本为空 | **关** | ❌ 假报极多（空格子的数量标签本来就该空）→ `--查空文本` |
## | 提示信息为空 | **关** | 需 `--查提示`；不是每个按钮都该有 tooltip，开着噪音大 |
##
## ⚠️ 三条**踩过的坑**，改这个文件前先读：
## 1. **不要用 `get_combined_minimum_size()` 量文字宽** —— 无头下不反映文本，
##    文案加长到两百多字它照样报"0 条问题"（假阴性）。用 `字体.get_string_size()`。
## 2. **多行文本要按最长一行量** —— 本项目大量用 `\n` 换行，拿整串量会假报溢出。
## 3. **只看 `is_visible_in_tree()`** —— 不筛会把其它页/已隐藏面板的控件一起报出来
##    （八门页 8 个门按钮全在同一坐标、全"没连信号"，就是那一页没显示）。
##
## ⚠️ "该有数据却是 0" 这一类**没做** —— 判据不明确（等级/金币本来就可能显示 0），
##    硬做会满屏假报。要做得上白名单，等有具体需求再说。

## 全窗口扫一遍（30 个页面）：
##   for 页 in 人物 背包 忍术 …; do
##     Godot --headless --path . --script res://测试/控件矩形转储.gd -- --page=$页 --只看问题
##   done
##
## ⚠️ **文字溢出这一条是 2026-09-25 补的**，查的是玩家嘴里那类「UI 重叠」：
##    Godot 的 `Label` 默认**既不裁剪也不换行**（`clip_text=false` / `autowrap` 关），
##    文字比它自己的矩形宽时，会**直接画到框外、压住旁边的东西**。
##    矩形本身量不出这个 —— 框是合规的，是**字**超出了框。所以这里拿
##    `get_combined_minimum_size()`（文字真实需要的尺寸）跟矩形比。
##    实测：福利窗「在线有礼」的奖励文案正是这么溢出的。

var _frames := 0
var _done := false
var _page := "人物"
var _最小面积 := 0.0
var _调用 := ""
var _调用参数 := 0
var _只看问题 := false
## `--查提示`：还要报"可交互控件但 tooltip_text 为空"。
## 默认**关** —— 不是每个按钮都必须有 tooltip，开着时噪音大，适合专门查"提示信息不全"。
var _查提示 := false
## `--查空文本`：报"可见 Label 但文本为空"。默认**关** —— 空格子/无状态时为空是正常的，
## 开着会满屏假报（实测背包 27 / NPC仓库 30 条全是空格子）。
var _查空文本 := false
var _win: Node = null
var _已调用 := false
var _问题数 := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--page="):
			_page = arg.trim_prefix("--page=")
		elif arg.begins_with("--最小面积="):
			_最小面积 = float(arg.trim_prefix("--最小面积="))
		elif arg.begins_with("--调用="):
			var 片 := arg.trim_prefix("--调用=").split(",", true)
			_调用 = 片[0]
			if 片.size() > 1:
				_调用参数 = int(片[1])
		elif arg == "--只看问题":
			_只看问题 = true
		elif arg == "--查提示":
			_查提示 = true
		elif arg == "--查空文本":
			_查空文本 = true
	var scene: PackedScene = load("res://场景/界面/功能窗口.tscn")
	if scene == null:
		push_error("功能窗口.tscn 加载失败")
		_done = true
		quit(1)
		return
	_win = scene.instantiate()
	get_root().add_child(_win)
	_win.call_deferred("open_page", _page)


## **同一个父节点下，有没有兄弟按钮连了 `pressed`。**
##
## 判据的来由（2026-09-25）：只查"没连信号"会把**装饰性页签**全报进来 ——
## 单页签的页（如技能书的「秘籍合成」）本来就常亮、压根不需要处理函数；
## 而真正漏连的，通常是**一组页签里少连了一个**，同组必然有别的连上了。
## 加上这一条之后，30 个窗口从「3 条可疑」收敛到「只剩成组出现的那些」。
func _同组有连上的(b: Button) -> bool:
	var 父 := b.get_parent()
	if 父 == null:
		return false
	for 兄弟 in 父.get_children():
		if 兄弟 == b or not (兄弟 is Button):
			continue
		if not (兄弟 as Button).get_signal_connection_list("pressed").is_empty():
			return true
	return false


func _dump(node: Node, depth: int) -> void:
	if node is Control:
		var c := node as Control
		# ⚠️ **只看真正显示出来的控件** —— 2026-09-25 实测：不筛的话会把**其它页/已隐藏面板**里的
		#    控件一起报出来（八门页那 8 个门按钮全在同一个坐标、全"没连信号"，
		#    就是没显示的那一页），满屏假报，比不查还坏。
		if not c.is_visible_in_tree():
			for child in node.get_children():
				_dump(child, depth + 1)
			return
		var r := c.get_global_rect()
		if r.size.x * r.size.y >= _最小面积:
			var 附加 := ""
			var 问题 := ""
			if c is Button:
				var b := c as Button
				var 连了: int = b.get_signal_connection_list("pressed").size()
				附加 = " disabled=%s icon=%s 变体=%s 覆盖normal=%s 连pressed=%d" % [
					b.disabled, b.icon != null, b.theme_type_variation,
					b.has_theme_stylebox_override("normal"), 连了,
				]
				# ⚠️ 这里原来还有一条"可点但既没字也没图标" —— **已删**，它是假报源：
				#    忍术格那类按钮的图标画在子节点/样式里，`b.icon` 恒为 null，
				#    一次就误报 15 条。真正要查的是"点了没反应"，就是下面那条。
				if not b.disabled and 连了 == 0 and b.get_signal_connection_list("toggled").is_empty() \
						and b.get_signal_connection_list("item_selected").is_empty() \
						and b.shortcut == null and not (b is CheckBox) and not (b is OptionButton) \
						and _同组有连上的(b):
					# 半成品：看着能点、点了什么都不会发生。
					# ⚠️ 排除 CheckBox（走 toggled）/ OptionButton（走 item_selected）/ 有 shortcut 的
					#    —— 它们不接 `pressed` 也是正常的。
					问题 = "  ← **半成品：可点但没连任何信号**（点了不会有反应）"
				elif _查提示 and b.tooltip_text.strip_edges().is_empty():
					问题 = "  ← 提示信息为空（tooltip_text 没写）"
			elif c is Label:
				var l := c as Label
				var 字号 := l.get_theme_font_size("font_size")
				var 字体 := l.get_theme_font("font")
				# ⚠️ **不要用 `get_combined_minimum_size()` 量文字宽度** —— 2026-09-25 实测它在
				#    无头下**不反映文本**：把奖励文案故意加长到两百多字，它照样报"0 条问题"
				#    （假阴性）。直接问字体要宽度才准。
				# ⚠️ 文本里可以有 `\n`（本项目大量用它换行）—— 那就要按**最长的一行**量，
				#    拿整串去量会把多行文本当成一行，**假报溢出**（2026-09-25 实测）。
				var 需要宽 := 0.0
				if 字体 != null:
					for 行 in l.text.split("\n", true):
						需要宽 = maxf(需要宽, 字体.get_string_size(行, HORIZONTAL_ALIGNMENT_LEFT, -1, 字号).x)
				附加 = " 字=%d 色=%s 文本=%s" % [
					字号, l.get_theme_color("font_color"), JSON.stringify(l.text),
					]
				var 会换行: bool = l.autowrap_mode != TextServer.AUTOWRAP_OFF
				# 占位符残留 / 未替换的模板 —— 都是"该显示内容却显示了别的"。
				var 脏 := ""
				for 记号 in ["%1", "%2", "%s", "%d", "undefined", "null", "NaN", "{", "}"]:
					if l.text.contains(记号):
						脏 = 记号
						break
				# ⚠️ "文本是空的"**默认不查** —— 它假报极多：背包/仓库的空格子、没 buff 的
				#    状态栏……空着本来就对。2026-09-25 实测：背包 27 条、NPC仓库 30 条**全是这个**，
				#    而它们全是真的空格子。要查得开 `--查空文本`，并且**自己按页判断**。
				if l.text.strip_edges().is_empty() and l.visible:
					if _查空文本:
						问题 = "  ← 文本是空的（注意：空格子/无状态时为空是正常的）"
				elif not 脏.is_empty():
					问题 = "  ← **文本里有未替换的占位符 `%s`**（该显示内容的地方露了模板）" % 脏
				elif not 会换行 and 需要宽 > r.size.x + 1.0:
					if l.clip_text:
						问题 = "  ← 文本要 %.0f px、框只有 %.0f px —— 设了裁剪，不会压到别人但会被**截断**" % [需要宽, r.size.x]
					else:
						问题 = "  ← **文本溢出 %d px**（要 %.0f、框只有 %.0f，Label 既不裁剪也不换行 → 会画到框外压住旁边）" % [int(需要宽 - r.size.x), 需要宽, r.size.x]
			if not 问题.is_empty():
				_问题数 += 1
			if not _只看问题 or not 问题.is_empty():
				print("%s%s %s%s%s" % ["  ".repeat(depth), c.name, r, 附加, 问题])
	for child in node.get_children():
		_dump(child, depth + 1)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	if _frames == 4 and not _调用.is_empty() and _win != null and _win.has_method(_调用):
		_win.call(_调用, _调用参数)
		return false
	if _frames < 12:
		return false
	_done = true
	print("=== 页面 ", _page, " 视口 ", get_root().get_visible_rect().size, " ===")
	_dump(get_root(), 0)
	print("=== 共 %d 条问题 ===" % _问题数)
	return true
