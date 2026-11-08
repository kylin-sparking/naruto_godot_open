extends SceneTree

## 漩涡鸣人「跨服频道」（原版 `kuafu/KuaFuChannelWindow` 595×451）的**行为门**。
##
## 逐件几何不在这里 —— `测试/原版服务窗回归测试.gd` 已经把 101 件逐个比
## `数据/界面/跨服频道_期望.json`，而且它会**重跑生成器**比对场景（手改 .tscn 立刻红）。
## 这里量的是那一族门看不见的事：
##   ① **只有 32 枚格**（`:195-197` 那个 `if (channleIndex == 32) break` 让第 11 行只建两枚）
##      ⇒ 谁"顺手补齐成 33"这里就红；第 33 格连节点都不许存在。
##   ② **离线 32 枚全是禁用灰态**（`setData:138-145` 先给每枚一个 int ⇒
##      `SelectedChannelCell.kuaFuData:57-61` 走「（维护）」#717068 + `drawState:106-109`
##      把**频道名也**染成 #717068）⇒ 这是原版真身，不是"没数据就空着"。
##   ③ **三档状态色含等号边界**：`<=0.7` 通畅 / `<=0.99` 良好 / 否则 爆满
##      ⇒ 喂 70 与 99 这两格专门钉等号（0.70 归通畅、0.99 归良好）。
##   ④ **互斥选中**（`selectedChannel:98-109`）+ 禁用格不吃鼠标 + 双击 = 选 + 进入。
##   ⑤ **两颗钮的客户端闸门**：进入要过 `isCheckLevel:224-235`（**只有号 > 27 才卡 60~80 级**）；
##      刷新 20 秒内再点 = **原版静默什么都不做**（`refreshHandler:237-245`）⇒ 这条最容易被
##      "顺手加一句提示"改掉。
##   ⑥ **一条主动偏离钉在这里**：没选任何格就点进入，原版 `isCheckLevel()` 会先读
##      `_currentCell.channleIndex` ⇒ **抛 #1009、监听器中途死掉**，那句
##      「请选择跨服服务器」其实是死代码。这边选择实现"意图"（弹那句），
##      并在门里写明它是偏离，不是照抄 —— 谁改成"什么都不弹"也要知道原因。
##   ⑦ **编辑器 == 运行期**：32 枚的 `disabled = true` / `toggle_mode = true` /
##      禁用槽指回常态皮（库里 disabledSkin 与 upSkin 同一个 charId 652）都读 `.tscn` 文本。
##   ⑧ **不落存档**：跑前记 `user://玩家数据.json` 字节、跑完断言没变
##      （门里要临时改 `_session.player_stats.level` 过等级闸门 ⇒ 只改内存，不碰 `存档.保存()`）。
##   ⑨ **两条上行真发**（10-23 接上）：开窗拉列表 `1825:0`、进场 `1825:1:<号>` + 关窗 ⇒
##      离线拿不到出帧，所以**装一枚假后端**只接管「出帧那半边」（同 伊鲁卡三窗门 §3.121 那套），
##      记的是**方法名 + 实参**，不是"我确实调过"。刷新那 20 秒节流也改成数**发没发**，
##      不再数通知文案（原版成功那一支一句提示都不弹）。
##   ⑩ **回帧原文整条回环**：把本机服务端 `handle_war_panel_action:21070-21072` 的**真帧原文**
##      `1825:0:1&忍界战场&0:100` 喂进**真后端** `_handle_bridge_text` ⇒ 解码 → `war_panel_received`
##      → 页里原地塞数。再喂一条「少掉几行」的第二帧 ⇒ 钉 `setData:138-145` 那个
##      **「先把 32 枚全打回维护、再用列表覆盖」**（上一轮放开的枚这一轮没数据必须退回灰），
##      以及 `:153-157`「选中的那枚掉回 int ⇒ 取消选中」。
##      ⚠ 多行用 `@` 连是**本工程文本桥的约定**（同 `SERVERLIST 145`，服务端 `:15071`），
##        本机服务端 cmd 0 只回**一行** ⇒ 多行那一档只有门喂得到。
##
## 运行：Godot --headless --path . --script res://测试/跨服频道页回归测试.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 页名 := "跨服频道"
const 场景路 := "res://场景/界面/窗口/跨服/跨服频道窗.tscn"
const 控制器 := preload("res://脚本/界面/窗口/跨服频道窗.gd")

const 格数 := 32
const 色常态 := Color(0.988235, 0.956863, 0.611765)		# #FCF49C
const 色禁用 := Color(0.443137, 0.439216, 0.407843)		# #717068
const 色通畅 := Color(0, 1, 0)
const 色良好 := Color(1, 0.568627, 0)
const 色爆满 := Color(1, 0, 0)
## 夹具里那六行的期望（`数据/界面/跨服频道_夹具.json`，maxLoad = 100）
const 喂后 := [[1, "通畅", 色通畅], [3, "通畅", 色通畅], [5, "良好", 色良好], [6, "爆满", 色爆满],
		[28, "通畅", 色通畅]]
const 未放开 := [7, 10, 27, 32]		# 夹具里没有的号 ⇒ 喂完仍必须是灰「（维护）」禁用
## 全程该判满的条数（不含最后那条「判满」本身）。跑出来的末行「判 N 条」= 应判 + 1。
const 应判 := 53

## 假后端：**只接管出帧那半边**（同 伊鲁卡三窗门 §3.121）。方法名与真后端逐字同名 ⇒
## 窗里 `后.call("request_war_panel_enter", 号)` 照原样打进来；记的是**实参**，不是"调过没调"。
## 带一枚同名信号，好让「回帧 → 原地塞数」那一支也能从这枚假后端走。
class 假后端:
	extends Node
	signal war_panel_received(列表: Array, 最大载入: int)
	var in_game := true
	var 列表次数 := 0
	var 进场: Array = []

	func request_war_panel_list() -> bool:
		列表次数 += 1
		return true

	func request_war_panel_enter(号: int) -> bool:
		进场.append(号)
		return true


var 场景: Node
var 管: Node
var 假: 假后端
var 真后: Node
var 红数 := 0
var 日志: Array[String] = []
var 通知记录: Array[String] = []
var 存档前 := ""
var 鼠位 := Vector2.ZERO
## 夹具（`数据/界面/跨服频道_夹具.json`）解出来的两份，回帧与上行两段都要用它喂数
var 夹列: Array = []
var 夹载 := 0
## 每段开头记下"到这儿为止一共判了几条"，段末再要求判满 —— 协程被运行期报错打断时，
## 后面整段一条都没跑，末行却照样打「红 0 项」（第 四十三~四十七 种假绿）。
var 判数 := 0


func _记(过: bool, 文: String) -> void:
	判数 += 1
	if not 过:
		红数 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 文])


func _等(n: int) -> void:
	for _i in range(n):
		await process_frame


func _尾通知() -> String:
	return 通知记录[通知记录.size() - 1] if not 通知记录.is_empty() else ""


func _清通知() -> void:
	通知记录.clear()


func _窗() -> Node:
	return 管._窗口们.get(页名) as Node


func _页() -> Control:
	var 窗 := _窗()
	if 窗 == null:
		return null
	var 出: Control = null
	for 子 in (窗.get_node("遮罩/主窗口/页面容器") as Control).get_children():
		if 子 is Control:
			出 = 子 as Control
	return 出


func _格(页: Control, 号: int) -> Button:
	return 页.get_node("频道列表/频道格%d" % 号) as Button


func _态(页: Control, 号: int) -> Label:
	return 页.get_node("频道列表/频道格%d/频道格%d态" % [号, 号]) as Label


func _名(页: Control, 号: int) -> Label:
	return 页.get_node("频道列表/频道格%d/频道格%d名" % [号, 号]) as Label


## 分两跳移进目标：同帧连发两条 MouseMotion 视口只按最后一条做拾取 ⇒
## 大距离瞬移不触发 `mouse_entered`（`flash-mbutton3-state-skins` 坑①）。
func 悬停(位置: Vector2) -> void:
	var 中 := (鼠位 + 位置) * 0.5
	var 移 := InputEventMouseMotion.new()
	移.position = 中
	移.global_position = 中
	root.push_input(移)
	鼠位 = 中
	await _等(2)
	移 = InputEventMouseMotion.new()
	移.position = 位置
	移.global_position = 位置
	root.push_input(移)
	鼠位 = 位置
	await _等(3)


func 点(位置: Vector2) -> void:
	await 悬停(位置)
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 位置
	按.global_position = 位置
	root.push_input(按)
	await _等(2)
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 位置
	放.global_position = 位置
	root.push_input(放)
	await _等(3)


func 点钮(钮: Control) -> void:
	await 点(钮.get_global_rect().get_center())


## 真发一次**双击**（第二次按下带 `double_click = true`，与 Godot 自己合成的一致）
func 双击(位置: Vector2) -> void:
	await 悬停(位置)
	for 次 in 2:
		var 按 := InputEventMouseButton.new()
		按.button_index = MOUSE_BUTTON_LEFT
		按.pressed = true
		按.button_mask = MOUSE_BUTTON_MASK_LEFT
		按.double_click = (次 == 1)
		按.position = 位置
		按.global_position = 位置
		root.push_input(按)
		await _等(1)
		var 放 := InputEventMouseButton.new()
		放.button_index = MOUSE_BUTTON_LEFT
		放.pressed = false
		放.double_click = (次 == 1)
		放.position = 位置
		放.global_position = 位置
		root.push_input(放)
		await _等(1)
	await _等(3)


func _存档字节() -> String:
	var f := FileAccess.open("user://玩家数据.json", FileAccess.READ)
	return "" if f == null else f.get_as_text()


## 取 `.tscn` 里某个节点自己的属性块（到下一个 `[node ` 为止）—— 烘值只能读文本。
func _节(文: String, 名: String) -> String:
	var 头 := 文.find("[node name=\"%s\"" % 名)
	if 头 < 0:
		return ""
	var 尾 := 文.find("[node ", 头 + 10)
	return 文.substr(头, 尾 - 头) if 尾 > 头 else 文.substr(头)


func _设等级(值: int) -> void:
	var 会 = root.get_node_or_null("/root/GameSession")
	if 会 != null:
		(会.get("player_stats") as Dictionary)["level"] = 值


func 已开() -> bool:
	var 窗 = _窗()
	return 窗 != null and bool(窗.call("已打开"))


## 重开一扇：`打开()` 会 `_render_page()` ⇒ 32 枚又回到**烘进场景的那一帧**（全禁用「（维护）」），
## 所以 `喂 = true` 时必须再发一次列表把那几枚放开，否则后面"真点格"点的是禁用件 = 静默没点着。
## 开窗那一次 `1825:0` 也由这里触发（`功能窗口.gd:打开()` 里 `page_name == "跨服频道"` 那一支）。
func _重开(喂: bool) -> void:
	控制器.新会话()
	var 窗 = _窗()
	if 窗 != null:
		窗.call("close")
	await _等(2)
	管.call("打开", 页名)
	await _等(4)
	var 窗2 = _窗()
	if 窗2 != null:
		(窗2.get_node("遮罩/主窗口") as Control).position = Vector2(8.0, 8.0)
	if 喂 and not 夹列.is_empty():
		假.emit_signal("war_panel_received", 夹列, 夹载)
	await _等(2)


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)		# ⚠ 不钉这个，无头视口拿不到 GUI 命中 ⇒ 点了静默不生效
	存档前 = _存档字节()
	var 会 = root.get_node_or_null("/root/GameSession")
	if 会 != null and 会.has_signal("notification_requested"):
		会.notification_requested.connect(func(文本: String) -> void: 通知记录.append(文本))
	真后 = root.get_node_or_null("/root/BackendConnection")
	假 = 假后端.new()
	root.add_child(假)
	控制器.新会话()
	场景 = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _等(6)
	管 = 场景.get_node_or_null("窗口管理")
	if 管 == null:
		收尾("地图场景下没有 窗口管理")
		return
	var 夹: Dictionary = 控制器.读夹具()
	夹列 = 夹.get("列表", []) as Array
	夹载 = int(夹.get("maxLoad", 0))
	管.call("全部关闭")
	管.call("打开", 页名)
	await _等(5)
	# 先把窗挪到左上角：`窗口管理` 按已开数量错开摆位，595×451 在 960×560 视口里
	#   可能被推到下沿之外 ⇒ 第 9/10 行那 5 枚格的矩形中心**在屏外**，真 `push_input` 点了等于没点。
	# ⚠ 2026-10-06：这一页先前那三条红**不是**屏外，而是「窗口画在聊天面板之上、命中却被它吃掉」
	#   （嵌套 CanvasLayer 的 GUI 拾取只比各自那个 `layer` 数，不加父层）
	#   ⇒ 已就地修在 `窗口管理.gd:重排层级`。挪窗只解决"在屏外"那一类，别把它当成那条的替身修法。
	var 窗0 = _窗()
	if 窗0 != null:
		(窗0.get_node("遮罩/主窗口") as Control).position = Vector2(8.0, 8.0)
		await _等(3)
	await _量开窗()
	await _量离线格()
	await _量静态件()
	await _量回帧()
	await _量选中()
	await _量上行()
	await _量刷新节流()
	await _量烘值()
	收尾()


func 收尾(致命: String = "") -> void:
	if 致命 != "":
		日志.append("!! %s" % 致命)
		红数 += 1
	var 现 := _存档字节()
	_记(现 == 存档前, "跑完 `user://玩家数据.json` **字节没变**（门里改了 player_stats.level，"
			+ "那只活内存；落盘会让邻居门次日假红）")
	if 现 != 存档前:
		日志.append("   ⇒ 说明这一族按钮里有支会写档：查 `_set_check` / `存档.保存()` 的调用链")
	_记(判数 == 应判, ("**全程判满 %d 条**（实测 %d）⇒ 没有哪一段协程被运行期报错打断、"
			+ "也没有哪一段提前 return（第 四十三~四十七 种那族：断在半路末行照样打「红 0 项」）")
			% [应判, 判数])
	for 一 in 日志:
		print(一)
	print("跨服频道页回归：%s（判 %d 条 / 红 %d 项）" % ["通过" if 红数 == 0 else "不通过", 判数, 红数])
	quit(1 if 红数 > 0 else 0)


## ──  开窗：外框 451（不是 414）+ 内容底用默认顶 38 ─────────────────────────
func _量开窗() -> void:
	日志.append("=== 开窗（595×451，标题「选择跨服频道」）===")
	var 窗 := _窗()
	_记(窗 != null, "落地页「%s」开出来了（鸣人 00000012 菜单行 = 动作值 18 WAR）" % 页名)
	if 窗 == null:
		return
	var 页 := _页()
	_记(页 != null and String(页.name) == "原版跨服频道内容", "页根 = %s" % (页.name if 页 != null else "无"))
	if 页 == null:
		return
	_记(String(窗._title.text) == "选择跨服频道",
			"标题是「选择跨服频道」（`:250` KUAFU_CHANNEL_TITLE）——**不是**菜单行文字「跨服忍界大战」，实测「%s」" % 窗._title.text)
	_记(absf(窗._window.size.x - 595.0) < 0.6 and absf(窗._window.size.y - 451.0) < 0.6,
			"外框 595×**451**（`:39` 是 414，但 `newView:65` `setSize(595,451)` ⇒ 玩家看到的稳态是 451），实测 %.0f×%.0f"
			% [窗._window.size.x, 窗._window.size.y])
	var 底: Control = 窗._content_bg as Control
	_记(底 != null and bool(底.visible) and absf(底.position.y - 38.0) < 0.6
			and absf(底.size.x - 579.0) < 0.6 and absf(底.size.y - 383.0) < 0.6,
			"内容底 (8,38) 579×383 —— 这扇**不调** setContentBgPos ⇒ 顶仍是默认 38（护送那两扇才是 30），实测 %s %s"
			% [str(底.position) if 底 != null else "无", str(底.size) if 底 != null else "无"])


## ── ② 离线 32 枚：数量 / 摆位 / 全禁用 / 名与态都是灰 ────────────────────────
func _量离线格() -> void:
	日志.append("=== 离线 32 枚频道格（int 分支 = 原版真身，不是空态）===")
	var 页 := _页()
	var 列: Array = (页.get_node("频道列表") as Control).get_children()
	_记(列.size() == 格数,
			"**只有 %d 枚**格（`:195-197` 的 `if (channleIndex == 32) break` 让第 11 行只建两枚 ⇒ 10×3+2），实测 %d"
			% [格数, 列.size()])
	var 位对 := true
	var 灰对 := true
	var 禁对 := true
	for 号 in range(1, 格数 + 1):
		var 格 := _格(页, 号)
		var 行 := int((号 - 1) / 3)
		var 列号 := (号 - 1) % 3
		var 想y := float(行 * 30 + (37 if 号 > 27 else 17))
		if absf(格.position.x - float(列号 * 190)) > 0.6 or absf(格.position.y - 想y) > 0.6 \
				or absf(格.size.x - 180.0) > 0.6 or absf(格.size.y - 26.0) > 0.6:
			位对 = false
		if _名(页, 号).get_theme_color(&"font_color") != 色禁用 \
				or _态(页, 号).get_theme_color(&"font_color") != 色禁用:
			灰对 = false
		if not bool(格.disabled) or bool(格.button_pressed):
			禁对 = false
	_记(位对, "格 i 在 (列*190, 行*30 + (号>27 ? 37 : 17))、180×26（`:185-186`+`:194`+`newView:76-88`）")
	_记(灰对, "频道名与状态文字**都是 #717068**（`drawState:106-109` 在 enabled=false 时把 nameLabel 也染色）")
	_记(禁对, "32 枚全 disabled、无一枚 pressed（`kuaFuData:58` int 分支）")
	var 维护对 := true
	for 号 in range(1, 格数 + 1):
		if _态(页, 号).text != "（维护）":
			维护对 = false
	_记(维护对, "状态文字逐字 = KUAFU_WEIHU「（维护）」×32")
	var 名对 := true
	for 号 in range(1, 格数 + 1):
		var 想 := "跨服频道 " + ("%02d" % 号 if 号 < 10 else str(号))
		if _名(页, 号).text != 想:
			名对 = false
	_记(名对, "频道名逐字 = KUAFU_SERVER_NAME + 号（<10 补一个 0）⇒「跨服频道 01」…「跨服频道 32」")
	# 离线点一枚禁用格 ⇒ 原版 removeEvent()（drawState:109）⇒ 什么都不会发生
	_清通知()
	await 点钮(_格(页, 5))
	_记(控制器.选中().is_empty(), "离线真点一枚禁用格 ⇒ **选中态没变**（禁用件不吃鼠标，与原版 removeEvent 同）")


## ── ③ 两枚绿字头 + 两颗钮 ───────────────────────────────────────────────────
func _量静态件() -> void:
	日志.append("=== 两枚绿字头 / 两颗钮 ===")
	var 页 := _页()
	var 头 := 页.get_node("频道名头") as Label
	var 级 := 页.get_node("等级名头") as Label
	_记(头.text == "跨服战场频道:" and 级.text == "60级--80级跨服战场：",
			"两条头**逐字**（一条半角冒号、一条全角冒号，原版就是这么不一致），实测「%s」「%s」" % [头.text, 级.text])
	_记(头.get_theme_color(&"font_color") == Color(0, 1, 0) \
			and 级.get_theme_color(&"font_color") == Color(0, 1, 0),
			"两条头都是 UI_GREEN #00ff00（`:72`/`:93`）")
	_记(absf(头.position.x - 18.0) < 0.6 and absf(头.position.y - 14.0) < 0.6 \
			and absf(级.position.y - 304.0) < 0.6,
			"头在 (18,43) / (18,333) ⇒ 整框页 −29 = (18,14)/(18,304)。⚠ 第二个 y 是 `:92` 拿 **list 局**的 " +
			"cells[27].y+height = 333 直接摆到**窗口**上（坐标系用混了才落在行8与行9之间）⇒ 照抄不许修正")
	var 进 := 页.get_node("进入钮") as Button
	var 刷 := 页.get_node("刷新钮") as Button
	_记(进.text == "进入跨服战场" and 刷.text == "刷新", "两颗钮文字逐字（KUAFU_JINRUKUAFUZHANCHANG / DEFFOR_DESINATION_REFURBISH）")
	_记(absf(进.position.x - 256.5) < 0.6 and absf(进.size.x - 82.0) < 0.6 \
			and absf(进.position.y - 395.0) < 0.6,
			"进入钮 (256.5,424) 82×22 ⇒ 场景 y 395（`btn_width_six` = 82、`(595−82)/2`、`451−22−5`；用 414 会低 37px）")
	_记(absf(刷.position.x - 550.0) < 0.6 and absf(刷.size.x - 37.0) < 0.6,
			"刷新钮 (550,424) 37×22（`btn_width_two` = 37、`595−37−8`）")


## ── ⑩ `1825:0` 真帧原文 → 真后端解码 → 页里原地塞数（不拆页）─────────────────
func _量回帧() -> void:
	日志.append("=== 喂服务端真帧原文 ⇒ 整条回环（解析 → 信号 → 原地塞数）===")
	var 页 := _页()
	var 页id0 := 页.get_instance_id()
	_记(not 夹列.is_empty() and 真后 != null,
			"读到夹具 %s（%d 行、maxLoad=%d）且真后端在位 ⇒ 这一段能量" % [控制器.夹具路径, 夹列.size(), 夹载])
	if 夹列.is_empty() or 真后 == null:
		收尾("前置就没成（夹具或真后端缺）⇒ 后面的段都没跑")
		return
	# ① 本机服务端 cmd 0 的**逐字原文**（`fake_flash_server.py:21070-21072`
	#    `f"{op}:0:1&忍界战场&{在线}:100"`）⇒ 这一条钉的是「客户端读法对得上服务端」，不是自己拼串。
	真后.call("_handle_bridge_text", "1825:0:1&忍界战场&0:100")
	await _等(2)
	var 现页 := _页()
	_记(现页 != null and 现页.get_instance_id() == 页id0,
			"喂完一帧 ⇒ **页还是同一枚实例**（#312 那一族：回帧拆页会让按住的两下落到已释放的件上 ⇒ 整页点不动），"
			+ "实例号 %s → %s" % [str(页id0), str(现页.get_instance_id()) if 现页 != null else "无"])
	_记(_态(页, 1).text == "通畅" and not bool(_格(页, 1).disabled),
			"真帧原文那一行解出来了 ⇒ 1 号放开禁用、状态「通畅」（`load=0 / maxLoad=100`），实测「%s」" % _态(页, 1).text)
	# ② 多行（`@` 连 = **本工程文本桥的约定**，同 `SERVERLIST 145` 服务端 `:15071`；
	#    本机服务端 cmd 0 从不发第二行 ⇒ 这一档只有门喂得到，别当成抓到的真帧）。
	真后.call("_handle_bridge_text", _多行帧())
	await _等(2)
	var 档对 := true
	for 行 in 喂后:
		var 格 := _格(页, int(行[0]))
		var 态 := _态(页, int(行[0]))
		if 态.text != String(行[1]) or 态.get_theme_color(&"font_color") != (行[2] as Color) \
				or bool(格.disabled) or _名(页, int(行[0])).get_theme_color(&"font_color") != 色常态:
			档对 = false
	_记(档对, "喂后 1/3/5/6/28 号 = 通畅/通畅/良好/爆满/通畅 且放开禁用、名回 #FCF49C"
			+ "（**70 与 99 是 `<=0.7` / `<=0.99` 两个含等号的边界格**）")
	var 灰对 := true
	for 号 in 未放开:
		if _态(页, 号).text != "（维护）" or not bool(_格(页, 号).disabled):
			灰对 = false
	_记(灰对, "夹具里没有的 7/10/27/32 号**仍是灰「（维护）」+ 禁用**（没被顺手放开）")
	var 名没改 := true
	for 行 in 喂后:
		var 号 := int(行[0])
		if _名(页, 号).text != "跨服频道 " + ("%02d" % 号 if 号 < 10 else str(号)):
			名没改 = false
	_记(名没改, "频道名**不**被数据覆盖 —— `kuaFuData` 分支只在开头写「跨服频道 NN」，" +
			"覆盖名的是另一个 setter `channelData:87-105`（这扇窗不用它）⇒ 别拿 WarChannelInfo.name 去改文案")
	# ③ 选中的那枚在新帧里掉回 int ⇒ `setData:153-157` 要替玩家把选中取消（否则会"选中一枚维护格"，
	#    而原版 `enterBattleHandler:119` 拿的是 `_currentCell.channelData.channel_id` ⇒ 那一下是崩）
	# ⚠ 阳性对照先走一遍：**上一帧确实把 3 号放开了**，下面那条"退回维护"才不是在比两个同样的烘态。
	#   （第 十四/十五 种那族：夹具不覆盖分支 ⇒ 判据"0 比 0"恒真。）
	_记(not bool(_格(页, 3).disabled) and _态(页, 3).text == "通畅",
			"喂多行帧之后 3 号**确实被放开了**（阳性对照，实测 disabled=%s 态=%s）"
			% [str(_格(页, 3).disabled), _态(页, 3).text])
	真后.call("_handle_bridge_text", "1825:0:1&忍界战场&0:100")
	await _等(2)
	_记(_态(页, 3).text == "（维护）" and bool(_格(页, 3).disabled) \
			and _态(页, 5).text == "（维护）" and bool(_格(页, 5).disabled) \
			and not bool(_格(页, 1).disabled),
			"再喂回那一行 ⇒ 上一轮放开的 3/5 号**退回「（维护）」+ 禁用**、这一轮有的 1 号仍放开"
			+ "（这一条才钉住 `setData:138-145` 那圈「先把 32 枚全打回维护、再用列表覆盖」）")
	await 点钮(_格(页, 3))
	_记(控制器.选中().is_empty() and not bool(_格(页, 3).button_pressed),
			"退回维护的那枚**点不动**（`kuaFuData:68` `useHandCursor = enabled = false` ⇒ 与原版 removeEvent 同）")
	await 点钮(_格(页, 1))
	_记(控制器.选中() == "频道格1", "1 号（这一帧里唯一有数据的那枚）照样点得中 ⇒ 上面那条不是整页失灵")
	真后.call("_handle_bridge_text", _多行帧())
	await _等(2)
	await 点钮(_格(页, 5))
	_记(控制器.选中() == "频道格5", "先真点中 5 号（下面那条「掉回维护要退选中」的前置）")
	真后.call("_handle_bridge_text", "1825:0:1&忍界战场&0:%d" % 夹载)
	await _等(2)
	_记(控制器.选中().is_empty() and not bool(_格(页, 5).button_pressed),
			"新帧里没有 5 号 ⇒ **选中自动取消**（`setData:153-157` 的 `_currentCell.channelData is int` 那一支），"
			+ "实测选中「%s」" % 控制器.选中())


## ──  互斥选中（真点，不是 emit 信号）─────────────────────────────────────────
## 把夹具拼成一条 `1825:0` 的文本桥原文（行 = `频道号&名&载入`，多行 `@` 连，帧尾一个 `maxLoad`）。
func _多行帧() -> String:
	var 行们: Array[String] = []
	for 行v in 夹列:
		var 行: Dictionary = 行v as Dictionary
		行们.append("%d&%s&%d" % [int(行.get("channel_id", 0)), String(行.get("name", "")), int(行.get("load", 0))])
	return "1825:0:%s:%d" % ["@".join(行们), 夹载]


func _量选中() -> void:
	日志.append("=== 真点格：互斥选中 ===")
	var 页 := _页()
	# 上一段末尾那条「只有一行」的帧已经把 3/4 号打回禁用了 ⇒ 这一段的**前置自己喂回来**，
	# 否则点禁用件静默没反应，三条选中判据会一起红（看着像互斥逻辑坏了，其实是夹具状态）。
	真后.call("_handle_bridge_text", _多行帧())
	await _等(2)
	_记(not bool(_格(页, 3).disabled) and not bool(_格(页, 4).disabled),
			"前置：3/4 号已经放开禁用 ⇒ 下面三条测的是选中互斥，不是「点了个禁用件、静默没反应」")
	await 点钮(_格(页, 3))
	_记(控制器.选中() == "频道格3" and bool(_格(页, 3).button_pressed),
			"点 3 号 ⇒ 选中（pressed 槽 = 658 那张，即库里 selectedUpSkin 与 downSkin 同一个 charId）")
	await 点钮(_格(页, 4))
	_记(控制器.选中() == "频道格4" and not bool(_格(页, 3).button_pressed) \
			and bool(_格(页, 4).button_pressed),
			"再点 4 号 ⇒ 旧的自动放开（`selectedChannel:98-109` 互斥，不是多选）")
	await 点钮(_格(页, 4))
	_记(控制器.选中() == "频道格4", "重复点同一枚 ⇒ 选中不变（`:100` `if(_currentCell != param1)` 那道判断）")
## ── ⑨ 两条上行真发 + 等级闸门（`isCheckLevel:224-235`）───────────────────────
## 离线拿不到出帧 ⇒ 这里把窗的 `_backend` 换成**假后端**（只接管出帧那半边，同 伊鲁卡三窗门 §3.121），
## 判据读的是假后端**记到的实参**，不是"我确实调过 `_点进入`"。
## ⚠ 每次重开都重新 `_render_page()` ⇒ 32 枚又回到烘进场景的那一帧（全禁用「（维护）」），
##   所以 `_重开` 里必须再喂一次列表，否则后面"真点格"点的是禁用件 = 静默没点着。
func _量上行() -> void:
	日志.append("=== 上行真发：开窗拉列表 / 双击进场 / 等级闸门（假后端记账）===")
	var 窗 = _窗()
	if 窗 == null:
		收尾("窗没了 ⇒ 上行那一段没量到")
		return
	窗.set("_backend", 假)
	_设等级(70)
	var 前 := 假.列表次数
	await _重开(true)
	_记(假.列表次数 == 前 + 1,
			"**开窗真的拉了一次列表**（`1825:0` = `WarPanelProcessor.as:122-127`），这一扇开出去 %d 条"
			% (假.列表次数 - 前))
	# —— 双击 = 选 + 立即进入（`:218-222`）；成功那一支原版**一句提示都不弹**、只关窗
	假.进场.clear()
	_清通知()
	await 双击(_页().get_node("频道列表/频道格5").get_global_rect().get_center())
	_记(假.进场 == [5], "双击 5 号 ⇒ 真发 `request_war_panel_enter(5)`（`enterBattleHandler:118`），实测 %s" % str(假.进场))
	_记(not 已开(), "进场后**窗自己关了**（`:122` `onCloseBtnClick(null)`）")
	_记(通知记录.is_empty(), "成功那一支**不弹任何提示**（原版发完就关窗，一句 addNotice 都没有）")
	# —— 号 ≤ 27 不看等级：等级 45 照样放行
	假.进场.clear()
	await _重开(true)
	_设等级(45)
	var 页 := _页()
	await 点钮(_格(页, 3))
	await 点钮(页.get_node("进入钮") as Button)
	_记(假.进场 == [3] and not 已开(),
			"3 号（≤ 27）等级 45 ⇒ **照样放行**（闸门只管号 > 27 那一组）+ 关窗，实测 %s" % str(假.进场))
	# —— 号 > 27：60~80 之内放行；59 / 81 两档拦下（拦下时**不许发帧**、**不许关窗**）
	假.进场.clear()
	await _重开(true)
	_设等级(70)
	页 = _页()
	await 点钮(_格(页, 28))
	_记(_格(页, 28).button_pressed and 控制器.选中() == "频道格28",
			"点 28 号那一下**真的落到了件上**（pressed 设上 + 选中记到 28）。⚠ 这一条是补的盲区："
			+ "重叠区里聊天面板(CanvasLayer 100)曾把窗口(局部层 1..N)的**命中**吃掉（画在它上面却点不到，"
			+ "见 `窗口管理.gd:重排层级` 的 2026-10-06 修正）⇒ 没有这条，点不到会伪装成等级闸门逻辑错")
	await 点钮(页.get_node("进入钮") as Button)
	_记(假.进场 == [28], "28 号（> 27）等级 70 在 60~80 **之内** ⇒ 放行、真发进场帧，实测 %s" % str(假.进场))
	for 档 in [[59, "低于下限"], [81, "超上限"]]:
		假.进场.clear()
		await _重开(true)
		_设等级(int(档[0]))
		页 = _页()
		await 点钮(_格(页, 28))
		_清通知()
		await 点钮(页.get_node("进入钮") as Button)
		_记(假.进场.is_empty() and 已开() and _尾通知() == "进入该频道，需要等级在60级到80级之间！",
				("28 号 %s（%s，`:228` 是 `>=60 && <=80` 双向）⇒ 一条上行都不发、窗**不关**、"
				+ "通知逐字 = KUAFU_CHANNEL_LEVEL_TISHI，实测「%s」") % [str(档[0]), String(档[1]), _尾通知()])
	# —— 没选任何格就点进入（主动偏离那一条）
	假.进场.clear()
	await _重开(true)
	_清通知()
	await 点钮(_页().get_node("进入钮") as Button)
	_记(控制器.选中().is_empty() and 假.进场.is_empty() and 已开() \
			and _尾通知() == "请选择跨服服务器",
			"没选任何格点进入 ⇒ 不发帧、不关窗、弹 KUAFUSERVERLIST_SELECTED_CHANEL_PROMPT。⚠ **这是主动偏离**："
			+ "原版 `enterBattleHandler:113` 先调 `isCheckLevel()`，而 `:226` 无条件读 "
			+ "`_currentCell.channleIndex` ⇒ 空引用 #1009、监听器中途死掉，这句提示其实是死代码。"
			+ "这边实现「意图」而不是照抄崩溃（见门头 ⑥）")
	# 还原成真后端，别把假的那份留给邻居段
	var 窗2 = _窗()
	if 窗2 != null:
		窗2.set("_backend", 真后)


## ── ⑦ 刷新 20 秒节流：第二次点**一条上行都不许发**（原版连提示都没有）────────
## ⚠ 数的是**发没发**，不是通知文案 —— 接上真上行之后成功那一支本来就没提示，
##   再拿「回显里含不含 1825」当判据 = 改了也不红（第 廿六~廿八 种那族）。
func _量刷新节流() -> void:
	日志.append("=== 刷新钮：20 秒内再点 = 连帧都不发 ===")
	var 窗 = _窗()
	if 窗 == null:
		收尾("窗没了 ⇒ 节流那一段没量到")
		return
	窗.set("_backend", 假)
	_设等级(70)
	await _重开(true)
	var 前 := 假.列表次数
	_清通知()
	await 点钮(_页().get_node("刷新钮") as Button)
	var 中 := 假.列表次数
	_记(中 == 前 + 1, "第一次点刷新 ⇒ 真发一条 `1825:0`（`refreshHandler:242`），这一段记 %d→%d" % [前, 中])
	_清通知()
	await 点钮(_页().get_node("刷新钮") as Button)
	_记(假.列表次数 == 中 and 通知记录.is_empty(),
			"**20 秒内再点 ⇒ 一条都不发、也没有任何提示**（`refreshHandler:240` 的 `>= 20` 不过就整个函数直接结束），"
			+ "累计仍是 %d" % 假.列表次数)
	窗.set("_backend", 真后)		# 还原，别把假后端留给下一段（烘值那段读的是 .tscn 文本，不碰它）


## ── ⑧ 编辑器 == 运行期：读 .tscn 文本比对开屏态 ─────────────────────────────
func _量烘值() -> void:
	日志.append("=== 场景烘的开屏态 == 运行期第一帧（读 .tscn 文本）===")
	var 文 := FileAccess.get_file_as_string(场景路)
	_记(文.count("disabled = true") >= 格数,
			"32 枚格在 .tscn 里就写着 `disabled = true`（实测 %d 处）⇒ 编辑器里看到的就是原版开屏那一帧"
			% 文.count("disabled = true"))
	_记(文.count("toggle_mode = true") >= 格数,
			"32 枚都写着 `toggle_mode = true`（选中 = pressed 槽 = 库里 selectedUpSkin 那张）")
	_记(not 文.contains("[node name=\"频道格33\""),
			"场景里**没有第 33 枚格**（`:195-197` 那个 break）⇒ 谁补齐成 33 这里就红")
	var 块 := _节(文, "频道格1")
	_记(块.contains('theme_override_styles/disabled = SubResource("') and 块.contains("_n\")"),
			"频道格的 disabled 槽指回**常态**那张皮（库里 disabledSkin 与 upSkin 同为 charId 652）——"
			+ "落回主题默认就会在禁用时变成一个灰盒子，实测 %s" % ["√" if 块.contains("_n\")") else "缺"])
	_记(文.count("res://素材/界面/原版窗口/跨服/频道格.png") >= 1 \
			and 文.count('path="res://素材/界面/原版窗口/跨服/频道格') == 3,
			"32 枚格**共用同一组三张皮**（ext_resource 只出现 3 条：常态/悬停/按下）⇒ 不复制 32 份")
	_记(文.contains("text = \"跨服频道 01\"") and 文.contains("text = \"跨服频道 32\"") \
			and 文.count("text = \"（维护）\"") >= 格数,
			"名与状态文字**烘在 .tscn 里**（不是运行期才长出来）⇒ 编辑器视图与玩家第一帧一致")
