extends Control

## 原版 `com/mxw/uifl/controls/yiZhi/YiZhiTip.as` —— **意志格**的悬浮提示（246 宽固定）。
## 两种文案由 `_type` 分发，两个页面各用一种：
##   type 1 `createToolTip`  → 学习页格（`YiZhiStudyCell:121`）、`ItemInfoWindow:52`
##   type 2 `createToolTip2` → 背包页格（`YiZhiCell:152-155 setToolTip`）
##
## 版式（逐条出处）：
##   :15        MAX_WIDTH = 246
##   :59-61     `back = new ToolTip_background()` 后**只设 width=246** ⇒ 宽是**定死**的
##              （与 `MToolTipText` 的"按文字缩宽"不同）；符号 699 无 scale9Grid ⇒ 整张拉伸
##   :62-73     tf.x = tf.y = 7；tf.width = MAX_WIDTH − 70 = **176**；leading 5、size 12、#FFF
##   :98        tf.height = textHeight + 6
##   :99        back.height = tf.height + 10
##   :108-114   图标 = `RotateComponent(ByteArrayImage(iconInfo))`，x = MAX_WIDTH − 65 = 181、y = 7；
##              `RotateComponent.set x/y`（`:90-102`）把 sprite 原点推到 +(w/2,h/2)，
##              而 `start()`（`:59-68`）又把源图摆到 (−w/2,−h/2) ⇒ **位图左上角正好 (181,7)**、
##              绕位图中心旋转
##   :110-111   `speed = YiZhiData.speed`（每 tick 转的度数，`RotateComponent.tick:104-107`）
##   :82        type1：`[色]名 Lv.级[/]` + 白 `desc`（+ `detailDesc`）+ 黄 `PERSONAL_SHOP_PRICE + price`
##   :91        type2：`[色]名 Lv.级[/]` + 白 `YIZHI_YI_ZHI_EXP + " " + exp/maxExp` + **红** `desc`
##              （+ 白 `detailDesc`）
##
## 行度量换算同 `文字提示框.gd`：Flash 宋体行盒 15 = Godot SimSun 13 + 2 ⇒
## `line_separation = leading + 2 = 7`，`textHeight = 20n − 5` = Godot 内容高(20n − 7) + 2。
## 定位/跟随/钳制继承 `MToolTip`（见 `文字提示框.gd` 的同名注释）。

const 定宽 := 246.0
const 文字宽 := 176.0		# MAX_WIDTH − 70
const 文字偏移 := 7.0
const 行距 := 5.0			# TextFormat.leading
const 行盒差 := 2.0			# Flash 行盒 15 − Godot SimSun 行盒 13
const 图标位 := Vector2(181.0, 7.0)	# :112-113（MAX_WIDTH − 65, 7）
## 原版 `RotateComponent.tick` 挂在 stage 帧上（`API.customHander`）。**该帧率未证** ⇒
## 这里取 24fps；它只影响转速快慢，不影响任何可量几何（要改只改这一处）。
const 节拍秒 := 1.0 / 24.0

@onready var _底: TextureRect = $底
@onready var _文字: RichTextLabel = $文字
@onready var _图标: TextureRect = $图标

var _舞台 := Vector2(960.0, 560.0)
var _鼠标点 := Vector2()
var _速度 := 0.0
var _角度 := 0.0
var _累计 := 0.0


## `YiZhiTip.setValue:76-115` 的 type 1（学习页格）。
## `实例` 提供运行期字段（`level`），缺省按原版的 `YiZhiData.level = 1` 初值。
## ⚠ `实例` 里必须带 `id`（图鉴表的键是 id、**记录内没有 id 字段**）——
## 原版 `YiZhiData` 自己持有 `id`，`getAttrValue:66-89` 的两条特例全靠它。
func 设置学习态(图鉴: Dictionary, 实例: Dictionary, 舞台尺寸: Vector2) -> void:
	var 级 := int(实例.get("level", 1))
	var 文 := "[color=%s]%s Lv.%d[/color]\n[color=#ffffff]%s" % [
			String(图鉴.get("textColor", "#ffffff")), String(图鉴.get("name", "")), 级,
			描述(图鉴, 级, 实例)]
	if 细述(图鉴) != "":
		文 += "\n" + 细述(图鉴)
	文 += "[/color]\n[color=#fff000]%s%d[/color]" % [价格字样(), int(图鉴.get("price", 0))]
	_上(文, 图鉴, 实例, 舞台尺寸)


## type 2（背包页格）。`exp` / `maxExp` 是运行期字段：`maxExp` 原版由
## `YiZhiData.maxExp:158-166` = `common.levelUp["level"+(级+1)][品质]` 现算，
## 所以调用方没给时**照同一条公式算**，不是填 0。
func 设置背包态(图鉴: Dictionary, 实例: Dictionary, 舞台尺寸: Vector2) -> void:
	var 级 := int(实例.get("level", 1))
	var 色 := String(图鉴.get("color", "gray"))
	var 表: Dictionary = 升级表().get("level%d" % (级 + 1), {})
	var 上限 := int(表.get(色, 0))
	var 经 := int(实例.get("exp", 0))
	var 文 := "[color=%s]%s Lv.%d[/color]\n[color=#ffffff]%s %d/%d[/color]\n[color=#ff0000]%s" % [
			String(图鉴.get("textColor", "#ffffff")), String(图鉴.get("name", "")), 级,
			经验字样(), 经, 上限, 描述(图鉴, 级, 实例)]
	if 细述(图鉴) != "":
		文 += "[/color]\n[color=#ffffff]" + 细述(图鉴)
	_上(文 + "[/color]", 图鉴, 实例, 舞台尺寸)


## `YiZhiData.getYiZhiDesc:147-155`：`String.Spirit[id].desc` 里的 `#value#` 换成
## **`attrValue`** = `getAttrValue(level)`。⚠️ 原版 `initData:134-139` 只在
## **非灰色**时才 `attrValue = getAttrValue(level)` ⇒ 灰色的 `#value#` 会换成 0（照做）。
static func 描述(图鉴: Dictionary, 级: int, 实例: Dictionary = {}) -> String:
	var 原 := String(图鉴.get("desc", ""))
	if not 原.contains("#value#"):
		return 原
	var 值 := 0
	if String(图鉴.get("color", "")) != "gray":
		值 = 属性值(图鉴, 级, 实例)
	return 原.replace("#value#", str(值))


static func 细述(图鉴: Dictionary) -> String:
	return String(图鉴.get("detailDesc", ""))


## `YiZhiData.getAttrValue:66-89`：两条特例（六道之力 801/802 = `3·clamp(级,1,20)`、
## 601/602 恒 1200），否则取 `attrValues.level1..levelN` 的**最大值**。
static func 属性值(图鉴: Dictionary, 级: int, 实例: Dictionary = {}) -> int:
	# id 优先取 `实例`（图鉴记录里没有 id 字段，只有表键）—— 缺了它这两条特例永远走不到，
	# 801/802 的 `3·clamp(级,1,20)` 与 601/602 的恒 1200 就会退化成 attrValues 取最大。
	var id := int(str(实例.get("id", 图鉴.get("id", "0"))))
	if id == 801 or id == 802:
		return 3 * clampi(级, 1, 20)
	if id == 601 or id == 602:
		return 1200
	var 表: Dictionary = 图鉴.get("attrValues", {})
	var 出 := 0
	var n := 1
	while n <= maxi(1, 级):
		出 = maxi(出, int(表.get(str(n), 0)))
		n += 1
	return 出


## 原版 `YiZhiManager.getYiZhiPropToopTioInfo:392-405`：**一行「当前意志：N」+ 每件穿戴一行**
## `<font color='#textColor'>名 Lv.级</font> <font color='#ff9100'>desc</font>`。
## 两处宿主共用它（意志背包窗的「意志值框」`updateYiZhiTipNow:505-514`、人物窗的「意志格」
## `CharPane.setYiZhiData:290-299` ← `YiZhiManager:284`）⇒ 只许有一份。
## 每行的 `desc` 原版现 new 一个 `YiZhiData(CocoSpirit)` 再读 `.desc`（`initData:143` →
## `getYiZhiDesc:147-155`）⇒ 这里复用上面的 `描述()`，不重抄那条 `#value#` 公式。
## ⚠️ 原版行色是 `setTextColor:204-` 按**帧色**算出来的，本工程取图鉴里按品质烘的 `textColor`：
##   夹具 `_spirit_color_id`（`fake_flash_server.py:20511-20515`）就是把 `items[id].spec.color`
##   当帧色发 ⇒ 两边恒等。真服务端若发异色帧，这里要改成按帧色查色表（同 `融合经验` 那条前提）。
static func 意志力提示文案(穿戴: Array, 值: int) -> String:
	var 文 := 语言表("YIZHI_YIZHILI_LABEL") + str(值)
	for 行 in 穿戴:
		if typeof(行) != TYPE_DICTIONARY:
			continue
		var 件 := 行 as Dictionary
		var 项 := 图鉴项(件.get("id", ""))
		文 += "<br><font color='#%s'>%s Lv.%d</font> <font color='#ff9100'>%s</font>" % [
				str(项.get("textColor", "#ffffff")).replace("#", ""), str(项.get("name", "")),
				int(件.get("level", 1)), 描述(项, int(件.get("level", 1)), 件)]
	return 文


func _上(文: String, 图鉴: Dictionary, 实例: Dictionary, 舞台尺寸: Vector2) -> void:
	if 舞台尺寸 != Vector2():
		_舞台 = 舞台尺寸
	_文字.text = 文
	var 路 := String(图鉴.get("icon", ""))
	_图标.texture = null if 路 == "" else load(路)
	if _图标.texture != null:
		var 尺 := (_图标.texture as Texture2D).get_size()
		_图标.size = 尺
		_图标.position = 图标位
		_图标.pivot_offset = 尺 / 2.0
	_速度 = float(图鉴.get("speed", 0))
	_角度 = 0.0
	_累计 = 0.0
	_排版()


func _排版() -> void:
	var 字号 := _文字.get_theme_font_size("normal_font_size")
	var 字体 := _文字.get_theme_font("normal_font")
	var 单行 := 字体.get_height(字号)
	var 量 := 字体.get_multiline_string_size(
			_文字.get_parsed_text(), HORIZONTAL_ALIGNMENT_LEFT, 文字宽, 字号)
	var 行数 := 1 if 单行 <= 0.0 else maxi(1, int(round(量.y / 单行)))
	var 内容高 := 量.y + (行距 + 行盒差) * float(行数 - 1)
	var 文字盒高 := 内容高 + 行盒差 + 6.0		# :98 tf.height = textHeight + 6
	_文字.position = Vector2(文字偏移, 文字偏移)
	_文字.size = Vector2(文字宽, 文字盒高)
	var 框 := Vector2(定宽, 文字盒高 + 10.0)	# :99 back.height = tf.height + 10
	_底.size = 框
	size = 框


## `MToolTip.setLocation`：贴在鼠标右下、钳进舞台、比舞台高就整体缩放。
func 贴到鼠标(鼠标位置: Vector2, 舞台尺寸: Vector2) -> void:
	scale = Vector2.ONE
	if size.y > 舞台尺寸.y - 8.0:
		var 比 := (舞台尺寸.y - 8.0) / size.y
		scale = Vector2(比, 比)
	var 位 := 鼠标位置 + Vector2(10.0, 20.0)
	位.x = clampf(位.x, 0.0, maxf(0.0, 舞台尺寸.x - size.x * scale.x))
	位.y = clampf(位.y, 0.0, maxf(0.0, 舞台尺寸.y - size.y * scale.y))
	position = 位


func _舞台矩形() -> Vector2:
	var 主 := get_parent() as Control
	if 主 == null:
		return _舞台
	return (_舞台 - 主.get_global_position()).max(Vector2.ZERO)


func _input(事件: InputEvent) -> void:
	if 事件 is not InputEventMouseMotion:
		return
	var 主 := get_parent() as Control
	if 主 == null:
		return
	_鼠标点 = (事件 as InputEventMouseMotion).global_position - 主.get_global_position()
	if visible:
		贴到鼠标(_鼠标点, _舞台矩形())


func _notification(什么: int) -> void:
	if 什么 == NOTIFICATION_VISIBILITY_CHANGED and visible:
		贴到鼠标(_鼠标点, _舞台矩形())


func _process(秒: float) -> void:
	if not visible or _速度 == 0.0:
		return
	_累计 += 秒
	while _累计 >= 节拍秒:
		_累计 -= 节拍秒
		_角度 = fmod(_角度 + _速度, 360.0)	# `RotateComponent.tick:104-107`
	_图标.rotation_degrees = _角度


## `PERSONAL_SHOP_PRICE`（语言表原文，含冒号）。
static func 价格字样() -> String:
	return String(语言表("PERSONAL_SHOP_PRICE"))


## `YIZHI_YI_ZHI_EXP` = 「意志经验」。
static func 经验字样() -> String:
	return String(语言表("YIZHI_YI_ZHI_EXP"))


static var _语言: Dictionary = {}


static func 语言表(键: String) -> String:
	if _语言.is_empty():
		_语言 = JSON.parse_string(FileAccess.get_file_as_string(
				"res://数据/界面/意志_文案.json"))
	return String(_语言.get(键, ""))


static var _升级: Dictionary = {}


static func 升级表() -> Dictionary:
	if _升级.is_empty():
		var 常: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
				"res://数据/意志.json"))
		_升级 = (常.get("common", {}) as Dictionary).get("levelUp", {})
	return _升级


static var _图鉴: Dictionary = {}


## 图鉴记录（`数据/意志图鉴.json`，键是 id 字符串）——只 `意志力提示文案` 用它现取名与字色，
## 格提示那条路径仍由调用方把记录传进来（`设置学习态/设置背包态` 的 `图鉴` 参数）。
static func 图鉴项(编号: Variant) -> Dictionary:
	if _图鉴.is_empty():
		_图鉴 = JSON.parse_string(FileAccess.get_file_as_string("res://数据/意志图鉴.json"))
	var 记 = _图鉴.get(str(编号), null)
	return 记 as Dictionary if 记 is Dictionary else {}
