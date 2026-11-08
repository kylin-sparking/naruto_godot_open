extends RefCounted

## 忍术窗口的渲染。布局口径一律来自 2.2.3 反编译的 AS3：
##
## - **树**：每个页签用**不同的元件**（`SkillWindow.as:100`
##   `tabBtns = [tabBtn1, tabBtn2, tabBtn4, tabBtn3, tabBtn5]`，显示顺序 1,2,4,3,5），
##   逐格坐标取自各元件（`SkillPane1F/2F/3F` 的 `cells`，`SkillPane4.as setCellXY`、
##   `SkillPane5.as createCell`），见 `数据/界面/忍术树_箭头与元件.json`。
##   **格子数按页签不同**：职业忍术 15 / 世界忍术 18 / 其他忍术 12 / 奥义禁术 13 / 特别技能 8。
## - **详情**：`SkillDetailPane.as` —— 名称、层数、忍术类型、攻击目标、攻击范围、效果说明，
##   下半块按"未学 / 已学 / 未开放"三选一显示 `SkillStudyConditionPane`（学习方法）、
##   `SkillUpgradeConditionPane`（升级条件）或 `SkillUnopenPane`。

const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 忍术场景 := preload("res://场景/界面/窗口/忍术/忍术窗口.tscn")
const 忍术格拖拽脚本 := preload("res://脚本/界面/组件/忍术格拖拽.gd")
## `SkillDetailPane.practiseBar` 是 MBar ⇒ 填充走 0.5s 补间（真值 `真值/窗口/进度条补间.md` §⑤）。
const 进度条补间 := preload("res://脚本/单例/进度条补间.gd")
const 树元件表路径 := "res://数据/界面/忍术树_箭头与元件.json"
const 境界表路径 := "res://数据/界面/忍术境界.json"
const 树底图模板 := "res://素材/界面/原版窗口/忍术/忍术树底图_%s.png"
## 连接线**逐条**画（运行时就是逐条精灵：`arrow1..arrowN`）。
##
## 数据在 `数据/界面/忍术树_箭头与元件.json` 的「箭头」：每条带
## `格`（它指向的格子下标）/`元件`（`SkillArrow1..4` 的符号 id）/`x,y`/`缩放X,Y`。
## **缩放必须一起用**：长杆是 `arrow7/8` 用 `scale(1, 4.88)` 拉出来的，
## 只画精灵盒不乘缩放就只剩一堆小箭头（上一轮"长杆全没了"就是漏了这个）。
##
## 而"已学变橙"的规则在 `SkillPane.as`：
## `arrows[this._index].filters = cells[i].floor > 0 ? null : getDisableFilter()`，
## 也就是**指向第 i 格的那条**跟着第 i 格学没学走——实例名 `arrowN` 的 N 恒等于 i。
## 橙=原色（导出的箭头美术本来就是橙的），灰=同一套亮度矩阵，不需要另找素材。
##
## 画在**格子下面**（原版 arrows 的 depth 3~27 < cells 的 29+），
## 所以这一层在场景树里排在 `忍术格容器` 前面，长杆的顶端会被格子盖住——与原版一致。
const 箭头美术模板 := "res://素材/界面/原版窗口/忍术/忍术树箭头_%d.png"
## 跨函数传引用用的元数据键。**必须是 ASCII**——`set_meta` 会拒绝非 ASCII 键。
const 键_境界面板 := &"skill_jingjie_panel"
const 键_忍术详情 := &"skill_detail_pane"
## 境界面板的滑入/滑出补间（连点时要先杀掉上一个，否则两个补间同时写 position.x）
const 键_境界补间 := &"skill_jingjie_tween"
## 「忍术境界」按钮的底（原版符号 453 SkillWindowMButtonF 的导出，见 开发工具/生成忍术窗口底图.py）
const 境界按钮图 := "res://素材/界面/原版窗口/忍术/忍术境界按钮.png"

## 原版 SkillDetailPane 的取值颜色（AS3 里的字面量）
const 色_名称 := Color("fff600")      # BaseUtil.getLabel("", 16774656)
const 色_标签 := Color("ff9100")      # 16748800
const 色_值 := Color("00ff00")        # 65280
const 色_描述 := Color("fcc399")      # 效果说明正文（真机取色）
const 色_达标 := Color("007e06")      # 32262：需要等级/需要秘笈 达成时的文字色
const 色_未达 := Color("e00104")      # 14681092：未达成（红）
const 色_拖动提示 := Color("00ff00")
const 色_境达标 := Color("c7b14f")   # 13087055：境界达成时境名转金
const 色_境未达 := Color("939393")   # 9671571：未达成是灰
## 写轮眼阶名（下标 = 服务端 `stage`，1..12）。逐字来自
## `CN.SKILLSTUDYCONDITION_XUYAO_XIELUNYAN`（`CN.as:9655`，它按 TONGSHU_WINDOW_* 语言键取），
## 次序与 `人物窗口.写轮眼阶段` 一致（那边 0 基、这里 1 基）。
const 写轮眼阶名 := ["", "单勾玉", "双勾玉", "三勾玉", "月读", "天照", "须佐之男", "伊邪那歧",
	"永恒万花筒", "轮回眼", "六勾玉轮回眼", "轮回写轮眼", "净眼"]

## 2026-11-01 用户点名「忍术等级字体偏小」「升级条件里的数值字体也偏小」——
## 原版这些都是 12（`MLabel.as:219`），宋体内嵌点阵覆盖 12..17，所以 14 依然锐利
## （18 起退灰度，见 `字体清晰回归测试` 的点阵实测）。只放大用户点名的两类，其余仍 12。
const 忍术等级字号 := 14
const 升级条件数值字号 := 14

static var _树元件表: Dictionary = {}
static var _境界表: Dictionary = {}
static var _灰化图标缓存: Dictionary = {}


## 未学技能的图标 = 原版加了 `Style.getDisableFilter()` 的样子：一张**灰度的**技能图。
##
## 原版的图标美术本身是"彩色底 + 白色主体"（如体能强化是紫底白人形），
## 套上亮度矩阵 0.3086/0.6094/0.082 之后，彩色底压成贴近格底的暗灰、白色主体仍是白，
## 看上去就是一张纯黑白图——所以这里要的就是**按亮度转灰**，不是调暗、也不是调透明度。
##
## 实现用**换纹理**而不是着色器：着色器那版踩过"材质明明赋上了、渲染却不生效"的坑
## （同一份代码在「职业忍术」页生效、在「特别技能」页不生效），换纹理没有这层不确定性。
## 图标是 34x34 的常量图，转一次缓存住即可。
static func _灰化图标(路径: String) -> Texture2D:
	if 路径.is_empty():
		return null
	if _灰化图标缓存.has(路径):
		return _灰化图标缓存[路径]
	var 原纹理 := load(路径) as Texture2D
	if 原纹理 == null:
		return null
	var 图 := 原纹理.get_image()
	图.convert(Image.FORMAT_RGBA8)
	for y in 图.get_height():
		for x in 图.get_width():
			var 像素 := 图.get_pixel(x, y)
			var 亮度 := 0.3086 * 像素.r + 0.6094 * 像素.g + 0.082 * 像素.b
			图.set_pixel(x, y, Color(亮度, 亮度, 亮度, 像素.a))
	var 纹理 := ImageTexture.create_from_image(图)
	_灰化图标缓存[路径] = 纹理
	return 纹理


static func _取树元件表() -> Dictionary:
	if not _树元件表.is_empty():
		return _树元件表
	var 文件 := FileAccess.open(树元件表路径, FileAccess.READ)
	if 文件 == null:
		push_error("忍术树元件表缺失：%s" % 树元件表路径)
		return {}
	var 解析结果: Variant = JSON.parse_string(文件.get_as_text())
	文件.close()
	if typeof(解析结果) != TYPE_DICTIONARY:
		push_error("忍术树元件表不是合法 JSON 对象：%s" % 树元件表路径)
		return {}
	_树元件表 = 解析结果 as Dictionary
	return _树元件表


static func _取境界表() -> Dictionary:
	if not _境界表.is_empty():
		return _境界表
	var 文件 := FileAccess.open(境界表路径, FileAccess.READ)
	if 文件 == null:
		push_error("忍术境界表缺失：%s" % 境界表路径)
		return {}
	_境界表 = JSON.parse_string(文件.get_as_text()) as Dictionary
	文件.close()
	return _境界表


## 总忍术层数 = 所有已学技能的层数之和（`DataCenter.as:3047 getTotalSkillLevel`）。
## 右上角「忍术境界」按钮在它 >= 50 时才出现（`SkillWindow.as:258`）。
## 技能**现在就能升**吗 —— `SkillCell.refreshUpgradeState`：
## `层数 > 0 && 层数 < 100 && 人物等级 >= 需等级 && 金币 >= 需金币 && 精华 >= (总量 − 熟练度)`。
## 满足时格子的 (4,4) 处会挂一个 `SkillPlusPicF`（符号 711，黄橙十字）。
static func _可升级(窗口, 忍术: Dictionary) -> bool:
	var 等级 := int(忍术.get("level", 0))
	if 等级 <= 0 or 等级 >= 100:
		return false
	var 需求 := GAME_DATA.skill_upgrade_req(等级 + 1, int(String(忍术.get("id", ""))))
	if 需求.size() < 3:
		return false
	var 属性: Dictionary = 窗口._session.player_stats
	return (int(属性.get("level", 0)) >= int(需求[0])
		and int(属性.get("gold", 0)) >= int(需求[1])
		and int(属性.get("zq", 0)) >= maxi(0, int(需求[2]) - int(忍术.get("master_level", 0))))


static func _总忍术层数(窗口) -> int:
	## 境界合计 = 每门忍术的**基础层 + 加层**。加层走 `getAddedSkillLevel` 那条口径
	## （玉链/忍具/勾玉 + 世界/职业加成，`游戏会话.added_skill_level`
	## `DataCenter.as:795-810`）—— 只数 `learned_skills` 里的 `level` 会把装备加成全漏掉
	## （用户 2026-11-07 报「境界层数合计没有加上灵器、忍具、勾玉增加的忍术层数」）。
	## 口径统一放在会话上：头顶那枚境界图标也读它，不然合计涨了境界不涨。
	return 窗口._session.total_skill_level()


## 格子里的层数文字。原版 `SkillCell.as:216-227`：`floorText = floor`，只有
## **自己会的、基础层 > 0、加层 > 0** 三样同时成立才写成 `基础+N`。
## ⚠️ 详情区的「层数」**不跟**：`SkillDetailPane.as:160` 只印 `param1.floor`（基础层）。
static func 层数文字(忍术: Dictionary) -> String:
	var 基础 := int(忍术.get("level", 0))
	var 加成 := int(忍术.get("added_level", 0))
	if 基础 > 0 and 加成 > 0:
		return "%d+%d" % [基础, 加成]
	return str(基础)


static func 渲染(窗口) -> void:
	var 页面 := 忍术场景.instantiate() as Control
	窗口._apply_common_control_skins(页面)
	窗口._content.add_child(页面)

	# 页签。名称与顺序见 功能窗口.忍术页签名（原文 SKILL_TAB_BTN_TEXTS_1..5）。
	var 分页名称: Array = 窗口.忍术页签名
	for 序号 in 分页名称.size():
		var 分页 := 页面.get_node("分页/%s" % 分页名称[序号]) as Button
		# 页签宽 61、间距 62 —— `SkillWindow.init()` 把每个 tabBtn 的 width 设成
		# `UIConfig.btn_width_four`(=61)，x 从 tabBtn1.x 起每次 `+= width + 1`。
		窗口._configure_overlay_button(分页, Vector2(61.0, 22.0))
		分页.button_pressed = 序号 == 窗口._skill_tab
		分页.pressed.connect(窗口._set_skill_tab.bind(序号))
	_渲染境界(窗口, 页面)
	_渲染树(窗口, 页面)
	_渲染详情(窗口, 页面)


## 右上角「忍术境界」按钮 + 从右滑入的境界面板（`SkillWindow.as:405-440`）。
## 按钮文案是 `CN.SKILL_STATE`=「忍术境界」，**不是**"忍术状态"。
static func _渲染境界(窗口, 页面: Control) -> void:
	var 表 := _取境界表()
	var 总 := _总忍术层数(窗口)
	var 按钮 := 页面.get_node("分页/忍术状态") as Button
	按钮.text = String(表.get("按钮文案", "忍术境界"))
	# 「忍术境界」按钮：`stateBtn.width = UIConfig.btn_width_four`(61)、
	# `x = width - stateBtn.width - 10`（窗口宽 462 → x=391，内容坐标 381）。
	窗口._configure_overlay_button(按钮, Vector2(61.0, 22.0))
	# 按钮的**底**用原版美术（`#453 SkillWindowMButtonF`，57x22）：底图里烘着一个作者期的
	# stateBtn（在 x=387，运行时在 391），两个错位叠着看就是"字没居中"。
	# 底图已经把它抹掉，这里自己画——`configure_overlay_button` 对非 toggle 按钮会设
	# `flat = true`（不画底），所以要把底贴回来。
	if ResourceLoader.exists(境界按钮图):
		var 底: StyleBoxTexture = 窗口._texture_style(境界按钮图)
		for 态 in ["normal", "hover", "pressed", "disabled", "focus"]:
			按钮.add_theme_stylebox_override(态, 底)
		按钮.flat = false
	# 原版解锁条件就是这一条：总层数 ≥ 50
	按钮.visible = 总 >= int(表.get("解锁门槛", 50))
	按钮.tooltip_text = "查看忍术境界"

	var 面板 := 页面.get_node("境界区/境界面板") as Control
	# ⚠️ 从**窗口上存的展开态**还原，而不是一律"收起"起始：
	# 服务端推送（`skills_changed` 等）随便来一条就会让窗口 `_refresh_current()` 重建整页，
	# 若这里写死收起，用户看到的就是「点开又自动返回忍术面板」（2026-09-26 报的）。
	# 与页签 `_skill_tab`、选中技能 `_selected_skill_id` 是同一套做法。
	面板.visible = 窗口._境界展开
	面板.position.x = 0.0 if 窗口._境界展开 else 210.0   # 基准偏移 0..210，滑入即 210 → 0
	var 档位: Array = 表.get("档", [])
	for i in 档位.size():
		var 一格: Dictionary = 档位[i]
		var 门槛 := int(一格.get("门槛", 0))
		var 达标 := 总 >= 门槛
		var 图标 := 面板.get_node("境界图标_%d" % i) as TextureRect
		var 图标路径 := "res://素材/界面/原版窗口/忍术/境界图标_%d.png" % i
		if ResourceLoader.exists(图标路径):
			图标.texture = load(图标路径) as Texture2D if 达标 else _灰化图标(图标路径)
		_设标签(窗口, 面板, "境界名_%d" % i, String(一格.get("境名", "")),
			12, 色_境达标 if 达标 else 色_境未达)
		_设标签(窗口, 面板, "境界说明_%d" % i,
			String(表.get("说明模板", "")).replace("%1", str(门槛)), 12, 色_描述)
	_设标签(窗口, 面板, "境界合计",
		String(表.get("合计模板", "")).replace("%1", str(总)), 12, 色_值)

	按钮.pressed.connect(_切换境界.bind(窗口))
	# ⚠️ 元数据键只能用 ASCII：Godot 4.7 的 `set_meta` 会拒绝「忍术详情」这种非 ASCII 键
	# （报 Invalid metadata identifier 并**静默不写**），于是 `get_meta` 拿回 null、
	# 境界面板的滑入/滑出直接退出——按钮点了没反应。这里改成 ASCII 键。
	窗口.set_meta(键_境界面板, 面板)
	# 境界面板的背景是**半透明**的（符号 936 的底色 (57,38,32, α=129)），
	# 原版靠 `BaseUtil.createMask` 把详情区盖住才不透。客户端就把详情区藏掉。
	var 详情 := 页面.get_node("忍术详情") as CanvasItem
	窗口.set_meta(键_忍术详情, 详情)
	# 展开态下重建页面时，详情区也要跟着藏回去（`_切换境界` 里是立刻切的，这里补同一件事）
	详情.visible = not 窗口._境界展开
	# 旧补间指向的是**已经被释放的旧面板**，留着只会在下次点击时被判无效；
	# 清掉更省事（`_切换境界` 本来也有 kill 兜底）。
	窗口.remove_meta(键_境界补间)


## 从右滑入 / 滑出。原版是 `TweenLite.to(…, 0.6, {x: detailPane.x})`，
## 同时 `TweenLite.to(detailPane, 0.6, {alpha: …})` 把详情区淡出/淡入。
##
## ⚠️ 判据必须是**面板现在滑到哪儿了**，不能是 `visible`。
## `visible` 一旦打开就再没被置回 false，所以第二次点击起都会走"收起"那条分支，
## 于是面板一边滑回来、详情区一边被显示——两层叠在一起（实机上来回点两下就复现）。
## 也不能只看"是不是正好在 210"：动画中途连点会取到中间值，方向就猜反了，
## 所以取 0 与 210 的中点当判据（等价于"离哪边近"）。
static func _切换境界(窗口) -> void:
	var 面板: Variant = 窗口.get_meta(键_境界面板, null)
	if 面板 == null:
		return
	var 控件 := 面板 as Control
	var 详情 := 窗口.get_meta(键_忍术详情, null) as CanvasItem
	var 收起着 := absf(控件.position.x - 210.0) < absf(控件.position.x - 0.0)
	var 目标 := 0.0 if 收起着 else 210.0
	控件.visible = true
	# 展开态**存在窗口上**：页面被 `_refresh_current()` 重建时靠它还原（见 `_渲染境界`）。
	窗口._境界展开 = 目标 == 0.0
	# 旧补间要先杀掉：`create_tween` 不会自动顶掉上一个，两个补间同时写 position.x 会打架。
	if 窗口.has_meta(键_境界补间):
		var 旧: Variant = 窗口.get_meta(键_境界补间)
		if 旧 is Tween and (旧 as Tween).is_valid():
			(旧 as Tween).kill()
	var 补间 := 控件.create_tween()
	窗口.set_meta(键_境界补间, 补间)
	补间.tween_property(控件, "position:x", 目标, 0.6)
	if 详情 != null:
		# 面板滑进去的时候详情区要**立刻**藏掉：境界底板是半透明的（符号 936 底色 α=129），
		# 原版靠 `BaseUtil.createMask` 盖住，客户端直接藏；收起时立刻还回来。
		详情.visible = 目标 == 210.0


## 树：底图与逐格坐标都按当前页签换。
static func _渲染树(窗口, 页面: Control) -> void:
	var 页签名: String = String(窗口.忍术页签名[窗口._skill_tab])
	var 可见忍术: Array[Dictionary] = 窗口._skills_for_tab(窗口._skill_tab)
	var 元件: Dictionary = (_取树元件表().get("页签", {}) as Dictionary).get(页签名, {})

	var 底图路径 := 树底图模板 % 页签名
	var 底图 := 页面.get_node("忍术树底图") as TextureRect
	底图.texture = load(底图路径) as Texture2D if ResourceLoader.exists(底图路径) else null

	_渲染连接线(窗口, 页面, 元件, 可见忍术)

	# 默认选中第 0 格 —— 原版 `SkillPane.setDefaultSkill()` 就是 `setSelectedCell(cell0)`。
	# ⚠️ 必须在这里定死：详情区那一步也会补 `_selected_skill_id`，但它跑在树的后面，
	# 而树已经画完了——于是"当前格"的橙圈第一屏永远不出现（并排图里能看到）。
	if not 可见忍术.is_empty():
		var 有选中 := false
		for 忍术 in 可见忍术:
			if String(忍术.get("id", "")) == String(窗口._selected_skill_id):
				有选中 = true
				break
		if not 有选中:
			窗口._selected_skill_id = String(可见忍术[0].get("id", ""))

	var 格位置: Array = 元件.get("格", [])
	var 容器 := 页面.get_node("忍术格容器") as Control
	# 「其他忍术」页的树分两块，两块各有自己的小标题。标题是 `SkillPane4.newTextField()`
	# 运行时 new 出来的（`jiazuSkill` 摆在 cell0 上方 4px、`fuqiSkill` 摆在 cell8 上方 4px，
	# 都是 `<font color="#ff9100">`），只有这一页有。
	var 有分节 := 页签名 == "其他忍术"
	(容器.get_node("家族忍术") as CanvasItem).visible = 有分节
	(容器.get_node("羁绊忍术") as CanvasItem).visible = 有分节
	# 按名字取，**不能用 get_children()**：容器里除了格子还摆着两块小标题，
	# 按序号遍历会把 Label 当按钮、报 "Invalid assignment ... on Nil"。
	for 序号 in 容器.get_child_count():
		var 格子 := 容器.get_node_or_null("忍术格_%d" % 序号) as Button
		if 格子 == null:
			continue
		# 原版每页签格子数不同（15/18/12/13/8）。格子数**由元件决定**，不由技能数决定：
		# `SkillPane.setData` 是 `cells[i].setCellValue(param1[i])`，列表短时多出来的格子照样画，
		# 只是空的（「特别技能」页 8 格、只有 5 个技能，另 3 格是空框）。
		var 可见 := 序号 < 格位置.size()
		格子.visible = 可见
		if not 可见:
			continue
		# ⚠️ 位置必须在"空格子"分支**之前**设。以前写在分支后面，空格子一 `continue`
		# 就全停在容器原点，几个空框叠在一起——「特别技能」页左上角那一坨就是它。
		格子.position = Vector2(float(格位置[序号].get("x", 0)), float(格位置[序号].get("y", 0)))
		var 有技能 := 序号 < 可见忍术.size()
		(格子.get_node("等级") as CanvasItem).visible = 有技能
		if not 有技能:
			(格子.get_node("图标") as TextureRect).texture = null
			(格子.get_node("选中环") as CanvasItem).visible = false
			(格子.get_node("底") as CanvasItem).modulate = Color.WHITE
			格子.tooltip_text = ""
			continue

		var 忍术: Dictionary = 可见忍术[序号]
		# 未学过的技能也占着自己的格子（原版如此）：图标是**灰度版**、等级显示 0。
		var 学过 := bool(忍术.get("learned", true)) and int(忍术.get("level", 0)) > 0
		var 选中: bool = String(忍术.get("id", "")) == String(窗口._selected_skill_id)
		(格子.get_node("选中环") as CanvasItem).visible = 选中
		(格子.get_node("底") as CanvasItem).modulate = Color.WHITE
		var 图标路径 := String(忍术.get("icon", ""))
		var 图标节点 := 格子.get_node("图标") as TextureRect
		if ResourceLoader.exists(图标路径):
			图标节点.texture = load(图标路径) as Texture2D if 学过 else _灰化图标(图标路径)
		else:
			图标节点.texture = null
		格子.tooltip_text = ("%s  Lv.%d" % [忍术.get("name", "忍术"), int(忍术.get("level", 0))]) if 学过 \
			else ("%s  未学习" % 忍术.get("name", "忍术"))
		格子.pressed.connect(窗口._select_skill.bind(String(忍术.get("id", ""))))
		# 学过的技能**可以拖到下方快捷键栏**。原版起拖端 `SkillCell.as:58`（`SkillPane1..5.as` 同款），
		# 落点端 `ShortcutColumnPane` 只认 `dragSource == SKILL_WINDOW`；未学的是灰图标、原版那格
		# 也没有拖拽监听，所以 `可拖` 跟着 `学过` 走。
		# 页面每次渲染都是新实例化的，格子必然是新的 —— 直接挂，不用先查有没有挂过。
		格子.set_script(忍术格拖拽脚本)
		格子.set("技能id", String(忍术.get("id", "")))
		格子.set("可拖", 学过)
		(格子.get_node("可升级") as CanvasItem).visible = _可升级(窗口, 忍术)
		var 等级标签 := 格子.get_node("等级") as Label
		等级标签.text = 层数文字(忍术)
		# 层数文字：#126 原版是 12px（元件里 `<font size="12">`），白字 + 黑辉光。
		# 2026-11-01 用户点名「忍术等级字体偏小、不够清晰」⇒ 放大到 14（宋体 12..17 都走
		# 内嵌点阵，14 仍锐利；灰度阈值是 18）。格子 40x40、Label 框 50x16，「MAX」21px 仍装得下。
		窗口._configure_label(等级标签, 忍术等级字号, Color.WHITE)


static func _渲染详情(窗口, 页面: Control) -> void:
	# 详情区的底**由场景里的 `详情底板` 节点画**（符号 888 `SkillDetail_background`，210x390，
	# 与面板同尺寸、完全盖住）。**不要在这里 add_theme_stylebox_override**——
	# 自造的 StyleBox 会压过全局主题，`UI资源回归测试` 会报错；而且主题那块比原版暗一截，
	# 叠上去整个详情区（连带学习方法的框）都发黑。
	var 详情 := 页面.get_node("忍术详情") as Panel
	var 页签名: String = String(窗口.忍术页签名[窗口._skill_tab])
	var 可见忍术: Array[Dictionary] = 窗口._skills_for_tab(窗口._skill_tab)
	var 空提示 := 详情.get_node("空提示") as Label
	空提示.visible = 可见忍术.is_empty()
	窗口._configure_label(空提示, 12, Color("#a9957f"))
	if 可见忍术.is_empty():
		_隐藏详情(详情)
		return

	# 详情取当前页签列表里的那一条——未学过的技能也在列表里，也能被选中查看。
	var 选中: Dictionary = {}
	for 条目 in 可见忍术:
		if String(条目.get("id", "")) == 窗口._selected_skill_id:
			选中 = 条目
			break
	if 选中.is_empty():
		选中 = 可见忍术[0]
		窗口._selected_skill_id = String(选中.get("id", ""))

	var 技能id := String(选中.get("id", ""))
	var 文案: Dictionary = GAME_DATA.skill_text(技能id)
	var 等级 := int(选中.get("level", 0))
	var 学过 := bool(选中.get("learned", true)) and 等级 > 0

	# ── 上半块（SkillDetailPane.as:159-167）──────────────────────────
	_显示(详情, ["图标", "名称", "层数标题", "层数", "忍术类型标题", "忍术类型",
		"攻击目标标题", "攻击目标", "攻击范围标题", "攻击范围", "效果说明标题", "描述"], true)
	var 图标 := 详情.get_node("图标") as TextureRect
	var 图标路径 := String(选中.get("icon", ""))
	图标.texture = load(图标路径) as Texture2D if ResourceLoader.exists(图标路径) else null

	_设标签(窗口, 详情, "名称", String(文案.get("name", 选中.get("name", "忍术"))), 12, 色_名称)
	# 层数在原版是**两个** MLabel：标题 "层数：" 在 x=74、值在 x=110（都是 0xFF9100）。
	# 2026-11-01 按用户口径两枚都放大到 14：标题 42px 宽、右缘到 116，值框因此从 x=110
	# 挪到 x=118（右缘仍 210 = 详情区宽），数字本身只有 7px 宽，视觉上不会跳。
	_设标签(窗口, 详情, "层数标题", "层数：", 忍术等级字号, 色_标签)
	_设标签(窗口, 详情, "层数", str(等级), 忍术等级字号, 色_标签)
	_设标签(窗口, 详情, "忍术类型", String(文案.get("skillTypeText", "")), 12, 色_值)
	_设标签(窗口, 详情, "攻击目标", _攻击目标文字(技能id, 文案), 12, 色_值)
	_设标签(窗口, 详情, "攻击范围", String(文案.get("rangeText", "")), 12, 色_值)
	# 「效果说明」那一段是**多行**的：原版的 effectInstructionText 从框顶往下排，
	# 而客户端 Label 默认被主题设成垂直居中，整段会被推到框中间（差三十来像素）。
	# 另外它的折行宽度是**文本框自己的 182**（符号 924 里 #914 的 bounds 到 x=180），
	# 不是 AS3 那个 196 宽的 Box —— 照 196 摆会少折一行。
	# `effectInstructionBox` 是 196x120 的框（`SkillDetailPane` 构造函数 setSize(196,120)），
	# 文案长了就**在框底截断**——原版真机上「特别技能」那页的说明就是被截掉的。
	# 客户端的 Label 默认不截，会长到下面的「学习方法」框上，所以开 clip_text（高度就是那 120）。
	_设标签(窗口, 详情, "描述", String(文案.get("desc", "")), 12, 色_描述)
	(详情.get_node("描述") as Label).vertical_alignment = VERTICAL_ALIGNMENT_TOP

	# 「修炼进度」只在**已学**时出现，且把下面四块整体下移 18px
	# （`SkillDetailPane.setPractiseBarVisible`：moveY = 攻击目标.y − 修炼进度.y = 18）。
	_显示(详情, ["修炼进度标题", "修炼进度"], 学过)
	var 下移 := 18 if 学过 else 0
	for 名 in ["攻击目标标题", "攻击目标", "攻击范围标题", "攻击范围", "效果说明标题", "描述"]:
		var 节点 := 详情.get_node(名) as Control
		节点.position.y = _基础纵坐标(详情, 名) + 下移
	if 学过:
		var 进度 := 详情.get_node("修炼进度") as ProgressBar
		var 已修 := int(选中.get("master_level", 0))
		var 总需 := maxi(1, int(GAME_DATA.skill_upgrade_req(等级 + 1, int(技能id))[2])
			if GAME_DATA.skill_upgrade_req(等级 + 1, int(技能id)).size() > 2 else 1)
		进度条补间.补间(进度, "value", clampf(100.0 * 已修 / 总需, 0.0, 100.0), [已修, 总需])

	# ── 下半块三选一（SkillDetailPane.as:176-187）───────────────────
	#   id 在 3200..3299（八门奥义那批）或 4009：按是否已学切"升级条件 / 学习方法"，
	#   其余：已学且可升级 → 升级条件；未学 → 学习方法；页签禁用（原版 tabBtn3）→ 未开放。
	var 恒切分块 := int(技能id) / 100 == 32 or int(技能id) == 4009
	var 显示升级: bool
	var 显示学习: bool
	if 恒切分块:
		显示升级 = 学过
		显示学习 = not 学过
	else:
		显示升级 = 学过 and not _不可升级(int(技能id))
		显示学习 = not 学过
	# 两个子面板在 AS3 里是**两个独立的 Sprite**（各有一套"需要等级"标签和自己的拖动提示），
	# 客户端也是两个容器、各管各的，不再共用节点。
	_渲染学习方法(窗口, 详情, 选中, 文案, 显示学习)
	_渲染升级条件(窗口, 详情, 选中, 文案, 显示升级)


## 「不可升级」那件（原版 `DataCenter.as:550-561` 里给技能详情对象打的 `notUpgradable`）：
##   · **羁绊技** `3301..3306`（`Job0.couple1..couple6`）—— 顺带 `isCanUpgrade = false`、`autoMaster = true`；
##   · **轮回眼技** `2020..2024`（`Job0.LunHuiYan1..LunHuiYan5`）。
## 这是**客户端自己按 id 算的**，服务端不下发。⚠️ 2026-10-13 修：原来读的是
## `选中.not_upgradable`（全工程没人写）⇒ 恒 false ⇒ 这两族已学会的技能照样摆出「升级条件」面板。
static func _不可升级(技能id: int) -> bool:
	return (技能id >= 3301 and 技能id <= 3306) or (技能id >= 2020 and 技能id <= 2024)


## 「学习方法」子面板（符号 905 `SkillStudyConditionPaneF`，运行时摆在详情区 (2,246)）。
## 坐标全部照 `SkillStudyConditionPane.as` 的 createLabel 参数 + 符号里那些**没被隐藏**的文本框：
## 容器原点 = 905 的符号原点，所以节点坐标就是 AS3/符号局部坐标，不用再换算。
static func _渲染学习方法(窗口, 详情: Control, 选中: Dictionary, 文案: Dictionary, 可见: bool) -> void:
	var 区 := 详情.get_node("学习方法区") as Control
	区.visible = 可见
	if not 可见:
		return
	var 玩家等级 := int(窗口._session.player_stats.get("level", 0))
	var 需要等级 := int(文案.get("reqLevel", -1))
	var 书id := String(文案.get("reqBook", ""))
	var 书名 := String(文案.get("reqBookName", ""))
	var 有书 := _背包里有(窗口, 书id)
	# 学习条件的**第三行**（`SkillStudyConditionPane.setData:157-188`）：
	#   族贡 > 0 → 「需要族贡：N」；否则八门 > 0 → 「需要八门：贯通N门」；否则写轮眼 > 0 →
	#   「需要写轮眼：<阶名>」。达成转绿、未达转红。原版在**家族已加入**时还会把「来源」整句
	#   换成「已加入家族，达到 N 级并满足家族贡献条件后可学习。」。
	#   三列都来自 `info.open`（已由 `开发工具/导出技能文案.py` 导进 reqBangGong/reqMai/reqXielunyan）。
	var 需族贡 := int(文案.get("reqBangGong", 0))
	var 需经脉 := int(文案.get("reqMai", 0))
	var 需轮眼 := int(文案.get("reqXielunyan", 0))
	var 家族贡献 := _家族贡献(窗口)
	var 经脉贯通 := _经脉贯通数(窗口)
	var 轮眼阶 := _写轮眼阶(窗口)
	var 三行 := 需族贡 > 0 or 需经脉 > 0 or 需轮眼 > 0
	# `isCanStudy`（`DataCenter.canStudySkill:341-370`）只卡等级/书/八门/写轮眼 —— **不含族贡**，
	# 族贡那条在原版只显示成红字，点下去由服务端回「需要家族贡献 N。」。这里照做。
	var 可学 := 玩家等级 >= 需要等级 and 有书
	if 需经脉 > 0 and 经脉贯通 < 需经脉:
		可学 = false
	if 需轮眼 > 0 and 轮眼阶 < 需轮眼:
		可学 = false

	var 等级值 := 区.get_node("需要等级") as Label
	等级值.text = str(需要等级)
	var 色_等级 := 色_达标 if 玩家等级 >= 需要等级 else 色_未达
	窗口._configure_label(等级值, 12, 色_等级)
	_加辉光(等级值, 色_等级)

	# `SkillStudyConditionPane.setData`：有书才显示《书名》，没有就显示"-"
	var 秘笈值 := 区.get_node("需要秘笈") as Label
	秘笈值.text = "《%s》" % 书名 if not 书名.is_empty() else "-"
	var 色_书 := 色_达标 if 有书 or 书id.is_empty() else 色_未达
	窗口._configure_label(秘笈值, 12, 色_书)
	_加辉光(秘笈值, 色_书)

	# 第三行：族贡 / 八门 / 写轮眼（`SkillStudyConditionPane.setData:157-188`）。三选一，展示优先级
	# 与 AS3 的 if/else if 一致；值为空字符串的那条在 AS3 里本来就隐藏。
	var 贡献标题 := 区.get_node("贡献标题") as Label
	var 贡献值 := 区.get_node("贡献值") as Label
	贡献标题.visible = 三行
	贡献值.visible = 三行
	if 三行:
		var 达成 := true
		if 需族贡 > 0:
			贡献标题.text = "需要族贡："
			贡献值.text = str(需族贡)
			达成 = 家族贡献 >= 需族贡
		elif 需经脉 > 0:
			贡献标题.text = "需要八门："
			# AS3：`reqMai > 8 ? "里·" + (reqMai - 8) : reqMai`（`SKILLSTUDYCONDITION_PANE_LI` 带间隔点），
			# 塞进「贯通%1门」。
			贡献值.text = "贯通%s门" % ("里·%d" % (需经脉 - 8) if 需经脉 > 8 else str(需经脉))
			达成 = 经脉贯通 >= 需经脉
		else:
			贡献标题.text = "需要写轮眼："
			贡献值.text = String(写轮眼阶名[clampi(需轮眼, 1, 写轮眼阶名.size() - 1)])
			达成 = 轮眼阶 >= 需轮眼
		var 色_第三 := 色_达标 if 达成 else 色_未达
		窗口._configure_label(贡献标题, 12, 色_标签)
		_加辉光(贡献标题, 色_标签)
		窗口._configure_label(贡献值, 12, 色_第三)
		_加辉光(贡献值, 色_第三)

	# 「来源」= 原版的 reqInstructionText（`#902`，**没被隐藏**、AS3 直接改文本）。
	# 它是个会换行的多行框（符号 bounds 到 y=32 = 两行高），所以开着 autowrap。
	# 有第三行时 AS3 把这块整体下移到 y=82（`reqInstructionText_y`），否则留在 y=(第三行.y)=60。
	# 已加入家族且带族贡要求时，整句换成「已加入家族，达到 N 级并满足家族贡献条件后可学习。」。
	var 来源文本 := String(文案.get("gain", ""))
	if 需族贡 > 0 and bool(窗口._session.guild.get("joined", false)):
		来源文本 = "已加入家族，达到 %d 级并满足家族贡献条件后可学习。" % 需要等级
	_设标签(窗口, 区, "来源", 来源文本, 12, 色_描述)
	var 来源 := 区.get_node("来源") as Label
	来源.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	来源.position.y = 82.0 if 三行 else 60.0

	# 技能书图标：**不在背包时按原版加 disableFilter 转灰**（不是调暗）——
	# `SkillStudyConditionPane.setData` 是 `_icon.filters = isBagExistItem(id)==0 ? getDisableFilter() : null`。
	# 图标框是符号里的 `#125`（40x40 @ (150,29)），图标本体按 `_icon.x = _icon.y = 3` 落在 (153,32)。
	var 秘笈图标 := 区.get_node("秘笈图标") as TextureRect
	var 书图路径 := GAME_DATA.item_icon_path(书id) if not 书id.is_empty() else ""
	if 书图路径.is_empty() or not ResourceLoader.exists(书图路径):
		秘笈图标.texture = null
	else:
		秘笈图标.texture = (load(书图路径) as Texture2D) if 有书 else _灰化图标(书图路径)
	秘笈图标.modulate = Color.WHITE
	# 秘籍图案上挂**物品提示**：原版 `SkillStudyConditionPane.setData` 里是
	#   `_loc4_ = ItemFactory.createSingleItem(studyReqSkillId); MToolTipItem.createToolTip(stage, _icon, _loc4_)`，
	# 悬停能看这本书的名字/类型/说明。客户端沿用背包那套纯文本 tooltip 的格式。
	if 书id.is_empty():
		秘笈图标.tooltip_text = ""
	else:
		var 书: Dictionary = GAME_DATA.item(书id)
		var 提示 := "%s
%s
%s" % [
			String(书.get("name", 书名)),
			String(书.get("category", "")),
			String(书.get("description", "")),
		]
		秘笈图标.tooltip_text = 提示.strip_edges()

	# 按钮的美术是**四张原版皮肤**（`素材/界面/原版窗口/忍术/学习按钮_{常态,悬停,按下,禁用}.png`，
	# 由 `开发工具/生成忍术详情底板.py` 从符号 `#452 SkillWindowMButton_up` 导出、按 AS3 的
	# ColorMatrixFilter 分态上色），贴在 tscn 的 `theme_override_styles/*` 上；
	# 作者期烘在符号 905 上的那颗（橙底 + 英文 "Button"）在同一支脚本里擦掉了。
	# 字面仍走 Godot Label —— 与「提升层数」同一条路：4 态文字色（#FCF49C/#FFFFC3/#ACADB2/#939393）
	# 来自主题里 Button 的那几个值（出处 `MButton3._textColors`）。
	#
	# ⚠️ 2026-09-26 去掉了这里原有的**描边色覆盖**：原按 `MButton3` 的辉光换色，
	#    启用态 `getGlowFilter(6824704)` = #682300、禁用态 `getGlowFilter(2039582)` = #1F1F1E。
	#    用户同日定下硬规则「游戏内所有文字描边一律 #000000」，与辉光换色冲突 ——
	#    由规则胜出：不覆盖，直接吃主题的黑色描边（`原版皮肤表.gd` 的 文字规则_描边色）。
	#    要回退就把这两行加回来（原值见 `原版皮肤表.gd` 的 按钮描边色_原版 与本注释）。
	var 学习 := 区.get_node("学习") as Button
	窗口._configure_standard_button(学习)
	# `isCanStudy` 的四条全在这里（等级 / 书 / 八门 / 写轮眼）；**族贡不在其中**，只影响红字显示。
	学习.disabled = not 可学
	学习.pressed.connect(窗口._learn_skill.bind(String(选中.get("id", ""))))


## 「升级条件」子面板（符号 900 `SkillUpgradeConditionPaneF`，运行时摆在详情区 (4,246)）。
## 三个数值是符号里**没被隐藏**的文本框（reqLevelText/reqCoinText/reqBreathText @ x=70，
## 运行时只改文本、不挪位），三个标签才是 AS3 新建的 MLabel @ x=9。
static func _渲染升级条件(窗口, 详情: Control, 选中: Dictionary, 文案: Dictionary, 可见: bool) -> void:
	var 区 := 详情.get_node("升级条件区") as Control
	区.visible = 可见
	if not 可见:
		return
	# 三个数全是**客户端静态表**算出来的（`SkillReqTable`，见 开发工具/导出升级需求表.py）：
	#   `DataCenter.as:548-551`  upgradeReqLevel/Coin = getSkillReq*(技能等级 + 1, 技能id)
	#                            upgradeReqTotalBreath = table[等级+1][2]
	#   `SkillUpgradeConditionPane.as:93` 界面上显示的精华 = 总量 − 当前熟练度（masterLevel）
	#   所以"升 N 级要人物 N 级"——技能等级不会超过人物等级。
	var 技能id := int(String(选中.get("id", "")))
	var 当前层 := int(选中.get("level", 0))
	var 需求 := GAME_DATA.skill_upgrade_req(当前层 + 1, 技能id)
	var 需人物等级 := int(需求[0]) if 需求.size() > 0 else 0
	var 需金币 := int(需求[1]) if 需求.size() > 1 else 0
	var 熟练 := int(选中.get("master_level", 0))
	var 需精华 := maxi(0, (int(需求[2]) if 需求.size() > 2 else 0) - 熟练)

	var 属性: Dictionary = 窗口._session.player_stats
	var 玩家等级 := int(属性.get("level", 0))
	var 金币 := int(属性.get("gold", 0))
	var 精华存量 := int(属性.get("zq", 0))

	var 色_等级 := 色_达标 if 玩家等级 >= 需人物等级 else 色_未达
	var 色_金币 := 色_达标 if 金币 >= 需金币 else 色_未达
	var 色_精华 := 色_达标 if 精华存量 >= 需精华 else 色_未达
	var 等级值 := 区.get_node("需要等级") as Label
	等级值.text = str(需人物等级)
	窗口._configure_label(等级值, 升级条件数值字号, 色_等级)
	_加辉光(等级值, 色_等级)
	var 金币值 := 区.get_node("金币消耗") as Label
	金币值.text = str(需金币)
	窗口._configure_label(金币值, 升级条件数值字号, 色_金币)
	_加辉光(金币值, 色_金币)
	var 精华值 := 区.get_node("精华消耗") as Label
	精华值.text = str(需精华)
	窗口._configure_label(精华值, 升级条件数值字号, 色_精华)
	_加辉光(精华值, 色_精华)

	# 按钮的底用原版美术（`#729 SkillWindowUpgradeBtnF`，38x40）自己画：
	# 底板里那颗已经挖掉了（作者期的是 38 宽、字还比药丸中心偏右 3px），
	# 与 AS3 一致地拉到 40 宽（`SkillUpgradeConditionPane` 里 `upgradeBtn.width = 40`），
	# 字交给下面那个居中 Label。
	# 按钮的**美术是烘在底板里的**（符号 900 上就是「提升层数」两行），
	# 所以这里不再套主题按钮，只留一块透明的点击区。
	# ⚠️ 那两行字**在底板里被整体左移了 3px**（作者期它贴在右边框上，见 生成忍术详情底板.py），
	# 不要改成"让客户端用 Godot 字体重画"：Godot 的中文字面比 Flash 大，重画会撑破药丸（试过 12/11 两档）。
	var 提升 := 区.get_node("提升层数") as Button
	# `SkillUpgradeConditionPane.as:102`：四项都满足才可点（人物等级/金币/精华/层数<人物等级）
	提升.disabled = not (玩家等级 >= 需人物等级 and 金币 >= 需金币
		and 精华存量 >= 需精华 and 当前层 < 玩家等级)
	提升.pressed.connect(窗口._upgrade_skill.bind(String(选中.get("id", ""))))


## 攻击目标：语言表 SKILL_ATTACK_RANGES_1..4 = 无/单体/范围/自己（键名叫 RANGES，
## 但 `SkillDetailPane.as:163` 拿它索引的是 attackTarget）。
## 特例：技能 id 4012 原版写死显示"单体/范围"。
## 连接线：按「箭头」表逐条画，指向的那一格学了就保持原色（橙），没学按亮度转灰。
static func _渲染连接线(窗口, 页面: Control, 元件: Dictionary, 可见忍术: Array[Dictionary]) -> void:
	var 容器 := 页面.get_node("忍术树连接线") as Control
	var 条目: Array = []
	for 项 in 元件.get("箭头", []):
		var 素材 := 箭头美术模板 % int(项.get("元件", 732))
		if not ResourceLoader.exists(素材):
			continue
		var 纹理 := load(素材) as Texture2D
		if 纹理 == null:
			continue
		# 指向第「格」号那一格；它学了 → 原色（橙），没学 → 按亮度转灰
		var 序号 := int(项.get("格", -1))
		var 已学 := false
		if 序号 >= 0 and 序号 < 可见忍术.size():
			已学 = bool(可见忍术[序号].get("learned", true)) and int(可见忍术[序号].get("level", 0)) > 0
		条目.append({
			"纹理": 纹理 if 已学 else _灰化图标(素材),
			"位置": Vector2(float(项.get("x", 0)), float(项.get("y", 0))),
			"尺寸": 纹理.get_size() * Vector2(float(项.get("缩放X", 1.0)), float(项.get("缩放Y", 1.0))),
		})
	# ⚠️ 不在运行时 new 控件：项目的页面脚本不许在运行期创建 TextureRect 之类的固定控件
	# （`功能入口回归测试` 会按源码文本查一遍，**注释里出现也算**，所以这里不写那个字符串）。
	# 所以交给这个 Control 自己的 `_draw` 逐条画（脚本挂在场景里的 忍术树连接线 节点上）。
	容器.设置连接线(条目)


## 详情区里会被「修炼进度」推下去的那几块的**原始纵坐标**（未学时的布局）。
## 写死在这里而不是每次读节点，是因为节点已经被上移过、再读就叠加了。
const 基础纵坐标 := {
	"攻击目标标题": 72.0, "攻击目标": 72.0, "攻击范围标题": 90.0,
	"攻击范围": 90.0, "效果说明标题": 108.0, "描述": 128.0,
}


static func _基础纵坐标(_详情: Control, 名: String) -> float:
	return float(基础纵坐标.get(名, 0.0))


static func _攻击目标文字(技能id: String, 文案: Dictionary) -> String:
	if int(技能id) == 4012:
		return "单体/范围"
	return String(文案.get("targetText", ""))


static func _背包里有(窗口, 书id: String) -> bool:
	if 书id.is_empty():
		return true
	# ⚠️ 会话背包的数量键是 **`quantity`**（`游戏会话.inventory` 那一族全用它），
	# 这里原来读 `count` ⇒ 永远拿到 0 ⇒ **背包里真有技能书也照样判"缺书"**，
	# 「学习」钮恒灰（用户 2026-10-20 报修）。`count` 只留在掉落/需求表里。
	for 物品 in 窗口._session.inventory:
		if String(物品.get("id", "")).pad_zeros(8) == 书id.pad_zeros(8):
			return int(物品.get("quantity", 物品.get("count", 0))) > 0
	return false


## 家族贡献（`GuildSource` 的口径）：**没入家族按 0 算**，原版 `setData` 里那一行照样显示红字。
static func _家族贡献(窗口) -> int:
	if not bool(窗口._session.guild.get("joined", false)):
		return 0
	return int(窗口._session.guild.get("contribution", 0))


## `JingMaiSource.getThroughMaiNumber:210-249`：**当前这一脉**里「已开穴位数 == 该门穴位数」
## 的门数 + `listId * MAI_LENGTH(8)`。数据面：`cultivation_states["八门"]` 的
## `list_id` / `exploded`（每门已开数），总穴位数取 `数据/经脉.json` 当前脉的 `mai.<门>.pts` 条数。
static func _经脉贯通数(窗口) -> int:
	var 状态: Dictionary = 窗口._session.cultivation_states.get("八门", {})
	var 脉 := int(状态.get("list_id", 0))
	var 门表: Dictionary = (GAME_DATA.取表("经脉").get(str(脉), {}) as Dictionary).get("mai", {})
	var 已开: Dictionary = 状态.get("exploded", {})
	var 贯通 := 0
	for 门id in 门表:
		var 穴表: Dictionary = (门表[门id] as Dictionary).get("pts", {})
		if 穴表.is_empty():
			continue
		if int(已开.get(int(门id), 0)) == 穴表.size():
			贯通 += 1
	return 贯通 + 脉 * 8


## 写轮眼阶（`TongshuSource._stage`，0 = 未开眼）。
static func _写轮眼阶(窗口) -> int:
	return int((窗口._session.cultivation_states.get("写轮眼", {}) as Dictionary).get("stage", 0))


static func _设标签(窗口, 详情: Control, 名: String, 文本: String, 字号: int, 色: Color) -> void:
	var 标签 := 详情.get_node(名) as Label
	窗口._configure_label(标签, 字号, 色)
	标签.text = 文本
	_加辉光(标签, 色)


## 原版这些字（需要等级/金币/精华/需要秘笈/来源/效果说明）都挂了 `BaseUtil.getGlowFilter()`——
## **默认参 = 黑色、blur 2**（`BaseUtil.as:124-127`：`GlowFilter(0, 1, 2, 2, 10, 1)`），
## 是一圈**黑色**光晕，不是同色光晕。
## ⚠️ 2026-10-20：这里原来用**文字本色 + α0.42 的 3px 外描边**冒充它 —— 12px 宋体上
## 彩色晕把笔画糊成一团，正是用户报的「忍术面板字体有模糊感」。改回黑描边、2px，
## 与全局文字规则（`原版皮肤表.文字规则_描边数值 = 2`）同源。
static func _加辉光(标签: Label, _色: Color) -> void:
	标签.add_theme_constant_override("outline_size", 2)
	标签.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))


static func _显示(详情: Control, 节点名: Array, 可见: bool) -> void:
	for 名 in 节点名:
		var 节点 := 详情.get_node_or_null(名) as CanvasItem
		if 节点 != null:
			节点.visible = 可见


static func _隐藏详情(详情: Control) -> void:
	_显示(详情, ["图标", "名称", "层数标题", "层数", "忍术类型标题", "忍术类型",
		"修炼进度标题", "修炼进度",
		"攻击目标标题", "攻击目标", "攻击范围标题", "攻击范围", "效果说明标题", "描述",
		"学习方法区", "升级条件区"], false)
