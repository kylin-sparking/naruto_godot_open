extends SceneTree

## 「开通穴道」弹窗里的**数是不是活的**。
##
## 真事（用户 2026-10-16 报"八门开通还没实装"）：弹窗能开、确认也接了线（§3.162），
## 但**里面三行值 + 灵符数量全是设计师烘在 .tscn 里的示例**（"头维 / 生命+15 / 399746 / 999"）
## —— 运行时一个字都没人填 ⇒ 玩家看到的全是死数，看着就像"没实装"。
##
## 这条门逐行对着 `数据/经脉.json` 的真值钉（**不写死期望值**：期望从同一份表里现算，
## 表改了门跟着变），并钉「勾选八门灵符 ⇒ 几率按每个灵符的加成往上加」。

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 默认地图 := "101010000"
const 经脉表 := preload("res://脚本/单例/游戏数据.gd")
## `字体落点()`：窗口标题字体包了一层 FontVariation（合成加粗），它自己没有 `resource_path`
## ⇒ 钉字体的腿一律解到底再比（正文是裸 FontFile，函数原样返回路径）。
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")

var _failures: Array[String] = []
var _已记 := 0
var _会话: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _记(条件: bool, 说明: String) -> void:
	_已记 += 1
	if not 条件:
		_failures.append(说明)


func _run() -> void:
	root.size = Vector2i(960, 560)
	var 场景 := (load(地图资源.playable_scene_path(默认地图)) as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _帧 in range(5):
		await process_frame

	var 管理 := 场景.get_node_or_null("窗口管理")
	var 会话 := root.get_node_or_null("GameSession")
	_会话 = 会话
	if 管理 == null or 会话 == null:
		_失败("依赖节点不完整")
		return
	管理.call("打开", "人物")
	await process_frame
	var 窗: Node = 管理.call("取或建窗口", "人物")
	窗.set("_character_main_tab", 1)		# 主分页 1 = 柔拳组
	窗.set("_character_sub_tab", 0)			# 子分页 0 = 八门
	窗.call("_render_page")
	await process_frame
	await process_frame

	var 页: Node = null
	for 子 in (窗.get("_content") as Node).get_children():
		var 扩展 := 子.get_node_or_null("人物扩展页")
		if 扩展 != null:
			页 = 扩展.get_node_or_null("八门内容")
	if 页 == null:
		_失败("八门页没建出来")
		_收尾()
		return
	var 弹窗 := 页.get_node_or_null("开通穴道弹窗") as Control
	if 弹窗 == null:
		_失败("开通穴道弹窗不在八门页里")
		_收尾()
		return

	# 取开门的第 0 枚穴位点，走**真点击的顺序**（先出信号让窗口填，再由组件填穴名并显示）
	var 层 := 页.get_node_or_null("穴位面板/穴位图/穴位点层_开门") as Control
	if 层 == null:
		_失败("穴位点层_开门 不在")
		_收尾()
		return
	# 按**穴名**找配置真值（**不按下标** —— 客户端点序与配置键序不是一回事，§3.162）
	var 穴名 := String(层.get_child(0).name).trim_prefix("点_")
	var 真 := _找穴(会话, 0, 穴名)
	if 真.is_empty():
		_失败("经脉表里找不到穴位「%s」" % 穴名)
		_收尾()
		return
	var 点 := 层.get_child(0) as Control
	if 点.has_signal("点击"):
		点.emit_signal("点击", 点.name)
	点.call("打开弹窗")
	await process_frame

	_记(弹窗.visible, "点穴位后弹窗没打开")
	_查值(弹窗, "行1", 穴名, "穴名")
	_查值(弹窗, "行2", "%s+%d" % [_属性名(String(真.get("attr", ""))), int(真.get("value", 0))], "加成")
	var 精华 := int((会话.get("player_stats") as Dictionary).get("zq", 0))
	_查值(弹窗, "行3", str(精华), "当前精华")

	var 区 := 弹窗.get_node_or_null("消耗与几率") as RichTextLabel
	if 区 == null:
		_失败("弹窗里没有 消耗与几率")
	else:
		var 消耗 := int(真.get("zq", 0))
		var 几率 := int(真.get("prob", 0))
		_记(区.text.contains(str(消耗)),
			"消耗与几率没写出真消耗 %d（现在是：%s）" % [消耗, 区.text])
		_记(区.text.contains(str(几率)),
			"消耗与几率没写出真几率 %d（现在是：%s）" % [几率, 区.text])
		_记(区.text.contains("#ff0000") if 精华 < 消耗 else 区.text.contains("#00ff00"),
			"消耗那一串的颜色不按够不够变（精华 %d / 消耗 %d）：%s" % [精华, 消耗, 区.text])

	# 勾上「本次操作使用」+ 选 1 个灵符 ⇒ 几率 = 基础 + 1 × 每个灵符的加成
	var 勾 := 弹窗.get_node_or_null("使用八门灵符") as CheckBox
	var 下拉 := 弹窗.get_node_or_null("数量下拉") as OptionButton
	if 勾 == null or 下拉 == null:
		_失败("弹窗里没有 使用八门灵符 / 数量下拉")
	else:
		var 每个 := int((经脉表.取表("经脉").get("info", {}) as Dictionary).get("itemprob", 0))
		_记(每个 > 0, "经脉表 info.itemprob 取不到（每个灵符的加成）")
		勾.button_pressed = true
		下拉.selected = 0			# → 用 1 个
		await process_frame
		var 期望 := int(真.get("prob", 0)) + 1 * 每个
		_记(区.text.contains(str(期望)),
			"勾上 1 个灵符后几率应为 %d，弹窗里没有（现在是：%s）" % [期望, 区.text])

	# ⑥ **越级拦截**：门内**按配置键序**逐枚开（原版 `JingMaiSource.getMaiPointSource` 的
	#    `for each(_loc7_ in pts)` ⇒ `pointId` = 配置键号；**玩家实机原版开门第一枚＝头维**）。
	#    原版 `chongMaiHandler:249-262` 判 `pointId > getMaiSuccessPoint()+1`（= `> 已开数`）才拦，
	#    **已开过的不拦**。
	#    ⚠️ 2026-10-17 更正：本门原来拿"点_头维"当越级样本 —— 那是**旧表（Ruffle 哈希序）**的产物，
	#       新口径下头维就是第 0 枚。现在**两枚都判**：第一枚不许被拦、靠后的必须被拦。
	var 提: Array[String] = []
	var 会话通知: Variant = 会话.get("notification_requested")
	if 会话通知 is Signal:
		会话通知.connect(func(文: String) -> void: 提.append(文))
	else:
		_失败("会话没有 notification_requested 信号，拦不拦得住看不出来")
	var 开通钮 := 弹窗.get_node_or_null("开通穴道按钮") as Button
	if 开通钮 == null:
		_失败("弹窗里没有 开通穴道按钮")
	else:
		# 第一枚（配置键 0，实机＝头维）：**不该**被越级拦（离线会落到"尚未连接原版游戏服务器"）
		提.clear()
		点.emit_signal("点击", 点.name)
		点.call("打开弹窗")
		await process_frame
		开通钮.pressed.emit()
		await process_frame
		_记(not 提.any(func(文: String) -> bool: return String(文).contains("不能越级")),
			"点**第一枚**（%s）被越级拦下了 —— 第一枚永远是合法的（实收：%s）" % [穴名, str(提)])
		# 靠后的那一枚（子节点第 5 个 = 配置键 4）：必须被拦
		if 层.get_child_count() >= 5:
			var 后 := 层.get_child(4) as Control
			提.clear()
			后.emit_signal("点击", 后.name)
			后.call("打开弹窗")
			await process_frame
			开通钮.pressed.emit()
			await process_frame
			_记(提.any(func(文: String) -> bool: return String(文).contains("不能越级")),
				"点**第 5 枚**（%s）没被越级拦下 —— 前面没开就该拦（实收：%s）"
					% [String(后.name).trim_prefix("点_"), str(提)])

	# ⑥½ **悬停穴位 ⇒ 右下角三格必须是这一枚穴位的配置**（用户 2026-11-01 报修：
	#     「提升属性没有具体显示提升多少属性，例如生命，只显示生命+」）。
	#     原版 `PointItem.overHandler:112-117` → `JingMaiPanel.updatePoint:284-293`：
	#     `_pointNameItem` = name、`_propItem` = getPropString(strengthProp, strengthValue)、
	#     `_zhenqiItem` = zhenqi；移开 → `PointItem.outHandler` → `clearPoint:245-250` 三格写 " "。
	#     ⚠️ 这三格是**穴位级**（`pts/<穴>/attr|value|zq`）；门级 `mai/<门>/value` 只进「修炼提示」。
	var 开门钮 := 页.get_node_or_null("门列表/按钮列/开门") as Button
	var 层现 := 页.get_node_or_null("穴位面板/穴位图/穴位点层_开门") as Control
	if 开门钮 == null or 层现 == null or 层现.get_child_count() < 3:
		_记(false, "门按钮 开门 / 穴位点层_开门 不全，悬停详情没法验")
	else:
		开门钮.pressed.emit()
		await process_frame
		# 进门时三格必须清空 —— 场景里烘着「曲差 / 生命 +8 / 500」的设计师示例值
		_记三格全空(页, "进入开门页")
		var 门提示 := 页.get_node_or_null("修炼提示面板/修炼提示") as RichTextLabel
		var 期望提示 := _加成(_找门(会话, 0))
		_记(门提示 != null and 门提示.text.contains(期望提示),
			"开门「修炼提示」应写出**门级**加成 %s（现在是：%s）"
				% [期望提示, 门提示.text if 门提示 != null else "<无>"])
		var 点一 := 层现.get_child(0) as Control
		var 点三 := 层现.get_child(2) as Control
		点一.emit_signal("mouse_entered")
		await process_frame
		_查详情(页, String(点一.name).trim_prefix("点_"), "悬停")
		点一.emit_signal("mouse_exited")
		点三.emit_signal("mouse_entered")
		await process_frame
		_查详情(页, String(点三.name).trim_prefix("点_"), "换悬停")
		点三.emit_signal("mouse_exited")
		await process_frame
		_记三格全空(页, "鼠标移开穴位")
		# 切门：鼠标点页签时早已离开穴位（原版 ROLL_OUT → clearPoint）⇒ 三格不许留上一门的残值
		页.get_node("门列表/按钮列/休门").emit_signal("pressed")
		await process_frame
		_记三格全空(页, "切到休门")
		var 期望休 := _加成(_找门(会话, 1))
		_记(门提示 != null and 门提示.text.contains(期望休),
			"切到休门后「修炼提示」应写出 %s（现在是：%s）"
				% [期望休, 门提示.text if 门提示 != null else "<无>"])

	# ⑦ **渲染不许发包**：`初始化八门页` 每次渲染都跑，一旦它发包就会形成
	#    render → 包 → 回帧（`cultivation_changed`） → render 的**死循环**
	#    （2026-10-17 用户实测：提示刷屏"八门统计请求已发送…" ＋ **整页点不动**）。
	#    离线判法：`发送修炼请求` 在未连服时会 emit「尚未连接原版游戏服务器」
	#    ⇒ **再渲染几次，一条通知都不该多出来**。
	提.clear()
	窗.call("_render_page")
	await process_frame
	窗.call("_render_page")
	await process_frame
	_记(提.is_empty(),
		"渲染八门页时发起了请求（收到通知：%s）—— 会造成 render→包→回帧→render 死循环（界面点不动）"
			% str(提))

	# ⚠️ 门卫生规矩 ④：上面 ⑦ 连着调了两次 `_render_page` ⇒ **旧页面节点已被 free**，
	#    这一节之前必须**重新取页**（直接拿 ⑥ 那个 `页` 会炸在 previously-freed 上——10-17 实测撞过）。
	页 = null
	for 子 in (窗.get("_content") as Node).get_children():
		var 扩展 := 子.get_node_or_null("人物扩展页")
		if 扩展 != null and 扩展.get_node_or_null("八门内容") != null:
			页 = 扩展.get_node_or_null("八门内容")
	if 页 == null:
		_记(false, "重取八门页失败（⑦ 渲染之后）")
		_收尾()
		return

	# ⑧ **门按钮与穴位名的"实际解析值"必须是原版那套**（用户 2026-10-17 报「八门那些门的字体都
	#    偏暗、不清晰」）。两个真凶（第一轮我猜的"页面根没挂 Theme"是**错的**——
	#    `project.godot:59 gui/theme/custom=原版主题.tres` 全局兜底，摘掉页内 theme 照样解析对，
	#    是反向对照把它打死的；见 §3.184）：
	#    ① 门按钮场景里写了 `custom_minimum_size` ⇒ `人物窗口.统一页面字号` 走 elif 按"场景没写过
	#       字号"塞 **11**，宋体 11px 打不中内嵌点阵 ⇒ 发虚；原版 `MButton.init:148-152` 是
	#       **size=12、font=COMMON_FONT**（内嵌宋体＝我们的 simsun_原版.ttf）⇒ 场景补 font_size=12。
	#    ② 穴位名 181 处 per-label 覆盖成 `SystemFont("SimSun")`（**系统 ttc 替身**，还吃 Godot
	#       默认 hinting=Light/subpixel=Auto ⇒ 发灰发透；§3.84.6 上位教训：别拿替身）⇒ 删覆盖，
	#       继承全局 `default_font = 素材/界面/simsun_原版.ttf`。
	#    ⚠️ 判据一律读**节点解析出来的实际值**（get_theme_*），不数场景里写了几行。
	var 门钮 := 页.get_node_or_null("门列表/按钮列/开门") as Button
	if 门钮 == null:
		_记(false, "门列表/按钮列/开门 不在")
	else:
		var 门字 := 门钮.get_theme_font("font")
		_记(门字 != null and 皮肤表.字体落点(门字).contains("simsun_原版"),
			"门按钮的字体不是原版内嵌宋体 simsun_原版.ttf（实际：%s）—— 系统 SimSun / Godot 默认字体都是「偏暗不清晰」"
				% 皮肤表.字体落点(门字))
		_记(门钮.get_theme_font_size("font_size") == 12,
			"门按钮字号是 %d，原版 MButton 是 12（11 打不中宋体点阵）" % 门钮.get_theme_font_size("font_size"))
		var 期望色 := Color(252.0 / 255.0, 244.0 / 255.0, 156.0 / 255.0, 1.0)	# #FCF49C = 16577692
		_记(门钮.get_theme_color("font_color").is_equal_approx(期望色),
			"门按钮字色不是原版 #FCF49C（实际 %s）" % str(门钮.get_theme_color("font_color")))
	var 穴字 := 页.get_node_or_null("穴位面板/穴位连线_开门/穴位组_头维/文字") as Label
	if 穴字 == null:
		_记(false, "穴位面板/穴位连线_开门/穴位组_头维/文字 不在")
	else:
		_记(穴字.get("theme_override_fonts/font") == null,
			"穴位名又被 per-label 字体覆盖了 —— 应继承主题里的 simsun_原版（§3.84.6 上位教训：别拿系统字体的替身）")
		var 穴 := 穴字.get_theme_font("font")
		_记(穴 != null and 皮肤表.字体落点(穴).contains("simsun_原版"),
			"穴位名实际字体不对（%s）" % 皮肤表.字体落点(穴))
		_记(穴字.get_theme_constant("outline_size") == 2,
			"穴位名黑描边不是 2（原版 MGlowLabel 黑辉光；实际 %d）" % 穴字.get_theme_constant("outline_size"))

	_收尾()


func _查值(弹窗: Control, 行: String, 期望: String, 名: String) -> void:
	var 值 := 弹窗.get_node_or_null("%s/值框/值" % 行) as Label
	_记(值 != null and 值.text == 期望,
		"%s（%s）是「%s」，应为「%s」" % [名, 行, 值.text if 值 != null else "<无>", 期望])


## 悬停某枚穴位时，右下角三格 = 这一枚的 name / attr+value / zq（期望从表里现算）。
func _查详情(页: Node, 穴名: String, 标签: String) -> void:
	var 穴 := _找穴(_会话, 0, 穴名)
	if 穴.is_empty():
		_记(false, "经脉表里找不到穴位「%s」（%s详情）" % [穴名, 标签])
		return
	var 期望 := [
		["穴位名称/值", 穴名],
		["提升属性/值", "%s+%d" % [_属性名(String(穴.get("attr", ""))), int(穴.get("value", 0))]],
		["所需精华/值", str(int(穴.get("zq", 0)))],
	]
	for 对 in 期望:
		var 值 := 页.get_node_or_null(String(对[0])) as Label
		_记(值 != null and 值.text == String(对[1]),
			"%s「%s」时「%s」是「%s」，应为「%s」"
				% [标签, 穴名, 对[0], 值.text if 值 != null else "<无>", 对[1]])


## 「鼠标不在这枚穴位上」⇒ 三格写 " "（原版 `clearPoint:245-250`）。
func _记三格全空(页: Node, 标签: String) -> void:
	for 路 in ["穴位名称/值", "提升属性/值", "所需精华/值"]:
		var 值 := 页.get_node_or_null(路) as Label
		_记(值 != null and 值.text.strip_edges().is_empty(),
			"%s后「%s」应清空，实际是「%s」" % [标签, 路, 值.text if 值 != null else "<无>"])


## 门级加成串（`mai/<门>/attr|value` → "生命+154"），原版 `getPropString`。
func _加成(门条: Dictionary) -> String:
	return "%s+%d" % [_属性名(String(门条.get("attr", ""))), int(门条.get("value", 0))]


func _门阶(会话) -> int:
	return int(((会话.get("cultivation_states") as Dictionary).get("八门", {}) as Dictionary).get("list_id", 0))


func _找门(会话, 门序: int) -> Dictionary:
	return ((经脉表.取表("经脉").get(str(_门阶(会话)), {}) as Dictionary)
		.get("mai", {}) as Dictionary).get(str(门序), {}) as Dictionary


## 从 `数据/经脉.json` 现算期望（**不写死**）：按当前阶 / 门序 / 穴名找。
func _找穴(会话, 门序: int, 穴名: String) -> Dictionary:
	var 阶 := _门阶(会话)
	var 门条: Dictionary = ((经脉表.取表("经脉").get(str(阶), {}) as Dictionary).get("mai", {}) as Dictionary).get(str(门序), {}) as Dictionary
	for _键 in (门条.get("pts", {}) as Dictionary):
		var 穴: Dictionary = 门条["pts"][_键] as Dictionary
		if String(穴.get("name", "")) == 穴名:
			return 穴
	return {}


func _属性名(属性: String) -> String:
	return String({"maxhp": "生命", "maxmp": "查克拉", "def": "防御",
		"atk": "攻击", "avd": "闪避", "bsk": "暴击"}.get(属性, 属性))


func _失败(说明: String) -> void:
	push_error("八门开通弹窗：" + 说明)
	quit(1)


func _收尾() -> void:
	if _failures.is_empty():
		print("八门开通弹窗回归测试：通过（%d 条断言：穴名 / 加成 / 当前精华 / 消耗与几率 / 灵符加成 / 越级拦截 / 悬停穴位详情 / 渲染不发包 / 整页主题与字体）" % _已记)
		quit(0)
		return
	for 项 in _failures:
		push_error("八门开通弹窗：" + 项)
	print("八门开通弹窗回归测试：失败 %d / %d 条 —— %s" % [_failures.size(), _已记, ", ".join(_failures)])
	quit(1)
