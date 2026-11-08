extends SceneTree

## 写轮眼状态图标（用户 2026-10-21 报修 2.2「人物形象下的写轮眼境界小图标，有点太小了」）。
##
## 根因是**两条 AS3 线抄串了**。原版头顶那排状态图标每格都是 20×20 的 `Effect_CharStatus_Kuang`
## 底框 + 里面一件图标，但里面那件的缩放**一枚一个口径**：
##   · 忍术境界 `Character.setTotalSkillLevel:1890-1897` ⇒ `x = y = 10`、`scaleX = scaleY = 18/30`
##     （素材 30×30，缩到 18 ⇒ 在 20 的框里留一圈边）；
##   · 写轮眼 `Character.setXieLunYanState:2623-2643` ⇒ **只有** `_loc3_.x = _loc3_.y = 0`，
##     整段没有 `scaleX/scaleY`（素材本就是 20×20，跟底框一样大 ⇒ 撑满那一格）。
## 移植时把 18/30 也套到写轮眼上（旧注释还把出处写成 `Character.as:2645`，那是 `adjustHeights()`），
## 于是 20×20 的眼睛被压成 12×12 ⇒ 用户看到的「太小了」。
##
## 这条门钉六件事：
##   ① 行为：阶 6 画得出来，且 `scale == 1`、**绘制尺寸 = 底框尺寸**（撑满，不是小一圈）；
##   ② 摆位：原版摆在框的 (0,0) ⇒ 图标位置 == 底框位置（内缩 0，不是旧的 4）；
##   ③ 范围：`param1 > 1 && param1 <= 12` ⇒ 阶 1 不画、2 画、12 画、13 不画；
##   ④ 邻居：**忍术境界那枚仍然是 18/30**（防"顺手把两处都改成 1"，那条线是真缩放）；
##   ⑤ 字面：`_刷写轮眼图标` 函数体内不得再出现 `族徽边长 / 忍术境界原边长`，全文不得再引用 `2645`；
##   ⑥ 素材：`世界状态02..12` 十一张都在、每张 20×20（缩放的前提是原图 = 框尺寸）。
##
## 用法：Godot --headless --path . --script res://测试/写轮眼状态图标回归测试.gd

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 默认地图 := "101010000"
const 写轮眼状态图标 := "res://素材/界面/原版窗口/人物/血继界限/写轮眼状态/世界状态/世界状态%02d.png"
const 忍术境界图标 := "res://素材/特效/Effect_RenShuJingJie/Effect_RenShuJingJie_%d/1.png"

var _通过 := 0
var _失败: Array[String] = []


func _initialize() -> void:
	call_deferred("_跑")


func _判(条件: bool, 说明: String, 补: String = "") -> void:
	_通过 += 1
	if not 条件:
		_失败.append(说明 + ("　" + 补 if not 补.is_empty() else ""))


func _取(人物: Node, 名: String) -> Sprite2D:
	return 人物.get_node_or_null(名) as Sprite2D


func _画布尺寸(精灵: Sprite2D) -> Vector2:
	if 精灵 == null or 精灵.texture == null:
		return Vector2(-1, -1)
	return 精灵.texture.get_size() * 精灵.scale


func _摆(会话, 实体, 人物: Node, 阶: int) -> void:
	会话.set("cultivation_states", {"写轮眼": {"stage": 阶, "count": 0}})
	实体.call("_刷写轮眼图标")
	实体.call("_排状态图标排")


func _跑() -> void:
	root.size = Vector2i(960, 560)
	var 场景 := (load(地图资源.playable_scene_path(默认地图)) as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _帧 in range(5):
		await process_frame

	var 实体 := 场景.get_node_or_null("LifeRoot")
	if 实体 == null:
		_失败.append("拿不到 LifeRoot（地图实体）")
		_收尾()
		return
	var 会话 = root.get_node_or_null("GameSession")
	if 会话 == null:
		_失败.append("拿不到 GameSession")
		_收尾()
		return
	var 人物 := get_first_node_in_group("player") as Node2D
	if 人物 == null:
		_失败.append("拿不到 player 分组里的真身")
		_收尾()
		return

	var 原修行: Dictionary = (会话.get("cultivation_states") as Dictionary).duplicate(true)
	var 原技能: Array = 会话.get("learned_skills").duplicate(true)

	# ── ① 行为腿：阶 6 画得出来、且**撑满底框** ──────────────────────────
	_摆(会话, 实体, 人物, 6)
	await process_frame
	var 图 := _取(人物, "XieLunYanStateIcon")
	var 框 := _取(人物, "XieLunYanStateIconFrame")
	_判(图 != null, "① 阶 6 应画出 XieLunYanStateIcon")
	_判(框 != null, "① 阶 6 应画出底框 XieLunYanStateIconFrame")
	if 图 != null:
		_判(图.visible, "① 阶 6 那枚应当可见")
		_判(is_equal_approx(图.scale.x, 1.0) and is_equal_approx(图.scale.y, 1.0),
			"① 原版 setXieLunYanState 不缩放 ⇒ scale 应为 1", "实得 %s" % 图.scale)
		if 框 != null and 框.texture != null:
			var 画 := _画布尺寸(图)
			_判(is_equal_approx(画.x, 框.texture.get_size().x)
				and is_equal_approx(画.y, 框.texture.get_size().y),
				"① 眼睛应当**撑满**底框（旧口径 18/30 会缩成 12×12 ⇒ 用户报的「太小了」）",
				"图标 %s / 底框 %s" % [画, 框.texture.get_size()])
		_判(String(图.texture.resource_path).contains("世界状态06"),
			"① 阶 6 该贴 世界状态06.png", "实得 %s" % 图.texture.resource_path)
	if 图 != null and 框 != null:
		# ② 摆位：原版 `_loc3_.x = _loc3_.y = 0` ⇒ 图标与底框**同点**（旧代码内缩 4 是为了把 12×12 摆正）
		_判(is_equal_approx(图.position.x, 框.position.x)
			and is_equal_approx(图.position.y, 框.position.y),
			"② 图标应摆在底框的 (0,0)（内缩 0）",
			"图标 %s / 底框 %s" % [图.position, 框.position])
		_判(框.get_index() < 图.get_index(), "② 底框要排在图标前面（同级按树序绘制）")

	# ── ③ 阶范围：`param1 > 1 && param1 <= 12` ──────────────────────────
	for 项 in [[1, false], [2, true], [12, true], [13, false], [0, false]]:
		_摆(会话, 实体, 人物, int(项[0]))
		await process_frame
		var 有 = _取(人物, "XieLunYanStateIcon") != null
		_判(有 == bool(项[1]), "③ 阶 %d 应当%s" % [int(项[0]), "画" if bool(项[1]) else "不画"],
			"实际%s" % ("画了" if 有 else "没画"))
		if 项[1]:
			var 张 := _取(人物, "XieLunYanStateIcon")
			_判(张 != null and is_equal_approx(张.scale.x, 1.0),
				"③ 阶 %d 也不该被缩放" % int(项[0]),
				"实得 %s" % (Vector2.ZERO if 张 == null else 张.scale))
	# 阶 13 越界那张（世界状态13）本来就不存在，这里顺手确认"不画"不是靠缺图蒙对
	_摆(会话, 实体, 人物, 1)
	await process_frame

	# ── ④ 邻居腿：忍术境界那枚**仍然**是 18/30（`Character.as:1896-1897`）──
	# ⚠ 上面那轮范围测试把图标 free 掉过，这里重新长出来 ⇒ 引用得重取（旧变量指向已释放节点）。
	会话.set("learned_skills", [{"id": "0001000", "level": 100, "master_level": 0}] as Array[Dictionary])
	_摆(会话, 实体, 人物, 6)
	实体.call("_刷忍术境界图标")
	await process_frame
	图 = _取(人物, "XieLunYanStateIcon")
	框 = _取(人物, "XieLunYanStateIconFrame")
	var 境界 := _取(人物, "SkillJingJieIcon")
	_判(境界 != null, "④ 灌 100 层后应长出忍术境界图标（否则这条邻居腿根本没执行）")
	_判(图 != null, "④ 阶 6 的写轮眼图标应当又长出来了")
	if 境界 != null:
		_判(is_equal_approx(境界.scale.x, 18.0 / 30.0),
			"④ 忍术境界那枚**必须还是** 18/30（素材 30×30，那条线原版真缩）",
			"实得 %s" % 境界.scale)
		if 框 != null and 框.texture != null:
			var 境界画 := _画布尺寸(境界)
			_判(境界画.x < 框.texture.get_size().x,
				"④ 境界在框里应当**小一圈**（与写轮眼撑满形成对照）", "实得 %s" % 境界画)
	_判(境界 != null and 图 != null and 境界.position != 图.position,
		"④ 两枚在同排不同格（x = 20*序号），不该叠在同一个点上")

	# ── ⑤ 字面腿：假前提与旧缩放都得清掉 ────────────────────────────────
	var 文 := FileAccess.get_file_as_string("res://脚本/地图/地图实体.gd")
	var 起 := 文.find("func _刷写轮眼图标")
	_判(起 >= 0, "⑤ 找得到 `func _刷写轮眼图标`")
	if 起 >= 0:
		var 止 := 文.find("\nfunc ", 起 + 1)
		var 体 := 文.substr(起, 止 - 起 if 止 > 起 else -1)
		_判(not 体.contains("族徽边长 / 忍术境界原边长"),
			"⑤ 写轮眼函数体里不该再拿 `族徽边长 / 忍术境界原边长`（那是境界那枚的比例）")
		_判(体.contains("图节点.scale = Vector2.ONE"), "⑤ 写轮眼函数体里应显式写 `scale = Vector2.ONE`")
	_判(not 文.contains("`Character.as:2645`") and not 文.contains("Character.as:2645"),
		"⑤ 全文不得再把出处写成 `Character.as:2645`（那是 adjustHeights，假前提）")
	_判(文.contains("内缩\": 0.0"), "⑤ 排里写轮眼那格的 内缩 应为 0.0")
	# ⚠ 上面「阶 1 / 13 不画」那两条行为腿**单独靠这道闸是咬不住的**：01、13 两张图本来就没导出
	#    （见 ⑥ 那条），缺图分支先把图标收掉了 ⇒ 把 `阶 < 2 or 阶 > 12` 改成 `阶 < 1 or 阶 > 13`
	#    行为腿照样绿。所以范围这条只能靠字面钉（原版 `param1 > 1 && param1 <= 12`）。
	_判(文.contains("if 阶 < 2 or 阶 > 12:"),
		"⑤ 范围闸 `阶 < 2 or 阶 > 12` 必须还在（`setXieLunYanState:2632` 的 param1 > 1 && param1 <= 12）")

	# ── ⑥ 素材腿：缩放的前提是"原图 = 框尺寸" ───────────────────────────
	var 缺 := ""
	var 错尺 := ""
	for 阶 in range(2, 13):
		var 路 := 写轮眼状态图标 % 阶
		if not ResourceLoader.exists(路):
			缺 += "%d " % 阶
			continue
		var 张图 := load(路) as Texture2D
		if 张图 == null or 张图.get_size() != Vector2(20, 20):
			错尺 += "%d:%s " % [阶, "空" if 张图 == null else 张图.get_size()]
	_判(缺.is_empty(), "⑥ 世界状态02..12 十一张都得在盘上", "缺 %s" % 缺)
	_判(错尺.is_empty(), "⑥ 每张都应是 20×20（= 底框尺寸，不缩才撑满）", "实得 %s" % 错尺)
	_判(ResourceLoader.exists(忍术境界图标 % 0), "⑥ 对照组素材 Effect_RenShuJingJie_0 在盘上")
	# 01 / 13 两张**本来就没导出** ⇒ 这就是 ⑤ 那条范围字面腿存在的理由（行为腿会被缺图吸收）。
	_判(not ResourceLoader.exists(写轮眼状态图标 % 1) and not ResourceLoader.exists(写轮眼状态图标 % 13),
		"⑥ 01 / 13 应当不存在（与 ⑤ 的范围字面腿配对：缺图会吸收行为变异）")

	# ── ⑦ 摆位缝腿：没有家族牌时，整排锚在**名字牌原点**（= 名字行墨迹底 + 4）──
	# 用户 2026-10-22 报修 8 的另一半：原版 `Character.as:1501` `_statusIconPane.y = _namePane.y`
	# 取的是**牌原点**，而原点比该行墨迹底低 4 个像素行（`RoleNamePane.as:122/134/171/182`：
	# `paneHeight = textHeight + 10`、`_tf.y = _bg.y + 4`、TextField 自带 2px 内缩 ⇒ 10 − 6 = 4）。
	# 移植时把"底边"当成"墨迹底" ⇒ 缝 0 ⇒ 图标压字。4 这个数**手抄**在下面，不从产品码取。
	var 家族牌 := 人物.get_node_or_null("NameplateFamily") as Label
	var 名牌 := 人物.get_node_or_null("Nameplate") as Label
	if 名牌 == null:
		_判(false, "⑦ 真身没有 Nameplate —— 这条缝量不起来（判据不作数）")
	else:
		var 牌原可见: bool = 家族牌 != null and 家族牌.visible
		if 家族牌 != null:
			家族牌.visible = false
		实体.call("_排状态图标排")
		await process_frame
		var 名行高: float = 名牌.get_theme_font("font").get_height(名牌.get_theme_font_size("font_size"))
		var 缝框 := _取(人物, "XieLunYanStateIconFrame")
		_判(缝框 != null and is_equal_approx(缝框.position.y, 名牌.position.y + 名行高 + 4.0),
			"⑦ 收起家族牌后整排应锚在名字牌原点 = 名牌.y + 行高 + 4（手抄的那条缝）",
			"实得 %s（名牌.y=%s 行高=%f 期望 %f）" % [
				"无底框" if 缝框 == null else str(缝框.position), str(名牌.position.y),
				名行高, 名牌.position.y + 名行高 + 4.0])
		if 家族牌 != null:
			家族牌.visible = 牌原可见

	# 还原会话（别把假修行状态留给下一条门 / 落盘）
	会话.set("cultivation_states", 原修行)
	会话.set("learned_skills", 原技能)
	实体.call("_刷写轮眼图标")
	实体.call("_刷忍术境界图标")
	实体.call("_排状态图标排")
	await process_frame

	_收尾()


func _收尾() -> void:
	print("写轮眼状态图标回归：通过 %d 条，失败 %d 条" % [_通过, _失败.size()])
	for 条 in _失败:
		print("  ✗ " + 条)
	print("跑完了")
	quit(1 if not _失败.is_empty() else 0)
