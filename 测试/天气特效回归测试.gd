extends SceneTree
## 报修 6「天气对应的地图特效没有实装」的离线门。
##
## 钉的是 `脚本/地图/天气特效.gd` 相对 AS3 真值（`2.2.3 Client.as:3790-4066`）的那几件事：
##   ① 三条地图名单（A 静态装饰可见 / B 永不放动态 / C 只跳过雪）——逐字搬 `:3847-3849`，
##      含"范围端点只到 ××40000、子图 112040002 不算"这个要命的细节；
##   ② 类型 → 素材图号 + 整层透明度 + 要不要叠雪（`:3885-3900`）与类型 0/10+ 什么都不画；
##   ③ 雪的参数（`:3980-3986`、`:3988`、`:3991-3997`、`:4004-4009`、`:4025`、`:4035-4047`）；
##   ④ 帧节拍 100ms（`Animation.as:47-50` + `FrameQueueAnimation.as:119` 的 `|| 100`）；
##   ⑤ 摆位：屏幕 (0,0) 画素材 (25,1)（`Client.as:3910-3911`），真帧数 nature_18=20、nature_16=7；
##   ⑥ 静态装饰物的可见性确实**改到了真烘焙场景里的那些节点**（含烘焙重名 `..._17_2`）；
##   ⑦ 端到端：喂一条 `1570:8` ⇒ 会话 hud_state ⇒ 节点自己把雾层画出来（在线那半条腿的离线等价物）。
##
## 跑法：
##   Godot --headless --path . --script res://测试/天气特效回归测试.gd

const 天气脚本 := preload("res://脚本/地图/天气特效.gd")
const 地图资源 := preload("res://脚本/地图/地图资源.gd")

var _失败: Array[String] = []
var _条数 := 0

func _initialize() -> void:
	call_deferred("_跑")

func _记(判据: bool, 说明: String) -> void:
	_条数 += 1
	if not 判据:
		_失败.append(说明)

func _跑() -> void:
	_钉名单()
	_钉画面参数()
	_钉雪参数()
	_钉摆位与节拍()
	await _钉装饰与动态层()
	await _钉真烘焙场景()
	await _钉端到端()
	_收尾()

## ──  ① 三条名单（`:3847-3849` 逐字） ────────────────────────────────────────
func _钉名单() -> void:
	# 每张图 = [地图号, A 静态装饰可见, B 永不放动态, C 只跳过雪]
	var 表: Array = [
		["101010000", false, false, false],	# 木叶村：三张名单都不在
		["107010000", false, true, false],	# 逐字 `:3848` 的三个 1070 等号项
		["108010000", false, true, false],	# 1080 范围下端
		["108040000", false, true, false],	# 1080 范围上端
		["109010000", true, false, true],	# 等号项同时在 A 与 C
		["109040000", true, false, true],
		["110010000", true, false, true],
		["110030000", false, true, false],	# 只在 B
		["110040000", true, false, true],
		["111010000", true, false, false],	# 只在 A（波之国那组：雪照下）
		["111040000", true, false, false],
		["111040001", false, false, false],	# ⚠ 范围上端 +1 就出名单
		["112010000", true, true, true],	# A∩B∩C：装饰看得见，动态一律不放
		["112040000", true, true, true],
		["112040002", false, false, false],	# ⚠ 子图：原版把烘好的装饰**藏起来**
		["411000000", false, false, false],	# 同上（这张图确实烘了 nature_17/18）
	]
	for 行 in 表:
		var 图号: String = 行[0]
		_记(天气脚本.在静态名单A(图号) == bool(行[1]),
				"A（静态装饰可见）%s 应为 %s（`Client.as:3847`）" % [图号, str(行[1])])
		_记(天气脚本.在禁动态名单B(图号) == bool(行[2]),
				"B（永不放动态）%s 应为 %s（`:3848`）" % [图号, str(行[2])])
		_记(天气脚本.在雪跳过名单C(图号) == bool(行[3]),
				"C（只跳过雪）%s 应为 %s（`:3849`）" % [图号, str(行[3])])
	# 波之国纪念雪（`:3810-3823`）：查得到才真，查不到一律假 —— 本机文本协议不带 mapData。
	_记(not 天气脚本.有纪念雪("111010000", {}),
			"没有 mapData 时纪念雪必须为假（`:3820` `hasOwnProperty` 判空）")
	_记(天气脚本.有纪念雪("111010000", {"mapData": {"_waveMemorialSnowMapIds": {"111010000": true}}}),
			"mapData 里点了这张图 ⇒ 纪念雪为真（`:3822`）")
	_记(not 天气脚本.有纪念雪("111010000", {"mapData": {"_waveMemorialSnowMapIds": {"111010000": false}}}),
			"点了但值为假 ⇒ 不算（`:3822` `Boolean(_loc2_[_loc3_])`）")
	_记(not 天气脚本.有纪念雪("111010001", {"mapData": {"_waveMemorialSnowMapIds": {"111010000": true}}}),
			"纪念雪按**真实地图号**查，别的图不许蹭（`:3821`）")

## ──  ② 类型 → 图号/透明度/雪（`:3885-3900`） ────────────────────────────────
func _钉画面参数() -> void:
	var 期望 := {
		1: {"图号": "18", "透明度": 0.45, "雪": false},
		2: {"图号": "18", "透明度": 0.7, "雪": false},
		3: {"图号": "18", "透明度": 1.0, "雪": false},
		4: {"图号": "16", "透明度": 0.08, "雪": true},
		5: {"图号": "16", "透明度": 0.13, "雪": true},
		6: {"图号": "16", "透明度": 0.18, "雪": true},
		7: {"图号": "16", "透明度": 0.35, "雪": false},
		8: {"图号": "16", "透明度": 0.6, "雪": false},
		9: {"图号": "16", "透明度": 0.85, "雪": false},
	}
	for 类型 in 期望:
		var 实 := 天气脚本.画面参数(类型)
		_记(实 == 期望[类型], "类型 %d 的画面参数应为 %s，实测 %s（`:3885-3900`）"
				% [类型, str(期望[类型]), str(实)])
	for 越界 in [-1, 0, 10, 99]:
		_记(天气脚本.画面参数(越界).is_empty(),
				"类型 %d 什么都不画（`:3830 _loc5_=\"\"` + `:3901-3904` 那条 return）" % 越界)

## ──  ③ 雪参数（`:3960-4050`） ───────────────────────────────────────────────
func _钉雪参数() -> void:
	# [类型, 数量, 半径随机量, 纵速随机量, 摆幅随机量, 风幅]
	var 分档 := [[4, 38, 2.8, 0.9, 0.42, 0.18], [5, 68, 2.8, 1.35, 0.42, 0.18], [6, 104, 3.6, 1.9, 0.62, 0.35]]
	for 档 in 分档:
		var 参 := 天气脚本.雪参数(int(档[0]))
		_记(int(参["数量"]) == 档[1], "类型 %d 的雪 %d 片（`:3980`）" % [档[0], 档[1]])
		_记(absf(float(参["半径底"]) - 0.9) < 1e-6 and absf(float(参["半径随机量"]) - 档[2]) < 1e-6,
				"类型 %d 半径 = 0.9 + rand×%.2f（`:3986`）" % [档[0], 档[2]])
		_记(absf(float(参["实心透明度"]) - 0.58) < 1e-6 and absf(float(参["实心随机量"]) - 0.36) < 1e-6,
				"实心圆 alpha = 0.58 + rand×0.36（`:3988`）")
		_记(absf(float(参["纵速底"]) - 0.65) < 1e-6 and absf(float(参["纵速随机量"]) - 档[3]) < 1e-6,
				"类型 %d speedY = 0.65 + rand×%.2f（`:4005`）" % [档[0], 档[3]])
		_记(absf(float(参["摆幅底"]) - 0.12) < 1e-6 and absf(float(参["摆幅随机量"]) - 档[4]) < 1e-6,
				"类型 %d sway = 0.12 + rand×%.2f（`:4006`）" % [档[0], 档[4]])
		_记(absf(float(参["横速底"]) + 0.22) < 1e-6 and absf(float(参["横速随机量"]) - 0.44) < 1e-6,
				"speedX = -0.22 + rand×0.44（`:4004`）")
		_记(absf(float(参["相速底"]) - 0.018) < 1e-6 and absf(float(参["相速随机量"]) - 0.035) < 1e-6,
				"phaseSpeed = 0.018 + rand×0.035（`:4008`）")
		_记(absf(float(参["自旋"]) - 0.45) < 1e-6, "spin = -0.45 + rand×0.9（`:4009`，单位是**度**）")
		_记(absf(float(参["风频"]) - 0.015) < 1e-6 and absf(float(参["风幅"]) - 档[5]) < 1e-6,
				"类型 %d 风 = sin(帧×0.015)×%.2f（`:4025`）" % [档[0], 档[5]])
		_记(absf(float(参["十字阈值"]) - 2.3) < 1e-6 and absf(float(参["十字长"]) - 1.35) < 1e-6 \
				and absf(float(参["线宽"]) - 0.6) < 1e-6 and absf(float(参["线透明度"]) - 0.48) < 1e-6,
				"半径>2.3 才画十字：±1.35r、线宽 0.6、白 alpha 0.48（`:3991-3997`）")
		_记(absf(float(参["下绕边距"]) - 24.0) < 1e-6 and absf(float(参["上补随机比"]) - 0.12) < 1e-6 \
				and absf(float(参["侧绕边距"]) - 30.0) < 1e-6,
				"回绕：y>H+24 → -24-rand×H×0.12；x<-30 → W+30；x>W+30 → -30（`:4035-4047`）")
	for 不该下 in [1, 2, 3, 7, 8, 9, 0, 10]:
		_记(天气脚本.雪参数(不该下).is_empty(), "类型 %d 不下雪（`:3890-3895` 只在 4..6 调 startWeatherSnowVisual）" % 不该下)

## ──  ④ 摆位 + 帧节拍 ────────────────────────────────────────────────────────
func _钉摆位与节拍() -> void:
	_记(天气脚本.舞台点 == Vector2(25.0, 1.0),
			"动态天气件的舞台点 (25,1)（`Client.as:3910-3911` \"x\":25,\"y\":1）")
	_记(absf(天气脚本.帧间隔 - 0.1) < 1e-9,
			"帧间隔 100ms ⇒ 10fps（`Animation.as:47-50` + `FrameQueueAnimation.as:119` 的 `|| 100`）")
	_记(天气脚本.层级 == 10, "CanvasLayer 10：在世界(0)之上、小地图面板(20)之下")

## ──  ⑤⑥ 动态层与静态装饰：用一个自搭的 ObjectRoot 骨架跑矩阵 ────────────────
## 骨架里放四种节点名，覆盖"图号命中/不命中/烘焙重名 `_2`/前缀都不是"四张脸。
func _搭骨架(地图号: String) -> Dictionary:
	var 架 := Node2D.new()
	架.name = "天气骨架_%s" % 地图号
	root.add_child(架)
	var 物件 := Node2D.new()
	物件.name = "ObjectRoot"
	架.add_child(物件)
	for 名 in ["Obj_acc_shuizhiguo_nature_16", "Obj_acc_shuizhiguo_nature_17",
			"Obj_acc_shuizhiguo_nature_17_2", "Obj_acc_shuizhiguo_nature_18",
			"Obj_acc_shuizhiguo_nature_12", "Obj_acc_yewai_nature_18"]:
		var 件 := Sprite2D.new()
		件.name = 名
		物件.add_child(件)
	var 节 := 天气脚本.new()
	节.name = "天气特效"
	架.add_child(节)
	节.地图号 = 地图号
	return {"架": 架, "件": 物件, "节": 节}

func _装饰状态(骨架: Dictionary) -> Dictionary:
	var 出 := {}
	for 件 in (骨架["件"] as Node).get_children():
		出[String(件.name)] = bool((件 as CanvasItem).visible)
	return 出

func _钉装饰与动态层() -> void:
	# 矩阵：[地图号, 类型, 期望"天气片", 期望"天气雪", 期望装饰(命中项 true/false)]
	var 矩阵: Array = [
		["101010000", -1, false, false, false],
		["101010000", 1, true, false, false],		# 名单外：动态照放，装饰藏起来
		["109040000", 1, true, false, true],		# A∩C：小雨能放
		["109040000", 5, false, false, true],		# A∩C + 4..6 ⇒ `:3881` 后半条拦掉
		["109040000", 8, true, false, true],		# 雾（8）不在 4..6 ⇒ 放行
		["111010000", 5, true, true, true],		# 只在 A：雪照下（波之国那组）
		["112010000", 2, false, false, true],		# A∩B ⇒ B 那条 return 全拦
		["112010000", 6, false, false, true],
		["107010000", 9, false, false, false],		# 只在 B
		["112040002", 3, true, false, false],		# ⚠ 子图：动态照放、装饰**藏**
		["411000000", 7, true, false, false],
	]
	for 行 in 矩阵:
		var 骨架 := _搭骨架(String(行[0]))
		var 节 = 骨架["节"]
		节.应用(int(行[1]))
		await process_frame
		var 架: Node = 骨架["架"]
		_记((架.get_node_or_null("天气特效/天气片") != null) == bool(行[2]),
				"%s 类型 %d 的天气片应%s（B/C 那两条 return 在 `:3881-3884`）"
				% [行[0], 行[1], "存在" if bool(行[2]) else "不存在"])
		_记((架.get_node_or_null("天气特效/天气雪") != null) == bool(行[3]),
				"%s 类型 %d 的雪层应%s（`:3892` 只在 4..6 起雪）"
				% [行[0], 行[1], "存在" if bool(行[3]) else "不存在"])
		var 状 := _装饰状态(骨架)
		var 命中名 := ["Obj_acc_shuizhiguo_nature_16", "Obj_acc_shuizhiguo_nature_17",
				"Obj_acc_shuizhiguo_nature_17_2", "Obj_acc_shuizhiguo_nature_18"]
		var 全对 := true
		for 名 in 命中名:
			if bool(状.get(名, not bool(行[4]))) != bool(行[4]):
				全对 = false
		# 图号不 16/17/18 的两枚**一律不许动**（原版 `:3855` 只挑这三张）。
		var 旁人 := bool(状.get("Obj_acc_shuizhiguo_nature_12", false)) \
				or bool(状.get("Obj_acc_yewai_nature_18", false))
		_记(全对, "%s 类型 %d 的 nature_16/17/18 可见性应全 %s（A 名单 `:3847` → `:3876`），实测 %s"
				% [行[0], 行[1], str(bool(行[4])), str(状)])
		_记(旁人, "%s 类型 %d 没命中 16/17/18 的装饰物保持默认可见（`:3855` 只挑这三张图号）"
				% [行[0], 行[1]])
		架.queue_free()
		await process_frame

## ─  真烘焙场景：节点自动挂上、素材真读得到、裁到视口那么大  ──────────────────
func _钉真烘焙场景() -> void:
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 == null:
		_失败.append("离线门里没有 /root/GameSession —— 天气层的初始类型是从它 hud_state 读的")
		return
	# [地图号, 类型, 期望图号, 期望帧数, 期望透明度]
	var 表: Array = [
		["112040000", 2, "18", 20, 0.7],	# A∩B∩C：装饰必须亮着（A），但 B 拦掉动态
		["109040000", 8, "16", 7, 0.6],
		["411000000", 1, "18", 20, 0.45],	# 名单外：动态照放、装饰藏起来
	]
	for 行 in 表:
		var 路径 := 地图资源.baked_scene_path(String(行[0]))
		if not ResourceLoader.exists(路径):
			_失败.append("%s 没有烘焙场景，这条验不了" % 行[0])
			continue
		var 原图: String = str(会话.current_map_id)
		会话.set("current_map_id", String(行[0]))
		var 场 := (load(路径) as PackedScene).instantiate()
		root.add_child(场)
		await process_frame
		var 节 := 场.get_node_or_null("天气特效")
		_记(节 != null, "%s 的地图根节点自动挂上了天气特效（`地图根节点._挂天气特效()`）" % 行[0])
		if 节 == null:
			场.queue_free()
			await process_frame
			continue
		_记(int(节.get("layer")) == 天气脚本.层级,
				"%s 的节点自己把 CanvasLayer 设成 %d（世界 0 与 小地图面板 20 之间）"
				% [行[0], 天气脚本.层级])
		# 装饰物：真烘焙场景里那些 nature_16/17/18 节点（可见性一律由 A 名单决定）。
		var 物件 := 场.get_node_or_null("ObjectRoot")
		var 查到的: Array[String] = []
		var 实测: Array = []
		var 全对 := true
		if 物件 != null:
			var 该看 := 天气脚本.在静态名单A(String(行[0]))
			for 件 in 物件.get_children():
				var 名 := String(件.name)
				if 名.begins_with("Obj_acc_shuizhiguo_nature_"):
					var 尾 := 名.substr("Obj_acc_shuizhiguo_nature_".length()).split("_")[0]
					if 尾 == "16" or 尾 == "17" or 尾 == "18":
						查到的.append(名)
						实测.append(bool((件 as CanvasItem).visible))
						if bool((件 as CanvasItem).visible) != 该看:
							全对 = false
		_记(not 查到的.is_empty() and 全对,
				"%s 真场景里的 %s 可见性应逐个 = A 名单(%s)，实测 %s"
				% [行[0], str(查到的), str(天气脚本.在静态名单A(String(行[0]))), str(实测)])
		# 主线程只该解**首帧**：整叠同步解实测 1831ms（雨 20 张 5260×1770）＝
		# "起雾那一刻画面冻一下"，这就是这一条要钉住的东西。
		var 起算 := Time.get_ticks_msec()
		节.call("应用", int(行[1]))
		var 主线程毫秒 := Time.get_ticks_msec() - 起算
		print("天气特效：%s 类型 %d 的 应用() 主线程耗时 %dms（旧写法同步解整叠实测 1831ms）"
				% [行[0], 行[1], 主线程毫秒])
		await process_frame
		var 片 := 场.get_node_or_null("天气特效/天气片") as Sprite2D
		if bool(天气脚本.在禁动态名单B(String(行[0]))):
			_记(片 == null, "%s 在 B 名单 ⇒ 类型 %d 也不该有天气片（`:3881`）" % [行[0], 行[1]])
		else:
			_记(片 != null, "%s 类型 %d 该有天气片" % [行[0], 行[1]])
			_记(主线程毫秒 < 400,
					"%s 类型 %d：应用() 返回只花 %dms（首帧同步 + 其余交 WorkerThreadPool；"
					% [行[0], 行[1], 主线程毫秒]
					+ "旧写法在这里同步解完整叠 = 实测 1831ms，画面冻住）")
			if 片 != null:
				var 视口: Vector2 = root.get_visible_rect().size
				# 剩下的帧是后台一叠一叠烘出来、主线程每帧收几张 ⇒ 等它长齐（最多 ~8 秒）。
				var 等待 := 0
				while (节.get("帧") as Array).size() < int(行[3]) and 等待 < 480:
					await process_frame
					等待 += 1
				_记((节.get("帧") as Array).size() == int(行[3]),
						"nature_%s 流式烘完真读到 %d 帧（素材目录 %s），实测 %d（等 %d 帧）"
						% [行[2], 行[3], 行[0], (节.get("帧") as Array).size(), 等待])
				_记(absf(片.modulate.a - float(行[4])) < 1e-6,
						"整层透明度 = %.2f（原版 `_loc3_.alpha`，`Client.as:3919`），实测 %.4f"
						% [float(行[4]), 片.modulate.a])
				_记(int(片.texture.get_width()) == maxi(int(视口.x), 1) \
						and int(片.texture.get_height()) == maxi(int(视口.y), 1),
						"裁到视口那么大（%.0f×%.0f 屏幕画素材 (25,1) 起的那一块）—— 实测 %d×%d；"
						% [视口.x, 视口.y, 片.texture.get_width(), 片.texture.get_height()]
						+ "原版整张无损 RGBA8 是 20 帧 745MB 显存，本机不吃这个价")
				# 帧节拍：直接喂 delta 走累加器，0.05s × 4 = 0.2s ⇒ 正好两步（100ms/步）。
				节.set("帧号", 0)
				节.set("帧时", 0.0)
				for _次 in range(4):
					节.call("_process", 0.05)
				_记(int(节.get("帧号")) == 2,
						"0.20s 走 2 帧 ⇒ 帧间隔 100ms（`Animation.as:47-50`），实测 %d" % int(节.get("帧号")))
		场.queue_free()
		await process_frame
		会话.set("current_map_id", 原图)

## ─  端到端：1570 帧 → 会话 hud_state → 节点真的画出来  ──────────────────────
func _钉端到端() -> void:
	var 会话 := root.get_node_or_null("GameSession")
	var 后端 := root.get_node_or_null("BackendConnection")
	if 会话 == null or 后端 == null:
		_失败.append("缺 /root/GameSession 或 /root/BackendConnection，端到端那条腿没法跑")
		return
	var 路径 := 地图资源.baked_scene_path("101010000")
	var 场 := (load(路径) as PackedScene).instantiate()
	root.add_child(场)
	await process_frame
	var 节 := 场.get_node_or_null("天气特效")
	_记(节 != null, "进图时地图根节点自动挂上了天气特效")
	if 节 != null:
		_记(int(节.get("类型")) == int((会话.hud_state as Dictionary).get("weather_type", -1)),
				"节点建出来就按会话当前的 hud_state 摆了一次（`_ready` 读 weather_type），"
				+ "实测节点类型 %d / 会话 %d" % [int(节.get("类型")),
						int((会话.hud_state as Dictionary).get("weather_type", -1))])
	# 喂一条 1570:8（大雾）—— 与在线门 `后端协议回归测试` 钉的是同一条解析入口。
	后端.call("_handle_weather_text", "1570:8".split(":", true))
	await process_frame
	_记(int((会话.hud_state as Dictionary).get("weather_type", -1)) == 8,
			"1570 ⇒ hud_state.weather_type = 8（`游戏会话._on_backend_weather:2312-2315`）")
	var 片 := 场.get_node_or_null("天气特效/天气片") as Sprite2D
	_记(片 != null and absf(片.modulate.a - 0.6) < 1e-6,
			"收到 1570:8 之后雾层**真的自己长出来了**、透明度 0.6（`:3899`），实测 %s" % str(片))
	# 再喂一条 1570:0（恢复"无天气"）⇒ 层必须收干净，不留僵尸。
	后端.call("_handle_weather_text", "1570:0".split(":", true))
	await process_frame
	_记(场.get_node_or_null("天气特效/天气片") == null,
			"1570:0 ⇒ 天气片收掉（`:3840-3841` 开头先 clear，`:3901-3904` 空图号直接 return）")
	场.queue_free()
	await process_frame

func _收尾() -> void:
	if _失败.is_empty():
		print("天气特效回归测试：通过 %d 条，失败 0 条" % _条数)
		quit(0)
		return
	for 条 in _失败:
		print("  !! " + 条)
	print("天气特效回归测试：%d 条里 %d 项不通过（共 %d 条判据）" % [_条数, _失败.size(), _条数])
	quit(1)
