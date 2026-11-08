extends SceneTree
## 家徽**显示**回归门（离线）：钉"按原尺寸居中、不缩放" + "素材本体不染色"。
##
## 为什么单独立这条：家徽图是 **34×34**，而界面上的格子往往更大（创建窗预览格 40×40）——
## `TextureRect` 默认 `stretch_mode = SCALE` 会把 34 拉到 40（非整数缩放 ⇒ 发糊、颜色被冲淡）。
## 原版 `SimpleItemCell.setIcon`（`:97-107`）是**按原尺寸居中**的，所以这边也必须不缩放。
## 用户 2026-10-11 报"这个图案太模糊了，而且颜色这些都不对"里的**模糊**就是这条（已修）。
##
## ⚠️ 但同一句话里"**颜色这些都不对**"当时判成了"颜色本身是对的"（照
## `PicTool.tintJiaHuiPicWhiteToGold` 把 RGB≥0xE0E0E0 染成 0xFFFF8C00）—— **那个结论是错的**。
## 2026-10-15 用户并排图纠偏：**单机版实机就是 swf 原图，没染色**（浅蓝方底 207,215,244 +
## 白圆盘 255,255,255 + 深灰卷纹 80,70,68），我们那批是"圆盘橘金 255,140,0"。
## 用户原话："**所有使用到族徽你都不应该染色，而是直接使用素材**"。
## ⇒ 素材已按原色重导（`开发工具/导出家族家徽.py` 默认不染色），本门加一节钉住它。
##
## 用法：Godot --headless --path . --script res://测试/家徽显示回归测试.gd

const 家徽图 := preload("res://脚本/界面/窗口/家族/家徽图.gd")
const 创建填充 := preload("res://脚本/界面/窗口/家族/家族创建填充.gd")

## `PicTool.as:528-558 tintJiaHuiPicWhiteToGold` 的目标色 —— **本工程不许出现**（见文件头）。
const 染金色 := Color8(0xFF, 0x8C, 0x00)
## 同一段的阈值：`(pixel & 0xFFFFFF) >= 14737632`（= 0xE0E0E0）。
const 染阈值 := 0xE0

var _失败: Array[String] = []


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	_查素材不染色()
	_查底框素材()
	await _查创建窗预览()
	await _查家族页家徽格()
	for 条 in _失败:
		print("  !! " + 条)
	if _失败.is_empty():
		print("家徽显示回归测试：通过（素材原色不染色；34×34 原尺寸居中、不缩放；样式翻页改图；家族页同款）")
		quit(0)
	else:
		print("家徽显示回归测试：FAIL %d 条" % _失败.size())
		quit(1)


## ── 素材本体：**一张都不许染色** ──────────────────────────────────────────
## 判据两条，缺一不可：
##   ① 没有任何一个像素等于染金色 `(255,140,0)`；
##   ② 每张都**至少有一个**像素的 RGB ≥ 0xE0E0E0（白圆盘那批）——
##      这条是"没有偷着染"的**正向证据**：AS3 那段染色会把所有 ≥ 阈值 的像素全换掉，
##      真染过的话 ② 必然不成立（染后一张白都剩不下）。
## 反向对照（2026-10-15 做过）：把某张换成染色版 ⇒ 这一节立刻红；换回原色 ⇒ 绿。
func _查素材不染色() -> void:
	var 文件 := DirAccess.get_files_at(家徽图.目录)
	if 文件.is_empty():
		_失败.append("读不到家徽素材目录：%s（素材不进 git，新克隆要自己跑 开发工具/导出家族家徽.py）"
			% 家徽图.目录)
		return
	var 数 := 0
	var 染色名单: Array[String] = []
	var 无阈值像素: Array[String] = []
	for 名 in 文件:
		if not (名.begins_with("家徽_") and 名.ends_with(".png")):
			continue
		数 += 1
		var 图 := load(家徽图.目录 + 名) as Texture2D
		if 图 == null:
			无阈值像素.append(名 + "(读不到贴图)")
			continue
		var 像 := 图.get_image()
		if 像 == null:
			无阈值像素.append(名 + "(拿不到 Image)")
			continue
		if Vector2i(像.get_width(), 像.get_height()) != Vector2i(int(家徽图.边长), int(家徽图.边长)):
			_失败.append("%s 尺寸 %s ≠ %d×%d（`PicTool.as:509` 的 drawRect）"
				% [名, str(像.get_size()), int(家徽图.边长), int(家徽图.边长)])
		var 有阈值像素 := false
		var 有染金 := false
		for y in 像.get_height():
			for x in 像.get_width():
				var 色 := 像.get_pixel(x, y)
				if 色.a < 0.5:
					continue
				var r := int(round(色.r * 255.0))
				var g := int(round(色.g * 255.0))
				var b := int(round(色.b * 255.0))
				if r == int(round(染金色.r * 255.0)) and g == int(round(染金色.g * 255.0)) \
						and b == int(round(染金色.b * 255.0)):
					有染金 = true
				elif r >= 染阈值 and g >= 染阈值 and b >= 染阈值:
					有阈值像素 = true
		if 有染金:
			染色名单.append(名)
		if not 有阈值像素:
			无阈值像素.append(名)
	if 数 != 200:
		_失败.append("家徽素材 %d 张 ≠ 200 张样式（`swf/BangHui/BangHui_flagStyle_*.swf` 是 200 张）" % 数)
	if not 染色名单.is_empty():
		_失败.append("这 %d 张还是染过色的（含 %s）：%s … —— 请跑 开发工具/导出家族家徽.py（**不带** --染色）"
			% [染色名单.size(), str(染金色), str(染色名单.slice(0, mini(5, 染色名单.size())))])
	if not 无阈值像素.is_empty():
		_失败.append("这 %d 张连一个 RGB ≥ 0xE0E0E0 的像素都没有（像被染过、或图坏了）：%s …"
			% [无阈值像素.size(), str(无阈值像素.slice(0, mini(5, 无阈值像素.size())))])


## ── 底框素材（`Effect_CharStatus_Kuang`，20×20）────────────────────────────
## 原版两块族徽（角色头顶 `Character.as:1449`、地图族旗 `Flag.as:419`）外面都套这一圈框；
## 2026-10-14 那轮记成"素材库里没有"是**查错了库** —— 它在运行时加载的
## `asset/effect.fws.swf`（SymbolClass 第 4 号），2026-10-15 已导出为 `族徽底框.png`。
## 判据：存在、20×20、且有非全透明像素（防 ffdec 对"画面在子符号里"的符号导空张）。
func _查底框素材() -> void:
	if not ResourceLoader.exists(家徽图.底框文件):
		_失败.append("缺底框素材 %s（跑 开发工具/导出族徽底框.py）" % 家徽图.底框文件)
		return
	var 图 := 家徽图.取底框()
	if 图 == null:
		_失败.append("底框素材加载不出来：%s" % 家徽图.底框文件)
		return
	var 像 := 图.get_image()
	if 像 == null:
		_失败.append("底框素材拿不到 Image：%s" % 家徽图.底框文件)
		return
	if Vector2i(像.get_width(), 像.get_height()) != Vector2i(20, 20):
		_失败.append("底框应是 20×20（`DefineShape 3` 的 bounds 0..6000 twip），实为 %s"
			% str(像.get_size()))
	var 不透明 := 0
	for y in 像.get_height():
		for x in 像.get_width():
			if 像.get_pixel(x, y).a > 0.0:
				不透明 += 1
	if 不透明 == 0:
		_失败.append("底框整张全透明（对「画面在子符号里」的符号 ffdec 会导空张）")


## 调用点也得是"原色直出"：素材不染色只是半边，另一半是**任何调用点都不许再覆色**
## （`modulate` / `self_modulate` 都算）。2026-10-15 把 7 个使用点逐个核过（家族页家徽格 /
## 创建窗预览 / 家族列表行 / 旗帜窗预览 / HUD 永久徽条 / 角色头顶标示 / 地图族旗），
## 全是"`texture = 取(...)` 之后不再动颜色"；这两条断言把其中最常改的两处钉住。
func _查没覆色(节点: CanvasItem, 谁: String) -> void:
	if 节点.modulate != Color.WHITE:
		_失败.append("%s 被 modulate 染了色：%s（族徽一律直接用素材原色）" % [谁, str(节点.modulate)])
	if 节点.self_modulate != Color.WHITE:
		_失败.append("%s 被 self_modulate 染了色：%s（族徽一律直接用素材原色）" % [谁, str(节点.self_modulate)])


func _查创建窗预览() -> void:
	var 页 := (load("res://场景/界面/窗口/家族/家族创建窗.tscn") as PackedScene).instantiate() as Control
	root.add_child(页)
	await process_frame
	创建填充._填家徽(页, null)
	await process_frame
	var 图 := 页.get_node_or_null("格家徽图") as TextureRect
	if 图 == null:
		_失败.append("创建窗里没有「格家徽图」")
		return
	if not 图.size.is_equal_approx(Vector2.ONE * 家徽图.边长):
		_失败.append("创建窗家徽预览画成了 %s —— 原版按原尺寸居中（%d×%d），不缩放"
			% [str(图.size), 家徽图.边长, 家徽图.边长])
	if 图.texture == null:
		_失败.append("创建窗家徽预览没有贴图（`家徽图.取(样式)` 没取到）")
	else:
		var 路 := String(图.texture.resource_path)
		if not 路.contains("家徽_"):
			_失败.append("创建窗家徽预览用的不是家徽图：%s" % 路)
	_查没覆色(图, "创建窗家徽预览")
	var 页码 := 页.get_node_or_null("分页短旗选择/页码") as Label
	if 页码 == null:
		_失败.append("创建窗里没有页码标签")
	else:
		var 总 := 游戏数据.family_create_styles().size()
		if 页码.text != "1/%d" % 总:
			_失败.append("页码应显示 1/%d，实为 %s" % [总, 页码.text])
	# 翻一页：图要换成下一个样式的
	var 首图 := String(图.texture.resource_path) if 图.texture != null else ""
	页.set_meta("guild_create_style_page", 1)
	创建填充._填家徽(页, null)
	await process_frame
	if 图.texture == null or String(图.texture.resource_path) == 首图:
		_失败.append("翻到第 2 页后家徽图没换（原版按 `ImgType.BangHui.flagStyle` 分页换图）")
	if not 图.size.is_equal_approx(Vector2.ONE * 家徽图.边长):
		_失败.append("翻页后预览尺寸又变了：%s（应在同一个 40×40 格里按原尺寸居中）" % str(图.size))
	页.queue_free()
	await process_frame


## 家族页那格：直接调 `_画家徽格`（它才是画家徽的地方），不依赖整个填充链。
## 用一个自造 40×40 的格，断言家徽按原尺寸居中（原版 `SimpleItemCell.setIcon` 同款）。
func _查家族页家徽格() -> void:
	var 窗 := (load("res://场景/界面/窗口/家族/家族窗口.tscn") as PackedScene).instantiate() as Control
	root.add_child(窗)
	await process_frame
	var 格 := Control.new()
	格.size = Vector2(40.0, 40.0)
	窗.add_child(格)
	窗.call("_画家徽格", 格, 1, 1000)
	await process_frame
	var 徽 := 格.get_node_or_null("家徽图") as TextureRect
	if 徽 == null:
		_失败.append("`_画家徽格` 没有补建「家徽图」")
	elif not 徽.size.is_equal_approx(Vector2.ONE * 家徽图.边长):
		_失败.append("家族页家徽格画成了 %s —— 应按原尺寸 %d 居中"
			% [str(徽.size), 家徽图.边长])
	elif 徽.texture == null:
		_失败.append("家族页家徽格没有贴图（样式 1000 应取到家徽_1000.png）")
	else:
		_查没覆色(徽, "家族页家徽格")
	# 悬停文案 = 原版 `FamillyManager.getJiaHuiJiaChengString`（逐项列该等级加成 + 全地图生效）
	var 文案 := 游戏数据.家徽加成文案(1)
	if not 文案.contains("1级家徽属性加成"):
		_失败.append("家徽格悬停文案的第一行不对：%s" % 文案)
	if not 文案.contains("2%生命上限"):
		_失败.append("家徽格悬停文案没列出属性（原版逐项列 `flag[等级].attr`，值在前名在后、rate 带%%）：%s" % 文案)
	if not 文案.contains("1%攻击") or not 文案.contains("1%防御"):
		_失败.append("家徽格悬停文案缺攻击/防御项：%s" % 文案)
	if not 文案.contains("（全地图生效）"):
		_失败.append("家徽格悬停文案缺「（全地图生效）」：%s" % 文案)
	if 格.tooltip_text != 文案:
		_失败.append("家徽格的 tooltip 没挂上加成文案，实为：%s" % 格.tooltip_text)
	窗.queue_free()
	await process_frame


const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
