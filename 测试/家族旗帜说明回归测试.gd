extends SceneTree
## 家族旗帜「说明窗二选一」回归门（离线）。
##
## 钉的是原版 `FamillyManager.showFamillyFlagView`（`FM.as:832-843`）+
## `FamillyFlagHelpWindow.as`（`FFH`）：
##   * 没设过「下次跳过」→ 家族页点「家族旗帜」**先出说明窗**（`FFH` 那张 642×426 整图）；
##   * 勾上「下次跳过本说明界面」→ **落盘**；再点 → 直接出**旗帜窗**；
##   * 说明窗的「进入家族旗帜介面」→ 收起自己 + 开旗帜窗（`FFH:38-42 clickBtnHandler`）；
##   * 旗帜窗的「说明资讯」→ 开说明窗，且复选框态与落盘值一致（`FFH:50`）。
##
## ⚠️ 落盘键落在**真实**的 `user://玩家设置.json`（`游戏会话.update_setting`），
##    所以本门跑完必须把原值写回去 —— 否则跑一次门就等于替玩家勾了"以后别再弹说明"。
##
## 用法：Godot --headless --path . --script res://测试/家族旗帜说明回归测试.gd

const 壳 := preload("res://脚本/界面/窗口/家族/家族子窗壳.gd")
const 跳过键 := "family_flag_help_skip"
const 选中皮 := "res://素材/界面/原版窗口/通用控件/复选框选中.png"

var _失败: Array[String] = []
var _宿主: Node
var _会话: Node
var _原值
var _原本有没有这个键 := false
## 本门为了能开出旗帜窗，会把 `会话.guild` 临时改成"已入族"。收尾时必须**原样写回** ——
## 见 `_收尾` 里那段警告（2026-10-08 就是漏了这一步，把两条在线门一起弄红了）。
var _原家族 := {}
## 本门为了开旗帜窗会改 `guild` 并触发 `_save_local_state()` ⇒ 开场按字节快照、
## 收尾按字节还原（内存态写回 + 再存一次也做不到逐字节相同）。
const 门存档快照 := preload("res://测试/门存档快照.gd")
var _文件前 := {}


func _initialize() -> void:
	_文件前 = 门存档快照.全快照()
	call_deferred("_跑")


func _跑() -> void:
	_会话 = root.get_node_or_null("GameSession")
	if _会话 == null:
		_失败.append("没有 GameSession 单例")
		_收尾()
		return
	var 设: Dictionary = _会话.get("game_settings")
	_原本有没有这个键 = 设.has(跳过键)
	_原值 = 设.get(跳过键, false)
	# 护栏：这个键是**玩家自己的偏好**（勾过"下次跳过"就是 true）。跑门之前它若已经是 true，
	# 说明可能是**上一次跑门留下的**（最早那版门没有还原逻辑，把 true 落进了真实存档，
	# 后果是玩家的说明窗永远不再弹）—— 直接喊出来，别默默继承。
	if bool(_原值):
		push_warning("跑门前 `%s` 就是 true —— 可能是历史测试残留；本门收尾会把它还原成 true。"
			% 跳过键 + "要清掉请手动删这个键（默认 false = 不跳过）。")
	设[跳过键] = false		# 起点：没设过
	_原家族 = (_会话.get("guild") as Dictionary).duplicate(true)

	_宿主 = (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(_宿主)
	await create_timer(0.2).timeout
	# 置成"已入族"：旗帜那一套本来就是"有族才有意义"的（`_render_guild` 未入族时连主窗都藏）。
	_会话.set("guild", {"joined": true, "id": 7, "name": "木叶测试族", "level": 1,
		"leader": "测试", "flag_name": "木叶", "flag_style": 1000, "member_list": []})
	_宿主.call("open_page", "家族")
	await create_timer(0.2).timeout

	# ── ① 第一次：应当出**说明窗**，而不是旗帜窗 ────────────────────────
	_宿主.call("_show_guild_action", "家族旗帜")
	await create_timer(0.2).timeout
	if not _已开("家族旗帜帮助窗"):
		_失败.append("第一次点「家族旗帜」没弹出说明窗（应二选一选到说明窗）")
		_收尾()
		return
	if _已开("家族旗帜窗"):
		_失败.append("说明窗和旗帜窗同时开了（应只出说明窗）")
		_收尾()
		return
	var 框 := _帮助窗框()
	if 框 == null:
		_失败.append("说明窗里没有「复选跳过/框」")
		_收尾()
		return
	if String(框.texture.resource_path) == 选中皮:
		_失败.append("说明窗复选框初始就是选中的（落盘值是 false，应未选）")
	# ── ② 勾上「下次跳过本说明界面」→ 必须落盘 ──────────────────────────
	# 走的就是那颗复选框的派发路径（`家族子窗._翻复选` 先翻皮、再发动作）。
	_勾跳过()
	await create_timer(0.2).timeout
	var 设2: Dictionary = _会话.get("game_settings")
	if not bool(设2.get(跳过键, false)):
		_失败.append("勾了「下次跳过」但没落盘（game_settings[%s] 还是 false）" % 跳过键)
	# ── ③ 说明窗的「进入家族旗帜介面」→ 收自己 + 开旗帜窗 ────────────────
	# 走真实流程：说明窗就靠这颗钮退场（原版 `FFH:38-42`）。
	_宿主.call("_show_guild_action", "家族旗帜帮助窗:进入旗帜")
	await create_timer(0.2).timeout
	if _已开("家族旗帜帮助窗"):
		_失败.append("「进入家族旗帜介面」没收起说明窗")
	if not _已开("家族旗帜窗"):
		_失败.append("「进入家族旗帜介面」没开出旗帜窗")
	# ── ④ 关掉旗帜窗，再点家族页的「家族旗帜」→ 这次该**直接**进旗帜窗 ──
	_宿主.call("_show_guild_action", "家族旗帜")
	await create_timer(0.2).timeout		# 先把它收掉（开窗表是开关式的）
	_宿主.call("_show_guild_action", "家族旗帜")
	await create_timer(0.2).timeout
	if _已开("家族旗帜帮助窗"):
		_失败.append("设过跳过之后还是弹了说明窗")
	if not _已开("家族旗帜窗"):
		_失败.append("设过跳过之后没有直接开旗帜窗")
	# ── ⑤ 旗帜窗的「说明资讯」→ 开说明窗，且复选框必须是**选中**态 ────────
	_宿主.call("_show_guild_action", "家族旗帜窗:说明资讯")
	await create_timer(0.2).timeout
	if not _已开("家族旗帜帮助窗"):
		_失败.append("旗帜窗的「说明资讯」没开出说明窗")
	var 框2 := _帮助窗框()
	if 框2 != null and String(框2.texture.resource_path) != 选中皮:
		_失败.append("「说明资讯」开出来的说明窗，复选框没跟落盘值对上（应选中）")
	if _已开("家族旗帜帮助窗"):
		壳.关掉(_宿主, "家族旗帜帮助窗")
		await create_timer(0.25).timeout

	# ── ⑥ 底部三颗钮的**兜底点击**（用户 2026-10-09 报的"最下方三个按钮点不动"）──
	#
	# ⚠️ 这一段必须走 `功能窗口._input()` 喂**合成鼠标按下**，不能再用
	#    `_show_guild_action(...)` 或 `pressed.emit()` —— 那两条都**绕过命中判定**，
	#    正是它们让这个 bug 在门里藏了这么久。
	#    实机 F9 现场数据：光标在钮矩形内、钮是最上层、事件到了 `_input` 且未被处理，
	#    但 Godot 的 GUI 命中把这一点判给了**页面根**，钮收不到 `gui_input`/`pressed`。
	#    兜底就是在 `_input` 里自己做矩形命中并补发 `pressed`（见 `功能窗口._兜底旗帜钮`）。
	await _试兜底点击("钮说明资讯", "家族旗帜帮助窗", "说明窗")
	if _已开("家族旗帜帮助窗"):
		壳.关掉(_宿主, "家族旗帜帮助窗")
		await create_timer(0.25).timeout
	await _试兜底点击("钮安插本族旗帜", "家族确认弹", "安插确认弹")
	if _已开("家族确认弹"):
		壳.关掉(_宿主, "家族确认弹")
		await create_timer(0.25).timeout

	_收尾()


## 对一颗钮喂一次**合成鼠标按下**（走 `功能窗口._input` 那条真路径），断言某个窗开出来了。
func _试兜底点击(钮名: String, 应开的窗: String, 说明: String) -> void:
	var 页: Control = 壳.取内容(_宿主, "家族旗帜窗")
	if 页 == null:
		_失败.append("旗帜窗不在了，测不了「%s」的兜底点击" % 钮名)
		return
	var 钮 := 页.get_node_or_null(钮名) as TextureButton
	if 钮 == null:
		_失败.append("旗帜窗里找不到「%s」" % 钮名)
		return
	if 钮.disabled:
		# ⚠️ 本门是**离线**的，合成会话里"是不是族长"未必成立 ⇒ 安插/修复被正确置灰是正常的。
		#    灰着就跳过（"灰得对不对"由 `家族条件口径回归测试` 与在线门负责），别误报。
		print("  （跳过「%s」：离线合成会话里它是灰的，属正常）" % 钮名)
		return
	var 点 := 钮.get_global_rect().get_center()
	var 事件 := InputEventMouseButton.new()
	事件.button_index = MOUSE_BUTTON_LEFT
	事件.pressed = true
	事件.position = 点
	事件.global_position = 点
	事件.button_mask = 1
	_宿主.call("_input", 事件)
	await create_timer(0.3).timeout
	if not _已开(应开的窗):
		_失败.append("在「%s」中心 %s 喂一次鼠标按下，%s 没开出来 ⇒ 兜底点击没生效"
			% [钮名, str(点), 说明])


func _已开(窗名: String) -> bool:
	return 壳.已开(_宿主, 窗名)


func _帮助窗框() -> TextureRect:
	var 页: Control = 壳.取内容(_宿主, "家族旗帜帮助窗")
	return 页.get_node_or_null("复选跳过/框") as TextureRect if 页 != null else null


## 模拟玩家点那颗复选框：`家族子窗._翻复选` 是先翻皮、再派发动作。
func _勾跳过() -> void:
	var 页: Control = 壳.取内容(_宿主, "家族旗帜帮助窗")
	if 页 == null:
		_失败.append("说明窗内容页取不到")
		return
	var 勾 := 页.get_node_or_null("复选跳过") as Control
	if 勾 == null:
		_失败.append("说明窗里没有「复选跳过」")
		return
	var 事件 := InputEventMouseButton.new()
	事件.button_index = MOUSE_BUTTON_LEFT
	事件.pressed = true
	勾.gui_input.emit(事件)


func _收尾() -> void:
	# 把真实设置与家族状态写回去（见文件头那条警告）。
	if _会话 != null:
		# ⚠️⚠️ 家族状态**必须在这里、且必须在 `update_setting` 之前还原**：
		#    本门为了开旗帜窗把 `会话.guild` 改成了"已入族"，而 `update_setting` 会顺手
		#    `_save_local_state()` —— 那一下会把**合成出来的假家族**（木叶测试族 id=7）
		#    写进真实的 `user://玩家数据.json`。之后任何在线用例一启动就 `_load_local_state()`
		#    读到"主角色已入族"，于是「商城买族书」报"没入族就画出了家族页"、
		#    「家族申请加入」报"前提不成立：主角色一开始就已经在家族里了" ——
		#    2026-10-08 就是这么同时弄红两条在线门的，排查时极易带偏方向。
		_会话.set("guild", _原家族)
		# 落盘键只在"玩家真的勾过"时才有意义 ⇒ **还原成 false 就把它删掉**。
		# ⚠️ 别用"这次跑之前有没有这个键"来判：第一次跑门会把它建出来，
		#    第二次跑就误判成"原来就有"，于是测试在玩家存档里永久留一个 default 键。
		var 还原值 := bool(_原值) if _原本有没有这个键 else false
		_会话.call("update_setting", 跳过键, 还原值)
		if not 还原值:
			(_会话.get("game_settings") as Dictionary).erase(跳过键)
			_会话.call("_save_local_state")
	# 文件级还原放在最后：`_save_local_state()` 重写的字节与原档不必一致。
	门存档快照.全还原(_文件前)
	if _失败.is_empty():
		print("家族旗帜说明回归测试：通过（首次弹说明 → 勾跳过落盘 → 再点直进旗帜窗 → 说明资讯带选中态 → 进入旗帜收窗）")
		quit(0)
		return
	for 条 in _失败:
		print("  !! " + 条)
	print("家族旗帜说明回归测试：FAIL %d 条" % _失败.size())
	quit(1)
