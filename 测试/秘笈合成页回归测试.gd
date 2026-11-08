extends SceneTree
## 秘笈合成页（原版 `JiNengCompositeWindow` 340×381，一枚页签）的**离线**几何门。
##
## 为什么要有这条：`开发工具/截秘笈合成页.gd` 是有头量具（要拍图、要走真实开窗路径），
## 进不了离线门 ⇒ 「场景被编辑器旧缓冲顶掉 / 换回 7 月那版 30 节点薄壳 / 控制器指回旧节点名 /
## 下拉被换回 OptionButton」这类回退以前只能靠人眼发现。2026-10-03 这一轮就是这种回退：
## 磁盘上那份 `.tscn` 是 7 月手摆版（`材料/主残卷·辅残卷一·辅残卷二·幸运符` 一套旧名、
## 说明是 `Label` + 运行期被 `_configure_label(…, 10, …)` 改字号、没有分隔线、
## 内容框皮是 `浅色面板.png`、勾选框文案自造成"使用幸运符"、下拉是 `OptionButton`）。
##
## 期望值**不另立一份**：直接读有头量具 `截秘笈合成页.gd` 的 const 表
## （`件路径 / 件期望 / 页面件 / 页面文案 / 原文 / 文案色 / 页签真值 / 下拉皮 / 材料格文案 / 内 / 勾选框内缩`）
## ⇒ 真值只有一处；量具改了这里跟着改，改不到一起就报红。
##
## ⚠ 本门**只 load 场景、不点任何原生钮** ⇒ 不会落 `user://玩家数据.json`
## （口径见记忆「离线门不许写存档」）。
##
## 跑法：Godot --path . --headless --script res://测试/秘笈合成页回归测试.gd

const 容差 := 0.02
## ⚠ 容差取 0.02 不是 1.0：烘的是设计期整数/半整数偏移，放 1px 等于"差一个像素过得去"——
## 宝石工艺页的变异测试实测：把 开始合成 下移 1px，容差 1.0 的门**不红**。
const 量具路 := "res://开发工具/截秘笈合成页.gd"
const 场景路 := "res://场景/界面/窗口/秘籍合成/秘籍合成窗口.tscn"
const 控制器路 := "res://脚本/界面/窗口/秘笈合成窗口.gd"
const 宿主路 := "res://脚本/界面/功能窗口.gd"
const 尺寸表路径 := "res://数据/界面/窗口尺寸.json"
const 节点数 := 31
const 资源数 := 25		# load_steps = 1 + 12 张图 + 11 个样式盒 + 1 个脚本（2026-10-03 主残卷格升级为拖放落点）

## 面板类皮：`MYellow_background`(10) ⇒ 内容面板.png；`MPane_background`(97) ⇒ 子面板.png
## （`JiNengCompositeWindow.as:193` 内容盒、`:234` `_resultBox.setSkin`、`ItemDropBox` 自己的皮）。
const 面板皮 := {
	"内容框": "内容面板.png",
	"放入残卷区": "子面板.png",
	"结果区": "子面板.png",
	"方向箭头": "方向箭头.png",
}
const 贴图皮 := {
	"说明分隔线": "横向分隔线.png",
	"主残卷格": "物品格.png",
	"秘籍格": "物品格.png",
	"材料格物品格": "物品格.png",
	"材料格2/物品格": "物品格.png",
	"材料格3/物品格": "物品格.png",
	"材料格4/物品格": "物品格.png",
}
## 页签四档皮：normal=未选、hover=未选 +30（预烘，**不是** modulate）、
## pressed / hover_pressed = 选中真皮（原版 `selectedUpSkin`，符号名坑：叫 `MTabButton_disabled`）。
const 页签皮 := {
	"normal": "分页按钮未选.png",
	"hover": "分页按钮未选_悬停.png",
	"pressed": "分页按钮选中.png",
	"hover_pressed": "分页按钮选中.png",
}
## 7 月薄壳的东西：出现任何一个都说明场景被顶回去了。
## ⚠ 判"旧节点名"要带 `name="…"`：`主残卷` 三个字同时也是正文（「辅残卷需要和主残卷同类型」）
##   和新节点名 `主残卷格` 的子串，光判字面会自己假红（本轮就这么红过一次）。
const 旧名 := ['name="辅残卷一"', 'name="辅残卷二"', 'name="主残卷"', "浅色面板",
		"OptionButton", 'name="材料"']

var _错 := 0
var _判数 := 0


func _initialize() -> void:
	var 表 := _常量()
	var 路径: Dictionary = 表.get("件路径", {}) as Dictionary
	var 期望: Dictionary = 表.get("件期望", {}) as Dictionary
	var 页面件: Dictionary = 表.get("页面件", {}) as Dictionary
	if 路径.is_empty() or 期望.is_empty() or 页面件.is_empty():
		_报("%s 里没有 件路径/件期望/页面件 三张 const 表" % 量具路)
		quit(1)
		return
	if not ResourceLoader.exists(场景路):
		_报("场景缺失 %s" % 场景路)
		quit(1)
		return
	_量场景文本(FileAccess.get_file_as_string(场景路))
	_量尺寸表()
	var 根 := (load(场景路) as PackedScene).instantiate() as Control
	root.add_child(根)
	_判(absf(根.size.x - 340.0) <= 容差 and absf(根.size.y - 352.0) <= 容差,
			"页面根 340×352（= 窗 381 − MWindow 顶部 29 拖动区）", "实际 %s" % 根.size)
	_量逐件(根, 路径, 期望, 页面件)
	_量页签(根, 表.get("页签真值", {}) as Dictionary,
			表.get("页签文字色", Color(0.988235, 0.956863, 0.611765, 1)) as Color)
	_量皮(根, 路径)
	_量文案(根, 路径, 表)
	_量下拉(根, 路径)
	_量控制器()
	print("秘笈合成离线门：断言 %d 条，红 %d 个" % [_判数, _错])
	quit(1 if _错 > 0 else 0)


func _常量() -> Dictionary:
	var 脚本 := load(量具路) as GDScript
	if 脚本 == null:
		_报("载不出量具脚本 %s" % 量具路)
		return {}
	return 脚本.get_script_constant_map()


## 先按**文本**钉树形：`load()` 会把坏场景静默修好一部分，光看运行期树发现不了层序/命名回退。
func _量场景文本(场: String) -> void:
	_判(场.count('[node name=') == 节点数, "场景 %d 个节点（整窗烘死，编辑器场景树可见）" % 节点数,
			"实际 %d ⇒ 八成被 7 月那版薄壳顶回去了" % 场.count('[node name='))
	_判(场.contains('load_steps=%d' % 资源数),
			"load_steps = %d（1 + 12 张图 + 11 个样式盒 + 1 个脚本；算错 Godot 直接崩）" % 资源数,
			"头行 %s" % 场.substr(0, 场.find("\n")))
	# 直接子节点必须写 `parent="."`：写成 `parent=""` 会让 Godot 解析期递归、栈溢出 SIGSEGV
	_判(not 场.contains('parent=""'), '直接子节点写 parent="."（`parent=""` 实测 SIGSEGV）',
			'文件里有 parent=""')
	for 名 in 旧名:
		_判(not 场.contains(名), "场景不再出现 7 月薄壳的东西：%s" % 名, "还在文件里")
	# 文字一律烘的是**秘笈**（语言表 `EQUIP_UPGRADE_*` 用「笈」；7 月版全文写成「秘籍」）
	_判(场.contains('text = "秘笈合成"'), "页签文案 = 秘笈合成（EQUIP_UPGRADE_TAB_NAMES_1）",
			"文件里没有这行 ⇒ 用字又退回「秘籍」了")
	_判(场.contains('text = "本次操作使用"'), "勾选框文案 = 本次操作使用（EQUIP_STRENGTH_DESC_TEMPLATE_2）",
			"缺 ⇒ 被改回自造的「使用幸运符」")
	_判(not 场.contains('scroll_active = true'), "没有 RichTextLabel 开滚动条", "有 true")


## `窗口尺寸.json` 的「技能书」那一条 —— 整窗尺寸与页面原点由宿主读它，量具的 −29 口径靠它成立。
func _量尺寸表() -> void:
	var 包 := _读表(尺寸表路径)
	var 条: Dictionary = 包.get("技能书", {}) as Dictionary
	_判(int(条.get("宽", 0)) == 340 and int(条.get("高", 0)) == 381,
			"窗口尺寸「技能书」= 340×381（`JiNengCompositeWindow.as:79` super(340,381)）",
			"实际 %s×%s" % [str(条.get("宽")), str(条.get("高"))])
	_判(bool(条.get("整框", false)),
			"「技能书」整框=true ⇒ 页面根原点 (0,29)、场景 y = AS3 y − 29", "缺或为 false")
	_判(not bool(条.get("内容底", true)),
			"「技能书」内容底=false ⇒ 宿主不再垫第二块 MPane（页里已烘同一块 MYellow）", "还是 true")
	_判(String(条.get("标题", "")) == "秘笈合成",
			"「技能书」标题 = 秘笈合成（EQUIP_UPGRADE_WINDOW_TITLE `:3110`）",
			"实际 %s ⇒ 窗口标题栏用字退回「秘籍」" % String(条.get("标题")))


## 逐件矩形：件名来自 `页面件`（+ 外壳两件），期望来自 `件期望`。
## `CheckBox` 不再单档：10-25 主题补上 `CheckBox/hover_pressed` 空盒后，控件矩形 == 皮肤矩形
## （当年"上下各多 4"不是 Godot 的固定外扩，是那 27 地板：主题缺槽 ⇒ 兜底盒四边各 4 的边距，
##   注释里的 `CHECK_BOX_EXTEND_SIZE` 工程里从来没这个常量）。
func _量逐件(根: Control, 路径: Dictionary, 期望: Dictionary, 页面件: Dictionary) -> void:
	var 原点 := 根.get_global_position()
	var 名单 := ["内容框", "开始合成"]
	for 页 in 页面件:
		名单.append_array(页面件[页] as Array)
	for 件名 in 名单:
		var 想v = 期望.get(件名, null)
		var 路v = 路径.get(件名, null)
		if not (想v is Array) or not (路v is String):
			continue
		var 件 := 根.get_node_or_null(String(路v)) as Control
		if 件 == null:
			_报("「%s」取不到（%s）" % [件名, String(路v)])
			continue
		var 想: Array = 想v as Array
		var 实 := 件.get_global_rect()
		var 偏 := (Vector2(实.position.x - 原点.x, 实.position.y - 原点.y)
				- Vector2(float(想[0]), float(想[1]))).length()
		_判(偏 <= 容差 and absf(实.size.x - float(想[2])) <= 容差
				and absf(实.size.y - float(想[3])) <= 容差,
				"「%s」矩形 = 量具 件期望（页面局部，AS3 现算）" % 件名,
				"烘的 %s 想 [%s, %s, %s, %s] 位偏 %.2f" % [实, str(想[0]), str(想[1]),
						str(想[2]), str(想[3]), 偏])
	# 四格材料排的"标签 + 物品格"是派生件（`ItemCaiLiaoBox`：标签 56×20 在顶、格在 ((56−40)/2,20)）
	for i in range(1, 5):
		var 格: Array = 期望["材料格%d" % i] as Array
		var 标 := 根.get_node_or_null("内容框/材料格%d/标签" % i) as Control
		var 子 := 根.get_node_or_null("内容框/材料格%d/物品格" % i) as Control
		_判(标 != null and 子 != null, "材料格%d 有 标签 + 物品格 两份子件" % i, "取不到")
		if 标 != null:
			_判(标.global_position.x - 原点.x - float(格[0]) <= 容差
					and absf(标.size.x - 56.0) <= 容差 and absf(标.size.y - 20.0) <= 容差,
					"材料格%d/标签 = 格顶 56×20（MLabel adjustContent=false ⇒ 高恒 20）" % i,
					"实际 %s %s" % [标.global_position - 原点, 标.size])
		if 子 != null:
			var 期 := Vector2(float(格[0]) + 8.0, float(格[1]) + 20.0)
			var 得 := 子.global_position - 原点
			_判(absf(得.x - 期.x) <= 容差 and absf(得.y - 期.y) <= 容差,
					"材料格%d/物品格 = 格内 (8,20)（(56−40)/2）" % i, "实际 %s 应 %s" % [得, 期])
	_判(根.get_node_or_null("内容框/材料格4/购买") is Button,
			"只有第 4 格有「购买」（`ItemCaiLiaoBox(true)` `:220`）", "取不到")
	_判(根.get_node_or_null("内容框/材料格1/购买") == null,
			"第 1..3 格**没有**购买钮（反向哨兵：别给四格都补上）", "多出来了")


## 唯一那枚页签：文案与宽钉 `页签真值`（基类的"页签宽按文字"是拿现场文字反算的 ⇒ 文字写错它跟着错），
## 四档皮按文件名钉死，五档字色全 = #fcf49c（`MTabButton.as:12` 四态同色）。
func _量页签(根: Control, 页签真值: Dictionary, 字色: Color) -> void:
	var 条 := 根.get_node_or_null("分页") as Control
	if 条 == null:
		_报("缺 分页 容器")
		return
	_判(条.get_child_count() == 1, "页签只有 1 枚（`EQUIP_UPGRADE_TAB_NAMES` 长度 1）",
			"实际 %d" % 条.get_child_count())
	var 钮 := 条.get_child(0) as Button
	if 钮 == null:
		_报("页签 0 不是 Button")
		return
	var 项v = 页签真值.get("页签0", null)
	if not (项v is Array):
		_报("量具 页签真值 里没有 页签0")
		return
	var 项: Array = 项v as Array
	_判(钮.text == String(项[0]), "页签文案 = %s" % String(项[0]), "烘的是 %s" % 钮.text)
	_判(absf(钮.size.x - float(项[1])) <= 容差, "页签宽 = %s（文字宽 + 6，`MButton3.as:383`）" % str(项[1]),
			"实际 %.1f" % 钮.size.x)
	_判(bool(钮.button_pressed), "页签烘 button_pressed=true（`:275` selectedIndex=0 常亮）", "没选中")
	for 槽 in 页签皮:
		var 皮 := _皮(钮, StringName(槽))
		_判(皮 == String(页签皮[槽]), "页签 %s 皮 = %s" % [槽, String(页签皮[槽])],
				"实际 %s ⇒ 被换回 modulate 染色或旧皮了" % 皮)
	for 键 in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		var 色 := 钮.get_theme_color(StringName(键))
		_判(色 == 字色, "页签的 %s = #fcf49c（`MTabButton.as:12` 四态同色）" % 键,
				"实际 %s" % 色.to_html(false))


## 皮来源逐件钉。这条防的是"顺手换成浅色面板/自绘样式"—— 7 月薄版的内容框就是 `浅色面板.png`。
func _量皮(根: Control, 路径: Dictionary) -> void:
	for 件名 in 面板皮:
		var 件 := 根.get_node_or_null(String(路径.get(件名, ""))) as Control
		if 件 == null:
			_报("皮核对缺件：%s" % 件名)
			continue
		var 皮 := _皮(件, &"panel")
		_判(皮 == String(面板皮[件名]), "%s 皮 = %s" % [件名, String(面板皮[件名])], "实际 %s" % 皮)
	for 件名 in 贴图皮:
		var 路 := String(路径.get(件名, ""))
		if 路 == "":
			路 = "内容框/" + 件名 if 件名.contains("/") else "内容框/材料格1/" + 件名.rsplit("/", 1)[-1]
		var 件 := 根.get_node_or_null(路)
		# 2026-10-03 接 1352：主残卷格从 TextureRect 升级为**拖放落点 Button**
		# （`残卷放入格.gd`，皮从 .texture 挪到 .icon —— 其余格仍是 TextureRect，两种都认）。
		var 图: Texture2D = null
		if 件 is TextureRect:
			图 = (件 as TextureRect).texture
		elif 件 is Button:
			图 = (件 as Button).icon
		else:
			_报("皮核对缺件：%s（%s，不是 TextureRect/Button？）" % [件名, 路])
			continue
		_判(图 != null and 图.resource_path.get_file() == String(贴图皮[件名]),
				"%s 贴图 = %s" % [件名, String(贴图皮[件名])],
				"实际 %s" % ("null" if 图 == null else 图.resource_path.get_file()))
	# 原版 TextArea2 是 dynamic TextField ⇒ 不出滚动条；开着会长出原版没有的滚动条
	for 件 in 根.find_children("*", "RichTextLabel", true, false):
		_判(not (件 as RichTextLabel).scroll_active,
				"%s scroll_active=false" % (件 as Node).name, "还开着")


## 文案逐字（`原文` 现译）+ 无 BBCode 件的字色。`结果` 走空态（占位符 `￥`/`$` 替 0）。
func _量文案(根: Control, 路径: Dictionary, 表: Dictionary) -> void:
	var 页面文案: Dictionary = 表.get("页面文案", {}) as Dictionary
	var 原文: Dictionary = 表.get("原文", {}) as Dictionary
	var 文案色: Dictionary = 表.get("文案色", {}) as Dictionary
	var 材料格文案: Array = 表.get("材料格文案", []) as Array
	_判(材料格文案.size() == 4, "量具 材料格文案 有 4 项", "实际 %d" % 材料格文案.size())
	for i in 材料格文案.size():
		var 标 := 根.get_node_or_null("内容框/材料格%d/标签" % (i + 1)) as Label
		_判(标 != null and 标.text == String(材料格文案[i]),
				"材料格%d 标签 = %s" % [i + 1, String(材料格文案[i])],
				"实际 %s" % ("<无>" if 标 == null else 标.text))
	for 页 in 页面文案:
		for 件名v in (页面文案[页] as Array):
			var 件名 := String(件名v)
			var 件 := 根.get_node_or_null(String(路径.get(件名, "")))
			if 件 == null:
				_报("文案核对取不到 %s" % 件名)
				continue
			var 原文串 := String(原文.get(件名, ""))
			if 件名 == "结果":
				原文串 = 原文串.replace("￥", "0").replace("$", "0")
			_判(原文串 != "", "%s 在量具 原文 里有登记" % 件名, "空 ⇒ 表没写")
			if 件 is RichTextLabel:
				_判((件 as RichTextLabel).text == _译(原文串),
						"%s 逐字 = 语言表原文译成的 BBCode" % 件名,
						"烘的 %s ≠ 应译 %s" % [(件 as RichTextLabel).text, _译(原文串)])
			elif 件 is Label:
				_判((件 as Label).text == _纯(原文串), "%s 逐字 = 语言表原文（去色）" % 件名,
						"烘的 %s ≠ %s" % [(件 as Label).text, _纯(原文串)])
			elif 件 is Button:
				_判((件 as Button).text == _纯(原文串), "%s 逐字 = 语言表原文（Button 族）" % 件名,
						"烘的 %s ≠ %s" % [(件 as Button).text, _纯(原文串)])
			else:
				_报("%s 既不是 RichTextLabel / Label 也不是 Button" % 件名)
				continue
			if 文案色.has(件名) and (件 is Label or 件 is Button):
				var 想: Color = 文案色[件名]
				var 色: Color = (件 as Control).get_theme_color(&"font_color")
				_判(色 == 想, "%s 字色 = %s（AS3 UI_ORANGE / textColor）" % [件名, 想.to_html(false)],
						"实际 %s" % 色.to_html(false))


## 结果区那一排：勾选框是 `CheckBox`、下拉是 **MenuButton**（`OptionButton` 有 64px 最小宽地板，
## 45 宽压不下去会盖住「个幸运符」）、初值 `disabled=true`（`:248`）、四态真皮 + `flat=false`
## （`MenuButton` 默认 flat ⇒ `Button::draw` 整块背景不画，接了皮也看不见）。
func _量下拉(根: Control, 路径: Dictionary) -> void:
	var 勾 := 根.get_node_or_null(String(路径.get("使用幸运符", "")))
	_判(勾 is CheckBox, "使用幸运符 是 CheckBox（原版 MCheckBoxF）",
			"实际 %s" % ("<无>" if 勾 == null else 勾.get_class()))
	_判(勾 != null and not (勾 as CheckBox).button_pressed,
			"勾选初值 false（`userCfg.canJuan.useXingYunFu` 默认 false）", "烘成勾上了")
	var 下拉 := 根.get_node_or_null(String(路径.get("幸运符数量", "")))
	_判(下拉 is MenuButton, "幸运符数量 是 MenuButton（OptionButton 64px 地板会压住「个幸运符」）",
			"实际 %s" % ("<无>" if 下拉 == null else 下拉.get_class()))
	if not (下拉 is MenuButton):
		return
	var 钮 := 下拉 as MenuButton
	_判(钮.disabled, "下拉烘 disabled=true（`:248` enabled=false）", "实际 %s" % str(钮.disabled))
	_判(钮.text == "1", "下拉显示第 1 项", "实际 %s" % 钮.text)
	var 表 := _常量()
	var 下拉皮: Dictionary = 表.get("下拉皮", {}) as Dictionary
	_判(下拉皮.size() == 4, "量具 下拉皮 表有四态", "实际 %d" % 下拉皮.size())
	for 槽 in 下拉皮:
		var 皮 := _皮(钮, StringName(槽))
		_判(皮 == String(下拉皮[槽]), "下拉 %s 皮 = %s（fl ComboBox_*Skin）"
				% [槽, String(下拉皮[槽])], "实际 %s ⇒ 没接上，走的是 Godot 默认主题" % 皮)
	_判(not 钮.flat, "下拉 flat=false（否则 MenuButton 根本不画背景）", "烘的是 flat=true")
	_判(钮.alignment == HORIZONTAL_ALIGNMENT_LEFT,
			"下拉文字左对齐（`MComboBox.as:22` 的 TextFormatAlign.LEFT）", "实际 %s" % 钮.alignment)
	var 白 := Color(1, 1, 1, 1)
	_判(钮.get_theme_color(&"font_color") == 白 and 钮.get_theme_color(&"font_disabled_color") == 白,
			"下拉字色白（含禁用态：fl 是 setTextFormat 硬灌，不换灰）",
			"常=%s 禁用=%s" % [钮.get_theme_color(&"font_color").to_html(false),
					钮.get_theme_color(&"font_disabled_color").to_html(false)])


func _量控制器() -> void:
	var 源 := FileAccess.get_file_as_string(控制器路)
	if 源.is_empty():
		_报("读不到控制器 %s" % 控制器路)
		return
	for 串 in ["秘笈合成场景", "内容框/放入残卷区/放入残卷", "内容框/材料格4/购买",
			"内容框/结果区/使用幸运符", "内容框/结果区/幸运符数量", "开始合成",
			# 2026-10-11 §3.107：反馈从"直写 `_宿主._status.text`"（那标签可见性关着 ⇒
			# 玩家看不见）改成走 `_宿主._show_hint(...)`（= 写文案即显形那条口子）。
			"_宿主._show_hint("]:
		_判(源.contains(串), "控制器在走真值路径：%s" % 串, "源码里找不到")
	_判(源.contains("for n in 9"), "下拉喂 1..9（`getLianXuArrByNum(9)` `:247`，宝石工艺是 20）",
			"没找到 9 这一档")
	# **不许出现自造协议**（2026-10-03 接 `1352` 后升级：提交走 `游戏会话.合成秘笈` 的封装，
	# 页面依旧不直接 `send_game_request`、不碰底层 socket 文本）。
	_判(not 源.contains("request_stone") and not 源.contains("request_merge") and not 源.contains(".send("),
			"控制器没自造协议（提交走会话封装，放入只给回执）", "出现了未授权的发包")
	# 2026-10-11：「购买」不再是桩 —— 原版共用材料格 `ItemCaiLiaoBox.buyHandler:45-53` 发
	# `REQUEST_CASH_ITEM_INFO`，走 `功能窗口.请求商城商品` 统一出口（§3.125 那条链）。
	# 行为面由 `勾玉炼制页回归测试` / `装备打造放入回归测试` 用**假后端钉真发包**，
	# 这里只钉"这一页也没退回成桩"。
	_判(源.contains("请求商城商品"), "材料格4「购买」走统一出口 `请求商城商品`",
			"源码里找不到（又退回成只回显的桩了？）")
	_判(源.contains("合成秘笈") and 源.contains("can_juan_result"),
			"控制器在走真协议：`会话.合成秘笈` + 结果帧 `can_juan_result`", "还是纯回执版")
	_判(源.contains("请求放入.connect"), "放入残卷格 = 真拖放落点（信号挂上）", "落点没人收")
	# 已切件：功能窗口.gd 不再 preload 本场景、不再运行期刷样式（编辑器=运行期）
	var 宿主 := FileAccess.get_file_as_string(宿主路)
	_判(not 宿主.contains("秘籍合成页面场景"),
			"功能窗口 不再 preload 本场景（交包只带这一份控制器 + 一张场景）", "还留着 const")
	for 旧 in ["_show_skill_book_hint", 'page.get_node("分页/秘籍合成")',
			'内容框/材料/主残卷/物品格']:
		_判(not 宿主.contains(旧), "功能窗口 不再指 7 月薄壳的接线：%s" % 旧, "还在源码里")
	_判(宿主.contains('const 秘笈合成窗口 := preload("res://脚本/界面/窗口/秘笈合成窗口.gd")')
			and 宿主.contains("秘笈合成窗口.渲染(self)"),
			"功能窗口 走 秘笈合成窗口.渲染(self)", "没接上")


func _皮(件: Control, 槽: StringName) -> String:
	var 题 := 件.get_theme_stylebox(槽)
	if 题 is StyleBoxTexture:
		var 图: Texture2D = (题 as StyleBoxTexture).texture
		return 图.resource_path.get_file() if 图 != null else ""
	return ""


## 量具 `译文为BBCode` / `纯文本` 的等价实现（三边同源：语言表原文 → 场景 → 门）。
func _译(原文: String) -> String:
	var 文 := 原文.replace("\r\n", "\n").replace("\r", "\n")
	文 = 文.replace("<br/>", "\n").replace("<br>", "\n")
	文 = 文.replace("<font color='", "[color=").replace('<font color="', "[color=")
	文 = 文.replace("'>", "]").replace('">', "]")
	文 = 文.replace("</font>", "[/color]")
	return 文


func _纯(原文: String) -> String:
	var 文 := _译(原文)
	for 串 in ["[color=#ffffff]", "[color=#00ff00]", "[color=#ff9100]", "[color=#ff9900]",
			  "[color=#0081ff]", "[color=#ff0000]", "[/color]"]:
		文 = 文.replace(串, "")
	return 文


func _读表(路径: String) -> Dictionary:
	var 文本 := FileAccess.get_file_as_string(路径)
	var 出 = JSON.parse_string(文本)
	return 出 if 出 is Dictionary else {}


func _报(文本: String) -> void:
	_错 += 1
	print("!! " + 文本)


func _判(对: bool, 标题: String, 详情 := "") -> void:
	_判数 += 1
	if not 对:
		_报("%s —— %s" % [标题, 详情])
