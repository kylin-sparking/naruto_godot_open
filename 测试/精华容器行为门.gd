extends SceneTree

## #184 行为门：底栏那枚「精华容器」折叠钮**真点得动吗**、两版布局**恰好一版可见吗**、
## 两版的填充宽度/高度**按不按原版的算式**（不是"看着像"）。
##
## 为什么必须真点：上一轮「走到 NPC 前自动开对话」就是门全绿、实机不弹（`has_method` 恒假那种假绿）。
## 本门第一版跑出来 12 条红，红的全是"箭头不是按钮" —— 那正是用户报的缺陷本体。
##
## 真值（逐条到行号，详表见 `真值/窗口/精华容器.md`）：
##   · `MenuPane.as:105` 起步 `breathPane1.visible=false`（默认展开）；`:106` `arrowBtn` 挂 CLICK
##   · `MenuPane.as:119-123` 折叠 = `breathPane.visible = !breathPane.visible` 之后
##     `breathPane1.visible = !breathPane.visible` ⇒ **恰好一版可见**
##   · `MenuPane.as:160-161 / :339-342` 数据两版都喂（`setBreath`/`setToolTip` 各调两次）
##   · `BreathPane.as:113-118` 球：`breathMask.y = 80 - int(breathMask.height * 比例)`
##   · `MBar.as:141` 条：`bar.x = barBg.x + ((barBg.width - bar.width) >> 1) - int(bar.width*(1-比例))`
##     （`BreathBarF`：barBg 在 (0,2) 宽 81、bar 在 (0,2) 宽 81、maskMc 在 (3,5) 宽 75）
##   · `MBar.as:158` 条上那行字 = `当前 + "/" + 上限`（不是百分比）
##   · `UIConfig.as:910` `ZQ_MAX = 500000`
##   · `BreathPane1.as:36-55` 收起版四颗 17×17 小钮在 x=0/18/45/63、y=15

const 出 := "res://测试/截图/追踪栏/精华容器行为.txt"
const 面板场景 := "res://场景/界面/技能面板.tscn"
const 上限 := 500000

var 日志: Array[String] = []
var 判 := 0
var 红 := 0
var 收 := false
var 存前 := PackedByteArray()


func _判(过: bool, 说: String) -> void:
	判 += 1
	日志.append("%s %s" % ["ok " if 过 else "!!红", 说])
	if not 过:
		红 += 1
	_写()


func _步(说: String) -> void:
	日志.append("· " + 说)
	_写()


func _写() -> void:
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(日志) + "\n")
		f.close()


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


func _看门狗() -> void:
	var 截止 := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < 截止:
		if not 日志.is_empty() and str(日志[日志.size() - 1]).begins_with("汇"):
			return
		await create_timer(0.2).timeout
	if 收:
		return
	_判(false, "看门狗：120 秒没跑到汇总（看最后一条停在哪一步）")
	_尾()


func _initialize() -> void:
	call_deferred("_跑")
	call_deferred("_看门狗")


## 把一件东西的"可见 + 矩形 + 贴图区域"打包成一行，判据与日志读**同一份**（防"打印读 A、判据读 B"）。
func _描(件: CanvasItem) -> String:
	if 件 == null:
		return "<缺件>"
	var 区 := ""
	if 件 is TextureRect and (件 as TextureRect).texture is AtlasTexture:
		var r := ((件 as TextureRect).texture as AtlasTexture).region
		区 = " region=(%.0f,%.0f,%.0f,%.0f)" % [r.position.x, r.position.y, r.size.x, r.size.y]
	return "visible=%s rect=(%.0f,%.0f,%.0f,%.0f)%s" % [
			str(件.visible), (件 as Control).offset_left, (件 as Control).offset_top,
			(件 as Control).offset_right, (件 as Control).offset_bottom, 区]


func _跑() -> void:
	root.size = Vector2i(960, 560)
	await _帧(1)
	## 存档基线要在**单例启动之后**取：跨天首次启动时 `游戏会话._reset_daily_quests_if_needed()`
	## 会按日重置并落一次盘（产品行为，不是本门写的）。基线取在启动前 ⇒ 每天第一次跑都假红。
	存前 = _字节("user://玩家数据.json")
	var 会: Node = root.get_node_or_null("GameSession")
	_判(会 != null, "拿得到 GameSession 单例")
	if 会 == null:
		_尾()
		return
	var 景: Node = (load(面板场景) as PackedScene).instantiate()
	root.add_child(景)
	await _帧(10)
	var 栏 := 景.get_node_or_null("技能栏") as Control
	_判(栏 != null, "技能栏在")
	var 箭头 := 栏.get_node_or_null("ChakraCoreArrow") as TextureButton if 栏 != null else null
	var 收起 := 栏.get_node_or_null("精华收起") as Control if 栏 != null else null
	var 球 := 栏.get_node_or_null("BreathContainer") as TextureRect if 栏 != null else null
	var 条 := 收起.get_node_or_null("填充") as TextureRect if 收起 != null else null
	var 数 := 收起.get_node_or_null("数值") as Label if 收起 != null else null
	# ── ① 折叠钮**得是颗按钮**（用户报的"点了没反应"第一层根因：它以前是 TextureRect + mouse_filter=IGNORE）
	_判(箭头 != null, "折叠钮 ChakraCoreArrow 在场景里")
	_判(箭头 != null and 箭头 is TextureButton,
			"折叠钮是 TextureButton（不是画上去的 TextureRect）—— 实得 %s" % (箭头.get_class() if 箭头 != null else "null"))
	_判(箭头 != null and 箭头.mouse_filter == Control.MOUSE_FILTER_STOP,
			"折叠钮吃点击（mouse_filter=STOP）—— 实得 %s" % str(箭头.mouse_filter if 箭头 != null else -1))
	_判(箭头 != null and 箭头.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
			"悬上去是手型（原版 MButton3.init 的 buttonMode=useHandCursor）—— 实得 %s" % str(
				箭头.mouse_default_cursor_shape if 箭头 != null else -1))
	_判(箭头 != null and 箭头.texture_normal != null
			and String(箭头.texture_normal.resource_path).contains("精华折叠钮"),
			"常态皮 = 原版 ArrowBtnF 那张（实得 %s）" % (
				String(箭头.texture_normal.resource_path).get_file() if 箭头 != null and 箭头.texture_normal != null else "无"))
	# ── ② 两版布局都在场景里、默认展开（`MenuPane.as:105`）
	## 先喂半满：`BreathContainer` 那一层在 zq=0 时**本来就该隐形**（露出高度 0），
	## 拿"起步可见"去判它会红一条与本缺陷无关的假红。
	会.player_stats["zq"] = int(上限 * 0.5)
	景.call("_画精华")
	var 展开件: Array = []
	for 名 in ["OriginalChakraCore", "BreathContainer", "ChakraCoreTrim",
			"打坐Button", "宠物Button", "闭关经验Button", "挂机Button"]:
		var 件 := 栏.get_node_or_null(名)
		_判(件 != null and (件 as CanvasItem).visible,
				"展开那一版的件在且起步可见：%s（%s）" % [名, _描(件 as CanvasItem)])
		if 件 != null:
			展开件.append(件)
	_判(收起 != null, "收起那一版 `精华收起` 在场景里（不是运行期才建）")
	_判(收起 != null and not 收起.visible, "起步收起版不可见（原版 breathPane1.visible=false）")
	_判(条 != null and 数 != null, "收起版里有 `填充` 与 `数值` 两枚（MBar 的 bar 与 tf）")
	## 身份判据 = 原版那四句提示文案（`CN.MENU_PRACTISE_BTN_TIP_TEXT_1..4` + "，快速键：无"）。
	## 10-12 #185 之前这里填的是我们自造的两个字（"打坐"/"宠物"…），改成原版原句；
	## 逐颗动作的对错归 `测试/那一排按钮回归测试.gd`，本门只管"这一枚是谁、在不在原位"。
	const 那一排提示 := {
		"坐Button": "打坐/取消打坐，快速键：无",
		"附Button": "通灵附身/取消附身，快速键：无",
		"修Button": "领取修行收益，快速键：无",
		"挂Button": "挂机/取消挂机，快速键：无",
	}
	for 名 in ["坐Button", "附Button", "修Button", "挂Button"]:
		var 钮 := 收起.get_node_or_null(名) as TextureButton if 收起 != null else null
		var 期望 := String(那一排提示[名])
		_判(钮 != null and String(钮.tooltip_text) == 期望,
				"收起版第 %s 枚 = %s（原版 BreathPane1 的 x=0/18/45/63 那一排）—— 实得 %s" % [
					名, 期望,
					("\"%s\"" % 钮.tooltip_text) if 钮 != null else "查无"])
	_判(收起 != null and absf(收起.offset_left - 443.0) < 0.5 and absf(收起.offset_top - 52.0) < 0.5,
			"收起版坐在 (443,52)（原版 breathPane1 在 MenuPane (454,52)，本栏 menuBg 左移 11）—— 实得 (%.0f,%.0f)" % [
				收起.offset_left if 收起 != null else -1.0, 收起.offset_top if 收起 != null else -1.0])

	# ── ③ 数值喂进去：两版都按算式重画（`setBreath` 两版都喂）
	会.player_stats["zq"] = int(上限 * 0.5)
	景.call("_画精华")
	_步("zq=半满(250000) 展开态：" + _描(球) + " ／ 条：" + _描(条))
	_判(球 != null and absf(球.offset_top - 51.0) < 0.5 and absf(球.offset_bottom - 91.0) < 0.5,
			"半满的球从**底部**露 40px：offset_top 应 = 11+80-40 = 51、bottom = 91（实得 %s）" % _描(球))
	_判(球 != null and (球.texture as AtlasTexture) != null
			and absf((球.texture as AtlasTexture).region.position.y - 40.0) < 0.5,
			"取的是贴图 y=40 起那一条（`breathMask.y = 80 - int(80*比例)`）—— 实得 %s" % _描(球))
	_判(条 != null and absf(条.offset_right - 41.0) < 0.5,
			"半满的条可见宽 = clamp(81-40,3,78)-3 = 38 ⇒ offset_right = 3+38 = 41（实得 %s）" % _描(条))
	_判(条 != null and (条.texture as AtlasTexture) != null
			and absf((条.texture as AtlasTexture).region.position.x - 43.0) < 0.5,
			"条的贴图从 x=3+40=43 取（bar **左移**、透过窗口露出右边那截）—— 实得 %s" % _描(条))
	_判(数 != null and 数.text == "250000/%d" % 上限,
			"条上那行字 = `当前/上限`（`MBar.as:158`，不是百分比）—— 实得「%s」" % (数.text if 数 != null else ""))

	会.player_stats["zq"] = 上限
	景.call("_画精华")
	_判(球 != null and absf(球.offset_top - 11.0) < 0.5 and 球.visible,
			"满的球整条带都露出来（top 回到 11）：%s" % _描(球))
	_判(条 != null and absf(条.offset_right - 78.0) < 0.5,
			"满的条 = 75 宽（maskMc 本身只有 75）：%s" % _描(条))
	会.player_stats["zq"] = 0
	景.call("_画精华")
	_判(球 != null and not 球.visible, "空的球不露内容（原版这一刻是**灰底**，紫色那一层高度 0）：%s" % _描(球))
	_判(条 != null and not 条.visible, "空的条不画：%s" % _描(条))
	会.player_stats["zq"] = int(上限 * 0.5)
	景.call("_画精华")

	# ── ④ **真点**折叠钮：两版恰好互换（`MenuPane.as:119-123`）
	var 位 := 箭头.get_global_rect().get_center() if 箭头 != null else Vector2.ZERO
	_步("往 (%.0f,%.0f) 发真鼠标事件点折叠钮" % [位.x, 位.y])
	var 鼠 := InputEventMouseMotion.new()
	## ⚠ 命中判定读的是 **`position`**（视口局部），只设 `global_position` 会落在 (0,0) 上；
	## 而 `global_position` 不设的话 `push_input` 在某些路径上又拿不到屏幕坐标 ⇒ 两个都写。
	## 第一版只写了 `global_position` 还除了一个 `root.size`（那是像素坐标，不是 0..1）⇒
	## 拾取恒空，后面"没换皮/没翻面"那五条全是这一行带来的假红。
	鼠.position = 位
	鼠.global_position = 位
	root.push_input(鼠)
	await _帧(2)
	_判(箭头 != null and root.gui_get_hovered_control() == 箭头,
			"悬停拾取到的就是折叠钮（不是被别的件吃掉）—— 实得 %s" % str(root.gui_get_hovered_control()))
	_判(箭头 != null and String(箭头.texture_normal.resource_path).contains("悬停"),
			"悬停换的是**烘出来的 +30 皮**（不是 modulate 染色）—— 实得 %s" % String(箭头.texture_normal.resource_path).get_file())
	var 按下 := InputEventMouseButton.new()
	按下.button_index = MOUSE_BUTTON_LEFT
	按下.position = 位
	按下.global_position = 位
	按下.pressed = true
	root.push_input(按下)
	await _帧(2)
	_判(箭头 != null and String(箭头.texture_normal.resource_path).contains("按下"),
			"按住那一步换的是 −40 皮 —— 实得 %s" % String(箭头.texture_normal.resource_path).get_file())
	按下.pressed = false
	root.push_input(按下)
	await _帧(3)
	_判(箭头 != null and not String(箭头.texture_normal.resource_path).contains("悬停")
			and not String(箭头.texture_normal.resource_path).contains("按下"),
			"**松手回常态**（原版 MButton3.as:103-108 回 STATE_UP，不是回 hover）—— 实得 %s" % String(箭头.texture_normal.resource_path).get_file())
	_判(收起 != null and 收起.visible, "点完 ⇒ 收起版可见了")
	var 都隐 := true
	for 件 in 展开件:
		if (件 as CanvasItem).visible:
			都隐 = false
	_判(都隐, "点完 ⇒ 展开那一版**整版**都隐掉（球三层 + 四颗大钮一起走）")
	_判(箭头 != null and String(箭头.tooltip_text) == "展开精华容器",
			"提示语跟着翻面（实得「%s」）" % (箭头.tooltip_text if 箭头 != null else ""))
	_判(条 != null and 条.visible and absf(条.offset_right - 41.0) < 0.5,
			"收起态下那条仍然按同一算式画：%s" % _描(条))
	# 反向：再点一次必须回得去（不是单向隐藏）
	按下.pressed = true			# ⚠ 上一轮收尾把它留在了 false —— 不重新按下去，这一腿就是"发了两次松手"
	root.push_input(按下)
	await _帧(2)
	按下.pressed = false
	root.push_input(按下)
	await _帧(3)
	_判(收起 != null and not 收起.visible, "再点一次 ⇒ 收起版又隐掉")
	var 都显 := true
	for 件 in 展开件:
		if not (件 as CanvasItem).visible:
			都显 = false
	_判(都显 and 球 != null and 球.visible, "再点一次 ⇒ 展开那一版整版回来（球也按半满重画）：%s" % _描(球))
	# ── ⑥ 悬停精华球 ⇒ `MToolTipText` 四行说明（2026-10-20 用户报「查克拉精华框显示不对」）
	## 原版 `BreathPane.as:44` 把提示框挂在 **`breath_background`**（我们的 OriginalChakraCore）上，
	## `:113-118 setData` 每次刷 `toolTip.text = CN.replaceString(CN.MENU_JINGHUA_TIP, 当前, ZQ_MAX, ZQ_MAX)`。
	## 以前球底是 IGNORE、也没接工具提示 ⇒ 这个框**从来没出现过**。
	var 球底 := 栏.get_node_or_null("OriginalChakraCore") as Control
	_判(球底 != null and 球底.mouse_filter != Control.MOUSE_FILTER_IGNORE,
			"球底必须吃悬停（`BreathPane.as:43` 只关了 breathContainer/breathMask）—— 实得 %s" % str(
				球底.mouse_filter if 球底 != null else -1))
	if 球底 != null:
		球底.mouse_entered.emit()
		await _帧(2)
	var 提示 := 景.get_node_or_null("精华提示框") as Control
	_判(提示 != null and 提示.visible, "悬停球底 ⇒ 弹「查克拉精华」提示框")
	var 提文 := ""
	if 提示 != null:
		var 文节 := 提示.get_node_or_null("文字") as RichTextLabel
		提文 = 文节.get_parsed_text() if 文节 != null else ""
	_判(提文.contains("当前查克拉精华：%d/%d" % [int(上限 * 0.5), 上限]),
			"提示第一行是「当前查克拉精华：250000/500000」（实得「%s」）" % 提文)
	_判(提文.contains("通过打坐等途径获得的查克拉精华将保存于此，上限为%d" % 上限), "第二行 = 上限说明")
	_判(提文.contains("查克拉精华可用于开通八门穴道，升级忍术等操作"), "第三行 = 用途")
	_判(提文.contains("双修打坐与双倍查克拉精华符可以增加同时间内查克拉精华的收益"), "第四行 = 双修/双倍符")
	if 球底 != null:
		球底.mouse_exited.emit()
		await _帧(2)
	_判(提示 == null or not 提示.visible, "移开 ⇒ 提示框收起")
	_尾()


func _尾() -> void:
	if 收:
		return
	收 = true
	_判(_字节("user://玩家数据.json") == 存前, "门不许动存档（本门全程不调任何落盘接口）")
	日志.append("汇：判 %d 条 / 红 %d 条" % [判, 红])
	_写()
	for 行 in 日志:
		print(行)
	quit(0 if 红 == 0 else 1)
