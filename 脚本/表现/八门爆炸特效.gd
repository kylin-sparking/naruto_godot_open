extends Node2D

## 原版 `ExplodeEffect`（`com/mxw/skills/effects/ExplodeEffect.as`）—— 八门「开通穴道」
## 读秒归零的那一下爆点（`CharacterHandler.addExploreEffect`，`CharacterHandler.as:783`）。
##
## 两个工厂（`ExplodeEffect.as:63-73`）：
##   · `getExplodeEffectSmall()` = **8 枚**/波、散布 **±150**（矩形 300×300）
##   · `getExplodeEffectBig()`   = **25 枚**/波、散布 **±250**（矩形 500×500）
## 节奏（`:35-55`）：`createTime = 150`、`interval = 50`，`pastTime` 超过 `start + duration(500)`
## 就不再补波；每枚粒子从三种 `Effect_MaiExplode_*` 里随机（`:12`），`fps = 100`、`once = true`。
## 位置：原版 `movieDO.x/y = 人物.x/y` ⇒ 本节点由调用方定位到人物脚下，粒子在节点局部坐标里散布。

const 名称表: Array[String] = ["Effect_MaiExplode_0", "Effect_MaiExplode_1", "Effect_MaiExplode_2"]
const 首波毫秒 := 150.0			# `ExplodeEffect.as:29 createTime = 150`
const 波间隔毫秒 := 50.0			# `:70 new ExplodeEffect(..., interval = 50, ...)`
const 持续毫秒 := 500.0			# `:69 duration = 500`

var 每波枚数 := 8
var 散布半径 := 150.0

var _已过毫秒 := 0.0
var _下一波毫秒 := 首波毫秒


## 原版两个工厂；调用方拿不到 `每波枚数/散布半径` 的写法，只能通过这两扇门。
static func 小() -> Node2D:
	return 造(true)


static func 大() -> Node2D:
	return 造(false)


static func 造(是小的: bool) -> Node2D:
	var 效 := (load("res://脚本/表现/八门爆炸特效.gd") as GDScript).new() as Node2D
	效.set("每波枚数", 8 if 是小的 else 25)
	效.set("散布半径", 150.0 if 是小的 else 250.0)
	return 效


func _process(delta: float) -> void:
	_已过毫秒 += delta * 1000.0
	# `while pastTime > createTime && pastTime < start + duration` —— 条件不闭合，
	# 恰好在 500ms 上不算这一波（`ExplodeEffect.as:47`）。
	while _下一波毫秒 < 持续毫秒 and _已过毫秒 > _下一波毫秒:
		_喷一波()
		_下一波毫秒 += 波间隔毫秒
	# `pastTime > start + duration && effects.length == 0` ⇒ 自己摘掉（`:52-57`）
	if _已过毫秒 > 持续毫秒 and get_child_count() == 0:
		queue_free()


func _喷一波() -> void:
	var 半 := int(散布半径)
	for _序号 in 每波枚数:
		var 粒 := EffectPlayer.new()
		# `MathAD.rnd(boundRect.left, boundRect.right)` —— **闭区间**整数
		粒.position = Vector2(float(randi_range(-半, 半)), float(randi_range(-半, 半)))
		add_child(粒)
		粒.play(名称表[randi() % 名称表.size()])
		粒.finished.connect(粒.queue_free)
