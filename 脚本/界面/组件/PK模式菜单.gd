extends RefCounted

## 头像下那颗模式钮点开的四行菜单 = 原版 `PKModePane2`
## （`com/mxw/uifl/controls/PKModePane2.as:66-101` 建层 + `:112-160` 的 `PkItem`）。
## 逐句对照的层栈与几何（Flash `addChild` 顺序，全部按行号搬，不自己排版）：
##   黄底 `MYellow_background`(元件 **10**，天然 263×252) 整幅非等比拉到 **390×106**（`:68-71`）
##   四行 `PkItem` 依次摆 x=5、y=5/30/55/80（`:73-90`：每行高 = 钮高 23 + 线高 2 = 25）
##     行内：钮(元件 760/744/748/756，天然 23×23，摆 (0,0)) → 说明字(MGlowLabel 组件摆
##     (钮宽, 0) = (23,0)、宽 = 390−10−23−3 = 354；**组件内 TextField 再往下 2**（`MLabel.as:212`）
##     + Flash 文本框 2px 内边距 ⇒ 墨迹顶在行内 y=4，见 `建行` 里那条注释) → 分隔线 `LineHPicF`
##     (**133**，摆 (3,23)、宽 380)
##     → 选中条 `MSelected_background1`(**705**，382×25，默认隐藏，悬停/选中才显)
##   行色 = `UIConfig.UI_YELLOW/BLUE/GREEN/RED`（`UIConfig.as:86/106/288/490` = #FFF000/#1E90FF/#00FF00/#FF0000）
##   行文案 = `CN.HEPING_MODE/ZUDUI_MODE/JIZU_MODE/QUANTI_MODE` 原文（message 包，逐字搬）
## ⚠ 点行才发上行：原版 `onCheckPKMode:44-64` 先 setSelectdItem、再发 `PKEvent.CHANGE_MODE`、
##   最后 `parent.removeChild(this)` ⇒ **不是"点一下钮就循环换档"**（那是我们以前的自造行为）。
## ⚠ 选中态是**盖一层选中条**，不是换钮皮；钮本身只有 upSkin（元件里查过：四枚都只有一张 upSkin）。

const 皮目录 := "res://素材/界面/原版窗口/头像面板/"
const 菜单宽 := 390.0
const 菜单高 := 106.0
const 行高 := 25.0
const 钮宽 := 23.0
const 钮高 := 23.0
const 线宽 := 380.0
const 选中宽 := 382.0

## 模式号 → 图标皮基名（`CharactorInfoPane.as:446-461`：1 和平 2 组队 3 家族 4 全体）
const 图标基名 := {1: "模式_普通", 2: "模式_组队", 3: "模式_家族", 4: "模式_全体"}
## 四行（顺序就是 `buttons` 数组顺序：[null, 和平, 组队, 家族, 全体]，`:100`）
const 行表 := [
	{"模式": 1, "文案": "【普通模式】你无法对任何玩家发起PK，群攻不会误伤任何玩家",
		"色": Color(1.0, 0.941176, 0.0)},			# UI_YELLOW 16773120 = #FFF000
	{"模式": 2, "文案": "【组队模式】你无法对同队伍玩家发起PK，群攻不会误伤本队玩家",
		"色": Color(0.117647, 0.564706, 1.0)},		# UI_BLUE 2003199 = #1E90FF
	{"模式": 3, "文案": "【家族模式】你无法对同家族玩家发起PK，群攻不会误伤同族玩家",
		"色": Color(0.0, 1.0, 0.0)},				# UI_GREEN 65280 = #00FF00
	{"模式": 4, "文案": "【全体模式】你可以对任何玩家发起PK，群攻会伤害其他任何玩家",
		"色": Color(1.0, 0.0, 0.0)},				# UI_RED 16711680 = #FF0000
]

static var 菜单: Control = null
static var 选了: Callable = Callable()
## 当前选中的那一档 = 原版 `PKModePane2.selectdItem` 那一位。
## ⚠ **别改回 `项.set_meta("选中", …)`**：Godot 4 的 metadata 键要求合法标识符，中文键
##   报 `ERROR: Invalid metadata identifier: '选中'` 且**静默存不进去** ⇒ 悬停移开后
##   `get_meta("选中", false)` 恒 false ⇒ 当前那一行的选中条再也亮不回来（2026-10-25 在线腿上逮到）。
static var 当前 := 1


static func 开着() -> bool:
	return 菜单 != null and is_instance_valid(菜单)


static func 关() -> void:
	if 开着():
		菜单.queue_free()
	菜单 = null


static func 打开(层: Node, 位置: Vector2, 当前模式: int, 回调: Callable) -> void:
	## `showPvpModeViewHandler:252-269`：没有就建一份、有就在"开着/关掉"之间切；
	## 位置 = 面板局部 (0,87) 变全局 ⇒ 调用方给已经换算好的父容器与点。
	if 开着():
		关()
		return
	选了 = 回调
	当前 = 当前模式
	菜单 = Control.new()
	菜单.name = "PK模式菜单"
	菜单.position = 位置
	菜单.size = Vector2(菜单宽, 菜单高)
	层.add_child(菜单)
	贴图(菜单, "底", 皮目录 + "模式_菜单底.png", Vector2.ZERO, Vector2(菜单宽, 菜单高))
	for i in 行表.size():
		建行(int(i), 当前模式)


static func 建行(序: int, 当前模式: int) -> void:
	var 行: Dictionary = 行表[序]
	var 项 := Button.new()
	项.name = "模式行%s" % str(int(行["模式"]))
	项.flat = true
	项.toggle_mode = false
	项.position = Vector2(5, 5 + 序 * 行高)
	项.size = Vector2(选中宽, 行高)
	项.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND	# PkItem:139 buttonMode+useHandCursor
	菜单.add_child(项)
	## 层序照 `PkItem` 构造：钮 → 字 → 线 → 选中条（选中条最后 ⇒ 盖在字下面还是上面？
	## Flash 里它是**最后 addChild** = 最上层，但它只有半透明底色，原版看上去字仍在上面；
	## 这里把它放最下层，避免半透明条压淡文字（观感与原版一致，形状尺寸按 382×25 原样）。
	var 条 := 贴图(项, "选中条", 皮目录 + "模式_选中条.png", Vector2.ZERO, Vector2(选中宽, 行高))
	条.visible = false
	贴图(项, "图标", 皮目录 + String(图标基名[int(行["模式"])]) + ".png", Vector2.ZERO, Vector2(钮宽, 钮高))
	var 字 := Label.new()
	字.name = "说明"
	## 原版 `PkItem` 摆的是 **MLabel 组件**（`label.setPosition(btn.x + btn.width, btn.y)` = (23,0)），
	## 而 MLabel 内部那块 TextField 自己再往下偏 2（`MLabel.as:211-212` `textField.x=0; textField.y=2`），
	## Flash 的 TextField 顶部还自带 2 像素内边距 ⇒ **墨迹顶 = 行内 y=4**。
	## 只摆 y=0 会整体偏上 4 像素（用户 10-25 实机看出的"文字偏上，应该在中间"）。
	## 实测：改前文字墨迹中线比图标中线高 4 像素（3.03 倍图上 24..59 vs 39..68），改后对齐。
	字.position = Vector2(钮宽, 4)
	字.size = Vector2(菜单宽 - 10.0 - 钮宽 - 3.0, 20.0)		# :122-124 label.width = param4 − x − 3
	字.text = String(行["文案"])
	字.add_theme_color_override("font_color", 行["色"])
	字.add_theme_font_size_override("font_size", 12)			# MGlowLabel/MLabel 默认 12
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	项.add_child(字)
	贴图(项, "分隔线", 皮目录 + "模式_分隔线.png", Vector2(3, 钮高), Vector2(线宽, 2))
	项.mouse_entered.connect(_悬停.bind(项, true))
	项.mouse_exited.connect(_悬停.bind(项, false))
	项.pressed.connect(_点行.bind(int(行["模式"])))
	if int(行["模式"]) == 当前模式:
		条.visible = true


static func _悬停(项: Button, 在: bool) -> void:
	## `overHandler:146-149` / `outHandler:151-154`：移出时回到"是否选中"，不是一律隐藏。
	## "是否选中"按 `当前` 判（节点名 `模式行<档>` 里就带那一档），不碰 meta（见 `当前` 上面那段）。
	var 条 := 项.get_node_or_null("选中条") as CanvasItem
	if 条 == null:
		return
	条.visible = 在 or String(项.name) == "模式行%d" % 当前


static func 设选中(模式: int) -> void:
	## `setCheck:39-41` ⇒ `setSelectdItem`：旧行灭、新行亮（`buttons[模式]`，数组下标即模式号）。
	当前 = 模式
	if not 开着():
		return
	for 序 in 行表.size():
		var 号: int = int(行表[序]["模式"])
		var 项 := 菜单.get_node_or_null("模式行%s" % str(号)) as Button
		if 项 == null:
			continue
		(项.get_node("选中条") as CanvasItem).visible = (号 == 当前)


static func _点行(模式: int) -> void:
	## 先关再发（原版 `onCheckPKMode` 末尾 `parent.removeChild(this)`，事件在前 ⇒ 这里同序）。
	var 回 := 选了
	关()
	if 回.is_valid():
		回.call(模式)


static func 贴图(父: Node, 名: String, 路: String, 位: Vector2, 尺: Vector2) -> TextureRect:
	var 图 := TextureRect.new()
	图.name = 名
	图.position = 位
	图.size = 尺
	if ResourceLoader.exists(路):
		图.texture = load(路)
	图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图.stretch_mode = TextureRect.STRETCH_SCALE			# 原版是整幅非等比拉伸，不是九宫格
	图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	父.add_child(图)
	return 图
