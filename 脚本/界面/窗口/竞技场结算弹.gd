extends RefCounted

## 竞技场结算弹层 = 原版 `PvpResultWindow`（底板 `FamillyPopupWindowSkin` 拉成 **545×220**）。
## 由 `2306:7:<1|0>:<阅历>` 触发（`PvpManager.onPk_showBattlePrize:458-463`
## → `setDOShow(PVP_RESULT_WINDOW,true)` + `onResult(胜, 阅历)`）。
##
## 版式全部照 AS3 字面（`PvpResultWindow.as:36-83`）：
##   底板 545×220（`:39-40`；原生 216×134 ⇒ 必须九宫，否则圆角糊成梯形）
##   文字 `MGlowLabel` `(0,120)`、宽 = 底板宽、居中、`adjustContent=false`（`:42-47`）
##   确定 `MButtonF` `x = (545−w)/2`、`y = 220−h−12`（`:48-52`），点它 = `onCloseBtnClick` ⇒ 关这扇
##   脸 `updateLayout:30-34`：`x = (545−205)/2`、**`y = 文字.y − 脸高 − 4 = 120−204−4 = −88`**
##     ⇒ 原版算式给的就是"脸上半截探到框外面、下缘压在文字上方 4px"（`UISwf_PvpUI_ShengLi`
##     实测 205×204、墨迹铺满画布 ⇒ 从导出图看不出注册点，只能照算式摆，别自作主张挪进框内）。
##
## ★ **为什么不挂进某一扇窗的 `遮罩`**：进战斗那一拍 `onStartPk:232-234` 把所有窗都关了，
##   结算帧是**打完之后**才来的 ⇒ 挂在被关掉的宿主里 = 玩家什么都看不见。
##   原版这扇是 `windowMap` 里独立的一扇（自己 `setDOShow`），所以这边给它**自己一层 CanvasLayer**，
##   层号 400 稳在一切之上（头像面板 300、聊天/技能 100、窗口 = `窗口管理.HUD基`110 + 序号）。
##
## ★ **同一时刻只留一枚**（`当前`）：原版 `setDOShow` 是对同一个实例置显隐。每来一帧就叠一层的话，
##   玩家关掉看得见的那枚之后，剩下的暗层继续吃点击（1079 弹两枚那次就是这么卡的）。

const 底宽 := 545.0				# `:39`
const 底高 := 220.0				# `:40`
const 九宫边 := 9.0				# 与 `购买VIP确认弹` 同一张皮的实测圆角占位
const 文字位 := Vector2(0.0, 120.0)		# `:44`
const 钮宽 := 61.0				# 钮底61 那一档
const 钮高 := 22.0
const 钮底隙 := 12.0				# `:51` `background.height − _okBtn.height − 12`
const 脸宽 := 205.0				# ffdec 实测 `UISwf_PvpUI_ShengLi` / `_ShiBai`
const 脸高 := 204.0
const 脸隙 := 4.0				# `:33` `− _title.height − 4`
const 关钮宽 := 25.0
const 关钮高 := 24.0
const 关钮边 := 7.0				# 家族弹窗那一族的 X 位（同 `购买VIP确认弹`）
const 白 := Color(1, 1, 1)
const 绿 := Color(0, 1, 0)			# `:82` 那个 `<font color='#00ff00'>`
const 暗色 := Color(0, 0, 0, 0.5)
const 层号 := 400

static var 当前: CanvasLayer = null


## `生命` = 当前地图的 `LifeRoot`（挂在它上面 ⇒ 换图自动跟着销毁，不留残影）。
static func 弹出(生命: Node, 胜: bool, 阅历: int) -> CanvasLayer:
	if 生命 == null or not is_instance_valid(生命) or 生命.get_parent() == null:
		return null
	收起()
	var 层 := CanvasLayer.new()
	层.name = "竞技场结算层"
	层.layer = 层号
	生命.get_parent().add_child(层)
	var 遮罩层 := Control.new()
	遮罩层.name = "竞技场结算"
	遮罩层.set_anchors_preset(Control.PRESET_FULL_RECT)
	遮罩层.mouse_filter = Control.MOUSE_FILTER_STOP
	层.add_child(遮罩层)
	var 暗 := ColorRect.new()
	暗.name = "暗层"
	暗.set_anchors_preset(Control.PRESET_FULL_RECT)
	暗.color = 暗色
	## ⚠ 暗层**不绑关闭**：原版点遮罩不关这扇（只有那颗「确定」= `onCloseBtnClick`）。
	暗.mouse_filter = Control.MOUSE_FILTER_STOP
	遮罩层.add_child(暗)
	var 主体 := Control.new()
	主体.name = "主体"
	主体.size = Vector2(底宽, 底高)
	主体.position = Vector2(floorf((遮罩层.size.x - 底宽) / 2.0), floorf((遮罩层.size.y - 底高) / 2.0))
	遮罩层.add_child(主体)
	主体.add_child(_底())
	主体.add_child(_脸(胜))
	主体.add_child(_文字(阅历))
	主体.add_child(_确定())
	主体.add_child(_关钮())
	当前 = 层
	return 层


static func 收起() -> void:
	if is_instance_valid(当前):
		## ★ **先脱树、再 queue_free**：只 `queue_free` 的话这一帧结束才真销毁，
		## 而"再来一帧换内容"（`setDOShow` 对同一个实例置显隐）走的就是 收起→新建 这条路 ⇒
		## 旧那一枚还挂在地图根上，量具按名字数就会数出两枚、并且拿到的是**旧的那枚**（脸还是笑脸）。
		## 不能直接 `free()`：这颗层里的按钮正在发 `pressed`，当场释放 = 释放信号的发出者。
		var 旧 := 当前
		当前 = null
		if 旧.get_parent() != null:
			旧.get_parent().remove_child(旧)
		旧.queue_free()
	当前 = null


static func _底() -> Control:
	var 底 := Panel.new()
	底.name = "底"
	var 皮 := StyleBoxTexture.new()
	皮.texture = load("res://素材/界面/原版窗口/家族/弹窗底.png") as Texture2D
	for 边 in ["left", "right", "top", "bottom"]:
		皮.set("texture_margin_" + String(边), 九宫边)
	底.add_theme_stylebox_override("panel", 皮)
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	底.size = Vector2(底宽, 底高)
	return 底


static func _脸(胜: bool) -> TextureRect:
	var 脸 := TextureRect.new()
	脸.name = "脸"
	脸.mouse_filter = Control.MOUSE_FILTER_IGNORE
	脸.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	脸.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	脸.texture = load("res://素材/界面/原版窗口/竞技场/UISwf_PvpUI_%s.png" % ("ShengLi" if 胜 else "ShiBai")) as Texture2D
	脸.position = Vector2(floorf((底宽 - 脸宽) / 2.0), floorf(文字位.y - 脸高 - 脸隙))
	脸.size = Vector2(脸宽, 脸高)
	return 脸


## `:82` `CN.replaceString(LangUtil.get("PVP_JIANGLI"), "<font color='#00ff00'>" + 阅历 + "</font>")`
## ⇒ 模板「奖励：阅历 %1」（message 包现查），替进去那一段是绿字。
static func _文字(阅历: int) -> Control:
	var 文 := RichTextLabel.new()
	文.name = "文字"
	文.bbcode_enabled = true
	文.scroll_active = false
	文.mouse_filter = Control.MOUSE_FILTER_IGNORE
	文.position = 文字位
	文.size = Vector2(底宽, 20.0)
	文.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	文.add_theme_font_size_override("normal_font_size", 12)
	文.add_theme_color_override("default_color", 白)
	文.add_theme_constant_override("line_separation", 2)
	文.text = "奖励：阅历 [color=#%s]%d[/color]" % [绿.to_html(false), 阅历]
	return 文


static func _确定() -> Control:
	var 钮 := TextureButton.new()
	钮.name = "确定钮"
	钮.ignore_texture_size = true
	钮.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	钮.texture_normal = load("res://素材/界面/原版窗口/家族/钮底61.png") as Texture2D
	钮.texture_hover = load("res://素材/界面/原版窗口/家族/钮底61_悬停.png") as Texture2D
	钮.texture_pressed = load("res://素材/界面/原版窗口/家族/钮底61_按下.png") as Texture2D
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.size = Vector2(钮宽, 钮高)
	钮.position = Vector2(floorf((底宽 - 钮宽) / 2.0), 底高 - 钮高 - 钮底隙)
	钮.pressed.connect(收起)
	var 字 := Label.new()
	字.name = "文字"
	字.text = "确定"						# `COMMON_OK`
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	字.set_anchors_preset(Control.PRESET_FULL_RECT)
	字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	字.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	字.add_theme_font_size_override("font_size", 12)
	字.add_theme_color_override("font_color", 白)
	钮.add_child(字)
	return 钮


## 原版这扇是 `MWindow` 且没关右上角那颗 X（`isDrag = true` 也照旧）⇒ 这边同样给一枚。
static func _关钮() -> Control:
	var 钮 := TextureButton.new()
	钮.name = "关钮"
	钮.ignore_texture_size = true
	钮.texture_normal = load("res://素材/界面/原版窗口/通用控件/关闭按钮.png") as Texture2D
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.position = Vector2(底宽 - 关钮宽 - 关钮边, 2.0)
	钮.size = Vector2(关钮宽, 关钮高)
	钮.pressed.connect(收起)
	return 钮
