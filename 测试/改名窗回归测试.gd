extends SceneTree

## 「角色改名」窗离线门（#240 未收口第 2 条，2026-10-16）。
##
## 参照值全部手抄自原版 `ChangeNameWindow.as`（逐行号写进下面每条判据里），
## **不从被测场景反查、不从截图量**。坐标换算：窗是 `UIWindow(300,320,true)`，
## 页标了 `整框: true` ⇒ 页局部 y = AS3 y − 29（拖动区高）。
##
## 覆盖：① 尺寸表那一条 ② 自己模式逐件矩形 + 七件都在 + 输入框 12 字上限
## ③ 别人模式藏七件（**取消钮不藏**）+ 历史名两行上移 82 + 标题换「X 的历史名字」
## ④ 开窗的是**回帧**（走真的 `窗口管理._on_改名回帧`，不是测试自己 open_page）
## ⑤ 列表排版：8 行一列、按列跳取、`N.名字` 垫两空格、空表「暂无历史名字」
## ⑥ 「确定」三道本地拦截（真 `push_input` 点，不是 `.emit()`）+ 过了才发 `2330:1`
## ⑦ 名字那颗「改」两条语义（自己=开窗+发 10 / 别人=只发 12:<名> / 离线=说话且不发）
## ⑧ 三态钮皮（normal/hover/pressed 三张真皮 + 手型光标）
## ⑨ 改名卡持有数：参照值由门自己按夹具算，不许问被测对象要
## ⑩ 结果 0 关窗、结果 1 **不关也不重复提示**（失败原因是服务端另一条动态提示给的）
## ⑪ 门不许动存档。
##
## 跑法：`Godot --headless --path . --script res://测试/改名窗回归测试.gd`
## ⚠ 本门 2026-10-25（§3.280）才登记进 `开发工具/验证全部.ps1` 的 `$testsBase64` ——
##   文件早就写好了、清单里没有它 ⇒ 全量跑批一直**没跑过它**（清单 170 → 171，全量 172）。

const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 尺寸表路径 := "res://数据/界面/窗口尺寸.json"
const 改名窗 := preload("res://脚本/界面/窗口/人物/改名窗.gd")
const 人物窗口 := preload("res://脚本/界面/窗口/人物窗口.gd")
const 页根名 := "原版改名窗内容"
const 存档 := "user://玩家数据.json"

## §②③ 逐件矩形 [x, y, 宽, 高]（**页局部** = AS3 − 29）。AS3 出处逐件标在注释里。
## 四枚文字件（提示文/拥有数/新名字标题/历史名标题）原版是 `MGlowLabel` 自动宽 ⇒ 只判 x,y。
const 件表 := {
	"改名卡格": [18.0, 19.0, 40.0, 40.0],			# `_contentBg.x+10, _contentBg.y+10` = (18,48) `:180`
	"购买钮": [23.0, 67.0, 37.0, 22.0],			# `itemCell.x+5, itemCell.y+48` = (23,96) `:195-196`
	"新名字输入": [128.0, 66.0, 110.0, 24.0],		# `nameLabel.x+60, nameLabel.y-3` = (128,95)，`setSize(110,24)` `:209-213`
	"历史名文": [18.0, 126.0, 264.0, 0.0],		# `_contentBg.x+10, historyLabel.y+25` = (18,155)，宽 = `_contentBg.width-20` = 264 `:227-228`
	"确定钮": [50.0, 264.0, 37.0, 22.0],			# `x=50, y=_height-27` = (50,293) `:238-239`
	"取消钮": [220.0, 264.0, 37.0, 22.0],			# `x=_width-80` = 220，y 同确定 `:245-246`
	"提示文": [68.0, 24.0],					# `itemCell.x+50, itemCell.y+5` = (68,53) `:186`
	"拥有数": [68.0, 42.0],					# `itemCell.x+50, tipLabel.y+18` = (68,71) `:190`
	"新名字标题": [68.0, 69.0],					# `itemCell.x+50, itemCell.y+50` = (68,98) `:206`
	"历史名标题": [18.0, 101.0],					# `_contentBg.x+10, nameInput.y+35` = (18,130) `:222`
}
## 「别人模式」要藏的七件（`setOtherPlayerMode:90-117` 逐件对照；**`_cancelBtn` 不在这一串里**）
const 别人藏 := ["新名字输入", "新名字标题", "确定钮", "购买钮", "改名卡格", "提示文", "拥有数"]
## 历史名那两行在别人模式整体上移的量（`:120` 与 `:124` 都是 `- 82`）
const 上移 := 82.0
const 钮常态 := "确定钮.png"
const 钮悬停 := "确定钮_悬停.png"
const 钮按下 := "确定钮_按下.png"

var 通过 := 0
var 失败 := 0
var 跑完了 := false
var 帧数 := 0
var 通知: Array = []
var 管: Node = null
var 窗: Node = null
var 假后: Node = null
var 存档前 := PackedByteArray()


## 只记不发。`功能窗口._backend` 声明成 `Node` ⇒ 假对象必须也是 Node。
## `authoritative_inventory` 是真的背包镜像形状（一条一格，键 `id` / `quantity`，
## 出处 `后端连接._parse_item_list:4193-4196`）⇒ `功能窗口.改名卡数()` 直接读它。
class 假后端 extends Node:
	var 发的: Array = []
	var in_game := true
	var authoritative_inventory: Array = []
	func request_history_names() -> bool:
		发的.append(["查自己历史名"]); return true
	func request_other_history_names(名: String) -> bool:
		发的.append(["查历史名", 名]); return true
	func request_change_name(新名: String) -> bool:
		发的.append(["改名", 新名]); return true


## `功能窗口._通知()` 是 `_session.notification_requested.emit(文本)` ⇒ 假对象必须**带这个信号**，
## 而且必须是 Node（`_session` 声明成 Node）。没有它，凡是走 `_通知` 的那几道会当场报错。
class 假会话 extends Node:
	signal notification_requested(文本: String)


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 话)


func _字节() -> PackedByteArray:
	if not FileAccess.file_exists(存档):
		return PackedByteArray()
	var f := FileAccess.open(存档, FileAccess.READ)
	return f.get_buffer(f.get_length())


## 看门狗：门里任何一处运行期报错都会让协程半路断掉 ⇒ `quit()` 永远轮不到、
## 无头进程挂着不出红（工程已栽过）。约 90 秒到点就老实认红。
func _process(秒: float) -> bool:
	帧数 += 1
	if 帧数 > 5400 and not 跑完了:
		print("红：门超时未跑完（约 90 秒），后面的判据没执行")
		print("改名窗门：通过 %d，红 %d" % [通过, 失败 + 1])
		quit(1)
		return true
	return false


func _initialize() -> void:
	await process_frame
	## 存档基线要在**单例启动之后**取：跨天首次启动时 `游戏会话._reset_daily_quests_if_needed()`
	## 会按日重置并落一次盘（产品行为，不是本门写的）。基线取在启动前 ⇒ 每天第一次跑都假红。
	存档前 = _字节()
	await _跑()
	if not 跑完了:
		失败 += 1
		print("红：门自己没跑完（协程中途报错），汇总行没打出来")
	print("改名窗门：通过 %d，红 %d" % [通过, 失败])
	quit(1 if 失败 > 0 else 0)


func _页() -> Control:
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	for 子 in 内容.get_children():
		if String(子.name) == 页根名:
			return 子 as Control
	return null


func _标题() -> String:
	var 题 = 窗.get("_title")
	return "" if 题 == null else String((题 as Label).text)


func _开着() -> bool:
	if 窗 == null:
		return false
	var 遮 = 窗.get("_overlay")
	return 遮 != null and (遮 as CanvasItem).visible


func _屏心(件: Control) -> Vector2:
	return 件.get_global_rect().position + 件.size * 0.5


## 无头里视口图每帧被显示服务打回 64×64 ⇒ **每次推输入前**都要重新钉一次，
## 且钉与推之间不许有 await（否则等到的那一帧又变回 64×64，屏外的点拾取不到）。
func _钉() -> void:
	root.size = Vector2i(960, 560)


func _移开() -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = Vector2(-400, -400)
	移.global_position = Vector2(-400, -400)
	_钉()
	root.push_input(移)


func _移到(件: Control) -> void:
	var 屏 := _屏心(件)
	var 移 := InputEventMouseMotion.new()
	移.position = 屏
	移.global_position = 屏
	_钉()
	root.push_input(移)


## 真点一次：**先把鼠标移上去、等一帧建立 hover，再按再放**。
## 少了那一帧的话，第一下会被"抢焦点/窗口拖动"吃掉（实测：同一颗钮第一次点没反应、
## 第二次才生效 ⇒ 门会把"没点着"读成"没拦截"，报出假红）。
func _点(件: Control) -> void:
	_移到(件)
	await process_frame
	var 屏 := _屏心(件)
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 屏
	按.global_position = 屏
	_钉()
	root.push_input(按)
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 屏
	放.global_position = 屏
	_钉()
	root.push_input(放)


func _等(帧: int = 3) -> void:
	for i in 帧:
		await process_frame


## 用真的回帧消费者开一次窗（`结果` 10=自己 / 12=别人）。
func _喂(结果: int, 消息: String, 名单: PackedStringArray = PackedStringArray()) -> void:
	管.call("_on_改名回帧", 结果, 消息, 名单)
	await _等(6)


func _跑() -> void:
	# ── ① 尺寸表那一条 ────────────────────────────────────────────────
	_判(改名窗 != null and 人物窗口 != null,
			"① 两份控制器都能 preload（拿不到 ⇒ 整份 功能窗口.gd 会 parse 失败、开窗类门全挂）")
	var 文本 := FileAccess.get_file_as_string(尺寸表路径)
	var 解: Dictionary = JSON.parse_string(文本)
	var 规: Dictionary = (解.get("角色改名", {}) as Dictionary)
	_判(not 规.is_empty(), "① 尺寸表有「角色改名」这一条（没有 ⇒ 开窗会回落成人物窗 517×440）")
	_判(float(规.get("宽", 0)) == 300.0 and float(规.get("高", 0)) == 320.0,
			"① 外框 300×320 = `ChangeNameWindow.as:54` `super(300,320,true)`（实得 %s×%s）"
			% [str(规.get("宽", 0)), str(规.get("高", 0))])
	_判(bool(规.get("内容底", false)),
			"① `内容底: true` = 第三个构造参数 `drawContentBg` ⇒ 外壳要在 (8,38) 画 284×252")
	_判(bool(规.get("整框", false)),
			"① `整框: true`（直接子件最小 y = 卡格 48，落在 36~40 那一段之上 ⇒ 页按外框坐标画）")
	_判(String(规.get("标题", "")) == "角色改名",
			"① 标题 = `:65` 的字面量「角色改名」（实得「%s」）" % String(规.get("标题", "")))

	# ── 建宿主：窗口管理 + 假后端 ──────────────────────────────────────
	管 = (load(管理场景) as PackedScene).instantiate()
	root.add_child(管)
	await _等(6)
	假后 = 假后端.new() as Node
	root.add_child(假后)
	窗 = 管.call("取或建窗口", "角色改名")
	_判(窗 != null, "① 能取到「角色改名」那个宿主实例")
	if 窗 == null:
		跑完了 = true
		return
	窗.set("_backend", 假后)
	var 假会 := 假会话.new() as Node
	root.add_child(假会)
	窗.set("_session", 假会)
	(假会 as Node).connect("notification_requested", func(文本2: String) -> void: 通知.append(文本2))

	# ── ② 自己模式：逐件矩形 + 七件都在 ────────────────────────────────
	var 名单 := PackedStringArray(["甲一", "甲二"])
	await _喂(10, "我自己", 名单)
	_判(_开着(), "② 收到 `2330:10` 那一帧 ⇒ 窗自己开出来了（不是靠点出来的）")
	var 页 := _页()
	_判(页 != null, "② 页根「%s」建出来了" % 页根名)
	if 页 == null:
		跑完了 = true
		return
	for 名 in 件表:
		var 件 := 页.get_node_or_null(String(名)) as Control
		if 件 == null:
			_判(false, "② 页上缺件：%s" % String(名))
			continue
		var 参: Array = 件表[名]
		var 实 := [件.position.x, 件.position.y, 件.size.x, 件.size.y]
		if 参.size() == 2:
			_判(absf(实[0] - float(参[0])) < 0.51 and absf(实[1] - float(参[1])) < 0.51,
					"② 「%s」在 (%s,%s)（实得 %.1f,%.1f）" % [名, str(参[0]), str(参[1]), 实[0], 实[1]])
		else:
			var 对 := absf(实[0] - float(参[0])) < 0.51 and absf(实[1] - float(参[1])) < 0.51 \
					and (float(参[2]) <= 0.0 or absf(实[2] - float(参[2])) < 0.51) \
					and (float(参[3]) <= 0.0 or absf(实[3] - float(参[3])) < 0.51)
			_判(对, "② 「%s」矩形 %s（实得 %.1f,%.1f,%.1f,%.1f）" % [名, str(参), 实[0], 实[1], 实[2], 实[3]])
	for 名 in 别人藏:
		_判((页.get_node(String(名)) as Control).visible, "② 自己模式「%s」该在（`resetToNormalMode:129-167`）" % String(名))
	_判(_标题() == "角色改名", "② 自己模式标题「角色改名」（实得「%s」）" % _标题())
	var 输入 := 页.get_node("新名字输入") as LineEdit
	_判(输入 != null and 输入.max_length == 12,
			"② 输入框 `maxChars=12`（`createInputArea:211`；实得 %d）" % (0 if 输入 == null else 输入.max_length))
	_判(输入 != null and 输入.text == "", "② 开窗时输入框是空的（`refreshData:253` 每次清）")

	# ── ③ 别人模式：藏七件 + 两行上移 + 换标题 ──────────────────────────
	await _喂(12, "社交同伴", PackedStringArray(["旧甲", "旧乙"]))
	var 页2 := _页()
	_判(页2 != null, "③ 别人模式也重画出了页")
	if 页2 == null:
		跑完了 = true
		return
	for 名 in 别人藏:
		_判(not (页2.get_node(String(名)) as Control).visible,
				"③ 别人模式「%s」该隐（`setOtherPlayerMode:90-117`）" % String(名))
	_判((页2.get_node("取消钮") as Control).visible,
			"③ **取消钮不许藏** —— 原版那一串里没有 `_cancelBtn`（`:98-117` 只关输入/标签/确定/购买/格/两条提示）")
	_判(absf((页2.get_node("历史名标题") as Control).position.y - (float(件表["历史名标题"][1]) - 上移)) < 0.51,
			"③ 历史名标题上移 82 ⇒ y=%.1f（实得 %.1f）" % [float(件表["历史名标题"][1]) - 上移,
					(页2.get_node("历史名标题") as Control).position.y])
	_判(absf((页2.get_node("历史名文") as Control).position.y - (float(件表["历史名文"][1]) - 上移)) < 0.51,
			"③ 历史名列表上移 82 ⇒ y=%.1f（实得 %.1f）" % [float(件表["历史名文"][1]) - 上移,
					(页2.get_node("历史名文") as Control).position.y])
	_判(_标题() == "社交同伴 的历史名字",
			"③ 标题 = `:126` 的「<名字> 的历史名字」（实得「%s」）" % _标题())
	_判(String((页2.get_node("历史名文") as RichTextLabel).text).contains("1.旧甲"),
			"③ 名单填进来了（实得「%s」）" % String((页2.get_node("历史名文") as RichTextLabel).text).replace("\n", "\\n"))

	# ── ⑤ 列表排版（原版 `setHistoryNames:272-301`：8 行一列、按列跳取）──
	var 十一: Array[String] = []
	for i in 11:
		十一.append("名%d" % (i + 1))
	var 排 := 改名窗.排历史名(PackedStringArray(十一))
	var 行0 := 排.split("\n")[0]
	_判(行0 == "1.名1  9.名9  ",
			"⑤ 第 1 行是「1.名1  9.名9  」（两列、列内跳 8 取；实得「%s」）" % 行0)
	_判(排.split("\n")[1] == "2.名2  10.名10  ",
			"⑤ 第 2 行「2.名2  10.名10  」（实得「%s」）" % 排.split("\n")[1])
	_判(排.split("\n").size() == 9,
			"⑤ 恒 8 行 + 结尾一个空段 ⇒ 9 段（实得 %d）" % 排.split("\n").size())
	_判(改名窗.排历史名(PackedStringArray()) == "暂无历史名字",
			"⑤ 空表 ⇒「暂无历史名字」（`:299`，实得「%s」）" % 改名窗.排历史名(PackedStringArray()))

	# ── ⑨ 卡数：参照值门自己算 ───────────────────────────────────────
	假后.authoritative_inventory = []
	_判(int(窗.call("改名卡数")) == 0, "⑨ 背包空 ⇒ 0 张（实得 %d）" % int(窗.call("改名卡数")))
	假后.authoritative_inventory = [
		{"id": 改名窗.改名卡号, "quantity": 3},
		{"id": "101", "quantity": 9},
		{"id": 改名窗.改名卡号, "quantity": 1}]
	_判(int(窗.call("改名卡数")) == 4, "⑨ 两张改名卡格（3+1）⇒ 4 张，别把别的物品也数进来（实得 %d）"
			% int(窗.call("改名卡数")))
	await _喂(10, "我自己", 名单)
	var 页3 := _页()
	_判(页3 != null and String((页3.get_node("拥有数") as Label).text) == "当前拥有:4",
			"⑨ 拥有数那一行 = `:261` 的「当前拥有:%d」（实得「%s」）" % [4,
					"" if 页3 == null else String((页3.get_node("拥有数") as Label).text)])
	var 拥色 := (页3.get_node("拥有数") as Label).get_theme_color("font_color")
	_判(拥色 == Color("#00ff00"), "⑨ 有卡是绿字（`:264` UI_GREEN；实得 %s）" % str(拥色))
	假后.authoritative_inventory = []
	await _喂(10, "我自己", 名单)
	页3 = _页()
	var 拥色2 := (页3.get_node("拥有数") as Label).get_theme_color("font_color")
	_判(拥色2 == Color("#ff0000"), "⑨ 没卡转红字（`:268` UI_RED；实得 %s）" % str(拥色2))

	# ──  三态钮皮 + 手型 ────────────────────────────────────────────
	for 钮名 in ["确定钮", "取消钮", "购买钮"]:
		var 钮 := 页3.get_node(钮名) as Button
		if 钮 == null:
			_判(false, "⑧ 缺钮：%s" % 钮名)
			continue
		var 三 := {"normal": 钮常态, "hover": 钮悬停, "pressed": 钮按下}
		var 全对 := true
		for 态 in 三:
			var 箱 := 钮.get_theme_stylebox(态)
			var 径 := ""
			if 箱 is StyleBoxTexture and (箱 as StyleBoxTexture).texture != null:
				径 = String((箱 as StyleBoxTexture).texture.resource_path)
			if not 径.ends_with(三[态]):
				全对 = false
				print("   %s/%s → %s（该是 %s）" % [钮名, 态, 径.get_file(), 三[态]])
		_判(全对, "⑧ 「%s」三档各挂各的真皮（normal/hover/pressed = 确定钮{,_悬停,_按下}.png）" % 钮名)
		_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
				"⑧ 「%s」是手型光标（`MButton3.init():135` buttonMode/useHandCursor）" % 钮名)

	# ── ⑥ 「确定」三道本地拦截（真点）──────────────────────────────────
	假后.发的 = []
	通知.clear()
	var 确定 := 页3.get_node("确定钮") as Button
	_判(确定.pressed.get_connections().size() == 1,
			"⑥ 确定钮只挂了一只处理器（实得 %d 只；多只=重复渲染没清）" % 确定.pressed.get_connections().size())
	# 卡数 0 时先测前两道（顺序与原版一致：空名 → 长度 → 卡数）
	假后.authoritative_inventory = [{"id": 改名窗.改名卡号, "quantity": 1}]
	await _喂(10, "我自己", 名单)
	页3 = _页()
	确定 = 页3.get_node("确定钮") as Button
	var 输入2 := 页3.get_node("新名字输入") as LineEdit
	假后.发的 = []
	通知.clear()
	await _点(确定)
	await _等(3)
	_判(通知.size() == 1 and String(通知[0]) == "请输入新名字！",
			"⑥ 空名 ⇒ 只说「请输入新名字！」且不发包（`:313-317`；实得 %s / 发 %s）" % [str(通知), str(假后.发的)])
	输入2.text = "一"
	通知.clear(); 假后.发的 = []
	await _点(确定)
	await _等(3)
	_判(通知.size() == 1 and String(通知[0]) == "名字长度需要2-12个字符！",
			"⑥ 1 个字 ⇒「名字长度需要2-12个字符！」（`:318-322`；实得 %s）" % str(通知))
	输入2.text = "一二三四五六七八九十一二三"
	_判(输入2.text.length() == 12,
			"⑥ 敲 13 个字**进不来** —— 输入框自己截到 12（`:211` `maxChars=12` ⇒ `LineEdit.max_length=12`），"
			+ "所以 `:318-322` 那道「>12」的分支与原版一样是够不到的（实得 %d 字）" % 输入2.text.length())
	通知.clear(); 假后.发的 = []
	await _点(确定)
	await _等(3)
	_判(假后.发的 == [["改名", "一二三四五六七八九十一二"]],
			"⑥ 发出去的是**截断后的那 12 个字**（不是我想塞的 13 个；实得 %s）" % str(假后.发的))
	输入2.text = "新名字二"
	假后.authoritative_inventory = []
	通知.clear(); 假后.发的 = []
	await _点(确定)
	await _等(3)
	_判(通知.size() == 1 and String(通知[0]) == "改名卡不足！",
			"⑥ 没卡 ⇒「改名卡不足！」，**客户端自己就拦了**、不发出去让服务端拒（`:323-327`；实得 %s）" % str(通知))
	_判(假后.发的.is_empty(), "⑥ 四道拦截里一次都没发包（实发 %s）" % str(假后.发的))
	假后.authoritative_inventory = [{"id": 改名窗.改名卡号, "quantity": 1}]
	通知.clear(); 假后.发的 = []
	await _点(确定)
	await _等(3)
	_判(假后.发的 == [["改名", "新名字二"]],
			"⑥ 三道都过 ⇒ 发 `2330:1:新名字二`（实得 %s）" % str(假后.发的))
	_判(通知.is_empty(), "⑥ 发成功不额外提示（原版只在拦截那三道说话；实得 %s）" % str(通知))

	# ── ⑦ 名字那颗「改」两条语义 ─────────────────────────────────────
	(窗 as Node).set("_他人档案", {"名": "社交同伴"})
	假后.发的 = []; 通知.clear()
	人物窗口._改名钮被点(窗, true)
	await _等(2)
	_判(假后.发的 == [["查历史名", "社交同伴"]],
			"⑦ 只读时点「改」⇒ 发 `2330:12:<对方名>`（**按名字不按号**，`CharPane.as:327-330`；实得 %s）"
			% str(假后.发的))
	_判(通知.is_empty(), "⑦ 发出去了就不再多嘴一句（实得 %s）" % str(通知))
	假后.in_game = false
	假后.发的 = []; 通知.clear()
	人物窗口._改名钮被点(窗, true)
	await _等(2)
	_判(假后.发的.is_empty() and 通知.size() == 1,
			"⑦ 离线点「改」⇒ 一帧不发、只说一句（实发 %s / 说 %s）" % [str(假后.发的), str(通知)])
	假后.in_game = true
	假后.发的 = []; 通知.clear()
	人物窗口._改名钮被点(窗, false)
	await _等(4)
	_判(假后.发的 == [["查自己历史名"]],
			"⑦ 自己那态点「改」⇒ 发 `2330:10`（`show():59-69` 里 `refreshData():251-256`）；实得 %s"
			% str(假后.发的))
	_判(_标题() == "角色改名" and _开着(),
			"⑦ 点完窗是开着的、标题回到「角色改名」（实得「%s」开着=%s）" % [_标题(), str(_开着())])

	# ── ⑩ 结果 0 关窗 / 结果 1 不关也不重复提示 ────────────────────────
	await _喂(10, "我自己", 名单)
	_判(_开着(), "⑩ 先确认窗是开的（下面两档才有对照）")
	通知.clear()
	await _喂(1, "该名字已被使用")
	_判(_开着(), "⑩ 结果 1（失败）⇒ **不关窗**（原版 `handleChangeNameResult:130-168` 对 1 没有分支）")
	_判(通知.is_empty(), "⑩ 结果 1 也不由客户端再报一句（原因那条动态提示服务端已经发过 ⇒ 双提示就是自造）；实得 %s"
			% str(通知))
	await _喂(0, "新名字二")
	_判(not _开着(), "⑩ 结果 0（改名成功）⇒ 摘窗（`:141` `removeWindow(ChangeNameWindow)`）")

	# ──  关掉再收 12 那一发：窗能重新开出来（同一个实例换模式）─────────
	await _喂(12, "社交同伴", PackedStringArray(["旧甲"]))
	_判(_开着() and _标题() == "社交同伴 的历史名字",
			"④ 同一扇窗从「自己」切到「别人」：能重开、标题跟着换（实得「%s」）" % _标题())
	await _喂(10, "我自己", 名单)
	_判(_标题() == "角色改名",
			"④ 再切回来 ⇒ 标题回「角色改名」（不切回来就是**上一发的名字挂在下一扇上**；实得「%s」）" % _标题())
	var 页4 := _页()
	for 名 in 别人藏:
		_判((页4.get_node(String(名)) as Control).visible, "④ 切回自己模式「%s」又出现了" % String(名))

	# ── ⑪ 门不许动存档 ───────────────────────────────────────────────
	_判(_字节() == 存档前, "⑪ 全程没写 user://玩家数据.json（字节要一致）")
	# 顺带把改名卡的图标取没取到说一句 —— 取不到就是**缺料**，别让它静默空白
	var 图标 := (页4.get_node("改名卡格/改名卡图标") as TextureRect).texture
	print("提示：改名卡(%s)图标 %s" % [改名窗.改名卡号, "取到了" if 图标 != null else "**没取到 ⇒ 缺料**"])

	跑完了 = true
