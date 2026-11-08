extends SceneTree
## 首领页（原版 `WangBossWindow` 573×324 + `WangBossCell`）的**离线**几何门。
##
## 为什么要有这条：`开发工具/截首领页.gd` 是有头量具（要拍图、要真鼠标翻页），
## 进不了离线门 ⇒ "场景被编辑器旧缓冲盖掉 / 被换回 7 月那版薄壳 / 控制器指回旧节点名"
## 这类回退以前只能靠人眼发现 —— 2026-10-03 这一轮就是这种回退：
## 磁盘上的 `首领窗口.tscn` 是 12 节点的薄壳（`外框 + 首领卡片 + 首领_0..2`），
## 而量具/生成器/像素门早就换成 80 节点的真值版 ⇒ 三处对不上、门整条红。
##
## 期望值**不另立一份**：直接读有头量具的 `件路径 / 件期望 / 件文案 / 首页索引 / 每页条数 / 星位`
## 六张 const 表（`GDScript.get_script_constant_map()`）⇒ 真值只有一处。
##
## 跑法：Godot --path . --headless --script res://测试/首领页回归测试.gd

const 容差 := 1.0
const 量具路 := "res://开发工具/截首领页.gd"
const 场景路 := "res://场景/界面/窗口/首领/首领窗口.tscn"
const 控制器路 := "res://脚本/界面/窗口/首领窗口.gd"	# 2026-10-03 从 活动窗口.gd 切出来单独成件
const 尺寸表路径 := "res://数据/界面/窗口尺寸.json"
const 文案路径 := "res://数据/界面/首领_文案.json"
const 薄壳组件 := "res://场景/界面/组件/首领卡片.tscn"

## AS3 出处：`WangBossWindow:82-85` background 573×324；`:90-95` background2 561×260 @(6,39)；
## `:96-107` 三张卡 183×250 @(11/195/379, 44)；`:61-64` 翻页条 124×20 @(224,299)。
const 窗宽 := 573.0
const 窗高 := 324.0
const 卡位 := [[11.0, 15.0], [195.0, 15.0], [379.0, 15.0]]		# 场景 y = 窗 y − 29
const 禁用钮 := ["首页", "上一页"]
const 可点钮 := ["下一页", "末页"]
## 语言表九键（`出首领原文数据.py` 落盘；`真值/窗口/首领.md` §3 逐条带行号）
const 文案键 := ["WANG_BOSS_TITLE", "WANG_BOSS_CELL_LEVEL", "WANG_BOSS_REFURBISH_MAP",
		"WANG_BOSS_REFURBISH_TIMER", "WANG_BOSS_INSTRUCTION", "WANG_BOSS_CELL_JI",
		"WANG_BOSS_NOT_DIED", "WANG_BOSS_KILL", "WANG_BOSS_TIP"]
## 空态要清的**十个**文本（`Cell.removeData:247-258`，连四枚固定标签一起清）
const 卡内十文本 := ["序号", "名称", "类型", "等级数值", "地图数值", "时间数值",
		"等级标签", "地图标签", "时间标签", "爆率标签"]

var _错 := 0
var _件数 := 0


func _initialize() -> void:
	var 表 := _常量()
	var 件路径: Dictionary = 表.get("件路径", {}) as Dictionary
	var 件期望: Dictionary = 表.get("件期望", {}) as Dictionary
	var 件文案: Dictionary = 表.get("件文案", {}) as Dictionary
	if 件路径.is_empty() or 件期望.is_empty():
		_报("%s 里没有 件路径/件期望 两张 const 表" % 量具路)
		quit(1)
		return
	var 首页索引: Array = 表.get("首页索引", []) as Array
	var 星位: int = int(表.get("星位", 7))
	_量尺寸表()
	var 根 := _量逐件(件路径, 件期望)
	if 根 != null:
		_量钮禁用三件套(根)
		_量卡内(根, 件路径, 件文案, 首页索引, 星位)
	_量数据不变量(表, 首页索引)
	_量控制器接线()
	if _错 > 0:
		print("!! 首领页离线门失败 %d 项" % _错)
		quit(1)
		return
	print("首领页离线门：%d 件逐矩形 + 翻页钮三件套 + 三张卡数据/星位 + 尺寸表 + 文案九键 + 接线 全部对上" % _件数)
	quit(0)


func _报(文本: String) -> void:
	_错 += 1
	print("!! " + 文本)


func _判(对: bool, 标题: String, 详情 := "") -> void:
	if not 对:
		_报("%s —— %s" % [标题, 详情])


func _常量() -> Dictionary:
	var 脚本 := load(量具路) as GDScript
	if 脚本 == null:
		_报("载不出量具脚本 %s" % 量具路)
		return {}
	return 脚本.get_script_constant_map()


func _读表(路径: String) -> Dictionary:
	var 文本 := FileAccess.get_file_as_string(路径)
	var 出 = JSON.parse_string(文本)
	return 出 if 出 is Dictionary else {}


func _量尺寸表() -> void:
	var 规格: Dictionary = _读表(尺寸表路径).get("首领", {}) as Dictionary
	if 规格.is_empty():
		_报("窗口尺寸.json 缺「首领」条目")
		return
	_判(absf(float(规格.get("宽", -1.0)) - 窗宽) < 0.01
			and absf(float(规格.get("高", -1.0)) - 窗高) < 0.01,
			"「首领」尺寸表 573×324 = WangBossWindow:82-85 的 background",
			"实际 %s×%s" % [str(规格.get("宽")), str(规格.get("高"))])
	_判(bool(规格.get("整框", false)),
			"「首领」标了 `整框`（⇒ 容器原点 (0,29)、场景 y = 窗 y − 29）",
			"没标整框 ⇒ 整页会右下各偏 8/38px")
	_判(String(规格.get("标题", "")) == "BOSS刷新信息",
			"标题 = WANG_BOSS_TITLE 原文", "实际 %s" % String(规格.get("标题")))


func _量逐件(件路径: Dictionary, 件期望: Dictionary) -> Control:
	if not ResourceLoader.exists(场景路):
		_报("场景缺失 %s" % 场景路)
		return null
	var 根 := (load(场景路) as PackedScene).instantiate() as Control
	root.add_child(根)
	_判(absf(float(根.size.y) - (窗高 - 29.0)) <= 容差,
			"页面根高 = 窗高 324 − 拖动区 29 = 295",
			"实际 size=%s" % 根.size)
	var 原点 := 根.get_global_position()
	var 坏名 := ""
	for 件名 in 件路径:
		var 想v = 件期望.get(件名, null)
		if not (想v is Array):
			continue
		var 件 := 根.get_node_or_null(String(件路径[件名])) as Control
		if 件 == null:
			坏名 += " %s" % 件名
			continue
		var 想: Array = 想v as Array
		var 实 := 件.get_global_rect()
		var 偏 := (Vector2(实.position.x - 原点.x, 实.position.y - 原点.y)
				- Vector2(float(想[0]), float(想[1]))).length()
		_件数 += 1
		_判(偏 <= 容差 and absf(实.size.x - float(想[2])) <= 容差
				and absf(实.size.y - float(想[3])) <= 容差,
				"「%s」矩形 = 量具 件期望（页面局部，AS3 现算）" % 件名,
				"烘的 %s 想 [%s, %s, %s, %s] 位偏 %.2f" % [实, str(想[0]), str(想[1]),
						str(想[2]), str(想[3]), 偏])
	_判(坏名 == "", "量具点名的件全在场景里", "取不到：" + 坏名)
	return 根


## 第 1 页的禁用档（`PageComponent.setBtnEnabled:102-120` + `MButton3` 的 `getGrayFilter`）：
## `disabled = true` + `texture_disabled` = **烘好的灰皮** + **不挂 material** + 手型光标。
## 三条各有理由：不 disabled ⇒ 状态错；指回同一张皮 ⇒ Godot 乘主题 `IconDisabledModulate`
## (0.55, α0.85) 比原版暗一截；挂 material ⇒ 会被子节点继承、且不是工程既有那条路
## （skill `flash-mbutton3-state-skins` 两条「不许用」）。
const 四钮 := ["首页", "上一页", "下一页", "末页"]


func _量钮禁用三件套(根: Control) -> void:
	for 名 in 四钮:
		var 钮 := 根.get_node_or_null("分页/" + 名) as TextureButton
		_判(钮 != null, "分页钮「%s」在场景里" % 名, "取不到")
		if 钮 == null:
			continue
		_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
				"「%s」手型光标（`MButton3.init:135` buttonMode/useHandCursor）" % 名,
				"cursor=%d" % 钮.mouse_default_cursor_shape)
		_判(钮.material == null, "「%s」不挂 material（三档一律换皮）" % 名, "挂了材质")
		var 灰路 := "res://素材/界面/专用控件/分页%s_灰.png" % 名
		_判(ResourceLoader.exists(灰路), "「%s」的灰皮在盘上（缺了就静默不灰）" % 名, 灰路)
		_判(钮.texture_disabled != null
				and 钮.texture_disabled.resource_path == 灰路,
				"「%s」texture_disabled = 烘好的灰皮" % 名,
				"实际 %s" % (钮.texture_disabled.resource_path if 钮.texture_disabled != null else "<无>"))
		# 悬停/按下两档运行期 load ⇒ 场景里钉不住，但**文件必须在**（缺一档整条链静默死掉）
		for 档 in ["悬停", "按下"]:
			var 路 := "res://素材/界面/专用控件/分页%s_%s.png" % [名, 档]
			_判(ResourceLoader.exists(路), "「%s」的 %s 皮在盘上" % [名, 档], 路)
	for 名 in 禁用钮:
		var 钮 := 根.get_node_or_null("分页/" + 名) as TextureButton
		_判(钮 != null and 钮.disabled, "「%s」烘了 disabled（第 1 页禁 首/上）" % 名,
				"disabled=%s" % (str(钮.disabled) if 钮 else "<无>"))
	for 名 in 可点钮:
		var 钮 := 根.get_node_or_null("分页/" + 名) as TextureButton
		_判(钮 != null and not 钮.disabled, "「%s」第 1 页可点" % 名,
				"disabled=%s" % (str(钮.disabled) if 钮 else "<无>"))
		_判(钮 != null and 钮.texture_normal != null
				and 钮.texture_normal.resource_path.ends_with("通用控件/%s.png" % 名),
				"「%s」常态皮仍是共享原件（派生件不倒回 通用控件/）" % 名,
				"实际 %s" % (钮.texture_normal.resource_path if 钮 != null and 钮.texture_normal != null else "<无>"))
	var 码 := 根.get_node_or_null("分页/页码") as Label
	_判(码 != null and 码.text == "1/4", "页码烘成 1/4（11 条 ÷ 每页 3 = ceil = 4）",
			"实际 %s" % (码.text if 码 else "<无>"))


func _量卡内(根: Control, 件路径: Dictionary, 件文案: Dictionary,
		首页索引: Array, 星位: int) -> void:
	var 文 := _读表(文案路径).get("文案", {}) as Dictionary
	for 卡 in 3:
		var 前 := "卡片_%d" % 卡
		# 四枚固定标签 = 语言表逐字（含「等　　级：」里那两个 U+3000 全角空格）
		for 件名 in 件文案:
			if not String(件名).begins_with("卡片%d" % 卡):
				continue
			var 标 := 根.get_node_or_null(String(件路径[件名])) as Label
			var 键 := String(件文案[件名])
			_判(标 != null and 标.text == String((文.get(键, {}) as Dictionary).get("值", "")),
					"「%s」= 语言表 %s 原文" % [件名, 键],
					"烘的「%s」" % (标.text if 标 else "<无>"))
		var 序 := 根.get_node_or_null(前 + "/序号") as Label
		_判(序 != null and 序.text == "",
				"「卡片%d序号」恒空（`Cell:98` 每次 setData 都写空串）" % 卡,
				"烘了「%s」" % (序.text if 序 else "<无>"))
		var 像 := 根.get_node_or_null(前 + "/头像底/头像") as TextureRect
		_判(像 != null and 像.texture != null
				and 像.texture.resource_path.ends_with("Effect_Wang_%d.png" % int(首页索引[卡])),
				"「卡片%d头像」= 运行期包 Effect_Wang_%d" % [卡, int(首页索引[卡])],
				"实际 %s" % (像.texture.resource_path if 像 != null and 像.texture != null else "<无>"))
		var 底 := 根.get_node_or_null(前 + "/头像底") as Control
		_判(底 != null and 底.mouse_filter == Control.MOUSE_FILTER_STOP,
				"「卡片%d头像底」吃鼠标（简介 tooltip 的宿主是 potraitBg，`Cell:133`）" % 卡,
				"filter=%s" % (str(底.mouse_filter) if 底 else "<无>"))
		var 图 := 根.get_node_or_null(前 + "/地图数值") as Control
		_判(图 != null and 图.mouse_filter == Control.MOUSE_FILTER_STOP,
				"「卡片%d/地图数值」吃鼠标（原版 mapText 可点 = __gotoMap）" % 卡,
				"filter=%s" % (str(图.mouse_filter) if 图 else "<无>"))
		# 星：实心 = floor(dropStars)、有小数再补一枚空心；其余星位 visible=false（不新建节点）
		var 段 := _星段(首页索引[卡])
		var 实: int = int(段[0])
		var 空: int = int(段[1])
		var 错星 := ""
		for 序2 in 星位:
			var 星 := 根.get_node_or_null("%s/星级/星_%d" % [前, 序2]) as TextureRect
			if 星 == null:
				错星 += " 缺星%d" % 序2
				continue
			var 该显: bool = 序2 < 实 + 空
			if 星.visible != 该显:
				错星 += " 星%d visible=%s(想 %s)" % [序2, str(星.visible), str(该显)]
			elif 该显:
				var 想空: bool = 空 > 0 and 序2 == 实
				var 路 := 星.texture.resource_path if 星.texture != null else ""
				if 路.ends_with("半星.png") != 想空:
					错星 += " 星%d 皮=%s(想 %s)" % [序2, 路.get_file(),
							"半星" if 想空 else "星级"]
		_判(错星 == "", "「卡片%d星级」%d 枚位与 dropStars 一致（实 %d + 空 %d）" % [卡, 星位, 实, 空],
				"应全对：" + 错星)
		var 挑 := 根.get_node_or_null(前 + "/挑战钮") as CanvasItem
		_判(挑 != null and 挑.visible, "「卡片%d挑战钮」可见（`setData:93` 置 true）" % 卡,
				"visible=%s" % (str(挑.visible) if 挑 else "<无>"))


## `dropStars` 在 JSON 里是 float ⇒ 按等价数值口径（真值 §2.2 有整段说明）。
func _星段(序: int) -> Array:
	var 包 := _读表("res://数据/原版杂项.json")
	var 行: Dictionary = ((包.get("BossWang", {}) as Dictionary).get("boss", {}) as Dictionary) \
			.get(str(序), {}) as Dictionary
	var 值: float = float(行.get("dropStars", 0.0))
	var 实: int = int(floor(值))
	return [实, (1 if 值 - float(实) > 0.0 else 0)]


func _量数据不变量(表: Dictionary, 首页索引: Array) -> void:
	var 包 := _读表("res://数据/原版杂项.json")
	var 行: Dictionary = ((包.get("BossWang", {}) as Dictionary).get("boss", {}) as Dictionary) as Dictionary
	_判(行.size() == 11, "BossWang.boss = 11 条（⇒ 4 页，末页只有 2 条）", "实际 %d 条" % 行.size())
	_判(int(表.get("每页条数", 0)) == 3, "每页 3 条 = `Window:61` new PageComponent(条数, 3)",
			"实际 %s" % str(表.get("每页条数")))
	_判(首页索引.size() == 3 and int(首页索引[0]) == 0 and int(首页索引[2]) == 2,
			"首页烘的是第 0/1/2 条", "实际 %s" % str(首页索引))
	var 文 := _读表(文案路径).get("文案", {}) as Dictionary
	var 缺 := ""
	for 键 in 文案键:
		if not 文.has(键):
			缺 += " " + 键
	_判(缺 == "", "首领_文案.json 有全部九键（缺就先跑 出首领原文数据.py）", "缺：" + 缺)
	# 「等」+两个 U+3000+「级」+「：」= **5** 字（先前按 6 判是我数错了）。
	_判(String((文.get("WANG_BOSS_CELL_LEVEL", {}) as Dictionary).get("值", "")).length() == 5,
			"「等　　级：」= 5 字（含两个 U+3000 全角空格，别被编辑器/字体吃掉）",
			"实际「%s」%d 字" % [String((文.get("WANG_BOSS_CELL_LEVEL", {}) as Dictionary).get("值", "")),
					String((文.get("WANG_BOSS_CELL_LEVEL", {}) as Dictionary).get("值", "")).length()])


## 控制器必须指真值路径。旧薄壳那版（`首领卡片/首领_%d` + `形象/等级/地图/时间/挑战`）
## 一旦回来，运行期会在 `get_node` 上取空、整页不画 —— 而**有头门才会红**，
## 所以这条钉在离线门里。
func _量控制器接线() -> void:
	var 源 := FileAccess.get_file_as_string(控制器路)
	if 源.is_empty():
		_报("读不到控制器 %s" % 控制器路)
		return
	for 串 in ["卡片_%d/挑战钮", "卡片_%d/地图数值", "分页/页码", "头像底/头像",
			"星级/星_%d", "首领行(", "request_map_change"]:
		_判(源.contains(串), "控制器在走真值路径/钩子：%s" % 串, "源码里找不到")
	for 串 in ["首领卡片/首领_", 'get_node("形象")', 'get_node("等级")', 'get_node("时间")']:
		_判(not 源.contains(串), "控制器不再指旧薄壳：%s" % 串, "还在源码里")
	# 控制器必须是**独立一份**：`活动窗口.gd` preload 了六张场景，交包会拖走五张不相干的页
	var 活动 := FileAccess.get_file_as_string("res://脚本/界面/窗口/活动窗口.gd")
	_判(not 活动.contains("首领场景") and not 活动.contains("_render_boss"),
			"首领代码已从 活动窗口.gd 切干净（交包只带这一份控制器）", "活动窗口里还留着首领")
	_判(源.contains("static func 渲染(宿主)"), "渲染入口是 首领窗口.渲染(宿主)", "签名变了")
	# 薄壳组件已退役：场景与控制器都不许再引用它
	var 场 := FileAccess.get_file_as_string(场景路)
	_判(not 场.contains("首领卡片") and not 源.contains("首领卡片"),
			"薄壳组件 首领卡片.tscn 已不被场景/控制器引用（文件保留未删）", "仍有引用")
	_判(场.count('node name=') == 80, "场景 80 个节点（三卡 × 22 + 外壳 + 翻页条）",
			"实际 %d ⇒ 八成被旧薄壳顶回去了" % 场.count('node name='))
