extends RefCounted
## 神秘商店窗（原版 `MysteryWindow`）控制器。逐件真值 = `真值/窗口/神秘商店.md`。
##
## 数据 = 服务端推的那一帧 `324:`（`后端连接._handle_secret_shop_text`
## → `mystery_shop_received` → `窗口管理._on_mystery_shop` 开这一页）。
## **背包底部那颗「神秘商店」只发一跳（NPC_SHOP 动作 6），点下去不开窗** ——
## 开窗的永远是回帧（`MysteryManager.requestOpenMystery` 全文没有 `showWindow`）。
##
## ⚠ 逐页状态放在宿主的**具名变量**上（`功能窗口._神秘商店页` / `._神秘商店走`），
## 不用 `set_meta`：Godot 4 的 metadata 键要求合法标识符，中文键会**静默存不进去**。
## 「走」那本字典和那张秒表（`_神秘商店秒表`，挂在宿主节点上）都必须活在**页之外** ——
## `_render_page` 每轮先把 `_content` 的子件全摘掉，页是每次重建的，
## 只有挂在宿主上的东西能跨重建活下去（§④-2 那条坑就在这）。

const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 富文本 := preload("res://脚本/界面/富文本.gd")

const 格数 := 12						# `MysteryWindow.as:70` `while(_loc4_ < 12)`

## 语言表逐字（`2.2.3/map_extract/out/mainlib_as/scripts/en_US$message_properties.as`，
## **行号写在每条后面**）。⚠ 原句里 `<font color = "#fff000">` 那个**等号两侧带空格**是原版
## 字面，照抄；GDScript 串里不能嵌裸双引号 ⇒ 两条 `<font>` 改用单引号
## （`富文本.译文为BBCode` / `输入确认弹.文案转BBCode` 两种引号都认）。
const 倒计时头 := "刷新倒计时：%1:%2:%3"										# :3192 MYSTERY_TIME_TXT
const 倒计时空 := "已刷新"																		# :2336 MYSTERY_TIME_OVER
const 花费头 := "花费：<font color = '#fff000'>%1</font>"						# :775 MYSTERY_REF_MONEY
const 已购买 := "已购买"																				# :1985 MYSTERY_CELL_PRIZE_TXT
const 确认元宝 := "该物品%1元宝,你确定购买吗？"									# :756 MYSTERY_SURE_BUY_YB_TIP
const 确认点券 := "该物品%1点券,你确定购买吗？"									# :2151 MYSTERY_SURE_BUY_DQ_TIP
const 不足元宝 := "很抱歉，你的元宝不足！"													# :1420 SORRY_DEFICIENCY_COIN
const 不足点券 := "很抱歉，你的点券不够"														# :1969 RIHUAN_DIANQUAN_BUGOU
const 刷新弹 := "直接刷新神秘商店物品需要花费<font color='#FFF000'>%1元宝</font>"	# :49 MYSTERY_REF_ITEM_TIP
const 不再提示 := "今日不再提示"																	# :1984 YIZHI_ZHAO_HUAN_NPC_DILOG_CHECK_TEXT
## 窗标题「神秘商店」= `:2232 MYSTERY_WINDOW_TITLE`，钮文字「刷新」= `:1299 DEFFOR_DESINATION_REFURBISH`
## ⇒ 两条都烘在 `.tscn` 里（标题由 `窗口尺寸.json` 那份交给外框画）。

const 白 := Color(1, 1, 1)			# UIConfig.UI_WHITE `:924`
const 绿 := Color(0, 1, 0)			# UIConfig.UI_GREEN `:930`

const 币元宝 := 0
const 币点券 := 1
const 币双币 := 2

const 刷新花费 := 50			# `MysteryWindow.as:32 private const refMoney:int = 50`
									#（`MysteryManager.as:16 _refYuanBao` 同值，两处各自写死）

## `MysteryManager.showSureRefWindow` 是**单例上的运行期字段**，不落盘 ⇒ 这边用脚本级静态变量：
## 同一次会话里勾了「今日不再提示」就不再弹，重启客户端又会弹一次。⚠ 别写进 `game_settings`。
static var 再弹刷新确认 := true


## 建页 + 填数据 + 接线（原版 `initUI` + `openMysteryWindow` 那两步合起来）。
static func 渲染(宿主: Node, 场景: PackedScene, 态: Dictionary) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	宿主._神秘商店页 = 页
	(页.get_node("刷新钮") as Button).pressed.connect(_点刷新.bind(宿主))
	for 序 in 格数:
		## 点击热区 = **物品格本身**（`MysteryCell.as:77` 把 `MSPRITE_CLICK` 挂在 `_itemCell` 上，
		## 不是整格）⇒ 点名称、点价格都不该有反应。
		(页.get_node("格%d/物品格" % 序) as Button).pressed.connect(_点格.bind(宿主, 序))
	_出字(页, 走(宿主))
	起秒表(宿主)
	灌(宿主, 页, 态)
	return 页


## 同一帧再来一次（买成 / 刷新都会重推一整帧 324）。
## 原版 `receiveRefItem:30-46` 分两支：**窗已存在 ⇒ 只 `updateview`**（不换实例、不重起秒表）；
## 不存在才 `centerTwoWindow` 开新的一扇。本工程 `打开()` 每轮都会 `open_page → _render_page`
## 把 `_content` 的子件全摘掉重建 ⇒ "页还在"这条几乎永远不成立，只能退一步守**可观察的那半**：
## 秒表挂在**宿主**上（不挂页上），重建页时那张表还在跑、`start()` 的 running 闸让它不被重起，
## 于是倒计时既不跳也不重对齐。逐页状态（`走`）同样挂宿主，见文件头那条 ⚠。
static func 重灌(宿主: Node, 场景: PackedScene, 态: Dictionary) -> void:
	var 页 = 宿主._神秘商店页
	if 页 == null or not is_instance_valid(页) or (页 as Control).get_parent() != 宿主._content:
		渲染(宿主, 场景, 态)
		return
	灌(宿主, 页 as Control, 态)


## `updateview(items, remainSecs)` 全文三件事：逐格 `setData` + 已购的盖章 + **改 passTime**。
## ⚠ `set passTime`（`CommonPassTimer.as:96-103`）**只换数字、不出字、不 `start()`** ⇒
## 文案还停在上一秒那一句，下一次 tick 才跳。
## 「刷新之后倒计时回满」不是客户端拨的：`_refresh_mystery_shop(manual)` 在服务端把
## `refresh_at` 推到 +6h ⇒ 那一帧的 `remainSecs` 本来就接近满；**买成**重推的那一帧
## 值几乎没动。所以"重灌不许自己减秒、也不许重起表"才是这条链的真口径。
static func 灌(宿主: Node, 页: Control, 态: Dictionary) -> void:
	var 货: Array = 态.get("items", []) as Array
	for 序 in 格数:
		填格(页, 序, 货[序] as Dictionary if 序 < 货.size() else {})
	走(宿主)["剩"] = int(态.get("remaining_seconds", 0))
	## `updateview` 每一轮都重写这句（值恒定 = `refMoney`），跟着重灌走一遍，不做"只写一次"。
	(页.get_node("花费") as RichTextLabel).text = 富文本.译文为BBCode(替(花费头, [刷新花费]))


## 一格。`项` 为空 = 原版那格根本没被 `setData` ⇒ **只有空底，一个字都不写、不假造**。
static func 填格(页: Control, 序: int, 项: Dictionary) -> void:
	var 格 := 页.get_node("格%d" % 序) as Control
	var 图 := 格.get_node("物品格/图标") as TextureRect
	var 价 := 格.get_node("价格") as Label
	(格.get_node("元宝图") as TextureRect).visible = false
	(格.get_node("券图") as TextureRect).visible = false
	(格.get_node("双币") as Control).visible = false
	if 项.is_empty():
		图.visible = false
		图.texture = null
		(格.get_node("名称") as Label).text = ""
		价.text = ""
		价.add_theme_color_override("font_color", 白)
		return
	var 路径 := String(项.get("icon", ""))
	图.texture = load(路径) as Texture2D if not 路径.is_empty() else null
	图.visible = 图.texture != null
	(格.get_node("名称") as Label).text = String(项.get("name", ""))
	## 显示的是 `yb`（这里叫 `cash_price`），**不是** `meso` —— `MysteryCell.setData:114`。
	价.text = str(int(项.get("cash_price", 0)))
	价.add_theme_color_override("font_color", 白)
	match int(项.get("money_type", 0)):
		币元宝:
			(格.get_node("元宝图") as TextureRect).visible = true
		币点券:
			(格.get_node("券图") as TextureRect).visible = true
		币双币:
			(格.get_node("双币") as Control).visible = true
	## `setSelled()` 只改这两样，且 `updateview` 每轮先 `setData` 复位 ⇒
	## "上次买过、这次刷新回来没买过"那一格会自己变回价格。这条不做成粘的。
	if bool(项.get("purchased", false)):
		价.text = 已购买
		价.add_theme_color_override("font_color", 绿)


## `MysteryWindow.buyItem(itemid, moneyType, yb)`（`:181-205`）四支分支，顺序照抄：
## ① `moneyType==1 且 bandMoney <= yb` ⇒ 一句点券不够；② `moneyType==0 且 cashMoney <= yb`
## ⇒ 一句元宝不足；③ `==2` **原版既没守卫也没文案**（`_loc4_` 留 null 进
## `CN.replaceString` ⇒ `null.replace` 抛 #1009 ⇒ 弹不出也发不出）⇒ 这边同样什么都不做；
## ④ 过闸才弹确认，**点确定才发 7**。判的是 `<=` 不是 `<` ⇒ 余额正好等于价也不让买。
static func _点格(宿主: Node, 序: int) -> void:
	var 态: Dictionary = 宿主._backend.get("authoritative_mystery_shop") as Dictionary
	var 货: Array = 态.get("items", []) as Array
	if 序 >= 货.size():
		return							# `MysteryCell.buyItemHandler:80-87` `if (data == null) return`
	var 项: Dictionary = 货[序] as Dictionary
	var 价 := int(项.get("cash_price", 0))
	var 币 := int(项.get("money_type", 0))
	var 计: Dictionary = 宿主._session.player_stats
	if 币 == 币点券 and int(计.get("cash_bind", 0)) <= 价:
		宿主._show_hint(不足点券)
		return
	if 币 == 币元宝 and int(计.get("cash", 0)) <= 价:
		宿主._show_hint(不足元宝)
		return
	if 币 != 币元宝 and 币 != 币点券:
		return
	## 确认文案按 `moneyType` 二选一，`%1` 填的是 `yb`；`_itemid` 存的是 **item_id**。
	var 号 := int(String(项.get("id", "0")))
	确认弹.弹消息(宿主._overlay,
			替(确认元宝 if 币 == 币元宝 else 确认点券, [价]),
			_点确定的购买.bind(宿主, 号))


## `__sureBuy`：只有 OK 那支发帧（本工程 `弹消息` 传 1=OK、2=CANCEL），
## 两支都会把 `_itemid` 清回 −1 ⇒ 这里不留任何待发改状态。
## ⚠ 形参顺序：`Callable.bind()` 把绑定参数排在**调用参数之后** ⇒ 回调实际收到
## `(档, 宿主, 号)`。写成 `(宿主, 号, 档)` 会在点确定那一刻报「Cannot convert argument」。
## ⚠ 上行载荷是 **item_id**、不是格子下标 —— 服务端 `handle_npc_shop` 的 `action 7`
## 直接 `_buy_mystery_shop_item(fields[1])`（`request_secret_shop_buy(index)` 那个形参名是旧的）。
static func _点确定的购买(档: int, 宿主: Node, 号: int) -> void:
	if 档 != 1:
		return
	宿主._backend.request_secret_shop_buy(号)


## `refItemHandler:140-148`：**先比元宝**（`cashMoney <= 50` ⇒ 一句「很抱歉，你的元宝不足！」、
## 不发帧），过了才交给 `MysteryManager.refItem()`。
## 那一排的元宝图**不跟着余额变灰** —— 原版它就是张静态贴画。
static func _点刷新(宿主: Node) -> void:
	var 计: Dictionary = 宿主._session.player_stats
	if int(计.get("cash", 0)) <= 刷新花费:
		宿主._show_hint(不足元宝)
		return
	if 再弹刷新确认:
		确认弹.弹勾选(宿主._overlay, 替(刷新弹, [刷新花费]), 不再提示, false,
				_点确定的刷新.bind(宿主))
		return
	发刷新(宿主)


## `sureRefItem:72-80`：取消 ⇒ `param1 == null` ⇒ **直接 return，连 `showSureRefWindow` 都不改**
## （所以"弹了但点取消"下次照样弹）；确定 ⇒ `showSureRefWindow = !勾选值` 再发。
static func _点确定的刷新(选: Variant, 宿主: Node) -> void:
	if 选 == null:
		return
	再弹刷新确认 = not bool(选)
	发刷新(宿主)


## `requestRefItem()` = NPC_SHOP 动作 8（**不带载荷**）。服务端过 25 级闸后
## `_refresh_mystery_shop(manual=true)` 扣 50 元宝、换新货架并重推一整帧 324。
static func 发刷新(宿主: Node) -> void:
	宿主._backend.request_secret_shop_refresh()


## ── 秒表（`CommonPassTimer`，`isDownTime = true` 那一档）─────────────────────
## 四条口径逐字照 `:81-94` + `:96-103` + `:137`：
##   · `initUI` 先把文案写成 `%1:%2:%3` 全 "00" ⇒ **开窗头一秒读的是「刷新倒计时：00:00:00」**，
##     `start()` 里那次 `onTimer(null)` 因为 `_lastTime` 刚被 `set passTime` 重锚、`_loc3_ == 0`
##     ⇒ 不出字，所以真数要等第一次真 tick；
##   · 每一 tick **先判 `<=0` 再减** ⇒ 走到 0 的那一秒文案还停在 `00:00:00`，
##     **再下一次 tick 才出「已刷新」并停表**（00:00:00 站整一秒）；
##   · 格式是 `H:M:S` 各补两位，**小时从 3600 里除**（21600 秒 ⇒ `06:00:00`），不是 60 进制两位；
##   · 表挂在**宿主**上、`start()` 有 running 闸（`:167`）⇒ 页重建 / 重灌都不会重起它，
##     走完 `stop()` 之后也没人再把它叫活（原版只有构造后那一次 `openMysteryWindow:137` 调 `start`，
##     `stop:49-56` 还把监听一起摘了）。
const 秒表名 := "神秘商店秒表"


## 跨重建活着的秒表状态。`文` 是**上一次 tick 出过的那一句**（重灌不许改它），
## `跑完` 对应原版"表已 stop"那个终态。
static func 走(宿主: Node) -> Dictionary:
	if 宿主._神秘商店走.is_empty():
		宿主._神秘商店走 = {"剩": 0, "文": 替(倒计时头, ["00", "00", "00"]), "跑完": false}
	return 宿主._神秘商店走


static func 起秒表(宿主: Node) -> void:
	var 表 := 宿主.get_node_or_null(秒表名) as Timer
	if 表 == null:
		表 = Timer.new()
		表.name = 秒表名
		表.wait_time = 1.0
		宿主.add_child(表)
		表.timeout.connect(_tick.bind(宿主))
	if bool(走(宿主)["跑完"]):
		## 走完出过「已刷新」之后原版把表摘了，此后 `updateview` 不再 `start()` ⇒
		## 页重建也不该复活，否则「已刷新」会被一帧迟到的 324 冲回数字。
		表.stop()
		return
	if not 表.is_stopped():
		return						# `CommonPassTimer.start:167` 的 `running == false` 闸
	表.start()


## 关窗要做的收尾。原版 `MysteryWindow.destroy:43-46` 第一句就是 `_timeLabel.stop()`，
## 而 Flash 关窗会把实例连同 `_timeLabel`（连同那个 `Timer`）一起销毁 ⇒ 下次
## `receiveRefItem` 走 `centerTwoWindow` 建的是**全新**一扇：文案回到 `initUI`（`CommonPassTimer:137`）
## 那句「刷新倒计时：00:00:00」，秒表从零重走，"已刷新"那个终态也不跨开关活着。
## 本工程的窗实例不销毁（关窗只是 `_overlay.visible = false`）⇒ 这条只能靠关窗时把状态清干净来还：
## **表节点留着、只 stop**（`queue_free` 会让"同一帧关了又开"撞上下标重名，白丢一张表）。
static func 复位(宿主: Node) -> void:
	宿主._神秘商店走 = {}
	var 表 := 宿主.get_node_or_null(秒表名) as Timer
	if 表 != null:
		表.stop()


## 每一 tick = 原版 `onTimer` 里 `_loc3_ >= 1` 那一支。
static func _tick(宿主: Node) -> void:
	var 表 := 宿主.get_node_or_null(秒表名) as Timer
	var 页: Control = 宿主._神秘商店页
	## 窗收掉了 ⇒ 表停下、**剩余值原地不动**：正常路径由 `close() → 复位` 停表并清状态，
	## 这一支只是兜住"页被别的路拆了/窗没走 close 就看不见"那种情况（别再让表空转）。
	if 页 == null or not is_instance_valid(页) or not bool(宿主.已打开()):
		if 表 != null:
			表.stop()
		return
	var 态 := 走(宿主)
	if int(态["剩"]) <= 0:
		if 表 != null:
			表.stop()
		态["文"] = 倒计时空
		态["跑完"] = true
		_出字(页, 态)
		return
	态["剩"] = int(态["剩"]) - 1
	var 秒 := int(态["剩"])
	## 三段各自从**减完的那个数**里除（`:90-92` 用的是同一个 `_loc3_` 后的 `_passTime`）：
	## 时 = 秒/3600，分 = (秒 − 时×3600)/60，秒 = 剩下那点。这里写成 `%` 是同值。
	态["文"] = 替(倒计时头, [_补零(int(秒 / 3600.0)), _补零(int((秒 % 3600) / 60.0)), _补零(秒 % 60)])
	_出字(页, 态)


static func _出字(页: Control, 态: Dictionary) -> void:
	(页.get_node("倒计时") as Label).text = String(态["文"])


static func _补零(值: int) -> String:
	return str(值) if 值 > 9 else "0" + str(值)


## `CN.replaceString` 的等价物：`%1`、`%2`… 依序替换。
static func 替(模板: String, 参数: Array) -> String:
	var 文 := 模板
	for i in 参数.size():
		文 = 文.replace("%" + str(i + 1), str(参数[i]))
	return 文
