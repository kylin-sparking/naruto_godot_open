extends SceneTree

## A2 状态图标自检 ③ + 10-25 buff 排返工：HUD 状态格必须等于原版 `BuffCell` 那一套。
##
## 真值出处（`as3/com/mxw/uifl/controls/BuffPane.as` / `BuffCell.as`，全表见
## `真值/系统/Buff状态图标.md`）：
##   ① 容器 (260,0)，6 列、步距 41（40 格 + 1 分隔），共 18 格
##   ② 每格三层：MGrid_background（symbol172，40×40，半透明）+ 图标（不缩放）+ 冷却扇形
##   ③ 图标落点：skillId/1000000 >= 9 ⇒ 居中；带 `pos` ⇒ (0,0)；否则 (3,3)
##   ④ 顺序 = 首次到达序（同 (type, skillId) 只更新、不挪位）
##   ⑤ 1811 系统双倍 = `Buff/System/<type>`、skillId 10000000+type、永久无扇形
##   ⑥ 有限时长 ⇒ 扇形 progress = 已过/总；永久 ⇒ 不建扇形
##
## 用法：Godot --headless --path . --script res://测试/状态图标回归测试.gd

const 头像面板脚本 := preload("res://脚本/界面/头像面板.gd")
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
const 格底路 := "res://素材/界面/原版窗口/通用控件/状态格底.png"
const 家徽路 := "res://素材/界面/原版窗口/家族/家徽_1000.png"

var _失败: Array[String] = []
var _断言数 := 0

func _initialize() -> void:
	call_deferred("_跑")

func _记(条件: bool, 话: String) -> void:
	_断言数 += 1
	if not 条件:
		_失败.append(话)


## 取格子里那枚图标的贴图路径；**贴图为空时返回空串**。
## ⚠ 不能写 `图件.texture.resource_path`：变异体下图标本来就该是空的，
##   空引用会让整条协程静默中止 ⇒ 门不红而是**挂到超时**（本门踩过一次）。
static func _贴图路(图件: TextureRect) -> String:
	if 图件 == null or 图件.texture == null:
		return ""
	return String(图件.texture.resource_path)

func _跑() -> void:
	var 表: Dictionary = GAME_DATA.取表("状态图标").get("表", {}) as Dictionary
	if 表.is_empty():
		_fail_and_quit("数据/状态图标.json 是空的（导出坏了？）")
		return
	# ① 每一行的贴图都得在盘上；`备注` 说明"原版这行本来没 icon"的除外（crimeA~S 四行）
	for 键 in 表:
		var 行: Dictionary = 表[键] as Dictionary
		var 路径 := String(行.get("贴图", ""))
		if 路径.is_empty():
			_记(not String(行.get("备注", "")).is_empty(),
				"%s 没有贴图路径，也没有「原版无图」的备注" % 键)
			continue
		_记(ResourceLoader.exists(路径), "%s 的贴图不在盘上：%s" % [键, 路径])
	var 物品表: Dictionary = GAME_DATA.取表("状态图标").get("物品Buff", {}) as Dictionary
	for 编号 in 物品表:
		var 路径 := String((物品表[编号] as Dictionary).get("贴图", ""))
		if not 路径.is_empty():
			_记(ResourceLoader.exists(路径), "BuffWuPin/%s 的贴图不在盘上：%s" % [编号, 路径])
	_记(ResourceLoader.exists(格底路), "格底素材不在盘上：%s" % 格底路)

	# ② 真把面板建出来
	var 面板 := (load("res://场景/界面/头像面板.tscn") as PackedScene).instantiate()
	root.add_child(面板)
	await process_frame
	var 格子: Array = 面板.get("_status_slots")
	if 格子.is_empty():
		_fail_and_quit("头像面板没收到状态格")
		return
	_记(格子.size() == 18, "状态格应为原版的 18 格（6 列），实为 %d" % 格子.size())
	var 提示 := 面板.get_node_or_null("头像区域/buff提示框")
	_记(提示 != null, "头像面板没建出 buff 提示框（原版 MToolTipTextWithTitle）")

	# ②b 容器摆位 = 头像面板宽度 260、y=0；6 列 / 步距 41（40+1）
	var 容器 := 面板.get_node_or_null("头像区域/状态效果") as GridContainer
	_记(容器 != null, "缺 头像区域/状态效果 容器")
	if 容器 != null:
		# 判**屏幕位**（原版 `BuffPane.x = charactorInfoPane.width = 260`、y=0）。
		# ⚠ 不能判 `容器.position`：它的父节点 `头像区域` 自己带 (1,-4) 的整块补偿。
		var 屏位 := 容器.get_global_rect().position
		_记(屏位 == Vector2(260, 0), "状态排屏幕位应为 (260,0)，实为 %s" % str(屏位))
		_记(容器.columns == 6, "状态排应为 6 列，实为 %d" % 容器.columns)
		_记(容器.get_theme_constant("h_separation") == 1,
			"列间距应为 1（原版步距 41 = 40 + 1），实为 %d" % 容器.get_theme_constant("h_separation"))
	# ②c 每格 = 格底 + 图标 + 扇形
	for i in 格子.size():
		var 格 := 格子[i] as TextureRect
		_记(格.custom_minimum_size == Vector2(40, 40), "第 %d 格不是 40×40" % i)
		_记(格.texture != null and String(格.texture.resource_path) == 格底路,
			"第 %d 格的底不是 symbol172 那张：%s" % [i, 格.texture.resource_path if 格.texture != null else "（空）"])
		var 图件 := 格.get_node_or_null("图标") as TextureRect
		var 扇 := 格.get_node_or_null("扇形") as ColorRect
		_记(图件 != null, "第 %d 格缺 图标 子节点" % i)
		_记(扇 != null, "第 %d 格缺 冷却扇形 子节点" % i)
		if 扇 != null:
			var 材 := 扇.material as ShaderMaterial
			_记(材 != null, "第 %d 格的扇形没有 ShaderMaterial" % i)
			if 材 != null:
				_记(is_equal_approx(float(材.get_shader_parameter("cover_alpha")), 0.4),
					"第 %d 格扇形 alpha 应为 0.4（GirdCool(0,0.4,…)）" % i)
		_记(格.mouse_filter != Control.MOUSE_FILTER_IGNORE,
			"第 %d 格是 IGNORE，悬停提示永远弹不出来" % i)

	# ③ 天气 0..9：图 = 表里那张、标题/描述、居中、永久无扇形
	for 级别 in 10:
		var 期望: Dictionary = 表.get("Weather/%d" % 级别, {}) as Dictionary
		if 期望.is_empty():
			_记(false, "表里没有 Weather/%d" % 级别)
			continue
		面板.call("_render_status_effects", 级别, [], [])
		var 格 := 格子[0] as TextureRect
		var 图件 := 格.get_node_or_null("图标") as TextureRect
		_记(bool(格.visible), "天气 %d 没渲染出格子" % 级别)
		if 图件 == null:
			continue
		_记(图件.texture != null and String(图件.texture.resource_path) == String(期望.get("贴图", "")),
			"天气 %d 画的不是表里那张：%s" % [级别, 图件.texture.resource_path if 图件.texture != null else "（空）"])
		# 9000201+n / 1000000 = 9 ⇒ 40×40 图标居中 ⇒ (0,0)
		_记(Vector2(图件.position) == Vector2.ZERO, "天气 %d 图标应居中于 (0,0)，实为 %s" % [级别, str(图件.position)])
		_记(Vector2(图件.size) == Vector2(40, 40), "天气 %d 图标被缩放了：%s" % [级别, str(图件.size)])
		var 扇 := 格.get_node_or_null("扇形") as ColorRect
		_记(扇 != null and not 扇.visible, "天气 %d 是永久格，不该有冷却扇形" % 级别)
		var 条: Dictionary = (面板.get("_状态提示") as Array)[0] as Dictionary
		_记(String(条.get("title", "")) == String(期望.get("名称", "")),
			"天气 %d 提示标题错：`%s`（原版是 `%s`）" % [级别, 条.get("title", ""), 期望.get("名称", "")])
		_记(String(条.get("desc", "")) == String(期望.get("说明", "")),
			"天气 %d 提示描述错：`%s`" % [级别, 条.get("desc", "")])
		if 提示 != null:
			面板.call("_显示状态提示", 0)
			var 题 := 提示.get_node_or_null("标题") as RichTextLabel
			var 文 := 提示.get_node_or_null("文") as RichTextLabel
			_记(bool((提示 as Control).visible), "天气 %d 悬停后提示框没显示" % 级别)
			if 题 != null:
				_记(题.text.contains(String(期望.get("名称", ""))), "天气 %d 提示框标题没写进原版组件" % 级别)
			if 文 != null:
				_记(文.text.contains(String(期望.get("说明", ""))), "天气 %d 提示框描述没写进原版组件" % 级别)
			面板.call("_收起状态提示")

	# ④ 查不到的图标：留空格子、不顶图（原版 BuffCell 没有兜底图）
	面板.call("_render_status_effects", -1, [{"name": "无图状态", "icon": "res://不存在/图.png"}], [])
	var 首格 := 格子[0] as TextureRect
	var 首图 := 首格.get_node_or_null("图标") as TextureRect
	_记(首图 != null and 首图.texture == null, "图标查不到却被顶上了别的图")
	var 首条: Dictionary = (面板.get("_状态提示") as Array)[0] as Dictionary
	_记(bool(首格.visible) and String(首条.get("title", "")) == "无图状态",
		"无图状态应当留一个带名字的空格子（visible=%s title=%s）"
			% [str(首格.visible), 首条.get("title", "")])

	# ⑤ 图标落点三档（`BuffCell.as:251-270`）
	_记(Vector2(头像面板脚本._图标偏移(9000001, Vector2(40, 40), false)) == Vector2.ZERO,
		"40×40 技能图（9000001）应居中 (0,0)")
	_记(Vector2(头像面板脚本._图标偏移(0, Vector2(34, 34), false)) == Vector2(3, 3),
		"34×34 家徽图（skillId 0）应落在 (3,3)")
	_记(Vector2(头像面板脚本._图标偏移(12, Vector2(34, 34), true)) == Vector2.ZERO,
		"结印那种带 pos 的图标应落在 (0,0)")
	_记(Vector2(头像面板脚本._图标偏移(10000000, Vector2(40, 40), false)) == Vector2.ZERO,
		"系统双倍（10000000+type）应居中")

	# ⑥ 有限时长 ⇒ 扇形；永久 ⇒ 没有
	var 道具图 := 家徽路
	var 现在 := Time.get_ticks_msec()
	面板.call("_render_status_effects", -1, [], [{
		"kind": "shuxing", "item_id": 16000001, "effect_key": "attribute_boost:16000001",
		"name": "测试药剂", "desc": "测试", "icon": 道具图,
		"remaining_seconds": 570, "total_seconds": 600, "received_at_msec": 现在 - 30000,
	}])
	var 药格 := 格子[0] as TextureRect
	var 药扇 := 药格.get_node_or_null("扇形") as ColorRect
	var 药图 := 药格.get_node_or_null("图标") as TextureRect
	_记(药扇 != null and 药扇.visible, "限时道具格应有冷却扇形")
	if 药扇 != null and 药扇.visible:
		var 材 := 药扇.material as ShaderMaterial
		var 进度 := float(材.get_shader_parameter("progress")) if 材 != null else -1.0
		_记(absf(进度 - 0.05) < 0.02, "扇形进度应为 已过/总 ≈ 0.05，实为 %.3f" % 进度)
	_记(药图 != null and Vector2(药图.position) == Vector2(3, 3), "34×34 道具图应落在 (3,3)")
	var 药条: Dictionary = (面板.get("_状态提示") as Array)[0] as Dictionary
	_记(int(药条.get("total", 0)) == 600, "道具提示的总量应为 600 秒，实为 %s" % str(药条.get("total", 0)))

	# ⑦ 1811 系统双倍：**从服务端那条文本帧走整条链**（opcode 分派 → 信号 → 会话 → HUD）。
	#    不能直接调 `_on_backend_system_buff` —— 那样把"信号有没有接上"整段跳过了（变异实测抓不到）。
	var 会话 := root.get_node_or_null("GameSession")
	var 后端 := root.get_node_or_null("BackendConnection")
	if 会话 == null or 后端 == null:
		_记(false, "缺 GameSession / BackendConnection 自动加载（1811 整条链做不了）")
	else:
		后端.call("_handle_bridge_text", "1811:0:0:1.5:600:1200")
		后端.call("_handle_bridge_text", "1811:0:1:1.5:300:600")
		var 列: Array = 会话.get("hud_state").get("buffs", []) as Array
		var 系: Array = []
		for 条 in 列:
			if String((条 as Dictionary).get("kind", "")) == "system":
				系.append(条)
		_记(系.size() == 2, "系统双倍应出 2 格，实为 %d" % 系.size())
		if 系.size() == 2:
			_记(String((系[0] as Dictionary).get("icon", "")) == String((表.get("System/0", {}) as Dictionary).get("贴图", "")),
				"系统双倍 0 的图标不是 Buff/System/0")
			_记(int((系[1] as Dictionary).get("skill_id", 0)) == 10000001,
				"系统双倍 1 的 skillId 应为 10000001")
		# 先到先排：系统 0/1 早于天气 ⇒ 它们占第 0/1 格，天气第 2 格
		面板.call("_render_status_effects", 9, 系, [])
		var 第0 := 格子[0] as TextureRect
		var 第1 := 格子[1] as TextureRect
		var 第2 := 格子[2] as TextureRect
		var 图0 := 第0.get_node_or_null("图标") as TextureRect
		var 图1 := 第1.get_node_or_null("图标") as TextureRect
		var 图2 := 第2.get_node_or_null("图标") as TextureRect
		_记(_贴图路(图0) == String((表.get("System/0", {}) as Dictionary).get("贴图", "")),
			"第 0 格应为系统双倍经验")
		_记(_贴图路(图1) == String((表.get("System/1", {}) as Dictionary).get("贴图", "")),
			"第 1 格应为系统双倍精华")
		_记(_贴图路(图2) == String((表.get("Weather/9", {}) as Dictionary).get("贴图", "")),
			"天气后到，应排在第 2 格（原版按到达序，不按类别）")
		# 收掉 type 0 只影响那一格
		后端.call("_handle_bridge_text", "1811:1:0")
		var 列2: Array = 会话.get("hud_state").get("buffs", []) as Array
		var 剩 := 0
		for 条 in 列2:
			if String((条 as Dictionary).get("kind", "")) == "system":
				剩 += 1
		_记(剩 == 1, "1811 cmd=1 只应收掉 type 0，实剩 %d 格" % 剩)
		后端.call("_handle_bridge_text", "1811:1:1")

	# ⑧ 顺序 = 首次到达序：先只喂 A，隔一帧再喂 **B 在前、A 在后**，
	#    若按列表序 B 会抢到第 0 格；按到达序则 A 仍在第 0 格。
	面板.call("_render_status_effects", -1, [], [])
	var A := {"kind": "shuxing", "item_id": 1, "effect_key": "a", "name": "甲", "icon": 家徽路,
		"remaining_seconds": 100, "total_seconds": 100, "received_at_msec": Time.get_ticks_msec()}
	var B := {"kind": "shuxing", "item_id": 2, "effect_key": "b", "name": "乙", "icon": 家徽路,
		"remaining_seconds": 100, "total_seconds": 100, "received_at_msec": Time.get_ticks_msec()}
	面板.call("_render_status_effects", -1, [], [A])
	await process_frame
	await process_frame
	面板.call("_render_status_effects", -1, [], [B, A])
	var 序条0: Dictionary = (面板.get("_状态提示") as Array)[0] as Dictionary
	var 序条1: Dictionary = (面板.get("_状态提示") as Array)[1] as Dictionary
	_记(String(序条0.get("title", "")) == "甲", "先到的甲应还在第 0 格，实为 `%s`" % 序条0.get("title", ""))
	_记(String(序条1.get("title", "")) == "乙", "后到的乙应排第 1 格，实为 `%s`" % 序条1.get("title", ""))

	_收尾()

func _fail_and_quit(话: String) -> void:
	print("  FAIL " + 话)
	print("状态图标回归测试：1 项不通过")
	quit(1)

func _收尾() -> void:
	if _失败.is_empty():
		print("状态图标回归测试：%d 项断言全部通过（18 格 / 三档落点 / 到达序 / 1811 / 扇形）" % _断言数)
		quit(0)
		return
	for 条 in _失败:
		print("  FAIL " + 条)
	print("状态图标回归测试：%d/%d 项不通过" % [_失败.size(), _断言数])
	quit(1)
