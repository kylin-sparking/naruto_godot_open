extends CanvasLayer

const SKILL_ICON_PATH := "res://素材/界面/技能/技能_1001001.png"
const 快捷栏格脚本 := preload("res://脚本/界面/组件/快捷栏格.gd")

## ── 底栏那一排技能格的度量（2026-10-12 从原版元件+代码现查，逐条出处见 `真值/窗口/技能栏.md`）──
## 格子 = 元件 400 `ShortcutColumnPaneCell`（class 同名，`extends KeyboardCell`）：
##   `cellBg`(#398) 在 (0,0)、40×40；`countTextField`(#399) 在 **(5,25)**。
## 标号 = `KeyboardCell.as:49-58` 构造函数建的 `keyTextField`：fontSize **11**、bold、**(2,1)**、
##   颜色走 `init():97-116` —— 底栏是 `SHORTCUT_COLUMN` ⇒ `_loc3_ = 16708477` = **#FEF37D**（黄）。
## 图标 = `addIcon():84-88`：技能那一档按 **34×34 居中** ⇒ 内缩 (40-34)/2 = **3**。
## 流光 = `setDefaultSkill():159-170` 挂元件 **115 `EquipAnimationF`**（65 帧、MainLib 帧率 24fps），
##   AS3 写的是 x=3、y=3（那是**注册点**摆到 (3,3)）；导出的 35×35 画布左上角与注册点同 x、
##   但**高 1px**（元件内容在 y 方向伸到注册点之上）⇒ 实测亮轨落在底板局部 3..36，
##   摆位见 `流光位置`（y 取 2 才与原版逐像素对齐）。
##   条件是 `keyData.action == targetHandler.defaultSkill`（`:231-234`）。
const 格宽 := 40.0
const 图标边 := 34.0
const 图标内缩 := 3.0
const 标号色 := Color(0.99607844, 0.9529412, 0.49019608, 1.0)
const 标号位置 := Vector2(2.0, 1.0)
const 等级位置 := Vector2(5.0, 25.0)
const 字大 := 11
const 描边宽 := 3
const 流光目录 := "res://素材/界面/技能面板/选中流光/"
const 流光帧数 := 65
const 流光边 := 35.0
## 流光**不是**"跟图标同缩进"。65 帧逐像素数出来的轨迹在 35×35 画布里是**偏心**的：
##   亮点只跑四条边 —— 上边=画布第 **1** 行、下边=第 **34** 行、左边=第 **0** 列、右边=第 **33** 列
##   （行计数 1:549 / 34:544，列计数 0:431 / 33:435，其余行列各只有 24~32 个转角像素）。
## ⇒ 亮轨盒 = 画布 (0,1)..(33,34) = **34×34**，与图标那一圈同尺寸。
## 用户 10-12 给的 flash 同格实拍（43×46）按底板两条亮边（元件 398 的第 1、38 列/行）定位后：
##   亮轨四条边全在底板局部 **3..36** —— 上下左右各留 2px，一圈对称，"把图标框进"就是这个意思。
## 我们原先按 (3,3) 摆 ⇒ 实测上边落在局部 4、下边落在 37（有头量具 10-12 同一张图量的），
##   即整圈**低 1px**、下沿压到内圈之外。所以 x 取 3、y 取 2。
const 流光位置 := Vector2(3.0, 2.0)
## ⚠ **60 帧/秒，不是 SWF 头上写的 24**：`MainLib.xml` 的 `frameRate="24.0"` 只是导出时的元数据，
##   引擎一起来就把舞台帧率改掉了 —— `Engine.as:13 STAGE_FRAME_RATE:int = 60`、
##   `Engine.as:50-52 if(stage.frameRate != STAGE_FRAME_RATE) stage.frameRate = 60`、
##   `World.as:226` 又钉了一次。Flash 的时间轴每**舞台帧**走一格 ⇒ 65 帧一圈 = 1.08 秒。
##   按 24 做出来就是慢 2.5 倍（用户 10-12 用眼睛看出"速度不一致"）。
const 流光灯速 := 60.0
## 标号是**粗体**：`KeyboardCell.as:50` 构造时就调 `setKeyTextFormat()`，默认参数 `true`
## ⇒ `keyTextField.bold = true`（`:64-67`）。只有宠物那一排 `:110` 传 `false`。
## Flash 的 bold 对 TTF 是**合成加粗**，Godot 这边对等的就是 `FontVariation.variation_embolden`
## （simsun 没有独立粗体字面）。⚠ `base_font` 必须写，不写 FontVariation 什么都不渲染。
const 标号字体路径 := "res://素材/界面/simsun_原版.ttf"
const 标号粗体量 := 0.8
## ── 冷却（`MCell.showCoolDown():100-113` → `GirdCool.as`）──────────────────────
## 原版冷却**不是**"盖一块黑"，而是两件事同时发生：
##   1. `GirdCool`：42×42 的**黑色 alpha=0.8** 方块，圆角遮罩 `drawRoundRect(...,10)`，
##      `rotation=-90`，画的是**扇形** —— 角度 = 已消耗/总时长 × 360，从正上方顺时针
##      把黑"转掉"；转到 360° 自己 `destroy()`（`GirdCool.draw():52-111`）。
##   2. `onAddToStageHand():131-134` 给**整格**挂 `Style.getDisableFilter()`
##      = `ColorMatrix(0.3086,0.6094,0.082,0,0 …)` ⇒ 图标和黄标号一起变灰，冷却结束清空。
## 原版**没有倒计时秒数**（`countTextField` 那枚是技能层数，不是秒）。
const 冷却扇形着色器 := preload("res://脚本/界面/组件/冷却扇形.gdshader")
const 灰度权重 := Vector3(0.3086, 0.6094, 0.082)	# `Style.as:65` `creatDisableFilter`
const 冷却板边 := 42.0								# `GirdCool` 构造第三参 `board=42`
static var _灰度副本表: Dictionary = {}


## 图标那份灰度：Flash 是运行时滤镜，Godot 这边对等的做法是**换一张去色的图**
## （`modulate` 是乘性的，去不了饱和 —— 与 MButton3 那族"只能换皮不能染色"同一条理）。
static func 取灰度副本(贴图: Texture2D) -> Texture2D:
	if 贴图 == null:
		return null
	var 键 := String(贴图.resource_path)
	if 键.is_empty():
		键 = "实例%s" % str(贴图.get_instance_id())
	if _灰度副本表.has(键):
		return _灰度副本表[键]
	var 原图 := 贴图.get_image()
	if 原图 == null:
		return null
	var 图: Image = 原图.duplicate()
	if 图.get_format() != Image.FORMAT_RGBA8:
		图.convert(Image.FORMAT_RGBA8)
	for y in range(图.get_height()):
		for x in range(图.get_width()):
			var c := 图.get_pixel(x, y)
			var g := 灰度权重.dot(Vector3(c.r, c.g, c.b))
			图.set_pixel(x, y, Color(g, g, g, c.a))
	var 副 := ImageTexture.create_from_image(图)
	_灰度副本表[键] = 副
	return 副


## 黄标号 #FEF37D 过同一套灰度矩阵后的颜色（原版整格滤镜会连它一起变灰）。
static func 标号灰色() -> Color:
	var g := 灰度权重.dot(Vector3(标号色.r, 标号色.g, 标号色.b))
	return Color(g, g, g, 标号色.a)
static var _标号字体: FontVariation = null


static func 取标号字体() -> FontVariation:
	if _标号字体 != null:
		return _标号字体
	var 底 := load(标号字体路径) as FontFile
	if 底 == null:
		push_error("标号字体查无：%s" % 标号字体路径)
		return null
	var 粗 := FontVariation.new()
	粗.base_font = 底
	粗.variation_embolden = 标号粗体量
	_标号字体 = 粗
	return 粗


static var _流光贴图: AnimatedTexture = null


## 选中流光的贴图（65 帧、24fps、循环）。**整排共用一张**：AnimatedTexture 每帧推进是它自己的事，
## 十格各建一张会让 650 张纹理挂在内存里，而它们内容完全一样。
static func 取流光贴图() -> AnimatedTexture:
	if _流光贴图 != null:
		return _流光贴图
	var 动 := AnimatedTexture.new()
	## ⚠ Godot 4.7 的 AnimatedTexture **没有 `fps`、也没有 `loop`**（有就撞上 #169 那个
	## 「转圈每秒才走一帧」的老坑：`frame_N/duration` 缺省是 1.0 秒）。要 24fps 只能逐帧
	## `set_frame_duration(序号, 1/24)`；循环由 `one_shot = false` 表达（缺省即循环，写明它）。
	动.one_shot = false
	## ⚠ `set_frames(数量)` 只管**帧数**（不是"第几帧给哪张图"），
	## 逐帧贴图要 `set_frame_texture(序号, 贴图)` —— 写成 `set_frames(0, i, 图)` 直接 parse 失败。
	动.set_frames(流光帧数)
	for i in range(流光帧数):
		var 路 := "%s%02d.png" % [流光目录, i + 1]
		if not ResourceLoader.exists(路):
			push_error("选中流光缺帧：%s（应为 65 张，缺任何一张都别让它半截转）" % 路)
			return null
		动.set_frame_texture(i, load(路) as Texture2D)
		动.set_frame_duration(i, 1.0 / 流光灯速)
	_流光贴图 = 动
	return 动
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")

## ── 精华容器（#184）：展开＝大球、收起＝细条，**两版二选一** ──────────────────
## 原版 `MenuPane.as:105` 起步 `breathPane1.visible=false`（默认展开），`:106` 给 `arrowBtn` 挂 CLICK，
## `:119-123 __switchBreathPane` 只做一件事：`breathPane.visible = !breathPane.visible` 之后
## `breathPane1.visible = !breathPane.visible` ⇒ **恰好一版可见**（不是高度动画、不是缩放）。
## 收起那一版是 `BreathPane1` = 一枚 `MBar`(`BreathBarF`) + 四颗 17×17 小钮（`BreathPane1.as:36-55`
## 的 x=0/18/45/63、y=15），**不是**把球藏起来就完事。
const 精华上限 := 500000			# `UIConfig.as:910` `ZQ_MAX`（定值，不按等级算）
const 球满高 := 80.0				# `BreathPane.as:113-118` `breathMask.y = 80 - int(80 * 比例)`
const 球顶 := 11.0					# 场景里 `BreathContainer` 节点的 offset_top（球画布的 y 基准）
const 条满宽 := 81.0				# `BreathBarF` 里 `bar`(符号 305) 的原画宽
const 条窗左 := 3.0				# `BreathBarF` 里 `maskMc`(符号 302) 在 (3,5)、宽 75
const 条窗宽 := 75.0
const 条带上 := 3.0					# `bar` 画在 (0,2)、mask 在 y=5 ⇒ 取贴图的 y 从 5-2=3 起，高 5
const 条带高 := 5.0

var _精华展开 := true
var _精华球: TextureRect
var _精华条: TextureRect
var _精华条数值: Label
var _精华收起: Control
var _精华展开件: Array[Node] = []
var _精华箭头: TextureButton
var _态实例: Dictionary = {}

@onready var bottom_menu: Control = get_node_or_null("技能栏")

var _session: Node
var _player: Node
var _experience_fill: TextureRect
var _shortcut_buttons: Array[BaseButton] = []
var _cooldown_overlays: Array[ColorRect] = []
var _冷却材质: Array[ShaderMaterial] = []
var _shortcut_icons: Array[TextureRect] = []
var _图标原皮: Array[Texture2D] = []
var _标号件: Array[Label] = []

func _ready() -> void:
	_session = get_node_or_null("/root/GameSession")
	transform = Transform2D.IDENTITY
	_setup_shortcuts()
	_setup_feature_buttons()
	_setup_精华容器()
	_setup_那一排()
	_setup_打坐四钮()
	_setup_experience()
	_connect_session()
	_refresh_all()


## 四颗球要**每帧跟着角色**（原版是在 `HealHandler.tick()` 里比较玩家坐标、变了才挪），
## 挂在 `_process` 上而不是信号上：打坐期间角色可能被打、被击退、被传送，位置源只有世界那边。
func _process(_秒: float) -> void:
	_刷新打坐四钮()

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var slot := _slot_from_key((event as InputEventKey).keycode)
	if slot >= 0:
		_use_skill(slot)

func _setup_shortcuts() -> void:
	if bottom_menu == null:
		return
	var skills: Array = _session.skill_slots if _session != null else []
	for slot in range(10):
		var cell := bottom_menu.get_node_or_null("SkillShortcut%d" % slot) as Control
		if cell == null:
			continue
		var has_skill := slot < skills.size() and not (skills[slot] as Dictionary).is_empty()
		## 底板 = 原版 `cellBg`（元件 400 时间轴里那枚 #398）。图标与冷却扇形都**相对它**摆，
		## 所以它在格子里怎么挪都不用改代码 —— 这是原版自己的父子关系（`addIcon():89`）。
		var 底板 := cell.get_node_or_null("ShortcutFrame") as TextureRect
		if 底板 == null:
			push_error("第 %d 格缺 `ShortcutFrame`（元件 398 那张底板）⇒ 图标与冷却没法定位" % slot)
			continue
		var icon: TextureRect = null
		var icon_texture: Texture2D = null
		if has_skill:
			var skill: Dictionary = skills[slot]
			var icon_path := String(skill.get("icon", ""))
			if icon_path.is_empty() and _session != null:
				var canonical: Dictionary = GAME_DATA.skill(skill.get("id", ""))
				icon_path = String(canonical.get("icon", ""))
			if icon_path.is_empty():
				icon_path = SKILL_ICON_PATH
			if ResourceLoader.exists(icon_path):
				icon_texture = load(icon_path) as Texture2D
			icon = TextureRect.new()
			icon.name = "SkillIcon"
			icon.position = Vector2(图标内缩, 图标内缩)
			icon.size = Vector2(图标边, 图标边)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.texture = icon_texture
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			## ⚠ 图标是**底板的子件**，不是格子的 —— 原版 `addIcon():78-91` 最后一行就是
			##   `this.cellBg.addChild(param1)`，且 `param1.x = (cellBg.width - 34) >> 1`。
			##   ⇒ 图标的坐标永远相对底板：底板在格子里挪到哪，图标跟到哪，不用重算
			##   （用户 10-12 把 `ShortcutFrame` 从 (0,0) 挪到 (-1,0)，硬算格子坐标的写法当场错位）。
			底板.add_child(icon)
		# 层数（原版 `countTextField`，元件 400 时间轴里就在 (5,25)）：`setItemCount(floor)`，
		# 文本 = `floor`，有加成时再拼 `+加成`（`KeyboardCell.as:260-281`）。
		# ⚠ 原版是 `param1 > 0` 才显 —— 0 层（没学）不显数字。
		var 层数 := Label.new()
		层数.name = "SkillLevel"
		层数.position = 等级位置
		层数.size = Vector2(34.0, 14.0)
		层数.add_theme_font_size_override("font_size", 字大)
		层数.add_theme_color_override("font_color", Color.WHITE)
		层数.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		层数.add_theme_constant_override("outline_size", 描边宽)
		层数.add_theme_constant_override("shadow_offset_x", 0)
		层数.add_theme_constant_override("shadow_offset_y", 0)
		层数.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var 本格: Dictionary = skills[slot] if has_skill else {}
		var 级 := int(本格.get("level", 0))
		层数.text = str(级) if 级 > 0 else ""
		层数.visible = 级 > 0
		cell.add_child(层数)
		# 标号（1..9、第 10 格是 "0"）：场景里已烤好一枚 Label，这里只**按真值校一遍**并接上文本，
		# 让"编辑器里看到的"与"跑起来看到的"是同一份（原版那一枚是代码建的 `keyTextField`）。
		var 标号 := cell.get_node_or_null("KeyLabel") as Label
		if 标号 == null:
			标号 = Label.new()
			标号.name = "KeyLabel"
			cell.add_child(标号)
		标号.text = _slot_key_text(slot)
		if 取标号字体() != null:
			标号.add_theme_font_override("font", 取标号字体())
		## ⚠ 层序要摆成原版的顺序：元件 400 时间轴是 `cellBg(0) → countTextField(1)`，
		##   构造函数再 `addChild(keyTextField)`（`KeyboardCell.as:51`）⇒ **标号压在层数与图标之上**；
		##   之后 `setDefaultSkill()` 的流光（`:169`）、`showCoolDown()` 的扇形（`MCell.as:105`）
		##   依次往上。图标挪进底板之后，"图标盖住标号"那个坑自然没了，但层数仍要在标号之下。
		cell.move_child(标号, cell.get_child_count() - 1)
		标号.position = 标号位置
		标号.size = Vector2(18.0, 14.0)
		标号.add_theme_font_size_override("font_size", 字大)
		标号.add_theme_color_override("font_color", 标号色)
		标号.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		标号.add_theme_constant_override("outline_size", 描边宽)
		标号.add_theme_constant_override("shadow_offset_x", 0)
		标号.add_theme_constant_override("shadow_offset_y", 0)
		标号.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 选中流光：只有"当前选中的那一枚"身上有（`KeyboardCell.setCellValue:231-234`）。
		# ⚠ 它坐在图标**之上**、鼠标要透过去（原版 mouseEnabled=false）。
		# 判据不是"节点盒与图标盒重合"，而是**亮轨盒**（画布 (0,1)..(33,34)）与图标盒重合
		# ⇒ 摆位取 `流光位置`=(3,2)，不是 AS3 字面的 (3,3)。
		# 本工程底板被挪到过 (-1,0)（用户 10-12 手改），按格子硬算就会与图标错开 1 像素
		# ⇒ 一律**相对底板**摆，圈跟着它要框住的那个盒子走。
		var 流光 := TextureRect.new()
		流光.name = "选中流光"
		流光.position = 底板.position + 流光位置
		流光.size = Vector2(流光边, 流光边)
		流光.mouse_filter = Control.MOUSE_FILTER_IGNORE
		流光.texture = 取流光贴图()
		流光.visible = false
		cell.add_child(流光)
		# 冷却扇形（原版 `GirdCool`）：黑色 alpha 0.8、圆角遮罩、随时间顺时针转掉。
		# 挂在**格子**上、位置取**底板原点**（原版 board=42 而 cellBg 是 40 ⇒ 遮罩比底板
		# 四周各多 1 像素，圆角才对得上底板的圆角）。每格一份 ShaderMaterial：进度各不相同。
		var 材 := ShaderMaterial.new()
		材.shader = 冷却扇形着色器
		var overlay := ColorRect.new()
		overlay.name = "CooldownOverlay"
		overlay.position = 底板.position
		overlay.size = Vector2(冷却板边, 冷却板边)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.visible = false
		overlay.material = 材
		cell.add_child(overlay)
		var button := Button.new()
		button.name = "SkillButton"
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.focus_mode = Control.FOCUS_NONE
		button.flat = true
		# ⚠️ **不能**用 `disabled` 来表示空格子：Godot 里禁用的控件收不到鼠标，而
		# **空格子恰恰是最主要的落点**（把忍术拖到一个空快捷键位）。空格子改由
		# `_use_skill()` 自己判空，外观还是靠下面那句 `cell.modulate`。
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if has_skill else Control.CURSOR_ARROW
		# 落点：接"从忍术面板拖过来的技能"（原版 `ShortcutColumnPane` 的 SKILL_WINDOW 那一支）。
		button.set_script(快捷栏格脚本)
		button.set("槽位号", slot)
		button.connect("绑定完成", _on_快捷栏绑定)
		button.pressed.connect(_use_skill.bind(slot))
		if has_skill:
			var skill: Dictionary = skills[slot]
			button.tooltip_text = "%s\n快捷键 %s  ·  冷却 %.1f 秒" % [String(skill.get("name", "忍术")), _slot_key_text(slot), float(skill.get("cooldown", 1.0))]
		# ⚠ 空格子**不许把整格压暗**（以前这里 `cell.modulate` 调成棕灰）：原版空格子就是那张
		#   `cellBg` 底板 + 一样亮的黄色标号（用户 10-12 给的原版图里 6..0 那五枚空格的标号
		#   与 1..5 同色同亮），压暗会让"没放技能"看起来像"技能不可用"。
		cell.add_child(button)
		_shortcut_buttons.append(button)
		_cooldown_overlays.append(overlay)
		_冷却材质.append(材)
		_shortcut_icons.append(icon if has_skill else null)
		_图标原皮.append(icon_texture if has_skill else null)
		_标号件.append(标号)
	刷新选中流光()

## 把"当前选中的那一枚"格子上的流光点亮、其余九格灭掉。
## 原版是建格时判一次（`KeyboardCell.setCellValue:231-234` 里 `== defaultSkill` 才 `setDefaultSkill()`），
## 本工程选中态会在运行时变（点格子、点怪、TAB 换目标都会改 `游戏会话.默认忍术`）⇒ 单独抽一个口，
## 建完格与每次改选中都喊一遍。
func 刷新选中流光() -> void:
	if bottom_menu == null:
		return
	var 亮格 := -1
	if _session != null:
		亮格 = int(_session.call("默认忍术槽"))
	for slot in range(10):
		var cell := bottom_menu.get_node_or_null("SkillShortcut%d" % slot) as Control
		if cell == null:
			continue
		var 流光 := cell.get_node_or_null("选中流光") as CanvasItem
		if 流光 != null:
			流光.visible = slot == 亮格

## 拖一个忍术到快捷栏格之后：重画快捷栏（图标/提示/冷却都跟着换）。
func _on_快捷栏绑定(_槽位: int, 成功: bool) -> void:
	if 成功:
		_refresh_shortcuts()

func _setup_feature_buttons() -> void:
	if bottom_menu == null or _session == null:
		return
	# ⚠ 这里**只**管底栏那十颗功能钮。`find_children(..., true, false)` 是**递归**的，
	#   精华容器那一排（`技能栏/宠物Button`）与底栏的「宠物」（`技能栏/@Control@123/@TextureButton@121`）
	#   tooltip 同名 ⇒ 以前这一条会把那一排的宠物钮一起抓走（开宠物窗，而原版是"附身/收回"）。
	#   那一排八颗由 `_setup_那一排()` 按**节点名**逐颗绑，出处见 真值/窗口/那一排按钮.md。
	var features := ["人物", "背包", "忍术", "宠物", "任务", "组队", "好友", "家族", "商城", "设置"]
	for node in bottom_menu.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null or button.get_parent() == bottom_menu:
			continue		# 直接挂在 `技能栏` 下的是那一排，不属于这十颗
		if button.tooltip_text in features:
			button.pressed.connect(_session.request_feature.bind(button.tooltip_text))

func _setup_experience() -> void:
	_experience_fill = get_node_or_null("技能栏/ExperienceFill") as TextureRect
	if _experience_fill != null and _experience_fill.material != null:
		_experience_fill.material = _experience_fill.material.duplicate()

func _connect_session() -> void:
	if _session == null:
		return
	_session.player_stats_changed.connect(_on_stats_changed)
	_session.skill_cooldown_changed.connect(_on_skill_cooldown_changed)
	_session.skills_changed.connect(_refresh_shortcuts.unbind(1))
	if _session.has_signal("默认忍术_changed"):
		_session.connect("默认忍术_changed", func(_编号: int) -> void: 刷新选中流光())
	var backend := get_node_or_null("/root/BackendConnection")
	if backend != null and backend.has_signal("heal_state_received"):
		backend.heal_state_received.connect(_on_heal_state)

func _refresh_all() -> void:
	if _session == null:
		return
	_on_stats_changed(_session.player_stats)
	for slot in range(mini(_session.skill_slots.size(), _shortcut_buttons.size())):
		var duration := float(_session.skill_slots[slot].get("cooldown", 1.0))
		_on_skill_cooldown_changed(slot, float(_session.call("get_skill_cooldown", slot)), duration)

func _refresh_shortcuts() -> void:
	_shortcut_buttons.clear()
	_cooldown_overlays.clear()
	_冷却材质.clear()
	_shortcut_icons.clear()
	_图标原皮.clear()
	_标号件.clear()
	if bottom_menu == null:
		return
	for slot in range(10):
		var cell := bottom_menu.get_node_or_null("SkillShortcut%d" % slot) as Control
		if cell == null:
			continue
		# ⚠ `SkillIcon` 现在是**底板的子件**（原版 `addIcon():89`），路径要带一层
		for child_name in ["ShortcutFrame/SkillIcon", "CooldownOverlay",
				"SkillButton", "SkillLevel", "选中流光"]:
			var child := cell.get_node_or_null(child_name)
			if child != null:
				child.free()
		cell.modulate = Color.WHITE
	_setup_shortcuts()
	_refresh_all()

func _use_skill(slot: int) -> void:
	if slot < 0 or slot >= _shortcut_buttons.size():
		return
	# 空格子不响应（原来靠 `button.disabled` 挡，现在禁用会让拖放落不上去 —— 见 `_setup_shortcuts`）。
	if _session != null and (slot >= _session.skill_slots.size() or _session.skill_slots[slot].is_empty()):
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	# ⭐ 点一下 = **把这枚设成"当前选中的忍术"**（原版 `TargetHandler.defaultSkill`，
	#   `TargetHandler.as:128-147`），之后点怪就默认用它（`SkillExecute.moveToAttack():59+` 每拍读它）。
	if _session != null:
		var 编号 := int(String(_session.skill_slots[slot].get("id", "")))
		# 原版 `SkillExecute.as:205`：再点**同一枚**已选中的、而且正在追打目标 ⇒ 什么都不做
		# （既不重复触发、也不把选中清掉）。
		var 在追打 := _player != null and is_instance_valid(_player) 				and _player.get("自动接近目标") != null 				and is_instance_valid(_player.get("自动接近目标"))
		if int(_session.get("默认忍术")) == 编号 and 在追打:
			return
		_session.call("设默认忍术", 编号)
	if _player != null and _player.has_method("use_skill_slot"):
		_player.call("use_skill_slot", slot)

func _toggle_practise() -> void:
	var backend := get_node_or_null("/root/BackendConnection")
	if backend != null and bool(backend.in_game):
		if int(backend.authoritative_heal.get("state", 0)) > 0:
			backend.request_heal_stop()
		else:
			backend.request_heal_start()
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player == null or not _player.has_method("toggle_practise"):
		return
	_player.call("toggle_practise")

## 打坐的**视觉反馈不在按钮上**：`HealHandler.healStateChange` 改的是角色的动作（坐下），
## 原版 `BreathPane` 从头到尾没给这四颗钮挂 `selected` —— 所以这里**不许**染按钮
## （以前那句 `self_modulate = #fff4b8` 是自造，10-12 删）。
func _on_heal_state(state: Dictionary) -> void:
	var active := int(state.get("state", 0)) > 0
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player != null and _player.has_method("set_practising"):
		_player.call("set_practising", active)

## 原版 `BreathPane.as:44` 给**球底**（`breath_background`）挂了 `MToolTipText`：
## `MToolTipText.createToolTip(stage, this.breath_background, CN.replaceString(CN.MENU_JINGHUA_TIP, 0))`，
## `:113-117 setData` 里再 `toolTip.text = CN.replaceString(CN.MENU_JINGHUA_TIP, 当前, ZQ_MAX, ZQ_MAX)`
## ⇒ **悬停查克拉精华球会弹出四行说明**（紫/黄/蓝/绿各一行），这是用户 2026-10-20 报的
## 「地图正中间最下面的查克拉精华框显示不对」——我们以前**根本没接**这个框。
## 文案取自 `en_US$message_properties.as:330` 的 `MENU_JINGHUA_TIP`（本工程没有语言表，按原句硬编码；
## 原句本身就是四段 `<font color="#…">…</font><br/>`，这里翻成 BBCode 同色）。
const 精华提示场景 := preload("res://场景/界面/组件/文字提示框.tscn")
const 精华提示节点名 := "精华提示框"
const 精华提示模板 := "[color=#9933fa]当前查克拉精华：%d/%d[/color]\n" \
		+ "[color=#ffff00]通过打坐等途径获得的查克拉精华将保存于此，上限为%d[/color]\n" \
		+ "[color=#1e90ff]查克拉精华可用于开通八门穴道，升级忍术等操作[/color]\n" \
		+ "[color=#00ff00]双修打坐与双倍查克拉精华符可以增加同时间内查克拉精华的收益[/color]"
var _精华提示: Control


## 精华容器的两版布局 + 折叠钮（#184）。
## ⚠ 收起那一版的四颗小钮**这里显式连**：`_setup_feature_buttons` 用的是
##   `find_children("*", "BaseButton", true, false)`，第 4 参 `false` = 不含隐藏件，
##   而 `精华收起` 起步就是 `visible=false` ⇒ 那一轮根本看不到它们（静默漏连）。
func _setup_精华容器() -> void:
	if bottom_menu == null:
		return
	_精华收起 = bottom_menu.get_node_or_null("精华收起") as Control
	_精华球 = bottom_menu.get_node_or_null("BreathContainer") as TextureRect
	_精华箭头 = bottom_menu.get_node_or_null("ChakraCoreArrow") as TextureButton
	if _精华收起 != null:
		_精华条 = _精华收起.get_node_or_null("填充") as TextureRect
		_精华条数值 = _精华收起.get_node_or_null("数值") as Label
	_精华展开件.clear()
	for 名 in ["OriginalChakraCore", "BreathContainer", "ChakraCoreTrim",
			"打坐Button", "宠物Button", "闭关经验Button", "挂机Button"]:
		var 件 := bottom_menu.get_node_or_null(名)
		if 件 != null:
			_精华展开件.append(件)
		else:
			push_warning("技能面板：精华容器缺件 %s（折叠判据会说不清是谁的锅）" % 名)
	if _精华箭头 != null:
		_精华箭头.pressed.connect(_切换精华)
		_绑三态(_精华箭头)
	# 球底（原版 `breath_background`）吃悬停：`BreathPane.as:43` 只把 `breathContainer`/`breathMask`
	# 设成 mouseEnabled=false，**球底没关** ⇒ 提示框挂在它身上。PASS 只收悬停、不吞点击。
	var 球底 := bottom_menu.get_node_or_null("OriginalChakraCore") as Control
	if 球底 != null:
		球底.mouse_filter = Control.MOUSE_FILTER_PASS
		球底.mouse_entered.connect(_显精华提示.bind(true))
		球底.mouse_exited.connect(_显精华提示.bind(false))
	_画精华()


## 悬停精华球 ⇒ 弹四行说明（原版 `MToolTipText`，见上面常量处注释）。
## ⚠ 提示框挂的是**本面板这根 CanvasLayer**（= 原版 `createToolTip(stage, …)` 的那个 stage），
## 所以必须把舞台尺寸交给 `设置`：组件默认那对 960×560 只是巧合对上，写清楚才算按约定传参
## （窗口类宿主一律传 `页面.get_viewport_rect().size`，见 `人物窗口.gd:_挂文字提示`）。
## ⚠ 旧账：原版 `MToolTip.as:34-46 closeTip` 是 ROLL_OUT 就 `_container.removeChild(this)`，
## 这边留着节点只切 `visible`（省得每次悬停重建度量）；`:131-133` 那条「框比舞台高就整体缩放」
## 也没验过（四行 92px，永远比舞台矮）。两条都记在编年史 §3.240。
func _显精华提示(显: bool) -> void:
	if not is_instance_valid(_精华提示):
		if not 显:
			return
		_精华提示 = 精华提示场景.instantiate() as Control
		_精华提示.name = 精华提示节点名
		_精华提示.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_精华提示)
	_精华提示.call("设置", 精华提示文本(), get_viewport().get_visible_rect().size)
	_精华提示.visible = 显


func 精华提示文本() -> String:
	var 存量 := int(_session.player_stats.get("zq", 0)) if _session != null else 0
	return 精华提示模板 % [存量, 精华上限, 精华上限]

func _切换精华() -> void:
	_精华展开 = not _精华展开
	_画精华()

## ── 精华容器上那一排四颗钮（#185）────────────────────────────────
## 原版同一个东西有**两份类**：展开 = `BreathPane.as`（元件 335 里的四颗 `MButton3`，
## 皮肤 = 元件 #322/#326/#330/#334，各 31×37），收起 = `BreathPane1.as:36-53`（运行期
## `BaseUtil.getButtonBySkin` 建的四颗 17×17，x=0/18/45/63、y=15）。
## 两版**动作不是逐颗相同**：`__biGuanExp` 在展开版调 `showLingquPane()`（开「领取修行收益」，
## `UIMain2.as:5949-5956`），在收起版调 `showBiguanWindow()`（开关「修行设定与收益」整扇，
## `UIMain2.as:3071-3078`）。照抄，别"统一"成一条。
## ⚠ 原版这四颗**没有选中态**（时间轴里只有一枚 `upSkin`，没有 `selectedUpSkin`），
##   点下去不染色、不换图 —— 打坐的反馈是**角色坐下**（`healStateChange`）。
const 那一排大钮 := [["打坐Button", "practise"], ["宠物Button", "pet"],
		["闭关经验Button", "claim"], ["挂机Button", "hang"]]
const 那一排小钮 := [["坐Button", "practise"], ["附Button", "pet"],
		["修Button", "biguan_window"], ["挂Button", "hang"]]
## 原版 `HealHandler.CD_REQUEST = 1000`（`HealHandler.as:34`）：`triggerHealState()` 走的是
## `requestHealStart(false)` / `requestHealStop(false)`，那条 `param1=false` 的分支里
## `if(!param1 && requestCDlast > 0) return`（`:345-348`、`:487-490`）⇒ 连点要能吃掉 1 秒。
const 打坐防抖毫秒 := 1000
## 原版 `GuajiHandler.set isStart` 里的 `_isCding`：置 true 后 1 秒内再置不生效
## （`GuajiHandler.as:1027-1037` 的 `setTimeout(..., 1000)`）。
const 挂机防抖毫秒 := 1000
## `CN.PETHANDLER_FUSHEN_PROMPT_2` / `_1`（语言表 message 包）—— 两条都是原版原句。
const 提示没有通灵兽 := "你还没有通灵兽！"
const 提示没有可附身 := "没有可以附身的通灵兽！"

var _上次打坐毫秒 := -1000000
var _上次切挂机毫秒 := -1000000

func _setup_那一排() -> void:
	if bottom_menu == null:
		return
	_接一排(bottom_menu, 那一排大钮)
	if _精华收起 != null:
		_接一排(_精华收起, 那一排小钮)

func _接一排(宿主: Node, 表: Array) -> void:
	for 行 in 表:
		var 钮 := 宿主.get_node_or_null(String(行[0])) as TextureButton
		if 钮 == null:
			push_warning("技能面板：那一排缺钮 %s（这一点就没人响应，门会红）" % 行[0])
			continue
		_绑三态(钮)
		# 只在一个地方连 ⇒ 不会有第二次 `pressed.connect`（#200 那条每次进图刷 ERROR 的根因）
		钮.pressed.connect(_那一排动作.bind(String(行[1])))

func _那一排动作(身份: String) -> void:
	match 身份:
		"practise":
			_打坐()
		"pet":
			_附身或收回宠物()
		"claim":
			if _session != null:
				_session.request_feature("领取修行收益")
		"biguan_window":
			if _session != null:
				_session.request_feature("闭关经验")
		"hang":
			_切换挂机()

## 打坐。原版 `triggerHealState()` = `nowInHeal ? requestHealStop : requestHealStart`
## （`HealHandler.as:363-374`）⇒ 判的是**服务端回帧里的状态**，不是本地猜。
func _打坐() -> void:
	var 现在 := Time.get_ticks_msec()
	if 现在 - _上次打坐毫秒 < 打坐防抖毫秒:
		return
	_上次打坐毫秒 = 现在
	_toggle_practise()

## 原版 `BreathPane.__guaJi` = `API.guajiHandler.isStart = !API.guajiHandler.isStart`
## —— 这颗钮是**开关**，不是"打开挂机设置窗"（开窗是另一条：`KEY_ID_15`「挂机设置」= J，
## 挂在别的入口上）。这里用工程既有的 `request_hang()`，不发明新协议。
func _切换挂机() -> void:
	if _session == null:
		return
	var 现在 := Time.get_ticks_msec()
	if 现在 - _上次切挂机毫秒 < 挂机防抖毫秒:
		return
	_上次切挂机毫秒 = 现在
	_session.request_hang(not bool(_session.hang_state.get("active", false)))

## 原版 `PetHandler.fuShenOrHuiShouPet():210-233` 三条分支（**不是**打开宠物窗）：
##   1) 一只都没有 ⇒ 「你还没有通灵兽！」
##   2) 有已召唤的那只（`position==0` ⇔ 原版 `CocoPet.STATUS_SUMMON`，
##      见 `CocoPet.as:72-85` 的 `updateStatus`）⇒ `requestCallBackPet` 收回
##   3) 否则取**第一只**在袋里（`STATUS_NORMAL`）且等级够携带的 ⇒ 附身；都没有 ⇒
##      「没有可以附身的通灵兽！」
## 出战中的那枚（`position==125` ⇔ `STATUS_ATTACK`）原版这一族**不碰** ⇒ 这里也跳过。
## `getCanFushenPet()` 传的是 `param1=false` ⇒ 等级不够时原版**不弹**「等级不足」那条，这里同样不弹。
func _附身或收回宠物() -> void:
	if _session == null:
		return
	var 列表: Array = _session.pets
	if 列表.is_empty():
		_session.notification_requested.emit(提示没有通灵兽)
		return
	for 项 in 列表:
		var 谁 := 项 as Dictionary
		if bool(谁.get("attached", false)):
			_session.set_pet_attached(String(谁.get("id", "")), false)
			return
	for 项 in 列表:
		var 谁 := 项 as Dictionary
		if bool(谁.get("attached", false)) or bool(谁.get("deployed", false)):
			continue
		if _携带等级够(谁):
			_session.set_pet_attached(String(谁.get("id", "")), true)
			return
	_session.notification_requested.emit(提示没有可附身)

## 原版 `PetDataManage.isLevelEnough():45-70`：玩家等级要 **≥ 宠物等级** 且
## **≥ 该宠的携带等级**（`PetAddValue.getPetCarryLevel(itemId)` 读 `info.carryLevel`，
## 查无当 0 ⇒ 不设闸）。
func _携带等级够(谁: Dictionary) -> bool:
	var 我 := int(_session.player_stats.get("level", 1))
	if 我 < int(谁.get("level", 1)):
		return false
	var 模板: Dictionary = GAME_DATA.pet_template(int(谁.get("item_id", int(谁.get("id", 0)))))
	return 我 >= int((模板.get("info", {}) as Dictionary).get("carryLevel", 0))

func _画精华() -> void:
	var 存量 := int(_session.player_stats.get("zq", 0)) if _session != null else 0
	var 比例 := clampf(float(存量) / float(精华上限), 0.0, 1.0)
	if _精华收起 != null:
		_精华收起.visible = not _精华展开
	for 件 in _精华展开件:
		件.visible = _精华展开
	if _精华箭头 != null:
		_精华箭头.tooltip_text = "收起精华容器" if _精华展开 else "展开精华容器"
	# 球：`BreathPane.setData` 把遮罩往下推 ⇒ 露出的是**底部**那截
	if _精华球 != null:
		var 高 := int(球满高 * 比例)
		_精华球.visible = _精华展开 and 高 > 0
		if 高 > 0:
			_精华球.offset_top = 球顶 + (球满高 - float(高))
			_精华球.offset_bottom = 球顶 + 球满高
			var 球图 := AtlasTexture.new()
			球图.atlas = _精华球常态图()
			球图.region = Rect2(0.0, 球满高 - float(高), 108.0, float(高))
			_精华球.texture = 球图
	# 条：`MBar.setData:141` 把整幅 bar **左移** `int(81*(1-比例))`，透过固定窗口露出右边一截
	if _精华条 != null:
		var 移 := int(条满宽 * (1.0 - 比例))
		var 可见 := clampf(条满宽 - float(移), 条窗左, 条窗左 + 条窗宽) - 条窗左
		_精华条.visible = 可见 > 0.0
		if 可见 > 0.0:
			_精华条.offset_left = 条窗左
			_精华条.offset_right = 条窗左 + 可见
			var 条图 := AtlasTexture.new()
			条图.atlas = _精华条常态图()
			条图.region = Rect2(条窗左 + float(移), 条带上, 可见, 条带高)
			_精华条.texture = 条图
	if _精华条数值 != null:
		_精华条数值.text = "%d/%d" % [存量, 精华上限]
	# 提示框开着时数值要跟着涨（原版 `setData` 里每次都会刷 `toolTip.text`）
	if is_instance_valid(_精华提示) and _精华提示.visible:
		_精华提示.call("设置", 精华提示文本())

## 常态图只取一次：`_画精华()` 每次数值变化都要重算，别把 AtlasTexture 套娃（region 会越裁越小）。
var _球原图: Texture2D
var _条原图: Texture2D

func _精华球常态图() -> Texture2D:
	if _球原图 == null and _精华球 != null:
		_球原图 = _精华球.texture
	return _球原图

func _精华条常态图() -> Texture2D:
	if _条原图 == null and _精华条 != null:
		_条原图 = _精华条.texture
	return _条原图

## MButton3 一族三态：**只换 `texture_normal`**，不用 `texture_hover/pressed`（Godot 松手会回到
## hover，而原版 `MButton3.as:103-108` 松手回 STATE_UP）；也不用 material（会连子节点一起变亮）。
func _绑三态(钮: TextureButton) -> void:
	var 常态 := 钮.texture_normal
	if 常态 == null:
		return
	var 干 := String(常态.resource_path).get_basename()
	var 皮: Array = [常态, null, null]
	if ResourceLoader.exists("%s_悬停.png" % 干):
		皮[1] = load("%s_悬停.png" % 干) as Texture2D
	if ResourceLoader.exists("%s_按下.png" % 干):
		皮[2] = load("%s_按下.png" % 干) as Texture2D
	_态实例[钮] = {"皮": 皮}
	钮.mouse_entered.connect(_设态.bind(钮, 1))
	钮.mouse_exited.connect(_设态.bind(钮, 0))
	钮.button_down.connect(_设态.bind(钮, 2))
	钮.button_up.connect(_设态.bind(钮, 0))

func _设态(钮: TextureButton, 态: int) -> void:
	var 记 = _态实例.get(钮)
	if 记 == null:
		return
	var 皮: Array = (记 as Dictionary).get("皮", [])
	var 图: Texture2D = 皮[态] if 态 < 皮.size() else null
	if 图 != null:
		钮.texture_normal = 图


## ── 打坐时围着角色的四颗球（`ButtonsWindow`，#203）────────────────────────────
## 层栈与坐标（`ButtonsWindow.as:147-154` + `UIConfig.BORDER_GAP = 5` + `btn_width_two = 37`）：
##   `_btnPanel` 在 (5,5)，四枚 `ProgramButton` 相对它摆 (-90,-65)/(-70,-30)/(30,-30)/(50,-65)
##   ⇒ 窗口局部 = **(-85,-60) 双修 / (-65,-25) 心法 / (35,-25) 挂机 / (55,-60) 修行**。
##   钮的**命中框**是 `graphics.drawRect(0,0,_width,_height)` = 37×37，但 `ProgramButton` 重写的
##   `updateDisplayList()` **没有** `upSkin.width = _width` 那一行（`MButton3.as:653` 才有）
##   ⇒ 皮按**天然 43×37** 画、右边超出命中框 6px。所以场景里钮的矩形取 43×37（画面对、边距不欺人）。
## 文案与提示全部是原版语言表（`message` 包，3346 条）里的原句：
##   `SHUANG_XIU/XIN_FA/GUA_JI/XIU_XING` + `*_BTN_TIP`。
## ⚠ **心法那枚原版不挂提示**（`setToolTip()` 的 `case 1:` 是空的）⇒ 这里不许自作聪明补一句。
const 球表 := [["双修钮", "shuangxiu", "进入双人同时修炼状态，加快经验与查克拉精华获得速度"],
		["心法钮", "xinfa", ""],
		["挂机钮", "guaji_window", "进入线上自动挂机战斗状态，可获得大量打怪经验"],
		["修行钮", "lingqu", "领取你的修行收益：包括修行经验与修行查克拉精华"]]
## `HealHandler.as:199/208`：`player.localToGlobal(0,0)` 再 **y + 20**（Flash 的 y 向下 = 我们的 y 向下）。
const 球抬 := 20.0

var _四钮: Control = null
var _四钮钉住位 := Vector2.INF


func _setup_打坐四钮() -> void:
	_四钮 = get_node_or_null("打坐四钮") as Control
	if _四钮 == null:
		push_warning("技能面板：场景里没有「打坐四钮」这一族 ⇒ 打坐时身边不会有四颗球")
		return
	for 行 in 球表:
		var 钮 := _四钮.get_node_or_null(String(行[0])) as TextureButton
		if 钮 == null:
			push_warning("技能面板：打坐四钮缺 %s" % 行[0])
			continue
		_绑三态(钮)
		钮.pressed.connect(_球动作.bind(String(行[1])))


## 四颗球**只在打坐时出现**，并且**每帧跟着角色**（原版 `HealHandler.tick()` 里玩家坐标一变就
## `showButtonsWindow(x, y+20, true)`）。判据用 `玩家.is_practising` —— 它由服务端回帧
## （`healStateChange` → `set_practising`）和本地 `toggle_practise()` 两条路共同写，
## 不需要在这里再猜一次服务端状态。
func _刷新打坐四钮() -> void:
	if _四钮 == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	# ⚠ **不能用 `bool(...)`**：`bool(null)` 在 4.7.1 里不是合法构造（NIL→BOOL 没有构造器）⇒ 抛
	#   `Invalid call. Nonexistent 'bool' constructor`，而抛在这一行等于**整个刷新中断**：
	#   group 里是一枚没有 `is_practising` 的桩玩家时，四颗球每帧静默失灵
	#   （2026-10-22 全量门里 `那一排按钮回归测试` 每帧刷 229 次就是这个）。
	#   `== true` 对缺属性的桩直接得 false，语义正是"没在打坐"（同 :439 的 `get() != null` 口径）。
	#   ⚠ `:=` 在这儿推不出类型（右边带 Variant 比较）⇒ 必须显式写 `: bool`，否则整个脚本 parse 失败。
	var 坐: bool = _player != null and is_instance_valid(_player) and _player.get("is_practising") == true
	if not 坐:
		if _四钮.visible:
			_四钮.visible = false
			_四钮钉住位 = Vector2.INF
		return
	_四钮.visible = true
	var 屏 := get_viewport().get_canvas_transform() * (_player as Node2D).global_position
	屏.y += 球抬
	if 屏 != _四钮钉住位:
		_四钮钉住位 = 屏
		_四钮.position = 屏


func _球动作(身份: String) -> void:
	match 身份:
		"shuangxiu":
			# 原版 `onClickShuangxiuBtn()`（`ButtonsWindow.as:167-172`）：先把上一轮那对窗关掉，
			# 再派发 `DAKAI_SHUANGXIU_WINDOW` → `UI.as:1236` 只发一发 `1282:4:2`（搜同屏玩家）⇒
			# **开窗的是回帧**（`Client.as:5003-5011`：`ShuangxiuWindow` + `SelectPlayerWindowInShuangxiuWindow`
			# 两扇成对）。落点在 `窗口管理.打开或收起("双修")` → `双修成对窗.点球`。
			# ⚠ 被邀请那一侧弹的是另一扇 `YaoqingShuangxiuWindow`（`1288:2` 那帧开的，已做）。
			if _session != null:
				_session.request_feature("双修")
		"xinfa":
			if _session != null:
				_session.request_feature("心法")
		"guaji_window":
			if _session != null:
				_session.request_feature("挂机")
		"lingqu":
			if _session != null:
				_session.request_feature("领取修行收益")

func _on_stats_changed(stats: Dictionary) -> void:
	_画精华()		# 精华存量变了：两版都要重画（`MenuPane.setBreath` 也是两版都喂）
	if _experience_fill == null or _experience_fill.material == null:
		return
	var maximum := maxf(1.0, float(stats.get("max_exp", 100)))
	var progress := clampf(float(stats.get("exp", 0)) / maximum, 0.0, 1.0)
	_experience_fill.material.set_shader_parameter("progress", progress)
	_experience_fill.tooltip_text = "经验 %d / %d" % [int(stats.get("exp", 0)), int(maximum)]

func _on_skill_cooldown_changed(slot: int, remaining: float, duration: float) -> void:
	if slot < 0 or slot >= _cooldown_overlays.size():
		return
	var cooling := remaining > 0.01
	_cooldown_overlays[slot].visible = cooling
	## 原版 `GirdCool.draw():56` 的角度 = **已消耗 / 总时长** × 360（不是剩余/总），
	## 刚放完 = 0 ⇒ 整格黑；转到 360° ⇒ `destroy()`（`MCell.showCoolDown:107-110` 里
	## 剩余 ≤ 0 就直接 `removeCoolDown()`）。所以这里喂的是"已经转掉多少"。
	var 总 := maxf(duration, 0.001)
	_冷却材质[slot].set_shader_parameter("progress", clampf((总 - remaining) / 总, 0.0, 1.0))
	# 整格灰度（原版给 `cellBg` 挂 `Style.getDisableFilter()`）：图标换去色副本、
	# 黄标号换成同一套矩阵算出来的灰。底板本身就是灰的（差 <5），不折腾。
	var 图标 := _shortcut_icons[slot]
	if 图标 != null and slot < _图标原皮.size():
		var 原皮 := _图标原皮[slot]
		图标.texture = 取灰度副本(原皮) if cooling else 原皮
	if slot < _标号件.size():
		_标号件[slot].add_theme_color_override("font_color", 标号灰色() if cooling else 标号色)
	if slot < _shortcut_buttons.size():
		_shortcut_buttons[slot].disabled = cooling

func _slot_from_key(keycode: Key) -> int:
	match keycode:
		KEY_1: return 0
		KEY_2: return 1
		KEY_3: return 2
		KEY_4: return 3
		KEY_5: return 4
		KEY_6: return 5
		KEY_7: return 6
		KEY_8: return 7
		KEY_9: return 8
		KEY_0: return 9
	return -1

func _slot_key_text(slot: int) -> String:
	return "0" if slot == 9 else str(slot + 1)
