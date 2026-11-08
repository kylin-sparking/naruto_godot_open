extends SceneTree

## #203 打坐门：身上光环 + 围着角色的四颗球（`ButtonsWindow`）**在真实地图场景里**的行为。
##
## 真值（逐条到行号，详表见 `真值/窗口/打坐.md` ⑩~⑫）：
##   · 数据源 = `2.2.3\logs\swfprobe`
##   · 光环 = `Character.tickHealAnimation()` 挂的 `FrameQueueAnimation`，帧表来自 GameData
##     `Etc.effects.healNew`：9 帧、**每帧尺寸与 origin 都不同**（150×79 ~ 219×199）、
##     delay = 第 0 帧 12000ms、其余 200ms ⇒ 一圈 13600ms。
##     ⚠ 因此**不许用 `AnimatedTexture`**（它要求各帧同尺寸），只能逐帧换 `Sprite2D.texture`。
##   · 四颗球 = `ButtonsWindow.as:147-154`：`_btnPanel` 在 (`UIConfig.BORDER_GAP`=5,5)，
##     四枚 `ProgramButton` 相对它 (-90,-65)/(-70,-30)/(30,-30)/(50,-65)
##     ⇒ 窗口局部 **(-85,-60) 双修 / (-65,-25) 心法 / (35,-25) 挂机 / (55,-60) 修行**。
##   · 命中框 37×37（`btn_width_two`=37）而皮按**天然 43×37** 画：`ProgramButton.updateDisplayList()`
##     没有 `upSkin.width = _width` 那一行 ⇒ 场景里钮矩形取 43×37。
##   · 跟随 = `HealHandler.as:188-201`：打坐期间玩家坐标一变就 `showButtonsWindow(x, y+20, true)`。
##   · 提示只有 0/2/3 三枚（`setToolTip()` 的 `case 1:` 是空的）⇒ **心法那颗必须没有提示**。
##   · 文案与提示逐字来自语言表 message 包（3346 条，`原版数据.语言()` 本机现查）：
##     双修 / 心法 / 挂机 / 修行 + 三条 `*_BTN_TIP`。
##   · 三态一律**换 `texture_normal`**，`texture_hover/pressed` 留空（原版松手回 STATE_UP）。
##
## ⚠ 本门会进图 ⇒ 会话层可能落 `user://玩家数据.json`：**动手前整份按字节快照、收尾还原并断言**
##   （隔壁「离线门不许写存档」那条老账：不还原会让邻居门次日假红）。
##
## 跑：Godot --headless --path . --script res://测试/打坐光环与四钮回归测试.gd

const 出 := "res://测试/截图/打坐/门.txt"
const 地图场景 := "res://场景/生成/地图_101010000_烘焙.tscn"
const 面板场景 := "res://场景/界面/技能面板.tscn"
const 存档 := "user://玩家数据.json"
const 光环数据 := "res://数据/界面/打坐光环.json"

## [节点名, 期望 x, 期望 y, 文字, 提示（"" = 原版不挂）]
const 球表 := [
	["双修钮", -85.0, -60.0, "双修", "进入双人同时修炼状态，加快经验与查克拉精华获得速度"],
	["心法钮", -65.0, -25.0, "心法", ""],
	["挂机钮", 35.0, -25.0, "挂机", "进入线上自动挂机战斗状态，可获得大量打怪经验"],
	["修行钮", 55.0, -60.0, "修行", "领取你的修行收益：包括修行经验与修行查克拉精华"],
]
## 光环帧表里逐帧的 (宽, 高, originX, originY) —— 与 `落打坐素材.py` 从元件时间轴量出来的一致
## 环近边（图里最后一个不透明像素）该钉在注册点下方第几行 = **第 0 帧自己的值**。
## 每行 = [宽, 高, 原点x, 原点y, 环底距]。⚠ 第 5 列（最后一个不透明像素行离注册点多远）
##   **不参与摆位**，只是留着的量数 —— 2026-10-13 就是拿它当"环的下沿"去钉才把盘顶起来的。
const 环近边基准 := 22.0
## ä¸èæ¬éååå¸¸éï¼æ´ä½éç¹æ¬é«ï¼éåçå½åå¾å° 28-5=23ï¼
const _T := 0.0
const 帧尺寸 := [[150, 79, 75, 39, 22], [201, 146, 110, 106, 22], [182, 152, 84, 112, 24],
		[212, 186, 103, 142, 26], [214, 199, 110, 150, 32], [219, 199, 110, 150, 29],
		[213, 195, 110, 150, 25], [211, 193, 102, 150, 24],]
## ⚠ 第 8 帧（156×190、原点 79,150）已按用户 2026-10-13 令从帧表删掉不播 ⇒ 表里只留 0~7。
const 球主 := "res://素材/界面/打坐四钮/球钮.png"
const 球悬 := "res://素材/界面/打坐四钮/球钮_悬停.png"
const 球按 := "res://素材/界面/打坐四钮/球钮_按下.png"
var 条 := 0
var 红 := 0
var 存前: PackedByteArray
var 存前在 := false
var 日志 := PackedStringArray()


## 把节点上所有"存档级"属性（`PROPERTY_USAGE_STORAGE` = 脚本变量 + 导出量）整套快照 / 回灌。
## A/B 两拍对照类判据必须有这个：只复位 position/velocity 会漏掉冷却计时、落脚点号这些
## 会在两拍之间留下差的东西，量出来的"差"就不是被测那一条量了。
func _存状态(节: Node) -> Dictionary:
	var 表 := {}
	for p in 节.get_property_list():
		var 名 := String(p.name)
		if int(p.usage) & PROPERTY_USAGE_STORAGE and 名 != "script":
			表[名] = 节.get(名)
	## ⚠ `get_property_list()` 只给**引擎侧属性**，脚本自己 `var` 出来的那一群
	## （`_双修毫秒` / `_浮动偏移` / `_浮基准y` / `current_fh_id` / 各种冷却计时器）**一条都不在里面**
	## —— 10-17 实测 `快照.has("_双修毫秒")` 就是 false。少了这一族 ⇒ 第二拍带着第一拍末尾的
	## 计时器与落脚点号起步，两拍轨迹自己分叉，红行看着像"浮动有副作用"（其实量具漏了复位）。
	## `Script.get_script_property_list()` 才是脚本成员那一份，两个并起来才是"完整状态"。
	var 脚: Script = 节.get_script() as Script
	if 脚 != null:
		for p in 脚.get_script_property_list():
			var 名2 := String(p.name)
			if not 表.has(名2):
				表[名2] = 节.get(名2)
	return 表


func _回状态(节: Node, 表: Dictionary) -> void:
	for 名 in 表:
		节.set(String(名), 表[名])

func _判(过: bool, 说: String) -> void:
	条 += 1
	var 行 := ("ok  " if 过 else "!!红 ") + 说
	日志.append(行)
	print(行)
	if not 过:
		红 += 1

func _帧(n: int) -> void:
	for i in n:
		await process_frame

## 一串读数的"跨度" = 最大 − 最小。用来判"这一串到底动没动"（浮动那两条的阳性对照）。
func _跨度(表: Array) -> float:
	if 表.is_empty():
		return 0.0
	var 小 := float(表[0])
	var 大 := float(表[0])
	for 值 in 表:
		小 = minf(小, float(值))
		大 = maxf(大, float(值))
	return 大 - 小

func _快照() -> void:
	存前在 = FileAccess.file_exists(存档)
	if 存前在:
		var g := FileAccess.open(存档, FileAccess.READ)
		存前 = g.get_buffer(g.get_length())

func _还原() -> void:
	if 存前在:
		var 现 := FileAccess.open(存档, FileAccess.READ)
		var 现字 := 现.get_buffer(现.get_length())
		if 现字 != 存前:
			var h := FileAccess.open(存档, FileAccess.WRITE)
			h.store_buffer(存前)
			现 = FileAccess.open(存档, FileAccess.READ)
			现字 = 现.get_buffer(现.get_length())
		_判(现字 == 存前, "存档按字节还原（本门点了打坐 ⇒ 会话层可能落盘）")
	else:
		if FileAccess.file_exists(存档):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(存档))
		_判(not FileAccess.file_exists(存档), "动手前没有存档 ⇒ 收尾把本门造的那份删掉")

func _initialize() -> void:
	root.size = Vector2i(960, 560)
	var 景: Node = (load(地图场景) as PackedScene).instantiate()
	root.add_child(景)
	current_scene = 景
	await _帧(30)
	## 存档基线要在**单例启动之后**取：跨天首次启动时 `游戏会话._reset_daily_quests_if_needed()`
	## 会按日重置并落一次盘（产品行为，不是本门写的）。基线取在启动前 ⇒ 每天第一次跑都假红。
	_快照()

	var 们 := get_nodes_in_group("player")
	_判(们.size() > 0, "拿得到玩家（组里 %d 个）" % 们.size())
	if 们.size() == 0:
		_收尾(); return
	var 玩: Node2D = 们[0] as Node2D
	玩.set("on_ground", true)

	# ── ① 身上光环 ──────────────────────────────────────────────────────────
	_判(玩.call("toggle_practise") == true, "toggle_practise 返回进入打坐")
	await _帧(3)
	var 环 := 玩.get_node_or_null("打坐光环") as Node2D
	_判(环 != null, "打坐之后角色身上挂出了「打坐光环」子件")
	if 环 == null:
		_收尾(); return
	var 状: Dictionary = 环.call("状态")
	_判(int(状.get("帧数", 0)) == 8,
			"帧表读到 8 帧（用户 2026-10-13 令：最后一帧 `Effect_healNew_8` 不播，他说只有那一帧的八卦阵位置不对）—— 实得 %s" % 状.get("帧数"))
	_判(int(状.get("当前帧", -1)) == 0, "起步停在第 0 帧（原版那一帧停 12 秒）—— 实得 %s" % 状.get("当前帧"))
	_判(状.get("画布位置") == Vector2(-75, -39),
			"第 0 帧按**它自己的** origin 往回挪：应 = (-75,-39) —— 实得 %s" % 状.get("画布位置"))
	_判(bool(状.get("已上图", false)), "第 0 帧贴图真的挂上了（不是白块）")
	var 世界 := 环.get_global_position()
	await _帧(20)
	_判(环.get_global_position() == 世界, "人不动时光环在屏幕上一动不动（它是角色子件，不各自漂）")
	# ★ 脚本里有一条"这张场景被 F6 单独跑时把整圈挪到屏幕正中"的取景偏移（2026-10-13 用户要
	#   F6 能直接看效果）。它**只许在单独跑时生效** —— 挂在角色身上还带着那个偏移，游戏里那圈
	#   就会飘到角色右下方几百像素外（门全绿也看不出来，因为上面那条只判"动不动"）。
	_判(环.get_global_position() == 玩.get_global_position(),
			"挂在角色身上时光环根仍在角色原点（F6 那套取景偏移不许漏进游戏）—— 环 %s 角色 %s" % [
				环.get_global_position(), 玩.get_global_position()])
	# 九帧现在是**场景里的九个 Sprite2D 子节点**（用户 2026-10-13 要"编辑器里看得见才好手调"）。
	# 门逐帧读那九个子节点：贴图尺寸 = 元件时间轴量出来的、position = AS3 字面公式，
	# 并且钉"运行期只亮当前那一帧"（编辑器里那个 `全显` 勾选不许漏到游戏里）。
	var 画 := 环.call("_帧节点", 0) as Sprite2D
	_判(画 != null, "光环里面有 `第0帧` 子节点（不是运行时 new 出来的隐形节点）")
	if 画 != null:
		for i in 帧尺寸.size():
			环.call("_落帧", i)
			var 点 := 环.call("_帧节点", i) as Sprite2D
			_判(点 != null, "第 %d 帧的子节点在场景里（被手改坏了就重跑 开发工具/生成打坐九帧场景.py）" % i)
			if 点 == null:
				continue
			var 尺 := 点.texture.get_size()
			var 期: Array = 帧尺寸[i]
			_判(int(尺.x) == int(期[0]) and int(尺.y) == int(期[1]),
					"第 %d 帧贴图 %sx%s（元件时间轴量出来的）—— 实得 %sx%s" % [i, 期[0], 期[1], 尺.x, 尺.y])
			# ★★ 2026-10-13 定案：摆位**只认注册点**，与 AS3 `CharacterItem.setOrigin():53-60`
			#   逐字相同（`bmp.x = -origin.x; bmp.y = -origin.y`），水平竖直都不加任何补偿。
			#   两次教训都记在 `脚本/角色/打坐光环.gd` 文件头与 `真值/窗口/打坐.md` §⑮：
			#   拿 `环底距` 或 `阵底` 当"盘的下沿"去钉，量的其实是盘底下那团**半透明辉光**
			#   ⇒ 补偿本身把盘顶走 7~10 像素，越修越飘。定案靠的是两条不依赖地标的证据：
			#   ① GameData `healNew` 每帧只有 `origin`+`delay`；② 注册点对齐 + 放大肉眼对照图。
			_判(点.position == Vector2(-float(期[2]), -float(期[3])),
					"第 %d 帧 position 逐像素等于 Flash 的字面公式 setOrigin(-origin.x,-origin.y)：应 = (-%s,-%s) —— 实得 %s" % [
						i, 期[2], 期[3], 点.position])
		# 运行期只许亮当前这一帧：九张同时亮 = 编辑器里对图用的 `全显` 漏到了游戏里
		环.call("_落帧", 3)
		var 亮列: Array = []
		for i in 帧尺寸.size():
			var 点 := 环.call("_帧节点", i) as Sprite2D
			亮列.append(点.visible if 点 != null else false)
		_判(亮列 == [false, false, false, true, false, false, false, false],
				"停在第 3 帧时只有第 3 帧可见（其余七帧藏着）—— 实得 %s" % [亮列])
		# ★ 上面那条只遍历**帧表管得到的**那几帧 ⇒ 万一场景里还挂着一个帧表之外的贴图节点
		#   （帧表删了尾帧但场景没删、或反过来），它**永远不会被 `_刷可见()` 关掉** ⇒ 一直亮着
		#   叠在旁边，看着就是"盘在飘 / 有重影"，而上面那条照样绿。用户 2026-10-13 正是问的这条：
		#   "播放下一帧会隐藏前一帧吗" ⇒ 把两边的数量钉死（实测游戏内逐拍普查：1500 拍全部只亮 1 帧）。
		var 子贴图 := 0
		for c in 环.get_children():
			if c is Sprite2D:
				子贴图 += 1
		_判(子贴图 == int(状.get("帧数", -1)),
				"场景里的贴图子节点数 == 帧表帧数（%d vs %s）—— 多出来的那个没人关，会常驻重影" % [
					子贴图, 状.get("帧数")])
		# 再来一条正面证据，钉"中间不许藏第三项"：第 0 帧与第 4 帧（`环底距` 差最多、
		# 上一版被顶得最狠的那一帧）的摆位差必须**恰好等于两者注册点之差**。
		环.call("_落帧", 0)
		var 位0: Vector2 = 画.position
		环.call("_落帧", 4)
		var 位4: Vector2 = (环.call("_帧节点", 4) as Sprite2D).position
		_判(位4 - 位0 == Vector2(-float(帧尺寸[4][2] - 帧尺寸[0][2]), -float(帧尺寸[4][3] - 帧尺寸[0][3])),
				"第 0/4 帧摆位差 == 两者注册点之差（中间不许有补偿项）—— 实得 %s" % [位4 - 位0])
		环.call("_落帧", 0)
	# 逼它跨过第 0 帧那 12 秒
	环.set("_剩毫秒", 1.0)
	await _帧(3)
	var 状2: Dictionary = 环.call("状态")
	_判(int(状2.get("当前帧", 0)) == 1, "停够就换到第 1 帧 —— 实得 %s" % 状2.get("当前帧"))
	_判(状2.get("画布位置") == Vector2(-110, -106),
			"第 1 帧用的是**第 1 帧自己的** origin (110,106) ⇒ position 应 = (-110,-106) —— 实得 %s" % 状2.get("画布位置"))
	_判(String(状2.get("贴图名", "")) == "打坐光环_1.png", "换帧同时换了贴图 —— 实得 %s" % 状2.get("贴图名"))
	_判(FileAccess.file_exists(光环数据), "帧表数据文件在（%s）" % 光环数据)
	# ── 层序：名字必须压在光环之上（原版 `Character.as:1626`/`:1414` 两张 adjustLayer 表
	#    都把 healQueueAnimation 排在 _namePane 之前）。光环是坐下时才 add_child 的 ⇒
	#    不显式 move_child 就会排到 spawn 时建好的 Nameplate 后面、把名字糊掉。
	var 牌 := 玩.get_node_or_null("Nameplate")
	if 牌 != null:
		var 子 := 玩.get_children()
		_判(子.find(环) < 子.find(牌),
				"光环排在名字条**前面**（名字不被光环盖住）—— 实得 光环 %d / 名字 %d" % [
					子.find(环), 子.find(牌)])
		# ⚠ 身体精灵的**节点名不是 `player_sprite`**（那是 玩家.gd 里的变量名，真身叫
		#   `original_sprite`）⇒ 按名字取会拿到 null、find 返回 -1，`光环 > -1` 恒真 = 假绿。
		#   一律走变量取节点，并且**取不到就当场红**，不许让 -1 混进比较。
		var 身: Node = 玩.get("player_sprite") as Node
		_判(身 != null and 身.get_parent() == 玩,
				"身体精灵取得到、且是玩家的直接子件（否则下面那条层序判据是空的）—— 实得 %s" % [身])
		if 身 != null:
			_判(子.find(环) > 子.find(身),
					"光环排在身体贴图**后面**（光环该盖住身体）—— 实得 贴图 %d / 光环 %d" % [
						子.find(身), 子.find(环)])
	else:
		_判(false, "取不到玩家的 Nameplate 子件 ⇒ 层序这两条根本没判（别当通过）")
	_判(FileAccess.file_exists(球主) and FileAccess.file_exists(球悬) and FileAccess.file_exists(球按),
			"球皮三档都在盘上（少一张派生皮 ⇒ 那颗静默没有悬停/按下，门不红就没人知道）")
	_皮检(球主, 球悬, 30, "悬停 = clamp(常态 rgb +30)")
	_皮检(球主, 球按, -40, "按下 = clamp(常态 rgb −40)")

	# ── ② 四颗球：本体（烘进场景的死值 + 运行期一致）────────────────────────
	var 面板 := 景.get_node_or_null("技能面板") as Node
	_判(面板 != null, "地图场景里有技能面板（四颗球挂在它那一层）")
	if 面板 == null:
		玩.call("toggle_practise"); _收尾(); return
	var 四 := 面板.get_node_or_null("打坐四钮") as Control
	_判(四 != null, "技能面板里有「打坐四钮」这一族")
	if 四 == null:
		玩.call("toggle_practise"); _收尾(); return
	var 文 := FileAccess.open(面板场景, FileAccess.READ)
	var 场 := 文.get_as_text()
	_判(场.contains("[node name=\"打坐四钮\" type=\"Control\" parent=\".\"]\nvisible = false"),
			"「打坐四钮」的 `visible = false` 是**烘进场景**的（编辑器里看到的=运行期的样子）")

	_判(四.visible, "打坐期间四颗球是出来的")
	var 钉 := root.get_viewport().get_canvas_transform() * (玩 as Node2D).global_position
	钉.y += 20.0
	_判(四.position == 钉,
			"面板钉在「角色屏幕位 +(0,20)」—— 期望 %s 实得 %s" % [钉, 四.position])
	# 跟随测的是**屏幕位**。这里把角色往右搬 900（靠近地图右边界 ⇒ 相机在那里被钳住），
	# 再用引擎自己的 canvas_transform 现算一遍屏幕位当参照 —— 写死常数 / 拿世界坐标当屏幕坐标
	# 都会在这一条上红。
	_判(not (四.position == (玩 as Node2D).global_position),
			"四颗球钉的是**屏幕位**不是世界位（世界位 %s ≠ 面板位 %s）" % [(玩 as Node2D).global_position, 四.position])
	_判(四.position.x >= 0.0 and 四.position.x < 960.0 and 四.position.y >= 0.0 and 四.position.y < 560.0,
			"面板位落在 960x560 这一屏之内（%s）" % 四.position)
	玩.set("on_ground", true)
	(玩 as Node2D).global_position = Vector2(2078.0, (玩 as Node2D).global_position.y)
	# ⚠ 相机是**缓动跟随**的：只等 6 帧它还在动 ⇒ 面板那一帧算的屏幕位与门这一帧现算的会差零点几像素
	#   （实测 180.3333 vs 179.6667，红一条；下次跑又可能刚好对上 = 假绿）。等 24 帧让它停稳，
	#   并只允许 1 像素以内的余差 —— 余差照报，不藏。
	await _帧(24)
	var 钉2 := root.get_viewport().get_canvas_transform() * (玩 as Node2D).global_position
	钉2.y += 20.0
	var 余 := (四.position - 钉2).length()
	_判(余 <= 1.0, "角色挪到地图右边之后，四颗球仍钉在新的屏幕位（与相机现算值余差 %.3f 像素，限 1 像素内）" % 余)
	_判((钉2 - 钉).length() <= 200.0,
			"两边屏幕位差 %s（相机跟随 ⇒ 差值本来就该小，这里只是把「钉死在某个写死值」的可能性排掉）"
			% (钉2 - 钉).length())

	# ── ②b **缺属性的桩玩家不许把刷新打断**（2026-10-22 全量门里 `那一排按钮回归测试` 每帧抛
	#     `Invalid call. Nonexistent 'bool' constructor` 229 次 ⇒ `bool(_player.get("is_practising"))`
	#     对没有该属性的桩返回 `bool(null)`，而 4.7.1 里 NIL→BOOL 没有构造器。**抛在这一行 = 整个
	#     `_刷新打坐四钮()` 中断**：真机上只要 group 里换过一枚不带该属性的对象，四颗球就静默失灵。
	#     可观察量：先让球是**出来的**，再把 `_player` 换成缺属性的桩、手动刷一帧 ⇒
	#     修好后必须走"不坐"分支把球**收起来**；打断则 `visible` 原样留着 = 这条腿红。
	var 真玩家 = 面板.get("_player")
	var 桩 := Node2D.new()
	root.add_child(桩)
	面板.set("_player", 桩)
	_判(四.visible, "量具自己：换桩前四颗球该还是出来的（上面那两条已确认在打坐）")
	面板.call("_刷新打坐四钮")
	_判(not 四.visible, "换成缺 `is_practising` 的桩玩家后，四颗球该按「没在打坐」收起（刷新不许中途抛）")
	面板.set("_player", 真玩家)
	桩.free()
	_判(面板.get("_player") == 真玩家, "量具自己：`_player` 已换回真玩家（后面的腿还要用）")

	for 行 in 球表:
		var 钮 := 四.get_node_or_null(String(行[0])) as TextureButton
		_判(钮 != null, "有 %s 这一颗" % 行[0])
		if 钮 == null:
			continue
		_判(钮.position == Vector2(float(行[1]), float(行[2])),
				"%s 摆位 = (%s,%s) —— 实得 %s" % [行[0], 行[1], 行[2], 钮.position])
		_判(钮.size == Vector2(37, 37),
				"%s 尺寸 = 37x37（= 原版命中框；球心/字心/框心三点重合）—— 实得 %s" % [行[0], 钮.size])
		_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "%s 是手型光标" % 行[0])
		_判(钮.texture_hover == null and 钮.texture_pressed == null,
				"%s 的 hover/pressed 两槽留空（三态一律换 texture_normal）" % 行[0])
		_判(钮.self_modulate == Color.WHITE and 钮.modulate == Color.WHITE,
				"%s 没有自造染色（self_modulate/modulate 恒白）" % 行[0])
		_判(String(钮.tooltip_text) == String(行[4]),
				"%s 的提示逐字对原版%s" % [行[0], "（原版这颗不挂提示）" if String(行[4]) == "" else ""] +
				" —— 实得「%s」" % 钮.tooltip_text)
		var 字 := 钮.get_node_or_null("文字") as Label
		_判(字 != null and 字.text == String(行[3]), "%s 里写着「%s」—— 实得「%s」" % [行[0], 行[3], 字.text if 字 != null else "<无>"])
		if 字 != null:
			_判(字.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
					and 字.vertical_alignment == VERTICAL_ALIGNMENT_CENTER
					and 字.offset_right == 37.0 and 字.offset_bottom == 37.0,
					"%s 的字在 37x37 那格里居中（tf.x=(37-tw)/2、tf.y=(37-th)/2）" % 行[0])
			_判(字.get_theme_color("font_color") == Color(0.9882353, 0.95686275, 0.6117647),
					"%s 的字色 = 原版 `_textColors.up` #FCF49C —— 实得 %s" % [行[0], 字.get_theme_color("font_color")])

	# 三颗钮的 pressed 各只连一条（#200 那类重复 connect 的根因是"两个地方都连"）
	for 行 in 球表:
		var 钮 := 四.get_node_or_null(String(行[0])) as TextureButton
		if 钮 != null:
			_判(钮.pressed.get_connections().size() == 1,
					"%s 的 pressed 只连 1 条（实得 %d）" % [行[0], 钮.pressed.get_connections().size()])

	# ── ④ 双修那 8 像素正弦（#260，原版 `CharacterHandler.tickHealDouble:725-759`）─────
	## 量法 = **同一具身体用同样的 dt 跑两遍物理，只改 `partner_id` 这一格，逐帧相减**。
	## 为什么不直接判绝对 y（10-17 第一版就是这么错的）：这个离线量具里人会顺着物理往下掉
	## 一百多像素（没有真服务端托着落脚点），拿绝对值判就是把"世界的移动"算到浮动头上。
	## 相减之后剩下的就只有浮动那一条量 —— 参照值仍是 AS3 那三行（起浮 10000 毫秒、
	## `floor(基准 − 8*sin((t−10000)/500))`、`10000 + π·500·3` 归零 ⇒ 节奏"浮 4.7 秒 → 停 10 秒"）。
	## 顺序本身也是判据：浮动排在层号 / 落脚点吸附 / 发对面的位置帧**之后**，所以两拍的 `z_index` 必须逐帧相等。
	var 后 = root.get_node_or_null("BackendConnection")
	_判(后 != null, "拿得到后端（这一支读的是权威 `authoritative_heal.partner_id`）")
	## 上面 ② 那一节人是**还坐着**的 ⇒ 这里不能再 toggle（一 toggle 就变成停坐，浮动分支根本进不去）。
	玩.call("set_practising", true)
	await _帧(4)
	## 两拍必须从**同一格完整状态**起步：以前只复位 position/velocity/on_ground，
	## 结果 A 拍跑完留下的 `current_fh_id`、几个冷却计时器都带进 B 拍 ⇒ 轨迹自己就分叉了
	## （10-17 实测：层号差 12 帧、"归零后静止"也红，看着像浮动有副作用，其实是量具漏了复位）。
	var 玩快照 := _存状态(玩)
	## ⚠ 层号那条红查到这里才见底：`地表.角色z(脚点id, 兜底y)`（`脚本/地图/地表.gd:223-230`）在
	## **角色没有落脚点号**（下落途中 `current_fh_id` 就是空串）时，走的是它自己那两个缓存
	## `_上次层号` / `_上次脚点y`。A 拍跑 1502 帧把缓存改脏，只回滚角色本体的话 B 拍从另一份缓存起步
	## ⇒ 层号"抖"十几帧（10-17 实测：同一帧 z=313 与 z=341，而两拍的 fh 都是空）。
	## ⇒ 差分测量要快照的是**被读方持有的状态**，不是"我以为被测对象的状态"。
	var 面: Node = 玩.get("footholds") as Node
	_判(面 != null, "拿得到落脚点表节点（层号那条判据要连它一起回滚，理由见上面那段）")
	var 面快照 := _存状态(面) if 面 != null else {}
	_判(玩快照.has("_双修毫秒") and 玩快照.has("_浮动偏移") and 玩快照.has("_浮基准y") and 玩快照.has("current_fh_id"),
			"快照带上了脚本自己声明的那几个计时器（少了这一族，第二拍带着第一拍末尾的相位与落脚点号起步 ⇒ 头 10 秒那条必然假红，实得键齐不齐：%s/%s/%s/%s）" % [
				str(玩快照.has("_双修毫秒")), str(玩快照.has("_浮动偏移")),
				str(玩快照.has("_浮基准y")), str(玩快照.has("current_fh_id"))])
	## ⚠ `velocity` **不在 `PROPERTY_USAGE_STORAGE` 里**（CharacterBody2D 的运行时量），
	## 快照带不走它 ⇒ 不回灌的话第二拍一开始就带着第一拍末尾的下落速度，头几帧就分叉。
	var 起速: Vector2 = 玩.velocity
	var 环相对 := 环.get_global_position() - (玩 as Node2D).get_global_position()
	var 帧数 := 1500
	var 对y: Array = []
	var 对z: Array = []
	var 对环: Array = []
	## `z_index = footholds.角色z(current_fh_id, position.y) + 1`（`玩家.gd` 那一行；
	## 10-17 起 `+1` 归本地 = "重叠时自己压住别人"）是这两个输入的函数，
	## 层号却抖而 y 完全对得上 ⇒ 差的只能是落脚点号 ⇒ 两拍都把 `current_fh_id` 记下来（红行带数字）。
	var 对fh: Array = []
	var 对动作: Array = []
	var 对贴图: Array = []
	## 身体精灵一律走变量取（节点真身叫 `original_sprite`，按名字取会拿到 null）。
	var 身体: Node = 玩.get("player_sprite") as Node
	_判(身体 != null, "姿势这一族要读身体精灵的 `action`，取不到精灵 = 那两条判据是空的")
	var 一状: Dictionary = 后.get("authoritative_heal") as Dictionary
	一状["partner_id"] = 0
	后.set("authoritative_heal", 一状)
	var 帧 := 0
	while 帧 < 帧数 + 2:
		玩.call("_physics_process", 1.0 / 60.0)
		对y.append(float(玩.position.y))
		对z.append(int(玩.z_index))
		对fh.append(String(玩.current_fh_id))
		对动作.append(String(身体.get("action")) if 身体 != null else "")
		对贴图.append(String(身体.get("sprite").get("texture").resource_path) if 身体 != null else "")
		对环.append(环.get_global_position() - (玩 as Node2D).get_global_position())
		帧 += 1
	## 复位 ⇒ 第二拍与第一拍从**同一格状态**起步（不然差值里混的是初始差，不是浮动）
	_回状态(玩, 玩快照)
	玩.velocity = 起速
	if 面 != null:
		_回状态(面, 面快照)		# 层号那两个兜底缓存也一起回滚（见上面那段）
	var 二状: Dictionary = 后.get("authoritative_heal") as Dictionary
	二状["partner_id"] = 2002
	后.set("authoritative_heal", 二状)
	_判(bool(玩.call("_双修在浮")), "坐着 + partner_id 非 0 ⇒ 该浮（原版那支 `param1 == API.player` 只让**本地这具**浮）")
	var 浮y: Array = []
	var 浮z: Array = []
	var 浮环: Array = []
	var 浮fh: Array = []
	var 浮动作: Array = []
	var 浮贴图: Array = []
	var 浮锚: Array = []
	帧 = 0
	while 帧 < 帧数:
		玩.call("_physics_process", 1.0 / 60.0)
		浮y.append(float(玩.position.y))
		浮z.append(int(玩.z_index))
		浮fh.append(String(玩.current_fh_id))
		浮动作.append(String(身体.get("action")) if 身体 != null else "")
		浮贴图.append(String(身体.get("sprite").get("texture").resource_path) if 身体 != null else "")
		浮锚.append(float(((玩 as Object).call("相机锚点") as Vector2).y))
		浮环.append(环.get_global_position() - (玩 as Node2D).get_global_position())
		帧 += 1
	## ── 姿势（用户 2026-10-17 报的"双修姿势不对"）──────────────────────────────
	## 原版：单修 `Character.as:2735` 设 SIT0(7)、双修 `HealHandler.as:415` 设 **SIT1(8)**。
	## 两帧美术完全不同 —— `sit0` 正面打坐、`sit1` 侧身对坐（身前那张小桌烘在帧里）。
	## ⚠ 头 120 帧不采：两拍起步那一刻角色还**不在地上**（快照回的是离地状态），
	## 那一档走的是 `not on_ground → play("jump")` 那一支，跟坐姿无关
	## （10-17 实测：连贴图采样也带着那几帧的 `jump_0_body`，把"整段都是 sit0"判成红）。
	var 对动作集 := {}
	var 浮动作集 := {}
	var 对图集 := {}
	var 浮图集 := {}
	帧 = 120
	while 帧 < 帧数:
		对动作集[String(对动作[帧])] = true
		浮动作集[String(浮动作[帧])] = true
		对图集[String(对贴图[帧]).get_file()] = true
		浮图集[String(浮贴图[帧]).get_file()] = true
		帧 += 1
	_判(对动作集.size() == 1 and 对动作集.has("sit0"),
			"对照拍（partner_id=0，单修）落定之后整段播的都是 **sit0** —— 实得 %s" % str(对动作集.keys()))
	_判(浮动作集.size() == 1 and 浮动作集.has("sit1"),
			"浮动拍（partner_id≠0，双修）落定之后整段播的都是 **sit1** —— 实得 %s。" % str(浮动作集.keys())
			+ "还是 sit0 就是用户看到的「姿势不对」（坐前三处写死 sit0）")
	## ★ **屏幕上那张图**也要跟着换，而且必须**在每一拍里当场采**：
	## `原始动画精灵._apply_frame()` 在 `_get_texture()` 取不到图时直接 `return`、**保留上一张**
	## ⇒ 只查 `action` 名测不出"图根本没换"（记忆里"逐帧特效只查节点属性 = 假绿"那一族）。
	## ⚠ 10-17 第一版就是在两拍都跑完之后才读一次 ⇒ 两个变量读到的是同一张（浮动拍末尾那张 sit1），
	## 看着像"sit0 的图丢了"，其实是量具自己采晚了。
	_判(对图集.size() == 1 and String(对图集.keys()[0]).contains("_sit0_"),
			"★★ 对照拍**屏幕上那张图**就是 sit0 的贴图（实得 %s）" % str(对图集.keys()))
	_判(浮图集.size() == 1 and String(浮图集.keys()[0]).contains("_sit1_"),
			"★★ 浮动拍**屏幕上那张图**就是 sit1 的贴图（实得 %s）" % str(浮图集.keys()))
	_判(对图集 != 浮图集, "两拍挂的真是两张不同的图（不是只把动作名改了、画面上没换）")
	## ── 镜头不许跟着浮动（用户 2026-10-17 第三条；根因见 `玩家.相机锚点()` 那段注释）──
	## ⚠ 这条**不能**判"锚点整段一动不动"：这一拍里角色本来就在往下落（两拍共有的轨迹，
	## 差分法把它抵掉了，所以浮动那几条一直是绿的 —— 实测锚点跨度 94 像素）。
	## 判的是两件相对的事，都不依赖父节点变换：
	## ① 锚点与"没有浮动的那一拍"逐帧同差 ⇒ 锚点跟的就是真落脚点；
	## ② 位置减锚点这一列的跨度 ≈ 16 ⇒ 摘掉的确实是那 ±8，不是顺手把真运动也摘了。
	## ⚠ 是 **±8（跨度 ≈16）** 不是 8：`floor(基准 − 8·sin((t−10000)/500))` 在一整个 1.5 周期里
	## sin 有正有负 ⇒ 目标在基准**上下各 8 像素**来回（下面那条"上下各 8 像素"判的就是这两端）。
	var 锚基差: Array = []
	var 摘掉的量: Array = []
	帧 = 0
	while 帧 < 帧数:
		锚基差.append(float(浮锚[帧]) - float(对y[帧]))
		摘掉的量.append(float(浮y[帧]) - float(浮锚[帧]))
		帧 += 1
	var 锚差跨 := _跨度(锚基差)
	var 摘跨 := _跨度(摘掉的量)
	_判(摘跨 >= 14.0 and 摘跨 <= 17.0,
			"★ 阳性对照：`position.y − 相机锚点().y` 这一列的跨度 %.2f 像素（该 ≈16 = 上下各 8）—— " % 摘跨
			+ "浮动真的被锚点摘掉了，不是这一拍根本没浮")
	_判(锚差跨 <= 0.01,
			"★★ `相机锚点()` 与对照拍（不浮动那一拍）逐帧同差（跨度 %.2f）" % 锚差跨
			+ "⇒ 相机跟的是真落脚点，镜头不会跟着那 ±8 上下动（用户 10-17 那一条）")
	## 逐帧差值 = 纯浮动量（地板时刻 600 帧 = 10 秒；一整个 1.5 周期 ≈ 283 帧）
	var 地板帧 := int(10000.0 / 1000.0 * 60.0)
	var 最低 := 0.0
	var 最高 := 0.0
	var 越界 := 0
	var 层抖 := 0
	var 环脱 := 0
	var 归零后静止 := true
	## 两拍一旦从不同状态起步，红的样子就是"头 10 秒也在动 + 层号抖几帧"——光看这两个数分不出
	## 是浮动有副作用还是**量具漏了复位**。所以把头段第一帧差值与层号第一次不同的那一帧
	## 连同两拍当时的状态一起记下来，红行里直接带出来（10-17 就是靠这两个数定位到 `velocity` 没进快照）。
	var 头一差帧 := -1
	var 头一差话 := ""
	var 层一差帧 := -1
	var 层一差话 := ""
	var 尾段起 := 地板帧 + int((float(PI) * 500.0 * 3.0) / 1000.0 * 60.0) + 2
	帧 = 0
	while 帧 < 帧数:
		var 差: float = float(浮y[帧]) - float(对y[帧])
		if 帧 < 地板帧:
			if 差 != 0.0 and 头一差帧 < 0:
				头一差帧 = 帧
				头一差话 = "第 %d 帧 对照 %.3f 浮拍 %.3f 差 %.3f｜浮拍当时 毫秒=%s 偏移=%s 基准=%s 速度=%s 落脚=%s" % [
						帧, float(对y[帧]), float(浮y[帧]), 差, str(玩.get("_双修毫秒")), str(玩.get("_浮动偏移")),
						str(玩.get("_浮基准y")), str(玩.velocity), str(玩.get("current_fh_id"))]
		else:
			最低 = minf(最低, 差)
			最高 = maxf(最高, 差)
			if 差 < -9.0 or 差 > 9.0:
				越界 += 1
		if 浮z[帧] != 对z[帧] and 层一差帧 < 0:
			层一差帧 = 帧
			层一差话 = "第 %d 帧 对照 z=%s fh=%s 浮拍 z=%s fh=%s" % [帧, str(对z[帧]), str(对fh[帧]),
					str(浮z[帧]), str(浮fh[帧])]
		if 浮z[帧] != 对z[帧]:
			层抖 += 1
		if 浮环[帧] != 对环[帧]:
			环脱 += 1
		## 只看"归零之后、下一次起浮之前"那 300 帧（1500 帧的窗子里第二段浮动已经在
		## 第 1484 帧又起来了，拿它当"该静止"判就是量具自己算错了窗口，不是代码错）。
		if 帧 >= 尾段起 and 帧 < 尾段起 + 300 and 差 != 0.0:
			归零后静止 = false
		帧 += 1
	_判(头一差帧 < 0, "坐下头 10 秒（前 %d 帧）一动不动 —— 原版要 `healSinTime > 10000` 才碰 y（%s）" % [
			地板帧, 头一差话 if 头一差帧 < 0 else "第一处差：%s" % 头一差话])
	_判(最低 <= -7.0 and 最低 >= -9.0 and 最高 >= 7.0 and 最高 <= 9.0,
			"浮起来那一段**上下各 8 像素**（实得 最低 %.1f / 最高 %.1f，基准 8.0；`floor` 落在小数基准上会有 1 像素零头）" % [最低, 最高])
	_判(越界 == 0, "1500 帧里没有任何一帧浮出 ±9 之外（越界 %d 帧）" % 越界)
	_判(层抖 == 0, "浮动期间 `z_index` 与对照拍**逐帧相同**（不同 %d 帧）—— 收了再浮才排得对，否则就是层序抖动（%s）" % [
			层抖, 层一差话 if 层一差帧 < 0 else "第一处差：%s" % 层一差话])
	_判(环脱 == 0, "光环相对角色的位置一格没变 ⇒ 是**整具身体**在浮，不是只挪了贴图（变 %d 帧）" % 环脱)
	_判(归零后静止, "走完 1.5 个周期归零以后回到对照拍的位置（判第 %d~%d 帧这 300 帧）" % [尾段起, 尾段起 + 299])
	## 双修解除 ⇒ 之后两帧必须与对照拍**逐帧相等**（`_推进双修浮动` 里 `not _双修在浮()` 那一条
	## 分支收的就不该有残余）。⚠ 上一版这里判的是"离对照末帧不超过 9 像素"—— 而浮动本身就只有
	## ±8，**永远过**，等于没判（记忆里第十五种"0 比 0 恒真"）。改成接着两帧做精确比对。
	二状 = 后.get("authoritative_heal") as Dictionary
	二状["partner_id"] = 0
	后.set("authoritative_heal", 二状)
	var 停差: Array = []
	var 次 := 0
	while 次 < 2:
		玩.call("_physics_process", 1.0 / 60.0)
		停差.append(float(玩.position.y) - float(对y[帧数 + 次]))
		次 += 1
	_判(停差.size() == 2 and float(停差[0]) == 0.0 and float(停差[1]) == 0.0,
			"partner_id 归 0 之后**接着两帧与对照拍完全相等**（实得差 %s）" % str(停差))
	_判(float(玩.get("_浮动偏移")) == 0.0, "浮动量本身也归零了（实得 %s）" % str(玩.get("_浮动偏移")))
	_判(not bool(玩.call("_双修在浮")), "不双修了 ⇒ 该停浮")
	_判(环相对 == 环.get_global_position() - (玩 as Node2D).get_global_position(),
			"收回之后光环仍贴在角色原点相对位（没被浮动带跑）")
	_回状态(玩, 玩快照)
	玩.velocity = 起速
	if 面 != null:
		_回状态(面, 面快照)

	# ── ③ 停坐 ⇒ 光环摘掉 + 四颗球收起 ─────────────────────────────────────
	玩.call("toggle_practise")
	await _帧(6)
	_判(玩.get_node_or_null("打坐光环") == null, "停止打坐之后光环被摘掉")
	_判(int(玩.get("is_practising")) == 0, "停止打坐后状态回到不坐")
	_判(not 四.visible, "停止打坐之后四颗球收起来了")

	_收尾()


func _收尾() -> void:
	var 结 := "结论：判 %d 条 / 红 %d 条" % [条, 红]
	日志.append(结)
	print(结)
	_还原()
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(日志) + "\n")
	quit(0 if 红 == 0 else 1)


## 逐像素：这颗球皮**整张都是半透的**（通用控件那一族 alpha 不是 255），所以不能按"只判 a==255"来数 ——
## 那样一条都判不到。判的是**烘焙这一层的定义**：`a>0` 的每个像素 `rgb == clamp(常态 rgb + 偏移)`
## 且 alpha 一模一样（原版 `getLightFilter` 的 alpha 行是 `0,0,0,1,0` ⇒ 不动 alpha）；
## `a==0` 的整像素必须原样不动（Flash 走预乘 alpha，全透处本来不亮，改了会在线性过滤时渗出亮边）。
func _皮检(主: String, 派: String, 偏: int, 说: String) -> void:
	var a := Image.load_from_file(ProjectSettings.globalize_path(主))
	var b := Image.load_from_file(ProjectSettings.globalize_path(派))
	if a == null or b == null:
		_判(false, "%s —— 图读不回来（%s / %s）" % [说, 主, 派])
		return
	_判(a.get_size() == b.get_size(), "%s：两张同尺寸 %s / %s" % [说, a.get_size(), b.get_size()])
	var 异 := 0
	var 判数 := 0
	var 跳过 := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			var 主a := int(round(p.a * 255.0))
			var 派a := int(round(q.a * 255.0))
			if 主a == 0:
				跳过 += 1
				if 派a != 0 or absf(q.r - p.r) * 255.0 > 0.6 or absf(q.g - p.g) * 255.0 > 0.6 \
						or absf(q.b - p.b) * 255.0 > 0.6:
					异 += 1
				continue
			判数 += 1
			if 派a != 主a:
				异 += 1
				continue
			var 不符 := false
			for i in 3:
				var 期: float = clampf([p.r, p.g, p.b][i] + float(偏) / 255.0, 0.0, 1.0)
				if absf(期 - [q.r, q.g, q.b][i]) * 255.0 > 0.6:
					不符 = true
			if 不符:
				异 += 1
	_判(判数 > 0 and 异 == 0,
			"%s：判 %d 个有墨像素（另 %d 个全透处要求原样不动），不符 %d 个" % [说, 判数, 跳过, 异])
