extends SceneTree

## 量「纲手对话窗」（原版 `QuestDialog.as`，两格 ScaleSprite 上下叠、无标题栏）。
## 这扇不是 `功能窗口` 的页 ⇒ 走不了 `量具基类` 那套「开窗→切页→量件」，
## 但**口径一样**：走真路径（`小地图面板.show_npc_dialog`）、逐件量矩形、逐字对文案、
## 截图 + `几何.txt` + 退出码当硬门。
##
## 用法（不能加 --headless）：
##   Godot --path . --script res://开发工具/截NPC对话页.gd -- --出目录=res://测试/截图/NPC对话

const 窗脚本 := preload("res://脚本/界面/窗口/NPC对话窗.gd")
const 宽 := 506.0
const 上格高 := 81.0
const 下格距 := 5.0
const 下格高 := 100.0
const 行距 := 20.0
const 黄 := Color(1, 0.941176, 0, 1)
const 白 := Color(1, 1, 1, 1)
const 绿 := Color(0, 1, 0, 1)
## 逐件期望（窗局部，原点 = 上格左上角）。算式全在 `QuestDialog.as` 行号里。
const 期望 := {
	"上格": [0, 0, 宽, 上格高],
	"上格/名字": [10, 8, 120, 21],
	"上格/台词": [25, 39, 456, 17],
	"下格": [0, 86, 宽, 下格高],
	"下格/菜单": [25, 106, 220, 60],
	"下格/菜单/行1": [25, 99, 220, 20],
	"下格/菜单/行1/手形": [25, 106, 15, 11],
	"下格/菜单/行1/文字": [45, 99, 200, 20],
	"下格/菜单/行2": [25, 119, 220, 20],
	"下格/菜单/行3": [25, 139, 220, 20],
}
const 文案 := {"上格/名字": "纲手", "下格/菜单/行1/文字": "挑战副本", "下格/菜单/行2/文字": "挑战精英副本",
	"下格/菜单/行3/文字": "离开"}

var 出目录 := ""
var 行: Array[String] = []
var 有错 := false
var 帧 := 0
var 场景: Node
var 面板: Node
var 窗: Node
var 队列: Array[Callable] = []
var 等待 := 0


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2 and 键值[0] == "--出目录":
			出目录 = 键值[1]
	if 出目录.is_empty():
		出目录 = "res://测试/截图/NPC对话"
	if not DirAccess.dir_exists_absolute(出目录):
		DirAccess.make_dir_recursive_absolute(出目录)
	队列.append(_步开图)
	队列.append(_步喊窗)
	队列.append(_步量)
	队列.append(_步拍)


func _process(_d: float) -> bool:
	帧 += 1
	if 帧 < 8:
		return false
	if 等待 > 0:
		等待 -= 1
		return false
	if 队列.is_empty():
		_收尾()
		return true
	队列.pop_front().call()
	return false


func _步开图() -> void:
	var 地图 := load("res://场景/地图/地图场景.tscn") as PackedScene
	场景 = 地图.instantiate()
	root.add_child(场景)
	面板 = 场景.get_node_or_null("小地图面板")
	if 面板 == null:
		_错("地图场景下没有 小地图面板")
		return
	等待 = 6


## 走**真路径**：`show_npc_dialog(npc_id, 服务端台词)` ⇒ 它自己去后端连接取 328 的菜单。
## 离线跑没有后端 ⇒ 那条路会退化成「只有一行离开」，所以这里再显式喂一次纲手的三行菜单，
## 喂的是服务端 `NPC_SERVICE_MENUS[18]` 的原值（挑战副本=12 / 挑战精英副本=30 / 离开=-1）。
func _步喊窗() -> void:
	面板.call("show_npc_dialog", "00000018", "我把希望，押在你身上，希望你能成为伟大的忍者。")
	等待 = 2
	窗 = _找(面板, "原版NPC对话窗") as Node
	if 窗 == null:
		_错("小地图面板 旁边没建出 原版NPC对话窗")
		return
	窗.call("显示", 18, "纲手", "我把希望，押在你身上，希望你能成为伟大的忍者。",
		[["挑战副本", 12], ["挑战精英副本", 30], ["离开", -1]])
	等待 = 3


func _步量() -> void:
	var 根 := 窗.get_node("原版NPC对话") as Control
	if 根 == null:
		_错("对话窗下没有 原版NPC对话 根")
		return
	有错 = 有错 or (not 根.visible)
	行.append("=== 纲手对话窗（QuestDialog 506 宽两格）===")
	行.append("  根 visible=%s size=%s" % [根.visible, 根.size])
	var 原点 := 根.get_global_position()
	for 名 in 期望:
		var 件 := 根.get_node_or_null(String(名)) as Control
		if 件 == null:
			_错("缺节点 %s" % 名)
			continue
		var 全 := 件.get_global_position()
		var 实 := [全.x - 原点.x, 全.y - 原点.y, 件.size.x, 件.size.y]
		var 想: Array = 期望[名]
		var 偏 := false
		for i in 4:
			if absf(实[i] - float(想[i])) > 0.01:
				偏 = true
		有错 = 有错 or 偏
		行.append("  %-10s 实(%6.1f,%6.1f %5.1fx%-5.1f) 期(%6.1f,%6.1f %5.1fx%-5.1f) %s" % [
			名, 实[0], 实[1], 实[2], 实[3], float(想[0]), float(想[1]), float(想[2]),
			float(想[3]), "!! 偏" if 偏 else "√"])
	# 居中（原版 `PopUpMananger.centerWindow` `QuestDialog.as:401`）：症状是「弹窗跑到左上角」
	# ⇒ 钉「四边留空大致相等」，不钉绝对坐标（钉死就等于把测试和 960×560 焊在一起）。
	var 视 := root.get_visible_rect()
	var 左 := 根.get_global_position().x
	var 上 := 根.get_global_position().y
	var 居: bool = absf(左 * 2.0 + 根.size.x - 视.size.x) < 1.0 \
			and absf(上 * 2.0 + 根.size.y - 视.size.y) < 1.0
	有错 = 有错 or (not 居)
	行.append("  居中 左上=(%.1f,%.1f) 视口=%dx%d 右下留空=(%.1f,%.1f) %s" % [
		左, 上, 视.size.x, 视.size.y, 视.size.x - 左 - 根.size.x, 视.size.y - 上 - 根.size.y,
		"√" if 居 else "!! 没居中（原版是舞台正中）"])
	_验文案(根)
	_验色(根)
	_验接线()


func _验文案(根: Control) -> void:
	行.append("  --- 文案 ---")
	for 名 in 文案:
		var 件 := 根.get_node_or_null(String(名))
		var 实 := ""
		if 件 is Label:
			实 = (件 as Label).text
		elif 件 is RichTextLabel:
			实 = (件 as RichTextLabel).text
		var 同 := 实 == String(文案[名])
		有错 = 有错 or (not 同)
		行.append("  %-10s %s（应 %s）%s" % [名, 实, 文案[名], "√" if 同 else "!! 不符"])
	var 台 := 根.get_node("上格/台词") as RichTextLabel
	var 想台 := "[color=#ffffff]我把希望，押在你身上，希望你能成为伟大的忍者。[/color]"
	有错 = 有错 or (台.text != 想台)
	行.append("  %-10s %s" % ["上格/台词", "√ 与 NPC.json 逐字一致" if 台.text == 想台 else "!! 不符"])


func _验色(根: Control) -> void:
	行.append("  --- 字色（`UIConfig` 的数不在语言表里）---")
	for 组 in [["上格/名字", 黄], ["下格/菜单/行1/文字", 绿]]:
		var 件 := 根.get_node_or_null(String(组[0])) as Label
		if 件 == null:
			_错("%s 取不到" % 组[0])
			continue
		var 色 := 件.get_theme_color(&"font_color")
		有错 = 有错 or (色 != 组[1])
		行.append("  %-16s %s（应 %s）%s" % [组[0], 色.to_html(false),
				(组[1] as Color).to_html(false), "√" if 色 == 组[1] else "!! 不符"])
	var 台 := 根.get_node("上格/台词") as RichTextLabel
	有错 = 有错 or not (台.text as String).begins_with("[color=#ffffff]")
	行.append("  %-16s 台词套白 = %s" % ["上格/台词", "√" if 台.text.begins_with("[color=#ffffff]") else "!!"])


## 三枚菜单行必须**可点**且走既有钩子；手型光标是原版 `buttonMode/useHandCursor` 的等价物。
func _验接线() -> void:
	行.append("  --- 交互 ---")
	for i in 3:
		var 件 := (窗.get_node("原版NPC对话") as Control).get_node("下格/菜单/行%d" % (i + 1)) as Control
		var 对: bool = 件.mouse_filter == Control.MOUSE_FILTER_STOP \
				and 件.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND
		var 数 := 件.get_signal_connection_list("gui_input").size()
		有错 = 有错 or (not 对) or 数 < 1
		行.append("  行%d mouse_filter=%s 手型=%s gui_input 连接 %d 条 %s" % [
			i + 1, 件.mouse_filter, 件.mouse_default_cursor_shape, 数, "√" if 对 and 数 >= 1 else "!! 不可点"])
	# 重复调用 显示() 不许叠行（原版每次 showDialog 都 closeDialog 重建）
	窗.call("显示", 18, "纲手", "我把希望，押在你身上，希望你能成为伟大的忍者。",
		[["挑战副本", 12], ["挑战精英副本", 30], ["离开", -1]])
	等待 = 2
	_验点行开页()


## 症状「点挑战副本 / 挑战精英副本没弹窗」的回归判据：原版是**收到回包才开窗**
## （`Client.as:1212 onCopy_visitHistory → showCopyWindow`、`:1149 onHeroEnterInfo →
## showEliteCopyWindow`），本工程那两扇是 `功能窗口` 的页 ⇒ 点行必须把对应页叫出来。
## 走的是与真点击完全相同的一条路径（`按下行`），不是 `emit()` 演一遍。
func _验点行开页() -> void:
	var 管理 := 场景.get_node_or_null("窗口管理")
	if 管理 == null or 面板 == null:
		_错("缺 窗口管理 / 小地图面板，点行判据跑不了")
		return
	for 组 in [[0, "副本"], [1, "精英副本"]]:
		窗.call("显示", 18, "纲手", "我把希望，押在你身上，希望你能成为伟大的忍者。",
			[["挑战副本", 12], ["挑战精英副本", 30], ["离开", -1]])
		窗.call("按下行", int(组[0]))
		var 窗体 := 管理.call("取或建窗口", String(组[1])) as Node
		var 当前 := "" if 窗体 == null else String(窗体.get("_current_page"))
		var 开着 := 当前 == String(组[1])
		有错 = 有错 or (not 开着)
		行.append("  点第 %d 行 → 「%s」窗 _current_page=%s %s" % [
			int(组[0]) + 1, 组[1], 当前, "√ 已打开" if 开着 else "!! 没弹出来"])


func _步拍() -> void:
	var 图像 := root.get_texture().get_image()
	var 根 := (窗.get_node("原版NPC对话")) as Control
	var 起 := Vector2i(int(根.get_global_position().x), int(根.get_global_position().y))
	var 尺 := Vector2i(int(根.size.x), int(根.size.y))
	尺.x = clampi(尺.x, 1, 图像.get_width() - 起.x)
	尺.y = clampi(尺.y, 1, 图像.get_height() - 起.y)
	图像.get_region(Rect2i(起, 尺)).save_png("%s/客户端.png" % 出目录)
	行.append("  截图 %s/客户端.png（%dx%d）" % [出目录, 尺.x, 尺.y])
	var 后 := 窗.get_node("原版NPC对话") as Control
	行.append("  重喊一次之后行数=%d（应 3，多了就是没清干净）%s" % [
		(后.get_node("下格/菜单") as Control).get_child_count(),
		"√" if (后.get_node("下格/菜单") as Control).get_child_count() == 3 else "!!"])
	有错 = 有错 or (后.get_node("下格/菜单") as Control).get_child_count() != 3


func _收尾() -> void:
	var f := FileAccess.open("%s/几何.txt" % 出目录, FileAccess.WRITE)
	if f != null:
		for 一 in 行:
			f.store_line(一)
		f.close()
	print("\n".join(行))
	print("纲手对话窗：%s" % ["不通过" if 有错 else "几何、文案、字色、接线全部对上"])
	quit(1 if 有错 else 0)


func _错(文本: String) -> void:
	有错 = true
	行.append("!! " + 文本)
	push_error("量具[纲手对话窗]：" + 文本)


func _找(父: Node, 名: String) -> Node:
	for 子 in 父.get_children():
		if str(子.name) == 名:
			return 子
		var 果 := _找(子, 名)
		if 果 != null:
			return 果
	return null
