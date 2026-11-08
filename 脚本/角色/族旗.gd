extends Node2D
## 地图上的**家族族旗**（原版 `com.mxw.roles.Flag` + `game/world/handlers/FlagHandler`）。
##
## 真值出处（逐条对着 AS3 抄的，别凭感觉改）：
##   * `FlagHandler.as:134-159` `addFlag(oid, info)`：位置取 `info.x/info.y`，
##     再按 `(x, y-30)` 往下找 foothold 贴地（本工程用 `地图实体` 同一套 foothold 逻辑）。
##   * `Flag.as:307-322` `initializeLook()`：
##       `mAnimation.skin = flag_level` —— **美术按"旗等级"取，不是家徽样式**；
##       `setAction(MobAction.stand)` —— 站着不动，只有飘动；
##       旗名牌 y=20、家族牌 y=38、家徽块 y=38（`setIcon` 里 `_iconPane.y = _namePane.y + 18`）。
##   * `Flag.as:413-427` `setIcon(flag_name, flag_level, bangName)`：
##       旗名牌 = `旗名 + CHAR_NAME_FLAG_LEVEL`（`en_US$core_properties.as:64` = `"[%1级族旗]"`）；
##       家族牌 = `CHAR_NAME_FAMILY + 族名`（`:31` = `"[家族]"`）；
##       家徽 = `PicTool.getJiaHuiPic(flag_style)`（34×34）缩到 **18×18**；
##       两行名字的颜色都是 `new RoleNamePane(4059383)` = **`#3DF0F7`**（`Flag.as:310-311`）。
##   * `Flag.as:352-366` `showHp(percent)`：血条是**按需懒建**的 ——
##       `if(null == this._hpBar) { this._hpBar = new CommonHpBar(); addChild(...) }`
##       ⇒ **刚立起来时没有任何血条**，只有挨打（服务端 `1815` 动作 4 / `FlagHandler.showHp`）
##         才第一次出现，并 **10 秒**后自己收（`setTimeout(hideMobHpBar,10000)`）。
##   * `data/flag/MapFlagInfo.as` 的 `decode()`：12 字段（本文件只读，解析在 `后端连接`）。
##
## 美术：`素材/世界/族旗/旗_<等级>_<帧>.png`（0~10 级 × 4 帧），
##   由 `开发工具/导出族旗.py` 从 `swf/BangHui/BangHui_<等级>_stand.swf` 直解
##   （那批图是 **DefineBitsJPEG3**，`开发工具/swf位图直解.py` 为此补了这个格式）。
##
## ⚠️ **注册点是从图上量的，不是原值**：原版的帧偏移在 `dat/BangHui/stand.dat` 里，
##    本机没有那份 dat。这里按"旗杆底部中心"量（与导出脚本同一算法），
##    将来若拿到 dat 应改用原值。

const 地图实体脚本 := preload("res://脚本/地图/地图实体.gd")
const 家徽图 := preload("res://脚本/界面/窗口/家族/家徽图.gd")

const 美术目录 := "res://素材/世界/族旗/"
const 帧数 := 4
## `FlagSprite.delay`（`FlagSprite.as:52-55`）取 `_crtDelays[帧]`，取不到兜底 **100ms**。
const 帧秒 := 0.1
const 血条停留 := 10.0
## 原版那两行名牌的 y（它们画在**自己原点上方**，见 `RoleNamePane`）；
## 本工程的世界名牌是"文字顶边落在 y"（见 `地图实体._名牌位置`），
## 所以换算成 `原 y - 名牌高`。
const 旗名牌Y := 20.0
const 家族牌Y := 38.0
## 两行名字的颜色：`new RoleNamePane(4059383)`（`Flag.as:310-311`）
const 名字色 := Color(0x3D / 255.0, 0xF0 / 255.0, 0xF7 / 255.0)
## `PicTool.as:509` 的原图边长；`Flag.setIcon` 把它缩到 18（`18/34`）。
const 家徽原边长 := 34.0
const 家徽边长 := 18.0
const 血条宽 := 60.0
const 血条高 := 6.0

var info := {}
var _精灵: Sprite2D
var _帧表: Array[Texture2D] = []
var _帧号 := 0
var _帧计时 := 0.0
var _血条剩 := 0.0
var _血条根: Node2D
var _血条填充: ColorRect
var _旗顶高 := 0.0


## 建这面旗。`数据` 就是服务端 `1815:1` 那 12 个字段（见 `后端连接._解族旗行`）。
func configure(数据: Dictionary) -> void:
	info = 数据.duplicate(true)
	position = Vector2(float(info.get("x", 0)), float(info.get("y", 0)))
	_建美术()
	_建名字与家徽()
	# ⚠️ **不建血条**：原版是 `showHp()` 里懒建的（见文件头），刚立起来的旗子头顶是干净的。
	#    用户 2026-10-11 实机确认"正常情况旗帜不应该显示血量"。


func 应用数据(数据: Dictionary) -> void:
	"""同一面旗的数据变了（掉血等）：只更新数值，不重画。"""
	var 旧 := info
	info = 数据.duplicate(true)
	if int(旧.get("flag_level", 0)) != int(info.get("flag_level", 0)) \
			or int(旧.get("flag_style", 0)) != int(info.get("flag_style", 0)):
		# 等级/样式变了（家徽升级）⇒ 美术与文字都得重来。原版也是重建 Flag（`removeFlag`+`addFlag`）。
		for 子 in get_children():
			子.queue_free()
		_帧表.clear()
		_血条根 = null
		_建美术()
		_建名字与家徽()
	# 只有**血量真的变了**才亮血条（原版 `FlagHandler.showHp` 也只被"血量变化"那条路调用）。
	if int(旧.get("flag_hp", 0)) != int(info.get("flag_hp", 0)):
		show_hp()


func _建美术() -> void:
	var 级 := int(info.get("flag_level", 1))
	_帧表.clear()
	for i in 帧数:
		var 路 := "%s旗_%d_%d.png" % [美术目录, 级, i]
		if ResourceLoader.exists(路):
			_帧表.append(load(路) as Texture2D)
	if _帧表.is_empty():
		push_warning("族旗：等级 %d 的美术缺失（%s旗_%d_0.png）—— 这面旗画不出来"
			% [级, 美术目录, 级])
		return
	_精灵 = Sprite2D.new()
	_精灵.name = "Sprite"
	_精灵.texture = _帧表[0]
	_精灵.centered = false
	# 注册点（杆底中心）落在节点原点上 ⇒ 旗子从地面往上立。
	_精灵.position = -量注册点(_帧表[0])
	add_child(_精灵)
	_旗顶高 = 量注册点(_帧表[0]).y


func _建名字与家徽() -> void:
	# 原版把文字画在名牌原点**上方**，所以这里减去名牌高（见文件头换算说明）。
	_造名牌("%s[%d级族旗]" % [String(info.get("flag_name", "")), int(info.get("flag_level", 1))],
		旗名牌Y - 地图实体脚本.NAMEPLATE_HEIGHT)
	_造名牌("[家族]%s" % String(info.get("bang_name", "")), 家族牌Y - 地图实体脚本.NAMEPLATE_HEIGHT)
	_建家徽()


func _造名牌(文案: String, y: float) -> void:
	var 字 := Label.new()
	字.name = "名牌"
	字.text = 文案
	字.size = Vector2(地图实体脚本.NAMEPLATE_WIDTH, 地图实体脚本.NAMEPLATE_HEIGHT)
	字.position = Vector2(-地图实体脚本.NAMEPLATE_WIDTH * 0.5, y)
	字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	字.add_theme_font_size_override("font_size", 12)
	字.add_theme_color_override("font_color", 名字色)
	字.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	字.add_theme_constant_override("outline_size", 地图实体脚本.世界名字描边)
	add_child(字)


func _建家徽() -> void:
	var 图 := 家徽图.取(int(info.get("flag_style", 0)))
	if 图 == null:
		return                       # 没这张样式就宁可不画，别编一张
	# 底框先加（同级 Sprite2D 按树序绘制 ⇒ 先加的在下层），家徽压在上面。
	# 真值 `Flag.as:419-421`：`_iconPane.addChild(Effect_CharStatus_Kuang)` 然后才 addChild 家徽；
	# 框是 **20×20**、家徽 `18×18` 摆在内缩 1px 处 ⇒ `_iconPane.width = 20`，
	# 于是 `_iconPane.x = -width/2 = -10`（**不是 -18/2**）。
	# ⚠️ 没框的时候（素材缺失）块宽退回 18 ⇒ x 退回落差 1px 的 -8 —— 与 AS3 同款分支。
	var 框 := 家徽图.取底框()
	var 块宽 := 家徽图.底框边长 if 框 != null else 家徽边长
	if 框 != null:
		var 框节 := Sprite2D.new()
		框节.name = "底框"
		框节.texture = 框
		框节.centered = false
		框节.position = Vector2(-块宽 * 0.5, 家族牌Y)
		add_child(框节)
	var 徽 := Sprite2D.new()
	徽.name = "家徽"
	徽.texture = 图
	徽.centered = false
	徽.scale = Vector2.ONE * (家徽边长 / 家徽原边长)
	# `setIcon` 里 `_loc4_.x = _loc4_.y = 1`，所在块 y = 家族牌 y + 18；x 按**块宽**算（有框时 -9）。
	徽.position = Vector2(-块宽 * 0.5 + 1.0, 家族牌Y + 1.0)
	add_child(徽)


## 懒建血条（只在第一次 `show_hp` 时建）。原版 `Flag.showHp` 就是这么写的。
func _建血条() -> void:
	_血条根 = Node2D.new()
	_血条根.name = "血条"
	_血条根.position = Vector2(-血条宽 * 0.5, -_旗顶高 - 血条高 - 2.0)
	var 底 := ColorRect.new()
	底.color = Color(0, 0, 0, 0.65)
	底.size = Vector2(血条宽, 血条高)
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_血条根.add_child(底)
	_血条填充 = ColorRect.new()
	_血条填充.color = Color(0.90, 0.16, 0.16, 1.0)   # 红色 = 敌方/可打（与原版血条同向）
	_血条填充.size = Vector2(血条宽, 血条高)
	_血条填充.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_血条根.add_child(_血条填充)
	add_child(_血条根)


func show_hp() -> void:
	"""`Flag.showHp`（`Flag.as:352-366`）：**懒建**血条 → 显血 → 10 秒后自己收，再来一次续时。"""
	if _血条根 == null or not is_instance_valid(_血条根):
		_建血条()
	var 上限 := maxf(1.0, float(info.get("flag_maxhp", 1)))
	var 现 := clampf(float(info.get("flag_hp", 0)), 0.0, 上限)
	_血条填充.size.x = 血条宽 * (现 / 上限)
	_血条根.visible = true
	_血条剩 = 血条停留


func hide_hp() -> void:
	if _血条根 != null:
		_血条根.visible = false


func _process(delta: float) -> void:
	if _帧表.size() > 1:
		_帧计时 += delta
		if _帧计时 >= 帧秒:
			_帧计时 -= 帧秒
			_帧号 = (_帧号 + 1) % _帧表.size()
			if _精灵 != null:
				_精灵.texture = _帧表[_帧号]
	if _血条剩 > 0.0:
		_血条剩 -= delta
		if _血条剩 <= 0.0:
			hide_hp()


## 量出旗杆**底部中心**（= 注册点）。
##
## ⚠️ 这是**从图上量出来的重建值**，不是原版原值 —— 原版的帧偏移在
## `dat/BangHui/stand.dat` 里，本机没有那份 dat（见文件头）。算法与
## `开发工具/导出族旗.py:量旗杆` 一致：取最底下那行不透明像素的水平中位。
static func 量注册点(图: Texture2D) -> Vector2:
	var 位 := 图.get_image()
	var 宽 := 位.get_width()
	var 高 := 位.get_height()
	for y in range(高 - 1, -1, -1):
		var xs: Array[int] = []
		for x in 宽:
			if 位.get_pixel(x, y).a > 0.03:
				xs.append(x)
		if not xs.is_empty():
			var 和 := 0
			for x in xs:
				和 += x
			return Vector2(float(和) / float(xs.size()), float(y))
	return Vector2(float(宽) * 0.5, float(高))
