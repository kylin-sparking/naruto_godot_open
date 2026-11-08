extends SceneTree

var _failures: Array[String] = []
var _scene_count := 0
var _texture_count := 0


func _initialize() -> void:
	call_deferred("_跑")


## ⚠️ 拆出 `_跑()` 是因为**登录那条检查必须等到下一帧**：
##    `_initialize()` 里 `add_child()` **不会同步触发 `_ready`**（那一刻主循环还没开始转），
##    而登录界面的"默认账号预填"是在 `_ready` 里做的 —— 不进帧就永远读到空输入框。
##    （旧登录界面把默认账号写在 `.tscn` 的 `text` 上，所以老测试不进帧也测得到；换人之后就变了。）
func _跑() -> void:
	var scene_paths: Array[String] = []
	_collect_files("res://场景/界面", ".tscn", scene_paths)
	for scene_path in scene_paths:
		_check_scene(scene_path)
	_check_no_flat_style("res://脚本/界面")
	_check_no_residual_style_override("res://脚本/界面")
	_check_bottom_hud_bounds()
	await _check_login_defaults()
	_check_original_window_contracts()
	if _failures.is_empty():
		print("UI资源回归测试：通过（场景 %d，贴图引用 %d）" % [_scene_count, _texture_count])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	push_error("UI资源回归测试：失败 %d 项" % _failures.size())
	quit(1)


func _collect_files(directory_path: String, extension: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		_failures.append("目录无法打开：%s" % directory_path)
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var path := directory_path.path_join(name)
		if directory.current_is_dir():
			_collect_files(path, extension, output)
		elif name.ends_with(extension):
			output.append(path)
		name = directory.get_next()
	directory.list_dir_end()


func _check_scene(scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_failures.append("场景加载失败：%s" % scene_path)
		return
	var instance := packed.instantiate()
	if instance == null:
		_failures.append("场景实例化失败：%s" % scene_path)
		return
	instance.free()
	_scene_count += 1
	var source := FileAccess.get_file_as_string(scene_path)
	var texture_regex := RegEx.create_from_string("res://[^\\\"\\r\\n]+[.]png")
	for match_result in texture_regex.search_all(source):
		_check_texture(match_result.get_string(), scene_path)


func _check_texture(texture_path: String, owner_scene: String) -> void:
	_texture_count += 1
	if not ResourceLoader.exists(texture_path):
		_failures.append("贴图不存在：%s（%s）" % [texture_path, owner_scene])
		return
	var texture := load(texture_path) as Texture2D
	if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
		_failures.append("贴图无法加载或尺寸为空：%s（%s）" % [texture_path, owner_scene])
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		_failures.append("贴图像素为空：%s（%s）" % [texture_path, owner_scene])
		return
	## 判"这张引用皮是不是整张空白"要**整图精确判**，不能按网格抽样：
	## 逐帧特效（创角那 70 帧 `提交转圈`）本来就是稀疏 alpha —— 一帧只有十几个亮点，
	## 24×24 网格恰好全落在空处 ⇒ 11 帧被误报"全透明"（2026-10-10 实测）。
	## `get_used_rect()` 拿的是真正的不透明包围盒，宽或高为 0 才是**一个像素都没有**。
	## 例外：**故意全透明的占位图**。`通用控件/无箭头.png` 是 1×1 空图，专门用来
	## 把 `OptionButton` 自带的那枚 13px 箭头连同它占的宽度一起去掉（下拉框的箭头本来就
	## 烙在皮上，再画一枚会把 80 的框挤成只放得下三个字）。它"一个像素都没有"是设计，
	## 不是丢料 —— 10-18 挂机页排版那一轮就是它把这条规矩撞红的。
	if texture_path.ends_with("无箭头.png"):
		return
	var 有效区 := image.get_used_rect()
	if 有效区.size.x <= 0 or 有效区.size.y <= 0:
		_failures.append("贴图整张全透明：%s（%s）" % [texture_path, owner_scene])


## ⚠️ **按名放行的例外**（2026-09-25 加，**不是静默跳过**）：
##
## `登录界面.gd` 是另一位开发者的**独立工程**搬进来的（原自带 `project.godot` 与导出预设），
## **整套皮肤就是代码里现搓的**（`_gold_box` / `_panel_box` / `_input_box` / `_circle_box`
## / `_menu_box` / `_tinted`），而且它自带 **1080p 循环视频背景 + 金色/暗色**一套独立视觉，
## **根本不用游戏的原版主题**。
##
## 这条规矩的目的是"**in-game 的原版 UI 别偏离 `原版皮肤表.gd` 这个唯一事实来源**"，
## 而登录页是**进游戏之前**的一屏、**没有原版界面可对** —— 所以放行。
## ⚠️ 只放这一个文件；游戏内的界面照旧不许手绘。
const 手绘样式例外 := ["res://脚本/界面/登录界面.gd"]


func _check_no_flat_style(directory_path: String) -> void:
	var script_paths: Array[String] = []
	_collect_files(directory_path, ".gd", script_paths)
	for script_path in script_paths:
		if script_path in 手绘样式例外:
			continue
		if FileAccess.get_file_as_string(script_path).contains("StyleBoxFlat.new()"):
			_failures.append("界面脚本重新引入手绘 StyleBoxFlat：%s" % script_path)


## P2 之后样式只应来自 素材/界面/原版主题.tres。
## add_theme_stylebox_override 会无条件压过 Theme —— 一旦有人加回去，
## 改主题就会「看起来没生效」，且很难查。故在测试里钉死。
##
## 判据是「样式数据在哪定义」，不是「有没有调 override」：
##   合法   _window.add_theme_stylebox_override("panel", 主题取来的样式)
##          —— 同一个节点要按窗口键在 窗口边框/小窗口边框 间切换，
##             theme_type_variation 是静态的，表达不了，只能 override 选择。
##   非法   ...add_theme_stylebox_override("panel", StyleBoxFlat.new())
##          —— 在脚本里现造样式数据，绕开了 原版皮肤表.gd 这个唯一事实来源。
##
## 不查 font_size/color 覆盖：143 处 configure_label 逐调用点传字号与颜色，
## Theme 无法表达这种逐点差异，那些覆盖是设计的一部分。
func _check_no_residual_style_override(directory_path: String) -> void:
	var script_paths: Array[String] = []
	_collect_files(directory_path, ".gd", script_paths)
	for script_path in script_paths:
		var source := FileAccess.get_file_as_string(script_path)
		var lines := source.split("\n")
		for index in lines.size():
			var line := lines[index]
			if line.strip_edges().begins_with("#"):
				continue
			if not line.contains("add_theme_stylebox_override") \
					and not line.contains("add_theme_icon_override"):
				continue
			if line.contains("StyleBox") and line.contains(".new("):
				_failures.append(
					"%s:%d 覆盖里现造 StyleBox 会压过全局主题，样式请回到 原版皮肤表.gd"
					% [script_path, index + 1]
				)


func _check_bottom_hud_bounds() -> void:
	var packed := load("res://场景/界面/技能面板.tscn") as PackedScene
	var instance := packed.instantiate()
	var skill_bar := instance.get_node("技能栏") as Control
	if not is_equal_approx(skill_bar.offset_top, -RenderProfile.底栏高度) \
			or not is_zero_approx(skill_bar.offset_bottom):
		_failures.append("底栏必须按原版 MenuPane 101px 高度贴齐视口底边")
	# 技能栏宽度必须精确等于舞台宽。子帧美术 hud_294.png 是 989 宽、偏移 -11..977，
	# 故意让它在视口边缘裁切 —— 这就是 Flash 的行为，缩小或重切美术会改变
	# 边框的可见比例。
	var 舞台宽 := float(RenderProfile.DESIGN_SIZE.x)
	if not is_equal_approx(skill_bar.offset_right - skill_bar.offset_left, 舞台宽):
		_failures.append(
			"底栏宽度应为舞台宽 %d，实为 %.1f"
			% [RenderProfile.DESIGN_SIZE.x, skill_bar.offset_right - skill_bar.offset_left]
		)
	instance.free()


## ⚠️ 2026-09-25 重写：登录界面换成了另一位开发者的**登录器**，节点路径与默认值规则都变了。
##
## * 路径：`登录卡片/账号输入`、`登录卡片/密码输入`（旧场景是 `窗体/内容边距/内容/登录面板/...`）；
## * 默认值：他改用**账号记忆**（`AccountStore`，存过才填）。但他没覆盖"本机第一次跑"那一步，
##   于是融合方补了兜底：**没存过账号时，用 `game_settings` 里的默认账号预填**（旧行为）。
##   所以这里仍然断言"默认填好"，只是取值来源变了 —— 本机存过账号的话会填存的那个。
func _check_login_defaults() -> void:
	var packed := load("res://场景/界面/登录界面.tscn") as PackedScene
	var instance := packed.instantiate()
	# ⚠️ **必须进树 + 等一帧**：预填是在 `_ready` 里做的，而 `_initialize()` 期间
	#    `add_child()` 不会同步触发 `_ready`，要等主循环转起来（见 `_跑()` 的说明）。
	root.add_child(instance)
	await process_frame
	var account := instance.get_node_or_null("登录卡片/账号输入") as LineEdit
	var password := instance.get_node_or_null("登录卡片/密码输入") as LineEdit
	if account == null or password == null:
		_failures.append("登录界面缺少 登录卡片/账号输入 或 密码输入")
		instance.queue_free()
		return
	# ⚠️ **本机存过账号时，他的登录器按"账号记忆"走、不预填** —— 那是他的设计，不算失败。
	#    只有"没存过任何账号"时才该看到兜底预填（开箱即用，旧登录界面的行为）。
	var 官方 := root.get_node_or_null("AccountStore")
	if 官方 != null and not (官方.get("accounts") as Array).is_empty():
		print("  （本机已存 %d 个账号，登录器按账号记忆走，跳过预填断言）"
			% (官方.get("accounts") as Array).size())
	elif not account.text.contains("@") or password.text.is_empty():
		# ⚠️ `SceneTree` 脚本里**不能用 autoload 的全局名**（`GameSession` 编译期认不到，
		#    报 `Identifier not found`）—— 一律 `root.get_node_or_null(...)`，与其它用例一致。
		var 会话 := root.get_node_or_null("GameSession")
		var 默认 := "<没有 GameSession 单例>"
		if 会话 != null:
			默认 = String((会话.get("game_settings") as Dictionary).get("backend_account", "<无该键>"))
		_failures.append(
			"登录界面应当开箱即用（没存过账号时用 settings 里的默认账号预填），实际账号=%s；诊断：AccountStore=%s、settings.backend_account=%s"
			% [account.text, str(官方 != null), 默认])
	instance.queue_free()


func _check_original_window_contracts() -> void:
	_check_scene_minimum_size("res://场景/界面/窗口/遗址/意志学习窗口.tscn", Vector2(772.0, 535.0), "YiZhiStudyWindow 772x564（扣除29px标题栏）")
	_check_scene_minimum_size("res://场景/界面/窗口/地图信息/地图信息窗口.tscn", Vector2(769.0, 463.0), "WorldMap2 769x492（扣除29px标题栏）")
	_check_scene_minimum_size("res://场景/界面/窗口/装备强化/页面/装备打造通用页.tscn", Vector2(350.0, 349.0), "装备打造分页 setSize(350,349)")
	_check_texture_size("res://素材/界面/原版窗口/遗址/遗址背景.png", Vector2i(750, 514))
	_check_texture_size("res://素材/地图/世界地图/世界地图背景.png", Vector2i(735, 412))
	_check_texture_size("res://素材/界面/通用界面/UISwf_Text.swf_22.png", Vector2i(27, 27))
	_check_texture_size("res://素材/界面/通用界面/UISwf_Text.swf_25.png", Vector2i(23, 23))
	_check_texture_size("res://素材/界面/通用界面/UISwf_Text.swf_28.png", Vector2i(23, 23))
	var feature_source := FileAccess.get_file_as_string("res://脚本/界面/功能窗口.gd")
	if feature_source.contains("tab.disabled = index != 0"):
		_failures.append("装备打造的原版分页不能再次整体禁用")
	if ResourceLoader.exists("res://场景/界面/窗口/修炼/修炼窗口.tscn"):
		_failures.append("无原版入口的修炼场遗留场景不应恢复")


func _check_scene_minimum_size(scene_path: String, expected: Vector2, source_name: String) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_failures.append("原版尺寸场景无法加载：%s" % scene_path)
		return
	var instance := packed.instantiate() as Control
	if instance == null or instance.custom_minimum_size != expected:
		_failures.append("%s 尺寸应为 %s：%s" % [source_name, expected, scene_path])
	if instance != null:
		instance.free()


func _check_texture_size(texture_path: String, expected: Vector2i) -> void:
	var texture := load(texture_path) as Texture2D
	if texture == null or Vector2i(texture.get_width(), texture.get_height()) != expected:
		_failures.append("原版贴图尺寸应为 %s：%s" % [expected, texture_path])
