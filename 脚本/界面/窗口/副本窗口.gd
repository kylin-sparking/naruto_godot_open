extends RefCounted
## 副本传送页（原版 `com/mxw/uifl/controls/copy/CopyWindow.as`，`super(570,283)` 在 `:69`）。
##
## 从 `系统窗口.gd` **切出来单独成件**（2026-10-03，与 `秘笈合成窗口.gd` / `宝石工艺窗口.gd`
## 同一条理由）：那份控制器 `preload` 了七八张不相干的场景，交包时要么一起拖走、要么在
## 融合方那边 `preload` 编译失败。
##
## ⚠ **这里不摆样式、不摆控件**：99 个节点全烘在 `.tscn`（由 `开发工具/生成副本场景.py` 从
## 量具表 `截副本页.gd` + `数据/副本.json` 生成 ⇒ 改真值改量具表再重跑生成器，别手改场景）。
## 旧版那 14 个节点的 `ItemList` + 两个 `Panel` 是 7 月的薄壳，四列布局/星级/滚动区/勾选
## 全不在，逐件出处 `game-client/真值/窗口/副本.md`。
##
## 三条运行期职责（原版同名函数的移植）：
##   * `setRightTextFieldData`（`:495-556`）⇒ 选中行换右侧「丰厚度星级 / 通关奖励 / 副本说明」
##     并按 `enter.needItemId > 0` 决定「副本密卷进入」露不露。
##   * `onClickCheckBox`（`:321-364`）⇒ 勾上只留「等级够 且 次数没用完」的行。
##   * `onClickComeInBtn`（`:558-579`）⇒ 两道校验后走**既有** `request_copy_open`。
##
## ⚠ **协议只走既有钩子**：「副本密卷进入」原版开 `FubenLingWindow` 并要服务端配合
## （`onClickFubenlingBtn:380-409`），本工程没有那条钩子 ⇒ 只给状态行回执，不发裸包。

const 副本场景 := preload("res://场景/界面/窗口/副本/副本窗口.tscn")
const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 文案路径 := "res://数据/界面/副本_文案.json"
const 配置路径 := "res://数据/副本.json"
const 物品路径 := "res://数据/物品.json"
const 行高 := 20
const 星宽 := 14
const 行高字 := 17		# Flash 12px 单行 textHeight；与 `生成副本场景.py` 同一条数

static var _宿主
static var _页: Control
static var _配置: Array = []
static var _文案: Dictionary = {}
static var _物品: Dictionary = {}
static var _选中 := 0
static var _过滤 := false
static var _已接行: Array[Control] = []


static func 渲染(宿主) -> void:
	_宿主 = 宿主
	if _配置.is_empty():
		_配置 = _读(配置路径).get("副本", []) as Array
	if _文案.is_empty():
		_文案 = _读(文案路径)
	_页 = _宿主._instantiate_page(副本场景)
	_已接行.clear()		# 场景是**新建**的一份 ⇒ 上一份的行引用已 free，留着会把新行判成"已接"
	_接钮()
	_接勾选()
	_填行()
	_选(clampi(_选中, 0, maxi(0, _配置.size() - 1)))


static func _物品名(编号: int) -> String:
	# 与 `开发工具/生成副本场景.py` 同源（都读 `数据/物品.json`）⇒ 通关奖励那串只有一份。
	if _物品.is_empty():
		_物品 = _读(物品路径)
	return String((_物品.get(str(编号), {}) as Dictionary).get("name", "物品%s" % 编号))


static func _读(路径: String) -> Dictionary:
	var f := FileAccess.open(路径, FileAccess.READ)
	if f == null:
		return {}
	var 体: Variant = JSON.parse_string(f.get_as_text())
	return 体 if typeof(体) == TYPE_DICTIONARY else {}


static func _行们() -> Array[Control]:
	var 出: Array[Control] = []
	var 容 := _页.get_node("列表/行容器") as Control
	for 子 in 容.get_children():
		if 子 is Control:
			出.append(子 as Control)
	return 出


static func _会话() -> Node:
	return _宿主._session if _宿主 != null else null


## 玩家等级 / 已用次数 / 上限 —— 全部走本工程既有状态，不新造数据。
static func _玩家等级() -> int:
	var 会 := _会话()
	return int(会.player_stats.get("level", 1)) if 会 != null else 1


static func _已用(编号: int) -> int:
	var 会 := _会话()
	return int(会.copy_history.get(编号, 0)) if 会 != null else 0


static func _上限(条: Dictionary) -> int:
	## `CopyWindowCell.as:111-118`：`enter.through > 0` 用它，否则用 `totalCount`
	## （=`setData` 第二参 = 服务端 819 帧的 `maximum`）。
	var 穿: int = int((条["enter"] as Dictionary).get("through", 0))
	if 穿 > 0:
		return 穿
	var 会 := _会话()
	return maxi(1, int(会.copy_total_count)) if 会 != null else 1


static func _组队(类型: String) -> String:
	return {"1": String(_文案.get("COPY_CELL_SINGLE", "")),
			"2": String(_文案.get("COPY_CELL_TEAM", "")),
			"3": String(_文案.get("COPY_CELL_TROOP", ""))}.get(类型, "")


## `setListData` + `onClickCheckBox`：每行四列重填，勾上时把不该露的行整行藏掉。
static func _填行() -> void:
	var 行们 := _行们()
	for i in 行们.size():
		var 行 := 行们[i]
		if i >= _配置.size():
			行.visible = false
			continue
		var 条: Dictionary = _配置[i]
		var 露 := true
		if _过滤:
			# `:336-346`：等级够 **且**（有 data 包装时）次数没用完
			露 = int(条["reqLevel"]) <= _玩家等级() and _已用(int(条["id"])) < _上限(条)
		行.visible = 露
		(行.get_node("名") as Label).text = String(条["name"])
		(行.get_node("等级") as Label).text = str(int(条["reqLevel"]))
		(行.get_node("组队") as Label).text = _组队(String(条["teamType"]))
		(行.get_node("次数") as Label).text = String(_文案.get("COPY_CELL_COUNT", "%1/%2次")) \
			.replace("%1", str(_已用(int(条["id"])))) .replace("%2", str(_上限(条)))
		(行.get_node("悬停底") as Control).visible = false
		(行.get_node("选中底") as Control).visible = 露 and i == _选中
		if 行 in _已接行:
			continue		# ⚠ 只接一次：`_过滤` 每次切换都会重跑 `_填行`，重复 connect 会叠监听
		_已接行.append(行)
		行.mouse_entered.connect(_悬停.bind(行, true))
		行.mouse_exited.connect(_悬停.bind(行, false))
		# ⚠  是**追加到参数表末尾**：gui_input 先递 event ⇒ 形参必须写成
		#   (事件, 序号)。上一版写成 (序号, 事件) ⇒ 实参错位，点行永远选不中（bug2）。
		行.gui_input.connect(_点行.bind(i))


static func _悬停(行: Control, 进: bool) -> void:
	if not is_instance_valid(行):
		return
	(行.get_node("悬停底") as Control).visible = 进


static func _点行(事件: InputEvent, 序号: int) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed \
			and (事件 as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_选(序号)


static func _接行() -> void:
	pass


## `setRightTextFieldData`（`:495-556`）：右侧三块 + 星级 + 密卷钮露出。
static func _选(序号: int) -> void:
	if _配置.is_empty() or 序号 >= _配置.size():
		return
	_选中 = 序号
	var 条: Dictionary = _配置[序号]
	for i in _行们().size():
		var 行 := _行们()[i]
		if 行.get_node_or_null("选中底") != null:
			(行.get_node("选中底") as Control).visible = bool(行.visible) and i == 序号
	var 内 := _页.get_node("详情滚动/详情内容") as Control
	var 奖 := 内.get_node("奖励") as RichTextLabel
	var 说 := 内.get_node("说明") as RichTextLabel
	(内.get_node("奖励标题") as Label).text = String(_文案.get("COPY_TONGGUAN_JIANGLI", ""))
	奖.text = "[color=#00ff00]" + _奖励纯文本(条) + "[/color]"
	说.text = "[color=#ff9100]" + _格式串(str(条["desc"])) + "[/color]"
	# `:544` copySay.y = 奖励.y + textHeight + 1（原版是 autoSize TextField）。
	# ⚠ **不要用 `reset_size()` / `get_content_height()`**：RichTextLabel 的 min 宽会被 autowrap
	#   压到很小 ⇒ 内容高暴涨（实测 2 行的奖励算出 1000+），把 说明 整个推到裁剪区之外，
	#   表现就是「副本说明凭空消失、门还全绿」。高度改成与生成器同一条 `行数 × 17`。
	奖.size = Vector2(170.0, float(_行数(_奖励纯文本(条), 170) * 行高字))
	说.position = Vector2(3.0, 17.0 + 奖.size.y + 1.0)
	说.size = Vector2(200.0, float(_行数(_格式串(str(条["desc"])), 200) * 行高字))
	内.custom_minimum_size = Vector2(224.0, maxf(142.0, 说.position.y + 说.size.y))
	_填星(float(条["stars"]))
	# `:546-553`：只有 `enter.needItemId > 0` 才露出「副本密卷进入」
	(_页.get_node("密卷钮") as Button).visible = int((条["enter"] as Dictionary).get("needItemId", 0)) > 0
	_刷状态钮()


## `BaseUtil.formatStr`（`BaseUtil.as:378-392`）：删掉「反斜杠 r」与真回车，再把
## 「反斜杠 n」（两个字符）换成真换行。⚠ 数据里的 desc 存的就是字面反斜杠 n ⇒
## 不套这一道，实机会把反斜杠 n 当正文画出来（2026-10-03 截图抓到）。
static func _格式串(文: String) -> String:
	文 = 文.replace("\\r", "").replace("\r", "")
	return 文.replace("\\n", "\n")


## 与 `开发工具/生成副本场景.py::行数` 逐字同一条：每行 `floor(宽/12)` 字（12px 宋体汉字满宽）。
static func _行数(文: String, 宽: int) -> int:
	var 每行 := maxi(1, int(宽 / 12.0))
	var 总 := 0
	for 段 in 文.split("\n"):
		总 += maxi(1, int(ceil(float(段.length()) / float(每行))))
	return 总


## `setRightTextFieldData:520-543`：无奖励先取 `FAMILLY_MANAGER_WU`，有则逐条
## `【物品名×数量】` 换行相接。⚠ 数量必须 `int()` 再转串 —— `JSON.parse_string` 把 100 解成
## 100.0 ⇒ 实机烘出「【手里剑木桩×100.0】」（2026-10-03 截图抓到）。
static func _奖励纯文本(条: Dictionary) -> String:
	var 奖: Array = 条.get("prize", []) as Array
	if 奖.is_empty():
		return String(_文案.get("FAMILLY_MANAGER_WU", ""))
	var 部: Array[String] = []
	for p in 奖:
		部.append("【%s×%d】" % [_物品名(int((p as Dictionary)["itemid"])),
				int((p as Dictionary)["quantity"])])
	return "\n".join(部)


## `newStars()`（`:279-314`）：`ceil(stars)` 枚亮，末枚只在 `stars == ceil` 时才用实心。
static func _填星(星数: float) -> void:
	var 容 := _页.get_node("星容器") as Control
	var 枚 := int(ceil(星数))
	var i := 0
	for 子 in 容.get_children():
		if not (子 is TextureRect):
			continue
		var 槽 := 子 as TextureRect
		var 该: bool = i < 枚
		槽.visible = 该
		if 该:
			var 实: bool = i < 枚 - 1 or (i == 枚 - 1 and 星数 == float(枚))
			槽.texture = load("res://素材/界面/原版窗口/副本/%s.png" % ("星实心" if 实 else "星空心"))
			槽.position = Vector2(float(i) * 星宽, 0)
		i += 1


static func _接钮() -> void:
	(_页.get_node("进入钮") as Button).pressed.connect(_进入)
	(_页.get_node("密卷钮") as Button).pressed.connect(_密卷)
	# 本工程既有的 819 流程三枚钮（原版没有 ⇒ 静止隐藏，只在对应状态下露出）
	(_页.get_node("确认钮") as Button).pressed.connect(func(): _会话().request_copy_confirm(true))
	(_页.get_node("取消钮") as Button).pressed.connect(func(): _会话().request_copy_confirm(false))
	(_页.get_node("领取钮") as Button).pressed.connect(func(): _会话().request_copy_reward(_当前编号()))


static func _接勾选() -> void:
	var 勾 := _页.get_node("勾选") as CheckBox
	勾.text = String(_文案.get("COPY_MCHECK", ""))
	勾.toggled.connect(func(开: bool):
		_过滤 = 开
		_填行()
		_选(clampi(_选中, 0, maxi(0, _配置.size() - 1))))


static func _当前编号() -> int:
	return int((_配置[_选中] as Dictionary)["id"]) if _选中 < _配置.size() else -1


## `onClickComeInBtn`（`:558-579`）：先等级、再次数，两道都不过就只出原话提示。
static func _进入() -> void:
	var 会 := _会话()
	if 会 == null:
		return
	var 条: Dictionary = _配置[_选中]
	if _玩家等级() < int(条["reqLevel"]):
		_宿主._show_hint(String(_文案.get("COPY_DENGJI_TAIDI", "")))
		return
	if _已用(int(条["id"])) >= _上限(条):
		_宿主._show_hint(String(_文案.get("COPY_MINGTIAN_JIXU", "")))
		return
	_宿主._show_hint("正在请求进入副本")
	会.request_copy_open(int(条["id"]))


## `onClickFubenlingBtn`（`:380-409`）：原版要开 `FubenLingWindow`（另一扇窗 + 服务端配合）。
## 本工程没有那条钩子 ⇒ 只把原版那三句提示照说，**不发裸包、不自造密卷窗**。
static func _密卷() -> void:
	var 条: Dictionary = _配置[_选中]
	var 用: int = int((条["enter"] as Dictionary).get("needItemId", 0))
	if _已用(int(条["id"])) < _上限(条):
		_宿主._show_hint(String(_文案.get("COPY_SHIYONG_WANMIJUAN_JINRU", "")))
	elif _玩家等级() < int(条["reqLevel"]):
		_宿主._show_hint(String(_文案.get("COPY_DENGJI_TAIDI", "")))
	elif 用 <= 0:
		_宿主._show_hint(String(_文案.get("COPY_BUNENG_MIJUAN_JINRU", "")))
	else:
		# 原版 `onClickFubenlingBtn:380-409` → 开 `FubenLingWindow.setData(第次, copyId)`：
		#   第次 = `curCopycount − maxCopycount + 1`；需要数 = **`2^(第次−1)`**（:221 那句 %3）；
		#   「确定」⇒ `onComeinCopy`（`UI.as:1632-1642`）→ **`requestCopy_open(copyId)`** ——
		#   就是本工程已有的动作 1。服务端 `_request_copy_entry` 会按 `_copy_repeat_requirement`
		#   扣密卷（不够就回"再次进入需要 N 个副本令"）。
		# ⚠️ 这里原来写的是"要服务端 819 的密卷子命令，本工程未接（待点头）" —— **假缺口**（§3.122）。
		var 第次: int = _已用(int(条["id"])) - _上限(条) + 1
		var 需要数: int = int(pow(2.0, float(第次 - 1)))
		var 文 := String(_文案.get("FUBENLING_COUNT", ""))
		文 = 文.replace("%1", str(第次)).replace("%2", String(条.get("name", ""))).replace("%3", str(需要数))
		var 题 := String(_文案.get("FUBENLING_WINDOW_TITLE", ""))
		var 会2 := _会话()
		_宿主._弹出确认(题, 确认弹.文案转BBCode(文), String(_文案.get("COPY_JINRU", "进入")), func() -> void:
			# 原版 `updateItemCount:227-243`：背包里不够 `2^(第次−1)` 就把「确定」灰掉。
			# 我们那颗确认键没有禁用态 ⇒ 改成点下去先判一句（服务端也会再判一次）。
			if int(_宿主._背包数量(用)) < 需要数:
				_宿主._show_hint("很抱歉，你的副本密卷不够")
				return
			# ⚠️ 会话那条 `request_copy_open` 会**返回布尔**（离线时是 false）——
			#    不看返回值就是"点了没反应"那种静默空转（本工程一直在治的形状）。
			if 会2 == null or not 会2.request_copy_open(int(条["id"])):
				_宿主._show_hint("进入副本要在服务端结算（离线不模拟）")
		)


## 819 回包状态 ⇒ 三枚流程钮的露出（沿用 `系统窗口` 原来那套 pending/completed 判据）。
static func _刷状态钮() -> void:
	var 会 := _会话()
	if 会 == null:
		return
	var 态: Dictionary = 会.copy_state
	var 待: int = int(态.get("pending_copy_id", -1))
	var 完: int = int(态.get("completed_copy_id", -1))
	var 当 := _当前编号()
	var 确认 := _页.get_node("确认钮") as Button
	var 取消 := _页.get_node("取消钮") as Button
	var 领取 := _页.get_node("领取钮") as Button
	确认.visible = 待 == 当
	取消.visible = 待 == 当
	领取.visible = 完 == 当 and 待 != 当
