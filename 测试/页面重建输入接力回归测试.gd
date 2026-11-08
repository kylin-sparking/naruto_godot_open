extends SceneTree

## 页面重建时的**输入接力**回归门（2026-10-18，用户实机报修「商城搜索框搜不了」）。
##
## 病根不是搜索那条协议 —— 是**页面活得太短**：`功能窗口._refresh_current()` 挂了十几个信号
## （`player_stats_changed` / `inventory_changed` / `social_changed` / `equipment_changed`…），
## 随便一条回帧就 `_render_page()` ⇒ 把 `_content` 下的整棵页面 `remove_child` + `queue_free`
## 再按 `.tscn` 重建。于是玩家正在打字的那枚 `LineEdit` **被换成了一枚新的**：
##   · 字没了（新的那枚按窗口上记的旧值重新种一遍）；
##   · 焦点也没了（控件被移出树时 Godot 直接丢焦点）—— 接着敲键盘打到的是别处。
## 实机表现就是"点进去打两个字就没了 / 根本打不进去"，看起来像"搜索框坏了"。
## 同一类毛病本工程已经记过两次账：滚动位置（§3.40，`_shop_scroll`）、结印自动提升（§3.193）——
## **凡是页面上的临时状态都必须存在窗口上**，这条门把"输入"也钉进同一条规矩。
##
## 盯五件：
##   ① 打字 ⇒ 立刻进窗口上的**草稿**（`_商城搜索草稿`）：框自己活不过一帧，只有宿主记得住；
##   ② **正聚焦着**来一条状态帧 ⇒ 文本、焦点、光标列**三样都接回新的那枚**（`_记输入焦点` / `_放输入接力`）；
##   ③ **已经点了别处**（焦点早没了）再来状态帧 ⇒ 字仍然在框里（靠 ① 的草稿种回来，接力只是补焦点）；
##   ④ 点「搜索」把草稿提交成 `_shop_query`，且**不许**误报「请输入道具名称」；
##   ⑤ 点**页签** ⇒ 已提交的 `_shop_query` 要清掉（原版 `isSearch = false`），但框里玩家打的字要留着。
##
## ⚠ 三条口径：
##   · **程序赋值 `框.text = …` 不发 `text_changed`**（本门实测：Godot 4.7 里赋值后 `text_changed`
##     一次都没收到）。真键入一定发 ⇒ 模拟打字要"赋值 + 补 emit"两步一起做，只赋值会漏测 ①。
##   · 本门走 `call_deferred` 才让宿主的 `_ready` 跑得起来（§3.124.4）；
##   · **不碰真链路**：全程离线，`_refresh_current` 直接由门来调（等价于"服务端来了一条状态帧"）。
##
## 运行：`Godot --headless --path . --script res://测试/页面重建输入接力回归测试.gd`

const 窗场景路径 := "res://场景/界面/功能窗口.tscn"

var 红数 := 0
var _秒 := 0.0


## 看门狗：`_跑` 里出运行时错误会当场断、**永不 quit** ⇒ 无头进程挂死且不红（§3.113）。
func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 90.0:
		printerr("页面重建输入接力回归测试：看门狗超时（90s）—— 中途崩了没走到收尾")
		quit(1)
		return true
	return false


func _记(过: bool, 文: String) -> void:
	if not 过:
		红数 += 1
		print("!! " + 文)


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)
	var 场: Node = (load(窗场景路径) as PackedScene).instantiate()
	root.add_child(场)
	await process_frame
	await process_frame

	var 内容 := 场.get("_content") as Control
	var 会话 := root.get_node_or_null("GameSession")
	if 内容 == null or 会话 == null:
		_记(false, "依赖不齐：_content=%s GameSession=%s" % [内容, 会话])
		_finish()
		return

	场.call("open_page", "商城")
	await process_frame
	var 框 := _找(内容, "搜索词") as LineEdit
	if 框 == null:
		_记(false, "商城页里没有「搜索词」输入框（后面三条判据都做不了）")
		_finish()
		return
	# ① 接线：`text_changed` 上必须挂着"写回窗口草稿"的那条 lambda
	_记(框.text_changed.get_connections().size() >= 1,
			"「搜索词」的 text_changed 没接任何东西 —— 玩家打的字只存在框自己身上，重建即丢")

	# ① 打字 ⇒ 草稿进窗口（赋值不发信号，所以补 emit 才等于真键入）
	框.text = "幸运符"
	框.text_changed.emit("幸运符")
	_记(String(场.get("_商城搜索草稿")) == "幸运符",
			"打了字但窗口上的 _商城搜索草稿 = %s（应当是「幸运符」）" % str(场.get("_商城搜索草稿")))

	# ② 正聚焦着来一条状态帧 ⇒ 文本 / 焦点 / 光标 三样都接回
	框.grab_focus()
	框.caret_column = 2
	_记(root.gui_get_focus_owner() == 框, "前置没做好：搜索框没拿到焦点（实测 %s）" % str(root.gui_get_focus_owner()))
	场.call("_refresh_current")
	await process_frame
	await process_frame
	var 新框 := _找(内容, "搜索词") as LineEdit
	_记(新框 != null and 新框 != 框, "页面上没换出新的搜索框（这条腿就没测到重建）—— 新=%s 旧=%s" % [新框, 框])
	if 新框 == null:
		_finish()
		return
	_记(新框.text == "幸运符",
			"重建把玩家刚打的字冲掉了：搜索框现在是「%s」（原版根本没有「回帧就重开页面输入」这回事）" % 新框.text)
	_记(root.gui_get_focus_owner() == 新框,
			"重建后焦点丢了（玩家接着敲的就是键盘全局快捷键，不是往框里打字）—— 实测 %s" % str(root.gui_get_focus_owner()))
	_记(新框.caret_column == 2,
			"重建后光标没接回第 2 列（实测 %d）—— 打字会跳到末尾，中间改字改不了" % 新框.caret_column)

	# ③ 焦点早就点在别处了（现实里更常见：打完字去翻页/滚动）⇒ 字仍要在，靠的是窗口上的草稿
	新框.release_focus()
	await process_frame
	场.call("_refresh_current")
	await process_frame
	await process_frame
	var 再新 := _找(内容, "搜索词") as LineEdit
	_记(再新 != null and 再新.text == "幸运符",
			"失焦之后再重建，框里的字没了（实测 %s）—— 只靠焦点接力不够，草稿必须种回控件" % str(再新))
	_记(再新 != null and root.gui_get_focus_owner() != 再新,
			"玩家明明点了别处，重建却把焦点抢回搜索框（打字会打进框里，全局快捷键全废）")

	# ④ 点「搜索」⇒ 草稿提交成 `_shop_query`，且不许误报「请输入道具名称」
	var 提示: Array[String] = []
	会话.notification_requested.connect(func(文: String) -> void: 提示.append(文))
	var 按钮 := _找(内容, "搜索") as Button
	if 按钮 == null:
		_记(false, "商城页里没有「搜索」按钮，④ 做不了")
	else:
		按钮.pressed.emit()
		await process_frame
		await process_frame
		_记(String(场.get("_shop_query")) == "幸运符",
				"点了「搜索」但 _shop_query = %s（应当提交框里的「幸运符」）" % str(场.get("_shop_query")))
		var 有误报 := false
		for 文 in 提示:
			if 文.contains("请输入道具名称"):
				有误报 = true
		_记(not 有误报, "框里明明有字，点搜索却提示「请输入道具名称」：%s" % str(提示))
		# 搜索之后框里还得留着那三个字（原版 `keywordsText` 不会因为发过一次搜索就清空）
		var 搜后 := _找(内容, "搜索词") as LineEdit
		_记(搜后 != null and 搜后.text == "幸运符",
				"点完搜索框被清空（实测 %s）—— 玩家想改两个字再搜一次就得重打" % str(搜后))
	# ⑤ 切页签 ⇒ 上次**提交**的搜索词要清掉（原版 `CashShopWindow2.as:429-437 __onTabClick`
	#    第一句就是 `isSearch = false`，切页签发的是**按类目**的 432 而不是 433），
	#    但**框里的字要留着**（原版 `keywordsText.text` 不动 —— `isSearch` 只管"这一跳发不发搜索"）。
	#    不清的话：搜过一次之后再点页签，看到的还是上次那批搜索结果，玩家看就是"页签切不动"。
	var 页签1 := _找(内容, "页签1") as Button
	if 页签1 == null:
		_记(false, "商城页里没有「页签1」，⑤ 做不了")
	else:
		_记(String(场.get("_shop_query")) == "幸运符",
				"⑤ 前置不对：点了「搜索」之后 _shop_query = %s" % str(场.get("_shop_query")))
		页签1.pressed.emit()
		await process_frame
		await process_frame
		_记(String(场.get("_shop_query")).is_empty(),
				"⑤ 切页签没清掉上次的搜索词（还是「%s」）—— 这一跳发出去的还是 433 搜索，页签看着像切不动"
					% str(场.get("_shop_query")))
		_记(int(场.get("_shop_tab")) == 1,
				"⑤ 点了页签1 但 _shop_tab = %s（这腿什么都没测到）" % str(场.get("_shop_tab")))
		var 切后 := _找(内容, "搜索词") as LineEdit
		_记(切后 != null and 切后.text == "幸运符",
				"⑤ 切页签把框里玩家打的字也一起清了（实测 %s）—— 原版只清 isSearch，不清 keywordsText"
					% str(切后.text if 切后 != null else "<无框>"))
	for 连 in 会话.notification_requested.get_connections():
		会话.notification_requested.disconnect(连["callable"])

	_finish()


## 按名字在子树里找控件（页面是整棵换掉的，只能事后重新定位）。
func _找(根节点: Node, 名: String) -> Node:
	for 子 in 根节点.get_children():
		if String(子.name) == 名:
			return 子
		var 深 := _找(子, 名)
		if 深 != null:
			return 深
	return null


func _finish() -> void:
	if 红数 == 0:
		print("页面重建输入接力回归测试：通过（打字进窗口草稿 / 重建接回文本+焦点+光标 / "
				+ "失焦后靠草稿种回 / 点搜索提交且不抢回焦点 / 切页签清已提交搜索词）")
		quit(0)
	else:
		print("页面重建输入接力回归测试：失败 %d 项" % 红数)
		quit(1)
