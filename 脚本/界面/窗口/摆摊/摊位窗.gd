extends RefCounted
## 随身摊位窗（原版 `StallWindow`）控制器。逐件真值 = `真值/窗口/随身摊位窗.md`。
##
## 数据不是开窗时发的请求给的，而是**服务端推的那一帧** `1296:1:`
## （`后端连接._handle_stall_text` → `stall_state_received` → `窗口管理._on_stall_state` 开这一页）。
## 「看摊」= 买家档（`showView(false)`）：只露「购买」，摊名框只读。
## 摊主档（`showView(true)`）：露「上架／下架／修改」，摊名框换成可输入的，
## 「出售记录」那一格**只由下行 `1296:4:` 累积**（原版 `StallDataManager.stallLogs` 是客户端自己那本账，
## `onStallItemList:27-39` 把服务端 `1296:1:` 给的日志段**整段丢掉** ⇒ 本工程照它，别去接那一段）。
##
## ⚠ 本页的逐页状态（页序 / 行清单 / 选中号 / 桶）全放在**宿主的具名变量**上
## （`功能窗口._摊位页序` 等），不用 `set_meta` —— Godot 4 的 metadata 键要求合法标识符，
## 中文键会**静默存不进去**（工程已栽过）。原版也只有 `stallWindow` 一个实例，所以这样对应得上。

const 行脚本 := preload("res://脚本/界面/窗口/摆摊/摊位行.gd")
const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")		# 只读 `pet_template` 的 `info.jie`

## 三枚页签的文案（`StallWindow.as:157`：`STALL_WINDOW_SALE_ITEM` / `_SALE_PET` / `_STALL_WINDOW_SALE_MONEY`
## =「出售中的物品 / 出售中的宠物 / 出售中的货币」）**烘进场景**，运行期只切选中态与上下架文字。
const 钮文字表 := [["物品上架", "物品下架"], ["宠物列表", "宠物下架"], ["货币上架", "货币下架"]]
## ↑ 左：STALL_UP_SHELF_BUTTON_NAME / TRADE_PET_LIST / STALL_UP_SHELF_BUTTON_MONEY_NAME
## ↑ 右：STALL_DOWN_SHELF_BUTTON_NAME / STALL_WINDOW_DOWN_SHELF_PET / STALL_DOWN_SHELF__MONEY_NAME

## 三桶的键名，**同时**是 `分桶()` 的出参键、`_填行` 的取页键、`_设页签态` 的取列表键。
## 原来这三处各写一遍字面量 ⇒ 一处改字（比如把「物品」换成页签全称）另外两处会静默读到空表，
## 表现为"挂了货却一行都不显示"。
const 页名数组 := ["物品", "宠物", "货币"]

## 每页最多挂 10 条（`StallWindow.as:39` `private static const MAX_NUM:int = 10`）。
## ⚠ 这是**纯客户端闸**：服务端 `handle_stall_action` action 4 数都不数就往 `stall.listings` 里塞，
## 所以这一下不拦，在线能一路挂到十一二三条、而原版永远到不了 11。
const 最多 := 10
const 满 := "对不起，你的上架物品已达到限制，请先下架！"	# STALL_WINDOW_NOTICE_1（`:618/652/306/318/246`）
const 不可交易 := "该物品不能交易！"						# IS_NOT_ITEM_TRADE + `！`（`:311`，值本身不带叹号）
const 名空 := "请输入摊位名称！"							# `:361` 硬写的，不在语言表里
const 名全特 := "摊位名称不能只包含特殊字符！"				# `:378`
const 名超长 := "摊位名称不能超过15个字符！"				# `:383`
const 名折敏 := "已自动移除敏感词"							# `:397`
const 名折特 := "已自动移除特殊字符和表情"					# `:401`
const 名折两 := "已自动移除敏感词和特殊字符"				# `:393`
## 宠物／货币两档的伴随窗（`:627-671`）：第 1 页开 `SuiShenPet`（选宠 ⇒ `SHANGJIA_PET`
## ⇒ `选宠上架` 那六道闸 ⇒ `1296:5`），第 2 页开 `UpShelfMoneyWindow`（⇒ `1296:8`）。
const 附身宠物页 := "附身宠物"
const 货币上架页 := "货币上架"

## `selectedPetHandler():236-250` → `showUpShelfWindow(宠, PET_UP_OPERATION)` 那六道闸的话术
## （`STALL_WINDOW_NOTICE_2..6`，顺序照原文：满 → 不能交易 → 已出战 → 已附身 → 6 阶 → 有装备）。
## ⚠ `NOTICE_2` 本身不带叹号（`:2770`），别顺手补。
const 宠不能 := "该通灵兽不能交易"
const 宠出战 := "该通灵兽已经出战，不能上架！"
const 宠附身 := "该通灵兽已经附身，不能上架！"
const 宠六阶 := "6阶以上的通灵兽不能交易！"
const 宠有装 := "请先卸掉通灵兽的装备再上架！"
## 背包那侧点物品时要的一行话（原版这条不需要 —— 它靠跟着鼠标的 `UpShelfCursor`，见 `上架单`）。
const 上架提示 := "点背包里的物品即可上架"
const 退出提示 := "已退出上架模式"
## 原版这里出的是右下角提示条 `MessageTipPane2.TYPE_BAG_FULL`（下架 `:119-123`、购买 `:597-601`
## 两处同一个 type）⇒ 本工程那个消费者未接，暂时落窗口状态行（真值 §⑨ 第 2 条）。
const 背包满 := "背包已满，请先整理背包。"

## `filterSensitiveWords():415-441` 那张表（全文就两枚词），和 `isAllowedChar():410-413` 那四段码区。
## 中文词没有大小写可言 ⇒ 原版的 `new RegExp(word,"gi")` 在这里等价于 `replace`；
## 往表里加**拉丁**词的人得自己把大小写无关补上，这里不留那份推测。
const 敏感词表 := ["系统", "官方"]

const 记录头 := "玩家%s购买了%s道具，获得了%s块金币和%s个元宝"	# STALLDATA_MANAGER_SAY（%1..%4）

## `isAllowedChar():410-413` 逐段照搬：ASCII 可打印 ／ 中日韩统一表意 ／ 全角 ／ 中日韩符号与注音首段。
static func 许可码(码: int) -> bool:
	return (码 >= 32 and 码 <= 126) or (码 >= 19968 and 码 <= 40869) \
			or (码 >= 65281 and 码 <= 65374) or (码 >= 12288 and 码 <= 12351)

## `filterSensitiveWords():415-441`：命中就把那枚词换成等长的 `*`（**不是删掉**，原版就是这么写的）。
static func 洗敏感词(文: String) -> String:
	var 出 := 文
	for 词 in 敏感词表:
		出 = 出.replace(词, "*".repeat(词.length()))
	return 出

## `modifyHandler():356-408` 中段那一串逐字过滤（先洗敏感词、再按码区留字）。
## 返回 `[留下的串, 洗过敏感词, 滤过特殊字符]` —— 后两个布尔决定末尾弹哪句
## （`:386-402`：两种都动过 ⇒ `名折两`；只动过一种 ⇒ 那一种的话；**弹完就 return，不发帧**）。
static func 洗摊名(原文: String) -> Array:
	var 敏 := 洗敏感词(原文)
	var 留 := ""
	for i in 敏.length():
		var 码 := 敏.unicode_at(i)
		if 许可码(码):
			留 += 敏.substr(i, 1)
	return [留, 敏 != 原文, 留 != 敏]

const 类型宠物 := 3			# `CocoItem.PET`（`CocoItem.as:14`）= 服务端 `ItemCodecType.PET`
const 类型货币 := 10			# `CocoItem.MONEY_ITEM`（`:24`）= 服务端 `_send_stall` 里那个 10

## `addItem():530-550` 的分桶：货币 → moneys、宠物 → pets、其余（装备/神器/灵器/忍具…）→ items。
static func 分桶(挂牌表: Array) -> Dictionary:
	var 物: Array = []
	var 宠: Array = []
	var 币: Array = []
	for 行 in 挂牌表:
		var 种 := int((行 as Dictionary).get("kind", 0))
		if 种 == 类型货币:
			币.append(行)
		elif 种 == 类型宠物:
			宠.append(行)
		else:
			物.append(行)
	return {"物品": 物, "宠物": 宠, "货币": 币}

## 买家/摊主两档的显隐与摊名行排布（`showView():451-468` + `:220`）。
## `是摊主` 由**摊主号是不是我**决定（`StallDataManager.as:29-37`：是自己 ⇒ `showMyStallWindow`，
## 是别人 ⇒ `showStallWindow()` + `showView(false)`）。
## 摊名那一格原版是同一个可输入的 `MTextInput2`，两档只差 `enableInput` ⇒ 本工程把它拆成
## 「只读 Label（买家档）+ LineEdit（摊主档）」两件叠在同一个框里，**换的是哪一件露面**。
## 所以两档的差别落在两处：**横向排布**（摊主档要给「修改」让位）＋ **哪三枚钮在台上**。
static func 设档(页: Control, 是摊主: bool) -> void:
	(页.get_node("上架钮") as Button).visible = 是摊主
	(页.get_node("下架钮") as Button).visible = 是摊主
	(页.get_node("购买钮") as Button).visible = not 是摊主
	(页.get_node("修改钮") as Button).visible = 是摊主
	var 框 := 页.get_node("摊名框") as Control
	var 钮 := 页.get_node("修改钮") as Button
	## 摊名那一格：原版是**同一个** `MTextInput2`，两档只差 `enableInput`（`:458` / `:465`）。
	## 本工程把它拆成「只读 Label + 可输入 LineEdit」两件叠在同一个框里 ⇒ 这里换的是**哪一件露面**，
	## 不是"能不能打字"：两档都有字看（买家档原版也显示摊名，只是点不动）。
	(页.get_node("摊名框/摊名文") as Label).visible = not 是摊主
	(页.get_node("摊名框/摊名输入") as LineEdit).visible = 是摊主
	## `showView(true)` 那一支才 `addLog(StallDataManager.stallLogs)`（`:461`）⇒ **买家档日志格恒空**，
	## 而且这一格清得掉：原版 `stallWindow`（买家那扇）从头到尾没往 `_logField` 写过字。
	(页.get_node("日志/日志文") as Label).text = 记录文() if 是摊主 else ""
	if 是摊主:
		## AS3 是 `(277 − 125 − 37 − 8)/2 = 53.5` —— 原版就是半像素，别取整（Flash 也按 .5 画）。
		框.position.x = (277.0 - 125.0 - 37.0 - 8.0) / 2.0
		钮.position.x = 框.position.x + 125.0 + 8.0
	else:
		框.position.x = (277.0 - 125.0) / 2.0


## 建页 + 填数据 + 接线。
## `态` = `{owner_id, owner_name, stall_name, listings:[{uid,owner_id,kind,point_price,cash_price,payload}], logs}`
static func 渲染(宿主: Node, 场景: PackedScene, 态: Dictionary) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	宿主._摊位桶 = 分桶(态.get("listings", []) as Array)
	宿主._摊主号 = int(态.get("owner_id", 0))
	宿主._摊主名 = String(态.get("owner_name", ""))
	宿主._摊位页序 = 0
	宿主._摊位选中 = -1
	设摊名(页, String(态.get("stall_name", "")))
	设档(页, 宿主._摊主号 == int(宿主._backend.get("character_id")))
	for i in 3:
		(页.get_node("页签条/页签%d" % i) as Button).pressed.connect(_切页.bind(宿主, i))
	(页.get_node("购买钮") as Button).pressed.connect(_点购买.bind(宿主))
	## 摊主档那三枚（`:202` upShelfHandler / `:214` downShelfHandler / `:230` modifyHandler）。
	## 买家档它们 `visible = false` ⇒ 接了也点不到，但**必须接**：`设档` 只切显隐，
	## 不接就是"窗开得出、钮按不动"那种最难从静态检查看出来的坏法。
	(页.get_node("上架钮") as Button).pressed.connect(_点上架.bind(宿主))
	(页.get_node("下架钮") as Button).pressed.connect(_点下架.bind(宿主))
	(页.get_node("修改钮") as Button).pressed.connect(_点改名.bind(宿主))
	宿主._摊位页 = 页
	_填行(宿主)
	_设页签态(宿主, 0)
	return 页


## 摊名两件套（只读 Label + 可输入 LineEdit）写同一个串。
## 原版是 `_input.text = param3`（`setStall():558`）一处写、两档共用一个控件。
static func 设摊名(页: Control, 名: String) -> void:
	(页.get_node("摊名框/摊名文") as Label).text = 名
	(页.get_node("摊名框/摊名输入") as LineEdit).text = 名


## 同一帧再来一次（买完服务端会再推一条 `1296:1:`）⇒ 不重建整页，只换数据并重排行。
## 原版也是同一个 `stallWindow` 实例被 `setStall` 重新灌（`StallDataManager.as:36-37`）。
static func 重灌(宿主: Node, 场景: PackedScene, 态: Dictionary) -> void:
	## ⚠ `queue_free()` 之后节点**还在**（`is_instance_valid` 仍为真）要到帧末才真删 ——
	## `_render_page` 每次重渲染都先把 `_content` 的子件摘掉，所以判"这页还能不能用"必须看
	## **它还挂在宿主的 `_content` 下**，不能只判 valid。（实测：连着喂两帧就踩这个，
	## 门里看到的是"页没建出来"，其实是行全建在了一个即将删除的旧页上。）
	var 页 = 宿主._摊位页
	if 页 == null or not is_instance_valid(页) or (页 as Control).get_parent() != 宿主._content:
		渲染(宿主, 场景, 态)
		return
	宿主._摊位桶 = 分桶(态.get("listings", []) as Array)
	宿主._摊主号 = int(态.get("owner_id", 0))
	宿主._摊主名 = String(态.get("owner_name", ""))
	设摊名(宿主._摊位页 as Control, String(态.get("stall_name", "")))
	## ⚠ 这一帧**可能换成别人那一摊**（我在自己摊上开着「上架」，又去点别人头像里的「看摊」）。
	## 原版两档是**两个实例**（`myStallWindow` / `stallWindow`），上架光标挂在自己那扇的钮上，
	## 所以切到别人那扇时它自然不受影响；本工程只有一页 ⇒ 这里必须自己收掉，
	## 否则退出的是"买家档的界面"、留在台上的却是"上架模式"，回背包点物品会开出一扇上架窗。
	if 宿主._摊主号 != int(宿主._backend.get("character_id")):
		上架模式 = false
	设档(宿主._摊位页 as Control, 宿主._摊主号 == int(宿主._backend.get("character_id")))
	## 原版重灌走 `onDatReady → selectedBtnHandler` ⇒ 同样收掉不属于当前页的伴随窗（`:469-535`）。
	_收别窗(宿主, int(宿主._摊位页序))
	_填行(宿主)
	_设页签态(宿主, int(宿主._摊位页序))


## `selectedBtnHandler():469-527`：换页只换数据源与上下架两颗钮的文字，并把选中重置到第 0 行。
## ⚠ 第 1／2 页那两支各带一句 `hideCursor()`（`:500`/`:513`）⇒ **换到宠物页或货币页会退出上架模式**
## （只有第 0 页"物品"允许点背包落子）。这条不是可选的装饰：不退出，玩家切到货币页再点背包，
## 弹出来的仍是物品上架窗、发出去的却是 `1296:4`。
static func _切页(宿主: Node, 序: int) -> void:
	宿主._摊位页序 = 序
	if 序 != 0 and 上架模式:
		上架模式 = false
	## `selectedBtnHandler` 每支只收**别人**那两扇伴随窗（第 0 页两扇都收）。
	_收别窗(宿主, 序)
	_填行(宿主)
	_设页签态(宿主, 序)


## 关掉不属于当前页的伴随窗（`StallWindow.as:469-535`：`setDOShow2(…, false)`）。
## 不关的后果：切到货币页后选宠窗还浮在旁边，点「上架」照样走宠物那条腿。
static func _收别窗(宿主: Node, 序: int) -> void:
	if 序 != 1:
		_关伴窗(宿主, 附身宠物页)
	if 序 != 2:
		_关伴窗(宿主, 货币上架页)


static func _关伴窗(宿主: Node, 页名: String) -> void:
	var 管理: Node = 宿主.get_parent()
	if 管理 == null or not 管理.has_method("取窗口"):
		return
	var 窗 = 管理.call("取窗口", 页名)
	if 窗 != null and bool(窗.call("已打开")):
		窗.call("close")


## 「宠物列表」那一支（`:627-647`）：每次点都 `setData()` 重灌并显示；**不是**开关。
static func _开选宠(宿主: Node) -> void:
	var 管理: Node = 宿主.get_parent()
	if 管理 == null or not 管理.has_method("打开"):
		return
	var 窗: Node = 管理.call("取或建窗口", 附身宠物页)
	窗.set("_附身用途", "摆摊")
	窗.set("_附身选中", 0)
	管理.call("打开", 附身宠物页)
	管理.call("摆到旁边", 附身宠物页, "随身摊位")


static func _设页签态(宿主: Node, 序: int) -> void:
	var 页 := 宿主._摊位页 as Control
	if 页 == null or not is_instance_valid(页):
		return
	for i in 3:
		var 钮 := 页.get_node("页签条/页签%d" % i) as Button
		## `TabButtonBar.selectedBtn():44` 给选中那枚推 `enabled = false`，而 `MTabButton`
		## 里 `set enabled(p)` 写的是 `selected = !p` ⇒ 选中 = `button_pressed = true`（显示 `分页按钮选中.png`）。
		钮.button_pressed = i == 序
	var 桶: Dictionary = 宿主._摊位桶
	var 列表: Array = 桶.get(页名数组[序], []) as Array
	## `:489/501/514` `this._downShelfBtn.enabled = 这一桶.length > 0`：一条都没挂 ⇒ 下架灰着。
	(页.get_node("下架钮") as Button).disabled = 列表.is_empty()
	## 上架那颗是 MButtonF 的**选中态**（`:622 _upShelfBtn.selected = true`），不是文字变化 ⇒
	## 重灌之后也要把它按回去，否则"模式还开着、钮却看起来没开"。
	(页.get_node("上架钮") as Button).button_pressed = 上架模式
	(页.get_node("上架钮") as Button).text = 钮文字表[序][0]
	(页.get_node("下架钮") as Button).text = 钮文字表[序][1]


## 按当前页重建行（原版 `List.dataProvider = new DataProvider(...)`）。
static func _填行(宿主: Node) -> void:
	var 页 := 宿主._摊位页 as Control
	if 页 == null or not is_instance_valid(页):
		return
	var 区 := 页.get_node("列表/行区") as VBoxContainer
	for 旧 in 区.get_children():
		区.remove_child(旧)
		旧.queue_free()
	var 桶: Dictionary = 宿主._摊位桶
	var 列表: Array = 桶.get(页名数组[int(宿主._摊位页序)], []) as Array
	var 留: Array = []
	for 序 in 列表.size():
		var 行: Dictionary = 列表[序] as Dictionary
		var 件 := 行脚本.new()
		件.name = "行%d" % 序
		件.填(行)
		## 用 lambda 按值捕获 `序`（**不用 `.bind`**：`被点击` 自带一个参数，
		## 而 `Callable.bind()` 是把绑定参数**追加在信号参数之后**，
		## `_点行.bind(宿主, 行)` 实际收到的是 `(信号那行, 宿主, 行)` —— 三个参数砸进两参函数，
		## 结果就是"点了没反应"这种最难看出来的坏法）。
		件.被点击.connect(func(_项: Dictionary) -> void: _选中(宿主, 序))
		区.add_child(件)
		留.append(件)
	宿主._摊位行们 = 留
	_选中(宿主, 0 if 留.size() > 0 else -1)		# `:526` `_list.selectedIndex = 0`


## 选中态换人：同一时刻只有一行的底亮着。
static func _选中(宿主: Node, 序: int) -> void:
	var 列表: Array = 宿主._摊位行们
	for i in 列表.size():
		var 件 = 列表[i]
		if is_instance_valid(件):
			(件 as Control).设选中(i == 序)
	宿主._摊位选中 = 序


## 当前选中的那条挂牌（没选 ⇒ 空字典）。买家的「购买」与门都读这个。
static func 选中项(宿主: Node) -> Dictionary:
	var 列表: Array = 宿主._摊位行们
	var 序 := int(宿主._摊位选中)
	if 序 < 0 or 序 >= 列表.size():
		return {}
	var 件 = 列表[序]
	return (件 as Control).项 if is_instance_valid(件) else {}


## 「待买那一条挂牌」放**脚本级静态变量**，不放窗口实例的变量上 ——
## `窗口管理` 给每一页各建一个 `功能窗口` 实例，摊位窗与确认弹是**两个不同实例**，
## 存在实例上 ⇒ 确认弹那一侧永远读到空字典（实测：窗开得出、里面没页）。
## 同族的 `洗点窗.gd` 也是这个形状（`_还原`/`_基数` 都是脚本级）。
static var 待买: Dictionary = {}

## 当前页要用的挂牌清单（按页取），门与确认弹都读这里。
static func 取待买() -> Dictionary:
	return 待买


## `buyHandler():593-604`：没选中什么都不发生；选中了才开购买确认窗（`StallUpShelfWindow` 的 `BUY_OPERATION` 档）。
static func _点购买(宿主: Node) -> void:
	var 行 := 选中项(宿主)
	if 行.is_empty():
		return
	## 原版第一道闸是背包满（`isPackgeFull()`）—— 满了只出提示、不开窗。
	if _背包已满(宿主):
		宿主._show_hint(背包满)
		return
	## `ISTABBTNMONEY`（`:511` 由页签决定）传进确认窗，决定它比哪一对余额、画哪一档。
	待买 = {
		"行": 行,
		"货币页": int(宿主._摊位页序) == 2,
		"摊主号": int(宿主._摊主号),
		"摊主名": String(宿主._摊主名),
	}
	var 管理: Node = 宿主.get_parent()
	if 管理 == null or not 管理.has_method("打开"):
		待买 = {}
		return
	管理.call("打开", "摊位购买")


## ---------- 摊主侧：上架 / 下架 / 改名 ----------

## 「上架模式」= 原版的 `UIConfig.isDropItem` + `dropValidateFun = showUpShelfWindow`
## 那一对（`StallWindow.as:621-624`）。原版靠一枚跟着鼠标的 `UpShelfCursor` 告诉玩家"现在点
## 背包就是上架"，落点判定在 `ItemWindow2.as:440-444`（点一格 ⇒ 调 `dropValidateFun(那格)`
## 然后 **return**，连物品菜单都不弹）。本工程没有跟随光标的自绘件 ⇒ 照 `交易窗.上架模式`
## （`UIConfig.isShangjiaItem` 的同型移植）把它做成**模式位**：钮用 toggle 态表达，背包那侧读同一个位。
## ⚠ 必须是**脚本级静态**：摊位窗与背包窗是两个不同的 `功能窗口` 实例，存实例上互相读不到。
static var 上架模式 := false

## 从背包递给「上架确认窗」的那一件 = `{物品: 背包字典, 格: int}`。同 `待买` 的理由放脚本级。
static var 上架单: Dictionary = {}

## 摊主那本「出售记录」（原版 `StallDataManager.stallLogs`：进程级**字符串**，只在收到
## `1296:4:` 时追一行，`setStall` 重灌不清、切页不清 ⇒ 放在这里而不是宿主的页状态上）。
## ⚠ 本工程存成**行数组**、渲染时以 `"\n"` 连接。原版那句用 `<br/>` 分隔、内部三段 `<font color>`
##   （时间灰 `#999999`／玩家名绿 `#00B000`／物品名紫 `#AE00FF`／两个数目红 `#FF0000`），
##   而 `日志/日志文` 是一只普通 Label（只有一种颜色）⇒ **字一句不少、配色拿不到**，
##   这条偏离登记在真值 §⑨。别为了"看着像"把它换成 RichTextLabel 再补一层 HTML 转换。
static var 摊日志: Array = []

## 彩虹神器那条：物品名里带 `[[ZBLH]]` 标记（`MYTH_RAINBOW_LOG_MARKER`），原版那一支
## **摘掉标记**、换一段七色渐变 HTML（`getMythRainbowGradientHtml`）。纯文本下只剩"摘标记"这一步。
const 虹彩标记 := "[[ZBLH]]"

## 时间戳用的是**客户端本地钟**（原版 `new Date()` 的 hours/minutes/seconds，各自补零到两位），
## 不是服务端给的时间 ⇒ `Time.get_time_string_from_system()`（不带 utc 参数就是本地）。
static func 加记录(买家名: String, 物品名: String, 金币: int, 元宝: int) -> void:
	摊日志.append("%s %s" % [Time.get_time_string_from_system(),
			记录头 % [买家名, 物品名.replace(虹彩标记, ""), 金币, 元宝]])


static func 记录文() -> String:
	return "\n".join(摊日志)


## 背包满（原版 `API.dataCenter.isPackgeFull()`）。下架与购买两处共用。
## ⚠ 容量还没收到（0）时**不算满**：否则刚连上、背包帧未到就点购买会被凭空拦一道。
static func _背包已满(宿主: Node) -> bool:
	var 后 = 宿主._backend
	if 后 == null:
		return false
	var 容量 := int(后.get("authoritative_bag_capacity"))
	if 容量 <= 0:
		return false
	return (后.get("authoritative_inventory") as Array).size() >= 容量


## 开/收上架模式。原版两支：开 = `showCursorUI` + `selected = true` + `isDropItem = true`
## （`:621-624`），收 = `hideCursor():443-449`（**不弹话**。所以退出这一支也只写状态行、不 `_通知`）。
static func _设上架态(宿主: Node, 开: bool) -> void:
	上架模式 = 开
	var 页 := 宿主._摊位页 as Control
	if 页 != null and is_instance_valid(页):
		(页.get_node("上架钮") as Button).button_pressed = 开
	宿主._show_hint(上架提示 if 开 else 退出提示)


## 「物品上架／宠物列表／货币上架」这颗钮（`upShelfHandler():606-672`）三分支。
## 第 0 页：已在模式 ⇒ 收；未满 10 ⇒ 开。第 1 页开选宠窗 `SuiShenPet`、第 2 页开
## `UpShelfMoneyWindow`（货币那一页原版的 10 条闸在开窗之前，`:650-654` ⇒ 满了要说"先下架"）。
static func _点上架(宿主: Node) -> void:
	var 桶: Dictionary = 宿主._摊位桶
	## ⚠ `toggle_mode` 的钮在**点击那一刻自己就翻了位**，而下面三支里有两支根本不开模式
	## （满 10、宠物/货币两档）⇒ 先把视觉位收回真实模式，再让 `_设上架态` 摆成该成的样子。
	## 不收回的表现是"钮看着按下了、点背包却什么都不发"——最难从画面上看出来的那种坏法。
	var 页 := 宿主._摊位页 as Control
	if 页 != null and is_instance_valid(页):
		(页.get_node("上架钮") as Button).button_pressed = 上架模式
	match int(宿主._摊位页序):
		0:
			if 上架模式:
				_设上架态(宿主, false)
			elif (桶.get(页名数组[0], []) as Array).size() >= 最多:
				宿主._通知(满)
			else:
				_设上架态(宿主, true)
		1:
			## `:627-647` 点「宠物列表」不数宠物条数（满 10 的闸在选完宠之后的
			## `selectedPetHandler:243-248`）。
			_开选宠(宿主)
		2:
			if (桶.get(页名数组[2], []) as Array).size() >= 最多:
				宿主._通知(满)
			else:
				_开货币上架(宿主)


## 「货币上架」那一支（`:648-671`）。
static func _开货币上架(宿主: Node) -> void:
	var 管理: Node = 宿主.get_parent()
	if 管理 == null or not 管理.has_method("打开"):
		return
	管理.call("打开", 货币上架页)
	管理.call("摆到旁边", 货币上架页, "随身摊位")


## 选宠窗里点「上架」⇒ `SHANGJIA_PET`（`SuiShenPet.as:102-117`）⇒ 六道闸
## （`StallWindow.as:236-250` + `showUpShelfWindow:298-350`）⇒ 开确认窗挂宠。
## `宿主` 是**摊位窗那一页**：满 10 数的是它那个桶。
static func 选宠上架(宿主: Node, 宠物: Dictionary) -> void:
	if 宠物.is_empty():
		return
	if (宿主._摊位桶.get(页名数组[1], []) as Array).size() >= 最多:
		宿主._通知(满)
		return
	if not bool(宠物.get("can_trade", true)):
		宿主._通知(宠不能)
		return
	if bool(宠物.get("deployed", false)):
		宿主._通知(宠出战)
		return
	if bool(宠物.get("attached", false)):
		宿主._通知(宠附身)
		return
	var 模板: Dictionary = 游戏数据.pet_template(int(宠物.get("item_id", 0)))
	var 信息: Dictionary = 模板.get("info", {}) as Dictionary
	if int(信息.get("jie", 0)) >= 6:
		宿主._通知(宠六阶)
		return
	var 装: Array = 宠物.get("equipment", []) as Array
	if not 装.is_empty():
		宿主._通知(宠有装)
		return
	上架单 = {"宠物": 宠物}
	var 管理: Node = 宿主.get_parent()
	if 管理 == null or not 管理.has_method("打开"):
		上架单 = {}
		return
	管理.call("打开", "摊位上架")


## 「物品下架／宠物下架／货币下架」（`downShelfHandler():114-128`）。
## ⚠ 背包满这一闸**客户端服务端都查**（服务端那条腿：放不下时**一条帧都不回**，只发一句
## 「背包空间不足」⇒ `后端连接._handle_stall_removed` 的注释）。两边都拦才不会出现
## "屏幕上行摘了、物品却没回到背包"那种假成功。
static func _点下架(宿主: Node) -> void:
	var 行 := 选中项(宿主)
	if 行.is_empty():
		## `if (this._list.selectedItem)` 那一层：没选中 ⇒ 一个字节都不发、也不弹话。
		return
	if _背包已满(宿主):
		宿主._show_hint(背包满)
		return
	var 后 = 宿主._backend
	if 后 == null:
		宿主._show_hint("下架需要连接服务端")
		return
	## 不提示"已发送"：摘行由服务端 `1296:3:` 驱动（`重排`），发成功本来就该什么都没发生。
	后.call("request_stall_remove_item", int(行.get("uid", 0)))


## 「修改」= 改摊名（`modifyHandler():356-408`）。四道判式的**顺序与话术**都照原文：
## 空 → 只特殊字符 → 超 15 → **折过东西就回写输入框、弹一句、`return`（这一趟不发帧）**。
## 最后一支是原文的语义：玩家看到字变了，**再点一次「修改」**才真发 `3:`。
static func _点改名(宿主: Node) -> void:
	var 页 := 宿主._摊位页 as Control
	if 页 == null or not is_instance_valid(页):
		return
	var 框 := 页.get_node("摊名框/摊名输入") as LineEdit
	var 原文 := 框.text
	if 原文.is_empty():
		宿主._通知(名空)
		return
	var 洗 := 洗摊名(原文)
	var 留 := String(洗[0])
	if 留.is_empty():
		宿主._通知(名全特)
		return
	if 留.length() > 15:
		宿主._通知(名超长)
		return
	if bool(洗[1]) or bool(洗[2]):
		框.text = 留
		(页.get_node("摊名框/摊名文") as Label).text = 留
		宿主._通知(名折两 if bool(洗[1]) and bool(洗[2])
				else 名折敏 if bool(洗[1]) else 名折特)
		return
	var 后 = 宿主._backend
	if 后 == null:
		宿主._show_hint("改摊名需要连接服务端")
		return
	## `onStallModify`（`UI.as:1148-1151`）发的是 `requestStallRename(API.dataCenter.stats.id, 名)`
	## ⇒ 角色号是**我自己**，不是 `_charId`（这一支只有摊主档点得到，两者本来就相等）。
	后.call("request_stall_rename", int(后.get("character_id")), 留)


## 上架模式下点背包的一格 ⇒ 原版 `UIConfig.dropValidateFun(那格)` =
## `showUpShelfWindow(物品, 0)`（`WUPING_UP_OPERATION = 0`，`StallUpShelfWindow.as:31`）。
## 三道闸都在 `showUpShelfWindow:298-314`：**没传 item 直接 return** → 满 10 → 不可交易。
## ⚠ 顺序照原文：**先数 10、再看能不能交易**（反过来的话，挂满 10 条时点一件绑定物
##   会弹「该物品不能交易」，而原版弹的是「上架物品已达到限制」）。
static func 背包落一件(宿主: Node, 物品: Dictionary, 格: int) -> void:
	if 物品.is_empty():
		return
	if (宿主._摊位桶.get(页名数组[0], []) as Array).size() >= 最多:
		宿主._通知(满)
		return
	if not bool(物品.get("can_trade", true)):
		## `:309-313` 这一条走 `MDialog.showMessageDialog(…, stage)` —— **模态弹**、只有确定，
		## 不是右下角那条 `addNotice` ⇒ 用移植件 `输入确认弹.弹消息`。没有遮罩层时退化成一句通知，
		## 总之不许静默。
		var 遮罩 := 宿主.get("_overlay") as Control
		if 遮罩 == null:
			宿主._通知(不可交易)
		else:
			确认弹.弹消息(遮罩, 不可交易, func(_码: int) -> void: pass)
		return
	上架单 = {"物品": 物品, "格": 格}
	var 管理: Node = 宿主.get_parent()
	if 管理 == null or not 管理.has_method("打开"):
		上架单 = {}
		return
	管理.call("打开", "摊位上架")
	## ⚠ **不收模式**：原版点完一格之后光标还在（`hideCursor` 只在换页／再点钮／关窗三支里调），
	## 所以挂完一件还能接着点下一件。这里跟着不清，否则玩家得每挂一件就重开一次模式。


## 服务端推来一条加／摘挂牌之后重排（原版 `upShelf():522-529` 与 `downShelf():252-296`
## 末尾各调一句 `selectedBtnHandler(null)`：换数据源 + 选中回到第 0 行）。
## 数据从 `authoritative_stall` 重取 —— `后端连接` 那两个 handler 已经把这一行加／摘进去了。
static func 重排(宿主: Node) -> void:
	var 后 = 宿主._backend
	if 后 != null:
		var 态: Dictionary = 后.get("authoritative_stall") as Dictionary
		宿主._摊位桶 = 分桶(态.get("listings", []) as Array)
	_填行(宿主)
	_设页签态(宿主, int(宿主._摊位页序))


## 收到一条 `1296:4:` 之后把账本写回台上那一格。**账已经追好了**（`加记录`），这里只画。
## 判式与 `设档` 里那句同一口径：原版只有 `showView(true)` 那一支才 `addLog(stallLogs)`
## （`:461`）⇒ 买家档那一格恒空，别在这里"顺手"给买家也写上一行。
static func 补日志(宿主: Node) -> void:
	var 页 := 宿主._摊位页 as Control
	if 页 == null or not is_instance_valid(页):
		return
	(页.get_node("日志/日志文") as Label).text = 记录文() \
			if int(宿主._摊主号) == int(宿主._backend.get("character_id")) else ""


## 关自己那扇 ⇒ 收模式（`onCloseBtnClick:130-141` 里那句 `if (_upShelfBtn.selected) hideCursor()`）
## 并收掉两扇伴随窗（原版 `StallWindow` 连同 `_petListWindow` / `_upShelfMoneyWindow` 一起销毁）。
## ⚠ 不收的后果不是"难看"而是**按错**：下次开摊时钮看起来没按下，点背包却弹出一扇上架窗。
static func 关窗清态(宿主: Node) -> void:
	上架模式 = false
	上架单 = {}
	_关伴窗(宿主, 附身宠物页)
	_关伴窗(宿主, 货币上架页)
