extends CanvasLayer

const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")
## 悬停提示的样式（§3.105）**只从皮肤表/主题取** —— `变体_提示文字` = 原版 `OrigTooltipText`。
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")	# 追踪栏要怪名/物品名（静态查表）

## 小地图标记的锚点表（生成物，别手改；改逻辑请改 开发工具/出小地图标记表.py）。
## 锚点只能从 `Effect_mapHelper.swf` 的形状框读出来 —— 见 数据/界面/小地图标记.json 的「真值」。
const 标记表路 := "res://数据/界面/小地图标记.json"
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

## 小地图那排里**竞技场那两颗入口钮**的判据来源（`SmallMapButtonBox.as:539-564` / `:391-404`）：
## 显隐读的是常驻单例上的状态（原版 `PvpManager.getInstance()`），不是本帧的局部量 ⇒ 从控制器取。
const 竞技场窗脚本 := preload("res://脚本/界面/窗口/竞技场窗.gd")
## `PvpManager.as:30` `PVP_ENTER_LEVEL = 30`（AS3 客户端那道闸；服务端另按 `Pk.common` 的 45 拦，
## 两边本来就对不上 —— 差异已记 `真值/窗口/竞技场.md` §⑮，未点头前不改任何一边）。
const 竞技场门槛 := 30

## 追踪栏几何。逐条有出处，不是量出来的近似值：
##   追踪面板宽   QuestTrackerWindow.as:130  _width = _background.width（TrackerTitleSKin 175）
##   追踪标题高   QuestTrackerWindow.as:165  _hotRect.y = _background.height
##                （PNG 是 175×23，第 23 行全透明 = ffdec 导出的空边，真身高 22）
##   追踪最大高   QuestTrackerWindow.as:40   MAX_HEIGHT = 180
##   追踪滚动宽   QuestTrackerWindow.as:168  _contentPanel.width = _width - 5
##   追踪行宽     QuestTrackerItemRenderer.as:79/167  _label.width=160 / StructuredText(…,160)
##   追踪行标题高 MLabel.as:57  setSize(0,20)（renderer 只改宽，高留默认 20）
##   追踪行尾空隙 QuestTrackerItemRenderer.as:175  itemHeight = label.height + textHeight + 2
const 追踪面板宽 := 175.0
const 追踪标题高 := 22.0
const 追踪最大高 := 180.0
const 追踪滚动宽 := 170.0
const 追踪行宽 := 160.0
## 正文的换行宽不是 160。StructuredText 的原版机制是两遍排版：
##   第一遍 setTextField() :305-308  _txt.width = 传进来的 160，wordWrap=true
##   量完再 :116-117               _txt.height = textHeight + 10
##                                 _txt.width  = textWidth + 6   ← 改宽会**再换一次行**
## 所以最终换行宽 = 「按 160 排出来的最宽行」+ 6，而行高取的是**第一遍**的行数
## （:116 在 :117 之前，改宽之后没再量高度 —— 原版自己就是这么留的）。
## 这里把「最宽行」按 160 取满，写成固定 166：
## 实测（开发工具/量RTL断行.gd）当前样本按 160 排出来的最宽行是 162，
## 真值应为 168；162 那行的下一个字要 174 宽，166 与 168 都在它前面断开，
## 所以两种取法在现有数据上换行点完全一样。
## 靠这 6px 富余，原版「寻找：[终结谷浅滩]暗部忍者-」收尾那个半角减号才留在第一行。
## 这也解释了 _contentPanel.width = 175 - 5 = 170 为什么比 160 宽出 10。
const 追踪正文富余 := 6.0
const 追踪正文宽 := 追踪行宽 + 追踪正文富余
const 追踪行标题高 := 20.0
const 追踪行尾空隙 := 2.0
## 行距换算：原版 StructuredText.as:23 LEADING=5、:27 FONT_SIZE=12，
## Flash 里 12px 宋体的 textHeight 实测 15（由页签高 19 = textHeight+4 反推），
## 所以一行的推进 = 15 + 5 = 20px。
## 2026-11-01 用户点名「追踪栏字体不够清晰」⇒ 行内字号 12→14（`追踪行字号`）。
## 宋体内嵌点阵覆盖 12..17，14 仍是锐利的点阵（18 起退灰度，见 `字体清晰回归测试`）；
## Godot 14px 的字体高度是 15（量行高.gd 实测），所以 line_separation = 20 − 15 = 5，
## 一行推进仍是**原版的 20px** —— 只让字变大，不让行变高。
const 追踪行字号 := 14
const 追踪行距 := 5
## 「更多可玩内容」—— QuestTrackerWindow.as:178 playMoreTf = new StructuredText(…, _width)
## StructuredText.as:116  _txt.height = textHeight + 10 → 单行高 = 15 + 10 = 25
const 更多可玩内容高 := 25.0
## 文案真值：en_US$message_properties.as:2995 QUEST_TRACKER_KEWAN_NEIRONG
const 更多可玩内容源 := "<font color='#00ff00'><a href='event:moreInfo'>更多可玩内容</a></font>"

## 追踪条（原版 QuestTrackerItemRenderer / QuestTrackerWindow）
const 富文本 := preload("res://素材/界面/任务界面/脚本/原版富文本.gd")

## 类型前缀，真值 en_US$message_properties.as 的 QUEST_TRACKER_ITME_RENDERER_*
## 注意是**半角括号**
## 键 = 原版 QuestInfoData.as:41-57 的 questType 字符串，值 = QuestTrackerItemRenderer.as:83-108
## 各 case 拼在名字前的那段，文案出自 en_US$message_properties.as。
const 追踪类型前缀 := {
	"trunk": "(主线)", "branch": "(支线)", "daily": "(日环)", "weekly": "(周环)",
	"monthly": "(月环)", "loop": "(挂机)", "huodong": "(活动)", "mixin": "(护送)", "banghui": "(家族)",
}
const 接任务前缀 := "任务接取："
const 回复任务前缀 := "任务回复："
## 已接/已完成时正文按类型追加的那一段（QuestTrackerItemRenderer.as:131-163）。
## 注意周环用的是「降低任务难度与提升奖励回报」，且 href 也是 event:daily。
const 周环降难度 := "<font color='#00ff00'><a href='event:daily'>降低任务难度与提升奖励回报</a></font>"
const 日环立即完成 := "<font color='#00ff00'><a href='event:daily'>立即完成</a></font>"
const 家族立即完成 := "<font color='#00ff00'><a href='event:familly'>立即完成</a></font>"
## 接取/回复行里的 NPC 名：原版链接是写死的 "findNpc"（:25 `NPC = "findNpc"`），
## 目标 id 不在 href 里，而在渲染器的 _findNpc 字段（:123/:146），点击时再取。
const 找NPC链接 := "event:findNpc"
## 击败类目标的链接：`event:mob<地图id>:<怪模板>`。原版点正文是走
## `QuestDataManager:489 → getQuestPoint() → gotoMonsterPoint(2, 序号, 图)`，
## 本工程把「图 + 怪」直接编进 href，点击处不用再回表查。
const 打怪链接 := "event:mob"
const 跨图寻路脚本 := "res://脚本/地图/跨图寻路.gd"
const 实体脚本 := preload("res://脚本/地图/地图实体.gd")	# 只借它那份 可对话横距/纵距常数
## 右上角那块任务提示条（原版 `MessageTipPane2`）——两档语义全在它里面。
const 提示条 := preload("res://脚本/界面/提示条面板.gd")
## 主界面左上角那枚连斩计数（原版 `LianZhanMC`），由 1291:1 驱动。
const 连斩面板 := preload("res://脚本/界面/连斩面板.gd")

## 右下角那列「获得提示」（原版 `NoticePnl`）：经验/金币/点券/道具……一切增减。
const 获得提示层 := preload("res://脚本/界面/获得提示层.gd")

var _追踪表: Dictionary = {}
var _追踪定义: Dictionary = {}
var _追踪悬停 := ""
var _追踪按下 := ""

var _session: Node
var _player: Node2D
var _map_data := {}
var _map_name: Label
var _map_coordinates: Label
var _minimap: MinimapCanvas
var _minimap_panel: Control
var _minimap_content: Control
var _minimap_expanded := true
var _shield_selected := false
var _voice_selected := false
var _activity_button: TextureButton
## 小地图左边那颗活跃度图标的呼吸光晕（`SmallMapWindow._huoyueduBtn` 的 GlowFilter）。
## 本工程把它烘成了 AnimatedTexture，所以「有没有在闪」= 这颗节点的 `visible`。
var _活跃度光晕: TextureRect
var _gift_button: TextureButton
var _info_button: TextureButton
var _shield_button: TextureButton
var _voice_button: TextureButton
var _竞技场钮: TextureButton
var _排名奖钮: TextureButton
var _quest_list: VBoxContainer
var _quest_tracker: Control
var _quest_content: Control
var _quest_expand_button: TextureButton
var _quest_accepted_button: Button
var _quest_available_button: Button
var _quest_play_more: RichTextLabel
var _quest_expanded := true
var _quest_show_accepted := true
## 旧「单格假气泡」**已退役**（§3.106，作者 §11-3）。这三件原来是**场景里的 Label 节点**
## （`小地图区域/原版NPC对话/…`），新窗 `NPC对话窗` 只把它们**当台词源**读一下
## （`_对话.显示(id, _dialog_name, _dialog_text, …)`）⇒ 改成普通 String 把**来源**留下，
## 节点本体连同那棵子树一起从场景里删掉（那两枚按钮本来就是死的）。
var _dialog_name := ""
var _dialog_title := ""
var _dialog_text := ""
var _dialog_npc_id := ""
var _dialog_action_page := ""
var _toast: Label
var _backend: Node
var _提示条: Control
var _获得提示层: Control
var _连斩面板: Control = null
var _标记秒表 := 0.0

func _ready() -> void:
	_追踪表 = 富文本.建表()
	_追踪定义 = _读任务定义()
	transform = Transform2D.IDENTITY
	_session = get_node_or_null("/root/GameSession")
	_backend = get_node_or_null("/root/BackendConnection")
	if _backend != null:
		_backend.npc_dialog_received.connect(_on_backend_npc_dialog)
		_backend.quest_accepted.connect(_于任务接上)
		_backend.quest_progress_received.connect(_于环任务数据)
		_backend.quest_completion_shown.connect(_于任务交付)
		## 活跃度状态（`2326`）一变就重算光晕：原版 `ActivityTaskManager.updateOneItem` /
		## `updateGotLevel` 都是在收到帧之后直接调 `setHuoyueduBtn`。
		_backend.activity_state_received.connect(_于活跃度状态)
		## 右下角那列「获得提示」（原版 `NoticePnl`）的数据源在 `后端连接`（差值只有它算得出），
		## 画在这一层。原版这块挂在 `API.ui.content`（= 整块 HUD），本工程 HUD 跟着地图场景走，
		## 所以**换图会把还挂着的一列清掉**（原版不清）—— 差异记在 #174 的未决里。
		## ⚠ 用 `connect("获得提示", …)` 的通用写法：`_backend` 是 `Node` 型，
		##   写成 `_backend.获得提示.connect` 编译期找不到这个信号名会直接 parse 失败。
		if _backend.has_signal("获得提示"):
			_backend.connect("获得提示", _于获得提示)
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_map_data = _load_map_data()
	var map_root := get_node("小地图区域") as Control
	_bind_map_ui(map_root)
	## 提示条层：原版这些条挂在 `API.ui.content`（= 整块 HUD）上，不在任何一扇窗里。
	_提示条 = 提示条.new()
	add_child(_提示条)
	_提示条.确定点击.connect(_于提示条确定)
	## 获得提示层（`NoticePnl`）：自己按视口尺寸摆位（原版 x=W-250、y=H-125），宿主只管挂上。
	_获得提示层 = 获得提示层.new()
	add_child(_获得提示层)
	## 连斩计数（原版 `LianZhanMC`）：挂在 `API.ui.content`（整块 HUD）、摆位 x=200 y=36、默认隐藏；
	## 本工程 HUD 跟着地图场景走 ⇒ 换图会把它清掉（与 #177 同族，这里不另开一层）。
	_连斩面板 = 连斩面板.new()
	add_child(_连斩面板)
	if _backend != null and _backend.has_signal("lianzhan_count_changed"):
		_backend.connect("lianzhan_count_changed", _于连斩数)
	_connect_session()
	_refresh_all()


## 一行「获得提示」上屏（原版 `noticePnl.addNotice(htmlText)` 的那一下）。
func _于获得提示(文本: String) -> void:
	if _获得提示层 != null and is_instance_valid(_获得提示层):
		_获得提示层.call("加一条", 文本)

## 跨图赶路的"待进门"：走到门口站定后才发进门包（原版 `MovePlayerToMap` 也是先走路再触发门）。
## `{"index": 门序号, "位": 世界坐标, "图": 目标图}`；空 = 没在赶路。
var _待进门 := {}
## —— 多跳跨图自动赶路（原版 `KeyController` 的 `_aryMapJoint` + `_nowMapJointIndex` +
## `_nowWalkingToMap` + `movingtoLifeId` 四件套，本工程摊成下面五个）——
## 路线 = `脚本/地图/跨图寻路.gd`（原版 `MapPathFinder.getPath`）算出来的"依次走哪几扇门"。
var _跨图余程: Array = []		# 还没走的那几跳，第 0 跳 = 当前这一跳
var _跨图终点图 := 0			# 最终要到的那张图（跳走完了由它决定"到点干什么"）
var _跨图终目标 := {}			# 到了之后要做的事 {"类":"n"/"m","号":int,"说明":String}
var _跨图上图 := 0				# 上一次看到的图号，变了就说明刚换完图 ⇒ 接着走下一跳
var _跨图在途 := false			# 有一趟跨图行程在进行（含"本图就有直达门"那一跳）
var _跨图起手印 := 0			# 出发时 `玩家.auto_path_cancel_stamp` 的值，变了 = 玩家手动取消过
## ⚠ 这个印**只能在同一个玩家实例上比**：换图会把玩家节点重建，新实例的印从 0 重新开始，
##   拿去跟旧实例留下的数字比就会**一到目标图就被误判成"手动取消"**（2026-10-10 用户实机报的
##   "寻路到地图2就不动了" 正是这条）。⇒ 记下当前这个玩家，换了人就重新对表，不算取消。
var _跨图玩家: Node2D
var _跨图等到 := 0.0			# 到终点图后等 NPC 刷出来的秒数（原版每拍重试 `canTalkToNpc`）
var _跨图总跳数 := 0			# 这趟一共几跳（报"第几跳"用）
var _跨图接过 := false			# 本实例有没有从会话接手过路线（每个 HUD 实例只接一次）
## 走到 NPC 跟前之后要自动开对话（原版 `KeyController.as:211-227` 的 `movingtoLifeId`）：
## 原版 `pathFind(x, y, lifeId, forceToStop, showTip)` 把 lifeId 一路带在寻路对象里，
## 走完那一帧（`_aryJoint` 走完）拿它反查 object_id ⇒ `talkToNPC` + `requestNPCTalk`(54)
## + `directionNPC`。**只有带 lifeId 的那次寻路**到点才发对话包 —— 点小地图、手动走路不会。
## ⚠ 这里以前写着"原版走到跟前不会再自动开对话"，那句是错的（当时 `pathFind` 根本没传 lifeId）。
var _待对话NPC := ""
## 起这条 NPC 路线那一刻，玩家身上 `auto_path_arrive_stamp` 的值。
## 兑现条件 = **路线真的走完**（印变大，原版 `KeyController.as:212` 的"路径关节走完"），
## 不是"停下来时离得够近"：失落秋千那种挂在半空的 NPC（数据 y=431 / 脚下平台 482，
## 纵差 51 ≥ 可对话纵距 50）人永远走不到 50 以内 —— 拿距离当闸会让这类 NPC 静默不弹。
var _待对话起点印 := 0
## 「到点自动开对话」真兑现了几次。
## 为什么要它：取消（打断）与兑现都会把 `_待对话NPC` 清空，光看那个字段分不开这两条路，
## 于是"停下来才弹"这条时机契约没法测（10-10 门里就这么假红过一次）。
var 到点对话次数 := 0
## 任务完成横幅（原版 `API.stage.addChild(ByteArrayImage)` + ENTER_FRAME 计时）。
## 同一时刻只挂一枚：再交付一个任务就重来一遍（原版也是各挂各的，但同屏叠两张会糊）。
var _横幅: Node2D
var _横幅秒表 := 0.0
## 「自动寻路中．．．」—— 原版 `KeyController.PathFindingTip`（`:781-791`）：
## `MCFromDatDefine("Effect_PathFindingTip")` + `autoTick=true` + `fps=40` + 不吃鼠标，
## 挂在 **`API.stage`**（不是窗口层）的 `x = Config.STAGE_WIDTH/2, y = 110`（`:996-1000`）。
## 40 帧时间轴、每帧 25ms ⇒ 1 秒一圈，省略号是**逐帧动画**不是文本。
## 图与注册点由 `开发工具/出任务标记特效.py` 从钉住的 `Effect_PathFindingTip.swf` 现读，进 `数据/特效.json`。
const 寻路提示特效 := "Effect_PathFindingTip"
const 寻路提示y := 110.0
var _寻路提示: Node2D
var _寻路提示已连 := false


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	_接寻路提示()
	if not _待进门.is_empty() and _player != null:
		# 站定（走向 已停）且离门口够近 ⇒ 进门。超过 6 秒还没到就放弃，别一直挂着。
		_待进门["等"] = float(_待进门.get("等", 0.0)) + _delta
		var 近 := _player.global_position.distance_to(_待进门["位"] as Vector2)
		var 停 := not bool(_player.get("click_move_active"))
		if (近 <= 260.0 and 停) or float(_待进门["等"]) > 12.0:
			var 后端 := get_node_or_null("/root/BackendConnection")
			_跨图记("发进门包 index=%s 去 %s 差 %.0f" % [str(_待进门.get("index")), str(_待进门.get("图")), 近])
			if 近 <= 420.0 and 后端 != null and 后端.has_method("request_portal_enter"):
				后端.call("request_portal_enter", int(_待进门["index"]))
				show_notification("已进入《%s》" % _地图名(int(_待进门["图"])))
			else:
				show_notification("没走到传送点（差 %.0f），到门口再点一次" % 近)
			_待进门 = {}
	## 换图完成的判据 = `_本图号()` 变了（服务端权威图号，`map_changed` 那条走的是场景重载，
	## 这里轮询比接信号稳：HUD 不被重建，而玩家节点每换一张图就重建一次）。
	## 换图 ⇒ 旧 HUD 被释放、新 HUD 起来（路线在会话里，这里只负责接手与写回）。
	if not _跨图接过:
		_跨图接过 = true
		if _session != null and bool(_session.get("跨图在途")):
			_跨图在途 = true
			_跨图余程 = (_session.get("跨图余程") as Array).duplicate(true)
			_跨图终目标 = (_session.get("跨图终目标") as Dictionary).duplicate(true)
			_跨图终点图 = int(_session.get("跨图终点图"))
			_跨图等到 = float(_session.get("跨图等到"))
			_跨图上图 = _本图号()		# 接手时人已经在新图上了，别再当成"刚换完图"
			_跨图记("新面板接手：余程 %d 跳 终目标 %s" % [_跨图余程.size(), str(_跨图终目标)])
			_跨图玩家 = null			# 新玩家实例 ⇒ 第一拍走"重新对表"那一支
	if _跨图在途 and _player != null:
		## 原版形状：`isDownMoveKey() && _nowPathFinding ⇒ stopPathFind()`（`KeyController.as:1205-1212`），
		## 而 `stopPathFind()` 把跨图那包**一起清**（`:1577-1590`）⇒ 手动一走 / 出一招，整趟取消。
		## 只清"跨图带来的"那个待进门，同图点地走留下的待进门不归这里管。
		if _跨图玩家 != _player:
			## 换图把玩家节点重建了 ⇒ **重新对表**（这不是取消）。顺带清掉上一张图残留的待进门。
			_跨图玩家 = _player
			_跨图起手印 = int(_player.get("auto_path_cancel_stamp"))
			_待进门 = {}
			_跨图记("换了玩家实例 ⇒ 重新对表（不算取消）")
			_续跨图()
		## 判"玩家自己插手"就照原版那条**触发条件**来：`isDownMoveKey() && _nowPathFinding`
		## （`KeyController.as:1205-1212`）—— 按着方向键/跳/出招键才算他取消。
		## ⚠ 以前这里判的是"角色的取消计数变了/变大了"，而实机日志（跨图实机.log）证明
		##   **发进门包那一帧计数自己 +1**（进门要把当前路线停掉），于是每一趟都在
		##   踏进门的那一刻被当成"玩家手动取消"清掉 —— 这就是用户三次打回的那个"到图就不动"。
		elif _玩家自己在动():
			_跨图记("判成手动取消（玩家按着移动/跳跃/攻击键）")
			if bool(_待进门.get("跨图", false)):
				_待进门 = {}
			_清跨图()
		elif _跨图余程.is_empty():
			## 已经在终点图上：这图的 NPC 是服务端**逐枚生成包**推来的（`Client.as:6467`），
			## 换图那一瞬间常常还没有 ⇒ 原版是每拍重试（`KeyController.as:164-186` 查 `canTalkToNpc`），
			## 不是找不到就判死。等过头 15 秒再说一句，别无声挂着。
			_跨图等到 += _delta
			if _跨图等到 > 15.0:
				show_notification("到了《%s》但 15 秒没等到要见的那个人（再点一次追踪栏那行）" % _地图名(_跨图终点图))
				_清跨图()
			else:
				_续跨图()
		else:
			var 在图 := _本图号()
			if 在图 > 0 and 在图 != _跨图上图:
				_跨图上图 = 在图
				_续跨图()
	if not _待对话NPC.is_empty() and _player != null:
		## ⚠ 触发时机 = **路线走完（人停下来）之后**，不是"一进距离"。
		## 原版 `KeyController.as:212` 那一支的条件是 `_aryJoint.length < _nowJointIndex + 1`
		## （路径关节走完）才 `talkToNPC` + `requestNPCTalk` + `directionNPC`；
		## 而中途打断走的是 `:196-211` 那一支 —— 清掉 `movingtoLifeId` 且**不说话**。
		## 两条都会让 `click_move_active` 变假 ⇒ 另看 `auto_path_arrive_stamp`（只认走完）来分开。
		## **不许**改用「停 + 横100/纵50」那道距离闸：原版这条支路没有距离条件，而
		## 失落秋千（`数据/地图/木叶村/地图.json` life 21：y=431，脚下平台 482）纵差 51，
		## 照距离判就永远差 1 像素不弹（2026-10-26 用户实机"卡在失落秋千"）。
		if not bool(_player.get("click_move_active")):
			var 实体 := _找本图NPC(_待对话NPC)
			var 号 := _待对话NPC
			var 走到头 := int(_player.get("auto_path_arrive_stamp")) > _待对话起点印
			_待对话NPC = ""
			_待对话起点印 = 0
			if 实体 != null and 走到头:
				_到点开对话(号)
	if _跨图在途:
		_写回跨图()		# 换图会杀掉本实例，路线得一直在会话里留着
	_走横幅(_delta)
	if _minimap != null:
		_标记秒表 += _delta
		if _标记秒表 >= 0.5:
			_标记秒表 = 0.0
			_刷标记()	# 场上 NPC 是服务端逐枚生成包推来的（Client.as:6467），没有"变了"信号可接
	if _map_coordinates != null and _player != null:
		## 原版 `"[" + Math.floor(x/100) + ", " + Math.floor(y/100) + "]"`
		## （SmallMapWindow.as:437）—— **向下取整**、逗号后**有一个空格**。
		## ⚠ 用 `floori` 不用 `int()`：`int()` 是**朝零取整**，而 AS3 的 `Math.floor` 朝负无穷取整 ——
		## 地图纵坐标本来就是负的（终结谷浅滩 VRTop = −100），y 在 (−100,0) 这一段两者会差 1。
		_map_coordinates.text = "[%d, %d]" % [floori(_player.global_position.x / 100.0), floori(_player.global_position.y / 100.0)]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var 吃了 := false
		# （旧假气泡那半截已随 §3.106 退役；只剩新窗这一支）
		if _对话 != null and _对话.is_visible_in_tree():
			# 原版 ESC = `__clickStageHandler` ⇒ 发 `NPC_TALK_MORE_EX(CLOSE,-1)` 让服务端
			# 清掉那半截作者对话（**不**结算任务）。只关窗不发帧的话，服务端还留着
			# `active_quest_dialog_*`，下次点同一枚 NPC 会从半截继续翻。
			_对话.call("离开")
			吃了 = true
		if 吃了:
			get_viewport().set_input_as_handled()

func show_npc_dialog(npc_id: String, server_message := "") -> void:
	if _session == null:
		return
	var info: Dictionary = _session.call("get_npc_info", npc_id)
	_dialog_name = String(info.get("name", "NPC"))
	_dialog_title = String(info.get("title", ""))
	_dialog_npc_id = npc_id
	_session.call("complete_npc_talk", npc_id)
	var quest: Dictionary = _session.call("get_npc_quest_info", npc_id)
	_dialog_text = _format_npc_quest(quest) if not quest.is_empty() else (server_message if not server_message.is_empty() else String(info.get("dialogue", "……")))
	var service := String(_session.call("get_npc_service", npc_id))
	_dialog_action_page = ""
	if not quest.is_empty():
		_dialog_action_page = "任务"
	# 菜单只认服务端 328 帧里那一段（原版 `_data.menu`）；没收到帧就按原版空菜单画两格。
	var 菜单: Array = []
	var 选择: Array = []
	var 后端: Node = get_node_or_null("/root/BackendConnection")
	if 后端 != null:
		菜单 = (后端.last_npc_dialog as Dictionary).get("menu", []) as Array
	## **剧情面**：328 帧第 4 段 `playerText` = 原版 `data.text`。有它就走
	## `QuestDialog.drawView():393-395` 的 `createPlayerTextArea()` 分支 ——
	## 下格只有那一行绿色玩家回应，**菜单行与任务链接一概不建**（所以"交易按钮不见了"
	## 不是 hide，是这条分支根本不建）。点下格发 `57:NEXT:1` 翻下一句。
	var 回应 := ""
	if 后端 != null:
		回应 = String((后端.last_npc_dialog as Dictionary).get("player_text", ""))
	if 回应 == "-":
		回应 = ""		# 本机服务端用 `-` 表示"没有可选回应"（`_send_npc_dialog`）
	if 回应 != "":
		_对话.显示(int(npc_id), _dialog_name, _dialog_text, [], [], 回应)
		return
	if not 菜单.is_empty() and 后端 != null:
		# 帧里的 selection 段（第 6 段）**不是菜单行**：原版把它拼成一块居中富文本链接
		# （`QuestDialog.as:249-345`）⇒ 交给对话窗的 `选择` 参数，别混进 菜单。
		# 值仍是 Callable ⇒ 本地开页，**不发 57:2 也不发 57:3**（那条包会改任务状态）。
		for t in ((后端.last_npc_dialog as Dictionary).get("selection", []) as Array):
			选择.append(_选择条目(t as Dictionary))
	if 菜单.is_empty():
		# 还没收到 328 的 menu 段（离线门、或这版服务端只发 325 普通对话）时，
		# **不许凭感觉凑菜单**：按服务端同一套组装规则现算的表取
		# （`数据/界面/木叶村NPC.json`，规则出处 `fake_flash_server.py:52314-52330`）
		# ⇒ 离线点每枚 NPC 与在线是同一张菜单、同一批动作值。
		菜单 = NPC菜单行(npc_id)
		选择 = NPC选择行(npc_id)
	if 菜单.is_empty() and 选择.is_empty():
		# 表里也没有这枚（夹具用的 00000001/00000002 不在木叶村）⇒ 才用旧的本机入口凑。
		# 动作值给 Callable ⇒ 对话窗走本地跳转，**不发** 57 那个协议包。
		if not quest.is_empty():
			菜单 = [["打开任务", func(): _session.request_feature("任务")]]
		elif not service.is_empty():
			菜单 = [["打开%s" % service, func(): _session.open_npc_service(_dialog_npc_id)]]
		菜单.append(["离开", func(): pass])
	_对话.显示(int(npc_id), _dialog_name, _dialog_text, 菜单, 选择)

func _format_npc_quest(quest: Dictionary) -> String:
	return "[%s] %s\n%s（%s）" % [
		quest.get("type", "任务"),
		quest.get("name", "未命名任务"),
		quest.get("description", "暂无任务说明"),
		quest.get("npc_status", ""),
	]

func _on_backend_npc_dialog(npc_id: int, message: String) -> void:
	show_npc_dialog("%08d" % npc_id, message)

func show_notification(message: String) -> void:
	_toast.text = message
	_toast.visible = true
	_toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_toast, "modulate:a", 1.0, 0.12)
	tween.tween_interval(1.6)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): _toast.visible = false)

func _bind_map_ui(root: Control) -> void:
	_minimap_panel = root.get_node("小地图") as Control
	_minimap_content = root.get_node("小地图/小地图内容槽") as Control
	_map_name = root.get_node("小地图/地图名") as Label
	_map_coordinates = root.get_node("小地图/坐标") as Label
	var minimap_slot := _minimap_content
	_minimap = MinimapCanvas.new()
	_minimap.name = "RuntimeMinimapCanvas"
	## 视口尺寸是 AS3 常数（SmallMapWindow.as:55-61），**不是**跟着槽的大小走 ——
	## 画布自己 clip_contents（= 原版的 _mapPanel.mask），尺寸给错就等于裁错。
	_minimap.size = Vector2(MinimapCanvas.视口宽, MinimapCanvas.视口高)
	_minimap.标记表 = _读标记表()
	_minimap.玩家 = func(): return _玩家世界位()
	_minimap.点了寻路.connect(_点小地图寻路)
	minimap_slot.add_child(_minimap)
	_接地图()
	_quest_tracker = root.get_node("任务追踪") as Control
	_quest_content = root.get_node("任务追踪/任务内容区") as Control
	_quest_accepted_button = root.get_node("任务追踪/当前任务页签") as Button
	_quest_available_button = root.get_node("任务追踪/可接任务页签") as Button
	_quest_expand_button = root.get_node("任务追踪/折叠钮") as TextureButton
	_quest_list = root.get_node("任务追踪/任务内容区/任务列表") as VBoxContainer
	_quest_play_more = root.get_node("任务追踪/更多可玩内容") as RichTextLabel
	_绑更多可玩内容()
	_quest_accepted_button.pressed.connect(func(): _select_quest_tab(true))
	_quest_available_button.pressed.connect(func(): _select_quest_tab(false))
	_绑页签(_quest_accepted_button)
	_绑页签(_quest_available_button)
	_quest_expand_button.pressed.connect(_toggle_quest_tracker)
	_绑三态(_quest_expand_button)
	_刷新折叠钮图形()	# 初始 _quest_expanded=true；这一步同时把当前态那组三态皮肤挂上
	_bind_minimap_buttons(root)
	_bind_activity_buttons(root)
	_select_quest_tab(true)
	_bind_fixed_overlays(root)

## 原版 setCurrentBtn()（QuestTrackerWindow.as:251-259）把**选中的那一页**设成
## `enabled = false`；MButton3.updateState() 在 STATE_DISABLED 时推的是
## StyleUtil.getGrayFilter()（灰化），而不是换一套颜色 ——
## 所以「当前页」看到的是灰掉的渐变。
## selectedUpSkin 那对 #ECEC4C→#B3B333 在本窗口里从没显示过（_selected 全程 false）。
func _select_quest_tab(show_accepted: bool) -> void:
	_quest_show_accepted = show_accepted
	if _quest_accepted_button == null or _quest_available_button == null:
		return
	_设页签选中(_quest_accepted_button, show_accepted)
	_设页签选中(_quest_available_button, not show_accepted)
	# 原版 selectedTabHandler()（:541-557）：点「可接任务」才 visible=true，点回「当前任务」置 false
	if _quest_play_more != null:
		_quest_play_more.visible = not show_accepted
	_refresh_quest_list()


## 原版 playMoreTf（QuestTrackerWindow.as:178-182）：一条 StructuredText，
## 挂在窗口上而不是 _hotRect 里 —— 收起列表时它照样显示。
## 点击走 onClickPlayMoreTf(:429) → ActivityWindowEvent.REQUEST_DATA，
## 等价于本项目的 request_feature("活动")，与小地图上的「活动」按钮同一入口。
func _绑更多可玩内容() -> void:
	if _quest_play_more == null:
		return
	_quest_play_more.set_meta("src", 更多可玩内容源)
	_quest_play_more.set_meta("ns", "M")
	_追踪正文重绘(_quest_play_more)
	_quest_play_more.meta_hover_started.connect(_追踪悬停开始.bind(_quest_play_more))
	_quest_play_more.meta_hover_ended.connect(_追踪悬停结束.bind(_quest_play_more))
	_quest_play_more.meta_clicked.connect(_追踪链接点击)
	_quest_play_more.gui_input.connect(_追踪按键.bind(_quest_play_more))

func _设页签选中(钮: Button, 选中: bool) -> void:
	钮.disabled = 选中
	var m := 钮.material as ShaderMaterial
	if m != null:
		m.set_shader_parameter("gray_amount", 1.0 if 选中 else 0.0)
	# 原版 MButton3.updateState() 在 DISABLED 时是**整份替换** skin.filters，
	# 悬停那层加亮滤镜会被灰化滤镜顶掉 —— 所以选中后必须把亮度复位。
	_页签亮度(钮, false, false)

## 原版 StyleUtil.skinFilters = {up:0, over:+30, down:-40}，
## getLightFilter 是**加性**亮度偏移（ColorMatrix 第 5 列，单位 0~255）。
## 这里用等比 self_modulate 近似 —— 乘法还顺带保证黑描边不会被一起提亮。
## 选中页 disabled 后收不到鼠标事件，与原版 removeMouseEventLisener() 一致。
const 页签悬停亮 := 1.0 + 30.0 / 255.0
const 页签按下亮 := 1.0 - 40.0 / 255.0

func _绑页签(钮: Button) -> void:
	# 两个页签的皮肤是 StyleBoxEmpty_quest_tab_text（下边距 4）：4.7 的 Button 没有
	# vertical_alignment，文字恒居中，下边距是把墨迹从第 7 行抬到原版第 5 行的唯一旋钮。
	# 逐像素依据见 开发工具/量追踪页签基线.py 的 docstring。
	# 场景里两个页签共用同一份 ShaderMaterial，直接改 uniform 会互相串台 → 各拿一份副本
	钮.material = (钮.material as ShaderMaterial).duplicate()
	钮.mouse_entered.connect(_页签亮度.bind(钮, true, false))
	钮.mouse_exited.connect(_页签亮度.bind(钮, false, false))
	钮.button_down.connect(_页签亮度.bind(钮, true, true))
	钮.button_up.connect(_页签亮度.bind(钮, true, false))

func _页签亮度(钮: Button, 悬停: bool, 按下: bool) -> void:
	var v := 页签按下亮 if 按下 else (页签悬停亮 if 悬停 else 1.0)
	钮.self_modulate = Color(v, v, v, 1.0)

## 追踪栏滚到哪儿了（`任务内容区` 是 ScrollContainer，对应原版 QuestTrackerWindow 的 ScrollPane）。
## 列表每收到一次任务帧就整段重建；不记这一位的话，玩家滚到交付 NPC 那一行、下一帧就被顶回顶部。
var _quest_scroll := 0


func _refresh_quest_list() -> void:
	if _quest_list == null:
		return
	if _quest_content is ScrollContainer:
		_quest_scroll = int((_quest_content as ScrollContainer).scroll_vertical)
	for child in _quest_list.get_children():
		_quest_list.remove_child(child)
		child.free()
	if _session == null:
		return
	var 未接: Array = _session.call("get_available_quests")
	var 已接列表: Array = _session.call("get_accepted_quests")
	# 每项 = [任务字典, 是否已接]。状态是**每条任务自己的**（原版 QuestInfoData.status），
	# 不是页签的 —— 「当前任务」页插进来的那几条是未接的，标题得走蓝色、正文得是「任务接取：」。
	var 列表: Array = []
	if _quest_show_accepted:
		# drawListNow() :354-368：「当前任务」页会把**还没接**的主线 / 日环·周环·家族 /
		# 活动 / 护送插到最前面 —— 这几类是必须做的，没接也要在追踪栏里催着去接。
		var 前置: Array = []
		for q in 未接:
			if q is Dictionary and _追踪必做(q as Dictionary):
				前置.append(q)
		_按等级排(前置)
		for q in 前置:
			列表.append([q, false])
		var 排: Array = 已接列表.duplicate()
		_按等级排(排)
		for q in 排:
			列表.append([q, true])
	else:
		for q in 未接:
			列表.append([q, false])
	for value in 列表:
		if value[0] is Dictionary:
			_quest_list.add_child(_create_quest_renderer(value[0], bool(value[1])))
	if _quest_content is ScrollContainer:
		(_quest_content as ScrollContainer).set_deferred("scroll_vertical", _quest_scroll)
	_刷新追踪高度()


## 原版 sortComprareFun（:280-299）先按 category.order 再按 requestLevel。
## category.order 在 数据/任务.json 里没有对应字段（未导出），这里只能按等级排。
func _按等级排(列表: Array) -> void:
	列表.sort_custom(func(a, b): return int(a.get("request_level", 0)) < int(b.get("request_level", 0)))


## QuestTrackerWindow.as:358 那个 if：TRUNK / isLoopQuest() / HUODONG / isHuSongQuest()。
## isLoopQuest = daily|weekly|banghui（QuestInfoData.as:220-234），
## isHuSongQuest = mixin（:1016-1024，HUSONG_QUEST 的字符串值就是 "mixin"）。
func _追踪必做(quest: Dictionary) -> bool:
	return _追踪类型(quest) in ["trunk", "daily", "weekly", "banghui", "huodong", "mixin"]


## 类型串以原版词表为准（QuestInfoData.as:41-57）。运行时段子可能带的是旧的中文标签，
## 那种情况回落到任务定义表的 info.type —— 它是从原版 GameData.dat 直接导出来的真值。
func _追踪类型(quest: Dictionary) -> String:
	var 动 := String(quest.get("type", ""))
	if 追踪类型前缀.has(动):
		return 动
	var 定 := _追踪定义条(quest)
	var 信: Variant = 定.get("info", {})
	if 信 is Dictionary:
		var 静 := String((信 as Dictionary).get("type", ""))
		if not 静.is_empty():
			return 静
	return 动

func _create_quest_renderer(quest: Dictionary, 已接: bool) -> VBoxContainer:
	# 原版 QuestTrackerItemRenderer.drawItem()：
	#   标题行 _label(MGlowLabel) = "[等级]" + "(类型)" + 名称，颜色按状态
	#                    未接=UI_BLUE(#1e90ff) 已接=UI_WHITE(#ffffff) 已完成=UI_GREEN(#00ff00)
	#                    日环/周环再强制刷成 UI_BLUE
	#   正文行 _requireField = StructuredText，外层 <font color='#ffffff'>，y = 标题高
	#                    → **正文里的名字是链接**，悬停变红 #FF0000、可点击
	#   原版整行**没有任何背景**（背景是整块面板的 drawTrackerBg 渐变），
	#   所以这里不能给每行铺贴图；行尾留 2px = itemHeight 里的那个 +2。
	var item := VBoxContainer.new()
	item.custom_minimum_size = Vector2(追踪行宽, 0.0)
	# ScrollPane 宽 170，但渲染器本身只有 160（_label.width=160 / StructuredText(…,160)），
	# 且挂在 _list 的 x=0。VBox 默认会把子节点拉满父宽 → 不锁的话正文会在 170 处才换行，
	# 换行点比原版晚一个多字，整块高度也跟着多撑一行。
	item.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_constant_override("separation", 0)

	var 完成 := bool(quest.get("completed", false))
	var 定 := _追踪定义条(quest)

	# ---- 标题行 ----
	var 类 := _追踪类型(quest)
	var 标题色 := Color("#1e90ff") if not 已接 else (Color("#00ff00") if 完成 else Color("#ffffff"))
	# :165-168 日环/周环不分状态，标题一律刷回 UI_BLUE
	if 类 == "daily" or 类 == "weekly":
		标题色 = Color("#1e90ff")
	var title := _label(Vector2.ZERO, Vector2(追踪行宽, 追踪行标题高), 追踪行字号, 标题色)
	title.custom_minimum_size = Vector2(追踪行宽, 追踪行标题高)
	## 运行期条目（444 折出来的）只有 id/状态/进度，名字与等级必须回落到**定义表**：
	## 名字在 `定.info.name`、等级在 `定.check["0"].lvmin`。以前写的是 `定.get("name")`
	## （定义表根上没有这个键）⇒ 所有在线任务标题都显示「任务」、等级恒 0
	## （2026-10-26 用户截图 `[0](主线)任务` 就是这条）。
	var 信: Dictionary = 定.get("info", {}) as Dictionary
	var 阶零: Dictionary = (定.get("check", {}) as Dictionary).get("0", {}) as Dictionary
	title.text = "[%d]%s%s" % [
		int(quest.get("request_level", 阶零.get("lvmin", 0))),
		String(追踪类型前缀.get(类, "(%s)" % 类)),
		String(quest.get("name", 信.get("name", "任务"))),
	]
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	# 2026-11-02 用户实机报「任务面板内字体模糊，可能需要去掉字体阴影」⇒ 这块**不留描边**。
	# 原版两处确实挂了黑 GlowFilter：标题是 `MGlowLabel`（构造里 blur 3 / strength 6），
	# 正文是 `QuestTrackerItemRenderer.as:168` 的 `getGlowFilter()`（blur 2 / strength 10）。
	# 但 Flash 那是**柔和外发光**；14px 宋体点阵（§3.358 放大的字号）外面再套 2px 实心黑描边，
	# 笔画边缘一圈全黑，看起来就是"糊"。这里是用户点头的偏离 —— 显式压 0；
	# ⚠️ 不能只删 override：`原版主题.tres` 里 Label/Button 默认就烘着 outline_size=2。
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	title.add_theme_constant_override("outline_size", 0)
	item.add_child(title)

	# ---- 正文行（富文本，可点链接）----
	var body := RichTextLabel.new()
	body.custom_minimum_size = Vector2(追踪正文宽, 0.0)
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	body.add_theme_color_override("default_color", Color.WHITE)
	# 同标题行：不描边（原版那层 GlowFilter 在 14px 点阵上只会让笔画发糊）。
	body.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	body.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	body.add_theme_constant_override("outline_size", 0)
	body.add_theme_constant_override("line_separation", 追踪行距)
	body.add_theme_font_size_override("normal_font_size", 追踪行字号)
	body.set_meta("src", _追踪正文源(quest, 已接, 完成, 定))
	body.set_meta("ns", "T%s" % String(quest.get("id", "")))
	body.set_meta("find_npc", _追踪回复NPC(quest, 定) if 完成 else _追踪接取NPC(quest, 定))
	body.set_meta("done", 完成)
	body.set_meta("quest_id", int(quest.get("id", 0)))
	_追踪正文重绘(body)
	body.meta_hover_started.connect(_追踪悬停开始.bind(body))
	body.meta_hover_ended.connect(_追踪悬停结束.bind(body))
	body.meta_clicked.connect(_追踪链接点击.bind(body))
	body.gui_input.connect(_追踪按键.bind(body))
	item.add_child(body)

	# 原版行与行之间没有间隔线，itemHeight 末尾那个 +2 就是唯一的空隙
	var 尾隙 := Control.new()
	尾隙.custom_minimum_size = Vector2(追踪行宽, 追踪行尾空隙)
	尾隙.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(尾隙)
	return item


## 正文行的原版标记串（未转换）
func _追踪正文源(quest: Dictionary, 已接: bool, 完成: bool, 定: Dictionary) -> String:
	var s := ""
	var 类 := _追踪类型(quest)
	if not 已接:
		# 未接：任务接取：<a href='event:findNpc'>NPC</a>（:123-125）
		s = 接任务前缀 + _找NPC链接(_追踪接取NPC(quest, 定))
	elif 完成:
		# 已完成：require + 任务回复：<a>NPC</a> + 类型尾（前面带 <br/>）（:144-163）
		s = _指标符(定, quest)
		s += 回复任务前缀 + _找NPC链接(_追踪回复NPC(quest, 定))
		s += _类型尾(类, true)
	else:
		# 已接：require 原样 + 类型尾（:129-143）
		s = _指标符(定, quest)
		s += _类型尾(类, false)
	if s.is_empty():
		s = String(quest.get("description", ""))
	return "<font color='#ffffff'>" + s + "</font>"


## 已完成时正文末尾按类型再拼一段；周环那段文案长，且 href 与日环同为 event:daily。
func _类型尾(类: String, 完成: bool) -> String:
	var 换行 := "<br/>" if 完成 else ""
	match 类:
		"weekly":
			return 换行 + 周环降难度
		"daily":
			return 换行 + 日环立即完成
		"banghui":
			return 换行 + 家族立即完成
	return ""


## 追踪行那个绿色 NPC 名要**可点**，就得先拿到编号。
##
## ⚠ **在线那两条列表里根本没有 NPC**：`444:3`（已接）只带 `id&状态&目标类型&数据&环id&-&次数`、
## `444:4`（可接）**只有 id**（`后端连接.gd:1637-1666`）。原版也一样 —— 它的
## `QuestTrackerItemRenderer.as:122-125` 用的是 `this._quest.npcId`，那是**按 id 从静态
## `Quest.npc` 段合并出来的**（`数据/任务.json` 的 `npc = {"0": 接取, "1": 回复}`，与服务端
## `fake_flash_server.py:7760-7761` 的 `start_npc_id = npc.get("0")` / `end_npc_id = npc.get("1")`
## 同一副表）。⇒ 运行期条目里没有就必须回落到定义表。
## 以前不回落到头：编号算出 0 ⇒ `_找NPC链接` 直接拼**空串** ⇒ 那一行压根没有可点的东西，
## 用户 2026-10-09 实机报的「点任务没反应」就是这一条（不报错、不提示，静默）。
func _追踪接取NPC(quest: Dictionary, 定: Dictionary = {}) -> int:
	var 值 := int(quest.get("giver_npc", quest.get("npc_id", 0)))
	if 值 > 0:
		return 值
	return int((定.get("npc", {}) as Dictionary).get("0", 0))


func _追踪回复NPC(quest: Dictionary, 定: Dictionary = {}) -> int:
	var 值 := int(quest.get("target_npc", quest.get("end_npc", 0)))
	if 值 > 0:
		return 值
	return int((定.get("npc", {}) as Dictionary).get("1", 0))


## href 里没有 id（原版把 id 存在渲染器的 _findNpc 字段里），所以点击目标要另存 meta。
func _找NPC链接(npc_id: int) -> String:
	if npc_id <= 0:
		return ""
	return "<font color='#00ff00'><a href='%s'>%s</a></font>" % [找NPC链接, 富文本.NPC全名(str(npc_id))]


## 指标符：从 数据/任务.json 的 check 里取目标，进度取运行时条目。
##
## 原版这一行是服务端下发的 `quest.require` 整串（多条之间 `<br/>`、**结尾没有换行**，
## `QuestTrackerItemRenderer.as:129`），并且**点正文会赶路**
## （`QuestDataManager:469-497` → `getQuestPoint()` → `gotoMonsterPoint(2, 序号, 图)`）。
## 本工程按同一份表**现算**，六类目标（mob/npc/item/equip/useitem/pet）**每一类都挂上链接**：
## npc 走 `event:npc<模板>`（既有那条真寻路），mob 走 `event:mob<图>:<怪>`。
func _指标符(定: Dictionary, quest: Dictionary = {}) -> String:
	var 阶段: Variant = 定.get("check", {})
	var 目标: Dictionary = {}
	if 阶段 is Dictionary:
		var c: Variant = (阶段 as Dictionary).get("1", (阶段 as Dictionary).get("0", {}))
		if c is Dictionary:
			目标 = c
	var 多条: Array = []
	var 条数 := 0
	for 键 in ["mob", "npc", "item", "equip", "useitem", "pet"]:
		条数 += _取列(目标.get(键, {})).size()
	## 计数**逐目标各算各的**，不再整条任务共用一个和值。
	## 为什么改：以前只在"这条任务只有一个目标"时才显示 `（x/y）`，而那个数读的是
	## 接任务那一刻 `444:3` 折出来的和值 —— 进度帧没解成数字，于是杀多少怪都不动
	## （用户 2026-10-10 实机报的"击杀怪物任务面板没有实时更新"，图里一直 0/3）。
	## 键的口径与服务端同一份：`QuestObjective.progress_key = str(target_id)`
	## （LEVEL 那一类才用 index）。
	var 有进度 := quest.size() > 0
	for m in _取列(目标.get("mob", {})):
		var 怪 := int(m.get("id", 0))
		if 怪 <= 0:
			continue
		多条.append("击败：<font color='#00ff00'><a href='%s%d:%d'>%s</a></font>%s" % [
				打怪链接, int(m.get("map", 0)), 怪,
				String(GAME_DATA.monster_name(怪)),
				_目标计数(quest, "mob", 怪, int(m.get("count", 1)), 条数, 有进度)])
	for n in _取列(目标.get("npc", 目标.get("npcs", []))):
		var id := int(n.get("id", 0))
		if id <= 0:
			continue
		## ⚠ 「寻找：NPC」这一行**不印计数** —— 原版 `require` 串里对话类目标就是一句
		##    「与#pc…l#交谈」，没有 `（x/y）`；计数只在**可数的**目标上出现
		##    （杀怪 / 交物品 / 捕捉）。我一开始把它加上去，`任务追踪目标回归测试` ④ 当场红。
		多条.append("寻找：<font color='#00ff00'><a href='event:npc%d'>%s</a></font>" % [id, 富文本.NPC全名(str(id))])
	for 键 in ["item", "equip", "useitem"]:
		for it in _取列(目标.get(键, {})):
			var 物 := int(it.get("id", 0))
			if 物 <= 0:
				continue
			var 文 := "交上：<font color='#00ff00'>%s</font>×%d%s" % [
					String(GAME_DATA.item_name(物)), int(it.get("count", 1)),
					_目标计数(quest, 键, 物, int(it.get("count", 1)), 条数, 有进度)]
			var 交 := int(it.get("npc", 0))
			if 交 > 0:
				文 += "（交给 <font color='#00ff00'><a href='event:npc%d'>%s</a></font>）" % [
						交, 富文本.NPC全名(str(交))]
			多条.append(文)
	for 宠 in _取列(目标.get("pet", {})):
		var 号 := int(宠.get("id", 0))
		if 号 <= 0:
			continue
		多条.append("捕捉：<font color='#00ff00'>%s</font>×%d%s" % [
				String(GAME_DATA.monster_name(号)), int(宠.get("count", 1)),
				_目标计数(quest, "pet", 号, int(宠.get("count", 1)), 条数, 有进度)])
	# 多条之间用 \n（RichTextLabel 按行算高），**末尾不加** —— 加了会撑出一个空行
	return "\n".join(多条)


## 一个目标后面的 `（当前/需要）`。
## 有 `目标进度`（在线那两条 444 解出来的）就按 `类:目标号` 取自己那一份；
## 取不到才退回整条任务的和值，而且**只在单目标任务上退**——
## 多目标共用和值会说出"每个目标都完成了"这种假话。
## `有进度` 为假 = 离线那套（`progress_quest` 只写和值），同样只在单目标上显示。
func _目标计数(quest: Dictionary, 类: String, 目标号: int, 需要: int, 目标总数: int, 有进度: bool) -> String:
	if not 有进度:
		return ""
	var 列: Array = quest.get("目标进度", []) as Array
	for 项 in 列:
		var d: Dictionary = 项 as Dictionary
		if String(d.get("kind", "")) != 类:
			continue
		if int(str(d.get("key", "0"))) != 目标号:
			continue
		return "（%d/%d）" % [int(d.get("curr", 0)), int(d.get("count", 需要))]
	if 目标总数 == 1:
		return "（%d/%d）" % [int(quest.get("progress", 0)), int(quest.get("required", 需要))]
	return ""


func _取列(v: Variant) -> Array:
	if v is Array:
		return v
	if v is Dictionary:
		var a: Array = []
		for k in (v as Dictionary).keys():
			a.append((v as Dictionary)[k])
		return a
	return []


## 读本工程的静态任务表（GDScript 需要它来生成指标符；运行时条目只有进度）
func _读任务定义() -> Dictionary:
	if not FileAccess.file_exists("res://数据/任务.json"):
		return {}
	var f := FileAccess.open("res://数据/任务.json", FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}


func _追踪定义条(quest: Dictionary) -> Dictionary:
	var id := String(quest.get("id", ""))
	var 定: Dictionary = _追踪定义.get(id, {})
	return _session.合并任务定义(quest, 定) if _session != null else 定


## 用条目自己的命名空间重转一次正文 BBCode（悬停/按下态靠它精确命中本行）
func _追踪正文重绘(标: RichTextLabel) -> void:
	标.text = 富文本.转换(String(标.get_meta("src")), _追踪表,
		_追踪悬停, _追踪按下, String(标.get_meta("ns")))


func _追踪悬停开始(url: String, 标: RichTextLabel) -> void:
	if _追踪悬停 == String(url):
		return
	_追踪悬停 = String(url)
	标.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_追踪正文重绘(标)


func _追踪悬停结束(_url: String, 标: RichTextLabel) -> void:
	if _追踪悬停.is_empty():
		return
	_追踪悬停 = ""
	_追踪按下 = ""
	标.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_追踪正文重绘(标)


## 原版 a:active = #B19B50 —— 悬停在该段上并按住左键时才生效。
## RichTextLabel 没有逐链接 pressed 信号，只能自己收 gui_input 记按键态。
func _追踪按键(ev: InputEvent, 标: RichTextLabel) -> void:
	var e := ev as InputEventMouseButton
	if e == null or _追踪悬停.is_empty() or e.button_index != MOUSE_BUTTON_LEFT:
		return
	var 新 := _追踪悬停 if e.pressed else ""
	if 新 == _追踪按下:
		return
	_追踪按下 = 新
	## ⚠ **按下那一帧不重排文本**：`标.text = …` 会打断 RichTextLabel 自己的「按下→抬起」配对，
	## `meta_clicked` 就永远不发 ⇒ 表现成"点绿名有时不走"（用户 2026-10-10 上午报的那条）。
	## 只在**抬手**时重绘：抬手后原版本来也就回悬停色，少的只是按住那几帧的 active 色。
	if not e.pressed:
		_追踪正文重绘(标)


func _追踪链接点击(url: String, 标: RichTextLabel = null) -> void:
	# 与任务窗口同源：本图有该 NPC 就开对话，否则给提示
	var u := 富文本.解链接(String(url))
	if u == "event:moreInfo":
		_open_activity()
		return
	if u == "event:daily" and 标 != null:
		var 号 := int(标.get_meta("quest_id", 0))
		if 号 in [8001, 8002]:
			_开环任务窗(号)
		return
	# 原版 `event:findNpc` = `CharacterHandler.MovePlayerToNpc()`（`:685-717`）：
	#   `guajiHandler.isStart = false`（停挂机）→ 取 NPC 所在图与坐标 →
	#   **同图就 `pathFind` 走过去**，跨图先 `MovePlayerToMap`。
	# ⚠ 以前不在本图时落到 `show_npc_dialog(键)` —— 那是**本地假对话**：
	#    人没到、包没发、窗先开了，玩家看到的就是"点寻路没反应"（用户 2026-10-10 报的 B3）。
	#    现在两条链接都汇到 `前往NPC`，与任务窗口点条目、点「前往」按钮同一份代码。
	# id 不在 href 里（原版把它存在渲染器的 `_findNpc` 字段），所以取本行 meta。
	var id := 0
	if u == 找NPC链接:
		id = int(标.get_meta("find_npc")) if 标 != null and 标.has_meta("find_npc") else 0
	elif u.begins_with("event:npc"):
		var 数字 := ""
		for i in range("event:npc".length(), u.length()):
			var c := u[i]
			if c >= "0" and c <= "9":
				数字 += c
			else:
				break
		id = int(数字) if 数字.length() > 0 else 0
	elif u.begins_with(打怪链接):
		## 原版 `QuestTrackerItemRenderer.clickTextHandler:191-208`：这一行**已经做完**了
		## （可交付）时，点那行里的怪名**不再往怪身上走**，而是直接走去**交付 NPC**。
		## ⚠ 以前不分状态，做完了还往怪堆里钻 —— 面板上明明白白写着"已完成"，
		##    人物却往反方向跑，看着就像 bug。
		if 标 != null and 标.has_meta("done") and bool(标.get_meta("done")):
			var 交 := int(标.get_meta("find_npc")) if 标.has_meta("find_npc") else 0
			if 交 > 0:
				前往NPC(交)
				return
		_走向任务怪(u)
		return
	else:
		show_notification("暂不支持该链接：%s" % u)
		return
	if id <= 0:
		## 不许静默：这一行没解析出 NPC 编号 ⇒ 点了不会走。
		## 用户报"有时走有时不走"，屏幕上这句话就能分清是**断在解析**、**断在寻路**，还是根本没点到字上。
		show_notification("这一行没解析出 NPC 编号（链接 %s）⇒ 点了不会走" % u)
		return
	前往NPC(id)
## 到点自动开对话 = 原版 `KeyController.as:220-224`。走的是与**手动点 NPC 完全同一条路**
## （发 54 + 本地渲染一帧），不另开一套，免得在线/离线两种表现分家。
func _到点开对话(编号: String) -> void:
	到点对话次数 += 1
	if _backend != null:
		_backend.call("request_npc_dialog", int(编号))
	show_npc_dialog(编号)


## `42 SHOW_STATUS_INFO`（QUEST 档）→ 原版 `QuestDataManager.startQuest()`（`:269-273`）：
## 非环任务且有寻路目标时弹 `MessageTipPane2.TYPE_ACCEPT_QUEST`，而 `isAutoQuestFun()`
## （`MessageTipPane2.as:386-406`）在**没勾**"关闭自动交接"时把这块提示直接隐藏、
## 自动点一次确定 ⇒ `gotoQuestPoint()` 赶路。默认就是自动（`closeCommitQuest` 是 Boolean、初值 false）。
var _待开环任务 := {}


func _于环任务数据(信息: Dictionary) -> void:
	var 号 := int(信息.get("id", 0))
	if _待开环任务.has(号) and 信息.has("dynamic_data"):
		_待开环任务.erase(号)
		_开环任务窗.call_deferred(号)


## 原版 `QuestDataManager.startQuest:290-296`：日/周环被接上时是 `setDOShow(…, true)`
## （**显示**，不是切换）。`窗口管理.打开或收起` 对已开的窗是关闭 ⇒ 连锁接下一环时
## 会把正开着的环任务窗关掉。这里走幂等的 `打开()`。
func _开环任务窗(编号: int) -> void:
	var 名 := "日环任务" if 编号 == 8001 else "周试炼任务"
	var 管: Node = null
	if get_parent() != null:
		管 = get_parent().get_node_or_null("窗口管理") as Node
	if 管 != null and 管.has_method("打开"):
		管.call("打开", 名)
	elif _session != null:
		_session.request_feature(名)


func _于任务接上(编号: int) -> void:
	if 编号 in [8001, 8002]:
		_待开环任务[编号] = true
		return
	var 条 := _接上的条目(编号)
	if 条.is_empty():
		return
	var 定 := _追踪定义条(条)
	## 守卫逐字照 `QuestDataManager.startQuest:269-273`：
	## `if(!_loc2_.isLoopQuest() && _loc5_ != null) showMessageTipPane2(TYPE_ACCEPT_QUEST, …)`
	## ⇒ **环任务根本不弹这块**（它另有一条 `showDailyMessageTip` 的入口，本工程还没接到，见下），
	##   且 `getQuestPoint()` 为 null 时也不弹、不走路、不报错。
	if _是环任务(条):
		return
	var 目 := _寻路目标(条, 定)
	if 目.is_empty():
		## 原版 `gotoQuestPoint()`（`QuestInfoData.as:297-304`）拿到 null 就**一步都不走**，
		## 也不报错不提示（`getQuestPoint:124-127`：交物目标既没写 npc 也没写 map/mob 时）。
		return
	_提示条报高()
	## 走路这件事**不在这里做** —— 交给 `显示()` 里那次"自动点确定"发 `确定点击`，
	## 与玩家自己点那枚钮同一条路（原版 `isAutoQuestFun → __onOkClick → gotoQuestPoint`）。
	_提示条.call("显示", 提示条.档接取, 编号, _任务名(条, 定), _是环任务(条), _自动交接())


## 提示条上那枚「确定」被点掉（玩家点的、或原版那次"自动点"）。
## 两支各自的动作逐字照 `MessageTipPane2.__onOkClick`：
##   `case TYPE_ACCEPT_QUEST` → `_data.gotoQuestPoint()`（本工程 = `_寻路目标` 那一支）
##   `case TYPE_FINISH_QUEST`（:280-283）→ `UI.qusetClickText(3, _data.endNpcId)` = 走去交付 NPC
## 1291:1 ⇒ 原版 `Client.as:5594 onLianzhanCount`：0 就收起来，否则重新起一个窗口。
func _于连斩数(数量: int) -> void:
	if _连斩面板 != null and is_instance_valid(_连斩面板):
		_连斩面板.call("收到连斩数", 数量)

func _于提示条确定(类型: int, 任务号: int) -> void:
	if 类型 == 提示条.档交付:
		var 键 := String(_session.call("任务交付NPC", 任务号)) if _session != null else ""
		if 键.is_empty():
			## 不许静默：没记下交付 NPC ⇒ 点了确定也不会走，这句话就是给实机看的。
			show_notification("这条任务没记下交付 NPC ⇒ 不会自动走")
			return
		前往NPC(int(键))
		return
	var 条 := _接上的条目(任务号)
	if 条.is_empty():
		return
	var 目 := _寻路目标(条, _追踪定义条(条))
	if 目.is_empty():
		return
	match int(目[0]):
		2:
			_走向任务怪("%s%d:%d" % [打怪链接, int(目[2]), int(目[1])])
		3:
			前往NPC(int(目[1]))


## 原版 `y = smallMapWindow.height + 70` 读的是**运行期**那块的当前高（可折叠）⇒ 每次弹之前现报。
func _提示条报高() -> void:
	if _提示条 == null or _minimap_panel == null:
		return
	_提示条.call("报小地图高", float(_minimap_panel.size.y))


## `QuestInfoData.isLoopQuest():220-233` —— **只有这三类算环任务**：
## daily / weekly / banghui。`monthly`、`loop`、`huodong`、`mixin` 都**不算**，
## 别按名字里带"环"就一起收进去（本工程 追踪类型前缀 那张表里"月环"也在，容易顺手带上）。
## 类型串走 `_追踪类型(条)`：运行期段子里有就用、没有回落定义表的 `info.type`。
func _是环任务(条: Dictionary) -> bool:
	return _追踪类型(条) in ["daily", "weekly", "banghui"]


## 提示条标题里那个任务名 = 追踪行用的同一个取值（`quest.name`，缺省回落定义表）。
func _任务名(条: Dictionary, 定: Dictionary) -> String:
	return String(条.get("name", (定.get("info", {}) as Dictionary).get("name", "任务")))



## 刚接上那条任务的运行期条目（在线形状 = `444:3` 折出来的 `{"id":…, "completed":…}`）。
func _接上的条目(编号: int) -> Dictionary:
	if _session == null:
		return {}
	for 条v in (_session.get("accepted_quests") as Array):
		var 条: Dictionary = 条v as Dictionary
		if int(条.get("id", 0)) == 编号:
			return 条
	return {}


## 原版 `BasicQuestInfoData.getQuestPoint()`（`:94-166`）逐字移植的寻路目标算式。
## 三条口径都是照着 AS3 抄的、**不许"优化"**：
##  ① 次序固定 mobs → items → equips → npcs → pets → 兜底回复 NPC；
##  ② 每一类的 `for each` 都在**第一条**就 return（AS3 就是这个形状，
##     多目标任务因此永远走第一条目标 —— 不是"挑最合适的那条"）；
##     只有 npcs 那一支例外（`:152` 的 `if(_loc8_)`：id 为 0 会接着看下一条）。
##  ③ 目标只读 `check["1"]`，**不看 `check["0"]`** —— "0" 是接取条件
##     （等级/时间/前置任务），拿它当目标会走向一个根本不存在的怪。
##     出处：`QuestInfoData.getConditionData:836` 那句 `getFromObject(this.check,["1",param1])`。
## 返回 `[]` = 原版的 null；兜底那一档用 `_追踪回复NPC`（= AS3 的 `endNpcId`，
## 它同样在 `:968` 从 `configure.npc[1]` 取，且 `:908/926` 允许被运行期 dynamicData 覆盖）。
##
## ⚠ **档只有 2 和 3，没有 1**：`qusetClickText` 的 1 档（去图）在任务链上不可达 ——
##   全量 `qusetClickText(1, …)` 只有三处调用，没有一处是任务：
##   `StructuredText.as:449`（点正文里的 `<#map>` 地名）、`ItemWindow2.as:1038/1047`（飞行卷轴）、
##   `FamillyFlagWindow.as:449`（家族旗帜）。⇒ 别为了"凑齐三档"在这里造一条死分支。
func _寻路目标(条: Dictionary, 定: Dictionary) -> Array:
	var 阶: Dictionary = {}
	var 检: Variant = 定.get("check", {})
	if 检 is Dictionary:
		var 一: Variant = (检 as Dictionary).get("1", {})
		if 一 is Dictionary:
			阶 = 一
	for 怪 in _取列(阶.get("mob", {})):
		return [2, int(怪.get("id", 0)), int(怪.get("map", 0))]
	for 物列 in ["item", "equip"]:
		for 物 in _取列(阶.get(物列, {})):
			var 交 := int(物.get("npc", 0))
			if 交 == 0:
				var 图 := int(物.get("map", 0))
				var 怪号 := int(物.get("mob", 0))
				if 怪号 == 0 and 图 == 0:
					return []
				return [2, 怪号, 图]
			return [3, 交, 0]
	for 人 in _取列(阶.get("npc", {})):
		var 号 := int(人.get("id", 0))
		if 号 != 0:
			return [3, 号, 0]
	for 宠 in _取列(阶.get("pet", {})):
		return [2, int(宠.get("mob", 0)), int(宠.get("map", 0))]
	return [3, _追踪回复NPC(条, 定), 0]


## 设置项 = 原版 `SysCfg.closeCommitQuest`（勾上 = **不要**自动交接，`MessageTipPane2.as:386-406`
## `isAutoQuestFun()` 读的正是它；原版初值 false ⇒ 默认自动）。本工程把它存成**正向键**
## `auto_commit_quest`：设置页第 10 枚勾选框「关闭自动提交任务」写值时取反
## （`设置窗口.gd:_点复选` 的 `写=false` 就是「标题是键的反义」那一族，和
##  `show_other_characters` 同一套），所以这里**直接读、不要再取一次反**——
## 再取一次就把默认行为反过来了（接完任务不再自己走过去），而且门测的还是默认那一条，绿着也看不出来。
## 勾选框真值：`SystemConfigWindow.as:129-134`（x 同「遮罩所有造型特效」、y = 它 + 27）、
## 文案键 `SYSCONFIG_CLOSE_COMMIT_QUEST` = 关闭自动提交任务（`en_US$message_properties.as:2240`）。
## ⚠ 这里以前写死 `return true` ⇒ 那枚勾点了**没有任何作用**（用户看不出任何差别）。
## ⚠ 2026-10-10 更正管辖范围：它**只管**那块提示条要不要"自动替你点确定"
##   （`提示条面板.gd:显示()` 里那一句），**不是**"要不要自动赶路"。
##   以前两支都挂在这个开关上 ⇒ 勾上之后接完任务、交完任务一步都不走，
##   而原版是"把条子显示出来等你点确定"——走路那一支在原版是点得下去就一定发生的。
func _自动交接() -> bool:
	if _session == null:
		return true
	return bool(_session.game_settings.get("auto_commit_quest", true))


## `51 SHOW_QUEST_COMPLETION` → 原版 `QuestDataManager.showOverQuest()`（`:737-756`）：
## 先挂那枚大横幅，再（任务确实在"已完成"列表里）走 `showCompleteTip`。
## 横幅之外还要走 `showCompleteTip` 那一半：`MessageTipPane2.as:412-415` 的
## `qusetClickText(3, endNpcId)` ⇒ 自动赶路去**交付 NPC**，到点自动开对话（`_待对话NPC`）。
func _于任务交付(编号: int) -> void:
	播任务完成横幅()
	## `showOverQuest:751-755`：横幅**无条件**挂；那块提示条要"这条任务确实在已接列表里、
	## 且状态 = 已完成"才走 `showCompleteTip`。
	var 条 := _接上的条目(编号)
	if 条.is_empty() or not bool(条.get("completed", false)):
		return
	_提示条报高()
	## `showCompleteTip:706-707`：先按任务号把两档旧条各清一遍，再挂交付档。
	_提示条.call("移除任务提示", -1, 编号)
	## 走路不在这儿：`显示()` 里那次"自动点确定"会发 `确定点击(档交付, …)`，
	## 由 `_于提示条确定` 去 `前往NPC(交付NPC)`。勾了那枚开关时 ⇒ 条子留在屏上等你点。
	_提示条.call("显示", 提示条.档交付, 编号, _任务名(条, _追踪定义条(条)), false, _自动交接())


## 横幅本体。真值 `QuestDataManager.as:739-756` + `:787-811`：
##   图 = `Etc.effects.questOverTip[0]`（424×98，origin 212,0 ⇒ 水平居中挂在锚点上）；
##   位置 = `x = Config.STAGE_WIDTH / 2`（本工程视口宽 960 ⇒ 480）、`y = 50`；
##   `mouseChildren = mouseEnabled = false`（不吃鼠标）；
##   时间轴（**按帧**加 alpha，不是按秒 —— 原版 `_frameTime` 是 ENTER_FRAME，60fps 与 30fps
##   淡入时长不同，这里照抄"每帧 ±0.1"，不改成按秒）：
##     <500ms 每帧 +0.1 → 500~3500ms 恒 1 → 3500~4500ms 每帧 −0.1 → ≥4500ms removeChild。
const 横幅特效 := "questOverTip"
## x 不能写死：原版 QuestDataManager.as:744 是 x = Config.STAGE_WIDTH / 2，那是运行期的舞台宽
## （本机实机 1918 宽、LAUNCHER_SCALE=1）⇒ 窗口多大就居中到哪。以前写死 480（=960 的一半），
## 你最大化窗口后它就偏到左半屏（2026-10-09 实机报的）。y 才是真常数 50（:745 的字面值）。
## 贴图原点 [212,0] 由 特效播放器 处理 ⇒ position.x 就是横幅的水平中心。
const 横幅y := 50.0
const 横幅淡入完 := 0.5
const 横幅开始淡出 := 3.5
const 横幅移除 := 4.5
const 横幅每帧步长 := 0.1

func 播任务完成横幅() -> void:
	if _横幅 != null and is_instance_valid(_横幅):
		_横幅.queue_free()
	_横幅 = null
	var 播放器 := EffectPlayer.new()
	播放器.name = "任务完成横幅"
	add_child(播放器)
	if not 播放器.call("play", 横幅特效):
		播放器.queue_free()
		_横幅 = null
		return
	播放器.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5, 横幅y)
	## 原版 `mouseChildren = mouseEnabled = false`。Godot 侧 Node2D/Sprite2D 本来就不吃
	## 鼠标拾取（没有 `input_pickable`），所以这里**没有**可设的属性 —— 别写 `mouse_filter`，
	## Node2D 上没这个成员，写了是运行期报错。
	播放器.modulate.a = 0.0
	_横幅秒表 = 0.0
	_横幅 = 播放器

func _走横幅(增量: float) -> void:
	if _横幅 == null or not is_instance_valid(_横幅):
		return
	_横幅秒表 += 增量
	var 秒 := _横幅秒表
	if 秒 >= 横幅移除:
		_横幅.queue_free()
		_横幅 = null
		return
	var 色 := _横幅.modulate
	if 秒 < 横幅淡入完:
		色.a = minf(1.0, 色.a + 横幅每帧步长)
	elif 秒 <= 横幅开始淡出:
		色.a = 1.0
	else:
		色.a = maxf(0.0, 色.a - 横幅每帧步长)
	_横幅.modulate = 色


## 玩家一出现就把 `自动寻路态` 接上（只接一次；面板被重建过则重新接 + 按当前态补挂）。
func _接寻路提示() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if not _寻路提示已连:
		if not _player.has_signal("自动寻路态"):
			return
		_player.connect("自动寻路态", _于自动寻路)
		_寻路提示已连 = true
	## 补挂：本页可能在一段自动赶路**中途**才被重建（设置页改一项会整页重建），
	## 这时信号不会重发，必须照玩家当前状态把它挂回去。
	if bool(_player.get("自动寻路中")):
		_挂寻路提示()
	else:
		_摘寻路提示()

func _于自动寻路(在走: bool) -> void:
	if 在走:
		_挂寻路提示()
	else:
		_摘寻路提示()

func _挂寻路提示() -> void:
	if _寻路提示 != null and is_instance_valid(_寻路提示):
		return		# 原版 `:1004` 先 `stage.contains()` 判过才 add —— 重复挂会把它挪到最上层
	var 播放器 := EffectPlayer.new()
	播放器.name = "自动寻路提示"
	add_child(播放器)
	if not 播放器.call("play", 寻路提示特效):
		播放器.queue_free()
		return
	## `x = Config.STAGE_WIDTH / 2` 是**运行期**算的，不是常量 ⇒ 这里跟着视口宽走。
	## ⚠ 本文件 `extends CanvasLayer`，**没有** `get_viewport_rect()`（那是 Viewport/Window 的方法），
	## 只能 `get_viewport().get_visible_rect().size`。
	播放器.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5, 寻路提示y)
	_寻路提示 = 播放器

func _摘寻路提示() -> void:
	if _寻路提示 != null and is_instance_valid(_寻路提示):
		_寻路提示.queue_free()
	_寻路提示 = null


## 本图里有没有这个 NPC。
##
## ⚠️ **不能用 `get_nodes_in_group("npc")`** —— 全工程**没有任何地方**把 NPC 加进那个组，
## 它恒为空。原来那段 `for n in get_tree().get_nodes_in_group("npc")` 就是空转
## （前后两条路都落到 `show_npc_dialog`，所以一直没暴露）。
## 这里改成向 `LifeRoot` 要它的 `_entities`（本工程查世界上有没有某样东西的既有口径）。
## 世界上这些实体的**唯一**取法。以前这里写 `get_parent().get_node_or_null("LifeRoot")`，
## 而同一个文件 `_刷标记` 写的是 `场.get_node_or_null("LifeRoot")` —— 两份找同一个节点的写法，
## 换一次 HUD 挂法就只有一边还能拿到（"时灵时不灵"最难查的那种）。统一走这一条。
func _生怪根() -> Node:
	var 场 := get_tree().current_scene
	var 根 := 场.get_node_or_null("LifeRoot") if 场 != null else null
	if 根 != null:
		return 根
	return get_parent().get_node_or_null("LifeRoot") if get_parent() != null else null


func _找本图NPC(编号: String) -> Node2D:
	var 生怪根 := _生怪根()
	if 生怪根 == null:
		return null
	for 实体 in 生怪根.get("_entities") as Array:
		## ⚠ 换图瞬间 `_entities` 里可能还留着**已释放**的旧实体（新 LifeRoot 接手前的那一帧）。
		## 直接 `as Node2D` 会每帧刷 `Trying to cast a freed object` 并中断本函数 ——
		## 实测一次跑图刷了几百行，还会挡住同帧后面的逻辑。
		if not is_instance_valid(实体):
			continue
		var 谁 := 实体 as Node2D
		if 谁 == null or str(谁.get("kind")) != "n":
			continue
		if int(str(谁.get("entity_id"))) == int(编号):
			return 谁
	return null

## 原版 `MovePlayerToNpc` 的"同图"那一支：`pathFind(npc.x, npc.y)`。
## 本工程落到 `玩家.走向()` 上 —— 点怪那条命令走的就是同一套真寻路（§3.67）。
func _走向NPC(实体: Node2D, 到点开对话 := false, 显示提示 := true) -> void:
	var 玩家 := get_tree().get_first_node_in_group("player")
	if 玩家 == null or not 玩家.has_method("走向"):
		show_notification(寻路失败)
		return
	# 对应原版 `pathFind(x, y, param3 = lifeId, ...)`：只有任务赶路才带 lifeId
	_待对话NPC = str(int(实体.get("entity_id"))) if 到点开对话 else ""
	## 记下"起这条路线时的走完印"：HUD 下一帧靠印变没变分辨"走完了"与"被打断"。
	_待对话起点印 = int(玩家.get("auto_path_arrive_stamp"))
	## 第 4 参 = 原版 `showtip`：`CharacterHandler.as:710` 的 MovePlayerToNpc 传的是 **true**；
	## 而 `NPC.as:63` 的「远处点 NPC」传的是 **false** ⇒ 那一种不亮「自动寻路中」。
	## ⚠ `走向` 返回 false = 这个点没有落脚点/寻不到路 ⇒ 必须说出来：以前忽略返回值，
	## 于是"点了任务没反应"连一句提示都没有（用户 2026-10-09 实机报的那条）。
	if not bool(玩家.call("走向", 实体.global_position, true, 显示提示)):
		_待对话NPC = ""
		show_notification(寻路失败)


## 点追踪栏「击败：X」= 原版点任务正文赶路（`QuestDataManager:469-497`）。
## **同图**：取最近的一只活口真寻路走过去；**不在本图**：走一步跨图传送点，走不到就报他在哪张图。
## 外部面板点「去这只怪」的公共入口（写轮眼页的绿字怪名）：原版
## `StructuredText.as:465` → `UI.qusetClickText(2, mobid, mapid)` → `CharacterHandler.MovePlayerToMob`。
## 先停挂机（`UI.as:769` 的 `guajiHandler.isStart = false`），再复用任务怪那条：
## 同图取**最近活口**真寻路、异图走传送门。
func 走向怪(图号: int, 怪号: int) -> void:
	if _session != null and bool((_session.get("hang_state") as Dictionary).get("active", false)):
		_session.call("request_hang", false)
	_走向任务怪("%s%d:%d" % [打怪链接, 图号, 怪号])


func _走向任务怪(链接: String) -> void:
	var 段 := 链接.substr(打怪链接.length()).split(":", false)
	var 图 := int(段[0]) if 段.size() > 0 else 0
	var 怪 := int(段[1]) if 段.size() > 1 else 0
	if 怪 <= 0:
		return
	var 名 := String(GAME_DATA.monster_name(怪))
	var 实体 := _本图最近怪(怪)
	if 实体 != null:
		var 玩家 := get_tree().get_first_node_in_group("player")
		if 玩家 == null or not 玩家.has_method("走向"):
			show_notification(寻路失败)
			return
		## 原版 `CharacterHandler.as:881` 的 MovePlayerToMob → `pathFind(x, y, -mobId, **true**)`
		## ⇒ 这一支也带 showtip。（**不是**战斗里"走过去打"那条 —— 那条走 `GuajiHandler`，不带。）
		## ⚠ 以前**没判返回值**：这一步寻不到路就一句都不说，看着就是"点怪名没反应"
		##    （用户 2026-10-10 实机报的其中一条）。
		if not bool(玩家.call("走向", 实体.global_position, true, true)):
			show_notification("走不到「%s」那一步（这一段没有落脚点）" % 名)
		return
	if 图 > 0 and 图 != _本图号():
		前往别的图(图, "击败 %s" % 名)
		return
	if 图 <= 0:
		## href 里没带图号（老数据/服务端没给）⇒ 拿实体所在图表兜一下，别直接放弃
		var 实际 := _在哪图("mob", 怪)
		if not 实际.is_empty() and _挪去别的图(实际, "击败 %s" % 名):
			return
	## 任务声明的就是本图、可现在场上没这只活口 ⇒ 等刷新，别假装在赶路
	show_notification("本图暂时没有「%s」，等它刷出来再点一次" % 名)
## 本图有没有**直达**目标图的传送点。读 `数据/地图/<当前图>/地图.json` 的 portal 段，
## 只认原版会用的 `pt in [2,7,10]`（与 `传送门.gd`/烘焙器同一道筛）；
## 序号 = 字典键 = 服务端 `current_map.portals` 的键（两边同一份表，不另立编号）。
func _通往(目标图: int) -> Dictionary:
	var 后端 := get_node_or_null("/root/BackendConnection")
	var 本图 := int(后端.get("authoritative_map_id")) if 后端 != null else 0
	if 本图 <= 0 or 目标图 <= 0:
		return {}
	## 走 MAP_RESOURCES 那一条解析（`数据/地图索引.json` 图号→目录），
	## 不再自己拿显示名去拼目录名 —— 显示名与目录名**不是同一个东西**，
	## 拼错了这里只会安静地返回 {}，于是"跨图赶路"永远说"本图没有直达传送点"。
	var 路 := MAP_RESOURCES.map_data_path(str(本图))
	if not FileAccess.file_exists(路):
		return {}
	var 表 = JSON.parse_string(FileAccess.get_file_as_string(路))
	if not (表 is Dictionary):
		return {}
	var 门们: Dictionary = (表 as Dictionary).get("portal", {}) as Dictionary
	for 键 in 门们.keys():
		var 门: Dictionary = 门们[键] as Dictionary
		if not [2, 7, 10].has(int(门.get("pt", 0))):
			continue
		if int(门.get("tm", 0)) == 目标图:
			## ⚠ 世界位 = **数据原值**，不是 ×100。证据两处，都是现查：
			##   ① 地图场景摆落脚点/出生点直接吃原值（`地表.gd:89` `Vector2(float(pd["x"]), float(pd["y"]))`）；
			##   ② 原版坐标显示是 `Math.floor(x/100)`（`SmallMapWindow.as:437`），而 `x` 就是世界位
			##      ⇒ ÷100 只是**显示口径**，不是"数据是 1/100 单位"。以前这里乘了 100，目标点被推到
			##      地图外面（木叶村那扇门算成 (459500, 126395)），`find_click_target` 给不到落脚点
			##      ⇒ 跨图一步都起不来。2026-10-10 由 `测试/跨图赶路推进回归测试.gd` 量出来后改回。
			## −5 是原版本来的下偏（`KeyController.as:477` `pathFind(门.x, 门.y - 5)`），单位=世界像素。
			return {"index": int(键), "图": 目标图,
					"位": Vector2(float(门.get("x", 0)), float(门.get("y", 0)) - 5.0)}
	return {}


## 跨图**一跳**自动赶路：先走到门口，站定后由 `_process` 发进门包。
## 两跳以上（要 BFS 整张传送图 + 换图后续跑）**没接** —— 明确报出来，不假装"正在前往"。
func 前往别的图(目标图: int, 说明: String, 终目标 := {}) -> bool:
	var 门 := _通往(目标图)
	if 门.is_empty():
		## 没有直达门 ⇒ 交给图级路线（原版 `MovePlayerToMap` 在跨图那一支就是这个顺序：
		## 不是"找不到直达门就算了"，而是把整条门路排出来一跳一跳走）。
		return _起多跳(目标图, 说明, 终目标)
	var 玩家 := _player if _player != null else (get_tree().get_first_node_in_group("player") as Node2D)
	if 玩家 == null or not 玩家.has_method("走向"):
		return false
	## 跨图赶路的这一步在原版**一定**亮提示：`KeyController.as:1058` 的条件是
	## `param5 || this._nowWalkingToMap`，而 `_nowWalkingToMap` 在 :1122 置真。
	if not bool(玩家.call("走向", 门["位"] as Vector2, true, true)):
		show_notification("通往《%s》的传送点这一步寻不到路" % _地图名(目标图))
		return false
	_待进门 = 门.duplicate(true)
	_待进门["等"] = 0.0
	_待进门["跨图"] = true
	_跨图余程 = []
	_跨图终目标 = 终目标
	_跨图终点图 = 目标图
	_跨图在途 = true
	_跨图上图 = _本图号()
	_跨图玩家 = _player as Node2D
	_跨图起手印 = int(_player.get("auto_path_cancel_stamp")) if _player != null else 0
	_跨图记("起跑（直达门）")
	_跨图等到 = 0.0
	show_notification("前往《%s》：先走到传送点（%s）" % [_地图名(目标图), 说明])
	return true


## 排一条多跳路线开走。每一跳的落点 = `(门.x, 门.y - 5)`（数据原值就是世界坐标）：
## ⚠ 这里以前写的是 `*100` —— 错了：地图场景把数据原值直接当世界坐标用（见 `_通往` 里那两条
##   现查证据），乘 100 会把目标推到地图外，跨图第一步就寻不到路。2026-10-10 改回原值。
func _起多跳(目标图: int, 说明: String, 终目标: Dictionary) -> bool:
	var S := load(跨图寻路脚本)
	if S == null:
		show_notification("跨图路线模块读不到（res://脚本/地图/跨图寻路.gd）")
		return false
	var 出: Dictionary = S.路线(str(_本图号()), str(目标图))
	if not bool(出.get("成", false)):
		show_notification("%s ⇒ %s 到《%s》走不过去（%s）" % [
				str(出.get("原因", "路线没算出来")), _地图名(_本图号()), _地图名(目标图), 说明])
		return false
	_跨图余程 = (出.get("跳", []) as Array).duplicate(true)
	_跨图总跳数 = _跨图余程.size()
	_跨图终点图 = 目标图
	_跨图终目标 = 终目标
	_跨图上图 = _本图号()
	_跨图在途 = true
	_跨图记("起跑（多跳）共 %d 跳" % _跨图余程.size())
	show_notification("前往《%s》：要穿 %d 道传送门（%s）" % [_地图名(目标图), _跨图余程.size(), 说明])
	return _走跨图一跳()


## 走余程里的第一跳：先过等级闸，再走到门口、站定后由 `_process` 那一段发进门包。
func _走跨图一跳() -> bool:
	if _跨图余程.is_empty():
		return false
	var 跳: Dictionary = _跨图余程[0] as Dictionary
	var 状态: Dictionary = (_session.get("player_stats") as Dictionary) if _session != null else {}
	var 我要 := int(状态.get("level", 1))
	var 要等 := int(跳.get("到达等级", 0))
	if 我要 < 要等:
		## 原版 `KeyController.as:661` 这一支：`MAP_NO_ENTRAY` + `stopPathFind()` —— 等级不够
		## 是**整条停下来**，不是绕路、更不是硬闯。
		show_notification("进不去《%s》：要 %d 级（你现在 %d 级），先到门口也没用" % [
				_地图名(int(str(跳.get("到达图", "0")))), 要等, 我要])
		_清跨图()
		return false
	## 落点 = 数据原值 + 原版那个 −5（与 `_通往` 同一条口径，证据见那里的注释）
	var 位 := Vector2(float(跳.get("门x", 0.0)), float(跳.get("门y", 0.0)) - 5.0)
	var 玩家 := _player if _player != null else (get_tree().get_first_node_in_group("player") as Node2D)
	if 玩家 == null or not 玩家.has_method("走向"):
		## ⚠ 这里以前直接 `_清跨图()` —— **一声不吭地把整趟行程删掉**。换图那一瞬间新角色往往
		## 还没建好（角色是服务端推进来的），于是"接手的第一拍"就撞上这个分支，症状正是
		## 用户实机看到的「到了第二张就站住、什么提示也没有」。⇒ 改成：**不判死，下一拍再试**，
		## 上限走同一条 15 秒闸（`_跨图等到`），到点必须说一句，不许静默。
		_跨图等到 += 0.016
		if _跨图等到 > 15.0:
			show_notification("跨图赶路停了：换图后 15 秒没等到可用的角色（再点一次追踪栏那行）")
			_清跨图()
		return false
	if not bool(玩家.call("走向", 位, true, true)):
		_跨图记("这一跳 走向() 回 false ⇒ 整条取消")
		show_notification("通往《%s》的传送点这一步寻不到路（%d 跳里的第 %d 跳）" % [
				_地图名(int(str(跳.get("到达图", "0")))), _跨图余程.size(), 1])
		_清跨图()
		return false
	_待进门 = {"index": int(跳.get("门号", -1)), "图": int(str(跳.get("到达图", "0"))),
			"位": 位, "等": 0.0, "跨图": true}
	_跨图余程.pop_front()
	_跨图玩家 = 玩家 as Node2D
	_跨图起手印 = int(玩家.get("auto_path_cancel_stamp"))
	_跨图等到 = 0.0
	_跨图记("起第 %d 跳：门 %s → %s 落点 %s" % [_跨图总跳数 - _跨图余程.size(),
			str(跳.get("门号")), str(跳.get("到达图")), str(位)])
	## 每起一跳都留一句（原版顶部那条「自动寻路中」只说"在走"，不说走到第几门）。
	## 这句是给**定位**用的：换图后看见它 = 行程活着、是走不到人；看不见 = 行程被清了。
	show_notification("跨图赶路：第 %d 跳，共 %d 跳 → 走到《%s》方向" % [
			_跨图总跳数 - _跨图余程.size(), _跨图总跳数, _地图名(int(str(跳.get("到达图", "0"))))])
	return true


## 换图成功后：到终点了就去做那件事，否则接着走下一跳。
func _续跨图() -> void:
	## 换图后接着走：还有余程 ⇒ 走下一跳；余程空 ⇒ 到终点图了，去找那个人。
	## 注意这里**不清在途**（以前一进来就清，于是"到达后每拍重试"根本没机会跑）——
	## 清由 `_清跨图()` 统一做。
	if not _跨图余程.is_empty():
		_走跨图一跳()
		return
	if _跨图终目标.is_empty() or int(_跨图终目标.get("号", 0)) <= 0:
		var 图0 := _跨图终点图
		_清跨图()
		show_notification("已到达《%s》" % _地图名(图0))
		return
	if str(_跨图终目标.get("类", "")) == "n" and _找本图NPC("%08d" % int(_跨图终目标["号"])) == null:
		return		# 还没刷出来：下一拍再来（超时那句在 _process 里报）
	var 终 := _跨图终目标
	var 图 := _跨图终点图
	_清跨图()
	if str(终.get("类", "")) == "n":
		_走到NPC(int(终["号"]), str(终.get("说明", "到了")), true)
	else:
		show_notification("已到达《%s》，任务怪要再点一次（这一跳只负责把人送到图上）" % _地图名(图))


## 把路线状态抄回会话（换图后新 HUD 靠它接手）。会话是单例，不抄就等于把路线带进坟里。
## 跨图每个决策点都往这个文件追一行（**不写 user://**，那是存档的地盘）。
## 为什么必须有：这条链上"行程被清掉"有好几个入口（手动取消 / 等级闸 / 这一跳寻不到路 /
## 换图后没接手成功），界面上看全是"人不走了"，只有决策日志分得清是哪一条。
func _跨图记(说: String) -> void:
	var 路 := "res://测试/截图/追踪栏/跨图实机.log"
	var 存 := FileAccess.file_exists(路)
	var f := FileAccess.open(路, FileAccess.READ_WRITE if 存 else FileAccess.WRITE)
	if f == null:
		return
	if 存:
		f.seek_end()
	f.store_string("[%s] 图=%d 在途=%s 余程=%d 等到=%.1f 印=%d|现=%d 同人=%s 新=%s %s%s" % [
			str(float(Time.get_ticks_msec()) / 1000.0), _本图号(), str(_跨图在途), _跨图余程.size(),
			_跨图等到, _跨图起手印, int(_player.get("auto_path_cancel_stamp")) if _player != null else -1,
			str(_跨图玩家 != null and _跨图玩家 == _player), str(_跨图玩家 == null), 说, char(10)])
	f.close()


## 玩家是不是自己在操作（原版 `isDownMoveKey()`：左右上下 + 跳；本工程再加普攻键，
## 因为 `SkillHandler.as:278` 出招也会 `stopPathFind()`，效果等同"插手"）。
func _玩家自己在动() -> bool:
	for 招 in ["ui_left", "ui_right", "ui_up", "ui_down", "jump", "basic_attack"]:
		if Input.is_action_pressed(招):
			return true
	return false


func _写回跨图() -> void:
	if _session == null:
		return
	_session.set("跨图在途", _跨图在途)
	_session.set("跨图余程", _跨图余程)
	_session.set("跨图终目标", _跨图终目标)
	_session.set("跨图终点图", _跨图终点图)
	_session.set("跨图等到", _跨图等到)


func _清跨图() -> void:
	_跨图余程 = []
	_跨图等到 = 0.0
	_跨图终目标 = {}
	_跨图终点图 = 0
	_跨图在途 = false
	_跨图记("清空这趟行程")
	_写回跨图()


## 本图里离玩家最近的一只该模板**活口**怪。
## ⚠ 和 `_找本图NPC` 一样：不能走 `get_nodes_in_group`（没人加组），要问 `LifeRoot._entities`。
func _本图最近怪(模板: int) -> Node2D:
	var 生怪根 := _生怪根()
	if 生怪根 == null:
		return null
	var 玩家 := get_tree().get_first_node_in_group("player") as Node2D
	var 最近: Node2D = null
	var 最近距 := INF
	for 实体 in 生怪根.get("_entities") as Array:
		var 谁 := 实体 as Node2D
		if 谁 == null or str(谁.get("kind")) != "m" or not bool(谁.get("alive")):
			continue
		if int(str(谁.get("entity_id"))) != 模板:
			continue
		if 玩家 == null:
			return 谁
		var 距 := 谁.global_position.distance_squared_to(玩家.global_position)
		if 距 < 最近距:
			最近距 = 距
			最近 = 谁
	return 最近


var _地图名表 := {}


func _地图名(图: int) -> String:
	if _地图名表.is_empty():
		var 解 = JSON.parse_string(FileAccess.get_file_as_string("res://数据/地图名.json"))
		_地图名表 = 解 if 解 is Dictionary else {}
	return String((_地图名表 as Dictionary).get(str(图), "图 %d" % 图))


## NPC 那一支的**唯一出口**：点「可接任务」条目 / 追踪栏绿名 / 「前往」按钮都汇到这里。
## 原版 `CharacterHandler.MovePlayerToNpc()`（`:685-717`）：取该 NPC 所在图 →
## **同图就 `pathFind` 走过去、到点自动发 54 开对话**；跨图先 `MovePlayerToMap`。
## 本工程跨图只做**一步**（本图有直达传送点就走到门口进门）；做不到就**说清他在哪张图**，
## ⚠ 绝不弹本地假对话假装"到了"（用户 2026-10-10 报的"NPC 不在当前地图点寻路没反应"就是那条）。
func 前往NPC(模板号: int, 显示提示 := true) -> void:
	_走到NPC(模板号, "找 %s" % String(GAME_DATA.npc_name("%08d" % 模板号)), 显示提示)


var _实体图表 := {}


## `数据/界面/实体所在图.json`：模板号 → 出现在哪些图上。
## 出处 = `开发工具/出实体所在图.py`，读 `数据/地图索引.json` + 各图 `life` 段 ——
## 与运行期生成这些实体的**同一份表**，所以不会出现"索引说他在 A 图、进图却没人"。
func _实体图() -> Dictionary:
	if _实体图表.is_empty():
		var 解 = JSON.parse_string(FileAccess.get_file_as_string(
				"res://数据/界面/实体所在图.json"))
		_实体图表 = 解 if 解 is Dictionary else {}
	return _实体图表


func _在哪图(类: String, 模板号: int) -> Array:
	var 表 = _实体图().get(类, {})
	if not (表 is Dictionary):
		return []
	var 列 = (表 as Dictionary).get(str(模板号), [])
	return 列 if 列 is Array else []


func _本图号() -> int:
	var 后端 := get_node_or_null("/root/BackendConnection")
	if 后端 != null:
		var 在 := int(后端.get("authoritative_map_id"))
		if 在 > 0:
			return 在
	if _session != null:
		## ⚠ 必须 `str()` 不能 `String()`：`_session.get()` 回来的是 Variant，
		##    `String(变量)` 在 GDScript 里是**无效调用**（函数中途死掉且不报错），
		##    正是 #149 登记的那一类 —— `点角色不崩回归测试` 全工程扫这条，写错立刻红。
		return int(str(_session.get("current_map_id")))
	return 0


## 目标不在本图 ⇒ **只走一步**：本图有直达传送点就走到门口进门。
## 返回 true = 这一步真的起来了；多跳自动赶路没做，不许假装做完了。
func _挪去别的图(图们: Array, 说明: String, 终目标 := {}) -> bool:
	var 本图 := _本图号()
	for v in 图们:
		var 图 := int(str(v))
		if 图 <= 0 or 图 == 本图:
			continue
		# 只认第一张目标图，别把"没有直达门"重复播报
		return 前往别的图(图, 说明, 终目标)
	show_notification("%s：实体所在图表里查不到他在哪张图" % 说明)
	return false


func _走到NPC(模板号: int, 说明: String, 显示提示 := true) -> void:
	if 模板号 <= 0:
		return
	var 键 := "%08d" % 模板号
	var 实体 := _找本图NPC(键)
	if 实体 != null:
		_走向NPC(实体, true, 显示提示)		# 走到跟前自动开对话
		return
	var 名 := str(GAME_DATA.npc_name(键))
	var 图们 := _在哪图("npc", 模板号)
	if 图们.is_empty():
		show_notification("《%s》不在本图，实体所在图表里也查不到他" % 名)
		return
	var 在本图 := false
	for v in 图们:
		## 表里的图号可能是 int 也可能是字符串（`int(str(v))` 与 `_挪去别的图` 同一口径），
		## 直接 `图们.has(本图)` 会因为类型不同而假负。
		if int(str(v)) == _本图号():
			在本图 = true
			break
	if 在本图:
		## 表上说他**就在这张图**，可场景里没这个实体 ⇒ 十有八九是点在换图/刷新的那一瞬间
		## （LifeRoot 正在重建）。这是"有时走有时不走"最像的一种，必须说清，别改口成"他在别的图"。
		show_notification("《%s》就该在本图，但场景里此刻没有他（换图/刷新的一瞬间点的，再点一次）" % 名)
		return
	if _挪去别的图(图们, 说明, {"类": "n", "号": 模板号, "说明": 说明}):
		return
	var 图名: Array = []
	for v in 图们:
		图名.append(_地图名(int(str(v))))
	## 走到这里 = 直达门没有、多跳也没起来（等级闸 / 门口寻不到路 / 图不连通），
	## 那几条自己已经播过原因了，这里只补一句"他在哪张图"，别再重复"还没接"。
	show_notification("《%s》在《%s》" % [名, "、".join(PackedStringArray(图名))])
func _toggle_quest_tracker() -> void:
	_quest_expanded = not _quest_expanded
	_quest_content.visible = _quest_expanded
	_刷新折叠钮图形()
	_刷新追踪高度()
	_quest_expand_button.tooltip_text = "收起任务追踪" if _quest_expanded else "展开任务追踪"


## 展开/收起两态换皮。哪张皮对应哪一态不是猜的：拿 测试/基线/原版界面/原版_人物背包忍术.png
## 里追踪栏（模板匹配置于 左=2095 上=184）右上角 x=_width-18-4=153 / y=2
## （QuestTrackerWindow.as:163-164）算出的 (2248,186) 那块 18×18 逐像素比过：
## 截图是**展开**态，与 减少按钮.png 不透明区平均差 1.50、最大 16；
## 与 增加按钮.png 差 27.35、最大 230 ⇒ 展开=减号，收起=加号。
## 原版 MButton3 有 upSkin / selectedUpSkin 两张皮（MButton3.as:136-142、:341），
## QuestTrackerWindow 用 selected 表示**展开**（:88 初始 selected=true，:102-105 selected 才显示
## 内容，:422-423 点一下取反）—— 所以这里换的是"当前态的常态皮肤"，悬停/按下仍走同一套滤镜。
func _刷新折叠钮图形() -> void:
	if _quest_expand_button == null:
		return
	_设三态皮肤(_quest_expand_button,
		"折叠钮展开" if _quest_expanded else "折叠钮收起")


## 原版 QuestTrackerWindow 的高度是算出来的，不是固定的：
##   有任务：_height = min(标题高 + 列表高, MAX_HEIGHT=180)，ScrollPane 高 = _height - 22
##   没任务：_height = 标题高 22，并且展开按钮 disabled
##   收起：  _hotRect / contentPanel 直接 visible=false
## 背景渐变铺的是**整块面板**（drawTrackerBg 用 this.width/this.height），
## 所以面板高度一变就要重算，不能只在场景里写死。
## 「更多可玩内容」也计入面板高 —— 原版 height() 的三行分支（:271-277）：
##   收起：_background.height + playMore.height + 5
##   展开：_height + playMore.height + 15
## 它的 y 同理（positionPlayMoreTf :190-193）：收起 = _hotRect.y+5 = 27，展开 = _height+15。
func _刷新追踪高度() -> void:
	if _quest_tracker == null:
		return
	# 先按上限撑开，等 VBox 排版完再收成实际高度
	_quest_tracker.size.y = 追踪最大高 + 更多可玩内容高 + 15.0
	await get_tree().process_frame
	if _quest_list == null or not is_instance_valid(_quest_list):
		return
	var 有任务 := not _quest_list.get_children().is_empty()
	if _quest_expand_button != null:
		_quest_expand_button.disabled = not 有任务
	var 内容高 := 追踪标题高
	if 有任务 and _quest_expanded:
		内容高 = 追踪标题高 + minf(_quest_list.get_combined_minimum_size().y, 追踪最大高 - 追踪标题高)
	_quest_content.size = Vector2(追踪滚动宽, maxf(内容高 - 追踪标题高, 0.0))
	var 面板高 := 追踪标题高 if not _quest_expanded else 内容高
	if _quest_play_more != null and _quest_play_more.visible:
		_quest_play_more.position = Vector2(0.0,
			(追踪标题高 + 5.0) if not _quest_expanded else (内容高 + 15.0))
		面板高 += 更多可玩内容高 + (5.0 if not _quest_expanded else 15.0)
	_quest_tracker.size.y = 面板高

func _bind_minimap_buttons(root: Control) -> void:
	var minimap := root.get_node("小地图") as Control
	(minimap.get_node("展开收起钮") as Button).pressed.connect(_toggle_minimap)
	_activity_button = minimap.get_node("活动按钮") as TextureButton
	_gift_button = minimap.get_node("福利按钮") as TextureButton
	_info_button = minimap.get_node("信息按钮") as TextureButton
	_shield_button = minimap.get_node("屏蔽按钮") as TextureButton
	_voice_button = minimap.get_node("音量按钮") as TextureButton
	_activity_button.pressed.connect(_open_activity)
	_gift_button.pressed.connect(_open_gift)
	_info_button.pressed.connect(_open_info)
	_shield_button.pressed.connect(_toggle_shield)
	_voice_button.pressed.connect(_toggle_voice)
	(minimap.get_node("地图文字钮") as Button).pressed.connect(_open_map_info)
	(minimap.get_node("排行文字钮") as Button).pressed.connect(_open_ranking)
	(minimap.get_node("换线文字钮") as Button).pressed.connect(_cycle_channel)
	for 钮 in [_activity_button, _gift_button, _info_button, _shield_button, _voice_button]:
		_绑三态(钮)
		_设三态皮肤(钮)
	# 开关两颗的 tooltip 是**固定文案**，不随选中变：`SmallMapWindow.as:1058/1060` 只
	# `createToolTip` 一次，之后再没改过 text（改 tooltip 是我以前的自造）。
	# 原文带 `<font color="#00ff00">…</font>` 与 `<br/>`（`en_US$message_properties.as:1642/:59`），
	# Godot 的 tooltip 只能纯文本 ⇒ 去掉颜色标记、`<br/>` 换成换行。
	_shield_button.tooltip_text = "点击后将显示/遮罩其他玩家的人物及其名称\n遮罩其他玩家可以提高游戏的流畅效果"
	_voice_button.tooltip_text = "点击后将打开/关闭游戏音乐与音效"
	_绑常驻活动图标(minimap)
	_sync_quick_button_state()


## 小地图上那两个「常驻活动入口」—— 原版挂在 `_permanentActivityIconContainer`
## （`SmallMapWindow.as:220-221`，容器就在窗口原点），一共两件东西：
##   * `_huoyueduBtn`（:262-271）→ 点它开**活跃度**窗口
##   * `_activityPrizeBtn`（:305-323）→ 点它开**开心有礼**窗口（原版 `activityPrizeHandler` :1358）
## 两个按钮的坐标在场景里是**照抄 Flash 窗口坐标**的 —— 父容器 `常驻活动图标`
## 自己偏移了 −230，所以子节点写的就是 −26 / 14 这两个原始值。取真值过程见
## `测试/截图/入口图标_对照/真值对照表.md`。
## `活跃度光晕` 会呼吸，但**脚本里看不到动画**：原版 `onHuoyueduSD()`（:871-883）每帧把
## 半径 `_blue` 加 `_speed`、在 6↔20 之间反转 → 28 帧一个来回（`MainLib.xml:5` 24fps = 1.167 秒）。
## 这条周期整个烘进了 `素材/界面/专用控件/小地图活跃度光晕.tres`（AnimatedTexture，
## 逐帧时长 1/24 秒，28 帧由 `开发工具/烘焙活跃度光晕.py` 出），所以这里只连按钮、不 Tween。
## 等效高斯 σ 不是猜的：按参照帧逐列反解，σ(blurX=6)=1.8（`开发工具/拟合光晕半径.py`）。
##
## ⚠️ 但**挂不挂**这套光晕是看有没有奖励可领的：`setHuoyueduBtn(false)`（:418-433）会
## `filters = null` 并摘掉 ENTER_FRAME 监听，光晕整块消失；判据是
## `ActivityTaskWindow.setDataBottom:272-282` 的「下一档够分」。本工程把这条判据收在
## `游戏数据.活跃度可领`，`visible` 就是它的结果（2026-10-29 用户报"没奖励也一直闪"）。
func _绑常驻活动图标(minimap: Control) -> void:
	var 容器 := minimap.get_node_or_null("常驻活动图标") as Control
	if 容器 == null:
		push_error("小地图/常驻活动图标 找不到：两个活动入口按钮不会出现在小地图左边")
		return
	var 活跃度 := 容器.get_node_or_null("活跃度入口") as TextureButton
	var 礼包 := 容器.get_node_or_null("礼包入口") as TextureButton
	_活跃度光晕 = 容器.get_node_or_null("活跃度光晕") as TextureRect
	if 活跃度 == null or 礼包 == null or _活跃度光晕 == null:
		push_error("常驻活动图标 下缺 活跃度入口 / 活跃度光晕 / 礼包入口")
		return
	活跃度.pressed.connect(_open_huoyuedu)
	礼包.pressed.connect(_open_gift)
	_绑三态(活跃度)
	_设三态皮肤(活跃度)
	_绑三态(礼包, 容器.get_node("礼包入口/点击领取") as Label)
	_设三态皮肤(礼包)
	_刷新活跃度光晕()


func _于活跃度状态(_状态: Dictionary) -> void:
	_刷新活跃度光晕()


## `SmallMapWindow.setHuoyueduBtn:418-433` —— 有得领才挂光晕，没得领 `filters = null`。
## 光晕是烘好的 AnimatedTexture，停动画没有独立开关，所以按原版的最终观感整块显/隐。
func _刷新活跃度光晕() -> void:
	if _活跃度光晕 == null or not is_instance_valid(_活跃度光晕):
		return
	var 状态: Dictionary = {}
	if _backend != null:
		状态 = _backend.authoritative_activity
	_活跃度光晕.visible = 游戏数据.活跃度可领(状态)


## ── MButton3 三态（悬停 +30 / 按下 −40）────────────────────────────────
## 小地图上**每一颗图钮**在原版都是 `MButton3`：元件 293 的 channelBtn / searchBtn /
## largeBtn / voiceBtn / shieldBtn / expandBtn 在 `SmallMapWindow.as:73-201` 全声明成
## MButton3，六颗功能钮是 `SmallMap*BtnF extends MButton3`，两个入口是 `ProgramButton`，
## 追踪栏折叠钮是 `QuestTrackerWindow._expandBtn:MButton3`（:70）。
## 它们都**只有一张皮肤**，悬停/按下是运行时滤镜：
##   `MButton3.updateState()`（`MButton3.as:329-345`）→ `upSkin.filters = [getLightFilter(d)]`，
##   `StyleUtil.as:8-12` 的 `skinFilters = {up:0, over:30, down:-40}`，
##   `getLightFilter`（:43-47）是单位矩阵 + 第 5 列 R/G/B 各加 d ⇒ **加性**提亮、逐通道 clamp、**alpha 不动**。
## 文字不跟着变亮：`updateTextState()`（:520-528）换的是 `_textColors`（:69-74）。
##
## 为什么不用 Godot 自带的 `texture_hover` / `texture_pressed`，也不用 shader：
##  ① shader 挂在 `CanvasItem.material` 上会被子节点继承 —— 「点击领取」那颗 Label 会跟着变亮，
##     而原版只亮皮肤、文字换色，分工不同；
##  ② 原版 `mouseUpHandler`（:103-108）松开后回的是 **STATE_UP 而不是 OVER** —— 鼠标还停在上面
##     也不会再亮，要移出去再进来才重新 `ROLL_OVER`。`texture_hover` 做不到这条（松手仍显 hover）。
## 三态图由 `开发工具/生成小地图钮态图.py` 烘出来（幂等，逐字节等于上面那条公式），不是另画的美术。
## 文字钮（地图/排行/切线/展开/NPC 对话那两颗）不在这张表里 —— 它们是 `Button`，
## 三态由全局主题 `原版皮肤表.gd` 的 hover/pressed 负责；追踪栏两个页签另走
## `渐变文字.gdshader` 的亮度（见上面 `_页签亮度`）。
const _态皮肤 := {
	"活跃度入口": [
		preload("res://素材/界面/专用控件/小地图活跃度入口.png"),
		preload("res://素材/界面/专用控件/小地图活跃度入口_悬停.png"),
		preload("res://素材/界面/专用控件/小地图活跃度入口_按下.png"),
	],
	"礼包入口": [
		preload("res://素材/界面/专用控件/小地图礼包入口.png"),
		preload("res://素材/界面/专用控件/小地图礼包入口_悬停.png"),
		preload("res://素材/界面/专用控件/小地图礼包入口_按下.png"),
	],
	"亲热天堂钮": [
		preload("res://素材/界面/专用控件/小地图宝箱.png"),
		preload("res://素材/界面/专用控件/小地图宝箱_悬停.png"),
		preload("res://素材/界面/专用控件/小地图宝箱_按下.png"),
	],
	"宝石工艺钮": [
		preload("res://素材/界面/专用控件/小地图原石.png"),
		preload("res://素材/界面/专用控件/小地图原石_悬停.png"),
		preload("res://素材/界面/专用控件/小地图原石_按下.png"),
	],
	"首领刷新钮": [
		preload("res://素材/界面/专用控件/小地图首领.png"),
		preload("res://素材/界面/专用控件/小地图首领_悬停.png"),
		preload("res://素材/界面/专用控件/小地图首领_按下.png"),
	],
	"装备打造钮": [
		preload("res://素材/界面/专用控件/小地图强化.png"),
		preload("res://素材/界面/专用控件/小地图强化_悬停.png"),
		preload("res://素材/界面/专用控件/小地图强化_按下.png"),
	],
	"秘笈合成钮": [
		preload("res://素材/界面/专用控件/小地图技能书.png"),
		preload("res://素材/界面/专用控件/小地图技能书_悬停.png"),
		preload("res://素材/界面/专用控件/小地图技能书_按下.png"),
	],
	"意志背包钮": [
		preload("res://素材/界面/专用控件/小地图遗址.png"),
		preload("res://素材/界面/专用控件/小地图遗址_悬停.png"),
		preload("res://素材/界面/专用控件/小地图遗址_按下.png"),
	],
	## 竞技场那两颗（`SmallMapButtonBox.as:539-564` / `:391-404`）都是 `ProgramButton` = **MButton3 一族**：
	## 原版只有一张 upSkin，悬停 +30 / 按下 −40 是运行时加性滤镜（`StyleUtil.as:7-12`）⇒ 皮按同一条公式预烘。
	"竞技场钮": [
		preload("res://素材/界面/专用控件/小地图竞技场.png"),
		preload("res://素材/界面/专用控件/小地图竞技场_悬停.png"),
		preload("res://素材/界面/专用控件/小地图竞技场_按下.png"),
	],
	"排名奖钮": [
		preload("res://素材/界面/专用控件/小地图排名奖.png"),
		preload("res://素材/界面/专用控件/小地图排名奖_悬停.png"),
		preload("res://素材/界面/专用控件/小地图排名奖_按下.png"),
	],
	"活动按钮": [
		preload("res://素材/界面/通用界面/UISwf_Text.swf_22.png"),
		preload("res://素材/界面/通用界面/UISwf_Text.swf_22_悬停.png"),
		preload("res://素材/界面/通用界面/UISwf_Text.swf_22_按下.png"),
	],
	"信息按钮": [
		preload("res://素材/界面/通用界面/UISwf_Text.swf_25.png"),
		preload("res://素材/界面/通用界面/UISwf_Text.swf_25_悬停.png"),
		preload("res://素材/界面/通用界面/UISwf_Text.swf_25_按下.png"),
	],
	"福利按钮": [
		preload("res://素材/界面/通用界面/UISwf_Text.swf_28.png"),
		preload("res://素材/界面/通用界面/UISwf_Text.swf_28_悬停.png"),
		preload("res://素材/界面/通用界面/UISwf_Text.swf_28_按下.png"),
	],
	# 屏蔽 / 音量两颗是**开关**：原版 MButton3 有 upSkin + selectedUpSkin 两张皮
	# （`MButton3.as:136-142`、`drawSkin()` :341 按 `_selected` 选一张），
	# selected=true 就是"屏蔽中 / 已静音"（`SmallMapWindow.as:1497-1500`、`:1572-1574`
	# 把 selected 直接写进 SysCfg 的 hideCharAnimation / forbidMapBackgoundMusic）。
	# 两张皮分别来自元件 282/275 的 upSkin(#281/#274) 与 selectedUpSkin(#278/#271)。
	"屏蔽按钮": [
		preload("res://素材/界面/专用控件/小地图屏蔽.png"),
		preload("res://素材/界面/专用控件/小地图屏蔽_悬停.png"),
		preload("res://素材/界面/专用控件/小地图屏蔽_按下.png"),
	],
	"屏蔽选中": [
		preload("res://素材/界面/专用控件/小地图屏蔽_选中.png"),
		preload("res://素材/界面/专用控件/小地图屏蔽_选中_悬停.png"),
		preload("res://素材/界面/专用控件/小地图屏蔽_选中_按下.png"),
	],
	"音量按钮": [
		preload("res://素材/界面/专用控件/小地图音量.png"),
		preload("res://素材/界面/专用控件/小地图音量_悬停.png"),
		preload("res://素材/界面/专用控件/小地图音量_按下.png"),
	],
	"音量选中": [
		preload("res://素材/界面/专用控件/小地图音量_选中.png"),
		preload("res://素材/界面/专用控件/小地图音量_选中_悬停.png"),
		preload("res://素材/界面/专用控件/小地图音量_选中_按下.png"),
	],
	# 折叠钮两态各一组。展开=减号、收起=加号的判定过程见 `测试/截图/对照_分支按钮.png`
	# 那轮像素比对（与 减少按钮.png 不透明区平均差 1.50、与 增加按钮.png 差 27.35）。
	# 常态仍取共享的 通用控件/，只有派生的两态落在本页 专用控件/ —— 不往共享目录倒派生件。
	"折叠钮展开": [
		preload("res://素材/界面/原版窗口/通用控件/减少按钮.png"),
		preload("res://素材/界面/专用控件/减少按钮_悬停.png"),
		preload("res://素材/界面/专用控件/减少按钮_按下.png"),
	],
	"折叠钮收起": [
		preload("res://素材/界面/原版窗口/通用控件/增加按钮.png"),
		preload("res://素材/界面/专用控件/增加按钮_悬停.png"),
		preload("res://素材/界面/专用控件/增加按钮_按下.png"),
	],
}

## `_textColors` 的 up / over / down（16577692 / 16777155 / 11316658）。
## disabled 是 #939393，本页这几颗图钮没有禁用态，不列。
const _态文字色 := [Color("#fcf49c"), Color("#ffffc3"), Color("#acadb2")]

## 每颗钮的当前状态：钮 → {"皮肤": [三张], "态": 0..2, "文字": Label}
var _态实例: Dictionary = {}

## 挂上四颗信号。皮肤组由 `_设三态皮肤` 给（折叠钮两态各一组，所以拆成两步）。
## ⚠ 状态存在下面这张字典里，**不能用 `set_meta`**：Godot 4 的 metadata 键要求是合法
##    标识符，中文键直接报 `Invalid metadata identifier: '皮肤'` 并且**静默存不进去**。
func _绑三态(钮: TextureButton, 文字: Label = null) -> void:
	_态实例[钮] = {"皮肤": [], "态": 0, "文字": 文字}
	# 原版 `MButton3.init()`：`buttonMode = useHandCursor = true`（:135）
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.mouse_entered.connect(_设三态.bind(钮, 1))
	钮.mouse_exited.connect(_设三态.bind(钮, 0))
	钮.button_down.connect(_设三态.bind(钮, 2))
	钮.button_up.connect(_设三态.bind(钮, 0))

## 换一组三态皮肤（组名缺省=按钮名）。换完立刻按当前态重画，避免停在旧图。
func _设三态皮肤(钮: TextureButton, 组名: String = "") -> void:
	var 组: Array = _态皮肤.get(钮.name if 组名.is_empty() else 组名, [])
	if 组.is_empty():
		push_error("钮 %s 没登记三态皮肤：悬停/按下不会反馈" % 钮.name)
		return
	if not _态实例.has(钮):
		_绑三态(钮)
	_态实例[钮]["皮肤"] = 组
	_设三态(钮, int(_态实例[钮]["态"]))

func _设三态(钮: TextureButton, 态: int) -> void:
	var 记: Dictionary = _态实例.get(钮, {})
	if 记.is_empty() or (记["皮肤"] as Array).is_empty():
		return
	记["态"] = 态
	钮.texture_normal = (记["皮肤"] as Array)[态] as Texture2D
	var 文字 := 记["文字"] as Label
	if 文字 != null:
		文字.add_theme_color_override("font_color", _态文字色[态])


## 原版 `enterHuoyueduHandler()`（:818-821）→ `showActivityTaskWindow()`。
func _open_huoyuedu() -> void:
	if _session != null:
		_session.request_feature("活跃度")

func _bind_activity_buttons(root: Control) -> void:
	var activity_buttons := root.get_node("功能按钮")
	var pages := {
		"亲热天堂钮": "藏宝图",
		"宝石工艺钮": "挖矿",
		"首领刷新钮": "首领",
		"装备打造钮": "装备强化",
		"秘笈合成钮": "技能书",
		"意志背包钮": "遗址",
	}
	for node_name in pages:
		var button := activity_buttons.get_node(node_name) as BaseButton
		button.pressed.connect(_session.request_feature.bind(String(pages[node_name])))
		_绑三态(button as TextureButton)
		_设三态皮肤(button as TextureButton)
	## ── 竞技场那两颗（`SmallMapButtonBox` 数组第 12、15 位）────────────────────────
	## 原版是"条件成立才 `addChild`、不成立就 `removeChild`"⇒ 件本身烘在场景里、这里只翻 `visible`，
	## 判据一条都不许自己另算（编辑器里看得见这两颗 = 与运行期同一份摆位，见 [[editor-runtime-parity]]）。
	_竞技场钮 = activity_buttons.get_node_or_null("竞技场钮") as TextureButton
	_排名奖钮 = activity_buttons.get_node_or_null("排名奖钮") as TextureButton
	for 钮 in [_竞技场钮, _排名奖钮]:
		if 钮 == null:
			continue
		_绑三态(钮)
		_设三态皮肤(钮)
	if _竞技场钮 != null:
		_竞技场钮.pressed.connect(_开竞技场)
	if _排名奖钮 != null:
		_排名奖钮.pressed.connect(_领排名奖)
	## 等级那道闸要跟着升级走；`2306:11`（`onPk_updateAwardStat`）到了要立刻改那枚领奖钮。
	if _session != null and _session.has_signal("player_stats_changed"):
		_session.connect("player_stats_changed", func(_状态: Dictionary) -> void: _刷竞技钮())
	if _backend != null and _backend.has_signal("竞技场帧"):
		_backend.connect("竞技场帧", _于竞技帧)
	_刷竞技钮()


## `SmallMapButtonBox.showPvpButton:539-564`：`stats.level >= PVP_ENTER_LEVEL` **且** `PvpManager.isOpen`。
## `isOpen` 在 AS3 全工程只出现在 `PvpManager.as:38` 那一行 `= true`（没有任何写入点）⇒ 恒真，照原样算。
## `showHaiPangPrizeButton:391-404`：`onPk_updateAwardStat:136-148` 只在 `awardStat == PkAwardStat.NOT_AWARDED`(1)
## 时点亮那枚领奖钮（0 未上榜 / 2 本期已领都撤）。
func _刷竞技钮() -> void:
	var 等级 := 1
	if _session != null:
		等级 = maxi(1, int((_session.get("player_stats") as Dictionary).get("level", 1)))
	if _竞技场钮 != null and is_instance_valid(_竞技场钮):
		_竞技场钮.visible = 等级 >= 竞技场门槛
	if _排名奖钮 != null and is_instance_valid(_排名奖钮):
		_排名奖钮.visible = 竞技场窗脚本.奖状态 == 1


func _于竞技帧(动作: int, 值: Dictionary) -> void:
	if 动作 == 11:
		## 原样照 `onPk_updateAwardStat(param1, param2)`：那颗钮的显隐吃的是**这一帧带来的那两个数**，
		## 不是回头去读控制器上的那份存档（两条连接谁先跑都能得出同一个结果）。
		if _排名奖钮 != null and is_instance_valid(_排名奖钮):
			_排名奖钮.visible = int(值.get("状态", 0)) == 1


## `enterJingJiChangHandler:510-517` = 先过 `HuSongQuestManager.enblePve()` 那道闸，再 `showPvpWindow()`。
## ⚠ 那道闸读的是 `isInHuSong`（护送进行中，`HuSongQuestManager.as:270-277`），本工程客户端没有这份状态
##   （欠在 #209）⇒ 这里只接后半，**不许拿"看起来一样"的旗当它存在**；差异记 `真值/窗口/竞技场.md` §未收口。
func _开竞技场() -> void:
	if _session != null:
		_session.request_feature("竞技场")


## `getPaiHangPrizeHandler:500-503` = `API.client.PK_gainPaiHangPrize()` ⇒ 上行 `2306:5`；
## 服务端 `_claim_arena_rank_prize:29814-29844` 要么回 `2306:8:<名次>:<阅历>` + `2306:11:<名次>:2`（真发奖），
## 要么只回一条 `2306:11:<名次>:<2|0>`（本期已领 / 名次不在奖表）。
func _领排名奖() -> void:
	if _backend != null:
		_backend.call("request_arena_rank_prize")

func _toggle_minimap() -> void:
	_minimap_expanded = not _minimap_expanded
	_minimap_content.visible = _minimap_expanded
	for node_name in ["小地图底图框", "地图名", "活动按钮", "福利按钮", "信息按钮", "屏蔽按钮", "音量按钮", "地图文字钮", "排行文字钮", "换线文字钮"]:
		var node := _minimap_panel.get_node_or_null(node_name) as CanvasItem
		if node != null:
			node.visible = _minimap_expanded
	(_minimap_panel.get_node("展开收起钮") as Button).tooltip_text = "收起小地图" if _minimap_expanded else "展开小地图"

func _toggle_shield() -> void:
	_shield_selected = _shield_button != null and _shield_button.button_pressed
	## ⚠ 这颗钮**不动小地图上的标记**：原版 `shieldHandler`（SmallMapWindow.as:1495-1501）写的三个
	## 开关是 `hideCharAnimation / hideCharName / hideOthersSkillEffect` —— 屏蔽的是**世界里的其他玩家**
	## （动画、名字、技能特效），跟 minimap 的 charElseContainer 没关系。
	## 旧代码在这里多写了一句 `_minimap.hide_other_characters = …`，是把两件事混成一件事的自造，删掉。
	if _session != null:
		_session.update_setting("show_other_characters", not _shield_selected)
		_session.update_setting("show_skill_effects", not _shield_selected)
	_apply_quick_button_visual(_shield_button, _shield_selected)

func _toggle_voice() -> void:
	# 原版 `voiceHandler`（SmallMapWindow.as:1570-1575）：先翻按钮自己的 selected，
	# 再把**同一个值**同时写进"静音音乐"和"静音音效"。这里必须用局部量 ——
	# 上一版直接读成员 `_voice_selected`，而写第一条设置时 `settings_changed`
	# 会重算那个成员，第二条就被改回去了。
	var 选中 := _voice_button != null and _voice_button.button_pressed
	_voice_selected = 选中
	if _session != null:
		_session.update_setting("mute_music", 选中)
		_session.update_setting("mute_sound", 选中)
	_apply_quick_button_visual(_voice_button, 选中)
	_voice_button.tooltip_text = "开启声音" if 选中 else "关闭声音"

func _open_activity() -> void:
	if _session != null:
		_session.request_feature("活动")

func _open_gift() -> void:
	if _session != null:
		_session.request_feature("福利")

func _open_info() -> void:
	if _session != null:
		_session.request_feature("信息")

func _open_map_info() -> void:
	if _session != null:
		_session.request_feature("地图信息")

func _open_ranking() -> void:
	if _session != null:
		_session.request_feature("排行榜")

func _sync_quick_button_state() -> void:
	if _session == null:
		return
	_shield_selected = not bool(_session.game_settings.get("show_other_characters", true))
	_同步音量按钮()
	_shield_button.button_pressed = _shield_selected
	_apply_quick_button_visual(_shield_button, _shield_selected)
	var channel_button := _minimap_panel.get_node("换线文字钮") as Button
	channel_button.text = "%d线" % int(_session.current_channel)
	channel_button.tooltip_text = "当前线路：%d线" % int(_session.current_channel)

## 原版 `SysCfg.checkMusicCheckBox()`（`SysCfg.as:325-331`）：**只有"静音音乐"和
## "静音音效"两条相等时**才把值回写到小地图那颗音量钮上，不相等就保持按钮原样 ——
## 因为设置窗口里音乐/音效是**两个独立勾选框**（`功能窗口.gd:2221-2235` 对应的
## `SysCfg` 那两条），本来允许不一致。
## 老写法 `mute_music and mute_sound` 会无条件回写，并且抢改 `_voice_selected`
## 成员：`_toggle_voice()` 刚写完第一条、还没写第二条时就被它算成 false，
## 于是第二条又被写回 false —— 实测表现就是"点了没反应"（`toggled` 连发两次）。
func _同步音量按钮() -> void:
	if _session == null or _voice_button == null:
		return
	var 静音音乐 := bool(_session.game_settings.get("mute_music", false))
	var 静音音效 := bool(_session.game_settings.get("mute_sound", false))
	if 静音音乐 != 静音音效:
		return
	_voice_selected = 静音音乐
	# `set_pressed_no_signal` 才等价于原版那句 `voiceBtn.selected = x`：
	# 直接赋 `button_pressed` 会再发一次 `toggled`，形成回环。
	_voice_button.set_pressed_no_signal(静音音乐)
	_apply_quick_button_visual(_voice_button, _voice_selected)

## 开关两颗的"选中"**不是染色，是换一张皮**（原版 MButton3 的 selectedUpSkin）。
## 以前这里用 `self_modulate = (0.55,0.72,0.82)` 假装选中态 —— 那是自造的，原版没有。
func _apply_quick_button_visual(钮: TextureButton, 选中: bool) -> void:
	if 钮 == null:
		return
	_设三态皮肤(钮,
		("屏蔽选中" if 钮 == _shield_button else "音量选中") if 选中 else String(钮.name))

func _cycle_channel() -> void:
	if _session == null:
		return
	_session.set_channel(int(_session.current_channel) % 3 + 1)
	var button := _minimap_panel.get_node("换线文字钮") as Button
	button.text = "%d线" % int(_session.current_channel)
	button.tooltip_text = "当前线路：%d线" % int(_session.current_channel)

const NPC对话窗脚本 := preload("res://脚本/界面/窗口/NPC对话窗.gd")
var _对话: Node = null


func _bind_fixed_overlays(root: Control) -> void:
	# 旧那枚「单格 + 一枚服务钮」的假气泡 **2026-10-11 §3.106 退役**（作者 §11-3）：
	# 原版 `QuestDialog` 是两格上下叠 + 手形菜单行，新窗由 `NPC对话窗.gd` 现建
	# （烘在 `场景/界面/窗口/NPC对话/NPC对话窗.tscn`）。旧节点连那棵子树一起从场景里删了 ——
	# 它身上只有 `NPC名称/对话内容` 被**当台词源**读（现在改成普通 String，见上面 var 段），
	# 那枚「服务按钮/关闭按钮」本来就是死的（新窗自己出菜单行、自己有关闭）。
	_对话 = NPC对话窗脚本.new()
	_对话.name = "原版NPC对话窗"
	root.add_child(_对话)
	_对话.connect("行被点", _开NPC菜单页)
	## 通知条在**单独的 CanvasLayer 350** 下（原版 `MessageTipPane` 摆在 0.6W/0.6H、盖在所有窗口上）。
	## ⚠ 它是本 CanvasLayer（小地图面板）的直接子树，**不在** `小地图区域` 里 ⇒ 从 self 取，不走 `root`。
	_toast = get_node("通知层/通知区域/通知条") as Label

## ↓ 表机器（小地图包）：菜单/落地表全部由 `数据/界面/木叶村NPC.json` 现算
## 给行为门用的两个入口：读当前菜单行文字、按第 i 行（走的是与点击完全相同的代码路径）。
func npc对话菜单行() -> Array[String]:
	return [] if _对话 == null else (_对话.call("行文字表") as Array[String])


## 木叶村 25 枚 NPC 的菜单表与「动作值 → 落地」。表由 `开发工具/出木叶村NPC表.py`
## 照 `fake_flash_server.py:10891-10929 + 52313-52329` 导出来 ⇒ 客户端**不自己发明菜单**。
## ⚠ `JSON.parse_string` 会把数字全解成 float ⇒ 这里每个取数都 `int()`（少一个就打成 "12.0"）。
const NPC表路径 := "res://数据/界面/木叶村NPC.json"
static var _NPC行: Dictionary = {}
static var _落地: Dictionary = {}
## 328 帧的 **selection 段**（任务行）与 menu 段是两种东西 ⇒ 单独一张表：
## `_任务行[npc_id] = [[文字, 落地页, 任务id], …]`、`_任务落地[任务id] = [落地页, 文字]`（在线帧只带 id，靠它查页）。
static var _任务行: Dictionary = {}
static var _任务落地: Dictionary = {}
## 表里 `任务行` 那一段的**原始字典**（含 类型/上限/次数/任务状态）⇒ selection 链接块要按
## 原版那套拼文案，压缩成 [文字, 页, id] 就不够用了。
static var _任务原文: Dictionary = {}	## npc 编号 → 表里那几条任务行（原始字典）
static var _任务按号: Dictionary = {}	## 任务id → 同一条（帧里只带 id，类型/上限要回表查）

static func _读NPC表() -> void:
	if not _NPC行.is_empty():
		return
	var 解: Variant = JSON.parse_string(FileAccess.get_file_as_string(NPC表路径))
	if typeof(解) != TYPE_DICTIONARY:
		return
	for 条v in (解 as Dictionary).get("npc", []):
		var 条: Dictionary = 条v
		var 行: Array = []
		for rv in 条.get("菜单", []):
			var r: Dictionary = rv
			var 文字 := String(r["文字"])
			var 码 := int(r["动作"])
			行.append([文字, 码])
			if 码 == -1 or _落地.has(码):
				continue
			_落地[码] = {"页": String(r.get("落地页", "")), "名": 文字,
					"原版类": String(r.get("原版类", "")), "状态": String(r.get("状态", ""))}
		var 任: Array = []
		for tv in 条.get("任务行", []):
			var t: Dictionary = tv
			var 页 := String(t.get("落地页", ""))
			任.append([String(t["文字"]), 页, int(t["任务id"])])
			if not 页.is_empty():
				_任务落地[int(t["任务id"])] = [页, String(t["文字"])]
		_NPC行[String(条["id"])] = 行
		_任务行[String(条["id"])] = 任
		_任务原文[String(条["id"])] = 条.get("任务行", []) as Array
		for 任v in (条.get("任务行", []) as Array):
			_任务按号[int((任v as Dictionary)["任务id"])] = 任v as Dictionary


## 给行为门与 `show_npc_dialog` 用：这枚 NPC 的原版菜单行（[文字, 动作值]）。
func NPC菜单行(npc_id: String) -> Array:
	_读NPC表()
	var 出: Array = (_NPC行.get(npc_id, []) as Array).duplicate(true)
	# ⚠ 2026-10-05 改：`任务行`（328 帧第 6 段 selection）**不再当菜单行返回** ——
	#   原版把它拼成一块居中的富文本链接（`QuestDialog.as:249-345`，实机图上就是
	#   「[日环]每日环任务(1/20)（可接）」那两行绿色下划线），画在下格右侧。
	#   要它请走 `NPC选择行(npc_id)`。
	return 出


## 328 帧第 6 段的一条 → 对话窗 `选择` 条目。帧里的编码是
## `文字&questId&任务状态&次数&上限&questId`（`_解析NPC任务行` 已解），**类型帧里没有**
## ⇒ 按 questId 回表查（原版同样是拿 questId 去任务配置里查 `getQuestType`）。
func _选择条目(帧: Dictionary) -> Dictionary:
	var 号 := int(帧.get("任务id", 0))
	var 出 := {"文字": String(帧.get("文字", "")), "任务id": 号,
			"任务状态": int(帧.get("状态", 0)), "次数": int(帧.get("次数", 0)),
			"上限": int(帧.get("上限", 0))}
	_读NPC表()
	var 落: Array = _任务落地.get(号, []) as Array
	var 条: Dictionary = _任务按号.get(号, {}) as Dictionary
	出["类型"] = String(条.get("类型", ""))
	if int(出["上限"]) == 0:
		出["上限"] = int(条.get("上限", 0))
	## NPC 表那份 `任务行` 只覆盖**有本地落地页**的那几扇 ⇒ 普通主线/支线查不到类型，
	## `[主线]` 前缀就会掉。原版是 `getQuestType(quest)` 拿 id 去**任务配置**查（`QuestDialog.as:267`），
	## 这里同口径回 `_追踪定义`（= `数据/任务.json`）的 `info.type` 再查一次。
	if String(出["类型"]) == "":
		var 定 := _追踪定义.get(str(号), {}) as Dictionary
		var 信: Dictionary = 定.get("info", {}) as Dictionary
		出["类型"] = String(信.get("type", ""))
		if int(出["上限"]) == 0:
			出["上限"] = int(信.get("loopCount", 0))
	# 原版 `selectionLinKHandler`：这一行的 href **就是任务 id** ⇒ 点它发 `57:3:<任务id>`，
	# 由服务端决定接取/对话目标/交付。已移植的那几扇（日环/护送/兑换/卡片…）再额外开本地页。
	出["值"] = 号
	出["本地"] = null if 落.is_empty() or 号 in [8001, 8002] else _本地开页.bind(String(落[0]), String(出["文字"]))
	return 出


## 离线（没收到 328）时按表给 selection 条目 ⇒ 与在线同一套文案、同一个落地页。
func NPC选择行(npc_id: String) -> Array:
	_读NPC表()
	var 出: Array = []
	for 条v in (_任务原文.get(npc_id, []) as Array):
		var 条: Dictionary = (条v as Dictionary).duplicate(true)
		条["值"] = _本地开页.bind(String(条.get("落地页", "")), String(条.get("文字", "")))
		出.append(条)
	return 出


## 任务行点击的落点：只开本地页，一个协议包都不发。
func _本地开页(页: String, 名: String) -> void:
	if 页.is_empty():
		show_notification("「%s」还没移植" % 名)
	elif _session != null:
		_session.request_feature(页)


## 原版是**收到回帧才开窗**（`Client.as:1210-1212` / `:1149-1151`），本工程那几扇都挂在
## `功能窗口` 的页上 ⇒ 这一跳按表落地：有页就开，**没移植的只说清缺哪扇，不自造窗**。
var _落地等待 := ""

var _落地截止 := 0

func npc对话点行(序号: int) -> void:
	if _对话 != null:
		_对话.call("按下行", 序号)


func _open_npc_service() -> void:
	if _session != null:
		if not _dialog_action_page.is_empty():
			_session.request_feature(_dialog_action_page)
		else:
			_session.open_npc_service(_dialog_npc_id)

func _connect_session() -> void:
	if _session == null:
		return
	_session.quest_changed.connect(_on_quest_changed)
	_session.notification_requested.connect(show_notification)
	_session.settings_changed.connect(_sync_quick_button_state.unbind(1))
	# 纲手菜单落地**等回帧**（2026-10-04 服务端打通）：817/0 → 副本页、1828/0 → 精英副本页。
	# ⚠ 这两行是"等回帧"那条路的**唯一连接点**；没有它们，点了 12/30 只会静默等 5 秒然后什么都不开。
	_session.copy_changed.connect(_on_copy_landed)
	_session.hero_state_changed.connect(_on_hero_landed)
	## 换图必须重接：缩略图、miniMap 规格、门表全跟着地图走
	## （原版是 `Client.as:8507-8530` 在进图包里重推一遍 `setMap`）。
	if _session.has_signal("map_changed"):
		_session.map_changed.connect(_于换图)
	if _session.has_signal("quests_changed"):
		_session.quests_changed.connect(func(_a, _b): _刷标记())

func _于换图(_新图: String) -> void:
	_接地图()

func _refresh_all() -> void:
	if _session == null:
		return
	_on_quest_changed(_session.active_quest)
	_map_name.text = _session.call("get_map_name", String(_session.current_map_id))

func _on_quest_changed(_quest: Dictionary) -> void:
	if _quest_show_accepted:
		_refresh_quest_list()

func _load_map_data() -> Dictionary:
	var map_id := String(_session.current_map_id) if _session != null else "101010000"
	var file := FileAccess.open(MAP_RESOURCES.map_data_path(map_id), FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	if text.begins_with("﻿"):
		text = text.substr(1)
	var parsed = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

## 换图 / 换场景 / 开局都要走这一条：重新读地图.json、重新取缩略图、重新算标记。
## 原版对应 `Client.as:8507-8530`（进图时 `PicTool.getMiniMap` + `getPortalsByFilter({pt:2})` → `setMap`）。
func _接地图() -> void:
	if _minimap == null:
		return
	_map_data = _load_map_data()
	var 规格: Dictionary = _map_data.get("miniMap", {}) as Dictionary
	var 藏 := 该藏(_map_data)
	## 原版：`PicTool.as:456-459` hideMinimap==1 就返回 null ⇒ `Client.as:8508-8511` 把整块小地图
	## （框、钮、标记一起）藏掉，不是只藏图。没有 miniMap 段同理。
	_minimap_panel.visible = not 藏
	var 图: Texture2D = null
	var 路 := MAP_RESOURCES.minimap_path(String(_session.current_map_id) if _session != null else "101010000")
	if 路 != "" and ResourceLoader.exists(路):
		图 = load(路) as Texture2D
	_minimap.装载(规格, 图)
	_刷标记()

## 整块小地图要不要藏起来。**原版这一条在取图那一步就决定了**：
## `PicTool.as:456-459` 见 `info.hideMinimap == 1` 直接返回 null ⇒
## `Client.as:8508-8511` 走 `setDOShow2(smallMapWindow, false)` —— 连框带钮一起藏。
## 没有 miniMap 段是同一个出口（`PicTool.as:462` 那个 `if (null != _loc5_)` 不成立也返回 null）。
static func 该藏(数据: Dictionary) -> bool:
	var 规格: Dictionary = 数据.get("miniMap", {}) as Dictionary
	if 规格.is_empty():
		return true
	return int((数据.get("info", {}) as Dictionary).get("hideMinimap", 0)) == 1

## 标记表（锚点/贴图路径）：**只从 json 读，不在这儿写死任何数**。
static func _读标记表() -> Dictionary:
	var 文 := FileAccess.open(标记表路, FileAccess.READ)
	if 文 == null:
		return {}
	var 解 = JSON.parse_string(文.get_as_text())
	if typeof(解) != TYPE_DICTIONARY:
		return {}
	return (解 as Dictionary).get("标记", {}) as Dictionary

func _玩家世界位() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return Vector2.INF		# 画布拿 INF 当「没有玩家」，不挪面板也不画自己
	return _player.global_position

## 场上的怪（§3.117）。原版这一族的来路：
##   · 加：`Monster.addToSmallMap:1849-1856` → `SmallMapHandler.addMob:188-208`
##     （payload = `{id, mobid, x, y, name: getMobName(), type: mobInfo.boss}`；
##      `hideMob == 1` 时**直接不加**）；
##   · 挪：`SmallMapHandler.tick:137-178` 每 tick 看 `mob.positionChange` ⇒ `udpatedMobPos`；
##   · 皮：`SmallMapHelper.getMobMC:76-89` —— **0 普通 / 1 首领 / 2 精英**。
## 我们这边：位置跟着 LifeRoot 上的实体走（与 NPC 同一套，`_刷标记()` 每 0.5 秒重取），
## 皮按**静态表**取 —— `数据/怪物.json` 的 `boss` 字段本来就有（1574 条：0 共 723 / 1 共 824 / 2 共 27），
## 所以欠账里那句"`mobInfo.boss` 未导出"**已经不成立**（导出器后来补上了）。
func _场上怪() -> Array:
	var 出: Array = []
	var 场 := get_tree().current_scene
	if 场 == null:
		return 出
	var 根 := 场.get_node_or_null("LifeRoot")
	if 根 == null:
		return 出
	for 条 in 根.get_children():
		if str(条.get("kind")) != "m" or not (条 is Node2D):
			continue
		出.append({
			"类": _怪皮(str(条.get("entity_id"))),
			"位": (条 as Node2D).global_position,
			# 悬停提示那句 = 原版 `getMobName()`；`display_name` 由 `_configure_actor:677-682` 从
			# `会话.get_mob_name(id)` 填（离线/在线同一个口径）。
			"名": str(条.get("display_name")),
		})
	return 出


## 怪的皮：`SmallMapHelper.getMobMC:76-89` 的三分支（0/1/2），其余一律走普通。
func _怪皮(怪物id: String) -> String:
	match int((游戏数据.monster(怪物id) as Dictionary).get("boss", 0)):
		1:
			return "minimap_mobBoss_skin"
		2:
			return "minimap_mobJingYing_skin"
		_:
			return "minimap_mob_skin"


## 场上要画的那些人：原版是**生成包驱动的**（`Client.as:6467-6482 onSpawnNPC` → `addNpc`），
## 不是把 地图.json 的 life 段一次全画出来 —— 所以这里跟着 LifeRoot 上的实体走。
func _场上实体() -> Array:
	var 出: Array = []
	var 场 := get_tree().current_scene
	if 场 == null:
		return 出
	var 根 := 场.get_node_or_null("LifeRoot")
	if 根 == null:
		return 出
	for 条 in 根.get_children():
		## ⚠ 一律 `str()`：远程玩家是裸 Node2D、没有 kind 属性，`String(null)` 会当场把整段带走
		## （工程里栽过一次，见 测试/点角色不崩回归测试.gd）。
		var 类 := str(条.get("kind"))
		if 类 != "n" or not (条 is Node2D):
			continue
		# 名字一并带走（悬停提示用，§3.105）：`display_name` 是演员脚本上的属性，
		# 建 NPC 时由 `地图实体.gd:679-680` 从 `get_npc_info(id).name` 填。
		出.append({"号": str(条.get("entity_id")), "位": (条 as Node2D).global_position,
				"名": str(条.get("display_name")),
				# 服务端的 `513` 键是 **object_id**（每图重新分配），模板 id 撞不上 ⇒ 两个都带走
				"对": int(str(条.get("object_id")).to_int()) if str(条.get("object_id")).is_valid_int() else 0})
	return 出


func _刷标记() -> void:
	if _minimap == null:
		return
	var 新组 := {"npc": [], "传送点": [], "怪": []}
	## 怪：原版 `SmallMapHandler.addMob:190-195` 的头一句就是 `hideMob == 1 ⇒ 不加`
	## （`地图.json` 的 miniMap 段；实测 177 张有 miniMap 的图里**只有 2 张**是 1）。
	## ⚠️ 读的是**面板自己的** `_map_data`（`规格` 是画布那层的成员、面板层没有这个名字 ——
	##    第一版就是在这儿写成 `规格.get(...)` 的，会直接 Parse Error）。
	var 迷你规格: Dictionary = _map_data.get("miniMap", {}) as Dictionary
	if int(迷你规格.get("hideMob", 0)) != 1:
		新组["怪"] = _场上怪()
	## 传送点：`Client.as:8515` 的过滤条件是 **pt == 2**（不是"有 tm 就算门"），
	## 名字走 `StringTool.getMapString(tm)`（:8523）⇒ 悬停提示要的那句。
	var 门: Variant = _map_data.get("portal", {})
	var 门表: Array = 门.values() if 门 is Dictionary else (门 as Array if 门 is Array else [])
	for 项 in 门表:
		if not (项 is Dictionary) or int((项 as Dictionary).get("pt", 0)) != 2:
			continue
		新组["传送点"].append({
			"类": "minimap_portal_skin",
			"位": Vector2(float((项 as Dictionary).get("x", 0.0)), float((项 as Dictionary).get("y", 0.0))),
			"名": _门名(int((项 as Dictionary).get("tm", 0))),
		})
	if _session != null:
		for 条 in _场上实体():
			## **头顶标记与小地图标记必须同一个来源**：原版是一条 `513` 帧在
			## `NPCHandler.as:149-157` 里同时做 `NPC.setQuestStatus()` 与
			## `SmallMapHandler.setNpcStatus()`。所以这里走 `会话.npc_quest_status()`
			## （在线优先读 513，没收到才回退本地倒推），**不再**各读各的 `NPC任务状态()`
			## —— 两头各算一份就会一个亮一个不亮。
			新组["npc"].append({
				"类": String(MinimapCanvas.NPC态[int(_session.call("npc_quest_status", String(条["号"])))]),
				"位": 条["位"],
				"号": 条["号"],
				# ⚠️ `对`（object_id）留在标记字典里供门与悬停定位这一枚实体：
				#    `会话.npc_quest_status()` 比的是**模板号**（`号`），不看 `对`。
				#    第一版只在 `_场上实体()` 里带了、标记字典漏了 ⇒ 门（4 条）当场抓出来。
				"对": int(条.get("对", 0)),
				# 悬停提示那句（§3.105）：原版 `SmallMapWindow.as:662`
				# `getNPCMC(param1.name, 0, param1.funcType)` —— 名字就是实体自己的
				# `display_name`（`地图实体.gd:679-680` 建 NPC 时从 `get_npc_info(id).name` 填）。
				"名": String(条.get("名", "")),
			})
	_minimap.组 = 新组
	_minimap.queue_redraw()

## 点小地图 ⇒ 寻路到那一处。原版 `onClickMapToFindPath`（`SmallMapWindow.as:1125-1138`）一共做七件事：
## `playerKeyEnable` 闸 → `toAttackAnemy=false` / `cancelCapture()` / `stopCaptureSword()` /
## `resetCurItemGotoPickup()` / `cancelGoToDoubleHeal()` / **`guajiHandler.isStart = false`（停托管）**
## → `pathFind(面板mouseX*16 − centerX, 面板mouseY*16 − centerY, 0, true)`。
## 本工程只有其中两条对得上：**`自动接近目标`**（点怪那条一次性命令，`玩家.gd:47`）与角色走位
## （`玩家.走向()` 里那套落脚点/梯子/跳跃路线规划，点世界走的就是它）。
## 抓宠、双倍治疗、停托管这些**没有对应实现或要发帧** ⇒ 不碰，只在托管开着时把差别说出来。
const 寻路失败 := "自动寻路失败"	# 逐字：`en_US$message_properties.as:1346` PATH_FIND_FAIL
const 托管挡路 := "挂机中：原版这里会停掉托管（guajiHandler.isStart=false），本工程不碰挂机状态 ⇒ 路线可能被托管换掉"

func _点小地图寻路(世界: Vector2) -> void:
	var 玩 := get_tree().get_first_node_in_group("player") as Node
	if 玩 == null or not 玩.has_method("走向"):
		show_notification(寻路失败)
		return
	if 玩.get("自动接近目标") != null:
		玩.set("自动接近目标", null)
	## 原版 `SmallMapWindow.as:1137`：`pathFind(x*16−centerX, y*16−centerY, 0, **true**)`
	## —— 第 4 参就是 showtip ⇒ 点小地图一定亮「自动寻路中」。
	if not bool(玩.call("走向", 世界, true, true)):
		show_notification(寻路失败)
		return
	if _session != null and bool(_session.hang_state.get("active", false)):
		show_notification(托管挡路)

func _门名(目标图: int) -> String:
	## 原版悬停提示上的那句地名 = `StringTool.getMapString(portal.tm)`（Client.as:8523），
	## 走的是同一张地图名表 ⇒ 复用 会话.get_map_name，不在这儿自己拼。
	if 目标图 <= 0 or _session == null:
		return ""
	return String(_session.call("get_map_name", str(目标图)))

## ⚠ 「一枚 NPC 顶哪一档」这件事**不在本文件里判**。
## 原版是服务端逐枚推 `onUpdateQuestStatusPacket(npcId, status)`（`Client.as:5079-5085` →
## `NPCHandler.as:149-157` 同时喂头顶与 `SmallMapHandler.setNpcStatus:259`），本工程接了那条
## `513`，两侧都走 `会话.npc_quest_status()`（口径与出处写在 `游戏会话.gd:366-397`）。
## 这里原来有一份 `static func NPC任务状态()` 自己倒推，`_刷标记` 改走会话之后**没有任何调用者**，
## 而门还在测它 —— 门绿着、真链零覆盖，2026-10-09 查 #148 时一并删掉。

func _label(pos: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

class MinimapCanvas extends Control:
	## 原版 `SmallMapWindow` 里那块会滚的地图 = `_mapPanel`（:1027）+ 它的七个容器（:1043-1050）。
	## 三条口径只从 AS3 来，逐条登记在 `数据/界面/小地图标记.json` 的「真值」里：
	##  * **显示尺寸 = 贴图原生尺寸 × miniMap.scale/16**（`setMap:1442` 给位图上的那个 scale），
	##    与 `miniMap.width/16 × height/16`（`PicTool.as:473-474`）等价。
	##    ⚠ 旧写法是「按 VR 线性映射塞进框」—— 于是 480×280 的缩略图被压进 152×126，
	##    看着有图，其实比例、可见范围、每个标记的位置全跟着错。
	##  * **世界→图素 = ((x + centerX)/16, (y + centerY)/16)**（`setMcPosition:857-858`）。
	##    VR 是可行走范围，缩略图画的是整张 canvas，两者差着 centerX/centerY 那一截。
	##  * **滚动是死区跟随，不是居中跟随**（`setPlayerPosition:444-469`）：玩家越过 1/5、4/5
	##    两条线才挪面板，挪完 `Math.round`（:468-469）。居中跟随 = 每走一步地图抖一下。
	## 锚点（贴图左上角相对标记点的偏移）不许在这里推：全部读 `小地图标记.json`，
	## 那张表由 `开发工具/出小地图标记表.py` 从 `Effect_mapHelper.swf` 的形状框解析出来 ——
	## 实测这批元件是**底边对齐 + 水平居中**（人形脚踩坐标点、「!」长在头顶上），
	## 拿「PNG 尺寸减一半」自己编会错 1px 以上，而 1px 在 143×124 的小图上是看得见的。
	const 视口宽 := 143.0		# SmallMapWindow.as:55-57 MAX_WIDTH == MIN_WIDTH ⇒ 视口恒 143
	const 视口高 := 124.0		# :59-61
	## `_mapPanel.addChild` 的序（:1043-1050）。原版把 portContainer 连加两次（:1047-1048），
	## 那是重复添加的无害 bug，不影响画序 ⇒ 这里只留一份。
	const 画序 := ["图", "npc", "他人", "怪", "传送点", "旗", "自己"]
	## 任务态 → 元件名（`SmallMapHelper.as:47-63 getNPCMC`；状态值 = `NpcQuestStatus.as:7-12`）
	const NPC态 := {0: "minimap_npc_skin", 1: "minimap_startnpc_skin", 2: "minimap_endnpc_skin", 3: "minimap_questing_skin"}

	## 点小地图要寻路（原版 `_mapPanel` 上挂了 CLICK ⇒ `onClickMapToFindPath`，:1080-1083 与 :1125-1138）。
	## 发的是**世界坐标**：换算在 `_世界位()` 里做，宿主只管交给角色。
	signal 点了寻路(世界: Vector2)

	var 规格 := {}			# 地图.json 的 miniMap 那一段（width/height/centerX/centerY/scale/hideMob）
	var 贴图: Texture2D
	var 标记表 := {}			# 数据/界面/小地图标记.json 的「标记」
	var 组 := {}				# 组名 → Array<[{"类": String, "位": Vector2 世界坐标}]>
	var 玩家: Callable		# -> Vector2 世界坐标；拿不到就不挪面板、也不画自己
	var 面板偏移 := Vector2.ZERO
	var 图尺寸 := Vector2.ZERO
	var 可视 := Vector2.ZERO		# mapWidth/mapHeight（:1078-1094：图比视口小就跟着变小、且不滚）
	var 图层: MinimapPicture
	var _皮缓存 := {}
	var _上次 := ""

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST	# 标记 1:1 贴，必须 NEAREST（平滑会把 10×12 的小人糊掉）
		clip_contents = true					# 原版是 _mapPanel.mask = _mapMask（:1040-1051）
		## 原版 `_mapPanel` 挂了 CLICK 监听 ⇒ 这一块**要吃鼠标**（点它就该寻路，而不是穿过去点世界）。
		## ⚠ 但**不设手型光标**：Flash 只 addEventListener（:1080-1083），没给 `_mapPanel` 设 buttonMode
		## ⇒ 原版指针在小地图上一直是箭头。
		mouse_filter = Control.MOUSE_FILTER_STOP
		图层 = MinimapPicture.new()
		图层.name = "地图层"
		## ⚠ 这一句漏掉是**静默的**：`MinimapPicture._draw()` 第一行就是 `if 源 == null: return`
		## ⇒ 缩略图一张都不画，而门里「图层存在」照样绿。实测截图上看到的"树"其实是
		## **世界场景透过半透明窗框**，不是缩略图 —— 差点点就把这张图当成"做完了"。
		图层.源 = self
		add_child(图层)
		# 鼠标移出面板时把悬停提示收起来（`gui_input` 只在面板内收得到 motion，
		# 出了界就没事件了，不接这一下提示会一直挂着）。
		mouse_exited.connect(func() -> void:
			if _提示 != null:
				_提示.visible = false)

	## `setMap:1439-1457` + `updateMapView:1076-1095`
	func 装载(新规格: Dictionary, 新贴图: Texture2D) -> void:
		规格 = 新规格
		贴图 = 新贴图
		var 档 := float(规格.get("scale", 0.0))
		if 档 <= 0.0:
			档 = 8.0					# PicTool.as:477 `scale || 8`
		图尺寸 = 贴图.get_size() * 档 / 16.0 if 贴图 != null else Vector2.ZERO
		if 图尺寸.x < 视口宽:
			可视.x = 图尺寸.x
			面板偏移.x = (视口宽 - 图尺寸.x) / 2.0		# :1085-1089
		else:
			可视.x = 视口宽
			面板偏移.x = 0.0
		if 图尺寸.y < 视口高:
			可视.y = 图尺寸.y
			面板偏移.y = (视口高 - 图尺寸.y) / 2.0		# :1091-1094
		else:
			可视.y = 视口高
			面板偏移.y = 0.0
		_皮缓存.clear()
		_上次 = ""
		if 图层 != null:
			图层.queue_redraw()
		queue_redraw()

	func _图素(世界: Vector2) -> Vector2:
		return Vector2((世界.x + float(规格.get("centerX", 0.0))) / 16.0,
				(世界.y + float(规格.get("centerY", 0.0))) / 16.0)

	## 画布局部坐标 → 世界坐标。这是 `_图素()` 的逆，也是原版那一行的直译：
	## `SmallMapWindow.as:1137` `pathFind(_mapPanel.mouseX * 16 - _mapObj.centerX, _mapPanel.mouseY * 16 - _mapObj.centerY, 0, true)`
	## —— `mouseX` 是**面板内**坐标（面板会滚，所以要先减掉 `面板偏移`），不是画布坐标。
	func _世界位(局部: Vector2) -> Vector2:
		var 面 := 局部 - 面板偏移
		return Vector2(面.x * 16.0 - float(规格.get("centerX", 0.0)),
				面.y * 16.0 - float(规格.get("centerY", 0.0)))

	func _gui_input(事: InputEvent) -> void:
		# 悬停提示（§3.105）—— 原版 `SmallMapWindow.as:398-413` 在 marker 的 MOUSE_OVER 上
		# `showTooltip`、`:379-386` 跟鼠标、`:1302-1305` 移出时 `removeChild`。
		# 我们的标记是**画在画布上的**（`MinimapPicture._draw()`），没有逐枚节点 ⇒
		# 只得自己做命中判定（拿 `_图素 + _锚` 算出每枚的矩形，见 `_悬停到的`）。
		if 事 is InputEventMouseMotion:
			var 动 := 事 as InputEventMouseMotion
			_显提示(_悬停到的(动.position), 动.position)
			return
		if not (事 is InputEventMouseButton):
			return
		var 钮 := 事 as InputEventMouseButton
		if 钮.button_index != MOUSE_BUTTON_LEFT or not 钮.pressed:
			return
		if 规格.is_empty():
			return	# 没有 miniMap 段（hideMinimap / 查无）⇒ 没得寻路
		accept_event()
		点了寻路.emit(_世界位(钮.position))

	## ── 悬停提示（原版 `SmallMapTooltip`，73 行）────────────────────────────
	## 白字 12 号、底色 `2104381`（= `0x201BBD`）圆角 10、`BG_RIM = 5`、alpha 0.7。
	## ⚠️ 一处**有意的差别**：原版 `addChild(stage)` 挂到舞台上，能**溢出**小地图面板；
	##    我们的面板 `clip_contents = true`，挂子节点会被裁 ⇒ 这里把它**夹在面板矩形内**
	##    （宁可贴着边，也不让名字被裁掉半截）。记在 §3.105.3。
	var _提示: Panel = null
	var _提示字: Label = null
	const 提示边距 := 5.0        ## 原版 `BG_RIM`

	func _建提示() -> void:
		if _提示 != null:
			return
		# ⚠️ 样式**只从主题取**（P2 之后全工程口径：不许在脚本里现造 `StyleBoxFlat` ——
		#    `UI资源回归测试` 有明文守卫，我第一版手搓底皮就被它点名了）。
		#    主题里现成有两件：`TooltipPanel`（原版 `提示框.png` 九宫格 [`皮肤表.原版窗口/通用控件/提示框.png`]）
		#    与 `OrigTooltipText`（= `皮肤表.变体_提示文字`，白字 + 黑描边 + 行距 5）。
		#    ⚠️ **与原版的一处差别**：原版 `SmallMapTooltip` 是**自己画**圆角矩形
		#    （`bgColor = 2104381`、alpha 0.7、rim 5）而不是贴皮 ⇒ 我们这版**底色/圆角跟着皮肤走**、
		#    不是那个色号。记在 §3.105.3。
		_提示 = Panel.new()
		_提示.theme_type_variation = &"TooltipPanel"
		_提示.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_提示字 = Label.new()
		_提示字.theme_type_variation = 皮肤表.变体_提示文字
		_提示字.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_提示.add_child(_提示字)
		add_child(_提示)
		_提示.visible = false

	## 鼠标局部位 → 命中那枚标记的名字（没命中回空串）。只有**带名字**的标记参与。
	func _悬停到的(局部: Vector2) -> String:
		if 规格.is_empty():
			return ""
		for 名 in 画序:
			for 条 in (组.get(名, []) as Array):
				var d := 条 as Dictionary
				var 文字 := String(d.get("名", ""))
				if 文字.is_empty():
					continue
				var 类 := String(d.get("类", ""))
				var 贴 := _皮(类)
				if 贴 == null:
					continue
				var 左上 := 面板偏移 + _图素(d.get("位", Vector2.ZERO) as Vector2) + _锚(类)
				if Rect2(左上, 贴.get_size()).has_point(局部):
					return 文字
		return ""

	func _显提示(文字: String, 鼠标: Vector2) -> void:
		if 文字.is_empty():
			if _提示 != null:
				_提示.visible = false
			return
		_建提示()
		_提示字.text = 文字
		_提示字.size = _提示字.get_minimum_size()
		_提示字.position = Vector2(提示边距, 提示边距)
		_提示.size = _提示字.size + Vector2(提示边距, 提示边距) * 2.0
		# 原版 `stage.mouseX + 8 / mouseY + 12`，再按舞台尺寸夹住（`:383-386`）；
		# 我们夹在**面板**矩形内（理由见上面那条差别）。
		var 位 := 鼠标 + Vector2(8, 12)
		位.x = clampf(位.x, 0.0, maxf(0.0, size.x - _提示.size.x))
		位.y = clampf(位.y, 0.0, maxf(0.0, size.y - _提示.size.y))
		_提示.position = 位
		_提示.visible = true

	func _process(_秒: float) -> void:
		var 挪了 := _挪面板()
		var 摘 := _摘要()
		if 挪了 or 摘 != _上次:
			_上次 = 摘
			if 图层 != null:
				图层.queue_redraw()
			queue_redraw()

	## setPlayerPosition:441-469。**先算一次屏幕位再判两条线**（AS3 就是这个顺序，
	## 两个 if 用的是同一个 `_loc3_`，第二个 if 看到的还是挪之前的屏幕位）⇒ 别改成边挪边重算。
	func _挪面板() -> bool:
		if 规格.is_empty() or not 玩家.is_valid():
			return false
		var 世界: Vector2 = 玩家.call()
		if 世界 == Vector2.INF:
			return false
		var 旧 := 面板偏移
		var 图素 := _图素(世界)
		if 图尺寸.x > 可视.x:
			var 屏x := 面板偏移.x + 图素.x
			if 屏x > 可视.x * 4.0 / 5.0:
				面板偏移.x -= 屏x - 可视.x * 4.0 / 5.0
				面板偏移.x = maxf(可视.x - 图尺寸.x, 面板偏移.x)
			if 屏x < 可视.x / 5.0:
				面板偏移.x += 可视.x / 5.0 - 屏x
				面板偏移.x = minf(0.0, 面板偏移.x)
		if 图尺寸.y > 可视.y:
			var 屏y := 面板偏移.y + 图素.y
			if 屏y > 可视.y * 4.0 / 5.0:
				面板偏移.y -= 屏y - 可视.y * 4.0 / 5.0
				面板偏移.y = maxf(可视.y - 图尺寸.y, 面板偏移.y)
			if 屏y < 可视.y / 5.0:
				面板偏移.y += 可视.y / 5.0 - 屏y
				面板偏移.y = minf(0.0, 面板偏移.y)
		面板偏移 = Vector2(roundf(面板偏移.x), roundf(面板偏移.y))	# :468-469 Math.round
		return 面板偏移 != 旧

	func _摘要() -> String:
		var 部: Array = []
		for 名 in 画序:
			for 条 in (组.get(名, []) as Array):
				var d := 条 as Dictionary
				部.append("%s|%s|%s" % [名, String(d.get("类", "")), (d.get("位", Vector2.ZERO) as Vector2)])
		if 玩家.is_valid():
			部.append(str(玩家.call()))
		return str(部)

	func _皮(类: String) -> Texture2D:
		if _皮缓存.has(类):
			return _皮缓存[类]
		var 条: Dictionary = 标记表.get(类, {}) as Dictionary
		var 路 := String(条.get("贴图", ""))
		var 贴: Texture2D = null
		if 路 != "" and ResourceLoader.exists(路):
			贴 = load(路) as Texture2D
		_皮缓存[类] = 贴
		return 贴

	func _锚(类: String) -> Vector2:
		var a: Array = (标记表.get(类, {}) as Dictionary).get("锚点", [0, 0]) as Array
		if a.size() < 2:
			return Vector2.ZERO
		return Vector2(float(a[0]), float(a[1]))

	func _draw() -> void:
		if 规格.is_empty():
			return
		for 名 in 画序:
			if 名 == "图":
				continue	# 图在子节点「地图层」上画（它要线性过滤，标记要 NEAREST）
			var 条们: Array = 组.get(名, []) as Array
			if 名 == "自己":
				## 自己不是数据项：原版是 `playerHelper`（:1052）每 tick 由 setPlayerPosition 挪
				条们 = [] if not 玩家.is_valid() else [{"类": "minimap_user_skin", "位": 玩家.call()}]
			for 条 in 条们:
				var d := 条 as Dictionary
				var 类 := String(d.get("类", ""))
				var 贴 := _皮(类)
				if 贴 == null:
					continue
				draw_texture(贴, 面板偏移 + _图素(d.get("位", Vector2.ZERO) as Vector2) + _锚(类))


class MinimapPicture extends Control:
	## 缩略图单独一层，因为**两种过滤要分开**：Flash 把位图按 scale/16 降采样是平滑的（图1 上
	## 树和房子是软的），而标记是 1:1 贴的像素小人（是硬的）。一个 CanvasItem 只能有一种
	## `texture_filter` ⇒ 图放子层、`show_behind_parent = true` 让它垫在标记下面。
	var 源			# 指回外面的 MinimapCanvas（内嵌类互相写类型名会成环 ⇒ 不标类型）

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if 源 == null or 源.贴图 == null:
			return
		draw_texture_rect(源.贴图, Rect2(源.面板偏移, 源.图尺寸), false)


func _开NPC菜单页(动作值: int) -> void:
	_读NPC表()
	var 信: Dictionary = _落地.get(动作值, {})
	if 信.is_empty():
		return
	var 页 := String(信["页"])
	if not 页.is_empty():
		# 原版**没有"点行即开窗"这一跳**：动作 12/30 是收到服务端回帧才开
		# （`Client.as:1212 onCopy_visitHistory` / `:1149 onHeroEnterInfo`）⇒ 等回帧（§3.90.8 用户拍板）。
		if 页 == "副本" or 页 == "精英副本":
			if _session == null:
				return
			_落地等待 = 页
			_落地截止 = Time.get_ticks_msec() + 5000
			# 12 走 819/0 兜底自拉：本次 57 帧没触发推送时，request_copy_history 必让服务端回 817/0。
			# ⚠ `request_copy_history()` 在**后端**上（`后端连接.gd:867`），不在会话上 —— 会话没有这个方法，
			#   写 `_session.` 会 "Nonexistent function" 当场中断（本轮实测到的）。
			if 动作值 == 12:
				var 后端 := get_node_or_null("/root/BackendConnection")
				if 后端 != null:
					后端.request_copy_history()
			return
		if _session != null:
			_session.request_feature(页)
		return
	var 态 := String(信["状态"])
	if 态.begins_with("待建"):
		show_notification("「%s」还没移植（原版 %s %s）" % [String(信["名"]), String(信["原版类"]), 态])
	else:
		show_notification("「%s」%s" % [String(信["名"]), 态])

func _on_copy_landed(_state: Dictionary) -> void:
	if _落地等待 == "副本" and Time.get_ticks_msec() <= _落地截止:
		_落地等待 = ""
		_session.request_feature("副本")

func _on_hero_landed() -> void:
	if _落地等待 == "精英副本" and Time.get_ticks_msec() <= _落地截止:
		_落地等待 = ""
		_session.request_feature("精英副本")


## 给行为门用的两个入口：读当前菜单行文字、按第 i 行（与鼠标点击完全同一条代码路径）。
