extends SceneTree
# 好友主窗几何门（headless）：期望值读 `数据/界面/好友页期望.json`（与场景同一份 SPEC 生成），
# 逐件比页面矩形，容差 ±1；另钉四条状态断言（页签互斥/选中枚显示选中皮/体唯一可见/行高 23）。
# 跑法：Godot --path . --headless --script res://测试/好友页回归测试.gd

const 场景 := "res://场景/界面/窗口/好友/好友窗口.tscn"
const 期望文件 := "res://数据/界面/好友页期望.json"
const 容差 := 1.0
var _红 := 0
var _帧 := 0


func _initialize() -> void:
	pass		# 装配挪到 _process 第 2 帧：假宿主的 `_ready`（给会话命名 GameSession）要等首帧


func _process(_d: float) -> bool:
	if _帧 < 2:
		_帧 += 1
		return false
	跑()
	return true


func 跑() -> void:
	var f := FileAccess.open(期望文件, FileAccess.READ)
	var 期: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	var 根: Control = (load(场景) as PackedScene).instantiate()
	root.add_child(根)
	var 宿: Node = _假宿主()
	root.add_child(宿)
	# 控制器里是 `get_node_or_null("/root/GameSession")` ⇒ 会话必须真挂在 root 下（不是宿主的孙子）
	var 会: Node = 宿.get_node("GameSession")
	宿.remove_child(会)
	root.add_child(会)
	根.call("装配", 宿)
	var 内: Array = 期["_内容"]
	if (根.get_combined_minimum_size() - Vector2(内[0], 内[1])).length() > 容差:
		_报("根尺寸 %s ≠ %s" % [根.get_combined_minimum_size(), 内])
	for 键 in 期:
		if not 键.begins_with("_"):
			_量(根, 键, 期[键])
	_验状态(根)
	验数据(根, 宿, 期["_页签"])
	验路由(根, 宿)
	验模板行(期["_模板行"])
	验菜单(根, 期["_菜单"])
	验最近交友(根, 宿)
	验双击(根, 宿)
	验行数据(根, 宿)
	根.free()
	print("好友主窗：%s" % ("几何与状态全对上" if _红 == 0 else "有 %d 条不符" % _红))
	quit(1 if _红 > 0 else 0)


## 数据通路：行数必须来自**假宿主**的会话（上一版控制器只读 /root/GameSession，
## 与 autoload 撞名 ⇒ 假宿主根本没生效、门在读真数据还报绿）。
func 验数据(根: Control, 宿: Node, 数: Array) -> void:
	var 会: Node = 宿.get("_session")
	for 定 in 数:
		var 期望行数: int = (会.get(定[3]) as Array).size()
		根.call("切页", 定[0])
		var 实 := (根.get_node(定[2] + "/列表/行容器") as Control).get_child_count()
		if 实 != 期望行数:
			_报("页签 %s 行数 %d ≠ 假会话 %d（数据通路或互斥刷新坏了）" % [定[0], 实, 期望行数])
	根.call("切页", "好友")


func _路(键: String) -> String:
	if not 键.contains("|"):
		return 键
	var 对 := 键.split("|")
	if 对[0] == "页签":
		return "页签条/页签" + 对[1]
	if 对[0] == "体":
		return 对[1]
	return 对[0] + "/" + 对[1]


func _量(根: Control, 键: String, 录: Array) -> void:
	var 节 := 根.get_node_or_null(NodePath(_路(键))) as Control
	if 节 == null:
		_报("%s 节点没找到（路径 %s）" % [键, _路(键)])
		return
	var 局: Array = 录[0]
	var d := maxf(maxf(absf(节.position.x - 局[0]), absf(节.position.y - 局[1])),
			maxf(absf(节.size.x - 局[2]), absf(节.size.y - 局[3])))
	if d > 容差:
		_报("%s 实测 (%s,%s,%s,%s) ≠ 期望 %s" % [键, 节.position.x, 节.position.y, 节.size.x, 节.size.y, 局])


func _验状态(根: Control) -> void:
	var 显 := 0
	for 名 in ["好友", "师徒", "仇人", "黑名单", "最近"]:
		var 钮 := 根.get_node("页签条/页签" + 名) as TextureButton
		var 体 := 根.get_node("体" + 名) as Control
		if 体.visible:
			显 += 1
		if 钮.disabled != (名 == "好友"):
			_报("页签 %s 的 disabled=%s 不对（选中枚才 disabled ⇒ 显示 selectedUpSkin）" % [名, 钮.disabled])
		if 钮.disabled and 钮.texture_normal != load("res://素材/界面/原版窗口/好友/页签未选.png"):
			_报("选中枚被换了未选皮（应该是 disabled 槽的选中皮）")
		if not 钮.disabled and 钮.texture_normal != load("res://素材/界面/原版窗口/好友/页签未选.png"):
			_报("未选枚 %s 常态皮不是 页签未选.png" % 名)
	if 显 != 1:
		_报("同屏可见体 = %d，应为 1" % 显)


## 行模板：几何按 §2 的 `模板行`；这里用假数据建一行来量（运行期才有的件，场景里没有）。
func 验模板行(板: Array) -> void:
	var 行: Control = load("res://脚本/界面/窗口/好友/好友行.gd").new()
	root.add_child(行)
	行.填({"name": "瑞树", "level": 60, "favor": 120, "online": true}, "好友", 0)
	for 件 in 板:
		var 节 := 行.get_node_or_null(件[0]) as Control
		if 节 == null:
			_报("行模板件 %s 没建出来" % 件[0])
			continue
		var 局: Array = 件[1]
		if maxf(absf(节.position.x - 局[0]), absf(节.position.y - 局[1])) > 容差:
			_报("行/%s 落点 %s ≠ %s" % [件[0], 节.position, 局])
	if 行.size.y != 23.0:
		_报("行高 %s ≠ 23" % 行.size.y)
	行.free()


## 菜单：验 §6.4 的版式公式（bgWidth = max(文字+6)+6、项宽 = bgWidth−6、底 = 盒+4 × 累计+6+5）。
## ⚠ 中途脚本报错会让本函数提前返回、而 `_红` 还是 0 ⇒ 用返回值当"跑完没跑完"的哨兵，
##    别让门假绿（上一版就差点把"菜单没验成"报成"全对上"）。
func 验菜单(根: Control, 板: Dictionary) -> void:
	var 菜 := 根.get_node("行菜单") as Control
	菜.弹出(根, "好友", {"name": "瑞树", "online": true}, Vector2(100, 100))
	if not 菜.visible:
		_报("菜单没弹出来")
		return
	var 项们: Array = []
	for 子 in 菜.get_children():
		if 子 is Button:
			项们.append(子)
	if 项们.is_empty():
		_报("菜单没建出项")
		return
	var 字多: Button = 项们[0]
	for 钮 in 项们:
		if String(钮.text).length() > String(字多.text).length():
			字多 = 钮
	var 期望项宽 := float(字多.size.x)
	for 钮 in 项们:
		if absf(钮.size.x - 期望项宽) > 容差:
			_报("菜单项宽不齐：%s=%s vs %s" % [钮.name, 钮.size.x, 期望项宽])
	var 底 := 菜.get_node("菜单底") as Control
	if absf(底.size.x - (期望项宽 + 6.0 + 4.0)) > 1.5:
		_报("菜单底宽 %s ≠ 项宽+6+4（bgWidth 公式，MPM:53-61,87-91）" % 底.size.x)
	if absf(底.size.y - (项们.size() * (19.0 + 3.0) + 3.0 + 6.0 - 3.0 + 5.0)) > 1.5:
		_报("菜单底高 %s ≠ 累计+6+5（MPM:85-91）" % 底.size.y)
	if 底.size.y <= 项们.size() * 19.0:
		_报("菜单底高 %s 装不下 %d 项 ⇒ 版式没跑完" % [底.size.y, 项们.size()])
	菜.visible = false


## 「最近」页那枚「交友」的闸门（`FriendGird:148`）：
##   `if(!FriendChatManage.getInstance().buddyData.isFriend(项.id)) splice(1,0,交友)`
## —— 判的是**现算**的"这人在不在我好友列表里"，**不是数据里带的一个字段**。
## 原来 `好友菜单` 读 `项.is_friend`（全工程没人写它）⇒ 恒 false ⇒ 已经是好友的也照出「交友」。
func 验最近交友(根: Control, 宿: Node) -> void:
	var 会: Node = 宿.get("_session")
	会.set("friends", [{"character_id": 777, "name": "瑞树", "level": 60, "online": true}])
	会.set("recent_contacts", [
		{"character_id": 777, "name": "已是好友", "level": 51, "job": "水", "online": true},
		{"character_id": 888, "name": "路人", "level": 51, "job": "水", "online": true}])
	根.call("切页", "最近")
	var 列 := 根.get_node("体最近/列表/行容器") as Control
	if 列 == null or 列.get_child_count() < 2:
		_报("最近页没建出两行 ⇒ 这一腿没量到")
		return
	var 菜 := 根.get_node("行菜单") as Control
	for i in 2:
		var 行: Control = 列.get_child(i)
		# 走**行自己存的那份**（`填()` 收的就是刷新时补好 `is_friend` 的那份副本）
		行.emit_signal("点击", 行.get("_项"), Vector2(100, 100))
		var 文: Array = []
		for 子 in 菜.get_children():
			if 子 is Button:
				文.append(String((子 as Button).text))
		var 该有 := i == 1
		if 文.has("交友") != 该有:
			_报("最近页第 %d 行（character_id=%s，%s好友列表）里「交友」该%s有，实测项表 %s"
				% [i, "777" if i == 0 else "888", "在" if i == 0 else "不在",
					"不" if i == 0 else "", str(文)])
	菜.visible = false
	根.call("切页", "好友")


## 双击好友行 ⇒ 该把「对话」这一动作交回宿主（`FriendGird` 双击即私聊那一档）。
## ⚠ 10-23 全工程普查 `.bind()` 时逮到这一腿**从没被门走过**：控制器写的是
## `行.双击.connect(_发动作.bind("x:对话"))`，而 Godot 4.7 把绑进去的实参排在**信号实参之后**
## ⇒ 实到 `_发动作(<那一项 Dictionary>, "x:对话")`，`_发动作(名: String)` 只有一个形参
## ⇒ 运行期报错、**双击什么都不发生**（玩家侧是一条死交互）。改成闭包后这里必须真落到动作上。
func 验双击(根: Control, 宿: Node) -> void:
	var 会: Node = 宿.get("_session")
	会.set("friends", [{"character_id": 777, "name": "瑞树", "level": 60, "online": true}])
	根.call("切页", "好友")
	var 列 := 根.get_node("体好友/列表/行容器") as Control
	if 列 == null or 列.get_child_count() == 0:
		_报("好友页没建出行 ⇒ 双击这一腿**没量到**（不是通过）")
		return
	var 动: Array = 宿.get("动作")
	var 前 := 动.size()
	var 行0: Control = 列.get_child(0)
	行0.emit_signal("双击", 行0.get("_项"))
	if 动.size() != 前 + 1 or not String(动[动.size() - 1]).contains("对话"):
		_报("双击好友行 ⇒ 该交回宿主一条带「对话」的动作，实测新增 %d 条（末条 %s）"
				% [动.size() - 前, String(动[动.size() - 1]) if 动.size() > 前 else "无"])
	# 光有动作串没用：宿主拿不到 `character_id` 就发不出私聊/资料请求（A1 之前就是这个状态）
	var 记: Array = 宿.get("菜单动作")
	if 记.is_empty() or int((记[记.size() - 1] as Dictionary).get("character_id", 0)) != 777:
		_报("双击交回的行数据没带角色编号（宿主发不出协议）：%s"
				% (记[记.size() - 1] if not 记.is_empty() else "空"))


## 行数据通路（A1）：菜单项无论走**直发**还是**确认后**，都要把这一行（编号/名字/头像/等级）
## 交回宿主 —— 原版 `FriendWindow2.onMenuHand` 收的是 `param1.object as BuddyMemeber`。
## 只回传动作串的时代宿主能开窗、发不出任何协议（查看/密语/组队/看摊/删黑/赠花全是死键）。
func 验行数据(根: Control, 宿: Node) -> void:
	var 会: Node = 宿.get("_session")
	会.set("friends", [{"character_id": 101, "name": "瑞树", "level": 60, "favor": 120,
			"online": true, "face": 3}])
	根.call("切页", "好友")
	var 列 := 根.get_node("体好友/列表/行容器") as Control
	if 列 == null or 列.get_child_count() == 0:
		_报("好友页没建出行 ⇒ 行数据这一腿**没量到**（不是通过）")
		return
	var 行: Control = 列.get_child(0)
	var 项: Dictionary = 行.get("_项")
	if int(项.get("character_id", 0)) != 101 or int(项.get("face", 0)) != 3:
		_报("行内 `_项` 没带上编号/头像：%s（刷新时把字段丢了）" % 项)
	var 菜 := 根.get_node("行菜单") as Control
	var 记: Array = 宿.get("菜单动作")
	# ① 直发档（查看）：一条动作、行数据原样交回
	var 前 := 记.size()
	菜.项点击.emit("查看", 项)
	if 记.size() != 前 + 1:
		_报("点「查看」宿主没收到菜单动作（新增 %d 条）" % (记.size() - 前))
	elif int((记[记.size() - 1] as Dictionary).get("character_id", 0)) != 101:
		_报("「查看」交回的行数据掉了编号：%s" % (记[记.size() - 1] as Dictionary))
	# ② 确认档（删除）：确认前一条都不许发，确认后仍要带着同一行
	前 = 记.size()
	菜.项点击.emit("删除", 项)
	if 记.size() != 前:
		_报("删除在确认前就把菜单动作发出去了：%d 条" % (记.size() - 前))
	var 层: Control = 宿.get("_overlay")
	var 弹们 := _弹列表(层)
	if 弹们.is_empty():
		_报("删除没弹确认框 ⇒ 「确认后带行数据」这一腿没量到")
		return
	(弹们[弹们.size() - 1].get_node("主体/确定") as Button).pressed.emit()
	if 记.size() != 前 + 1:
		_报("确认删除后宿主没收到菜单动作（新增 %d 条）" % (记.size() - 前))
	elif int((记[记.size() - 1] as Dictionary).get("character_id", 0)) != 101:
		_报("确认删除后交回的行数据掉了编号：%s" % (记[记.size() - 1] as Dictionary))
	菜.visible = false


## 菜单动作分流（`FW2:338-440`）：删除/拉黑/移除 ⇒ 先弹输入确认（正文按页签取不同文案）；
## 打探 ⇒ 开打探窗；其余 ⇒ 直接交回宿主。假宿主把两路都记下来，这里逐条核。
func 验路由(根: Control, 宿: Node) -> void:
	var 菜 := 根.get_node("行菜单")
	var 瑞 := {"name": "瑞树", "level": 60, "favor": 120, "online": true}
	根.set("_当前", "好友")
	菜.项点击.emit("删除", 瑞)
	菜.项点击.emit("拉黑", 瑞)
	菜.项点击.emit("打探", 瑞)
	var 弹: Array = 宿.get("弹")
	var 动: Array = 宿.get("动作")
	if 弹.size() != 2:
		_报("删除/拉黑应各弹一次输入确认，实得 %d 次" % 弹.size())
	else:
		if String(弹[0]).split("|")[0] != "你确定要删除以下连络人吗？":
			_报("好友页删除的确认文案不对：%s" % 弹[0])
		if String(弹[0]).split("|")[1] != "瑞树" or String(弹[0]).split("|")[2] != "true":
			_报("确认弹没把玩家名填进只读输入框：%s" % 弹[0])
		if String(弹[1]).split("|")[0] != "你确定将以下连络人移至黑名单吗？":
			_报("拉黑的确认文案不对：%s" % 弹[1])
	var 层: Control = 宿.get("_overlay")
	if 层.get_node_or_null("家族子窗_好友打探窗") == null:
		_报("点打探没开好友打探窗")
	# 关键不变量：**没点确定就什么都不发**（原版 handler 只在 okBtn 里调）
	if 动.size() != 0:
		_报("未确认就把动作发出去了：%s" % 动)
	验确认弹(层)
	# 走**真钮**而不是直接 call 回调：确定 ⇒ 发出动作、取消 ⇒ 原版 handler(null) 什么都不发
	var 弹们 := _弹列表(层)
	if 弹们.size() < 2:
		var 名: Array = []
		for 子 in 层.get_children():
			名.append(String(子.name))
		_报("假宿主没把两扇确认弹真开进遮罩，只剩 %d 扇，遮罩里=%s" % [弹们.size(), 名])
		return
	(弹们[0].get_node("主体/确定") as Button).pressed.emit()
	if 动.size() != 1 or String(动[0]) != "好友页|好友:删除":
		_报("点确定应发 1 条动作，实得 %s" % 动)
	(弹们[1].get_node("主体/取消") as Button).pressed.emit()
	if 动.size() != 1:
		_报("点取消不该发动作，实得 %s" % 动)


## 遮罩里的确认弹（按 `mdialog` 标记认 —— 两扇同名时 Godot 会把后一粒改成 @Control@N）。
func _弹列表(层: Control) -> Array:
	var 出: Array = []
	for 子 in 层.get_children():
		if (子 as Object).has_meta("mdialog"):
			出.append(子)
	return 出


## 输入确认弹的版式（`MDialog:244-292,507-527,543-550`，实现见 `脚本/界面/窗口/输入确认弹.gd`）。
## 一行正文 = 15+4 = 19 ⇒ 线在 33+2=35、输入框在 33+8=41、contentHeight=41+21+5=67、
## panelHeight=67+50=117、钮 y=117−22−13=82。
func 验确认弹(层: Control) -> void:
	var 弹们 := _弹列表(层)
	if 弹们.is_empty():
		_报("遮罩里没有输入确认框")
		return
	var 单: Control = 弹们[0]
	var 主: Control = 单.get_node("主体") as Control
	var 表 := {
		"正文": [14.0, 14.0, 267.0, 19.0],
		"分隔线": [3.0, 35.0, 287.0, 2.0],
		"输入框": [9.0, 41.0, 267.0, 21.0],
		"确定": [77.0, 82.0, 70.0, 22.0],
		"取消": [186.0, 82.0, 70.0, 22.0],
	}
	for 名 in 表:
		var 节 := 主.get_node_or_null(名) as Control
		if 节 == null:
			_报("确认弹缺件：%s" % 名)
			continue
		var 局: Array = 表[名]
		var d := maxf(maxf(absf(节.position.x - 局[0]), absf(节.position.y - 局[1])),
				maxf(absf(节.size.x - 局[2]), absf(节.size.y - 局[3])))
		if d > 容差:
			_报("确认弹 %s 实测 (%s,%s,%s,%s) ≠ 期望 %s" % [名, 节.position.x, 节.position.y, 节.size.x, 节.size.y, 局])
	if absf(主.size.x - 302.0) > 容差 or absf(主.size.y - 117.0) > 容差:
		_报("确认弹主体 %s ≠ 302×117（panelHeight=67+50）" % 主.size)
	var 期位 := Vector2(floorf((层.size.x - 302.0) * 0.5), floorf((层.size.y - 117.0) * 0.5))
	if 主.position.distance_to(期位) > 容差:
		_报("确认弹没居中：(%s) ≠ (%s)" % [主.position, 期位])
	var 输 := 主.get_node("输入框") as LineEdit
	if 输.text != "瑞树":
		_报("确认弹没把玩家名填进输入框：%s" % 输.text)
	if 输.editable:
		_报("好友页的输入框应是只读（AS3 TextFieldType.DYNAMIC）")
	var 正 := 主.get_node("正文") as RichTextLabel
	if 正.bbcode_enabled != true or 正.scroll_active:
		_报("确认弹正文该开 BBCode 且关滚动：%s/%s" % [正.bbcode_enabled, 正.scroll_active])
	if String(正.text) != "你确定要删除以下连络人吗？":
		_报("确认弹正文没落到控件上：%s" % 正.text)


func _报(话: String) -> void:
	_红 += 1
	print("!! " + 话)


func _假宿主() -> Object:
	return load("res://测试/假好友宿主.gd").new()
