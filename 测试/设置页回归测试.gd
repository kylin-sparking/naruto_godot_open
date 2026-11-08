extends SceneTree
## 设置页几何与状态门（headless）：场景与期望**同源**（`开发工具/生成设置场景.py` 一份 SPEC 出两份），
## 所以这里量的不是"我抄的期望"，而是"场景有没有照 SPEC 落"。真值：`game-client/真值/窗口/设置.md` §1–§6。
##
## 跑法：Godot --path . --headless --script res://测试/设置页回归测试.gd
## 除坐标外还验四件会复发的假绿：
##   ① 逐件**取不到就报**（别把 404 当"这件不重要"）；
##   ② 勾选态取自**假宿主**的 game_settings（撞 autoload 名 = 假通过，见好友页 §9）；
##   ③ 页签选中枚显示的是 selectedUpSkin（disabled 档），不是灰度；
##   ④ 音量滑块位置 = v·170 − 7（AS3 drawCircle 圆心在 (0,25) ⇒ 框要偏 −7）。

const 场景 := "res://场景/界面/窗口/设置/设置窗口.tscn"
const 期望文件 := "res://数据/界面/设置页期望.json"
const 容差 := 1.0
## 行根该挂的那份状态机，与它取派生皮的共享件目录（期望值写死在这里，不从被测件反查）。
const 件脚本路 := "res://脚本/界面/组件/原版复选项.gd"
const 通用件目录 := "res://素材/界面/原版窗口/通用控件/"

var _红 := 0


func _initialize() -> void:
	_跑()


## ⚠ 整段搬进协程并**先等两帧**：`root.add_child(页)` 之后，节点自己脚本的 `_ready()`
## 不在同一调用栈里跑（10-19 现查：`add_child` 当时读 `主干=[]`、四条信号 0 条连接，
## 两帧之后才变成 `主干=[两张皮]`、各 1 条）。不 await 的话，"组件没接上"这种**假红**
## 会一直挂着，反过来也说明判据读的是 `_ready` 的产物、不是场景里的静态属性。
func _跑() -> void:
	var 期: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(期望文件))
	var 页 := (load(场景) as PackedScene).instantiate() as Control
	if 页 == null:
		print("!! 场景 instantiate null")
		quit(1)
		return
	root.add_child(页)
	await process_frame
	await process_frame
	var 宿: Node = load("res://测试/假设置宿主.gd").new()
	root.add_child(宿)
	页.call("装配", 宿)
	# 真宿主在 装配 之后还要填「客户端」层（`系统窗口._render_settings` 那三步），
	# 假宿主必须一起演一遍：它内部会 `more.visible = true`，不补 重摆层 就是实机那次的泄漏
	宿.call("_render_more_settings", 页, (宿.get("_session") as Node).get("game_settings"))
	页.call("重摆层")
	验几何(页, 期)
	验层互斥(页, 宿)
	验状态(页, 宿, 期)
	验勾选(页, 宿, 期)
	验音量(页, 宿, 期)
	验文案(页, 期)
	验复选态(页, 期)
	验写入回退链(页, 宿)
	页.queue_free()
	print("设置页：几何 %d 件 + 状态/勾选/音量/文案/复选态 22 行，红 %d" % [(期["件"] as Dictionary).size(), _红])
	quit(1 if _红 > 0 else 0)


## 只有 `_session` 的裸宿主：`设置窗口._写` 的回退链要用它。
## 真宿主 `功能窗口` 有 `_set_check`/`_set_slider`，所以这条链在实机走不到 ——
## 但那正是它危险的地方：方法名写错也**永远不会被发现**（原来写的是 `set_game_setting`，
## 会话里只有 `update_setting`，`游戏会话.gd:1721`）。
class 裸宿主 extends Node:
	class 裸会话 extends Node:
		var game_settings := {"mute_music": true}
		var 收到: Array[String] = []

		func update_setting(键: String, 值: Variant) -> void:
			收到.append("%s=%s" % [键, 值])
			game_settings[键] = 值

	var _session := 裸会话.new()

	func _ready() -> void:
		add_child(_session)


## ⑤ `_写(键, 值)` 的两条路（`设置窗口.gd:138-147`）：
##   宿主有 `_set_check`/`_set_slider` ⇒ 走宿主；**没有** ⇒ 落到会话的 `update_setting`，
##   最后才退到本页字典。**任何一条都不许静默什么都不写**（那就是"设置点了没用"）。
func 验写入回退链(页: Control, 宿: Node) -> void:
	# ① 宿主优先：`_set_check` 在，就别越过它去动会话
	var 宿写前: int = (宿.get("写") as Array).size()
	页.call("_写", "mute_music", false)
	if (宿.get("写") as Array).size() != 宿写前 + 1:
		_报("宿主有 `_set_check` 时 `_写` 该走宿主，实测宿主一条都没收到")
	if bool((宿.get("_session") as Node).game_settings.get("mute_music", true)):
		_报("走宿主那条没把值写真：game_settings.mute_music 还是 true")
	# ② 没有 `_set_check` 的宿主 ⇒ 必须落到 `会话.update_setting`
	var 裸 := 裸宿主.new()
	root.add_child(裸)
	var 页裸 := (load(场景) as PackedScene).instantiate() as Control
	root.add_child(页裸)
	页裸.call("装配", 裸)
	页裸.call("_写", "mute_music", false)
	var 会: Node = 裸.get("_session")
	if (会.get("收到") as Array).is_empty():
		_报("宿主没有 `_set_check` 时 `_写` 该落到 `会话.update_setting`（方法名写错 ⇒ 恒 false、静默不写）")
	elif bool(会.game_settings.get("mute_music", true)):
		_报("落到 `update_setting` 那条没把值写真")
	页裸.queue_free()
	裸.queue_free()


func 验几何(页: Control, 期: Dictionary) -> void:
	for 路 in (期["件"] as Dictionary):
		if String(路).ends_with("/钮滑块"):
			continue		# 滑块位置是运行期值（x = v·170 − 7），由 验音量 按公式断言，不与设计位比
		var 节 := 页.get_node_or_null(NodePath(String(路))) as Control
		if 节 == null:
			_报("缺件：%s（路径 %s）" % [路, 路])
			continue
		var 录: Array = (期["件"] as Dictionary)[路][0]
		var d := maxf(maxf(absf(节.position.x - 录[0]), absf(节.position.y - 录[1])),
				maxf(absf(节.size.x - 录[2]), absf(节.size.y - 录[3])))
		if d > 容差:
			_报("%s 实测 (%s,%s,%s,%s) ≠ 期望 %s" % [路, 节.position.x, 节.position.y, 节.size.x, 节.size.y, 录])


## 层互斥 + 页签选中态：主页可见、特页隐藏、三枚里选中那枚 disabled（⇒ 读 texture_disabled 皮）。
func 验状态(页: Control, 宿: Node, 期: Dictionary) -> void:
	var 主 := 页.get_node("层主页") as Control
	var 特 := 页.get_node("层特页") as Control
	if not 主.visible or 特.visible:
		_报("初始页态不对：主页 %s 特页 %s（期望 主显 特隐）" % [主.visible, 特.visible])
	var 钮们: Array = []
	for 条 in (期["页签"] as Array):
		var 钮 := 页.get_node_or_null(NodePath(String(条[0]))) as TextureButton
		if 钮 == null:
			_报("页签缺件：%s" % 条[0])
			continue
		钮们.append(钮)
	# 原版只有前 3 枚（§2）；第 4 枚「客户端」是本工程自加的，不算还原偏差但必须在位
	if 钮们.size() != 4:
		_报("页签应 3 原版 + 1 客户端 = 4 枚，实得 %d" % 钮们.size())
		return
	if not (钮们[0] as TextureButton).disabled:
		_报("选中的系统设置页签没走 disabled（原版 enabled=false ⇒ selectedUpSkin）")
	# 皮 39 宽、钮 59 宽（`isScale9Grid=false` ⇒ 整张非等比拉）⇒ 只能 STRETCH_SCALE。
	# 写成 stretch_mode=1 是 STRETCH_TILE（平铺），59 宽里会重出一段皮，看着就是"一排页签互相叠住"。
	for i in 4:
		var 列: Array = 期["页签"]
		if i >= 列.size():
			continue
		var 名2 := String(列[i][0])
		var 钮2 := 页.get_node_or_null(NodePath(名2)) as TextureButton
		if 钮2 != null and (钮2.stretch_mode != TextureButton.STRETCH_SCALE or not 钮2.ignore_texture_size):
			_报("%s 的画法是 %s/%s，期望 STRETCH_SCALE + ignore_texture_size（平铺会叠出第二条边）"
				% [名2, 钮2.stretch_mode, 钮2.ignore_texture_size])
		# 三态口径：`MTabButton.as:16-32` 的 over/down 是**同一张皮 + 滤镜**（StyleUtil up0/over+30/
		# down−40），Godot 只能换图 ⇒ 工程口径是换 `texture_normal` 本身（与底栏十钮同源）。
		# 用 texture_hover/pressed 实现会漏掉 `MButton3.as:103-108`「松手回 STATE_UP 不是 OVER」那档。
		if 钮2 != null and not 钮2.disabled:
			if 钮2.texture_hover != null or 钮2.texture_pressed != null:
				_报("%s 挂了 texture_hover/pressed ⇒ 松手后仍会亮，与原版松手回 up 不符（三态要换 texture_normal）" % 名2)
			if 钮2.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
				_报("%s 光标不是手型（MButton3.init():135 buttonMode + useHandCursor）" % 名2)
			var 基 := String((钮2.texture_normal as Texture2D).resource_path).get_file()
			页.call("_设态", 钮2, 1)
			var 悬 := String((钮2.texture_normal as Texture2D).resource_path).get_file()
			页.call("_设态", 钮2, 2)
			var 按 := String((钮2.texture_normal as Texture2D).resource_path).get_file()
			页.call("_设态", 钮2, 0)
			var 回 := String((钮2.texture_normal as Texture2D).resource_path).get_file()
			if 悬 != "页签未选_悬停.png" or 按 != "页签未选_按下.png" or 回 != 基:
				_报("%s 三态实际皮肤 = 悬停 %s / 按下 %s / 回档 %s，期望 悬停/按下 两张派生皮 + 回到 %s"
					% [名2, 悬, 按, 回, 基])
	# 选中枚（disabled）必须**不吃三态**：原版 `MTabButton.as:34-38` 选中 = enabled=false，
	# `updateState()` 走 DISABLED 分支、滤镜取 `skinFilters[STATE_UP]` = 0 ⇒ 不加亮也不换档。
	var 选 := 钮们[0] as TextureButton
	var 选前 := String((选.texture_normal as Texture2D).resource_path).get_file()
	页.call("_设态", 选, 1)
	页.call("_设态", 选, 2)
	if String((选.texture_normal as Texture2D).resource_path).get_file() != 选前:
		_报("选中页签被三态改了皮肤（disabled 那枚原版不加亮）")
	for i in [1, 2]:
		if (钮们[i] as TextureButton).disabled:
			_报("未选页签 %d 被置 disabled（会显示成选中皮）" % i)
	# 点「特殊设置」⇒ 换页、选中枚跟着变
	(钮们[2] as TextureButton).pressed.emit()
	if 主.visible or not 特.visible:
		_报("点特殊设置后没换页：主 %s 特 %s" % [主.visible, 特.visible])
	# .tscn 里**烘的** disabled 必须等于运行期开局真值（页=0 ⇒ 只有第 1 枚）：
	# 四枚全烘 true 的话，编辑器里四枚都显示选中皮，与实机不符（编辑器=运行期 那条硬规矩）。
	# ⚠ 只能读 .tscn 文本 —— `装配()` 里 `_摆层()` 会按 `_页` 重写 disabled，拿运行时值比等于自证自绿；
	#   而本函数跑在 `验层互斥` 之后，那时页已被点过一轮，更量不到设计位。
	var 景文 := FileAccess.get_file_as_string(场景)
	for i in (期["页签"] as Array).size():
		var 名0 := String((期["页签"] as Array)[i][0])
		var 块 := 景文.substr(景文.find('[node name="%s"' % 名0))
		# ⚠ 别用 `$`：.tscn 是 Windows 下写的，行尾是 \r\n ⇒ `$` 永远匹配不上（第一版就全报"没有 disabled 行"）
		var 匹 := RegEx.create_from_string("(?m)^disabled = (\\w+)").search(块.left(块.find("\r\n\r\n")))
		if 匹 == null:
			_报("%s 在 .tscn 里没有 disabled 行" % 名0)
			continue
		var 烘 := 匹.get_string(1) == "true"
		if 烘 != (i == 0):
			_报("%s 在 .tscn 里烘的 disabled=%s，运行期开局应是 %s（编辑器视图与实机不符）"
				% [名0, 烘, i == 0])
	if not (钮们[2] as TextureButton).disabled or (钮们[0] as TextureButton).disabled:
		_报("换页后 disabled 没跟着挪（选中皮会留在旧页签上）")
	(钮们[0] as TextureButton).disabled = false
	(钮们[0] as TextureButton).pressed.emit()
	# 快速键 = 开关式弹独立窗，不切页（SCW:264 → UM2:3133-3146）：
	# 通路是会话的 `request_feature("快捷键")`（→ 窗口管理.打开或收起），不是页内换页。
	(钮们[1] as TextureButton).pressed.emit()
	var 收: Array = (宿.get("_session") as Node).get("特性")
	if 收 != ["快捷键"]:
		_报("点快速键页签的开窗通路不对：会话收到 %s（期望 [快捷键]）" % 收)
	if not 主.visible:
		_报("点快速键把系统设置页关了（原版它不占页）")


## 勾选态必须来自假宿主的 game_settings（值与语义：勾选 = 写"勾选时写入"那个值）。
## 三层只能有一层可见（客户端层是工程自加的，泄漏过一次：宿主把它 visible 拉成真）
func 验层互斥(页: Control, 宿: Node) -> void:
	var 主 := 页.get_node("层主页") as Control
	var 特 := 页.get_node("层特页") as Control
	var 客 := 页.get_node("更多设置") as Control
	if not 主.visible or 特.visible or 客.visible:
		_报("开局层态不对：主 %s 特 %s 客户端 %s（期望只有主页可见）" % [主.visible, 特.visible, 客.visible])
	var 字 := 客.get_node("音乐面板/音量文字") as Label
	if 字.text == "音乐音量":
		_报("假宿主没填客户端层 ⇒ 这步演的是假过程（门验不到泄漏）")
	(页.get_node("页签客户端") as TextureButton).pressed.emit()
	if 主.visible or 特.visible or not 客.visible:
		_报("点客户端后层态不对：主 %s 特 %s 客户端 %s" % [主.visible, 特.visible, 客.visible])
	(页.get_node("页签系统设置") as TextureButton).disabled = false
	(页.get_node("页签系统设置") as TextureButton).pressed.emit()
	if not 主.visible or 客.visible:
		_报("从客户端切回系统设置后没收回：主 %s 客户端 %s" % [主.visible, 客.visible])


func 验勾选(页: Control, 宿: Node, 期: Dictionary) -> void:
	var 设: Dictionary = (宿.get("_session") as Node).get("game_settings")
	for 条 in (期["复选"] as Array):
		var 名 := String(条[0])
		var 项 := 页.get_node_or_null(NodePath("层主页/" + 名)) as Control
		if 项 == null:
			continue
		var 勾 := (项.get_node("标记") as CanvasItem).visible
		var 键 := String(条[5])
		var 写值 := bool(条[6])
		var 期望勾 := bool(设.get(键, not 写值)) if 写值 else not bool(设.get(键, true))
		if 勾 != 期望勾:
			_报("复选 %s 显示 %s ≠ 会话 %s=%s 推出来的 %s" % [名, 勾, 键, 设.get(键, "?"), 期望勾])
	# 点一枚 ⇒ 走宿主 _set_check 写回，值 = 「勾选时写入」
	var 写: Array = 宿.get("写")
	var 前 := 写.size()
	var 项2 := 页.get_node("层主页/复选遮罩其他玩家名字") as Control
	(项2.get_node("点击区域") as Button).pressed.emit()
	if 写.size() != 前 + 1:
		_报("点复选没走宿主写回出口（实得 %s）" % 写)
	elif String(写[前]) != "show_names=false":
		_报("点「遮罩其他玩家的名字资讯」应写 show_names=false，实得 %s" % 写[前])
	if (项2.get_node("点击区域") as Control).mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
		_报("复选点击区不是手型（原版 buttonMode）")


func 验音量(页: Control, 宿: Node, 期: Dictionary) -> void:
	var 条: Array = 期["音量"]
	var 行 := 页.get_node(NodePath("层特页/" + String((条[0] as Array)[0]))) as Control
	var 钮 := 行.get_node("钮滑块") as Control
	var 文 := 行.get_node("文标签") as Label
	var 轨 := 行.get_node("轨条") as ColorRect
	if absf(钮.position.x - (0.5 * 170.0 - 7.0)) > 容差:
		_报("音量滑块 x=%s ≠ v·170−7（music_volume=0.5）" % 钮.position.x)
	if not 文.text.ends_with("50%"):
		_报("音量标签没显示百分比：%s" % 文.text)
	if 轨.color != Color(0.2, 0.2, 0.2, 1):
		_报("轨道色 %s ≠ #333333（SCW:298-300）" % 轨.color)
	# 拖到 3/4 处 ⇒ 写回 sound/music 键并挪滑块
	var 事 := InputEventMouseButton.new()
	事.position = Vector2(170.0 * 0.75, 25.0)
	事.button_index = MOUSE_BUTTON_LEFT
	事.pressed = true
	行.gui_input.emit(事)
	if absf(钮.position.x - (170.0 * 0.75 - 7.0)) > 1.5:
		_报("拖动后滑块 x=%s ≠ 0.75·170−7" % 钮.position.x)
	var 写: Array = 宿.get("写")
	if 写.is_empty() or not String(写[写.size() - 1]).begins_with("music_volume="):
		_报("拖音量没走既有写回出口，实得 %s" % 写)


## 文案一律从语言表来（SPEC 里存的值就是按语言表解析的结果）——这里核场景落上去的文本逐字一致。
func 验文案(页: Control, 期: Dictionary) -> void:
	for 条 in (期["复选"] as Array):
		var 项 := 页.get_node_or_null(NodePath("层主页/" + String(条[0]))) as Control
		if 项 == null:
			continue
		if (项.get_node("文本") as Label).text != String(条[1]):
			_报("复选文案不符：%s ≠ %s" % [(项.get_node("文本") as Label).text, 条[1]])
	for 条 in (期["特页复选"] as Array):
		var 项 := 页.get_node_or_null(NodePath("层特页/" + String(条[0]))) as Control
		if 项 == null:
			continue
		if (项.get_node("文本") as Label).text != String(条[1]):
			_报("特页复选文案不符：%s ≠ %s" % [(项.get_node("文本") as Label).text, 条[1]])


## 22 行内联复选的**交互态接线**（#292 的④）。原版这一族 `MCheckBoxF`→`MButton3`：一组只有一张皮，
## 悬停 +30 / 按下 −40 是运行时加性滤镜（`StyleUtil.as:7-12`、`:43-47`），而且
## `createCheckBox(..., 2003199)` 走的是 `MButton3.as:444-451` 那个把 up/over/down/disabled
## **四档写成同一个数**的 `textColor` 设器 ⇒ 换态**不许**换字色。
## ⚠ 换档用 `emit_signal` 不用 `push_input`：这一层判的是"行根挂了组件脚本 + 四条信号接上 +
## 处理器把两张皮换成对的那张"这条**接线**；"鼠标真打得到这颗"由有头量具判
## （两处各判各的，缺一个只有半个结论 —— 记忆「行为门要吃真事件」）。
func 验复选态(页: Control, 期: Dictionary) -> void:
	var 数 := 0
	for 组 in [["复选", "层主页"], ["特页复选", "层特页"]]:
		for 条 in (期[String(组[0])] as Array):
			var 层 := String(组[1])
			var 名 := String(条[0])
			var 标 := "%s/%s" % [层, 名]
			var 件 := 页.get_node_or_null(NodePath(层 + "/" + 名)) as Control
			if 件 == null:
				_报("%s 运行期查无 ⇒ 这一行的交互态一条都没判" % 标)
				continue
			数 += 1
			var 钮 := 件.get_node_or_null("点击区域") as Button
			var 框 := 件.get_node_or_null("指示框") as TextureRect
			var 记 := 件.get_node_or_null("标记") as TextureRect
			var 字 := 件.get_node_or_null("文本") as Label
			if 钮 == null or 框 == null or 记 == null or 字 == null:
				_报("%s 四件不齐（点击区域/指示框/标记/文本）⇒ 组件脚本按名字认件，缺一件整行不接" % 标)
				continue
			var 脚: GDScript = 件.get_script()
			_判态(脚 != null and str(脚.resource_path) == 件脚本路, 标,
					"行根要挂 %s，实得 %s" % [件脚本路, "〈无〉" if 脚 == null else str(脚.resource_path)])
			for 信 in ["mouse_entered", "mouse_exited", "button_down", "button_up"]:
				var n := 钮.get_signal_connection_list(信).size()
				_判态(n == 1, 标, "`%s` 要**恰好一条**连接，实得 %d（0=状态机没跑；2=宿主又接一遍、一次换两档）" % [
						信, n])
			_判态(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, 标,
					"要手型光标（`MButton3.init()` `:135`）")
			var 勾初 := 记.visible
			var 色初 := 字.get_theme_color("font_color").to_html(false)
			_判态(_皮名(框) == "复选框未选.png" and _皮名(记) == "复选框选中.png", 标,
					"开跑两张皮都该是常态，实得 %s / %s" % [_皮名(框), _皮名(记)])
			_判态(str(框.texture.resource_path).begins_with(通用件目录), 标,
					"常态皮要走共享件 %s（`_悬停/_按下/_灰` 只烘在它旁边；指页私有那两张同名件 = 查不到派生皮、只能回落常态 = 这一行又是「点了没反应」），实得 %s" % [通用件目录, str(框.texture.resource_path)])
			钮.emit_signal("mouse_entered")
			_判态(_皮名(框) == "复选框未选_悬停.png" and _皮名(记) == "复选框选中_悬停.png", 标,
					"悬停 ⇒ 两张皮要**同档**一起换 _悬停（漏一张=勾亮框不亮），实得 %s / %s" % [
					_皮名(框), _皮名(记)])
			_判态(记.visible == 勾初, 标, "悬停不许改勾没勾（标记.visible %s → %s）" % [str(勾初), str(记.visible)])
			_判态(字.get_theme_color("font_color").to_html(false) == 色初, 标,
					"悬停不许换字色（原版四档同色），%s → %s" % [
					色初, 字.get_theme_color("font_color").to_html(false)])
			钮.emit_signal("button_down")
			_判态(_皮名(框) == "复选框未选_按下.png" and _皮名(记) == "复选框选中_按下.png", 标,
					"按下 ⇒ 应是 _按下，实得 %s / %s" % [_皮名(框), _皮名(记)])
			钮.emit_signal("button_up")
			_判态(_皮名(框) == "复选框未选.png", 标,
					"松手（鼠标还压着）要回 **STATE_UP = 常态**（`MButton3.as:103-108`），实得 %s" % _皮名(框))
			钮.emit_signal("mouse_exited")
			_判态(_皮名(框) == "复选框未选.png" and _皮名(记) == "复选框选中.png", 标,
					"移开 ⇒ 两张皮都回常态，实得 %s / %s" % [_皮名(框), _皮名(记)])
	_判态(数 == 22, "壬：量具自计到",
			"设置页该判满 22 行内联复选（层主页 16 + 层特页 6，10-19 普查），实得 %d ⇒ 少了就是期望表被删了行" % 数)


func _皮名(件: TextureRect) -> String:
	return "〈没图〉" if 件.texture == null else str(件.texture.resource_path.get_file())


func _判态(对: bool, 标: String, 话: String) -> void:
	if not 对:
		_报("%s：%s" % [标, 话])


func _报(话: String) -> void:
	_红 += 1
	print("!! " + 话)
