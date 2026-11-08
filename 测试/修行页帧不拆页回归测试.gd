extends SceneTree

## 修行那一组两扇（左「修行设定与收益」+ 右「领取修行收益」）的**回帧不拆页**门。
##
## 为什么单开一道（用户 2026-10-20 夜实机报「这个界面的按钮我点击还是没反应，根本点不动」，
## 而当时 78 条几何门 + 685 条换皮件门全绿）：
## 病不在版式，在**刷新方式**。`功能窗口.gd:389-407` 把 `player_stats_changed` /
## `cultivation_changed` / `inventory_changed` 等十几个会话信号都接到 `_refresh_current()`
## → `_flush_refresh()` → `_render_page()`，而 `_render_page()` 开头把 `_content` 的 children
## 全部 `remove_child + queue_free` ⇒ 按下记在旧节点、抬起落到重建出来的新节点，
## `BaseButton.pressed` 永远不发。联网后 1286/39/40 那些帧每秒几十发，手一按下去页就被拆了。
## 离线几何门一次就点中，正因为离线没有这些帧。
##
## 原版口径（真值，别改回重建）：`Client.as:4704-4706 onQueryBiguanResult`
## → `biGuanWindow.setData(4 参)`（`BiGuanWindow.as:156-161` = `shouyiWindow.setData(exp,zq)`
## + `formatTimer(秒)`），包裹变了 → `ItemManager.as:362-364` → `lingquShouyi.updateIconContainer()`
## （`LingquBiguanShouyi.as:187-193`）。**原版全程没有一句拆页重建。**
##
## ⚠ 真鼠标那两条（按下→帧→抬起 ⇒ `pressed`）不归这道门：无头拿不到视口拾取，硬塞进来只会假红
##（实测：同一支脚本加 `--headless` ⇒ 两件都"活着"而 `pressed` 0 次）。那条取证在
## `开发工具/量修行页命中.gd`（**不能加 --headless**）。这道门钉同一条因果的**上游**：
## 页没被拆 + 数还刷得动，并且自带一条"故意把旗摘掉"的阳性对照，证明判据真有牙齿。
##
## 跑法：Godot --headless --path . --script res://测试/修行页帧不拆页回归测试.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 系统窗口 := preload("res://脚本/界面/窗口/系统窗口.gd")
const 右页根 := "原版领取修行收益内容"
const 左页根 := "原版闭关窗口内容"

## 每段必须钉满的条数（协程被运行期报错打断 ⇒ 后面整段没跑而末行照样打「红 0」，差额按红计）。
const 应判 := 10

var 判数 := 0
var 红 := 0
var 会: Node


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	call_deferred("_跑")


func _判(对: bool, s: String) -> void:
	判数 += 1
	if not 对:
		红 += 1
		print("红   " + s)


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _找页(名: String) -> Control:
	return root.find_child(名, true, false) as Control


## 状态里那三个数是不是刚喂进去的那一组（阳性对照：不成立就是夹具根本没落到会话里）。
func _状对(秒: int, 经验: int, 精华: int) -> bool:
	var 状: Dictionary = 会.call("修行收益状态")
	var 对: bool = int(状.get("seconds", -1)) == 秒
	对 = 对 and int(状.get("exp_gain", -1)) == 经验
	对 = 对 and int(状.get("zq_gain", -1)) == 精华
	return 对


## 喂一发**服务端真帧原文**：直接进 `后端连接._handle_bridge_dictionary`（socket 收到的那份
## 字典就是走它的，`jylx` = opcode ⇒ 见 `后端连接.gd:2422`）。这一层比"自己调会话方法"多照到
## 一条真接线：`游戏会话.gd:211 backend.biguan_info_received.connect(_on_backend_biguan_info)`。
## 自己 emit 会话信号那种写法照不到这一支（夹具替代码圆谎那条坑）。
func _灌一帧(秒: int, 经验: int, 精华: int) -> void:
	root.get_node("BackendConnection").call("_handle_bridge_dictionary", {
		"jylx": 1286, "seconds": 秒, "expGain": 经验, "zqGain": 精华,
	})
	await _帧(8)


func _跑() -> void:
	var 场景: Node = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _帧(60)
	会 = root.get_node_or_null("GameSession")
	if 会 == null:
		_判(false, "① 找不到 /root/GameSession ⇒ 后面全部判不了")
		await _收()
		return
	if root.get_node_or_null("BackendConnection") == null:
		_判(false, "① 找不到 /root/BackendConnection ⇒ 真帧进不来，后面全部判不了")
		await _收()
		return

	## 与玩家那颗「领取修行奖励」同一个入口（`技能面板.gd:552`）⇒ 成对伴随会把左窗一起叫出来。
	会.call("request_feature", "领取修行收益")
	await _帧(20)
	var 右 := _找页(右页根)
	var 左 := _找页(左页根)
	_判(右 != null and 左 != null, "① 开窗之后两扇页面根都要在（右=%s 左=%s）" % [
			str(右 != null), str(左 != null)])
	if 右 == null or 左 == null:
		_判(false, "② 有一扇没建出来 ⇒ 后面 9 条等于没判，明着记红不许静默跳过")
		await _收()
		return
	var 右号: int = (右 as Node).get_instance_id()
	var 左号: int = (左 as Node).get_instance_id()

	## ── ③④⑤ 一发 1286 帧进来：两扇都不许被拆掉重建 ──
	await _灌一帧(3725, 88991, 6677)
	_判(_状对(3725, 88991, 6677),
			"③ 这一帧必须真写进 修行收益状态()（不成立就是夹具没喂进去，④ 以后全废）")
	var 右新 := _找页(右页根)
	var 左新 := _找页(左页根)
	_判(右新 != null and (右新 as Node).get_instance_id() == 右号,
			"④ 回帧之后右页必须还是同一个实例（实得 %s，原 %d）" % [
			str((右新 as Node).get_instance_id()) if 右新 != null else "〈查无〉", 右号])
	_判(左新 != null and (左新 as Node).get_instance_id() == 左号,
			"⑤ 回帧之后左页必须还是同一个实例（实得 %s，原 %d）" % [
			str((左新 as Node).get_instance_id()) if 左新 != null else "〈查无〉", 左号])

	## ── ⑥⑦ 不拆页不等于刷不动：右页两格、左页四格都要原地跟着新帧翻 ──
	await _灌一帧(7200, 123456, 45678)
	var 末右 := _找页(右页根)
	var 末左 := _找页(左页根)
	if 末右 == null or 末左 == null:
		_判(false, "⑥ 判数字前右页已被拆掉/查无 ⇒ 明着记红")
		_判(false, "⑦ 判数字前左页已被拆掉/查无 ⇒ 明着记红")
	else:
		_判(str((末右.get_node("经验值") as Label).text) == "123456"
				and str((末右.get_node("精华值") as Label).text) == "45678",
				"⑥ 右页「经验值/精华值」要原地等于新帧（实得 %s / %s）" % [
				str((末右.get_node("经验值") as Label).text),
				str((末右.get_node("精华值") as Label).text)])
		## 左页 = 原版 `BiGuanWindow.as:156-161`：`formatTimer(7200)` ⇒ 小时 2、分钟 0
		## （`:81-88` `hour=floor(秒/3600)`、`minute=floor((秒/3600−hour)*60)`）
		## 再 `shouyiWindow.setData(exp,zq)` ⇒ 收益面板那两格。
		_判(str((末左.get_node("小时值") as LineEdit).text) == "2"
				and str((末左.get_node("分钟值") as LineEdit).text) == "0"
				and str((末左.get_node("收益面板/经验") as LineEdit).text) == "123456"
				and str((末左.get_node("收益面板/金币") as LineEdit).text) == "45678",
				"⑦ 左页小时/分钟/经验/精华要原地等于新帧（实得 %s / %s / %s / %s）" % [
				str((末左.get_node("小时值") as LineEdit).text),
				str((末左.get_node("分钟值") as LineEdit).text),
				str((末左.get_node("收益面板/经验") as LineEdit).text),
				str((末左.get_node("收益面板/金币") as LineEdit).text)])

	## ── ⑧⑨ 密卷格：包裹变了要**原地**重取（原版 `ItemManager.as:362-364 → updateIconContainer`）──
	## 只动内存里那份 inventory，跑完**就地**还原（`游戏会话.gd:85` 是 `Array[Dictionary]` 类型化数组，
	## 整份 `会.inventory = 普通Array` 会被 set() **静默丢掉** ⇒ 只能 clear + append 还原）。
	## 全程不点原生钮 ⇒ 不落 `user://玩家数据.json`。
	var 背包原: Array = (会.inventory as Array).duplicate(true)
	var 号 := String(系统窗口.修行密卷id())
	(会.inventory as Array).append({"id": 号, "quantity": 1})
	会.inventory_changed.emit((会.inventory as Array).duplicate(true))
	await _帧(6)
	var 格一 := _格()
	_判(格一 != null and str(格一.tooltip_text) == "修行密卷" and 格一.icon != null
			and str((格一.get_node("角标") as Label).text) == "1" and 格一.material == null,
			"⑧ 塞一枚密卷 ⇒ 角标 1、有图标、名字 tooltip、整格**不**套灰（实得 角标=[%s] 图标=%s 灰=%s）" % [
			str((格一.get_node("角标") as Label).text) if 格一 != null else "〈查无〉",
			str(格一 != null and 格一.icon != null),
			str(格一 != null and 格一.material != null)])
	(会.inventory as Array).clear()
	for 条 in 背包原:
		(会.inventory as Array).append(条)
	会.inventory_changed.emit((会.inventory as Array).duplicate(true))
	await _帧(6)
	var 格二 := _格()
	_判(格二 != null and str(格二.tooltip_text) == "修行密卷"
			and str((格二.get_node("角标") as Label).text) == "" and 格二.material != null,
			"⑨ 摘回去 ⇒ 角标是**空串**（不是 ×0）、整格套灰（实得 角标=[%s] 灰=%s）" % [
			str((格二.get_node("角标") as Label).text) if 格二 != null else "〈查无〉",
			str(格二 != null and 格二.material != null)])
	_判(str(会.inventory) == str(背包原),
			"⑩ 夹具动过的 inventory 必须按内容还原（不许把假背包留给后面的门）")
	await _收()


func _格() -> Button:
	var 页 := _找页(右页根)
	if 页 == null:
		return null
	return 页.get_node_or_null("密卷格") as Button


## 阳性对照：④⑤ 测的到底是"拆不拆页"，还是恒真？
## ⇒ 把旗**摘掉**再灌一帧，右页实例号必须变。这一条自己红过才说明那两条有牙齿。
func _收() -> void:
	var 右 := _找页(右页根)
	if 右 != null:
		var 旧号: int = (右 as Node).get_instance_id()
		右.set_meta("page_self_refresh", false)
		await _灌一帧(7500, 123999, 45999)
		var 新 := _找页(右页根)
		_判(新 != null and (新 as Node).get_instance_id() != 旧号,
				"⑪ 阳性对照：摘掉自刷旗再灌一帧，右页实例**必须**变（实得 %s，原 %d；不变说明 ④⑤ 恒真）" % [
				str((新 as Node).get_instance_id()) if 新 != null else "〈查无〉", 旧号])
	else:
		_判(false, "⑪ 阳性对照开跑前右页已查无 ⇒ 明着记红")
	if 判数 < 应判:
		红 += (应判 - 判数)
		print("红   只判了 %d 条，不足 %d 条 ⇒ 中间有段被运行期报错打断" % [判数, 应判])
	print("修行页帧不拆页回归测试：判 %d 条 / 红 %d 条" % [判数, 红])
	quit(0 if 红 == 0 else 1)
