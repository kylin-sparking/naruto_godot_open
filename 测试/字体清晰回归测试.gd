extends SceneTree

## 「字发虚」这一族的回归门（用户实机报修 1.1 / 1.2 / 1.3 / 1.4 / 1.5，2026-10-22）。
##
## 用户的话（逐字）：
##   1.1 背包、商店上方的白色字体有点模糊，例如背包（28/150）
##   1.2 亲热天堂的功能介绍描述字体，偏小，模糊
##   1.3 右上角，地图、排行、线路字体模糊
##   1.4 右上角任务面板，任务字体模糊
##   1.5 左边中间的活动时间显示字体模糊
##
## 五处查到底的根子不是同一个，门也就分五条腿（合在一起才叫"修完"）：
##
## ① **整扇窗的落点必须踩在整像素上**。原版居中写的是
##    `Math.round(Config.STAGE_WIDTH - width >> 1)`（`PopUpMananger.as:141-142`、
##    `MWindow.as:366`）—— `-` 比 `>>` 先算，移位自己就把结果截成整数，
##    所以**原版不存在半像素窗口**。这边 `_apply_original_window` 原来写
##    `offset_left = -宽 * 0.5`：尺寸表 74 条可解析里 **43 条是奇数宽或高**，
##    背包 275 ⇒ x=342.5、人物 517 ⇒ 221.5 ⇒ 整扇窗（含标题白字）压在 .5 上，
##    宋体 12px 那份**内嵌点阵**被整块重采样 ⇒ 发虚（1.1）。
##    锚点留 0.5 是为了视口改大小还跟着走，所以偏移按「整落点 − 父的一半」反算。
## ② 字号真值 = **12**。`MLabel.as:219` `_textFormat.size = 12`；
##    `TreasureBoxWindow.as:270/277` 那两枚说明是裸 `new TextField()`、不建 TextFormat
##    ⇒ 吃 Flash 默认 12；`MCountDownTimeLabel.as` 的 `init()` 明写 `size = 12`。
##    宋体的内嵌点阵**只在 12px 起存在**，10/11px 退回轮廓+灰度 AA ⇒ 发虚
##    （§3.184/§3.191 那张点阵表的直接后果）。
## ③ 行高真值 = `textHeight + 4` = **19**（`MCountDownTimeLabel.doLayout`；
##    同一件事在追踪页签高 19 = 15 + 4 上再次成立）。原来的 11 是"13 行要塞进约 120
##    屏高"倒推出来的**拟合值**，它引用的 `测试/基线/原版界面/原版_系统消息.png`
##    **在仓里不存在** ⇒ 按 AS3 收回。
## ④ 1.4 量下来字号/字体/落点全对（12px、simsun_原版.ttf、整数），真正的缺陷是
##    **`任务列表` 往左溢出**：某行正文有断不开的词时 VBox 最小宽超过 170，
##    而它 `grow_horizontal = BOTH` ⇒ 溢出量对半分 ⇒ 整列左移到父节点之外，
##    被 `clip_contents` 削掉左边 14px。原版 `_contentPanel.width = 170` 是**定宽**、
##    文字超出只往右溢（Flash 的 x 是绝对摆放，不因子件宽而平移）⇒ 改 `GROW_END`。
##
## ## 2026-10-24 复测（#93「逐处量，不再复读旧结论」）新量到的三件事，各钉一条腿
##
## ⑤ **1.1 之前只量了坐标，没量字体** —— 而"点阵在不在"根本不是坐标能推出的。
##    直接解 `simsun_原版.ttf` 的 `EBLC`：`numSizes = 6`、六条 strike 的 ppem =
##    **12、13、14、15、16、17**（`腿 K` 逐字节读，两条独立字段互证）。
##    再用有显卡的实测（`开发工具/_探_点阵与描边实测.gd`，本工程真的这份字体、
##    真的描边值）逐格数像素：
##      · 「战斗属性」12/13/15/17px ⇒ 墨像素 **100.0% 实心**（1-bit 点阵的签名），
##      · 同样这几枚 **描边 2、描边 3 也还是 100.0%** ⇒ `outline_size` 不会把点阵挤回矢量灰度；
##      · 11px 掉到 2.0%、18px 掉到 8.1% ⇒ 上界 17 是实测出来的，不是"≥12"随口推的。
##    ⇒ 12 这条真值两头都硬：`EBLC` 里有 strike，光栅化确实吃了它。
## ⑥ **「背包(28/150)」里的数字任何字号都没有点阵**（实测实心 21–29%，10..18 全平）——
##    这 6 个 strike 只烘了 CJK 字形。这不是本工程的 bug：**原版同一个文件、Flash 自有
##    光栅器，数字同样是灰度**（拿 `测试/基线/原版界面/原版_背包.png` 的标题条 `x136..208 /
##    y17..28` 用同一口径量 ⇒ 实心 **52.5%**，覆盖率直方图就 `0.5/0.6/1.0` 三档 ⇒ 原版自己
##    就是"实心 + 一档中间灰"的 AA）。我们 12px 描边 2 实测 54.1% ⇒ **不比原版虚**。
##    所以 1.1 收口的口径是"钉住别再退化"（点阵表/导入参数/字号/落点四层），
##    而不是再动代码 —— 用户举的那串字里数字那半截，天生就是灰度。
## ⑦ 标题的黑边**是原版有的**：`MWindow.drawWindowLayout():195`
##    `titleTextField.filters = BaseUtil.getGlowFilter()`，而 `BaseUtil.as:124-127`
##    = `GlowFilter(0x000000, 1, 2, 2, 10, 1)`（strength 10 把辉光压成贴边的实心黑）
##    ⇒ 我们的 `outline_size = 2` + 黑描边是对等实现，**不是**多余的糊。钉在腿 J。
##
## ⚠ 口径：无头跑；载**运行时真正加载的烘焙地图场景**（`地图资源.playable_scene_path()`，
##   拿源场景验等于验了个假 —— `功能入口回归测试.gd:1-8` 那条老账）；不发包、不落存档。
## 运行：Godot --headless --path . --script res://测试/字体清晰回归测试.gd

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 默认地图 := "101010000"
const 功能窗口脚本 := "res://脚本/界面/功能窗口.gd"
const 活动窗口脚本 := "res://脚本/界面/窗口/活动窗口.gd"
const 小地图面板脚本 := "res://脚本/界面/小地图面板.gd"
const 系统消息脚本 := "res://脚本/界面/系统消息.gd"
const 系统消息场景 := "res://场景/界面/组件/系统消息.tscn"
const 亲热天堂场景 := "res://场景/界面/窗口/亲热天堂/亲热天堂窗口.tscn"
const 窗口尺寸表 := "res://数据/界面/窗口尺寸.json"
const 字体文件 := "res://素材/界面/simsun_原版.ttf"
const 字体导入 := "res://素材/界面/simsun_原版.ttf.import"
const 主题文件 := "res://素材/界面/原版主题.tres"
const 工程文件 := "res://project.godot"
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 界面皮肤 := preload("res://脚本/界面/窗口/界面皮肤.gd")
const 视口 := Vector2i(960, 560)
const 字号真值 := 12
const 倒计时行高 := 21.0
## `EBLC` 里真实存在的内嵌点阵 ppem（腿 K 逐字节读出来跟这张表对）。
## 下界 12 就是 字号真值的来头；上界 17 是像素实测出来的（18px 已退灰度）。
const 点阵字号真值表: Array = [12, 13, 14, 15, 16, 17]

## 各腿的判据总数（不含下面这条"总数对不对"本身 —— 它是最后加的，把自己算进去就永远差一）。
## 为什么要有这条：GDScript 的运行时错误只掐断**当前那个函数**，`_跑` 会带着剩下的腿继续往下跑，
## 于是 `红 0 条` 照样打印。实测过一次 `Theme.get_theme_constant` 打错，腿 J 被拦腰截掉 4 条，
## 汇总仍显示绿灯 —— 只有总数能发现。加/删判据时改这个数字。
## 2026-10-25：84 → 87（腿 E 加 3 条 —— default_font 不是 FontVariation（全局加粗已回滚，
## 它会把数字/字母抹糊）、窗口标题变体是 FontVariation 且 embolden 与皮肤表同步、base_font 指得到文件）。
## 2026-11-07：98 → 99（腿 ③ 加「活动时间贴左 x=6」；底边那条从"≤ 聊天顶−6"改成
## 精确钉 AS3 锚点 聊天顶−60 + 行高，判数不变）。
const 判数真值 := 99

var 红: Array[String] = []
var 判 := 0
var 日志: Array[String] = []
## 解析 sfnt 目录时读到的标签名，给"解析器自己有没有对齐"那条判据用（腿 J）。
var 目录标签: Array[String] = []


func _记(过: bool, 话: String) -> void:
	判 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 话])
	if not 过:
		红.append(话)


func _帧(n: int) -> void:
	for _i in n:
		await process_frame


func _整(值: float) -> bool:
	return 值 == floorf(值)


## 任务面板那族「不许描边/阴影」的判据：outline_size 必须 0，且描边色、阴影色都全透明。
## 只删 override 不够 —— `原版主题.tres` 给 Label/Button 烘的默认描边就是 2。
func _无描边阴影(控件: Control) -> bool:
	var 描边色 := 控件.get_theme_color("font_outline_color")
	var 阴影色 := 控件.get_theme_color("font_shadow_color")
	return 控件.get_theme_constant("outline_size") == 0 and 描边色.a == 0.0 and 阴影色.a == 0.0


## 尺寸表读一遍，腿 A/K 都按它算期望落点 —— 页名/宽/高/标题四处同源于 `数据/界面/窗口尺寸.json`：
## 在门里再抄一份数字，表按 AS3 改值时这边不会跟着走，量到的就是过期的落点。
func _尺寸(页: String) -> Dictionary:
	var 表: Variant = JSON.parse_string(FileAccess.get_file_as_string(窗口尺寸表))
	if typeof(表) != TYPE_DICTIONARY or not (表 as Dictionary).has(页):
		return {}
	return (表 as Dictionary)[页] as Dictionary


func _找(根: Node, 脚本路: String) -> Node:
	if 根.get_script() != null and str(根.get_script().resource_path) == 脚本路:
		return 根
	for 子 in 根.get_children():
		var 得 := _找(子, 脚本路)
		if 得 != null:
			return 得
	return null


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = 视口
	var 场景路径: String = 地图资源.playable_scene_path(默认地图)
	_记(场景路径.contains("场景/生成/"),
		"载的是烘焙场景（%s）—— 实机走的就是这一份" % 场景路径)
	var packed := load(场景路径) as PackedScene
	if packed == null:
		_记(false, "地图场景加载失败，后面的腿全跳过")
		_尾()
		return
	var 场景 := packed.instantiate()
	root.add_child(场景)
	current_scene = 场景
	await _帧(14)
	var 管理 := 场景.get_node_or_null("窗口管理")
	_记(管理 != null, "场景里有 `窗口管理`（① 两条腿都要它建窗）")
	_A_窗口整落点(管理)
	_B_居中数学()
	_C_源码不许半像素()
	_D_拖动收整(管理)
	await _I_改视口仍整数(管理)
	_K_标题白字实测(管理)
	_J_点阵与光栅真值()
	var 面板: Node = _找(场景, 小地图面板脚本)
	_记(面板 != null, "地图场景里挂着小地图面板（②③④ 三条腿都要它）")
	if 面板 != null:
		_E_右上角字号(面板)
		await _F_追踪栏不左溢(面板)
	await _G_系统消息()
	_H_亲热天堂字号()
	await _L_说明走漏斗()
	_尾()


## —— ① 奇数宽/高的窗，落点必须是**整数**，且等于原版的 `(父 − 尺寸) >> 1` ——
## 页名从尺寸表取（用户举的是「背包、商店」，商店那条键是 `NPC商店`、标题烘的是「交易」）。
func _A_窗口整落点(管理: Node) -> void:
	if 管理 == null:
		return
	for 页 in ["背包", "人物", "NPC商店"]:
		var 规格 := _尺寸(页)
		if 规格.is_empty():
			_记(false, "尺寸表里没有 %s（① 这条腿等于没测）" % 页)
			continue
		var 宽: float = float(规格.get("宽", 0))
		var 高: float = float(规格.get("高", 0))
		var 窗: Node = 管理.call("取或建窗口", 页)
		if 窗 == null:
			_记(false, "%s 窗建不出来（① 这条腿等于没测）" % 页)
			continue
		窗.call("_apply_original_window", 页)
		var 外: Control = 窗.get("_window") as Control
		var 父: Control = (外.get_parent() as Control) if 外 != null else null
		if 外 == null or 父 == null:
			_记(false, "%s 窗里没有 `_window` 或它没有 Control 父节点" % 页)
			continue
		_记(父.size == Vector2(视口.x, 视口.y),
			"%s 的宿主铺满视口（实得 %s）—— 落点公式的父尺寸要钉住" % [页, str(父.size)])
		var 位 := 外.get_global_position()
		var 期望 := Vector2(floorf((父.size.x - 宽) * 0.5), floorf((父.size.y - 高) * 0.5))
		_记(位 == 期望, "%s 落点 = (%s, %s)，原版口径 (%s, %s)" % [
			页, str(位.x), str(位.y), str(期望.x), str(期望.y)])
		_记(_整(位.x) and _整(位.y),
			"%s 落在整像素上（外框 %s×%s 是奇数，旧写法把整扇窗压到 .5）" % [页, str(宽), str(高)])
		_记(absf(外.size.x - 宽) < 0.001 and absf(外.size.y - 高) < 0.001,
			"%s 外框尺寸仍是 %s×%s（收整落点不许把尺寸一起改了）" % [页, str(宽), str(高)])


## —— ① 的数学腿：`_居中偏移` 对**奇偶两种父尺寸**都要把落点送回整数 ——
## 反算式 `floor((父−子)/2) − 父/2` 在父为奇数时偏移本身带 .5，
## 但 `position = 锚点(父/2) + 偏移` 里两个 .5 正好抵消 ⇒ 落点还是整数。
## 只在纯函数上量，不开窗 —— 视口能不能是奇数不由我们决定。
func _B_居中数学() -> void:
	var 脚: GDScript = load(功能窗口脚本) as GDScript
	if 脚 == null:
		_记(false, "功能窗口.gd 读不到，① 的数学腿跳过")
		return
	for 组 in [[960.0, 275.0], [961.0, 275.0], [560.0, 394.0], [561.0, 394.0], [961.0, 517.0]]:
		var 父: float = 组[0]
		var 子: float = 组[1]
		var 落点: float = 父 * 0.5 + float(脚.call("_居中偏移", 父, 子))
		var 期望: float = floorf((父 - 子) * 0.5)
		_记(落点 == 期望 and _整(落点),
			"父=%s 子=%s ⇒ 落点 %s（要 %s，且整数）" % [str(父), str(子), str(落点), str(期望)])


## —— ① 的源码 tripwire：`_window.offset_*` 上那种 `* 0.5` 的写法必须绝迹 ——
## 为什么钉源码而不多开几扇窗：改回旧写法时，只要视口恰好是偶数，
## "落点 = floor((父−子)/2)" 这条断言**照样绿**（§3.245「门绿着但腿没跑」同族）。
func _C_源码不许半像素() -> void:
	var 源 := FileAccess.get_file_as_string(功能窗口脚本)
	_记(源.length() > 0, "功能窗口.gd 读到（%d 字节）" % 源.length())
	var 漏网: Array[String] = []
	for 行 in 源.split("\n"):
		var t := String(行).replace("\t", "")
		if t.strip_edges().begins_with("#"):
			continue
		if t.contains("_window.offset") and t.contains("0.5"):
			漏网.append(t.strip_edges())
	_记(漏网.is_empty(), "`_window.offset_*` 里不许再出现 0.5 的折半（漏网：%s）" % " / ".join(漏网))


## —— ② 拖动之后也要留在整像素上（同一个根因的另一条腿）——
func _D_拖动收整(管理: Node) -> void:
	if 管理 == null:
		return
	var 窗: Node = 管理.call("取或建窗口", "背包")
	if 窗 == null:
		_记(false, "背包窗建不出来，拖动腿跳过")
		return
	窗.call("_apply_original_window", "背包")
	var 外: Control = 窗.get("_window") as Control
	if 外 == null:
		_记(false, "拖动腿缺 `_window`")
		return
	窗.set("_dragging", true)
	窗.set("_drag_offset", Vector2(10.0, 6.0))
	var 移动 := InputEventMouseMotion.new()
	移动.global_position = Vector2(120.37, 88.62)
	窗.call("_on_title_input", 移动)
	var 位 := 外.get_global_position()
	_记(_整(位.x) and _整(位.y),
		"拖到小数坐标后停在整像素（实得 %s, %s；旧写法停在 110.37, 82.62）" % [str(位.x), str(位.y)])
	窗.set("_dragging", false)


## —— ② 视口改成**奇数**之后仍要停在整像素上 ——
## 0.5 锚点的原罪：父尺寸由偶转奇时，`position = 0.5×父 + 偏移` 里那个 0.5 会自己冒出来，
## `_摆窗口居中()` 只在开窗那一次算过 ⇒ 必须靠 `_resize_overlay()` 把当前位置收整。
## 这条腿量的是"改完视口之后的落点"，和腿①（开窗落点）是两个不同的点。
func _I_改视口仍整数(管理: Node) -> void:
	if 管理 == null:
		return
	var 窗: Node = 管理.call("取或建窗口", "背包")
	if 窗 == null:
		_记(false, "改视口腿缺背包窗")
		return
	窗.call("_apply_original_window", "背包")
	var 外: Control = 窗.get("_window") as Control
	if 外 == null:
		_记(false, "改视口腿缺 `_window`")
		return
	root.size = Vector2i(961, 561)
	await _帧(4)
	var 位 := 外.get_global_position()
	_记(_整(位.x) and _整(位.y),
		"视口 960×560 → 961×561（奇偶变了）之后落点仍是整像素（实得 %s, %s）" % [str(位.x), str(位.y)])
	root.size = 视口
	await _帧(2)


## —— ③ 右上角五枚：地图名 / 坐标 / 地图 / 排行 / 线路 ——
## 真值 `MLabel.as:219` `_textFormat.size = 12`；`_mapName`、`_positionInput` 都是
## `new MGlowLabel()`（`SmallMapWindow.as:1014/1021`，不另设字号），
## 三枚钮走 `MButton3.text` ⇒ 同一个 12。
func _E_右上角字号(面板: Node) -> void:
	for 名 in ["小地图区域/小地图/地图名", "小地图区域/小地图/坐标",
			"小地图区域/小地图/地图文字钮", "小地图区域/小地图/排行文字钮",
			"小地图区域/小地图/换线文字钮"]:
		var c := 面板.get_node_or_null(名) as Control
		if c == null:
			_记(false, "右上角缺节点 %s（字号无从量起）" % 名)
			continue
		var 号 := c.get_theme_font_size("font_size")
		_记(号 == 字号真值, "%s 字号 = %d（要 %d；低于它宋体没有内嵌点阵）" % [c.get_name(), 号, 字号真值])


## —— ④ 任务追踪：字号全 ≥12，且整列不许往左跑出被裁区 ——
func _F_追踪栏不左溢(面板: Node) -> void:
	var 内容区 := 面板.get_node_or_null("小地图区域/任务追踪/任务内容区") as Control
	var 列表 := 面板.get_node_or_null("小地图区域/任务追踪/任务内容区/任务列表") as Control
	if 内容区 == null or 列表 == null:
		_记(false, "追踪栏缺 `任务内容区` / `任务列表`")
		return
	var 起 := 列表.get_child_count()
	_记(列表.get_global_position().x == 内容区.get_global_position().x,
		"任务列表左沿和父节点对齐（实得 %s vs %s；旧写法 BOTH 把溢出对半分，整列削进裁区）"
		% [str(列表.get_global_position().x), str(内容区.get_global_position().x)])
	for 项 in [
		{"id": "9001", "name": "暗部任务-清剿", "request_level": 30, "completed": false},
		{"id": "9002", "name": "寻找：[终结谷浅滩]暗部忍者-", "request_level": 25, "completed": true},
	]:
		var 行: Node = 面板.call("_create_quest_renderer", 项, true)
		if 行 is Control:
			列表.add_child(行)
	await _帧(4)
	_记(列表.get_child_count() == 起 + 2,
		"追踪列表真的建出了两行（%d → %d；0 行 = 下面的字号判据等于没跑）" % [起, 列表.get_child_count()])
	var 最小号 := 999
	var 行号 := 起
	for 行 in 列表.get_children().slice(起):
		行号 += 1
		if not (行 is Control):
			continue
		for 件 in (行 as Node).get_children():
			if 件 is Label:
				最小号 = mini(最小号, (件 as Label).get_theme_font_size("font_size"))
				_记(_无描边阴影(件 as Control),
					"追踪第 %d 行标题不许描边/阴影（outline=%d）" % [行号, (件 as Control).get_theme_constant("outline_size")])
			elif 件 is RichTextLabel:
				最小号 = mini(最小号, (件 as RichTextLabel).get_theme_font_size("normal_font_size"))
				_记(_无描边阴影(件 as Control),
					"追踪第 %d 行正文不许描边/阴影（outline=%d）" % [行号, (件 as Control).get_theme_constant("outline_size")])
	_记(最小号 >= 字号真值, "追踪行最小字号 = %d（要 ≥%d）" % [最小号, 字号真值])
	# 2026-11-02 用户点名「任务面板内字体模糊，可能需要去掉字体阴影」⇒ 整块页签/正文都不留描边。
	# 期望 0 是**用户裁定**（原版 `MGlowLabel` / `getGlowFilter()` 是 Flash 柔和外发光；
	# 在这份 14px 宋体点阵上换实心黑描边只会糊成一圈）。⚠ 主题默认烘着 2，所以钉的是实际取值。
	for 名 in ["小地图区域/任务追踪/当前任务页签", "小地图区域/任务追踪/可接任务页签",
			"小地图区域/任务追踪/更多可玩内容"]:
		var 件节 := 面板.get_node_or_null(名) as Control
		if 件节 == null:
			_记(false, "任务面板缺 %s（无描边那条腿没量到）" % 名)
			continue
		_记(_无描边阴影(件节),
			"%s 不许描边/阴影（outline=%d）" % [件节.get_name(), 件节.get_theme_constant("outline_size")])
	_记(列表.get_global_position().x == 内容区.get_global_position().x,
		"塞进带断不开词的长行之后，整列仍然没往左跑（实得 %s，父左沿 %s）" % [
			str(列表.get_global_position().x), str(内容区.get_global_position().x)])


## —— ③ 左侧倒计时：字号 12、行高 19（`MCountDownTimeLabel.as` 的 `size = 12`
##    与 `height = textHeight + 4`；textHeight 在 Flash 的 12px 宋体上是 15）——
func _G_系统消息() -> void:
	var 包 := load(系统消息场景) as PackedScene
	if 包 == null:
		_记(false, "系统消息.tscn 加载失败")
		return
	var 脚本 := load(系统消息脚本) as GDScript
	# `GDScript` 没有 `get_constant()`（那条写法会当场抛 ⇒ 整条腿静默消失，§3.245），
	# 常量要从 `get_script_constant_map()` 里取。
	var 常量 := 脚本.get_script_constant_map()
	_记(int(常量.get("字号", -1)) == 14,
		"系统消息字号应为 14，实得 %s" % str(常量.get("字号", "缺")))
	_记(float(常量.get("行高", -1.0)) == 倒计时行高,
		"系统消息 const 行高 = %s（要 %s = textHeight 15 + 4）" % [
			str(常量.get("行高", "缺")), str(倒计时行高)])
	var 节点 := 包.instantiate()
	root.add_child(节点)
	await _帧(2)
	var 样本: Array = []
	for i in 3:
		样本.append({"text": "距世界Boss刷新还有", "seconds": 3600 + i, "基准毫秒": Time.get_ticks_msec()})
	节点.call("_应用", 样本)
	var 列表 := 节点.get_node_or_null("界面区域/系统消息/消息列表") as Control
	if 列表 == null or 列表.get_child_count() < 2:
		_记(false, "系统消息没建出 3 行（实际 %d）"
			% (列表.get_child_count() if 列表 != null else -1))
	else:
		var 首 := 列表.get_child(0) as Label
		var 次 := 列表.get_child(1) as Label
		_记(首.get_theme_font_size("font_size") == 14,
			"倒计时行实际渲染字号 = %d" % 首.get_theme_font_size("font_size"))
		_记(首.position.y - 次.position.y == 倒计时行高,
			"相邻两行行距 = %s（要 %s，且按原版从锚点往上叠）" % [
				str(首.position.y - 次.position.y), str(倒计时行高)])
		_记(首.get_theme_constant("outline_size") == 0 and 首.get_theme_color("font_shadow_color").a == 0.0,
			"活动时间无描边与阴影")
		var 列 := 节点.get_node_or_null("界面区域") as Control
		_记(列 != null and 列.position.x == 6.0,
			"活动时间贴左侧（原版 x=6），实得 %s" % str(列.position.x if 列 != null else "缺"))
		var 原尺寸 := root.size
		for 尺寸 in [Vector2i(960, 560), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			root.size = 尺寸
			节点.call("_重排")
			var 首行 := 列表.get_child(0) as Label
			var 底 := 首行.get_global_transform_with_canvas().origin.y + 首行.size.y
			# 锚点 = 聊天顶 - 60（UIMain2.as:4418），首行从锚点往上叠，块底 = 锚 + 行高
			var 期望底 := float(尺寸.y) - 266.0 - 60.0 + 倒计时行高
			_记(absf(底 - 期望底) < 0.5,
				"活动时间在聊天框上边 60、左侧地图中部：%s，底边 %.1f（要 %.1f）" % [str(尺寸), 底, 期望底])
		root.size = 原尺寸
	节点.queue_free()


## —— ② 亲热天堂两枚说明：调用点入参必须是 12（源码 tripwire）——
## 这条只钉"入参"，渲染那一头由腿 L 接手：两枚合起来才成链
## （入参 12 → `configure_label` → Label 上真的是 12 + 点阵字体 + 黑描边 + 无阴影）。
## 单有这条的话，`configure_label` 哪天不再写 `font_size` override，调用点照样绿。
func _H_亲热天堂字号() -> void:
	var 源 := FileAccess.get_file_as_string(活动窗口脚本)
	_记(源.length() > 0, "活动窗口.gd 读到（%d 字节）" % 源.length())
	var 命中 := 0
	for 行 in 源.split("\n"):
		var t := String(行).replace("\t", "")
		if t.strip_edges().begins_with("#"):
			continue
		var m := RegEx.create_from_string(
			"_configure_label\\(page\\.get_node\\(\"兑换(?:说明|流程)\"\\) as Label, (\\d+)"
		).search(t)
		if m != null:
			命中 += 1
			_记(int(m.get_string(1)) == 字号真值,
				"%s ⇒ 字号入参 %s（要 %d）" % [t.strip_edges(), m.get_string(1), 字号真值])
	_记(命中 == 2, "两枚说明的入参都找到了（实得 %d 处；0 处 = 这条腿没跑）" % 命中)


## —— ② 的渲染腿：把亲热天堂那张页场景**真的实例化**，走一遍漏斗再读回来 ——
## 起整扇活动窗确实贵，但页场景（`亲热天堂窗口.tscn`）单独实例化不贵 ⇒ 没理由只量源码。
func _L_说明走漏斗() -> void:
	var 包 := load(亲热天堂场景) as PackedScene
	if 包 == null:
		_记(false, "亲热天堂窗口.tscn 加载失败，漏斗腿跳过")
		return
	var 页 := 包.instantiate() as Control
	if 页 == null:
		_记(false, "亲热天堂页实例化失败，漏斗腿跳过")
		return
	root.add_child(页)
	await _帧(2)
	# 先拿一个**和主题默认值不同**的字号走漏斗：主题的 default_font_size 也是 12，
	# 只用 12 量的话，`configure_label` 哪天不再写 `font_size` override，这边照样读到 12 ⇒ 腿是假的。
	# 15 是随手挑的：既离开主题默认值，又还在点阵档上（见上面那张 strike 表）。
	var 探针 := 15
	_记(点阵字号真值表.has(探针), "漏斗探针字号 %d 也在点阵档上（挑它就是为了离开主题默认的 %d）" % [探针, 字号真值])
	for 名 in ["兑换说明", "兑换流程"]:
		var 标签 := 页.get_node_or_null(名) as Label
		if 标签 == null:
			_记(false, "亲热天堂页里没有 Label「%s」（漏斗腿等于没测）" % 名)
			continue
		界面皮肤.configure_label(标签, 探针, Color("#ff9100"))
		_记(标签.get_theme_font_size("font_size") == 探针,
			"漏斗把非默认字号 %d 真的写进了「%s」（实得 %d；写不进去 = 这条腿量的是主题默认值，不是漏斗）" % [
				探针, 名, 标签.get_theme_font_size("font_size")])
		界面皮肤.configure_label(标签, 字号真值, Color("#ff9100"))
		_记(标签.get_theme_font_size("font_size") == 字号真值,
			"走完漏斗后「%s」渲染字号 = %d（要 %d）" % [名, 标签.get_theme_font_size("font_size"), 字号真值])
		# ⚠ 这条只证"漏斗把规则值写到了 Label 上"，它**拿规则值和自己比**，天然杀不掉
		#    （M3 那一刀：规则值 2→3，这边两枚照绿）。规则值和主题烘的值是否一致由腿 J 钉。
		_记(标签.get_theme_constant("outline_size") == 皮肤表.文字规则_描边数值,
			"「%s」描边 = 规则值 %d（漏斗确实把规则值写下来了，不是写死的旧 3）" % [
				名, 标签.get_theme_constant("outline_size")])
		_记(标签.get_theme_color("font_shadow_color").a == 0.0,
			"「%s」阴影 alpha = 0（原版没有投影，多一层影子就是糊）" % 名)
		var 字体 := 标签.get_theme_font("font")
		var 路 := 皮肤表.字体落点(字体) if 字体 != null else "（没取到字体）"
		_记(字体 != null and 路.contains("simsun_原版"),
			"「%s」不设 font override ⇒ 吃到的正是 %s（点阵烘在这份里）" % [名, 路])
	页.queue_free()


## —— ⑤ 字体侧四层真值：点阵表 / 光栅化参数 / 主题默认 / 工程不缩放 ——
## 为什么钉这四样而不是"再截一张图对比"：1.1 那族的根有两个在坐标之外 ——
## **点阵存不存在**由 `EBLC` 说了算，**吃不吃得到**由 `.import` 那几项 + 工程不给 stretch 说了算。
## 这四处此前一扇门都没读过，任何一个被顺手翻掉，全工程每一行 12px 汉字一起退回灰度 AA，
## 而门全绿（§3.245「门绿着但腿没跑」同族，只是这次连腿都没有）。
func _J_点阵与光栅真值() -> void:
	var 点阵 := _读点阵ppem表()
	# 先证"解析器自己有没有对齐"，再证它读出来的数 —— 否则一次字节步长写错就是"读到 0 条"，
	# 看着像字体坏了，其实是腿坏了（§3.245 那条老规矩在二进制上也成立）。
	_记(目录标签.has("cmap") and 目录标签.has("head") and 目录标签.has("EBDT"),
		"sfnt 目录按 16 字节对齐读到了 %d 个标签，且含 cmap/head/EBDT（缺 ⇒ 是解析器漂了，不是字体没点阵）" % 目录标签.size())
	_记(not 点阵.is_empty(),
		"从 `%s` 解出 EBLC 内嵌点阵表（读到 %d 条 strike）" % [字体文件, 点阵.size()])
	_记(点阵 == 点阵字号真值表,
		"strike 的 ppem = %s（要 %s；换字库/重烘字体就重跑 `开发工具/_探_点阵与描边实测.gd` 再改这张表）" % [
			str(点阵), str(点阵字号真值表)])
	_记(点阵.has(字号真值), "字号真值 %d 落在点阵档上（低于它没有 strike ⇒ 1.2 那句「偏小又模糊」是同一件事）" % 字号真值)

	var 导入 := _读导入参数()
	# ⚠ 下面三条"= 几"的语义别再靠猜：取值是从引擎自己吐出来的枚举表读回来的
	# （`ClassDB.class_get_property_list("FontFile")` 的 `hint_string`，按声明顺序就是取值顺序）：
	#   antialiasing 0=None / 1=Grayscale / 2=LCD Subpixel
	#   hinting      0=None / 1=Light    / 2=Normal
	#   subpixel_positioning 0=Disabled / 1=Auto / 2=半像素 / 3=四分之一像素
	for 项 in [
		["disable_embedded_bitmaps", "false", "翻了就没有点阵可用，整份 UI 直接退灰度"],
		# 2026-10-25 深夜（用户：「字体不模糊了，但是还是感觉小，也不算很清晰」）：
		# 宋体**没有 ASCII 点阵**（EBLC 只覆盖汉字，见上面 strike 那几条腿），数字/字母只能走轮廓。
		# 1=灰度时 12px 的竖笔画只覆盖约 86% 像素 ⇒ 实测字芯是 219 灰、原版截图是 255 纯白（同一字形、同一 8px 高）。
		# 0=单色后字芯全 255、笔画边缘仍是 1-bit（不再有中间灰）⇒ 和原版逐像素同级；汉字点阵不受影响。
		["antialiasing", "0", "0=单色（ASCII 走轮廓，12px 必须单色才是实心 255）；1=灰度会把字芯压到 219"],
		["hinting", "2", "2=normal，把字形对齐像素网格；0 会漂到网格之间"],
		["subpixel_positioning", "0", "0=关；开了会把整块点阵推到 .33/.5 的位置上重采样"],
		["multichannel_signed_distance_field", "false", "MSDF 是距离场，天生比点阵软"],
		["oversampling", "0.0", "放大重采样 = 主动把点阵糊掉"],
	]:
		var 键 := String(项[0])
		var 得 := String(导入.get(键, "（没有这一项）"))
		_记(得 == String(项[1]), "%s = %s（要 %s —— %s）" % [键, 得, String(项[1]), String(项[2])])

	var 主题 := load(主题文件) as Theme
	_记(主题 != null, "主题 `%s` 加载得到（default_font 烘在这里）" % 主题文件)
	if 主题 != null:
		var 默字 := 主题.get_default_font()
		var 默路 := 皮肤表.字体落点(默字) if 默字 != null else "（没有 default_font）"
		_记(默字 != null and 默路.contains("simsun_原版"),
			"主题 default_font = %s" % 默路)
		# 2026-10-25 晚：§3.275 的全局合成加粗已回滚 —— 它把**所有** ASCII 都加粗，
		# 用户实机报「数值方面，数字、字母之类的都模糊了」（合成加粗把 12px 轮廓边缘抹成灰）。
		# 对 AS3 也只有 `MWindow.as:69-74` 的窗口标题 bold；数量字 `ItemWindowCell.as:60-62`
		# 没有 bold ⇒ default_font 必须是裸 FontFile，标题那层单独钉在 `OrigWindowTitle` 上。
		_记(not (默字 is FontVariation),
			"主题 default_font 不该是 FontVariation（实际 %s）—— 全局合成加粗会把数字/字母抹糊，见 原版皮肤表.标题加粗量" % str(默字 if 默字 != null else "<无>"))
		var 标题字 := 主题.get_font("font", 皮肤表.变体_窗口标题)
		_记(标题字 is FontVariation
				and is_equal_approx((标题字 as FontVariation).variation_embolden, 皮肤表.标题加粗量),
			"窗口标题字体应是 FontVariation(embolden=%s)（实际 %s）—— 原版 MWindow 标题 bold；重跑 开发工具/生成界面主题.gd" % [
				str(皮肤表.标题加粗量), str(标题字 if 标题字 != null else "<无>")])
		_记(标题字 != null and 皮肤表.字体落点(标题字).contains("simsun_原版"),
			"标题 FontVariation.base_font 没指到 simsun_原版（不写 base_font，标题什么都不渲染）")
		_记(主题.get_default_font_size() == 字号真值,
			"主题 default_font_size = %d（要 %d；漏了它，没写 override 的 Label 吃 Godot 默认 16）" % [
				主题.get_default_font_size(), 字号真值])
		# 规则值和主题烘的值是**两份文件**：`原版皮肤表.gd` 改一笔、`原版主题.tres` 没重生成，
		# 就会出现"主题给 2、漏斗给 3"这种互相打架（§3.52.3(d) 那次 3→2 就是这个形状）。
		# 变异 M3（规则值 2→3）证了这条判据真能红：腿 L 同那一刀是绿的，只有这里红。
		var 烘描边 := int(主题.get_constant("outline_size", "Label"))
		_记(烘描边 == 皮肤表.文字规则_描边数值,
			"主题烘的 Label 默认描边 %d == 皮肤表规则值 %d（不等就是两份文件各改各的，全工程文字粗细看谁压后）" % [
				烘描边, 皮肤表.文字规则_描边数值])
		_记(int(主题.get_constant("shadow_offset_x", "Label")) == 0
			and int(主题.get_constant("shadow_offset_y", "Label")) == 0,
			"主题烘的 Label 阴影偏移 = (0,0)（偏移一开，灰度 AA 的数字那半截会拖出重影）")

	var 有模式 := false
	for 行 in FileAccess.get_file_as_string(工程文件).split("\n"):
		if String(行).strip_edges().begins_with("window/stretch/mode="):
			有模式 = true
	_记(not 有模式,
		"project.godot 里不许出现 `window/stretch/mode`（设成 canvas_items 会把 960×560 整块画布放大 ⇒ 位图和点阵一起糊，project.godot:42 那条 ⚠ 说的就是这件事）")
	_记(FileAccess.get_file_as_string(工程文件).contains('window/stretch/scale_mode="integer"'),
		"scale_mode 仍是 \"integer\"")


## 直接解 sfnt 目录找 EBLC，逐条 strike 读 ppem。
## ⚠ 三处独立读数互证（+19 的 xPpem、+44/+45 的 deviceX/Y）：**对不上就当读不到**，
##   不猜别的步长 —— 这张表红了只可能是字体换了，那时要重跑像素实测再改常量，不是改解析式。
func _读点阵ppem表() -> Array:
	目录标签 = []
	var f := FileAccess.open(字体文件, FileAccess.READ)
	if f == null:
		return []
	f.big_endian = true
	f.seek(0)
	f.get_32()                       # sfnt version
	var 表数 := f.get_16()
	f.get_16()
	f.get_16()
	f.get_16()                       # searchRange / entrySelector / rangeShift
	var 表: Dictionary = {}
	for _i in 表数:
		var tag := ""
		for _k in 4:
			tag += char(f.get_8())
		f.get_32()                   # checkSum
		表[tag] = f.get_32()         # offset
		f.get_32()                   # length —— ⚠ 这条必须读掉：目录项是 16 字节，
									 #    少读一个就每轮偏 4 字节，下一个"tag"其实是 length，
									 #    里面全是 0x00 ⇒ `char(0)` 一路刷 "Unexpected NUL" 警告，
									 #    而 `表.has("EBLC")` 恒假 ⇒ 整条腿静默读到 0 条 strike。
		目录标签.append(tag)
	if not 表.has("EBLC"):
		f.close()
		return []
	var 基: int = int(表["EBLC"])
	f.seek(基)
	if f.get_32() != 0x00020000:     # 不是 EBLC v2.0 ⇒ 48 字节步长这条假设不成立
		f.close()
		return []
	var 条数 := f.get_32()
	var 出: Array = []
	for i in 条数:
		var 格 := 基 + 8 + 48 * i
		f.seek(格 + 18)
		var 甲 := f.get_8()
		f.seek(格 + 44)
		var 乙 := f.get_8()
		var 丙 := f.get_8()
		if 甲 != 乙 or 乙 != 丙:
			f.close()
			return []
		出.append(甲)
	f.close()
	出.sort()
	return 出


## `.import` 是 `[params]` 下的 key=value；只取参数段，避免和 `[remap]`/`[deps]` 的同名键串。
func _读导入参数() -> Dictionary:
	var 出: Dictionary = {}
	var 在参数段 := false
	for 行 in FileAccess.get_file_as_string(字体导入).split("\n"):
		var t := String(行).strip_edges()
		if t.begins_with("["):
			在参数段 = (t == "[params]")
			continue
		if not 在参数段 or not t.contains("="):
			continue
		var 断 := t.find("=")
		出[t.substr(0, 断)] = t.substr(断 + 1)
	return 出


## —— ⑤/⑦ 1.1 的字体侧：三扇窗标题**实际渲染**到的字号/字体/描边/阴影 ——
## 用户举的是「背包、商店上方的白色字体」⇒ 商店那扇（键 `NPC商店`、标题烘的是「交易」）
## 也在名单里；此前这条腿只量窗口坐标，字体侧一次没量过。
## 黑描边**是指望有的**：`MWindow.drawWindowLayout():195` 给 titleTextField 挂
## `BaseUtil.getGlowFilter()` = `GlowFilter(0x000000, 1, 2, 2, 10, 1)`（strength 10 把辉光压成
## 贴边实心黑）⇒ 我们的 `outline_size = 2` 是对等实现，不是多余的糊，不许"为了清晰"删掉。
func _K_标题白字实测(管理: Node) -> void:
	if 管理 == null:
		return
	for 页 in ["背包", "人物", "NPC商店"]:
		if _尺寸(页).is_empty():
			_记(false, "尺寸表里没有 %s，标题字体腿跳过" % 页)
			continue
		var 窗: Node = 管理.call("取或建窗口", 页)
		if 窗 == null:
			_记(false, "%s 窗建不出来，标题字体腿跳过" % 页)
			continue
		窗.call("_apply_original_window", 页)
		var 标题 := 窗.get("_title") as Label
		if 标题 == null:
			_记(false, "%s 窗里没有 `_title`" % 页)
			continue
		var 号 := 标题.get_theme_font_size("font_size")
		var 字体 := 标题.get_theme_font("font")
		var 路 := 皮肤表.字体落点(字体) if 字体 != null else "（没取到字体）"
		_记(号 == 字号真值, "%s 标题实际渲染字号 = %d（要 %d；点阵只烘在 %s 这几档）" % [
			页, 号, 字号真值, str(点阵字号真值表)])
		_记(字体 != null and 路.contains("simsun_原版"),
			"%s 标题取到的字体 = %s（点阵在这份里，不在系统 simsun.ttc 里）" % [页, 路])
		_记(标题.get_theme_constant("outline_size") == 皮肤表.文字规则_描边数值,
			"%s 标题黑描边 = %d = 皮肤表规则值（原版那层 GlowFilter 的对等实现）" % [
				页, 标题.get_theme_constant("outline_size")])
		_记(标题.get_theme_color("font_shadow_color").a == 0.0,
			"%s 标题阴影 alpha = 0（原版只有黑辉光、没有投影）" % 页)
	_动态标题落点(管理)


## 用户举的例子是带计数的「背包(28/150)」，而 `_apply_original_window` 只烘死「背包」。
## 计数串是运行期 `背包窗口.gd:74 → 设置标题()` 换上去的，换那一下 `_layout_title` 会**重新居中**
## ⇒ 要钉的是"换完之后"还在整像素上，不是开窗那一下。
func _动态标题落点(管理: Node) -> void:
	var 窗: Node = 管理.call("取或建窗口", "背包")
	if 窗 == null:
		_记(false, "动态标题腿缺背包窗")
		return
	窗.call("设置标题", "背包(28/150)")
	var 标题 := 窗.get("_title") as Label
	if 标题 == null:
		_记(false, "动态标题腿缺 `_title`")
		return
	_记(标题.text == "背包(28/150)", "标题已换成用户举的那串（实得「%s」）" % 标题.text)
	var 位 := 标题.get_global_position()
	_记(_整(位.x) and _整(位.y),
		"换完计数串重新居中后仍踩整像素（实得 %s, %s；`_layout_title` 走 `int(宽 − 文字宽) >> 1`）" % [
			str(位.x), str(位.y)])
	var 号 := 标题.get_theme_font_size("font_size")
	_记(号 == 字号真值, "计数串那截也是 %dpx（数字在这份字体里没有任何 strike ⇒ 只能靠字号不再往下掉）" % 号)
	窗.call("_apply_original_window", "背包")


func _尾() -> void:
	var 腿判数 := 判
	_记(腿判数 == 判数真值,
		"各腿判数 = %d（实得 %d；少的那几条是被运行时错误掐断的腿，去上面找 SCRIPT ERROR）" % [判数真值, 腿判数])
	print("字体清晰回归测试 —— 判 %d 条，红 %d 条" % [判, 红.size()])
	for 行 in 日志:
		print(行)
	for 行 in 红:
		push_error(行)
	quit(1 if not 红.is_empty() else 0)

