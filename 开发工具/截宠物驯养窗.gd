extends SceneTree

## 截「通灵驯养」三页 + 尾兽预览的图（报修 4.1/4.2 取证与验收用）。
##
## 为什么要单独写：`_探_窗口巡检.gd` 那类探针只量节点树，**看不见的东西量不出来**
## （原版有、我们没建的节点在树上根本不存在）；而 4.1 报的是"缺图标 / 图标过大"，
## 必须拿图对着原版基线（`测试/基线/原版界面/原版_宠物驯养窗.png`）看。
##
## ⚠️ **不能加 --headless**（无头拿不到视口图像），存图目录是 `res://测试/截图/驯养`
##    （`.gitignore` 挡着，属"盘上有、仓里没有"），**不碰 `user://`**。
##
## 用法：
##   Godot --path . --script res://开发工具/截宠物驯养窗.gd
## 可选：
##   --出目录=res://测试/截图/驯养
##   --窗宽/窗高 只在日志里报视口尺寸，真正的视口大小跟 project.godot（960×560）

var _出目录 := "res://测试/截图/驯养"
var _场景: Node = null
var _管理: Node = null
var _会话: Node = null
var _帧 := 0
var _步 := 0
var _用例: Array = []
var _当前: Dictionary = {}
var _等待 := 0
var _就绪 := false


func _initialize() -> void:
	for 参 in OS.get_cmdline_user_args():
		if 参.begins_with("--出目录="):
			_出目录 = String(参.trim_prefix("--出目录="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_出目录))
	_用例 = [
		{"名": "驯养_进阶", "宠": "1", "页签": 0, "模式": -1, "带预览": false},
		# ⚠️ 这条对的是**唯一一张原版基线** `测试/基线/原版界面/原版_宠物驯养窗.png`：
		#    那张拍的就是"属性提升页、下拉还没选任何东西"的 type0 态（AS3 `setType:437-439`
		#    → `initType:727-771` 那半页：`你将要提升的通灵兽是` + 200×110 `PetPic_background`
		#    + 名称/等级 + 立绘 + 提示）。原来七条用例全给了 `模式 >= 0` ⇒ 这半页从没被眼睛看过。
		{"名": "驯养_提升未选", "宠": "1", "页签": 1, "模式": -1, "带预览": false},
		{"名": "驯养_提升品级", "宠": "1", "页签": 1, "模式": 0, "带预览": false},
		{"名": "驯养_提升悟性", "宠": "1", "页签": 1, "模式": 1, "带预览": false},
		{"名": "驯养_提升潜力", "宠": "1", "页签": 1, "模式": 2, "带预览": false},
		{"名": "驯养_融魂普通宠", "宠": "1", "页签": 2, "模式": -1, "带预览": false},
		{"名": "驯养_融魂尾兽", "宠": "9", "页签": 2, "模式": -1, "带预览": true},
		# 4.2 的验收图：**三扇一起**开（宠物主窗 + 驯养副窗 + 尾兽预览），
		# 走 `_摆宠物双窗` 那条"整条贴右墙"的摆位 ⇒ 存整幅视口，不裁窗。
		{"名": "驯养_三扇全条", "宠": "9", "页签": 2, "模式": -1, "带预览": true, "带主窗": true},
	]
	var 场景脚本 := load("res://场景/地图/地图场景.tscn") as PackedScene
	_场景 = 场景脚本.instantiate()
	root.add_child(_场景)
	# ⚠ `_initialize` 里 `await process_frame` **不会醒**（引擎还停在这一次调用里，
	#   process_frame 早过了）—— 必须走 `call_deferred`，与 `_探_窗口巡检.gd` 同一写法。
	call_deferred("_准备")


func _准备() -> void:
	for _i in 8:
		await process_frame
	_管理 = _场景.get_node_or_null("窗口管理")
	_会话 = root.get_node_or_null("GameSession")
	if _管理 == null or _会话 == null:
		push_error("拿不到 窗口管理 / GameSession")
		quit(1)
		return
	_会话.pets = _宠()
	_就绪 = true


## ⚠️ **这个函数里绝对不能 `await`**：`_process` 是"每帧返回 bool 的状态机"，
##   挂一次 await 就把整条状态机断掉（实测：只进来一帧，之后什么都不发生、六秒后自己退出）。
##   等渲染一律走 `_等待` 计数。（同 `开发工具/截商城窗.gd:81-84` 那条注。）
func _process(_delta: float) -> bool:
	_帧 += 1
	if not _就绪:
		return false
	if _等待 > 0:
		_等待 -= 1
		if _等待 == 0:
			_抓()
			_步 += 1
		return false
	if _步 >= _用例.size():
		print("截宠物驯养窗：共 %d 张，目录 %s" % [_用例.size(), _出目录])
		quit(0)
		return true
	var 用例: Dictionary = _用例[_步]
	_当前 = 用例
	var 窗 = _管理.call("取或建窗口", "通灵驯养")
	if 窗 == null:
		push_error("建不出通灵驯养窗")
		quit(1)
		return true
	窗._驯养宠物id = String(用例["宠"])
	窗._驯养页签 = int(用例["页签"])
	窗._驯养提升模式 = int(用例["模式"])
	窗._驯养融魂下标 = -1
	窗._融魂预览已开 = false
	_管理.call("打开", "通灵驯养")
	if bool(用例.get("带主窗", false)):
		# 三扇全条：主窗也开出来，摆位交给 `_摆宠物双窗` 自己算（它会因为预览开着而整条贴右墙）。
		# ⚠️ 必须走 `窗口管理.打开`，`open_page` 只换页、不按尺寸表收外框 ⇒ 主窗会停在 517×440。
		_管理.call("打开", "宠物")
		var 主窗 = _管理.call("取窗口", "宠物")
		if 主窗 != null:
			主窗.call("_摆宠物双窗")
	else:
		# 摆在视口左侧：驯养窗 410 宽 + 尾兽预览 400 宽 = 812，居中会切掉右边。
		窗.call("窗口偏移", Vector2(-268.0, 0.0), false)
	_等待 = 8
	return false
	_步 += 1
	return false


func _抓() -> void:
	var 图 := root.get_texture().get_image()
	if 图 == null or 图.is_empty():
		push_error("拿不到视口图像 —— 是不是加了 --headless？")
		return
	var 窗 = _管理.call("取窗口", "通灵驯养")
	var 主 := 窗.get_node("遮罩/主窗口") as Control
	var 框 := 主.get_global_rect()
	if bool(_当前.get("带主窗", false)):
		# 三扇全条要看的是**整条**（主窗被推到屏幕外一截），所以直接存整幅视口。
		框 = Rect2(Vector2.ZERO, Vector2(float(图.get_width()), float(图.get_height())))
	elif bool(_当前["带预览"]):
		# 把右边那块预览一起裁进来（原版预览在 窗局部 x=412 起、宽 400）
		框 = Rect2(框.position, Vector2(框.size.x + 404.0, 框.size.y + 60.0))
	var 裁 := Rect2(Vector2(maxf(0.0, floorf(框.position.x)), maxf(0.0, floorf(框.position.y))),
			Vector2(minf(float(图.get_width()), ceilf(框.end.x)), minf(float(图.get_height()), ceilf(框.end.y))))
	var 区 := Rect2(裁.position, 裁.end - 裁.position)
	if 区.size.x <= 0.0 or 区.size.y <= 0.0:
		push_error("裁剪区为空：%s" % 区)
		return
	var 子图 := 图.get_region(Rect2i(区.position, 区.size))
	var 路径 := "%s/%s.png" % [_出目录, String(_当前["名"])]
	if 子图.save_png(路径) != OK:
		push_error("存图失败：%s" % 路径)
		return
	print("截宠物驯养窗：%s → %s（%.0fx%.0f，窗全局 %s）" % [String(_当前["名"]), 路径,
			区.size.x, 区.size.y, 框])


## 一只有九条技能的普通宠（悟性页两行才满）+ 一只尾兽宠（融魂页与预览那一族）。
func _宠() -> Array[Dictionary]:
	var 技: Array = []
	for 号 in [101, 102, 103, 104, 105, 106, 107, 108, 109]:
		技.append({"id": 号, "level": 3})
	return [
		{"id": "1", "unique_id": 1, "item_id": 101, "name": "小忍犬", "level": 12,
			"aptitude": 1, "savvy": 10, "experience": 0, "face": 0,
			"potential_real_atk": 100, "potential_real_def": 100,
			"potential_real_dex": 100, "potential_real_str": 100,
			"potential_total_atk": 120, "potential_total_def": 120,
			"potential_total_dex": 120, "potential_total_str": 120,
			"equipment": [], "skills": 技, "attached": false, "deployed": true},
		{"id": "9", "unique_id": 9, "item_id": 401, "name": "三尾矶怃", "level": 60,
			"aptitude": 4, "savvy": 100, "experience": 0, "face": 0,
			"potential_real_atk": 6198, "potential_real_def": 6198,
			"potential_real_dex": 6198, "potential_real_str": 6198,
			"potential_total_atk": 6198, "potential_total_def": 6198,
			"potential_total_dex": 6198, "potential_total_str": 6198,
			"equipment": [], "skills": [{"id": 125, "level": 10}],
			"attached": false, "deployed": true},
	]
