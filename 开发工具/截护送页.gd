extends SceneTree

## 量「油女志乃 · 护送族两扇」的运行期实机图（2026-10-06）。
##
## 为什么单独一份量具：`截木叶村NPC页.gd` 量的是**25 枚 NPC 的对话窗**，主窗「护送任务」
## 走它的 selection 行判据（`任务行判据` 第三条）已经拍得到；但第二扇「护送提示」
## **没有 NPC 入口**（原版是踩到地上那枚护送标记才弹，`HuSongQuestManager.as:609-613`）
## ⇒ 那份量具的判据模型里根本没有它这一格，硬塞进去会把「按 NPC 编号驱动」的口径搞脏。
##
## 出三样东西：
##   ① `护送_主窗.png` / `护送_提示窗.png`（整屏图，裁图按 `几何.txt` 里的矩形）
##   ② `几何.txt`（两扇的 `遮罩/主窗口.get_global_rect()` + 页面里逐件全局矩形）
##   ③ 退出码：外框与 `数据/界面/窗口尺寸.json` 不一致 ⇒ 1（量具先报错，别拿错坐标去比图）
##
## ⚠ 两条本工程量具的硬口径：
##   · **不能加 `--headless`**（无头拿不到视口图像）；
##   · 改状态与拍图**分两步**（`root.get_texture().get_image()` 拍到的是上一帧画完的果）；
##   · 出图前**关掉 HUD 那几层**（口径见下面 `HUD层` 那段：只有 `系统消息` 真会画到窗面上，
##     聊天/技能/头像/小地图本来就画在窗下面）；旧注释说的"HUD 盖住窗口 ⇒ 点不到"
##     是**命中**层的错（2026-10-06 已修在 `窗口管理.gd:重排层级`），不是画序。
##
## 用法：Godot --path . --script res://开发工具/截护送页.gd -- --出目录=res://测试/截图/护送

const 尺寸表 := "res://数据/界面/窗口尺寸.json"
## 出图前关掉的 HUD CanvasLayer。
## ⚠ 旧版这里写的理由是错的（"它们排在 `窗口管理` 之后 ⇒ 画在窗口之上"）：
##   `地图场景.tscn` 的树序是 头像/小地图/聊天/技能 **在前**、`窗口管理` 110 在中、`系统消息` 110 在后，
##   而**画序**按 CanvasLayer 叠（20/100 < 110）⇒ 只有同为 110 且创建在后的 `系统消息`
##   真会把 `_通知` 的长句糊在窗面上。关其余几层只是让图干净，别再拿它们当"窗点不到"的解释。
const HUD层 := ["头像面板", "小地图面板", "聊天面板", "技能面板", "系统消息"]
## [页名, 图名, 期望宽, 期望高]
const 页表 := [["护送任务", "护送_主窗.png", 578, 342], ["护送提示", "护送_提示窗.png", 300, 170]]
## 主窗里逐件量这几件的全局矩形（对原版截图时按它们，别肉眼估）
const 钉件 := ["等级条底", "奖格0", "奖格4", "双倍说明", "护送规则钮", "刷新钮",
		"自动刷新槽", "品质下拉槽", "为止", "开始钮"]

var 出目录 := ""
var 行: Array[String] = []
var 有错 := false
var 帧 := 0
var 场景: Node
var 队列: Array[Callable] = []
var 等待 := 0


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2 and 键值[0] == "--出目录":
			出目录 = 键值[1]
	if 出目录.is_empty():
		出目录 = "res://测试/截图/护送"
	if not DirAccess.dir_exists_absolute(出目录):
		DirAccess.make_dir_recursive_absolute(出目录)
	队列.append(_步开图)
	for 组 in 页表:
		队列.append(_步开页.bind(String(组[0])))
		队列.append(_步拍.bind(String(组[0]), String(组[1]), int(组[2]), int(组[3])))
	队列.append(_步收尾)


func _process(_d: float) -> bool:
	帧 += 1
	if 等待 > 0:
		等待 -= 1
		return false
	if 帧 < 10:
		return false
	if 队列.is_empty():
		return true
	队列.pop_front().call()
	return false


func _步开图() -> void:
	var 地图 := load("res://场景/地图/地图场景.tscn") as PackedScene
	场景 = 地图.instantiate()
	root.size = Vector2i(960, 560)
	root.add_child(场景)
	等待 = 6


func _步开页(页名: String) -> void:
	var 管理 := 场景.get_node_or_null("窗口管理")
	if 管理 == null:
		_错("地图场景下没有 窗口管理")
		return
	管理.call("全部关闭")
	管理.call("打开", 页名)
	for 名 in HUD层:
		# ⚠ `聊天面板`/`系统消息` 是 **CanvasLayer**，不是 CanvasItem ⇒ `as CanvasItem` 会得到
		#   null、看起来像"节点不存在"（本轮就这么假红过一次）。一律走 `set("visible", …)`。
		var 件: Node = 场景.get_node_or_null(名)
		if 件 == null:
			_错("地图场景里没有「%s」节点 ⇒ 结构变了，先重核" % 名)
			continue
		件.set("visible", false)
	# 高窗贴右下会被屏缘切掉 ⇒ 统一挪到 (8,8)（只动窗体 position，不改版式）
	var 窗: Node = 管理.call("取或建窗口", 页名) as Node
	if 窗 == null:
		_错("%s 取不到窗口实例" % 页名)
		return
	var 主窗 := 窗.get_node_or_null("遮罩/主窗口") as Control
	if 主窗 == null:
		_错("%s 开不出 遮罩/主窗口" % 页名)
		return
	主窗.position = Vector2(8.0, 8.0)
	等待 = 4
	行.append("%s：外框全局矩形 %s（HUD 已关 %s）" % [页名, str(主窗.get_global_rect()), " + ".join(HUD层)])


func _步拍(页名: String, 图名: String, 宽: int, 高: int) -> void:
	var 管理 := 场景.get_node_or_null("窗口管理")
	var 窗: Node = 管理.call("取或建窗口", 页名) as Node
	if 窗 == null:
		_错("%s 取不到窗口实例" % 页名)
		return
	var 主窗 := 窗.get_node_or_null("遮罩/主窗口") as Control
	if 主窗 == null:
		_错("%s 没开出来，拍不了" % 页名)
		return
	var 尺: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(尺寸表)) as Dictionary).get(页名, {})
	_记(int(尺.get("宽", -1)) == 宽 and int(尺.get("高", -1)) == 高 \
			and absf(主窗.size.x - float(宽)) < 0.6 and absf(主窗.size.y - float(高)) < 0.6,
			"%s 外框 %.0f×%.0f（期望 %d×%d，尺寸表 %s×%s）"
			% [页名, 主窗.size.x, 主窗.size.y, 宽, 高, str(尺.get("宽")), str(尺.get("高"))])
	var 图 := root.get_texture().get_image()
	var 路 := 出目录 + "/" + 图名
	图.save_png(路)
	行.append("  截图 %s（%dx%d，%s）" % [路, 图.get_width(), 图.get_height(),
			"ok" if ResourceLoader.exists(路) or FileAccess.file_exists(路.replace("res://", "")) else "?"])
	if 页名 == String(页表[0][0]):
		for 件名 in 钉件:
			var 件 := 主窗.get_node_or_null("页面容器/原版护送任务内容/" + 件名) as Control
			if 件 == null:
				_错("主窗里量不到「%s」" % 件名)
				continue
			行.append("  %s 全局 %s" % [件名, str(件.get_global_rect())])


func _步收尾() -> void:
	var 路 := 出目录 + "/几何.txt"
	var f := FileAccess.open(路, FileAccess.WRITE)
	if f == null:
		_错("写不了 %s" % 路)
	else:
		for 一 in 行:
			f.store_line(一)
		f.close()
	for 一 in 行:
		print(一)
	print("截护送页：%s（红 %d 项）" % ["通过" if not 有错 else "不通过", 0 if not 有错 else 1])
	quit(1 if 有错 else 0)


func _记(过: bool, 文: String) -> void:
	if not 过:
		有错 = true
	行.append("  %s %s" % ["√" if 过 else "!!", 文])


func _错(文: String) -> void:
	有错 = true
	行.append("!! " + 文)
