extends SceneTree

## 量「木叶村 25 枚 NPC 的对话弹窗」（2026-10-04）。
##
## 与 `截NPC对话页.gd` 的分工：那一份量**纲手一扇**的逐件几何；这一份量**整批 NPC 的数据驱动链路**。
## 关键一条：这里**故意不显式喂菜单** —— 只调 `show_npc_dialog(id, 台词)`。
## 离线没有后端 ⇒ 它必须自己退到 `数据/界面/木叶村NPC.json`
## （那张表由 `出木叶村NPC表.py` 照服务端 `fake_flash_server.py:51342-51410` 的组装规则导出）。
## ⇒ 这份跑绿 = 「离线点每枚 NPC 看到的菜单，与服务端在线下发的是同一张」；跑红 = 表或接线断了。
##
## 步序口径（本工程踩过的坑）：**改状态与拍图之间必须隔帧**（`root.get_texture()` 是上一帧画果）
## ⇒ 每个 NPC 拆成「喊窗 → 等待 → 验+拍」两条队列步，不在同一帧里既改又拍。
##
## 用法（不能加 --headless）：
##   Godot --path . --script res://开发工具/截木叶村NPC页.gd -- --出目录=res://测试/截图/木叶村NPC

const 表路径 := "res://数据/界面/木叶村NPC.json"
const 宽 := 506.0
const 上格高最少 := 77.0
const 下格高最少 := 74.0
const 行距 := 20.0
const 黄 := Color(1, 0.941176, 0, 1)
const 绿 := Color(0, 1, 0, 1)

## 已落地的（动作值 → 本工程页名）。⚠ 每条都必须在表里找得到，否则量具自己红 ——
## 这样「数据表加了新落地、判据没跟上」也会被抓出来（而不是默默少测一条）。
## 注：`QUEST=0` 不在这里 —— 木叶村 25 枚里没有任何一枚服务端菜单给了它（那是引导 NPC 的）。
const 落地判据 := [[9, "兑换商店", "夹具"], [31, "变身卡属性互换"], [32, "变身卡特性互换"], [1, "NPC商店"], [2, "NPC仓库"], [12, "副本"], [30, "精英副本"], [14, "藏宝图"], [28, "忍具兑换"], [25, "十拳剑兑换"], [8, "卡片套册"], [17, "勾玉炼制"], [18, "跨服频道", "跨服"],
		# 2026-10-06 这三行从「未移植」挪进来（阿凯 15 / 三代火影 26 / 木叶丸 13）
		[15, "生命料理"], [26, "洗点"], [13, "徽章打造"]]
## 兑换商店的格子是运行期由 1820 回帧建的 ⇒ 不喂数据就只拍得到空态。
## 喂的那 12 行来自 `数据/界面/兑换商店_夹具.json`（`出兑换商店夹具.py` 从 2.2.3优化版捕获目录导出）。
const 兑换夹具路径 := "res://数据/界面/兑换商店_夹具.json"
## 漩涡鸣人（动作值 18 = WAR）那扇「跨服频道」的三档状态色（通畅/良好/爆满）只有
## `1825:0` 回帧才有 ⇒ 用 `数据/界面/跨服频道_夹具.json`（**门自造，不是捕获帧**）喂。
## ⚠ 这一页还要**挪窗**：595×451 在 960×560 里被错开摆位推到下沿 ⇒ 第 9/10 行那 5 枚格出屏。
const 跨服夹具路径 := "res://数据/界面/跨服频道_夹具.json"
const 跨服控制器 := preload("res://脚本/界面/窗口/跨服频道窗.gd")
## 未移植动作（点了只许出通知条、不许造窗）—— **2026-10-06 起清空**：
##   15 生命料理 / 26 重置潜能点（洗点）/ 13 徽章打造 三页都建完了 ⇒ 挪进上面的 落地判据。
## ⚠ 这张表留着的意义 = 「没建的窗不许被拍成窗」；清空之后它一条都不跑，
##   但**别删这段代码**（下一条未移植的页还得靠它）。
const 未移植判据 := []
## 富岳（模板 27）那两行**没有动作值**（`&` 后面是 questId），入口是 `任务行` 的 Callable
## ⇒ 单独一条判据：[NPC 编号, 行文字, 本工程页名, 喂不喂环任务夹具, 出图前挪不挪窗]。
##   少钉一条 = 做了窗却没量到入口（同门的口径）。
## ⚠ 第四格是必要的：护送（志乃 23）那一行**没有 444 形状可喂** —— 它的六个数只在
##   MIXIN 2325 状态帧里（`HuSongQuestManager.showHuSongQuestWindowNow:118-125` 紧接
##   `updateview(richDegree)`）⇒ 拿环任务夹具去喂它 = 量具自己造假。
const 任务行判据 := [["00000027", "每日环任务", "日环任务", "环"],
		["00000027", "周试炼任务", "周试炼任务", "环"],
		["00000023", "护送任务", "护送任务", "无", "挪"]]
## 这两扇的运行期件（星级 / 次数 / 奖励格 / 倒计时）只有服务端 444 任务信息帧才有 ⇒
## 「有数据」那张图靠 `数据/界面/环任务_夹具.json`（**门自造**，字段名逐条对 `BasicQuestInfoData`）。
const 环夹具路径 := "res://数据/界面/环任务_夹具.json"
## 多页签落地页 ⇒ **每一面都要单独拍一张**：三块面板只有一枚 visible，
## 只拍首屏 = 只量到这页的三分之一（17 勾玉炼制 = 面板0/1/2 三页签）。
## 形如 [动作值, 页名, 页根, 枚数, 页签条件名, 面板父件名]（后两格 2026-10-06 加的：
## 徽章打造那页的页签条叫 `页签条`、面板挂在 `内容层` 下，与 勾玉 的 `分页`/`内容底` 不同名，
## 写死一套就会在另一页上 get_node 拿到 null ⇒ 拍到的是没切过去的图还以为切了）。
const 多页签判据 := [[17, "勾玉炼制", "原版勾玉炼制内容", 3, "分页", "内容底"],
		[13, "徽章打造", "原版徽章打造内容", 2, "页签条", "内容层"]]
## 主窗里点一颗钮**开出同族第二扇**的（原版 `PopUpMananger.centerWindow`）：
## [主页名, 页根, 先点的钮, 再点的钮, 弹页名, 弹页根]。洗点确认 就是这一类 —— 它自己
## 没有 NPC 入口（`WashPointWindow.as:240-247` 本地开），不点主窗的钮就拍不到。
## ⚠ 「先点的钮」是把总和弄正的那颗（开始洗点 开屏禁用，`:191`），不点它就永远开不了弹。
const 串门判据 := [["洗点", "原版洗点内容", "行2/行2减钮", "开始钮", "洗点确认", "原版洗点确认内容"]]

var 出目录 := ""
var 行: Array[String] = []
var 有错 := false
var 帧 := 0
var 场景: Node
var 面板: Node
var 窗: Node
var 表: Array = []
var 队列: Array[Callable] = []
var 等待 := 0


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2 and 键值[0] == "--出目录":
			出目录 = 键值[1]
	if 出目录.is_empty():
		出目录 = "res://测试/截图/木叶村NPC"
	if not DirAccess.dir_exists_absolute(出目录):
		DirAccess.make_dir_recursive_absolute(出目录)
	var 解: Variant = JSON.parse_string(FileAccess.get_file_as_string(表路径))
	if typeof(解) != TYPE_DICTIONARY:
		_错("读不到 %s（先跑 python 开发工具/出木叶村NPC表.py）" % 表路径)
	else:
		表 = (解 as Dictionary).get("npc", []) as Array
	队列.append(_步开图)
	for 条v in 表:
		var 条: Dictionary = 条v
		队列.append(_步喊.bind(String(条["id"]), String(条["台词"])))
		队列.append(_步验.bind(条))
	for 组 in 落地判据:
		var 条2 := _带动作(int(组[0]))
		if 条2.is_empty():
			队列.append(_步红.bind("表里没有动作值 %d 的那一行（判据落后于数据表）" % int(组[0])))
			continue
		队列.append(_步喊.bind(String(条2["id"]), String(条2["台词"])))
		队列.append(_步点落地.bind(条2, int(组[0]), String(组[1])))
		if 组.size() > 2 and String(组[2]) == "夹具":
			队列.append(_步喂夹具.bind(String(组[1])))
		elif 组.size() > 2 and String(组[2]) == "跨服":
			# 顺序是 挪窗 ⇒ 拍离线（32 枚全灰禁用 = 原版开屏那一帧）⇒ 喂 ⇒ 下面那张通用的
			# `落地_<页>.png`（三档色）。**挪窗要在拍之前**：不挪的话第 9/10 行那 5 枚在屏外，
			# 图里就没有 28 号那一格，喂没喂都看不出差别。
			队列.append(_步挪窗.bind(String(组[1])))
			队列.append(_步拍全屏.bind("落地_%s_离线.png" % String(组[1])))
			队列.append(_步喂跨服夹具.bind(String(组[1])))
		队列.append(_步拍全屏.bind("落地_%s.png" % String(组[1])))
		for 多 in 多页签判据:
			if int(多[0]) == int(组[0]):
				for 序 in int(多[3]):
					# ⚠ 切页与拍屏**必须两条步**：`等待` 是在上一步跑完之后才开始数帧的，
					#   在同一步里 emit 完立刻 `get_texture().get_image()` 拍到的是**切换前**那一帧
					#   （实测：页签1 那张里画的还是面板0）。
					队列.append(_步切页.bind(String(组[1]), String(多[2]), 序, int(多[3]),
							String(多[4]), String(多[5])))
					队列.append(_步拍全屏.bind("落地_%s_页签%d.png" % [String(组[1]), 序]))
	for 串 in 串门判据:
		队列.append(_步串门.bind(String(串[0]), String(串[1]), String(串[2]), String(串[3]),
				String(串[4]), String(串[5])))
		队列.append(_步拍全屏.bind("落地_%s.png" % String(串[4])))
	for 组 in 任务行判据:
		var 条4 := _找条(String(组[0]))
		if 条4.is_empty():
			队列.append(_步红.bind("表里没有 NPC %s" % String(组[0])))
			continue
		队列.append(_步喊.bind(String(组[0]), String(条4["台词"])))
		队列.append(_步点任务行.bind(条4, String(组[1]), String(组[2])))
		if 组.size() > 4 and String(组[4]) == "挪":
			队列.append(_步挪窗.bind(String(组[2])))
		队列.append(_步拍全屏.bind("落地_空_%s.png" % String(组[2])))
		if String(组[3]) == "环":
			队列.append(_步喂环夹具.bind(String(组[2]), String(组[1])))
			队列.append(_步拍全屏.bind("落地_有数_%s.png" % String(组[2])))
	for 码 in 未移植判据:
		var 条3 := _带动作(int(码))
		if 条3.is_empty():
			队列.append(_步红.bind("表里没有动作值 %d" % int(码)))
			continue
		队列.append(_步喊.bind(String(条3["id"]), String(条3["台词"])))
		队列.append(_步点未移植.bind(条3, int(码)))


func _process(_d: float) -> bool:
	帧 += 1
	if 等待 > 0:
		等待 -= 1
		return false
	if 帧 < 10:
		return false
	if 队列.is_empty():
		_收尾()
		return true
	队列.pop_front().call()
	return false


func _步开图() -> void:
	var 地图 := load("res://场景/地图/地图场景.tscn") as PackedScene
	场景 = 地图.instantiate()
	root.add_child(场景)
	面板 = 场景.get_node_or_null("小地图面板")
	if 面板 == null:
		_错("地图场景下没有 小地图面板")
		队列.clear()
		return
	等待 = 6


## 只给 id 与台词，菜单让 小地图面板 自己去表里取（这条就是被验的那一跳）。
func _步喊(编号: String, 台词: String) -> void:
	面板.call("show_npc_dialog", 编号, 台词)
	等待 = 3
	窗 = _找(面板, "原版NPC对话窗")


## 递归找（`_对话` 是 `add_sibling` 挂到面板内层 root 下的，不是 面板 的直接子节点 —— 只搜一层必然取空）。
func _找(父: Node, 名: String) -> Node:
	for 子 in 父.get_children():
		if str(子.name) == 名:
			return 子
		var 果 := _找(子, 名)
		if 果 != null:
			return 果
	return null


## selection 那几行的**应有文案**，逐字钉死（用户 2026-10-05 给的实机截图就是这两行）。
## 故意不把 `NPC对话窗.选择文案()` 拿来当期望 ⇒ 那等于自证；这里是一份独立的复述：
## 前缀 `[日环]`/`[周环]`(:1705/:255) + 文字 + `(次数/上限)`(:266-276) + `（可接）`(:1658，状态 0)。
const 选择句表 := {
	"00000027": ["[日环]每日环任务(1/20)（可接）", "[周环]周试炼任务(1/100)（可接）"],
	# 志乃那一条是护送行（`fake_flash_server.py:51467`）：前缀 `[护送]`（QUEST_DIALOG_HUSONG）、
	# 带计数 `(1/3)`（mixin 在 `选择带计数` 里）、后缀 `（可接）`；status 0 ⇒ 客户端把 value
	# 强改成 -1（`QuestDialog.as:304-305`）⇒ 点它**本地开窗、不发帧**。
	"00000023": ["[护送]护送任务(1/3)（可接）"],
}


## 下格高的原版公式（`:341-346`）：菜单末行底 + 20、selection 块高 + 40、74 三者取大。
func _期望下格高(菜单n: int, 块: RichTextLabel) -> float:
	var 高 := maxf(40.0 + 菜单n * 行距, 下格高最少)
	if 块 != null and 块.visible:
		高 = maxf(高, 块.size.y + 40.0)
	return 高


func _期望文字(条: Dictionary) -> Array[String]:
	var 出: Array[String] = []
	for r in (条["菜单"] as Array):
		出.append(String((r as Dictionary)["文字"]))
	# selection 行排在菜单行**之后**（原版 `QuestDialog.as:215-236` 先摆 menu、`:249-345` 再摆 selection）
	for 句 in (选择句表.get(String(条["id"]), []) as Array):
		出.append(String(句))
	return 出


func _行号(条: Dictionary, 动作值: int) -> int:
	var i := 0
	for r in (条["菜单"] as Array):
		if int((r as Dictionary)["动作"]) == 动作值:
			return i
		i += 1
	return 0


func _带动作(动作值: int) -> Dictionary:
	for 条v in 表:
		for r in ((条v as Dictionary)["菜单"] as Array):
			if int((r as Dictionary)["动作"]) == 动作值:
				return 条v
	return {}


func _步验(条: Dictionary) -> void:
	var 编号 := String(条["id"])
	行.append("=== %s %s（%s）===" % [编号, String(条["名"]), String(条["称号"])])
	if 窗 == null:
		_错("%s 没建出 原版NPC对话窗" % 编号)
		return
	var 根 := 窗.get_node("原版NPC对话") as Control
	if 根 == null or not 根.visible:
		_错("%s 对话窗根节点不可见" % 编号)
		return
	var 期望文字 := _期望文字(条)
	var 实文字: Array[String] = 窗.call("行文字表")
	var 同: bool = 实文字 == 期望文字
	有错 = 有错 or (not 同)
	行.append("  菜单 %s（应 %s）%s" % [str(实文字), str(期望文字), "√" if 同 else "!! 不符"])
	var 菜单n := (条["菜单"] as Array).size()
	var 上格 := 根.get_node("上格") as Control
	var 下格 := 根.get_node("下格") as Control
	var 块 := 下格.get_node_or_null("选择块") as RichTextLabel
	var 有块: bool = 块 != null and 块.visible
	var 尺对: bool = absf(上格.size.x - 宽) < 0.01 and absf(下格.size.x - 宽) < 0.01 \
			and 上格.size.y >= 上格高最少 and 下格.size.y >= 下格高最少 \
			and absf(下格.position.y - (上格.size.y + 5.0)) < 0.01 \
			and absf(下格.size.y - _期望下格高(菜单n, 块)) < 0.01
	有错 = 有错 or (not 尺对)
	行.append("  两格 上 %.0fx%.0f、下 y=%.0f %.0fx%.0f（菜单 %d 行%s）%s" % [
		上格.size.x, 上格.size.y, 下格.position.y, 下格.size.x, 下格.size.y, 菜单n,
		"、+selection 块 %.0f 高" % 块.size.y if 有块 else "",
		"√" if 尺对 else "!! 下格没按公式长（`QuestDialog.as:341-346` = max(菜单末行底+20, 块高+40, 74) → %.0f）"
				% _期望下格高(菜单n, 块)])
	# selection 块：整块居中富文本，**不是一行一个按钮**（用户实机图打回的那一条）
	if 有块:
		var 净: Array[String] = 窗.call("选择文字表")
		var 句: Array = (选择句表.get(编号, []) as Array)
		var 句对: bool = 净.size() == 句.size()
		for i in 句.size():
			句对 = 句对 and i < 净.size() and 净[i] == String(句[i])
		var 块对: bool = 句对 and absf(块.size.x - 366.0) < 0.01 				and 块.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND 				and 块.position.x > 0.0 and 块.position.y > 0.0
		有错 = 有错 or (not 块对)
		行.append("  selection 块 %s @(%0.0f,%0.0f) 宽 %.0f %s" % [
			str(净), 块.position.x, 块.position.y, 块.size.x,
			"√ 整块居中 + 手型 + 宽 366（`:336-337`）" if 块对 else "!! 文案或摆位不对"])
	var 名件 := 根.get_node("上格/名字") as Label
	var 台件 := 根.get_node("上格/台词") as RichTextLabel
	var 名对: bool = 名件.text == String(条["名"])
	var 台对: bool = (台件.text as String).contains(String(条["台词"]))
	有错 = 有错 or (not 名对) or (not 台对)
	行.append("  名字=%s %s / 台词=%s %s" % [名件.text, "√" if 名对 else "!! 与表不符",
			台件.text, "√" if 台对 else "!! 与 NPC.json 不符"])
	var 色对: bool = 名件.get_theme_color(&"font_color") == 黄
	var 绿对 := true
	for i in 菜单n:
		var 件 := 根.get_node_or_null("下格/菜单/行%d/文字" % (i + 1)) as Label
		if 件 == null:
			绿对 = false
			continue
		绿对 = 绿对 and (件.get_theme_color(&"font_color") == 绿) \
				and (件.get_parent().mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND)
	有错 = 有错 or (not 色对) or (not 绿对)
	行.append("  字色 名字#fff000 / 各行#00ff00 且行带手型 %s" % ["√" if 色对 and 绿对 else "!! 不符"])
	var 视 := root.get_visible_rect()
	var 居: bool = absf(根.get_global_position().x * 2.0 + 根.size.x - 视.size.x) < 1.0 \
			and absf(根.get_global_position().y * 2.0 + 根.size.y - 视.size.y) < 1.0
	有错 = 有错 or (not 居)
	行.append("  居中 %s（左上 %.1f,%.1f 视口 %dx%d）" % ["√" if 居 else "!! 没居中",
			根.get_global_position().x, 根.get_global_position().y, 视.size.x, 视.size.y])
	for r in (条["菜单"] as Array):
		var 页 := String((r as Dictionary).get("落地页", ""))
		if 页.is_empty():
			continue
		var 在: bool = false
		for g in 落地判据:
			if int(g[0]) == int((r as Dictionary)["动作"]):
				在 = true
		if not 在:
			_错("%s 的行「%s」落地页=%s，但 落地判据 没这条 ⇒ 判据落后于数据表" % [
				编号, String((r as Dictionary)["文字"]), 页])
	_拍("%s/客户端_%s_%s.png" % [出目录, 编号, String(条["名"])])


func _拍(路径: String) -> void:
	var 图像 := root.get_texture().get_image()
	var 根 := (窗.get_node("原版NPC对话")) as Control
	var 起 := Vector2i(int(根.get_global_position().x), int(根.get_global_position().y))
	var 尺 := Vector2i(int(根.size.x), int(根.size.y))
	起.x = clampi(起.x, 0, 图像.get_width() - 1)
	起.y = clampi(起.y, 0, 图像.get_height() - 1)
	尺.x = clampi(尺.x, 1, 图像.get_width() - 起.x)
	尺.y = clampi(尺.y, 1, 图像.get_height() - 起.y)
	var 错 := 图像.get_region(Rect2i(起, 尺)).save_png(路径)
	行.append("  截图 %s（%dx%d，%s）" % [路径, 尺.x, 尺.y, "ok" if 错 == OK else "err %d" % 错])


func _步拍全屏(名: String) -> void:
	var 图像 := root.get_texture().get_image()
	图像.save_png("%s/%s" % [出目录, 名])
	等待 = 2


## 点一条已落地的行 ⇒ 那一页必须真被叫出来（走 `按下行` 这条与真点击相同的路径）。
func _步点落地(条: Dictionary, 动作值: int, 页名: String) -> void:
	if 窗 == null:
		_错("点「%s」前窗没建出来" % 页名)
		return
	# 落地截图要干净：先把别的页全关掉（否则 25 枚逐枚 + 前几条落地的窗会叠在后面，
	# 目视时分不清哪块是本页画的 —— 2026-10-04 就被这个坑到一次「格子不见了」的误判）。
	var 管理0 = 场景.get_node_or_null("窗口管理")
	if 管理0 != null and 管理0.has_method("全部关闭"):
		管理0.call("全部关闭")
		等待 = 3
	窗.call("按下行", _行号(条, 动作值))
	等待 = 5
	var 管理 := 场景.get_node_or_null("窗口管理")
	var 窗体: Node = null
	if 管理 != null:
		窗体 = 管理.call("取或建窗口", 页名) as Node
	var 当前 := "" if 窗体 == null else String(窗体.get("_current_page"))
	var 开着: bool = 当前 == 页名
	有错 = 有错 or (not 开着)
	行.append("点 %s 的「%s」（动作 %d）→ %s 窗 _current_page=%s %s" % [
		String(条["名"]), _文字of(条, 动作值), 动作值, 页名, 当前, "√ 已打开" if 开着 else "!! 没弹出来"])
	# 状态行是**全工程共用的反馈口子**，它到底显不显形、画在哪，只能在这儿量一次
	# （2026-10-04：`后端状态` 在场景里 `visible=false` ⇒ 之前所有"点了给个说法"都没人看得见）。
	if 窗体 != null:
		var 主窗 := 窗体.get_node_or_null("遮罩/主窗口") as Control
		if 主窗 != null:
			行.append("  外框全局矩形 %s（对原版截图裁图按它，别靠肉眼估）" % str(主窗.get_global_rect()))
		var 状 := 窗体.get_node_or_null("遮罩/主窗口/后端状态") as Label
		if 状 != null:
			行.append("  状态行 visible=%s 矩形=%s 字色=%s 字号=%d 文字=%s" % [
				str(状.visible), str(状.get_global_rect()), str(状.get_theme_color("font_color")),
				状.get_theme_font_size("font_size"), 状.text])


## 多页签页切到第 序 枚（**只切不拍** ⇒ 拍屏是队列里的下一条，隔 4 帧才拿到画面）。
## 驱动方式 = 走页签钮的 `pressed`（与真点同一条控制器路径）；「真鼠标点得到」这条不在这里证，
## 由 `测试/勾玉炼制页回归测试.gd` 用 `push_input` 逐枚量（visible / disabled / 提交钮文字 三件一起换）。
## 这里切完**仍断言落到的态** ⇒ 免得后面那张拍到的是没切过去的图还以为切了。
func _步切页(页名: String, 页根: String, 序: int, 枚数: int, 页签父: String, 面板父: String) -> void:
	var 管理 := 场景.get_node_or_null("窗口管理")
	var 窗体: Node = null
	if 管理 != null:
		窗体 = 管理.call("取或建窗口", 页名) as Node
	var 页: Control = null
	if 窗体 != null:
		页 = 窗体.get_node_or_null("遮罩/主窗口/页面容器/%s" % 页根) as Control
	if 页 == null:
		_错("切页签 %d 前 %s 的页根 %s 没建出来" % [序, 页名, 页根])
		return
	var 钮 := 页.get_node_or_null("%s/页签%d" % [页签父, 序]) as Button
	if 钮 == null:
		_错("页签%d 不在场景里（%s/页签%d）" % [序, 页签父, 序])
		return
	钮.emit_signal("pressed")
	等待 = 4
	var 只对 := true
	var 明细: Array[String] = []
	for i in 枚数:
		var 面 := 页.get_node_or_null("%s/面板%d" % [面板父, i]) as Control
		var 可 := 面 != null and bool(面.visible)
		明细.append("面板%d=%s" % [i, "显" if 可 else "隐"])
		if 可 != (i == 序):
			只对 = false
	# 提交钮两页不同名：勾玉那页叫 `提交钮`（顶层）、徽章打造那页叫 `确定钮`（顶层）。
	var 提: Button = null
	for 名 in ["提交钮", "确定钮"]:
		提 = 页.get_node_or_null(名) as Button
		if 提 != null:
			break
	var 提文 := "" if 提 == null else 提.text
	只对 = 只对 and 提文 != ""
	有错 = 有错 or (not 只对)
	行.append("切到页签%d ⇒ %s，提交钮「%s」%s（真点由 勾玉炼制页回归测试.gd 量）" % [
		序, " ".join(明细), 提文, "√" if 只对 else "!!"])


## 主窗点一颗钮开出**同族第二扇**（洗点 → 洗点确认）⇒ 先点那颗把总和弄正的钮，
## 再点主钮，然后断言弹页真的成了当前页（否则拍到的还是主窗，看图的人分不出来）。
## ⚠ 与 `_步切页` 同一个口径：这里 `emit_signal` 只为**拍到那一帧**，
##   "真鼠标点得到"由 `测试/阿凯洗点徽章页回归测试.gd` 用 `push_input` 逐颗量。
func _步串门(主页: String, 主页根: String, 先点: String, 再点: String, 弹页: String, 弹页根: String) -> void:
	var 管理 = 场景.get_node_or_null("窗口管理")
	if 管理 == null:
		_错("没有 窗口管理 ⇒ 串门这一跳无从点起")
		return
	# 上一节的落地页还开着 ⇒ 先全关再走主窗，否则 `取或建窗口` 拿到的是**别的页**的窗体。
	管理.call("全部关闭")
	等待 = 3
	管理.call("打开", 主页)
	等待 = 5
	var 主窗体: Node = 管理.call("取或建窗口", 主页) as Node
	var 页: Control = null
	if 主窗体 != null:
		页 = 主窗体.get_node_or_null("遮罩/主窗口/页面容器/%s" % 主页根) as Control
	if 页 == null:
		_错("%s 的页根没建出来 ⇒ 开不了 %s" % [主页, 弹页])
		return
	for 路 in [先点, 再点]:
		var 钮 := 页.get_node_or_null(路) as Button
		if 钮 == null:
			_错("%s 里没有钮 %s" % [主页, 路])
			return
		if 路 == 再点 and 钮.disabled:
			_错("%s 仍是禁用态 ⇒ 说明「%s」那一下没把总和弄正（原版 `:191`+`:83`）" % [再点, 先点])
			return
		钮.emit_signal("pressed")
		等待 = 4
	var 弹窗体: Node = 管理.call("取或建窗口", 弹页) as Node
	var 当前 := "" if 弹窗体 == null else String(弹窗体.get("_current_page"))
	var 开着: bool = 当前 == 弹页
	var 有件: bool = 弹窗体 != null and (弹窗体.get_node_or_null(
			"遮罩/主窗口/页面容器/%s" % 弹页根) as Node) != null
	有错 = 有错 or (not (开着 and 有件))
	行.append("%s 点「%s」→「%s」→ %s 窗 _current_page=%s 页根 %s %s" % [
		主页, 先点, 再点, 弹页, 当前, "已建" if 有件 else "缺", "√" if 开着 and 有件 else "!!"])


## 运行期建的页（格子/列表）不喂数据就只拍得到空态 ⇒ 从夹具 json 原样喂进去再拍。
## 只喂 **不点**：这一跳验的是画出来的形状，行为由 `伊鲁卡三窗回归测试.gd` 用真 `push_input` 量。
func _步喂夹具(页名: String) -> void:
	var 管理 := 场景.get_node_or_null("窗口管理")
	var 窗体: Node = null
	if 管理 != null:
		窗体 = 管理.call("取或建窗口", 页名) as Node
	if 窗体 == null:
		_错("喂夹具前 %s 窗没建出来" % 页名)
		return
	var 解: Variant = JSON.parse_string(FileAccess.get_file_as_string(兑换夹具路径))
	if typeof(解) != TYPE_DICTIONARY:
		_错("读不到 %s（先跑 python 开发工具/出兑换商店夹具.py）" % 兑换夹具路径)
		return
	var 行表: Array = (解 as Dictionary).get("行", []) as Array
	if 行表.is_empty():
		_错("%s 里没有行" % 兑换夹具路径)
		return
	窗体.call("_render_exchange_shop", 行表)
	等待 = 4
	行.append("  喂 %d 行夹具（%s）⇒ 下面那张是**有数据**的整窗" % [行表.size(), 兑换夹具路径])


## 跨服频道（漩涡鸣人 00000012，动作值 18）：频道状态文字与三档色只有 `1825:0` 回帧才有
## ⇒ 量具直接调控制器的 `填数`（= 原版 `setData:130-162` 服务端那一半）。
## ⚠ 喂的是 `数据/界面/跨服频道_夹具.json` —— **门自造、不是捕获帧**（这条协议本工程没接），
##   字段名与顺序逐字对 `WarChannelInfo.decode`；图只证明"有数据那一帧长什么样"。
func _步喂跨服夹具(页名: String) -> void:
	var 管理 := 场景.get_node_or_null("窗口管理")
	var 窗体: Node = null
	if 管理 != null:
		窗体 = 管理.call("取或建窗口", 页名) as Node
	if 窗体 == null:
		_错("喂跨服夹具前 %s 窗没建出来" % 页名)
		return
	var 容器 := 窗体.get_node_or_null("遮罩/主窗口/页面容器") as Control
	if 容器 == null:
		_错("%s 没有 遮罩/主窗口/页面容器" % 页名)
		return
	var 页: Control = null
	for 子 in 容器.get_children():
		if 子 is Control:
			页 = 子 as Control
	if 页 == null:
		_错("%s 的页面容器里没长出页根 ⇒ 窗是空的，喂不了" % 页名)
		return
	var 解: Variant = JSON.parse_string(FileAccess.get_file_as_string(跨服夹具路径))
	if typeof(解) != TYPE_DICTIONARY:
		_错("读不到 %s" % 跨服夹具路径)
		return
	var 列表: Array = (解 as Dictionary).get("列表", []) as Array
	var 最大 := int((解 as Dictionary).get("maxLoad", 100))
	if 列表.is_empty():
		_错("%s 里没有行" % 跨服夹具路径)
		return
	跨服控制器.填数(页, 列表, 最大)
	等待 = 4
	行.append("  喂 %d 行跨服夹具（%s，maxLoad=%d）⇒ 下面那张是**有数据**的整窗"
			% [列表.size(), 跨服夹具路径, 最大])


## 未移植的行：只许出通知条说清缺哪扇，**不许开出一扇自造的窗**。
func _步点未移植(条: Dictionary, 动作值: int) -> void:
	if 窗 == null:
		_错("点未移植行前窗没建出来")
		return
	窗.call("按下行", _行号(条, 动作值))
	等待 = 3
	var 文字 := _文字of(条, 动作值)
	var 条件 := 面板.get("_toast") as Label
	var 说了: bool = 条件 != null and 条件.visible and (条件.text as String).contains(文字)
	有错 = 有错 or (not 说了)
	行.append("点 %s 的「%s」（未移植）→ 通知条「%s」%s" % [String(条["名"]), 文字,
			条件.text if 条件 != null else "无", "√ 只提示、没造窗" if 说了 else "!! 没给提示"])


func _文字of(条: Dictionary, 动作值: int) -> String:
	for r in (条["菜单"] as Array):
		if int((r as Dictionary)["动作"]) == 动作值:
			return String((r as Dictionary)["文字"])
	return "?"


func _找条(编号: String) -> Dictionary:
	for 条v in 表:
		if String((条v as Dictionary)["id"]) == 编号:
			return 条v as Dictionary
	return {}


## 点 `任务行` 那一族：行号 = 菜单行数 + 第几行（`小地图面板.NPC菜单行` 是**先菜单后 selection**，
## 原版顺序 `QuestDialog.as:215-236` 再 `:256-275`）。`按下行` 拿到的是 Callable ⇒ 本地开页、不发 57。
## 环任务那两枚勾选的初值读的是会话 `game_settings`（**会落盘**）⇒ 拍图前钉成未勾：
## 否则这张证据图取决于上一次门跑完留下什么，重跑会变，而且与原版实机图（两枚都没勾）不一致。
func _钉勾() -> void:
	var 会 = root.get_node_or_null("/root/GameSession")
	if 会 != null and typeof(会.get("game_settings")) == TYPE_DICTIONARY:
		var 设: Dictionary = 会.get("game_settings")
		设["riHuan_auto"] = false
		设["riHuan_stop"] = false


func _步点任务行(条: Dictionary, 文字: String, 页名: String) -> void:
	if 窗 == null:
		_错("点「%s」前窗没建出来" % 页名)
		return
	_钉勾()
	var 管理0 = 场景.get_node_or_null("窗口管理")
	if 管理0 != null and 管理0.has_method("全部关闭"):
		管理0.call("全部关闭")
		等待 = 3
	var 任: Array = (条.get("任务行", []) as Array)
	var 序 := (条["菜单"] as Array).size()
	var 中 := false
	for t in 任:
		if String((t as Dictionary)["文字"]) == 文字:
			中 = true
			break
		序 += 1
	if not 中:
		_错("表里没有 %s 的「%s」这一行（判据落后于数据表）" % [String(条["id"]), 文字])
		return
	窗.call("按下行", 序)
	等待 = 5
	var 管理 := 场景.get_node_or_null("窗口管理")
	var 窗体: Node = null
	if 管理 != null:
		窗体 = 管理.call("取或建窗口", 页名) as Node
	var 当前 := "" if 窗体 == null else String(窗体.get("_current_page"))
	var 开着: bool = 当前 == 页名
	有错 = 有错 or (not 开着)
	行.append("点 %s 的 selection 行「%s」（行号 %d，无动作值）→ %s 窗 _current_page=%s %s" % [
		String(条["名"]), 文字, 序, 页名, 当前, "√ 已打开" if 开着 else "!! 没弹出来"])
	if 窗体 != null:
		var 主窗 := 窗体.get_node_or_null("遮罩/主窗口") as Control
		if 主窗 != null:
			行.append("  外框全局矩形 %s（对原版截图裁图按它，别靠肉眼估）" % str(主窗.get_global_rect()))
		var 状 := 窗体.get_node_or_null("遮罩/主窗口/后端状态") as Label
		if 状 != null:
			行.append("  状态行 visible=%s 文字=%s" % [str(状.visible), 状.text])


## 喂一条 444 形状的任务数（只喂不点：形状在这张图里量，行为由 `富岳两窗回归测试.gd` 真点量）。
func _步喂环夹具(页名: String, 文字: String) -> void:
	var 管理 := 场景.get_node_or_null("窗口管理")
	var 窗体: Node = null
	if 管理 != null:
		窗体 = 管理.call("取或建窗口", 页名) as Node
	if 窗体 == null:
		_错("喂夹具前 %s 窗没建出来" % 页名)
		return
	var 解: Variant = JSON.parse_string(FileAccess.get_file_as_string(环夹具路径))
	if typeof(解) != TYPE_DICTIONARY:
		_错("读不到 %s" % 环夹具路径)
		return
	var 键 := "日环" if String(页名) == "日环任务" else "周"
	var 数: Dictionary = ((解 as Dictionary).get(键, {}) as Dictionary)
	if 数.is_empty():
		_错("%s 里没有「%s」那一份数" % [环夹具路径, 键])
		return
	_钉勾()
	窗体.call("_render_daily_ring" if 键 == "日环" else "_render_weekly_ring", 数)
	等待 = 4
	行.append("  喂 %s 夹具（richDegree=%s / order=%s / 奖励 %d 枚）⇒ 下面那张是**有数据**的整窗"
			% [文字, str(数.get("richDegree")), str(数.get("order")),
				(数.get("encourageItems", []) as Array).size()])


## 只为出证据把窗**挪进视口 + 让开 HUD**，两条都是实测出来的、不是预防性写法：
##   ① `窗口管理` 按已开数量错开摆位 ⇒ 578×342 这种高窗被推到贴右下
##      （实测 P=(382,218)、下沿正好 = 视口高 560），「开启护送」那颗钮压在底栏下面；
##   ② `地图场景.tscn` 里 `聊天面板`/`系统消息` 排在 `窗口管理` **之后** ⇒ 同一层序下画在
##      窗口之上（10-04 深夜续三 登记过那条），而前面几步 `_通知` 出去的两条「空态」长句
##      正好糊在窗面上（实测第一版证据图里读得到「日环的运行期数字…」压在窗体上）。
## ⇒ 出图前把窗挪到 (8,8)、把这两块 HUD 关掉，**只动这一张图**，不改任何版式；
##   日志里写清挪到哪、关了哪两块，裁图按日志那个矩形、别靠肉眼估。
func _步挪窗(页名: String) -> void:
	var 管理 := 场景.get_node_or_null("窗口管理")
	if 管理 == null:
		_错("挪窗时没有 窗口管理")
		return
	var 窗体: Node = 管理.call("取或建窗口", 页名) as Node
	if 窗体 == null:
		_错("挪窗时 %s 没建出来" % 页名)
		return
	var 主窗 := 窗体.get_node_or_null("遮罩/主窗口") as Control
	if 主窗 == null:
		_错("挪窗时找不到 %s 的 遮罩/主窗口" % 页名)
		return
	主窗.position = Vector2(8.0, 8.0)
	var 关: Array[String] = []
	for 名 in ["聊天面板", "系统消息"]:
		# ⚠ 这两个是 **CanvasLayer**、不是 CanvasItem ⇒ `as CanvasItem` 拿到 null、
		#   看起来像"节点不存在"（本轮实测假红过一次）。走 `set("visible", …)`。
		var 件: Node = 场景.get_node_or_null(名)
		if 件 == null:
			_错("证据摆位：地图场景里没有「%s」节点 ⇒ 结构变了，先重核再出图" % 名)
			continue
		件.set("visible", false)
		关.append(名)
	等待 = 2
	行.append(("  证据摆位：%s 外框挪到 (8,8) ⇒ %s；关掉 %s（⚠ 只有同为 110 且创建在后的 `系统消息`"
			+ " 会真画在窗面上；聊天/技能/头像/小地图是 20/100，本来就画在窗下面 —— "
			+ "旧版这里写的「HUD 画在窗口层之上」是把**命中**层的旧坑说成了画序，2026-10-06 已修）")
			% [页名, str(主窗.get_global_rect()), " + ".join(关)])


func _步红(文本: String) -> void:
	_错(文本)


func _错(文本: String) -> void:
	有错 = true
	行.append("!! " + 文本)


func _收尾() -> void:
	行.insert(0, "木叶村 NPC %d 枚（表 = %s，规则出处 fake_flash_server.py:51342-51410）" % [表.size(), 表路径])
	var f := FileAccess.open("%s/几何.txt" % 出目录, FileAccess.WRITE)
	if f != null:
		for 一 in 行:
			f.store_line(一)
		f.close()
	for 一 in 行:
		print(一)
	print("木叶村NPC：%s" % ["有不符项" if 有错 else "25 枚菜单/几何/字色/居中/落地/未移植提示 全部对上"])
	quit(1 if 有错 else 0)
