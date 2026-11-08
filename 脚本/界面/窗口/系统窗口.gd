extends RefCounted

const 设置页面场景 := preload("res://场景/界面/窗口/设置/设置窗口.tscn")
const 闭关页面场景 := preload("res://场景/界面/窗口/闭关/闭关窗口.tscn")
const 领取修行收益页面场景 := preload("res://场景/界面/窗口/闭关/领取修行收益.tscn")
const 挂机窗口 := preload("res://脚本/界面/窗口/挂机窗口.gd")
const 副本窗口 := preload("res://脚本/界面/窗口/副本窗口.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 富文本 := preload("res://脚本/界面/富文本.gd")
const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 地图信息页面场景 := preload("res://场景/界面/窗口/地图信息/地图信息窗口.tscn")
const 地图NPC条目场景 := preload("res://场景/界面/组件/地图NPC条目.tscn")
const 排行榜页面场景 := preload("res://场景/界面/窗口/排行榜/排行榜窗口.tscn")
const 排行榜条目场景 := preload("res://场景/界面/组件/排行榜条目.tscn")
const 礼包兑换页面场景 := preload("res://场景/界面/窗口/兑换/礼包兑换窗口.tscn")

var 窗口

## 修行那一族两扇**建一次、之后只往件里塞数**（原版口径，见 `_render_retreat` 里那条长注释）。
## 一扇窗一个 `系统窗口` 实例（`功能窗口.gd:368`），所以这两个字段天然只对自己那一页有效。
var 修行页: Control
var 修行页是右窗 := false
var 修行帧连过 := false

var _session:
	get: return 窗口._session
var _status:
	get: return 窗口._status
var _settings_tab:
	get: return 窗口._settings_tab
	set(value): 窗口._settings_tab = value
var _map_view_tab:
	get: return 窗口._map_view_tab
	set(value): 窗口._map_view_tab = value
var _ranking_tab:
	get: return 窗口._ranking_tab
	set(value): 窗口._ranking_tab = value
## 排行榜「第几页」= 原版 `changeTab(p)` 的那个 p：**0 = 忍界榜、1 = 同级榜**
## （不是 PageComponent 的页号；页号是下面的 `_排行码`）。
var _排行页:
	get: return 窗口._排行页
	set(value): 窗口._排行页 = value
## 原版 `PageComponent.currentPage − 1`（0 基存着，显示时才 +1）。
var _排行码:
	get: return 窗口._排行码
	set(value): 窗口._排行码 = value
func _init(宿主) -> void:
	窗口 = 宿主

func _instantiate_page(scene: PackedScene) -> Control:
	return 窗口._instantiate_page(scene)

func _configure_original_panel(panel: Panel, outer := false) -> void:
	窗口._configure_original_panel(panel, outer)

func _configure_label(label: Label, font_size: int, color: Color) -> void:
	窗口._configure_label(label, font_size, color)

func _configure_overlay_button(button: Button, button_size: Vector2) -> void:
	窗口._configure_overlay_button(button, button_size)

func _configure_standard_button(button: Button, 尺寸 := Vector2(57.0, 22.0)) -> void:
	窗口._configure_standard_button(button, 尺寸)

func _configure_value_input(input: LineEdit) -> void:
	窗口._configure_value_input(input)

func _apply_tab_skin(tab: Button) -> void:
	窗口._apply_tab_skin(tab)

func _apply_list_selection_skin(button: Button) -> void:
	窗口._apply_list_selection_skin(button)

func _bind_original_check(item: Control, label_text: String, key: String, default_value: bool, inverted: bool, settings: Dictionary) -> void:
	窗口._bind_original_check(item, label_text, key, default_value, inverted, settings)

func _render_shortcut_settings(parent: Control) -> void:
	窗口._render_shortcut_settings(parent)

func _render_more_settings(parent: Control, settings: Dictionary) -> void:
	窗口._render_more_settings(parent, settings)

func _set_settings_tab(index: int) -> void:
	窗口._set_settings_tab(index)

func _set_check(value: bool, key: String) -> void:
	窗口._set_check(value, key)

func _claim_retreat() -> void:
	窗口._claim_retreat()

func _original_content_panel() -> StyleBoxTexture:
	return 窗口._original_content_panel()

## 客户端一次只显示一个窗口，而原版是「修行设定与收益」与「领取修行收益」同时弹；
## 故用本窗口的按钮过渡到那一页（原版该窗口本身没有领取按钮）。
##
## ⚠ 2026-10-20 B2 之后两扇**真的**一起开了（`窗口管理.成对伴随`），这颗钮留着的唯一理由是
## 原版 `ShouyiWindow.as:112-119 onClickLingqu` 本身就有一颗"打开领取窗"的（只是 `:94` 显式
## `visible = false` 藏起来了）。走 `窗口管理` 那一路（而不是 `open_page`）才不会把本扇换页。
func _open_claim_page() -> void:
	var 管理: Node = 窗口.get_parent()
	if 管理 != null and 管理.has_method("打开或收起"):
		管理.call("打开或收起", "领取修行收益")
		return
	窗口.open_page("领取修行收益")

func _redeem_code(code: String) -> void:
	窗口._redeem_code(code)

func _refresh_current() -> void:
	窗口._refresh_current()

## 设置页（原版 `SystemConfigWindow` 423×424 的整框 1:1 移植，另一位开发者那一版）。
## 三步顺序**不能换**（他说明 §2 ①）：
##   ① `装配` —— 页面自己绑页签/复选/音量；
##   ② `_render_more_settings` —— 填第 4 枚页签「客户端」那一层（**它内部会把该层显形**）；
##   ③ `重摆层` —— ⚠️ 必须补：上一句把非原版层显形了，得让它重新按时间轴摆一次，
##      否则「客户端」层会压在原版件上。
func _render_settings() -> void:
	var settings: Dictionary = _session.game_settings
	var page := _instantiate_page(设置页面场景)
	page.call("装配", 窗口)
	窗口._render_more_settings(page, settings)
	page.call("重摆层")


func _render_retreat() -> void:
	# 这一页就是原版的「修行设定与收益」（见 数据/界面/窗口尺寸.json 的「闭关经验」条目，
	# 标题早已登记为改名后的名字）。文案与数值口径按真机参照
	# `测试/基线/原版界面/原版_修行收益.png` 与 2.2.3 的 BIGUAN 协议：
	#   累计时间  → 「你当前已经修行：N 小时 M 分钟」
	#   经验收益  → 「人物经验值」
	#   精华收益  → 「人物精华储量」（原版给的是查克拉精华，不是金币！）
	#   状态提示  → 「请注意：12小时以后修行将自动停止…」
	# 数据一律取服务端 1286 帧（游戏会话.修行收益状态()），不在客户端自算。
	var page := _instantiate_page(闭关页面场景)
	# ⚠ 外层这块**必须与右窗同一张皮**：原版两扇的 `cellBackground` 都是 `MYellow_background`
	#   （左 `BiGuanWindow.as:130-135`、右 `LingquBiguanShouyi.as:232-237`），它是**半透明**的暗底
	#   ⇒ 透过它能看到淡淡的世界背景（用户 10-20 说的"左页只是淡淡透明"）。
	#   原来这里走 `_configure_original_panel(…, true)` = 变体 `OrigLightPanel` = `浅色面板.png`
	#   = 元件 830 `Condition_backgroundSkin`（**另一张、偏亮的皮**）⇒ 整页发灰、透明度也不对。
	(page.get_node("外层面板") as Panel).add_theme_stylebox_override("panel", _original_content_panel())

	## ⚠ 这页**不许在回帧时被拆掉重建**（用户 2026-10-20 夜实机报「这一界面的按钮我点击还是没反应，
	## 根本点不动」的根因；取证 = `开发工具/量修行页命中.gd`，修前实测：一发 1286 帧之后页面换了实例号、
	## `购买`/`单倍领取` 在「按下→帧→抬起」时序下 `pressed` 0 次且件已被释放）。
	## 病灶在宿主：`功能窗口.gd:389-407` 把 `player_stats_changed` / `cultivation_changed` /
	## `inventory_changed` 等十几个会话信号都接到 `_refresh_current()` → `_render_page()`，
	## 而 `_render_page()` 开头把 `_content` 的 children 全 `remove_child + queue_free` ——
	## `BaseButton` 要按下与抬起落在**同一个节点**才发 `pressed`，所以每秒几十发的状态帧等于整页不响应。
	## 原版没有一句重建：`Client.as:4704-4706` 收到 1286 帧是 `biGuanWindow.setData(4 参)`
	## **塞进已经开着的那扇**，`BiGuanWindow.as:156-161` 再转 `shouyiWindow.setData(exp,zq)`
	## + `formatTimer(秒)`。⇒ 挂"自刷"旗（同 `挂机窗口.gd:167` 那面旗、同一个修法），数由
	## `_连修行帧()` 接帧原地刷进件里。键名必须 ASCII：Godot 4 的 metadata 键不收中文标识符（静默存不进）。
	page.set_meta("page_self_refresh", true)
	修行页 = page
	修行页是右窗 = false
	_连修行帧()

	# `BiGuanWindow.as:52` `unlockTf = getLabel(CN.BIGUAN_ZIDONG_KAIQI, 16777215, true)`
	# ⇒ 第三参是 **htmlText 开关**（`BaseUtil.as:436-456`：为真走 `htmlText`），
	#   所以颜色由**表里的 markup** 定：`<font color="#00ff00">` ⇒ **绿**
	#   （`16777215` 那参只是 TextField 的底色，被 markup 盖掉）。
	#   原文案「无论是离线与否…」是我自己编的，表里是「无论是否线上…」⇒ 照表改。
	_configure_label(page.get_node("开启提示") as Label, 12, Color("#00ff00"))
	(page.get_node("开启提示") as Label).text = "无论是否线上，你均会保持不停的成长"
	# `:136-141 _line = new LineHPicF(); x=11; y=66; width=245; height=2`
	# ⇒ **是素材里那张 `横向分隔线.png`（天然 252×2，两端是半透明渐隐）**，不是纯色块：
	#   原来这里画一条 `ColorRect #806047` 的实色线，两头没有渐隐、中间颜色也不对。
	#   `LineHPicF.as:6` 是 `extends Sprite`（不是 ScaleSprite）⇒ **九宫格无效**，
	#   按 AS3 那样整帧非等比拉到 245×2（场景里 `stretch_mode = 6`，边距表 [0,0,0,0]）。

	_configure_label(page.get_node("时间标题") as Label, 12, Color.WHITE)
	(page.get_node("时间标题") as Label).text = "你当前已经修行："
	var hour_value := page.get_node("小时值") as LineEdit
	var minute_value := page.get_node("分钟值") as LineEdit
	_configure_value_input(hour_value)
	_configure_value_input(minute_value)
	hour_value.editable = false
	minute_value.editable = false
	_configure_label(page.get_node("小时") as Label, 12, Color.WHITE)
	_configure_label(page.get_node("分钟") as Label, 12, Color.WHITE)
	# `BiGuanWindow.as:69-77` `regardTf.htmlText = CN.BIGUAN_QINGZHUYI`（红 `#FF0000`、
	# 盒宽 238、`wordWrap/multiline`、高 = `textHeight + 6`）⇒ **表里那个 `<br/>` 是硬换行**，
	# 不是"排到第二行"：第一句到"自动停止"为止，第二句从"届时"起。
	# 原文是半角冒号 `请注意:` 与繁体「儘」，逐字照抄（工程口径：文案只从表里取，不许我改字）。
	_configure_label(page.get_node("提示盒/说明") as Label, 12, Color("#FF0000"))
	(page.get_node("提示盒/说明") as Label).text = "请注意:12小时以后修行将自动停止\n届时请儘快领取收益，以便开始下一轮修行"

	var reward_panel := page.get_node("收益面板") as Panel
	_configure_original_panel(reward_panel)
	# `ShouyiWindow.as:77-78` `dangQianShouyiTf` = getLabel(CN.BIGUAN_DANGQIAN_SHOUYI, 白, htmlText)
	# ⇒ 表里 markup 是 `#ffffff` ⇒ **白**，不是原来那颗金黄 `#ffd27c`；冒号是**半角**（表里就是 `:`）。
	_configure_label(reward_panel.get_node("标题") as Label, 12, Color.WHITE)
	(reward_panel.get_node("标题") as Label).text = "你当前可领取的修行收益:"
	# `:79-84` `experienceLable`/`zhenQiLable` = `CN.SHOUYI_EXPERIENCE`/`SHOUYI_ZHENQI`
	# ⇒ 表里两条都带**全角冒号**（原来少了），字号 12（原来给了 10）。
	_configure_label(reward_panel.get_node("经验标题") as Label, 12, Color.WHITE)
	(reward_panel.get_node("经验标题") as Label).text = "人物经验值："
	_configure_label(reward_panel.get_node("金币标题") as Label, 12, Color.WHITE)
	(reward_panel.get_node("金币标题") as Label).text = "人物精华储量："
	var exp_value := reward_panel.get_node("经验") as LineEdit
	var 精华值 := reward_panel.get_node("金币") as LineEdit
	_configure_value_input(exp_value)
	_configure_value_input(精华值)
	exp_value.editable = false
	精华值.editable = false

	# `ShouyiWindow.as:86-94` 的顺序照搬：`:92` **先挂 CLICK**、`:93` addChild、`:94` 才
	# `visible = false` ⇒ 原版这颗钮是"接好了但藏着"，不是没有。同页 `:102` 那颗"攻略"同理。
	# 我们原来把它画出来还按分钟数置灰 = 自造；现在按原文：连上、藏起来。
	# （成对开窗已经把右边那扇一起开了，所以藏掉不影响"能不能领取"。）
	var claim := reward_panel.get_node("领取收益") as Button
	_configure_standard_button(claim)
	claim.text = "领取"
	claim.pressed.connect(_open_claim_page)
	claim.visible = false

	## 四个数只从 `填修行左窗值()` 这一个口子写进件里：建页时刷一次，回帧时原地刷也走它
	##（两份算式并存的话，改一处另一处会静默不一致 —— 10-19 挂机页就是这么漏过一次）。
	填修行左窗值(page)

	# 进页即向服务端要一次最新状态；离线时保持上面读到的本地缓存值。
	if _session.request_修行收益查询():
		pass

## 原版的「领取修行收益」弹窗（AS3 `LingquBiguanShouyi`，窗口 **267×218**，`:225-226`）。
## 逐件 x/y/w/h/字号/色**全在 `场景/界面/窗口/闭关/领取修行收益.tscn` 里按 §2 表烘死**，
## 这里只做三件事：填运行期的值、上色、连 handler。件位一个数都不在这份文件里。
## 文案逐字取语言表（`en_US$message_properties.as`），出处都标在下面每一行。
func _render_retreat_claim() -> void:
	var page := _instantiate_page(领取修行收益页面场景)
	# §2 行 3 `cellBackground` = `MYellow_background`(元件 10)，`:232-237` (6,39,255,146)
	(page.get_node("外层面板") as Panel).add_theme_stylebox_override("panel", _original_content_panel())
	# §2 行 4 `background3` = `MPane_background`(元件 97)，`:238-243` (11,85,245,94)
	# 主题的 Panel 基础样式就是 子面板.png ⇒ 只标 mouse_filter，不再套变体。
	(page.get_node("子面板底") as Panel).mouse_filter = Control.MOUSE_FILTER_IGNORE
	(page.get_node("经验底图") as Panel).mouse_filter = Control.MOUSE_FILTER_IGNORE
	(page.get_node("精华底图") as Panel).mouse_filter = Control.MOUSE_FILTER_IGNORE

	## ⚠ 与左边那一扇同一个旗、同一个道理：**回帧不许把这页拆掉重建**，否则三颗钮"根本点不动"
	##（取证与根因逐字见 `_render_retreat()` 上面那条注释）。原版的口径就是往开着的这扇里塞数：
	## `LingquBiguanShouyi.as:213-218 setData(exp,zq)` + `:187-193 updateIconContainer()`
	##（后者由 `ItemManager.as:362-364` 在包裹变化时调）。
	page.set_meta("page_self_refresh", true)
	修行页 = page
	修行页是右窗 = true
	_连修行帧()

	# §2 行 17 `hintTf`，`:162-171`：`htmlText = CN.BIGUAN_SHOUYI`（`:766` 双色原文），
	# wordWrap/multiline/selectable=false/mouseEnabled=false ⇒ RichTextLabel + BBCode。
	# 字号 12（`:168-169` 走 MLabel/BaseUtil 默认 12，`:219 _textFormat.size = 12`），
	# 本页查无 `leading` ⇒ 工程口径 leading 0 ⇒ Godot 行距 +2（真值文件《行距口径》那一段）。
	var 提示 := page.get_node("提示盒/提示") as RichTextLabel
	提示.text = 富文本.译文为BBCode(语言BIGUAN_SHOUYI)

	# §2 行 15 `shouyiTf` = `getLabel(CN.LINGQU_SHOUYI_RUXIA, 2003199)` ⇒ **蓝 `#1E90FF`**，
	# 不是黄的（B7；2003199 = 0x1E90FF）。`:155-156` (119,92,127,18)。
	_configure_label(page.get_node("收益标题") as Label, 12, Color("#1E90FF"))
	page.get_node("收益标题").text = 语言LINGQU_SHOUYI_RUXIA
	# §2 行 8/10：`LINGQU_SHOUYI_EXPERIENCE` = "人物经验值："（`:2811`）、
	# `LINGQU_SHOUYI_ZHENQI` = "人物精华储量："（`:2821`）—— **带全角冒号**（B8），色 `#FFFFFF`。
	for 名称 in ["经验标题", "精华标题"]:
		_configure_label(page.get_node(名称) as Label, 12, Color.WHITE)
	page.get_node("经验标题").text = 语言LINGQU_SHOUYI_EXPERIENCE
	page.get_node("精华标题").text = 语言LINGQU_SHOUYI_ZHENQI
	# §2 行 9/11：`_experience` / `_zhenQi` 是**纯 TextField**（`:118 mouseEnabled=selectable=false`、
	# `:129 textColor=#FFFFFF`），不是输入框 ⇒ Label；数字只从入参来，客户端不自算（`:215-220`），
	# 而"入参"由下面 `填修行右窗值()` 这一个口子写（建页与回帧原地刷共用同一个算式）。
	var 经验值 := page.get_node("经验值") as Label
	var 精华值 := page.get_node("精华值") as Label
	_configure_label(经验值, 12, Color.WHITE)
	_configure_label(精华值, 12, Color.WHITE)

	# §2 行 5 `iocnContaier` = `ItemWindowCell`，`:95-98` (21,94) 40×40。
	# B9/B10：**没有**独立的名字件与数量件 —— 数量是**格内角标**
	# （`ItemWindowCell.as:54-58 tf = (1,24,37,16)` autoSize=RIGHT、size12 `#FFFFFF`），
	# 名字走 tooltip，而且 tooltip 与 id 都**从表里取**：
	# id = `StringTool.as:799-802` 读 `ImgType.Etc` 的 `biguan.itemid`
	# ⇒ 工程同源表 `数据/原版杂项.json` 的 `biguan.itemid`（B11 不是"查无对照物"，这张表在）；
	# 名字 = `数据/物品.json` 该 id 的 `name`（B10）。格子本身可点（原版 `buttonMode`、
	# `singleClickHandler:137`），不再 `disabled = true`。
	var 密卷格 := page.get_node("密卷格") as Button
	密卷格.disabled = false
	var 角标 := page.get_node("密卷格/角标") as Label
	_configure_label(角标, 12, Color.WHITE)
	# 格里那三样（名字 tooltip / 图标 / 数量角标）与"没卷就整格套灰"都归
	# `填修行右窗值()` —— 原版这一族是 `updateIconContainer()`(`:187-193`)，
	# 由 `ItemManager.as:362-364` 在**包裹变化时**再调一次 ⇒ 我们接 `inventory_changed` 原地刷，
	# 不靠拆页重建。

	# §2 行 12 `buyBtn`，`:131-137` (22,143) `width = UIConfig.btn_width_two = 37`、
	# `isScale9Grid = false`（整帧非等比 ⇒ 高就是 upSkin 的 22）、文字 `CN.SHOP_BUY` = "购买"。
	var 购买 := page.get_node("购买") as Button
	_configure_standard_button(购买, Vector2(37.0, 22.0))
	购买.text = 语言SHOP_BUY
	# B12：原版 `:246-251 onClickBuyBtn` 派 `CashShopWindowEvent(REQUEST_CASH_ITEM_INFO)`，
	# 消费者 `game/ui/UI.as:197-205` 拿的是 **单件详情** `Client.requestCashItemInfo(id, 0)`，
	# 不是"打开商城页" ⇒ 接工程现成的同一个出口 `功能窗口.请求商城商品`（1086 单字段 = 物品 id）。
	# id 当场取（`修行密卷id()` 只读一张表）：这页现在建一次就活到关窗，闭包里不许再抓旧局部量。
	购买.pressed.connect(func(): 窗口.请求商城商品(修行密卷id()))

	# §2 行 13/14 三颗钮的第三、四颗：`btn_width_four = 61`、y=189；
	# 双倍那颗 x 是 `:153 cellBackground.x + width − 钮宽 − 29` = 6+255−61−29 = **171**
	# （`:146` 先写的 163 被 `:153` 覆盖，别照 163 摆）。
	# ⚠ **原版这三颗全程没有一句 `disabled`**（`:172-174` 只挂 CLICK 监听）
	# ⇒ 置灰是这工程自造的，本轮按"移植不是重做"撤掉，缺卷的反馈改成原文那句弹。
	var 单倍 := page.get_node("单倍领取") as Button
	var 双倍 := page.get_node("双倍领取") as Button
	for 按钮 in [单倍, 双倍]:
		_configure_standard_button(按钮, Vector2(61.0, 22.0))
	单倍.text = 语言BIGUAN_DANBEI_LINGQU
	双倍.text = 语言BIGUAN_SHUANGBEI_LINGQU
	单倍.pressed.connect(_claim_retreat_claim.bind(false))
	双倍.pressed.connect(_claim_retreat_claim.bind(true))

	填修行右窗值(page)

	# B13：原版三个入口在同帧**还派一条 `BiGuanWindowEvent(BIGUAN_GAIN)`**
	# （`ButtonsWindow.as:42-43` / `BreathPane.as:70-79` / `MessageTipPane2.as:226-229`）
	# ⇒ `UI.as:420-423 onBiguanGain → Client.requestQueryBiguanGain()` ⇒ **1284:2**。
	# 只在**开窗那一次**发（`_刚开窗`）：回帧引起的重渲染再发就成 发↔刷新 成环。
	# ⚠ 离线照旧**不许自算**：`游戏会话.get_retreat_rewards/claim_retreat_reward` 那道
	#   `_离线拒绝` 的封死（`:2723-2731`）保持不动，这里只是把查询发出去，数还是服务端给。
	if bool(窗口.get("_刚开窗")) and _session.request_修行收益查询():
		pass


## 服务端 1286 帧的四个数**原地**写进左页 —— 逐句对应原版
## `Client.as:4704-4706 onQueryBiguanResult → biGuanWindow.setData(秒, exp, zq, ?)`
## → `BiGuanWindow.as:156-161`：`shouyiWindow.setData(exp,zq)`（`:213-215` 两格收益）
## \+ `formatTimer(秒)`（`:81-88`：`hour = floor(秒/3600)`、`minute = floor((秒/3600 − hour)*60)`）。
## 建页与回帧原地刷**共用这一个口子**（两份算式并存迟早不一致）。
func 填修行左窗值(页: Control) -> void:
	var 状态: Dictionary = _session.修行收益状态()
	var 分钟总数: int = int(状态.get("seconds", 0)) / 60
	(页.get_node("小时值") as LineEdit).text = "%d" % (分钟总数 / 60)
	(页.get_node("分钟值") as LineEdit).text = "%d" % (分钟总数 % 60)
	(页.get_node("收益面板/经验") as LineEdit).text = str(int(状态.get("exp_gain", 0)))
	(页.get_node("收益面板/金币") as LineEdit).text = str(int(状态.get("zq_gain", 0)))


## 右页原地刷：两格收益 = `LingquBiguanShouyi.as:213-218 setData(exp,zq)`，
## 密卷格那三样 + 套灰 = `:187-193 updateIconContainer()`（原版由 `ItemManager.as:362-364`
## 在包裹变化时再调一次）。
## ⚠ 与原版的一处**已知不同**：原版这两格数字只在左窗那颗 `visible=false` 的领取钮
## （`ShouyiWindow.as:115-117`）被点时才塞，正常开着看是**空的**；本工程 10-20 起成对开窗、
## 且门钉的就是"数字显形"（`真值/窗口/修行收益.md` B2/B15），所以这里由 1286 帧直接塞。
func 填修行右窗值(页: Control) -> void:
	var 状态: Dictionary = _session.修行收益状态()
	(页.get_node("经验值") as Label).text = str(int(状态.get("exp_gain", 0)))
	(页.get_node("精华值") as Label).text = str(int(状态.get("zq_gain", 0)))
	var 密卷id := 修行密卷id()
	var 密卷数 := 背包密卷数量(_session, 密卷id)
	var 密卷格 := 页.get_node("密卷格") as Button
	密卷格.tooltip_text = String(游戏数据.item(密卷id).get("name", ""))
	var 图标 := String(游戏数据.item_icon_path(密卷id))
	密卷格.icon = load(图标) as Texture2D if not 图标.is_empty() and ResourceLoader.exists(图标) else null
	# `ItemWindowCell.setDataCount:57-60`：**只有 >0 才写数字**，0 的时候是空串，不是 "×0"。
	(页.get_node("密卷格/角标") as Label).text = str(密卷数) if 密卷数 > 0 else ""
	# `:189-191 updateIcon` 每次刷新都走 `iocnContaier.setFilters(isBagExisItem())`
	# ⇒ **没卷的时候整格套灰**（`ItemWindowCell.as:77-87`：`itemIcon.filters = Style.getDisableFilter()`，
	#   而 `itemIcon` 就是 `MGrid_background` 本体、图标是它的子件 ⇒ Flash 的 filter 连格底一起灰）。
	# 数量 `tf` 是**格的兄弟件**（`:54-58 addChild(this.tf)`）⇒ 不跟着灰。
	# Godot 侧 `material` 恰好也不传子件 ⇒ 只给格设一次就是原版的形状。
	密卷格.material = 窗口.禁用灰度材质() if 密卷数 <= 0 else null


## 这一族两扇自己接上"回帧 ⇒ 原地刷"（挂了 `page_self_refresh` 旗之后宿主就不会再拆页，
## 原来被拆页顺带刷掉的东西必须自己接上 —— 同 `挂机窗口.gd:63-76 _连会话()` 那条口径）。
## 只连一次：连第二次会让同一个回调挂两遍（`_render_page()` 每次开页都再走一遍建页函数）。
func _连修行帧() -> void:
	if 修行帧连过:
		return
	if _session == null:
		return			# 宿主还没进树：下次建页再连，不烧 `修行帧连过`
	修行帧连过 = true
	_session.cultivation_changed.connect(func(_种, _状) -> void: 刷修行页())
	_session.inventory_changed.connect(func(_包) -> void: 刷修行页())


func 刷修行页() -> void:
	if 修行页 == null or not is_instance_valid(修行页):
		return
	if 修行页是右窗:
		填修行右窗值(修行页)
	else:
		填修行左窗值(修行页)

## 密卷 id 的**唯一出处**（B11）：原版 `StringTool.get_FuZhuWuPin_id_BGF()`（`StringTool.as:799-802`）
## = `ImgUtil.getImg(ImgType.Etc, "biguan")` 再取 `itemid` ⇒ 工程同源导出表
## `数据/原版杂项.json` 的 `biguan.itemid`。查不到就返回空串（**不硬凑一个数**）。
## static：`功能窗口._claim_retreat_claim` 那侧（B4 缺卷判定）也调这一个，id 不落第二处。
static func 修行密卷id() -> String:
	var 段: Variant = 游戏数据.取表("原版杂项").get("biguan", {})
	if not (段 is Dictionary):
		return ""
	## ⚠ `数据/原版杂项.json` 里 `itemid` 是**整数** 16000003，而 JSON 解进 GDScript 一律是 **float**
	## ⇒ 直接 `str()` 拿到的是 "16000003.0"：非空、但拿去查物品表/图标表**全查空**
	##   （`游戏数据.item()` 只在 `is_valid_int()` 时才补零）⇒ 密卷格没图标、缺卷判定恒假，
	##   就是用户 10-20 那张原版对照图里"这一格是空的"的成因。`String(整数)` 那一族是另一种死法
	##   （静默空串）；两条都归下面这一个口径：整数一律先 `int()` 再 `str()`。
	return 密卷id串((段 as Dictionary).get("itemid", ""))

## Variant 物品 id → 表里能查到的**十进制串**。查不到（null / 空串 / 别的类型）就返回空串，
## **不硬凑一个数**（原版 `StringTool.get_FuZhuWuPin_id_BGF()` 查无也是空）。
static func 密卷id串(值: Variant) -> String:
	match typeof(值):
		TYPE_STRING:
			return String(值)
		TYPE_INT, TYPE_FLOAT:
			return str(int(值))
		_:
			return ""

## 原版 `API.dataCenter.isBagExistItem(id)`（`LingquBiguanShouyi.as:72/:192`）⇒ 背包里该 id 的总数。
## 注意原版的口径是"**有没有**"（`isBagExisItem():70-77` 只判 >0），数字只是拿给角标显示。
static func 背包密卷数量(会话: Node, 密卷id: String) -> int:
	if 密卷id.is_empty() or 会话 == null:
		return 0
	var 总数 := 0
	for 物品 in 会话.inventory:
		if 密卷id串(物品.get("id", "")) == 密卷id:
			总数 += int(物品.get("quantity", 1))
	return 总数


## 语言表原文（`en_US$message_properties.as`，逐字照抄，键号标在每条后面）。
const 语言BIGUAN_SHOUYI := "<font color=\"#ff9100\">只要在你的背包里有1个修行密卷，即可领取</font><br/><font color=\"#00ff00\">双倍修行收益</font>"		# :766
const 语言LINGQU_SHOUYI_RUXIA := "修行收益如下："			# :1431
const 语言LINGQU_SHOUYI_EXPERIENCE := "人物经验值："			# :2811
const 语言LINGQU_SHOUYI_ZHENQI := "人物精华储量："			# :2821
const 语言SHOP_BUY := "购买"						# :2225
const 语言BIGUAN_DANBEI_LINGQU := "单倍领取"				# :816
const 语言BIGUAN_SHUANGBEI_LINGQU := "双倍领取"				# :796
const 语言LINGQU_SHOUYI_SORRY_XIUXINGFU := "很抱歉,你的背包里没有修行密卷"	# :2986（B4 那句弹）

func _claim_retreat_claim(use_double: bool) -> void:
	# B4 = 原版 `drawShouyi:200-207`：只有**双倍**这一支判背包，缺卷就
	# `MDialog.showMessageDialog(CN.LINGQU_SHOUYI_SORRY_XIUXINGFU, stage)`（`:204`）然后 **return**
	# —— 事件根本不派发，领取也不发。工程这条链就是 `输入确认弹.弹消息`（`showMessageDialog` 的移植，
	# 宠物放生/快捷键窗都走它），不新造控件。
	# 判的是 `isBagExisItem()`（`:70-77`，即"有没有"），不是数量。
	if use_double and 背包密卷数量(_session, 修行密卷id()) <= 0:
		确认弹.弹消息(窗口.get("_overlay") as Control, 语言LINGQU_SHOUYI_SORRY_XIUXINGFU,
			func(_码: int) -> void: pass)
		return
	窗口._claim_retreat_claim(use_double)

## 挂机页整扇（原版 `GuaJiSettingWindow` 664×492）已经**切出来单独成件**：
## 版式在 `场景/界面/窗口/挂机/挂机窗口.tscn`（`开发工具/生成挂机场景.py` 从 AS3 链式重算生成），
## 逻辑与 1283/7779/1808 三条上行在 `脚本/界面/窗口/挂机窗口.gd`。
##
## ⚠ 别再往回抄那 83 行：它是 652×315 的自造版式（11 勾 + 2 输入 + 三块 Panel），
## 与原版四组 LeafBorder / 25 勾 / 6 下拉 / 3 输入 / 2 钮不是一回事；更关键的是那版把勾
## 只写进 `user://玩家设置.json`，**服务端那份 1283 角色配置表既没读过也没写过**，
## 而「生命低于 45% 自动吃药」这种数原版的默认是 **70%**（`GuaJiSettingInfoData.as:46/76`），
## 45/30 两个数在这工程的任何一份原版材料里都不存在。
func _render_auto_combat() -> void:
	挂机窗口.渲染(窗口)

func _render_copy() -> void:
	# 2026-10-04 合并「纲手三页」包：原版 `CopyWindow` 的逐件几何/皮/文案全在
	# `场景/界面/窗口/副本/副本窗口.tscn`（由 `开发工具/生成副本场景.py` 生成），
	# 运行期逻辑与"已进次数"数据源在 `脚本/界面/窗口/副本窗口.gd`。
	# 这里只留一行委派，别再往回抄（旧 57 行运行期建件版已删——
	# 那份"运行期摆 ItemList"正是「编辑器≠运行期」病根的又一实例）。
	副本窗口.渲染(窗口)



func _render_map_info() -> void:
	var page := _instantiate_page(地图信息页面场景)
	_configure_original_panel(page.get_node("内容框") as Panel, true)
	_configure_original_panel(page.get_node("地图面板") as Panel)
	_configure_original_panel(page.get_node("右侧面板") as Panel)
	for index in 2:
		var tab := page.get_node("分页/%s" % ["当前地图", "世界地图"][index]) as Button
		窗口.选页签(tab, index == _map_view_tab)
		_apply_tab_skin(tab)
		tab.pressed.connect(_set_map_view_tab.bind(index))
	var map_title := page.get_node("地图标题") as Label
	map_title.text = _session.get_map_name() if _map_view_tab == 0 else "忍界世界地图"
	_configure_label(map_title, 12, Color.WHITE)
	var map_id := page.get_node("寻路列表/地图编号") as Label
	map_id.text = "地图编号  %s" % _session.current_map_id
	var channel := page.get_node("寻路列表/当前线路") as Label
	channel.text = "当前线路  %d 线" % int(_session.current_channel)
	for label_path in ["X标签", "Y标签", "寻路列表/地图信息", "寻路列表/地图编号", "寻路列表/当前线路", "寻路列表/NPC标题"]:
		_configure_label(page.get_node(label_path) as Label, 10, Color("#ff9100") if label_path in ["X标签", "Y标签", "寻路列表/NPC标题"] else Color.WHITE)
	_configure_label(page.get_node("寻路列表/区域状态") as Label, 10, Color("#78d67a"))
	_configure_label(page.get_node("当前位置") as Label, 16, Color("#ff4b3e"))
	_configure_value_input(page.get_node("X坐标") as LineEdit)
	_configure_value_input(page.get_node("Y坐标") as LineEdit)
	for button_path in ["前往", "寻找NPC"]:
		var button := page.get_node(button_path) as Button
		_configure_standard_button(button)
		button.pressed.connect(func(): 窗口._show_hint("请在地图或右侧列表中选择寻路目标"))
	var npc_list := page.get_node("寻路列表/NPC列表") as VBoxContainer
	for npc in _session.get_map_npcs():
		var npc_button := 地图NPC条目场景.instantiate() as Button
		var title := String(npc.get("title", ""))
		npc_button.text = String(npc.get("name", npc.get("id", "")))
		if not title.is_empty():
			npc_button.text += "  [%s]" % title
		npc_button.tooltip_text = "(%d, %d)" % [int(npc.get("x", 0)), int(npc.get("y", 0))]
		npc_button.pressed.connect(_select_map_target.bind(npc_button.text))
		npc_list.add_child(npc_button)

func _set_map_view_tab(index: int) -> void:
	_map_view_tab = index
	_refresh_current()

func _select_map_target(target_name: String) -> void:
	窗口._show_hint("已选择寻路目标：%s" % target_name)

## ── 排行榜页（原版 `RankWindow2` 整扇）─────────────────────────────────
## 这一页**没有一处文案是自己写的**：23 条榜单、列头、规则、"同级榜"页签显不显，
## 全部由 `Etc.PaiHangBang` 里被选中的那一条驱动
## （`RankWindowManager.getRankEtcData:103-153` + `RankWindow2.selecteRankMenu:230-254`）。
## 旧版这里烘的是四枚自造页签（个人等级/战斗力/宠物/家族）+ 一套自造的"我的排名"黄字，
## 而且**离线的拿好友表现造假榜** —— 那是编数据，不是还原（用户报修 5，见 §3.254）。

## 原版 `myRank` 那一句是**双色 htmlText**（`queryMyRank:100` + `CN.RANK_MY_RANK:1912`），
## `%1` 由 `CN.replaceString` 逐个替换（`CN.as:5392-5404`）⇒ 这里先替 `%1` 再过 BBCode。
const 语言RANK_MY_RANK := '<font color="#ff9100">你的当前排名：</font><font color="#ffffff">%1</font>'
const 语言RANK_MY_RANK_NOT_ENOUGH := "未上榜"					# :2618
const 语言RANK_LIST_RANK_NAME := "排名"						# :491（第一列**固定**，不随榜变）
const 语言RANK_LIST_NAME := "姓名"							# :2159（showType==0）
const 语言RANK_LIST_PET_OWNER := "宠物主人"					# :400 （showType!=0）
const 语言RANK_WINDOW_TIP := "【每日凌晨6点更新排行资料】"		# :1022
const 语言RANK_LIST_RENJIE_BANG := "忍界榜"					# :592
const 语言RANK_LIST_TONGJIE_BANG := "同级榜"					# :1778
const 语言榜单标题 := "榜单"									# LangUtilUI UI_5（`ui` 包）
const 语言排行规则标题 := "排行规则"							# LangUtilUI UI_41
## 一页 10 行 = `PageComponent(50, 10)` 的第 2 参 `_pageItems`（`PageComponent.as:56`）。
const 排行每页 := 10
## ⚠ 原版 `PageComponent` **构造期**就把 `_totalItems` 当 50 使（`:55/58`
##   `_totalPage = ceil(50/10) = 5`），而 `_pageComponent.reset()` 要**等第一帧回包**才调
##   （`RankWindow2.setData:366`）⇒ 回帧之前那一格真的是"1/5"、而且**下一页/末页是亮的**
##   （`setBtnEnabled:112-115`），点下去 `listData` 还是 null ⇒ 页上空白。
##   这不是 bug，是原版的既成观感，照抄、不"顺手改成 1/1"。
const 构造期总件 := 50


## 左侧那 23 条菜单（`Etc.PaiHangBang` 整段 = `数据/原版杂项.json` 的 `PaiHangBang`）。
## 行序 = **键的数值升序**（`getRankEtcData:121-125` 先把键收进数组、再 `sort(NUMERIC)`），
## 不是 JSON 里的书写序（书写序会把 "10" 排到 "2" 前面）。`menuId` 就是那个键
## （`:130 rankMenuId = int(_loc7_)`），条里**没有**这个字段，得自己补 ⇒ 所以是副本、不改原表。
static func 榜单定义() -> Array:
	var 表: Dictionary = 游戏数据.取表("原版杂项").get("PaiHangBang", {}) as Dictionary
	var 键: Array = 表.keys()
	键.sort_custom(func(a, b): return int(String(a)) < int(String(b)))
	var 出: Array = []
	for 名 in 键:
		var 条 := Dictionary((表[名] as Dictionary).duplicate(true))
		条["menuId"] = int(String(名))
		出.append(条)
	return 出


## 当前榜那一格收到的最后一帧：`{"rows": [...], "rank": int, "江湖": bool}`，没回帧 ⇒ `{}`。
## ⚠ 判"有没有回帧"用 `has("rows")`，**不能用行数是否为空** —— 服务端真给空表时
##   `rows` 存在但长度为 0，原版那时显示的是 "1/0"（`reset(0,10)` ⇒ `_totalPage=0`），
##   跟"还没回帧"的 "1/5" 是两种状态（`fake_flash_server.py:27518` 空表写 `-`，会走到前者）。
func _排行帧() -> Dictionary:
	if 窗口._backend == null:
		return {}
	return (窗口._backend.authoritative_rankings.get(_ranking_tab, {}) as Dictionary)


func _render_ranking() -> void:
	var page := _instantiate_page(排行榜页面场景)
	_configure_original_panel(page.get_node("外框") as Panel, true)
	_configure_original_panel(page.get_node("榜单框") as Panel)
	var 定义 := 榜单定义()
	if 定义.is_empty():
		# 空表 = 导出坏了。这里**不**退回"随便画四条页签"：那正是旧版自造榜的起点。
		push_error("排行榜：`数据/原版杂项.json` 的 PaiHangBang 段读不到 ⇒ 整页只能留空壳")
		return
	var 条 := 定义[clampi(_ranking_tab, 0, 定义.size() - 1)] as Dictionary
	# 左栏两块标题 = `BaseUtil.getLabel2(文字, 宽)`（`RankWindow2:449/465`）：
	# 默认色 **`16773120` = `#FFF000`**、字号 12、**不设 align**（盒左对齐）。
	# 旧版写成 `#ffd27c` 是自造的暖黄，差得挺远。
	for 名 in ["分类标题", "规则标题"]:
		_configure_label(page.get_node(名) as Label, 12, Color("#FFF000"))
	# 右上那行提示 = `BaseUtil.getLabel(RANK_WINDOW_TIP, UI_GREEN, true)`（`:189`）
	# ⇒ **绿 `#00FF00`、12 号、居中**（`getLabel` 不碰字号 ⇒ MLabel 默认 12；旧版给的 10）。
	_configure_label(page.get_node("提示") as Label, 12, Color("#00ff00"))
	(page.get_node("提示") as Label).text = 语言RANK_WINDOW_TIP
	(page.get_node("分类标题") as Label).text = 语言榜单标题
	(page.get_node("规则标题") as Label).text = 语言排行规则标题
	_渲染榜单菜单(page, 定义)
	_渲染排行规则与页签(page, 条)
	_渲染排行表头(page, 条)
	var 帧 := _排行帧()
	_渲染排行行(page, 帧)
	_渲染我的排名(page, 帧)
	_渲染排行翻页(page, 帧)


func _渲染榜单菜单(page: Control, 定义: Array) -> void:
	var 容器 := page.get_node("榜单滚动/榜单容器") as VBoxContainer
	for 旧 in 容器.get_children():
		容器.remove_child(旧)
		旧.queue_free()
	var 选中 := clampi(_ranking_tab, 0, 定义.size() - 1)
	for index in 定义.size():
		var 条 := 定义[index] as Dictionary
		var 钮 := Button.new()
		# 每条 90×20（`RankMenuCell2.initUI:39-53` 的 `selectedBg 90×20` +
		# `createRankMenu:322` 的 `y += 高`）⇒ 23 条 460 高，123 的 ScrollPane 里**必须滚**。
		钮.text = String(条.get("name", ""))
		_apply_list_selection_skin(钮)
		钮.toggle_mode = true
		钮.button_pressed = index == 选中
		钮.custom_minimum_size = Vector2(90, 20)
		钮.focus_mode = Control.FOCUS_NONE
		# 字色：这条 label 是 `getLabel("", UI_ORANGE, true)` 建的（`RankMenuCell2:47`），
		# 选中/悬停**只换底图、不改字色**（`selected` 那个 setter 只动 `selectedBg.visible`）
		# ⇒ 四档全钉橙 `#FF9100`，别跟着皮肤表的"列表项按下色"漂成白。
		for 态 in ["font_color", "font_hover_color", "font_pressed_color",
				"font_hover_pressed_color", "font_focus_color"]:
			钮.add_theme_color_override(态, Color("#FF9100"))
		钮.add_theme_font_size_override("font_size", 12)
		钮.pressed.connect(_set_榜单.bind(index))
		容器.add_child(钮)


## 规则那一坨 + 忍界榜/同级榜两枚页签 —— 三件事在原版里由**同一处**决定，所以放一起：
## `selecteRankMenu:239-253`（tongJi 显隐、`_ruleText = descs[0]`、末尾强制 `changeTab(0)`）
## 与 `changeTab:296-303`（`_ruleText = descs[p]` + 互斥的 selected/enabled）。
## `descs` = `[desc]` + `[tongDesc 若有]`（`getRankEtcData:141-145`）⇒ 23 条里**只有
## menuId 0（等级排行榜）没有 tongDesc** ⇒ 只有那一榜藏掉「同级榜」页签。
func _渲染排行规则与页签(page: Control, 条: Dictionary) -> void:
	var 文案: Array = [String(条.get("desc", ""))]
	if 条.has("tongDesc"):
		文案.append(String(条["tongDesc"]))
	(page.get_node("规则") as Label).text = String(文案[clampi(_排行页, 0, 文案.size() - 1)])
	var 忍界 := page.get_node("榜单分页/忍界榜") as Button
	var 同级 := page.get_node("榜单分页/同级榜") as Button
	同级.visible = 文案.size() > 1
	忍界.text = 语言RANK_LIST_RENJIE_BANG
	同级.text = 语言RANK_LIST_TONGJIE_BANG
	for 组 in [[忍界, 0], [同级, 1]]:
		var 钮 := 组[0] as Button
		窗口.选页签(钮, _排行页 == int(组[1]))
		_apply_tab_skin(钮)
		钮.pressed.connect(_set_排行页.bind(int(组[1])))


func _渲染排行表头(page: Control, 条: Dictionary) -> void:
	# 三枚列头都由 `RankListPane2.cretateLabel(..., 默认 16777215)` 建 ⇒ **白、12 号、居中**。
	# 旧版给的是 `#e7c37a` 米黄，原版没有这个色。
	for 名 in ["名次标题", "名称标题", "数值标题"]:
		_configure_label(page.get_node(名) as Label, 12, Color.WHITE)
	# 第一列**固定**"排名"（`initUI:131`）；后两列 `setListTitle` 现场填
	# （`selecteRankMenu:248-251`）⇒ 第二列按 `showType` 换「姓名 / 宠物主人」，
	# 第三列 = 该榜的 `valueName`（23 条里只有 menuId 2 宠物身价榜是 showType=1）。
	var 是角色 := int(条.get("showType", 0)) == 0
	(page.get_node("名次标题") as Label).text = 语言RANK_LIST_RANK_NAME
	(page.get_node("名称标题") as Label).text = 语言RANK_LIST_NAME if 是角色 else 语言RANK_LIST_PET_OWNER
	(page.get_node("数值标题") as Label).text = String(条.get("valueName", ""))


func _渲染排行行(page: Control, 帧: Dictionary) -> void:
	var 容器 := page.get_node("排行榜列表") as Control
	for 旧 in 容器.get_children():
		容器.remove_child(旧)
		旧.queue_free()
	# `_listData` 在**首帧之前是 null** ⇒ `requestData` 只 `removeCellData()`、一行不画
	# （`RankListPane2:84-101`）。那时翻页条却还显示 1/5 且能点 —— 照抄（见 构造期总件）。
	if not 帧.has("rows"):
		return
	var 行: Array = 帧.get("rows", []) as Array
	var 页 := _排行页序(行.size())
	var 起 := (页 - 1) * 排行每页
	var 止 := mini(起 + 排行每页, 行.size())
	for i in range(起, 止):
		var 记录 := 行[i] as Dictionary
		# 名次 = `(currentPage - 1) * 10 + (i + 1)`（`requestData:93`），i 是**页内下标**
		# ⇒ 展开就是**全表下标 + 1**。原版那 10 枚 cell 是 `initUI` 里一次性建好的
		# （`y = 23, 46, …`，步长 `高 25 − 2 = 23`），这里只画当页那几条、摆位同一口径。
		var 名次 := i + 1
		# ⚠ 色按**名次**、整行三列同色（`setData:44-59` + `setCellColor:131-134`）：
		#   1 红 / 2 绿 / 3 蓝 / 其余白。不是"前三行才染色"，也不是只有名次那列染色。
		var 色 := Color("#ff0000")
		if 名次 == 2:
			色 = Color("#00ff00")
		elif 名次 == 3:
			色 = Color("#1E90FF")
		elif 名次 > 3:
			色 = Color.WHITE
		var 条 := 排行榜条目场景.instantiate() as Control
		条.position = Vector2(0.0, float(i - 起) * 23.0)
		var 值 := {"名次": str(名次), "名称": String(记录.get("name", "")),
			"数值": String(记录.get("value", ""))}
		for 名 in 值:
			var 文 := 条.get_node(名) as Label
			文.text = String(值[名])
			_configure_label(文, 12, 色)
		容器.add_child(条)


## 「你的当前排名」—— 原版**不吃服务端回帧里那个 `rank`**：
## `RankWindowManager.onPaiHang_searchResult:86-92` 只把 `tabId/bool/行` 传给 `setData`，
## 名次是客户端**扫整张表找自己**算出来的（`queryMyRank:86-101`，`charId == stats.id` ⇒ `下标+1`，
## 找不到 ⇒ 「未上榜」）。⇒ 服务端那个数只存着给门钉，界面一律走扫表。
func _渲染我的排名(page: Control, 帧: Dictionary) -> void:
	var 文 := page.get_node("我的排名") as RichTextLabel
	if not 帧.has("rows"):
		return
	文.text = 富文本.译文为BBCode(语言RANK_MY_RANK.replace("%1", _我的名次(帧)))


func _我的名次(帧: Dictionary) -> String:
	if 窗口._backend == null:
		return 语言RANK_MY_RANK_NOT_ENOUGH
	# ⚠ "我的角色 id"只能从 `BackendConnection.character_id` 取：`player_stats` 里**没有 `id`**
	#   （同 `家族旗帜填充.gd:496` 那条口径，写成 `player_stats.get("id")` 会恒 0、人人"未上榜"）。
	var 我 := int(窗口._backend.get("character_id"))
	var 行: Array = 帧.get("rows", []) as Array
	for i in 行.size():
		if int((行[i] as Dictionary).get("char_id", -1)) == 我:
			return str(i + 1)
	return 语言RANK_MY_RANK_NOT_ENOUGH


## 当前页序（1 基，和原版 `PageComponent.currentPage` 同名同义）。
## 原版只在**回帧 reset** 和**点箭头**两处改它，从不因"换了个榜"而重算；但换榜之后
## 新榜的行数可能比旧榜少，那时照原样会翻到空白页 ⇒ 这里把显示用的页序夹进 `[1, 总页]`，
## 箭头那四枚的可点性与它保持一致（夹完仍然 100% 落在原版可达的状态里，不会多出原版没有的态）。
func _排行页序(总件: int) -> int:
	var 总页 := int(ceil(float(总件) / float(排行每页)))
	return clampi(_排行码 + 1, 1, maxi(总页, 1))


func _渲染排行翻页(page: Control, 帧: Dictionary) -> void:
	var 条 := page.get_node("分页条") as Control
	# 未回帧 ⇒ 用构造期的 50 件（见 构造期总件）；已回帧 ⇒ 用真实行数（**可以是 0 ⇒ "1/0"**）。
	var 有帧 := 帧.has("rows")
	var 总件 := (帧.get("rows", []) as Array).size() if 有帧 else 构造期总件
	var 总页 := int(ceil(float(总件) / float(排行每页)))
	var 页 := 1 if not 有帧 else _排行页序(总件)
	# 禁用判据逐字照 `setBtnEnabled:102-120`：前向两枚看 `currentPage > 1`、
	# 后向两枚看 `currentPage < totalPage`。**别用"目标页 == 当前页"** ——
	# 那样只有一页时下一页还是亮的（`功能窗口._渲染翻页条` 那条同款教训）。
	var 前向 := 页 > 1
	var 后向 := 页 < 总页
	var 目标 := {"首页": 1, "上一页": maxi(1, 页 - 1), "下一页": mini(总页, 页 + 1), "末页": 总页}
	for 名 in ["首页", "上一页", "下一页", "末页"]:
		var 按钮 := 条.get_node_or_null(名) as TextureButton
		if 按钮 == null:
			continue
		# 素材自然尺寸就是 18×13 / 15×13，与场景摆位**一格不差** ⇒ 不用设 stretch。
		按钮.disabled = not (前向 if 名 in ["首页", "上一页"] else 后向)
		# 禁用态 = **同一张图套灰度**（原版翻页钮也是 `MButton3` 系，`updateState` 对
		# DISABLED 走 `StyleUtil.getGrayFilter()`）；不是换一张灰图，也不是压暗。
		按钮.material = 窗口.禁用灰度材质() if 按钮.disabled else null
		按钮.pressed.connect(_翻排行页.bind(int(目标[名])))
	var 页码 := 条.get_node_or_null("页码") as Label
	if 页码 != null:
		# `currentPage` setter：`pageText.text = currentPage + "/" + totalPage`（`:98`）
		# 白字 12（`:149 textColor = 16777215`）—— 不是橙。
		页码.text = "%d/%d" % [页, 总页]
		_configure_label(页码, 12, Color.WHITE)


## 点箭头 —— 目标页序在 `_渲染排行翻页` 里已按 `__onArrowBtnClick:197-209` 夹好，这里只落地。
func _翻排行页(页: int) -> void:
	_排行码 = maxi(0, 页 - 1)
	_refresh_current()


func _set_榜单(index: int) -> void:
	窗口._set_榜单(index)


func _set_排行页(页: int) -> void:
	窗口._set_排行页(页)


func _render_exchange() -> void:
	var page := _instantiate_page(礼包兑换页面场景)
	_configure_original_panel(page.get_node("外框") as Panel, true)
	var prompt := page.get_node("提示") as Label
	_configure_label(prompt, 12, Color.WHITE)
	var input := page.get_node("兑换码输入") as LineEdit
	_configure_value_input(input)
	var exchange := page.get_node("兑换") as Button
	_configure_standard_button(exchange)
	var shop_tab := Button.new()
	shop_tab.text = "道具兑换"
	shop_tab.position = Vector2(22.0, 10.0)
	shop_tab.size = Vector2(82.0, 24.0)
	shop_tab.button_pressed = 窗口._exchange_mode == 0
	_apply_tab_skin(shop_tab)
	shop_tab.pressed.connect(func(): 窗口._exchange_mode = 0; 窗口._render_page())
	page.add_child(shop_tab)
	var code_tab := Button.new()
	code_tab.text = "礼品码"
	code_tab.position = Vector2(108.0, 10.0)
	code_tab.size = Vector2(72.0, 24.0)
	code_tab.button_pressed = 窗口._exchange_mode == 1
	_apply_tab_skin(code_tab)
	code_tab.pressed.connect(func(): 窗口._exchange_mode = 1; 窗口._render_page())
	page.add_child(code_tab)
	if 窗口._exchange_mode == 1:
		exchange.pressed.connect(func(): _redeem_code(input.text); input.clear())
		return
	prompt.text = "选择兑换："
	prompt.position = Vector2(30.0, 43.0)
	input.visible = false
	var offers: Array = 窗口._backend.authoritative_exchange if 窗口._backend != null and bool(窗口._backend.in_game) else []
	var selector := OptionButton.new()
	selector.position = Vector2(108.0, 40.0)
	selector.size = Vector2(190.0, 24.0)
	窗口._configure_option_button(selector)
	for offer in offers:
		selector.add_item("%s x%d" % [offer.get("name", "道具"), int(offer.get("quantity", 1))], int(offer.get("sn", 0)))
	var cost := Label.new()
	cost.position = Vector2(108.0, 68.0)
	cost.size = Vector2(238.0, 20.0)
	_configure_label(cost, 12, Color("#e7c37a"))
	var update_cost := func(index: int):
		if index < 0 or index >= offers.size():
			cost.text = "暂无可兑换项目"
			return
		var offer: Dictionary = offers[index]
		cost.text = "金币 %d  已兑 %d/%s" % [int(offer.get("need_gold", 0)), int(offer.get("single_exchanged", 0)), str(offer.get("character_limit", 0)) if int(offer.get("character_limit", 0)) > 0 else "不限"]
	selector.item_selected.connect(update_cost)
	update_cost.call(0 if not offers.is_empty() else -1)
	page.add_child(selector)
	page.add_child(cost)
	exchange.text = "兑换"
	exchange.position = Vector2(310.0, 40.0)
	exchange.size = Vector2(60.0, 24.0)
	exchange.disabled = offers.is_empty()
	exchange.pressed.connect(func():
		if selector.selected >= 0 and 窗口._backend != null:
			窗口._backend.request_exchange(selector.get_selected_id())
	)
