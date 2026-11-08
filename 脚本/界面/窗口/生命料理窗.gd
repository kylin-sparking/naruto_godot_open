extends RefCounted

## 阿凯（NPC `00000020`，模板 20，称号「生命の料理」）「生命料理」= 原版
## `com/mxw/uifl/controls/equip/LiaoLiMadeWindow`（241×319，标题「神 秘 料 理」）。
## 场景由 `开发工具/原版服务窗.py 生成 生命料理` 从 SPEC 烘（12 件、逐条带 AS3 行号），
## **别手改 .tscn** —— 门会重跑生成器比期望表（`数据/界面/生命料理_期望.json`）。
##
## 控制器管原版也归运行期管的那几件：
##   ① 「需要金币：」那个数的**颜色**（数是静态配置 2000 ⇒ 已烘进场景）：
##      `:364` `getConditionString(money, cocoNuts, "#ffffff")` ⇒ `BaseUtil.as:118-122`
##      的式子 `money > cocoNuts ? "#ff0000" : "#ffffff"` ⇒ **金币不够时那个 2000 变红**；
##   ② 两枚投料格收料（10-23 接上）：落点件运行期 `set_script` 挂（同 `徽章放入格`/`勾玉放入格`
##      那一族，**不动场景**）；类型闸在 `料理放入格.可收`（= `ItemType.as:144-147`
##      `int(id/10000) == LiaoLiCaiLiao`，`:61` `LiaoLiCaiLiao = 1601`），
##      **同种料**那道闸在这儿（`:88-93` `isSameCaiLiao` = 只比 `id`）；
##   ③ 「放入材料 / 取出料理」那颗钮的两态（`clickDropBtnHandler:212-229`）；
##   ④ 「制作」那颗钮的四道闸 + 500ms 后才发帧（`zhiZhuoHandler:272-289`
##      → `EquipManager.showLoadingBar:167-181`，第三参默认 **500**）；
##   ⑤ `1822` 回帧：`onBuffHeCheng_updateStatus:187-203`（成功换钮文字 + 填成品格，
##      失败只弹一句），之后**必定** `updateCaiLiao()` + 重算消耗色。
##
## 状态放**会话级 static**（不是页内）：这页会被 `功能窗口.gd:435` 那批回帧重建，
## 状态跟着页一起没的话"刚做出来的成品"就凭空消失。重建后 `_刷新全` 按同一份状态重画
## ⇒ 编辑器 = 运行期，且回帧**不靠**拆页来刷新（#312 那一族：回帧拆页 ⇒ 按住的两下落空）。
##
## ⚠ 三条**主动偏离**（都登记在门与 `真值/世界/外来帧与上行接线.md`，不是照抄）：
##   1. 原版收料走**光标收集态**（`:221-223` `CursorManager.showCursorUI("UpShelfCursor")` +
##      `UIConfig.dropValidateFun`），本工程没有跟手光标件 ⇒ 用**拖放**（同徽章/勾玉/宝石四页）；
##      于是「只能放入料理材料」那句在拖放路径下说不出来（`_can_drop_data` 返回假 = 落不上去），
##      改由「放入材料」那颗钮说；
##   2. 原版两处弹话走 `MDialog.showMessageDialog`（居中模态），本工程同族一律走通知条
##      （与 `徽章打造窗.满级或破碎提示` 一条口径）；
##   3. 原版点制作先挂那根 `GeneralInternalLoading` 进度条，**500 毫秒后**才发帧
##      （`EquipManager:167-181`，`if(this._loading) return` 是重入闸）。
##      本工程没移植那根条 ⇒ 留同一只 500ms 的表 + 同一个重入闸，把「制作料理中」用通知条说，
##      发帧时刻与原版一致。要那根条得单独做件（等点头）。
##
## 协议面（**已接真上下行**，10-23）：`BUFF_HECHENG = 1822`（`SendOpCodes.as:265`）。
##   上行 = `BuffHeChengProcessor.as:35-38` `requestBuffHeCheng_makeBuff({item0,item1})`
##   （`:19-25` = `writeInt(子命令)` + AMF 对象，两值都是**背包格号** = `ItemData.position`）
##   ⇒ 工程侧 `后端连接.request_buff_fusion(槽1, 槽2)` 发 `1822:1:<槽1>:<槽2>`；
##   下行 = `handleBuffHeChengAction:55-62` 的 **cmd 2** = `updateStatus`（本机服务端
##   `handle_buff_he_cheng:38668-38753` 回文本 `1822:2:<成品物品号>`，0 = 失败/不够条件）。
##   ⚠ 本机服务端硬条件（不是我加的闸门）：两枚都得 `item_id//10000 == 1601`、**不同种**、
##   金币够 `cooking_cost()`、背包放不下且两堆都不会清空时判失败 ⇒ 一律回 `1822:2:0`。

const 料理放入格 := preload("res://脚本/界面/组件/料理放入格.gd")
const 放入选择器 := preload("res://脚本/界面/组件/放入选择器.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

const 花费 := 2000		# `BuffHeCheng.json` `items.info.money`（静态配置，已烘在场景里）
const 色够 := Color("#ffffff")		# `:364` 传进去的第三参
const 色不够 := Color("#ff0000")		# `BaseUtil.as:120` 的第四参默认值
const 格路 := ["材料1", "材料2", "成品格"]		# 前两枚是投料格，第三枚是成品格
const 图标名 := "投料图标"
const 进度毫秒 := 500		# `EquipManager.showLoadingBar:167` 第三参默认值

const 文放入 := "放入材料"		# LIAOLIMADEWINDOW_DROP_BUTTON_NAME
const 文取出 := "取出料理"		# LIAOLIMADEWINDOW_PICK_UP_BUTTON_NAME
const 文材料齐 := "材料放入完毕，您现在可以制作料理了"		# LIAOLIMADEWINDOW_CAI_LIAO_READY(3085)
const 文缺材料 := "请先放入材料"		# LIAOLIMADEWINDOW_NO_CAI_LIAO(389)
const 文金币少 := "很抱歉，你的金币不够"		# EQUIP_STRENGTH_FAIL_PROMPT_2_1(636) 替 _2(635)
const 文非料 := "只能放入料理材料"		# LIAOLIMADEWINDOW_NOT_CAI_LIAO
const 文同种 := "只能放入两种不同的料理材料"		# LIAOLIMADEWINDOW_SAME_CAI_LIAO
const 文制作中 := "制作料理中"		# LIAOLIMADEWINDOW_ZHI_ZUO_LIAO_LI
const 文成功 := "制作料理成功"		# LIAOLIMADEWINDOW_ZHI_ZUO_SUCCESS
const 文失败 := "很抱歉，制作料理失败"		# LIAOLIMADEWINDOW_ZHI_ZUO_FAIL

## 会话级：`_料[i]` = 第 i 枚投料格占的**背包格号**（−1 = 空）；`_成品` = 成品物品号（0 = 没有）。
static var _料 := [-1, -1]
static var _成品 := 0
static var _制作中 := false		# `showLoadingBar:169-172` `if(this._loading) return` 那道重入闸


static func 新会话() -> void:
	_料 = [-1, -1]
	_成品 = 0
	_制作中 = false


static func 投料格() -> Array:
	return _料.duplicate()


static func 成品号() -> int:
	return _成品


## `宿主` = `功能窗口`（要 `_content` / `_通知` / `_session` / `_backend`）。
static func 渲染(宿主: Node, 场景: PackedScene) -> Control:
	var 页 := 场景.instantiate() as Control
	## 这页自己接 `buff_fusion_received` 原地刷 ⇒ 必须挂旗，否则宿主 `_flush_refresh`
	## 会在**每一发** 1822 回帧上把整页拆掉重建（`功能窗口.gd:4183-4194`，#312 同一族：
	## 按下与抬起落不到同一节点 ⇒ 联网时整页点不动，而离线一次点击照旧生效）。
	页.set_meta("page_self_refresh", true)
	宿主._content.add_child(页)
	# 三枚格都是原版 `SimpleItemCell`（`LiaoLiMadeWindow.as:333/338/347`；`SimpleItemCell.as:220`
	# 一有 itemData 就挂 MToolTipItem）⇒ 悬停要弹物品详情。场景是 SPEC 生成物不手改，
	# 提示框运行期挂（同勾玉炼制/宝石镶嵌那两页）。
	宿主._给页挂提示框(页)
	for 序 in 2:
		var 格 := 页.get_node(格路[序]) as Control
		格.set_script(料理放入格)			# 落点件运行期挂（场景是 SPEC 生成物，不动 .tscn）
		## ⚠ 带参数的信号**不许用 `.bind()`**：`bind` 把绑进去的实参排在**信号实参之后**，
		## `_收到料(宿主, 页, 序, 背包格)` 就变成 `_收到料(背包格, 宿主, 页, 序)` ⇒ 运行期
		## `Cannot convert argument 1 from int to Object`、整条投料静默死掉。同 `徽章打造窗.gd:104` 用闭包。
		格.connect("请求放入", func(背包格: int) -> void: _收到料(宿主, 页, 序, 背包格))
		格.connect("请求取出", func() -> void:
			if not _制作中:
				_料[序] = -1
				刷新料(页, 宿主, 序))
	(页.get_node("放入钮") as Button).pressed.connect(_点放入.bind(宿主, 页))
	(页.get_node("制作钮") as Button).pressed.connect(_点制作.bind(宿主, 页))
	_接回帧(页, 宿主)
	_刷新全(页, 宿主)
	return 页


## 订阅 `1822:2` 那一帧 ⇒ 原地改（回帧不许靠拆页刷新，#312 那一族）。
static func _接回帧(页: Control, 宿主: Node) -> void:
	var 后: Node = 宿主.get("_backend") as Node
	if 后 == null or not 后.has_signal("buff_fusion_received"):
		return
	后.connect("buff_fusion_received", func(信息: Dictionary) -> void:
		if is_instance_valid(页) and int(信息.get("action", -1)) == 2:
			_于合成(页, 宿主, 信息))


## `onBuffHeCheng_updateStatus:187-203`。⚠ 末尾那两句（`updateCaiLiao` + 重算消耗色）
## 在**成功与失败两支之外**，无论哪支都要走 ⇒ 顺序照抄。
static func _于合成(页: Control, 宿主: Node, 信息: Dictionary) -> void:
	var 号 := int(信息.get("item_id", 0))
	if 号 == 0:
		宿主._通知(文失败)
	else:
		宿主._通知(文成功)
		_成品 = 号
	_刷新全(页, 宿主)


static func _刷新全(页: Control, 宿主: Node) -> void:
	刷新料(页, 宿主, 0)
	刷新料(页, 宿主, 1)
	_刷新成品(页, 宿主)
	_上消耗色(页, 宿主)


static func _条(宿主: Node, 背包格: int) -> Dictionary:
	if 宿主 == null or 宿主.get("_session") == null:
		return {}
	var 会: Node = 宿主.get("_session") as Node
	return 会._占用条(会.inventory, 背包格) as Dictionary


## 同种料判定要按 **id**，所以取总量走的是 `isBagExistItem(id)` 那一句的等价物。
static func _背包总量(宿主: Node, 物品号: int) -> int:
	if 宿主 == null or 宿主.get("_session") == null:
		return 0
	var 总 := 0
	for 项 in ((宿主.get("_session") as Node).inventory as Array):
		if int((项 as Dictionary).get("id", 0)) == 物品号:
			总 += int((项 as Dictionary).get("quantity", 0))
	return 总


## `updateCaiLiao:110-146`：格里有料就按**该物品在背包里的总量**写角标；总量掉到 0 ⇒ 清这一格。
## 没料 ⇒ `itemData = null` ⇒ `hideIcon` ⇒ 角标是一个空格（不是 "0"、不是空字符串）。
static func 刷新料(页: Control, 宿主: Node, 序: int) -> void:
	var 格 := 页.get_node(格路[序]) as Control
	var 图标 := 格.get_node_or_null(图标名) as TextureRect
	var 条 := _条(宿主, _料[序]) if _料[序] > 0 else {}
	if 条.is_empty():
		_料[序] = -1
		if 图标 != null:
			图标.texture = null
		(格.get_node("%s_数量" % 格路[序]) as Label).text = " "
		宿主._接打造提示(页, 格, 0)		# 空格 ⇒ 悬停时把详情框收掉
		return
	var 总量 := _背包总量(宿主, int(条.get("id", 0)))
	if 总量 <= 0:
		_料[序] = -1
		if 图标 != null:
			图标.texture = null
		(格.get_node("%s_数量" % 格路[序]) as Label).text = " "
		宿主._接打造提示(页, 格, 0)
		return
	if 图标 == null:
		图标 = TextureRect.new()
		图标.name = 图标名
		图标.position = Vector2.ZERO
		图标.size = 格.size
		图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE		# 缺省 KEEP_SIZE 会被贴图顶大（本工程栽过）
		图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		图标.mouse_filter = Control.MOUSE_FILTER_IGNORE
		格.add_child(图标)
	图标.texture = 游戏数据.item_icon(str(int(条.get("id", 0))).pad_zeros(8))
	(格.get_node("%s_数量" % 格路[序]) as Label).text = str(总量)
	宿主._接打造提示(页, 格, int(条.get("id", 0)), 总量)


## 成品格。`setResultData:298-303` 里 **`_resultCell.label = "1"` 是原版明写的一句**（不是按 count 算的），
## 所以有成品时角标是 "1"；`pickItemOut:207` 把 `itemData = null` ⇒ `hideIcon` ⇒ 角标回到一个空格。
static func _刷新成品(页: Control, 宿主: Node) -> void:
	var 格 := 页.get_node("成品格") as Control
	var 图标 := 格.get_node_or_null(图标名) as TextureRect
	(格.get_node("成品格_数量") as Label).text = "1" if _成品 > 0 else " "
	if _成品 <= 0:
		if 图标 != null:
			图标.texture = null
	else:
		if 图标 == null:
			图标 = TextureRect.new()
			图标.name = 图标名
			图标.position = Vector2.ZERO
			图标.size = 格.size
			图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			图标.mouse_filter = Control.MOUSE_FILTER_IGNORE
			格.add_child(图标)
		图标.texture = 游戏数据.item_icon(str(_成品).pad_zeros(8))
	宿主._接打造提示(页, 格, _成品, 1)		# `_成品=0` ⇒ 空物品、悬停只收框
	var 钮 := 页.get_node("放入钮") as Button
	钮.text = 文取出 if _成品 > 0 else 文放入		# `:198` / `:207` 两支各自改 `_dropBtn.text`


# 拖放按 dropItemHandler:146-168 替换目标格，不走光标收集的 validateItem。
static func _收到料(宿主: Node, 页: Control, 序: int, 背包格: int) -> void:
	if _制作中:
		return
	var 条 := _条(宿主, 背包格)
	if 条.is_empty():
		return
	if not 料理放入格.可收(int(条.get("id", 0))):
		宿主._通知(文非料)
		return
	if _同种(宿主, 背包格, _料[1 - 序]):
		宿主._通知(文同种)
		return
	_料[序] = 背包格
	刷新料(页, 宿主, 序)


## `isSameCaiLiao:131-138`：两边都在 ⇒ 只比 `id`。
static func _同种(宿主: Node, 甲格: int, 乙格: int) -> bool:
	var 甲 := _条(宿主, 甲格)
	var 乙 := _条(宿主, 乙格)
	if 甲.is_empty() or 乙.is_empty():
		return false
	return int(甲.get("id", 0)) == int(乙.get("id", 0))


## `clickDropBtnHandler:212-229`：文字是「取出料理」⇒ `pickItemOut`；
## 否则两格都满 ⇒ 弹「材料放入完毕…」，不然弹公共「放入选择」清单（2026-11-08）。
## 清单落进**第一个空格**（原版光标在手上、点哪格进哪格；本工程一格一键的等价通道）。
static func _点放入(宿主: Node, 页: Control) -> void:
	if _成品 > 0:
		_成品 = 0
		_刷新成品(页, 宿主)		# `pickItemOut:203-208`：只清成品，投料格不动
		return
	if _料[0] > 0 and _料[1] > 0:
		宿主._通知(文材料齐)
		return
	var 序 := 0 if _料[0] <= 0 else 1
	var 清单 := 放入选择器.背包候选(宿主.get("_session"),
			func(条: Dictionary) -> bool: return 料理放入格.可收(int(条.get("id", 0))))
	if 清单.is_empty():
		宿主._通知("背包里没有可放入的料理材料")
		return
	放入选择器.弹(页, 清单,
			func(行: Dictionary) -> void: _收到料(宿主, 页, 序, int(行.get("格", 0))))


## `zhiZhuoHandler:272-289` 四道闸按原序：有成品先清 → 缺料 → 金币不够 → 才挂进度条发帧。
static func _点制作(宿主: Node, 页: Control) -> void:
	if _成品 > 0:
		_成品 = 0
		_刷新成品(页, 宿主)
	if _料[0] < 0 or _料[1] < 0:
		宿主._通知(文缺材料)
		return
	if 花费 > 宿主._金币():
		宿主._通知(文金币少)
		return
	if _制作中:
		return			# `showLoadingBar:169-172` 同一根条没结束前**直接 return**
	_制作中 = true
	for 名 in ["材料1", "材料2"]:
		页.get_node(名).set("锁定", true)
	宿主._通知(文制作中)
	var 树 := 宿主.get_tree()
	if 树 == null:
		_制作中 = false
		return
	树.create_timer(float(进度毫秒) / 1000.0).timeout.connect(_发合成.bind(宿主, 页))


## `zhiZuoLiaoLi:60-68` = `requestBuffHeCheng_makeBuff({item0:_itemData1.position, item1:...})`。
## 发出去之后**不预报结果**：成功/失败那两句话都来自 `1822:2` 那一帧。
static func _发合成(宿主: Node, 页: Control) -> void:
	_制作中 = false
	if not is_instance_valid(页):
		return
	for 名 in ["材料1", "材料2"]:
		页.get_node(名).set("锁定", false)
	var 后: Node = 宿主.get("_backend") as Node
	if 后 == null or not 后.has_method("request_buff_fusion"):
		宿主._通知("合成上行发不出去：取不到 `_backend.request_buff_fusion`")
		return
	if not bool(后.call("request_buff_fusion", _料[0], _料[1])):
		宿主._通知("合成上行没发出去（离线 / 未连服务端）⇒ 服务端不会回 1822:2")
		return


## `getConditionString:120`：只有颜色跟着金币走，数字始终是那个静态配置值。
static func _上消耗色(页: Control, 宿主: Node) -> void:
	var 数 := 页.get_node("消耗行/消耗数值") as Label
	数.add_theme_color_override("font_color", 色不够 if 宿主._金币() < 花费 else 色够)
