extends RefCounted

## 原版背包窗口（`ItemWindow2`）的渲染与交互。
##
## 版式真值全部来自 `com/mxw/uifl/controls/ItemWindow2.as`，坐标是**窗口局部**
## （0,0 = 窗口外框左上角，含外框那圈）—— 靠 `数据/界面/窗口尺寸.json` 里背包那条的
## `"原点": [0,0]` 让页面容器铺满整个外框。
##
## ⚠️ 用户口径四轮：2026-10-29「每一页 128 格」，2026-10-31「一行 10 格、10 行」
##    「10 行也可以一屏全露，不用上下滚动」，同日第四轮「单格高度改小了、图标越过格子下边框」
##    ⇒ 格高必须 40；第五轮「除了格子数，其他布局不要做改变」——**有意偏离原版 30 格/页**。
##    版式回到第三轮原样：窗口 453x556（原版 `super(275, 394)`）、格区 433x364 与格区底同框
##    （11..444、71..435）、格 40x40、横距 42 / 纵距 40、起点 8,4（`物品格.tscn`）。
##    364 高只装得下 9 行（4 + 9x40 = 364）⇒ **10 列 x 9 行 = 90 格/页**，末行下沿 364 = 框下沿。
##    ⚠️ 2026-10-31 第三轮（用户：「格子左右两边空了一格」）之前格区是 364 见方**在页里居中**
##    （44..408），左右各剩 37/36 白边看着像空了一列；现在格子从九宫格内沿 19 铺到 437，
##    与老版「格位贴框」的观感一致，菜单定位里的 `容器.x = 11` 也才对得上。
##    **两条滚动都关**：一开 ScrollContainer 就把滚动条宽（19）算进最小尺寸，视口会撑出页面。
##    页数仍 9 ⇒ 上限 9x90 = 810。总格数现在由**服务端读档时就向上补满整页**
##    （`SinglePlayerState.from_dict` → `page_aligned_capacity`：308 → 360、128 → 180），
##    所以标题「(已用/总)」、页签数（ceil(总/90)）、可直接用的格子三者同口径。
##    客户端仍保留「超出总格数的尾巴格隐藏」这一层防御：万一收到不是整页倍数的总格数，
##    宁可少画几格，也不画出玩家点不到的满格空格。
##    服务端 `BAG_PAGE_SIZE=90`、`扩容需求.每页格数("背包")`、`格数回退` 必须同步。
##
## 关键 AS3 出处（下面坐标是原版 275x394 的值，90 格版的改动见上一段）
##   :169   super(275, 394)                    窗口尺寸
##   :1108  title = 「背包」+ "(" + 已用 + "/" + totalCell + ")"
##   :1333  页数 = ceil(totalCell / 30)
##   :1341  页签 x = 17 + i*宽 + 3，y = 45，宽 = UIConfig.btn_width_one(25)
##   :1352  「扩充」紧接最后一个页签右边
##   :1439  格位 x = 40*(i%6) + 1*(i%6) + 4、y = 40*(i/6) + 1*(i/6) + 4
##   :913   totalCell = DataCenter.commonSlots，<=0 回退 96
##   :1370  底部四键 y = 281，x 从 16 起、逐个紧接，宽 btn_width_four(61)
##   :285   右列三键 x = 宽 − 57 − 18 = 200，y = 313 起、逐个 +高+2，宽 61

const 背包场景 := preload("res://场景/界面/窗口/背包/背包窗口.tscn")
const 格子提示框 := preload("res://脚本/界面/组件/格子提示框.gd")
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 数字格式 := preload("res://脚本/界面/数字格式.gd")
const 扩容需求 := preload("res://脚本/界面/扩容需求.gd")
const 勾玉炼制窗脚本 := preload("res://脚本/界面/窗口/勾玉炼制窗.gd")
const 秘笈合成窗脚本 := preload("res://脚本/界面/窗口/秘笈合成窗口.gd")
const 残卷放入格 := preload("res://脚本/界面/组件/残卷放入格.gd")
const 徽章打造窗脚本 := preload("res://脚本/界面/窗口/徽章打造窗.gd")
const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 装备部位表 := preload("res://脚本/单例/装备部位.gd")
## 「物品上架」模式位（原版 `UIConfig.isShangjiaItem` 是全局一份，判定就写在背包的点击分支里，
## `ItemWindow2.as:458-465`）。这里读的是 `交易窗.gd` 的那个静态位 ⇒ 两边同一份，不留第二份。
const 交易窗 := preload("res://脚本/界面/窗口/交易/交易窗.gd")
## 「摆摊上架」模式位（原版 `UIConfig.isDropItem` + `dropValidateFun` 那一对，全局一份，
## 判定同样写在背包的点击分支里 —— `ItemWindow2.as:440-444` 是**第一支**，比出售/仓库/交易都早）。
## 位与三道闸都在 `摊位窗.gd`，这里只读同一个位、把那一格递过去。
const 摊位窗 := preload("res://脚本/界面/窗口/摆摊/摊位窗.gd")

## 每页格数（用户 2026-10-31 口径 90 = 10 列 x 9 行；原版 `ItemWindow2.as:1333` 是 30 格/页）。
## ⚠ 同步：服务端 `BAG_PAGE_SIZE`、`扩容需求.每页格数("背包")`、本文件 `格数回退`。
const 每页格数 := 90
const 每页格数浮点 := 90.0
## `UIConfig.storageTabBtnName` = 语言表 ONE..NINE
const 页签名 := ["一", "二", "三", "四", "五", "六", "七", "八", "九"]
## 货币行文字色 = 16773120
const 色_货币 := Color("fff000")
## 货币**数值**字号（用户 2026-10-25：「金币、元宝、点券数…模糊，偏小」）。
## 原版真值仍是 12（`ItemWindow2.as:1401-1406` 的 `BaseUtil.getLabel` 默认 size=12）；
## 这里是有意的画面偏离。行标题「游戏金币」等仍是 12，只放大数值。
const 货币字号 := 14
## 背包标题「背包」二字的字号（用户 2026-10-25 说这截没问题，保持 14）。
## 原版是一整个 `MWindow.title` 文本（`ItemWindow2.as:1108` 拼「背包(已用/总)」）。
const 标题字号 := 14
## 标题尾巴「(已用/总)」的字号。用户 2026-10-25：「已用和总的值，还是模糊，大小差不多」，
## 换成 20 号后又说「有点太大了」，18 号之后又说「再小一点」——
## 真因是标题变体 `FontVariation` 的合成加粗把 ASCII 轮廓抹粗/走形（点阵只覆盖汉字，§3.281），
## 不是字号不够。裸字体实测：16 号数字墨高 11px、括号 14px、笔画 2px、字芯纯 255；
## 18 号 12px、20 号 14px。现取 **16 号**（用户第三次要求缩小）。
## 主标题仍用标题变体 14。
## ⚠️ 改这个数要同步 `测试/背包道具回归测试.gd` ⑯b 的期望字号。
const 格子数字号 := 16
## `ItemWindow2.as:915`：commonSlots <= 0 时的回退值。
## ⚠ 取**恰好一页** 90（10 列 x 9 行；旧的 96 会画出不足一页的空位）。
const 格数回退 := 90

## ⚠️ 页码**不放 static**：它一重建就丢。改存窗口上（`功能窗口._背包页`），
##    开窗时才复位 —— 见 `功能窗口.gd` 里那段注释
##    （2026-09-27 用户报「装备拖到人物面板后背包自动返回第一页」）。
static func _取页(窗口) -> int:
	return int(窗口._背包页)

static func _设页(窗口, 值: int) -> void:
	窗口._背包页 = 值
## 双击判定的间隔。原版是 `MSprite` 自己的 clickCount 计时器（`MCell` 的单击处理末尾
## 会 `clickCount = 0`），具体毫秒数没写在反编译出来的这几个类里。
## **300ms 这个数是我定的，2.2.3 里没有依据**（同 §3.9.7 那四个自定值）。
const 双击间隔毫秒 := 300
static var _上次点击物品 := ""
static var _上次点击时刻 := 0


static func 渲染(窗口) -> void:
	var 会话 = 窗口._session
	# ⚠️ 这里**不能**复位页码：`渲染()` 会被 `equipment_changed` / `inventory_changed`
	#    触发重建，一复位玩家刚翻到的那页就跳回第一页（原版只在**开窗**时回第一页）。
	var 页面 := 窗口._instantiate_page(背包场景) as Control
	var 总格数 := _背包总格数(会话)
	# "已用"数**占格数**不是数组长度（稳定格位制：数组里现在会有 {} 洞，
	# 用 size() 会把洞算进件数，2026-10-01 B）。
	窗口.设置标题("背包", 标题字号,
			"(%d/%d)" % [会话._占用数(会话.inventory), 总格数], 格子数字号)

	_渲染页签(窗口, 页面, 总格数)
	_渲染格子(窗口, 页面, 会话, 总格数)
	_渲染货币(窗口, 页面, 会话)
	_渲染按钮(窗口, 页面, 会话)
	var 菜单 := 页面.get_node_or_null("物品菜单")
	if 菜单 != null:
		菜单.connect("选择了", func(项名: String): _执行菜单项(窗口, 页面, 项名))
	var 扩容 := 页面.get_node_or_null("扩容窗口")
	if 扩容 != null:
		扩容.connect("确认扩充", func(_归属: String):
			var 后端 = 窗口._backend
			if 后端 == null or not 后端.has_method("request_cash_shop_capacity"):
				窗口._show_hint("扩充：未连接服务端")
			elif not 后端.request_cash_shop_capacity():   # CS_REQ_CATEGORY_EXTEND = 1084
				窗口._show_hint("扩充请求发送失败")
			# 发成功不提示：原版 `EnlargeWindow` 只发一跳，格数等 1084 回帧重绘。
		)
		# 「购买」= 原版 `EnlargeWindow.onClickBuy:169-174` 那跳 `REQUEST_CASH_ITEM_INFO`
		# （只带物品 id，自己不买东西）⇒ 走 `功能窗口.请求商城商品` 的统一出口。
		扩容.connect("请求购买", func(密卷id: String): 窗口.请求商城商品(密卷id))
	var 销毁 := 页面.get_node_or_null("销毁窗口")
	if 销毁 != null:
		# 按**槽位号**销（2026-10-01 A/C）：旧写法按 id 找第一摞 —— 同 id 两摞时会错杀
		# 另一格；拖到空处的确认销毁更是明确知道来源格的。
		销毁.connect("确认销毁", func(_归属: String, 槽位: int, _物品id: String, 件数: int):
			窗口._session.discard_inventory_slot(槽位, 件数)
		)
	var 拆分 := 页面.get_node_or_null("拆分窗口")
	if 拆分 != null:
		# 2026-10-01：改走 `会话.split_inventory_item` —— 在线仍是 ITEM_SPLIT 发包、
		# 回包驱动；离线补了本地拆分（原来这里离线只会说"未连接服务端"，点了没动静）。
		拆分.connect("确认拆分", func(位置: int, 数量: int):
			if not 窗口._session.split_inventory_item(位置, 数量):
				窗口._show_hint("拆分失败（数量不合法或背包已满）")
			else:
				窗口._show_hint("已拆分 %d 个" % 数量)
		)
	# —— 拖到空处松手 = 销毁链（C）。接盘是页面最底层的 `空白接盘` 节点。
	# 页面每次 渲染() 都新建，接盘也是新节点 ⇒ 不用防重复连接。 ——
	var 接盘 := 页面.get_node_or_null("空白接盘") as Control
	if 接盘 != null:
		接盘.connect("落在空白", _拖放落在空白.bind(窗口, 页面))


## 菜单里点了某一项。
## 已实现：佩戴、使用/全部使用、拆分（SplitWindow）、销毁（DestroyWindow）、
##   绑定（直发 `ITEM_CHANGE` 9，原版 `onClickPopupMenu :798` 就不开窗）。
## 移动不在这里 —— 原版「移动」也是起拖（`moveItem:1273` createDragDataProxy），见 _接拖拽 / _处理拖放。
## 其余（合成/强化/宝石镶嵌/破碎修复/升阶/镶嵌勾玉/开光/灵化/洗练/重置…）各自是独立窗口，
## 属装备或其它模块 —— 点了给明确反馈，不静默。
static func _执行菜单项(窗口, 页面: Control, 项名: String) -> void:
	match 项名:
		# 原版装备类菜单的第一项就是「佩戴」（`ItemWindow2.getItemMenu`），
		# 走 `useItem()` → `UI.useItem` → `requestEquipItem`（`UI.as:1346-1350`）——
		# 和双击"使用"是同一条路。客户端这条本来就通（双击能穿），
		# 缺的只是菜单项没接上，所以这里直接复用，不另写一套。
		"使用", "佩戴":
			窗口._use_item(窗口._selected_inventory_格)
		"宠物佩戴":
			# 原版 `MENU_CHONGWUPEIDAI:757` 走的是**另一条链**：`petPutOnEquip()`，不是 useItem。
			# 这一项以前谁也没接，掉进下面的兜底分支 ⇒ 只弹一句"还没接"，
			# 而菜单里它对每一件兽铠/兽爪…都会出现（`菜单项表[1]`）。
			_宠物佩戴(窗口, 窗口._selected_inventory_格,
					窗口._session._占用条(窗口._session.inventory, 窗口._selected_inventory_格))
		"全部使用":
			# 2026-10-01：以前和「使用」同路 —— useAll 从没传出去过，整摞永远只吃 1 个。
			窗口._use_item(窗口._selected_inventory_格, true)
		"拆分":
			_开拆分窗(窗口, 页面)
		"销毁":
			_开销毁窗(窗口, 页面)
		"移动":
			窗口._show_hint("移动：直接拖拽格子即可（同容器内换位；跨容器即存取）")
		"发到聊天框":
			# 原版 `ItemWindow2.as:483`：按住 Ctrl 单击走的就是这条，调
			# `chatPane.insertShowItem(getCellValue())` —— 往聊天输入框插「【物品名】」。
			var 物品: Dictionary = 窗口._inventory_item_by_id(窗口._selected_inventory_id)
			# ⚠️ 按 **group** 找，不按父链（2026-10-02）：`窗口.get_parent().get_node_or_null("聊天面板")`
			#   是**单窗时代**的写法——那时功能窗口直接挂在地图场景下，父链一步就到聊天面板。
			#   现在窗口挂在 `窗口管理`(CanvasLayer) 下、聊天面板是它的**兄弟**，那条链**永远拿到 null**
			#   ⇒ 菜单点「发到聊天框」实机只会弹"找不到聊天面板"（14bf477 接上真实行为后一直没被门点过，
			#   §3.78.1"信号在发但拿不到对象"的同族）。聊天面板场景根挂了组 `chat_panel`。
			var 聊天: Node = 窗口.get_tree().get_first_node_in_group("chat_panel")
			if 物品.is_empty() or 聊天 == null or not 聊天.has_method("insert_show_item"):
				窗口._show_hint("发到聊天框：找不到聊天面板")
			else:
				聊天.insert_show_item(String(物品.get("id", "")), String(物品.get("name", "")))
		"绑定":
			# 2026-10-02 实装。原版 `onClickPopupMenu :798` `requestBindItem(position)`
			# —— 不开窗、不确认，直发 `ITEM_CHANGE` 子命令 9。走**格位**（上面记下的那一格）。
			# 服务端回什么、离线怎么本地置位，全在 `游戏会话.bind_inventory_slot` 头上那段。
			窗口._session.bind_inventory_slot(窗口._selected_inventory_格)
		"强化":
			# 2026-10-02 实装。原版 `onClickPopupMenu :807-818` →
			# `UIMain2.showEquipStrengthWindowWithData:4846-4854` → `EquipStrengthWindow.init:302-308`：
			# **开窗、页签切到 param1=0（强化）、把点的那件直接放进左栏**（init 不走拖放门槛）。
			_开打造窗并放入(窗口)
			# 不 return：原版每个分支都关弹出菜单（`onClickPopupMenu:848 this.popupMenu=null`），
			#   收尾那句关的是 **物品菜单** 本身，和留在屏幕上的拆分/销毁窗不是同一个节点。
		"洗练":
			# 原版 `onClickPopupMenu` 的「洗炼」→ `showXiLianWindow(curCellData)`（**带物开窗**）。
			_开灵器炼制窗(窗口, "洗练")
		"灵化":
			# → `showLingHuaWindow(curCellData)`。
			_开灵器炼制窗(窗口, "灵化")
		"开光":
			# 灵器 → `showKaiGuangWindow(curCellData)`；**人具**（类型 65）→ `showRenJuKaiGuangWindow`。
			# 两扇版式相同、配置同为 `Etc.LingQi.kaiguang`，只有协议不同（LING 0 / RENJU 0）。
			_开灵器炼制窗(窗口, "开光人具" if _是忍具(窗口) else "开光")
		"破碎修复":
			# 原版 `onClickPopupMenu:802` → `showEquipRepairWindow(0, curCellData)`（**带物开窗**）。
			# ⚠️ 这一项只在**破碎**的装备菜单里出现（`filtrateItemMenu` 按 `crashTime` 二选一）。
			_开装备修复窗(窗口)
		"宝石镶嵌":
			# 2026-10-02 实装。原版 `onClickPopupMenu :777` → `showStoneCarryWindow(curCellData)`
			# —— 开「宝石镶嵌与取出」窗、带**这一格装备**。
			_开镶嵌窗(窗口)
		"镶嵌勾玉":
			# 原版 `onClickPopupMenu :827` → `showGouYuCarryWindow(curCellData)`。
			# ⚠️ 与「宝石镶嵌」**同一套版式、不同一条协议**：勾玉走 `ITEM_CHANGE` 13/14、
			# 宝石走 1/2（`ItemChangeProcessor.requestJadeInlay:564 writeByte(13)` vs
			# `requestInlay:235 writeByte(1)`）⇒ 这里传模式位。
			_开镶嵌窗(窗口, true)
		"升阶":
			# 原版 `onClickPopupMenu:819-820` `showYuLianJinJieWindow(0, curCellData)`（玉链进阶）。
			# ⚠️ 菜单表里「升阶」**只留给玉链**（徽章/其余装备都在 `getItemMenu` 里 erase 掉了）
			# ⇒ 走到这儿的就是玉链，直接开那一页。
			_开勾玉炼制窗(窗口, 0)
		"重置":
			# `:824` `showYuLianJinJieWindow(2, curCellData)`（勾玉重置）——菜单表里只有**勾玉**留着它。
			_开勾玉炼制窗(窗口, 2)
		"合成":
			# 2026-10-03 实装。原版 `onClickPopupMenu :780-797`：同一个「合成」按物品种类**分四扇窗**——
			# 残卷→`showCanJuanHeChengWindowWithData`、徽章石→`showBeastBadgeCreateWindowWithData(0,…)`、
			# 宝石且勾玉→`showYuLianJinJieWindow(1,…)`、**其余宝石**→
			# `UIMain2.showStoneWindowWithData:4523-4540`（先判 `nextId==0` 满级：弹话、**连窗都不开**；
			# 否则开「宝石工艺」窗切到合成页并 `showCompositeWindow(curCellData)` 带那颗进去）。
			_开合成窗(窗口)
		_:
			# 走到这里 = 菜单表里冒出一项**分派表没写**的（不是"故意不做"，是漏）。
			窗口._show_hint("%s：还没接 —— 背包菜单这一项没有分派" % 项名)
	var 菜单 := 页面.get_node_or_null("物品菜单") as Control
	if 菜单 != null:
		菜单.call("收起")


## 宠物装备「佩戴」的 UI 侧 = 原版 `ItemWindow2.petPutOnEquip:209-219`：
## **绿（`CocoEquip.APTITUDE_GREEN`=3）/ 紫（`APTITUDE_PURPLE`=4）且还能交易**的装备先弹
## `PEIDAI_BANGDING`（语言表 :2864，原文就是这段嵌套 `<font>`+`<br/>`；`弹消息` 自己会换算 BBCode），
## 点「确定」(=MDialog.OK=1) 才发；其余直接发。菜单项（`:757`）与双击（`:880`）两个入口共用。
## ⚠️ 这不是"提示而已"：服务端 `_binds_when_equipped` 用的正是同一判据 `{3,4}`+can_trade，
##    确认框背后那次绑定**不可逆**。
const 佩戴绑定正文 := "<font color=\"#ff0000\">佩戴后，该装备将与您绑定。<br/><font color=\"#00ff00\">您希望佩戴该装备吗？</font></font>"

static func _宠物佩戴(窗口, 格位: int, 物品: Dictionary) -> void:
	if 物品.is_empty():
		return
	if bool(物品.get("can_trade", true)) and int(物品.get("aptitude", 0)) in [3, 4]:
		确认弹.弹消息(窗口._overlay, 佩戴绑定正文, func(码: int) -> void:
			if 码 == 1:
				窗口._use_item(格位))
		return
	窗口._use_item(格位)


## 「升阶 / 重置 / 合成(勾玉)」三支开的是**同一扇**「勾玉炼制」窗，只是页签不同 ——
## 逐字照原版 `ItemWindow2.as:793/821/824` 的三处 `showYuLianJinJieWindow(页, curCellData)`：
##   升阶 → 页0 玉链升阶 ／ 合成(勾玉) → 页1 勾玉合成 ／ 重置 → 页2 勾玉重置。
## 物品**随窗带进去**（提交发的是它的槽位）—— 原版传的就是那一格 `curCellData`。
static func _开勾玉炼制窗(窗口, 页: int) -> void:
	var 格 := _选中格(窗口)
	if 格 <= 0:
		格 = 窗口._session._inventory_index(窗口._selected_inventory_id) + 1
	if 格 <= 0:
		窗口._show_hint("勾玉炼制：这一格取不到原版槽位")
		return
	var 条: Dictionary = 窗口._session._占用条(窗口._session.inventory, 格)
	if 条.is_empty():
		return
	# 同 `_开打造窗并放入`：稳定格位制的不变量是 `slot_index 恒 = 下标 + 1`，离线示例件没这个字段
	if int(条.get("slot_index", 0)) != 格:
		条["slot_index"] = 格
	var 管理: Node = 窗口.get_parent()
	if 管理 == null or not 管理.has_method("打开") or not 管理.has_method("取窗口"):
		窗口._show_hint("勾玉炼制：找不到窗口管理")
		return
	管理.call("打开", "勾玉炼制")
	var 炼制窗: Node = 管理.call("取窗口", "勾玉炼制")
	if 炼制窗 == null:
		窗口._show_hint("勾玉炼制：窗没开出来")
		return
	炼制窗.set("_jade_item", 条.duplicate(true))
	# 从物品菜单开一次 = 原版**新建一扇窗**（`_itemData` / 三页料 / 上一次合成结果全空）
	# ⇒ 先复位控制器静态态，再指定要落的页签。
	勾玉炼制窗脚本.新会话()
	勾玉炼制窗脚本._页 = 页
	炼制窗.call("_render_page")


## 开「秘笈合成」窗并把这一格残卷带进去。
## 原版 `UIMain2.showCanJuanHeChengWindowWithData:5848-5860`：`centerTwoWindow(秘笈合成, 背包)`
## + `equipUpgrageWindow.validateItem(curCellData)` —— **开窗即带物**。
## 我们的"放入态"是 `秘笈合成窗口._放入格`（1 基槽位；`残卷放入格` 拖放也写它）⇒
## **先设好再开页**，`渲染` 末尾那次 `_刷视图` 就会把它画出来。
## 背包那半边靠 `窗口管理.伴随背包` 登记「技能书」（原版那两个开窗入口都走 `centerTwoWindow`）。
static func _开秘笈合成带物(窗口, 格: int) -> void:
	var 管理: Node = 窗口.get_parent()
	if 管理 == null or not 管理.has_method("打开"):
		窗口._show_hint("合成：找不到窗口管理")
		return
	秘笈合成窗脚本._放入格 = 格
	管理.call("打开", "技能书")


## 昆虫 → 原版 `KunChongManager.showStrengthView(curCellData)`（`ItemWindow2.as:808-811`）：
## 开**昆虫强化视图**并带上这只虫。本工程的昆虫强化是**人物窗口的「寄坏之术」页**
## （`子分页组[1] = ["八门","柔拳","寄坏之术"]` ⇒ 主分页 1 / 子分页 2）⇒ 打开人物窗、切到那一页，
## 并把这只虫记成强化目标。跨窗状态设在**渲染那一页的宿主**上（§3.62 那条老坑）。
## ⚠️ 位置传**背包格号**（不是装备位）：服务端 `_strengthen_kun_chong` 拿它 `inventory.get(slot)`
##    取件，背包里的虫只有按格号才取得到（已装备的才走 -200..-203）。
static func _开寄坏之术带虫(窗口, 条: Dictionary, 格: int) -> void:
	var 管理: Node = 窗口.get_parent()
	if 管理 == null or not 管理.has_method("打开") or not 管理.has_method("取窗口"):
		窗口._show_hint("昆虫强化：找不到窗口管理")
		return
	管理.call("打开", "人物")
	var 人窗: Node = 管理.call("取窗口", "人物")
	if 人窗 == null:
		窗口._show_hint("昆虫强化：人物窗没开出来")
		return
	人窗.set("_角色携入虫", 条.duplicate(true))
	人窗.set("_角色携入位置", 格)
	人窗.call("_set_character_main_tab", 1)
	人窗.call("_set_character_sub_tab", 2)


## 开「徽章打造」窗并切到指定页：原版 `showBeastBadgeCreateWindowWithData(页, curCellData)`
## （页 0 = 合成徽章石、页 1 = 打造徽章）。
## ⚠️ 原版那第二参是**带物**（把这一格放进投料盒），本工程那扇窗的**投料还没做**
## （原版是 `ItemCaiLiaoBox` 的光标/拖放，见 `徽章打造窗._点放入` 的说明）⇒ 这里只把
## **导航**接对：开窗 + 切页。缺的那半已登记在案，不假装接上。
static func _开徽章打造窗(窗口, 页: int) -> void:
	var 管理: Node = 窗口.get_parent()
	if 管理 == null or not 管理.has_method("打开"):
		窗口._show_hint("徽章打造：找不到窗口管理")
		return
	徽章打造窗脚本._页 = 页
	管理.call("打开", "徽章打造")


## 打开「格数扩展」窗（原版 `EnlargeWindow`，背包那条 `_isItemWindow = 0`）。
## 每页要几个密卷取自 `数据/界面/扩容需求.json`（真值来自 GameData `Etc.BeibaoKuozhan`），
## 下标用法以服务端为准：`page_index = max(0, ceil(当前容量/30)-1)`。
static func _开扩容窗(窗口, 页面: Control, 总格数: int, 页数: int) -> void:
	var 窗 := 页面.get_node_or_null("扩容窗口") as Control
	if 窗 == null:
		return
	var 需求 := 扩容需求.取需求("背包", 页数)
	窗.call("打开", "背包", 页数, 需求["需要数量"], 需求["密卷id"], 扩容需求.拥有数(窗口._session, 需求["密卷id"]))
	# 物品格 = 原版 `ItemWindowCell`（`EnlargeWindow.as:239`，悬停 `:309-314` 挂 MToolTipItem）
	窗口._接打造提示(页面, 窗.get_node_or_null("物品格") as Control,
			int(需求["密卷id"]), 扩容需求.拥有数(窗口._session, 需求["密卷id"]))


## 打开拆分窗。原版 `ItemWindow2.splitItem()`（`:1166-1171`）就是
## `splitWindow.setData(itemData)` + `PopUpMananger.addWindow(splitWindow)`：
## 件数决定上限、**position 随确认一起发给服务端**（1 基绝对格位）。
static func _开拆分窗(窗口, 页面: Control) -> void:
	var 拆分 := 页面.get_node_or_null("拆分窗口") as Control
	if 拆分 == null:
		return
	# ⚠️ **优先用单击记下的格位**（2026-10-02）：`_inventory_item_by_id`/`find` 都按 id 取第一摞，
	#   **同 id 两摞时会拆错格**——正是 §3.81.1 给销毁修过的"按 id 反查"残留，拆分这条漏了。
	#   原版 `splitItem()` 拿的是 `curCellData`（那一格的实例），position 随确认一起发。
	var 格 := _选中格(窗口)
	var 物品: Dictionary = 窗口._session._占用条(窗口._session.inventory, 格)
	if 物品.is_empty():
		物品 = 窗口._inventory_item_by_id(窗口._selected_inventory_id)   # 兜底：格位丢了仍按 id
		if 物品.is_empty():
			return
		格 = 窗口._session._inventory_index(String(物品.get("id", ""))) + 1
	var 件数 := int(物品.get("quantity", 1))
	if 件数 <= 1:
		窗口._show_hint("数量为 1 的物品不能拆分")
		return
	拆分.call("打开", 件数, 格)   # position 是 1 基


## 打开销毁窗。原版 `ItemWindow2.destroyItem()`（`:633-`）→ `DestroyWindow.setData`，
## 销毁数量就是**整叠件数**（`DestroyWindow.as:57-62` 的 `dropCount = count`）。
## 背包这条走已有的 `游戏会话.discard_item`（底层 `ITEM_MOVE`：`byte0, src, 0, count`）。
static func _开销毁窗(窗口, 页面: Control) -> void:
	var 格: int = _选中格(窗口)
	if 格 <= 0:
		# 选中格失效（弹菜单后那格被异步换件/清空）→ 退回按 id 找第一摞（老口径）。
		# 常态走不到这里：`_选中格` 有效时**永远按那一格**，同 id 两摞不开错窗。
		格 = 窗口._session._inventory_index(窗口._selected_inventory_id) + 1
	if 格 <= 0:
		return
	_开销毁窗按格(窗口, 页面, 格)

## 「强化」菜单项：开装备打造窗、页签切 0、把**点的那一格**放进左栏。
## 原版链：`onClickPopupMenu :807-818` → `UIMain2.showEquipStrengthWindowWithData:4846-4854`
## → `EquipStrengthWindow.init:302-308`（`_tabBar.selectedIndex = param1(0)`、`_itemData = param2`）
## —— 菜单这条路是**开窗即带物**，不走拖放的门槛校验；放进复用现成的 `_应用选中部位`
## （页签=强化时它的门槛校验本来就全放行，和 init 的放行口径一致）。
## ⚠️ 原版那两个分流**各有各的窗**，别塞进通用打造窗：
##   · 昆虫（id 前三位 131，`:808-811`）→ `KunChongManager.showStrengthView(curCellData)`；
##   · 徽章（四位码 141，`:813-816`）→ `showBeastBadgeCreateWindowWithData(1,…)`（页 1 = 打造）。
static func _开打造窗并放入(窗口) -> void:
	var 格 := _选中格(窗口)
	if 格 <= 0:
		格 = 窗口._session._inventory_index(窗口._selected_inventory_id) + 1
	if 格 <= 0:
		return
	var 条: Dictionary = 窗口._session._占用条(窗口._session.inventory, 格)
	if 条.is_empty():
		return
	# ⚠️ **把格号写回会话里的这一格**（2026-10-02）：稳定格位制的不变量是"slot_index 恒=下标+1"，
	#   在线件由 `落位带洞` 补好、**离线示例件却没带这个字段**。打造页左栏是"现读"
	#   （`_会话选中()` 按 `格+id` 回查、找不到就 `backItemToEquip` 落回"没放"）——
	#   不补的话，离线放进 → 下一次渲染就自己清了，"放进去的件凭空消失"。
	#   `条` 就是 `inventory[格-1]` 的引用，写它即维护这条不变量。
	if int(条.get("slot_index", 0)) != 格:
		条["slot_index"] = 格
	var id文本 := String(条.get("id", ""))
	var 补零 := id文本.pad_zeros(8) if id文本.is_valid_int() else id文本
	# 昆虫 → 原版 `KunChongManager.showStrengthView(curCellData)`：开昆虫强化视图并**带上这只虫**。
	# ⚠️ **判据必须是"四位码 0131"（等价于服务端的 `item_id // 10000 == 131`、也等价于
	#    `装备部位.位置 == 昆虫包`），不是前三位** —— 昆虫的 id 是 `01310001..01310006`
	#    （八位补零后前三位是 `013`），而**前三位 `131` 的是勾玉**（`13100000` 起，360 件）！
	#    2026-10-11 抓到的真 bug：旧写法 `int(补零.substr(0,3)) == 131` 一件真昆虫都匹配不到
	#    ⇒ 点「强化」掉进**通用打造窗**（左栏还放不进去）；要真放进来，反而会误伤勾玉
	#    （勾玉菜单里没有「强化」所以没炸，属于侥幸）。
	if 装备部位表.位置(补零) == 装备部位表.昆虫包:
		_开寄坏之术带虫(窗口, 条, 格)
		return
	if 补零.length() >= 4 and int(补零.substr(0, 4)) == 141:
		# 徽章 → `showBeastBadgeCreateWindowWithData(1, curCellData)`（页 1 = 打造）。
		# ⚠️ 同 `合成` 的徽章石那支：只接**导航**（开窗 + 切页 1），那扇窗的投料还没做。
		_开徽章打造窗(窗口, 1)
		return
	# ⚠️ **跨窗状态要设在渲染那一页的宿主上**（§3.62 咬过两回的老坑，门 ⑬ 专门钉这条）。
	var 管理: Node = 窗口.get_parent()
	if 管理 == null or not 管理.has_method("打开") or not 管理.has_method("取窗口"):
		窗口._show_hint("强化：找不到窗口管理")
		return
	管理.call("打开", "装备强化")
	var 打窗: Node = 管理.call("取窗口", "装备强化")
	if 打窗 == null:
		窗口._show_hint("强化：打造窗没开出来")
		return
	打窗.set("_strengthen_tab", 0)          # init 的 param1 = 页签
	var 件: Dictionary = 条.duplicate(true)
	件["put_on"] = false                     # 背包件（`put_on` 是装配时打的标，别拿 id 反查）
	if not bool(打窗.call("_应用选中部位", 件)):
		窗口._show_hint("强化：这件放不进打造窗")
	打窗.call("_render_page")


## 「合成」菜单项 → 开「宝石工艺」窗（页面名沿用 "挖矿"）、切到合成页、带**这一格宝石**。
## 原版 `onClickPopupMenu :780-797` 按种类分四扇窗；这里只接**普通宝石**那一支，
## 其余三支是别的独立窗（残卷合成窗 / 徽章石打造窗 / 玉链进阶窗），给诚实提示、不塞错窗。
## ⚠️ 开窗走 `打开` 两次的老规矩：`窗口管理.打开` 先按**旧状态**渲一遍，设好放置态再渲第二遍。
static func _开合成窗(窗口) -> void:
	var 格 := _选中格(窗口)
	if 格 <= 0:
		格 = 窗口._session._inventory_index(窗口._selected_inventory_id) + 1
	if 格 <= 0:
		return
	var 条: Dictionary = 窗口._session._占用条(窗口._session.inventory, 格)
	if 条.is_empty():
		return
	var 物品id := String(条.get("id", ""))
	var 补零 := 物品id.pad_zeros(8) if 物品id.is_valid_int() else 物品id
	var 类型号 := int(补零.substr(0, 2)) if 补零.length() >= 2 else 0
	# ① 残卷（技能/宠物）：原版 `showCanJuanHeChengWindowWithData:5848-5860`
	#    = `centerTwoWindow(秘笈合成, 背包)` + `validateItem(curCellData)`（**带物开窗**）。
	#    判据用**这一族自己那套** `残卷放入格.有配方`（`canjuan_book > 0`）—— 它与
	#    `ItemType.isItemJiNengCanJuan`（类型 8/9）同源，且正是那扇窗收投放的判据。
	if 残卷放入格.有配方(物品id):
		_开秘笈合成带物(窗口, 格)
		return
	# ② 徽章石：原版 `showBeastBadgeCreateWindowWithData(0, curCellData)`（页 0 = 合成）。
	#    ⚠️ 那扇窗的**投料**（把石头放进格）本工程还没做（原版是 `ItemCaiLiaoBox` 的光标/拖放，
	#    见 `徽章打造窗._点放入` 的说明）⇒ 这里把**导航**接对（开窗+切页），投料那条另记。
	if 补零.length() >= 3 and int(补零.substr(0, 3)) == 132:
		_开徽章打造窗(窗口, 0)
		return
	if 类型号 != 13:
		# 其它非宝石（人具/货币…）原版落进 `showStoneWindowWithData` 也开不出东西 ⇒ 诚实说一句。
		窗口._show_hint("合成：这一类没有对应的合成窗")
		return
	if 补零.substr(0, 3) == "131":
		# 勾玉 → `showYuLianJinJieWindow(1, curCellData)`（**勾玉合成那一页**），和宝石合成不是一扇窗
		_开勾玉炼制窗(窗口, 1)
		return
	# 满级那颗**不开窗**（`UIMain2.showStoneWindowWithData:4529-4533`：先 addNotice 再 return）。
	# 文案逐字取 `CN.IS_STONE_LEVEL_MAX` = 「该宝石已经是最高等级！」。
	if int(GAME_DATA.item(物品id).get("stone_next", 0)) <= 0:
		窗口._session.notification_requested.emit("该宝石已经是最高等级！")
		return
	var 管理: Node = 窗口.get_parent()
	if 管理 == null or not 管理.has_method("打开") or not 管理.has_method("取窗口"):
		窗口._show_hint("合成：找不到窗口管理")
		return
	管理.call("打开", "挖矿")
	var 窗: Node = 管理.call("取窗口", "挖矿")
	if 窗 == null:
		窗口._show_hint("合成：窗没开出来")
		return
	窗.set("_stone_tab", 0)        # 合成页（原版 `showCompositeWindow` 切 tab 0）
	窗.set("_宝石合成格", 格)
	窗.set("_宝石合成id", 物品id)
	窗.set("_宝石合成结果", {})     # 带新宝石进来，上一次的三格结果清掉
	窗.call("打开")                 # 第二遍：用刚设好的放置态重渲（同 `_开镶嵌窗` 那条坑）


## 「宝石镶嵌」菜单项 → 开「宝石镶嵌与取出」窗、带这一格装备。
## 原版 `onClickPopupMenu:777` → `showStoneCarryWindow(curCellData)`，`StoneCarryWindow.setData` 存 `_eqtData`。
## ⚠️ 跨窗状态设在渲染那页的宿主上（§3.62 那条老坑）。
## 开「灵器炼制」窗（洗练/灵化/开光三扇版式相同、只换文案与材料格）并带上这一件灵器。
## 原版 `showXiLianWindow / showLingHuaWindow / showKaiGuangWindow(curCellData)` 三处都是**带物开窗**。
## 这一格点中的是不是**忍具（人具）**：`ItemType.getItemTypeFromId == 65`
## （`装备部位` 的 `_前七位表[65] = 忍具`，走同一个口径）。
static func _是忍具(窗口) -> bool:
	var 条: Dictionary = 窗口._session._占用条(窗口._session.inventory, _选中格(窗口))
	if 条.is_empty():
		return false
	return 装备部位表.位置(String(条.get("id", ""))) == 装备部位表.忍具


static func _开灵器炼制窗(窗口, 模式: String) -> void:
	var 格 := _选中格(窗口)
	if 格 <= 0:
		格 = 窗口._session._inventory_index(窗口._selected_inventory_id) + 1
	if 格 <= 0:
		return
	var 条: Dictionary = 窗口._session._占用条(窗口._session.inventory, 格)
	if 条.is_empty():
		return
	var 管理: Node = 窗口.get_parent()
	if 管理 == null or not 管理.has_method("打开") or not 管理.has_method("取窗口"):
		窗口._show_hint("%s：找不到窗口管理" % 模式)
		return
	管理.call("打开", 模式)
	var 窗: Node = 管理.call("取窗口", 模式)
	if 窗 == null:
		窗口._show_hint("%s：窗没开出来" % 模式)
		return
	窗.call("带物开窗", 模式, 条, 格)     # 原版各窗的 `setData`：写 `_itemId`/`_itemPos`，洗炼那扇另灌 plusAttr
	窗.call("打开")            # 设好状态**再开一次**（同 `_开镶嵌窗`）


## 开「破碎装备修复」窗并带上这一格装备（原版 `showEquipRepairWindow(0, curCellData)`，
## `EquipRepairWindow.init(0, 装备)` 把页签设为 0、把那件放进台子）。
static func _开装备修复窗(窗口) -> void:
	var 格 := _选中格(窗口)
	if 格 <= 0:
		格 = 窗口._session._inventory_index(窗口._selected_inventory_id) + 1
	if 格 <= 0:
		return
	var 条: Dictionary = 窗口._session._占用条(窗口._session.inventory, 格)
	if 条.is_empty():
		return
	var 管理: Node = 窗口.get_parent()
	if 管理 == null or not 管理.has_method("打开") or not 管理.has_method("取窗口"):
		窗口._show_hint("修复：找不到窗口管理")
		return
	管理.call("打开", "装备修复")
	var 修窗: Node = 管理.call("取窗口", "装备修复")
	if 修窗 == null:
		窗口._show_hint("修复：窗没开出来")
		return
	修窗.set("_装备修复物品", 条.duplicate(true))
	修窗.set("_装备修复格", 格)
	修窗.call("打开")            # 同 `_开镶嵌窗`：设好状态**再开一次**，第二次才用对状态渲


static func _开镶嵌窗(窗口, 勾玉模式 := false) -> void:
	var 格 := _选中格(窗口)
	if 格 <= 0:
		格 = 窗口._session._inventory_index(窗口._selected_inventory_id) + 1
	if 格 <= 0:
		return
	var 条: Dictionary = 窗口._session._占用条(窗口._session.inventory, 格)
	if 条.is_empty():
		return
	var 管理: Node = 窗口.get_parent()
	if 管理 == null or not 管理.has_method("打开") or not 管理.has_method("取窗口"):
		窗口._show_hint("宝石镶嵌：找不到窗口管理")
		return
	管理.call("打开", "宝石镶嵌")
	var 镶窗: Node = 管理.call("取窗口", "宝石镶嵌")
	if 镶窗 == null:
		窗口._show_hint("宝石镶嵌：窗没开出来")
		return
	镶窗.set("_宝石镶嵌装备格", 格)
	镶窗.set("_宝石镶嵌装备id", String(条.get("id", "")))
	镶窗.set("_镶嵌勾玉模式", 勾玉模式)
	# ⚠️ 上面 `打开` 那一句会**先用旧状态（装备格=0）渲染一次**，而镶嵌窗的渲染在
	#   "装备不在原格"时会 `close()` —— 于是窗口刚建出来就被自己关了。
	#   设好状态后**再打开一次**：这次 `_固定页` 已就位 → 显示遮罩 + 用正确状态重渲。
	# ⚠️ 第二次也必须**经窗口管理**打开：直接 `镶窗.call("打开")` 会走 `open_page` →
	#   `_apply_original_window` 重新居中，把第一次打开时 `centerTwoWindow` 摆好的
	#   成对位置整个冲掉（2026-11-02 用户报「镶嵌面板优先级低于背包/位置不对」的根因）。
	管理.call("打开", "宝石镶嵌")


## 单击记下的那一格（`_选中格子` 里从 `格子.槽位号` 抄的，和原版 `curCellData` 同物）。
## 校验"那格确实是选中的 id"才敢用——重渲染后旧格位可能空了/换件了，返回 -1 让调用方退回按 id。
static func _选中格(窗口) -> int:
	var 格 := int(窗口._selected_inventory_格)
	if 格 < 1:
		return -1
	var 条: Dictionary = 窗口._session._占用条(窗口._session.inventory, 格)
	if 条.is_empty() or String(条.get("id", "")) != 窗口._selected_inventory_id:
		return -1
	return 格

## 按**格号**开销毁确认窗（菜单路径与"拖到空处"的确认分支共用；
## 原版 `ItemWindow2.showDestroyWindow(itemData)` 也是拿着那一格的实例）。
static func _开销毁窗按格(窗口, 页面: Control, 格: int) -> void:
	var 销毁 := 页面.get_node_or_null("销毁窗口") as Control
	if 销毁 == null:
		return
	var 物品: Dictionary = 窗口._session._占用条(窗口._session.inventory, 格)
	if 物品.is_empty():
		return
	var 图标: Texture2D = null
	var 路径 := String(物品.get("icon", ""))
	if ResourceLoader.exists(路径):
		图标 = load(路径) as Texture2D
	销毁.call("打开", String(物品.get("id", "")), String(物品.get("name", "")),
		图标, int(物品.get("quantity", 1)), "背包", 格)


## —— 拖到空处松手 = 销毁链（C）——
## 判定表照 `ItemWindow2.destroyItem:633-678`（`ItemType.getTypeFromId = int(id/1e6)`，
## 类型号见 `ItemType.as:9-61`）：
##   · [6,7,8,9 技能书/残卷、11 礼包、12 材料、13 宝石、14 舍利子、15 特殊、16 辅助、
##     19 魂戒、20 灵器、65 忍具] → **一律先弹 DestroyWindow 确认**（原 case 群直接 showDestroyWindow）；
##   · 玩家装备(1)/宠物装备(2)：强化>0 / 有镶嵌 / 紫资质(4) / 阶 >= 角色档 / 时装(21) /
##     宠物时装(05) / 玉链(120) / 徽章(141) 任一命中 → 确认；否则**整摞直接销**；
##   · 其余（3/4/5 药剂、10 任务物品…）→ 直接销。
## ⚠️ 用户常以为"材料随手拖就该掉"—— 原版材料(12)在**确认组**里，别自作主张挪出来。
static func 拖放销毁决定(会话, 物品: Dictionary) -> String:
	var 物品id := String(物品.get("id", ""))
	if not 物品id.is_valid_int():
		return "销毁"
	var 补零 := 物品id.pad_zeros(8)
	var 类型 := int(物品id.to_int() / 1000000)
	if 类型 in [6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 19, 20, 65]:
		return "确认"
	if 类型 == 1 or 类型 == 2:
		if int(物品.get("strengthen", 0)) > 0:
			return "确认"
		if (物品.get("inlays", []) as Array).size() > 0:
			return "确认"
		if int(物品.get("aptitude", 1)) == 4:
			return "确认"
		if 补零.substr(2, 2) == "21" or (类型 == 2 and 补零.substr(2, 2) == "05"):
			return "确认"
		if int(补零.substr(0, 4)) in [120, 141]:
			return "确认"
		if int(GAME_DATA.item(补零).get("stage", 1)) >= _角色装备阶(会话):
			return "确认"
		return "销毁"
	return "销毁"

## 原版 `DataCenter.curEquipStage:1374-1396`：等级 20/40/60/80/100 → 档 2..6。
static func _角色装备阶(会话) -> int:
	var 等级 := int(会话.player_stats.get("level", 1))
	for 档 in range(6, 1, -1):
		if 等级 >= (档 - 1) * 20:
			return 档
	return 1

static func _拖放落在空白(载荷: Dictionary, 窗口, 页面: Control) -> void:
	var 来源格 := 载荷.get("来源格") as Button
	if 来源格 == null:
		return
	var 格 := int(来源格.槽位号)
	var 物品: Dictionary = 窗口._session._占用条(窗口._session.inventory, 格)
	if 物品.is_empty() or String(物品.get("id", "")) != String(载荷.get("物品id", "")):
		return      # 起拖后那格换过东西/已空 → 什么都不发生（原版此时件已不在代理手里）
	match 拖放销毁决定(窗口._session, 物品):
		"确认":
			_开销毁窗按格(窗口, 页面, 格)
		_:
			if 窗口._session.drop_destroy_inventory_slot(格):
				窗口._show_hint("已销毁：%s" % String(物品.get("name", "物品")))


## `DataCenter.commonSlots`。客户端的存档里还没有这个字段（服务端走 CHAR_INFO 下发），
## 所以取不到时按 `格数回退`（原版 AS3 值 96；90 格/页取恰好一页 90）。
## 背包总格数（`ItemWindow2` 的 totalCell）。
##
## ⚠️ 顺序不能反：**先看服务端给的权威值，再退回属性键，最后才是兜底常量**。
##    2026-09-27 用户报"活跃度奖励提示背包空间不足，实际上我背包是有空间的"——
##    真因就是这里：服务端 `bag_capacity` 是 **90**，而这条链一路退到常量 **96**，
##    界面上凭空多出 6 个空格，玩家以为还放得下，服务端却按 90 算 → 判"背包已满"。
static func _背包总格数(会话) -> int:
	var 后端: Node = 会话.get_node_or_null("/root/BackendConnection")
	if 后端 != null and int(后端.authoritative_bag_capacity) > 0:
		return int(后端.authoritative_bag_capacity)
	var 值 := int(会话.player_stats.get("common_slots", 0))
	return 值 if 值 > 0 else 格数回退


## 页签：页数 = ceil(总格数/每页格数)，最多 9 个（页签名只有一~九）。
## 当前页的按钮 `enabled = false`（`createTabBtn` 末尾 `curBtn.enabled = false`）。
static func _渲染页签(窗口, 页面: Control, 总格数: int) -> void:
	var 页数 := int(ceilf(总格数 / 每页格数浮点))
	页数 = clampi(页数, 1, 页签名.size())
	for 序号 in 页签名.size():
		var 分页 := 页面.get_node("分页/第%d页" % (序号 + 1)) as Button
		窗口._apply_tab_skin(分页)
		分页.text = 页签名[序号]
		分页.visible = 序号 < 页数
		# 页签宽度按 AS3 压到 25（`MTabButtonF` 是 39 宽、`isScale9Grid = false` 时直接横向压扁）。
		分页.pressed.connect(_切页.bind(窗口, 页面, 序号))
	var 扩充 := 页面.get_node("分页/扩充") as Button
	窗口._apply_tab_skin(扩充)
	# 「扩充」摆在最后一个页签右边（`activeBtn.x = 最后一个页签.x + 它的宽`）；
	# 页数 >= 9 时原版把它藏起来。
	扩充.position.x = 20.0 + 25.0 * 页数
	扩充.visible = 页数 < 9
	扩充.pressed.connect(_开扩容窗.bind(窗口, 页面, 总格数, 页数))
	_刷新页签选中(窗口, 页面, 页数)


static func _刷新页签选中(窗口, 页面: Control, 页数: int) -> void:
	for 序号 in 页签名.size():
		var 分页 := 页面.get_node("分页/第%d页" % (序号 + 1)) as Button
		if not 分页.visible:
			continue
		窗口.选页签(分页, 序号 == _取页(窗口))
		# AS3 用 `enabled = false` 表示"当前页"（MTabButton 的禁用态就是选中态）。
		分页.disabled = 序号 == _取页(窗口)


static func _切页(窗口, 页面: Control, 序号: int) -> void:
	if 序号 == _取页(窗口):
		return
	_设页(窗口, 序号)
	_刷新页签选中(窗口, 页面, 页签名.size())
	var 菜单 := 页面.get_node_or_null("物品菜单") as Control
	if 菜单 != null:
		菜单.call("收起")
	_渲染格子(窗口, 页面, 窗口._session, _背包总格数(窗口._session))


## 90 个格子按**当前页**填。绝对格位 position 是 1 基：
## 页 = ceil(position/90)、页内下标 = (position-1) % 90。
## 客户端的 inventory 是**稳定格位数组**（格号=下标+1，空格是 {} 洞，2026-10-01 B），
## 所以页内下标 = 页*90 + i，**空位照原版画空格**（旧紧凑数组"吃一件挪一挪"就是
## 用户报②"背包自动整理"的病根）。
## ⚠️ 绝对格位 > `总格数` 的尾巴格**隐藏**：真档的总格数读档时已被服务端补成整页
##    （`page_aligned_capacity`），这条只在收到非整页值时兜底；
##    以前第 2 页照样画满 90 格 ⇒ 永远放不进东西的空格（用户：「占用数/总不对」）。
static func _渲染格子(窗口, 页面: Control, 会话, 总格数: int) -> void:
	var 背包: Array = 会话.inventory
	var 起点 := _取页(窗口) * 每页格数
	var 格子容器 := 页面.get_node("格子滚动/格子容器") as Control
	for 序号 in 每页格数:
		var 格子 := 格子容器.get_node("物品格_%d" % 序号) as Button
		var 数量 := 格子.get_node("数量") as Label
		格子.visible = 起点 + 序号 + 1 <= 总格数
		格子.icon = null
		格子.disabled = true
		格子.theme_type_variation = 皮肤表.变体_物品格按钮
		格子.focus_mode = Control.FOCUS_NONE
		数量.text = ""
		# 字号 **14**（用户 2026-10-25：「背包可堆叠道具的数量显示字体，可以略微大一点」）。
		# 原版真值是 12（AS3 `ItemWindowCell:62 _loc1_.size = 12`），这里是有意的画面偏离：
		# 14px 的「20」是 10px 高（12px 时 8px），仍走单色光栅、字芯全 255；
		# 14 也落在宋体点阵档（12~17）里，所以不管汉字还是 ASCII 都不会发糊。
		# 右下位置 + **右对齐**在场景 `物品格.tscn` 里定（Flash autoSize=RIGHT：右边界固定、往左长）；
		# 黑描边（≈原版 GlowFilter 2px）由 configure_label 给。
		# ⚠️ 不要加粗：§3.281 的教训是全局 `FontVariation.embolden` 只作用于走轮廓的 ASCII，
		#    12/14px 的数字会被抹成一圈中间灰 —— 大一号就够，字重保持 default_font 的裸 FontFile。
		窗口._configure_label(数量, 14, Color.WHITE)
		格子.物品id = ""
		_接拖拽(窗口, 格子, 起点 + 序号 + 1)
		_接提示框(窗口, 页面, 格子, {}, true)
		var 下标 := 起点 + 序号
		var 物品: Dictionary = 背包[下标] if 下标 < 背包.size() else {}
		if 物品.is_empty():
			# 空格（越界**或洞**）才清覆盖层。⚠️ 原来这里是**每格无条件"先清再设"**——
			# 清的那一下会停掉流光，随后 `设置品质` 又从头播 ⇒ 每次重渲染所有紫橙装
			# "转一半跳回开头"。同物品重渲染的去重现在归 `装备品质.挂流光` 的身份判断管（咽喉处）。
			格子.call("清空品质覆盖层")
			continue
		格子.物品id = String(物品.get("id", ""))
		格子.disabled = false
		var 图标路径 := String(物品.get("icon", ""))
		if ResourceLoader.exists(图标路径):
			格子.icon = load(图标路径) as Texture2D
		# 灵器/忍具两族恒粉框 + 流光：`ItemWindowCell` 两条专属分支
		# （`addLingQiitemAnima` :169-188 / `addRenJuItemFrame` :191-204），两个开关都开。
		格子.call("设置品质", 物品, true, true)
		var 件数 := int(物品.get("quantity", 1))
		数量.text = str(件数) if 件数 > 1 else ""
		# `ItemWindowCell.singleClickHandler`（:137）→ `ItemWindow2.onItemClick`（:428）弹菜单。
		# ⚠️ **先断再连**：`_切页` 只重画不重建格子，直接 connect 会撞上
		#    "Signal 'pressed' is already connected to given callable"（每翻一次页刷一屏 ERROR）。
		for 连 in 格子.pressed.get_connections():
			格子.pressed.disconnect(连["callable"])
		格子.pressed.connect(_选中格子.bind(窗口, 页面, 格子, 物品))
		# 背包格带右侧「身上穿戴件」对比列：原版 `ItemWindowCell.as:314`
		# 就是四参调用 `createToolTip(stage, this, value, getEquipedItemById(value.id))`。
		_接提示框(窗口, 页面, 格子, 物品, true)


## 左键单击格子：弹物品菜单（原版行为），顺带把选中态也更新了。
## 菜单位置 = `格子.x + 20 + 容器.x(11)`（`ItemWindow2.as:487`），
## 格子的 position 是**容器局部**，容器在窗口局部 (11,65)，所以换算成页面局部要各加一次。
static func _选中格子(窗口, 页面: Control, 格子: Button, 物品: Dictionary) -> void:
	# ⚠️ 这里**不能**走 `窗口._select_inventory_item()` —— 它会 `_render_page()` 把整个页面
	# 重建掉，我手里这个 `页面` 立刻变成野指针，下面拿菜单就会拿到 null。
	# 原版的单击也只是弹菜单、不重建窗口，所以直接写选中字段。
	窗口._selected_inventory_id = String(物品.get("id", ""))
	# 「绑定」这类按格位操作要的是**这一格**（`格子.槽位号` 由 `_接拖拽` 按 1 基绝对格位设好），
	# 不能从 id 反查（同 id 两摞会绑错格）。
	窗口._selected_inventory_格 = int(格子.槽位号)
	if 摊位窗.上架模式:
		# 摆摊「物品上架」模式下点背包格 = 上架这一件。原文这是**第一支**
		# （`onItemClick:440-444`：`if (UIConfig.isDropItem && Boolean(那一格的数据))
		# { UIConfig.dropValidateFun(那一格); return; }`）—— 排在出售／仓库／交易之前，
		# 调完直接 return，连物品菜单都不弹。`dropValidateFun` = `showUpShelfWindow(物品, 0)`
		# （`StallWindow.as:624` 设的），三道闸（没带 item／满 10／不可交易）都在闸那侧 ⇒
		# 都在 `摊位窗.背包落一件` 里，**宿主必须是摊位窗那一页**（它数的是那一摊的行）。
		var 管: Node = 窗口.get_parent()
		var 摊: Node = 管.call("取窗口", "随身摊位") as Node \
				if 管 != null and 管.has_method("取窗口") else null
		if 摊 == null:
			# 模式位是脚本级的、窗是窗口管理管的 ⇒ 万一两边不同步（窗已经没了），
			# 要说清"再开一扇"，**不许静默**，更不许拿背包自己当宿主（读不到 `_摊位桶` 就是崩）。
			窗口._show_hint("随身摊位窗已经不在了，重开一扇再上架")
			return
		摊位窗.背包落一件(摊, 物品, int(格子.槽位号))
		return
	if 窗口.批量存取模式:
		# 仓库那边开了「批量存取」时，单击背包格 = 存入仓库（原版 `isSaveOrTakeItem`）。
		窗口._deposit_item(int(格子.槽位号), -1)
		return
	if 交易窗.上架模式:
		# 交易窗开了「物品上架」时，单击背包格 = 丢进交易（原版 `ItemWindow2.as:458-465`
		# 派发 `TradeWindowEvent.ITEM_DRAG`，`dst = 0` 让服务端自动落格）。
		# ⚠ 本机服务端 `handle_player_interaction:23873` 只认 `1 <= 交易槽 <= 5`，
		#   拿 `dst=0` 发过去会被**静默丢掉** ⇒ 这里由客户端算出第一个空格再发，
		#   语义等价于原版的"自动落格"，差别登记在 `真值/窗口/交易与邀请托盘.md` §⑩。
		var 后 = 窗口._backend
		if 后 == null:
			窗口._show_hint("交易需要连接服务端")
			return
		var 空槽 := int(后.call("交易空格"))
		if 空槽 == 0:
			窗口._show_hint("交易的五个格已经放满了")
			return
		# 绑定物品那一闸在**交易窗那侧**（原版 `TradeWindow2.as:403-409` 也只在拖放路径判），
		# 这条点击路径原版不做客户端校验 —— 服务端 `:23875-23877` 会回「绑定物品不能交易」。
		后.call("request_trade_put_item", int(格子.槽位号), 空槽)
		return
	if 窗口.商店出售模式:
		# NPC 商店开了「出售」时，单击背包格 = 拿去卖。		# 原版这条是 `UIConfig.saleValidateFun`（= `ShopWindow2.showBuyAndSaleWindow`，
		# `:648`）—— 选出售后点背包物品，由商店弹买卖数量窗，**不弹物品菜单**。
		# 槽位由这里带上（原版 `_loc4_.slot = param1.position`）—— 同 id 两摞时
		# 按 id 反查会卖错那一格。
		窗口._开买卖窗(物品, false, int(格子.槽位号))
		return
	# 双击 = 使用（`ItemWindow2.onItemDoubleClick`，:857）。原版那条链在"仓库/商店/宠物/
	# 抽奖/魂戒"各有分支，我们这个上下文只走通用分支。Flash 的单击是**立刻弹菜单**的
	# （真机对照过），双击时菜单已经弹开，所以这里再把菜单收掉。
	# 按住 Ctrl 单击 = 把物品发到聊天框（`ItemWindow2.as:483` 的
	# `KeyManager.isDown(KeyCode.KEY_CONTROL)` 分支，走 `chatPane.insertShowItem`）。
	# 客户端的聊天面板还没有"插入物品"这套，先给明确反馈。
	if Input.is_key_pressed(KEY_CTRL):
		# 同菜单那条：按 group 找（父链写法在多窗后永远拿到 null，见「发到聊天框」分支的注）。
		var 聊天: Node = 窗口.get_tree().get_first_node_in_group("chat_panel")
		if 聊天 != null and 聊天.has_method("insert_show_item"):
			聊天.insert_show_item(String(物品.get("id", "")), String(物品.get("name", "")))
		return
	var 本刻 := Time.get_ticks_msec()
	var 同一件 := String(物品.get("id", "")) == _上次点击物品 and 本刻 - _上次点击时刻 <= 双击间隔毫秒
	_上次点击物品 = String(物品.get("id", ""))
	_上次点击时刻 = 本刻
	if 同一件:
		_上次点击时刻 = 0
		var 收起菜单 := 页面.get_node_or_null("物品菜单") as Control
		if 收起菜单 != null:
			收起菜单.call("收起")
		# 宠物装备在原版这里就分叉去 `petPutOnEquip`（`onItemDoubleClick:879-882`），**不进 useItem**。
		if 装备部位表.是宠物槽(装备部位表.位置(String(物品.get("id", "")))):
			_宠物佩戴(窗口, int(格子.槽位号), 物品)
		else:
			窗口._use_item(int(格子.槽位号))
		return
	var 菜单 := 页面.get_node_or_null("物品菜单") as Control
	if 菜单 == null:
		return
	var 项: Array = 菜单.call("取菜单项", 物品, false)
	# 格区滚动过之后 `格子.position.y` 不再等于它在页面里的位置 ⇒ 减掉 scroll_vertical。
	# 91 = 滚动区原点 71（原版容器 y=65）+ 20（`格子.y + 20`）。
	var 滚动 := 页面.get_node_or_null("格子滚动") as ScrollContainer
	var 滚 := float(滚动.scroll_vertical) if 滚动 != null else 0.0
	菜单.call("弹出", 项,
		Vector2(格子.position.x + 31.0, 格子.position.y + 91.0 - 滚),
		窗口._舞台尺寸())


## 拖拽（原版靠 `DragManager`，见 脚本/界面/组件/物品格.gd 的注释）。
## **所有格子都开拖拽**（空格子也要能当落点），归属填 "背包"、槽位号用 1 基绝对格位。
## 落下时按来源/目标分三种：背包内移动 / 存入仓库 / 从仓库取出。
static func _接拖拽(窗口, 格子: Button, 槽位号: int) -> void:
	格子.格子归属 = "背包"
	格子.槽位号 = 槽位号
	格子.可拖拽 = true
	for 连接 in 格子.拖放.get_connections():
		格子.拖放.disconnect(连接["callable"])
	格子.拖放.connect(_处理拖放.bind(窗口))


static func _处理拖放(来源格: Button, 目标格: Button, 物品id: String, 窗口) -> void:
	var 源归属: String = 来源格.格子归属
	var 目标归属: String = 目标格.格子归属
	if 源归属 == 目标归属:
		if 源归属 != "背包":
			return
		# 背包内移动：原版 `requestMoveItem(category=0, src, dst)` →
		# `ITEM_MOVE` 的 `type:src:dst:qty`（服务端 handle_item_move 只看 src/dst/qty）。
		# 2026-10-01：改走 `会话.move_inventory_items` —— 在线行为不变（只发包、
		# 回包驱动），离线补本地对调（原来离线拖了没反应，同"卸下没有实装"一族）。
		窗口._session.move_inventory_items(来源格.槽位号, 目标格.槽位号)
		return
	# 跨容器：走已有的仓库存取（`STORAGE` action 3 存 / 2 取），按**来源格那一格**搬。
	# ⚠️ 不能用拖拽载荷里的物品 id 反查 —— 同 id 两摞时会搬错第一摞（#16）。

	if 源归属 == "背包" and 目标归属 == "仓库":
		窗口._deposit_item(int(来源格.槽位号), -1)
	elif 源归属 == "仓库" and 目标归属 == "背包":
		窗口._withdraw_item(int(来源格.槽位号), -1)


## 悬停出原版物品提示框（`MToolTipItem` 挂在格子的 MOUSE_OVER 上，立刻弹）。
## 提示框是场景里的固定节点、挂在页面根下最上层，这里只负责填内容与摆位。
static func _接提示框(窗口, 页面: Control, 格子: Button, 物品: Dictionary,
		比穿戴件 := false) -> void:
	# 2026-10-01：与仓库/人物装备格的同一段 30 行接线合并到 `组件/格子提示框.gd`
	# （三处复制必漂；合并前这两份是逐字相同的）。本函数只剩转发，调用点没动。
	格子提示框.接线(窗口, 页面, 格子, 物品, 比穿戴件)


## 三行货币。原版三行是 游戏金币 / 商城元宝 / 商城点券。
## 三个字段都有源：`gold` / `cash` 走属性帧，点券 = `cash_bind` ——
## 上行 `2597` 那条把服务端的中转键 `cashBind` 映射过来（`后端连接.gd:2796`、
## `服务端会话同步.gd:33`），离线吃礼包也写同一个键（`游戏会话.gd:899`）。
## ⚠️ 别照旧注释写"点券没接"（那是 §3.10.6 时的状态，早就翻案了）：
## 在线扣款那条有门 `商城真实事务回归测试` 钉的是**会话的 `player_stats.cash_bind`**，
## 不是 `authoritative_stats` 那个中转字典（拿后者判会恒 0）。
static func _渲染货币(窗口, 页面: Control, 会话) -> void:
	var 值表 := [
		["游戏金币", int(会话.player_stats.get("gold", 0))],
		["商城元宝", int(会话.player_stats.get("cash", 0))],
		["商城点券", int(会话.player_stats.get("cash_bind", 0))],
	]
	for 序号 in 值表.size():
		var 名: String = 值表[序号][0]
		var 标题 := 页面.get_node("%s标题" % 名) as Label
		# 原版三行标题各 53x18（`ItemWindow2.as:1395-1400` 的 47,316 / 47,341 / 47,364），
		# 比数值小一号；字色与数值同色系。
		窗口._configure_label(标题, 12, 色_货币)
		var 值 := 页面.get_node("%s值" % 名) as Label
		# 原版这三个值是 `BaseUtil.formatNumber(param)` 出来的 —— 大于 999 才带千分位。
		值.text = 数字格式.千分位(int(值表[序号][1]))
		# 2026-10-25 用户报「金币/元宝/点券数模糊、偏小」⇒ 只放大**值**，行标题仍 12。
		# 落点写在场景里：值框左沿 98（离图标右沿 5~8px，字墨再多 1px）、上下贴齐 21px 货币底框并垂直居中；
		# 横向**左对齐**（用户最终要求：靠图标一侧、留一点点距离但不要太远，随后再近 2px）。
		窗口._configure_label(值, 货币字号, 色_货币)


## 底部那一排钮。**原版每颗都有 handler**（`ItemWindow2.as:1770-1774` 那一族一起挂的），
## "只有整理背包有实现"是旧注释里的假前提，别再抄：
##   整理背包 ⇒ 66；随身仓库 `:293 openCangKuHandler` ⇒ VIP 闸 + `1818`；
##   随身药店 `:302/:1225-1243 openYaoDianHandler` ⇒ 商店窗已开则切显隐，否则
##   `VIPManager.vipLevel >= CANG_KU_LEVEL` 才 `requestVip_openMedicine()`，不够格弹「购买VIP确认」
##   （⚠ 这一族 2026-10-25 按用户报修 5.1/5.2 **整条删掉**：不要求等级、没有确认弹、没有元宝那条 ⇒ **别照 AS3 补回**）；
##   神秘商店 `:311/:1763 openMysteryHandler` ⇒ `MysteryManager.requestOpenMystery()`
##   → `client.requestSecretShopOpen()`（= NPC_SHOP 动作 6，回帧 324）；
##   二级密码 `:722 mouseClickTwoPassword` ⇒ `requestSecondLevelPassword_queryFirstTime()`（2309）；
##   摊位列表 `:1547 viewStallListHandler` ⇒ `showStallListWindow()`（`1296:0/1`）；
##   随身摊位 `:1515 viewStallHandler` ⇒ 自己那扇已开就关，否则 `requestStallOpen(stats.id)`
##   （**看的是自己的摊** ⇒ 回帧那支按 `stats.id` 判定摊主档，`StallDataManager.as:29-37`）。
## ⚠️ 原版那颗「充值」（`:418 onClickCZ` → `Config.ChargeUrl` 开网页）本工程**按用户明确要求删了**
## （§3.203），不是漏接，别照 AS3 补回来。
##
## `缺的那一块` 写的是每一条**当前真缺的东西**（不是"本轮未做"那种开发周期话，那种话会烂在包里），
## 点下去仍旧要给一句话 —— 本仓口径：点了没反应＝会被当成坏了。
## ⚠️ 空表**不等于这套机制没了**：底下那颗占位循环照这张表走，将来再接一条就填一行。
const 缺的那一块 := {
}

static func _渲染按钮(窗口, 页面: Control, 会话) -> void:
	var 整理 := 页面.get_node("整理背包") as Button
	窗口._configure_standard_button(整理)
	整理.pressed.connect(func():
		var 后端 = 窗口._backend
		if 后端 == null or not 后端.has_method("request_item_sort"):
			窗口._show_hint("整理背包：未连接服务端")
		elif not 后端.request_item_sort(0):   # `AllInOneProcessor.requestItemSort`：byte type，0=背包、1=仓库
			窗口._show_hint("整理背包请求发送失败")
		# 发成功不提示：原版只发一跳，格子等 66 回帧重排。
	)
	for 名 in 缺的那一块:
		var 按钮 := 页面.get_node_or_null(名) as Button
		if 按钮 == null:
			continue
		窗口._configure_standard_button(按钮)
		按钮.pressed.connect(窗口._show_hint.bind("%s：还没接 —— %s" % [名, String(缺的那一块[名])]))
	## 「随身摊位」（#49 接上）= **开关自己那扇 + 一跳**，而**开窗的仍旧是回帧**。
	## `ItemWindow2.as:1515-1525 viewStallHandler` 全文只有两支：
	## `if (API.ui.content.myStallWindow) setDOShow(MY_STALL_WINDOW,false)`
	## ／ `else API.ui.viewStall(API.dataCenter.stats.id)`，而 `viewStall` 就是
	## `Client.requestStallOpen(号)`（`UI.as:216-219`）⇒ 上行 `1296:2:<摊主号>`。
	## ⚠️ 点下去**不该直接开窗**：摊没摆时服务端只回一句动态提示、一帧 `1296` 都不发
	##   ⇒ "没窗"是原语义（真开窗那条腿在 `窗口管理._on_stall_state`）。
	## ⚠️ 号取的是**我自己**（`stats.id`）不是选中目标 ⇒ 这颗只管自己那一摊；看别人的摊走
	##   目标信息条／聊天／好友／排行／摊位列表那七个入口（`viewStall` 的其余调用点）。
	var 摊主 := 页面.get_node("随身摊位") as Button
	窗口._configure_standard_button(摊主)
	摊主.pressed.connect(func():
		var 管理: Node = 窗口.get_parent()
		if 管理 == null or not 管理.has_method("取窗口"):
			窗口._show_hint("随身摊位：这里没有窗口管理")
			return
		var 摊: Node = 管理.call("取窗口", "随身摊位") as Node
		if 摊 != null and bool(摊.call("已打开")):
			# 原版那一支 `setDOShow(...,false)`：**一个包都不发**，只收窗。
			摊.call("close")
			return
		var 后端 = 窗口._backend
		if 后端 == null or not 后端.has_method("request_stall_open"):
			窗口._show_hint("随身摊位：未连接服务端")
		elif not 后端.request_stall_open(int(后端.get("character_id"))):
			窗口._show_hint("随身摊位请求发送失败"))
	## 「二级密码」（§3.225 接上）= **点下去只发一跳**：`ItemWindow2.as:722-729
	## mouseClickTwoPassword` 全文是 `if (!UIConfig.isEnableDrag) return; queryFirstTime();`
	## ⇒ **一扇窗都不开**，开窗的是回帧 2（`Client.as:1569-1577` 的
	## `reverseDisplay(TWOPASSWORD_SAY_WINDOW)`）—— 和 神秘商店/随身药店 同一族。
	## ⚠ 那句 `isEnableDrag`（全局"正在打造/合成读条"的闸，`UIConfig.as:914`）本工程没有这份
	##   状态 ⇒ 没接，后果只是"打造中也发得出这一跳"，登记在真值 §⑤ 第 1 条。
	var 密 := 页面.get_node("二级密码") as Button
	窗口._configure_standard_button(密)
	密.pressed.connect(func():
		var 后端 = 窗口._backend
		if 后端 == null or not 后端.has_method("request_second_password"):
			窗口._show_hint("二级密码：未连接服务端")
		elif not 后端.request_second_password(0, []):	# 上 0 = `queryFirstTime:195-200`，无值
			窗口._show_hint("二级密码请求发送失败"))
	## 「摊位列表」（§3.224 接上）= **点下去一跳都不发**：原版 `:1547-1557` 全文只有
	## `if (stallListWindow) setDOShow(...,false) else showStallListWindow()` 这一对开关，
	## 而 `showStallListWindow():4568-4576` = `setDOShow` + `stallListWindow.init()`，
	## 那句 `init()` 里才是 `loadPage(0)` ⇒ **发 `1296:0:0:11` 的是开窗那一刻、不是这一下点击**。
	## 所以这里只叫 `打开或收起`，发包在 `功能窗口.open_page("摊位列表")`。
	## ⚠️ 别改成"这里直接 request_stall_list"：那条路会绕过开窗、把回帧打进一扇没开的窗
	##   （`窗口管理._on_stall_list` 判的是 `已打开()` ⇒ 帧被丢掉），点了就永远转圈。
	var 摊列 := 页面.get_node("摊位列表") as Button
	窗口._configure_standard_button(摊列)
	摊列.pressed.connect(func():
		var 管理: Node = 窗口.get_parent()
		if 管理 == null or not 管理.has_method("打开或收起"):
			窗口._show_hint("摊位列表：开窗要窗口管理，这里没有")
			return
		管理.call("打开或收起", "摊位列表"))
	## 「随身药店 / 随身仓库」= 三支判式，见 `_随身入口`。
	## ⚠️ 仓库那颗**旧写法是 `会话.request_feature("NPC仓库")`** —— 本地直接把页开出来、一个包都不发：
	##   在线点它，画的是**上次那帧的仓库**（甚至空架子），而原版这一跳连窗都不开，
	##   开窗的是服务端 `330:1`（`Client.as:4263-4273`）。药店那颗以前干脆躺在占位表里。
	var 药店 := 页面.get_node("随身药店") as Button
	窗口._configure_standard_button(药店)
	药店.pressed.connect(func(): _随身入口(窗口, "NPC商店", "随身药店",
			"request_vip_open_medicine"))
	var 仓库 := 页面.get_node("随身仓库") as Button
	窗口._configure_standard_button(仓库)
	仓库.pressed.connect(func(): _随身入口(窗口, "NPC仓库", "随身仓库",
			"request_vip_open_store"))
	## 「神秘商店」= **只发一跳**（`ItemWindow2.as:1763-1766` 全文一句 `requestOpenMystery()`，
	## 没有等级闸、没有 showWindow）⇒ 点下去**不该开窗**，开窗的是回帧那帧 `324:`
	## （`窗口管理._on_mystery_shop`）。发成功不提示 —— 等级 < 25 时服务端只回一句系统聊天，
	## 那时"没窗"是原语义，提前弹一句"打开失败"反倒像坏了。
	var 神秘 := 页面.get_node("神秘商店") as Button
	窗口._configure_standard_button(神秘)
	神秘.pressed.connect(func():
		var 后端 = 窗口._backend
		if 后端 == null or not 后端.has_method("request_secret_shop_open"):
			窗口._show_hint("神秘商店：未连接服务端")
		elif not 后端.request_secret_shop_open():
			窗口._show_hint("神秘商店请求发送失败"))


## 底部「随身药店 / 随身仓库」的**三支**判式，按顺序、命中即返回
## （`ItemWindow2.as:1225-1243 openYaoDianHandler` / `:1289-1307 openCangKuHandler`，
## 两支只差**窗名**与**动作号**）：
##   ① 那一扇**已经建过** ⇒ `reverseDisplay` = 切显隐，**一个包都不发**
##     （判的是实例在不在，不是连没连；`UIMain2.as:5139-5160` 在台上就 removeWindow、不在就 createWindow）；
##   ② 没连后端 / 缺那条方法 ⇒ 一句「未连接服务端」（移植侧的边界话，原版没有这一支）；
##   ③ 发**免费**那条（1818 动作 1／2）。
##     原版这一支前面还挂着 `VIPManager.vipLevel >= CANG_KU_LEVEL(1)`，不够格就弹「购买VIP确认」
##     走**元宝**那条（动作 5／6），另有一支 `API.waiGuaHandler.isConnected` ⇒ 动作 3／4 的
##     `requestVip_open*ForWaSai`（本工程没有 `WaiGuaHandler` 那半边，自动购买/自动挂机，**整支不移植**）。
##     **2026-10-25 用户点名删掉等级那一族**（报修 5.1「不要求任何 vip 等级」+ 5.2「删除 vip、vip 充值的内容按键逻辑」，
##     与 §3.203 商城充值键同一族有意偏离）⇒ 等级闸、确认弹、`*_by_cash` 两条上行全部没了，
##     **别照 AS3 补回来**；服务端那半边（夹具 `handle_vip` 的 `_has_active_vip()`）同步放开。
## ⚠️ **开窗的不是这一跳，是回帧**：药店 ⇒ `OPEN_NPC_SHOP`（服务端 `_send_npc_shop(14)`；
##   `Client.as:771-774` → `UI.as:2018-2057` → `UIMain2.as:4894-4901`）；
##   仓库 ⇒ `330:1` 分块**拼完**（`Client.as:4263-4273`）⇒ 消费者在 `窗口管理._on_npc_shop` / `_on_storage_opened`。
##   所以①只能判"实例建过没有"：本地抢先把空页开出来＝把上次的旧数据糊玩家一脸（这就是修前的病）。
static func _随身入口(窗口, 页名: String, 按钮文字: String, 免费: String) -> void:
	var 管理: Node = 窗口.get_parent()
	if 管理 != null and 管理.has_method("取窗口") and 管理.call("取窗口", 页名) != null:
		管理.call("打开或收起", 页名)
		return
	var 后 = 窗口._backend
	if 后 == null or not 后.has_method(免费):
		窗口._show_hint("%s：未连接服务端" % 按钮文字)
		return
	if not 后.call(免费):
		窗口._show_hint("%s请求发送失败" % 按钮文字)
