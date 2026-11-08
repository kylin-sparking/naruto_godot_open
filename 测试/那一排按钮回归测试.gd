extends SceneTree

## #185 行为门：精华容器上那一排四颗钮（打坐 / 通灵附身 / 领取修行收益 / 挂机）
## **像不像原版、点下去到底干什么**。
##
## 真值（逐条到行号，详表见 `真值/窗口/那一排按钮.md`）：
##   · 数据源 = `2.2.3\logs\swfprobe`
##   · 元件时间轴 `MainLib.xml` 符号 335 `BreathPaneF`：四颗 `#322/#326/#330/#334` 在
##     (99,7)/(140,7)/(181,7)/(222,7)、各自包围盒 31×37、注册点 (0,0) ⇒ 摆位就是**左上角**；
##     每颗时间轴里**只有 `upSkin`、没有 `selectedUpSkin`** ⇒ 只有一组三态，点下不换第二张皮。
##   · 符号 308 `BreathPane1F`（收起版）四颗 17×17 运行期建，`BreathPane1.as:38-53` x=0/18/45/63、y=15。
##   · `BreathPane.as:61-131` 四颗的动作：打坐=`healHandler.triggerHealState()`、
##     宠物=`petHandler.fuShenOrHuiShouPet()`、闭关=`showLingquPane()`+BIGUAN_GAIN、
##     挂机=`guajiHandler.isStart = !isStart`。
##     ⚠ `BreathPane1.as:70-79` 同一颗的 `__biGuanExp` 调的是 `showBiguanWindow()` ——
##     **展开版开「领取修行收益」、收起版开「修行设定与收益」**，这是原版自己的分工。
##   · `HealHandler.as:363-374` + `:344-348`、`GuajiHandler.as:1027-1037` 各有一道 1 秒防抖。
##   · `PetHandler.as:210-233` + `PetDataManage.as:165-190`：没宠⇒「你还没有通灵兽！」；
##     有已召唤的那只⇒收回；否则取第一只**在袋里**且**等级够携带**的⇒附身；都没有⇒「没有可以附身的通灵兽！」
##   · 文案 `CN.MENU_PRACTISE_BTN_TIP_TEXT_1..4` + `CN.KEYBOARD_SHORTCUT_KEY`（"快速键：无"）。
##
## 三条口径：
##   1) 交互态一律**换 `texture_normal`**，`texture_hover/pressed/disabled` 必须留着空 ——
##      原版松手回 `STATE_UP`（`MButton3.as:103-108`），Godot 的 hover 槽会在松手后把图顶回去。
##   2) 派生皮逐像素必须 == `clamp(常态 rgb ±30/−40)`、alpha 原样 —— 这条在门里算，不靠"看着像"。
##   3) 打坐**不许染按钮**：原版的反馈是角色坐下，`self_modulate` 必须恒为白。
##
## ⚠ 本门会点挂机/附身 ⇒ 会话层会落 `user://玩家数据.json` ⇒ **动手前整份快照、收尾按字节还原**，
##   再断言还原后与快照一致（隔壁「精华容器行为门」全程不落盘，它那侧判的是"没变"）。
##
## 跑：Godot --headless --path . --script res://测试/那一排按钮回归测试.gd

const 出 := "res://测试/截图/追踪栏/那一排按钮行为.txt"
const 面板场景 := "res://场景/界面/技能面板.tscn"
const 存档 := "user://玩家数据.json"
const 皮目录 := "res://素材/界面/技能面板/"
const 防抖复位 := -1000000
## 每次真点之前先把鼠标挪到这里：**同一个位置重复发 motion 不会重发 `mouse_entered`**，
## 上一颗松手后鼠标还停在原处 ⇒ 再点同一颗时"悬停换皮"那一步采不到（10-12 实测）。
const 躲开位 := Vector2(6, 6)

## 语言表原句（message 包，`LangUtil.get`）—— 抄在这里当判据，每个字都有出处
const 提示打坐 := "打坐/取消打坐"
const 提示附身 := "通灵附身/取消附身"
const 提示领取 := "领取修行收益"
const 提示挂机 := "挂机/取消挂机"
const 键尾 := "，快速键：无"		# CN.KEYBOARD_SHORTCUT_KEY = "快速键：无"
const 提示没有通灵兽 := "你还没有通灵兽！"
const 提示没有可附身 := "没有可以附身的通灵兽！"

## [节点名, 常态皮主干, 元件号, 期望 x, 提示句]
## x = 元件里的 (99/140/181/222) + breathPane 在 MenuPane 的 441 − 本栏 menuBg 左移的 11
const 大钮表 := [
	["打坐Button", "hud_319", "322", 529.0, 提示打坐],
	["宠物Button", "hud_323", "326", 570.0, 提示附身],
	["闭关经验Button", "hud_327", "330", 611.0, 提示领取],
	["挂机Button", "hud_331", "334", 652.0, 提示挂机],
]
## 收起版 [节点名, 常态皮主干, UISwf_Text 符号名, 期望 x, 动作身份]
const 小钮表 := [
	["坐Button", "收起钮_坐", "PractiseBtn2Skin", 0.0, "practise"],
	["附Button", "收起钮_附", "PetBtn2Skin", 18.0, "pet"],
	["修Button", "收起钮_修", "BiGuanExpBtn2Skin", 45.0, "biguan_window"],
	["挂Button", "收起钮_挂", "GuaJiBtn2Skin", 63.0, "hang"],
]
## 折叠箭头是同一族的第九张皮（#184 烘的），一并核文件级，防"改了一处、另一处坏了没人发现"
const 其余皮 := ["精华折叠钮"]

var 日志: Array[String] = []
var 判 := 0
var 红 := 0
var 收 := false
var 存前 := PackedByteArray()
var 会: Node = null			# GameSession 单例（`_喂宠` 那一条要写它的 typed 数组）
var 页: Array[String] = []		# feature_requested 收到的页名
var 话: Array[String] = []		# notification_requested 收到的提示


## `游戏会话.pets` 声明的是 `Array[Dictionary]` ⇒ 直接赋一条**普通 Array** 会运行期报
## `Invalid assignment of property or key 'pets'`，而 `_跑` 是协程 —— 报错当场断掉，
## 后面几十条**一条都不跑**，门看着只是"卡到看门狗"（10-12 实测踩过）。这里过一道类型。
func _喂宠(表: Array) -> void:
	var 出: Array[Dictionary] = []
	for 项 in 表:
		出.append(项 as Dictionary)
	会.pets = 出


func _判(过: bool, 说: String) -> void:
	判 += 1
	日志.append("%s %s" % ["ok " if 过 else "!!红", 说])
	if not 过:
		红 += 1
	_写()


func _步(说: String) -> void:
	日志.append("· " + 说)
	_写()


func _写() -> void:
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(日志) + "\n")
		f.close()


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _字节() -> PackedByteArray:
	if not FileAccess.file_exists(存档):
		return PackedByteArray()
	var g := FileAccess.open(存档, FileAccess.READ)
	if g == null:
		return PackedByteArray([1])
	var 字 := g.get_buffer(g.get_length())
	g.close()
	return 字


func _看门狗() -> void:
	var 截止 := Time.get_ticks_msec() + 420000
	while Time.get_ticks_msec() < 截止:
		if not 日志.is_empty() and str(日志[日志.size() - 1]).begins_with("汇"):
			return
		await create_timer(0.2).timeout
	if 收:
		return
	_判(false, "看门狗：420 秒没跑到汇总（看最后一条停在哪一步）")
	_尾()


func _initialize() -> void:
	存前 = _字节()
	call_deferred("_跑")
	call_deferred("_看门狗")


## 派生皮这一档的**期望值**：全透像素 rgb 不动（Flash 走预乘 alpha），
## 其余逐通道 `clamp(rgb + 偏移)`，alpha 原样。
func _期色(a: Color, 偏移: int) -> Color:
	if a.a == 0.0:
		return a
	return Color(clampf(a.r * 255.0 + float(偏移), 0.0, 255.0) / 255.0,
			clampf(a.g * 255.0 + float(偏移), 0.0, 255.0) / 255.0,
			clampf(a.b * 255.0 + float(偏移), 0.0, 255.0) / 255.0, a.a)


func _移到(位: Vector2, 隔: int) -> void:
	var 鼠 := InputEventMouseMotion.new()
	鼠.position = 位
	鼠.global_position = 位
	root.push_input(鼠)
	await _帧(隔)


## 真点：挪开 → 挪进（**同一位置重复发 motion 不会重发 `mouse_entered`**，
## 上一颗松手后鼠标还停在原处，直接再点就采不到"悬停换皮"那一步 —— 10-12 实测踩过）
## → 按下 → 松手（`pressed` 在松手那一步才发）→ 再挪开。顺路把三态皮一起核掉。
func _点(钮: Control, 基名: String) -> void:
	var 位 := 钮.get_global_rect().get_center()
	await _移到(躲开位, 2)
	await _移到(位, 3)
	_判(root.gui_get_hovered_control() == 钮,
			"%s 悬停拾取到的是它自己（没被别的件吃掉）—— 实得 %s" % [钮.name, str(root.gui_get_hovered_control())])
	_判(String(钮.texture_normal.resource_path).ends_with("%s_悬停.png" % 基名),
			"%s 悬停换的是烘出来的 +30 皮 —— 实得 %s" % [钮.name, String(钮.texture_normal.resource_path).get_file()])
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.position = 位
	按.global_position = 位
	按.pressed = true
	root.push_input(按)
	await _帧(3)
	_判(String(钮.texture_normal.resource_path).ends_with("%s_按下.png" % 基名),
			"%s 按住那一步换的是 −40 皮 —— 实得 %s" % [钮.name, String(钮.texture_normal.resource_path).get_file()])
	按.pressed = false
	root.push_input(按)
	await _帧(3)
	_判(String(钮.texture_normal.resource_path).ends_with("%s.png" % 基名),
			"%s **松手回常态**（原版回 STATE_UP，不是回 hover）—— 实得 %s" % [
				钮.name, String(钮.texture_normal.resource_path).get_file()])
	await _移到(躲开位, 2)


## 只负责"真点一下"，不核三态皮 —— 给底栏那种**没有派生皮**的对照件用。
func _只按(钮: Control) -> void:
	var 位 := 钮.get_global_rect().get_center()
	await _移到(躲开位, 2)
	await _移到(位, 3)
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.position = 位
	按.global_position = 位
	按.pressed = true
	root.push_input(按)
	await _帧(2)
	按.pressed = false
	root.push_input(按)
	await _帧(3)
	await _移到(躲开位, 2)


## 每段前面打一条**带秒数**的行：这道门真点二十来次，跑不动时要能一眼看出卡在哪段
## （10-12 第一版就是 150 秒看门狗先响，事后看不出是像素段慢还是点击段慢）。
func _时(说: String) -> void:
	_步("[%.1fs] %s" % [Time.get_ticks_msec() / 1000.0, 说])


func _跑() -> void:
	root.size = Vector2i(960, 560)
	会 = root.get_node_or_null("GameSession")
	_判(会 != null, "拿得到 GameSession 单例")
	if 会 == null:
		_尾()
		return
	会.feature_requested.connect(func(名: String) -> void: 页.append(名))
	会.notification_requested.connect(func(文: String) -> void: 话.append(文))

	# ── ① 文件级：九张常态皮的 18 张派生态，逐像素 == clamp(常态 ±30/−40)
	_时("① 文件级像素")
	var 皮表: Array = []
	for 行 in 大钮表:
		皮表.append(String(行[1]))
	for 行 in 小钮表:
		皮表.append(String(行[1]))
	for 名 in 其余皮:
		皮表.append(名)
	for 基名 in 皮表:
		var 常 := Image.load_from_file("%s%s.png" % [皮目录, 基名])
		_判(常 != null, "常态皮读得到：%s.png" % 基名)
		if 常 == null:
			continue
		常.convert(Image.FORMAT_RGBA8)
		for 对 in [["悬停", 30], ["按下", -40]]:
			var 派 := Image.load_from_file("%s%s_%s.png" % [皮目录, 基名, String(对[0])])
			if 派 == null:
				_判(false, "%s 缺 %s 皮（少一张 ⇒ 那颗钮静默没有这一态）" % [基名, 对[0]])
				continue
			派.convert(Image.FORMAT_RGBA8)
			_判(派.get_size() == 常.get_size(), "%s_%s.png 尺寸与常态一致（%s vs %s）" % [
					基名, 对[0], 派.get_size(), 常.get_size()])
			var 不符 := 0
			var 偏移 := int(对[1])
			for y in 常.get_height():
				for x in 常.get_width():
					var a := 常.get_pixel(x, y)
					var b := 派.get_pixel(x, y)
					if _到255(b) != _到255(_期色(a, 偏移)):
						不符 += 1
			_判(不符 == 0, "%s_%s.png 逐像素 == clamp(常态%+d)、alpha 原样（不符 %d 个）" % [
					基名, 对[0], 偏移, 不符])

	# ── ② 场景里烘死的值（读 .tscn 文本，与运行期两条独立腿）
	_时("② 场景烘值")
	var 文 := ""
	var t := FileAccess.open(面板场景, FileAccess.READ)
	if t != null:
		文 = t.get_as_text()
		t.close()
	_判(not 文.is_empty(), "读到了场景文本（编辑器一致那条要有底本）")
	for 行 in 大钮表:
		var 段 := _节(文, String(行[0]))
		_判(段.contains("offset_left = %.1f" % float(行[3])),
				"%s 烘在 x=%.0f（元件 %s 的时间轴换算，不是运行期挪的）—— 该段：%s" % [
					行[0], float(行[3]), 行[2], _一行(段, "offset_left")])
		_判(段.contains("offset_top = 7.0"), "%s 烘在 y=7（元件时间轴 y=7）—— %s" % [
				行[0], _一行(段, "offset_top")])
		_判(段.contains("tooltip_text = \"%s%s\"" % [行[4], 键尾]),
				"%s 的提示烘的是原句「%s%s」—— %s" % [行[0], 行[4], 键尾, _一行(段, "tooltip_text")])
		_判(段.contains("mouse_default_cursor_shape = 2"), "%s 烘了手型（原版 buttonMode=useHandCursor）" % 行[0])

	# ── ③ 运行期：几何 / 皮 / 空槽 / 不染色 / 只连一条
	_时("③ 运行期几何")
	var 景: Node = (load(面板场景) as PackedScene).instantiate()
	root.add_child(景)
	await _帧(10)
	var 栏 := 景.get_node_or_null("技能栏") as Control
	_判(栏 != null, "技能栏在")
	if 栏 == null:
		_尾()
		return
	var 大: Dictionary = {}
	for 行 in 大钮表:
		var 钮 := 栏.get_node_or_null(String(行[0])) as TextureButton
		_判(钮 != null, "展开版有 %s" % 行[0])
		if 钮 == null:
			continue
		大[String(行[0])] = 钮
		_判(absf(钮.offset_left - float(行[3])) < 0.5 and absf(钮.offset_top - 7.0) < 0.5
				and absf(钮.size.x - 31.0) < 0.5 and absf(钮.size.y - 37.0) < 0.5,
				"%s 矩形 = (%.0f,7) 31×37（元件 %s 的皮肤天然尺寸）—— 实得 (%.0f,%.0f,%.0f,%.0f)" % [
					行[0], float(行[3]), 行[2], 钮.offset_left, 钮.offset_top, 钮.size.x, 钮.size.y])
		_判(String(钮.texture_normal.resource_path).ends_with("%s.png" % 行[1]),
				"%s 的常态皮就是元件 %s 那张 upSkin（%s.png）—— 实得 %s" % [
					行[0], 行[2], 行[1], String(钮.texture_normal.resource_path).get_file()])
		_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
				"%s 悬上去是手型 —— 实得 %s" % [行[0], str(钮.mouse_default_cursor_shape)])
		_判(钮.texture_hover == null and 钮.texture_pressed == null and 钮.texture_disabled == null,
				"%s 的 hover/pressed/disabled 三槽留空（口径=只换 texture_normal）" % 行[0])
		_判(String(钮.tooltip_text) == "%s%s" % [行[4], 键尾],
				"%s 提示 = 「%s%s」—— 实得「%s」" % [行[0], 行[4], 键尾, 钮.tooltip_text])
		_判(钮.self_modulate == Color(1, 1, 1, 1) and 钮.modulate == Color(1, 1, 1, 1),
				"%s 没被染色（原版这四颗没有选中态）" % 行[0])
		# 只在一个地方连 ⇒ #200 那批"每次进图刷 already connected"在这里被结构性堵掉
		_判(钮.pressed.get_connections().size() == 1,
				"%s 的 pressed 只连 1 条（实得 %d 条）" % [行[0], 钮.pressed.get_connections().size()])
	_判(absf((大["宠物Button"] as TextureButton).offset_left - (大["打坐Button"] as TextureButton).offset_left - 41.0) < 0.5
			and absf((大["挂机Button"] as TextureButton).offset_left - (大["闭关经验Button"] as TextureButton).offset_left - 41.0) < 0.5,
			"四颗的步距恒 41（元件 99/140/181/222 的间距，31 宽 + 10 缝）")

	var 收起 := 栏.get_node_or_null("精华收起") as Control
	_判(收起 != null, "收起版在")
	var 小: Dictionary = {}
	if 收起 != null:
		for 行 in 小钮表:
			var 钮 := 收起.get_node_or_null(String(行[0])) as TextureButton
			_判(钮 != null, "收起版有 %s" % 行[0])
			if 钮 == null:
				continue
			小[String(行[0])] = 钮
			_判(absf(钮.offset_left - float(行[3])) < 0.5 and absf(钮.offset_top - 15.0) < 0.5
					and absf(钮.size.x - 17.0) < 0.5 and absf(钮.size.y - 17.0) < 0.5,
					"%s 矩形 = (%.0f,15) 17×17（BreathPane1.as:38-53）—— 实得 (%.0f,%.0f,%.0f,%.0f)" % [
						行[0], float(行[3]), 钮.offset_left, 钮.offset_top, 钮.size.x, 钮.size.y])
			_判(String(钮.texture_normal.resource_path).ends_with("%s.png" % 行[1]),
					"%s 的常态皮 = UISwf_Text 的 %s —— 实得 %s" % [
						行[0], 行[2], String(钮.texture_normal.resource_path).get_file()])
			_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "%s 悬上去是手型" % 行[0])
			_判(钮.texture_hover == null and 钮.texture_pressed == null, "%s 的 hover/pressed 两槽留空" % 行[0])
			_判(钮.pressed.get_connections().size() == 1, "%s 的 pressed 只连 1 条" % 行[0])

	# ── ④ 打坐：真点 + 防抖 + 不染色（反馈在角色身上，不在按钮上）
	_时("④ 打坐")
	var 码 := GDScript.new()
	码.source_code = "extends Node\nvar 次 := 0\nfunc toggle_practise() -> bool:\n\t次 += 1\n\treturn 次 % 2 == 1\nfunc set_practising(_v: bool) -> void:\n\tpass\n"
	码.reload()
	var 假角: Node = 码.new()
	假角.name = "玩家夹具"
	root.add_child(假角)
	假角.add_to_group("player")
	景.set("_player", 假角)
	景.set("_上次打坐毫秒", 防抖复位)
	await _点(大["打坐Button"], "hud_319")
	_判(int(假角.get("次")) == 1, "真点打坐钮 ⇒ 角色切了一次打坐（离线走 玩家.toggle_practise）—— 实得 %d 次" % int(假角.get("次")))
	await _点(大["打坐Button"], "hud_319")
	_判(int(假角.get("次")) == 1, "1 秒内再点被防抖吃掉（HealHandler.as:345 的 requestCDlast=1000）—— 实得 %d 次" % int(假角.get("次")))
	_判((大["打坐Button"] as TextureButton).self_modulate == Color(1, 1, 1, 1),
			"打过坐之后按钮**仍然没染色**")
	景.set("_上次打坐毫秒", 防抖复位)
	await _点(大["打坐Button"], "hud_319")
	_判(int(假角.get("次")) == 2, "过了防抖再点 ⇒ 第二次生效 —— 实得 %d 次" % int(假角.get("次")))

	# ── ⑤ 通灵附身：原版三条分支逐个走（这颗**不开宠物窗**）
	_时("⑤ 附身")
	_喂宠([])
	话.clear()
	await _点(大["宠物Button"], "hud_323")
	_判(话.size() == 1 and 话[0] == 提示没有通灵兽,
			"一只通灵兽都没有 ⇒「%s」（PetHandler.as:212-216）—— 实得 %s" % [提示没有通灵兽, str(话)])
	_判(页.is_empty(), "点宠物钮**不该**打开任何功能页（原版这颗不开窗）—— 实得 %s" % str(页))
	_喂宠([{"id": "00000102", "item_id": 102, "unique_id": 77, "level": 1,
			"attached": false, "deployed": false}])
	会.player_stats["level"] = 5
	话.clear()
	await _点(大["宠物Button"], "hud_323")
	_判(not bool((会.pets[0] as Dictionary).get("attached", false)) and 话.size() == 1 and 话[0] == 提示没有可附身,
			"玩家 5 级 < 携带等级 20 ⇒ 等级闸拦住、只弹「%s」（而且不弹等级不足那条）—— attached=%s 提示=%s" % [
				提示没有可附身, str((会.pets[0] as Dictionary).get("attached")), str(话)])
	会.player_stats["level"] = 60
	话.clear()
	await _点(大["宠物Button"], "hud_323")
	_判(bool((会.pets[0] as Dictionary).get("attached", false)) and 话.is_empty(),
			"等级够了 ⇒ 附身那只在袋里的通灵兽、不再弹提示 —— attached=%s 提示=%s" % [
				str((会.pets[0] as Dictionary).get("attached")), str(话)])
	await _点(大["宠物Button"], "hud_323")
	_判(not bool((会.pets[0] as Dictionary).get("attached", false)),
			"已召唤着再点 ⇒ 收回（PetHandler.as:224-227 的 requestCallBackPet）")
	_喂宠([{"id": "00000103", "item_id": 103, "unique_id": 88, "level": 1,
			"attached": false, "deployed": true},
			{"id": "00000101", "item_id": 101, "unique_id": 99, "level": 1,
			"attached": false, "deployed": false}])
	话.clear()
	await _点(大["宠物Button"], "hud_323")
	_判(bool((会.pets[1] as Dictionary).get("attached", false))
			and not bool((会.pets[0] as Dictionary).get("attached", false)),
			"出战中那枚(position=125 ⇔ STATUS_ATTACK)原版这一族**不碰** ⇒ 附身的是在袋里的那只")
	_喂宠([{"id": "00000999", "item_id": 999, "unique_id": 5, "level": 1,
			"attached": false, "deployed": false}])
	话.clear()
	await _点(大["宠物Button"], "hud_323")
	_判(bool((会.pets[0] as Dictionary).get("attached", false)) and 话.is_empty(),
			"模板查无(999) ⇒ 原版 `getPetCarryLevel` 回 0 ⇒ 携带等级不设闸、照样附身 —— attached=%s 提示=%s" % [
				str((会.pets[0] as Dictionary).get("attached")), str(话)])
	_喂宠([])

	# ── ⑥ 第三颗：两版开的**不是同一扇**
	_时("⑥ 两版第三颗")
	页.clear()
	await _点(大["闭关经验Button"], "hud_327")
	_判(页 == ["领取修行收益"], "展开版第三颗 ⇒ 开「领取修行收益」（showLingquPane）—— 实得 %s" % str(页))
	页.clear()
	景.call("_切换精华")
	await _帧(2)
	await _点(小["修Button"], "收起钮_修")
	_判(页 == ["闭关经验"], "收起版同一颗 ⇒ 开「修行设定与收益」（BreathPane1 的 showBiguanWindow）—— 实得 %s" % str(页))
	景.call("_切换精华")
	await _帧(2)

	# ── ⑦ 挂机：是**开关**，不是开窗
	_时("⑦ 挂机")
	页.clear()
	会.hang_state["active"] = false
	景.set("_上次切挂机毫秒", 防抖复位)
	await _点(大["挂机Button"], "hud_331")
	_判(bool(会.hang_state.get("active", false)), "真点挂机钮 ⇒ hang_state.active=true（isStart 取反）")
	_判(页.is_empty(), "点挂机**不该**打开任何功能页（开窗的是另一条「挂机设置」=J）—— 实得 %s" % str(页))
	await _点(大["挂机Button"], "hud_331")
	_判(bool(会.hang_state.get("active", false)), "1 秒内再点被防抖吃掉 ⇒ 还开着（GuajiHandler 的 _isCding）")
	景.set("_上次切挂机毫秒", 防抖复位)
	await _点(大["挂机Button"], "hud_331")
	_判(not bool(会.hang_state.get("active", false)), "过了防抖再点 ⇒ 关掉")
	景.call("_切换精华")		# 收起版要先露出来才拾取得到
	await _帧(2)
	景.set("_上次切挂机毫秒", 防抖复位)
	await _点(小["挂Button"], "收起钮_挂")
	_判(bool(会.hang_state.get("active", false)), "收起版那颗与展开版同一动作（这里开一次）")
	景.set("_上次切挂机毫秒", 防抖复位)
	await _点(小["挂Button"], "收起钮_挂")
	_判(not bool(会.hang_state.get("active", false)), "收起版那颗也能关")
	景.call("_切换精华")
	await _帧(2)

	# ── ⑧ 底栏那十颗不受影响（10-12 的坑：这一排的宠物钮与底栏宠物钮 tooltip 曾经同名）
	var 底宠: TextureButton = null
	for 件 in 栏.find_children("*", "BaseButton", true, false):
		var 钮 := 件 as TextureButton
		if 钮 != null and 钮.get_parent() != 栏 and String(钮.tooltip_text) == "宠物":
			底宠 = 钮
			break
	_判(底宠 != null, "找得到底栏那颗「宠物」功能钮（父件不是 `技能栏` 本身）")
	if 底宠 != null:
		页.clear()
		await _只按(底宠)
		_判(页 == ["宠物"], "底栏「宠物」仍开宠物窗、没被这一排抢走 —— 实得 %s" % str(页))

	假角.queue_free()
	_步("未收口（本门如实报，不算红）：")
	_步("  · 悬停那一圈白色辉光（BreathPane.as:129 的 BaseUtil.getGlowFilter(白, blur 5, 5)）没做 —— 现在只有 ±30 换皮")
	_步("  · 附身前那根 1500ms 进度条（PetHandler.as:152-159 showFuShenPetProgress）没做，点下去直接发召唤")
	_步("  · 原版前三颗有跨服守卫 inKuaFuBattle()，本工程没有跨服战场 ⇒ 无守卫可判")
	_步("  · 四颗的原版默认快速键 = X/W/A/H（键位表 position 22/24/14/23），与本地 普攻=X、移动=W/A 撞键 ⇒ 未接线，提示里写「快速键：无」")
	_尾()


func _到255(c: Color) -> Array[int]:
	return [int(round(c.r * 255.0)), int(round(c.g * 255.0)), int(round(c.b * 255.0)), int(round(c.a * 255.0))]


## 从场景文本里抠出一段节点定义（到下一个 [node 之前）
func _节(文: String, 节点名: String) -> String:
	var 起 := 文.find("[node name=\"%s\" type=\"TextureButton\" parent=\"技能栏\"" % 节点名)
	if 起 < 0:
		return ""
	var 余下 := 文.substr(起 + 1)
	var 止 := 余下.find("[node ")
	return 余下.substr(0, 止 if 止 >= 0 else 余下.length())


func _一行(段: String, 键: String) -> String:
	for 行 in 段.split("\n"):
		if str(行).begins_with(键):
			return String(行)
	return "<没有这行>"


func _尾() -> void:
	if 收:
		return
	收 = true
	var 现 := _字节()
	if 存前.is_empty():
		if FileAccess.file_exists(存档):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(存档))
		_判(not FileAccess.file_exists(存档), "动手前没有存档 ⇒ 收尾把本门造的那份删掉")
	else:
		if 现 != 存前:
			var g := FileAccess.open(存档, FileAccess.WRITE)
			if g != null:
				g.store_buffer(存前)
				g.close()
			_判(_字节() == 存前, "存档按字节还原（本门点了挂机/附身，会话层会落盘）")
		else:
			_判(true, "存档没被改动（无需还原）")
	日志.append("汇：判 %d 条 / 红 %d 条" % [判, 红])
	_写()
	for 行 in 日志:
		print(行)
	quit(0 if 红 == 0 else 1)
