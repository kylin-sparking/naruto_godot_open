extends SceneTree

## 油女志乃「护送任务」（原版 `husong/HuSongQuestWindow` 578×342）的**行为门**。
##
## 逐件几何不在这里 —— `测试/原版服务窗回归测试.gd` 已经把 43 件逐个比
## `数据/界面/护送任务_期望.json`，而且它会**重跑生成器**比对场景（手改 .tscn 立刻红）。
## 这里量的是那一族门看不见的事：
##   ① **内容底顶 30**：`HuSongQuestWindow.as:114` `setContentBgPos(CONTENT_GAP, 30)` 把
##      UIWindow 默认的 y=38 抬到 30 ⇒ 尺寸表要 `内容底: true` + `内容底顶: 30`。
##      这条**只有运行期看得见**：宿主 `功能窗口.gd` 那段是运行期设的，几何门只读盘。
##   ② **五枚奖格的层序与显形**：`HuSongItemCell` 的 addChild 序是 底(0) → 图标(1) → 名(2)
##      → 选中框(3)（`:57-58` 先 addChild(title)，再 `addChildAt(bg,0)`、`addChildAt(mc,1)`、
##      `addChildAt(selectedBg, numChildren)`）；选中框 `visible = (richDegree == id)`（`:93`）
##      ⇒ 离线**五枚全隐**，而且格**没有 CLICK** —— 它是"当前品质"的指示器，不是可选项。
##   ③ **复选项 ↔ 下拉联动**：`:241` `hsComboBox.enabled = hsCheckBox.selected` ⇒ 开窗时下拉
##      **禁用**；真点勾选才放开（`autoHankdler:66-69` 只做这一件事）。
##   ④ **下拉是反序**：`HUSONG_PINZHI_NAME.split("#").reverse()` ⇒ [S,A,B,C,D]，
##      而五枚格名那排是正序 [D,C,B,A,S] ⇒ 两处顺序相反是原版的形状，谁"顺手统一"这里就红。
##   ⑤ **规则 tooltip**：`:178` `MToolTipText.createToolTip(stage, ruleTf, HUSONG_RULE_DESC)`
##      ⇒ 悬停出七条规则、移开收掉。⚠ `RichTextLabel` 默认 `mouse_filter = IGNORE` ⇒
##      控制器不改成 STOP 就一次悬停都收不到（这条是"门绿着但功能没有"的经典形状）。
##   ⑥ **两支未接只回显**：刷新任务 = `MIXIN 2325` 子命令 1、开启护送 = 子命令 2
##      （`QuestProcessor.as:186-192` + `:229-232` / `:122-125`）⇒ 一条帧都不发。
##   ⑦ **不连背包**：`UIMain2.as:3675-3678` 只是 `setDOShow(HUSONGQUEST_WINDOW)`，
##      **没有** `centerTwoWindow` ⇒ 这扇不许进 `窗口管理.伴随背包`（与 勾玉炼制 正相反）。
##   ⑧ **编辑器 == 运行期**：五枚选中框的 `visible = false`、免费刷新数的空文本
##      都读 `.tscn` 文本比对（读运行期值等于自证）。
##
## ⚠ 三条硬口径（都是这个工程踩过的）：
##   · `push_input` 前先钉 `root.size`（无头默认视口拿不到 GUI 命中 ⇒ 点了静默不生效）；
##   · 悬停要**分两跳**（同帧两条 MouseMotion 视口只按最后一条做拾取，大距离瞬移不触发
##     `mouse_entered`）；改状态与断言之间隔 3 帧；
##   · 本门不落存档：跑前记 `user://玩家数据.json` 的字节、跑完断言**没变**。
##
## 运行：Godot --headless --path . --script res://测试/护送任务页回归测试.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 页名 := "护送任务"
const 场景路 := "res://场景/界面/窗口/护送/护送任务窗.tscn"
const 提示场景路 := "res://场景/界面/窗口/护送/护送提示窗.tscn"
const 控制器 := preload("res://脚本/界面/窗口/护送任务窗.gd")
const 窗口管理路 := "res://脚本/界面/窗口管理.gd"

## `HUSONG_DOUBLE_INFO_TEXT` 逐字（原版 htmlText 的两段 `<font color='#00ff00'>` ⇒ BBCode）。
const 提示文真值 := "双倍护送活动已开启，每日[color=#00ff00]20:00-20:30[/color]护送将获得双倍奖励，" \
		+ "赶快前往[color=#00ff00]木叶-油女志乃[/color]接取护送任务吧！"

const 格名 := ["D级", "C级", "B级", "A级", "S级"]		# HUSONG_PINZHI_NAME 正序
const 下拉名 := ["S级", "A级", "B级", "C级", "D级"]		# ⚠ .reverse() 之后的下拉序
const 格色 := [Color(1, 1, 1), Color(0, 1, 0), Color(0.117647, 0.564706, 1),
		Color(1, 0.490196, 0.815686), Color(1, 0.568627, 0)]	# `HuSongItemCell.as:26`
const 橙 := Color(1, 0.568627, 0)					# `MCheckBox.as:13` upTextColor #ff9100
const 蓝 := Color(0.117647, 0.564706, 1)				# UIConfig.UI_BLUE #1e90ff
const 双倍 := "每天20:00-20:30护送有双倍奖励，被打劫后还能获得一半奖励。"	# HUSONG_MIXIN_DESC
const 行路 := ["时间条", "经验条", "精华条", "气血条"]
const 行文 := ["护送时间：", "护送奖励：", "", "气血加成："]	# 精华那行整条都是数字 ⇒ 空

var 场景: Node
var 管: Node
var 红数 := 0
var 日志: Array[String] = []
var 通知记录: Array[String] = []
var 存档前 := ""
var 鼠位 := Vector2.ZERO


func _记(过: bool, 文: String) -> void:
	if not 过:
		红数 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 文])


func _等(n: int) -> void:
	for _i in range(n):
		await process_frame


func _尾通知() -> String:
	return 通知记录[通知记录.size() - 1] if not 通知记录.is_empty() else ""


func _清通知() -> void:
	通知记录.clear()


func _窗() -> Node:
	return 管._窗口们.get(页名) as Node


func _页() -> Control:
	var 窗 := _窗()
	if 窗 == null:
		return null
	var 出: Control = null
	for 子 in (窗.get_node("遮罩/主窗口/页面容器") as Control).get_children():
		if 子 is Control:
			出 = 子 as Control
	return 出


## 分两跳移进目标矩形中心：同帧连发两条 MouseMotion 时视口只按最后一条做拾取 ⇒
## 大距离瞬移不触发 `mouse_entered`（`flash-mbutton3-state-skins` 坑①）。
func 悬停(位置: Vector2) -> void:
	var 中 := (鼠位 + 位置) * 0.5
	var 移 := InputEventMouseMotion.new()
	移.position = 中
	移.global_position = 中
	root.push_input(移)
	鼠位 = 中
	await _等(2)
	移 = InputEventMouseMotion.new()
	移.position = 位置
	移.global_position = 位置
	root.push_input(移)
	鼠位 = 位置
	await _等(3)


func 点(位置: Vector2) -> void:
	await 悬停(位置)
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 位置
	按.global_position = 位置
	root.push_input(按)
	await _等(2)
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 位置
	放.global_position = 位置
	root.push_input(放)
	await _等(3)


func 点钮(钮: Control) -> void:
	await 点(钮.get_global_rect().get_center())


func _存档字节() -> String:
	var f := FileAccess.open("user://玩家数据.json", FileAccess.READ)
	return "" if f == null else f.get_as_text()


## 取 `.tscn` 里某个节点自己的属性块（到下一个 `[node ` 为止）—— 烘值只能读文本。
func _节(文: String, 名: String) -> String:
	var 头 := 文.find("[node name=\"%s\"" % 名)
	if 头 < 0:
		return ""
	var 尾 := 文.find("[node ", 头 + 10)
	return 文.substr(头, 尾 - 头) if 尾 > 头 else 文.substr(头)


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)		# ⚠ 不钉这个，无头视口拿不到 GUI 命中 ⇒ 点了静默不生效
	存档前 = _存档字节()
	var 会 = root.get_node_or_null("/root/GameSession")
	if 会 != null and 会.has_signal("notification_requested"):
		会.notification_requested.connect(func(文本: String) -> void: 通知记录.append(文本))
	控制器.新会话()
	场景 = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _等(6)
	管 = 场景.get_node_or_null("窗口管理")
	if 管 == null:
		收尾("地图场景下没有 窗口管理")
		return
	管.call("全部关闭")
	管.call("打开", 页名)
	await _等(5)
	await _量开窗()
	await _量奖格()
	await _量静态件()
	await _量运行期四件()
	await _量勾选联动()
	await _量规则提示()
	await _量两支()
	await _量不成对()
	await _量烘值()
	await _量提示窗()
	收尾()


func 收尾(致命: String = "") -> void:
	if 致命 != "":
		日志.append("!! %s" % 致命)
		红数 += 1
	var 现 := _存档字节()
	_记(现 == 存档前, "跑完 `user://玩家数据.json` **字节没变**（本门不落存档；变了会让邻居门次日假红）")
	if 现 != 存档前:
		日志.append("   ⇒ 说明这一族按钮里有支会写档：查 `_set_check` / `存档.保存()` 的调用链")
	for 一 in 日志:
		print(一)
	print("护送任务页回归：%s（红 %d 项）" % ["通过" if 红数 == 0 else "不通过", 红数])
	quit(1 if 红数 > 0 else 0)


## ──  开窗：外框 / 标题 / 内容底顶 30 ────────────────────────────────────────
func _量开窗() -> void:
	日志.append("=== 开窗（578×342 + 内容底顶 30）===")
	var 窗 := _窗()
	_记(窗 != null, "落地页「%s」开出来了（入口 = 志乃的 selection 行，`QuestDialog.as:107-110` 本地直开）" % 页名)
	if 窗 == null:
		return
	var 页 := _页()
	_记(页 != null and String(页.name) == "原版护送任务内容", "页根 = %s" % (页.name if 页 != null else "无"))
	if 页 == null:
		return
	_记(String(窗._title.text) == "护送任务",
			"标题「护送任务」（`:63` HUSONG_WINDOW_TITLE；⚠ 与 `HuSongNoticeWindow.as:19` 同一个键）")
	_记(absf(窗._window.size.x - 578.0) < 0.6 and absf(窗._window.size.y - 342.0) < 0.6,
			"外框 578×342（`:62` `super(578,342,true)`），实测 %.0f×%.0f"
			% [窗._window.size.x, 窗._window.size.y])
	# 第三参 true ⇒ 宿主画内容底；但 y 被 `:114` 抬到 30 ⇒ 钉 `内容底顶` 这条新键真的生效了
	var 底 = 窗._content_bg
	_记(底 != null and bool(底.visible), "宿主的 内容底 显形（AS3 第三参 true）")
	if 底 != null:
		var 皮: StyleBoxTexture = (底 as Control).get_theme_stylebox("panel") as StyleBoxTexture
		var 皮名 := String(皮.texture.resource_path).get_file() if 皮 != null and 皮.texture != null else "无"
		_记(皮名 == "内容面板.png",
				"内容底皮 = 内容面板.png（`UIWindow.as:36` `new MYellow_background()`），实测「%s」" % 皮名)
		_记(absf((底 as Control).position.x - 8.0) < 0.6 and absf((底 as Control).position.y - 30.0) < 0.6,
				"内容底顶 = **(8,30)** 而不是默认 (8,38)（`:114` setContentBgPos(CONTENT_GAP,30)），实测 %s"
						% str((底 as Control).position))
		_记(absf((底 as Control).size.x - 562.0) < 0.6 and absf((底 as Control).size.y - 274.0) < 0.6,
				"内容底 562×274（`UIWindow.as:38` 宽−2·8 / 高−68），实测 %.0f×%.0f"
				% [(底 as Control).size.x, (底 as Control).size.y])


## ── ② 五枚奖格：层序 / 摆位 / 名与色 / 选中框全隐 ─────────────────────────────
func _量奖格() -> void:
	日志.append("=== 五枚奖卡格（HuSongItemCell）===")
	var 页 := _页()
	var 序对 := true
	var 位对 := true
	var 名对 := true
	var 色对 := true
	var 隐对 := true
	var 皮对 := true
	for i in 5:
		var 格 := 页.get_node("奖格%d" % i) as Control
		var 名们: Array[String] = []
		for 子 in 格.get_children():
			名们.append(String(子.name))
		序对 = 序对 and 名们 == ["奖格%d底" % i, "奖格%d图标" % i, "奖格%d名" % i, "奖格%d选中" % i]
		位对 = 位对 and absf(格.position.x - (28.0 + i * 106.0)) < 0.6 and absf(格.position.y - 46.0) < 0.6
		var 字 := 格.get_node("奖格%d名" % i) as Label
		var 选 := 格.get_node("奖格%d选中" % i) as CanvasItem
		名对 = 名对 and 字.text == 格名[i]
		色对 = 色对 and 字.get_theme_color(&"font_color") == 格色[i]
		隐对 = 隐对 and not bool(选.visible)
		var 底 := 格.get_node("奖格%d底" % i) as NinePatchRect
		var 图 := 格.get_node("奖格%d图标" % i) as TextureRect
		皮对 = 皮对 and String(底.texture.resource_path).get_file() == "奖卡底.png" \
				and String(图.texture.resource_path).get_file() == "奖卡图标%d.png" % i \
				and String(选.texture.resource_path).get_file() == "奖卡选中框.png" \
				and absf(选.position.x + 7.0) < 0.6 and absf(选.size.x - 106.0) < 0.6
	_记(序对, "每格层序 = 底→图标→名→选中框（`HuSongItemCell.as:49` addChild(title)、`:96` addChildAt(bg,0)、`:64` addChildAt(mc,1)、`:95` addChildAt(selectedBg,numChildren)）")
	_记(位对, "格 i 在页面 (28+106i, 46)（`:148-152` x = i*106 + 18 + 10、y = 40+25+10，整框 ⇒ −29）")
	_记(名对, "五枚名逐字 = %s（HUSONG_PINZHI_NAME 正序）" % str(格名))
	_记(色对, "名色 = 白/绿/#1e90ff/#ff7dd0/#ff9100（`:26` titleColor 那五档 UI_WHITE..UI_ORANGE）")
	_记(皮对, "皮 = 奖卡底 96 / 奖卡图标i 90 @(3,3) / 奖卡选中框 106 @(−7,−7)（UISwf_HuSong tag3/9-i/tag6）")
	_记(隐对, "五枚选中框**全隐**（`:93` visible = (richDegree == id)；离线没有 richDegree ⇒ 不假造，而且它不是可点项 —— 全文没有 CLICK 监听）")


## ── ③ 静态件文案逐字 + 数字件为空 ────────────────────────────────────────────
func _量静态件() -> void:
	日志.append("=== 静态件（说明 / 四行奖励 / 居中）===")
	var 页 := _页()
	var 级 := 页.get_node("等级文本") as RichTextLabel
	_记(级.text == "当前护送等级：",
			"等级文本烘到冒号为止（`:158` HUSONG_CURRLEVEL 的 %%1 是运行期数字 ⇒ 离线不假造），实测「%s」" % 级.text)
	_记(int(级.horizontal_alignment) == 1, "等级文本居中（`:157` align=\"center\"）")
	var 说 := 页.get_node("双倍说明") as RichTextLabel
	_记(说.text == 双倍, "双倍说明逐字 = HUSONG_MIXIN_DESC（:167）")
	_记(int(说.get_theme_constant(&"line_separation")) == 6,
			"双倍说明行距 6 = AS3 leading 4 + 2（`:166` leading=4），实测 %d"
			% int(说.get_theme_constant(&"line_separation")))
	var 文对 := true
	for i in 行路.size():
		var 件 := 页.get_node(行路[i]) as RichTextLabel
		文对 = 文对 and 件.text == 行文[i]
	_记(文对, "四行奖励 = %s（`:180-219`，精华那行整条是 %%1 ⇒ 空文本）" % str(行文))
	var 免 := 页.get_node("免费刷新数") as RichTextLabel
	_记(免.text == "",
			"免费刷新数**建时不设文**（`:250-255` 只 setSize/setPosition/align；文案只在 updateview(:310) 由"
			+ " HUSONG_FREE_REFUSH_CNT 填）⇒ 离线空，不把模板里的 %1 显示出来")
	var 止 := 页.get_node("为止") as Label
	_记(止.text == "为止", "「为止」逐字（`:247` HUSONG_COMBOBOX_TXT）⇒ 连读「刷出 [S级] 为止」")
	var 条 := 页.get_node("等级条底") as TextureRect
	_记(String(条.texture.resource_path).get_file() == "列表分隔条2.png" \
			and int(条.expand_mode) == 1 and int(条.stretch_mode) == 0,
			"等级条底 = 列表分隔条2.png（charId 841，原生 431×28、**无九宫格** ⇒ 整帧非等比 ⇒ 必须 expand_mode=1）")
	var 钮 := 页.get_node("护送规则钮") as RichTextLabel
	_记(钮.get_theme_color(&"default_color") == 蓝, "规则钮字色 #1e90ff（`:175` UI_BLUE）")
	_记(String(钮.text).contains("[u]"), "规则钮带下划线（`:176` underline=true ⇒ Godot 走 BBCode [u]）")
	_记(int(钮.mouse_filter) == Control.MOUSE_FILTER_STOP \
			and 钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
			"规则钮吃鼠标 + 手型（`:177` useHandCursor=buttonMode=true；⚠ RichTextLabel 默认 IGNORE ⇒"
			+ " 不改 STOP 悬停一次都收不到）")


## ──  运行期长出来的四件（复选项 / 下拉 / tooltip 位 / 两颗钮的提示） ──────────
func _量运行期四件() -> void:
	日志.append("=== 运行期件（复选项 + 下拉）===")
	var 页 := _页()
	var 勾槽 := 页.get_node("自动刷新槽") as Control
	var 拉槽 := 页.get_node("品质下拉槽") as Control
	_记(勾槽.get_child_count() == 1, "自动刷新槽里长出 1 件复选项（`:226-231` MCheckBoxF）")
	_记(拉槽.get_child_count() == 1, "品质下拉槽里长出 1 件下拉（`:232-241` MComboBox）")
	if 勾槽.get_child_count() == 0 or 拉槽.get_child_count() == 0:
		return
	var 件 := 勾槽.get_child(0) as Control
	var 字 := 件.get_node("文本") as Label
	_记(字.text == "刷出", "复选项文字 = HUSONG_CHECK_TXT「刷出」")
	_记(字.get_theme_color(&"font_color") == 橙,
			"复选项字色 #ff9100（`MCheckBox.as:13` upTextColor=16748800，**不是** MButton3 的 #fcf49c）")
	_记(absf(件.size.x - 45.0) < 0.6 and absf(件.size.y - 19.0) < 0.6,
			"复选项 45×19 = 皮宽19 + 2 + 文字宽24 / 皮高19（`MCheckBox.as:81-91` 的**九宫格**分支，`:12` isScale9Grid=true），实测 %.0f×%.0f" % [件.size.x, 件.size.y])
	_记(absf(字.position.x - 21.0) < 0.6 and absf(字.size.x - 24.0) < 0.6 \
			and 字.get_global_position().x + 字.size.x <= 页.get_global_position().x + 页.size.x + 0.6,
			("文字盒压回真值 (21, 实测字宽)（`MCheckBox.as:17-20` tf.x=皮宽+2、tf.width=实测字宽）——"
			+ "共用件 `原版复选项.tscn` 那条 155 宽是摆设置页长句的，照搬会伸出窗口右框 15px（`窗口布局体检` 抓到），实测 x=%.0f 宽=%.0f"
			+ "（2026-10-25 晚全局合成加粗回滚后字宽回到 24；中间短暂的 25 是全局 embolden 1.5 撑出来的；"
			+ " 皮宽 19 + 2 + 24 < 复选项烘的 45 ⇒ 不越框这条照旧）")
			% [字.position.x, 字.size.x])
	var 拉 := 拉槽.get_child(0) as OptionButton
	var 项: Array[String] = []
	for i in 拉.item_count:
		项.append(拉.get_item_text(i))
	_记(项 == 下拉名, "下拉五项 = %s（`:234-235` split(\"#\").reverse()）—— 与格名那排**反序**是原版的形状，实测 %s"
			% [str(下拉名), str(项)])
	_记(bool(拉.disabled), "开窗时下拉**禁用**（`:241` enabled = hsCheckBox.selected，勾选默认 false）")
	_记(not bool((件.get_node("标记") as CanvasItem).visible), "复选项默认未勾（MCheckBox selected 初值 false）")


## ──  真点勾选 ↔ 下拉联动（`autoHankdler:66-69` 只做这一件事） ────────────────
func _量勾选联动() -> void:
	日志.append("=== 真点复选项 ⇒ 下拉解禁（再点回档）===")
	var 页 := _页()
	var 件 := (页.get_node("自动刷新槽") as Control).get_child(0) as Control
	var 拉 := (页.get_node("品质下拉槽") as Control).get_child(0) as OptionButton
	var 标 := 件.get_node("标记") as CanvasItem
	await 点钮(件.get_node("点击区域") as Button)
	_记(bool(标.visible) and not bool(拉.disabled) and 控制器.勾选态(),
			"点下去：标记显形 + 下拉 enabled + 会话态 true（`:68` hsComboBox.enabled = selected）")
	await 点钮(件.get_node("点击区域") as Button)
	_记(not bool(标.visible) and bool(拉.disabled) and not 控制器.勾选态(),
			"再点回档：标记隐 + 下拉 disabled（MCheckBox `onClick:66-70` 自己翻 selected）")


## ──  悬停规则钮出 tooltip、移开收掉 ─────────────────────────────────────────
func _量规则提示() -> void:
	日志.append("=== 悬停「护送规则」出 tooltip ===")
	var 页 := _页()
	var 钮 := 页.get_node("护送规则钮") as RichTextLabel
	await 悬停(钮.get_global_rect().get_center())
	var 框 := 页.get_node_or_null("文字提示_护送规则") as CanvasItem
	_记(框 != null and bool(框.visible), "悬停时提示条显形（`:178` MToolTipText.createToolTip）")
	if 框 != null:
		var 文 := (框.get_node("文字") as RichTextLabel).text if 框.get_node_or_null("文字") is RichTextLabel else ""
		_记(String(文).contains("1.本活动全天均可完成护送任务。") \
				and String(文).contains("7.护送中不能使用二段跳，瞬移，隐身等技能。"),
				"提示条含 HUSONG_RULE_DESC 的首尾两条（七条逐字、\\n 转 [br]），实测长度 %d" % String(文).length())
	await 悬停(页.get_node("双倍说明").get_global_rect().get_center())
	_记(框 == null or not bool(框.visible), "移开 ⇒ 提示条收掉（原版是 MOUSE_MOVE 驱动，不是常驻）")


## ── ⑦ 两支未接只回显，且点完不留自造状态 ─────────────────────────────────────
func _量两支() -> void:
	日志.append("=== 刷新任务 / 开启护送：只回显、不发帧 ===")
	var 页 := _页()
	_清通知()
	await 点钮(页.get_node("刷新钮") as Button)
	_记(_尾通知().contains("MIXIN 2325") and _尾通知().contains("子命令 1") and _尾通知().contains("已发")
			and not _尾通知().contains("未接"),
			"刷新任务 → 点名「已发 MIXIN 2325 子命令 1」（10-22 夜接上真上行），实测「%s」" % _尾通知())
	_清通知()
	await 点钮(页.get_node("开始钮") as Button)
	_记(_尾通知().contains("MIXIN 2325") and _尾通知().contains("子命令 2") and _尾通知().contains("已发")
			and not _尾通知().contains("未接"),
			"开启护送 → 点名「已发 MIXIN 2325 子命令 2」（10-22 夜接上真上行），实测「%s」" % _尾通知())
	var 隐对 := true
	for i in 5:
		隐对 = 隐对 and not bool((页.get_node("奖格%d/奖格%d选中" % [i, i]) as CanvasItem).visible)
	_记(隐对, "点完两支：五枚选中框**仍然全隐**（没自造 richDegree、没把哪枚点亮）")
	var 空对 := true
	for 路 in ["等级文本", "时间条", "经验条", "精华条", "气血条", "免费刷新数"]:
		var 件 := 页.get_node(路) as RichTextLabel
		空对 = 空对 and not String(件.text).contains("%1") and not String(件.text).contains("%2")
	_记(空对, "六处数字件里**没有 %1/%2 模板残留**（离线要么中文标签、要么空，不假造数）")


## ── ⑧ 这扇不连背包（与 勾玉炼制 正相反） ─────────────────────────────────────
func _量不成对() -> void:
	日志.append("=== 不连背包 ===")
	_记(管._窗口们.get("背包") == null,
			"开护送**没有**把背包一起开（`UIMain2.as:3675-3678` 只有 setDOShow，无 centerTwoWindow）")
	# const 只能从脚本资源的常量表里取（`get("伴随背包")` 拿不到 const）
	var 表: Dictionary = (load(窗口管理路) as GDScript).get_script_constant_map().get("伴随背包", {})
	_记(not 表.has(页名), "窗口管理.伴随背包 里没登记「护送任务」（登记了就是自造联动）")


## ── ⑨ 编辑器 == 运行期：读 .tscn 文本比对开屏态 ──────────────────────────────
func _量烘值() -> void:
	日志.append("=== 场景烘的开屏态 == 运行期第一帧（读 .tscn 文本）===")
	var 文 := FileAccess.get_file_as_string(场景路)
	_记(文.count("visible = false") >= 5,
			"五枚选中框在 .tscn 里就 `visible = false`（实测 %d 处）⇒ 编辑器里看到的=原版开窗那一帧"
			% 文.count("visible = false"))
	var 块 := _节(文, "免费刷新数")
	_记(块.contains("text = \"\""), "免费刷新数烘的是**空文本**（不是「今日剩余…」那种自造句，也不是 %1 模板）")
	_记(not 文.contains("[node name=\"品质下拉\"") and not 文.contains("[node name=\"复选_刷出\""),
			"下拉与复选项**不在场景里**（原版是 createChildren 运行期建的共用件）⇒ 由控制器长，槽只占位")
	_记(文.contains("奖卡图标4.png") and 文.contains("text = \"S级\""),
			"第五枚格（S级）的图标与名都烘在盘上（静态图离线就画）")
	var 名块 := _节(文, "奖格4名")
	_记(名块.contains("horizontal_alignment = 1") and 名块.contains("offset_top = 101.0"),
			"格名居中 + y=101（`HuSongItemCell.as:40-43` (5,101)、align=center），实测 %s"
			% ["√" if 名块.contains("horizontal_alignment = 1") else "缺"])


## ──  护送族第二扇：提示弹（HuSongNoticeWindow 300×170）+「前往护送」那颗钮 ────
func _量提示窗() -> void:
	日志.append("=== 护送提示窗（300×170，入口不是 NPC）===")
	管.call("打开", "护送提示")
	await _等(4)
	var 窗: Node = 管._窗口们.get("护送提示") as Node
	_记(窗 != null and bool(窗.call("已打开")), "按页名开得出「护送提示」（原版入口是地上那枚护送标记，未接）")
	if 窗 == null:
		return
	_记(String(窗._title.text) == "护送任务",
			"标题与主窗**一模一样**都叫「护送任务」（`:19` 与 `HuSongQuestWindow.as:63` 同一个语言键 HUSONG_WINDOW_TITLE）")
	_记(absf(窗._window.size.x - 300.0) < 0.6 and absf(窗._window.size.y - 170.0) < 0.6,
			"外框 300×170（`:18` `super(300,170,true)`），实测 %.0f×%.0f" % [窗._window.size.x, 窗._window.size.y])
	var 底: Control = 窗._content_bg as Control
	_记(底 != null and absf(底.position.y - 30.0) < 0.6 and absf(底.size.x - 284.0) < 0.6
			and absf(底.size.y - 102.0) < 0.6,
			"内容底 (8,30) 284×102 —— `:26` 同样把顶抬到 30（默认 38 会低 8px）、`UIWindow.as:38` 宽−16/高−68，实测 %s %s"
			% [str(底.position) if 底 != null else "无", str(底.size) if 底 != null else "无"])
	var 页: Control = null
	for 子 in (窗.get_node("遮罩/主窗口/页面容器") as Control).get_children():
		if 子 is Control:
			页 = 子 as Control
	_记(页 != null and String(页.name) == "原版护送提示内容", "页根 = %s" % (页.name if 页 != null else "无"))
	if 页 == null:
		return
	var 文 := 页.get_node("提示文") as RichTextLabel
	_记(文.text == 提示文真值, "提示文案**逐字** = HUSONG_DOUBLE_INFO_TEXT（两段绿字走 BBCode），实测「%s」" % 文.text)
	_记(int(文.horizontal_alignment) == 1 and int(文.get_theme_constant(&"line_separation")) == 6,
			"提示文居中 + 行距 6（`:34` algin=\"center\"、`:32` leading=4 ⇒ +2）")
	_记(absf(文.position.x - 16.0) < 0.6 and absf(文.position.y - 21.0) < 0.6 \
			and absf(文.size.x - 280.0) < 0.6 and absf(文.size.y - 72.0) < 0.6,
			"提示文 (16,50) 280×72 ⇒ 整框页 −29 = (16,21)（`:30-33` 那四条算式），实测 %s %s"
			% [str(文.position), str(文.size)])
	var 钮 := 页.get_node("前往钮") as Button
	_记(absf(钮.position.x - 119.5) < 0.6 and absf(钮.position.y - 109.0) < 0.6 \
			and absf(钮.size.x - 61.0) < 0.6 and absf(钮.size.y - 22.0) < 0.6,
			"前往钮 (119.5,138) 61×22 ⇒ 场景 (119.5,109)（`:41-43` (宽−61)/2、高−22−10），实测 %s %s"
			% [str(钮.position), str(钮.size)])
	_记(钮.text == "前往护送", "钮文字 = HUSONG_DOUBLE_BTN_TXT「前往护送」")
	_记(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "前往钮手型（MButtonF 继承 MButton3 的 buttonMode）")
	var 皮全 := true
	for 后 in ["", "_悬停", "_按下"]:
		皮全 = 皮全 and FileAccess.file_exists("res://素材/界面/原版窗口/护送/前往钮%s.png" % 后)
	_记(皮全, "前往钮三档皮在盘上（护送/前往钮[_悬停/_按下].png，61×22 预烘 +30/−40）")
	_清通知()
	await 点钮(钮)
	_记(_尾通知().contains("前往护送") and _尾通知().contains("未接") and _尾通知().contains("待点头"),
			"点「前往护送」→ 说清两支（收窗已做 / 自动寻路未接），实测「%s」" % _尾通知())
	_记(not bool(窗.call("已打开")),
			"点完这扇**自己收起**（原版 `goQuestHandler:23-27` 第一句 `showHuSongNoticeWindow()` = `UIMain2.as:5366` 的 `reverseDisplay` ⇒ 等价 `窗口管理.打开或收起`）")
	var 场 := FileAccess.get_file_as_string(提示场景路)
	_记(场.count("[color=#00ff00]") == 2 and 场.contains("text = \"双倍护送活动已开启"),
			"两段绿字与整句都**烘在 .tscn 里**（编辑器 = 运行期），实测 [color=#00ff00] 出现 %d 次" % 场.count("[color=#00ff00]"))
