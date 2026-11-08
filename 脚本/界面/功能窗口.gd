extends CanvasLayer

const WINDOW_SKIN := preload("res://脚本/界面/窗口/界面皮肤.gd")
const 活动窗口 := preload("res://脚本/界面/窗口/活动窗口.gd")
const 活跃度窗口 := preload("res://脚本/界面/窗口/活跃度窗口.gd")
const 社交窗口 := preload("res://脚本/界面/窗口/社交窗口.gd")
const 系统窗口 := preload("res://脚本/界面/窗口/系统窗口.gd")
const 传承窗口 := preload("res://脚本/界面/窗口/传承窗口.gd")
## 首领窗（2026-10-03 合并另一位开发者的首领页包）：数据/交互/换皮全在独立控制器里，
## 活动窗口那边只留了指路注释（`测试/首领页回归测试.gd` 钉着"活动窗口不再留首领代码"）。
const 首领窗口 := preload("res://脚本/界面/窗口/首领窗口.gd")
## 精英副本（2026-10-04 合并「纲手三页」包，1828 已接通）
const 精英副本窗口 := preload("res://脚本/界面/窗口/精英副本窗口.gd")
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
const 进度条补间 := preload("res://脚本/单例/进度条补间.gd")
const 富文本 := preload("res://脚本/界面/富文本.gd")
const 装备部位 := preload("res://脚本/单例/装备部位.gd")
# 默认键位表与 InputMap 注册都在它那里 —— 本文件只负责「快捷键设置」页的显示与改键。
# 注册**不在这里做**：窗口是懒建的，挂在 `_ready()` 上会导致开局 jump/WASD 全不生效。
const 快捷键 := preload("res://脚本/单例/快捷键.gd")

const ORIGINAL_UI := "res://素材/界面/原版窗口/"
const ORIGINAL_BUTTON := ORIGINAL_UI + "通用控件/按钮.png"
const ORIGINAL_TAB := ORIGINAL_UI + "通用控件/分页按钮未选.png"
const ORIGINAL_SLOT := ORIGINAL_UI + "通用控件/物品格.png"
const ORIGINAL_CLOSE := ORIGINAL_UI + "通用控件/关闭按钮.png"
## 那颗 X 的悬停 +30 / 按下 −40 **不在这里**：原版 `MWindowCloseBtnF`（symbol7）`extends MButton3`
## ⇒ 一族一张皮，运行时加性滤镜（`StyleUtil.as:7-12`），Godot 侧只能预烘派生皮再换皮。
## 状态机全工程只有一份，挂在场景上：`场景/界面/功能窗口.tscn` 那颗 X 的
## `script = res://脚本/界面/组件/原版三态钮.gd`（`开发工具/给换皮件挂三态.py` 烘进去的）。
## 代码里现造的 X（`刻印图解` 那张帮助窗）没法烘进场景 ⇒ 用同一份脚本 `set_script` 上去。
const 三态皮 := preload("res://脚本/界面/组件/原版三态钮.gd")
## 「刻印图解」那张图（`UISwf_KeYinHelp_Background`，308×406 纯图，SWF 直解见 §3.135）。
const ORIGINAL_KE_YIN_HELP := ORIGINAL_UI + "装备强化/UISwf_KeYinHelp_Background.png"
const ORIGINAL_CONTENT := ORIGINAL_UI + "通用控件/内容面板.png"
const ORIGINAL_GOLD := ORIGINAL_UI + "通用控件/金币.png"
const ORIGINAL_CASH := ORIGINAL_UI + "通用控件/火影币.png"
const ORIGINAL_SKILL_WINDOW := ORIGINAL_UI + "忍术/忍术窗口底图.png"
const ORIGINAL_SETTINGS_WINDOW := ORIGINAL_UI + "设置/系统设置底图.png"
const ORIGINAL_WINDOW_FRAME := ORIGINAL_UI + "通用控件/窗口边框.png"
const ORIGINAL_SMALL_WINDOW_FRAME := ORIGINAL_UI + "通用控件/小窗口边框.png"
const ORIGINAL_WINDOW_INNER := ORIGINAL_UI + "通用控件/窗口内底.png"
const ORIGINAL_SUB_PANEL := ORIGINAL_UI + "通用控件/子面板.png"
const ORIGINAL_LIGHT_PANEL := ORIGINAL_UI + "通用控件/浅色面板.png"
const ORIGINAL_INPUT := ORIGINAL_UI + "通用控件/输入框.png"
const ORIGINAL_SELECTED := ORIGINAL_UI + "通用控件/选中条.png"
const ORIGINAL_TAB_ON := ORIGINAL_UI + "通用控件/分页按钮选中.png"
const ORIGINAL_BUTTON_DOWN := ORIGINAL_UI + "通用控件/按钮按下.png"
const ORIGINAL_CHECKBOX_ON := ORIGINAL_UI + "通用控件/复选框选中.png"
const ORIGINAL_CHECKBOX_OFF := ORIGINAL_UI + "通用控件/复选框未选.png"
const ORIGINAL_PROGRESS_BG := ORIGINAL_UI + "通用控件/进度槽.png"
const ORIGINAL_PROGRESS_FILL := ORIGINAL_UI + "通用控件/进度填充.png"
const ORIGINAL_DROPDOWN_ARROW := ORIGINAL_UI + "通用控件/下拉箭头.png"

# 九宫格切片来自原版 SWF 的 DefineScalingGrid，单位已由 twips 换算为像素。
# 顺序：左、右、上、下（右/下为距右下边缘的距离）。
const NINE_SLICE := {
	ORIGINAL_WINDOW_FRAME: [48, 48, 29, 13],
	ORIGINAL_SMALL_WINDOW_FRAME: [50, 52, 26, 18],
	ORIGINAL_WINDOW_INNER: [11, 10, 10, 12],
	ORIGINAL_SUB_PANEL: [8, 7, 7, 7],
	ORIGINAL_LIGHT_PANEL: [24, 21, 18, 17],
	ORIGINAL_CONTENT: [11, 10, 10, 20],
	ORIGINAL_BUTTON: [7, 7, 7, 7],
	ORIGINAL_BUTTON_DOWN: [7, 7, 7, 7],
	ORIGINAL_TAB: [7, 8, 7, 7],
	ORIGINAL_TAB_ON: [9, 8, 9, 4],
	ORIGINAL_SLOT: [9, 6, 9, 6],
	ORIGINAL_INPUT: [6, 7, 5, 6],
	ORIGINAL_SELECTED: [9, 8, 5, 5],
	ORIGINAL_PROGRESS_BG: [6, 6, 4, 4],
	ORIGINAL_PROGRESS_FILL: [4, 4, 3, 3],
}
const PLAYER_PORTRAIT := "res://素材/角色动画/玩家/木叶忍者_00000001/Char_00000001.swf_42_Char_00000001_info_portrait.png"
const 人物窗口 := preload("res://脚本/界面/窗口/人物窗口.gd")
const 改名窗 := preload("res://脚本/界面/窗口/人物/改名窗.gd")
const 改名窗场景 := preload("res://场景/界面/窗口/人物/改名窗.tscn")
const 背包窗口 := preload("res://脚本/界面/窗口/背包窗口.gd")
const 忍术窗口 := preload("res://脚本/界面/窗口/忍术窗口.gd")
const 宠物窗口 := preload("res://脚本/界面/窗口/宠物窗口.gd")
const 宠物数值 := preload("res://脚本/角色/宠物数值.gd")
const 装备打造表 := preload("res://脚本/界面/装备打造表.gd")
## 「是不是宝石」的判定**只认这一份**（类型 13，`ItemType`/`isItemABaoShi` 同源）——
## 镶嵌窗的拖放和合成窗的拖放/开门要同一口径，别再抄第二份（§3.82 canTrade 那族教训）。
const 宝石孔格脚本 := preload("res://脚本/界面/组件/宝石孔格.gd")
## 属性名/属性英文名那两张表**只认提示框那一份**（`装备提示框.属性名` / `.属性英文名`）——
## 它们是从 `ItemFactory.SUB_ATTR_TYPES/_NAMES/_EN_NAMES` 逐字抄来的，再抄一份迟早对不上。
const 装备提示框 := preload("res://脚本/界面/组件/装备提示框.gd")
const 格子提示框 := preload("res://脚本/界面/组件/格子提示框.gd")
## 悬停详情框的两个场景。灵器炼制页 / 两扇兑换窗的场景里都没烘它们（SPEC 生成物，
## 不手改 .tscn）⇒ 渲染时运行期挂，口径同 `勾玉炼制窗.建提示框`。
const 物品提示场景 := preload("res://场景/界面/组件/物品提示框.tscn")
const 装备提示场景 := preload("res://场景/界面/组件/装备提示框.tscn")
## 部位列表行要复用装备格的资质框表（`SimpleItemCell.showIcon` 用的是同一套）
const 装备品质脚本 := preload("res://脚本/单例/装备品质.gd")
## 原版按钮的**禁用态灰度**（`MButton3.updateState` → `StyleUtil.getGrayFilter`）。
## 所有 `MButton3` 系按钮禁用时都套它，不止翻页条那几个。
const 禁用灰度着色器 := preload("res://脚本/界面/组件/禁用灰度.gdshader")

static var _禁用灰度材质: ShaderMaterial = null

static func 禁用灰度材质() -> ShaderMaterial:
	if _禁用灰度材质 == null:
		_禁用灰度材质 = ShaderMaterial.new()
		_禁用灰度材质.shader = 禁用灰度着色器
	return _禁用灰度材质
const 装备强化页面场景 := preload("res://场景/界面/窗口/装备强化/装备强化窗口.tscn")
const 宝石镶嵌页面场景 := preload("res://场景/界面/窗口/宝石镶嵌/宝石镶嵌窗口.tscn")
const 宝石工艺页面场景 := preload("res://场景/界面/窗口/宝石工艺/宝石工艺窗口.tscn")
## 专属面板页（原版是 `new` 出来的面板，盖住整个内容区 350x316）
const 装备进阶页场景 := preload("res://场景/界面/窗口/装备强化/页面/装备进阶页.tscn")
const 装备洗附加属性页场景 := preload("res://场景/界面/窗口/装备强化/页面/装备洗附加属性页.tscn")
const 装备刻印页场景 := preload("res://场景/界面/窗口/装备强化/页面/装备刻印页.tscn")
const 装备精炼页场景 := preload("res://场景/界面/窗口/装备强化/页面/装备精炼页.tscn")
# 注意：`场景/界面/窗口/装备强化/页面/装备打造通用页.tscn` **没有在这里 preload** ——
# 它是旧模板残留，本文件从来没 instantiate 过它（那个 const 是死代码，2026-09-25 清掉）。
# 场景文件本身**还在**：`测试/UI资源回归测试.gd` 拿它当 `setSize(350,349)` 的断言对象。
const 秘笈合成窗口 := preload("res://脚本/界面/窗口/秘笈合成窗口.gd")
const 意志窗口 := preload("res://脚本/界面/窗口/意志窗口.gd")
const NPC商店页面场景 := preload("res://场景/界面/窗口/NPC商店/NPC商店窗口.tscn")
const 商店商品格场景 := preload("res://场景/界面/组件/商店商品格.tscn")
const 仓库窗口 := preload("res://脚本/界面/窗口/仓库窗口.gd")
## 默认键位表已移到 `脚本/单例/快捷键.gd`（真值只有那一份），这里只留一个指针，
## 免得下次又有人在本文件里加一份。

## 窗口几何表，事实来源见 数据/界面/窗口尺寸.json。
## 原先此处是一个 27 分支的 match，尺寸与容器边距混在一起；现改为数据驱动。
const 窗口尺寸表路径 := "res://数据/界面/窗口尺寸.json"
const 商城分页表路径 := "res://数据/界面/商城分页.json"

## UIWindow.as:37-38 / 64-65 —— drawContentBg 为真时内容底的固定几何。
const 内容底偏移 := Vector2(8.0, 38.0)
const 内容底高度缩减 := 68.0
## MWindow.as:166 标题基线 y（_isSmallBackground 为假时）。
const 标题Y := 5.0
## 标题**文字盒**的 y。原版是 Flash TextField：`y=5` 时墨迹正好从第 5 行开始（基线实测 5..16）。
## Godot 的 Label 会把 17px 行盒在矩形里居中，同样给 5 会整体掉到 8..19，实测低 3px。
const 标题文字Y := 2.0
## MWindow.as:229 拖动区高度。
const 拖动区高 := 29.0

static var _窗口尺寸表: Dictionary = {}
static var _商城分页表: Dictionary = {}


## 商城页签真值（`数据/界面/商城分页.json`，生成器 `开发工具/导出商城分页.py`）。
##
## ⚠️ 页签**不是写死的**：原版 `CashShopWindow2.as:171-191` 从 GameData 的
## `String/ShangCheng.yuanbao.tab0..tab19` 顺序读、遇到缺号停，末尾再补一个「荣誉类」
## （语言表 `CASHSHOP_RONGYU`）。本机读出 8 个 +「荣誉类」= 9。
## **数组下标就是发给服务端 432 包的 categoryId**（`:149` → `:570`），别再另立一套映射。
static func _取商城分页表() -> Dictionary:
	if not _商城分页表.is_empty():
		return _商城分页表
	var 文件 := FileAccess.open(商城分页表路径, FileAccess.READ)
	if 文件 == null:
		push_error("商城分页表缺失：%s" % 商城分页表路径)
		return {}
	var 解析结果: Variant = JSON.parse_string(文件.get_as_text())
	文件.close()
	if typeof(解析结果) != TYPE_DICTIONARY:
		push_error("商城分页表不是合法 JSON 对象：%s" % 商城分页表路径)
		return {}
	_商城分页表 = 解析结果
	return _商城分页表

static func _取窗口尺寸表() -> Dictionary:
	if not _窗口尺寸表.is_empty():
		return _窗口尺寸表
	var 文件 := FileAccess.open(窗口尺寸表路径, FileAccess.READ)
	if 文件 == null:
		push_error("窗口尺寸表缺失：%s" % 窗口尺寸表路径)
		return {}
	var 解析结果: Variant = JSON.parse_string(文件.get_as_text())
	文件.close()
	if typeof(解析结果) != TYPE_DICTIONARY:
		push_error("窗口尺寸表不是合法 JSON 对象：%s" % 窗口尺寸表路径)
		return {}
	for 键 in (解析结果 as Dictionary):
		# 以 _ 开头的键是表内自述文档，不是窗口条目。
		if not String(键).begins_with("_"):
			_窗口尺寸表[键] = (解析结果 as Dictionary)[键]
	return _窗口尺寸表

var _session: Node
var _backend: Node
var _activity: Node
var _overlay: Control
var _window: Control
## 外框尺寸（`_apply_original_window` 记下、`_镶嵌定宽` 会改宽）。
## 摆位置时要用它反算锚点偏移 ⇒ 落点能精确踩在整像素上（见 `_居中偏移`）。
var _外框尺 := Vector2(517, 440)
var _frame: Panel
var _content_bg: Panel
var _title: Label
## 标题尾巴（背包「(已用/总)」这类要跟标题分开排版的数字）。
## ⚠ 不能塞回 `_title`：标题变体是 `FontVariation` 合成加粗，ASCII 经它一渲染就带一圈
## 中间灰（§3.281；用户 2026-10-25 报「已用和总的值，还是模糊」）。这里用**裸 FontFile**
## + 独立字号，数字字芯才会是纯 255。由 `设置标题` 填、`_apply_original_window` 清。
var _title_数值: Label
## 场景里标题的原始 y（2）。没有尾巴的窗口保持这个落点；有尾巴时（背包）
## 要按用户要求把整条标题在 29px 标题栏里**垂直居中**，换页/换标题时必须能退回去。
var _标题初始Y := 0.0
var _content: Control
var _close_button: Button
## 这一次 `_render_page()` 是不是"开窗"触发的（true）而不是回帧引起的重建（false）。
## **只喂给 `open_page()` 自己那一轮渲染**：置真 ⇒ 渲染 ⇒ 立刻置假，所以其余那些
## `_render_page()` 调用点（回帧、切页签、按钮回调）一律读到假，不会重复发开窗查询。
var _刚开窗 := false
var _drag_area: Control
var _status: Label
## 提示行的**自收**账（用户 2026-10-22 报修 9「灰色字体一直挂在面板上方，不消失，除非关闭面板」）。
## 真值：原版那句反馈不是窗内的常驻标签，而是 `MessageTipPane` 的黄色飘字 ——
## `MessageTipPane.as:80-97` `showMessage` 里 `TweenLite.to(tf, 5, {y:-60, alpha:0, onComplete:remove})`：
## **5 秒**里升 60 像素并淡到全透明、然后自己从容器摘掉（攒过 `MAX_LINES=10` 行还挤掉最旧那行）。
## 本工程把它复用在窗内那枚灰色 `后端状态` 标签上、又没搬那套补间 ⇒ 写完就**常驻**。
## 这里按同一个 5 秒收：到期只清空文本并藏掉标签，节点与落点都不动（不做位移动画 ——
## 这枚标签钉在标题行里，飘走会拖着一整条标题动）。
## ⚠ `_on_backend_status` 写的也是这枚标签（`后端：…`），但它**不**排自收 ⇒
##   提示到期时若标签已被那句盖掉，一并收掉。那句只在连接状态变化时重刷，不是玩家要读的东西。
const 提示自收秒 := 5.0
var _提示代号 := 0
var _current_page := ""
var _dragging := false
var _drag_offset := Vector2.ZERO
var _selected_inventory_id := ""
## 选中背包格的**1 基绝对格位**（`物品格.槽位号`）。
## ⚠️ 绑定这类"按格位操作"必须用它，**不能**从 `_selected_inventory_id` 反查
## （`_inventory_index` 按 id 找第一摞，同 id 两摞会绑错格 —— 和 §3.81.1
## 销毁/出售/存入那条"按格不按 id"是同一族）。单击弹菜单时就在这里记格位。
var _selected_inventory_格 := 0
## 「宝石镶嵌与取出」窗（`StoneCarryWindow`）正操作的那件装备的**背包格号（1 基）**与 id。
## 原版 `setData(eqtData)` 存 `_eqtData`，镶嵌/取出都按它的 `position` 发；
## 装备若被别处移动/镶嵌回包换件 → 对应原版 `itemDatachanged`（拿不到或 id 变了就关窗）。
var _宝石镶嵌装备格 := 0
var _宝石镶嵌装备id := ""
## 宝石工艺窗（`StoneWindow`，页面名"挖矿"）**合成页**正操作的那摞宝石的背包格号（1 基）与 id。
## 原版 `StoneCompositeWindow._itemData`（`validateItem:181-212` 放进来、`itemDatachanged:335-352`
## 每次刷新**按格位现读**、换件/没了就 `backItemToEquip` 清掉）。跨窗状态设在渲染那页的宿主上（§3.62）。
var _宝石合成格 := 0
var _宝石合成id := ""
## 最近一次 `STONE_MERGE_RESPONSE(1042)` 的解析结果（`{kind:"stone_merge", success_count,
## success_item_id, success_level, failed_count, failed_item_id, failed_level,
## left_count, left_item_id, left_level}`）。原版 `operationResultHandler:132-171` 拿它填
## **成功/退还/剩余**三格；**没收到回包前三格是空的**，放进新宝石也会清空（`dropItemHandler:175-177`）。
var _宝石合成结果: Dictionary = {}
## 当前挂着的「幸运合成」页（tab2 才非空）—— 提交时要读它身上的**勾选与张数下拉**。
## 页面每次渲染都是新建的，`_配置幸运合成页` 里覆盖；离开 tab2 时不清也不打紧（提交只在 tab2 走）。
var _幸运合成页: Control = null
## 仓库「批量存取」开关 —— 对应原版 `UIConfig.isSaveOrTakeItem`
## （`StorageWindow2.as:746-763` 切光标模式 `StorageTakeCursorF` 时置 true）。
## 打开后单击物品格直接存/取，而不是弹菜单（原版 `onItemDoubleClick` 也吃这个标志）。
var 批量存取模式 := false
## NPC 商店「出售」开关 —— 对应原版 `UIConfig.isSaleItem` + `UIConfig.saleValidateFun`
## （`ShopWindow2.as:646-648` 选出售时置位，`:631-650` 关掉时清）。
## 开着时，**单击背包物品**走商店的买卖数量窗去卖（原版是 `saleValidateFun(item)` 回调），
## 而不是弹物品菜单。跟 `批量存取模式` 是同一类跨窗口模式开关。
## ⚠️ 商品格**不受它影响** —— 原版 `onItemClick`（`:415-424`）不判 `_isBuy`，点格子永远是买。
var 商店出售模式 := false
var _selected_pet_id := ""
## 背包 / 仓库的**当前页**。存窗口上、不存 `背包窗口.gd` 的 static ——
## 那两个模块的 `渲染()` 每次都会把页码清零，而"拖一件装备穿上"会触发
## `equipment_changed` → `_refresh_current()` → 重建整页，于是**刚翻到的页被打回第一页**
## （2026-09-27 用户报"装备拖到人物面板后背包自动返回第一页"）。
## 开窗时在 `open_page` 里复位，重建时不碰。
var _背包页 := 0
var _仓库页 := 0

var _quest_tab := 0
var _selected_quest_id := ""
var _team_tab := 0
var _friend_tab := 0
var _shop_tab := 0
var _shop_query := ""
## 搜索框里**当前打着的字**（还没点「搜索」也算）。`_shop_query` 是"已经发出去的那次搜索词"，
## 两者维度不同：原版 `keywordsText.text` 只是输入框内容，`isSearch` 才决定这一跳发不发搜索
## （`CashShopWindow2.as:461-473`）。存窗口上是因为页面每帧重建（同 `_shop_scroll` 那条）。
var _商城搜索草稿 := ""
## 商城的页码（1 基）。原版是 `PageComponent` 的 `_currentPage`（`PageComponent.as:104-113`），
## 每页 20 条，翻页发 `requestData(indexBegin, indexEnd)`。
var _shop_page := 1
## 商城 / NPC 商店货架的**滚动位置**。
##
## ⚠️ 与 `_境界展开` 是**同一类毛病、同一个修法**（§3.40）：`_render_page()` 会把整页
## 拆掉重建，而 `social_changed` / `player_stats_changed` / `inventory_changed` 等
## **十几个信号**随便来一条就 `_refresh_current()` → 重建 → 滚动条回到顶上。
## 用户 2026-09-26 看到的就是「商城往下滚，又自动弹回上面」。
##
## 所以位置必须存在**窗口**上：重建**之前**先从旧页读出来，建完再放回去。
## ⚠️ 不要在重建过程中监听 `value_changed` 去记 —— 重建时滚动条会被夹到 0，
## 那一瞬间的 0 会把真位置冲掉。只在拆页之前读、建完之后写。
var _shop_scroll := 0
var _npc_shop_scroll := 0
## 商城**购买窗正开着哪件商品**（空 = 没开）。
##
## ⚠️ 必须存在窗口上，理由和 `_shop_scroll` / `_境界展开` 完全一样：
## `social_changed` 等信号会 `_refresh_current()` → `call_deferred("_flush_refresh")` → 整页重建，
## **刚打开的购买窗会连同旧页一起被换掉**。用户看到的症状是"点购买有时弹有时不弹"，
## 因为它取决于那次重建有没有排在打开动作之后（间歇性，最难查的一类）。
## 所以：打开 = 写这个字段 + 重建；重建完按它把弹窗重新开出来；关闭/成交 = 清空。
var _商城购买商品: Dictionary = {}
## **这一扇自己**有没有发过 1086（查商城单件详情）。1079 回包是广播给所有开着的宿主的，
## 没有这一旗就会"每个开着的窗各弹一枚购买道具窗"（10-20 深夜实机「购买道具页关不掉」的根因：
## 两枚叠在同一个正中位置，点掉上面那枚下面还压着一枚）。原版只有一个处理者
## （`UIMain2.addBuyWindow:2906-2913` 挂 `_windowMap[BUY_EQP_WINDOW]` 那一个 key）⇒ 谁问的谁弹。
var _等1079 := false
## 背包物品菜单「强化」在**昆虫**上带进来的那只虫（原版 `KunChongManager.showStrengthView(curCellData)`）。
## 人物窗的寄坏之术页读它当强化目标；`_角色携入位置` 是**发给服务端**的那个位置
## （已装备的虫 = 装备位；背包里的虫 = 它那一格的背包格号）。空 = 没携入，走"第一个已装备的"。
## 修复窗"放进台子上的那件"（原版 `_itemData`）与它的背包格号。
## 灵器炼制（洗练/灵化/开光）带进来的那件与它的格号 —— 三扇共用（版式相同、只换文案）。
var _灵器炼制物品: Dictionary = {}
var _灵器炼制格 := 0
## 原版 `LingQiManager.plusAttr` 那一档（`:47`）：**不是**每次渲染从物品现算，而是
## ① 开窗 `setData` 按那一件的附加属性灌一次；② **灵化成功**回来硬置 **1**
## （`onLingEquipLingHuaResult:260-276` 里就写 `plusAttr = 1`，**不是** 1×6=6）；
## ③ **洗炼成功**回来才 `updatePlusAttr:278-281` 取「第一条 × 6」。
## ⇒ 必须挂在宿主上（翻页重绘不丢），页里现算会把②那一档抹平。
var _灵器附加展示 := 0
## 原版「开光」那两扇点一次就把钮**按住**（`KaiGuangWindow.as:160` /
## `RenJuKaiGuangWindow.as:172` 都在发请求前置 `kaiGuangBtn.enabled = false`）：
## 灵器那扇的结果帧是空函数（`LingQiManager:302-304`）⇒ **再也不放开**；
## 忍具那扇的结果帧第一句就是 `enabled = true`（`:72`）⇒ 回帧一定放回。
var _灵器开光已点 := false
var _灵器开始钮: Button
## 忍具（人具）那支「开光」的页名 —— 版式同一扇、协议换成 `RENJU 2082` 子命令 0。
const 页_开光人具 := "开光人具"
var _装备修复物品: Dictionary = {}
var _装备修复格 := 0
var _角色携入虫: Dictionary = {}
var _角色携入位置 := 0
var _skill_tab := 0
var _selected_skill_id := ""
## 忍术页「忍术境界」面板是不是展开着。
## ⚠️ 必须存在**窗口**上、并在重渲染时还原：`_渲染境界` 每次都会新建面板并以"收起"起始，
## 而服务端推送（`skills_changed` 等十来个信号）随便来一条就会 `_refresh_current()` 重建整页 ——
## 面板于是自己弹回去。用户 2026-09-26 看到的就是「点开又自动返回忍术面板」。
var _境界展开 := false
var _settings_tab := 0
## 排行榜当前选中的**榜单号** = `Etc.PaiHangBang` 的 menuId（0..22），**不是 0..3 的页签序号**。
## （旧版把它当自造的四枚页签序号用，配上 `2329` 那个跨服充值榜 opcode ⇒ 整页从来没真过。）
var _ranking_tab := 0
## 排行榜「忍界榜 / 同级榜」= 原版 `RankWindow2.changeTab(p)` 的那个 p（0 忍界、1 同级）。
## 上行的那个 bool 由它决定：原版 `requestListData:106` 发的是 `!renJieBtn.enabled`，
## 而 `renJieBtn.enabled = (p != 0)` ⇒ **flag = (p == 0)**。服务端字段叫 `bJiangHu`、
## 客户端叫 `renJieBang`，名字反着来，别按名字猜。
var _排行页 := 0
## 翻页页序（0 基；显示时才 +1，对应原版 `PageComponent.currentPage`）。
## 回帧时归 0 —— 原版是 `setData:366 _pageComponent.reset(len, 10)`，`reset` 里 `currentPage = 1`。
var _排行码 := 0
var _exchange_mode := 0
var _map_view_tab := 0
var _prize_tab := 0
var _activity_overview_tab := 0
var _info_tab := 0
var _stone_tab := 0
## 当前选中的强化部位 —— **装备位置 int**（见 `脚本/单例/装备部位.gd`），2026-09-21 从中文名改过来
## ⚠️ 它现在只是"穿在身上那件"的**位置游标**；左栏到底放没放东西看 `_强化放入中`（下面三行）。
## 「勾玉炼制」页带进来的那件（背包**物品菜单**（左键单击格子弹出）的 升阶/合成/重置 ⇒ 原版 `ItemWindow2.showYuLianJinJieWindow(页, 物品)`）。
## 与 `_selected_strengthen_slot` 同理：**跨窗状态设在渲染那一页的宿主上**（§3.62 咬过两回）。
var _jade_item := {}

var _selected_strengthen_slot := 装备部位.武器
var _strengthen_tab := 0
## 精炼页下拉**跨重渲染**记住的锻造项（`_render_strengthen` 每收到一次回包就整页重建，
## 原来 `_配置精炼页` 每次都写死 `selected = 0`，用户 2026-11-01 报「精炼后选择锻造项被重置」）。
## 换页签 / 重开窗才回默认（原版 `EquipBaiLianPanel.showView()` 就是回 index 0）。
var _精炼项选中 := 装备打造表.精炼项_附加属性
## 左栏"放入装备"的那件（原版 `_itemData`）。原版**开窗时是空的**
## （`EquipStrengthWindow.as:166/181` `_itemData = null`），点部位列表行或放入门光标才放进；
## 我们以前没有这个状态，左栏**永远显示 `equipped_items[游标]`** —— 于是：
##   · 开窗就"已经放着"一件，「取出装备」根本无处可取；
##   · 部位列表里**背包那半**（原版 `getStrengthEquipItems` 先穿着后背包）点了没反应 ——
##     `_会话选中()` 只查 equipped_items（2026-10-01 用户报"打造面板很多bug"里的两条）。
## 放入来源两种："" = 身上穿的（用 `_selected_strengthen_slot` 现读，属性刷新不掉），
## "背包" = 用 `格+id` 在 `inventory` 里现读（被打造消耗/移走时自动落回"没放"态，
## 对位原版刷新时 id 对不上就 `backItemToEquip()`，`:462-466`）。
var _强化放入中 := false
var _强化放入来源 := ""
var _强化放入格 := 0
var _强化放入id := ""
## 「装备打造」右栏部位列表选中的页签序号（0=全部 1=白色 2=绿色 3=蓝色 4=紫色）。
var _部位列表页 := 0
## 右栏部位列表的**页码**（0 基）。一页 2 列 x 6 行 = 12 件。
var _部位列表页码 := 0
var _npc_shop_tab := 0
## NPC 商店的买卖光标模式：0 = 购买、1 = 出售、**-1 = 都没选**（原版开窗时就是没选，
## 光标要点了按钮才出现，见 `_set_npc_shop_mode`）。
var _npc_shop_mode := -1
## 「看别人」那一扇的档案（`窗口管理._on_other_char_info` 灌进来；改名/宠物页要现取）。
var _他人档案: Dictionary = {}
## 原版 `CharPointInfoPane.as:239` `troopBtn.enabled = !API.dataCenter.isInTroop(id)`：
## 对方**已经在自己队里**时那颗「组　队」是灰的，不是点了报一句错。
var _他人已在队 := false
## 「看别人」那扇宠物页的游标（原版 `SimplePetWindow._curPet`）：与本窗 `_selected_pet_id`
## 是两个独立游标；归属号用来判"换了人 ⇒ 回到第一只"。
var _他人宠物选中号 := ""
var _他人宠物归属号 := -1
## 「角色改名」那扇的**模式开关**：空 = 改自己的名（输入框/购买/确定/卡格都在），
## 非空 = 看某个人的历史名（原版 `ChangeWindow.setOtherPlayerMode(名)` ⇒ 藏七件、
## 历史名上移 82、标题变「<名> 的历史名字」）。名单本身在 `2330:10/12` 那一发里。
var _改名别人名 := ""
var _改名名单: PackedStringArray = PackedStringArray()
var _character_main_tab := 0
var _character_sub_tab := 0
## 八门页当前看的是哪一门（空串 = 总览）。原版 `JingMaiPanel` 的 tabBar 选中态是常驻的；
## 我们这边每次回帧整页重建，`初始化八门页` 原来固定落回总览 ⇒ 开通失败后玩家被弹回
## 「主页」（2026-10-20 报修）。记在窗口上才能跨重建。
var _八门选中门 := ""
## 「开通穴道」弹窗开没开 + 选中的是哪一枚（门序, 客户端点序, 穴名）。
## 原版这个弹窗是**独立 UIWindow**，数据回包不会把它关掉；我们这边它烘在八门页里，
## 整页重建会把它连同开合态一起清掉。失败结果帧一到，页面看着就像"被打回主页"。
## 记在窗口上，重建后照原样开回来（2026-10-20 报修）。
var _八门穴位弹窗开 := false
var _八门选中穴位: Array = []
var _character_pending_ap := {"ap_atk": 0, "ap_def": 0, "ap_dex": 0, "ap_phy": 0}
## 「战斗属性」那枚箭头开没开 **「其他属性」浮板**（原版 `CharPane.as:333-339` 翻的三件
## `visible`）。同样记在窗口上：整页每次回包重建，页面实例上的态活不过一次刷新。
var _其他属性开着 := false
## 结印「自动提升」的**在不在自动态**（原版是 `JieYinTiShengWindow._isAutoTiSheng`）。
## 记在**窗口**上而不是页面上：`_render_page()` 每一帧回包就重建一次页面，
## 页面实例上的东西活不过一次刷新（钮文字靠它在重建后复原）。
var _结印自动提升 := false
## 同上，记「提升结印阶数弹窗」开没开 —— 重建后按它落回展开态、不重播滑入。
var _结印弹窗开着 := false
## 下一跳的计时器**令牌**：停自动时置空，比"令牌照旧"多一道保险
## （已排的那发 timeout 仍会触发，但令牌不匹配就不会再发包；同 `_排一次重试` 那套）。
var _结印自动计时: SceneTreeTimer = null
## 写轮眼 / 柔拳 / 轮回六道那三族的同一套状态（族名 ⇒ 值），与结印那三个变量并列：
## 结印走 `jieyin_state_received`（2318 是独立 opcode、字段语义也不同），已经单独一套并钉在门里，
## 这三族走 `修炼结果帧` ⇒ 各自一套、互不串味。同样**记在窗口上**：回帧引起的整页重建
## 活不下来（钮文字与弹窗开合都靠它在重建后复原）。
var _族自动提升 := {}
var _族自动计时 := {}
var _族弹窗开着 := {}
## 手里剑突破弹窗里「失败后自动继续」那一勾（原版 `_failCheckBox`，`ThroughShouLiJianWindow.as:348`）
## 与排队中的那发重试的**令牌**。⚠️ 记在窗口上、不记在弹窗控件上：页面重绘会换掉整棵弹窗件
## （与 `_结印自动提升` 同一处置），回灌点在 `人物窗口.初始化手里剑页`。
var _手里剑失败继续 := false
var _手里剑重试计时: SceneTreeTimer = null
## 昆虫强化弹窗（报修 2.1）的状态：窗开着 / 放置格里有虫 / 两枚勾与张数 / 自动循环开着 /
## 当前强化目标那件（`虫`、`位`）/ 拖走后的位置（`置`，报修③）。与 `_族弹窗开着`、`_手里剑失败继续` 同一处置 ——
## 每一发 2066 回帧都重画整页，弹窗、CheckBox、OptionButton 都是**新节点**，
## 不记在窗口上就闪回原形（玩家勾完「本次操作使用寄坏玉」，一发回帧就被弹回未勾）。
## 回灌点在 `人物窗口._接昆虫弹窗`（节点上的 `set_meta` 键才必须 ASCII，这里这层是普通字典）。
var _昆虫强化态 := {"开": false, "放": false, "镇": false, "玉": false, "张": 1, "自动": false, "虫": {}, "位": 0, "置": null}
## 「自动强化到10并停止」排队中的那一跳（原版 `onStengthResult:588` 的 `setTimeout(…, 500)`）。
## 令牌比对同 `_手里剑重试计时:423` —— Godot 的 SceneTreeTimer 撤不掉，只能比引用。
var _昆虫强化自动计时: SceneTreeTimer = null
## 发出去的那一跳的**发起快照** `{位置, 等级}`：原版把 `_lastLevel` 记在窗上（`strengthEquip:351`），
## 回帧的三句提示要的是发起前的星级（`人物窗口.收昆虫强化回帧`）。
var _昆虫强化发起 := {}
var _shortcut_waiting_action := ""
var _refresh_queued := false
## 物品菜单开着时被推迟的那次整页重建（见 `_flush_refresh` 的说明）。
var _refresh_waiting_menu := false
## 回帧引起的整页重建会 free 掉玩家**正在打字**的那枚 `LineEdit`（商城搜索框、家族/好友搜索框、
## 礼包兑换码框……页面里烘了 `LineEdit` 的页都算；十几个信号都走 `_refresh_current`，
## 实机里几乎每帧来一条）⇒ 字被冲掉、焦点跑掉，
## 表现为"搜索框打不进字"。重建前把 `{路径, 文本, 光标}` 记在这儿，重建后按同一路径交还给新控件。
var _输入接力 := {}
var _legacy_tab := 0
var _card_level := 40
var _card_node := 0
var _chest_id := 10001
var _buff_slot1 := 0
var _buff_slot2 := 0
var _heal_target := 1
var _活动窗口
var _社交窗口
var _系统窗口
var _传承窗口

func _ready() -> void:
	_活动窗口 = 活动窗口.new(self)
	_社交窗口 = 社交窗口.new(self)
	_系统窗口 = 系统窗口.new(self)
	_传承窗口 = 传承窗口.new(self)
	_session = get_node_or_null("/root/GameSession")
	_backend = get_node_or_null("/root/BackendConnection")
	_activity = get_node_or_null("/root/ActivityService")
	# 快捷键的注册**不在这里**：窗口是懒建的，挂在这儿的后果是"开局没开窗口之前
	# jump/WASD 都不生效"。已移到 `游戏会话._ready()`，见 `脚本/单例/快捷键.gd`。
	_bind_scene_nodes()
	if _session != null:
		# 多窗口：底栏信号由 `窗口管理` **一家**接（开、关、置顶都归它）。
		# 本实例只在**没被窗口管理接管**时才直连 `open_page` —— 那是老的"单窗口换页"用法。
		#
		# ⚠️ 判据取**父节点的能力**，不能取 `_固定页`：`窗口管理._新建窗口` 是先
		#   `add_child(窗)` 再 `设为单页(...)`，`_ready` 跑的时候 `_固定页` 还是空串。
		#
		# 不隔这一下的后果（用户 2026-09-24 报的"再点一下不关闭、反而复原位置"）：
		#   点一次按钮 → `打开或收起` 先 `close()` → 紧接着本实例自己的 `open_page`
		#   又把它 `visible = true` 并 `_apply_original_window` 强制回居中，
		#   把窗口重新打开、还抹掉玩家拖过的位置。
		if not _由窗口管理接管():
			_session.feature_requested.connect(open_page)
		# 属性/库存这两条走 `_on_资源帧`（停在修炼族子页时原地刷，别把玩家正开着的突破弹窗拆了）。
		_session.player_stats_changed.connect(_on_资源帧.unbind(1))
		_session.inventory_changed.connect(_on_资源帧.unbind(1))
		_session.storage_changed.connect(_refresh_current.unbind(1))
		_session.npc_shop_changed.connect(_refresh_current.unbind(1))
		# 装备这条**不进 `_on_资源帧`**（换装是真重建需求），但 `应用背包` 已改成**装备表真变了才发** ——
		# 背包扣料帧不再捎带一发把这身守卫全破光（2026-10-28 手里剑突破失败拆弹窗的根因，§3.307）。
		_session.equipment_changed.connect(_refresh_current.unbind(1))
		_session.skills_changed.connect(_refresh_current.unbind(1))
		_session.quests_changed.connect(_refresh_current.unbind(2))
		_session.pets_changed.connect(_refresh_current.unbind(1))
		# 首领列表回帧（1351）⇒ 若正开着首领页，重渲染把真 alive/倒计时换上（2026-10-03 接通）
		_session.wang_list_changed.connect(_refresh_current.unbind(1))
		# 意志回帧族（1823）⇒ 重渲染当前页换真数据（面板 guard 保证不会二次 open 成环）
		_session.spirit_state_changed.connect(_refresh_current)
		# 阅历帧（1572）⇒ 学习页就地刷两个货币标签，**不重渲染**（重渲染⇒重建⇒再请求⇒成环，
		# 见 `游戏会话.阅历_变化` 信号声明处的说明）。
		_session.阅历_变化.connect(_on_阅历_变化)
		# 精英副本进入列表（1828/0）⇒ 刷「x/y 次」
		_session.hero_state_changed.connect(_refresh_current)
		_session.social_changed.connect(_refresh_current)
		_session.settings_changed.connect(_refresh_current.unbind(1))
		_session.cultivation_changed.connect(_on_cultivation_changed)
		_session.copy_changed.connect(_refresh_current.unbind(1))
		_session.hang_changed.connect(_refresh_current.unbind(1))
	if _backend != null:
		_backend.connection_status_changed.connect(_on_backend_status)
		# 宠物动作回帧 `pet_action_received` **故意不接**（§3.204）：它的 action 9 是宠物喊话
		# （`PetProcessor.handlePetAction_chat` ⇒ `Client.onPetChat`，原版那份实现是空的），
		# 不是拒绝通道；服务端的真拒绝是 `CHAT_MESSAGE` 的 `CHAR_NOTICE(512)` 位，
		# 由 `后端连接._handle_chat_text` 直接进提示口子，与本窗无关。
		# 家族创建成功 → 收掉创建流程的窗（见 `_收到家族状态`）。
		if _backend.has_signal("guild_state_received"):
			_backend.guild_state_received.connect(_收到家族状态)
		if _backend.has_signal("item_change_result_received"):
			_backend.item_change_result_received.connect(_on_item_change_result)
		if _backend.has_signal("inventory_delta_received"):
			_backend.inventory_delta_received.connect(_收到打造装备帧)
		_backend.quest_progress_received.connect(_收到环任务进度)
		if _backend.has_signal("shop_transaction_received"):
			_backend.shop_transaction_received.connect(_on_shop_transaction)
		if _backend.has_signal("storage_full_received"):
			_backend.storage_full_received.connect(func(): _show_hint("仓库已满"))
		# 1079（商品详情）→ 原版 `Client.onCashItemInfo`（`Client.as:7787-7791`）。
		# ⚠️⚠️ **只让最上层那扇窗弹**（2026-10-16 修）：1079 是全局信号，而**每扇窗各有自己的 `遮罩`**
		#   ⇒ 每个实例都接的话，一次回包会叠出 **N 枚购买窗 + N 层遮罩**（探针实测：开 3 扇窗 ⇒ 3/3）。
		#   玩家关掉看得见的那一枚后，剩下的遮罩继续吃点击 ⇒ **整屏像卡死**。
		#   症状就是"背包扩充里买过一次、再买一次就卡住"（第一次没事＝当时只开着一扇窗）。
		# 八门「开通穴道」的延迟引爆：**关掉人物窗 → N+1 秒后再开回来**（原版
		# `Client.onMaiDelayExplode:11464-11485`）。到点时服务端已结算并推了统计帧，
		# 重开时的重渲染就会把刚开通的那枚穴位点亮。
		if _backend.has_signal("八门倒计时"):
			_backend.八门倒计时.connect(_on_八门倒计时)
		# 结印的**每一跳结果**（2318:2）驱动原版那个"自动提升"客户端循环
		# （`onJieYin_stageupResult` → 0.8 秒后再发一发 / 停）。见 `_收到结印帧`。
		if _backend.has_signal("jieyin_state_received"):
			_backend.jieyin_state_received.connect(_收到结印帧)
		# 别三族（写轮眼/柔拳/轮回六道）的同一套循环，心跳是**升阶结果帧**（动作 2）。
		if _backend.has_signal("修炼结果帧"):
			_backend.修炼结果帧.connect(_收到修炼结果帧)
		if _backend.has_signal("cash_item_info_received"):
			_backend.cash_item_info_received.connect(_收1079)
		# 容量帧（1084 背包 / 1085 仓库）：背包窗与仓库窗的总格数是**渲染时**读
		# `authoritative_bag_capacity` 的 ⇒ 不重画就等于没扩充。
		# ⚠️ 这两个信号原先**全工程零连接点**（2026-10-11 扫"emit 了没人接"逮到）。
		#    服务端是**先发背包/仓库帧、后发容量帧**（`_extend_item_capacity` 尾部才 `send_text`）
		#    ⇒ 只有两帧被同一次 socket 读一起拿到、`_refresh_current` 那个 `call_deferred`
		#    落在两帧之后，界面才碰巧是新的；拆到两次读就停在旧格数上（**顺序竞态**）。
		#    接上它把这条变成确定的，不再靠包合并。
		# 仓库那条（1085）不在这里接：它走的是 `会话.storage_changed`（上面已接），
		# 由 `后端连接` 在容量帧里补一次 `apply_backend_storage` 落会话字段 —— 见那边的注释。
		if _backend.has_signal("bag_capacity_received"):
			_backend.bag_capacity_received.connect(_refresh_current.unbind(1))
		# 荣誉积分帧（`2323:8:`）—— 原版 `MuYeDaZhanManager.onMuyeBattle_updateFamePoint:617-624`
		# 只有一句"存下来 + **if (cashShopWindow) updateRongYu()**"。这里等价：存值在后端字典里，
		# 商城开着就重画一次（`_refresh_current` 自带 `not _overlay.visible ⇒ return` 的闸，
		# 没开着的那几扇窗不会跟着刷）。
		if _backend.has_signal("荣誉积分帧"):
			_backend.荣誉积分帧.connect(_refresh_current.unbind(1))
		# ⚠️ `anqi_state_received`（手里剑 1817 每一帧都会发）**不在这里接**：接上就是
		#    每帧一次 `_refresh_current()` 整页重建，把玩家正开着的「突破瓶颈」弹窗 free 掉
		#    （`手里剑页._exit_tree` 连搬到屏幕弹窗层的也一起收）⇒ 幸运值永远看不到涨。
		#    它的界面刷新走 `cultivation_changed` → `_on_cultivation_changed` 的**原地刷新**。
		for signal_name in ["gift_state_received", "czhuodong_state_received", "exchange_state_received", "achievement_state_received", "activity_state_received", "card_state_received", "chest_state_received", "buff_fusion_received", "heal_state_received", "jieyin_state_received"]:
			if _backend.has_signal(signal_name):
				_backend.connect(signal_name, _on_reward_state_received)
		# 福袋单独接：通用那条只做"刷当前页"，而这两支帧要的是一件具体的事 ——
		# `1289:1` 开/填 `SuccessWindow`、`1289:2` 起跑马灯（原版两条 listener 分工在
		# `Client.onShowFudaiInfo:6582` / `onShowFudaiGainItemInfo:4575`）。
		# ⚠️ 以前它挂在上面那条通用列表里 ⇒ 全工程**没有任何一处**开这扇窗，
		#    在线双击福袋只收到一句"等待服务器确认"（#74）。
		if _backend.has_signal("fudai_state_received"):
			_backend.fudai_state_received.connect(_收到福袋帧)
		# 排行榜单独接：除了刷新，还要在**本榜**回帧时把翻页页序打回第一页
		# （原版 `RankWindow2.setData:366` 里那句 `reset`）。走通用那条 `_on_reward_state_received`
		# 就只剩刷新，玩家翻到第 5 页后随便切个页签再切回来，页上还停在 5/1 的空页。
		if _backend.has_signal("ranking_state_received"):
			_backend.ranking_state_received.connect(_on_ranking_state)
		_on_backend_status(_backend.status, _backend.detail)
	if _activity != null:
		_activity.activity_changed.connect(_refresh_current.unbind(1))

## 最近收到的鼠标/按键事件（F9 诊断用，环形缓冲，最多 40 条）。
##
## 为什么记在 `_input` 里：Godot 的派发顺序是 **`_input`（按树逆序，先被后加的节点看到）
## → GUI 命中判定 → `_unhandled_input`**。所以"事件有没有进来、进来时是不是已经
## 被别人 `set_input_as_handled()` 了"，只有在这里看得到 —— 这正是
## "鼠标停在钮上、钮又在最上层，Godot 却报 `is_hovered()=false`、点击毫无反应" 的分岔点。
var _输入审计: Array[String] = []


func _input(event: InputEvent) -> void:
	# 兜底点击**必须排在最前**（要在 GUI 之前把事件吃掉，见 `_兜底旗帜钮` 上面那段）。
	if _兜底旗帜钮(event):
		return
	_收下拉于别处(event)
	# ⚠️ 闸门：**只有家族旗帜窗开着才记**。`_input` 每帧都会被鼠标移动触发，
	# 无条件地格式化字符串会给正常游戏白白加一份每帧开销。
	if not 家族子窗壳.已开(self, "家族旗帜窗"):
		return
	var 位置 := ""
	if event is InputEventMouseMotion:
		位置 = str((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		位置 = str((event as InputEventMouseButton).position)
	else:
		return
	var 类 := "移动" if event is InputEventMouseMotion else "按键"
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		类 = "抬起"
	_输入审计.append("%s 位置=%s 到达 _input 时已被处理=%s"
		% [类, 位置, str(get_viewport().is_input_handled())])
	if _输入审计.size() > 40:
		_输入审计.pop_front()


## 摊位列表的下拉菜单：**在菜单外面按下就收掉**。
## 真值 = `MComboBox.as:29-41` 的 `close()` 里那句
## `API.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onStageClick)` —— 反推 `open()` 挂的
## 正是"点舞台任意处 ⇒ 关"。不补这一条，菜单会一直赖在屏上盖着列表（本工程口径：这就是坏了）。
func _收下拉于别处(event: InputEvent) -> void:
	var 按 := event as InputEventMouseButton
	if 按 == null or not 按.pressed or 按.button_index != MOUSE_BUTTON_LEFT:
		return
	if _摊位列表下拉 != null and is_instance_valid(_摊位列表下拉):
		if not (_摊位列表下拉 as Control).get_global_rect().has_point(按.global_position):
			摊位列表窗.关下拉(self)
	## 二级密码三格那两枚 `MComboBox` 的菜单同一处理（`MComboBox.as:29-41` 的 `close()`）。
	if _二级密码下拉 != null and is_instance_valid(_二级密码下拉):
		if not (_二级密码下拉 as Control).get_global_rect().has_point(按.global_position):
			二级密码窗.关下拉(self)


## 家族旗帜窗「钮点不动」现场取证（F9 触发，见 `_unhandled_input`）。
##
## 只做一件事：把**真实光标**下面到底压着什么，以及三颗钮的状态，写进
## `user://旗帜钮诊断.txt`。用户悬停在点不动的钮上按 F9 即可 —— 这是唯一能拿到
## "真鼠标"数据的办法（模拟鼠标在这个工程里做不实，原因见 F9 那段注释）。
##
## ⚠️ 它**只读**：不改任何状态、不发任何协议。
func _写旗帜钮诊断() -> void:
	var 文件 := FileAccess.open("user://旗帜钮诊断.txt", FileAccess.WRITE)
	if 文件 == null:
		return
	var 行: Array[String] = []
	行.append("时间=%s" % Time.get_datetime_string_from_system())
	行.append("窗口=%s 视口=%s 内容缩放=%s 模式=%d 有焦点=%s 鼠标(视口)=%s 鼠标(屏幕)=%s"
		% [str(DisplayServer.window_get_size()), str(get_viewport().get_visible_rect().size),
			str(get_window().content_scale_size), get_window().content_scale_mode,
			str(DisplayServer.window_is_focused()), str(get_viewport().get_mouse_position()),
			str(DisplayServer.mouse_get_position())])
	var 点 := get_viewport().get_mouse_position()
	行.append("")
	行.append("Godot 自己认为光标悬停在：%s"
		% str(get_viewport().gui_get_hovered_control()))
	var 候: Array[Control] = []
	_收光标下的控件(get_tree().root, 点, 候)
	行.append("")
	行.append("光标 (%s) 下叠了 %d 层可接事件的 Control（**最后一行是最上层**）："
		% [str(点), 候.size()])
	for i in 候.size():
		行.append("  %2d) %s   filter=%d clip=%s"
			% [i + 1, _诊断路径(候[i]), 候[i].mouse_filter, str(候[i].clip_contents)])
	行.append("")
	行.append("家族旗帜窗的三颗钮：")
	var 窗 := 家族子窗壳.取内容(self, "家族旗帜窗")
	if 窗 == null:
		行.append("  （旗帜窗没开着）")
	else:
		for 名 in ["钮说明资讯", "钮安插本族旗帜", "钮修复族旗血量"]:
			var 钮 := 窗.get_node_or_null(名) as TextureButton
			if 钮 == null:
				行.append("  %s：**找不到**" % 名)
				continue
			行.append("  %s：矩形=%s disabled=%s 树里可见=%s 悬停=%s 在光标下=%s"
				% [名, str(钮.get_global_rect()), str(钮.disabled), str(钮.is_visible_in_tree()),
					str(钮.is_hovered()), str(钮.get_global_rect().has_point(点))])
		# 行控件会不会盖到按钮那条带子上（列表是裁剪窗，但它的矩形远大于可视区）
		var 列 := 窗.get_node_or_null("列表/内容列") as Control
		if 列 != null:
			行.append("  列表/内容列：矩形=%s（列表裁剪窗矩形=%s）"
				% [str(列.get_global_rect()),
					str((窗.get_node("列表") as Control).get_global_rect())])
	行.append("")
	_写族旗现场(行)
	行.append("")
	行.append("最近 %d 条鼠标事件（在 `_input` 里记的；**到达时已被处理=true = 被别人先吃掉了**）："
		% _输入审计.size())
	if _输入审计.is_empty():
		行.append("  （一条都没有 ⇒ 鼠标事件根本没走到这里）")
	for 条 in _输入审计:
		行.append("  " + 条)
	行.append("")
	行.append("三颗钮的**祖先链**（逐级看矩形/mouse_filter/可见 —— Godot 的命中判定里，"
		+ "任何一级 `mouse_filter=IGNORE` 都会让它**整棵子树点不到也悬停不到**）：")
	if 窗 != null:
		var 级 := 窗.get_node_or_null("钮说明资讯") as Control
		while 级 != null:
			行.append("  %s  矩形=%s filter=%d 树里可见=%s clip=%s"
				% [_诊断路径(级), str(级.get_global_rect()), 级.mouse_filter,
					str(级.is_visible_in_tree()), str(级.clip_contents)])
			级 = 级.get_parent_control()
	文件.store_string("\n".join(行) + "\n")
	文件.close()
	_session.notification_requested.emit("已写出 user://旗帜钮诊断.txt")

## 地图族旗现场：旗到底有没有被客户端建出来、建在哪、离玩家多远。
## 为什么要打"距离"：旗子的落点是服务端 `MAP_FLAG_LOCATIONS` 里那 13 个固定点之一
## （木叶村那面在 `(2372,1209)` 附近），而村子横向 4800+ 像素 ——
## **旗在、但你站的地方离它很远**，画面里当然看不到。这两件事必须分清。
func _写族旗现场(行: Array[String]) -> void:
	var 后端 := get_node_or_null("/root/BackendConnection")
	var 会话 := get_node_or_null("/root/GameSession")
	行.append("地图族旗现场：")
	if 后端 == null or 会话 == null:
		行.append("  （缺 BackendConnection / GameSession）")
		return
	# ⚠ 取法必须是 `str(...)`：全工程守卫禁无默认值的 `String(X.get("键"))`（见 §3.166 教训 6）。
	var 图 := str(会话.get("current_map_id"))
	行.append("  会话当前图 = %s（%s）" % [图, 会话.call("get_map_name")])
	行.append("  authoritative_map_flag = %s"
		% JSON.stringify(后端.get("authoritative_map_flag")))
	var 表: Array = 后端.get("authoritative_flag_list") as Array
	行.append("  族旗表 %d 行；本图那一行 = %s" % [表.size(), JSON.stringify(_本图那行(表, 图))])
	var 实体 := _找地图实体(get_tree().root)
	if 实体 == null:
		行.append("  **地图实体没找到**（那族旗根本没地方挂）")
		return
	行.append("  地图实体 = %s" % _诊断路径(实体))
	var 旗 := 实体.get_node_or_null("族旗") as Node2D
	if 旗 == null:
		行.append("  **地图实体下没有「族旗」节点** ⇒ 客户端确实没建（不是「建了但看不见」）")
		return
	var 玩家 := get_tree().get_first_node_in_group("player") as Node2D
	行.append("  族旗节点位置 = %s（可见=%s）" % [str(旗.global_position), str(旗.visible)])
	if 玩家 != null:
		var 距 := 玩家.global_position.distance_to(旗.global_position)
		行.append("  玩家位置 = %s ⇒ **离旗 %.0f 像素**（相机视野约 ±480，超过就看不见）"
			% [str(玩家.global_position), 距])


func _本图那行(表: Array, 图: String) -> Dictionary:
	for 行 in 表:
		var 记 := 行 as Dictionary
		if int(记.get("map_id", -1)) == int(图):
			return 记
	return {}


func _找地图实体(节点: Node) -> Node:
	if not is_instance_valid(节点):
		return null
	var 脚: Variant = 节点.get_script() if 节点.get_script() != null else null
	if 脚 != null and String((脚 as Script).resource_path).ends_with("地图实体.gd"):
		return 节点
	for 子 in 节点.get_children():
		var 果 := _找地图实体(子)
		if 果 != null:
			return 果
	return null


## 收集光标下的控件（按树的**前序**，所以越靠后越上层；不做裁剪判断，裁剪那条由人工比矩形）。
func _收光标下的控件(节点: Node, 点: Vector2, 出: Array[Control]) -> void:
	for 子 in 节点.get_children():
		if 子 is Control:
			var 控 := 子 as Control
			if 控.is_visible_in_tree() and 控.mouse_filter != Control.MOUSE_FILTER_IGNORE \
					and 控.get_global_rect().has_point(点):
				出.append(控)
		_收光标下的控件(子, 点, 出)


func _诊断路径(节点: Node) -> String:
	var 段: Array[String] = []
	var 当 := 节点
	while 当 != null:
		段.push_front(String(当.name))
		当 = 当.get_parent()
	return "/".join(段)


## 家族旗帜窗底部三颗钮的**兜底点击**。
##
## 为什么要这么绕（用户 2026-10-09 实机 F9 现场数据，句句是实测）：
##   * 光标 (945,673) **确实落在**「安插本族旗帜」的矩形里（910.5..988.5 × 666..688）；
##   * 命中层扫描里**钮就是最上层**，没有任何控件盖住它；
##   * 钮 `disabled=false`、`visible=true`、`pressed` 连接正常，`pressed.emit()` 三颗全生效；
##   * 但 **`钮.is_hovered()` 恒 false**，而 `Viewport.gui_get_hovered_control()` 报的是
##     **页面根 `家族旗帜窗`** —— 也就是说 **Godot 的 GUI 命中判定把这一点判给了页面，跳过了钮**；
##   * 同时 F9 的"事件到达审计"里，**按键/抬起到了 `_input` 且 `已被标记处理=false`**
##     ⇒ 事件本身是好的，坏的是"`_input` 之后、GUI 命中"那一段。
## 已排除的原因（都量过）：权限/置灰、钮宽装不下字、被别的控件盖住、接线断、
## `has_point` 贴图判定（`钮底.png` 尺寸 57×22 = 控件尺寸，不会拒绝矩形内的点）。
##
## 所以这里**在 `_input` 这一层自己做一次矩形命中**并直接补发 `pressed`，随后
## `set_input_as_handled()` 把事件吃掉 —— 这样即使 GUI 那条路仍然把事件判给页面，
## 也不会出现"补发一次 + GUI 又发一次"的双触发。
##
## ⚠️ 只在**这扇窗是当前最上层**时兜底：`家族确认弹` / `家族旗帜帮助窗` 开着时，
##     落在同一坐标的点击应该归它们，这里必须让路。
##
## 回滚办法：删掉本函数，以及 `_input` 里的第一段调用 —— 若将来 Godot 侧或别处修好了
## GUI 命中，这段兜底就是多余的（但**无害**：它抢先消费，行为与正常点击一致）。
func _兜底旗帜钮(事件: InputEvent) -> bool:
	if not (事件 is InputEventMouseButton):
		return false
	var 鼠 := 事件 as InputEventMouseButton
	# ⚠️ `InputEventMouseButton` **没有 `echo`**（`echo` 是 `InputEventKey` 的）——
	#    这里原来写成 `鼠.echo`，实机一按就抛 "Invalid access to property 'echo'"，
	#    兜底整个失效（`功能窗口._兜底旗帜钮` 是 `_input` 里第一段，抛了连事件审计都不跑）。
	if 鼠.button_index != MOUSE_BUTTON_LEFT or not 鼠.pressed:
		return false
	for 别的 in ["家族确认弹", "家族旗帜帮助窗"]:
		if 家族子窗壳.已开(self, 别的):
			return false
	var 页 := 家族子窗壳.取内容(self, "家族旗帜窗")
	if 页 == null:
		return false
	for 名 in ["钮说明资讯", "钮安插本族旗帜", "钮修复族旗血量"]:
		var 钮 := 页.get_node_or_null(名) as TextureButton
		if 钮 == null or 钮.disabled or not 钮.is_visible_in_tree():
			continue
		if 钮.get_global_rect().has_point(鼠.position):
			钮.pressed.emit()
			get_viewport().set_input_as_handled()
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if not _shortcut_waiting_action.is_empty():
			_set_shortcut_key(_shortcut_waiting_action, event as InputEventKey)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and _overlay.visible:
			# 确认框是树内 Control 而非 Window，不会自己吃掉 ESC，
			# 所以这里先关它、不连带关掉后面的主窗口。
			var 确认框 := _overlay.get_node_or_null("确认框")
			if 确认框 != null:
				确认框.queue_free()
				get_viewport().set_input_as_handled()
				return
			close()
		# F9：家族旗帜窗「钮点不动」现场取证。
		# 为什么要这么绕：模拟鼠标在这个工程里**做不实** ——
		#   * `--script` 模式**没有真窗口**（`DisplayServer.window_get_size()=(0,0)`、视口被压成
		#     64×64），`Input.parse_input_event` 的坐标还会被整体平移（实测想点 (202,354)、
		#     控件收到 (194,316)）⇒ 结论全是假的；
		#   * 真窗口下又拿不到焦点，`is_hovered()` 恒 false、事件根本进不了 GUI。
		# 所以让**玩家用真鼠标悬停 + 按 F9** 最省事：把"光标下到底是谁"写进
		# `user://旗帜钮诊断.txt`（=`%APPDATA%/Godot/app_userdata/火影世界/`）。
		if event.keycode == KEY_F9:
			_写旗帜钮诊断()
			get_viewport().set_input_as_handled()
			return

## 多窗口模式：把本实例**固定**到某一页，并接受一个位置偏移。
## 背景：原版每个面板是独立 `UIWindow`，可以同时开着（也才可能"背包→人物面板"拖装备）；
## 我们原来只有一个 `功能窗口` 实例、`open_page` 是**换页**，所以永远只能开一个。
## 现在由 `窗口管理.gd` 为每个页面建一个实例，各自固定一页、各自带偏移。
var _固定页 := ""
var _位置偏移 := Vector2.ZERO


func 设为单页(页名: String, 偏移: Vector2) -> void:
	_固定页 = 页名
	_位置偏移 = 偏移


## 本实例是不是"每页一扇窗"里的一扇。
## 判据是父节点的**能力**（`窗口管理` 有 `打开或收起`），与 `_ready` / `设为单页`
## 的先后无关 —— 父节点在 `_ready` 时已经在树上，而 `_固定页` 那时还是空串。
func _由窗口管理接管() -> bool:
	var 父 := get_parent()
	return 父 != null and 父.has_method("打开或收起")


## 窗口主体在屏幕上的矩形。`窗口管理` 用它做"点击置顶"的命中判定。
func 窗口矩形() -> Rect2:
	var 主窗 := get_node_or_null("遮罩/主窗口") as Control
	return 主窗.get_global_rect() if 主窗 != null else Rect2()


## 台面上这一点现在有没有**模态弹层**罩着。`窗口管理` 的"点击置顶"要先问它一句。
##
## 工程里每一枚模态弹（`输入确认弹` 的输入/消息/勾选三型、老的 `_弹出确认` `_弹出输入`）
## 都是同一形状：`PRESET_FULL_RECT` + `mouse_filter = STOP` + `z_index = 100`。
## ⇒ 认**形状**不认节点名：同名叠两层时 Godot 会把后一个改名 `@Control@N`，名字靠不住。
func 模态弹罩住(点: Vector2) -> bool:
	if _overlay == null:
		return false
	for 子 in _overlay.get_children():
		var 层 := 子 as Control
		if 层 == null or 层.is_queued_for_deletion() or not 层.visible:
			continue
		if 层.z_index < 100 or 层.mouse_filter != Control.MOUSE_FILTER_STOP:
			continue
		if 层.get_global_rect().has_point(点):
			return true
	return false


## **跨窗口导航**：本页上的按钮要打开**另一页**时走这里。
## 固定页的实例自己不能换页（`open_page` 会被守卫挡掉），所以转交给窗口管理 ——
## 由它去建/开目标页那扇窗。原版就是这么弹新窗的。
## （`_固定页` 为空的是老的"单窗口换页"用法，回落到 `open_page`。）
func 导航到(页名: String) -> void:
	var 管理: Node = get_parent()
	if not _固定页.is_empty() and 管理 != null and 管理.has_method("打开"):
		管理.call("打开", 页名)
		return
	open_page(页名)


## 窗口管理调这个来开窗（不用 `open_page`，那个还会处理切页副作用）。
func 打开() -> void:
	if _固定页.is_empty():
		return
	_overlay.visible = true
	open_page(_固定页)
	# 居中之后再错开，免得多个窗口叠在正中央看不出是几个
	if _位置偏移 != Vector2.ZERO:
		窗口偏移(_位置偏移)




## 把窗口摆到「居中位置 + 偏移」处，**并钳进视口** ——
## 不钳的话多窗口错开会把窗口推出屏幕右边（第一版就推出去了）。
##
## ⚠️ 2026-09-24 改成**绝对定位**（原来是 `offset_left += 偏移.x`）。原因：
## `打开()` 每次开窗都会调这里，而关窗时 `窗口管理` 用 `取位置偏移()` 记下的
## **正是当前这个偏移** —— 于是"开了关、关了开"每循环一次就**再漂一个偏移量**
## （实测背包连开两次会偏出 (120,78)，越用越偏）。
## 改成从"居中"算绝对位置后天然幂等：开多少次、记不记得住，结果都一样。
## 位置在 Godot 里是相对视口中心的，所以居中态就是 ±size/2。
func 窗口偏移(偏移: Vector2, 钳进视口 := true) -> void:
	var 主窗 := get_node_or_null("遮罩/主窗口") as Control
	if 主窗 == null:
		return
	# ⚠️⚠️ 尺寸必须**先取出来存进局部变量**。下面每赋一个 offset，`主窗.size` 立刻跟着变，
	#   要是像原来那样在第二个赋值里再读一次 `主窗.size`，拿到的是**已经被改过的**尺寸，
	#   窗口就越算越小。
	#   实测（2026-09-24）：背包 275x394 被算成 **215x355**、忍术 462x466 被算成 **342x388**
	#   —— 275→(改完 left)155→215、394→(改完 top)316→355，逐位吻合。
	#   症状就是用户报的"背包底板背景对不上格子UI"：`窗口边框`（底板）跟着 `主窗口` 缩了
	#   60px，而 `页面容器`（格子）仍是正确尺寸，两者对不齐。
	#   只有"第一个打开的窗"看着是对的 —— 它的错开量是 0，压根不进这段代码。
	var 尺寸 := 主窗.size
	# 钳制的是「**窗口中心**距视口中心的偏移」，范围 ±(视口-窗口)/2。
	#
	# ⚠️ 不能拿 `offset_left` 直接去钳：那是**左沿**相对锚点（=视口中心）的坐标，
	#    居中的窗口它本来就是 `-尺寸/2`，直接跟 ±(视口-窗口)/2 比，会把「居中」都判成
	#    越界、把窗口往右下推半个身位 —— 实测人物本该落在 x=221.5，被推到了 258.5，
	#    而且连带把拖动余量吃掉（背包只能上下动 ±83，可它连居中位都保不住）。
	var 视口 := get_viewport().get_visible_rect().size
	if 钳进视口:
		# 成对摆位那条路要**不钳进视口**（原版那对会让背包垂出下沿），所以给开关。
		var 横限 := maxf(0.0, (视口.x - 尺寸.x) * 0.5)
		var 纵限 := maxf(0.0, (视口.y - 尺寸.y) * 0.5)
		偏移 = Vector2(clampf(偏移.x, -横限, 横限), clampf(偏移.y, -纵限, 纵限))
	主窗.offset_left = -尺寸.x * 0.5 + 偏移.x
	主窗.offset_right = 尺寸.x * 0.5 + 偏移.x
	主窗.offset_top = -尺寸.y * 0.5 + 偏移.y
	主窗.offset_bottom = 尺寸.y * 0.5 + 偏移.y
	# 记住的是**钳过之后**的实际偏移，`打开()` 回填时才能原样复现。
	# 实例也存一份，免得 `打开()` 还用创建那一刻的陈旧偏移。
	_位置偏移 = 偏移


## 当前相对"居中位置"的偏移（窗口管理用来记住位置）。
##
## 窗口的位置是相对**父节点（遮罩）中心**的，而遮罩铺满视口 → 父中心就是视口中心，
## 所以"距居中的偏移"就是 `offset_left + size.x/2`。
##
## ⚠️ 原来这里还多减了一个 `视口/2`，于是居中时返回的是 (-480,-280) 而不是 (0,0) ——
##    `打开或收起` 把它记进 `_记住的位置`、`打开()` 再喂回 `窗口偏移`，整个偏掉一大截。
##    两个函数本该互为逆运算，这条契约现在由 `测试/窗口行为契约体检.gd` 的 B 组钉住。
func 取位置偏移() -> Vector2:
	var 主窗 := get_node_or_null("遮罩/主窗口") as Control
	if 主窗 == null:
		return Vector2.ZERO
	return Vector2(主窗.offset_left + 主窗.size.x * 0.5, 主窗.offset_top + 主窗.size.y * 0.5)


## 本实例是不是**最上层**那扇由窗口管理接管的窗。
## 全局弹窗（1079 ⇒ 商城购买窗）只该它一家响应 —— 否则每扇窗各弹一枚、各铺一层遮罩。
## 老的"单窗口换页"用法没有窗口管理 ⇒ 台上只有它自己一枚，照旧放行。
func _是最上层窗口() -> bool:
	var 父 := get_parent()
	if 父 == null or not 父.has_method("取最上层窗口"):
		return true
	return 父.call("取最上层窗口") == self


func 已打开() -> bool:
	return _overlay != null and _overlay.visible


func open_page(page_name: String) -> void:
	# ⚠️ **多窗口的命门**：每个实例的 `_ready` 都把 `feature_requested` 连到了自己的
	# `open_page`，所以底栏点一次按钮，**所有已建实例都会收到**并各自换页换标题 ——
	# 表现是"三个窗口标题全变成最后一个点的那个"。
	# 因此固定到某一页的实例只认自己那一页，其余一概不理。
	# （`_固定页` 为空的是老的"单窗口换页"用法，保持原样。）
	if not _固定页.is_empty() and page_name != _固定页:
		return
	if _current_page == "NPC仓库" and page_name != "NPC仓库" and _backend != null and bool(_backend.in_game):
		_backend.request_storage_close()
	if page_name == "人物" and _current_page != "人物":
		_character_pending_ap = {"ap_atk": 0, "ap_def": 0, "ap_dex": 0, "ap_phy": 0}
		# ⚠️ 这里**原来还有一发 `_backend.request_jieyin_state()`（发 2318:2）—— 已删，别再写回来**：
		#   结印**没有"请求状态"这个动作**（上行只有 byte 0/1，`JieYinProcessor.as:78-111`），
		#   夹具 `handle_jie_yin` 的白名单也是 `(0,1)` ⇒ 那一发永远无回帧，纯空枪。
		#   阶段/熟练度的来源是登录时服务端**主动推**的 2318:0（`_send_jie_yin_state`）。
		if _backend != null and bool(_backend.in_game):
			_backend.request_anqi_state()
	_current_page = page_name
	## 挂机页要的配置查询**不在这里发**：整扇页已经切给 `脚本/界面/窗口/挂机窗口.gd`，
	## 它自己的 `渲染()` 末尾发 `1283:0`（原版本来就没有"开窗拉配置"这一步，是
	## `CharacterConfig` 在进图时同步过的；我们没那一步，所以由页面补一发）。
	## 这里以前发的是 `request_hang_state()` = `1808:2` —— 原版只有 0/1 两档、
	## 服务端 `handle_hang_action:18329` 也只认 0/1 ⇒ 那条查询**永远不会有回帧**。
	# 摊位列表：原版 `init()` = `loadPage(0)` ⇒ **开窗那一刻**发 `1296:0:0:11`，
	# 回帧只灌表（`窗口管理._on_stall_list`）。⚠ 回帧那一路**不许**再走 `open_page`，
	# 否则 发→灌→开窗→再发 成环（工程既有口径）。
	# 离线时只清状态、不发包：点开的窗画「总数：0」+ 四枚翻页钮灰着，与原版空表一致。
	if page_name == "摊位列表":
		摊位列表窗.复位(self)
		if _backend != null and bool(_backend.in_game):
			摊位列表窗.请求页(self, 0)
	if page_name == "商城" and _session != null:
		# 每次开窗都从第 1 页开始（原版 `init()` 里 `setSelectedTabBtn(tabs[param1])` → `requestData(0,19)`）
		_shop_page = 1
		_session.request_cash_shop(_shop_tab, _shop_query, true)
	if page_name == "家族" and _backend != null and bool(_backend.in_game):
		_backend.request_guild_summary()
	if page_name == "好友" and _backend != null and bool(_backend.in_game):
		_backend.request_friend_list()
	if page_name == "组队" and _backend != null and bool(_backend.in_game):
		_backend.request_party_state()
		_backend.request_nearby_parties()
	if page_name == "排行榜":
		# 原版每次开这扇都是**重新 build** 的（关窗 `onCloseBtnClick:79-84` 先 `destroy()`，
		# 再进时 `createRankMenu:328-337` 默认选中第 0 条）⇒ 重开必回「等级排行榜 / 忍界榜 / 第 1 页」，
		# **不记**上次看的是哪条。（原版另有一条 `JueDouManager.rankIndex > 0` 的入口——从决斗窗
		# 跳来看某一条榜——本工程决斗窗那条没接，所以这里恒走默认那一条。）
		_ranking_tab = 0
		_排行页 = 0
		_排行码 = 0
		_请求排行榜()
	if page_name in ["兑换", "兑换商店"] and _backend != null and bool(_backend.in_game):
		# ⚠ 伊鲁卡那扇「兑换商店」与 `系统窗口` 的「兑换」页读的是**同一张表** ⇒ 开页也要拉。
		# 服务端回的是**原始二进制帧**（`_send_exchange_recipe_list` → `send_original_packet`），
		# 不是 AMF3 文本 ⇒ 入口在 `后端连接._handle_original_frame`。
		_backend.request_exchange_list()
	if page_name in ["签到", "福利"] and _backend != null and bool(_backend.in_game):
		# 六子页的数据来自两条独立的线：礼包 `1344`（签到/线上有礼/周登录…）
		# 与充值活动 `1814`（首充/限时大奖/新服有礼）。两条都要拉。
		_backend.request_gift_state()
		_backend.request_czhuodong_bootstrap()
		_backend.request_activity_state()
	if page_name == "活动" and _backend != null and bool(_backend.in_game):
		_backend.request_activity_state()
	# 活跃度页读的就是 `authoritative_activity`（15 项次数 + claimed_level + points），
	# 与「活动/福利」同一份 —— 服务端 `2326` 帧。
	if page_name == "活跃度" and _backend != null and bool(_backend.in_game):
		_backend.request_activity_state()
	# 背包/仓库的页码只在**开窗**时复位（原版也是开一次从第一页起）；
	# 重建（装备/移动/整理触发的刷新）要保住玩家翻到的那一页。
	if page_name == "背包":
		_背包页 = 0
	if page_name == "NPC仓库":
		_仓库页 = 0
	# 任务页的两份列表（已接/可接）走 `443` 请求、`444` 回包。在线时本地那两份是离线的
	# 假任务，**必须**由服务端覆盖，否则窗口里显示的是"任务不存在于服务端"的内容。
	if page_name == "任务" and _backend != null and bool(_backend.in_game):
		_backend.request_quest_list()
	if page_name == "信息" and _backend != null and bool(_backend.in_game):
		_backend.request_achievements(1)
	# 跨服频道：原版 `KuaFuChannelWindow.initWindow:211` 直接拿 `KuaFuManager.serverList` 填，
	# 那份列表来自 `requestWarPanel_warServerList`（`WarPanelProcessor.as:122-127`）—— 原版是
	# 「点菜单先发 0、收到回帧才开窗」（`KuaFuManager.onWarPanel_warServerInfo:516-527`）。
	# 这边开窗是本地直开 ⇒ 改成**开窗即拉**，回帧只原地塞数不拆页（见 跨服频道窗.gd:_接回帧）。
	if page_name == "跨服频道" and _backend != null and bool(_backend.in_game):
		_backend.request_war_panel_list()
	if page_name == "签到":
		_prize_tab = 0
	elif page_name == "福利":
		_prize_tab = 3
	if page_name == "忍者传承" and _传承窗口 != null:
		_传承窗口.请求当前页()
	# 标题由 _apply_original_window 从窗口尺寸表读取并居中。
	_apply_original_window(page_name)
	_overlay.visible = true
	# 「这一次渲染是**开窗**，不是回帧引起的重建」—— 给页面一个可靠的区分手段：
	# 原版每扇窗的"开窗"动作各自发一条查询（心法 = `UI.as:649-652 requestXinfaShow()`），
	# 而回帧引起的重渲染**不该再发**（否则 发→回帧→重建→再发 成环）。
	# 光靠"数据到没到过"判不行：那样第二次开窗就不查了，切完心法重开还是旧值
	#（用户 2026-10-14 报的"有时候切换了没反应"）。
	_刚开窗 = true
	_render_page(_刚开窗)	# 开窗/换底栏页 = 数值条直落（用户：切换后是多少就是多少）
	_刚开窗 = false		# 只喂上面那一轮：之后任何原因的 `_render_page()` 都算"回帧引起的重建"

func close() -> void:
	_停日环自动()
	_停打造自动()
	_清洗属性快照()
	if _current_page == "NPC仓库" and _backend != null and bool(_backend.in_game):
		_backend.request_storage_close()
	if _current_page == "人物":
		_character_pending_ap = {"ap_atk": 0, "ap_def": 0, "ap_dex": 0, "ap_phy": 0}
		# 原版关掉 `CharWindow2` 会连带把提升弹窗 `destroy()`，而它干的就是 `clearTimeOut()`
		# （`JieYinTiShengWindow.as:54-57`）⇒ **关窗 = 自动提升停**；弹窗开合也归零，
		# 下次进来是原版那个「收起着」的初始态。
		停结印自动()
		_结印弹窗开着 = false
		# 另三族同一处理：原版 `RouQuanTiShengWindow.destroy:261-265` / `LunHuiYanTiShengWindow:280-284`
		# 都只做 `clearTimeOut()`，写轮眼那族的关窗钮更是直接 `_isZidong = false`
		# （`TishengTongshuPanel.onCloseBtnClick:81-88`）⇒ **关人物窗 = 自动提升全停**。
		for 族 in 人物窗口.自动提升族:
			停族自动(族)
			_族弹窗开着[族] = false
	if _固定页 == "神秘商店":
		# 原版关窗 = `MysteryWindow.destroy()`（第一句 `_timeLabel.stop()`，实例一起销毁）⇒
		# 倒计时**不跨开关活着**：下次开窗重新从「刷新倒计时：00:00:00」走一遍。
		神秘商店窗.复位(self)
	if _固定页 == "梦幻属性符":
		# 原版关窗 `onremoveFromStage → backItemToEquip`：台子清空。材料格保留到下次开窗再填
		# （`showPropPanle` 每次都会重写它），不影响。
		_梦幻_清装备()
	if _固定页 == "橙装打造":
		# 原版关窗同样 `onremoveFromStage → backItemToEquip`（`YellowEquipLianZhiWindow.as:212-217`）。
		_橙装_清装备()
	if _固定页 == "摊位列表":
		# 原版关窗 = `UIManager` 把 `stallListWindow` 销毁 ⇒ 下次 `init()` 从第 0 页重新拉、
		# 关键字框是空的、类目回到「按物品名称」。本工程的窗**只藏不删** ⇒ 这三样在这里清掉，
		# 否则关一次再开：画的是上一页、框里还留着上次的词（`摊位列表窗.复位`）。
		摊位列表窗.复位(self)
	if _固定页 == "随身摊位":
		# 摊主侧的「上架中」是一个**脚本级**开关（对应原版 `StallWindow._isUpShelf` +
		# `MouseManager` 的拖拽光标）：原版关窗把整个 `StallWindow` 销毁 ⇒ 开关与光标一起没。
		# 本工程窗只藏不删 ⇒ 在这里显式收掉，否则关一次再开，背包点格子还会走「上架」分支。
		# 两扇伴随窗（选宠 / 货币上架）也一并收（原版它们挂在 `StallWindow` 里一起销毁）。
		摊位窗.关窗清态(self)
	if _固定页 == "交易":
		# 交易档的选宠窗跟着交易窗走（原版 `TradeWindow2` 关窗时 `suiShenPet` 一起拆）。
		# ⚠ 只收**交易档**那一扇：玩家可能同时开着随身摊位，它的选宠窗还该留着。
		var 伴管理: Node = get_parent()
		if 伴管理 != null and 伴管理.has_method("取窗口"):
			var 伴 = 伴管理.call("取窗口", "附身宠物")
			if 伴 != null and bool(伴.call("已打开")) and str(伴.get("_附身用途")) == "交易":
				伴.call("close")
	if _固定页 == "二级密码问题":
		# 三格那两枚 `MComboBox` 的菜单挂在 `宿主._overlay` 上（页重建会被连手清掉，故挂外面）
		# ⇒ 关窗时必须自己收掉，否则菜单会盖着整屏（`MComboBox.as:29-41` 的 `close()`）。
		二级密码窗.关下拉(self)
	if _固定页 == "宠物":
		# 原版 `PetWindow.destroy:204-211` 里「通灵驯养」是主窗的孩子 ⇒ 关主窗一起拆。
		_随页宠物id = ""
		_关宠物驯养窗()
	if _固定页 == "通灵驯养":
		# 原版预览是**融魂页的孩子**（`PetRongHunTab.showYuLanWindow:570` `addChild`）⇒
		# 驯养窗一关，`PetRongHunTab.destroy()` 就把预览一起 `removeChild` 掉。
		_关尾兽预览()

	# 提示行跟着窗收掉（用户报修 9 那半句"除非关闭面板"）。原版那枚飘字挂在**全局**容器
	# （`MessageTipPane.container`）⇒ 关窗不影响它；而这行字钉在**这扇窗**的标题行里、
	# 本工程窗只藏不删 ⇒ 不清的话下次开窗会把上次那句重新显形。
	# 代号 +1 顺带作废还在飞的那发 5 秒自收（`_收起提示` 只认当初那一发）。
	_提示代号 += 1
	if _status != null:
		_status.text = ""
		_status.visible = false
	_收回购买窗()		# 抬到「购买窗舞台层」的那枚不跟着 `遮罩` 一起藏
	_overlay.visible = false
	# ⚠️ **必须在 `_overlay.visible = false` 之后**：`已打开()` 读的就是 `_overlay.visible`，
	#   而 `_摆宠物双窗` 是靠"预览那扇还开着没开着"决定整条居中还是贴右墙的。放在上面那批
	#   `_固定页` 钩子里时，本扇自己还报"开着" ⇒ 玩家点 X 关掉预览，主窗+驯养窗仍留在贴右墙
	#   的位置（主窗左半截白缺一块，2026-10-25 写 ⑬ 门时才发现）。
	if _固定页 == "尾兽预览":
		# 玩家自己点 X 关掉 ⇒ 整条少一扇 ⇒ 主窗+驯养窗回到常规居中（不留在贴右墙位）。
		_重摆宠物双窗()
	# B2 那一对（`成对伴随`）：关一扇另一扇跟着关。这里是全工程**唯一**的关窗出口
	# （`关闭按钮.pressed` 也连到这里），所以闸放在这一句后面就够用。
	# 递归是自止的：本扇已经 `visible = false` ⇒ `已打开()` 返回 false，伙伴那边再兜回来也开不了。
	var 管理: Node = get_parent()
	if 管理 != null and 管理.has_method("连带关闭"):
		管理.call("连带关闭", _current_page)

## 页面渲染后可以再改标题（并重新居中）。用于标题要带数据的窗口——
## 例如原版的背包标题是「背包(20/30)」，容量直接写在标题里。
## `字号` > 0 时只给**这一扇窗**的标题加字号 override（2026-10-25 用户要求背包格子数略大），
## 传 0 = 回主题的 12。换页时 `_apply_original_window` 会清掉 override，别让背包的字号漏到别的页。
##
## `尾文本`/`尾字号`：跟在标题后面、但**不走标题加粗变体**的一截（背包的「(已用/总)」）。
## 拆成两枚 Label 是因为 ASCII 过 `FontVariation` 合成加粗会发灰（见 `_title_数值` 注释）；
## 主标题「背包」仍保持原来的标题变体 14 号（用户：「背包字体没问题」）。
func 设置标题(文本: String, 字号 := 0, 尾文本 := "", 尾字号 := 0) -> void:
	_title.text = 文本
	if 字号 > 0:
		_title.add_theme_font_size_override("font_size", 字号)
	else:
		_title.remove_theme_font_size_override("font_size")
	if _title_数值 != null:
		_title_数值.text = 尾文本
		_title_数值.visible = not 尾文本.is_empty()
		if 尾字号 > 0:
			_title_数值.add_theme_font_size_override("font_size", 尾字号)
		else:
			_title_数值.remove_theme_font_size_override("font_size")
	_layout_title(_window.size.x)

## 原版把窗口摆到舞台正中用的是**整型**落点：`PopUpMananger.as:141-142` 与
## `MWindow.as:366` 都写 `Math.round(Config.STAGE_WIDTH - width >> 1)`（`-` 比 `>>` 先算，
## 移位自己就把结果截成整数）⇒ 原版的窗口**永远踩在整像素上**。
## 旧写法 `offset_left = -宽 * 0.5` 在奇数宽上把整扇窗压在 .5（`数据/界面/窗口尺寸.json`
## 74 条可解析里 43 条是奇数宽或高；背包 275 ⇒ 342.5、人物 517 ⇒ 221.5），
## 宋体 12px 的内嵌点阵跟着整块重采样 ⇒ 标题白字发虚（用户报修 1.1）。
## 锚点仍留 0.5（视口改大小要跟着走），偏移按「整落点 − 父的一半」反算 ⇒ position 落回整数。
static func _居中偏移(父: float, 子: float) -> float:
	return floorf((父 - 子) * 0.5) - 父 * 0.5

func _摆窗口居中() -> void:
	if _window == null or not (_window.get_parent() is Control):
		return
	var 父 := (_window.get_parent() as Control).size
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.offset_left = _居中偏移(父.x, _外框尺.x)
	_window.offset_right = _window.offset_left + _外框尺.x
	_window.offset_top = _居中偏移(父.y, _外框尺.y)
	_window.offset_bottom = _window.offset_top + _外框尺.y

func _apply_original_window(page_name: String) -> void:
	var 规格: Dictionary = _取窗口尺寸表().get(page_name, {})
	if 规格.is_empty():
		push_warning("窗口尺寸表无此页面，回落到人物窗口尺寸：%s" % page_name)
		规格 = {"宽": 517, "高": 440, "内容底": false, "小背景": false, "标题": page_name}
	var 宽 := float(规格.get("宽", 517))
	var 高 := float(规格.get("高", 440))

	_title.text = String(规格.get("标题", page_name))
	# 同一实例会换页（背包→仓库…）：标题 override 是挂在共用 Label 上的，
	# 不清掉就会把背包那条 14 号带到下一扇窗。默认回到主题的 12。
	_title.remove_theme_font_size_override("font_size")
	# 尾巴同理：换到没有数字的页必须整截收掉（文本、字号 override、可见性一起清）。
	if _title_数值 != null:
		_title_数值.text = ""
		_title_数值.visible = false
		_title_数值.remove_theme_font_size_override("font_size")

	# 外框：视口居中，尺寸即 AS3 的 super(w, h)。绝对定位，不再经过容器最小尺寸链。
	_外框尺 = Vector2(宽, 高)
	_摆窗口居中()

	# 底图：有专属底图的页面用它，否则用通用九宫格边框。
	var 底图路径 := String(规格.get("底图", ""))
	if 底图路径.is_empty():
		var 边框变体: StringName = (
			WINDOW_SKIN.皮肤表.变体_小窗口边框 if bool(规格.get("小背景", false))
			else WINDOW_SKIN.皮肤表.变体_窗口边框
		)
		_frame.theme_type_variation = 边框变体
		_frame.remove_theme_stylebox_override("panel")
	else:
		# 专属底图是整幅美术，按窗口尺寸拉伸，不参与九宫格。
		_frame.theme_type_variation = &""
		_frame.add_theme_stylebox_override("panel", _texture_style(底图路径))

	# 内容底：UIWindow.as:37-38 固定 (8, 38)，尺寸 (宽-16, 高-68)。
	var 需要内容底 := bool(规格.get("内容底", false))
	_content_bg.visible = 需要内容底
	if 需要内容底:
		# ⚠ 这一段原来只摆 position/size、从不设样式，而场景里那个 Panel 也不带样式
		# ⇒ 运行期拿到主题基础 Panel（子面板.png），不是 `UIWindow.as:36` 的 MYellow。
		_content_bg.add_theme_stylebox_override("panel", WINDOW_SKIN.content_panel())
		# 内容底顶：`UIWindow.as:37-38` 默认 y=38，个别页 `setContentBgPos` 改成 30。
		var 底顶 := float(规格.get("内容底顶", 内容底偏移.y))
		_content_bg.position = Vector2(内容底偏移.x, 底顶)
		_content_bg.size = Vector2(宽 - 内容底偏移.x * 2.0, 高 - 内容底高度缩减)

	# 页面容器原点。多数页的 .tscn 以内容区左上角为 (0,0) 画，容器若铺满外框，
	# 整页会上移到标题栏底下（分页按钮和标题、关闭按钮挤在同一行），底部空出
	# 30~130px 边框带。故默认按 UIWindow.as:37-38 的内容区原点 (8, 38) 摆放。
	# 少数页（首领、地图信息等）当初是照外框坐标画的，根节点宽度就等于外框宽、
	# 内部子节点自带 6~10px 边距，再加 (8, 38) 会顶出右下边框；这些页用"整框"
	# 标记走原点 (0,0)。判定写在尺寸表里，不靠这里猜。
	# 整框页的根节点宽度正好等于外框宽、高度正好等于 外框高 - 拖动区高（29），
	# 即它们是"横向铺满外框、纵向从标题栏下沿起算"画的，边距已画进子节点里。
	var 整框 := bool(规格.get("整框", false))
	# 少数页是**整个窗口**的 1:1 移植：AS3 里那些坐标就是窗口局部（含外框那圈，
	# 例如背包的 cellBackground 在 (6,39)、页签在 y=45），不是"内容区局部"。
	# 这类页用 `原点` 显式给容器原点（一般是 [0,0]），容器铺满整个外框。
	# 判定写在尺寸表里，不靠这里猜。
	if 规格.has("原点"):
		var 原点 := Vector2(float(规格["原点"][0]), float(规格["原点"][1]))
		_content.position = 原点
		_content.size = Vector2(宽, 高) - 原点
	else:
		_content.position = Vector2(0.0, 拖动区高) if 整框 else 内容底偏移
		_content.size = (
			Vector2(宽, 高 - 拖动区高) if 整框
			else Vector2(宽 - 内容底偏移.x * 2.0, 高 - 内容底高度缩减)
		)

	# 标题：MWindow.as:190 titleTextField.x = bgW - textW >> 1，即整数居中。
	_title.position.y = 标题文字Y
	_layout_title(宽)

	# 关闭按钮：`MWindow.drawWindowLayout():210-217` ⇒
	#   `x = round(bgW − closeBtn.width − 6)`、`y = _titleTextFieldY + 1`，
	#   而 `_titleTextFieldY` = **5**（普通背景）/ **3**（`_isSmallBackground`，`:167-174`）。
	#   元件 7 `MWindowCloseBtnF` 的边界现查 = (0,0)-(25,24) ⇒ **符号本身没有透明留白**，
	#   我们的 `关闭按钮.png` 也正是 25×24 满墨 ⇒ 那个 6 直接照抄。
	#   ⚠ 旧代码写的是 −13（注释里说在补 SWF 元件的留白，而留白根本不存在）
	#   ⇒ 全工程每一扇窗的 X 都往左偏了 7 像素（2026-10-14 用户实机图打回）。
	var 标题基准 := 3.0 if bool(规格.get("小背景", false)) else 标题Y
	var 关闭尺寸 := _close_button.size
	_close_button.position = Vector2(round(宽 - 关闭尺寸.x - 6.0), 标题基准 + 1.0)

	# 拖动区：MWindow.as:229 顶部 29px 全宽。
	_drag_area.position = Vector2.ZERO
	_drag_area.size = Vector2(宽, 拖动区高)

func _layout_title(窗口宽: float) -> void:
	# Label 的 size 在本帧尚未由文本更新，取字体实测宽度而非 size.x。
	var 字体 := _title.get_theme_font("font")
	var 字号 := _title.get_theme_font_size("font_size")
	# 宽度先取整再相加：尾巴的 x = 主标题 x + 主标题宽，只要有 .5 就会把整截 ASCII
	# 压到半像素上（亚像素关闭也一样会重采样发虚）。
	var 主宽 := roundf(float(字体.get_string_size(
			_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 字号).x))
	var 尾宽 := 0.0
	var 有尾 := _title_数值 != null and _title_数值.visible and not _title_数值.text.is_empty()
	if 有尾:
		var 尾字 := _title_数值.get_theme_font("font")
		var 尾号 := _title_数值.get_theme_font_size("font_size")
		尾宽 = roundf(float(尾字.get_string_size(
				_title_数值.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 尾号).x))
	var 左 := float(int(窗口宽 - 主宽 - 尾宽) >> 1)
	_title.size.x = 主宽
	_title.position.x = 左
	# 2026-10-25 用户：「最好也是那个框内的中间位置」——带尾巴的背包标题整条放在
	# **29px 标题栏的垂直正中**（原落点 2 偏高 4px，是 AS3 标题的原始位置）。
	# 只对背包这类有尾巴的标题生效：其他窗口保持 `_标题初始Y`，别让这条观感偏离扩散到全工程。
	_title.position.y = (roundf((拖动区高 - _title.size.y) * 0.5) if 有尾 else _标题初始Y)
	if _title_数值 != null:
		# 两枚 Label 按整条标题的实测总宽一起居中（原版是**一个** TextField，
		# 拆开后不能各居各的，否则「背包」和括号会分家）。
		# 尾巴字号比标题大时，Label 的**最小高度**会被字体撑高（20 号 ⇒ 21px > 标题 17px）；
		# 不跟着把 y 上移的话文字会往下沉，和标题的垂直中心错开 1~2px。
		var 尾高 := maxf(_title.size.y, _title_数值.get_combined_minimum_size().y)
		_title_数值.size = Vector2(尾宽, 尾高)
		_title_数值.position = Vector2(左 + 主宽,
				_title.position.y + roundf((_title.size.y - 尾高) * 0.5))

## 标题尾巴的节点（与 `_title` 并排、同一行）。只建一次；字色照抄标题变体，
## **字体不抄** —— 不设 font override 就落到主题的裸 `FontFile`（单色光栅）。
## 描边/阴影也**不抄**：`原版主题` 的 `Label` 本来就是规则值（黑、2、透明），
## 这里再抄一遍只会让「文字规则」门看不清真值来源（2026-10-25 门当场报 5 处）。
func _建标题数值() -> void:
	if _title_数值 != null:
		return
	_title_数值 = Label.new()
	_title_数值.name = "标题数值"
	_title_数值.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_数值.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_数值.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_数值.add_theme_color_override("font_color", _title.get_theme_color("font_color"))
	_title_数值.visible = false
	_title.add_sibling(_title_数值)

func _bind_scene_nodes() -> void:
	_overlay = get_node("遮罩") as Control
	## 浮层一挂上来就重算一次层序。原版 `PopUpMananger.showWindow:74-108` 把弹窗直接挂到
	## `uiMain` 最末（`showSwapDialog:1866-1873` 还要再 `setChildIndex(…, numChildren−1)` 顶一次）
	## ⇒ **弹出来那一刻就在所有窗口之上**。我们的浮层挂在宿主自己的 `遮罩` 里（跟着宿主的
	## CanvasLayer 走）⇒ 同一条不变量要在"入树那一刻"补一次重排，否则它要等玩家下一次点击才被纠正。
	if not _overlay.child_entered_tree.is_connected(_浮层进场):
		_overlay.child_entered_tree.connect(_浮层进场)
	_window = get_node("遮罩/主窗口") as Control
	_frame = get_node("遮罩/主窗口/窗口边框") as Panel
	_content_bg = get_node("遮罩/主窗口/内容底") as Panel
	_content = get_node("遮罩/主窗口/页面容器") as Control
	_title = get_node("遮罩/主窗口/标题") as Label
	_标题初始Y = _title.position.y
	_建标题数值()
	_status = get_node("遮罩/主窗口/后端状态") as Label
	_close_button = get_node("遮罩/主窗口/关闭按钮") as Button
	## 三态（常态 / 悬停 +30 / 按下 −40）与手型都不在代码里：那颗 X 自己挂了
	## `脚本/界面/组件/原版三态钮.gd`（烘在 `场景/界面/功能窗口.tscn`），
	## 与挂机页那 27 枚勾之外所有窗口 X 共用同一份状态机。
	_drag_area = get_node("遮罩/主窗口/拖动区") as Control
	_drag_area.gui_input.connect(_on_title_input)
	_close_button.pressed.connect(close)
	get_viewport().size_changed.connect(_resize_overlay)


## 拆页**之前**把货架滚动位置读出来存到窗口上（见 `_shop_scroll` 的注释）。
## 必须在 `remove_child` 之前调 —— 之后节点就没了。
func _记当前滚动位置() -> void:
	var 页 := _content.get_child(0) if _content.get_child_count() > 0 else null
	if 页 == null:
		return
	var 滚动 := 页.get_node_or_null("商品列表框/商品滚动") as ScrollContainer
	if 滚动 != null:
		_shop_scroll = 滚动.scroll_vertical
		return
	滚动 = 页.get_node_or_null("商品面板/商品滚动") as ScrollContainer
	if 滚动 != null:
		_npc_shop_scroll = 滚动.scroll_vertical


## 记下"焦点在哪枚 `LineEdit` 上、字打到第几列"。按 `_content` 的**相对路径**认人：
## 页面重建走的是同一个 `.tscn`，新实例的名字与层级一模一样 ⇒ 路径能对上。
## 排还原挂在**这里**而不是 `_render_page` 末尾 —— 那个函数中间有 `return` 分支
## （`_session == null`），漏掉一次就等于没修。
func _记输入焦点() -> void:
	_输入接力 = {}
	var 焦点 := get_viewport().gui_get_focus_owner()
	if not (焦点 is LineEdit) or _content == null or not _content.is_ancestor_of(焦点):
		return
	var 框 := 焦点 as LineEdit
	_输入接力 = {"路径": str(_content.get_path_to(框)), "文本": 框.text, "光标": 框.caret_column}
	call_deferred("_放输入接力")


## 把刚才那一下交还给**重建后**的同一路径控件：先写回文本（各页渲染时会把它按宿主持有的
## 旧值刷过一遍，这里覆盖回玩家实际打的），再抢焦点、把光标放回原来的列。
func _放输入接力() -> void:
	if _输入接力.is_empty() or _content == null:
		return
	var 框 := _content.get_node_or_null(String(_输入接力["路径"])) as LineEdit
	if 框 == null or 框.is_queued_for_deletion():
		return
	if 框.text != String(_输入接力["文本"]):
		框.text = String(_输入接力["文本"])
	框.grab_focus()
	框.caret_column = clampi(int(_输入接力["光标"]), 0, 框.text.length())


## `直落` = 这一趟是**换页/换页签**（开窗也走这里）：所有数值条当帧直接落到真值，
## 不许从 `.tscn` 烘的默认值或上一页的残留位扫一遍；回帧引起的同页重建仍走快照续接。
func _render_page(直落: bool = false) -> void:
	## 重建后旧菜单已经没了，等它收起的那笔推迟刷新自然也作废。
	_refresh_waiting_menu = false
	_记当前滚动位置()
	_记输入焦点()
	# 整页重建会把每根条打回 `.tscn` 烘的默认值（经验条 0、生命条 100、结印四根 0），
	# 随后的 0.5s 补间就从那里重新爬到新值 —— 用户 2026-10-31 报「60 变 65 却从头扫到尾」。
	# 原版 MBar 是常驻件、只从**当前视觉位置**续（`MBar.as:130/170`）⇒ 拆页前先按
	# 「内容根下的相对路径」记下每根条停在哪，`进度条补间._起` 建新补间时接回去。
	# 换页/换页签则改挂 `直落键`：那一趟**不许**拿旧位当起点（用户同日：「切换后是多少就是多少」）。
	_content.set_meta(进度条补间.重建快照键, _快照条值(_content))
	if 直落:
		_content.set_meta(进度条补间.直落键, true)
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	if _session == null:
		_content.add_child(_make_label("游戏数据尚未初始化", 16, Color.WHITE))
		_content.remove_meta(进度条补间.重建快照键)
		_content.remove_meta(进度条补间.直落键)
		return
	# 家族页**未入族时不显示窗壳本身**（见 `_该显示家族主窗`）。放在每次重绘的最前面
	# 统一归一化，是因为这个实例在老的"单窗口换页"用法里会换页 —— 只在 `_render_guild`
	# 里藏的话，从家族页切到人物页之后窗壳就再也不出来了。
	_设家族主窗可见(_该显示家族主窗())
	match _current_page:
		"人物": _render_character()
		# 「人物属性（看别人）」= 原版 `CharOtherWindow2`（真值 真值/窗口/人物属性_看别人.md）。
		# 开窗走 `窗口管理.打开`，数据来自后端那条 `58:4` 解出来的 `他人详细信息`。
		"人物属性看别人": _render_other_character()
		"角色改名": 改名窗.渲染(self, 改名窗场景)
		"背包": _render_inventory()
		"忍术": _render_skills()
		"宠物": _render_pets()
		"通灵驯养": _render_pet_study()
		"尾兽预览": _render_pet_preview()
		"任务": _render_quests()
		"组队": _render_team()
		"好友": _render_friends()
		"家族": _render_guild()
		"商城": _render_shop()
		"设置": _render_settings()
		"快捷键": _render_hotkeys()
		"闭关经验": _render_retreat()
		"领取修行收益": _render_retreat_claim()
		"挂机": _render_auto_combat()
		"副本": _render_copy()
		"地图信息": _render_map_info()
		"排行榜": _render_ranking()
		"兑换": _render_exchange()
		"活动": _render_activity()
		"活跃度": _render_activity_task()
		"信息": _render_info()
		"签到": _render_check_in()
		"福利": _render_benefit()
		"藏宝图": _render_treasure()
		"挖矿": _render_mining()
		"首领": 首领窗口.渲染(self)
		"精英副本": _render_elite_copy()
		"装备强化": _render_strengthen()
		"宝石镶嵌": _render_stone_carry()
		"技能书": _render_skill_books()
		"洗练": _render_ling_forge("洗练", _灵器炼制物品, _灵器炼制格)
		"灵化": _render_ling_forge("灵化", _灵器炼制物品, _灵器炼制格)
		"开光": _render_ling_forge("开光", _灵器炼制物品, _灵器炼制格)
		"开光人具": _render_ling_forge("开光人具", _灵器炼制物品, _灵器炼制格)
		"装备修复": _render_equip_repair()
		"梦幻属性符": _render_梦幻属性符()
		"橙装打造": _render_橙装打造()
		"遗址": 意志窗口.渲染背包(self)
		"意志学习": 意志窗口.渲染学习(self)
		"意志介绍": 意志窗口.渲染介绍(self)
		"NPC商店": _render_npc_shop()
		"神秘商店": _render_mystery_shop()
		"NPC仓库": _render_storage()
		"忍者传承": _render_legacy()
		"忍具兑换": _render_renju_exchange()
		"十拳剑兑换": _render_totsuka_exchange()
		"卡片套册": _render_card_collection()
		"兑换商店": _render_exchange_shop()
		"变身卡属性互换": _render_card_swap(false)
		"变身卡特性互换": _render_card_swap(true)
		"日环任务": _render_daily_ring()
		"周试炼任务": _render_weekly_ring()
		"勾玉炼制": _render_jade()
		"护送任务": _render_escort()
		"护送提示": _render_escort_notice()
		"竞技场": _render_arena()
		"竞技场英雄榜": _render_arena_rank()
		"跨服频道": _render_kuafu_channel()
		"生命料理": _render_liaoli()
		"洗点": _render_wash_point()
		"洗点确认": _render_wash_confirm()
		"双修邀请": _render_shuangxiu_invite()
		"家族邀请": _render_家族邀请()
		"羁绊申请": _render_求婚窗()
		"赠花": _render_赠花窗()
		"随身摊位": _render_stall()
		"附身宠物": _render_附身宠物()
		"货币上架": _render_货币上架()
		"摊位列表": _render_stall_list()
		"摊位购买": _render_stall_buy()
		"摊位上架": _render_stall_up()
		"交易": _render_trade()
		"二级密码说明": _render_second_password(二级密码窗.页说明)
		"二级密码设置": _render_second_password(二级密码窗.页一格)
		"二级密码资料": _render_second_password(二级密码窗.页二格)
		"二级密码问题": _render_second_password(二级密码窗.页三格)
		"二级密码修改": _render_second_password(二级密码窗.页修改)
		"二级密码解锁": _render_second_password(二级密码窗.页解锁)
		"徽章打造": _render_beast_badge()
		"心法": _render_xinfa()
		_: _content.add_child(_make_label("功能入口不存在", 16, Color.WHITE))
	_content.remove_meta(进度条补间.重建快照键)
	_content.remove_meta(进度条补间.直落键)


## 拆页前把 `_content` 子树里每根条的**当前视觉值**按相对路径记下来（见 `_render_page`）。
## ⚠ 只收进度条（`Range` 还包括 ScrollBar/SpinBox —— 滚动位置有自己那一套记录/还原）。
func _快照条值(根: Node) -> Dictionary:
	var 表 := {}
	var 根路 := String(根.get_path())
	var 待走: Array[Node] = []
	待走.append(根)
	while not 待走.is_empty():
		var 节点: Node = 待走.pop_back()
		if 节点 is ProgressBar or 节点 is TextureProgressBar:
			表[String(节点.get_path()).trim_prefix(根路)] = float((节点 as Range).value)
		for 子 in 节点.get_children():
			待走.append(子)
	return 表

func _resize_overlay() -> void:
	if _overlay != null:
		_overlay.size = get_viewport().get_visible_rect().size
		# 视口宽/高改了奇偶性时，0.5 锚点会把整扇窗推到 .5 上（同 `_居中偏移` 那条账）。
		# 这里只把**当前位置**收整，不重新回中 —— 用户拖到哪就还在哪。
		if _window != null:
			_window.global_position = _window.global_position.round()

func _render_character() -> void:
	人物窗口.渲染(self)

func _render_other_character() -> void:
	# 数据源 = **后端那一份镜像**（原版 `CharOtherWindow2.setData` 读的就是当前那一帧的
	# `CharacterFullInfo`）；窗实例上的 `_他人档案` 只作镜像还没到时（空档）的兜底。
	# ⚠ 别再反过来优先读窗实例：门里有一条腿直接改后端镜像再重绘（`看别人属性窗回归测试
	#   _验缺段不冒充`），窗实例那份还是上一帧的完整档 ⇒ 会拿旧的"他的 5 阶"冒充缺段。
	var 后: Node = get_node_or_null("/root/BackendConnection")
	var 档: Dictionary = (后.get("他人详细信息") as Dictionary) if 后 != null else {}
	if 档.is_empty():
		档 = get("_他人档案")
	# **开窗/回帧**那一次渲染才回到「角色 / 人物」这一页 —— 原版 `CharOtherWindow2.as:164-171
	# setData()` 里那句 `setPanel(0,0)`（`Client.as` 每收到一帧 `58:4` 就调一次 setData）。
	# ⚠ 判据用 `_刚开窗`：`open_page()` 只在"开窗/回帧重建"那一轮为真，
	#   而页签自己翻过去的那次重绘（`_set_character_*_tab` → `_render_page`）为假 ——
	#   写在这里无条件重置的话，页签永远翻不动（10-22 门腿 ⑧⑨ 当场红给它看）。
	if _刚开窗:
		_character_main_tab = 0
		_character_sub_tab = 0
	# 档为空也照样建页面：这扇窗只在收到 `58:4` 之后才会被开，空档只出现在体检/异常路径，
	# 而那时更要让**真版式**建出来（布局体检要量它；提前 return 会被判"空白"，10-15 实测）。
	人物窗口.渲染(self, 档)

## 改名卡持有数 = 原版 `ChangeNameWindow.updateCardCount:258-269` 的
## `API.dataCenter.getItemCountWithId(RENAME_CARD_ITEM_ID, 0)`。
## 直接在**服务端背包镜像**上按 id 累加 `quantity`（一条一格，键名出处
## `后端连接._parse_item_list`）。只读镜像，不读存档、不写任何东西。
func 改名卡数() -> int:
	var 后: Node = _backend
	if 后 == null:
		return 0
	var 数 := 0
	for 件 in (后.get("authoritative_inventory") as Array):
		if typeof(件) == TYPE_DICTIONARY and String((件 as Dictionary).get("id", "")) == 改名窗.改名卡号:
			数 += int((件 as Dictionary).get("quantity", 1))
	return 数


func _render_inventory() -> void:
	背包窗口.渲染(self)

func _render_skills() -> void:
	忍术窗口.渲染(self)

## —— 通灵驯养窗（宠物主窗右侧子窗，原版 `PetStudyWindow`）———————————————
## 它是**独立的一扇窗**，但不出现在底栏；由宠物主窗点「品级/悟性/四潜力」打开，
## 并贴主窗右缘（原版 `petTab.x = _width`）。所以开窗走 `窗口管理.打开("通灵驯养")`
## 之后自己 `窗口偏移` 到主窗右边 —— 位置由**主窗**给，不参与底栏的错开逻辑。
var _驯养页签 := 0            ## 0=通灵进阶 1=属性提升 2=宠物融魂（`PetStudyWindow.TYPE_*`）
var _驯养宠物id := ""         ## 主窗当前选中的那只（按显示 id）
var _驯养用记忆符 := false    ## 原版存 `UIConfig.userCfg.petJie.useJiYiFu`
var _驯养失败继续 := false
var _驯养融魂下标 := -1       ## 融魂页选中的尾兽按钮下标（原版 `_curIndex` 初值 -1）
## 融魂页「进页自动预览三尾」只开一次（原版 `update()` 每次都 `setWeiShouInfo(2)`，
## 但我们的渲染会在每次点击后重跑 —— 不挡就会反复弹预览窗）。
var _融魂预览已开 := false
var _驯养提升模式 := -1        ## 属性提升页下拉选中项（-1 未选 / 0 品级 / 1 悟性 / 2..5 四潜力）
## 家族确认弹按的是哪件事（`家族成员窗:解散家族` / `:退出家族`）——
## 弹窗的「确定」只带一个动作串，得靠这个才知道该发哪条协议。
var _家族确认动作 := ""
var _驯养用幸运符 := false    ## 潜力提升用不用幸运符（原版 `_xingYunCheckBox`）
var _驯养幸运符数 := 1        ## `_xingYunComboBox.selectedIndex + 1`
var _驯养重试计时: SceneTreeTimer = null

## —— 宠物主窗那四颗钮的动作态（原版 `PetWindow` 的 `isDelay` / 读条 / 三态闸）。
var _宠物动作时刻 := {}       ## 动作键 → 上次放行的 `Time.get_ticks_msec()`
var _附身读条中 := false      ## 1500ms 附身读条的重入挡
var _随页宠物id := ""         ## 「通灵驯养」副窗上次跟着哪只宠开出来的

const 通灵驯养窗口 := preload("res://脚本/界面/窗口/通灵驯养窗口.gd")


func _render_pet_study() -> void:
	通灵驯养窗口.渲染(self)


func _render_pet_preview() -> void:
	通灵驯养窗口.渲染预览(self)


## 开尾兽预览窗（原版 `PetRongHunTab.showYuLanWindow(_loc2_)`）。
var _预览尾兽号 := 0


func _开尾兽预览(兽号: int) -> void:
	var 管理: Node = get_parent()
	if 管理 == null or not 管理.has_method("打开"):
		return
	# ⚠️ 它**不是** `PopUpManager` 的居中弹出窗（上一版注释就是这么写错的）。原版
	#   `PetRongHunTab.showYuLanWindow:567-570` 是 `new RongHunYuLanWindow(); x=404; y=-6;
	#   this.addChild(...)` —— **挂在融魂页上的孩子**，永远贴在驯养窗右缘外侧。
	#   居中弹的后果实测：预览压住宠物主窗 **264×244**（用户报修 4.2）。
	管理.call("打开", "尾兽预览")
	# ⚠️⚠️ **跨窗状态第三次咬我**：状态要设在**渲染这个页面的那个宿主**上。
	#    设在调用方（驯养窗）上 → 预览窗读到 0 → 窗口开出来是空的（截图里就是一片黑）。
	#    同一类错在 `_打开驯养窗` 上已经犯过一次（§3.62 记着）。
	var 窗: Node = 管理.call("取窗口", "尾兽预览")
	if 窗 != null:
		窗.set("_预览尾兽号", 兽号)
		窗.call("_render_page")
	_重摆宠物双窗()		# 多了一扇 ⇒ 整条要重排（预览开着时整条贴右墙）
	_摆尾兽预览()


## `_摆宠物双窗` 是**主窗**的方法（它拿 `self` 当主窗摆位），而 `_开尾兽预览` 是驯养窗调的
## ⇒ 一律绕到主窗实例上再调，别在驯养窗实例上直接跑（那会把主窗的偏移写进驯养窗）。
func _重摆宠物双窗() -> void:
	var 管理: Node = get_parent()
	if 管理 == null or not 管理.has_method("取窗口"):
		return
	var 主: Node = 管理.call("取窗口", "宠物")
	if 主 != null and bool(主.call("已打开")):
		主.call("_摆宠物双窗")


## 关尾兽预览（原版 `closeYuLanWindow:575-586`：`destroy()` + `removeChild`，页没了它也必须没）。
func _关尾兽预览() -> void:
	var 管理: Node = get_parent()
	if 管理 == null or not 管理.has_method("取窗口"):
		return
	var 窗: Node = 管理.call("取窗口", "尾兽预览")
	if 窗 != null and bool(窗.call("已打开")):
		窗.call("close")


## 把预览摆到**驯养窗右缘外侧**（原版页局部 (404,−6) ⇒ 窗局部 (412,47)，
## 页根落点由 `开发工具/_探_驯养图标与预览实测.gd` 丁段实测钉住）。
## `窗口偏移` 收的是"窗中心距视口中心的偏移" ⇒ 两窗尺寸都要折进去半格。
func _摆尾兽预览() -> void:
	var 管理: Node = get_parent()
	if 管理 == null or not 管理.has_method("取窗口"):
		return
	var 预: Node = 管理.call("取窗口", "尾兽预览")
	if 预 == null or not bool(预.call("已打开")):
		return
	var 副: Node = 管理.call("取窗口", "通灵驯养")
	if 副 == null or not bool(副.call("已打开")):
		return
	var 副尺: Vector2 = 副.call("取窗口尺寸")
	var 预尺: Vector2 = 预.call("取窗口尺寸")
	if 副尺.x <= 0.0 or 预尺.x <= 0.0:
		return
	预.call("窗口偏移", 副.call("取位置偏移") + Vector2(412.0, 47.0) + (预尺 - 副尺) * 0.5, false)


## 驯养窗被拖动时预览跟手（原版它是页的孩子，天然跟手）。
func _拖动尾兽预览跟随(差: Vector2) -> void:
	if 差 == Vector2.ZERO:
		return
	var 管理: Node = get_parent()
	if 管理 == null or not 管理.has_method("取窗口"):
		return
	var 预: Node = 管理.call("取窗口", "尾兽预览")
	if 预 != null and bool(预.call("已打开")):
		预.call("移动相对", 差)



## 从宠物主窗打开：`页签` 0/1/2 由点的是哪个标签决定（原版 onOpenStudyWindow 的 switch）。
## `模式` = 「属性提升」页那六个下拉模式（0 品级 / 1 悟性 / 2..5 四潜力），-1 = 不动它。
## 原版六个标签各自带自己的子类型进来（`PetStrongTab.as:40-50`）。
func _打开驯养窗(宠物id: String, 页签: int, 模式 := -1) -> void:
	_驯养宠物id = 宠物id
	_驯养页签 = clampi(页签, 0, 2)
	if 模式 >= 0:
		_驯养提升模式 = clampi(模式, 0, 5)
	var 管理: Node = get_parent()
	if 管理 == null or not 管理.has_method("打开"):
		return
	# ⚠️ **先把状态写好再让它渲染**：`打开()` 内部会立刻 `_render_page()`，而新建实例的
	#    `_驯养宠物id` 还是空串 ⇒ 那一次渲染先弹一句"请先选一只通灵兽"，随后才被这里的
	#    第二次渲染盖掉。用户 2026-10-20 报的"每次打开宠物面板都发一遍"就是这条首帧。
	#    改成先 `取或建窗口`（不打开、不渲染）→ 灌状态 → 再 `打开`（只渲染一次）。
	var 窗: Node = 管理.call("取或建窗口", "通灵驯养")
	if 窗 == null:
		return
	# ⚠️ 状态要设在**驯养窗那个宿主实例**上，不是本窗（宠物窗）——
	# 页面是在驯养窗的 `_content` 里渲染的，`渲染()` 读的是**它自己**的 `_驯养宠物id`。
	# 2026-09-28 栽过：设在宠物窗上 → 页面渲染时读到空 → 一直提示"请先选一只通灵兽"。
	窗.set("_驯养宠物id", 宠物id)
	窗.set("_驯养页签", clampi(页签, 0, 2))
	if 页签 == 2:
		# 换宠进融魂页同样要落回"先看三尾"的初态
		_驯养融魂下标 = -1
		_融魂预览已开 = false
		窗.set("_驯养融魂下标", -1)
		窗.set("_融魂预览已开", false)
	if 模式 >= 0:
		窗.set("_驯养提升模式", clampi(模式, 0, 5))		# 同一条道理：页面读的是**驯养窗**那份
	if not bool(窗.call("已打开")):
		管理.call("打开", "通灵驯养")
	else:
		窗.call("_render_page")
	# 贴主窗右缘：原版 `petTab.x = _width`（444）。**必须整对摆位**：
	# 只对副窗调 `窗口偏移`（默认钳进视口）会把 410 宽的副窗钳回来，
	# 实测停在 x=−173（主窗一半塞到屏幕外），见真值 §15B。
	_随页宠物id = 宠物id
	_摆宠物双窗()


func _切驯养页签(号: int) -> void:
	# 离开融魂页 ⇒ 预览一起拆：原版它是 `PetRongHunTab` 的孩子，`setType` 换页时那一页整个
	# `removeChild` ⇒ 预览跟着没了。本工程页是重画的，预览却是独立一扇 ⇒ 必须显式收。
	if _驯养页签 == 2 and 号 != 2:
		_关尾兽预览()
	_驯养页签 = 号
	# 进融魂页 = 原版 `update()`：`_curIndex=-1` + `setWeiShouInfo(2)`（永远先看三尾）
	if 号 == 2:
		_驯养融魂下标 = -1
		_融魂预览已开 = false
	_render_page(true)


## 右侧「通灵驯养」窗跟着宠物页一起出（原版 `PetWindow.selectedPet:720-727` →
## `updateStudyWindow` → `createStudyWindow:632-641`：`petTab.x = _width; petTab.y = 0`）。
##
## 三条细节：
##   ① 已开着且还是同一只 ⇒ 只重摆位置，**不重刷**（重刷会把玩家正在看的页签顶回去）；
##   ② 玩家自己把副窗关了、又没换宠 ⇒ **不硬顶回来**（`_随页宠物id` 记住上次开的是谁）；
##      换了一只才跟着重开 —— 否则每次回帧重渲染都把副窗弹出来，烦人且不像原版；
##   ③ 关闭主窗时 `_随页宠物id` 归零（见 `close()`），下次开宠物页又能带出来。
func _随选中开驯养窗() -> void:
	if _current_page != "宠物" or String(_selected_pet_id).is_empty():
		return
	var 管理: Node = get_parent()
	if 管理 == null or not 管理.has_method("取窗口"):
		return
	var 副: Node = 管理.call("取窗口", "通灵驯养")
	var 已开 := 副 != null and bool(副.call("已打开"))
	## ⚠️ `取窗口` 在"从没建过这扇窗"时返回 **null**（`窗口管理.取窗口` 只查 `_窗口们`），
	##    所以这里不能直接 `副.get(...)`（2026-10-17 实测 `Cannot call method 'get' on a null value`）。
	var 副宠号: Variant = null
	if 副 != null:
		副宠号 = 副.get("_驯养宠物id")
	if 已开 and str(副宠号) == String(_selected_pet_id):
		_摆宠物双窗()
		return
	if not 已开 and _随页宠物id == String(_selected_pet_id):
		return
	if not 已开:
		# 同 `_打开驯养窗`：先建实例、灌状态，再 `打开` 渲染 —— 否则首帧读到空宠物 id
		# 会弹一句"请先选一只通灵兽"（2026-10-20 报修）。
		副 = 管理.call("取或建窗口", "通灵驯养")
		if 副 == null:
			return
		副.set("_驯养页签", 0)			# 原版 createStudyWindow 建出来停在「通灵进阶」
		副.set("_驯养宠物id", String(_selected_pet_id))
		# 原版每次 `createStudyWindow()` 都是**新** PetStudyWindow ⇒ `PetStrongTab._typeStrong = 0`（未选）。
		# 我们的副窗是复用的实例，不显式复位就会带着上一只的模式进来（用户 #3.3(5)）。
		副.set("_驯养提升模式", -1)
		_随页宠物id = String(_selected_pet_id)
		管理.call("打开", "通灵驯养")
		_摆宠物双窗()
		return
	副.set("_驯养宠物id", String(_selected_pet_id))	# 状态要设在副窗自己的实例上（跨窗状态坑）
	副.set("_驯养提升模式", -1)
	_随页宠物id = String(_selected_pet_id)
	副.call("_render_page")
	_摆宠物双窗()


## 宠物主窗 + 通灵驯养副窗**整对居中**：两扇合起来的宽度贴在屏幕中间，
## 主窗在左、副窗紧贴主窗右缘（原版 `petTab.x = _width`）。
##
## ⚠️ 两扇是**兄弟**（各是一个 `CanvasLayer` 的功能窗口），不是父子 ⇒ 这里必须两扇都显式摆，
## 且 `窗口偏移` 第二参传 `false`（不钳进视口），否则宽 854 的一对在 960 视口里
## 会被钳成"只看得见一半"。960 视口下：左 = 53，主窗 P=(53,76)、副窗 P=(497,76)。
##
## 融魂页的**尾兽预览**也开着时（原版它是融魂页的孩子 ⇒ 第三扇），整条宽 444+410+2+400 = 1256 > 960，
## 居中会把预览推出右墙 ⇒ 这时改成**贴右墙**（左 = 960−1256 = −296）：预览右沿正好压屏幕右沿、
## 三扇互不重叠（用户报修 4.2），代价是主窗左半截出屏 —— 它的标题栏与关闭钮仍在台上，
## 拖得动也关得掉；原版靠"舞台可放大到 2000×1200"躲过这一节，我们的视口钉死 960。
func _摆宠物双窗() -> void:
	var 管理: Node = get_parent()
	if 管理 == null or not 管理.has_method("取窗口"):
		return
	var 副: Node = 管理.call("取窗口", "通灵驯养")
	if 副 == null or not bool(副.call("已打开")):
		return
	var 主尺: Vector2 = 取窗口尺寸()
	var 副尺: Vector2 = 副.call("取窗口尺寸")
	if 主尺.x <= 0.0 or 副尺.x <= 0.0:
		return
	var 预: Node = 管理.call("取窗口", "尾兽预览")
	var 预尺 := Vector2.ZERO
	if 预 != null and bool(预.call("已打开")):
		预尺 = 预.call("取窗口尺寸")
	var 视口 := get_viewport().get_visible_rect().size
	## 预览开着时整条要多算 **2px 缝**：原版它是融魂页的孩子、挂在页局部 x=404，
	## 折到窗局部 = 412，而驯养窗只有 410 宽 ⇒ 它天生压着驯养窗右缘外侧 2px。
	## 不折这 2px 的话贴右墙会把预览推出屏幕 2px（实测 562..962 > 960）。
	var 总宽 := 主尺.x + 副尺.x + 预尺.x + (2.0 if 预尺.x > 0.0 else 0.0)
	var 左 := maxf(0.0, floorf((视口.x - 总宽) * 0.5))
	if 预尺.x > 0.0:
		左 = minf(左, floorf(视口.x - 总宽))
	var 上 := maxf(0.0, floorf((视口.y - 主尺.y) * 0.5))
	var 中心 := 视口 * 0.5
	窗口偏移(Vector2(左, 上) + 主尺 * 0.5 - 中心, false)
	副.call("窗口偏移", Vector2(左 + 主尺.x, 上) + 副尺 * 0.5 - 中心, false)
	## ⚠️ 预览是**跟着驯养窗**摆的（原版它是那一页的孩子，天然跟着走）⇒ 这里挪了两扇就必须
	## 把第三扇也重新锚一次，否则只有驯养窗动了、预览留在原地脱节。
	## 触发点不止 `_开尾兽预览`：`_随选中开驯养窗`（换宠/回帧）、`close()` 里预览自己关掉后的
	## `_重摆宠物双窗` 都会跑到这里。`_摆尾兽预览` 自己不再回摆这两扇 ⇒ 不成环。
	_摆尾兽预览()



## 拖主窗时副窗跟着走（原版副窗是主窗的**孩子**，天然跟手）。
func _拖动驯养窗跟随(差: Vector2) -> void:
	if 差 == Vector2.ZERO:
		return
	var 管理: Node = get_parent()
	if 管理 == null or not 管理.has_method("取窗口"):
		return
	var 副: Node = 管理.call("取窗口", "通灵驯养")
	if 副 != null and bool(副.call("已打开")):
		副.call("移动相对", 差)
	_拖动尾兽预览跟随(差)


## 关宠物主窗时把副窗一起拆（原版 `PetWindow.destroy:204-211` 里 `petTab` 是自己的 `addChild`）。
func _关宠物驯养窗() -> void:
	var 管理: Node = get_parent()
	if 管理 == null or not 管理.has_method("取窗口"):
		return
	var 副: Node = 管理.call("取窗口", "通灵驯养")
	if 副 != null and bool(副.call("已打开")):
		副.call("close")


## 按「相对偏移」平移本窗（拖动跟随用；`窗口偏移` 收的就是相对视口中心的偏移）。
func 移动相对(差: Vector2) -> void:
	窗口偏移(取位置偏移() + 差, false)


## 1000ms 节流 —— 原版 `MButtonF.isDelay = true`（`PetWindow.as:897` 挂在附身/驯养/出战三颗上，
## 放生**不挂**）。返回 true = 这次放行。
func _宠物按钮节流(键: String) -> bool:
	var 现 := Time.get_ticks_msec()
	if 现 - int(_宠物动作时刻.get(键, -100000)) < 1000:
		return false
	_宠物动作时刻[键] = 现
	return true


## 原版 `PetDataManage.isLevelEnough:45-69` 的两道闸 ⇒ 空串 = 放行，否则是要弹的提示。
##   ① 玩家级 < 通灵兽等级；② 玩家级 < 模板 `info.carryLevel`（`PetAddValue.getPetCarryLevel`）。
static func 等级不足提示(玩家级: int, 宠物级: int, 携带级: int, 用途: String) -> String:
	if 玩家级 < 宠物级:
		return "需要%d级才能%s这只通灵兽！" % [宠物级, 用途]
	if 玩家级 < 携带级:
		return "需要%d级才能%s这只通灵兽！" % [携带级, 用途]
	return ""


func _宠物等级够(宠: Dictionary, 用途: String) -> bool:
	var 玩家级 := 1
	if _session != null:
		玩家级 = int((_session.get("player_stats") as Dictionary).get("level", 1))
	# `宠物数值.携带等级` = 原版 `PetAddValue.getPetCarryLevel`，读模板 `info.carryLevel`（已导出）
	var 携带级 := int(宠物数值.携带等级(宠))
	var 提示 := 等级不足提示(玩家级, int(宠.get("level", 0)), 携带级, 用途)
	if 提示.is_empty():
		return true
	_通知(提示)
	return false


func _驯养宠物() -> Dictionary:
	return _pet_by_id(_驯养宠物id)


func _背包数量(物品号: int) -> int:
	var 总 := 0
	for 项 in _session.inventory:
		if int(项.get("id", 0)) == 物品号:
			总 += int(项.get("quantity", 0))
	return 总


## 金币数：**先读会话的 `player_stats.gold`**（服务端属性帧 27 ⇒ gold，见 `后端连接.gd:1890`），
## 会话没有这一键时再退回后端的权威属性 —— 各页（生命料理/通灵驯养/宿主自己）共用这一个口径。
func _金币() -> int:
	if _session != null and (_session.get("player_stats") as Dictionary).has("gold"):
		return int((_session.get("player_stats") as Dictionary).get("gold", 0))
	var 后端 := get_node_or_null("/root/BackendConnection")
	if 后端 == null:
		return 0
	return int((后端.get("authoritative_stats") as Dictionary).get("money", 0))


func _通知(文本: String) -> void:
	_session.notification_requested.emit(文本)


## 复选项外观：原版 `MCheckBoxF`（方框 + 文本），工程里已有 原版复选项 组件
func _配置复选项(按钮: Button, 选中: bool) -> void:
	按钮.toggle_mode = true
	按钮.button_pressed = 选中
	按钮.focus_mode = Control.FOCUS_NONE
	var 框 := 按钮.get_node_or_null("框") as TextureRect
	if 框 != null:
		框.texture = load(ORIGINAL_CHECKBOX_ON if 选中 else ORIGINAL_CHECKBOX_OFF) as Texture2D


## 开始提升。原版 `PetLayerTab.onClickHand` 的拦截顺序：能进阶 → 材料够 → 金币够 → (用记忆符则)记忆符够。
func _请求进阶(宠物: Dictionary, 进化: Dictionary, 进阶符: int, 需要: int, 记忆符: int, 需钱: int) -> void:
	if int(进化.get("enable", 0)) == 0 or int(进化.get("nextPetId", 0)) == 0:
		_通知("你的通灵兽已达到最高阶！" if int(进化.get("nextPetId", 0)) == 0 else "很抱歉，不能进行该操作！")
		return
	if _背包数量(进阶符) < 需要:
		_通知("%s不足。" % GAME_DATA.item_name(进阶符))
		return
	if _金币() < 需钱:
		_通知("金币不足。")
		return
	var 用 := 1 if _驯养用记忆符 else 0
	if 用 == 1 and _背包数量(记忆符) < 1:
		_通知("%s不足。" % GAME_DATA.item_name(记忆符))
		return
	var 后端 := get_node_or_null("/root/BackendConnection")
	if 后端 == null or not 后端.request_pet_evolve(int(宠物.get("unique_id", 0)), 用):
		_通知("进阶请求未发送")
		return
	# 失败后自动继续：原版 `layerResult(0)` → `setTimeout(goToLayer, 900)`
	if _驯养失败继续:
		_排一次重试()


## 开始融魂。原版 `PetRongHunTab.onRongHunHandler` 的两道前置 + `requestRongHun(uid, _curIndex)`。
## ⚠️ 总梦幻度 ≥ 70 那道门槛**只在服务端**（`_fuse_pet_soul`），客户端不预判 —— 发过去由服务端回话。
func _请求融魂(宠物: Dictionary) -> void:
	if _驯养融魂下标 < 0:
		_通知("请先选择一只尾兽")
		return
	if 通灵驯养窗口.尾兽id.has(int(宠物.get("item_id", 0))):
		_通知("你的宠物已经融魂！")
		return
	if int(宠物.get("aptitude", 1)) < 4:      # PetAptitude.PREEMINENCE
		_通知("通灵兽品阶不足！")
		return
	var 后端 := get_node_or_null("/root/BackendConnection")
	if 后端 == null or not 后端.request_pet_soul_fusion(int(宠物.get("unique_id", 0)), _驯养融魂下标):
		_通知("融魂请求未发送")
		return
	# 融魂结果由服务端回帧（`EVOLUTION_UP 15` / `UPDATE 2`），面板随 `pets_changed` 自动刷新


const 文不够 := "很抱歉，你的%1不够"		# EQUIP_STRENGTH_FAIL_PROMPT_2_1（= `CN.as:8967` 那个数组的 [0]）
const 文金币 := "金币"					# EQUIP_STRENGTH_FAIL_PROMPT_2_2（= 同一个数组的 [1]）


## 开始提升（`PetStrongTab.onClickHand:289-338`）：闸门顺序 **材料 → 金币 → 幸运符**
## （`:295` `validateNeedItem` → `:300` `validateMoney` → 潜力分支里 `:320` `validateXinYunJing`），
## 三句提示共用同一条模板 `EQUIP_STRENGTH_FAIL_PROMPT_2[0]` =「很抱歉，你的%1不够」
## （`CN.as:8965-8968`：`[0]=_1` 是模板、`[1]=_2` 是"金币" ⇒ 金币那句是模板替进"金币"，
## 材料/幸运符那两句替的是 `StringTool.getItemString(物品号)` —— **不是**"××不足。"）。
## 幸运符颗数只对**潜力模式**有意义（原版 `_loc2_`：勾了才取 `selectedIndex + 1`，否则 0）；
## 品级/悟性两支原版**固定传 1**（`:311`/`:314`），跟勾没勾无关。
## ⚠ 原版第一句是 `if(KuaFuManager.inKuaFuBattle()) return;`（跨服大战里直接不给点，静默）——
##   本工程没有那份"我在跨服战场"的客户端状态（服务端 `war_battle_active` 不下发给客户端）⇒ 这条没落，
##   已记进 `真值/世界/外来帧与上行接线.md` §⑤。
func _请求提升(宠物: Dictionary, 配置: Dictionary, 模式: int, 幸运符: int) -> void:
	if _backend == null:
		_通知("未连接服务端")
		return
	var 材料 := int(配置.get("needItemId", 0))
	var 需要 := int(配置.get("needItemCnt", 0))
	if _背包数量(材料) < 需要:
		_通知(文不够.replace("%1", GAME_DATA.item_name(材料)))
		return
	if _金币() < int(配置.get("needMoney", 0)):
		_通知(文不够.replace("%1", 文金币))		# `:539` `replaceString(_2[0], _2[1])`
		return
	# `:114-122`：勾选了才判，且比的是**下拉选中的那个颗数**（`selectedIndex + 1`），不是"至少有一枚"
	if 模式 >= 2 and _驯养用幸运符 and _背包数量(幸运符) < _驯养幸运符数:
		_通知(文不够.replace("%1", GAME_DATA.item_name(幸运符)))
		return
	var uid := int(宠物.get("unique_id", 0))
	var 颗 := (_驯养幸运符数 if _驯养用幸运符 else 0) if 模式 >= 2 else 1
	var 发出 := false
	match 模式:
		0:
			发出 = _backend.request_pet_rewash_aptitude(uid, 颗)
		1:
			发出 = _backend.request_pet_change_savvy(uid, 颗)
		_:
			发出 = _backend.request_pet_strength_potential(uid, 颗, 模式 - 1)
	if not 发出:
		_通知("提升请求未发送")


## 家族创建窗的「创建」：读表单三值 + 发 `request_guild_create`。
## ⚠️ 旗页样式（原版翻页选）这一版给 0 —— 旗页选择器还没接数据，先不编一个值。
## 家族创建窗的「创建」：读表单 + 选中家徽样式，校验后发 `request_guild_create`。
##
## 校验集中在 `家族创建填充.校验`（家族名/家徽名长度 + 创建材料 16000022），
## 因为那几条门槛的口径都在那边（原版 `validateInput()` + `FamillyManager.createFamilly()`）。
## ⚠️ 之前这里只判了"名字 ≥2 字"，而且提示写的是**「需要 1000 金币」** —— 那是自造的：
##    单机版创建门槛是 `flag["1"].cost` 的 **16000022×1、金币 0**，一分钱都不收。
func _发创建家族() -> void:
	var 后端 := get_node_or_null("/root/BackendConnection")
	if 后端 == null:
		return
	# ⚠️ 取内容页一律走 `家族子窗壳.取内容`：别自己拼 `家族子窗_X/X` 的路径 ——
	#    那要求**场景根节点名恰好等于窗名**，而 `家族列表窗.tscn` 的根叫「原版家族列表内容」，
	#    拼出来的路径恒为 null ⇒ 静默什么都不做（2026-09-30 的在线用例抓到的）。
	var 创建窗 := 家族子窗壳.取内容(self, "家族创建窗")
	if 创建窗 == null:
		_通知("创建窗没开着")
		return
	var 拦截 := String(家族创建填充.校验(创建窗, self))
	if not 拦截.is_empty():
		_通知(拦截)
		return
	var 表单 := 家族创建填充.取表单(创建窗)
	var 名 := String(表单.get("name", ""))
	var 徽名 := String(表单.get("emblem", ""))
	var 公告 := String(表单.get("notice", ""))
	# 家徽样式取页面当前翻到的那一个（原来恒发 0，等于玩家选的图案永远不生效）。
	后端.request_guild_create(名, 家族创建填充.选中样式(创建窗), 徽名, 公告 if not 公告.is_empty() else "团结协作，共同守护木叶。", 0)


## 家族创建窗「图形选择」翻页：把内容页交给 `家族创建填充.翻页`（它知道样式表与当前页号）。
func _翻家徽(步: int) -> void:
	var 创建窗 := 家族子窗壳.取内容(self, "家族创建窗")
	if 创建窗 == null:
		return
	家族创建填充.翻页(创建窗, self, 步)


## 家族创建窗「购买」：弹**商城「购买道具」窗**，而不是直接买。
##
## ⚠️ 2026-10-06 用户实机纠正：原来这里点一下就直接发 1081 买 1 本，**跳过了购买弹窗**。
##    正确链路和商城一样：`CashItemCell` 购买 → `BUY_FROM_LIST` → `CashShopWindow2.__buyItem`
##    → `BuyEqpWindow.setData`（`BuyEqpWindow.as`，518 行）—— 也就是那个「购买道具」窗：
##    售价 / 绿字说明 / 购买方式 / 购买数量 / 购买总价 / 你帐号中还有元宝 / 购买
##    （原版那颗「充值」本工程已删，见 `商城购买窗.gd::_排购买`）。
##
## ⚠️ 价格**必须问服务端**（`1086` 商品详情 → 回 `1079`），别本地硬编码：
##    服务端 `_cash_shop_price(item_id, 分类)` 会按**商品所属分类**与编辑器覆盖算价，
##    而族书的段是 FuZhuWuPin ⇒ 落「召唤」页(2)。拿到详情后由 `cash_item_info_received`
##    把弹窗开出来（详情里带着服务端现价，与商城窗口显示的是同一个数）。
func _发购买族书() -> void:
	var 后端 := get_node_or_null("/root/BackendConnection")
	if 后端 == null:
		return
	var 物品号 := int((GAME_DATA.family_create_cost().get("item", [{}]) as Array)[0].get("id", GAME_DATA.家族创建材料))
	if 物品号 <= 0:
		return
	# ⚠️⚠️ 上传分支与 nr1 的**唯一差异**就在这里：nr1 是 lazy connect 一份
	#     `cash_item_info_received → _收到族书详情` 自己弹窗；而本分支 `_ready` 里已经把
	#     这条信号**全局**接到了 `打开商城购买窗`（1079 回包 → 遮罩上的「购买道具」窗）。
	#     再接一份会和它**双开**（同一件商品弹两枚窗）⇒ 这里只发请求，弹窗走全局那条。
	#     附带好处：购买窗挂遮罩而非创建窗窗根，关闭由 `_商城购买窗关了` 统一管，
	#     连 `_收到族书详情`/`_开族书购买窗`/`_族书购买窗关了`/`_成交族书` 四支都不需要。
	if not 后端.request_cash_item_info(物品号):
		_通知("购买请求未发送（可能未进入游戏）")


## 详情到了才开窗。**只认我们等的那一件**：这条信号是全局的，商城窗口也会收，
## 不能把别人点的商品劫过来弹。
## 家族创建窗的「检测重名」：原版 `FamillyCreateWindow.nameValidateHandler`
## → `API.client.requestBanghuiCheckBanghuiName(名字)`（服务端 `action 21`，回包 `19:<0|1>`）。
## ⚠️ 这条链路原来**一个字节都没接** —— 那颗钮点下去没有任何反应。
func _发检测重名() -> void:
	var 后端 := get_node_or_null("/root/BackendConnection")
	if 后端 == null:
		return
	var 创建窗 := 家族子窗壳.取内容(self, "家族创建窗")
	if 创建窗 == null:
		return
	# 占位提示算空（原版 `validateInput()` 就是拿 `text == CN.NAME_PROMPT` 判"没填"）。
	var 名 := String((家族创建填充.取表单(创建窗) as Dictionary).get("name", ""))
	if 名.is_empty():
		_通知("请输入家族名称")
		return
	if 名.length() < 2:
		_通知("家族名至少 2 个字")
		return
	# 换名字就得重新检测：先把上一次的"可用"结论清掉。
	家族创建填充.清重名态(创建窗)
	if not 后端.request_guild_check_name(名):
		_通知("重名检测未发送")




## 家族列表窗的「申请加入」。
## 三条拦截照抄原版：① 没选中行 ⇒ 静默（`FL:367` 的 `if(this.list.selectedItem)`）；
## ② 已经在某个家族里 ⇒ 提示 `CN.FAMILLY_MANAGER_SORRY_YOU_JIAZU`、**不发协议**
## （`FM.as:769-777`）；③ 否则发 `requestBanghuiApply(id)`（`BanghuiProcessor.as:174-180`
## 的 action 2 + 家族 id，服务端 `handle_banghui` 的 `action == 2`）。
func _发申请加入() -> void:
	var 窗 := 家族子窗壳.取内容(self, "家族列表窗")
	if 窗 == null:
		return
	var 家族: Dictionary = 窗.call("选中家族") as Dictionary
	if 家族.is_empty():
		return
	if _backend == null or not bool(_backend.in_game):
		return
	if bool((_session.guild as Dictionary).get("joined", false)):
		_通知("很抱歉，你已经有家族了！")
		return
	_backend.request_guild_apply(int(家族.get("id", 0)))


## ── 家族金币窗（原版 `ZhuGongMoneyWindow`）：把金币捐进**家族资金** ─────────────
## `_step = 10000`、`_minMoney = 10000`（`ZGM.as:29,35`）是原文常量，不是估的。
## 协议：`requestBanghuiContribution([{itemid:0, count:<金额>}])`（`:60-66`）——
## 我方 `request_guild_donate` 发的 `itemId&数量` 里 **itemId=0 就是捐金币**，同一条。
const 金币窗步长 := 10000
const 金币窗下限 := 10000


func _家族金币窗() -> Control:
	return 家族子窗壳.取内容(self, "家族金币窗")


## 开窗时：余额框 = 玩家金币、捐献框 = 下限（`ZGM.as:96-100 initView`）。
func _初始化金币窗() -> void:
	var 窗 := _家族金币窗()
	if 窗 == null:
		return
	var 余额 := int(_session.player_stats.get("gold", 0))
	(窗.get_node("输入余额") as LineEdit).text = str(余额)
	(窗.get_node("输入捐献") as LineEdit).text = str(金币窗下限)


## 减 / 加 / 最大 / 确定（`ZGM.as:58-72,204-247`）。三条数值规则照抄：
## 加不超过余额、减不低于下限、输入框超界时钳回去。
func _家族金币动作(动作: String) -> void:
	var 窗 := _家族金币窗()
	if 窗 == null:
		return
	var 余额 := int(_session.player_stats.get("gold", 0))
	var 框 := 窗.get_node("输入捐献") as LineEdit
	var 原文 := String(框.text).strip_edges()
	var 值 := int(原文) if 原文.is_valid_int() else 金币窗下限
	match 动作:
		"加":
			值 = mini(值 + 金币窗步长, 余额) if 值 < 余额 else 值
		"减":
			值 = maxi(值 - 金币窗步长, 金币窗下限) if 值 > 金币窗下限 else 值
		"最大":
			值 = 余额
		"确定":
			if 值 > 余额 or 余额 < 金币窗下限:
				_通知("对不起，你的金币不足")
				return
			if _backend != null and bool(_backend.in_game):
				_backend.request_guild_donate([[0, 值]])
			# 原版发完就 `onCloseBtnClick`（`:67`）—— 收窗表里没有「确定」，这里自己收。
			家族子窗壳.关掉(self, "家族金币窗")
			return
	框.text = str(maxi(金币窗下限, mini(值, maxi(余额, 金币窗下限))))


## 家族旗帜窗底部那两颗钮（原版 `FamillyFlagWindow.as`）。
##
## ⚠️ 别照着"点了就发协议"写：原版 `insertFlagHandler`（`:379-397`）是**三步**，
##    而且前两步失败时只弹系统提示、什么都不发：
##      ① 没选中 → `FAMILLY_FLAG_WINDOW_SELECT_MAP`「请选择您要安插的地图」
##      ② 今日安插次数用完（`myFlagCount >= MAX_INSERT_FLAGS`，`FM.as:65` = 1）
##         → `FAMILLY_FLAG_INSERT_FINISHED`「今日旗帜安插次数已用完」
##      ③ 否则弹确认弹（正文 `FAMILLY_FLAG_WINDOW_XIAOHAO_JINBI`、按钮 `COMMON_OK`），
##         **确认之后**才发 `1815:1`
##    「修复族旗血量」那颗原版 `modifyFlagBloodHandler` 没有确认弹，直接发。
func _家族旗帜动作(动作: String) -> void:
	var 窗 := 家族子窗壳.取内容(self, "家族旗帜窗")
	var 后端 := get_node_or_null("/root/BackendConnection")
	if 窗 == null or 后端 == null or not bool(后端.in_game):
		return
	var 选中 := 窗.get_meta("flag_selected", {}) as Dictionary
	var map_id := int(选中.get("map_id", 0))
	if 动作 == "安插本族旗帜":
		if map_id <= 0:
			_系统提示("请选择您要安插的地图")
			return
		# ⚠️⚠️ 原版这里还有一道 `myFlagCount < MAX_INSERT_FLAGS`（`FFW:383`），
		#    但那个计数**不是**"本族已安插的族旗数"，别自己去数族旗表：
		#    原版 `myFlagCount` 的唯一来源是服务端推送 `onBanghuiUpdatePlugFlagCnt` →
		#    `param1.plugFlagCnt`（`Client.as:7792-7795`，配套文案「今日安插次数%1」）。
		#    本机服务端**从不发这条推送**（`fake_flash_server` 里查无此项）⇒ `myFlagCount` 恒为 0
		#    ⇒ 这道门在原版里也永远不会触发。
		#    2026-10-08 之前我们拿"族旗表里本族占了几面"顶替它 ⇒ 本族只要有 1 面旗，
		#    下一次安插就被客户端拦掉（提示"今日次数已用完"），而服务端根本不看这个 ——
		#    **这就是"旗帜还是无法安插"的直接原因**。现在不拦，交给服务端裁决
		#    （它会回「该地图已经有族旗。」/「本族可安插的族旗已达上限。」/「只有族长可以操作族旗。」）。
		#    将来服务端补了那条推送，再在这里读它。
		_族旗安插图 = map_id
		_家族确认动作 = "家族旗帜窗:安插本族旗帜"
		# `家族确认弹` 原版就不是 UIWindow（自带 580 号底），开窗表里那几条也都传 `false`。
		家族子窗壳.切换(self, "家族确认弹", "安插族旗", false)
		_填家族确认弹(_家族确认动作)
		return
	if map_id <= 0:
		return
	后端.request_map_flag_cure(map_id)


func _系统提示(文本: String) -> void:
	if _session != null:
		_session.notification_requested.emit(文本)

func _家族商城购买(商品文本: String) -> void:
	var 后端 := get_node_or_null("/root/BackendConnection")
	var 商品_id := int(商品文本)
	if 后端 == null or not bool(后端.in_game) or 商品_id <= 0:
		return
	后端.request_guild_shop_buy(商品_id)

## 家族令牌窗的「确定」：把拖进格子的那几叠书捐进族贡仓库
## （原版 `ZhuGongLingWindow.clickOkBtnHandler`，`ZGL.as:44-56`）。
## 空格子不发 —— 一条都没有时原版那个 `if(_loc2_.length > 0)` 就拦掉了。
func _发令牌捐献() -> void:
	var 窗 := 家族子窗壳.取内容(self, "家族令牌窗")
	if 窗 == null:
		return
	var 行: Array = 家族令牌填充.收取行(窗)
	if 行.is_empty():
		return
	if _backend == null or not bool(_backend.in_game):
		return
	if _backend.request_guild_donate(行):
		家族令牌填充.清空(窗)


## 好友页（另一位开发者那一版）的「删除/拉黑/移除/泯恩仇」先弹**输入型确认弹**
## （原版 `MDialog.showInputDialog`，他的说明 §2 ③ 规定宿主实现这一个方法）。
## 页面在宿主没这个方法时会退化成"直接交回动作"，不会静默吞点击。
func _弹出输入确认(正文: String, 默认值: String, 只读: bool, 回调: Callable) -> void:
	if _overlay == null:
		return
	输入确认弹.弹出(_overlay, 正文, 默认值, 只读, 回调)


func _排一次重试() -> void:
	_驯养重试计时 = get_tree().create_timer(0.9)
	var 计 := _驯养重试计时
	await 计.timeout
	if 计 != _驯养重试计时 or not _驯养失败继续:
		return
	if not 已打开():
		return
	# 重新读一遍宠物与配置（失败会涨祝福值，成功率随之变化），再走同一条拦截链
	var 宠物 := _驯养宠物()
	if 宠物.is_empty():
		return
	var 行 := GAME_DATA.pet_template(int(宠物.get("item_id", 0)))
	var 进化: Dictionary = (行.get("info", {}) as Dictionary).get("evolution", {})
	_请求进阶(宠物, 进化, int(进化.get("needItemId", 0)), int(进化.get("needItemCnt", 0)),
		int(进化.get("helpItemId", 0)), int(进化.get("needMoney", 0)))


## ── 结印「自动提升」= 原版的**客户端循环** ——————————————————————————————
## 真值 `JieYinTiShengWindow.as`：`sureToAutoTiSheng:205-211` 置 `_isAutoTiSheng`、
## 把钮文字换成「停止提升」，然后 `tiShengJieYin(true)` 跳第一下；
## 之后每一发**结果帧**（2318:2）过 `onJieYin_stageupResult:182-193`：
##   · `result==1`（这一跳把阶段推上了下一层）⇒ `clearTimeout` 停；
##   · 否则还在自动态 ⇒ `setTimeout(tiShengJieYin, 800)` 再发**同一发 byte 0**。
## ⇒ 自动**不是**服务端一次吞光精华（byte 1 `eatUpAutoConsumeAllZq` 原版零调用点），
##   确认正文里那三条停止条件（精华不足 / 升阶成功 / 手动或点停止）就是这么来的。

## 二次确认点了「确定」之后的落点（`输入确认弹.弹消息` 回调：**1=确定 / 2=取消**）。
func 起结印自动() -> void:
	_结印自动提升 = true
	_refresh_current()		# 先把钮文字翻成「停止提升」，不等服务端回帧
	人物窗口.结印一跳(self, true)


## = 原版 `clearTimeOut():235-241`（selected=false + 文字换回「自动提升」+ clearTimeout）。
func 停结印自动() -> void:
	if not _结印自动提升 and _结印自动计时 == null:
		return
	_结印自动提升 = false
	_结印自动计时 = null
	_refresh_current()


## 结印的每一帧都从这儿过一眼（`后端连接.jieyin_state_received`）：
## 只有动作 2（`action_JieYinEatUpResult` = `result, addCount`）驱动循环，
## 动作 0（阶段/熟练度）只管界面、不参与。
## ⚠️ 原版对结果帧**一句提示都不弹**（`Client.onJieYin_eatUpResult:8285-8291` 只把它转给
##   提升弹窗）⇒ 这边也一样，既不能落到 `_handle_cultivation_text` 那条别族「神符升阶」的
##   文案支上（每跳一次就弹一句「很抱歉，进阶失败！」），也别在这里加话。
func _收到结印帧(状态: Dictionary) -> void:
	if int(状态.get("action", -1)) != 2 or not _结印自动提升:
		return
	if bool(状态.get("success", false)):
		停结印自动()		# 停止条件 2：结印阶段成功的提升到了下一层
		return
	_排结印下一跳()


func _排结印下一跳() -> void:
	var 计 := get_tree().create_timer(0.8)
	_结印自动计时 = 计
	# 令牌比对：`停结印自动()` 把 `_结印自动计时` 置空后，已经排下去的那发不会再补包
	# （AS3 的 `clearTimeout` 是"取消那一发"，Godot 的 timer 取消不了 ⇒ 用令牌等效）。
	计.timeout.connect(func() -> void:
		if 计 != _结印自动计时 or not _结印自动提升 or not 已打开():
			return
		人物窗口.结印一跳(self, true))


## ── 写轮眼 / 柔拳 / 轮回六道的「自动提升」= 与结印同一套**客户端循环** ————————————
## 三族的原文逐条对过（真值出处见 `人物窗口.族一跳` 上方那张表）：
##   · 点「自动提升」⇒ 先过 `canTiSheng()` / `setStartBtnEnbled()` 那道**拥有数前置**，
##     够才弹 `*_AUTO_TISHENG_PROMPT` 二次确认，确认了才换钮文字并立刻跳第一下；
##     不够 ⇒ 只发一句提示、**连确认都不弹**；
##   · 每一发**结果帧**（动作 2）过各族的 `on*_stageupResult`：还在自动态且没升阶
##     ⇒ `setTimeout(再发一发, 800 / 写轮眼 1000)`；升阶成功 ⇒ 停；
##   · 手动那一跳、点「停止提升」、关掉弹窗 / 关窗 ⇒ 都停。

func 族自动中(族: String) -> bool:
	return bool(_族自动提升.get(族, false))


## 二次确认点了「确定」之后的落点（同 `结印文案` 那套：**1=确定 / 2=取消**）。
func 起族自动(族: String) -> void:
	_族自动提升[族] = true
	_refresh_current()		# 先把钮文字翻成「停止提升」，不等服务端回帧
	人物窗口.族一跳(self, 族, true)


func 停族自动(族: String) -> void:
	if not 族自动中(族) and _族自动计时.get(族) == null:
		return
	_族自动提升[族] = false
	_族自动计时[族] = null
	_refresh_current()


## 结果帧驱动循环（`后端连接.修炼结果帧`）。
## ⚠️ 成功那一跳**要不要顺手把弹窗收掉**是分族的：写轮眼 `TongshuSource:78` 调
##   `tishengPanel.onCloseBtnClick(null)`、轮回 `LunHuiYanTiShengWindow:196` 调
##   `closeWindowHandler(null)` —— 两族升阶成功当场关窗；柔拳 `:62` 只 `clearTimeout`、
##   结印同理（窗还开着）。这边照这个差别办。
func _收到修炼结果帧(族: String, 成功: bool, _用神符: bool) -> void:
	if 族 == "手里剑":
		_手里剑结果帧(成功)
		return
	if not 族自动中(族):
		return
	if 成功:
		if 族 == "写轮眼" or 族 == "轮回六道":
			_族弹窗开着[族] = false
		停族自动(族)		# 内部 `_refresh_current()` 一次到位（钮文字 + 弹窗落位一起复原）
		return
	_排族下一跳(族)


func _排族下一跳(族: String) -> void:
	var 计 := get_tree().create_timer(人物窗口.族自动间隔(族))
	_族自动计时[族] = 计
	# 同结印那条：令牌比对就是"停止后立刻重开不该把旧的那发也算进来"的守卫。
	计.timeout.connect(func() -> void:
		if _族自动计时.get(族) != 计 or not 族自动中(族) or not 已打开():
			return
		人物窗口.族一跳(self, 族, true))


## ── 手里剑「失败后自动继续」= 原版的**客户端连点重试** ————————————————
## 真值 `ThroughShouLiJianWindow.as`：`toPoResult:360-370` 收 `1817:3` 结果帧 ——
##   · `result==1`（成功）⇒ 只 `clearLayerTimeOut()`，**连勾选都不清**（那枚勾是玩家的偏好）；
##   · `result==0`（失败）且 `_failCheckBox.selected` ⇒ `setTimeout(continueToPoShouLiJian, 900)`；
## `continueToPoShouLiJian:383-387` = `clearLayerTimeOut()` + `toPoHandler(null)`
## ⇒ 重试**不经过那枚钮**（所以不吃 1000ms 的 `isDelay` 节流），走的是同一条预检 + 发包。
## 取消勾选那一下 = `continueToPoHandler:428-434` 的 `clearTimeout`。
## ⚠️ 这一族**不靠"自动态"开关**（结印/柔拳/写轮眼/轮回那四族看 `_族自动提升`），
##   看的是弹窗里那一枚勾 —— 所以状态记在窗口上、勾选态每次重绘回灌给弹窗
##   （`人物窗口.初始化手里剑页`）。
func _手里剑结果帧(成功: bool) -> void:
	if 成功:
		_手里剑重试计时 = null		# 原版 `toPoResult(1)` = `clearLayerTimeOut()`
		return
	if _手里剑失败继续:
		_排一次手里剑重试()


## 900ms 后自己再跳一发 —— 令牌比对 = AS3 的 `clearTimeout`（Godot 的 timer 撤不掉，
## 同 `_排族下一跳:2169` / `_排结印下一跳:2113` 那两条的写法）。
## 落点前置两条：还勾着、且那扇弹窗**还亮着**（原版它是常驻顶层窗，我们这边页面重绘会收掉它，
## 看不见却继续扣钱不行 —— 已登记的有意偏离，§3.264）。
func _排一次手里剑重试() -> void:
	var 计 := get_tree().create_timer(0.9)
	_手里剑重试计时 = 计
	计.timeout.connect(func() -> void:
		if _手里剑重试计时 != 计 or not _手里剑失败继续:
			return
		if not 人物窗口.手里剑弹窗还亮着(self):
			return
		人物窗口.手里剑突破一跳(self))


## 弹窗里那枚勾翻了（页面 → 宿主）。取消勾选 = 原版 `continueToPoHandler:428-434` 的 `clearTimeout`。
func 手里剑失败继续切换(已勾: bool) -> void:
	_手里剑失败继续 = 已勾
	if not 已勾:
		_手里剑重试计时 = null


## 昆虫「自动强化到10并停止」的下一跳 —— 原版 `onStengthResult:588` 排的那发
## `setTimeout(strengthHandler, 500)`；撤表用令牌比对（同 `_排一次手里剑重试:2220`，
## Godot 的 SceneTreeTimer 撤不掉）。
## 落点前置三条：还勾着、弹窗**还亮着**（看不见却继续扣钱不行 —— §3.264 同一条有意偏离）、
## 然后重跑 `人物窗口._昆虫强化提交`，五道闸该停的会在那里停（原版 `strengthHandler:517-521`）。
func _排一次昆虫强化重试() -> void:
	var 计 := get_tree().create_timer(0.5)
	_昆虫强化自动计时 = 计
	计.timeout.connect(func() -> void:
		if _昆虫强化自动计时 != 计 or not bool(_昆虫强化态.get("自动", false)):
			return
		if not 人物窗口.昆虫强化弹窗还亮着(self):
			人物窗口.昆虫自动停(self)
			return
		人物窗口.昆虫强化自动一跳(self))


func _render_pets() -> void:
	宠物窗口.渲染(self)

func _render_legacy() -> void:
	_传承窗口.渲染()

func _render_quests() -> void:
	_社交窗口._render_quests()

## 组队（原版 `TroopWindow2` 515×432）。318 件全烘在场景里（逐件出处 = `真值/窗口/组队.md`），
## 回帧只切 visible + 换文字，**绝不拆页重建**（同一族坑见 #312）。
## 状态挂在 `队伍窗` 的 static 上（= 原版 `DataCenter.partyStatus` + `MyTroopPane` 私有字段）。
func _render_team() -> void:
	队伍窗.渲染(self, 队伍场景)


## 组队邀请/申请**先躺进托盘**（原版 `CueManage.addMsg`），点格才弹确认。
## 托盘节点在 `窗口管理` 下面，名字唯一 ⇒ 这里按名字找它，不新开一条全局引用。
## `是申请=false` ⇒ `类型组队邀请`（去重键 troopId）；`true` ⇒ `类型组队申请`（去重键 partyCharId）。
func _加队伍托盘(是申请: bool, 数据: Dictionary) -> void:
	var 盘 := get_tree().root.find_child("邀请托盘", true, false) as Control
	if 盘 == null:
		return
	## 类型常量在托盘脚本里（`Object.get()` 读不到常量，只能调它的方法）。
	盘.call("加队伍邀请", 是申请, 数据)


## `API.ui.clickCharacter(id)` 的等价件：发 94（CHAR_INFO_REQUEST），**下行 58 到了才开窗**
## （`窗口管理._on_other_char_info:273-281` 那条路）。这里只发上行，不自作聪明直接开空窗。
func _查看角色资料(号: int) -> void:
	if _backend == null or 号 <= 0:
		return
	_backend.call("request_char_full_info", 号)

func _render_friends() -> void:
	_社交窗口._render_friends()

## 家族页（原版 `FamillyWindow` 整块）—— 2026-09-29 换成另一位开发者的版本。
## 装配把宿主传进去：他要拿 `宿主._session` 与 `宿主._overlay`（子窗开到遮罩层上）。
## 未入族时按用户实机口径**直接开列表窗**（说明 §2 ②）。
const 家族页面场景 := preload("res://场景/界面/窗口/家族/家族窗口.tscn")
const 家族子窗壳 := preload("res://脚本/界面/窗口/家族/家族子窗壳.gd")
const 家族令牌填充 := preload("res://脚本/界面/窗口/家族/家族令牌填充.gd")
const 家族贡献填充 := preload("res://脚本/界面/窗口/家族/家族贡献填充.gd")
const 家族创建填充 := preload("res://脚本/界面/窗口/家族/家族创建填充.gd")
const 家族列表填充 := preload("res://脚本/界面/窗口/家族/家族列表填充.gd")
const 家族成员填充 := preload("res://脚本/界面/窗口/家族/家族成员填充.gd")
const 输入确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 好友子窗目录 := "res://场景/界面/窗口/好友/"
const 好友文案表 := preload("res://脚本/界面/窗口/好友/好友文案.gd")


## 家族**创建成功**之后，把创建流程的窗全收掉，只留家族页 —— 用户 2026-10-06 定的口径。
##
## 触发点：服务端对 `1552:1`（创建）的回包 `1552:2:1:<家族id>`
## （`fake_flash_server._handle_multiplayer_family` 的 `action == 1` 成功分支），
## `后端连接._handle_guild_text` 把它解成 `{"action": 2, "success": true, "guild_id": ...}`。
## 失败时服务端回 `1552:2:0:0`，于是 `success` 为假 —— 那种情况**不关窗**，让玩家改名字重试。
##
##
## 另外**退出/被踢**（服务端 `1552:14`）走这里另一条分支：把"没族就没意义"的子窗全收掉，
## 只留家族列表 —— 用户 2026-10-06 的口径，对应原版
## `FamillyManager.destroyWindowOnExitFamilly()`（`FM.as:491-505`）。
func _收到家族状态(状态: Dictionary) -> void:
	var 动作 := int(状态.get("action", -1))
	# `1552:4`（家徽标识帧 = 升级结果 / 改旗名 / 改旗样式都会推它）会改 level/旗名/样式
	# ⇒ 家族页的家徽格、等级值、信息区「家徽等级」行都得跟着换。原版
	# `FamillyManager.onUpgradeFamilly`（FM.as:212-225）→ `famillyWindow.updateJiaHui()`
	# → `updateJiaHuiView()` 就是干这个的，**不等 membership 跳变**（升级前后都在族里）。
	# ⇒ 单独记一个待重画标志，交帧末的 `_家族跳变后收拾` 消费（同款广播时序教训）。
	if 动作 == 4:
		_家族页待重画 = true
	# ⚠️ **收窗与重画一律推到帧末**（`_家族跳变后收拾`）。
	#    原因是时序：`guild_state_received` 是广播，`会话` 与本窗谁先收到**没有保证**；
	#    在本函数里当场读 `会话.guild.joined` 有可能读到的还是旧值 —— 那样
	#    `_render_page()` 会按"未入族"把家族列表窗画回来，而出错那次的连带反应更狠：
	#    收掉列表窗会触发 `_家族子窗已收`，它再判一次"未入族且没窗"就把整扇窗关了。
	#    帧末时两边都已合过状态，判断才是准的（在线门 2026-10-07 抓到过这一条）。
	call_deferred("_家族跳变后收拾")
	if 动作 == 14:
		for 名 in 退族要收的窗:
			家族子窗壳.关掉(self, 名)
		return
	if 动作 != 2 or not bool(状态.get("success", false)):
		return
	# 收不收列表窗**只能靠"创建窗当时在不在"来分**：创建成功与申请加入的回包都是 action 2。
	#    * 创建流程 ⇒ 连列表窗一起收（它是"进族之前"的入口；用户口径：
	#      「家族创建好以后，家族创建相关页面也要关闭，只剩家族页面才对」）。
	#    * 申请加入 ⇒ **不收**。原版入族后是留在列表窗上、把「创建家族/申请加入」变灰
	#      （`FL.as:123-133` 的 `init()`），收掉列表窗等于把那条反馈路径砍了
	#      （`测试/家族申请加入在线回归测试` 2026-10-07 就是这么红的）。
	_创建流程收列表窗 = 家族子窗壳.已开(self, "家族创建窗")
	家族子窗壳.关掉(self, "家族创建窗")


## 家族页「在族 / 未在族」的跳变收尾 —— 也是 `_上次处理时在族` 的**唯一写者**，
## 以及「创建流程收列表窗」的唯一执行者（两者都必须等到帧末、会话状态合上之后）。
##
## 只在**跳变时**动手，不能每帧都跑：家族页上有个「家族列表」钮，在族时玩家可以主动把
## 列表窗开出来（原版 `FamillyManager.showWindow(FAMILLY_LIST_WINDOW)` 也允许），
## 每次状态帧都收就等于那个钮永远点不开。
func _家族跳变后收拾() -> void:
	if _session == null:
		return
	var 在族 := bool(_session.guild.get("joined", false))
	if 在族 != _上次处理时在族:
		_上次处理时在族 = 在族
		if 在族 and _创建流程收列表窗:
			家族子窗壳.关掉(self, "家族列表窗")
		if 已打开():
			_render_page()
	elif _家族页待重画:
		# 升级/改旗（`1552:4`）：家徽数据变了但**不是**入退族 ⇒ 只刷家族页数据、不重建页
		# （重建会丢成员表滚动位，而原版 `updateJiaHui` 也只是在原窗上改六样）。
		_刷家族页数据()
	_家族页待重画 = false
	_创建流程收列表窗 = false


## 家族页**数据**刷新（不重建页）：`1552:4` 到家徽格/等级/信息区就得换。
## 原版 `FamillyWindow.updateJiaHui`（FW.as:320-325）→ `updateJiaHuiView`（:101-112）
## 更新六样：家徽图标(style)、格底色(level 色阶)、悬停文案(该级加成)、旗名、
## 等级标签、信息区「家徽等级」行 —— 这些全在 `家族窗口.刷新()` 里，直接调它即可
## （`家族窗口.gd` 的 `刷新` 本来就是按一份家族字典重画这三块）。
## ⚠️ 只在**当前页就是家族**且窗开着时刷：别的页刷了看不见，还白费。
func _刷家族页数据() -> void:
	if not 已打开() or _current_page != "家族" or _session == null:
		return
	for 子 in _content.get_children():
		if String(子.name) == "原版家族窗口内容" and 子.has_method("刷新"):
			子.call("刷新", _session.guild)
			return


## 退出/被踢之后要收掉的家族子窗。
##
## 原版 `FamillyManager.destroyWindowOnExitFamilly()`（`FM.as:491-505`）关的是
## 成员窗 / 贡献窗 / 升级窗 / 搜索玩家窗 / 铸贡献令牌窗(`ZHU_GONG_LING`) / 家族宠物窗；
## 我们这边同类"没族就没意义"的还有旗帜窗 / 商城窗 / 金币窗，一并收 —— 否则退族后它们
## 仍挂在遮罩上，对着空家族点下去只会一路静默失败（`authoritative_guild` 已被清空）。
## ⚠️ **不含「家族列表窗」**：那扇正是退族后唯一该留着的那扇。
const 退族要收的窗: Array[String] = [
	"家族成员窗", "家族贡献窗", "家族升级窗", "家族搜索窗",
	"家族令牌窗", "家族守卫窗", "家族金币窗", "家族旗帜窗",
]

## 上一次处理家族状态时的"在族"值，用来抓入族/离族的**跳变**（见 `_家族跳变后收拾`）。
## 初值 `false`：登录时若本来就在族里，第一帧摘要会算作一次跳变 —— 那次要做的
## "收列表窗"本来就无窗可收（窗口还没开），重画也无害，所以不需要更精细的初值。
var _上次处理时在族 := false
## 「这次家徽数据变了（`1552:4`），家族页要重画」的待办标志。由 `_收到家族状态` 置位、
## `_家族跳变后收拾` 在帧末消费 —— 同样因为 `guild_state_received` 是广播，
## 当场读 `会话.guild` 可能拿到旧值（升级前后的 level 就是活例）。
var _家族页待重画 := false
## 「这次入族是不是走创建流程」的待办标志。在 `_收到家族状态` 的 action 2 分支里置位
## （判据：家族创建窗当时开着），由 `_家族跳变后收拾` 在帧末消费掉。
## 为什么要过一道手：那一刻 `会话.guild.joined` 可能还没合上，当场收窗会连带触发
## `_家族子窗已收` 把整扇窗关掉（2026-10-07 在线门抓到的）。
var _创建流程收列表窗 := false


## 家族确认弹的正文与确定钮文字（原版 `FamillyPopUpWindow.popUpWindow(param1 文案, …, param4 确定钮文字)`）。
##
## 真值（`en_US$message_properties.as`）：
##   退出 → `FAMILLY_MEMBERS_TUICHU_JIAZU_OK`「你确认要退出家族吗？」+ 确定钮 `FAMILLY_MEMBERS_TUICHU`「退出」
##          （调用点 `FamillyMembersWindow.as:428`）
##   解散 → `FAMILLY_MEMBERS_JIESAN_JIAZU_OK`「你确认要解散家族吗？」+ 确定钮「解散」
## 弹窗**不显示标题、也不显示「记住」复选框**：`FamillyPopUpWindow.updateView` 里
## `_checkBox.visible = true` 只在传了 param7 时才执行，这两条调用都没传；
## `_label` 也没人给它赋文字（截图里那个小窗就只有正文 + 两钮）。
const 确认弹文案 := {
	"家族成员窗:退出家族": ["你确认要退出家族吗？", "退出"],
	"家族成员窗:解散家族": ["你确认要解散家族吗？", "解散"],
	# 原版 `FFW.insertFlagHandler`（`:383-386`）：确认弹正文
	# `FAMILLY_FLAG_WINDOW_XIAOHAO_JINBI`、确定钮 `COMMON_OK`（= "确定"）。
	"家族旗帜窗:安插本族旗帜": ["是否确认消耗1000万家族金币安插族旗？", "确定"],
	# 家族升级：`FamillyUpgradeWindow.clickOkBtnHandler`（FUW.as:41-44）传的两串
	# （`en_US$message_properties.as`）：正文 `FAMILLY_UPGRADE_WINDOW_SHENGJI_OK`
	# 「你确定要升级吗？」、确定钮 `FAMILLY_UPGRADE_WINDOW_SHENGJI`「升级」。
	"家族升级窗:确定": ["你确定要升级吗？", "升级"],
}

## 「安插族旗」确认弹要用的地图 id（原版把 `list.selectedItem.id` 直接闭进回调里，
## 我们走"记下来 - 确认 - 再发"这一套，所以要存一下）。
var _族旗安插图 := 0

## 「开除 / 禅让」确认弹要用的那一行成员（原版把 `list.selectedItem` 闭进回调，
## `fireMember:750-764` / `changeLeader:1260-1263` 都只读它的 id/name）。
## 正文也是**带名字**的（`FAMILLY_MANAGER_BUNENG_QUEREN_KAICHU` + 名 / `NI_QUEDING_CHANRANG`），
## 所以不能像解散/退族那样写死在 `确认弹文案` 里。
var _家族确认对象: Dictionary = {}

## 今日安插族旗的次数上限 = 原版 `FamillyManager.MAX_INSERT_FLAGS`（`FM.as:65`，值 **1**）。
##
## ⚠️ 当前**没有地方在用它**，这是有意的：原版拿它比的是 `myFlagCount`，而那个值的唯一来源
##    是服务端推送 `onBanghuiUpdatePlugFlagCnt`（`Client.as:7792-7795`），本机服务端**从不发**
##    ⇒ 在原版里这道门也永远不会触发。详见 `_家族旗帜动作` 里那段说明。
##    别拿"本族已安插的族旗数"顶替它（2026-10-08 之前就是这么错的，会把安插整个拦死）。
## ⚠️ 另外别跟"本族最多 10 面族旗"混：那是服务端 `handle_map_flag_action` 里的**总数**上限
##    （回包「本族可安插的族旗已达上限。」）。
const 家族今日安插上限 := 1


func _填家族确认弹(动作: String) -> void:
	var 行: Array = 确认弹文案.get(动作, [])
	var 名 := String(_家族确认对象.get("name", ""))
	# 开除 / 禅让的正文**带名字**，不能写死在 `确认弹文案` 里：
	#   `FM.as:750-764` 传 `FAMILLY_MANAGER_BUNENG_QUEREN_KAICHU` + `selectedItem.name`，确定钮 `FAMILLY_MANAGER_KAICHU`；
	#   `FM.as:1260-1263` 传 `CN.replaceString(FAMILLY_MANAGER_NI_QUEDING_CHANRANG, name)`，确定钮 `FAMILLY_MANAGER_CHANRANG`。
	if 行.size() < 2:
		match 动作:
			"家族成员窗:开除":
				行 = ["你确认要开除玩家：%s" % 名, "开除"]
			"家族成员窗:禅让":
				行 = ["你确定要禅让给%s吗？" % 名, "禅让"]
			_:
				return
	var 窗 := 家族子窗壳.取内容(self, "家族确认弹")
	if 窗 == null:
		return
	var 正文 := 窗.get_node_or_null("文本正文") as RichTextLabel
	if 正文 != null:
		正文.text = String(行[0])
	var 标题 := 窗.get_node_or_null("标题提示") as Label
	if 标题 != null:
		标题.text = ""
	var 勾 := 窗.get_node_or_null("复选记住") as Control
	if 勾 != null:
		勾.visible = false
	var 钮 := 窗.get_node_or_null("钮确定") as Control
	if 钮 != null:
		var 字 := 钮.get_node_or_null("Label") as Label
		if 字 != null:
			字.text = String(行[1])


func _render_guild() -> void:
	# 没入族时**只开家族列表窗，家族主窗一律不出现**。
	#
	# 真值：原版 `FamillyManager.showMainWindow()`（`FM.as:1222-1239`）是**二选一**：
	#   `myFamillyInfo.id != 0`（在族）→ `FAMILLY_UI_WINDOW`（家族主窗）
	#   否则                        → `FAMILLY_LIST_WINDOW`（**只有列表窗**）
	# 家族页那套（公告/成员/族徽）本来就是"有族才有意义"的，没族时不该在场。
	#
	# ⚠️ 上一版只做了"不往 `页面容器` 里塞家族页"，**漏了窗壳自己那层外框**：
	#    「家族主窗」在我们这儿 = 这层**通用窗壳**（`功能窗口`，尺寸表「家族」617×390）。
	#    于是未入族时屏上是「一个空框、标题写着家族」+ 小一圈的列表窗浮在它上面 ——
	#    用户 2026-10-06 报的「家族页还在」就是这个空框。
	#    取证器：`开发工具/探家族入口.gd`（未入族 → `主窗口.visible=true`、`页面容器=[]`）。
	#    显隐本身在 `_render_page` 里统一归一化（见 `_该显示家族主窗`），此处只管内容。
	if not bool(_session.guild.get("joined", false)):
		# `独立=true`（最后一个实参）：这时主窗被藏了，全屏只有这一扇窗，而子窗窗皮的
		# 内部 alpha 只有 0.843，单层会透出游戏画面 ⇒ 自带一层不透明底。
		# 详见 `家族子窗壳` 的 `独立底名`。
		家族子窗壳.只在未开时开(self, "家族列表窗", "家族列表", true, 家族子窗壳.子窗目录, true)
		return
	var 页面 := 家族页面场景.instantiate() as Control
	_content.add_child(页面)
	# ⚠️ 场景的**根节点本身**就叫「原版家族窗口内容」（不是它的子节点）——装配直接调根。
	页面.call("装配", self)


## 家族主窗（= 本窗壳的 `主窗口`）这一刻该不该显示。
##
## 判据只有原版那一条：在族才显示（`FM.as:1222-1239`）。非家族页恒 true ——
## 本实例若走老的"单窗口换页"用法，从家族页切走之后窗壳必须回来。
func _该显示家族主窗() -> bool:
	if _current_page != "家族":
		return true
	if _session == null:
		return true
	return bool(_session.guild.get("joined", false))


## 家族主窗显隐。
##
## ⚠️ 全工程只有本文件读 `主窗口`（三处 `get_node_or_null`），没有第二处写它的
##    `visible` ⇒ 在这里独占，不会和别处打架。
## ⚠️ **别顺手改 `遮罩` 的可见性**：家族列表窗是挂在 `遮罩` 上的
##    （`家族子窗壳.切换` 取 `宿主._overlay`），遮罩一藏列表窗跟着没了。
##    遮罩归 `打开()`/`close()` 管，本函数只管它下面那个 `主窗口`。
func _设家族主窗可见(可见: bool) -> void:
	var 主窗 := get_node_or_null("遮罩/主窗口") as Control
	if 主窗 != null:
		主窗.visible = 可见
	# 主窗一藏，家族列表窗底下就没有不透明的东西垫着了 ⇒ 它得自带一层底。
	# ⚠️ 同步（而不是只在开窗那一刻给）是必需的：退族后列表窗是**已经开着**的那扇
	#    （`退族要收的窗` 特意不收它），此刻主窗才转为隐藏，开窗时的实参早就过期了。
	家族子窗壳.设独立底(self, "家族列表窗", not 可见)


## `家族子窗壳.关掉` 的回头通知：我这宿主这边刚收掉一扇家族子窗。
##
## 为什么需要它：未入族时家族主窗是不显示的（`_该显示家族主窗`），屏上只剩 `遮罩`（一张接点击
## 但不画东西的暗层）+ 家族列表窗。玩家点列表窗自己的关钮把列表窗收掉之后，
## **遮罩还在** —— 画面看着是正常游戏，可点哪儿都没反应，是个"看不见的死屏"。
## ⇒ 未入族 + 家族列表窗也不在了 ⇒ 整扇窗壳一起退场。
##
## ⚠️ 判定本身**必须延到帧末**（`_家族子窗已收_判`）：这一刻 `会话.guild` 可能还没合上
##    （`guild_state_received` 是广播，订阅者先后不保证），当场按"未入族"判会在入族/退族
##    的当口误关整扇窗。帧末再判一次把两类误判都堵住：
##      * 创建成功那一刻 → `joined` 已为 true ⇒ 不关；
##      * 退族那一刻     → `joined` 已为 false，但列表窗马上会被 `_render_guild` 开出来 ⇒ 已开 ⇒ 不关。
func _家族子窗已收(_窗名: String) -> void:
	call_deferred("_家族子窗已收_判")


func _家族子窗已收_判() -> void:
	if _current_page != "家族" or _session == null:
		return
	if bool(_session.guild.get("joined", false)):
		return
	if 家族子窗壳.已开(self, "家族列表窗"):
		return
	close()


func _render_shop() -> void:
	_社交窗口._render_shop()


func _render_settings() -> void:
	_系统窗口._render_settings()


## 快捷键设置窗（原版 `KeyboardFrame` 765×455，另一位开发者那一版）。
## 它是**开关式独立窗**（原版设置页点「快速键」走 `UM2:3133-3146 setKeyboardWindowvisible`，
## 不是设置页内换页）—— 页面里的「快速键」页签自己会 `request_feature("快捷键")`，
## 落到这里由 `窗口管理` 打开/收起本页。
## 外框规格（765×455、整框、无底图）在 `数据/界面/窗口尺寸.json` 的「快捷键」条目里。
const 快捷键窗场景 := preload("res://场景/界面/窗口/设置/快捷键窗.tscn")
const 原版服务窗 := preload("res://脚本/界面/窗口/原版服务窗.gd")
const 忍具兑换场景 := preload("res://场景/界面/窗口/忍具兑换/忍具兑换窗.tscn")
const 卡片套册窗 := preload("res://脚本/界面/窗口/卡片套册窗.gd")
const 卡片套册场景 := preload("res://场景/界面/窗口/卡片套册/卡片套册窗.tscn")
const 兑换商店窗 := preload("res://脚本/界面/窗口/兑换商店窗.gd")
const 兑换商店场景 := preload("res://场景/界面/窗口/兑换商店/兑换商店窗.tscn")
const 变身卡互换窗 := preload("res://脚本/界面/窗口/变身卡互换窗.gd")
const 变身卡互换场景 := preload("res://场景/界面/窗口/变身卡互换/变身卡属性互换窗.tscn")
const 变身卡特性互换场景 := preload("res://场景/界面/窗口/变身卡互换/变身卡特性互换窗.tscn")
const 日环任务窗 := preload("res://脚本/界面/窗口/日环任务窗.gd")
const 日环任务场景 := preload("res://场景/界面/窗口/环任务/日环任务窗.tscn")
const 周试炼任务窗 := preload("res://脚本/界面/窗口/周试炼任务窗.gd")
const 周试炼任务场景 := preload("res://场景/界面/窗口/环任务/周试炼任务窗.tscn")
const 勾玉炼制窗 := preload("res://脚本/界面/窗口/勾玉炼制窗.gd")
const 勾玉炼制场景 := preload("res://场景/界面/窗口/勾玉炼制/勾玉炼制窗.tscn")
const 护送任务窗 := preload("res://脚本/界面/窗口/护送任务窗.gd")
const 护送任务场景 := preload("res://场景/界面/窗口/护送/护送任务窗.tscn")
const 护送提示场景 := preload("res://场景/界面/窗口/护送/护送提示窗.tscn")
const 竞技场窗 := preload("res://脚本/界面/窗口/竞技场窗.gd")
const 队伍窗 := preload("res://脚本/界面/窗口/组队/队伍窗.gd")
const 队伍场景 := preload("res://场景/界面/窗口/组队/队伍窗.tscn")
const 竞技场场景 := preload("res://场景/界面/窗口/竞技场/竞技场窗.tscn")
const 竞技场英雄榜窗 := preload("res://脚本/界面/窗口/竞技场英雄榜窗.gd")
const 竞技场英雄榜场景 := preload("res://场景/界面/窗口/竞技场/竞技场英雄榜.tscn")
const 跨服频道窗 := preload("res://脚本/界面/窗口/跨服频道窗.gd")
const 跨服频道场景 := preload("res://场景/界面/窗口/跨服/跨服频道窗.tscn")
const 生命料理窗 := preload("res://脚本/界面/窗口/生命料理窗.gd")
const 生命料理场景 := preload("res://场景/界面/窗口/生命料理/生命料理窗.tscn")
const 洗点窗 := preload("res://脚本/界面/窗口/洗点窗.gd")
const 洗点场景 := preload("res://场景/界面/窗口/洗点/洗点窗.tscn")
const 洗点确认场景 := preload("res://场景/界面/窗口/洗点/洗点确认窗.tscn")
const 双修邀请窗 := preload("res://脚本/界面/窗口/双修/双修邀请窗.gd")
const 双修邀请场景 := preload("res://场景/界面/窗口/双修/双修邀请窗.tscn")
const 家族邀请窗 := preload("res://脚本/界面/窗口/家族/家族邀请窗.gd")
const 家族邀请场景 := preload("res://场景/界面/窗口/家族/家族邀请窗.tscn")
const 求婚窗 := preload("res://脚本/界面/窗口/家族/求婚窗.gd")
const 求婚场景 := preload("res://场景/界面/窗口/家族/求婚窗.tscn")
const 赠花窗 := preload("res://脚本/界面/窗口/家族/赠花窗.gd")
const 赠花场景 := preload("res://场景/界面/窗口/家族/赠花窗.tscn")
const 徽章打造窗 := preload("res://脚本/界面/窗口/徽章打造窗.gd")
const 徽章打造场景 := preload("res://场景/界面/窗口/徽章打造/徽章打造窗.tscn")
const 摊位窗 := preload("res://脚本/界面/窗口/摆摊/摊位窗.gd")
const 摊位场景 := preload("res://场景/界面/窗口/摆摊/摊位窗.tscn")
## 摊位两档的伴随小窗（`SuiShenPet` / `UpShelfMoneyWindow`）。**都是代码现搭页**，没有场景。
const 附身宠物窗 := preload("res://脚本/界面/窗口/附身宠物窗.gd")
const 货币上架窗 := preload("res://脚本/界面/窗口/摆摊/货币上架窗.gd")
const 摊位列表窗 := preload("res://脚本/界面/窗口/摆摊/摊位列表窗.gd")
const 摊位购买窗 := preload("res://脚本/界面/窗口/摆摊/购买确认窗.gd")
const 摊位购买场景 := preload("res://场景/界面/窗口/摆摊/购买确认窗.tscn")
const 交易窗 := preload("res://脚本/界面/窗口/交易/交易窗.gd")
const 交易场景 := preload("res://场景/界面/窗口/交易/交易窗.tscn")
## 二级密码六窗（`controls/twoPassword/*`）。**没有场景**：整页就是一张几何表，
## 六扇的矩形全抄在 `二级密码窗.gd` 的 `窗件*` 六张表里（口径同 摊位列表/神秘商店）。
const 二级密码窗 := preload("res://脚本/界面/窗口/二级密码/二级密码窗.gd")
## 神秘商店（`controls/mystery/MysteryWindow`，275×394）。数据 = 服务端那一帧 `324:`。
const 神秘商店窗 := preload("res://脚本/界面/窗口/神秘商店/神秘商店窗.gd")
const 神秘商店场景 := preload("res://场景/界面/窗口/神秘商店/神秘商店窗.tscn")
const 心法窗 := preload("res://脚本/界面/窗口/心法窗.gd")
const 心法场景 := preload("res://场景/界面/窗口/心法/心法窗.tscn")
const 十拳剑兑换场景 := preload("res://场景/界面/窗口/十拳剑兑换/十拳剑兑换窗.tscn")
const 扩容需求 := preload("res://脚本/界面/扩容需求.gd")
## 「破碎装备修复」窗（`EquipRepairWindow`，360×407）。
const 装备修复场景 := preload("res://场景/界面/窗口/装备修复/装备修复窗.tscn")
const 修复放入格组件 := preload("res://脚本/界面/组件/修复放入格.gd")
## 公共「放入选择」弹层（2026-11-08）：所有"放入"钮都走它，见 `放入选择器.gd` 文件头。
const 放入选择器 := preload("res://脚本/界面/组件/放入选择器.gd")
## 「梦幻属性符」窗（`MengHuanPropResetWindow`，360×432）。
## 入口 = 背包双击/使用梦幻属性符（`ItemWindow2.as:953-967`）；**连背包成对开**。
const 梦幻属性符场景 := preload("res://场景/界面/窗口/梦幻属性符/梦幻属性符窗.tscn")
const 梦幻放入格组件 := preload("res://脚本/界面/组件/梦幻放入格.gd")
## 「橙装打造」窗（`YellowEquipLianZhiWindow`，376×407）：橙装打造 / 橙装精炼 两页签。
## 入口 = 背包双击/使用「传说装备打造石」/「传说精炼石」（`ItemWindow2.as:979-988`）；
## **连背包成对开**（`UIMain2.as:3961-3981` 的 `centerTwoWindow`，已登记 `窗口管理.伴随背包`）。
const 橙装打造场景 := preload("res://场景/界面/窗口/橙装打造/橙装打造窗.tscn")
## 商城购买弹窗（`BuyEqpWindow.as`）。商城页里本来就 instance 了一份；
## 这条 const 是给"**不在商城页时**也要弹它"那条路用的（见 `打开商城购买窗`）。
const 商城购买窗场景 := preload("res://场景/界面/组件/商城购买窗.tscn")
## 购买窗那层**整舞台遮罩**的节点名（`_overlay` 下；见 `_前置购买窗遮罩`）。
const 购买窗遮罩名 := "购买窗遮罩"
## 购买窗被抬到的舞台层（根下 CanvasLayer，见 `_抬购买窗`）。
## 层号必须**高于**根下「屏幕弹窗层」（120，`手里剑页._屏幕弹窗层` / `突破瓶颈按钮._屏幕弹窗层`）：
## 原版购买窗走 `PopUpMananger.centerWindow`（`UIMain2.addBuyWindow:2906-2913`），挂在所有窗口与
## 屏幕级弹窗之上；我们平时让它住宿主 `遮罩`（= 宿主 CanvasLayer 111..118）⇒ 手里剑突破弹窗
## 搬到 120 并铺整屏暗幕时会把购买窗整个盖住（2026-11-01 用户报修）。
const 购买窗舞台层名 := "购买窗舞台层"
const 购买窗舞台层号 := 130
## 一键出售弹窗（`QuickSaleWindow.as`，410×300）。商店页那枚「一键出售」弹的是**它**，
## 不是直接发包 —— 见 `_quick_sell_items`。遮罩与购买窗共用 `购买窗遮罩名`（同一时刻只会开着两枚之一）。
const 一键出售窗场景 := preload("res://场景/界面/组件/一键出售窗.tscn")
## 装备修理窗（`MendEtcWindow.as`，295×250）。商店页那枚「修理」弹的是**它**，
## 不是直接发包 —— 见 `_repair_equipment`。遮罩与购买窗共用 `购买窗遮罩名`。
const 修理窗场景 := preload("res://场景/界面/组件/修理窗.tscn")
## 自选礼包选择窗（`ChoiceLibaoWindow.as`，宽 240、高按候选行数现算）。
## ⚠️ **没有 .tscn** —— 原版是纯代码建的（`createUI()` 全程 new + 写坐标），
##    我们也照它把版式写在脚本里，所以这里拿到的是**脚本**，实例化用 `.new()`。
const 自选礼包窗脚本 := preload("res://脚本/界面/窗口/自选礼包窗.gd")
## 选择窗当前对应背包的**格位**（1 基；-1 = 没开着）。存窗口上而不是存进窗：
## 窗只管"选了第几格"，吃哪一格是协议层的事（同 `#16`：按 id 反查会吃错摞）。
var _自选礼包格位 := -1
## 「火影有礼」详情窗（`SelectGiftWindow.as`，202 宽；高按 12/16 格与能不能开现算）。
## 入口同 `自选礼包窗` 一样是纯脚本建的，没有 .tscn。
const 礼包详情窗脚本 := preload("res://脚本/界面/窗口/礼包详情窗.gd")
var _礼包详情格位 := -1
## 宠物技能重置窗（`PetSkillResetWindow.as`，444×423，纯脚本建、无 .tscn）。
## 入口：双击/使用「神奇技能符」15018001（`use_type == "jineng"`，见 `游戏会话.是技能符`）。
const 宠物技能替换窗脚本 := preload("res://脚本/界面/窗口/宠物技能替换窗.gd")
var _技能符格位 := -1
## 成就福袋窗（`SuccessWindow.as`，274×306，纯脚本建、无 .tscn）。
## ⚠️ 这扇窗**不是点击开的**，是 `1289:1` 回帧开的（`Client.onShowFudaiInfo:6582-6607`）——
##    点击只发 `request_fudai_open(格位)`；见 `_开福袋` 与 `_收到福袋帧`。
const 福袋窗脚本 := preload("res://脚本/界面/窗口/福袋窗.gd")
## 发请求那一刻记住的**福袋编号**（`SuccessManager.currItemID` 的对应物）：
## 服务端在 action 1 里就扣件（`fake_flash_server.py:31903` `_consume_bag_slot`），
## 回帧到达时那一格可能已经空了 ⇒ 标题（`StringTool.getItemString`）与
## 「还抽不抽下一只」（`isBagExistItem`）都不能再从格位现取。
## 格位本身**不留**：三条上行里只有 `1286:1:<格位>` 用它，而那一刻手上有；2/3 不带参。
var _福袋物品id := ""


func _render_hotkeys() -> void:
	var page := _instantiate_page(快捷键窗场景)
	page.call("装配", self)
	# 页面只把动作交回来（`快捷键窗|确定` / `|方案N` / `|保存方案`），**不自己发协议**
	# —— 改键的真实落盘仍走既有的 `快捷键.应用单个`，见 `_show_guild_action` 里
	#     `快捷键窗:` 那个分支（本轮的合并只接 UI，协议一条没动）。

func _render_retreat() -> void:
	_系统窗口._render_retreat()

func _render_retreat_claim() -> void:
	_系统窗口._render_retreat_claim()

func _render_auto_combat() -> void:
	_系统窗口._render_auto_combat()

func _render_copy() -> void:
	_系统窗口._render_copy()

func _render_map_info() -> void:
	_系统窗口._render_map_info()

func _render_ranking() -> void:
	_系统窗口._render_ranking()

func _render_exchange() -> void:
	_系统窗口._render_exchange()

func _render_activity() -> void:
	_活动窗口._render_activity()

## 活跃度（原版 `ActivityTaskWindow`，小地图上的「活跃度」钮）。
## 版式全烘在 场景/界面/窗口/活跃度/活跃度窗口.tscn 里，控制器只填运行期的数。
func _render_activity_task() -> void:
	活跃度窗口.渲染(self)

func _render_info() -> void:
	_活动窗口._render_info()


func _render_check_in() -> void:
	_活动窗口._render_check_in()

func _render_benefit() -> void:
	_活动窗口._render_benefit()

func _render_treasure() -> void:
	_活动窗口._render_treasure()

## 宝石工艺窗（原版 `StoneWindow`，332×399 三页签：合成 / 镶嵌摘除 / 幸运合成）。
## 页面名沿用 "挖矿"（`窗口尺寸.json` 的 as3 字段就是 StoneWindow；小地图「宝石工艺钮」开它，
## 对位原版 `SmallMapButtonBox:316` `showStoneWindow()`）。
## 本轮（2026-10-03）**合成页**按 `StoneCompositeWindow.as` 实装到能走真协议；
## 镶嵌摘除页仍是原版那张纯说明（真镶嵌在装备菜单那条「宝石镶嵌」独立窗里，§3.85）；
## **幸运合成页 2026-10-11 §3.100 也实装了** —— 原先它只是占位（那会儿服务端
## `ItemChangeAction` 枚举里确实没有 31，没有真值可钉）；现在服务端补了
## `MERGE_STONE_LUCKY = 31` 与处理器，这一页是真的面板 + 真协议（见 `_配置幸运合成页`）。
func _render_mining() -> void:
	var page := _instantiate_page(宝石工艺页面场景)
	# —— 三页签（`StoneWindow.selectedBtnHandler:65-98`：tab1 藏「合成」按钮，tab0/2 都显）——
	var 页签表 := ["宝石合成", "宝石镶嵌与摘除", "宝石幸运合成"]
	for i in 页签表.size():
		var 钮 := page.get_node("分页/%s" % 页签表[i]) as Button
		_apply_tab_skin(钮)
		选页签(钮, _stone_tab == i)
		钮.pressed.connect(_set_stone_tab.bind(i))
	page.get_node("内容框/宝石合成页").visible = _stone_tab == 0
	page.get_node("内容框/镶嵌摘除页").visible = _stone_tab == 1
	page.get_node("内容框/幸运合成页").visible = _stone_tab == 2
	_configure_original_panel(page.get_node("内容框") as Panel, true)
	_configure_original_panel(page.get_node("内容框/宝石合成页/放入宝石区") as Panel)
	_configure_original_panel(page.get_node("内容框/宝石合成页/结果说明区") as Panel)
	_configure_original_panel(page.get_node("内容框/镶嵌摘除页/成就说明区") as Panel)
	# 「合成结果」竖排抬头 + 三格橙标题（AS3：12px 粗体 #ff9100，`EQUIP_STONE_TEXTS_1..4`）
	_configure_label(page.get_node("内容框/宝石合成页/合成结果") as Label, 12, Color("#ff9100"))
	for 名 in ["成功", "退还", "剩余"]:
		var 格 := page.get_node("内容框/宝石合成页/结果格/%s" % 名) as Control
		_configure_label(格.get_node("标签") as Label, 12, Color("#ff9100"))
		(格.get_node("物品格/底") as TextureRect).texture = load(ORIGINAL_SLOT) as Texture2D
	# —— 正操作的那一摞：**每次渲染按格位现读**（`itemDatachanged:335-352`）——
	#   格上没件了 / 换成了别的 id → 对位 `backItemToEquip`：放置态、结果三格一起清。
	var 条: Dictionary = _宝石合成现读()
	# 放入/取出的那颗宝石（`原宝石格`，`StoneCompositeWindow._itemDropBox.itemCell`）
	var 源格 := page.get_node("内容框/宝石合成页/放入宝石区/原宝石格") as Button
	源格.theme_type_variation = WINDOW_SKIN.皮肤表.变体_物品格按钮
	源格.focus_mode = Control.FOCUS_NONE
	源格.格子归属 = "宝石放入"          # 认领落点（`可拖拽格._can_drop_data` 要求非空）
	源格.可拖拽 = false                  # 原版这格只接不吐
	源格.物品id = "" if 条.is_empty() else String(条.get("id", ""))
	源格.icon = _物品图标(String(源格.物品id))
	_摆数量角标(源格.get_node("数量") as Label, int(条.get("quantity", 0)) if not 条.is_empty() else 0)
	# 页面每次渲染都是**新建**的（`_instantiate_page`），理论上没有旧连接；
	# 仍按镶嵌窗那个写法先清一遍再连（重入/复用场景时不至于 "already connected" 刷屏）。
	for 连 in 源格.请求放入.get_connections():
		源格.请求放入.disconnect(连["callable"])
	源格.请求放入.connect(_宝石工艺_放入)
	# 产物预览（`resultCell` = `createSingleItem(nextId)`，`validateItem:199-200`；没放就空）
	var 预览 := page.get_node("内容框/宝石合成页/放入宝石区/合成宝石格/图标") as TextureRect
	预览.texture = _物品图标(_宝石合成下一颗(条))
	(page.get_node("内容框/宝石合成页/放入宝石区/合成宝石格/底") as TextureRect).texture = load(ORIGINAL_SLOT) as Texture2D
	# 放入宝石 / 取出宝石（`EQUIP_STONE_DROP_ITEM_BTN_NAMES_1/2`；放了那颗就换「取出宝石」）
	var 放钮 := page.get_node("内容框/宝石合成页/放入宝石区/放入宝石") as Button
	_configure_standard_button(放钮)
	放钮.text = "取出宝石" if not 条.is_empty() else "放入宝石"
	放钮.pressed.connect(_宝石工艺_按放入钮.bind(page))
	# 结果说明（`_resultTextField` = `EQUIP_STRENGTH_DESC_TEMPLATE_0` + COMPOSITE_DESCS_3 红字，
	# 数字金币不够时整串换红，`updateDescription:86-109`）
	_填宝石合成说明(page, 条)
	# 成功/退还/剩余三格（`operationResultHandler:132-171`：只在计数>0 时摆那一颗）
	var 果 := _宝石合成结果
	for 档 in [["成功", "success_count", "success_item_id"], ["退还", "failed_count", "failed_item_id"], ["剩余", "left_count", "left_item_id"]]:
		var 格 := page.get_node("内容框/宝石合成页/结果格/%s" % 档[0]) as Control
		var 数 := int(果.get(档[1], 0))
		(格.get_node("物品格/图标") as TextureRect).texture = _物品图标(str(int(果.get(档[2], 0)))) if 数 > 0 else null
		_摆数量角标(格.get_node("物品格/数量") as Label, 数)
	# 开始合成（`upgradeBtn`，文案 = `EQUIP_STRENGTH_STRENGTH_BTN_NAMES[4]`「开始合成」；
	# tab1 镶嵌摘除页**没有提交**，按钮藏起来）
	var 成钮 := page.get_node("开始合成") as Button
	_configure_standard_button(成钮)
	成钮.visible = _stone_tab != 1
	成钮.pressed.connect(_宝石工艺_提交)
	# 幸运合成页（tab2）**自己一套版式**（§3.100 实装）：与合成页共用放进态与 1042 回包，
	# 只是多一行幸运符、结果说明换模板、提交走动作 31。可见性上面已经切好，这里按需配置。
	if _stone_tab == 2:
		_配置幸运合成页(page.get_node("内容框/幸运合成页") as Control)

## 现读合成页那一摞（对位 `itemDatachanged`）。格上没件/换件 → 清放置态（不关窗）。
func _宝石合成现读() -> Dictionary:
	if _宝石合成格 <= 0:
		return {}
	var 条: Dictionary = _session._占用条(_session.inventory, _宝石合成格)
	if 条.is_empty() or String(条.get("id", "")) != _宝石合成id:
		_宝石合成格 = 0
		_宝石合成id = ""
		_宝石合成结果 = {}
		return {}
	return 条

## 放进来的那颗 → 合成产物那颗的八位 id（`inlay.next`；`stone_level`/`stone_next` 两列
## 由 `开发工具/导出宝石合成链.py` 从服务端 catalog 补进 `数据/物品.json`）。空串 = 没放/满级。
func _宝石合成下一颗(条: Dictionary) -> String:
	if 条.is_empty():
		return ""
	var 下 := int(GAME_DATA.item(String(条.get("id", ""))).get("stone_next", 0))
	if 下 <= 0:
		return ""
	return str(下).pad_zeros(8)

## 合成到下一级那一次的 `{needMoney, prob}`（`装备打造表.取宝石合成`，键取**目标级**）。
## ⚠️ 表里**没有的行返回空字典 → 按 0 处理**（服务端同口径：勾玉 11..15 级、以及任何
## 没配到的目标级都是 `merge_config=None` → prob 0）；别拿 100% 兜底骗玩家。
func _宝石合成档(条: Dictionary) -> Dictionary:
	if 条.is_empty():
		return {}
	var 级 := int(GAME_DATA.item(String(条.get("id", ""))).get("stone_level", 0))
	if 级 <= 0:
		return {}
	return 装备打造表.取宝石合成(级 + 1)

## 这一次「开始合成」要花多少金币。原版 `updateDescription:86-90`：
## `needMoney = merge.level{目标级}.needMoney`，**件数≥3 才乘批数**（`× int(件数/3)`），
## 不足 3 颗就是单批价（反正提交闸会先拦下）。显示与提交闸**共用这一个算式**
## ——同一字段两条路径口径必须一致（§3.82 canTrade 那条教训）。
func _宝石合成花费(条: Dictionary) -> int:
	var 单批 := int(_宝石合成档(条).get("needMoney", 0))
	var 件数 := int(条.get("quantity", 0))
	if 件数 >= 3:
		return 单批 * int(件数 / 3)
	return 单批

## `_resultTextField`：`EQUIP_STRENGTH_DESC_TEMPLATE_0` + `<br/>` + `EQUIP_STONE_COMPOSITE_DESCS_3`。
## 金币数在**不够付**时换红（`updateDescription:95`），没放东西显示 0/0。
## ⚠️ 原版还有「`enableMergeStone`（8~10 级合成 buff，15039001 那类）且 stoneLevel>6 → 几率 100」
##   的分支（`:98-101`）—— 那是 buff 旗标（UIMain2 挂/摘 buff 时置位），我们没建模 buff 期，
##   默认 false（=几率按表），已登记欠账。
func _填宝石合成说明(page: Control, 条: Dictionary) -> void:
	var 说明 := page.get_node("内容框/宝石合成页/结果说明区/结果说明") as RichTextLabel
	if 条.is_empty():
		说明.text = "[color=#ffffff]本次操作消耗金币：0\n本次操作成功几率：0%\n注意：本处合成为全部合成\n如果你不需要一次性合成这麽多\n请先将宝石拆分后再放入合成框[/color]"
		return
	var 花 := _宝石合成花费(条)
	var 率 := int(_宝石合成档(条).get("prob", 0))
	var 金币 := int(_session.player_stats.get("gold", 0))
	var 钱文本 := str(花)
	if 金币 < 花:
		钱文本 = "[color=#ff0000]%s[/color]" % 钱文本   # 红字照 `#ff0000`，AS3 同款
	说明.text = "[color=#ffffff]本次操作消耗金币：%s\n本次操作成功几率：%d%%\n[/color][color=#ff0000]注意：本处合成为全部合成\n如果你不需要一次性合成这麽多\n请先将宝石拆分后再放入合成框[/color]" % [钱文本, 率]

## 幸运合成页的结果说明：原版 `updateDescription()`（`StoneLuckyCompositeWindow.as:380-412`）——
## `EQUIP_STRENGTH_DESC_TEMPLATE_0` 两行，￥→**这一次**的金币（不够标红），$→成功率
## `min(100, 基础几率 + 张数 × LUCKY_RATIO_PER_CHARM)`。
## ⚠️ 与合成页那句"**全部合成**"的注意**不同** —— 幸运合成**一次只吃 3 颗**
## （原版 `submitToHandle` 判钱也只按单次 `_needMoney`），所以这里**没有**"请先拆分"那两行。
## 没放宝石时两行都是 0（AS3 的 else 分支）。
func _填幸运合成说明(页: Control, 条: Dictionary, 张数: int) -> void:
	var 说明 := 页.get_node("结果说明区/结果说明") as RichTextLabel
	var 花 := 0
	var 率 := 0
	if not 条.is_empty():
		花 = int(_宝石合成档(条).get("needMoney", 0))
		率 = mini(100, int(_宝石合成档(条).get("prob", 0)) + 张数 * 装备打造表.宝石幸运符每张加成)
	var 钱文本 := str(花)
	if int(_session.player_stats.get("gold", 0)) < 花:
		钱文本 = "[color=#ff0000]%s[/color]" % 钱文本
	说明.text = "[color=#ffffff]本次操作消耗金币：%s\n本次操作成功几率：%d%%[/color]" % [钱文本, 率]


## SimpleItemCell 的数量角标（`itemCell.label`）——几何/字号同背包格（`ItemWindowCell.as:54-62`，
## 右下、12 号、右对齐，§3.84/§3.16 那套换算），这里只是格子里那颗宝石的件数。
func _摆数量角标(量: Label, 件数: int) -> void:
	if 量 == null:
		return
	量.text = "" if 件数 <= 0 else str(件数)
	_configure_label(量, 12, Color.WHITE)

func _物品图标(物品id: String) -> Texture2D:
	if 物品id.is_empty():
		return null
	var 图标 := String(GAME_DATA.item(物品id).get("icon", ""))
	if 图标.is_empty() or not ResourceLoader.exists(图标):
		return null
	return load(图标) as Texture2D

## 落上一颗宝石（`dropItemHandler:173-179` → `validateItem:181-212`）。
## 非宝石在组件的 `_can_drop_data` 就挡了；满级那颗**只弹话不收**（原版 `MDialog(IS_STONE_LEVEL_MAX)`）。
func _宝石工艺_放入(宝石格: int) -> void:
	var 条: Dictionary = _session._占用条(_session.inventory, 宝石格)
	if 条.is_empty():
		return
	var 物品id := String(条.get("id", ""))
	if not 宝石孔格脚本.是宝石(物品id):
		_session.notification_requested.emit("对不起，该物品不是宝石")
		return
	if int(GAME_DATA.item(物品id).get("stone_next", 0)) <= 0:
		_session.notification_requested.emit("该宝石已经是最高等级！")
		return
	_宝石合成格 = 宝石格
	_宝石合成id = 物品id
	_宝石合成结果 = {}       # 换一颗就把上一次的三格结果清掉（原版 dropItemHandler 同）
	_refresh_current()

## 「放入宝石 / 取出宝石」那颗钮（`clickDropBtnHandler:113-130`）。
## 已放 → `backItemToEquip`+`showView`（清放置、清三格、按钮换回「放入宝石」）；
## 没放 → 原版是切"上架光标"等玩家点背包那格 —— 本工程走公共「放入选择」弹层（2026-11-08）。
## 满级那颗照样**进单**，选中后由 `_宝石工艺_放入` 弹原版那句（与光标点错件同效）。
func _宝石工艺_按放入钮(页: Control) -> void:
	if _宝石合成格 > 0:
		_宝石合成格 = 0
		_宝石合成id = ""
		_宝石合成结果 = {}
		_refresh_current()
		return
	var 清单 := 放入选择器.背包候选(_session,
			func(条: Dictionary) -> bool: return 宝石孔格脚本.是宝石(String(条.get("id", ""))))
	if 清单.is_empty():
		_session.notification_requested.emit("背包里没有可放入的宝石")
		return
	放入选择器.弹(页, 清单,
			func(行: Dictionary) -> void: _宝石工艺_放入(int(行.get("格", 0))))

## 「开始合成」（`submitToHandle:354-375`，**判序照原版**）：
##   没放 → 「请放入宝石！」；件数<3 → 「对不起，宝石合成需要三颗以上的宝石！」；
##   金币<needMoney → 「很抱歉，你的金币不够」；都过了才发 `requestMergeStone(宝石格)`。
## 幸运页（tab 2）走的是另一条 `requestMergeStoneLucky(31)`，服务端没有 → 诚实拒。
## 「幸运合成」页（原版 `StoneLuckyCompositeWindow`，`ITEM_CHANGE` 子命令 **31**）。
## 与「宝石合成页」**同族**：放进态（`_宝石合成格/_宝石合成id`）与 1042 回包（`_宝石合成结果`）
## 都**共用** —— 两页从不同时可见，各建一套反而会分叉。差别只有三处：
##   ① 多一行**幸运符**（格 + 勾选 + 张数下拉 +「张」）；② 结果说明换 `EQUIP_STRENGTH_DESC_TEMPLATE_0`
##   （只有金币/几率两行，**没有**合成页那句"全部合成"的红字注意）；③ 提交走动作 **31**。
## 版式坐标出处 `StoneLuckyCompositeWindow.createChildren()`（`:74-170`），见场景节点注释。
func _配置幸运合成页(页: Control) -> void:
	_configure_original_panel(页.get_node("放入宝石区") as Panel)
	_configure_original_panel(页.get_node("结果说明区") as Panel)
	# 三格标题（原版 12px 粗体 #ff9100；格子的「标签」与「数量」都在里面）
	_configure_label(页.get_node("合成结果") as Label, 12, Color("#ff9100"))
	for 名 in ["成功", "退还", "剩余"]:
		var 格 := 页.get_node("结果格/%s" % 名) as Control
		_configure_label(格.get_node("标签") as Label, 12, Color("#ff9100"))
		(格.get_node("物品格/底") as TextureRect).texture = load(ORIGINAL_SLOT) as Texture2D
	_configure_label(页.get_node("幸运符格/标签") as Label, 12, Color("#ff9100"))
	(页.get_node("幸运符格/物品格/底") as TextureRect).texture = load(ORIGINAL_SLOT) as Texture2D

	var 条: Dictionary = _宝石合成现读()
	# —— 放入宝石区：与合成页**逐件同款**（含拖放认领与「放入/取出」钮）——
	var 源格 := 页.get_node("放入宝石区/原宝石格") as Button
	源格.theme_type_variation = WINDOW_SKIN.皮肤表.变体_物品格按钮
	源格.focus_mode = Control.FOCUS_NONE
	源格.格子归属 = "宝石放入"
	源格.可拖拽 = false
	源格.物品id = "" if 条.is_empty() else String(条.get("id", ""))
	源格.icon = _物品图标(String(源格.物品id))
	_摆数量角标(源格.get_node("数量") as Label, int(条.get("quantity", 0)) if not 条.is_empty() else 0)
	for 连 in 源格.请求放入.get_connections():
		源格.请求放入.disconnect(连["callable"])
	源格.请求放入.connect(_宝石工艺_放入)
	(页.get_node("放入宝石区/合成宝石格/底") as TextureRect).texture = load(ORIGINAL_SLOT) as Texture2D
	(页.get_node("放入宝石区/合成宝石格/图标") as TextureRect).texture = _物品图标(_宝石合成下一颗(条))
	var 放钮 := 页.get_node("放入宝石区/放入宝石") as Button
	_configure_standard_button(放钮)
	放钮.text = "取出宝石" if not 条.is_empty() else "放入宝石"
	放钮.pressed.connect(_宝石工艺_按放入钮.bind(页))

	# —— 成功 / 退还 / 剩余三格（与合成页同一份 `_宝石合成结果`）——
	var 果 := _宝石合成结果
	for 档 in [["成功", "success_count", "success_item_id"], ["退还", "failed_count", "failed_item_id"], ["剩余", "left_count", "left_item_id"]]:
		var 格 := 页.get_node("结果格/%s" % 档[0]) as Control
		var 数 := int(果.get(档[1], 0))
		(格.get_node("物品格/图标") as TextureRect).texture = _物品图标(str(int(果.get(档[2], 0)))) if 数 > 0 else null
		_摆数量角标(格.get_node("物品格/数量") as Label, 数)

	# —— 幸运符格：**拥有数**角标（原版 `refreshLuckyBox`：`isBagExistItem(id)`），没人放也一直显示 ——
	var 符id := 装备打造表.宝石幸运符id
	var 符有 := 装备打造表.拥有数(_session, 符id)
	(页.get_node("幸运符格/物品格/图标") as TextureRect).texture = _物品图标(str(符id).pad_zeros(8))
	_摆数量角标(页.get_node("幸运符格/物品格/数量") as Label, 符有)

	# —— 勾选 / 张数下拉 /「张」（`EQUIP_STRENGTH_DESC_TEMPLATE_2` = "本次操作使用" + [N] + 张）——
	var 勾选 := 页.get_node("使用幸运符") as CheckBox
	_configure_checkbox(勾选)
	var 下拉 := 页.get_node("幸运符数量") as OptionButton
	# 宿主的 40px 宽 + 右侧「张」挨着 ⇒ 必须压回 40（默认最小宽 70，见 `_配置幸运符下拉`）。
	_配置幸运符下拉(下拉)
	下拉.clear()
	for 值 in range(1, 装备打造表.宝石幸运符上限 + 1):
		下拉.add_item(str(值), 值)
	下拉.disabled = not 勾选.button_pressed
	# 这一次要用几张（勾了且下拉有项才算；原版 `_checkBox.selected ? int(_comboBox.value) : 0`）
	var 现读张数 := func() -> int:
		return int(下拉.get_item_text(下拉.selected)) if (勾选.button_pressed and 下拉.item_count > 0 and 下拉.selected >= 0) else 0
	# ⚠️ **勾选/下拉一变只重画那两行说明，不许走 `_refresh_current()`**（2026-10-11 修）：
	#    这一页每次渲染都是**整个重建**的（`_render_page` 把 `_content` 的子节点全 free 掉，
	#    `_instantiate_page` 重新 instantiate）⇒ 重建 = 勾选回到场景默认（未勾）、下拉回到第 0 项
	#    ⇒ 玩家**一勾就自己弹回去**、张数永远只能是 1，「幸运符」这条功能实际用不了。
	#    原版 `clickCheckBoxHandler:320` / `comboBoxChangeHandler:326` 也只是
	#    `_comboBox.enabled = _checkBox.selected` + `updateDescription()`，**不重建**。
	勾选.toggled.connect(func(开: bool) -> void:
		下拉.disabled = not 开
		_填幸运合成说明(页, 条, 现读张数.call()))
	下拉.item_selected.connect(func(_序: int) -> void:
		_填幸运合成说明(页, 条, 现读张数.call()))
	_configure_label(页.get_node("张") as Label, 12, Color.WHITE)

	# —— 结果说明：`EQUIP_STRENGTH_DESC_TEMPLATE_0` 把 ￥/$ 换成金币与成功率 ——
	_填幸运合成说明(页, 条, 现读张数.call())

	_幸运合成页 = 页


## 幸运合成的提交（原版 `StoneLuckyCompositeWindow.submitToHandle()` + `composeStoneLucky()`）。
## 四道前置，**文案逐字**来自原版语言表（`en_US$message_properties.as`）：
##   ① 没放宝石 → `EQUIP_STRENGTH_FAIL_PROMPT_6_1`「请放入宝石！」
##   ② 不足 3 颗 → `EQUIP_STONE_FAIL_PROMPT_1`「对不起，宝石合成需要三颗以上的宝石！」
##   ③ 金币不够 → `EQUIP_STRENGTH_FAIL_PROMPT_2_1`「很抱歉，你的金币不够」
##   ④ 勾了符但包里不够那么多张 → 同 ③ 那条模板，`%1` 换成幸运符的名字
## 过了四道才发 `requestMergeStoneLucky(位置, 张数)`（= `ITEM_CHANGE` 动作 **31**）。
func _幸运合成_提交() -> void:
	var 条 := _宝石合成现读()
	if 条.is_empty():
		_session.notification_requested.emit("请放入宝石！")
		return
	if int(条.get("quantity", 0)) < 3:
		_session.notification_requested.emit("对不起，宝石合成需要三颗以上的宝石！")
		return
	if int(_session.player_stats.get("gold", 0)) < int(_宝石合成档(条).get("needMoney", 0)):
		_session.notification_requested.emit("很抱歉，你的金币不够")
		return
	var 张数 := 0
	if _幸运合成页 != null and is_instance_valid(_幸运合成页):
		var 勾选 := _幸运合成页.get_node("使用幸运符") as CheckBox
		var 下拉 := _幸运合成页.get_node("幸运符数量") as OptionButton
		if 勾选.button_pressed and 下拉.item_count > 0:
			张数 = int(下拉.get_item_text(下拉.selected))
	if 张数 > 0 and 装备打造表.拥有数(_session, 装备打造表.宝石幸运符id) < 张数:
		_session.notification_requested.emit("很抱歉，你的%s不够" % 装备打造表.物品名(装备打造表.宝石幸运符id))
		return
	if not _session.merge_stone_lucky(_宝石合成格, 张数):
		_session.notification_requested.emit("宝石合成要在服务端结算（离线不模拟）")


func _宝石工艺_提交() -> void:
	if _stone_tab == 2:
		# 幸运合成（`ITEM_CHANGE` 31）2026-10-11 §3.100 实装 —— 走自己那条提交。
		_幸运合成_提交()
		return
	var 条 := _宝石合成现读()
	if 条.is_empty():
		_session.notification_requested.emit("请放入宝石！")
		return
	var 件数 := int(条.get("quantity", 0))
	if 件数 < 3:
		_session.notification_requested.emit("对不起，宝石合成需要三颗以上的宝石！")
		return
	var 档 := _宝石合成档(条)
	var 花 := int(档.get("needMoney", 0)) * maxi(1, int(件数 / 3))
	if int(_session.player_stats.get("gold", 0)) < 花:
		_session.notification_requested.emit("很抱歉，你的金币不够")
		return
	if not _session.merge_stone(_宝石合成格):
		_session.notification_requested.emit("宝石合成要在服务端结算（离线不模拟）")

func _set_stone_tab(页: int) -> void:
	_stone_tab = 页
	_refresh_current()

## 原版「装备打造」窗的十个页签名 —— 逐字照抄 `EquipStrengthWindow.as:327` 的 `tabBtnNameS`。
## 七项都取自语言表（`EQUIP_STRENGTH_TAB_NAMES_1/2/3/4/6/7` + `EQUIPBAILIAN_JINGLIAN_BUTTON`，
## `en_US$message_properties.as:231-238` / `:3305`）。
##
## ⚠️ 原版这里还有后三项：**神话属性锻造 / 神话重置 / 特性属性**
## （`EquipStrengthWindow.as:327` 硬编码在数组里，语言表没有）。**2026-09-25 用户明确
## 决定本重制版不做这三个** —— 所以整个删掉，不留「尚未接」占位，页签按钮也从场景里删了。
##
## ⚠️ `EQUIP_STRENGTH_TAB_NAMES_5`（"修复"）是**孤儿**：语言表里有，这个数组没用它
## （和 §3.12.1 那个 `EQUIP_NAMES` 多一项是同一类现象）。
##
## ⚠️ 原版页签**不是写死的**：`filtrateTabBtn()`（`EquipStrengthWindow.as:782-830`）会按
## 服务端开关 `SwitchController.TIANSHENG_OFF` / `KEYIN_OFF` **动态增删**「天生」「刻印」。
## 我们目前是固定七项 —— 这条还没接，记在 §3.21。
const 打造页签 := [
	"强化", "洗附加属性", "洗附加数值", "进阶", "天生", "刻印", "精炼",
]

## 材料格上那枚「购买」的真实尺寸。原版 `ItemCaiLiaoBox.createChildren`：
##   `buyBtn = new MButtonF(); buyBtn.width = UIConfig.btn_width_two` ——
##   `btn_width_two` 就是 `原版皮肤表.按钮宽度[1] = 37`，`x = (盒宽 - 37) / 2`。
## ⚠️ 必须显式传给 `_configure_standard_button`：它的 `custom_minimum_size` 默认是
##    **57×22**（按钮.png 原始宽），不传就会把场景里按 37 排好的钮撑宽 20px ——
##    左锚不动、文字中心右移 10px，用户 2026-11-04 报的「每个子面板的购买按键都有点偏右」
##    就是这个（数学上场景坐标 11 = (60−37)/2 是对的，错在被最小宽顶成了 57）。
const 购买钮尺寸 := Vector2(37.0, 22.0)

## 每个页签的「说明 / 注意 / 标签」三段文案。
## 原版是 `CN.EQUIP_STRENGTH_DESC_TEMPLATE_<n>[0..2]`，把 `CN.REPLACE_FLAG` 换成材料名 ——
## `REPLACE_FLAG` 在语言表里的值就是 **"★"**（`en_US$message_properties.as:3135`），
## 而且 ★ 被包在 `<font color='#00ff00'>` 里，所以**材料名显示成绿色**（和实机一致）。
## 下面逐字抄自 `en_US$message_properties.as:1378-1391`（3 = 强化、7 = 天生），**别改写措辞**。
const 打造文案 := {
	"强化": [
		"<font color='#ff9100'>基础属性强化步骤说明：</font><br/>1：请在左侧装备框放入要操作的装备<br/>2：准备好<font color='#00ff00'>★</font><font color='#ffffff'>（放入包裹中即可）<br/>3：点“开始强化”按钮即可开始强化操作</font>",
		"<font color='#ff9100'>注意：</font><br/><font color='#ffffff'>强化失败，装备不降级，属性保持不变。<br/><br/><br/><br/></font>",
		"* 强化成功后，装备基础属性将大幅度提升",
	],
	"天生": [
		"<font color='#ff9100'>天生属性强化说明：</font><br/>1：请在左侧装备框放入要操作的装备<br/>2：装备好<font color='#00ff00'>★</font><font color='#ffffff'>（放入包裹中即可）<br/>3：点“开始强化”按钮即可开始强化操作</font>",
		"<font color='#ff9100'>注意：</font><br/><font color='#ff0000'>天生属性强大最大可提升至100%<br/>即：天生属性加成最大时等于基础属性加成</font><br/><font color='#ffffff'>本处强化失败不会降低原装备的任何属性<br/>强化成功将带来天生属性的随机幅度上涨</font>",
		"* 强化成功后，装备基础属性将大幅度提升",
	],
}

## 说明文案里的占位符（原版 `CN.REPLACE_FLAG`）。
const 文案占位 := "★"


## 「精炼」页的两段固定文案。逐字抄 `en_US$message_properties.as`（`:1464` / `:368` / `:350`）。
## ⚠️ 这一页**不做占位替换** —— 材料名"精炼锤"是**语言表里直接写死的**，
## 既不是 `★`（强化/天生/洗附加属性用的）也不是 `%1`（刻印/洗附加数值用的）。
## 别顺手给它加个 replace，加了反而会把这段正确的文案改坏。
const 精炼说明 := "<font color='#ff9100'>装备精炼步骤说明：\r</font><font color='#ffffff'>1：请在左侧装备框放入要操作的紫色装备\r2：准备好<font color='#00ff00'>精炼锤</font>（放在包裹中即可）\r3：选择精炼项，点击“开始精炼”按钮</font>"
## 注意段**随下拉项换**（`onSelectedTypeHandler` 的 case 0 / case 1），键就是精炼项的 id。
const 精炼注意文案 := {
	0: "<font color='#00ff00'>提升附加属性：精炼成功将会提升装备每条附加属性的数值，锻造失败将回收精炼锤，装备属性不产生任何损失。\r</font><font color='#ff0000'>即：装备附加属性只会上升，不会下降。</font>",
	1: "<font color='#00ff00'>提升强化星数：精炼成功后将会提升装备的强化星数，失败装备不降级，属性保持不变</font>",
}


## 材料格的**角标数字 + 灰不灰**，各页原版的口径是同一族三件套
## （`ItemCaiLiaoBox.count = isBagExistItem(id)`、`applyGrayFilter(布)`、`hasItem()`）：
##   · 必备材料（材料一 / `_caiLiao1` / `_fu1`）：**角标 = 需要数**
##     （`EquipStrengthWindow.as:295`、`EquipKeYinPanel.as:124`、`EquipPropResetPanel.as:137/339`、
##       `EquipPropLianZhiPanel.as:163`、`EquipUpgradeWindow.as:344`、`EquipBaiLianPanel.as:505`），
##     **灰 = 需要数 > 拥有数**（各家 `updateXingYunRatio/validateCaiLiao` 的同一句 `count >= need`）；
##   · 幸运符/帮手材料（材料二 / `_caiLiao2` / `_fu4`）：**角标 = 拥有数**
##     （`EquipPropResetPanel.as:149` `isBagExistItem(id)`、`EquipUpgradeWindow.as:156` `_fu4.count`），
##     **灰 = 拥有数 ≤ 0**（`ItemCaiLiaoBox.hasItem()`：`count>0 ? 摘灰 : 套灰`）；
##   · **没放装备**：整格无条件套灰（`applyGrayFilter()` 默认 true——
##     `EquipKeYinPanel.as:103/117`、`EquipPropResetPanel.as:99-100`、`EquipUpgradeWindow.as:432-433`、
##     `EquipStrengthWindow.as:925`、`EquipBaiLianPanel.as:503`），
##     并且**各专属面板页把角标清成空白**（各家 `backItemToEquip`：`itemCell.label = " "`；
##     共用左栏不清，它恒 `needItemCnt` —— 照 `EquipStrengthWindow.as:295`）。
## 我们以前：只有精炼页做了灰度，别的页**角标有的摆拥有数（应为需要数）、有的从不灰**。
## ⚠️ 灰要打满整格：AS3 的 filter 挂在 itemCell 上（底+图标一起灰），
##    Godot 的 `material` 不传子节点 ⇒ 格子与图标两个节点都要设（§3.18.9 精炼页量出来的）。
func _套格子灰(格: CanvasItem, 要灰: bool) -> void:
	if 格 == null:
		return
	var 材质: Material = 禁用灰度材质() if 要灰 else null
	格.material = 材质
	var 图标 := 格.get_node_or_null("材料图标") as CanvasItem
	if 图标 != null:
		图标.material = 材质


## 原版那两段文案是 **Flash 的 htmlText**（`<font color='#ff9100'>`、`<br/>`），
## 而 Godot 的 `RichTextLabel` 吃的是**另一套 BBCode**（`[color=#ff9100]`、换行）。
##
## ⚠️ 这两套**不通用**，必须翻译 —— 直接照抄标签的结果是**整段标签原样显示成文字**
## （2026-09-22 实机看到的：窗口里赫然写着 `<font color='#ff9100'>基础属性强化步骤说明：`）。
## 翻译只做四件事：换行（`<br/>` 与 Flash 的 `\r`）、`<font color=...>`→`[color=…]`、
## `</font>`→`[/color]`、**剥掉 `<textformat …>` / `</textformat>` 这层样式块**。
## **文字本身一个字不改** —— 措辞的真值仍然是语言表那段。
static func 译文为BBCode(html: String) -> String:
	# 2026-10-01：实现搬去了 `脚本/界面/富文本.gd`（原来只长在本文件里，别的界面拿不到）。
	# 这里保留同名转发，调用点一行没动。
	return 富文本.译文为BBCode(html)

## 原版「装备打造」窗。**一个窗、一条左栏**：七个操作页签共用同一套
## `说明/注意/标签/材料框/开始强化`，各页只是换文案与配置；
## 右侧 `部位列表` 是选"要操作的已装备部位"的列表，与左栏是两件事。
## 出处：`EquipStrengthWindow.createChildren()`（`:322-406`）与
## `refresh()` 的 `switch(this._tabBar.selectedIndex)`（`:195-300`）。
func _render_strengthen() -> void:
	var page := _instantiate_page(装备强化页面场景)
	for index in 打造页签.size():
		var tab := page.get_node("分页/%s" % 打造页签[index]) as Button
		选页签(tab, index == _strengthen_tab)
		_apply_tab_skin(tab)
		tab.pressed.connect(_set_strengthen_tab.bind(index))
	_configure_original_panel(page.get_node("外框") as Panel, true)
	_configure_original_panel(page.get_node("内容背景") as Panel)
	_configure_original_panel(page.get_node("内容容器/材料框") as Panel)
	(page.get_node("内容容器/装备格") as TextureRect).texture = load(ORIGINAL_SLOT) as Texture2D
	(page.get_node("内容容器/材料框/材料格") as TextureRect).texture = load(ORIGINAL_SLOT) as Texture2D
	# 页签分派：`case 0 强化` 与 `case 4 天生` 用**共用左栏**；
	# 其余七页各自 `new` 一个面板、**位置尺寸就是整个内容区 350×316**
	# （`EquipStrengthWindow.as:727-733`）—— 是**整块换掉左栏**，不是换文案。
	# 所以这里必须二选一，不能两个都画（§3.18.10 记的就是我上一轮画错的这条）。
	var 页名: String = 打造页签[clampi(_strengthen_tab, 0, 打造页签.size() - 1)]
	# ⚠️ 「箭头」也在这份名单里 —— 它属共用左栏（`ItemDropBox` 的一部分）。
	# 漏掉它会怎样：七个专属面板页上，共用左栏的箭头**不隐藏**，与各页面自己那个箭头
	# 叠在一起，画面上是两个箭头错位重影（2026-09-25 靠像素比对逮到的：
	# 差异域能量 34090，采样发现我方 x=43..46 有灰色箭头、而原版那里是纯面板底色）。
	# ⚠️ 2026-10-01 同一族又漏了「装备格」：原版专属页藏的是**整个 `_contentBox`**
	# （`EquipStrengthWindow.as:659/723/739` `this._contentBox.visible = false`），
	# `_itemBox`（放入装备+装备格+箭头）都在它里面。我们逐件藏，独独漏了装备格 ——
	# `_配置打造左栏` 每次渲染都往 `内容容器/装备格/装备图标` 填选中装备的图标，
	# 于是六个专属页上放有装备时**两枚图标错位重叠**（用户 2026-10-01 报"除强化外都有重叠"）。
	for 名 in ["放入装备", "装备格", "说明", "注意", "标签", "材料框", "箭头"]:
		(page.get_node("内容容器/%s" % 名) as CanvasItem).visible = 页名 in ["强化", "天生"]
	_配置打造左栏(page)
	_配置面板页(page, 页名)
	_配置部位列表(page)


## 专属面板那几页：把面板铺在**整个内容区**（350×316，窗口 (5,58)），并隐藏共用左栏。
## 2026-10-01 更正过期注释：这句以前写"只有进阶有面板、其余六页明说未接"——
## 刻印/精炼/洗附加属性/洗附加数值/进阶**五页的面板都早就建好了**（各自场景 + `_配置X页`），
## 现在唯一走兜底报错的是"页名不在七页清单里"这种结构性漏。
func _配置面板页(page: Control, 页名: String) -> void:
	var 容器 := page.get_node_or_null("面板容器") as Control
	if 容器 == null:
		return
	for 旧 in 容器.get_children():
		容器.remove_child(旧)
		旧.queue_free()
	# 面板全被拆掉了，两个"页面持有面板"的引用都悬空了 —— 回包时不能再往它上面填。
	_洗数值面板 = null
	_洗数值面板件 = ""
	_洗属性面板 = null
	# 只有"洗附加数值"这一页需要跨重建留住预览；换到别的页签就作废。
	if 页名 != "洗附加数值":
		_洗数值预览.clear()
	# 「洗附加属性」的洗前快照同理：只有停在这一页才留（换装备登录态的同一页重建要留着）。
	if 页名 != "洗附加属性":
		_清洗属性快照()
	# 「开始强化」那个按钮**七页都留着**（原版它不是左栏的一部分，是窗口自己的），
	# 只是文案按页签换 —— `EQUIP_STRENGTH_STRENGTH_BTN_NAMES`：
	#   1 开始强化 / 2 开始重置 / 3 开始修复 / 4 开始进阶 / 5 开始合成
	# 原版各 case 只设 text，不改位置（`x` 由公共尾那句居中算）。
	var 执行 := page.get_node("开始强化") as Button
	if 页名 in ["强化", "天生"]:
		容器.visible = false
		执行.text = "开始强化"        # BTN_NAMES[0]
		执行.visible = true
		return
	容器.visible = true
	if 页名 == "刻印":
		# 刻印页也**自建按钮**（`_keYinBtn`，`EquipKeYinPanel.as:252`），x 还是写死的 50；
		# 所以和洗附加属性一样：藏窗口那个、接面板这个。
		var 刻面板 := 装备刻印页场景.instantiate() as Control
		容器.add_child(刻面板)
		_配置刻印页(page, 刻面板)
		执行.visible = false
		var 刻印按钮 := 刻面板.get_node("开始刻印") as Button
		_configure_standard_button(刻印按钮)
		for 连接 in 刻印按钮.pressed.get_connections():
			刻印按钮.pressed.disconnect(连接["callable"])
		刻印按钮.pressed.connect(_执行打造.bind(page))
		var 图解 := 刻面板.get_node("刻印图解") as Button
		_configure_standard_button(图解)
		图解.pressed.connect(_切换刻印图解.bind(刻面板))
		return
	if 页名 == "精炼":
		# ⚠️ 精炼页也**自建按钮**，而且自建了**两只**（`_jingLianBtn` + `_autoJingLianBtn`，
		# `EquipBaiLianPanel.as:242/248`）—— 名字和别页都不一样，别照 `_upgradeBtn` 找
		# （§3.18.15 专门提醒过这条）。照规矩：藏窗口那个、接面板这个。
		var 精面板 := 装备精炼页场景.instantiate() as Control
		容器.add_child(精面板)
		_配置精炼页(page, 精面板)
		执行.visible = false
		var 精炼按钮 := 精面板.get_node("精炼") as Button
		_configure_standard_button(精炼按钮)
		for 连接 in 精炼按钮.pressed.get_connections():
			精炼按钮.pressed.disconnect(连接["callable"])
		精炼按钮.pressed.connect(_执行打造.bind(page))
		var 自动按钮 := 精面板.get_node("自动精炼") as Button
		_configure_standard_button(自动按钮)
		自动按钮.text = "停止精炼" if not _打造自动目标.is_empty() else "自动精炼"
		自动按钮.disabled = 精炼按钮.disabled and _打造自动目标.is_empty()
		自动按钮.pressed.connect(func():
			if not _打造自动目标.is_empty():
				_停打造自动()
				_refresh_current()
			else:
				_打造自动选中 = true
				_执行打造(page))
		return
	if 页名 == "洗附加数值":
		# **复用「洗附加属性」那个场景** —— 两个面板的版式在 AS3 里是同一套
		# （`EquipPropLianZhiPanel` 与 `EquipPropResetPanel` 的 createChildren 逐件同坐标），
		# 差别只是数值版把 `_oldPropLabel`/`_newPropLabel`/`_propBox` 设成隐藏
		# （`showView()` 里那两句），而那几件我们本来就没建。
		var 数值面板 := 装备洗附加属性页场景.instantiate() as Control
		容器.add_child(数值面板)
		_配置洗附加数值页(page, 数值面板)
		执行.visible = false
		var 数值按钮 := 数值面板.get_node("开始重置") as Button
		_configure_standard_button(数值按钮)
		for 连接 in 数值按钮.pressed.get_connections():
			数值按钮.pressed.disconnect(连接["callable"])
		数值按钮.pressed.connect(_执行打造.bind(page))
		return
	if 页名 == "洗附加属性":
		var 面板 := 装备洗附加属性页场景.instantiate() as Control
		容器.add_child(面板)
		_配置洗附加属性页(page, 面板)
		# ⚠️ 这一页用的是**面板自己的**按钮，不是窗口那个 ——
		# `EquipPropResetPanel.createChildren()` 里 `new 了一个 _upgradeBtn`
		# （x=(350-61)/2=144.5、y=349-高-5），位置和窗口的 `_strengthBtn` **正好重合**，
		# 面板盖在上面。所以把窗口那个藏起来、接线接到面板这个上，
		# 否则界面上会出现两个同名按钮、而看得见的那个是死的（回归用例逮到过）。
		执行.visible = false
		var 自己的按钮 := 面板.get_node("开始重置") as Button
		_configure_standard_button(自己的按钮)
		自己的按钮.text = "开始重置"          # STRENGTH_BTN_NAMES[1]
		for 连接 in 自己的按钮.pressed.get_connections():
			自己的按钮.pressed.disconnect(连接["callable"])
		自己的按钮.pressed.connect(_执行打造.bind(page))
		return
	# ⚠️ 是 **「开始合成」**（= `EQUIP_STRENGTH_STRENGTH_BTN_NAMES[4]`，
	# **0 基下标** → 数组第 5 个 = `_5` = "开始合成"，不是 `_4` 的"开始进阶"）。
	# 我第一版按 `_4` 写成了"开始进阶"，是**下标差一格**；靠原版实机图才逮到。
	# 走到这里**只剩「进阶」**：强化/天生 在上面走了共用左栏就 return，
	# 刻印/精炼/洗附加数值/洗附加属性 各自 return。
	# 原先这里还有一条 `"%s：尚未接"` 的兜底，是给
	# 神话属性锻造 / 神话重置 / 特性属性 那三页用的 —— 2026-09-25 用户决定不做那三页、
	# 页签也从场景里删了，兜底随之变成死代码，一并清掉（留着只会把"漏了分支"藏起来）。
	if 页名 != "进阶":
		push_error("「%s」没有专属面板，却走到了 _配置面板页 的兜底" % 页名)
		return
	_配置面板执行按钮(page, "开始合成")
	var 面板 := 装备进阶页场景.instantiate() as Control
	容器.add_child(面板)
	_配置进阶页(page, 面板)


## 专属面板页里**用窗口那个按钮**的那种（进阶页就是 —— `EquipUpgradeWindow` 自己不建按钮），
## 把窗口根的 `开始强化` 换个文案并接线。（洗附加属性页不同：它面板自带按钮，见那里的注释。）
func _配置面板执行按钮(page: Control, 文案: String) -> void:
	var 执行 := page.get_node("开始强化") as Button
	执行.text = 文案
	执行.disabled = false
	for 连接 in 执行.pressed.get_connections():
		执行.pressed.disconnect(连接["callable"])
	执行.pressed.connect(_执行打造.bind(page))


## 打造各页「放入装备」格上的品质外框 + 紫橙流光 —— 原版 `SimpleItemCell.showIcon`
## 对带 `aptitude` 的件加 `aptitudeIcon`(-1,-1) + `equipAnimationF`(3,3)（列表行/装备格
## 都没有灵气粉框分支），全项目搭这两个节点的唯一入口是 `装备品质.挂覆盖层`。
## 空格子/非装备也要调（传 `{}`）—— 上一次那件留下的框靠它清掉。
func _挂装备品质(格: Control, 选中: Dictionary) -> void:
	装备品质脚本.挂覆盖层(格, 选中, false, "格子")


## 打造各页材料格的「数量」角标 —— 用户 2026-11-01：「各面板的道具数量字体都偏小，
## 可以参考背包面板的道具数量字体大小和样式」。口径照背包（`背包窗口.gd:779-787`）：
## **14 号白字、右对齐、黑描边、不加粗**（14 是 2026-10-25 用户批准的、原版 12 的有意偏离）。
## 右下位置在场景里（锚 bottom-right），这里只补字号/颜色/右对齐。
func _配置材料数量(标签: Label) -> void:
	_configure_label(标签, 14, Color.WHITE)
	标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## 「张 / 个」幸运符颗数下拉 —— 只装 1..9 的数字，**不该按最长项撑宽**。
## Godot 的 `OptionButton` 最小宽默认 70（主题内容边距 7+18、箭头 12+4、字 12 号；
## 实测 `fit_to_longest_item = true` 时就是这个数），而场景里这几格只有 40~45 宽
## ⇒ 控件右沿压到后面的「个幸运符 / 张」上（用户 2026-11-01 报「数值框跟个幸运符字体重叠」）。
## 三项一起才把最小宽压回 40（同 `寄坏之术页.tscn` 的 `数量下拉` 写法，2026-10-27 那轮验过）：
##   `fit_to_longest_item = false`（不按项宽算）+ `clip_text`（溢出裁掉）+ `arrow_margin = 0`。
func _配置幸运符下拉(下拉: OptionButton) -> void:
	_configure_option_button(下拉)
	下拉.fit_to_longest_item = false
	下拉.clip_text = true
	下拉.add_theme_constant_override("arrow_margin", 0)


## 「精炼」页（`EquipBaiLianPanel`）—— 打造窗里**唯一带下拉、且下拉两项各走各的配置**的一页。
##
## 下拉 = `EQUIPBAILIAN_JINGLIAN_TYPE`（"提升附加属性,提升强化星级"）split(",")，
## 面板末尾写死 `selectedIndex = 0`，所以**默认落在附加属性**那一项。
## 两项的配置见 `装备打造表.取精炼`：附加属性走 `forgeAdditive`、强化星级走
## `strength.level11`（百炼那条），材料都是**精炼锤 15028002**；
## 两档的成功率 2026-11-01 按用户口径统一提到 **25%**（服务端 overlay 改，见项目 `project.json`）。
##
## ⚠️ 这一页**不做占位替换**（材料名写死在语言表里），见 `精炼说明` 上那条注释。
func _配置精炼页(page: Control, 面板: Control) -> void:
	# —— 每次进这一页只做一遍的静态件 ——
	_configure_original_panel(面板.get_node("材料框") as Panel)
	# 2.1：装备格原来**没给底图**（场景里也没 texture），空框根本不出现。
	for 名 in ["装备格", "材料框/材料一/材料格"]:
		(面板.get_node(名) as TextureRect).texture = load(ORIGINAL_SLOT) as Texture2D
	(面板.get_node("说明") as RichTextLabel).text = 译文为BBCode(精炼说明)
	_configure_label(面板.get_node("标签") as Label, 12, Color("#ff9100"))
	(面板.get_node("标签") as Label).text = "* 精炼台只能精炼紫色品质强化等级10星以上的装备"

	var 放入 := 面板.get_node("放入装备") as Button
	_configure_standard_button(放入)
	放入.pressed.connect(_点打造放入钮.bind(page))
	_挂打造落点(面板.get_node("装备格") as Control)

	# 「购买」= 原版 `ItemCaiLiaoBox.buyHandler:46-55` 那跳 `REQUEST_CASH_ITEM_INFO`
	# （`id = itemCell.itemData.id`）⇒ 走 `请求商城商品` 统一出口（§3.125 那条链）。
	# 精炼材料 = 精炼锤，两档配置的 `needItemId` 都是它（`装备打造表.精炼项_附加属性` 那条注释）。
	var 购买 := 面板.get_node("材料框/材料一/购买") as Button
	_configure_standard_button(购买, 购买钮尺寸)
	var 精炼材料id := int(装备打造表.取精炼(装备打造表.精炼项_附加属性).get("needItemId", 0))
	购买.disabled = 精炼材料id <= 0
	购买.tooltip_text = "购买材料"
	购买.pressed.connect(func() -> void: 请求商城商品(str(精炼材料id)))

	# 两处贴着条/框的小字，色是 `UIConfig.UI_ZHONG_SE` = 16565145 = #FCC399。
	# ⚠️ 字号一律 **12** —— 这是 2026-09-23 拿原版并排图量出来的：
	# 这四处的墨高（含基线）原版都是 12，我原来写的 11/10 矮一格。
	# `材料名` 那条另有 AS3 明证：`ItemCaiLiaoBox.createChildren()` 里写死 `this.label.fontSize = 12`。
	for 名 in ["材料框/选择锻造项", "材料框/锻造成功率"]:
		_configure_label(面板.get_node(名) as Label, 12, Color("#fcc399"))
	(面板.get_node("材料框/选择锻造项") as Label).text = "选择锻造项"
	(面板.get_node("材料框/锻造成功率") as Label).text = "锻造成功率"
	_configure_label(面板.get_node("材料框/勾选后点击精炼") as Label, 12, Color("#00ff00"))
	(面板.get_node("材料框/勾选后点击精炼") as Label).text = "勾选后点击精炼"
	# 2.4：条上那行 "prob/100" —— 原版 `MBar.tf` 是默认 **12 号**、宽 = 条宽、居中；
	# 我们原来 10 号、矩形还往右偏 2px、贴顶（用户："字体偏小且不在数值轴正中间"）。
	# 矩形按条心摆：条在材料框 (150,57) 100×11（填充画在 y=3..8），中心 y=62.5；
	# 文字框给 19 高 ⇒ y = 62.5 − 19/2 = 53，竖向居中后正好落在条上。
	var 成功率文本 := 面板.get_node("材料框/成功率文本") as Label
	_configure_label(成功率文本, 12, Color.WHITE)
	成功率文本.position = Vector2(150.0, 53.0)
	成功率文本.size = Vector2(100.0, 19.0)
	成功率文本.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	成功率文本.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var 自动勾 := 面板.get_node("材料框/自动精炼至满属性") as CheckBox
	_configure_checkbox(自动勾)
	自动勾.set_pressed_no_signal(_打造自动选中)
	自动勾.toggled.connect(_设置打造自动)
	_configure_label(面板.get_node("材料框/材料一/材料名") as Label, 12, Color("#ff9100"))
	_配置材料数量(面板.get_node("材料框/材料一/材料格/材料数量") as Label)

	# 下拉：文案照语言表 split(",") 的次序，id 直接用精炼项常量。
	# 2.2：整页重渲染时**按上次那一项还原**（不是每次都 `selected = 0`）；
	# 换页签/重开窗由 `_set_strengthen_tab` 把它重置回默认。
	var 下拉 := 面板.get_node("材料框/精炼项") as OptionButton
	_configure_option_button(下拉)
	下拉.add_item("提升附加属性", 装备打造表.精炼项_附加属性)
	下拉.add_item("提升强化星级", 装备打造表.精炼项_强化星级)
	下拉.selected = maxi(0, 下拉.get_item_index(_精炼项选中))
	下拉.item_selected.connect(func(索引: int):
		_停打造自动()
		_精炼项选中 = 下拉.get_item_id(索引)
		# 就地刷，不走 `_refresh_current()`：整页重建会 free 掉面板与各子节点，
		# 还在用它们的外部调用（门/脚本）会撞 "previously freed instance"。
		_刷新精炼项(page, 面板)
		_刷新精炼自动钮(面板))
	_刷新精炼项(page, 面板)


## 精炼页里**随下拉项变**的那几件 —— 原版 `onSelectedTypeHandler()`（`EquipBaiLianPanel.as:309-329`）
## 做的就是这件事：换 `_configure`、换注意段、换材料图标与名字、换成功率条的读数。
## 也顺带跟着"装备放没放进去"刷新一次（原版是 `updateViewNow()` 干的，`:491-509`）。
func _刷新精炼项(page: Control, 面板: Control) -> void:
	var 选中 := _会话选中()
	var 有装备 := not 选中.is_empty()
	var 下拉 := 面板.get_node("材料框/精炼项") as OptionButton
	var 项 := 下拉.get_selected_id()
	var 配置 := 装备打造表.取精炼(项)
	var 材料id := int(配置.get("needItemId", 0))
	var 需要数 := int(配置.get("needItemCnt", 0))
	# ⚠️ 条上读数是**配置里原始的 `prob`**（`_ratioMbar.setData(this._configure.prob, 100)`），
	# 这一页**没有幸运符**，所以不过 `实际成功率`（那个是加幸运符用的，本页恒等于 prob）。
	var 成功率 := int(配置.get("prob", 0))

	(面板.get_node("注意") as RichTextLabel).text = 译文为BBCode(String(精炼注意文案.get(项, "")))

	# 材料格显示的是**需要数**（`updateViewNow()`：`_caiLiao1.itemCell.label = needItemCnt`），
	# 不够就套灰度 —— 用的正是 `applyGrayFilter()` 那套矩阵（已核过与 `Style.getDisableFilter()`
	# 逐字相同，就是 §3.18.9 那个 `禁用灰度.gdshader`）。
	# 原版 `updateViewNow()`（`:497-508`）分**两段**：
	#   有装备 → `applyGrayFilter(needItemCnt > 拥有数)`
	#   没装备 → `applyGrayFilter()` —— **无条件**套灰
	# ⚠️ 还有一处必须盖到**图标**上：AS3 是 `this.itemCell.filters = …`（整格，含图标），
	# 而 Godot 的 `material` **不会传给子节点** —— 只设在 `材料格`（空框）上的话，
	# 图标照旧彩色。2026-09-23 并排图直接量出来的：原版图标平均 RGB (85,82,81) 近中性灰，
	# 我这边还是 (134,72,47) 的橙。**两个节点都要设。**
	var 拥有 := 装备打造表.拥有数(_session, 材料id)
	var 该套灰 := (not 有装备) or 需要数 > 拥有
	for 名 in ["材料框/材料一/材料格", "材料框/材料一/材料格/材料图标"]:
		(面板.get_node(名) as CanvasItem).material = 禁用灰度材质() if 该套灰 else null
	(面板.get_node("材料框/材料一/材料名") as Label).text = 装备打造表.物品名(材料id)
	(面板.get_node("材料框/材料一/材料格/材料图标") as TextureRect).texture = \
		GAME_DATA.item_icon(材料id) if 材料id != 0 else null
	(面板.get_node("材料框/材料一/材料格/材料数量") as Label).text = str(需要数)

	# 成功率条：`MBarExpF` 的 `setData(prob, 100)`，条上那行文字是 "prob/100"
	# （`MBar.setData` 里 `tf.text = param1 + "/" + param2`，`_showPercent` 没开）
	#
	# ⚠️ 填充是**遮罩显影**，不是拉伸：`MBar.setData` 把整幅 `bar`（122 宽）左移
	# `int(bar.width * (1 - ratio))`，透过固定的 `maskMc`（符号 x=48、宽 94）露出左边一截。
	# 所以这里改 `region_rect`（取贴图的一段），而不是 ProgressBar 的 value ——
	# 几何照符号算：显示区 = 材料框局部 (153,60) 起、94×ratio 宽、5 高，
	# 取的贴图区域从 (3,3) 开始（因为 `bar` 画在符号 x=45、`maskMc` 在 48，差 3）。
	var 条 := 面板.get_node("材料框/成功率条") as Control
	(条.get_node("槽") as TextureRect).texture = load(ORIGINAL_PROGRESS_BG) as Texture2D
	var 填充 := 条.get_node("填充") as TextureRect
	# 可见宽度照 AS3 算，**不是** `94 × ratio`：
	#   `bar.width` = 100（122 宽的原画缩到 100）、`bar.x = 45 − int(100 × (1 − ratio))`
	#   → bar 右沿 = 145 − int(100 × (1 − ratio))；而 `maskMc` 左沿 = 48
	#   → 可见 = **100 × ratio − 3**，再夹进 0..94（mask 本身只有 94 宽）。
	# 那 3px 在比值小的时候很显眼：7% 是 4px，不是 94×7% = 6.6px。
	var 可见宽 := clampf(float(成功率) - 3.0, 0.0, 94.0)
	填充.position = Vector2(3.0, 3.0)
	填充.size = Vector2(可见宽, 5.0)
	# ⚠️ `TextureRect` **没有** `region_enabled` / `region_rect`（那是 `Sprite2D` 的属性）——
	# 写错只报一句 "Invalid assignment ... 'region_enabled'"，**不中断整个脚本**但会中断这个函数，
	# 于是 size 设了、区域没生效、贴图还是整幅 122 宽（7% 的条被画成满格绿）。取区域要用 `AtlasTexture`。
	# 另外场景里那个 `expand_mode = 1`（IGNORE_SIZE）必须开着，否则贴图会把最小尺寸顶成 122。
	# 取的贴图宽度要乘 122/100 —— 原画被缩到 100 宽，屏幕上的 1px 对应原画 1.22px。
	# （`进度填充.png` 左右镜像平均差 0.47、亮度曲线逐点相同 = **水平对称**，
	#   所以从哪端取都一样，用左端即可 —— 这条是量过的，不是"看着像"。）
	var 图集 := AtlasTexture.new()
	图集.atlas = load(ORIGINAL_PROGRESS_FILL) as Texture2D
	图集.region = Rect2(3.0, 3.0, 可见宽 * 1.22, 5.0)
	填充.texture = 图集
	(面板.get_node("材料框/成功率文本") as Label).text = "%d/100" % 成功率

	(面板.get_node("装备格/装备图标") as TextureRect).texture = \
		load(String(选中.get("icon", ""))) as Texture2D if 有装备 and ResourceLoader.exists(String(选中.get("icon", ""))) else null
	# 0.1：放入格也要带品质外框 + 流光（原版 `SimpleItemCell.showIcon`）。
	_挂装备品质(面板.get_node("装备格") as Control, 选中 if 有装备 else {})
	(面板.get_node("放入装备") as Button).text = "取出装备" if 有装备 else "放入装备"
	# ⚠️ 2026-11-04 用户要求：**满级后不再可点**（原来只判"没装备"，满了照样点、
	# 照样扣精炼锤）。两档各自的上限就是服务端的两个前置闸：
	#   「提升强化星级」`_forge_level_eleven` 要求 `strength_level == 10` ⇒ 11 星封顶；
	#   「提升附加属性」`_forge_additive` 要求 `forge_additive_ratio < MAX_FORGE_ADDITIVE_RATIO`(500)。
	var 已满 := false
	if 有装备:
		if 项 == 装备打造表.精炼项_强化星级:
			已满 = int(选中.get("strengthen", 0)) >= 11
		else:
			已满 = int(选中.get("forge_additive_ratio", 0)) >= 500
	(面板.get_node("精炼") as Button).disabled = (not 有装备) or 已满 or not _打造请求.is_empty() or not _打造自动目标.is_empty()
	_接打造装备提示(page, 面板.get_node("装备格"), 选中 if 有装备 else {})
	_接打造提示(page, 面板.get_node("材料框/材料一/材料格"), 材料id, 需要数)


func _刷新精炼自动钮(面板: Control) -> void:
	var 自动按钮 := 面板.get_node_or_null("自动精炼") as Button
	if 自动按钮 == null:
		return
	var 精炼按钮 := 面板.get_node_or_null("精炼") as Button
	自动按钮.text = "停止精炼" if not _打造自动目标.is_empty() else "自动精炼"
	自动按钮.disabled = 精炼按钮 != null and 精炼按钮.disabled and _打造自动目标.is_empty()


## 「洗附加数值」页（`EquipPropLianZhiPanel(isWashProp = true)`）。
## 配置 = `EquipSystem.plus.washvalue`（`装备打造表.取洗附加数值`），**prob 写死 100**。
## 文案取自语言表 `EQUIPPROPLIANZHIPANEL_PROP_WASH_DESC`（**说明与注意是同一个字段**，
## 不像「洗附加属性」那样分成两段）与 `EQUIPPROPLIANZHIPANEL_PROP_WASH_LABEL`；
## 占位同样是 **`%1`**。
func _配置洗附加数值页(page: Control, 面板: Control) -> void:
	var 选中 := _会话选中()
	var 有装备 := not 选中.is_empty()
	_configure_original_panel(面板.get_node("材料框") as Panel)
	for 名 in ["装备格", "材料框/材料一/材料格", "材料框/材料二/材料格"]:
		(面板.get_node(名) as TextureRect).texture = load(ORIGINAL_SLOT) as Texture2D
	(面板.get_node("装备格/装备图标") as TextureRect).texture = \
		load(String(选中.get("icon", ""))) as Texture2D if 有装备 and ResourceLoader.exists(String(选中.get("icon", ""))) else null
	var 放入 := 面板.get_node("放入装备") as Button
	_configure_standard_button(放入)
	放入.text = "取出装备" if 有装备 else "放入装备"
	放入.pressed.connect(_点打造放入钮.bind(page))
	_挂打造落点(面板.get_node("装备格") as Control)

	# 消耗按**附加属性条数**分档（`plus<条数>`），所以先把条数数出来
	var 附加条数: int = (选中.get("plus_attributes", []) as Array).size()
	var 配置 := 装备打造表.取洗附加数值(_装备阶数(选中), maxi(1, 附加条数))
	var 材料id := int(配置.get("needItemId", 0))
	var 材料名 := 装备打造表.物品名(材料id)

	var 说明 := String("<font color='#ff9100'>重置附加属性数值说明：</font><br/><font color='#ffffff'>1：请在左侧装备框放入要操作的装备<br/>2：装备好<font color='#00ff00'>%1</font>（放入包裹即可）<br/>3：点开始强化按钮即可开始强化操作<br/></font><font color='#ff9100'>注意：</font><br/><font color='#ffffff'>本操作会改变您装备的附加属性值大小<br/>无论本操作成功或失败，您装备附加属性的条数和类型均不会有任何改变</font><br/><font color='#ff0000'>达到满属性后再次重置将不会改变</font>")
	# ⚠️ 这个场景里**没有「注意」节点** —— AS3 那边说明与注意本来就是**同一个字段**
	# （`_descField.htmlText = 整段`），所以建场景时就只留了「说明」一件。
	(面板.get_node("说明") as RichTextLabel).text = 译文为BBCode(说明.replace("%1", 材料名))
	_configure_label(面板.get_node("标签") as Label, 12, Color("#ff9100"))
	(面板.get_node("标签") as Label).text = "* 强化后的新属性可以自主选择【保存】或【取消】"

	(面板.get_node("材料框/材料一/材料名") as Label).text = 材料名
	_configure_label(面板.get_node("材料框/材料一/材料名") as Label, 12, Color("#ff9100"))
	(面板.get_node("材料框/材料一/材料格/材料图标") as TextureRect).texture = GAME_DATA.item_icon(材料id) if 材料id != 0 else null
	# 角标 = **需要数**（`EquipPropLianZhiPanel.as:163`），没放清成 " "（`:528`）；
	# 灰 = 没放 或 需要 > 拥有（`:383-387` 的 `count >= need`）。
	var 需要数 := int(配置.get("needItemCnt", 0))
	(面板.get_node("材料框/材料一/材料格/材料数量") as Label).text = str(需要数) if 有装备 else " "
	_配置材料数量(面板.get_node("材料框/材料一/材料格/材料数量") as Label)
	_套格子灰(面板.get_node("材料框/材料一/材料格") as CanvasItem,
			not 有装备 or 需要数 > 装备打造表.拥有数(_session, 材料id))
	_接打造装备提示(page, 面板.get_node("装备格"), 选中 if 有装备 else {})
	_挂装备品质(面板.get_node("装备格") as Control, 选中 if 有装备 else {})
	_接打造提示(page, 面板.get_node("材料框/材料一/材料格"), 材料id, 需要数)
	# 1.2（用户 2026-11-01）：原版这一页（`EquipPropLianZhiPanel(isWashProp = true)`）
	# **只建 `_caiLiao1`** —— 没有第二材料格、也没有幸运符那组控件
	# （`createChildren:260-290` 里根本没有 `_caiLiao2`）。场景是与「洗附加属性」共用的，
	# 所以这里把多出来的四件**藏掉**（材料二连它那枚「购买」一起）。
	for 名 in ["材料框/材料二", "材料框/使用幸运符", "材料框/幸运符数量", "材料框/单位"]:
		(面板.get_node(名) as CanvasItem).visible = false
	# 「购买」= 原版 `ItemCaiLiaoBox.buyHandler:46-55` 那跳 `REQUEST_CASH_ITEM_INFO`（§3.125 那条链）。
	var 购买 := 面板.get_node("材料框/材料一/购买") as Button
	_configure_standard_button(购买, 购买钮尺寸)
	购买.disabled = 材料id <= 0
	# ⚠️ 这一页每次渲染都重建 ⇒ 连接不会叠加；但 `_configure_standard_button` 之后
	#    必须重新接（它不碰 pressed）。
	if 材料id > 0:
		购买.pressed.connect(请求商城商品.bind(str(材料id)))
	_刷新消耗几率(面板, "材料框/消耗几率", 配置)

	# 旧/新对照 + 保存/取消：只有这一页有（原版 `EquipPropLianZhiPanel`）。
	# 两列抬头取自 `EQUIPPROPLIANZHIPANEL_OLD_PROP_LABEL` / `..._NEW_PROP_LABEL`；
	# **新属性那列是金色**（`EquipPropLianZhiPanel.as:210` 那个 16773120），别写成白的。
	_configure_label(面板.get_node("原属性") as Label, 12, Color.WHITE)
	(面板.get_node("原属性") as Label).text = "原属性"
	_configure_label(面板.get_node("新属性") as Label, 12, Color("fff000"))
	(面板.get_node("新属性") as Label).text = "新属性"

	# 进页面时先复原成"还没洗"的样子，等预览回包再打开。
	_洗数值面板 = 面板
	_洗数值面板件 = _洗数值件键(选中)
	_复原洗数值界面(面板)
	# 扣材料那帧会先到并把本页整页重建掉，所以预览存在窗口上、重建后在这里补回去
	# （否则玩家保存/取消的入口连一次都看不到）。
	if not _洗数值预览.is_empty():
		_填洗数值对照(面板, {"plus_attributes": _洗数值预览}, false)
	var 保存 := 面板.get_node("保存") as Button
	var 取消 := 面板.get_node("取消") as Button
	for 对 in [[保存, true], [取消, false]]:
		var 按钮 := 对[0] as Button
		_configure_standard_button(按钮)
		for 连接 in 按钮.pressed.get_connections():
			按钮.pressed.disconnect(连接["callable"])
		按钮.pressed.connect(_提交洗数值.bind(面板, bool(对[1])))


## 「洗附加数值」页当前挂着的面板 —— 收到预览回包时要往上填旧/新对照。
## 离开这一页（`_配置面板页` 把面板 free 掉）时置空。
var _洗数值面板: Control = null
## 这份面板画的是**哪一件**（`_洗数值件键` 的结果）。原地刷新只改材料数/对照，
## 换了放入件就必须整页重建 —— 否则放好的图标/品质框/悬停框还停在上一次那件上
## （2026-11-05 用户报「放入的装备除右侧第一件外都不显示装备图标」，实测就是原地刷新
## 把换件那一步吞掉了，槽里一直是最初那件的图标）。
var _洗数值面板件 := ""
## 待玩家「保存 / 取消」的那份预览。**必须跨整页重建活着**：
## 服务端 `_forge_wash_plus_attributes` 的顺序是「先扣材料（发库存帧）→ 再发 1819」，
## 而扣材料的库存帧会走 `_on_资源帧 → _refresh_current`，把本页连面板一起重建
## （`_配置面板页` 还会把 `_洗数值面板` 置空）⇒ 预览刚摊开就被拆掉，
## 玩家看到的就是"洗了但什么都没发生"（2026-11-03 用户报「根本没有实装」）。
var _洗数值预览: Array = []
## 「洗附加属性」页前后对照的**洗前快照**（模块 4 没有预览/保存协议：服务端
## `_forge_change_aptitude` 洗成功即落盘，只回库存/装备帧）。所以对比只能在点之前
## 记一份旧列表、等装备帧把新列表写进会话后再并排画出来（2026-11-04 用户要求）。
## 三项一起用：旧列表 + 那件装备的 id/槽位；换件、换页签、离开本页都清空。
var _洗属性旧值: Array = []
var _洗属性旧id := ""
var _洗属性旧格 := 0
var _洗属性面板: Control = null
var _洗属性待旧值: Array = []
var _洗属性保留对照 := false
var _打造自动选中 := false
var _打造自动目标 := {}
var _打造请求 := {}
var _打造自动计时: SceneTreeTimer = null
var _打造应答计时: SceneTreeTimer = null
## 物品 id → 装备元数据。`数据/物品装备元数据.json` 的键是**八位补零**写法（`01010023`），
## 而线上传过来的 id 常是去零的（`1010023`），两种都试。
static var _装备元表: Dictionary = {}

## —— 「梦幻属性符」窗（`MengHuanPropResetWindow`，2026-11-03）——
## 窗上只存**定位键**（背包格 + id），每次渲染现读 `_session.inventory` 重解析：
## 原版 `itemDatachanged:435-450` 也是按 `_itemData.position` 从 dataCenter 重取，
## 取不到或 id 变了就 `backItemToEquip()`；重置成功的库存帧会把本页整页重建。
var _梦幻_装备格 := 0        # 背包格（1 基）；0 = 没放
var _梦幻_装备id := ""
var _梦幻_材料格 := 0        # 梦幻属性符那一格（1 基）
var _梦幻_材料id := ""
var _梦幻_选中 := 0          # 选中的附加属性序号（**1 基**，原版 `PropItem.prop.index`）

## —— 「橙装打造」窗（`YellowEquipLianZhiWindow`，376×407，2026-11-04）——
## 两个页签 0 = 橙装打造、1 = 橙装精炼；装备同样只存**定位键**（背包格 + id），
## 每次渲染现读会话（原版 `itemDatachanged:427-443` 的重取口径）。
var _橙装_页 := 0
var _橙装_装备格 := 0
var _橙装_装备id := ""


## 把「洗附加数值」页复原成"还没洗"的样子：只留说明 + 开始重置。
## 原版对应两条路 —— `showView()`（`EquipPropLianZhiPanel.as:284-300`）与
## `backItemToEquip()`（`:520-533`），两处都是同一组开关。
func _复原洗数值界面(面板: Control) -> void:
	if 面板 == null or not is_instance_valid(面板):
		return
	(面板.get_node("说明") as RichTextLabel).visible = true
	(面板.get_node("开始重置") as Button).visible = true
	var 对照 := 面板.get_node("对照区") as Control
	for 旧 in 对照.get_children():
		对照.remove_child(旧)
		旧.queue_free()
	for 名 in ["原属性", "新属性", "对照区", "保存", "取消"]:
		var 节点 := 面板.get_node_or_null(名) as CanvasItem
		if 节点 != null:
			节点.visible = false


## 填「洗附加数值」的**旧/新对照**。出处 `EquipPropLianZhiPanel.drawPropView`（`:78-157`）。
##
## 版式：每行 20 高；左列 x=0、右列 x=75（= 左列宽 70 + 5），标记跟在右列之后。
## 颜色：左列整条白；右列**名字白、只有数值和标记变色** ——
##   新 < 旧 → 红 + `↓` ；新 > 旧且没到顶 → 绿 + `↑` ；到/超上限 → 绿 + `★` ；没变 → 白。
func _填洗数值对照(面板: Control, 回包: Dictionary, 可提示: bool = true) -> void:
	var 新列表 := 回包.get("plus_attributes", []) as Array
	if 新列表.is_empty():
		return          # 没洗出预览（服务端那句"没有可洗练的附加属性"）→ 界面不动
	# ⚠️ "切到对照态"这几个开关只能放在**这里**（收到预览那条路）。
	# 第一版放进了内层的 `_画洗数值对照`，而"保存/取消"收尾时也会调它 ——
	# 结果刚收起的按钮又被自己画回来（回归用例逮到的）。
	(面板.get_node("说明") as RichTextLabel).visible = false
	(面板.get_node("开始重置") as Button).visible = false
	for 名2 in ["原属性", "新属性", "对照区", "保存", "取消"]:
		(面板.get_node(名2) as CanvasItem).visible = true
	_画洗数值对照(面板, 新列表)
	# 新旧完全一样时给一句解释 —— 服务端对 `旧值 >= 上限` 的条目**原样返回**
	# （页面说明原话「达到满属性后再次重置将不会改变」），此时右列没有任何标记，
	# 不解释就看起来像"洗练没生效"（用户 2026-11-01 报的 1.1 就是这个观感）。
	var 旧列表 := _会话选中().get("plus_attributes", []) as Array
	var 一样 := not 旧列表.is_empty()
	for 序号 in mini(旧列表.size(), 新列表.size()):
		if int((旧列表[序号] as Dictionary).get("attribute_value", 0)) \
				!= int((新列表[序号] as Dictionary).get("attribute_value", 0)):
			一样 = false
			break
	if 一样 and 可提示:
		_通知("本次洗练数值没有变化（达到满属性后不再改变）")


## `新列表` 为空数组 = **只画旧值那一列**。
## 原版 `drawPropView` 的 `param2` 就是干这个的：单参调用（`param2 == null`）时
## 右列内容写成 `" "`、也不要标记。洗完（保存**和**取消都一样）都回到这个状态 ——
## 不是把对照区收起来。
##
## ⚠️ 版式照 `EquipPropLianZhiPanel.drawPropView`（`:110-166`）用 **FormItem2** 摆，
## 不是把"名+值"塞进一列：
##   * 每件 FormItem2 = 标题 70 + gap 4 + 内容 45，整体 119 宽（`FormItem2.setTitleAndContentSize`）；
##   * 旧件 x=0、新件 x = 旧件宽 + 5 = 124，标记贴新件右沿 = 243（`:`_loc15_.setPosition(_loc12_.x + _loc12_.width, y - 2)`）；
##   * 旧件标题/内容、新件标题全是 16777215 白，新件标题是 16773120(#FFF000) 金，新值/标记按升降变色。
## 2026-11-04 用户报"排版不够整齐、有堆叠"：旧实现把 `"名　值"` 写进 70 宽一列、
## 新列名字又只给 45 宽 —— 像「技能等级加成」这种 6 字名（12 号 ≈ 72px）整条往左溢出，
## 新旧两列叠在一起。拆成标题列/内容列后，标题最长溢出 2px，与右列不再重叠。
func _画洗数值对照(面板: Control, 新列表: Array) -> void:
	var 选中 := _会话选中()
	var 旧列表 := 选中.get("plus_attributes", []) as Array

	# 上限表：`drawPropView` 里那句 `ItemFactory.getEquipMaxPropValue(id, stage, subAttrType)`
	# —— 就是 装备打造表.取附加属性上限。用来判"到没到顶"（到顶画 ★ 而不是 ↑）。
	var 元 := _装备元(String(选中.get("id", "")))
	var 上限 := {}
	for 条目 in 装备打造表.取附加属性上限(
			_装备阶数(选中), String(元.get("type_name", ""))).values():
		if 条目 is Dictionary:
			上限[String((条目 as Dictionary).get("type", ""))] = int((条目 as Dictionary).get("valueTo", 0))

	var 对照 := 面板.get_node("对照区") as Control
	for 旧 in 对照.get_children():
		对照.remove_child(旧)
		旧.queue_free()
	for 序号 in 旧列表.size():
		var 旧条 := 旧列表[序号] as Dictionary
		var 类型 := int(旧条.get("attribute_type", 0))
		var 旧值 := int(旧条.get("attribute_value", 0))
		# 没有新值（单列模式）时右列留空 —— 照原版 `_loc10_ = " "`。
		var 有对照 := 序号 < 新列表.size()
		var 新值 := int((新列表[序号] as Dictionary).get("attribute_value", 0)) if 有对照 else 旧值
		var 名 := String(装备提示框.属性名.get(类型, "属性%d" % 类型))
		var 顶 := int(上限.get(String(装备提示框.属性英文名.get(类型, "")), 0))
		var 色 := Color.WHITE
		var 标记 := ""
		if not 有对照:
			pass
		elif 新值 < 旧值:
			色 = Color("ff0000"); 标记 = "↓"
		elif 新值 > 旧值:
			色 = Color("00ff00"); 标记 = "★" if (顶 > 0 and 新值 >= 顶) else "↑"
		elif 顶 > 0 and 新值 >= 顶:
			色 = Color("00ff00"); 标记 = "★"
		var y := float(序号) * 20.0
		# 旧件（标题 0..70 / 内容 74..119），全白。
		_加到对照(对照, 名, Vector2(0.0, y), Vector2(70.0, 20.0), Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		_加到对照(对照, str(旧值), Vector2(74.0, y), Vector2(45.0, 20.0), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		# 新件（标题 124..194 / 内容 198..243），标题金、内容按升降变色。
		_加到对照(对照, 名, Vector2(124.0, y), Vector2(70.0, 20.0), Color("fff000"), HORIZONTAL_ALIGNMENT_RIGHT)
		_加到对照(对照, "+%d" % 新值 if 有对照 else " ", Vector2(198.0, y), Vector2(45.0, 20.0), 色, HORIZONTAL_ALIGNMENT_LEFT)
		if not 标记.is_empty():
			_加到对照(对照, 标记, Vector2(243.0, y - 2.0), Vector2(20.0, 20.0), 色, HORIZONTAL_ALIGNMENT_LEFT)




func _加到对照(父: Control, 文本: String, 位置: Vector2, 尺寸: Vector2, 色: Color, 对齐: int) -> void:
	var 标签 := Label.new()
	标签.text = 文本
	标签.position = 位置
	标签.size = 尺寸
	标签.horizontal_alignment = 对齐
	标签.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_configure_label(标签, 12, 色)
	父.add_child(标签)


## 保存 / 取消。出处 `clicLeftBtnHandler`（`:481-495`，保存 → 动作 19 的 `true`）与
## `clickRightBtnHandler`（`:497-511`，取消 → `false`）。
## ⚠️ 这两个按钮就是"洗附加数值能不能真的落盘"的**唯一**入口 ——
## 在这之前客户端全项目都没有人调用过动作 19（见 §3.18.21）。
func _提交洗数值(面板: Control, 接受: bool) -> void:
	# 保存/取消都结束这一轮预览；后面的整页重建不再把它补回来。
	_洗数值预览.clear()
	var 选中 := _会话选中()
	# ⚠️ **先复原界面再发请求** —— 原版的次序就是这样（`clicLeftBtnHandler` 先摆按钮、
	# 再 `requestSelectPlusValue`；`:481-495`）。我第一版把"没连服务端就 return"放在复原之前，
	# 结果离线时界面卡在对照态出不来（回归用例逮到的）。
	# 洗完不管保存还是取消，都回到**只画旧值那一列**（原版紧接着那句 `drawPropView(旧列表)`）。
	(面板.get_node("开始重置") as Button).visible = true
	(面板.get_node("保存") as CanvasItem).visible = false
	(面板.get_node("取消") as CanvasItem).visible = false
	_画洗数值对照(面板, [])
	if 选中.is_empty():
		return
	var 后端 = _backend
	if 后端 == null or not bool(后端.in_game):
		_show_hint("洗练需要连接原版服务端")
		return
	var 位置 := int(选中.get("slot_index", 选中.get("equip_position", _selected_strengthen_slot)))
	后端.request_select_plus_value(位置, 接受)
	_show_hint("附加数值洗练已保存" if 接受 else "附加数值洗练已取消")


## 这一件装备的**阶数**。
##
## ⚠️ **不要**读 `选中.get("stage")` —— 服务端那条物品帧里**根本没有 stage**
## （`后端连接._parse_item_entry` 那 29 个字段里没有它），那样写**永远拿到默认值 1**，
## 于是刻印 / 天生 / 洗附加数值 / 进阶**全都在查 stage1 的配置**（2026-09-23 逮到的）。
## 阶数在 `数据/物品装备元数据.json` 的 `物品.<八位id>.stage`，提示框那边也是这么取的。
func _装备阶数(选中: Dictionary) -> int:
	return maxi(1, int(_装备元(String(选中.get("id", ""))).get("stage", 1)))


## 天生是否已满（100%）。服务端 `_forge_born_attribute` 的掷点上限就是
## `round(base * randint(10,100)/100)` ⇒ `天生值 == 基础值` 即顶，之后永远不再上涨。
## 基础值缺失（0）时**不算满**，别把"没有数据"当成"已满"把功能锁死。
func _天生已满(选中: Dictionary) -> bool:
	var 基础 := int(选中.get("base_attr_value", 0))
	return 基础 > 0 and int(选中.get("born_attr_value", 0)) >= 基础


## 物品 id → 装备元数据条目（`stage` / `type_name`）。
func _装备元(物品id: String) -> Dictionary:
	if _装备元表.is_empty():
		var 解析: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/物品装备元数据.json"))
		_装备元表 = 解析 as Dictionary if typeof(解析) == TYPE_DICTIONARY else {}
	var 物品: Dictionary = _装备元表.get("物品", {}) as Dictionary
	var 候选: Array[String] = [物品id, 物品id.lstrip("0")]
	if 物品id.is_valid_int():
		候选.append(str(int(物品id)).pad_zeros(8))
	for 键 in 候选:
		var 条: Variant = 物品.get(键, null)
		if typeof(条) == TYPE_DICTIONARY:
			return 条 as Dictionary
	return {}


## 「刻印」页（`EquipKeYinPanel`）。配置 = `EquipSystem.carve.req.<阶数>`（`装备打造表.取刻印`）。
## 文案三段取自语言表 `EQUIPLIANZHIWINDOW_KE_YIN_*`；
## ⚠️ 说明里的占位是 **`%1`**（`CN.replaceString`），**不是** `★`。
func _配置刻印页(page: Control, 面板: Control) -> void:
	var 选中 := _会话选中()
	var 有装备 := not 选中.is_empty()
	_configure_original_panel(面板.get_node("材料框") as Panel)
	for 名 in ["装备格", "材料框/材料一/材料格"]:
		(面板.get_node(名) as TextureRect).texture = load(ORIGINAL_SLOT) as Texture2D
	(面板.get_node("装备格/装备图标") as TextureRect).texture = 		load(String(选中.get("icon", ""))) as Texture2D if 有装备 and ResourceLoader.exists(String(选中.get("icon", ""))) else null
	# 0.1：放入格带品质外框 + 流光（原版 `SimpleItemCell.showIcon`）。
	_挂装备品质(面板.get_node("装备格") as Control, 选中 if 有装备 else {})
	var 放入 := 面板.get_node("放入装备") as Button
	_configure_standard_button(放入)
	放入.text = "取出装备" if 有装备 else "放入装备"
	放入.pressed.connect(_点打造放入钮.bind(page))
	_挂打造落点(面板.get_node("装备格") as Control)

	var 配置 := 装备打造表.取刻印(_装备阶数(选中))
	var 材料id := int(配置.get("needItemId", 0))
	var 材料名 := 装备打造表.物品名(材料id)
	(面板.get_node("材料框/材料一/材料名") as Label).text = 材料名
	_configure_label(面板.get_node("材料框/材料一/材料名") as Label, 12, Color("#ff9100"))
	(面板.get_node("材料框/材料一/材料格/材料图标") as TextureRect).texture = GAME_DATA.item_icon(材料id) if 材料id != 0 else null
	# 角标 = **需要数**（`EquipKeYinPanel.as:124`），没放装备清空（`:110/117` 的 " "+套灰）。
	# 我们原先摆的是**拥有数** —— 和别的页串了口径（2026-10-01 扫出）。
	var 需要数 := int(配置.get("needItemCnt", 0))
	var 拥有 := 装备打造表.拥有数(_session, 材料id)
	(面板.get_node("材料框/材料一/材料格/材料数量") as Label).text = str(需要数) if 有装备 else ""
	_配置材料数量(面板.get_node("材料框/材料一/材料格/材料数量") as Label)
	_套格子灰(面板.get_node("材料框/材料一/材料格") as CanvasItem,
			not 有装备 or 需要数 > 拥有)
	_接打造装备提示(page, 面板.get_node("装备格"), 选中 if 有装备 else {})
	_接打造提示(page, 面板.get_node("材料框/材料一/材料格"), 材料id, 需要数)
	# 「购买」= 原版 `ItemCaiLiaoBox.buyHandler:46-55` 那跳 `REQUEST_CASH_ITEM_INFO`（§3.125 那条链）。
	var 购买 := 面板.get_node("材料框/材料一/购买") as Button
	_configure_standard_button(购买, 购买钮尺寸)
	购买.disabled = 材料id <= 0
	if 材料id > 0:
		购买.pressed.connect(请求商城商品.bind(str(材料id)))

	# 三段文案（语言表 `EQUIPLIANZHIWINDOW_KE_YIN_*`），说明里的 %1 → 材料名
	var 说明 := String("<font color='#ff9100'>装备刻印步骤说明：</font><br/><font color='#ffffff'>1：请在左侧装备框放入要操作的装备<br/>2：装备好<font color='#00ff00'>%1</font>（放在包裹中即可）<br/>3：点“开始刻印”按钮开始刻印</font>")
	(面板.get_node("说明") as RichTextLabel).text = 译文为BBCode(说明.replace("%1", 材料名))
	var 注意 := String("<font color='#00ff00'>装备刻印成功将随机增加一条秘印属性<br/></font><font color='#ffffff'>已经刻印的装备也可以重新刻印<br/></font><font color='#ff0000'>装备刻印成功后，将会与您绑定</font>")
	(面板.get_node("注意") as RichTextLabel).text = 译文为BBCode(注意)
	_configure_label(面板.get_node("标签") as Label, 12, Color("#ff9100"))
	(面板.get_node("标签") as Label).text = "* 为装备新增加一条异常强大的尾兽秘印属性"
	# 那一整块文本：原版 `EQUIP_STRENGTH_DESC_TEMPLATE_0`（同其它页那两行的措辞）
	_刷新消耗几率(面板, "材料框/消耗文本", 配置)
	# 放过**已刻印过的装备**时，原版在这两行上面还有一行"秘印属性"（`EquipKeYinPanel.as:319-334`）——
	# 我们以前整个丢了。措辞两个分支照抄；原版绿字套色这条（节点是 Label）登记欠账。
	if 有装备 and int(选中.get("carve_id", 0)) != 0:
		var 秘印行 := _刻印秘印行(选中)
		if not 秘印行.is_empty():
			var 消耗 := 面板.get_node("材料框/消耗文本")
			消耗.set("text", 秘印行 + "\n" + str(消耗.get("text")))


## 秘印行（原 320-332 两分支）：
##   抬头 `秘印属性：`（`MTOOL_MIYIN_SHUXING`）**不带色**（默认白），
##   冒号后**整段绿**（原版 `<font color='#00ff00'>` 从这里起）：
##   到顶 = `<名> <属性><值>%` + `MTOOTIP_MANMENGHUAN_ZHI`（去 font 标签后是"    【梦幻满值】"）；
##   没到顶 = 同上 + `（最大<value_max>%）`（`MTOOL_ZUIDA` = "最大"）。
## 属性名 = `getKeYinStr(carve_type)` → `SUB_ATTR_TYPE_NAMES[indexOf(SUB_ATTR_TYPES, type)]`
## （`MToolTipItem.as:46-49`）——和 `装备提示框.属性名` 同一张表。
## 消耗文本 2026-10-01 起是 RichTextLabel，绿字这才真挂上了（原先 Label 上只能舍色）。
func _刻印秘印行(选中: Dictionary) -> String:
	var 配置 := 装备打造表.取刻印值(int(选中.get("carve_id", 0)))
	if 配置.is_empty():
		return ""
	var 属性名 := String(装备提示框.属性名.get(int(选中.get("carve_type", 0)), ""))
	var 身 := String(配置.get("name", "")) + " " + 属性名 + str(int(选中.get("carve_value", 0))) + "%"
	if int(选中.get("carve_value", 0)) == int(配置.get("value_max", 0)):
		身 += "    【梦幻满值】"
	else:
		身 += "（最大%d%%）" % int(配置.get("value_max", 0))
	return "秘印属性：[color=#00ff00]%s[/color]" % 身


## 「洗附加属性」页（`EquipPropResetPanel`）。
## 配置 = `EquipSystem.changeAptitude` + `apt<资质>` 覆盖（见 装备打造表.取洗附加属性）。
## 文案 = `EQUIP_STRENGTH_DESC_TEMPLATE_5`，两个 `★` 分别换两个材料名
## （`★` 就是语言表里的 `REPLACE_FLAG`，见 §3.18.12）。
func _配置洗附加属性页(page: Control, 面板: Control) -> void:
	var 选中 := _会话选中()
	var 有装备 := not 选中.is_empty()
	_configure_original_panel(面板.get_node("材料框") as Panel)
	for 名 in ["装备格", "材料框/材料一/材料格", "材料框/材料二/材料格"]:
		(面板.get_node(名) as TextureRect).texture = load(ORIGINAL_SLOT) as Texture2D
	(面板.get_node("装备格/装备图标") as TextureRect).texture = 		load(String(选中.get("icon", ""))) as Texture2D if 有装备 and ResourceLoader.exists(String(选中.get("icon", ""))) else null
	# 0.1：放入格带品质外框 + 流光（原版 `SimpleItemCell.showIcon`）。
	_挂装备品质(面板.get_node("装备格") as Control, 选中 if 有装备 else {})
	var 放入 := 面板.get_node("放入装备") as Button
	_configure_standard_button(放入)
	放入.text = "取出装备" if 有装备 else "放入装备"
	放入.pressed.connect(_点打造放入钮.bind(page))
	_挂打造落点(面板.get_node("装备格") as Control)

	var 配置 := 装备打造表.取洗附加属性(int(选中.get("aptitude", 1)))
	var 材料一id := int(配置.get("needItemId", 0))
	var 材料二id := int(配置.get("helpItemId", 0))
	var 材料一名 := 装备打造表.物品名(材料一id)
	var 材料二名 := 装备打造表.物品名(材料二id)

	# 原版 `showView()`（`:330`）：
	#   `TEMPLATE_5[0].replace(★, needItem名) + "\r" + TEMPLATE_5[1].replace(★, helpItem名)`
	# —— **两段各有一个 ★，分别换成两个材料名**（不是同一个名字换两处）。
	var 说明一 := String("<font color='#ff9100'>附加属性重置步骤说明：</font><br/>1：请在左侧装备框放入要操作的装备<br/>2：装备好<font color='#00ff00'>★</font><font color='#ffffff'>（放入包裹中即可）<br/>3：点“开始重置”按钮即可开始强化操作</font>")
	说明一 = 说明一.replace(文案占位, 材料一名)
	var 说明二 := String("<font color='#ff9100'>注意：</font><br/><font color='#ffffff'>附加属性重置成功后，你装备的附加属性将随机重新生成，若在包裹中备有</font><font color='#00ff00'>★</font><font color='#ffffff'>将可提高强化成功概率，并且放入的越多，则出现的属性越好</font>")
	说明二 = 说明二.replace(文案占位, 材料二名)
	(面板.get_node("说明") as RichTextLabel).text = 译文为BBCode(说明一 + "\n" + 说明二)
	# `TEMPLATE_5[2]`
	_configure_label(面板.get_node("标签") as Label, 12, Color("#ff9100"))
	(面板.get_node("标签") as Label).text = "* 重新生成附加属性的条数、类型和数值大小"

	# 角标/灰度按 `_caiLiao1`/`_caiLiao2` **两套不同口径**（`EquipPropResetPanel.as`）：
	#   材料一（必备）：**需要数**（`:137/339`），灰 = 需要 > 拥有（`:426-430` 的 `count >= need`）；
	#   材料二（幸运符）：**拥有数**（`:149` `isBagExistItem`），灰 = 拥有 ≤ 0（`hasItem()`）；
	#   没放装备：一格清角标（`:88` " "）、两格都套灰（`:99-100`）。
	# 我们以前两格都摆**拥有数**、也从不灰 —— 2026-10-01 扫出。
	for 侧 in [["材料一", 材料一id, 材料一名, "need"], ["材料二", 材料二id, 材料二名, "have"]]:
		var 节点 := 面板.get_node("材料框/%s" % 侧[0]) as Control
		(节点.get_node("材料名") as Label).text = String(侧[2])
		_configure_label(节点.get_node("材料名") as Label, 12, Color("#ff9100"))
		(节点.get_node("材料格/材料图标") as TextureRect).texture = GAME_DATA.item_icon(int(侧[1])) if int(侧[1]) != 0 else null
		var 拥有 := 装备打造表.拥有数(_session, int(侧[1]))
		var 角标 := ""
		var 要灰 := not 有装备
		if 有装备:
			if String(侧[3]) == "need":
				角标 = str(int(配置.get("needItemCnt", 0)))
				要灰 = int(配置.get("needItemCnt", 0)) > 拥有
			else:
				角标 = str(拥有)
				要灰 = 拥有 <= 0
		else:
			角标 = " "        # 原版没放时清成 " "（不是空串，照抄）
		if 节点.has_node("材料格/材料数量"):
			(节点.get_node("材料格/材料数量") as Label).text = 角标
			_配置材料数量(节点.get_node("材料格/材料数量") as Label)
		_套格子灰(节点.get_node("材料格") as CanvasItem, 要灰)
		_接打造提示(page, 节点.get_node("材料格"), int(侧[1]), 1)
		# 「购买」= 原版 `ItemCaiLiaoBox.buyHandler:46-55` 那跳 `REQUEST_CASH_ITEM_INFO`（§3.125 那条链）。
		var 购买 := 节点.get_node("购买") as Button
		_configure_standard_button(购买, 购买钮尺寸)
		var 这件材料id := int(侧[1])
		购买.disabled = 这件材料id <= 0
		if 这件材料id > 0:
			购买.pressed.connect(请求商城商品.bind(str(这件材料id)))

	# 消耗/几率两行：`EQUIP_STRENGTH_DESC_TEMPLATE_0` 的措辞。
	# 2026-10-01：改走 `_刷新消耗几率`（唯一口径）—— 手动那句既没接幸运符联动、
	# 也没有原版的"金币不够标红"（`EquipPropResetPanel.as:420`）。
	_刷新消耗几率(面板, "材料框/消耗几率", 配置)
	var 勾选 := 面板.get_node("材料框/使用幸运符") as CheckBox
	_configure_checkbox(勾选)
	var 下拉 := 面板.get_node("材料框/幸运符数量") as OptionButton
	_配置幸运符下拉(下拉)
	for 值 in range(1, 10):
		下拉.add_item(str(值), 值)
	var 上限 := 装备打造表.幸运符上限(配置)
	勾选.disabled = 上限 <= 0
	下拉.disabled = 上限 <= 0 or not 勾选.button_pressed
	_接线幸运符刷新(面板, 勾选, 下拉, 配置)
	_configure_label(面板.get_node("材料框/单位") as Label, 12, Color.WHITE)
	(面板.get_node("材料框/单位") as Label).text = "个%s" % 材料二名     # COMMON_GE = "个%1"
	_接打造装备提示(page, 面板.get_node("装备格"), 选中 if 有装备 else {})

	# 洗前快照还在、且服务端已经把新列表写回会话 ⇒ 用说明那块位置摊开旧/新两列
	# （与「洗附加数值」共用场景里的 原属性/新属性/对照区 三件，版式也照它）。
	_洗属性面板 = 面板
	(面板.get_node("说明") as CanvasItem).visible = true
	_刷新洗属性对照(面板)


func _清洗属性快照() -> void:
	_洗属性旧值.clear()
	_洗属性待旧值.clear()
	_洗属性保留对照 = false


# 请求快照与正在显示的对照分开，扣材料引发重建也不能闪回说明。
func _开始洗属性对照(选中: Dictionary) -> void:
	_洗属性待旧值 = (选中.get("plus_attributes", []) as Array).duplicate(true)
	_洗属性旧id = String(选中.get("id", ""))
	_洗属性旧格 = int(选中.get("slot_index", 选中.get("equip_position", _selected_strengthen_slot)))
	if _洗属性旧值.is_empty():
		_洗属性旧值 = _洗属性待旧值.duplicate(true)
	elif _洗属性旧值 != _洗属性待旧值:
		_洗属性保留对照 = true


## 收起对照，只留说明。洗完/换件/没快照时都走这里。
## ⚠️ 说明必须一并亮回来：洗失败（回包与快照相同）时上一轮成功会把说明藏掉，
##    只藏对照会留下一块空白区。
func _藏洗属性对照(面板: Control) -> void:
	for 名 in ["原属性", "新属性", "对照区"]:
		var 节点 := 面板.get_node_or_null(名) as CanvasItem
		if 节点 != null:
			节点.visible = false
	var 说明 := 面板.get_node_or_null("说明") as CanvasItem
	if 说明 != null:
		说明.visible = true
	var 对照 := 面板.get_node_or_null("对照区") as Control
	if 对照 == null:
		return
	for 旧 in 对照.get_children():
		对照.remove_child(旧)
		旧.queue_free()


## 快照 vs 会话里的新列表：**类型和数值都按序号逐条比**（洗附加属性会换类型，
## 不能像"洗附加数值"那样只比数值）。完全一样（失败/没洗）⇒ 不摊对照。
func _刷新洗属性对照(面板: Control) -> void:
	if 面板 == null or not is_instance_valid(面板):
		return
	var 选中 := _会话选中()
	if 选中.is_empty() or _洗属性旧值.is_empty() \
			or String(选中.get("id", "")) != _洗属性旧id:
		_藏洗属性对照(面板)
		return
	var 当前格 := int(选中.get("slot_index", 选中.get("equip_position", _selected_strengthen_slot)))
	if _洗属性旧格 != 0 and 当前格 != _洗属性旧格:
		_藏洗属性对照(面板)
		return
	var 新列表 := 选中.get("plus_attributes", []) as Array
	if 新列表.size() != _洗属性旧值.size():
		_藏洗属性对照(面板)
		return
	var 一样 := true
	for 序号 in 新列表.size():
		var 旧条 := _洗属性旧值[序号] as Dictionary
		var 新条 := 新列表[序号] as Dictionary
		if int(旧条.get("attribute_type", 0)) != int(新条.get("attribute_type", 0)) \
				or int(旧条.get("attribute_value", 0)) != int(新条.get("attribute_value", 0)):
			一样 = false
			break
	if 一样 and not _洗属性保留对照:
		_藏洗属性对照(面板)
		return
	(面板.get_node("说明") as CanvasItem).visible = false
	for 名 in ["原属性", "新属性", "对照区"]:
		(面板.get_node(名) as CanvasItem).visible = true
	_画洗属性对照(面板, _洗属性旧值, 新列表)


## 两列版式与 `_画洗数值对照` 完全一致（AS3 FormItem2：标题 70 + 内容 45，
## 新件 x=124、标记 x=243）。差别只有：右列是**新的类型名**，所以每行要单独取名字；
## 类型没变时才按数值升降变色/打 ↑↓★，换了类型就保持白色、不打标记。
func _画洗属性对照(面板: Control, 旧列表: Array, 新列表: Array) -> void:
	var 选中 := _会话选中()
	var 元 := _装备元(String(选中.get("id", "")))
	var 上限 := {}
	for 条目 in 装备打造表.取附加属性上限(
			_装备阶数(选中), String(元.get("type_name", ""))).values():
		if 条目 is Dictionary:
			上限[String((条目 as Dictionary).get("type", ""))] = int((条目 as Dictionary).get("valueTo", 0))

	var 对照 := 面板.get_node("对照区") as Control
	for 旧 in 对照.get_children():
		对照.remove_child(旧)
		旧.queue_free()
	for 序号 in 旧列表.size():
		var 旧条 := 旧列表[序号] as Dictionary
		var 新条 := 新列表[序号] as Dictionary
		var 旧类型 := int(旧条.get("attribute_type", 0))
		var 新类型 := int(新条.get("attribute_type", 0))
		var 旧值 := int(旧条.get("attribute_value", 0))
		var 新值 := int(新条.get("attribute_value", 0))
		var 旧名 := String(装备提示框.属性名.get(旧类型, "属性%d" % 旧类型))
		var 新名 := String(装备提示框.属性名.get(新类型, "属性%d" % 新类型))
		var 色 := Color.WHITE
		var 标记 := ""
		if 新类型 == 旧类型:
			var 顶 := int(上限.get(String(装备提示框.属性英文名.get(新类型, "")), 0))
			if 新值 < 旧值:
				色 = Color("ff0000"); 标记 = "↓"
			elif 新值 > 旧值:
				色 = Color("00ff00"); 标记 = "★" if (顶 > 0 and 新值 >= 顶) else "↑"
			elif 顶 > 0 and 新值 >= 顶:
				色 = Color("00ff00"); 标记 = "★"
		var y := float(序号) * 20.0
		_加到对照(对照, 旧名, Vector2(0.0, y), Vector2(70.0, 20.0), Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		_加到对照(对照, str(旧值), Vector2(74.0, y), Vector2(45.0, 20.0), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		_加到对照(对照, 新名, Vector2(124.0, y), Vector2(70.0, 20.0), Color("fff000"), HORIZONTAL_ALIGNMENT_RIGHT)
		_加到对照(对照, "+%d" % 新值, Vector2(198.0, y), Vector2(45.0, 20.0), 色, HORIZONTAL_ALIGNMENT_LEFT)
		if not 标记.is_empty():
			_加到对照(对照, 标记, Vector2(243.0, y - 2.0), Vector2(20.0, 20.0), 色, HORIZONTAL_ALIGNMENT_LEFT)


## 「进阶」页（`EquipUpgradeWindow.updateView`，`:120-160`）。
## 配置取 `EquipSystem.stageup.stage<下一阶>`（`StringTool.getStageUpEquipConfig`），
## 已经在 `数据/装备打造.json` 里（§3.17）。
func _配置进阶页(page: Control, 面板: Control) -> void:
	var 选中 := _会话选中()
	var 有装备 := not 选中.is_empty()
	_configure_original_panel(面板.get_node("结果区") as Panel)
	for 名 in ["装备格", "结果格", "材料一/材料格", "材料二/材料格"]:
		(面板.get_node(名) as TextureRect).texture = load(ORIGINAL_SLOT) as Texture2D

	# 装备盒里的两格：放进去的 / 进阶后会变成的
	(面板.get_node("装备格/装备图标") as TextureRect).texture = \
		load(String(选中.get("icon", ""))) as Texture2D if 有装备 and ResourceLoader.exists(String(选中.get("icon", ""))) else null
	(面板.get_node("结果格/结果图标") as TextureRect).texture = null
	# 0.1：放入格带品质外框 + 流光（原版 `SimpleItemCell.showIcon`）。
	_挂装备品质(面板.get_node("装备格") as Control, 选中 if 有装备 else {})
	var 放入 := 面板.get_node("放入装备") as Button
	_configure_standard_button(放入)
	放入.text = "取出装备" if 有装备 else "放入装备"     # DROP_ITEM_BTN_NAMES[1] / [0]
	放入.pressed.connect(_点打造放入钮.bind(page))
	_挂打造落点(面板.get_node("装备格") as Control)

	# 站位文案（`EQUIP_UPGRADE_DESCS_1`，`en_US$message_properties.as`）
	(面板.get_node("说明") as RichTextLabel).text = 译文为BBCode(
		"<font color='#ff9100'>装备合成可以让你将低阶装备合成为高阶装备<br/>合成成功你将获得全新的高阶装备<br/>合成失败将扣除材料，装备不会有任何改变</font>")
	# `EQUIPUPGRAFEWINDOW_XIN_FUN_DESC`（`:2099`）
	_configure_label(面板.get_node("幸运符说明") as Label, 12, Color("#ff9100"))
	(面板.get_node("幸运符说明") as Label).text = "*放入的幸运符越多，进阶成功的几率越大"

	var 阶数 := _装备阶数(选中) + 1
	var 配置 := 装备打造表.取进阶(阶数) if 有装备 else 装备打造表.取进阶(2)
	var 材料一id := int(配置.get("needItemId", 0))
	var 材料二id := int(配置.get("helpItemId", 0))
	var 材料一名 := 装备打造表.物品名(材料一id)
	var 材料二名 := 装备打造表.物品名(材料二id)
	(面板.get_node("材料一/材料名") as Label).text = 材料一名
	(面板.get_node("材料二/材料名") as Label).text = 材料二名
	_configure_label(面板.get_node("材料一/材料名") as Label, 12, Color("#ff9100"))
	_configure_label(面板.get_node("材料二/材料名") as Label, 12, Color("#ff9100"))
	(面板.get_node("材料一/材料格/材料图标") as TextureRect).texture = GAME_DATA.item_icon(材料一id) if 材料一id != 0 else null
	(面板.get_node("材料二/材料格/材料图标") as TextureRect).texture = GAME_DATA.item_icon(材料二id) if 材料二id != 0 else null
	# 两格角标口径**不一样**（`EquipUpgradeWindow.as`）：
	#   `_fu1`（必备）= **需要数**（`:344`，只在放了装备时写；back/开窗态是 " "）；
	#   `_fu4`（幸运符）= **拥有数**（`:156` **无条件**写，back 不清）；
	#   灰：`_fu1` = 需要 > 拥有（`:292-296`），`_fu4` = 拥有 ≤ 0（`hasItem()` `:298`）；
	#   没放装备两格都套灰（`:432-433`）。
	var 需要数 := int(配置.get("needItemCnt", 0))
	var 拥有一 := 装备打造表.拥有数(_session, 材料一id)
	var 拥有二 := 装备打造表.拥有数(_session, 材料二id)
	(面板.get_node("材料一/材料格/材料数量") as Label).text = str(需要数) if 有装备 else " "
	_配置材料数量(面板.get_node("材料一/材料格/材料数量") as Label)
	(面板.get_node("材料二/材料格/材料数量") as Label).text = str(拥有二)
	_配置材料数量(面板.get_node("材料二/材料格/材料数量") as Label)
	_套格子灰(面板.get_node("材料一/材料格") as CanvasItem, not 有装备 or 需要数 > 拥有一)
	_套格子灰(面板.get_node("材料二/材料格") as CanvasItem, not 有装备 or 拥有二 <= 0)
	_接打造装备提示(page, 面板.get_node("装备格"), 选中 if 有装备 else {})
	_接打造提示(page, 面板.get_node("材料一/材料格"), 材料一id, 需要数)
	_接打造提示(page, 面板.get_node("材料二/材料格"), 材料二id, 拥有二)
	# 「购买」= 原版 `ItemCaiLiaoBox.buyHandler:46-55` 那跳 `REQUEST_CASH_ITEM_INFO`（§3.125 那条链）。
	for 名 in ["材料一", "材料二"]:
		var 购买 := 面板.get_node("%s/购买" % 名) as Button
		_configure_standard_button(购买, 购买钮尺寸)
		var 这件材料id := 材料一id if 名 == "材料一" else 材料二id
		购买.disabled = 这件材料id <= 0
		购买.tooltip_text = "购买材料"
		if 这件材料id > 0:
			购买.pressed.connect(请求商城商品.bind(str(这件材料id)))

	# `EQUIP_UPGRADE_CAILIAO_DESCS_1`：把 "1" 换成材料一名、"4" 换成材料二名（照 AS3 的 replace 次序）
	var 材料说明 := String("<font color='#ffffff'>1：为装备合成的必备材料<br/>4：提高升阶合成的成功概率</font><br/><font color='#00ff00'>装备进阶成功后，新的装备将保持原有装备的强化等级和附加属性</font>")
	材料说明 = 材料说明.replace("1", 材料一名).replace("4", 材料二名)
	(面板.get_node("材料说明") as RichTextLabel).text = 译文为BBCode(材料说明)

	# 结果区：勾选 + 幸运符 1~9 + 单位
	var 勾选 := 面板.get_node("结果区/使用幸运符") as CheckBox
	_configure_checkbox(勾选)
	var 下拉 := 面板.get_node("结果区/幸运符数量") as OptionButton
	_配置幸运符下拉(下拉)
	for 值 in range(1, 10):
		下拉.add_item(str(值), 值)
	# 原版联动：`_comboBox.enabled = _checkBox3.selected`（勾了才让选颗数）；
	# 上限是配置里的 `maxHelpCnt`（进阶是 9，所以下拉正好 1..9）。
	var 幸运符上限 := 装备打造表.幸运符上限(配置)
	勾选.disabled = 幸运符上限 <= 0
	下拉.disabled = 幸运符上限 <= 0 or not 勾选.button_pressed
	for 连接 in 勾选.toggled.get_connections():
		勾选.toggled.disconnect(连接["callable"])
	_接线幸运符刷新(面板, 勾选, 下拉, 配置)
	_configure_label(面板.get_node("结果区/单位") as Label, 12, Color.WHITE)
	(面板.get_node("结果区/单位") as Label).text = "个%s" % 材料二名     # COMMON_GE = "个%1"
	# 结果区顶部那两行 —— **原版进阶页也有**（实机图核过），措辞与强化页一致
	_刷新消耗几率(面板, "结果区/结果文本", 配置)


## 左栏：说明 / 注意 / 标签 / 放入装备 / 材料框 / 开始强化。
## 原版这五件在 case 0（强化）与 case 4（天生）走的是同一条**公共尾**
## （`EquipStrengthWindow.as:296-302`），其余五页各有专属面板（`_配置面板页`）。
## 共用尾在专属页上也照跑，但那一列整体被 `_render_strengthen` 的名单藏掉，画面看不到。
func _配置打造左栏(page: Control) -> void:
	var 选中 := _会话选中()
	var 有装备 := not 选中.is_empty()
	(page.get_node("内容容器/装备格/装备图标") as TextureRect).texture = \
		load(String(选中.get("icon", ""))) as Texture2D if 有装备 and ResourceLoader.exists(String(选中.get("icon", ""))) else null
	# 0.1：放入格带品质外框 + 流光（原版 `SimpleItemCell.showIcon`）。
	_挂装备品质(page.get_node("内容容器/装备格") as Control, 选中 if 有装备 else {})
	var 放入 := page.get_node("内容容器/放入装备") as Button
	_configure_standard_button(放入)
	# `EQUIP_STRENGTH_DROP_ITEM_BTN_NAMES[0]/[1]` = 放入装备 / 取出装备（`:985` / `:984`）
	放入.text = "取出装备" if 有装备 else "放入装备"
	放入.pressed.connect(_点打造放入钮.bind(page))
	_挂打造落点(page.get_node("内容容器/装备格") as Control)
	# 「购买」先禁用：这一页的**材料 id 要等下面按页签算出 `配置` 才知道**，
	# 算出来之后（`var 材料id := …` 那行下面）再启用并接线。见那条注释。
	(page.get_node("内容容器/材料框/购买") as Button).disabled = true
	var 自动勾 := page.get_node("内容容器/材料框/自动强化") as CheckBox
	自动勾.disabled = not 有装备
	自动勾.set_pressed_no_signal(_打造自动选中)
	自动勾.toggled.connect(_设置打造自动)

	var 页名: String = 打造页签[clampi(_strengthen_tab, 0, 打造页签.size() - 1)]
	自动勾.text = "自动强化到满天生" if 页名 == "天生" else "自动强化到10级"
	var 说明 := page.get_node("内容容器/说明") as RichTextLabel
	var 注意 := page.get_node("内容容器/注意") as RichTextLabel
	var 标签 := page.get_node("内容容器/标签") as Label
	var 材料名 := page.get_node("内容容器/材料框/材料名") as Label
	var 数量 := page.get_node("内容容器/材料框/材料格/材料数量") as Label
	var 材料图标 := page.get_node("内容容器/材料框/材料格/材料图标") as TextureRect
	# 「消耗几率」2026-10-01 起是 RichTextLabel（金币不够要标红，原版 `￥` 的红色替换）——
	# 字号/颜色在场景里用 theme override 定（12/白），这里只拿节点、按名字写文本。
	var 消耗几率 := page.get_node("内容容器/材料框/消耗几率")
	var 执行 := page.get_node("开始强化") as Button
	_configure_standard_button(执行)
	_configure_label(标签, 12, Color("#ff9100"))
	_configure_label(材料名, 12, Color("#ff9100"))
	_配置材料数量(数量)

	# 这条左栏只服务「强化」与「天生」两页（原版 case 0 / case 4 走公共尾）；
	# 其余五页在 `_配置面板页` 各走各的专属面板。走到这里时那五页的件虽然照样被填，
	# 但**整列都被藏掉**（`_render_strengthen` 的显隐名单），画面看不到。
	var 配置 := {}
	if 页名 == "强化":
		配置 = 装备打造表.取强化(mini(int(选中.get("strengthen", 0)) + 1, 装备打造表.强化上限))
		执行.text = "开始强化"          # STRENGTH_BTN_NAMES[0]
	elif 页名 == "天生":
		# 原版 case 4：`EquipManager.getStrengthTianShengPropCfg(位置, 阶数)`（`:600-615`）——
		# 材料数/成功率**按部位**取（`born.EquipA..L`），金币**按阶**取（`born.needMoney.stageN`）。
		# ⚠️ 非标准 12 槽（神器/灵器/忍具/羁绊…）没有天生配置，`取天生` 会返回空 ——
		# 那时只出文案不出数（不编数）。
		# ⚠️ 部位从**放着那件的 id** 现算（放进背包件时 `_selected_strengthen_slot`
		#   不是它的位 —— 照游标查会查错部位的天生表）。
		var 天生部位 := 装备部位.位置(String(选中.get("id", "")))
		if 天生部位 == 0:
			天生部位 = _selected_strengthen_slot
		配置 = 装备打造表.取天生(天生部位, _装备阶数(选中))
		执行.text = "开始强化"          # STRENGTH_BTN_NAMES[0]
	else:
		执行.text = "该页专属面板未接"

	var 模板: Array = 打造文案.get(页名, [])
	if 模板.is_empty():
		说明.text = ""
		注意.text = "[color=#ff9100]该页的专属面板尚未接。[/color]"
		标签.text = ""
	else:
		var 材料显示名 := ""
		if not 配置.is_empty():
			材料显示名 = 装备打造表.物品名(int(配置.get("needItemId", 0)))
		说明.text = 译文为BBCode(String(模板[0]).replace(文案占位, 材料显示名))
		注意.text = 译文为BBCode(String(模板[1]).replace(文案占位, 材料显示名))
		# 标签是 MGlowLabel（纯文本，不带标签），**不要**过翻译
		标签.text = String(模板[2])

	# 公共尾（`:296-302`）：材料图标 / 数量 / 名字 / 消耗与几率
	if 配置.is_empty():
		材料图标.texture = null
		数量.text = ""
		材料名.text = ""
		消耗几率.set("text", "本次操作消耗金币：0\n本次操作成功几率：0%")
		_套格子灰(page.get_node("内容容器/材料框/材料格") as CanvasItem, true)
		_接打造提示(page, page.get_node("内容容器/装备格"), 0)
		_接打造提示(page, page.get_node("内容容器/材料框/材料格"), 0)
		执行.disabled = true
		return
	var 材料id := int(配置.get("needItemId", 0))
	材料图标.texture = GAME_DATA.item_icon(材料id) if 材料id != 0 else null
	数量.text = str(int(配置.get("needItemCnt", 0)))
	材料名.text = 装备打造表.物品名(材料id)
	# 「购买」= 原版 `ItemCaiLiaoBox.buyHandler:46-55` 那跳 `REQUEST_CASH_ITEM_INFO`
	# （`id = itemCell.itemData.id`）⇒ 走 `请求商城商品` 统一出口（§3.125 那条链）。
	# 材料 id 从这一刻起才是对的，所以接线放在这儿、不在函数开头。
	var 购买钮 := page.get_node("内容容器/材料框/购买") as Button
	_configure_standard_button(购买钮, 购买钮尺寸)
	购买钮.disabled = 材料id <= 0
	购买钮.tooltip_text = "购买材料"
	if 材料id > 0:
		购买钮.pressed.connect(请求商城商品.bind(str(材料id)))
	# 灰度（`EquipStrengthWindow.as:615-619`）：放了东西按"需要 > 拥有"套灰；
	# 没放整格套灰（`:925` backItemToEquip 的默认 true）。角标**恒为需要数**（`:295`）。
	_套格子灰(page.get_node("内容容器/材料框/材料格") as CanvasItem,
			not 有装备 or int(配置.get("needItemCnt", 0)) > 装备打造表.拥有数(_session, 材料id))
	# **原版这两行的原文**（`_textField`，`EquipStrengthWindow.as` 的 updateView）：
	#   本次操作消耗金币：N / 本次操作成功几率：N%
	# 没放装备时原版就显示 0 / 0%（实机核过），不是占位。
	_刷新消耗几率(page, "内容容器/材料框/消耗几率", 配置)
	# ⚠️ "强化满级就禁用"只属于**强化页** —— 旧写法把同一条罩在共用尾上，
	# **天生页跟着遭殃**（强化到顶的件天生按钮点不动）。原版的等级闸在
	# `strengthHandler` 的强化 case（`EQUIP_STRENGTH_MAX_LEVEL`），天生没有这条：
	# 天生的"顶"是 100%（天生=基础），那是服务端掷点的效果、不是按钮的理由。
	# ⚠️ 2026-11-04 用户明确要求：**满天生后不再可点**（服务端原来没有上限闸，
	# 满了还能点、还扣金币和材料）。所以天生页在 `天生值 >= 基础值` 时也禁用；
	# 服务端 `_forge_born_attribute` 同步加闸，两步都不可省。
	执行.disabled = (not 有装备) or not _打造请求.is_empty() or not _打造自动目标.is_empty() \
			or (页名 == "强化" and int(选中.get("strengthen", 0)) >= 装备打造表.强化上限) \
			or (页名 == "天生" and _天生已满(选中))
	执行.pressed.connect(_执行打造.bind(page))
	_接打造装备提示(page, page.get_node("内容容器/装备格"), 选中 if 有装备 else {})
	_接打造提示(page, page.get_node("内容容器/材料框/材料格"), 材料id, int(配置.get("needItemCnt", 0)))


## 打造页格子的悬停详情框（#6）。
##
## 原版两处都挂 `MToolTipItem`：材料格是 `SimpleItemCell.as:220`
## `MToolTipItem.createToolTip(PopUpMananger.stage, this, this._itemData)`，
## 放入装备那块是 `ItemDropBox` 的同源提示。我们复用的正是背包/仓库/人物装备格
## 那一份 `格子提示框.接线`（同一个 `MToolTipItem.as:73-109` 分发口径）。
##
## ⚠️ 打造页的格子是 `TextureRect`，场景里 `mouse_filter = 2`（IGNORE）⇒ 永远不会有
## `mouse_entered`。这里抬到 **PASS**：PASS 只收悬停信号、**不吞点击/拖放**
## （换成 STOP 会盖住底下「放入装备」与拖放命中链）。
## ⚠️ 提示框节点挂在**外层页面**（`装备强化窗口.tscn` 根）上，不在各子面板里 ——
## 所以第二个参数恒传 `page`（`_render_strengthen` 那个页面），不是 `面板`。
##
## ⚠️ **装备格必须带实例数据**（`实例` 非空）：只喂 `{id, quantity}` 时提示框只能按物品模板画
## 白板（原版 `MToolTipItem` 拿的是 `EqpData`，强化星级/附加属性/资质/刻印都在这份数据里）。
## 2026-11-01 用户报「放入装备那格只显示白板属性」—— 根因就是这里只传了 id。
func _接打造提示(page: Control, 格子: Control, 物品id: int, 数量: int = 1,
		实例: Dictionary = {}) -> void:
	if 格子 == null:
		return
	if 格子.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		格子.mouse_filter = Control.MOUSE_FILTER_PASS
	var 物品 := {}
	if not 实例.is_empty():
		物品 = 实例.duplicate(true)
		物品["id"] = String(物品.get("id", str(物品id)))
	elif 物品id > 0:
		物品 = {"id": str(物品id).pad_zeros(8), "quantity": maxi(1, 数量)}
	格子提示框.接线(self, page, 格子, 物品)


## 装备格的提示框：把**这一件**的实例整份交出去（原版 `SimpleItemCell` 的 `itemData`）。
func _接打造装备提示(page: Control, 格子: Control, 实例: Dictionary) -> void:
	if 实例.is_empty():
		_接打造提示(page, 格子, 0)
		return
	_接打造提示(page, 格子, int(实例.get("id", 0)), 1, 实例)


## 给页面临时挂上两套悬停详情框（场景里没有）。原版这些格子全是 `SimpleItemCell`
## / `ItemCaiLiaoBox`，每枚都挂 `MToolTipItem`（`SimpleItemCell.as:220`）。
func _给页挂提示框(page: Control) -> void:
	for 项 in [["物品提示框", 物品提示场景], ["装备提示框", 装备提示场景]]:
		var 名 := str(项[0])
		if page.get_node_or_null(名) != null:
			continue
		var 框 := (项[1] as PackedScene).instantiate() as Control
		框.name = 名
		框.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(框)


## 兑换窗的成品格 + 六枚碎片格接悬停（十拳剑 / 忍具两扇窗结构一模一样）。
## 碎片"有几个"不影响提示内容 —— 展示的是物品本身，所以空着也照样能悬停。
func _接兑换提示(page: Control, 成品格路: String, 成品id: int, 碎片表: Array) -> void:
	_接打造提示(page, page.get_node_or_null(成品格路) as Control, 成品id)
	for i in 碎片表.size():
		_接打造提示(page, page.get_node_or_null(
			"子面板/碎片格%d/碎片格%d_格" % [i + 1, i + 1]) as Control, int(碎片表[i]))


## 右栏「部位列表」：选"要操作的**已装备部位**"。
##
## 出处：
##   * 列表来源 `EquipManager.getStrengthEquipItems()` —— **先列身上穿着的**（`putOn = true`），
##     再列背包里的（`putOn = false`），两边都过 `isStrengthListEquip` 那层筛。
##   * 筛掉：时装、玉链、徽章、宠物装备、变身卡（角色/宠物）。
##   * 行 = `ItemPanelRanderer`（135x44）：图标 40x40 @(2,2)、名字 @(47,2) 宽 86、
##     「强化N」@(47,22) 宽 40、「已装备」@(91,22) 宽 86（**黄色粗体，只有穿着时才显示**，
##     `ZHUANGBEIWANFA_YI_ZHUANG_BEI` = "已装备"）；`MENU_QIANGHUA` = "强化"，所以是"强化11"。
##   * 网格 = `ItemPanel.drawList`：**2 列 x 6 行一页**，行距 46、列距 137，起点 (8,4)。
##   * 页签筛选 = `EquipItemPanel.onTabChanged`。
##
## ⚠️ **`EquipAptitudeType` 的常量名与颜色是交叉的**（和 §3.12.1 那个 `EquipAptitudeGreenF`
## 是同一类坑）：`EquipColors` 里 `BLUE`(=2) 是 `0x08FF19`（**绿**）、`GREEN`(=3) 是
## `0x009CFF`（**蓝**）。所以原版"**绿色页筛 2、蓝色页筛 3**"是**对的** ——
## 照常量名改成反过来才是错。下面的 `资质` 映射因此就是恒等的 [0,1,2,3,4]。
const 部位列表页名 := ["全部", "白色", "绿色", "蓝色", "紫色"]
const 部位列表资质 := [0, 1, 2, 3, 4]
## 一页 2 列 x 6 行（`ItemPanel.as:15-17`）
const 部位列表列数 := 2
const 部位列表行数 := 6


func _配置部位列表(page: Control) -> void:
	for 序号 in 部位列表页名.size():
		var 按钮 := page.get_node_or_null("列表分页/%s" % 部位列表页名[序号]) as Button
		if 按钮 == null:
			continue
		_apply_tab_skin(按钮)
		选页签(按钮, 序号 == _部位列表页)
		按钮.pressed.connect(func(): _部位列表页 = 序号; _refresh_current())
	_渲染部位列表行(page)
	_渲染翻页条(page)


## 翻页条（`ItemPanel` 的 `PageComponent`）：首页 / 上一页 / `N/M` / 下一页 / 末页。
## 一页 2 列 x 6 行 = 12 件，页数 = `ceil(件数 / 12)`（`onTabChanged` 里那个 `reset` 的分母）。
func _渲染翻页条(page: Control) -> void:
	var 条 := page.get_node_or_null("翻页条") as Control
	if 条 == null:
		return
	var 材料 := _部位列表物品()
	var 要资质 := int(部位列表资质[clampi(_部位列表页, 0, 部位列表资质.size() - 1)])
	var 件数 := 0
	for 物品 in 材料:
		if 要资质 == 0 or int((物品 as Dictionary).get("aptitude", 1)) == 要资质:
			件数 += 1
	var 每页 := 部位列表列数 * 部位列表行数
	var 页数 := maxi(1, int(ceil(float(件数) / float(每页))))
	_部位列表页码 = clampi(_部位列表页码, 0, 页数 - 1)
	# 禁用判据照 `PageComponent.currentPage` 那个 setter：
	#   首页/上一页 在 `currentPage > 1` 时才 enabled；下一页/末页 在 `currentPage < totalPage` 时才 enabled。
	# ⚠️ 别用"目标页 == 当前页"这种自造判据 —— 那样上一页/下一页在只有一页时仍是亮的（真栽过）。
	var 首尾可点 := _部位列表页码 > 0
	var 后向可点 := _部位列表页码 < 页数 - 1
	for 名 in ["首页", "上一页", "下一页", "末页"]:
		var 按钮 := 条.get_node_or_null(名) as TextureButton
		if 按钮 == null:
			continue
		按钮.texture_normal = load("res://素材/界面/原版窗口/通用控件/%s.png" % 名) as Texture2D
		按钮.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
		按钮.disabled = not (首尾可点 if 名 in ["首页", "上一页"] else 后向可点)
		# 禁用态 = **同一张图套灰度**（原版 `MButton3.updateState` 对 DISABLED 走
		# `StyleUtil.getGrayFilter()`，系数见 `禁用灰度.gdshader`）。
		# 不是另一张素材，也不是压暗 —— 之前用 modulate.a=0.45 近似是错的。
		按钮.material = 禁用灰度材质() if 按钮.disabled else null
		for 连接 in 按钮.pressed.get_connections():
			按钮.pressed.disconnect(连接["callable"])
		var 目标: int = {"首页": 0, "上一页": _部位列表页码 - 1,
			"下一页": _部位列表页码 + 1, "末页": 页数 - 1}[名]
		按钮.pressed.connect(func(): _部位列表页码 = int(目标); _refresh_current())
	var 页码 := 条.get_node_or_null("页码") as Label
	if 页码 != null:
		页码.text = "%d/%d" % [_部位列表页码 + 1, 页数]
		# 原版页文本是**白色**（`PageComponent` 的 pageFormat），不是橙
		_configure_label(页码, 12, Color.WHITE)


func _渲染部位列表行(page: Control) -> void:
	var 容器 := page.get_node_or_null("列表内容") as Control
	if 容器 == null:
		return
	for 旧 in 容器.get_children():
		容器.remove_child(旧)
		旧.queue_free()
	# ⚠️ 这里**不要**顺手 `_洗数值面板 = null` —— 清的是右栏「部位列表」，跟那个面板没关系。
	# 我第一版用批量替换加那句，连这里一起改了，于是每次刷部位列表都把引用清掉，
	# 预览回包填不进去还顺手重建面板（把用例手里的面板 free 了）。
	var 要资质 := int(部位列表资质[clampi(_部位列表页, 0, 部位列表资质.size() - 1)])
	var 每页 := 部位列表列数 * 部位列表行数
	var 命中 := 0
	var 行序号 := 0
	for 物品 in _部位列表物品():
		if 要资质 != 0 and int((物品 as Dictionary).get("aptitude", 1)) != 要资质:
			continue
		# 跳过前面几页（`ItemPanel.updatePage`：`起点 = (页码-1) * 每页件数`）
		if 命中 < _部位列表页码 * 每页:
			命中 += 1
			continue
		命中 += 1
		if 行序号 >= 每页:
			break
		_建部位行(容器, 物品, 行序号, page)
		行序号 += 1


## 列表里的物件：**先身上、后背包**（照 `getStrengthEquipItems` 的次序）。
## ⚠️ 每件都要打 `put_on` 标（原版 `getStrengthEquipItems` 里 `putOn=true/false` 是
## 列表**装配时就知道的**事实），行上"已装备"与 `_选中部位` 的放入来源都据此。
## 以前"已装备"是拿 id 反查身上有没有同类 —— 背包里那件和身上穿的是**同一个 id** 时，
## 背包行也被错标成"已装备"（2026-10-01 扫出，新门 `装备打造放入回归测试` 钉着这条）。
func _部位列表物品() -> Array:
	var 结果: Array = []
	for 位置 in _session.equipped_items:
		var 物品: Variant = _session.equipped_items[位置]
		if typeof(物品) == TYPE_DICTIONARY and not (物品 as Dictionary).is_empty() \
				and _算不算部位列表装备(物品 as Dictionary):
			var 穿着件: Dictionary = (物品 as Dictionary).duplicate(true)
			穿着件["put_on"] = true
			结果.append(穿着件)
	for 物品 in _session.inventory:
		if typeof(物品) == TYPE_DICTIONARY and _算不算部位列表装备(物品 as Dictionary):
			var 背包件: Dictionary = (物品 as Dictionary).duplicate(true)
			背包件["put_on"] = false
			结果.append(背包件)
	return 结果


## `isStrengthListEquip` 的等价物（`EquipManager.as:254-287`）。
##
## 原版先 `ItemFactory.IItem2ItemData(param1) as EqpData`，**转不出 EqpData 的一律 return false**
## ⇒ 灵器(LingQiData)/忍具(RenJuData)/昆虫(KunChongData)/神器(ShenQiData)/羁绊 这些
## 根本不是 EqpData，天然不在列表里；再排掉时装、玉链、徽章、变身卡、宠物装备。
## 客户端没有那套数据类，等价判据 = **位置必须落在原版 `EquipAptitudeType`/`EqpData`
## 覆盖的标准 12 槽**（武器…斗篷）—— 这一条同时把灵器(-23)/忍具(-24)/昆虫(-200..-205)/
## 徽章(-22)/神器(-100/-101)/羁绊(-50)/玉链/变身/宠物(正数)全部挡在外面。
## ⚠ 2026-11-04 用户报「右侧还显示昆虫/灵器/忍具/徽章」：旧版只排了 120/121/141 与宠物槽，
##   灵器忍具昆虫照样混进来（它们过得了 `是装备`）。
func _算不算部位列表装备(物品: Dictionary) -> bool:
	var 物品id := String(物品.get("id", ""))
	if not 装备部位.是装备(物品id):
		return false
	if not 装备部位.标准槽.has(装备部位.位置(物品id)):
		return false
	# ⚠️ 按位置的解析一律用**八位补零**那一份：服务端下发的 id 是整数形态（七位），
	#    而原版 `ItemType` / `EquipmentPosition` 读的是 `lpad(id, 8)`（同 物品菜单.gd 那段说明）。
	var 补零 := 物品id.pad_zeros(8) if 物品id.is_valid_int() else 物品id
	# 时装：`isItemAShiZhuang` = lpad(id,8).substr(2,2) == "21"
	return 补零.substr(2, 2) != "21"


## 一行：图标 40x40 @(2,2) / 名字 @(47,2) / 强化N @(47,22) / 已装备 @(91,22)
func _建部位行(容器: Control, 物品: Dictionary, 序号: int, page: Control) -> void:
	var 列 := 序号 % 部位列表列数
	var 行 := 序号 / 部位列表列数
	var 根 := Control.new()
	根.position = Vector2(列 * 137 + 8, 行 * 46 + 4)
	根.size = Vector2(135.0, 44.0)
	根.mouse_filter = Control.MOUSE_FILTER_PASS
	容器.add_child(根)

	var 底 := Panel.new()
	底.size = Vector2(135.0, 44.0)
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	根.add_child(底)
	_configure_original_panel(底)

	var 格 := TextureRect.new()
	格.position = Vector2(2.0, 2.0)
	格.size = Vector2(40.0, 40.0)
	格.mouse_filter = Control.MOUSE_FILTER_IGNORE
	格.texture = load(ORIGINAL_SLOT) as Texture2D
	根.add_child(格)
	var 图 := TextureRect.new()
	图.set_anchors_preset(Control.PRESET_FULL_RECT)
	图.offset_left = 2.0
	图.offset_top = 2.0
	图.offset_right = -2.0
	图.offset_bottom = -2.0
	图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 图标路径 := String(物品.get("icon", ""))
	if ResourceLoader.exists(图标路径):
		图.texture = load(图标路径) as Texture2D
	格.add_child(图)

	# 资质框 + 紫橙流光：`SimpleItemCell.showIcon`（`:156-182`）—— 框贴 (-1,-1)、
	# 流光贴 (3,3)，条件与背包格同一套，全在 `脚本/单例/装备品质.gd` 那张表里。
	# 列表行**没有**灵气粉框分支（原版也没有），所以 `含灵气` 用默认的 false。
	装备品质脚本.挂覆盖层(格, 物品)

	var 名 := Label.new()
	名.position = Vector2(47.0, 2.0)
	名.size = Vector2(86.0, 16.0)
	名.text = String(物品.get("name", ""))
	名.clip_text = true
	名.mouse_filter = Control.MOUSE_FILTER_IGNORE
	根.add_child(名)
	_configure_label(名, 12, Color("#f5ead6"))

	var 强化 := Label.new()
	强化.position = Vector2(47.0, 22.0)
	强化.size = Vector2(40.0, 16.0)
	强化.text = "强化%d" % int(物品.get("strengthen", 0))     # MENU_QIANGHUA = "强化"
	强化.mouse_filter = Control.MOUSE_FILTER_IGNORE
	根.add_child(强化)
	_configure_label(强化, 12, Color("#f5ead6"))

	# 「已装备」只在**身上穿着**时显示（`_icon.visible = putOn`），黄色粗体
	# ⚠️ 用装配时打的 `put_on` 标，别拿 id 反查 —— 背包行和身上同 id 时会错标（§3.21 尾注）。
	var 穿着 := bool(物品.get("put_on", _item_is_worn(物品)))
	var 已装备 := Label.new()
	已装备.position = Vector2(91.0, 22.0)
	已装备.size = Vector2(44.0, 16.0)
	已装备.text = "已装备" if 穿着 else ""
	已装备.mouse_filter = Control.MOUSE_FILTER_IGNORE
	根.add_child(已装备)
	_configure_label(已装备, 12, Color("#ffdd55"))

	# 绑定锁：`SimpleItemCell.showIcon` 里
	#   `if(this._showBingIcon){ if(!this._itemData.canTrade){ new LockedIcon() } }`，
	# 摆在图标格局部 (3, 40 - 锁高 - 3)。素材是 **MainLib 符号 724**，
	# 用 `开发工具/导出原版符号.ps1 -符号 724` 导出（单帧静态符号，作者期 == 运行时）。
	# ⚠️ `_showBingIcon` 为真时原版走的是 **else 分支** —— 只画锁，**不画强化角标**。
	if not bool(物品.get("can_trade", true)):
		var 锁路径 := "res://素材/界面/原版窗口/通用控件/绑定锁.png"
		if ResourceLoader.exists(锁路径):
			var 锁 := TextureRect.new()
			锁.texture = load(锁路径) as Texture2D
			锁.position = Vector2(3.0, 40.0 - 锁.texture.get_height() - 3.0)
			锁.mouse_filter = Control.MOUSE_FILTER_IGNORE
			格.add_child(锁)

	# 点一行 = 把这个部位放进左栏（原版 `clickItemFun = dropItemHandler`）
	var 按下 := Button.new()
	按下.flat = true
	按下.size = Vector2(135.0, 44.0)
	按下.focus_mode = Control.FOCUS_NONE
	根.add_child(按下)
	按下.pressed.connect(_选中部位.bind(物品))
	# 悬停详情框：原版这一行里面就是 `SimpleItemCell`（`ItemPanelRanderer.as:150-160 ensureItemCell`
	# → `SimpleItemCell.as:220` `MToolTipItem.createToolTip(..., this._itemData)`），
	# 拿的是整件 `EqpData`。我们的行是手画的，2026-11-01 用户报「右侧装备栏悬停不显示详情框」——
	# 接线挂在**最上层那枚「按下」钮**上：图标被它整行盖住，挂格子节点收不到 `mouse_entered`。
	_接打造装备提示(page, 按下, 物品)


## 这一件是不是"身上穿着的那件"（对应原版的 `putOn`）。
func _item_is_worn(物品: Dictionary) -> bool:
	var 位置 := 装备部位.位置(String(物品.get("id", "")))
	if 位置 == 0:
		return false
	var 身上: Variant = _session.equipped_items.get(位置, {})
	return typeof(身上) == TYPE_DICTIONARY and not (身上 as Dictionary).is_empty()


## 点一行 = 放进左栏。**穿着的行**走部位游标、**背包的行**记住（格, id）——
## 原版 `dropItemHandler` 对两种行一视同仁（`_itemData.position` 背包件就是正格位，
## 发给服务端的打造请求也照这个位走）。
func _选中部位(物品: Dictionary) -> void:
	if _应用选中部位(物品):
		_refresh_current()


func _set_strengthen_tab(index: int) -> void:
	_strengthen_tab = index
	# 2.2：换页签 / 重开窗才把「精炼」下拉放回默认项 —— 原版 `EquipBaiLianPanel.showView()`
	# 就是 `onSelectedTypeHandler(null)`，用 `_comboBox` 的初始 index 0。同一页内的回包重建
	# **不**走这里（那时要保住玩家选的那一项）。
	_精炼项选中 = 装备打造表.精炼项_附加属性
	# ⚠️ 换页签 = 原版 `selectedBtnHandler`：它**先 `backItemToEquip()` 再摆页**（`:741`）——
	# 左栏放的件在换页时**清空**，每一页要重新点一行放进去。我们原来让放入态跨页签
	# 存活，是第二处"和原版长得不一样"（2026-10-01 核 `EquipStrengthWindow.as` 时抓的）。
	_清放入()
	# 换页签 = 原版重进面板，上一轮没保存的预览作废。
	_洗数值预览.clear()
	_清洗属性快照()
	_refresh_current()


func _on_item_change_result(_opcode: int, result: Dictionary) -> void:
	var kind := String(result.get("kind", ""))
	if int(_打造请求.get("页", -1)) == 6 and int(result.get("equipment_position", 0)) == int(_打造请求.get("格", 0)):
		var 预期 := "forge_strength" if int(_打造请求["项"]) == 装备打造表.精炼项_强化星级 else "forge_additive"
		if kind == 预期:
			_结束打造请求()
	var names := {
		"stone_merge": "宝石合成", "equipment_inlay": "装备镶嵌", "wash_plus_value": "附加数值洗练",
		"forge_strength": "强化精炼", "forge_additive": "附加属性精炼",
		"badge_stone_merge": "徽章石合成",
	}
	var operation := String(names.get(kind, "装备打造"))
	# 十拳剑炼制（2081）与人具开光（2082）：**原版一支提示都不发** —— 帧只往管理器递一句，
	# `LingQiManager.onLingEquipKaiGuangResult:302-304` 与 `onLingEquipHeChengResult` 是**空函数**，
	# 灵化/洗炼失败被 `if(param1 == 1)` 吞掉 ⇒ 这两族必须在通用提示**之前**分流出去，
	# 不然玩家每点一次「开光」都挨一句莫名其妙的「装备打造结果：…」（2026-10-24 补）。
	if kind == "ling_qi_result" or kind == "ren_ju_result":
		_处理灵器炼制回帧(kind, result)
		return
	# 昆虫强化（2066）：原版**只有** `onStengthResult:561-592` 那三句（成功 / 差一点 / 失败），
	# 槽位对不上时更是一句不发 ⇒ 通用那行「昆虫强化结果：成功」是原版没有的噪音，
	# 在这里分流走（与上面 2081/2082 同一处置，§3.270）。
	if kind == "kunchong_strength":
		人物窗口.收昆虫强化回帧(self, result as Dictionary)
		_refresh_current()
		return
	# 宝石合成的回包（`StoneWindow.operationResultHandler:43-49` → 合成页三格）：
	# 结果存宿主、下面的 `_refresh_current()` 重渲染时由 `_render_mining` 摆进 成功/退还/剩余。
	if kind == "stone_merge":
		_宝石合成结果 = (result as Dictionary).duplicate(true)
		# 勾玉合成走的是**同一条 1042**（成功率/页1 提交 `request_merge_jade`）。原版
		# `GouYuCompositePanel.operationResultHandler:61-103` 拿 `param1[0]/[3]/[6]` 摆
		# 成功/退还/剩余三格；页0/页2 那两个 handler 是**空函数** ⇒ 只在勾玉炼制窗停在第 1 页时接管，
		# 也不发通用那句「宝石合成结果：…」（原版这一支一句提示都没有）。
		if _页名() == "勾玉炼制" and bool(call("已打开")) and 勾玉炼制窗.当前页() == 1:
			勾玉炼制窗.收合成回帧(self, _宝石合成结果)
			_宝石合成结果 = {}
			_refresh_current()
			return
	# 徽章石合成的回包（`2317 HUI_ZHANG_STONE_MERGE_RES`，`Client.as:10020-10023` →
	# `StoneComposePane.updateResultAndLeftCel:114-124`）：成功/剩余两格**只有这一帧填得上**，
	# 它同时清掉投料格与产物格 —— 交给窗口自己存、`_refresh_current()` 重渲染时摆。
	if kind == "badge_stone_merge":
		徽章打造窗.收石合成回帧(result as Dictionary)
	# 0.5（用户 2026-11-01）：结果不要写在标题栏那条灰状态行上（`_show_hint`）—— 太不清晰。
	# 「精炼」两档原版就是 `API.ui.addNotice(EQUIPBAILIAN_JINGLIAN_SUCCESS / _FAIL)`
	# （`EquipBaiLianPanel.as:287-303` 与 `:336-352`；两句文案见
	# `en_US$message_properties.as:1086` / `:901`），照它改走屏幕通知。
	# 「洗附加数值」的回包**不只是**一行状态：它带回一份新词条预览，
	# 要摊成"原属性 / 新属性"两列并让玩家 保存/取消（原版 `operationResultHandler`，
	# `EquipPropLianZhiPanel.as:316-330`）。这一步不做的话，预览就白洗了。
	# ⚠ 这条必须在通用状态行**之前**分流：原版这里只摊对照、不发通知，而状态行那句
	# 「附加数值洗练结果：成功」会压在面板上（用户 2026-11-01 的 0.5 投诉）。
	# ⚠ 2026-11-03：判据改成**看当前页**，不再只看 `_洗数值面板` 活不活。扣材料那一帧
	# 先到、触发的整页重建会把面板 free 掉（`_洗数值面板` 置空）⇒ 回包到这里时面板已经是
	# 上一代，旧判据直接落进通用分支：对照不摊、还多一句"结果：成功"，玩家看到的就是
	# 「洗了但什么都没发生」。现在预览先存 `_洗数值预览`，面板活着就摊、重建后由
	# `_配置洗附加数值页` 补回去。
	if kind == "wash_plus_value" and _在洗数值页():
		var 预览 := result.get("plus_attributes", []) as Array
		if not 预览.is_empty():
			_洗数值预览 = 预览.duplicate(true)
		if _洗数值面板 != null and is_instance_valid(_洗数值面板):
			_填洗数值对照(_洗数值面板, result)
		return
	if kind == "forge_strength" or kind == "forge_additive":
		_通知("恭喜您精炼成功" if int(result.get("result", 0)) == 1 else "很抱歉，装备精炼失败")
	elif result.has("result"):
		_show_hint("%s结果：%s" % [operation, "成功" if int(result.result) == 1 else "失败（%d）" % int(result.result)])
	else:
		_show_hint("%s结果已返回" % operation)
	_refresh_current()


## 灵器炼制族**在场**的三页（`开光人具` 不算：那是另一支、走 2082 与 `RenJuManager`）。
const 灵器页 := ["洗练", "灵化", "开光"]

## 当前这一页的页名（`窗口管理` 那套「每页一扇窗」用 `_固定页`，裸开的窗用 `_current_page`）。
func _页名() -> String:
	return _固定页 if not _固定页.is_empty() else _current_page


## 装备打造窗是不是停在「洗附加数值」页签。
func _在洗数值页() -> bool:
	if _页名() != "装备强化":
		return false
	return 打造页签[clampi(_strengthen_tab, 0, 打造页签.size() - 1)] == "洗附加数值"


## 这张洗数值面板画的是哪一件：id + 放入来源 + 背包格 + 部位游标。
## 只比 id 不够 —— 同 id 的"身上那件"和"背包那件"是两行，换过去图标相同但不是同一件。
func _洗数值件键(件: Dictionary) -> String:
	if 件.is_empty():
		return ""
	return "%s|%s|%d|%d" % [String(件.get("id", "")), _强化放入来源,
		_强化放入格, _selected_strengthen_slot]


## 「洗附加数值」页收到库存/属性帧时的**原地刷新**：返回 true = 已刷完，别整页重建。
## 2026-11-04 用户报「洗附加数值显示有点卡顿，不够丝滑」：每扣一次材料都会来一帧库存，
## `_flush_refresh` 原来一律整页重建（页签/右栏/面板全拆再装回），画面闪一下，
## 刚摊开的对照也被 free 掉、下一帧再由 `_洗数值预览` 补回来。这一页真正会变的
## 只有材料数/灰度/消耗行和对照本身 ⇒ 原地改这几处即可。
## 面板不在了 / 装备被拿走 ⇒ 返回 false 交回整页重建（那边本来就有收面板的逻辑）。
func _原地刷新洗数值页() -> bool:
	if not _在洗数值页():
		return false
	var 面板 := _洗数值面板
	if 面板 == null or not is_instance_valid(面板):
		return false
	var 选中 := _会话选中()
	if 选中.is_empty():
		return false
	# 换了放入件 ⇒ 交回整页重建：图标/品质框/悬停框都跟着件走，原地刷新只认材料数。
	if _洗数值件键(选中) != _洗数值面板件:
		return false
	var 附加条数: int = (选中.get("plus_attributes", []) as Array).size()
	var 配置 := 装备打造表.取洗附加数值(_装备阶数(选中), maxi(1, 附加条数))
	var 材料id := int(配置.get("needItemId", 0))
	var 需要数 := int(配置.get("needItemCnt", 0))
	(面板.get_node("材料框/材料一/材料格/材料数量") as Label).text = str(需要数)
	_套格子灰(面板.get_node("材料框/材料一/材料格") as CanvasItem,
			需要数 > 装备打造表.拥有数(_session, 材料id))
	_刷新消耗几率(面板, "材料框/消耗几率", 配置)
	if not _洗数值预览.is_empty():
		_填洗数值对照(面板, {"plus_attributes": _洗数值预览}, false)
	return true


## 2081/2082 回帧的消费。原版 `LingEquipProcessor:53-73` / `RenJuProcessor:44-51` 把帧只往
## 管理器递一句：`LingQiManager` 成功才 `updateInfo:87-105`（给在场的开光/灵化/洗炼各调一次
## `showInfo`），`RenJuManager` 只把结果转给开光那扇。
## ⚠ 本工程这三扇是**独立实例**（`窗口管理._新建窗口` 每页一扇），原版三扇共用的是**单例
## 管理器上同一个 `plusAttr`** ⇒ 这里靠「每扇实例各自订同一根 `item_change_result_received`」
## 还原那次广播：同一发帧进每一扇，各扇只认自己那一页、把同一档值写进自己那份。
func _处理灵器炼制回帧(kind: String, 帧: Dictionary) -> void:
	if kind == "ren_ju_result":
		_处理人具开光回帧(帧)
		return
	if not 灵器页.has(_页名()):
		return
	var 动作 := int(帧.get("action", -1))
	# 开光(0) 与 合成(3) 那两支在原版是**空函数**（`onLingEquipKaiGuangResult:302-304`）⇒ 连重绘都没有；
	# 灵化/洗炼失败被外层 `if(param1 == 1)` 吞 ⇒ 界面一动不动。
	if 动作 != 1 and 动作 != 2:
		return
	if int(帧.get("result", 0)) != 1:
		return
	# 灵化成功硬置 **1**（`onLingEquipLingHuaResult:266` 写的就是字面量 1，**不是** 6 条 ×1 的和）；
	# 洗炼成功才走 `updatePlusAttr:278-281` 的「第一条数值 × 6」。
	# ⇒ 同一件剑灵化那一下会把洗炼窗从 +6 刷成 +1，这是**原版的账**，别"顺手"统一成 ×6。
	_灵器附加展示 = 1 if 动作 == 1 else _洗炼加成(帧)
	_refresh_current()


## 2082 那支（`RenJuManager.onRenJuKaiGuangResult:69-77` → `handleKaiGuangResult:70-77`）：
## 第一句**无条件**放回钮（失败也能重试），成功再 `setDOShow(RENJU_KAIGUANG_WINDOW,false)` 关窗。
## 成功那半原版还顺手把 `manager._itemId` 换成 65000002（`:71`）—— 本工程不自己改 id：
## 服务端 `_open_renju` 会重发那一格（clear + add），`_render_ling_forge` 每次按格现取就带上来了。
func _处理人具开光回帧(帧: Dictionary) -> void:
	if _页名() != 页_开光人具:
		return
	_灵器开光已点 = false
	if _灵器开始钮 != null and is_instance_valid(_灵器开始钮):
		_灵器开始钮.disabled = false
	if int(帧.get("result", 0)) == 1:
		close()


## 「宝石镶嵌与取出」窗（原版 `StoneCarryWindow`）——由**装备**菜单「宝石镶嵌」开。
## 装备还在不在、id 对不对，决定窗口去留（原版 `itemDatachanged:238-255`：拿不到或换件就 `onCloseBtnClick`）。
## 镶嵌窗的**模式**：宝石（动作 1/2）或勾玉（动作 13/14）。
## 原版是**两扇类**（`StoneCarryWindow` / `GouYuCarryWindow`），但版式**逐字相同**
## （`super(254,204)`、6 孔 HBox、两条说明，两处 `createChildren` 可逐行对照），
## 差别只有两样：`ITEM_NAMES[0]`=宝石 / `[1]`=勾玉 那个 `%1`，以及提交发的那条请求。
## ⇒ 本工程用**一扇窗 + 模式位**，不复制一份同样的场景。
var _镶嵌勾玉模式 := false

## 镶嵌窗的标题与两条说明（原版 `EQUIP_STONE_CARRY_WINDOW_TITLE`「%1镶嵌与取出」、
## `EQUIP_STONE_CARRY_DESCS = [DESCS_1(两行说明), DESCS_2(绿字费用)]`，都是 `%1` 替换）。
const 镶嵌标题 := {false: "宝石镶嵌与取出", true: "勾玉镶嵌与取出"}
const 镶嵌说明文 := {
	false: "[color=#ff9100]宝石镶嵌：[/color][color=#ffffff]将背包中的宝石拖入本窗口[/color]\n"
			+ "[color=#ff9100]宝石取出：[/color][color=#ffffff]点击本窗口中的宝石[/color]",
	true: "[color=#ff9100]勾玉镶嵌：[/color][color=#ffffff]将背包中的勾玉拖入本窗口[/color]\n"
			+ "[color=#ff9100]勾玉取出：[/color][color=#ffffff]点击本窗口中的勾玉[/color]",
}
const 取出说明文 := {
	false: "[color=#00ff00]宝石镶嵌与取出不消耗任何费用\n成功率为100%[/color]",
	true: "[color=#00ff00]勾玉镶嵌与取出不消耗任何费用\n成功率为100%[/color]",
}


## 玉链的孔数 = `EquipSystem.special.inlay.stage<阶>.count`
## （原版 `GouYuCarryWindow.getInalyCount:141-146`，配置在 `数据/装备打造.json` 的 `special` 段）。
static func 玉链孔数(阶: int) -> int:
	var 特: Dictionary = 装备打造表.取段("special")
	var 孔表 = 特.get("inlay", {})
	if not (孔表 is Dictionary):
		return 0
	var 条 = (孔表 as Dictionary).get("stage%d" % maxi(1, 阶), {})
	return int((条 as Dictionary).get("count", 0)) if 条 is Dictionary else 0


func _render_stone_carry() -> void:
	var page := _instantiate_page(宝石镶嵌页面场景)
	# 悬停详情框：原版每枚孔都是 `SimpleItemCell`，而它每次填图标都挂
	# `MToolTipItem.createToolTip(PopUpMananger.stage, this, this._itemData)`
	# （`SimpleItemCell.as:220`）⇒ 已镶的宝石/勾玉悬停要弹物品详情框（用户 2026-11-02 报
	# 「镶嵌的勾玉鼠标放上去没有镶嵌框」）。场景是 SPEC 生成物不手改 ⇒ 运行期挂，
	# 口径同 `勾玉炼制窗.建提示框`。
	_给页挂提示框(page)
	var 装备: Dictionary = _session._占用条(_session.inventory, _宝石镶嵌装备格) if _宝石镶嵌装备格 > 0 else {}
	# ⚠️ 两种"没装备"要分开（否则契约体检"逐页裸开"这页会因为自关而红，E1）：
	#   · 装备格号=0 = **裸开**（没有装备上下文）→ 摆一排空孔、窗留着；
	#   · 格号>0 但那件没了/换件 = 原版 `itemDatachanged:246-252` → 关窗。
	if _宝石镶嵌装备格 > 0 and (
			装备.is_empty() or String(装备.get("id", "")) != _宝石镶嵌装备id):
		_show_hint("镶嵌窗：装备已不在原格")
		close()
		return
	# 标题与两条说明随模式换（两族只差 `%1` 那个词）。
	设置标题(String(镶嵌标题[_镶嵌勾玉模式]))
	(page.get_node("镶嵌说明") as RichTextLabel).text = String(镶嵌说明文[_镶嵌勾玉模式])
	(page.get_node("取出说明") as RichTextLabel).text = String(取出说明文[_镶嵌勾玉模式])
	# 孔数：**玉链**走 `special.inlay.stage<阶>.count`（`GouYuCarryWindow.getInalyCount`）；
	# 其余装备橙装(资质>=5) 6 孔、否则 5（`_inlay_equipment_stone:54246-54252`）。
	var 是玉链 := 装备部位.位置(String(装备.get("id", ""))) == 装备部位.勾玉
	var 孔数 := 6 if int(装备.get("aptitude", 1)) >= 5 else 5
	# ⚠️ 阶数走 `_装备阶数`（`数据/物品装备元数据.json`），**不是** `装备.get("stage")` ——
	#    这条链的装备是**背包行**，那 29 个字段里没有 stage，读它永远是 1 ⇒ 六阶玉链也只剩 1 孔
	#    （2026-11-01 用户报「无论什么等级都只能镶一个勾玉」）。同 `:3966` 那段说明。
	if 是玉链:
		孔数 = clampi(玉链孔数(_装备阶数(装备)), 0, 6)
	var 宽 := 300 if 孔数 >= 6 else 254
	_镶嵌定宽(宽, page)
	var inlays: Array = 装备.get("inlays", [])
	var 面板 := page.get_node("孔面板") as Control
	for i in 6:
		var 孔 := 面板.get_node("孔_%d" % i) as Button
		孔.visible = i < 孔数
		if i >= 孔数:
			continue
		孔.孔号 = i
		孔.格子归属 = "宝石孔"          # 认领落点（`可拖拽格._can_drop_data` 要求非空）
		# 深色物品格底（原版孔是 `SimpleItemCell`，不是橙色按钮；同背包格口径）
		孔.theme_type_variation = WINDOW_SKIN.皮肤表.变体_物品格按钮
		孔.focus_mode = Control.FOCUS_NONE
		孔.icon = null
		孔.物品id = ""
		孔.清空品质覆盖层()
		var 孔物品 := {}
		if i < inlays.size():
			var 石: Dictionary = inlays[i] as Dictionary
			var 石id := str(int(石.get("stone_id", 0))).pad_zeros(8)
			if int(石.get("stone_id", 0)) > 0:
				孔物品 = {"id": 石id, "quantity": 1}
			孔.物品id = 石id
			var 图标 := String(GAME_DATA.item(石id).get("icon", ""))
			if not 图标.is_empty() and ResourceLoader.exists(图标):
				孔.icon = load(图标) as Texture2D
		# 先断再连（切页/回包重渲染会重复连，撞 "already connected" 刷屏，§3.10.6 坑2 同族）
		for 连 in 孔.请求镶嵌.get_connections():
			孔.请求镶嵌.disconnect(连["callable"])
		for 连 in 孔.请求摘除.get_connections():
			孔.请求摘除.disconnect(连["callable"])
		# 信号本身带孔号（镶嵌带 孔号+宝石格、摘除带 孔号），直接连，**别再 `.bind()`**——
		# 上一版 `.bind()` 空参 + 签名两参 = 参数不匹配、处理函数没跑（用户报"拖进去没反应"的根因）。
		孔.请求镶嵌.connect(_宝石镶嵌_落入)
		孔.请求摘除.connect(_宝石镶嵌_摘除)
		# 已镶 ⇒ 弹那颗宝石/勾玉的详情；空孔 ⇒ 悬停时把两套框都收掉（`格子提示框` 空格那一支）。
		格子提示框.接线(self, page, 孔, 孔物品)
	_摆镶嵌孔(面板, 孔数, 宽)

## 把 5~6 个孔格在孔面板里**水平居中**排（原版是 HBox 自动居中，这里对齐它）。
func _摆镶嵌孔(面板: Control, 孔数: int, 宽: int) -> void:
	var 面板宽 := 宽 - 26.0                      # 孔面板左右各 13
	var 总宽 := 孔数 * 40.0 + (孔数 - 1) * 2.0    # 40x40，gap 2
	var 起点 := int((面板宽 - 总宽) / 2.0)
	for i in 孔数:
		var 孔 := 面板.get_node("孔_%d" % i) as Control
		孔.position = Vector2(起点 + i * 42.0, (60.0 - 40.0) / 2.0)

## 按孔数改窗宽（254/300）：外框 + 页面容器 + 标题居中 + 关闭按钮 + 拖动区 + 页内三块底/文字一起改宽。
func _镶嵌定宽(宽: float, page: Control) -> void:
	var 高 := 204.0
	# ⚠️ 每次回帧重渲（镶/摘一颗 → 库存帧 → `_refresh_current` → 本函数）都会走到这儿。
	# 原来无条件 `_摆窗口居中()` ⇒ 玩家把窗拖到别处后，**一拖入宝石就跳回正中**
	# （2026-11-02 用户报）。原版这窗是常驻件，HBox 变宽只改内部排布，窗不动 ⇒
	# 这里先记住当前偏移、居中标尺后再放回去（开窗那一趟随后由 `打开()` 的
	# `窗口偏移(_位置偏移)` 摆到正确位置，两次都幂等）。
	var 旧偏移 := 取位置偏移()
	_外框尺 = Vector2(宽, 高)
	_摆窗口居中()
	窗口偏移(旧偏移)
	_content.size = Vector2(宽, 高)
	_drag_area.size = Vector2(宽, 拖动区高)
	_layout_title(宽)
	# 关闭钮的边距口径同 `_apply_original_window`：`MWindow.as:215` 的 6（旧值 13 是补了不存在的留白）
	_close_button.position.x = 宽 - _close_button.size.x - 6.0
	# 页内元素（原为 254 摆的）随宽伸展
	(page.get_node("内容底") as Control).offset_right = 宽 - 5.0
	for 名 in ["镶嵌说明", "孔面板", "取出说明"]:
		(page.get_node(名) as Control).offset_right = 宽 - 13.0

func _宝石镶嵌_落入(孔号: int, 宝石格: int) -> void:
	# 孔号仅用于将来"镶到指定孔"，服务端是在 inlays 末尾 append ⇒ 当前不发。
	if _镶嵌勾玉模式:
		# 勾玉那一支的客户端前置（`GouYuCarryWindow.inalyStoneHandler:222-249`）：
		# ① 拖来的必须**是勾玉**（`isItemAGouYu`，前三位 131）；② 孔已满 ⇒ 点名上限。
		# ⚠️ ③"同加成忍术不许重镶"这一条**没做**：要那枚勾玉的 `skillId`（`StoneData.skillId`），
		#    本工程没导出那份数据 ⇒ 交给服务端判（它按同一张表拒并回话），不假装判过。
		var 条: Dictionary = _session._占用条(_session.inventory, 宝石格)
		var 是勾玉 := str(条.get("id", "")).pad_zeros(8).substr(0, 3) == "131"
		if not 是勾玉:
			_session.notification_requested.emit("对不起，该物品不是勾玉")
			return
		var 装备: Dictionary = _session._占用条(_session.inventory, _宝石镶嵌装备格)
		var 上限 := clampi(玉链孔数(_装备阶数(装备)), 0, 6) \
				if 装备部位.位置(String(装备.get("id", ""))) == 装备部位.勾玉 \
				else (6 if int(装备.get("aptitude", 1)) >= 5 else 5)
		var 已镶: Array = 装备.get("inlays", [])
		if 已镶.size() >= 上限:
			_session.notification_requested.emit("很抱歉，该装备最多只能镶嵌%d个勾玉" % 上限)
			return
		_镶嵌反馈(_session.jade_inlay(_宝石镶嵌装备格, 宝石格), "已请求镶嵌")
		return
	_镶嵌反馈(_session.inlay_stone(_宝石镶嵌装备格, 宝石格), "已请求镶嵌")

func _宝石镶嵌_摘除(孔号: int) -> void:
	if _镶嵌勾玉模式:
		_镶嵌反馈(_session.jade_uninlay(_宝石镶嵌装备格, 孔号), "已请求取出")
		return
	_镶嵌反馈(_session.uninlay_stone(_宝石镶嵌装备格, 孔号), "已请求取出")

## 镶嵌窗的反馈一律走**系统消息**（HUD 可见）——小窗里 `_show_hint` 写的状态栏是隐藏的，
## 离线被拒时玩家会什么都没看到（用户 2026-10-02 报"拖进去没反应"的一半原因）。
func _镶嵌反馈(成功: bool, 成功文案: String) -> void:
	var 话 := 成功文案 if 成功 else "宝石镶嵌/取出在服务端结算，当前离线模式不生效（请连服务端再试）"
	_session.notification_requested.emit(话)

## 原版「灵器炼制」三扇（洗炼 `XiLianWindow` / 灵化 `LingHuaWindow` / 开光 `KaiGuangWindow`，
## 都在 `com/mxw/uifl/controls/lingQi/`）。三扇 `super(520,345,true)`、`createChildren` **逐行相同**，
## 差别只有：**材料格枚数**（开光 2 枚）、文案、以及 `LING = 2081` 的子命令
## （`LingEquipProcessor.as:107/116/125`：灵化 `writeByte(1)` / 开光 `0` / 洗炼 `2`，都带 (itemId, itemPos)）。
## ⇒ 本工程**一个场景 + 模式位**（同「镶嵌勾玉」那条口径）。配置在 `数据/原版杂项.json` 的 `LingQi` 段。
const 灵器炼制场景 := preload("res://场景/界面/窗口/灵器炼制/灵器炼制窗.tscn")

const 洗炼说明文 := "<font color='#fcc399'>十拳剑是传说中的灵器，曾被击碎散落于世，自此销声匿迹于世。<br/></font><font color='#00ff00'>后人机缘巧合之下重铸此剑，但其展现的威力却大不如前！<br/></font><font color='#ff0000'>传说中通过洗炼，能让此剑获得神秘的力量，大展传说灵器之威！</font>"
const 灵化说明文 := "<font color='#fcc399'>十拳剑是传说中的灵器，曾被击碎散落于世，自此销声匿迹于世。<br/></font><font color='#00ff00'>后人机缘巧合之下重铸此剑，但其展现的威力却大不如前！<br/></font><font color='#ff0000'>传说中通过灵化，能让此剑获得神秘的力量，大展传说灵器之威！</font>"
const 开光说明文 := "<font color='#fcc399'>十拳剑是传说中的灵器，曾被击碎散落于世，自此销声匿迹于世。<br/></font><font color='#00ff00'>后人机缘巧合之下重铸此剑，但其展现的威力却大不如前！<br/></font><font color='#ff0000'>传说中通过开光，能让此剑获得神秘的力量，大展传说灵器之威！</font>"
const 洗炼条件文 := "<font color='#FFDC35'>洗炼条件：<br/></font><font color='#FFFFFF'>\t\t拥有【十拳剑】<br/><br/></font><font color='#FFDC35'>洗炼效果：<br/></font><font color='#FFFFFF'>\t\t附加属性<br/>\t\t攻击 +%1<br/><br/></font><font color='#FFDC35'>洗炼消耗：<br/></font><font color='#00ff00'>\t\t灵器洗炼石%2颗<br/><br/></font><font color='#FFDC35'>洗炼成功率：<br/></font><font color='#FFFFFF'>\t\t100%</font>"
const 灵化条件文 := "<font color='#FFDC35'>灵化条件：<br/></font><font color='#FFFFFF'>\t\t拥有【十拳剑】<br/><br/></font><font color='#FFDC35'>灵化效果：<br/></font><font color='#FFFFFF'>\t\t十拳剑增加6条附加属性（攻击力）<br/>\t\t附加属性的初始值为1<br/><br/></font><font color='#FFDC35'>灵化消耗：<br/></font><font color='#00ff00'>\t\t灵化石%1颗<br/><br/></font><font color='#FFDC35'>灵化成功率：<br/></font><font color='#FFFFFF'>\t\t100%</font>"
const 开光条件文 := "<font color='#FFDC35'>开光条件：<br/></font><font color='#FFFFFF'>\t\t拥有【十拳剑】<br/><br/></font><font color='#FFDC35'>开光后加成：<br/></font><font color='#FFFFFF'>\t\t攻击 +%1\t\t\t血量上限 +%2<br/>\t\t世界忍术等级 +%3\t\t职业忍术等级 +%4<br/><br/></font><font color='#FFDC35'>开光消耗：<br/></font><font color='#00ff00'>\t\t灵器开光锤1把，灵器开光石%5颗<br/><br/></font><font color='#FFDC35'>开光成功率：<br/></font><font color='#FFFFFF'>\t\t100%</font>"


## 背包物品菜单「开光 / 灵化 / 洗练」那三选一的**带物开窗**（原版 `showKaiGuangWindow(curCellData)`
## 一族 → 各窗 `setData`）。⚠ 只有**洗炼**那扇的 `XiLianWindow.setData:63-77` 会灌 `plusAttr`
## （带附加 ⇒ 第一条×6；不带 ⇒ 置 0），灵化（`LingHuaWindow.setData:144-152`）与开光
## （`KaiGuangWindow.setData:130-138`）两支只写 `_itemId`/`_itemPos` ⇒ 别在这儿顺手把别的页也刷了。
## 也不在这里放回「开光已点」：原版 `setDOShow(...,false)` 只是 `removeChild`（`UIMain2:4161-4175`）、
## 窗对象留在 `_windowMap` 里 ⇒ 按住的那枚钮**跨关窗/开窗一路按住**，本工程同样留着实例，口径一致。
func 带物开窗(模式: String, 条: Dictionary, 格: int) -> void:
	_灵器炼制物品 = 条.duplicate(true)
	_灵器炼制格 = 格
	if 模式 == "洗练":
		_灵器附加展示 = _洗炼加成(条)


## 三扇共用的一处渲染（版式相同、只换文案与材料格）。
## `模式` ∈ {"洗练", "灵化", "开光"}；`条` = 那件灵器（原版 `showXxWindow(curCellData)` 带进来的）。
func _render_ling_forge(模式: String, 条: Dictionary, 格: int) -> void:
	var page := _instantiate_page(灵器炼制场景)
	_给页挂提示框(page)
	# 原版这三扇的「这一件」**不是开窗时的快照**：结果帧回来以后走的是
	# `LingQiManager.onLingEquipLingHuaResult:266` / `onLingEquipWashUpResult:312` 那两句
	# `getItemBySlotFromList(API.dataCenter.commonItems, _itemPos)` ⇒ **每次重绘按格号现取**。
	# 现取不到（那格空了）才退回带进来的那件，别把台面刷成空的。
	# 这一句同时管住两件事：开光把 id 换成 20200001、灵化写进 6 条附加 ⇒ 都靠它进窗；
	# 否则第二次点「开始」还抱着旧 id 发包，服务端 `handle_ling_qi:52097` 那句
	# `item.item_id != item_id` 一定判失败。
	var 现取: Dictionary = {} if 格 <= 0 or _session == null else _session._占用条(_session.inventory, 格)
	if not 现取.is_empty():
		条 = 现取
		_灵器炼制物品 = 现取
	var 杂项: Dictionary = GAME_DATA.取表("原版杂项").get("LingQi", {}) as Dictionary
	var 段名: String = {"洗练": "xiLian", "灵化": "lingHua", "开光": "Kaiguang", "开光人具": "Kaiguang"}.get(模式, "xiLian")
	var 配置: Dictionary = 杂项.get(段名, {}) if 杂项.get(段名) is Dictionary else {}
	var 标题: String = {"洗练": "洗炼", "灵化": "灵化", "开光": "开光", "开光人具": "开光"}.get(模式, "洗炼")
	设置标题(标题)
	var 说明文: String = {"洗练": 洗炼说明文, "灵化": 灵化说明文, "开光": 开光说明文, "开光人具": 开光说明文}.get(模式, 洗炼说明文)
	(page.get_node("说明") as RichTextLabel).text = 译文为BBCode(说明文)
	# 开光那扇（人具同版式）有两处与洗炼/灵化不同，都相对**文案框**算
	# （`KaiGuangWindow.as:76/131`、`RenJuKaiGuangWindow.as:121/133`）：
	#   · 第一枚材料格 `x = 文案x + 文案宽 − 10` = **340**（洗炼/灵化是 `+0` = 350）；
	#   · 开始钮   `x = 文案x + 文案宽 + 20` = **370** ⇒ 比材料格**右 30**，不是右 20。
	#   · 第一枚是 `new ItemCaiLiaoBox(false)`（开光锤）⇒ **它没有「购买」钮**，
	#     第二枚（开光石）才是 `true`。
	var 是开光 := 模式 == "开光" or 模式 == "开光人具"
	# 材料：`needItemId`/`needItemCnt` 三段的拼写与个数都不一样（照抄配置，不统一）
	var 材料id串 := String(配置.get("needItemId", 配置.get("needItemid", "")))
	var 数量串 := String(配置.get("needItemCnt", "1"))
	var 材料ids := 材料id串.split(",")
	var 数量s := 数量串.split(",")
	for i in 2:
		var 有这件 := i < 材料ids.size()
		var 格节点 := page.get_node_or_null("内容底/材料格%s" % ["一", "二"][i]) as Control
		var 名节点 := page.get_node_or_null("内容底/材料格%s名" % ["一", "二"][i]) as Label
		if 格节点 == null:
			continue
		格节点.visible = 有这件
		if 名节点 != null:
			名节点.visible = 有这件
		if not 有这件:
			# ⚠️ 三件（格 / 名 / 购买）**必须一起藏** —— 2026-10-13 只藏了前两件，
			#    「购买」漏在外面（灵化只有 1 件材料 ⇒ 第二枚购买钮白摆在那儿）。
			var 闲购 := page.get_node_or_null("内容底/材料格%s购买" % ["一", "二"][i]) as Button
			if 闲购 != null:
				闲购.visible = false
			continue
		var 材料id := int(材料ids[i])
		var 需要 := int(数量s[i]) if i < 数量s.size() else 1
		_接打造提示(page, 格节点, 材料id, 需要)
		# ⚠️ 角标是**拥有数**不是需要数（原版 `LingHuaWindow.validateItem:105`：
		#    `itemCell.label = int(isBagExistItem(id)) + ""`）—— 需要数只在「消耗」那行说。
		var 拥有: int = int(_背包数量(材料id))
		var 图标 := 格节点.get_node("材料图标") as TextureRect
		图标.texture = GAME_DATA.item_icon(材料id)
		# 拥有 < 需要 ⇒ **整格灰化**（原版 `:107-111` `if(_loc3_ < _loc1_) lhShiCell.applyGrayFilter()`）。
		图标.modulate = Color(1, 1, 1, 1) if 拥有 >= 需要 else Color(0.55, 0.55, 0.55, 1)
		(格节点.get_node("材料数量") as Label).text = str(拥有)
		if 名节点 != null:
			名节点.text = 装备打造表.物品名(材料id)
		# 购买钮（原版 `new ItemCaiLiaoBox(true)` 的那枚 `buyBtn`）—— 与全工程同一个出口。
		# 开光锤那枚是 `ItemCaiLiaoBox(false)` ⇒ **原版就没有这枚钮**，别硬摆一枚。
		var 有购买钮 := not (是开光 and i == 0)
		var 购买 := page.get_node_or_null("内容底/材料格%s购买" % ["一", "二"][i]) as Button
		if 购买 != null:
			购买.visible = 有购买钮		# ⚠️ 同组的三件要一起显隐；漏了这句 ⇒ 灵化（只有 1 件材料）会多出一枚「购买」
		if 购买 != null and 有购买钮:
			_configure_standard_button(购买)
			for 连 in 购买.pressed.get_connections():
				购买.pressed.disconnect(连["callable"])
			购买.pressed.connect(func() -> void: 请求商城商品(str(材料id).pad_zeros(8)))
	# 文案（原版 `showInfo()` 的 `CN.replaceString`，逐条照抄）
	var 文案 := page.get_node("内容底/文案") as RichTextLabel
	match 模式:
		"洗练":
			文案.text = 译文为BBCode(洗炼条件文.replace("%1", str(_灵器附加展示)).replace("%2", str(int(数量s[0]))))
		"灵化":
			文案.text = 译文为BBCode(灵化条件文.replace("%1", str(int(数量s[0]))))
		_:
			var 加成 := _灵器加成表(配置)
			文案.text = 译文为BBCode(开光条件文
					.replace("%1", str(int(加成.get("atk", 0))))
					.replace("%2", str(int(加成.get("mxHp", 0))))
					.replace("%3", str(int(加成.get("world_skill_level", 0))))
					.replace("%4", str(int(加成.get("job_skill_level", 0))))
					.replace("%5", str(int(数量s[1]) if 数量s.size() > 1 else 1)))
	# 开始钮：文字与位置（开光那扇原件在三枚件右侧）
	var 钮 := page.get_node("内容底/开始") as Button
	钮.text = 标题
	var 首格 := float(340.0 if 是开光 else 350.0)
	钮.position = Vector2(首格 + (30.0 if 是开光 else 0.0), 175.0)
	var 格一 := page.get_node("内容底/材料格一") as Control
	格一.position = Vector2(首格, 80.0)
	(page.get_node("内容底/材料格一名") as Label).position = Vector2(首格 - 6.0, 60.0)
	for 连 in 钮.pressed.get_connections():
		钮.pressed.disconnect(连["callable"])
	钮.pressed.connect(_执行灵器炼制.bind(模式, 条, 格))
	# 「开光」那两扇点过一次就按住（`KaiGuangWindow.as:160` / `RenJuKaiGuangWindow.as:172`）。
	# 记在宿主上而不是页里 ⇒ 回帧重绘也还是按住的那一枚；忍具那支由结果帧放回
	# （`RenJuKaiGuangWindow.handleKaiGuangResult:70-77` 第一句 `enabled = true`），
	# 灵器那支的结果帧是空函数 ⇒ 一路按住到窗关。
	_灵器开始钮 = 钮
	钮.disabled = 是开光 and _灵器开光已点


## 洗炼窗「洗炼效果：攻击 +N」里那个 N —— 原版 `XiLianWindow.showInfo:51-52` 用的是
## `lqManager.plusAttr`，而它是 `LingQiManager.updatePlusAttr:280` 算出来的：
## **`附加属性[0].subArrtValue × 6`**（洗炼把 6 条附加一起往上滚）；没有附加属性时
## `XiLianWindow.setData:72` 直接把它置 **0**。
## ⚠️ 2026-10-13 修：原来读的是 `条.plus_attr` —— 全工程没人写这个键 ⇒ 恒 0 ⇒
## **洗炼窗永远显示「攻击 +0」**（不管这件十拳剑灵化到多少）。
static func _洗炼加成(条: Dictionary) -> int:
	var 表: Array = 条.get("plus_attributes", []) as Array
	if 表.is_empty():
		return 0
	return int((表[0] as Dictionary).get("attribute_value", 0)) * 6


## `LingQi.<段>.attrs` 是 `{"0": {"type": "atk", "value": "222"}, …}` 那种形状
## （开光那段的类型名混着大小写：`mxHp` / `world_skill_level` / `job_skill_level`），摊成一张表。
static func _灵器加成表(配置: Dictionary) -> Dictionary:
	var 出: Dictionary = {}
	var 原: Variant = 配置.get("attrs", {})
	if not (原 is Dictionary):
		return 出
	for k in (原 as Dictionary):
		var 条: Variant = (原 as Dictionary)[k]
		if 条 is Dictionary:
			出[String((条 as Dictionary).get("type", ""))] = int((条 as Dictionary).get("value", 0))
	return 出


## 提交：`LING = 2081` 子命令 0/1/2 + (itemId, itemPos)（`LingEquipProcessor.as:107-130`）。
func _执行灵器炼制(模式: String, 条: Dictionary, 格: int) -> void:
	if 条.is_empty() or 格 <= 0:
		_session.notification_requested.emit("请先放入要炼制的灵器")
		return
	var 后端 = _backend
	if 后端 == null:
		_session.notification_requested.emit("%s要在服务端结算（离线不模拟）" % 模式)
		return
	var 物品号 := int(str(条.get("id", "0")))
	var 成功 := false
	match 模式:
		"开光":
			成功 = 后端.call("request_ling_equip_kai_guang", 物品号, 格)
		"开光人具":
			# 人具那扇（`RenJuKaiGuangWindow`）版式与本尊相同，只是发 `RENJU = 2082` 子命令 **0**
			# （`RenJuProcessor.as:36-42` `writeByte(0)` + itemId + itemPos）；
			# 它的材料配置**回落到** `Etc.LingQi.kaiguang`（`RenJuManager.as:94-99`）。
			成功 = 后端.call("request_renju_kai_guang", 物品号, 格)
		"灵化":
			成功 = 后端.call("request_ling_equip_ling_hua", 物品号, 格)
		_:
			成功 = 后端.call("request_ling_equip_wash", 物品号, 格)
	if not 成功:
		_session.notification_requested.emit("%s请求发送失败" % 模式)
		return
	# 开光族发出去就把钮按住（原版在 `requestXxx` **之前**一句 `kaiGuangBtn.enabled = false`，
	# 发失败也一样按住 —— 本工程按同一口径放在"已发出"之后：没发出去的请求不该锁界面）。
	if 模式 == "开光" or 模式 == "开光人具":
		_灵器开光已点 = true
		if _灵器开始钮 != null and is_instance_valid(_灵器开始钮):
			_灵器开始钮.disabled = true
	# 发成功**不提示**（同 `_成交修理` / `人物窗口.发送修炼请求`）：原版 `LingEquipProcessor`
	# 的 as:107-130 四发写包一个 `addNotice` 都没有，界面等 2081 回帧重绘。


## 原版「破碎装备修复」窗（`EquipRepairWindow.as`，360×407）。入口只有一条：
## 背包物品菜单「破碎修复」（`onClickPopupMenu:802 showEquipRepairWindow(0, curCellData)`；
## **只有破碎的装备**菜单里才出这一项）。
## ⚠️ 提交走 `requestRecoverEquip` = `ITEM_CHANGE` 子命令 **8**（`strengthEquip:370-377`），
##    不是 7（`requestRepair` 那条是 NPC 商店的修理，另一扇窗）。
## 三段文案、两条闸门都逐字取 `EQUIP_STRENGTH_DESC_TEMPLATE_6` / `FAIL_PROMPT_*`。
func _render_equip_repair() -> void:
	var page := _instantiate_page(装备修复场景)
	var 条: Dictionary = _装备修复物品
	var 有装备 := not 条.is_empty()
	var 配置: Dictionary = 装备打造表.取段("crash")
	var 材料id := int(配置.get("needItemId", 0))
	var 材料名 := 装备打造表.物品名(材料id)
	设置标题("装备打造")          # `CN.EQUIP_STRENGTH_WINDOW_TITLE`：与打造窗**同名**
	# 装备格 + 图标（原版 `_itemBox.itemCell`）
	(page.get_node("内容容器/放入装备") as Button).text = "取出装备" if 有装备 else "放入装备"
	var 图标 := page.get_node("内容容器/装备格/装备图标") as TextureRect
	图标.texture = null
	if 有装备:
		var 图路 := String(条.get("icon", ""))
		if not 图路.is_empty() and ResourceLoader.exists(图路):
			图标.texture = load(图路) as Texture2D
	# 三段文案（`EQUIP_STRENGTH_DESC_TEMPLATE_6[0/1/2]`，`REPLACE_FLAG`=★ 换成材料名）
	for 对 in [["内容容器/说明", 修复说明模板], ["内容容器/注意", 修复注意模板]]:
		(page.get_node(String(对[0])) as RichTextLabel).text = \
				译文为BBCode(String(对[1]).replace("★", 材料名))
	(page.get_node("内容容器/标签") as Label).text = 修复标签文
	# 材料格：`_caiLiao1.itemCell.itemData = createSingleItem(needItemId)`、角标 = `needItemCnt`（原版强制 1）
	(page.get_node("内容容器/材料框/材料格/材料图标") as TextureRect).texture = GAME_DATA.item_icon(材料id)
	(page.get_node("内容容器/材料框/材料格/材料数量") as Label).text = "1"
	_刷新消耗几率(page, "内容容器/材料框/消耗几率", 配置)
	# 落点件：装备格运行期 `set_script`（场景是生成物、不许手改 .tscn；先例见 `意志格.gd`）
	var 格 := page.get_node("内容容器/装备格") as Control
	格.set_script(修复放入格组件)
	格.mouse_filter = Control.MOUSE_FILTER_STOP
	for 连 in 格.请求放入.get_connections():
		格.请求放入.disconnect(连["callable"])
	格.请求放入.connect(修复_收料)
	# 放入/取出 开关（原版 `clickDropBtnHandler:76-89`：已放 ⇒ `backItemToEquip` 清格，都不发帧）
	var 放入 := page.get_node("内容容器/放入装备") as Button
	for 连 in 放入.pressed.get_connections():
		放入.pressed.disconnect(连["callable"])
	放入.pressed.connect(_修复_按放入钮.bind(page))
	var 执行 := page.get_node("内容容器/开始修复") as Button
	for 连 in 执行.pressed.get_connections():
		执行.pressed.disconnect(连["callable"])
	执行.pressed.connect(_执行装备修复)


## 放入/取出 开关（原版 `clickDropBtnHandler:76-89`：已放 ⇒ `backItemToEquip` 清格，都不发帧）。
## 没放 ⇒ 公共「放入选择」弹层（原版 `UpShelfCursor` 的等价通道，2026-11-08）。
func _修复_按放入钮(页: Control) -> void:
	if not _装备修复物品.is_empty():
		_装备修复物品 = {}
		_装备修复格 = 0
		_render_page()
		return
	var 清单 := _背包装备候选()
	if 清单.is_empty():
		_show_hint("背包里没有可放入的装备")
		return
	放入选择器.弹(页, 清单,
			func(行: Dictionary) -> void: 修复_收料(int(行.get("格", 0))))


## `EquipRepairWindow.updateView` case 0 的三段文案（`EQUIP_STRENGTH_DESC_TEMPLATE_6`，
## `CN.as:3434-3437` = [_1 步骤说明, _2 注意, _3 标签]；`en_US$message_properties.as:3126-3129` 逐字）。
## `★` = `CN.REPLACE_FLAG`（语言表里就是 `★`，会被包绿 → 材料名显示成绿色）。
const 修复说明模板 := "<font color='#ff9100'>破碎装备修复步骤说明：</font><br/>1：请在左侧装备框放入要操作的装备<br/>2：装备好<font color='#00ff00'>★</font><font color='#ffffff'>（放入包裹中即可）<br/>3：点“开始修复”按钮即可开始修复操作</font>"
const 修复注意模板 := "<font color='#ff9100'>注意：</font><br/><font color='#ffffff'>包裹中必须有<font color='#00ff00'>★</font>才能修复处于破碎状态的装备<br/><br/><br/></font>"
const 修复标签文 := "* 若在限制时间内未修复破碎装备，破碎装备将永久消失"


## 落上一件装备。原版 `validateItem:230-263`：不是打造装备 / 时装 / 玉链 / 徽章各有各的话；
## 收下之后再看**破碎**（`crashTime == 0` ⇒ 「对不起，该装备没有破损！」**并不收**）。
## ⚠️ 判据的 id 形态见 §3.129：类型 1/2、时装 = `substr(2,2)=="21"`、玉链/徽章走**四位码**。
func 修复_收料(背包格: int) -> void:
	var 条: Dictionary = _session._占用条(_session.inventory, 背包格)
	if 条.is_empty():
		return
	if int(条.get("crash_time", 0)) == 0:
		_session.notification_requested.emit("对不起，该装备没有破损！")   # `FAIL_PROMPT_10_1[0]` 替 `_10_2`
		return
	_装备修复物品 = 条.duplicate(true)
	_装备修复格 = 背包格
	_render_page()


## 「开始修复」：原版 `strengthHandler:150-178` 的闸门**逐条照抄**（一条不过就不发）。
func _执行装备修复() -> void:
	if _装备修复物品.is_empty():
		_session.notification_requested.emit("请放入装备！")             # `FAIL_PROMPT_6[0]` 替 `_6[1]`
		return
	if int(_装备修复物品.get("crash_time", 0)) == 0:
		_session.notification_requested.emit("对不起，该装备没有破损！")
		return
	var 配置: Dictionary = 装备打造表.取段("crash")
	var 金币 := int(配置.get("needMoney", 0))
	if 金币 > int(_session.player_stats.get("gold", 0)):
		_session.notification_requested.emit("很抱歉，你的金币不够")     # `FAIL_PROMPT_2[0]` 替 `_2[1]`
		return
	var 需要材料 := 1                       # 原版 `_configInfo.needItemCnt = 1`（写死）
	if 装备打造表.拥有数(_session, int(配置.get("needItemId", 0))) < 需要材料:
		_session.notification_requested.emit("很抱歉，你的%s不够" % 装备打造表.物品名(int(配置.get("needItemId", 0))))
		return
	var 后端 = _backend
	if 后端 == null or not 后端.has_method("request_recover_equipment"):
		_session.notification_requested.emit("修复要在服务端结算（离线不模拟）")
		return
	# ⚠️ 发的是**背包格号**（原版 `requestRecoverEquip(this._itemData.position)`）。
	_session.notification_requested.emit(
			"已请求修复" if 后端.request_recover_equipment(_装备修复格) else "修复请求发送失败")


### —— 「梦幻属性符」窗（`MengHuanPropResetWindow.as`，360×432）——
##
## 入口：背包双击/使用「梦幻属性符」（`ItemWindow2.as:953-967`：`id == getMengHuanFuId()`
## ⇒ `showMengHuanPropRestWindow(符)` ⇒ `UIMain2.as:5651-5664` 先 `centerTwoWindow` 再
## `showPropPanle`）—— **整条不发 USE_ITEM**，所以拦截点必须在 `_use_item`（见函数里那段）。
## 提交：`requestFullPlusValue(装备格, 材料格, 选中序号)` = `ITEM_CHANGE` 子命令 **20**
## （`ItemChangeProcessor.as:287-296`）。⚠ 序号在 AS3 是 **1 基**（`PropItem.prop.index = i+1`）。

## 原版 `createChildren` 的那三条文案（`en_US$message_properties.as:967/1305/190`）。
const 梦幻说明 := "<font color='#00ff00'>梦幻属性符可以重置装备附加属性数值到满值\r</font><font color='#ffffff'>1：请放入一件紫色或橙色装备\r2：点选要重置的附加属性\r3：点开始重新开机按钮，100%重置成功</font>"
const 梦幻标签 := "*您所选的属性，在重置后将100%变为【梦幻满值】"
const 梦幻需要文 := "本次操作成功几率：100%\r重置后的效果预览："


func _render_梦幻属性符() -> void:
	var page := _instantiate_page(梦幻属性符场景)
	# 页签只有一枚「附加属性梦幻数值重置」（`selectedBtnHandler` case 0 恒选中）
	var 页签 := page.get_node("分页/附加属性梦幻数值重置") as Button
	选页签(页签, true)
	_apply_tab_skin(页签)

	# 装备格 + 图标（原版 `_itemBox.itemCell` / `updateView` 的 `itemCell.itemData`）
	var 装备 := _梦幻_装备()
	var 有装备 := not 装备.is_empty()
	(page.get_node("内容容器/放入装备") as Button).text = "取出装备" if 有装备 else "放入装备"
	var 图标 := page.get_node("内容容器/装备格/装备图标") as TextureRect
	图标.texture = null
	if 有装备:
		var 图路 := String(装备.get("icon", ""))
		if not 图路.is_empty() and ResourceLoader.exists(图路):
			图标.texture = load(图路) as Texture2D
	_挂装备品质(page.get_node("内容容器/装备格") as Control, 装备)
	_接打造装备提示(page, page.get_node("内容容器/装备格") as Control, 装备)

	# 三段文案（`selectedBtnHandler case 0`），说明里的 `\r` 与 `<font>` 由 译文为BBCode 翻译
	(page.get_node("内容容器/说明") as RichTextLabel).text = 译文为BBCode(梦幻说明)
	(page.get_node("内容容器/标签") as Label).text = 梦幻标签
	(page.get_node("内容容器/材料框/需要文") as RichTextLabel).text = 译文为BBCode(梦幻需要文)

	# 材料格：图标/名字/角标恒为梦幻属性符，**灰不灰看两件事**——
	# 没放装备 ⇒ `applyGrayFilter()`（无条件灰）；放了装备 ⇒ `hasItem()`（背包里有货才不灰）。
	var 材料id := 装备打造表.梦幻属性符id()
	var 材料名 := 装备打造表.物品名(材料id)
	(page.get_node("内容容器/材料框/材料一/材料名") as Label).text = 材料名
	(page.get_node("内容容器/材料框/材料一/材料格/材料图标") as TextureRect).texture = GAME_DATA.item_icon(材料id)
	var 数量 := page.get_node("内容容器/材料框/材料一/材料格/材料数量") as Label
	数量.text = "1"                       # `showPropPanle`：`itemCell.label = "1"`
	_配置材料数量(数量)
	var 材料格 := page.get_node("内容容器/材料框/材料一/材料格") as TextureRect
	_套格子灰(材料格, not 有装备 or 装备打造表.拥有数(_session, 材料id) <= 0)
	_接打造提示(page, 材料格, 材料id, 1)
	var 购买 := page.get_node("内容容器/材料框/材料一/购买") as Button
	_configure_standard_button(购买)
	购买.disabled = 材料id <= 0
	if 材料id > 0:
		购买.pressed.connect(请求商城商品.bind(str(材料id)))

	# 附加属性列表（`drawPropView:78-105`，每行 20 高）
	_梦幻_画属性列表(page, 装备)

	# 落点件：装备格运行期 `set_script`（场景是生成物、不许手改 .tscn；先例同 修复放入格）
	var 格 := page.get_node("内容容器/装备格") as Control
	格.set_script(梦幻放入格组件)
	格.mouse_filter = Control.MOUSE_FILTER_STOP
	for 连 in 格.请求放入.get_connections():
		格.请求放入.disconnect(连["callable"])
	格.请求放入.connect(梦幻_收料)

	# 放入/取出（原版 `clickDropBtnHandler:322-335`：已放 ⇒ `backItemToEquip`，都不发帧）
	var 放入 := page.get_node("内容容器/放入装备") as Button
	_configure_standard_button(放入)
	for 连 in 放入.pressed.get_connections():
		放入.pressed.disconnect(连["callable"])
	放入.pressed.connect(_梦幻_按放入钮.bind(page))

	var 执行 := page.get_node("内容容器/开始重置") as Button
	_configure_standard_button(执行)
	for 连 in 执行.pressed.get_connections():
		执行.pressed.disconnect(连["callable"])
	执行.pressed.connect(_执行梦幻重置)


## 现读会话里放着的那件（原版 `itemDatachanged` 的重取口径）。取不到/id 变了 ⇒ 退回空态。
func _梦幻_装备() -> Dictionary:
	if _梦幻_装备格 <= 0:
		return {}
	var 条: Dictionary = _session._占用条(_session.inventory, _梦幻_装备格)
	if 条.is_empty() or String(条.get("id", "")) != _梦幻_装备id:
		_梦幻_清装备()
		return {}
	return 条


## 原版 `backItemToEquip:107-118`（清装备 + 收起对照 + 清选择）。
func _梦幻_清装备() -> void:
	_梦幻_装备格 = 0
	_梦幻_装备id = ""
	_梦幻_选中 = 0


## 放入/取出（原版 `clickDropBtnHandler:322-335`：已放 ⇒ `backItemToEquip`，都不发帧）。
## 没放 ⇒ 公共「放入选择」弹层（原版 `UpShelfCursor` 的等价通道，2026-11-08）。
func _梦幻_按放入钮(页: Control) -> void:
	if _梦幻_装备格 > 0:
		_梦幻_清装备()
		_render_page()
		return
	var 清单 := _背包装备候选()
	if 清单.is_empty():
		_show_hint("背包里没有可放入的装备")
		return
	放入选择器.弹(页, 清单,
			func(行: Dictionary) -> void: 梦幻_收料(int(行.get("格", 0))))


## 附加属性上限（原版 `ItemFactory.getEquipMaxPropValue(id, stage, type)`）：
## 按 `数据/装备打造.json` 的 `plus.stage<阶>.<部位>` 里同英文名那条的 `valueTo` 取。
## 查不到 ⇒ 0（原版也是 0，且 `isFull = value >= max` 会因此把该行判成"满"—— 照抄）。
func _梦幻_上限(装备: Dictionary, 类型: int) -> int:
	var 元 := _装备元(String(装备.get("id", "")))
	var 英文 := String(装备提示框.属性英文名.get(类型, ""))
	for 条目 in 装备打造表.取附加属性上限(
			_装备阶数(装备), String(元.get("type_name", ""))).values():
		if 条目 is Dictionary and String((条目 as Dictionary).get("type", "")) == 英文:
			return int((条目 as Dictionary).get("valueTo", 0))
	return 0


## 选中的那条（**1 基序号**）；没选/已满/越界都是空字典 —— 对应原版
## `strengthHandler` 那句 `!_selectedProp || _selectedProp.isFull`。
func _梦幻_选中条(装备: Dictionary) -> Dictionary:
	var 列表 := 装备.get("plus_attributes", []) as Array
	if _梦幻_选中 < 1 or _梦幻_选中 > 列表.size():
		return {}
	var 条 := 列表[_梦幻_选中 - 1] as Dictionary
	var 类型 := int(条.get("attribute_type", 0))
	var 值 := int(条.get("attribute_value", 0))
	var 顶 := _梦幻_上限(装备, 类型)
	if 值 >= 顶:
		return {}
	return {"序号": _梦幻_选中, "类型": 类型, "值": 值, "顶": 顶}


## 画属性行（`PropItem`，`MengHuanPropResetWindow.as:455-518`）：
##   左列 x=0 宽 104、紫（`UI_ZHI_SE`）= `属性名 +当前值`；
##   右列 x=105 宽 105 —— 未满绿「最大可提升至N」、已满橙「【梦幻满值】」；
##   勾选框 x=210 y=3，**已满的行没有勾**（`updateView` 里 `checkBox.visible = isFull ? false : true`）。
## 底下的预览（`_previewPropItem`）只在选中一条时亮：属性名 +满值 / 橙「【梦幻满值】」。
func _梦幻_画属性列表(page: Control, 装备: Dictionary) -> void:
	var 区 := page.get_node("内容容器/属性列表") as Control
	for 子 in 区.get_children():
		区.remove_child(子)
		子.queue_free()
	var 预览 := page.get_node("内容容器/材料框/预览属性") as Control
	预览.visible = false
	if 装备.is_empty():
		_梦幻_选中 = 0
		return
	var 列表 := 装备.get("plus_attributes", []) as Array
	if _梦幻_选中 > 列表.size():
		_梦幻_选中 = 0
	for 序号 in 列表.size():
		var 条 := 列表[序号] as Dictionary
		var 类型 := int(条.get("attribute_type", 0))
		var 值 := int(条.get("attribute_value", 0))
		var 顶 := _梦幻_上限(装备, 类型)
		var 满 := 值 >= 顶
		if 满 and _梦幻_选中 == 序号 + 1:
			_梦幻_选中 = 0                      # 重置成功后这行已满，勾也画不出来
		var 行 := Control.new()
		行.position = Vector2(0.0, float(序号) * 20.0)
		行.size = Vector2(244.0, 20.0)
		行.mouse_filter = Control.MOUSE_FILTER_IGNORE
		区.add_child(行)
		var 名 := Label.new()
		var 属名 := String(装备提示框.属性名.get(类型, "属性%d" % 类型))
		名.text = "%s +%d" % [属名, 值]
		名.position = Vector2.ZERO
		名.size = Vector2(104.0, 20.0)
		名.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_configure_label(名, 12, Color("ba01f9"))
		行.add_child(名)
		var 尾 := Label.new()
		尾.position = Vector2(105.0, 0.0)
		尾.size = Vector2(105.0, 20.0)
		尾.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if 满:
			尾.text = "【梦幻满值】"
			_configure_label(尾, 12, Color("ff9100"))
		else:
			尾.text = "最大可提升至%d" % 顶
			_configure_label(尾, 12, Color("00ff00"))
		行.add_child(尾)
		if not 满:
			var 勾 := CheckBox.new()
			勾.position = Vector2(210.0, 3.0)
			勾.size = Vector2(20.0, 20.0)
			勾.text = ""
			勾.focus_mode = Control.FOCUS_NONE
			勾.button_pressed = _梦幻_选中 == 序号 + 1
			# `toggled` 带一个 bool；原版 CLICK 里**总是**把点的那行置为选中
			# （`selectedPropHandler:301-313`），所以按下/弹起都按"选中它"处理。
			勾.toggled.connect(func(_按下: bool) -> void: _梦幻_选中项(序号 + 1))
			行.add_child(勾)
	# 预览：只有"选中的那条没满"才亮（`selectedPropHandler:283-298`）
	var 选中 := _梦幻_选中条(装备)
	if 选中.is_empty():
		return
	预览.visible = true
	var 名字 := String(装备提示框.属性名.get(int(选中["类型"]), "属性%d" % int(选中["类型"])))
	(page.get_node("内容容器/材料框/预览属性/属性值") as Label).text = "%s +%d" % [名字, int(选中["顶"])]
	(page.get_node("内容容器/材料框/预览属性/属性值") as Label).size = Vector2(104.0, 20.0)
	_configure_label(page.get_node("内容容器/材料框/预览属性/属性值") as Label, 12, Color("ba01f9"))
	(page.get_node("内容容器/材料框/预览属性/结果") as Label).text = "【梦幻满值】"
	_configure_label(page.get_node("内容容器/材料框/预览属性/结果") as Label, 12, Color("ff9100"))


## 点勾：原版 `selectedPropHandler` —— 旧的取消、新的选中、预览换成它的满值。
func _梦幻_选中项(序号: int) -> void:
	_梦幻_选中 = 序号
	_render_page()


## 落上一件装备。原版 `validateItem:156-231` 六道闸门**按原顺序**弹话：
## 不是打造装备 / 时装 / 玉链 / 徽章 / 破损 / 非紫橙。过了才收。
func 梦幻_收料(背包格: int) -> void:
	var 条: Dictionary = _session._占用条(_session.inventory, 背包格)
	if 条.is_empty():
		return
	var 物品id := String(条.get("id", ""))
	var 补零 := 物品id.pad_zeros(8)
	var 类型号 := int(补零.substr(0, 2)) if 补零.length() >= 2 else 0
	if 类型号 != 1 and 类型号 != 2:
		_show_hint("对不起，该物品不能被打造")                    # `EQUIP_STRENGTH_FAIL_PROMPT_1`
		return
	if 补零.substr(2, 2) == "21":                              # `isItemAShiZhuang`
		_show_hint("对不起，%s不可以进行打造！" % "变身卡")        # 7[0] 替 7[1]
		return
	var 四位 := int(补零.substr(0, 4))
	if 四位 == 120:                                            # `isItemAYuLian`
		_show_hint("对不起，%s不可以进行打造！" % "玉链")          # 7[0] 替 7[2]
		return
	if 四位 == 141:                                            # `isItemAHuiZhang`
		_show_hint("该物品无法进行此操作。")                       # `HUIZHANG_STRENGTH_FAIL_PROMPT`
		return
	if int(条.get("crash_time", 0)) > 0:
		_show_hint("对不起，该装备已经破损！")                     # 10[0] 替 10[2]
		return
	if int(条.get("aptitude", 0)) not in [4, 5]:               # PURPLE / ORANGE
		_show_hint("该装备不符合要求，请放入紫色或橙色品质装备")    # `..._FANG_RU_ZI_ZHAUNG`
		return
	_梦幻_装备格 = 背包格
	_梦幻_装备id = 物品id
	_梦幻_选中 = 0
	_render_page()


## 「开始重置」：原版 `strengthHandler:337-383` 的闸门**逐条照抄**（一条不过就不发）。
func _执行梦幻重置() -> void:
	var 装备 := _梦幻_装备()
	if 装备.is_empty():
		_show_hint("请放入装备！")                                # 6[0] 替 6[1]
		return
	if int(装备.get("crash_time", 0)) > 0:
		_show_hint("对不起，该装备已经破损！")
		return
	var 材料id := 装备打造表.梦幻属性符id()
	if 装备打造表.拥有数(_session, 材料id) <= 0:
		_show_hint("很抱歉，你的%s不够" % 装备打造表.物品名(材料id))   # 2[0] 替 2[1]
		return
	if int(装备.get("aptitude", 0)) not in [4, 5]:
		_show_hint("该装备不符合要求，请放入紫色或橙色品质装备")
		return
	var 选中 := _梦幻_选中条(装备)
	if 选中.is_empty():
		_show_hint("请先选择一条附加属性")                          # `..._NO_SELECTED`
		return
	var 后端 = _backend
	if 后端 == null or not 后端.has_method("request_full_plus_value"):
		_show_hint("梦幻属性符要在服务端结算（离线不模拟）")
		return
	# ⚠ 序号发 **1 基**（原版 `PropItem.prop.index = i+1`；服务端按同一口径减一）。
	if not 后端.request_full_plus_value(_梦幻_装备格, _梦幻_材料格, int(选中["序号"])):
		_show_hint("重置请求发送失败")


## 打开梦幻属性符窗并带上材料格（`showPropPanle(符)`：材料格 = 点的那一格）。
## 同 `背包窗口._开装备修复窗`：先 `打开` 建窗、写状态、再 `打开` 一次才按新状态渲染。
func _开梦幻属性符窗(格位: int) -> void:
	var 条: Dictionary = _session._占用条(_session.inventory, 格位)
	if 条.is_empty():
		return
	var 管理: Node = get_parent()
	if 管理 == null or not 管理.has_method("打开") or not 管理.has_method("取窗口"):
		_show_hint("梦幻属性符：找不到窗口管理")
		return
	管理.call("打开", "梦幻属性符")
	var 窗: Node = 管理.call("取窗口", "梦幻属性符")
	if 窗 == null:
		_show_hint("梦幻属性符：窗没开出来")
		return
	窗.set("_梦幻_材料格", 格位)
	窗.set("_梦幻_材料id", String(条.get("id", "")))
	窗.call("打开")


### —— 「橙装打造」窗（`YellowEquipLianZhiWindow.as`，376×407）——
##
## 入口：背包双击/使用「传说装备打造石」/「传说精炼石」（`ItemWindow2.as:979-988`）⇒
## `showYellowEquipLianZhiWindow(0/1)`；**一样不发 USE_ITEM**，拦截点在 `_use_item`。
## 两页签共用同一套版式：`0 橙装打造`（紫 10 星 60 级 → 橙，随机一条传说属性）、
## `1 橙装精炼`（橙装重掷传说属性）。两档配置由 `getEquipDaZaoCfg/getEquipJingLianCfg`
## 强置 `prob = 100`、`needMoney = 0`（`YellowEquipLianZhiWindow.as:96-106 / :219-242`）。
## 提交 = `request_change_to_orange` / `request_change_tale_attribute`（ITEM_CHANGE 23/24），
## 参数是**背包格**（服务端 `fake_flash_server.py:54984` 用 `inventory.get(slot)` 取件）。

## 原版 `createChildren` 用的语言表原文（`en_US$message_properties.as:295/623/1947/1119/2542/2157`）。
const 橙装打造说明 := "<font color='#ff9100'>橙色装备打造提示：\r</font><font color='#ffffff'>1：请将需要进行操作的装备放入左侧装备栏\r2：请确认背包内有“<font color='#00ff00'>%1</font>”\r3：点击“开始打造”按钮即可开始打造操作</font>"
const 橙装打造注意 := "<font color='#ff9100'>注意：\r</font><font color='#ffffff'>只有60级以上的紫色满星装备可以用于打造橙装\r橙装的打造操作成功率为100%\r</font><font color='#ff0000'>橙装可以镶嵌6颗宝石，并增加一条传说属性\r橙装的精炼操作成功率为100%</font>"
const 橙装打造标签 := "橙色装备打造成功后，将随机获得一条传说属性"
const 橙装精炼说明 := "<font color='#ff9100'>橙色装备精炼提示：\r</font><font color='#ffffff'>1：请将需要进行操作的装备放入左侧装备栏\r2：请确认背包内有“<font color='#00ff00'>%1</font>”\r3：点击“开始精炼”按钮即可开始精炼操作</font>"
const 橙装精炼注意 := "<font color='#ff9100'>注意：\r</font><font color='#ffffff'>只有橙色装备才可进行精炼操作\r橙装的精炼操作成功率为100%</font>"
const 橙装精炼标签 := "传说属性精炼成功后，将随机重置获得一条新的传说属性"
## 打造门槛（`YellowEquipLianZhiWindow.strengthHandler:146-198`：
## `strengthLevel < 10` / `reqLevel < EquipManager.EQUIP_PROP_LIMIT_LEVEL = 60`）。
const 橙装打造满星 := 10
const 橙装打造等级限 := 60


func _render_橙装打造() -> void:
	var page := _instantiate_page(橙装打造场景)
	_给页挂提示框(page)

	# 页签两枚：原版 `selectedBtnHandler:409-413` 先 `backItemToEquip()` 再重画 ⇒ 换页清装备。
	for i in 2:
		var 签 := page.get_node("分页/" + ["橙装打造", "橙装精炼"][i]) as Button
		_apply_tab_skin(签)
		选页签(签, _橙装_页 == i)
		for 连 in 签.pressed.get_connections():
			签.pressed.disconnect(连["callable"])
		签.pressed.connect(_切橙装页.bind(i))

	var 页 := clampi(_橙装_页, 0, 1)
	var 装备 := _橙装_装备()
	var 有装备 := not 装备.is_empty()
	var 部位 := String(_装备元(String(装备.get("id", ""))).get("type_name", ""))
	var 配置 := 装备打造表.取橙装打造(部位) if 页 == 0 else 装备打造表.取橙装精炼()
	var 材料id := int(配置.get("needItemId", 0))
	var 材料名 := 装备打造表.物品名(材料id)
	var 需要数 := int(配置.get("needItemCnt", 0)) if 页 == 0 else 1

	# 装备格（`_itemBox.itemCell`）+ 品质外框 + 悬停详情
	var 图标 := page.get_node("内容容器/装备格/装备图标") as TextureRect
	图标.texture = null
	if 有装备:
		var 图路 := String(装备.get("icon", ""))
		if not 图路.is_empty() and ResourceLoader.exists(图路):
			图标.texture = load(图路) as Texture2D
	_挂装备品质(page.get_node("内容容器/装备格") as Control, 装备 if 有装备 else {})
	_接打造装备提示(page, page.get_node("内容容器/装备格") as Control, 装备)

	# 放入/取出（原版 `clickDropBtnHandler:322-335`：已放 ⇒ `backItemToEquip`，不发帧）
	var 放入 := page.get_node("内容容器/放入装备") as Button
	_configure_standard_button(放入)
	放入.text = "取出装备" if 有装备 else "放入装备"
	for 连 in 放入.pressed.get_connections():
		放入.pressed.disconnect(连["callable"])
	放入.pressed.connect(_橙装_按放入钮.bind(page))

	# 三段文案（`updateView:244-290` 两个 case）
	if 页 == 0:
		(page.get_node("内容容器/说明") as RichTextLabel).text = 译文为BBCode(橙装打造说明.replace("%1", 材料名))
		(page.get_node("内容容器/注意") as RichTextLabel).text = 译文为BBCode(橙装打造注意)
		(page.get_node("内容容器/标签") as Label).text = 橙装打造标签
	else:
		(page.get_node("内容容器/说明") as RichTextLabel).text = 译文为BBCode(橙装精炼说明.replace("%1", 材料名))
		(page.get_node("内容容器/注意") as RichTextLabel).text = 译文为BBCode(橙装精炼注意)
		(page.get_node("内容容器/标签") as Label).text = 橙装精炼标签

	# 材料格（`_caiLiao1`）：打造页按**部位**取 `needItemCnt`，精炼页恒 1。
	# 打造页藏「购买」、材料盒整体下沉 10（`updateView`：`y = BORDER_GAP + 10` / `BORDER_GAP`）。
	var 材料盒 := page.get_node("内容容器/材料框/材料一") as Control
	材料盒.position.y = 15.0 if 页 == 0 else 5.0
	(page.get_node("内容容器/材料框/材料一/材料名") as Label).text = 材料名
	var 材料图标 := page.get_node("内容容器/材料框/材料一/材料格/材料图标") as TextureRect
	材料图标.texture = GAME_DATA.item_icon(材料id) if 材料id > 0 else null
	var 数量 := page.get_node("内容容器/材料框/材料一/材料格/材料数量") as Label
	数量.text = str(需要数) if 页 == 1 or 需要数 > 0 else " "
	_配置材料数量(数量)
	var 材料格 := page.get_node("内容容器/材料框/材料一/材料格") as TextureRect
	_套格子灰(材料格, not 有装备 or 需要数 <= 0 or 装备打造表.拥有数(_session, 材料id) < 需要数)
	_接打造提示(page, 材料格, 材料id, maxi(1, 需要数))
	var 购买 := page.get_node("内容容器/材料框/材料一/购买") as Button
	_configure_standard_button(购买, 购买钮尺寸)
	购买.visible = 页 == 1
	购买.disabled = 材料id <= 0
	if 材料id > 0:
		购买.pressed.connect(请求商城商品.bind(str(材料id)))

	# 消耗/几率（`updateXingYunRatio:110-145`）：精炼页且橙装时先带一行传说属性。
	var 文 := ""
	if 页 == 1 and 有装备 and int(装备.get("aptitude", 0)) == 5:
		var 传类型 := int(装备.get("tale_attr_type", -1))
		var 传名 := String(装备提示框.属性名.get(传类型, "属性%d" % 传类型))
		文 += "[color=#ffffff]传说属性：[/color][color=#fff000]%s +%d[/color]\n" % [
				传名, int(装备.get("tale_attr_value", 0))]
	文 += "[color=#ffffff]本次操作消耗金币：0\n本次操作成功几率：100%[/color]"
	(page.get_node("内容容器/材料框/消耗文本") as RichTextLabel).text = 文

	var 执行 := page.get_node("内容容器/开始打造") as Button
	_configure_standard_button(执行)
	执行.text = "开始打造" if 页 == 0 else "开始精炼"
	for 连 in 执行.pressed.get_connections():
		执行.pressed.disconnect(连["callable"])
	执行.pressed.connect(_执行橙装打造)

	# 落点件：同 梦幻属性符（场景是生成物，`set_script` 在运行期挂；先例 修复放入格）
	var 格 := page.get_node("内容容器/装备格") as Control
	格.set_script(梦幻放入格组件)
	格.mouse_filter = Control.MOUSE_FILTER_STOP
	for 连 in 格.请求放入.get_connections():
		格.请求放入.disconnect(连["callable"])
	格.请求放入.connect(橙装_收料)


## 现读会话里放着的那件（原版 `itemDatachanged:427-443`：按 `_itemData.position` 重取）。
func _橙装_装备() -> Dictionary:
	if _橙装_装备格 <= 0:
		return {}
	var 条: Dictionary = _session._占用条(_session.inventory, _橙装_装备格)
	if 条.is_empty() or String(条.get("id", "")) != _橙装_装备id:
		_橙装_清装备()
		return {}
	return 条


## 原版 `backItemToEquip:415-425`。
func _橙装_清装备() -> void:
	_橙装_装备格 = 0
	_橙装_装备id = ""


## 放入/取出（原版 `clickDropBtnHandler:322-335`：已放 ⇒ `backItemToEquip`，都不发帧）。
## 没放 ⇒ 公共「放入选择」弹层（原版 `UpShelfCursor` 的等价通道，2026-11-08）。
func _橙装_按放入钮(页: Control) -> void:
	if _橙装_装备格 > 0:
		_橙装_清装备()
		_render_page()
		return
	var 清单 := _背包装备候选()
	if 清单.is_empty():
		_show_hint("背包里没有可放入的装备")
		return
	放入选择器.弹(页, 清单,
			func(行: Dictionary) -> void: 橙装_收料(int(行.get("格", 0))))


## 换页签：原版 `selectedBtnHandler:409-413` —— 先 `backItemToEquip()` 再重画。
func _切橙装页(页: int) -> void:
	if 页 == _橙装_页:
		return
	_橙装_页 = 页
	_橙装_清装备()
	_render_page(true)


## 落上一件装备。原版 `validateItem:292-330`：只认"打造装备"（人物/宠物），
## 再按顺序拦 时装 / 玉链 / 徽章 / 破损 —— **资质不在这里判**（打造页才判紫、精炼页才判橙）。
func 橙装_收料(背包格: int) -> void:
	var 条: Dictionary = _session._占用条(_session.inventory, 背包格)
	if 条.is_empty():
		return
	var 物品id := String(条.get("id", ""))
	var 补零 := 物品id.pad_zeros(8)
	var 类型号 := int(补零.substr(0, 2)) if 补零.length() >= 2 else 0
	if 类型号 != 1 and 类型号 != 2:
		_show_hint("对不起，该物品不能被打造")                    # `EQUIP_STRENGTH_FAIL_PROMPT_1`
		return
	if 补零.substr(2, 2) == "21":                              # `isItemAShiZhuang`
		_show_hint("对不起，%s不可以进行打造！" % "变身卡")        # 7[0] 替 7[1]
		return
	var 四位 := int(补零.substr(0, 4))
	if 四位 == 120:                                            # `isItemAYuLian`
		_show_hint("对不起，%s不可以进行打造！" % "玉链")          # 7[0] 替 7[2]
		return
	if 四位 == 141:                                            # `isItemAHuiZhang`
		_show_hint("该物品无法进行此操作。")                       # `HUIZHANG_STRENGTH_FAIL_PROMPT`
		return
	if int(条.get("crash_time", 0)) > 0:
		_show_hint("对不起，该装备已经破损！")                     # 10[0] 替 10[2]
		return
	_橙装_装备格 = 背包格
	_橙装_装备id = 物品id
	_render_page()


## 「开始打造 / 开始精炼」：原版 `strengthHandler:146-198` 的闸门**逐条照抄**（一条不过就不发）。
func _执行橙装打造() -> void:
	var 装备 := _橙装_装备()
	if 装备.is_empty():
		_show_hint("请放入装备！")                                # 6[0] 替 6[1]
		return
	var 页 := clampi(_橙装_页, 0, 1)
	var 部位 := String(_装备元(String(装备.get("id", ""))).get("type_name", ""))
	var 配置 := 装备打造表.取橙装打造(部位) if 页 == 0 else 装备打造表.取橙装精炼()
	if int(配置.get("needMoney", 0)) > int(_session.player_stats.get("gold", 0)):
		_show_hint("很抱歉，你的金币不够")                        # 2[0] 替 2[1]
		return
	if int(装备.get("crash_time", 0)) > 0:
		_show_hint("对不起，该装备已经破损！")                     # 10[0] 替 10[2]
		return
	var 材料id := int(配置.get("needItemId", 0))
	var 需要数 := int(配置.get("needItemCnt", 0)) if 页 == 0 else 1
	if 需要数 > 0 and 装备打造表.拥有数(_session, 材料id) < 需要数:
		_show_hint("很抱歉，你的%s不够" % 装备打造表.物品名(材料id))   # 2[0] 替 2[1]
		return
	if 页 == 0:
		if int(装备.get("aptitude", 0)) != 4:
			_show_hint("该装备不是紫装，不符合橙装打造要求，无法进行打造")   # `YELLOWEQUIP_PINGJI_ERROR`
			return
		if int(装备.get("strengthen", 0)) < 橙装打造满星:
			_show_hint("该装备非满星状态，不符合橙装打造要求，无法进行打造") # `YELLOWEQUIP_XING_ERROR`
			return
		if _装备需求等级(装备) < 橙装打造等级限:
			_show_hint("该装备等级低于60级，不符合橙装打造要求，无法进行打造") # `YELLOWEQUIP_LEVEL_ERROR`
			return
	elif int(装备.get("aptitude", 0)) != 5:
		_show_hint("该装备不符合橙装精炼要求，无法进行精炼")          # `YELLOWEQUIP_JINGLIAN_ERROR`
		return
	var 后端 = _backend
	if 后端 == null or not 后端.has_method(
			"request_change_to_orange" if 页 == 0 else "request_change_tale_attribute"):
		_show_hint("橙装打造要在服务端结算（离线不模拟）")
		return
	var 发出 := false
	if 页 == 0:
		发出 = 后端.request_change_to_orange(_橙装_装备格)
	else:
		发出 = 后端.request_change_tale_attribute(_橙装_装备格)
	if not 发出:
		_show_hint("打造请求发送失败")


## 打开橙装打造窗（`showYellowEquipLianZhiWindow(0/1)`）。同 `_开梦幻属性符窗`：
## 先 `打开` 建窗、写页签与清装备、再 `打开` 一次才按新状态渲染。
func _开橙装打造窗(页: int) -> void:
	var 管理: Node = get_parent()
	if 管理 == null or not 管理.has_method("打开") or not 管理.has_method("取窗口"):
		_show_hint("橙装打造：找不到窗口管理")
		return
	管理.call("打开", "橙装打造")
	var 窗: Node = 管理.call("取窗口", "橙装打造")
	if 窗 == null:
		_show_hint("橙装打造：窗没开出来")
		return
	窗.set("_橙装_页", 页)
	窗.set("_橙装_装备格", 0)
	窗.set("_橙装_装备id", "")
	窗.call("打开")


func _render_skill_books() -> void:
	# 2026-10-03 合并另一位开发者的「秘笈合成页」包：31 个节点全部烘进 .tscn
	# （由 开发工具/生成秘笈合成场景.py 从量具表 截秘笈合成页.gd 生成），样式不再在运行期刷
	# ——旧版这里对每条文本 `_configure_label(…, 10, …)` 重设字号、`load(ORIGINAL_SLOT)` 补图，
	# 正是"编辑器看到的和实机不是同一套"的病根。协议三条（放入拖放/合成 ITEM_CHANGE/购买商城）
	# 仍未接，控制器只给原版文案的回执（`测试/秘笈合成页回归测试.gd` 钉着）。
	秘笈合成窗口.渲染(self)

## 「遗址（意志背包）/意志学习/意志介绍」三窗（2026-10-03 合并另一位开发者的意志页包）：
## 版式+交互全在 `脚本/界面/窗口/意志窗口.gd` 的三个静态渲染函数，分派表直接调它们。
## 旧版这里的手摆（663×410 那张场景 + 逐控件 `_configure_label` 运行期刷样式）已整段删除——
## 它和真值 663×548 不同源，`测试/意志页回归测试.gd` 钉着"旧手摆版场景不许回来"。
## 协议族 1823 `SPIRIT_ACTION` 整族未接 ⇒ 按钮只写"需要连接原版服务端"的回执（诚实话）。

## 原版「交易」窗（`ShopWindow2.as`）。版式见 场景/界面/窗口/NPC商店/NPC商店窗口.tscn 的头注释。
##
## 三件事跟 2026-09-26 之前不一样：
##   1. **页签按服务端下发的 `groups` 现建**（`createTabBtn`，`:347-370`），宽 = `[0,25,37,49,61][名字长度]`。
##      以前写死「全部/装备/药品」三个、还按前端字符串过滤 `category`。
##   2. **格子按 110x41 + hgap6/vgap3 的真网格摆**（`initCellCount`，`:279-313`），带滚动、全条目。
##      以前是 `12+123i` / `34+68r` 的两列、还 `mini(size,6)` 砍到只剩 6 个。
##   3. **点格子弹买卖数量窗**（`onItemClick`，`:415-424`），数量在那个窗里选。
##      以前是格子里塞 SpinBox，那不是原版的东西。
func _render_npc_shop() -> void:
	var page := _instantiate_page(NPC商店页面场景)
	var 分组 := _npc商店分组()
	_建npc商店页签(page.get_node("分页") as Control, 分组)

	var 本组: Array = []
	if _npc_shop_tab >= 0 and _npc_shop_tab < 分组.size():
		本组 = 分组[_npc_shop_tab].get("items", []) as Array
	elif not 分组.is_empty():
		# 服务端换了分组列表、下标越界时落回第一组（原版 `setItemCellData(0)` 也是这个兜底）
		_npc_shop_tab = 0
		本组 = 分组[0].get("items", []) as Array

	var 商品列表 := page.get_node("商品面板/商品滚动/商品列表") as Control
	_建商店商品格(page, 商品列表, 本组)
	(page.get_node("商品面板/商品滚动") as ScrollContainer).scroll_vertical = 0
	_接npc商店按钮(page)
	_接买卖信号(page)


## 服务端下发的分组。`数据链`：`后端连接._handle_npc_shop_text`（`:1948-1979`）已经解析出
## `tabs = [{name, items}]`，但 `游戏会话.apply_backend_npc_shop` 以前只存了 `items` 把 `tabs` 丢了。
## 拿不到就退回一个单组「全部」，至少不空窗。
func _npc商店分组() -> Array:
	var 在线: Array = _session.get_selected_npc_shop_tabs()
	if not 在线.is_empty():
		return 在线
	# 离线/服务端没给 groups 时的兜底：单组「全部」。
	# ⚠️ 再空也**要留这一组** —— 页签是这一页唯一的分组标题，一组都没有等于整页没有导航；
	# 原版服务端永远至少下一组，轮不到这个分支。
	return [{"name": "全部", "items": _session.get_selected_npc_shop()}]


## `createTabBtn()`（`ShopWindow2.as:347-370`）+ `getTabBtnWidth`（`:456-460`）+ `_tabBtnWidthArr`（`:33`）。
## ⚠️ 宽度是**按名字长度查表**，不是定值：2 字 = 37、3 字 = 49。
## ⚠️ x 是**累加**的（`:360` `_loc1_.x = tabBtnContainer.width + 1`）。
##    `Sprite.width` 是包围盒宽、**不含**起始偏移，所以首项 x=1、之后每项步进 = 上一项的宽度，
##    即 x_i = 1 + Σ(w_j, j<i)。等宽 49 时就是 1/50/99/148…，**不是** 50 的整数倍。
const 页签宽度表 := [0.0, 25.0, 37.0, 49.0, 61.0]

func _建npc商店页签(容器: Control, 分组: Array) -> void:
	for 旧 in 容器.get_children():
		容器.remove_child(旧)
		旧.queue_free()
	var 起点 := 1.0
	for index in 分组.size():
		var 名 := String((分组[index] as Dictionary).get("name", ""))
		var 宽: float = 页签宽度表[clampi(名.length(), 0, 页签宽度表.size() - 1)]
		var 页签 := Button.new()
		页签.text = 名
		页签.toggle_mode = true
		页签.focus_mode = Control.FOCUS_NONE
		页签.theme_type_variation = WINDOW_SKIN.皮肤表.变体_分页
		页签.position = Vector2(起点, 0.0)
		页签.size = Vector2(宽, 22.0)
		选页签(页签, index == _npc_shop_tab)
		页签.pressed.connect(_set_npc_shop_tab.bind(index))
		容器.add_child(页签)
		起点 += 宽


## `initCellCount()`（`ShopWindow2.as:279-313`）。网格是**子件包围盒**推出来的 110x41：
##   列 x：偶数格 `hgap` = 6，奇数格 `width + hgap` = 116
##   行 y：第 0 行 `vgap` = 3；其余行 `height*r + vgap*r` = 44r
func _建商店商品格(页面: Control, 商品列表: Control, 本组: Array) -> void:
	for 旧 in 商品列表.get_children():
		商品列表.remove_child(旧)
		旧.queue_free()
	const 列宽 := 110.0
	const 行高 := 41.0
	const 横距 := 6.0
	const 纵距 := 3.0
	var 最大底 := 0.0
	for index in 本组.size():
		var 商品: Dictionary = 本组[index]
		var 列 := index % 2
		var 行 := index / 2
		var 格子 := 商店商品格场景.instantiate() as Button
		格子.position = Vector2(
			列宽 * 列 + 横距 * (列 if 列 > 0 else 1),
			行高 * 行 + 纵距 * (行 if 行 > 0 else 1)
			)
		最大底 = maxf(最大底, 格子.position.y + 行高)
		(格子.get_node("物品格") as Panel).theme_type_variation = WINDOW_SKIN.皮肤表.变体_物品格
		var 路径 := String(商品.get("icon", ""))
		(格子.get_node("物品格/图标") as TextureRect).texture = (
			load(路径) as Texture2D if ResourceLoader.exists(路径) else null
		)
		(格子.get_node("价格底") as Panel).theme_type_variation = WINDOW_SKIN.皮肤表.变体_输入框底
		(格子.get_node("名称") as Label).text = String(商品.get("name", ""))
		(格子.get_node("价格") as Label).text = str(int(商品.get("price", 0)))
		(格子.get_node("禁装") as TextureRect).visible = not _可装备(String(商品.get("id", "")))
		格子.pressed.connect(_开买卖窗.bind(商品, true))
		商品列表.add_child(格子)
		# 悬停提示：原版 `ShopWindowCell` 挂 `MToolTipItem`，与背包格**同一套分发**
		# （`MToolTipItem.as:73-109`：`EqpData` → `MToolTipZhuangBei`，其余 → `MToolTipDefault`）。
		# 所以直接复用背包那份，不另写 —— 见 NPC商店窗口.tscn 尾部加的实例。
		# ⚠️ 对比列也照原版：`ShopWindowCell.as:164` 是**四参**
		#    `createToolTip(stage, this, value, this.getEquipedItem())`，那个私有函数
		#    （`:53-64`）就是「按槽位取我身上穿的」⇒ 商店货架带右侧穿戴对比。
		背包窗口._接提示框(self, 页面, 格子, 商品, true)
	# 同商城那边：`ScrollContainer` 只认子节点的 `custom_minimum_size`（见 `社交窗口.gd` 的注释），
	# 写 `size` 会被容器立刻改回 0，表现是货架滚不动。
	# 同商城：`set_deferred` 等布局跑完再放回滚动位置（见 `_shop_scroll` 的注释）。
	# ⚠️ 这里拿不到 `page`（本函数只收 `商品列表`），顺着父节点取滚动容器。
	var 滚动 := 商品列表.get_parent() as ScrollContainer
	if 滚动 != null:
		WINDOW_SKIN.皮肤表.配原版滚动区(滚动, 商品列表, 255.0, 220.0, 最大底)
	if 滚动 != null:
		滚动.set_deferred("scroll_vertical", int(_npc_shop_scroll))


## `ItemData.isFitMe(FIT_ALL)`（`ItemData.as:302-316`）：
## `reqJob == 0 || reqJob == 自己职业` 且 `level >= reqLevel`。
## 职业需求在 `数据/物品装备元数据.json` 的 `required_job`，等级需求在 `数据/物品.json` 的 `required_level`。
## 非装备（查不到元数据）没有装备条件，恒可装备。
func _可装备(物品id: String) -> bool:
	var 元 := _装备元(物品id)
	if 元.is_empty():
		return true
	var 职业 := int(元.get("required_job", 0))
	if 职业 != 0 and 职业 != int(_session.player_stats.get("job", 0)):
		return false
	var 等级 := int((GAME_DATA.item(物品id) as Dictionary).get("required_level", 0))
	return int(_session.player_stats.get("level", 1)) >= 等级


## `setupMouseEvents()`（`ShopWindow2.as:533-544`）+ `onClickMendBtn`（`:153-156`）/
## `onQuickSaleBtn`（`:569-572`）。
##
## ⚠️ 购买/出售在原版是**切光标**（`CursorManager.showCursorUI("ShopBuyCursorF"/"ShopSaleCursorF")`）：
##    选中「出售」之后**点背包里的物品**才会弹买卖窗（`UIConfig.saleValidateFun`，`:648`），
##    商品格本身**不管在哪个模式都是买**（`onItemClick` 不判 `_isBuy`）。
##    所以这里不再像以前那样"出售模式就把货架换成背包"——那是自造的。
##    光标换成了 `商店出售模式` 这个跨窗口开关，背包那边读它（同 `批量存取模式` 的做法）。
func _接npc商店按钮(page: Control) -> void:
	var 购买 := page.get_node("购买") as Button
	var 出售 := page.get_node("出售") as Button
	购买.toggle_mode = true
	出售.toggle_mode = true
	购买.button_pressed = _npc_shop_mode == 0
	出售.button_pressed = _npc_shop_mode == 1
	购买.pressed.connect(_set_npc_shop_mode.bind(-1 if _npc_shop_mode == 0 else 0))
	出售.pressed.connect(_set_npc_shop_mode.bind(-1 if _npc_shop_mode == 1 else 1))
	(page.get_node("一键出售") as Button).pressed.connect(_quick_sell_items)
	(page.get_node("修理") as Button).pressed.connect(_repair_equipment)


## 买卖数量窗只发信号，协议在这里发（组件只报意图，同 `拆分窗口`/`销毁窗口`）。
func _接买卖信号(page: Control) -> void:
	var 窗 := page.get_node_or_null("买卖数量窗") as Control
	if 窗 == null:
		return
	if not 窗.确定买卖.is_connected(_成交):
		窗.确定买卖.connect(_成交)


func _成交(是买: bool, 物品id: String, 数量: int, 槽位: int) -> void:
	if 是买:
		_buy_npc_item(物品id, 数量)
	else:
		# ⚠️ 卖的是**玩家点的那一格**（`买卖数量窗` 把开窗时那格的 slot 带回来了）。
		#    原来这里只拿 id ⇒ 会话按 id 反查首摞，同 id 两摞会卖错那一款（巡检 #16）。
		_sell_item(槽位, 数量)


## 弹**商城购买窗**。原版那条链：`CashItemCell` 购买 → `CashShopWindowEvent.BUY_FROM_LIST`
## → `CashShopWindow2.__buyItem`（`:444-451`）→ `new BuyEqpWindow(); setData(data)`。
func _开商城购买窗(商品: Dictionary) -> void:
	# 窗已搬上 `_overlay`（§3.145），重建页面开不出它；直接走统一出口。
	打开商城购买窗(商品)




func _商城购买窗关了() -> void:
	_商城购买商品 = {}
	var 遮罩 := _购买窗遮罩节点()
	if 遮罩 != null:
		遮罩.visible = false
	_收回购买窗()


## 把本宿主那枚购买窗**收掉**（只藏，不发 `关闭了` —— 那条是"玩家自己点了 X"才走的）。
## 给 `窗口管理.收起其他购买窗` 调：一发 1079 只该留下一枚购买窗（原版全局一枚）。
func 收起购买窗() -> void:
	_商城购买商品 = {}
	if _overlay == null:
		return
	var 窗 := _购买窗节点()
	if 窗 != null:
		窗.visible = false
	var 遮罩 := _购买窗遮罩节点()
	if 遮罩 != null:
		遮罩.visible = false
	_收回购买窗()


## 购买窗平时住宿主 `遮罩`，被 `_抬购买窗` 抬到「购买窗舞台层」后要两处都找
## （`收起购买窗` / `刷新商城购买窗余额` / 重开复用都会在抬着的时候进来）。
func _购买窗节点() -> Control:
	var 窗 := (_overlay.get_node_or_null("商城购买窗") as Control) if _overlay != null else null
	if 窗 != null or not is_inside_tree():
		return 窗
	var 层 := get_tree().root.get_node_or_null(购买窗舞台层名)
	return (层.get_node_or_null("商城购买窗") as Control) if 层 != null else null


func _购买窗遮罩节点() -> Control:
	var 遮 := (_overlay.get_node_or_null(购买窗遮罩名) as Control) if _overlay != null else null
	if 遮 != null or not is_inside_tree():
		return 遮
	var 层 := get_tree().root.get_node_or_null(购买窗舞台层名)
	return (层.get_node_or_null(购买窗遮罩名) as Control) if 层 != null else null


## 根下「屏幕弹窗层」此刻有没有亮着的弹窗（手里剑突破/提速、八门突破瓶颈那几张）。
## 有 ⇒ 宿主这一层（111..118）的购买窗会被它连整屏暗幕一起压住。
func _有屏幕级弹窗亮着() -> bool:
	if not is_inside_tree():
		return false
	var 层 := get_tree().root.get_node_or_null("屏幕弹窗层") as CanvasLayer
	if 层 == null:
		return false
	for 子 in 层.get_children():
		var 控 := 子 as Control
		if 控 != null and 控.is_visible_in_tree():
			return true
	return false


## 把购买窗和它的整屏遮罩抬到「购买窗舞台层」（> 屏幕弹窗层）。坐标不用换算：
## `遮罩` 与根级 CanvasLayer 都以视口左上角为原点。
func _抬购买窗(窗: Control) -> void:
	if 窗 == null or not _有屏幕级弹窗亮着():
		return
	var 层 := get_tree().root.get_node_or_null(购买窗舞台层名) as CanvasLayer
	if 层 == null:
		层 = CanvasLayer.new()
		层.name = 购买窗舞台层名
		层.layer = 购买窗舞台层号
		get_tree().root.add_child(层)
	if 窗.get_parent() != 层:
		窗.reparent(层)
	var 遮罩 := _overlay.get_node_or_null(购买窗遮罩名) as Node
	if 遮罩 != null and 遮罩.get_parent() != 层:
		遮罩.reparent(层)
		层.move_child(遮罩, 窗.get_index())		# 遮罩压到窗下面（`move_child` 先摘后插）


## 抬上去的购买窗不跟着 `_overlay.visible = false` 走（`close()` 只藏 `遮罩`）
## ⇒ 关窗/收起时统一收回来，保持"平时住在 `_overlay`"这条老口径（多处门按它断）。
func _收回购买窗() -> void:
	if _overlay == null:
		return
	var 窗 := _购买窗节点()
	if 窗 != null and 窗.get_parent() != _overlay:
		窗.visible = false
		窗.reparent(_overlay)
	var 遮罩 := _购买窗遮罩节点()
	if 遮罩 != null and 遮罩.get_parent() != _overlay:
		遮罩.visible = false
		遮罩.reparent(_overlay)


## 本宿主身上**此刻有没有浮层**（MDialog 那三种弹、商城购买窗、通用确认/输入弹层）。
## 给 `窗口管理.重排层级()` 用 —— 原版 `UIMain2.bringMWindowToTop:3693-3712` 把窗口置顶的
## 目标索引钉在 `max(0, getChildIndex(scrolledAnnouncePane) − 2)`：**窗口永远升不到弹窗之上**
## （弹窗是 `PopUpMananger.showWindow:74-108` 直接挂 `uiMain` 的兄弟，且 `showSwapDialog:1866-1873`
## 还要再把它 `setChildIndex(…, numChildren − 1)` 顶到最末）。
## 我们的浮层挂在**本宿主的 `遮罩` 里**（= 跟着宿主那个 CanvasLayer 走），所以同一条不变量
## 只能落成"身上有浮层的那一扇，层号必须最大"。少了这条：点另一扇窗的任意位置都会把
## 这扇的浮层连它的整屏遮罩一起压到底 ⇒ 遮罩还在吞输入、按钮却收不到按下
## = 用户 10-22 午后实机报的「提示点完确定之后整屏卡住」。
func 有浮层() -> bool:
	if _overlay == null:
		return false
	for 子 in _overlay.get_children():
		var 控 := 子 as Control
		if 控 != null and 控.is_visible_in_tree() and bool(控.get_meta(输入确认弹.浮层标记, false)):
			return true
	return false


## 见 `_bind_scene_nodes()` 里那条连接：只有带浮层标记的才要动层序（页面里挂进 `遮罩` 的
## 别的件不该顺带把整扇窗提到最上）。
func _浮层进场(子: Node) -> void:
	var 控 := 子 as Control
	if 控 == null or not bool(控.get_meta(输入确认弹.浮层标记, false)):
		return
	var 管 := get_parent()
	if 管 != null and 管.has_method("重排层级"):
		管.call("重排层级")


## 购买窗的**整舞台遮罩**。原版 `CashShopWindow2.as:450`：
## `PopUpMananger.centerWindow(buyEqpWindow, true)` —— 那个 `true` 就是"要遮罩"，
## `showWindow` 里画一片 `STAGE_WIDTH×STAGE_HEIGHT` 的 `beginFill(_bgColor=0, _bgAlpha=**0.3**)`，
## 窗挂在它**上面**（`:96-124`）。
## ⚠️ 老账里"`popUpMananger` 全屏遮罩（居中弹只做了居中）"就是这一条 —— 以前只把窗摆到正中。
## ⚠️ 点遮罩**不关窗**：原版 `onMaskView:146-153` 只在有拖拽时 `removeDragDataProxy()`。
##    所以这里 `mouse_filter = STOP`（挡穿透）但**不接**任何点击回调 —— 与 §3.116 那条
##    "点遮罩只取消拖拽、不关窗"取同一条口径。
func _前置购买窗遮罩(窗: Control) -> void:
	# ⚠️ 只有挂在 `_overlay` 上的那枚能这么压。**2026-10-13 §3.145**：社交窗口那条路以前把购买窗
	# **烘在页面里**（父链在 `主窗口/页面容器` 之下 ⇒ 这层遮罩会盖在它**上面**、反而把窗藏了），
	# 已改成统一走 `打开商城购买窗` ⇒ 现在**所有入口都是 `_overlay` 上那一枚**。
	# 护栏留着：万一将来又有人把购买窗挂回页面里，这里至少不会把它盖没。
	if 窗 == null or 窗.get_parent() != _overlay:
		return
	var 遮罩 := _overlay.get_node_or_null(购买窗遮罩名) as ColorRect
	if 遮罩 == null:
		遮罩 = ColorRect.new()
		遮罩.name = 购买窗遮罩名
		遮罩.set_anchors_preset(Control.PRESET_FULL_RECT)
		遮罩.color = Color(0.0, 0.0, 0.0, 0.3)
		遮罩.mouse_filter = Control.MOUSE_FILTER_STOP
		遮罩.set_meta(输入确认弹.浮层标记, true)
		_overlay.add_child(遮罩)
	遮罩.visible = true
	# ⚠️ 这两枚的 `z_index` 是**模态形状**的一部分，不是装饰（用户 2026-10-22 报修 10
	#   「商城购买道具的面板显示优先级过低，老是点一下就下降到最下面」）。
	#   `窗口管理._input` 的「点任何窗都置顶」在提之前先问一遍 `模态弹罩住(点)`，而那一句认的是
	#   **形状**：`z_index >= 100` **且** `mouse_filter = STOP`（`功能窗口.模态弹罩住`，认形状不认节点名）。
	#   以前这层遮罩 z_index 留默认 **0** ⇒ 形状认不出来 ⇒ 玩家在购买窗上点一下，`_input` 照样把
	#   **矩形盖住那一点**的别的窗翻到最上；而购买窗住在宿主自己的 CanvasLayer 里
	#   （`layer = HUD基 + 序号`，见 `窗口管理.重排层级`）⇒ 别的窗 layer 一变大就把弹窗整个压下去
	#   = 报修 10 那句「点一下就下降到最下面」。
	#   原版没这个洞，因为 `PopUpMananger` 把弹窗挂在 **stage 那一层**（自成一层，底下的窗翻不上来）
	#   ⇒ 这边的等价物就是：遮罩长成模态形状 ⇒ 弹窗开着期间一票都不提。
	# ⚠️ 画序靠 z_index（遮罩 100、窗 101 ⇒ 窗仍压遮罩）；下面那段 `move_child` 管的是**兄弟序**，
	#   两件事不冲突，`商城购买窗回归测试` 那条 `挡.get_index() < 窗.get_index()` 照旧成立。
	遮罩.z_index = 100
	窗.z_index = 遮罩.z_index + 1		# 不给死值：两者必须保持「窗压遮罩」
	# ⚠️⚠️ **挪到窗下面，索引要先把"遮罩自己原本占的那一格"扣掉**（2026-10-16 修）。
	#   `move_child(子, i)` 会**先摘掉再插**：若遮罩原本在窗**前面**（第二次及以后就是这样），
	#   摘掉它会让窗前移一格，这时再按 `窗.get_index()`（摘之前算的旧值）插回去，
	#   **遮罩就落到窗上面去了** —— 黑 α0.3 盖着窗 ⇒ **窗看着发灰、点哪儿都被遮罩吃掉**
	#   （用户实机报的"第二次进购买界面就变灰了、也点不了"就是这一条）。
	#   判据：先看遮罩在窗前面还是后面，前面就把目标下标减 1。
	var 目标位 := 窗.get_index()
	if 遮罩.get_index() < 目标位:
		目标位 -= 1
	_overlay.move_child(遮罩, 目标位)		# 压到窗**下面**


## 购买窗只发信号（组件只报意图，同 `买卖数量窗`）。它给的是 **sn**，
## 而 `游戏会话.buy_shop_item` 是按**物品 id** 找货架的 —— 所以这里用 sn 反查一次。
##
## ⚠️ 第三参 `用点券` **必须一路带到报文**（2026-10-17 巡检 #17）：原版那两枚勾选不是装饰 ——
##   `BuyEqpWindow.as:353` `shopType = ybCheckBox.selected ? 0 : 1`，
##   再 `UI.as:1453 Client.requestShopping(shopType, sn, quantity)`（`AllInOneProcessor:2789` 三个 writeInt）。
##   原来这条把它丢了 ⇒ 无论勾哪枚都发 0（元宝），点券余额纹丝不动。
func _成交商城(sn: int, 数量: int, 用点券: bool) -> void:
	for 商品 in _session.shop_catalog:
		if int(商品.get("sn", 0)) == sn:
			_buy_item(String(商品.get("id", "")), 数量, 用点券)
			return
	# 兜底：从「扩容窗/仓库窗」那条路弹出来的商品**不一定在货架上** ——
	# 1079 只有在货架里已经有同 sn 时才会并进 `authoritative_cash_shop`（`后端连接.gd:3525-3529`），
	# 而 `游戏会话.buy_shop_item` 是**按物品 id 在货架里找**的 ⇒ 找不到就静默什么都不发。
	# 这条路上直接按 sn 发（原版 `requestCashShopBuy(sn…)` 收的就是 sn）。
	if int(_商城购买商品.get("sn", 0)) == sn:
		if _backend != null and _backend.has_method("request_cash_shop_buy"):
			if _backend.request_cash_shop_buy(sn, maxi(1, 数量), 1 if 用点券 else 0):
				return
		_buy_item(String(_商城购买商品.get("id", "")), maxi(1, 数量), 用点券)


## 1079（商品详情）回包 ⇒ 弹**商城购买窗**。
## 原版那条链：`CashShopProcessor.handleCashItemInfo:159-176` → `Client.onCashItemInfo:7787-7791`
## → `UIMain2.addBuyWindow:2906-2913` —— 它 `requestCashMoney()` 之后**新建一枚独立的
## `BUY_EQP_WINDOW` 居中挂上**，**不开商城页**。走这条路的是「扩容窗 / 仓库窗」那枚「购买」
## （`EnlargeWindow.onClickBuy:169-174` 只 dispatch `REQUEST_CASH_ITEM_INFO` 带个物品 id，
## 自己不买东西）以及 `FubenLingWindow` / `ChangeNameWindow` 那几处。
##
## ⚠️ 修之前这里**没有消费者**：请求发出去了（`功能窗口.请求商城商品`）、
##    服务端回了、`cash_item_info_received` 也 emit 了，**全工程一次都没人听**
##    ⇒ 玩家点「购买」只看到一句"商城详情窗还没接这条路"。
## 1079 回包的**本宿主**入口：不是我这扇问的就不弹（一发回包弹 N 枚就是「关不掉」那条）。
##
## ⚠ 两档语义，缺任何一档都会踩掉一条既有门（10-22 合支实测）：
##   · **有人举旗**（`请求商城商品` 发过 1086）⇒ 只由举旗那扇接 —— 归属正确、不叠。
##   · **全场没人举旗** ⇒ 仍是原版那枚全局处理者（`UIMain2.addBuyWindow` 只挂一个 key）：
##     照旧开窗。老门 `商城购买窗回归测试` 直接 `emit` 回包、从没走过 1086，
##     只按旗挡会让它 14 条全红；而真机上 1079 只可能是 1086 的回包，这条兜底不会多弹。
##   两扇都举旗时（连点两处购买）各自都开，`打开商城购买窗` 里的
##   `收起其他购买窗` 收成全局一枚，后弹的赢 —— 与原版按 key 复用同形。
func _收1079(商品: Dictionary) -> void:
	## 归属以管理节点记的申请者为准（见 `窗口管理._购买申请者`）：不看各宿主的旗，
	## 因为先接 handler 的那扇会把旗清掉，后接的那扇就误判成"没人问"。
	## 申请者 null = 全场没走过 1086（老门直接 emit）⇒ 谁都接，由 `收起其他购买窗` 收成最后一枚。
	var 管 := get_parent()
	var 申请者 = 管.get("_购买申请者") if 管 != null and 管.has_method("收起其他购买窗") else null
	if 申请者 != null and 申请者 != self:
		return
	_等1079 = false
	## 归属旗保证"谁问的谁弹"；多宿主叠加由 `收起其他购买窗` 收成全局一枚。
	打开商城购买窗(商品)


func 打开商城购买窗(商品: Dictionary) -> void:
	if 商品.is_empty() or _overlay == null:
		return
	## **全局只留一枚**：先请别的宿主把自己那枚收干净。原版 `UIMain2.addBuyWindow:2906-2913`
	## 挂的是 `_windowMap[UIConfig.BUY_EQP_WINDOW]` 那一个 key ⇒ 天生只有一枚；而我们的 1079
	## 消费者是**每个开着的宿主各自**连的（本文件 `:417-418`）⇒ 一发回包弹两枚、叠在同一个
	## 正中位置，玩家点掉上面那枚下面还压着一枚 —— 10-20 深夜实机报「购买道具页关不掉」的根因。
	var 管 := get_parent()
	if 管 != null and 管.has_method("收起其他购买窗"):
		管.call("收起其他购买窗", self)
	_商城购买商品 = 商品.duplicate(true)
	var 后端 := get_node_or_null("/root/BackendConnection")
	if 后端 != null and 后端.has_method("request_cash_money"):
		后端.request_cash_money()		# 原版 `addBuyWindow` 第一句就是它
	# 遮罩上已经有一枚就复用（同一次会话连点两件商品时别叠成两层）。
	var 窗 := _购买窗节点()
	if 窗 != null and 窗.has_method("正在买") and bool(窗.call("正在买", int(商品.get("sn", -1)))):
		# **同一件商品、窗正亮着** ⇒ 只补余额，不重开。重走 `打开()` 会把玩家刚填的数量与
		# 刚勾的货币冲回默认（2026-10-18 实机报修「购买方式/购买数量点不动」），
		# 而且每来一条 1079 就多发一发 `request_cash_money`。
		窗.call("刷新余额", int(_session.player_stats.get("cash", 0)),
				int(_session.player_stats.get("cash_bind", 0)))
		return
	_商城购买商品 = 商品.duplicate(true)
	# 走 `_backend`（`_ready` 里就是 `/root/BackendConnection`）而不是现取一遍 autoload：
	# 同文件其余发包处都走这条，且门才能把它换成只记参数的假后端。
	if _backend != null and _backend.has_method("request_cash_money"):
		_backend.request_cash_money()		# 原版 `addBuyWindow` 第一句就是它
	if 窗 == null:
		窗 = 商城购买窗场景.instantiate() as Control
		窗.name = "商城购买窗"
		窗.set_meta(输入确认弹.浮层标记, true)		# 见 `有浮层()`：带浮层的那一扇不许被别的窗压住
		_overlay.add_child(窗)
	_前置购买窗遮罩(窗)
	_抬购买窗(窗)
	if not 窗.确认购买.is_connected(_成交商城):
		窗.确认购买.connect(_成交商城)
	if not 窗.关闭了.is_connected(_商城购买窗关了):
		窗.关闭了.connect(_商城购买窗关了)
	窗.call("打开", 商品,
			int(_session.player_stats.get("cash", 0)),
			int(_session.player_stats.get("cash_bind", 0)))


## 页面重建后给购买窗补一次余额（§3.145 起购买窗挂在 `_overlay` 上、不随页面重建消失）。
## 与 `打开商城购买窗` 的**分工**就一条：这条只碰余额数字，不碰玩家输入、不重发请求。
func 刷新商城购买窗余额() -> void:
	var 窗 := _购买窗节点()
	if 窗 == null or not 窗.visible or not 窗.has_method("刷新余额"):
		return
	窗.call("刷新余额", int(_session.player_stats.get("cash", 0)),
			int(_session.player_stats.get("cash_bind", 0)))




## 八门「开通穴道」的延迟引爆（原版 `Client.onMaiDelayExplode`）：
## 把自己那扇**人物窗**关掉，`秒 + 1` 之后再开回来。
## ⚠️ 只有"人物"那扇要动（原版那个 `uiMain.charWindow` 就是它）；别的页收到这条什么也不做。
## 为什么关窗而不是原地刷：服务端在倒计时结束后才结算并推统计帧，
## **重开一次**正好落在结算之后，既亮穴位又与原版**所见即所得**的节奏一致。
func _on_八门倒计时(秒: int) -> void:
	var 本页 := str(get("_固定页"))
	if 本页.is_empty():
		本页 = str(get("_current_page"))
	if 本页 != "人物":
		return
	close()
	get_tree().create_timer(maxf(1.0, float(秒)) + 1.0).timeout.connect(func() -> void:
		var 管理 := get_parent()
		if 管理 != null and 管理.has_method("打开"):
			管理.call("打开", "人物")
		# 到点了 ⇒ 问一次：服务端处理这条请求时会先把这次开通结算掉，页面随即拿到新的已开数
		if _backend != null and bool(_backend.in_game):
			_backend.request_bamen(1))


## 弹买卖数量窗。`ShopWindow2.showBuyAndSaleWindow`（`:93-151`）在买卖两条路上都走它：
## 点商品格（`:423`）与出售模式下点背包物品（`:648` 的 `saleValidateFun`）。
## 背包那条路由 `背包窗口._选中格子()` 读 `商店出售模式` 后调进来。
## `格位` = 玩家点的那一格（背包那边传 `格子.槽位号`）；从货架买不需要，留 0。
func _开买卖窗(物品: Dictionary, 是买: bool, 格位 := 0) -> void:
	var 窗 := _找买卖窗()
	if 窗 == null:
		return
	窗.call("打开", 物品, 是买, int(_session.player_stats.get("gold", 0)), 格位)


func _找买卖窗() -> Control:
	for 子 in _content.get_children():
		var 找 := (子 as Node).get_node_or_null("买卖数量窗")
		if 找 != null:
			return 找 as Control
	return null

func _render_storage() -> void:
	仓库窗口.渲染(self)

func _configure_original_panel(panel: Panel, outer := false) -> void:
	WINDOW_SKIN.configure_panel(panel, outer)

func _configure_value_input(input: LineEdit) -> void:
	WINDOW_SKIN.configure_value_input(input)

func _add_reward_row(parent: Control, row_position: Vector2, title_text: String, reward_text: String, available: bool) -> Button:
	var row := Panel.new()
	row.position = row_position
	row.size = Vector2(438.0, 44.0)
	row.add_theme_stylebox_override("panel", _sub_panel_style())
	parent.add_child(row)
	_add_positioned_label(row, title_text, Vector2(11.0, 4.0), Vector2(105.0, 35.0), 11, Color("#e7c37a"))
	_add_positioned_label(row, reward_text, Vector2(116.0, 4.0), Vector2(216.0, 35.0), 10, Color.WHITE)
	var button := _make_button("领取" if available else "未达成", "领取奖励")
	button.position = Vector2(350.0, 10.0)
	button.size = Vector2(66.0, 24.0)
	button.disabled = not available
	row.add_child(button)
	return button

func _make_label(text: String, size: int, color: Color) -> Label:
	return WINDOW_SKIN.make_label(text, size, color)

func _make_button(text: String, tooltip: String) -> Button:
	return WINDOW_SKIN.make_button(text, tooltip)

## 给"点了要给个说法"的按钮用的反馈口子 —— 复用窗口自带的 后端状态 标签，
## 而不是让按钮点了静默没反应（静默无反应会被当成"坏了"）。
## ⚠️ 传进来的话要**点名缺的是哪一条**（协议号/那一扇窗），不要写开发周期的话：
##    那种话会烂在包里，玩家看不出坏没坏，下一轮也看不出该补哪段。
func _show_hint(文本: String) -> void:
	if _status == null:
		return
	# 每一发都占一个新代号：上一发的自收还没到点就会被这个代号作废（连点同一颗钮时
	# 提示要从这一次重新数 5 秒，不能被上一次的定时器提前收掉）。
	_提示代号 += 1
	_status.text = 文本
	# ⚠ `后端状态` 这个 Label 在场景里是 `visible=false`，全工程没有一处设回来
	# ⇒ 各页"点了给个说法"的反馈在游戏里一个字都看不见（门只断 .text ⇒ 假绿）。
	_status.visible = not 文本.strip_edges().is_empty()
	if not _status.visible or not is_inside_tree():
		return
	get_tree().create_timer(提示自收秒).timeout.connect(_收起提示.bind(_提示代号))


## 提示到期（与 `_show_hint` 的 5 秒自收配成一对）。
## 作废条件两条：代号不是当初那一发（又来新提示了 / `close()` 收过）、或标签已经不在。
func _收起提示(代号: int) -> void:
	if 代号 != _提示代号 or _status == null or not is_instance_valid(_status):
		return
	_status.text = ""
	_status.visible = false


func _configure_standard_button(button: Button, 尺寸 := Vector2(57.0, 22.0)) -> void:
	WINDOW_SKIN.configure_standard_button(button, 尺寸)

func 选页签(tab: Button, 选中: bool) -> void:
	WINDOW_SKIN.选页签(tab, 选中)


## 页签选中态的**唯一入口**（口径写在 `界面皮肤.选页签` 的注释里 —— 必须同时置 `disabled`，
## 否则选中那枚走 `pressed` 槽、渲染成 −40 暗皮）。其它窗口一律 `窗口.选页签(...)` 走这儿。


func _apply_tab_skin(tab: Button) -> void:
	WINDOW_SKIN.apply_tab_skin(tab)

func _apply_list_selection_skin(button: Button) -> void:
	WINDOW_SKIN.apply_list_selection_skin(button)

func _original_content_panel() -> StyleBoxTexture:
	return WINDOW_SKIN.content_panel()

func _texture_style(path: String, tint := Color.WHITE) -> StyleBoxTexture:
	return WINDOW_SKIN.texture_style(path, tint)

func _make_quantity_picker(maximum: int) -> SpinBox:
	return WINDOW_SKIN.make_quantity_picker(maximum)

func _configure_progress_bar(bar: ProgressBar, force := false) -> void:
	WINDOW_SKIN.configure_progress_bar(bar, force)

func _configure_checkbox(check: CheckBox) -> void:
	WINDOW_SKIN.configure_checkbox(check)

func _configure_option_button(option: OptionButton) -> void:
	WINDOW_SKIN.configure_option_button(option)

func _configure_spin_box(spin: SpinBox) -> void:
	WINDOW_SKIN.configure_spin_box(spin)

func _apply_common_control_skins(node: Node) -> void:
	WINDOW_SKIN.apply_common_control_skins(node)

func _sub_panel_style() -> StyleBoxTexture:
	return WINDOW_SKIN.sub_panel_style()

func _icon_rect(path: String, icon_size: Vector2) -> Control:
	return WINDOW_SKIN.icon_rect(path, icon_size)

func _add_positioned_label(parent: Control, text: String, position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := _make_label(text, font_size, color)
	label.position = position
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _make_overlay_button(text: String, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	_configure_overlay_button(button, button_size)
	return button

func _configure_overlay_button(button: Button, button_size: Vector2) -> void:
	WINDOW_SKIN.configure_overlay_button(button, button_size)

func _configure_label(label: Label, font_size: int, color: Color) -> void:
	WINDOW_SKIN.configure_label(label, font_size, color)

func _instantiate_page(scene: PackedScene) -> Control:
	var page := scene.instantiate() as Control
	_apply_common_control_skins(page)
	_content.add_child(page)
	return page

## 忍术页签名，顺序即页签序号。原文见 en_US$message_properties.as 的 SKILL_TAB_BTN_TEXTS_1..5。
const 忍术页签名 := ["职业忍术", "世界忍术", "其他忍术", "奥义禁术", "特别技能"]
const 技能分页路径 := "res://数据/界面/技能分页.json"
## 页签清单里的占位符，运行时按角色职业展开（见 数据/界面/技能分页.json 的 _职业普攻占位）
const 职业普攻占位 := "$职业普攻"

static var _技能分页: Dictionary = {}

## 技能 → 页签归属表。原先这里写的是 `0 if skill_id.begins_with("1") else 1`，
## 只按 id 前缀分两组，导致「其他忍术」「奥义禁术」永远是空的。改为查数据表。
##
## 表的结构是 **按原版树栅格** 的：每个页签是若干「列」，列内自上而下即树上的先后。
## 依据是 AS3 `DataCenter.getSkillIdsForJob`（id 顺序）＋ 2026-09-18 逐格点开原版读的
## 66 格实测（`数据/界面/忍术树_真机实测.json`）。
static func _取技能分页() -> Dictionary:
	if not _技能分页.is_empty():
		return _技能分页
	var 文件 := FileAccess.open(技能分页路径, FileAccess.READ)
	if 文件 == null:
		push_error("技能分页表缺失：%s" % 技能分页路径)
		return {}
	var 解析结果: Variant = JSON.parse_string(文件.get_as_text())
	文件.close()
	if typeof(解析结果) != TYPE_DICTIONARY:
		push_error("技能分页表不是合法 JSON 对象：%s" % 技能分页路径)
		return {}
	var 页签: Variant = (解析结果 as Dictionary).get("页签", {})
	if typeof(页签) != TYPE_DICTIONARY:
		return {}
	_技能分页 = 解析结果 as Dictionary
	return _技能分页

## 返回某个页签**按树格子顺序**的全部技能（学过的带等级，没学过的 level=0）。
##
## 原版是按格子顺序摆技能的：AS3 `SkillPane.setData` 就是
## `cells[i].setCellValue(param1[i])`（SkillPane.as:206-230），
## 所以每个树节点上必须是**它自己那个技能**，而不是"把学过的技能从头跑一遍"。
## 原先的实现就是后者——结果每个节点上的图标都不是它该有的那个。
##
## 职业忍术页 = Passive1..6 + **该职业的 3 个普攻** + ProbDefence1..3 + ProbAttack1..3（共 15）。
## 实测参照：选中第 1 格显示「体能强化」= 0001000；第 2 列 3 格是 200 组的水遁三连
## （号主是 200 职业，见 `数据/界面/忍术树_真机实测.json`）。
func _skills_for_tab(tab_index: int) -> Array[Dictionary]:
	var 分页 := _取技能分页()
	var 页签名 := String(忍术页签名[tab_index]) if tab_index >= 0 and tab_index < 忍术页签名.size() else ""
	var 页签数据: Variant = (分页.get("页签", {}) as Dictionary).get(页签名, {})
	var 序清单: Array = (页签数据 as Dictionary).get("技能序", []) if typeof(页签数据) == TYPE_DICTIONARY else []
	var 职业 := str(int(_session.player_stats.get("job", 0)))
	var 职业普攻: Array = (分页.get("职业普攻", {}) as Dictionary).get(职业, [])
	var ids: Array = []
	# 「技能序」= AS3 `getSkillIdsForJob` 的原序（下标与树格子一一对应）。
	# 别改成按「列」摊平：奥义禁术/其他忍术两页的列序与数据序不一致（见 技能分页.json 的 _为什么改成扁平技能序）。
	for 项 in 序清单:
		if 项 == null:
			continue
		# 原版 getSkillIdsForJob 的 case 0 把该职业 3 个普攻排在 Passive1..6 之后
		if String(项) == 职业普攻占位:
			ids += 职业普攻
		else:
			ids.append(项)

	var 学过的 := {}
	for skill in _session.learned_skills:
		学过的[String(skill.get("id", ""))] = skill

	var result: Array[Dictionary] = []
	for 项 in ids:
		if 项 == null:
			continue
		var 技能id := String(项)
		if 学过的.has(技能id):
			# `added_level` = 勾玉/玉链 + 世界/职业技能加成（原版 `getAddedSkillLevel`）。
			# ⚠️ `_skill_with_icon` 在已有图标时**原样返回会话里那一条**，直接写会改到存档数据 ⇒ 先拷一份。
			var 条目: Dictionary = _skill_with_icon(学过的[技能id]).duplicate(true)
			条目["added_level"] = _session.added_skill_level(技能id)
			result.append(条目)
			continue
		# 没学过：拿静态表的名字与图标，等级记 0（原版这些格子也是灰的、显示 0）
		var 记录: Dictionary = GAME_DATA.skill(技能id)
		if 记录.is_empty():
			continue
		var 条目 := 记录.duplicate(true)
		条目["level"] = 0
		条目["max_level"] = maxi(1, int(记录.get("max_level", 10)))
		条目["icon"] = GAME_DATA.skill_icon_path(记录)
		条目["learned"] = false
		result.append(条目)
	return result

func _find_skill(skill_id: String) -> Dictionary:
	for skill in _session.learned_skills:
		if String(skill.get("id", "")) == skill_id:
			return _skill_with_icon(skill)
	return {}

## 会话里的技能记录只带 id/等级/熟练度，**不带图标**；而忍术窗口的格子与详情都直接读
## `icon` 字段，不补就是整片空白（"一个个图标都没有对应"）。
## 图标来自 数据/技能.json 的 icon_class，经 技能素材索引 解析成 PNG 路径。
## 少数技能本身没有 icon_class（已在 数据/技能素材缺失.json 登记），补不出来就保持空白，
## 不造假图标。
func _skill_with_icon(skill: Dictionary) -> Dictionary:
	if not String(skill.get("icon", "")).is_empty():
		return skill
	var entry: Dictionary = skill.duplicate(true)
	entry["icon"] = String(GAME_DATA.skill(skill.get("id", "")).get("icon", ""))
	return entry

func _bind_original_check(item: Control, label_text: String, key: String, default_value: bool, inverted: bool, settings: Dictionary) -> void:
	var stored_value := bool(settings.get(key, default_value))
	var checked := not stored_value if inverted else stored_value
	(item.get_node("标记") as CanvasItem).visible = checked
	var label := item.get_node("文本") as Label
	label.text = label_text
	var click_area := item.get_node("点击区域") as Button
	click_area.tooltip_text = label_text
	click_area.pressed.connect(func(): _set_check(not stored_value, key))

func _inventory_item_by_id(item_id: String) -> Dictionary:
	for item in _session.inventory:
		if String(item.get("id", "")) == item_id:
			return item
	return {}

func _pet_by_id(pet_id: String) -> Dictionary:
	for pet in _session.pets:
		if String(pet.get("id", "")) == pet_id:
			return pet
	return {}

func _quest_by_id(quest_id: String, quests: Array) -> Dictionary:
	for quest in quests:
		if String(quest.get("id", "")) == quest_id:
			return quest
	return {}

func _render_shortcut_settings(parent: Control) -> void:
	_configure_label(parent.get_node("左标题") as Label, 12, Color("#ffd080"))
	_configure_label(parent.get_node("右标题") as Label, 12, Color("#ffd080"))
	_configure_label(parent.get_node("说明") as Label, 10, Color("#bca98f"))
	var rows := [["向左移动", "向左移动", "ui_left"], ["向右移动", "向右移动", "ui_right"], ["跳跃", "跳跃", "jump"], ["向上攀爬", "向上攀爬", "ui_up"], ["向下攀爬", "向下攀爬", "ui_down"], ["普通攻击", "普通攻击", "basic_attack"], ["NPC交互", "NPC 交互", "interact"]]
	for row in rows:
		_bind_shortcut_row(parent.get_node(String(row[0])) as Control, String(row[1]), String(row[2]))
	_bind_static_shortcut_row(parent.get_node("快捷忍术") as Control, "快捷忍术", "1 - 0")
	_bind_static_shortcut_row(parent.get_node("关闭窗口") as Control, "关闭窗口", "Esc")
	_bind_static_shortcut_row(parent.get_node("聊天记录") as Control, "聊天记录", "↑ / ↓")

func _bind_shortcut_row(row: Control, label_text: String, action_name: String) -> void:
	var label := row.get_node("名称") as Label
	label.text = label_text
	var button_text := "按下按键..." if _shortcut_waiting_action == action_name else _shortcut_text(action_name)
	var key_button := row.get_node("按键") as Button
	key_button.text = button_text
	key_button.tooltip_text = "%s快捷键" % label_text
	_configure_standard_button(key_button)
	key_button.pressed.connect(_start_shortcut_capture.bind(action_name))

func _bind_static_shortcut_row(row: Control, label_text: String, shortcut_text: String) -> void:
	var label := row.get_node("名称") as Label
	label.text = label_text
	var key_button := row.get_node("按键") as Button
	key_button.text = shortcut_text
	key_button.tooltip_text = "%s快捷键" % label_text
	_configure_standard_button(key_button)
	key_button.disabled = true

## 只读：把某个动作当前绑的键渲染成文字（最多两个）。
func _shortcut_text(action_name: String) -> String:
	var names: Array[String] = []
	for input_event in InputMap.action_get_events(action_name):
		if not input_event is InputEventKey:
			continue
		var key_event := input_event as InputEventKey
		var keycode := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		var key_name := OS.get_keycode_string(keycode)
		if not key_name.is_empty() and not names.has(key_name):
			names.append(key_name)
		if names.size() == 2:
			break
	return " / ".join(names) if not names.is_empty() else "未设置"

func _start_shortcut_capture(action_name: String) -> void:
	_shortcut_waiting_action = action_name
	_render_page()

func _set_shortcut_key(action_name: String, source_event: InputEventKey) -> void:
	var keycode := source_event.physical_keycode if source_event.physical_keycode != 0 else source_event.keycode
	快捷键.应用单个(action_name, keycode)
	_shortcut_waiting_action = ""
	_session.update_setting("keybind_%s" % action_name, int(keycode))

func _render_more_settings(parent: Control, settings: Dictionary) -> void:
	var more := parent.get_node("更多设置") as Control
	more.visible = true
	var music_panel := more.get_node("音乐面板") as Panel
	music_panel.add_theme_stylebox_override("panel", _sub_panel_style())
	_configure_label(music_panel.get_node("标题") as Label, 12, Color("#fff0a0"))
	var music_mute := music_panel.get_node("静音") as CheckBox
	music_mute.button_pressed = bool(settings.get("mute_music", false))
	music_mute.toggled.connect(_set_check.bind("mute_music"))
	var music_label := music_panel.get_node("音量文字") as Label
	music_label.text = "音乐音量  %d%%" % int(float(settings.get("music_volume", 0.7)) * 100.0)
	_configure_label(music_label, 12, Color.WHITE)
	var music_slider := music_panel.get_node("音量") as HSlider
	music_slider.value = float(settings.get("music_volume", 0.7))
	music_slider.value_changed.connect(func(value: float): music_label.text = "音乐音量  %d%%" % int(value * 100.0); _set_slider(value, "music_volume"))

	var sound_panel := more.get_node("音效面板") as Panel
	sound_panel.add_theme_stylebox_override("panel", _sub_panel_style())
	_configure_label(sound_panel.get_node("标题") as Label, 12, Color("#fff0a0"))
	var sound_mute := sound_panel.get_node("静音") as CheckBox
	sound_mute.button_pressed = bool(settings.get("mute_sound", false))
	sound_mute.toggled.connect(_set_check.bind("mute_sound"))
	var sound_label := sound_panel.get_node("音量文字") as Label
	sound_label.text = "音效音量  %d%%" % int(float(settings.get("sound_volume", 0.8)) * 100.0)
	_configure_label(sound_label, 12, Color.WHITE)
	var sound_slider := sound_panel.get_node("音量") as HSlider
	sound_slider.value = float(settings.get("sound_volume", 0.8))
	sound_slider.value_changed.connect(func(value: float): sound_label.text = "音效音量  %d%%" % int(value * 100.0); _set_slider(value, "sound_volume"))
	var fullscreen := more.get_node("全屏显示") as CheckBox
	fullscreen.button_pressed = bool(settings.get("fullscreen", false))
	fullscreen.toggled.connect(_set_check.bind("fullscreen"))
	var pickup := more.get_node("自动拾取") as CheckBox
	pickup.button_pressed = bool(settings.get("auto_pickup", true))
	pickup.toggled.connect(_set_check.bind("auto_pickup"))
	_configure_label(more.get_node("连接标题") as Label, 12, Color("#ffd080"))
	var host := more.get_node("主机") as LineEdit
	host.text = String(settings.get("backend_host", "127.0.0.1"))
	var port := more.get_node("端口") as SpinBox
	port.value = int(settings.get("backend_port", 18684))
	var account := more.get_node("账号") as LineEdit
	account.text = String(settings.get("backend_account", "a33047518511@gmail.com"))
	var password := more.get_node("密码") as LineEdit
	password.text = String(settings.get("backend_password", "123456"))
	var web_url := more.get_node("网页地址") as LineEdit
	web_url.text = String(settings.get("backend_url", "http://127.0.0.1:18680/ruffle.html"))
	for input in [host, account, password, web_url]:
		_configure_value_input(input)
	var sync := more.get_node("同步") as Button
	_configure_standard_button(sync)
	sync.tooltip_text = "保存连接参数并从原服务端同步角色数据"
	sync.pressed.connect(_save_backend_settings.bind(host, port, account, password, web_url))
	var connection_status := more.get_node("连接状态") as Label
	connection_status.text = _status.text
	_configure_label(connection_status, 12, Color("#bca98f"))

func _舞台尺寸() -> Vector2:
	return get_viewport().get_visible_rect().size


## 真实舞台尺寸。
##
## ⚠️⚠️ **不是**固定的 960x560 —— 原版 `Config.STAGE_WIDTH/HEIGHT` 由
## `Game.as:76-93` 的 `onResizeHandler` 按**真实窗口尺寸**重算（钳到 600~2000 / 400~1200），
## 原版 UI 就是按那个尺寸居中/贴边的。我们这个客户端没有拉伸（见 `project.godot`
## 那段注释：给 stretch 设 mode 会把位图放大变糊），所以**视口尺寸就是舞台尺寸**。
## 写死 960x560 的后果：居中/贴边的弹窗跑到左上角那一片去（用户 2026-09-27 报的
## "购买窗位置不对"就是这个）。凡是要"相对舞台居中/贴边/夹取"的地方都调它。


func _refresh_current() -> void:
	if _overlay == null or not _overlay.visible or _refresh_queued:
		return
	if _刷新环任务页():
		return
	_refresh_queued = true
	call_deferred("_flush_refresh")

## 修炼族（八门/手里剑/写轮眼/结印/柔拳/寄坏/轮回）回帧：
## **能原地刷就原地刷**，不能才整页重绘（2026-10-20 报修 2.1 的修法）。
## 原版每一族的管理器只 update 自己那一块面板（`JingMaiSource.onAnQi_updateZhuFu`
## 直接 `windowMap[...].updateXingYunValue(值)`），弹窗/页面都留着；而整页重绘会把
## 玩家正操作的「突破瓶颈 / 开始提升」弹窗 free 掉（`手里剑页._exit_tree` 连搬到屏幕
## 弹窗层的那枚也一起收）⇒ 突破失败回的幸运值永远看不到涨、弹窗一闪就没。
func _on_cultivation_changed(族: String, _状态: Dictionary) -> void:
	if _overlay == null or not _overlay.visible or _refresh_queued:
		return
	var 页名 := _固定页 if not _固定页.is_empty() else _current_page
	if 页名 == "人物" and 人物窗口.原地刷新族页(self, 族):
		return
	_refresh_current()

## 属性/库存那一类回帧（扣钱、扣精华、扣升阶道具、购买、修理……）停在**修炼族子页**时同样只原地刷。
## 用户 2026-10-22 报修 3「手里剑突破瓶颈失败，突破瓶颈的界面不应该消失」：失败那一发在结果帧**之前**
## 先扣了钱/精华/道具（`2.2.3/tools/fake_flash_server.py:52639-52679`：`_consume_inventory_quantity`
## + `money`/`zq` 都扣，随后 `_send_stats` 和逐格库存帧）⇒ 这两个信号把 `_refresh_current` 叫醒
## ⇒ 整页重绘 ⇒ `_content` 重建、`手里剑页._exit_tree` 连搬到「屏幕弹窗层」的突破弹窗一起 `queue_free`。
## 原版：`ThroughShouLiJianWindow.as:97` 订的是 `EventManager.ITEM_DATAS_CHANGED` ⇒ 库存来了只走
## `itemDataChangedHandler`（`:181`）**就地**换材料数，窗不动；结果帧 `toPoResult()`（`:360-370`）
## 成功只 `clearLayerTimeOut`、失败只在勾了「失败继续」时排一发 900ms 重试 —— **两支都不关窗**。
## ⚠ 守的是**信号口**，不是 `_refresh_current` 本体：切页/换页签那类真的要重建的路径照旧重建，
##   重建时收僵尸弹窗那条（§3.211 的 D 腿）还得成立。
func _on_资源帧() -> void:
	if _overlay == null or not _overlay.visible or _refresh_queued:
		return
	var 页名 := _固定页 if not _固定页.is_empty() else _current_page
	if 页名 == "人物" and 人物窗口.原地刷新族页(self, 人物窗口.当前子页名(self)):
		return
	_refresh_current()

## 阅历帧（1572）到达 ⇒ 原版 `YiZhiStudyWindow.updateYueLiAndYuanBao:221-225` 是就地改
## `_yuanBaoLabel` / `_jinBiLabel` 两个 Label 文字，不重建窗口；照抄。
## ⚠️ 走重渲染会成环：重建学习页 ⇒ `渲染学习` 再发 `请求阅历状态()` ⇒ 服务端再回 1572。
func _on_阅历_变化(点数: int) -> void:
	if _current_page == "意志学习":
		意志窗口.刷阅历(self, 点数)

func _flush_refresh() -> void:
	_refresh_queued = false
	if _overlay == null or not _overlay.visible:
		return
	## ⚠ 标了「自刷」的页**不许整页重建**（用户 2026-10-19 实机报「挂机页面所有内容我无法点击」的根因）。
	## `_render_page()` 开头把 `_content` 的 children 全部 `remove_child + queue_free`，而
	## `BaseButton` 的 `pressed` 要**按下与抬起落在同一个节点**才发 ⇒ 联网时 39/40/1808 那些状态帧
	## 每秒几十发、每一发都排一次重绘，手一按下去节点就被拆了，抬起落到重建出来的新节点 ⇒ 整页不响应。
	## 离线量具一次就点中，正因为离线没有这些帧（`开发工具/量挂机页命中.gd` 修前实测：
	## 按下→灌一帧→抬起 ⇒ `pressed` 0 次、那个件已释放）。这类页自己连会话信号原地刷值。
	var 页: Node = null
	if _content != null and _content.get_child_count() > 0:
		页 = _content.get_child(0)
	if 页 != null and bool(页.get_meta("page_self_refresh", false)):
		return
	## 物品菜单开着时**不许重建**：菜单是页根的子节点（人物/背包/仓库都这样），
	## `_render_page()` 会把它连同「已按下」一起 free 掉、重建出来的新菜单是收起的
	## ⇒ 点「卸下」落空（2026-11-01 用户报「装备点卸下无效」；探针实测：开菜单后灌一帧库存
	## ⇒ 旧菜单已 free、新菜单 visible=false、点原卸下位置武器仍在身上）。
	## 推迟到菜单收起（`收起()` / 选项 `pressed` 都会置 visible=false 发 `visibility_changed`）。
	if 页 != null:
		var 菜单 := 页.get_node_or_null("物品菜单") as Control
		if 菜单 != null and 菜单.visible:
			if not _refresh_waiting_menu:
				_refresh_waiting_menu = true
				菜单.visibility_changed.connect(_on_物品菜单收起, CONNECT_ONE_SHOT)
			return
	_refresh_waiting_menu = false
	# 2026-11-04 用户报「洗附加数值显示有点卡顿、不够丝滑」：每扣一次材料都会来一帧库存，
	# 这里原本整页重建（页签/右栏/面板全拆再装回），画面闪一下，刚摊开的对照也被拆掉。
	# 洗练页真正会变的只有材料数/灰度/消耗行和对照本身 ⇒ 原地刷，不重建。
	if _页名() == "装备强化" and _原地刷新洗数值页():
		return
	_render_page()


func _on_物品菜单收起() -> void:
	_refresh_waiting_menu = false
	_refresh_current()

func _on_backend_status(next_status: String, next_detail: String) -> void:
	if _backend == null or not bool(_backend.in_game):
		_停日环自动()
		_环任务请求.clear()
		_环任务应答表 = null
		_停打造自动()
		_打造请求.clear()
		_打造应答计时 = null
		_洗属性待旧值.clear()
		_refresh_current()
	if _status != null:
		_status.text = "后端：%s" % next_status
		_status.tooltip_text = next_detail

func _on_reward_state_received(_state: Dictionary) -> void:
	_refresh_current()

## ⚠️ 这里原来有一个 `_on_dim_input`（点遮罩就 `close()` 这扇窗）—— **已删，别再写回来**：
##    它是**零调用点**的死函数，而且**行为与原版相反**。原版 `PopUpMananger.showWindow:74-113`
##    建遮罩后，那句话只挂一条 `MOUSE_UP → onMaskView:146-153`，而 `onMaskView` 干的是
##    **取消正在拖的东西**（`DragManager.removeDragDataProxy`），**不关窗**；
##    `MDialog.addCloseListener:376` 也只挂在 okBtn/cancelBtn 上。
##    ⇒ 原版**没有"点窗外关窗"**这条交互。谁要是把这条死代码接上，就是**自造行为**（§3.116）。

func _on_title_input(event: InputEvent) -> void:
	if _固定页 == "尾兽预览":
		# 原版 `RongHunYuLanWindow` 构造第一句 `this.mouseEnabled = false`（`:23`）⇒ **整扇不吃鼠标**，
		# 只有 `closeBtn` 还活着（`mouseChildren` 没关）。它是融魂页的挂件，位置由 `_摆尾兽预览`
		# 钉死 ⇒ 单独拖走反而会把锚点弄丢。
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_drag_offset = event.global_position - _window.global_position
	elif event is InputEventMouseMotion and _dragging:
		var 旧 := _window.global_position
		# 落点收整：原版 `DragManager` 给的 stage 鼠标坐标本来就是整像素，而这里
		# `event.global_position` 是浮点 ⇒ 拖完停在半像素上，同一扇窗又会发虚（1.1 同根）。
		_window.global_position = (event.global_position - _drag_offset).round()
		if _固定页 == "宠物":
			_拖动驯养窗跟随(_window.global_position - 旧)
		elif _固定页 == "通灵驯养":
			# 驯养窗自己也能拖 ⇒ 挂在它右缘外侧的预览要一起跟（原版是它的孙子，天然跟手）。
			_拖动尾兽预览跟随(_window.global_position - 旧)

func _allocate_attribute(attribute: String) -> void:
	_session.allocate_attribute(attribute)

func _unequip(位置: int) -> void:
	_session.unequip_item(位置)

func _select_inventory_item(item_id: String) -> void:
	_selected_inventory_id = item_id
	_render_page()

func _select_pet(pet_id: String) -> void:
	_selected_pet_id = pet_id
	_render_page()

## 卸下宠物装备（原版 SimpleItemCell.clickFun=petTakeOffEquip：点了有装备的格才发）。
func _take_off_pet_equipment(pet_id: String, equipment_slot: int) -> void:
	_session.take_off_pet_item(pet_id, equipment_slot)

## 改名（原版 MDialog.showInputDialog + maxChars 12 + `__conChangeName` 空名拦截）。
func _rename_pet_request(当前名: String) -> void:
	var pet := _pet_by_id(_selected_pet_id)
	if pet.is_empty():
		return
	# 原版 `onOpenStudyWindow:654-659` + `__conChangeName:741-755`（真值 §8 #12 / §9）：
	# 输入弹 = 302 版 `MDialog`，预填当前名、全选、抢焦点、`maxChars = 12`。
	# 空名提示：原版那条 `PETWINDOW_CHANGE_NAME_OPERATION_PROMPT_1` 是「该通灵兽已经出战！」
	# （上游复制粘贴错的串），**决定不照抄**，保留「名字不能为空」（已登记在真值 §8 #12）。
	var 回调 := func(新名: Variant) -> void:
		if 新名 == null:
			return
		var 文本 := String(新名).strip_edges()
		if 文本.is_empty():
			_session.notification_requested.emit("名字不能为空")
			return
		_session.rename_pet(String(pet.get("id", "")), 文本)
	输入确认弹.弹出(_overlay, "请输入通灵兽的新名字", 当前名, false, 回调, 12)

func _set_quest_tab(tab_index: int) -> void:
	_quest_tab = tab_index
	_selected_quest_id = ""
	_render_page(true)

func _select_quest(quest_id: String) -> void:
	_selected_quest_id = quest_id
	_render_page()

func _set_team_tab(tab_index: int) -> void:
	_team_tab = tab_index
	_render_page(true)

func _set_friend_tab(tab_index: int) -> void:
	_friend_tab = tab_index
	_render_page(true)

## `CashShopWindow2.setSelectedTabBtn`（`:115-161`）＋ `requestData(0,19)`（`:159`）：
## 换页签 = 换分类 + **回到第 1 页**再取货。
## ⚠️ 「荣誉类」页签在原版里只切 `RongYuPanel` 显隐、**不发商品请求**（`:129-138`），
##    所以这里交给渲染端判（见 `社交窗口._render_shop`），不做特判。
func _set_shop_tab(tab_index: int) -> void:
	_shop_tab = tab_index
	_shop_page = 1
	# 原版 `CashShopWindow2.as:429-437 __onTabClick` 第一句就是 **`isSearch = false`**：
	# 切页签发的是**按类目**的 `432`（`dispatchCashShopEvent`），只有 `__search`（`:362-373`）才把
	# `isSearch` 置 true 走 `433`。本工程用"`_shop_query` 空不空"当 `isSearch`（见
	# `游戏会话.request_cash_shop` 的分支），所以这里必须清掉它 —— 不清的话搜过一次之后再点页签，
	# 发出去的还是上次那个关键词，玩家看到的就是一本"页签切不动"。
	# ⚠️ **不清**框里的字：原版 `keywordsText.text` 原样留着（`isSearch` 只是"这一跳发不发搜索"）。
	_shop_query = ""
	if _session != null and not _是商城荣誉页(tab_index):
		_session.request_cash_shop(_shop_tab, _shop_query, false, 0)
	_render_page(true)


## `CashShopWindow2.as:129-138` —— 「荣誉类」页签只切 `RongYuPanel` 显隐、**直接 return**，
## 不发 432 商品请求。别让这一刻也发出去（服务端那边分类 8 是空的，但口径上就不该发）。
func _是商城荣誉页(tab_index: int) -> bool:
	var 分页表 := _取商城分页表()
	var 页签们: Array = 分页表.get("页签", []) as Array
	if tab_index < 0 or tab_index >= 页签们.size():
		return false
	return String(页签们[tab_index]) == String(分页表.get("荣誉页签名", "荣誉类"))


## `CashShopWindow2.__search`（`:362-373`）：非空才搜，空的话只提示 `CASH_SHOP_INPUT_KEYWORDS`；
## 搜之前还会 `setSelectedTabBtn(tabs[0])` —— **把页签切回第一个**。
func _search_shop(query: String) -> void:
	_shop_query = query.strip_edges()
	if _shop_query.is_empty():
		_show_hint("请输入道具名称")
		return
	_shop_tab = 0
	_shop_page = 1
	if _session != null:
		_session.request_cash_shop(_shop_tab, _shop_query, false, 0)
	_render_page()


## 翻页（`PageComponent.__onArrowBtnClick` → `dispathPageEvent` → `CashShopWindow2.__setPage`，`:254-257`）。
## `indexBegin = (页-1) * 20`、`indexEnd = min(indexBegin + 20, 总数)`（`PageComponent.as:104-113`）。
func _set_shop_page(page: int) -> void:
	_shop_page = maxi(1, page)
	if _session == null:
		_render_page(true)
		return
	var 起 := (_shop_page - 1) * 20
	var 总数 := maxi(0, int(_session.cash_shop_total))
	_session.request_cash_shop(_shop_tab, _shop_query, false, 起, mini(起 + 20, 总数))
	_render_page(true)

func _set_skill_tab(tab_index: int) -> void:
	_skill_tab = tab_index
	_selected_skill_id = ""
	_render_page(true)

func _set_character_main_tab(tab_index: int) -> void:
	_character_main_tab = tab_index
	_character_sub_tab = 0
	_render_page(true)
	_进页后拉数据()

func _set_character_sub_tab(tab_index: int) -> void:
	_character_sub_tab = tab_index
	_render_page(true)
	_进页后拉数据()


## **进页时**按页名补一次数据请求。
##
## ⚠️⚠️ 只能在"切页"这一跳发，**不能放进渲染里**：`功能窗口._refresh_current` 挂在
##    `会话.cultivation_changed` 上，而渲染里发包 ⇒ 回帧触发渲染 ⇒ 又发包，
##    **无限循环**（表现：提示刷屏 ＋ 整页点不动；2026-10-17 用户实测）。
##
## 八门那一发既是**页面数据的刷新点**，也是**倒计时结束后的引爆点** ——
## 服务端 `handle_mai` 进来会先把到点的开通结算掉（见那边行尾注释），再把结果帧/统计帧推回来。
func _进页后拉数据() -> void:
	if _current_page != "人物" or _backend == null or not bool(_backend.in_game):
		return
	if 人物窗口.当前子页名(self) == "八门":
		_backend.request_bamen(1)

func _select_skill(skill_id: String) -> void:
	_selected_skill_id = skill_id
	_render_page()

func _set_settings_tab(tab_index: int) -> void:
	_settings_tab = tab_index
	_render_page(true)

## 点左侧榜单（原版 `__selectRank:262-266` → `selecteRankMenu:230-254`，末尾那句
## `__onRenJieBtnClick(null)` ⇒ `changeTab(0)`）⇒ **换榜一定退回「忍界榜」那一页**。
## 页序不用手动归 0：原版靠回帧时 `setData` 里那句 `reset()` 归的，这里同一口径
## （见 `_on_ranking_state`）。
func _set_榜单(编号: int) -> void:
	_ranking_tab = 编号
	_排行页 = 0
	_请求排行榜()
	_refresh_current()


## 点「忍界榜 / 同级榜」（原版 `changeTab(p)`：改 selected/enabled + 换规则文案 + 重新请求）。
func _set_排行页(页: int) -> void:
	_排行页 = 页
	_请求排行榜()
	_refresh_current()


func _请求排行榜() -> void:
	if _backend != null and bool(_backend.in_game):
		_backend.request_ranking(_ranking_tab, _排行页 == 0)


## 排行榜回帧：除了刷新，还要**把页序归 0** —— 原版 `setData:366` 那句
## `_pageComponent.reset(len, 10)` 无条件把 `currentPage` 打回 1，
## 不管这次切的是榜还是页。**只在"当前榜"时归零是我们这份的口径**（见下面注释），
## 因为这里按 menuId 分格存帧，别的榜的回帧不该动玩家正在看的那页。
func _on_ranking_state(state: Dictionary) -> void:
	if int(state.get("tab", -1)) == _ranking_tab:
		_排行码 = 0
	_refresh_current()

func _set_prize_tab(tab_index: int) -> void:
	_prize_tab = tab_index
	if _backend != null and bool(_backend.in_game):
		_backend.request_gift_state()
		_backend.request_czhuodong_bootstrap()
		_backend.request_activity_state()
	_render_page(true)

func _set_activity_overview_tab(tab_index: int) -> void:
	_activity_overview_tab = tab_index
	_render_page(true)

func _set_info_tab(tab_index: int) -> void:
	_info_tab = tab_index
	if _backend != null and bool(_backend.in_game) and _info_tab == 2:
		_backend.request_achievements(1)
	_render_page(true)

func _select_strengthen_slot(位置: int) -> void:
	_停打造自动()
	# 按**身上穿的部位**放入（原版 `dropItemHandler` 选中穿着那件时的形态）。
	_selected_strengthen_slot = 位置
	_强化放入中 = true
	_强化放入来源 = ""
	_强化放入格 = 0
	_强化放入id = ""
	# 换了一件 ⇒ 上一件没保存的洗数值预览作废。
	_洗数值预览.clear()
	_清洗属性快照()
	_render_page()

## 「放入装备 / 取出装备」那只按钮（各页的 `dropBtn` 都接这儿）。
## 原版 `clickDropBtnHandler`（`EquipStrengthWindow.as:485-499`）：
##   · 已是"取出装备"态（放了东西）⇒ 点一下 = `backItemToEquip()`：**清空**，回到"放入"态；
##   · "放入装备"态 ⇒ 点一下 = 挂 `UpShelfCursor`，让用户去点包裹里的一件。
## 本工程没有跟手光标件 ⇒ 用户授权的等价通道（同 `勾玉炼制窗`）：在游标处弹一张清单，
## 点一条 = 原版"点背包那一格"（2026-11-08 §3.385）。清单列**身上 + 背包**里所有装备
## （`_部位列表物品` 那套 `put_on` 标记照带），选到过不了门槛的那件照样由
## `_放入页签校验` 弹原版原话 —— 和原版"光标挂在手上、点错件给 MDialog"同效。
func _点打造放入钮(页: Control) -> void:
	if _强化放入中:
		_清放入()
		_render_page()
		return
	var 清单 := _打造放入候选()
	if 清单.is_empty():
		_show_hint("背包里没有可放入的装备")
		return
	_打造选择器 = 放入选择器.弹(页, 清单,
			func(行: Dictionary) -> void:
				if _应用选中部位(行.get("物品", {}) as Dictionary):
					_render_page())


## 放入清单：先身上、后背包（次序同 `_部位列表物品`），只收"装备位认得出"的件
## （材料/消耗品不进单；灵器/忍具/徽章/玉链这类认得出位置但过不了门槛的**进单**，
##  选中后由 `_放入页签校验` 弹原版那句，而不是让玩家在一张空清单里找不到自己的东西）。
var _打造选择器: PopupMenu = null


func _打造放入候选() -> Array:
	var 出: Array = []
	for 位置 in _session.equipped_items:
		var 物品: Variant = _session.equipped_items[位置]
		if typeof(物品) != TYPE_DICTIONARY or (物品 as Dictionary).is_empty():
			continue
		var 穿着件: Dictionary = (物品 as Dictionary).duplicate(true)
		if not 装备部位.是装备(String(穿着件.get("id", ""))):
			continue
		穿着件["put_on"] = true
		出.append(_打造候选行(穿着件, 0))
	for 物品 in _session.inventory:
		if typeof(物品) != TYPE_DICTIONARY or (物品 as Dictionary).is_empty():
			continue
		var 背包件: Dictionary = (物品 as Dictionary).duplicate(true)
		if not 装备部位.是装备(String(背包件.get("id", ""))):
			continue
		背包件["put_on"] = false
		出.append(_打造候选行(背包件, int(背包件.get("slot_index", 0))))
	return 出


## 一行清单 = `放入选择器` 的通用形状 + `物品`（收料要拿整件实例）。
func _打造候选行(件: Dictionary, 格: int) -> Dictionary:
	var 物品id := String(件.get("id", ""))
	return {"格": 格, "id": 物品id,
		"名称": String(GAME_DATA.item(物品id).get("name", 物品id)),
		"数量": int(件.get("quantity", 1)), "物品": 件}


## 背包里的装备候选 —— 修复 / 梦幻属性符 / 橙装 三扇窗的「放入」钮共用
## （它们只认背包：原版落点 `validateItem` 的 `position > 0` 口径）。
## 和前一条同理不过滤"过不了门槛"的件，拒收那几句留给各页 `收料` 说。
func _背包装备候选() -> Array:
	var 出: Array = []
	for 物品 in _session.inventory:
		if typeof(物品) != TYPE_DICTIONARY or (物品 as Dictionary).is_empty():
			continue
		var 件: Dictionary = (物品 as Dictionary).duplicate(true)
		if not 装备部位.是装备(String(件.get("id", ""))):
			continue
		件["put_on"] = false
		出.append(_打造候选行(件, int(件.get("slot_index", 0))))
	return 出


## 打造各页装备格的**拖放落点**（原版 `ItemDropBox.itemCell.dropItemFun = dropItemHandler`）：
## 运行期 `set_script`（场景是生成物、不许手改 .tscn；先例 修复/梦幻/橙装 三页）。
## 判据全在页面 `_放入页签校验` —— 组件只负责把来源背包格号交出来。
func _挂打造落点(格: Control) -> void:
	if 格 == null:
		return
	if 格.get_script() != 梦幻放入格组件:
		格.set_script(梦幻放入格组件)
		格.mouse_filter = Control.MOUSE_FILTER_STOP
	for 连接 in 格.请求放入.get_connections():
		格.请求放入.disconnect(连接["callable"])
	格.请求放入.connect(_打造放入格)


## 从背包拖进装备格。原版这时走 `validateItem`（各页门槛）—— 这里同一条 `_应用选中部位`。
func _打造放入格(背包格: int) -> void:
	var 条: Dictionary = _session._占用条(_session.inventory, 背包格)
	if 条.is_empty():
		return
	var 件: Dictionary = 条.duplicate(true)
	件["put_on"] = false
	if _应用选中部位(件):
		_render_page()

## 清空放入态（原版 `backItemToEquip`）。游标 `_selected_strengthen_slot` 留着当轮换起点。
func _清放入() -> void:
	_停打造自动()
	_清洗属性快照()
	_强化放入中 = false
	_强化放入来源 = ""
	_强化放入格 = 0
	_强化放入id = ""

## 原版**放进左栏那一刻**按当前页签校验的门槛 —— 七页各有一段真值：
##   · 共用尾（强化/天生，`EquipStrengthWindow.validateItem:506-564`）：
##     不是打造装备 / 时装 / 玉链 / 徽章 / **破损**（所有页都有这一条，进阶除外）；
##     天生页再加 `reqLevel < EQUIP_PROP_LIMIT_LEVEL(=60, EquipManager.as:38)`
##     ⇒ `%1级以上的装备才能进行该操作`（`:545-553`，语言表 :1949）。
##   · 洗附加属性（`EquipPropResetPanel.validateItem:373-411`）：类型/时装/玉链/徽章/破损。
##   · 洗附加数值（`EquipPropLianZhiPanel.validateItem:400-448`）：再加白色
##     （`EQUIPLIANZHIWINDOW_WHITE_EQIP_NOT_WASH`，:1937）与 60 级（:429-433）。
##   · 刻印（`EquipKeYinPanel.validateItem:128-171`）：再加白色
##     （`EQUIPLIANZHIWINDOW_WHITE_EQIP_NOT_KE_YIN`，:2963）。
##   · 精炼（`EquipBaiLianPanel.validateItem:446-489`）：紫/橙 且强化 ≥10
##     （`EQUIPBAILIAN_CAB_NOT_DAZAO`，:2993）。
##   · 进阶（`EquipConvertWindow.validateItem:220-253`）：只认角色装备、**必须已卸到背包**
##     （`position <= 0` 是在身上的）；换职业 id 无效/目标件不存在各有各的话。**没有破损闸**。
## ⚠️ 洗附加属性/洗附加数值/刻印/精炼四页的第一句是 `isItemADaZaoZhuangBei`（类型 1/2），
##    所以玉链(12)/徽章(14)在这四页弹的是通用「该物品不能被打造」；只有强化/天生走
##    `param1 is EqpData` 那支，才到得了「玉链不可以进行打造」。
## ⚠️ 原版用 MDialog 弹窗；本实现先用**状态行**放同样的原文（弹层没接，登记欠账）——
##    关键是**拒了就不放进**，别再出现"低等级件点了没反应/照样能打造"。
const 数值天生等级限 := 60


## 这一件的需求等级：在线帧里是 `req_level`（`后端连接._item_display_fields:2906`），
## 离线示例/商店件没有 ⇒ 回 `数据/物品装备元数据.json` 的 `required_level`。
func _装备需求等级(物品: Dictionary) -> int:
	for 键 in ["req_level", "required_level"]:
		if 物品.has(键):
			return int(物品.get(键, 0))
	return int(_装备元(String(物品.get("id", ""))).get("required_level", 0))


## 按当前页签校验"这件能不能放"。可以 ⇒ 返回 ""；不行 ⇒ 返回原版那句提示（并拒放）。
func _放入页签校验(物品: Dictionary) -> String:
	var 页名: String = 打造页签[clampi(_strengthen_tab, 0, 打造页签.size() - 1)]
	var 物品id := String(物品.get("id", ""))
	var 补零 := 物品id.pad_zeros(8) if 物品id.is_valid_int() else 物品id
	var 类型号 := int(补零.substr(0, 2)) if 补零.length() >= 2 else 0
	var 四位 := int(补零.substr(0, 4)) if 补零.length() >= 4 else 0
	var 是时装 := 类型号 == 1 and 补零.substr(2, 2) == "21"     # `ItemType.isItemAShiZhuang`
	var 是玉链 := 四位 == 120                                    # `ItemFactory.isItemAYuLian`
	var 是徽章 := 四位 == 141                                    # `ItemFactory.isItemAHuiZhang`
	var 破损 := int(物品.get("crash_time", 0)) > 0
	var 资质 := int(物品.get("aptitude", 1))

	if 页名 == "进阶":
		# `EquipConvertWindow.validateItem:220-253`（进阶页**不**走共用那套，也没有破损闸）
		if 类型号 != 1 or 是时装 or 是玉链 or 是徽章:
			return "只能放入角色装备进行转换"
		if bool(物品.get("put_on", _item_is_worn(物品))):
			return "请先将装备卸下到背包再操作"
		var 转 := _进阶目标id(物品id)
		if 转 <= 0:
			return "该装备无法转换为当前职业对应装备"
		if GAME_DATA.item(str(转)).is_empty():
			return "目标装备不存在，无法转换！"
		return ""

	# 四张专属面板的第一句 = `isItemADaZaoZhuangBei`（类型 1/2）；不满足只弹通用那句。
	if 页名 in ["洗附加属性", "洗附加数值", "刻印", "精炼"]:
		if 类型号 != 1 and 类型号 != 2:
			return "对不起，该物品不能被打造"                    # `EQUIP_STRENGTH_FAIL_PROMPT_1`
	else:
		# 强化/天生走共用尾：`param1 is EqpData` ⇒ 打造装备、玉链、徽章都进得来。
		if 类型号 != 1 and 类型号 != 2 and not 是玉链 and not 是徽章:
			return "对不起，该物品不能被打造"
	if 是时装:
		return "对不起，变身卡不可以进行打造！"                  # `FAIL_PROMPT_7[0]` 填 `[1]`
	if 是玉链:
		return "对不起，玉链不可以进行打造！"                    # `FAIL_PROMPT_7[0]` 填 `[2]`
	if 是徽章:
		return "该物品无法进行此操作。"                          # `HUIZHANG_STRENGTH_FAIL_PROMPT`
	if 破损:
		return "对不起，该装备已经破损！"                        # `FAIL_PROMPT_10[0]` 填 `[2]`
	if 页名 == "洗附加数值":
		if 资质 == 1:
			return "很抱歉，白色属性的装备，无法重置附加属性条目的数值"
		if _装备需求等级(物品) < 数值天生等级限:
			return "%d级以上的装备才能进行该操作" % 数值天生等级限
	elif 页名 == "刻印":
		if 资质 == 1:
			return "很抱歉，白色属性的装备，无法刻印秘印属性"
	elif 页名 == "精炼":
		if 资质 not in [4, 5] or int(物品.get("strengthen", 0)) < 10:
			return "精炼台只能精炼紫色品质强化等级10星以上的装备"
	elif 页名 == "天生":
		if _装备需求等级(物品) < 数值天生等级限:
			return "%d级以上的装备才能进行该操作" % 数值天生等级限
	return ""


## 进阶页的目标 id（`EquipConvertWindow.getConvertedItemId:264-277`）：
## 末位是职业组（job/100 ∈ 1..4），同组/0 尾 = 转不了，返回 0。
func _进阶目标id(物品id: String) -> int:
	var 组 := int(int(_session.player_stats.get("job", 0)) / 100)
	if 组 < 1 or 组 > 4:
		return 0
	if not 物品id.is_valid_int():
		return 0
	var 数 := int(物品id)
	var 尾 := 数 % 10
	if 尾 == 0 or 尾 == 组:
		return 0
	return int(数 / 10) * 10 + 组


## 把候选列表里的一件放进左栏（只改状态，不重建页面——调用方自己决定何时刷）。
## 返回 false = 认不出装备位，或被**当前页签的门槛**拒了（提示已落在状态行）。
func _应用选中部位(物品: Dictionary) -> bool:
	var 位置 := 装备部位.位置(String(物品.get("id", "")))
	if 位置 == 0:
		return false
	var 拒 := _放入页签校验(物品)
	if not 拒.is_empty():
		_show_hint(拒)
		return false
	_停打造自动()
	_强化放入中 = true
	# 换了一件 ⇒ 上一件没保存的洗数值预览作废。
	_洗数值预览.clear()
	_清洗属性快照()
	if bool(物品.get("put_on", _item_is_worn(物品))):
		_强化放入来源 = ""
		_强化放入格 = 0
		_强化放入id = ""
		_selected_strengthen_slot = 位置
	else:
		_强化放入来源 = "背包"
		_强化放入格 = int(物品.get("slot_index", 0))
		_强化放入id = String(物品.get("id", ""))
	return true

func _set_npc_shop_tab(tab_index: int) -> void:
	_npc_shop_tab = tab_index
	_render_page(true)

## `ShopWindow2.onClickBuyBtn`（`:437-454`）/ `onClickSaleBtn`（`:631-650`）—— 这两个按钮
## **切的是光标**（`ShopBuyCursorF` / `ShopSaleCursorF`），不是切货架数据。
## 再点一次已选中的那个 = 把光标收掉（`hideBuyCursor`/`hideSaleCursor`），
## 所以这里用 `-1` 表示"都不选"，与 `_npc_shop_mode` 的 0/1 区分开。
func _set_npc_shop_mode(mode: int) -> void:
	_npc_shop_mode = mode
	商店出售模式 = mode == 1
	if 商店出售模式:
		_show_hint("出售：点背包里的物品选数量")
	else:
		_show_hint("购买：点商品格选数量")
	_render_page()

## `ShopWindow2.onClickMendBtn:153-156` → `UIMain2.showMendEtcWindow()`：「修理」弹的是
## **装备修理窗**，不是一条直接发出去的协议。
##
## ⚠️ 巡检 #19 逮到的三连错（旧代码全中）：
##   1. 不发窗、点一下就走 ⇒ 玩家看不到"这次要花多少钱"，也没有普通/特殊两档可选；
##   2. 发的是 `NPC_SHOP` 子命令 **2**（`PacketCreator.as:576 getNPCShopRechargeItemRequestPacket`
##      = 商品**补货**，`UI.as:2241 onShopRechargeItems`）—— 协议映射错到另一条业务上；
##   3. 只挑**第一件**受损装备发过去，而原版 `requestRepairEquip` 一个格位都不带：
##      `ITEM_CHANGE 7 + writeInt(修理方式)`，服务端拿它一次修**身上全部**装备。
func _repair_equipment() -> void:
	if _overlay == null:
		return
	var 价 := _修理价目()
	var 窗 := _overlay.get_node_or_null("修理窗") as Control
	if 窗 == null:
		窗 = 修理窗场景.instantiate() as Control
		窗.name = "修理窗"
		_overlay.add_child(窗)
	_前置购买窗遮罩(窗)
	if not 窗.确认修理.is_connected(_成交修理):
		窗.确认修理.connect(_成交修理)
	if not 窗.提示不需要修理.is_connected(_修理无需提示):
		窗.提示不需要修理.connect(_修理无需提示)
	if not 窗.关闭了.is_connected(_一键出售窗关了):
		窗.关闭了.connect(_一键出售窗关了)
	窗.call("打开", int(价[0]), int(价[1]))


## `MendEtcWindow.setData():65-84` 的那两栏合计：对**身上每一件**装备累加
## `(maxEndure - endure) × getEtcXiuliPrice(stage)[0|1]`，`[0]=normalPrice`、`[1]=specialPrice`。
## ⚠️ 清单口径要和服务端**同一份**：`_repair_all_equipped` 扫的是 `-199 <= slot < 0` 的角色装备，
##    正是镜像 `equipped_items`（2051 `EQUIPPED_INFO` 那份）⇒ 满耐久的不进账、
##    `max_endure < 0` 的（玉链/徽章那类）乘出来是 0、也不进账。
func _修理价目() -> Array:
	var 普通 := 0
	var 特殊 := 0
	for 位置 in _session.equipped_items:
		var 物品: Variant = _session.equipped_items[位置]
		if typeof(物品) != TYPE_DICTIONARY:
			continue
		var 件 := 物品 as Dictionary
		if 件.is_empty():
			continue
		var 上限 := int(件.get("max_endure", -1))
		var 当前 := int(件.get("endure", 上限))
		if 上限 < 0 or 当前 >= 上限:
			continue
		var 阶 := maxi(1, int(_装备元(String(件.get("id", ""))).get("stage", 1)))
		var 缺口 := 上限 - 当前
		普通 += 缺口 * 装备打造表.取修理价(阶, false)
		特殊 += 缺口 * 装备打造表.取修理价(阶, true)
	return [普通, 特殊]


## `onClickXiuliBtn:44-63` 的闸门：那一档合计为 0 ⇒ 只 `addNotice(CN.BUXUYAO_XIULI)`，
## **不发帧、也不关窗**（窗只在真发出去之后才 `onCloseBtnClick`）。
func _修理无需提示() -> void:
	_show_hint("不需要修理")


## 组件只报意图（同 `一键出售窗`），协议在这一层：那一个 int 原样交给 `后端连接`。
func _成交修理(类型: int) -> void:
	if _backend != null and bool(_backend.in_game):
		# 发成功**不提示**（同 `请求商城商品`/`发送修炼请求`：结果由回帧把画面刷出来）。
		if not bool(_backend.request_repair_equip(类型)):
			_show_hint("修理请求发送失败")
		return
	_show_hint("修理需要先连上服务端")

## 商店页「一键出售」⇒ 弹 `QuickSaleWindow`（**不是**点一下就发）。
## 原版那条链：`ShopWindow2.as:569-572 onQuickSaleBtn` → `UIMain2.as:2401-2407 showQuickSaleWindow()`
## → `PopUpMananger.centerWindow(new QuickSaleWindow(), true)`。
##
## ⚠️ §3.42 当年把它"折成一条直接发出去的协议"，发的是 `1, 30, 0` —— 而
##   `PacketCreator.getNPCShopOnekeySellRequestPacket:102-111` 是 **4 个 writeInt**
##   （等级、星、品质、目标位图），夹具把第 3 个当**品质上限** ⇒ 0 ⇒ 每次必回 SHOP_ERROR，
##   而且扩容后的格子根本不在"1..30"这个区间里（巡检 #18）。
func _quick_sell_items() -> void:
	if _overlay == null:
		return
	var 窗 := _overlay.get_node_or_null("一键出售窗") as Control
	if 窗 == null:
		窗 = 一键出售窗场景.instantiate() as Control
		窗.name = "一键出售窗"
		_overlay.add_child(窗)
	_前置购买窗遮罩(窗)
	if not 窗.确认出售.is_connected(_成交一键出售):
		窗.确认出售.connect(_成交一键出售)
	if not 窗.关闭了.is_connected(_一键出售窗关了):
		窗.关闭了.connect(_一键出售窗关了)
	窗.call("打开")


func _一键出售窗关了() -> void:
	var 遮罩 := _overlay.get_node_or_null(购买窗遮罩名) as Control
	if 遮罩 != null:
		遮罩.visible = false


## 组件只报意图（同 `商城购买窗`），协议在这一层：四个 int 原样交给 `后端连接`。
func _成交一键出售(等级: int, 星级: int, 品质: int, 目标: int) -> void:
	if _backend != null and bool(_backend.in_game):
		# 发成功**不提示**：卖成功的画面证据是格子空掉 + 钱变多（回帧），不是回执一句话。
		if not bool(_backend.request_npc_shop_one_key_sell(等级, 星级, 品质, 目标)):
			_show_hint("一键出售请求发送失败")
		return
	_show_hint("一键出售需要先连上服务端")

func _on_shop_transaction(code: int) -> void:
	_show_hint(String({
		0: "购买成功", 1: "补货成功", 3: "背包已满", 4: "目标格已满",
		5: "金币不足", 8: "出售成功", 32: "商店交易失败",
	}.get(code, "商店返回状态 %d" % code)))

## `全部` = 菜单「全部使用」（原版 `ItemWindow2.useAll`，见 `游戏会话.use_inventory_slot`）。
## ⚠️ 收的是**格位**不是 id —— 同 `#16` 那条：同 id 两摞时按 id 反查会吃第一摞。
##
## ⚠️ 自选礼包（`libao_select`）**在这儿被截走**，一包都不发（巡检 #21）：
##   原版 `ItemWindow2.as:990-1017` 的礼包分支在真正发包之前 `return`，
##   弹 `ChoiceLibaoWindow` 等玩家选一件，「确定」才由选择窗发
##   `requestUseItem(position, id, {job, index})`。
##   **`useAll` 也一样被截**（`MENU_USEALL:767-768` 同样走 `useItem()` 那一支，
##   而 `ChoiceLibaoWindow.__onOkBtnClick` 调的是不带 useAll 的三参 `requestUseItem`）
##   ⇒ 对着一摞 5 件「全部使用」，原版也只吃**选中的那一件**一次。别"顺手"改成循环。
func _use_item(格位: int, 全部 := false) -> void:
	# ⚠️ **第一位**：原版 `ItemWindow2.as:957-964` 的福袋支排在两个礼包支（`:990-1017`）之前，
	#   并且当场 `return` ⇒ 福袋**从不发 USE_ITEM**，件是服务端在 `1286:1` 的处理里扣的。
	#   放在礼包之后会串味：15008001 在 `数据/物品.json` 里 `use_type` 是空的、不是礼包，
	#   于是掉进 `use_inventory_slot` ⇒ 在线发一条服务端不认的 USE_ITEM、离线只回一句提示（#74）。
	if _session.是福袋类(格位):
		_开福袋(格位)
		return
	# ⚠️ 「梦幻属性符」**在这儿截走、一件不发**（2026-11-03 用户报「不能直接使用」）：
	#   原版 `ItemWindow2.as:953-967` 的梦幻支排在福袋**之后**、礼包/千里符**之前**，
	#   并且当场 `return` ⇒ 双击只开窗、不发 `USE_ITEM`（服务端也不认这件）。
	#   以前掉进 `use_inventory_slot`：在线发一条没人处理的 USE_ITEM、离线回
	#   「是材料或任务物品，不能直接使用」（用户看到的就是这句）。
	var 梦幻id := 装备打造表.梦幻属性符id()
	if 梦幻id > 0 and _session != null:
		var 梦幻条: Dictionary = _session._占用条(_session.inventory, 格位)
		if not 梦幻条.is_empty() and int(str(梦幻条.get("id", "0"))) == 梦幻id:
			_开梦幻属性符窗(格位)
			return
	# 「传说装备打造石 / 传说精炼石」同样**当场截走**：原版 `ItemWindow2.as:979-988` 的
	# `isItemCanDaZao` / `isItemCanJingLian` 两支各自 `showYellowEquipLianZhiWindow(0/1)`
	# 后 `return`，不发 `USE_ITEM`（服务端也不认这两件）。id 走 `EquipSystem` 那两段的 `needItemId`。
	if _session != null:
		var 橙装条: Dictionary = _session._占用条(_session.inventory, 格位)
		if not 橙装条.is_empty():
			var 这件id := int(str(橙装条.get("id", "0")))
			if 这件id > 0 and 这件id == 装备打造表.橙装打造石id():
				_开橙装打造窗(0)
				return
			if 这件id > 0 and 这件id == 装备打造表.橙装精炼石id():
				_开橙装打造窗(1)
				return
	if _session.是自选礼包(格位):
		_开自选礼包窗(格位)
		return
	# `ItemWindow2.as:990-1017` 的第二支：`preview == 1` 且 type 是 libao/libao_fufei
	# ⇒ 先弹 `SelectGiftWindow` 详情窗，**不直接发包**。两种礼包在窗里按
	# `spec.type` 分 12 格（金币/点券成本）与 16 格（顶部元宝支付）两套版式。
	if _session.是详情礼包(格位):
		_开礼包详情窗(格位)
		return
	# `ItemWindow2.as:1056-1060`：`isItemTeShuWuPin && isPreviewLibaoTypeWuxing`
	# （= 特殊物品的 `spec.type == "jineng"`，本事就是「神奇技能符」）⇒
	# `API.petHandler.onResetPetSkill(itemData)` 弹 `PetSkillResetWindow`，当场 return。
	# 以前掉进 `use_inventory_slot`：在线发一条服务端会按 jineng 收下的 USE_ITEM、
	# 但报文缺 `{petUid,oldskill,newskill}` ⇒ 服务端回「请选择要操作的宠物。」；
	# 离线则被 `_使用前置拒` 之外的分支当成普通物品拒掉。**整条使用链以前根本不存在**。
	if _session.是技能符(格位):
		_开宠物技能替换窗(格位)
		return
	_session.use_inventory_slot(格位, 全部)


## 打开（或复用）选择窗 —— 摆法同 `_quick_sell_items`：挂 `_overlay`、压遮罩、接两个信号。
func _开自选礼包窗(格位: int) -> void:
	if _overlay == null:
		return
	var 条: Dictionary = _session.格位物品(格位)
	if 条.is_empty():
		return
	var 窗 := _overlay.get_node_or_null("自选礼包窗") as Control
	if 窗 == null:
		窗 = 自选礼包窗脚本.new() as Control
		窗.name = "自选礼包窗"
		_overlay.add_child(窗)
	_前置购买窗遮罩(窗)
	if not 窗.确认选择.is_connected(_成交自选礼包):
		窗.确认选择.connect(_成交自选礼包)
	if not 窗.关闭了.is_connected(_自选礼包窗关了):
		窗.关闭了.connect(_自选礼包窗关了)
	_自选礼包格位 = 格位
	窗.call("打开", String(条.get("id", "")), self)


## 关闭 / 取消 ⇒ 只收遮罩（窗自己已经 `visible = false`）。
func _自选礼包窗关了() -> void:
	_自选礼包格位 = -1
	var 遮罩 := _overlay.get_node_or_null(购买窗遮罩名) as Control
	if 遮罩 != null:
		遮罩.visible = false


## 选择窗「确定」⇒ 这一条路才真的发 USE_ITEM。
##
## 原版 `__onOkBtnClick:283-293` 的两步，顺序**不许调**：
##   ① 先验背包空位 `1 + commonItems.length <= commonSlots`，满了只回
##      `CN.ITEM_GRID_NOT_SPACE`（「背包空间不足！」）且**窗不关、包不发**；
##   ② 过了才 `requestUseItem(位置, id, {job, index})` 并关窗。
## 服务端 `:49713-49715`（`_use_authored_gift_item` 里那道 `_has_inventory_capacity`）
## 同样回一句「背包空间不足，无法打开礼包。」并**不扣件**，
## 客户端这道是原版的、不是多余的：它决定"窗留不留"。
func _成交自选礼包(职业组: int, 序号: int) -> void:
	if _自选礼包格位 < 1:
		return
	var 窗 := _overlay.get_node_or_null("自选礼包窗") as Control
	if _session._占用数(_session.inventory) + 1 > 背包窗口._背包总格数(_session):
		_show_hint("背包空间不足！")
		return
	if _session.use_inventory_slot(_自选礼包格位, false, {"job": 职业组, "index": 序号}) and 窗 != null:
		窗.call("隐藏")


## —— 「火影有礼」详情窗（`SelectGiftWindow`）——
## 挂 `_overlay`、压同一张遮罩、接两个信号 —— 摆法与 `_开自选礼包窗` 逐字同源。
func _开礼包详情窗(格位: int) -> void:
	if _overlay == null:
		return
	var 条: Dictionary = _session.格位物品(格位)
	if 条.is_empty():
		return
	var 窗 := _overlay.get_node_or_null("礼包详情窗") as Control
	if 窗 == null:
		窗 = 礼包详情窗脚本.new() as Control
		窗.name = "礼包详情窗"
		_overlay.add_child(窗)
	_前置购买窗遮罩(窗)
	if not 窗.确认开启.is_connected(_成交礼包详情):
		窗.确认开启.connect(_成交礼包详情)
	if not 窗.关闭了.is_connected(_礼包详情窗关了):
		窗.关闭了.connect(_礼包详情窗关了)
	_礼包详情格位 = 格位
	窗.call("打开", String(条.get("id", "")), self)


func _礼包详情窗关了() -> void:
	_礼包详情格位 = -1
	var 遮罩 := _overlay.get_node_or_null(购买窗遮罩名) as Control
	if 遮罩 != null:
		遮罩.visible = false


## 详情窗「打开礼包」⇒ 这里才真的发 USE_ITEM。
##
## 原版 `onClickOpenBtn:251-266` 的背包空位闸 `itemsCount + commonItems.length <= commonSlots`
## 用的是**当前职业看到的行数**（不是 contents 的全部候选），按窗格上限截断：
## 12 格（libao）/ 16 格（libao_fufei）。满了只回 `CN.ITEM_GRID_NOT_SPACE`，
## **窗不关、包不发**；过了才 requestUseItem，服务端再按自己的容量闸复核。
func _成交礼包详情() -> void:
	if _礼包详情格位 < 1:
		return
	var 窗 := _overlay.get_node_or_null("礼包详情窗") as Control
	var 条: Dictionary = _session.格位物品(_礼包详情格位)
	var 号 := String(条.get("id", ""))
	var 详情 := GAME_DATA.礼包详情(号)
	var 格上限 := 16 if String(详情.get("type", "")).to_lower() == "libao_fufei" else 12
	var 行数 := mini(GAME_DATA.礼包详情物品(号, int(_session.player_stats.get("job", 0))).size(), 格上限)
	if _session._占用数(_session.inventory) + 行数 > 背包窗口._背包总格数(_session):
		_show_hint("背包空间不足！")
		return
	if _session.use_inventory_slot(_礼包详情格位) and 窗 != null:
		窗.call("隐藏")


## —— 宠物技能重置窗（`PetSkillResetWindow.as`，444×423）——
## 挂 `_overlay`、压同一张遮罩、接两枚信号 —— 摆法与 `_开礼包详情窗` 同源。
func _开宠物技能替换窗(格位: int) -> void:
	if _overlay == null:
		return
	if _session.格位物品(格位).is_empty():
		return
	var 窗 := _overlay.get_node_or_null("宠物技能替换窗") as Control
	if 窗 == null:
		窗 = 宠物技能替换窗脚本.new() as Control
		窗.name = "宠物技能替换窗"
		_overlay.add_child(窗)
	_前置购买窗遮罩(窗)
	if not 窗.确认替换.is_connected(_成交宠物技能替换):
		窗.确认替换.connect(_成交宠物技能替换)
	if not 窗.关闭了.is_connected(_宠物技能替换窗关了):
		窗.关闭了.connect(_宠物技能替换窗关了)
	_技能符格位 = 格位
	窗.call("打开", self)


func _宠物技能替换窗关了() -> void:
	_技能符格位 = -1
	var 遮罩 := _overlay.get_node_or_null(购买窗遮罩名) as Control
	if 遮罩 != null:
		遮罩.visible = false


## 窗里「确定重置」⇒ 把 `{petUid, oldskill, newskill}` 交给协议层。
## 窗**不自己关**（原版 `resetSkill:69-94` 发完包也没有关窗）：成功与否看服务端回帧，
## 技能列表由 `pets_changed` 就地刷新；符被扣掉后那一格空了，再点确定就是普通失败。
func _成交宠物技能替换(宠物uid: int, 旧技能: int, 新技能: int) -> void:
	if _技能符格位 < 1:
		return
	_session.use_pet_skill_symbol(_技能符格位, 宠物uid, 旧技能, 新技能)


## —— 成就福袋（`SuccessWindow`，#74）——
## 双击福袋**只发请求、不开窗**：原版 `UI.onFudai:1898-1901` 整个函数体就一句
## `Client.requestFudaiOpen(param1.position)`；窗要等 `1289:1` 到了才由
## `Client.onShowFudaiInfo:6597-6606` 开（`if(!content.successWindow) reverseDisplay(SUCCESS_WINDOW_F)`）。
## ⚠️ 这条链**一次 USE_ITEM 都不发**：扣件是服务端在 action 1 的处理里做的
## （`fake_flash_server.py:31903` `_consume_bag_slot`），编号必须在**发包前**存进 `_福袋物品id`
## —— 回帧到达时那一格已经空了，标题与「还抽不抽下一只」都没处取。
func _开福袋(格位: int) -> void:
	var 条: Dictionary = _session.格位物品(格位)
	if 条.is_empty():
		return
	var 号 := String(条.get("id", ""))
	if _backend != null and bool(_backend.in_game):
		_福袋物品id = 号
		if not bool(_backend.request_fudai_open(格位)):
			_show_hint("成就福袋请求发送失败")
		return
	# 离线：落在哪一格是服务端 `randrange(len(candidates))` 掷的，本地掷骺就是自造 ⇒
	# 与 `zidong` 灵药那支同一句诚实提示（`游戏会话:838`），**不扣件、不开窗**。
	_session.notification_requested.emit("「%s」的效果要在服务端结算（离线不模拟）"
		% String(GAME_DATA.item(号).get("name", 号)))


## `fudai_state_received` 的唯一消费者。**不进** `_on_reward_state_received` 那条通用列表：
## 那条只做"记状态 + 刷红点"，这里要开一扇窗 ⇒ 与 `ranking_state_received` 同法单接一条。
## 两支帧按 `action` 分流，形状见 `后端连接._parse_fudai_state_frame` / `_parse_fudai_index_frame`。
func _收到福袋帧(状态: Dictionary) -> void:
	if _overlay == null:
		return
	var 动作 := int(状态.get("action", -1))
	var 窗 := _overlay.get_node_or_null("福袋窗") as Control
	# `queue_free` 到帧末才真摘掉 ⇒ 本帧里 `get_node_or_null` 还会拿到那枚已判死刑的旧窗。
	if 窗 != null and 窗.is_queued_for_deletion():
		窗 = null
	if 动作 == 1:
		# `onShowFudaiInfo:6597-6600`：`_windowMap` 里没有 ⇒ `reverseDisplay` 造一枚、
		# `default: setLocationCenter()` 摆到舞台正中、`addChildAt` 上台。
		# 已经在台上时这一句**不跑**（守卫看的是 map 里的实例，不是 parent）⇒ 不会把开着的窗 toggled 掉。
		var 新建 := false
		if 窗 == null:
			窗 = 福袋窗脚本.new() as Control
			窗.name = "福袋窗"
			_overlay.add_child(窗)
			窗.call("接线", self)
			if not 窗.请求开始.is_connected(_福袋发开始):
				窗.请求开始.connect(_福袋发开始)
			if not 窗.请求领取.is_connected(_福袋发领取):
				窗.请求领取.connect(_福袋发领取)
			新建 = true
		# 原版 `if(param2.itemid)` 之前先把 `param2` 喂进 `ItemFactory`（**先 new 再 decode**），
		# 所以 `gained` 在 AS3 侧恒非空；文本桥的 `-` ⇒ 空字典 ⇒ 这里原样传，窗按"有没有奖"分流。
		窗.call("设数据", int(状态.get("state", 0)), 状态.get("gained", {}) as Dictionary,
			状态.get("candidates", []) as Array, _福袋物品id)
		if 新建:
			窗.call("登台")
		return
	if 动作 == 2:
		# `Client.onShowFudaiGainItemInfo:4575-4581`：窗**不存在就什么都不做**（不替玩家开一扇空窗）。
		if 窗 == null:
			return
		窗.call("设落点", int(状态.get("state", 2)), int(状态.get("index", -1)))


## 「开始」= `FudaiProcessor.requestFudaiStart:146-151`（只有 action 字节，不带格位）。
func _福袋发开始() -> void:
	if _backend != null and bool(_backend.in_game) and not bool(_backend.request_fudai_start()):
		_show_hint("成就福袋请求发送失败")


## 「领奖」= `FudaiProcessor.requestFudaiGain:123-128`。发奖与扣件由服务端回通用物品/背包帧，
## 下一只的状态跟着 `1289:1` 一起到 ⇒ 这里不解包。
func _福袋发领取() -> void:
	if _backend != null and bool(_backend.in_game) and not bool(_backend.request_fudai_gain()):
		_show_hint("成就福袋请求发送失败")

## ⚠️ 2026-10-01 修一处必踩的元数不匹配：`背包窗口` 的销毁确认用 `(id, 件数)` 两参调这里，
## 而旧签名只有一参 ⇒ GDScript 运行时 Invalid call、销毁点了等于没点、**件数还被吞**。
func _discard_item(item_id: String, quantity := -1) -> void:
	_session.discard_item(item_id, quantity)

func _upgrade_skill(skill_id: String) -> void:
	_session.upgrade_skill(skill_id)

func _bind_skill(slot: int, skill_id: String) -> void:
	_session.bind_skill_to_slot(skill_id, slot)

## 出战/回收（原版 `PetWindow.petAttckHandler:158-179`）。
##
## 三态语义（真值 §8 #4）：NORMAL → `requestAttackOut`；ATTACK → `requestAttackBack`；
## **SUMMON（附身中）⇒ 只 notice「该通灵兽已经附身！」、一个包都不发**。
## 再加 `isLevelEnough` 两道等级闸与 1000ms `isDelay`。
func _toggle_pet(pet_id: String, deployed: bool) -> void:
	var 宠 := _pet_by_id(pet_id)
	if 宠.is_empty():
		return
	if bool(宠.get("attached", false)):
		_通知("该通灵兽已经附身！")
		return
	if not _宠物等级够(宠, "出战"):
		return
	if not _宠物按钮节流("出战"):
		return
	_session.set_pet_deployed(pet_id, deployed)


## 附身/回收（原版 `PetWindow.petFuShenHandler:542-563`）。
##
## 三态语义（真值 §8 #3）：NORMAL → 1500ms 读条后 `requestCallOutPet`；SUMMON → `requestCallBackPet`；
## **ATTACK（出战中）⇒ 只 notice「该通灵兽已经出战！」、不发包**。
func _attach_pet(pet_id: String) -> void:
	var 宠 := _pet_by_id(pet_id)
	if 宠.is_empty():
		return
	if bool(宠.get("deployed", false)):
		_通知("该通灵兽已经出战！")
		return
	if not _宠物等级够(宠, "携带"):
		return
	if not _宠物按钮节流("附身"):
		return
	if bool(宠.get("attached", false)):
		_session.set_pet_attached(pet_id, false)		# 回收 = call_back，不需要读条
		return
	_附身读条(pet_id)


## 附身读条：原版 `showFuShenPetProgress` —— 一条「正在附身...」（`PET_FUSHEN_NAME`）的横条，
## 1500ms 后发 `requestCallOutPet`。
##
## ⚠️ 那两张读条皮（`GeneralLoadingBg_Skin` / `GeneralLoading_Skin`）在原版的四个素材库里
## **都不存在**（真值 §11 已核实）⇒ 我们**不造条**，只还原「文案 + 1500ms 节奏 + 重入挡」。
## 读条期间玩家可能换宠/关窗/被附身 ⇒ 到点先复核一次再发包。
func _附身读条(pet_id: String) -> void:
	if _附身读条中:
		return
	_附身读条中 = true
	_通知("正在附身...")
	await get_tree().create_timer(1.5).timeout
	_附身读条中 = false
	if _session == null:
		return
	var 宠 := _pet_by_id(pet_id)
	if 宠.is_empty() or bool(宠.get("attached", false)) or bool(宠.get("deployed", false)):
		return
	_session.set_pet_attached(pet_id, true)


## 「刻印图解」帮助窗 —— 原版 `EquipKeYinHelpWindow.as`（全文 74 行；§3.132 记的那笔欠账，§3.135 收口）。
##
## 窗体**只有一张图**：`UISwfMovieClipAgent("UISwf_KeYinHelp_Background", true)`，
## 即 308×406 的纯位图（由 `开发工具/swf位图直解.py` 的 DefineBitsJPEG3 分支解出）；
## 外加**右上角一枚关闭钮**（`x = width - 钮宽 - 4, y = 4`）。`MWindow` 基类在这条路上
## 不画任何皮 —— `createChildren` 里 `graphics.drawRect(0,0,308,406)` 是 **alpha=0** 的命中区。
##
## ⚠️ 图里烘死的字是**繁体**（守鶴／貓又／鼠蛟／磯撫）。原版这份 SWF 就是繁体：
## `UISwfMovieClipAgent` 按元件名的**前两段**取件（`UISwf_KeYinHelp` → `swf/UISwf/UISwf_KeYinHelp.swf`）、
## **没有语言分支**，全库也只有这一份 ⇒ **照登**（"查到原版就是这样"也是一个结论，不许拿别的图填）。
##
## 开关照 `EquipKeYinPanel.helpHandler:287-300`：**同一枚钮再点一次就收起**（原版是
## "有父就 removeChild、没父就 addChild"，我们等价成切 `visible`）。
const 刻印图解窗名 := "刻印图解窗"

func _切换刻印图解(刻面板: Control) -> void:
	if 刻面板 == null:
		return
	var 窗 := 刻面板.get_node_or_null(刻印图解窗名) as Control
	if 窗 == null:
		窗 = _建刻印图解窗(刻面板)
		刻面板.add_child(窗)
		return
	窗.visible = not 窗.visible

func _建刻印图解窗(刻面板: Control) -> Control:
	var 窗 := Control.new()
	窗.name = 刻印图解窗名
	窗.mouse_filter = Control.MOUSE_FILTER_STOP
	窗.z_index = 50                      # 弹出层：压在面板与页签之上
	var 图 := TextureRect.new()
	图.name = "图解图"
	图.texture = load(ORIGINAL_KE_YIN_HELP) as Texture2D
	图.position = Vector2.ZERO
	if 图.texture != null:
		图.size = Vector2(图.texture.get_size())
	窗.add_child(图)
	窗.size = 图.size
	# 贴位：`EquipKeYinPanel.helpHandler:290-291` 的 `_helpWindow.x = _width; y = -58`。
	var 面板宽 := 刻面板.size.x if 刻面板.size.x > 0.0 else 350.0
	窗.position = Vector2(面板宽, -58.0)
	# 关闭钮：`EquipKeYinHelpWindow:44` 与 `:39` 的 `x = width - 钮宽 - 4, y = 4`。
	var 钮 := Button.new()
	钮.name = "关闭键"
	## 交互态（悬停 +30 / 按下 −40）走全工程那一份状态机；`set_script` 必须在**设 icon 之前**
	## （它在 `_ready()` 抄常态皮当主干，抄不到就整条静默不接）。原版这颗也是 `MWindowCloseBtnF`。
	钮.set_script(三态皮)
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND		# `MButton3.init()` `:135`
	钮.focus_mode = Control.FOCUS_NONE
	钮.tooltip_text = "关闭"
	# 只留图标、不要按钮皮 —— 走皮肤表的「原版无外观可点区」变体。
	# ⚠️ 别在这里 `add_theme_stylebox_override(…, StyleBoxEmpty.new())`：
	#    `UI资源回归测试` 有守卫，**代码里现造 StyleBox 会压过全局主题**（§3.135 撞过一次）。
	钮.theme_type_variation = WINDOW_SKIN.皮肤表.变体_透明按钮
	钮.icon = load(ORIGINAL_CLOSE) as Texture2D
	var 钮尺 := Vector2(钮.icon.get_size()) if 钮.icon != null else Vector2(25.0, 24.0)
	钮.size = 钮尺
	钮.position = Vector2(窗.size.x - 钮尺.x - 4.0, 4.0)
	钮.pressed.connect(func() -> void: 窗.visible = false)
	窗.add_child(钮)
	return 窗


## 「刻印图解」帮助窗 —— 原版 `EquipKeYinHelpWindow.as`（全文 74 行；§3.132 记的那笔欠账，§3.135 收口）。
##
## 窗体**只有一张图**：`UISwfMovieClipAgent("UISwf_KeYinHelp_Background", true)`，
## 即 308×406 的纯位图（由 `开发工具/swf位图直解.py` 的 DefineBitsJPEG3 分支解出）；
## 外加**右上角一枚关闭钮**（`x = width - 钮宽 - 4, y = 4`）。`MWindow` 基类在这条路上
## 不画任何皮 —— `createChildren` 里 `graphics.drawRect(0,0,308,406)` 是 **alpha=0** 的命中区。
##
## ⚠️ 图里烘死的字是**繁体**（守鶴／貓又／鼠蛟／磯撫）。原版这份 SWF 就是繁体：
## `UISwfMovieClipAgent` 按元件名的**前两段**取件（`UISwf_KeYinHelp` → `swf/UISwf/UISwf_KeYinHelp.swf`）、
## **没有语言分支**，全库也只有这一份 ⇒ **照登**（"查到原版就是这样"也是一个结论，不许拿别的图填）。
##
## 开关照 `EquipKeYinPanel.helpHandler:287-300`：**同一枚钮再点一次就收起**（原版是
## "有父就 removeChild、没父就 addChild"，我们等价成切 `visible`）。


## 树内确认框，替代 ConfirmationDialog。
##
## 原版 MDialog/MPromptWindow 是活在普通显示列表里的 MWindow 子类，不是 OS 窗口，
## 所以这里用 小窗口边框 的树内 Control，而不是 Godot 内嵌 Window ——
## 后者的主题面（embedded_border/title_font/title_height/close）与原版对不上。
## 几何取 MWindow 语义：标题 y=3（小背景）、居中用算术右移即 floorf。
func _弹出确认(标题: String, 正文: String, 确认文字: String, 确认回调: Callable) -> void:
	const 尺寸 := Vector2(300.0, 130.0)
	const 标题Y := 3.0            # MWindow._titleTextFieldY，小背景
	const 边框间隙 := 5.0          # UIConfig.BORDER_GAP
	const 内容间隙 := 8.0          # UIConfig.CONTENT_GAP
	const 按钮间隙 := 4.0          # UIConfig.BUTTON_GAP
	const 按钮尺寸 := Vector2(70.0, 22.0)   # UIConfig.btn_width_five

	var 遮罩层 := Control.new()
	遮罩层.name = "确认框"
	遮罩层.set_anchors_preset(Control.PRESET_FULL_RECT)
	遮罩层.mouse_filter = Control.MOUSE_FILTER_STOP
	遮罩层.z_index = 100

	var 暗层 := ColorRect.new()
	暗层.set_anchors_preset(Control.PRESET_FULL_RECT)
	暗层.color = Color(0.0, 0.0, 0.0, 0.3)		# 原版 `PopUpMananger.centerWindow` 默认 bgAlpha=0.3
	遮罩层.add_child(暗层)

	var 主体 := Control.new()
	主体.size = 尺寸
	# (STAGE - size) >> 1 是算术右移，负值向负无穷取整，必须 floorf
	主体.position = Vector2(
		floorf((_overlay.size.x - 尺寸.x) * 0.5),
		floorf((_overlay.size.y - 尺寸.y) * 0.5),
	)
	遮罩层.add_child(主体)

	var 边框 := Panel.new()
	边框.set_anchors_preset(Control.PRESET_FULL_RECT)
	边框.theme_type_variation = WINDOW_SKIN.皮肤表.变体_小窗口边框
	主体.add_child(边框)

	var 标题标签 := Label.new()
	标题标签.name = "标题"		# 起名是为了**门能寻址**（`_弹出确认` 的件都是运行期建的）
	标题标签.text = 标题
	标题标签.theme_type_variation = WINDOW_SKIN.皮肤表.变体_窗口标题
	标题标签.autowrap_mode = TextServer.AUTOWRAP_OFF
	主体.add_child(标题标签)
	标题标签.position = Vector2(floorf((尺寸.x - 标题标签.get_minimum_size().x) * 0.5), 标题Y)

	var 正文标签 := Label.new()
	正文标签.name = "正文"
	正文标签.text = 正文
	正文标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	正文标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	正文标签.position = Vector2(内容间隙 + 边框间隙, 34.0)
	正文标签.size = Vector2(尺寸.x - (内容间隙 + 边框间隙) * 2.0, 44.0)
	主体.add_child(正文标签)

	var 按钮行 := HBoxContainer.new()
	按钮行.add_theme_constant_override("separation", int(按钮间隙))
	按钮行.position = Vector2(
		floorf((尺寸.x - (按钮尺寸.x * 2.0 + 按钮间隙)) * 0.5),
		尺寸.y - 按钮尺寸.y - 18.0,
	)
	主体.add_child(按钮行)

	var 确认键 := Button.new()
	确认键.name = "确认键"
	确认键.text = 确认文字
	确认键.custom_minimum_size = 按钮尺寸
	按钮行.add_child(确认键)

	var 取消键 := Button.new()
	取消键.name = "取消键"
	取消键.text = "取消"
	取消键.custom_minimum_size = 按钮尺寸
	按钮行.add_child(取消键)

	确认键.pressed.connect(func() -> void:
		遮罩层.queue_free()
		确认回调.call()
	)
	取消键.pressed.connect(遮罩层.queue_free)
	# 点空白处取消，与原版点窗口外关闭一致
	暗层.gui_input.connect(func(事件: InputEvent) -> void:
		if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed:
			遮罩层.queue_free()
	)

	遮罩层.set_meta(输入确认弹.浮层标记, true)
	_overlay.add_child(遮罩层)
	确认键.grab_focus()

## 树内输入框，同 `_弹出确认` 的骨架。原版 `MDialog.showInputDialog`：
## `maxChars=12`（`PetWindow.as:658`）、全选现名、焦点在输入框。
func _弹出输入(标题: String, 默认值: String, 确认回调: Callable) -> void:
	const 尺寸 := Vector2(300.0, 150.0)
	var 遮罩层 := Control.new()
	遮罩层.name = "输入框"
	遮罩层.set_anchors_preset(Control.PRESET_FULL_RECT)
	遮罩层.mouse_filter = Control.MOUSE_FILTER_STOP
	遮罩层.z_index = 100
	var 暗层 := ColorRect.new()
	暗层.set_anchors_preset(Control.PRESET_FULL_RECT)
	暗层.color = Color(0.0, 0.0, 0.0, 0.3)		# 原版 `PopUpMananger.centerWindow` 默认 bgAlpha=0.3
	遮罩层.add_child(暗层)
	var 主体 := Control.new()
	主体.size = 尺寸
	主体.position = Vector2(floorf((_overlay.size.x - 尺寸.x) * 0.5), floorf((_overlay.size.y - 尺寸.y) * 0.5))
	遮罩层.add_child(主体)
	var 边框 := Panel.new()
	边框.set_anchors_preset(Control.PRESET_FULL_RECT)
	边框.theme_type_variation = WINDOW_SKIN.皮肤表.变体_小窗口边框
	主体.add_child(边框)
	var 标题标签 := Label.new()
	标题标签.text = 标题
	标题标签.theme_type_variation = WINDOW_SKIN.皮肤表.变体_窗口标题
	标题标签.autowrap_mode = TextServer.AUTOWRAP_OFF
	主体.add_child(标题标签)
	标题标签.position = Vector2(floorf((尺寸.x - 标题标签.get_minimum_size().x) * 0.5), 3.0)

	var 输入 := LineEdit.new()
	输入.text = 默认值
	输入.max_length = 12            # MDialog showInputDialog 的 maxChars
	输入.position = Vector2(20.0, 44.0)
	输入.size = Vector2(尺寸.x - 40.0, 24.0)
	主体.add_child(输入)

	var 按钮行 := HBoxContainer.new()
	按钮行.add_theme_constant_override("separation", 4)
	按钮行.position = Vector2(floorf((尺寸.x - (70.0 * 2.0 + 4.0)) * 0.5), 尺寸.y - 22.0 - 18.0)
	主体.add_child(按钮行)
	var 确认键 := Button.new()
	确认键.text = "确定"
	确认键.custom_minimum_size = Vector2(70.0, 22.0)
	按钮行.add_child(确认键)
	var 取消键 := Button.new()
	取消键.text = "取消"
	取消键.custom_minimum_size = Vector2(70.0, 22.0)
	按钮行.add_child(取消键)
	确认键.pressed.connect(func() -> void:
		var 文本 := 输入.text
		遮罩层.queue_free()
		确认回调.call(文本)
	)
	取消键.pressed.connect(遮罩层.queue_free)
	暗层.gui_input.connect(func(事件: InputEvent) -> void:
		if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed:
			遮罩层.queue_free()
	)
	遮罩层.set_meta(输入确认弹.浮层标记, true)
	_overlay.add_child(遮罩层)
	输入.grab_focus()
	输入.select_all()               # 原版 setSelection(0, len)

func _release_pet(pet_id: String) -> void:
	var pet := _pet_by_id(pet_id)
	if pet.is_empty():
		return
	# 原版 petFangShenHandler:389-398：**先拦装备**（穿了装备根本不出确认框）
	if not (pet.get("equipment", []) as Array).is_empty():
		_session.notification_requested.emit("很抱歉，穿著装备的通灵兽无法放生，请先卸下装备！")
		return
	# 原版 `PetWindow.petFangShenHandler:389-398` → `MDialog.showMessageDialog`
	# （真值 §8 #6 / §9）：正文 = `PROMPT_2`「你确定要放生该通灵兽吗?」，OK(=1) 才发包。
	# 上一版是自造的 300×130 确认框（标题「放生通灵兽」+「此操作无法撤销」），已删。
	输入确认弹.弹消息(_overlay, "你确定要放生该通灵兽吗?", func(结果: int) -> void:
		if 结果 == 1:
			_session.release_pet(pet_id))

func _accept_quest(quest_id: String) -> void:
	_session.accept_quest(quest_id)

func _claim_quest(quest_id: String) -> void:
	_session.claim_quest_reward(quest_id)

func _create_team() -> void:
	_session.create_team()

func _invite_team(player_name: String) -> void:
	_session.invite_team_member(player_name)

func _leave_team() -> void:
	_session.leave_team()

func _add_friend(player_name: String) -> void:
	_session.add_friend(player_name)

func _remove_friend(player_name: String) -> void:
	_session.remove_friend(player_name)

func _unblock_friend(player_name: String) -> void:
	_session.unblock_player(player_name)

func _start_whisper(player_name: String) -> void:
	close()
	_session.notification_requested.emit("请在聊天框输入 /%s 消息" % player_name)

func _create_guild(guild_name: String) -> void:
	if not _session.create_guild(guild_name):
		# 单机版创建门槛是 `flag["1"].cost` 的 16000022×1（**金币 0**）；
		# 原来这里写"需要 1000 金币"是自造的，已按真值改掉。
		_session.notification_requested.emit("家族名至少 2 个字，且需要族之书 1 本")

func _leave_guild() -> void:
	_session.leave_guild()

# ── 家族旗帜「说明窗二选一」+ 取数（原版 `FM.as:832-843` + `FamillyFlagHelpWindow.as`）──
#
# 用户 2026-10-07 第 3 条：**第一次**进家族旗帜要先出那张 642×426 的说明整图，
# 左下角「下次跳过本说明界面」勾上之后，下一次就直接进旗帜窗。

## 「下次跳过本说明界面」的落盘键。原版存在本地配置
## `CharacterConfig.banghuiAutoEnterFlagWindow`（`CharacterConfig.as:21` + `synch()`）；
## 我们这工程对应 `游戏会话.game_settings` → `user://玩家设置.json`（`update_setting` 落盘）。
## 键名用 ASCII：同一份 settings 里现成的键都是这个风格（`auto_combat` / `keybind_*`）。
const 跳过旗帜说明键 := "family_flag_help_skip"
const 复选皮未选 := "res://素材/界面/原版窗口/通用控件/复选框未选.png"
const 复选皮选中 := "res://素材/界面/原版窗口/通用控件/复选框选中.png"


## 家族页「家族旗帜」这个入口：按设置**二选一**开窗。
func _开家族旗帜视图() -> void:
	if _设过跳过旗帜说明():
		家族子窗壳.切换(self, "家族旗帜窗", "家族旗帜")
		_请求旗帜数据()
		return
	# 说明窗**没有窗壳**（原版 `FFH` 就是一张整图、自带关钮），所以第四个实参传 false。
	家族子窗壳.切换(self, "家族旗帜帮助窗", "家族旗帜帮助", false)
	_同步帮助窗复选()


func _设过跳过旗帜说明() -> bool:
	var 设 := _取设置表()
	return bool(设.get(跳过旗帜说明键, false))


func _取设置表() -> Dictionary:
	if _session == null:
		return {}
	var 值: Variant = _session.get("game_settings")
	return 值 as Dictionary if 值 is Dictionary else {}


func _本族id() -> int:
	if _session == null:
		return 0
	var 家: Variant = _session.get("guild")
	return int((家 as Dictionary).get("id", 0)) if 家 is Dictionary else 0


## 说明窗复选框的初始态 = 落盘值（原版 `FFH:50`：`_checkBox.selected = CharacterConfig...`）。
func _同步帮助窗复选() -> void:
	var 框 := _帮助窗复选框()
	if 框 == null:
		return
	框.texture = load(复选皮选中 if _设过跳过旗帜说明() else 复选皮未选) as Texture2D


## 说明窗里那个复选框的「框」贴图（窗没开 ⇒ null）。
func _帮助窗复选框() -> TextureRect:
	var 页 := 家族子窗壳.取内容(self, "家族旗帜帮助窗")
	if 页 == null:
		return null
	return 页.get_node_or_null("复选跳过/框") as TextureRect


## 落盘。⚠️ `家族子窗._翻复选` 是**先翻皮、再发动作**，所以这里读到的是"翻过之后"的状态；
## 判定也照它那一套走 —— 皮的 `resource_path` 才是当前态的唯一真值源。
func _存跳过旗帜说明() -> void:
	if _session == null:
		return
	var 框 := _帮助窗复选框()
	if 框 == null:
		return
	# ⚠️ 走 `update_setting`，它自己会 `_save_local_state()`；别绕开它直接写文件。
	_session.call("update_setting", 跳过旗帜说明键, String(框.texture.resource_path) == 复选皮选中)


## 开旗帜窗要的两条取数：本族旗帜信息 + **全服族旗表**（`1815:0`）。
## 「势力对比」要的是后者，跟家徽标识（`1552:103`）不是一回事 —— 原版开这一窗时发的
## 也正是它（`FM.as:592-593` 的 `requestQueryMapFlagList()`）。
func _请求旗帜数据() -> void:
	if _backend == null or not bool(_backend.in_game):
		return
	_backend.request_guild_flag(_本族id())
	_backend.request_flag_list()



## 好友页行菜单（原版 `FriendWindow2.onMenuHand:338-440`）。
## `动作` = 「<页签>:<项名>」（页签是 好友/最近/仇人/黑名单/师徒），`项` = 那一行的数据字典
## （`character_id/name/online/level/face/...`）。菜单本身只开确认弹，真正的协议全在这一处发。
## 老调用点（不带行数据，例如好友页底栏钮）会走 `_show_guild_action("好友页|…")` 那条路进来，
## 此时 `项` 为空 —— 只应该接得到开窗类动作，碰到要编号/名字的项就明说缺数据，不静默。
func _好友菜单动作(动作: String, 项: Dictionary) -> void:
	var 页 := 动作.get_slice(":", 0)
	var 项名 := 动作.get_slice(":", 1)
	var 号 := int(项.get("character_id", 0))
	var 名 := String(项.get("name", ""))
	# 老口径动作串没有行数据；不发 `127:x:0` 这种空包，也不静默吞点击
	if 项名 in ["查看", "看摊", "删除", "拉黑", "移除", "赠花", "交友", "交易"] and 号 <= 0:
		_通知("%s：找不到这名玩家的数据" % 项名)
		return
	if 项名 in ["密语", "组队"] and 名.is_empty():
		_通知("%s：找不到这名玩家的数据" % 项名)
		return
	match 项名:
		"查看":
			## `FW2:351-355`：离线先 `addNotice(CN.ON_LINE_PLAYER)`，**随后仍然** `clickCharacter(id)`。
			## 队伍面板那一支不同（`TroopHPPane.as:400-410`）：离线只提示、**不发 94**。
			if not bool(项.get("online", true)):
				_通知("该玩家不在线！")
				if 页 == "队伍":
					return
			_查看角色资料(号)
		"密语":
			## `FW2:361-366`：`ChatEvent(CHECK_ONLINE)` **不发包**，只把聊天框切到私聊频道、
			## 预填 `/名字 `（与头像面板/人物面板那几处同一个出口）。
			_开始好友私聊(名)
		"组队":
			## `FW2:368-372` → `TroopWindowEvent(INVITE)` → `UI.sureToTroopWindowInvite` →
			## `120:4:<名字>`（组队邀请取名字，不是编号）。
			_好友请求("request_party_invite", 名, "邀请组队")
		"看摊":
			## `FW2:428-432` → `API.ui.viewStall(id)` → `Client.requestStallOpen(id)`。
			_好友请求("request_stall_open", 号, "查看摊位")
		"交易":
			## 队伍面板第六项（`TroopHPPane.as:422-426`）：`TradeWindowEvent(TRADE_INVITE)` →
			## `requestTradeInvite(charId)` ⇒ `119:2:<编号>`；服务端成功时给对方 `119:3:<我号>:<我名>`。
			_好友请求("request_trade_invite", 号, "邀请交易")
		"删除":
			## 三页三档：好友 3（`requestDeleteFriend`）、最近 7（`requestDeleteRecent`）、
			## 仇人 9（`requestDeleteEnemy`）—— AS3 三个不同的 action，别全发 3。
			match 页:
				"好友": _好友请求("request_friend_delete", 号, "删除好友")
				"最近": _好友请求("request_friend_delete_recent", 号, "删除最近联系人")
				"仇人": _好友请求("request_friend_delete_enemy", 号, "删除仇人")
				_: _通知("%s：这个页签没有「删除」" % 动作)
		"拉黑":
			## `FW2:447-461` `__conBlackFriend` → `FriendChatManage.addMemberToBlackList(id)` → `127:4`。
			_好友请求("request_friend_block", 号, "拉黑")
		"移除":
			## `FW2:243-260` `deletePlayerFromHeiMingDan` → `127:6`（按编号）。
			_好友请求("request_friend_unblock", 号, "移出黑名单")
		"赠花":
			## `FW2:343-345` → `MarryTableManager.openMarryZengHuaWindow(id,name,face,level)`：
			## **先存"对面是谁"四项、再发 `94:6`，窗开在回帧那一刻**（同头像面板那条路）。
			_好友赠花(项)
		"对话":
			## `FW2:361-366` `FRIEND_CHAT`：在线才 `FriendChatManage.openChat(id,name)`，
			## 离线只 `addNotice(CN.ON_LINE_PLAYER)`（**不开窗**）。
			_好友开私聊(项)
		"添加好友钮":
			## `FTL:69-76`：开选人窗 + 多功能钮改「添加好友」、searchType = 1。
			## 选人窗是好友页自己用 `子窗表` 开的，这里只补"加好友档"的配置；没开就补开。
			家族子窗壳.只在未开时开(self, "好友选人窗", 好友文案表.取("SELCET_PLAYER_WINDOW_TITLE"),
					false, 好友子窗目录)
			var 选人 := 家族子窗壳.取内容(self, "好友选人窗")
			if 选人 != null and 选人.has_method("设添加好友"):
				选人.call("设添加好友")
		"交友":
			## `FW2:436-440` → `FriendPaneEvent(ADD_FRIEND)` → `UI.onAddFriend:1659` →
			## `127:1:<编号>`（先判"已经是好友"，只提示不发包）。
			if 号 > 0 and _backend != null and bool(_backend.in_game) and bool(_backend.call("is_friend", 号)):
				_通知("该玩家已经是你的好友")
			else:
				_好友请求("request_friend_add", 号, "加好友")
		_:
			## A2 之后好友页的动作已经全接；走到这里说明动作串拼错了（拼成新项会静默）。
			_通知("%s：好友页这一项还没接" % 动作)


## 好友页那几发统一从这儿出：先判在线，再调后端；发不出去/不在线都给一句提示，
## 不像旧版那样静默吞掉点击。
func _好友请求(方法: String, 参: Variant, 事: String) -> void:
	if _backend == null or not bool(_backend.in_game):
		_通知("%s需要在线" % 事)
		return
	if not bool(_backend.call(方法, 参)):
		_通知("%s发送失败" % 事)


## `ChatEvent.CHECK_ONLINE`：不发包，只把聊天框切到私聊、预填 `/名字 `、抢焦点。
func _开始好友私聊(名: String) -> void:
	if 名.is_empty():
		return
	for 节 in get_tree().get_nodes_in_group("chat_panel"):
		if 节.has_method("开始私聊"):
			节.call("开始私聊", 名)
			return
	_通知("请在聊天框输入 /%s 消息" % 名)


## `FW2:361-366` `FRIEND_CHAT` 那一档：**在线才开**私聊窗（`FriendChatManage.openChat(id,name)`），
## 离线只 `addNotice(CN.ON_LINE_PLAYER)`、不开窗。标题由窗自己按 `FRIENDCHAT_WINDOW_TITLE` 拼。
func _好友开私聊(项: Dictionary) -> void:
	var 号 := int(项.get("character_id", 0))
	var 名 := String(项.get("name", ""))
	if not bool(项.get("online", true)):
		_通知("该玩家不在线！")
		return
	if 号 <= 0:
		_通知("对话：找不到这名玩家的数据")
		return
	家族子窗壳.只在未开时开(self, "好友私聊窗", "", false, 好友子窗目录)
	var 窗 := 家族子窗壳.取内容(self, "好友私聊窗")
	if 窗 != null and 窗.has_method("设对象"):
		窗.call("设对象", 号, 名)


## `MarryTableManager.openMarryZengHuaWindow:184-197`：只存对面四项 + 发 `94:6`，
## 窗由 `94:6` 的回帧（`58:2`）在 `窗口管理` 那侧开（见 `头像面板` 同名那一支）。
func _好友赠花(项: Dictionary) -> void:
	var 号 := int(项.get("character_id", 0))
	var 管 := _取窗口管理()
	if 号 <= 0 or _backend == null or not bool(_backend.in_game) or 管 == null:
		_通知("赠花需要在线")
		return
	管.call("记赠花对面", {"charId": 号, "name": String(项.get("name", "")),
			"face": int(项.get("face", 0)), "level": int(项.get("level", 0))})
	_backend.call("request_flower_info", 号)


## 本族族长角色号（`1552:15` 的字段 7；旧包没有 ⇒ -1）。
func _族长号() -> int:
	if _session == null:
		return -1
	var 家: Variant = _session.get("guild")
	return int((家 as Dictionary).get("leader_id", -1)) if 家 is Dictionary else -1


## 「开除出族」钮 = 原版 `FamillyMembersWindow.fireMemberHandler`（`FMEM.as:362-368`）：
## 读 `list.selectedItem`，没选中什么都不做；再走 `FM.fireMember:750-764` 的两道闸
## （先自己、再族长）和 `FamillyPopUpWindow` 确认（正文**带名字**）。
func _开开除族员确认(员页: Control) -> void:
	var 行 := 家族成员填充.选中成员(员页)
	var 号 := int(行.get("character_id", 0))
	if 号 <= 0:
		return
	if _backend != null and 号 == int(_backend.character_id):
		_通知("不能开除自己！")
		return
	if 号 == _族长号():
		_通知("不能开除族长！")
		return
	_家族确认对象 = 行
	_家族确认动作 = "家族成员窗:开除"
	家族子窗壳.只在未开时开(self, "家族确认弹", "开除出族", false)
	_填家族确认弹(_家族确认动作)


## 成员行菜单（原版 `FM.cickMenuItemHandler` 的 `FAMILLY_MEMBER` / `FAMILLY_MANAGER` 两支，
## `FM.as:944-1048`）。`项` = 那一行成员（`character_id/name/rank/channel_id/...`）。
func _家族成员菜单动作(文本: String, 项: Dictionary) -> void:
	var 号 := int(项.get("character_id", 0))
	if 号 <= 0:
		return
	if 文本 == "查看资料":
		# `FM.as:948-960` / `:982-992`：`channelId > 0` 才 `clickCharacter`，否则
		# `ON_LINE_PLAYER`。成员行没带这个字段（摘要行）时按在线算，别把人拦死。
		if int(项.get("channel_id", 1)) <= 0:
			_通知("该玩家不在线！")
			return
		_查看角色资料(号)
		return
	var 管 := 家族成员填充.是族长(self)
	# `FM.as:972-976`：管理菜单里点到的**就是族长本人那一行** ⇒ 除查看资料外全拦。
	if 管 and 号 == _族长号():
		_通知("不能对自己进行%s操作！" % 文本)
		return
	match 文本:
		"加为好友":
			_家族加好友(项)
		"任命副族长", "任命长老", "任命顾问", "任命精英", "任命族员":
			# `FM.as:994-1040`：`requestBanghuiChangeMemberRank(id, 2|3|4|5|9999)`。
			var 职 := {"任命副族长": 2, "任命长老": 3, "任命顾问": 4,
					"任命精英": 5, "任命族员": 9999}.get(文本, 0) as int
			if 职 <= 0:
				return
			if _backend == null or not bool(_backend.in_game):
				_通知("任命职务需要在线")
				return
			_backend.request_guild_member_rank(号, 职)
		"禅让族长":
			# `FM.as:979-983`：`FamillyPopUpWindow` 确认，正文「你确定要禅让给%1吗？」。
			_家族确认对象 = 项
			_家族确认动作 = "家族成员窗:禅让"
			家族子窗壳.只在未开时开(self, "家族确认弹", "禅让族长", false)
			_填家族确认弹(_家族确认动作)
		"弹劾族长":
			_弹劾族长(项)
		_:
			_通知("%s：成员菜单这一项还没接" % 文本)


## 原版 `FM.addFriend:871-891`：已是好友只提示；按**名字**撞自己再拦；否则 `127:1`。
func _家族加好友(项: Dictionary) -> void:
	var 号 := int(项.get("character_id", 0))
	if _backend == null or not bool(_backend.in_game):
		_通知("加好友需要在线")
		return
	if bool(_backend.call("is_friend", 号)):
		_通知("该玩家已经是你的好友")
		return
	if 号 == int(_backend.character_id):
		_通知("你不能添加自己为好友！")
		return
	_backend.request_friend_add(号)


## 原版 `FM.onTanHeZhuZhang:363-374` + `tanHeZuZhang:243-274`：
## 背包里要有弹劾令（`数据/家族.json` 的 `cost.kick.item[0]` = 15019001），
## 确认文案 = `FAMILLY_MANAGER_HANHE_JIAZU_ZUZHANG`（`%1` 族长名、`%2` 天数，默认 5）。
## ⚠ 原版还要求族长连续 N 天未上线（`kickLeaderDays`，本机数据表没有这一项 ⇒ 取 AS3 兜底 5）；
##    本机服务端不做上线时间校验，这里只把原版会发的 `1552:22` 发出去，不伪造额外门槛。
func _弹劾族长(项: Dictionary) -> void:
	if 家族成员填充.是族长(self):
		_通知("不能弹劾自己")
		return
	if _session != null and String((_session.get("guild") as Dictionary).get("name", "")).is_empty():
		_通知("您没有家族，不能进行族长弹劾")
		return
	if _backend == null or not bool(_backend.in_game):
		_通知("弹劾需要在线")
		return
	if int(_backend.inventory_quantity(15019001)) <= 0:
		_通知("您没有【弹劾令】道具，请购买后再进行族长弹劾")
		return
	var 族长名 := String(项.get("name", ""))
	var 家: Variant = _session.get("guild") if _session != null else null
	if 家 is Dictionary and not String((家 as Dictionary).get("leader", "")).is_empty():
		族长名 = String((家 as Dictionary).get("leader", ""))
	var 正文 := "您确认要对您所在的家族族长<font color='#00ff00'>【%s】</font>进行弹劾？<br/>（族长超过<font color='#00ff00'>%d天</font>未上线，即可弹劾族长取而代之）" % [族长名, 5]
	输入确认弹.弹消息(_overlay, 正文, func(结果: int) -> void:
		if 结果 == 1 and _backend != null and bool(_backend.in_game):
			_backend.request_guild_impeach())


## 功能窗口正常挂在 `窗口管理`（CanvasLayer）下面；单窗工具/门里没有这一层 ⇒ 回 null。
func _取窗口管理() -> Node:
	var 节 := get_parent()
	while 节 != null:
		if 节.has_method("记赠花对面"):
			return 节
		节 = 节.get_parent()
	return null


func _show_guild_action(action_name: String) -> void:
	# 好友页的老口径动作串（页面里没有行数据的那几条路）：转给 `_好友菜单动作`。
	# 新页面直接调 `_好友菜单动作(动作, 行)`；保留这一支只为不把旧调用点摔进家族页末尾的
	# "等待家族服务器数据"那句假提示里。
	if action_name.begins_with("好友页|"):
		_好友菜单动作(action_name.get_slice("|", 1), {})
		return
	# ⓪ 家族升级入口：**满级时不开升级窗**，只弹一句提示。
	#    真值 `FamillyWindow.jiaZhuShengjiHandler`（FW.as:302-312）：
	#    `getFamillyUpgradeCfg()` 在 `myFamillyInfo.level >= 10` 时返 null ⇒ 不走
	#    `showWindow(FAMILLY_UPGRADE_WINDOW)`，改 `API.ui.addNotice(
	#    CN.FAMILLY_WINDOW_JIAZU_LEVEL_MAX)`「你的家族已经升到最高级！」。
	#    ⚠️ 必须赶在下面 `家族子窗壳.按动作` **之前**拦：那张开窗表会把裸名
	#       「家族升级」直接映射到升级窗，放它先跑就等于满级也照样开窗。
	if action_name == "家族升级" and _session != null \
			and int(_session.guild.get("level", 0)) >= GAME_DATA.家族最高等级:
		_通知("你的家族已经升到最高级！")
		return
	# ⓪ 家族页的「家族旗帜」是**二选一**（原版 `FamillyManager.showFamillyFlagView`，
	#    `FM.as:832-843`）：设过「下次跳过本说明界面」→ 直接开**家族旗帜窗**；
	#    否则先开**家族旗帜帮助窗**（`FFH` 那张 642×426 整图，连窗壳都没有）。
	#    ⚠️ 必须在 `家族子窗壳.按动作` **之前**拦掉：壳的开窗表把裸名「家族旗帜」直接
	#       映射到了家族旗帜窗，放它先跑就等于永远不弹说明窗。
	if action_name == "家族旗帜":
		_开家族旗帜视图()
		return
	# ① 另一位开发者的家族页接线（说明 §2 ①）：动作串先过壳的开窗/收窗表，
	#    **原来的 request_* 全部保留在下面**（壳只管 UI 开关，不碰协议）。
	#    裸名 = 主窗底栏 8 钮；"窗名:钮名" = 子窗里的钮。
	家族子窗壳.按动作(self, action_name)
	# 说明窗从**旗帜窗的「说明资讯」**开出来时，复选框要跟落盘值对上（原版 `FFH:50`）。
	# （从家族页那条路走的是 `_开家族旗帜视图`，那边自己同步。）
	if action_name == "家族旗帜窗:说明资讯":
		_同步帮助窗复选()
	# 「进入家族旗帜介面」= 原版 `FFH.clickBtnHandler`：`showWindow(FAMILLY_FLAG_WINDOW,false)`
	# 再收起自己。`showWindow` 的第二参 false 是"别反显/别开关式"，落到我们这边就是**开一下**。
	if action_name == "家族旗帜帮助窗:进入旗帜":
		家族子窗壳.关掉(self, "家族旗帜帮助窗")
		家族子窗壳.切换(self, "家族旗帜窗", "家族旗帜")
		_请求旗帜数据()
	# 「下次跳过本说明界面」：`家族子窗._翻复选` 已经**先把皮翻过来**了，
	# 这里只负责把翻过之后的状态落盘（原版 `FFH:86-89` 同序）。
	if action_name == "家族旗帜帮助窗:跳过":
		_存跳过旗帜说明()
	# ② **要发协议**的那几个（他 §5.3 故意没接 —— 不在 UI 层假装成功，归我们接）。
	#    先记下"这次确认的是哪件事"，确认弹的「确定」再按它发对应请求。
	#    「家族升级窗:确定」也走这条：原版点升级窗的「确定」**不直接发协议**，先弹确认弹
	#    （`FUW.as:41-44`），由弹窗的「确定」调 `sureToUpgrade` 才发。
	if action_name == "家族成员窗:解散家族" or action_name == "家族成员窗:退出家族" \
			or action_name == "家族升级窗:确定":
		_家族确认动作 = action_name
		# 窗刚被上面那张开窗表开出来，正文/按钮文字这时才能填（原版是弹窗构造时传进去的）。
		_填家族确认弹(action_name)
	if action_name == "家族确认弹:确定":
		var 后端 := get_node_or_null("/root/BackendConnection")
		if 后端 != null:
			if _家族确认动作 == "家族成员窗:解散家族":
				后端.request_guild_disband()
			elif _家族确认动作 == "家族成员窗:退出家族":
				后端.request_guild_leave()
			elif _家族确认动作 == "家族成员窗:开除":
				# `FM.sureToFire:1109-1112` → `requestBanghuiExpel(id)`（action 4）。
				后端.request_guild_expel(int(_家族确认对象.get("character_id", 0)))
			elif _家族确认动作 == "家族成员窗:禅让":
				# `FM.changeLeader:1260-1263` → `requestBanghuiChangeLeader(id)`（action 18）。
				后端.request_guild_change_leader(int(_家族确认对象.get("character_id", 0)))
			elif _家族确认动作 == "家族旗帜窗:安插本族旗帜":
				后端.request_map_flag_add(_族旗安插图)
			elif _家族确认动作 == "家族升级窗:确定":
				# 原版 `sureToUpgrade`（FUW.as:37-40）：发 `requestBanghuiUpgradeFlag(0,0)`
				# 后**当场关掉升级窗**（不等回包；升级结果走 `1552:4` 广播，见 `_收到家族状态`）。
				# ⚠️ 没连上后端时**必须留一句提示**：早年这里是静默 return，
				#    玩家点「升级」什么都没发生，连排查的线索都没有（§3.140 同族症状）。
				if bool(后端.in_game):
					后端.request_guild_upgrade_flag()
					家族子窗壳.关掉(self, "家族升级窗")
				else:
					_通知("还没有连上游戏服务器，稍等一下再试。")
		_家族确认动作 = ""
		_家族确认对象 = {}
	# 「创建」要把创建窗表单里的三个值读出来发过去（内容页由 `家族子窗壳.取内容` 取）。
	if action_name == "家族创建窗:创建":
		_发创建家族()
	# 「检测重名」= 原版 `FamillyCreateWindow.nameValidateHandler`（`FC:119-126`）。
	# ⚠️ 原来这里**没有这一条**，所以那颗钮点了完全没反应。
	if action_name == "家族创建窗:检测重名":
		_发检测重名()
	# 「图形选择」的翻页（原版 `PageComponent` 的上下页）。走页面既有的 `_发动作` 路由，
	# 与其余子窗钮同一条路 —— 别在填充脚本里自己 `Callable(静态函数).bind` 去接。
	if action_name == "家族创建窗:上一页":
		_翻家徽(-1)
	if action_name == "家族创建窗:下一页":
		_翻家徽(1)
	# 「购买」族书（单机版截图里那颗钮；原版 AS3 没有，是本项目按截图补的）。
	if action_name == "家族创建窗:购买":
		_发购买族书()
	# 「申请加入」= 原版 `FamillyListWindow.joinJiaZhuHandler`（`FL:364-372`）读
	# `list.selectedItem.id` → `FamillyManager.joinFamilly`（`FM.as:769-777`）→ `requestBanghuiApply`。
	# 拦截顺序照抄：**没选中就什么都不做**（原版那个 `if` 没有 else）；已在家族里则只提示不发协议。
	if action_name == "家族列表窗:申请加入":
		_发申请加入()
	# 家族金币窗（捐献金币）：开窗时灌余额/下限，窗内四钮各自处理（`ZGM.as`）。
	if action_name == "家族贡献窗:贡献金币":
		_初始化金币窗()
	elif action_name.begins_with("家族金币窗:"):
		_家族金币动作(action_name.get_slice(":", 1))
	# 家族贡献窗自己的分页四钮 / 「每页」下拉（原版 `PageComponent` + `MComboBox`）。
	# 场景根是通用 `家族子窗.gd`，**所有** TextureButton（含没皮肤的分页四钮）都会把
	# `家族贡献窗:<钮名>` 扔回来 ⇒ 在这里分发到内容页的填充脚本上（`家族贡献填充`）。
	# 「贡献金币」「贡献书籍」在上面那几支已经处理过，落到下面的 match 里什么都不做。
	if action_name.begins_with("家族贡献窗:"):
		var 贡献页 := 家族子窗壳.取内容(self, "家族贡献窗")
		if 贡献页 != null:
			match action_name.get_slice(":", 1):
				"首页", "上一页", "下一页", "末页":
					家族贡献填充.翻页(贡献页, self, action_name.get_slice(":", 1))
				"页":
					家族贡献填充.弹每页下拉(贡献页, self)
	# 家族令牌窗（捐献书籍）
	if action_name == "家族令牌窗:确定":
		_发令牌捐献()
	if action_name == "家族旗帜窗:安插本族旗帜" or action_name == "家族旗帜窗:修复族旗血量":
		_家族旗帜动作(action_name.get_slice(":", 1))
	# 「家族升级窗:确定」不在这里发协议：上面 ② 已把它转去**确认弹**，
	# 真发在「家族确认弹:确定」那一支（照原版 `sureToUpgrade` 的次序）。
	if action_name.begins_with("家族商城窗:购买商品:"):
		_家族商城购买(action_name.get_slice(":", 2))
	# 快捷键窗（另一位开发者的那一版只交回三种动作，见 `快捷键窗.gd:245-247`）。
	# ⚠️ 键位**在页面的「确定」里已经落盘**（`快捷键窗._落盘` → 工程既有的 `快捷键.应用单个`）；
	#    原版那两条协议（`Client.requestKeyChange` + `CharacterConfig.synch`）本机服务端
	#    **没有实现**（`fake_flash_server` 里查无此 action）⇒ 这里不假装发，只收窗。
	#    `方案N`/`保存方案` 的存档语义（`hasKeyScheme/saveKeyScheme`）是已知未收口，见设置页说明 §6。
	if action_name.begins_with("快捷键窗|"):
		var 动作 := action_name.get_slice("|", 1)
		if 动作 == "确定":
			close()
	# 「查询玩家」= 原版 `SearchPlayerWindow.searchHandler`（`SPW.as:77-84`）：
	# **名字为空就什么都不做**（那个 `if` 没有 else），非空才发、发完自己在途禁用
	# （回帧 `setData` 再放开，见 `家族列表填充`）。
	# ⚠️ 场景里那颗钮的 `metadata/act` 是「搜索」（不是节点名「钮搜索」）⇒ 早年的
	#    `"家族搜索窗:钮搜索"` 永远进不来，搜索按钮点了没反应（本轮修）。
	if action_name == "家族搜索窗:搜索":
		var 搜后 := get_node_or_null("/root/BackendConnection")
		var 搜窗 := 家族子窗壳.取内容(self, "家族搜索窗")
		if 搜后 != null and 搜窗 != null:
			var 名 := String((搜窗.get_node("输入玩家名") as LineEdit).text).strip_edges()
			if not 名.is_empty():
				# ⚠️ mode 必须是 **1**（按名字搜全服角色）；mode 2 是"同屏可见玩家"、
				# 不看 query —— 家族「查询玩家」按名字查，用 2 会恒返回空。
				# searchType **100** = 家族那一条（原版 `FamillyManager.as:897` 发的是 100，
				# `Client.as:5012` 按 100 派给 `searchPlayerResult`）。以前用默认值 4 ⇒
				# 和「双修选人窗」共用一个号，两边会互相把对方的列表抢走（10-18 现查）。
				搜后.request_char_search(名, 1, 100)
				家族列表填充.设搜索中(搜窗, true)
	# 查询窗的上一页/下一页 + 查看资料 + 邀请加入（`SearchPlayerWindow.as:204-260`）。
	if action_name.begins_with("家族搜索窗:"):
		var 搜页 := 家族子窗壳.取内容(self, "家族搜索窗")
		if 搜页 != null:
			match action_name.get_slice(":", 1):
				"上一页", "下一页":
					家族列表填充.翻页(搜页, self, action_name.get_slice(":", 1))
				"查看资料":
					var 看行 := 家族列表填充.选中(搜页)
					if not 看行.is_empty() and int(看行.get("character_id", 0)) > 0:
						_查看角色资料(int(看行["character_id"]))
				"邀请加入":
					# `SPW.as:246-252` `inviteHandler` → `FM.invateToJoinFamilly(charId)` → `1552:19`。
					# 原版只在 `if(_list.selectedItem)` 时发；没选中什么都不做。
					var 邀行 := 家族列表填充.选中(搜页)
					if not 邀行.is_empty() and int(邀行.get("character_id", 0)) > 0 \
							and _backend != null and bool(_backend.in_game):
						_backend.request_guild_invite(int(邀行["character_id"]))
	# 家族成员管理窗：分页四钮 / 两个下拉 / 自动同意复选框 / 开除出族
	# （原版 `FamillyMembersWindow.as` + `PageComponent` + `MComboBox`）。
	if action_name.begins_with("家族成员窗:"):
		var 员页 := 家族子窗壳.取内容(self, "家族成员窗")
		if 员页 != null:
			var 员项 := action_name.get_slice(":", 1)
			if 员项 in ["首页", "上一页", "下一页", "末页"]:
				家族成员填充.翻页(员页, self, 员项)
			elif 员项 == "页" or 员项 == "成员":
				家族成员填充.弹下拉(员页, self, 员项)
			elif 员项 == "自动同意":
				# `FMEM.as:128-145` `changeAutoAgreeHandler`：翻转后发 action 20（本工程服务端权威版）。
				if _backend != null and bool(_backend.in_game):
					_backend.request_guild_auto_accept(not 家族成员填充.自动同意(self))
			elif 员项 == "开除出族":
				_开开除族员确认(员页)
	if _backend != null and bool(_backend.in_game):
		match action_name:
			"家族列表":
				_backend.request_guild_list()
			# ⛔ 「家族升级」**绝不在这里发协议** —— 这个裸名是家族页底栏那颗钮，
			#    原版 `jiaZhuShengjiHandler`（FW.as:302-312）只做一件事：开升级窗
			#    （满级时改弹提示，见本函数开头 ⓪）。升级请求只从升级窗的「确定」→
			#    确认弹 → 「家族确认弹:确定」发（`FUW.as:37-44`）。
			#    以前这里跟着发过一次 `request_guild_upgrade_flag()` ⇒ 玩家只是想
			#    **看一眼升级条件**，服务端却已经收到升级请求：材料够就**未经确认直接升**，
			#    材料不够就弹一句「家族资金不足」——两头都不对（2026-10-14 修）。
			"家族尾兽":
				_backend.request_guild_boss_state()
				_backend.request_guild_boss_enter()
			"家族旗帜":
				# ⚠️ 这一支**正常情况下到不了**：裸名「家族旗帜」在 `_show_guild_action` 开头
				# 就被 `_开家族旗帜视图` 拦走、直接 return 了（它要按"跳过说明"设置二选一）。
				# 留着只是为了"万一有别的调用点直接叫这个名字"时不至于静默停摆。
				_请求旗帜数据()
			"家族贡献":
				_backend.request_guild_members(int(_session.guild.get("id", 0)))
			"家族商店":
				_backend.request_guild_shop()
			"家族商城窗:购买商品":
				_家族商城购买(action_name.get_slice(":", 2))
			"成员信息":
				_backend.request_guild_members(int(_session.guild.get("id", 0)), true)
			"家族技能":
				close()
				_session.request_feature("忍术")
		return
	if action_name == "家族技能":
		close()
		_session.request_feature("忍术")
		return
	_session.notification_requested.emit("%s：旧版入口已接入，等待家族服务器数据" % action_name)

func _buy_item(item_id: String, quantity := 1, 用点券 := false) -> void:
	_session.buy_shop_item(item_id, quantity, 用点券)

func _buy_npc_item(item_id: String, quantity := 1) -> void:
	_session.buy_npc_item(item_id, quantity)

## ⚠️ 这几个都是**格位**（1 基）不是物品 id（2026-10-17 巡检 #16）：背包/仓库的格子早就知道自己
## 是哪一格（`格子.槽位号`），按 id 反查首摞在同 id 两摞时会操作错那一款。
## 只有"手上只有 id"的调用（快捷栏、自动吃药）才走会话上那层按 id 的包装。
func _sell_item(格位: int, quantity := 1) -> void:
	_session.sell_inventory_slot(格位, quantity)

func _deposit_item(格位: int, quantity := -1) -> void:
	_session.deposit_slot(格位, quantity)

func _withdraw_item(格位: int, quantity := -1) -> void:
	_session.withdraw_slot(格位, quantity)

func _set_slider(value: float, key: String) -> void:
	_session.update_setting(key, value)

func _set_check(value: bool, key: String) -> void:
	_session.update_setting(key, value)
	if key == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)

func _set_backend_url(url: String) -> void:
	_session.update_setting("backend_url", url.strip_edges())
	_sync_backend()

func _save_backend_settings(host: LineEdit, port: SpinBox, account: LineEdit, password: LineEdit, web_url: LineEdit) -> void:
	_session.update_setting("backend_host", host.text.strip_edges())
	_session.update_setting("backend_port", int(port.value))
	_session.update_setting("backend_account", account.text.strip_edges())
	_session.update_setting("backend_password", password.text)
	_session.update_setting("backend_url", web_url.text.strip_edges())
	_sync_backend()

func _sync_backend() -> void:
	if _backend != null:
		_backend.sync_character()

## B5 = 原版 `LingquBiguanShouyi.drawShouyi:208-212` 的后半段，**逐句照搬、顺序不换**：
##   `:208` 派发事件（⇒ `UI.as:954-957` → `Client.requestBiguan(useDouble)`，即这一支的"上行"）
##   `:209` `onCloseBtnClick(null)` —— 关掉**领取窗自己**
##   `:210` `API.ui.content.biGuanWindow.onCloseBtnClick(null)` —— **把设定窗一起关掉**
##   `:211-212` `this._experience.text = "0"; this._zhenQi.text = "0"` —— 本地两个数字刷成 "0"
## ⚠ 原版**没有** `disabled`、没有隐藏钮、没有"换页到闭关经验"。原来那句
##   `open_page("闭关经验")` 是自造的换页（两扇一扇都不关），本轮按原文撤掉。
## ⚠ 关窗在前、归零在后，照 `:209-212` 的字面顺序：`close()` 只是把遮罩 `visible = false`，
##   页内的件还挂在 `_content` 上，所以后两句仍然写得进去。
func _claim_retreat_claim(use_double: bool) -> void:
	# 上行包形 = 原版：`LingquBiguanShouyi.as:208` 派事件 ⇒ `AllInOneProcessor.requestBiguan(useDouble)`
	# 先 `writeByte(1)` 再 `writeByte(useDouble ? 1 : 0)` ⇒ 客户端发 `1284:1:<0|1>`
	# （`后端连接.gd:2353-2359`），服务端 `handle_biguan:17946` 读的就是这一形状（10-20 已点头改齐）。
	# 离线（单机夹具之外）这一支**原版没有**，留着是为了"不许造假"：
	# 没发出去就不关窗、不把数字刷成 0（刷了就是假装领到了）。
	# ⚠ 反馈必须走 `_通知`（聊天那一条，玩家真看得见）：`_show_hint` 写的是窗口标题条里那枚
	#   `后端状态` 标签（`功能窗口.tscn:80-90`，深灰字压在标题上）—— 10-20 用户报"点了没反应"
	#   一半就是这条：代码跑了、字也写了，屏幕上什么都没有。
	if not _session.request_修行收益领取(use_double):
		_通知("离线状态无法领取修行收益")
		return
	close()
	var 页: Node = null
	if _content != null and _content.get_child_count() > 0:
		页 = _content.get_child(0)
	if 页 != null:
		var 经验 := (页 as Node).get_node_or_null("经验值") as Label
		var 精华 := (页 as Node).get_node_or_null("精华值") as Label
		if 经验 != null:
			经验.text = "0"
		if 精华 != null:
			精华.text = "0"

func _claim_retreat() -> void:
	# 在线时走原版 BIGUAN 协议（单倍 = `1284:1:0`、双倍 = `1284:1:1`，见 `后端连接.request_biguan_claim`），
	# 收益与计时都由服务端维护；
	# 离线（单机夹具之外）才回落到本地那套，避免按钮点了没反应。
	if not _session.request_修行收益领取(false):
		_session.claim_retreat_reward()
	_render_page()

func _redeem_code(code: String) -> void:
	_activity.redeem_code(code)

func _check_in() -> void:
	_activity.check_in()

func _claim_benefit() -> void:
	_activity.claim_daily_benefit()

## 亲热天堂的按钮由活动窗维护的藏宝状态机处理（2026-10-21 #9：过去这里转的是
## `活动服务.explore_treasure()`，只会离线拒绝，页面上的按钮永远打不开宝箱）。
func _explore_treasure() -> void:
	_活动窗口.藏宝按钮()

func _mine() -> void:
	_activity.mine()

func _start_boss() -> void:
	var current_scene := get_tree().current_scene
	var life_root := current_scene.get_node_or_null("LifeRoot") if current_scene != null else null
	if life_root != null and life_root.has_method("start_boss_encounter") and bool(life_root.call("start_boss_encounter")):
		close()

## 打造执行 —— 七个页签**各走各的协议**，动作号照 `后端连接.request_item_change`：
##   强化 5 / 升阶(进阶) 3 / 洗附加属性 1 / 洗附加数值 2 / 天生 4 / 刻印 16
##   精炼 **21 或 22**（看下拉：附加属性 22 / 强化星级 21 —— 同一页两个分支，别记成一个）
## （出处：`EquipStrengthWindow` 的 `strengthHandler` 与 §3.11.1 的动作表。）
##
## ⚠️ 之前这里是 `_strengthen(slot_name: String)` 并被 `bind(_selected_strengthen_slot)` 绑了
## **int** —— 参数类型对不上，点「开始强化」会直接报错；而且它只走 `_session.strengthen_equipment`
## （那条只覆盖强化、还带离线 mock）。现在统一走 `_backend`，在线才发。
func _执行打造(page: Control) -> void:
	if not _打造请求.is_empty():
		return
	var 选中 := _会话选中()
	if 选中.is_empty():
		_show_hint("请先放入需要打造的装备")
		return
	var 后端 = _backend
	if 后端 == null or not bool(后端.in_game):
		_show_hint("装备打造需要连接原版服务端")
		return
	var 位置 := int(选中.get("slot_index", 选中.get("equip_position", _selected_strengthen_slot)))
	if 位置 == 0:
		_show_hint("装备缺少原版槽位，无法发送打造请求")
		return
	var 幸运符 := _打造幸运符颗数(page)
	var 页名: String = 打造页签[clampi(_strengthen_tab, 0, 打造页签.size() - 1)]
	if 页名 in ["强化", "天生", "精炼"]:
		var 拒 := _打造前置(选中)
		if not 拒.is_empty():
			_停打造自动()
			_通知(拒)
			_refresh_current()
			return
		if _打造自动选中:
			_打造自动目标 = {"页": _strengthen_tab, "格": 位置, "id": str(选中.get("id", "")), "项": _精炼项选中}
	if 页名 in ["强化", "天生", "精炼", "洗附加属性"]:
		_打造请求 = {"页": _strengthen_tab, "格": 位置, "id": str(选中.get("id", "")), "项": _精炼项选中}
	var 已发 := false
	match 页名:
		"强化":
			已发 = 后端.request_strength(位置, 幸运符)
		"洗附加属性":
			# 服务端是"直接生效"（动作 4 没有预览/保存），所以洗前先记一份快照，
			# 回帧写到会话里之后再并排画出来（`_刷新洗属性对照` 在页面重建时调用）。
			_开始洗属性对照(选中)
			已发 = 后端.request_change_aptitude(位置, 幸运符)
		"洗附加数值":
			已发 = 后端.request_wash_plus_value(位置, 0)
		"进阶":
			已发 = 后端.request_stage_up(位置, 幸运符, false, false)
		"天生":
			已发 = 后端.request_wash_born(位置)
		"刻印":
			已发 = 后端.request_carve(位置, true)
		"精炼":
			# 精炼页的下拉两项**各走各的协议**（`EquipBaiLianPanel.sureToRequest()`，`:152-162`）：
			#   下拉 0「提升附加属性」→ `requestForgeAdditive`  → ITEM_CHANGE 动作 **22**
			#   下拉 1「提升强化星级」→ `requestForgeStrength` → ITEM_CHANGE 动作 **21**
			# ⚠️ 别把「精炼」整页记成 22 —— 22 只是默认那一项，21 是同一页的另一半。
			if _精炼项(page) == 装备打造表.精炼项_强化星级:
				已发 = 后端.request_forge_strength(位置)
			else:
				已发 = 后端.request_forge_additive(位置)
		_:
			_show_hint("「%s」的协议尚未接" % 页名)
			return
	if not 已发:
		_打造请求.clear()
		_洗属性待旧值.clear()
		_停打造自动()
		_show_hint("打造请求发送失败")
	elif not _打造请求.is_empty():
		var 计 := get_tree().create_timer(10.0)
		_打造应答计时 = 计
		计.timeout.connect(func(): _打造应答超时(计))
	_refresh_current()


func _设置打造自动(开启: bool) -> void:
	_打造自动选中 = 开启
	if not 开启:
		_停打造自动()
	_refresh_current()


func _停打造自动() -> void:
	_打造自动选中 = false
	_打造自动目标.clear()
	_打造自动计时 = null


func _打造前置(选中: Dictionary) -> String:
	var 配置 := {}
	match 打造页签[_strengthen_tab]:
		"强化":
			if int(选中.get("strengthen", 0)) >= 装备打造表.强化上限:
				return "普通强化已达上限，自动强化停止"
			配置 = 装备打造表.取强化(int(选中.get("strengthen", 0)) + 1)
		"天生":
			if _天生已满(选中):
				return "天生属性已满，自动强化停止"
			配置 = 装备打造表.取天生(装备部位.位置(str(选中.get("id", ""))), _装备阶数(选中))
		"精炼":
			if _精炼项选中 == 装备打造表.精炼项_强化星级:
				if int(选中.get("strengthen", 0)) != 10:
					return "只有10星装备可以精炼强化星级"
			else:
				if int(选中.get("strengthen", 0)) < 11:
					return "装备达到11星后才能精炼附加属性"
				if int(选中.get("forge_additive_ratio", 0)) >= 500:
					return "附加属性已满，自动精炼停止"
			配置 = 装备打造表.取精炼(_精炼项选中)
	if 配置.is_empty():
		return "这件装备无法进行当前打造操作"
	if int(_session.player_stats.get("gold", 0)) < int(配置.get("needMoney", 0)):
		return "金币不足，打造停止"
	if 装备打造表.拥有数(_session, int(配置.get("needItemId", 0))) < int(配置.get("needItemCnt", 0)):
		return "打造材料不足，打造停止"
	return ""


func _收到打造装备帧(标志: int, 字段: Array) -> void:
	if 标志 != 11 or 字段.size() < 5:
		return
	var 格 := int(字段[2])
	if 格 == _洗属性旧格 and not _洗属性待旧值.is_empty():
		_洗属性旧值 = _洗属性待旧值.duplicate(true)
		_洗属性待旧值.clear()
		_refresh_current()
	if not _打造请求.is_empty() and 格 == int(_打造请求["格"]) and int(_打造请求["页"]) in [0, 1, 4]:
		_结束打造请求()


func _结束打造请求() -> void:
	_打造请求.clear()
	_打造应答计时 = null
	if not _打造自动目标.is_empty():
		var 计 := get_tree().create_timer(0.9)
		_打造自动计时 = 计
		计.timeout.connect(func(): _自动打造下一次(计))
	_refresh_current()


func _自动打造下一次(计: SceneTreeTimer) -> void:
	if 计 != _打造自动计时 or _打造自动目标.is_empty():
		return
	_打造自动计时 = null
	var 选中 := _会话选中()
	if not 已打开() or _页名() != "装备强化" or 选中.is_empty() \
			or _strengthen_tab != int(_打造自动目标.get("页", -1)) \
			or _精炼项选中 != int(_打造自动目标.get("项", -1)) \
			or str(选中.get("id", "")) != str(_打造自动目标.get("id", "")) \
			or int(选中.get("slot_index", 选中.get("equip_position", _selected_strengthen_slot))) != int(_打造自动目标.get("格", 0)):
		_停打造自动()
		_refresh_current()
		return
	if _backend == null or not bool(_backend.in_game):
		_停打造自动()
		_refresh_current()
		return
	_执行打造(_content.get_child(0) as Control)


func _打造应答超时(计: SceneTreeTimer) -> void:
	if 计 != _打造应答计时:
		return
	_打造请求.clear()
	_打造应答计时 = null
	_洗属性待旧值.clear()
	_停打造自动()
	_通知("未收到打造结果，已停止自动操作，请确认结果后再试")
	_refresh_current()


## 「本次操作消耗金币 / 本次操作成功几率」那两行。
##
## ⚠️ 成功率**必须把「这一次用几颗幸运符」传进去**。原版是
##     `_checkBox.selected ? int(_configInfo.prob + int(_comboBox.value) * UIConfig.xingYunJingRatio)
##                        : int(_configInfo.prob)`
##   （`EquipPropResetPanel.as:421`、`EquipUpgradeWindow.as:337`；`xingYunJingRatio = 3`
##    见 `UIConfig.as:976`）。
##
##   §3.18.3 第 6 条记的"幸运符比例没接"，真况是：**公式早就在
##   `装备打造表.实际成功率` 里了，缺的是把颗数传进去** —— 之前五处调用全没传，
##   于是显示的成功率恒等于 `prob`，勾上幸运符、改下拉都不动。
##   所以调用点分两半：开页画一次 + **勾选/下拉一变就重画**（见 `_接线幸运符刷新`）。
## 2026-10-01：节点从 Label 换成了 **RichTextLabel**，金币不够时原版要把数字标红
## （`_textField.htmlText` 里 `￥` 换成 `<font color='#ff0000'>N</font>`，
##   `EquipStrengthWindow.as:595` / `EquipPropResetPanel.as:420` /
##   `EquipKeYinPanel.as:315` / `EquipUpgradeWindow.as:333` 四页同一句）。
## ⚠️ 判据照抄原版的怪癖：`needMoney < cocoNuts` 才正常 ⇒ **钱正好够也标红**。
## 兼容 Label 兜底（万一还有没换过来的调用点）：那条分支不套色、写同文纯文本。
func _刷新消耗几率(page: Control, 节点路径: String, 配置: Dictionary) -> void:
	var 节点 := page.get_node_or_null(节点路径)
	var 富文本 := 节点 as RichTextLabel
	var 纯标签 := 节点 as Label
	if 富文本 == null and 纯标签 == null:
		return
	var 金币 := int(配置.get("needMoney", 0))
	var 余额 := int(_session.player_stats.get("gold", 0)) if _session != null else 0
	var 金币文本 := str(金币)
	if 金币 >= 余额:
		金币文本 = "[color=#ff0000]%d[/color]" % 金币 if 富文本 != null else str(金币)
	var 文本 := "本次操作消耗金币：%s\n本次操作成功几率：%d%%" % [
		金币文本,
		装备打造表.实际成功率(配置, _打造幸运符颗数(page)),
	]
	if 富文本 != null:
		富文本.text = 文本
	else:
		纯标签.text = "本次操作消耗金币：%d\n本次操作成功几率：%d%%" % [
			金币, 装备打造表.实际成功率(配置, _打造幸运符颗数(page))]


## 幸运符「勾选 / 数量下拉」一变就重算那两行。三页（洗附加数值 / 洗附加属性 / 进阶）共用。
## 顺手把下拉可用性也管上 —— 原版是 `_comboBox.enabled` 跟 `_checkBox.selected` 联动。
func _接线幸运符刷新(page: Control, 勾选: CheckBox, 下拉: OptionButton, 配置: Dictionary) -> void:
	var 路径 := _找消耗几率路径(page)
	if 路径.is_empty():
		push_error("幸运符接线：这一页找不到「消耗/几率」那两行的标签")
		return
	勾选.toggled.connect(func(开: bool):
		下拉.disabled = not 开
		_刷新消耗几率(page, 路径, 配置))
	下拉.item_selected.connect(func(_序号: int):
		_刷新消耗几率(page, 路径, 配置))


## 「消耗/几率」那两行的标签，三页里叫的名字不一样，按候选名找（各自只有一个命中）。
func _找消耗几率路径(page: Control) -> String:
	for 路径 in ["材料框/消耗几率", "材料框/消耗文本", "结果区/结果文本", "内容容器/材料框/消耗几率"]:
		var 节点 := page.get_node_or_null(路径)
		if 节点 is Label or 节点 is RichTextLabel:
			return 路径
	return ""


## 这一次要用几颗幸运符。原版是「勾了『本次操作使用』才读下拉框」
## （`_checkBox3` 与 `_comboBox.enabled` 联动）。找不到控件就当 0 颗。
func _打造幸运符颗数(page: Control) -> int:
	var 勾选 := page.find_child("使用幸运符", true, false) as CheckBox
	var 下拉 := page.find_child("幸运符数量", true, false) as OptionButton
	if 勾选 == null or 下拉 == null or not 勾选.button_pressed or 下拉.selected < 0:
		return 0
	# 配置里的 `maxHelpCnt` 才是上限（强化是 0 —— 那一页压根没有幸运符）
	var 配置 := 装备打造表.取强化(mini(int(_会话选中().get("strengthen", 0)) + 1, 装备打造表.强化上限))
	if 打造页签[clampi(_strengthen_tab, 0, 打造页签.size() - 1)] == "进阶":
		配置 = 装备打造表.取进阶(_装备阶数(_会话选中()) + 1)
	return clampi(下拉.get_selected_id(), 0, 装备打造表.幸运符上限(配置))


## 精炼页下拉当前选的是哪一项（0 提升附加属性 / 1 提升强化星级）。
## 找不到下拉（不在精炼页 / 面板没建起来）就按原版的默认值 0 走。
func _精炼项(page: Control) -> int:
	var 下拉 := page.find_child("精炼项", true, false) as OptionButton
	return 下拉.get_selected_id() if 下拉 != null else 装备打造表.精炼项_附加属性


## 左栏"放着的那件"（原版 `_itemData`）。没放 = 空字典。
## 两种来源都是**现读会话**（不存快照），打造成功/失败后数值自动是新的：
##   · 穿着的 → `equipped_items[游标]`；
##   · 背包的 → 按 `格+id`（格 0 时只按 id）在 `inventory` 里找；找不着（被消耗/挪走/合成掉）
##     就自动落回"没放"——对位原版刷新时 `getItemBySlot` 拿不到或 id 对不上就
##     `backItemToEquip()`（`EquipStrengthWindow.as:462-466`）。
func _会话选中() -> Dictionary:
	if not _强化放入中:
		return {}
	if _强化放入来源 == "背包":
		for 物品 in _session.inventory:
			if String((物品 as Dictionary).get("id", "")) != _强化放入id:
				continue
			if _强化放入格 != 0 and int((物品 as Dictionary).get("slot_index", 0)) != _强化放入格:
				continue
			return 物品 as Dictionary
		_清放入()
		return {}
	return _session.equipped_items.get(_selected_strengthen_slot, {})

func _learn_skill(skill_id: String) -> void:
	_session.learn_skill_from_book(skill_id)

func _start_ruins() -> void:
	if _activity.start_ruins_challenge():
		close()

func _today() -> int:
	return int(Time.get_unix_time_from_system()) / 86400

func _skill_slot_for(skill_id: String) -> int:
	for index in _session.skill_slots.size():
		if String(_session.skill_slots[index].get("id", "")) == skill_id:
			return index
	return -1

func _render_elite_copy() -> void:
	精英副本窗口.渲染(self)



## 活动大使（模板 59）菜单第三行「兑换忍具」= `RENJU_EXCHANGE=28`。
## 原版 `RenJuDuiHuanWindow.as`（420×250）：左一枚**成品格**、右六枚**碎片格**（`碎片1..6`）
## ⇒ 集齐六种八咫镜碎片按下「兑换」⇒ `API.client.requestRenJuHeCheng()`
## = `RenJuProcessor:29-34`：`writeByte(3)` + `SendOpCodes.RENJU`。
##
## ⚠️ 2026-10-11 之前这里写的是"本工程不接协议（待点头）" —— **假缺口**：
##    服务端 `handle_renju`（`ClientOpcode.RENJU = 2082`）**动作 3 就是它**
##    （`RenJuAction.COMBINE`：扣 16000278..16000283 各 1、发 65000001，附两句失败文案）。
##    已接：碎片格填数量+不足灰化（原版 `validateItem:134-153`）、兑换钮走真请求。
func _render_renju_exchange() -> void:
	var 页 := 原版服务窗.渲染(self, 忍具兑换场景, {}, {"兑换钮": _忍具兑换})
	_填忍具兑换页(页)
	_给页挂提示框(页)
	_接兑换提示(页, "子面板/忍具格/忍具格_格", 忍具成品, 忍具碎片)


## 原版 `RenJuDuiHuanWindow.as:22` 的 `RENJU_DEBRIS_IDS`（六种八咫镜碎片，逐字）。
const 忍具碎片 := [16000278, 16000279, 16000280, 16000281, 16000282, 16000283]
## 十拳剑那六种碎片：**连号** `16000110..16000115`（服务端 `ItemId.TOTSUKA_FRAGMENT_1..6`，
## `fake_flash_server.py:592-597`），与 `数据/物品.json` 的「十拳剑碎片一..六」逐条对得上。
const 十拳剑碎片 := [16000110, 16000111, 16000112, 16000113, 16000114, 16000115]
## 十拳剑成品（`LingQi` 20100001，`LingEquipAction.COMBINE` 发的就是它）。
const 十拳剑成品 := 20100001

## 原版 `:30` `renJuItemId = 65000001`（八咫镜；这个 id 不在 `数据/物品.json` 里，
## 图标是 `原版直解清单.json` 里手工单符号导出那张，所以成品格不在这儿重填图标）。
const 忍具成品 := 65000001


## 六枚碎片格的「数量 + 灰化」：逐条照 `validateItem:134-153` ——
## 数量 = 背包里该碎片的**拥有数**（`isBagExistItem`），0 就把**格皮+图标**灰掉
## （`applyGrayFilter`，数量文本不跟着灰，同 `扩容窗口` 那条口径）。
func _填忍具兑换页(页: Control) -> void:
	_填兑换碎片格(页, 忍具碎片, true)


## 兑换窗族**共用**的碎片格填法（忍具 / 十拳剑两扇窗结构一模一样：`子面板/碎片格1..6/碎片格N_格`）。
## `写名` = 要不要把「名」也改写成 `碎片N`（忍具那扇原版硬编码 `"碎片" + (i+1)`；
## 十拳剑那扇是 `DUIHUAN_SUIPIAN + i` ⇒ **碎片0..5**，场景烘的就是它 ⇒ 别动）。
func _填兑换碎片格(页: Control, 碎片表: Array, 写名 := false) -> void:
	const 灰度 := preload("res://脚本/界面/组件/禁用灰度.gdshader")
	var 材 := ShaderMaterial.new()
	材.shader = 灰度
	for i in 碎片表.size():
		var 格 := 页.get_node_or_null("子面板/碎片格%d/碎片格%d_格" % [i + 1, i + 1]) as Control
		if 格 == null:
			continue
		var 有 := 装备打造表.拥有数(_session, int(碎片表[i]))
		# ⚠️ 三枚子的名字里**只有「名」不带 `_格`**（场景就这么烘的，写错就是"格子里什么都没有"）
		var 数 := 格.get_node("碎片格%d_格_数量" % (i + 1)) as Label
		数.text = str(有)
		if 写名:
			(格.get_node("碎片格%d_名" % (i + 1)) as Label).text = "碎片%d" % (i + 1)
		# ⚠️ `str()` 不是 `String()` —— GDScript 4 里 **`String(int)` 是非法构造**（当场抛），
		#    而它抛在"图标"这一行 ⇒ 后面几枚格子**一个都没填**、灰化也没复位（门当场抓出来）。
		var 图 := 格.get_node("碎片格%d_格_图标" % (i + 1)) as TextureRect
		图.texture = GAME_DATA.item_icon(str(碎片表[i]))
		# 灰化只挂**格皮 + 图标**两件（原版 `applyGrayFilter` 就是这么挂的）；数量文本不跟着灰
		# —— 场景是"没有碎片"那副样子烘的 ⇒ 那枚数量标签上的 mat1 也要清掉。
		var 灰 := null if 有 > 0 else 材
		格.material = 灰
		图.material = 灰
		数.material = null


## 「兑换」—— 逐条照 `duiHuanHandler:170-177`：六种碎片**各 ≥1** 才发（`canDuiHuan:155-167`），
## 发完关窗。⚠️ 原版不足时是**静默返回**（一发不发、也不提示）—— 我们给一句提示：
## 静默返回在这个端口上就是"点了没反应"那个老形状（§3.111/§3.112 的判据都在治它）。
func _忍具兑换() -> void:
	if not _碎片齐(忍具碎片, "八咫镜"):
		return
	_发兑换请求("request_renju_combine", "兑换忍具")


## 「兑换十拳剑」—— 与忍具同形（原版 `DuiHuanWindow.duiHuanHandler:157-164` →
## `requestLingEquipHeCheng()` = `LingEquipProcessor:60-67`：**byte 3 + 两个 int 0** + `LING`）。
func _十拳剑兑换() -> void:
	if not _碎片齐(十拳剑碎片, "十拳剑"):
		return
	_发兑换请求("request_ling_equip_combine", "兑换十拳剑")


## 六种碎片各 ≥1（原版 `canDuiHuan`）。⚠️ 原版不足时**静默返回** —— 端口上那就是
## §3.111/§3.112 一直在治的"点了没反应"，故这里给一句提示。
func _碎片齐(碎片表: Array, 名字: String) -> bool:
	for id in 碎片表:
		if 装备打造表.拥有数(_session, int(id)) < 1:
			_show_hint("请先集齐六种%s碎片（缺 %s）" % [名字, GAME_DATA.item_name(int(id))])
			return false
	return true


## 发出去 + 关窗（原版两扇窗都是 `setDOShow(...,false)`）。
func _发兑换请求(方法: String, 动作名: String) -> void:
	var 后端 = _backend
	if 后端 == null or not 后端.has_method(方法) or not bool(后端.call(方法)):
		_show_hint("%s要走服务端协议，当前未连上服务端" % 动作名)
		return
	# 发成功不提示（同 `_成交修理`）：换到的东西由回帧进背包，那才是玩家要看的。
	close()

## 活动大使菜单第二行「兑换十拳剑」= `TOTSUKA_EXCHANGE=25`；原版 `DuiHuanWindow.as:78-84`
## 的钮点下去同样是服务端那一跳（`LingQiManager` 的兑换请求）⇒ 未接，只回显。



## 活动大使菜单第二行「兑换十拳剑」= `TOTSUKA_EXCHANGE=25`；原版 `DuiHuanWindow.as:78-84`：
## 钮 → `API.client.requestLingEquipHeCheng()` = `LingEquipProcessor:60-67`
## （`writeByte(3)` + 两个 `writeInt(0)` + `SendOpCodes.LING`）。
##
## 服务端有（`ClientOpcode.LING = **2081**`、`LingQiAction.COMBINE = 3`），窗口与数据也都在：
## 六种碎片就是**连号** `16000110..16000115`（服务端 `ItemId.TOTSUKA_FRAGMENT_1..6`，
## 与 `数据/物品.json` 的「十拳剑碎片一..六」逐条对得上），成品 `20100001` 也在。
## ⇒ 与「兑换忍具」同一副样子，**一并接上**（§3.119）。
## ⚠️ 他那一版原注说卡在"`数据/忍具.json` 没导 `Debris`" —— 那句话**不影响这一跳**：
##    Debris 只用来填格/做前置，而碎片 id 是连号且物品表里有，照写给死即可；
##    真要按原版从表里现读，才需要补那一步导出。
func _render_totsuka_exchange() -> void:
	var 页 := 原版服务窗.渲染(self, 十拳剑兑换场景, {}, {"兑换钮": _十拳剑兑换})
	_填兑换碎片格(页, 十拳剑碎片)
	_给页挂提示框(页)
	_接兑换提示(页, "子面板/十拳剑格/十拳剑格_格", 十拳剑成品, 十拳剑碎片)


## 鹿丸（模板 29）菜单第一行「卡片套册收集」= `CARD_COLLECTION=8`（2.2.3 服务端
## `fake_flash_server.py:1110-1149`）。原版 `GuwanshoujiWindow`（534×384）：左列套册树、
## 右列选中套卡的需求/掉落/进度。树与右列都是运行期现填 ⇒ 控制器 `卡片套册窗.gd`。
func _render_card_collection() -> void:
	卡片套册窗.渲染(self, 卡片套册场景)


## 伊鲁卡菜单第一行「变身卡与道具兑换」= `ITEM_EXCHANGE=9` → `exchangeShop/ExchangeShopWindow`。
## 行数据只有服务端 `1820` 那一帧有（**未接**）⇒ 离线是空态；量具/门自己喂
## `开发工具/出兑换商店夹具.py` 从 2.2.3优化版 服务端捕获目录取的 12 行。
func _render_exchange_shop(行: Array = []) -> void:
	兑换商店窗.渲染(self, 兑换商店场景, 行)


## 伊鲁卡菜单第二/第三行 = 动作 31 / 32 ⇒ 原版同一个 builder 的两个模式（`特殊` 那一参）。
func _render_card_swap(特殊: bool) -> void:
	变身卡互换窗.渲染(self, 变身卡特性互换场景 if 特殊 else 变身卡互换场景, 特殊)


## 富岳（模板 27）两行「每日环任务 / 周试炼任务」= 328 帧第 6 段 selection 的补行
## （`fake_flash_server.py:51414-51447`，任务 8001/8002）。**入口不是服务菜单动作值**，
## 所以落地页写在 `开发工具/出木叶村NPC表.py` 的 `环任务行` 表里、由 `小地图面板` 本地直开。
## `数` = 一条 `BasicQuestInfoData` 形状，只有服务端 444 的任务信息帧才有 ⇒ 本地一定是空态；
## 门/量具自己造一条喂进去（字段名逐条对 AS3，见 `真值/窗口/木叶村NPC.md` §6f）。
func _render_daily_ring(数: Dictionary = {}) -> void:
	日环任务窗.渲染(self, 日环任务场景, _环任务数据(8001) if 数.is_empty() else 数)


func _render_weekly_ring(数: Dictionary = {}) -> void:
	周试炼任务窗.渲染(self, 周试炼任务场景, _环任务数据(8002) if 数.is_empty() else 数)


var _环任务请求 := {}
var _环任务应答表: SceneTreeTimer


func _环任务操作(动作: int, 编号: int) -> bool:
	if not _环任务请求.is_empty():
		return false
	if _backend == null or not _backend.in_game:
		_通知("未连接服务端，无法操作环任务")
		return false
	_环任务请求 = {"动作": 动作, "编号": 编号}
	if not _backend.request_quest(动作, 编号):
		_环任务请求.clear()
		_通知("环任务请求发送失败")
		return false
	_环任务应答表 = get_tree().create_timer(10.0)
	_环任务应答表.timeout.connect(_环任务超时.bind(_环任务应答表))
	_刷新环任务页()
	return true


func _环任务超时(表: SceneTreeTimer) -> void:
	if 表 != _环任务应答表:
		return
	_环任务应答表 = null
	_环任务请求.clear()
	_停日环自动()
	_刷新环任务页()
	if 已打开():
		_通知("未收到环任务结果，已停止自动操作，请确认结果后再试")


func _停日环自动() -> void:
	for 页 in _content.get_children():
		if 页.has_meta("ring_quest_binding"):
			日环任务窗.停自动(页.get_meta("ring_quest_binding"))


func _收到环任务进度(信息: Dictionary) -> void:
	var 编号 := int(信息.get("id", 0))
	if _环任务请求.is_empty():
		## 服务端交完一环会直接把下一环接上并推 `444:2`（`_complete_original_quest:58194`
		## 那一支）⇒ 正开着环任务窗时要把页上的数字跟到新任务，不然停在交完的那条。
		if 编号 in [8001, 8002]:
			_刷新环任务页()
		return
	if 编号 != int(_环任务请求["编号"]):
		return
	var 自动 := int(_环任务请求["动作"]) == 9 and int(_环任务请求["编号"]) == 8001
	_环任务请求.clear()
	_环任务应答表 = null
	_环任务结果.call_deferred(自动)


func _环任务结果(自动: bool) -> void:
	_刷新环任务页()
	if 自动 and 已打开():
		for 页 in _content.get_children():
			if 页.has_meta("ring_quest_binding"):
				var 绑: Dictionary = 页.get_meta("ring_quest_binding")
				if bool(绑["点过"]):
					日环任务窗._自动刷新(绑)


func _刷新环任务页() -> bool:
	var 页名 := _固定页 if not _固定页.is_empty() else _current_page
	if 页名 not in ["日环任务", "周试炼任务"] or _content == null:
		return false
	var 数 := _环任务数据(8001 if 页名 == "日环任务" else 8002)
	for 页 in _content.get_children():
		if 页.has_meta("ring_quest_binding"):
			var 绑: Dictionary = 页.get_meta("ring_quest_binding")
			if not 数.is_empty() and 数 != 绑["数"]:
				日环任务窗.填数据(页, 数, 绑)
			for 名 in ["立即完成钮", "刷新任务钮"]:
				(页.get_node(名) as Button).disabled = not _环任务请求.is_empty()
		elif 页.has_meta("ring_quest_data"):
			var 旧: Dictionary = 页.get_meta("ring_quest_data")
			if not 数.is_empty() and 数 != 旧:
				旧.clear()
				旧.merge(数)
				周试炼任务窗.填数据(页, 旧, self)
			for 名 in ["降难度钮", "提回报钮"]:
				(页.get_node(名) as Button).disabled = not _环任务请求.is_empty()
	return _content.get_child_count() > 0


func _环任务数据(编号: int) -> Dictionary:
	if _session == null:
		return {}
	var 条 := _quest_by_id(str(编号), _session.accepted_quests)
	if (条.get("dynamic_data", {}) as Dictionary).is_empty():
		return {}
	var 定: Dictionary = _session.合并任务定义(条, GAME_DATA.取表("任务").get(str(编号), {}))
	return 日环任务窗.构造数据(条, 定, int(_session.player_stats.get("job", 0)))


func _环任务开始(数: Dictionary) -> void:
	var HUD := get_tree().get_first_node_in_group("game_hud")
	if HUD != null:
		if int(数.get("status", 0)) == 2:
			HUD.前往NPC(int(数.get("endNpcId", 0)))
		else:
			HUD._于提示条确定(0, int(数.get("questId", 0)))
	close()


## 静音「勾玉炼制」（动作 17）。这一页**没有运行期数据可喂**：三页签的静态件（投料框/说明/材料格）
## 全在 AS3 `createChildren` 里建，图标与消耗数要等投料 + 服务端回帧 ⇒ 本地就是全静态件 + 空格。
## ⚠ 原版开窗走 `UIMain2.as:3848-3866` 的 `centerTwoWindow(这扇, ITEM_WINDOW2_F)` ⇒
##   由 `窗口管理.gd` 的 `伴随背包` 负责连背包一起开并成对摆位，这里不管位置。
func _render_jade() -> void:
	# 从背包物品菜单带进来的那件**只喂一次**：原版 `showWindow:88` 存 `_item`、
	# `selectedBtnHandler:96-98` 装到新页后立刻置 null ⇒ 再开一次不会在三页里都长出图标。
	var 带入 := _jade_item
	_jade_item = {}
	勾玉炼制窗.渲染(self, 勾玉炼制场景, 带入, _刚开窗)


## 志乃「护送任务」。这页的静态件（三块面板 / 等级条底 / 五枚奖卡格 + 名 + 选中框 /
## 双倍说明 / 规则钮 / 四行奖励标签 / 两颗钮 / 「为止」）全在 AS3 `createChildren` 里建、
## 已烘进场景 ⇒ 运行期只补原版也是运行期长的四件：复选项、下拉、规则 tooltip、两颗钮的行为。
## ⚠ 六处数字（当前等级 / 时间 / 经验 / 精华 / 气血 / 剩余免费刷新）只在
##   `updateview(:286-310)` 由 MIXIN 2325 状态帧填 ⇒ 本地直开是空态，一个都不假造。
func _render_escort() -> void:
	护送任务窗.渲染(self, 护送任务场景)


## 护送提示弹（双倍活动）。两块静态件全在场景里 ⇒ 控制器只管那颗「前往护送」。
func _render_escort_notice() -> void:
	护送任务窗.渲染提示(self, 护送提示场景)


## 鸣人「跨服频道」。32 枚频道格**全烘在场景里**（原版 `setData` 先给每枚一个 int ⇒
## 离线就是「跨服频道 0N（维护）」灰禁用，这是原版真身、不是空态占位）。
## 运行期只有「哪几枚有数据」来自 `1825:0` 那一帧 ⇒ 未接，`填数` 只给门/量具喂夹具用。


## 鸣人「跨服频道」。32 枚频道格**全烘在场景里**（原版 `setData` 先给每枚一个 int ⇒
## 离线就是「跨服频道 0N（维护）」灰禁用，这是原版真身、不是空态占位）。
## 运行期只有「哪几枚有数据」来自 `1825:0` 那一帧 ⇒ 未接，`填数` 只给门/量具喂夹具用。
## 竞技场主窗（原版 `PvpWindow` 770x567）。五枚候选格 + 五条战报行**全烘在场景里**（逐件出处 = `真值/窗口/竞技场.md` §11），回帧只切 visible + 换文字，**绝不拆页重建**（同一族坑见 #312）。
## 状态挂在 `竞技场窗` 的 static 上 = 原版单例 `PvpManager`，换图/关窗都不清。
func _render_arena() -> void:
	竞技场窗.渲染(self, 竞技场场景)


## 英雄榜（`PvpRankWindow` 380×400）：主窗左下「查看英雄榜」那一行开过来。
func _render_arena_rank() -> void:
	竞技场英雄榜窗.渲染(self, 竞技场英雄榜场景)


func _render_kuafu_channel() -> void:
	跨服频道窗.渲染(self, 跨服频道场景)


## 阿凯「生命料理」（动作 15）。12 件全静态（三枚格离线就是空格 + 一个空格，
## 原版 `hideIcon` 那条口径），控制器只接两颗钮 + 按金币换那个 2000 的颜色。
func _render_liaoli() -> void:
	生命料理窗.渲染(self, 生命料理场景)


## 三代火影「洗点」（动作 26）。四行的加减是**纯本地状态机**（原版也不发帧，
## 直到确认弹的「确定」）⇒ 交互面全照搬 `WashPointWindowCell.as:43-122`。
func _render_wash_point() -> void:
	洗点窗.渲染(self, 洗点场景)


## 洗点族第二扇 = 确认弹（`WashPointConfrimWindow`）。两段文案是运行期数据
## （四项点数 + 总和 + 洗点卷数）⇒ 场景烘空件，这里按逐字模板填。
func _render_wash_confirm() -> void:
	洗点窗.渲染确认(self, 洗点确认场景)

## 双修邀请窗（`YaoqingShuangxiuWindow`）。**这一页的数据不是开窗时发的请求给的**，
## 是服务端推的一帧：`1288:2:<邀请者号>` ⇒ `authoritative_heal.pending_inviter_id`。
## 所以"号"要**记在宿主身上**：回帧引起的重渲染（换心法、连斩…）没有新的 2 帧，
## 每次都去读 pending 会在第二帧之后就取不到 ⇒ 窗自己消失。
## 查不到那个人（不在同屏表）⇒ 整页不建，宁可不出现也不弹一扇四行全空的窗。
var _双修邀请号 := 0


func _render_shuangxiu_invite() -> void:
	if _backend == null:
		return
	if _双修邀请号 <= 0:
		var 状: Dictionary = _backend.get("authoritative_heal") as Dictionary
		_双修邀请号 = int(状.get("pending_inviter_id", 0))
	var 态: Dictionary = (_backend.get("map_players") as Dictionary).get(_双修邀请号, {}) as Dictionary
	if _双修邀请号 <= 0 or 态.is_empty():
		_双修邀请号 = 0
		return
	双修邀请窗.渲染(self, 双修邀请场景, _双修邀请号, 态)


## 同意/取消/被拒/真的开始双修 ⇒ 关窗**并把记住的邀请者号清掉**，
## 否则下一次别人的邀请会被填进上一号的缓存里。
func 关掉双修邀请() -> void:
	_双修邀请号 = 0
	close()

## 族邀（原版 `MPromptWindow.popupHasPlayerInfoWindow`）。和双修那一页同一个形状：
## **开窗的是服务端推的那一帧**（`1552:16:…`），但**开窗动作发生在"点了头顶那一格"之后**
## （`FamillyManager.onAcceptFamillyInvite:339-343` 塞格 → `inviteHandler:235-239` 才弹），
## 所以数据由 `窗口管理._on_托盘已点` 用 `set("_家族邀请", …)` 灌进来，这里只读缓存。
## ⚠ 缓存清与不清：点「同意加入/拒绝」或点右上角叉都要清（原版 `onCloseBtnClick:140-144` 只是
## `removeWindow`，**不发拒绝帧**）；不清的话下一次再开这页会拿上一任族长的名字填。
var _家族邀请: Dictionary = {}


func _render_家族邀请() -> void:
	if _家族邀请.is_empty():
		return
	# 同一扇窗两档（`_apply_original_window` 已按尺寸表写过「邀请入族」）：
	# 审核档标题 = 「申请入族」（`applyHandler:129` 的 `param3`），两串都是 4 个汉字 ⇒ 宽度不变。
	设置标题(家族邀请窗.申请标题 if bool(_家族邀请.get("是申请", false)) else 家族邀请窗.标题)
	家族邀请窗.渲染(self, 家族邀请场景, _家族邀请)


func 关掉家族邀请() -> void:
	_家族邀请 = {}
	close()

## 求婚窗（原版 `ProposalWindow`，页名「羁绊申请」）。**两档共用一扇**：
## 发起档的数据 = `61:14`（我点菜单「羁绊」⇒ 服务端回对面那份资料 ⇒ **直接开窗**）；
## 被求档的数据 = `61:17`（⇒ 只塞头顶托盘那一格 ⇒ **点那一格**才开窗，`是被求 = true`）。
## 缓存里那位 `item`（对戒号）会被 `放入钮` 改写 ⇒ 关窗必须整份清掉，
## 否则下一任求方会带着上一任那枚对戒的图与号（同 `_双修邀请号` 那条坑）。
var _求婚: Dictionary = {}


func _render_求婚窗() -> void:
	if _求婚.is_empty():
		return
	求婚窗.渲染(self, 求婚场景, _求婚)


func 关掉求婚窗() -> void:
	_求婚 = {}
	close()

## 赠花窗（原版 `MarryZengHuaWindow`，页名「赠花」，#88 / 原报修 #263）。
## 数据**两半**：`对面` = 点菜单那一刻存的号/名/脸/级（存在 `窗口管理._赠花对面`），
## `档` = 回帧 `58:2` 解出来的 `authoritative_flower`（友好度/统计/五条记录/三档花全在这半）。
## ⇒ 开窗的是**回帧**，不是点击（`窗口管理._on_花档帧`），所以缓存为空时**什么都不画**：
## 门可以直接 emit 一帧来灌，也可以先开窗再灌。关窗把整份清掉，别留上一任对面的友好度。
var _赠花: Dictionary = {}


func _render_赠花窗() -> void:
	if _赠花.is_empty():
		return
	赠花窗.渲染(self, 赠花场景, _赠花)


func 关掉赠花窗() -> void:
	_赠花 = {}
	close()

## 随身摊位窗（`StallWindow`，看别人摊 = 买家档）。和双修那一族同一个形状：
## **数据是服务端推的一帧** `1296:1:<摊主号>:<摊主名>:<摊名>:<行表>:<日志>`
## ⇒ `后端连接.authoritative_stall` + `stall_state_received`，消费者在 `窗口管理._on_stall_state`。
## 买成之后服务端会**再推同一条** `1296:1:`（那一行已经不在表里了）⇒ 走 `重灌`，不重建整页
## （原版也只有 `stallWindow` 这一个实例被 `setStall` 重新灌，`StallDataManager.as:36-37`）。
## ⚠ 逐页状态全放这里的**具名变量**上，不放 `set_meta`：Godot 4 的 metadata 键要求合法标识符，
## 中文键会静默存不进去（工程已栽过）。
var _摊位页: Control = null
var _摊位桶: Dictionary = {}
var _摊位行们: Array = []
var _摊位页序 := 0
var _摊位选中 := -1
var _摊主号 := 0
var _摊主名 := ""


func _render_stall() -> void:
	if _backend == null:
		return
	var 态: Dictionary = _backend.get("authoritative_stall") as Dictionary
	if 态.is_empty():
		return
	摊位窗.重灌(self, 摊位场景, 态)


## 摊位列表（`controls/stall/StallListWindow`，474×378）。同「随身摊位」相反的一族：
## **这扇窗是点击开的**（`UIMain2.as:4568-4576` → `init():152-156` = `loadPage(0)`），
## 回帧 `1296:0:<总数>:<行表>` 只负责**灌表**（`StallDataManager.as:88-94` 就一句
## `if (stallListWindow) setPageData(...)` ⇒ 窗没开就什么也不做）。
## ⚠ 因此**不能照 `_render_stall` 那样"空态 return"**：一条摊都没有时页照样在台上，
## 只是列表空着 + 「总数：0」+ 四枚翻页钮灰着（原版的数），return 会让玩家对着一片黑。
## 逐页状态同样放**宿主具名变量**（`set_meta` 的中文键会静默存不进去）。
var _摊位列表页: Control = null
## `{总, 行, 页, 请页, 快序, 词, 载, 选}` —— 形状与算法都在 `摊位列表窗.gd`，见 `空态()`。
var _摊位列表走: Dictionary = 摊位列表窗.空态()
var _摊位列表行们: Array = []
var _摊位列表下拉: Control = null
## 下拉当前显示的**序号**（`_searchBox.selectedItem`，只有玩家点菜单才改）。
## ⚠ 和 `_摊位列表走["快序"]`（**已提交**的那一份，= 原版 `_quickKey`）是两份：
## 原版「刷新」把后者强塞回 1、却不碰前者 ⇒ 显示与实际并不同步，这两份必须分开存。
var _摊位列表快序 := 0


func _render_stall_list() -> void:
	摊位列表窗.渲染(self)


## 回帧入口（`窗口管理._on_stall_list` 判过"这扇窗在台上"才调进来）。
func 灌摊位列表(总: int, 行表: Array) -> void:
	摊位列表窗.灌入(self, 总, 行表)


## 购买确认窗（`StallUpShelfWindow` 的 `BUY_OPERATION` 档）。数据 = 点「购买」那一刻
## 存进 `摊位窗.待买` 的那条挂牌（**脚本级静态**：确认弹和摊位窗是两个 `功能窗口` 实例，
## 存在实例上这一侧读不到那一侧 —— 同 `洗点窗.gd` 的 `_还原`/`_基数`）。
func _render_stall_buy() -> void:
	if 摊位窗.待买.is_empty():
		return
	摊位购买窗.渲染(self, 摊位购买场景, 摊位窗.待买)


## 上架确认窗（同一个 `StallUpShelfWindow` 的 `WUPING_UP_OPERATION` 档 ⇒ 复用同一份场景）。
## 数据 = 摊主把物品从背包**拖到摊位内容区**那一刻存进 `摊位窗.上架单` 的那件
## （脚本级静态，理由同 `待买`：这扇窗和摊位窗是两个 `功能窗口` 实例）。
## ⚠ 原版这档是 `centerWindow` 的**居中弹**，而「拖上去」的瞬间主窗并不关 ⇒ 两扇叠着；
## 本工程用 `窗口管理.居中弹` 表达同一效果，见 `窗口管理.gd:402`。
func _render_stall_up() -> void:
	if 摊位窗.上架单.is_empty():
		return
	摊位购买窗.渲染上架(self, 摊位购买场景, 摊位窗.上架单)


## 附身宠物选宠窗（`SuiShenPet`，193×190 小背景）。一扇窗两个用途：
##   · 摆摊档 = 摊位窗第 1 页「宠物列表」开它（`_附身用途 = "摆摊"`）；
##   · 交易档 = 交易窗「宠物列表」开它（`"交易"`，默认）。
## 逐页状态挂宿主具名变量（**不用 `set_meta`**：中文键在 Godot 4 里静默存不进去）。
var _附身用途 := "交易"
var _附身选中 := -1
var _附身上架钮: Button = null
var _附身行们: Array = []


func _render_附身宠物() -> void:
	附身宠物窗.渲染(self)


## 货币上架窗（`UpShelfMoneyWindow`，251×168）。入口 = 摊位窗第 2 页「货币上架」，
## 点「上架」发 `1296:8:` 后自己关窗（`UpShelfMoneyWindow.as:95`）。
var _货币上架页: Control = null
## `0` = 卖金币（标价用元宝）、`1` = 卖元宝（`UpShelfMoneyWindow.as:92-93`）。
var _货币类型 := 0


func _render_货币上架() -> void:
	货币上架窗.渲染(self)


## 交易窗（`TradeWindow2`）。同「随身摊位」那一族的形状：
## **窗是服务端推帧推出来的** —— 双方任一接受邀请 ⇒ `335:22` ⇒ `trade_started`
## ⇒ `窗口管理._on_trade_started` 开这页；此后每一次出价/放物/锁定都会重放一整轮快照
## （`_broadcast_trade_snapshot`）⇒ 一律走 `重灌`，不重建整页
## （原版也只有 `tradeWindow` 一个实例被反复 set）。
## 逐页状态只有「页」本身 —— 交易的数据全在 `后端连接.authoritative_trade` 上，
## 不在宿主里再存一份副本（存两份迟早和回帧打架）。
var _交易页: Control = null


## 控制器要读当前交易态（`交易窗._设钮态` 用它判两块遮罩）。
func _交易态() -> Dictionary:
	if _backend == null:
		return {}
	return _backend.get("authoritative_trade") as Dictionary


func _render_trade() -> void:
	if _backend == null:
		return
	var 态: Dictionary = _交易态()
	if not bool(态.get("active", false)):
		return
	交易窗.重灌(self, 交易场景, 态)


## 神秘商店（`controls/mystery/MysteryWindow`，275×394）。同「随身摊位 / 交易」那一族形状：
## **窗是服务端那一帧 `324:` 推出来的** —— 背包底部那颗钮只发 NPC_SHOP 动作 6
## （`MysteryManager.requestOpenMystery` 全文没有一句 `showWindow`），回帧经
## `后端连接.mystery_shop_received` → `窗口管理._on_mystery_shop` 才开这一页。
## 等级 < 25 时服务端**只发一句系统聊天、不发 324**（`fake_flash_server.py` 动作 6/8 那道闸）
## ⇒ 点了没窗是原语义；买成与手动刷新都会再推一整帧 ⇒ 一律 `重灌`
## （原版 `receiveRefItem:38-45` 也是"窗已存在 ⇒ 只 `updateview`"）。
## ⚠ 空态直接 return：`_render_page` 已经清过 `_content`，这里不建页 = 窗里一片空白，
##   而 324 从没到过的时候本来就不该有这扇窗（不会有"空白窗"被人当成坏了）。
var _神秘商店页: Control = null
## 秒表跨重建的状态（`{剩, 文, 跑完}`）。**必须挂在宿主上、不能挂在页上** ——
## `_render_page` 每轮把 `_content` 的子件全摘掉重建，页里的 Timer 一起没了。
var _神秘商店走: Dictionary = {}


func _render_mystery_shop() -> void:
	if _backend == null:
		return
	var 态: Dictionary = _backend.get("authoritative_mystery_shop") as Dictionary
	if 态.is_empty():
		return
	神秘商店窗.重灌(self, 神秘商店场景, 态)


## 木叶丸「徽章打造」（动作 13）。两页 pane 的件**逐件不同**（绿白两块文字的颜色
## 与 x 偏移 +2/+3 都不一样）⇒ 全烘在场景里，运行期只有切页换「确定」钮文字。
func _render_beast_badge() -> void:
	徽章打造窗.渲染(self, 徽章打造场景)

## 打坐时技能栏上方那颗「心法」球 ⇒ 原版 `com/mxw/uifl/controls/XinfaWindow`（275×295，
## 标题「修炼心法」）。开窗链路照原版：点球 ⇒ 只发 `86:7` 查询当前修炼的心法
## （`UI.as:649-652 openXinfaWindow()` 里唯一一句 = `Client.requestXinfaShow()`），
## 回帧 `1288:3:<id>` 才填主格（`Client.as:8033 onDefaultXinfaId`）。
## ⚠ 原版是**收到回帧才建窗**，本工程 `功能窗口` 是点开就建 ⇒ 回帧走 `_refresh_current()`
## 重渲染这一页来填主格（同一句话只发一次，见 心法窗.gd 的闸门，否则发包↔刷新成环）。
func _render_xinfa() -> void:
	心法窗.渲染(self, 心法场景)




## 外框尺寸（`窗口管理` 算「成对摆位」要用：主窗宽 + 背包宽 + 1 决定整对怎么居中）。
func 取窗口尺寸() -> Vector2:
	var 主窗 := get_node_or_null("遮罩/主窗口") as Control
	return 主窗.size if 主窗 != null else Vector2.ZERO


## 当前相对"居中位置"的偏移（窗口管理用来记住位置）。
##
## 窗口的位置是相对**父节点（遮罩）中心**的，而遮罩铺满视口 → 父中心就是视口中心，
## 所以"距居中的偏移"就是 `offset_left + size.x/2`。
##
## ⚠️ 原来这里还多减了一个 `视口/2`，于是居中时返回的是 (-480,-280) 而不是 (0,0) ——
##    `打开或收起` 把它记进 `_记住的位置`、`打开()` 再喂回 `窗口偏移`，整个偏掉一大截。
##    两个函数本该互为逆运算，这条契约现在由 `测试/窗口行为契约体检.gd` 的 B 组钉住。




## 「购买」的**统一出口**。原版凡是 `CashShopWindowEvent.REQUEST_CASH_ITEM_INFO` 那一跳都走它：
##   · 扩容窗 `EnlargeWindow.onClickBuy:169-174`（`id = 密卷id`）
##   · 材料格 `ItemCaiLiaoBox.buyHandler:46-55`（`id = itemCell.itemData.id`）—— 共用的那枚小格，
##     勾玉炼制的「材料4」、通灵驯养的材料格、徽章打造、精炼、`MPromptWindow` 的提升弹窗都用它
##   · 副本密卷 `FubenLingWindow.as:209` / 改名 `ChangeNameWindow.as:305` / `EquipManager.as:99`
## ⇒ 1086 只发一个字段、那个字段就是**物品 id**（`后端连接.gd:869-876` 已核实）。
## 回包 1079 由 `打开商城购买窗` 接（2026-10-11 接上，之前**没有消费者**）。
func 请求商城商品(物品id: String) -> void:
	var 后端 = _backend
	if 物品id.is_empty() or 后端 == null or not 后端.has_method("request_cash_item_info"):
		_通知("购买：未连接服务端")
		return
	_等1079 = true		# 举旗在发之前：回包只由**这一扇**接（见 `_等1079` 那条注释）
	## 同时把归属写到管理节点上：1079 是广播，旗在 handler 里会被先接信号的那扇清掉，
	## 后接的那扇就看不出"谁问的"了（`窗口管理._购买申请者` 有实测记录）。
	var 管 := get_parent()
	if 管 != null and 管.has_method("收起其他购买窗"):
		管.set("_购买申请者", self)
	if not 后端.request_cash_item_info(int(物品id)):
		_通知("购买：商城信息请求发送失败")
	# 发成功**不提示**：回包 1079 一到，`打开商城购买窗` 会把购买窗弹出来（原版同口径）。

## 改名（原版 MDialog.showInputDialog + maxChars 12 + `__conChangeName` 空名拦截）。
## 改名（原版 `onOpenStudyWindow:654-659` + `__conChangeName:741-755`）。
## 走**输入型确认弹**（`MDialog.showInputDialog` 的移植，302 宽那只）而不是
## 早先自造的 `_弹出输入`：那只几何不是原版。预填当前名 + 全选 + `maxChars=12`。
## ⚠ 空名那条原版弹的是 `PETWINDOW_CHANGE_NAME_OPERATION_PROMPT_1`，而语言表里
##    这个键的值是「该通灵兽已经出战！」—— **上游复制粘贴错的串**。
##    照抄会让玩家莫名其妙，所以这里保留「名字不能为空」，抓错记录登记在 §8 第 12 行。


## ── 二级密码六窗（`controls/twoPassword/*`，#48，真值 `真值/窗口/二级密码.md`）─────
##
## 六扇都**没有场景**：整页就是一张几何表，逐件矩形抄在 `二级密码窗.gd` 的 `窗件*` 六张表里
## （口径同 摊位列表/神秘商店）。`数据/界面/窗口尺寸.json` 那六条全是 `整框: true` +
## `内容底: false` —— 六个构造**都没传第三参** ⇒ 宿主不画内容底板，页里自己
## `MYellow_background` + `MPane_background`（`UIWindow.as:28-44`）。
##
## ⚠ 分工：本宿主只管**画**（`_render_second_password` 建页、`刷二级密码` 重画）；
##   开哪一扇、关哪一扇、弹哪一句，全在 `窗口管理._on_second_password`（那儿才有窗表），
##   上行判式全在 `二级密码窗.gd` 的那十条 `_点*`。
## ⚠ 逐页状态放**宿主具名变量**（`set_meta` 的中文键会静默存不进去）。
var _二级密码页: Control = null
## 三格当前那一档（0 设置 / 1 确认 / 2 删除）= 原版 `SetPasswordPane3.pane_Type`。
## 存在宿主上、**不存脚本静态**：脚本级那份是给"跨六扇窗共享的草稿"用的，档是这一页自己的。
var _二级密码问题型: int = 0
## `MComboBox` 那两枚问题菜单弹出来的面板（挂在 `_overlay` 上 ⇒ `close()` 里得自己收掉）。
var _二级密码下拉: Control = null


## `_render_page` 那六条臂的公共出口。`页名` == `_current_page` == 尺寸表的键。
func _render_second_password(页名: String) -> void:
	if 页名 == 二级密码窗.页说明:
		二级密码窗.渲染说明(self)
	elif 页名 == 二级密码窗.页一格:
		二级密码窗.渲染一格(self)
	elif 页名 == 二级密码窗.页二格:
		二级密码窗.渲染二格(self)
	elif 页名 == 二级密码窗.页三格:
		二级密码窗.渲染三格(self)
	elif 页名 == 二级密码窗.页修改:
		二级密码窗.渲染修改(self)
	else:
		二级密码窗.渲染解锁(self)


## 回帧的**重画**那一半（= 原版那几处 `xxxWindow.updateView(...)`）。
## `档` 只有三格那一页吃（0/1/2）；其余四页原版根本没有 `updateView` 的参数。
## ⚠ 二格、解锁**不在这里**：`SetPasswordPane2/UnchainLookWindow` 全类没有 `updateView`
##   （二格只 `initWindow:163-168` 回填草稿，解锁的 `onCloseBtnClick:42-49` 反而清草稿）。
func 刷二级密码(档: int = -1) -> void:
	if _固定页 == 二级密码窗.页三格:
		二级密码窗.刷三格(self, 档)
	elif _固定页 == 二级密码窗.页说明:
		二级密码窗.刷说明(self)
	elif _固定页 == 二级密码窗.页一格:
		二级密码窗.刷一格(self)
	elif _固定页 == 二级密码窗.页修改:
		二级密码窗.刷修改(self)


## 竞技场那枚「你需要选择无需挑战直接查看结果吗？」= 原版**双钮 + 今日不再提示**
## （`PvpPlayerPanel.as:70-86` → `FamillyPopUpWindow.popUpWindow(..., "挑战", ..., "查看结果", ...)`）。
## `弹双钮` 的回调只分「第一颗 / 其余」两支，所以这里自己回读勾选值，再分别喂给两个回调。
func 弹出双钮确认(正文: String, 钮一: String, 回调一: Callable, 钮二: String, 回调二: Callable,
		勾选文字: String) -> void:
	var 层: Control = null
	层 = 输入确认弹.弹双钮(_overlay, 正文, 钮一, 钮二, 勾选文字, func(v: Variant) -> void:
		var 勾值 := false
		if 层 != null:
			var 勾 := 层.get_node_or_null("主体/勾选") as CheckBox
			if 勾 != null:
				勾值 = 勾.button_pressed
		if v == null:
			回调二.call(勾值)
		else:
			回调一.call(勾值))


## 原版 `MDialog.showCheckBoxDialog(正文, false, 回调, 今日不再提示)`
## （清CD `:279-288`、加次数 `:226-235`）⇒ 单颗确定 + 一行勾选。
func 弹出勾选确认(正文: String, 回调: Callable) -> void:
	输入确认弹.弹勾选(_overlay, 正文, "今日不再提示", false, 回调)

## 一颗居中的「确定」= 家族弹窗把取消藏掉那一档（`hideCancelButton`）。
## 竞技场「本期排名奖励获得」用它（`PvpManager.as:98-103`）。回调什么都不做：
## 原版那条 `popUpWindow(文案, null, null, "", null, "", false)` 的 `okFun` 传的就是 null。
func 弹出单钮确认(正文: String) -> void:
	输入确认弹.弹单钮(_overlay, 正文)
