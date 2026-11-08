extends RefCounted

## 木叶丸（NPC `00000032`，模板 32，称号「徽章打造」）「徽章打造」= 原版
## `com/mxw/uifl/controls/beastBadge/BeastBadgeWindow`（340×400，标题「**徽章打造合成**」）。
## 场景由 `开发工具/原版服务窗.py 生成 徽章打造` 从 SPEC 烘（36 件、逐条带 AS3 行号），
## **别手改 .tscn** —— 门会重跑生成器比期望表（`数据/界面/徽章打造_期望.json`）。
##
## 控制器只管原版也归运行期管的那三件：
##   ① 两页签切页（`:60-73 selectedBtnHandler`）= 换选中枚 + 换面板 + **换「确定」钮文字**
##      （页0 = `CREATESTONE_START_BTN`「开始合成」、页1 = `HUIZAHNG_START`「开始打造」，
##      `:67/:71`）；默认开页 **0**（`:101-103 init(param1 = 0)`）。
##   ② 两枚「放入」钮各自的换文案（`StoneComposePane:59-72` / `BadgeComposePane:58-71`）：
##      「放入打造石」⇄「取出打造石」、「放入徽章」⇄「取出徽章」—— 两支**都不发帧**，
##      前一支进光标收集模式（`CursorManager.showCursorUI("UpShelfCursor")` +
##      `UIConfig.dropValidateFun`），后一支只在有成品时清格。⇒ 与背包格拖放联动（未决 #8）未接。
##   ③ 「确定」钮按当前页分流（`:118-128 OKBtnClickHandler`）：页0 走 `submitToHandle:206-222`、
##      页1 走 `upgradeEquip:215-239`，两支第一道闸门都是「格里没有料」⇒ 弹**两句不同的真提示**
##      （`EQUIP_STRENGTH_FAIL_PROMPT_6[0]` = 「请放入%1！」，页0 替 `BEASTBADGE_STONE`「徽章打造石」、
##      页1 替 `_6[1]` = 「装备」）⇒ 离线点它**永远落在这一句**，这正是原版真身。
##
## ⚠ 切页时原版会 `removeAllChild(_contentPane)` 再把 pane 重挂（`:62` + `:85/:98`），
##   两个 pane **懒建后重用、不重建**；且两边都会调 `backItemToEquip()`（`:83`/`:96`——
##   `:96` 那行清的是 `_badgeComposePane` 自己，没清石头那页，原版就这么写的，不"顺手修好"）。
##   这边等价于「两枚容器只切 visible」（口径同 勾玉炼制 的三页签），
##   `backItemToEquip` 清的都是运行期物品状态 ⇒ 离线恒空，不需要代码。
##
## ⚠ 材料盒那枚格（`_fu1` = `ItemCaiLiaoBox`）**没放徽章时是灰的、且没有图标**：
##   `updateView:175` 在没料时用 `getHuiZhangStageUpconfig(2)` 兜底，而 2.2.3 的
##   `Etc.json EquipSystem.huiZhangStageUp` 键是徽章 itemid（1410001…1410010）、**没有键 "2"**
##   ⇒ `:179-181` 直接 return，格既不填图也不设数量，`backItemToEquip:272` 再 `applyGrayFilter()`。
##   ⇒ 已烘成场景里的 `灰化: true`（口径同 2026-10-05「精玉灵珠图标其实是静态配置」那条：
##   查到"原版这里就是空"也是一个结论，不许拿别的图填上）。
##   **2026-10-25 补上另外半条（报修 1.1）**：放了徽章就**不是**空的 ——
##   `updateView:183-186` 按 `huiZhangStageUp[<徽章十进制id>]` 把**要耗的那枚打造石与颗数自动填进这格**
##   （玩家不拖、也拖不进去：`ItemCaiLiaoBox` 只有 `itemCell`，没挂 `dropItemFun`），
##   灰不灰只由 `validateCaiLiao:203-213` 说了算 = `count < needItemCnt`，
##   而 `count` = `isBagExistItem(石id)`（`DataCenter.as:3166-3182`，**整个背包同 id 摞数相加**）。
##   ⇒ 「放入徽章后石头自己带上、数量写着需要几颗、只有不够才灰」是原版真身，不是新增诉求。
##   ⚠ 「取出徽章」那支照 `backItemToEquip:272-273`：**只清图标、重新挂灰，数量文字留着**
##   （AS3 的 `countLabel` 不归 `itemData` 那支管，取出时没人清它 —— 不"顺手修好"）。
##
## 协议面：两页提交都走 `ITEM_CHANGE = 1040`（`SendOpCodes.as:146`）——
##   页0 = 子命令 **26**（`StoneComposePane:243` `requestMergeHuiZhangStone(position)` →
##   `Client.as:9810-9815`）、页1 = 子命令 **27**（`BadgeComposePane:112`
##   `requestStageUpHuiZhang(position)` → `Client.as:2379-2384`），都只带一个 int 背包格号。
##   页0 的**回包是单独一帧** `2317 = HUI_ZHANG_STONE_MERGE_RES`
##   （`ReceiveOpCodes.as:464`，`ItemChangeProcessor.handleHuiZhangStoneMergerResponse:20-43`
##   读四个 int = 成数/成品id/剩余数/剩余id → `Client.onHuiZhangStoneMergeResponse:10020-10023`
##   → `StoneComposePane.updateResultAndLeftCel:114-124`）⇒ 成功/剩余两格**只有这帧能填**，
##   它同时把投料格与产物格清掉（`:122-123`）。页1 **没有**专属回包：`_stage_up_badge` 只发
##   背包增删 + 属性帧，成品靠 `ITEM_DATAS_CHANGED` 那条重刷（`BadgeComposePane.itemDatachanged:241-255`）。

const 页签数 := 2
const 徽章放入格 := preload("res://脚本/界面/组件/徽章放入格.gd")
const 放入选择器 := preload("res://脚本/界面/组件/放入选择器.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 装备打造表 := preload("res://脚本/界面/装备打造表.gd")
const 格子提示框 := preload("res://脚本/界面/组件/格子提示框.gd")
const 物品提示场景 := preload("res://场景/界面/组件/物品提示框.tscn")
const 装备提示场景 := preload("res://场景/界面/组件/装备提示框.tscn")
const 面板名 := ["面板0", "面板1"]
const 确定文 := ["开始合成", "开始打造"]		# CREATESTONE_START_BTN(2881) / HUIZAHNG_START(3066)
const 放入路 := ["内容层/面板0/石页投料盒/石页放入钮",
		"内容层/面板1/徽页投料盒/徽页放入钮"]
const 放入文 := ["放入打造石", "放入徽章"]		# CREATESTONE_INPUT_BTN(105) / BEASTBADGE_INPUT_BTN(3335)
const 取出文 := ["取出打造石", "取出徽章"]		# CREATESTONE_GET_BTN(2951) / BEASTBADGE_GET_BTN(2459)
## 两句都是 `EQUIP_STRENGTH_FAIL_PROMPT_6[0]`(1925「请放入%1！」) 替出来的：
## 页0 传 `BEASTBADGE_STONE`(81「徽章打造石」)、页1 传 `_6[1]`(1924「装备」)。
const 缺料文 := ["请放入徽章打造石！", "请放入装备！"]
## 「确定」两页各发的**真协议**（2026-10-11 接上）：
## 页0 `StoneComposePane:243` `requestMergeHuiZhangStone(position)` → `ITEM_CHANGE 1040` 子命令 **26**；
## 页1 `BadgeComposePane:112` `requestStageUpHuiZhang(position)` → 子命令 **27**。都只带**背包格号**。
const 提交动作 := [26, 27]

## 材料格 / 数量角标 / 落点件的挂点。场景是 SPEC 生成物、**不许手改 .tscn** ⇒ 落点运行期挂。
const 材料格路 := ["内容层/面板0/石页投料盒/石页材料格",
		"内容层/面板1/徽页投料盒/徽页材料格"]
const 材料数量路 := ["内容层/面板0/石页投料盒/石页材料格/石页材料格_数量",
		"内容层/面板1/徽页投料盒/徽页材料格/徽页材料格_数量"]
## 两页投料盒里的**产物格**（`ItemDropBox.resultCell`）：`validateItem:100-101` /
## `updateView:177-178` 一放件就把"下一级那件"摆上去，`updateResultAndLeftCel:123` 把它清掉。
const 产物格路 := ["内容层/面板0/石页投料盒/石页结果格",
		"内容层/面板1/徽页投料盒/徽页结果格"]
const 产物数量路 := ["内容层/面板0/石页投料盒/石页结果格/石页结果格_数量",
		"内容层/面板1/徽页投料盒/徽页结果格/徽页结果格_数量"]
## 页1 的材料盒 = `BadgeComposePane._fu1`（`ItemCaiLiaoBox`）：石与颗数是**配置自动带的**，不是拖进去的。
const 材料盒格路 := "内容层/面板1/材料盒/材料盒格"
const 材料盒数量路 := "内容层/面板1/材料盒/材料盒格/材料盒格_数量"
## 页0 那两格 = `StoneComposePane._successCell` / `_leftCell`（`updateResultAndLeftCel:116-121`），
## **只有 2317 那一帧能填** ⇒ 没收到回包前原版也是两枚空格。
const 成功格路 := "内容层/面板0/石页成功格"
const 成功数量路 := "内容层/面板0/石页成功格/石页成功格_数量"
const 剩余格路 := "内容层/面板0/石页剩余格"
const 剩余数量路 := "内容层/面板0/石页剩余格/石页剩余格_数量"
const 图标名 := "投料图标"

## 会话级：原版 `_tabBar.selectedIndex`（窗内状态）⇒ 做成 static 让门能不点鼠标直接驱动。
static var _页 := 0
## 每页那份"放进去的料"的**来源背包槽号**（1 基；-1 = 没放）。
## 原版是 `_fu1.itemCell.itemData.position`，提交发的就是它（`StoneComposePane:243`）。
static var _投料 := [-1, -1]
## 2317 `HUI_ZHANG_STONE_MERGE_RES` 那四个 int（成数/成品id/剩余数/剩余id）。
## 原版把它直接写进 `_successCell`/`_leftCell`；这边存成会话级，重渲染时由
## `刷新合成结果格` 摆 —— 与 `_宝石合成结果`（宝石工艺页）同一口径。
static var _石合成结果: Dictionary = {}


static func 新会话() -> void:
	_页 = 0
	_投料 = [-1, -1]
	_石合成结果 = {}


## `Client.onHuiZhangStoneMergeResponse:10020-10023` 的那一句转发。
## 除了存下四个数，还照 `updateResultAndLeftCel:122-123` 把**投料格与产物格清掉**。
static func 收石合成回帧(帧: Dictionary) -> void:
	_石合成结果 = 帧.duplicate(true)
	_投料[0] = -1


static func 当前页() -> int:
	return _页


## `宿主` = `功能窗口`（要 `_content` / `_通知`）。
static func 渲染(宿主: Node, 场景: PackedScene) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	建提示框(页)
	for i in 页签数:
		(页.get_node("页签条/页签%d" % i) as Button).pressed.connect(_点页.bind(页, i))
		(页.get_node(放入路[i]) as Button).pressed.connect(_点放入.bind(宿主, 页, i))
		挂投料格(页, 宿主, i)
	(页.get_node("确定钮") as Button).pressed.connect(_点确定.bind(宿主, 页))
	切页(页, _页)
	return 页


## 悬停详情框的两个节点场景里没烘（SPEC 生成物不许手改 .tscn）⇒ 运行期挂，
## 口径同 `福袋窗._建提示框` / `礼包详情窗._建提示框`。原版五枚格全是 `SimpleItemCell`，
## 每枚都挂 `MToolTipItem`（`SimpleItemCell.as:220`），分发见 `格子提示框.gd` 的头注。
static func 建提示框(页: Control) -> void:
	for 项 in [["物品提示框", 物品提示场景], ["装备提示框", 装备提示场景]]:
		var 名 := str(项[0])
		if 页.get_node_or_null(名) != null:
			continue
		var 框 := (项[1] as PackedScene).instantiate() as Control
		框.name = 名
		框.mouse_filter = Control.MOUSE_FILTER_IGNORE
		页.add_child(框)


## 这一页现在那份料的**背包行**（格号失效/被服务端清掉 ⇒ 空字典 = 原版 `_itemData` 为 null）。
static func 料(宿主: Node, 槽: int) -> Dictionary:
	if 槽 <= 0 or 宿主 == null or 宿主.get("_session") == null:
		return {}
	var 会话: Node = 宿主.get("_session")
	return 会话._占用条(会话.inventory, 槽)


## 把落点件挂到这一页的材料格上（场景是 SPEC 生成物、不许手改 .tscn ⇒ 运行期 `set_script`，
## 先例见 `意志格.gd`）。判据与"收不收"在组件里，这里只负责挂与刷。
static func 挂投料格(页: Control, 宿主: Node, i: int) -> void:
	var 格: Control = 页.get_node(材料格路[i]) as Control
	格.set_script(徽章放入格)
	格.set("本页", i)
	# 落点必须能接鼠标（场景里那些皮件多半是 IGNORE）。
	格.mouse_filter = Control.MOUSE_FILTER_STOP
	格.connect("请求放入", func(背包格: int) -> void: 收料(宿主, 页, i, 背包格))
	刷新投料格(页, 宿主, i)


## 落上一件合格料。原版 `validateItem` 在"收下"之前还有两道闸门（**满级 / 破碎**），
## 过了才 `_itemData = param1`；这里照同一次序判，不过就**弹原版那句话、不收**。
static func 收料(宿主: Node, 页: Control, i: int, 背包格: int) -> void:
	if 背包格 <= 0:
		return
	var 提示 := 满级或破碎提示(宿主, i, 背包格)
	if not 提示.is_empty():
		宿主._通知(提示)
		return
	if i == 0:
		# `StoneComposePane.dropItemHandler:76-77`：落新料**先把上次的成功/剩余两格清空**。
		_石合成结果 = {}
	_投料[i] = 背包格
	刷新投料格(页, 宿主, i)


## 原版"收下之前"那道闸门（满级 / 破碎）。返回空串 = 收；否则是**逐字的原版提示**。
## 判据来源（两处都**按八位补零**查表 —— §3.129 那条 id 形态的坑）：
##   · 页0 `StoneComposePane.validateItem:88-95`：徽章打造石（`StoneData.nextId`）满级 ⇒
##     `MDialog(IS_STONE_LEVEL_MAX)`「该宝石已经是最高等级！」。`StoneData.nextId = inlay.next`
##     ⇔ 我们 `物品.json` 的 `stone_next`（**与「宝石工艺」合成页同源同判据**，见 `功能窗口._宝石工艺_放入`）。
##   · 页1 `BadgeComposePane.validateItem:86-95`：**先破碎**（`crashTime > 0`，`FAIL_PROMPT_10[0]`
##     替 `_10[2]` =「对不起，该装备已经破损！」）、**再满级**（`EqpData.nextId == 0`，
##     `FAIL_PROMPT_11[0]` 替 `_11[1]` =「该装备已经是最高阶！」）。`EqpData.nextId = ZhuangBei.next`
##     ⇔ 我们 `装备库.json` 的 `进阶目标`（**空串 = 满级**，导出见 `导出装备库.mjs:82`）。
static func 满级或破碎提示(宿主: Node, 页: int, 背包格: int) -> String:
	var 条: Dictionary = {}
	if 宿主 != null and 宿主.get("_session") != null:
		条 = 宿主._session._占用条(宿主._session.inventory, 背包格)
	if 条.is_empty():
		return ""
	var 补零 := str(条.get("id", "")).pad_zeros(8)
	if 页 == 0:
		if int(游戏数据.item(补零).get("stone_next", 0)) <= 0:
			return "该宝石已经是最高等级！"
		return ""
	if int(条.get("crash_time", 0)) > 0:
		return "对不起，该装备已经破损！"
	if 装备进阶目标(补零).is_empty():
		return "该装备已经是最高阶！"
	return ""


## `装备库.装备[八位id].进阶目标`（原版 `EqpData.nextId`；**空串 = 满级**）。
## 真源已提进 `游戏数据.装备进阶目标`（勾玉炼制的玉链升阶也用同一条）——这里只留个转发，
## 免得本窗的门与注释认不出名字。
static func 装备进阶目标(八位id: String) -> String:
	return 游戏数据.装备进阶目标(八位id)


## 按当前那份料刷新这一页：材料格的**图标**（运行期挂的 `投料图标`）、枚数角标、
## 「放入/取出」钮的文字（`CREATESTONE_GET_BTN` / `BEASTBADGE_GET_BTN`），
## 以及**产物格**（`updateView:177-178` / `validateItem:100-101`）、页1 的**材料盒**
## （`updateView:183-186` + `validateCaiLiao:203-213`）、页0 的**成功/剩余两格**
## （`updateResultAndLeftCel:114-124`，只有 2317 那帧填得上）。
static func 刷新投料格(页: Control, 宿主: Node, i: int) -> void:
	var 格: Control = 页.get_node(材料格路[i]) as Control
	var 条 := 料(宿主, _投料[i])
	var 图标 := 格.get_node_or_null(图标名) as TextureRect
	if 条.is_empty():
		_投料[i] = -1
		if 图标 != null:
			图标.texture = null
		(页.get_node(材料数量路[i]) as Label).text = " "
	else:
		图标 = 挂图标(格)
		图标.texture = 游戏数据.item_icon(str(条.get("id", "")))
		(页.get_node(材料数量路[i]) as Label).text = str(int(条.get("quantity", 1)))
	var 钮 := 页.get_node(放入路[i]) as Button
	钮.text = 取出文[i] if not 条.is_empty() else 放入文[i]
	接提示(宿主, 页, 格, 条)
	刷新产物格(页, 宿主, i, 条)
	if i == 1:
		刷新材料盒(页, 宿主, 条)
	else:
		刷新合成结果格(页, 宿主)


## 图标**原尺寸、居中**摆在格上 —— `SimpleItemCell.showIcon:157-165`：
## `x = round((40 - icon.width) / 2)`（34×34 的图 ⇒ (3,3)），**不是铺满**。
## 层序也是原版钉死的：`setSkin` 把背景 add 在 0、`createChildren:143` 把 countLabel add 在 1、
## `showIcon:159` 再 `addChildAt(_icon, 1)` ⇒ 背景 → **图标 → 数量**，数字永远压在图上。
## 本工程的 `_数量` 是烘在场景里的（背景之后），运行期 add 的图标会排到**最后**把数字盖住
## ——用户 2026-10-28 报修「合成后成功/剩余的数被打造石图标盖住」的真因；
## 所以挂完必须 `move_child` 到数量 Label **之前**。
static func 挂图标(格: Control) -> TextureRect:
	var 图标 := 格.get_node_or_null(图标名) as TextureRect
	if 图标 != null:
		return 图标
	图标 = TextureRect.new()
	图标.name = 图标名
	图标.position = Vector2.ZERO
	图标.size = 格.size
	图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图标.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	图标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	格.add_child(图标)
	for 子件 in 格.get_children():
		if 子件 is Label:
			格.move_child(图标, 子件.get_index())
			break
	return 图标


## 悬停详情框。格子在场景里多半是 `mouse_filter = 2`（IGNORE）⇒ 抬到 **PASS**：
## 只收悬停、不吞点击/拖放（口径同 `功能窗口._接打造提示`）。
## `物品` 空字典 = 这格现在没件 ⇒ 走 `格子提示框` 的"空格子悬停把两套都收掉"那一支。
static func 接提示(宿主: Node, 页: Control, 格: Control, 物品: Dictionary) -> void:
	if 格.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		格.mouse_filter = Control.MOUSE_FILTER_PASS
	格子提示框.接线(宿主, 页, 格, 物品)


## 这一格现在摆的**件**（提示框的载荷）：投料格用背包真行（词条/强化等级都是真的），
## 产物格/材料盒/成功格只有 id 与枚数 —— 与原版那几枚 `ItemFactory.createSingleItem` 同形。
static func 载荷(id: Variant, 枚数: int, 源: Dictionary = {}) -> Dictionary:
	if str(id) == "" or int(id) == 0:
		return {}
	var 条 := {"id": str(id).pad_zeros(8), "quantity": maxi(1, 枚数)}
	for 键 in ["aptitude", "strength_level", "strength_value", "plus_attributes", "endure"]:
		if 源.has(键):
			条[键] = 源[键]
	return 条


## `updateView:177-178`（页1，`getHuiZhangUpgradeItemData`）与
## `validateItem:100-101` + `updateView:130-131`（页0，`createSingleItem(nextId)`）：
## 放件后**下一级那件**摆进产物格；两边都不设 `resultCell.label` ⇒ 产物格**只有图标、
## 没有角标**（`SimpleItemCell` 的 `countLabel` 只由 `set label:255-261` 写，`set itemData` 不碰它）。
static func 刷新产物格(页: Control, 宿主: Node, i: int, 条: Dictionary) -> void:
	var 格: Control = 页.get_node(产物格路[i]) as Control
	var 下件 := 下一级id(条, i)
	挂图标(格).texture = 游戏数据.item_icon(str(下件).pad_zeros(8)) if 下件 != 0 else null
	(页.get_node(产物数量路[i]) as Label).text = " "
	# 页1 的产物是**带着旧徽章属性**的那件（`getHuiZhangUpgradeItemData:929-946` 逐条 copy）；
	# 页0 是 `createSingleItem(nextId)` 造的**裸石** ⇒ 不带。
	接提示(宿主, 页, 格, 载荷(下件, 1, 条 if i == 1 else {}))


## 页0 的 `stone_next`（`物品.json`）/ 页1 的 `进阶目标`（`装备库.json`）⇒ 八位 id；0 = 满级/没件。
static func 下一级id(条: Dictionary, 页: int) -> int:
	if 条.is_empty():
		return 0
	var 补零 := str(条.get("id", "")).pad_zeros(8)
	if 页 == 0:
		return int(游戏数据.item(补零).get("stone_next", 0))
	var 目标 := 装备进阶目标(补零)
	return int(目标) if 目标.is_valid_int() else 0


## 页1 那枚 `ItemCaiLiaoBox`（`_fu1`）：石与颗数由 `huiZhangStageUp[<徽章十进制id>]` **自动带**，
## 灰只由"背包里这枚石的总数够不够"决定（`validateCaiLiao:205-212`）。
static func 刷新材料盒(页: Control, 宿主: Node, 徽章: Dictionary) -> void:
	var 格: Control = 页.get_node(材料盒格路) as Control
	var 数 := 页.get_node(材料盒数量路) as Label
	var 配置 := 徽章强化配置(str(徽章.get("id", "")))
	if 配置.is_empty():
		# 没徽章 / 表里查不到 ⇒ 原版 `updateView:179-181` 直接 return（连图标都不换），
		# `backItemToEquip:272` 把灰挂回去；`:273` 只清 `itemData`，**countLabel 没人清** ⇒ 角标留着。
		var 旧 := 格.get_node_or_null(图标名) as TextureRect
		if 旧 != null:
			旧.texture = null
		套灰(宿主, 格, true)
		接提示(宿主, 页, 格, {})
		return
	var 石id := int(配置.get("needItemId", 0))
	var 需数 := int(配置.get("needItemCnt", 0))
	挂图标(格).texture = 游戏数据.item_icon(str(石id).pad_zeros(8))
	数.text = str(需数)
	套灰(宿主, 格, 装备打造表.拥有数(宿主.get("_session"), 石id) < 需数)
	接提示(宿主, 页, 格, 载荷(石id, 需数))


## `huiZhangStageUp` 那一行 —— 原版 `StringTool.getHuiZhangStageUpconfig(int(徽章id))`
## （`StringTool.as:319-323`）：**键是去前导零的十进制 id**（"1410001"，不是八位"01410001"）。
## ⚠ 表里**没有 `needMoney`** ⇒ 原版 `upgradeEquip:232` 那句 `undefined > cocoNuts` 恒 false，
##   金币这一闸**实际不存在**，别自己加。
static func 徽章强化配置(八位id: String) -> Dictionary:
	if 八位id.is_empty() or not 八位id.is_valid_int():
		return {}
	var 条: Variant = 装备打造表.取段("huiZhangStageUp").get(str(int(八位id)), null)
	return 条 as Dictionary if typeof(条) == TYPE_DICTIONARY else {}


## 页0 的成功/剩余两格（`updateResultAndLeftCel:116-121`）：没收到 2317 之前恒空。
static func 刷新合成结果格(页: Control, 宿主: Node) -> void:
	填结果格(页, 宿主, 成功格路, 成功数量路, int(_石合成结果.get("success_count", 0)),
			int(_石合成结果.get("success_item_id", 0)))
	填结果格(页, 宿主, 剩余格路, 剩余数量路, int(_石合成结果.get("left_count", 0)),
			int(_石合成结果.get("left_item_id", 0)))


static func 填结果格(页: Control, 宿主: Node, 格路: String, 数量路: String,
		枚数: int, id: int) -> void:
	var 格: Control = 页.get_node(格路) as Control
	挂图标(格).texture = 游戏数据.item_icon(str(id).pad_zeros(8)) if 枚数 > 0 and id > 0 else null
	(页.get_node(数量路) as Label).text = str(枚数) if 枚数 > 0 else " "
	接提示(宿主, 页, 格, 载荷(id, 枚数))


## 灰要打满整格：Godot 的 `material` **不传子节点**（§3.18.9 精炼页量出来的），
## 而场景把 `mat1` 同时烘在格与 `_数量` 两枚上 ⇒ 连子节点一起设（图标/角标跟着灰）。
static func 套灰(宿主: Node, 件: Control, 要灰: bool) -> void:
	# 灰度材质**只有 `功能窗口` 那一份**（`禁用灰度材质()`，先例 `二级密码窗._设禁用:918`）；
	# 本窗不 preload 它 —— `功能窗口` 反过来 preload 本窗，会成环。
	var 材质: Material = 宿主.禁用灰度材质() if 要灰 else null
	件.material = 材质
	for 子 in 件.get_children():
		var 子件 := 子 as CanvasItem
		if 子件 != null:
			子件.material = 材质


## `selectedBtnHandler:60-73`：换选中枚 + 换面板 + 换「确定」钮文字。
## `MTabButton` 的选中机制照共用口径：**选中那枚走 disabled 槽**（显示 `selectedUpSkin`
## = tag118 那张真皮，不是灰度）、四档字色同一个 #FCF49C、选中态悬停不变亮。
static func 切页(页: Control, 序: int) -> void:
	_页 = clampi(序, 0, 页签数 - 1)
	for i in 页签数:
		var 钮 := 页.get_node("页签条/页签%d" % i) as Button
		钮.disabled = (i == _页)
		钮.button_pressed = (i == _页)
		(页.get_node("内容层/%s" % 面板名[i]) as Control).visible = (i == _页)
	(页.get_node("确定钮") as Button).text = 确定文[_页]


static func _点页(页: Control, 序: int) -> void:
	切页(页, 序)


## 「放入」钮：原版这一支**没有单帧请求**（`:59-72` `clickDropBtnHandler` 只把鼠标切成
## `UpShelfCursor` 收集态、挂上 `UIConfig.dropValidateFun`，点背包格才真进格）。
## 本工程用公共「放入选择」弹层 + 拖放（`徽章放入格.gd` 挂在材料格上）⇒ 钮负责：
## **有料时取出**（原版那一支清格也不发帧），**没料时**弹背包候选，选中 = 原版"点背包那一格"。
static func _点放入(宿主: Node, 页: Control, 序: int) -> void:
	if _投料[序] > 0:
		if 序 == 0:
			# `StoneComposePane.backItemToEquip:275-276`：取出连成功/剩余两格一起清。
			_石合成结果 = {}
		_投料[序] = -1
		刷新投料格(页, 宿主, 序)
		return
	var 清单 := 放入选择器.背包候选(宿主.get("_session"),
			func(条: Dictionary) -> bool: return 徽章放入格.可收(String(条.get("id", "")), 序))
	if 清单.is_empty():
		宿主._通知("背包里没有可放入的%s" % ("徽章打造石" if 序 == 0 else "徽章"))
		return
	放入选择器.弹(页, 清单,
			func(行: Dictionary) -> void: 收料(宿主, 页, 序, int(行.get("格", 0))))


## 「确定」：`:118-128` 按页分流。闸门顺序照原版两支**逐条**对：
##   · 页0 `submitToHandle:206-222`：没料 → 「请放入徽章打造石！」；**这摞 < 3 颗** →
##     `EQUIP_STONE_FAIL_PROMPT_1`「对不起，宝石合成需要三颗以上的宝石！」（服务端
##     `_merge_badge_stone:54225-54228` 也是按 `quantity // 3` 一次全合，口径同源）；
##   · 页1 `upgradeEquip:215-239`：没料 → 「请放入装备！」；`nextId == 0` → 「该装备已经是最高阶！」；
##     `_fu1.count < needItemCnt` → `FAIL_PROMPT_2[0]` 替 `getItemstr(needItemId)`
##     =「很抱歉，你的<石名>不够」；最后那句金币闸门**表里没有 `needMoney`** ⇒ 原版恒不触发。
## 都过了才发**真协议**（`ITEM_CHANGE 1040` 子命令 26/27，只带**背包格号**）。
static func _点确定(宿主: Node, 页: Control) -> void:
	var 条 := 料(宿主, _投料[_页])
	if 条.is_empty():
		# ⚠️ 只发**原版那句话本身** —— 以前这里还缀着"（`EQUIP_STRENGTH_FAIL_PROMPT_6[0]` 替 %1）"
		#   那是**开发注记混进了玩家文案**（原版 `MDialog` 只说「请放入装备！」）。
		#   出处留在 `缺料文` 那条注释里就够了。
		宿主._通知(缺料文[_页])
		return
	if _页 == 0:
		if int(条.get("quantity", 1)) < 3:
			宿主._通知("对不起，宝石合成需要三颗以上的宝石！")
			return
	else:
		if 下一级id(条, 1) == 0:
			宿主._通知("该装备已经是最高阶！")
			return
		var 配置 := 徽章强化配置(str(条.get("id", "")))
		var 石id := int(配置.get("needItemId", 0))
		if not 配置.is_empty() \
				and 装备打造表.拥有数(宿主.get("_session"), 石id) < int(配置.get("needItemCnt", 0)):
			宿主._通知("很抱歉，你的%s不够" % 装备打造表.物品名(石id))
			return
	var 后端 = 宿主.get("_backend")
	var 方法 := "request_merge_badge_stone" if _页 == 0 else "request_stage_up_badge"
	if 后端 == null or not 后端.has_method(方法):
		宿主._通知("合成/打造要在服务端结算（离线不模拟）")
		return
	# ⚠️ 发的是**背包格号**（原版 `_itemData.position`），不是物品 id。
	# 发成功**不提示**（同 `功能窗口._成交修理`）：打造结果由回帧把格子刷出来。
	if not bool(后端.call(方法, _投料[_页])):
		宿主._通知(确定文[_页] + "请求发送失败")
