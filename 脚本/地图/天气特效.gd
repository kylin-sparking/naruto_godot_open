extends CanvasLayer
## 天气特效层（报修 6「天气对应的地图特效没有实装」）。
##
## 原版这一整套都在 `Client.as` 里：`onWeatherChange:3790` → `applyWeatherVisual:3825`
## → `startWeatherSnowVisual:3960` / `onWeatherSnowFrame:4017`。服务端只发一条
## `1570 天气类型`（`ReceiveOpCodes.CHANGE_WEATHER`），**画什么、画多浓、哪张图能看，
## 全是客户端自己定的**。移植侧 1570 → `后端连接.weather_received` →
## `游戏会话.hud_state["weather_type"]` 早就通了（头像面板那枚状态图标一直在吃它），
## 从头到尾缺的就是这个消费者 —— 所以用户看到的是"天气变了，地图上什么都没有"。
##
## 层级：世界是 CanvasLayer 0、小地图面板 20、聊天/技能 100 ⇒ 天气取 **10**
## （在地图之上、HUD 之下）。节点由 `地图根节点._ready()` 用代码建，
## 不进 174 张烘焙场景 ⇒ 不用重烤。
##
## 已知偏离（都登记在 真值/地图/天气特效.md 的「已知偏离」表）：
##   ① 原版的动态天气件是挂在 `API.world` **世界坐标 (25,1)** 的一个 `MapObjectRender`
##      （`:3905-3920`），会跟相机一起滚出视野（那张图宽 5260，玩家走到 x>5285 雨就没了）。
##      本机钉在**视口**上：屏幕 (0,0) 画素材 (25,1) 那一块 ⇒ 与原版"相机在该图左上角时
##      看到的那一格"逐像素相同，但不再随走路消失。
##   ② 原版把天气件 push 到 `objectRenders` 末尾 ⇒ 画在物件之上、**角色之下**；
##      本机整层在角色之上（雨丝落在人身上）。
##   ③ 显存：素材按现有 `.import`（`compress/mode=0` 无损 RGBA8）整张进显存是
##      nature_18 20 帧 × 5260×1770 = **745MB**。本机改为**从磁盘读原图、只裁视口那一块**
##      再烘成 `ImageTexture`（960×560 下 20 帧 ≈ 43MB），并按 `帧缓存预算` 封顶。

const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")

## 本层所在 CanvasLayer。
const 层级 := 10
## 原版动态天气件的舞台坐标（`Client.as:3910-3911` `"x":25,"y":1`）⇒ 本机的裁切起点。
const 舞台点 := Vector2(25.0, 1.0)
## 帧间隔 100ms ⇒ 10fps。`Animation.as:47-50` 的 `delay` 恒 100；
## `FrameQueueAnimation.as:55-57` 按帧取 `_crtDelays[_frame]`，而 `:119` 是
## `ObjectAccessor.getFromObject(_loc1_,[帧,"delay"]) || 100`。天气件是
## `MapObject.fromObject` 现造的（`:3905-3915`，帧表里没有 delay）⇒ 取默认 100ms。
const 帧间隔 := 0.1
## 一叠帧（宽×高×4 字节 ×帧数）的封顶。超了就等比缩小裁切、再放大回去画。
const 帧缓存预算 := 128 * 1024 * 1024
## 原版 60fps 节拍（`Engine.as:13 STAGE_FRAME_RATE = 60` + 累加器）：雪每帧走一步。
const 节拍帧率 := 60.0
## 单帧最大步长：掉帧/切后台回来不许让雪一下跳出屏幕（原版累加器会补帧，我们不补）。
const 最大步长秒 := 1.0 / 15.0

const 装饰前缀 := "Obj_acc_shuizhiguo_nature_"
## 这三张名单是 `Client.as:3847-3849` 那三行的逐字搬运。
## ⚠ 要命的细节：范围端点只到 `××40000`/`××10000`，**子图不在名单里** ——
##   112040002、411000000 都烘了 nature_16/17/18 装饰物，原版在那些图上是把它们
##   **隐藏**（`:3876 _loc3_.visible = _loc12_`，而 `_loc12_` 为假），不是显示。
static func 在静态名单A(地图号: String) -> bool:
	var 图 := 地图号.to_int()
	return 图 == 109010000 or 图 == 109020000 or 图 == 109040000 \
		or 图 == 110010000 or 图 == 110020000 or 图 == 110040000 \
		or (图 >= 111010000 and 图 <= 111040000) \
		or (图 >= 112010000 and 图 <= 112040000)

## B：这张图**永远不放动态天气**（`:3848`，`:3881` 直接 return）。
static func 在禁动态名单B(地图号: String) -> bool:
	var 图 := 地图号.to_int()
	return 图 == 107010000 or 图 == 107020000 or 图 == 107030000 or 图 == 110030000 \
		or (图 >= 108010000 and 图 <= 108040000) \
		or (图 >= 112010000 and 图 <= 112040000)

## C：这张图**只跳过雪**（4..6），雨雪雾照放（`:3849` + `:3881` 的后半个条件）。
static func 在雪跳过名单C(地图号: String) -> bool:
	var 图 := 地图号.to_int()
	return 图 == 109010000 or 图 == 109020000 or 图 == 109040000 \
		or 图 == 110010000 or 图 == 110020000 or 图 == 110040000 \
		or (图 >= 112010000 and 图 <= 112040000)

## 类型 → 用哪张素材 + 整层透明度 + 要不要叠雪（`Client.as:3885-3900`）。
## 名单外/0/10+ 拿到空字典 ⇒ 什么都不画（对应 `:3901-3904` 的 `_loc5_ == ""`）。
static func 画面参数(类型: int) -> Dictionary:
	match 类型:
		1: return {"图号": "18", "透明度": 0.45, "雪": false}	# 小雨
		2: return {"图号": "18", "透明度": 0.7, "雪": false}	# 中雨
		3: return {"图号": "18", "透明度": 1.0, "雪": false}	# 大雨
		4: return {"图号": "16", "透明度": 0.08, "雪": true}	# 小雪
		5: return {"图号": "16", "透明度": 0.13, "雪": true}	# 中雪
		6: return {"图号": "16", "透明度": 0.18, "雪": true}	# 大雪
		7: return {"图号": "16", "透明度": 0.35, "雪": false}	# 小雾
		8: return {"图号": "16", "透明度": 0.6, "雪": false}	# 中雾
		9: return {"图号": "16", "透明度": 0.85, "雪": false}	# 大雾
	return {}

## 雪的参数（`startWeatherSnowVisual:3960-4015` + `onWeatherSnowFrame:4017-4050`）。
## 逐条出处写在键名后面，回归门按这张表钉死数值：
##   数量 38/68/104（`:3980`）
##   半径 = 0.9 + rand×半径随机量，半径随机量 2.8、类型 6 用 3.6（`:3986`）
##   实心圆 alpha = 0.58 + rand×0.36（`:3988`）
##   半径 > 2.3 才加十字：线宽 0.6、纯白、alpha 0.48，长短 ±1.35×半径（`:3991-3997`）
##   speedX = -0.22 + rand×0.44（`:4004`）
##   speedY = 0.65 + rand×纵速随机量，纵速随机量 0.9/1.35/1.9（`:4005`）
##   sway = 0.12 + rand×摆幅随机量，摆幅随机量 0.42、类型 6 用 0.62（`:4006`）
##   phase 初值 rand×TAU、phaseSpeed = 0.018 + rand×0.035（`:4007-4008`）
##   spin = -0.45 + rand×0.9（`:4009`，Flash 的 `rotation` 是**度**）
##   风 = sin(帧计数 × 0.015) × 风幅，风幅 0.35（类型 6）/0.18（`:4025`）
##   回绕：y > H+24 → y = -24 - rand×H×0.12、x = rand×W（`:4035-4039`）；
##         x < -30 → W+30；x > W+30 → -30（`:4040-4047`）
static func 雪参数(类型: int) -> Dictionary:
	if 类型 < 4 or 类型 > 6:
		return {}
	var 大雪 := 类型 == 6
	return {
		"数量": 38 if 类型 == 4 else (68 if 类型 == 5 else 104),
		"半径底": 0.9, "半径随机量": 3.6 if 大雪 else 2.8,
		"实心透明度": 0.58, "实心随机量": 0.36,
		"十字阈值": 2.3, "十字长": 1.35, "线宽": 0.6, "线透明度": 0.48,
		"横速底": -0.22, "横速随机量": 0.44,
		"纵速底": 0.65, "纵速随机量": 0.9 if 类型 == 4 else (1.35 if 类型 == 5 else 1.9),
		"摆幅底": 0.12, "摆幅随机量": 0.62 if 大雪 else 0.42,
		"相速底": 0.018, "相速随机量": 0.035,
		"自旋": 0.45,
		"风频": 0.015, "风幅": 0.35 if 大雪 else 0.18,
		"下绕边距": 24.0, "上补随机比": 0.12, "侧绕边距": 30.0,
	}

## ── 木叶村天空底图随天气切换（用户 2026-10-31 口径，**原版没有这一条**）────────────
## 原版 `Client.as:3825-3904` 的天气只在天空之上叠一张动态雨/雪/雾片，底图永远不动。
## 用户要求木叶村的天空跟着天气变阴（素材 `新素材/Back_zhucheng_back_2_{小,大}阴天.png`）：
##   晴天（0 / 未知）= 原来的 `Back_zhucheng_back_2.png`
##   小雨 / 中雨 / 小雪 / 中雪 / 雾（7..9）= 小阴天
##   大雨 / 大雪（3 / 6）= 大阴天
## ⚠ 中雨、中雪用户没点名，按"轻档"走小阴天（要改就改 `天空变体`，门会跟着红）。
## ⚠ 只做木叶村（100000000）：别的图连天空层都不碰，`_应用天空背景` 一进来就 return。
const 天空变体图 := {
	"100000000": {
		"小": "res://素材/地图/木叶村/背景/Back_zhucheng_back_2_小阴天.png",
		"大": "res://素材/地图/木叶村/背景/Back_zhucheng_back_2_大阴天.png",
	},
}

## 天气类型 → 阴天档位（"" = 用原图）。用户口径的**唯一出处**：门按这张表逐类型钉死。
static func 天空变体(类型: int) -> String:
	match 类型:
		1, 2, 4, 5, 7, 8, 9:
			return "小"
		3, 6:
			return "大"
	return ""

## 变体贴图按路径缓存：新图 1472×1728 RGBA 一张约 10MB，来回切天气不重复解码。
static var _天空变体缓存 := {}

## 从磁盘读原 PNG 再烘成纹理 —— 与天气片同一条路（不走 `.import`，也就不需要重烤地图）。
static func 读天空变体(路径: String) -> Texture2D:
	if 路径 == "":
		return null
	if _天空变体缓存.has(路径):
		return _天空变体缓存[路径] as Texture2D
	var 图 := 烘帧任务.读图(路径)
	if 图 == null:
		push_warning("天气特效：天空变体读不出来 %s" % 路径)
		return null
	var 纹 := ImageTexture.create_from_image(图)
	_天空变体缓存[路径] = 纹
	return 纹

## 波之国纪念雪（`Client.as:3807` `applyWeatherVisual(this.hasWaveMemorialSnowVisual() ? 5 : param1)`，
## 判据 `:3810-3823` 查 `CharacterConfig.mapData._waveMemorialSnowMapIds[地图号]`）。
## ⚠ 本机这条**当前恒假**：`mapData` 是原版 `1283` 二进制 AMF 里的字段
##   （`CharacterConfig.as:67`），文本协议不运它 ⇒ 夹具发来的 1283 没有这一段。
##   判据照原版写成"查得到才真"，**不自己编地图号**（编了就是把客户端自造的名单当真值）。
##   注意原版只把**画面**改成类型 5，三条名单仍按真实地图号判（`:3846` 取的是 `map.data.id`）。
static func 有纪念雪(地图号: String, 配置: Dictionary) -> bool:
	var 表 = 配置.get("mapData", {})
	if not 表 is Dictionary:
		return false
	var 名单 = (表 as Dictionary).get("_waveMemorialSnowMapIds", null)
	if not 名单 is Dictionary:
		return false
	return bool((名单 as Dictionary).get(地图号, false))

var 地图号 := ""
var 类型 := -1
var 帧: Array = []
var 帧号 := 0
var 帧时 := 0.0
var 片: Sprite2D = null
var 雪: Node2D = null
## 本节点当前在用的帧表键（`图号|宽x高`）—— `_收帧` 靠它找到那份在烘的任务。
var _键 := ""
## 天空层（`BakedBackgrounds` 里 `bg_kind = "天空"` 的那几层）与**进图时**的贴图。
## 换天气只改这几层；回到晴天时把原贴图放回去 —— 原引用烘焙场景已经拿好了，不用再 load。
var _天空层: Array[Node2D] = []
var _天空原图: Array[Texture2D] = []

## 按 "图号|宽x高" 缓存裁好的帧。同时只可能有一种天气在放 ⇒ 换尺寸/换图号就整表丢掉。
## ⚠ 表里那份 Array 是**活的**：后台烘出来的帧由 `_收帧` 直接 append 进去，
##   所有拿到同一份引用的节点会看到它原地变长。
static var _帧缓存 := {}
## 还在后台烘的任务，按同一个键索引 ⇒ 换天气类型重建节点时接管同一份，不开第二叠。
static var _在途 := {}

func _ready() -> void:
	layer = 层级
	set_process(false)
	var 会话 := get_node_or_null("/root/GameSession")
	if 会话 != null:
		地图号 = str(会话.current_map_id)
		if not 会话.hud_state_changed.is_connected(_on_hud_state):
			会话.hud_state_changed.connect(_on_hud_state)
		_找天空层()
		应用(_有效类型(int((会话.hud_state as Dictionary).get("weather_type", -1))))
	get_viewport().size_changed.connect(_on_视口变化)

func _exit_tree() -> void:
	var 会话 := get_node_or_null("/root/GameSession")
	if 会话 != null and 会话.hud_state_changed.is_connected(_on_hud_state):
		会话.hud_state_changed.disconnect(_on_hud_state)

func _on_hud_state(state: Dictionary) -> void:
	应用(_有效类型(int(state.get("weather_type", -1))))

func _有效类型(类型_: int) -> int:
	var 会话 := get_node_or_null("/root/GameSession")
	if 会话 != null and 有纪念雪(地图号, 会话.get("挂机配置") as Dictionary):
		return 5
	return 类型_

func _on_视口变化() -> void:
	# 裁切是按视口尺寸烘的，尺寸一变就得重烘（原版是 stage 尺寸变了雪场跟着变）。
	if 类型 >= 1:
		应用(类型)

## 主入口：等价于原版 `applyWeatherVisual(类型)`。
func 应用(类型_: int) -> void:
	类型 = 类型_
	_清理()
	# 静态装饰物的可见性：`:3850-3880`，**在两条 return 之前**跑完 ⇒ B/C 图也照 hidden。
	_静态装饰可见性()
	# 天空底图换阴天（用户口径，原版没有）—— 也放在两条 return 之前：
	# 它与"这张图放不放动态天气片"是两件事（木叶村两条名单都不在，只是顺序上别埋雷）。
	_应用天空背景(类型)
	# `:3881-3884`：B 图什么都不放；C 图只跳过雪（4..6）。
	if 在禁动态名单B(地图号) or (在雪跳过名单C(地图号) and 类型 >= 4 and 类型 <= 6):
		set_process(false)
		return
	var 参数 := 画面参数(类型)
	if 参数.is_empty():
		set_process(false)
		return
	_起片(String(参数["图号"]), float(参数["透明度"]))
	if bool(参数["雪"]):
		_起雪(类型)
	set_process(片 != null)

## 进图时抓一把天空层：只认烘焙产物里 `metadata/bg_kind = "天空"` 的那几层
## （`开发工具/识别背景层.py` 判出来的类别，和 `地图根节点` 拉满整图用的是同一个字段）。
func _找天空层() -> void:
	_天空层.clear()
	_天空原图.clear()
	var 根 := get_parent()
	if 根 == null:
		return
	var 背 := 根.get_node_or_null("BakedBackgrounds")
	if 背 == null:
		return
	for 件 in 背.get_children():
		if not 件 is Node2D:
			continue
		if String(件.get_meta("bg_kind", "")) != "天空":
			continue
		var 层 := 件 as Node2D
		var 原 = 层.get("texture")
		_天空层.append(层)
		_天空原图.append(原 if 原 is Texture2D else null)

## 按天气类型换天空底图。表里没有这张图 / 没抓到天空层 ⇒ 什么都不做（返回原图）。
## 变体图读不出来时也退回原图 —— 宁可晴天，不要露出一块空白天。
func _应用天空背景(类型_: int) -> void:
	if not 天空变体图.has(地图号) or _天空层.is_empty():
		return
	var 变体 := 天空变体(类型_)
	var 纹: Texture2D = 读天空变体(String(天空变体图[地图号].get(变体, ""))) if 变体 != "" else null
	for i in _天空层.size():
		var 层: Node2D = _天空层[i]
		var 用: Texture2D = 纹 if 纹 != null else _天空原图[i]
		if 层.get("texture") == 用:
			continue
		层.set("texture", 用)
		层.queue_redraw()

func _清理() -> void:
	if 片 != null:
		片.queue_free()
		片 = null
	if 雪 != null:
		雪.queue_free()
		雪 = null
	帧 = []
	帧号 = 0
	帧时 = 0.0
	# 这一份帧表已经和本节点脱钩了：别再让 `_收帧` 往它身上追加（换天气类型时
	# 旧任务若还在烘，它只会在 `_帧缓存` 里等下一个接管者或换键时被弃）。
	_键 = ""

## 原版 `:3855-3877`：名字对上 `acc/shuizhiguo/nature` + 图号 16/17/18 的物件，
## 可见性一律由名单 A 决定（不是这张图的天气类型决定 —— 所以"这张图有没有雨"
## 和"这张图烘没烘那坨水上装饰"是两件事）。
func _静态装饰可见性() -> void:
	var 根 := get_parent()
	if 根 == null:
		return
	var 物件层 := 根.get_node_or_null("ObjectRoot")
	if 物件层 == null:
		return
	var 该看 := 在静态名单A(地图号)
	for 件 in 物件层.get_children():
		if not 件 is CanvasItem:
			continue
		var 名 := String(件.name)
		if not 名.begins_with(装饰前缀):
			continue
		# 烘焙重名会追加 `_<n>`（`..._nature_17_2`）⇒ 取第一段才是图号。
		var 图号 := 名.substr(装饰前缀.length()).split("_")[0]
		if 图号 == "16" or 图号 == "17" or 图号 == "18":
			(件 as CanvasItem).visible = 该看

func _起片(图号: String, 透明度: float) -> void:
	帧 = _取帧(图号)
	if 帧.is_empty():
		push_warning("天气特效：类型 %d 的素材 %s 一张都没读到" % [类型, 图号])
		return
	片 = Sprite2D.new()
	片.name = "天气片"
	片.centered = false
	片.texture = 帧[0] as Texture2D
	# 原版 `_loc3_.alpha = _loc6_`（`:3919`）—— 整层透明度，不是逐帧烘焙。
	片.modulate = Color(1, 1, 1, 透明度)
	var 视口 := get_viewport().get_visible_rect().size
	片.scale = Vector2(float(视口.x) / float(片.texture.get_width()),
			float(视口.y) / float(片.texture.get_height()))
	add_child(片)

func _起雪(类型_: int) -> void:
	var 参 := 雪参数(类型_)
	if 参.is_empty():
		return
	雪 = 雪花.new()
	雪.name = "天气雪"
	add_child(雪)
	# 节拍常量从外面传进来：GDScript 的内部类拿不到外围脚本的 const，
	# 在 雪花 里再抄一份就是两个真值源了。
	(雪 as 雪花).起手(类型_, 参, 节拍帧率, 最大步长秒)

## 从磁盘读原图、只裁视口那一块 —— 这是显存那 745MB 的解法（见文件头「已知偏离」③）。
## **首帧同步、其余后台流式**：实测 20 张 5260×1770 的 PNG 在主线程逐张解码要 1831ms
## （雾 7 张也要 ~1000ms）⇒ 全同步就是"起雾那一刻画面冻住一下"。后台只解码 + 裁，
## 纹理上传留主线程（`RenderingDevice` 不允许跨线程建纹理），每帧收几张。
func _取帧(图号: String) -> Array:
	var 视口 := get_viewport().get_visible_rect().size
	var 键 := "%s|%dx%d" % [图号, int(视口.x), int(视口.y)]
	if _帧缓存.has(键):
		# 同一叠帧在后台烘着（换天气类型/重建节点/视口没变）⇒ 直接接管那一份，不重开任务。
		_键 = 键
		return _帧缓存[键]
	var 基础名 := "%s%s" % [装饰前缀, 图号]
	var 目录 := MAP_RESOURCES.find_asset_directory(地图号, "地图物件", 基础名)
	if 目录.is_empty():
		push_warning("天气特效：找不到素材目录 %s" % 基础名)
		return []
	var 路径表 := _列帧文件(目录, 基础名)
	if 路径表.is_empty():
		push_warning("天气特效：%s 目录里没有帧文件" % 基础名)
		return []
	# 首张只能同步解：裁切框要用它的尺寸定，而且特效得立刻有东西可画。
	var 首 := 烘帧任务.读图(String(路径表[0]))
	if 首 == null:
		push_warning("天气特效：%s 首帧读不出来" % 基础名)
		return []
	var 裁 := _裁切矩形(视口, 首, 路径表.size())
	var 首纹 := _烘纹理(首, 裁)
	if 首纹 == null:
		push_warning("天气特效：%s 首帧传不上显存" % 基础名)
		return []
	# 换键 ⇒ 旧任务的产物再也没人收，叫它们早停，别让显存里同时躺着两叠。
	for 旧 in _在途.values():
		(旧 as 烘帧任务).弃()
	_在途.clear()
	_帧缓存.clear()
	var 任 := 烘帧任务.new()
	任.路径表 = 路径表.slice(1)
	任.裁 = 裁
	任.起算 = Time.get_ticks_msec()
	# 缓存里放的是**同一个 Array**：`_收帧` 往里 append，正在播的 `帧` 就原地变长。
	_帧缓存[键] = [首纹]
	_在途[键] = 任
	_键 = 键
	WorkerThreadPool.add_task(任.跑, false, "天气帧烘焙")
	return _帧缓存[键]

## 裁切起点 = 舞台点（屏幕 (0,0) 画素材 (25,1)，见文件头「已知偏离」①）。
## 预算封顶：帧数 × 宽 × 高 × 4 超了就等比缩小，画的时候再用 `_起片` 里的 scale 放大回去。
func _裁切矩形(视口: Vector2, 首: Image, 帧数: int) -> Rect2i:
	var 裁 := Rect2i(int(舞台点.x), int(舞台点.y),
			maxi(int(视口.x), 1), maxi(int(视口.y), 1))
	var 需 := float(帧数) * float(裁.size.x) * float(裁.size.y) * 4.0
	if 需 > float(帧缓存预算):
		var 缩 := sqrt(float(帧缓存预算) / 需)
		裁.size.x = maxi(int(float(裁.size.x) * 缩), 1)
		裁.size.y = maxi(int(float(裁.size.y) * 缩), 1)
	裁.size.x = clampi(裁.size.x, 1, maxi(首.get_width() - 裁.position.x, 1))
	裁.size.y = clampi(裁.size.y, 1, maxi(首.get_height() - 裁.position.y, 1))
	裁.position = Vector2i(maxi(mini(裁.position.x, 首.get_width() - 1), 0),
			maxi(mini(裁.position.y, 首.get_height() - 1), 0))
	return 裁

static func _烘纹理(图: Image, 裁: Rect2i) -> Texture2D:
	return ImageTexture.create_from_image(烘帧任务.裁好(图, 裁))

## 主线程收割后台烘好的子图（每帧一次，`ImageTexture.create_from_image` 很便宜）。
func _收帧() -> void:
	if _键 == "" or not _在途.has(_键):
		return
	var 任 := _在途[_键] as 烘帧任务
	var 出 := _帧缓存[_键] as Array
	var 批 := 任.取一批()
	for 图 in 批:
		var 纹 := ImageTexture.create_from_image(图 as Image)
		if 纹 != null:
			出.append(纹)
	if 批.is_empty() and 任.跑完:
		var 基础名 := "%s%s" % [装饰前缀, _键.get_slice("|", 0)]
		if 任.丢 > 0:
			push_warning("天气特效：%s 有 %d 帧读不出来，已跳过" % [基础名, 任.丢])
		# 实测凭据：主线程只解了首帧，整叠的解码时间都在后台。
		print("天气特效：帧表 %s 裁 %s 共 %d 张（约 %.1fMB，后台烘了 %dms）" % [
			基础名, 任.裁, 出.size(),
			float(出.size()) * 任.裁.size.x * 任.裁.size.y * 4.0 / 1048576.0,
			Time.get_ticks_msec() - 任.起算])
		_在途.erase(_键)

## 帧文件名是 `<基础名>_<n>.png`（导出器口径，与 `地图物件.gd:_collect_frames` 一致）。
func _列帧文件(目录: String, 基础名: String) -> Array:
	var 遍 := DirAccess.open(目录)
	if 遍 == null:
		return []
	var 表 := []
	遍.list_dir_begin()
	var 名 := 遍.get_next()
	while 名 != "":
		if not 遍.current_is_dir() and 名.begins_with(基础名 + "_") \
				and (名.ends_with(".png") or 名.ends_with(".jpg") or 名.ends_with(".jpeg")):
			var 尾 := 名.substr(基础名.length() + 1).get_basename()
			if 尾.is_valid_int():
				表.append([尾.to_int(), 目录.path_join(名)])
		名 = 遍.get_next()
	遍.list_dir_end()
	表.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	var 出: Array = []
	for 项 in 表:
		出.append(项[1])
	return 出

## 后台那份活：解码 + 裁，别的都不碰。产物（裁好的 `Image`）放在 `成图` 里等主线程收，
## 所以它只可能比"手头这一叠"大一点，不会一路涨到 745MB。
class 烘帧任务 extends RefCounted:
	var 路径表: Array = []
	var 裁 := Rect2i()
	var 成图: Array = []
	var 锁 := Mutex.new()
	var 跑完 := false
	var 已弃 := false
	var 丢 := 0
	var 起算 := 0

	static func 读图(路径: String) -> Image:
		var f := FileAccess.open(路径, FileAccess.READ)
		if f == null:
			return null
		var 图 := Image.new()
		var 数据 := f.get_buffer(f.get_length())
		if 图.load_png_from_buffer(数据) == OK or 图.load_jpg_from_buffer(数据) == OK:
			return 图
		return null

	## 4.7 的 Image 没有 crop_region/crop_at_position ⇒ 用 get_region 取一份子图。
	## 素材比裁框小（把窗口拉到比 2450 宽还会发生）就整张交出去，剩下那块由
	## `_起片` 的 scale 拉回去补 —— 原版在那种尺寸下是露底的。
	static func 裁好(图: Image, 裁框: Rect2i) -> Image:
		if 图.get_width() >= 裁框.end.x and 图.get_height() >= 裁框.end.y:
			var 子 := 图.get_region(裁框)
			if 子 != null and 子.get_width() == 裁框.size.x \
					and 子.get_height() == 裁框.size.y:
				return 子
		return 图

	## 在 `WorkerThreadPool` 里跑。整张 5260×1770 解出来是 37MB ⇒ 立刻裁成 960×560 再交，
	## 队列里最多堆几 MB；`已弃` 让换视口/换天气的旧任务早停。
	func 跑() -> void:
		while true:
			var 路 := ""
			锁.lock()
			if not 已弃 and not 路径表.is_empty():
				路 = String(路径表.pop_front())
			锁.unlock()
			if 路 == "":
				break
			var 图 := 读图(路)
			if 图 == null:
				锁.lock()
				丢 += 1
				锁.unlock()
				continue
			锁.lock()
			成图.append(裁好(图, 裁))
			锁.unlock()
		锁.lock()
		路径表.clear()
		跑完 = true
		锁.unlock()

	## 主线程每帧调一次：一次取空队列（`pop_front` ⇒ 交出去的整张图当场就能释放）。
	func 取一批() -> Array:
		锁.lock()
		var 批: Array = []
		while not 成图.is_empty():
			批.append(成图.pop_front())
		锁.unlock()
		return 批

	func 弃() -> void:
		锁.lock()
		已弃 = true
		路径表.clear()
		锁.unlock()

func _process(delta: float) -> void:
	# 每帧先把后台烘好的帧收进显存 —— `帧` 是缓存里那份引用，收一帧就多一帧。
	_收帧()
	if 帧.size() < 2:
		# 一叠只剩一张（素材就一帧，或首帧之后全失败）⇒ 没有节拍可言，任务也收干净了就停进程。
		if _键 == "" or not _在途.has(_键):
			set_process(false)
		return
	# 原版 `Animation.tick:116-158` 是累加器：`while pastTime > delay` 逐帧追。
	帧时 += delta
	var 走过 := 0
	while 帧时 >= 帧间隔 and 走过 < 帧.size():
		帧时 -= 帧间隔
		帧号 = (帧号 + 1) % 帧.size()
		走过 += 1
	if 走过 > 0 and 片 != null:
		片.texture = 帧[帧号] as Texture2D


## 雪片层（原版 `weatherSnowLayer` + 每帧 `onWeatherSnowFrame`）。
## 数值一律由外部 `雪参数(类型)` 传进来 —— 门要钉的那张表只有一个出处。
class 雪花 extends Node2D:
	var 类型 := 4
	var 参: Dictionary = {}
	var 片: Array[Dictionary] = []
	var 帧计数 := 0.0
	var 节拍 := 60.0
	var 最大步长 := 1.0 / 15.0
	var 随机 := RandomNumberGenerator.new()

	## 节拍常量由外面传：GDScript 的内部类读不到外围脚本的 const，
	## 在这里再抄一份就成了两个真值源。
	func 起手(类型_: int, 参_: Dictionary, 节拍_: float, 最大步长_: float) -> void:
		类型 = 类型_
		参 = 参_
		节拍 = 节拍_
		最大步长 = 最大步长_
		随机.randomize()
		片.clear()
		var 视口 := get_viewport().get_visible_rect().size
		for _i in range(int(参["数量"])):
			var 径 := float(参["半径底"]) + 随机.randf() * float(参["半径随机量"])
			片.append({
				"位": Vector2(随机.randf() * float(视口.x), 随机.randf() * float(视口.y)),
				"径": 径,
				"透": float(参["实心透明度"]) + 随机.randf() * float(参["实心随机量"]),
				"横速": float(参["横速底"]) + 随机.randf() * float(参["横速随机量"]),
				"纵速": float(参["纵速底"]) + 随机.randf() * float(参["纵速随机量"]),
				"摆": float(参["摆幅底"]) + 随机.randf() * float(参["摆幅随机量"]),
				"相": 随机.randf() * TAU,
				"相速": float(参["相速底"]) + 随机.randf() * float(参["相速随机量"]),
				"旋": -float(参["自旋"]) + 随机.randf() * float(参["自旋"]) * 2.0,
			})
		queue_redraw()

	func _process(delta: float) -> void:
		var 视口 := get_viewport().get_visible_rect().size
		var 宽 := float(视口.x)
		var 高 := float(视口.y)
		if 片.is_empty() or 宽 <= 0.0 or 高 <= 0.0:
			return
		# 原版 ENTER_FRAME 跑在 60fps 的舞台上 ⇒ 位移一律按 `delta × 60` 走。
		var 步 := minf(delta, 最大步长) * 节拍
		帧计数 += 步
		var 风 := sin(帧计数 * float(参["风频"])) * float(参["风幅"])
		var 下距 := float(参["下绕边距"])
		var 侧距 := float(参["侧绕边距"])
		for 朵 in 片:
			朵["相"] = float(朵["相"]) + float(朵["相速"]) * 步
			var 位: Vector2 = 朵["位"]
			位 += Vector2(float(朵["横速"]) + sin(float(朵["相"])) * float(朵["摆"]) + 风,
					float(朵["纵速"])) * 步
			# Flash 的 `Sprite.rotation` 是**度**（`:4034 _loc6_.rotation += spin`）。
			朵["旋角"] = float(朵.get("旋角", 0.0)) + float(朵["旋"]) * 步
			if 位.y > 高 + 下距:
				位 = Vector2(随机.randf() * 宽, -下距 - 随机.randf() * 高 * float(参["上补随机比"]))
			elif 位.x < -侧距:
				位 = Vector2(宽 + 侧距, 位.y)
			elif 位.x > 宽 + 侧距:
				位 = Vector2(-侧距, 位.y)
			朵["位"] = 位
		queue_redraw()

	func _draw() -> void:
		var 阈值 := float(参.get("十字阈值", 2.3))
		var 长比 := float(参.get("十字长", 1.35))
		var 线宽 := float(参.get("线宽", 0.6))
		var 线色 := Color(1, 1, 1, float(参.get("线透明度", 0.48)))
		for 朵 in 片:
			var 径 := float(朵["径"])
			draw_set_transform(朵["位"], deg_to_rad(float(朵.get("旋角", 0.0))), Vector2.ONE)
			# 原版 `beginFill(0xFFFFFF, 0.58+rand*0.36); drawCircle(0,0,r)`（`:3988-3990`）。
			draw_circle(Vector2.ZERO, 径, Color(1, 1, 1, float(朵["透"])))
			if 径 > 阈值:
				var 长 := 径 * 长比
				draw_line(Vector2(-长, 0.0), Vector2(长, 0.0), 线色, 线宽)
				draw_line(Vector2(0.0, -长), Vector2(0.0, 长), 线色, 线宽)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
