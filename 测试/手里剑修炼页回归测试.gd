extends SceneTree

## 手里剑页的七条腿 —— 钉用户 2026-10-18 实机报修的 2.1 / 2.2 / 2.3、2026-10-22 报修 3，
## 与任务 #85（「失败后自动继续」）。
##
## **A. 等级语义（2.3）**：协议帧 `1817:0:<stage>:<level>:…` 里那一位是**本阶等级 1..4**，
## 不是全局等级。原版收到后算 `shouLiJianRealLevel = 4*(stage-1) + level`
## （`JingMaiSource.as:415`），往 `updateView` 传的正是这个**累计值**（`:420`），
## 上限显示 `getMaxShouLiJianLevel(stage) = 4*stage`（`:250-253`）。
## ⇒ 十字手里剑（2 阶）练满：帧 `level=4` ⇒ 页面该写「8/8级」「已达瓶颈」。
##   旧写法当全局等级用 ⇒ 写「4/8级」，满了却显示还剩一半。
##
## **B. 点提升/突破不刷回执（2.1）**：原版 `AnQiProcessor` 那三跳（0 启用 / 1 突破 / 2 提速）
## 一个 `addNotice` 都没有 —— `ShouLiJianTiShengWindow.as:160/171` 发完只 `close()`。
## 界面等回帧重绘。原来宿主每发一次就弹一句「XX请求已发送，等待服务器确认」，
## 点一下刷一句，既呆板又挡后续操作（结印那条还有客户端 0.8 秒自动重发，刷屏最狠）。
## ⇒ 只保留**发不出去/离线**那一侧的话。
##
## **C. 突破瓶颈弹窗的「购买升阶物品」（2.2）**：原版它不买东西，只 dispatch 一条
## `REQUEST_CASH_ITEM_INFO`（`ThroughShouLiJianWindow.as:372-381` → `UI.as:197-205`
## → `Client.requestCashItemInfo(id, 0)`）⇒ 由回包 1079 弹商城购买窗。
## 本工程走 `功能窗口.请求商城商品` 这条**统一出口**（与扩容窗/材料格同一跳）。
## 满阶（7 阶，没有下一阶）时那枚该置灰。
##
## **F. 突破失败弹窗不该消失（2026-10-22 报修 3）**：失败那一发在结果帧**之前**先扣钱/精华/升阶道具
## ⇒ 服务端跟着来 `_send_stats` + 逐格库存帧 ⇒ `player_stats_changed` / `inventory_changed` 把
## `功能窗口._refresh_current` 叫醒。E 腿只堵了 `cultivation_changed` 那**一条**腿，这三条一样得原地刷
## （原版 `ThroughShouLiJianWindow` 订 `ITEM_DATAS_CHANGED` 就地换材料数，`toPoResult` 两支都不关窗）。
## ⚠ 2026-10-28 §3.307：用户**实机**又报同样的病。这条腿原来用**直发会话信号**演那两帧 ——
## 绕开了 `服务端同步.应用背包` 里那发**无条件的 `equipment_changed`**（`功能窗口:493` 是裸
## `_refresh_current`，一处裸连就把整圈守卫掀翻，弹窗还是被拆）。现在 F 腿照生产**逐帧推真字节**
## （`34:` 属性 + `32:1:` 扣料 + `1817:3` 结果 + `1817:0` 状态帧【这发原来漏演】+ `1817:1` 祝福），
## 并**数 `equipment_changed` 的发数**钉根因；F-4 是对照组：装备**真变**那一发照旧得发、页面照旧得重建。
##
## **G. 「失败后自动继续」（#85，2026-10-24）**：原版 `toPoHandler:185-223` 有**四道客户端预检**
## （`:193` 未到瓶颈 → `:198` 金币 → `:203` 精华 → `:208` 材料，材料不够时 `:210` 的「替身」能顶），
## 每道不过就一句 `addNotice` + `return`、**一发都不出去**；`toPoResult:360-370` 收结果帧 ——
## 成功只 `clearLayerTimeOut()`（**连勾选都不清**），失败且 `_failCheckBox.selected` 才
## `setTimeout(continueToPoShouLiJian, 900)` 自己再跳一发（`:383-387`，走 `toPoHandler(null)`
## ⇒ 不吃钮上那 1000ms 的 `isDelay`）。四道预检就是这条循环能自然停的原因。
##
## **H. 2026-10-29 实机两条报修**：
##   H-1「物品：手里剑木桩 数量的文字，与右侧本次突破幸运值的数值轴重叠了」——
##       突破弹窗下半截没按原版 `ThroughShouLiJianWindow.as:257-323` 排（物品值宽 121、
##       幸运条偏右 22px 又偏下 7px）⇒ 11px 高的一整条压在物品文字上。
##   H-2「角色手里剑，特殊能力，鼠标放上去没有详情框」——
##       原版每枚 `SkillCell` 自带 `MToolTipSkill`（`SkillCell.as:266-296`），本工程三枚图标
##       光换贴图、没接悬停。提示框要挂窗口 `遮罩`（页面 `clip_contents = true` 会整刀裁掉），
##       技能 id 还要**按当前预览阶现算**（4 阶 1 枚 / 5 阶 2 枚 / 6、7 阶 3 枚，id 跟着换）。
##
## 运行：Godot --headless --path . --script res://测试/手里剑修炼页回归测试.gd

const 数据 := preload("res://素材/界面/原版窗口/人物/手里剑/脚本/手里剑数据.gd")
const 装备部位 := preload("res://脚本/单例/装备部位.gd")

var _失败: Array[String] = []
var _受检 := 0
## 本门为 G 腿给会话发的资源（金币 / 精华 / 升阶道具）—— **收尾原样放回**。
## ⚠️ 只动内存也不行：会话层一落盘就把这些假数字写进真实玩档（§3.217 那起"三只假宠"血案同款）。
var _存属性 := {}
var _存库存: Array = []


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _帧 in 5:
		await process_frame

	var 会话: Node = root.get_node_or_null("/root/GameSession")
	if 会话 == null:
		_停("拿不到 GameSession")
		return
	var 后端: Node = root.get_node_or_null("/root/BackendConnection")
	if 后端 == null:
		_停("拿不到 BackendConnection")
		return
	var 管理: Node = 场景.get_node_or_null("窗口管理")
	var 窗 = 管理.call("取或建窗口", "人物") if 管理 != null else null
	if 窗 == null:
		_停("拿不到人物窗")
		return
	管理.call("打开", "人物")
	for _帧 in 4:
		await process_frame

	var 通知: Array = []
	会话.notification_requested.connect(func(文: String) -> void: 通知.append(文))
	# 突破那一跳自 #85 起有**四道客户端预检**（金币 / 精华 / 材料），B、D 两条腿也要按真链路
	# 走一遍 ⇒ 全程给足家当，收尾由 G 腿的 `_收资源` 按内存原样放回（§3.217）。
	_发资源(会话)

	# 手里剑在**角色**那一组（`子分页组[0] = 人物 / 手里剑 / 结印`），15 级开放。
	窗.call("_set_character_main_tab", 0)
	await process_frame
	窗.call("_set_character_sub_tab", 1)
	for _帧 in 4:
		await process_frame

	await _验等级语义(窗, 后端)
	await _验静默发送(窗, 后端, 通知)
	await _验购买升阶(窗, 后端, 通知)
	await _验购买窗压屏幕层(窗, 后端)
	await _验重影(窗, 后端, 通知)
	await _验幸运就地刷新(窗, 后端, 通知)
	await _验失败不拆台(窗, 后端, 会话, 通知)
	await _验失败继续(窗, 后端, 会话, 通知)
	await _验弹窗几何(窗, 后端)
	await _验技能提示(窗, 后端)
	窗.set("_backend", null)
	_收尾()


# ── A：等级是**累计值**，帧里那一位是本阶 1..4 ───────────────────────
func _验等级语义(窗, 后端) -> void:
	# A-1 先钉住换算不是"一律乘 4"：1 阶 3 级 ⇒ 累计还是 3。
	await _推帧(后端, 窗, "1817:0:1:3:100:true:0")
	var 页 := _取页(窗)
	if 页 == null:
		_失败.append("A 取不到手里剑页 ⇒ 这一整腿没量到")
		return
	_核字(页, "当前信息/当前等级/值", "3/4级", "1 阶 3 级：累计等级与上限")
	_核字(页, "详情面板/修炼等级/值", "3/4", "1 阶 3 级：等级条没到瓶颈")

	# A-2 用户报的那一档：2 阶练满（帧里 level=4、熟练度 5000）
	await _推帧(后端, 窗, "1817:0:2:4:5000:true:0")
	页 = _取页(窗)
	if 页 == null:
		return
	_核字(页, "当前信息/当前等级/值", "8/8级", "2 阶练满：累计等级 4*(2-1)+4=8、上限 4*2=8")
	_核字(页, "详情面板/修炼等级/值", "已达瓶颈", "2 阶练满：等级条该写已达瓶颈")
	# 填充现在走 `进度条补间` 的 0.5 秒补间（§3.243，`MBar.as:170`）⇒ 量之前等**墙上时钟**；
	# 上面那行文字仍是立即写（原版 `:151-168` 先写字、`:170` 才挂补间），所以放在等之前。
	await create_timer(0.7).timeout
	var 条 := 页.get_node_or_null("详情面板/修炼等级") as ProgressBar
	_断(条 != null and int(条.value) == 8 and int(条.max_value) == 8,
		"2 阶练满：等级条该画满 8/8，实测 %s/%s" % [
			str(条.value if 条 != null else -1), str(条.max_value if 条 != null else -1)])
	_核字(页, "详情面板/页码", "2/7", "帧换了阶段 ⇒ 预览页跳回当前阶")

	# A-3 提速弹窗里那行「等级/值」吃的是同一个累计值
	var 提速钮 := 页.get_node_or_null("详情面板/提升速度") as Button
	if 提速钮 == null:
		_失败.append("取不到「详情面板/提升速度」⇒ 提速弹窗那一腿没量到")
	else:
		提速钮.pressed.emit()
		await process_frame
		var 提速 := _取弹窗("修炼提速弹窗", 页)
		_断(提速 != null and 提速.visible, "点「提升速度」该打开修炼提速弹窗")
		_核字(提速, "等级/值", "8/8级", "提速弹窗的等级行同样该用累计值")
		await _关弹窗(提速)

	# A-4 翻页预览：已修炼过的阶（1 阶）与还没修炼的阶（3 阶）
	await _翻(页, -1)
	_核字(页, "详情面板/修炼等级/值", "已达瓶颈", "预览已修炼过的 1 阶")
	_核字(页, "详情面板/提升速度", "已修炼", "预览已修炼过的 1 阶：钮文字")
	var 提升 := 页.get_node_or_null("详情面板/提升速度") as Button
	_断(提升 == null or 提升.disabled, "预览已修炼过的阶时「提升速度」该置灰")
	await _翻(页, 1)
	await _翻(页, 1)
	_核字(页, "详情面板/修炼等级/值", "?/?", "预览还没修炼的 3 阶：等级未知")
	_核字(页, "详情面板/突破瓶颈", "未修炼", "预览还没修炼的 3 阶：钮文字")


# ── B：发**成功**一句提示都不给 ─────────────────────────────────────
func _验静默发送(窗, 后端, 通知) -> void:
	var 假 := 假后端.new()
	窗.set("_backend", 假)
	await _推帧(后端, 窗, "1817:0:2:1:100:true:0")
	var 页 := _取页(窗)
	if 页 == null:
		_失败.append("B 取不到手里剑页 ⇒ 这一整腿没量到")
		return

	# B-1 提升速度（单张）⇒ 一发 1817:2:0，**零回执**
	await _核发包(页, "详情面板/提升速度", "修炼提速弹窗", "开始提速",
		[2, false], 假, 通知, "单张提速")

	# B-2 「使用全部」要先过二次确认，确认后发 (2, true)
	var 提速钮 := 页.get_node_or_null("详情面板/提升速度") as Button
	提速钮.pressed.emit()
	await process_frame
	var 提速 := _取弹窗("修炼提速弹窗", 页)
	var 全部 := (提速.get_node_or_null("使用全部") if 提速 != null else null) as Button
	if 全部 == null:
		_失败.append("提速弹窗里找不到「使用全部」")
	else:
		假.手里剑.clear()
		通知.clear()
		全部.pressed.emit()
		await process_frame
		_断(假.手里剑.is_empty(),
			"点「使用全部」只该亮二次确认，**不能**直接发包（原版 `ShouLiJianTiShengWindow` 先弹确认）")
		var 确 := (提速.get_node_or_null("全部确认/确定") if 提速 != null else null) as Button
		if 确 == null:
			_失败.append("提速弹窗里找不到「全部确认/确定」")
		else:
			确.pressed.emit()
			await process_frame
			_断(假.手里剑 == [[2, true]], "确认「使用全部」该发一发 1817:2:1，实测 %s" % str(假.手里剑))
			_断(通知.is_empty(), "发成功不该刷回执（用户 2026-10-18 报修 2.1），实测 %s" % str(通知))
		await _关弹窗(提速)

	# B-3 突破瓶颈 ⇒ 一发 1817:1，零回执
	# ⚠️ 得先把状态推到**瓶颈**（`1817:0:2:4:5000`）：`toPoHandler` 那四道客户端预检（#85）
	#    没过就一句提示、**一发都不发**（原版 `:193`）。上面那帧 `2:1:100` 是拿来量提速的。
	#    资源（金币/精华/材料）由 `_发资源` 给足，收尾按内存原样放回。
	await _推帧(后端, 窗, "1817:0:2:4:5000:true:0")
	页 = _取页(窗)
	await _核发包(页, "详情面板/突破瓶颈", "手里剑突破瓶颈弹窗", "开始突破瓶颈",
		[1, false], 假, 通知, "突破瓶颈")

	# B-4 启用复选框 ⇒ 一发 1817:0:<bool>，零回执
	假.手里剑.clear()
	通知.clear()
	var 复 := 页.get_node_or_null("当前信息/启用复选框") as TextureButton
	if 复 == null:
		_失败.append("找不到「当前信息/启用复选框」")
	else:
		复.emit_signal("toggled", true)
		await process_frame
		_断(假.手里剑 == [[0, true]], "勾选启用该发 1817:0:1，实测 %s" % str(假.手里剑))
		_断(通知.is_empty(), "启用那一跳发成功也不该刷回执，实测 %s" % str(通知))

	# B-5 **离线**时才要讲话：一句「尚未连接原版游戏服务器」，别静默
	窗.set("_backend", null)
	await _推帧(后端, 窗, "1817:0:2:1:100:true:0")
	页 = _取页(窗)
	假.手里剑.clear()
	通知.clear()
	var 提速钮2 := 页.get_node_or_null("详情面板/提升速度") as Button
	提速钮2.pressed.emit()
	await process_frame
	var 提速2 := _取弹窗("修炼提速弹窗", 页)
	var 开始2 := (提速2.get_node_or_null("开始提速") if 提速2 != null else null) as Button
	if 开始2 == null:
		_失败.append("离线那一腿取不到「开始提速」")
	else:
		开始2.pressed.emit()
		await process_frame
		_断(假.手里剑.is_empty(), "离线不该发出去任何包")
		_断(通知.find("尚未连接原版游戏服务器") >= 0, "离线点提速该有明确回绝，实测 %s" % str(通知))
	通知.clear()


# ── C：突破瓶颈弹窗的「购买升阶物品」───────────────────────────────
func _验购买升阶(窗, 后端, 通知) -> void:
	var 假 := 假后端.new()
	窗.set("_backend", 假)
	await _推帧(后端, 窗, "1817:0:2:1:100:true:0")
	var 页 := _取页(窗)
	if 页 == null:
		_失败.append("C 取不到手里剑页 ⇒ 这一整腿没量到")
		return
	await _开突破弹窗(页)
	var 弹窗 := _取弹窗("手里剑突破瓶颈弹窗", 页)
	_断(弹窗 != null and 弹窗.visible, "点「突破瓶颈」该打开突破瓶颈弹窗")
	var 购 := (弹窗.get_node_or_null("购买升阶物品") if 弹窗 != null else null) as Button
	if 购 == null:
		_失败.append("突破瓶颈弹窗里找不到「购买升阶物品」")
		return
	_断(购.pressed.get_connections().size() == 1,
		"「购买升阶物品」该只接**一条**线（多连会一次发好几跳），实测 %d 条"
		% 购.pressed.get_connections().size())
	_断(not 购.disabled, "2 阶有下一阶 ⇒ 「购买升阶物品」不该置灰")
	假.商城.clear()
	通知.clear()
	购.pressed.emit()
	await process_frame
	var 期望id := int(((数据.取阶(3).get("up", {}) as Dictionary).get("物品id", 0)))
	_断(假.商城 == [期望id],
		"点「购买升阶物品」该发一发商城信息请求（物品 id %d，`ThroughShouLiJianWindow.as:372-381`），实测 %s"
		% [期望id, str(假.商城)])
	_断(通知.is_empty(), "商城请求发成功不该刷回执（回包 1079 自己会弹购买窗），实测 %s" % str(通知))
	await _关弹窗(弹窗)

	# C-2 满阶（7 阶没有下一阶）⇒ 购买与开始突破都置灰，按下也不该发东西
	await _推帧(后端, 窗, "1817:0:7:4:5000:true:0")
	页 = _取页(窗)
	await _开突破弹窗(页)
	var 弹窗7 := _取弹窗("手里剑突破瓶颈弹窗", 页)
	var 购7 := (弹窗7.get_node_or_null("购买升阶物品") if 弹窗7 != null else null) as Button
	var 开始7 := (弹窗7.get_node_or_null("开始突破瓶颈") if 弹窗7 != null else null) as Button
	_断(购7 != null and 购7.disabled, "7 阶（顶阶）时「购买升阶物品」该置灰")
	_断(开始7 != null and 开始7.disabled, "7 阶时「开始突破瓶颈」该置灰")
	_核字(弹窗7, "上信息/等级/值", "28/28级", "7 阶顶阶：累计等级 4*7")
	假.商城.clear()
	假.手里剑.clear()
	通知.clear()
	if 购7 != null:
		购7.pressed.emit()
	await process_frame
	_断(假.商城.is_empty() and 通知.is_empty(),
		"顶阶时 `_物品id` 是空的 ⇒ 就算程序化按下购买也不该发商城请求，实测 商城 %s、通知 %s"
		% [str(假.商城), str(通知)])
	await _关弹窗(弹窗7)

	# C-3 离线点购买 ⇒ 一句「购买：未连接服务端」，别静默
	await _推帧(后端, 窗, "1817:0:2:1:100:true:0")
	窗.set("_backend", null)
	页 = _取页(窗)
	await _开突破弹窗(页)
	var 弹窗离 := _取弹窗("手里剑突破瓶颈弹窗", 页)
	var 购离 := (弹窗离.get_node_or_null("购买升阶物品") if 弹窗离 != null else null) as Button
	通知.clear()
	if 购离 != null:
		购离.pressed.emit()
	await process_frame
	_断(通知.find("购买：未连接服务端") >= 0, "离线点「购买升阶物品」该有明确回绝，实测 %s" % str(通知))
	通知.clear()


# ── I：购买窗必须压在屏幕级弹窗之上 ─────────────────────────────
## 原版购买窗走 `PopUpMananger.centerWindow`（`UIMain2.addBuyWindow:2906-2913`）⇒ 挂在 stage 上、
## 永远在突破瓶颈窗（`windowMap` 里的 `UIWindow`）之上。本工程它平时住宿主 `遮罩`
## （= 宿主 CanvasLayer 111..118），而手里剑突破弹窗被 `手里剑页._弹出到屏幕层` 搬到根下
## 「屏幕弹窗层」(120) 还铺了整屏吞点击的暗幕 ⇒ 购买窗被整个盖住、点不着
## （用户 2026-11-01 报「点升阶道具，购买道具的面板显示优先级太低，被突破瓶颈面板盖住，看不见」）。
## 这里走生产的 `打开商城购买窗`（1079 的回包落点；「点购买钮 → 发 1086」那半条链在 C 腿）。
func _验购买窗压屏幕层(窗, 后端) -> void:
	await _推帧(后端, 窗, "1817:0:2:1:100:true:0")
	var 页 := _取页(窗)
	await _开突破弹窗(页)
	var 突破 := _取弹窗("手里剑突破瓶颈弹窗", 页)
	if 突破 == null or not 突破.visible:
		_失败.append("I：突破弹窗没开出来 ⇒ 购买窗的层序没量到")
		return
	var 屏层 := root.get_node_or_null("屏幕弹窗层") as CanvasLayer
	_断(屏层 != null and 屏层.layer == 120,
		"I-1：突破弹窗该在根下「屏幕弹窗层」(120)，实测 %s"
			% (str(屏层.layer) if 屏层 != null else "没有这一层"))
	窗.call("打开商城购买窗", {"sn": 16000061, "id": "16000061",
		"name": "手里剑升阶物品", "price": 1, "now_price": 1})
	await process_frame
	var 买 := _购买窗节点(窗)
	_断(买 != null and 买.visible, "I-2：点「购买升阶物品」的回包（1079）没弹出商城购买窗")
	if 买 == null:
		await _关弹窗(突破)
		return
	_断(_控件层号(买) > _控件层号(突破),
		"I-3：购买窗在层 %d、突破瓶颈弹窗在层 %d ⇒ 购买窗被盖住了"
			% [_控件层号(买), _控件层号(突破)])
	var 买遮 := _买窗遮罩节点(窗)
	_断(买遮 != null and 买遮.visible and _控件层号(买遮) > _控件层号(突破),
		"I-4：购买窗那层整屏遮罩没跟着抬上去（%s，层 %s）"
			% [str(买遮 != null and 买遮.visible), str(_控件层号(买遮) if 买遮 != null else -1)])
	_断(突破.visible, "I-5：弹购买窗不该把突破瓶颈弹窗关掉（原版两只并存，买完还要接着点突破）")
	买.call("隐藏")
	await process_frame
	_断((窗.get("_overlay") as Control).get_node_or_null("商城购买窗") == 买,
		"I-6：购买窗关掉后没搬回宿主遮罩 —— 之后找 `_overlay/商城购买窗` 的人（收起/刷新余额/重开复用）会落空")
	_断(买遮 != null and not 买遮.visible, "I-7：购买窗关掉后它的整屏遮罩还亮着（会继续吞点击）")
	await _关弹窗(突破)

	# I-8/I-9：屏幕级弹窗全收掉后，购买窗照旧**住宿主遮罩**（老口径：`商城购买窗回归测试` /
	# `购买窗单一宿主回归测试` / `窗口行为契约体检` 都按 `_overlay/商城购买窗` 找），
	# 关掉时那层整屏遮罩也得藏 —— 抬层只是"有屏幕级弹窗时"的例外，不是常态。
	窗.call("打开商城购买窗", {"sn": 16000062, "id": "16000062",
		"name": "手里剑升阶物品", "price": 1, "now_price": 1})
	await process_frame
	var 买2 := _购买窗节点(窗)
	_断(买2 != null and 买2.visible and 买2.get_parent() == (窗.get("_overlay") as Control),
		"I-8：没有屏幕级弹窗时购买窗不该被抬走（要留在宿主遮罩上）")
	if 买2 != null:
		买2.call("隐藏")
	await process_frame
	var 遮2 := _买窗遮罩节点(窗)
	_断(遮2 != null and not 遮2.visible, "I-9：关购买窗没藏掉那层整屏遮罩（平时那条路，不抬层时）")


# ── D：重绘重建页面 ⇒ 屏幕层里不能留僵尸弹窗 ───────────────────────
## `_render_page` 每次重绘 `queue_free` 整个 `_content`：页面是新实例，弹窗也是新实例，
## 而**上一轮搬进「屏幕弹窗层」的那枚不会跟着页面一起没**。它连的是已释放的旧页面 ⇒
## 玩家眼前这张还亮着、点「开始突破瓶颈」却毫无反应（2026-10-18 报修"很呆滞"里的一半）；
## 层里留着同名旧件，下一次搬进来的新窗还会被 Godot 顶成 `@Control@431` 这种自动名。
## ⇒ `手里剑页._exit_tree` 必须把自己搬出去的两张弹窗和暗幕一起收掉。
func _验重影(窗, 后端, 通知) -> void:
	var 假 := 假后端.new()
	窗.set("_backend", 假)
	await _推帧(后端, 窗, "1817:0:2:1:100:true:0")
	var 页 := _取页(窗)
	await _开突破弹窗(页)
	var 数 := _层同名("手里剑突破瓶颈弹窗")
	_断(数 == [1, 1], "第一次打开：屏幕层里该有 1 枚、亮着，实测 亮%d/共%d" % [数[0], 数[1]])

	# D-1 弹窗开着的时候来一帧服务端状态 ⇒ 页面重建，僵尸弹窗不该还留在屏幕上
	await _推帧(后端, 窗, "1817:0:2:2:100:true:0")
	数 = _层同名("手里剑突破瓶颈弹窗")
	_断(数[0] == 0, "重绘之后层里不该留着一枚亮着的突破弹窗（它连的页面已经没了，点不动），实测 %d 枚" % 数[0])
	var 层 := root.get_node_or_null("屏幕弹窗层") as CanvasLayer
	var 暗幕 := (层.get_node_or_null("手里剑弹窗暗幕") as CanvasItem) if 层 != null else null
	_断(暗幕 != null and not 暗幕.visible, "重绘之后暗幕也该跟着收掉，不然整屏一直暗着")

	# D-2 再点开 ⇒ 必须是**活的**那一张：名字没被顶成自动名、点下去真发包
	# （同 B-3：要发得出包就得先在瓶颈上 —— 预检是 #85 那四道。）
	await _推帧(后端, 窗, "1817:0:2:4:5000:true:0")
	页 = _取页(窗)
	await _开突破弹窗(页)
	数 = _层同名("手里剑突破瓶颈弹窗")
	_断(数 == [1, 1], "重绘后再点开：层里该只有 1 枚、且亮着，实测 亮%d/共%d" % [数[0], 数[1]])
	var 弹窗 := _取弹窗("手里剑突破瓶颈弹窗", 页)
	_断(弹窗 != null and String(弹窗.name) == "手里剑突破瓶颈弹窗",
		"搬进屏幕层的弹窗名不该被顶成自动名（层里重名会这样），实测 %s"
		% str(弹窗.name if 弹窗 != null else "无"))
	var 开始 := (弹窗.get_node_or_null("开始突破瓶颈") if 弹窗 != null else null) as Button
	if 开始 == null:
		_失败.append("D-2 取不到「开始突破瓶颈」")
	else:
		假.手里剑.clear()
		通知.clear()
		开始.pressed.emit()
		await process_frame
		_断(假.手里剑 == [[1, false]],
			"重绘后这张弹窗该是活的：点「开始突破瓶颈」要发一发 1817:1，实测 %s" % str(假.手里剑))
		_断(通知.is_empty(), "发成功不该刷回执，实测 %s" % str(通知))
	窗.set("_backend", null)


## ── E：修炼回帧只该**原地**刷页，开着的弹窗不能收掉、幸运值要当场涨 ──────
## 原版 `JingMaiSource.as:429-437 onAnQi_updateZhuFu` 收 `1817:1` 后直接
## `windowMap[THROUGH_SHOU_LI_JIAN_WINDOW].updateXingYunValue(值)`；本工程原来
## 每帧整页重建 ⇒ 弹窗一闪就没、突破失败加的 1-3 点幸运值永远看不见（2026-10-20 报修 2.1）。
func _验幸运就地刷新(窗, 后端, 通知) -> void:
	var 假 := 假后端.new()
	窗.set("_backend", 假)
	后端.call("_handle_bridge_text", "1817:0:2:4:5000:true:0")
	for _帧 in 4:
		await process_frame
	var 页 := _取页(窗)
	if 页 == null:
		_失败.append("E 取不到手里剑页 ⇒ 这一整腿没量到")
		return
	await _开突破弹窗(页)
	var 弹窗 := _取弹窗("手里剑突破瓶颈弹窗", 页)
	if 弹窗 == null or not 弹窗.visible:
		_失败.append("E 点「突破瓶颈」没打开弹窗")
		return
	var 上限 := 1
	var 下 := 数据.取阶(3)
	if not 下.is_empty():
		上限 = maxi(1, int((下["up"] as Dictionary)["幸运满"]))
	_核字(弹窗, "下信息/幸运条/幸运文字", "0/%d" % 上限, "E 开窗时幸运值该是 0")
	# 服务端「突破失败加幸运值」那一帧 `1817:1:<值>`（`_send_cultivation_blessing`）：
	# 走真实链路（后端解析 → 会话 `cultivation_changed` → 功能窗口原地刷新），不手动重绘。
	后端.call("_handle_bridge_text", "1817:1:7")
	## 等的是**墙上时钟**：这里既要让回帧走完（后端 → 会话 → 功能窗口原地刷新），
	## 又要让幸运条那 0.5 秒补间落位（§3.243，`ThroughShouLiJianWindow.as:394-400` 的 `_xinYunBar`
	## 是 MBar ⇒ 本工程 `_设条` 已接 `进度条补间.灌值`）。无头里 `process_frame` 短到微秒，
	## 原来那 6 帧只够第一件事、量条必然假红。
	await create_timer(0.7).timeout
	_断(is_instance_valid(弹窗) and (弹窗 as Control).visible,
		"E 回帧后突破弹窗该还开着，实测 %s" % ("没了" if not is_instance_valid(弹窗) else "关了"))
	if is_instance_valid(弹窗) and (弹窗 as Control).visible:
		_核字(弹窗, "下信息/幸运条/幸运文字", "7/%d" % 上限, "E 幸运值该当场刷成 7")
		var 条 := 弹窗.get_node_or_null("下信息/幸运条") as ProgressBar
		_断(条 != null and int(条.value) == 7,
			"E 幸运条该填到 7，实测 %s" % str(条.value if 条 != null else -1))
	await _关弹窗(弹窗)
	# E-2 升阶结果帧：手里剑的**动作号是 3**（不是别族的 2）⇒ 修前一句提示都没有。
	通知.clear()
	后端.call("_handle_bridge_text", "1817:3:0:false")
	for _帧 in 3:
		await process_frame
	_断(通知 == ["很抱歉，进阶失败！"], "E-2 手里剑突破失败该弹一句失败提示，实测 %s" % str(通知))
	通知.clear()
	后端.call("_handle_bridge_text", "1817:3:1:false")
	for _帧 in 3:
		await process_frame
	_断(通知 == ["恭喜你进阶成功！"], "E-2 手里剑突破成功该弹一句成功提示，实测 %s" % str(通知))
	窗.set("_backend", null)


## ── F：突破**失败**那一发除了结果帧，还先扣钱/精华/升阶道具 ⇒ 库存与属性帧同样不许拆台 ──
## 用户 2026-10-22 报修 3「手里剑突破瓶颈失败，突破瓶颈的界面不应该消失」。
## E 腿堵的是 `cultivation_changed` **那一条**叫醒腿；而失败在服务端是**五帧**（`2.2.3/tools/fake_flash_server.py:52639-52688`）：
## 先 `_consume_inventory_quantity` + 扣 `money`/`zq`，再 `_send_stats` → 逐格库存帧 → `1817:3:0` 结果
## → `1817:1` 幸运 → `1817:0` 状态。前两帧经 `服务端会话同步.gd:66/117` 变成 `player_stats_changed` /
## `inventory_changed`，这两个信号**直连** `功能窗口._refresh_current` ⇒ 修前无条件排队整页重绘
## ⇒ `_content` 重建、`手里剑页._exit_tree` 连搬到「屏幕弹窗层」的突破弹窗一起 `queue_free`
## ⇒ 玩家看到的就是"失败之后界面自己没了"。
## 原版：`ThroughShouLiJianWindow.as:97` 订的是 `EventManager.ITEM_DATAS_CHANGED` ⇒ 库存来了走
## `itemDataChangedHandler`（`:181`）**就地**换材料数、窗不动；结果帧 `toPoResult()`（`:360-370`）
## 成功只 `clearLayerTimeOut`、失败只在勾了「失败继续」时排一发 900ms 重试 —— **两支都不关窗**。
func _验失败不拆台(窗, 后端, 会话, 通知) -> void:
	var 假 := 假后端.new()
	窗.set("_backend", 假)
	后端.call("_handle_bridge_text", "1817:0:2:4:5000:true:0")
	for _帧 in 4:
		await process_frame
	var 页 := _取页(窗)
	if 页 == null:
		_失败.append("F 取不到手里剑页 ⇒ 这一整腿没量到")
		return
	await _开突破弹窗(页)
	var 弹窗 := _取弹窗("手里剑突破瓶颈弹窗", 页)
	if 弹窗 == null or not 弹窗.visible:
		_失败.append("F 点「突破瓶颈」没打开弹窗 ⇒ 这一整腿没量到")
		窗.set("_backend", null)
		return
	var 页id := 页.get_instance_id()
	# 失败那一发的**前两帧**（扣钱 / 扣道具）照生产逐帧推**真字节**（串形 =
	# `fake_flash_server._advance_stage_cultivation` 失败支第 ①② 步：`_send_stats({MONEY,ZQ})`
	# 一发 `34:27&<金>@22&<精>`，再**每件扣料**一发 `32:1:<from_drop>:<id>:<格>:<新数量>:1:1`）。
	# ⚠ 原来这两行是**直发会话信号**糊过去的 —— 那条路不经过 `服务端同步.应用背包`，
	#   永远碰不到"扣料帧捎带一发 `equipment_changed`"这一真凶（§3.307，2026-10-28 用户实机又报）。
	# ⚠ 离线起手 `后端连接` 从没收过 2050/2051，两份镜像是**空的**：先把会话当前包/装备同步进
	#   镜像再推 —— 不然 `应用背包` 落的是"空背包+空装备表"，那是测试污染，不是生产形态
	#   （生产那发落在**同一份包**上、只是材料 -1、装备表原样）。
	var 扣料格 := 1
	var 镜像: Array[Dictionary] = []
	var 扣的件: Dictionary = {}
	for 项 in 会话.inventory:
		var 副本: Dictionary = (项 as Dictionary).duplicate(true)
		if 扣的件.is_empty() and int(副本.get("id", 0)) == 16000032:
			副本["slot_index"] = 扣料格
			扣的件 = 副本
		镜像.append(副本)
	后端.set("authoritative_inventory", 镜像)
	后端.set("authoritative_equipment", (会话.equipped_items as Dictionary).duplicate(true))
	var 装备帧 := {"数": 0}
	var 数装备 := func(_装: Dictionary) -> void: 装备帧["数"] += 1	# ⚠ 形参类型照 `signal equipment_changed(equipment: Dictionary)`
	会话.equipment_changed.connect(数装备)
	后端.call("_handle_bridge_text", "34:27&%d@22&%d" % [
		int(会话.player_stats["gold"]) - 1000, maxi(0, int(会话.player_stats["zq"]) - 10)])
	var 新数量: int = int(扣的件.get("quantity", 1)) - 1 if not 扣的件.is_empty() else 0
	后端.call("_handle_bridge_text", "32:1:0:16000032:%d:%d:1:1" % [扣料格, 新数量])
	for _帧 in 6:
		await process_frame
	会话.equipment_changed.disconnect(数装备)
	# ⭐ 根因钉子：装备表一个键没动 ⇒ `equipment_changed` 该**零发**。发过一发，
	#   `功能窗口:493` 的裸 `_refresh_current` 就把下面三条守卫全绕过去（§3.307 病根）。
	_断(int(装备帧["数"]) == 0,
		"F 扣料帧捎带了 %d 发 `equipment_changed` ⇒ 装备没变就该**零发**（`应用背包` 只在真变了才发，"
		% int(装备帧["数"]) + "裸连的重建把 §3.264 那圈守卫整个掀翻）")
	_断(is_instance_valid(弹窗) and (弹窗 as Control).visible,
		"F 库存/属性帧之后突破弹窗该还开着（用户报修 3），实测 %s" % (
			"整枚没了" if not is_instance_valid(弹窗) else "被关掉了"))
	var 页新 := _取页(窗)
	_断(页新 != null and 页新.get_instance_id() == 页id,
		"F 这条腿该**原地刷**、不该重建页面（重建 = 换实例 = 弹窗被 `_exit_tree` 一起收掉），"
		+ "实测 %s" % ("页面没了" if 页新 == null else str(页新.get_instance_id())))
	# F-2 结果帧：失败只出一句提示，窗留着（`JingMaiSource.as:273-286` → `toPoResult(0)`）
	通知.clear()
	后端.call("_handle_bridge_text", "1817:3:0:false")
	for _帧 in 3:
		await process_frame
	_断(is_instance_valid(弹窗) and (弹窗 as Control).visible,
		"F-2 失败结果帧之后突破弹窗也该还开着（原版 `toPoResult(0)` 不关窗）")
	_断(通知 == ["很抱歉，进阶失败！"], "F-2 失败那句提示该有，实测 %s" % str(通知))
	# F-2b 失败后服务端**还补一发状态帧**（`_advance_stage_cultivation` 的 ④ `_send_an_qi_state()`，
	# 就插在结果帧与祝福帧之间）。这条腿 10-22 那回没演它 —— 现在逐帧补齐。
	后端.call("_handle_bridge_text", "1817:0:2:4:5000:true:0")
	for _帧 in 3:
		await process_frame
	_断(is_instance_valid(弹窗) and (弹窗 as Control).visible,
		"F-2b 失败后的 1817:0 状态帧之后突破弹窗也该还开着")
	# F-3 失败加的 1-3 点幸运值，要当场刷在**开着**的那张弹窗上
	var 上限 := 12
	var 下 := 数据.取阶(3)
	if not 下.is_empty():
		上限 = maxi(1, int((下["up"] as Dictionary)["幸运满"]))
	后端.call("_handle_bridge_text", "1817:1:3")
	await create_timer(0.7).timeout
	_断(is_instance_valid(弹窗) and (弹窗 as Control).visible,
		"F-3 幸运值帧之后突破弹窗该还开着")
	if is_instance_valid(弹窗) and (弹窗 as Control).visible:
		_核字(弹窗, "下信息/幸运条/幸运文字", "3/%d" % 上限, "F-3 失败加的幸运值该当场刷到条上")
	if is_instance_valid(弹窗):
		await _关弹窗(弹窗)
	# F-4 **对照组**：上面那道守卫不能修成死闸 —— 装备表**真变了**那一发照旧得发、
	#   页面照旧得重建（换装要刷装备格/属性，这正是 `功能窗口:493` 留裸 `_refresh_current` 的需求）。
	#   用 flag 8 的 32 子帧走**同一咽喉** `应用背包`（`_set_slot_quantity` 砸不到空槽 ⇒ 纯捎带路径）。
	var 装备底: Dictionary = (会话.equipped_items as Dictionary).duplicate(true)
	var 加一件: Dictionary = (后端.get("authoritative_equipment") as Dictionary).duplicate(true)
	加一件[装备部位.武器] = {"id": "01020020", "slot_index": 装备部位.武器, "quantity": 1}
	后端.set("authoritative_equipment", 加一件)
	后端.call("_handle_bridge_text", "32:8:999:1")
	for _帧 in 8:
		await process_frame
	var 页四 := _取页(窗)
	_断(页四 != null and 页四.get_instance_id() != 页id,
		"F-4 装备真变了 ⇒ `equipment_changed` 照旧该发、页面照旧该重建（换装是真重建需求），"
		+ "实测 %s" % ("页面没了" if 页四 == null else ("没重建，还是 " + str(页四.get_instance_id()))))
	# 放回原样再走同一咽喉（装备从"有武器"变回空 ⇒ 又是一次真变化，会话不留测试残渣）
	后端.set("authoritative_equipment", 装备底.duplicate(true))
	后端.call("_handle_bridge_text", "32:8:999:1")
	for _帧 in 4:
		await process_frame
	# 会话背包里那摞镜像写回的 39 根木桩由 G 腿 `_给满材料` 重新灌满；金币/精华由 `_收资源` 放回。
	窗.set("_backend", null)


## ── G：#85 四道客户端预检 + 「失败后自动继续」的 900ms 自跳 ──────────────────
## 真值全在 `ThroughShouLiJianWindow.as`：`toPoHandler:185-223`（四道预检，每道一句 `addNotice`
## 就 `return`，**过不了连一发都不发**）、`toPoResult:360-370`（成功只 clearTimeout；失败且勾选
## ⇒ `setTimeout(continueToPoShouLiJian, 900)`）、`continueToPoShouLiJian:383-387`
## （重试走 `toPoHandler(null)`，不经过那枚钮 ⇒ 不吃 `isDelay` 的 1000ms）、
## `continueToPoHandler:428-434`（取消勾选 ⇒ clearTimeout）。
func _验失败继续(窗, 后端, 会话, 通知) -> void:
	var 假 := 假后端.new()
	窗.set("_backend", 假)
	var 上三: Dictionary = 数据.取阶(3)["up"]
	var 材料名 := String(上三["物品名"])

	# G-1 ~ G-4 四道预检各自的句子与顺序（`:193` → `:198` → `:203` → `:208`）
	await _预检拦(窗, 后端, 假, 通知, "1817:0:2:1:100:true:0",
		"尚未达到修炼瓶颈的手里剑，无法进行突破操作！", "G-1 未到瓶颈")
	会话.player_stats["gold"] = 0
	await _预检拦(窗, 后端, 假, 通知, "1817:0:2:4:5000:true:0",
		"对不起，你的金币不足", "G-2 金币不足")
	会话.player_stats["gold"] = 900000
	会话.player_stats["zq"] = 0
	await _预检拦(窗, 后端, 假, 通知, "1817:0:2:4:5000:true:0",
		"很抱歉，你的查克拉精华不够", "G-3 精华不足")
	会话.player_stats["zq"] = 900
	会话.inventory.clear()
	await _预检拦(窗, 后端, 假, 通知, "1817:0:2:4:5000:true:0",
		"很抱歉，你的背包中没有足够的%s！" % 材料名, "G-4 材料不足（%s 没带）" % 材料名)
	# G-5 顶阶：下一阶配置不存在 ⇒ `:221` 那句（`_tuPoBtn` 这时已置灰，程序化按下也得有正确的话）
	await _预检拦(窗, 后端, 假, 通知, "1817:0:7:4:5000:true:0",
		"该手里剑已达到最高阶，无需进行突破操作！", "G-5 顶阶")
	# G-6 材料不够但背包里有「替身」（手里剑神符）⇒ 原版 `:210` 那道 `fakeItemId` 放它过去。
	# 4→5 阶那档才有替身（表里 `替身id = 16000036`，1..3 阶那个键是 0 = 没有）。
	会话.inventory.append({"id": 16000036, "quantity": 1, "name": "手里剑神符"})
	await _推帧(后端, 窗, "1817:0:4:4:5000:true:0")
	var 页六 := _取页(窗)
	await _开突破弹窗(页六)
	var 弹窗六 := _取弹窗("手里剑突破瓶颈弹窗", 页六)
	if 弹窗六 != null:
		假.手里剑.clear()
		通知.clear()
		(弹窗六.get_node_or_null("开始突破瓶颈") as Button).pressed.emit()
		await process_frame
		_断(假.手里剑 == [[1, false]],
			"G-6 材料不够但有一张替身神符 ⇒ 原版 `:210` 该放它过去、发一发，实测 %s" % str(假.手里剑))
		_断(通知.is_empty(), "G-6 放行那一跳不该有话，实测 %s" % str(通知))
		await _关弹窗(弹窗六)

	# G-7 勾选 → 失败帧 → 900ms 自己再跳一发
	_给满材料(会话)
	await _推帧(后端, 窗, "1817:0:2:4:5000:true:0")
	var 页 := _取页(窗)
	await _开突破弹窗(页)
	var 弹窗 := _取弹窗("手里剑突破瓶颈弹窗", 页)
	if 弹窗 == null:
		_失败.append("G-7 开不出突破弹窗 ⇒ 自动重试那一整腿没量到")
		_收资源(会话)
		窗.set("_backend", null)
		return
	_按勾(弹窗, true)
	_断(bool(窗.get("_手里剑失败继续")),
		"G-7 点勾该把状态记到**窗口**上（页面重绘会换掉弹窗件，记在控件上一帧就丢）")
	假.手里剑.clear()
	(弹窗.get_node_or_null("开始突破瓶颈") as Button).pressed.emit()
	await process_frame
	_断(假.手里剑 == [[1, false]], "G-7 手动那一跳该发一发，实测 %s" % str(假.手里剑))
	假.手里剑.clear()
	通知.clear()
	后端.call("_handle_bridge_text", "1817:3:0:false")		# 失败结果帧，走真实链路
	await create_timer(1.4).timeout		# 900ms 那一发是**墙上时钟**，留 500ms 余量
	_断(假.手里剑 == [[1, false]],
		"G-7 失败 + 勾选 ⇒ 900ms 后该**自己再跳一发**（原版 `setTimeout(continueToPoShouLiJian,900)`），实测 %s"
		% str(假.手里剑))
	_断(通知 == ["很抱歉，进阶失败！"],
		"G-7 自跳那一发不该再补一句回执（B 腿口径：发包侧零提示），实测 %s" % str(通知))

	# G-8 取消勾选 ⇒ 排队那发撤掉（`continueToPoHandler:428-434` 的 clearTimeout）
	假.手里剑.clear()
	后端.call("_handle_bridge_text", "1817:3:0:false")
	_按勾(弹窗, false)
	await create_timer(1.4).timeout
	_断(假.手里剑.is_empty(), "G-8 取消勾选后，排队中的那发不该再跳，实测 %s" % str(假.手里剑))
	_断(not bool(窗.get("_手里剑失败继续")), "G-8 取消勾选该把窗口状态刷回 false")

	# G-9 玩家自己关窗 ⇒ 不再跳（**有意偏离** `onCloseBtnClick:94-98`：原版只摘库存监听、
	# 不 clearTimeout ⇒ 挂着勾关窗，客户端还在每 900ms 自发、把钱和材料悄悄耗光）
	_按勾(弹窗, true)
	假.手里剑.clear()
	后端.call("_handle_bridge_text", "1817:3:0:false")
	await _关弹窗(弹窗)
	await create_timer(1.4).timeout
	_断(假.手里剑.is_empty(),
		"G-9 关窗后不再悄悄烧钱（本工程登记的有意偏离），实测 %s" % str(假.手里剑))

	# G-10 成功帧 ⇒ clearTimeout，但**不清勾选**（`toPoResult(1):362-365`）
	假.手里剑.clear()
	通知.clear()
	后端.call("_handle_bridge_text", "1817:3:1:false")
	await create_timer(1.4).timeout
	_断(假.手里剑.is_empty(), "G-10 成功帧之后不该再有下一发，实测 %s" % str(假.手里剑))
	_断(bool(窗.get("_手里剑失败继续")), "G-10 成功不该替玩家把勾抹掉（原版只 clearTimeout）")

	# G-11 整页重绘 ⇒ 弹窗是**新实例**，勾选态得从窗口回灌（`人物窗口.初始化手里剑页`）
	await _推帧(后端, 窗, "1817:0:2:4:5000:true:0")
	var 页新 := _取页(窗)
	await _开突破弹窗(页新)
	var 弹窗新 := _取弹窗("手里剑突破瓶颈弹窗", 页新)
	if 弹窗新 == null:
		_失败.append("G-11 重绘后开不出突破弹窗 ⇒ 回灌那一腿没量到")
	else:
		var 勾新 := 弹窗新.get_node_or_null("失败后自动继续") as TextureButton
		_断(勾新 != null and 勾新.button_pressed,
			"G-11 重绘后新弹窗件上那枚勾该亮着（从 `窗口._手里剑失败继续` 回灌），实测 %s"
			% ("没有这枚钮" if 勾新 == null else str(勾新.button_pressed)))
		await _关弹窗(弹窗新)
	窗.set("_手里剑失败继续", false)

	# G-12 「开始突破瓶颈」**不许有点击 CD**（用户 2026-10-31 报「连续点没有用、停顿太长，
	# 应该跟其他突破境界一样丝滑」）。原版这枚钮挂 `isDelay = true`（`ThroughShouLiJianWindow.as:343`
	# → `MButton3.as:625-636 / :568-579`，1000ms 吞第二下），但写轮眼/柔拳/轮回六道/结印/八门
	# 那几颗突破钮都没有 ⇒ 本工程按用户口径统一成不节流，这里钉死「连点两下发两发」。
	await _推帧(后端, 窗, "1817:0:2:4:5000:true:0")
	var 页四 := _取页(窗)
	await _开突破弹窗(页四)
	var 弹窗四 := _取弹窗("手里剑突破瓶颈弹窗", 页四)
	if 弹窗四 == null:
		_失败.append("G-12 开不出突破弹窗 ⇒ 连点那一腿没量到")
	else:
		假.手里剑.clear()
		var 钮 := 弹窗四.get_node_or_null("开始突破瓶颈") as Button
		钮.pressed.emit()
		钮.pressed.emit()
		await process_frame
		_断(假.手里剑 == [[1, false], [1, false]],
			"G-12 连点两下该发**两发**（本工程有意偏离原版 isDelay，与其他突破钮一致），实测 %s"
			% str(假.手里剑))
		await _关弹窗(弹窗四)
	_收资源(会话)
	窗.set("_backend", null)


## ── H-1：突破弹窗下半截的版式（用户 2026-10-29 实机报修「物品数量与幸运值轴重叠」）──
## 逐行照 `ThroughShouLiJianWindow.as:257-323`（坐标都相对 `_loc3_` 面板左上）：
##   `_needLabel`/`_ratioLabel` y=4、MLabel 构造里 `setSize(0,20)`；
##   `_ratioBar.y = _ratioLabel.y + 20 = 24`，MBar 画 11 高；
##   `_xinYunLabel.y = _ratioBar.y + _ratioBar.height + 10 = 45`，高 20；
##   `_xinYunBar.y = _xinYunLabel.y + 20 = 65`；**`_xinYunBar.x = _ratioBar.x`**（同一条左线，
##   `_ratioBar.x = _ratioLabel.x - 42`）；
##   三行材料是 `BaseUtil.getFormItem(…,[74,80],false)` ⇒ `FormItem2.setTitleAndContentSize`
##   把正文放到 `标题x + 74 + 4`、宽 80，行高 20、行间 +4 ⇒ 金币 24、精华 48、物品 72。
## 物品值行 72..92 里 12px 字居中 ⇒ 字顶 = 72 + (20-12)/2 = 76；幸运条底 = 65 + 11 = 76
## ⇒ 原版是**贴边不压字**。修前本工程物品值宽 121（右到 200）、幸运条 x=145 y=72（底 83）
## ⇒ 一整条 11px 压在物品文字上 —— 就是玩家看到的那处重叠。
func _验弹窗几何(窗, 后端) -> void:
	var 假 := 假后端.new()
	窗.set("_backend", 假)
	await _推帧(后端, 窗, "1817:0:2:1:100:true:0")
	var 页 := _取页(窗)
	if 页 == null:
		_失败.append("H-1 取不到手里剑页 ⇒ 版式这一腿没量到")
		return
	await _开突破弹窗(页)
	var 弹窗 := _取弹窗("手里剑突破瓶颈弹窗", 页)
	if 弹窗 == null or not 弹窗.visible:
		_失败.append("H-1 点「突破瓶颈」没打开弹窗")
		return
	var 物 := 弹窗.get_node_or_null("下信息/物品值") as Control
	var 物题 := 弹窗.get_node_or_null("下信息/物品标题") as Control
	var 精 := 弹窗.get_node_or_null("下信息/精华值") as Control
	var 幸条 := 弹窗.get_node_or_null("下信息/幸运条") as Control
	var 幸题 := 弹窗.get_node_or_null("下信息/幸运标题") as Control
	var 成条 := 弹窗.get_node_or_null("下信息/成功率条") as Control
	if 物 == null or 物题 == null or 精 == null or 幸条 == null or 幸题 == null or 成条 == null:
		_失败.append("H-1 下信息里缺件（物品值/物品标题/精华值/幸运条/幸运标题/成功率条）")
		await _关弹窗(弹窗)
		return
	# 物品正文：宽 80（AS3 `[74,80]` 的第二位），左缘 = 标题宽 74 + FormItem2.gap 4
	_断(is_equal_approx(物.size.x, 80.0),
		"H-1 物品值宽该是 80（原版 `getFormItem(…,[74,80])` 的正文宽），实测 %s" % str(物.size.x))
	_断(is_equal_approx(物.position.x, 物题.position.x + 78.0),
		"H-1 物品值该从标题左缘 +74+4 起（`FormItem2.as:73-79`），实测 标题x %s、值x %s"
		% [str(物题.position.x), str(物.position.x)])
	_断(is_equal_approx(物.position.y, 精.position.y + 24.0),
		"H-1 物品行该压在精华行下 20+4 处（AS3 三行 `_moneyField.y + height + 4`），实测 精华y %s、物品y %s"
		% [str(精.position.y), str(物.position.y)])
	# 幸运条：与成功率条**同一条左线**、宽 100（AS3 `MBarExpF.width = 100`）
	_断(is_equal_approx(幸条.position.x, 成条.position.x),
		"H-1 幸运条左缘该与成功率条对齐（`_xinYunBar.x = _ratioBar.x`），实测 %s vs %s"
		% [str(幸条.position.x), str(成条.position.x)])
	_断(is_equal_approx(成条.position.x, 幸题.position.x - 42.0),
		"H-1 成功率条该在标题左缘 -42（`_ratioBar.x = _ratioLabel.x - 42`），实测 条 %s、标题 %s"
		% [str(成条.position.x), str(幸题.position.x)])
	_断(is_equal_approx(幸条.size.x, 100.0),
		"H-1 幸运条宽该是 100（`MBarExpF.width = 100`），实测 %s" % str(幸条.size.x))
	_断(is_equal_approx(幸题.position.y, 成条.position.y + 成条.size.y + 10.0),
		"H-1 幸运标题该在成功率条底 +10（`_xinYunLabel.y = _ratioBar.y + _ratioBar.height + 10`），实测 标题y %s、条底 %s"
		% [str(幸题.position.y), str(成条.position.y + 成条.size.y)])
	_断(is_equal_approx(幸条.position.y, 幸题.position.y + 20.0),
		"H-1 幸运条该压在标题行下 20（MLabel 高 20），实测 条y %s、标题y %s"
		% [str(幸条.position.y), str(幸题.position.y)])
	# 玩家看见的那条：条底不许越过物品文字的**字顶**（字 12px 在 20px 行里居中）
	var 条底 := 幸条.position.y + 幸条.size.y
	var 字顶 := 物.position.y + (物.size.y - 12.0) / 2.0
	_断(条底 <= 字顶 + 0.5,
		"H-1 幸运条压到物品文字了：条底 %s 越过字顶 %s（用户 2026-10-29 报的就是这处）"
		% [str(条底), str(字顶)])
	await _关弹窗(弹窗)
	窗.set("_backend", null)


## ── H-2：特殊能力图标的悬停详情框（用户 2026-10-29 实机报修「鼠标放上去没有详情框」）──
## 原版 `ShouLiJianPanel.as:531-543` 给每枚 `attack.skills` 建 `SkillCellF`，`SkillCell`
## 自己挂 `MToolTipSkill`（`SkillCell.as:266-296`）；正文照 `SkillUtil.formatSkillInfo:89-92`
## 三行（绿冷却 / 白「描述资讯」/ 橙 desc），载荷冷却取的是 **0 号技能**（`:535`，
## `数据/技能.json` "0000000" 的 `cooldown = 1.12` ⇒ 「1.12秒」）。
## 本工程三枚图标"这一阶有几枚技能铺几枚"、id 随预览阶换 ⇒ id 必须**每次悬停现算**：
##   4 阶 = [9102 长箸之术]，5 阶 = [9100 黑暗行之术, 9103 斩镰之术]。
## 9102 / 9103 的 desc 只差「（技能等级1级）」/「（技能等级2级）」⇒ 正好分辨"第几枚、哪一阶"。
func _验技能提示(窗, 后端) -> void:
	var 假 := 假后端.new()
	窗.set("_backend", 假)
	await _推帧(后端, 窗, "1817:0:2:1:100:true:0")
	var 页 := _取页(窗)
	if 页 == null:
		_失败.append("H-2 取不到手里剑页 ⇒ 悬停提示这一腿没量到")
		return
	var 层 := 窗.get_node_or_null("遮罩") as Control
	if 层 == null:
		_失败.append("H-2 人物窗没有 `遮罩` 层（原版 stage 弹层等价物）⇒ 提示框没处挂")
		return
	var 图1 := 页.get_node_or_null("详情面板/技能图标1") as Control
	var 图2 := 页.get_node_or_null("详情面板/技能图标2") as Control
	var 图3 := 页.get_node_or_null("详情面板/技能图标3") as Control
	if 图1 == null or 图2 == null or 图3 == null:
		_失败.append("H-2 详情面板里缺技能图标1..3")
		return
	var 框1 := 层.get_node_or_null("手里剑技能提示_1") as Control
	var 框2 := 层.get_node_or_null("手里剑技能提示_2") as Control
	if 框1 == null or 框2 == null:
		_失败.append("H-2 遮罩层里没建出手里剑技能提示_1/2")
		return
	# tscn 里三枚都是 `mouse_filter = 2`（IGNORE）—— 不收鼠标就永远等不到悬停
	for 图 in [图1, 图2, 图3]:
		_断(图.mouse_filter == Control.MOUSE_FILTER_PASS,
			"H-2 技能图标必须改成 PASS 才收得到悬停（tscn 里烘的是 IGNORE），实测 %d" % (图 as Control).mouse_filter)
	# 2 阶没有特殊能力：三枚都藏着，悬停也不该亮空框
	_断(not 图1.visible, "H-2 2 阶没有特殊能力 ⇒ 技能图标1 该藏着")
	图1.mouse_entered.emit()
	_断(not 框1.visible, "H-2 这一阶没铺技能 ⇒ 悬停不该亮个空框")
	# 翻到 4 阶：只有 9102 一枚
	await _翻(页, 1)
	await _翻(页, 1)
	_断(图1.visible and not 图2.visible,
		"H-2 4 阶只有 1 枚特殊能力 ⇒ 只该亮技能图标1（实测 图1 %s / 图2 %s）"
		% [str(图1.visible), str(图2.visible)])
	图1.mouse_entered.emit()
	_断(框1.visible, "H-2 悬停 4 阶特殊能力图标该亮详情框")
	_核框(框1, "长箸之术", "（技能等级1级）", "H-2 4 阶第 1 枚（9102）")
	图1.mouse_exited.emit()
	_断(not 框1.visible, "H-2 鼠标移出该收起详情框")
	# 同一枚图标翻到 5 阶换技能 ⇒ 证明 id 是现算的，不是接线时烘死的
	await _翻(页, 1)
	_断(图1.visible and 图2.visible,
		"H-2 5 阶有 2 枚特殊能力 ⇒ 技能图标1/2 都该亮（实测 图1 %s / 图2 %s）"
		% [str(图1.visible), str(图2.visible)])
	图1.mouse_entered.emit()
	_断(框1.visible, "H-2 悬停 5 阶第 1 枚该亮详情框")
	_核框(框1, "黑暗行之术", "减缓其移动速度的效果", "H-2 5 阶第 1 枚（9100）")
	图1.mouse_exited.emit()
	图2.mouse_entered.emit()
	_断(框2.visible, "H-2 悬停 5 阶第 2 枚该亮详情框")
	_核框(框2, "斩镰之术", "（技能等级2级）", "H-2 5 阶第 2 枚（9103）")
	图2.mouse_exited.emit()
	_断(not 框2.visible, "H-2 鼠标移出 5 阶第 2 枚该收起详情框")
	# 6 阶那枚 9105（螺旋之术）本轮不单测：上面两阶已覆盖"枚数随阶变 + id 随阶变"
	窗.set("_backend", null)


## 提示框三段：标题（#ffff00 居中粗体）、绿冷却行（0 号技能 1.12 秒）、白「描述资讯」、橙 desc。
func _核框(框: Control, 题含: String, 尾含: String, 说明: String) -> void:
	var 题 := 框.get_node_or_null("标题") as RichTextLabel
	var 文 := 框.get_node_or_null("文") as RichTextLabel
	if 题 == null or 文 == null:
		_失败.append("%s：提示框缺「标题」/「文」" % 说明)
		return
	_断(String(题.text).contains(题含),
		"%s：标题该含「%s」，实测「%s」" % [说明, 题含, String(题.text)])
	_断(String(题.text).contains("ffff00"),
		"%s：标题色该是 #ffff00（`MToolTipSkill:56-58` 16776960），实测「%s」" % [说明, String(题.text)])
	_断(String(文.text).contains("[color=#00ff00]冷却时间：1.12秒"),
		"%s：正文该有绿冷却行「1.12秒」（0 号技能 cdBase，`:535`），实测「%s」" % [说明, String(文.text)])
	_断(String(文.text).contains("描述资讯"),
		"%s：正文该有「描述资讯」一行（`formatSkillInfo:89-92`），实测「%s」" % [说明, String(文.text)])
	_断(String(文.text).contains(尾含),
		"%s：正文该含「%s」，实测「%s」" % [说明, 尾含, String(文.text)])


## 点「开始突破瓶颈」被预检拦下：一句提示、**一发都不发**、窗不动。
func _预检拦(窗, 后端, 假, 通知, 帧: String, 期望句: String, 说明: String) -> void:
	await _推帧(后端, 窗, 帧)
	var 页 := _取页(窗)
	if 页 == null:
		_失败.append("%s：取不到手里剑页" % 说明)
		return
	await _开突破弹窗(页)
	var 弹窗 := _取弹窗("手里剑突破瓶颈弹窗", 页)
	if 弹窗 == null:
		_失败.append("%s：点「突破瓶颈」开不出弹窗" % 说明)
		return
	假.手里剑.clear()
	通知.clear()
	(弹窗.get_node_or_null("开始突破瓶颈") as Button).pressed.emit()
	await process_frame
	_断(假.手里剑.is_empty(),
		"%s：预检没过**一发都不该发**（原版每道都是 addNotice + return），实测 %s" % [说明, str(假.手里剑)])
	_断(通知 == [期望句], "%s：该只弹一句「%s」，实测 %s" % [说明, 期望句, str(通知)])
	await _关弹窗(弹窗)


## 点那枚「失败后自动继续」。`set_pressed_no_signal` 只管样式、故意不发信号，
## 而玩家真点一下是**两样都来**（翻态 + `toggled`）⇒ 两条都要，才与真点击等效。
func _按勾(弹窗: Control, 已勾: bool) -> void:
	if 弹窗 == null or not is_instance_valid(弹窗):
		_失败.append("取不到突破弹窗 ⇒ 勾选那一腿没量到")
		return
	var 勾 := (弹窗 as Control).get_node_or_null("失败后自动继续") as TextureButton
	if 勾 == null:
		_失败.append("突破弹窗里找不到「失败后自动继续」（场景烘的那枚 TextureButton）")
		return
	勾.set_pressed_no_signal(已勾)
	勾.emit_signal("toggled", 已勾)


## 给会话发足四道预检要查的家当：金币 / 精华 / 升阶道具（`_发资源` 备份、`_收资源` 放回）。
func _给满材料(会话) -> void:
	会话.inventory.clear()
	会话.inventory.append({"id": 16000032, "quantity": 40, "name": "手里剑木桩"})
	会话.player_stats["gold"] = 900000
	会话.player_stats["zq"] = 900


## G 腿的**发**：先按内存原样留底，再给足家当。
## ⚠️ 只动内存不放回 = 会话一落盘就把假数字写进真实玩档（§3.217 那起"三只假宠"同款血案）；
##   所以 G 腿的两个出口（正常走完 / 开不出弹窗早退）都挂了 `_收资源`。
func _发资源(会话) -> void:
	_存属性 = 会话.player_stats.duplicate(true)
	_存库存.clear()
	for 项 in 会话.inventory:
		_存库存.append(项)
	_给满材料(会话)


## G 腿的**收**：原样放回。
## ⚠️ `player_stats` / `inventory` 都得 `clear()` + 逐键/逐件**原地**填回去 ——
##   `inventory` 是 `Array[Dictionary]`，直接赋一个普通 Array 只报 `Invalid assignment`
##   **且不中断脚本**（§3.217 血案：错误刷屏、门却照样绿）。
func _收资源(会话) -> void:
	会话.player_stats.clear()
	会话.player_stats.merge(_存属性, true)
	会话.inventory.clear()
	for 项 in _存库存:
		会话.inventory.append(项)


## 屏幕层里某名的弹窗：`[亮着的枚数, 总枚数]`。
func _层同名(名: String) -> Array:
	var 亮 := 0
	var 总 := 0
	var 层 := root.get_node_or_null("屏幕弹窗层") as CanvasLayer
	if 层 == null:
		return [0, 0]
	for 子 in 层.get_children():
		var c := 子 as Control
		if c != null and String(c.name) == 名:
			总 += 1
			if c.visible:
				亮 += 1
	return [亮, 总]


# ── 辅助 ────────────────────────────────────────────────────────────

## 权威状态**从帧里来**（不直接写 `cultivation_states`）：这样 `1817` 的解析、会话落库、
## 页面换算三段都在门的射程里。
func _推帧(后端, 窗, 帧: String) -> void:
	后端.call("_handle_bridge_text", 帧)
	窗.call("_refresh_current")
	for _帧 in 4:
		await process_frame


## 点页面某枚钮 → 弹窗亮起 → 点弹窗里某枚钮 → 回验**发了什么包**与**有没有刷回执**。
func _核发包(页: Control, 页面钮: String, 弹窗名: String, 弹窗钮: String, 期望: Array,
		假, 通知, 说明: String) -> void:
	var 开 := 页.get_node_or_null(页面钮) as Button
	if 开 == null:
		_失败.append("%s：取不到「%s」" % [说明, 页面钮])
		return
	开.pressed.emit()
	await process_frame
	var 弹窗 := _取弹窗(弹窗名, 页)
	if 弹窗 == null or not 弹窗.visible:
		_失败.append("%s：点「%s」没打开「%s」" % [说明, 页面钮, 弹窗名])
		return
	var 确 := 弹窗.get_node_or_null(弹窗钮) as Button
	if 确 == null:
		_失败.append("%s：弹窗里找不到「%s」" % [说明, 弹窗钮])
		return
	假.手里剑.clear()
	通知.clear()
	确.pressed.emit()
	await process_frame
	_断(假.手里剑 == [期望], "%s：该发**一发** 1817 动作 %s，实测 %s" % [说明, str(期望), str(假.手里剑)])
	_断(通知.is_empty(), "%s：发成功不该刷「已发送，等待服务器确认」这类回执（用户报修 2.1），实测 %s"
		% [说明, str(通知)])
	await _关弹窗(弹窗)


func _开突破弹窗(页: Control) -> void:
	if 页 == null:
		return
	var 钮 := 页.get_node_or_null("详情面板/突破瓶颈") as Button
	if 钮 == null:
		_失败.append("取不到「详情面板/突破瓶颈」")
		return
	钮.pressed.emit()
	await process_frame


func _关弹窗(弹窗: Control) -> void:
	if 弹窗 == null:
		return
	var 关 := 弹窗.get_node_or_null("关闭按钮") as Button
	if 关 == null:
		弹窗.visible = false
		return
	关.pressed.emit()
	await process_frame


func _翻(页: Control, 增量: int) -> void:
	var 钮 := 页.get_node_or_null("详情面板/下一页" if 增量 > 0 else "详情面板/上一页") as TextureButton
	if 钮 == null:
		_失败.append("取不到翻页箭头 ⇒ 预览那一腿没量到")
		return
	钮.pressed.emit()
	await process_frame


## 弹窗首次打开会被页面 `reparent` 到「屏幕弹窗层」；页面每次重绘换新实例，上一轮搬出去的
## 那枚由 `手里剑页._exit_tree` 收掉（见 D 腿）⇒ 层里同名**最多一枚**。先按页面找（还没搬走的
## 就是它），搬走了的再到层里按名找。
func _取弹窗(名: String, 页: Control) -> Control:
	if 页 != null:
		var 新 := 页.get_node_or_null(名) as Control
		if 新 != null:
			return 新
	var 层 := root.get_node_or_null("屏幕弹窗层") as CanvasLayer
	return null if 层 == null else 层.get_node_or_null(名) as Control


func _扩展面板(窗) -> Panel:
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	var 页面 := 内容.find_child("原版人物窗口内容", true, false) as Control
	return 页面.get_node_or_null("人物扩展页") as Panel if 页面 != null else null


func _取页(窗) -> Control:
	var 面板 := _扩展面板(窗)
	return null if 面板 == null else 面板.get_node_or_null("手里剑内容") as Control


## 购买窗平时在宿主 `遮罩`，屏幕级弹窗亮着时会被抬到根下「购买窗舞台层」（见
## `功能窗口._抬购买窗`）⇒ 两处都找。
func _购买窗节点(窗) -> Control:
	var 遮 := 窗.get("_overlay") as Control
	var 找 := 遮.get_node_or_null("商城购买窗") as Control if 遮 != null else null
	if 找 != null:
		return 找
	var 层 := root.get_node_or_null("购买窗舞台层")
	return null if 层 == null else 层.get_node_or_null("商城购买窗") as Control


func _买窗遮罩节点(窗) -> Control:
	var 遮 := 窗.get("_overlay") as Control
	var 找 := 遮.get_node_or_null("购买窗遮罩") as Control if 遮 != null else null
	if 找 != null:
		return 找
	var 层 := root.get_node_or_null("购买窗舞台层")
	return null if 层 == null else 层.get_node_or_null("购买窗遮罩") as Control


## 控件实际落在哪个 CanvasLayer 上 —— 画序与命中都按这个 `layer` 数比（见 `窗口管理.重排层级`）。
func _控件层号(控: Control) -> int:
	var 走: Node = 控
	while 走 != null:
		var 层 := 走 as CanvasLayer
		if 层 != null:
			return 层.layer
		走 = 走.get_parent()
	return -1


## 「值」那类标签，以及按钮的文字 —— 都要按**玩家看到的字符串**来钉。
func _核字(节点: Node, 路径: String, 期望: String, 说明: String) -> void:
	_受检 += 1
	var 件: Node = null if 节点 == null else 节点.get_node_or_null(路径)
	if 件 == null:
		_失败.append("%s：取不到「%s」" % [说明, 路径])
		return
	var 实测 := String(件.get("text"))
	if 实测 != 期望:
		_失败.append("%s：「%s」期望「%s」，实测「%s」" % [说明, 路径, 期望, 实测])


func _断(ok: bool, 话: String) -> void:
	_受检 += 1
	if not ok:
		_失败.append(话)


func _停(原因: String) -> void:
	push_error("手里剑修炼页回归测试：中断 - %s" % 原因)
	quit(1)


func _收尾() -> void:
	if _失败.is_empty():
		print("手里剑修炼页回归测试：通过（%d 条断言 / 等级累计换算 · 提升突破零回执 · 购买升阶物品走商城统一出口 · 幸运值回帧就地刷新 · 四道突破预检与「失败后自动继续」900ms 自跳 · 突破弹窗下半截版式 · 特殊能力悬停详情框 · 购买窗压在屏幕级弹窗之上）"
			% _受检)
		quit(0)
		return
	for 项 in _失败:
		printerr("手里剑修炼页回归测试：" + 项)
	quit(1)


## 假后端：只收不连，用来看**请求里到底带了什么**。
class 假后端:
	extends Node
	var in_game := true
	var 手里剑: Array = []
	var 商城: Array = []

	func request_shuriken(动作: int, 参数 := false) -> bool:
		手里剑.append([动作, 参数])
		return true

	func request_cash_item_info(物品id: int, 商店类型 := 0) -> bool:
		商城.append(物品id)
		return true
