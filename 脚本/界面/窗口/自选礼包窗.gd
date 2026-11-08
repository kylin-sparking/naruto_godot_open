extends Control

## 原版「可选礼包」选择窗 —— `com/mxw/uifl/controls/ChoiceLibaoWindow.as`（343 行）。
##
## 入口链（巡检 #21 之前**整条缺失** ⇒ 20 件 `libao_select` 礼包点确定只收到一句
## 「请先在自选礼包中选择一件奖励。」）：
##   `ItemWindow2.onItemDoubleClick` → `UI.useItem` → `isItemLiBao && info.preview == 1`
##   （`ItemWindow2.as:990-1017`）里 `spec.type == "libao_select"` 那一支 ⇒ `new ChoiceLibaoWindow()`。
##   本工程按 `use_type == "libao_select"` 分流：**已核这 20 件全是 `preview == 1`**
##   （同一份 LiBao 表里 `libao_rand` 129 件全是 `preview == 0`），所以这条判据与原版等价。
##   没把 `preview` 补进 `数据/物品.json`：补列要重跑 `开发工具/导出游戏数据.mjs`，
##   而它连 `--data-only=true` 都会顺带改 意志/物品/礼包奖励 三张表，为一列不值。
##
## 版式出自 `createUI():125-187` + `draw():109-114` + `createItemCell():294-322`，坐标是**窗局部**：
##   background   MWindowSmall_background @ (0,0) **240** 宽，高由 `draw()` 现算
##   标题         `titleTextField.y = 2`（这个窗**改了** MWindow 默认的 5）；关闭 y = 4、x = 240 − 宽 − 4
##   background2  MYellow_background @ (6,30)，宽 = 240 − 12 = 228，高 = 格阵高 + 42
##   tipText      (6,33) 228×18 **黄**(16711680) 居中 = `CHOICE_LIBAO_ICON`
##   line         LineHPicF (11,56) 218×2
##   cellContainer (12,60)；格 40×40、hgap=vgap=2、首格偏移 4 ⇒ 容器局部 (4+42·列, 4+42·行)
##   钮           y = background2.height + 30 + 6；确定 x = 30、取消 x = 240 − 钮宽 − 30
##   窗高          = background2.height + 30 + 38
## 选中环 = `SkillCellSelectedGridF`（46×46，库里同一张 `忍术格选中环.png`），
##   `setSelectedGrid():64-74` 摆在 `cell.x − 3`。
## 格 = `prize/PrizeItemCell`：`MGrid_background` 40×40 + 数量 `MGlowLabel`
##   **(0,21) 宽 = 格宽 − 2 = 38、右对齐、白**（⚠️ 与背包格 `ItemWindowCell` 的
##   `(1,24)/宽 37` **不是同一套**，别照抄背包）。
##
## ⚠️ **格子阵的枚数 ≠ 候选数**（`getCellCountTotal():324-340`）：它数的是**所有职业组**的总行数
##   （不看职业、也不滤 `id<=0`），再 `ceil(总行数 / 5) × 5`；`setData():198-245` 只把
##   「通用组 + 本职业组」的行填进**前** `min(候选数, 格数)` 枚 ⇒ 尾巴那几枚是原版就摆着的空格。
##   同背包那条口径：空格照原版摆出来，不许挤掉。点击也只接在**填了的格**上
##   （AS3 只给前 n 枚 `addEventListener(MSPRITE_CLICK)`），空格点了不选。
##   开窗默认选中第 0 格（`:242` `selectedCell = cellArr[0]`）。
##
## 发出去的选择 = `{job, index}`（`getSelectItemIndex():247-273`）：`job` 是那行所属的**职业组**、
## `index` 是「通用组 + 本职业组」拼接之后的**全局下标**。服务端
## `_authored_gift_reward_rows:49562-49611` 按同一个序算下标，所以 `候选()` 必须连它的
## **过滤**一起复刻（`id<=0` 或 `count<=0` 的行服务端跳过）—— 少跳一行，玩家点的第 3 格
## 就发成了第 4 条奖励。导出的 `数据/礼包奖励.json` 内层键已按序号排好
## （`开发工具/导出游戏数据.mjs:180-188` 的 `sort(Number)`），与那句 AVM2 数字键序一致。
##
## 本窗**不管协议**（同 `一键出售窗`）：确定只发 `确认选择(职业组, 序号)`。
## ⚠️ 确定**不关窗** —— 原版 `__onOkBtnClick:283-293` 的关窗写在成功分支**里面**：
##   先过背包空位前置闸 `1 + commonItems.length <= commonSlots`，满了只
##   `addNotice(CN.ITEM_GRID_NOT_SPACE)`（「背包空间不足！」）**窗还开着**、一个包都不发。
##   闸只有调用方（拿得到会话）能算，所以「成交 ⇒ 由调用方回关这扇窗」是这里的契约；
##   见 `功能窗口._成交自选礼包`。取消/关闭钮自己关（同 `onCloseBtnClick`）。

signal 确认选择(职业组: int, 序号: int)
signal 关闭了

const 界面皮肤 := preload("res://脚本/界面/窗口/界面皮肤.gd")
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 物品格场景 := preload("res://场景/界面/组件/物品格.tscn")
const 物品提示场景 := preload("res://场景/界面/组件/物品提示框.tscn")
const 装备提示场景 := preload("res://场景/界面/组件/装备提示框.tscn")
const 格子提示框 := preload("res://脚本/界面/组件/格子提示框.gd")

const 选中环皮 := "res://素材/界面/原版窗口/忍术/忍术格选中环.png"
## 原版这张 `SkillCellSelectedGridF`（symbol129）是**整块选中态**：橙边 + 半透明深灰底 +
## 黑色内棱 + 右下角一个 0。盖在格子上会把道具图标压灰、还漏一个 0（用户 2026-11-07 报）。
## 玩家要的只是外框 ⇒ 运行时只留橙色像素，其余（灰底/黑棱/0）清成透明。
static var _纯框缓存: Texture2D = null
const 分隔线皮 := "res://素材/界面/原版窗口/通用控件/横向分隔线.png"
const 关闭钮皮 := "res://素材/界面/原版窗口/通用控件/关闭按钮.png"

const 窗宽 := 240.0
const 面板位 := Vector2(6.0, 30.0)			# `background2.x/y`
const 面板宽 := 228.0					# `background.width − 12`
const 提示高 := 18.0
const 分隔线位 := Vector2(11.0, 56.0)
const 分隔线宽 := 218.0
const 容器位 := Vector2(12.0, 60.0)
const 列数 := 5						# `rowCount`
const 格边 := 4.0					# 首格偏移（AS3 那两个分支合起来就是 `42·列 + 4`）
const 格距 := 42.0					# 格宽 40 + hgap/vgap 2（`createItemCell:303/311`）
const 格尺寸 := 40.0
const 环偏 := -3.0					# `selectedFrame.x = cell.x - 3`
const 面板底补 := 42.0					# `background2.height = cellContainer.height + 42`
const 窗高底补 := 68.0					# `background.height = background2.height + 30 + 38`
const 钮y补 := 36.0					# `okBtn.y = background2.height + 30 + 6`
const 钮高 := 22.0
const 钮边 := 30.0					# 确定 x = 30；取消 x = 240 − 宽 − 30
const 关闭钮宽 := 25.0
const 关闭钮高 := 24.0
const 黄 := Color(1.0, 1.0, 0.0)			# `tipText.textColor = 16711680`

## 语言表逐字（`en_US$message_properties.as`）
const 窗口标题 := "可选礼包"				# :2456 CHOICE_LIBAO_TITLE
const 提示文案 := "请点击选择一个礼物图示"			# :851 CHOICE_LIBAO_ICON
const 确定字 := "确定"					# :2325 COMMON_OK
const 取消字 := "取消"					# :1906 COMMON_CANCEL

var _格们: Array[Button] = []
var _候选: Array = []
var _选中序 := -1
var _选中环: TextureRect = null


## 「通用组 + 本职业组」的候选清单 —— 数据层在 `游戏数据.礼包候选`（会话离线发奖也读它，
## 两边必须同一份序，不然窗上第 3 格和服务端第 3 条不是同一样东西）。
static func 候选(物品id: String, 职业: int) -> Array:
	return 游戏数据.礼包候选(物品id, 职业)


## 格子阵要摆多少**枚**（含尾巴的空格）—— 序与过滤的账记在 `游戏数据.礼包格阵格数` 头上。
static func 格阵格数(物品id: String) -> int:
	return 游戏数据.礼包格阵格数(物品id, 列数)


static func 是131族(物品id: String) -> bool:
	# `ItemType.isItemAKunChong:285-288` = `String(id).substr(0,3) == "131"` —— 判的是**未补零**的
	# 整数形态 ⇒ **昆虫 `1310001`（四位码 131）和勾玉 `13100000`（前三位 131）都命中**，
	# 它不是"位置 == 昆虫包"（勾玉的位置是 -20，拿 `装备部位.位置()` 判会把勾玉整族漏掉）。
	# 我们手上的 id 两种形态都会出现（表里是不补零的、背包格上是补零的），
	# 所以与 `物品菜单:150` 同法并两条判据 —— 只写一条就会在其中一族上分叉。
	var 号 := String(物品id).strip_edges()
	if 号.is_valid_int():
		号 = 号.pad_zeros(8)
	return int(号.substr(0, 4)) == 131 or 号.substr(0, 3) == "131"


## 摆好这扇窗并显形。`宿主` = `功能窗口`（`格子提示框.接线` 要它的 `_session` / `_舞台尺寸()`）。
## 候选为空**不该调用**这里 —— 原版那支根本不开窗（`setData` 的 `length > 0` 闸）。
func 打开(物品id: String, 宿主: Node) -> void:
	var 会话: Node = 宿主.get("_session") as Node
	var 职业 := int(会话.player_stats.get("job", 0)) if 会话 != null else 0
	_候选 = 候选(物品id, 职业)
	var 格数 := 格阵格数(物品id)
	if 格数 < _候选.size():
		格数 = _候选.size()				# 数据漂到"候选比阵长"时不让任何一格没地方摆
	_重建(mini(_候选.size(), 格数), 格数, 宿主)
	visible = true
	_居中()


## `填数` = 要摆上图的格数；`格数` = 这一阵一共摆几枚（含空格）。
func _重建(填数: int, 格数: int, 宿主: Node) -> void:
	for 子 in get_children():
		子.free()
	_格们.clear()
	_选中序 = -1
	_选中环 = null
	var 行数 := int(ceilf(格数 / float(列数)))
	# Flash 的 sprite 边界：首格顶 y=4、末格底 = 4 + 42(行数−1) + 40 ⇒ 高 = 42·行数 − 2。
	# （带资质框的那两枚 42×42 覆盖层会把边界再抬 1px、窗跟着高 2px —— 原版 `height` 是
	#   实测边界、我们按字面公式算，这 2px 不追，见 §3.205 的账。）
	var 面板高 := 格距 * 行数 - 2.0 + 面板底补
	size = Vector2(窗宽, 面板高 + 窗高底补)
	var 钮y := 面板高 + 钮y补

	var 框 := Panel.new()
	框.name = "框"
	框.set_anchors_preset(Control.PRESET_FULL_RECT)
	框.mouse_filter = Control.MOUSE_FILTER_IGNORE
	框.theme_type_variation = 皮肤表.变体_小窗口边框
	add_child(框)

	var 标 := Label.new()
	标.name = "标题"
	标.text = 窗口标题
	标.position = Vector2(0.0, 2.0)		# `titleTextField.y = 2`
	标.size = Vector2(窗宽, 18.0)
	标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	标.theme_type_variation = 皮肤表.变体_窗口标题
	add_child(标)

	var 关 := Button.new()
	关.name = "关闭"
	关.position = Vector2(窗宽 - 关闭钮宽 - 4.0, 4.0)	# `closeBtn.x = 宽 − width − 4`
	关.size = Vector2(关闭钮宽, 关闭钮高)
	关.focus_mode = Control.FOCUS_NONE
	关.flat = true
	关.icon = load(关闭钮皮) as Texture2D
	# 右上角那枚 X 是 `MWindow` 基类接的（`onCloseBtnClick`），不是这个窗自己画的 ⇒
	# 语义 = **直接关**，不发选择（同取消）。
	关.pressed.connect(_点钮.bind(取消字))
	add_child(关)

	var 黄底 := Panel.new()
	黄底.name = "黄底"
	黄底.position = 面板位
	黄底.size = Vector2(面板宽, 面板高)
	黄底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	黄底.theme_type_variation = 皮肤表.变体_内容面板
	add_child(黄底)

	var 提 := Label.new()
	提.name = "提示"
	提.text = 提示文案
	提.position = Vector2(面板位.x, 面板位.y + 3.0)	# `tipText.y = background2.y + 3`
	提.size = Vector2(面板宽, 提示高)
	提.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	提.mouse_filter = Control.MOUSE_FILTER_IGNORE
	界面皮肤.configure_label(提, 12, 黄)
	add_child(提)

	var 线 := TextureRect.new()
	线.name = "分隔线"
	线.texture = load(分隔线皮) as Texture2D
	线.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	线.mouse_filter = Control.MOUSE_FILTER_IGNORE
	线.position = 分隔线位
	线.size = Vector2(分隔线宽, 2.0)
	add_child(线)

	var 阵 := Control.new()
	阵.name = "格阵"
	阵.position = 容器位
	阵.size = Vector2(格边 + 格距 * (列数 - 1) + 格尺寸, 格距 * 行数 - 2.0)
	阵.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(阵)
	for 序号 in 格数:
		var 格 := 物品格场景.instantiate() as Button
		格.name = "格_%d" % 序号
		格.position = Vector2(格边 + 格距 * (序号 % 列数), 格边 + 格距 * int(序号 / 列数))
		格.focus_mode = Control.FOCUS_NONE
		# `PrizeItemCell` 可点、可悬停出提示框，但**不参与拖拽**：`可拖拽 = false`、
		# `格子归属` 留空（`可拖拽格._get_drag_data` 第一道闸就是它）。
		格.set("可拖拽", false)
		阵.add_child(格)
		_格们.append(格)
		if 序号 >= 填数:
			continue				# 尾巴上的空格：原版照样摆着，不接点击
		_填格(格, _候选[序号] as Dictionary)

	# 选中环在格子**之后** add ⇒ 画在格子上面（AS3 `setSelectedGrid` 也是懒建后 addChild 进容器）。
	_选中环 = TextureRect.new()
	_选中环.name = "选中环"
	_选中环.texture = _取纯选中环()
	_选中环.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# ⚠ `EXPAND_IGNORE_SIZE` 只改"贴图不撑节点"这一条，节点尺寸仍要自己给：
	#   不设 size 就是 0×0，环画不出来（用户 2026-11-07 报「选中没有框，看不到选了哪一个」）。
	_选中环.size = Vector2(46.0, 46.0)		# `SkillCellSelectedGridF` 46×46
	_选中环.mouse_filter = Control.MOUSE_FILTER_IGNORE
	阵.add_child(_选中环)

	# 两枚都 `isScale9Grid = true` 且没设宽 ⇒ 各自按文字量宽（`_量钮宽`），
	# 所以取消那枚的 x 要**等自己的宽**算出来（AS3 `createUI:180` 用的就是 `cancelBtn.width`）。
	for 文字v in [确定字, 取消字]:
		var 文 := String(文字v)
		var 钮 := Button.new()
		钮.name = 文
		钮.text = 文
		var 宽 := _量钮宽(文)
		钮.custom_minimum_size = Vector2(宽, 钮高)
		钮.position = Vector2(钮边 if 文 == 确定字 else 窗宽 - 宽 - 钮边, 钮y)
		add_child(钮)
		钮.pressed.connect(_点钮.bind(文))

	# 提示框建在**最后** ⇒ 盖得住格阵、也盖得住两枚钮（模态窗压在遮罩上，提示框必须同层）。
	_建提示框()
	for 序号 in 填数:
		var 项: Dictionary = _候选[序号] as Dictionary
		var 格 := _格们[序号]
		格.pressed.connect(_点格.bind(格))
		格子提示框.接线(宿主, self, 格, {
			"id": String(项.get("item_id", "")),
			"quantity": int(项.get("count", 1)),
			"star": int(项.get("star", 0))})
	_选到(0)


## `PrizeItemCell.setCellValue/setPic` 那三件事：图标、数量、品质覆盖层。
func _填格(格: Button, 项: Dictionary) -> void:
	var 号 := String(项.get("item_id", ""))
	格.icon = 游戏数据.item_icon(号) as Texture2D
	格.set("物品id", 号)
	var 件 := int(项.get("count", 1))
	var 数量 := 格.get_node("数量") as Label
	# `PrizeItemCell:34-38`：`setPosition(0,21)`、`width = background.width − 2`、`align="right"`。
	数量.offset_left = 0.0
	数量.offset_top = 21.0
	数量.offset_right = 38.0
	数量.offset_bottom = 37.0
	数量.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	界面皮肤.configure_label(数量, 12, Color.WHITE)
	数量.text = str(件) if 件 > 1 else ""
	# 资质框的门槛在 **`setData():207-216`**：`_loc7_.hasOwnProperty("aptitude")` 且
	# `isItemAKunChong(id)`（= id 前三位 "131"，昆虫与勾玉两族都算）才把行上的 `aptitude`
	# **抄到那张待显示的 ItemData 上**。`PrizeItemCell.setPic():66-83` 只看这条属性在不在、
	# 再按 `switch(aptitude)` 画 2/3/4 三档 —— 资质 0(白) 不在 case 里 ⇒ **什么都不画**，
	# 所以"给了键但值是 0"与"没给键"画面一致。`装备品质.覆盖层()` 读的正是"字典里有没有
	# aptitude 这个键"，所以这里用**键的有无**表达，不是传 0。
	# （`setPic` 末尾那条 `hasOwnProperty("canTrade") && !canTrade` 的锁图标在这里**永远不亮**：
	#   `createSingleItem:300-345` 只 new 一个 ItemData、不碰 canTrade，而 `ItemData.as:93` 的
	#   默认值是 `true` —— 所以本窗不画锁，不是漏了。）
	var 品质: Dictionary = {"id": 号}
	if 是131族(号):
		品质["aptitude"] = int(项.get("aptitude", 0))
	# `认灵气` 传 false：灵气（十拳剑）恒粉框那条只有 `ItemWindowCell` 有，`PrizeItemCell` 没有
	# （见 `装备品质.gd::覆盖层` 的头注释）。
	格.call("设置品质", 品质, false)


func _建提示框() -> void:
	for 项 in [["物品提示框", 物品提示场景], ["装备提示框", 装备提示场景]]:
		var 名 := String(项[0])
		if get_node_or_null(名) != null:
			continue
		var 框 := (项[1] as PackedScene).instantiate() as Control
		框.name = 名
		框.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(框)


## `SkillCellSelectedGridF`（symbol129）是整块「橙边 + 半透明深灰底 + 右下角 0」的选中态。
## 整张盖上去会把道具图标染灰、还多一个 0 —— 只留橙边（#FF7500 一族，含抗锯齿边），
## 灰底/黑色内棱/那个 0 全清成透明，露出下面的道具图标（用户 2026-11-07 口径）。
static func _取纯选中环() -> Texture2D:
	if _纯框缓存 != null:
		return _纯框缓存
	var 原 := load(选中环皮) as Texture2D
	if 原 == null:
		return null
	var 图 := 原.get_image()
	if 图 == null or 图.is_empty():
		_纯框缓存 = 原
		return 原
	图 = 图.duplicate()
	图.convert(Image.FORMAT_RGBA8)
	for y in 图.get_height():
		for x in 图.get_width():
			var 像素 := 图.get_pixel(x, y)
			# 橙判据：亮红主导、绿约一半、蓝近 0。深灰底 (40,26,22)、黑棱 (0,0,0)、
			# 白字 0 (183,178,177) 都不满足。
			if not (像素.r > 0.6 and 像素.r > 像素.g * 1.5 and 像素.b < 0.4):
				图.set_pixel(x, y, Color(0, 0, 0, 0))
	_纯框缓存 = ImageTexture.create_from_image(图)
	return _纯框缓存


## 移动选中环（容器局部：环在 `格 − 3`）。
func _选到(序: int) -> void:
	if _选中环 == null or 序 < 0 or 序 >= _格们.size():
		return
	_选中序 = 序
	_选中环.position = _格们[序].position + Vector2(环偏, 环偏)


func _点格(格: Button) -> void:
	_选到(_格们.find(格))


func _点钮(名: String) -> void:
	if 名 == 确定字:
		# 选中序一定在候选内（`_选到(0)` 起就有值、空格子没接点击），但闸留着：
		# 数据漂成"填了 0 格"时宁可什么都不发，也不发一条 `{job:0,index:-1}` 的废选择。
		if _选中序 >= 0 and _选中序 < _候选.size():
			var 项: Dictionary = _候选[_选中序] as Dictionary
			确认选择.emit(int(项.get("job", 0)), int(项.get("index", -1)))
		return						# 关窗是调用方的事（见头注释）
	隐藏()


func 隐藏() -> void:
	if not visible:
		return
	visible = false
	关闭了.emit()


## `PopUpMananger.centerWindow`：舞台居中（同 `一键出售窗._居中()` 那个 `set_deferred` 理由
## —— 刚挂上 `_overlay` 的那一刻布局还没跑，当场写 `global_position` 用的是祖先的旧变换）。
func _居中() -> void:
	var 舞台 := get_viewport().get_visible_rect().size
	set_deferred("global_position", Vector2(
		round((舞台.x - size.x) * 0.5), round((舞台.y - size.y) * 0.5)
	))


## `MButton3.measure():378-390`：`isScale9Grid = true` 且**没显式设宽** ⇒ `_width = 文字宽 + 6`。
## 这个窗的确定/取消正是这一支（`createUI:171-177` 只置了 `isScale9Grid`），
## 所以钮宽按实测文字量，别照抄 一键出售窗 那种 `btn_width_four = 61`。
func _量钮宽(文: String) -> float:
	var 字 := get_theme_font("font", "Button") as Font
	if 字 == null:
		return 30.0
	return ceilf(字.get_string_size(文, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			get_theme_font_size("font_size", "Button")).x) + 6.0
