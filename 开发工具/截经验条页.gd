extends SceneTree

## #180 的**有头**量具：底栏那根经验条 + 真人物窗口那根，各拍两种经验下的图，
## 并读出运行期真正生效的数字（shader 的 progress、ProgressBar 的 value/max_value、百分比文字）。
## ⚠ 不能加 `--headless`（无头拿不到视口图像；实测 技能面板.tscn 在无头里会卡住）。
## 跑法：godot --path . --script res://开发工具/截经验条页.gd

const 出 := "res://测试/截图/经验条/"
const 表脚本 := preload("res://脚本/单例/等级经验表.gd")

var 日志: Array[String] = []
var 红 := 0
var 判 := 0
var 存前 := PackedByteArray()
var 收 := false


func _写() -> void:
	var f := FileAccess.open(出 + "数值.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(日志) + "\n")
		f.close()


func _步(说: String) -> void:
	日志.append("· " + 说)
	_写()


func _判(过: bool, 说: String) -> void:
	判 += 1
	日志.append("%s %s" % ["ok " if 过 else "!!红", 说])
	if not 过:
		红 += 1
	_写()


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _字节(路: String) -> PackedByteArray:
	if not FileAccess.file_exists(路):
		return PackedByteArray()
	var g := FileAccess.open(路, FileAccess.READ)
	if g == null:
		return PackedByteArray([1])
	var 字 := g.get_buffer(g.get_length())
	g.close()
	return 字


func _initialize() -> void:
	call_deferred("_跑")
	call_deferred("_看门狗")


func _看门狗() -> void:
	var 截止 := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < 截止 and not 收:
		await create_timer(0.2).timeout
	if 收:
		return
	_判(false, "看门狗：90 秒没跑到汇总（看最后一条 `·` 停在哪一步）")
	_尾()


func _尾() -> void:
	if 收:
		return
	收 = true
	_判(_字节("user://玩家数据.json") == 存前, "量具不许动存档（user://玩家数据.json 字节一致）")
	日志.append("汇：判 %d 条 / 红 %d 条" % [判, 红])
	_写()
	quit(0 if 红 == 0 else 1)


func _找(根: Node, 名: String) -> Node:
	for 子 in 根.get_children():
		if String(子.name) == 名:
			return 子
		var 得 := _找(子, 名)
		if 得 != null:
			return 得
	return null


func _读进度(填: TextureRect) -> float:
	if 填 == null or 填.material == null:
		return -1.0
	return float(填.material.get_shader_parameter("progress"))


func _拍(名: String) -> void:
	var 图 := root.get_texture().get_image()
	图.save_png(出 + 名 + ".png")


## 数一根条里"亮着的列"有几列：每 3 列取一条竖线、每 2 行取一个点，
## 亮列 = 该列亮点数 >= 该图最大亮点数的一半。只用来比"变长没有"，不当像素门。
func _亮列(名: String) -> int:
	var 图 := Image.load_from_file(ProjectSettings.globalize_path(出 + 名 + ".png"))
	if 图 == null:
		return -1
	var 面 := root.get_node_or_null("技能面板")
	var 填: TextureRect = null
	if 面 != null:
		填 = 面.get_node_or_null("技能栏/ExperienceFill") as TextureRect
	var 框 := Rect2i(0, 0, 图.get_width(), 图.get_height())
	if 填 != null:
		var r := 填.get_global_rect()
		框 = Rect2i(int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y))
	框 = 框.intersection(Rect2i(0, 0, 图.get_width(), 图.get_height()))
	if 框.size.x <= 0 or 框.size.y <= 0:
		return -1
	var 段 := 图.get_region(框)
	var 列: Array[int] = []
	var 最高 := 0
	for x in range(0, 段.get_width(), 3):
		var 计 := 0
		for y in range(2, maxi(4, 段.get_height() - 2), 2):
			if 段.get_pixel(x, mini(y, 段.get_height() - 1)).v > 0.30:
				计 += 1
		列.append(计)
		最高 = maxi(最高, 计)
	var 亮 := 0
	for v in 列:
		if v >= int(最高 * 0.5):
			亮 += 1
	return 亮 * 3


func _跑() -> void:
	存前 = _字节("user://玩家数据.json")
	_步("0) 钉窗口尺寸")
	root.size = Vector2i(960, 560)
	var 会 = root.get_node_or_null("GameSession")
	if 会 == null:
		_判(false, "缺 GameSession 单例")
		_尾()
		return
	var 底 := ColorRect.new()
	底.name = "灰底"
	底.color = Color(0.12, 0.11, 0.10)
	root.add_child(底)
	底.size = Vector2(960, 560)
	_步("1) 喂 {level:7, exp:300}（本级所需 = 表[7] = %d）" % 表脚本.本级所需(7))
	会.apply_backend_character({"level": 7, "exp": 300.0, "maxHp": 5000, "hp": 3000,
			"maxMp": 2000, "mp": 900})
	_步("2) load 技能面板场景")
	var 包: PackedScene = load("res://场景/界面/技能面板.tscn")
	_判(包 != null, "技能面板场景能 load")
	if 包 == null:
		_尾()
		return
	_步("3) 实例化并 add_child")
	# ⚠ 场景根是 **CanvasLayer**（`技能面板.tscn:38`），当 Control 拿会得到 null
	var 面: CanvasLayer = 包.instantiate() as CanvasLayer
	root.add_child(面)
	_步("4) 等 6 帧")
	await _帧(6)
	var 填: TextureRect = 面.get_node_or_null("技能栏/ExperienceFill") as TextureRect
	_判(面 != null, "技能面板实例化出来了（根是 CanvasLayer）")
	if 面 == null:
		_尾()
		return
	_判(填 != null, "找得到 技能栏/ExperienceFill")
	if 填 == null:
		_尾()
		return
	var 进度甲 := _读进度(填)
	_步("5) 拍底栏甲")
	_拍("底栏_经验300")
	_判(absf(进度甲 - 300.0 / 1196.0) < 0.001,
			"底栏 shader progress = %.4f，应当 = 300/1196 = %.4f" % [进度甲, 300.0 / 1196.0])
	_判(进度甲 > 0.0 and 进度甲 < 1.0, "这根条既不空也不顶满（修前恒 1.0）")
	_步("6) 喂 exp=900")
	会.apply_backend_character({"exp": 900.0})
	await _帧(6)
	var 进度乙 := _读进度(填)
	_拍("底栏_经验900")
	_判(absf(进度乙 - 900.0 / 1196.0) < 0.001,
			"经验涨到 900 之后 progress = %.4f，应当 = 900/1196 = %.4f" % [进度乙, 900.0 / 1196.0])
	_判(进度乙 > 进度甲 + 0.4, "同一根条在两次之间真的变长了（%.4f → %.4f）" % [进度甲, 进度乙])
	var 甲 := _亮列("底栏_经验300")
	var 乙 := _亮列("底栏_经验900")
	_判(乙 > 甲 and 甲 > 0, "截图上量出来的亮段也变长了：%d → %d 列（≈像素宽）" % [甲, 乙])
	_步("7) 开真人物窗")
	var 窗场景 := load("res://场景/界面/功能窗口.tscn") as PackedScene
	_判(窗场景 != null, "功能窗口场景能 load")
	if 窗场景 == null:
		_尾()
		return
	var 窗: Node = 窗场景.instantiate()
	root.add_child(窗)
	await _帧(4)
	if 窗.has_method("open_page"):
		窗.call("open_page", "人物")
	_步("8) 等 10 帧后读面板经验条")
	await _帧(10)
	var 条 := _找(窗, "经验条") as ProgressBar
	var 文 := _找(窗, "经验数值") as Label
	_判(条 != null, "人物窗里找得到「经验条」")
	if 条 != null:
		_判(absf(条.max_value - 1196.0) < 0.01, "面板经验条 max_value = %.1f（= 表[7]）" % 条.max_value)
		_判(absf(条.value - 900.0) < 0.01, "面板经验条 value = %.1f（= 会话里的经验 900）" % 条.value)
	if 文 != null:
		_判(文.text == "75%", "面板那行百分比 = 「%s」（900/1196 四舍五入 = 75%%）" % 文.text)
	_拍("人物面板_经验900")
	_步("9) 再喂 exp=1100，看窗口不重开会不会跟着变")
	会.apply_backend_character({"exp": 1100.0})
	await _帧(8)
	# ⚠ 属性帧一到，`功能窗口._refresh_current()` 会**整页重画** ⇒ 上一轮那个 ProgressBar
	#   已经被 free 掉了（Godot 4 里失效引用比 null 相等）—— 必须重新找，不然这两条会静默跳过。
	条 = _找(窗, "经验条") as ProgressBar
	文 = _找(窗, "经验数值") as Label
	_判(条 != null and is_instance_valid(条), "重画之后还找得到「经验条」（没找=面板整个没了）")
	if 条 != null:
		_判(absf(条.value - 1100.0) < 0.01 and absf(条.max_value - 1196.0) < 0.01,
				"再喂 exp=1100 之后 value=%.1f / max=%.1f（窗口没重开也跟着变）" % [条.value, 条.max_value])
	if 文 != null:
		_判(文.text == "92%", "百分比文字跟着变 = 「%s」（1100/1196=91.98%%）" % 文.text)
	_拍("人物面板_经验1100")
	_尾()
