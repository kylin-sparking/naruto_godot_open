extends RefCounted

## 静音（NPC 00000019）「勾玉炼制」= 原版 `com/mxw/uifl/controls/equip/YuLianJinJieWindow`
## （360×407，标题「玉链进阶」）+ 三个页签面板 `YuLianUpgragePanel` / `GouYuCompositePanel` /
## `GouYuResetPanel`。场景由 `开发工具/原版服务窗.py 生成 勾玉炼制` 从 SPEC 烘，**别手改 .tscn**。
##
## 取证要点（逐件表与行号在 SPEC 的 `出处` 里，这里只记控制器要负责的那几条）
##   :38    `super(360,407,false)` ⇒ 宿主不画内容底；`:147-152` 类里自己 `setSkin(MYellow_background)`
##          摆 (5,58) 350×316 ⇒ 黄底**烘在页面里**（尺寸表 `内容底: false`，宿主再垫就是两块底）
##   :62/101 切页 = 从 `_contentBg` removeChild 旧的、addChild 新的 ⇒ 这边等价于「三枚容器只切 visible」
##          （口径同 宝石工艺 那三页签；面板在 AS3 里 `_width=_height=0`、子件全按绝对 local 画）
##   :67/76/85 提交钮文字随页签换：`EQUIP_STRENGTH_STRENGTH_BTN_NAMES[3]/[4]/[1]`
##          =「开始进阶 / 开始合成 / 开始重置」（`CN.as:9200` 的数组是 1 基命名 0 基下标）
##   :86    **只有页签2 那一支 `isDelay = true`**（原版防连点）⇒ 这边记在 `延后档` 里，门钉得住
##   TabButtonBar.as:21/92  枚间 `horizontalGap = 1`；`MTabButton.as:35-39` `set enabled(v)` ⇒
##          `selected = !v` ⇒ **选中那枚走 disabled 槽**（显示 `selectedUpSkin` = tag118）
##          且 `:16-33` 对 DISABLED 推 `skinFilters[STATE_UP]` = +0 ⇒ **不灰**、悬停也不变亮
##
## ⚠ 投料钮的初始文字：原版 `GouYuCompositePanel.showView:142` 与 `GouYuResetPanel.showView:85`
##   拿错成 `[2]`=「取出玉链」——可那两页放的是勾玉。2026-11-02 用户明确要求改正：
##   空格子写「放入勾玉」、有料写「取出勾玉」（页0 仍是「放入玉链 / 取出玉链」）。
##   这是**有意偏离 AS3** 的文案修正，别再照抄回 `[2]`。
##
## 协议面（2026-10-13 更正，此前这里写着"一条都不发"—— 早过时了）：
##   · **提交**三页各走一条真协议（§3.123）：`request_special_stage_up` / `request_merge_jade` /
##     `request_change_jade`，传的都是 `_itemData.position`；
##   · **投料**走**拖放**（落点件 `勾玉放入格.gd`，原版是 `ItemDropBox` 的 `UpShelfCursor`
##     光标收集态）—— 2026-10-13 接上；闸门（`满级或拆开提示`）现在只剩页0 玉链满阶、
##     页1 勾玉满级（2026-11-02 页2 的满级误判与拆分要求已按用户要求去掉）；
##   · 只有「材料4 购买」是 `ItemCaiLiaoBox.buyHandler` 那跳 `REQUEST_CASH_ITEM_INFO`（已接）。
##
## 2026-10-29 补的两条（用户实机报「拖进去没反应 / 悬停没详情框」，两条都是**缺件**不是接错）：
##   · **悬停详情框**：原版五枚格（三页 `ItemDropBox.itemCell` + 页0/页1 的 `resultCell`）全是
##     `SimpleItemCell`，`createChildren` 里每枚都挂 `MToolTipItem.createToolTip`（`SimpleItemCell.as:220`）
##     ⇒ 投料格与结果格**都得有提示框**。两套提示框场景里没烘（SPEC 生成物不许手改 .tscn）
##     ⇒ 运行期 `建提示框`，口径同 `徽章打造窗.建提示框`。
##   · **每页各一份料**：`YuLianJinJieWindow.as:56-59` 每次换页先对**离开那页** `backItemToEquip()`，
##     `:96-98` 再对新页 `showView()` 并把窗口的 `_item` 装上去、随即置 null ⇒ **切走即清，
##     回到一页永远是空的**。此前这里做成三页共用的 `static var _物品`，坏在：页1 放了勾玉、
##     切回页0 点提交，发的是**勾玉那一格的槽位**给 `request_special_stage_up`。
##
## 2026-10-31 补的四条（用户实机报：三页都默认塞一个玉链图标 / 放入钮没实装 /
## 消耗金币与成功率恒 0 / 合成成功三格与精玉灵珠灰态不对）：
##   · **幽灵图标**：`渲染` 曾把背包带进来的那件在**每次重绘**都重新装上，且 `_页/_料` 是静态、
##     关窗再开不清 ⇒ 三页各留一份。现在 `开窗` 那一轮复位 `_页/_料/_合成结果`，
##     宿主 `功能窗口._render_jade` 也照 `selectedBtnHandler:96-98` 把 `_jade_item` 置空（只喂一次）。
##   · **放入钮**：原版 `clickDropBtnHandler:57-72` 切 `UpShelfCursor` 光标收集态；本工程没有跟手件
##     ⇒ 弹一张只列**本页收得下**的清单（`放入选择器.弹`，判据同落点格 `勾玉放入格.可收`）。
##   · **消耗/几率**：三页各查各的键（`special.stageup.stage{阶+1}` / `jade.merge.level{级+1}`
##     且 `needMoney` 写死 0 / `jade.change.level{max(1,级)}`），文案 = `EQUIP_STRENGTH_DESC_TEMPLATE_0`，
##     金币不够付那个数换红。
##   · **合成结果三格 + 材料4**：1042 回包在**页1 在场**时交给 `收合成回帧`（`operationResultHandler:61-103`
##     摆 成功/退还/剩余），不发通用那句提示；材料4 角标 = `needItemCnt × ⌊枚数/3⌋`（不足一批按一批），
##     灰 = `拥有 < 需要`，格/图标/数量三层同一份灰。

const 页签名 := ["玉链升阶", "勾玉合成", "勾玉重置"]		# YU_LIAN_TAB_BUTTON_NAMES_1..3
const 面板名 := ["面板0", "面板1", "面板2"]
const 提交文 := ["开始进阶", "开始合成", "开始重置"]
const 投料文 := ["放入玉链", "放入勾玉", "放入勾玉"]		# 页1/2 空格子 = 放入勾玉（见文件头，用户 2026-11-02 要求改正）
const 投料钮路 := ["内容底/面板0/投料框0/投料钮0", "内容底/面板1/合成投料框/合成投料钮",
		"内容底/面板2/重置投料框/重置投料钮"]		# ⚠ 钮在**投料框里**，不是面板直属（`GouYu*Panel` 那三个框各是 `MUIComponent`）
const 延后档 := 2						# `:86` 只有页签2 `isDelay = true`

## 三页的落点格 / 结果格（`ItemDropBox.itemCell` / `resultCell`）。页2 是 `new ItemDropBox()`
## （**不带 resultCell**，`GouYuResetPanel:151`）⇒ 它没有结果格，别硬凑一个。
const 投料格路 := ["内容底/面板0/投料框0/投料格0", "内容底/面板1/合成投料框/合成投料格",
		"内容底/面板2/重置投料框/重置投料格"]
const 结果格路 := ["内容底/面板0/投料框0/结果格0", "内容底/面板1/合成投料框/合成结果格", ""]
## 投料之后钮文字（`YU_LIAN_DROP_BUTTON_NAMES` 的 `[1]`=取出玉链 / `[3]`=取出勾玉；见文件头坑⑦）。
const 取出文 := ["取出玉链", "取出勾玉", "取出勾玉"]
const 图标名 := "投料图标"
const 结果图标名 := "结果图标"
## 本窗投料框的落点件（场景是 SPEC 生成物、不许手改 .tscn ⇒ 运行期 `set_script`，先例 `徽章放入格.gd`）。
const 勾玉放入格 := preload("res://脚本/界面/组件/勾玉放入格.gd")
const 放入选择器 := preload("res://脚本/界面/组件/放入选择器.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 装备打造表 := preload("res://脚本/界面/装备打造表.gd")
const 格子提示框 := preload("res://脚本/界面/组件/格子提示框.gd")
const 物品提示场景 := preload("res://场景/界面/组件/物品提示框.tscn")
const 装备提示场景 := preload("res://场景/界面/组件/装备提示框.tscn")
const 灰度着色器 := preload("res://脚本/界面/组件/禁用灰度.gdshader")
## 三页的「本次操作…」说明块（`_resultTextField` / `_textField`，都是 `TextArea2` ⇒ RichTextLabel）。
## 页1 那句前缀 = `YU_LIAN_GOU_YU_COMPOSITE_DESCS[2]`（数组 1 基命名 ⇒ 下标2 是 `_3`「若合成失败…」）。
const 说明路 := ["内容底/面板0/结果区0/结果文0", "内容底/面板1/合成结果区/合成结果文",
		"内容底/面板2/重置材料盒/重置结果文"]
const 说明模板 := "[color=#ffffff]本次操作消耗金币：%s\n本次操作成功几率：%d%%[/color]"
const 合成失败语 := "[color=#ffffff]若合成失败不会对勾玉本身造成任何影响[/color]"
## 材料1/2/3 = 成功 / 退还 / 剩余（`operationResultHandler:61-103` 摆的是 `param1[0]/[3]/[6]` 三对）。
const 材料格路 := ["内容底/面板1/材料盒/材料1/材料1格", "内容底/面板1/材料盒/材料2/材料2格",
		"内容底/面板1/材料盒/材料3/材料3格"]
const 材料键 := [["success_count", "success_item_id"], ["failed_count", "failed_item_id"],
		["left_count", "left_item_id"]]
const 材料图标名 := "材料图标"
const 材料数量名 := "材料数量"
## 材料4 那格（子件 `材料4格_数量` / `材料4格_图标` 是 SPEC 烘的静态件）。
const 珠格 := "内容底/面板1/材料盒/材料4/材料4格"
## 精玉灵珠（`jade.merge.level2.needItemId`，`数据/物品.json`）。
const 灵珠id := 16000031

## 当前页签。原版是 `TabButtonBar.selectedIndex`（窗内状态）；这里做成 static 是为了
## 门/量具能在不点鼠标的情况下直接驱动 `切页`，跑完 `新会话()` 复位。
static var _页 := 0
## 三页**各一份**料（原版三个面板各持 `_itemData`）：`{}` = 那页现在没放。
## ⚠ 之前是三页共用一份 —— 见文件头「每页各一份料」。
static var _料: Array = [{}, {}, {}]
## 开窗时从背包带进来的那件 = 原版窗口的 `_item`（`showWindow:88` 存、`selectedBtnHandler:96-98`
## 装到新页后立刻清）。`渲染(物品)` 走的就是这一支。
static var _带入 := {}
## 1042 合成回包（`OPERATION_RESULT` → `工作台._宝石合成结果`）里那三对
## 成功/退还/剩余；`GouYuCompositePanel.operationResultHandler:61-103` 就是拿它摆材料1/2/3。
static var _合成结果 := {}
## 「放入」钮的选物清单（原版 `UpShelfCursor` 的等价通道，弹层在 `放入选择器`）。
static var _选择器: PopupMenu = null
## `渲染` 入口存一次：`切页` 只有 (页, 序) 两个参数，刷新要拿窗口接提示框（先例 `首领窗口.gd:138`）。
static var _宿主
static var _灰材质: ShaderMaterial = null


static func 新会话() -> void:
	_页 = 0
	_料 = [{}, {}, {}]
	_带入 = {}
	_合成结果 = {}
	if _选择器 != null and is_instance_valid(_选择器):
		_选择器.queue_free()
	_选择器 = null


static func 当前页() -> int:
	return _页


static func 料(页序: int) -> Dictionary:
	return _料[clampi(页序, 0, 2)]


## `宿主` = `功能窗口`（要 `_content` / `_通知`）。
## `开窗` = 这一轮是**开窗/换底栏页**（`功能窗口._刚开窗`）⇒ 原版是新建一扇窗：页签回 0、三页全空。
## 回帧引起的**重渲染**（`_刚开窗` 假）必须保住已放的那份料 —— 原版 `updateView` 是**按槽位重新读**
## （`YuLianUpgragePanel.as:112-126`），不是把格子清掉；2026-10-31 之前这里每轮都 `_料 = [{},{},{}]`，
## 于是拖进去的件会被任何一条状态帧抹掉。
static func 渲染(宿主: Node, 场景: PackedScene, 物品: Dictionary = {}, 开窗 := false) -> Control:
	_宿主 = 宿主
	if 开窗:
		_页 = 0
		_料 = [{}, {}, {}]
		_合成结果 = {}
	else:
		_对位(宿主)
	_带入 = 物品
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	建提示框(页)
	_接页签(页, 宿主)
	_接钮(页, 宿主)
	_挂投料格(页, 宿主)
	切页(页, _页)
	return 页


## 重渲染前把三页那份料**按槽位对齐**（= 原版 `updateView`）：
## 件没了 / 那一格换了件 ⇒ 清；还在 ⇒ 换成最新那行（枚数可能被服务端改过）。
static func _对位(宿主: Node) -> void:
	for i in 3:
		var 条: Dictionary = _料[i]
		if 条.is_empty():
			continue
		var 格 := int(条.get("slot_index", 0))
		if 格 <= 0:
			continue
		var 现 := 取条(宿主, 格)
		if 现.is_empty() or String(现.get("id", "")) != String(条.get("id", "")):
			_料[i] = {}
			continue
		var 新 := 现.duplicate(true)
		if int(新.get("slot_index", 0)) != 格:
			新["slot_index"] = 格
		_料[i] = 新


## 悬停详情框的两套节点场景里没烘（SPEC 生成物不许手改 .tscn）⇒ 运行期挂，
## 与 `徽章打造窗.建提示框` / `福袋窗._建提示框` 同一口径。
static func 建提示框(页: Control) -> void:
	for 项 in [["物品提示框", 物品提示场景], ["装备提示框", 装备提示场景]]:
		var 名 := str(项[0])
		if 页.get_node_or_null(名) != null:
			continue
		var 框 := (项[1] as PackedScene).instantiate() as Control
		框.name = 名
		框.mouse_filter = Control.MOUSE_FILTER_IGNORE
		页.add_child(框)


## 给一枚格接悬停。`物品` 空字典 = 这格现在没件 ⇒ 走 `格子提示框` 的"空格子把两套都收掉"那一支。
## 落点格已经是 `MOUSE_FILTER_STOP`（要接拖放），结果格是场景里的皮件（多半 IGNORE）⇒ 抬到 PASS。
static func 接提示(页: Control, 格: Control, 物品: Dictionary) -> void:
	if 格 == null:
		return
	if 格.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		格.mouse_filter = Control.MOUSE_FILTER_PASS
	格子提示框.接线(_宿主, 页, 格, 物品)


## 把落点件挂到三页的投料格上（运行期 `set_script`，先例 `徽章放入格.gd`）。
## 判据与"收不收"在组件里，这里只负责挂、刷新、以及落上之后那两道页面闸门。
static func _挂投料格(页: Control, 宿主: Node) -> void:
	for i in 投料格路.size():
		var 格 := 页.get_node(投料格路[i]) as Control
		格.set_script(勾玉放入格)
		格.set("本页", i)
		# 落点必须能接鼠标（场景里那些皮件多半是 IGNORE）。
		格.mouse_filter = Control.MOUSE_FILTER_STOP
		格.connect("请求放入", func(背包格: int) -> void: 收料(宿主, 页, i, 背包格))
		刷新页(页, 宿主, i)


## 落上一件合格料。原版三个 `validateItem` 在"收下"之前还有一道闸门，过了才 `_itemData = param1`；
## 这里照同一次序判，不过就**弹原版那句话、不收**。
static func 收料(宿主: Node, 页: Control, 页序: int, 背包格: int) -> void:
	if 背包格 <= 0:
		return
	var 提示 := 满级或拆开提示(宿主, 页序, 背包格)
	if not 提示.is_empty():
		宿主._通知(提示)
		return
	var 条 := 取条(宿主, 背包格).duplicate(true)
	# 稳定格位制：`slot_index` 恒 = 下标+1；离线示例件没这列 ⇒ 补上（同 `背包窗口._开勾玉炼制窗`）
	条["slot_index"] = 背包格
	_料[页序] = 条
	刷新页(页, 宿主, 页序)


## 取会话背包里那一格的条（`{}` = 空）。
static func 取条(宿主: Node, 背包格: int) -> Dictionary:
	if 宿主 == null or 宿主.get("_session") == null:
		return {}
	return 宿主._session._占用条(宿主._session.inventory, 背包格)


## 原版"收下之前"那道闸门。返回空串 = 收；否则是**逐字的原版提示**。
##   · 页0 `YuLianUpgragePanel.validateItem:88-92`：玉链满级（`EqpData.nextId == 0`）⇒
##     `FAIL_PROMPT_11[0]` 替 `_11[2]` =「该**玉链**已经是最高阶！」。nextId ⇔ `装备库.进阶目标`
##     （**空串 = 满级**，与徽章打造同一条真源）。
##   · 页1 `GouYuCompositePanel.validateItem:288-292`：勾玉满级（`StoneData.nextId == 0`）⇒
##     `FAIL_PROMPT_17` =「该勾玉已经是最高等级！」。nextId ⇔ `物品.stone_next`（同宝石）。
##   · 页2 `GouYuResetPanel.validateItem:113-117`：**只查"是不是勾玉"**，既没有满级判断、
##     也没有数量限制。2026-11-02 用户报「重置里拖入勾玉却弹『已经最高等级』/『请拆成1个』」——
##     前者是我们把页1 的满级闸错套到了页2，后者是照抄 AS3 的 `count > 1` 拒绝。
##     **用户明确要求偏离 AS3**：整摞可以直接放，一次操作消耗 1 个、生成 1 个
##     （服务端 `_change_jade_attribute:53959-53975` 本来就是 `quantity > 1 ⇒ -1 + 新件`）。
static func 满级或拆开提示(宿主: Node, 页序: int, 背包格: int) -> String:
	var 条 := 取条(宿主, 背包格)
	if 条.is_empty():
		return ""
	var 补零 := str(条.get("id", "")).pad_zeros(8)
	if 页序 == 0:
		if 游戏数据.装备进阶目标(补零).is_empty():
			return "该玉链已经是最高阶！"
		return ""
	if 页序 == 1 and int(游戏数据.item(补零).get("stone_next", 0)) <= 0:
		return "该勾玉已经是最高等级！"
	return ""


## 按当前那份料刷新这一页：投料格的图标、**结果格**（原版 `resultCell` = 下一件预览）、
## 以及投料钮文字（有料 ⇒ 取出；没料 ⇒ 回原版那串初始文字）。
static func 刷新投料(页: Control, 宿主: Node, 页序: int) -> void:
	var 条: Dictionary = _料[页序]
	var 格 := 页.get_node(投料格路[页序]) as Control
	var 图标 := 格.get_node_or_null(图标名) as TextureRect
	var 结果 := 页.get_node_or_null(结果格路[页序]) as Control if not 结果格路[页序].is_empty() else null
	var 下一件 := "" if 条.is_empty() else 下一件id(页序)
	# 原版三页的 `itemCell` 与页0/页1 的 `resultCell` 全是 `SimpleItemCell` ⇒ **空料也接**
	# （`格子提示框` 的空格那一支负责把两套提示框都收掉，不留上一件的残影）。
	接提示(页, 格, 条)
	接提示(页, 结果, 预览载荷(下一件))
	if 条.is_empty():
		var 原钮 := 页.get_node(投料钮路[页序]) as Button
		原钮.text = 投料文[页序]
		if 图标 != null:
			图标.texture = null
		_清结果图标(结果)
		return
	if 图标 == null:
		图标 = _新建图标(格, 图标名)
	图标.texture = 游戏数据.item_icon(String(条.get("id", "")))
	(页.get_node(投料钮路[页序]) as Button).text = 取出文[页序]
	if 结果 != null:
		var 结果图标 := 结果.get_node_or_null(结果图标名) as TextureRect
		if 结果图标 == null:
			结果图标 = _新建图标(结果, 结果图标名)
		结果图标.texture = null if 下一件.is_empty() else 游戏数据.item_icon(下一件)


## 一页的**全部**运行期态：落点格/结果格/钮文字 + 「本次操作…」说明 + 材料4（精玉灵珠）
## + 材料1/2/3（合成回包）。原版这三块分别由 `validateItem` / `updateDescription` /
## `operationResultHandler` 刷 ⇒ 这里收成一处，任何原因重画页面都走它。
static func 刷新页(页: Control, 宿主: Node, 页序: int) -> void:
	刷新投料(页, 宿主, 页序)
	_填说明(页, 宿主, 页序)
	if 页序 == 1:
		_填材料4(页, 宿主)
		_填合成结果(页)


## 这一页这一次的 `_configure`。三页各查各的键（三处 `setConfigure`）：
##   页0 `special.stageup.stage{stage+1}`（`YuLianUpgragePanel.as:187-190`）；
##   页1 `jade.merge.level{stoneLevel+1}` 且 **`needMoney` 写死 0**（`GouYuCompositePanel.as:301-305`）；
##   页2 `jade.change.level{stoneLevel||1}`（`GouYuResetPanel.as:160-164`）。
## 满级/没有下一件时返回空 ⇒ 显示 0 金币 0%（AS3 的 else 那一支）。
static func _配置(页序: int, 条: Dictionary) -> Dictionary:
	if 条.is_empty():
		return {}
	var 物id := String(条.get("id", ""))
	var 物: Dictionary = 游戏数据.item(物id)
	if 页序 == 0:
		var 阶 := int(物.get("stage", 0))
		if 阶 <= 0 or 游戏数据.装备进阶目标(物id).is_empty():
			return {}
		return 装备打造表.取特殊进阶(阶 + 1)
	if 页序 == 1:
		var 级 := int(物.get("stone_level", 0))
		if 级 <= 0 or int(物.get("stone_next", 0)) <= 0:
			return {}
		var 行: Dictionary = 装备打造表.取勾玉合成(级 + 1).duplicate(true)
		行["needMoney"] = 0
		return 行
	return 装备打造表.取勾玉重置(maxi(1, int(物.get("stone_level", 0))))


## `_resultTextField` / `_textField` = `EQUIP_STRENGTH_DESC_TEMPLATE_0`（￥ 金币 / $ 几率）。
## 金币不够付 ⇒ 那个数换红（三页同一句 `cocoNuts < needMoney`）；页1 前面拼「若合成失败…」
## （`updateDescription:181`），页2 前面拼「勾玉属性：」+ 绿字（`GouYuResetPanel:92-106`）。
## 没放东西 = 0 金币 0%（三页的 else 分支）。
static func _填说明(页: Control, 宿主: Node, 页序: int) -> void:
	var 文 := 页.get_node_or_null(说明路[页序]) as RichTextLabel
	if 文 == null:
		return
	var 条: Dictionary = _料[页序]
	var 配置 := _配置(页序, 条)
	var 钱数 := 0
	var 率 := 0
	if not 配置.is_empty():
		钱数 = int(配置.get("needMoney", 0))
		率 = int(配置.get("prob", 0))
	var 金币 := 0
	if 宿主 != null and 宿主.get("_session") != null:
		金币 = int(宿主._session.player_stats.get("gold", 0))
	var 钱文本 := str(钱数)
	if 金币 < 钱数:
		钱文本 = "[color=#ff0000]%s[/color]" % 钱文本
	var 说明 := 说明模板 % [钱文本, 率]
	if 页序 == 1:
		说明 = 合成失败语 + "\n" + 说明
	elif 页序 == 2 and not 条.is_empty():
		var 物: Dictionary = 游戏数据.item(String(条.get("id", "")))
		var 技能号 := int(物.get("gouyu_skill", 0))
		var 层 := int(物.get("gouyu_level", 0))
		var 名 := String(游戏数据.skill_text(技能号).get("name", ""))
		if 名.is_empty():
			名 = str(技能号)
		说明 = "勾玉属性：[color=#00ff00]%s+%d层[/color]\n" % [名, 层] + 说明
	文.text = 说明


## 材料4「精玉灵珠」：图标是静态配置造的（`showView:140-141`），格内数字 = **需要数**
## （`_box4.itemCell.label = getNeedItemCout()`），灰 = **拥有 < 需要**（`updateDescription:161-170`）。
## 需要数 = `needItemCnt × floor(勾玉枚数/3)`，不足一批按一批算（`:307-311`）；
## 拥有数按同 id 各摞累加（`ItemCaiLiaoBox.count` = `isBagExistItem`）。
static func _填材料4(页: Control, 宿主: Node) -> void:
	var 格 := 页.get_node_or_null(珠格) as Control
	if 格 == null:
		return
	var 数 := 格.get_node_or_null("材料4格_数量") as Label
	var 图 := 格.get_node_or_null("材料4格_图标") as TextureRect
	var 条: Dictionary = _料[1]
	var 需 := 0
	var 拥有 := 0
	if not 条.is_empty():
		var 配置 := _配置(1, 条)
		var 基数 := maxi(0, int(配置.get("needItemCnt", 0)))
		需 = 基数 * int(int(条.get("quantity", 1)) / 3)
		if 需 <= 0:
			需 = 基数
		拥有 = 装备打造表.拥有数(宿主.get("_session"), int(配置.get("needItemId", 灵珠id)))
	if 数 != null:
		数.text = " " if 条.is_empty() or 需 <= 0 else str(需)
	var 要灰 := 条.is_empty()
	if not 条.is_empty() and 需 > 0:
		要灰 = 拥有 < 需
	_套珠灰(格, 数, 图, 要灰)


static func 珠灰材质() -> ShaderMaterial:
	if _灰材质 == null:
		_灰材质 = ShaderMaterial.new()
		_灰材质.shader = 灰度着色器
	return _灰材质


## 灰要打满整格：Godot 的 `material` 不传给子节点 ⇒ 格 / 数量 / 图标三层各挂同一份
## （§3.18.9 精炼页量出来的；与本场景烘的 `mat1` 等价）。
static func _套珠灰(格: CanvasItem, 数: CanvasItem, 图: CanvasItem, 要灰: bool) -> void:
	var 材: Material = 珠灰材质() if 要灰 else null
	for 件 in [格, 数, 图]:
		if 件 != null:
			件.material = 材


## 材料1/2/3 = 成功 / 退还 / 剩余（`GouYuCompositePanel.operationResultHandler:61-103`）。
## 计数 ≤ 0 的那格整件清掉（原版 `itemCell.itemData = null` ⇒ 只剩空皮），> 0 才长图标 + 右下角标。
static func _填合成结果(页: Control) -> void:
	for i in 3:
		var 格 := 页.get_node_or_null(材料格路[i]) as Control
		if 格 == null:
			continue
		var 数 := int(_合成结果.get(String(材料键[i][0]), 0))
		var 图 := 格.get_node_or_null(材料图标名) as TextureRect
		var 标 := 格.get_node_or_null(材料数量名) as Label
		if 数 <= 0:
			if 图 != null:
				格.remove_child(图)
				图.queue_free()
			if 标 != null:
				格.remove_child(标)
				标.queue_free()
			continue
		if 图 == null:
			图 = TextureRect.new()
			图.name = 材料图标名
			图.position = Vector2(3, 3)
			图.size = Vector2(34, 34)
			图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			图.mouse_filter = Control.MOUSE_FILTER_IGNORE
			格.add_child(图)
		图.texture = 游戏数据.item_icon(str(int(_合成结果.get(String(材料键[i][1]), 0))).pad_zeros(8))
		if 标 == null:
			标 = Label.new()
			标.name = 材料数量名
			标.position = Vector2(0, 20)
			标.size = Vector2(40, 20)
			标.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			标.add_theme_font_size_override("font_size", 12)
			标.add_theme_color_override("font_color", Color.WHITE)
			标.mouse_filter = Control.MOUSE_FILTER_IGNORE
			格.add_child(标)
		标.text = str(数)


## 1042 回包（成功/退还/剩余）落到页1 的三枚材料格。原版 `operationResultHandler` 同时把投料格
## 与结果格清空；页0/页2 的回包在原版是**空函数**（`YuLianUpgragePanel:54-56` / `GouYuResetPanel:94-96`）
## ⇒ 不是当前页1 的时候一个字都不动。
static func 收合成回帧(宿主: Node, 结果: Dictionary) -> void:
	if _页 != 1:
		return
	_合成结果 = 结果.duplicate(true)
	_料[1] = {}


## 结果格那件的提示框载荷：原版是 `ItemFactory.createSingleItem(nextId)`（**只有 id**，
## 没有背包行的枚数/词条）⇒ 这边同样只给 id + 1 枚；空串 = 这格没件。
static func 预览载荷(下一件: String) -> Dictionary:
	return {} if 下一件.is_empty() else {"id": 下一件, "quantity": 1}


static func _新建图标(格: Control, 名: String) -> TextureRect:
	var 图标 := TextureRect.new()
	图标.name = 名
	图标.position = Vector2.ZERO
	图标.size = 格.size
	图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	格.add_child(图标)
	return 图标


static func _清结果图标(结果: Control) -> void:
	if 结果 == null:
		return
	var 图标 := 结果.get_node_or_null(结果图标名) as TextureRect
	if 图标 != null:
		图标.texture = null


## 结果格那件：页0 原版是 `getEquipUpgradeItemData`（**进阶预览**，不是一件普通物品，本工程没这份数据）
## ⇒ 空着；页1 是 `createSingleItem(nextId)`（下一级勾玉）⇒ 取 `stone_next`；页2 没有结果格。
static func 下一件id(页序: int) -> String:
	if 页序 != 1:
		return ""
	var 下 := int(游戏数据.item(String(料(页序).get("id", ""))).get("stone_next", 0))
	return "" if 下 <= 0 else str(下).pad_zeros(8)


## 三枚页签：位置/宽/四档皮/四态同色都已烘 ⇒ 这里只接信号。
static func _接页签(页: Control, 宿主: Node) -> void:
	var 条 := 页.get_node("分页") as Control
	for i in 条.get_child_count():
		var 钮 := 条.get_child(i) as Button
		钮.pressed.connect(_点页.bind(页, i))


static func _点页(页: Control, 序: int) -> void:
	切页(页, 序)


## = `selectedBtnHandler`（`:50-103`）：换选中枚 + 换面板 + 换提交钮文字。
## 原版这里还有 `if(!isDatReady()) return;`（`:52-55`，`dats = [BaoShi, FuZhuWuPin]` `:39`）
## ⇒ 离线没有那两份数据时**原版连面板都不建**；本工程把三页静态件全烘进场景、只切 visible，
##   因为静态件本身就是 `createChildren` 的产物（取证表里标「静态」的那些行），
##   少画一件就是"窗开得出、里面是空的"。运行期数据一回来由 `填数` 覆盖。
static func 切页(页: Control, 序: int) -> void:
	var 旧 := _页
	_页 = clampi(序, 0, 2)
	# `:56-59` 先对**离开那页** `backItemToEquip()` ⇒ 三页各一份料、切走即清。
	# 同页也走这一句：原版 `showWindow:88-95` 在 `selectedIndex` 没变时直接调本函数，
	# 那一次同样先清掉旧的、再把带进来的那件装上。
	_清料(页, 旧)
	for i in 3:
		(页.get_node("分页/页签%d" % i) as Button).disabled = (i == _页)
		(页.get_node("分页/页签%d" % i) as Button).button_pressed = (i == _页)
		(页.get_node("内容底/%s" % 面板名[i]) as Control).visible = (i == _页)
	(页.get_node("提交钮") as Button).text = 提交文[_页]
	# `:96-98` 新页 `showView()`（钮文字回初始那串）→ 有带来的件就装上（原版 `validateItem(_item)`）→ 清 `_item`。
	if not _带入.is_empty():
		_料[_页] = _带入
		_带入 = {}
	# 原版每次进页都 `showView()` + `updateDescription()` ⇒ 说明块/材料格按**这一页现在的料**重画。
	刷新页(页, _宿主, _页)


## 清掉某一页的放置件（= 原版 `backItemToEquip`：置空 `_itemData` + 格图标 + 钮文字翻回初始那串）。
static func _清料(页: Control, 页序: int) -> void:
	if _料[页序].is_empty():
		return
	_料[页序] = {}
	刷新页(页, _宿主, 页序)


## 提交钮走**真协议**（§3.123）；投料钮 2026-10-31 接上了（见 `_点投料` 的清单那一支）。
## 「材料4」的购买钮 2026-10-11 接上了 —— 它就是
## 共用材料格 `ItemCaiLiaoBox.buyHandler:46-55` 那跳 `REQUEST_CASH_ITEM_INFO`
## （`id = itemCell.itemData.id`），走 `功能窗口.请求商城商品` 的统一出口。
static func _接钮(页: Control, 宿主: Node) -> void:
	(页.get_node("提交钮") as Button).pressed.connect(_提交.bind(宿主))
	for i in 投料钮路.size():
		var 钮 := 页.get_node(投料钮路[i]) as Button
		钮.pressed.connect(_点投料.bind(宿主, 页, i))
	# 材料4 = 「精玉灵珠」`16000031`（`数据/物品.json`）。
	(页.get_node("内容底/面板1/材料盒/材料4/材料4购买钮") as Button).pressed.connect(
			func() -> void: 宿主.请求商城商品("16000031"))


## 「投料 / 取出」那枚钮（`clickDropBtnHandler:57-72`）：
## **已放** ⇒ 原版 `backItemToEquip()` + `showView()`（清放置、钮文字翻回初始那串），**不发帧**；
## **没放** ⇒ 原版切 `UpShelfCursor` 光标收集态、等玩家点背包格。本工程没有跟手光标件
## ⇒ 同 `秘笈合成窗口._弹残卷选择`：在游标处弹一张**只列本页收得下**的清单（2026-10-31 用户报
## 「放入钮没实装、只能拖」）。落点格的拖放两路并存，判据同一把闸 `勾玉放入格.可收`。
static func _点投料(宿主: Node, 页: Control, 序: int) -> void:
	if not _料[序].is_empty():
		_料[序] = {}
		刷新页(页, 宿主, 序)
		return
	var 清单 := 放入选择器.背包候选(宿主.get("_session"),
			func(条: Dictionary) -> bool: return 勾玉放入格.可收(String(条.get("id", "")), 序))
	if 清单.is_empty():
		宿主._通知("背包里没有可放入的%s" % ("玉链" if 序 == 0 else "勾玉"))
		return
	_选择器 = 放入选择器.弹(页, 清单,
			func(行: Dictionary) -> void: 收料(_宿主, 页, 序, int(行.get("格", 0))))


## 三页的提交**各对应一条已有的后端请求**（而且那三条以前**全工程零调用点** —— §3.123）：
##   页0 玉链升阶 = `requestSpecialStageUp`（`YuLianUpgragePanel.as:171`）
##   页1 勾玉合成 = `requestMergeJade`（`GouYuCompositePanel.as:329`）
##   页2 勾玉重置 = `requestChangeJade`（`GouYuResetPanel.as:202`）
## 三处传的都是 `_itemData.position`（= 从背包带进来的那件）。
static func _提交(宿主: Node) -> void:
	var 条 := 料(_页)
	if 条.is_empty():
		宿主._通知("请先从背包里选中一件玉链/勾玉再开这扇窗（投料那一跳）")
		return
	var 位置 := int(条.get("slot_index", 条.get("equip_position", 0)))
	if 位置 == 0:
		宿主._通知("这件物品没有原版槽位，无法发送请求")
		return
	var 后端 = 宿主._backend
	var 方法: String = ["request_special_stage_up", "request_merge_jade", "request_change_jade"][clampi(_页, 0, 2)]
	var 成: bool = 后端 != null and 后端.has_method(方法) and bool(后端.call(方法, 位置))
	# 发成功**不提示**（同 `功能窗口._成交修理`）：炼制结果由回帧把格子刷出来。
	# 只有没发出去（离线/后端没这个方法）才要说一句，那才是玩家看得到的"没反应"。
	if not 成:
		宿主._通知("%s要在服务端结算（离线不模拟）" % 提交文[clampi(_页, 0, 2)])
