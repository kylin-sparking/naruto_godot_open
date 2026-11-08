extends Control

## 主界面左上角那枚「连斩」计数 + 倒计时条（原版 `com.mxw.uifl.controls.LianZhanMC`，全文 139 行都读过了）。
## 由 1291(LIANZHAN) 的 `cmd=1` 那一帧驱动；`cmd=2` 是阶段/经验加成（挂 buff + 人物光环），不进这块面板。
##
## 逐处对照（行号都是 2.2.3优化版 的 .as）：
## · 摆位 `UIMain2.as:5345-5349` ⇒ 懒建、`setParent(主界面)`、**默认隐藏**、`x = 200`、`y = 36`。
## · 层序 `LianZhanMC.as:52-55` ⇒ 底皮 `bgMC` → 进度条(运行时画的黑矩形) → 遮罩(同一张皮) → 「连斩」二字，
##   数字再 `addChildAt(cn, numChildren)` 盖最上（`:90`）。
## · 进度条是**运行时画的纯黑矩形**、不是美术（`LianZhanMC.as:45-51`）⇒ `beginFill(0)`、`drawRect(0,0,165,136)`、
##   并且 `progressBar.mask = maskMC` ⇒ 黑矩形只在**皮的形状里**显形。
## · 进度算式 `LianZhanMC.as:60-63` ⇒ `progressBar.x = 条宽 × (比例 − 1)`，配合 `mask = 皮` ⇒
##   **可见黑 = `[0, 条宽×比例]`** ⇒ 屏幕上就是"黑图原地不动、从右边开始一点点被擦掉、擦除线往左走"。
##   ⚠ 用户 10-12 实机逐帧口径与这条算式**一致**（他先说"从左到右"、随后自己更正为"从右到左"）：
##     红 = 最底层全尺寸静止图；黑 = 上层同一张皮的全尺寸静止图；倒计时**只擦黑**，红不移也不缩放。
##     本工程为此被打回两次，教训都是同一个：**判据只钉"某个 x 等于某个算式"不够，必须钉"这张图在屏幕上一动不动"**：
##     ① 第一版让黑剪影整块平移 ⇒ 看着"图在动"；② 第二版让红皮整块平移 ⇒ 血溅花纹跟着错位。
##     现在两层的 `position`/`scale` 全程恒定，随倒计时变的只有 `黑裁.size.x`（165 → 0）。
## · 倒计时 `LianZhanMC.as:126-138`，驱动点 `SkillHandler.as:271` ⇒ **每帧喂这一帧的毫秒**，攒满 `blockTime` 就整块收掉。
## · `blockTime` **不是常数**（`LianZhanMC.as:88-91`）⇒ `Etc.LianZhan.interval[连斩数/100]`；
##   现查 `数据/原版杂项.json`：`[15000,12000,9000,6000,3000,2000,1000,750,500]`（斩数越大窗口越短）。
## · 数字 = `ColorNumber(count,"NoRed0")`（`LianZhanMC.as:98-104`）⇒ `x = 10`、`y = 高 + 20`、
##   先 `width/height ×2` 再 0.5 秒回原尺寸（弹一下）。
##   拼帧：`ColorNumber.as:42` 的 `dicts = [null,"0".."9","miss"]` ⇒ **帧号 = 数字 + 1**、`count==0` 用第 11 帧「miss」；
##   `ColorNumber.as:53-76` 每个字按**墨迹包围盒**的左边缘接上一个的右边缘（`gap = 0`），`:99` 再 `container.x = -宽/2` 居中。
##   素材 = `素材/特效/Effect_colorNumber/NoRed0/1..11.png`（原版那 11 帧，画布 98×38、字在画布里的墨迹盒各不相同）。
##
## ⚠ 欠一张皮（别拿黑矩形冒充它）：`UISwf_LianZhan_Skin`（原版 `LianZhanMC.as:39-40` 的底皮 + 遮罩）
##   在本机素材里**查无**：`MainLib.xml` 的 SymbolClass 只有 407 条、里面没有它（那一串 `UISwf_LianZhan_Skin`
##   出现在 ABC 常量池里，只是字符串），`swf/UISwf/` 也没有 `UISwf_LianZhan.swf`。
##   ⇒ 现在这条黑条按原版算式滑、并被裁在 165 宽的口子里；**"条的形状由皮决定"那一层还欠着**，
##   真机上看到的是矩形进度而非皮里那个造型。找到皮之后补 `bgMC`/`maskMC` 两个节点即可，算式不用改。

const 标题皮 := "res://素材/界面/通用界面/连斩标题.png"
const 条皮 := "res://素材/界面/通用界面/连斩条底.png"
const 数字目录 := "res://素材/特效/Effect_colorNumber/NoRed0/"
const 条宽 := 165.0
const 条高 := 136.0
const 窗口默认 := [15000, 12000, 9000, 6000, 3000, 2000, 1000, 750, 500]

## 本工程 `GAME_DATA` 不是 autoload，是每个文件自己 preload 的常量（同 脚本/角色/战斗角色.gd:49）。
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")

var 连斩数 := 0
var 窗口毫秒 := 15000.0
var 攒下的毫秒 := 0.0
var 在显示 := false

var 红条: TextureRect = null		## **最底层**：红血溅，全尺寸静止，永远不动也不缩放
var 黑裁: ColorRect = null		## 套在黑底上的"擦除窗口"（原版那个遮罩的角色）
var 黑底: TextureRect = null		## **上层**：同一张皮涂成黑，全尺寸静止；被 `黑裁` 从左往右一点点擦掉
var 数字区: Control = null
var 数字块: Array[TextureRect] = []
var 补间: Tween = null


func _ready() -> void:
	# 原版 `mouseChildren = false; mouseEnabled = false` ⇒ 整块不吃鼠标，别挡住底下的点击。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(200.0, 36.0)
	## 两层皮**都是全尺寸、都不动**：红在下、黑在上；倒计时只改"黑色那张被擦掉多少"（从左往右）。
	## 红色看着在扩大，纯粹是黑色被擦掉露出来的 ⇒ 任何"移动/缩放红层"的写法都是错的
	## （10-12 被打回两次：第一版黑整块平移、第二版红整块平移，两次花纹都跟着错位）。
	红条 = TextureRect.new()
	红条.texture = load(条皮) as Texture2D
	红条.size = Vector2(条宽, 条高)
	红条.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(红条)
	黑裁 = ColorRect.new()
	黑裁.color = Color(0.0, 0.0, 0.0, 0.0)					## 窗口自己不画
	黑裁.size = Vector2(条宽, 条高)
	黑裁.mouse_filter = Control.MOUSE_FILTER_IGNORE
	黑裁.clip_contents = true
	add_child(黑裁)
	黑底 = TextureRect.new()
	黑底.texture = 红条.texture								## **同一张皮**，只是涂黑
	黑底.self_modulate = Color(0.0, 0.0, 0.0, 1.0)
	黑底.size = Vector2(条宽, 条高)
	黑底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	黑裁.add_child(黑底)

	var 题 := TextureRect.new()
	题.texture = load(标题皮) as Texture2D
	题.position = Vector2(34.5, 48.0)
	题.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(题)
	数字区 = Control.new()
	数字区.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(数字区)
	隐藏面板()


## 原版 `SkillHandler.as:271`：每帧把这一帧的毫秒数喂进来。
func _process(帧秒: float) -> void:
	投喂(帧秒 * 1000.0)


## 原版 `tick()`：攒时间 ⇒ 还有余量就按算式挪条，攒满就把整块收掉。
func 投喂(毫秒: float) -> void:
	if not 在显示:
		return
	攒下的毫秒 += 毫秒
	var 剩余 := 窗口毫秒 - 攒下的毫秒
	if 剩余 > 0.0:
		放进度(剩余 / 窗口毫秒)
	else:
		隐藏面板()


## 倒计时的唯一动作：**把黑色那张从右往左擦掉**（红色那张一动不动、也不缩放）。
## `比例` = 剩余时间 / 窗口时间（1 ⇒ 刚触发、整块黑；0 ⇒ 擦光、整块红）。
## 擦除窗口**钉在左端 x=0**、只把宽度从 165 收到 0 ⇒ 可见黑 = `[0, 条宽×比例]`，右边先露红、
## 分界线一路往左走。两层的位置与缩放全程恒定（用户 10-12 实机口径：图不动，只是黑色一点点消失）。
func 放进度(比例: float) -> void:
	黑裁.size = Vector2(条宽 * clampf(比例, 0.0, 1.0), 条高)


func 显示面板() -> void:
	visible = true
	在显示 = true
	放进度(1.0)


func 隐藏面板() -> void:
	visible = false
	在显示 = false
	连斩数 = 0


## 原版 `setCount()`。
func 设连斩数(数量: int) -> void:
	if 数量 == 0:
		隐藏面板()
		return
	连斩数 = 数量
	窗口毫秒 = float(窗口档(int(数量 / 100.0)))
	攒下的毫秒 = 0.0
	排数字(数量)
	显示面板()
	数字区.scale = Vector2(2.0, 2.0)
	if 补间 != null and 补间.is_valid():
		补间.kill()
	补间 = create_tween()
	补间.tween_property(数字区, "scale", Vector2(1.0, 1.0), 0.5)


func 窗口档(段: int) -> int:
	var 表 = GAME_DATA.取表("原版杂项").get("Lianzhan", {})
	var 档: Dictionary = (表 as Dictionary).get("interval", {}) if 表 is Dictionary else {}
	if 段 < 0 or 段 >= 窗口默认.size():
		return 500
	return int(档.get(str(段), 窗口默认[段]))


## 数字：按墨迹包围盒接排、整串居中，再摆到 `x = 10`、`y = 高 + 20`。
func 排数字(数量: int) -> void:
	for 块 in 数字块:
		数字区.remove_child(块)
		块.queue_free()
	数字块.clear()
	var 字 := str(数量)
	var 串: Array[AtlasTexture] = []
	var 总宽 := 0.0
	for i in range(字.length()):
		var 图 := _裁好的图(_帧号(字[i]))
		if 图 == null:
			continue
		串.append(图)
		总宽 += 图.region.size.x
	var 左 := -总宽 * 0.5
	var 高 := 0.0
	for 图 in 串:
		var 块 := TextureRect.new()
		块.texture = 图
		块.mouse_filter = Control.MOUSE_FILTER_IGNORE
		块.size = Vector2(图.region.size.x, 图.region.size.y)
		块.position = Vector2(左, 0.0)
		左 += 块.size.x
		高 = maxf(高, 块.size.y)
		数字区.add_child(块)
		数字块.append(块)
	数字区.size = Vector2(总宽, 高)
	数字区.position = Vector2(10.0, 高 + 20.0)


## `dicts = [null,"0".."9","miss"]` ⇒ `indexOf` + 1 = 帧号（Flash 的 MovieClip 帧是 1 基，导出的 png 也是 1 基）。
func _帧号(字: String) -> int:
	if 字.length() == 1 and 字[0] >= "0" and 字[0] <= "9":
		return 字.to_int() + 1		# "0"→第 1 帧、"9"→第 10 帧
	return 11						# miss


func _裁好的图(帧号: int) -> AtlasTexture:
	var 底 := load("%s%d.png" % [数字目录, 帧号]) as Texture2D
	if 底 == null:
		return null
	var 图 := 底.get_image()
	if 图 == null:
		return null
	var 域 := 图.get_used_rect()
	if 域.size.x <= 0 or 域.size.y <= 0:
		return null
	var 块 := AtlasTexture.new()
	块.atlas = 底
	块.region = Rect2(Vector2(域.position), Vector2(域.size))
	return 块


## 后端 1291:1 的入口（`Client.as:5594 onLianzhanCount` 那两个分支）。
func 收到连斩数(数量: int) -> void:
	设连斩数(数量)
