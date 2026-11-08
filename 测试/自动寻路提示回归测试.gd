## 「自动寻路中．．．」这条顶部提示的形状门。
##
## 为什么要有这一把（2026-10-09，用户录的原版任务流程视频逼出来的）
## ---------------------------------------------------------------
## 原版每次**自动赶路**（点追踪栏、点对话里那行绿字、点小地图、跨图赶门）都会在舞台
## 顶部中央常驻一条 `Effect_PathFindingTip`，走完才摘。本工程**图早就在盘上、
## `数据/特效.json` 里也早就有条目，但全工程没有一处 .gd 播它** ⇒ 门是绿的、玩家看到的是"人自己走了，
## 屏幕上什么都不说"。这正是"流程没有灵魂"里最响的一条。
##
## 本门钉三层，少任一条都会假绿：
##   ① **数据层**：注册点/周期/段数/四张图两两不同 —— 注册点是 `出任务标记特效.py` 从
##      `Effect_PathFindingTip.swf` 的 shapeBounds 现读的，不许退回 [0,0] 那种占位；
##   ② **状态层**（`玩家.gd`）：`走向` 带 `自动` 参、路线起来才置真、`cancel_auto_path`
##      与"路线走完"两条收尾都要置假；
##   ③ **调用点层**：该亮的四处都真传了 true，**不该亮的两处**（鼠标点地走、战斗自动接近）
##      不许被顺手改成 true —— 原版 `World.as:392` 不传 showtip，手动点一下也亮就是自造。
extends SceneTree

var _失败: Array[String] = []
var _条数 := 0


func _initialize() -> void:
	call_deferred("_run")


func _断言(成立: bool, 说明: String) -> void:
	_条数 += 1
	if not 成立:
		_失败.append(说明)


func _读(路: String) -> String:
	return FileAccess.get_file_as_string(路)


func _截段(文: String, 起: String, 止: String) -> String:
	var a := 文.find(起)
	if a < 0:
		return ""
	var b := 文.find(止, a + 起.length())
	return 文.substr(a, b - a) if b > 0 else 文.substr(a)


func _run() -> void:
	## ──  数据层 ──────────────────────────────────────────────────────────
	var 表: Variant = JSON.parse_string(_读("res://数据/特效.json").trim_prefix("\ufeff"))
	_断言(typeof(表) == TYPE_DICTIONARY, "数据/特效.json 读不出来")
	if typeof(表) != TYPE_DICTIONARY:
		_finish()
		return
	var 条: Dictionary = (表.get("特效", {}) as Dictionary).get("Effect_PathFindingTip", {}) as Dictionary
	_断言(not 条.is_empty(), "特效.json 里没有 Effect_PathFindingTip")
	if 条.is_empty():
		_finish()
		return
	var 帧: Array = 条.get("帧", []) as Array
	_断言(int(条.get("时间轴帧", 0)) == 40, "时间轴应 40 帧（MCFromDatDefine.as:244-250 写死 frameCount=40），实际 %s" % str(条.get("时间轴帧", 0)))
	_断言(int(条.get("每帧ms", 0)) == 25, "每帧应 25ms（KeyController.as:787 fps=40 ⇒ 1000/40），实际 %s" % str(条.get("每帧ms", 0)))
	var 总 := 0
	for f in 帧:
		总 += int((f as Dictionary).get("停留ms", 0))
	_断言(总 == 1000, "整圈应 1000ms（40×25），实际 %d ⇒ 省略号节奏会和原版不同" % 总)
	_断言(帧.size() == 4, "40 帧时间轴应压成 4 段唯一帧，实际 %d 段" % 帧.size())
	var 画: Array = 条.get("画布", []) as Array
	_断言(画.size() == 2 and int(画[0]) == 257 and int(画[1]) == 43,
			"画布应为 257x43（ffdec 原样画布，不许自己裁），实际 %s" % str(画))
	var 原: Array = 条.get("注册点", []) as Array
	## 注册点 [105, 45] 的 y **在画布之外**（45 > 43）—— 这不是算错：形状框 y 上界是 −2，
	## 字形整体坐在锚点上方 2px。所以这条要连形状框一起钉，否则以后有人"顺手改成 43"。
	_断言(原.size() == 2 and int(原[0]) == 105 and int(原[1]) == 45,
			"注册点应为 [105, 45]（从 SWF 形状框现读），实际 %s" % str(原))
	var 形: Array = 条.get("形状框", []) as Array
	_断言(形.size() == 4 and float(形[3]) < 0.0,
			"形状框 y 上界应为负（字形在锚点之上 ⇒ 注册点 y 天然落在画布外），实际 %s" % str(形))
	_断言(String(条.get("注册点依据", "")).begins_with("精确"),
			"注册点依据应为「精确」，实际「%s」⇒ 两轴没对上就别用" % str(条.get("注册点依据", "")))
	var 字: Array[String] = []
	for f in 帧:
		var 路 := String((f as Dictionary).get("贴图", ""))
		_断言(ResourceLoader.exists(路), "这条贴图不在盘上：%s" % 路)
		_断言(int((f as Dictionary).get("原点", [0, 0])[0]) == 105, "每帧原点都得是 105，%s 不是" % 路)
		字.append(FileAccess.get_file_as_bytes(路).hex_encode().md5_text())
	## 阳性对照：四段必须**两两不同**。要是哪天导出把 40 帧压成 1 段（或四张一样），
	## "节点存在、在播" 这类断言全绿，但屏幕上那条省略号永远不动。
	var 独 := {}
	for h in 字:
		独[h] = true
	_断言(字.size() == 4, "四段图没能全读进来（读到 %d 个）" % 字.size())
	_断言(独.size() == 4, "四段图里有重复（唯一 %d 张）⇒ 省略号动画是假的" % 独.size())

	## ──  状态层（玩家.gd）──────────────────────────────────────────────
	var 玩 := _读("res://脚本/角色/玩家.gd")
	_断言(玩.contains("signal 自动寻路态(在走: bool)"), "玩家.gd 没有 自动寻路态 信号")
	_断言(玩.contains("var 自动寻路中 := false"), "玩家.gd 没有 自动寻路中 状态位")
	_断言(玩.contains("func 走向(目标: Vector2, 显示涟漪 := true, 自动 := false) -> bool:"),
			"走向 没带 自动 参 ⇒ showtip 传不进来")
	var 走段 := _截段(玩, "func 走向(", "func show_click_ripple")
	_断言(走段.contains("_设自动寻路态(自动 and click_move_active)"),
			"走向 没按「自动 且 路线真起来了」置状态 ⇒ 要么常亮要么不亮")
	var 设段 := _截段(玩, "func _设自动寻路态", "\nfunc ")
	_断言(设段.contains("if 自动寻路中 == 在走:") and 设段.contains("return"),
			"_设自动寻路态 没有同值早退 ⇒ 每次寻路都重发信号，挂/摘会抖")
	_断言(设段.contains("自动寻路态.emit(在走)"), "_设自动寻路态 没 emit")
	_断言(_截段(玩, "func cancel_auto_path", "\nfunc ").contains("_设自动寻路态(false)"),
			"cancel_auto_path 没摘提示（原版 :446-449 停路线时一起 removeChild）")
	_断言(_截段(玩, "func _physics_process", "\nfunc ").contains("自动寻路中 and not click_move_active"),
			"没有「路线走完就摘」的兜底 ⇒ 到了目的地提示还挂着")
	## 两处**不许亮**的：手动点地走、战斗自动接近
	_断言(_截段(玩, "func _unhandled_input", "\nfunc ").contains("走向(get_global_mouse_position())"),
			"鼠标点地走那句应当不带 自动（原版 World.as:392 不传 showtip）")
	_断言(_截段(玩, "func _维持接近路线", "\nfunc ").contains("走向(目标.global_position, false)"),
			"战斗自动接近那句应当只关涟漪、不带 自动")

	## ──  画的那一侧 + 调用点（小地图面板.gd）──────────────────────────
	var HUD := _读("res://脚本/界面/小地图面板.gd")
	_断言(HUD.contains("const 寻路提示特效 := \"Effect_PathFindingTip\""), "HUD 没钉要播哪条特效")
	_断言(HUD.contains("const 寻路提示y := 110.0"), "提示 y 应为 110（KeyController.as:999）")
	_断言(HUD.contains("get_viewport().get_visible_rect().size.x * 0.5"),
			"x 必须跟着视口宽走（原版 STAGE_WIDTH/2 是运行期算的），不许写死 480")
	_断言(HUD.contains("_player.connect(\"自动寻路态\", _于自动寻路)"), "HUD 没接 自动寻路态")
	_断言(HUD.contains("_接寻路提示()"), "HUD 没在 _process 里补接（面板重建后会永远不亮）")
	var 挂段 := _截段(HUD, "func _挂寻路提示", "func _摘寻路提示")
	_断言(挂段.contains("is_instance_valid(_寻路提示)") and 挂段.contains("return"),
			"_挂寻路提示 没有「已挂着就别再挂」的早退（原版 :1004 先 contains() 判过）")
	_断言(挂段.contains("queue_free()"), "play 失败时没回收节点 ⇒ 会留一个空转的 EffectPlayer")
	_断言(_截段(HUD, "func _摘寻路提示", "\nfunc ").contains("queue_free()"), "_摘寻路提示 没回收")
	var 向段 := _截段(HUD, "func _走向NPC", "\nfunc ")
	## 2026-10-09：`_走向NPC` 多了一个 `显示提示` 形参 —— 远处点 NPC 那一种原版传的是
	## showtip=false（`NPC.as:63`），而任务赶路那几种仍是 true（`CharacterHandler.as:710`）。
	## 判据跟着改成「**默认值必须是 true**」：不传参的调用点一律照旧亮；
	## 「远处点 NPC 传 false」由 `任务标记刷新与距离闸回归测试.gd` 钉住。
	_断言(_截段(HUD, "func _走向NPC", "
func ").contains("显示提示 := true"),
			"前往NPC 那条的 showtip 默认值不是 true（原版 :710 是 true ⇒ 任务赶路一定亮）")
	_断言(向段.contains("走向\", 实体.global_position, true, 显示提示)"),
			"_走向NPC 没把 showtip 透给 走向（形参白加，两种点击会共用同一个值）")
	_断言(_截段(HUD, "func _走向任务怪", "\nfunc ").contains("走向\", 实体.global_position, true, true)"),
			"点追踪栏去怪 没传 showtip（原版 CharacterHandler.as:881 是 true）")
	_断言(_截段(HUD, "func _点小地图寻路", "\nfunc ").contains("走向\", 世界, true, true)"),
			"点小地图寻路 没传 showtip（原版 SmallMapWindow.as:1137 是 true）")
	_断言(HUD.contains("走向\", 门[\"位\"] as Vector2, true, true)"),
			"跨图赶门那一步没传 showtip（原版 :1058 条件 param5 || _nowWalkingToMap ⇒ 必亮）")
	_断言(_读("res://脚本/界面/窗口/活跃度窗口.gd").contains(", true, true)"),
			"活跃度窗口的「走过去找 NPC」没传 showtip")
	_finish()


func _finish() -> void:
	if _失败.is_empty():
		print("自动寻路提示回归测试：通过（%d 条）" % _条数)
		quit(0)
		return
	for 条 in _失败:
		printerr(条)
	print("自动寻路提示回归测试：共 %d 条，红 %d 条" % [_条数, _失败.size()])
	quit(1)
