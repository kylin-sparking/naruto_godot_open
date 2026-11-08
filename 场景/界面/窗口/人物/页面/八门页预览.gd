extends Control
## 八门页「独立运行（F6）」预览脚本。
##
## 在编辑器里打开 八门页.tscn 按 F6，本脚本会把 8 个门按钮接上切门逻辑，
## 默认显示「休门」——这样能直接看到穴位组、穴位连线、右侧门标的效果。
##
## 在游戏里（被 人物窗口.gd 实例化到 人物扩展页/八门内容 下时）本脚本什么都不做：
## 那里 get_tree().current_scene 不是本节点，所以不会干扰正式流程。
##
## 注意：这里的切门逻辑是 人物窗口.gd 更新八门页() 的等价副本，故意**不 preload**
## 那个脚本——否则 八门页.tscn ↔ 人物窗口.tscn 会形成循环依赖。

const 门清单 := ["开门", "休门", "生门", "伤门", "杜门", "景门", "惊门", "死门"]

## 门说明 / 修炼提示 的文案与游戏内共用同一份（原版原文），别再各写一套。
const 八门文案 := preload("res://脚本/界面/窗口/八门文案.gd")

## 与 人物窗口.gd 的 八门穴位图 保持一致
const 穴位图 := {
	"开门": "res://素材/界面/原版窗口/人物/八门/开门穴位图.png",
	"休门": "res://素材/界面/原版窗口/人物/八门/休门穴位图.png",
	"生门": "res://素材/界面/原版窗口/人物/八门/生门穴位图.png",
	"伤门": "res://素材/界面/原版窗口/人物/八门/伤门穴位图.png",
	"杜门": "res://素材/界面/原版窗口/人物/八门/杜门穴位图.png",
	"景门": "res://素材/界面/原版窗口/人物/八门/景门穴位图.png",
	"惊门": "res://素材/界面/原版窗口/人物/八门/惊门穴位图.png",
	"死门": "res://素材/界面/原版窗口/人物/八门/死门穴位图.png",
}

var 当前门: String = "休门"


func _ready() -> void:
	if get_tree() == null or get_tree().current_scene != self:
		return
	print("[八门页预览] 独立运行：门按钮已接上，默认显示「休门」。点「总览」回总览页。")
	for 门 in 门清单:
		var 钮 := get_node_or_null("门列表/按钮列/%s" % 门) as Button
		if 钮 != null:
			钮.toggle_mode = true
			钮.pressed.connect(切门.bind(门))
	var 总览钮 := get_node_or_null("门列表/按钮列/总览") as Button
	if 总览钮 != null:
		总览钮.pressed.connect(切门.bind(""))
	var 突破钮 := get_node_or_null("门列表/按钮列/突破瓶颈") as Button
	if 突破钮 != null:
		突破钮.pressed.connect(显示突破弹窗)
	切门(当前门)


## 传空串 = 回到总览页
func 切门(门: String) -> void:
	当前门 = 门
	设置总览视图(门.is_empty())
	var 弹窗 := get_node_or_null("突破瓶颈弹窗") as Control
	if 弹窗 != null:
		弹窗.visible = false
	for 名 in 门清单:
		var 线 := get_node_or_null("穴位面板/穴位连线_%s" % 名) as Line2D
		if 线 != null:
			线.visible = 名 == 门
		var 标 := get_node_or_null("八门人体图/门标_%s" % 名)
		if 标 != null:
			var 暗 := 标.get_node_or_null("暗") as TextureRect
			var 亮 := 标.get_node_or_null("亮") as TextureRect
			if 暗 != null:
				暗.visible = 名 != 门
			if 亮 != null:
				亮.visible = 名 == 门
		var 点层 := get_node_or_null("穴位面板/穴位图/穴位点层_%s" % 名) as Control
		if 点层 != null:
			点层.visible = 名 == 门
		var 钮 := get_node_or_null("门列表/按钮列/%s" % 名) as Button
		if 钮 != null:
			钮.button_pressed = 名 == 门
	var 图 := get_node_or_null("穴位面板/穴位图") as TextureRect
	if 图 != null and 穴位图.has(门):
		图.texture = load(String(穴位图[门])) as Texture2D
	# 文案跟着门走（与游戏内 人物窗口.gd 更新八门页() 同一份数据）
	if 门.is_empty():
		return
	var 说明 := get_node_or_null("门说明面板/门说明") as Label
	if 说明 != null:
		说明.text = 八门文案.门说明(门)
	# 修炼提示是 RichTextLabel（第一行白/第二行橙，原版 #ffffff + #ff9100）
	var 提示 := get_node_or_null("修炼提示面板/修炼提示") as Control
	if 提示 != null:
		提示.set("text", 八门文案.修炼提示(门))
	# 右下角三格是**穴位级**详情，游戏里只在悬停穴位时才填（`人物窗口.gd 刷八门穴位详情`）。
	# 预览没有会话、也拿不到悬停数据 ⇒ 清空，别把场景烘的「曲差 / 生命 +8 / 500」示例值留在脸上。
	for 路 in ["穴位名称/值", "提升属性/值", "所需精华/值"]:
		var 格 := get_node_or_null(路) as Label
		if 格 != null:
			格.text = " "


func 显示突破弹窗() -> void:
	var 弹窗 := get_node_or_null("突破瓶颈弹窗") as Control
	if 弹窗 != null:
		弹窗.visible = true


## 总览页与门内容**互斥**（原版 JingMaiPanel.showZongLanView()）：
##   true  → 显示总览页，隐藏穴位面板/人体图/门说明/修炼提示/三行穴位信息，并亮出「突破瓶颈」
##   false → 反过来
## 游戏内 人物窗口.gd 也调这个方法（页面.call），所以两条路都不会再出现"总览和门内容叠在一起"。
func 设置总览视图(总览: bool) -> void:
	var 总览页 := get_node_or_null("总览页") as Control
	if 总览页 != null:
		总览页.visible = 总览
	for 路径 in ["穴位面板", "八门人体图", "门说明面板", "修炼提示面板",
			"穴位名称标题", "穴位名称", "提升属性标题", "提升属性",
			"所需精华标题", "所需精华"]:
		var 节点 := get_node_or_null(路径) as CanvasItem
		if 节点 != null:
			节点.visible = not 总览
	# 原版里「突破瓶颈」按钮只在总览视图出现（showZongLanView 里 addChild/removeChild）
	var 突破 := get_node_or_null("门列表/按钮列/突破瓶颈") as CanvasItem
	if 突破 != null:
		突破.visible = 总览
	# 「总览」按钮也是可锁定的页签（原版 tabBar 第 0 项），按下态跟着视图走
	var 总览钮 := get_node_or_null("门列表/按钮列/总览") as Button
	if 总览钮 != null and 总览钮.toggle_mode:
		总览钮.button_pressed = 总览
	# 弹窗重新打开时居中，关掉时不用管
	if not 总览:
		var 弹窗 := get_node_or_null("突破瓶颈弹窗") as Control
		if 弹窗 != null:
			弹窗.visible = false
