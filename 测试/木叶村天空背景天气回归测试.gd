extends SceneTree
## 木叶村（100000000）天空底图随天气切换 —— 用户 2026-10-31 报的口径：
##   「晴天还是原本的，小雨=小阴天，大雨=大阴天，小雪/大雪同理，雾气是小阴天」。
##
## 这不是原版行为（原版 `Client.as:3825-3904` 的天气只叠动态雨/雪/雾片，底图不动），
## 是本工程按用户口径**新增**的一条；实现放在 `脚本/地图/天气特效.gd`
## （它不在烘焙哈希的输入清单里 ⇒ 改它不用重烤 174 张图）。
##
## 钉四件事：
##   ① 类型 → 档位映射：0/未知 原图；1/2/4/5/7/8/9 小阴天；3/6 大阴天（中雨/中雪按轻档）；
##   ② 两张新素材真在盘上、能解码、分辨率不比原天空低、大阴天确实比小阴天暗；
##   ③ 端到端：真烘焙场景里喂 1570 ⇒ 会话 hud_state ⇒ 天空层的贴图真的换了、晴天真的换回来，
##      且**只换天空层**（后景/纯色底块不动）；
##   ④ 别的图不吃这条：木叶森林（102010000）大雨时天空仍是原图。
##
## 跑法：Godot --headless --path . --script res://测试/木叶村天空背景天气回归测试.gd

const 天气脚本 := preload("res://脚本/地图/天气特效.gd")
const 地图资源 := preload("res://脚本/地图/地图资源.gd")

const 木叶村 := "100000000"
const 别的图 := "102010000"					# 木叶森林：用同一套 zhucheng 背景，但不在变体表里
const 原天空路 := "res://素材/地图/木叶村/背景/Back_zhucheng_back_2.png"
const 小阴天路 := "res://素材/地图/木叶村/背景/Back_zhucheng_back_2_小阴天.png"
const 大阴天路 := "res://素材/地图/木叶村/背景/Back_zhucheng_back_2_大阴天.png"

var _失败: Array[String] = []
var _条数 := 0
var _已收尾 := false
var _秒 := 0.0

func _initialize() -> void:
	call_deferred("_跑")

## 崩了不会红、只会挂死 ⇒ 看门狗兜底。
func _process(delta: float) -> bool:
	_秒 += delta
	if not _已收尾 and _秒 > 90.0:
		printerr("木叶村天空背景天气回归测试：看门狗超时（90s）—— 中途崩了没走到收尾")
		quit(1)
		return true
	return false

func _记(成立: bool, 说明: String) -> void:
	_条数 += 1
	if not 成立:
		_失败.append(说明)
		print("红：", 说明)

func _跑() -> void:
	_钉映射表()
	_钉素材()
	await _钉端到端()
	await _钉别的图不动()
	_收尾()

## ── ① 类型 → 档位（期望值是用户口径手抄的，不从 `天空变体` 反查）────────────────
func _钉映射表() -> void:
	var 期望 := {
		0: "",		# 晴天
		-1: "",		# 还没收到天气
		1: "小",	# 小雨
		2: "小",	# 中雨（用户没点名，按轻档）
		3: "大",	# 大雨
		4: "小",	# 小雪
		5: "小",	# 中雪（用户没点名，按轻档）
		6: "大",	# 大雪
		7: "小",	# 小雾
		8: "小",	# 中雾
		9: "小",	# 大雾（用户：「雾气是小阴天」）
		10: "",		# 越界：原版 `:3885` 什么都不画 ⇒ 天空也别动
	}
	for 类型 in 期望:
		var 实 := 天气脚本.天空变体(int(类型))
		_记(实 == String(期望[类型]),
				"天气 %d 的天空档位应为「%s」，实测「%s」（用户 2026-10-31 口径）"
				% [int(类型), String(期望[类型]), 实])
	# 木叶村之外的图不许挂进变体表（用户：「目前仅限木叶村」）。
	var 表: Dictionary = 天气脚本.天空变体图
	_记(表.has(木叶村), "变体表里必须有木叶村 %s" % 木叶村)
	_记(表.size() == 1, "变体表当前只该有木叶村一张图，实测 %s" % str(表.keys()))

## ── ② 素材本体 ────────────────────────────────────────────────────────────
func _钉素材() -> void:
	var 原 := _读png(原天空路)
	var 小 := _读png(小阴天路)
	var 大 := _读png(大阴天路)
	_记(原 != null, "原天空 %s 读不出来" % 原天空路)
	_记(小 != null, "小阴天 %s 读不出来（素材没放进工程？）" % 小阴天路)
	_记(大 != null, "大阴天 %s 读不出来（素材没放进工程？）" % 大阴天路)
	if 原 == null or 小 == null or 大 == null:
		return
	# 新图分辨率不许低于原图，否则拉满整图会被放得更糊。
	_记(小.get_width() >= 原.get_width() and 小.get_height() >= 原.get_height(),
			"小阴天 %dx%d 不该比原天空 %dx%d 小" % [小.get_width(), 小.get_height(),
		原.get_width(), 原.get_height()])
	_记(大.get_width() >= 原.get_width() and 大.get_height() >= 原.get_height(),
			"大阴天 %dx%d 不该比原天空 %dx%d 小" % [大.get_width(), 大.get_height(),
		原.get_width(), 原.get_height()])
	_记(小.get_size() == 大.get_size(),
			"两张阴天图尺寸应一致（同一机位出的），实测 %s / %s" % [str(小.get_size()), str(大.get_size())])
	# 大阴天必须真的更暗 —— 这条防的是"两张图接反了"（接反时映射表那条照样绿）。
	var 亮小 := _平均亮(小)
	var 亮大 := _平均亮(大)
	_记(亮大 < 亮小 - 0.05,
			"大阴天应明显比小阴天暗（实测 大=%.3f 小=%.3f；接反/换错图都吃这条）" % [亮大, 亮小])

## ── ③ 真烘焙场景端到端 ────────────────────────────────────────────────────
func _钉端到端() -> void:
	var 场 := await _进图(木叶村, 0)
	if 场 == null:
		return
	var 层 := _天空层(场)
	_记(层.size() == 1, "%s 的烘焙场景应正好有 1 层天空，实测 %d 层" % [木叶村, 层.size()])
	if 层.is_empty():
		场.queue_free()
		return
	var 天空: Node2D = 层[0]
	var 矩形: Rect2 = 天空.get("整图矩形")
	_记(_贴图路径(天空.get("texture")) == 原天空路,
			"晴天（weather 0）天空应还是原图 %s，实测 %s"
			% [原天空路, _贴图路径(天空.get("texture"))])
	var 后备景 := _兄弟贴图(场, "后景")
	var 后纯色 := _兄弟贴图(场, "纯色底块")

	# 1570 帧走真解析入口（与在线门、`天气特效回归测试` 同一条）。
	var 后端 := root.get_node_or_null("BackendConnection")
	_记(后端 != null, "没有 BackendConnection，1570 那条腿没法喂")
	if 后端 == null:
		场.queue_free()
		return
	var 表: Array = [
		[1, 小阴天路, "小雨"],
		[3, 大阴天路, "大雨"],
		[4, 小阴天路, "小雪"],
		[6, 大阴天路, "大雪"],
		[8, 小阴天路, "中雾"],
	]
	var 旧纹 = 天空.get("texture")
	var 小纹: Texture2D = null
	var 大纹: Texture2D = null
	for 行 in 表:
		后端.call("_handle_weather_text", ("1570:%d" % int(行[0])).split(":", true))
		await process_frame
		var 纹 = 天空.get("texture")
		var 路 := String((天气脚本.天空变体图[木叶村] as Dictionary).get(
				"小" if 行[1] == 小阴天路 else "大", ""))
		var 期望 := 天气脚本.读天空变体(路)
		_记(纹 == 期望,
				"%s（类型 %d）天空应换成 %s 对应的那张变体，实测 %s"
				% [String(行[2]), int(行[0]), 路.get_file(), _贴图路径(纹)])
		_记(纹 != 旧纹, "%s（类型 %d）天空贴图必须是**另一张**（没换等于没生效）" % [String(行[2]), int(行[0])])
		if 行[1] == 小阴天路:
			小纹 = 纹 as Texture2D
		else:
			大纹 = 纹 as Texture2D
		# 只换天空：后景 / 纯色底块一个都不许动。
		_记(_兄弟贴图(场, "后景") == 后备景 and _兄弟贴图(场, "纯色底块") == 后纯色,
				"%s（类型 %d）只许换天空层，后景/纯色底块不许跟着变" % [String(行[2]), int(行[0])])
		_记(天空.get("整图矩形") == 矩形,
				"%s（类型 %d）换图不许动拉满整图的矩形（%s）" % [String(行[2]), int(行[0]), str(矩形)])
		_记(bool(天空.get("拉满整图")), "%s（类型 %d）天空层仍应是拉满整图模式" % [String(行[2]), int(行[0])])
	_记(小纹 != null and 大纹 != null and 小纹 != 大纹,
			"小雨/小雪/雾 与 大雨/大雪 必须落到**两张不同**的图上（实测 %s / %s）"
			% [str(小纹), str(大纹)])
	if 小纹 != null and 大纹 != null:
		var 图小 := 小纹.get_image()
		var 图大 := 大纹.get_image()
		if 图小 != null and 图大 != null:
			_记(_平均亮(图大) < _平均亮(图小) - 0.05,
					"端到端这趟也是大阴天更暗（大=%.3f 小=%.3f）—— 防止映射接反"
					% [_平均亮(图大), _平均亮(图小)])

	# 晴天：1570:0 ⇒ 换回原图（不是留着一张阴天图）。
	后端.call("_handle_weather_text", "1570:0".split(":", true))
	await process_frame
	_记(_贴图路径(天空.get("texture")) == 原天空路,
			"1570:0 之后天空必须换回原图 %s，实测 %s"
			% [原天空路, _贴图路径(天空.get("texture"))])
	场.queue_free()
	await process_frame

## ── ④ 别的图不吃这条 ──────────────────────────────────────────────────────
func _钉别的图不动() -> void:
	var 场 := await _进图(别的图, 3)
	if 场 == null:
		return
	var 层 := _天空层(场)
	_记(not 层.is_empty(), "%s 也应该有天空层（这条腿要有东西可比）" % 别的图)
	if not 层.is_empty():
		_记(_贴图路径((层[0] as Node2D).get("texture")) == 原天空路,
				"%s 大雨（类型 3）也该保持原天空 —— 用户说这条只做木叶村，实测 %s"
				% [别的图, _贴图路径((层[0] as Node2D).get("texture"))])
	场.queue_free()
	await process_frame

## ── 小工具 ────────────────────────────────────────────────────────────────
func _进图(图号: String, 天气: int) -> Node:
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 == null:
		_记(false, "离线门里没有 /root/GameSession，进不了图")
		return null
	var 路径 := 地图资源.baked_scene_path(图号)
	if not ResourceLoader.exists(路径):
		_记(false, "%s 没有烘焙场景（%s）—— 这条腿验不了" % [图号, 路径])
		return null
	会话.set("current_map_id", 图号)
	var 态: Dictionary = 会话.hud_state
	态["weather_type"] = 天气
	var 场 := (load(路径) as PackedScene).instantiate()
	root.add_child(场)
	await process_frame
	await process_frame
	_记(场.get_node_or_null("天气特效") != null,
			"%s 的地图根节点应自动挂上天气特效（`_挂天气特效()`）" % 图号)
	return 场

func _天空层(场: Node) -> Array:
	var 出: Array = []
	var 背 := 场.get_node_or_null("BakedBackgrounds")
	if 背 == null:
		return 出
	for 件 in 背.get_children():
		if 件 is Node2D and String(件.get_meta("bg_kind", "")) == "天空":
			出.append(件)
	return 出

## 把同场景里某类别（后景 / 纯色底块）各层的贴图路径拼成一个可比较的字符串。
func _兄弟贴图(场: Node, 类别: String) -> String:
	var 出: Array = []
	var 背 := 场.get_node_or_null("BakedBackgrounds")
	if 背 == null:
		return ""
	for 件 in 背.get_children():
		if 件 is Node2D and String(件.get_meta("bg_kind", "")) == 类别:
			出.append(_贴图路径(件.get("texture")))
	return "|".join(出)

func _贴图路径(纹) -> String:
	if 纹 is Texture2D:
		return String((纹 as Texture2D).resource_path)
	return ""

func _读png(路: String) -> Image:
	var f := FileAccess.open(路, FileAccess.READ)
	if f == null:
		return null
	var 图 := Image.new()
	if 图.load_png_from_buffer(f.get_buffer(f.get_length())) != OK:
		return null
	return 图

## 每 64 像素采一点求平均亮度（0..1）。图像大，逐像素太慢。
func _平均亮(图: Image) -> float:
	if 图 == null or 图.get_width() <= 0 or 图.get_height() <= 0:
		return -1.0
	var 和 := 0.0
	var 数 := 0
	for y in range(0, 图.get_height(), 64):
		for x in range(0, 图.get_width(), 64):
			var 色 := 图.get_pixel(x, y)
			和 += (色.r + 色.g + 色.b) / 3.0
			数 += 1
	return 和 / float(maxi(数, 1))

func _收尾() -> void:
	_已收尾 = true
	if _失败.is_empty():
		print("木叶村天空背景天气回归测试：通过（%d 条断言）" % _条数)
		quit(0)
		return
	print("木叶村天空背景天气回归测试：共 %d 条，红 %d 条" % [_条数, _失败.size()])
	quit(1)
