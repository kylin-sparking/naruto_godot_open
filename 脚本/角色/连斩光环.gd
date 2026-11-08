extends Node2D

## 人物脚下那圈「连斩阶段」光环（原版 `Character.as:663-676 setLianzhanEffect`）。
## 每一档阶段是一张 80 帧的循环特效，**阶段号直接拼在名字里**：`Effect_LianZhanGuanHuan_<阶段>`。
##
## 逐条对照（行号 = 2.2.3优化版 的 .as）：
## · 换档先拆旧的：`:666` ⇒ 每次 `setLianzhanEffect` 第一句都是 `destroyLianZhanAura()`（不是"有变化才换"）。
## · 名字：`:668` `"Effect_LianZhanGuanHuan_" + stage`；`stage == 0` ⇒ 只拆不建。
## · 播放：`:670-671` ⇒ `autoTick = false`、`fps = 40` ⇒ 一帧 25 毫秒，由本节点自己按 40fps 推进。
## · 尺寸：`:672-673` ⇒ `scaleX = 139.6 / 109.5`、`scaleY = 33 / 109.5`
##   （109.5 是那个符号在原版里的原生高 ⇒ 压成 ~140×33 的一圈扁环贴在地上）。
## · 不吃鼠标：`:674` ⇒ 本工程的 Node2D 本来就不吃鼠标（**没有** `input_pickable` 这个属性，写上去是 parse 错）。
## · 进哪一层：`:915-918 layerAura()` ⇒ 挂进**当前落脚点那一层**（`ALayerManager.getALayer(currFoothold.index1)`）
##   ⇒ 与人物同一个深度桶、跟人物一起被前后遮挡。本工程没有 ALayerManager ⇒ 挂在人物节点下（跟着人物走），
##   遮挡关系那一层**未逐像素对过**，记在未收口。
## · 谁调：`LianzhanHandler.as:77-97`（1291:2、角色号是自己）+ `CharacterHandler.as:189`（别人进图时按存档阶段补挂）。
## · 注册点：ffdec 导出的画布**注册点不在正中**（同 #178 那条）⇒ 先取 80 帧的**并集**墨迹盒，
##   把"墨迹中心"对到本节点原点（= 人物脚点）上；单帧盒会随帧动，所以不能用首帧的盒。

const 帧目录模板 := "res://素材/特效/Effect_LianZhanGuanHuan_%d/Effect_LianZhanGuanHuan_%d/"
const 原生高 := 109.5
const 目标宽 := 139.6
const 目标高 := 33.0
const 每秒帧数 := 40.0

var 帧表: Array[Texture2D] = []
var 当前帧 := 0
var 推进 := 0.0
var 墨迹中心 := Vector2.ZERO
var 阶段 := 0


## 装好返回 true；素材不在（阶段号越界、素材被挪走）返回 false，调用方自己决定怎么处理。
func 建(阶段号: int) -> bool:
	阶段 = 阶段号
	帧表.clear()
	当前帧 = 0
	推进 = 0.0
	var 目录 := 帧目录模板 % [阶段号, 阶段号]
	var i := 1
	while ResourceLoader.exists("%s%d.png" % [目录, i]):
		var 图 := load("%s%d.png" % [目录, i]) as Texture2D
		if 图 != null:
			帧表.append(图)
		i += 1
	if 帧表.is_empty():
		return false
	var 并 := _墨迹并集()
	墨迹中心 = 并.position + 并.size * 0.5
	scale = Vector2(目标宽 / 原生高, 目标高 / 原生高)
	set_as_top_level(false)
	return true


## 80 帧墨迹盒的**并集**（画布坐标，px）。
func _墨迹并集() -> Rect2:
	var 并 := Rect2()
	var 有 := false
	for 图 in 帧表:
		var 像 := 图.get_image()
		if 像 == null:
			continue
		var 盒 := 像.get_used_rect()
		var 矩 := Rect2(Vector2(盒.position), Vector2(盒.size))
		并 = 矩 if not 有 else 并.merge(矩)
		有 = true
	return 并


func _process(帧秒: float) -> void:
	投喂帧(帧秒)


## 公开的推进口：量具要能**定帧**拍图（不然同一档像素每帧都不一样，#196 那条坑）。
## 原版 `autoTick = false` + `fps = 40`（`Character.as:670-671`）= 引擎不自己走，由外层按 40fps 喂。
func 投喂帧(秒: float) -> void:
	if 帧表.is_empty():
		return
	推进 += 秒 * 每秒帧数
	var 新 := int(推进) % 帧表.size()
	if 新 != 当前帧:
		当前帧 = 新
		queue_redraw()


## 手挑一帧画（不用 AnimatedTexture）：那样"同一档像素每帧都不一样"，量具拍不了稳定图（#196 那条坑）。
## 画布点 `墨迹中心` 要落在本节点原点（人物脚点）⇒ 矩形左上角 = `-墨迹中心`。
func _draw() -> void:
	if 帧表.is_empty():
		return
	var 图 := 帧表[当前帧]
	draw_texture_rect(图, Rect2(-墨迹中心, Vector2(图.get_size())), false)
