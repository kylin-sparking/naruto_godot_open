extends "res://开发工具/截意志学习页.gd"

## 用户 2026-10-20 实机报：意志学习窗「一键学习 / 一键拾取 / 一键卖出」点了都没反应，
## 学习到的意志也拾取不了。本探针把三族点击逐族真点一遍（`root.push_input` 派发，
## 不用 `pressed.emit()` —— emit 绕不过命中判定，见 [[gate-must-use-real-input]]）：
##   ① 三个大 TextureButton：真点 ⇒ 离线应给诚实话（`学习回执` 文案进「后端状态」）
##   ② 学习格上的「拾取」「卖出」Label（`_填学习格` 给它们接的是 `gui_input`）
##   ③ 顺带打印每件的祖先链 mouse_filter / 悬停归属 ——「点了没反应」的两大惯犯：
##      a) 祖先某级 IGNORE 让整棵子树失明（功能窗口.gd:506 的注释是这么写的）；
##      b) Label 默认 `mouse_filter=IGNORE`（Godot 4 的 Label 初值）⇒ gui_input 永远收不到。
## 用法（不能加 --headless）：
##   Godot --path . --script res://开发工具/验意志一键钮.gd -- "--出目录=res://测试/截图/意志一键钮"

## 图鉴里 101=吊车尾(灰，无「拾取」)、201=凝神(绿，有「拾取」)。
## 喂这两件 ⇒ 格0 走非灰路径、格1 走灰色路径，两条都覆盖。
## ⚠ 喂数据的时机必须在**基类空态门跑完之后**（`额外校验` 断"无数据时 0 格可见"）⇒
##   放 `_队列尾` 第一步，并走 `spirit_state_changed` 让功能窗口重渲（与在线回帧同一条路）。
const 喂入面板件 := [201, 101]

var _计数: Dictionary = {}


func _队列尾() -> void:
	队列.append(_步喂数据)
	队列.append(_步查件态)
	队列.append(_步点大钮.bind("全部拾取"))
	队列.append(_步验回执.bind("全部拾取", "拾取全部意志需要连接原版服务端"))
	队列.append(_步点大钮.bind("全部卖出"))
	队列.append(_步验回执.bind("全部卖出", "卖出全部意志需要连接原版服务端"))
	队列.append(_步点大钮.bind("一键学习"))
	队列.append(_步验回执.bind("一键学习", "一键学习意志需要连接原版服务端"))
	队列.append(_步点格钮.bind(0, "拾取"))
	队列.append(_步验格钮.bind(0, "拾取"))
	队列.append(_步点格钮.bind(0, "卖出"))
	队列.append(_步验格钮.bind(0, "卖出"))
	队列.append(_步点格钮.bind(1, "卖出"))
	队列.append(_步验格钮.bind(1, "卖出"))
	队列.append(_步查灰格无拾取)
	队列.append(_步查悬停归属)


# ═════════════════ 辅助 ═════════════════

## 喂两件真意志并触发重渲染。基类空态门（"无数据时 0 格可见"）已经在这之前跑完，
## 所以这里放心喂；`spirit_state_changed` 让 `功能窗口._refresh_current` 重建本页，
## 与在线时服务端回帧驱动的是同一条路（`游戏会话.gd:2282`）。
func _步喂数据() -> void:
	var 会 := root.get_node_or_null("GameSession")
	if 会 == null:
		_错("取不到 GameSession")
		return
	会.set("spirit_panel", 喂入面板件.duplicate())
	if 会.has_signal("spirit_state_changed"):
		会.emit_signal("spirit_state_changed")
	等待 = 4
	行.append("  喂面板件       spirit_panel=%s ⇒ 已触发重渲染" % str(喂入面板件))


func _状态文案() -> String:
	var 主 := 主窗()
	var 状 := 主.get_node_or_null("后端状态") as Label if 主 != null else null
	return 状.text if 状 != null else ""


func _送移动(点: Vector2) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 点
	移.global_position = 点
	root.push_input(移)


## 分两跳进中心：大距离一步瞬移时同一帧只按最后一条 motion 做拾取，会不发 mouse_entered。
func _悬到(件: Control) -> void:
	var 心 := 件.get_global_rect().position + 件.get_global_rect().size / 2.0
	var 页 := 页根()
	var 远 := (页.get_global_position() + Vector2(20.0, 20.0)) if 页 != null else Vector2(20.0, 20.0)
	_送移动((心 + 远) / 2.0)
	等待 = 2
	_送移动(心)
	等待 = 3


func _点(件: Control) -> void:
	_悬到(件)
	for 按 in [true, false]:
		var 键 := InputEventMouseButton.new()
		var 心 := 件.get_global_rect().position + 件.get_global_rect().size / 2.0
		键.position = 心
		键.global_position = 心
		键.button_index = MOUSE_BUTTON_LEFT
		键.pressed = 按
		root.push_input(键)
	等待 = 3


func _件(路: String) -> Control:
	var 页 := 页根()
	return 页.get_node_or_null(路) as Control if 页 != null else null


## 从件往上走到根，逐级打印（含 filter / clip / visible）——「整棵子树点不到」看这条链。
func _报祖先链(件: Control) -> void:
	var 级 := 件
	var 串 := ""
	while 级 != null:
		串 += "%s[f=%d c=%s v=%s] ← " % [级.name, 级.mouse_filter,
				str(级.clip_contents), str(级.is_visible_in_tree())]
		级 = 级.get_parent_control()
	行.append("      祖先链 " + 串 + "root")


# ═════════════════ ① 三个大钮 ═════════════════

func _步查件态() -> void:
	var 页 := 页根()
	if 页 == null:
		_错("取不到页面根")
		return
	for 名 in ["一键学习", "全部拾取", "全部卖出", "返回", "打开背包"]:
		var 件 := _件("导师面板/" + 名)
		if 件 == null:
			_错("取不到 导师面板/%s" % 名)
			continue
		var 盒 := 件.get_global_rect()
		行.append("  件态 %-6s 矩形=%s 全局中心=%s disabled=%s visible=%s filter=%d"
				% [名, 盒, 盒.position + 盒.size / 2.0, 件.disabled, 件.visible, 件.mouse_filter])
		_报祖先链(件)
	var 喂 := _件("意志容器/意志格_0")
	if 喂 != null:
		行.append("  喂面板件后 意志格_0 visible=%s（spirit_panel=%s）"
			% [喂.visible, str(喂入面板件)])
	for 格 in [0, 1]:
		for 字 in ["拾取", "卖出"]:
			var 件 := _件("意志容器/意志格_%d/%s" % [格, 字])
			if 件 == null:
				_错("取不到 意志格_%d/%s" % [格, 字])
				continue
			行.append("  格%d小字       「%s」filter=%d visible=%s 手型=%s rect=%s"
				% [格, 字, 件.mouse_filter, 件.visible,
					件.mouse_default_cursor_shape,
					件.get_global_rect()])
	等待 = 2


func _步点大钮(名: String) -> void:
	var 件 := _件("导师面板/" + 名)
	if 件 == null:
		_错("点不到 %s（件不存在）" % 名)
		return
	if not 件.visible:
		_错("%s 当前不可见（`_刷新导师状态` 按 `special_enabled` 藏它）—— 实机看不到≠点不到，先确认可见性" % 名)
	if 件.disabled:
		_错("%s 处于 disabled（`_绑三态钮` 见 disabled 直接早退、连三态都不接）" % 名)
	var 心 := 件.get_global_rect().position + 件.get_global_rect().size / 2.0
	_悬到(件)
	for 按 in [true, false]:
		var 键 := InputEventMouseButton.new()
		键.position = 心
		键.global_position = 心
		键.button_index = MOUSE_BUTTON_LEFT
		键.pressed = 按
		root.push_input(键)
	等待 = 3
	var 悬 := root.get_viewport().gui_get_hovered_control()
	行.append("  真点 %-6s 心=%s 点完悬停=%s" % [名, 心, str(悬)])


func _步验回执(名: String, 想: String) -> void:
	var 得 := _状态文案()
	if 得 != 想:
		_错("点「%s」后后端状态=「%s」，应为「%s」⇒ 点击没走到 `_接学习钮` 的回执支"
			% [名, 得, 想])
	else:
		行.append("  %-6s 可点      状态「%s」√" % [名, 得])


# ═════════════════ ② 学习格上的小字 ═════════════════

func _步点格钮(格: int, 动作: String) -> void:
	var 件 := _件("意志容器/意志格_%d/%s" % [格, 动作])
	if 件 == null:
		_错("取不到 意志格_%d/%s" % [格, 动作])
		return
	if not 件.visible:
		_错("意志格_%d/%s 不可见（非灰才显「拾取」）" % [格, 动作])
	if 件.mouse_filter != Control.MOUSE_FILTER_STOP:
		_错("意志格_%d/%s mouse_filter=%d，应为 STOP(0)——Label 默认 IGNORE，gui_input 收不到" % [格, 动作, 件.mouse_filter])
	var 心 := 件.get_global_rect().position + 件.get_global_rect().size / 2.0
	_悬到(件)
	for 按 in [true, false]:
		var 键 := InputEventMouseButton.new()
		键.position = 心
		键.global_position = 心
		键.button_index = MOUSE_BUTTON_LEFT
		键.pressed = 按
		root.push_input(键)
	等待 = 3
	行.append("  真点 格%d/%-4s filter=%d 心=%s 点完悬停=%s"
		% [格, 动作, 件.mouse_filter, 心, str(root.get_viewport().gui_get_hovered_control())])


func _步验格钮(格: int, 动作: String) -> void:
	var 得 := _状态文案()
	var 想 := "%s意志要在服务端结算（离线不模拟）" % 动作
	if 得 != 想:
		_错("点学习格%d「%s」后状态=「%s」，应为「%s」⇒ `gui_input` 没收到（Label 默认 IGNORE？）"
			% [格, 动作, 得, 想])
	else:
		行.append("  格%d小字可点    「%s」⇒ 状态「%s」√" % [格, 动作, 得])


## 灰色格（格1 = 101 吊车尾）不该有「拾取」（`YiZhiStudyCell:92-94` 三元）。
func _步查灰格无拾取() -> void:
	var 拾 := _件("意志容器/意志格_1/拾取")
	var 卖 := _件("意志容器/意志格_1/卖出")
	var 对: bool = 拾 != null and not 拾.visible and 卖 != null and 卖.visible
	有错 = 有错 or not 对
	if 对:
		行.append("  灰格态         格1（101 灰）「拾取」隐、「卖出」显（卖出对齐方式=%s）√"
			% (卖.horizontal_alignment if 卖 != null else -1))
	else:
		行.append("  灰格态         格1 拾取.visible=%s 卖.visible=%s !! 错"
			% [str(拾.visible) if 拾 != null else "<无>", str(卖.visible) if 卖 != null else "<无>"])


## 把鼠标放到「全部拾取」中心，看 Godot 认为悬停的是谁 —— 若返回的是别的东西
## （页面根/说明文字/某个容器），点击就被它吃了。
func _步查悬停归属() -> void:
	var 件 := _件("导师面板/全部拾取")
	if 件 == null:
		return
	_悬到(件)
	var 悬 := root.get_viewport().gui_get_hovered_control()
	var 对: bool = 悬 == 件
	有错 = 有错 or not 对
	if 对:
		行.append("  悬停归属       全部拾取 中心 ⇒ hovered=自己 √")
	else:
		行.append("  悬停归属       全部拾取 中心 ⇒ hovered=%s !! 错（点击被它吃）" % str(悬))
	var 像 := _件("导师面板/导师容器/导师_0/头像")
	if 像 != null:
		_悬到(像)
		行.append("  悬停归属       导师_0 头像 ⇒ hovered=%s（对照：头像点击用户说是好的）"
			% str(root.get_viewport().gui_get_hovered_control()))
