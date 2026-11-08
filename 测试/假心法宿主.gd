extends Node

## 心法页行为门的**假宿主 + 假后端**（`测试/心法页回归测试.gd` 用）。
##
## 只提供 `脚本/界面/窗口/心法窗.gd` 会碰的那几样 ⇒ 「做了窗没人能点开」那一面由
## §真页 那节用**真的 `窗口管理` + 真的鼠标事件**去判，这里只负责把**发出去的字节**记下来：
## 原版这条链上只有两种包 —— `86:7` 查询当前修炼的心法、`86:6:<id>` 切换
## （`UI.as:649-652` 与 `:1836-1839`），而真的 `后端连接` 离线时 `send_game_request()`
## 一律 return false、没处记账 ⇒ 记账只能落在假后端上。
##
## ⚠ 假接口一旦与真身失配 = 假通过（本工程栽过好几次），所以 `心法页回归测试.gd` 的 §接口
##   那一节会拿**真的** `功能窗口.gd` / `后端连接.gd` 逐条核对这里用到的成员确实存在。

class 假后端 extends Node:
	## 与真身同名同型（`后端连接.gd:376` / `:438`）
	var authoritative_skills := {}
	var authoritative_heal := {}
	## 记账本 = 宿主的 `流水`：这样「先发切换、后关窗」这个**顺序**才看得见（原版
	## `onClickOkBtn():97-115` 就是 派发 ⇒ removeChild ⇒ onCloseBtnClick 的序）。
	var 宿主: Node = null

	func request_xinfa_show() -> bool:
		_记("7")
		return true

	func request_xinfa_change(xinfa_id: int) -> bool:
		_记("6:%d" % xinfa_id)
		return true

	func _记(一条: String) -> void:
		# `宿主` 由假宿主的 `_ready()` 接线；没接上就是门自己喂错了状态 ⇒ 记账必须说话，
		# 不许静默吞掉（静默 = "一条包都没发"的假绿）。
		if 宿主 == null:
			push_warning("假心法宿主：假后端没接到宿主 ⇒ 「%s」这条包记不上账" % 一条)
			return
		宿主.流水.append(一条)


var _content := Control.new()
var _backend := 假后端.new()
var _刚开窗 := true		# 宿主 `open_page()` 才为真；回帧引起的重渲染是 false（`功能窗口.gd`）
var 流水: Array[String] = []		# 假后端记的字节 + close 记的"关窗"，按发生顺序
var 通知: Array[String] = []
var 关窗次数 := 0


func _ready() -> void:
	_backend.name = "假后端"
	_backend.宿主 = self
	add_child(_backend)
	_content.name = "页面容器"
	_content.size = Vector2(960.0, 560.0)
	add_child(_content)


func _通知(文本: String) -> void:
	通知.append(文本)


func close() -> void:
	关窗次数 += 1
	流水.append("close")
