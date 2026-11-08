## 「点任务 ⇒ 出剧情、交易等按钮一概不出现」这门。
##
## 用户 2026-10-09 的原话：「你没有做任务的信息面，点击任务后的面板应该是出现剧情信息
## 并且隐藏交易等按钮」。他给的三张实机图里，上格是 NPC 台词、下格是**一行绿色玩家回应**，
## 左边那排「物品交易 / 离开」**不在**。
##
## 原版这不是"hide"，是**分叉**：`QuestDialog.drawView():393-399`
##   `if (data.hasOwnProperty("text")) createPlayerTextArea(); else createSelection();`
## ⇒ 有 `text` 这条分支**根本不建**菜单行与任务链接块；点下格 =
## `clickPlayerSaidHandler():137-145` 发 `57:NEXT:1` 翻下一句。
## 本机服务端的文本桥把 `text` 放在 **328 帧第 4 段 `playerText`**
## （`_send_npc_dialog` / `_send_authored_quest_dialog` 把 GameData 的「NPC台词 @ 玩家回应」拆开）。
##
## 本门两头都判：① 源码分叉与几何常量照 AS3；② **运行期真开窗**，喂两种数据，
## 断言「有回应时菜单行数=0、回应可见、下格高按公式」与「无回应时回应隐藏」。
extends SceneTree

const 窗 := preload("res://脚本/界面/窗口/NPC对话窗.gd")
const HUD路 := "res://脚本/界面/小地图面板.gd"

var _失败: Array[String] = []
var _条数 := 0


func _initialize() -> void:
	call_deferred("_run")


func _断言(成立: bool, 说明: String) -> void:
	_条数 += 1
	if not 成立:
		_失败.append(说明)


func _找(根: Node, 名: String) -> Node:
	if String(根.name) == 名:
		return 根
	for 子 in 根.get_children():
		var 找 := _找(子, 名)
		if 找 != null:
			return 找
	return null


func _可见行(件: Node) -> int:
	var 数 := 0
	for 行 in 件.get_children():
		if String(行.name).begins_with("行") and (行 as Control).visible:
			数 += 1
	return 数


func _run() -> void:
	## ── ① 源码形状 ──────────────────────────────────────────────
	var 窗源 := FileAccess.get_file_as_string("res://脚本/界面/窗口/NPC对话窗.gd")
	_断言(窗源.contains("func 显示(npc编号: int, npc名: String, 台词: String, 菜单: Array, 选择: Array = [], 回应 := \"\") -> void:"),
			"显示 没有 回应 参数 ⇒ 原版 data.text 那条分支传不进来")
	var 显段 := _截(窗源, "func 显示(", "\nfunc ")
	_断言(显段.contains("if 回应 != \"\":") and 显段.contains("_排回应(回应)"),
			"显示 里没有 回应 分支 ⇒ 剧情面永远画不出来")
	_断言(显段.contains("_排行([])") and 显段.contains("_排选择([], 0)"),
			"剧情分支没把菜单/选择清空 ⇒ 会「剧情 + 交易按钮」同屏（正是用户打回的样子）")
	_断言(显段.contains("_藏回应()"), "非剧情分支没藏回应 ⇒ 上一句的剧情会留在下一屏")
	_断言(窗源.contains("const 回应块底 := 40.0"), "下格高增量应为 40（`:411` height + 40）")
	_断言(窗源.contains("const 台词x := 25.0"), "回应块 x 应与台词同 = 25（`:409`）")
	_断言(窗源.contains("const 下格最少 := 74"), "下格最小高应为 74（MIN_PLAYER_SAID_HEIGHT）")
	_断言(窗源.contains("Vector2(台词宽, 回应行高 * 回应行数(文本))"),
			"回应块宽应为 456（`:407` 上格宽 − 50）并按行数算高")
	_断言(窗源.contains("MOUSE_FILTER_IGNORE") and 窗源.contains("_下格.mouse_filter = Control.MOUSE_FILTER_STOP"),
			"热区应是**整个下格**（原版 skin 上挂 CLICK），文字本身不吃鼠标")

	var HUD := FileAccess.get_file_as_string(HUD路)
	_断言(HUD.contains('get("player_text", "")'), "HUD 没读 328 第 4 段 ⇒ 剧情面数据被解出来却没人用")
	_断言(HUD.contains("回应 == \"-\""), "`-` 是服务端「没有可选回应」的记号，要当空处理")
	var 开段 := _截(HUD, "func show_npc_dialog", "\nfunc ")
	## ⚠️ 2026-10-15 并分支：`_dialog_name/_dialog_text` 已按 master 那边改成**普通 String**
	##    （§3.106 把那两个 Label 节点连同子树从场景里删了，`小地图面板.gd` 只把值当台词源读），
	##    所以这里不再有 `.text`。判的仍然是**同一条行为**：有回应就空菜单 + 空选择 + 直接返回。
	_断言(开段.contains("_对话.显示(int(npc_id), _dialog_name, _dialog_text, [], [], 回应)")
			and 开段.contains("return"),
			"有回应时没走「空菜单 + 空选择 + 直接返回」⇒ 下面那堆兜底菜单会被凑出来")
	## 关键：兜底造菜单那两段必须在 回应 之后，否则剧情屏还是会长出「离开」
	var 位回应 := 开段.find("if 回应 != \"\":")
	_断言(位回应 >= 0 and 位回应 < 开段.find("if 菜单.is_empty():"),
			"剧情分支排在兜底菜单之后 ⇒ 顺序反了，交易/离开还是会画出来")

	## ── ② 运行期真开窗，两种数据各开一次 ────────────────────────
	var 宿主 := Control.new()
	root.add_child(宿主)
	var 件 := 窗.new()
	宿主.add_child(件)
	await process_frame
	await process_frame

	件.显示(9, "浅野婆婆", "听老头子说，暗部救回你之后，醒来你就失忆了，对吗？", [], [], "我会用心记住婆婆的话的。")
	await process_frame
	var 下 := _找(件.根(), "下格") as Control
	var 回应件 := _找(件.根(), "回应") as Control
	_断言(下 != null and 回应件 != null, "剧情模式下找不到下格或回应块")
	if 下 != null and 回应件 != null:
		_断言(回应件.visible, "回应块没显示")
		_断言(_可见行(下.get_node("菜单")) == 0, "剧情模式下菜单行还可见 ⇒ 用户打回的就是这个")
		var 行: int = 窗.回应行数("我会用心记住婆婆的话的。")
		_断言(absf(下.size.y - maxf(74.0, 行 * 17.0 + 40.0)) < 0.01,
				"下格高应 = max(74, 行×17+40)，实际 %.0f（%d 行）" % [下.size.y, 行])
		_断言(absf(回应件.position.x - 25.0) < 0.01, "回应块 x 应为 25，实际 %.0f" % 回应件.position.x)
		_断言(absf(回应件.position.y - (下.size.y - 回应件.size.y) * 0.5) < 0.01,
				"回应应在下格内垂直居中（`:413`）")
		_断言(String(回应件.text).contains("[color=#00ff00]"), "玩家回应应是 #00ff00（`:405`）")
		_断言(String(回应件.text).contains("我会用心记住婆婆的话的。"), "回应文案没原样进块")

	# 无回应 ⇒ 回到菜单分支，回应必须藏起来
	件.显示(9, "浅野婆婆", "想要点儿什么？我的手艺非常不赖哦！", [["物品交易", 100], ["离开", -1]])
	await process_frame
	if 回应件 != null:
		_断言(not 回应件.visible, "切回菜单模式后回应还可见 ⇒ 上一句剧情会留在这一屏")
	if 下 != null:
		_断言(_可见行(下.get_node("菜单")) == 2, "菜单模式应画出 2 行，实际 %d" % _可见行(下.get_node("菜单")))
	_断言(String(件.行文字表()[0]) == "物品交易", "菜单行文案应是服务端给的那句")

	## ③ 行现在是**复用**的（空菜单只藏不删）⇒ 必须"先摘干净再接"，否则第二次开窗会撞
	## `gui_input is already connected`。⚠ **这条只能判源码**：Godot 自己会拒重复连接，
	## 运行期数出来永远是 1，拿连接数当判据是**假判据**（写第一版时我就差点这么干）。
	_断言(窗源.contains("func _接行点击(行: Control, 序: int) -> void:"),
			"没有 _接行点击 这个「先摘再接」的收口")
	_断言(not 窗源.contains("行.gui_input.connect(_点行.bind(i))"),
			"_排行 里还在裸 connect ⇒ 复用行时第二次开窗会报 already connected")
	_断言(窗源.contains("_接行点击(行, i)"), "_排行 没走 _接行点击")

	宿主.queue_free()
	_finish()


func _截(文: String, 起: String, 止: String) -> String:
	var a := 文.find(起)
	if a < 0:
		return ""
	var b := 文.find(止, a + 起.length())
	return 文.substr(a, b - a) if b > 0 else 文.substr(a)


func _finish() -> void:
	if _失败.is_empty():
		print("任务剧情面回归测试：通过（%d 条）" % _条数)
		quit(0)
		return
	for 条 in _失败:
		printerr(条)
	print("任务剧情面回归测试：共 %d 条，红 %d 条" % [_条数, _失败.size()])
	quit(1)
