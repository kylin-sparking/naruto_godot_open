extends CanvasLayer
## **多窗口**管理：每个功能面板一个独立的 `功能窗口` 实例，可以同时开着。
##
## 为什么要有它
## ------------
## 原来地图场景里只有**一个** `功能窗口`，`open_page(name)` 做的是**换页** ——
## 点「人物」再点「背包」，人物那页就被顶掉了，**结构上不可能同时开两个**。
## 而原版每个面板是独立的 `UIWindow`（`PopUpMananger` 管理），本来就能同时开；
## 也正因为能同时开，「从背包拖装备到人物面板」才成立。
##
## 做法
## ----
## * 懒加载：第一次请求某页才 `instantiate` 一个 `功能窗口`，`设为单页(页名, 偏移)` 固定住它；
## * 建好留在树里，之后用 `_overlay.visible` 开关（页面状态不会每次重来）；
## * 再点同一个按钮 = **收起**（原版点底栏按钮也是这个手感）；
## * 每个新窗口按已开数量**错开**一个偏移 —— 否则窗口自己会居中，多个叠在正中央。
##
## ⚠️ 每个实例的 `_ready` 都会把一堆会话信号连到它自己的 `_refresh_current`；
## 但那个函数有 `_overlay.visible` 守卫，关着的窗口不会白刷。

## ⚠ **不要改回 `const 场景 := preload(...)`**（2026-10-25 实测）：`功能窗口.gd` 是
## 451KB、**104 个 preload** 的大脚本，preload 会在**地图场景一加载时**把它整条编译链
## 拖进来 —— 真登录界面点角色→进图 4.7 秒里有 2.7 秒花在这里。窗口本来就是懒建的
## （第一次请求某页才 instantiate），场景也照同一节拍懒取；登录界面在**首帧前**
## 同步预热它，正常走到这里时已经命中缓存，取用时 0 成本。见 `登录界面.gd` 顶部注释。
const 功能窗口路 := "res://场景/界面/功能窗口.tscn"
var _功能窗口场景: PackedScene = null

## Boss 房门那一步（`1349`）要弹的那枚通用确认框。原版是 `MDialog.showMessageDialog`，
## 本工程同族 = `输入确认弹.弹消息`（不自己拼版式、不自己造文案：正文逐字用服务端下发的那句）。
const 输入确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")

## 二级密码六窗（#48）。这里**只用它的三张表**：页名、下行的档位、语言串
## （`文` 那份字典的键与行号都抄在 `真值/窗口/二级密码.md`）⇒ 开窗/弹字这条状态机
## 归本脚本，画页与判式归 `功能窗口` + 那个脚本。**没有循环**：它只 preload 输入确认弹。
const 二级密码窗 := preload("res://脚本/界面/窗口/二级密码/二级密码窗.gd")
## 随身摊位控制器（#49 摊主侧）。这里**只用它的三个静态动作**：`重排`（挂牌增删之后重填行）、
## `加记录`（`1296:4:` 那一本账）、`补日志`（把那本账写回台上那一格）。
## 开窗/判式/发帧都在 `摊位窗.gd` 与 `功能窗口` 里，这里只负责"回帧到了叫谁"。
const 摊位窗 := preload("res://脚本/界面/窗口/摆摊/摊位窗.gd")
## 打坐那颗「双修」球开出来的**成对窗**（原版 `ShuangxiuWindow` + `SelectPlayerWindowInShuangxiuWindow`）。
## 它**不是一页**：两扇成对摆位、而且开窗的是 `1282` 回帧 ⇒ 不进 `取或建窗口` 那套单页流程。
const 双修成对窗 := preload("res://脚本/界面/窗口/双修/双修成对窗.gd")
## 赠花控制器（#88）。这里**只用它一个静态动作** `收花文案`（点托盘那一格弹的那两句，
## 判妖姬要看原版表里的 `rosebuleid` ⇒ 放在窗那一侧，门也才能直接钉）。
## 开窗/上行/画页都在 `赠花窗.gd` 与 `功能窗口` 里，这里只负责"回帧到了叫谁"。
const 赠花窗 := preload("res://脚本/界面/窗口/家族/赠花窗.gd")

## 新窗口的错开步长。**别太小** —— 多个窗口都居中，错 20 来像素的话旧的会被压住，
## 看起来就像"只开了一个"（第一版 26px 就踩了这个）。窗口能拖标题栏，所以
## 初始只要保证"能看出有几个"即可。
const 错开步长 := Vector2(120.0, 78.0)
## 开满这么多就绕回原位重新叠一轮，免得越挪越出屏。
const 绕回个数 := 6
## 每扇窗的 CanvasLayer 局部层号基线：必须**大于 HUD 各面板用过的最大层号**
## （头像/小地图 20，聊天/技能 100，窗口管理/系统消息 110）。
## ⚠ 画序把子层叠进父层、命中却只比各自这个数 ⇒ 取 1..N 会让窗口的点击被聊天面板吃掉。
const HUD基 := 110
## 竞技场那 12 档下行由**常驻单例**接（原版 `PvpManager.getInstance()`），不是哪扇窗的事 ⇒ 挂在这。
const 队伍窗脚本 := preload("res://脚本/界面/窗口/组队/队伍窗.gd")
const 竞技场窗脚本 := preload("res://脚本/界面/窗口/竞技场窗.gd")

var _窗口们: Dictionary = {}      ## 页名 → 功能窗口实例
var _顺序: Array[String] = []     ## 打开顺序，用来排 Z 与算错开量
## 页名 → 上次关闭时的位置偏移。原版窗口会记住上次位置（换会话会漂，见 §3.10.6 第 5 条），
## 这里也照着做：关了再开回到原处，拖动过就按拖动后的位置。
var _记住的位置: Dictionary = {}
var _会话 = null
## 托盘那两格点了要发的帧（接受/婉拒邀请）走的是**全局后端**，不是某一扇窗的 `_backend`。
## 离线门没法连真服务端，所以这里留一个注入口：填了就用它发出帧。
## ⚠ 这不是给运行期用的 —— 运行期恒 null。
var 出帧后端: Node = null
## 师徒申请排队：原版按 charId **同屏摆好几扇**（`ShituListManage.totalTutorWindow`），
## 本工程只有**一扇**申请窗（真值表 §⑧ 登记的偏离）⇒ 正在弹时新来的先排队，关掉一封放下一封。
var _师徒队列: Array = []
var _师徒已连 := false
## 当前那枚「进 Boss 房？」确认框所在的层（同一时刻只留一枚）。
var _进图确认层: CanvasLayer = null


func _发帧后端() -> Node:
	return 出帧后端 if 出帧后端 != null else get_node_or_null("/root/BackendConnection")


func _ready() -> void:
	add_to_group("窗口管理")
	_会话 = get_node_or_null("/root/GameSession")
	if _会话 != null and _会话.has_signal("feature_requested"):
		_会话.feature_requested.connect(打开或收起)
	## Boss 房门（`1349`）：服务端先把换图挂起、等这边回「进/不进」，答了才发 129 开图。
	## 不接这一帧 ⇒ 门点下去什么都不发生（服务端那条 `CHANGE_MAP` 进了
	## `pending_map_confirmation` 就再也不往下走）。用户 2026-10-31 报「BOSS 地图都进不去了」。
	if _会话 != null and _会话.has_signal("portal_panel_requested"):
		_会话.portal_panel_requested.connect(_on_portal_panel)
	## 双修邀请窗的入口不是底栏按钮、也不是 NPC 菜单，而是**服务端推的一帧**：
	## 对方点目标信息条菜单「双修」⇒ `86:3` ⇒ 服务端 `DOUBLE_INVITE` 给**本端**发
	## `1288:2:<邀请者号>`（`fake_flash_server.py:34810-34813`）⇒ 这里开窗。
	## `action 1` = 双方真的开始双修（服务端给两边各发两遍）、`action 4` = 被拒/不可达
	## ⇒ 两种都该让这扇窗消失（原版 `HealHandler` 收到 1 就把邀请框摘掉）。
	var 后 := get_node_or_null("/root/BackendConnection")
	## 竞技场：`2306:8`（排名奖到手）与 `2306:10`（被人挑战）这两档**玩家可能一扇窗都没开着就收到**，
	## 挂在这里（与下面 `heal_state_received` 同一处、同一写法）才不会"没开主窗就整族丢掉"。
	竞技场窗脚本.挂全局(后, self)
	if 后 != null and 后.has_signal("heal_state_received"):
		后.connect("heal_state_received", _on_heal_state)
	## 打坐那颗「双修」球：**开窗的是这条 `1282` 回帧、不是点击**（原版同一条形状，
	## `Client.as:5003-5011`）⇒ 点完球到帧回来之间那一小段，屏幕上什么都不该出现。
	if 后 != null and 后.has_signal("char_search_received"):
		后.connect("char_search_received", _on_玩家搜索帧)
	## 随身摊位窗同理：目标信息条菜单「看摊」⇒ `1296:2:<摊主号>` ⇒ 服务端 `_send_stall`
	## 回一条 `1296:1:<摊主号>:<摊主名>:<摊名>:<行表>:<日志>` ⇒ 这里开窗（买家档）。
	## 摊没摆 ⇒ 服务端只发一条动态提示「对方尚未摆摊」，本端一帧 `1296` 都收不到 ⇒ 窗不开。
	if 后 != null and 后.has_signal("stall_state_received"):
		后.connect("stall_state_received", _on_stall_state)
	## 摊位列表的**列表帧**（`1296:0:`）同一条 1296，只是 action 不同 ⇒ 由 `后端连接`
	## 分流成两条信号。**这一条绝不开窗**：开窗的是背包底部那颗钮（原版 `init()` 发的那一跳），
	## 回帧只负责灌表（`StallDataManager.as:88-94` 全文就一句 `if (stallListWindow)`）。
	if 后 != null and 后.has_signal("stall_list_received"):
		后.connect("stall_list_received", _on_stall_list)
	## 摊主侧那三条增量帧（`1296:2/3/4:`，#49）。**都不开窗** —— 窗是"点自己头像里的看摊"
	## 或"背包那颗摊位列表"开出来的，这三条只负责让台上的那一页跟着变
	## （原版 `StallDataManager` 的 `onStallAddItem` / `onStallRemoveItem` / `onStallTeadeLog`
	## 三个 handler 全文都只碰已经存在的 `myStallWindow`，没有 `show…` 那一句）。
	if 后 != null and 后.has_signal("stall_listing_added"):
		后.connect("stall_listing_added", _on_stall_listing_added)
	if 后 != null and 后.has_signal("stall_listing_removed"):
		后.connect("stall_listing_removed", _on_stall_listing_removed)
	if 后 != null and 后.has_signal("stall_sale_log"):
		后.connect("stall_sale_log", _on_stall_sale_log)
	## 神秘商店同理，而且**开窗的不是那一下点击**：背包底部那颗钮只发 NPC_SHOP 动作 6，
	## 服务端回的一帧 `324:` 才是开窗时刻（`Client.as:8723-8726 onOpenSecretShop`
	## → `MysteryManager.receiveRefItem` → 没窗就 `centerTwoWindow`）。
	## 等级 < 25 时服务端**只发一句系统聊天、不发 324** ⇒ 窗开不出来是原语义，不是坏了。
	if 后 != null and 后.has_signal("mystery_shop_received"):
		后.connect("mystery_shop_received", _on_mystery_shop)
	## 「随身药店」那颗也是**回帧开窗**，不是点击开窗（§3.223）：点击只发 `1818:1`，
	## 服务端 `_send_npc_shop(14)` 回一条 `OPEN_NPC_SHOP` ⇒ 原版
	## `Client.as:771-774 onOpenNPCShop` → `UI.as:2018-2057 openNpcShop`
	## → `UIMain2.as:4894-4901 showShopWindow()` = `centerTwoWindow(SHOP_WINDOW2_F, 背包)`。
	## 同一条也接住了 NPC 对话里点「商店」那一路（原版那路同样只发一跳、由回帧开窗）。
	if 后 != null and 后.has_signal("npc_shop_received"):
		后.connect("npc_shop_received", _on_npc_shop)
	## 「随身仓库」同族：点击发 `1818:2`，服务端回 `330:1`（分块）⇒ 拼完那一下
	## 走 `Client.as:4263-4273 onOpenStorage` → `setStorageWindowVisible()`
	## （`UIMain2.as:4544` = `centerTwoWindow(STORAGE_WINDOW2, 背包)`）。
	if 后 != null and 后.has_signal("storage_opened"):
		后.connect("storage_opened", _on_storage_opened)
	## 「看别人的人物窗」也是**回帧开窗**（原版 `Client.as:3009-3035 onCharInfo`：窗还没建才
	## `setDOShow(CHAR_OTHER_WINDOW_F,true)`，**已经开着就走 `setData` + 五路 `setXxxData` 刷新、绝不关窗**）。
	## ⚠ 这里必须用幂等的 `打开()`、**不能用 `打开或收起`**：两支合起来的效果就是"有则刷、无则开"，
	## 而"收起"只在点标题栏关闭时才发生。
	## 挂在 `feature_requested` 上（10-22 之前的写法）的后果 = **连着点两次「查看信息」窗自己关掉**、
	## 以及"正看着 A 的资料又去点 B"⇒ 窗关了，得再点一次才开得回来。
	if 后 != null and 后.has_signal("他人详细信息收到"):
		后.connect("他人详细信息收到", _on_other_char_info)
	## 角色改名：`2330:10`（结果 0/10 自己）/ `2330:12`（结果 0/12 看别人历史名）。
	## 开窗/关门全由这一帧决定（原版 `Client.as` 里 `onChangeName` / `onGetHistoryNameList`），
	## 点「改名」只是发请求，不等回帧绝不开第二扇窗。
	if 后 != null and 后.has_signal("改名回帧收到"):
		后.connect("改名回帧收到", _on_改名回帧)
	## 交易族四条（上行 119 / 下行 335）。**开窗的不是点击、是服务端那一帧 `335:22`**，
	## 而邀请 `335:3` 连窗都不开 —— 它只往头顶的邀请托盘塞一格（`Client.as:6391-6398`）。
	if 后 != null and 后.has_signal("trade_invite_received"):
		后.connect("trade_invite_received", _on_trade_invite)
	## 师徒申请（#225）：对面点目标信息菜单「拜师/收徒」⇒ 上行 `77:3/4:<我的号>` ⇒
	## 服务端 `handle_tutor:22710-22757` 给**被申请那一方**发 `77:4:<号>:<名>`（来拜我）
	## 或 `77:5:<号>:<名>`（来收我）⇒ 是**这一帧**开 `AgreestToturWindow`（原版
	## `ShituListManage:132-182`），不是点菜单那一方开窗。
	if 后 != null and 后.has_signal("tutor_requested"):
		后.connect("tutor_requested", _on_师徒申请)
	if 后 != null and 后.has_signal("trade_started"):
		后.connect("trade_started", _on_trade_started)
	if 后 != null and 后.has_signal("trade_updated"):
		后.connect("trade_updated", _on_trade_updated)
	if 后 != null and 后.has_signal("trade_closed"):
		后.connect("trade_closed", _on_trade_closed)
	## 族邀（`1552:16`）⇒ **只塞托盘那一格**，点格才开窗（同交易邀请那一族的形状）。
	if 后 != null and 后.has_signal("family_invite_received"):
		后.connect("family_invite_received", _on_家族邀请帧)
	## 入族申请（`1552:8`，只推给族长）⇒ 塞 `TYPE_FAMILY_APPLY` 一格，点格开同一扇
	## 「邀请入族」页壳、换成"审核入族申请"的那一套文案与按钮（原版 `onFamillyApply:148-160`）。
	if 后 != null and 后.has_signal("family_apply_received"):
		后.connect("family_apply_received", _on_家族申请帧)
	## 羁绊（求婚）四条下行各走各的形状，逐条对照 `真值/窗口/求婚窗.md` §①/§②：
	## `61:17` ⇒ **只塞托盘那一格**（原版 `Client.as:7883` → `CueGird.TYPE_QIUHUN`，点格才开窗）；
	## `61:14` ⇒ 直接开**我这侧**那扇「发起羁绊」（`onFriend_taStart:9500` 就是 `setData → showProposalWindow`）；
	## `61:18` ⇒ 只一句提示（`onFriend_refuseTa:10242`，文案有真值）；
	## `61:19/20` ⇒ 结成 ⇒ 原版灌的是 `WeddingWindow`（本工程还没那扇 ⇒ 先把这一扇关掉，**不自造庆祝窗**）。
	if 后 != null and 后.has_signal("bond_invite_received"):
		后.connect("bond_invite_received", _on_羁绊求帧)
	if 后 != null and 后.has_signal("bond_preview_received"):
		后.connect("bond_preview_received", _on_羁绊预览帧)
	if 后 != null and 后.has_signal("bond_refused_received"):
		后.connect("bond_refused_received", _on_羁绊被拒帧)
	if 后 != null and 后.has_signal("bond_established_received"):
		后.connect("bond_established_received", _on_羁绊结成帧)
	## 好友申请（`61:5:<申请人号>:<申请人名>`）⇒ **只塞托盘那一格**，点格才弹 MDialog。
	## 原版这一路的喂格口是 `FriendChatManage.onFriend_addFriendApply:263-269`
	## （`CueManage.addMsg(CueGird.TYPE_FRIEND, {id: charId, name})`），弹与上行在 `CuePane.as:51-54`。
	if 后 != null and 后.has_signal("friend_state_received"):
		后.connect("friend_state_received", _on_好友申请帧)
	## 组队邀请（`59:4:<队号>:<队长名>`）⇒ 原版 `RelationShipHandler.onPartyInvite:196-210` 有**两支**：
	## 自己不在队中 **且** 挂机配置 `troopAutoAcceptInvite` 为真 ⇒ 直接替玩家接受、**连格都不塞**；
	## 否则才塞一格（点格弹 MDialog，见 `_on_托盘已点`）。
	if 后 != null and 后.has_signal("party_state_received"):
		后.connect("party_state_received", _on_组队邀请帧)
	## 赠花两条下行，形状**正好相反**（`MarryTableManager` 那两条，真值 `真值/窗口/赠花窗.md` §②）：
	## `58:2` ⇒ **开窗**（`receiveRefreshFlowerWindow:338` 才 `setDOShow(MARRY_ZENGHUA_WINDOW,true)` ⇒
	## 点菜单只存"对面是谁"并把 `94:6` 发出去，窗是回帧顶出来的）；
	## `61:44` ⇒ **只塞托盘那一格**（`receiveFlower:204-218`：两判 `senderId != 我` 且 `receiverId == 我`，
	## 发花人自己也收这一条 ⇒ 少判一半就会给自己摆一格）。
	if 后 != null and 后.has_signal("花档收到"):
		后.connect("花档收到", _on_花档帧)
	if 后 != null and 后.has_signal("收花帧收到"):
		后.connect("收花帧收到", _on_收花帧)
	if 后 != null and 后.has_signal("bond_dissolved_received"):
		后.connect("bond_dissolved_received", _on_解除羁绊帧)
	## ⚠ 交易那三条**上面 142-147 已经连过了**：10-23 并主干时两边各有一份同样的连接，
	## 自动合并不会报冲突、只会在每次建窗口管理时刷三条
	## `Signal 'trade_started' is already connected ...` ⇒ 别在这儿再加第三份。
	## 二级密码（2309）。这一族**十一帧十一种行为**，全在 `_on_second_password` 里逐条抄
	## `Client.as` 那十一个 `onSecondLevelPassword_*`（真值 `真值/窗口/二级密码.md` §③）。
	if 后 != null and 后.has_signal("二级密码帧"):
		后.connect("二级密码帧", _on_second_password)
	## 托盘那一格被点 ⇒ 按类型分流。交易档弹的是**原版 MDialog 那只确认弹**
	## （`CuePane.as:60-64` + `:109-124`），确定/取消两条都有上行，不是"取消什么都不发"。
	var 盘 := get_node_or_null("邀请托盘") as Control
	if 盘 != null and 盘.has_signal("已点"):
		盘.已点.connect(_on_托盘已点)
	## ⚠ 不要在这里用 `load_threaded_request` 预热功能窗口：GDScript 的 preload 链
	##    不能在加载线程里编译，实测会把 功能窗口.gd 撕成 Parse Error（详见
	##    `登录界面.gd` 顶部注释）。正常路径上登录界面已在首帧前同步预热好。

	## 组队那套是**全局**的（原版 `CueManage` 常驻）：不管玩家开没开过组队页，
	## 收到 `59:4/59:38` 都要进托盘 ⇒ 在这里挂一次，别等 `队伍窗.渲染()`。
	if 后 != null:
		队伍窗脚本.挂全局(后)



func _on_stall_state(_状: Dictionary) -> void:
	## 同一个实例被重新灌（买成之后服务端会再推一条 `1296:1:`）：`打开` 对已开的窗是幂等的，
	## 而 `功能窗口._render_stall` 走 `摊位窗.重灌` ⇒ 只重排行、不重建整页。
	打开("随身摊位")


## `1296:0:<总数>:<行表>` ⇒ **只灌表，不开窗**（原版 `StallDataManager.as:88-94` 的
## `onStallList` 全文一句 `if (stallListWindow) setPageData(...)`：窗没开 ⇒ 这一帧被丢掉，
## 玩家中途关掉窗、回帧才到 ⇒ 也不该把刚关的窗再顶出来）。
## ⚠ 本工程的窗实例**只藏不删**（`_新建窗口` 建过就一直留在 `_窗口们` 里）⇒
##   判据必须是 `已打开()`，判"实例在不在"等于永远判真 —— 那就是原版那句 `if` 的反面。
func _on_stall_list(总: int, 行表: Array) -> void:
	var 窗: Node = _窗口们.get("摊位列表") as Node
	if 窗 == null or not bool(窗.call("已打开")):
		return
	窗.call("灌摊位列表", 总, 行表)


## 台上那扇「随身摊位」（没开 ⇒ null）。判式同 `_on_stall_list`：本工程的窗实例**只藏不删**
## ⇒ 必须判"已打开"，判"实例在不在"等于永远判真。
func _在台的摊位窗() -> Node:
	var 窗: Node = _窗口们.get("随身摊位") as Node
	if 窗 == null or not bool(窗.call("已打开")):
		return null
	return 窗


## 下行 `1296:2:<uid>:<摊主号>:…`（挂上一件）⇒ **只重排摊主自己那一摊**。
## 原文 `StallDataManager.onStallAddItem:80-86` 判的就是 `myStallWindow` 那一个实例，
## 买家那扇**不跟着长行**（别人新挂一件，你看到的还是点开那一瞬间的表）。
## 本工程两档共用一页 ⇒ 把"是不是自己"这句判式挪到这里，拿 `行["owner_id"]` 对 `character_id`。
func _on_stall_listing_added(行: Dictionary) -> void:
	var 窗 := _在台的摊位窗()
	if 窗 == null:
		return
	var 后 := _发帧后端()
	if 后 == null or int(行.get("owner_id", 0)) != int(后.get("character_id")):
		return
	摊位窗.重排(窗)


## 下行 `1296:3:<摊主号>:<uid>`（摘一件）⇒ **摊主与买家两档都要摘**
## （`onStallRemoveItem:65-78` 按摊主号分流到 `myStallWindow` / `stallWindow`，两支都调 `downShelf`）。
## ⚠ 行只在**收到这一帧**时才摘：服务端背包放不下时一句 `1296` 都不回
## （`fake_flash_server.py:25583`）⇒ `摊位窗._点下架` 既不说"成功"也不自己摘行，
##   在这里自己摘 = 把"没回到背包"的那一次演成成功。
func _on_stall_listing_removed(_摊主号: int, _uid: int) -> void:
	var 窗 := _在台的摊位窗()
	if 窗 == null:
		return
	摊位窗.重排(窗)


## 下行 `1296:4:<买家名>:<物品名>:<金币>:<元宝>`（我卖出一件）。
## 这本账是**进程级**的（原版 `onStallTeadeLog:41-63` 往 `StallDataManager.stallLogs` 那根
## 字符串上追一行，从不清）⇒ **窗没开也要追**，否则关掉窗做成的一单会在再开窗时凭空少一行；
## 窗开着才多写一次屏幕（写不写由 `补日志` 里那一句"摊主档才露"决定，买家档恒空）。
## ⚠ 这一条**不重排行**：服务端在发它之前已经发过一条 `1296:1:` 重灌（`_send_stall` 紧跟在成交后面）。
func _on_stall_sale_log(买家名: String, 物品名: String, 金币: int, 元宝: int) -> void:
	摊位窗.加记录(买家名, 物品名, 金币, 元宝)
	var 窗 := _在台的摊位窗()
	if 窗 != null:
		摊位窗.补日志(窗)


## 服务端那帧 `324:` 到货 ⇒ 开窗（原版 `onOpenSecretShop` → `MysteryManager.receiveRefItem`：
## 有窗就 `updateview`、没窗才 `centerTwoWindow`）。这里两条都走 `打开` ——
## 它对已开的窗是幂等的，重灌由 `功能窗口._render_mystery_shop` 负责。
func _on_mystery_shop(_状: Dictionary) -> void:
	打开("神秘商店")


## `OPEN_NPC_SHOP`（含药店那一张 `npc_id 14`）到货 ⇒ 开商店窗。
## ⚠ 这里**只开窗、不判是谁点的**：原版 `openNpcShop` 也没有"这次是药店还是 NPC"这个概念，
## 一个 `ShopWindow2` 装所有货架 ⇒ 谁回帧谁占这张账（药店把上一个 NPC 的货架盖掉是原语义）。
## 神秘商店**不**走这里（那是另一本账 `authoritative_mystery_shop`，见 §3.222）。
func _on_npc_shop(_状: Dictionary) -> void:
	打开("NPC商店")


## `330:1` 拼完 ⇒ 开仓库窗（原版 `onOpenStorage` 那一支）。
func _on_storage_opened() -> void:
	打开("NPC仓库")


## `58:4`（`ServerOpcode.CHAR_INFO` + action 4）到 ⇒ 开/刷新「人物属性（看别人）」。
## 参数只有一帧档，窗口自己从 `后端连接.他人详细信息` 取 —— 这里只负责"让它出现在屏幕上"。
## 已在 `打开()` 里幂等：已经开着就重新渲染（= 原版 `setData` 那支），不关窗。
func _on_other_char_info(档: Dictionary) -> void:
	# 档案与「是否已在我队里」都灌在**窗实例**上：页里的四颗钮/改名要现取
	# （`人物窗口._接他人钮`、`_改名钮被点` 读的就是这两个键）。
	var 窗 := 取或建窗口("人物属性看别人")
	窗.set("_他人档案", 档)
	窗.set("_他人已在队", _队在队(后_取队伍(), int(档.get("cid", 0))))
	打开("人物属性看别人")


## 自己的队伍那份镜像（`后端连接.authoritative_party`）。
func 后_取队伍() -> Dictionary:
	var 后 := get_node_or_null("/root/BackendConnection")
	return (后.get("authoritative_party") as Dictionary) if 后 != null else {}


## 成员表形状来自 `后端连接`（`members` 是一串字典）⇒ 按 id 找，找不到就是不在队。
func _队在队(队: Dictionary, 号: int) -> bool:
	if 号 <= 0 or not bool(队.get("joined", false)):
		return false
	for 成 in (队.get("members", []) as Array):
		if typeof(成) == TYPE_DICTIONARY and int((成 as Dictionary).get("id", 0)) == 号:
			return true
	return false


## 分支（`挂机按原版逐句转写-1019`）里的消费函数名，门与旧调用点都用这个名字；
## 收的是同一帧、开的是同一扇窗，只是把名字收在一处。
func _on_他人详细信息(档: Dictionary) -> void:
	## 收到的是哪一帧，后端那一份镜像也该是哪一帧 —— 窗里 `_render_other_character` 读的
	## 就是后端镜像（生产上 `_handle_character_info_text` 已经先写过一遍，这里幂等）。
	## 只靠这条别名路径喂档的夹具/门（`他人人物窗回归测试._再灌`）就是靠这一句对齐两处。
	var 后 := get_node_or_null("/root/BackendConnection")
	if 后 != null:
		后.set("他人详细信息", 档)
	_on_other_char_info(档)


## `2330` 那一族的回帧消费者。**结果号是"改名的结果"，不是"动作号"**（上行才是动作 1/10/12）：
## · `0` = **改名成功**（服务端扣卡之后 `_send_change_name_result(0, 新名)`）⇒ 摘窗
##   （原版 `handleChangeNameResult:141` 就是 `removeWindow(ChangeNameWindow)`；名字本身等服务端
##   推 34/199 那一族才会真的变，客户端这边只关窗 —— 见 `真值/窗口/人物属性_改钮.md` §⑨ 第 1 条）。
## · `1` = 失败 ⇒ **什么都不做**（原版对 1 没有分支；原因那条动态提示服务端已经发过，
##   客户端再报一句就是双提示，也不关窗 ⇒ 玩家能改完再试）。
## · `10` = 自己的历史名（`消息` 是名字、不是新名）；`12` = 别人的（`消息` 是**那个人的名字**
##   ⇒ 拿它当"别人模式"的标题来源）。10/12 都灌模式与名单再开。
func _on_改名回帧(结果: int, 消息: String, 名单: PackedStringArray) -> void:
	if 结果 != 10 and 结果 != 12 and 结果 != 0:
		return
	var 窗 := 取或建窗口("角色改名")
	if 结果 == 0:
		if bool(窗.call("已打开")):
			窗.call("close")
		return
	窗.set("_改名别人名", 消息 if 结果 == 12 else "")
	窗.set("_改名名单", 名单)
	打开("角色改名")


## 邀请 ⇒ 托盘加一格。**不弹窗、不开窗** —— 弹窗是"点了那一格"之后的事（§⑧⑨）。
func _on_trade_invite(邀: Dictionary) -> void:
	## ⚠ 这里**故意不写类型**：托盘的 `类型交易` 是它自己脚本上的常量，
	## 声明成 `Control` 之后 GDScript 会按 Control 的接口判、编译期就报"找不到属性"。
	var 盘 = get_node_or_null("邀请托盘")
	if 盘 == null:
		return
	盘.加消息(盘.类型交易, 邀)


## `61:5`：**别人申请加我为好友** ⇒ 只塞托盘那一格（原版 `FriendChatManage.onFriend_addFriendApply:263-269`）。
## ⚠ 递给托盘的数据键必须是原版那两个 `id` / `name`（`CueGird.TYPE_FRIEND` 的去重比的是 `data.id`，
## `CueManage.as:113-124`）：后端解出来的是 `character_id`，直接原样递 = 同一个申请连来两次摆两格。
## 也不在这里弹窗 —— 原版弹窗发生在**点那一格**之后（`CueGird.onClickHand:297-299` → `CuePane.as:51-54`）。
func _on_好友申请帧(状: Dictionary) -> void:
	if int(状.get("action", -1)) != 5:
		return
	var 请: Dictionary = 状.get("request", {}) if 状.get("request") is Dictionary else {}
	var 号 := int(请.get("character_id", 0))
	if 号 <= 0:
		return
	var 盘 = get_node_or_null("邀请托盘")
	if 盘 == null:
		return
	盘.加消息(盘.类型好友申请, {"id": 号, "name": String(请.get("name", ""))})


## `59:4`：**别人邀我入队** ⇒ 逐字照 `RelationShipHandler.onPartyInvite:196-210` 的两支：
## ① `!isInTroop(stats.id) && CharacterConfig.troopAutoAcceptInvite` ⇒ 直接 `requestAcceptInvitation(troopId)`，
##    **一格都不塞**（那是玩家自己在挂机设置里勾的"自动接受组队邀请"，原版就是这么吞掉这一帧的）；
## ② 否则塞一格，键名用原版的 `troopId` / `captainName`（去重按 `troopId`，`CueManage.as:125-134`）。
func _on_组队邀请帧(状: Dictionary) -> void:
	if int(状.get("action", -1)) != 4:
		return
	var 邀: Dictionary = 状.get("invite", {}) if 状.get("invite") is Dictionary else {}
	var 队号 := int(邀.get("party_id", 0))
	if 队号 <= 0:
		return
	var 后 := _发帧后端()
	var 在队 := false
	if 后 != null:
		在队 = bool((后.get("authoritative_party") as Dictionary).get("joined", false))
	var 自动 := false
	if _会话 != null:
		自动 = bool((_会话.get("挂机配置") as Dictionary).get("troopAutoAcceptInvite", false))
	if 自动 and not 在队 and 后 != null and 后.has_method("request_party_accept"):
		后.call("request_party_accept", 队号)
		return
	var 盘 = get_node_or_null("邀请托盘")
	if 盘 == null:
		return
	盘.加消息(盘.类型组队邀请, {"troopId": 队号, "captainName": String(邀.get("inviter_name", ""))})


## ── 师徒申请（`77:4` 来拜我 / `77:5` 来收我）──────────────────────────────
## 帧到的那一刻就开窗（原版 `ShituListManage:135-144` 的两档自动档：
## `AUTO_ACCEPT_PRENTICE == 1` ⇒ 不弹、直接回 `77:7`；`AUTO_REFUSE_PRENTICE == 3` ⇒ 直接 `77:5`。
## 本机服务端 `77:15` 把两档都发成 2（不自动）⇒ **实机一定弹**，本工程照"弹"这一档做）。
func _on_师徒申请(档: int, 号: int, 名: String) -> void:
	var 窗 := _师徒窗()
	if 窗 == null:
		return
	if not 窗.has_method("填"):
		return
	if bool((窗.call("现在") as Dictionary).get("开着", false)):
		_师徒队列.append([档, 号, 名])
		return
	窗.call("填", 档, 号, 名)


func _师徒窗() -> Control:
	var 窗 := get_node_or_null("师徒申请层/师徒申请窗") as Control
	if 窗 != null:
		_师徒队列连接(窗)
	return 窗


## 关掉一封 ⇒ 放排队里的下一封（只在第一次拿到这扇窗时连一次，免得重复 connect 叠回调）。
func _师徒队列连接(窗: Control) -> void:
	if _师徒已连 or not 窗.has_signal("关掉了"):
		return
	_师徒已连 = true
	窗.connect("关掉了", _放下一封师徒申请)


func _放下一封师徒申请() -> void:
	if _师徒队列.is_empty():
		return
	var 项: Array = _师徒队列.pop_front()
	var 窗 := _师徒窗()
	if 窗 != null:
		窗.call("填", int(项[0]), int(项[1]), String(项[2]))


## 族长邀我入族（`1552:16:<族长名>:<级>:<职>:<脸>:<族名>:<族长号>:<族号>`）。
## 原版 `FamillyManager.onAcceptFamillyInvite:331-343` 干的事就两件：
## 把那六行改名（`playerName/level/job/face/famillyName/charId`）后塞进 `CueGird`，
## 给那一格挂 `FAMILY_INVITE` 监听 ⇒ **收到帧不开窗**，点格才开（见 `_on_托盘已点`）。
## 去重键 = `charId`（`CueManage.checkExist:113-150` 家族那一支比的是族长角色号），
## 所以这里原样把后端解出来的字典递过去，不再改名、也不挑字段。
func _on_家族邀请帧(邀: Dictionary) -> void:
	var 族长号 := int(邀.get("charId", 0))
	if 族长号 <= 0:
		return
	var 盘 = get_node_or_null("邀请托盘")
	if 盘 == null:
		return
	盘.加消息(盘.类型家族邀请, 邀)


## 入族申请（`1552:8:<申请人名>:<角色号>:<脸>:<等级>`，只推给族长/副族长）。
## 原版 `FamillyManager.onFamillyApply:148-160` 把 `name/id/face/level` 塞进
## `CueGird.TYPE_FAMILY_APPLY` 格 ⇒ **收到帧不开窗**，点格才开「邀请入族」页壳的审核档
## （标题「申请入族」、主钮「批准入族」，见 `家族邀请窗.渲染`）。
## 去重键同样是 `charId`（`CueManage.checkExist:113-150` 家族那一支）。
func _on_家族申请帧(申请: Dictionary) -> void:
	if int(申请.get("charId", 0)) <= 0:
		return
	var 盘 = get_node_or_null("邀请托盘")
	if 盘 == null:
		return
	盘.加消息(盘.类型家族申请, 申请)


## `61:17`：别人向我求羁绊 ⇒ **只塞那一格**（点格才开窗）。`charId` = **求方角色号**
## （不是对戒号、也不是家族号；对戒号在 `item` 那一位，被求那一侧的窗要把它画进第一格）。
## ⚠ 原版 `CueManage` 对求婚这一族**没有去重键** ⇒ 同一个人连发两求就摆两格，别并成一份。
func _on_羁绊求帧(邀: Dictionary) -> void:
	var 求号 := int(邀.get("charId", 0))
	if 求号 <= 0:
		return
	var 盘 = get_node_or_null("邀请托盘")
	if 盘 == null:
		return
	盘.加消息(盘.类型求婚申请, 邀)


## `61:14`：我点了菜单「羁绊」⇒ 服务端把对面那份资料回给我，**这一条直接开窗**。
## 和族邀那一支正好相反（那一支收到帧只塞格）—— 两支的形状在原版里就是不同的，别统一。
func _on_羁绊预览帧(人: Dictionary) -> void:
	if int(人.get("charId", 0)) <= 0:
		return
	var 窗 := 取或建窗口("羁绊申请")
	窗.set("_求婚", {"是被求": false, "人": 人})
	打开("羁绊申请")


## `61:18`：对方拒绝 ⇒ 就一句 addNotice（`DUIFANG_JUJUE_JIEHUN_QINGQIU`，`%1` 换成名字；
## `Client.as:10242-10245`）。这句话**有真值**，不是自造的"对方拒绝了你的邀请"。
func _on_羁绊被拒帧(拒: Dictionary) -> void:
	_弹("真遗憾，" + String(拒.get("name", "")) + "拒绝了您的羁绊请求，再努努力吧！")


## `61:19/20`：结成 ⇒ 原版灌的是 `WeddingWindow`（`Client.as:4878/6795`），**那一扇本工程还没做**
## （`真值/窗口/求婚窗.md` §⑥.1 已登记）。所以这里只做能做的：把还开着的申请窗收掉，
## **不再补发任何帧**、也不自造一张庆祝页。
## 61:23 解除羁绊成功（原版 `FriendProcessor.as:227-229` → `onFriend_divorceSuccess`，
## 服务端 `handle_friend:23395-23404` 给**两边各发一条**）。
## 这一侧只做"还开着的求羁绊那两扇要收掉"——配偶数据已由解码器清成空（`authoritative_spouse`），
## 好友窗那一页下次重画自然读到空的；**不在这里另清一份状态**（两处真相迟早打架）。
func _on_解除羁绊帧() -> void:
	for 页名 in ["羁绊申请", "发起羁绊"]:
		var 窗 := _窗口们.get(页名) as Node
		if 窗 != null:
			窗.call("close")


func _on_羁绊结成帧(_婚: Dictionary) -> void:
	var 窗 := _窗口们.get("羁绊申请") as Node
	## ⚠ **不用 `has_method` 挡**：那一挡会把"方法名写错"变成静默零覆盖（记忆里的老坑）。
	## 方法必须由门钉住存在，这里只做 null 判断。
	if 窗 != null:
		窗.call("关掉求婚窗")


## ── 赠花（#88 / 报修 #263）──────────────────────────────────────────────
##
## 这一族的**数据分两半**，窗和托盘各拿一半，别并成一条：
## · **「对面是谁」（号 / 名 / 脸 / 级）在点菜单那一刻就定下来**（原版把它存进 Manager 自己身上，
##   `openMarryZengHuaWindow:184-197`，**窗还不开**）⇒ 存在下面这个变量上，由 `头像面板` 经
##   `get_parent().get_node_or_null("窗口管理")` 递进来（两者都是地图场景里 map root 的兄弟）。
## · **友好度 / 统计 / 五条记录 / 三档花**全在回帧里 ⇒ 回帧到才开窗（原版那句 `setDOShow` 就在
##   帧处理函数里，`:338`）。
var _赠花对面: Dictionary = {}


## `头像面板` 点「赠花」那一条时调。只认四项，别的字段一律不往窗里带（原版 Manager 上就这四个）。
func 记赠花对面(对面: Dictionary) -> void:
	_赠花对面 = {"charId": int(对面.get("charId", 0)), "name": String(对面.get("name", "")),
			"face": int(对面.get("face", 0)), "level": int(对面.get("level", 0))}


func 取赠花对面() -> Dictionary:
	return _赠花对面


## `58:2` ⇒ 开窗。⚠ `cid == 我` 那一支原版开的是**另一扇** `MyFlowerWindow`（`:332`，我收到的花，
## 带「加为好友 / 回赠」那两列），本工程没做那扇 ⇒ 这里**跳过**，不拿它顶替赠花窗：
## 顶过去就是一扇"我给自己送花"的假页，还顺带把「赠花」那三档花格画成我自己的档位。
func _on_花档帧(档: Dictionary) -> void:
	var 后 := _发帧后端()
	if 后 != null and int(档.get("cid", 0)) == int(后.get("character_id")):
		return
	var 窗 := 取或建窗口("赠花")
	窗.set("_赠花", {"对面": _赠花对面, "档": 档})
	打开("赠花")


## `61:44:<发号>:<收号>:<发名>:<朵>:<花号>` ⇒ **两边各发一份**，所以两判都要（见上面连接处那段）。
## 原版给这一族**没有去重键**（`CueManage.checkExist` 不列 TYPE_XIANHUA）⇒ 同一个人送两次摆两格，
## `邀请托盘._已存在` 那边照的正是这条，这里别再叠一层判重。
func _on_收花帧(条: Dictionary) -> void:
	var 后 := _发帧后端()
	if 后 == null:
		return
	var 我号 := int(后.get("character_id"))
	if int(条.get("senderId", 0)) == 我号 or int(条.get("receiverId", 0)) != 我号:
		return
	var 盘 = get_node_or_null("邀请托盘")
	if 盘 == null:
		return
	盘.加消息(盘.类型收到鲜花, 条)


## `335:22` = 双方成交开始 ⇒ 这才是开窗的那一刻。
## 原版 `setTradeWindowVisible()`（`UIMain2.as:4884-4892`）做的是
## `centerTwoWindow(交易窗, 背包)` ⇒ 交易页已在 `伴随背包` 表里，成对摆位由 `打开()` 负责。
func _on_trade_started(_状: Dictionary) -> void:
	打开("交易")


## 快照每变一次服务端重放一整轮（`_broadcast_trade_snapshot:23753-23787`）⇒ 只重灌、不重建。
func _on_trade_updated(_状: Dictionary) -> void:
	var 窗 := _窗口们.get("交易") as Node
	if 窗 == null or not bool(窗.call("已打开")):
		return
	打开("交易")


## 购买道具窗**全局只该有一枚**。原版 `UIMain2.addBuyWindow:2906-2913` 挂的是
## `_windowMap[UIConfig.BUY_EQP_WINDOW]` 那一个 key ⇒ 天生一枚。我们的 1079 消费者是
## **每个开着的功能窗口各自**连的（`功能窗口.gd:417-418`）⇒ 一发回包弹 N 枚、全叠在屏幕正中，
## 玩家点掉上面那枚，下面还压着一枚 —— 10-20 深夜实机报「购买道具页关不掉」就是这么来的
## （取证：`开发工具/查购买窗关不掉.gd`，两扇都开着时一发 1079 ⇒ 可见的购买窗 2 枚）。
## 谁要弹就先叫别的宿主把自己那枚收干净；`收起购买窗` 只藏不 emit ⇒ 不会再触发这条，不成环。
##
## **归属记在这里**（`功能窗口.请求商城商品` 发 1086 时写）：1079 是广播给所有宿主的，
## 只靠各宿主的 `_等1079` 判"谁问的"会踩时序 —— 先接信号的那扇在 handler 里把旗清掉，
## 后接的那扇再查就看不见旗了，结果可见的那枚跑到了没发请求的遮罩下（10-22 合支实测 ③）。
## 管理节点在信号发出前就记下了申请者 ⇒ 与连接顺序无关。null = 全场没走过 1086（老门直接
## emit 的那种）⇒ 退回原版"全局一枚"：谁都接，由 `收起其他购买窗` 收成最后一枚。
var _购买申请者: Node = null


func 收起其他购买窗(除了: Node) -> void:
	for 页名 in _窗口们.keys():
		var 窗 := _窗口们[页名] as Node
		if 窗 == null or 窗 == 除了 or not 窗.has_method("收起购买窗"):
			continue
		窗.call("收起购买窗")


## `335:8`（成交）/ `335:9:0`（取消）⇒ 关交易窗。
## 原版这两条还把**随身宠窗与背包**一起关掉（`Client.as:7420-7427`、`:3290-3299`——
## 两边都不看 `myType`，无条件关 `suiShenPet`）⇒ 这里照抄。
func _on_trade_closed(_原因: String) -> void:
	for 页名 in ["交易", "背包", "附身宠物"]:
		var 窗 := _窗口们.get(页名) as Node
		if 窗 != null and bool(窗.call("已打开")):
			窗.call("close")


## 托盘点击分流。`类型交易` ⇒ MDialog 确认弹（OK|CANCEL 两档都有上行）；
## 族邀 / 求婚两格 ⇒ 开各自的页窗（原版 `CuePane` 给这两格挂的是 `FAMILY_INVITE` /
## `TYPE_QIUHUN` 监听，`inviteHandler:235-239` 直接 popup，**没有**确认弹那一层）。
func _on_托盘已点(类型: int, 数据: Dictionary) -> void:
	var 盘 = get_node_or_null("邀请托盘")
	if 盘 == null:
		return
	## 家族邀请那一格开的**不是** MDialog（无标题确认弹），而是一扇有标题栏、有关闭叉的
	## `MPromptWindow` 子类 ⇒ 走 `功能窗口` 那侧的页壳，缓存由 `_render_家族邀请` 读。
	if 类型 == 盘.类型家族邀请:
		var 家窗 := 取或建窗口("家族邀请")
		家窗.set("_家族邀请", 数据)
		打开("家族邀请")
		return
	## 入族申请那一格 ⇒ **同一扇**「邀请入族」页壳，只是换成审核档：标题「申请入族」、
	## 正文「该玩家申请加入你的家族，请问你是否审核通过」、主钮「批准入族」（`家族邀请窗.渲染`）。
	## 原版 `onFamillyApply:148-160` 给格挂的 `CueGird.TYPE_FAMILY_APPLY` 监听走的就是这个子类。
	if 类型 == 盘.类型家族申请:
		var 审窗 := 取或建窗口("家族邀请")
		var 审数 := 数据.duplicate()
		审数["是申请"] = true
		审窗.set("_家族邀请", 审数)
		打开("家族邀请")
		return
	## 求婚那一格 ⇒ 开的是**被求那一档**（`_isProposa = true`：标题「羁绊确认」、
	## 主钮「同意请求」、次钮「拒绝」，底下两颗藏起来）。
	if 类型 == 盘.类型求婚申请:
		var 婚窗 := 取或建窗口("羁绊申请")
		婚窗.set("_求婚", {"是被求": true, "人": 数据})
		打开("羁绊申请")
		return
	## 收到鲜花那一格 ⇒ **单钮** `MDialog`（`xianhuaHandler:256-280` 调的是
	## `showMessageDialog(文案, API.stage)`，`param3/param5` 留默认 ⇒ handler 为 null、`buttons = 1`
	## 只有「确定」，且那颗居中 —— `MDialog:228-238`）。点确定**没有上行**：原版只是把弹收掉。
	if 类型 == 盘.类型收到鲜花:
		var 花弹 := get_node_or_null("模态确认弹层/模态确认弹") as Control
		if 花弹 != null:
			花弹.call("弹出", 赠花窗.收花文案(数据), "确定", func() -> void: pass)
		return
	## 竞技场战报那一格 ⇒ 开 `PvpZhanBaoWindow` 等价件（正文 = 同一条战报的 `getZhanBao`）。
	## 走 `竞技场窗` 而不是在这边建窗：那侧才有 `生命`（弹窗自己一层 CanvasLayer 要挂在地图根下）。
	if 类型 == 盘.类型战报:
		竞技场窗脚本.战报格被点(数据)
		return
	## 组队邀请那一格 ⇒ `CuePane.TROOP_INVITE` 那支：弹「××邀请你加入组队！」OK|CANCEL，
	## 确定发 `120:3:<队号>`、取消发 `120:13:<队长名>`（两边都走 `队伍窗.确认邀请`）。
	if 类型 == 盘.类型组队邀请:
		队伍窗脚本.确认邀请(int(数据.get("troopId", 0)), String(数据.get("captainName", "")))
		return
	## 入队申请那一格 ⇒ `CuePane.TROOP_APPLY` 那支：确定发 `120:12`、取消发 `120:14`。
	if 类型 == 盘.类型组队申请:
		队伍窗脚本.确认申请(int(数据.get("partyCharId", 0)), String(数据.get("partyCharName", "")))
		return
	## 好友申请仍走下面那颗两钮弹（`CuePane.__confirmAddFriend`）；交易同理。
	## 组队邀请/申请/战报已在上面各自分派 ⇒ 不再落进通用弹。
	if 类型 != 盘.类型交易 and 类型 != 盘.类型好友申请:
		return
	var 弹 := get_node_or_null("模态确认弹层/模态确认弹") as Control
	var 后 := _发帧后端()
	if 弹 == null or 后 == null:
		return
	var 号 := int(数据.get("id", 0))
	## 好友申请那一格 ⇒ `MDialog(FRIEND_INVITE_YOU_TIP)`（`<font color="#ff6600">%1</font>请求加为好友！`）。
	## ⚠ **只有「确定」有上行**（`CuePane.__confirmAddFriend:168-174` 的 if 里只判 OK，取消什么都不发），
	## 但取消那一颗钮**照旧要摆出来**（`showMessageDialog(…, OK | CANCEL)` ⇒ 两钮档，点它只收弹）。
	if 类型 == 盘.类型好友申请:
		弹.call("弹出",
				"[color=#ffffff][color=#ff6600]%s[/color]请求加为好友！[/color]" % String(数据.get("name", "")),
				"确定",
				func() -> void: 后.call("request_friend_accept", 号),
				"取消", func() -> void: pass)
		return
	## 正文原文 = `TRADE_USER_INFO_BTN_TRADE_INVITE`（`<font color="#ff6600">%1</font>请求与你交易！`），
	## `MDialog.setMessage` 外面再包一层白（`:404`）⇒ 嵌套颜色，内层说了算。
	弹.call("弹出",
		"[color=#ffffff][color=#ff6600]%s[/color]请求与你交易！[/color]" % String(数据.get("name", "")),
		"确定",
		func() -> void: 后.call("request_trade_accept", 号),
		"取消",
		func() -> void: 后.call("request_trade_decline", 号))


## ── 二级密码（2309）：十一帧 ⇒ 六扇窗的开合 ─────────────────────────────────
##
## 逐条照 `Client.as` 那十一个 `onSecondLevelPassword_*`（真值 `真值/窗口/二级密码.md` §③）。
## 三条统一口径，先说清楚，免得后来人"顺手统一"：
##
## * **`reverseDisplay` 是开关**（`UIMain2.as:5139-5182`：已挂台上 ⇒ `removeWindow`，
##   否则 `createWindow` + `addChildAt`）⇒ 这些腿一律走 `打开或收起`，**不是** `打开`。
##   第二次点背包那颗「二级密码」会把说明窗收起，也是同一条。
## * **`Boolean(API.ui.content.<getter>)` 判的是"这个会话里建过没有"**：getter 读 `_windowMap`，
##   而 `removeWindow:5294-5308` 只摘 display child、**从不清那张 map** ⇒ 关着的窗照样算"在"。
##   本工程实例同样只藏不删 ⇒ `_窗口们.has()` 才是等价判据。
##   ⚠ **和上面 `_on_stall_list` 那条正相反**：那里 `StallDataManager.stallListWindow` 关窗会置
##   null，所以判的是"开没开"。两本账不要并成一条。
## * 原版有**四处没判空**（帧 1 的 `setPasswordPane3.updateView`、帧 4 的两条腿）⇒ 对 null 解引用
##   抛异常、整帧作废。本工程判空跳过，并**连带把那两句 `addNotice` 一起圈进判据**
##   （异常发生在弹字之前 ⇒ 窗没建过就该一句都不弹，帧 9 的原版本来就是这么圈的）。
func _on_second_password(动作: int, 值: Array) -> void:
	match 动作:
		0:
			# passwordReusltFirstTime:5305-5311 —— **失败那条腿原文是空的**：不弹、不开、不清输入。
			if int(值[0]) == 1:
				打开或收起(二级密码窗.页二格)
		1:
			# QAResult:2546-2552 —— 成功才把三格推到「确认档」（原地换显示，不开也不关）。
			if int(值[0]) == 1:
				_刷二级(二级密码窗.页三格, 二级密码窗.档确认)
		2:
			# isFirstTimeResult:1569-1577 —— `类型` 已由后端写进 `authoritative_second_password`，
			# 这里开合说明窗 + 刷那三颗钮（首钮文字、两颗 enabled 全读那份账）。
			打开或收起(二级密码窗.页说明)
			_刷二级(二级密码窗.页说明)
		3:
			# contactResult:2456-2459 —— **结果号读都不读**：服务端说"资料没存上"也照样往下开三格。
			# 而且原版这一支没有 `updateView`：开出来的就是 `initWindow` 那一版（Type1）。
			打开或收起(二级密码窗.页三格)
		4:
			# QAConformResult:6445-6457 —— `else` 是"非 0"，不是"==1"。
			var 窗四 := _建过(二级密码窗.页三格)
			if 窗四 != null:
				if int(值[0]) == 0:
					_刷二级(二级密码窗.页三格, 二级密码窗.档确认)
					_弹(String(二级密码窗.文["设置失败"]))
				else:
					_关二级(二级密码窗.页三格)
					_弹(String(二级密码窗.文["设置成功"]))
		5:
			# Questions:1961-1971 —— 两根问题 + 剩余删除次数已进账 ⇒ 落点是**删除档**。
			# ⚠ 顺序照原版：**先写草稿**（`TwoPasswordManager.problem1/problem2 = param1/param2`）
			# 再 `reverseDisplay` + `updateView(Type3)` —— 删除档那两格显示的是**服务端发来的这两条**，
			# 不是玩家上次自己填的那对（`刷三格` 读的就是 `草稿["问题n"]`，写在后面就晚了）。
			二级密码窗.草稿["问题1"] = String(值[0])
			二级密码窗.草稿["问题2"] = String(值[1])
			打开或收起(二级密码窗.页三格)
			_刷二级(二级密码窗.页三格, 二级密码窗.档删除)
		6:
			# modifyPasswordResult:2001-2012 —— 非 1 只把「还可以进行%1次」刷成新数，1 才关窗。
			# ⚠ **成功失败都不弹字**：`TWOPASSWORD_NOTICE_3/4` 全库无人引用（真值 §⑤ 第 2 条）。
			if int(值[0]) != 1:
				_刷二级(二级密码窗.页修改)
			else:
				_关二级(二级密码窗.页修改)
		7:
			# requestPassword:4838-4841 —— 服务端**主动**要密码（登录进锁定态那一支）。
			# `showUnchainLookWindow`（`UIMain2.as:5690-5698`）= removeWindow + centerWindow(重建, true)
			# ⇒ 不是开关，是**每次都重摆到正中央**（`居中弹` 那条），所以这里走 `打开`。
			打开(二级密码窗.页解锁)
		8:
			# releaseLockResult:6810-6816 —— 只写 `已解锁`（后端 `:6206` 已经写了），别的一个都不动：
			# 不关解锁窗（它点确定那一刻自己就关了）、不刷说明窗（下次进来才在 `updateView` 里吃到）。
			pass
		9:
			# QAConformResultForDelete:5741-5754 —— 两条 `addNotice` 都圈在 `Boolean(窗)` 里。
			var 窗九 := _建过(二级密码窗.页三格)
			if 窗九 != null:
				if int(值[0]) == 1:
					_关二级(二级密码窗.页三格)
					_弹(String(二级密码窗.文["删除成功"]))
				else:
					_刷二级(二级密码窗.页三格, 二级密码窗.档删除)
					_弹(String(二级密码窗.文["删除失败"]).replace("%1", str(int(值[1]))))
		10:
			# requestModifyPasswordResult:5623-5631 —— 剩余修改次数进账后开合改密窗 + 刷那一句。
			打开或收起(二级密码窗.页修改)
			_刷二级(二级密码窗.页修改)


## 「这一扇这个会话里建过没有」= 原版 `Boolean(API.ui.content.<getter>)`（读 `_windowMap`）。
func _建过(页名: String) -> Node:
	return _窗口们.get(页名) as Node


## 回帧的**重画**那一半（= `xxxWindow.updateView(...)`）。窗没建过 ⇒ 一条都不做。
func _刷二级(页名: String, 档: int = -1) -> void:
	var 窗 := _建过(页名)
	if 窗 != null:
		窗.call("刷二级密码", 档)


## 原版 `xxxWindow.onCloseBtnClick(null)` ⇒ 本工程 `close()`（只藏不删，实例留在窗表里）。
func _关二级(页名: String) -> void:
	var 窗 := _建过(页名)
	if 窗 != null:
		窗.call("close")


## `API.ui.addNotice` 的端口（同 `功能窗口._通知:1519`，只是这里没有宿主可借）。
func _弹(文本: String) -> void:
	if _会话 != null and _会话.has_signal("notification_requested"):
		_会话.notification_requested.emit(文本)


func _on_heal_state(状: Dictionary) -> void:
	match int(状.get("action", 0)):
		2:
			打开("双修邀请")
		1, 4:
			var 窗 := _窗口们.get("双修邀请") as Node
			if 窗 != null and 窗.has_method("关掉双修邀请"):
				窗.call("关掉双修邀请")


## `1282` 玩家搜索回帧。归「双修成对窗」那一组自己判这帧是不是它的
## （家族那侧按名字搜发的是 searchType 100，原版 `FamillyManager.as:897`）。
func _on_玩家搜索帧(结果: Array) -> void:
	双修成对窗.回帧(self, 结果)


## 同一页再点一次 = 收起（原版点底栏按钮的手感）。
func 打开或收起(页名: String) -> void:
	## 「双修」不是一页：那是**两扇成对窗**（`centerTwoWindow`），而且开窗的是 `1282` 回帧
	## ⇒ 不进 `取或建窗口`/`打开` 那套单页流程（否则 `功能窗口` 会把 `_current_page`
	## 换成一个没有渲染分支的页名 ⇒ 开出一扇空白窗）。
	if 页名 == "双修":
		双修成对窗.点球(self)
		return
	页名 = 规范页名(页名)
	var 窗 := _窗口们.get(页名) as Node
	if 窗 != null and 窗.call("已打开"):
		_记住的位置[页名] = 窗.call("取位置偏移")
		窗.call("close")
		return
	打开(页名)


func 打开(页名: String) -> void:
	页名 = 规范页名(页名)
	var 窗 := _窗口们.get(页名) as Node
	if 窗 == null:
		窗 = _新建窗口(页名)
		_窗口们[页名] = 窗
	_置顶(页名)
	窗.call("打开")
	# 关过再开要回到**上次关掉时**的位置（`打开或收起` 关闭时已记进 `_记住的位置`）。
	# `窗口偏移` 是绝对定位、幂等，调几次结果都一样。
	if 居中弹.has(页名):
		# 弹层每次都回到正中央（`PopUpMananger.centerWindow`），不吃错开、也不回填旧位置。
		窗.call("窗口偏移", Vector2.ZERO)
	elif _记住的位置.has(页名):
		窗.call("窗口偏移", _记住的位置[页名])
	if 伴随背包.has(页名):
		# 原版 `showShopWindow` 是先 `setDOShow(背包)` 再 `setDOShow(主窗)` ⇒ 主窗在顶上；
		# 这里 `打开("背包")` 会把背包置顶，所以摆完要把主窗再提回去。
		打开("背包")
		成对摆位(页名)
		_置顶(页名)
	elif 成对伴随.has(页名):
		# B2 = 原版 `UIMain2.as:5949-5956 showLingquPane()` → `:3159 centerTwoWindow(设定窗, 领取窗)`：
		# `:3161` 先 `setDOShow(领取窗)`、`:3162` 再 `setDOShow(设定窗)` ⇒ **后显的设定窗在顶上**。
		# 这里点的那颗开的是领取窗（右），所以要再把设定窗叫出来并提到顶上。
		var 伙伴 := String(成对伴随[页名])
		打开(伙伴)
		成对摆位(伙伴, 页名)
		_置顶(伙伴)
	# ⚠️ 2026-10-23 §3.189（用户实机报：意志学习/意志背包两窗该并排——学习在左、
	#    背包在右、紧挨、同 y、整体居中，照原版 `MWindow.setLocationCenter` +
	#    `subWindow` 公式）。**搭档已开着**才成对（不强制开另一扇，原版开学习窗
	#    不会连带开背包）；两窗互为搭档 ⇒ 无论先开哪个、后开哪个都重摆成对。
	#    主窗恒为「意志学习」（= 用户要的"学习在背包左边"），每次打开重摆
	#    （原版 `centerTwoWindow` 同语义：伴随背包那一族也是每次打开都重摆）。
	if 成对意志窗.has(页名):
		var 搭档名: String = "遗址" if 页名 == "意志学习" else "意志学习"
		var 搭档 := _窗口们.get(搭档名) as Node
		if 搭档 != null and bool(搭档.call("已打开")):
			成对摆位("意志学习", "遗址")
			_置顶(页名)


## 这一族窗口打开时**把背包一起叫出来**，两窗顶边平齐、背包紧贴主窗右侧 1px。
##
## 真值 = `UIMain2.as:3159-3185 centerTwoWindow(主, 背包)`：交易/仓库/变卡互换/勾玉炼制/生命料理/徽章打造。
## 例外（2026-10-31）：背包比主窗高时它自己夹进屏内、顶边不再平齐 —— 见函数里那段注释。
##
## 第二参 `伙伴名` 是给 B2 那一族用的（左「修行设定与收益」+ 右「领取修行收益」，
## 伙伴不是背包）。默认的 `"背包"` 保持上面那一族**一个字的调用点都不用改**。
func 成对摆位(主页名: String, 伙伴名: String = "背包") -> void:
	var 主 := _窗口们.get(主页名) as Node
	var 包 := _窗口们.get(伙伴名) as Node
	if 主 == null or 包 == null:
		return
	var 视口 := get_viewport().get_visible_rect().size
	var 主尺: Vector2 = 主.call("取窗口尺寸")
	var 包尺: Vector2 = 包.call("取窗口尺寸")
	if 主尺.x <= 0.0 or 包尺.x <= 0.0:
		return
	# 竖直：主窗按**自己**的高度居中（原版 `UIMain2.as:3170 setLocationCenter(false,true)`），
	# 伙伴跟主窗的 y（`:3171 _loc4_.y = _loc3_.y`，两窗顶边平齐）。
	# ⚠️ 2026-10-31：本工程的背包是 453x556（10 列 x 9 行一屏全露，见 `背包窗口.gd` 头注），
	#   跟着矮主窗（勾玉 407 / 交易 483）居中会垂出下沿 72/34px ⇒ 随身药店、神秘商店那几行
	#   点不到。背包比主窗高时**单独夹进屏内**，顶边因此不再平齐 —— 有意偏离：原版
	#   `ItemWindow2` 394 高、560 舞台里永远不触这条；而头像面板还恒在窗之上（`目标信息条
	#   回归测试` ⑨「头像处于最上层，不会被窗口挡住」= 用户 10-15 定的口径），不能靠抬高
	#   窗口层去抢那块地方。其余族（意志学习/遗址、闭关/领取）两扇都装得下 ⇒ 与原版一致。
	var 主左上 := Vector2(maxf(0.0, (视口.x - (主尺.x + 包尺.x + 1.0)) * 0.5),
			floorf((视口.y - 主尺.y) * 0.5))
	var 包左上 := Vector2(主左上.x + 主尺.x + 1.0, 主左上.y)
	if 包左上.y + 包尺.y > 视口.y:
		包左上.y = maxf(0.0, 视口.y - 包尺.y)
	# `窗口偏移()` 收的是「相对视口中心的偏移」；第二参 false = **不钳进视口**（原版那对会垂出下沿）。
	主.call("窗口偏移", 主左上 + 主尺 * 0.5 - 视口 * 0.5, false)
	包.call("窗口偏移", 包左上 + 包尺 * 0.5 - 视口 * 0.5, false)


## 伴随小窗贴主窗（原版 `StallWindow.as:640-646` / `:665-670`、`UIMain2.as:4754-4755`）：
## 左边放得下就贴左、否则贴右，y 对齐主窗顶边。原版舞台固定、这些窗只往左摆；
## 本工程视口窄时左摆会出屏 ⇒ 统一夹进视口（`窗口偏移` 默认就钳，这里算好再传）。
func 摆到旁边(页名: String, 参照页名: String) -> void:
	var 窗 := _窗口们.get(页名) as Node
	var 主 := _窗口们.get(参照页名) as Node
	if 窗 == null or 主 == null:
		return
	if not bool(窗.call("已打开")) or not bool(主.call("已打开")):
		return
	var 视口 := get_viewport().get_visible_rect().size
	var 窗尺: Vector2 = 窗.call("取窗口尺寸")
	var 主尺: Vector2 = 主.call("取窗口尺寸")
	if 窗尺.x <= 0.0 or 主尺.x <= 0.0:
		return
	var 主偏移: Vector2 = 主.call("取位置偏移")
	var 主左上 := 主偏移 + 视口 * 0.5 - 主尺 * 0.5
	var x := 主左上.x - 窗尺.x
	if x < 0.0:
		x = 主左上.x + 主尺.x
	x = clampf(x, 0.0, maxf(0.0, 视口.x - 窗尺.x))
	var y := clampf(主左上.y, 0.0, maxf(0.0, 视口.y - 窗尺.y))
	窗.call("窗口偏移", Vector2(x, y) + 窗尺 * 0.5 - 视口 * 0.5)


## 打开时要把**另一扇功能窗**（不是背包）一起叫出来、并按 `centerTwoWindow` 摆成一对的页。
## 键 = 点那颗开的那扇（右），值 = 另一扇（左）。
##
## B2 唯一的一条：`UIMain2.as:5949-5956 showLingquPane()` →
## `:5955 centerTwoWindow(UIConfig.BI_GUAN_WINDOW_F, UIConfig.LINGQU_BIGUAN_SHOUYI)`
## ⇒ 左「修行设定与收益」(`BiGuanWindow.as:122-124` 267×274)、
##   右「领取修行收益」(`LingquBiguanShouyi.as:225-226` 267×218)、
##   `:3172` 顶边平齐、`:3176` 紧贴 +1px、`:3173-3175` 整对按 `267+267+1` 水平居中。
## 只登记**已核实**的这一条，别凭空加名字。
const 成对伴随 := {"领取修行收益": "闭关经验"}


## 关一扇 ⇒ 另一扇跟着关。原版是**双向**的：
##   `BiGuanWindow.as:101-108` 关设定窗时 `if(lingquShouyi) lingquShouyi.onCloseBtnClick(null)`；
##   `LingquBiguanShouyi.as:209-210` 领完也把两扇一起关。
## 由 `功能窗口.close()` 回来调这里（那里是全工程唯一的关窗出口）。
func 连带关闭(页名: String) -> void:
	var 伙伴 := ""
	if 成对伴随.has(页名):
		伙伴 = String(成对伴随[页名])
	elif 成对伴随.values().has(页名):
		for 键 in 成对伴随:
			if String(成对伴随[键]) == 页名:
				伙伴 = String(键)
				break
	if 伙伴.is_empty():
		return
	var 窗 := _窗口们.get(伙伴) as Node
	if 窗 != null and bool(窗.call("已打开")):
		窗.call("close")


## 打开时要连背包一起叫出来的页（只登记**已核实**的，别凭空加名字）。
## 这一族两窗互为搭档：任一扇**已开着**时打开另一扇 ⇒ 两窗并排摆位
## （学习窗在左、意志背包在右，紧挨、同 y、整体水平居中）——照原版
## `MWindow.setLocationCenter` + `subWindow` 公式（`MWindow.as:355-363`：
## 主窗 x = (舞台宽 − 主宽 − 子宽)/2、子窗 x = 主窗 x + 主窗宽 + 1、子窗 y = 主窗 y）。
## 用户 2026-10-23 实机报：「意志学习的弹窗应该在意志背包左边紧挨着，并且平行且在
## 屏幕正中」。注意与 `伴随背包` 不同：这里**不**连带开另一扇，只做摆位。
const 成对意志窗 := {"意志学习": true, "遗址": true}


## 打开时要连背包一起叫出来的页（只登记**已核实**的，别凭空加名字）。
const 伴随背包 := {"NPC商店": true, "NPC仓库": true,
	"变身卡属性互换": true, "变身卡特性互换": true,   # UIMain2.as:580 / :694-697
	"技能书": true,                                    # UIMain2.as:3361 / :5858（两个入口都 centerTwoWindow）
	"勾玉炼制": true,                                  # UIMain2.as:3848-3866
	"生命料理": true,                                  # UIMain2.as:3928-3940
	"徽章打造": true,                                  # UIMain2.as:4547-4565
	"神秘商店": true,                                  # MysteryManager.as:37-45 `receiveRefItem`
														# 里没有窗时走的正是 `centerTwoWindow(MYSTERY_WINDOW, ITEM_WINDOW2_F)`
	"交易": true,                                      # UIMain2.as:4884-4892 `setTradeWindowVisible`
														# = `centerTwoWindow(TRADE_WINDOW_F, ITEM_WINDOW2_F)`
	"宝石镶嵌": true,                                  # `UIMain2.as:2720-2733 showStoneCarryWindow` /
														# `:5558-5570 showGouYuCarryWindow`（同一扇窗、两族）
														# 都是 `centerTwoWindow(STONE/GOUYU_CARRY_WINDOW, ITEM_WINDOW2_F)`
														# ⇒ 主窗在左、背包在右；2026-11-02 用户报
														# 「镶嵌子面板优先级低于背包」的根因是本工程没摆这一对，
														# 254×204 的小窗正中压在 453×556 背包里。
	"梦幻属性符": true,                                # `UIMain2.as:5651-5664 showMengHuanPropRestWindow`
														# = 先 `centerTwoWindow(MENG_HUAN_PROP_RESET_WINDOW,
														# ITEM_WINDOW2_F)` 再 `showPropPanle(符)`
	"橙装打造": true,                                  # `UIMain2.as:3961-3981 showYellowEquipLianZhiWindow`
														# = `centerTwoWindow(YELLOWEQUIP_LIANZHI_WINDOW,
														# ITEM_WINDOW2_F)` 再 `init(tab)`
	"挖矿": true,                                      # 宝石工艺 `StoneWindow`：`UIMain2.as:3614 / :4538`
														# `centerTwoWindow(STONE_WINDOW, ITEM_WINDOW2_F)`
														# （`:5107` 关窗时 deleteTwoWindow 同一对）
	"装备修复": true}                                  # `UIMain2.as:3618-3630 showEquipRepairWindow`
														# = `centerTwoWindow(EQUIP_REPAIR_WINDOW,
														# ITEM_WINDOW2_F)` 再 `init(param1, param2)`
														# （⚠ 同文件 `:3958 reverseDisplay` 是 `showMendEtcWindow`
														# 的 MEND_ETC_WINDOW，与这扇无关，别混）


## 这一族是**弹层**，原版永远摆正中央、不参与错开、也不记位置。
## 「二级密码解锁」= `showUnchainLookWindow`（`UIMain2.as:5690-5698`）那句
## `centerWindow(createWindow(UNCHAIN_LOOK_WINDOW), true)` —— 第二参 true 就是**带遮罩**，
## 而其余五扇（说明/一格/二格/三格/修改）走的是 `reverseDisplay` ⇒ 普通可拖窗，不进这张表。
const 居中弹 := {"洗点确认": true, "双修邀请": true, "摊位购买": true,
	"摊位上架": true,					# 同 `StallUpShelfWindow` 的另一档（`:83` 那句在构造里，两档共用）
	"家族邀请": true,					# `PopUpMananger.centerWindow(_, false)`（`FamillyManager:127`）
	"二级密码解锁": true}


## 把某页提到最上层。层级规则的**唯一实现**（新开窗、点窗任意位置都走它）。
##
## ⚠️ 目标索引取 `get_child_count() - 1`，**不要**写 `_顺序.size() - 1`。
##   原来写的正是后者，而且在 `append` **之前**算，恒差一格 ——
##   第二个开的窗被 `move_child` 到 index 0，也就是压到最底。
##   用户 2026-09-24 报的"层级固定成人物最高、背包最底"就是这条。
##   另：「子节点序号」和「`_顺序` 下标」本来就不该互相推导，所以直接用前者。
## **最上层**那扇已打开的窗（`_顺序` 末尾那枚，层号也最高）。
##
## 用途：**全局弹窗**（如 1079 商品详情 ⇒ 商城购买窗）只该它一家响应。
## ⚠️ 每扇窗各有自己的 `遮罩`，若每个实例都弹一次，一次回包就会叠出 **N 枚购买窗 + N 层遮罩**；
##    玩家关掉看得见的那枚之后，**剩下的遮罩继续吃点击**（黑 α0.3、`mouse_filter=STOP`）
##    ⇒ 整屏像卡死。2026-10-16 用户实机报的「背包扩充里买过一次、再买一次就卡住」就是这个。
func 取最上层窗口() -> Node:
	for i in range(_顺序.size() - 1, -1, -1):
		var 窗 := _窗口们.get(_顺序[i]) as Node
		if 窗 != null and is_instance_valid(窗) and bool(窗.call("已打开")):
			return 窗
	return null


func _置顶(页名: String) -> void:
	if not _窗口们.has(页名):
		return
	_顺序.erase(页名)
	_顺序.append(页名)
	move_child(_窗口们[页名] as Node, get_child_count() - 1)
	重排层级()


## 按 `_顺序` 依次给每扇窗分配递增的 `layer`，**但身上有浮层（模态弹窗/购买窗）的那一扇排到最后**
## —— 那是原版 `UIMain2.bringMWindowToTop:3693-3712` 给置顶留的上限（窗口永远升不到弹窗之上）
## 在我们这套"浮层挂在宿主自己的 `遮罩` 里"的结构下的唯一落法。详见 `功能窗口.有浮层()`。
##
## ⚠️ **光靠 `move_child` 不够**：这些窗各自是一个 CanvasLayer，而 Godot 在
## **同一 layer** 的 CanvasLayer 之间是按**创建顺序**画的，不跟树序。
## 实测（2026-09-24）：`move_child` 把人物排到末位后，`get_child(get_child_count()-1)`
## 确实是人物（所以按树序断言的用例会假绿），可 `gui_get_hovered_control()` 在重叠区
## 命中的仍是背包 —— 画序和命中都没变。layer 才是真正说了算的那个。
##
## ⚠️ 原来这里从 **1** 开始排 —— "往上取不冲突"只对**画序**成立；
## Godot 对一个 CanvasLayer 用**两套顺序**：
##   · 画序：按 canvas 索引，子层叠在父层里面 ⇒ 窗**画在 HUD 之上**（看着对）；
##   · 命中：Viewport 的 GUI 拾取比的是**每个 CanvasLayer 自己写的那个 `layer` 数**，**不加父层**
##     ⇒ 原来 1..N 比聊天/技能面板的 100 **小**，重叠区的钮点不到（2026-10-06 实测）。
## ⇒ 局部层号必须**大于现网 HUD 用过的最大层号**，基线取 110。
func 重排层级() -> void:
	## 先按"身上有没有浮层"分两拨，各拨内部保持 `_顺序` 里的相对次序：**带浮层的那一拨排最后**
	## ⇒ 拿到最大层号 ⇒ 点别的窗把它自己提到最上，也压不到那一拨的弹窗上（见 `功能窗口.有浮层()`）。
	var 序: Array[String] = []
	var 后: Array[String] = []
	for 页名 in _顺序:
		var 窗 := _窗口们.get(页名) as Node
		if 窗 == null:
			continue
		if 窗.has_method("有浮层") and bool(窗.call("有浮层")):
			后.append(页名)
		else:
			序.append(页名)
	for 页名 in 后:
		序.append(页名)
	for i in 序.size():
		var 窗 := _窗口们.get(序[i]) as Node
		if 窗 != null:
			窗.layer = HUD基 + i + 1


## 点窗口的**任何位置**都把它提到最上（用户 2026-09-24 定的规则）。
##
## 从 `_顺序` 末位往下找第一个命中的 —— 只有**压在最上面**的那扇才该被提起；
## 否则点重叠区会把下面那扇也一起翻上来。
##
## 放 `_input` 而不是 `_gui_input`：`_input` 早于 GUI 派发，即使那一点上是个按钮
## 把事件吃掉，窗口也照样置顶。
func _input(event: InputEvent) -> void:
	var 点事件 := event as InputEventMouseButton
	if 点事件 == null or not 点事件.pressed or 点事件.button_index != MOUSE_BUTTON_LEFT:
		return
	# **模态弹罩着这一点 ⇒ 一票都不提。** 原版 `MDialog` 挂的是 `PopUpMananger.stage`
	# （自成一层，点它不会把底下的窗翻上来）；这边的弹挂在各窗自己的 `遮罩` 里，
	# 而成对摆位时**隔壁那扇窗的矩形也盖住弹上同一个点** ⇒ 不拦的话 `_input` 抢在 GUI 拾取
	# 之前把隔壁提起来，弹被压到隔壁之下：玩家点「取消」实际点中背后的背包一格
	# （10-19 实测：神秘商店买东西的确认弹正压在背包第 18 格上，取消/确定都点不动）。
	for i in range(_顺序.size() - 1, -1, -1):
		var 弹窗 := _窗口们.get(_顺序[i]) as Node
		if 弹窗 != null and bool(弹窗.call("已打开")) and bool(弹窗.call("模态弹罩住", 点事件.position)):
			return
	for i in range(_顺序.size() - 1, -1, -1):
		var 页名 := _顺序[i]
		var 窗 := _窗口们.get(页名) as Node
		if 窗 == null or not bool(窗.call("已打开")):
			continue
		if (窗.call("窗口矩形") as Rect2).has_point(点事件.position):
			_置顶(页名)
			return


## 关掉所有窗口（换图等场景调；原版换图也是全关）。
func 全部关闭() -> void:
	for 页名 in _窗口们:
		var 窗 := _窗口们[页名] as Node
		if 窗 != null and 窗.call("已打开"):
			窗.call("close")


func 取窗口(页名: String) -> Node:
	return _窗口们.get(页名) as Node


## 按页名取实例，**没有就建一个**（不打开）。给测试与截图工具用 ——
## 它们原来按节点名 `功能窗口` 找那唯一实例，现在是多实例了，得指名要哪一页。
## 默认页名 "人物"：绝大多数老工具截的都是人物面板。
func 取或建窗口(页名 := "人物") -> Node:
	页名 = 规范页名(页名)
	var 窗 := _窗口们.get(页名) as Node
	if 窗 == null:
		窗 = _新建窗口(页名)
		_窗口们[页名] = 窗
	return 窗


## 页名别名。分支（`挂机按原版逐句转写-1019`）把这一扇叫「他人人物」，
## master 后来按功能键改叫「人物属性看别人」；两份门都在仓里，别名收在这一处，
## 免得 `_窗口们` 里同一扇窗挂两个实例。
func 规范页名(页名: String) -> String:
	if 页名 == "他人人物":
		return "人物属性看别人"
	return 页名


## 第一次要开窗时才取 `功能窗口.tscn`。正常路径上登录界面已在首帧前
## 同步 load 过 ⇒ 这里命中 ResourceLoader 缓存；直接进图的工具/门则在这里付一次。
## 之后所有页共用同一份 PackedScene。
func _取功能窗口场景() -> PackedScene:
	if _功能窗口场景 == null:
		_功能窗口场景 = load(功能窗口路) as PackedScene
	return _功能窗口场景


func _新建窗口(页名: String) -> Node:
	页名 = 规范页名(页名)
	var 包 := _取功能窗口场景()
	if 包 == null:
		push_error("窗口管理：功能窗口场景打不开（%s）" % 功能窗口路)
		return null
	var 窗 := 包.instantiate()
	add_child(窗)
	# 按当前已开数量错开；开满一圈就绕回来，免得越挪越远
	# 位置：上次关掉时在哪就回哪；没记录过则按已开数量错开
	var 偏移: Vector2 = _记住的位置.get(页名, 错开步长 * float(_窗口们.size() % 绕回个数))
	窗.call("设为单页", 页名, 偏移)
	return 窗


## Boss 房门（`1349`）：`正文`是服务端给整句（`fake_flash_server.py:15101-15104`），
## 逐字弹出来、不另造文案；答了才回帧，服务端拿到「进」才 `_warp_to_map`。
## 自己单开一层 `CanvasLayer`：功能窗口各自是 CanvasLayer，GUI 拾取只比各自的 `layer`
## （见 `重排层级` 的注释）⇒ 挂在本层里会被窗子盖住，必须比它们都高。
func _on_portal_panel(request_id: int, 正文: String) -> void:
	if _进图确认层 != null and is_instance_valid(_进图确认层):
		var 旧 := _进图确认层
		_进图确认层 = null
		旧.queue_free()		# 它的 tree_exited 会给**旧** request_id 补一帧「取消」
	var 层 := CanvasLayer.new()
	层.name = "进图确认层"
	层.layer = 400
	add_child(层)
	_进图确认层 = 层
	var 遮罩 := Control.new()
	遮罩.name = "进图确认遮罩"
	遮罩.set_anchors_preset(Control.PRESET_FULL_RECT)
	遮罩.mouse_filter = Control.MOUSE_FILTER_STOP
	层.add_child(遮罩)
	## ⚠️ **不要在进树前 `遮罩.size = ...`**（2026-10-31，用户报「BOSS 提示框不显示、点不了确定」）：
	## 满铺锚点 + 未进树 ⇒ 父区是 0×0，Godot 会把设进来的 960×560 **烘成偏移**（offset_right/bottom
	## = 960/560）；进树后 size = 父区 960×560 **加上**偏移 = **1920×1120**。`弹消息` 按这个双倍尺寸
	## 居中，主体被摆到 (809,509)、确定钮在 (886,576) ⇒ 全在 960×560 的屏幕外，只见右下角一条字。
	## 满铺锚点自己就会跟着视口走，进树那一刻尺寸已经是对的，不需要也不许手动赋值。
	## 每一枚框带自己的状态：被新框顶掉时，旧框的 `tree_exited` 只该答它自己那一帧，
	## 不能把新框的 `_进图确认层` 清掉、更不能拿新 request_id 乱答。
	var 状态 := {"已答": false}
	var 答 := func(接受: bool) -> void:
		if bool(状态["已答"]):
			return
		状态["已答"] = true
		if _进图确认层 == 层:
			_进图确认层 = null
		层.queue_free()
		if _会话 != null:
			_会话.request_portal_panel(request_id, 接受)
	var 框 := 输入确认弹.弹消息(遮罩, 正文, func(选: int) -> void: 答.call(选 == 1))
	## 点暗层会拆框而不回调（`弹消息` 照原版 `showMessageDialog` 没有遮罩点击处理）。
	## 不补这一条 ⇒ 服务端那条挂起要占满 60 秒，这期间所有 Boss 房门请求都被它吞掉。
	框.tree_exited.connect(func() -> void: 答.call(false))
