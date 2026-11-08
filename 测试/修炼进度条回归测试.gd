extends SceneTree

## 修炼页（写轮眼 / 柔拳）每阶那几根**属性进度条**的回归门（§3.237）。
##
## 用户 2026-10-21 报修 2.1 原话：「血继界限写轮眼，使用精魄，有提升属性，但是写轮眼的进度条
## 没有增加进度值，其他类似的，柔拳也要检查」。根因不是"算错一格"，而是**这条链压根没接**：
## 页面由另一位开发者的 .tscn + 脚本烘出来，他只负责切页显隐，四根（最多九根）条子从头到尾
## 停在 Godot 默认的 `0/100`，旁边那行 `0/200` 是场景里的**示例字**、没人覆盖过。
## ⇒ 以前的门全绿（`人物秘术页回归测试` 量的是"能不能建、阶段推没推到、弹窗接没接线"），
## 这一条补的就是那个盲区。
##
## 真值口径（两条腿都核过反编译）：
##  · `TongshuWindow.as:533-580 setBarData` + `MBar.as:129-166 setData`（写轮眼页）
##  · `RouQuanManager.as:128-167 getRouQuanProps` + `RouQuanPanel.as:580-645 updateProp`（柔拳页，同一式子）
##  · 分母 = **查看阶自己**的 `levelUp.maxItemCnt`，与服务端 `cultivation_progress_requirement`
##    （`fake_flash_server.py:7715-7724`，`maxItemCnt` → `maxJingHun` 的回退链）同口径。
##
## ⚠ 一条**有意偏离**：属性按**类型**对号、不按 `attrs` 下标。`XieLunYan.stage6` 把
## `anqi_trigger` 排在最后一位（下标 8），而原版 `setBarData` 是 `barArr[i] ← attrs[i]`、
## 标签却写死在 `:268`「手里剑触发几率」⇒ 原版第 6 阶会把**反弹伤害**的数画进**手里剑触发几率**的条。
## 柔拳那页自己反而是 `switch (type)`（`RouQuanPanel.as:600-644`）⇒ 跟柔拳、不跟写轮眼那条下标写法。
## 门 ② 就是钉这一条的。
##
## 运行：Godot --headless --path . --script res://测试/修炼进度条回归测试.gd

const 人物脚本 := preload("res://脚本/界面/窗口/人物窗口.gd")
const 写轮眼页路 := "res://场景/界面/窗口/人物/页面/写轮眼页.tscn"
const 柔拳页路 := "res://场景/界面/窗口/人物/页面/柔拳页.tscn"
const 写轮眼区 := "阶段，数值名称切换区"
const 柔拳区 := "数值，阶段名称切换区"

var _通过 := 0
var _失败: Array[String] = []


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_跑")


func _判(对: bool, 明: String, 反: String = "") -> void:
	if 对:
		_通过 += 1
	else:
		_失败.append("%s%s" % [明, "" if 反.is_empty() else " ⇒ " + 反])


## 建一页并挂进树（他的脚本在 `_ready()` 里自己接线，不挂树等于跑不到那条路）。
func _建(路径: String) -> Control:
	var 包 := load(路径) as PackedScene
	if 包 == null:
		_失败.append("场景建不出来：%s" % 路径)
		return null
	var 页 := 包.instantiate() as Control
	root.add_child(页)
	return 页


## 读一根条：`{值, 上限, 字}`；条或字取不到返回空字典（调用方按"没填上"记红）。
func _量(页: Control, 区名: String, 组名: String, 条名: String) -> Dictionary:
	var 区 := 页.find_child(区名, true, false) as Control
	var 组 := 区.get_node_or_null(组名) as Control if 区 != null else null
	var 条 := 组.get_node_or_null(条名) as ProgressBar if 组 != null else null
	if 条 == null:
		return {}
	var 字 := 组.get_node_or_null("%s值" % 条名) as Label
	return {"值": 条.value, "上限": 条.max_value, "字": String(字.text) if 字 != null else "<无标签>"}


## `%d/%d` 这条字必须一起量：条子动了、字没动，用户看到的还是"进度没涨"。
## ⚠ 填充是 `进度条补间` 的 **0.5 秒补间**（§3.243）⇒ 量之前必须等**墙上时钟**半秒以上：
##   无头下一帧可以短到微秒，"等 2 帧"不等于"等半秒"（§3.207 同源）。文案那条不受影响，
##   它按数据立刻写（`MBar.as:151-168` 在 `:170` 之前）。
func _核(页: Control, 区名: String, 组名: String, 条名: String, 期值: int, 期上限: int, 明: String) -> void:
	await create_timer(0.7).timeout
	var 得 := _量(页, 区名, 组名, 条名)
	_判(not 得.is_empty(), "%s：%s/%s 取得到" % [明, 组名, 条名], "节点名与类型表对不上")
	if 得.is_empty():
		return
	_判(int(得["值"]) == 期值 and int(得["上限"]) == 期上限,
		"%s ⇒ %s/%s 应为 %d/%d" % [明, 组名, 条名, 期值, 期上限],
		"实得 %s/%s" % [str(得["值"]), str(得["上限"])])
	_判(String(得["字"]) == "%d/%d" % [期值, 期上限],
		"%s ⇒ %s/%s 旁边那行字应为 %d/%d" % [明, 组名, 条名, 期值, 期上限],
		"实得「%s」" % String(得["字"]))


## 数据自己从 JSON 读一遍（`游戏数据表` 只是 `人物窗口.gd` 里的文件级 const 别名，
## 门里够不着；照着 `人物秘术页回归测试.gd:2035` 的写法独立取表，免得跟生产代码共用一个假设）。
func _原版杂项() -> Dictionary:
	var 包: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/原版杂项.json"))
	return 包 as Dictionary if 包 is Dictionary else {}


func _跑() -> void:
	var 眼页 := _建(写轮眼页路)
	var 拳页 := _建(柔拳页路)
	if 眼页 == null or 拳页 == null:
		_收尾()
		return

	# ① 写轮眼：三档（低于真阶=满 / 等于真阶=插值 / 高于真阶=0）
	人物脚本.填修炼进度条(眼页, 写轮眼区, "XieLunYan", 12, {"stage": 2, "count": 125})
	await _核(眼页, 写轮眼区, "单勾玉阶段", "生命", 200, 200, "① 查看阶<真阶画满")
	# stage1 maxhp 200 → stage2 500，需求 250：200 + floor(125×300/250) = 350
	await _核(眼页, 写轮眼区, "双勾玉阶段", "生命", 350, 500, "① 查看阶==真阶按进度插值")
	await _核(眼页, 写轮眼区, "双勾玉阶段", "查克拉", 30, 45, "① 同一档另一根（15→45，进度一半）")
	await _核(眼页, 写轮眼区, "三勾玉阶段", "生命", 0, 1000, "① 查看阶>真阶归零")

	# ② 用户报的那一下：进度涨了 ⇒ 条子必须跟着涨（不是只改场景示例字）
	人物脚本.填修炼进度条(眼页, 写轮眼区, "XieLunYan", 12, {"stage": 2, "count": 250})
	await _核(眼页, 写轮眼区, "双勾玉阶段", "生命", 500, 500, "② 精魄喂满这一阶 ⇒ 条子走满")
	人物脚本.填修炼进度条(眼页, 写轮眼区, "XieLunYan", 12, {"stage": 2, "count": 99999})
	await _核(眼页, 写轮眼区, "双勾玉阶段", "生命", 500, 500, "② 进度超需求要夹住（`MBar.as:135-138`）")

	# ③ 类型对号（有意偏离那条）：`XieLunYan.stage6` 把 `anqi_trigger` 排在 attrs **末位**（下标 8），
	#    而这一组场景里第 7 根节点名叫「手里剑触发几率」。原版是
	#    `this.barArr[i].setData(loc2[i].value, …)`（`TongshuWindow.as:577`，按下标），
	#    标签却写死在 `:268`「手里剑几率」⇒ 原版第 6 阶把 **反弹伤害 = 4** 画进「手里剑触发几率」。
	#    我们按类型 ⇒ 5。这一组只有 7 根条（原版 `barVisibleArr[5] = 7`，`:376-395`）
	#    ⇒ 反弹伤害/伤害免疫两根**根本不存在**，第二条腿钉的是"没条就别凭空造节点"。
	人物脚本.填修炼进度条(眼页, 写轮眼区, "XieLunYan", 12, {"stage": 6, "count": 450})
	await _核(眼页, 写轮眼区, "须佐之男阶段", "手里剑触发几率", 5, 5, "③ 按类型对号（按下标会画成 4）")
	_判(_量(眼页, 写轮眼区, "须佐之男阶段", "反弹伤害").is_empty(),
		"③ 这一阶只有 7 根条 ⇒ 反弹伤害不该存在")
	# 第 7 阶起手里剑与反弹伤害**同时**在数据里 ⇒ 两根各归各位（下标写法在这里恰好也对，用来兜底）
	人物脚本.填修炼进度条(眼页, 写轮眼区, "XieLunYan", 12, {"stage": 7, "count": 500})
	await _核(眼页, 写轮眼区, "伊邪那歧阶段", "手里剑触发几率", 12, 12, "③ 第 7 阶 手里剑触发几率")
	await _核(眼页, 写轮眼区, "伊邪那歧阶段", "反弹伤害", 7, 7, "③ 第 7 阶 反弹伤害")
	await _核(眼页, 写轮眼区, "月读阶段", "生命", 2000, 2000, "③ 真阶 7 时第 4 阶早已练满")
	# 写轮眼这页第 9 根节点名叫「伤害免疫」（柔拳那页同类型叫「伤害减免」）⇒ 名字表漏一个就填不上
	人物脚本.填修炼进度条(眼页, 写轮眼区, "XieLunYan", 12, {"stage": 8, "count": 550})
	await _核(眼页, 写轮眼区, "永恒万花筒阶段", "伤害免疫", 10, 10, "③ 写轮眼页 damage_reduce 叫「伤害免疫」")

	# ④ 柔拳（同一式子的另一页）：stage2 500 → stage3 1000，需求 30
	人物脚本.填修炼进度条(拳页, 柔拳区, "RouQuan", 8, {"stage": 3, "count": 15})
	await _核(拳页, 柔拳区, "第三阶段", "生命", 750, 1000, "④ 柔拳插值")
	await _核(拳页, 柔拳区, "第一阶段", "生命", 200, 200, "④ 柔拳查看阶<真阶画满")
	await _核(拳页, 柔拳区, "第四阶段", "生命", 0, 2000, "④ 柔拳查看阶>真阶归零")
	# 同一类型两页节点名不同：写轮眼「伤害免疫」/ 柔拳「伤害减免」（名字表只认一个 ⇒ 另一页静默不填）
	人物脚本.填修炼进度条(拳页, 柔拳区, "RouQuan", 8, {"stage": 5, "count": 40})
	await _核(拳页, 柔拳区, "第五阶段", "伤害减免", 2, 2, "④ 柔拳 伤害减免（写轮眼那页同类型叫 伤害免疫）")

	# ⑤ 场景 ↔ 名字表**反向**对号：每根条都得有名字（能反查到类型）、该类型在这阶的数据里真有、
	#    且旁边有 `X值` 标签。防的是"美术改了节点名 ⇒ 代码静默不填"（这正是本轮 bug 的形态）。
	#    ⚠ 方向是 条→数据、不是 数据→条：原版每阶只画 `barVisibleArr[阶]` 根
	#    （`TongshuWindow.as:376-395`，写轮眼 `[4,4,4,4,6,7,8,9,9,9,9,9]`），
	#    高阶段少几根 attrs 是**原版行为**，反着钉会假红。
	for 项 in [[眼页, 写轮眼区, "XieLunYan", 12], [拳页, 柔拳区, "RouQuan", 8]]:
		var 页: Control = 项[0]
		var 区 := 页.find_child(String(项[1]), true, false) as Control
		_判(区 != null, "⑤ %s 找得到「%s」" % [项[2], 项[1]])
		if 区 == null:
			continue
		_判(区.get_child_count() == int(项[3]),
			"⑤ %s 的组数应为 %d（一阶一组）" % [项[2], 项[3]], "实得 %d" % 区.get_child_count())
		var 族表: Dictionary = _原版杂项().get(String(项[2]), {}) as Dictionary
		var 漏 := ""
		# 类型名 → 条名（反查用）
		var 反查 := {}
		for 型 in 人物脚本.修炼属性条名:
			for 名 in (人物脚本.修炼属性条名[型] as Array):
				反查[String(名)] = 型
		for 下标 in mini(int(项[3]), 区.get_child_count()):
			var 组 := 区.get_child(下标) as Control
			var 本阶 := 人物脚本.修炼阶属性(族表, 下标 + 1)
			for 子 in 组.get_children():
				if not (子 is ProgressBar):
					continue
				var 条名 := String(子.name)
				var 型 := String(反查.get(条名, ""))
				if 型.is_empty():
					漏 = "%s/%s 这根条名字表里查不到类型" % [组.name, 条名]
				elif not 本阶.has(型):
					漏 = "%s/%s 对应类型「%s」不在阶 %d 的数据里" % [组.name, 条名, 型, 下标 + 1]
				elif not (组.get_node_or_null("%s值" % 条名) is Label):
					漏 = "%s/%s 旁没有「%s值」标签" % [组.name, 条名, 条名]
		_判(漏.is_empty(), "⑤ 场景每根条都反查得到类型、且该阶数据里真有", 漏)
		# 正向兜底：低阶（4 根条那几组）attrs 里有的类型必须一根不漏
		var 正查 := ""
		for 阶 in [1, 2, 3, 4]:
			var 组 := 区.get_child(阶 - 1) as Control
			for 型 in 人物脚本.修炼阶属性(族表, 阶):
				var 中 := false
				for 名 in (人物脚本.修炼属性条名.get(型, []) as Array):
					if 组.get_node_or_null(String(名)) is ProgressBar:
						中 = true
				if not 中:
					正查 = "%s 阶%d 类型「%s」找不到条" % [项[2], 阶, 型]
		_判(正查.is_empty(), "⑤ 前四阶（4 根条）attrs 全对得上", 正查)

	# ⑥ 接线腿：两页的初始化**真的**各调了一次（不调就回到本轮那个"永远 0/100"的世界）
	var 文 := FileAccess.get_file_as_string("res://脚本/界面/窗口/人物窗口.gd")
	_判(文.contains("填修炼进度条(页面, \"%s\", \"XieLunYan\"" % 写轮眼区),
		"⑥ 写轮眼页初始化里接了 `填修炼进度条(… XieLunYan …)`")
	_判(文.contains("填修炼进度条(页面, \"%s\", \"RouQuan\"" % 柔拳区),
		"⑥ 柔拳页初始化里接了 `填修炼进度条(… RouQuan …)`")

	# ⑦ 与服务端同分母：回退链字面两头各钉一遍（客户端少写 `maxJingHun` 就变成"轮回那族除 0"）
	_判(文.contains("for 键 in [\"maxItemCnt\", \"maxJingHun\"]"),
		"⑦ 客户端分母按 maxItemCnt → maxJingHun 回退")
	var 服 := FileAccess.get_file_as_string("res://服务端/runtime/tools/fake_flash_server.py")
	_判(服.contains('for key in ("maxItemCnt", "maxJingHun")'),
		"⑦ 服务端 `cultivation_progress_requirement` 用的是同一条回退链")

	_收尾()


func _收尾() -> void:
	print("修炼进度条回归：通过 %d 条，失败 %d 条" % [_通过, _失败.size()])
	for 条 in _失败:
		print("  ✗ " + 条)
	print("跑完了")
	quit(1 if not _失败.is_empty() else 0)
