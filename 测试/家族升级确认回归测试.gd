extends SceneTree
## 家族**升级二次确认**回归门（离线）：钉"点「确定」→ 弹确认弹 → 点「升级」→ 发协议并关窗"。
##
## 为什么单独立这条（§3.140，用户 2026-10-15 报"家族升级条件全部达成，点升级没反应"）：
##   真凶是**一颗钮上接了两条同样的动作** —— `家族子窗.gd:53` 早给所有带 `metadata/act` 的
##   TextureButton 统一接了 `_发动作(act)`；而 `家族升级填充` 又给「确定」接了一条
##   `_show_guild_action("家族升级窗:确定")`。点一次 ⇒ 同一個动作跑两遍：
##     第一遍：壳按开窗表把 `家族确认弹` 开出来；
##     第二遍：壳看它已经开着 ⇒ 按"再点同一个入口 = 收起"**当场关掉**。
##   ⇒ 弹窗开一下就没，玩家看到的就是"完全没反应"（协议其实从来没发出去）。
##   ⚠️ 这类 bug **离线门与在线门都抓不到**：在线门直接 `request_guild_upgrade_flag()`，
##     绕过了 UI；而 UI 这边两条接线各自都"是对的"。
##
## 本门钉三件事：
##   ① 点「确定」能开出确认弹（且**开着**，不被第二遍动作关掉）；
##   ② 「确定」钮上**只有一条** pressed 连接（双接线直接红）；
##   ③ 取消 → 再点确定还能再开；点「升级」后升级窗收掉（= 协议分支跑到了）。
##
## ⚠️ 这里用 `pressed.emit()` 而不是合成鼠标事件：headless 的 `Viewport.push_input`
##    不会派发到 GUI（拿壳的关钮实测，点了不关窗）⇒ 真点击在这类脚本里到不了按钮。
##    而"一条 pressed 上接了几条回调"正是要照的东西，emit 全部回调刚好对症。
##
## 用法：Godot --headless --path . --script res://测试/家族升级确认回归测试.gd

var _窗: CanvasLayer
var _失败: Array[String] = []


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 后端 := root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	if 后端 == null or 会话 == null:
		_失败.append("缺自动加载单例（BackendConnection / GameSession）")
		_收尾()
		return
	# 喂一份"条件全达成"的家族：服务端发过贡献帧（action 5）之后 authoritative_guild 里
	# 才会有 fund/materials 这两个键（升级窗读的是后端这份，不是 会话.guild）。
	var 族 := {"joined": true, "name": "44", "level": 2, "leader": "115", "fund": 20000,
		"materials": {"16000023": 99, "16000024": 99, "16000025": 99, "16000026": 99},
		"flag_style": 1000}
	(会话 as Node).set("guild", 族)
	(后端 as Node).set("authoritative_guild", 族.duplicate(true))
	(后端 as Node).set("in_game", true)
	_窗 = (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate() as CanvasLayer
	root.add_child(_窗)
	await process_frame
	await process_frame

	# ① 开升级窗（= 底栏「家族升级」那颗钮）
	_窗.call("_show_guild_action", "家族升级")
	await process_frame
	await process_frame
	var 升 := _内容("家族子窗_家族升级窗")
	if 升 == null:
		_失败.append("「家族升级」没开出升级窗")
		_收尾()
		return
	var 文 := 升.get_node_or_null("文本升级说明") as RichTextLabel
	if 文 == null or not 文.text.contains("20000 / 666"):
		_失败.append("升级窗没填家族资金行（后端 authoritative_guild 没喂对？）：%s"
			% (文.text if 文 else "<无节点>"))
	var 确定 := 升.get_node_or_null("钮确定") as TextureButton
	if 确定 == null:
		_失败.append("升级窗里没有「钮确定」")
		_收尾()
		return
	if 确定.disabled:
		_失败.append("条件全够但「确定」是灰的（经济已知且资金/材料都够时不该禁用）")
	# ② 双接线直接红（§3.140 的正主）：带 metadata/act 的钮只该有子窗那一条通用接线
	var 接线数 := 确定.pressed.get_connections().size()
	if 接线数 != 1:
		_失败.append("「确定」上接了 %d 条 pressed（应只有子窗通用接线那 1 条）—— "
			% 接线数 + "多一条就等于把确认弹开一下又关掉，玩家看来就是「点了没反应」")
	# ③ 点「确定」⇒ 确认弹开出来且**开着**
	_点(确定)
	await process_frame
	await process_frame
	var 弹 := _内容("家族子窗_家族确认弹")
	if 弹 == null:
		_失败.append("点「确定」没弹出确认弹（或弹出后又被同帧的第二遍动作关掉）")
	else:
		var 正 := 弹.get_node_or_null("文本正文") as RichTextLabel
		if 正 == null or not 正.text.contains("你确定要升级吗？"):
			_失败.append("确认弹正文不对：%s" % (正.text if 正 else "<无 文本正文 节点>"))
		var 弹钮 := 弹.get_node_or_null("钮确定") as TextureButton
		if 弹钮 == null:
			_失败.append("确认弹里没有「钮确定」")
		elif 弹钮.get_index() >= 0:
			var 字 := 弹钮.get_node_or_null("Label") as Label
			if 字 == null or 字.text != "升级":
				_失败.append("确认弹的确定钮文字该是「升级」，实为 %s" % (字.text if 字 else "<空>"))
	# ④ 取消 ⇒ 收起；再点一次确定 ⇒ 还能再开（玩家最自然的动作序列）
	_窗.call("_show_guild_action", "家族确认弹:取消")
	await process_frame
	await process_frame
	if _内容("家族子窗_家族确认弹") != null:
		_失败.append("点「取消」没收起确认弹")
	_点(确定)
	await process_frame
	await process_frame
	if _内容("家族子窗_家族确认弹") == null:
		_失败.append("再点一次「确定」开不出确认弹（收起过一次就废了？）")
	# ⑤ 点确认弹的「升级」⇒ 分支跑到（升级窗被关掉）+ 不报错
	var 弹2 := _内容("家族子窗_家族确认弹")
	if 弹2 != null:
		_点(弹2.get_node_or_null("钮确定") as TextureButton)
		await process_frame
		await process_frame
		if _内容("家族子窗_家族升级窗") != null:
			_失败.append("点「升级」后升级窗没关（`家族确认弹:确定` 分支没跑到）")
	_收尾()


## 取某扇子窗的**内容页**（壳的孩子里第一个非「窗壳」的就是内容；无壳的窗内容就是唯一孩子）。
func _内容(根名: String) -> Control:
	var 遮罩 := _窗.get_node_or_null("遮罩") as Control
	if 遮罩 == null:
		return null
	var 根 := 遮罩.get_node_or_null(根名) as Control
	if 根 == null:
		return null
	for 子 in 根.get_children():
		if String(子.name) == "窗壳":
			continue
		return 子 as Control
	return null


## 点一颗钮 = 把它 pressed 上接的**所有**回调都跑一遍（等价于玩家点一次）。
func _点(钮: TextureButton) -> void:
	if 钮 != null:
		钮.pressed.emit()


func _收尾() -> void:
	for 条 in _失败:
		print("  !! " + 条)
	if _失败.is_empty():
		print("家族升级确认回归测试：通过（确定→确认弹→取消→再开→升级发协议并关窗；确定钮仅 1 条接线）")
		quit(0)
	else:
		print("家族升级确认回归测试：FAIL %d 条" % _失败.size())
		quit(1)
