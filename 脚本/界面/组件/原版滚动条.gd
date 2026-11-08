extends Control

## 原版滚动条的**共用件**（用户 2026-10-14 点头：把"滑块不许短于 13 像素"这条原版下限补回来）。
##
## 真值全在 `fl/controls/ScrollBar.as` —— 原版 `ScrollPane`（32 个文件在用，心法窗就是
## `XinfaWindow.as:191 new ScrollPane()`）和 `SmallScrollBar`（18 个文件在用，它没重写
## `updateThumb`）**共用同一支 ScrollBar 的算法**，所以本工程也做成一个共用件，不给单页打补丁。
##
## · `:145-155 updateThumb()`
##     值域 = maxScroll − minScroll + page；`ScrollPane.as:134` 传进来的 maxScroll 就是
##     `contentHeight − page` ⇒ 分母 = **内容高**；
##     `thumb.height = Math.max(13, page / 内容高 × track.height)`
##     `thumb.y      = track.y + (track.height − thumb.height) × 位置 / (maxScroll − minScroll)`
## · `:271-276` `thumb.setSize(WIDTH,15)` + `thumb.move(0,15)` ⇒ 上下箭头各占 15 高。
##   ⚠ 我们的箭头皮天然 **19×17**（比原版宽 4、高 2，就是 #100 那条已登记的偏差）⇒ 这里按
##   **皮的天然尺寸**排布、不缩放美术，轨道因此比原版短 4 像素（短列表时差 1~3 像素，
##   长列表被下面的 13 下限兜住）。哪天要连宽度也对上，只改这一处即可。
## · `:83` `_lineScrollSize = 1`（`ScrollPane` 从没设过）⇒ 点一次箭头滚 **1 像素**（按住按
##   `repeatInterval` 连发）—— 看着小，但这就是原版手感，不自作主张改成"滚一行"。
## · `:352-354` 点轨道空白处 = 滚一整页（`pageScrollSize` 缺省 = pageSize）。
##
## 为什么非自己画不可：Godot 的 `ScrollBar` 滑块长度**没有 getter**、下限写死在引擎里
## （实测 10），主题 `thickness` 从 13 试到 26 长度纹丝不动（只管粗细不管长短）⇒ 没有开关可用。
## 配套量具：`开发工具/截心法页.gd` 的条数扫描表 + `测试/滚动条滑块下限回归测试.gd`。
##
## ⚠ **三个 `TextureButton` 的 `stretch_mode` 必须是 0（STRETCH_SCALE），且只能写在场景里。**
## Godot 的默认值是 **2 = STRETCH_KEEP（按皮的天然尺寸画、不看控件矩形）** —— 箭头的矩形
## 本来就等于皮（19×17）所以看不出问题，而滑块要压到 13 高：`ignore_texture_size=true` 只
## 让矩形不再被皮顶大，**不让皮缩放**。实测（10-14）：矩形 60..73、屏幕上却画到 65..95
## ⇒ 滑块盖住下箭头、拖到底还超出条底 5 像素，被用户连打回三次。判据落在像素上：
## `_量画出来的()` 把滑块临时涂绿再数屏幕行，超出矩形就记红、退出码 1。

const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 滑块下限 := 13.0		# `ScrollBar.as:153` 的 `Math.max(13, ...)`

@onready var 槽: TextureRect = $槽
@onready var 滑块: TextureButton = $滑块
@onready var 上箭头: TextureButton = $上箭头
@onready var 下箭头: TextureButton = $下箭头

var 滚动: ScrollContainer
var 内容: Control
var _拖起点 := 0.0
var _拖起始滚动 := 0.0


## 记下"这条管的是哪个滚动区、哪个内容"——每次排版都会重新指一次（同一个件反复接上，不重建）。
func 接上(滚动: ScrollContainer, 内容: Control) -> void:
	self.滚动 = 滚动
	self.内容 = 内容


## **只给心法窗挂**（2026-10-14：铺到共用 `配原版滚动区` 上会把商城的滑块甩到列表中间，
## 这个件假设"滚动区的位置与尺寸在调用这一刻已定死" ⇒ 收回来一页一页验）。
## 干三件事：① Godot 自带那条压成全透明 + 让开鼠标（**不能 hide 它** —— 一不见，
## `ScrollContainer` 既不给纵向滚、也不给这条留位置，上面的"减条宽"算式跟着失效）
## ② 把本件摆到滚动区右缘 ③ 接上数据源。返回挂上去的那个件（重复调用是幂等的）。
static func 挂到(滚动: ScrollContainer, 内容: Control, 区宽: float, 可视高: float) -> Control:
	var 父 := 滚动.get_parent()
	if 父 == null:
		return null
	var 自带 := 滚动.get_v_scroll_bar() as Control
	var 实条: float = maxf(皮肤表.滚动条宽, 自带.get_combined_minimum_size().x)
	自带.modulate = Color(1.0, 1.0, 1.0, 0.0)
	自带.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 件 := 父.get_node_or_null("原版滚动条") as Control
	if 件 == null:
		# 用 `load` 不用 `preload`：本场景的脚本就是"我自己"，编译期互相引用会绕死
		件 = (load("res://场景/界面/组件/原版滚动条.tscn") as PackedScene).instantiate() as Control
		件.name = "原版滚动条"
		父.add_child(件)
	件.position = 滚动.position + Vector2(区宽 - 实条, 0.0)
	件.size = Vector2(实条, 可视高)
	件.call("接上", 滚动, 内容)
	return 件


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE		# 空白处不拦鼠标：让滚轮落到列表上
	槽.gui_input.connect(_点轨道)
	滑块.gui_input.connect(_拖滑块)
	上箭头.pressed.connect(_滚.bind(-1.0))			# `lineScrollSize = 1`
	下箭头.pressed.connect(_滚.bind(1.0))


func _process(_d: float) -> void:
	# 宿主整页重渲染时是 `remove_child + queue_free` ⇒ 我们可能比 `滚动`/`内容` 多活几帧，
	# 那时它们已是"已释放对象"（`== null` 判不出来），碰一下就报一帧一条错误。
	if 上箭头 == null or not is_instance_valid(滚动) or not is_instance_valid(内容) or not is_inside_tree():
		return
	# 列表整个收起（心法窗常态）⇒ 这条也得跟着没
	visible = 滚动.visible
	if not visible:
		return
	var 可视 := 滚动.size.y
	var 内容高 := maxf(内容.size.y, 内容.custom_minimum_size.y)
	var 值域 := 内容高 - 可视
	if 值域 <= 0.0 or 可视 <= 0.0:
		槽.visible = false
		滑块.visible = false
		上箭头.visible = false
		下箭头.visible = false
		return
	槽.visible = true
	滑块.visible = true
	上箭头.visible = true
	下箭头.visible = true
	var 帽 := 上箭头.size.y
	var 轨长 := size.y - 2.0 * 帽
	var 高 := maxf(滑块下限, 可视 / 内容高 * 轨长)
	高 = minf(高, 轨长)
	槽.size = size
	滑块.size = Vector2(size.x, 高)
	滑块.position = Vector2(0.0, 帽 + (轨长 - 高) * clampf(滚动.scroll_vertical / 值域, 0.0, 1.0))
	下箭头.position = Vector2(0.0, size.y - 下箭头.size.y)


func _滚(方向: float) -> void:
	if 滚动 == null:
		return
	var 值域 := maxf(内容.size.y, 内容.custom_minimum_size.y) - 滚动.size.y
	滚动.scroll_vertical = int(clampf(滚动.scroll_vertical + 方向, 0.0, maxf(0.0, 值域)))


## 拖滑块：按住之后按鼠标 y 的位移换算成滚动量（换算式就是上面 `thumb.y` 那条的反解）。
func _拖滑块(事: InputEvent) -> void:
	if 滚动 == null or 内容 == null:
		return
	var 可视 := 滚动.size.y
	var 内容高 := maxf(内容.size.y, 内容.custom_minimum_size.y)
	var 值域 := 内容高 - 可视
	if 值域 <= 0.0:
		return
	var 下 := 事 as InputEventMouseButton
	if 下 != null and 下.button_index == MOUSE_BUTTON_LEFT and 下.pressed:
		_拖起点 = 下.global_position.y
		_拖起始滚动 = float(滚动.scroll_vertical)
	var 移 := 事 as InputEventMouseMotion
	if 移 != null and 移.button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
		var 帽 := 上箭头.size.y
		var 可拖 := size.y - 2.0 * 帽 - 滑块.size.y
		var 比例 := 0.0 if 可拖 <= 0.0 else (移.global_position.y - _拖起点) / 可拖
		滚动.scroll_vertical = int(clampf(_拖起始滚动 + 比例 * 值域, 0.0, 值域))


## 点轨道空白 = 滚一整页（`:352-354`）。点在滑块上时滑块自己吃掉，不会走到这里。
func _点轨道(事: InputEvent) -> void:
	var 下 := 事 as InputEventMouseButton
	if 下 == null or not 下.pressed or 下.button_index != MOUSE_BUTTON_LEFT or 滚动 == null:
		return
	var 可视 := 滚动.size.y
	var 内容高 := maxf(内容.size.y, 内容.custom_minimum_size.y)
	var 值域 := 内容高 - 可视
	if 值域 <= 0.0:
		return
	var 往哪: float = -1.0 if 下.position.y < 滑块.position.y else 1.0
	滚动.scroll_vertical = int(clampf(滚动.scroll_vertical + 往哪 * 可视, 0.0, 值域))
