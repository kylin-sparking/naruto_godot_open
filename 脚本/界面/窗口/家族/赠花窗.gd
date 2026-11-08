extends RefCounted
## 赠花窗（原版 `MarryZengHuaWindow extends UIWindow`，本工程页名「赠花」）控制器。
## 逐件真值：`真值/窗口/赠花窗.md`（页 550×386 = 整窗 415 减 29 标题栏）。
##
## 这一扇的**数据分两半**，别记混：
## · **对面是谁**（号 / 名 / 级 / 脸）在**点菜单那一刻**就定下来了
##   （`MarryTableManager.openMarryZengHuaWindow:184-197` 把四项存进自己身上，**窗还不开**）；
## · **友好度、统计、五条记录、三档花**全部来自回帧 `58:2`
##   （`receiveRefreshFlowerWindow:326-344` 里才 `setDOShow(MARRY_ZENGHUA_WINDOW, true)`）⇒
##   **开窗的是回帧，不是点击**（`窗口管理._on_花档帧`）。
##
## 记录格那两列「加为好友 / 回赠」在**这一扇里恒藏**：`updateView(条, false)`（`MarryZengHuaWindow:196`），
## 只有 `MyFlowerWindow`（本工程还没那扇）传 true 才露出来。

const 富文本 := preload("res://脚本/界面/富文本.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

## ── 文案（`en_US$message_properties.as` 原样，`<font color = "#…">` 那套由 `译文为BBCode` 折）──
const 标题文字 := "赠花"						# ZENGHUA_WINDOW_TITLE
const 档案文案 := "角色名：%1<br/>角色等级：%2<br/>友好度：%3"		# ZENGHUA_CHAR_INFO_TXT
const 统计文案 := "今日收到次数：%1/20      本周收到：%2朵 总数：%3朵"	# ZENGHUA_RECEIVE_INFO
const 说明文案 := '<font color = "#1e90ff">说明：</font><br><font color = "#fff000">1.每天只可进行一次赠花<br>2.玫瑰花可由日环任务获得，蓝色妖姬可在商城购买获得</font>'	# ZENGHUA_SHUOMING_TXT
const 赠送文字 := "赠送"						# ZENGHUA_BUTTON_TXT（不是"送花"）
const 购买文字 := "购买"						# SHOP_BUY
const 玫瑰花文案 := "<font color = '#fff000'>赠送%1朵玫瑰花</font><br/><font color = '#1e90ff'>友好度：</font>%2<br/><font color = '#1e90ff'>经验：</font>%3<br/><font color = '#1e90ff'>花费：</font>%4"	# ZENGHUA_DESC_TEXT
const 妖姬文案 := "<font color = '#fff000'>赠送蓝色妖姬</font><br/><font color = '#1e90ff'>友好度：</font><font color = \"#FF5498\">%1</font><br/>(商城可购买)"	# ZENGHUA_YAOJI_DESC_TEXT
const 元宝单位 := "元宝/点券"					# BUYEQP_WINDOW_UNIT
const 金币单位 := "金币"						# CHARACTOR_GOLD_COIN
const 记录文案 := "<font color = '#1e90ff'>%1</font>赠送了[%2朵玫瑰花]"	# ZENGHUA_INFO_LOG
const 妖姬记录文案 := "<font color = '#1e90ff'>%1</font>赠送了[%2朵蓝色妖姬]"	# ZENGHUA_INFO_YAOJI_LOG
const 时间刚刚 := "刚刚"						# ZENGHUA_INFO_TIME_1
const 时间分 := "%1分钟前"						# ZENGHUA_INFO_TIME
const 时间时 := "%1小时前"						# ZENGHUA_INFO_XIAOSHI_TIME
const 时间天 := "%1天前"						# ZENGHUA_INFO_TIAN_TIME
const 收到花文案 := "恭喜你收到玩家<font color = '#00ff00'>%1</font>送来的<font color = '#00ff00'>%2</font>朵玫瑰花！"	# ZENGHUA_RECEIVE_TIP
const 收到妖姬文案 := "恭喜你收到玩家<font color = '#00ff00'>%1</font>送来的<font color = '#00ff00'>%2</font>朵蓝色妖姬！"	# ZENGHUA_RECEIVE_YAOJI_TIP
const 没这个号 := "还没连上线，赠花要等进游戏之后再点。"

## 原版 `MarryZengHuaWindow` 的两个私有常量（`:23-25`）：立绘摆位 = `宽>>1` 与 `高−35`。
const 立绘宽 := 146
const 立绘高 := 208

## 记录格 / 花格各几个（`:143` 与 `:153-169` 那两个 while；花格是 2×2 里 break 掉右下角 ⇒ 三格）。
const 记录格数 := 5
const 花格数 := 3


## 建页 + 灌数据。`数` = `{"对面": {charId,name,face,level}, "档": authoritative_flower}`。
static func 渲染(宿主: Node, 场景: PackedScene, 数: Dictionary) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	var 对面: Dictionary = 数.get("对面", {}) as Dictionary
	var 档: Dictionary = 数.get("档", {}) as Dictionary
	## 友好度走**回帧**（`receiveRefreshFlowerWindow:329` `this.youHaoDu = param1.youhaodu`），
	## 名/级/脸走**点击那刻存的对面**（`updateView:183-185` 取的正是 Manager 上那三个字段）。
	var 名 := String(对面.get("name", ""))
	var 级 := int(对面.get("level", 0))
	var 友好 := int(档.get("youhaodu", 0))
	(页.get_node("档案文字") as RichTextLabel).text = 富文本.译文为BBCode(
			_填(档案文案, [名, 级, 友好]))
	## 统计三参的**顺序**是原版的 `count, weeklyFlowers, totalFlowers`（`:187`）——
	## `%1` 是"今日收到次数"，不是总朵数，抄串时最容易自己排错的一位。
	(页.get_node("收花统计") as Label).text = _填(统计文案, [
			int(档.get("count", 0)), int(档.get("weeklyFlowers", 0)), int(档.get("totalFlowers", 0))])
	(页.get_node("说明文字") as RichTextLabel).text = 富文本.译文为BBCode(说明文案)
	_接立绘(页, 对面, 档)
	_刷记录(页, 档)
	_刷花格(宿主, 页, 对面, 档)
	return 页


## `%1..%n` 逐个换（原版 `CN.replaceString`，AS3 的整数除在这里都用 `int()` 显式写出来）。
static func _填(串: String, 参: Array) -> String:
	var 文 := 串
	for i in 参.size():
		文 = 文.replace("%%%d" % (i + 1), _印(参[i]))
	return 文


## AS3 把 Number 塞进文案时**不印小数点**（`1234.0` → "1234"），而我们的经验是 `float()` 解出来的
## ⇒ 整值就按整数印。别的值原样。
static func _印(值: Variant) -> String:
	if 值 is float:
		var 浮 := float(值)
		return str(int(浮)) if 浮 == floorf(浮) else str(浮)
	return str(值)


## 立绘是**活的**（`setImgChar:210-218` 用 `getCharAliveLookJustFace` + `customHander.addTick`），
## 不是静态头像那张。脸取自"对面是谁"（原版 `MarryTableManager.receiveFace`），
## 回帧里那份 `face` 只在没有点击缓存时兜底（同一个服务端账号，两个值同源）。
static func _接立绘(页: Control, 对面: Dictionary, 档: Dictionary) -> void:
	var 容 := 页.get_node("立绘框") as Control
	for 子 in 容.get_children():
		容.remove_child(子)
		子.queue_free()
	var 脸 := int(对面.get("face", 0))
	if 脸 <= 0:
		脸 = int(档.get("face", 0))
	if 脸 <= 0:
		return
	var 角 := OriginalSprite.new()
	if 角.configure("character", str(脸).pad_zeros(8), "stand"):
		## `:213-214` = `CHAR_WIDTH >> 1` 与 `CHAR_HEIGHT − 35`，都摆在 `charBg` 框内。
		角.position = Vector2(float(立绘宽 >> 1), float(立绘高 - 35))
		容.add_child(角)
		角.play("stand")


## 五条收花记录（`:189-198`：`_loc6_ = min(记录数, 5)`，**只有前 min 个格子被灌**，
## 剩下的格子底板照画、正文空着 —— 原版这里就是"上一句留着"，第一次开窗时那是空串）。
static func _刷记录(页: Control, 档: Dictionary) -> void:
	var 记录: Array = 档.get("flowerDayLogInfo", []) as Array
	for i in 记录格数:
		var 格 := 页.get_node("记录_%d" % i) as Control
		var 内容 := 格.get_node("内容") as RichTextLabel
		var 时刻 := 格.get_node("时间") as Label
		## 「加为好友 / 回赠」这两列**本窗恒藏**（`MarryZengHuaWindow:196` 传的是 false）。
		(格.get_node("加为好友") as Control).visible = false
		(格.get_node("回赠") as Control).visible = false
		if i >= 记录.size():
			内容.text = ""
			时刻.text = ""
			continue
		var 条: Dictionary = 记录[i] as Dictionary
		## 妖姬那一档走另一句（`LogCell:107-113`，判据是**花号**，不是朵数）。
		var 是妖姬 := int(条.get("flowerid", 0)) == _妖姬号()
		内容.text = 富文本.译文为BBCode(_填(妖姬记录文案 if 是妖姬 else 记录文案, [
				## `%1` 后面原版**多带一个空格**（`param1.senderName + " "`），照抄。
				String(条.get("senderName", "")) + " ", int(条.get("count", 0))]))
		时刻.text = _时间(int(条.get("sendTime", 0)))


## 时间那一列的四档（`MarryZengHuaLogCell:115-139`）。⚠ 进来的是**经过秒**，不是墙上时钟：
## 原版直接拿它 `<60 ⇒ 刚刚`、再 `/60 /60 /24` 逐级整数除。服务端在 `_flower_send_elapsed`
## 里就把绝对时间戳换成了秒，客户端这一段才敢做成纯函数被门逐档钉住。
static func _时间(经过秒: int) -> String:
	if 经过秒 < 60:
		return 时间刚刚
	var 分 := int(经过秒 / 60)
	if 分 < 60:
		return _填(时间分, [分])
	var 时 := int(分 / 60)
	if 时 < 24:
		return _填(时间时, [时])
	return _填(时间天, [int(时 / 24)])


## 三档花格（`:199-207` 按 `flowerInfo[i]` **顺位**摆，解析器已按 `youhaodu` 升序排过
## ⇒ 恒是 1 朵 → 20 朵 → 99 朵蓝妖姬，这里不许再排一次）。
static func _刷花格(宿主: Node, 页: Control, 对面: Dictionary, 档: Dictionary) -> void:
	var 列表: Array = 档.get("flowerInfo", []) as Array
	var 号 := int(对面.get("charId", 0))
	for i in 花格数:
		var 格 := 页.get_node("花格_%d" % i) as Control
		var 条: Dictionary = {}
		if i < 列表.size():
			条 = 列表[i] as Dictionary
		var 花号 := int(条.get("flowerid", 0))
		var 朵 := int(条.get("count", 0))
		var 经验: float = float(条.get("exp", 0.0))
		var 花费 := int(条.get("cost", 0))
		var 友好 := int(条.get("youhaodu", 0))
		(格.get_node("图标") as TextureRect).texture = 游戏数据.item_icon(花号) if 花号 > 0 else null
		## `Cell:102-112`：**朵数 > 1 且不是妖姬**才有角标、花费单位才是"元宝/点券"；
		## 1 朵玫瑰那一格**没有角标**、单位写"金币" —— 不是漏画，是原版就分这一岔。
		var 是妖姬 := 花号 > 0 and 花号 == _妖姬号()
		var 有角标 := 花号 > 0 and 朵 > 1 and not 是妖姬
		var 标 := 格.get_node("角标") as Label
		标.visible = 有角标
		标.text = str(朵) if 有角标 else ""
		var 单位 := 元宝单位 if 有角标 else 金币单位
		## 妖姬那一档「购买」才露（`Cell:116`），其余三档那颗是**藏**起来的。
		(格.get_node("购买钮") as Control).visible = 是妖姬
		var 正文 := ""
		if 花号 > 0:
			## 非妖姬那一支外面还裹一层白、**末尾再拼单位**（`Cell:122`）；妖姬那支没有这层裹。
			if 是妖姬:
				正文 = 富文本.译文为BBCode(_填(妖姬文案, [友好]))
			else:
				正文 = 富文本.译文为BBCode("<font color='#ffffff'>"
						+ _填(玫瑰花文案, [朵, 友好, 经验, 花费]) + 单位 + "</font>")
		(格.get_node("描述") as RichTextLabel).text = 正文
		(格.get_node("赠送钮/文字") as Label).text = 赠送文字
		(格.get_node("购买钮/文字") as Label).text = 购买文字
		(格.get_node("赠送钮") as TextureButton).pressed.connect(_点赠送.bind(宿主, 号, 朵))
		(格.get_node("购买钮") as TextureButton).pressed.connect(_点购买.bind(宿主, 花号))
		for 颗 in ["赠送钮", "购买钮"]:
			绑三态(格.get_node(颗) as TextureButton)


## ── MButtonF 三态（同 `求婚窗` / `家族邀请窗` 那两扇的口径，理由在那边写完）──
## 只换 `texture_normal`，**不用** `texture_hover` / `texture_pressed`：Godot 松手后只要鼠标还悬着
## 会停在 hover 档，而原版 `mouseUpHandler:103-108` 回的是 STATE_UP。
const 态后缀 := ["", "_悬停", "_按下", "_灰"]
## `MButton3.as:69-74` `_textColors`（up/over/down/disabled）。
const 态文字色 := [Color(0.988235, 0.956863, 0.611765, 1), Color(1, 1, 0.764706, 1),
		Color(0.67451, 0.67451, 0.698039, 1), Color(0.576471, 0.576471, 0.576471, 1)]

static func 绑三态(钮: TextureButton) -> void:
	if 钮 == null or not 钮.has_meta("skin"):
		return
	钮.mouse_entered.connect(设态.bind(钮, 1))
	钮.mouse_exited.connect(设态.bind(钮, 0))
	钮.button_down.connect(设态.bind(钮, 2))
	钮.button_up.connect(设态.bind(钮, 0))
	设态(钮, 0)


static func 设态(钮: TextureButton, 态: int) -> void:
	if 钮 == null or not 钮.has_meta("skin"):
		return
	var 皮: String = String(钮.get_meta("skin")) + 态后缀[3 if 钮.disabled else 态] + ".png"
	if not ResourceLoader.exists(皮):
		return
	钮.texture_normal = load(皮) as Texture2D
	var 文字 := 钮.get_node_or_null("文字") as Label
	if 文字 != null:
		文字.add_theme_color_override("font_color", 态文字色[3 if 钮.disabled else 态])


## 蓝色妖姬的物品号，**取自原版烘的那张表**（`ImgUtil.getImg(ImgType.Etc,"flower").rosebuleid`，
## 本地导出在 `数据/原版杂项.json` 的 `flower` 段）。原版判妖姬从头到尾用的都是这一个值
## （`Cell:102/114`、`LogCell:107`、`Manager:269`），所以这里也只认表、不在代码里写死号。
static func _妖姬号() -> int:
	var 表: Dictionary = 游戏数据.取表("原版杂项") as Dictionary
	var 花: Dictionary = 表.get("flower", {}) as Dictionary
	return int(花.get("rosebuleid", 0))


## 点托盘「收到鲜花」那一格弹的那句（`MarryTableManager.xianhuaHandler:256-280`）。
## ⚠ 妖姬那一句的判据是**花号 == 妖姬 或 朵 == 99**（`:271` 那个 `||`）—— 两条都算，
## 因为服务端结算帧里 99 朵那一档本来就等价于一朵妖姬，原版宁可判两遍也不肯漏。
## 返回**已经翻好的 BBCode**，`窗口管理` 直接递给 `模态确认弹.弹出`。
static func 收花文案(条: Dictionary) -> String:
	var 是妖姬 := int(条.get("flowerid", 0)) == _妖姬号() or int(条.get("count", 0)) == 99
	return 富文本.译文为BBCode(_填(收到妖姬文案 if 是妖姬 else 收到花文案, [
			String(条.get("senderName", "")), int(条.get("count", 0))]))


## 「赠送」⇒ `Cell:158-161` `zengHuaFunc(flowerNum)` → `Manager.requestZengHua:160-163`
## → `Friend_requestSendFlower` = **`127:39:<对面号>:<朵>`**。
## ⚠ 原版点完**不关窗、也不重查档**：统计那几项要等下一次开窗才更新，这里照它。
## 钱不够 / 今天送过了 / 对方收满了，全是服务端回的那句提示，客户端不替它预判。
static func _点赠送(宿主: Node, 号: int, 朵: int) -> void:
	var 后 := _后端(宿主)
	if 号 <= 0 or 后 == null or not bool(后.call("get", "in_game")):
		_提示(宿主, 没这个号)
		return
	后.call("request_send_flower", 号, 朵)


## 「购买」= `Cell:82-85` `API.client.requestCashItemInfo(花号, 0)` ⇒ 按物品号开点券商城那一页。
## 本工程商城那条分页链还没接（同 `求婚窗._点购买`），**这里不自己造商店**：话要说实。
static func _点购买(宿主: Node, 花号: int) -> void:
	_提示(宿主, "点券商城按物品号开页还没接（原版是 requestCashItemInfo(%d, 0)）" % 花号)


static func _提示(宿主: Node, 话: String) -> void:
	var 树 := Engine.get_main_loop() as SceneTree
	if 树 == null:
		return
	var 会话 := 树.root.get_node_or_null("GameSession")
	if 会话 != null and 会话.has_signal("notification_requested"):
		会话.notification_requested.emit(话)


## ⚠ 必须写 `var 后: Node = ...` 这种**带类型**的接法：`Engine.get_main_loop()` 回来的是 MainLoop，
## 链式 `.root` 是 Variant ⇒ `:=` 推不出类型直接 parse 失败，而这份脚本是 功能窗口.gd preload 进来的
## ⇒ 一坏就把整个功能窗口拖死（实测，同 `家族邀请窗.gd` 那条）。
static func _后端(_宿主: Node) -> Node:
	var 树 := Engine.get_main_loop() as SceneTree
	return 树.root.get_node_or_null("BackendConnection") if 树 != null else null
