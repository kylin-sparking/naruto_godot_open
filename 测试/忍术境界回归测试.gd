extends SceneTree

## 忍术页「忍术境界」面板：**展开态必须扛得住页面重建**。
##
## 为什么单拎一条（2026-09-26 用户报"点开又自动返回忍术面板"）：
## `功能窗口._refresh_current()` 会把整个页面**重建**，而它有十来个触发信号
## （`skills_changed` / `player_stats_changed` / `activity_changed` …），
## 联机时服务端随便推一条就会跑一次。`_渲染境界()` 原本每次都以"收起"起始，
## 于是面板刚滑进去就被弹回来 —— 页签 `_skill_tab`、选中技能 `_selected_skill_id`
## 这些**存在窗口上的**状态都能活过重建，唯独境界面板的展开态没存。
##
## 钉三件事：
##  ① 点开 → 面板滑入（x 趋近 0、详情区藏起来）
##  ② **重建页面后仍然展开**（这条是本次的 bug）
##  ③ 再点一次 → 收起；**重建后仍然收起**
##
## 运行：Godot --headless --path . --script res://测试/忍术境界回归测试.gd

const 面板键 := &"skill_jingjie_panel"
const 详情键 := &"skill_detail_pane"
# ⑤ 学技能会 `_save_local_state()`（`learn_skill_from_book` 里），按字节快照/还原，跑批器才不会点名写档。
const 门存档快照 := preload("res://测试/门存档快照.gd")

var _失败: Array[String] = []
var 断言 := 0
var _窗 = null
var _底栏: Control = null
var _存档前: Dictionary = {}


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	_存档前 = 门存档快照.全快照()
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	await _等帧(6)

	var 会话: Node = root.get_node_or_null("/root/GameSession")
	if 会话 == null:
		_停("拿不到 GameSession"); return
	# 「忍术境界」按钮的解锁条件是总层数 ≥ 50（`SkillWindow.as:258`），灌够再开窗
	var 技能表: Array[Dictionary] = [
		{"id": "1001001", "level": 20, "master_level": 0},
		{"id": "1001002", "level": 20, "master_level": 0},
		{"id": "1001003", "level": 20, "master_level": 0},
	]
	会话.learned_skills.assign(技能表)

	_底栏 = 场景.get_node_or_null("技能面板/技能栏") as Control
	if _底栏 == null:
		_停("找不到底栏（技能栏）"); return
	_窗 = 场景.get_node_or_null("窗口管理").call("取或建窗口", "忍术")
	if _窗 == null:
		_停("拿不到忍术窗"); return
	if not _点底栏("忍术"):
		_停("底栏没有 tooltip=忍术 的按钮"); return
	await _等帧(6)

	var 按钮 := _找按钮()
	if 按钮 == null:
		_停("找不到「忍术境界」按钮（分页/忍术状态）"); return
	_check(按钮.visible, "总层数 60 ≥ 50，忍术境界按钮应当可见")

	# ① 点开
	按钮.pressed.emit()
	# ⚠️ 别按帧等：无头下帧率不受 vsync 限制，45 帧可能远不到补间的 0.6 秒
	#    （第一版就这么写的，抓到"x=109.1 还没滑到位"的假红）。改成轮询到位。
	await _等滑到位(0.0)
	var 面板 := _取面板()
	_check(面板 != null, "点开后应当取到境界面板")
	if 面板 == null:
		_收尾(); return
	_check(面板.position.x < 20.0, "点开后应滑入到位，实际 x=%.1f" % 面板.position.x)
	_check(面板.visible, "点开后境界面板应当可见")
	_check(not _详情可见(), "展开时详情区应当藏起来（境界底板是半透明的）")

	# ⑥ 境界合计 = 基础层 + 加层。玉链/忍具/勾玉与世界/职业加成都由
	#   `游戏会话.added_skill_level`（`DataCenter.as:795-810`）给，原先只数 `level`
	#   ⇒ 合计恒少一截（用户 2026-11-07 报「没加上灵器、忍具、勾玉增加的忍术层数」）。
	会话.skill_added_levels = {"1001001": 5, "1001003": 3}
	_推一次刷新()
	await _等帧(6)
	var 面板加 := _取面板()
	var 合计标 := 面板加.get_node_or_null("境界合计") as Label if 面板加 != null else null
	_check(合计标 != null and String(合计标.text).find("68") >= 0,
			"⑥ 合计要含加层：60 基础 + 5 + 3 = 68，实际 %s"
			% (String(合计标.text) if 合计标 != null else "取不到标签"))
	会话.skill_added_levels = {}		# 还原，别影响后面的段

	# ⑥-b 境界档位必须跟**同一份合计**走：450 层 = 第 3 档（门槛 450）。
	#   修前合计涨了、档位只用基础层 ⇒ 450 层还亮着「新星崭露头角」
	#   （用户 2026-11-07 报「到了 450 层还是显示上一个境界」）。
	会话.skill_added_levels = {"1001001": 200, "1001002": 100, "1001003": 90}
	_推一次刷新()
	await _等帧(8)
	_check(会话.call("total_skill_level") == 450,
			"⑥ 会话合计应 = 基础 60 + 加层 390 = 450，实际 %d" % int(会话.call("total_skill_level")))
	var 面板档 := _取面板()
	var 合计档 := 面板档.get_node_or_null("境界合计") as Label if 面板档 != null else null
	_check(合计档 != null and String(合计档.text).find("450") >= 0,
			"⑥ 450 层时合计标签要写 450，实际 %s" % (String(合计档.text) if 合计档 != null else "取不到"))
	var 境2 := 面板档.get_node_or_null("境界名_2") as Label if 面板档 != null else null
	var 境3 := 面板档.get_node_or_null("境界名_3") as Label if 面板档 != null else null
	_check(境2 != null and 境2.get_theme_color("font_color") == Color("c7b14f"),
			"⭐ 合计 450 必须点亮第 3 档「精通特殊领域」，实际 %s"
			% (str(境2.get_theme_color("font_color")) if 境2 != null else "取不到"))
	_check(境3 != null and 境3.get_theme_color("font_color") == Color("939393"),
			"第 4 档（门槛 700）未达应保持灰字")
	会话.skill_added_levels = {}		# 还原，别影响后面的段

	# ② 服务端推一条 → 页面重建 → 展开态必须还在
	_推一次刷新()
	await _等帧(6)
	var 新面板 := _取面板()
	_check(新面板 != null and 新面板 != 面板, "刷新后页面应当被重建（面板换新实例）")
	if 新面板 == null:
		_收尾(); return
	_check(新面板.position.x < 20.0,
		"⭐ 重建后境界面板必须仍然展开，实际 x=%.1f（写死收起就会弹回来）" % 新面板.position.x)
	_check(新面板.visible, "重建后境界面板应当仍然可见")
	_check(not _详情可见(), "重建后详情区仍应藏着")

	# ③ 收起 → 再重建 → 应当仍然收起
	var 按钮2 := _找按钮()
	_check(按钮2 != null, "重建后应当还能找到「忍术境界」按钮")
	if 按钮2 == null:
		_收尾(); return
	按钮2.pressed.emit()
	await _等滑到位(210.0)
	var 收面板 := _取面板()
	_check(收面板 != null and 收面板.position.x > 190.0,
		"再点一次应当收起，实际 x=%.1f" % (收面板.position.x if 收面板 != null else -999.0))
	_check(_详情可见(), "收起后详情区应当回来")
	_推一次刷新()
	await _等帧(6)
	var 三面板 := _取面板()
	_check(三面板 != null and 三面板.position.x > 190.0,
		"⭐ 收起态也要扛过重建，实际 x=%.1f" % (三面板.position.x if 三面板 != null else -999.0))
	_check(_详情可见(), "重建后收起态的详情区应当可见")

	# ④ 羁绊 / 轮回眼那两族：**已学也不给「升级条件」**（`DataCenter.as:550-561` 的 notUpgradable）
	await _验不可升级()

	# ⑤ 学习链路（2026-10-20 用户报「背包有技能书仍提示缺少/不能学习」）
	await _验学习()

	# ⑦ 学习条件第三行（族贡 / 八门 / 写轮眼）与可学判定（2026-11-03）
	await _验需求行()

	_收尾()


## ④ 的实测：把「其他忍术」页里那个 `0003306`（= `Job0.couple6`，羁绊技）摆成**已学**，
## 详情区两个子面板**都不该出** —— 原版 `SkillDetailPane.as:184-186`：
##   `升级条件 = !notUpgradable && isStudied && !tab3`、`学习方法 = !isStudied && !tab3`。
## 对照组：普通已学技能（`0001000`）**要**出「升级条件」（否则这条腿可能只是"两个都不出"的假绿）。
func _验不可升级() -> void:
	var 会话: Node = root.get_node_or_null("/root/GameSession")
	会话.learned_skills.assign([
		{"id": "0001000", "level": 20, "master_level": 0},
		{"id": "0003306", "level": 1, "master_level": 0}])
	_窗.set("_skill_tab", 2)			# 其他忍术（`技能分页.json` 里 0003303..0003306 在这页）
	_窗.set("_selected_skill_id", "0003306")
	_推一次刷新()
	await _等帧(6)
	var 详情 := _窗.get_meta(详情键, null) as Control
	if 详情 == null:
		_停("④ 取不到详情区")
		return
	var 升级区 := 详情.get_node_or_null("升级条件区") as CanvasItem
	var 学习区 := 详情.get_node_or_null("学习方法区") as CanvasItem
	if 升级区 == null or 学习区 == null:
		_停("④ 详情区里找不到两个子面板")
		return
	_check(升级区 != null and not 升级区.visible,
			"羁绊技（0003306）已学也不该出「升级条件」面板（`DataCenter.as:550` 的 notUpgradable）")
	_check(学习区 != null and not 学习区.visible, "已学的羁绊技也不该出「学习方法」面板")
	# 对照组：换成职业忍术页的普通技能，同一个位置该出「升级条件」
	_窗.set("_skill_tab", 0)
	_窗.set("_selected_skill_id", "0001000")
	_推一次刷新()
	await _等帧(6)
	var 详情2 := _窗.get_meta(详情键, null) as Control
	var 升级区2 := (详情2.get_node_or_null("升级条件区") as CanvasItem) if 详情2 != null else null
	if 升级区2 == null:
		_停("④ 对照组取不到「升级条件区」")
		return
	_check(升级区2.visible, "对照：普通已学技能（0001000）该出「升级条件」面板")


## ⑤ 学习链路（2026-10-20 用户报「背包有技能书仍提示缺少/不能学习」）。
## 原版判定全在服务端（`_learn_skill`），所以要钉住三件事：
##   a) 背包里没书 → 「学习」钮必须灰、`需要秘笈` 那行转灰（不是"看着能点却没反应"）；
##   b) 塞进那本书 → 钮可点，点下去**技能进已学列表、书被消耗 1**（不是扣金币那种自造规则）；
##   c) 背包里双击同一本书（`use_inventory_slot`）→ 走同一条学习路（服务端 `handle_use_item:50513`）。
## 另外验两条失败提示：没书 / 等级不够时都要有话说（以前是**静默 return false**）。
func _验学习() -> void:
	var 会话: Node = root.get_node_or_null("/root/GameSession")
	if 会话 == null:
		_停("⑤ 拿不到 GameSession")
		return
	# 从「没学过 1002001、背包里没有那本书」开始
	var 初始技能: Array[Dictionary] = [{"id": "0001000", "level": 20, "master_level": 0}]
	会话.learned_skills.assign(初始技能)
	var 空格: Array[Dictionary] = []
	会话.inventory.assign(空格)
	会话.player_stats["level"] = maxi(int(会话.player_stats.get("level", 1)), 30)
	_窗.set("_skill_tab", 0)
	_窗.set("_selected_skill_id", "1002001")
	_推一次刷新()
	await _等帧(6)
	var 详情 := _窗.get_meta(详情键, null) as Control
	if 详情 == null:
		_停("⑤ 取不到详情区")
		return
	var 区 := 详情.get_node_or_null("学习方法区") as Control
	if 区 == null:
		_停("⑤ 详情区里没有学习方法区")
		return
	_check(区.visible, "⑤ 未学技能（1002001 怪力）该出「学习方法」面板")
	var 秘笈 := 区.get_node_or_null("需要秘笈") as Label
	_check(秘笈 != null and String(秘笈.text).begins_with("《怪力》"),
		"⑤ 需要秘笈那行该写《怪力》，实际 %s" % (String(秘笈.text) if 秘笈 != null else "取不到"))
	var 学习 := 区.get_node_or_null("学习") as Button
	if 学习 == null:
		_停("⑤ 学习方法区里没有「学习」钮")
		return
	_check(学习.disabled, "⑤ 背包里没有书时「学习」钮必须置灰")

	# 失败提示：没书时直调会话，必须**有话说**（原来静默 false）
	var 提示: Array[String] = []
	var 收 = func(文: String) -> void: 提示.append(文)
	会话.notification_requested.connect(收)
	会话.learn_skill_from_book("1002002")
	会话.notification_requested.disconnect(收)
	_check(提示.size() == 1 and String(提示[0]).contains("背包里没有"),
		"⑤ 没书时应当提示「背包里没有学习这个技能所需的技能书。」，实际 %s" % str(提示))

	# 塞进《怪力》（`数据/技能文案.json` 的 reqBook = 06000016）
	var 一本: Array[Dictionary] = [{"id": "06000016", "quantity": 1, "slot_index": 1}]
	会话.inventory.assign(一本)
	_推一次刷新()
	await _等帧(6)
	详情 = _窗.get_meta(详情键, null) as Control
	区 = (详情.get_node_or_null("学习方法区") as Control) if 详情 != null else null
	学习 = (区.get_node_or_null("学习") as Button) if 区 != null else null
	if 学习 == null:
		_停("⑤ 塞书后取不到「学习」钮")
		return
	_check(not 学习.disabled, "⑤ 背包里有书、等级够时「学习」钮必须可点")
	学习.pressed.emit()
	await _等帧(4)
	_check(_有技能(会话, "1002001"), "⑤ 点「学习」应当学会 1002001")
	_check(_书数(会话, "06000016") == 0, "⑤ 学会后技能书要被消耗（不花金币）")

	# c) 背包里双击另一本书（`0001000` 的书 = 06000038）也要能学
	var 两格: Array[Dictionary] = [{}, {"id": "06000038", "quantity": 1, "slot_index": 2}]
	会话.inventory.assign(两格)
	var 学了 := bool(会话.use_inventory_slot(2))
	_check(学了 and _有技能(会话, "0001000"), "⑤ 背包里双击技能书也该学会对应忍术")
	_check(_书数(会话, "06000038") == 0, "⑤ 背包双击学会后那本书要被消耗")


## ⑦ 学习条件第三行 + 可学判定（2026-11-03 用户报「未学的忍术，就算背包有对应秘籍，还是不能学习」）。
## 真值 `SkillStudyConditionPane.setData:136-190`：
##   · 第三行三选一：reqBangGong＞0 →「需要族贡：N」；否则 reqMai＞0 →「需要八门：贯通N门」
##     （>8 写成「贯通里·(N−8)门」）；否则 reqXielunyan＞0 →「需要写轮眼：<阶名>」。
##     达成 #007E06 绿、未达 #E00104 红；有第三行时「来源」整块下移到 y=82。
##   · 已入家族且带族贡时，「来源」换成「已加入家族，达到 N 级并满足家族贡献条件后可学习。」。
##   · 学习钮 = 等级 ≥ 需求 && 背包有书 && `isCanStudy`（`DataCenter.as:341-370`）：
##     **reqMai / reqXielunyan 也卡**，而 **reqBangGong 不卡** —— 族贡只显示红字，由服务端拒绝。
## 修前客户端既没有第三行，`学习.disabled` 也只判等级/书（八门/写轮眼都当不存在）。
func _验需求行() -> void:
	var 会话: Node = root.get_node_or_null("/root/GameSession")
	if 会话 == null:
		_停("⑦ 拿不到 GameSession")
		return
	会话.player_stats["level"] = 100
	会话.learned_skills.assign([{"id": "0001000", "level": 20, "master_level": 0}])
	会话.inventory.assign([
		{"id": "06000022", "quantity": 1},
		{"id": "06000046", "quantity": 1},
		{"id": "06000054", "quantity": 1},
		{"id": "06000055", "quantity": 1},
		{"id": "06000056", "quantity": 1},
		{"id": "06000057", "quantity": 1},
		{"id": "06000070", "quantity": 1},
	])
	# 未入家族却攒了 999 贡献 ⇒ 族贡行必须仍按 0 算（`_家族贡献`）。
	会话.guild = {"joined": false, "contribution": 999}
	会话.cultivation_states["八门"] = {"list_id": 0, "exploded": {}}
	会话.cultivation_states["写轮眼"] = {"stage": 0}

	# ① 无任何额外要求的技能：第三行整行隐藏，「来源」留在 y=60
	var 区 := await _看法(1, "0003006")
	if 区 == null:
		_停("⑦ 取不到学习方法区（0003006）")
		return
	var 标题 := 区.get_node_or_null("贡献标题") as Label
	var 值 := 区.get_node_or_null("贡献值") as Label
	if 标题 == null or 值 == null:
		_停("⑦ 学习方法区里没有第三行节点（贡献标题/贡献值）")
		return
	_check(not 标题.visible and not 值.visible, "⑦ 无额外要求时第三行整行隐藏")
	_check(absf((区.get_node("来源") as Control).position.y - 60.0) < 0.5,
			"⑦ 无第三行时「来源」留在 y=60")

	# ② 族贡：未入家族 ⇒ 贡献按 0 算（红），但钮仍可点（isCanStudy 不含族贡）
	区 = await _看法(2, "0003110")
	if 区 == null:
		_停("⑦ 取不到学习方法区（0003110）")
		return
	标题 = 区.get_node("贡献标题") as Label
	值 = 区.get_node("贡献值") as Label
	_check(标题.visible and 值.visible, "⑦ 带 reqBangGong 的技能必须出第三行")
	_check(标题.text == "需要族贡：", "⑦ 第三行标题 =「需要族贡：」，实际 %s" % 标题.text)
	_check(值.text == "100", "⑦ reqBangGong=100 ⇒ 值写 100，实际 %s" % 值.text)
	_check(值.get_theme_color("font_color") == Color("e00104"),
			"⑦ 未入家族（贡献按 0）⇒ 100 未达，红字，实际 %s" % str(值.get_theme_color("font_color")))
	var 来源 := 区.get_node("来源") as Label
	_check(absf(来源.position.y - 82.0) < 0.5, "⑦ 有第三行时「来源」下移到 y=82，实际 %.1f" % 来源.position.y)
	_check(not String(来源.text).contains("已加入家族"),
			"⑦ 未入家族时「来源」不许换成家族说明句，实际 %s" % 来源.text)
	var 学习 := 区.get_node("学习") as Button
	_check(not 学习.disabled,
			"⑦ 书和等级都够、族贡没达标 ⇒ 钮仍可点（原版 isCanStudy 不卡族贡，由服务端回「需要家族贡献」）")

	会话.guild = {"joined": true, "contribution": 50}
	区 = await _看法(2, "0003110")
	值 = 区.get_node("贡献值") as Label
	来源 = 区.get_node("来源") as Label
	_check(值.get_theme_color("font_color") == Color("e00104"), "⑦ 族贡 50 < 100 ⇒ 红字")
	_check(String(来源.text).contains("已加入家族"),
			"⑦ 已入家族且带族贡 ⇒「来源」换成家族说明句，实际 %s" % 来源.text)
	会话.guild = {"joined": true, "contribution": 100}
	区 = await _看法(2, "0003110")
	值 = 区.get_node("贡献值") as Label
	_check(值.get_theme_color("font_color") == Color("007e06"), "⑦ 族贡 100 达标 ⇒ 绿字")
	_check(not (区.get_node("学习") as Button).disabled, "⑦ 族贡达标后钮仍可点")

	# ③ 八门（reqMai）：没贯通够 ⇒ 钮必须灰（修前只判等级/书 ⇒ 假可点）
	会话.guild = {"joined": false, "contribution": 0}
	会话.cultivation_states["八门"] = {"list_id": 0, "exploded": {}}
	区 = await _看法(3, "0003201")
	if 区 == null:
		_停("⑦ 取不到学习方法区（0003201）")
		return
	标题 = 区.get_node("贡献标题") as Label
	值 = 区.get_node("贡献值") as Label
	_check(标题.text == "需要八门：", "⑦ 八门行标题 =「需要八门：」，实际 %s" % 标题.text)
	_check(值.text == "贯通5门", "⑦ reqMai=5 ⇒「贯通5门」，实际 %s" % 值.text)
	_check(值.get_theme_color("font_color") == Color("e00104"), "⑦ 贯通 0/5 ⇒ 红字")
	_check((区.get_node("学习") as Button).disabled,
			"⑦ 书、等级都够但八门没贯通够 ⇒ 钮必须灰（isCanStudy 的 reqMai 那条）")
	# 当前脉贯通 5 门（`JingMaiSource.getThroughMaiNumber:240-249`：每门已开数 == 该门穴位数）
	会话.cultivation_states["八门"] = {"list_id": 0,
		"exploded": {0: 24, 1: 21, 2: 25, 3: 26, 4: 21}}
	区 = await _看法(3, "0003201")
	_check(not (区.get_node("学习") as Button).disabled, "⑦ 贯通 5 门达标 ⇒ 钮可点")
	_check((区.get_node("贡献值") as Label).get_theme_color("font_color") == Color("007e06"),
			"⑦ 贯通达标 ⇒ 绿字")
	# listId 那一段：脉 1、一门没开 ⇒ 贯通 8 门，正好满足 reqMai=8
	会话.cultivation_states["八门"] = {"list_id": 1, "exploded": {}}
	区 = await _看法(3, "0003202")
	_check(not (区.get_node("学习") as Button).disabled,
			"⑦ listId=1 且本脉一门没开 ⇒ 贯通 8 门（listId×8），满足 reqMai=8")
	# >8 的文字口径：reqMai=16、脉 2 ⇒「贯通里·8门」（`SKILLSTUDYCONDITION_PANE_LI` =「里·」）
	会话.cultivation_states["八门"] = {"list_id": 2, "exploded": {}}
	区 = await _看法(3, "0003203")
	值 = 区.get_node("贡献值") as Label
	_check(值.text == "贯通里·8门", "⑦ reqMai=16、脉 2 ⇒「贯通里·8门」，实际 %s" % 值.text)
	_check(not (区.get_node("学习") as Button).disabled, "⑦ 贯通 16 门达标 ⇒ 钮可点")

	# ④ 写轮眼（reqXielunyan）：阶名照 `CN.SKILLSTUDYCONDITION_XUYAO_XIELUNYAN`
	会话.cultivation_states["写轮眼"] = {"stage": 3}
	区 = await _看法(3, "0003204")
	if 区 == null:
		_停("⑦ 取不到学习方法区（0003204）")
		return
	标题 = 区.get_node("贡献标题") as Label
	值 = 区.get_node("贡献值") as Label
	_check(标题.text == "需要写轮眼：", "⑦ 写轮眼行标题 =「需要写轮眼：」，实际 %s" % 标题.text)
	_check(值.text == "月读", "⑦ reqXielunyan=4 ⇒ 阶名「月读」，实际 %s" % 值.text)
	_check(值.get_theme_color("font_color") == Color("e00104"), "⑦ stage 3 < 4 ⇒ 红字")
	_check((区.get_node("学习") as Button).disabled, "⑦ 写轮眼没到 4 阶 ⇒ 钮必须灰")
	会话.cultivation_states["写轮眼"] = {"stage": 4}
	区 = await _看法(3, "0003204")
	_check(not (区.get_node("学习") as Button).disabled, "⑦ 写轮眼 4 阶达标 ⇒ 钮可点")
	_check((区.get_node("贡献值") as Label).get_theme_color("font_color") == Color("007e06"),
			"⑦ 写轮眼达标 ⇒ 绿字")
	会话.cultivation_states["写轮眼"] = {"stage": 9}
	区 = await _看法(3, "0004009")
	if 区 != null:
		_check((区.get_node("贡献值") as Label).text == "轮回眼",
				"⑦ reqXielunyan=9 ⇒ 阶名「轮回眼」，实际 %s" % (区.get_node("贡献值") as Label).text)


## 切页签/选中并等页面重建，返回学习方法区（取不到返回 null）。
func _看法(页签: int, 技能号: String) -> Control:
	_窗.set("_skill_tab", 页签)
	_窗.set("_selected_skill_id", 技能号)
	_推一次刷新()
	await _等帧(6)
	var 详情 := _窗.get_meta(详情键, null) as Control
	return (详情.get_node_or_null("学习方法区") as Control) if 详情 != null else null


func _有技能(会话: Node, 编号: String) -> bool:
	for 技能 in 会话.learned_skills:
		if String(技能.get("id", "")).pad_zeros(7) == String(编号).pad_zeros(7):
			return true
	return false


func _书数(会话: Node, 书id: String) -> int:
	var 合计 := 0
	for 物品 in 会话.inventory:
		if String(物品.get("id", "")).pad_zeros(8) == String(书id).pad_zeros(8):
			合计 += int(物品.get("quantity", 0))
	return 合计


func _推一次刷新() -> void:
	var 会话: Node = root.get_node_or_null("/root/GameSession")
	会话.skills_changed.emit(会话.learned_skills.duplicate(true))


func _取面板() -> Control:
	return _窗.get_meta(面板键, null) as Control


func _详情可见() -> bool:
	var 详情 := _窗.get_meta(详情键, null) as CanvasItem
	return 详情 != null and 详情.visible


func _找按钮() -> Button:
	var 面板 := _取面板()
	if 面板 == null:
		return null
	# 面板 → 境界区 → 页面
	var 页面 := 面板.get_parent().get_parent() as Node
	return 页面.get_node_or_null("分页/忍术状态") as Button


func _点底栏(提示: String) -> bool:
	for 节点 in _底栏.find_children("*", "BaseButton", true, false):
		var 按钮 := 节点 as BaseButton
		if 按钮 != null and 按钮.tooltip_text == 提示:
			按钮.pressed.emit()
			return true
	return false


func _等帧(数: int) -> void:
	for _i in 数:
		await process_frame


## 等补间把面板滑到 `目标`（容差 1px），最多等 `上限` 帧。
func _等滑到位(目标: float, 上限 := 600) -> void:
	for _i in 上限:
		var 面板 := _取面板()
		if 面板 != null and absf(面板.position.x - 目标) <= 1.0:
			return
		await process_frame


func _check(条件: bool, 讯息: String) -> void:
	断言 += 1
	if not 条件:
		_失败.append(讯息)


func _停(原因: String) -> void:
	_失败.append(原因)
	_收尾()


func _收尾() -> void:
	if not _存档前.is_empty():
		门存档快照.全还原(_存档前)
	if _失败.is_empty():
		print("忍术境界回归测试：通过（%d 条断言）" % 断言)
		quit(0)
		return
	for 项 in _失败:
		push_error("忍术境界回归失败：" + 项)
	print("忍术境界回归测试失败：%d 项（共 %d 条断言）" % [_失败.size(), 断言])
	quit(1)
