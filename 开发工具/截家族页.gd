extends SceneTree

## 量「家族主窗」内容页（原版 `FamillyWindow` 617×390，内容区 601×322 @ (8,38)）。
## 页面坐标 = 窗口坐标 − (8,38)；真值全文 `game-client/真值/窗口/家族.md` §1。
## 首钮 x=(617−61·8−16·7)/2=8.5 是**半像素**（居中公式），故矩形比对允许 ±1px。
## 用法（不能加 --headless）：Godot --path . --script res://开发工具/截家族页.gd

const 容差 := 1

## 件名 → [页面内路径, 期望页面矩形(x,y,w,h), 真值出处]
const 件 := {
	"家徽区": ["家徽区", [5, 5, 210, 142], "FW:172-176 窗(13,43)"],
	"家徽区底": ["家徽区/盒底", [5, 5, 210, 142], "MPane_background 九宫格 7.5/6.75/7/7.25"],
	"家徽名标题": ["家徽区/家徽名标题", [13, 13, 64, 20], "FW:184-191 FormItem2 title 64"],
	"家徽名值": ["家徽区/家徽名值", [81, 13, 135, 20], "FW:185 content 135、gap 4"],
	"家族等级值": ["家徽区/家族等级值", [73, 35, 135, 20], "FW:193 标题x+60"],
	"加成属性": ["家徽区/加成属性", [13, 57, 135, 20], "FW:194 行距 22"],
	"家徽格": ["家徽区/家徽格", [23, 81, 40, 40], "FW:195-198 名x+10、加成y+24"],
	"公告区": ["公告区", [216, 19, 380, 127], "FW:178 家徽区右+1、y+14"],
	"公告端帽左": ["公告区/端帽左", [246, 5, 27, 22], "LeafBorder.as:66,82 x=padding30、y=8−22"],
	"公告端帽右": ["公告区/端帽右", [539, 5, 27, 22], "LeafBorder.as:67 x=宽−27−30"],
	"公告盒标题": ["公告区/盒标题", [216, 0, 380, 18], "LeafBorder.as:70-71 y=−label高+1"],
	"公告文本": ["公告区/公告", [216, 19, 380, 137], "FW:199-200 高=盒+10、maxChars200"],
	"修改钮": ["公告区/修改钮", [554, 118, 37, 22], "FW:203-204 盒右−42、盒底−28、w37"],
	"信息区": ["信息区", [5, 167, 210, 149], "FW:179 y=家徽区底+20"],
	"信息文本": ["信息区/信息", [5, 167, 210, 149], "FW:205-206 橙字"],
	"成员区": ["成员区", [216, 167, 380, 149], "FW:180"],
	"成员表头": ["成员区/表头", [224, 172, 364, 20], "FW:268-280 createListLable 字画在 y−2"],
	"表头列1": ["成员区/表头/角色名", [224, 172, 110, 20], "FW:218 宽110"],
	"表头列2": ["成员区/表头/等级", [334, 172, 58, 20], "FW:221 宽58"],
	"表头列3": ["成员区/表头/职位", [392, 172, 64, 20], "FW:224 宽64"],
	"表头列4": ["成员区/表头/贡献", [456, 172, 68, 20], "FW:227 宽68"],
	"表头列5": ["成员区/表头/财富", [524, 172, 68, 20], "FW:230 宽68、末列无分隔"],
	"表头分隔1": ["成员区/表头/分隔1", [334, 174, 2, 20], "TableSeparatorLineF 593 原生2×20"],
	"表头横线": ["成员区/表头横线", [224, 192, 364, 2], "FW:232-236 y=表头y+18、LineHPicF 252×2 整拉"],
	"成员列表": ["成员区/列表窗口", [224, 194, 349, 116], "FW:207-212 列表 364 宽含 15 竖条"],
	"成员滚动条": ["成员区/滚动条", [573, 194, 15, 116], "ScrollBar.WIDTH=15；列表窗口 224+349=573 起"],
}
const 底栏 := ["家族列表", "家族升级", "家族技能", "家族尾兽", "家族旗帜", "家族贡献", "家族商店", "成员信息"]

var _帧 := 0
var _红 := 0
var _页: Control

func _initialize() -> void:
	root.size = Vector2i(960, 560)
	var 场: Node = load("res://场景/界面/窗口/家族/家族窗口.tscn").instantiate()
	场.position = Vector2(8.0, 38.0)		# 模拟 UIWindow 内容区原点（窗口坐标 − (8,38)）
	root.add_child(场)
	_页 = 场 as Control

func _process(_d: float) -> bool:
	_帧 += 1
	if _帧 < 14:
		return false
	_页.call("装配", _假宿主())
	for 名 in 件:
		_量(名)
	_量底栏()
	_验状态()
	var 图 := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://测试/截图/家族")
	图.save_png("res://测试/截图/家族/客户端.png")
	print("  截图 → res://测试/截图/家族/客户端.png")
	print("家族主窗：%s" % ("几何全部对上" if _红 == 0 else "有 %d 条不符" % _红))
	quit(0 if _红 == 0 else 1)
	return true

## 假宿主：只提供 `_session.guild` 与 `_show_guild_action`，让页面能离线跑完整填充路径。
func _假宿主() -> Object:
	var 宿 := Node.new()
	宿.name = "假宿主"
	宿.set_script(_宿脚本())
	return 宿

func _宿脚本() -> GDScript:
	var s := GDScript.new()
	s.source_code = """extends Node
var _session := 数据.new()
func _show_guild_action(名: String) -> void:
	pass
class 数据 extends Node:
	var guild := {"joined": true, "name": "木叶", "leader": "鸣人", "flag_name": "火之意志",
		"level": 3, "members": 5, "contribution": 120, "notice": "团结协作",
		"member_list": [{"name": "鸣人", "level": 60, "rank": 5, "contribution": 900,
			"weekly_contribution": 30}]}
"""
	s.reload()
	return s

func _量(名: String) -> void:
	var 据: Array = 件[名]
	var 节 := _页.get_node_or_null(String(据[0])) as Control
	if 节 == null:
		_红 += 1
		print("  !! %-12s 节点不存在：%s" % [名, 据[0]])
		return
	var g := 节.get_global_transform_with_canvas().origin
	var 实 := [int(round(g.x)) - 8, int(round(g.y)) - 38, int(round(节.size.x)), int(round(节.size.y))]
	var 期: Array = 据[1]
	var 中 := true
	for i in 4:
		if absi(实[i] - int(期[i])) > 容差:
			中 = false
	if not 中:
		_红 += 1
	print("  %-12s %s 期%s 实%s　%s" % [名, "√" if 中 else "!!", 期, 实, 据[2]])

func _量底栏() -> void:
	for i in 底栏.size():
		var 节 := _页.get_node_or_null(底栏[i]) as TextureButton
		if 节 == null:
			_红 += 1
			print("  !! %-12s 不存在" % 底栏[i])
			continue
		var g := 节.get_global_transform_with_canvas().origin
		var 期x := float(int(round(0.5 + 77.0 * i)))	# 移植侧取整（原版居中公式落 8.5 半像素，Godot 会重采样）
		var 中 := absf(g.x - 8.0 - 期x) <= 1.0 and absf(g.y - 38.0 - 325.0) <= 1.0 \
			and absf(节.size.x - 61.0) <= 1.0 and absf(节.size.y - 22.0) <= 1.0
		if not 中:
			_红 += 1
		print("  %-12s %s 期[%.1f, 325, 61, 22] 实[%d, %d, %d, %d]　FW:237-257 w61 间距16 y=高−27" % [
			底栏[i], "√" if 中 else "!!", 期x, int(round(g.x)) - 8, int(round(g.y)) - 38, int(节.size.x), int(节.size.y)])
		var 字 := 节.get_node_or_null("Label") as Label
		if 字 == null or 字.text != 底栏[i]:
			_红 += 1
			print("  !! %s 的 Label 文案不对" % 底栏[i])

func _验状态() -> void:
	var 技 := _页.get_node("家族技能") as TextureButton
	var 列 := _页.get_node("家族列表") as TextureButton
	_断(not 技.disabled and not 列.disabled, "在族时 8 颗全可点（FW:413 updateFamilly 放权）")
	_页.call("刷新", {"joined": false})
	_断(技.disabled, "不在族时 技能/尾兽 禁用（FW:245,248 初值）")
	_断(not (_页.get_node("公告区/修改钮") as TextureButton).disabled, "不在族 ⇒ 修改钮变「创建家族」可点")
	_页.call("刷新", _假宿主()._session.guild)
	var 告 := _页.get_node("公告区/公告") as TextEdit
	告.text = "x".repeat(260)
	告.grab_focus()
	_页.call("_限公告长")	# 程序性赋值不一定发 text_changed ⇒ 直接跑一次裁长（真人打字必发）
	_断(告.text.length() == 200, "公告超 200 字被裁（FW:202 maxChars=200，TextEdit 无该属性⇒text_changed 裁）")
	var 底 := _页.get_node("家徽区/家徽格/底色") as ColorRect
	_断(底.color == Color(0x1E / 255.0, 0x90 / 255.0, 1.0), "3 级家徽底色 = 0x1E90FF（FW:130-145）")
	_断(not _页.get_node("成员区/滚动条").visible, "1 行成员无可滚量 ⇒ 不出竖条（AUTO 策略）")
	_断(_页.get_node("公告区/修改钮").texture_normal.resource_path.contains("钮底61.png"),
		"底栏钮常态 = 钮底61.png（tag18 九宫格预烘档，不是通用控件/按钮.png）")

func _断(真: bool, 说: String) -> void:
	if not 真:
		_红 += 1
	print("  %s %s" % ["√" if 真 else "!!", 说])
