extends SceneTree

## 「人物属性（看别人）」= 原版 `CharOtherWindow2`：点对方头顶那颗「查看信息」→ 服务端回
## `58:4:<52 段>` → 开这一扇，窗内数据是对方的**实时**属性。
## 真值：`真值/窗口/人物属性_看别人.md`（入口链逐跳 / 逐件矩形 / 52 段字段表 / 四颗钮协议）。
##
## 这条门钉这几样东西：
##   ① **开窗那一跳真的接上了**（`他人详细信息收到` → `窗口管理._on_other_char_info` → `打开()`），
##      而不是"字面写对了"—— 所以它从**真场景**里灌**真帧**给**真解析器**，
##   ② 填进去的是**那一帧的数**（信息区六格 / 战斗属性六行 / 三根条），不是默认值；
##   ③ 四颗钮**点下去世界真的变了**（密语 ⇒ 聊天框切私聊频道并预填；加友 ⇒ 已是好友就不发包）。
##      ⚠ 「接了线」不等于「点了有用」（§3.111 的假绿就是这么来的），所以这里一律 push 真点击。
##   ④ 没接的东西**不许冒充**：「意志」那格显示 `-`、「战斗属性」右边那枚箭头藏起来
##      （2026-10-18 三面板巡检 #29 加的后半 —— 本工程 `58:4` 没解出对方的三条率）；
##   ⑩ **他的装备真的画在他的格子上**（图标 + 六层角标），而**我的装备一件都不许漏进那扇**，
##      他那扇的格子还必须**点不动**（原版 `EquipPane.as:1114-1127 removeMouseEvents`）；
##   ⑩a **第二帧只刷新、不关窗，并且拉回人物页**（原版 `Client.as:3022-3035`：窗已开着走
##      `setData` + 五路 `setEquipData`，`CharOtherWindow2.as:164-171 setData()` 里 `setPanel(0,0)`）。

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 职业表 := preload("res://脚本/单例/职业.gd")
const 部位 := preload("res://脚本/单例/装备部位.gd")
# 格子**节点名**只有这一份真值（`装备格节点`，神器镜那格在场景里叫 `真神器`）——
# 门里不能再抄一份 20 个中文名，抄了就会跟 .tscn 漂移（本工程栽过两次）。
const 人物窗 := preload("res://脚本/界面/窗口/人物窗口.gd")
# 本门会**灌地图场景**并覆写 `会话.equipped_items` ⇒ 落地路径不止一条（`_save_local_state`
# 有几十处调用点，开窗/切页里就可能撞到）。按字节快照 + 按字节还原，独立跑也不脏用户的档。
const 门存档快照 := preload("res://测试/门存档快照.gd")
# 三枚计数角标的节点名（与 `人物窗口.计数角标名` 同一份；门里抄一份是为了能点名报错）。
const 计数角标 := ["紫件数", "满星件数", "满融件数"]
const 默认地图 := "101010000"

var _failures: Array[String] = []
var _已记 := 0
## 开场按字节抄下的 `user://` 两份档（`_还原档()` 收尾原样放回）。
var _文件前: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _记(条件: bool, 说明: String) -> void:
	_已记 += 1
	if not 条件:
		_failures.append(说明)


func _run() -> void:
	_文件前 = 门存档快照.全快照()
	# ⚠ 无头视口是 (64,64) —— 不钉尺寸，后面按坐标做的任何事都落不进视口（门卫生规矩②）
	root.size = Vector2i(960, 560)

	var 场景路径: String = 地图资源.playable_scene_path(默认地图)
	if not 场景路径.contains("场景/生成/"):
		_fail("加载的不是烘焙场景（%s）—— 实机走的是 playable_scene_path()" % 场景路径)
		return
	var 打包 := load(场景路径) as PackedScene
	if 打包 == null:
		_fail("无法加载地图场景：%s" % 场景路径)
		return
	var 场景 := 打包.instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _帧 in range(5):
		await process_frame

	var 后端 := root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	var 管理 := 场景.get_node_or_null("窗口管理")
	var 聊天 := 场景.get_node_or_null("聊天面板")
	if 后端 == null or 会话 == null or 管理 == null:
		_fail("依赖节点不完整（BackendConnection / GameSession / 窗口管理）")
		return

	# ── 造一帧真的 `58:4`：**52 段**、按下标排（头 0..29 见 真值 §⑥，尾巴 30..51 见
	#    `后端连接.他人尾巴整数/文本`）。⚠ **不手搓字典**，而是把这条文本灌进**真解析器**
	#    再取 `他人详细信息` —— 上一版就是手搓一份"键名长得像"的档，于是"解析器只解到
	#    下标 29、剩下 22 段整截被丢"这件事门里量不出来（尾巴一个键都不缺、照样全绿）。
	const 对方号 := 4242
	const 对方名 := "被看的人"
	# 下标 6 = 脸号：**取 2**（本工程有美术的那具女身）。我自己是 1 ⇒ 画错了脸一眼看得出来。
	# 腿 ㋴b 另外灌一发 5（**查无此美术**）钉"他的窗上不许站着我的身体"。
	var 帧 := [
		"58", "4", str(对方号), 对方名, "77", "300", "2", "被看家族", "对象",
		"11", "13", "4242", "8484", "1500", "7", "900", "1000", "350", "400",
		"111", "222", "333", "444", "155", "166", "2700", "26", "27", "251",
		# 29..33：装备 / 神器 / 魂结 / 宠物 / 灵器 五份负载。这份**空**的留在原位钉下标对位，
		# 腿 ⑩ 会另造一份**有货**的灌进去（`_验他的装备`）。
		"-", "-", "-", "-", "-",
		# 34..37 手里剑阶/级/熟练/触发%  38 意志串  39..40 柔拳阶/进度
		"3", "2", "137", "25", "-", "5", "61",
		# 41..42 轮回六道阶/进度  43 原版是 lunhuiSkills、夹具这格是 "-"  44..45 结印阶/进度
		"4", "52", "-", "6", "73",
		# 46..47 写轮眼阶/进度  48..51 卡片与变身卡四个计数
		"2", "8", "3", "40", "5", "88",
	]
	_记(帧.size() == 52, "夹具那支发 52 段，这里造的帧是 %d 段 ⇒ 下标全错位" % 帧.size())
	# ① 开窗那一跳：灌帧 ⇒ 解析器**自己**出 `他人详细信息收到` ⇒ 窗口管理**自己**把窗开出来。
	#    ⚠ 判据走 `取窗口`（只查已存在的实例），**不能用 `取或建窗口`** —— 后者不管有没有
	#    接上都会建出一扇窗，于是"回帧→开窗"那条腿断了也照样绿（10-22 就是靠这条逮到
	#    「第二帧把窗关掉」的：原来挂在 `feature_requested` 上 = `打开或收起`）。
	var 开窗前: Node = 管理.call("取窗口", "人物属性看别人") if 管理.has_method("取窗口") else null
	_记(开窗前 == null, "这扇窗在开窗前就已经存在，这条腿测不出东西")
	后端.call("_handle_character_info_text", PackedStringArray(帧))
	var 档: Dictionary = (后端.get("他人详细信息") as Dictionary)
	await process_frame
	await process_frame
	var 窗: Node = 管理.call("取窗口", "人物属性看别人")
	_记(窗 != null, "灌一帧 58:4 之后「人物属性看别人」没有自己开出来（回帧→开窗那条腿断了）")
	if 窗 == null:
		_收尾()
		return

	# ⓪ 尾巴 30..51 **真的进了档**（这五页只读版的数据源就在这段里，丢一格就少一页）。
	for 对 in [["手里剑阶", 3], ["手里剑级", 2], ["手里剑熟练", 137], ["手里剑触发", 25],
			["柔拳阶", 5], ["柔拳进度", 61], ["轮回六道阶", 4], ["轮回六道进度", 52],
			["结印阶", 6], ["结印进度", 73], ["写轮眼阶", 2], ["写轮眼进度", 8],
			["卡片已领", 3], ["卡片总数", 40], ["变身卡已得", 5], ["变身卡总数", 88]]:
		var 键 := String(对[0])
		_记(档.has(键) and int(档[键]) == int(对[1]),
			"尾巴键 %s 解出来是 %s，应为 %d" % [键, 档.get(键, "<没这个键>"), int(对[1])])
	for 键 in ["神器串", "魂结串", "宠物串", "灵器串", "意志串"]:
		_记(String(档.get(键, "缺")) == "-", "尾巴文本键 %s 应为 `-`，实为 %s" % [键, 档.get(键, "<没这个键>")])
	_记(int(档.get("段数", 0)) == 52, "段数记的是 %s，应为 52" % 档.get("段数", "<无>"))

	窗.call("_render_page")
	await process_frame

	var 面板 := _找人物面板(窗)
	if 面板 == null:
		_fail("渲染出来的页面里找不到 原版人物属性面板（页面没建出来？）")
		_收尾()
		return

	# ② 加点块 ↔ 他人信息面板 的互斥（原版 `CharPane.as:255-270 set isMyself`）
	var 他人块 := 面板.get_node_or_null("他人信息面板") as Control
	_记(他人块 != null and 他人块.visible, "他人信息面板 没显示出来（看别人时该显它）")
	for 名 in ["加点属性底板", "加点属性标题", "基础属性"]:
		var 件 := 面板.get_node_or_null(名) as CanvasItem
		_记(件 != null and not 件.visible, "看别人时 %s 还显示着（该换成他人信息面板）" % 名)

	# ③ 信息区六格 = 那一帧的数（不是我的数、也不是默认值）
	var 期望 := {
		# 职业格显示的是**职业名**（`渲染人物页` 走 `职业表.取(job)`），不是职号
		"姓名格": 对方名, "等级格": "77", "职业格": 职业表.取(300),
		"家族格": "被看家族", "罪恶值格": "13", "羁绊格": "对象",
	}
	for 格名 in 期望:
		var 值 := 面板.get_node_or_null("信息区/%s/数值" % 格名) as Label
		_记(值 != null and 值.text == String(期望[格名]),
			"信息区/%s/数值 是 %s，应为 %s" % [格名, 值.text if 值 != null else "<无>", 期望[格名]])
	# 意志那一格看别人时原版没有数 ⇒ 不许拿"我的意志力"冒充
	var 意志 := 面板.get_node_or_null("信息区/意志格/数值") as Label
	_记(意志 != null and 意志.text == "-", "看别人时「意志」那格应显示 -（不能拿我的数冒充）")

	# ④ 战斗属性六行
	for 对 in [["攻击", "111"], ["防御", "222"], ["暴击", "333"], ["闪避", "444"],
			["攻击速度", "155"], ["移动速度", "166"]]:
		var 行 := 面板.get_node_or_null("战斗属性/%s" % 对[0]) as Label
		_记(行 != null and 行.text == String(对[1]),
			"战斗属性/%s 是 %s，应为 %s" % [对[0], 行.text if 行 != null else "<无>", 对[1]])

	# ④b 「战斗属性」右边那枚箭头**看别人时该藏**（2026-10-18 三面板巡检 #29）。
	#     原版「其他属性」那一板的**三条固定率**取自自己的 stats
	#     （`DataCenter.as:1448-1481 getDataForCharacterInfoWindow` 只在自己的那份里塞
	#     `damageReduce/damageReflect/ignoreDef`），而夹具在原版那三个下标（49..51）发的是
	#     **卡片计数** ⇒ 他那帧根本没有这三条率 ⇒ 画一板 0 就是拿我的口径冒充他的数
	#     （同上面「意志」那格的判据）。
	#     ⚠ 2026-10-22 起他的**装备特性已经解出来了**（`_他人装备表` 走整条 `_parse_item_entry`），
	#       所以这条腿藏箭头的理由**只剩那三条率** —— 将来服务端补上 49..51 那三条，
	#       就该把箭头放出来、附加行走他的装备（别顺手也改装备表那条）。
	var 展开 := 面板.get_node_or_null("战斗属性展开") as Button
	_记(展开 != null and not 展开.visible, "看别人时「战斗属性展开」该藏起来（他那帧没有那三条率），实 %s"
		% ("没有这个节点" if 展开 == null else "仍可见"))

	# ⑤ 三根条：分母是**原版定值**（`UIConfig.as` 5400 / 503 / ZQ_MAX），文字按 `cur/total`
	if 他人块 != null:
		# ⚠ **必须逐条 await**：`_查条` 里有 `create_timer` 的 await，调用处不 await ⇒ 只跑到
		#   第一个 await 就交回控制权，**最后那条 `槽.value` 判据一行不跑**（2026-10-22 就这么静默丢了 3 条腿）。
		await _查条(他人块, "忍术境界", 2700, 5400)
		await _查条(他人块, "八门进度", 26, 27)		# 帧里 26 = 经脉等级、27 = 八门进度，条上写 26/27
		await _查条(他人块, "成就进度", 251, 503)

	# ⑥ 四颗钮：**都接上了**（`as Button` 会恒 null —— 宠物那六颗就是这么一颗都没接上的）
	if 他人块 != null:
		for 钮名 in ["密语钮", "交易钮", "加友钮", "组队钮"]:
			var 钮 := 他人块.get_node_or_null(钮名) as BaseButton
			_记(钮 != null, "他人信息面板 缺 %s" % 钮名)
			if 钮 != null:
				_记(钮.pressed.get_connections().size() > 0, "%s 没接任何回调（点了没反应）" % 钮名)

	# ⑦ **点下去世界真的变了**：密语 ⇒ 聊天框切「私聊」频道、预填 `/名字 `、记下对象
	var 密语 := 他人块.get_node_or_null("密语钮") as BaseButton if 他人块 != null else null
	if 密语 != null and 聊天 != null:
		密语.pressed.emit()
		await process_frame
		var 输入 := 聊天.get("_chat_input") as LineEdit
		_记(String(聊天.get("_whisper_target")) == 对方名,
			"点密语后聊天框的对象是 %s，应为 %s" % [聊天.get("_whisper_target"), 对方名])
		_记(输入 != null and 输入.text == "/%s " % 对方名,
			"点密语后聊天框应预填 /%s ，实为 %s" % [对方名, 输入.text if 输入 != null else "<无输入框>"])

	# ⑧ **只读的五页**（手里剑/结印/柔拳/写轮眼/轮回六道）：数据 = 他那帧的阶，
	#    动作钮全部摁住或藏掉。原版每块只读面板改的就是这一行
	#    （`RouQuanPanel.as:433` / `JieYinPanel.as:356` / `LunHuiYanPanel.as:546` 摁住提升钮、
	#    `TongshuWindow.as:491-496` 整枚藏、`ShouLiJianPanel.as:140/383/416-419` 摁住 checkbox 与
	#    突破/提速），页面类与我自己那扇**是同一份**。
	var 三页: Array = [
		# [主分页, 子分页, 页面节点名, 页面上那枚"提升"入口, 期望显示他的第几阶, 入口该藏吗]
		# 0 排现在按原版是 人物→宠物→手里剑→结印（`CharOtherWindow2.as:222-224` 的宠物恒有）
		[0, 2, "手里剑内容", "", 3, false],
		[0, 3, "结印内容", "提升结印", 6, false],
		[1, 0, "柔拳内容", "提升柔拳阶数", 5, false],
		[2, 0, "写轮眼内容", "提升写轮眼阶数", 2, true],
		[2, 1, "轮回六道内容", "提升轮回六道", 4, false],
	]
	for 腿 in 三页:
		_切页(窗, int(腿[0]), int(腿[1]))
		await process_frame
		var 页 := _子页(窗, String(腿[2]))
		if 页 != null:
			_验只读页(页, 腿)
	_记(int(三页.size()) == 5, "只读页清单被改短了（现在 %d 条）—— 加页要连着加判据" % 三页.size())

	# ⑨ 看别人时主分页**三枚都亮**（另三页各有只读面板已接）；子分页组按**别人那一套**：
	#    tab1 只有「柔拳 / 寄坏之术」，**没有八门**（`CharOtherWindow2.as:237-244` 与
	#    `CharWindow2.as:570-576` 是两份不同的 createButtons）。
	_切页(窗, 1, 1)
	await process_frame
	var 页面 := 页面节点(窗)
	if 页面 != null:
		var 主按钮排: Array = []
		for 子在 in (页面.get_node("主分页") as Node).get_children():
			if 子在 is Button:
				主按钮排.append(子在)
		for 序号 in 主按钮排.size():
			_记(not (主按钮排[序号] as Button).disabled,
				"看别人时主分页第 %d 枚该亮着（只读页已接）" % 序号)
		var 子按钮排: Array = []
		for 子在 in (页面.get_node("子分页") as Node).get_children():
			if 子在 is Button:
				子按钮排.append(子在)
		_记(String((子按钮排[0] as Button).text) == "柔拳",
			"看别人时秘术那组的第 1 枚是「%s」，应为「柔拳」（**不是八门**）" % (子按钮排[0] as Button).text)
		_记(String((子按钮排[1] as Button).text) == "寄坏之术", "第 2 枚应为寄坏之术")
		# 10-16 起这一页已有只读实现（段 29 的 −200..−203 四格），不再"要么禁要么不出现"。
		_记((子按钮排[1] as Button).visible and not (子按钮排[1] as Button).disabled,
			"寄坏之术的只读页已接（段 29 四格）⇒ 这枚该可点")
	# ⚠ 藏起来的第三条腿（尾巴缺段时**不许拿默认值冒充**）在最后一条函数里，
	#   它会自己把档换掉，放在这里跑完再执行，免得打乱上面这些腿。
	_验缺段不冒充(窗, 后端)

	# ⑩ 他的**装备**（2026-10-22 用户报修「看别人装备格缺品质/绑定角标」⇒ 逮到整扇串窗：
	#    以前这扇画的是**我的**装备，还留着点击腿，双击他的格子会卸下**我的**件）。
	await _验他的装备(窗, 后端, 会话, 管理, 帧)

	_收尾()


## 三根条的 值/上限/文字 一起钉 —— 只钉"控件在"是钉不住 MBar 那套口径的。
## ⚠ 填充现在走 `进度条补间` 的 0.5 秒补间（§3.243，`MBar.as:170`）⇒ **只有 `value` 这一项要等**，
##    等的是**墙上时钟**（无头里 `process_frame` 短到微秒，"等 N 帧"必然假红）。
##    上限与那行文字仍是**立即**写 —— 原版 `:151-168` 先写字、`:170` 才挂补间
##    （§② 第 5 步：数字先到终值、条慢慢爬），所以先钉它俩、再等、再钉条。
func _查条(块: Control, 条名: String, 当前: int, 上限: int) -> void:
	var 槽 := 块.get_node_or_null("%s槽" % 条名) as ProgressBar
	if 槽 == null:
		_failures.append("他人信息面板 缺 %s槽" % 条名)
		return
	_记(int(槽.max_value) == 上限, "%s槽 上限是 %d，应为 %d" % [条名, int(槽.max_value), 上限])
	var 值 := 块.get_node_or_null("%s值" % 条名) as Label
	_记(值 != null and 值.text == "%d/%d" % [当前, 上限],
		"%s值 文字是 %s，应为 %d/%d" % [条名, 值.text if 值 != null else "<无>", 当前, 上限])
	await create_timer(0.7).timeout
	_记(int(槽.value) == 当前, "%s槽 当前是 %d，应为 %d" % [条名, int(槽.value), 当前])


## 切页 = 直接挪宿主那两个下标再重绘。**不走 `pressed`**：页签钮每次 `_render_page` 都会重建，
## 发 pressed 得先摸到"当前那一枚"，绕一圈反而容易假绿；而这两个下标就是页签的唯一身份
## （`_set_character_main_tab:5225-5229` 干的也正是"写下标 + 重绘"这两件事）。
func _切页(窗: Node, 主: int, 子: int) -> void:
	窗.set("_character_main_tab", 主)
	窗.set("_character_sub_tab", 子)
	窗.call("_render_page")


func _子页(窗: Node, 页名: String) -> Control:
	var 页 := 页面节点(窗)
	if 页 == null:
		_failures.append("渲染出来的页面根都找不到，「%s」这条腿没法测" % 页名)
		return null
	var 扩展 := 页.get_node_or_null("人物扩展页") as Panel
	if 扩展 == null:
		_failures.append("页面里没有 人物扩展页")
		return null
	var 子页 := 扩展.get_node_or_null(页名) as Control
	if 子页 == null:
		_failures.append("人物扩展页 里没有「%s」（页签没切过去？）" % 页名)
	return 子页


## 一条腿两件事：**他的阶落进显示层了**、**动作全部点不动**。
## 腿的形 = [主分页, 子分页, 页面节点名, 提升入口名, 他的阶, 入口该整枚藏掉吗]。
func _验只读页(页: Control, 腿: Array) -> void:
	var 页名 := String(腿[2])
	var 他的阶 := int(腿[4])
	var 入口名 := String(腿[3])
	if not 入口名.is_empty():
		var 入口 := 页.get_node_or_null(入口名) as BaseButton
		if 入口 == null:
			_failures.append("%s 里没有入口「%s」" % [页名, 入口名])
		elif bool(腿[5]):
			# 写轮眼那族原版不是摁住、是**整枚藏**（`TongshuWindow.as:491-496`）
			_记(not 入口.visible, "%s/%s 看别人时该整枚藏掉（原版 readOnly 走 visible=false）" % [页名, 入口名])
		else:
			_记(入口.disabled, "%s/%s 看别人时该摁住（点不动）" % [页名, 入口名])
	match 页名:
		"手里剑内容":
			# 三颗动作钮：checkbox + 提速 + 突破（`ShouLiJianPanel.as:140/383/416-419`）
			for 路径 in ["当前信息/启用复选框", "详情面板/提升速度", "详情面板/突破瓶颈"]:
				var 件 := 页.get_node_or_null(路径) as BaseButton
				_记(件 != null and 件.disabled, "手里剑页 %s 看别人时该摁住" % 路径)
			_记(int(页.get("_阶段")) == 他的阶,
				"手里剑页停在 %s 阶，应为他的 %d 阶" % [页.get("_阶段"), 他的阶])
			# ⚠ 这条钉的是"攻击能力那行换算用的是**他的** atk"（原版 `:376 otherAtk = _data.atk`）。
			#   上一版这里直接读我的 `player_stats.attack` ⇒ 看别人的手里剑伤害写成我的攻击力。
			_记(int(页.get("_攻击力")) == 111,
				"手里剑页的换算攻击力是 %s，应是他那一帧下标 19 那个 111" % 页.get("_攻击力"))
			var 等级 := 页.get_node_or_null("当前信息/当前等级/值") as Label
			_记(等级 != null and 等级.text == "10/12级",
				"当前等级写的是 %s，应为 10/12级（4×(3-1)+2 = 10 级，上限 4×3）"
				% (等级.text if 等级 != null else "<没这个节点>"))
			var 触发 := 页.get_node_or_null("当前信息/当前触发几率/值") as Label
			_记(触发 != null and 触发.text == "25%",
				"触发几率写的是 %s，应为他那一格 25%%" % (触发.text if 触发 != null else "<没这个节点>"))
			var 进度 := 页.get_node_or_null("当前信息/当前进度/值") as Label
			_记(进度 != null and 进度.text.begins_with("137/"),
				"熟练度写的是 %s，应为他的 137 起头" % (进度.text if 进度 != null else "<没这个节点>"))
		"结印内容":
			var 弹窗 := 页.get_node_or_null("提升结印阶数弹窗") as Control
			if 弹窗 == null:
				_failures.append("结印页里没有 提升结印阶数弹窗")
				return
			var 亮 := 弹窗.get_node_or_null("印%d阶段" % 他的阶) as Control
			var 灭 := 弹窗.get_node_or_null("印%d阶段" % (他的阶 - 1)) as Control
			_记(亮 != null and 亮.visible, "结印页没把他的 %d 阶亮起来" % 他的阶)
			_记(灭 != null and not 灭.visible, "结印页 %d 阶也该是暗的（只亮当前那一阶）" % (他的阶 - 1))
			var 数 := 弹窗.get_node_or_null("印%d阶段/熟练度进度条/熟练度值数值" % 他的阶) as Label
			_记(数 != null and 数.text == "73/12000",
				"他的结印熟练度写的是 %s，应为 73/12000（下标 45 = 73，6 阶上限 12000）"
				% (数.text if 数 != null else "<没这个节点>"))
		"柔拳内容":
			_记(int(页.get("当前阶段")) == 他的阶,
				"柔拳页停在 %s 阶，应为他的 %d 阶" % [页.get("当前阶段"), 他的阶])
		"写轮眼内容":
			# 他的脚本收的是 **0 起算**下标（`切写轮眼阶段` 里那句 `阶 - 1`）
			_记(int(页.get("_当前阶段")) == 他的阶 - 1,
				"写轮眼页停在 %s，应为他的 %d 阶（0 起算 = %d）" % [页.get("_当前阶段"), 他的阶, 他的阶 - 1])
		"轮回六道内容":
			_记(int(页.get("current_index")) == 他的阶 - 1,
				"轮回六道页停在 %s，应为他的 %d 阶（0 起算 = %d）" % [页.get("current_index"), 他的阶, 他的阶 - 1])


## 尾巴**缺段**时不许拿默认值凑：把档换成"只有头 30 段"那份（六个 `*阶` 键全抹掉），
## 再切到柔拳页 ⇒ 页面该停在他自己烘的默认态（`_ready` 里那句 `_切换阶段(1)`），
## 而不是"我的阶"、也不是拼出来的假 1 阶。这条钉的是 `人物窗口.页状态` 那个**空字典早退**。
func _验缺段不冒充(窗: Node, 后端: Node) -> void:
	var 全档: Dictionary = (后端.get("他人详细信息") as Dictionary)
	var 头档: Dictionary = 全档.duplicate(true)
	for 键 in ["柔拳阶", "柔拳进度", "手里剑阶", "手里剑级", "手里剑熟练", "手里剑触发",
			"结印阶", "结印进度", "写轮眼阶", "写轮眼进度", "轮回六道阶", "轮回六道进度"]:
		头档.erase(键)
	后端.set("他人详细信息", 头档)
	_切页(窗, 1, 0)
	var 页 := _子页(窗, "柔拳内容")
	if 页 != null:
		_记(int(页.get("当前阶段")) == 1,
			"尾巴缺段时柔拳页停在 %s 阶 —— 没数据就该留在他烘的默认 1 阶，不许拿我的数凑" % 页.get("当前阶段"))
		var 入口 := 页.get_node_or_null("提升柔拳阶数") as BaseButton
		_记(入口 != null and 入口.disabled, "尾巴缺段时提升入口还亮着（只读闸跟着数据一起漏了）")
	后端.set("他人详细信息", 全档)		# 还原，别把这半截档留给后面的腿/别的门


func 页面节点(窗: Node) -> Node:
	var 内容 := 窗.get("_content") as Node
	if 内容 == null:
		return null
	for 子 in 内容.get_children():
		if 子.get_node_or_null("原版人物属性面板") != null:
			return 子
	return null


func _找人物面板(窗: Node) -> Control:
	var 页 := 页面节点(窗)
	if 页 == null:
		return null
	return 页.get_node_or_null("原版人物属性面板") as Control


## 一截宝石镶嵌。**服务端 5 字段**：`stone_id*stone_level*attribute_type*skill_id*attribute_value`
## （行内 `*`、行间 `!`，`fake_flash_server.py:51030` 那条 `entry[:5]`），
## 解析侧 `_parse_named_rows(values[21], [stone_id, stone_level, attribute_type, skill_id, attribute_value])`
## ⇒ **一行了 5 段就整行丢**（`:4643`），丢光了金钻角标与满融灯就都不亮，还查不出为什么。
func _嵌(颗数: int, 级: int) -> String:
	var 行: Array[String] = []
	for 序 in 颗数:
		行.append("301*%d*1*0*50" % 级)
	return "!".join(行) if not 行.is_empty() else "-"


## 造一截 `58:4` 的装备负载。**与服务端 `_encode_item_payload` 的 EQUIPMENT 支同一条**：
## 10 段通用 + 23 段装备 = **33 段**（`fake_flash_server.py:50985-51046`），`&` 分字段、`@` 分件。
## ⚠ 段数 < 29 时 `_parse_item_entry` **整件丢掉**（不报错），所以这里自己先钉一次 33 ——
##   上一版「只解 id」就是钉在这个形状上的：形状不对时门里看不到角标，只会以为"他没装"。
func _装(号: String, 槽: int, 资: int, 星: int, 耐: int, 嵌: String, 碎: int, 类: int = 1,
		绑: int = 1) -> String:
	# 段 6 = canTrade（`_parse_item_entry` 读 `values[6]`，提示框那行 `[已绑定]/[未绑定]` 归它）。
	var 段: Array[String] = [
		str(类), 号, str(槽), "1", "0", "0", str(绑), "被看的人", "0", str(700000 - 槽),
	]
	match 类:
		4:		# 神器：base_attributes + holy_attributes（`:51002-51011`）
			段 += ["-", "-"]
		5:		# 羁绊：两个占位（`:51012-51014`）
			段 += ["0", "-"]
		6:		# 灵器：plus_attributes 一段（`:51015-51020`，解析侧要 ≥ 11 段）
			段 += ["-"]
		_:
			段 += [str(资), "100", str(耐), "4", "10", "0", "0", "-", "0", "0", "0", 嵌,
				str(星), "true", str(碎), "0", "-1", "0", "0", "-", "0", "0", "0"]
			_记(段.size() == 33,
				"造的装备负载是 %d 段，服务端那条是 33 段 ⇒ 解析器整件丢，格子上当然没角标" % 段.size())
			return "&".join(段)
	return "&".join(段)


## 腿 ⑩：他的装备画在他的格子上（图标 + 六层角标）+ 我的**一件都不漏** + 他的格子点不动。
## 原版真值：`uifl/controls/cell/EquipmentWindowCell.as:121-173`（六层覆盖层）与
## `EquipPane.as:747-757 / 1114-1127`（看别人摘掉点击系四条、留悬停提示）。
## 数据侧 = `后端连接._他人装备表`（四截串并成 `位置 → 物品`，走同一个 `_parse_item_entry`）。
func _验他的装备(窗: Node, 后端: Node, 会话: Node, 管理: Node, 基帧: Array) -> void:
	# 我的装备**先钉死**（离线档里本来有什么是不确定的，判据不能建在它上面）。三件的形状
	# 专挑与**他那七件不一样**的账，漏一件就有一格对不上：
	#   武器 = **橙**装（他的是白装 ⇒ 串窗就会多一枚资质框）；手套 = 白装零孔（那格是点击腿的靶子，
	#   他的却是 紫+12星+满融 ⇒ 串窗就没有蓝钻/金钻）；护腰 = **我有他没有**、且带 12 星蓝钻
	#   （他那扇的护腰格本该空着 ⇒ 画出图标/物品id/蓝钻 任一样都是漏）。
	# ⚠ 计数三档 紫/星/融 也刻意错开：我的 = **1/1/0**，他的 = **2/1/1** ⇒ ㋳ 那三条里
	#   紫与融都能判串窗（第一版我的是 2/1/1、他的也是 2/1/1，那三条腿等于没测）。
	var 我的装 := {
		部位.武器: 后端.call("_parse_item_entry", _装("01010011", -1, 5, 0, 100, "-", 0)),
		部位.手套: 后端.call("_parse_item_entry", _装("01020020", -2, 1, 0, 100, "-", 0)),
		部位.护腰: 后端.call("_parse_item_entry", _装("01050011", -5, 1, 12, 100, "-", 0)),
	}
	var 原装 = 会话.get("equipped_items")
	会话.set("equipped_items", 我的装)

	var 帧 := 基帧.duplicate()
	帧[29] = "@".join([
		_装("01010011", -1, 1, 0, 100, "-", 0),		# 武器：白装，什么角标都不该叠
		# 手套：紫 + 12 星 + 满融 ⇒ 蓝钻 + 金钻；**绑 0** = 他那件「已绑定」、我这件「未绑定」
		# ⇒ 腿 ㋱b 的提示框那条才有方向（两边一样就测不出串窗）。
		_装("01020010", -2, 4, 12, 100, _嵌(5, 6), 0, 1, 0),
		_装("01030011", -3, 5, 3, 0, "-", 7),		# 衣服：橙 + 3 星 + 耐久 0 + 破碎
		_装("01040011", -4, 1, 0, 100, "-", 0),
	])
	帧[30] = _装("17100001", -100, 0, 0, 100, "-", 0, 4)	# 神器剑（原版没装备就整格隐藏）
	帧[31] = _装("19010001", -50, 0, 0, 100, "-", 0, 5)	# 羁绊
	帧[33] = _装("20100001", -23, 0, 0, 100, "-", 0, 6)	# 灵器
	# ㋰a **第二帧不许关窗、也不许停在我上次翻过去的那页**（原版 `Client.as:3022-3035`：
	#      窗已开着走 `setData(otherCharData)` + 五路 `setEquipData/setShenqiData/…`，
	#      `CharOtherWindow2.as:164-171 setData()` 里 `setPanel(0,0)`）。
	#      上一版这两件事都是红的：开窗挂在 `feature_requested` 上 = `打开或收起` ⇒ 第二帧**把窗关掉**；
	#      而页签不重置 ⇒ 换个人来看还停在上一个人的秘术页上。
	_切页(窗, 1, 0)
	后端.call("_handle_character_info_text", PackedStringArray(帧))
	await process_frame
	await process_frame
	var 还在 := 管理.call("取窗口", "人物属性看别人") as Node
	_记(还在 == 窗, "灌第二帧 58:4 之后这扇窗不见了或换了一扇（原版只刷新、不关窗）")
	_记(int(窗.get("_character_main_tab")) == 0 and int(窗.get("_character_sub_tab")) == 0,
		"第二帧之后还停在 主%s/子%s —— 原版 setData 会 setPanel(0,0) 拉回人物页"
		% [窗.get("_character_main_tab"), 窗.get("_character_sub_tab")])

	var 面板 := _找人物面板(窗)
	if 面板 == null:
		_failures.append("⑩ 灌了有货的 58:4 之后页面重建失败")
		会话.set("equipped_items", 原装)
		return
	var 档: Dictionary = (后端.get("他人详细信息") as Dictionary)
	var 表: Dictionary = 档.get("装备", {}) as Dictionary

	# ㋰ 解码结果本身（位置键是**协议里那个负数**，不是 1 基下标）
	_记(表.size() == 7, "他的装备表解出 %d 件，应为 7（4 件标准 + 神器 + 羁绊 + 灵器）" % 表.size())
	var 他手: Dictionary = 表.get(部位.手套, {}) as Dictionary
	_记(String(他手.get("id", "")) == "01020010",
		"他的手套位解出来是 %s，应为 01020010" % 他手.get("id", "<没这个位>"))
	_记(int(他手.get("strengthen", -1)) == 12,
		"手套的 strengthen 是 %s，应为负载里那个 12（读不到就是装备段没解、只剩 id）"
		% 他手.get("strengthen", "<没这个键>"))
	var 他手嵌: Array = 他手.get("inlays", []) as Array
	_记(他手嵌.size() == 5,
		"手套的镶嵌没解出 5 行（实 %d）⇒ 镶嵌行的字段数与服务端那条不一致" % 他手嵌.size())
	# 忍具：夹具那帧**根本没有 RenJu 负载**（原版 34 那格，`_full_character_info_fields` 没写）
	# ⇒ 他那扇的忍具格该是空的。这条钉的是"不许拿我的忍具冒充他的"，不是"实现完了"。
	_记(not 表.has(部位.忍具), "他的忍具格凭空有了件 —— 服务端没发 RenJu 负载，只能是漏了我的")

	# ㋱ 六层角标（`EquipmentWindowCell.as:130-171`）
	var 容器 := 面板.get_node("装备栏/装备格子容器") as Control
	if 容器 == null:
		_failures.append("⑩ 找不到 装备栏/装备格子容器")
		会话.set("equipped_items", 原装)
		return
	var 武 := 容器.get_node_or_null("武器格") as Button
	var 手 := 容器.get_node_or_null("手套格") as Button
	var 衣 := 容器.get_node_or_null("衣服格") as Button
	var 腰 := 容器.get_node_or_null("护腰格") as Button
	var 神 := 容器.get_node_or_null("神器剑格") as Button
	var 灵 := 容器.get_node_or_null("灵器格") as Button
	var 绊 := 容器.get_node_or_null("羁绊格") as Button
	if 武 == null or 手 == null or 衣 == null or 腰 == null or 神 == null or 灵 == null or 绊 == null:
		_failures.append("⑩ 装备格节点缺件（武器/手套/衣服/护腰/神器剑/灵器/羁绊）")
		会话.set("equipped_items", 原装)
		return
	_记(武.icon != null and 手.icon != null and 衣.icon != null,
		"他的装备格没画出图标（资质/星数都无从谈起）")
	_记(灵.icon != null and 绊.icon != null, "灵器/羁绊两格没画出他的件（30/31/33 三截没并进装备表？）")
	_记(神.visible, "神器剑格他没装件时才隐藏；负载里有 1710 这件，格子该露出来")
	# 白装不叠资质框（`装备品质.挂覆盖层`：资质 1 → 无边框贴图），紫/橙叠
	_记(not _层(武, "资质框"), "他的武器是白装却叠了资质框 —— 那枚框是我那件橙装的（串窗）")
	_记(_层(手, "资质框"), "他的手套（紫装）没叠资质框")
	_记(_层(手, "蓝钻") and _层(手, "强化底") and not _层(手, "强化数字"),
		"手套 12 星该是「底 + 蓝钻、不写数字」（`EquipStrengthIcon.setStrengthInfo(level,false)`）")
	_层在(手, "镶嵌金钻", true, "手套 5 孔全 6 级 ⇒ 该有金钻（`isShowGoldIcon`）")
	_层在(衣, "破碎角标", true, "衣服 crash_time=7 ⇒ 该有破碎角标")
	_层在(衣, "耐久红框", true, "衣服 endure=0 ⇒ 该有耐久红框")
	_层在(衣, "强化数字", true, "衣服 3 星 ⇒ 该写数字而不是蓝钻")
	var 衣数 := 衣.get_node_or_null("强化数字") as Label
	_记(衣数 != null and 衣数.text == "3", "衣服强化数字是 %s，应为 3" % (衣数.text if 衣数 != null else "<无>"))
	# 角标位置照原版 `EquipmentWindowCell.as:152-168`：强化符号摆 (-2,26)、16x16，内件
	# background@(0,0) / tf@(2,2) / blueDiamond@(2,3)；满融是第二个符号摆 (26,26) 的
	# goldDiamond@(2,3) ⇒ (28,29)-(40,39)。2026-11-07 用户报「满融标位置不对」：
	# 旧换算整组 +35（把 -2 当成 33），金钻落到 x=61..77、直接出格。
	var 强底 := 手.get_node_or_null("强化底") as Control
	var 蓝钻层 := 手.get_node_or_null("蓝钻") as Control
	var 金钻层 := 手.get_node_or_null("镶嵌金钻") as Control
	_记(强底 != null and 强底.position == Vector2(-2.0, 26.0) and 强底.size == Vector2(16.0, 16.0),
		"强化底该在 (-2,26) 16x16（`EquipmentWindowCell.as:157-158`），实测 %s / %s" % [
			str(强底.position) if 强底 != null else "<无>", str(强底.size) if 强底 != null else "<无>"])
	_记(蓝钻层 != null and 蓝钻层.position == Vector2(0.0, 29.0) and 蓝钻层.size == Vector2(12.0, 10.0),
		"蓝钻该在 (0,29) 12x10（符号内 blueDiamond@(2,3)），实测 %s / %s" % [
			str(蓝钻层.position) if 蓝钻层 != null else "<无>", str(蓝钻层.size) if 蓝钻层 != null else "<无>"])
	_记(金钻层 != null and 金钻层.position == Vector2(28.0, 29.0) and 金钻层.size == Vector2(12.0, 10.0),
		"满融金钻该在 (28,29) 12x10（26,26 + goldDiamond@(2,3)），实测 %s / %s" % [
			str(金钻层.position) if 金钻层 != null else "<无>", str(金钻层.size) if 金钻层 != null else "<无>"])
	_记(金钻层 != null and 金钻层.position.x + 金钻层.size.x <= 40.0,
		"满融标必须落在 40x40 格子内（旧换算推到 x=61..77 = 出格），实测右沿 %s" % [
			str(金钻层.position.x + 金钻层.size.x) if 金钻层 != null else "<无>"])

	# ㋲ **我的装备一件都不许出现**
	#    护腰 = 我有他没有：这一格画出任何东西（图标 / 物品id / 我那 5 枚镶嵌的金钻）都是漏。
	_记(腰.icon == null, "他的护腰位没件，格子里却画出了图标 —— 画的是我的那件")
	_记(_格物品id(腰) == "", "护腰格的 物品id 是 %s，应为空（我的 01050011 漏过去了）" % _格物品id(腰))
	_记(not _层(腰, "蓝钻") and not _层(腰, "强化底"),
		"护腰格叠了我那件的强化角标（蓝钻/强化底）—— 覆盖层也走了我的表")

	# ㋳ 计数角标 = 他的数（紫 2 / 星 1 / 融 1），不是我的（我的那套也是 1/1/1 ⇒ 必须钉 2）
	var 栏 := 面板.get_node_or_null("装备栏") as Control
	for 对 in [["紫件数", "2"], ["满星件数", "1"], ["满融件数", "1"]]:
		var 根 := 栏.get_node_or_null("强化计数/%s" % 对[0]) as Control if 栏 != null else null
		var 字 := 根.get_node_or_null("数字") as Label if 根 != null else null
		_记(根 != null and 根.visible and 字 != null and 字.text == String(对[1]),
			"计数角标 %s 是 %s，应为他的 %s" % [对[0],
				字.text if 字 != null else "<没这个节点>", 对[1]])

	# ㋴ 立绘 = 他的脸（帧下标 6 = 2；`装备串`再全也不该把我的身体画上去）
	# ⚠ 10-25 起 `角色站立图` 不再是"一张站姿图"：窗里那具改成了**会播待机的角色精灵**——
	#    父节点自己挂着 `角色待机`（`OriginalSprite`，见 `人物窗口.gd:209-228`），父的 `texture`
	#    被**显式清空**（不改 `visible`，见那段注释里两个踩过的坑）。只查 `立.texture` 恒为 null
	#    ⇒ 本腿会假红。真值 = 播放器 `sprite.texture` 的 resource_path（美术缺帧时才会退回静图）。
	var 立 := 面板.get_node_or_null("角色站立图") as Control
	var 立路 := ""
	if 立 != null:
		var 播: Node = 立.get_node_or_null("角色待机")
		if 播 != null:
			var 画 = 播.get("sprite")
			if 画 is Sprite2D and (画 as Sprite2D).texture != null:
				立路 = (画 as Sprite2D).texture.resource_path
		if 立路.is_empty() and 立 is TextureRect and (立 as TextureRect).texture != null:
			立路 = (立 as TextureRect).texture.resource_path
	_记(立 != null and 立.visible and 立路.contains("00000002"),
		"看别人时立绘不是他那一帧的 2 号造型（%s）" % ("<没画出来>" if 立路.is_empty() else 立路))

	# ㋵ **只读**：20 格一条点击/拖放腿都不接（原版 `removeMouseEvents`），而且真点下去我的件不掉
	for 位置 in 部位.人物面板槽:
		var 格名 := String(人物窗.装备格节点[位置])
		var 格 := 容器.get_node_or_null(格名) as Button
		if 格 == null:
			_failures.append("⑩ 场景里缺装备格 %s —— 这条只读腿没法测" % 格名)
			continue
		_记(格.pressed.get_connections().is_empty(),
			"看别人的 %s 还接着 pressed（双击就会卸下**我的**件）" % 格名)
		var 信: Signal = 格.get("拖放")
		_记(信.get_connections().is_empty(), "看别人的 %s 还接着 拖放（能把背包物品塞进他的格子）" % 格名)
	var 我的手套 := 会话.get("equipped_items") as Dictionary
	var 手套前 := String((我的手套.get(部位.手套, {}) as Dictionary).get("id", ""))
	_记(手套前 == "01020020", "夹具把自己那双手套换掉了（实 %s）—— 下面那条点击腿失去意义" % 手套前)
	手.pressed.emit()
	手.pressed.emit()			# 连着发两次 = 原版那套双击时序
	await process_frame
	var 手套后 := String(((会话.get("equipped_items") as Dictionary).get(部位.手套, {}) as Dictionary).get("id", ""))
	_记(手套后 == 手套前,
		"点/双击他的手套格之后我的手套掉了（前 %s 后 %s，只读闸没关上）" % [手套前, 手套后])

	# 悬停提示**要留着**（原版摘的是点击系四条，ROLL_OVER 那条留着）
	_记(手.mouse_entered.get_connections().size() > 0 or 手.gui_input.get_connections().size() > 0,
		"他的装备格连悬停提示都没接了（原版 removeMouseEvents 不摘 ROLL_OVER）")

	# ㋱b 悬停提示里那行**绑定**必须是**他的**（用户报修原话就是「品质/绑定角标」；绑定不是格子上的
	#     角标、是 `装备提示框` 那行 `[已绑定]/[未绑定]`，取自负载第 7 段 canTrade ⇒ 只要提示框喂的是
	#     他的物品字典就连这条跟着换）。**方向按 AS3**：`canTrade` = 可交易
	#     （`MToolTipZhuangBei.as:829`：`canTrade ? 未绑定 : 已绑定`）⇒ 他那件 绑=0 ⇒「[已绑定]」、
	#     我那件 绑=1 ⇒「[未绑定]」，串窗才会显示成我的那句。
	var 页面 := 面板.get_parent() as Control
	var 装备框 := 页面.get_node_or_null("装备提示框") as Control
	if 装备框 == null:
		_failures.append("⑩ 页面根上没有「装备提示框」节点（绑定行无从验，接线只认这个节点名）")
	else:
		手.mouse_entered.emit()
		var 绑定行 := 装备框.get_node_or_null("绑定") as Label
		_记(装备框.visible, "悬停他的手套格没弹出装备提示框（他那扇的悬停腿断了）")
		_记(绑定行 != null and 绑定行.visible and 绑定行.text == "[已绑定]",
			"他的手套提示框那行绑定是 %s，应为「[已绑定]」（他那件负载 canTrade=0 = 不可交易；显示成「[未绑定]」= 喂了我的物品字典或极性反了）"
			% (绑定行.text if 绑定行 != null else "<没有绑定这个节点>"))

	# ㋺ **他一件没装**（29..33 全 `-`）⇒ 他那扇必须停在**空格子**，一格都不许回落我的。
	#     这条是 ㋰~㋱b 的配对腿：上面那七件非空，所以"表空不空"这种写法在那些腿里**测不出来**
	#     （`套装提示.已装()` 一旦从 `is Dictionary` 退成"空就回落 `会话.equipped_items`"，
	#      只有全空这一发会让紫件数亮起来 = 我的那 1 件）。
	#     原版 `CharOtherWindow2` 没装就是空格子，`setSeriesIcon(param1)` 那支喂的是**他的空数组**。
	var 空帧 := 帧.duplicate()
	for 下标 in [29, 30, 31, 32, 33]:
		空帧[下标] = "-"
	后端.call("_handle_character_info_text", PackedStringArray(空帧))
	await process_frame
	await process_frame
	var 面板3 := _找人物面板(窗)
	var 空档: Dictionary = (后端.get("他人详细信息") as Dictionary)
	_记((空档.get("装备", {}) as Dictionary).is_empty(),
		"29..33 全 `-` 时他的装备表解出 %d 件，应为 0" % (空档.get("装备", {}) as Dictionary).size())
	if 面板3 == null:
		_failures.append("⑩ 全空那帧之后页面重建失败")
	else:
		var 空容器 := 面板3.get_node("装备栏/装备格子容器") as Control
		for 位置 in 部位.人物面板槽:
			var 格 := 空容器.get_node_or_null(String(人物窗.装备格节点[位置])) as Button
			if 格 == null:
				continue
			_记(格.icon == null and String(格.get("物品id")) == "",
				"他一件没装，%s 却画出了我的件（图标 %s / 物品id %s）"
				% [String(人物窗.装备格节点[位置]),
					"有" if 格.icon != null else "无", String(格.get("物品id"))])
		var 空栏 := 面板3.get_node_or_null("装备栏") as Control
		for 名 in 计数角标:
			var 根 := 空栏.get_node_or_null("强化计数/%s" % 名) as Control if 空栏 != null else null
			_记(根 == null or not 根.visible,
				"他没一件装备，计数角标 %s 却亮着（那是我那套的数）" % 名)

	# ㋴b 最后一条（它会**重建整页**，所以放在所有引用旧页面节点的腿之后）：
	#     他的脸号**查无此美术**（5 号不在这工程 `数据/角色/动画素材索引.json` 里）⇒ 立绘该**留空**。
	#     场景里烘着的是**我的**那具身体 —— `图 == null` 时不清就等于"他的窗上站着我的角色"。
	var 缺帧 := 帧.duplicate()
	缺帧[6] = "5"
	后端.call("_handle_character_info_text", PackedStringArray(缺帧))
	await process_frame
	var 面板2 := _找人物面板(窗)
	var 立2: TextureRect = null
	if 面板2 != null:
		立2 = 面板2.get_node_or_null("角色站立图") as TextureRect
	_记(立2 != null and 立2.texture == null,
		"他脸号查不到美术时立绘还画着东西（%s）—— 那是烘在场景里的**我的**身体"
		% (立2.texture.resource_path if 立2 != null and 立2.texture != null else "<没有这个节点>"))

	会话.set("equipped_items", 原装)


func _层(格: Button, 名: String) -> bool:
	var 件 := 格.get_node_or_null(名) as CanvasItem
	return 件 != null and 件.visible


## 覆盖层"该不该在"分开记，失败时才说得出是**没建节点**还是**没显示**。
func _层在(格: Button, 名: String, 期望: bool, 说明: String) -> void:
	var 件 := 格.get_node_or_null(名) as CanvasItem
	if 期望:
		_记(件 != null and 件.visible, "%s（节点 %s）" % [说明, "没有" if 件 == null else "没显示"])
	else:
		_记(件 == null or not 件.visible, 说明)


func _格物品id(格: Button) -> String:
	return String(格.get("物品id"))


func _fail(说明: String) -> void:
	push_error("看别人属性窗：" + 说明)
	_还原档()
	quit(1)


## 按字节还原 `user://玩家数据.json` / `玩家设置.json`（开场那份）。
func _还原档() -> void:
	if not _文件前.is_empty():
		门存档快照.全还原(_文件前)


func _收尾() -> void:
	_还原档()
	if _failures.is_empty():
		print(("看别人属性窗回归测试：通过（%d 条断言：开窗 / 互斥 / 六格六行 / 三根条 / 四颗钮 / 真点击 / "
			+ "他的装备与六层角标 / 我的装备不漏一件 / 格子只读 / 第二帧不关窗）") % _已记)
		quit(0)
		return
	for 项 in _failures:
		push_error("看别人属性窗：" + 项)
	print("看别人属性窗回归测试：失败 %d / %d 条 —— %s" % [_failures.size(), _已记, ", ".join(_failures)])
	quit(1)
