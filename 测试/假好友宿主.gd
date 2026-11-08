extends Node

const 输入确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 测试后端 := preload("res://测试/测试后端连接.gd")

## 好友页回归用的假宿主：提供 `好友窗口.gd` 与三扇子窗会碰的四样 —— `_session`（数据源）、
## `_backend`（协议出口）、`_show_guild_action()` / `_好友菜单动作()`（动作出口）
## 与 `_通知()` / `_查看角色资料()`（子窗的提示与资料出口）。
## 独立成文件：往 GDScript.source_code 里塞多行字符串容易静默失配
## （家族那轮就把主窗喂成了未入族态还报通过）。

class 假会话 extends Node:
	signal inventory_changed(项: Array)
	signal 好友私聊追加(对端: int)

	# `character_id`/`face` 必须有：菜单动作要靠它们发协议（原版 `BuddyMemeber.id/face`），
	# 缺了就只剩名字 —— 门也就验不到"这一行的数据真送到了协议层"。
	# ⚠ 键名跟**服务端 61:2 行解析后的真实键**走：羁绊是 `couple`（不是 `spouse`）、
	#    亲密度是 `intimacy`（不是 `favor`）、职业是**职号**（不是中文串）——
	#    `好友窗口._发菜单项` 曾按 `spouse` 判羁绊，全工程没人写这个键 ⇒ 那条闸永远不开。
	var friends := [
		{"character_id": 101, "name": "瑞树", "level": 60, "intimacy": 120, "online": true,
			"face": 3, "gender": 0, "job": 100, "couple": false},
		{"character_id": 102, "name": "长门", "level": 58, "intimacy": 40, "online": false,
			"face": 5, "gender": 0, "job": 300, "couple": false}]
	var enemies := [{"character_id": 301, "name": "仇八", "level": 40, "intimacy": 900,
		"online": true, "face": 7, "gender": 0, "job": 200}]
	var recent_contacts := [{"character_id": 401, "name": "小南", "level": 51, "job": 200,
		"face": 9, "gender": 1, "online": true, "is_friend": false}]
	# ⚠️ 键名跟着**本工程 `游戏会话` 的真实字段**走（合并时订正过）：
	#    「黑名单」页签读的是 `blocked_contacts`（行字典），不是 `blacklist`
	#    —— 会话里只有 `blocked_players`（纯名字，别处按名字判重），所以另存了一份行字典。
	#    这里原来写 `blacklist` ⇒ 页签读到空、报"黑名单 行数 0 ≠ 假会话 1"。
	var blocked_contacts := [{"character_id": 501, "name": "拉黑者", "level": 12,
		"job": 100, "face": 2, "gender": 0, "online": false}]
	var shitu := [{"character_id": 601, "name": "徒弟甲", "level": 30, "intimacy": 0,
		"face": 4, "gender": 0, "online": true}]

	## 打探窗读背包（`inventory` + `inventory_changed`）；初始 2 张乾坤密卷，门可清空验灰格。
	var inventory: Array = [{"id": 16000005, "quantity": 2}]
	var player_stats := {"name": "我"}
	var 好友私聊记录: Dictionary = {}
	var 清好友私聊次 := 0

	func 记录好友私聊(自己: bool, 号: int, 名: String, 文: String, 时: int = 0) -> void:
		if 号 <= 0 or 文.is_empty():
			return
		var 键 := str(号)
		var 条: Array = 好友私聊记录.get(键, [])
		条.append({"自己": 自己, "名": 名, "文": 文,
			"时": 时 if 时 > 0 else int(Time.get_unix_time_from_system())})
		好友私聊记录[键] = 条
		好友私聊追加.emit(号)

	func 取好友私聊(号: int) -> Array:
		var 条: Variant = 好友私聊记录.get(str(号), [])
		return (条 as Array).duplicate(true) if typeof(条) == TYPE_ARRAY else []

	func 清好友私聊(号: int) -> void:
		清好友私聊次 += 1
		好友私聊记录.erase(str(号))


var _session := 假会话.new()
## 协议出口：真 `测试/测试后端连接.gd`（继承真后端、只记不发），门直接读 `sent_requests`。
var _backend := 测试后端.new()
var _overlay := Control.new()		# 真宿主的 `遮罩`：子窗壳要把浮窗挂这里（与 假家族宿主 同口径）
var 动作: Array[String] = []
## `_好友菜单动作(动作, 行)` 的记账：`好友窗口` 现在把**这一行的数据**随动作一起交回宿主
## （原版 `onMenuHand` 收的就是 `BuddyMemeber`），光有动作串发不出协议。
var 菜单动作: Array[Dictionary] = []
## 子窗的提示出口（原版 `addNotice`）；`好友私聊窗` 没有提示，另两扇有。
var 通知: Array[String] = []
## `选人窗.查看资料钮` 的出口（原版 `API.ui.clickCharacter`）。
var 查看资料: Array[int] = []


func _ready() -> void:
	add_child(_session)
	_session.name = "GameSession"
	add_child(_backend)
	_backend.name = "假后端连接"
	_overlay.name = "遮罩"
	_overlay.size = Vector2(960, 560)
	add_child(_overlay)


func _通知(文: String) -> void:
	通知.append(文)


func _查看角色资料(号: int) -> void:
	查看资料.append(号)


func _show_guild_action(名: String) -> void:
	动作.append(名)


## 真宿主 `功能窗口._好友菜单动作` 的同名替身：两路都记。
##   `动作` 保留老断言（`好友页|好友:删除`），`菜单动作` 存**整行数据**，门拿它核
##   `character_id/name/face/level` 有没有真送到协议那一层。
func _好友菜单动作(名: String, 项: Dictionary) -> void:
	动作.append("好友页|" + 名)
	菜单动作.append(项.duplicate(true))


## 真身是 `脚本/界面/窗口/输入确认弹.gd`（MDialog.showInputDialog 的移植）。假宿主一边**记账**
## 一边**真开弹**：门要量弹里各件的坐标、还要真点得到"确定/取消"两条路，
## 只记账就只能验到"该弹了"、验不到弹本身。
var 弹: Array[String] = []
var 回调: Array[Callable] = []		# 门可以拿它模拟"点了确定"，验没确认前什么都不发


func _弹出输入确认(正文: String, 默认值: String, 只读: bool, _回调: Callable) -> void:
	弹.append("%s|%s|%s" % [正文, 默认值, 只读])
	回调.append(_回调)
	输入确认弹.弹出(_overlay, 正文, 默认值, 只读, _回调)
