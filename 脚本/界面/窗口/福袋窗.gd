extends Control

## 原版「成就福袋」窗 —— `com/mxw/uifl/controls/success/SuccessWindow.as`（513 行）。
##
## 入口链（#74 之前**整条缺失**：双击 15008001 落到 `use_inventory_slot`，在线发一条
## USE_ITEM、离线回一句"要在服务端结算"，玩家连窗都看不到）：
##   `ItemWindow2.onItemDoubleClick` → `UI.useItem` → `StringTool.isFuDaiLeiItemByID(id)`
##   （`ItemWindow2.as:957-964`，排在决斗/梦幻灵芝之后、**礼包两支之前**）⇒
##   置 `SuccessManager.currItemID`、发 `ItemEvent.USE_FUDAI`、**当场 return**。
##   `UI.onFudai:1898-1901` → `Client.requestFudaiOpen(背包格位)`（`FudaiProcessor.as:216-222`
##   = writeByte(1) + writeInt(position)）。
##   ⚠️ 福袋**从不发 USE_ITEM**，件是服务端在 action 1 里扣的（`fake_flash_server.py:31903`
##   `_consume_bag_slot`），所以这扇窗的整条路上一次 `request_use_item` 都不该出现。
##
## **窗是回帧开的，不是点击开的**：`Client.onShowFudaiInfo:6582-6607` 先
## `if(!content.successWindow) reverseDisplay(SUCCESS_WINDOW_F)` 再 `setData(...)`；
## `onShowFudaiGainItemInfo:4575-4581` 只在**窗已存在**时 `setTakeData(...)`。
## ⇒ 调用点见 `功能窗口._收到福袋帧`。
##
## 版式（构造 `:108-155` + `newCell:157-216` + `newBackground:465-487`，坐标是**窗局部**）：
##   background  MWindow_background 274×306
##   奖品字      `getLabel2(UI_29 = "奖 品", 40)` @ (88,117) —— ⚠️ 它在**构造函数里先
##               `addChild`，背景是随后进的 `init()`**（`:111-115` vs `:465-487`）⇒
##               原版把它画在三层背景**底下**，靠背景自身半透明（实测 子面板.png 中心 a=129）
##               透出一点。这边同一顺序，不许"顺手"提到最上层。
##   background2 MYellow_background  @ (6,39) 262×263（= 宽 − 12）
##   background3 MPane_background    @ (64,100) 139×138
##   16 枚 `SuccessWindowCell` 40×40 摆成**一圈**（`cellArr` 序，全是窗的直接子件）：
##     上排 5 枚 x = 40·i + 11·i + 12 → 12/63/114/165/**216**，y=45
##     右列 3 枚 (221,98) (221,150) (221,202)
##     下排 5 枚 x = 221 − 51·i → 221/170/119/68/**17**，y=254
##     左列 3 枚 (12,202) (12,150) (12,98)
##   ⚠️ 右上 216 与右下 221、左下 17 与左上 12 这**两处 5px 不对称是原版的**（两组公式
##      各自取整的结果，`:166` 与 `:191`），不是抄错 —— 照抄，别"对齐"。
##   awardIocn   (84,133)；startBtn (147,128)；takeBtn (147,152) —— 两枚宽
##               `UIConfig.btn_width_two = 37`（`:964`），高按皮肤原生 22（`按钮.png` 57×22，
##               `MButton3.as:275` 没设高就取 `upSkin.height`）
##   checkBox_take  (82,180) 宽 109「开奖后自动领奖」；checkBox_start (82,201) 宽 109「领奖后自动开始」
##   标题 `init:124` 先给 `CN.SUCCESS_WINDOW_TITLE`，`setData:247` 立刻被
##   `StringTool.getItemString(currItemID)` **覆盖** ⇒ 玩家看到的是**物品名**（15008001 =「成就福袋」）。
##
## 格 = `SuccessWindowCell`（`SuccessWindowCell.as`）：`MGrid_background` 40×40 +
##   数量 `tf` **(2,22) 37×18 右对齐 12px 白 + `getGlowFilter(0)`（≈2px 黑描边）**
##   ⚠️ 与背包格 `ItemWindowCell` 的 (1,24)/37 不是同一套 ⇒ 场景里烘的那份要改几何。
##   提示框 `showToolTip:80-83` 传了第四个参数 `getEquipedItemById(value.id)` ⇒ 有对比列（§3.259）。
##   选中环 = `Mc_YellowIcon` @ (−3,−3)：**本工程没有这张素材**，又不能在脚本里现造
##   `StyleBoxFlat`（`测试/UI资源回归测试.gd:105` 钉死样式只能来自 `素材/界面/原版主题.tres`）
##   ⇒ 与 `活动窗口._补藏宝格子` 同法：四条 2px `ColorRect` 拼一枚 46×46 空心黄框。
##
## 三态闸（`setBtnEnabled:312-335`，状态语义 = 原版 `FudaiState`）：
##   0 待显示 ⇒ 两枚都关 + 清选中 + 停帧；1 已开出 ⇒ 开始开、领奖关；2 待停止 ⇒ 开始关、领奖开
##   ⚠️ `setData:252` 是 `if(param1) setBtnEnabled(param1)` ⇒ **状态 0 那一帧压根不调用它**，
##      钮保持上一次的档（链尾那条 `1289:1:0:-:-:1` 就是这么让「开始」留在亮着的 —— 原版如此）。
##
## 跑马灯（`setTakeData:345-364` + `enterFrame:392-430` + `startMove:372-384`）：
##   `randAccTime = MathAD.rnd(3,4)`（`MathAD.as:27-30` 两端**闭区间** ⇒ 3 或 4）
##   `total = randAccTime·16 + index`、`averageCount = total − 7 − 7`
##   起步 `count=0`、选中 `cellArr[0]`，每走一格 `++count; count%=16` ⇒ **恰好停在 `cellArr[index]`**
##   三段节奏：前 7 格按 `addArr=[100,80,60,40,40,30,20]` 等 `_nowpasttime` 命中（每帧 +10）
##     ⇒ 10/8/6/4/4/3/2 帧递减；中间 `(total−14)` 格**每帧一格**；末 7 格按
##     `minusArr=[20,40,50,80,100,110,120]` ⇒ 2/4/5/8/10/11/12 帧递增。全程 `total` 格。
##   帧 = 舞台 `ENTER_FRAME`，本工程按 §3.77.3 的定论 **60fps**（`Engine.as:13`）⇒ 下面用
##   `Timer.wait_time = 1/60`；门不真等时间，直接连调 `_滴答()`。
##   走完：停帧 + `setAwardData`（把定住那格的值抄进奖品格）+ 领奖钮开
##   + 「开奖后自动领奖」⇒ `yanshi_yingqu` 再数 6 帧点一次领奖（`:440-448` 的 `> 5`）
##   + 「领奖后自动开始」且开始钮可用 ⇒ 立即点开始。
##
## 背包满闸（`onClickStartBtn:450-463` / `onClickTakeBtn:281-310` 开头）：
##   `DataCenter.isPackgeFull():1043-1046` = `commonItems.length >= commonSlots` ⇒
##   `已占格数 >= 背包总格数`，满了只播 `CN.SUCCESS_WINDOW_PACK_FULL`「背包已经满了」，
##   **不发请求**（注意是 `>=`，和自选礼包那支的 `+1 >` 不是同一条算式）。
##   领奖还多三步：清选中、`nowindex=0`、`isBagExistItem(currItemID)`（`DataCenter:3166-3182`
##   = 同 id 件数**求和**）> 0 ⇒ `cleanAwardData()`（清奖品格 + 关领奖钮），否则只关领奖钮。
##   `takeBtn.isDelay = true`（`:153`）= 1000ms 防连点（`MButton3.as:41/568-579`，`startBtn` **没有**）。
##
## 协议面：本窗只发意图（`请求开始` / `请求领取`），发包在 `功能窗口`（同 `自选礼包窗` 的契约）。
## 领取的回包是通用物品/背包帧 + 下一只的 `1289:1` 状态帧，不在这里解。

signal 请求开始
signal 请求领取

const 界面皮肤 := preload("res://脚本/界面/窗口/界面皮肤.gd")
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 背包窗口 := preload("res://脚本/界面/窗口/背包窗口.gd")
const 物品格场景 := preload("res://场景/界面/组件/物品格.tscn")
const 物品提示场景 := preload("res://场景/界面/组件/物品提示框.tscn")
const 装备提示场景 := preload("res://场景/界面/组件/装备提示框.tscn")
const 格子提示框 := preload("res://脚本/界面/组件/格子提示框.gd")

const 子面板皮 := "res://素材/界面/原版窗口/通用控件/子面板.png"
const 关闭钮皮 := "res://素材/界面/原版窗口/通用控件/关闭按钮.png"

const 窗宽 := 274.0
const 窗高 := 306.0
const 黄底位 := Vector2(6.0, 39.0)
const 黄底宽 := 262.0				# `background.width - 12`
const 黄底高 := 263.0
const 子面板位 := Vector2(64.0, 100.0)
const 子面板宽 := 139.0
const 子面板高 := 138.0
const 奖品字位 := Vector2(88.0, 117.0)
const 奖品位 := Vector2(84.0, 133.0)
const 开始位 := Vector2(147.0, 128.0)
const 领奖位 := Vector2(147.0, 152.0)
const 钮宽 := 37.0					# `UIConfig.btn_width_two`
const 钮高 := 22.0					# `MButton3.as:275` 取 upSkin 原生高
const 勾领取位 := Vector2(82.0, 180.0)
const 勾开始位 := Vector2(82.0, 201.0)
const 勾宽 := 109.0
const 勾高 := 19.0					# `MCheckBox.as:81-82` `_height = upSkin.height` = 19×19 那张皮
const 关闭钮宽 := 25.0
const 关闭钮高 := 24.0
## `MWindow.as:27` `_startDragY = 29`：`SuccessWindow extends MWindow` 且没改 `isDrag`
## （`MWindow:68` 构造里 `isDrag = true`）⇒ 原版这扇窗**顶部 29px 能拖着走**。
const 拖动区高 := 29.0
const 环偏 := -3.0
const 黄 := Color("#ffd24a")
const 奖品字色 := Color("#fff000")		# `BaseUtil.getLabel2` 的默认色 16773120

## 一圈 16 枚的摆位（`cellArr` 序）—— 两处 5px 不对称照抄，见头注释。
const 环位: Array[Vector2] = [
	Vector2(12, 45), Vector2(63, 45), Vector2(114, 45), Vector2(165, 45), Vector2(216, 45),
	Vector2(221, 98), Vector2(221, 150), Vector2(221, 202),
	Vector2(221, 254), Vector2(170, 254), Vector2(119, 254), Vector2(68, 254), Vector2(17, 254),
	Vector2(12, 202), Vector2(12, 150), Vector2(12, 98),
]

const 加速表 := [100, 80, 60, 40, 40, 30, 20]		# `addArr:24`
const 减速表 := [20, 40, 50, 80, 100, 110, 120]		# `minusArr:98`
const 每帧刻度 := 10.0					# `time:96`，`_nowpasttime += time`

## 语言表逐字（`en_US$message_properties.as` / `en_US$ui_properties.as`）
const 初始标题 := "成就福袋"		# :2787 SUCCESS_WINDOW_TITLE（setData 会被物品名覆盖）
const 奖品字 := "奖 品"			# `LangUtilUI.get("UI_29")`，`en_US$ui_properties.as:78`（中间一个空格）
const 自动领奖字 := "开奖后自动领奖"	# :1854 SUCCESS_WINDOW_ZIDONG_LIJIANG
const 自动开始字 := "领奖后自动开始"	# :2749 SUCCESS_WINDOW_ZIDONG_KAISHI
const 开始字 := "开始"			# :1414 SELECT_CHAR_START
const 领奖字 := "领奖"			# :2815 PRIZE_BTN
const 背包满字 := "背包已经满了"		# :1633 SUCCESS_WINDOW_PACK_FULL

var _宿主: Node = null
var _会话: Node = null
var _物品id := ""
var _候选: Array = []
var _已得: Dictionary = {}
## 环上 16 格**当前显示**的那条（与 `_格们` 同序；空格 = 空字典）。
## `setAwardData:386-390` 从定住那格抄进奖品格，抄的就是它。
## ⚠️ 不挂在格上：`可拖拽格` 只有 `格子归属 / 槽位号 / 物品id / 可拖拽` 四个脚本变量，
##    `格.set("镜像条目", …)` 会当场 Invalid set。
var _格条: Array[Dictionary] = []
var _格们: Array[Button] = []
var _选中们: Array[Control] = []
var _奖品格: Button = null
var _开始钮: Button = null
var _领奖钮: Button = null
var _勾领取: CheckBox = null
var _勾开始: CheckBox = null
var _滴答定时: Timer = null

var _状态 := 0					# `_state`
var _亮格 := -1					# `curSelectCell`
var _落点 := -1					# `index`
var _总步 := 0					# `total`
var _均步 := 0					# `averageCount`
var _刻度 := 0.0				# `_nowpasttime`
var _加档 := 0					# `addArrIndex`
var _减档 := 0					# `minusArrIndex`
var _环序 := 0					# `count`
var _已走 := 0					# `nowindex`
var _延演 := -1					# `_yanshi`（-1 = 没挂上 `yanshi_yingqu`）
var _领奖上次点 := -1.0			# `MButton3._lastClikTime`（`isDelay` 1000ms）


## 建一次版式（同 `礼包详情窗._重建`：只建一次，数据来了只填不重建）。
func _建件() -> void:
	if _格们.size() > 0:
		return
	# 奖品字**先 add**（AS3 构造函数 `:111-115` 先 addChild，背景是随后 `init()` 才进的）
	# ⇒ 原版把它画在背景底下，靠半透明透出来。顺序照抄。
	var 奖字 := Label.new()
	奖字.name = "奖品字"
	奖字.text = 奖品字
	奖字.position = 奖品字位
	奖字.size = Vector2(40.0, 20.0)			# `getLabel2` 里 `setSize(w, 20)`
	奖字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	界面皮肤.configure_label(奖字, 12, 奖品字色)
	add_child(奖字)

	var 框 := Panel.new()
	框.name = "框"
	框.position = Vector2.ZERO
	框.size = Vector2(窗宽, 窗高)
	框.mouse_filter = Control.MOUSE_FILTER_IGNORE
	框.theme_type_variation = 皮肤表.变体_窗口边框
	add_child(框)

	var 标 := Label.new()
	标.name = "标题"
	标.text = 初始标题
	标.position = Vector2(0.0, 5.0)			# `MWindow._titleTextFieldY = 5`
	标.size = Vector2(窗宽, 18.0)
	标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	标.theme_type_variation = 皮肤表.变体_窗口标题
	add_child(标)

	# 拖动区（`MWindow.as:229` 顶部 29px）。⚠ 必须排在「关闭」**之前**：Godot 按子节点
	# 逆序派发输入，后加的关钮才收得到点击 —— 与 AS3 `onMouseDownHandler` 里
	# `if(param1.target is MButton) return` 同一条语义（点钮不拖窗）。
	var 拖 := Control.new()
	拖.name = "拖动区"
	拖.position = Vector2.ZERO
	拖.size = Vector2(窗宽, 拖动区高)
	add_child(拖)
	拖.gui_input.connect(_拖.bind(self))

	var 关 := Button.new()
	关.name = "关闭"
	关.position = Vector2(窗宽 - 关闭钮宽 - 6.0, 6.0)
	关.size = Vector2(关闭钮宽, 关闭钮高)
	关.focus_mode = Control.FOCUS_NONE
	关.flat = true
	关.icon = load(关闭钮皮) as Texture2D if ResourceLoader.exists(关闭钮皮) else null
	关.pressed.connect(隐藏)
	add_child(关)

	var 黄底 := Panel.new()
	黄底.name = "黄底"
	黄底.position = 黄底位
	黄底.size = Vector2(黄底宽, 黄底高)
	黄底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	黄底.theme_type_variation = 皮肤表.变体_内容面板
	add_child(黄底)

	# `MPane_background`（符号 97 = `通用控件/子面板.png`）主题里**没有注册变体**
	# ⇒ 按 `二级密码窗.gd:251-264` 那条口径用 NinePatchRect + 真图（margin 同 洗点窗 那枚）。
	var 面板 := NinePatchRect.new()
	面板.name = "子面板"
	面板.texture = load(子面板皮) as Texture2D if ResourceLoader.exists(子面板皮) else null
	面板.position = 子面板位
	面板.size = Vector2(子面板宽, 子面板高)
	面板.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## ⚠️ `patch_margin_*` 是 **int** 属性：收到 float 整条建件都中止。
	面板.patch_margin_left = 8
	面板.patch_margin_right = 7
	面板.patch_margin_top = 7
	面板.patch_margin_bottom = 7
	add_child(面板)

	for 序 in 环位.size():
		var 格 := _建格("格_%d" % 序)
		格.position = 环位[序]
		add_child(格)
	_格条.resize(环位.size())			# 与 `_格们` 同序；没填的格留空字典
	_奖品格 = _建格("奖品格")
	_奖品格.position = 奖品位
	add_child(_奖品格)

	_勾领取 = _建勾("勾领取", 自动领奖字, 勾领取位)
	add_child(_勾领取)
	_勾开始 = _建勾("勾开始", 自动开始字, 勾开始位)
	add_child(_勾开始)

	_开始钮 = _建钮("开始", 开始字, 开始位)
	_开始钮.pressed.connect(_点开始)
	add_child(_开始钮)
	_领奖钮 = _建钮("领奖", 领奖字, 领奖位)
	# ⚠️ `takeBtn.isDelay = true`（`:153`）= 1000ms 防连点；`startBtn` **没有**这一档。
	_领奖钮.pressed.connect(_点领奖)
	add_child(_领奖钮)
	_置钮态(0)

	_建提示框()


func _建格(名: String) -> Button:
	var 格 := 物品格场景.instantiate() as Button
	格.name = 名
	格.focus_mode = Control.FOCUS_NONE
	# `SuccessWindowCell` 只悬停出提示框、不接点击、不参与拖拽（AS3 只有 `buttonMode`）。
	格.set("可拖拽", false)
	# 场景烘的 `数量` 是背包格 `ItemWindowCell` 的 (1,24)/37 —— 本窗是
	# `SuccessWindowCell.tf`：(2,22)、宽 37、高 18、右对齐 12 号白 + 2px 黑描边。
	var 数量 := 格.get_node("数量") as Label
	数量.offset_left = 2.0
	数量.offset_top = 22.0
	数量.offset_right = 39.0
	数量.offset_bottom = 40.0
	数量.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	界面皮肤.configure_label(数量, 12, Color.WHITE)
	数量.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	数量.add_theme_constant_override("outline_size", 2)
	# 选中环（`Mc_YellowIcon` @ −3,−3，素材缺失 ⇒ 四条 2px ColorRect，同 `活动窗口`）。
	var 选中 := Control.new()
	选中.name = "选中"
	选中.position = Vector2(环偏, 环偏)
	选中.size = Vector2(46.0, 46.0)
	选中.mouse_filter = Control.MOUSE_FILTER_IGNORE
	选中.visible = false
	for 边 in ["上边", "下边", "左边", "右边"]:
		var 线 := ColorRect.new()
		线.name = 边
		线.color = 黄
		线.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match 边:
			"上边":
				线.size = Vector2(46.0, 2.0)
			"下边":
				线.position = Vector2(0.0, 44.0)
				线.size = Vector2(46.0, 2.0)
			"左边":
				线.size = Vector2(2.0, 46.0)
			"右边":
				线.position = Vector2(44.0, 0.0)
				线.size = Vector2(2.0, 46.0)
		选中.add_child(线)
	格.add_child(选中)
	_格们.append(格)
	_选中们.append(选中)
	return 格


func _建勾(名: String, 文: String, 位: Vector2) -> CheckBox:
	var 勾 := CheckBox.new()
	勾.name = 名
	勾.text = 文
	勾.position = 位
	勾.size = Vector2(勾宽, 勾高)
	勾.focus_mode = Control.FOCUS_NONE
	# `MCheckBoxF` 的 `isScale9Grid = false`（`:128/:136`）⇒ 框 + 字按原生宽摆，不拉伸。
	勾.button_pressed = false
	return 勾


func _建钮(名: String, 文: String, 位: Vector2) -> Button:
	var 钮 := Button.new()
	钮.name = 名
	钮.text = 文
	钮.position = 位
	# ⚠️ 两件都要：不在 Container 里时 `custom_minimum_size` **不会**撑开 `size`
	#    ⇒ 只调 helper 会得到一枚 0×0 的钮（口径同 `礼包详情窗:277-279`）。
	钮.size = Vector2(钮宽, 钮高)
	界面皮肤.configure_standard_button(钮, Vector2(钮宽, 钮高))
	return 钮


func _建提示框() -> void:
	for 项 in [["物品提示框", 物品提示场景], ["装备提示框", 装备提示场景]]:
		var 名 := String(项[0])
		if get_node_or_null(名) != null:
			continue
		var 框 := (项[1] as PackedScene).instantiate() as Control
		框.name = 名
		框.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(框)


## 挂上窗体并备好版式。`宿主` = `功能窗口`（`格子提示框.接线` 要它的 `_session` / `_舞台尺寸()`）。
## 只建一次：`设数据`/`设落点` 反复进来时**只填不重建**（同 `礼包详情窗._重建` 的口径，
## 原版 `SuccessWindow` 也是 `init()` 一次、之后只 `setCellValue`）。
func 接线(宿主: Node) -> void:
	_宿主 = 宿主
	_会话 = 宿主.get("_session") as Node if 宿主 != null else null
	size = Vector2(窗宽, 窗高)
	_建件()


## ═══ `setData:240-279` ═══
## `状态` = 帧里的 readByte（0/1/2）；`已得` = 那一格已中的件（`-` ⇒ 空字典）；
## `候选` = 16 件；`物品id` = `SuccessManager.currItemID`（标题用它）。
## ⚠️ AS3 的 `ItemNode` 是**先 new 再 decode**（`actionShowFudaiInfo:163`），`if(param2)` 恒真；
##    文本桥把"没有已得件"编码成 `-` ⇒ 这里以**字典空/非空**当 `param2` 的真假，
##    与链尾那条 `1289:1:0:-:-:1` 的意图一致（否则自动领奖那一支会在没有奖的时候也点一次）。
func 设数据(状态: int, 已得: Dictionary, 候选: Array, 物品id: String) -> void:
	_建件()
	_状态 = 状态
	_已得 = 已得
	_候选 = 候选
	_物品id = 物品id
	# `title = StringTool.getItemString(currItemID)` —— 覆盖掉构造里的 CN 标题。
	var 定义: Dictionary = 游戏数据.item(_物品id.pad_zeros(8) if _物品id.is_valid_int() else _物品id)
	(get_node("标题") as Label).text = String(定义.get("name", 初始标题))
	if _状态 != 0:
		_置钮态(_状态)
	for 序 in mini(_候选.size(), _格们.size()):
		var 条: Dictionary = _候选[序] as Dictionary
		_格条[序] = 条						# `SuccessWindowCell.value`（`setAwardData` 抄它）
		_填格(_格们[序], 条)
		_设件数(_格们[序], int(条.get("quantity", 1)))		# `setItemCount:432-438` 只在 >1 时写
	if not _已得.is_empty():
		_填格(_奖品格, _已得)
		_设件数(_奖品格, int(_已得.get("quantity", 1)))
	if _勾领取.button_pressed and not _已得.is_empty():
		_点领奖()
	elif _勾开始.button_pressed and _已得.is_empty():
		_自动开始()


## ═══ `setTakeData:345-364` ═══
## 服务端抽完这一格后回 `1289:2:<state>:<index>`（`actionShowFudaiGainItemInfo:102-121`）。
func 设落点(状态: int, 落点: int) -> void:
	_落点 = 落点
	_状态 = 状态
	_置钮态(状态)
	# AS3 紧接着无条件 `this.takeBtn.enabled = false`（`:349`）—— 领奖要等跑完才开。
	_领奖钮.disabled = true
	if 状态 == 0:
		return
	if _落点 < 0 or _落点 >= 环位.size():
		# 原版这里会一路 `startMove` 到 `minusArrIndex` 越界、`undefined == _nowpasttime` 永假
		# ⇒ 帧循环空转到天荒地老。越界是服务端的事，这边按"什么都不演"收，并把钮留在
		# `setBtnEnabled(状态)` 那一档，不骗玩家说中奖了。
		return
	_亮格 = 0
	_摆选中()
	# `MathAD.rnd(3,4)`（`MathAD.as:27-30` = `floor(rand()*(b-a+1))+a`）⇒ **闭区间**，3 或 4。
	var 圈数 := randi_range(3, 4)
	_总步 = 圈数 * 16 + _落点
	_均步 = _总步 - 加速表.size() - 减速表.size()
	_刻度 = 0.0
	_加档 = 0
	_减档 = 0
	_环序 = 0
	_已走 = 0
	_延演 = -1
	_起滴答()


## 一帧 = 原版一次 `ENTER_FRAME`。门直接连调这里，不真等 60fps。
func _滴答() -> void:
	if _延演 >= 0:
		# `yanshi_yingqu:440-448`：数到 `> 5` 才点（⇒ 第 6 帧），点完摘掉这个监听。
		_延演 += 1
		if _延演 > 5:
			_延演 = -1
			_停滴答()
			_点领奖()
		return
	_走格子()


## ═══ `enterFrame:392-430` 逐句 ═══
## 三段算式在数学上恰好走完 `total` 格：前 7 格（`nowindex 0→7`）+ 中间 `均步 + 1` 格
## + 末 7 格里最后那一格落在 `nowindex == total` ⇒ `7 + (total−14+1) + 6 = total`。
## 所以 `减速表` 的 7 档刚好用完、**不会越界**（原版越界那条 `undefined == _nowpasttime`
## 的死循环分支在这里不可达，不写防御）。
func _走格子() -> void:
	_刻度 += 每帧刻度
	if _已走 < 加速表.size():
		if _刻度 == float(加速表[_加档]):
			_移一格()
			_加档 += 1
	elif _已走 <= _均步 + 加速表.size():
		_移一格()
	elif _刻度 == float(减速表[_减档]):
		_移一格()
		if _已走 == _总步:
			# `:412-414` 摘帧 + `setAwardData` + 开领奖钮，再按两个勾选演后续。
			_停滴答()
			_奖品落定()
			_领奖钮.disabled = false
			if _勾领取.button_pressed:
				# `:418-421` 另挂一条 `yanshi_yingqu`，数到 `> 5` 才点 ⇒ 第 6 帧。
				_延演 = 0
				_起滴答()
			if _勾开始.button_pressed and not _开始钮.disabled:
				_点开始()
		_减档 += 1


## `startMove:372-384`：先灭旧环，`++count; ++nowindex; count %= 16`，点亮新格，刻度归零。
func _移一格() -> void:
	if _亮格 >= 0:
		_亮格 = -1
		_摆选中()
	_环序 = (_环序 + 1) % 环位.size()
	_已走 += 1
	_亮格 = _环序
	_摆选中()
	_刻度 = 0.0


## 选中环只有一枚（原版是每格自己的 `selectState`，这边等价地摆 46×46 黄框）。
## 无参 = 按当前 `_亮格`；传 `-1` = 全灭。
func _摆选中(序: int = -2) -> void:
	var 亮 := _亮格 if 序 == -2 else 序
	for i in _选中们.size():
		(_选中们[i] as Control).visible = (i == 亮)


## `setAwardData:386-390`：把定住那一格的 `value` 抄进奖品格（件数走同一句 `setItemCount`）。
func _奖品落定() -> void:
	if _亮格 < 0 or _亮格 >= _格条.size():
		return
	var 条: Dictionary = _格条[_亮格]
	if 条.is_empty():
		return
	_填格(_奖品格, 条)
	_设件数(_奖品格, int(条.get("quantity", 1)))


## ═══ `setBtnEnabled:312-335` 三态闸 ═══
## 状态 0 = 待显示；1 = 已开出（能开始、不能领奖）；2 = 待停止（不能开始、**能领奖**）。
## ⚠️ 2 那一档 `takeBtn.enabled = true`（`:331`）—— 之前这里两枚一起关，玩家跑完灯也点不动领奖。
func _置钮态(状态: int) -> void:
	_状态 = 状态
	match 状态:
		0:
			_开始钮.disabled = true
			_领奖钮.disabled = true
			_清选中()
			_停滴答()
		1:
			_开始钮.disabled = false
			_领奖钮.disabled = true
		2:
			_开始钮.disabled = true
			_领奖钮.disabled = false


func _清选中() -> void:
	_亮格 = -1
	_摆选中()


## ═══ `onClickStartBtn:450-463` ═══
func _点开始() -> void:
	if _背包已满():
		_通知(背包满字)
		return
	if get_parent() == null:
		# AS3 `if(!parent) return`：窗已经从舞台上摘下来了就什么都不发。
		return
	请求开始.emit()


## ═══ `onClickTakeBtn:281-310`（带 `isDelay` 1000ms 防连点，`:153`）═══
func _点领奖() -> void:
	if _背包已满():
		_通知(背包满字)
		return
	if get_parent() == null:
		return
	var 此刻 := Time.get_ticks_msec()
	if _领奖上次点 >= 0.0 and 此刻 - _领奖上次点 < 1000:
		# `MButton3.delayClickHandler:568-579`：不足 `intervalTime` 的那一发
		# `stopImmediatePropagation()` ⇒ 后面的 CLICK 监听**根本不跑**。
		return
	_领奖上次点 = float(此刻)
	请求领取.emit()
	_清选中()
	_已走 = 0
	# `isBagExistItem(currItemID)`（`DataCenter:3166-3182` = 同 id 件数**求和**）> 0 ⇒
	# `cleanAwardData()`：包里下一只福袋还在，奖品格要腾空；否则**只关钮**、图标留着（原版如此）。
	if _会话 != null and int(_会话.call("背包同名件数", _物品id)) > 0:
		_清奖品格()
	_领奖钮.disabled = true
	_自动开始()


## ═══ `SuccessWindowCell.removeData:129-146`（`cleanAwardData:366-369` 调它）═══
## 图标 + 资质/流光覆盖层 + 件数 + `value` + 悬停监听一起清 —— 清完这枚格悬上去什么都不出。
func _清奖品格() -> void:
	_奖品格.icon = null
	_奖品格.set("物品id", "")
	_奖品格.call("清空品质覆盖层")
	(_奖品格.get_node("数量") as Label).text = ""
	if _宿主 != null:
		格子提示框.接线(_宿主, self, _奖品格, {})


## `automatismStart:489-504`：勾了「领奖后自动开始」且包里还有同种福袋 ⇒ 立即点开始；
## 没了就**只摘帧监听**（不发请求、不关窗）。
func _自动开始() -> void:
	if not _勾开始.button_pressed:
		return
	if _会话 != null and int(_会话.call("背包同名件数", _物品id)) > 0:
		_点开始()
	else:
		_停滴答()


## `DataCenter.isPackgeFull():1043-1046` = `commonItems.length >= commonSlots`。
## 总格数走 `背包窗口._背包总格数` 那条链（服务端权威值 → `common_slots` → 96）。
func _背包已满() -> bool:
	if _会话 == null:
		return false
	return _会话._占用数(_会话.inventory) >= 背包窗口._背包总格数(_会话)


func _通知(文本: String) -> void:
	if _会话 != null and _会话.has_signal("notification_requested"):
		_会话.notification_requested.emit(文本)


## `SuccessWindowCell.setCellValue` + `showIcon`：图标、件数、资质覆盖层、提示框。
func _填格(格: Button, 条: Dictionary) -> void:
	var 号 := String(条.get("id", ""))
	格.icon = 游戏数据.item_icon(号) as Texture2D
	格.set("物品id", 号)
	var 品质 := {"id": 号}
	var 资质 := int(条.get("aptitude", 0))
	if 资质 > 0 or String(号).substr(0, 3) == "131":
		# `SuccessWindowCell.__showIcon:186-211` 的门槛是 `hasOwnProperty("aptitude")`，
		# 昆虫族（`isItemAKunChong`）在 `ItemFactory` 那侧一定带这个键 —— 口径同 `自选礼包窗._填格`。
		品质["aptitude"] = 资质
	格.call("设置品质", 品质, false)
	_挂提示(格, 条)


## `setItemCount:432-438`：只有 `count > 1` 才写字（`SuccessWindowCell.tf` 空着就是 1 件）。
func _设件数(格: Button, 件: int) -> void:
	if 件 <= 1:
		return
	var 数量 := 格.get_node_or_null("数量") as Label
	if 数量 != null:
		数量.text = str(件)


func _挂提示(格: Button, 条: Dictionary) -> void:
	if _宿主 == null:
		return
	格子提示框.接线(_宿主, self, 格, {
		"id": String(条.get("id", "")),
		"quantity": int(条.get("quantity", 1)),
		"star": int(条.get("star", 0)),
		"aptitude": int(条.get("aptitude", 0))}, true)


func _起滴答() -> void:
	if _滴答定时 == null:
		_滴答定时 = Timer.new()
		_滴答定时.name = "滴答"
		# 原版是舞台 `ENTER_FRAME`；本工程按 §3.77.3 定论 舞台 60fps ⇒ 一拍 1/60 秒。
		_滴答定时.wait_time = 1.0 / 60.0
		_滴答定时.one_shot = false
		add_child(_滴答定时)
		_滴答定时.timeout.connect(_滴答)
	_滴答定时.start()


func _停滴答() -> void:
	if _滴答定时 != null and is_instance_valid(_滴答定时):
		_滴答定时.stop()
	_延演 = -1


## 右上角 X = `onCloseBtnClick:218-238`：清选中 → 摘 ENTER_FRAME → `parent.removeChild` →
## 因为 `isDestroy` 继承基类的 **true**（本类没改过它），接着 `removeChildAt` 清空子件 +
## `destroyUIWindow(windowName)` ⇒ `_windowMap` 里那份**作废**。
## ⇒ 下一次 `1289:1` 走的是"重新造一扇 + 重新居中"，不是把旧的显影 ——
##   与 `自选礼包窗` 那种"隐藏后复用同一枚"是**两种生命周期**，别照着那边改。
## `queue_free()` 到帧末才真摘掉，同帧里 `get_node_or_null` 还能拿到本枚 ⇒
## 调用方按 `is_queued_for_deletion()` 判缺（见 `功能窗口._收到福袋帧`）。
func 隐藏() -> void:
	if not visible:
		return
	_清选中()
	_停滴答()
	visible = false
	queue_free()


## 首次登台：显形 + 摆到舞台正中。拆成单独一条是因为原版**只在实例造出来那一轮**摆位
## （`UIMain2.createWindow` 的 `setLocationCenter()` 整段在 `if(_windowMap[名] == null)` 里）
## ⇒ 复用旧枚时不许再摆，玩家拖到哪儿就停哪儿。
func 登台() -> void:
	visible = true
	_居中()


## 标题带拖动。`MWindow.onMouseDownHandler:327-341`：左键按下（目标不是按钮）⇒
## `startDrag(false, new Rectangle(0, 0, STAGE_WIDTH - width, STAGE_HEIGHT - 30))`。
## 钳位**照抄那个矩形**：x ∈ [0, 960−274]、y ∈ [0, 560−30]（y 上限刻意是"舞台高 − 30"，
## 即最多只留 30px 标题带在屏内，不是"窗底贴舞台底"）。落点收整同 §3.232（半像素会发虚）。
## ⚠️ `set_meta` 的键必须 ASCII（中文键会被静默拒掉 ⇒ 一次都拖不动，§3.64.4）。
static func _拖(事件: InputEvent, 窗: Control) -> void:
	if 事件 is InputEventMouseButton:
		var 按 := 事件 as InputEventMouseButton
		if 按.button_index == MOUSE_BUTTON_LEFT:
			窗.set_meta("drag_grab", 按.global_position - 窗.global_position if 按.pressed else Vector2.INF)
	elif 事件 is InputEventMouseMotion and (事件 as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		var 动 := 事件 as InputEventMouseMotion
		var 起 := 窗.get_meta("drag_grab", Vector2.INF) as Vector2
		if 起 == Vector2.INF:
			return
		var 视口 := 窗.get_viewport()
		if 视口 == null:
			return
		var 舞台 := 视口.get_visible_rect().size
		var 位 := (动.global_position - 起).round()
		位.x = clampf(位.x, 0.0, maxf(0.0, 舞台.x - 窗.size.x))
		位.y = clampf(位.y, 0.0, maxf(0.0, 舞台.y - 30.0))
		窗.global_position = 位


## 摆到舞台正中。出处不是 `PopUpMananger` —— 这扇窗走的是 `reverseDisplay` ⇒
## `UIMain2.createWindow:2291` 的 `default: _loc3_.setLocationCenter()`，
## 而 `MWindow.setLocationCenter:355-367` = `y = Math.round((STAGE_HEIGHT - height) >> 1)`
## （`>>` 先把 Number 取整再移 ⇒ 正数是**向下取整**，不是四舍五入）；x 同式。
## ⚠️ 一个实例**只摆这一次**（`_windowMap` 命中时那段整体跳过）⇒ 只有 `隐藏()` 作废实例后
##    重造才会再居中；复用旧枚时不许再调这里。
## 延迟一帧的理由同 `自选礼包窗._居中()`：刚挂上 `_overlay` 那一刻布局还没跑。
func _居中() -> void:
	var 视口 := get_viewport()
	if 视口 == null:
		return
	var 舞台 := 视口.get_visible_rect().size
	set_deferred("global_position", Vector2(
		floorf((舞台.x - size.x) * 0.5), floorf((舞台.y - size.y) * 0.5)
	))
