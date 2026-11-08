extends SceneTree

## 校验 素材/界面/原版主题.tres 与 脚本/界面/原版皮肤表.gd 一致。
##
## 运行：Godot --headless --path . --script res://测试/界面主题回归测试.gd
##
## 三件事：
##   1. 皮肤表声明的每个类型/项都真的存在于签入的主题里
##   2. 每个九宫格样式的 texture_margin 等于 皮肤表.九宫格 条目
##   3. 在内存里重跑生成器并逐项比对 —— 抓「手改了 .tres、下次生成会丢」

const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 生成器 := preload("res://开发工具/生成界面主题.gd")
const 主题路径 := "res://素材/界面/原版主题.tres"

var _失败 := 0


func _initialize() -> void:
	var 主题: Theme = load(主题路径) as Theme
	if 主题 == null:
		push_error("主题加载失败：%s" % 主题路径)
		quit(1)
		return

	_查字体(主题)
	_查类型(主题)
	_查生成一致(主题)
	_查文字描边规则(主题)
	_查场景文字规则()
	_查代码文字规则()
	_查页签三态(主题)
	_查标准钮四态(主题)
	_查数值输入框字号(主题)
	_查忍术面板主题()
	_查页面字体主题(主题)
	_查扩展页字号()

	if _失败 > 0:
		print("界面主题回归测试失败：%d 项" % _失败)
		quit(1)
		return
	print("界面主题回归测试通过（类型 %d 个）" % 主题.get_type_list().size())
	quit(0)


func _报错(讯息: String) -> void:
	_失败 += 1
	push_error(讯息)
	print("  ✗ ", 讯息)


## ── 用户 2026-09-26 硬规则：**游戏内所有文字** ──────────────────────────
##   Font Outline 开启、颜色 `000000`、描边数值 **3**
##   Font Shadow 开启、颜色 `00000000`（全透明 —— 视觉上就是不投影）
##
## ⚠️ 遍历的是**皮肤表规格**（含变体），不是 `主题.get_type_list()`：
##    变体自己不写 `font_color`（继承基类的），按"主题里有没有 font_color"筛会把
##    `OrigTab`/`OrigListItem`/`OrigOverlayButton` 全漏掉 —— 而它们恰恰是最容易漏的，
##    因为**运行期 `Theme.has_color` 在变体上查不到基类的颜色**（实测，见 §3.37.10）。
##    `生成界面主题.规格带文字()` 是生成器与这里共用的同一份判据。

## 从 .tscn 文本里解析 `Color(r, g, b, a)` / `Color(r,g,b)`。
## ⚠️ 别拿 `str(Color(0,0,0,0))` 去比 —— Godot 的 str 是 `(0.0, 0.0, 0.0, 0.0)`，
##    而 .tscn 里写的是 `Color(0, 0, 0, 0)`，比出来永远不等（本门第一版就栽在这）。
func _解析颜色(文本: String) -> Variant:
	var 值 := 文本.strip_edges()
	if not 值.begins_with("Color(") or not 值.ends_with(")"):
		return null
	var 段 := 值.substr(6, 值.length() - 7).split(",")
	if 段.size() < 3 or 段.size() > 4:
		return null
	var 分量 := [0.0, 0.0, 0.0, 1.0]
	for i in 段.size():
		if not String(段[i]).strip_edges().is_valid_float():
			return null
		分量[i] = String(段[i]).strip_edges().to_float()
	return Color(分量[0], 分量[1], 分量[2], 分量[3])


func _查文字描边规则(主题: Theme) -> void:
	var 违例 := 0
	var 受检 := 0
	for 键: Variant in 皮肤表.类型规格:
		var 类型名 := String(键)
		if not 生成器.规格带文字(皮肤表.类型规格[键]):
			continue
		受检 += 1
		if not 主题.has_constant("outline_size", 类型名):
			_报错("文字规则：%s 没有 outline_size（变体必须自己写一份，不能只靠基类）" % 类型名)
			违例 += 1
		elif 主题.get_constant("outline_size", 类型名) != 皮肤表.文字规则_描边数值:
			_报错("文字规则：%s 的 outline_size 应为 %d，实际 %d"
				% [类型名, 皮肤表.文字规则_描边数值, 主题.get_constant("outline_size", 类型名)])
			违例 += 1
		if not 主题.has_color("font_outline_color", 类型名):
			_报错("文字规则：%s 没有 font_outline_color" % 类型名)
			违例 += 1
		elif 主题.get_color("font_outline_color", 类型名) != 皮肤表.文字规则_描边色:
			_报错("文字规则：%s 的 font_outline_color 应为 000000，实际 %s"
				% [类型名, 主题.get_color("font_outline_color", 类型名)])
			违例 += 1
		if not 主题.has_color("font_shadow_color", 类型名):
			_报错("文字规则：%s 没有 font_shadow_color" % 类型名)
			违例 += 1
		elif 主题.get_color("font_shadow_color", 类型名) != 皮肤表.文字规则_阴影色:
			_报错("文字规则：%s 的 font_shadow_color 应为 00000000，实际 %s"
				% [类型名, 主题.get_color("font_shadow_color", 类型名)])
			违例 += 1
	if 违例 == 0:
		print("  文字规则（主题层）：%d 个带文字的类型全部合规" % 受检)


## 场景里**显式**写的 override 也不能违反同一条规则。
## 没写 override 的节点由主题默认值兜住，不在这里管。
## 跳过 `场景/生成/`（烘焙派生物，源头是 地图场景.tscn，已经在这里被扫到）。
func _查场景文字规则() -> void:
	var 违规文件: Array[String] = []
	var 违规行数 := 0
	for 路径 in _遍历tscn("res://场景"):
		var 文本 := FileAccess.get_file_as_string(路径)
		if 文本.is_empty():
			continue
		var 本文件违规 := 0
		for 行 in 文本.split("\n"):
			var 去空 := 行.strip_edges()
			if 去空.begins_with("theme_override_constants/outline_size"):
				var 允许: Array = [皮肤表.文字规则_描边数值]
				允许.append_array(场景例外描边数值.get(路径, []))
				var 写的 := 去空.get_slice("=", 1).strip_edges()
				if not 写的.is_valid_int() or not 允许.has(int(写的)):
					本文件违规 += 1
			elif 去空.begins_with("theme_override_colors/font_outline_color"):
				var 色: Color = _解析颜色(去空.get_slice("=", 1))
				var 合规 := 色.is_equal_approx(皮肤表.文字规则_描边色)
				for 例外 in 场景例外描边色:
					合规 = 合规 or 色.is_equal_approx(例外)
				for 例外 in 场景例外描边色_按场景.get(路径, []):
					合规 = 合规 or 色.is_equal_approx(例外)
				if not 合规:
					本文件违规 += 1
			elif 去空.begins_with("theme_override_colors/font_shadow_color"):
				if _解析颜色(去空.get_slice("=", 1)) != 皮肤表.文字规则_阴影色:
					本文件违规 += 1
		if 本文件违规 > 0:
			违规文件.append("%s（%d 处）" % [路径, 本文件违规])
			违规行数 += 本文件违规
	if 违规行数 > 0:
		_报错("文字规则：%d 个场景里有 %d 处与规则相反的 override：%s"
			% [违规文件.size(), 违规行数, 违规文件.slice(0, 6)])
	else:
		print("  文字规则（场景层）：显式 override 全部合规")


## 第三层：**代码里**用 `add_theme_*_override` 设的那份（`.tscn` 扫不到）。
## 实战教训：改完 .tscn 那 86 处以为干净了，`忍术窗口.gd` / `地图实体.gd` / `小地图面板.gd`
## 里还有 20 多处是指纹写死的（世界名牌的近黑色、面板标题的实心投影）。
## 跳过 `开发工具/`（字号探针那类工具里描边值本身就是自变量：要量不同描边下的点阵）。
## 场景里允许的**例外描边色**（其余仍照 `文字规则_描边色` 查）。
## 小地图「点击领取」是**黄字 + 深棕描边**（`Color(0.408,0.137,0)`）——
## 与 `代码例外` 里忍术窗口那条同属一类：原版这几行字挂的是**彩色辉光**，
## 我们用"同色半透明外描边"近似，**不是自造**（2026-09-29 合并小地图包时登记）。
## 竞技场窗里 VS/倒计时那 5 行是**金色描边**（`Color(0.686275,0.501961,0.12549)` = #AF8020）——
## 与上一档同源：原版那几行是彩色辉光，不是 UI 的黑色实心描边。
const 场景例外描边色 := [Color(0.408, 0.137, 0, 1), Color(0.686275, 0.501961, 0.12549, 1)]

## 按场景放行的**描边色**：`{场景路径: [允许的颜色]}`。与上面那张全局表分开，
## 因为"全透明描边"等于关掉描边，任何场景都能写会把这层规则废掉。
## 小地图右上角的**任务追踪**（2026-11-02 用户实机报「右上角任务面板内字体模糊，可能
## 需要去掉字体阴影」）：原版那几行挂的是 Flash 的**柔和外发光**（标题 `MGlowLabel`
## blur 3/strength 6，正文 `QuestTrackerItemRenderer.as:168` 的 `getGlowFilter()`
## blur 2/strength 10），而我们 14px 宋体点阵外面套一圈 2px **实心黑**，笔画边缘全黑
## ⇒ 看着就是糊。按用户要求这一族显式压 0 描边 + 透明描边色（有意偏离，§3.361）。
const 场景例外描边色_按场景 := {
	"res://场景/界面/小地图面板.tscn": [Color(0, 0, 0, 0)],
}

## 场景级**描边宽度**的例外表：`{场景路径: [额外允许的值]}` —— 是"在规则值之外再放行这些"，
## 不是"改成只认这些"（一个场景里常常两种都有：技能面板.tscn 就有 11 处 2 和 10 处 3）。
## `res://场景/界面/技能面板.tscn` 那 10 枚 `KeyLabel` 烤的是 `outline_size = 3` ——
## 与上面 `代码例外` 里 `技能面板.gd` 那条同一个根：原版 `KeyboardCell.as:48` 的标号是
## **`MGlowLabel`**，它自己的 `getFilter()`（`MGlowLabel.as:26-35`）= `GlowFilter(黑,1,blur 3,3,str 6)`，
## 比 UI 规则那条 `BaseUtil.getGlowFilter()`（blur 2）重一档 ⇒ 3 才是真值。
## 场景里那 10 处是 `开发工具/烘焙技能栏格子.py` 从 `技能面板.gd const 描边宽` 现读烤进去的，
## 两边同源，改一处两边一起动。
## 竞技场窗那 5 行同一档：原版 VS/倒计时是 3px 辉光（读作外描边 3），不是 UI 的 2px。
const 场景例外描边数值 := {
	"res://场景/界面/技能面板.tscn": [3],
	"res://场景/界面/窗口/竞技场/竞技场窗.tscn": [3],
	# 任务追踪那三枚（两页签 + 「更多可玩内容」）按上面 `场景例外描边色_按场景` 同一条
	# 理由压 0（2026-11-02 用户报字体模糊，§3.361）。
	"res://场景/界面/小地图面板.tscn": [0],
}

const 代码例外 := {
	# 忍术窗口的 `_加辉光()`：AS3 里这几行字挂了 `getGlowFilter()` 的**彩色辉光**
	# （暗绿 0x007E06 等），客户端用"一圈半透明的同色外描边"近似 —— 与"描边一律 #000000"
	# 冲突，**用户 2026-09-26 看了一眼后拍板保留**（它是真值复刻，不是自造）。
	# 例外只认这一个函数，别处照规则查。
	"res://脚本/界面/窗口/忍术窗口.gd": ["_加辉光"],
	# 世界里的名字（角色 / 怪物 / NPC / **掉落物**）走的是原版 `RoleNamePane.getFilter()`
	# （`RoleNamePane.as:191-200`）= `GlowFilter(0,1,3,3,6)` —— **blur 3**；
	# 而 UI 那条规则对应的是另一个滤镜 `BaseUtil.getGlowFilter()`（`BaseUtil.as:124-126`）
	# = `GlowFilter(0,1,2,2,10)` —— blur 2。**两者在原版就是分开的**，所以这里必须是例外。
	# 2026-09-27 用户给并排图报"怪物名称的字体"不对：量下来字号(12)/字体(宋体)/
	# 颜色规则(`Monster.as:1270-1287` 五档)全对，差的只有这层描边（我们 2、原版 3）。
	# 例外只认这两个函数，本文件别处照规则查。
	# `_新建家族牌`（本地玩家头顶那行 `[家族]<族名>`）与 `_create_nameplate` **同源**：
	# 原版 `Character.as:275` 的 `_banghuiPane = new RoleNamePane(4059383)`，
	# 就是世界名牌那一套（宋体 12、`GlowFilter(0,1,3,3,6)` ⇒ 描边 3），
	# 只是颜色固定 `#3DF0F7`（与 `族旗._造名牌` 那两行同色同源）。
	"res://脚本/地图/地图实体.gd": ["_create_nameplate", "_create_drop_node", "_新建家族牌"],
	# 技能栏那枚黄标号 + 层数：`KeyboardCell.as:48` 走的是 `BaseUtil.getLabel("",0xFFFFFF)`，
	# 第 4 参默认 `true` ⇒ 建的是 **`MGlowLabel`**，而它自己的 `getFilter()`
	# （`MGlowLabel.as:26-35`）= `GlowFilter(黑, alpha 1, blurX/Y = 3, strength 6)` ——
	# **blur 3**，与 UI 那条规则对应的 `BaseUtil.getGlowFilter()`（`BaseUtil.as:124-126`，blur 2）
	# 在原版就是两个不同的滤镜 ⇒ 这里必须是例外（和上面世界名字那一条同一个道理）。
	# 10-12 补：技能栏那轮改完没跑这道门，红着就交了，这次全量才抓出来。
	"res://脚本/界面/技能面板.gd": ["_setup_shortcuts"],
	# 地图上的**族旗**那两行名字（`族旗._造名牌`）：与上一行同源 —— 原版 `Flag.as:310-311`
	# 也是 `new RoleNamePane(4059383)`（世界名牌那一套：宋体 12、`GlowFilter(0,1,3,3,6)`
	# ⇒ 描边 3），只是**颜色是固定的 #3DF0F7**（`RoleNamePane` 的构造参数，不是 UI 那套）。
	# 属于"世界里的名字"这一类，随 `地图实体._create_nameplate` 一起例外。
	"res://脚本/角色/族旗.gd": ["_造名牌"],
	# 伤害数字的 `播放()`：原版给这个 TextField 挂的是 `new GlowFilter(0, 0.6)`
	# （`Monster.as:918` / `Character.as:1263`）——**黑色、alpha 0.6 的辉光**，不是实心描边。
	# 客户端用"一圈同为黑色的半透明外描边"近似，所以 alpha 是 0.6 而不是 1。真值复刻，不是自造。
	"res://脚本/角色/伤害数字.gd": ["播放"],
	# 帧率浮层（`脚本/调试/帧率显示.gd`）是**调试小工具**，不属于原版 UI：
	# 用高对比黄字 + 4px 黑描边保证叠在任何地图/HUD 上都能看清。只在
	# 环境变量 NARUTO_FPS=1 或游戏内按 F8 时出现，正常游玩不显示。
	# 例外只认 `_ready`（override 都在那里建）。
	"res://脚本/调试/帧率显示.gd": ["_ready"],
# 镜头节拍记录（`脚本/调试/镜头节拍记录.gd`，2026-10-23 随镜头节拍修复并入）
	# 与上一行同类：**调试小工具**，不是原版 UI。左上角那行状态字用高对比绿字 +
	# 4px 黑描边，保证叠在任何地图/HUD 上都能看清（规则值是 2px，这里故意加粗）。
	# 正常启动只有在"逻辑节拍跟了屏幕"（高刷屏）或开录（F6 / NARUTO_CAMLOG=1）时才显示。
	# 例外只认 `_ready`（override 都在那里建）。
	# 捕捉通灵兽读条（`捉宠流程.gd`）是原版 `GeneralInternalLoading` 的**逐字复刻**：
	# 「正在捕获...」12px、#00ff00、黑色 2px 描边、**无阴影** —— 与页面常规文字规则
	# （描边色/阴影色统一取主题）本来就不同，属真值，不是自造。例外只认 `_ready`。
	"res://脚本/地图/捉宠流程.gd": ["_ready"],
	# 竞技场左上角倒计时（`战场倒计时.gd`）：原版 PvpWindow 那行是 3px 黑描边，
	# 比 UI 规则的 2px 重一档（与上面技能栏 `MGlowLabel` 同一类）。例外只认 `_ready`。
	"res://脚本/界面/组件/战场倒计时.gd": ["_ready"],
	"res://脚本/调试/镜头节拍记录.gd": ["_ready"],
	# 右上角任务追踪的标题/正文（`_create_quest_renderer`）：2026-11-02 用户实机报
	# 「任务面板内字体模糊，可能需要去掉字体阴影」⇒ 这一族显式压 outline_size=0 +
	# 透明描边色（原版是 Flash GlowFilter 柔和外发光，14px 宋体点阵上套 2px 实心黑
	# 只会发糊）。有意偏离，§3.361；判据在 `测试/字体清晰回归测试.gd`。
	"res://脚本/界面/小地图面板.gd": ["_create_quest_renderer"],
	# 活动时间/倒计时那几行（`系统消息._保证行数`）：2026-11-07 用户报「活动显示时间字体
	# 去掉阴影、略微加大」⇒ 运行期建行时显式压 outline_size/shadow 全 0 + 透明阴影色。
	# 原版这几行就是纯色字，没有 UI 常规的 2px 实心描边；有意偏离，§3.373。
	"res://脚本/界面/系统消息.gd": ["_保证行数"],
}


func _查代码文字规则() -> void:
	var 违规: Array[String] = []
	# ⚠️ 必须按**逻辑语句**看，不能只按行：`add_theme_color_override("font_outline_color",`
	#    换行再写值是很常见的写法（本仓就有两处），逐行扫会整个漏掉。
	for 路径 in _遍历gd("res://脚本"):
		var 文本 := FileAccess.get_file_as_string(路径)
		if 文本.is_empty():
			continue
		var 例外函数: Array = 代码例外.get(路径, [])
		var 当前函数 := ""
		var n := 0
		var 行号 := 0
		var 待收 := ""
		var 待收起行 := 0
		for 行 in 文本.split("\n"):
			行号 += 1
			var 去空 := 行.strip_edges()
			if 去空.begins_with("static func "):
				当前函数 = 去空.get_slice(" ", 2).get_slice("(", 0)
			elif 去空.begins_with("func "):
				当前函数 = 去空.get_slice(" ", 1).get_slice("(", 0)
			if 待收 != "":
				待收 += " " + 去空
				if 去空.contains(")"):
					if _违规则(待收) and not 例外函数.has(当前函数):
						_报错("文字规则：%s:%d 的 override 违反规则（函数 %s）"
							% [路径, 待收起行, 当前函数])
						n += 1
					待收 = ""
				continue
			if not 去空.contains("add_theme_"):
				continue
			if 去空.contains(")"):
				if _违规则(去空) and not 例外函数.has(当前函数):
					_报错("文字规则：%s:%d 的 override 违反规则（函数 %s）—— 若是真值复刻，"
						% [路径, 行号, 当前函数] + "请加进 代码例外 并写明理由")
					n += 1
			else:
				待收 = 去空
				待收起行 = 行号
		if n > 0:
			违规.append("%s（%d 处）" % [路径, n])
	if 违规.is_empty():
		print("  文字规则（代码层）：add_theme_*_override 全部合规（含跨行写法）")


func _违规则(语句: String) -> bool:
	if 语句.contains('"font_outline_color"'):
		# 与下面 outline_size 同口径：**两种写法都认** —— 直接写黑色，或引用规则常量
		# `皮肤表.文字规则_描边色`。原来只认字面量，等于把"会随规则漂的值"钉成字面量
		# （正是下面那条注释记过的病），于是运行期建控件的代码只能抄死值或进例外表。
		var 色值 := 语句.get_slice('"font_outline_color",', 1).strip_edges().trim_suffix(")")
		return 色值 != "Color(0, 0, 0, 1)" and not 色值.ends_with("文字规则_描边色")
	if 语句.contains('"font_shadow_color"'):
		return not 语句.contains("Color(0, 0, 0, 0)")
	if 语句.contains('"outline_size"'):
		# ⚠️ 这里原来是 `not 语句.contains(", 3)")` —— 把**会漂的规则值钉成了字面量**，
		#    09-27 规则从 3 改成 2 之后它就反了：写 3 的算合规、读规则常量的倒算违规。
		#    现在两种写法都认：直接写规则值，或写 `皮肤表.文字规则_描边数值`。
		var 值 := 语句.get_slice('"outline_size",', 1).strip_edges().trim_suffix(")")
		return 值 != str(皮肤表.文字规则_描边数值) and not 值.ends_with("文字规则_描边数值")
	if 语句.contains('"shadow_offset_'):
		return not 语句.contains(", 0)")
	return false


## 项目主题与稀疏页面主题的 `default_font` 都不该包**全局**合成加粗壳。
## §3.275 的全局 embolden 已于 2026-10-25 晚回滚：它把 12px 数字/字母的边缘抹成灰，
## 用户实机报「数值方面，数字、字母之类的都模糊了」；原版只有窗口标题 `MWindow` 是 bold，
## 那层烘在项目主题的 `OrigWindowTitle` 变体里，不在 `default_font` 上。
func _无全局加粗(字: Font) -> bool:
	return not (字 is FontVariation)


## 忍术面板单独挂了一份主题（`素材/界面/忍术面板主题.tres`）。这份主题必须是**稀疏**的：
## 一旦往里面写颜色/描边/样式，就会遮住上面那三层文字规则在这个面板里的效果。
## 允许的只有 `default_font` / `default_font_size`。
##
## ⚠️ 2026-09-27 **字体口径改了**：原来断言"必须是微软雅黑"（§3.39，用户 09-26 选的），
## 现在改回**宋体**（= 项目主题那份 `原版字体.tres`）。
## 依据是用户的并排对比图 `忍术界面对比.png`（4 倍放大）：
##   原版的字**实心白、笔画粗实**；我们的雅黑**发灰发透、笔画被 2px 描边吃掉了芯**。
##   宋体 12px 有内嵌点阵（笔画是实心块，描边吃不掉），雅黑是纯轮廓（~1px，一压就没了）；
##   而且**原版 `Config.COMMON_FONT` 就是宋体**。
## 所以这里不再钉具体字体族，只钉"面板字体 == 项目主题字体"（口径一致）。
func _查忍术面板主题() -> void:
	const 路径 := "res://素材/界面/忍术面板主题.tres"
	var 面板主题 := load(路径) as Theme
	if 面板主题 == null:
		_报错("忍术面板主题加载失败：%s" % 路径)
		return
	if 面板主题.default_font == null:
		_报错("忍术面板主题没有 default_font —— 面板会掉回项目主题的宋体")
	else:
		# 钉"与项目主题同源"，不钉具体族名 —— 族名会随上面的口径改，写死就会像今天这样假红。
		# 2026-10-25 晚：项目主题的 default_font 回到裸 FontFile（全局合成加粗已回滚），
		# 但仍然钉"解到底的同一份文件"，防系统 simsun.ttc 替身（§3.84.6）。
		var 项目主题 := load("res://素材/界面/原版主题.tres") as Theme
		if 项目主题 != null and 皮肤表.字体落点(面板主题.default_font) != 皮肤表.字体落点(项目主题.default_font):
			_报错("忍术面板字体应与项目主题同源（原版字体.tres），实际 %s"
				% 面板主题.default_font.get_font_name())
		elif 项目主题 != null and not _无全局加粗(面板主题.default_font):
			_报错("忍术面板的 default_font 包了合成加粗壳（%s）—— 全局加粗已回滚（数字/字母会糊），见 原版皮肤表.标题加粗量"
				% str(面板主题.default_font))
	var 类型 := 面板主题.get_type_list()
	if not 类型.is_empty():
		_报错("忍术面板主题应当是稀疏的（只设字体），却写了 %d 个类型：%s —— "
			% [类型.size(), 类型] + "这些项会遮住该项目主题里的文字规则")
	else:
		print("  忍术面板主题：稀疏（只设字体 %s）" % 面板主题.default_font.get_font_name())


## 合并带进来的四个「提升XX阶数弹窗」各挂了一份**只设字体的 Theme**：
## `柔拳字体.tres`（柔拳/写轮眼/轮回六道 三页共用）与 `结印字体.tres`。
## 它们原来把**系统 simsun.ttc 拷进工程**当宋体用（实测 md5 与
## `C:/Windows/Fonts/simsun.ttc` 逐字节相同）——与 §3.84.6 的定案冲突：
## 原版内嵌的是 `www/fonts/simsun.ttf` = 我们的 `素材/界面/simsun_原版.ttf`
## （汉字相近、**数字差得最扎眼**；系统那份还没有内嵌点阵那套光栅参数）。
## 2026-10-17 借「八门那些门的字体偏暗」那轮一并改指原版 ttf；这里钉**同源**，
## 防将来又被换回替身（口径同 `_查忍术面板主题`：不钉族名、钉同一份资源）。
func _查页面字体主题(项目主题: Theme) -> void:
	for 路径 in [
		"res://素材/界面/原版窗口/人物/柔拳/宋体文字/柔拳字体.tres",
		"res://素材/界面/原版窗口/人物/结印/宋体文字/结印字体.tres",
	]:
		var 页主题 := load(路径) as Theme
		if 页主题 == null:
			_报错("页面字体主题加载失败：%s" % 路径)
			continue
		# 原来钉的是**对象身份**（`页主题.default_font != 项目主题.default_font`）——
		# 本意是"别拿系统 simsun.ttc 当替身"（§3.84.6）。项目主题期间短暂包过 FontVariation
		# （§3.275 全局加粗，2026-10-25 晚已回滚），对象身份会随壳变 ⇒ 统一改钉
		# **解到底的同一份文件**，判据本意不变。
		var 页落点 := 皮肤表.字体落点(页主题.default_font)
		var 项落点 := 皮肤表.字体落点(项目主题.default_font)
		if 页落点 != 项落点 or not 页落点.contains("simsun_原版"):
			_报错("%s 的 default_font 不是原版内嵌宋体（实际 %s，项目主题 %s）—— 系统 simsun.ttc 是替身，见 §3.84.6"
				% [路径, 页落点, 项落点])
		elif not _无全局加粗(页主题.default_font):
			_报错("%s 的 default_font 包了合成加粗壳 —— 全局加粗已回滚（数字/字母会糊），见 原版皮肤表.标题加粗量" % 路径)
		elif 页主题.default_font_size != 12:
			_报错("%s 的 default_font_size=%d，应为 12（MButton/MLabel 口径）" % [路径, 页主题.default_font_size])
		elif not 页主题.get_type_list().is_empty():
			_报错("%s 应当是稀疏的（只设字体），却写了 %d 个类型 —— 会遮住项目主题里的文字规则"
				% [路径, 页主题.get_type_list().size()])
		else:
			print("  页面字体主题：", 路径, " 与项目主题同源")


## 人物面板那 7 个扩展页（八门 / 手里剑 / 写轮眼 / 结印 / 柔拳 / 寄坏之术 / 轮回六道）
## 和同目录那几个弹窗：**任何一处字号都不许小于皮肤表的 `默认字号`**。
## 2026-10-17 用户报「秘术、血继界限有些字体不太对，小或者比较暗，而且不清晰」。
## 真值：这几页原版**没有一处小于 12** —— `MLabel.initUI:218-223`、`TextArea2.createTf:77-82`、
## `MButton.init:148-155`、`MButton3:123-131` 全是 `size=12 + font=COMMON_FONT(宋体)`，
## `MBar.labelFormat`（`RouQuanPanel.as:455-459`、`JieYinPanel.as:502-513`）**根本不设 size**
## ⇒ 吃 Flash 默认 12。而宋体的内嵌点阵只在 12px 命中，8/9/10/11 会退回轮廓 + 灰度抗锯齿
## ⇒ 看着就是"又小又虚又暗"（§3.55.3 是同一件事的 UI 侧，§3.184 只治了八门那一角）。
##
## 钉**两层**：① 场景里烘的 `theme_override_font_sizes/*`；② 宿主 `统一页面字号` 补的那份 ——
## 它只补"场景没写过"的节点，补成 11 一样糊，两层都得看。
const 扩展页目录 := "res://场景/界面/窗口/人物/页面"
const 扩展页宿主 := "res://脚本/界面/窗口/人物窗口.gd"


func _查扩展页字号() -> void:
	var 门 := int(皮肤表.默认字号)
	var 违规: Array[String] = []
	for 路径 in _遍历tscn(扩展页目录):
		var 文本 := String(FileAccess.get_file_as_string(路径))
		var 节点名 := "?"
		var 行号 := 0
		for 行 in 文本.split("\n"):
			行号 += 1
			var 去空 := 行.strip_edges()
			if 去空.begins_with("[node name="):
				var 起 := 去空.find("\"")
				节点名 = 去空.substr(起 + 1, 去空.find("\"", 起 + 1) - 起 - 1)
				continue
			if not 去空.begins_with("theme_override_font_sizes/"):
				continue
			var 数 := _首个整数(去空.substr(去空.find("=") + 1))
			if 数 >= 0 and 数 < 门:
				违规.append("%s:%d 「%s」%s=%d" % [路径.get_file(), 行号, 节点名,
					去空.get_slice("/", 1).get_slice("=", 0), 数])
	var 宿主文本 := String(FileAccess.get_file_as_string(扩展页宿主))
	# 2026-10-25：`_configure_label` 的第 2 参不再全是字面量（人物页数值用 `数值字号` 常量，
	# 有意 14；§3.284）。旧解析会跳过符号去抓后面的 `Color("#00ff00")`，把 00 读成 0 假红。
	# ⇒ 只取第 2 个实参；字面量直接转 int，符号查本文件的 `const X := N` 表。
	var 常量表 := {}
	var 常量正则 := RegEx.create_from_string("^\\s*const\\s+(\\S+)\\s*:=\\s*(\\d+)\\s*$")
	for 常量行 in 宿主文本.split("\n"):
		var 常量匹配 := 常量正则.search(常量行)
		if 常量匹配 != null:
			常量表[常量匹配.get_string(1)] = int(常量匹配.get_string(2))
	var 行号2 := 0
	for 行 in 宿主文本.split("\n"):
		行号2 += 1
		var 数2 := -1
		if 行.contains("font_size\", "):
			数2 = _首个整数(行.substr(行.find("font_size\", ") + 12))
		elif 行.contains("_configure_label("):
			var 段 := 行.substr(行.find("_configure_label(") + 17)
			var 部 := 段.split(",", false, 2)
			var 参 := 部[1].strip_edges() if 部.size() >= 2 else ""
			if 参.is_valid_int():
				数2 = int(参)
			elif 常量表.has(参):
				数2 = int(常量表[参])
		if 数2 >= 0 and 数2 < 门:
			违规.append("人物窗口.gd:%d 统一页面字号补成 %d" % [行号2, 数2])
	if 违规.size() > 0:
		_报错("扩展页字号：%d 处小于 %d（宋体点阵只在 %d 命中，小了必糊）：%s"
			% [违规.size(), 门, 门, 违规.slice(0, 8)])
	else:
		print("  扩展页字号：场景与宿主两层全部 >= %d" % 门)


## 取字符串开头（跳过空格）的那段数字；没有数字返回 -1。
func _首个整数(文本: String) -> int:
	var 数 := ""
	for i in 文本.length():
		var c := 文本[i]
		if c >= "0" and c <= "9":
			数 += c
		elif not 数.is_empty():
			break
	return int(数) if not 数.is_empty() else -1


func _遍历gd(根: String) -> Array[String]:
	var 结果: Array[String] = []
	var 目录 := DirAccess.open(根)
	if 目录 == null:
		return 结果
	目录.list_dir_begin()
	var 名 := 目录.get_next()
	while 名 != "":
		var 全 := 根.path_join(名)
		if 目录.current_is_dir():
			结果.append_array(_遍历gd(全))
		elif 名.ends_with(".gd"):
			结果.append(全)
		名 = 目录.get_next()
	目录.list_dir_end()
	return 结果


func _遍历tscn(根: String) -> Array[String]:
	var 结果: Array[String] = []
	var 目录 := DirAccess.open(根)
	if 目录 == null:
		return 结果
	目录.list_dir_begin()
	var 名 := 目录.get_next()
	while 名 != "":
		var 全 := 根.path_join(名)
		if 目录.current_is_dir():
			if 名 != "生成":
				结果.append_array(_遍历tscn(全))
		elif 名.ends_with(".tscn"):
			结果.append(全)
		名 = 目录.get_next()
	目录.list_dir_end()
	return 结果


## 断言解析到的字面在预期名单内。allow_system_fallback=true 时，
## 缺字体的机器会静默落到别的字体 —— 只断言「画出了文字」抓不到这种漂移。
func _查字体(主题: Theme) -> void:
	if 主题.default_font == null:
		_报错("主题缺 default_font")
		return
	if 主题.default_font_size != 皮肤表.默认字号:
		_报错("default_font_size=%d，应为 %d" % [主题.default_font_size, 皮肤表.默认字号])

	var 字面 := 主题.default_font.get_font_name()
	# 2026-09-26：字体表首项换成 **SimSun/宋体**（对方的宋体排版工作 —— 原版 Flash 就是
	# 宋体点阵观感，雅黑偏现代）。名单是"允许哪些"而不是"必须是哪一个"，
	# 缺字体的机器会往后落到雅黑，所以后四项仍留着。
	var 允许 := ["SimSun", "宋体", "Microsoft YaHei UI", "Microsoft YaHei", "微软雅黑",
		"Noto Sans SC", "Source Han Sans SC"]
	if not 允许.has(字面):
		_报错("字体解析到「%s」，不在预期名单 %s 内" % [字面, 允许])
	else:
		print("  字体解析到：", 字面)


func _查类型(主题: Theme) -> void:
	for 键: Variant in 皮肤表.类型规格:
		var 类型名 := String(键)
		var 规格: Dictionary = 皮肤表.类型规格[键]

		if 规格.has("继承"):
			var 基类 := String(规格["继承"])
			if 主题.get_type_variation_base(类型名) != 基类:
				_报错("%s 的变体基类应为 %s" % [类型名, 基类])

		for 项名: String in 规格.get("样式", {}):
			if not 主题.has_stylebox(项名, 类型名):
				_报错("缺样式 %s/%s" % [类型名, 项名])
				continue
			_查九宫格(主题.get_stylebox(项名, 类型名), 规格["样式"][项名], 类型名, 项名)

		for 项名: String in 规格.get("颜色", {}):
			if not 主题.has_color(项名, 类型名):
				_报错("缺颜色 %s/%s" % [类型名, 项名])

		for 项名: String in 规格.get("常量", {}):
			if not 主题.has_constant(项名, 类型名):
				_报错("缺常量 %s/%s" % [类型名, 项名])

		for 项名: String in 规格.get("图标", {}):
			if not 主题.has_icon(项名, 类型名):
				_报错("缺图标 %s/%s" % [类型名, 项名])
			elif 主题.get_icon(项名, 类型名) == null:
				_报错("图标为空 %s/%s" % [类型名, 项名])

		if 规格.has("字号"):
			var 字号项 := String(规格.get("字号项", "font_size"))
			if not 主题.has_font_size(字号项, 类型名):
				_报错("缺字号 %s/%s" % [类型名, 字号项])
			elif 主题.get_font_size(字号项, 类型名) != int(规格["字号"]):
				_报错("字号 %s/%s 不符" % [类型名, 字号项])


func _查九宫格(样式: StyleBox, 规格值: Variant, 类型名: String, 项名: String) -> void:
	if 规格值 == null:
		if not 样式 is StyleBoxEmpty:
			_报错("%s/%s 应为 StyleBoxEmpty" % [类型名, 项名])
		return
	if not 样式 is StyleBoxTexture:
		_报错("%s/%s 应为 StyleBoxTexture" % [类型名, 项名])
		return

	var 纹理样式: StyleBoxTexture = 样式
	if 纹理样式.texture == null:
		_报错("%s/%s 纹理为空" % [类型名, 项名])
		return

	var 参数: Array = 规格值
	var 路径 := String(参数[0])
	if not ResourceLoader.exists(路径):
		_报错("%s/%s 纹理路径不存在：%s" % [类型名, 项名, 路径])
		return

	var 边距: Variant = 皮肤表.九宫格.get(路径)
	if 边距 == null:
		return
	var 组: Array = 边距
	var 转置 := 参数.size() > 3 and bool(参数[3])
	var 期望 := [float(组[0]), float(组[1]), float(组[2]), float(组[3])]
	if 转置:
		期望 = [float(组[2]), float(组[3]), float(组[0]), float(组[1])]
	var 实际 := [
		纹理样式.texture_margin_left,
		纹理样式.texture_margin_right,
		纹理样式.texture_margin_top,
		纹理样式.texture_margin_bottom,
	]
	if 实际 != 期望:
		_报错("%s/%s 九宫格边距 %s，应为 %s" % [类型名, 项名, 实际, 期望])


## 重跑生成器并比对签入产物。手改 .tres 会在这里暴露。
func _查生成一致(签入: Theme) -> void:
	var 重建: Theme = 生成器.构建主题()
	if 重建 == null:
		_报错("生成器重建主题失败")
		return

	var 签入类型 := 签入.get_type_list()
	var 重建类型 := 重建.get_type_list()
	签入类型.sort()
	重建类型.sort()
	if 签入类型 != 重建类型:
		_报错("签入主题的类型集与重新生成不一致")
		return

	for 类型名 in 重建类型:
		for 项名 in 重建.get_color_list(类型名):
			if 签入.get_color(项名, 类型名) != 重建.get_color(项名, 类型名):
				_报错("颜色 %s/%s 与重新生成不一致（.tres 被手改？）" % [类型名, 项名])
		for 项名 in 重建.get_constant_list(类型名):
			if 签入.get_constant(项名, 类型名) != 重建.get_constant(项名, 类型名):
				_报错("常量 %s/%s 与重新生成不一致（.tres 被手改？）" % [类型名, 项名])
		for 项名 in 重建.get_font_size_list(类型名):
			if 签入.get_font_size(项名, 类型名) != 重建.get_font_size(项名, 类型名):
				_报错("字号 %s/%s 与重新生成不一致（.tres 被手改？）" % [类型名, 项名])
		for 项名 in 重建.get_stylebox_list(类型名):
			var 甲 := 签入.get_stylebox(项名, 类型名)
			var 乙 := 重建.get_stylebox(项名, 类型名)
			if 甲.get_class() != 乙.get_class():
				_报错("样式 %s/%s 类型与重新生成不一致" % [类型名, 项名])
				continue
			if 甲 is StyleBoxTexture and 乙 is StyleBoxTexture:
				var 甲纹: StyleBoxTexture = 甲
				var 乙纹: StyleBoxTexture = 乙
				if 甲纹.modulate_color != 乙纹.modulate_color:
					_报错("样式 %s/%s modulate 与重新生成不一致" % [类型名, 项名])
				if 甲纹.texture_margin_left != 乙纹.texture_margin_left \
						or 甲纹.texture_margin_right != 乙纹.texture_margin_right \
						or 甲纹.texture_margin_top != 乙纹.texture_margin_top \
						or 甲纹.texture_margin_bottom != 乙纹.texture_margin_bottom:
					_报错("样式 %s/%s 九宫格与重新生成不一致" % [类型名, 项名])

## ── 页签三态皮的真值（§3.139）────────────────────────────────
##   `MTabButton.as:38` `set enabled(v){selected=!v}` ⇒ **选中走 disabled 槽**（选中真皮）；
##   而 `pressed`/`hover_pressed` 是 `StyleUtil.as:8-12` 的 `down:−40` **瞬时按下皮**。
##   谁把 `pressed` 改回"选中皮"、或把按下皮那张常量漏接，这里就红。
func _查页签三态(主题: Theme) -> void:
	var 期望 := {
			"normal": "分页按钮未选.png",
			"hover": "分页按钮未选_悬停.png",
			"pressed": "分页按钮未选_按下.png",
			"hover_pressed": "分页按钮未选_按下.png",
			"disabled": "分页按钮选中.png",
	}
	for 态 in 期望:
		var 盒 := 主题.get_stylebox(态, String(皮肤表.变体_分页))
		if 盒 == null:
			_报错("`OrigTab` 的 `%s` 槽没有样式盒" % 态)
			continue
		if not (盒 is StyleBoxTexture):
			_报错("`OrigTab` 的 `%s` 槽不是 StyleBoxTexture（实测 %s）" % [态, 盒])
			continue
		var 图 := (盒 as StyleBoxTexture).texture
		var 路径 := String(图.resource_path) if 图 != null else ""
		if not 路径.ends_with(期望[态]):
			_报错("`OrigTab` 的 `%s` 槽该用 %s，实测 %s" % [态, 期望[态], 路径 if 路径 != "" else "（空图）"])


## ── 标准钮（`Button` 族）四态皮的真值（10-20）──────────────────────────
## 原版的这一颗是 `MButtonF`（元件 21）= `extends MButton3`（`MButtonF.as:6` 类体只有构造函数）
## ⇒ **一族一张 upSkin**，悬停 = `StyleUtil.as:43-47` 的 `getLightFilter(+30)`、
## 按下 = `−40`（加性、逐通道 clamp、不动 alpha）。落成三张图 = `开发工具/生成标准钮态图.py`。
## 三条都是**逮过的真错**：
##   ① `hover` 原来是 `按钮.png × modulate #fff4d8`（**乘性**，几乎不亮）；
##   ② 主题**根本没有 `hover_pressed`** ⇒ 鼠标压着按下时（引擎走 DRAW_HOVER_PRESSED=4）
##      漏到 Godot 自带主题那块 `StyleBoxFlat(1.0,0.365,0.365)` 红块上，用户看到的"点击效果"
##      就是那块红；而 `pressed` 槽原来挂的 `按钮按下.png` 其实一次都没画过；
##   ③ **故意不给 `Button` 声明 `hover_pressed`** —— 按下瞬间引擎走 DRAW_HOVER_PRESSED 档，
##     补了槽 = 按下闪一张别的皮；这一族的"按下变暗"只能逐颗挂 `原版三态钮.gd`。
##     （10-25 前这里写的理由是"一补槽裸 CheckBox 最小高就从 27 掉到 19、每枚勾挪 4 像素"——
##      那个 27 是 `CheckBox` **自己没声明这一槽**、回退到带 4 像素 content_margin 的兜底盒撑出来的，
##      不是不能动的死数；现在 `CheckBox` 单独补了空盒把地板收回皮高 19，Button 这条禁令换成三态的理由。）
func _查标准钮四态(主题: Theme) -> void:
	var 期望 := {
			"normal": "按钮.png",
			"hover": "按钮_悬停.png",
			"pressed": "按钮_按下.png",
	}
	for 态 in 期望:
		var 盒 := 主题.get_stylebox(态, "Button")
		if not (盒 is StyleBoxTexture):
			_报错("`Button` 的 `%s` 槽不是 StyleBoxTexture（实测 %s）" % [态, 盒])
			continue
		var 图: Texture2D = (盒 as StyleBoxTexture).texture
		var 路径 := String(图.resource_path) if 图 != null else ""
		if not 路径.ends_with(期望[态]):
			_报错("`Button` 的 `%s` 槽该用 %s，实测 %s" % [态, 期望[态], 路径 if 路径 != "" else "（空图）"])
		if (盒 as StyleBoxTexture).modulate_color != Color(1, 1, 1, 1):
			_报错("`Button` 的 `%s` 槽还带着 modulate %s ⇒ 那是乘性染色，不是原版的 ±30/−40 加性滤镜"
					% [态, str((盒 as StyleBoxTexture).modulate_color)])
	if 主题.has_stylebox("hover_pressed", "Button"):
		# ⚠ GDScript **不拼接相邻字符串字面量**（写成两串就是语法错）⇒ 长消息一律用 `+`。
		_报错("`Button/hover_pressed` 被声明了 ⇒ 按下瞬间会闪一张别的皮："
				+ "这一族的\"按下变暗\"只能逐颗挂 `脚本/界面/组件/原版三态钮.gd`"
				+ "（它把五槽并成实例私有的一张，还管\"松手回 STATE_UP\"，`MButton3.as:103-108`）")
	## 按下档的字色要钉住（挂了三态状态机的那几颗按下去时引擎走 DRAW_HOVER_PRESSED，
	## 这一项不写就沿默认主题拿白字 ⇒ 皮暗、字亮 = 原版没有的样子）。
	## ⚠ 颜色项**不影响几何**，所以这一条可以安全声明（对比上面那条样式槽）。
	var 期字 := Color(皮肤表.按钮色按下)
	var 实字 := 主题.get_color("font_hover_pressed_color", "Button")
	if 实字 != 期字:
		_报错("`Button/font_hover_pressed_color` 应是 down 档 %s，实得 %s"
				% [皮肤表.按钮色按下, str(实字)])
	## 地板层的**声明**：`CheckBox` 六态样式盒必须全声明且全是空盒。
	## 机制：`BaseButton::_get_minimum_size()` 取六态样式盒的最大 ⇒ 少写 `hover_pressed`
	## 就沿主题回拿到一块"不画但 content_margin 上下各 4"的兜底盒，最小高被顶到 27
	## （皮肤真高 19，`MCheckBox.as:81-82`）⇒ 皮在 27 的盒里居中、每一枚勾低 4 像素，
	## 且原版 20/21/22 的行距下上下两枚点击矩形重叠。**运行期**最小高 == 皮高的判据在
	## `测试/勾选框几何回归测试.gd`（那里 `await process_frame` 之后才读，见其头注第 ④ 条）。
	var 勾态 := ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]
	for 态 in 勾态:
		if not 主题.has_stylebox(态, "CheckBox"):
			_报错("`CheckBox/%s` 槽没声明 ⇒ 沿主题回退到带 content_margin 的兜底盒，"
					+ "裸 CheckBox 最小高会被顶离皮肤高 19（实测过的 4 像素下挪 + 行重叠）" % 态)
			continue
		var 盒 := 主题.get_stylebox(态, "CheckBox")
		if not (盒 is StyleBoxEmpty):
			_报错("`CheckBox/%s` 槽应是 StyleBoxEmpty（画不出东西、也不撑几何），实测 %s" % [态, 盒])
	var 皮: Texture2D = 主题.get_icon("unchecked", "CheckBox")
	if 皮 == null:
		_报错("主题里读不到 `CheckBox/unchecked` ⇒ 没法核对皮高")
	elif absf(皮.get_height() - 19.0) > 0.01:
		_报错("`CheckBox/unchecked` 皮高应是 19（`MCheckBox.as:81-82` `_height = upSkin.height`），实得 %s"
				% str(皮.get_height()))


## ── 数值件字号（10-20 用户报「左页的数字有点小，和原版本不一致」）────────────
## 左窗那四个数字（`小时值/分钟值/经验/金币`）原版是 `BaseUtil.getLabel("",16777215)`
## = `MLabel`/`MGlowLabel`（`BiGuanWindow.as:60-63`、`ShouyiWindow.as:80-85`），
## 而 `MLabel.as:218-219` 的默认 `TextFormat.size = 12` ⇒ 主题 `LineEdit` 字号必须是 12。
## （原来这里是 10，与本表自己的 `默认字号 = 12` 也矛盾。）
func _查数值输入框字号(主题: Theme) -> void:
	var 实 := 主题.get_font_size("font_size", "LineEdit")
	if 实 != 12:
		_报错("`LineEdit` 字号应是 12（`MLabel.as:218-219` 默认 TextFormat.size），实得 %d" % 实)
	## 只读框的字是**另一个主题项**：不写就漏到 Godot 自带主题的灰字上
	## （实测屏幕上"0"最高只到 (107,107,107) ⇒ 数字看着"又小又不对"有一半是这条）。
	## 原版 `ShouyiWindow.as:129 textColor = #FFFFFF`，没有可编辑/只读之分。
	## ⚠ 项名先跟**引擎自带主题**对一遍：主题项名写错不报错，`get_color("错名")`
	##   照样返回自己塞进去的值 ⇒ 门绿而屏幕上一点没变（10-20 写成 `font_read_only` 就这么假绿过）。
	var 真名s: Array = ThemeDB.get_default_theme().get_color_list("LineEdit")
	if not 真名s.has("font_uneditable_color"):
		_报错("`font_uneditable_color` 不在引擎自带主题的 LineEdit 字色项里（实得 %s）⇒ 这一族项名改了，判据要跟着改"
				% str(真名s))
		# 阳性对照：上面那条红必须能被"故意写错的名字"照出来 —— 这里自查一次引擎确实查无错名。
		if 真名s.has("font_read_only"):
			_报错("自查：引擎里居然有 font_read_only 这一项，那上面那条红是判据写错了")
	else:
		var 只读字 := 主题.get_color("font_uneditable_color", "LineEdit")
		if 只读字 != Color(1, 1, 1, 1):
			_报错("`LineEdit/font_uneditable_color` 应是 #ffffff（原版的数字件不分可编辑/只读），实得 %s"
					% str(只读字))
		if 主题.has_color("font_read_only", "LineEdit"):
			_报错("主题里还留着自造项名 `font_read_only`（引擎根本不读它）⇒ 删掉，只留 font_uneditable_color")
	## 只读态的底也不许压暗：`MTextInput_background`(元件 437) 就是一张底，没有"只读变暗"。
	var 只读盒 := 主题.get_stylebox("read_only", "LineEdit")
	if 只读盒 is StyleBoxTexture and (只读盒 as StyleBoxTexture).modulate_color != Color(1, 1, 1, 1):
		_报错("`LineEdit/read_only` 底板 modulate 应是纯白（不许压暗），实得 %s"
				% str((只读盒 as StyleBoxTexture).modulate_color))

