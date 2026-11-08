## 有头量具：换皮件（每一扇原版窗右上角那颗 X、数量框那两颗加减）
## **鼠标真打得到吗、屏幕上真按 ±30/−40 变亮变暗吗**。
##
## 为什么离线门不够（`测试/换皮件三态回归测试.gd` 403 条已经判过接线）：
## 那道门读的是节点属性与运行期状态（`_形态`、四条信号、换档后的文件名），
## 它照不到三件事 —— ① 这颗钮**被别的件压住 / 摆在视口外** ⇒ 玩家鼠标根本打不到；
## ② 屏幕上那一小块像素**是不是** `clamp(皮 ± 30/−40)`（换皮对了但被主题再画一层就不对）；
## ③ **松手回 STATE_UP、移开回常态**在像素上成立（文件名为"常态"不等于屏幕上没留亮档）。
## 这三条只能在**渲染出来的那一屏**上量 ⇒ 本量具用 `root.push_input` 真投鼠标，
## 再从 `root.get_texture().get_image()` 裁那颗钮的矩形逐像素判。
##
## 代表件取"每一种落皮形态 + 每一种父布局"各一颗（状态机只有一份，见 `原版三态钮.gd`）：
##   纹理 = `好友选人窗/关钮`、`扩容窗口/关闭`（TextureButton 的 `texture_normal`）
##   图标 = `买卖数量窗/加`（Button 的 `icon`，与主窗壳那颗 X 同形态、后者已由 `量挂机勾态.gd` 判过）
##   样式盒 = `存取金额窗口/加`（四槽指向同一个 StyleBoxTexture，脚本把它 duplicate 成实例私有再换贴图）
##
## ⚠ **不能在钮上松手**：按下后在原位抬起会真把窗关掉 / 把数量加一格，后面的判据全作废。
##    抬起一律甩到 (6,6) 之后在那儿做 ⇒ `pressed` 不发、`button_up` 照发（原版也正是回 STATE_UP）。
## 跑法（**不能加 `--headless`**，无头拿不到视口图像与拾取）：
##   godot --path . --script res://开发工具/量换皮件态.gd
## 产物：`测试/截图/换皮件态/*.png` 逐态裁图（给人看的证据）+ `user://换皮件态量具.txt`（判据全文）。
extends SceneTree

const 出目录 := "res://测试/截图/换皮件态"
const 通用 := "res://素材/界面/原版窗口/通用控件/"

## 场景 → [[节点路径, 显示名, 常态皮主干, 落皮形态], …]；形态：纹理 / 图标 / 样式盒
const 代表 := [
	["res://场景/界面/窗口/好友/好友选人窗.tscn", "关钮", "好友选人窗关钮", 通用 + "关闭按钮", "纹理"],
	["res://场景/界面/组件/扩容窗口.tscn", "关闭", "扩容窗口关闭", 通用 + "关闭按钮", "纹理"],
	["res://场景/界面/组件/买卖数量窗.tscn", "加", "买卖数量窗加", 通用 + "增加按钮", "图标"],
	["res://场景/界面/组件/存取金额窗口.tscn", "加", "存取金额窗加", 通用 + "增加按钮", "样式盒"],
	## 10-20：主题 `Button` 族（`MButtonF`）—— 修行页右窗那颗「单倍领取」。
	## ⚠ 这一件**带文字** ⇒ 像素层只量外圈 2px 环带（`环` 那一列）：文字是 Button 自己另画的层，
	## 不在元件皮里，全域判会把每一粒字形都算成"不符公式"（skill 实测：57×22 全域 31.42% 红、
	## 外圈 2px 0.00%）。环带内的取样点要按**九宫格的端帽**回映射到素材文件自己的坐标
	## （钮宽 61 ≠ 皮宽 57，中段是被拉开的，直接拿 x 对 x 就串位）。
	["res://场景/界面/窗口/闭关/领取修行收益.tscn", "单倍领取", "修行窗单倍领取", 通用 + "按钮", "样式盒", 2],
]

var 行: Array[String] = []
var 红 := 0
var 判数 := 0
var 鼠 := Vector2.ZERO
var 上一鼠 := Vector2.ZERO
var 出图 := 0
var 像素判 := 0		# 像素层真正跑了几条（形状门 1 + 公式门 2 + "判到像素数"2 = 每件 5 条）——防"整段静默没跑"
var 判像素 := 0		# `_数不符` 里真正比对过的像素个数（环带∩端帽若为空，不符=0 就是 0 比 0 的假绿）


func _initialize() -> void:
	call_deferred("_跑")


func _记(s: String) -> void:
	行.append(s)
	print(s)


func _判(对: bool, s: String) -> void:
	判数 += 1
	if 对:
		_记("ok   " + s)
	else:
		红 += 1
		_记("红   " + s)


func _帧(n: int) -> void:
	for i in n:
		await process_frame


## 两跳（同一帧连发两条 motion，视口只按最后一条拾取 ⇒ 大距离瞬移不发 mouse_entered）。
func _跳到(点: Vector2) -> void:
	if 鼠.distance_to(点) > 48.0:
		_移动((鼠 + 点) * 0.5)
		await _帧(2)
	_移动(点)
	await _帧(3)


func _移动(点: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = 点
	e.global_position = 点
	e.relative = 点 - 上一鼠
	上一鼠 = 点
	鼠 = 点
	root.push_input(e)


func _键(点: Vector2, 按下: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = 点
	e.global_position = 点
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = 按下
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if 按下 else 0
	root.push_input(e)


func _拾取() -> Node:
	return root.call("gui_get_hovered_control")


func _钮心(钮: Control) -> Vector2:
	var 矩 := 钮.get_global_rect()
	return 矩.position + 矩.size * 0.5


## 生效皮文件名（三种形态各自的读法）。
func _皮(钮: Control, 形态: String) -> String:
	if 形态 == "纹理":
		var t: Texture2D = (钮 as TextureButton).texture_normal
		return "〈没图〉" if t == null else str(t.resource_path.get_file())
	if 形态 == "图标":
		var i: Texture2D = (钮 as Button).icon
		return "〈没图〉" if i == null else str(i.resource_path.get_file())
	var 盒 := (钮 as Button).get_theme_stylebox("normal")
	if 盒 is StyleBoxTexture and (盒 as StyleBoxTexture).texture != null:
		return str((盒 as StyleBoxTexture).texture.resource_path.get_file())
	return "〈没图〉"


func _跑() -> void:
	root.size = Vector2i(960, 560)
	await _帧(3)
	for 项 in 代表:
		await _走一项(项)
	_判(出图 >= 代表.size() * 4, "壬：量具自计到——每件该出 4 张裁图（常态/悬停/按下/移开），实得 %d 张 ⇒ 少图=中途静默报错" % 出图)
	## 像素层单独再钉一次"跑满"：上面那次报错实证过 —— `Image` 没有 `size()`，
	## 运行期一崩，**裁图照样出满、末行照样打红 0**，只有数判据条数才照得出来。
	_判(像素判 == 代表.size() * 5,
			"壬：量具自计到——像素层该判满 %d 条（每件形状门 1 + 公式门 2 + 判到像素数 2），实得 %d ⇒ 少一条就是那段整块没跑" % [
			代表.size() * 5, 像素判])
	_收()


func _走一项(项: Array) -> void:
	var 路 := String(项[0])
	var 节点 := String(项[1])
	var 件名 := String(项[2])
	var 主干 := String(项[3])
	var 形态 := String(项[4])
	## 只量外圈 N 像素的环带（带文字的钮必须 >0，理由见 `代表` 表里那条注释）。
	var 环 := int(项[5]) if 项.size() > 5 else 0
	var 装 := load(路) as PackedScene
	if 装 == null:
		_判(false, "%s 装不出来 ⇒ 这一件一条都没量" % 件名)
		return
	var 页 := 装.instantiate() as Control
	页.visible = true
	root.add_child(页)
	await _帧(12)
	var 钮 := 页.get_node_or_null(节点) as BaseButton
	if 钮 == null:
		_判(false, "%s/%s 运行期查无 ⇒ 表与场景对不上" % [件名, 节点])
		页.queue_free()
		return
	_判(str(钮.get_script().resource_path) == "res://脚本/界面/组件/原版三态钮.gd",
			"%s 挂的是那份唯一的状态机（实得 %s）" % [件名, str(钮.get_script().resource_path)])
	_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "%s 要手型（`MButton3.init()` `:135`）" % 件名)
	await _跳到(Vector2(6.0, 6.0))
	var 矩 := 钮.get_global_rect()
	_判(矩.position.x >= 0.0 and 矩.position.y >= 0.0 and 矩.end.x <= float(root.size.x) and 矩.end.y <= float(root.size.y),
			"壬：夹具——%s 的矩形要整个在视口里才量得到（实得 %s 视口 %s）" % [件名, str(矩), str(root.size)])
	_判(矩.size.x >= 16.0 and 矩.size.y >= 16.0,
			"壬：夹具——%s 的点击区不能细到打不中（实得 %s）" % [件名, str(矩.size)])
	_判(_皮(钮, 形态) == 主干.get_file() + ".png",
			"%s 开跑屏幕上该挂常态皮 %s.png，实得 %s" % [件名, 主干.get_file(), _皮(钮, 形态)])
	var 常态 := _裁(钮, 件名, "常态")
	## 悬停：重试到**拾取到的就是这颗钮**（开窗后头几十帧窗口还会挪位，算一次坐标就投 = 量具自己抖）。
	var 中 := false
	for 试 in 8:
		await _跳到(_钮心(钮))
		if _拾取() == 钮:
			中 = true
			break
		await _跳到(Vector2(6.0, 6.0))
	_判(中, "%s：鼠标投到钮心后拾取要落到这颗钮本身（实得 %s）⇒ 打不到 = 玩家点它没有反馈" % [
			件名, "〈无〉" if _拾取() == null else (_拾取() as Node).name])
	var 悬停 := _裁(钮, 件名, "悬停")
	_判(_皮(钮, 形态) == 主干.get_file() + "_悬停.png", "%s 悬停 ⇒ 生效的图应是 _悬停，实得 %s" % [
			件名, _皮(钮, 形态)])
	钮.button_down.connect(_钉按下.bind(件名))
	钮.button_up.connect(_钉抬起.bind(件名))
	var 收到 := 0
	for 试 in 4:
		_键(_钮心(钮), true)
		await _帧(2)
		if 按下数.has(件名) and int(按下数[件名]) > 收到:
			收到 = int(按下数[件名])
			break
		_键(鼠, false)
		await _帧(2)
	_判(收到 > 0, "%s：按下要真落到这颗钮上（重试 4 次仍没收到 button_down ⇒ 量具打偏，不作数）" % 件名)
	var 按下 := _裁(钮, 件名, "按下")
	_判(_皮(钮, 形态) == 主干.get_file() + "_按下.png", "%s 按下 ⇒ 应是 _按下，实得 %s" % [
			件名, _皮(钮, 形态)])
	## 抬起**在别处**做：在原位抬起会真关窗/加数量，后面全废；原版也是松手回 STATE_UP。
	await _跳到(Vector2(6.0, 6.0))
	_键(Vector2(6.0, 6.0), false)
	await _帧(3)
	var 移开 := _裁(钮, 件名, "移开")
	_判(_皮(钮, 形态) == 主干.get_file() + ".png",
			"%s 松手+移开 ⇒ 要回常态（停在悬停档 = 那种「松手还亮着」的假第四态），实得 %s" % [
			件名, _皮(钮, 形态)])
	# 三条像素判据：拿**屏幕上的三张裁图**与**素材文件本身**算期望（期望值不从被测对象身上取）。
	# ⚠ `Image` **没有 `size()`**（只有 `get_size()` / `is_empty()`）。写成 `.size()` 不是编译期错，
	# 是运行期 `Invalid call. Nonexistent function 'size' in base 'Image'` ⇒ **整段静默不跑**，
	# 而这一版量具当时照样打「红 0 条 / 退出码 0」（假绿实证，故下面钉 `像素判`）。
	var 皮 := _读文件(主干 + ".png")
	## 水平端帽多宽 = 这颗钮**自己的** StyleBox `texture_margin`（现读，不写死 7：
	## 边距的唯一事实源是 `原版皮肤表.九宫格`，写死就会在它改动时假红或假绿）。
	var 帽s := [0, 0]
	if 环 > 0:
		var 初 := (钮 as Button).get_theme_stylebox("normal")
		if 初 is StyleBoxTexture:
			帽s = [int(round((初 as StyleBoxTexture).texture_margin_left)),
					int(round((初 as StyleBoxTexture).texture_margin_right))]
	_判(not 常态.is_empty() and not 悬停.is_empty() and not 按下.is_empty() and not 移开.is_empty(),
			"壬：夹具——%s 的四张裁图都要拿到（拿不到 = 视口图/矩形为空，下面三条没判）" % 件名)
	if 皮.is_empty() or 常态.is_empty():
		if 皮.is_empty():
			_判(false, "壬：%s 的常态皮文件读不到 ⇒ 这一件的像素层整段没判（路=%s.png）" % [件名, 主干])
		页.queue_free()
		return
	像素判 += 1
	_判(_等(常态, 移开), "%s 移开这一帧的屏幕像素要和常态**一格不差**（形状门）" % 件名)
	for 档 in [["悬停", 30, 悬停], ["按下", -40, 按下]]:
		var 前 := 判像素
		var 差 := _数不符(常态, (档[2] as Image), 皮, int(档[1]), 环, 帽s)
		像素判 += 2		# 这一档两条：判到的像素数 + 逐通道不符数
		## 判到的像素数也要钉：环带∩端帽如果一像素都不剩，"不符 0 处"就是 0 比 0 的假绿。
		_判(判像素 - 前 >= 环 * 8, "%s %s 这一档实际判到的像素太少（%d 个，环=%d 端帽=%s）⇒ 判据等于没判" % [
				件名, String(档[0]), 判像素 - 前, 环, str(帽s)])
		_判(差 == 0, "%s %s 这一档屏幕上按 `getLightFilter(%+d)` 算：逐通道不符的像素要是 0，实得 %d" % [
				件名, String(档[0]), int(档[1]), 差])
	页.queue_free()


var 按下数 := {}
var 抬起数 := {}


func _钉按下(件名: String) -> void:
	按下数[件名] = int(按下数.get(件名, 0)) + 1


func _钉抬起(件名: String) -> void:
	抬起数[件名] = int(抬起数.get(件名, 0)) + 1


## 拿这颗钮**当前全局矩形**在视口图上裁一块（不外扩：外扩会把邻件的像素也算进来）。
func _裁(钮: Control, 件名: String, 态: String) -> Image:
	var 视 := root.get_texture().get_image()
	if 视 == null:
		_判(false, "视口图像为空 ⇒ 不能加 --headless 跑")
		return Image.new()
	var 原点: Vector2 = 钮.get_global_transform_with_canvas() * Vector2.ZERO
	var 左 := Vector2i(roundi(原点.x), roundi(原点.y))
	var 尺 := Vector2i(roundi(钮.size.x), roundi(钮.size.y))
	左.x = clampi(左.x, 0, 视.get_width() - 1)
	左.y = clampi(左.y, 0, 视.get_height() - 1)
	尺.x = clampi(尺.x, 1, 视.get_width() - 左.x)
	尺.y = clampi(尺.y, 1, 视.get_height() - 左.y)
	DirAccess.make_dir_recursive_absolute(出目录)
	var 图 := 视.get_region(Rect2i(左, 尺))
	if 图.save_png("%s/%s_%s.png" % [出目录, 件名, 态]) == OK:
		出图 += 1
	return 图


func _读文件(路: String) -> Image:
	if not FileAccess.file_exists(路):
		return Image.new()
	var 名 := FileAccess.open(路, FileAccess.READ)
	if 名 == null:
		return Image.new()
	var 图 := Image.new()
	if 图.load_png_from_buffer(名.get_buffer(名.get_length())) != OK:
		return Image.new()
	return 图


func _等(a: Image, b: Image) -> bool:
	if a.get_size() != b.get_size():
		return false
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				return false
	return true


## 屏幕上 `常态` 那一格是 `皮` 坐在某个底上合成的结果（底未知）。原版的滤镜只加在皮上：
##   out = 皮·a + 底·(1−a)      ⇒  out' = out + a·(clamp(皮+d) − 皮)
## 逐通道比（容差 2：视口是 8bit、裁图取整）。`a==255` 时这条就退化成 `out' == clamp(皮+d)`，
## 也就是 `常态 == 皮` —— 期望值来自**素材文件本身**，不是问被测对象要（否则 = 自证）。
func _数不符(常态: Image, 实测: Image, 皮: Image, d: int, 环 := 0, 帽s := [0, 0]) -> int:
	if 常态.get_size() != 实测.get_size():
		return -1
	var 宽 := mini(皮.get_width(), 常态.get_width())
	var 高 := mini(皮.get_height(), 常态.get_height())
	var 不 := 0
	var 限 := Vector2i(宽, 高) if 环 == 0 else 常态.get_size()
	var 帽左 := int(帽s[0])
	var 帽右 := int(帽s[1])
	for y in 限.y:
		for x in 限.x:
			## `环 == 0` ⇒ 全域直接对（那四件是**无字**的图标/纹理钮，裁图与素材 1:1）。
			## `环 > 0` ⇒ **带文字的钮**只量「水平端帽 ∩ 上下环带」那一圈，两个理由各管一半：
			##  * 文字是 Button 自己另画的层、不在元件皮里 ⇒ 字形那几行不许判
			##    （12 号字在 22 高的钮里占中间几行，上下各 2 行是干净的；skill 实测全域 31.42% 红、
			##     外圈 0.00%）；
			##  * 九宫格**拉开的是中段** ⇒ 中段列与素材列不是 1:1，拿 x 对 x 必串位
			##    （实测 钮宽 61 / 皮宽 57：中段 47 列对 43 列，串 4 列 ⇒ 端帽以外全判错，
			##     这一档一开始就红 54/51 处）。端帽内的列才 1:1，右端帽按"贴着素材右缘"回映射。
			var 皮x := x
			var 皮y := y
			if 环 > 0:
				var 在左帽 := x < 帽左
				var 在右帽 := x >= 限.x - 帽右
				var 在上环 := y < 环
				var 在下环 := y >= 限.y - 环
				if not ((在左帽 or 在右帽) and (在上环 or 在下环)):
					continue
				if 在右帽:
					皮x = 皮.get_width() - 限.x + x
				if 在下环 and 皮.get_height() != 限.y:
					皮y = 皮.get_height() - 限.y + y
			if 皮x < 0 or 皮x >= 皮.get_width() or 皮y < 0 or 皮y >= 皮.get_height():
				continue
			判像素 += 1
			var 底c := 常态.get_pixel(x, y)
			var 实c := 实测.get_pixel(x, y)
			var 皮c := 皮.get_pixel(皮x, 皮y)
			var a := 皮c.a
			for 通 in 3:
				var 皮v: float = [皮c.r, 皮c.g,皮c.b][通]
				var 期: float = [底c.r, 底c.g, 底c.b][通] + a * (clampf(皮v + float(d) / 255.0, 0.0, 1.0) - 皮v)
				var 实v: float = [实c.r, 实c.g, 实c.b][通]
				if absf(实v - 期) > 2.0 / 255.0:
					不 += 1
			if int(round(实c.a * 255.0)) != int(round(底c.a * 255.0)):
				不 += 1
	return 不


func _收() -> void:
	_记("换皮件态量具：判 %d 条（其中像素层 %d 条），红 %d 条，出图 %d 张（代表 %d 件）→ user://换皮件态量具.txt" % [
			判数, 像素判, 红, 出图, 代表.size()])
	var 名 := FileAccess.open("user://换皮件态量具.txt", FileAccess.WRITE)
	if 名 != null:
		名.store_string("\n".join(行) + "\n")
		名.close()
	quit(0 if 红 == 0 else 1)
