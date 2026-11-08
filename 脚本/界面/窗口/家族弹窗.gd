extends RefCounted
## 家族弹窗族 = 原版 `FamillyPopUpWindow`（`com/mxw/uifl/controls/familly/FamillyPopUpWindow.as`）。
##
## ⚠ **这一族不是 `MDialog`**，两族几何完全不同，别互相套：
##
## | | `MDialog`（`输入确认弹.弹消息/弹勾选/弹出`） | `FamillyPopUpWindow`（这一份） |
## |---|---|---|
## | 底板 | `bg2` 小窗口边框，宽恒 302 | `FamillyPopupWindowSkin` **原生 216×134**（`:113-114`），`windowWidth` 才改宽 |
## | 正文 | `createTextArea` ⇒ (14,14)、宽 267、`setMessage:411` 高 = textHeight+8 | `TextArea2` ⇒ **(5,25)**、宽 = 底宽−12、`:178` 高 = textHeight+pad+pad+6 |
## | 撑高 | `panelHeight = 勾选底 + BOTTOM_HEIGHT(50)` | **区高严格大于 51 才撑**：`底高 = 25 + 区高 + 43`，否则停原生 134（`:186-188`） |
## | 暗层 | 恒有，alpha 0.5 | `centerWindow` 第 2 参 = `popUpWindow` 第 7 参 `modal` ⇒ **false 就没有暗层、也不拦点击**（`:74-115`） |
## | 藏取消 | 没有这一档 | 两条：`hideCancelButton:164-168`（藏掉**并把确定搬到正中**）与 `ItemWindow2.as:411` 那种**直接** `visible=false`（确定仍钉 x=35） |
##
## 10-24 的起因：竞技场「本期排名奖励获得」那枚（`PvpManager.as:98-103` 走的正是这一族）被接在
## `MDialog` 的勾选型上、而且正文盒写死一行 ⇒ 三行文案被面板底边裁掉（用户实机报的第四条）。
## 这一族的算式只留这一份，`输入确认弹.弹单钮/弹双钮` 与 `购买VIP确认弹` 都从这里取。

const 底原生宽 := 216.0				# `:113-114` 皮肤原生宽；不调 `windowWidth` 就停这个数
const 底原生高 := 134.0				# `:113-114`
const 正文位 := Vector2(5.0, 25.0)			# `:123 setPosition(5,25)`
const 内边距 := 8.0					# `:122` 四边 = `UIConfig.CONTENT_GAP`
const 最低文本高 := 51.0				# `:20 MIN_TEXT_HEIGHT`（`:186` 是**严格大于**）
const 文本行高 := 15.0				# Flash 宋体 12px 行盒（同 `输入确认弹` 的口径）
const 文本额外 := 6.0				# `:178` 那个 `+ 6`
const 撑高隙 := 43.0				# `:188 正文.y + 区高 + 43`
const 勾选隙 := 10.0				# `:183 勾选.y = 正文.y + 区高 + 10`
const 勾选加高 := 30.0				# `:184 _loc1_ += 30`（有勾选才加，加完再去比 51）
const 钮高 := 22.0
const 钮底隙 := 12.0				# `:190 底高 − 钮高 − 12`
const 确定隙 := 35.0				# `:135 _okBtn.x = 35`
const 取消隙 := 35.0				# `:141/:192 底宽 − 钮宽 − 35`
const 钮文字宽 := 12.0				# 一个汉字
const 钮左右隙 := 6.0				# `isScale9Grid` ⇒ 钮宽 = 文字宽 + 6
const 九宫边 := 9.0				# `弹窗底.png` 圆角占 9px（alpha 探针，同 `购买VIP确认弹`）
const 字号 := 12
const 行距 := 2					# Godot `line_separation` = 原版 leading(4) 折到这套字体的差（同 `家族确认弹.tscn`）
const 正文字色 := Color(1, 1, 1, 1)		# `TextArea2(param1 = 0xFFFFFF)` 默认白（`:22`）
const 皮路径 := "res://素材/界面/原版窗口/家族/弹窗底.png"
const 钮皮路径 := "res://素材/界面/原版窗口/家族/钮底61.png"
## 挂进宿主遮罩的那一层要带这一枚标记 —— `功能窗口.有浮层()` 认它（键名必须 ASCII，中文键静默丢）。
const 浮层标记 := "overlay_popup"


## htmlText → BBCode（`<br/>`→换行、`<font color=…>`→`[color=…]`）。整族共用这一份。
static func 文案转BBCode(文: String) -> String:
	for 旧 in [["<br/>", "\n"], ["<br>", "\n"], ["<font color='", "[color="],
			['<font color="', "[color="], ["'>", "]"], ['">', "]"], ["</font>", "[/color]"]]:
		文 = 文.replace(String(旧[0]), String(旧[1]))
	return 文


## 正文实际占几行。拿不到字体时**退回数换行符** —— 别让一次量不到把整枚弹退回一行。
static func 量行数(标: RichTextLabel, 折行宽: float) -> int:
	var 估 := func() -> int: return maxi(1, 标.get_parsed_text().count("\n") + 1)
	var 字体 := 标.get_theme_font("normal_font")
	if 字体 == null:
		return 估.call()
	var 单行 := 字体.get_height(字号)
	if 单行 <= 0.0:
		return 估.call()
	var 量 := 字体.get_multiline_string_size(标.get_parsed_text(),
			HORIZONTAL_ALIGNMENT_LEFT, 折行宽, 字号)
	return maxi(1, int(round(量.y / 单行)))


## `:178-188` 那一段摊开。`区高` = 15·行数 + 8 + 8 + 6（有勾选再 `+= 30`）；
## 底高只在区高**严格大于** 51 时才撑，否则停原生 134。`勾选Y` 用的是**加 30 之前**的那份（`:183`）。
static func 量(行数: int, 有勾选: bool) -> Dictionary:
	var 文本区高 := 文本行高 * maxf(1.0, float(行数)) + 内边距 * 2.0 + 文本额外
	var 出 := {"文本区高": 文本区高, "勾选Y": 正文位.y + 文本区高 + 勾选隙}
	var 区高: float = float(文本区高) + (勾选加高 if 有勾选 else 0.0)
	出["区高"] = 区高
	出["底高"] = 底原生高 if 区高 <= 最低文本高 else 正文位.y + 区高 + 撑高隙
	return 出


static func 钮宽(文字: String) -> float:
	return 钮文字宽 * float(文字.length()) + 钮左右隙


## 「行数 + 底宽 + 有没有勾选 + 取消怎么处理」→ 各件矩形。几何门直接读这张表。
## `居中确定` = 走 `hideCancelButton()`；false = 确定钉在 `x = 35`。
static func 布局(行数: int, 宽: float = 底原生宽, 有勾选: bool = false,
		居中确定: bool = false, 钮一文字: String = "确定", 钮二文字: String = "取消") -> Dictionary:
	var 量出 := 量(行数, 有勾选)
	var 高: float = float(量出.get("底高"))
	var 一宽 := 钮宽(钮一文字)
	var 二宽 := 钮宽(钮二文字)
	var 钮Y := 高 - 钮高 - 钮底隙
	var 一X := 确定隙						# `:135` 不居中那一支
	if 居中确定:
		一X = floorf((宽 - 一宽) / 2.0)		# `hideCancelButton:167 (背景宽 − 钮宽)/2`
	var 出 := {
		"底": [0.0, 0.0, 宽, 高],
		"正文": [正文位.x, 正文位.y, 宽 - 12.0, float(量出.get("区高"))],
		"确定": [一X, 钮Y, 一宽, 钮高],
		"取消": [宽 - 二宽 - 取消隙, 钮Y, 二宽, 钮高],
		"底高": 高,
	}
	if 有勾选:
		出["勾选"] = [0.0, float(量出.get("勾选Y")), 宽, 27.0]
	return 出


## 一颗 `MButtonF`（`钮底61` 那族，文字居中、不吃主题皮）。
static func 钮(节点名: String, 文字: String, 位: Vector2, 宽: float) -> TextureButton:
	var 钮 := TextureButton.new()
	钮.name = 节点名
	钮.texture_normal = load(钮皮路径) as Texture2D
	钮.ignore_texture_size = true
	钮.stretch_mode = TextureButton.STRETCH_SCALE
	钮.custom_minimum_size = Vector2.ZERO
	钮.position = 位
	钮.size = Vector2(宽, 钮高)
	钮.focus_mode = Control.FOCUS_NONE
	var 字 := Label.new()
	字.name = "Label"
	字.text = 文字
	字.set_anchors_preset(Control.PRESET_FULL_RECT)
	字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	字.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	字.add_theme_font_size_override("font_size", 字号)
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	钮.add_child(字)
	return 钮


## 建一扇家族弹窗并挂进 `遮罩`。`钮二文字` 给空串 ⇒ 走 `hideCancelButton()`（藏掉取消**并把确定搬到正中**）；
## 非空 ⇒ 两颗都在。`模态` = `popUpWindow` 第 7 参：false ⇒ 不建暗层、整层 `MOUSE_FILTER_IGNORE`
## （原版 `centerWindow:74-115` 那个 `if(param2)` 不成立时连遮罩 Sprite 都不加，点击照穿）。
## 点钮 = `clickOkBtnHandler:60-73` / `clickCancelBtnHandler:95-108`：**先回调、后 `destroy()`**。
static func 弹出(遮罩: Control, 节点名: String, 正文: String, 勾选文案: String,
		初值: bool, 钮一文字: String, 钮二文字: String,
		钮一回调: Callable, 钮二回调: Callable, 模态: bool,
		宽: float = 底原生宽, 文字色: Color = 正文字色) -> Control:
	var 有勾选 := 勾选文案 != ""
	var 层 := Control.new()
	层.name = 节点名
	层.set_meta("mdialog", "family")
	层.set_meta(浮层标记, true)
	层.set_anchors_preset(Control.PRESET_FULL_RECT)
	层.mouse_filter = Control.MOUSE_FILTER_STOP if 模态 else Control.MOUSE_FILTER_IGNORE
	层.z_index = 100
	if 模态:
		var 暗 := ColorRect.new()
		暗.name = "暗层"
		暗.set_anchors_preset(Control.PRESET_FULL_RECT)
		暗.color = Color(0, 0, 0, 0.3)		# `PopUpMananger.as:58` 的 param4 默认 0.3
		层.add_child(暗)
	var 主 := Control.new()
	主.name = "主体"
	主.mouse_filter = Control.MOUSE_FILTER_IGNORE
	层.add_child(主)
	var 底 := Panel.new()
	底.name = "底"
	var 皮 := StyleBoxTexture.new()
	皮.texture = load(皮路径) as Texture2D
	for 边 in ["left", "right", "top", "bottom"]:
		皮.set("texture_margin_" + String(边), 九宫边)
	底.add_theme_stylebox_override("panel", 皮)
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	主.add_child(底)
	var 正文件 := RichTextLabel.new()
	正文件.name = "正文"
	正文件.bbcode_enabled = true
	正文件.scroll_active = false
	正文件.position = 正文位
	## `:122` 四边 padding = `CONTENT_GAP(8)` ⇒ 外盒 (5,25,底宽−12,区高)，**字从 (13,33) 起、
	## 折行宽 = 底宽−12−16**。Godot 这边对等的就是这四条 text margin（`购买VIP确认弹` 当年把
	## 外盒当字盒用 ⇒ 字往左顶了 8 像素，这一份按 AS3 摆）。
	for 边 in ["left", "right", "top", "bottom"]:
		正文件.set("text_margin_" + String(边), 内边距)
	正文件.add_theme_constant_override("line_separation", 行距)
	正文件.add_theme_font_size_override("normal_font_size", 字号)
	正文件.add_theme_color_override("default_color", 文字色)
	正文件.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## 原版 `TextArea2 extends Box` 只画一层滚动遮罩（`Box.as:270-273` 那条 lime 50% 的 mask），
	## **没有底板**。10-24 这里曾用 `StyleBoxEmpty.new()` 覆盖 `normal`；10-30 实测
	## `原版主题.tres` **根本没有** `RichTextLabel/styles/normal`，解算结果本来就是引擎默认的
	## `StyleBoxEmpty`（探针 `_tmp/probe_rtl_normal.gd`）⇒ 那行是空操作，还撞 `UI资源回归测试`
	## 的「覆盖里现造 StyleBox 会压过全局主题」守卫 ⇒ 删除。将来若真出现底板，样式要进
	## `原版皮肤表.gd` 的 `RichTextLabel` 段，别在调用点现造。
	正文件.text = 文案转BBCode(正文)
	主.add_child(正文件)
	var 勾: CheckBox = null
	if 有勾选:
		勾 = CheckBox.new()
		勾.name = "勾选"
		勾.text = 勾选文案
		勾.button_pressed = 初值			# `:94 checkBox.selected = isSelected`
		勾.focus_mode = Control.FOCUS_NONE
		主.add_child(勾)
	# 行数要等文本进了树、拿到主题字体才量得准 ⇒ 先建件、再量、再按 `updateDisplayList` 摆。
	var 折行宽 := 宽 - 12.0 - 内边距 * 2.0
	var 表 := 布局(量行数(正文件, 折行宽), 宽, 有勾选, 钮二文字 == "", 钮一文字,
			钮二文字 if 钮二文字 != "" else "取消")
	var 高: float = float(表.get("底高"))
	正文件.size = Vector2(float((表.get("正文") as Array)[2]), float((表.get("正文") as Array)[3]))
	主.size = Vector2(宽, 高)
	底.size = Vector2(宽, 高)
	## `PopUpMananger.positionWindwo:126-145` 是相对**舞台**（`Config.STAGE_WIDTH/HEIGHT`）居中
	## ⇒ 这边按 `遮罩` 的尺寸算。两个调用方给的都是一层已经排过版的整屏层
	## （`功能窗口._overlay` / `竞技场窗._全局浮层` 的「舞台」），10-24 实测同帧就是 960×560，
	## 所以这里**不留"size 为 0 就拿视口兜底"那一支** —— 那条分支在这两个入口上永不触发
	## （变异实测：把它去掉，居中那条判据照样量到 (372,212)）。真凶是层号，见 `竞技场窗._全局浮层`。
	主.position = Vector2(floorf((遮罩.size.x - 宽) * 0.5), floorf((遮罩.size.y - 高) * 0.5))
	if 勾 != null:
		勾.size = Vector2(宽, 27.0)
		勾.position = Vector2(0.0, float((表.get("勾选") as Array)[1]))
		勾.mouse_filter = Control.MOUSE_FILTER_STOP
	var 收 := func() -> void: 层.queue_free()
	var 确定 := 钮("确定", 钮一文字, Vector2((表.get("确定") as Array)[0], (表.get("确定") as Array)[1]),
			float((表.get("确定") as Array)[2]))
	主.add_child(确定)
	if 钮一回调.is_valid():
		确定.pressed.connect(func() -> void:
			钮一回调.call()
			收.call())
	else:
		确定.pressed.connect(收)				# `okFun == null` ⇒ `clickOkBtnHandler` 只剩 `destroy()`
	var 取消 := 钮("取消", 钮二文字 if 钮二文字 != "" else "取消",
			Vector2((表.get("取消") as Array)[0], (表.get("取消") as Array)[1]),
			float((表.get("取消") as Array)[2]))
	取消.visible = 钮二文字 != ""
	主.add_child(取消)
	if 钮二回调.is_valid():
		取消.pressed.connect(func() -> void:
			钮二回调.call()
			收.call())
	遮罩.add_child(层)
	return 层
