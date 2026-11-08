extends Control

## 左侧那一行「离比赛结束还有： mm 分 ss 秒」= 原版 `ShowShenQiPvpTime`（一个不吃鼠标的 MWindow）。
##
## 摆位：`UIMain2.showLeftCountDownView:3124-3131` ⇒ `x = 20`、`y = 头像面板.y + 头像面板.height`
## （由 `地图实体` 负责算，原版这块挂在 UIMain2 那一层，这边挂在头像面板同一个 CanvasLayer 里）。
##
## 计时：`setCountDownTime:144-151` + `__onTick:60-79` + `__onTimerComplete:164-167` ——
## 原版是 `new Timer(1000, leftTime)`：**每一拍先减一再显示** ⇒ 900 秒这一档第一拍显示的是 899，
## 而且**起表那一瞬间是空的**（`setCountDownTime` 不写文本）⇒ 这边同样不在 `_ready` 里先画一行。
## 数走完（`Timer` 到 repeat 次数）就 `onCloseBtnClick(null)` ⇒ 整块自己藏，不靠外部关。
##
## ⚠ 只实装 **PVP 那一档**。AS3 的 `__onTick` 还有两档（神器战场 `CN.COUNTDOWN_ACTIVITY`、
## 铃铛战场 `LINGDANG_ZHANCHANG_COUNTDOWN_TIME`）与 `setData` 那行「当前持剑者：」，
## 那些属于**没移植**的神器/铃铛战场 ⇒ 不放没核过的文案，等做那两族时再补。

const 类型_PVP := 2					# `ShowShenQiPvpTime.as:19`
const 行宽 := 308.0					# `init:136/139` `setTextFieldXYWH(…, 0/20, 308, 20)`
const 行高 := 20.0
const 字色 := Color(1.0, 0.8, 0.0)		# `setTextFieldXYWH:153` 默认 16748800 = #FFCC00
const 模板 := "离比赛结束还有： %s 分 %s 秒"	# 语言包 `PVP_COUNTDOWN_TIME`（message 包现查）

var 类型 := 类型_PVP
var 剩 := 0
var 累计 := 0.0
var 时间: Label


func _ready() -> void:
	if 时间 != null:
		return
	## `init:134` `mouseEnabled = mouseChildren = false` ⇒ 整块不吃鼠标、也不给子件
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	时间 = Label.new()
	时间.name = "时间"
	时间.mouse_filter = Control.MOUSE_FILTER_IGNORE
	时间.size = Vector2(行宽, 行高)
	时间.add_theme_font_size_override("font_size", 12)
	时间.add_theme_color_override("font_color", 字色)
	时间.add_theme_constant_override("outline_size", 3)
	时间.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	add_child(时间)


## = `setCountDownTime(秒, 档)`：起表、藏掉「当前持剑者」那一行、时间行回到 y=0。
func 设倒计时(秒: int, 档: int = 类型_PVP) -> void:
	剩 = 秒
	类型 = 档
	累计 = 0.0
	visible = true
	if 时间 != null:
		时间.position = Vector2(0.0, 0.0)
		时间.text = ""


## = `onCloseBtnClick` ⇒ 走完了自己藏（`地图实体` 每帧喊一次，不额外建 Timer）。
func 停() -> void:
	剩 = 0
	visible = false


func _process(秒: float) -> void:
	if not visible or 剩 <= 0:
		return
	累计 += 秒
	while 累计 >= 1.0 and visible:
		累计 -= 1.0
		_一拍()


func _一拍() -> void:
	剩 = maxi(0, 剩 - 1)			# `:62-63` 先减一再夹 0
	时间.text = 模板 % [_两位(剩 / 60), _两位(剩 % 60)]
	if 剩 <= 0:
		停()					# `__onTimerComplete:164-167`


static func _两位(值: int) -> String:
	var 文 := str(int(值))
	return "0" + 文 if 文.length() < 2 else 文
