extends RefCounted

const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
## 族中职务名/色（全工程只此一份）。⚠️ 别再内联那张表 —— 这里原来内联的一份是**反的**
## （5 当族长、1 当成员），把族长显示成了"成员"（用户 2026-10-09 报的）。
const 家族职务 := preload("res://脚本/界面/窗口/家族/家族职务.gd")
const 任务页面场景 := preload("res://场景/界面/窗口/任务/任务窗口.tscn")
const 好友页面场景 := preload("res://场景/界面/窗口/好友/好友窗口.tscn")
# （家族页那个 `家族页面场景` 预载随 `_render_guild` 一起删了 —— 见本文件里那段说明。）
const 商城页面场景 := preload("res://场景/界面/窗口/商城/商城窗口.tscn")
const 任务条目场景 := preload("res://场景/界面/组件/任务条目.tscn")
const 商城商品行场景 := preload("res://场景/界面/组件/商城商品行.tscn")
const 荣誉商品行场景 := preload("res://场景/界面/组件/荣誉商品行.tscn")
const 数字格式 := preload("res://脚本/界面/数字格式.gd")
const ORIGINAL_SLOT := "res://素材/界面/原版窗口/通用控件/物品格.png"
const ORIGINAL_GOLD := "res://素材/界面/原版窗口/通用控件/金币.png"
const ORIGINAL_CASH := "res://素材/界面/原版窗口/通用控件/火影币.png"

var 窗口

var _session:
	get: return 窗口._session
var _quest_tab:
	get: return 窗口._quest_tab
	set(value): 窗口._quest_tab = value
var _selected_quest_id:
	get: return 窗口._selected_quest_id
	set(value): 窗口._selected_quest_id = value
var _team_tab:
	get: return 窗口._team_tab
	set(value): 窗口._team_tab = value
var _friend_tab:
	get: return 窗口._friend_tab
	set(value): 窗口._friend_tab = value
var _shop_tab:
	get: return 窗口._shop_tab
	set(value): 窗口._shop_tab = value
var _shop_query:
	get: return 窗口._shop_query
	set(value): 窗口._shop_query = value
var _商城搜索草稿:
	get: return 窗口._商城搜索草稿
	set(value): 窗口._商城搜索草稿 = value
var _shop_page:
	get: return 窗口._shop_page
	set(value): 窗口._shop_page = value
var _shop_scroll:
	get: return 窗口._shop_scroll
	set(value): 窗口._shop_scroll = value
var _backend:
	get: return 窗口._backend

func _init(宿主) -> void:
	窗口 = 宿主

func _instantiate_page(scene: PackedScene) -> Control:
	return 窗口._instantiate_page(scene)

func _configure_overlay_button(button: Button, button_size: Vector2) -> void:
	窗口._configure_overlay_button(button, button_size)

func _configure_standard_button(button: Button) -> void:
	窗口._configure_standard_button(button)

func _configure_value_input(input: LineEdit) -> void:
	窗口._configure_value_input(input)

func _configure_label(label: Label, font_size: int, color: Color) -> void:
	窗口._configure_label(label, font_size, color)

func _bind_original_check(item: Control, label_text: String, key: String, default_value: bool, inverted: bool, settings: Dictionary) -> void:
	窗口._bind_original_check(item, label_text, key, default_value, inverted, settings)

func _sub_panel_style() -> StyleBoxTexture:
	return 窗口._sub_panel_style()

func _original_content_panel() -> StyleBoxTexture:
	return 窗口._original_content_panel()

func _texture_style(path: String, tint := Color.WHITE) -> StyleBoxTexture:
	return 窗口._texture_style(path, tint)

func _add_positioned_label(parent: Control, text: String, position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	return 窗口._add_positioned_label(parent, text, position, label_size, font_size, color)

func _make_button(text: String, tooltip: String) -> Button:
	return 窗口._make_button(text, tooltip)

func _quest_by_id(quest_id: String, quests: Array) -> Dictionary:
	return 窗口._quest_by_id(quest_id, quests)

func _render_page() -> void:
	窗口._render_page()

func _set_quest_tab(index: int) -> void:
	窗口._set_quest_tab(index)

func _select_quest(quest_id: String) -> void:
	窗口._select_quest(quest_id)

func _accept_quest(quest_id: String) -> void:
	窗口._accept_quest(quest_id)

func _claim_quest(quest_id: String) -> void:
	窗口._claim_quest(quest_id)

func _set_team_tab(index: int) -> void:
	窗口._set_team_tab(index)

func _create_team() -> void:
	窗口._create_team()

func _invite_team(player_name: String) -> void:
	窗口._invite_team(player_name)

func _leave_team() -> void:
	窗口._leave_team()

func _set_friend_tab(index: int) -> void:
	窗口._set_friend_tab(index)

func _add_friend(player_name: String) -> void:
	窗口._add_friend(player_name)

func _remove_friend(player_name: String) -> void:
	窗口._remove_friend(player_name)

func _unblock_friend(player_name: String) -> void:
	窗口._unblock_friend(player_name)

func _start_whisper(player_name: String) -> void:
	窗口._start_whisper(player_name)

func _create_guild(guild_name: String) -> void:
	窗口._create_guild(guild_name)

func _leave_guild() -> void:
	窗口._leave_guild()

func _show_guild_action(action_name: String) -> void:
	窗口._show_guild_action(action_name)

func _set_shop_tab(index: int) -> void:
	窗口._set_shop_tab(index)

func _search_shop(query: String) -> void:
	窗口._search_shop(query)

func _buy_item(item_id: String, quantity := 1) -> void:
	窗口._buy_item(item_id, quantity)

## 任务面板（原版 `MQuestionWindow`）。
##
## 2026-09-27 合并另一位开发者的「任务页」后，这一页**不再由这里搭**：
## `场景/界面/窗口/任务/任务窗口.tscn` 的根上挂着它自己的控制器
## `素材/界面/任务界面/脚本/任务窗口.gd`（分组树、页签、右栏两段富文本、追踪复选项、
## 放弃/接任务按钮全在里面，几何逐条抄 AS3），它在 `_ready()` 里自己取 `GameSession`、
## 连 `quests_changed`/`quest_changed`、并刷新。这里只负责把场景挂进页面容器。
##
## ⚠️ 旧版是这里用代码摆的（`任务树`/`任务详情` 那两个 Panel），
##    那些节点在新场景里已经不存在了 —— 别再按旧节点名取，会 `Node not found`。
func _render_quests() -> void:
	var page := _instantiate_page(任务页面场景)
	# 数据已经变了但页面是刚建的，`_ready()` 已经刷过一次；这里只是把
	# 「页面重建」和「数据到达」两条路都收敛到同一个入口。
	if page.has_method("刷新"):
		page.call("刷新")


func _render_friends() -> void:
	# 另一位开发者的好友页（原版 `FriendWindow2` 295×370 五页签 + 三扇子窗 + 行菜单）。
	# 分工照旧：**UI 以他为主、逻辑归我们** —— 页面自装配，动作一律交回
	# `_show_guild_action("好友页|…")`；我们这边只需要提供 `_session` 与两个宿主方法
	# （`_show_guild_action` 已有、`_弹出输入确认` 见 `功能窗口`）。
	var page := _instantiate_page(好友页面场景)
	# ⚠️ 宿主传的是**功能窗口那个 Node**（`窗口`），不是本控制器的 `self` ——
	#    本文件 `extends RefCounted`，而页面的 `装配(宿主: Node)` 要的是 Node，
	#    传 self 会直接 "not a subclass of the expected argument class"。
	#    页面要的三样（`_session` / `_show_guild_action` / `_弹出输入确认`）功能窗口都有。
	page.call("装配", 窗口)
	_挂好友申请行(page)


## ⚠️ **本工程特有的扩展，原版 `FriendWindow2` 没有**：服务端有"好友申请"这条流
## （`127` 的 request/accept/reject，在线用例跑过），旧页面把它画在好友页里。
## 新页面按原版只画五页签 ⇒ 这里由宿主**另挂一条申请行**补在「体好友」里、
## 与他自己的行容器并列（不进他的容器：他的 `刷新()` 一换页签就会清空那个容器）。
## 位置取他列表下沿之下（`列表` 底 = 259）；他重生成场景也吃得住（体好友还在）。
func _挂好友申请行(page: Control) -> void:
	var 体 := page.get_node_or_null("体好友") as Control
	if 体 == null:
		return
	var 旧 := 体.get_node_or_null("好友申请行")
	if 旧 != null:
		体.remove_child(旧)
		旧.queue_free()
	var 申请: Array = _session.pending_social_requests.filter(
		func(request): return String(request.get("type", "")) == "friend")
	if 申请.is_empty():
		return
	var 列 := Control.new()
	列.name = "好友申请行"
	列.position = Vector2(0.0, 262.0)
	列.size = Vector2(265.0, 36.0)
	体.add_child(列)
	for i in mini(申请.size(), 2):		# 只摆两行，多的走系统消息，别把他的版面挤乱
		var 请求: Dictionary = 申请[i]
		var 名 := String(请求.get("name", "忍者"))
		var 字 := _add_positioned_label(列, "%s 请求加为好友" % 名,
			Vector2(4.0, i * 18.0), Vector2(150.0, 18.0), 11, Color("#f3ce71"))
		字.name = "申请%d" % i
		var 收 := _make_button("接受", "接受好友申请")
		收.name = "接受%d" % i
		收.position = Vector2(158.0, i * 18.0)
		收.size = Vector2(46.0, 17.0)
		收.pressed.connect(func(): _session.accept_friend_request(int(请求.get("character_id", 0))))
		列.add_child(收)
		var 拒 := _make_button("拒绝", "拒绝好友申请")
		拒.name = "拒绝%d" % i
		拒.position = Vector2(208.0, i * 18.0)
		拒.size = Vector2(46.0, 17.0)
		拒.pressed.connect(func(): _session.reject_friend_request(int(请求.get("character_id", 0))))
		列.add_child(拒)

# ⚠️ 这里原来有一整段 `_render_guild()`（家族页整窗渲染，约 80 行）—— **零调用点**，
#    而且里面读的节点名（`家徽区`/`公告`/`创建家族`/`成员区`/`表头`/`成员行`…）跟真实的
#    `场景/界面/窗口/家族/家族窗口.tscn`（`家徽名标题`/`盒标题`/`修改钮`/…）**全对不上**。
#    家族页由 `功能窗口._render_guild()`（功能窗口.gd:1170）→ `家族窗口.gd` 渲染，
#    本文件跟家族有关的只剩 `_create_guild` / `_leave_guild` / `_show_guild_action` 三个出口。
#    2026-10-13 删：死代码 + 假节点名，谁顺手接上谁踩（§3.116「死代码是陷阱」那一族）。

## 原版「商城」窗（`CashShopWindow2.as`）。版式见 场景/界面/窗口/商城/商城窗口.tscn 的头注释。
##
## 四处跟 2026-09-26 之前不一样：
##   1. **页签是真值**（8 个商品分类 + 1 个「荣誉类」面板页签），来自
##      `数据/界面/商城分页.json`；**下标就是发给服务端的 categoryId**。
##      以前写死「全部/药品/宠物/装备/荣誉」五个、分类 id 走 `[-1,1,2,3,4]` 查表、
##      而且发出去之后还在前端按 `category` 字符串二次过滤。
##   2. **商品行是 `CashItemCell` 的真字段**：原价、元宝/券图标、热卖/打折角标、
##      两色说明框。以前只有名字/售价/单色说明，而且「售价」少了那个冒号。
##   3. **底部货币栏**：元宝 + 点券两条带底框的数值、荣誉积分。
##      以前是「金币 50000 / 火影币 100」两行裸文字。
##      ⚠️ 原版这里还有一枚 `payBtn`（充值，`CashMoneyPane.as:73-77` 跳 `Config.ChargeUrl`）
##      —— **本工程按用户要求删掉了**（2026-10-18，有意偏离原版：本项目没有充值渠道）；
##      2026-11-01 用户又把旁边那条「1RMB = 10元宝」文案（`cashMoneyTipText`）也删了，
##      空位让给从荣誉积分框上挪过来的翻页条（有意偏离原版，见 §3.359）。
##   4. **有翻页条**（`PageComponent`，每页 20 条）。以前一次性把目录全渲染出来。
func _render_shop() -> void:
	var page := _instantiate_page(商城页面场景)
	var 分页表: Dictionary = 窗口._取商城分页表()
	var 页签们: Array = 分页表.get("页签", ["常用类"]) as Array
	var 荣誉页签名 := String(分页表.get("荣誉页签名", "荣誉类"))
	if _shop_tab < 0 or _shop_tab >= 页签们.size():
		_shop_tab = 0

	# `CashShopWindow2.as:192-209` —— `MTabButtonF`：x 从 16 起、宽 `btn_width_three`=49、步进 +50
	# （那 16/44 已烘进 `分页` 的 (16,44)）。⚠️ 页签**烘在场景里**（`分页/页签0..8`，§3.138 重做），
	# 这里只按数据填文字/选中态并接线 —— 以前是 `Button.new()` 现造、**没有名字**，
	# 门与别处都寻址不到（§3.113 规矩 5）。文字仍由 `数据/界面/商城分页.json` 驱动。
	var 页签容器 := page.get_node("分页") as Control
	var 已烘 := 页签容器.get_children()
	for index in 页签们.size():
		var 页签: Button
		if index < 已烘.size():
			页签 = 已烘[index] as Button
		else:
			# 兜底：数据比烘出来的多时才现造（当前真值固定 9 个，走不到这里）。
			页签 = Button.new()
			页签.name = "页签%d" % index
			页签.toggle_mode = true
			页签.focus_mode = Control.FOCUS_NONE
			页签.theme_type_variation = 皮肤表.变体_分页
			页签.position = Vector2(50.0 * index, 0.0)
			页签.size = Vector2(49.0, 22.0)
			页签容器.add_child(页签)
		页签.text = String(页签们[index])
		# ⚠️ 选中那枚**同时**置 `disabled` —— 这是本工程 `MTabButton` 的既有口径
		# （`MTabButton.as:35-39` `set enabled(v)` ⇒ `selected = !v`，**选中走 disabled 槽**显示
		# `selectedUpSkin`；见 `勾玉炼制窗.切页` / `徽章打造窗.切页`）。
		# 只置 `button_pressed` 时 toggle 的按下皮**不显形**（§3.138 实测：九枚渲染成一个样）。
		页签.disabled = index == _shop_tab
		页签.button_pressed = index == _shop_tab
		页签.pressed.connect(_set_shop_tab.bind(index))

	var 搜索 := page.get_node("搜索词") as LineEdit
	# ⚠️ 框里的字必须存**窗口**上：这页每来一条状态帧就整棵重建一次（`_refresh_current` 挂了
	# 十几个信号），存在旧 LineEdit 上的输入活不过一帧 ⇒ 玩家"打不进字"（2026-10-18 实机报修）。
	# 焦点与光标由 `功能窗口._记输入焦点` / `_放输入接力` 跨重建接回去。
	搜索.text = _商城搜索草稿
	搜索.text_changed.connect(func(新文本: String) -> void: _商城搜索草稿 = 新文本)
	(page.get_node("搜索") as Button).pressed.connect(func(): _search_shop(搜索.text))

	# 荣誉类：`CashShopWindow2.as:129-132` —— 它是**面板页签**，只把 `rongYuPanel` 显出来
	# 并 `setData()`（数据 100% 出自 GameData，**不发 432 商品请求**；不发的那半边在
	# `功能窗口._set_shop_tab`，读的那半边在 `数据/荣誉商店.json`）。
	# 积分与兑换走 **2323 MUYE_BATTLE**（`后端连接 OP_MUYE_BATTLE`，2026-10-20 §3.227 接上）：
	#   积分 = `2323:8:` 唯一来源（`MuYeDaZhanManager.onMuyeBattle_updateFamePoint:617-624`），
	#   点「兑换」发 `2323:3:<itemId>:1`（`RongYuItemCell.buyBtnClick:151-154`）。
	# ⚠️ `商品列表框` **不再按页签隐藏**：原版的 `rongYuPanel` 与 `listBg` 占的是**同一个矩形**
	#   ((11,64) 起、内层 ScrollPane 都是 (3,2) 608x308)，靠显隐轮换 ⇒ 这一页复用同一个容器。
	# ⚠️ 但 `分页条` **这一页藏起来**（一条**有意的偏离**，理由要留着）：原版
	#   `setSelectedTabBtn:124-132` 确实不藏 `_pageComponent`，所以带着一部陈旧翻页条进荣誉页
	#   是原版行为 —— 可原版的翻页条是**收到商品回包才 `new`**（`setData:272`），而且它的
	#   `__setPage` 用的是 `selectedSecondType`（**荣誉页签不改这个字段**）。我们这边翻页条
	#   每帧都渲染、`_shop_tab` 又**就是** categoryId ⇒ 留着点一下会发 `432:8`（原版发不出去的请求）。
	#   ⇒ 藏掉是"少一根不会误发的箭"，不是"改版式"。
	var 是荣誉页 := String(页签们[_shop_tab]) == 荣誉页签名
	(page.get_node("分页条") as Control).visible = not 是荣誉页
	_渲染商城货架(page, not 是荣誉页)
	_渲染商城货币栏(page)
	# 购买窗挂在 `_overlay` 上（§3.145），整页重建**不会**带走它 ⇒ 这里只补余额数字。
	# ⚠️ 别再改成 `窗口.打开商城购买窗(...)`：那等于每次回帧把整扇窗重开一遍 ——
	# 数量冲回 1、购买方式勾回默认，玩家看就是"点不动"（2026-10-18 实机报修）。
	窗口.刷新商城购买窗余额()


func _渲染商城货架(page: Control, 有货架: bool) -> void:
	var 商品列表 := page.get_node("商品列表框/商品滚动/商品列表") as Control
	for 旧 in 商品列表.get_children():
		商品列表.remove_child(旧)
		旧.queue_free()
	_渲染商城翻页条(page)
	if not 有货架:
		_渲染荣誉货架(page, 商品列表)
		return
	var 商品们: Array = _session.shop_catalog
	# `CashShopWindow2.as:355` —— `_loc2_.y = _loc2_.height * loadIndex`，行高 62、x=0
	for index in 商品们.size():
		var 商品: Dictionary = 商品们[index]
		var 行 := 商城商品行场景.instantiate() as Panel
		行.position = Vector2(0.0, 62.0 * index)
		商品列表.add_child(行)
		_布置商品行(行, 商品)
	# ⚠️ 要写 `custom_minimum_size` 而不是 `size` —— `ScrollContainer` 只按子节点的
	# **最小尺寸**决定滚动范围，而纯 `Control` 的 `get_combined_minimum_size()` 只看
	# `custom_minimum_size`、**不把子节点算进去**（只有 Container 才合并子节点）。
	# 写成 `size` 会被 ScrollContainer 立刻改回 0，表现是货架滚不动。
	# 按实测条宽减（见 原版皮肤表.配原版滚动区 的说明），否则容器自己变宽、条落到框外。
	var 滚动 := page.get_node("商品列表框/商品滚动") as ScrollContainer
	if 滚动 != null:
		皮肤表.配原版滚动区(滚动, 商品列表, 608.0, 308.0, 62.0 * 商品们.size())
	# 还原滚动位置。⚠️ 必须 `set_deferred`：滚动范围要等布局跑完才算得出来，
	# 当场写会被夹到 0（症状就是"下滚又弹回上面"）。
	(page.get_node("商品列表框/商品滚动") as ScrollContainer).set_deferred("scroll_vertical", int(_shop_scroll))
	if 商品们.is_empty():
		var 空文案 := "正在读取商城商品" if bool(_session.cash_shop_loading) else "没有符合条件的商品"
		_add_positioned_label(商品列表, 空文案, Vector2(214.0, 140.0), Vector2(180.0, 24.0), 12, Color("#a9957f"))


## 一行 `CashItemCell`。取值与位置规则全部照 `CashItemCell.as:186-232` 的 `data` setter。
func _布置商品行(行: Panel, 商品: Dictionary) -> void:
	var 物品id := String(商品.get("id", ""))
	var 图标路径 := String(商品.get("icon", ""))
	(行.get_node("物品格/图标") as TextureRect).texture = (
		load(图标路径) as Texture2D if ResourceLoader.exists(图标路径) else null
	)

	var 名称 := 行.get_node("名称") as Label
	名称.text = String(商品.get("name", ""))
	var 售价标签 := 行.get_node("售价标签") as Label
	售价标签.text = "售价："
	var 售价 := 行.get_node("售价") as Label
	var 现价 := int(商品.get("price", 0))
	# `:198` —— `formatNumber(nowPrice)`：**> 999 要加千分位**（以前写 `str()`，
	# 一千以上的元宝价少一个逗号；`getPriceTFWidth` 量的就是这个串，宽度跟着一起偏）。
	售价.text = 数字格式.千分位(现价)

	# `:231-233` —— 原价行只在 origPrice != nowPrice 时出现
	var 原价 := int(商品.get("original_price", 现价))
	var 原价行 := 行.get_node("原价") as RichTextLabel
	原价行.visible = 原价 != 现价
	if 原价行.visible:
		# `CASHITEMCELL_NOW_PRICE` = `<font color="#018aff">原价：</font><font color="#ffffff">%1</font>`
		# `:199` 同样喂 `formatNumber`。
		原价行.text = String(窗口.译文为BBCode(
			'<font color="#018aff">原价：</font><font color="#ffffff">%s</font>' % 数字格式.千分位(原价)
		))

	# `:222` —— `salePriceText.width = getPriceTFWidth(text)` = 文字宽 + 3
	售价.size.x = _文字宽(售价) + 3.0
	# `:223-224` —— 元宝图标紧贴售价右边，券图标再右移 13
	var 元宝图标 := 行.get_node("元宝图标") as TextureRect
	var 券图标 := 行.get_node("券图标") as TextureRect
	元宝图标.position.x = round(售价.position.x + 售价.size.x)
	券图标.position.x = 元宝图标.position.x + 13.0
	# `:197` —— 券角标的显示条件是 wire 上第 13 个字段 `isLiJin`
	券图标.visible = bool(商品.get("is_li_jin", false))

	# `:225-229` —— **没有原价行时**（常态）名称与售价整块下移
	if not 原价行.visible:
		名称.position.y = 12.0
		售价标签.position.y = 30.0
		售价.position.y = 30.0
		券图标.position.y = 30.0
		元宝图标.position.y = 32.0

	# `:216-219` —— 说明框：绿 detaildesc + 换行 + 白 desc，再按行数决定是否上移
	var 详情 := GAME_DATA.item_detail(物品id)
	var 描述 := String(商品.get("description", ""))
	var 说明 := 行.get_node("说明") as RichTextLabel
	if 详情.is_empty() and 描述.is_empty():
		说明.text = ""
	else:
		说明.text = String(窗口.译文为BBCode(
			'<textformat leading="2"><font color="#00ff00">%s</font><br/><font color="#ffffff">%s</font></textformat>'
			% [详情, 描述]
		))
	var 行数 := 说明.get_line_count()
	var 所需高 := 说明.get_content_height() + 5.0
	说明.size.y = 所需高
	说明.position.y = 0.0 if 行数 > 3 else floor((62.0 - 所需高) * 0.5)

	# `:203-214` —— 热卖 / 打折角标
	(行.get_node("热卖") as TextureRect).visible = bool(商品.get("is_hot", false))
	(行.get_node("打折") as TextureRect).visible = bool(商品.get("is_discount", false))

	# `:84-86` + `:113` + `:175-177` —— 购买按钮派发 `BUY_FROM_LIST`，
	# 由 `CashShopWindow2.__buyItem`（`:444-451`）弹出**购买窗**选数量。
	# （§3.48 那个"直接买 1 个"的过渡做法在本轮去掉。）
	var 购买 := 行.get_node("购买") as Button
	购买.text = "购买"
	购买.tooltip_text = "购买当前商品"
	购买.pressed.connect(func(): 窗口._开商城购买窗(商品))


## 荣誉页那一栏（`RongYuPanel.as:91-107 setData` + `:70-89 delayLoadData`）。
## 原版 `setData` **只读 GameData、一条请求都不发**（`ImgUtil.getImg(ImgType.MuyeBattle,"shop")`）
## ⇒ 数据源是 `数据/荣誉商店.json`（导出见 开发工具/导出荣誉商店.py），**行序就是显示序**。
## `delayLoadData` 每 50ms 建一行只是加载动画，落位算式是 `y = height * index`（行高 62）
## ⇒ 这里一次建齐，视觉上没人看得出差别，也不会留一个"重建时要接的定时器"。
## ⚠️ 复用 `商品列表框/商品滚动/商品列表`：原版 `rongYuPanel`(11,64) 与 `listBg`(11,64) 是同矩形、
## 内层 ScrollPane 都是 (3,2) 608x308 / 垂直 ON / 水平 OFF，靠显隐轮换（两边都装不下同时显示）。
func _渲染荣誉货架(page: Control, 商品列表: Control) -> void:
	var 条目们: Array = GAME_DATA.荣誉商店()
	for index in 条目们.size():
		var 行 := 荣誉商品行场景.instantiate() as Panel
		行.position = Vector2(0.0, 62.0 * index)
		商品列表.add_child(行)
		_布置荣誉行(行, 条目们[index] as Dictionary)
	var 滚动 := page.get_node("商品列表框/商品滚动") as ScrollContainer
	皮肤表.配原版滚动区(滚动, 商品列表, 608.0, 308.0, 62.0 * 条目们.size())
	滚动.set_deferred("scroll_vertical", int(_shop_scroll))
	if 条目们.is_empty():
		# 只有导出坏了才会走到这里（表是空 ⇒ 原版同样一页空白，但它会一直转那 50ms 的定时器）。
		_add_positioned_label(商品列表, "没有可用的荣誉商品", Vector2(214.0, 140.0), Vector2(180.0, 24.0), 12, Color("#a9957f"))


## 一行 `RongYuItemCell`。取值与位置规则全部照 `RongYuItemCell.as:175-196` 的 `data` setter。
## ⚠️ 与 `_布置商品行` 的三处不同写在该场景的头注释里（纵向起点 10/28、没有原价行与货币图标、
##   文案是「荣誉：」「兑换」）。
func _布置荣誉行(行: Panel, 条目: Dictionary) -> void:
	var 物品id := str(int(条目.get("itemId", 0)))
	(行.get_node("物品格/图标") as TextureRect).texture = GAME_DATA.item_icon(物品id)
	# `:182` `StringTool.getItemStringObject(itemId)` —— 名字/desc/detaildesc 全从 GameData 的
	# 文案段查，**不在报文里**（这条帧只带 itemId + famePoint）。
	(行.get_node("名称") as Label).text = GAME_DATA.item_name(物品id)
	var 荣誉值 := 行.get_node("荣誉值") as Label
	# `:187-188` —— `formatNumber(famePoint)`，宽度 = 自动字宽 + 3
	荣誉值.text = 数字格式.千分位(int(条目.get("famePoint", 0)))
	荣誉值.size.x = _文字宽(荣誉值) + 3.0

	# `:189-192` —— 绿 detaildesc + 白 desc；超过 3 行贴顶，否则整块垂直居中
	# （原版移动的是 `iteminfoBox.y`，正文在框内固定 (0,?) ⇒ 等效于移正文）。
	var 说明 := 行.get_node("说明") as RichTextLabel
	var 详情 := GAME_DATA.item_detail(物品id)
	var 描述 := String((GAME_DATA.item(物品id) as Dictionary).get("desc", ""))
	说明.text = "" if 详情.is_empty() and 描述.is_empty() else String(窗口.译文为BBCode(
		'<textformat leading="2"><font color="#00ff00">%s</font><br/><font color="#ffffff">%s</font></textformat>'
		% [详情, 描述]
	))
	var 行数 := 说明.get_line_count()
	var 所需高 := 说明.get_content_height() + 5.0
	说明.size.y = 所需高
	说明.position.y = 0.0 if 行数 > 3 else floor((62.0 - 所需高) * 0.5)

	# `:89-91` + `:194` —— 按钮构造时 disable，`data` 走完才打开；
	# `:151-154` 点击**恒传数量 1**、**不做任何本地余额判断**（积分够不够由服务端算，
	# 三条出口都只回 `2323:8:`）。发不出去（未连接）才给一句状态行。
	var 兑换 := 行.get_node("兑换") as Button
	兑换.disabled = false
	兑换.pressed.connect(func():
		if not (_backend != null and _backend.has_method("request_muye_prize")
				and bool(_backend.call("request_muye_prize", int(物品id), 1))):
			窗口._show_hint("兑换请求没发出去（还没连上服务端）"))


## 文字实际占宽。⚠️ 不能用 `get_combined_minimum_size()` —— 无头下它不反映文本（见
## `测试/控件矩形转储.gd` 头注释里踩过的坑）。
func _文字宽(控件: Label) -> float:
	var 字体 := 控件.get_theme_font("font")
	var 字号 := 控件.get_theme_font_size("font_size")
	return float(字体.get_string_size(控件.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 字号).x)


## `CashShopWindow2.as:254-289` 的翻页条。`PageComponent(total, 20, 3)`：
## 每页 20 条；翻页发 `requestData(indexBegin, indexEnd)`，两种货架都走 `request_cash_shop`。
func _渲染商城翻页条(page: Control) -> void:
	var 条 := page.get_node("分页条") as Control
	var 总数 := maxi(0, int(_session.cash_shop_total))
	var 每页 := 20
	var 总页 := maxi(1, int(ceil(总数 / float(每页)))) if 总数 > 0 else 1
	var 当前页 := clampi(int(_shop_page), 1, 总页)
	_shop_page = 当前页
	(条.get_node("页码") as Label).text = "%d/%d" % [当前页, 总页]
	var 首页 := 条.get_node("首页") as TextureButton
	var 上一页 := 条.get_node("上一页") as TextureButton
	var 下一页 := 条.get_node("下一页") as TextureButton
	var 末页 := 条.get_node("末页") as TextureButton
	首页.disabled = 当前页 <= 1
	上一页.disabled = 当前页 <= 1
	下一页.disabled = 当前页 >= 总页
	末页.disabled = 当前页 >= 总页
	if not 首页.pressed.is_connected(_商城翻页):
		首页.pressed.connect(_商城翻页.bind(1))
		上一页.pressed.connect(_商城翻页.bind(2))
		下一页.pressed.connect(_商城翻页.bind(3))
		末页.pressed.connect(_商城翻页.bind(4))


func _商城翻页(动作: int) -> void:
	var 总数 := maxi(0, int(_session.cash_shop_total))
	var 总页 := maxi(1, int(ceil(总数 / 20.0))) if 总数 > 0 else 1
	match 动作:
		1: _shop_page = 1
		2: _shop_page = maxi(1, int(_shop_page) - 1)
		3: _shop_page = mini(总页, int(_shop_page) + 1)
		4: _shop_page = 总页
	窗口._set_shop_page(_shop_page)


## `CashShopWindow2.as:510-534` 的 `CashMoneyPane` + `rongYuLable`/`rongYuInput`。
##
## 三件都是真数据，各有各的来路（别按"哪条链没做"的旧账猜）：
##   · 元宝 = `player_stats.cash`，即 1073 `MoneyInfo.cashMoney`（`MoneyInfo.as:23-26` 就这一个字段）。
##   · 点券 = `player_stats.cash_bind`，来自**角色包**（`DataCenter.as:3151`），不走 1073。
##   · 荣誉积分 = `2323:8:` 写入的 `authoritative_muye_battle.fame_point`（见 `_荣誉积分`）。
## 未连接时三条各自回 0 —— 与原版 `private var` 初值一致，不是"漏接"。
func _渲染商城货币栏(page: Control) -> void:
	var 统计: Dictionary = _session.player_stats
	var 元宝 := page.get_node("货币栏/元宝值") as Label
	元宝.text = str(int(统计.get("cash", 0)))
	# 点券：`player_stats.band_money`，来自**角色包**的 `cashBind`
	# （原版 `DataCenter.as:3151` `bandMoney = param1.cash_bind`）——
	# 与元宝不同，元宝走 1073（`MoneyInfo` 只有 `cashMoney` 一个字段）。
	var 点券 := page.get_node("货币栏/点券值") as Label
	点券.text = str(int(统计.get("cash_bind", 0)))
	点券.tooltip_text = "点券：原版 API.dataCenter.bandMoney（角色包 cashBind 下发）"
	var 荣誉 := page.get_node("荣誉积分值") as Label
	# `CashShopWindow2.as:375-378 updateRongYu` = `rongYuInput.text = formatNumber(famePoint)`。
	# **原版同样从 0 起**：`famePoint` 只由 `2323:8:` 写（`MuYeDaZhanManager:599-624`），
	# 而发 `2323:8:` 的三处全在"点兑换"之后（服务端 `:30031,30036,30046`）⇒ 刚登录没兑过 = 0。
	# ⚠️ 别"顺手"改成读角色包的 `fame`：那是**另一个口径**（服务端 帧 1 的 personal_points 用它，
	#   战场内 `muye_battle_points` 又是另一个），原版这扇窗一个都没读。
	荣誉.text = 数字格式.千分位(_荣誉积分())
	荣誉.tooltip_text = "荣誉积分：来自木叶大战（2323:8 帧），兑换一次荣誉商品后由服务端回帧刷新"

	# 2026-09-26 那次把这三件控件收起来，理由是"荣誉积分永远是 0"（当时那条链确实没接）。
	# 链在 2026-10-20 §3.227 接上了 ⇒ 按该处注释预留的口径**回到原版全显**。
	# 版式的两处偏离（都在 2026-11-01，用户点名）：删掉「1RMB = 10元宝」文案，
	# 翻页条从原版的 283（会压住积分框）挪到它让出来的 454。
	# 见 `场景/界面/窗口/商城/商城窗口.tscn` 的「分页条」注释与 `真值/窗口/商城窗口.md` ④。


## 荣誉积分（`MuYeDaZhanManager.famePoint` 的等价物）在 `后端连接.authoritative_muye_battle` 里，
## **不在** `player_stats`（服务端兑换成功时虽然也补发一条 FAME 统计帧，但那一条更新的是
## 人物面板的"名望"，跟这扇窗读的计数是两条链、原版不混用）。
## 未连接 ⇒ 0（与原版 `private var _famePoint:int` 的初值同一个）。
## ⚠ 取法不许写 `后.get(...) as Dictionary`：桩后端**没有这个属性**时 `get` 返回 null，
##   `null as Dictionary` 抛 `Invalid cast` 并当场打断本函数（§3.245，全量日志 grep 出来的）。
##   抛错的代价不只是噪声——调用点后半句（`荣誉.tooltip_text`）也跟着没跑。
func _荣誉积分() -> int:
	var 后: Node = _backend
	if 后 == null:
		return 0
	var 战斗: Variant = 后.get("authoritative_muye_battle")
	if not (战斗 is Dictionary):
		return 0
	return int(战斗.get("fame_point", 0))
