extends RefCounted
## 求婚窗（原版 `ProposalWindow extends MWindow`，本工程页名「羁绊申请」）控制器。
## 逐件真值：`真值/窗口/求婚窗.md`（页 388×446 = 整窗 475 减 29 标题栏）。
##
## 这一扇**两档共用一个场景**，由 `是被求` 切：
## · 发起档（`_isProposa = false`，`ProposalWindow.as:64-69`）：标题「发起羁绊」、
##   主钮「建立羁绊」、次钮「关闭」（**只关窗、不发帧**），底下「放入羁绊戒 / 购买羁绊戒」两颗**看得见**；
## · 被求档（`true`，`:56-61`）：标题「羁绊确认」、主钮「同意请求」、次钮「拒绝」（发 `127:22`），
##   那两颗**隐藏**（`ProposaBottomWindow.as:201-204` `visible = !param1`）。
##
## 触发链两条，形状不一样，别统一：
## ① 我点菜单「羁绊」⇒ `127:15:<对方号>` ⇒ 服务端回 `61:14` ⇒ **直接开我这侧这扇**（`onFriend_taStart:9500`）；
## ② 别人求我 ⇒ `61:17` ⇒ **只塞头顶托盘那一格**（`Client.as:7883` → `CueGird.TYPE_QIUHUN`），点那一格才开（被求档）。

const 职业表 := preload("res://脚本/单例/职业.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

const 标题发起 := "发起羁绊"				# PROPOSA_WINDOW_TITLE
const 标题被求 := "羁绊确认"				# PROPOSA_WINDOW_TITLE_OK
const 查资料文字 := "查看信息"				# POPUP_QUERY
const 主钮发起 := "建立羁绊"				# PROPOSA_WINDOW_QIUHUN
const 主钮被求 := "同意请求"				# PROPOSA_WINDOW_TONGYI_QIUHUN
const 次钮发起 := "关闭"					# DIALOG_BTN_STOP_DIALOG
const 次钮被求 := "拒绝"					# REMITCOPY_DECLINE
const 心意发起 := "请问您是希望向TA发出羁绊请求吗？"	# CHARINFO_PANE_TISHI_TEXT_2
const 心意被求 := "TA向您出示了心意，您愿意与TA建立羁绊吗？"	# CHARINFO_PANE_TISHI_TEXT_1
const 说明发起 := "您需要先拥有羁绊对戒以示心意"	# PROPOSA_WINDOW_NI_XUEYAO_CHENGYI
const 说明被求 := "TA为您呈上的羁绊对戒是："		# PROPOSA_WINDOW_TA_WEINI_FENGXIAN_JIEZHI
const 放入文字 := "放入羁绊戒"				# FANGRU_DINGQING_JIEZHI_BTN_TEXT
const 购买文字 := "购买羁绊戒"				# GOUMAI_DINGQING_JIEZHI_BTN_TEXT
const 没放对戒 := "请先放入羁绊对戒"			# QINGFANGRU_DINGQINGDUIJIE（`ProposalWindow.as:82`）
const 发出去了 := "羁绊请求已发送！等待过程中，不妨送TA些小礼物哦！"	# QIUHUN_QINGJIU_YIFANGCONG（`:91`）

## 四行前缀（`CharInfoPane.setData:73-79` 都是 `语言(键) + "：" + 值`，冒号在代码里补）。
const 名字前 := "名字"					# CHARACTOR_NAME
const 等级前 := "等级"					# FAMILLY_GONGXIAN_WINDOW_LEVEL
const 职业前 := "职业"					# CHARACTOR_JOB
const 家族前 := "家族"					# FAMILLY__WINDOW_TITLE


## 建页 + 填数据 + 接五颗钮。`数` = `{"是被求": bool, "人": Dictionary}`（人 = `61:14/17` 解出来的那份）。
static func 渲染(宿主: Node, 场景: PackedScene, 数: Dictionary) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	var 人: Dictionary = 数.get("人", {}) as Dictionary
	var 是被求 := bool(数.get("是被求", false))
	## 标题两档不同（`:56/64`），尺寸表里那条只当默认档 ⇒ 每次渲染都按档改写（`功能窗口.设置标题`）。
	宿主.call("设置标题", 标题被求 if 是被求 else 标题发起)
	(页.get_node("名字") as Label).text = 名字前 + "：" + String(人.get("name", ""))
	(页.get_node("等级") as Label).text = 等级前 + "：" + str(int(人.get("level", 0)))
	(页.get_node("职业") as Label).text = 职业前 + "：" + 职业表.取(int(人.get("job", 0)))
	(页.get_node("家族") as Label).text = 家族前 + "：" + String(人.get("banghui", ""))
	(页.get_node("心意提示") as Label).text = 心意被求 if 是被求 else 心意发起
	(页.get_node("说明白字") as Label).text = 说明被求 if 是被求 else 说明发起
	(页.get_node("查看资料钮/文字") as Label).text = 查资料文字
	(页.get_node("主钮/文字") as Label).text = 主钮被求 if 是被求 else 主钮发起
	(页.get_node("次钮/文字") as Label).text = 次钮被求 if 是被求 else 次钮发起
	## `ProposaBottomWindow.isProposa:201-204`：被求那一侧这两颗**不显示**（不是禁用、是 `visible = false`）。
	(页.get_node("放入钮") as Control).visible = not 是被求
	(页.get_node("购买钮") as Control).visible = not 是被求
	## 头像：`CharInfoPane.setHeadIcon:59-71` = `PortraitHead(true, 54−5, 54−5, TYPE_CHAR)`，
	## 摆在格内 `((54−49)>>1, (54−49)>>1)` = **(2,2)** —— 这条是字面算式，没有偏离（49 塞 54 的格）。
	var 脸 := str(int(人.get("face", 1))).pad_zeros(8)
	(页.get_node("头像格/头像") as TextureRect).texture = OriginalSprite.portrait("character", 脸)
	## 第一格 = 那件**定情对戒**：发起档取自己背包里挑出来的那件（挑不到就空着，见 `_挑对戒`），
	## 被求档取帧里带的 `item`（`61:17` 末段）。空着是原版的画法（没放东西时那格就是空的）。
	var 戒指号 := int(人.get("item", 0))
	(页.get_node("对戒格/对戒图") as TextureRect).texture = 游戏数据.item_icon(戒指号) if 戒指号 > 0 else null
	var 号 := int(人.get("charId", 0))
	(页.get_node("查看资料钮") as TextureButton).pressed.connect(_点查资料.bind(号))
	(页.get_node("主钮") as TextureButton).pressed.connect(_点主.bind(宿主, 是被求, 号, 戒指号))
	(页.get_node("次钮") as TextureButton).pressed.connect(_点次.bind(宿主, 是被求, 号))
	(页.get_node("放入钮") as TextureButton).pressed.connect(_点放入.bind(宿主, 页))
	(页.get_node("购买钮") as TextureButton).pressed.connect(_点购买.bind(宿主))
	for 颗 in ["查看资料钮", "主钮", "次钮", "放入钮", "购买钮"]:
		_绑三态(页.get_node(颗) as TextureButton)
	return 页


## ── MButtonF 三态（`MButtonF extends MButton3` ⇒ 一张皮 + 运行时加性滤镜，不是四张皮）──
## 只换 `texture_normal`，**不用** `texture_hover` / `texture_pressed`：Godot 松手后只要鼠标还悬着
## 会停在 hover 档，而原版 `mouseUpHandler:103-108` 回的是 STATE_UP（不移出鼠标就不再亮）。
const 态后缀 := ["", "_悬停", "_按下", "_灰"]
## `MButton3.as:69-74` `_textColors`（up/over/down/disabled）。
const 态文字色 := [Color(0.988235, 0.956863, 0.611765, 1), Color(1, 1, 0.764706, 1),
		Color(0.67451, 0.67451, 0.698039, 1), Color(0.576471, 0.576471, 0.576471, 1)]

static func _绑三态(钮: TextureButton) -> void:
	if 钮 == null or not 钮.has_meta("skin"):
		return
	钮.mouse_entered.connect(_设态.bind(钮, 1))
	钮.mouse_exited.connect(_设态.bind(钮, 0))
	钮.button_down.connect(_设态.bind(钮, 2))
	钮.button_up.connect(_设态.bind(钮, 0))
	_设态(钮, 0)


static func _设态(钮: TextureButton, 态: int) -> void:
	if 钮 == null or not 钮.has_meta("skin"):
		return
	var 皮: String = String(钮.get_meta("skin")) + 态后缀[3 if 钮.disabled else 态] + ".png"
	if not ResourceLoader.exists(皮):
		return
	钮.texture_normal = load(皮) as Texture2D
	var 文字 := 钮.get_node_or_null("文字") as Label
	if 文字 != null:
		文字.add_theme_color_override("font_color", 态文字色[3 if 钮.disabled else 态])


## 从**自己的背包**里挑一件完整对戒（服务端认的那八个号 `190[1-8]0001`，且必须在背包格上）。
## 参照服务端 `_is_bond_pair_item:22926-22928` + `_bond_pair_item:22930-22938` 的同一道闸 ——
## 客户端先按同一条筛，挑不到就一句话说明，**不发一发注定被服务端丢掉的帧**。
## ⚠ 原版是「点放入钮 ⇒ 变成取件光标 ⇒ 到背包里点那一件」（`CursorManager.showCursorUI("ShopBuyCursorF")`
## + `ItemWindow2.as:1738-1742`）。那套游标本工程没接（真值表 §⑥.2 等点头），
## 这里改成「按钮直接从背包挑第一件符合的对戒」—— **少了一次拖放、不新增任何原版没有的界面**。
static func _挑对戒(后: Node) -> int:
	if 后 == null:
		return 0
	for 件 in (后.get("authoritative_inventory") as Array):
		if not (件 is Dictionary):
			continue
		## ⚠ 键名认的是**服务端 58 帧解出来那一份**（`后端连接._parse_item_entry:4349-4352`：
		## `id` / `slot_index` / `quantity`），不是 `item_id` / `position` / `count`。
		## 10-17 第一版就是照抄了自己代码里自造的三个键 ⇒ 离线门喂的假字典与它**一起错、互相印证**，
		## 真机上「放入羁绊戒」永远回"请先放入羁绊对戒"（这只有在线门 §⑧ 那条能逮，见台账）。
		var 物品号 := int((件 as Dictionary).get("id", 0))
		var 格 := int((件 as Dictionary).get("slot_index", 0))
		var 数 := int((件 as Dictionary).get("quantity", 0))
		if 格 > 0 and 数 > 0 and _是对戒(物品号):
			return 物品号
	return 0


static func _是对戒(物品号: int) -> bool:
	## 与服务端同一条：`190[1-8]0001`。写在代码里而不是正则，是为了让门能逐位钉住它。
	if 物品号 < 19010001 or 物品号 > 19080001:
		return false
	var 阶 := int(物品号 / 10000) % 10
	return 物品号 % 10000 == 1 and 阶 >= 1 and 阶 <= 8


## 主钮。两档走的是两条完全不同的上行，别并写：
## · 被求档 ⇒ `requestAcceptTa(charId, item)` = `127:21:<求方号>:<对戒号>`（`ProposalWindow.as:76`）；
## · 发起档 ⇒ 先过两道原版闸：没对戒 ⇒ 一句「请先放入羁绊对戒」并 **return**（`:80-84`）、
##   已经结过 ⇒ 一句「你已经建立了羁绊啦…」（`:85-89`，走 `WeddingWindowController.isWedding`，
##   本工程用后端的 `authoritative_spouse.charId` 判，同一件事）；都过了才 `127:20`（`:90`）。
static func _点主(宿主: Node, 是被求: bool, 号: int, 戒指号: int) -> void:
	var 后 := _后端(宿主)
	if 是被求:
		if 后 != null:
			后.call("request_bond_accept", 号, 戒指号)
		宿主.call("关掉求婚窗")
		return
	var 对戒 := 戒指号 if 戒指号 > 0 else _挑对戒(后)
	if 对戒 <= 0:
		_提示(宿主, 没放对戒)
		return
	if 后 != null and int((后.get("authoritative_spouse") as Dictionary).get("charId", 0)) > 0:
		_提示(宿主, "你已经建立了羁绊啦！小心被TA骂你是大笨蛋哦！")
		return
	if 后 != null:
		后.call("request_bond_invite", 号, 对戒)
	_提示(宿主, 发出去了)
	宿主.call("关掉求婚窗")


## 次钮。被求档 = `onClickCancelBtn:108-115` ⇒ 发 `127:22:<求方号>` 再关窗；
## 发起档 = **只关窗**（同一支在 `_isProposa == false` 时只走 `onCloseBtnClick`，**不发任何帧**）。
## 右上角那把叉同理（`onCloseBtnClick:97-101` 只 `hideInputCursor + super`）。
static func _点次(宿主: Node, 是被求: bool, 号: int) -> void:
	if 是被求:
		var 后 := _后端(宿主)
		if 后 != null:
			后.call("request_bond_refuse", 号)
	宿主.call("关掉求婚窗")


## 发起档那颗「放入羁绊戒」：原版开取件游标 + 弹背包（`onClickInputBtn:206-219`）。
## 游标没接 ⇒ 这里直接从背包挑，挑到就把图标画进第一格、点中即发不发由主钮那一步决定；
## 挑不到就说真话，**不演"已放入"**。
static func _点放入(宿主: Node, 页: Control) -> void:
	var 后 := _后端(宿主)
	var 对戒 := _挑对戒(后)
	if 对戒 <= 0:
		_提示(宿主, 没放对戒)
		return
	(页.get_node("对戒格/对戒图") as TextureRect).texture = 游戏数据.item_icon(对戒)
	## 把挑到的号**并回宿主那份缓存**，否则下一次重渲染（换心法、连斩…引起的帧回来重画）会把它冲掉、
	## 格里的图没了 —— 与 `功能窗口._双修邀请号` 同一条坑（数据要记在宿主身上，不只记在页里）。
	## ⚠ `Dictionary` 是引用类型 ⇒ `宿主.get()` 拿回来的就是宿主那一份本身，改写它即生效；
	## 但**变量必须写在 if 之外**（GDScript 4 是块作用域，写在 if 里外面就找不到，实测报
	## `Identifier "人" not declared in the current scope`）。
	var 缓存: Dictionary = 宿主.get("_求婚") if 宿主.get("_求婚") is Dictionary else {}
	var 人: Dictionary = 缓存.get("人", {}) as Dictionary
	人["item"] = 对戒
	缓存["人"] = 人
	_提示(宿主, "已放入背包里的羁绊对戒（阶 %d）" % (int(对戒 / 10000) % 10))


## 「购买羁绊戒」= `onClickBuyBtn:221-224` `setCashShopVisible(5)` ⇒ 开点券商城第 5 页。
## 本工程商城那一页归 #101 那条链，这里**不自己造一个商店**：话要说实。
static func _点购买(宿主: Node) -> void:
	_提示(宿主, "点券商城那页还没接（原版是 setCashShopVisible(5)）")


## `onClickInfoBtn:146-156` = `API.ui.clickCharacter(data.charId)` ⇒ 上行 `94:0:<号>`。
static func _点查资料(号: int) -> void:
	var 后 := _后端(null)
	if 后 != null and bool(后.call("get", "in_game")):
		后.call("request_char_full_info", 号)


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
