extends SceneTree

## 自选礼包选择窗回归门（2026-10-18，巡检 #21）。
##
## 病根：`libao_select` 这 20 件礼包**没有选择窗** —— 双击/「使用」直接发一条不带 selection
## 的 USE_ITEM，服务端 `_use_authored_gift_item:49679-49682` 回一句
## 「请先在自选礼包中选择一件奖励。」并 `return 0`（**礼包一件不扣**）⇒ 点多少次都白费。
## 原版的链是 `ItemWindow2.as:990-1017`（`isItemLiBao && preview==1` 里 `libao_select` 那一支）
## → `ChoiceLibaoWindow` → `__onOkBtnClick:283-293` 才发 `requestUseItem(position, id, {job,index})`。
## 本门钉的就是补上来的这扇窗。
##
## 盯九件（每件都能追到 AS3/服务端行号，没有一条是自造）：
##   ① **下标契约**：`游戏数据.礼包候选` 与门内**独立复刻**的服务端
##      `_authored_gift_reward_rows:49562-49611` 逐字段相等（20 件 × 每个职业组）。
##      "两处调同一个函数"撞不出错，所以这里各算一遍；导出的数组序 == AVM2 数字键枚举序
##      这一条前提由 ①a 单独钉（每组 slot 必须正好 0..n-1 升序）。
##   ② 服务端那两个**跳过**（`item_id<=0` / `count<=0`）和**组过滤**（只取 "0" + 本职业组）：
##      真数据 0 条脏行 ⇒ ① 撞不出来，这里注入一件合成礼包专门钉它。
##   ③ 版式：`createUI:125-187` / `draw:109-114` / `createItemCell:294-322` /
##      `setSelectedGrid:64-74` 那套坐标（窗宽 240、格 40×40 @ 容器局部 `4+42·列/行`、
##      环 46×46 摆在格 −3、钮 y = 面板高 + 36、数量 (0,21) 右界 38）。
##   ④ **尾巴上的空格**：格阵枚数 = `ceil(所有组总行数/5)×5`（`getCellCountTotal:324-340`
##      不看职业、不滤脏行），只把「通用组 + 本职业组」填进**前** n 枚 ⇒ 11020003 摆 25 枚、
##      填 24 枚；空格**没接点击**（AS3 只给前 n 枚 `addEventListener(MSPRITE_CLICK)`）。
##   ⑤ 拦截：`_use_item(格位)` 对自选礼包**只开窗、一个包都不发**（旧写法是直接发）；
##      「全部使用」(`全部=true`) 同样被截 —— 原版 `MENU_USEALL:767-768` 也走 `useItem()`
##      那一支，而选择窗发的那条 `requestUseItem` 里**没有 useAll** ⇒ 一摞 2 件也只吃 1 件。
##   ⑥ 点第 2 格 ⇒ 确定 ⇒ `{job, index}` 交给会话，**离线只发选中的那一行**。
##   ⑦ 满了 ⇒ 原版闸 `1 + commonItems.length <= commonSlots` 回「背包空间不足！」、
##      **不发、窗不关**（`__onOkBtnClick` 的关窗写在成功分支**里面**）。
##   ⑧ `libao_rand` **不开窗**（随机族在原版没有选择窗）。
##   ⑨ 资质框门槛 `setData:207-216` = `hasOwnProperty("aptitude") && isItemAKunChong`，
##      而 `isItemAKunChong:285-288` 判的是 **id 前三位 "131"** ⇒ 昆虫（`1310001`，四位码 131）
##      与勾玉（`13100000`，前三位 131）**都算**；拿 `装备部位.位置()==昆虫包` 判会漏掉勾玉整族。
##
## ⚠️ 三条口径：
##   · 本门会 `_save_local_state()` 落盘 user:// ⇒ 开场快照、收尾还原并再落盘（§3.76.1）；
##     新门先连跑两遍，第二遍红 = 第一遍污染了存档。
##   · 窗挂在 `功能窗口._overlay` 上 ⇒ 开场钉 `root.size`（无头视口 64×64，居中算式读它）。
##   · ② 注入的合成键**当场 erase**（`礼包格阵格数` 数的是整表，留着会污染后面的账）。
##
## 运行：Godot --headless --path . --script res://测试/自选礼包窗回归测试.gd

const 窗场景 := "res://场景/界面/功能窗口.tscn"
const 奖励表路径 := "res://数据/礼包奖励.json"
const 会话路径 := "/root/GameSession"

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 选择窗脚本 := preload("res://脚本/界面/窗口/自选礼包窗.gd")

var _失败: Array[String] = []
var _受检 := 0
var _快照: Dictionary = {}
var _秒 := 0.0
## 内存态还原后再 `_save_local_state()` 的**字节并不等于磁盘原文件** ⇒ 再加一层文件级快照。
const 门存档快照 := preload("res://测试/门存档快照.gd")
var _文件前 := {}


func _initialize() -> void:
	_文件前 = 门存档快照.全快照()
	call_deferred("_run")


func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 90.0:
		_收尾()
		printerr("自选礼包窗回归测试：看门狗超时（90s）—— 中途崩了没走到收尾，已强制还原快照")
		quit(1)
		return true
	return false


func _查(过: bool, 文: String) -> void:
	_受检 += 1
	if not 过:
		_失败.append(文)
		print("!! " + 文)


func _件(物品id: String, 件数: int, 补丁 := {}) -> Dictionary:
	var 条 := {"id": 物品id, "name": 物品id, "category": "消耗品",
			"quantity": 件数, "price": 20,
			# 种子带 icon：格子渲染只在 `ResourceLoader.exists(icon)` 时摆图标，
			# 不带 icon 的脏种子会把别的门饿着（§3.76 同一条）。
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"}
	条.merge(补丁, true)
	return 条


## ── 门内**独立**复刻（不叫 `游戏数据` 的任何函数，直接读原始 JSON）──────────────
## 真值：`fake_flash_server.py:49562-49611`（拼行 + 跳过）与 `:49661-49686`（校验选择）。
func _原始表() -> Dictionary:
	var f := FileAccess.open(奖励表路径, FileAccess.READ)
	if f == null:
		return {}
	var 得: Variant = JSON.parse_string(f.get_as_text())
	if 得 is Dictionary:
		return 得 as Dictionary
	return {}


func _组(原始: Dictionary, 号: String) -> Dictionary:
	var 包: Dictionary = 原始.get(号, {}) as Dictionary
	if 包.is_empty() and 号.is_valid_int():
		包 = 原始.get(str(int(号)), {}) as Dictionary
	return 包.get("rewards_by_job", {}) as Dictionary


## 「通用组 + 本职业组」拼出来的行（服务端那条序）。项 = {job,index,item_id,count}。
func _服务端序(原始: Dictionary, 号: String, 职业: int) -> Array:
	var 组: Dictionary = _组(原始, 号)
	var 职业组 := (maxi(0, 职业) / 100) * 100
	var 组名表: Array = ["0"] if 职业组 == 0 else ["0", str(职业组)]
	var 出: Array = []
	for 组名 in 组名表:
		var 行: Array = 组.get(String(组名), []) as Array
		for 条v in 行:
			var 条: Dictionary = 条v as Dictionary
			var 物品号 := int(String(条.get("item_id", "0")))
			var 件 := int(条.get("count", 1))
			if 物品号 <= 0 or 件 <= 0:
				continue
			出.append({"job": int(String(组名)), "index": 出.size(),
					"item_id": String(条.get("item_id", "")), "count": 件})
	return 出


## `getCellCountTotal:324-340`：数**所有组**的行、**不滤脏行**，再 `ceil(总/5)×5`。
func _格阵格数(原始: Dictionary, 号: String) -> int:
	var 组: Dictionary = _组(原始, 号)
	var 总 := 0
	for 组名 in 组:
		总 += (组[组名] as Array).size()
	return int(ceilf(总 / 5.0)) * 5


## 窗上那几枚格子（`格阵` 容器里的 Button；选中环不是 Button）。
func _格们(窗: Control) -> Array:
	var 出: Array = []
	for 子 in (窗.get_node("格阵") as Control).get_children():
		if 子 is Button:
			出.append(子)
	return 出


func _数量字(格: Button) -> String:
	return (格.get_node("数量") as Label).text


func _在包(会话, 物品号: int) -> bool:
	for 条 in (会话.inventory as Array):
		var 号 := String((条 as Dictionary).get("id", ""))
		if 号.is_valid_int() and int(号) == 物品号:
			return true
	return false


## 遮罩上那枚选择窗。按**前缀**找：叠了两枚时 Godot 会把后一枚改名 `@Control@N`。
func _取窗(遮罩层: Control) -> Control:
	for 子 in 遮罩层.get_children():
		if String(子.name).begins_with("自选礼包窗"):
			return 子 as Control
	return null


func _run() -> void:
	root.size = Vector2i(960, 560)
	var 会话 = root.get_node(会话路径)
	_快照 = {
		"player_stats": (会话.player_stats as Dictionary).duplicate(true),
		"inventory": (会话.inventory as Array).duplicate(true),
		"storage": (会话.storage as Array).duplicate(true),
		"equipped_items": (会话.equipped_items as Dictionary).duplicate(true),
	}
	var 原始 := _原始表()
	if 原始.is_empty():
		_查(false, "读不到 %s —— 整门空判" % 奖励表路径)
		_收尾()
		quit(1)
		return

	# 20 件 `libao_select`（判据取物品表，与窗上那一条同源）
	var 物品表 := 游戏数据.取表("物品")
	var 礼包们: Array = []
	for 号 in 物品表:
		if String((物品表[号] as Dictionary).get("use_type", "")).to_lower() == "libao_select":
			礼包们.append(String(号))
	礼包们.sort()
	_查(not 礼包们.is_empty(), "物品表里一件 libao_select 都没有（导出坏了？）")
	_查(礼包们.size() == 20, "libao_select 是 %d 件、不是 20 件 —— 本门按 20 件算的账要一起改"
			% 礼包们.size())

	# —— ①a 导出的数组序 == AVM2 数字键枚举序：每组 slot 必须正好 0..n-1 升序 ——
	for 号 in 礼包们:
		var 组: Dictionary = _组(原始, 号)
		for 组名 in 组:
			var 行: Array = 组[组名] as Array
			for i in 行.size():
				var 序 := int((行[i] as Dictionary).get("slot", -1))
				_查(序 == i, ("%s 组%s 第 %d 条的 slot 是 %d —— 导出没排好 ⇒ 服务端数字键序 != 我们的"
						+ "数组序，① 的下标契约就断了") % [号, 组名, i, 序])

	# —— ①b 候选 == 服务端序 ——
	var 撞过 := 0
	for 号 in 礼包们:
		var 职业集: Array = [0, 700]
		for 组名 in _组(原始, 号):
			职业集.append(int(String(组名)) + 1)
		for 职业 in 职业集:
			var 实: Array = 游戏数据.礼包候选(号, int(职业))
			var 期: Array = _服务端序(原始, 号, int(职业))
			撞过 += 1
			_查(实.size() == 期.size(), "%s 职业%d：候选 %d 条 ≠ 服务端 %d 条"
					% [号, 职业, 实.size(), 期.size()])
			for i in mini(实.size(), 期.size()):
				var a: Dictionary = 实[i] as Dictionary
				var b: Dictionary = 期[i] as Dictionary
				_查(int(a.get("job", -9)) == int(b["job"])
						and int(a.get("index", -9)) == int(b["index"])
						and String(a.get("item_id", "")) == String(b["item_id"])
						and int(a.get("count", -9)) == int(b["count"]),
						"%s 职业%d 第 %d 条对不上：客户端 %s / 服务端 %s" % [号, 职业, i, str(a), str(b)])
			_查(游戏数据.礼包格阵格数(号, 5) == _格阵格数(原始, 号),
					"%s 格阵格数 %d ≠ ceil(所有组总行数/5)×5 = %d（`getCellCountTotal:324-340`）"
					% [号, 游戏数据.礼包格阵格数(号, 5), _格阵格数(原始, 号)])
	_查(撞过 >= 100, "①只对撞了 %d 组（该是 20 件 × 至少 6 个职业），太少" % 撞过)

	# —— ② 脏行跳过 + 组过滤（真数据 0 条脏行 ⇒ 必须注入合成件才撞得出来）——
	var 表 := 游戏数据.取表("礼包奖励")
	var 合成人 := "99112233"
	表[合成人] = {"rewards_by_job": {
		"0": [
			{"slot": 0, "item_id": "6000059", "count": 1},
			{"slot": 1, "item_id": "0", "count": 5},
			{"slot": 2, "item_id": "6000060", "count": 0},
			{"slot": 3, "item_id": "abc", "count": 2},
			{"slot": 4, "item_id": "6000061", "count": 3}],
		"100": [{"slot": 0, "item_id": "6000062", "count": 4}],
		"300": [{"slot": 0, "item_id": "6000063", "count": 9}]}}
	var 候0: Array = 游戏数据.礼包候选(合成人, 0)
	_查(候0.size() == 2 and String((候0[0] as Dictionary).get("item_id", "")) == "6000059"
			and String((候0[1] as Dictionary).get("item_id", "")) == "6000061"
			and int((候0[1] as Dictionary).get("index", -1)) == 1,
			"②脏行没被跳过（id<=0 / count<=0 / 非数字都该跳，服务端 :49596）：实测 %s" % str(候0))
	var 候101: Array = 游戏数据.礼包候选(合成人, 101)
	_查(候101.size() == 3 and int((候101[2] as Dictionary).get("job", -1)) == 100
			and String((候101[2] as Dictionary).get("item_id", "")) == "6000062"
			and int((候101[2] as Dictionary).get("index", -1)) == 2,
			"②组 100 没拼到通用组后面、或下标没接着数（实测 %s）" % str(候101))
	var 候301: Array = 游戏数据.礼包候选(合成人, 301)
	_查(候301.size() == 3 and String((候301[2] as Dictionary).get("item_id", "")) == "6000063",
			"②职业 301 取到的不是组 300 那一行（实测 %s）" % str(候301))
	_查(游戏数据.礼包格阵格数(合成人, 5) == 10,
			"②注入 9 行（含 2 条脏行）后格阵该按**未过滤**的行数摆成 10 枚，实测 %d"
			% 游戏数据.礼包格阵格数(合成人, 5))
	表.erase(合成人)
	_查(not (游戏数据.取表("礼包奖励") as Dictionary).has(合成人), "②的合成礼包没清干净")
	_查(游戏数据.礼包候选("11020014", 0).size() == 5,
			"轮回技能可选礼包（11020014）的候选不是 5 条 —— 下面 ③⑥ 的账要一起改")

	# —— ⑨ 资质框门槛：前三位 131（昆虫与勾玉两族都算），不是"位置 == 昆虫包" ——
	_查(选择窗脚本.是131族("1310001"), "⑨昆虫 `1310001` 判成不是 131 族（紫框 + 流光就没了）")
	_查(选择窗脚本.是131族("01310001"), "⑨补零形态 `01310001` 也该算 131 族（背包格上是这形态）")
	_查(选择窗脚本.是131族("13100000"), "⑨勾玉 `13100000` 前三位是 131 ⇒ 原版算 131 族")
	_查(not 选择窗脚本.是131族("11020014") and not 选择窗脚本.是131族("6000059"),
			"⑨把普通礼包 / 技能书也判成 131 族了")

	# —— ③ 版式（真窗开在 `功能窗口` 的遮罩层上）——
	会话.player_stats["job"] = 101
	会话.inventory = 会话.落位带洞([_件("11020014", 2, {"slot_index": 1})])
	var 场: Node = (load(窗场景) as PackedScene).instantiate()
	root.add_child(场)
	await process_frame
	await process_frame
	var 遮罩层 := 场.get("_overlay") as Control
	if 遮罩层 == null:
		_查(false, "功能窗口没有 _overlay，开窗这条路没法测")
		_收尾()
		quit(1)
		return
	场.call("_use_item", 1)
	await process_frame
	var 窗 := _取窗(遮罩层)
	_查(窗 != null and 窗.visible, "「使用」自选礼包没弹出选择窗（原版开 `ChoiceLibaoWindow`）")
	if 窗 == null:
		_收尾()
		quit(1)
		return
	# 11020014：所有组共 5 行 ⇒ 阵 5 枚 / 1 行；面板高 = 42·1−2+42 = 82；窗高 = 82+30+38 = 150
	_查(窗.size == Vector2(240, 150), "窗尺寸 %s ≠ 240×150" % str(窗.size))
	var 阵 := 窗.get_node("格阵") as Control
	_查(阵.position == Vector2(12, 60), "格阵容器不在 (12,60)（`cellContainer.x/y`）")
	var 格们 := _格们(窗)
	_查(格们.size() == 5, "格子枚数 %d ≠ 5（`ceil(5/5)×5`）" % 格们.size())
	for i in 格们.size():
		var 格 := 格们[i] as Button
		_查(格.position == Vector2(4 + 42 * (i % 5), 4 + 42 * int(i / 5)),
				"第 %d 枚格在 %s，原版是容器局部 (4+42·列, 4+42·行)" % [i, str(格.position)])
		_查(格.custom_minimum_size == Vector2(40, 40), "第 %d 枚格不是 40×40（`MGrid_background`）" % i)
	var 环 := 阵.get_node("选中环") as TextureRect
	_查(环.texture != null and 环.texture.get_width() == 46 and 环.texture.get_height() == 46,
			"选中环不是 46×46（`SkillCellSelectedGridF`）")
	# ⚠ 光看贴图尺寸不够：`EXPAND_IGNORE_SIZE` 自己不撑节点，节点 size 留在 0×0 时
	#   环根本画不出来（用户 2026-11-07 报「选中没有框」）。
	_查(环.size == Vector2(46, 46), "选中环节点不是 46×46（实测 %s，0×0 就看不见）" % str(环.size))
	_查(环.position == (格们[0] as Button).position + Vector2(-3, -3),
			"选中环没摆在选中格的 −3 处（`setSelectedGrid:70-72`），实测 %s" % str(环.position))
	_查(环.get_index() == 阵.get_child_count() - 1, "选中环要 add 在格子**之后**才画得上去")
	# ⚠ 原版整块选中的贴图自带**半透明深灰底 + 黑色内棱 + 右下角 0**，整张盖上去会把道具
	#   图标压灰、还漏一个 0（用户 2026-11-07 报「只要当前这个橙色外框」）。派生贴图必须：
	#   中心 (23,23) 与那个 0 的位置 (38,35) 透明，橙边 (1,23) 还在。
	var 环图 := 环.texture.get_image()
	_查(环图 != null and 环图.get_pixel(23, 23).a == 0.0,
			"选中环中心没清透明，会压灰道具图标")
	_查(环图 != null and 环图.get_pixel(38, 35).a == 0.0,
			"选中环右下角那个 0 没清掉（原版贴图 (38,35) 是白字）")
	_查(环图 != null and 环图.get_pixel(1, 23).a > 0.9 and 环图.get_pixel(1, 23).b < 0.4,
			"选中环的橙边不见了（左缘 (1,23)）")
	_查((格们[0] as Button).pressed.get_connections().size() >= 1, "填了的格没接点击")
	_查((窗.get_node("标题") as Label).text == "可选礼包", "标题 ≠ `CHOICE_LIBAO_TITLE`（:2456）")
	var 提 := 窗.get_node("提示") as Label
	_查(提.text == "请点击选择一个礼物图示", "提示文案 ≠ `CHOICE_LIBAO_ICON`（:851）")
	_查(提.position == Vector2(6, 33) and 提.size == Vector2(228, 18),
			"提示行版式不是 (6,33) 228×18（`tipText.x/y/width/height`）")
	var 线 := 窗.get_node("分隔线") as TextureRect
	_查(线.position == Vector2(11, 56) and 线.size == Vector2(218, 2),
			"分隔线不是 (11,56) 218×2（`line.width = background2.width − 10`）")
	var 黄 := 窗.get_node("黄底") as Panel
	_查(黄.position == Vector2(6, 30) and 黄.size == Vector2(228, 82),
			"黄底面板不是 (6,30) 228×82（`background2`：x=6、y=30、宽=240−12、高=格阵高+42）")
	_查((窗.get_node("关闭") as Button).position == Vector2(211, 4),
			"关闭钮不在 (211,4)（`closeBtn.x = 宽 − width − 4`、`y = 4`）")
	var 确 := 窗.get_node("确定") as Button
	var 取钮 := 窗.get_node("取消") as Button
	_查(确.position.y == 118.0 and 取钮.position.y == 118.0,
			"两枚钮的 y 该是面板高 + 36 = 118，实测 %.1f/%.1f" % [确.position.y, 取钮.position.y])
	_查(确.position.x == 30.0, "确定不在 x=30（`okBtn.x = 30`）")
	_查(absf(取钮.position.x + 取钮.size.x - 210.0) < 0.6,
			"取消右边缘不在 210（`cancelBtn.x = 240 − 宽 − 30`），实测 x=%.1f 宽=%.1f"
			% [取钮.position.x, 取钮.size.x])
	# `MButton3.measure():378-390`：`isScale9Grid` 且没设宽 ⇒ 宽 = 文字宽 + 6
	var 字体 := 确.get_theme_font("font", "Button") as Font
	if 字体 != null:
		var 应宽 := ceilf(字体.get_string_size("确定", HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				确.get_theme_font_size("font_size", "Button")).x) + 6.0
		_查(absf(确.size.x - 应宽) < 0.6,
				"确定钮宽不是「文字宽 + 6」（MButton3 的 scale9 量宽支），实测 %.1f" % 确.size.x)
	else:
		_查(false, "取不到 Button 主题字体，钮宽那条没法算")
	# 数量：`PrizeItemCell:34-38` ⇒ (0,21)、宽 = 格宽−2 = 38、右对齐、件>1 才显
	var 量 := (格们[0] as Button).get_node("数量") as Label
	_查(量.offset_left == 0.0 and 量.offset_top == 21.0 and 量.offset_right == 38.0,
			"数量标签不是 (0,21) 右界 38（背包格是 1/24，**别照抄**）")
	_查(量.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "数量没右对齐（`align=\"right\"`）")
	var 候5: Array = 游戏数据.礼包候选("11020014", 101)
	for i in 格们.size():
		var 件数 := int((候5[i] as Dictionary).get("count", 1))
		var 字面 := str(件数) if 件数 > 1 else ""
		_查(_数量字(格们[i] as Button) == 字面,
				"第 %d 枚数量是「%s」，原版该是「%s」（件数 1 不显数字）"
				% [i, _数量字(格们[i] as Button), 字面])
		_查((格们[i] as Button).icon != null, "第 %d 枚没摆上物品图标（`setPic` 的 `PicTool.getItemPic`）" % i)

	# —— ④ 尾巴空格：11020003 所有组共 24 行 ⇒ 阵 25 枚、填 24 枚 ——
	会话.inventory = 会话.落位带洞([_件("11020003", 1, {"slot_index": 1})])
	场.call("_use_item", 1)
	await process_frame
	窗 = _取窗(遮罩层)
	var 格2 := _格们(窗)
	_查(格2.size() == 25, "11020003 该摆 25 枚（ceil(24/5)×5），实测 %d" % 格2.size())
	# 5 行 ⇒ 面板高 = 42·5−2+42 = 250；窗高 = 250+30+38 = 318
	_查(窗.size == Vector2(240, 318), "5 行的窗高 %s ≠ 240×318" % str(窗.size))
	_查((格2[24] as Button).icon == null, "第 25 枚尾巴空格不该有图")
	_查((格2[24] as Button).pressed.get_connections().is_empty(),
			"第 25 枚空格接了点击 —— 原版只给前 n 枚 addEventListener，空格点了不选")
	_查(_数量字(格2[0] as Button) == "81",
			"勾玉 81 颗那枚数量是「%s」，原版件>1 就显件数" % _数量字(格2[0] as Button))

	# —— ⑤ 拦截：开窗那一刻**一件都不吃**（回到 11020014、一摞 2 件；连「全部使用」也一样）——
	会话.inventory = 会话.落位带洞([_件("11020014", 2, {"slot_index": 1})])
	场.call("_use_item", 1, true)
	await process_frame
	窗 = _取窗(遮罩层)
	_查(窗 != null and 窗.visible,
			"「全部使用」(全部=true) 没弹选择窗（原版 MENU_USEALL 同样走 useItem 那一支）")
	var 挡 := 遮罩层.get_node_or_null("购买窗遮罩") as ColorRect
	_查(挡 != null and 挡.visible, "缺一整舞台遮罩（原版 `centerWindow(..., true)`）")
	if 挡 != null and 窗 != null:
		_查(挡.get_index() < 窗.get_index(), "遮罩该压在选择窗**下面**")
	_查(String(会话.格位物品(1).get("id", "")) == "11020014"
			and int(会话.格位物品(1).get("quantity", 0)) == 2,
			"开窗就把一摞 2 件吃了（原版这段只弹窗，`requestUseItem` 里没有 useAll）")

	# —— ⑥ 点第 2 格 ⇒ 确定 ⇒ `{job:0,index:1}` ⇒ 离线只发选中那一行 ——
	var 格3 := _格们(窗)
	(格3[1] as Button).pressed.emit()
	await process_frame
	var 环3 := (窗.get_node("格阵") as Control).get_node("选中环") as TextureRect
	_查(环3.position == (格3[1] as Button).position + Vector2(-3, -3),
			"点第 2 格选中环没跟着走（`onItemClick` → `setSelectedGrid`），实测 %s" % str(环3.position))
	(窗.get_node("确定") as Button).pressed.emit()
	await process_frame
	var 剩: Dictionary = 会话.格位物品(1)
	_查(剩.is_empty() or int(剩.get("quantity", 0)) == 1,
			"确定之后礼包没扣 1 件（实测 %s）" % str(剩))
	_查(_在包(会话, 6000060), "选中的第 2 件（6000060）没进包")
	_查(not _在包(会话, 6000059), "没选的 6000059 也进包了 —— 离线必须**只发选中那一行**")
	_查(not _在包(会话, 6000061) and not _在包(会话, 6000062) and not _在包(会话, 6000063),
			"其余候选也发了（#20-A 那笔「凭空刷物品」的账返祖）")
	_查(not 窗.visible, "确定成交后窗没关（原版关窗写在成功分支里）")

	# —— ⑦ 满了 ⇒ 「背包空间不足！」、不发、窗不关 ——
	会话.player_stats["common_slots"] = 1
	会话.inventory = 会话.落位带洞([_件("11020014", 1, {"slot_index": 1})])
	场.call("_use_item", 1)
	await process_frame
	窗 = _取窗(遮罩层)
	_查(窗 != null and 窗.visible,
			"满包时没开窗（原版照样开窗，满了是在「确定」那一刻才判）")
	if 窗 != null:
		(窗.get_node("确定") as Button).pressed.emit()
		await process_frame
		_查(窗.visible, "满了还把窗关了 —— 原版 `__onOkBtnClick` 的关窗在成功分支**里面**")
		_查(String(会话.格位物品(1).get("id", "")) == "11020014"
				and int(会话.格位物品(1).get("quantity", 0)) == 1,
				"满了还吃掉了礼包（原版一条都不发）")
		var 状态 := 场.get("_status") as Label
		_查(状态 != null and 状态.text.contains("背包空间不足！"),
				"满了没回原话「背包空间不足！」（`CN.ITEM_GRID_NOT_SPACE` :1530），状态行实测 %s"
				% (状态.text if 状态 != null else "<无 _status>"))
		(窗.get_node("取消") as Button).pressed.emit()
		await process_frame
		_查(not 窗.visible, "取消后窗还开着")
	if 挡 != null:
		_查(not 挡.visible, "关窗后整舞台遮罩没撤")

	# —— ⑧ `libao_rand` 不开窗（原版随机族没有选择窗那一支）——
	会话.player_stats["common_slots"] = 90
	会话.inventory = 会话.落位带洞([_件("11010001", 1, {"slot_index": 1})])
	场.call("_use_item", 1)
	await process_frame
	var 又开 := _取窗(遮罩层)
	_查(又开 == null or not 又开.visible,
			"随机礼包（11010001 libao_rand）也弹了选择窗 —— 原版只对 libao_select 开")

	场.queue_free()
	await process_frame
	_收尾()
	if _失败.is_empty():
		print(("自选礼包窗回归测试：通过（下标契约对撞 %d 组 / 脏行跳过 / 240×150 与 25 枚格阵 / "
				+ "拦截只开窗不吃件 / 离线只发选中那一行 / 满了不发也不关窗 / libao_rand 不开窗）")
				% [撞过])
		quit(0)
	else:
		print("自选礼包窗回归测试：失败 %d 项（共 %d 项）" % [_失败.size(), _受检])
		quit(1)


func _收尾() -> void:
	if not _快照.is_empty():
		var 会话 = root.get_node(会话路径)
		会话.player_stats = _快照["player_stats"]
		# ⚠️ `inventory`/`storage` 都是 `Array[Dictionary]` ⇒ 直接赋普通 Array 会
		#    Invalid assignment 报错但不中断（§3.196 同型坑），走 `assign`。
		(会话.inventory as Array).assign(_快照["inventory"] as Array)
		(会话.storage as Array).assign(_快照["storage"] as Array)
		会话.equipped_items = _快照["equipped_items"]
		会话.call("_save_local_state")
	# 文件级还原放在最后：`_save_local_state()` 重写的字节与原档不必一致。
	门存档快照.全还原(_文件前)
