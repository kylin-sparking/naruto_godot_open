## 真鼠标量具：修行那一组两扇（左「修行设定与收益」+ 右「领取修行收益」）在**服务端回帧打进来**
## 的时候还点不点得动、数字还刷不刷得动。
##
## 为什么要它（用户 2026-10-20 夜实机报「这个界面的按钮我点击还是没反应，根本点不动」，
## 而离线门 78 条 + 换皮件 685 条全绿）：
## `功能窗口.gd:389-407` 把 `player_stats_changed` / `cultivation_changed` / `inventory_changed`
## 等**十几个会话信号**都接到 `_refresh_current()` → `_flush_refresh()` → `_render_page()`，
## 而 `_render_page()` 开头把 `_content` 的 children 全部 `remove_child + queue_free`
## ⇒ **按下记在旧节点、抬起落到重建出来的新节点**，`BaseButton.pressed` 永远不发。
## 离线量具一次就点中，正因为离线没有这些帧（同一条道理 10-19 已在挂机页抓过一次，
## 见 `开发工具/量挂机页命中.gd` 与 `功能窗口.gd:4094-4104` 的那面旗）。
##
## 原版口径（真值，别照"重建"改回去）：`Client.as:4704-4706` 收到 1286 帧做的是
## `biGuanWindow.setData(4 参)` —— **往已经开着的那扇里塞数**，`BiGuanWindow.as:156-161`
## 再转 `shouyiWindow.setData(exp,zq)` + `formatTimer(秒)`；包裹变了是
## `ItemManager.as:362-364 → lingquShouyi.updateIconContainer()`。**原版全程没有一句拆页重建。**
##
## 跑法（**不能加 --headless**，无头拿不到视口拾取）：
##   godot --path . --script res://开发工具/量修行页命中.gd
extends SceneTree

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 右页根 := "原版领取修行收益内容"
const 左页根 := "原版闭关窗口内容"

## 每一段必须钉满的条数：协程被运行期报错打断时，后面根本没跑，末行照样能打「红 0」
## ⇒ 收尾自己数判过的条数，不满就把差额记红（§判满 N 条 那条口径）。
const 应判 := 8

var 行: Array[String] = []
var 红 := 0
var 判数 := 0
var 点过 := {}
var 会: Node
var 场: Node
var 上一鼠 := Vector2.ZERO


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	call_deferred("_跑")


func _记(s: String) -> void:
	行.append(s)
	print(s)


func _判(对: bool, s: String) -> void:
	判数 += 1
	if 对:
		_记("ok   " + s)
	else:
		红 += 1
		_记("红   " + s)


func _帧(n: int) -> void:
	for i in n:
		await process_frame


## 一发"服务端 1286 回帧"的最小等价物：**喂真帧原文**给后端的字典分派
## （`后端连接.gd:2422 _handle_bridge_dictionary`，`jylx` = opcode）—— 比自己调会话方法多照到
## 一条真接线 `游戏会话.gd:211 backend.biguan_info_received.connect(_on_backend_biguan_info)`；
## 自己 emit 会话信号那种写法照不到这一支（夹具替代码圆谎那条坑）。
## 返回值 = 这一帧有没有真的落到会话状态里（阳性对照，判据①之前必须先证它成立）。
func _灌一帧(秒: int, 经验: int, 精华: int) -> bool:
	root.get_node("BackendConnection").call("_handle_bridge_dictionary", {
		"jylx": 1286, "seconds": 秒, "expGain": 经验, "zqGain": 精华,
	})
	await _帧(4)
	var 状: Dictionary = 会.call("修行收益状态")
	var 三对: bool = int(状.get("seconds", -1)) == 秒
	三对 = 三对 and int(状.get("exp_gain", -1)) == 经验
	三对 = 三对 and int(状.get("zq_gain", -1)) == 精华
	return 三对


func _找页(名: String) -> Control:
	return root.find_child(名, true, false) as Control


func _跑() -> void:
	var 场景: Node = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _帧(60)
	场 = 场景
	会 = root.get_node_or_null("GameSession")
	if 会 == null:
		_判(false, "找不到 /root/GameSession ⇒ 后面全部判不了")
		_收()
		return

	## 与玩家那颗「领取修行奖励」同一个入口（`技能面板.gd:552`）⇒ 开窗后 成对伴随 会把左窗也叫出来。
	会.call("request_feature", "领取修行收益")
	await _帧(20)
	var 右 := _找页(右页根)
	var 左 := _找页(左页根)
	_判(右 != null and 左 != null,
			"request_feature(\"领取修行收益\") 之后两扇页面根都要在（右=%s 左=%s）" % [
			str(右 != null), str(左 != null)])
	if 右 == null or 左 == null:
		_判(false, "有一扇没建出来 ⇒ 后面 8 条等于没判，明着记红不许静默跳过")
		_收()
		return
	var 右号: int = (右 as Node).get_instance_id()
	var 左号: int = (左 as Node).get_instance_id()
	_记("页面实例号：右 %d 左 %d" % [右号, 左号])

	## ── ⓪ 这一发帧必须真的落到会话里（阳性对照：不成立就是夹具没喂进去，下面全废）──
	var 落到: bool = await _灌一帧(3725, 88991, 6677)
	_判(落到, "灌进去的 1286 帧必须真的写进 修行收益状态()（秒/经验/精华三项都等于喂的数）")
	if not 落到:
		_判(false, "帧没落进会话 ⇒ 后面 7 条等于没判，明着记红")
		_收()
		return

	## ── ① 回帧来了**不许把页拆掉**：拆了就是"整页点不动"的根因 ──
	var 右新 := _找页(右页根)
	var 左新 := _找页(左页根)
	_判(右新 != null and (右新 as Node).get_instance_id() == 右号,
			"回帧之后右页必须还是同一个实例（实得 %s，原 %d）" % [
			str((右新 as Node).get_instance_id()) if 右新 != null else "〈查无〉", 右号])
	_判(左新 != null and (左新 as Node).get_instance_id() == 左号,
			"回帧之后左页必须还是同一个实例（实得 %s，原 %d）" % [
			str((左新 as Node).get_instance_id()) if 左新 != null else "〈查无〉", 左号])

	## ── ② 真机时序的点击：按下 → 灌一帧 → 抬起 ──
	## 挑 购买（只发商城单件查询，不动存档）与 单倍领取（离线只回一句通知，不弹模态）；
	## 双倍那颗会弹「背包里没有修行密卷」的确认框，那框正好压在 购买 上、下一轮就被它吃掉
	## ——那是模态的事，不归这条门，所以这里不打它。
	for 件名 in ["购买", "单倍领取"]:
		var 现: Control = _找页(右页根)
		if 现 == null:
			_判(false, "%s 这一轮开跑前右页已被拆掉 ⇒ 这条明着记红，不许静默跳过" % 件名)
			continue
		var 件 := 现.get_node_or_null(件名) as Control
		if 件 == null or not (件 is BaseButton):
			_判(false, "%s 查无或不是 Button ⇒ 这一条等于没判" % 件名)
			continue
		var 控 := 件 as BaseButton
		var 心: Vector2 = 件.get_global_rect().get_center()
		点过[件名] = 0
		控.pressed.connect(_按过.bind(件名))
		_移(Vector2(8.0, 8.0))
		await _帧(2)
		_移(心)
		await _帧(3)
		var 按 := InputEventMouseButton.new()
		按.position = 心
		按.global_position = 心
		按.button_index = MOUSE_BUTTON_LEFT
		按.pressed = true
		按.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(按)
		await _帧(2)
		await _灌一帧(4385, 90001, 7000)		# ← 真机上就是这一发把节点拆掉的
		await _帧(2)
		var 抬 := 按.duplicate() as InputEventMouseButton
		抬.pressed = false
		抬.button_mask = 0
		root.push_input(抬)
		await _帧(4)
		_判(int(点过[件名]) > 0 and is_instance_valid(件),
				"%s 在「按下→回帧→抬起」时序下 pressed 要被叫到且件不能被拆（实得 %d 次、活着=%s）" % [
				件名, int(点过[件名]), str(is_instance_valid(件))])

	## ── ③ "不拆页"不等于"刷不动"：喂一发新帧，两扇的数字必须跟着翻（原地刷）──
	var 末: Control = _找页(右页根)
	await _灌一帧(7200, 123456, 45678)
	var 左末: Control = _找页(左页根)
	if 末 == null or 左末 == null:
		_判(false, "判数字前页面已被拆掉/查无 ⇒ 这一条明着记红")
	else:
		_判(String((末.get_node("经验值") as Label).text) == "123456"
				and String((末.get_node("精华值") as Label).text) == "45678",
				"右页「经验值/精华值」要原地等于新帧（实得 %s / %s）" % [
				String((末.get_node("经验值") as Label).text),
				String((末.get_node("精华值") as Label).text)])
		## 左页按原版 `BiGuanWindow.as:81-88 formatTimer`：7200 秒 ⇒ 小时 2、分钟 0
		##（`hour = floor(秒/3600)`、`minute = floor((秒/3600 − hour) * 60)`）。
		_判(String((左末.get_node("小时值") as LineEdit).text) == "2"
				and String((左末.get_node("分钟值") as LineEdit).text) == "0"
				and String((左末.get_node("收益面板/经验") as LineEdit).text) == "123456"
				and String((左末.get_node("收益面板/金币") as LineEdit).text) == "45678",
				"左页小时/分钟/经验/精华要原地等于新帧（实得 %s / %s / %s / %s）" % [
				String((左末.get_node("小时值") as LineEdit).text),
				String((左末.get_node("分钟值") as LineEdit).text),
				String((左末.get_node("收益面板/经验") as LineEdit).text),
				String((左末.get_node("收益面板/金币") as LineEdit).text)])
	_收()


func _移(点: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = 点
	e.global_position = 点
	e.relative = 点 - 上一鼠
	上一鼠 = 点
	root.push_input(e)


func _按过(件名: String) -> void:
	点过[件名] = int(点过[件名]) + 1


func _收() -> void:
	if 判数 < 应判:
		红 += (应判 - 判数)
		_记("红   只判了 %d 条，不足 %d 条 ⇒ 中间有段被运行期报错打断，差额按红计" % [判数, 应判])
	print("量修行页命中：判 %d 条 / 红 %d 条" % [判数, 红])
	quit(0 if 红 == 0 else 1)
