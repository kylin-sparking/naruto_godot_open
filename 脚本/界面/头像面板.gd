extends CanvasLayer

const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
const 角色造型 := preload("res://脚本/角色/角色造型.gd")
## 两条曲线都出自这一道口子：目标血蓝 = `MBar` 的 0.5s **二次缓出**，
## 自己血蓝 = `MMaskSprite` 的 0.5s **线性**（真值 `真值/窗口/进度条补间.md` §⑥/§⑧）。
const 进度条补间 := preload("res://脚本/单例/进度条补间.gd")
## Buff 格的悬停提示（原版 `MToolTipTextWithTitle`，见组件文件头）。
const 标题提示场景 := preload("res://场景/界面/组件/标题文字提示框.tscn")
## 组队队长标：原版 `CharactorInfoPane.setTroopCaptainIcon/removeTroopCaptainIcon`
## （`:278-292 / :346-353`；图标 = `UISwf_Text_TroopCaptainIcon`，33×17，摆面板局部 (210,38)、
## 鼠标穿透）。触发点在 `RelationShipHandler` 四处（建队 :120 / 换队长 :56,60 /
## `removeTroopHPPane:286` = 离队·解散·被踢）。这边状态记在 `队伍窗.队长标应显`，
## 队伍窗改完广播 `GameSession.队长标_changed`；面板 `_ready` 再自读一次兜底（切图重建）。
const 队伍窗脚本 := preload("res://脚本/界面/窗口/组队/队伍窗.gd")
## 头像下那颗战斗模式钮 = 原版 `CharactorInfoPane._pvpBtn`（`:433-471`）：
## **按当前模式换整张皮**（1 和平=元件760 / 2 组队=744 / 3 家族=748 / 4 全体=756，都 23×23，
## 各只有一张 upSkin ⇒ 悬停/按下是 MButton3 的加性滤镜 ±30/−40，预烘成派生皮）。
## 点它开的四行菜单见 `脚本/界面/组件/PK模式菜单.gd`（原版 `PKModePane2`）。
const PK模式菜单 := preload("res://脚本/界面/组件/PK模式菜单.gd")
const 模式皮目录 := "res://素材/界面/原版窗口/头像面板/"
const 模式皮基名 := {1: "模式_普通", 2: "模式_组队", 3: "模式_家族", 4: "模式_全体"}
## `CN.PVPBTN_*` + `CN.PK_MODE` 拼出来的那颗钮的 tooltip（语言表原文，逐字搬；
## 原版是 html 带色，Godot 的 tooltip 只能纯文本 ⇒ 只保文字，不自己造句）。
const 模式提示 := {
	1: "当前模式：普通\n不会对任何人造成伤害\n点击后可更改PK模式",
	2: "当前模式：组队\n不会对同队成员造成伤害\n点击后可更改PK模式",
	3: "当前模式：家族\n不会对家族成员造成伤害\n点击后可更改PK模式",
	4: "当前模式：全体\n可以对任何人造成伤害\n点击后可更改PK模式",
}

## ── 目标信息条（原版 `DetailsWindow`，逐件真值见 `真值/窗口/目标信息条.md`）──────
## 六颗钮的**悬停/按下**两档皮。基名那张（`texture_normal`）烤在 .tscn 里，这里只列派生两档。
## 为什么只能换皮不能染色：原版的 over/down 是 `getLightFilter(+30 / −40)` 的**加性**滤镜
## （`StyleUtil.as:7-12`），Godot 的 `modulate` 是乘性 ⇒ 暗部几乎不亮（skill `flash-mbutton3-state-skins`）。
const 目标钮派生皮 := {
	"钮_查看资料": ["res://素材/界面/原版窗口/目标信息/钮_查看资料_悬停.png",
			"res://素材/界面/原版窗口/目标信息/钮_查看资料_按下.png"],
	"钮_交易": ["res://素材/界面/原版窗口/目标信息/钮_交易_悬停.png",
			"res://素材/界面/原版窗口/目标信息/钮_交易_按下.png"],
	"钮_加好友": ["res://素材/界面/原版窗口/目标信息/钮_加好友_悬停.png",
			"res://素材/界面/原版窗口/目标信息/钮_加好友_按下.png"],
	"钮_组队": ["res://素材/界面/原版窗口/目标信息/钮_组队_悬停.png",
			"res://素材/界面/原版窗口/目标信息/钮_组队_按下.png"],
	"钮_私聊": ["res://素材/界面/原版窗口/目标信息/钮_私聊_悬停.png",
			"res://素材/界面/原版窗口/目标信息/钮_私聊_按下.png"],
	"钮_菜单": ["res://素材/界面/原版窗口/目标信息/钮_菜单_悬停.png",
			"res://素材/界面/原版窗口/目标信息/钮_菜单_按下.png"],
}
## `init():113` 的 `btnTips`，值 = 语言表里那 6 个键（`POPUP_QUERY` / `POPUT_TRADE` / `POPUP_FRIEND`
## / `TROOP_INVITE_BUTTON` / `PRIVATELY_CHAT` / `REPLENISH_MENU`）。
const 目标钮提示 := {
	"钮_查看资料": "查看信息", "钮_交易": "邀请交易", "钮_加好友": "加为好友",
	"钮_组队": "邀请组队", "钮_私聊": "私聊", "钮_菜单": "补充菜单",
}
## `_menu():309-320` 的三档行表。`ShituList.as:15 LIMIT_LEVEL = 60`、`Config.as:78 SHITU_OFF = false`。
const 菜单基本行 := ["族邀", "赠花", "羁绊", "看摊", "双修"]
const 拜师行 := "拜师"
const 收徒行 := "收徒"
const 师徒等级线 := 60
## 这五行**全部接上了**（#88 收尾）。以前这里挂着一份「本机未开放」名单，最近一条是「赠花」，
## 理由写的是"婚姻整套服务端没接" —— **那句是假的**（§3.255 撤掉族邀/羁绊两条、§3.256 撤掉最后一条）：
## 三条协议服务端全都在发（`94:6`→`58:2` 见 `_flower_character_info_fields`、`127:39`→`61:44`
## 见 `_send_flower_gift`、`1552:19` 见 `:33547`、`127:15` 见 `:23266-23283`），
## 客户端上行也都写好了，缺的从来只是菜单那一行没接 ⇒ 名单连同 `_报("…还没有…")` 一起删掉。
## 门里那份同名名单（`测试/头像信息在线回归测试.gd`）同步撤了，改成逐行判真发包。

## ── 战斗模式（原版 `PKModePane2`，见 `真值/窗口/战斗模式菜单.md`）─────────────
## 行序 = 模式号：`PKModePane2.createChildren():113` 烘的是 `buttons = [null, 和平, 组队, 家族, 全体]`，
## `onCheckPKMode():96` 回传的又是 `buttons.indexOf(钮)` ⇒ **数组下标 + 1 就是 `OpenPvpMode` 的模式号**。
## 第 5 档「阵营」不在这扇里（`OpenPvpMode.as` 有 5，`PKModePane2` 只摆 4 行）。
## 每档五项全是原版烘死的，本地不发挥：
## · 名 = `en_US$message_properties.as` 的 tooltip 里那半句 `当前模式：X`（`PVPBTN_PEACE` 397 行
##   写的是「普通」**不是**「和平」—— 只有代码符号叫 Peace）。
## · 说 = 同一行的后半句（`CharactorInfoPane.set pvpMode:486-527` 拼的 `CN.PVPBTN_*`）。
## · 色 = tooltip 的 `<font color>` **和** 菜单行色一致（`PkItem` 第三参 `UIConfig.UI_YELLOW/BLUE/
##   GREEN/RED` = `16773120/2003199/65280/16711680`，`createChildren:70-82`；`UI_YELLOW` 那一档
##   tooltip 里是 `#ffffff`，两处不一致时取**菜单色**，tooltip 本客户端是纯文本、无色可挂）。
## · 行 = 菜单里那一整句（`CN.HEPING/ZUDUI/JIZU/QUANTI_MODE`，原版就是整句，不是短名）。
## · 皮 = `set pvpMode` 每次换掉的整个按钮类（`PeaceButton` 760 / `TroopButton` 744 /
##   `FamillyButton` 748 / `GloablButton` 756，MainLib 符号，23×23 与格子同尺寸）。
##   只有 up 一档：原版的 over/down 是同一张图的加性滤镜，扁平导出拿不到 ⇒ 三档同一张，不假造高亮。
const 战斗模式档 := [
	{"名": "普通", "说": "不会对任何人造成伤害", "色": "ffff00",
	"行": "【普通模式】你无法对任何玩家发起PK，群攻不会误伤任何玩家",
	"皮": "res://素材/界面/通用界面/战斗模式钮_和平.png"},
	{"名": "组队", "说": "不会对同队成员造成伤害", "色": "1e90ff",
	"行": "【组队模式】你无法对同队伍玩家发起PK，群攻不会误伤本队玩家",
	"皮": "res://素材/界面/通用界面/战斗模式钮_组队.png"},
	{"名": "家族", "说": "不会对家族成员造成伤害", "色": "00ff00",
	"行": "【家族模式】你无法对同家族玩家发起PK，群攻不会误伤同族玩家",
	"皮": "res://素材/界面/通用界面/战斗模式钮_家族.png"},
	{"名": "全体", "说": "可以对任何人造成伤害", "色": "ff0000",
	"行": "【全体模式】你可以对任何玩家发起PK，群攻会伤害其他任何玩家",
	"皮": "res://素材/界面/通用界面/战斗模式钮_全体.png"},
]
## `CharactorInfoPane.as:517` 在 `CN.PVPBTN_*` 后面无条件再拼一句 `CN.PK_MODE`（绿字）。
const 战斗模式提示尾 := "点击后可更改PK模式"
## `showPvpModeViewHandler:262` 的锚点 = 面板局部 `(0, 87)`，而 `_pvpBtn` 在 `(0, 64)`、高 23
## ⇒ 就是**钮的正下方**。本面板的 `角色状态` 在 `头像区域` 里偏 (4,4)、钮 (6,67)~(29,90)
## ⇒ 等价锚点 (4, 94)。
const 战斗模式锚点 := Vector2(4.0, 94.0)

## 状态图标（天气 / 系统双倍 …）一律查 `数据/状态图标.json`，脚本里不再抄路径也不再抄名字。
## 原来手抄的那份 `WEATHER_NAMES` 把 8/9 两级写反了：dat 表里 8=大雾、9=浓雾。
var _图标表 := {}

func _状态图标(键: String) -> Dictionary:
	if _图标表.is_empty():
		_图标表 = GAME_DATA.取表("状态图标").get("表", {}) as Dictionary
	return _图标表.get(键, {}) as Dictionary

## 原版的格子没有"兜底图标"：图就是数据里那张，查不到就留空格子，随手拿另一张贴上是自造。
func _贴图(路径: String) -> Texture2D:
	return load(路径) as Texture2D if not 路径.is_empty() and ResourceLoader.exists(路径) else null

var _session: Node
var _status_name: Label
var _status_level: Label
var _hp_bar: TextureProgressBar
var _mp_bar: TextureProgressBar
var _target_panel: Control
var _target_portrait: TextureRect
var _self_portrait: TextureRect
var _队长标: TextureRect
var _target_name: Label
var _target_level: Label
var _target_hp: TextureProgressBar
var _target_mp: TextureProgressBar
var _target_hp_text: Label
var _target_mp_text: Label
var _目标菜单: Control
var _目标信息: Dictionary = {}
var _钮态: Dictionary = {}			## 钮 → {"皮": [三档 Texture2D], "态": 0..2}
## 2026-10-25 用户：「左上角还有 vip 标志，帮我完整的删掉」⇒ VIP 徽记整颗摘除
## （场景里的 `VipBadge/VipLevel` 与这里的两条引用、`_update_vip` 一并删）。
## 服务端仍会推 1818 的 VIP 等级帧，客户端**只解析不显示**（协议回归门仍钉解析）。
var _status_button: BaseButton
## 模式钮的两件状态：`_模式` = 当前档（1..4），`_模式钮态` = 0 常态 / 1 悬停 / 2 按下
##（`_钮态` 这个名字已被目标信息条那六颗钮占用，别撞）。
## ⚠ 存脚本字段、不存 meta：中文 meta 键在 Godot 4 会**静默存不进去**（见 skill 记录）。
var _模式: int = 1
var _模式钮态: int = 0
var _status_slots: Array[TextureRect] = []
var _模式菜单: Control
var _pending_pk_mode := -1
var _pk_request_started_msec := 0
## 每个状态格的提示数据：{title, desc, expires(毫秒，0=永久), time_style("buff"/"item"/"none")}
var _状态提示: Array = []
var _标题提示: Control
var _悬停格 := -1
var _提示秒表 := 0.0
## 每格的首次到达时刻（键 → msec）。原版 `BuffPane` 按 `addChild` 顺序摆格、
## 刷新只改数据不挪位（`BuffPane.as:152-183`）⇒ 顺序取"首次出现"，不按类别分组。
var _到达时刻: Dictionary = {}
## 到点闪烁（原版 `BuffCell.as:194-223`：120ms × 10 闪 alpha 0.5/1，再收格）
var _闪烁: Dictionary = {}
var _闪烁节拍 := 0.0

func _ready() -> void:
	transform = Transform2D.IDENTITY
	_session = get_node_or_null("/root/GameSession")
	var root := get_node("头像区域") as Control
	_status_name = root.get_node("角色状态/StatusName") as Label
	_status_level = root.get_node("角色状态/StatusLevel") as Label
	_hp_bar = root.get_node("角色状态/HpBar") as TextureProgressBar
	_mp_bar = root.get_node("角色状态/MpBar") as TextureProgressBar
	_target_panel = root.get_node("选中人物信息") as Control
	_target_portrait = _target_panel.get_node("头像") as TextureRect
	## 自己这枚头像（`PortraitHead` 的角色档）—— 以前只有 .tscn 里烤死的那一张，
	## 于是女角色配男头像（用户 10-11 实机图）。原版头像与身体是**同一个 face**
	## （`CharacterHandler.as:305-307` + `PortraitHead.as:136`）。
	_self_portrait = root.get_node("角色状态/Portrait") as TextureRect
	## 队长标（原版 `troopCaptainIcon`）：场景里常驻、默认隐藏，亮不亮由队伍状态决定。
	_队长标 = root.get_node_or_null("角色状态/队长标") as TextureRect
	_刷队长标()
	## 199 换装/变身回帧 ⇒ 头像跟着一起换。原版本人那一支是写完 `stats.face` 之后
	## **立刻** `setCharacterImage(new PortraitHead())`（`CharacterHandler.as:297-307`），不是等下一次刷新。
	## ⚠ 用 `has_signal` + `connect("名字", …)` 的通用写法：这里拿到的是 `Node` 型，
	##   写成 `后端.char_look_changed.connect` 编译期找不到信号名会直接 parse 失败。
	var 后端 := get_node_or_null("/root/BackendConnection")
	## 服务端推的目标信息一帧（`1284`，原版 `Client.onTargetInfo()`）——「查看信息」那颗钮
	## 换来的就是它：服务端 `_send_target_player_info`（`fake_flash_server.py:20282`）
	## 把对方的 hp/maxHp/mp/maxMp 推给**我**，条上的数字与填充跟着改成服务端那份。
	if 后端 != null and 后端.has_signal("target_info_received"):
		后端.connect("target_info_received", _on_服务端目标信息)
	## 「查看信息」那颗钮是**两段回帧**：1284 喂头上这条（上面那支），`58:4` 给一整份别人的档案。
	## ⚠ 开窗**不归这里**：原版 `onCharInfo` 是"窗还没建才 `setDOShow(...,true)`，已开着就 `setData` 刷新、
	##   绝不关窗"（`Client.as:3009-3035` 两支），
	##   而 `feature_requested` 那条路走的是 `窗口管理.打开或收起` —— 已经开着就会**关掉**，
	##   于是"连着点两次查看信息 ⇒ 窗没了 / 换个人看 ⇒ 窗关了要再点一次"。
	##   回帧开窗一律落在 `窗口管理`（与 神秘商店 / NPC商店 / 仓库 同一族，那里用的就是幂等 `打开()`）。
	if 后端 != null and 后端.has_signal("char_look_changed"):
		后端.connect("char_look_changed", func(角色号: int, _性别: int, _肤色: int, _脸: int, _灵气脸: int, _装备串: String):
			if 角色号 == int(后端.get("character_id")):
				_更新自身头像())
	_target_name = _target_panel.get_node("名字") as Label
	_target_level = _target_panel.get_node("等级") as Label
	_target_hp = _target_panel.get_node("血条") as TextureProgressBar
	_target_mp = _target_panel.get_node("蓝条") as TextureProgressBar
	_target_hp_text = _target_panel.get_node("血字") as Label
	_target_mp_text = _target_panel.get_node("蓝字") as Label
	_接目标钮(root)
	_status_button = root.get_node("角色状态/StatusToggle") as BaseButton
	for child in root.get_node("状态效果").get_children():
		if child is TextureRect:
			_status_slots.append(child as TextureRect)
	# ⚠️ 状态格原来全是 `mouse_filter = 2(IGNORE)` ⇒ 原生 tooltip 和原版提示框都**永远弹不出来**
	#    （用户 10-17 报"buff 状态没有提示框"）。IGNORE 的控件不参与命中测试，悬停事件根本不到它。
	for i in _status_slots.size():
		var 格 := _status_slots[i]
		格.mouse_filter = Control.MOUSE_FILTER_STOP
		格.mouse_entered.connect(_显示状态提示.bind(i))
		格.mouse_exited.connect(_收起状态提示)
	_标题提示 = (标题提示场景.instantiate()) as Control
	_标题提示.name = "buff提示框"
	root.add_child(_标题提示)
	_setup_feature_buttons(root)
	_clear_status_slots()
	if _session == null:
		return
	_session.player_stats_changed.connect(_on_stats_changed)
	_session.hud_state_changed.connect(_on_hud_state_changed)
	_session.map_character_selected.connect(_on_map_character_selected)
	_session.map_character_selection_cleared.connect(_on_map_character_selection_cleared)
	_session.队长标_changed.connect(_on_队长标_changed)
	_on_stats_changed(_session.player_stats)
	_on_hud_state_changed(_session.hud_state)

func _on_stats_changed(stats: Dictionary) -> void:
	_status_name.text = String(stats.get("name", "忍者"))
	_status_level.text = "Lv.%d" % int(stats.get("level", 1))
	_hp_bar.max_value = maxf(1.0, float(stats.get("max_hp", 100)))
	_mp_bar.max_value = maxf(1.0, float(stats.get("max_mp", 100)))
	# 这两枚是原版 `CharactorInfoPane` 的 `MMaskSprite`（不是 MBar）：**逐帧线性**插值、同样半秒、
	# 同样"从当前渲染值重新起算"、同样同数据早退（`MMaskSprite.as:59-67/158-169`）⇒ 走 `线性补间`，
	# 别套 MBar 的二次缓出（真值 §⑥）。数字与 tooltip 一律按 stats 算，不读条自己。
	var 生命 := clampf(float(stats.get("hp", 0)), 0.0, _hp_bar.max_value)
	var 查克拉 := clampf(float(stats.get("mp", 0)), 0.0, _mp_bar.max_value)
	进度条补间.线性补间(_hp_bar, "value", 生命, [生命, _hp_bar.max_value])
	进度条补间.线性补间(_mp_bar, "value", 查克拉, [查克拉, _mp_bar.max_value])
	_hp_bar.tooltip_text = "生命 %d / %d" % [int(stats.get("hp", 0)), int(stats.get("max_hp", 100))]
	_mp_bar.tooltip_text = "查克拉 %d / %d" % [int(stats.get("mp", 0)), int(stats.get("max_mp", 100))]
	_更新自身头像()


## 头像跟着服务端下发的 `face` 走（#191）。查不到图就**留着原来那张**，
## 不许把头像刷成空白 —— 空白比错更难查（用户看不出是素材没导还是没接上）。
func _更新自身头像() -> void:
	if _self_portrait == null or _session == null:
		return
	var 身: Dictionary = _session.call("自身外观")
	var 号 := 角色造型.造型号(int(身["face"]), int(身["gender"]))
	var 图 := OriginalSprite.portrait("character", 号)
	if 图 != null:
		_self_portrait.texture = 图

## 原版 `setTroopCaptainIcon():278-292` 每次都先 `removeTroopCaptainIcon()` 再按
## `isPartyLeader(自己)` 决定加不加 ⇒ 这边等价于整颗换 `visible`，不动父子关系。
func _on_队长标_changed(应显: bool) -> void:
	if _队长标 != null:
		_队长标.visible = 应显


## 面板建出来（含切图重建）时按队伍状态补画一次 —— 建队帧可能比 HUD 先到。
func _刷队长标() -> void:
	_on_队长标_changed(队伍窗脚本.队长标应显)


func _on_hud_state_changed(state: Dictionary) -> void:
	var mode := clampi(int(state.get("pk_mode", 1)), 1, 5)
	## ★ **任何一条带 pk_mode 的 hud 帧就是落定**，不要求"值 == 我刚点的那个"。
	## 原版没有"我要的那个值回来了才算确认"这个概念：`Client.as:5777-5789` 收到 `1792 cmd=2`
	## 只要角色号是自己，就直接 `PVPHandler.pvpMode = param2`，而**被拒那一支服务端回的是原值**
	## （`fake_flash_server.py:41632-41652`）⇒ 按旧口径对不上，钮要按住到 5 秒看门狗、
	## 还顺带报一句「战斗模式切换超时，请重试」（用户 10-22 报修 12「一直超时」正是这一条）。
	if _pending_pk_mode >= 0:
		var 生效 := mode == _pending_pk_mode
		_pending_pk_mode = -1
		_status_button.disabled = false
		## 在线**不补这一句**：服务端同一趟自己发一条 512 黄字「已切换为X模式。」
		## （`_handle_chat_text` → `_通知`），再飘一遍就是同一件事两遍字（同 §3.203 那条"每点一次刷一句"）。
		## 离线没有黄字，这一句是唯一的反馈。
		if 生效 and _后端() == null:
			_session.notification_requested.emit("已切换为%s模式。" % _pk_mode_name(mode))
	_刷模式钮(mode)
	_render_status_effects(
		int(state.get("weather_type", -1)),
		state.get("buffs", []) as Array,
		state.get("effects", []) as Array
	)


## 原版 `DetailsWindow.setData():212-271`：名字 / 等级 / 头像 / 两条条，外加 `hideBtn(type)`。
func _on_map_character_selected(info: Dictionary) -> void:
	_目标信息 = info
	_target_name.text = String(info.get("name", "人物"))
	_target_level.text = String(info.get("level_text", ""))
	_target_portrait.texture = info.get("portrait") as Texture2D
	## ⚠ **只有玩家档（原版 `type == 1`）显示那排钮** —— `hideBtn():287-298` 判的就是这一个值，
	## 怪与 NPC 的条上没有这一排（原版点 NPC 走的是对话窗，不是这一条）。
	var 是玩家 := int(info.get("type", 0)) == 1
	for 名 in 目标钮派生皮:
		(_target_panel.get_node(名) as Control).visible = 是玩家
	if not 是玩家:
		_收起目标菜单()
	_刷目标条(_target_hp, _target_hp_text, int(info.get("hp", 0)), int(info.get("max_hp", 0)))
	_刷目标条(_target_mp, _target_mp_text, int(info.get("mp", 0)), int(info.get("max_mp", 0)))
	_target_panel.visible = true

## `MBar.setData():128-175`：`当前`/`上限` 任一为 **-1** ⇒ 条上印 `?/?`（`:158-161`）；
## 否则文案 = `当前 + "/" + 上限`（`showPercent` 默认 false），填充比例走 **0.5 秒补间**（`:170`）。
func _刷目标条(条: TextureProgressBar, 字: Label, 当前: int, 上限: int) -> void:
	if 当前 == -1 or 上限 == -1:
		字.text = "?/?"
		# 原版这一支写完文案就 `return`（`MBar.as:158-161`，**不动条**）；本工程选择画**空条**，
		# 但必须走 `直写` 而不是 `条.value = 0.0` —— 后者把件里的缓存留在上一次那发数据上，
		# 下次选中同一个人时会被"同数据早退"吞掉 ⇒ 条再也不回半格。
		进度条补间.直写(条, "value", 0.0)
		return
	var 实 := 当前
	if 上限 > 0 and 实 > 上限:
		实 = 上限
	字.text = "%d/%d" % [实, 上限]
	var 比例 := 进度条补间.比例(float(实), float(上限), false)
	## `上限 <= 0` = **还没拿到对方属性**（选中玩家那一刻才发 `94:4`，1284 回帧在路上）。
	## 这一档要画成**空条**，不是满条 —— 满条看着像"对方血是满的"，那是另一种假数。
	## ⇒ `上限零当满 = false`（原版 MBar 缺省画满，这条是本工程**已登记的偏离**，
	##   见 `真值/窗口/目标信息条.md` §⑫）。早退与"换数据杀旧补间"都在件里，别再自己 `create_tween`。
	进度条补间.补间(条, "value", 比例, [当前, 上限])

## 只认**玩家档**（`type == 1`）。怪（0）与地图旗（2）两档**故意不接**：本工程的怪身上没存
## 服务端那个 objectId，拿模板号去配会把"同种的另一只"的血填进当前目标 —— 宁可数字不动，
## 也不填错人的血（这条口径记在 `真值/窗口/目标信息条.md` §⑫）。
func _on_服务端目标信息(状: Dictionary) -> void:
	if int(状.get("type", -1)) != 1:
		return
	if _目标信息.is_empty() or int(_目标信息.get("char_id", 0)) != int(状.get("object_id", 0)):
		return
	_目标信息["hp"] = int(状.get("hp", 0))
	_目标信息["max_hp"] = int(状.get("max_hp", 0))
	_目标信息["mp"] = int(状.get("mp", 0))
	_目标信息["max_mp"] = int(状.get("max_mp", 0))
	_on_map_character_selected(_目标信息)


func _on_map_character_selection_cleared() -> void:
	_目标信息 = {}
	_收起目标菜单()
	_target_panel.visible = false

## ── 那六颗钮 + 菜单弹窗 ────────────────────────────────────────────────
## 三档一律换 `texture_normal`（0 up / 1 悬停 +30 / 2 按下 −40），**松手回 up**
## （`MButton3.as:103-108` `mouseUpHandler` 推的是 `STATE_UP`）。
## 不用 `texture_hover`/`texture_pressed`：Godot 松手后只要鼠标还悬着会停在 hover，与原版相反。
func _接目标钮(_root: Control) -> void:
	for 名 in 目标钮派生皮:
		var 钮 := _target_panel.get_node(名) as TextureButton
		var 皮: Array = [钮.texture_normal]
		for 路 in 目标钮派生皮[名]:
			皮.append(_贴图(路))
		_钮态[钮] = {"皮": 皮, "态": 0}
		钮.tooltip_text = String(目标钮提示[名])
		钮.mouse_entered.connect(_设目标钮态.bind(钮, 1))
		钮.mouse_exited.connect(_设目标钮态.bind(钮, 0))
		钮.button_down.connect(_设目标钮态.bind(钮, 2))
		钮.button_up.connect(_设目标钮态.bind(钮, 0))
	var 动作 := {
		"钮_查看资料": _目标查资料, "钮_交易": _目标邀请交易, "钮_加好友": _目标加好友,
		"钮_组队": _目标邀请组队, "钮_私聊": _目标私聊, "钮_菜单": _弹目标菜单,
	}
	for 名 in 动作:
		(_target_panel.get_node(名) as BaseButton).pressed.connect(动作[名])
	## `onClickHead():473-476` = `API.targetHandler.cancelTarget()` ⇒ **点头像取消选中**。
	## 注册点：原版 `iconMc` 整枚都可点（圆框那张皮 62×62 就是它的命中区），
	## 头像本体 `mouse_filter = 2` 让位给底下的圆框。
	(_target_panel.get_node("头像框") as Control).gui_input.connect(_点头像框)
	_目标菜单 = _target_panel.get_node("目标菜单") as Control
	_目标菜单.connect("选择了", _点目标菜单项)

func _设目标钮态(钮: TextureButton, 态: int) -> void:
	var 记: Dictionary = _钮态.get(钮, {}) as Dictionary
	var 皮: Array = 记.get("皮", []) as Array
	if 皮.is_empty() or 态 >= 皮.size():
		return
	记["态"] = 态
	钮.texture_normal = 皮[态] as Texture2D

func _点头像框(事件: InputEvent) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed \
			and (事件 as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var 地图 := get_parent().get_node_or_null("LifeRoot")
		if 地图 != null and 地图.has_method("取消选中"):
			地图.call("取消选中")		# 连目标一起清（原版 cancelTarget），条跟着隐
		elif _session != null:
			_session.call("clear_map_character_selection")
		get_viewport().set_input_as_handled()

func _后端() -> Node:
	return get_node_or_null("/root/BackendConnection")

func _目标号() -> int:
	return int(_目标信息.get("char_id", 0))

func _目标名() -> String:
	return String(_目标信息.get("name", ""))

func _报(话: String) -> void:
	if _session != null:
		_session.notification_requested.emit(话)

## `onClickSelectDatumBtn():449-452` `API.ui.clickCharacter(id)` —— 原版发 `94:4` 拉对方资料。
## 这里只保证**包真发出去了**（服务端 `handle_character_info_request` 会回帧）；
## 开窗由 `窗口管理` 接住那条回帧来做，理由见 `_ready` 里那段。
func _目标查资料() -> void:
	var 号 := _目标号()
	if 号 <= 0:
		_报("这个目标没有角色编号")
		return
	var 后 := _后端()
	if 后 == null or not bool(后.get("in_game")) or not bool(后.call("request_character_info", 号)):
		_报("查看信息需要在线")

## `_trade():466-471` `TradeWindowEvent.TRADE_INVITE(charId)` ⇒ 服务端 `handle_player_interaction`
## action 2；成功时**对方**收 `119:3:<我的号>:<我的名>`、**我**收一条系统提示。
func _目标邀请交易() -> void:
	var 号 := _目标号()
	var 后 := _后端()
	if 号 <= 0 or 后 == null or not bool(后.get("in_game")):
		_报("邀请交易需要在线")
		return
	if not bool(后.call("request_trade_invite", 号)):
		_报("邀请交易发送失败")

## `_addFriend():190-205`：已经是好友 ⇒ 只弹一句 `FRIEND_TIP_CHAR_IS_FRIEND_ALREADY`（**不发包**）；
## 否则 `FriendPaneEvent.ADD_FRIEND` ⇒ 服务端 `127:1:<角色号>`（编号，不是名字）。
func _目标加好友() -> void:
	var 号 := _目标号()
	if 号 <= 0:
		_报("这个目标没有角色编号")
		return
	var 后 := _后端()
	if 后 == null or not bool(后.get("in_game")):
		_报("加好友需要在线")
		return
	if bool(后.call("is_friend", 号)):
		_报("该玩家已经是你的好友")
		return
	if not bool(后.call("request_friend_add", 号)):
		_报("加好友请求发送失败")

## `_troop():454-459` `TroopWindowEvent.INVITE(charName)` ⇒ `120:4:<名字>`（组队那一路取的是**名字**）。
func _目标邀请组队() -> void:
	var 名 := _目标名()
	var 后 := _后端()
	if 名.is_empty() or 后 == null or not bool(后.get("in_game")):
		_报("邀请组队需要在线")
		return
	if not bool(后.call("request_party_invite", 名)):
		_报("邀请组队发送失败")

## `_whisper():360-365` `ChatEvent.CHECK_ONLINE(playName)` —— **不发包**：
## 把聊天框切到「私聊」频道、预填 `/名字 `、抢焦点（与好友行菜单那一档同一套做法）。
func _目标私聊() -> void:
	var 名 := _目标名()
	if 名.is_empty():
		return
	for 节 in get_tree().get_nodes_in_group("chat_panel"):
		if 节.has_method("开始私聊"):
			节.call("开始私聊", 名)
			return
	_报("请在聊天框输入 /%s 消息" % 名)

## `_menu():300-328`：再点一次 = 收起；否则在 `(menuBtn.x, menuBtn.y + menuBtn.height)` = (141,60) 弹出。
func _弹目标菜单() -> void:
	if _目标菜单.visible:
		_收起目标菜单()
		return
	## 位置是**条局部**的 (141,60)（`_menu():322-323` 就这一句）。第三参要的是舞台尺寸：
	## 条在屏幕顶部居中，弹窗往右下挂，永远出不了屏 ⇒ 拿视口尺寸当钳制框等于不钳
	## （原版 `MPopupMenu` 本来也不钳）。传条自己的尺寸会把 y 从 60 压回 0（有头量具抓到过）。
	## ⚠ 本脚本的 `self` 是 **CanvasLayer，不是 CanvasItem** ⇒ 既没有 `get_viewport_rect()`
	##   也没有 `get_root()`，写成那样整份脚本 parse 失败、整个 HUD 一起死（10-15 实测两次）。
	##   取屏幕一律 `get_tree().root`。
	_目标菜单.弹出(_菜单行表(), Vector2(141.0, 60.0), get_tree().root.get_visible_rect().size)

## 三档行表（`:309-320`）：`SHITU_OFF = false`（`Config.as:78`），所以只看双方等级与 60 级那条线。
func _菜单行表() -> Array:
	var 行: Array = 菜单基本行.duplicate()
	var 我 := int((_session.player_stats.get("level", 1)) if _session != null else 1)
	var 他 := int(_目标信息.get("level", 0))
	if 我 < 师徒等级线 and 他 >= 师徒等级线:
		行.append(拜师行)
	elif 我 >= 师徒等级线 and 他 < 师徒等级线:
		行.append(收徒行)
	return 行

func _收起目标菜单() -> void:
	if _目标菜单 != null:
		_目标菜单.call("收起")

## `onClickPopupMenu():330-358` 的七路分发。
func _点目标菜单项(项: String) -> void:
	var 号 := _目标号()
	match 项:
		"看摊":
			# `UI.viewStall():216-220` → `StallProcessor.requestStallOpen` = `1296:2:<角色号>`
			var 后 := _后端()
			if 号 > 0 and 后 != null and bool(后.get("in_game")):
				后.call("request_stall_open", 号)
		"双修":
			## 点这一行 = 原版 `API.healHandler.requestToDoubleHeal(id)`（`HealHandler.as:374-395`）
			## —— **不是**直接把 `86:3` 发出去。原版先判三件事：我在双修吗 / 那具身体在不在这个场景 /
			## 离得够不够近（`|Δx|<40 && |Δy|<20`），**不够近就先自动走过去**、走到了再发。
			## 所以整条判定在场景那一侧（要读玩家位置、落脚点、远程演员），这里只负责问和说。
			var 后 := _后端()
			var 地图 := get_parent().get_node_or_null("LifeRoot")
			if 号 <= 0 or 后 == null or not bool(后.get("in_game")):
				_报("双修邀请需要在线")
			elif 地图 == null or not 地图.has_method("请求双修"):
				_报("双修邀请需要先进图")		# 拿不到场景就什么都不发，别演一次"成功"
			else:
				var 话 := String(地图.call("请求双修", 号))
				if not 话.is_empty():
					_报(话)
		"拜师":
			var 后 := _后端()
			if 号 > 0 and 后 != null and bool(后.get("in_game")):
				后.call("request_tutor_apply", 3, 号)		# TutorProcessor.as:222-228
		"收徒":
			var 后 := _后端()
			if 号 > 0 and 后 != null and bool(后.get("in_game")):
				后.call("request_tutor_apply", 4, 号)		# TutorProcessor.as:246-252
		"羁绊":
			## 原版 `DetailsWindow.as:343-345` → `SwitchController.requestWedding:200-210`
			## → `Client.Friend_requestTaStart:9103` → `127:15:<对面号>`。
			## 服务端 `fake_flash_server.py:23266-23283` 要求**对面在线**，把对面那份资料
			## 用 `61:14:<名>:<级>:<职>:<族>:<脸>:<号>` **回给发起方自己**（不推对面）⇒
			## 我这侧由 `窗口管理._on_羁绊预览帧` 把「发起羁绊」那一扇**直接开出来**（不走托盘）。
			var 后 := _后端()
			if 号 > 0 and 后 != null and bool(后.get("in_game")):
				后.call("request_bond_start", 号)
		"族邀":
			## 原版 `DetailsWindow.as:334-336` → `FamillyManager.invateToJoinFamilly:779-782`
			## = 一行转发，**客户端侧没有闸**（不判我在不在族、是不是族长）。
			## 权限在服务端：`fake_flash_server.py:33547` 那道 `is_leader` 之外 ⇒ 一发出去
			## 什么也不会发生。照原版发、不替它演一次失败提示，也不再谎报"本机没这条协议"。
			var 后 := _后端()
			if 号 > 0 and 后 != null and bool(后.get("in_game")):
				后.call("request_family_invite", 号)
		"赠花":
			## 原版 `DetailsWindow.as:337-342` → `MarryTableManager.openMarryZengHuaWindow:184-197`
			## = **只存「对面是谁」那四项、并发 `94:6`，窗还不开**（开在回帧那一刻，
			## `receiveRefreshFlowerWindow:338`）。⇒ 这里既不开窗也不重查，只做那两件事。
			## 那四项存到 `窗口管理` 上（`记赠花对面`）：窗和托盘都挂在那一侧，面板这边留一份
			## 就成两份账。⚠ **先存后发**，反了就可能把上一任对面灌进这一帧的窗里。
			## 以前这一行报的是"本机服务端还没有「赠花」这条协议" —— **那句是假的**（§3.256）：
			## 上行 `94:6` 与回帧 `58:2`、结算 `61:44` 服务端全都在发，缺的是客户端这一行没接。
			var 后 := _后端()
			var 管 := get_parent().get_node_or_null("窗口管理") as Node
			if 号 <= 0 or 后 == null or not bool(后.get("in_game")) or 管 == null:
				_报("赠花需要在线")
			else:
				管.call("记赠花对面", {"charId": 号, "name": _目标名(),
						"face": int(_目标信息.get("face", 0)),
						"level": int(_目标信息.get("level", 0))})
				后.call("request_flower_info", 号)

func _setup_feature_buttons(root: Control) -> void:
	var under_bar := root.get_node("角色状态/UnderBarButtons")
	(under_bar.get_node("ExchangeButton") as BaseButton).pressed.connect(_request_feature.bind("兑换"))
	(under_bar.get_node("CheckInButton") as BaseButton).pressed.connect(_request_feature.bind("签到"))
	var status_button := root.get_node("角色状态/StatusToggle") as BaseButton
	status_button.toggle_mode = false
	## 三档一律换 `texture_normal`（**不填 hover/pressed 槽**：Godot 松手会回 hover，
	## 原版 `MButton3.mouseUpHandler:103-108` 回的是 UP）；手型 = `buttonMode/useHandCursor`。
	status_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	status_button.mouse_entered.connect(_设模式钮态.bind(1))
	status_button.mouse_exited.connect(_设模式钮态.bind(0))
	status_button.button_down.connect(_设模式钮态.bind(2))
	status_button.button_up.connect(_设模式钮态.bind(0))
	status_button.pressed.connect(_点模式钮)
	## 头像下那颗「挂机设置」= 原版 `CharGuaJiButton`（`CharactorInfoPane.as:113-127`：
	## x=43,y=51、文字 `LangUtilUI.get("UI_24")`「挂机设置」），点它走
	## `reverseDisplay(GUA_JI_SETTING_WINDOW)`（`:405-412`）= **开/收挂机设置窗**。
	## ⚠ 它跟技能栏上方那颗球分工不同：球是 `BreathPane.__guaJi:104-111`
	## `isStart = !isStart` ⇒ **直接开始/停止挂机**、根本不开窗。
	## 这颗在场景里一直画着，但 `mouse_filter=2(IGNORE)` 且脚本从没人接过 ⇒
	## 看着像钮、点了没反应（用户 10-18 实机点出来的）。
	var 挂机设置 := root.get_node_or_null("角色状态/AutoCombatSettings/HangLabel") as Control
	if 挂机设置 != null:
		挂机设置.mouse_filter = Control.MOUSE_FILTER_STOP
		挂机设置.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		挂机设置.tooltip_text = "挂机设置"
		挂机设置.gui_input.connect(_挂机设置被点)


## 只认"左键按下"这一下：`gui_input` 会把移动/松开全送进来，不过门就会点一次开、松一次关。
func _挂机设置被点(事件: InputEvent) -> void:
	var 鼠标 := 事件 as InputEventMouseButton
	if 鼠标 == null or 鼠标.button_index != MOUSE_BUTTON_LEFT or not 鼠标.pressed:
		return
	_request_feature("挂机")

func _request_feature(feature_name: String) -> void:
	if _session != null:
		_session.request_feature(feature_name)

func _设模式钮态(态: int) -> void:
	_模式钮态 = 态
	if _status_button == null or not is_instance_valid(_status_button):
		return
	var 基: String = String(模式皮基名.get(_模式, "模式_普通"))
	var 尾: String = [".png", "_悬停.png", "_按下.png"][态]
	var 路 := 模式皮目录 + 基 + 尾
	_status_button.texture_normal = load(路) if ResourceLoader.exists(路) else null


## 原版 `set pvpMode:433-471`：先摘掉旧钮，再按模式号 new 一颗**带对应皮**的钮。
## ⚠ `OpenPvpMode.ZHENYING = 5`（阵营）在那个 switch 里**没有分支** ⇒ `_pvpBtn` 留 null =
##   那颗钮根本不出现。这边同样藏起来，不自造第五张皮。
func _刷模式钮(模式: int) -> void:
	_模式 = 模式
	if _status_button == null or not is_instance_valid(_status_button):
		return
	var 有档: bool = 模式皮基名.has(模式)
	_status_button.visible = 有档
	if not 有档:
		return
	_设模式钮态(_模式钮态)
	_status_button.tooltip_text = String(模式提示[模式])
	PK模式菜单.设选中(模式)


func _点模式钮() -> void:
	## `showPvpModeViewHandler:242-270`：木叶大战中 / 决斗中直接 return（本机没有木叶大战这一档，
	## 竞技场对战 = `竞技场窗.对战中()`）；否则在面板局部 (0,87) 开/收那张四行菜单。
	## ⚠ 以前这里是"点一下循环换档"（`current % 4 + 1`）= 自造行为，原版必须先弹菜单、点行才发。
	var 竞技场 := load("res://脚本/界面/窗口/竞技场窗.gd")
	if 竞技场 != null and 竞技场.对战中():
		return
	var 层 := _status_button.get_parent() as Control
	if 层 == null:
		return
	PK模式菜单.打开(层, Vector2(0, 87), _模式, _请求模式)


func _请求模式(号: int) -> void:
	## 菜单某一行的点击 = 原版 `PKEvent.CHANGE_MODE`（`onCheckPKMode:44-64`）。
	## 保留原有的"请求中禁用 + 5 秒超时回档"这一层（原版没有超时，但断线时不兜会一直灰着）。
	if _session == null or _pending_pk_mode >= 0:
		return
	_pending_pk_mode = 号
	_pk_request_started_msec = Time.get_ticks_msec()
	_status_button.disabled = true
	if _session.request_pk_mode(号):
		return
	_pending_pk_mode = -1
	_status_button.disabled = false
	_刷模式钮(int(_session.hud_state.get("pk_mode", 1)))
	_session.notification_requested.emit("战斗模式切换失败：尚未连接服务器")

func _process(delta: float) -> void:
	_提示秒表 += delta
	if _提示秒表 >= 1.0:
		_提示秒表 = 0.0
		_刷新状态提示()
	_闪烁节拍 += delta
	if _闪烁节拍 >= 0.06:
		_闪烁节拍 = 0.0
		if not _闪烁.is_empty():
			_推进闪烁(Time.get_ticks_msec())
	if _pending_pk_mode < 0 or Time.get_ticks_msec() - _pk_request_started_msec < 5000:
		return
	_pending_pk_mode = -1
	_status_button.disabled = false
	var mode := clampi(int(_session.hud_state.get("pk_mode", 1)), 1, 5) if _session != null else 1
	_刷模式钮(mode)
	if _session != null:
		_session.notification_requested.emit("战斗模式切换超时，请重试")

## 已删（2026-10-25 用户：「左上角还有 vip 标志，帮我完整的删掉」）：
## `_update_vip(level)` —— 原版 `CharactorInfoPane.as:532` 在 VIP < 6 时隐藏，上一版
## 为了"不要求 VIP"改成常亮，反而把徽记留在台上了。用户要的是**整颗没有**，
## 所以场景节点、两条成员、这条函数和两处调用全部删掉；别再照原版补回来。

func _clear_status_slots() -> void:
	_收起状态提示()
	_状态提示.clear()
	_闪烁.clear()
	for slot in _status_slots:
		slot.visible = false
		slot.self_modulate = Color.WHITE
		slot.tooltip_text = ""
		var 图标件 := slot.get_node_or_null("图标") as TextureRect
		if 图标件 != null:
			图标件.texture = null
			图标件.position = Vector2.ZERO
			图标件.size = Vector2.ZERO
		var 扇形 := slot.get_node_or_null("扇形") as ColorRect
		if 扇形 != null:
			扇形.visible = false
		_状态提示.append({})


## 图标落点照 `BuffCell.as:251-270`：
##   skillId/1000000 >= 9 ⇒ 居中；否则带 `pos` ⇒ (0,0)；否则 (3,3)。
## 原版只设 x/y、**不缩放**图标 ⇒ 这里 size 取贴图原生尺寸。
static func _图标偏移(技能号: int, 尺: Vector2, 贴零点: bool) -> Vector2:
	if 技能号 / 1000000 >= 9:
		return Vector2(float((40 - int(尺.x)) >> 1), float((40 - int(尺.y)) >> 1))
	if 贴零点:
		return Vector2.ZERO
	return Vector2(3, 3)


static func _扇形节点(格: Control) -> ColorRect:
	return 格.get_node_or_null("扇形") as ColorRect


func _设扇形(序号: int, 进度: float, 显示: bool) -> void:
	if 序号 < 0 or 序号 >= _status_slots.size():
		return
	var 扇 := _扇形节点(_status_slots[序号])
	if 扇 == null:
		return
	扇.visible = 显示
	if not 显示:
		return
	var 材 := 扇.material as ShaderMaterial
	if 材 != null:
		材.set_shader_parameter("progress", clampf(进度, 0.0, 1.0))


## 画一格，并把悬停要用的数据存起来。
## 用**原版提示框**（`MToolTipTextWithTitle`）而不是原生 `tooltip_text`：
## 原版 BuffCell 的 tooltip 是 `{title: name, desc: desc}`（`BuffCell.as:136-140`），
## 有橙色标题、白描述与剩余时间；原生 tooltip 是单色一行，玩家看到的不是原版那一套。
func _画状态格(序号: int, 图标: String, 标题: String, 描述: String,
		到期毫秒: int, 时间样式: String, 技能号: int = 0, 是道具: bool = false,
		贴零点: bool = false, 总毫秒: int = 0) -> void:
	if 序号 < 0 or 序号 >= _status_slots.size():
		return
	var 格 := _status_slots[序号]
	格.tooltip_text = ""
	格.visible = true
	格.self_modulate = Color.WHITE
	# 图由数据给（原版 `PicTool.getSkillPic` / `getItemPic`），没有兜底图。
	var 图 := _贴图(图标)
	var 图标件 := 格.get_node_or_null("图标") as TextureRect
	if 图标件 != null:
		图标件.texture = 图
		if 图 == null:
			图标件.size = Vector2.ZERO
		else:
			var 尺 := 图.get_size()
			图标件.size = 尺
			图标件.position = _图标偏移(技能号, 尺, 贴零点)
	# 原版只有「有限时长的技能类」与「全部道具类」有扇形；永久格（>= 2100000000 秒）没有。
	var 计时 := 总毫秒 > 0 and 总毫秒 < 2100000000000 and 到期毫秒 > 0 \
			and (是道具 or 时间样式 == "buff")
	var 开始 := 到期毫秒 - 总毫秒 if 计时 else 0
	_状态提示[序号] = {
		"title": 标题, "desc": 描述.strip_edges(),
		"expires": 到期毫秒, "time_style": 时间样式,
		"total": int(round(float(总毫秒) / 1000.0)) if 总毫秒 > 0 else 0,
		"total_ms": 总毫秒 if 计时 else 0,
		"started": 开始,
	}
	if 计时:
		_设扇形(序号, float(maxi(0, Time.get_ticks_msec() - 开始)) / float(总毫秒), true)
	else:
		_设扇形(序号, 0.0, false)


## 把三类状态合成一排（原版就是一个 `BuffPane`，没有分类）：
##   ① 天气（`HealHandler.setWeatherBuff`）② 限时道具（1292/1293/1294/2324）
##   ③ 服务端增益 + 客户端自造（族徽/连斩/打坐/罪状/系统双倍）。
## 顺序 = **首次到达序**；同一 `(type, skillId)` 视为同一格（`BuffPane.as:155`）。
func _render_status_effects(weather_type: int, buffs: Array, effects: Array) -> void:
	_clear_status_slots()
	var 现在 := Time.get_ticks_msec()
	var 条目: Array = []
	if weather_type >= 0:
		var weather := _状态图标("Weather/%d" % weather_type)
		if not weather.is_empty():
			# 原版 `HealHandler.setWeatherBuff:458-482`：title = buffName、desc = buffDesc、
			# remain/total = int.MAX（永久，不显示剩余时间、不建扇形）。
			条目.append({
				"键": "weather:%d" % weather_type,
				"图标": String(weather.get("贴图", "")),
				"标题": String(weather.get("名称", "")),
				"描述": String(weather.get("说明", "")),
				"到期": 0, "样式": "none", "技能号": 9000201 + weather_type,
				"是道具": false, "贴零点": false, "总毫秒": 0,
			})
	for value in effects:
		if not value is Dictionary:
			continue
		var effect := value as Dictionary
		var remaining := maxi(0, int(effect.get("remaining_seconds", 0)))
		# 帧只给"收到那一刻的剩余秒"；HUD 用收到时刻自己倒计时（原版 BuffPane.tick 每秒 setCD）。
		var 收到 := int(effect.get("received_at_msec", 0))
		var 到期 := (收到 if 收到 > 0 else 现在) + remaining * 1000
		var 总 := maxi(remaining, int(effect.get("total_seconds", remaining)))
		var 键 := String(effect.get("effect_key", ""))
		if 键.is_empty():
			键 = "%s:%d" % [String(effect.get("kind", "")), int(effect.get("item_id", 0))]
		条目.append({
				"键": "effect:" + 键,
				"图标": String(effect.get("icon", "")),
				"标题": String(effect.get("name", "限时状态")),
				"描述": String(effect.get("desc", "")),
				"到期": 到期, "样式": "item", "技能号": int(effect.get("item_id", 0)),
				"是道具": true, "贴零点": false, "总毫秒": 总 * 1000,
			})
	for value in buffs:
		if not value is Dictionary:
			continue
		var buff := value as Dictionary
		var 到期 := 0
		var 样式 := "none"
		var 总毫秒 := 0
		if buff.has("expires_at_msec"):
			到期 = int(buff.get("expires_at_msec", 0))
			样式 = "buff"
			if buff.has("total_time"):
				总毫秒 = maxi(0, int(buff.get("total_time", 0))) * 1000
			elif buff.has("duration_ms"):
				总毫秒 = maxi(0, int(buff.get("duration_ms", 0)))
		elif buff.has("duration_ms") and int(buff.get("duration_ms", 0)) > 0:
			到期 = int(buff.get("received_at_msec", 现在)) + int(buff.get("duration_ms", 0))
			样式 = "buff"
			总毫秒 = int(buff.get("duration_ms", 0))
		var 类型 := int(buff.get("type", 0))
		var 技能号 := int(buff.get("skill_id", 0))
		var 键 := "buff:%d:%d" % [类型, 技能号]
		if 技能号 == 0:
			键 += ":" + String(buff.get("name", ""))
		条目.append({
				"键": 键,
				"图标": String(buff.get("icon", "")),
				"标题": String(buff.get("name", "状态效果")),
				"描述": String(buff.get("desc", "")),
				"到期": 到期, "样式": 样式, "技能号": 技能号,
				"是道具": 类型 == 2, "贴零点": bool(buff.get("pos", false)),
				"总毫秒": 总毫秒,
			})
	var 在列 := {}
	for 条 in 条目:
		在列[String((条 as Dictionary)["键"])] = true
	for 键 in _到达时刻.keys().duplicate():
		if not 在列.has(键):
			_到达时刻.erase(键)
	var 排序列: Array = []
	for i in 条目.size():
		var 条 := 条目[i] as Dictionary
		var 键 := String(条["键"])
		if not _到达时刻.has(键):
			_到达时刻[键] = 现在
		排序列.append({"i": i, "t": int(_到达时刻[键])})
	排序列.sort_custom(func(a, b):
		if int((a as Dictionary)["t"]) == int((b as Dictionary)["t"]):
			return int((a as Dictionary)["i"]) < int((b as Dictionary)["i"])
		return int((a as Dictionary)["t"]) < int((b as Dictionary)["t"]))
	for 序 in 排序列.size():
		if 序 >= _status_slots.size():
			break
		var 条 := 条目[int((排序列[序] as Dictionary)["i"])] as Dictionary
		_画状态格(序, String(条["图标"]), String(条["标题"]), String(条["描述"]),
			int(条["到期"]), String(条["样式"]), int(条["技能号"]),
			bool(条["是道具"]), bool(条["贴零点"]), int(条["总毫秒"]))


func _显示状态提示(序号: int) -> void:
	if _标题提示 == null or 序号 < 0 or 序号 >= _状态提示.size():
		return
	if (_状态提示[序号] as Dictionary).is_empty():
		return
	_悬停格 = 序号
	_刷新提示内容()
	(_标题提示 as Control).visible = true
	var 主 := (头像区域节点() as Control)
	var 鼠标 := 主.get_local_mouse_position() if 主 != null else Vector2.ZERO
	_标题提示.call("贴到鼠标", 鼠标, _舞台尺寸())


func _收起状态提示() -> void:
	_悬停格 = -1
	if _标题提示 != null:
		_标题提示.call("收起")


## 每秒一次：扇形进度、到点进入闪烁；悬停中的剩余时间跟着走。
func _刷新状态提示() -> void:
	var 现在 := Time.get_ticks_msec()
	for i in _状态提示.size():
		var 条: Dictionary = _状态提示[i] as Dictionary
		if 条.is_empty():
			continue
		var 总毫秒 := int(条.get("total_ms", 0))
		var 开始 := int(条.get("started", 0))
		if 总毫秒 > 0 and 开始 > 0:
			_设扇形(i, float(现在 - 开始) / float(总毫秒), true)
		var 到期 := int(条.get("expires", 0))
		if 到期 > 0 and 到期 <= 现在 and not _闪烁.has(i):
			# 原版到点先闪 120ms×10 再收（`BuffCell.as:194-223`），不是立刻消失。
			_闪烁[i] = {"结束": 现在 + 1200, "下次": 现在}
	if _标题提示 != null and _标题提示.visible and _悬停格 >= 0 \
			and _悬停格 < _状态提示.size() and not (_状态提示[_悬停格] as Dictionary).is_empty():
		_刷新提示内容()


## 到点闪烁：每 120ms 切一次 alpha（0.5 ↔ 1），1.2 秒后收格并清掉悬停。
func _推进闪烁(现在: int) -> void:
	for i in _闪烁.keys().duplicate():
		if i < 0 or i >= _status_slots.size():
			_闪烁.erase(i)
			continue
		var 格 := _status_slots[i]
		var 姿: Dictionary = _闪烁[i]
		if 现在 >= int(姿.get("结束", 0)):
			_闪烁.erase(i)
			格.visible = false
			格.self_modulate = Color.WHITE
			_状态提示[i] = {}
			if _悬停格 == i:
				_收起状态提示()
			continue
		if 现在 >= int(姿.get("下次", 0)):
			姿["下次"] = 现在 + 120
			格.self_modulate.a = 0.5 if 格.self_modulate.a > 0.9 else 1.0


func _刷新提示内容() -> void:
	if _标题提示 == null or _悬停格 < 0 or _悬停格 >= _状态提示.size():
		return
	var 条: Dictionary = _状态提示[_悬停格] as Dictionary
	if 条.is_empty():
		return
	var 描述 := String(条.get("desc", ""))
	var 到期 := int(条.get("expires", 0))
	if 到期 > 0:
		var 剩 := maxi(0, ceili(float(到期 - Time.get_ticks_msec()) / 1000.0))
		var 样式 := String(条.get("time_style", "none"))
		if 样式 == "item":
			# `BuffCell.updateItemToolTip:57`：道具描述 + `剩余容量：remain/total`（秒）。
			描述 += "\n剩余容量：%d/%d" % [剩, int(条.get("total", 剩))]
		elif 样式 == "buff":
			# `BuffCell.updateToolTip:172`：技能描述 + `BaseUtil.getLeftTimeText`。
			描述 += "\n剩余时间：" + _左时间文案(剩)
	_标题提示.call("设置", String(条.get("title", "")), 描述, _舞台尺寸())


## `BaseUtil.getLeftTimeText:332-348`：`剩余时间：` + [N天] + H小时M分S秒（小时总是显示）。
static func _左时间文案(总秒: int) -> String:
	var 天数 := int(总秒 / 86400)
	var 余 := 总秒 % 86400
	var 小时 := int(余 / 3600)
	余 %= 3600
	var 分钟 := int(余 / 60)
	var 秒 := 余 % 60
	var 文 := ""
	if 天数 > 0:
		文 += "%d天" % 天数
	return 文 + "%d小时%d分%d秒" % [小时, 分钟, 秒]


func _舞台尺寸() -> Vector2:
	var 视口 := get_viewport()
	var 尺寸: Vector2 = 视口.get_visible_rect().size if 视口 != null else Vector2.ZERO
	return 尺寸 if 尺寸.x > 0.0 and 尺寸.y > 0.0 else Vector2(960.0, 560.0)


func 头像区域节点() -> Control:
	return get_node_or_null("头像区域") as Control

func _pk_mode_name(mode: int) -> String:
	if mode >= 1 and mode <= 战斗模式档.size():
		return String((战斗模式档[mode - 1] as Dictionary).get("名", "普通"))
	return "阵营"
