extends SceneTree

## 容量帧刷新回归门（2026-10-11）：**扩充行囊/仓库之后，界面得跟着变**。
##
## 病根：背包窗与仓库窗的**总格数不是存在窗口上的**，是 `渲染()` 里现读
## `BackendConnection.authoritative_bag_capacity`（`背包窗口._背包总格数`）。
## 而容量帧（`1084` 背包 / `1085` 仓库）在 `后端连接` 里只做两件事：写权威值 + `emit` 信号 ——
## 那两个信号 **`bag_capacity_received` / `storage_received` 全工程零连接点**
## （2026-10-11 扫"emit 了没人接"逮到）⇒ 没人重画。
##
## 为什么平时没露馅：服务端 `_extend_item_capacity` 是**先发背包/仓库帧、后发容量帧**，
## 而 `功能窗口._refresh_current()` 走 `call_deferred` —— **两帧被同一次 socket 读一起拿到**时，
## 那次重画正好落在两帧之后，界面碰巧是新的。拆到两次读（真网络、或服务端分两次 flush）
## 就停在旧格数上，非得重开窗才看见。**这是顺序竞态，不是必然复发** —— 所以门必须
## **显式分两拍**驱动：先让权威值变 + 发容量帧，再看界面有没有跟上。
##
## 盯两件 + 仓库页一处顺带账：
##   ① 背包容量帧 ⇒ 背包页标题 `背包(已用/总格数)` 里的**总格数**跟着变；
##   ② 仓库容量帧 ⇒ 仓库页同理（仓库那条走 `storage_received` 三参，别接错参数个数）；
##   ③ 仓库页「背包那边早修过、这一页没跟着走」的账（已用数洞 / 叠放数量字号 / 页签高亮写死第一页 /
##      2026-10-25 标题「占位数/总」按背包拆尾巴、下方金币值同背包 14 号金色）。
##
## ⚠ 口径：本门**不发任何协议**（`emit` 是直接调的）；开场钉 `root.size`；
##    走 `call_deferred` 让宿主 `_ready` 跑起来（§3.124.4）。
##
## 运行：`Godot --headless --path . --script res://测试/容量帧刷新回归测试.gd`

const 窗场景 := "res://场景/界面/功能窗口.tscn"

var 红数 := 0


func _记(过: bool, 文: String) -> void:
	if not 过:
		红数 += 1
		print("!! " + 文)


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)
	var 场: Node = (load(窗场景) as PackedScene).instantiate()
	root.add_child(场)
	await process_frame
	await process_frame

	var 后端 := root.get_node_or_null("BackendConnection")
	if 后端 == null:
		_记(false, "缺 BackendConnection")
		_finish()
		return

	# ⚠️ 两段都必须**喂文本帧**（`_handle_bridge_text("1085:150")`）走真 handler，
	#    不能直接 `emit` 信号 —— 修在 handler 里，直接 emit 等于把被测的那段跳过去。
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 == null:
		_记(false, "缺 GameSession")
		_finish()
		return

	# ① 背包（`1084`）：背包窗的总格数读 `后端.authoritative_bag_capacity`
	后端.set("authoritative_bag_capacity", 60)
	await 开页(场, "背包")
	var 标题一 := _标题(场)
	_记(标题一.contains("/60"), "开背包页后标题没带总格数 60，实测「%s」" % 标题一)
	后端.call("_handle_bridge_text", "1084:90")
	await 晾()
	_记(_标题(场).contains("/90"),
			"收到 1084 背包容量帧（60→90）后界面没跟着变，实测「%s」" % _标题(场))

	# ② 仓库（`1085`）：仓库窗读的是**会话**的 `storage_capacity`，容量帧必须把它一起落掉
	会话.set("storage_capacity", 120)
	await 开页(场, "NPC仓库")
	var 仓标题 := _标题(场)
	_记(仓标题.contains("/120"), "开仓库页后标题没带总格数 120，实测「%s」" % 仓标题)
	后端.call("_handle_bridge_text", "1085:150")
	await 晾()
	_记(_标题(场).contains("/150"),
			"收到 1085 仓库容量帧（120→150）后界面没跟着变，实测「%s」" % _标题(场))

	# ③ 仓库页几处**背包同族**的账（2026-10-17 巡检 #15；2026-10-25 补 d）：
	#    这些都不是容量问题，是"背包那边早修过、仓库这一页没跟着走"——
	#    a) 标题「已用」按 `size()` 数 ⇒ 把稳定格位制的 {} 洞也算进件数（背包 2026-10-01 B 改过）；
	#    b) 格子里那行叠放数量字号：仓库/背包共用 `物品格.tscn`，背包 2026-10-25 已是 14，
	#       仓库按用户「堆叠数量…也要跟背包一致」跟到 14；
	#    c) 页签高亮写死 `序号 == 0` ⇒ 回帧重建时把玩家翻到的第 3 页顶回「一」，
	#       而格子内容读的仍是 `_取页(窗口)`（同 2026-10-01「背包自动返回第一页」那条病根）。
	#    d) 2026-10-25 用户：「仓库、占位数/总，你照着背包 占位数/总改」⇒ 标题拆「仓库」+ 尾巴
	#       `(已用/总)`，主标题 14、尾巴 16 且走裸 FontFile（同背包 §3.286~§3.288）。
	#    e) 2026-10-25 用户：「下方金币格式也要跟背包一致」⇒ 值 14 号金色，标题仍 12。
	会话.set("storage", 会话.落位带洞([
		{"id": "16000001", "name": "乙火", "quantity": 5, "slot_index": 1},
		{"id": "16000002", "name": "丙火", "quantity": 1, "slot_index": 5},
	]))
	会话.set("storage_gold", 1234567)
	场.set("_仓库页", 2)		# 玩家翻到第 3 页
	场.call("_refresh_current")
	await 晾()
	var 仓页 := (场.get("_content") as Control).find_child("原版NPC仓库内容", true, false) as Control
	if 仓页 == null:
		_记(false, "③ 取不到仓库页 ⇒ 三条仓库同族账没量到")
	else:
		var 仓标题二 := _标题(场)
		# 数组长度 5（1..5 含三个洞），**已用只有 2**
		_记(仓标题二.contains("(2/"),
				"③a 仓库标题的「已用」把空格洞也数进去了：数组长 %d、实有 2 件，实测「%s」"
				% [(会话.get("storage") as Array).size(), 仓标题二])
		var 数量标 := 仓页.find_child("数量", true, false) as Label
		var 号: Variant = 数量标.get("theme_override_font_sizes/font_size") if 数量标 != null else null
		_记(号 != null and int(号) == 14,
				"③b 仓库格里的叠放数量该跟背包一致是 14，实测 %s" % 号)
		if 数量标 != null:
			_记(数量标.get_theme_color("font_color") == Color.WHITE,
					"③b 仓库叠放数量该是白色（与背包同一套 `_configure_label`），实测 %s"
					% 数量标.get_theme_color("font_color"))
			_记(数量标.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT,
					"③b 仓库叠放数量该右对齐（与背包同一份 `物品格.tscn`），实测 %d"
					% 数量标.horizontal_alignment)
		# ③d 标题「占位数/总」与背包同款：主标题 14 + 尾巴 16 裸字体。
		var 标题主 := 场.get("_title") as Label
		var 标题尾 := 场.get("_title_数值") as Label
		_记(标题主 != null and 标题主.text == "仓库",
				"③d 仓库主标题该只剩「仓库」（占位数在尾巴上），实测「%s」"
				% (标题主.text if 标题主 != null else "<空>"))
		_记(标题尾 != null and 标题尾.visible and 标题尾.text == "(2/150)",
				"③d 仓库标题尾巴该是可见的「(2/150)」，实测 visible=%s text=「%s」"
				% [标题尾.visible if 标题尾 != null else "无节点", 标题尾.text if 标题尾 != null else ""])
		_记(标题主 != null and 标题主.get_theme_font_size("font_size") == 14,
				"③d 仓库主标题字号该跟背包一致是 14，实测 %s"
				% (标题主.get_theme_font_size("font_size") if 标题主 != null else "无节点"))
		_记(标题尾 != null and 标题尾.get_theme_font_size("font_size") == 16,
				"③d 仓库占位数尾巴字号该跟背包一致是 16，实测 %s"
				% (标题尾.get_theme_font_size("font_size") if 标题尾 != null else "无节点"))
		var 尾字体: Font = (标题尾.get_theme_font("font") if 标题尾 != null else null) as Font
		_记(尾字体 != null and not (尾字体 is FontVariation),
				"③d 仓库占位数必须走裸 FontFile（数字没有点阵，套标题变体合成加粗会发灰/糊）")
		# ③e 下方「仓库中金币」的值与背包同款：千分位 + 14 号 + 金色。
		var 金标 := 仓页.get_node_or_null("仓库金币数") as Label
		_记(金标 != null and 金标.text == "1,234,567",
				"③e 仓库金币数该按千分位显示「1,234,567」，实测「%s」"
				% (金标.text if 金标 != null else "<无节点>"))
		_记(金标 != null and 金标.get_theme_font_size("font_size") == 14,
				"③e 仓库金币数该跟背包货币值一致是 14，实测 %s"
				% (金标.get_theme_font_size("font_size") if 金标 != null else "无节点"))
		_记(金标 != null and 金标.get_theme_color("font_color") == Color("fff000"),
				"③e 仓库金币数该是金色（fff000，同背包货币值），实测 %s"
				% (金标.get_theme_color("font_color") if 金标 != null else "无节点"))
		var 页三 := 仓页.get_node_or_null("分页/第3页") as Button
		var 页一 := 仓页.get_node_or_null("分页/第1页") as Button
		_记(页三 != null and 页三.disabled, "③c 停在第 3 页、重建后「三」该是按下态（disabled）")
		_记(页一 != null and not 页一.disabled, "③c 停在第 3 页、重建后「一」不该还亮着（高亮被写死回第一页）")

	_finish()


## 打开某一页并等它画完（`_refresh_current` 走 `call_deferred`，要多等几帧）。
func 开页(场: Node, 页名: String) -> void:
	场.call("open_page", 页名)
	await 晾()


func 晾() -> void:
	for _帧 in range(4):
		await process_frame


## 标题的**完整显示文本**。2026-10-25 起背包、仓库都把「(已用/总)」拆到 `_title_数值` 上
## （裸字体、不跟标题变体合成加粗），拼回来才是玩家看到的那一行；
## 其他页仍是整条 `_title.text`，尾巴为空/不可见。
func _标题(场: Node) -> String:
	var 标 := 场.get("_title") as Label
	if 标 == null:
		return ""
	var 尾 := 场.get("_title_数值") as Label
	if 尾 != null and 尾.visible:
		return 标.text + 尾.text
	return 标.text


func _finish() -> void:
	if 红数 == 0:
		print("容量帧刷新回归测试：通过（背包 1084 / 仓库 1085 都会让界面重画；仓库页已用数·叠放数量·标题尾巴·金币值·页签高亮同族账）")
		quit(0)
	else:
		print("容量帧刷新回归测试：失败 %d 项" % 红数)
		quit(1)
