extends Control

## 原版「火影有礼」礼包详情窗 —— `com/mxw/uifl/controls/SelectGiftWindow.as`（471 行）。
##
## 入口链（`ItemWindow2.as:990-1017`）：
##   `isItemLiBao && StringTool.isPreviewLibao(id)`
##   → `spec.type == "libao"`      ⇒ 本窗（12 格，金币/点券两行成本）
##   → `spec.type == "libao_fufei"`⇒ 本窗（16 格 + 顶部「礼包开启需要支付 N 元宝」）
##   → 其余（`libao_select`）      ⇒ 已实装的 `自选礼包窗.gd`（`ChoiceLibaoWindow`）
## 数据只读 `数据/礼包详情.json`（只收 `info.preview == 1`），导出见
## `开发工具/导出礼包详情.py`。**别拿 `数据/物品.json.contents` 当详情**：那是服务端
## 把 job 0/300 两组扁平化后的候选清单，和当前职业看到的行不是同一份。
##
## 版式真值：`createUI/defaultUi:298-378` + `updateLayout:416-446`：
##   窗 202 宽；非付费初始高 321，付费 334；
##   **可开启时** `showIcon:185-189` 把 `_height` 改成 300 / 313 并重排（少了底部红字那 21px）。
##   background_1 `MYellow` @ (6,39)，高 = 窗高 − 76
##   background_2 `MPane`   @ (11, background_1.y + (付费?51:31))，高 = 格阵高 + 12
##   格 40×40、4 列、hgap/vgap=1、首格 (6,6)；12 格 3 行 / 付费 16 格 4 行
##   非付费底部：金币行 y=background_2 底+5、点券行 +28，分隔线 +57，红字再 +2
##   付费：没有金币/点券两行，分隔线在 background_2 底+5
##   打开钮：`MButtonF`，宽 `UIConfig.btn_width_four = 61`，x 居中，
##           y = background_1.y + background_1.height + 4
##
## ⚠️ `showIcon:145-189` 的可开判定只查**等级**与 **`money.cash`（元宝）**；
##    `money.point`（金币）与 `money.cashbind`（点券）只显示、不拦。别"顺手"补判 ——
##    原版就是先让按钮亮着，服务端结算时再拒。服务端 `_use_authored_gift_item`
##    现在也按同一口径扣费，见那边的注释。
##
## 本窗不管协议：打开钮只发 `确认开启`（同 `自选礼包窗` 的契约），扣件/发奖由
## `功能窗口._成交礼包详情` 走 `游戏会话.use_inventory_slot`。

signal 确认开启
signal 关闭了

const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 界面皮肤 := preload("res://脚本/界面/窗口/界面皮肤.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 物品格场景 := preload("res://场景/界面/组件/物品格.tscn")
const 物品提示场景 := preload("res://场景/界面/组件/物品提示框.tscn")
const 装备提示场景 := preload("res://场景/界面/组件/装备提示框.tscn")
const 格子提示框 := preload("res://脚本/界面/组件/格子提示框.gd")

const 关闭钮皮 := "res://素材/界面/原版窗口/通用控件/关闭按钮.png"
const 金币皮 := "res://素材/界面/原版窗口/通用控件/金币.png"
const 点券皮 := "res://素材/界面/原版窗口/通用控件/点券.png"
const 元宝皮 := "res://素材/界面/原版窗口/通用控件/元宝币.png"
const 分隔线皮 := "res://素材/界面/原版窗口/通用控件/横向分隔线.png"

const 窗宽 := 202.0
const 黄底位 := Vector2(6.0, 39.0)
const 黄底宽 := 190.0
const 黄底高补 := 76.0
const 子面板x := 11.0
const 子面板宽 := 180.0
const 格尺寸 := 40.0
const 格距 := 1.0
const 格边 := 6.0
const 列数 := 4
const 非付费格数 := 12
const 付费格数 := 16
const 子面板底补 := 12.0
const 关闭钮宽 := 25.0
const 关闭钮高 := 24.0
const 钮宽 := 61.0
const 钮高 := 22.0

const 基础高 := 321.0
const 付费基础高 := 334.0
const 可开高 := 300.0
const 付费可开高 := 313.0

const 橙 := Color("#ff9100")		# `UIConfig.UI_ORANGE = 16748800`
const 白 := Color.WHITE
const 红 := Color("#ff0000")		# `setTextFieldXYWH(tishi, ..., 16711680)`

const 窗口标题 := "火影有礼"		# `CN.SELECT_GIFT_WINDOW_TITLE`
const 等级提示 := "礼包开启需要等级"	# `CN.OPEN_LEVEL_GIFT`
const 级字 := "级"			# `CN.QUEST_ITEMHAND_PETCELL`
const 支付提示 := "礼包开启需要支付"	# `CN.OPEN_DEFRAY_GIFT`
const 元宝字 := "元宝"			# `CN.COIN`
const 金币字 := "金币："			# `CN.MONEY`
const 点券字 := "点券："			# `CN.DIANJUAN`
const 打开字 := "打开礼包"		# `CN.OPEN_GIFT`
const 元宝不足 := "很抱歉，你的元宝不足！"		# `CN.SORRY_DEFICIENCY_COIN`
const 等级不足 := "很抱歉，你的等级不足！"		# `CN.SORRY_DEFICIENCY_LEVEL`
const 元宝等级不足 := "很抱歉，你的元宝和等级不足！"	# `CN.SORRY_DEFICIENCY_COIN_AND_LEVEL`

var _物品id := ""
var _详情: Dictionary = {}
var _职业 := 0
var _等级 := 0
var _当前元宝 := 0
var _付费 := false
var _可开 := false
var _格们: Array[Button] = []
var _宿主: Node = null


## `宿主` = `功能窗口`（`格子提示框.接线` 要它的 `_session`/`_舞台尺寸()`）。
func 打开(物品id: String, 宿主: Node) -> void:
	_物品id = 物品id
	_宿主 = 宿主
	_详情 = 游戏数据.礼包详情(物品id)
	var 会话: Node = 宿主.get("_session") as Node if 宿主 != null else null
	_职业 = int(会话.player_stats.get("job", 0)) if 会话 != null else 0
	_等级 = int(会话.player_stats.get("level", 0)) if 会话 != null else 0
	_当前元宝 = int(会话.player_stats.get("cash", 0)) if 会话 != null else 0
	_付费 = String(_详情.get("type", "")).to_lower() == "libao_fufei"
	_重建()
	visible = true
	_居中()


## `showIcon:151-189` 的可开判定。只查等级与 `money.cash`（元宝），见头注释。
func _算可开() -> bool:
	var 需求等级 := int(_详情.get("req_level", 0))
	var 需元宝 := _需求元宝()
	return _等级 >= 需求等级 and _当前元宝 >= 需元宝


func _需求元宝() -> int:
	var 钱: Dictionary = _详情.get("money", {}) as Dictionary
	return absi(int(钱.get("cash", 0)))


func _需求金币() -> int:
	var 钱: Dictionary = _详情.get("money", {}) as Dictionary
	return int(钱.get("point", 0))


func _需求点券() -> int:
	var 钱: Dictionary = _详情.get("money", {}) as Dictionary
	return int(钱.get("cashbind", 0))


func _提示() -> String:
	var 缺等级 := _等级 < int(_详情.get("req_level", 0))
	var 缺元宝 := _当前元宝 < _需求元宝()
	if 缺等级 and 缺元宝:
		return 元宝等级不足
	if 缺元宝:
		return 元宝不足
	if 缺等级:
		return 等级不足
	return ""


func _重建() -> void:
	for 子 in get_children():
		子.free()
	_格们.clear()
	_可开 = _算可开()
	var 格数全 := 付费格数 if _付费 else 非付费格数
	var 行数 := int(ceilf(格数全 / float(列数)))
	var 格阵高 := 格距 + 格尺寸 * 行数 + 格距 * (行数 - 1) + 格边
	# 格 y = 6 + 41·行 ⇒ 末格底 = 6 + 41·(行数−1) + 40 = 41·行数 + 5。
	格阵高 = 41.0 * 行数 + 5.0
	var 窗高 := (付费基础高 if _付费 else 基础高)
	if _可开:
		窗高 = 付费可开高 if _付费 else 可开高
	size = Vector2(窗宽, 窗高)
	var 黄底高 := 窗高 - 黄底高补
	var 子面板y := 黄底位.y + (51.0 if _付费 else 31.0)
	var 子面板高 := 格阵高 + 子面板底补

	var 框 := Panel.new()
	框.name = "框"
	框.position = Vector2.ZERO
	框.size = size
	框.theme_type_variation = 皮肤表.变体_窗口边框
	add_child(框)

	var 标 := Label.new()
	标.name = "标题"
	标.text = 窗口标题
	标.position = Vector2(0.0, 5.0)		# `MWindow._titleTextFieldY = 5`
	标.size = Vector2(窗宽, 18.0)
	标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	标.theme_type_variation = 皮肤表.变体_窗口标题
	add_child(标)

	var 关 := Button.new()
	关.name = "关闭"
	关.position = Vector2(窗宽 - 关闭钮宽 - 6.0, 6.0)	# `closeBtn.x = 宽 − width − 6`、y = 5+1
	关.size = Vector2(关闭钮宽, 关闭钮高)
	关.focus_mode = Control.FOCUS_NONE
	关.flat = true
	关.icon = load(关闭钮皮) as Texture2D if ResourceLoader.exists(关闭钮皮) else null
	关.pressed.connect(_关)
	add_child(关)

	var 黄底 := Panel.new()
	黄底.name = "黄底"
	黄底.position = 黄底位
	黄底.size = Vector2(黄底宽, 黄底高)
	黄底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	黄底.theme_type_variation = 皮肤表.变体_内容面板
	add_child(黄底)

	# —— 顶部「礼包开启需要等级 N 级」——
	_标签(标节点(11.0, 44.0, 98.0, 18.0), 等级提示, 白).name = "开启等级"
	_输入底(Vector2(111.0, 44.0), Vector2(40.0, 21.0))
	_标签(标节点(113.0, 45.0, 36.0, 18.0), str(int(_详情.get("req_level", 0))), 白,
			HORIZONTAL_ALIGNMENT_CENTER).name = "等级值"
	_标签(标节点(153.0, 44.0, 36.0, 18.0), 级字, 白).name = "级"

	# —— 付费版顶部第二行「礼包开启需要支付 N 元宝」——
	if _付费:
		_标签(标节点(11.0, 66.0, 98.0, 18.0), 支付提示, 白).name = "支付提示"
		_输入底(Vector2(111.0, 66.0), Vector2(40.0, 21.0))
		_标签(标节点(113.0, 67.0, 36.0, 18.0), str(_需求元宝()), 白,
				HORIZONTAL_ALIGNMENT_CENTER).name = "元宝值"
		_标签(标节点(153.0, 66.0, 36.0, 18.0), 元宝字, 白).name = "元宝字"

	var 子面板 := Panel.new()
	子面板.name = "子面板"
	子面板.position = Vector2(子面板x, 子面板y)	# `MPane_background @ (11, background_1.y + 31/51)`
	子面板.size = Vector2(子面板宽, 子面板高)
	子面板.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(子面板)

	var 阵 := Control.new()
	阵.name = "格阵"
	阵.position = Vector2(子面板x, 子面板y)		# `container.x/y = background_2.x/y`
	阵.size = Vector2(格边 + 格距 * (列数 - 1) + 格尺寸, 格阵高)
	阵.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(阵)

	var 奖励 := 游戏数据.礼包详情物品(_物品id, _职业)
	if 奖励.size() > 格数全:
		奖励 = 奖励.slice(0, 格数全)
	for 序号 in 格数全:
		var 格 := 物品格场景.instantiate() as Button
		格.name = "格_%d" % 序号
		格.position = Vector2(格边 + 41.0 * (序号 % 列数), 格边 + 41.0 * int(序号 / 列数))
		格.focus_mode = Control.FOCUS_NONE
		格.set("可拖拽", false)
		阵.add_child(格)
		_格们.append(格)
		if 序号 >= 奖励.size():
			continue
		_填格(格, 奖励[序号] as Dictionary)

	# —— 非付费版底部成本两行 ——
	var 底 := 子面板y + 子面板高
	var 线y := 底 + 5.0
	if not _付费:
		_标签(标节点(11.0, 底 + 5.0, 38.0, 18.0), 金币字, 橙).name = "金币标签"
		_输入底(Vector2(51.0, 底 + 3.0), Vector2(115.0, 21.0))
		_图标(Vector2(53.0, 底 + 4.0), 金币皮, Vector2(17.0, 17.0))
		_标签(标节点(74.0, 底 + 4.0, 88.0, 18.0), str(_需求金币()), 白).name = "金币值"
		_标签(标节点(11.0, 底 + 28.0, 38.0, 18.0), 点券字, 橙).name = "点券标签"
		_输入底(Vector2(51.0, 底 + 27.0), Vector2(115.0, 21.0))
		_图标(Vector2(53.0, 底 + 31.0), 点券皮, Vector2(20.0, 15.0))
		_标签(标节点(74.0, 底 + 29.0, 85.0, 18.0), str(_需求点券()), 白).name = "点券值"
		线y = 底 + 31.0 + 15.0 + 11.0

	var 线 := TextureRect.new()
	线.name = "分隔线"
	线.texture = load(分隔线皮) as Texture2D if ResourceLoader.exists(分隔线皮) else null
	线.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	线.mouse_filter = Control.MOUSE_FILTER_IGNORE
	线.position = Vector2(子面板x, 线y)
	线.size = Vector2(子面板宽, 2.0)
	线.visible = not _可开
	add_child(线)

	var 提示 := _标签(标节点(子面板x, 线y + 2.0, 子面板宽, 18.0), _提示(), 红)
	提示.name = "提示"
	提示.visible = not _可开

	var 钮 := Button.new()
	钮.name = 打开字
	钮.text = 打开字
	钮.position = Vector2(floorf((窗宽 - 钮宽) * 0.5), 黄底位.y + 黄底高 + 4.0)
	钮.size = Vector2(钮宽, 钮高)
	界面皮肤.configure_standard_button(钮, Vector2(钮宽, 钮高))
	钮.disabled = not _可开
	钮.pressed.connect(_点开启)
	add_child(钮)

	# 提示框最后建 ⇒ 盖在格阵与按钮之上（同 `自选礼包窗._建提示框`）。
	_建提示框()
	for 序号 in 奖励.size():
		格子提示框.接线(_宿主, self, _格们[序号], {
			"id": String((奖励[序号] as Dictionary).get("item_id", "")),
			"quantity": int((奖励[序号] as Dictionary).get("count", 1)),
			"star": int((奖励[序号] as Dictionary).get("star", 0)),
		})


## `ItemWindowCell.showIcon` 的三件事：图标、数量、资质覆盖层。
func _填格(格: Button, 项: Dictionary) -> void:
	var 号 := String(项.get("item_id", ""))
	格.icon = 游戏数据.item_icon(号) as Texture2D
	格.set("物品id", 号)
	var 数量 := 格.get_node_or_null("数量") as Label
	if 数量 != null:
		数量.text = str(int(项.get("count", 1))) if int(项.get("count", 1)) > 1 else ""
	# `ItemWindowCell.setCellValue` 对装备把行上的 aptitude 抄到 ItemData 上；
	# 非装备没有 aptitude 属性 ⇒ 只给有资质或 131 族（昆虫/勾玉）的格挂键。
	var 资质 := int(项.get("aptitude", 0))
	var 品质 := {"id": 号}
	if 资质 > 0 or 是131族(号):
		品质["aptitude"] = 资质
	格.call("设置品质", 品质, false)


## `ItemType.isItemAKunChong:285-288` 的两族判据，详见 `自选礼包窗.是131族`。
static func 是131族(物品id: String) -> bool:
	var 号 := String(物品id).strip_edges()
	if 号.is_valid_int():
		号 = 号.pad_zeros(8)
	return int(号.substr(0, 4)) == 131 or 号.substr(0, 3) == "131"


func _建提示框() -> void:
	for 项 in [["物品提示框", 物品提示场景], ["装备提示框", 装备提示场景]]:
		var 名 := String(项[0])
		if get_node_or_null(名) != null:
			continue
		var 框 := (项[1] as PackedScene).instantiate() as Control
		框.name = 名
		框.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(框)


func _标签(节点: Label, 文字: String, 颜色: Color,
		对齐 := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	节点.text = 文字
	节点.horizontal_alignment = 对齐
	节点.mouse_filter = Control.MOUSE_FILTER_IGNORE
	界面皮肤.configure_label(节点, 12, 颜色)
	add_child(节点)
	return 节点


func 标节点(x: float, y: float, 宽: float, 高: float) -> Label:
	var 节点 := Label.new()
	节点.position = Vector2(x, y)
	节点.size = Vector2(宽, 高)
	return 节点


func _输入底(位置: Vector2, 尺寸: Vector2) -> Panel:
	var 底 := Panel.new()
	底.position = 位置
	底.size = 尺寸
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	底.theme_type_variation = 皮肤表.变体_输入框底
	add_child(底)
	return 底


func _图标(位置: Vector2, 路径: String, 尺寸: Vector2) -> void:
	if not ResourceLoader.exists(路径):
		return
	var 图 := TextureRect.new()
	图.texture = load(路径) as Texture2D
	图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	图.position = 位置
	图.size = 尺寸
	add_child(图)


func _点开启() -> void:
	if not _可开:
		return
	# 原版 `onClickOpenBtn:251-266`：先查背包空位，再 dispatch ItemEvent.USE，
	# 然后 `onCloseBtnClick(null)` —— 关窗不等服务端回执。背包空位那道闸在调用方
	# `功能窗口._成交礼包详情` 里（它拿得到会话）；这里只发意图并照原版立即关。
	确认开启.emit()
	隐藏()


func _关() -> void:
	隐藏()


func 隐藏() -> void:
	if not visible:
		return
	visible = false
	关闭了.emit()


## `PopUpMananger.centerWindow`：舞台居中。延迟一帧，理由同 `自选礼包窗._居中()`。
func _居中() -> void:
	var 视口 := get_viewport()
	if 视口 == null:
		return
	var 舞台 := 视口.get_visible_rect().size
	set_deferred("global_position", Vector2(
		round((舞台.x - size.x) * 0.5), round((舞台.y - size.y) * 0.5)
	))
