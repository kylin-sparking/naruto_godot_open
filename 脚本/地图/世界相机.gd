class_name WorldCamera
extends Camera2D

@export var target_path: NodePath = NodePath("../Player")
@export var map_bounds := Rect2()
## 屏幕底部被 HUD 视觉遮挡的高度。不等于 底栏高度 —— 条的顶部 16px 是半透明
## 边框，透过它能看见世界，所以遮挡量比条本身矮。写成减法而非裸 85，
## 让美术改动能自动传导。
@export var bottom_hud_height := RenderProfile.底栏高度 - 16.0
## 角色在屏幕上的竖直落点偏移。
##
## 依据原版反编译：`com/mxw/game/world/Camera.as:46`
##     var _loc3_:int = this._focusObject.y - this._rect.height / 2 - 128;
## 即**相机矩形顶边 = 角色.y − 屏高/2 − 128**，也就是角色固定在屏幕中线**下方 128px**
## 处（560 档 → 角色落在 y=408，约 73% 位置），与 HUD 无关。
##
## 本相机的中心 = 角色 + (vertical_focus_offset + 底栏高度补偿/2)，
## 于是角色的屏幕 y = 屏高/2 − (offset + 补偿/2)。要让它等于 屏高/2 + 128，需
##     offset = −128 − 补偿/2
## 旧实现按"屏幕分数 38.1%"折算成 −109，把角色放到了中线上方约 66px——
## 玩家因此看到的多是头顶的地形，"能走的路"看着和地形对不上。
@export var vertical_focus_offset := -128.0 - (RenderProfile.底栏高度 - 16.0) * 0.5

var _target: Node2D = null

func _ready() -> void:
	zoom = RenderProfile.WORLD_CAMERA_ZOOM
	position_smoothing_enabled = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	_target = get_node_or_null(target_path) as Node2D
	get_viewport().size_changed.connect(refresh)
	make_current()
	refresh()

func configure(target: Node2D, bounds: Rect2) -> void:
	_target = target
	map_bounds = bounds
	refresh()

func refresh() -> void:
	zoom = RenderProfile.WORLD_CAMERA_ZOOM
	_update_position()
	force_update_scroll()

func _physics_process(_delta: float) -> void:
	_update_position()
	抖一拍(_delta)

## ── 暴击震屏（原版 `com/mxw/common/tools/Earthquake.as`）──────────────────────
## 原版调的是 `API.world.earthquake()` = `Earthquake.go(this.camera, 30, 0.3)`
## （`World.as:874-877`）。它写的是 `camera.x/y`，而那两个 setter 落到
## `_rect.x/y` + `map.scrollRect`（`Camera.as:194-215`）⇒ **抖的是世界视口，HUD 一律不动**。
## 我们这边跟位每帧重算 `global_position`，所以把抖动叠在 `offset` 上
## （Godot 的 `Camera2D.offset` 正是"叠加在跟位之后"的那个口，`zoom = 1` ⇒ 1 单位 = 1 屏幕像素）。
const 震屏帧率 := 20						# `Earthquake.as:20 FRAME_RATE = 20`
const 震屏默认强度 := 30.0					# `World.earthquake(param1 = 30, ...)`
const 震屏默认秒 := 0.3						# `World.earthquake(..., param2 = 0.3)`

var _震剩余拍 := 0
var _震强度 := 0.0
var _震累计 := 0.0

## 闸在调用那头：`SysCfg.as:30` 的 `_forbidEarthQuake` 默认 **true ⇒ 默认不抖**，
## 本工程对应设置页那枚「遮罩暴击操作的震屏特效」= `game_settings.screen_shake`
## （`离线示例数据.gd:116` 默认也是 true）。相机不去读会话，免得显示层反过来依赖数据层。
func 震一下(强度: float = 震屏默认强度, 时长秒: float = 震屏默认秒) -> void:
	## 中途重触发：原版先停旧表、**复位到 `_originalX/_originalY`**，再按新参数重开
	## （`Earthquake.go():39-45`）。这里"原值"恒为 0 ⇒ 复位就是 `offset = ZERO`。
	_震复位()
	_震强度 = 强度
	_震剩余拍 = int(时长秒 * 1000.0 / 拍毫秒())
	# `new Timer(50, 6)` 的第一拍在 50ms 之后才响，不是立刻抖 ⇒ 累计从 0 起。
	_震累计 = 0.0

func 拍毫秒() -> float:
	return floorf(1000.0 / float(震屏帧率))		# int(1000/20) = 50

## 每物理帧调一次：攒够 50ms 抖一拍，抖满 6 拍（0.3 秒）归位。
## 拆成公开函数是为了离线门能**按拍喂**，不用等真时间走 0.3 秒。
func 抖一拍(delta: float) -> void:
	if _震剩余拍 <= 0:
		return
	_震累计 += delta
	var 步 := 拍毫秒() / 1000.0
	if _震累计 < 步:
		return
	_震累计 -= 步					# 扣掉这一拍，多攒的留给下一拍（不是归零）
	_震剩余拍 -= 1
	if _震剩余拍 > 0:
		offset = _震偏移()
	else:
		_震复位()					# `TIMER_COMPLETE` ⇒ `resetImage()`：回原值 + 清表

func _震偏移() -> Vector2:
	# `quake():66-70`：`x = 原 + Math.random()*强度 - 强度/2`，结果赋给 `int` ⇒ 向下取整。
	# 强度 30 ⇒ 偏移落在 **[-15, 14]** 这一侧不闭合的区间，不是 ±15.0 的连续值。
	var 半 := floorf(_震强度 / 2.0)
	return Vector2(floorf(randf() * _震强度) - 半, floorf(randf() * _震强度) - 半)

func _震复位() -> void:
	_震剩余拍 = 0
	_震累计 = 0.0
	offset = Vector2.ZERO

func _update_position() -> void:
	if not is_instance_valid(_target):
		_target = get_node_or_null(target_path) as Node2D
	if not is_instance_valid(_target):
		return

	var hud_world_height := bottom_hud_height / zoom.y
	## ★ 跟的是**相机锚点**，不是 `global_position`：双修那 ±8 像素是"只为画而抬起来"的量。
	## 原版这条不是显式写的，是**死区**给的：`Camera.tick()` 走 `gotoFocusObject`（`Camera.as:97-155`），
	## 焦点确实是 player 本体（`World.as:287`，读的 y **含**那 ±8），但外面套了一张 256×256 的
	## `_innerRect` ⇒ 8 像素出不去死区 ⇒ 镜头一格不动。本工程是**每物理帧硬跟**、没有死区，
	## 所以在这里显式把偏移摘掉（口径与注释都在 `玩家.gd::相机锚点` 上）。
	## ⚠ 死区那一整条**没有**照抄，理由记在 `真值/窗口/双修邀请窗.md` §⑦ 末：
	## 它一旦进来，画面中心就变成"死区中心"，`Camera.as:46` 那条"角色固定在屏幕中线下方 128"
	## 的取景会一起没了（原版自己的取景是**历史相关**的，不是一个固定偏移），
	## 那是全游戏走路手感 + 一批按屏幕位判的门的改动，不是一条 bug 的修法。
	var 锚点: Vector2 = _target.call("相机锚点") if _target.has_method("相机锚点") else _target.global_position
	var desired_center := 锚点 + Vector2(
		0.0,
		vertical_focus_offset + hud_world_height * 0.5
	)
	## ★ 取整要落在**屏幕像素网格**上，不是"世界像素网格"上（2026-10-13 修"全屏就飘"）。
	##   屏幕位 = 世界 − 相机 + 视口/2。原来这里直接 `.round()` ⇒ 一旦**视口宽或高是奇数**
	##   （全屏时视口就等于屏幕/工作区尺寸，很常见），`视口/2` 带 .5 ⇒ 每个世界像素都被推到
	##   两个屏幕像素正中间 ⇒ Nearest 采样逐帧在两者之间取整 ⇒ 整幅画面（尤其八卦阵那种
	##   细亮线）看着就在抖。用户实测"恢复默认分辨率就不飘、全屏就飘"正是这个。
	##   改成先减掉半视口再取整：屏幕位 = 世界 − round(世界 − 视口/2) ⇒ **恒为整数**。
	##   视口为偶数时 `视口/2` 本身是整数 ⇒ 与旧写法逐像素等价 ⇒ 零行为变化。
	var 半视口: Vector2 = get_viewport_rect().size * 0.5 / zoom
	global_position = (_clamp_center_to_map(desired_center) - 半视口).round() + 半视口

func _clamp_center_to_map(center: Vector2) -> Vector2:
	if not map_bounds.has_area():
		return center

	var viewport_world_size := get_viewport_rect().size / zoom
	var half_view := viewport_world_size * 0.5
	var left := map_bounds.position.x + half_view.x
	var right := map_bounds.end.x - half_view.x
	var top := map_bounds.position.y + half_view.y
	# 地图最下方必须贴住实际边界；把 HUD 高度加到边界会露出地图外区域，
	# 同时将整幅世界画面向上顶。HUD 补偿只用于角色视线位置。
	var bottom := map_bounds.end.y - half_view.y
	## 图比窗口还窄/还矮时（`left > right` / `top > bottom`）**不许退化成"把图居中"**。
	## 原版 `Camera.as:122-131` 是两条**有先后**的钳制：
	##     _loc2_ = Math.max(viewRect.left, _loc2_);
	##     _loc2_ = Math.min(viewRect.right - rect.width, _loc2_);   ← 后算的那条赢
	## ⇒ 退化时**近边（左/上）钳不住、远边（右/下）钉死在屏幕边**，空出来的一条全在**上方**。
	## 我们原来写 `if left > right: 用地图中心` —— 居中会把空档劈成"上图下各一条"，
	## 于是矮图（竞技场 503000000 只有 767 高，玩家窗口 1032）整块平台悬在屏幕中间、
	## 底下露出一条天空 —— 玩家看到的就是"地图悬空"。
	## ⚠ 这里**不许**用 `clampf()`：Godot 的 `Math::clamp` 是
	##   `v < lo ? lo : (hi < v ? hi : v)` —— 一旦 `v < lo` 就**直接返回 lo、不再比 hi**。
	##   退化档（`lo > hi`）要的恰好是"比完近边还要再比远边"，所以必须把原版那两行**分开写**。
	center.x = minf(maxf(center.x, left), right)
	center.y = minf(maxf(center.y, top), bottom)
	return center
