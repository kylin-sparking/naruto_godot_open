extends SceneTree
# 家族**开窗**回归门（headless）：验 `家族子窗壳` + `功能窗口.家族开窗/家族收窗` 这套接线，
# 不再量件矩形（那是 `家族子窗几何回归测试.gd` 的活）。查五件事：
#   ① 开窗表每个窗名都有场景、装得进壳，且 窗尺寸 = 内容 + (16,38)
#      —— 列表窗 604×332 ⇒ 620×370 正好是 `FamillyListWindow.as` 的声明尺寸（两条口径互相印证）；
#   ② 窗壳三件按 `MWindow.as:162-221`：标题 y=5 高 18、关钮 x=round(宽−25−6) y=6、内容原点 (8,38)；
#   ③ 半透窗皮必须在内容**之下**（`框` 是 index 0）；
#   ④ 拖动区必须排在关钮**之前**（Godot 按子节点逆序派发输入，反了就吞掉关钮点击）；
#   ⑤ 再点同一个入口 = 收起；`收窗表` 指向的窗名必须在 `开窗表` 落点里（防死键）；
#      未入族入口 = 直接开列表窗，且页面重绘不该把它关掉（用户实机 2026-09-29 截图）。
# 跑法：Godot --path . --headless --script res://测试/家族开窗回归测试.gd

const 壳脚本 := preload("res://脚本/界面/窗口/家族/家族子窗壳.gd")
const 宿主脚本 := preload("res://测试/假家族宿主.gd")
const 场景目录 := "res://场景/界面/窗口/家族/"
const 内容原点 := Vector2(8, 38)
const 关钮尺寸 := Vector2(25, 24)
## 原版不是 UIWindow 的三种：自带整幅底和自己的关钮 ⇒ 不许套窗壳
const 无壳窗 := ["家族确认弹", "家族旗帜帮助窗", "家族Boss奖励条", "家族Boss完成窗"]
## 原版由服务器推送/事件推开、没有 UI 入口的窗（`FamillyBossPrizeTip`、`FamillyPetFinishWindow`）
## ⇒ 允许只出现在收窗表，不算死键。
const 事件推窗 := ["家族Boss奖励条", "家族Boss完成窗"]

var _红 := 0


func _initialize() -> void:
	var 脚: Script = load("res://脚本/界面/窗口/家族/家族子窗壳.gd")
	# 常量表从窗壳脚本直接读：注册表改了名、少了一项，这道门就要响（别在测试里另抄一份）
	var 常: Dictionary = 脚.get_script_constant_map()
	var 开窗: Dictionary = 常.get("开窗", {})
	var 收窗: Dictionary = 常.get("收窗", {})
	if 开窗.is_empty() or 收窗.is_empty():
		print("!! 读不到 家族子窗壳 的 开窗/收窗 常量（改名了？）")
		quit(1)
		return
	var 宿主 = 宿主脚本.new()
	root.add_child(宿主)
	var 层: Control = 宿主._overlay
	var 落点 := {}
	for 入口 in 开窗:
		var 定: Array = 开窗[入口]
		var 窗名 := String(定[0])
		var 有壳 := bool(定[2])
		落点[窗名] = true
		if 有壳 == (窗名 in 无壳窗):
			_报("%s 的 壳=%s 与原版不符" % [窗名, 有壳])
		if not ResourceLoader.exists(场景目录 + 窗名 + ".tscn"):
			_报("%s 场景不存在" % 窗名)
			continue
		壳脚本.切换(宿主, 窗名, String(定[1]), 有壳)
		var 根 := 层.get_node_or_null("家族子窗_" + 窗名) as Control
		if 根 == null:
			_报("%s 没开出来（_overlay 下找不到）" % 窗名)
			continue
		var 内容 := 根.get_child(1 if 有壳 else 0) as Control
		var 尺: Vector2 = 内容.get_combined_minimum_size()
		_等("%s 窗尺寸" % 窗名, 根.size, 尺 + 内容原点 * Vector2(2, 1) if 有壳 else 尺)
		_等("%s 内容原点" % 窗名, 内容.position, 内容原点 if 有壳 else Vector2.ZERO)
		if 有壳:
			var 框 := 根.get_node("窗壳") as Control
			var 题 := 根.get_node("标题") as Label
			var 关 := 根.get_node("关闭按钮") as Control
			var 拖 := 根.get_node("拖动区") as Control
			if 框.get_index() != 0:
				_报("%s 窗皮不在最底（半透会盖住内容）" % 窗名)
			if 拖.get_index() > 关.get_index():
				_报("%s 拖动区排在关钮之后 ⇒ 吞掉关钮点击" % 窗名)
			_等("%s 标题落点" % 窗名, Vector2(题.position.y, 题.size.y), Vector2(5, 18))
			_等("%s 关钮位" % 窗名, 关.position, Vector2(roundf(根.size.x - 关钮尺寸.x - 6.0), 6.0))
			_等("%s 关钮尺寸" % 窗名, 关.size, 关钮尺寸)
			if 题.text != String(定[1]):
				_报("%s 标题 ≠ 开窗表文案（%s）" % [窗名, 题.text])
		壳脚本.切换(宿主, 窗名, String(定[1]), 有壳)
		if 层.get_node_or_null("家族子窗_" + 窗名) != null:
			_报("%s 再点入口没收起来" % 窗名)
	for 入口 in 收窗:
		var 目标 := String(收窗[入口])
		if not ResourceLoader.exists(场景目录 + 目标 + ".tscn"):
			_报("收窗表 %s 指向 %s，但场景不存在" % [入口, 目标])
		elif not 落点.has(目标) and not (目标 in 事件推窗):
			_报("收窗表 %s 指向的 %s 既没入口也不是事件推窗 ⇒ 死键" % [入口, 目标])
	壳脚本.关掉(宿主, "家族令牌窗")		# 没开着也要安全
	if 层.get_child_count() != 0:
		_报("关掉() 空操作却留了节点")
	宿主._session.guild["joined"] = false
	壳脚本.只在未开时开(宿主, "家族列表窗", "家族列表")
	壳脚本.只在未开时开(宿主, "家族列表窗", "家族列表")	# 页面重绘不该反过来把它关掉
	if not 壳脚本.已开(宿主, "家族列表窗"):
		_报("未入族入口没开家族列表窗（或重绘时自己关了）")
	else:
		_等("列表窗 = FL 声明 620×370", (层.get_node("家族子窗_家族列表窗") as Control).size,
				Vector2(620, 370))
	print("家族开窗门：开窗 %d 条 / 收窗 %d 条，红 %d" % [开窗.size(), 收窗.size(), _红])
	quit(1 if _红 > 0 else 0)


func _报(话: String) -> void:
	_红 += 1
	print("!! " + 话)


func _等(名: String, 实: Vector2, 期: Vector2) -> void:
	if (实 - 期).length() > 1.0:
		_报("%s 实测 %s ≠ 期望 %s" % [名, 实, 期])
