extends SceneTree

## 竞技场**对战表现**自检（#335，**有头**：要拿视口图像、要发真点击）。
##
## 判的是这一串，每一步都带原版行号：
##   `2306:5` **只存秒数、一个字都不画**（`PvpManager.onPk_showBattleRemainTime:276-279`）
##   → **换图**那一拍才拿去显示（`Client.as:6340` → `onEnterMap:416-436` → `onStartPk:230-237`：
##     关窗 → 左侧倒计时 → 藏宠物）
##   → 每秒一行「离比赛结束还有： mm 分 ss 秒」（`ShowShenQiPvpTime.__onTick:60-79`
##     **先减一再显示** ⇒ 900 那一档第一拍是 14 分 59 秒）
##   `2306:6` 退场倒计时 = 头顶飘字那条队，绿字，**整秒变了才喊一次**（`Character.tickCopyClock:878-899`）
##   `2306:7` 结算弹层 = `PvpResultWindow`（笑脸/哭脸 + 奖励 + 确定；**同一时刻只一枚**）
##   离开竞技场图 ⇒ `onEndPk:321-325`：宠物放回来、那一行藏掉。
##
## ⚠ 节拍相关的两条判据一律**拿真实经过毫秒自己算参照值**（不写死"70 帧之后应该是 899"）——
##   跑批机器快慢不一样，按帧数钉死就是上一轮那种"帧率依赖的假红/假绿"。
##
## 用法：Godot --path . --script res://开发工具/验竞技场对战.gd
##   退出码 0 = 全过；1 = 有红；2 = 前置条件不满足

const 竞技场窗 := preload("res://脚本/界面/窗口/竞技场窗.gd")

const 出图 := "res://测试/截图/竞技场/对战.png"
const 竞技场图 := "503000000"
const 老家图 := "101010000"

var _帧 := 0
var _场景: Node = null
var _生命: Node = null
var _后端: Node = null
var _会话: Node = null
var _管理: Node = null
var _面板: CanvasLayer = null
var _牌: Control = null
var _窗: Node = null
var _甲: Node2D = null
var _乙: Node2D = null
var _判: Array = []
var _阶段 := 0
var _等待 := 0
var _起表毫秒 := 0
var _层: Node = null
var _钮位 := Vector2.ZERO
var _战报格位 := Vector2.ZERO
var _战报格数据: Dictionary = {}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://测试/截图/竞技场"))
	var 场 := load("res://场景/地图/地图场景.tscn") as PackedScene
	if 场 == null:
		push_error("拿不到 地图场景.tscn")
		quit(2)
		return
	_场景 = 场.instantiate()
	root.add_child(_场景)


func _过程(名: String, 过: bool) -> void:
	_判.append([名, 过])


func _倒计时块() -> Node:
	return _生命.get("_战场倒计时") as Node


func _时间文本() -> String:
	var 块 := _倒计时块()
	if 块 == null:
		return ""
	var 时 := 块.get_node_or_null("时间") as Label
	return 时.text if 时 != null else ""


## 把「离比赛结束还有： 14 分 59 秒」折回总秒数；格式不对就回 −1（判据会红，不会蒙过）
func _剩余秒数() -> int:
	var 文 := _时间文本()
	if not 文.begins_with("离比赛结束还有： "):
		return -1
	var 尾 := 文.trim_prefix("离比赛结束还有： ")
	var 分 := 尾.split(" 分 ")[0]
	var 秒 := 尾.split(" 分 ")[1].trim_suffix(" 秒") if 尾.split(" 分 ").size() == 2 else ""
	if not 分.is_valid_int() or not 秒.is_valid_int():
		return -1
	return int(分) * 60 + int(秒)


func _飘字文本们() -> Array:
	var 出: Array = []
	var 玩家 := _生命.get("_player") as Node
	if 玩家 == null:
		return 出
	for 子 in 玩家.get_children():
		for 孙 in 子.get_children():
			if 孙 is Label:
				出.append(String((孙 as Label).text))
	return 出


func _结算层们() -> Array:
	var 出: Array = []
	for 子 in _场景.get_children():
		if String(子.name) == "竞技场结算层":
			出.append(子)
	return 出


func _找(从: Node, 路: String) -> Node:
	return 从.get_node_or_null(路) if 从 != null else null


func _process(_秒: float) -> bool:
	_帧 += 1
	if _帧 < 10:
		return false
	match _阶段:
		0:
			_后端 = root.get_node_or_null("BackendConnection")
			_会话 = root.get_node_or_null("GameSession")
			_生命 = _场景.get_node_or_null("LifeRoot")
			_管理 = _场景.get_node_or_null("窗口管理")
			_面板 = _场景.get_node_or_null("头像面板") as CanvasLayer
			_牌 = _面板.get_node_or_null("头像区域/角色状态") as Control if _面板 != null else null
			_过程("后端/会话/LifeRoot/窗口管理/头像面板 都在",
					_后端 != null and _会话 != null and _生命 != null and _管理 != null and _面板 != null and _牌 != null)
			if _后端 == null or _会话 == null or _生命 == null or _管理 == null or _面板 == null or _牌 == null:
				push_error("前置条件不满足")
				quit(2)
				return true
			## 夹具：往那两个槽里各挂一只真的 Node2D。`显示宠物()` 判的是"两槽一起翻"，
			## 槽是空的跑这条 = 0 比 0 的假绿 ⇒ 必须先把槽点亮（原版那两条 if 也是分开判的）。
			_甲 = Node2D.new()
			_甲.name = "夹具出战宠物"
			_乙 = Node2D.new()
			_乙.name = "夹具附身宠物"
			_生命.add_child(_甲)
			_生命.add_child(_乙)
			_生命.set("_pet_companion", _甲)
			_生命.set("_pet_companion_extra", _乙)
			_过程("夹具：两只宠物都亮着", _甲.visible and _乙.visible)
			_窗 = _管理.call("取或建窗口", "竞技场")
			if _窗 != null:
				_窗.call("open_page", "竞技场")
			_过程("进图前竞技场那扇是开着的", _窗 != null and bool(_窗.call("已打开")))
			_喂("2306:5:900")
			_阶段 = 1
			_等待 = 3
		1:
			if _等待 > 0:
				_等待 -= 1
				return false
			## ★ 这一步判的是"**不该发生的没发生**"：`2306:5` 只存数，一块都不许建
			_过程("2306:5 只把 900 存进 战斗剩余", 竞技场窗.战斗剩余 == 900)
			_过程("2306:5 没把那一行画出来（原版要等换图那一拍）", _倒计时块() == null)
			_会话.set("current_map_id", 竞技场图)
			_起表毫秒 = Time.get_ticks_msec()
			_生命.call("_核对竞技场对战")		# 换图那一拍 `Client.as:6340` 喊的就是这一句
			_阶段 = 2
			_等待 = 4
		2:
			if _等待 > 0:
				_等待 -= 1
				return false
			_过程("换图那一拍 isPking 翻真", 竞技场窗.在对战)
			_过程("进战斗把开着的窗全关了（onStartPk:232-234）", not bool(_窗.call("已打开")))
			var 块 := _倒计时块()
			_过程("左侧倒计时块建出来了", 块 != null)
			_过程("挂在头像面板那一层（跟着屏幕走，不是跟着世界相机走）", 块 != null and 块.get_parent() == _面板)
			_过程("摆位 = x20、y = 头像面板底（showLeftCountDownView:3127-3128）",
					块 != null and is_equal_approx((块 as Control).position.x, 20.0)
					and is_equal_approx((块 as Control).position.y, _牌.position.y + _牌.size.y))
			_过程("两只宠物一起藏掉（showMyPet 那两条 if）", not _甲.visible and not _乙.visible)
			## 起表那一瞬间该是空的（`setCountDownTime` 不写文本）；机器慢到已经跑过一拍时
			## 改判"那一拍打的是 899"——两条都是有意义的断言，不写死帧数。
			var 经 := Time.get_ticks_msec() - _起表毫秒
			if 经 < 900:
				_过程("起表那一瞬间还没有字（<900ms，实测 %dms）" % 经, String(_时间文本()) == "")
			else:
				_过程("机器慢：第一拍已打出 14 分 59 秒", _剩余秒数() == 899)
			_等待 = 0
			_阶段 = 3
		3:
			## ★ 按**真实经过时间**等，不按帧数：这台机一屏 860ms 就跑完 80 帧（≈93fps），
			##   按帧数钉死就会在"还没到第一拍"的时候去判 ⇒ 假红（口径同 #269 那条帧率依赖）。
			if Time.get_ticks_msec() - _起表毫秒 < 1200:
				return false
			var 经秒 := int((Time.get_ticks_msec() - _起表毫秒) / 1000)
			var 望 := maxi(0, 900 - 经秒)
			var 实 := _剩余秒数()
			_过程("那一行按「离比赛结束还有： mm 分 ss 秒」在走，且与真实经过时间对得上（±1 秒）"
					+ "（实=%d 望=%d 经=%dms 文本=%s）" % [实, 望, Time.get_ticks_msec() - _起表毫秒, _时间文本()],
					实 >= 0 and absi(实 - 望) <= 1)
			_喂("2306:6:5")
			_阶段 = 4
			_等待 = 6
		4:
			if _等待 > 0:
				_等待 -= 1
				return false
			var 有钟 := false
			var 色对 := false
			for 子 in (_生命.get("_player") as Node).get_children():
				for 孙 in 子.get_children():
					if 孙 is Label and "退出竞技场倒计时" in String((孙 as Label).text):
						有钟 = true
						## 65280 = #00FF00（`player_addAttriChangeTip(..., 65280, true)`）
						色对 = (孙 as Label).has_theme_color_override("font_color") \
								and (孙 as Label).get_theme_color("font_color") == Color(0, 1, 0)
			_过程("2306:6 在头顶飘出「退出竞技场倒计时: 5」", 有钟)
			_过程("那一行是绿字 #00FF00（不是默认白）", 色对)
			_喂("2306:7:1:50")
			_阶段 = 5
			_等待 = 4
		5:
			if _等待 > 0:
				_等待 -= 1
				return false
			var 层们 := _结算层们()
			_过程("2306:7 弹出一枚结算层", 层们.size() == 1)
			_层 = 层们[0] as Node if 层们.size() == 1 else null
			if _层 == null:
				_收()
				return true
			_过程("结算层自己是一层 CanvasLayer、层号 400（压在窗与 HUD 之上）", int(_层.get("layer")) == 400)
			_过程("胜 ⇒ 画的是笑脸 ShengLi", _脸路径().contains("ShengLi"))
			_过程("文字里带这一档的阅历 50", "50" in _结算文字())
			_过程("底板 545×220", _结算底尺寸())
			_过程("脸的摆位 = 原版算式 (170, −88)", _脸摆位())
			_钮位 = _确定钮屏幕位()
			_喂("2306:7:0:10")
			_阶段 = 6
			_等待 = 4
		6:
			if _等待 > 0:
				_等待 -= 1
				return false
			## ★ 再来一帧 ⇒ **只许换内容，不许再叠一层**（1079 弹两枚那次整屏卡住的根因）
			_过程("第二帧不叠第二枚（同一时刻只留一枚）", _结算层们().size() == 1)
			_层 = _结算层们()[0] as Node if not _结算层们().is_empty() else null
			_过程("负 ⇒ 换成哭脸 ShiBai", _脸路径().contains("ShiBai"))
			_过程("文字跟着换成这一档的阅历 10", "10" in _结算文字())
			_抓图()
			_阶段 = 7
			_等待 = 3
		7:
			if _等待 > 0:
				_等待 -= 1
				return false
			## 点「确定」= 真点击（`emit_signal("pressed")` 是演给自己看的，不算）
			_指过去并点一下(_钮位)
			_阶段 = 8
			_等待 = 8
		8:
			if _等待 > 0:
				_等待 -= 1
				return false
			_过程("点确定之后这枚弹层消失（onCloseBtnClick）", _结算层们().is_empty())
			_会话.set("current_map_id", 老家图)
			_生命.call("_核对竞技场对战")
			_阶段 = 9
			_等待 = 4
		9:
			if _等待 > 0:
				_等待 -= 1
				return false
			_过程("离开竞技场图 ⇒ isPking 翻假", not 竞技场窗.对战中())
			_过程("两只宠物一起放回来（onEndPk:324）", _甲.visible and _乙.visible)
			_过程("左侧那一行跟着藏掉", _倒计时块() == null or not (_倒计时块() as CanvasItem).visible)
			_阶段 = 10
			_等待 = 2
		10:
			if _等待 > 0:
				_等待 -= 1
				return false
			## ── 战报格（`onPk_challengedReport:359-391`）：`2306:10` 的 8 段是**冒号**分隔
			##（服务端 `:29801` 自己把 `&` 换成了 `:`）⇒ 夹具照那个形状写，不是手写猜。
			var 盘 := _管理.get_node_or_null("邀请托盘") as Node
			_过程("地图里有邀请托盘那一块", 盘 != null)
			if 盘 == null:
				_收()
				return true
			_喂("2306:10:301:301:甲一:9001:乙一:111:60:7")
			_过程("被人挑战 ⇒ 托盘多一格", int(盘.call("数量")) == 1)
			_喂("2306:10:301:301:甲一:9001:乙一:111:60:7")
			_过程("同一条 timeStamp 再来一次 ⇒ 不塞第二格（`:377-380`）", int(盘.call("数量")) == 1)
			_喂("2306:10:302:302:甲二:9002:乙二:222:70:6")
			_喂("2306:10:303:303:甲三:9003:乙三:333:80:5")
			_喂("2306:10:304:304:甲四:9004:乙四:444:90:4")
			_喂("2306:10:305:305:甲五:9005:乙五:555:95:3")
			_过程("第 5 条进来 ⇒ shift 掉最旧那格，屏上仍是 4 格（`:383-387` 的 `length > 3`）",
					int(盘.call("数量")) == 4)
			_战报格位 = Vector2.ZERO
			_战报格数据 = {}
			## ★ 等补位动画跑完再量格子位置：`删消息` 会把右边那些格整体右移 40px、历时 0.2 秒
			##（`邀请托盘.删消息` 里那条 tween）⇒ 提前取屏幕位会点到**邻格**（第一次跑就是这样，
			##  弹出来的是 444 那条而不是最新那条）。等 20 帧（>0.2 秒）再取，点到的才是我要的那格。
			_阶段 = 11
			_等待 = 20
		11:
			if _等待 > 0:
				_等待 -= 1
				return false
			var 盘2 := _管理.get_node_or_null("邀请托盘") as Node
			var 格 := 盘2.call("最后一格") as Control
			if 格 != null:
				_战报格位 = 格.global_position + 格.size * 0.5
				_战报格数据 = 格.get("数据") as Dictionary
			_指过去并点一下(_战报格位)
			_阶段 = 12
			_等待 = 6
		12:
			if _等待 > 0:
				_等待 -= 1
				return false
			var 战层: Node = null
			for 子 in _场景.get_children():
				if String(子.name) == "竞技场战报层":
					战层 = 子
			_过程("点那一格 ⇒ 弹出战报窗（`clickGridHandler:81-86`）", 战层 != null)
			if 战层 != null:
				_过程("战报窗标题 = PVP_ZHANBAO_TITLE「战报」",
						String((战层.get_node("战报/主体/标题") as Label).text) == "战报")
				var 正 := 战层.get_node("战报/主体/正文") as RichTextLabel
				## 点的是哪一格就该出哪一格的正文：这几条夹具里 `winnerId` 都不是本号
				## ⇒ `getZhanBao:199-202` 走 else 那一支、取 **winnerName**（不是败者名）。
				var 胜名 := String(_战报格数据.get("winnerName", ""))
				_过程("正文用的是那一格自己的 getZhanBao 渲染（含胜者名「%s」+「挑战」+「排名」）" % 胜名,
						正 != null and not 胜名.is_empty() and 胜名 in 正.text
						and "挑战" in 正.text and "排名" in 正.text)
				_过程("底板天然 216×134（原版这扇**没**拉伸）",
						is_equal_approx((战层.get_node("战报/主体/底") as Control).size.x, 216.0)
						and is_equal_approx((战层.get_node("战报/主体/底") as Control).size.y, 134.0))
			_收()
			return true
	return false




func _脸路径() -> String:
	var 脸 := _找(_层, "竞技场结算/主体/脸") as TextureRect
	if 脸 == null or 脸.texture == null:
		return ""
	return String(脸.texture.resource_path)


func _脸摆位() -> bool:
	var 脸 := _找(_层, "竞技场结算/主体/脸") as Control
	if 脸 == null:
		return false
	return is_equal_approx(脸.position.x, 170.0) and is_equal_approx(脸.position.y, -88.0)


func _结算文字() -> String:
	var 文 := _找(_层, "竞技场结算/主体/文字") as RichTextLabel
	return 文.text if 文 != null else ""


func _结算底尺寸() -> bool:
	var 底 := _找(_层, "竞技场结算/主体/底") as Control
	return 底 != null and is_equal_approx(底.size.x, 545.0) and is_equal_approx(底.size.y, 220.0)


## 确定那颗在屏幕上的位置：结算层是 CanvasLayer ⇒ 遮罩层 = 整屏，主体已按屏中摆好
func _确定钮屏幕位() -> Vector2:
	var 钮 := _找(_层, "竞技场结算/主体/确定钮") as Control
	if 钮 == null:
		return Vector2.ZERO
	return 钮.global_position + 钮.size * 0.5


func _指过去并点一下(位: Vector2) -> void:
	if 位 == Vector2.ZERO:
		push_error("拿不到确定那颗的屏幕位 ⇒ 这一条没法判")
		return
	var 移 := InputEventMouseMotion.new()
	移.position = 位
	root.push_input(移)
	var 按 := InputEventMouseButton.new()
	按.position = 位
	按.global_position = 位
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	root.push_input(按)
	var 放 := InputEventMouseButton.new()
	放.position = 位
	放.global_position = 位
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	root.push_input(放)


func _喂(串: String) -> void:
	_后端.call("_handle_arena_text", PackedStringArray(串.split(":")))


func _抓图() -> void:
	var 图 := root.get_texture().get_image()
	if 图 == null or 图.is_empty():
		push_error("拿不到视口图像 —— 是不是加了 --headless？")
		return
	if 图.save_png(出图) != OK:
		push_error("存图失败：" + 出图)
		return
	print("竞技场对战：%s（%dx%d）" % [出图, 图.get_width(), 图.get_height()])


func _收() -> void:
	var 红 := 0
	for 一 in _判:
		var 过: bool = bool(一[1]) if 一.size() > 1 else false
		if not 过:
			红 += 1
		print("  %-4s  %s" % ["通过" if 过 else "红", 一[0]])
	print("竞技场对战自检：判 %d 条，红 %d 条" % [_判.size(), 红])
	quit(0 if 红 == 0 else 1)
