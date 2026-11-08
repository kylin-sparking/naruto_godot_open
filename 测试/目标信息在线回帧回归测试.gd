extends SceneTree
## 目标信息条的**在线回帧**门：喂进服务端 `TARGET_INFO(1284)` 的原文，看条上的数字与填充
## 是不是跟着改成服务端那份 —— 也就是「查看信息」那颗钮按下之后真正会发生的事。
##
## 与 `目标信息条回归测试.gd` 的分工：那道门把后端换成记账假对象来判"点钮发了哪一发"，
## 所以它**判不了回帧**（假对象没有真的解析器）。这道门用**真的** `BackendConnection`，
## 把服务端写者拼出来的那串原文喂进 `_handle_bridge_text`，走的是玩家实机那一条路。
##
## 跑法：`"godot" --path . --headless --script res://测试/目标信息在线回帧回归测试.gd`

const 服务端文件 := "res://服务端/runtime/tools/fake_flash_server.py"
const 玩家档 := "1284:1002:1:1002:200:800:50:100"
const 别人档 := "1284:9999:1:9999:1:1:1:1"
const 怪档 := "1284:7001:0:100101:55:55:0:0"
const 旗档 := "1284:3:2:1:10000:10000:0:0"
const 截断档 := "1284:1002:1:1002:200"

var 通过 := 0
var 失败 := 0
var 跑完了 := false


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 话)


func _initialize() -> void:
	await _跑()
	if not 跑完了:
		失败 += 1
		print("红：门自己没跑完（协程中途报错）")
	quit(1 if 失败 > 0 else 0)


func _玩家信息(号: int, 名: String, 血: int, 上限: int) -> Dictionary:
	return {"name": 名, "level_text": "LV.7", "hp": 血, "max_hp": 上限,
			"mp": 260, "max_mp": 260, "type": 1, "char_id": 号, "level": 7}


func _跑() -> void:
	print("目标信息在线回帧门开始")
	await process_frame
	var 后 := root.get_node_or_null("BackendConnection")
	_判(后 != null and 后.has_signal("target_info_received"),
			"真后端在树上且已声明 target_info_received（这道门判的是真解析器，不用假对象）")
	if 后 == null:
		跑完了 = true
		return
	#  先钉"样本串不是手写猜的"：服务端那一行拼串现在还是 `:<char_id>:1:<char_id>:<hp>:<maxHp>:<mp>:<maxMp>`
	var 源 := FileAccess.get_file_as_string(服务端文件)
	_判(源.contains('f"{op(ServerOpcode.TARGET_INFO)}:{target.character.character_id}:1:"'),
			"服务端玩家档那一发的拼串没改（改了 ⇒ 本门的样本串要同步改，否则判的是旧形状）")
	_判(源.contains("TARGET_INFO = 1284"), "服务端的 TARGET_INFO 还是 1284")

	var 件 := (load("res://场景/界面/头像面板.tscn") as PackedScene).instantiate()
	root.add_child(件)
	for i in 4:
		await process_frame
	var 条 := 件.get_node_or_null("头像区域/选中人物信息") as Control
	_判(条 != null, "条本体取到了")
	if 条 == null:
		跑完了 = true
		return
	var 会话 := root.get_node("GameSession")

	# ① 没选中任何人时来一帧 ⇒ 不崩、也不把条弹出来
	后.call("_handle_bridge_text", 玩家档)
	for i in 3:
		await process_frame
	_判(not 条.visible, "没选中目标时来一帧 ⇒ 条不自己冒出来")

	# ② 选中玩家 → 喂服务端那一帧 → 数字与填充都改成服务端那份
	会话.call("select_map_character", _玩家信息(1002, "夕日光", 650, 650))
	for i in 3:
		await process_frame
	_判((条.get_node("血字") as Label).text == "650/650", "先确认选中那一下是 650/650")
	后.call("_handle_bridge_text", 玩家档)
	## 补间按**真实时间**走（`MBar.as:170` 那 0.5 秒），无头下一帧可以短到微秒 ⇒
	## 拿"等 40 帧"当"等半秒"必然假红。等的是墙上时钟。
	await create_timer(0.8).timeout
	_判((条.get_node("血字") as Label).text == "200/800",
			"喂进 1284 玩家档 ⇒ 血改成 200/800（实得「%s」）" % (条.get_node("血字") as Label).text)
	_判((条.get_node("蓝字") as Label).text == "50/100",
			"蓝同理改成 50/100（实得「%s」）" % (条.get_node("蓝字") as Label).text)
	var 血条 := 条.get_node("血条") as TextureProgressBar
	_判(absf(血条.value - 0.25) < 0.02, "血条填到 200/800 = 1/4（实得 %.3f）" % 血条.value)
	_判(absf((条.get_node("蓝条") as TextureProgressBar).value - 0.5) < 0.02, "蓝条填到 50/100 = 1/2")

	# ③ 对象号对不上（别人的目标）⇒ 整条丢掉，不把别人的血量填进来
	后.call("_handle_bridge_text", 别人档)
	for i in 6:
		await process_frame
	_判((条.get_node("血字") as Label).text == "200/800",
			"对象号不是当前目标 ⇒ 这一帧不动本条（实得「%s」）" % (条.get_node("血字") as Label).text)

	# ④ 段数不够（老端/噪声）⇒ 整条丢，不拿默认值凑半条
	后.call("_handle_bridge_text", 截断档)
	for i in 6:
		await process_frame
	_判((条.get_node("血字") as Label).text == "200/800",
			"截断帧整条丢掉（实得「%s」）" % (条.get_node("血字") as Label).text)

	# ⑤ 怪档与地图旗档：现在**故意没接**（本工程怪身上没存服务端 objectId，
	#    拿模板号去配会把同种另一只的血填进当前目标）。这两条判的是"不许乱改"。
	后.call("_handle_bridge_text", 怪档)
	for i in 6:
		await process_frame
	_判((条.get_node("血字") as Label).text == "200/800", "怪档 1284 不改本条（未接，见真值表 §⑫）")
	后.call("_handle_bridge_text", 旗档)
	for i in 6:
		await process_frame
	_判((条.get_node("血字") as Label).text == "200/800", "地图旗档 1284 不改本条（同上）")

	# ⑥ 解析器本身：三档都该发信号，且 type/id 分得清（不依赖 UI）
	var 收到: Array = []
	后.connect("target_info_received", func(状: Dictionary): 收到.append(状.duplicate(true)))
	for 串 in [玩家档, 怪档, 旗档]:
		后.call("_handle_bridge_text", 串)
	_判(收到.size() == 3, "三档都解析出发信号（实得 %d 条）" % 收到.size())
	if 收到.size() == 3:
		_判(int(收到[0]["type"]) == 1 and int(收到[0]["object_id"]) == 1002
				and int(收到[0]["hp"]) == 200 and int(收到[0]["max_hp"]) == 800,
				"玩家档解析成 type=1 / 对象号 1002 / 200~800（实得 %s）" % str(收到[0]))
		_判(int(收到[1]["type"]) == 0 and int(收到[1]["id"]) == 100101,
				"怪档的 id 段是**模板号**、对象号是另一段（实得 %s）" % str(收到[1]))
		_判(int(收到[2]["type"]) == 2 and int(收到[2]["max_hp"]) == 10000,
				"地图旗档 type=2、上限 10000（实得 %s）" % str(收到[2]))
	跑完了 = true
	print("目标信息在线回帧门：通过 %d，红 %d" % [通过, 失败])
