extends SceneTree

## 阿凯 / 三代火影 / 木叶丸 三页四扇（生命料理 241×319、洗点 275×324、
## 洗点确认 240×198、徽章打造 340×400）的**行为门**。
##
## 逐件几何不在这里 —— `测试/原版服务窗回归测试.gd` 已经把 16 扇逐个比
## `数据/界面/<页>_期望.json`、而且会**重跑生成器**比场景（手改 .tscn 立刻红）。
## 这里量的是那一族门看不见的事：
##   ① **运行期才决定的颜色**：`LiaoLiMadeWindow.as:364` 的消耗数值只有**色**跟着金币走
##      （数 = 静态配置 2000 已烘），⇒ 门里把金币真的改成 100 与 50000 各渲一次，
##      两档色都要落到件上（只验常态 = 一条永远绿的假判据）。
##   ② **四行状态机**（`WashPointWindowCell.as:43-122`）：⚠ 加减方向与钮名**反着**
##      —— 加钮 `temp − 1`、减钮 `temp + 1`；配对禁用（`:51-52`）；窗级那条
##      `__showAllRevertPoints:79-84`（总和 + 开始钮解禁）**只在点行钮时走**，
##      开窗那条 `setData` 不走 ⇒ 开屏 开始钮 恒禁用（`:191`）。
##   ③ **确认弹两档消耗**（`WashPointConfrimWindow.as:65` `level <= 30 ? 0 : 总和`）
##      与 **确定那两道闸门的顺序**（`WashPointWindow.as:306-323`：等级 > 30 才查背包卷，
##      卷不够 ⇒ **只弹通知、弹层不关**）⇒ 门里真改 会话 的 level / inventory 各跑一支，
##      跑完还原。
##   ④ **居中弹**：`PopUpMananger.centerWindow` ⇒ 洗点确认 的 取位置偏移 必须 == (0,0)
##      （它不参与底栏错开）。⚠ 原版还有全屏 alpha 0.3 遮罩 + 点遮罩=取消，本工程未做
##      ⇒ 记在真值 md 的未决表，本门不假装量到。
##   ⑤ **徽章打造两页签**（`BeastBadgeWindow.as:60-73`）：换面板 + **换「确定」钮文字**
##      （开始合成 / 开始打造）；两支缺料提示是**两个不同的句子**（`_6[0]` 分别替
##      「徽章打造石」与「装备」）⇒ 混成一句就红。
##   ⑥ **成对摆位**：生命料理 / 徽章打造 连背包（`UIMain2.as:3939` / `:4563`）、
##      洗点**不连**（`Client.as:5908-5910` 走 `setDOShow`）⇒ 三条一起钉，
##      谁往 `伴随背包` 里多塞一个名字就红。
##   ⑦ **烘值**（读 `.tscn` 文本，读运行期值 = 自证）：开屏那批 disabled、
##      烘出来的 `*_禁用.png` 灰皮、`cell` 的「空格角标」、材料盒格的灰化材质。
##   ⑧ **一条帧都不发**（REWASH_AP 83 / BUFF_HECHENG 1822:1 / ITEM_CHANGE 1040 子命令
##      26·27 全等点头）⇒ 通知里不许出现「未连接服务端」那种"真试过发送"的字样。
##
## ⚠ 三条硬口径（都是这个工程踩过的）：
##   · `push_input` 前先钉 `root.size`（无头拿不到 GUI 命中 ⇒ 点了静默不生效）；
##   · 悬停**分两跳**、改状态与断言之间隔 3 帧；
##   · 本门不落存档：跑前记 `user://玩家数据.json` 的字节、跑完断言**没变**，
##     中途改过的 `会话` 字段（gold / level / inventory）也**逐条还原并断言**。
##
## 运行：Godot --headless --path . --script res://测试/阿凯洗点徽章页回归测试.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 料理场景 := "res://场景/界面/窗口/生命料理/生命料理窗.tscn"
const 洗点场景 := "res://场景/界面/窗口/洗点/洗点窗.tscn"
const 确认场景 := "res://场景/界面/窗口/洗点/洗点确认窗.tscn"
const 徽章场景 := "res://场景/界面/窗口/徽章打造/徽章打造窗.tscn"
const 料理控制器 := preload("res://脚本/界面/窗口/生命料理窗.gd")
const 料理放入格 := preload("res://脚本/界面/组件/料理放入格.gd")
const 洗点控制器 := preload("res://脚本/界面/窗口/洗点窗.gd")
const 徽章控制器 := preload("res://脚本/界面/窗口/徽章打造窗.gd")

const 白 := Color(1, 1, 1)
const 红 := Color(1, 0, 0)
const 橙 := Color(1, 0.568627, 0)		# UI_ORANGE `UIConfig.as:928`
const 蓝 := Color(0.117647, 0.564706, 1)		# UI_BLUE
const 黄 := Color(1, 0.941176, 0)		# UI_YELLOW（当前方案那行 #FFF000）

## 逐字语言表（`en_US$message_properties.as` 的行号写在每条后面）
const 文缺材料 := "请先放入材料"						# :389 LIAOLIMADEWINDOW_NO_CAI_LIAO
const 文金币少 := "很抱歉，你的金币不够"					# :636+635 替出来的整句
const 文卷不足 := "很抱歉，你背包中的洗点卷数量不足，洗点操作失败了"	# :1545
const 方案模板 := "攻击型 %1 点： 防御型 %2 点\n灵巧型 %3 点：健体型 %4 点\n确认要将它们还原成未分配的潜能点吗？"
const 结果模板 := "还原后，将获得未分配潜能点：%1\n本次操作将需要洗点卷：%2"
const 行名表 := ["攻击型", "防御型", "灵巧型", "健体型"]		# CHAR_FIRST_ATTR_*（`:167-170` 这个序）
const 属性键 := ["ap_atk", "ap_def", "ap_dex", "ap_phy"]
const 缺料文 := ["请放入徽章打造石！", "请放入装备！"]		# `_6[0]`:1925 分别替 :81 与 :1924

## 料理那一段的假后端：**只接管出帧那半边**（同 伊鲁卡三窗门 §3.121 / 跨服频道门）。
## 带一枚与真身同名的信号 ⇒ 「回帧 → 原地换成品」那一支也能从它走；记的是**实参**不是"调过没调"。
class 料理假后:
	extends Node
	signal buff_fusion_received(信息: Dictionary)
	var in_game := true
	var 发: Array = []

	func request_buff_fusion(甲: int, 乙: int) -> bool:
		发.append([甲, 乙])
		return true


var 场景: Node
var 管: Node
var 红数 := 0
var 判数 := 0
var 日志: Array[String] = []
var 通知记录: Array[String] = []
var 全部通知: Array[String] = []		# 累计（`通知记录` 每节会清 ⇒ 坏文案要在收尾一起抓）
var 存档前 := ""
var 鼠位 := Vector2.ZERO
var 走完 := {}
## 跑前玩家四个 `ap_*` 的原值（跑完还原，见 `_跑` 里的说明）。
var 原属性点 := {}
var 段数 := {}
var 上节 := ""
var 上节起 := 0

## ⚠ 每节**判满几条**必须在收尾一起复查（10-23 实栽）：某一节协程半路抛 `SCRIPT ERROR` 时
## 只带走那一个 `await` 中的函数，`_跑` 照样跑到收尾 ⇒ 末行照打「红 0 项」，而那一节后半段
## **一条都没判**。光有「走完几扇」不够（旗是在节**开头**登记的），只能数条数。
const 段应判 := {"生命料理": 49, "洗点": 22, "洗点确认": 17, "徽章打造": 27, "烘值": 9, "成对面": 6}


func _记(过: bool, 文: String) -> void:
	判数 += 1
	if not 过:
		红数 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 文])


## 开一节时把**上一节**判到几条结掉 ⇒ 哪一节半路崩，那一节的条数就短，收尾必然点名它。
func _结(名: String) -> void:
	if 上节 != "":
		段数[上节] = 判数 - 上节起
	上节 = 名
	上节起 = 判数


func _等(n: int) -> void:
	for _i in range(n):
		await process_frame


func _尾通知() -> String:
	return 通知记录[通知记录.size() - 1] if not 通知记录.is_empty() else ""


func _清通知() -> void:
	通知记录.clear()


func _窗(页名: String) -> Node:
	return 管._窗口们.get(页名) as Node


func _页(页名: String) -> Control:
	var 窗 := _窗(页名)
	if 窗 == null:
		return null
	var 出: Control = null
	for 子 in (窗.get_node("遮罩/主窗口/页面容器") as Control).get_children():
		if 子 is Control:
			出 = 子 as Control
	return 出


## 从**已经读进内存的场景文本**里切出某个节点那一块。
## ⚠ 参数是文本、不是路径（10-23 逮到：这一族调用全在传 `get_file_as_string()` 的结果，
## 而旧写法又对那串文本再 `get_file_as_string()` ⇒ 取回空串 ⇒ **正向判据恒红、负向判据恒绿**，
## 烘值那一节整整两年没说过话）。
func _节(文: String, 名: String) -> String:
	var 头 := 文.find('[node name="%s"' % 名)
	if 头 < 0:
		return ""
	var 尾 := 文.find("[node ", 头 + 10)
	return 文.substr(头, 尾 - 头) if 尾 > 头 else 文.substr(头)


## 节点块里 `ExtResource("t6")` 那个引用号。
func _引用号(块: String) -> String:
	var 头 := 块.find("ExtResource(\"")
	if 头 < 0:
		return ""
	var 起 := 头 + 13
	var 尾 := 块.find("\"", 起)
	return 块.substr(起, 尾 - 起) if 尾 > 起 else ""


## `[ext_resource ... path="res://…" id="t6"]` 那一行里、给定引用号对应的资源路径。
func _ext路(文: String, 号: String) -> String:
	if 号 == "":
		return ""
	for 行 in 文.split("\n"):
		if not 行.begins_with("[ext_resource"):
			continue
		if 行.find('id="%s"' % 号) < 0:
			continue
		var 起 := 行.find('path="')
		if 起 < 0:
			return ""
		起 += 6
		var 尾 := 行.find("\"", 起)
		return 行.substr(起, 尾 - 起) if 尾 > 起 else ""
	return ""


func _皮(钮: Button, 槽: String) -> String:
	var 盒 := 钮.get_theme_stylebox(槽) as StyleBoxTexture
	return String(盒.texture.resource_path).get_file() if 盒 != null and 盒.texture != null else "无"


## 分两跳移进目标矩形中心（同帧连发两条 MouseMotion 视口只按最后一条做拾取）。
func 悬停(位置: Vector2) -> void:
	var 中 := (鼠位 + 位置) * 0.5
	var 移 := InputEventMouseMotion.new()
	移.position = 中
	移.global_position = 中
	root.push_input(移)
	鼠位 = 中
	await _等(2)
	移 = InputEventMouseMotion.new()
	移.position = 位置
	移.global_position = 位置
	root.push_input(移)
	鼠位 = 位置
	await _等(3)


func 点(位置: Vector2) -> void:
	await 悬停(位置)
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 位置
	按.global_position = 位置
	root.push_input(按)
	await _等(2)
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 位置
	放.global_position = 位置
	root.push_input(放)
	await _等(3)


func 点钮(钮: Control) -> void:
	await 点(钮.get_global_rect().get_center())


func _钮(根: Control, 路: String) -> Button:
	return 根.get_node(路) as Button


## 某一枚格的数量角标（格自己底下的 `<格名>_数量`）。**空格** = 原版的 `hideIcon` 那一态。
func _角标(根: Control, 格名: String) -> String:
	return (根.get_node("%s/%s_数量" % [格名, 格名]) as Label).text


func _存档字节() -> String:
	var f := FileAccess.open("user://玩家数据.json", FileAccess.READ)
	return "" if f == null else f.get_as_text()


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)
	存档前 = _存档字节()
	var 会 = root.get_node_or_null("/root/GameSession")
	if 会 != null and 会.has_signal("notification_requested"):
		会.notification_requested.connect(func(文本: String) -> void:
			通知记录.append(文本)
			全部通知.append(文本))
	# ⚠ 洗点状态机（点减钮 ⇒ temp+1）要求**四行基数都 > 0**：基数 0 的那一行「−」是禁用的，
	#   点下去什么也不发生，后面 5 条断言就全假红。2026-10-17 撞到过：玩档被写脏成
	#   `ap_atk=0 / ap_dex=1000` 之后，这条门红了 5 项，而代码一个字节没动。
	#   ⇒ 门自己把四行设成一个确定的形状，跑完还原（只改内存，不落盘）。
	if 会 != null:
		var 属性: Dictionary = 会.get("player_stats")
		for 键 in 属性键:
			原属性点[键] = int(属性.get(键, 0))
		var 假点 := [7, 5, 3, 2]
		for i in 4:
			属性[属性键[i]] = 假点[i]
	# ⚠ 生命料理**有会话级状态**（10-23 接投料之后多了三样：两枚投料格占的背包格号、成品号、
	#   那根 500ms 进度条的重入闸，全挂在 `生命料理窗.gd` 的 static 上 ⇒ 门开头必须清一次，
	#   不然这一门跑完会把料留在内存里，邻居门次日假红）。
	料理控制器.新会话()
	洗点控制器.新会话()
	徽章控制器.新会话()
	场景 = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _等(6)
	管 = 场景.get_node_or_null("窗口管理")
	if 管 == null:
		收尾("地图场景下没有 窗口管理")
		return
	管.call("全部关闭")
	await _量料理()
	await _量洗点()
	await _量确认弹()
	await _量徽章()
	await _量成对面()
	await _量烘值()
	收尾()


func 收尾(致命: String = "") -> void:
	_结("")		# 先把最后一节结掉 ⇒ 收尾自己那几条不许算进任何一节
	if 致命 != "":
		日志.append("!! %s" % 致命)
		红数 += 1
	# 把 `_跑` 里为了四行状态机临时改的 `ap_*` 还原（只改内存，不落盘）
	if not 原属性点.is_empty():
		var 会 = root.get_node_or_null("/root/GameSession")
		if 会 != null:
			var 属性: Dictionary = 会.get("player_stats")
			for 键 in 原属性点:
				属性[键] = 原属性点[键]
	var 现 := _存档字节()
	_记(现 == 存档前, "跑完 `user://玩家数据.json` **字节没变**（中途只改内存里的 会话 字段，不落存档）")
	# ⚠ 这一条钉的是 GDScript 的 `%` 结合得比 `+` **紧**：`"A %s" + "B" % 参数` 只会把参数
	#   喂给最后一段 ⇒ 前面那个 %s 原样打到通知条上（本次真撞到，通知实测「%s = 原版进入…」，
	#   而 `contains("UpShelfCursor")` 照样绿 ⇒ 只验关键词的判据抓不到坏文案）。
	var 坏: Array[String] = []
	for 文 in 全部通知:
		if 文.contains("%s") or 文.contains("%d"):
			坏.append(文.substr(0, 40))
	_记(坏.is_empty(), "跑过的 %d 条通知里**没有一条带未替换的占位符**（实测坏句 %s）"
			% [全部通知.size(), str(坏)])
	_记(走完.size() == 4, ("四扇都判到了最后一节（走完 %s）—— 少一扇 = 门自己中途抛了异常，"
			+ "后面那些节等于没判，而 `红` 看不出来") % str(走完.keys()))
	## ⚠ 上面那条 `走完` 是**节开头**登记的 ⇒ 半路崩照样满 4。真正兜住的是这一条：逐节数条数。
	## 10-23 实栽：`料理放入格.可收` 里一句 `String(int)`（构造器不存在）把 `_量料理` 带走，
	## 后面 20 多条**一条没跑**，末行却打「红 0 项」。
	for 名 in 段应判:
		var 实: Variant = 段数.get(名, "没结案")
		_记(int(段数.get(名, -1)) == int(段应判[名]),
				("第「%s」节判满 %s 条（实测 %s）—— 短了就是那一节半路崩了，后面那些条等于没判")
				% [名, str(段应判[名]), str(实)])
	for 一 in 日志:
		print(一)
	print(("阿凯·洗点·徽章 页回归：通过（红 %d 项）" % 红数) if 红数 == 0
			else ("阿凯·洗点·徽章 页回归：不通过（红 %d 项）" % 红数))
	quit(1 if 红数 > 0 else 0)


## ── ① 生命料理（阿凯 / 动作 15）──────────────────────────────────────────────
func _量料理() -> void:
	日志.append("=== 生命料理 241×319「神 秘 料 理」===")
	_结("生命料理")
	管.call("打开", "生命料理")
	await _等(5)
	var 窗 := _窗("生命料理")
	_记(窗 != null, "落地页「生命料理」开出来了")
	if 窗 == null:
		return
	走完["生命料理"] = true
	var 页 := _页("生命料理")
	_记(页 != null and String(页.name) == "原版生命料理内容", "页根 = %s" % (页.name if 页 != null else "无"))
	if 页 == null:
		return
	_记(String(窗._title.text) == "神 秘 料 理",
			"标题「神 秘 料 理」（`:308` LIAOLIMADEWINDOW_TITLE :3307，三字之间各一个**半角**空格）"
			+ "—— 与菜单行「生命料理」、NPC 称号「生命の料理」是三个词，实测「%s」" % String(窗._title.text))
	_记(absf(窗._window.size.x - 241.0) < 0.6 and absf(窗._window.size.y - 319.0) < 0.6,
			"外框 241×319（`:58` `super(241,319,true)`、全链没有 setSize），实测 %.0f×%.0f"
			% [窗._window.size.x, 窗._window.size.y])
	# 第三参 true ⇒ 宿主画内容底，且没有 setContentBgPos ⇒ 就是 UIWindow 默认的 (8,38) 225×251
	var 底 = 窗._content_bg
	_记(底 != null and bool(底.visible), "宿主的 内容底 显形（AS3 第三参 true ⇒ 类里没再 new MYellow）")
	if 底 != null:
		_记(absf((底 as Control).position.x - 8.0) < 0.6 and absf((底 as Control).position.y - 38.0) < 0.6,
				"内容底顶 = **(8,38)**（没有 `setContentBgPos` ⇒ `UIWindow.as:36-38` 的默认），实测 %s"
						% str((底 as Control).position))
		_记(absf((底 as Control).size.x - 225.0) < 0.6 and absf((底 as Control).size.y - 251.0) < 0.6,
				"内容底 225×251（宽−16 / 高−68），实测 %.0f×%.0f"
				% [(底 as Control).size.x, (底 as Control).size.y])
	# 三枚格离线就是**空格**：`hideIcon` 把 countLabel 置成一个空格（`SimpleItemCell.as:311-316,340-342`）
	var 空格对 := true
	for 名 in ["材料1", "材料2", "成品格"]:
		var 角 := 页.get_node("%s/%s_数量" % [名, 名]) as Label
		if 角 == null or 角.text != " " or 角.horizontal_alignment != HORIZONTAL_ALIGNMENT_RIGHT:
			空格对 = false
	_记(空格对, "三枚格的数量角标都是**一个空格**、右对齐、格内 (0,20) 40×20"
			+ "（hideIcon 那一态；生成器以前把 cell 的 数量 整段丢掉 ⇒ 这次补在 `格内层`）")
	_记(String((页.get_node("材料1/材料1_数量") as Node).get_parent().name) == "材料1"
			and (页.get_node("材料1") as Node).get_index() < (页.get_node("材料2") as Node).get_index()
			and (页.get_node("材料2") as Node).get_index() < (页.get_node("成品格") as Node).get_index(),
			"角标挂在**格自己**底下、格按 AS3 的 addChild 序排（材料1 → 材料2 → 箭头 → 成品格）")
	# 悬停详情：原版三枚格都是 `SimpleItemCell`（`LiaoLiMadeWindow.as:333/338/347`），
	# itemData 一填就挂 `MToolTipItem`（`SimpleItemCell.as:220`）⇒ 空格悬停只收框、有料弹详情。
	var 物品框 := 页.get_node_or_null("物品提示框") as Control
	_记(物品框 != null, "生命料理页该在运行期挂上 物品提示框（原版三格都是 SimpleItemCell）")
	if 物品框 != null:
		物品框.visible = true
		(页.get_node("材料1") as Control).mouse_entered.emit()
		_记(not 物品框.visible, "空格子悬停必须把详情框收掉（itemData=null 那一态）")
	# 消耗那一行：标题橙、数白；**只有色是运行期的**
	var 数 := 页.get_node("消耗行/消耗数值") as Label
	_记(数.text == "2000", "消耗数值烘的是静态配置 2000（`BuffHeCheng.json` items.info.money），实测「%s」" % 数.text)
	var 会: Node = 窗.get("_session") as Node
	var 态: Dictionary = 会.get("player_stats") as Dictionary
	var 旧金币 = int(态.get("gold", 0))
	态["gold"] = 100
	料理控制器._上消耗色(页, 窗)
	_记(数.get_theme_color("font_color") == 红,
			"金币 100 < 2000 ⇒ 那个 2000 变**红**（`BaseUtil.as:120` `money > cocoNuts ? #ff0000`），实测 %s"
			% str(数.get_theme_color("font_color")))
	态["gold"] = 旧金币
	料理控制器._上消耗色(页, 窗)
	## ⚠ "还原后该变回白色"这一条**不能拿存档里的金币当前提**：那份 `user://玩家数据.json`
	## 与另一份同名工程共用，在线腿登录过临时夹具之后里面就是 4 个金币 ⇒
	## `4 < 2000` 依旧是红，判据就变成"看环境脸色"（10-19 全量门红在这里）。
	## ⇒ 自己钉一个"肯定付得起"的基准值，再判它回到白；顺手把红/白两档都判到。
	态["gold"] = 999999
	料理控制器._上消耗色(页, 窗)
	_记(数.get_theme_color("font_color") == 白 and int(态.get("gold", 0)) == 999999,
			"金币 999999 ≥ 2000 ⇒ 变回 **#ffffff**（`BaseUtil.as:120` 三元式的另一档），实测 %s"
			% str(数.get_theme_color("font_color")))
	态["gold"] = 旧金币
	料理控制器._上消耗色(页, 窗)
	_记(int(态.get("gold", 0)) == 旧金币,
			"会话 金币 已原样还原成 %d（本门不许把临时值留在内存里）" % 旧金币)
	_记((页.get_node("消耗行/消耗标题") as Label).get_theme_color("font_color") == 橙,
			"「需要金币：」是 UI_ORANGE #ff9100（`BaseUtil.as:255` 传的第一档）")
	# 两颗钮：手型 + 三档皮 + 点击各回一句
	var 放 := _钮(页, "放入钮")
	var 作 := _钮(页, "制作钮")
	_记(放.text == "放入材料" and 作.text == "制作",
			"钮文字「放入材料」(`:2457`)/「制作」(`:2236`)，实测「%s」「%s」" % [放.text, 作.text])
	_记(放.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND
			and 作.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
			"两颗钮都是手型（`MButton3.init():135`）")
	for 项 in [[放, "放入钮"], [作, "制作钮"]]:
		var 钮: Button = 项[0]
		var 干: String = 项[1]
		_记(_皮(钮, "normal") == 干 + ".png" and _皮(钮, "hover") == 干 + "_悬停.png"
				and _皮(钮, "pressed") == 干 + "_按下.png",
				"%s 三档 = 预烘的 +%s/−40 派生皮、**没有** texture_hover（`StyleUtil.as:8-12` 是加性）"
				% [干, "30"])
	# ── 10-23 接上投料与制作 ⇒ 这一段量的是「闸门顺序 + 真发帧 + 真回帧」，不是回显文案 ──
	## 全程**不换页**：这页自己接 `buff_fusion_received` 原地刷、并挂了 `page_self_refresh`
	## ⇒ `放` / `作` / 两枚落点件从渲染到收尾都是同一批节点（#312 那一族：回帧拆页 ⇒ 按下与抬起落不到一起）。
	var 真后: Node = 窗.get("_backend")
	var 页号 := 页.get_instance_id()
	# ① 落点件挂没挂上（`set_script` 在 渲染 里做）；成品格**不该**是落点
	var 一格 := 页.get_node("材料1") as Control
	var 二格 := 页.get_node("材料2") as Control
	var 成格 := 页.get_node("成品格") as Control
	_记(String(一格.get_script().resource_path).ends_with("料理放入格.gd")
			and String(二格.get_script().resource_path).ends_with("料理放入格.gd"),
			"两枚投料格运行期挂上了 `料理放入格`（场景是 SPEC 生成物 ⇒ **没动 .tscn**，先例 `徽章放入格`）")
	_记(成格.get_script() == null,
			"成品格**不是**落点件（原版只有两枚投料盒，成品只能点「取出料理」拿回来）")
	# ② 类型闸逐条（`ItemType.as:144-147` `int(id/10000) == 1601`）
	_记(料理放入格.可收("16010001") and 料理放入格.可收(16010002),
			"香蕉 16010001 / 鲜虾 16010002 ⇒ **收**（前四位 1601 = `ItemType.LiaoLiCaiLiao`）")
	_记(not 料理放入格.可收("16000011") and not 料理放入格.可收("13100010"),
			"洗点卷 16000011（1600 家族）与勾玉 13100010 ⇒ **不收**（这一条防的是「前四位」写成「前三位」）")
	_记(not 一格._can_drop_data(Vector2.ZERO, {"归属": "背包", "物品id": "16000011", "来源格": 一格})
			and not 一格._can_drop_data(Vector2.ZERO, {"归属": "仓库", "物品id": "16010001", "来源格": 一格})
			and 一格._can_drop_data(Vector2.ZERO, {"归属": "背包", "物品id": "16010001", "来源格": 一格}),
			"`_can_drop_data` 三档：背包+料理料=真、背包+非料=假、**归属不是背包**=假")
	# ③ 夹具：三枚料进背包。⚠ 三条口径都是这工程踩过的：
	#    · `游戏会话.gd:85` 是 `Array[Dictionary]` ⇒ 只能**就地** clear/`[]=`，`set("inventory", 普通 Array)` 被静默丢掉；
	#    · `游戏会话._占用条:2767-2770` 是**按位置**取（格号 = 下标 + 1，越界回空条）⇒ 要槽 5/6/7 得先垫够 7 格；
	#    · `id` 写成**八位补零字符串** —— 服务端回填就是这个形状（`后端连接.gd:4388` `str(item_id).pad_zeros(8)`），
	#      给 int 会让 `背包窗口.gd:722` 的 `String(物品.get("id"))` 当场炸（`String(int)` 构造器不存在）。
	var 背包备份: Array = (会.inventory as Array).duplicate(true)
	var 背包: Array[Dictionary] = 会.get("inventory")
	背包.clear()
	for _垫 in range(7):
		背包.append({})
	背包[4] = {"id": "16010001", "quantity": 3}
	背包[5] = {"id": "16010002", "quantity": 1}
	背包[6] = {"id": "16010001", "quantity": 2}		# 同种第二格 ⇒ 专给「同种」那条判据用
	_记(int(窗.call("_背包数量", 16010001)) == 5 and int(窗.call("_背包数量", 16010002)) == 1
			and int(窗.call("_背包数量", 16010003)) == 0,
			"夹具自证：宿主自己读到 香蕉 5 / 鲜虾 1 / 成品 0（背包**真**被改写了，下面几条才有意义）")
	# ④ 投料（`validateItem:75-105` + `updateCaiLiao:107-146`）
	_清通知()
	一格.emit_signal("请求放入", 5)
	await _等(2)
	_记(料理控制器.投料格() == [5, -1] and _角标(页, "材料1") == "5"
			and _角标(页, "材料2") == " " and _角标(页, "成品格") == " ",
			"落一枚进槽 1 ⇒ 记背包格 5、角标 = **该物品在背包里的总量 5**（`:112-115` 用 `isBagExistItem(id)`，
			不是这一格的数量 —— 槽 5 自己只有 3 枚，另 2 枚在槽 7 ⇒ 显示 5 才叫按总量），实测「%s」"
			% _角标(页, "材料1"))
	二格.emit_signal("请求放入", 7)
	await _等(2)
	_记(料理控制器.投料格() == [5, -1] and _尾通知() == "只能放入两种不同的料理材料",
			"槽 1 已有香蕉、再放**同种**香蕉 ⇒ 弹 `SAME_CAI_LIAO` 且不占槽 2（`:89-93`），实测「%s」" % _尾通知())
	二格.emit_signal("请求放入", 6)
	await _等(2)
	_记(料理控制器.投料格() == [5, 6] and _角标(页, "材料2") == "1",
			"换鲜虾 ⇒ 落槽 2（`:94-97` 不同种才收），实测格号 %s" % str(料理控制器.投料格()))
	# 投料后悬停 ⇒ 弹那颗料的详情（标题来自道具表 = 物品名，不是格名「进阶符」那类固定语言）
	if 物品框 != null:
		物品框.visible = false
		(页.get_node("材料1") as Control).mouse_entered.emit()
		_记(物品框.visible and String((物品框.get_node("标题") as Label).text) == "香蕉",
				"悬停材料1 该弹「香蕉」详情，实得 %s"
				% ((物品框.get_node("标题") as Label).text if 物品框.visible else "<没弹>"))
		(页.get_node("材料1") as Control).mouse_exited.emit()
		_记(not 物品框.visible, "移开材料1 详情框该收起")
	_清通知()
	await 点钮(放)
	_记(_尾通知() == "材料放入完毕，您现在可以制作料理了" and 放.text == "放入材料",
			"两格都满 ⇒ 点「放入材料」只弹 `CAI_LIAO_READY` 就 return（`:216-220`）、钮文字不动，实测「%s」" % _尾通知())
	一格.emit_signal("请求放入", 7)
	_记(料理控制器.投料格() == [7, 6], "替换只改变目标材料格")
	二格.emit_signal("请求放入", 7)
	_记(料理控制器.投料格() == [7, 6], "替换不能让两格变成同种")
	var 返回格 := Button.new()
	返回格.set_script(load("res://脚本/界面/组件/可拖拽格.gd"))
	返回格.set("格子归属", "背包")
	root.add_child(返回格)
	var 载荷: Variant = 一格.call("_get_drag_data", Vector2.ZERO)
	_记(载荷 is Dictionary and 载荷.get("归属") == "料理", "材料可起拖，载荷不是背包实体移动")
	_记(返回格.call("_can_drop_data", Vector2.ZERO, 载荷), "背包接收料理取出")
	返回格.call("_drop_data", Vector2.ZERO, 载荷)
	_记(料理控制器.投料格() == [-1, 6] and int(背包[6].quantity) == 2,
		"拖回背包仅清选择，不销毁、不移动、不增减物品")
	一格.emit_signal("请求放入", 5)
	var 右击 := InputEventMouseButton.new()
	右击.button_index = MOUSE_BUTTON_RIGHT
	右击.pressed = true
	一格.call("_gui_input", 右击)
	_记(料理控制器.投料格() == [-1, 6], "右键可取出材料")
	一格.emit_signal("请求放入", 5)
	返回格.queue_free()
	# ⑤ 制作：三道闸全过 ⇒ 先挂进度条说「制作料理中」，**500 毫秒后**才发帧。
	## 出帧那半边换**假后端**（`_发合成` 运行期现取 `_backend` ⇒ 不必重开页），记的是实参不是"调过没调"。
	var 假 := 料理假后.new()
	root.add_child(假)
	态["gold"] = 999999
	窗.set("_backend", 假)
	_清通知()
	var 起 := Time.get_ticks_msec()
	await 点钮(作)
	var 按后 := Time.get_ticks_msec() - 起
	_记(_尾通知() == "制作料理中" and 假.发.is_empty(),
			"点「制作」立刻：只说「制作料理中」、**一条都没发**（原版 `showLoadingBar:167-181` 先挂 `GeneralInternalLoading`，
			500ms 后才 `zhiZuoLiaoLi`），点击这一跳用了 %d ms" % 按后)
	await 点钮(作)
	var 用 := Time.get_ticks_msec() - 起
	_记(用 < 500 and 假.发.is_empty(),
			"500ms 没到之前再点 ⇒ `if(this._loading) return` 那道重入闸拦下、不排第二次队（此刻第 %d ms，必须 <500 这条才算真判到）" % 用)
	var 发于 := 用
	while 假.发.is_empty() and 发于 < 4000:
		await process_frame
		发于 = Time.get_ticks_msec() - 起
	_记(假.发.size() == 1 and int(假.发[0][0]) == 5 and int(假.发[0][1]) == 6
			and 发于 - 按后 >= 300,
			"等过进度条 ⇒ **只发一条** `1822:1:<槽1>:<槽2>` = 两枚投料格占的背包格号
			（`zhiZuoLiaoLi:62-66` 发的是 `ItemData.position`），实测 %s 在第 %d ms" % [str(假.发), 发于])
	窗.set("_backend", 真后)
	# ⑥ 回帧走**服务端真帧原文**（`fake_flash_server.py:38668-38753` 回 `1822:2:<成品号>`，0 = 失败）
	if 真后 != null:
		_清通知()
		真后.call("_handle_bridge_text", "1822:2:0")
		await _等(2)
		var 解: Dictionary = 真后.get("authoritative_buff_fusion") as Dictionary
		_记(int(解.get("action", -1)) == 2 and int(解.get("item_id", -1)) == 0,
				"服务端原文 `1822:2:0` 解出 action=2 + item_id=0，实测 %s" % str(解))
		_记(_尾通知() == "很抱歉，制作料理失败" and 料理控制器.成品号() == 0
				and 放.text == "放入材料" and 料理控制器.投料格() == [5, 6],
				"失败支只 `addNotice` 一句（`:190-193`）⇒ 钮、成品格、两格料**都不动**，实测「%s」" % _尾通知())
		真后.call("_handle_bridge_text", "1822:2:16010003")
		await _等(2)
		_记(料理控制器.成品号() == 16010003 and 放.text == "取出料理"
				and _角标(页, "成品格") == "1" and _尾通知() == "制作料理成功",
				"成功支：弹成功 + 填成品格 + 钮换「取出料理」（`:196-199`）。⚠ 角标是 `setResultData:301`
				**明写的字符串 1**、不是按数量算的（我原先按 `createSingleItem` 的 count 推成空格 ⇒ 这条是纠正），实测「%s」「%s」"
				% [放.text, _角标(页, "成品格")])
		真后.call("_handle_bridge_text", "1822:2:0")
		await _等(2)
		_记(料理控制器.成品号() == 16010003 and 放.text == "取出料理",
				"已有成品时再来一发失败帧 ⇒ 原版**不清成品**（`buffItemId==0` 那一支只弹话，`pickItemOut`
				只在点「取出料理」时走）—— 这条钉的是我一开始自己脑补「失败就清回空态」的那一处")
		_记(is_instance_valid(页) and _页("生命料理") != null
				and (_页("生命料理") as Node).get_instance_id() == 页号,
				"这三发 1822 回帧**没有把页拆掉**（挂了 `page_self_refresh` ⇒ 宿主 `_flush_refresh` 直接 return）")
	else:
		_记(false, "取不到 /root/BackendConnection ⇒ 回帧那整段**没量到**（不是通过）")
	# ⑦ 取出料理：只清成品，投料格不动（`pickItemOut:205-210`）
	_清通知()
	await 点钮(放)
	_记(料理控制器.成品号() == 0 and 放.text == "放入材料" and _角标(页, "成品格") == " "
			and 料理控制器.投料格() == [5, 6],
			"点「取出料理」⇒ 清成品（角标回空格）+ 钮回「放入材料」，两格料**不**跟着清，实测「%s」%s"
			% [放.text, str(料理控制器.投料格())])
	# ⑧ 阳性对照：**摘掉旗** ⇒ 同一发真帧必须把页换掉，否则 ⑥ 最后那条等于没判
	if 真后 != null:
		页.set_meta("page_self_refresh", false)
		真后.call("_handle_bridge_text", "1822:2:16010003")
		await _等(4)
		var 新 := _页("生命料理")
		_记(新 == null or not is_instance_valid(页) or (新 as Node).get_instance_id() != 页号,
				"把旗摘掉再喂同一发 ⇒ 页**确实被宿主拆掉重建**（同一把尺子必须照到反面，`功能窗口.gd:4183-4194`）")
		if 新 != null:
			_记(bool((新 as Control).get_meta("page_self_refresh", false)),
					"重建出来的那页自己又把旗挂回去了（旗在 `渲染()` 里设 ⇒ 不是门里手设的）")
	# 还原：背包、金币、会话级状态、假后端、窗
	背包.clear()
	for 项 in 背包备份:
		背包.append(项 as Dictionary)
	态["gold"] = 旧金币
	料理控制器.新会话()
	假.queue_free()
	管.call("打开或收起", "生命料理")


## ── ② 洗点主窗（三代火影 / 动作 26）：四行状态机 ─────────────────────────────
func _量洗点() -> void:
	日志.append("=== 洗点 275×324 四行状态机（加减方向与钮名反着）===")
	_结("洗点")
	管.call("打开", "洗点")
	await _等(5)
	var 窗 := _窗("洗点")
	_记(窗 != null, "落地页「洗点」开出来了")
	if 窗 == null:
		return
	走完["洗点"] = true
	var 页 := _页("洗点")
	_记(页 != null and String(页.name) == "原版洗点内容", "页根 = %s" % (页.name if 页 != null else "无"))
	if 页 == null:
		return
	_记(String(窗._title.text) == "洗点",
			"标题「洗点」（`:102` CN.WASH_POINT :2663）—— ⚠ 菜单行写的是「重置潜能点」，两个词别互相顶掉")
	_记(absf(窗._window.size.x - 275.0) < 0.6 and absf(窗._window.size.y - 324.0) < 0.6,
			"外框 275×324（`MWindow` 族、尺寸唯一来源 `:265-266`），实测 %.0f×%.0f"
			% [窗._window.size.x, 窗._window.size.y])
	var 底 = 窗._content_bg
	_记(底 != null and not bool(底.visible),
			"宿主的 内容底 **不显形**（`MWindow` 族没有 UIWindow 那个第三参 ⇒ 黄底是页面自己烘的）")
	var 黄底 := 页.get_node("内容底") as NinePatchRect
	_记(_皮2(黄底) == "内容面板.png", "页面 内容底 皮 = 内容面板.png（MYellow_background），实测「%s」" % _皮2(黄底))
	_记(absf(黄底.position.x - 6.0) < 0.6 and absf(黄底.position.y - 10.0) < 0.6
			and absf(黄底.size.x - 263.0) < 0.6 and absf(黄底.size.y - 251.0) < 0.6,
			"内容底 (6,39)→页内 (6,10) 263×251（`:272-277`；⚠ y=**39** 不是 UIWindow 的 38），实测 %s %s"
			% [str(黄底.position), str(黄底.size)])
	var 属底 := 页.get_node("属性区底") as NinePatchRect
	_记(absf(属底.size.x - 253.0) < 0.6,
			"属性区底宽 = **253**（`:281` `background2.width − 10 = 263−10`；2026-10-06 自查：SPEC 以前算成 252）"
			+ "，实测 %.0f" % 属底.size.x)
	# 数据面：四行的基数就是 会话 的 ap_*（`initWindow:201-202` 的取数序 = 攻/防/敏/体）
	var 态: Dictionary = (窗.get("_session") as Node).get("player_stats") as Dictionary
	var 基 := 洗点控制器.基数()
	var 键对 := true
	for i in 4:
		if 基[i] != int(态.get(属性键[i], -1)):
			键对 = false
	_记(键对, "四行基数按 `ap_ATK/ap_DEF/ap_DEX/ap_PHY` 那一序落到 `ap_atk…`（`服务端会话同步.gd:28` 的改名表），"
			+ "实测 %s" % str(基))
	var 名对 := true
	for i in 4:
		if (页.get_node("行%d/行%d属性名" % [i, i]) as Label).text != 行名表[i]:
			名对 = false
	_记(名对, "四行属性名逐字「攻击型/防御型/灵巧型/健体型」（`:167-170` 那个序）")
	_记((页.get_node("当前方案") as Label).get_theme_color("font_color") == 黄
			and (页.get_node("操作提示") as Label).get_theme_color("font_color") == 蓝,
			"「当前配点方案如下」#FFF000（`getLabel2` 默认 UI_YELLOW）、「请点击上方的 + - 按钮还原点数」#1E90FF")
	# 开屏态（`:147-154` setData + `:51-52` 配对禁用 + `:191` 开始钮禁用）
	var 开屏对 := true
	for i in 4:
		var 行 := 页.get_node("行%d" % i) as Control
		if (行.get_node("行%d已分配" % i) as Label).text != str(基[i]):
			开屏对 = false
		if (行.get_node("行%d还原数" % i) as Label).text != "-0":
			开屏对 = false
		if not (行.get_node("行%d全收钮" % i) as Button).disabled:
			开屏对 = false
		if not (行.get_node("行%d加钮" % i) as Button).disabled:
			开屏对 = false
	_记(开屏对, "开屏每行：已分配 = ap、还原数 = **\"-0\"**（带负号，`:152`）、全收/加 **禁用**（`temp>0` 那组）")
	_记(_钮(页, "开始钮").disabled and _钮(页, "再想钮").disabled == false,
			"开屏「开始洗点」**禁用**（`:191`；`initWindow→setData` 不走 SHOW_ALL_REVERT_POINTS 那条事件）")
	_记((页.get_node("获得数值") as Label).text == "0", "获得数值开屏 \"0\"（`:139`）")
	# 逐档走状态机
	var 减 := _钮(页, "行0/行0减钮")
	await 点钮(减)
	var 行0 := 页.get_node("行0") as Control
	_记(洗点控制器.还原数()[0] == 1
			and (行0.get_node("行0已分配") as Label).text == str(基[0] - 1)
			and (行0.get_node("行0还原数") as Label).text == "-1",
			"点**减钮** ⇒ temp +1（`:88-95`，与钮名反着）⇒ 已分配 %d、还原数 \"-1\"" % (基[0] - 1))
	_记((页.get_node("获得数值") as Label).text == "1" and not _钮(页, "开始钮").disabled,
			"⇒ 窗级那条事件跑到：获得数值 1、开始钮解禁（`:82-83`）")
	_记(not _钮(行0, "行0全收钮").disabled and not _钮(行0, "行0加钮").disabled,
			"⇒ 行0 的 全收/加 转亮（`temp>0`）")
	await 点钮(_钮(行0, "行0加钮"))
	_记(洗点控制器.还原数()[0] == 0 and (页.get_node("获得数值") as Label).text == "0"
			and _钮(页, "开始钮").disabled,
			"点**加钮** ⇒ temp −1 回 0（`:57-61`）⇒ 开始钮**又禁用**（总和 0）")
	await 点钮(_钮(行0, "行0全放钮"))
	_记(洗点控制器.还原数()[0] == 基[0] and (行0.get_node("行0已分配") as Label).text == "0"
			and (行0.get_node("行0还原数") as Label).text == "-%d" % 基[0],
			"点**全放钮** ⇒ temp = 基数（`:45-46`）、已分配 0、还原数 \"-%d\"" % 基[0])
	_记(_钮(行0, "行0减钮").disabled and _钮(行0, "行0全放钮").disabled
			and not _钮(行0, "行0全收钮").disabled and not _钮(行0, "行0加钮").disabled,
			"⇒ 禁用配对整个翻面（`temp < base` 那组灭、`temp > 0` 那组亮）")
	await 点钮(_钮(行0, "行0全收钮"))
	_记(洗点控制器.还原数()[0] == 0 and _钮(页, "开始钮").disabled,
			"点**全收钮** ⇒ temp = 0（`:120-121`）、开始钮回到禁用")
	# 跨行求和
	await 点钮(_钮(页, "行2/行2减钮"))
	await 点钮(_钮(页, "行3/行3减钮"))
	_记((页.get_node("获得数值") as Label).text == "2" and 洗点控制器.总和() == 2,
			"两行各减 1 ⇒ 获得数值 2（`:81-82` 是四行求和，不是只看一行）")


## ── ③ 洗点确认弹：两档消耗 + 两道闸门顺序 ────────────────────────────────────
func _量确认弹() -> void:
	日志.append("=== 洗点确认弹 240×198（居中、两段逐字、卷不足不关弹）===")
	_结("洗点确认")
	var 页 := _页("洗点")
	var 窗 := _窗("洗点")
	if 页 == null or 窗 == null:
		_记(false, "前置没了（洗点主窗没开出来）⇒ 这一节整节等于没判")
		return
	var 会: Node = 窗.get("_session") as Node
	var 态: Dictionary = 会.get("player_stats") as Dictionary
	var 旧级 = int(态.get("level", 1))
	_记(not _钮(页, "开始钮").disabled, "点得动「开始洗点」（总和 2 > 0）")
	await 点钮(_钮(页, "开始钮"))
	var 弹 := _窗("洗点确认")
	_记(弹 != null and bool(弹.call("已打开")),
			"⇒ 本地开确认弹（`:242-246` new + setData + centerWindow，**不发帧**）")
	走完["洗点确认"] = true
	if 弹 == null:
		return
	_记(String(弹._title.text) == "洗点", "确认弹标题与主窗**同一个语言键**「洗点」（`:100`）")
	_记(absf(弹._window.size.x - 240.0) < 0.6 and absf(弹._window.size.y - 198.0) < 0.6,
			"外框 240×**198**（`setData:71` 稳态 = 171+22+5；构造那格 169 只在空文案时成立 ⇒ 尺寸表取稳态），"
			+ "实测 %.0f×%.0f" % [弹._window.size.x, 弹._window.size.y])
	_记(str(弹.call("取位置偏移")) == str(Vector2.ZERO),
			"弹层**居中**（`PopUpMananger.centerWindow` ⇒ 取位置偏移 == (0,0)，不参与底栏错开），实测 %s"
			% str(弹.call("取位置偏移")))
	var 弹页 := _页("洗点确认")
	_记(弹页 != null and String(弹页.name) == "原版洗点确认内容", "页根 = %s" % (弹页.name if 弹页 != null else "无"))
	if 弹页 == null:
		return
	var 参: Array[String] = []
	for v in 洗点控制器.还原数():
		参.append(str(v))
	var 期望方案 := 洗点控制器.替(方案模板, 参)
	var 实测方案 := (弹页.get_node("方案文本") as RichTextLabel).text
	_记(实测方案 == 期望方案, "方案文本 = 四项点数逐个替进逐字模板（`:1451`，两个换行、全角冒号、"
			+ "「攻击型 %%1 点：」后**有一个空格**），实测「%s」" % 实测方案)
	var 合 := 洗点控制器.总和()
	## ⚠ 第一档（>30 ⇒ 收 总和）**必须自己把等级钉过去**：`player_stats.level` 读的是
	## 与另一份同名工程共用的那份 `user://玩家数据.json`，在线腿登录过临时夹具之后那里就是 1 级
	## ⇒ 不钉就是"存档决定判哪条分支"（10-19 全量门红过）。下面那档 20 级本来就是钉的，
	## 这一档漏了 —— 同一节里两档只钉一档，也是门自己的不对称。
	态["level"] = 60
	弹.call("_render_page")
	await _等(3)
	弹页 = _页("洗点确认")
	_记((弹页.get_node("结果文本") as RichTextLabel).text == 洗点控制器.替(结果模板, [str(合), str(合)]),
			"等级钉成 60 > 30 ⇒ 消耗 = 总和 %d（`:65` `level<=30 ? 0 : 总和`，原版这里**写死 30**）" % 合)
	# 换一级再渲一次 ⇒ 另一档（真状态，不是假判据）
	态["level"] = 20
	弹.call("_render_page")
	await _等(3)
	var 弹页2 := _页("洗点确认")
	_记((弹页2.get_node("结果文本") as RichTextLabel).text == 洗点控制器.替(结果模板, [str(合), "0"]),
			"等级改成 20 ⇒ 消耗那句显示 **0**（同一支公式的另一档），实测「%s」"
			% (弹页2.get_node("结果文本") as RichTextLabel).text)
	## ⚠ 这里**不能**把等级还原回存档那一份：接着的两支判的是"要不要收洗点卷"，
	## 而 `:65` 那一支只在 `level > 30` 才收卷 —— 那份 `user://玩家数据.json` 与另一份同名工程共用，
	## 在线腿登录过临时夹具之后里面就是 1 级 ⇒ 还原成环境值会让"卷不足/有卷"两支根本走不到
	## （10-19 全量门就是这么红 3 条）。还原推到本节末尾（"取消那一支"之前那一句）。
	态["level"] = 60
	弹页2 = _页("洗点确认")
	_记(int(态.get("level", 0)) == 60, "本段两支都要 >30 ⇒ 等级先钉在 60（还原在节末）")
	# 卷不足那一支：通知逐字 + **弹层不关**（`:312-313` 只 addNotice + return）
	var 卷号 := int((游戏配置().get("needItemId", 0)))
	var 背包: Array = 会.get("inventory") as Array
	var 旧的: Array = []
	for i in range(背包.size() - 1, -1, -1):
		if int((背包[i] as Dictionary).get("id", 0)) == 卷号:
			旧的.append([i, 背包[i]])
			背包.remove_at(i)
	_清通知()
	await 点钮(_钮(弹页2, "确定钮"))
	_记(_尾通知() == 文卷不足, "背包里没有洗点卷 ⇒ 通知**逐字**（`:1545`），实测「%s」" % _尾通知())
	_记(bool(_窗("洗点确认").call("已打开")) and not _尾通知().contains("REWASH"),
			"⇒ 这一支**弹层不关**、也压根不提发帧（`:313` 直接 return）")
	# 够卷那一支：塞一枚进去 ⇒ 走 REWASH 回显 + 关弹
	背包.append({"id": 卷号, "quantity": 99})
	_清通知()
	await 点钮(_钮(弹页2, "确定钮"))
	_记(_尾通知().contains("REWASH_AP 83") and not _尾通知().contains("未连接服务端"),
			"有卷 ⇒ 点名 83 未点头（`UI.as:1143-1146`）且**没有真试过发送**，实测「%s」" % _尾通知())
	背包.remove_at(背包.size() - 1)
	_记(弹页2 != null and not bool(_窗("洗点确认").call("已打开")),
			"⇒ 这一支末尾才 `__cancel()` 收弹（`:322`）")
	_记(会.get("inventory") != null and (会.get("inventory") as Array).size() == 背包.size(),
			"临时塞的那枚洗点卷已取回，背包条数回到 %d" % 背包.size())
	# 取消那一支 + 主窗「我再想想」
	态["level"] = 旧级
	管.call("打开", "洗点确认")
	await _等(4)
	var 弹3 := _页("洗点确认")
	_清通知()
	await 点钮(_钮(弹3, "取消钮"))
	_记(not bool(_窗("洗点确认").call("已打开")) and bool(_窗("洗点").call("已打开")),
			"「取消」= 收弹、主窗留着（`:55-59` dispatch CANCEL → `__cancel:249-256`）")
	await 点钮(_钮(_页("洗点"), "再想钮"))
	_记(not bool(_窗("洗点").call("已打开")),
			"「我再想想」= 关主窗（`:325-328` 直接 `onCloseBtnClick`，**不清四行的 temp**）")


func 游戏配置() -> Dictionary:
	const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
	return 游戏数据.取表("原版杂项").get("XiDian", {}) as Dictionary


## ── ④ 徽章打造（木叶丸 / 动作 13）：两页签 + 两句缺料 ────────────────────────
func _量徽章() -> void:
	日志.append("=== 徽章打造 340×400 两页签（确定钮换字、两句缺料）===")
	_结("徽章打造")
	管.call("打开", "徽章打造")
	await _等(5)
	var 窗 := _窗("徽章打造")
	_记(窗 != null, "落地页「徽章打造」开出来了")
	if 窗 == null:
		return
	走完["徽章打造"] = true
	var 页 := _页("徽章打造")
	_记(页 != null and String(页.name) == "原版徽章打造内容", "页根 = %s" % (页.name if 页 != null else "无"))
	if 页 == null:
		return
	_记(String(窗._title.text) == "徽章打造合成",
			"标题「徽章打造合成」（`:139` BEASTBADGE_WINDOW_TITTLE :507，⚠ 键名拼错 TITTLE 照抄）"
			+ "—— 与菜单行「徽章打造」不是一个词，实测「%s」" % String(窗._title.text))
	_记(absf(窗._window.size.x - 340.0) < 0.6 and absf(窗._window.size.y - 400.0) < 0.6,
			"外框 340×400（`:33` `super(340,400,false)`、全链没有 setSize），实测 %.0f×%.0f"
			% [窗._window.size.x, 窗._window.size.y])
	var 底 = 窗._content_bg
	_记(底 != null and not bool(底.visible), "宿主的 内容底 **不显形**（第三参 false ⇒ 底由页面烘在 `内容底` 上）")
	var 黄底 := 页.get_node("内容底") as NinePatchRect
	_记(absf(黄底.position.x - 5.0) < 0.6 and absf(黄底.position.y - 31.0) < 0.6
			and absf(黄底.size.x - 330.0) < 0.6 and absf(黄底.size.y - 310.0) < 0.6,
			"内容底 (5,60)→页内 (5,31) 330×310（`:147-152` `宽−10 / 高−90`），实测 %s %s"
			% [str(黄底.position), str(黄底.size)])
	_记((页.get_node("页签条") as Node).get_index() < (黄底 as Node).get_index(),
			"层序：**页签条 早于 内容底**（`:146` 先于 `:152`）⇒ 重叠那 2px 由底压页签，这是原版的形状")
	_记(_钮(页, "页签条/页签0").text == "打造石合成" and _钮(页, "页签条/页签1").text == "徽章强化",
			"两枚页签文字逐字（CREATESTONE :2873 / BEASTBADGE_CREATE :594 —— ⚠ 后者键名叫 CREATE、"
			+ "文字是「徽章强化」）实测「%s」「%s」" % [_钮(页, "页签条/页签0").text, _钮(页, "页签条/页签1").text])
	# 开屏：页 0 选中（`init(param1 = 0)`）
	_记(徽章控制器.当前页() == 0 and _钮(页, "页签条/页签0").disabled and _钮(页, "页签条/页签0").button_pressed
			and bool((页.get_node("内容层/面板0") as Control).visible)
			and not bool((页.get_node("内容层/面板1") as Control).visible),
			"开屏页 0 =「打造石合成」：该枚走 disabled 槽（= 选中皮）、只有面板0 显形")
	_记(_皮(_钮(页, "页签条/页签0"), "disabled") == "分页按钮选中.png",
			"选中枚的皮 = selectedUpSkin 那张**真皮**（tag118），不是灰度近似（`flash-mbutton3-state-skins` §4.2）")
	_记(_钮(页, "确定钮").text == "开始合成" and absf(_钮(页, "确定钮").size.x - 61.0) < 0.6,
			"确定钮开屏「开始合成」（`:67` CREATESTONE_START_BTN :2881）、宽 61（btn_width_four），实测「%s」%.0f"
			% [_钮(页, "确定钮").text, _钮(页, "确定钮").size.x])
	# 材料盒那枚格：开屏就是灰的、没有图标（`huiZhangStageUp` 没有键 "2" ⇒ `:179-181` 早退）
	var 盒格 := 页.get_node("内容层/面板1/材料盒/材料盒格") as NinePatchRect
	_记(盒格 != null and (盒格 as CanvasItem).material != null,
			"材料盒格挂了 `禁用灰度.gdshader`（`ItemCaiLiaoBox.applyGrayFilter`）⇒ 离线必须灰")
	_记(盒格.get_children().size() == 1
			and String(盒格.get_child(0).name).ends_with("_数量")
			and (盒格.get_child(0) as Label).text == " ",
			"格内只有「空格角标」一层 —— **不假造图标**（查无配置就是一个结论）")
	_记((页.get_node("内容层/面板1/材料盒/材料盒名") as Label).text == "徽章打造石"
			and (页.get_node("内容层/面板1/材料盒/材料盒名") as Label).horizontal_alignment
			== HORIZONTAL_ALIGNMENT_CENTER,
			"材料盒名「徽章打造石」BEASTBADGE_STONE :81、居中（`ItemCaiLiaoBox.as:130-139` align=center）")
	_记((页.get_node("内容层/面板0/石页竖题") as Label).text == "合\n成\n结\n果",
			"竖排那列「合\\n成\\n结\\n果」逐字（CREATESTONE_RESULT :1869，语言键里就带的换行）")
	# 切页 → 换面板 + 换确定钮文字
	await 点钮(_钮(页, "页签条/页签1"))
	_记(徽章控制器.当前页() == 1 and _钮(页, "确定钮").text == "开始打造"
			and bool((页.get_node("内容层/面板1") as Control).visible)
			and not bool((页.get_node("内容层/面板0") as Control).visible),
			"点页签1 ⇒ 只有面板1 显形、确定钮换「开始打造」（HUIZAHNG_START :3066），实测「%s」"
			% _钮(页, "确定钮").text)
	_记(_钮(页, "页签条/页签0").disabled == false and _钮(页, "页签条/页签1").disabled,
			"⇒ 选中枚换到第 2 枚（旧的回到亮的未选皮）")
	# 两句缺料：页1「请放入装备！」
	_清通知()
	await 点钮(_钮(页, "确定钮"))
	# ⚠️ 2026-10-11 改：这两句现在**只说缺料**（不再附带"原版发 1040 子命令 N ⇒ 本工程未接"）——
	#    因为那一跳**接上了**（有料时真发 26/27）。没料这一支的行为没变：只回显、不发帧。
	_记(_尾通知() == 缺料文[1],
			"页1 没料点确定 ⇒ 逐字「%s」（`:219` `_6[0]` 替 `_6[1]`=装备），实测「%s」"
			% [缺料文[1], _尾通知()])
	# 页0「请放入徽章打造石！」
	await 点钮(_钮(页, "页签条/页签0"))
	_清通知()
	await 点钮(_钮(页, "确定钮"))
	_记(_尾通知() == 缺料文[0],
			"页0 没料点确定 ⇒ 逐字「%s」（`:220` `_6[0]` 替 BEASTBADGE_STONE），实测「%s」"
			% [缺料文[0], _尾通知()])
	_记(not _尾通知().contains("未连接服务端"), "没料那一支只是回显 ⇒ **一条帧都没试过发**")
	# 两枚放入钮：没料时只说「背包里没有可放入的…」，弹层**不弹**、也不发帧
	# （原版那一支是 `UpShelfCursor` 收集态；本工程 = 有料弹「放入选择」清单，见 §3.385）
	for 项 in [[0, "石页放入钮", "放入打造石", "背包里没有可放入的徽章打造石"],
			[1, "徽页放入钮", "放入徽章", "背包里没有可放入的徽章"]]:
		# ⚠️ 先切到那一页：两页面板叠在同一个矩形里，没显示的那页 hidden ⇒ 鼠标会落到
		#    另一页同位置的钮上（旧文案两页一模一样，这条坑一直没露出来）。
		await 点钮(_钮(页, "页签条/页签%d" % 项[0]))
		_清通知()
		var 钮 := _钮(页, 徽章控制器.放入路[项[0]])
		await 点钮(钮)
		_记(钮.text == String(项[2]), "%s 文字「%s」逐字（CREATESTONE_INPUT_BTN :105 / BEASTBADGE_INPUT_BTN :3335）"
				% [项[1], 项[2]])
		_记(_尾通知() == String(项[3]) and not _尾通知().contains("未连接服务端"),
				"没料时点 %s ⇒ 只说「%s」、不发帧，实测「%s」" % [项[1], 项[3], _尾通知()])
		_记(页.get_node_or_null("放入选择") == null, "%s 无候选时不该弹「放入选择」清单" % 项[1])
	_记(_钮(页, "内容层/面板0/石页投料盒/石页放入钮").size.x > 62.0,
			"石页放入钮宽 66 = `btn_width_four + 5`（`StoneComposePane.as:156` 那一行覆盖）⇒ 与徽页的 61 **不同**，"
			+ "实测 %.0f" % _钮(页, "内容层/面板0/石页投料盒/石页放入钮").size.x)
	管.call("打开或收起", "徽章打造")


func _皮2(件: Control) -> String:
	var 皮 := (件 as NinePatchRect).texture as Texture2D
	return String(皮.resource_path).get_file() if 皮 != null else "无"


## ── ⑤ 成对面：两页连背包、一页不连 ─────────────────────────────────────────
func _量成对面() -> void:
	日志.append("=== centerTwoWindow：生命料理/徽章打造 连背包、洗点不连 ===")
	_结("成对面")
	管.call("全部关闭")
	await _等(3)
	管.call("打开", "洗点")
	await _等(4)
	var 包 := _窗("背包")
	_记(包 == null or not bool(包.call("已打开")),
			"开「洗点」**不带出背包**（`Client.as:5908-5910` 走 `setDOShow(WASH_POINT_WINDOW_F)`、"
			+ "没有 centerTwoWindow）⇒ 这页名不许进 伴随背包")
	管.call("全部关闭")
	await _等(3)
	管.call("打开", "生命料理")
	await _等(4)
	var 主 := _窗("生命料理")
	包 = _窗("背包")
	_记(主 != null and 包 != null and bool(包.call("已打开")), "开「生命料理」⇒ 背包一起开（`UIMain2.as:3939`）")
	if 主 != null and 包 != null:
		var a: Vector2 = (主 as Node).get_node("遮罩/主窗口").global_position
		var b: Vector2 = (包 as Node).get_node("遮罩/主窗口").global_position
		# 原版 `:3170-3171` 是「主窗按自己高度居中、伙伴 y = 主.y」。2026-10-31 起背包 556 高
		# （10 行一屏全露）⇒ 跟 319 高的生命料理居中共会垂出下沿，所以背包单独夹进屏内
		# （y = 560-556 = 4），**顶边不再平齐**（有意偏离，见 `窗口管理.成对摆位`）。
		# 期望写死：主 (560-319)/2 = 120，背包 4。
		_记(absf(a.y - 120.0) < 1.2 and absf(b.y - 4.0) < 1.2,
				"主窗（319 高）按自己高度居中 y = 120、背包（556 高）夹进屏内 y = 4，实测 %.1f / %.1f"
				% [a.y, b.y])
		_记(absf((b.x) - (a.x + 241.0 + 1.0)) < 1.2,
				"背包紧贴主窗右侧 **1px**（`:3172-3175` 总宽 = 主 + 包 + 1），实测 dx=%.1f（应 %.1f）"
				% [b.x - a.x, 242.0])
	管.call("全部关闭")
	await _等(3)
	管.call("打开", "徽章打造")
	await _等(4)
	var 主2 := _窗("徽章打造")
	包 = _窗("背包")
	_记(主2 != null and 包 != null and bool(包.call("已打开")), "开「徽章打造」⇒ 背包一起开（`UIMain2.as:4563`）")
	if 主2 != null and 包 != null:
		var a2: Vector2 = (主2 as Node).get_node("遮罩/主窗口").global_position
		var b2: Vector2 = (包 as Node).get_node("遮罩/主窗口").global_position
		# 同上：主 (560-400)/2 = 80，背包（556 高）夹进屏内 4；右贴 1px（主宽 340）不变。
		_记(absf(a2.y - 80.0) < 1.2 and absf(b2.y - 4.0) < 1.2
				and absf(b2.x - (a2.x + 340.0 + 1.0)) < 1.2,
				"主窗（400 高）居中 y = 80、背包夹进屏内 y = 4、右贴 1px（主宽 340），实测 y %.1f/%.1f dx=%.1f"
				% [a2.y, b2.y, b2.x - a2.x])
	管.call("全部关闭")


## ── ⑥ 烘值（读 `.tscn` 文本）：开屏 disabled / 灰皮 / 空格角标 / 灰化材质 ─────
func _量烘值() -> void:
	日志.append("=== 烘值（编辑器 == 运行期第一帧）===")
	_结("烘值")
	var 洗 := FileAccess.get_file_as_string(洗点场景)
	_记(_节(洗, "开始钮").contains("disabled = true"),
			"洗点窗.tscn：开始钮 烘了 `disabled = true`（`:191` 的开屏态，编辑器里就看着是灰的）")
	var 八对 := true
	for i in 4:
		for 名 in ["全收钮", "加钮"]:
			if not _节(洗, "行%d%s" % [i, 名]).contains("disabled = true"):
				八对 = false
	_记(八对, "四行的 全收/加 八枚都烘了 `disabled = true`（`temp=0` 时那组恒禁用，与数据无关）")
	var 两对 := true
	for i in 4:
		for 名 in ["减钮", "全放钮"]:
			if _节(洗, "行%d%s" % [i, 名]).contains("disabled = true"):
				两对 = false
	_记(两对, "四行的 减/全放 **没有**烘 disabled（开屏是亮的；只有基数为 0 那一行才由运行期压灰）")
	var 灰对 := true
	for 名 in ["开始钮", "全收钮", "加号钮", "减号钮"]:
		if not FileAccess.file_exists("res://素材/界面/原版窗口/洗点/%s_禁用.png" % 名):
			灰对 = false
	_记(灰对, "四张 `*_禁用.png` 在盘上（`getGrayFilter` 预烘，`MButton3.as:333-339` 禁用染的是 upSkin、"
			+ "库里没有第二张皮）⇒ 少了它 `disabled=true` 会掉到 Godot 主题默认灰框")
	_记(_节(洗, "行0全收钮").contains("theme_override_styles/disabled = SubResource"),
			"行钮接了 disabled 槽（烘在场景里，不是运行期才挂）")
	var 料 := FileAccess.get_file_as_string(料理场景)
	_记(_节(料, "消耗数值").contains('text = "2000"'),
			"生命料理.tscn：消耗数值 烘 2000（静态配置），色烘常态 #ffffff（红色是运行期按金币现判）")
	## ⚠ 箭头那格的皮**不在节点块里** —— `.tscn` 只在节点上写 `ExtResource("t6")`，路径在文件头的
	## `[ext_resource … id="t6"]` 那一行。旧判据拿节点块找 `料理箭头.png` ⇒ 永远找不到（判据自己的错，
	## 不是场景缺图）。⇒ 先把引用号解出来，再回文件头解成路径来判。
	var 箭块 := _节(料, "料理箭头")
	var 箭路 := _ext路(料, _引用号(箭块))
	_记(箭块 != "" and 箭路.contains("生命料理/料理箭头.png"),
			"箭头皮 = 从**外挂** `UISwf_LiaoLi.swf` symbol 3 导的那张（MainLib 里查无此图 ⇒ 别在 MainLib 找），实测 %s" % 箭路)
	var 徽 := FileAccess.get_file_as_string(徽章场景)
	_记(_节(徽, "页签0").contains("disabled = true") and _节(徽, "页签0").contains("button_pressed = true")
			and not _节(徽, "页签1").contains("disabled = true"),
			"徽章打造.tscn：页签0 烘成选中态（disabled+pressed）、页签1 没有 ⇒ 开屏页 0 与运行期一致")
	_记(徽.contains('path="res://脚本/界面/组件/禁用灰度.gdshader"'),
			"灰化材质指回**共用那份** shader（与 意志/兑换商店 同一系数）")
