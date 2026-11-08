extends RefCounted

## 油女志乃（NPC `00000023`，模板 23，称号「护送」）「护送任务」= 原版
## `com/mxw/uifl/controls/husong/HuSongQuestWindow`（578×342，标题「护送任务」）。
## 场景由 `开发工具/原版服务窗.py 生成 护送任务` 从 SPEC 烘（43 件、逐条带 AS3 行号），
## **别手改 .tscn** —— 门会重跑生成器比期望表（`数据/界面/护送任务_期望.json`）。
##
## 控制器只负责原版里**运行期才长出来**的那四件（其余全是静态件、已在场景里）：
##   :226-231 `hsCheckBox`（MCheckBoxF，文「刷出」，字色 `MCheckBox.as:13` `upTextColor`
##            = 16748800 = #ff9100；宽 = 皮19 + 2 + 文字24 = **45**、高 = 皮高 19，
##            走 `:85` 的**九宫格**分支 —— `:12` `isScale9Grid = true`）
##   :232-241 `hsComboBox`（MComboBox 60×20，`enabled = hsCheckBox.selected` ⇒ **开窗时禁用**）
##   :169-178 `ruleTf`（MGlowLabel #1e90ff + underline + `buttonMode = useHandCursor`，
##            `:178` `MToolTipText.createToolTip(stage, ruleTf, HUSONG_RULE_DESC)` ⇒ 悬停出规则条）
##   :114     `setContentBgPos(CONTENT_GAP, 30)` ⇒ 内容底顶 30（尺寸表 `内容底顶`，
##            宿主那条固定 38 会低 8px）
##
## ⚠ 五枚奖卡格**没有点击**：`HuSongItemCell` 全文没有 CLICK 监听，选中框的可见性由
##   `onLoadComplete:93` `selectedBg.visible = (manager.richDegree == id)` 决定
##   （`set selected:75-78` 是另一条入口，`createChildren` 里先 `selected = false`）——
##   是「当前品质」的指示器，不是可选项 ⇒ 这边全隐（离线没有 richDegree，不假造）。
##
## ⚠ 数字件全空（等级文本的 %1 / 时间 / 经验 / 精华 / 气血 / 免费刷新次数）：
##   原版只在 `updateview(:286-310)` 里填，数据源是 **MIXIN 2325 状态帧**
##   （入口链 `showHuSongQuestWindow:234-240` 第一件事就是 `requestMinxin_update()`）
##   ⇒ 本地直开就是空态，这是原版的形状，不是漏做。
##
## 协议面（**刷新与开启两条已接真上行**，10-22）：`QuestProcessor.as:186-192` `requestMixin_common(子命令)`
##   → `SendOpCodes.MIXIN = 2325`（`SendOpCodes.as:318`；收侧 `ReceiveOpCodes.as:480` 同号）。
##   子命令：1 = 刷新品质（带 `{"color":N}`，`:229-232` ⇒ `后端连接.request_escort_refresh`）、
##   2 = 开启护送（`:121-124` ⇒ `request_escort_start`）、4 = 取状态（`:70-73`）。
##   本机服务端**在处理**（`handle_mixin:34363-34405`）⇒ 发出去有回话：成功/失败那两句
##   都来自服务端 `_send_native_server_message`，**这边不本地改品质**（那是服务端的账）。
## ⚠ 剩下两条没接（不是漏写，是差数据/差帧形，逐条见 `真值/世界/外来帧与上行接线.md` §⑤）：
##   · 状态帧 `2325:1` 服务端只发**二进制原帧**（`_send_mixin_state:34540` 走 `send_original_packet`）
##     ⇒ 文本桥收不到 ⇒ 窗里那些数字件仍是空态（原版靠这条帧填，`updateview:286-310`）；
##   · 提示弹那颗「前往」的第二支 `gotoStartQuestNpcPoint()` —— 寻路入口**已查到**
##     （`小地图面板.前往NPC(模板号)`，与追踪栏/交付赶路同一条），**差的是目标号**：
##     原版取 `this.quest.npcId` / `QuestDataManager.findHuSongQuest().npcId`，
##     而"哪一条任务算护送任务"在客户端数据里还没定位 ⇒ 不猜，等定位之后再并。

const 复选项场景 := preload("res://场景/界面/组件/原版复选项.tscn")
const 文字提示场景 := preload("res://场景/界面/组件/文字提示框.tscn")
const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")

## `HUSONG_PINZHI_NAME`「D级#C级#B级#A级#S级」`.split("#").reverse()`（`:234-235`）
## ⇒ **[S级, A级, B级, C级, D级]**，与五枚格名那一排（D→S）**正好反序**。
## ⚠ 两处顺序相反是原版给的形状，不许"顺手统一"。
const 下拉项 := ["S级", "A级", "B级", "C级", "D级"]

## `HUSONG_CHECK_TXT`「刷出」+ `HUSONG_COMBOBOX_TXT`「为止」连读 =「刷出 [S级] 为止」。
const 勾选文 := "刷出"

## `MCheckBox.as:13` `upTextColor = 16748800`。
const 勾字色 := Color(1.0, 0.568627, 0.0)

## `HUSONG_RULE_DESC` 逐字（七条，原版用 `\n` 分行 ⇒ 这里存成数组、拼回 `\n`，
## 免得踩「GDScript 不接相邻字面量」那条坑（本会话栽过四次））。
const 规则行 := ["1.本活动全天均可完成护送任务。",
		"2.在双倍活动开启期间，完成任务有双倍奖励，双倍时间为每天20:00-20:30。",
		"3.任务分为5种颜色，由白色到橙色奖励逐渐增加，可使用元宝/点卷刷新任务颜色。",
		"4.活动期间玩家可以打劫正在护送的玩家，将护送奖励据为己有，每天只能打劫3次。",
		"5.打劫同等级段的玩家，才能获得奖励，打劫时不能使用群攻，例如35级只能打劫30-39等级段才可获得奖励。",
		"6.被打劫或护送失败的玩家，依然可获得一半的奖励。",
		"7.护送中不能使用二段跳，瞬移，隐身等技能。"]

## 会话级勾选态：原版 `hsCheckBox.selected` 不落 `userCfg`（对比 日环 那两枚会落盘），
## 且关窗时 `onCloseBtnClick:78-84` 把 `autoRefesh` 复位 ⇒ 这边也只记会话、由 `新会话()` 清零。
static var _勾 := false


static func 新会话() -> void:
	_勾 = false


static func 勾选态() -> bool:
	return _勾


## `宿主` = `功能窗口`（要 `_content` / `_通知` / `_configure_option_button`）。
static func 渲染(宿主: Node, 场景: PackedScene) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	_建下拉(页, 宿主)
	_建勾选(页, 宿主)			# 后建：勾选要在 `_设勾` 里同步下拉的 disabled
	_接规则(页)
	(页.get_node("刷新钮") as Button).pressed.connect(
			func() -> void: _点刷新(页, 宿主))
	(页.get_node("开始钮") as Button).pressed.connect(
			func() -> void: _点开启(宿主))
	return 页


## 品质取**这一页那枚下拉当前选中的项**（原版 `:232-241` 那个 `品质下拉` 就是 color 的来源，
## 开窗时禁用、只有服务端给了才亮）；取不到就发 0 —— 服务端 action 1 自己按 `_mixin_pending_color()` 算，
## 不拿这个数当账，但段数与键名必须与原版一致（`{"color":N}`）。
static func _点刷新(页: Control, 宿主: Node) -> void:
	var 下拉 := 页.get_node_or_null("品质下拉槽/品质下拉") as OptionButton
	var 品质 := 0
	if 下拉 != null and 下拉.selected >= 0:
		品质 = int(下拉.get_item_id(下拉.selected))
	var 后端 := 宿主.get_node_or_null("/root/BackendConnection") as Node
	if 后端 == null or not 后端.has_method("request_escort_refresh"):
		宿主._通知(刷新话() + "｜取不到 /root/BackendConnection")
		return
	后端.call("request_escort_refresh", 品质)
	宿主._通知(刷新话())


## 开启护送：原版 `requestMixin_startQuest()` 一个参数都不带。
static func _点开启(宿主: Node) -> void:
	var 后端 := 宿主.get_node_or_null("/root/BackendConnection") as Node
	if 后端 == null or not 后端.has_method("request_escort_start"):
		宿主._通知(开启话() + "｜取不到 /root/BackendConnection")
		return
	后端.call("request_escort_start")
	宿主._通知(开启话())


static func 刷新话() -> String:
	return "已发 MIXIN 2325 子命令 1（服务端会回「护送进行中不能刷新」/「已是最高品质」，或把品质 +1）"


static func 开启话() -> String:
	return "已发 MIXIN 2325 子命令 2（服务端按 30 级闸门与品质结算，成功会走护送那一套回帧）"


## `:226-231` 复选项塞进 `自动刷新槽`（45×19）。原版 `MCheckBoxF` 的宽是算出来的
## （皮 19 + 2 + 文字宽）⇒ 槽宽就是它的宽，别再往两边留边距。
static func _建勾选(页: Control, 宿主: Node) -> void:
	var 槽 := 页.get_node("自动刷新槽") as Control
	var 件 := 复选项场景.instantiate() as Control
	件.name = "复选_刷出"
	件.custom_minimum_size = 槽.size
	件.size = 槽.size
	var 字 := 件.get_node("文本") as Label
	字.text = 勾选文
	字.add_theme_color_override("font_color", 勾字色)
	# ⚠ 共用件 `原版复选项.tscn` 的 文本 是**摆设置页长句**的（x=22、宽 155 ⇒ 右缘 177）：
	#   照搬进这枚 45 宽的复选项，文字盒会伸出窗口右框 15px（`窗口布局体检` 抓到）。
	#   原版 `MCheckBox.as:17-20` `tf.x = upSkin.x + upSkin.width + 2 = 21`、`tf.width` = **实测文字宽**
	#   （`measure():85` 反推：宽 45 = 19 + 2 + 24 ⇒ 文字宽 24）⇒ 按真值压回 24 宽，别留 155。
	字.position = Vector2(21.0, 字.position.y)
	字.size = Vector2(槽.size.x - 21.0, 槽.size.y)
	var 钮 := 件.get_node("点击区域") as Button
	钮.size = 槽.size
	钮.focus_mode = Control.FOCUS_NONE
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 原版 `MButton3.init():135` = `buttonMode = useHandCursor = true`（MCheckBox 继承它）
	_设勾(页, 件, _勾)
	# 用 `pressed` + 自己翻 `标记.visible`（口径同 日环/设置）⇒ 不开 `toggle_mode`、
	# 也不碰 `toggled`（`Callable.bind` 的参数排在调用参数之后，接错就是静默不响应）。
	钮.pressed.connect(_点勾.bind(页, 件))
	槽.add_child(件)


## `:66-69` `autoHankdler`：勾选一变就同步 `hsComboBox.enabled`（**只此一件副作用**，
## 原版那边的 `autoRefesh` 是驱动 1 秒定时器连刷的开关 ⇒ 属协议支路，未接）。
static func _点勾(页: Control, 件: Control) -> void:
	_设勾(页, 件, not bool((件.get_node("标记") as CanvasItem).visible))


static func _设勾(页: Control, 件: Control, 选中: bool) -> void:
	_勾 = 选中
	(件.get_node("标记") as CanvasItem).visible = 选中
	(页.get_node("品质下拉槽/品质下拉") as OptionButton).disabled = not 选中


## `:232-241` 品质下拉塞进 `品质下拉槽`（60×20），开窗时**禁用**。
static func _建下拉(页: Control, 宿主: Node) -> void:
	var 槽 := 页.get_node("品质下拉槽") as Control
	var 下拉 := OptionButton.new()
	下拉.name = "品质下拉"
	下拉.size = 槽.size
	下拉.custom_minimum_size = 槽.size
	下拉.focus_mode = Control.FOCUS_NONE
	宿主._configure_option_button(下拉)
	for i in 下拉项.size():
		下拉.add_item(下拉项[i], i)
	下拉.selected = 0
	下拉.disabled = not _勾				# `:241` `enabled = hsCheckBox.selected`
	槽.add_child(下拉)


## `:169-178` 「护送规则」：下划线 + 手型已烘，这里只补**可悬停**与提示条。
## Godot 的 `RichTextLabel` 默认 `mouse_filter = IGNORE` ⇒ 不改成 STOP 就一次悬停都收不到。
static func _接规则(页: Control) -> void:
	var 钮 := 页.get_node("护送规则钮") as RichTextLabel
	钮.mouse_filter = Control.MOUSE_FILTER_STOP
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.mouse_entered.connect(_出规则.bind(页))
	钮.mouse_exited.connect(_收规则.bind(页))


static func _出规则(页: Control) -> void:
	var 名 := "文字提示_护送规则"
	var 框 := 页.get_node_or_null(名) as Control
	if 框 == null:
		框 = 文字提示场景.instantiate() as Control
		框.name = 名
		框.mouse_filter = Control.MOUSE_FILTER_IGNORE
		页.add_child(框)
	框.设置(确认弹.文案转BBCode("\n".join(规则行)).replace("\n", "[br]"),
			页.get_viewport_rect().size)
	框.visible = true
	框.贴到鼠标(页.get_local_mouse_position(), 页.get_viewport_rect().size)


static func _收规则(页: Control) -> void:
	var 框 := 页.get_node_or_null("文字提示_护送规则") as CanvasItem
	if 框 != null:
		框.visible = false


## ── 护送族第二扇：`husong/HuSongNoticeWindow` 300×170（双倍活动提示弹） ──────────
## 两块静态件全在场景里（居中富文本 + 一颗钮）⇒ 控制器只接那一颗钮。
## 原版 `goQuestHandler:23-27` 做**两件事**：① `showHuSongNoticeWindow()` —— 它走的是
## `UIMain2.as:5365-5368` 的 `reverseDisplay(HUSONGNOTICE_WINDOW)`，即**再点一次 = 收起自己**；
## ② `gotoStartQuestNpcPoint()` 自动寻路到志乃 —— 世界层 + 任务数据，未接（待点头）。
## ⇒ 这边照做 ①（工程里等价的那条是 `窗口管理.打开或收起`）+ 把 ② 说清楚。
static func 渲染提示(宿主: Node, 场景: PackedScene) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	(页.get_node("前往钮") as Button).pressed.connect(_点前往.bind(宿主))
	return 页


static func 提示话() -> String:
	return "前往护送 = 原版收掉本提示弹 + `gotoStartQuestNpcPoint()` 自动寻路到志乃" \
			+ "（`HuSongNoticeWindow.as:23-27`）⇒ 寻路属世界层，本工程未接（待点头）"


static func _点前往(宿主: Node) -> void:
	宿主._通知(提示话())
	var 管理: Node = 宿主.get_parent()
	if 管理 != null and 管理.has_method("打开或收起"):
		管理.call("打开或收起", "护送提示")		# = reverseDisplay：点完这扇收起
