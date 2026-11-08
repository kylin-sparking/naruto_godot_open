extends RefCounted
## 秘笈合成页（原版 `com/mxw/uifl/controls/equip/JiNengCompositeWindow.as` 340×381，一个页签）。
##
## 从 `功能窗口.gd` **切出来单独成件**（2026-10-03，与 `首领窗口.gd` / `宝石工艺窗口.gd` 同一条理由）：
## 那份控制器 `preload` 了十几张场景 ⇒ 交包时要么把不相干的页一起拖走、要么在融合方那边
## `preload` 编译失败。切出来之后本包只带这一份控制器 + 一张场景。
##
## ⚠ **这里不摆样式、不摆控件**：31 个节点全烘在 `.tscn`（由 `开发工具/生成秘笈合成场景.py`
## 从量具表 `截秘笈合成页.gd` 生成 ⇒ 改真值改量具表再重跑生成器，别手改场景）。
## 旧版在这里对每个文本 `_configure_label(..., 10, ...)` 重设字号颜色、`_configure_original_panel`
## 重设皮、运行期 `load(ORIGINAL_SLOT)` 给六个格子补图 —— 那正是"编辑器里看到的和实机不是同一套"
## 的病根（量具按 12px 量、运行期被改成 10px；格皮编辑器里根本看不见）。逐件出处
## `真值/窗口/秘笈合成.md`。
##
## **协议面（2026-10-03 深夜接通 `CAN_JUAN_ACTION 1352`，本页由纯美术升级为真窗）**：
##   放入 = **背包拖放**（原版 `CursorManager` 光标式拖拽，本工程沿用 §3.86 宝石放入格同族
##   内置拖放：`残卷放入格.gd` 只收有配方（`canjuan_book`>0）的背包件，落点直接拒非残卷。
##   ⚠ **§3.308 补**：这条组件走 `宝石放入格` 同款 `super._can_drop_data`，而那道闸要求
##   **页面给落点认领 `格子归属`**（`功能窗口.gd:2897` 宝石那条一直填着、这页切件时漏了
##   ⇒ 拖放整个死在闸一）。`徽章/勾玉/昆虫/修复放入格` 四族不调 super 所以没这问题——
##   照抄判据前先看清闸在哪个文件）；
##   提交 = 校验四步后 `游戏会话.合成秘笈(格, 张数)` → `后端连接.request_can_juan_compose`
##   （`0:<unique_id>:<张数>`，原版 `writeByte+writeDouble+writeInt` 的 text 等价）；
##   结果 = `1352:0:<0/1>`（原版 `operationResultHandler:342` **只在 true 刷新**，失败不弹话）。
##   校验四步逐字照 `upgradeHandler:147-170` + `validateXinYunJing:137-145`（见 `_提交`）。
##   「购买」2026-10-11 接上了：原版发 `CashShopWindowEvent.REQUEST_CASH_ITEM_INFO`
##   （`ItemCaiLiaoBox.as:45-53`）⇒ 走 `功能窗口.请求商城商品`（§3.125 那条链）。
##   「放入残卷」钮 **§3.308 实装**：照 `clickDropBtnHandler:326-340` 三分支——已放入⇒取出、
##   空袋⇒原版空态话、没放⇒原版是 `UpShelfCursor` 光标收集态（本工程无跟手件）**按用户点名**
##   （「也不能点放入秘籍选择对应秘籍残卷」10-28）改成游标处弹**残卷选择清单**、点一条即放入（偏离原版，用户授权）。
## ⚠ 几率显示按表（prob=25），**夹具掷骰基率硬编码 30**（`handle_can_juan_action`），两边不同源——
##   在线门只钉结果 0/1 与消耗，不钉几率值（差异记 §3.90.6）。

const 秘笈合成场景 := preload("res://场景/界面/窗口/秘籍合成/秘籍合成窗口.tscn")

## 原版空态提示：`upgradeHandler:149-152` 在没放主残卷时
## `addNotice(CN.replaceString(EQUIP_STRENGTH_FAIL_PROMPT_6[0], CN.EQUIP_STRENGTH_FAIL_PROMPT_6[3]))`
## = 「请放入%1！」(`:1925`) 填「忍术残卷」(`:1919`) ⇒ 逐字来自语言表，不是编的句子。
## （GDScript 的 `const` 不许是表达式 ⇒ 这里直接落拼好的值，两个键名留在上面的算式里。）
const 空态提示 := "请放入忍术残卷！"
## ②残卷不够：`EQUIP_STRENGTH_FAIL_PROMPT_14`「对不起，秘笈合成至少需要%1个忍术残卷！」
const 缺残卷模板 := "对不起，秘笈合成至少需要%1个忍术残卷！"
## ③精华不够：`EQUIP_STRENGTH_FAIL_PROMPT_2[0]` 填 `[2]` ⇒「很抱歉，你的查克拉精华不够」
const 缺精华 := "很抱歉，你的查克拉精华不够"
## ④幸运符不够：`EQUIP_STRENGTH_FAIL_PROMPT_2[0]` 填 `getItemString(helpItemId)`＝道具表名字
##   （16000015《幸运符》）⇒「很抱歉，你的幸运符不够」
const 缺幸运符 := "很抱歉，你的幸运符不够"
## 非残卷落点被组件拒后，页面兜的拒话 = `EQUIP_STRENGTH_FAIL_PROMPT_4[0]` 填 `[4]`
##   「对不起，该物品不是%1」+「忍术残卷」⇒ 逐字拼好（`validateItem:373` 的 MDialog 同句）。
const 非残卷 := "对不起，该物品不是忍术残卷"
## 说明行模板 = `EQUIP_STRENGTH_DESC_TEMPLATE_1`（原文带 `<font color='#ffffff'>`，
## 占位 ￥=消耗精华、$=成功几率）；zq 不够时 ￥ 换红（`:388`）。
const 配置路径 := "res://数据/界面/秘笈合成配置.json"

static var _宿主
static var _放入格 := -1			# 主残卷来源背包格号（1 基，`slot_index`）；-1 = 没放
static var _页面: Control			# 当前页根（结果帧回来时刷视图要用）
static var _选择器: PopupMenu = null	# 「放入残卷」的残卷选择清单（原版 UpShelfCursor 的等价通道）
static var _选择清单: Array = []		# 与 _选择器 行号对齐的 [{格,id,名称,数量}]

## 四枚 `材料格`（原版 `_fu1.._fu4`，都是 `ItemCaiLiaoBox`）。
const 材料格路 := ["内容框/材料格1", "内容框/材料格2", "内容框/材料格3", "内容框/材料格4"]
const 数量名 := "数量"
const 灰度着色器 := preload("res://脚本/界面/组件/禁用灰度.gdshader")
static var _灰材质: ShaderMaterial = null


static func 渲染(宿主) -> void:
	_宿主 = 宿主
	_页面 = _宿主._instantiate_page(秘笈合成场景)
	# 四枚材料格 + 主残卷格在原版都是带 `itemCell` 的件（`ItemCaiLiaoBox.as:128` /
	# `ItemDropBox`），`JiNengCompositeWindow.as:107-122` 给每枚填 `itemData`
	# ⇒ `SimpleItemCell.as:220` 自动挂 MToolTipItem。场景是烘出来的，提示框运行期挂
	# （同勾玉炼制/宝石镶嵌那几页）。
	_宿主._给页挂提示框(_页面)
	# 一、页签：原版只有 1 枚且 `selectedIndex=0` 在 `createChildren` 末尾设过（`:275`）
	#   ⇒ 常亮、不需要处理函数（`控件矩形转储.gd` 也记过这条），所以这里**不接 pressed**。
	# 二、放入残卷格 = 拖放落点（`残卷放入格.gd` 发 `请求放入(格)`）；信号一参处理也一参
	#   （§3.85.5 arity 教训）。落上换按钮文案「取出残卷」（`:363` DROP_ITEM_BTN_NAMES[3]）。
	(_页面.get_node("内容框/放入残卷区/主残卷格") as Button).pressed.connect(_取回残卷)
	_挂放入信号()
	# 三、「放入残卷」= 原版 `clickDropBtnHandler` 三分支（取出 / 空态话 / 弹残卷选择清单）。
	(_页面.get_node("内容框/放入残卷区/放入残卷") as Button).pressed.connect(_点放入钮)
	# 「购买」= 原版 `ItemCaiLiaoBox.buyHandler:45-53` 那跳 `REQUEST_CASH_ITEM_INFO`
	# （`id = itemCell.itemData.id`）⇒ 走 `功能窗口.请求商城商品` 统一出口（§3.125 那条链）。
	# 材料格4 = 合成用的帮手道具 `Etc.CanJuanHeCheng.help_item` = 16000015（本窗 `配置路径` 里那项）。
	var 帮手id := int(_配置().get("help_item", 0))
	(_页面.get_node("内容框/材料格4/购买") as Button).pressed.connect(
		 func() -> void: _宿主.请求商城商品(str(帮手id)))
	(_页面.get_node("开始合成") as Button).pressed.connect(_提交)
	_接幸运符(_页面)
	# 四、结果帧**只连一次**（会话是常驻单例，每次开页都 connect 会越叠越多——提示节点同款教训）。
	if not _宿主._session.can_juan_result.is_connected(_于结果):
		_宿主._session.can_juan_result.connect(_于结果)
	_刷视图()


## 给落点组件接拖放信号。每次开页都是新节点 ⇒ 先摘旧连再连新（同 §3.86 `_宝石合成格` 做法）。
static func _挂放入信号() -> void:
	var 落点 := _页面.get_node("内容框/放入残卷区/主残卷格") as Button
	# ⭐ **§3.308 病根**：`残卷放入格` 与 `宝石放入格` 同款走 `super._can_drop_data`，
	#   那道闸第一句就是 `格子归属.is_empty() ⇒ 拒`。宝石那页在 `功能窗口.gd:2897` 认领了落点，
	#   本页 10-03 切件时漏了这一行 ⇒ **从背包拖什么进来都弹回**（用户 10-28 报修）。
	落点.格子归属 = "残卷放入"          # 认领落点（`可拖拽格._can_drop_data` 要求非空）
	落点.可拖拽 = false                 # 原版这格只接不吐（`ItemDropBox.itemCell` 无起拖监听）
	# 每次开页都是新节点，`is_connected` 恒 false；这道护栏防的是"同一页根被重复挂"。
	if not 落点.is_connected("请求放入", _落入):
		落点.请求放入.connect(_落入)


static func _落入(残卷格: int) -> void:
	# 落上**不是残卷**（有配方判据在组件）时组件已经拒了；这里只会收到合格件。
	_放入格 = 残卷格
	_刷视图()


static func _取回残卷() -> void:
	# 原版按钮态语义：放入后这颗变「取出残卷」，点一下回背包（不发协议，本地格位还原）。
	if _放入格 > 0:
		_放入格 = -1
		_刷视图()


## 每次渲染按格位**现读**（§3.86 `_宝石合成现读` 同策）：换件、空了、被服务端消耗了都自动跟进。
static func _放入现读() -> Dictionary:
	if _放入格 <= 0:
		return {}
	for 件 in _宿主._session.inventory:
		if typeof(件) == TYPE_DICTIONARY and int((件 as Dictionary).get("slot_index", 0)) == _放入格:
			if 残卷放入格类.有配方(String((件 as Dictionary).get("id", ""))):
				return 件 as Dictionary
			return {}
	return {}


const 残卷放入格类 := preload("res://脚本/界面/组件/残卷放入格.gd")
const 放入选择器 := preload("res://脚本/界面/组件/放入选择器.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")


## 原版 `updateView:377-398` + `updateXingYunRatio:392+`：
## 说明两行 = 消耗精华 `need_zq`（zq 不够换红）、几率 `prob + 张数×3`；空态全 0。
static func _刷视图() -> void:
	if _页面 == null or not is_instance_valid(_页面):
		return
	var 配置 := _配置()
	var 行 := _放入现读()
	var 有: bool = not 行.is_empty()
	var 需精华 := int(配置.get("need_zq", 0)) if 有 else 0
	var 张数 := _选中张数() if 有 else 0
	var 几率 := int(int(配置.get("prob", 0)) + 张数 * int(配置.get("ratio", 3))) if 有 else 0
	var zq: int = int(_宿主._session.player_stats.get("zq", 0))
	var 精华串 := str(需精华)	# ⚠ `String(int)` 在 4.7 没有构造器（对方坑表第 9 条），一律 str()
	if 有 and zq < 需精华:
		精华串 = "[color=#ff0000]%d[/color]" % 需精华
	var 说明 := _页面.get_node("内容框/说明") as RichTextLabel
	if 说明 != null:
		说明.bbcode_enabled = true
		# 模板 `EQUIP_STRENGTH_DESC_TEMPLATE_1` 两行整体白字（外层 `<font color='#ffffff'>`），
		# 只有"精华不够"那个数换成红（`:388`）。
		说明.text = "[color=#ffffff]本次操作消耗精华：%s[/color]\n[color=#ffffff]本次操作成功几率：%d%%[/color]" % [精华串, 几率]
	var 钮 := _页面.get_node("内容框/放入残卷区/放入残卷") as Button
	if 钮 != null:
		钮.text = "取出残卷" if 有 else "放入残卷"
	var 格 := _页面.get_node("内容框/放入残卷区/主残卷格") as Button
	if 格 != null:
		格.icon = 游戏数据.item_icon(String(行.get("id", ""))) if 有 else _空格皮()
		# 悬停详情：`_itemDropBox.itemCell.itemData = this._itemData`（`JiNengCompositeWindow.as:107`）。
		# 数量取这一摞的件数（itemData.count），不是背包同种总数。
		_宿主._接打造提示(_页面, 格, int(行.get("id", 0)),
				int(行.get("quantity", 1)) if 有 else 1)
	_填材料格(配置, 行, 有)


## 四枚材料格的显示（原版 `updateView:84-109` + `updateXingYunRatio:377-398`）：
##   · 辅残卷1 = **主残卷同款图标**（`_fu1.itemCell.itemData = this._itemData`），
##     角标 = `needCnt − 1`（`updateXingYunRatio:392` `_fu1.itemCell.label = needCnt - 1`），
##     背包里同款总数 < needCnt 时整格灰（`updateView:96-105` 那三行 filters）；
##   · 辅残卷2/3 原版两枚 `_loc2_/_loc3_` **从未赋值** ⇒ itemData 恒 null ⇒ 空皮、无数；
##   · 幸运符 = `ItemFactory.createSingleItem(helpItemId)` 的图标，角标 = **背包拥有数**
##     （`_fu4.itemCell.label = isBagExistItem(...)`；`hasItem()` 在拥有 0 时打灰）。
## 以前这四格全没接线：永远是场景烘的那张通用空皮、一个数字都没有（用户 2026-11-02 报
## 「辅残券、幸运符的显示都没有正确接入」）。与 AS3 唯一偏离：幸运符拥有数**一开页就写**，
## 原版要等一次 `ITEM_DATAS_CHANGED` 才补上（`itemDatachanged:312`）—— 那只是它自己的时序。
static func _填材料格(配置: Dictionary, 行: Dictionary, 有主: bool) -> void:
	var 帮手id := int(配置.get("help_item", 0))
	var 拥有符 := _背包计数(str(帮手id))
	var 需条 := _需条(行)
	var 拥有卷 := _背包计数(String(行.get("id", ""))) if 有主 else 0
	for i in 4:
		var 格 := _页面.get_node_or_null(材料格路[i]) as Control
		if 格 == null:
			continue
		var 图 := 格.get_node_or_null("物品格") as TextureRect
		var 标 := 格.get_node_or_null(数量名) as Label
		if 标 == null:
			标 = Label.new()
			标.name = 数量名
			标.mouse_filter = Control.MOUSE_FILTER_IGNORE
			标.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			标.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			标.add_theme_font_size_override("font_size", 12)
			标.add_theme_color_override("font_color", Color.WHITE)
			格.add_child(标)
		var 图标: Texture2D = null
		var 数串 := ""
		var 要灰 := false
		var 提示号 := 0
		var 提示量 := 1
		if i == 0 and 有主:
			图标 = 游戏数据.item_icon(String(行.get("id", "")))
			数串 = str(maxi(0, 需条 - 1))
			要灰 = 拥有卷 < 需条
			提示号 = int(行.get("id", 0))			# `_fu1.itemCell.itemData = this._itemData`（`:119`）
			提示量 = maxi(1, int(行.get("quantity", 1)))
		elif i == 3 and 帮手id > 0:
			图标 = 游戏数据.item_icon(str(帮手id))
			数串 = str(拥有符)
			要灰 = 拥有符 <= 0
			提示号 = 帮手id							# `_fu4.itemCell.itemData = createSingleItem(helpItemId)`（`:122`）
			提示量 = maxi(1, 拥有符)
		if 图 != null:
			图.texture = 图标 if 图标 != null else _空格皮()
			# 悬停详情挂在 40×40 的 `物品格`（`SimpleItemCell` 的命中区），不是整块 56×88 底板。
			_宿主._接打造提示(_页面, 图, 提示号, 提示量)
			# 角标压在物品格右下角（SimpleItemCell.countLabel 的原位；格是 40×40）。
			标.position = Vector2(图.position.x, 图.position.y + 图.size.y - 20.0)
			标.size = Vector2(图.size.x, 20.0)
		else:
			标.position = Vector2(0.0, 40.0)
			标.size = Vector2(56.0, 20.0)
		标.text = 数串
		var 材: Material = 灰材质() if 要灰 else null
		if 图 != null:
			图.material = 材
		标.material = 材


static func 灰材质() -> ShaderMaterial:
	if _灰材质 == null:
		_灰材质 = ShaderMaterial.new()
		_灰材质.shader = 灰度着色器
	return _灰材质


## 一张残卷要几枚：原版 `_configInfo.needCnt` 取自 `spec.merge.needCnt`（`updateView:88-92`），
## 表里那列是 `canjuan_need`。
static func _需条(行: Dictionary) -> int:
	return maxi(1, int(游戏数据.item(String(行.get("id", ""))).get("canjuan_need", 0)))


static func _空格皮() -> Texture2D:
	return load("res://素材/界面/原版窗口/通用控件/物品格.png") as Texture2D


static func _配置() -> Dictionary:
	var 解: Variant = JSON.parse_string(FileAccess.get_file_as_string(配置路径))
	return (解 as Dictionary) if 解 is Dictionary else {}


## 当前下拉选中张数（勾了才算；勾没勾由 `_接幸运符` 的 disabled 反映——原版 `:279` 先判 selected）。
static func _选中张数() -> int:
	var 勾 := _页面.get_node("内容框/结果区/使用幸运符") as CheckBox
	if 勾 == null or not 勾.button_pressed:
		return 0
	return int(_页面.get_node("内容框/结果区/幸运符数量").text)


## 勾选↔下拉（`JiNengCompositeWindow.as:243-248` + `clickCheckBoxHandler`）：
## `dataProvider = getLianXuArrByNum(9)` ⇒ **1..9**（宝石工艺那页是 20，别抄错）、
## 初值 `enabled=false`、显示第 1 项；勾上才放开，取消勾选回第 1 项。勾/张数变了几率文案跟刷。
static func _接幸运符(page: Control) -> void:
	var 勾 := page.get_node("内容框/结果区/使用幸运符") as CheckBox
	var 下拉 := page.get_node("内容框/结果区/幸运符数量") as MenuButton
	var 菜单 := 下拉.get_popup()
	菜单.clear()
	for n in 9:
		菜单.add_item(str(n + 1), n)
	菜单.id_pressed.connect(func(id: int):
		下拉.text = str(id + 1)
		_刷视图())
	下拉.text = "1"
	下拉.disabled = not 勾.button_pressed
	勾.toggled.connect(func(开: bool):
		下拉.disabled = not 开
		if not 开:
			下拉.text = "1"
		_刷视图())


## 「放入残卷」= 原版 `clickDropBtnHandler:326-340` 三分支逐支对上（§3.308，用户点名要能"点选"）：
##   已放入（文案态「取出残卷」）⇒ `backItemToEquip` 取回；
##   没放、且背包里有可放残卷 ⇒ 原版进 `UpShelfCursor` 光标收集态（本工程无跟手件，
##     **用户授权的偏离**：改成在游标处弹残卷选择清单、点一条即放入——输入等价通道）；
##   没放、背包也没残卷 ⇒ 原版空态话 `upgradeHandler:149-152`「请放入忍术残卷！」。
static func _点放入钮() -> void:
	if _放入格 > 0:
		_取回残卷()
		return
	var 清单 := _背包残卷清单()
	if 清单.is_empty():
		_宿主._show_hint(空态提示)
		return
	_选择清单 = 清单
	_选择器 = 放入选择器.弹(_页面, 清单,
			func(行: Dictionary) -> void: _落入(int(行.get("格", 0))), "残卷选择")


## 背包里**可参与合成**的残卷堆（判据与落点同一把闸 `残卷放入格.有配方`，两路永远同口径）。
static func _背包残卷清单() -> Array:
	return 放入选择器.背包候选(_宿主._session,
			func(条: Dictionary) -> bool:
				return (int(条.get("slot_index", 0)) > 0
						and 残卷放入格类.有配方(String(条.get("id", "")))))


## 提交 = 原版 `upgradeHandler:147-170` **四步判序逐字照抄**（不发就是不发）：
##   ①没放主残卷 → 「请放入忍术残卷！」
##   ②背包里该残卷总量 < needCnt → 「对不起，秘笈合成至少需要%1个忍术残卷！」
##   ③精华 < needZq → 「很抱歉，你的查克拉精华不够」
##   ④勾了幸运符但背包枚数 < 选中张数 → 「很抱歉，你的幸运符不够」
## 全过 ⇒ `游戏会话.合成秘笈`（离线 false ⇒ 诚实话，§3.83/§3.86 同口径）。
static func _提交() -> void:
	var 行 := _放入现读()
	if 行.is_empty():
		_宿主._show_hint(空态提示)
		return
	var 配置 := _配置()
	var 物品id := String(行.get("id", ""))
	var 需条 := _需条(行)
	var 在手: int = _背包计数(物品id)
	if 在手 < 需条:
		_宿主._show_hint(缺残卷模板.replace("%1", str(需条)))
		return
	var zq: int = int(_宿主._session.player_stats.get("zq", 0))
	if zq < int(配置.get("need_zq", 0)):
		_宿主._show_hint(缺精华)
		return
	var 张数 := _选中张数()
	if 张数 > 0 and _背包计数(str(int(配置.get("help_item", 0)))) < 张数:
		_宿主._show_hint(缺幸运符)
		return
	if not _宿主._session.合成秘笈(_放入格, 张数):
		_宿主._show_hint("秘笈合成要在服务端结算（离线不模拟）")
		return
	# 原版此刻 `showLoadingBar(CN.MI_JI_LOAGING_NAME)` =「秘笈合成中」（本工程无进度条件，话照抄）。
	_宿主._show_hint("秘笈合成中")


static func _背包计数(物品id: String) -> int:
	var 总 := 0
	for 件 in _宿主._session.inventory:
		if typeof(件) == TYPE_DICTIONARY and String((件 as Dictionary).get("id", "")) == 物品id:
			总 += int((件 as Dictionary).get("quantity", 0))
	return 总


## 结果帧（`1352:0:<0/1>`）。原版 `operationResultHandler:342-347`：**true 才刷新、失败什么都不弹**——
## 物品增减由通用背包帧/属性帧表达，"成功"没有话术、"失败"也没有。这里严格照办：只刷视图，
## **不自造"合成成功/失败"文案**（在线门靠捕 `can_juan_result` 信号钉结果帧到过，不靠文案）。
static func _于结果(_成功: bool) -> void:
	_刷视图()
