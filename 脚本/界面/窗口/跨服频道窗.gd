extends RefCounted

## 漩涡鸣人（NPC `00000012`，模板 12，称号「跨服忍界大战」）「跨服频道」= 原版
## `com/mxw/uifl/controls/kuafu/KuaFuChannelWindow`（**595×451**，标题「选择跨服频道」）。
## 场景由 `开发工具/原版服务窗.py 生成 跨服频道` 从 SPEC 烘（101 件、逐条带 AS3 行号），
## **别手改 .tscn** —— 门会重跑生成器比期望表（`数据/界面/跨服频道_期望.json`）。
##
## 控制器只管原版也归运行期管的那几件：
##   ① 32 枚频道格的**选中态机**（`:98-109` `selectedChannel`：旧枚 selected=false、新枚 true；
##      `:164-167` 单击 = 选；`:218-222` 双击 = 选 + 立即进入）；
##   ② `:130-162` `setData`：先给每枚 `kuaFuData = 序号`（**int** ⇒ 灰禁用「（维护）」），
##      再用服务端列表覆盖 ⇒ 有数据那几枚放开、状态文字按 `load/maxLoad` 换三档色；
##   ③ 两颗钮的**客户端闸门**（都在发帧之前，属本地行为、照搬）：
##      进入 = `:111-128` + `:224-235`（号 > 27 才卡 60~80 级）；
##      刷新 = `:237-245`（两次点击间隔 < 20 秒 ⇒ **什么都不做**，连提示都没有）。
##
## ⚠ 一条**主动偏离**（登记在几何/行为门与真值 md，等点头）：
##   原版 `enterBattleHandler:113` 第一句就 `this.isCheckLevel()`，而 `isCheckLevel:226`
##   无条件读 `this._currentCell.channleIndex` ⇒ **一枚都没选时原版先抛 #1009 空引用、
##   监听器中途死掉**，`:126` 那句「请选择跨服服务器」永远弹不出来（死代码）。
##   这边改成：没选 ⇒ 通知「请选择跨服服务器」。这是把"原版的意图"实现出来，不是照抄崩溃。
##
## 协议面（**已接真上下行**）：`WAR_PANEL_ACTION = 1825`（`SendOpCodes.as:268`、
##   收侧 `ReceiveOpCodes.as:390` 同号）。上行 `WarPanelProcessor.as:122-127` 子命令 0 = 取频道列表、
##   `:28-34` 子命令 1 = 选服进场（int channel_id）。本机服务端 `fake_flash_server.py:11715` 注册
##   `handle_war_panel_action`（现查在 `:21053-21074`），两条都在处理（cmd 0 回 `1825:0:1&忍界战场&<在线>:100`）。
##   原版那一跳是「收到回帧才开窗」（`WarPanelProcessor:136-167` → `:51881-51882` →
##   `Client.as:4200-4203` → `KuaFuManager:516-527` `if(!kuaFuChannelWindow) showEnterBattleView()`）
##   ⇒ 这边改成「开窗即要列表、回帧原地塞数」，页不拆（同一族坑见 #312）；
##   进场那跳仍然照原版 `enterBattleHandler:118-122` 发帧后关窗。

const 夹具路径 := "res://数据/界面/跨服频道_夹具.json"

const 格数 := 32			# `createChannels:195-197` 那个 `== 32 break` ⇒ 只有 32 枚，不是 33
const 分界 := 27			# `FENJIEINDEX`：号 > 27 才卡等级
const 最低级 := 60			# `MINLEVEL`
const 最高级 := 80			# `MAXLEVEL`
const 节流秒 := 20.0		# `refreshHandler:240` `(getTimer() − last)/1000 >= 20`

## `SelectedChannelCell.as:33` `upTextColor = 16577692` / `disabledTextColor = 7434344`；
## 三档状态色来自 `:66-75` 的 htmlText（#00ff00 / #ff9100 / #ff0000）。
const 色常态 := Color(0.988235, 0.956863, 0.611765)
const 色禁用 := Color(0.443137, 0.439216, 0.407843)
const 色通畅 := Color(0, 1, 0)
const 色良好 := Color(1, 0.568627, 0)
const 色爆满 := Color(1, 0, 0)
const 文维护 := "（维护）"		# KUAFU_WEIHU
const 文通畅 := "通畅"			# CN.CHANG_TONG
const 文良好 := "良好"			# CN.LIANG_HAO
const 文爆满 := "爆满"			# CN.BAO_MAN
const 文未选 := "请选择跨服服务器"	# KUAFUSERVERLIST_SELECTED_CHANEL_PROMPT
const 文等级 := "进入该频道，需要等级在60级到80级之间！"	# KUAFU_CHANNEL_LEVEL_TISHI

## 会话级：原版 `_currentCell` / `_lastClickTime` 都是窗内状态 ⇒ 这边同样只记会话。
static var _选路 := ""
static var _上次刷新 := -1000.0


static func 新会话() -> void:
	_选路 = ""
	_上次刷新 = -1000.0


static func 选中() -> String:
	return _选路


## `宿主` = `功能窗口`（要 `_content` / `_通知` / `_session` / `_backend`）。
static func 渲染(宿主: Node, 场景: PackedScene) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	for 号 in range(1, 格数 + 1):
		var 格 := 页.get_node("频道列表/频道格%d" % 号) as Button
		格.pressed.connect(_点格.bind(页, 号))
		# 原版 `doubleClickEnabled = true`（`:188`）+ `:218-222` 双击 = 选 + 进入。
		# Godot 的 Button 没有双击信号 ⇒ 在 gui_input 里认 `double_click`（第二次按下会带上）。
		格.gui_input.connect(_格双击.bind(页, 号, 宿主))
	(页.get_node("进入钮") as Button).pressed.connect(_点进入.bind(页, 宿主))
	(页.get_node("刷新钮") as Button).pressed.connect(_点刷新.bind(宿主))
	_上选中(页)
	_接回帧(页, 宿主)
	return 页


## 订阅 `1825:0` 那一帧 ⇒ 原地塞数（回帧**不许**拆页重建，按住的两下会落到已释放的件上）。
## 页是运行期建的 ⇒ 连接随页释放自动失效（Godot 4 对已释放目标会自己断开），不留悬挂。
## ⚠ **开窗那一次拉取不在这里**：走 `功能窗口.gd:打开()` 里 `page_name == "跨服频道"` 那一支
##   （与 心法/任务/签到 同一条口径）。渲染里发 = 任何原因的**重建**都会再发一遍 ⇒ 成环。
static func _接回帧(页: Control, 宿主: Node) -> void:
	var 后: Node = 宿主.get("_backend") as Node
	if 后 == null or not 后.has_signal("war_panel_received"):
		return
	后.connect("war_panel_received", func(列表: Array, 最大载入: int) -> void:
		if is_instance_valid(页):
			填数(页, 列表, 最大载入))


static func _要列表(宿主: Node) -> void:
	var 后: Node = 宿主.get("_backend") as Node
	if 后 != null and 后.has_method("request_war_panel_list"):
		后.call("request_war_panel_list")


## 编辑器 = 运行期：场景里 32 枚全是 `disabled = true`、没一枚 pressed ⇒ 会话里若还记着
## 一枚选中（重开这扇的场景），把它重新按上；否则什么都不做。
static func _上选中(页: Control) -> void:
	if _选路.is_empty():
		return
	var 格 := 页.get_node_or_null("频道列表/%s" % _选路) as Button
	if 格 == null:
		_选路 = ""		# 场景换了形状（件名改了）⇒ 别留一个指不到东西的"选中"
		return
	格.button_pressed = true


static func _点格(页: Control, 号: int) -> void:
	_选中(页, 号)


## `selectedChannel:98-109`：同一枚重复点不重做；换枚时旧的 selected = false。
static func _选中(页: Control, 号: int) -> void:
	var 名 := "频道格%d" % 号
	if _选路 == 名:
		return
	if not _选路.is_empty():
		var 旧 := 页.get_node_or_null("频道列表/%s" % _选路) as Button
		if 旧 != null:
			旧.button_pressed = false
	_选路 = 名
	var 新 := 页.get_node("频道列表/%s" % 名) as Button
	新.button_pressed = true


## ⚠ `Callable.bind` 的实参**排在信号自带参数之后**（本工程第三次栽同一条）：
##   `gui_input.connect(F.bind(页, 号, 宿主))` 收到的调用是 `F(事件, 页, 号, 宿主)`
##   ⇒ 形参顺序必须把 `事` 写在第一个，否则事件被灌进 `页`、函数一路拿错类型。
static func _格双击(事: InputEvent, 页: Control, 号: int, 宿主: Node) -> void:
	var 按事 := 事 as InputEventMouseButton
	if 按事 == null or not 按事.pressed or not 按事.double_click:
		return
	_选中(页, 号)
	_点进入(页, 宿主)


## `enterBattleHandler:111-128`：等级闸门 → 有选中就发帧 + 关窗，没选中就提示。
## 原版成功那一支**不弹任何提示**（发完就 `onCloseBtnClick(null)`），所以这里也一句都不加。
static func _点进入(页: Control, 宿主: Node) -> void:
	var 号 := 0
	if not _选路.is_empty():
		号 = int(_选路.replace("频道格", ""))
	if 号 > 0 and not _等级够(宿主, 号):
		宿主._通知(文等级)
		return
	if 号 == 0:
		# ⚠ 见文件头「主动偏离」：原版在这里会先抛 #1009，这句提示其实是死代码。
		宿主._通知(文未选)
		return
	var 后: Node = 宿主.get("_backend") as Node
	if 后 != null and 后.has_method("request_war_panel_enter"):
		后.call("request_war_panel_enter", 号)
	宿主.close()


## `isCheckLevel:224-235`：只有 **号 > 27** 那一组才卡 60~80 级；号 ≤ 27 一律放行。
static func _等级够(宿主: Node, 号: int) -> bool:
	if 号 <= 分界:
		return true
	var 会: Node = 宿主.get("_session") as Node
	if 会 == null:
		return false
	var 级 := int((会.get("player_stats") as Dictionary).get("level", 1))
	return 级 >= 最低级 and 级 <= 最高级


## `refreshHandler:237-245`：**20 秒内再点 = 静默什么都不做**（原版连提示都没有）；
## 够 20 秒才记时间 + 发 `1825:0`（回帧走 `_接回帧` 原地塞数，同样一句提示都没有）。
static func _点刷新(宿主: Node) -> void:
	var 今 := float(Time.get_ticks_msec()) / 1000.0
	if 今 - _上次刷新 < 节流秒:
		return
	_上次刷新 = 今
	_要列表(宿主)


## `setData:130-162` 逐句三段（回帧来了**原地改**，不拆页）：
## ① `:138-145` 先把 32 枚全打回 int ⇒ 每一枚都变「（维护）」灰禁用（**上一轮回帧放开的那几枚
##    这一轮没再出现，就必须跟着退回维护**，这是接上 `1825:0` 之后才暴露出来的一段）；
## ② `:146-152` 再用列表覆盖 `cells[channel_id-1]`；
## ③ `:153-157` 选中的那枚如果掉回了 int ⇒ `selected = false`、`_currentCell = null`。
## ⚠ 频道名**不**被数据覆盖 —— `kuaFuData` 分支只在开头写「跨服频道 NN」，
##   覆盖名的是另一个 setter `channelData`（`:87-105`，这扇窗不用它）。
static func 填数(页: Control, 列表: Array, 最大载入: int) -> void:
	for 号 in range(1, 格数 + 1):
		_置维护(页, 号)
	var 有数据 := {}
	for 行v in 列表:
		var 行: Dictionary = 行v as Dictionary
		var 号 := int(行.get("channel_id", 0))
		if 号 < 1 or 号 > 格数:
			continue
		有数据[号] = true
		var 比 := 0.0
		if 最大载入 > 0:
			比 = float(int(行.get("load", 0))) / float(最大载入)
		_放开(页, 号, 比)
	if not _选路.is_empty():
		var 序 := int(_选路.replace("频道格", ""))
		if not 有数据.has(序):
			var 格 := 页.get_node_or_null("频道列表/%s" % _选路) as Button
			if 格 != null:
				格.button_pressed = false
			_选路 = ""


static func _置维护(页: Control, 号: int) -> void:
	var 格 := 页.get_node("频道列表/频道格%d" % 号) as Button
	var 态 := 页.get_node("频道列表/频道格%d/频道格%d态" % [号, 号]) as Label
	var 名 := 页.get_node("频道列表/频道格%d/频道格%d名" % [号, 号]) as Label
	格.disabled = true
	态.text = 文维护
	态.add_theme_color_override("font_color", 色禁用)
	名.add_theme_color_override("font_color", 色禁用)


static func _放开(页: Control, 号: int, 比: float) -> void:
	var 格 := 页.get_node("频道列表/频道格%d" % 号) as Button
	var 态 := 页.get_node("频道列表/频道格%d/频道格%d态" % [号, 号]) as Label
	var 名 := 页.get_node("频道列表/频道格%d/频道格%d名" % [号, 号]) as Label
	格.disabled = false
	名.add_theme_color_override("font_color", 色常态)	# `drawState:106` enabled ⇒ #FCF49C
	if 比 <= 0.7:
		态.text = 文通畅
		态.add_theme_color_override("font_color", 色通畅)
	elif 比 <= 0.99:
		态.text = 文良好
		态.add_theme_color_override("font_color", 色良好)
	else:
		态.text = 文爆满
		态.add_theme_color_override("font_color", 色爆满)


## 门/量具用：读夹具（字段名逐条对 `WarChannelInfo.decode` 的顺序与名字）。
static func 读夹具() -> Dictionary:
	var 解: Variant = JSON.parse_string(FileAccess.get_file_as_string(夹具路径))
	return 解 as Dictionary if typeof(解) == TYPE_DICTIONARY else {}
