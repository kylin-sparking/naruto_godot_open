extends Control

## 原版**格数扩展**窗（`EnlargeWindow`，242×215）。逐件真值见
## `game-client/真值/窗口/宠物.md` §12（行号级），背包/仓库侧旧登记在 开发记录（本地） §3.10.9。
##
## ⚠️ 与存钱窗一样 `extends MWindow`、**不是 UIWindow** —— 没有 `super(宽,高)`，
## 尺寸是给 `MWindowSmall_background`（符号 767）手动设 **242×215**（`:180-181`）。
## ⚠️ 而且这扇窗的所有件都 `addChild` 在**窗口自身**上、背景先占 (0,0) 整幅
## ⇒ AS3 写的坐标就是窗口局部坐标，**没有** `UIWindow` 那套 −29/内容原点 (8,38) 偏移。
##
##   `:178`  `isDrag = false` ⇒ **不许拖**
##   `:188-193`  黄底 `MYellow_background`（tag **10**，原生 263×252，边距 11/10/10/11）@ (6,30) 230×153
##   `:253-254`  标题 y=**2**、关钮 y=**3**（覆盖 `MWindow` 默认的 5/6）
##   `:194-195`  需要数 @ (8,36) 224×18，橙（`%1` = 需要几个密卷）
##   `:196-199`  物品名 @ (11,60) 83×18 居中，初值 `ENLARGE_MIJUAN`，`:274` 被**道具表真名**覆盖
##   `:200-204`  获得途径 @ (95,60) 124×18 居中
##   `:205-209`+`:125`  说明 `Box` @ (95,80) 142×64 —— `Box` 自己**没有任何皮**，只是裁剪区
##   `:210-222`+`:139`  └ `sayTf` 宽 **124**、高 `textHeight + 6`（3 行 ⇒ 15·3+2·2+6 = 55）、白、leading 2
##   `:223-224`  询问 @ (8,160) 224×18，橙
##   `:225-230`  确定 @ (33,186) **37**×22（`UIConfig.btn_width_two` = 37 `:964`）
##   `:232-237`  取消 @ (157,186) 37×22
##   `:239-242`  物品格 `ItemWindowCell` @ (33,80) 40×40；格内图标原尺寸居中（34×34 ⇒ (3,3)）、
##              数量 @ 格内 (1,24) **右沿 38**、12 号白（`cell/ItemWindowCell.as:54-60`）
##   `:243-248`  购买 @ (35,122) 37×22
##
## 四条分支（`setTextFieldText:104-141` + `onClickKo:281-309`）**只有文案与协议不同**：
##   0 行囊（背包）→ `ENLARGE_WANT_COUNT` + `ENLARGE_PACK_COUNT_1(%1=页号)` → `ItemEvent.ITEM_ACTIVE`
##   1 仓库        → **同一条** `ENLARGE_WANT_COUNT` + `ENLARGE_PACK_COUNT_2(%1=页号)` → `StorageWindowEvent.ITEM_ACTIVE`
##   **2 兽栏**    → `ENLARGE_WANT_COUNT_2` + `ENLARGE_PACK_COUNT_PET`（**不带 %1**）→ `requestExtendPetLimit(0)`
##   3 改变任务    → 另一套文案 + 隐藏「获得途径」+ `sayBox.height=105`（不属于本模块）
## 购买 `onClickBuy:169-174` → `CashShopWindowEvent.REQUEST_CASH_ITEM_INFO`（`id = 密卷id`）
## ⇒ 我们侧 1086 只发一个字段、就是**物品 id**（`后端连接.gd:869-876`）。
##
## `updateItemCount:78-100`：格上的数量 = 背包里该密卷的拥有数（>0 才显）；
## **拥有数 ≥ 需要数才让点「确定」**，不足时 `itemContainer.setFilters(false)`
## = `Style.getDisableFilter()`（`Style.as:65` 的 ColorMatrix 与 `禁用灰度.gdshader` 同一组系数）
## —— 注意 filters 挂在 `itemIcon`（格皮+图标）上，**数量文本是它的兄弟节点、不跟着灰**。

signal 确认扩充(归属: String)
signal 请求购买(密卷id: String)

const 标题 := "格数扩展"
const 密卷名 := "扩充密卷"                                ## ENLARGE_MIJUAN
const 获得途径 := "获得途径"                              ## ENLARGE_GET_PASS
## ENLARGE_WINDOW_DESC_STR1(1034) —— 原文用 `\r` 分行，这里按行拆开写
const 说明行 := [
	"1.击杀野外BOSS获得",
	"2.参与线上活动",
	"3.通过商城付费活动",
]
## 需要数：`%1` = 需要几个密卷
const 需要数模板 := {
	"背包": "扩充需要在背包中有%s个扩充密卷",       ## ENLARGE_WANT_COUNT(1448)
	"仓库": "扩充需要在背包中有%s个扩充密卷",       ## `:109-118` 仓库这条用的也是同一个键
	"兽栏": "扩展兽栏需要在背包中有%s个扩充密卷",   ## ENLARGE_WANT_COUNT_2(1188)
}
## 询问：背包/仓库的 `%1` = **页号**（原版 `_row`）；兽栏那条没有占位符
const 询问模板 := {
	"背包": "请问你是要扩充行囊%s吗？",             ## ENLARGE_PACK_COUNT_1(2685)
	"仓库": "请问你是要扩充仓库%s吗？",             ## ENLARGE_PACK_COUNT_2(2684)
	"兽栏": "请问你要扩展兽栏吗？",                 ## ENLARGE_PACK_COUNT_PET(2472)
}

const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
const 灰度着色器 := preload("res://脚本/界面/组件/禁用灰度.gdshader")

var _归属 := "背包"
var _密卷id := ""
static var _灰度: ShaderMaterial


## 建好引用。⚠️ 钮一律按 **BaseButton** 取：`TextureButton`/`LinkButton` 都不是 `Button` 的子类，
## 用 `as Button` 取到的是 null（工程里已经因为这个静默丢过一整批接线）。
func _ready() -> void:
	($确定 as BaseButton).pressed.connect(func() -> void:
		确认扩充.emit(_归属)
		隐藏())
	($取消 as BaseButton).pressed.connect(隐藏)
	($关闭 as BaseButton).pressed.connect(隐藏)
	($购买 as BaseButton).pressed.connect(func() -> void: 请求购买.emit(_密卷id))
	($标题 as Label).text = 标题
	($获得途径 as Label).text = 获得途径
	($说明 as Label).text = "\n".join(说明行)


## `setData(需要数量, 归属号, 页号, 密卷id)`（`:259-279`）+ `updateItemCount:78-100`。
## `页号` 就是原版 `_row`：只有背包/仓库的询问文案会用到它，兽栏不读。
## 密卷图标与拥有数量由调用方给（原版是 `StringTool.get_FuZhuWuPin_id_KZF()` 查道具表 +
## `API.dataCenter.isBagExistItem`）。
func 打开(归属: String, 页号: int, 需要数量: int, 密卷id: String, 拥有数量: int) -> void:
	_归属 = 归属
	_密卷id = 密卷id
	($需要数 as Label).text = String(需要数模板.get(归属, 需要数模板["背包"])) % str(需要数量)
	var 询问 := String(询问模板.get(归属, 询问模板["背包"]))
	# 兽栏那条**没有** `%1` 占位（`ENLARGE_PACK_COUNT_PET`），别对它做格式化
	if 询问.find("%s") >= 0:
		($询问 as Label).text = 询问 % str(maxi(1, 页号))
	else:
		($询问 as Label).text = 询问
	var 名 := GAME_DATA.item_name(密卷id) if not 密卷id.is_empty() else ""
	($物品名 as Label).text = 名 if not 名.is_empty() else 密卷名
	($物品格/格底/图标 as TextureRect).texture = (
		GAME_DATA.item_icon(密卷id) if not 密卷id.is_empty() else null)
	# `:80-85`：拥有数 > 0 才在格上显数量（`setDataCount`）
	($物品格/数量 as Label).text = str(拥有数量) if 拥有数量 > 0 else ""
	($购买 as Button).visible = true
	# `:92-98`：够才让点「确定」，不够把**格皮+图标**灰化（数量文本不跟着灰）
	var 够 := 拥有数量 >= 需要数量
	($确定 as Button).disabled = not 够
	($物品格/格底 as CanvasItem).material = null if 够 else _灰度材质()
	var 父 := get_parent() as Control
	var 舞台 := 父.size if 父 != null else get_viewport().get_visible_rect().size
	position = Vector2(floorf((舞台.x - size.x) * 0.5), floorf((舞台.y - size.y) * 0.5))
	visible = true


func 打开任务(密卷id: String, 拥有数量: int) -> void:
	打开("任务", 0, 1, 密卷id, 拥有数量)
	($标题 as Label).text = "改变任务"
	($需要数 as Label).text = "改变任务需要在背包中有1个乾坤密卷"
	($询问 as Label).text = "请问你要改变任务吗？"
	($获得途径 as Label).visible = false
	var 说明 := $说明 as Label
	说明.position.y = ($需要数 as Label).position.y + ($需要数 as Label).size.y
	说明.size.y = 105.0
	说明.text = "想让任务变得更简单，而回报却更丰富吗？只要你的背包中拥有“%s”道具，即可降低任务难度，提升奖励回报" % GAME_DATA.item_name(密卷id)


func 隐藏() -> void:
	visible = false


static func _灰度材质() -> ShaderMaterial:
	if _灰度 == null:
		_灰度 = ShaderMaterial.new()
		_灰度.shader = 灰度着色器
	return _灰度
