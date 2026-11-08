extends SceneTree

## 量「家族列表窗」内容页（原版 `FamillyListWindow` 620×370 ⇒ 内容区 604×302 @ (8,38)）。
## 页面坐标 = 窗口坐标 − (8,38)；每条期望都带 FL.as 行号。
## 用法（不能加 --headless）：Godot --path . --script res://开发工具/截家族列表窗.gd

const 容差 := 1
## 件名 → [路径, 页面矩形, 真值出处]
const 件 := {
	"列表盒": ["列表盒", [5, 5, 594, 267], "FL:161-166 内容宽−10、高−35"],
	"表头": ["表头", [10, 8, 584, 20], "FL:170-172 起点(18,48)、字画在 y−2"],
	"列1": ["表头/家徽", [10, 8, 57, 20], "FL:173 宽57"],
	"列2": ["表头/家族名称", [67, 8, 80, 20], "FL:176 宽80"],
	"列3": ["表头/现任族长", [147, 8, 83, 20], "FL:179 宽83"],
	"列4": ["表头/族中人数", [230, 8, 71, 20], "FL:182 宽71"],
	"列5": ["表头/等级总和", [301, 8, 71, 20], "FL:185 宽71"],
	"列6": ["表头/家徽等级", [372, 8, 107, 20], "FL:188 宽107"],
	"列7": ["表头/本周击杀BOSS数", [479, 8, 110, 20], "FL:191 宽110"],
	"竖分隔1": ["表头/竖分隔1", [67, 10, 2, 20], "FL:281-284 分隔画在 param2.y、列右缘"],
	"竖分隔6": ["表头/竖分隔6", [479, 10, 2, 20], "第 7 列后无分隔 ⇒ 共 6 根"],
	"表头横线": ["表头横线", [10, 30, 584, 2], "FL:193-197 y=表头y+20、宽=盒−10"],
	"列表窗口": ["列表窗口", [10, 34, 569, 235], "FL:198-203 行宽 569（renderer super 宽）"],
	"滚动条": ["滚动条", [579, 34, 15, 235], "ScrollBar.WIDTH=15；584−569=15"],
	"每页": ["每页", [20, 275, 28, 20], "FL:204-209 x=横线x+10、y=列表底+6"],
	"页下拉": ["页下拉", [50, 275, 60, 21], "FL:210-215 w60、x=每页右+2"],
	"显示": ["显示", [130, 275, 28, 20], "FL:216-222 x=下拉右+20"],
	"家主下拉": ["家主下拉", [160, 275, 90, 21], "FL:223-229 w90、x=显示右+2"],
	"自动同意": ["自动同意", [255, 276, 345, 19], "FL:230-239 w345、x=下拉右+5、y+1、默认勾选"],
	"创建家族": ["创建家族", [142, 305, 61, 22], "FL:240-246 x=150 固定、y=370−22−5"],
	"分页": ["分页", [248, 307, 124, 18], "FL:247-251 x=创建右+45、y=创建y+2"],
	"申请加入": ["申请加入", [417, 305, 61, 22], "FL:252-259 x=分页右+45"],
}

var _帧 := 0
var _红 := 0
var _页: Control

func _initialize() -> void:
	root.size = Vector2i(960, 560)
	var 场: Node = load("res://场景/界面/窗口/家族/家族列表窗.tscn").instantiate()
	场.position = Vector2(8.0, 38.0)
	root.add_child(场)
	_页 = 场 as Control

## ⚠️ 截图必须**晚一帧**：行是这一帧 `add_child` 进去的，`root.get_texture()`
## 给的是**上一帧**的画面 —— 同帧抓会拍到"暂无家族"（本轮就抓到过一次），
## 而断言全绿，看着像"选中底没画出来"。
var _该拍 := false

func _process(_d: float) -> bool:
	_帧 += 1
	if _帧 < 14:
		return false
	if _该拍:
		var 图 := root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("res://测试/截图/家族_列表_对照")
		图.save_png("res://测试/截图/家族_列表_对照/客户端.png")
		print("  截图 → res://测试/截图/家族_列表_对照/客户端.png")
		print("家族列表窗：%s" % ("几何全部对上" if _红 == 0 else "有 %d 条不符" % _红))
		quit(0 if _红 == 0 else 1)
		return true
	_页.call("装配", _假宿主())
	for 名 in 件:
		_量(名)
	_验状态()
	_该拍 = true
	return false

func _假宿主() -> Object:
	var 宿 := Node.new()
	宿.name = "假宿主"
	var s := GDScript.new()
	s.source_code = "extends Node\nfunc _show_guild_action(名: String) -> void:\n\tpass\n"
	s.reload()
	宿.set_script(s)
	return 宿

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

func _验状态() -> void:
	var 条 := _页.get_node("滚动条") as Control
	_断(not 条.visible, "空列表无可滚量 ⇒ 不出竖条（AUTO 策略）")
	_断(bool(_页.get("_勾上")), "复选默认勾选（FL:239 selected=true；自绘件 ⇒ 读控制器的 _勾上）")
	_断((_页.get_node("创建家族") as TextureButton).texture_normal.resource_path.ends_with("钮底61.png"),
		"钮常态 = 预烘 61 档（TextureButton 不能九宫格）")
	# 字段名 = 服务端 `handle_banghui` action 101 那 12 字段的语义名（`后端连接` action 3 解出来的键）
	_页.call("刷新", [{"name": "木叶家族", "leader": "瑞树", "members": 1, "capacity": 50,
		"level_sum": 60, "flag_level": 8, "flag_name": "木叶旗帜", "boss_sum": 0, "channel_id": 1, "flag_style": 1000}])
	var 行 := _页.get_node("列表窗口/内容列").get_child(0) as Control
	_断(行.name == "行1" and 行.size.y == 23.0, "一行 23 高（FL:199 rowHeight）")
	var 名 := 行.get_node("家族名称") as Label
	_断(名.text == "木叶家族" and 名.self_modulate == Color.WHITE and
		名.get_theme_color("font_color") == Color("#87CEEB"), "族名列 = UI_BLUE（renderer 列色）")
	var 级 := 行.get_node("家徽等级") as Label
	_断(级.text == "8级  木叶旗帜", "家徽等级列 = 「N级␣␣旗名」（AS3:94 是两个空格）")
	_断((行.get_node("等级总和") as Label).text == "60" and
		(行.get_node("本周击杀BOSS数") as Label).text == "0", "等级总和/本周BOSS 两列填上了（服务端有发）")
	# 选中态：`CommonItemRenderer.as:142-149`。截图前先选一行，让对照图里能看到选中底。
	_断(not (行.get_node("选中底") as Control).visible, "未选中时选中底不显示")
	_页.call("_选中", 0)
	_断((行.get_node("选中底") as Control).visible, "选中后选中底显出来（CommonItemRenderer.selected）")
	_断(String((_页.call("选中家族") as Dictionary).get("name", "")) == "木叶家族",
		"选中家族() 取的是这一行")

func _断(真: bool, 说: String) -> void:
	if not 真:
		_红 += 1
	print("  %s %s" % ["√" if 真 else "!!", 说])
