extends SceneTree

## 小地图正式化门（地图缩略图 + 四类原版标记）。
##
## 跑法：Godot --headless --path . --script res://测试/小地图标记回归测试.gd
##
## 三道腿缺一不可，各挡一类「看着像做完了」：
##  * **表腿**：`数据/界面/小地图标记.json` 的锚点必须能从它自己记的形状框重算出来
##    （手改一个数就红），且每条有贴图的都要在盘上、尺寸对得上。
##  * **几何腿**：图尺寸 = 贴图 × scale/16、世界→图素 = (世界 + center)/16、
##    视口恒 143×124、图比视口小就居中且不滚 —— 全部按 AS3 常数与算式判，不判"我确实调过"。
##  * **行为腿**：死区滚动。这一条是眼睛看得见的差别 —— 居中跟随每步都抖，
##    原版只在越过 1/5、4/5 两条线时挪。所以判据是「带内移动偏移**不变**」，
##    拿居中实现来跑必然红（变异实测见 真值 md §自检）。
##
## ⚠ 本门**不许写存档**：会真点原生控件、真改会话状态，全部走快照 + 还原 + 断言。

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 面板脚本 := preload("res://脚本/界面/小地图面板.gd")
const 默认地图 := "101010000"
const 存档 := "user://玩家数据.json"
## 框皮 `SmallMapWindowF.png`（195×179）上**内凹口**的实测矩形：从种子 (120,90) 按颜色洪扩
## + 逐行/逐列找最长暗段量出来的（暗底 RGB≈(55,57,62)、alpha 236）。
## 与 AS3 对得上：`SmallMapWindowF`(MainLib 精灵 293) 里 `content_bg` 的 matrix
## translateX/Y = 5460/480 twips = (273,24) 元件坐标，而 `title_bg` 在 (230,0)
## ⇒ 导出图裁掉了左边 227px ⇒ content_bg 落在皮上 (46,24)；
## `SmallMapWindow.as:1036-1037` 视口 = content_bg + (4,4) ⇒ (50,28) 量级，与实测凹口 (49,30) 同一条。
const 凹口 := Rect2(49, 30, 140, 120)

var _红: Array[String] = []
var _条数 := 0


func _判(说明: String, 成立: bool) -> void:
	_条数 += 1
	if not 成立:
		_红.append(说明)


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 快照 := ""
	if FileAccess.file_exists(存档):
		var 原 := FileAccess.open(存档, FileAccess.READ)
		快照 = 原.get_as_text()
		原.close()
	await _表腿()
	await _全图腿()
	await _几何腿()
	await _行为腿()
	await _接线腿()
	# 还原 + 断言还原本身（旧教训：还原不判 = 门自己把存档改了也没人知道）
	if 快照 != "":
		var 写 := FileAccess.open(存档, FileAccess.WRITE)
		写.store_string(快照)
		写.close()
	var 现 := ""
	if FileAccess.file_exists(存档):
		var 再 := FileAccess.open(存档, FileAccess.READ)
		现 = 再.get_as_text()
		再.close()
	_判("门不许动存档（user://玩家数据.json）", 现 == 快照)
	print("小地图标记回归测试：共 %d 条，红 %d 条%s" % [_条数, _红.size(), "" if _红.is_empty() else "：" ])
	for 项 in _红:
		print("  ✗ ", 项)
	quit(0 if _红.is_empty() else 1)


func _取面板() -> Node:
	for 层 in root.get_children():
		if str(层.get("name")) == "小地图面板":
			return 层
		var 找 := 层.find_child("小地图面板", true, false)
		if 找 != null:
			return 找
	return null


func _进图() -> Node:
	var 路: String = 地图资源.playable_scene_path(默认地图)
	var 包 := load(路) as PackedScene
	if 包 == null:
		_红.append("加载不到地图场景 %s" % 路)
		return null
	var 场 := 包.instantiate()
	## ⚠ 必须在 add_child **之前**钉尺寸：无头默认视口下 GUI 命中拿不到 ⇒ 点了静默不生效
	## （`卡片套册交互回归测试.gd:15` 早写过这条，本轮寻路腿第一版就是栽在"事后才改尺寸"）。
	root.size = Vector2i(960, 560)
	root.add_child(场)
	current_scene = 场
	for _秒 in range(6):
		await process_frame
	return 场


## ── 表腿：锚点表自洽 + 与盘上的图同源 ─────────────────────────────────
func _表腿() -> void:
	var 表: Dictionary = 面板脚本._读标记表()
	_判("标记表读得出（数据/界面/小地图标记.json）", not 表.is_empty())
	if 表.is_empty():
		return
	## SmallMapHelper.as:10-32 那十二枚 CLASS_* 一枚都不能少
	var 十二 := ["minimap_portal_skin", "minimap_user_skin", "minimap_friend_skin", "minimap_mob_skin",
			"minimap_mobBoss_skin", "minimap_mobJingYing_skin", "minimap_npc_skin",
			"minimap_startnpc_skin", "minimap_questing_skin", "minimap_endnpc_skin",
			"minimap_party_skin", "minimap_partymaster_skin"]
	for 名 in 十二:
		_判("表里有 %s（SmallMapHelper.as:10-32）" % 名, 表.has(名))
	var 全: Dictionary = {}
	var 文 := FileAccess.open("res://数据/界面/小地图标记.json", FileAccess.READ)
	if 文 != null:
		全 = JSON.parse_string(文.get_as_text()) as Dictionary
	for 名 in 表:
		var 条: Dictionary = 表[名] as Dictionary
		var a: Array = 条.get("锚点", []) as Array
		var 框: Array = 条.get("形状框", []) as Array
		_判("%s 锚点/形状框都在表里" % 名, a.size() == 2 and 框.size() == 4)
		if a.size() != 2 or 框.size() != 4:
			continue
		## 锚点必须等于形状框左上角按 **Godot 的 roundf**（.5 远离零）取整 ——
		## 生成器与这里用同一条规则，手改一个数、或改了表没重跑生成器，这条就红。
		_判("%s 锚点 == roundf(形状框左上)（[%d,%d] vs 框 %s）" % [名, int(a[0]), int(a[1]), 框],
				int(a[0]) == int(roundf(float(框[0]))) and int(a[1]) == int(roundf(float(框[1]))))
		## 这批元件全是「底边贴坐标点」：形状框下沿必须≈0（±1 是 AS3 里的半像素）
		_判("%s 底边对齐（形状框 Ymax=%s 应≈0）" % [名, 框[3]], abs(float(框[3])) <= 1.0)
		_判("%s 有出处与用途" % 名, String(条.get("出处", "")).length() > 8 and String(条.get("用途", "")).length() > 8)
		var 路 := String(条.get("贴图", ""))
		if 路 == "":
			_判("%s 没图就必须登记为什么（死链说明）" % 名, String(条.get("为什么", "")).length() > 20)
			continue
		var 盘 := 路.replace("res://", "res://")
		_判("%s 的贴图在盘上可载：%s" % [名, 路], ResourceLoader.exists(盘))
		if not ResourceLoader.exists(盘):
			continue
		var 贴 := load(盘) as Texture2D
		_判("%s 表里尺寸 == PNG 真实尺寸（%dx%d vs %s）" % [名, int(条.get("图宽", 0)), int(条.get("图高", 0)), 贴.get_size()],
				贴 != null and int(条.get("图宽", -1)) == int(贴.get_size().x) and int(条.get("图高", -1)) == int(贴.get_size().y))
	_判("表里视口常数 == 143×124（SmallMapWindow.as:55-61）",
			int(((全.get("视口", {}) as Dictionary).get("宽", 0))) == 143
			and int(((全.get("视口", {}) as Dictionary).get("高", 0))) == 124)
	_判("表里钉的是 2.2.3优化版（元件库路径含 2.2.3优化版）",
			String((全.get("真值", {}) as Dictionary).get("元件库路径", "")).contains("2.2.3优化版"))
	_判("表里记了元件库 md5（换 SWF 要能查）",
			String((全.get("真值", {}) as Dictionary).get("元件库md5", "")).length() == 32)


## ── 全图腿：把口径推到**索引里的每一张图**上（回答"所有小地图都加上这些元素了吗"）──
## 为什么必须有这一条：前三条腿只量了两张图（木叶村 / 终结谷浅滩）。
## "数据驱动 ⇒ 对所有图都生效"是一句**断言**，不是证据；只有逐张跑一遍才算量过。
## 判三样：
##  ① 索引里每张图都得有 `miniMap` 段（否则算式无从谈起）；
##  ② 有缩略图的每张都验「贴图 × scale/16 == miniMap.width/16」两条腿互算（≤1px）；
##  ③ **缺缩略图的清单必须恰好等于登记过的那几张** —— 多一张就红。
##     这样导出链以后再漏一张会被当场点名，而不是变成"那张图没底图"的哑故障。
## 门数 / NPC 数**只报数不判**：副本与竞技场本来就没有 NPC 和传送点（判了就是假红）。
func _全图腿() -> void:
	var 索 = JSON.parse_string(FileAccess.get_file_as_string("res://数据/地图索引.json"))
	var 素 = JSON.parse_string(FileAccess.get_file_as_string("res://数据/地图素材索引.json"))
	_判("地图索引读得出", typeof(索) == TYPE_DICTIONARY and (索 as Dictionary).size() > 100)
	if typeof(索) != TYPE_DICTIONARY or typeof(素) != TYPE_DICTIONARY:
		return
	var 已知缺图 := ["100030001", "112040002", "408000001", "466100002"]
	var 缺图: Array[String] = []
	var 无段: Array[String] = []
	var 违例: Array[String] = []
	var 量了 := 0
	var 最大差 := 0.0
	var 有门 := 0
	var 有NPC := 0
	for 号 in (索 as Dictionary).keys():
		var 目录 := String((索 as Dictionary)[号])
		var 路 := "res://数据/地图/%s/地图.json" % 目录
		if not FileAccess.file_exists(路):
			无段.append(String(号) + "(无目录)")
			continue
		var 数 = JSON.parse_string(FileAccess.get_file_as_string(路))
		if typeof(数) != TYPE_DICTIONARY or ((数 as Dictionary).get("miniMap", {}) as Dictionary).is_empty():
			无段.append(String(号))
			continue
		var 规: Dictionary = (数 as Dictionary).get("miniMap", {}) as Dictionary
		var 图 := String((素 as Dictionary).get("小地图/Map_%s_miniMap_canvas" % 号, ""))
		var 尺 := _png尺寸(图)
		if 尺 == Vector2.ZERO:
			缺图.append(String(号))
		else:
			量了 += 1
			var 档 := float(规.get("scale", 0.0))
			if 档 <= 0.0:
				档 = 8.0	# PicTool.as:477 `scale || 8`
			var 差 := maxf(absf(尺.x * 档 / 16.0 - float(规.get("width", 0.0)) / 16.0),
					absf(尺.y * 档 / 16.0 - float(规.get("height", 0.0)) / 16.0))
			最大差 = maxf(最大差, 差)
			if 差 > 1.0:
				违例.append("%s(%dx%d scale %s 差 %.2f)" % [号, int(尺.x), int(尺.y), str(档), 差])
		var 门: Variant = (数 as Dictionary).get("portal", {})
		var 门表: Array = (门 as Dictionary).values() if 门 is Dictionary else (门 as Array if 门 is Array else [])
		for 项 in 门表:
			if 项 is Dictionary and int((项 as Dictionary).get("pt", 0)) == 2:
				有门 += 1
				break
		var 生: Variant = (数 as Dictionary).get("life", {})
		var 生表: Array = (生 as Dictionary).values() if 生 is Dictionary else (生 as Array if 生 is Array else [])
		for 项 in 生表:
			if 项 is Dictionary and str((项 as Dictionary).get("type", "")) == "n":
				有NPC += 1
				break
	_判("索引里每张图都有 miniMap 段（缺：%s）" % str(无段), 无段.is_empty())
	_判("两条腿互算逐张 ≤1px（违例 %s，最大 %.3fpx）" % [str(违例), 最大差], 违例.is_empty())
	缺图.sort()
	_判("缺缩略图的只有登记过那几张（实 %s / 已知 %s）" % [str(缺图), str(已知缺图)], 缺图 == 已知缺图)
	_判("逐张量到的张数 == 索引数 − 已知缺图（%d vs %d）" % [量了, (索 as Dictionary).size() - 已知缺图.size()],
			量了 == (索 as Dictionary).size() - 已知缺图.size())
	print("   全图腿：索引 %d 张 / 逐张验过 %d 张 / 最大偏差 %.3fpx / 有 pt==2 传送点 %d 张 / 有 NPC %d 张（副本与竞技场本就没 NPC）"
			% [(索 as Dictionary).size(), 量了, 最大差, 有门, 有NPC])


## 只读 PNG 头拿尺寸（不 load 纹理：170 张全载进来会把门拖慢一个量级，也白占内存）。
func _png尺寸(路: String) -> Vector2:
	if 路 == "" or not FileAccess.file_exists(路):
		return Vector2.ZERO
	var 文 := FileAccess.open(路, FileAccess.READ)
	if 文 == null:
		return Vector2.ZERO
	var 头 := 文.get_buffer(24)
	文.close()
	if 头.size() < 24:
		return Vector2.ZERO
	if 头[0] != 0x89 or 头[1] != 0x50 or 头[2] != 0x4E or 头[3] != 0x47:
		return Vector2.ZERO
	return Vector2((头[16] << 24) | (头[17] << 16) | (头[18] << 8) | 头[19],
			(头[20] << 24) | (头[21] << 16) | (头[22] << 8) | 头[23])


## ── 几何腿：装载 / 投影 / 视口 ────────────────────────────────────────
func _几何腿() -> void:
	var 画 := 面板脚本.MinimapCanvas.new()
	画.标记表 = 面板脚本._读标记表()
	_判("画序第一条是图、最后一条是自己（SmallMapWindow.as:1043-1050）",
			str(画.画序[0]) == "图" and str(画.画序[画.画序.size() - 1]) == "自己")
	_判("画序有七组（图/npc/他人/怪/传送点/旗/自己）", 画.画序.size() == 7)
	_判("NPC 四态类名逐字（SmallMapHelper.as:24/28/26/22）",
			str(画.NPC态[0]) == "minimap_npc_skin" and str(画.NPC态[1]) == "minimap_startnpc_skin"
			and str(画.NPC态[2]) == "minimap_endnpc_skin" and str(画.NPC态[3]) == "minimap_questing_skin")

	# 大地图那条腿：贴图 480×280、scale 5 ⇒ 显示 150×87.5；x 比视口宽要滚，y 比视口高要居中
	var 大 := {"width": 2400.0, "height": 1400.0, "centerX": 0.0, "centerY": 100.0, "scale": 5.0}
	画.装载(大, load("res://素材/地图/终结谷浅滩/小地图.png") as Texture2D)
	_判("图尺寸 = 贴图 × scale/16（setMap:1442）", is_equal_approx(画.图尺寸.x, 150.0) and is_equal_approx(画.图尺寸.y, 87.5))
	_判("图尺寸 == miniMap.width/16（PicTool.as:473-474 两条腿互算）",
			abs(画.图尺寸.x - 2400.0 / 16.0) < 0.51 and abs(画.图尺寸.y - 1400.0 / 16.0) < 0.51)
	_判("x 比视口宽 ⇒ 可视.x = 143、偏移.x = 0", is_equal_approx(画.可视.x, 143.0) and is_equal_approx(画.面板偏移.x, 0.0))
	_判("y 比视口高 ⇒ 可视.y = 图高、偏移.y 居中（updateMapView:1091-1094）",
			is_equal_approx(画.可视.y, 87.5) and is_equal_approx(画.面板偏移.y, (124.0 - 87.5) / 2.0))
	_判("世界 (0,0) → 图素 ((0+centerX)/16,(0+centerY)/16)（setMcPosition:857-858）",
			画._图素(Vector2(0, 0)) == Vector2(0.0, 6.25))
	_判("世界 (160,−160) → (10, −3.75)", 画._图素(Vector2(160, -160)) == Vector2(10.0, -3.75))
	## ⚠ 上面那两条都在 **centerX = 0** 的图上量 ⇒ 把 x 轴的 `+centerX` 写成 `−centerX` 照样全绿
	## （变异实测 M3 第一版就没响）。必须再喂一张 **centerX 非零**的：木叶村是 centerX=20/centerY=46。
	var 偏 := {"width": 4950.0, "height": 1670.0, "centerX": 20.0, "centerY": 46.0, "scale": 10.0}
	画.装载(偏, load("res://素材/地图/木叶村/小地图.png") as Texture2D)
	_判("centerX 非零：世界 (0,0) → (1.25, 2.875)（是 +center 不是 −center）",
			is_equal_approx(画._图素(Vector2.ZERO).x, 1.25) and is_equal_approx(画._图素(Vector2.ZERO).y, 2.875))
	_判("centerX 非零：世界 (−20,−46) → (0,0)（图左上角就是世界的这个点）",
			画._图素(Vector2(-20, -46)) == Vector2.ZERO)
	画.装载(大, load("res://素材/地图/终结谷浅滩/小地图.png") as Texture2D)

	# scale 缺省那一档：PicTool.as:477 `scale || 8`
	var 无 := {"width": 1600.0, "height": 800.0, "centerX": 0.0, "centerY": 0.0, "scale": 0.0}
	画.装载(无, load("res://素材/地图/终结谷浅滩/小地图.png") as Texture2D)
	_判("scale 缺省当 8（PicTool.as:477）", is_equal_approx(画.图尺寸.x, 480.0 * 8.0 / 16.0))

	# 贴图查无（hideMinimap / 索引缺项）也不能炸
	画.装载(大, null)
	_判("没贴图时图尺寸归零、不报错", 画.图尺寸 == Vector2.ZERO)
	画.free()


## ── 行为腿：死区滚动（居中跟随的实现会在这一节红）──────────────────────
## 夹具用一张**比视口宽得多**的图（495×167 的木叶村缩略图，scale 10 ⇒ 显示 309.375×104.375）：
## 终结谷那张只有 150 宽、可滚行程只有 7px，任何一次越带都会立刻撞到边缘钳位，
## 「钉在 4/5 / 1/5」这两条就量不出来（第一版在这里连红两条，红的是门，不是代码）。
func _行为腿() -> void:
	var 画 := 面板脚本.MinimapCanvas.new()
	画.标记表 = 面板脚本._读标记表()
	var 位 := {"p": Vector2.ZERO}
	画.玩家 = func(): return 位.p as Vector2
	var 宽 := {"width": 4950.0, "height": 1670.0, "centerX": 0.0, "centerY": 0.0, "scale": 10.0}
	画.装载(宽, load("res://素材/地图/木叶村/小地图.png") as Texture2D)
	_判("夹具图显示尺寸 309.375×104.375（宽 > 视口 ⇒ x 会滚；高 < 视口 ⇒ y 不滚）",
			is_equal_approx(画.图尺寸.x, 309.375) and is_equal_approx(画.图尺寸.y, 104.375))
	位.p = Vector2(1600, 0)		# 图素 100 ⇒ 屏 100，落在 28.6 ~ 114.4 的死区里
	画._挪面板()
	_判("死区内不挪面板（居中跟随的实现会在这里红）", is_equal_approx(画.面板偏移.x, 0.0))
	_判("y 轴图比视口小 ⇒ 不滚，只保留居中值并取整（:457 的 if 不成立、:468 仍 round）",
			is_equal_approx(画.面板偏移.y, roundf((124.0 - 104.375) / 2.0)))
	位.p = Vector2(2000, 0)		# 图素 125 ⇒ 屏 125 > 114.4 ⇒ 挪到把玩家钉在 4/5
	画._挪面板()
	_判("越过 4/5 后把玩家钉在 4/5（setPlayerPosition:446-450）",
			abs(画.面板偏移.x + 125.0 - 143.0 * 4.0 / 5.0) <= 1.0)
	var 钉 := 画.面板偏移.x
	位.p = Vector2(1200, 0)		# 图素 75 ⇒ 屏 −11+75 = 64，还在 28.6~114.4 带内 ⇒ 不该再挪
	画._挪面板()
	_判("带内继续走仍然不挪（%s → %s）" % [钉, 画.面板偏移.x], is_equal_approx(画.面板偏移.x, 钉))
	位.p = Vector2(4950, 0)		# 走到图右缘 ⇒ 偏移钳在 可视 − 图尺寸
	画._挪面板()
	_判("走到图右缘 ⇒ 偏移钳在 可视−图尺寸（:449）",
			is_equal_approx(画.面板偏移.x, roundf(143.0 - 309.375)))
	位.p = Vector2(500, 0)		# 图素 31.25 ⇒ 屏 −134.75 < 28.6 ⇒ 挪到钉在 1/5（还没撞左钳位）
	画._挪面板()
	_判("越过 1/5 后把玩家钉在 1/5（:451-455）",
			abs(画.面板偏移.x + 31.25 - 143.0 / 5.0) <= 1.0)
	位.p = Vector2(0, 0)			# 再往左就该钳回 0
	画._挪面板()
	_判("走到图左缘 ⇒ 偏移钳回 0（:454）", is_equal_approx(画.面板偏移.x, 0.0))
	_判("偏移两个轴都恒为整数（:468-469 Math.round）",
			is_equal_approx(画.面板偏移.x, roundf(画.面板偏移.x)) and is_equal_approx(画.面板偏移.y, roundf(画.面板偏移.y)))
	位.p = Vector2(3000, 3000)
	var 前 := 画.面板偏移
	画.玩家 = Callable()
	画._挪面板()
	_判("拿不到玩家就不挪、也不报错", 画.面板偏移 == 前)
	画.free()


## ── 接线腿：真场景里的画布、门表、任务态、hideMinimap ──────────────────
func _接线腿() -> void:
	var 场 := await _进图()
	if 场 == null:
		return
	var 板 := _取面板()
	if 板 == null:
		_红.append("场景里没有 小地图面板 这一层")
		return
	for _秒 in range(4):
		await process_frame
	var 画: Node = 板.get("_minimap")
	var 槽: Node = 板.get("_minimap_content")
	_判("画布建出来了并挂在 小地图内容槽 下", 画 != null and 槽 != null and 画.get_parent() == 槽)
	if 画 == null:
		return
	_判("画布尺寸 == 143×124", 画.size == Vector2(143, 124))
	## ↓ 这三条是 2026-10-07 被实机图打回「小地图没在框内」之后补的：
	## 以前只判"画布 143×124"、**不判它摆在哪** ⇒ 槽摆在 (43,24)（凹口外 6/6px）而门全绿。
	_判("槽位置 == 凹口左上 (%d,%d)（实 %s）" % [int(凹口.position.x), int(凹口.position.y), (槽 as Control).position],
			is_equal_approx((槽 as Control).position.x, 凹口.position.x) and is_equal_approx((槽 as Control).position.y, 凹口.position.y))
	_判("槽大小 == 凹口 %s（实 %s）" % [凹口.size, (槽 as Control).size],
			is_equal_approx((槽 as Control).size.x, 凹口.size.x) and is_equal_approx((槽 as Control).size.y, 凹口.size.y))
	_判("槽自己裁（图超出凹口的部分不许糊到框皮上）", bool((槽 as Control).clip_contents))
	_判("画布自己裁（= 原版 _mapPanel.mask，:1040-1051）", bool(画.get("clip_contents")))
	## 2026-10-07 改口：原版 _mapPanel 上挂了 CLICK（SmallMapWindow.as:1080-1083）⇒ 小地图**要吃鼠标**
	## （点它就该寻路，不是穿过去点世界）。以前这条写的是 IGNORE，等于把原版行为判反了。
	_判("画布吃鼠标（挂了 CLICK ⇒ 点它就该寻路）", int(画.mouse_filter) == int(Control.MOUSE_FILTER_STOP))
	_判("但不设手型（Flash 没给 _mapPanel 设 buttonMode ⇒ 原版一直是箭头光标）",
			int(画.mouse_default_cursor_shape) == int(Control.CURSOR_ARROW))
	var 层: Node = 画.get_node_or_null("地图层")
	_判("缩略图在子层上画（两种过滤要分开）", 层 != null)
	if 层 != null:
		_判("图层层 show_behind_parent（必须垫在标记下面）", bool(层.show_behind_parent))
		## 「子节点存在」不等于「子节点画得出东西」：源没指回来时它的 _draw 第一行就 return，
		## 而画面看起来只是"暗了一点"，很容易被当成美术问题放过去（本轮实测踩到）。
		_判("图层.源 指回画布（漏了这句 = 缩略图一张都不画，而节点存在照样绿）", 层.get("源") == 画)
		_判("图层层用线性过滤（Flash 降采样是平滑的）", int(层.texture_filter) == int(CanvasItem.TEXTURE_FILTER_LINEAR))
	_判("标记层用 NEAREST（1:1 的小人不许糊）", int(画.texture_filter) == int(CanvasItem.TEXTURE_FILTER_NEAREST))
	_判("真地图的缩略图取到了（不是空手画线）", 画.get("贴图") != null)
	_判("真地图的 miniMap 规格喂进画布了", not (画.get("规格") as Dictionary).is_empty())
	var 组: Dictionary = 画.get("组") as Dictionary
	var 门: Array = 组.get("传送点", []) as Array
	var 人: Array = 组.get("npc", []) as Array
	var 图: Dictionary = 地图资源.map_data(默认地图)
	var 真门: int = 0
	for 项 in ((图.get("portal", {}) as Dictionary)).values():
		if int((项 as Dictionary).get("pt", 0)) == 2:
			真门 += 1
	_判("传送点枚数 == 地图里 pt==2 的枚数（Client.as:8515 只认 2）", 门.size() == 真门 and 真门 > 0)
	for 项 in 门:
		_判("传送点用的元件名对", str((项 as Dictionary).get("类", "")) == "minimap_portal_skin")
	## 枚数要比**同一时刻**的两个量：先让面板按当前场上状态刷一遍，再一起读
	## （面板 _process 里那个 0.5 秒轮询会随时换掉 组，拿旧快照比新场上 = 假红）
	板.call("_刷标记")
	组 = 画.get("组") as Dictionary
	人 = 组.get("npc", []) as Array
	_判("NPC 标记枚数 == 场上 kind==n 的实体枚数（%d vs %d）" % [人.size(), (板.call("_场上实体") as Array).size()],
			人.size() == (板.call("_场上实体") as Array).size() and 人.size() > 0)
	## 门表那条过滤要**单独喂混合 pt 的夹具**才判得动：真图上五扇门全是 pt==2，
	## 把条件放宽成 `pt>0` 枚数不变（变异实测 M5 第一版没响）。
	var 原图 = 板.get("_map_data")
	板.set("_map_data", {"miniMap": {"width": 2400.0, "height": 1400.0, "centerX": 0.0, "centerY": 100.0, "scale": 5.0},
			"info": {}, "portal": {"a": {"pn": "a", "pt": 1, "tm": 101040000, "x": 100.0, "y": 200.0},
			"b": {"pn": "b", "pt": 2, "tm": 101040000, "x": 300.0, "y": 400.0},
			"c": {"pn": "c", "pt": 4, "tm": 101040000, "x": 500.0, "y": 600.0}}})
	板.call("_刷标记")
	var 夹门: Array = ((画.get("组") as Dictionary).get("传送点", []) as Array)
	_判("夹具三条门（pt=1/2/4）只画 pt==2 那一条（实得 %d）" % 夹门.size(), 夹门.size() == 1)
	if 夹门.size() == 1:
		_判("留下的那条就是 pt==2 的位置（世界 300,400）",
				(夹门[0] as Dictionary).get("位") == Vector2(300, 400))
	板.set("_map_data", 原图)
	板.call("_接地图")
	for 项 in 人:
		_判("NPC 那几枚的类名都在四态表里",
				str((项 as Dictionary).get("类", "")) in ["minimap_npc_skin", "minimap_startnpc_skin",
				"minimap_endnpc_skin", "minimap_questing_skin"])
	## ── 怪（§3.117）────────────────────────────────────────────────────
	## 原版：`Monster.addToSmallMap:1849-1856` → `SmallMapHandler.addMob:188-208`，
	## 皮按 `mobInfo.boss` 三档（`SmallMapHelper.getMobMC:76-89`），`hideMob == 1` 时一枚都不加。
	板.call("_刷标记")
	组 = 画.get("组") as Dictionary
	var 怪: Array = 组.get("怪", []) as Array
	var 场上怪: Array = 板.call("_场上怪") as Array
	_判("这张图确实有怪（不然下面几条是空的）", 场上怪.size() > 0)
	_判("怪标记枚数 == 场上 kind==m 的实体枚数（%d vs %d）" % [怪.size(), 场上怪.size()],
			怪.size() == 场上怪.size())
	for 项 in 怪:
		var d := 项 as Dictionary
		_判("怪皮的类名在三档里（实 %s）" % [d.get("类", "")],
				str(d.get("类", "")) in ["minimap_mob_skin", "minimap_mobBoss_skin", "minimap_mobJingYing_skin"])
		_判("怪那枚带名字（悬停提示用 = 原版 `getMobName()`）", not String(d.get("名", "")).is_empty())
	# 三档皮：从**真表**里各找一条 boss=0/1/2 的怪来判（不写死 id —— 写死等于抄一遍表）
	var 怪表: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://数据/怪物.json")) as Dictionary
	var 各档 := {}
	for 怪id in 怪表.keys():
		var b := str(int((怪表[怪id] as Dictionary).get("boss", 0)))
		if not 各档.has(b):
			各档[b] = String(怪id)
	var 期望皮 := {"0": "minimap_mob_skin", "1": "minimap_mobBoss_skin", "2": "minimap_mobJingYing_skin"}
	for 档 in 期望皮.keys():
		if 各档.has(档):
			_判("boss=%s 的怪走 %s（id %s）" % [档, 期望皮[档], 各档[档]],
					板.call("_怪皮", 各档[档]) == 期望皮[档])
	## ── 服务端 `513` 那一档（§3.118）──────────────────────────────────
	## 原版 NPC 头上那枚皮的**唯一真相**是服务端推的（`SmallMapWindow.setNpcStatus:1605-1650`），
	## 我们原来只有"按任务列表自己推"那条老路。这里钉两件事：**收到 513 ⇒ 服务端说了算**；
	## **没收到 ⇒ 回落本地推**。判据做成**决定性**的：先把两条任务表清空（本地推必然是 0），
	## 服务端却说"可交(2)" ⇒ 皮必须变成 endnpc，而不是 npc。
	var 会话节点: Node = root.get_node_or_null("GameSession")
	var 场根 := 场.get_node_or_null("LifeRoot")
	if 会话节点 != null and 场根 != null and 场根.has_method("_spawn_life_entry"):
		var 假对象 := 987654
		var 假演员 = 场根.call("_spawn_life_entry",
				{"type": "n", "id": "00000027", "object_id": 假对象, "x": 1200.0, "y": 300.0}, 900, true)
		var 原已接: Array = (会话节点.get("accepted_quests") as Array).duplicate(true)
		var 原可接: Array = (会话节点.get("available_quests") as Array).duplicate(true)
		(会话节点.get("accepted_quests") as Array).clear()
		(会话节点.get("available_quests") as Array).clear()
		var 取那枚 := func() -> String:
			板.call("_刷标记")
			for 项 in ((画.get("组") as Dictionary).get("npc", []) as Array):
				var d := 项 as Dictionary
				if String(d.get("号", "")).lstrip("0") == "27" and int(d.get("对", 0)) == 假对象:
					return String(d.get("类", ""))
			return "<没找到>"
		_判("离线那条老路：两条任务表清空 ⇒ 那枚 NPC 是 npc 皮（本地推 0）",
				取那枚.call() == "minimap_npc_skin")
		# ⚠️ 2026-10-15 并分支后：**513 的单一真源是「后端那张表」**（`后端连接.npc_quest_status`），
		#    会话不再自己存一份；访问入口是 `会话.npc_quest_status(模板号)`，内部按 `map_npcs`
		#    把 object_id 反查成模板号。所以这里往**后端**种，并且要打开 `authenticated` 才走在线那支。
		var 后端513: Node = root.get_node_or_null("BackendConnection")
		if 后端513 == null:
			_判("BackendConnection 单例在（下面 513 那三条腿的前提）", false)
		else:
			var 认证513 = 后端513.get("authenticated")
			var 态表513: Dictionary = 后端513.get("npc_quest_status")
			var 本表513: Dictionary = 后端513.get("map_npcs")
			var 态备513: Dictionary = 态表513.duplicate(true)
			var 本备513: Dictionary = 本表513.duplicate(true)
			后端513.set("authenticated", true)
			本表513[假对象] = {"npc_id": 27}	# object_id → 模板号（"00000027" ⇒ 27）
			态表513[假对象] = 2			# 2 = CAN_COMPLETE 可交
			_判("收到 513 说「可交(2)」⇒ 皮换成 endnpc（**本地推不出来**，所以这条是决定性的）",
					取那枚.call() == "minimap_endnpc_skin")
			态表513[假对象] = 1			# 1 = CAN_START 可接
			_判("513 改口「可接(1)」⇒ 皮跟着换 startnpc", 取那枚.call() == "minimap_startnpc_skin")
			态表513.erase(假对象)
			_判("513 那条撤掉 ⇒ 回落本地推（还是 npc 皮）", 取那枚.call() == "minimap_npc_skin")
			本表513.clear(); 本表513.merge(本备513)
			态表513.clear(); 态表513.merge(态备513)
			后端513.set("authenticated", 认证513)
		(会话节点.get("accepted_quests") as Array).assign(原已接)
		(会话节点.get("available_quests") as Array).assign(原可接)
		if 假演员 is Node:
			(假演员 as Node).queue_free()
		await process_frame
	# hideMob == 1 ⇒ 一枚怪都不加（`SmallMapHandler.addMob:190-195`）
	var 原图怪 = 板.get("_map_data")
	var 假图 := (原图怪 as Dictionary).duplicate(true)
	(假图["miniMap"] as Dictionary)["hideMob"] = 1
	板.set("_map_data", 假图)
	板.call("_刷标记")
	_判("hideMob==1 的图上**一枚怪都不画**",
			((画.get("组") as Dictionary).get("怪", []) as Array).is_empty())
	板.set("_map_data", 原图怪)
	板.call("_接地图")
	# 自己：画布按 玩家 Callable 现取，不靠组
	var 会话: Node = root.get_node_or_null("GameSession")
	if 会话 != null:
		var 玩: Node = get_first_node_in_group("player") as Node
		if 玩 != null:
			玩.global_position = Vector2(1144.0, 200.0)
			for _秒 in range(3):
				await process_frame
			## 「自己」那一枚取到的必须是 user 那张图（不是 npc / 不是空）
			var 自: Texture2D = 画._皮("minimap_user_skin") as Texture2D
			_判("自己那枚取到 minimap_user_skin 的图（SmallMapHelper.as:12）",
					自 != null and 自.resource_path.ends_with("minimap_user_skin/1.png"))
			var 标: Dictionary = 面板脚本._读标记表()
			## ⚠ JSON 解出来的数一律是 float ⇒ 不能拿 `== [-5,-12]` 比（数组元素类型不同，实测假红）
			var 锚: Array = (标.get("minimap_user_skin", {}) as Dictionary).get("锚点", []) as Array
			## ⚠ `%s` 右操作数必须是**数组**：`"… %s" % 锚`（锚是 Array）会被当成两个参数 ⇒
			##   `String formatting error: not all arguments converted`，那条断言照样计数、
			##   但**文案整条丢掉**（实测：红 0 里藏着一条说不出话的判据）。
			_判("user 锚点 == 表里的 [-5,-12]（实得 %s）" % [锚],
					锚.size() == 2 and int(锚[0]) == -5 and int(锚[1]) == -12)
	# ── 任务态四档：测**活的那条** `会话.npc_quest_status()` ──────────────────
	## ⚠ 这一段原来测的是 `小地图面板.NPC任务状态()`（static）。头顶（`地图实体.gd:998,1259`）与
	## 小地图（`小地图面板.gd:1706`）都改走 `会话.npc_quest_status()` 之后，那份**一个调用者都没有**，
	## 门却照绿 ⇒ 真链零覆盖（查 #148 那晚抓到的第二处自证）。函数已删，判据全落到活的那条：
	## 优先级 **可交(2) > 进行中(3) > 可接(1) > 无(0)**、回复NPC 键序 `turn_in_npc → target_npc → giver_npc`，
	## 出处 `游戏会话.gd:378-397` 与 `:2379-2380`。
	var 后端: Node = root.get_node_or_null("BackendConnection")
	## ⚠ 这两条是**硬判据**，不许只写 `if … != null` 就往下走：整块任务标记腿都包在里面，
	## 一旦哪个单例没加载起来（变异实测真撞到过一次：把 `if` 条件写成 Python 的 `False` ⇒
	## 游戏会话.gd 整份 parse 失败 ⇒ 会话为 null ⇒ 26 条判据一条都没跑，而门照样报「红 0」）。
	_判("GameSession 单例在（缺了下面整块任务标记腿一条都不会跑）", 会话 != null)
	_判("BackendConnection 单例在（同上）", 后端 != null)
	if 会话 != null and 后端 != null:
		var 认证原 = 后端.get("authenticated")
		var 态表: Dictionary = 后端.get("npc_quest_status")
		var 本表: Dictionary = 后端.get("map_npcs")
		var 态备份: Dictionary = 态表.duplicate(true)
		var 本备份: Dictionary = 本表.duplicate(true)
		var 已接备份: Array = []
		var 可接备份: Array = []
		for d in 会话.accepted_quests:
			已接备份.append(d)
		for d in 会话.available_quests:
			可接备份.append(d)
		## typed `Array[Dictionary]` ⇒ 只能 clear + 逐条 append，整份赋值会红
		态表.clear()
		本表.clear()
		会话.accepted_quests.clear()
		会话.available_quests.clear()
		会话.accepted_quests.append({"id": "g1", "target_npc": 2, "completed": true})
		会话.accepted_quests.append({"id": "g2", "target_npc": 3})
		会话.accepted_quests.append({"id": "g3", "target_npc": 5, "completed": true})
		会话.accepted_quests.append({"id": "g4", "target_npc": 6})
		会话.accepted_quests.append({"id": "g5", "turn_in_npc": 7, "target_npc": 99, "completed": true})
		会话.available_quests.append({"id": "g6", "giver_npc": 4})
		会话.available_quests.append({"id": "g7", "giver_npc": 5})
		会话.available_quests.append({"id": "g8", "giver_npc": 6})
		会话.available_quests.append({"id": "g9", "npc_id": 8})
		后端.set("authenticated", false)
		_判("离线倒推：已接且已完成 → 可交(2)", int(会话.call("npc_quest_status", "2")) == 2)
		_判("离线倒推：已接未完成 → 进行中(3)", int(会话.call("npc_quest_status", "3")) == 3)
		_判("离线倒推：只在可接列表里 → 可接(1)", int(会话.call("npc_quest_status", "4")) == 1)
		_判("离线倒推：三处都查不到 → 无(0)", int(会话.call("npc_quest_status", "9")) == 0)
		_判("同一枚既可接又可交 ⇒ 可交优先", int(会话.call("npc_quest_status", "5")) == 2)
		_判("同一枚既进行中又有可接 ⇒ 进行中优先", int(会话.call("npc_quest_status", "6")) == 3)
		_判("回复NPC 键序 turn_in_npc 优先于 target_npc", int(会话.call("npc_quest_status", "7")) == 2)
		_判("target_npc 被 turn_in_npc 顶掉 ⇒ 99 那枚不该亮", int(会话.call("npc_quest_status", "99")) == 0)
		## ⚠ 活的那条**只认 giver_npc**；`npc_id` 是刚删掉的死函数才认的别名 ⇒ 如实钉成 0，
		## 别让这条偷偷变绿：真要支持 `npc_id`，得先改 `游戏会话.npc_quest_status()`（那是口径改动，要点头）。
		_判("可接只认 giver_npc，npc_id 这一路活函数不支持（实得 %d）"
				% int(会话.call("npc_quest_status", "8")), int(会话.call("npc_quest_status", "8")) == 0)
		## **生产形状**那一条：真数据两边都是补零的串（`离线示例数据.gd` 的 giver_npc 对
		## `地图实体.gd:647` 的 entity_id）。上面那些单位数的夹具是为了测「数字不许崩」，
		## 这条才是线上真正会长的那副样子 —— 两个都得响。
		会话.accepted_quests.append({"id": "g10", "target_npc": "00000011", "completed": true})
		_判("补零串形状比得上：target_npc 为 00000011 ⇒ 可交(2)",
				int(会话.call("npc_quest_status", "00000011")) == 2)
		## ── 在线：513 说什么就是什么，客户端不许自己否决
		后端.set("authenticated", true)
		态表[7001] = 1
		本表[7001] = {"npc_id": 2}
		_判("在线以 513 为准：本地算出可交(2)、513 说可接(1) ⇒ 回 1（实得 %d）"
				% int(会话.call("npc_quest_status", "2")), int(会话.call("npc_quest_status", "2")) == 1)
		_判("513 查无这一枚 ⇒ 才落回本地倒推（实得 %d）"
				% int(会话.call("npc_quest_status", "3")), int(会话.call("npc_quest_status", "3")) == 3)
		## 513 存的是 **object_id**，要靠 `map_npcs` 反查模板号；反查不上时不许乱套。
		态表[7003] = 2
		_判("513 的行反查不到 object_id ⇒ 不能拿它去顶别的枚（可接那枚仍回 1）",
				int(会话.call("npc_quest_status", "4")) == 1)
		## ── **这条才是 #148 的护栏**：小地图那一格的「类」必须由同一次 `npc_quest_status()` 决定。
		## 以前门里只判「类名在四态表里」，于是「头顶亮、小地图不亮」（用户打回的那一条）门里全绿。
		var 实们: Array = 板.call("_场上实体")
		var 号0 := ""
		if 实们.size() > 0:
			号0 = String((实们[0] as Dictionary).get("号"))
		## 同源那三条腿没有实体就等于没跑 ⇒ 必须点名红，不许静默跳过。
		_判("能从场上取到第一枚 NPC 的号（同源三条腿的前提）", 号0 != "")
		if 号0 != "":
			态表.clear()
			本表.clear()
			本表[8001] = {"npc_id": int(号0)}
			## ⚠ 这一段**不许 await**：面板 `_process` 里每 0.5 秒会自己重刷一次 组，
			## 中间让出帧就等于拿别人刷的结果来验自己。
			态表[8001] = 1
			板.call("_刷标记")
			_判("513 说可接 ⇒ 小地图那一格换 minimap_startnpc_skin（实得 %s）" % _组里类(画, 号0),
					_组里类(画, 号0) == "minimap_startnpc_skin")
			态表[8001] = 3
			板.call("_刷标记")
			_判("513 改成进行中 ⇒ 同一格跟着换 minimap_questing_skin（实得 %s）" % _组里类(画, 号0),
					_组里类(画, 号0) == "minimap_questing_skin")
			态表[8001] = 0
			板.call("_刷标记")
			_判("513 说无任务 ⇒ 回到灰点 minimap_npc_skin，**不是不画**（实得 %s）" % _组里类(画, 号0),
					_组里类(画, 号0) == "minimap_npc_skin")
		## ── 快照还原（离线门不许留脏状态给邻居）
		态表.clear()
		本表.clear()
		会话.accepted_quests.clear()
		会话.available_quests.clear()
		for k in 态备份:
			态表[k] = 态备份[k]
		for k in 本备份:
			本表[k] = 本备份[k]
		for d in 已接备份:
			会话.accepted_quests.append(d)
		for d in 可接备份:
			会话.available_quests.append(d)
		后端.set("authenticated", 认证原)
		_判("夹具与两张表都还原干净了（态 %d 本 %d 已接 %d 可接 %d）"
				% [态表.size(), 本表.size(), 会话.accepted_quests.size(), 会话.available_quests.size()],
				态表 == 态备份 and 本表 == 本备份)
	# hideMinimap 那一档：喂一份假地图数据，判整块面板藏起来（Client.as:8508-8511）
	var 面板节点: Node = 板.get("_minimap_panel")
	if 面板节点 != null:
		var 原数据 = 板.get("_map_data")
		板.set("_map_data", {"info": {"hideMinimap": 1}, "miniMap": {"width": 100.0, "height": 100.0}})
		板.call("_刷标记")
		_判("hideMinimap==1 ⇒ 整块小地图该藏（Client.as:8508-8511）", bool(面板脚本.该藏(板.get("_map_data"))))
		_判("没有 miniMap 段也藏（PicTool.as:462 返回 null）", bool(面板脚本.该藏({"info": {}})))
		_判("正常地图不藏", not bool(面板脚本.该藏(图)))
		_判("真面板此刻是显形的", bool(面板节点.visible))
		板.set("_map_data", 原数据)
	_判("地图名与坐标两个标签都在（原版 _mapName / _positionInput）",
			板.get("_map_name") != null and 板.get("_map_coordinates") != null)
	var 坐标: Node = 板.get("_map_coordinates")
	if 坐标 != null:
		## 原版 `"[" + Math.floor(x/100) + ", " + Math.floor(y/100) + "]"`（:437）：
		## 逗号后**有空格**、且**向下取整**（负 y 时 int() 会差 1）。
		var 玩2: Node = get_first_node_in_group("player") as Node
		if 玩2 != null:
			玩2.global_position = Vector2(1050.0, -50.0)
			## ⚠️ 2026-10-15 并分支后这条腿开始红，查出来是**它自己脆**、不是代码坏：
			##    无头下每个 process 帧最多走 8 个物理步（Godot 上限）⇒ 帧时长一超 0.133 秒，
			##    玩家每帧就掉 `末速上限 670 × 0.133 ≈ 89` 像素（0.13 秒掉这么快，物理上就是"掉"）。
			##    合并后工程变重、无头帧变慢 ⇒ 4 帧够它掉 300 像素，判据变成看运气（实测两次跑出 [10,2]/[10,1]）。
			##    这里要判的是**负 y 的 floor 取整 + 逗号后空格**，跟物理无关 ⇒ 把这一帧的物理钉住。
			玩2.set_physics_process(false)
			for _秒 in range(4):
				await process_frame
			_判("坐标文本 = \"[10, -1]\"（floor + 逗号后空格，实得 %s）" % 坐标.text, 坐标.text == "[10, -1]")
			玩2.set_physics_process(true)
	await _寻路腿(板, 画)
	场.free()


## 画布 `组` 里那一枚 NPC 现在顶哪个元件名（查不到返回空串）。
## 像素只能证明「这块变了」，证明不了「变的是我喂进去的那一枚」⇒ 同源的判据要从 `组` 里读。
func _组里类(画: Node, 号: String) -> String:
	for 条 in ((画.get("组") as Dictionary).get("npc", []) as Array):
		if String((条 as Dictionary).get("号")) == 号:
			return String((条 as Dictionary).get("类"))
	return ""


## ── 寻路腿：点小地图要真的寻路（`onClickMapToFindPath:1125-1138`）──
## 三条都要**真喂鼠标事件**（`push_input` + 等帧）：`_gui_input.emit()` 会演绿。
## ⚠ 无头下视口图/拾取都按 `root.size` 算 ⇒ 必须先钉尺寸，否则点不到（工程里栽过）。
func _寻路腿(板: Node, 画: Node) -> void:
	## ① 换算：`_世界位()` 必须是 `_图素()` 的逆（原版 :1137 那个 `mouseX * 16 - centerX`）
	var 规 := {"width": 4950.0, "height": 1670.0, "centerX": 20.0, "centerY": 46.0, "scale": 10.0}
	var 贴 := load("res://素材/地图/木叶村/小地图.png") as Texture2D
	画.装载(规, 贴)
	画.面板偏移 = Vector2(-37.0, 10.0)
	var 往反 := true
	for 点在 in [Vector2(0, 0), Vector2(40, 30), Vector2(139, 119), Vector2(73, 61)]:
		var 世界: Vector2 = 画._世界位(点在)
		var 回来: Vector2 = 画._图素(世界) + 画.面板偏移
		if 回来.distance_to(点在) > 0.001:
			往反 = false
	_判("_世界位 是 _图素 的逆（四点往返，含面板滚到 −37 的情况）", 往反)
	_判("_世界位 逐字照 :1137（局部(40,30) 偏移(−37,10) center(20,46) ⇒ (%s, %s)）" %
			[画._世界位(Vector2(40, 30)).x, 画._世界位(Vector2(40, 30)).y],
			is_equal_approx(画._世界位(Vector2(40, 30)).x, (40.0 + 37.0) * 16.0 - 20.0)
			and is_equal_approx(画._世界位(Vector2(40, 30)).y, (30.0 - 10.0) * 16.0 - 46.0))
	## ② 真点一下：事件要落到画布上、并且发得出信号、世界坐标等于期望
	var 收: Array = []
	画.点了寻路.connect(func(w): 收.append(w))
	var 局 := Vector2(40.0, 30.0)
	var 全: Vector2 = (画 as Control).get_global_position() + 局
	var 玩: Node = get_first_node_in_group("player") as Node
	## 点之前先**演成打坐中**：小地图这条路不经过 `_unhandled_input`，而"自己移动就停打坐"
	## 原先只写在那里 ⇒ 第一版真的会一边挪一边播 `sit0`。现在收进 `走向` 顶部，三个入口一起生效，
	## 这条断言就是钉住它的（挪回 `_unhandled_input` 立刻红）。
	if 玩 != null:
		玩.set("is_practising", true)
	await _点(全)
	_判("真点一下小地图会发 点了寻路（实收 %d 次）" % 收.size(), 收.size() == 1)
	if 收.size() == 1:
		_判("发出来的世界坐标 == 期望 (%s, %s)（实 %s）" % [画._世界位(局).x, 画._世界位(局).y, 收[0]],
				(收[0] as Vector2).distance_to(画._世界位(局)) < 0.001)
		if 玩 != null:
			_判("点完角色确实起了走位路线（玩家.click_move_active）", bool(玩.get("click_move_active")))
			_判("点完会清掉那条一次性的自动接近（原版 toAttackAnemy=false 那一族）", 玩.get("自动接近目标") == null)
			_判("点完停掉打坐（原版每次寻路前清一整列活动状态，:1131-1136）",
					not bool(玩.get("is_practising")))
			## 这一下**只许小地图吃一次**。`玩家._unhandled_input`（`玩家.gd:100-105`）也有一条
			## 「点地面 → 走向(get_global_mouse_position())」，它的目的地 = 鼠标处的**世界位**，
			## 和小地图换算出的那个点差着一整个摄像机偏移 ⇒ 谁最后写 `click_move_x` 谁就赢了。
			## ⚠ 拦住 unhandled 的是画布那行 **`mouse_filter = STOP`**，不是 `accept_event()`：
			##   实测把 `accept_event()` 删掉这条**照样绿**（Godot 的视口在命中 STOP 控件时就把事件
			##   判为已处理，`accept_event()` 在这里是冗余保险）⇒ 想拿它当判据要改判 STOP 那条（M14 会红）。
			## （有头侧的独立证据：A 条「真点小地图」与 B 条「直调 走向」路线逐字相同 —— §12）
			_判("点这一下只被小地图吃了一次：玩家记的目的地 == 换算出的世界 x（期望 %s，实 %s）" %
					[(收[0] as Vector2).x, float(玩.get("click_move_x"))],
					is_equal_approx(float(玩.get("click_move_x")), (收[0] as Vector2).x))
	## ③ 走不通那一支 ⇒ 通知条，句子逐字 = PATH_FIND_FAIL（`en_US$message_properties.as:1346`）。
	## ⚠ 这里**不再从画布点**：第一版点的是"画布最上沿"，以为那一行换算出去没有落脚点 ——
	## 实际木叶村最上平台在 y≈−70，寻路照样成功 ⇒ 红的是门的假设。改成直接喂一个图上没有的坐标，
	## 判的是"失败要说话"这条契约，点击→世界坐标那条已经由 ①② 判过了。
	板.call("_点小地图寻路", Vector2(999999.0, 999999.0))
	var 条: Node = 板.get("_toast")
	_判("寻路走不通 ⇒ 通知条文本 == \"自动寻路失败\"（实得「%s」）" % (条.text if 条 != null else "(无条)"),
			条 != null and String(条.text) == "自动寻路失败")
	## ③a 位置与层级：原版 `messageTipContainer` 摆在 (3/5 W, 3/5 H)
	## （`UIMain2.as:3512-3513`），且是 UIMain2 的顶层子节点 —— 盖在功能窗上。
	## 2026-11-02 用户报「装备打造的信息不要显示在地图最上方」：旧位置 y=60 且留在 layer 20。
	if 条 is Control:
		var 位 := (条 as Control).get_global_rect().position
		var 期 := Vector2(root.size) * 0.6
		_判("通知条在 (0.6W, 0.6H)（期望 %s，实 %s）" % [str(期), str(位)], 位.distance_to(期) < 1.0)
		var 层 := 条.get_parent().get_parent() as CanvasLayer
		_判("通知条所在层高于功能窗(110)、低于模态确认(400)（实 %s）" % (str(层.layer) if 层 != null else "无 CanvasLayer"),
				层 != null and 层.layer >= 300 and 层.layer < 400)
	## ③b 悬停提示（§3.105）：移到一枚**带名字**的标记上 ⇒ 提示出现、文本 == 那个名字。
	## 数据面（标记带不带名字）与交互面（`_悬停到的` 命中判定）在这条上一次验掉。
	var 带名: Dictionary = {}
	for 组名 in (画.get("组") as Dictionary):
		for 枚 in ((画.get("组") as Dictionary)[组名] as Array):
			if not String((枚 as Dictionary).get("名", "")).is_empty():
				带名 = 枚
				break
		if not 带名.is_empty():
			break
	_判("场上至少有一枚**带名字**的标记（悬停提示的数据面）", not 带名.is_empty())
	if not 带名.is_empty():
		var 类名 := String(带名.get("类", ""))
		var 皮: Texture2D = 画.call("_皮", 类名)
		var 左上: Vector2 = (画.get("面板偏移") as Vector2) \
				+ (画.call("_图素", 带名.get("位")) as Vector2) + (画.call("_锚", 类名) as Vector2)
		var 中心 := 左上 + ((皮.get_size() if 皮 != null else Vector2(10.0, 12.0)) * 0.5)
		root.push_input(_移((画 as Control).get_global_position() + 中心))
		for _帧 in range(3):
			await process_frame
		var 提示: Panel = 画.get("_提示")
		var 提示字: Label = 画.get("_提示字")
		_判("悬停到带名字的标记 ⇒ 提示出现（类=%s）" % 类名, 提示 != null and 提示.visible)
		_判("提示文本 == 那枚标记的名字（期望「%s」，实「%s」）"
				% [String(带名.get("名", "")), 提示字.text if 提示字 != null else ""],
				提示字 != null and 提示字.text == String(带名.get("名", "")))
		# 移到画布**内**的空处（不是出界）⇒ 走的是"没命中任何标记"那一支，提示要收起来。
		# ⚠️ 不能随手挑 (2,2) —— 第一版就是那么写的，红了一次：那个点**正好压着一枚标记**。
		# 用同一套命中判定扫出一个真正空的位置再移过去。
		var 空处 := Vector2(-1, -1)
		var 画尺寸 := (画 as Control).size
		for y in range(2, int(画尺寸.y) - 2, 6):
			for x in range(2, int(画尺寸.x) - 2, 6):
				if String(画.call("_悬停到的", Vector2(x, y))).is_empty():
					空处 = Vector2(x, y)
					break
			if 空处.x >= 0.0:
				break
		_判("画布上扫得到一个没标记的位置（收提示那条的前提）", 空处.x >= 0.0)
		if 空处.x >= 0.0:
			root.push_input(_移((画 as Control).get_global_position() + 空处))
			for _帧 in range(3):
				await process_frame
			_判("移到没标记的地方（%s）⇒ 提示收起来" % 空处, 提示 == null or not 提示.visible)

	## ④ 没地图数据时不许点出信号
	画.装载({}, null)
	var 前 := 收.size()
	收.clear()
	await _点((画 as Control).get_global_position() + Vector2(60.0, 40.0))
	_判("没有 miniMap 段 ⇒ 点了不寻路（不发信号）", 收.is_empty() and 前 >= 0)


## 真点一下：`移到 → 等 2 帧 → 按(带 button_mask) → 等 2 帧 → 松 → 等 4 帧`。
## 这套是 `卡片套册交互回归测试.gd:112-140` 实测可用的形状，照抄不改。
func _点(位: Vector2) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 位
	移.global_position = 位
	root.push_input(移)
	for _帧 in range(2):
		await process_frame
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 位
	按.global_position = 位
	root.push_input(按)
	for _帧 in range(2):
		await process_frame
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.button_mask = 0
	放.position = 位
	放.global_position = 位
	root.push_input(放)
	for _帧 in range(4):
		await process_frame


func _移(位: Vector2) -> InputEventMouseMotion:
	var 移 := InputEventMouseMotion.new()
	移.position = 位
	移.global_position = 位
	return 移


func _放(按: InputEventMouseButton) -> InputEventMouseButton:
	var 放 := 按.duplicate() as InputEventMouseButton
	放.pressed = false
	return 放
