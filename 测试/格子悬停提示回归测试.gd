## 格子悬停 → **原版那套提示框**（`MToolTipItem` 挂 MOUSE_OVER），三处共用一条接线。
##
## 真值：`EquipmentWindowCell.as:173`（装备格 `showToolTip()`）与背包格同款；
## 按 ItemData 子类分发：装备 → `MToolTipZhuangBei`（我们的 `装备提示框`）、其余 → 默认框。
##
## ⚠️ 人物装备格原来只有**原生 `tooltip_text` 一行字**（"武器：竹制忍杖"），没有原版提示框。
## 2026-10-01 把背包/仓库各一份的 30 行复制接线合并进 `组件/格子提示框.gd`，
## 人物页接上。这条门**同时**验证三处（背包/仓库 = 防合并改坏；人物 = 新连线）。
##
## 2026-10-24 §3.259 再加**对比列**那一腿（报修 15「背包详情框右侧没有身上穿戴件」）。
## 判的是原版那张分流表，**不是只判"有没有多一个框"**：
##   * 背包装备格 ⇒ 右列 = 我身上同槽位那件（`ItemWindowCell.as:314` 的四参调用）；
##   * 只有右列标题带 `(已装备)`、左列不带（`MToolTipZhuangBei.as:1566` 只给 `param2` 置）；
##   * 两列紧贴、顶边对齐、同比例，**钳位按组宽**（`createEqpTip:1552-1575` + `MToolTip.as:123-145`）；
##   * 槽位空 ⇒ 退回单列（原版 `param2` 为 null 那一支整块不进）；
##   * 消耗品格、以及**自己的**人物装备格 ⇒ 连节点都不该建
##     （`StorageWindowCell.as:220` 三参 / `EquipmentWindowCell.as:226` 的 `!_isMyself`）。
extends SceneTree

var _失败: Array[String] = []
var _受检 := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, 话: String) -> void:
	_受检 += 1
	if not ok:
		_失败.append(话)

func _run() -> void:
	var 会话 := root.get_node_or_null("/root/GameSession")
	if 会话 == null:
		_check(false, "没有 GameSession 单例")
		_收尾()
		return
	# —— 人物页：先**自备**已装武器（01010011 竹制忍杖），够验悬停 ——
	# ⚠️ 2026-10-03 夜血案：原先这里赌的是"user:// 存档里恰有穿戴残档"。
	#    `跑在线用例 -全部` 收尾会重写离线存档（equipped_items 变空）⇒ 第二天离线门假红。
	#    环境耦合的门不是门。现在从内存种子里自己穿上，**不调 _save_local_state、不落盘**。
	# ⚠️ 2026-10-17 第三次同型：玩档被在线号回填后，武器位穿的是**服务端那件「长太刀」**
	#    ⇒ 上面"背包里找到 01010011 才种"那条分支整个跳过，提示框标题就变成长太刀。
	#    ⇒ 改成**无条件**把武器位换成物品表里的 01010011，跑完在 `_收尾` 里还原原值。
	var 武器位: int = 部位.位置("01010011")
	原武器 = (会话.equipped_items.get(武器位, {}) as Dictionary).duplicate(true)
	var 竹制: Dictionary = (GAME_DATA.item("01010011") as Dictionary).duplicate(true)
	_check(not 竹制.is_empty(), "种子的武器 01010011 竹制忍杖 从物品表里取得到")
	if not 竹制.is_empty():
		会话.equipped_items[武器位] = 竹制
	var 窗: Node = await _开窗("人物")
	if 窗 != null:
		var 面板 := 窗.find_child("原版人物属性面板", true, false)
		var 格 := 面板.get_node_or_null("装备栏/装备格子容器/武器格") as Button
		_check(格 != null, "找不到 武器格")
		if 格 != null:
			# ⚠️ 提示框挂在**页面根**，不在 `原版人物属性面板`（它有 clip_contents，
			#    挂里面就会被面板下缘裁掉——用户报的"显示不全"）。这条也钉住归属。
			var 装备框 := 面板.get_parent().get_node_or_null("装备提示框") as Control
			_check(装备框 != null, "装备提示框应挂在页面根（面板 clip_contents 会裁它）")
			_check(装备框 != null, "人物页应有 装备提示框 节点（原版悬停那套）")
			_check(String(格.tooltip_text).is_empty(),
					"装备格的原生 tooltip_text 应让位给原版提示框（实际 %s）" % 格.tooltip_text)
			_check(装备框 != null and not 装备框.visible, "悬停前提示框应收起")
			格.mouse_entered.emit()
			await process_frame
			_check(装备框 != null and 装备框.visible, "悬停武器格应弹出装备提示框")
			var 题 := 装备框.get_node_or_null("标题") as Label if 装备框 != null else null
			_check(题 != null and 题.text.contains("竹制忍杖"),
					"提示框标题应是那件武器（实际 %s）" % (题.text if 题 != null else "?"))
			格.mouse_exited.emit()
			await process_frame
			_check(装备框 != null and not 装备框.visible, "移开鼠标提示框应收起")
			# 自己的装备格**不该建对比列**（`EquipmentWindowCell.as:226` 是 `if(!_isMyself)`）。
			_check(面板.get_parent().get_node_or_null("装备提示框对比") == null,
					"自己的人物装备格不该有『身上穿戴件』对比列")
		_关窗(窗)
		await process_frame

	# —— 背包页：合并转发的回归哨兵（格子里放一件消耗品，悬停出**默认**提示框）——
	## ⚠ 2026-10-10 同一条血案第二次发作：`user://玩家数据.json` 是**两份工程共用**的目录，
	## 而在线用例（`创角端到端`）会以一个**新建的小号**登录并把整份存档重写一遍
	## ⇒ 背包里只剩装备、没有非装备物品 ⇒ 这条门红在"环境"上而不是代码上。
	## 与上面人物页同一味药：**自己往内存里种一件消耗品**，不调 `_save_local_state`、不落盘。
	var 药id := "03000001"
	_check(部位.位置(药id) == 0, "种子 %s 必须是非装备类（药品），否则背包那一腿还是验不到默认提示框" % 药id)
	var 有非装备 := false
	for 货 in 会话.inventory:
		var 条: Dictionary = 货 as Dictionary
		if not 条.is_empty() and 部位.位置(String(条.get("id", 条.get("item_id", "")))) == 0:
			有非装备 = true
			break
	if not 有非装备:
		var 药水: Dictionary = (GAME_DATA.item(药id) as Dictionary).duplicate(true)
		_check(not 药水.is_empty(), "种子的消耗品 %s 从物品表里取得到" % 药id)
		if not 药水.is_empty():
			会话.inventory.append(药水)
	# —— 对比列那条腿的种子：背包里再放一件**与穿戴件同槽位**的武器。
	#    武器位上面已无条件穿的是 01010011 竹制忍杖 ⇒ 悬停这件 01010012，右列就该是那件穿戴件。
	#    （只往内存数组尾巴追加，不落盘 ⇒ 不碰共享存档，同上面那瓶药一个做法。）
	var 对比武器id := "01010012"
	_check(部位.位置(对比武器id) == 部位.位置("01010011"),
			"种子 %s 必须与穿戴的 01010011 同槽位，否则对比列这条腿量不到" % 对比武器id)
	var 对比件: Dictionary = (GAME_DATA.item(对比武器id) as Dictionary).duplicate(true)
	_check(not 对比件.is_empty(), "种子的对比武器 %s 从物品表里取得到" % 对比武器id)
	if not 对比件.is_empty():
		会话.inventory.append(对比件)
	var 窗2: Node = await _开窗("背包")
	if 窗2 != null:
		# ⚠️ `_content` 是容器，**页面根**（`原版背包内容`，提示框与格子容器都挂在它下面）还要再下一层
		var 页 := (窗2.get("_content") as Control).find_child("原版背包内容", true, false)
		var 提示: Control = null
		var 装框2: Control = null
		if 页 != null:
			提示 = 页.get_node_or_null("物品提示框") as Control
			装框2 = 页.get_node_or_null("装备提示框") as Control
		_check(提示 != null, "背包页应有 物品提示框 节点")
		_check(页 != null, "找不到 原版背包内容")
		if 页 == null:
			_收尾()
			return
		if 提示 != null:
			# 专挑**非装备**格（背包第一格常是装备，那会正确开装备框——别误判）。
			var 格子: Button = null
			## 背包**每页 30 格**（`背包窗口.gd::_渲染页签:445-468`、`_渲染格子:493`），
			## 而存档是 33 格 ⇒ 非装备那几件可能落在第二页。以前只扫当前页，
			## 于是 2026-10-10 全量红了一条"环境"：门把第二页的货当不存在。逐页翻，翻到为止。
			var 页号 := 0
			while 格子 == null and 页号 < 9:
				var 钮 := 页.get_node_or_null("分页/第%d页" % (页号 + 1)) as Button
				if 钮 == null or not 钮.visible:
					break
				钮.emit_signal("pressed")
				await process_frame
				for 子 in _找有货格(页):
					if 部位.位置(str(子.get("物品id"))) == 0:
						格子 = 子
						break
				页号 += 1
			_check(格子 != null, "背包九页里都找不到有货的非装备格（会话 %d 件：%s）" % [
					(会话.inventory as Array).size(), str(_货表(会话))])
			if 格子 != null:
				格子.mouse_entered.emit()
				await process_frame
				_check(提示.visible, "合并后背包悬停仍应出提示框")
				_check(装框2 == null or not 装框2.visible, "消耗品不该错开成装备框")
				格子.mouse_exited.emit()
				await process_frame
				_check(not 提示.visible, "移开后背包提示框应收起")
			# 消耗品那一悬停**不许**顺手建出对比列（原版 `MToolTipDefault.createDefaultTip`
			# 根本不接第四个参数，`MToolTipItem.as:105-107`）。
			_check(页.get_node_or_null("装备提示框对比") == null,
					"悬停过消耗品格之后也不该存在对比列节点")
			# —— 背包装备格：右侧「身上穿戴件」对比列（§3.259，用户报修 15）——
			var 武器格: Button = null
			var 翻号 := 0
			while 武器格 == null and 翻号 < 9:
				var 钮2 := 页.get_node_or_null("分页/第%d页" % (翻号 + 1)) as Button
				if 钮2 == null or not 钮2.visible:
					break
				钮2.emit_signal("pressed")
				await process_frame
				for 子2 in _找有货格(页):
					if str(子2.get("物品id")) == 对比武器id:
						武器格 = 子2
						break
				翻号 += 1
			_check(武器格 != null,
					"背包九页里找不到种子武器 %s（对比列这条腿没法判）" % 对比武器id)
			_check(装框2 != null, "背包页应有 装备提示框 节点（悬停装备要靠它）")
			if 武器格 != null and 装框2 != null:
				武器格.mouse_entered.emit()
				await process_frame
				var 右列 := 页.get_node_or_null("装备提示框对比") as Control
				_check(装框2.visible, "悬停武器格应弹出装备提示框")
				_check(右列 != null and 右列.visible,
						"背包装备格右侧应有『身上穿戴件』对比列（原版 `ItemWindowCell.as:314` 四参）")
				if 右列 != null:
					var 左题 := 装框2.get_node_or_null("标题") as Label
					var 右题 := 右列.get_node_or_null("标题") as Label
					var 袋名 := String(GAME_DATA.item(对比武器id).get("name", ""))
					var 穿名 := String(GAME_DATA.item("01010011").get("name", ""))
					_check(左题 != null and 左题.text == 袋名,
							"左列＝悬停那件，标题不该混进后缀（期望 %s，实际 %s）" % [
								袋名, 左题.text if 左题 != null else "?"])
					_check(右题 != null and 右题.text == 穿名,
							"右列＝身上穿的那件（期望 %s，实际 %s）" % [
								穿名, 右题.text if 右题 != null else "?"])
					var 左缀 := 装框2.get_node_or_null("对比后缀") as Label
					var 右缀 := 右列.get_node_or_null("对比后缀") as Label
					_check(左缀 != null and not 左缀.visible,
							"(已装备) 只挂在右列（原版 `:1566` 只给 param2 置 compareSuffixHtml）")
					_check(右缀 != null and 右缀.visible and 右缀.text == "(已装备)",
							"右列标题应带 (已装备)（实际 %s）" % (右缀.text if 右缀 != null else "没有这个节点"))
					_check(absf(右列.position.x
							- (装框2.position.x + 装框2.size.x * 装框2.scale.x)) < 0.5,
							"右列应**紧贴**左列右边界（原版列间没有间距）：左列 %.1f 宽 %.1f、右列 %.1f" % [
								装框2.position.x, 装框2.size.x, 右列.position.x])
					_check(absf(右列.position.y - 装框2.position.y) < 0.5, "两列顶边应对齐")
					_check(右列.scale == 装框2.scale, "两列应同比例（原版是同一个 Sprite 整体缩放）")
					var 舞台尺 := Vector2(1280.0, 720.0)
					# ⚠️ 不用 `窗2.call("_舞台尺寸")`：无头里 `get_viewport().get_visible_rect()`
					#    是 **64x64**（没有真窗口），那条"整组超高就缩放"会先绑住 ⇒ 两列被压到
					#    合计 160 宽，右缘钳位这条就量不到了。这里测的是 `贴成一对` 这个函数本身，
					#    给它一个和真窗口同量级的舞台才是它该表现的行为。
					装框2.call("贴成一对", Vector2(舞台尺.x - 100.0, 20.0), 舞台尺, 右列)
					var 组宽 := 装框2.size.x * 装框2.scale.x + 右列.size.x * 右列.scale.x
					_check(absf(装框2.position.x - (舞台尺.x - 组宽)) < 0.5,
							"贴右缘时整组左移到 `舞台.x − 组宽`（钳位按**组宽**）：左列 %.1f、组宽 %.1f、舞台 %.1f" % [
								装框2.position.x, 组宽, 舞台尺.x])
					_check(右列.position.x + 右列.size.x * 右列.scale.x <= 舞台尺.x + 0.5,
							"右列不许越出舞台右缘")
				武器格.mouse_exited.emit()
				await process_frame
				_check(右列 == null or not 右列.visible, "移开鼠标时对比列应与主框一起收起")
				# 槽位空 ⇒ 退回单列（原版 `param2` 为 null 时那一支整块不进）。
				# `原武器` 已在 `_收尾` 里还原，这里改的是内存、不落盘。
				会话.equipped_items.erase(部位.位置("01010011"))
				武器格.mouse_entered.emit()
				await process_frame
				var 右列2 := 页.get_node_or_null("装备提示框对比") as Control
				_check(装框2.visible, "空槽位时左列（主框）照常显示")
				_check(右列2 == null or not 右列2.visible,
						"槽位空就不该有对比列（拿悬停件自己当穿戴件是假对比）")
		_关窗(窗2)

	# —— 宠物页（2026-10-18 用户实机报修「宠物面板装备鼠标放上去没有装备提示框」）——
	# 原版 `SimpleItemCell.setItemData` 结尾给**每一格**挂 `MToolTipItem.createToolTip`
	# （`SimpleItemCell.as:220`），宠物五槽与背包格本来就是同一套提示框；
	# 我们这里当时只写了原生 `tooltip_text`，页面里连提示框节点都没有 ⇒ 什么都弹不出来。
	# ⚠️ 宠物页这条腿**自带种子**：`pets` 是共享存档里的东西，别的离线门会把它清空
	#    （§3.166 那一类"门读共享存档"的复发形态），红了的是环境不是代码。
	var 兽铠 := "02010060"
	_check(部位.位置(兽铠) == 1, "种子 %s 该落在宠物一（兽铠）位，否则这条腿量不到" % 兽铠)
	if (会话.pets as Array).is_empty():
		出厂宠 = (load("res://脚本/单例/离线示例数据.gd") as GDScript).create().get("pets", []) as Array
		会话.pets.assign(出厂宠)
	_check(not (会话.pets as Array).is_empty(), "宠物页这条腿要有一只宠（种子也没能种出来）")
	var 宠: Dictionary = (会话.pets[0] as Dictionary) if not (会话.pets as Array).is_empty() else {}
	if not 宠.is_empty():
		原装备 = 宠.get("equipment", null)
		var 件: Dictionary = (GAME_DATA.item(兽铠) as Dictionary).duplicate(true)
		_check(not 件.is_empty(), "种子的兽铠 %s 从物品表里取得到" % 兽铠)
		件["equipment_slot"] = 1
		件["slot_index"] = 1
		宠["equipment"] = [件]
		var 窗3: Node = await _开窗("宠物")
		if 窗3 != null:
			var 宠页 := (窗3.get("_content") as Control).find_child("原版宠物窗口内容", true, false)
			_check(宠页 != null, "找不到 原版宠物窗口内容")
			if 宠页 != null:
				# 节点必须在**页面根**：挂进 `装备面板`（TextureRect）里会被它的尺寸裁掉。
				var 宠框 := 宠页.get_node_or_null("装备提示框") as Control
				_check(宠框 != null, "宠物页页面根上应有 装备提示框 节点")
				_check(宠框 != null and not 宠框.visible, "悬停前宠物页提示框应收起")
				for 号 in [1, 2, 3, 4, 5]:
					var 格 := 宠页.get_node_or_null("装备槽_%d" % 号) as Button
					_check(格 != null, "缺装备槽_%d" % 号)
					if 格 == null:
						continue
					_check(String(格.tooltip_text).is_empty(),
							"宠物装备槽_%d 的原生 tooltip_text 应让位给原版提示框（实际 %s）" % [号, 格.tooltip_text])
					_check(not 格.mouse_entered.get_connections().is_empty(),
							"装备槽_%d 没接悬停（鼠标放上去不会有提示框）" % 号)
				var 一号 := 宠页.get_node_or_null("装备槽_1") as Button
				if 一号 != null:
					# 渲染是**每次开窗重来**的：先断后连这条要钉住，
					# 否则点一次卸下会发 N 发 16 号包（原来是 `pressed` 每渲染叠一条）。
					_check(一号.pressed.get_connections().size() == 1,
							"有货那格的 pressed 应只挂 1 条（实际 %d 条）" % 一号.pressed.get_connections().size())
					一号.mouse_entered.emit()
					await process_frame
					_check(宠框 != null and 宠框.visible, "悬停兽铠格应弹出装备提示框（用户报的就是这里什么都不出）")
					var 题 := 宠框.get_node_or_null("标题") as Label if 宠框 != null else null
					var 兽铠名 := String(GAME_DATA.item(兽铠).get("name", ""))
					_check(not 兽铠名.is_empty(), "物品表里 %s 该有名字" % 兽铠)
					_check(题 != null and 题.text == 兽铠名,
							"宠物提示框标题应是那件兽铠（实际 %s）" % (题.text if 题 != null else "?"))
					一号.mouse_exited.emit()
					await process_frame
					_check(宠框 != null and not 宠框.visible, "移开鼠标宠物页提示框应收起")
					# 宠物装备格**不带对比列**：原版 `EqpPetWindowCell.as:28` 也是 `!_isMyself`，
					# 而我们的宠物页只渲染自己的宠 ⇒ 调用点没传 `比穿戴件`。
					# ⚠️ 这条对"开关常开"那一刀是**空判**（§3.259 变异丁实测只红人物那条）：
					#    宠物槽位是**正数**（`装备部位.gd` 宠物一=1…宠物五=5），而
					#    `equipped_items` 的键全是**负数**的人物槽 ⇒ 即使误开也查不到件、建不出列。
					#    留着它钉的是**形状**：哪天有人把宠物件并进那张表，这条会立刻红。
					_check(宠页.get_node_or_null("装备提示框对比") == null,
							"宠物装备格不该建对比列（宠物槽位在 `equipped_items` 里没有键）")
			_关窗(窗3)
		宠物腿种过 = true
	_收尾()


## 宠物页那条腿自己种的东西，`_收尾` 里还原（只改内存，不落盘）。
var 出厂宠: Array = []
var 原装备: Variant = null
var 宠物腿种过 := false


## 跑前武器位穿的那件（`_run` 无条件换成 01010011，这里还原；只改内存，不落盘）。
var 原武器: Dictionary = {}


func _还原武器(会话: Node) -> void:
	var 位: int = 部位.位置("01010011")
	if 原武器.is_empty():
		(会话.equipped_items as Dictionary).erase(位)
	else:
		会话.equipped_items[位] = 原武器.duplicate(true)

## 找**有物品**的背包格（`物品格_N`；空格子的悬停只会收提示框，测不出东西）。
## 「这一格有没有货」的判据 = 格子上那条 `物品id`，**不是 `Button.icon != null`**。
## 2026-10-04 那次返工把真图标改成**格内子节点**（格内叠真图标 + 白色右对齐数量），
## `Button.icon` 只剩装备那一族还在设 ⇒ 拿 icon 当代理会把消耗品整片当成空格
## （2026-10-10 的全量假红：存档里明明有 03000001/04000001/16000014 三件非装备，
##   门却报「背包里找不到有物品的格子」—— 红的是量具，不是游戏）。
func _找有货格(页: Node) -> Array:
	var 出: Array = []
	for 子 in 页.get_node("格子滚动/格子容器").get_children():
		var 按 := 子 as Button
		if 按 == null:
			continue
		var 身: Variant = 按.get("物品id")
		if 身 != null and str(身) != "":
			出.append(按)
	return 出


## 红了要能自己说清环境：把会话里每一件物品的 `id:部位` 列出来（部位 0 = 非装备，能当种子）。
func _货表(会话: Node) -> Array[String]:
	var 列: Array[String] = []
	for 货 in (会话.inventory as Array):
		var 条: Dictionary = 货 as Dictionary
		if 条.is_empty():
			continue
		var id := String(条.get("id", 条.get("item_id", "")))
		列.append("%s:部位%d:%s" % [id, 部位.位置(id), String(条.get("category", ""))])
	return 列

const 部位 := preload("res://脚本/单例/装备部位.gd")
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")

func _开窗(页名: String) -> Node:
	var 场景 := (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	await process_frame
	if 场景.has_method("open_page"):
		场景.call("open_page", 页名)
	for _i in 30:
		await process_frame
	return 场景

func _关窗(窗: Node) -> void:
	窗.queue_free()

func _收尾() -> void:
	var 会话 := root.get_node_or_null("/root/GameSession")
	if 会话 != null:
		_还原武器(会话)
		if 宠物腿种过 and not (会话.pets as Array).is_empty():
			# 装备写回**原来那个值**（可能是"没有这个键"），兽铠那件只活在内存里
			var 宠 := 会话.pets[0] as Dictionary
			if 原装备 == null:
				宠.erase("equipment")
			else:
				宠["equipment"] = 原装备
			if not 出厂宠.is_empty():
				# 这只宠是本腿从出厂夹具种进去的（存档里本来没有宠）⇒ 一并撤掉
				会话.pets.assign([])
	if _失败.is_empty():
		print("格子悬停提示回归测试：通过（%d 条断言）" % _受检)
		quit(0)
		return
	for 项 in _失败:
		printerr("格子悬停提示回归测试：" + 项)
	quit(1)
