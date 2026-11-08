extends Control

## 原版捉宠流程（点野宠 → 走过去 → 屏幕中央读条 5 秒 → 发 21 捕捉）。
##
## 逐句出处：
##   `com/mxw/game/world/handlers/TargetHandler.as`
##     :179-184  `canCaptureStartNow()`  两轴 |dx|<100 且 |dy|<100，且动作是 STAND/WALK、着地
##     :330-352  `gotoCapturePet()`      停挂机 → 选中但不攻击 → 近就读条，不近就 pathFind
##     :379-421  `tick()`                走读条中：离目标 200 以外 → 提示「捕捉通灵兽失败」并取消；
##                                       动作不是 STAND → 取消；倒计时到 0 → `requestCatchPet(objectId)`
##     :511-531  `startCapturePetNow()`  停寻路、站住、显示 180×20 进度条（文字「正在捕获...」）
##     :550-575  `cancelCapture()`
##   `com/mxw/common/ui/GeneralInternalLoading.as:14-104`
##     容器在屏幕正中（`Config.STAGE_WIDTH/2, STAGE_HEIGHT/2`），条 180×20 以容器左上为 (-90,-10)；
##     填充遮罩宽 `20 + 140*pct/100`；文字 140 宽、x=20、y=-10、12 号、绿 `#00ff00`、带辉光。
##   `com/mxw/roles/Monster.as:705-728`  点宠物的入口（`getCanPetMonsterCapture` 两档提示）
##
## ⚠ 进度条那两张原版皮肤（`GeneralLoadingBg_Skin` / `GeneralLoading_Skin`）**不在 MainLib 的
##   导出符号表里**（`ApplicationDomain` 里按名字定义，本机拿不到）⇒ 这里按原版的**几何与文字**
##   画一条同尺寸的绿条；皮肤等拿到真元件再换，行为与判定已经 1:1。

const 捕捉时长 := 5.0          # TargetHandler.as:30 CAPTURE_TIME = 5000
const 起手距 := 100.0          # canCaptureStartNow 两轴阈值
const 安全距 := 200.0          # tick 里「离太远就失败」的阈值
const 提示行 := "正在捕获..."      # TARGETHANDLER_NOTICE_3
const 失败提示 := "捕捉通灵兽失败"  # TARGETHANDLER_NOTICE_1

var _后端: Node
var _会话: Node
var _玩家: Node2D
var _目标: Node2D
var _阶段 := 0                 # 0 空闲 / 1 走过去 / 2 读条
var _剩余 := 0.0
var _等走秒 := 0.0
var _条: Control
var _填: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(480.0, 280.0)   # positionCaptureLoading()：屏幕正中
	_条 = Control.new()
	_条.name = "捕获条"
	_条.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_条)
	var 底 := Panel.new()
	底.position = Vector2(-90.0, -10.0)
	底.size = Vector2(180.0, 20.0)
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 皮 := StyleBoxFlat.new()
	皮.bg_color = Color(0.10, 0.10, 0.10, 0.72)
	皮.border_color = Color(0.55, 0.55, 0.55, 0.9)
	皮.set_border_width_all(1)
	底.add_theme_stylebox_override("panel", 皮)
	_条.add_child(底)
	_填 = ColorRect.new()
	_填.position = Vector2(-89.0, -9.0)
	_填.size = Vector2(20.0, 18.0)
	_填.color = Color(0.0, 0.78, 0.0, 0.95)
	_填.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_条.add_child(_填)
	var 字 := Label.new()
	字.position = Vector2(-70.0, -22.0)   # 容器 (-90,-10) 内 x=20,y=-10
	字.size = Vector2(140.0, 18.0)
	字.text = 提示行
	字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	字.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	字.add_theme_font_size_override("font_size", 12)
	字.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0))
	字.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	字.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
	字.add_theme_constant_override("outline_size", 2)
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_条.add_child(字)
	_条.visible = false


func 开始(玩家: Node2D, 目标: Node2D, 后端: Node, 会话: Node) -> void:
	_玩家 = 玩家
	_目标 = 目标
	_后端 = 后端
	_会话 = 会话
	_阶段 = 1
	_等走秒 = 0.0
	_条.visible = false
	## `gotoCapturePet`：先停挂机，再按距离决定走还是读条。
	## ⚠ 走这段必须用**"走向"（只走不打）**：`开始自动接近` 那条是"走过去打"，
	##   用它会在到跟前时把野宠打死，捕捉目标就没了。
	if _玩家 != null and _玩家.has_method("走向"):
		_玩家.call("走向", _目标.global_position, true)
	试试开始读条()


func 取消() -> void:
	_阶段 = 0
	_目标 = null
	_剩余 = 0.0
	if _条 != null:
		_条.visible = false


func 正在捕获() -> bool:
	return _阶段 != 0


func _process(delta: float) -> void:
	if _阶段 == 0:
		return
	if _玩家 == null or not is_instance_valid(_玩家) or not is_instance_valid(_目标):
		取消()
		return
	var 位 := _玩家.global_position
	var 目标位 := _目标.global_position
	var 距x := absf(位.x - 目标位.x)
	var 距y := absf(位.y - 目标位.y)
	if _阶段 == 1:
		_等走秒 += delta
		试试开始读条(距x, 距y)
		## 原版 `checkCanCaptrueStart`：寻路自己停下又没到跟前 ⇒ cancelCapture（静默）。
		## 玩家点别处会把 `click_move_active` 打掉，就属于这一档；再留 20 秒兜底。
		var 在走 = _玩家.get("click_move_active")
		if _阶段 == 1 and 在走 != null and not bool(在走) and _等走秒 > 1.5:
			取消()
		elif _阶段 == 1 and _等走秒 > 20.0:
			取消()
		return
	## 读条中：`tick()` 两条取消条件
	if 距x > 安全距 or 距y > 安全距:
		if _会话 != null:
			_会话.notification_requested.emit(失败提示)
		取消()
		return
	if _玩家动作() != 1:
		取消()
		return
	_剩余 -= delta
	var 百分比 := clampf(1.0 - _剩余 / 捕捉时长, 0.0, 1.0)
	_填.size.x = 20.0 + 140.0 * 百分比
	if _剩余 <= 0.0:
		var 号 := int(_目标.get("object_id"))
		if 号 > 0 and _后端 != null:
			_后端.call("request_pet_catch", 号)
		取消()


## 玩家动作号（`玩家.gd` 的 `_同步动作`：1 站 / 3 走 / 2 跳 / 4-5 爬 / 7 打坐 / 8 双修）。
## ⚠ `get()` 取不到时是 null，`int(null)` 会当场打断协程 —— 一律判空再转。
func _玩家动作() -> int:
	var 值 = _玩家.get("_同步动作")
	return int(值) if 值 != null else 1


func 试试开始读条(距x := -1.0, 距y := -1.0) -> bool:
	if _阶段 != 1:
		return false
	if 距x < 0.0:
		距x = absf(_玩家.global_position.x - _目标.global_position.x)
		距y = absf(_玩家.global_position.y - _目标.global_position.y)
	## canCaptureStartNow：两轴都在 100 内，动作是站或走（走只用来起手，读条中只认站）
	var 动作 := _玩家动作()
	if 距x >= 起手距 or 距y >= 起手距 or (动作 != 1 and 动作 != 3):
		return false
	_阶段 = 2
	_剩余 = 捕捉时长
	_填.size.x = 20.0
	_条.visible = true
	## startCapturePetNow：stopPathFind + setMovementAction(STAND) + 停速度
## （还要清掉"追打目标"，否则下一拍玩家又自己冲上去把这只野宠打死）
	if _玩家.has_method("停止追打"):
		_玩家.call("停止追打")
	if _玩家.has_method("cancel_auto_path"):
		_玩家.call("cancel_auto_path")
	_玩家.set("velocity", Vector2.ZERO)
	return true
