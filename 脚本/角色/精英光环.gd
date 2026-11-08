extends Node2D

## 怪脚下那圈会转的光环本体（首领环 / 变异环二选一）。
## 真值 = 原版 `Monster.as:1659-1682`（2.2.3优化版 的 .as），逐句转写：
##
## · 用哪张：`:1660` ⇒ `_loc5_ = boss==1 ? "Effect_BossGuanHuan" : "Effect_BianYiGuanHuan"`
##   —— **只有首领用首领环**，`boss==2` 与"带精英属性"都走变异环，不是两套尺寸同一种图。
## · 播放：`:1663-1664` ⇒ `autoTick = false`、`fps = 40` ⇒ 一帧 25 毫秒，
##   原版是外层 `tick` 喂（`:1413 effect.tick(param1)`），这里由本节点自己按 40fps 推。
## · 尺寸：`:1666-1677` 三档，全部照字面搬（分子分母都是 AS3 原式里的数）：
##     mobId 6000000/6000001 ⇒ `scaleX = 168*2/76`、`scaleY = 40*2/76`
##     boss == 1            ⇒ `scaleX = 168/76` 、`scaleY = 40/76`
##     其余（boss==2 / 有精英属性）⇒ `scaleX = 118/126`、`scaleY = 28/126`
##   分母（76 / 126）= 那个符号在原版库里的**几何边界**边长；ffdec 导出的画布比它大，
##   因为 Flash 把发光滤镜的扩散也算进了位图（变异环画布 146、首领环画布 145）。
##   缩放是对整个画布乘的 ⇒ 几何部分正好落到分子（118 / 168），发光部分按比例一起放大 ——
##   与 `脚本/角色/连斩光环.gd` 同一口径（那条是 `139.6/109.5 × 33/109.5`）。
##   ⚠ 有头量具实测：变异环第 0 帧着墨宽 **122 像素**、竖直中心正对脚点（偏 0 像素）；
##   用户给的原版实机图里同一圈量到 118~122 像素 ⇒ 对得上。首领环第 0 帧着墨宽 195
##   （= 该帧墨迹 88 × 168/76 = 194.5）。见 `开发工具/量精英光环画出来.gd`。
## · 不吃鼠标：`:1680` `mouseEnabled = mouseChildren = false` ⇒ 本工程 Node2D 本来就不吃鼠标。
## · 画在身体后面：`:550-560 layerAura()` 挂进当前落脚点那一层，且 `aLayerType = BOTTOM`
##   （`AuraLayerItem.as:47-50` + `ALayerType.BOTTOM = 0`）⇒ 环的远侧弧被怪肚子盖住。
##   本工程没有 ALayerManager ⇒ 由外层容器 `精英外观.gd` 统一给 `z_index = -1`。
## · 注册点：ffdec 导出的画布**注册点不在正中**（同 #178 那条坑）⇒ 先取全部帧的**并集**墨迹盒，
##   把"墨迹中心"对到本节点原点（= 怪的脚点）上；单帧盒会随帧动，用首帧的盒会每帧抖一下。

const 环目录 := {
	"首领": "res://素材/特效/Effect_BossOrBianYi/Effect_BossGuanHuan/",
	"变异": "res://素材/特效/Effect_BossOrBianYi/Effect_BianYiGuanHuan/",
}
## [目标宽, 目标高, 原生边长]，三档的分子分母都来自 `Monster.as:1666-1677`
const 环尺寸 := {"首领": [168.0, 40.0, 76.0], "变异": [118.0, 28.0, 126.0]}
## 首领环放大一倍的那两个怪号（`Monster.as:1666`：一尾 / 八尾）
const 双倍首领 := [6000000, 6000001]
const 每秒帧数 := 40.0

## 80 帧的贴图按档共享（每只精英怪都 load 一遍 80 张是白干的活）
static var _帧缓存 := {}

var 档名 := ""
var 帧表: Array = []
var 当前帧 := 0
var 推进 := 0.0
var 墨迹中心 := Vector2.ZERO


## 装好返回 true；素材不在（档名越界、素材被挪走）返回 false，调用方自己决定怎么处理。
func 装(要首领环: bool, 怪号: int) -> bool:
	档名 = "首领" if 要首领环 else "变异"
	帧表 = _取帧(档名)
	if 帧表.is_empty():
		return false
	当前帧 = 0
	推进 = 0.0
	墨迹中心 = _墨迹中心(档名)
	var 尺: Array = 环尺寸[档名]
	var 倍 := 2.0 if 双倍首领.has(怪号) else 1.0
	scale = Vector2(尺[0] * 倍 / 尺[2], 尺[1] * 倍 / 尺[2])
	return true


func _process(帧秒: float) -> void:
	投喂帧(帧秒)


## 公开的推进口：量具要能**定帧**拍图（不然同一档像素每帧都不一样，#196 那条坑）。
func 投喂帧(秒: float) -> void:
	if 帧表.is_empty():
		return
	推进 += 秒 * 每秒帧数
	var 新 := int(推进) % 帧表.size()
	if 新 != 当前帧:
		当前帧 = 新
		queue_redraw()


## 定帧到第 `号` 帧（量具用；越界取模）。
func 定帧(号: int) -> void:
	if 帧表.is_empty():
		return
	推进 = float(号)
	当前帧 = 号 % 帧表.size()
	queue_redraw()


## 手挑一帧画（不用 AnimatedTexture）：那样"同一档像素每帧都不一样"，量具拍不了稳定图（#196 那条坑）。
## 画布点 `墨迹中心` 要落在本节点原点（怪的脚点）⇒ 矩形左上角 = `-墨迹中心`。
func _draw() -> void:
	if 帧表.is_empty():
		return
	var 图: Texture2D = 帧表[当前帧]
	draw_texture_rect(图, Rect2(-墨迹中心, 图.get_size()), false)


static func _取帧(档: String) -> Array:
	if _帧缓存.has(档):
		return _帧缓存[档]
	var 出: Array = []
	var i := 1
	while ResourceLoader.exists("%s%d.png" % [环目录[档], i]):
		var 图 := load("%s%d.png" % [环目录[档], i]) as Texture2D
		if 图 != null:
			出.append(图)
		i += 1
	_帧缓存[档] = 出
	return 出


## 全部帧**不透明墨迹盒的并集**中心（画布坐标）。环是旋转的 ⇒ 单帧盒随帧动，必须取并集。
static func _墨迹中心(档: String) -> Vector2:
	var 并 := Rect2()
	var 有 := false
	for 图 in _取帧(档):
		var 像 := (图 as Texture2D).get_image()
		if 像 == null:
			continue
		var 盒 := 像.get_used_rect()
		var 矩 := Rect2(Vector2(盒.position), Vector2(盒.size))
		并 = 矩 if not 有 else 并.merge(矩)
		有 = true
	if not 有:
		return Vector2.ZERO
	return 并.position + 并.size * 0.5


## 表里有没有这一档的环（门与量具用，不让它们去猜目录字符串）
static func 有环(档: String) -> bool:
	return not _取帧(档).is_empty()
