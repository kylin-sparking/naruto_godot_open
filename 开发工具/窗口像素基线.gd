extends SceneTree

## 把某一页窗口渲染出来，和**原版基线图**逐像素比对，自动指出差在哪一块、差在哪个控件。
##
## 为什么要有它：用户 2026-09-24 报"背包的底板背景对不上格子UI"，但说不清是哪一块。
## 靠人眼对坐标数格子不是办法，而且会把人引去改一个本来没问题的数字。
##
## ⚠️ 加载的是运行时真正加载的**烘焙场景**（`地图资源.playable_scene_path()`），
##    不是 `场景/地图/地图场景.tscn` —— 拿源场景验等于验了个假（2026-09-24 栽过）。
##
## ⚠️ **不能加 `--headless`**：要真视口渲染。无头下根视口只有 64x64。
##
## 用法：
##   Godot --path . --script res://开发工具/窗口像素基线.gd -- \
##        --页=背包 --基线=测试/基线/原版界面/原版_背包.png \
##        [--出目录=测试/差异/窗口基线] [--地图=101010000] [--阈值=8] [--梯度门=12]
##        [--掩码=关] [--偏移=x,y 人工指定配准做交叉验证] [--分页=职业忍术]
##
## **退出码是反着定的**：它是报告工具不是断言工具 —— 文字光栅化必然有非零差，
## 拿它判成败只会天天空红。默认 `quit(0)`；只有下面三种**方法论失败**才 `quit(1)`：
## 配准不可信 / 基线里装不下整个窗口 / 最佳尺度不是 1.00。

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 图像比对 := preload("res://脚本/调试/图像比对.gd")

var _页 := "背包"
var _基线 := ""
var _出目录 := "测试/差异/窗口基线"
var _地图 := "101010000"
var _分页 := ""
var _人工偏移 := Vector2i(99999, 99999)
## 只比窗口的某一块（窗口局部坐标）。
##
## 为什么需要：装备打造窗**右栏整块是装备列表** —— 原版列他的装备、我们列我们的，
## 内容天然不同（实测 23% 像素超阈），把配准的代价地形抹平：置信度掉到 0.98，
## "最优"位置在几个像素之间乱跳（把裁剪原点挪 -1,-9，最优反而从 (1,9) 跳到 (2,18)）。
## 那种情况下出的差异清单是噪声。限定到内容稳定的左栏 + 页签栏，代价地形才立得起来。
var _区域 := Rect2i()
## `--隐藏=<节点名>`：截图前把某个节点藏起来（**诊断用**，比如想验证"槽位的半透明中心
## 是不是把角色透上来了"就把 `角色站立图` 藏掉再看）。
var _隐藏 := ""
var _选项 := {"阈值": 8, "块": 16, "块阈值": 20.0, "梯度门": 12, "掩码": true}

var _场景: Node = null
var _管理: Node = null
var _窗: Node = null
var _方法论失败: Array[String] = []


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() != 2:
			continue
		match 键值[0]:
			"--页": _页 = 键值[1]
			"--基线": _基线 = 键值[1]
			"--出目录": _出目录 = 键值[1]
			"--地图": _地图 = 键值[1]
			"--分页": _分页 = 键值[1]
			"--阈值": _选项["阈值"] = int(键值[1])
			"--梯度门": _选项["梯度门"] = int(键值[1])
			"--块": _选项["块"] = int(键值[1])
			"--块阈值": 选项_块阈值(键值[1])
			"--掩码": _选项["掩码"] = 键值[1] != "关"
			"--隐藏": _隐藏 = 键值[1]
			"--区域":
				var 四 := 键值[1].split(",", false)
				if 四.size() == 4:
					_区域 = Rect2i(int(四[0]), int(四[1]), int(四[2]), int(四[3]))
			"--偏移":
				var 两 := 键值[1].split(",", false)
				if 两.size() == 2:
					_人工偏移 = Vector2i(int(两[0]), int(两[1]))
	call_deferred("_跑")


func 选项_块阈值(值: String) -> void:
	_选项["块阈值"] = float(值)


func _跑() -> void:
	if _基线.is_empty():
		push_error("窗口像素基线：必须给 --基线=<原版截图>")
		quit(1)
		return
	if not _建场景():
		quit(1)
		return
	var 我方 := await _截我方窗口()
	if 我方.is_empty():
		quit(1)
		return
	var 基线图 := _读图(_基线)
	if 基线图 == null:
		push_error("窗口像素基线：基线读不出来 " + _基线)
		quit(1)
		return
	_比对(我方, 基线图)
	quit(1 if not _方法论失败.is_empty() else 0)


func _建场景() -> bool:
	var 路径: String = 地图资源.playable_scene_path(_地图)
	print("窗口像素基线：加载 ", 路径)
	if not 路径.contains("场景/生成/"):
		push_error("窗口像素基线：加载的不是烘焙场景（%s）—— 拿源场景验等于验了个假" % 路径)
		return false
	var 包 := load(路径) as PackedScene
	if 包 == null:
		push_error("窗口像素基线：烘焙场景加载失败")
		return false
	_场景 = 包.instantiate()
	root.add_child(_场景)
	_管理 = _场景.get_node_or_null("窗口管理")
	if _管理 == null:
		push_error("窗口像素基线：场景里没有 `窗口管理`")
		return false
	return true


## 开页 → 等静帧 → 按 `遮罩/主窗口` 的全局矩形裁剪 → 顺手把控件矩形表写进 sidecar。
func _截我方窗口() -> Dictionary:
	_管理.call("打开", _页)
	await _等静帧(8)
	# ⚠️ `_窗` 必须**先赋值**再点页签 —— `_点页内按钮` 用的就是它。
	# 原来这两行写反了（`_窗` 在点页签之后才赋值），于是每次带 `--分页=` 都在
	# `get_node_or_null on a null value` 上静默返回 false、**页签根本没切**，
	# 拿"强化页"去比"精炼基线"，出来的数字全是废的（2026-09-25 踩到）。
	_窗 = _管理.call("取窗口", _页)
	if _窗 == null:
		push_error("窗口像素基线：打不开「%s」" % _页)
		return {}
	if not _分页.is_empty():
		# 直接走页签按下的**同一个入口** `_set_strengthen_tab`，而不是模拟点击。
		# 原因：模拟点击（`pressed.emit()`）在这条路上会被"重建发生在点签之前"的时序吃掉 ——
		# 实测点了之后 `_strengthen_tab` 确实是 6、页面也重建了，但页签还显示「强化」。
		# 这里要的是**页面内容**对得上，所以走确定性的入口；页签名照旧回读核验。
		var 页签表 := 打造页签表(_窗)
		var 序号 := 页签表.find(_分页)
		if 序号 < 0:
			_方法论失败.append("这一页没有「%s」这个页签（有：%s）" % [_分页, 页签表])
			return {}
		_窗.call("_set_strengthen_tab", 序号)
		for _i in 20:
			await process_frame
		_等静帧(8)
		var 页名 := String(_窗.get("_current_page"))
		var 当前页签 := 打造页签名(_窗)
		print("窗口像素基线：切到「%s」后，窗口停在「%s」、页签=%s、_strengthen_tab=%s" % [_分页, 页名, 当前页签, _窗.get("_strengthen_tab")])
		if 当前页签 != _分页:
			_方法论失败.append("页签没切到「%s」（实际「%s」）—— 比的是别的页，结论无效" % [_分页, 当前页签])
			return {}
	if _窗 == null:
		push_error("窗口像素基线：打不开「%s」" % _页)
		return {}
	var 主窗 := _窗.get_node_or_null("遮罩/主窗口") as Control
	if 主窗 == null:
		push_error("窗口像素基线：找不到 遮罩/主窗口")
		return {}
	var 矩形 := 主窗.get_global_rect()
	var 取 := Rect2i(Vector2i(矩形.position.round()), Vector2i(矩形.size.round()))
	var 视口 := root.get_visible_rect().size
	if 取.position.x < 0 or 取.position.y < 0 \
			or 取.end.x > int(视口.x) or 取.end.y > int(视口.y):
		# 窗口超出视口就没法整幅裁出来 —— 那是**方法论失败**，不能拿半张图去比。
		_方法论失败.append("窗口 %s 超出视口 %s，裁不出整幅" % [取, 视口])
		return {}
	if not _隐藏.is_empty():
		for 一个 in _隐藏.split(",", false):
			var 藏 := 主窗.find_child(一个, true, false) as CanvasItem
			if 藏 != null:
				藏.visible = false
				print("窗口像素基线：已隐藏 ", 一个)
			else:
				print("窗口像素基线：找不到要隐藏的节点 ", 一个)
		for _i in 5:
			await process_frame
	var 整屏 := root.get_texture().get_image()
	var 我方 := 整屏.get_region(取)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _出目录))
	var 前缀 := "%s/%s" % [_出目录, _页]
	我方.save_png("res://%s_我方.png" % 前缀)

	# 控件矩形表（**窗口局部坐标**），供"点名"用
	var 控件表: Array = []
	_收控件(主窗, 主窗, 控件表)
	var 文件 := FileAccess.open("res://%s_控件.json" % 前缀, FileAccess.WRITE)
	文件.store_string(JSON.stringify({
		"页": _页, "地图": _地图, "场景": 路径描述(),
		"窗口矩形": [取.position.x, 取.position.y, 取.size.x, 取.size.y],
		"控件": 控件表,
	}, "  "))
	文件.close()
	print("窗口像素基线：我方窗口 %s（%dx%d），控件 %d 个" % [取, 取.size.x, 取.size.y, 控件表.size()])
	return {"图": 我方, "控件表": 控件表, "窗口矩形": 取, "前缀": 前缀}


## 装备强化窗的页签名列表（按顺序）。
func 打造页签表(窗: Node) -> Array:
	var 出: Array = []
	var 页签 := 窗.get_node_or_null("遮罩/主窗口/页面容器/原版装备强化内容/分页")
	if 页签 == null:
		return 出
	for 子 in 页签.get_children():
		if 子 is Button:
			出.append(子.text)
	return 出


## 装备强化窗当前选中的页签名（读不到就返回空串）。
## 存在的意义是**证明页签真的切过去了** —— 不证明的话，切失败会静默地拿别的页去比。
func 打造页签名(窗: Node) -> String:
	var 页签 := 窗.get_node_or_null("遮罩/主窗口/页面容器/原版装备强化内容/分页")
	if 页签 == null:
		return ""
	for 子 in 页签.get_children():
		var 按钮 := 子 as Button
		if 按钮 != null and 按钮.button_pressed:
			return 按钮.text
	return ""


func 路径描述() -> String:
	return 地图资源.playable_scene_path(_地图)


func _收控件(节点: Node, 主窗: Control, 出: Array) -> void:
	for 子 in 节点.get_children():
		if 子 is Control and (子 as Control).is_visible_in_tree():
			var 控 := 子 as Control
			var r := 控.get_global_rect()
			var 局 := Rect2i(
				Vector2i((r.position - 主窗.get_global_rect().position).round()),
				Vector2i(r.size.round()))
			if 局.size.x > 0 and 局.size.y > 0:
				var 记 := {
					"路径": String(主窗.get_path_to(控)),
					"类": 控.get_class(),
					"矩形": [局.position.x, 局.position.y, 局.size.x, 局.size.y],
				}
				if 控 is Label:
					# 文字审计要用**实际渲染色**做颜色过滤，否则墨迹盒会被格子边框污染。
					var 标 := 控 as Label
					记["文本"] = 标.text
					var 色 := 标.get_theme_color("font_color")
					记["色"] = [色.r8, 色.g8, 色.b8]
					记["字号"] = 标.get_theme_font_size("font_size")
				出.append(记)
			_收控件(子, 主窗, 出)


func _点页内按钮(文字: String) -> bool:
	var 主窗 := _窗.get_node_or_null("遮罩/主窗口")
	if 主窗 == null:
		return false
	for 节点 in 主窗.find_children("*", "BaseButton", true, false):
		var 按钮 := 节点 as BaseButton
		if 按钮 != null and (按钮.text == 文字 or 按钮.tooltip_text == 文字):
			按钮.pressed.emit()
			return true
	push_error("窗口像素基线：页内找不到按钮「%s」" % 文字)
	return false


## 连续两次抓同一块，逐像素相同才算静 —— 窗口有滑入补间，不等就会截到半路。
func _等静帧(上限: int) -> void:
	var 上次 := PackedByteArray()
	for _i in 上限:
		await process_frame
		var 本次 := root.get_texture().get_image().get_data()
		if 本次 == 上次:
			return
		上次 = 本次
	push_error("窗口像素基线：等静帧超时（%d 帧内画面一直在变）" % 上限)


func _读图(路径: String) -> Image:
	var 图 := Image.new()
	if 图.load(ProjectSettings.globalize_path("res://" + 路径)) != OK:
		return null
	return 图


# ── 比对与报告 ────────────────────────────────────────────────────────

func _比对(我方: Dictionary, 基线图: Image) -> void:
	var 甲: Image = 我方["图"]
	var 全窗宽 := 甲.get_width()
	var 全窗高 := 甲.get_height()
	# `--区域` 把比对面收到指定的一块。**裁的是两边同一块窗口局部矩形** ——
	# 我方与基线都是"按窗口精确裁"出来的（同尺寸），所以两边各自裁同一块之后，
	# 残余的整体偏移会被后面的配准找到，而右栏的内容差已经不在比对面里了。
	if _区域.size.x > 0 and _区域.size.y > 0:
		var 区 := _区域.intersection(Rect2i(0, 0, 全窗宽, 全窗高))
		if 区.size.x <= 0 or 区.size.y <= 0:
			_方法论失败.append("--区域 %s 与本窗口 %dx%d 没有交集" % [_区域, 全窗宽, 全窗高])
			return
		甲 = 甲.get_region(区)
		基线图 = 基线图.get_region(区)
		print("窗口像素基线：只比窗口局部 %s（%dx%d）" % [区, 区.size.x, 区.size.y])
	var 配 := 图像比对.配准(甲, 基线图)
	if _人工偏移.x != 99999:
		配["偏移"] = _人工偏移
		配["可信"] = true
		print("窗口像素基线：配准用人工指定 %s（交叉验证模式）" % _人工偏移)

	print("=== 窗口像素基线比对 页=%s 阈值=%d 梯度门=%d 掩码=%s ===" % [
		_页, _选项["阈值"], _选项["梯度门"], "开" if _选项["掩码"] else "关"])
	print("配准：我方 %dx%d 落在基线的 %s  代价=%.2f 置信度=%.2f 最佳尺度=%.3f" % [
		甲.get_width(), 甲.get_height(), 配["偏移"], 配["代价"], 配["置信度"], 配["尺度"]])

	if not 配["可信"]:
		_方法论失败.append("配准不可信（置信度 %.2f，尺度 %.3f）—— 宁可不报，也不能在错位上出结论" % [
			配["置信度"], 配["尺度"]])
	if not is_equal_approx(float(配["尺度"]), 1.0):
		_方法论失败.append("基线不是 1:1（最佳尺度 %.3f）—— 拒绝输出几何结论" % 配["尺度"])

	var 比 := 图像比对.比对(配, _选项)
	var 统: Dictionary = 比["统计"]
	print("掩码内可比像素 %d ｜ 超阈 %d（%.3f%%）｜ 最大差 %d" % [
		统["计点"], 统["超阈"],
		100.0 * 统["超阈"] / maxi(1, 统["计点"]), 统["最大差"]])

	var 控件表: Array = 我方["控件表"]
	var 域们: Array = 比["域们"]
	print("--- 差异域（按差异能量降序，共 %d 个）---" % 域们.size())
	for i in mini(12, 域们.size()):
		var 域: Dictionary = 域们[i]
		var r: Rect2i = 域["矩形"]
		print("%2d) 局部 %s %dx%d  点%d  最大差 %d  平均 %.1f  能量 %d" % [
			i + 1, r.position, r.size.x, r.size.y, 域["点数"], 域["最大差"], 域["平均差"], 域["能量"]])
		# ⚠️ 用了 `--区域` 时差异域是**区域局部**坐标，而控件表是**窗口局部**坐标 ——
		# 不把区域原点加回去，点名就是在拿两套坐标比，指到的控件是错的（踩过一次）。
		print("    ↔ %s" % 图像比对.点名(Rect2i(r.position + _区域.position, r.size), 控件表))

	var 块们: Array = 比["块们"]
	if not 块们.is_empty():
		print("--- 块级(%dpx)差异块 top5（粗版式错位在这儿最显眼）---" % _选项["块"])
		for i in mini(5, 块们.size()):
			print("   块%s 局部%s 均值 %.1f" % [块们[i]["块"], 块们[i]["矩形"].position, 块们[i]["均值"]])

	var 前缀: String = 我方["前缀"]
	图像比对.画差异图(甲, 基线图, 配, 比).save_png("res://%s_差异.png" % 前缀)
	_写报告(前缀, 配, 比)
	print("窗口像素基线：差异图与报告已写到 res://%s_*" % 前缀)


func _写报告(前缀: String, 配: Dictionary, 比: Dictionary) -> void:
	var 文件 := FileAccess.open("res://%s_报告.json" % 前缀, FileAccess.WRITE)
	文件.store_string(JSON.stringify({
		"页": _页,
		"配准": {"偏移": [配["偏移"].x, 配["偏移"].y], "代价": 配["代价"],
			"置信度": 配["置信度"], "尺度": 配["尺度"], "可信": 配["可信"]},
		"统计": 比["统计"],
		"域们": 比["域们"].slice(0, 20),
		"块们": 比["块们"].slice(0, 20),
		"方法论失败": _方法论失败,
	}, "  "))
	文件.close()
