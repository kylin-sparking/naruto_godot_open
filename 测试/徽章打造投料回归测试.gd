extends SceneTree

## 徽章打造「投料 + 提交」回归门（2026-10-11）。
##
## 这扇窗以前是**半扇**：两页的「放入」只回一句话、「确定」只回一句提示
## （源码里自己写着"协议面一条都不发，待点头"）。本轮把投料与提交接上：
##   · 投料 = 把背包里的料**拖到材料格上**（原版是 `ItemCaiLiaoBox` 的 `UpShelfCursor`
##     光标收集态；本工程没跟手光标件，用同族的拖放，落点件 `徽章放入格.gd` 运行期挂）；
##   · 提交 = `ITEM_CHANGE 1040` 子命令 **26**（页0 合成徽章石）/ **27**（页1 打造徽章），
##     两页都只带**背包格号**（原版 `_itemData.position`）。
##
## 盯的件（①~⑦ 是 2026-10-11/13 那两轮，⑧~⑫ 是 2026-10-25 报修 1.1/1.2）：
##   ① 两页的材料格都真的挂上了落点件（场景是 SPEC 生成物，只能运行期挂）；
##   ② 收料判据：页0 只收**徽章打造石**（前三位 132）、页1 只收**徽章**（装备部位 = 徽章）；
##   ③ 落上之后：`_投料` 记的是**来源背包格号**、材料格出图标、枚数角标 = 件数、
##      「放入」钮文字翻成「取出」（`CREATESTONE_GET_BTN` / `BEASTBADGE_GET_BTN`）；
##   ④ 没料点「确定」⇒ 原版那两句缺料文（逐字），**不发帧**；
##   ⑤ 有料点「确定」⇒ 发对应子命令 + **背包格号**（用假后端钉真发包）；
##   ⑥ 「取出」清格（原版那一支**不发帧**）；
##   ⑦ 原版 `validateItem` 收下之前那道闸门**逐条照抄**（2026-10-13 补）：
##      页0 打造石满级（`stone_next == 0`）⇒「该宝石已经是最高等级！」**不收**；
##      页1 徽章破碎（`crash_time > 0`）⇒「对不起，该装备已经破损！」、
##      满级（`装备库.进阶目标 == ""`）⇒「该装备已经是最高阶！」—— 两条都**不收**。
##
## 2026-10-25（报修 1.1 / 1.2）再盯五件：
##   ⑧ 页1 那枚**材料盒**（`ItemCaiLiaoBox._fu1`）：放了徽章就**自动**带上要耗的那枚石
##      （`BadgeComposePane.updateView:183-186`，键 = 去零十进制徽章 id）、角标写 `needItemCnt`，
##      **灰只由"背包里够不够"决定**（`validateCaiLiao:203-213`）——用户报的就是"放进去之后一直灰"。
##      ⚠ 取出后**角标留着**（`backItemToEquip:272-273` 只清 `itemData`、没人清 `countLabel`）⇒
##      这一条是原版的样子，钉住它是为了别被"顺手修好"。
##   ⑨ 两页的**产物格**（`ItemDropBox.resultCell`）放件后显示"下一级那件"、且**没有角标**。
##   ⑩ 页0 的**成功/剩余两格**只有 `2317` 那帧填得上（`updateResultAndLeftCel:114-124`），
##      同帧还把投料格与产物格清掉（`:122-123`）。
##   ⑪ 「确定」新增两道闸：页0 这摞 < 3 颗 ⇒「对不起，宝石合成需要三颗以上的宝石！」；
##      页1 石不够 ⇒ `FAIL_PROMPT_2[0]` 替 `getItemString(needItemId)` ⇒「很抱歉，你的<石名>不够」。都**不发帧**。
##   ⑫ 七枚格全接**悬停详情框**（原版每枚 `SimpleItemCell` 都挂 `MToolTipItem:220`）：
##      页上有运行期建的两套框、格子不再是 IGNORE、悬停真能弹。
##
## 2026-10-28（报修：合成后数字被图标盖住 / 尾兽徽章品质色）再盯两条：
##   ⑬ `SimpleItemCell` 的**层序与几何**：`showIcon:159` `addChildAt(_icon, 1)` 把图标插到
##      countLabel **之下**、`:161-162` 按**原尺寸居中**摆；本工程数量 Label 烘在场景里、
##      图标运行期后挂 ⇒ `挂图标` 必须自己 `move_child` 到数量之前 + KEEP_CENTERED，
##      否则铺满的图标把数字盖掉一半（用户看到的「偏右」= 只剩右沿漏出）。
##   ⑭ 资质框口径（**2026-10-28 用户追加点头**：「徽章装备图标外框本身也应该像装备品质那样
##      白绿蓝紫橙」）：原版 `shouldHideAptitudeIcon:89-92` 玉链/**徽章**都藏框，本工程
##      **徽章放回框**（档=服务端钉的尾数品质）、**玉链维持藏**；紫橙**流光不藏**
##      （`hasEquipAnimationByItem` 另一条路）；白档原版**本来无框素材**（switch 无 WHITE case）
##      ⇒ 一/二尾无框是对的；普通装备照常戴框（不许藏过界、也不许多藏）。
##
## ⚠️ 本门**不发任何真协议**（假后端）；不碰 user://（只在内存里读会话背包）。
##
## 运行：`Godot --headless --path . --script res://测试/徽章打造投料回归测试.gd`

const 窗场景 := "res://场景/界面/窗口/徽章打造/徽章打造窗.tscn"
const 控制器 := preload("res://脚本/界面/窗口/徽章打造窗.gd")
const 放入格脚本 := preload("res://脚本/界面/组件/徽章放入格.gd")
const 品质表 := preload("res://脚本/单例/装备品质.gd")

const 材料格路 := ["内容层/面板0/石页投料盒/石页材料格",
		"内容层/面板1/徽页投料盒/徽页材料格"]
const 数量路 := ["内容层/面板0/石页投料盒/石页材料格/石页材料格_数量",
		"内容层/面板1/徽页投料盒/徽页材料格/徽页材料格_数量"]
const 放入钮路 := ["内容层/面板0/石页投料盒/石页放入钮",
		"内容层/面板1/徽页投料盒/徽页放入钮"]
## 两页投料盒里的**产物格**（原版 `ItemDropBox.resultCell`）与它的角标（`_数量` 是格的子节点，
## ⇒ 路径得写全，`格路 + "_数量"` 拼不出来）。
const 产物格路 := ["内容层/面板0/石页投料盒/石页结果格",
		"内容层/面板1/徽页投料盒/徽页结果格"]
const 产物数量路 := ["内容层/面板0/石页投料盒/石页结果格/石页结果格_数量",
		"内容层/面板1/徽页投料盒/徽页结果格/徽页结果格_数量"]
## 页1 的材料盒（`_fu1`）与页0 的成功/剩余两格。
const 材料盒格路 := "内容层/面板1/材料盒/材料盒格"
const 材料盒数量路 := "内容层/面板1/材料盒/材料盒格/材料盒格_数量"
const 成功格路 := "内容层/面板0/石页成功格"
const 成功数量路 := "内容层/面板0/石页成功格/石页成功格_数量"
const 剩余格路 := "内容层/面板0/石页剩余格"
const 剩余数量路 := "内容层/面板0/石页剩余格/石页剩余格_数量"
## 图标是运行期挂的 `投料图标`（场景是 SPEC 生成物，烘不出运行期才有的件）。
const 图标名 := "投料图标"

var 红数 := 0
var _秒 := 0.0
var _快照: Array = []


func _记(过: bool, 文: String) -> void:
	if not 过:
		红数 += 1
		print("!! " + 文)


## ⚠️ **看门狗 + 取不到就红的护栏**（反向对照实测踩到）：落点件没挂上时
## `格.call("_can_drop_data", …)` 会抛 "Invalid call"，协程当场断、**永不 quit**
## ⇒ 无头进程挂死两分钟，而且会话背包的快照还原也不执行。**门必须红得下来，不能崩。**
func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 90.0:
		_还原()
		printerr("徽章打造投料回归测试：看门狗超时（90s）—— 中途崩了没走到收尾，已还原背包")
		quit(1)
	return false


func _还原() -> void:
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 != null and not _快照.is_empty():
		会话.inventory.assign(_快照)


## `_can_drop_data` / `_drop_data` 是落点件挂上才有的方法 ⇒ 先问再调。
func _能拖(格: Control, 载荷: Dictionary) -> bool:
	if not 格.has_method("_can_drop_data"):
		return false
	return bool(格.call("_can_drop_data", Vector2.ZERO, 载荷))


func _拖(格: Control, 载荷: Dictionary) -> void:
	if 格.has_method("_drop_data"):
		格.call("_drop_data", Vector2.ZERO, 载荷)


## 假宿主：`渲染` 只要 `_content`（挂页）、`_通知`（回显）、`_session`、`_backend`；
## 本轮还多了两件 —— 提示框接线要 `_舞台尺寸()`、材料盒套灰要 `禁用灰度材质()`
## （真宿主都是 `功能窗口`，那两个都在它身上；这里**照它的样子**给一份）。
class 假宿主 extends Node:
	var _content: Control
	var _session
	var _backend
	var 通知: Array[String] = []

	func _init() -> void:
		_content = Control.new()
		_content.name = "内容"
		add_child(_content)

	func _通知(文: String) -> void:
		通知.append(文)

	func _舞台尺寸() -> Vector2:
		return get_viewport().get_visible_rect().size

	## 真源是 `功能窗口.禁用灰度材质()`（static，本窗只能经宿主拿 —— preload 它会成环）。
	## 这里给一份**同图**的，断言只看"套没套"，不比对象身份。
	func 禁用灰度材质() -> ShaderMaterial:
		var 材质 := ShaderMaterial.new()
		材质.shader = load("res://脚本/界面/组件/禁用灰度.gdshader") as Shader
		return 材质


## 假后端：只认本轮接上那两条（原版 `requestMergeHuiZhangStone` / `requestStageUpHuiZhang`）。
class 假后端 extends Node:
	var 收到: Array = []

	func request_merge_badge_stone(背包格: int) -> bool:
		收到 = ["merge:%d" % 背包格]
		return true

	func request_stage_up_badge(背包格: int) -> bool:
		收到 = ["stage_up:%d" % 背包格]
		return true


## 拖放载荷里的"来源格"：`_drop_data` 只从它身上读 `槽位号`（同 `可拖拽格` 的约定）。
class 假来源格 extends Control:
	var 槽位号 := 0


## 这一格现在有没有摆着**看得见的**图标（运行期 `投料图标` 可能压根没建）。
func _有图(格: Control) -> bool:
	var 图标 := 格.get_node_or_null(图标名) as TextureRect
	return 图标 != null and 图标.texture != null


## 这一格现在**灰不灰**（`material` 非空 = 套了 `禁用灰度` 那张）。
func _灰(格: Control) -> bool:
	return 格.material != null


## ⑬ 一枚格的图标**几何 + 层序**（`SimpleItemCell.showIcon:159-162`）：
## 原尺寸居中（不许铺满）+ 排在 `_数量` Label **之前**（数量永远压着图标）。
func _查图标(页: Control, 格路: String, 数量路: String, 名: String) -> void:
	var 格 := 页.get_node(格路) as Control
	var 图标 := 格.get_node_or_null(图标名) as TextureRect
	_记(图标 != null and 图标.texture != null, "⑬ %s 这会儿该有图标（前置腿没摆上料？）" % 名)
	if 图标 == null:
		return
	_记(图标.stretch_mode == TextureRect.STRETCH_KEEP_CENTERED,
			"⑬ %s 图标该**原尺寸居中**（showIcon:161-162 round((40-宽)/2)），实得 stretch_mode=%d"
			% [名, 图标.stretch_mode])
	_记(图标.expand_mode == TextureRect.EXPAND_IGNORE_SIZE,
			"⑬ %s 图标不该吃格子拉伸（铺满就把数字那一行整个盖了）" % 名)
	var 数量 := 页.get_node(数量路) as Label
	var 手足: Array = 格.get_children()
	_记(手足.find(图标) >= 0 and 手足.find(图标) < 手足.find(数量),
			"⑬ %s 数量数字该**压在图标上面**（原版 addChildAt(_icon,1) 插在 countLabel 之下）" % 名)


## 从内存背包里撤掉某一摞（只在腿与腿之间搬料用，**不落盘**）。
func _撤掉(背包: Array, 八位id: String) -> void:
	for i in range(背包.size() - 1, -1, -1):
		if str((背包[i] as Dictionary).get("id", "")) == 八位id:
			背包.remove_at(i)


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 == null:
		_记(false, "缺 GameSession")
		_finish()
		return
	# 只读内存：把背包摆成"格1 = 打造石 / 格2 = 徽章 / 格3 = 普通装备"，跑完原样放回。
	_快照 = (会话.inventory as Array).duplicate(true)
	var 假 := 假后端.new()
	var 宿 := 假宿主.new()
	宿._session = 会话
	宿._backend = 假
	root.add_child(宿)

	控制器.新会话()
	var 页: Control = 控制器.渲染(宿, load(窗场景) as PackedScene)
	await process_frame
	if 页 == null:
		_记(false, "徽章打造页没建出来")
		_finish()
		return

	# ① 两页材料格都挂了落点件
	for i in 2:
		var 格 := 页.get_node(材料格路[i]) as Control
		_记(格.get_script() == 放入格脚本,
				"页%d 的材料格没挂上落点件（场景是生成物 ⇒ 只能运行期 `set_script`）" % i)
		_记(格.mouse_filter == Control.MOUSE_FILTER_STOP, "页%d 的材料格 mouse_filter 不是 STOP ⇒ 接不到拖放" % i)

	# ② 收料判据（纯函数，直接问）
	_记(放入格脚本.可收("13200000", 0), "页0 该收「徽章打造石」（前三位 132）")
	_记(not 放入格脚本.可收("01410002", 0), "页0 不该收徽章（那是页1 的料）")
	_记(放入格脚本.可收("01410002", 1), "页1 该收徽章（装备部位 = 徽章）")
	_记(not 放入格脚本.可收("13200000", 1), "页1 不该收打造石")
	_记(not 放入格脚本.可收("01010011", 1), "页1 不该收普通武器")

	# 摆背包（格1/2/3 正常料，格4 满级打造石、格5 破碎徽章、格6 满级徽章）——**不落盘**，只写内存
	会话.inventory.clear()
	会话.inventory.append({"id": "13200000", "name": "一尾徽章打造石", "quantity": 7, "slot_index": 1,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"})
	会话.inventory.append({"id": "01410002", "name": "一尾徽章", "quantity": 1, "slot_index": 2,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"})
	会话.inventory.append({"id": "01010011", "name": "长太刀", "quantity": 1, "slot_index": 3,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"})
	会话.inventory.append({"id": "13200009", "name": "十尾徽章打造石", "quantity": 1, "slot_index": 4,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"})
	会话.inventory.append({"id": "01410003", "name": "一尾徽章", "quantity": 1, "slot_index": 5,
			"crash_time": 120,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"})
	会话.inventory.append({"id": "01410011", "name": "满级徽章", "quantity": 1, "slot_index": 6,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"})
	await process_frame

	# ⑦pre 数据映射的钉子：`进阶目标` 就是原版 `nextId`（空串 = 满级）
	_记(控制器.装备进阶目标("01410001") == "01410002",
			"01410001 的进阶目标该是 01410002，实测「%s」" % 控制器.装备进阶目标("01410001"))
	_记(控制器.装备进阶目标("01410011").is_empty(),
			"01410011 是满级徽章，进阶目标该是空串，实测「%s」" % 控制器.装备进阶目标("01410011"))

	# ⑫a 悬停详情框的**接线本身**（报修 1.2 后半）：两套框运行期建在页上、七枚格不再是 IGNORE
	_记(页.get_node_or_null("物品提示框") is Control,
			"页上没有运行期建的「物品提示框」（场景是 SPEC 生成物 ⇒ 只能 `渲染` 时挂）")
	_记(页.get_node_or_null("装备提示框") is Control, "页上没有运行期建的「装备提示框」")
	for 路 in [材料格路[0], 材料格路[1], 产物格路[0], 产物格路[1], 材料盒格路, 成功格路, 剩余格路]:
		var 检格 := 页.get_node(str(路)) as Control
		_记(检格 != null and 检格.mouse_filter != Control.MOUSE_FILTER_IGNORE,
				"%s 的 mouse_filter 还是 IGNORE ⇒ 悬停永远弹不出" % str(路))

	# ④ 没料点「确定」⇒ 原版缺料文，且**不发帧**
	(页.get_node("确定钮") as Button).pressed.emit()
	await process_frame
	_记(假.收到.is_empty(), "没料点「确定」不该发包，实测 %s" % str(假.收到))
	_记(宿.通知.size() > 0 and 宿.通知[宿.通知.size() - 1].contains("请放入徽章打造石"),
			"没料点「确定」该说原版那句「请放入徽章打造石！」，实测 %s" % str(宿.通知))

	# ③ 页0 落上打造石（格1）
	var 源 := 假来源格.new()
	源.槽位号 = 1
	var 格0 := 页.get_node(材料格路[0]) as Control
	_记(_能拖(格0, {"归属": "背包", "物品id": "13200000", "来源格": 源}), "页0 该接受格1 拖来的打造石")
	_记(not _能拖(格0, {"归属": "背包", "物品id": "01010011", "来源格": 源}), "页0 不该接受普通武器")
	_拖(格0, {"归属": "背包", "物品id": "13200000", "来源格": 源})
	await process_frame
	_记(int(控制器._投料[0]) == 1, "落上后 `_投料[0]` 该记**来源背包格号 1**，实测 %s" % str(控制器._投料[0]))
	var 图标 := 格0.get_node_or_null("投料图标") as TextureRect
	_记(图标 != null and 图标.texture != null, "落上后材料格该出图标")
	_记((页.get_node(数量路[0]) as Label).text == "7",
			"枚数角标该是件数 7，实测「%s」" % (页.get_node(数量路[0]) as Label).text)
	_记((页.get_node(放入钮路[0]) as Button).text == "取出打造石",
			"放入钮该翻成「取出打造石」，实测「%s」" % (页.get_node(放入钮路[0]) as Button).text)

	# ⑤ 有料点「确定」⇒ 子命令 26 + 背包格号
	(页.get_node("确定钮") as Button).pressed.emit()
	await process_frame
	_记(假.收到 == ["merge:1"], "页0 该发 `request_merge_badge_stone(1)`（子命令 26 + 背包格号），实测 %s" % str(假.收到))

	# ⑥ 「取出」清格、不发帧
	假.收到 = []
	(页.get_node(放入钮路[0]) as Button).pressed.emit()
	await process_frame
	_记(int(控制器._投料[0]) == -1, "「取出」后 `_投料[0]` 该清成 -1，实测 %s" % str(控制器._投料[0]))
	_记(假.收到.is_empty(), "「取出」不该发包（原版那一支清格也不发帧），实测 %s" % str(假.收到))
	_记((页.get_node(放入钮路[0]) as Button).text == "放入打造石", "「取出」后钮文字该翻回「放入打造石」")

	# ⑥b 「放入」钮的选物清单（§3.385：原版 `UpShelfCursor` 的等价通道）。
	#    有料时弹「放入选择」，点一行 = 原版"点背包那一格"，与拖放同走 `收料` 那道闸。
	(页.get_node(放入钮路[0]) as Button).pressed.emit()
	await process_frame
	var 器 := 页.get_node_or_null("放入选择") as PopupMenu
	_记(器 != null, "页0 有料时点「放入」该弹「放入选择」清单")
	if 器 != null:
		_记(器.item_count == 2, "页0 清单该只列徽章打造石两摞（格1、格4），实测 %d" % 器.item_count)
		_记(器.get_item_text(0).contains("一尾徽章打造石") and 器.get_item_text(0).contains("×7"),
				"清单第 1 行该是格1 那摞「一尾徽章打造石 ×7」，实测「%s」" % 器.get_item_text(0))
		器.id_pressed.emit(1)		# 满级那摞 → 页面那道闸该拒
		await process_frame
		_记(int(控制器._投料[0]) == -1, "清单选中满级打造石不该收（`满级或破碎提示` 那一道）")
		_记(宿.通知.size() > 0 and 宿.通知[宿.通知.size() - 1] == "该宝石已经是最高等级！",
				"选中满级那行该逐字弹「该宝石已经是最高等级！」，实测 %s" % str(宿.通知))
		(页.get_node(放入钮路[0]) as Button).pressed.emit()
		await process_frame
		器 = 页.get_node_or_null("放入选择") as PopupMenu
		if 器 != null:
			器.id_pressed.emit(0)	# 格1 那摞 → 收
		await process_frame
		_记(int(控制器._投料[0]) == 1, "选中格1 那行后 `_投料[0]` 该记 1，实测 %s" % str(控制器._投料[0]))
		_记(_有图(页.get_node(材料格路[0]) as Control), "清单选中后材料格该出图标")
		_记((页.get_node(放入钮路[0]) as Button).text == "取出打造石", "清单选中后钮文字该翻「取出打造石」")
	# 收掉，回空态（⑤b 的起点）
	(页.get_node(放入钮路[0]) as Button).pressed.emit()
	await process_frame
	_记(int(控制器._投料[0]) == -1, "再点「取出」该回空态")

	# ⑤b 页1：切页 + 落徽章（格2）+ 确定 ⇒ 子命令 27
	#     先补一摞**这枚徽章要耗的石**（`huiZhangStageUp["1410002"].needItemId = 13200001`）：
	#     `upgradeEquip:229-233` 那一闸没石就**不发帧**（⑪b 专验拒绝），这里要的是过闸那一支。
	#     验完立刻撤掉，留给 ⑧ 验「背包里没石 ⇒ 材料盒该灰」。
	会话.inventory.append({"id": "13200001", "name": "二尾徽章打造石", "quantity": 1, "slot_index": 7,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"})
	控制器.切页(页, 1)
	await process_frame
	var 源2 := 假来源格.new()
	源2.槽位号 = 2
	var 格1 := 页.get_node(材料格路[1]) as Control
	_拖(格1, {"归属": "背包", "物品id": "01410002", "来源格": 源2})
	await process_frame
	(页.get_node("确定钮") as Button).pressed.emit()
	await process_frame
	_记(假.收到 == ["stage_up:2"], "页1 该发 `request_stage_up_badge(2)`（子命令 27 + 背包格号），实测 %s" % str(假.收到))
	_撤掉(会话.inventory, "13200001")

	# ⑦ 页1 收料闸门：破碎 / 满级 —— 都**不收**，各弹**逐字的原版那句话**
	var 源5 := 假来源格.new()
	源5.槽位号 = 5
	_拖(格1, {"归属": "背包", "物品id": "01410003", "来源格": 源5})
	await process_frame
	_记(int(控制器._投料[1]) == 2, "破碎的徽章不该被收下（`_投料[1]` 该还是 2），实测 %s" % str(控制器._投料[1]))
	_记(宿.通知.size() > 0 and 宿.通知[宿.通知.size() - 1] == "对不起，该装备已经破损！",
			"破碎的徽章该弹「对不起，该装备已经破损！」，实测 %s" % str(宿.通知))
	var 源6 := 假来源格.new()
	源6.槽位号 = 6
	_拖(格1, {"归属": "背包", "物品id": "01410011", "来源格": 源6})
	await process_frame
	_记(int(控制器._投料[1]) == 2, "满级徽章不该被收下（`_投料[1]` 该还是 2），实测 %s" % str(控制器._投料[1]))
	_记(宿.通知.size() > 0 and 宿.通知[宿.通知.size() - 1] == "该装备已经是最高阶！",
			"满级徽章该弹「该装备已经是最高阶！」，实测 %s" % str(宿.通知))

	# ⑦b 页0 收料闸门：满级打造石（十尾，`stone_next == 0`）
	控制器.切页(页, 0)
	await process_frame
	var 源4 := 假来源格.new()
	源4.槽位号 = 4
	var 格0b := 页.get_node(材料格路[0]) as Control
	_拖(格0b, {"归属": "背包", "物品id": "13200009", "来源格": 源4})
	await process_frame
	_记(int(控制器._投料[0]) == -1, "满级打造石不该被收下（`_投料[0]` 该还是 -1），实测 %s" % str(控制器._投料[0]))
	_记(宿.通知.size() > 0 and 宿.通知[宿.通知.size() - 1] == "该宝石已经是最高等级！",
			"满级打造石该弹「该宝石已经是最高等级！」，实测 %s" % str(宿.通知))

	# ── ⑧ 页1 的**材料盒**：放入徽章后打造石**自己带上**、角标写需要几颗、只有不够才灰 ──
	#    （报修 1.1。真值 `BadgeComposePane.updateView:183-186` + `validateCaiLiao:203-213`；
	#      01410002 那一行是 `huiZhangStageUp["1410002"] = {needItemId:13200001, needItemCnt:1}`，
	#      表里**没有 needMoney** ⇒ 金币那闸恒不触发。）
	控制器.切页(页, 1)
	await process_frame
	var 盒 := 页.get_node(材料盒格路) as Control
	var 盒数 := 页.get_node(材料盒数量路) as Label
	# 先清掉格 2 那份料，验"没徽章"那一支
	(页.get_node(放入钮路[1]) as Button).pressed.emit()
	await process_frame
	_记(not _有图(盒), "没放徽章时材料盒该**没有图标**（updateView:179-181 查不到键就直接 return）")
	_记(_灰(盒), "没放徽章时材料盒该是灰的（backItemToEquip:272 的 applyGrayFilter()）")
	# 落上徽章（格2）
	_拖(格1, {"归属": "背包", "物品id": "01410002", "来源格": 源2})
	await process_frame
	_记(_有图(盒), "放入徽章后材料盒该**自动**带上要耗的那枚打造石（玩家不拖、也拖不进去）")
	_记(盒数.text == "1", "材料盒角标该写 needItemCnt=1，实测「%s」" % 盒数.text)
	_记(_灰(盒), "背包里没有 13200001 时该灰（validateCaiLiao：count < needItemCnt）")
	# 补一摞二尾打造石 ⇒ **不该再灰**（这就是用户报的"一直灰"）
	会话.inventory.append({"id": "13200001", "name": "二尾徽章打造石", "quantity": 3, "slot_index": 7,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"})
	控制器.刷新投料格(页, 宿, 1)
	await process_frame
	_记(not _灰(盒), "背包里有 3 颗 ≥ 需要 1 颗时**不该灰**（报修 1.1 的主诉：放进去一直灰）")
	# ⚠️ 取出徽章那一支：只清图标、重新挂灰，**角标留着** —— `backItemToEquip:273` 不清 countLabel
	(页.get_node(放入钮路[1]) as Button).pressed.emit()
	await process_frame
	_记(not _有图(盒), "取出徽章后材料盒图标该清掉（backItemToEquip:273 `itemCell.itemData = null`）")
	_记(_灰(盒), "取出徽章后材料盒该重新挂灰（backItemToEquip:272）")
	_记(盒数.text == "1", "取出后角标**留着**是原版样子（没人清 countLabel ⇒ 别顺手修）")

	# ⑨ 两页的**产物格**（`ItemDropBox.resultCell`）放件后显示下一级那件、且没有角标
	_拖(格1, {"归属": "背包", "物品id": "01410002", "来源格": 源2})
	await process_frame
	_记(_有图(页.get_node(产物格路[1]) as Control),
			"页1 放入徽章后产物格该显示进阶后的那枚徽章（updateView:177-178）")
	var 产物角标 := (页.get_node(产物数量路[1]) as Label).text
	_记(产物角标 == " ",
			"产物格**不该有角标**（AS3 两支都不设 resultCell.label，实测「%s」" % 产物角标)
	_记(控制器.下一级id({"id": "01410002"}, 1) == 1410003,
			"01410002 的下一级该是 01410003，实测 %d" % 控制器.下一级id({"id": "01410002"}, 1))
	_记(控制器.下一级id({"id": "13200000"}, 0) == 13200001,
			"13200000 的下一级该是 13200001（物品.json 的 stone_next），实测 %d"
			% 控制器.下一级id({"id": "13200000"}, 0))
	_记(控制器.下一级id({}, 1) == 0, "没料时下一级 id 该是 0")

	# ⑫b 悬停：页1 的徽章格走**装备**框（`EqpData` → `MToolTipZhuangBei`）、打造石格走默认框
	var 装备框 := 页.get_node("装备提示框") as Control
	var 物品框 := 页.get_node("物品提示框") as Control
	_记(not 装备框.visible and not 物品框.visible, "悬停前两套框都该收起")
	格1.mouse_entered.emit()
	await process_frame
	_记(装备框.visible and not 物品框.visible, "悬停徽章格该弹**装备**提示框（分发按 ItemData 子类）")
	格1.mouse_exited.emit()
	await process_frame
	_记(not 装备框.visible, "移开鼠标该收起装备提示框")

	# ── ⑩ 页0 的**成功/剩余两格**只有 2317 那一帧填得上 ──
	#     `ItemChangeProcessor.handleHuiZhangStoneMergerResponse:20-43` 的四个 int
	#     → `Client.onHuiZhangStoneMergeResponse:10020-10023` → `updateResultAndLeftCel:114-124`
	_记(not _有图(页.get_node(成功格路) as Control), "没收到 2317 前成功格该是空的（原版也空）")
	控制器.收石合成回帧({"success_count": 2, "success_item_id": 13200001,
			"left_count": 1, "left_item_id": 13200000})
	控制器.刷新投料格(页, 宿, 0)
	await process_frame
	_记(_有图(页.get_node(成功格路) as Control), "2317 之后成功格该摆上成品（报修 1.2「没显示产物」）")
	_记((页.get_node(成功数量路) as Label).text == "2",
			"成功格角标该是成数 2，实测「%s」" % (页.get_node(成功数量路) as Label).text)
	_记((页.get_node(剩余数量路) as Label).text == "1",
			"剩余格角标该是剩余数 1，实测「%s」" % (页.get_node(剩余数量路) as Label).text)
	_记(int(控制器._投料[0]) == -1, "那一帧同时清投料格（updateResultAndLeftCel:122）")
	_记((页.get_node(放入钮路[0]) as Button).text == "放入打造石", "被服务端收走后钮该翻回「放入打造石」")

	# ── ⑪ 页0 这摞 < 3 颗 ⇒ 逐字那句、**不发帧**（`submitToHandle:212-216`）──
	会话.inventory.append({"id": "13200000", "name": "一尾徽章打造石", "quantity": 2, "slot_index": 8,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"})
	控制器.切页(页, 0)
	await process_frame
	var 源8 := 假来源格.new()
	源8.槽位号 = 8
	_拖(格0, {"归属": "背包", "物品id": "13200000", "来源格": 源8})
	await process_frame
	# 落新料先把上次那两格清掉（`dropItemHandler:76-77`），别拿旧结果糊弄玩家
	_记(not _有图(页.get_node(成功格路) as Control),
			"落上新料时成功格该清空（StoneComposePane.dropItemHandler:76）")
	假.收到 = []
	(页.get_node("确定钮") as Button).pressed.emit()
	await process_frame
	_记(宿.通知[宿.通知.size() - 1] == "对不起，宝石合成需要三颗以上的宝石！",
			"两颗就点合成该弹原版那句（EQUIP_STONE_FAIL_PROMPT_1），实测 %s" % str(宿.通知))
	_记(假.收到.is_empty(), "颗数不够时不该发包，实测 %s" % str(假.收到))
	# 悬停那颗石 ⇒ **默认**框（`ItemType` 不是 EqpData）
	格0.mouse_entered.emit()
	await process_frame
	_记(物品框.visible and not 装备框.visible, "悬停打造石格该弹**物品**提示框")
	_记(_有图(页.get_node(产物格路[0]) as Control),
			"页0 放入打造石后产物格该显示合成后的那颗（`stone_next`，`validateItem:100-101`）")
	格0.mouse_exited.emit()
	await process_frame

	# ── ⑪b 页1 石不够 ⇒ `FAIL_PROMPT_2[0]` 替 `getItemString(needItemId)`、**不发帧** ──
	_撤掉(会话.inventory, "13200001")
	控制器.切页(页, 1)
	await process_frame
	_拖(格1, {"归属": "背包", "物品id": "01410002", "来源格": 源2})
	await process_frame
	假.收到 = []
	(页.get_node("确定钮") as Button).pressed.emit()
	await process_frame
	_记(宿.通知[宿.通知.size() - 1] == "很抱歉，你的二尾徽章打造石不够",
			"石不够时该说「很抱歉，你的<石名>不够」，实测 %s" % str(宿.通知))
	_记(假.收到.is_empty(), "石不够时不该发包，实测 %s" % str(假.收到))

	# ── ⑬ 图标层序/几何（报修 2026-10-28：合成后成功/剩余的数字被图标盖住）──
	#     把 2317 那一帧再喂一次 ⇒ 成功/剩余填上；页1 那格徽章是 ⑪b 落的、还挂着，
	#     材料盒与产物格跟着它自动带石/带下一级（⑧/⑨ 的同一条腿）。
	控制器.收石合成回帧({"success_count": 2, "success_item_id": 13200001,
			"left_count": 1, "left_item_id": 13200000})
	控制器.刷新投料格(页, 宿, 0)
	await process_frame
	for 检 in [[成功格路, 成功数量路, "成功格"], [剩余格路, 剩余数量路, "剩余格"],
			[材料格路[1], 数量路[1], "页1 材料格"], [产物格路[1], 产物数量路[1], "页1 产物格"],
			[材料盒格路, 材料盒数量路, "材料盒"]]:
		_查图标(页, str(检[0]), str(检[1]), str(检[2]))

	# ── ⑭ 资质框口径（2026-10-28：徽章**放回框**；2026-10-31：玉链**按阶戴框**）──
	var 十尾: Dictionary = 品质表.覆盖层({"id": "01410011", "aptitude": 5})
	_记(String(十尾.get("边框", "")) == 品质表.边框路径(5) and bool(十尾.get("流光", false)),
			"⑭ 十尾徽章该**戴橙框有流光**（用户口径『外框本身也要白绿蓝紫橙』），实得 %s" % str(十尾))
	var 九尾: Dictionary = 品质表.覆盖层({"id": "01410010", "aptitude": 4})
	_记(String(九尾.get("边框", "")) == 品质表.边框路径(4) and bool(九尾.get("流光", false)),
			"⑭ 九尾徽章该戴紫框有流光，实得 %s" % str(九尾))
	var 三尾: Dictionary = 品质表.覆盖层({"id": "01410004", "aptitude": 2})
	_记(String(三尾.get("边框", "")) == 品质表.边框路径(2) and not bool(三尾.get("流光", false)),
			"⑭ 三尾徽章该戴绿框无流光，实得 %s" % str(三尾))
	var 一尾: Dictionary = 品质表.覆盖层({"id": "01410002", "aptitude": 1})
	_记(String(一尾.get("边框", "")) == "" and not bool(一尾.get("流光", false)),
			"⑭ 一尾徽章白档——原版 createAptitudeIcon 的 switch **没有 WHITE case**、白档本来无框素材，"
			+ "该无框无流光（放回框≠发明白框），实得 %s" % str(一尾))
	# 玉链（用户 2026-10-31 点名）：45/50 白（无色）、55 绿、60 蓝、65 紫、70 橙。
	# 服务端 aptitude **不表达品质**（夹具/默认值就是 2），档由**阶**推出来：
	# 阶 = id 十位、档 = clamp(阶-1, 1, 5)（`装备品质.玉链资质`）。
	# 阶的独立真值是 `数据/物品装备元数据.json` 的 `stage` —— 两边必须对得上。
	var 玉链表 := [
		["01200010", 1, "45级白"], ["01200020", 1, "50级白"],
		["01200030", 2, "55级绿"], ["01200040", 3, "60级蓝"],
		["01200050", 4, "65级紫"], ["01200060", 5, "70级橙"],
	]
	var 元数据文本 := FileAccess.get_file_as_string("res://数据/物品装备元数据.json")
	var 解析 = JSON.parse_string(元数据文本)
	var 物品元: Dictionary = (解析.get("物品", {}) as Dictionary) if 解析 is Dictionary else {}
	_记(not 物品元.is_empty(), "⑭ 前置：读不到 数据/物品装备元数据.json（%d 字节）" % 元数据文本.length())
	for 条 in 玉链表:
		var 件号 := String(条[0])
		var 元: Dictionary = 物品元.get(件号, {}) as Dictionary
		var 阶 := int(元.get("stage", 0))
		_记(品质表.玉链资质(件号) == int(条[1]) and clampi(阶 - 1, 1, 5) == int(条[1]),
				"⑭ 玉链 %s 该是 %d 档（%s）：阶从元数据表读到 %d、推导给 %d"
				% [件号, int(条[1]), String(条[2]), 阶, 品质表.玉链资质(件号)])
		# ⚠️ 故意喂一个**错的** aptitude（服务端那套值不表达品质），框必须只认阶。
		var 盖: Dictionary = 品质表.覆盖层({"id": 件号, "aptitude": 2})
		var 期望: Dictionary = 品质表.档(int(条[1]))
		_记(String(盖.get("边框", "")) == String(期望.get("边框", ""))
				and bool(盖.get("流光", false)) == bool(期望.get("有流光", false)),
				"⑭ 玉链 %s（%s）该戴 %d 档框（白档无框素材 ⇒ 「无色」），实得 %s"
				% [件号, String(条[2]), int(条[1]), str(盖)])
	var 白链乱资质: Dictionary = 品质表.覆盖层({"id": "01200010", "aptitude": 5})
	_记(String(白链乱资质.get("边框", "")) == "" and not bool(白链乱资质.get("流光", false)),
			"⑭ 45 级玉链就算下发 aptitude=5，也**只认阶**（白档无框），实得 %s" % str(白链乱资质))
	var 紫武: Dictionary = 品质表.覆盖层({"id": "01010011", "aptitude": 4})
	_记(not String(紫武.get("边框", "")).is_empty() and bool(紫武.get("流光", false)),
			"⑭ 普通装备该**照常戴紫框有流光**（玉链推导不许过界），实得 %s" % str(紫武))
	var 绿武: Dictionary = 品质表.覆盖层({"id": "01010011", "aptitude": 2})
	_记(not String(绿武.get("边框", "")).is_empty(),
			"⑭ 普通装备的绿框不该被玉链推导带走，实得 %s" % str(绿武))

	_还原()
	_finish()


func _finish() -> void:
	if 红数 == 0:
		print("徽章打造投料回归测试：通过（落点挂载 / 收料判据 / 落上刷新 / 缺料不发帧 / "
				+ "有料发 26·27 带格号 / 取出清格 / 满级·破碎不收且弹原版话 / "
				+ "材料盒自动带石·只不够才灰 / 两页产物格 / 2317 填成功剩余两格 / "
				+ "两颗不合·石不够不发包 / 七格悬停详情框分流 / "
				+ "图标原尺寸居中且压在数量之下 / 徽章戴品质框（2026-10-28 用户口径）、"
				+ "玉链按阶戴品质框（2026-10-31 用户口径）、流光照放）")
		quit(0)
	else:
		print("徽章打造投料回归测试：失败 %d 项" % 红数)
		quit(1)
