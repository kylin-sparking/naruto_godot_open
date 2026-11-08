extends Node2D

## 原版世界里的伤害数字。**不是 `ColorNumber` 那套位图** —— No* 系列是连斩数 / 倒计时用的
## （`LianZhanMC.as:80`、`PrizeCardSprite.as:97`）。伤害数字是一个 `TextField`，真值在
## `Monster.showFristAttriChangeTip():879-941`（人物那侧 `Character.as:1220-1290` 同款）：
##
##   · 字号按数值分档：>=500 → 22，>=100 → 20，否则 18，并且**加粗**
##   · 颜色由属性类型给（`Monster.player_addAttriChangeTip():402-430`）：
##       普通伤害 MOB_HP_COMMON = 16777215（白）、暴击 MOB_HP_BSK = 16711680（红）
##   · 文字 = `tip + "  " + ("+"|"-") + " " + num`（`Monster.as:908`、`Character.as:1235`）；
##     `num == 0` 而 tip 非空 ⇒ **只写 tip**（`:911-914`）；`num == 0 && tip == ""` ⇒ 怪身上
##     写 `FIGHT_MISS`("未命中")，玩家自己身上写 `FIGHT_AVD`("我闪")、正在跳写
##     `FIGHT_AVD_JUMP`("跳闪")（`Character.as:1244-1256`），且这一档的颜色被整个盖掉：
##     怪侧 `255`（蓝，`Monster.as:431-433`）、玩家侧 `65280`（绿，`Character.as:584-586`）
##   · 黑色辉光 `GlowFilter(0, 0.6)`
##   · 容器起点 y = `-锚点 + 12`（怪物锚点是 `mobBmdHeight`、人物是 `_crtCharHeight`）
##   · 两段补间各 0.6 秒（`TIME_ATTRI_CHANGE_TIP` 200 × 3 / 1000），起手 alpha 0.2：
##       普通：上浮 80px、alpha→1 → 回落 50px、alpha→0.2 → 移除
##       未命中：横向甩出 ±160、alpha→1 → 收回 ±30、alpha→0.2 → 移除

const 段时长 := 0.6
const 起手透明度 := 0.2
const 上浮像素 := 80.0
const 回落像素 := 50.0
const 未命中甩出 := 160.0
const 未命中收回 := 30.0

var _标签: Label
var _起点y := 0.0
var _闪避段 := false		# 第二段要知道第一段走的是"上浮"还是"横甩"那一档
var _甩向 := 1.0

## 锚点：怪物传 `min(200, 当帧 origin.y)`，人物传当前贴图高度。
## `是玩家` / `在空中` 只影响**闪避那一条**的文案（`Character.as:1244-1256`：
## 同一条 `num==0 && tip==""`，怪身上写「未命中」，玩家自己身上写「我闪」，
## 而且玩家正在跳的时候写「跳闪」`FIGHT_AVD_JUMP`；怪那一侧没有这两档，只有「未命中」）。
## `颜色` 在闪避那一档会被覆写（怪蓝 / 玩家绿，见上）。
func 播放(锚点: float, 数值: int, 文字前缀 := "", 颜色 := Color.WHITE, 朝左 := false,
		是玩家 := false, 在空中 := false) -> void:
	_起点y = -锚点 + 12.0
	position = Vector2(0.0, _起点y)
	modulate.a = 起手透明度

	_标签 = Label.new()
	var 前缀 := 文字前缀.strip_edges()
	var 闪避 := 数值 == 0 and 前缀.is_empty()
	var 颜色用 := 颜色
	if 闪避:
		# 这一档两边颜色**不一样**，别统一：怪身上 `Monster.as:431-433` 盖成 `255` = 纯蓝，
		# 玩家自己身上 `Character.as:584-586` 盖成 `65280` = 纯绿。
		_标签.text = ("跳闪" if 在空中 else "我闪") if 是玩家 else "未命中"
		颜色用 = Color(0.0, 1.0, 0.0) if 是玩家 else Color(0.0, 0.0, 1.0)
	elif 数值 == 0:
		# `Monster.as:911-914` / `Character.as:1241`：`num == 0` 而前缀非空 ⇒ **只有前缀**，
		# 不带正负号和数字（技能流水文字、连斩那一档都走这里）。
		_标签.text = 文字前缀
	else:
		_标签.text = "%s  %s %d" % [文字前缀, "+" if 数值 > 0 else "-", absi(数值)]
	_标签.add_theme_font_size_override("font_size", _字号(数值))
	_标签.add_theme_color_override("font_color", 颜色用)
	_标签.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	_标签.add_theme_constant_override("outline_size", 3)
	_标签.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_标签)
	# 原版把文字按自身宽高居中：`_loc2_.x = -textWidth/2; _loc2_.y = -textHeight/2`
	var 尺寸 := _标签.get_minimum_size()
	_标签.size = Vector2(maxf(尺寸.x, 1.0), maxf(尺寸.y, 1.0))
	_标签.position = -_标签.size * 0.5

	## ⭐ **两段、各 0.6 秒；每段里"位置 + 透明度"同时动；第二段一结束立刻移除。**
	## 出处：`Character.as:1275-1290`（第一段 y/alpha 在同一个 `TweenLite.to` 里）
	## → `onFinishTipUpTween:817-825`（第二段 y 与 alpha 也在**同一个**调用里）
	## → `onFinishTipDownTween:1603-1607`（onComplete 只做 removeChild，没有第三段动画）。
	## 这里原来写成三段 chain（上浮 0.6 → 回落 0.6 → **停在原地**淡出 0.6）
	## ⇒ 总时长 1.8 秒、最后那 0.6 秒字不动只在变淡 —— 用户 2026-10-14 说的"看着突兀"就是这一下愣住。
	var 一 := create_tween()
	一.set_parallel(true)
	var 方向 := -1.0 if 朝左 else 1.0
	if 闪避:
		一.tween_property(self, "position:x", 未命中甩出 * 方向, 段时长)
	else:
		一.tween_property(self, "position:y", _起点y - 上浮像素, 段时长)
	一.tween_property(self, "modulate:a", 1.0, 段时长)
	_闪避段 = 闪避
	_甩向 = 方向
	一.finished.connect(_飘第二段)


## 第二段：回落到 `-30`（未命中那档是收回 ±30）的同时淡回 0.2，然后移除。
func _飘第二段() -> void:
	var 二 := create_tween()
	二.set_parallel(true)
	if _闪避段:
		二.tween_property(self, "position:x", 未命中收回 * _甩向, 段时长)
	else:
		二.tween_property(self, "position:y", _起点y - 上浮像素 + 回落像素, 段时长)
	二.tween_property(self, "modulate:a", 起手透明度, 段时长)
	二.finished.connect(queue_free)

## `Monster.as:892-907`：>=500 → 22，>=100 → 20，否则 18。
func _字号(数值: int) -> int:
	var 绝对值 := absi(数值)
	if 绝对值 >= 500:
		return 22
	if 绝对值 >= 100:
		return 20
	return 18
