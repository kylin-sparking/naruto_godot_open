extends Control

## 原版「宠物技能重置」选择窗 —— `PetSkillSelectWindow.as`（444×423）。
##
## 由 `宠物技能替换窗` 的「查阅」打开；点某行的「选择」把技能号交回替换窗。
## 候选 = `数据/宠物技能.json` 全部 33 条 **减去尾兽四条**：原版
## `PetSkillSelectWindow.setSkills` 遍历 `ImgUtil.getImg(ImgType.Skill, "PetSkill")`
## 后按 `PetManager.isWeiShouSkill` 过滤，`PetManager.skills = [123,124,125,126]`。
##
## 行版式出自 `PetSkillItemRenderer.createView`（坐标是**行局部**）：
##   格 40×40 @ (13,8)、图标 34×34 @ (3,3)、富文本 (68,4) 290×50、
##   「选择」钮 37×22 @ (363,(57−22)/2)、分隔线 408×2 @ y=57。
## 文案颜色逐字照 AS3：技能名 `#1e90ff`、主动/被动 `#ffffff`、
## 推荐 `#00ff00`、说明 `#ffffff`；主动/被动读 `info.desc.skillType == 0`，
## 推荐按 `id <= 200` 分出战/附身（`SkillDataTool.isAttackPetSkill:471-478`）。

signal 选中技能(技能号: int)
signal 关闭了

const 界面皮肤 := preload("res://脚本/界面/窗口/界面皮肤.gd")
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

const 关闭钮皮 := "res://素材/界面/原版窗口/通用控件/关闭按钮.png"
const 分隔线皮 := "res://素材/界面/原版窗口/通用控件/横向分隔线.png"
const 格底图 := preload("res://素材/界面/原版窗口/通用控件/物品格.png")

const 窗宽 := 444.0
const 窗高 := 423.0
const 内容位 := Vector2(8.0, 38.0)		# `UIWindow`: x = CONTENT_GAP、y = 38
const 内容宽 := 428.0				# 窗宽 − CONTENT_GAP·2
const 内容高 := 355.0				# 窗高 − 68
const 列表位 := Vector2(12.0, 42.0)		# `_contentBg.x/y + 4`
const 列表宽 := 418.0				# `_contentBg.width − 10`
const 列表高 := 343.0				# `_contentBg.height − 12`
const 行宽 := 408.0
const 行高 := 60.0				# `list.rowHeight = 60`
const 格位 := Vector2(13.0, 8.0)
const 格尺寸 := 40.0
const 文字位 := Vector2(68.0, 4.0)
const 文字尺寸 := Vector2(290.0, 50.0)
const 钮宽 := 37.0				# `UIConfig.btn_width_two`
const 钮高 := 22.0
const 钮位 := Vector2(363.0, 17.5)		# `x = 文字.x + 295`、`y = (57 − 高) / 2`
const 分隔y := 57.0
const 关闭钮宽 := 25.0
const 关闭钮高 := 24.0

## `PetManager.as:40-48 isWeiShouSkill` 的名单（同 `PetManager.skills`）。
const 尾兽技能 := [123, 124, 125, 126]

const 窗口标题 := "宠物技能重置"		# `CN.PETSKILLSELECTWINDOW_TITLE`
const 选择字 := "选择"			# `CN.PEISKILLITEMRENDERER_XUAN_ZHE`

static var _空样式: StyleBoxEmpty = null

var _列表: VBoxContainer


## 一行的说明文字（`PetSkillItemRenderer.data` 的拼接串，只把 `<font>` 换成 BBCode）。
static func 说明(技号: int) -> String:
	var 记 := 游戏数据.pet_skill(技号)
	var 信息: Dictionary = 记.get("info", {}) as Dictionary
	var 描述: Dictionary = 信息.get("desc", {}) as Dictionary
	var 主动 := int(描述.get("skillType", 1)) == 0
	var 类型 := "【主动技能】" if 主动 else "【被动技能】"
	var 推荐 := "【推荐出战宠物学习】" if 技号 <= 200 else "【推荐附身宠物学习】"
	return "[color=#1e90ff]%s [/color][color=#ffffff]%s [/color][color=#00ff00]%s [/color]\n[color=#ffffff]%s[/color]" % [
		String(记.get("name", "宠物技能 %d" % 技号)), 类型, 推荐, String(记.get("desc", ""))]


static func 候选技能() -> Array[int]:
	var 出: Array[int] = []
	for 号 in 游戏数据.pet_skill_ids():
		if not 尾兽技能.has(号):
			出.append(号)
	return 出


static func _技能图标(技号: int) -> Texture2D:
	var 路径 := 游戏数据.skill_icon_path({"icon_class": "Skill_PetSkill_%d_icon" % 技号})
	if 路径.is_empty() or not ResourceLoader.exists(路径):
		return null
	return load(路径) as Texture2D


static func _空(): 
	if _空样式 == null:
		_空样式 = StyleBoxEmpty.new()
	return _空样式


func 打开() -> void:
	_重建()
	visible = true


func _重建() -> void:
	for 子 in get_children():
		子.free()
	size = Vector2(窗宽, 窗高)

	var 框 := Panel.new()
	框.name = "框"
	框.position = Vector2.ZERO
	框.size = size
	框.mouse_filter = Control.MOUSE_FILTER_IGNORE
	框.theme_type_variation = 皮肤表.变体_窗口边框
	add_child(框)

	var 标 := Label.new()
	标.name = "标题"
	标.text = 窗口标题
	标.position = Vector2(0.0, 5.0)
	标.size = Vector2(窗宽, 18.0)
	标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	标.theme_type_variation = 皮肤表.变体_窗口标题
	add_child(标)

	var 关 := Button.new()
	关.name = "关闭"
	关.position = Vector2(窗宽 - 关闭钮宽 - 6.0, 6.0)
	关.size = Vector2(关闭钮宽, 关闭钮高)
	关.focus_mode = Control.FOCUS_NONE
	关.flat = true
	关.icon = load(关闭钮皮) as Texture2D if ResourceLoader.exists(关闭钮皮) else null
	关.pressed.connect(隐藏)
	add_child(关)

	var 黄底 := Panel.new()
	黄底.name = "黄底"
	黄底.position = 内容位
	黄底.size = Vector2(内容宽, 内容高)
	黄底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	黄底.theme_type_variation = 皮肤表.变体_内容面板
	add_child(黄底)

	var 滚 := ScrollContainer.new()
	滚.name = "列表"
	滚.position = 列表位
	滚.size = Vector2(列表宽, 列表高)
	滚.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	滚.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	滚.clip_contents = true
	add_child(滚)

	_列表 = VBoxContainer.new()
	_列表.name = "行容器"
	_列表.custom_minimum_size = Vector2(行宽, 0.0)
	_列表.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_列表.add_theme_constant_override("separation", 0)
	滚.add_child(_列表)
	for 技号 in 候选技能():
		_建行(技号)


func _建行(技号: int) -> void:
	var 行 := Control.new()
	行.name = "行_%d" % 技号
	行.custom_minimum_size = Vector2(行宽, 行高)
	行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_列表.add_child(行)

	var 底 := TextureRect.new()
	底.name = "底"
	底.texture = 格底图
	底.position = 格位
	底.size = Vector2(格尺寸, 格尺寸)
	底.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	行.add_child(底)

	var 图 := TextureRect.new()
	图.name = "图标"
	图.texture = _技能图标(技号)
	图.position = 格位 + Vector2(3.0, 3.0)
	图.size = Vector2(34.0, 34.0)
	图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	行.add_child(图)

	var 文 := RichTextLabel.new()
	文.name = "说明"
	文.bbcode_enabled = true
	文.scroll_active = false
	文.fit_content = false
	文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	文.position = 文字位
	文.size = 文字尺寸
	文.mouse_filter = Control.MOUSE_FILTER_IGNORE
	文.add_theme_font_size_override("normal_font_size", 12)
	文.add_theme_constant_override("line_separation", 2)
	文.text = 说明(技号)
	行.add_child(文)

	var 钮 := Button.new()
	钮.name = "选择"
	钮.text = 选择字
	钮.position = 钮位
	界面皮肤.configure_standard_button(钮, Vector2(钮宽, 钮高))
	钮.pressed.connect(_点选择.bind(技号))
	行.add_child(钮)

	var 线 := TextureRect.new()
	线.name = "分隔线"
	线.texture = load(分隔线皮) as Texture2D if ResourceLoader.exists(分隔线皮) else null
	线.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	线.mouse_filter = Control.MOUSE_FILTER_IGNORE
	线.position = Vector2(0.0, 分隔y)
	线.size = Vector2(行宽, 2.0)
	行.add_child(线)


## `PetSkillSelectWindow.selectedSkillHandler:64-72` 只调 `setResetSkill`，**不关窗** ——
## 选完还能接着换，要退出得自己点关闭。
func _点选择(技号: int) -> void:
	选中技能.emit(技号)


func 隐藏() -> void:
	if not visible:
		return
	visible = false
	关闭了.emit()
