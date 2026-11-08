extends SceneTree

## 「意志穿戴八格接线」门（2026-10-22 §3.184）——用户实机报「左下角无法装备意志」。
##
## 真凶 = `脚本/界面/窗口/意志窗口.gd` 的 `_填一格层` 循环上界写成 `for i in 数量`：
## 穿戴传 8 ⇒ range(8) 只走到格_7；**格_8（穿戴盘左下，`initView:451` 偏移 [-4,161]）
## 从没接过拖放、没填过内容** ⇒ 拖任何意志进左下格都没有任何反应（落点系统根本不认它）。
## 与 §3.183 的 match 错位同族：边界差一个 ⇒ 静默失灵；且截图量具只量几何、
## 意志在线门只挪 -1 ⇒ 这条链此前的覆盖率是 0。
##
## 修：穿戴上界 `数量 + 1`（range(9)、跳过格_0 ⇒ 格_1..格_8 全进）。
## 本门钉修复后形状：起真功能窗口 → 开「遗址」页 → 8 个穿戴格必须全部
##   ① 在场景里；② 挂了 `意志格.gd`；③ `拖放` 信号有连接（空格也当落点）；
##   ④ `归属 == "意志穿戴"` 且 `槽位号 == -k`（协议穿戴位）。
## 对旧代码**确定性红**（格_8 裸奔：脚本/信号/归属三缺）。
##
## 运行：Godot --headless --path . --script res://测试/意志穿戴八格接线回归测试.gd

const 页名 := "遗址"					# 功能窗口分派表 `"遗址": 意志窗口.渲染背包(self)`
const 页根 := "原版意志背包内容"

var _失败: Array[String] = []


func _initialize() -> void:
	call_deferred("_跑")


func _记(过: bool, 话: String) -> void:
	if 过:
		print("  √ %s" % 话)
	else:
		_失败.append(话)


func _跑() -> void:
	var 窗 := (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(窗)
	await process_frame
	窗.call("open_page", 页名)
	for _帧 in range(30):
		await process_frame
	var 穿容器 := _找(窗, "穿戴容器") as Control
	_记(穿容器 != null, "「%s」页里找到了 穿戴容器（页没建出来？）" % 页名)
	if 穿容器 == null:
		_收尾()
		return
	_记(String(穿容器.get_parent().name) == 页根,
			"穿戴容器挂在页根 %s 下（实测父级 %s）" % [页根, str(穿容器.get_parent().name)])
	for k in range(1, 9):
		var 格 := 穿容器.get_node_or_null("格_%d" % k) as Control
		_记(格 != null, "穿戴格_%d 在场景里" % k)
		if 格 == null:
			continue
		var 脚: Script = 格.get_script()
		_记(脚 != null and str(脚.resource_path).ends_with("意志格.gd"),
				"穿戴格_%d 挂了 意志格 脚本（_填一格层 漏了它？）" % k)
		# ⚠️ 信号对象走 `is Signal` 判型再取，别 `get() as Signal`：没挂脚本的格
		#   `get("拖放")` 是 null，`null as Signal` 抛 Invalid cast ⇒ SCRIPT ERROR
		#   中断本函数、quit 不执行 ⇒ 门"挂"而不是红（§3.183 同款坑）。
		var 信: Variant = 格.get("拖放")
		var 有接线 := false
		if 信 is Signal:
			有接线 = (信 as Signal).get_connections().size() > 0
		_记(有接线, "穿戴格_%d 的 拖放 信号有接线（空格也要能当落点）" % k)
		_记(str(格.get("格子归属")) == "意志穿戴", "穿戴格_%d 归属 = 意志穿戴（实测 %s）" % [k, str(格.get("格子归属"))])
		# ⚠️ 槽位号也要走 Variant：没挂脚本的格 get 出来是 null，`int(null)` 会炸
		#    SCRIPT ERROR ⇒ 本函数中断、quit 永远不执行 ⇒ 门"挂"而不是红（§3.183 同款坑）。
		var 槽: Variant = 格.get("槽位号")
		_记(槽 != null and int(槽) == -k,
				"穿戴格_%d 槽位号 = -%d（实测 %s）" % [k, k, str(槽)])
	_收尾()


func _收尾() -> void:
	if _失败.is_empty():
		print("意志穿戴八格接线：通过（8 格全挂脚本 + 拖放接线 + 归属/槽位号全对）")
		quit(0)
		return
	for 条 in _失败:
		printerr("意志穿戴八格接线：" + 条)
	quit(1)


func _找(n: Node, 名: String) -> Node:
	if n == null:
		return null
	if String(n.name) == 名:
		return n
	for c in n.get_children():
		var 果 := _找(c, 名)
		if 果 != null:
			return 果
	return null
