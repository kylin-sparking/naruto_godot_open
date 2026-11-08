extends RefCounted

## 竞技场主窗 = 原版 `com/mxw/uifl/controls/pvp/PvpWindow`（**770×567**，标题「竞技场」）
## 加上 `PvpManager` 那侧的状态与闸门。**逐句转写，不重写**：函数边界、条件顺序、常量都照 AS3，
## 只多一层 API 对照（`addChild` → 场景树、`getTimer()` → `Time.get_ticks_msec()`）。
##
## 层栈与逐件坐标：`真值/窗口/竞技场.md` §⑪（每张图的天然尺寸是 ffdec 从 UISwf_Pvp* 实测的）。
## 包形（上行 0..6 / 下行 0..11 两张独立表）：同文件 §2B。
##
## 原版这一族的**状态全在单例 `PvpManager`**（`pkLevel` / `candidateList` / `_reportsList` / `pkInfo` /
## `awardLevel` / `awardStat` / 三枚「今日不再提示」旗），窗只是它的消费者 ⇒ 这边同样放 `static var`，
## **换图/关窗都不清**（原版单例活一整局）。`新会话()` 只在登录/换号时调。
##
## ★ 三条**原版自己就是这样**、不是我们做错了的事：
##   ① 挑战被服务端拒（等级 < 数据表 `reqLevel`=45、次数用完、正在副本/挂机…）时，服务端**只回一帧
##      `2306:0` 面板，一句提示都没有**（`fake_flash_server.py:29420-29422`）⇒ 这边也不加提示；
##   ② 客户端那道开窗闸是 **30 级**（`PvpManager.as:30`），跟服务端的 45 级**不是一把尺**
##      ⇒ 30~44 级能开窗、点挑战没反应；要不要统一，等他点头（真值 §⑨）；
##   ③ `PvpPlayerCell.as:157` 那枚「此人正在对战」的剑（`UISwf_Pvp_Jian`）**在导出表里查无**
##      ⇒ 原版从来不显示它 ⇒ 这边不移植（`inBattle` 只留在数据里，不画）。

const 角色造型 := preload("res://脚本/角色/角色造型.gd")
const 元件根 := "res://素材/界面/原版窗口/竞技场/"
const 钮底37 := [
	"res://素材/界面/原版窗口/家族/钮底37.png",
	"res://素材/界面/原版窗口/家族/钮底37_悬停.png",
	"res://素材/界面/原版窗口/家族/钮底37_按下.png",
]
const 排名奖表路径 := "res://数据/界面/竞技场排名奖.json"
const 竞技场结算弹脚本 := preload("res://脚本/界面/窗口/竞技场结算弹.gd")
const 输入确认弹脚本 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 战报弹脚本 := preload("res://脚本/界面/窗口/竞技场战报弹.gd")
const 邀请托盘脚本 := preload("res://脚本/界面/邀请托盘.gd")
## 竞技场图号 = `Pk.common.mapid`（真值 §⑨；服务端 `_arena_player_monster_spawn_payload:29511`
## 那一帧第 5 段发的也是这个数）。原版是 `ImgUtil.getImg(ImgType.Pk,"common").mapid` 现读。
const 竞技场图号 := 503000000

const 门槛 := 30				# `PvpManager.as:30` `PVP_ENTER_LEVEL`
const 战报上限 := 5				# `:32` `MAX_ZHANBAO_COUNT`
const 托盘上限 := 3				# `:371` `if(this._recentReports.length > 3)`
const 候选格数 := 5				# 服务端 `_arena_candidates()[:5]`

## 颜色全部取 AS3 字面量：`UIConfig.as:924/926/932`、`PvpManager.as:183/192/195/205/217`、
## `PvpWindow.as:236`（光晕 11481344 = #AF8020）、`PvpPlayerPanel.as:139`（65280 = #00FF00）。
const 色黄 := Color(1.0, 0.941176, 0.0)			# UI_YELLOW #FFF000
const 色蓝 := Color(0.117647, 0.564706, 1.0)		# UI_BLUE #1E90FF
const 色白 := Color(1, 1, 1)
const 色绿 := Color(0, 1, 0)
const 色橙 := Color(1.0, 0.568627, 0.0)			# #ff9100（我的排名那个数字）
const 色粉 := Color(1.0, 0.329412, 0.588235)		# #FF5498（战报里对面的名字）

## ── `PvpManager` 的实例字段（会话级）──
static var 排名 := 0					# `pkLevel`
static var 候选: Array = []				# `candidateList`
static var 候选序: Array = []				# 摆进那五格的**排好序的那份**（第 N 格 = 第 N 行）
static var 战报: Array = []				# `_reportsList`
static var 计数: Dictionary = {}			# `pkInfo`（PkCharInfo 那五段）
static var 公告 := ""					# `jingJiNotice`（一条聊天帧，重开窗要补灌）
static var 奖等级 := -1					# `awardLevel`
static var 奖状态 := 0					# `awardStat`（`PkAwardStat` 0/1/2）
static var 收帧毫秒 := 0				# `pvpAppStartTime = getTimer()`
static var 要挑战提示 := true				# `isTiaoZhanTip`
static var 要清CD提示 := true				# `isCDTip`
static var 要加次提示 := true				# `isAddCountTip`
static var 上次选挑战 := true				# `isTiaoZhan`
static var 战斗剩余 := 0				# `_pvpRemainSeconds`
static var 自己名 := ""
static var 自己号 := -1				# `API.dataCenter.stats.id`（战报里判"是不是我"）
static var 竞技场页: Control = null			# 当前开着的那扇（回帧原地塞数；窗关掉就置空）
static var 在对战 := false				# `isPking`（`:36`）——**换图**那一拍翻，不是收到哪一帧翻
static var 英雄榜: Array = []				# `onPk_showHeroList:327-333` 那份（≤100 行）
static var 生命: Node = null				# 当前这张图的 `LifeRoot`（倒计时/进场钟/藏宠物都挂在它身上）
static var 管理: Node = null				# 当前这章的 `窗口管理`（一扇窗都没开时，弹窗要落在它下面）
static var 浮层: Control = null			# `管理` 下那层整屏浮层（排名奖那种不依附窗的弹窗）
static var 近期战报: Array = []			# `_recentReports`（`PvpManager.as:66`）：[{流水号, 时间戳}]，屏上最多 4 格


static func 新会话() -> void:
	排名 = 0
	候选 = []
	候选序 = []
	战报 = []
	计数 = {}
	公告 = ""
	奖等级 = -1
	奖状态 = 0
	收帧毫秒 = 0
	战斗剩余 = 0


## 宿主 = `功能窗口`（要 `_content` / `_通知` / `_session` / `_backend`）。
## 原版 `initView:280-285` = 转圈 + `_panel.visible = false` + 发上行 0 ⇒ 这边同样**开窗即拉**，
## 面板先藏，等 `2306:0` 那一帧回来才显形（回帧只原地塞数、绝不拆页，同一族坑见 #312）。
static func 渲染(宿主: Node, 场景: PackedScene) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	页.visible = false				# `initView:283` `_panel.visible = false`
	竞技场页 = 页						# ★ 回帧要靠它，漏了这一步 = 喂了帧界面一动不动
	var 身: Dictionary = (宿主.get("_session") as Node).get("player_stats")
	自己号 = int(身.get("id", -1))
	自己名 = String(身.get("name", ""))
	接线(页, 宿主)
	上公告(页)
	画立绘(页, 宿主)
	挂全局(宿主.get("_backend") as Node)
	_拉一次(宿主)
	return 页


## `PvpWindow.drawFace:174-193`：那一整张**职业立绘**按 `stats.job` 换 ——
## 100 火 / 200 水 / 300 雷 / 400 风（摆位 `y = 查看英雄榜.y + 20` 已烘在场景的 `立绘` 上）。
## ⚠ 这不是候选格那颗按 `face` 取的头像，是四张 240×334 的整幅皮；以前整条漏了 ⇒ 场景里烘死火，
##   雷职业进来看到的还是火（10-24 用户实机报的第二条）。
## 原版 switch 没有 default（四个职业号全覆盖）⇒ 查不到号就保留烘好的那张，不另发明行为。
const 立绘皮 := {
	100: "res://素材/界面/原版窗口/竞技场/UISwf_PvpHuo_Skin.png",
	200: "res://素材/界面/原版窗口/竞技场/UISwf_PvpShui_Skin.png",
	300: "res://素材/界面/原版窗口/竞技场/UISwf_PvpLei_Skin.png",
	400: "res://素材/界面/原版窗口/竞技场/UISwf_PvpFeng_Skin.png",
}


static func 画立绘(页: Control, 宿主: Node) -> void:
	var 身: Dictionary = (宿主.get("_session") as Node).get("player_stats")
	var 路 := String(立绘皮.get(int(身.get("job", 0)), ""))
	if 路.is_empty() or not ResourceLoader.exists(路):
		return
	(页.get_node("面板/立绘") as TextureRect).texture = load(路) as Texture2D


static func _拉一次(宿主: Node) -> void:
	var 后: Node = 宿主.get("_backend") as Node
	if 后 != null and 后.has_method("request_arena_panel"):
		后.call("request_arena_panel")


## `PvpWindow.onLoadComplete:195-265` 那一串监听（原版在元件加载完才建件，这边场景里已烘好 ⇒ 只接信号）。
static func 接线(窗: Control, 宿主: Node) -> void:
	(窗.get_node("面板/左列/查看英雄榜") as LinkButton).pressed.connect(_点英雄榜.bind(宿主))
	var 加次 := 窗.get_node("面板/候选块/增加钮") as TextureButton
	加次.pressed.connect(_点加次.bind(宿主))
	_装三态(加次, 钮底37)
	加次.visible = _VIP够(宿主)			# `PvpPlayerPanel.as:161`
	var 清CD := 窗.get_node("面板/候选块/清CD钮") as TextureButton
	清CD.pressed.connect(_点清CD.bind(宿主))
	清CD.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for 序 in range(1, 候选格数 + 1):
		var 格 := 窗.get_node("面板/候选块/候选容器/候选格%d" % 序) as Control
		## ★ 原版只有**头像**吃点击（`PvpPlayerCell.as:146-151` 三个监听都挂在 `_portraitHead` 上），
		## 点名字/排名/框都没反应 ⇒ 命中盒只给头像那颗按钮。
		var 头像 := 格.get_node("头像") as TextureButton
		头像.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		头像.pressed.connect(_点头像.bind(宿主, 序))
		头像.mouse_entered.connect(_格悬停.bind(格, true))
		头像.mouse_exited.connect(_格悬停.bind(格, false))


## 回帧消费者：**原地改，绝不拆页**（同一族坑见 #312 —— 拆页会让按住/抬起落到已释放的件上）。
## ★ **常驻挂一次，不挂在某一扇窗上**：原版 `PvpManager` 是单例 ⇒ 十二档下行一直有人接
##   （`2306:8` 排名奖到手、`2306:10` 被人挑战这两档，玩家完全可能一扇竞技场窗都没开着就收到）。
##   本工程原来把 `接帧` 放在主窗 `渲染()` 里 ⇒ “没开过主窗 = 整族帧丢掉”
##   （`开发工具/验竞技场英雄榜.gd` 第一次跑就抓到：只开英雄榜时喂 `2306:9` 五条判据全红）。
##   落点火候照 `窗口管理._ready` 里 `heal_state_received` 那一族：每章地图建窗口管理时挂一次，
##   `is_connected` 挡住重接；`_回帧` 因此**不再要宿主**（要窗的地方改成要 `管理` 下那层浮层）。
static func 挂全局(后: Node, 管: Node = null) -> void:
	if 管 != null:
		管理 = 管
	if 后 == null or not 后.has_signal("竞技场帧"):
		return
	if not 后.is_connected("竞技场帧", _回帧):
		后.connect("竞技场帧", _回帧)


static func _回帧(动作: int, 值: Dictionary) -> void:
	## `PvpManager` 那 12 个 `onPk_*` 回调逐个对应：
	match 动作:
		0:
			## `onPk_panelInfo:105-117`：先刷四份状态，再喂窗（窗没开 ⇒ 只存状态）。
			## ★ 喂窗的是 `_reportsList`（**合并后的**那份），不是包里的 `param3` ⇒ 顺序照抄。
			收帧毫秒 = int(Time.get_ticks_msec())		# `:107`
			排名 = int(值.get("排名", 0))
			候选 = 值.get("候选", []) as Array
			_并战报(值.get("战报", []) as Array)		# `reportsList` setter `:465-488`
			计数 = _取计数(值)
			_刷页()
		1:
			排名 = int(值.get("排名", 0))			# `onPk_updatePkLevel:490-497`
			_刷页()
		2:
			候选 = 值.get("候选", []) as Array		# `onPk_updateCandidates:393-399`
			_刷页()
		3:
			_并战报(值.get("战报", []) as Array)		# `onPk_updateBattleReports:266-274`
			_刷页()
		4:
			收帧毫秒 = int(Time.get_ticks_msec())		# `onPk_updatePkInfo:438-447`
			计数 = _取计数(值)
			_刷页()
		5:
			战斗剩余 = int(值.get("秒", 0))			# `onPk_showBattleRemainTime:276-279`
		6:
			## `onPk_showBattleCountDown:302-305` = `player_showCopyEnterClock(0, 秒, false,
			## LangUtilCore.get("PVP_ENTER_JINGJICHANG_DAOJISHI"))`。
			## ★ 键名写 ENTER、文案却是「**退出**竞技场倒计时:」⇒ 原版自己不一致，照抄不改（真值 §⑤）。
			_喊进场钟(生命, "退出竞技场倒计时:", int(值.get("秒", 0)))
		7:
			## `onPk_showBattlePrize:458-463`：`setDOShow(PVP_RESULT_WINDOW,true)` + `onResult(胜, 阅历)`
			## ★ 宿主给 `生命`（地图根）而**不给这扇窗的 `_overlay`**：进战斗那一拍窗全被关了，
			##   挂在关掉的宿主里 = 玩家什么都看不见（原版这扇是 `windowMap` 里独立的一扇）。
			_弹出结算(bool(值.get("胜", false)), int(值.get("阅历", 0)))
		8:
			## `onPk_showPaiHangPrize:98-103`：`FamillyPopUpWindow.popUpWindow(文案,null,null,"",null,"",false)`
			## + `hideCancelButton()` ⇒ 家族那套确认弹、只留一颗居中的「确定」（`COMMON_OK`，
			## 因为 `updateView:80-83` 那个 `if(param3)` 对空串不成立 ⇒ 钮文字保持默认）。
			输入确认弹脚本.弹单钮(_全局浮层(), 排名奖文案(int(值.get("排名", 0)), int(值.get("阅历", 0))))
		9:
			## `onPk_showHeroList:327-333`：只喂**已经开着**的那扇英雄榜；窗没开 ⇒ 存着不动（原版丢掉）。
			英雄榜 = 值.get("英雄", []) as Array
			_刷英雄榜()
		10:
			## `onPk_challengedReport:359-391`：① 并进战报列表 + 刷主窗（窗没开只并表）
			## ② 右下角托盘塞一枚。★ 顺序照 AS3 原样：**先按 timeStamp 去重 return、
			##   再 `length > 3` shift 删最旧、最后才 addMsg**（`_recentReports` 比的是**那条的
			##   timeStamp**，不是角色号 ⇒ 同一场只留一格）。
			var 战报条 := 值.get("战报", {}) as Dictionary
			_并战报([战报条])
			_刷页()
			_塞战报格(战报条)
		11:
			奖等级 = int(值.get("排名", 0))			# `onPk_updateAwardStat:136-148`
			奖状态 = int(值.get("状态", 0))
			_刷页()
		_:
			return


static func _取计数(值: Dictionary) -> Dictionary:
	return {
		"已用": int(值.get("已用", 0)), "上限": int(值.get("上限", 0)),
		"冷却": int(值.get("冷却", 0)), "连胜": int(值.get("连胜", 0)),
		"距明天": int(值.get("距明天", 0)),
	}


## `set reportsList:465-488` + `addReport:281-295` + `sortReport:449-456` 三段合一：
## 空表 ⇒ 直接接过来；非空 ⇒ 逐条 `addReport`（**按 `timeStamp` 去重，同戳覆盖那一条**）；
## 最后按 `timeStamp` 降序 + 截前 5 条。★ 不许改成"整表替换"，那是另一套行为。
static func _并战报(新: Array) -> void:
	if 新.is_empty():
		return
	if 战报.is_empty():
		战报 = 新.duplicate(true)
	else:
		for 条 in 新:
			_加战报(条 as Dictionary)
	_排战报()


static func _加战报(条: Dictionary) -> void:
	for 序 in range(战报.size()):
		if int((战报[序] as Dictionary).get("timeStamp", 0)) == int(条.get("timeStamp", 0)):
			战报[序] = 条
			return
	战报.append(条)


static func _排战报() -> void:
	战报.sort_custom(func(a, b) -> bool:
		return int(a.get("timeStamp", 0)) > int(b.get("timeStamp", 0)))
	if 战报.size() > 战报上限:
		战报 = 战报.slice(0, 战报上限)


## 把状态写回那一扇窗（= `PvpWindow.updateView:82-90` 的四步 + `:263` 补灌公告）。
static func _刷页() -> void:
	if 竞技场页 == null or not is_instance_valid(竞技场页):
		return
	竞技场页.visible = true					# `updateView:85`
	_填排名(竞技场页)
	_填候选(竞技场页)
	_填战报(竞技场页)
	_填计数(竞技场页)
	上公告(竞技场页)


static func 上公告(页: Control) -> void:
	if 公告.is_empty():
		return
	## `updateJingJiNotice:267-273` = `htmlText = param1.text.replace("[JH]","")`
	(页.get_node("面板/公告") as RichTextLabel).text = 公告.replace("[JH]", "")


static func _填排名(页: Control) -> void:
	(页.get_node("面板/左列/排名行/值") as Label).text = str(排名)
	(页.get_node("面板/候选块/我的排名") as RichTextLabel).text = (
		"[color=#ffffff]我的排名[/color][color=#ff9100] %d[/color]" % 排名)
	_填排名奖(页)


## `updatePrizeTime:140-165` + `tickPrizeTime:298-318`：
## 排名在奖表里 ⇒ 「保持排名第N的奖励：阅历X，领取时间」+（≥1 天给「N天后」，否则 `HH:MM:SS` 走秒）；
## 不在 ⇒ 「您当前排名N，未上榜」并且**停掉走秒**。
static func _填排名奖(页: Control) -> void:
	var 奖 := _排名奖(排名)
	var 标 := (页.get_node("面板/排名奖") as Label)
	if 奖.is_empty():
		标.text = "您当前排名%d，未上榜" % 排名
		return
	var 剩余 := float(int(计数.get("距明天", 0))) - float(int(Time.get_ticks_msec()) - 收帧毫秒) / 1000.0
	var 天 := int(剩余 / 86400.0)
	if 天 >= 1:
		标.text = "保持排名第%d的奖励：阅历%d，领取时间%d天后" % [排名, int(奖["yueli"]), 天]
	else:
		var 时 := int(剩余 / 3600.0)
		var 分 := int(fmod(剩余, 3600.0) / 60.0)
		var 秒 := int(fmod(剩余, 60.0))
		标.text = "保持排名第%d的奖励：阅历%d，领取时间%02d:%02d:%02d" % [
			排名, int(奖["yueli"]), 时, 分, 秒]
	标.tooltip_text = "时间到后系统自动发放奖励"		# `:226` `PVP_GET_PAIHANG_PRIZE`


static func _排名奖(名次: int) -> Dictionary:
	if not FileAccess.file_exists(排名奖表路径):
		return {}
	var 解: Variant = JSON.parse_string(FileAccess.get_file_as_string(排名奖表路径))
	if typeof(解) != TYPE_DICTIONARY:
		return {}
	return (解 as Dictionary).get(str(名次), {}) as Dictionary


## `updateCandidates:334-337` → `PvpPlayerPanel.updateCandidates:328-352`：
## 先全拆再按 **`pkLevel` 降序** 建 ⇒ 这边同样先清空五枚再喂。
static func _填候选(页: Control) -> void:
	var 表 := _排候选()
	候选序 = 表			# ★ 点第 N 格要发的是**这一份第 N 行**那个号（见 `_点头像`）
	for 序 in range(1, 候选格数 + 1):
		var 格 := 页.get_node("面板/候选块/候选容器/候选格%d" % 序) as Control
		var 条: Dictionary = 表[序 - 1] if 序 - 1 < 表.size() else {}
		_喂格(格, 条)


## `PvpWindow:170-176` 那份"先按 `pkLevel` 降序再摆五格"的排序。**单独抽出来**是给离线门判得动：
## 光看 `_喂格` 里那几行文字看不出"第 N 格 = 第 N 行"这条映射，而它一旦与 `_点头像` 的取法脱节，
## 点下去发的就是**别人**的号（10-24 那版把号写进 `set_meta("号")`，中文 meta 键根本存不进去 ⇒
## 取回来恒 0 ⇒ 点头像永远没反应）。
static func _排候选() -> Array:
	var 表 := 候选.duplicate(true)
	表.sort_custom(func(a, b) -> bool:
		return int(a.get("pkLevel", 0)) > int(b.get("pkLevel", 0)))
	return 表


static func _喂格(格: Control, 条: Dictionary) -> void:
	格.visible = not 条.is_empty()
	if 条.is_empty():
		return
	var 头像 := 格.get_node("头像") as TextureButton
	## `PortraitHead` 默认 `_w=_h=-1` ⇒ **不缩放**，按天然尺寸画在框正中（`:93` 那个判据）。
	## 头像查不到就留着原来那张，别刷成空白（口径同 `头像面板.gd:172`）。
	var 图: Texture2D = OriginalSprite.portrait("character", 角色造型.造型号(int(条.get("face", 0)), 0))
	if 图 != null:
		头像.texture_normal = 图
	(格.get_node("排名") as Label).text = str(int(条.get("pkLevel", 0)))
	(格.get_node("名字") as Label).text = String(条.get("name", ""))
	(格.get_node("等级") as Label).text = "等级%d" % int(条.get("playerLevel", 0))
	(格.get_node("头像") as Control).tooltip_text = _属性提示(条)


## `PvpPlayerCell.getTipString:74-85`：先是「排名第N位 每期排名奖励获得 X阅历」（查得到奖表才有），
## 换行，再是六项属性。★ 这条用的是 `PVP_PAIMING_TIP`（**每期**），跟窗顶那条 `*_PRIZE_TIP`（本期）不是一个键。
static func _属性提示(条: Dictionary) -> String:
	var 头 := ""
	var 奖 := _排名奖(int(条.get("pkLevel", 0)))
	if not 奖.is_empty():
		头 = "[color=#ffffff]排名第%d位\n每期排名奖励获得\n[/color][color=#fff000]%d阅历[/color]\n" % [
			int(条.get("pkLevel", 0)), int(奖["yueli"])]
	return 头 + "攻击：%d\n防御：%d\n暴击：%d\n闪避：%d\n攻击速度：%d\n移动速度：%d" % [
		int(条.get("atk", 0)), int(条.get("def", 0)), int(条.get("bsk", 0)),
		int(条.get("avd", 0)), int(条.get("atkspeed", 0)), int(条.get("wlkspeed", 0))]


## `updateBattleReports:135-138` → `PvpZhanBaoPanel.setData:46-63`（行距恒 23）。
static func _填战报(页: Control) -> void:
	var 容器 := 页.get_node("面板/战报块/战报容器") as Control
	for 序 in range(1, 战报上限 + 1):
		var 行 := 容器.get_node("战报行%d" % 序) as Control
		var 有 := 序 - 1 < 战报.size()
		行.visible = 有
		if not 有:
			continue
		var 条: Dictionary = 战报[序 - 1]
		(行.get_node("文本") as RichTextLabel).text = 战报文本(条, 自己号)


## `PvpManager.getZhanBao:150-228` 逐句。`自己号` = `API.dataCenter.stats.id`。
static func 战报文本(条: Dictionary, 自己号: int) -> String:
	if 条.is_empty():
		return ""
	var 前 := ""
	var 差: float = absf(float(int(条.get("timeStamp", 0))) - float(Time.get_unix_time_from_system()))
	var 天 := int(差 / 86400.0)
	var 时 := int(差 / 3600.0)
	var 分 := int(差 / 60.0)
	var 头 := ""
	if 天 > 0:
		if 天 < 2:
			前 = "昨天"
		else:
			前 = "%d天前" % 天
	elif 时 > 0:
		前 = "%d小时前" % 时
	elif 分 > 0:
		前 = "%d分钟前" % 分
		if 分 <= 5:
			头 = "[color=#00ff00]新战报：[/color] "
	else:
		头 = "[color=#00ff00]新战报：[/color] "
		前 = "%d秒前" % int(差)
	var 我赢: bool = int(条.get("winnerId", 0)) == 自己号
	var 对方 := String(条.get("loserName", "")) if 我赢 else String(条.get("winnerName", ""))
	头 += "[color=#ffffff]%s[/color]" % 前
	if int(条.get("challenger", 0)) == 自己号:
		头 += "[color=#ffffff]你挑战[color=#FF5498] %s[/color]，[/color]" % 对方
	else:
		头 += "[color=#FF5498] %s[/color][color=#ffffff]挑战你，[/color]" % 对方
	if 我赢:
		头 += "[color=#fff000]你获胜了！[/color]"
		头 += ("[color=#ffffff]排名升至%d[/color]" % int(条.get("resultPkLevel", 0))
			if int(条.get("challenger", 0)) == 自己号 else "[color=#ffffff]排名不变[/color]")
	else:
		头 += "[color=#00ff00]你战败了！[/color]"
		头 += ("[color=#ffffff]排名不变[/color]"
			if int(条.get("challenger", 0)) == 自己号
			else "[color=#ffffff]排名降至%d[/color]" % int(条.get("resultPkLevel", 0)))
	return 头


static func _填计数(窗: Control) -> void:
	(窗.get_node("面板/左列/名字") as Label).text = 自己名	# `updatePkInfo:329`
	(窗.get_node("面板/左列/连胜行/值") as Label).text = str(int(计数.get("连胜", 0)))
	var 剩: int = int(计数.get("上限", 0)) - int(计数.get("已用", 0))
	(窗.get_node("面板/候选块/剩余次数") as RichTextLabel).text = (
		"[color=#ffffff]今日还可挑战[color=#fff000]%d[/color]次[/color]" % 剩)
	var 冷却: int = int(计数.get("冷却", 0))
	(窗.get_node("面板/候选块/清CD钮") as Control).visible = 冷却 > 0
	var 秒标 := (窗.get_node("面板/候选块/CD秒") as Label)
	秒标.visible = 冷却 > 0
	秒标.text = _冷却文本(冷却)
	(窗.get_node("面板/候选块/清CD钮") as Control).tooltip_text = "清除CD需要%d元宝" % _清CD价(冷却)


## `PvpPlayerPanel.tickCDTime` 那一句的口径：`mm:ss`（服务端 `:29340` 按分钟计价 ⇒ 这里也只按分钟）。
static func _冷却文本(秒: int) -> String:
	return "%02d:%02d" % [int(秒 / 60), int(fmod(秒, 60))]


## `getClearCDTimeYuanBao:205-213` = `ceil(剩余/60) * killCDPerMinuteNeed`，数据表那份 = 1 元宝/分钟。
static func _清CD价(秒: int) -> int:
	return int(ceil(float(秒) / 60.0)) * _每分钟元宝()


static func _每分钟元宝() -> int:
	return 1						# `Pk.common.killCDPerMinuteNeed`（真值 §⑨，数据表现值）


static func _加次价() -> int:
	## `getAddTianJiaCountYuanBao:264-272` = `(pkMaxCount - freePkCount + 1) * addPkCountNeed`
	return (int(计数.get("上限", 0)) - 15 + 1) * 2


static func _VIP够(宿主: Node) -> bool:
	## `PvpPlayerPanel.as:161` `VIPManager.vipLevel >= VIPManager.CANG_KU_LEVEL`（仓库等级 = 2）
	var 会: Node = 宿主.get("_session") as Node
	if 会 == null:
		return false
	return int((会.get("player_stats") as Dictionary).get("vip_level", 0)) >= 2


static func _格悬停(格: Control, 进: bool) -> void:
	## `overHandler:95-108` / `outHandler:87-93`：悬停层 `addChildAt(…,1)` ⇒ 压在头像框之上、
	## 名字条之下（场景里就按这个次序摆），只切 `visible`。
	(格.get_node("悬停层") as Control).visible = 进


## ── 上行四条（都在客户端闸门之后才发，闸门顺序照 `PvpPlayerPanel`）──

## 点头像 = `tiaoZhanPlayer(charId):174-191`：先判 CD（有 CD ⇒ 走「清CD并挑战」那条），
## 再判剩余次数（<=0 ⇒ **只提示，连上行都不发**），都过了才弹那一枚双钮确认。
static func _点头像(宿主: Node, 序: int) -> void:
	var 格: Control = 竞技场页.get_node("面板/候选块/候选容器/候选格%d" % 序) as Control
	if 格 == null or not 格.visible:
		return
	## ★ 号从 `候选序` 按**同一份排序**取，不从节点上捞：中文 `set_meta` 键在 Godot 4 里
	##   是"报错 + 存不进去"（`Invalid metadata identifier`），上一版那么写 ⇒ 取回恒 0 ⇒
	##   点头像永远没反应（10-24 由 `窗口行为契约体检`/`窗口布局体检` 那两条"空页"红揪出来）。
	var 条: Dictionary = (候选序[序 - 1] as Dictionary) if 序 - 1 < 候选序.size() else {}
	var 号 := int(条.get("charId", 0))
	if 号 <= 0:
		return
	if int(计数.get("冷却", 0)) > 0:
		_弹挑战确认(宿主, 号, true)
		return
	if int(计数.get("上限", 0)) - int(计数.get("已用", 0)) <= 0:
		宿主._通知("今日您的挑战次数已经用完")		# `PVP_COUNT_USE_FINISHED`
		return
	_弹挑战确认(宿主, 号, false)


## `enoughTiaoZhan:70-86`：旗开着 ⇒ 弹「你需要选择无需挑战直接查看结果吗？」**双钮**（挑战 / 查看结果）
## + 「今日不再提示」勾；旗关了 ⇒ 按上次那一支直接走（`isTiaoZhan` 真=挑战、假=查看结果）。
static func _弹挑战确认(宿主: Node, 号: int, 先清CD: bool) -> void:
	if not 要挑战提示:
		_发挑战(宿主, 号, 0 if 上次选挑战 else 1, 先清CD)
		return
	宿主.call("弹出双钮确认",
		"你需要选择无需挑战直接查看结果吗？",
		"挑战", func(勾: bool) -> void: _选挑战(宿主, 号, 先清CD, true, 勾),
		"查看结果", func(勾: bool) -> void: _选挑战(宿主, 号, 先清CD, false, 勾),
		"今日不再提示")


static func _选挑战(宿主: Node, 号: int, 先清CD: bool, 是挑战: bool, 勾了: bool) -> void:
	## `tiaoZhan:166-172` / `viewResult:215-221`：先落两枚旗，再走 `startTiaoZhan`。
	要挑战提示 = not 勾了
	上次选挑战 = 是挑战
	_发挑战(宿主, 号, 0 if 是挑战 else 1, 先清CD)


static func _发挑战(宿主: Node, 号: int, 类型: int, 先清CD: bool) -> void:
	var 后: Node = 宿主.get("_backend") as Node
	if 后 == null:
		return
	if 先清CD:
		后.call("request_arena_clear_and_start", 号, 类型)	# 上行 6
	else:
		后.call("request_arena_challenge", 号, 类型)			# 上行 1


## 清CD 那颗箭头 = `clearTimeHandler:274-289`（只在 CD>0 时可点）⇒ 上行 2。
static func _点清CD(宿主: Node) -> void:
	if 要清CD提示:
		宿主.call("弹出勾选确认", "是否确定使用%d元宝清除CD" % _清CD价(int(计数.get("冷却", 0))),
			func(勾: bool) -> void:
				要清CD提示 = not 勾
				_发清CD(宿主))
		return
	_发清CD(宿主)


static func _发清CD(宿主: Node) -> void:
	var 后: Node = 宿主.get("_backend") as Node
	if 后 != null:
		后.call("request_arena_clear_cooldown")


## 「增加」钮 = `tianJiaHandler:223-235` ⇒ 上行 3。
static func _点加次(宿主: Node) -> void:
	if 要加次提示:
		宿主.call("弹出勾选确认", "是否确定使用%d元宝增加挑战次数" % _加次价(),
			func(勾: bool) -> void:
				要加次提示 = not 勾
				_发加次(宿主))
		return
	_发加次(宿主)


static func _发加次(宿主: Node) -> void:
	var 后: Node = 宿主.get("_backend") as Node
	if 后 != null:
		后.call("request_arena_add_count")


static func _点英雄榜(宿主: Node) -> void:
	## `viewPaiHangHandler:275-278` → `showPvpRankWindow():88-96`：
	## `reverseDisplay` 之后**只有窗已经存在时**才发查询 ⇒ 第一次开只开不查，
	## 由英雄榜那扇自己建好后发（照抄这个顺序，别"顺手"改成先查后开）。
	宿主.call("导航到", "竞技场英雄榜")


static func _装三态(钮: TextureButton, 三张: Array) -> void:
	for 档 in range(3):
		var 路 := String(三张[档])
		if ResourceLoader.exists(路):
			钮.set("texture_%s" % ["normal", "hover", "pressed"][档], load(路))


## ── 对战那三步（`PvpManager.as:230-237` / `:321-325` / `:416-436`）──────────────
## ★ 原版**不是收到某一帧才开始显示倒计时**：`2306:5` 只把秒数存进 `_pvpRemainSeconds`
##   （`onPk_showBattleRemainTime:276-279` 一个字都不画），**换图**那一拍才拿去显示。
##   所以这边同样由 `地图实体._ready` → `进图(图号, 生命)` 驱动。
## 给量具/别的页读 `isPking` 用（静态量直接跨文件点出来容易和属性遮蔽搞混）。
static func 对战中() -> bool:
	return 在对战


static func 进图(图号: int, 根: Node) -> void:
	生命 = 根
	if 图号 == 竞技场图号 and not 在对战:
		在对战 = true
		_开局()
		return
	if 图号 != 竞技场图号 and 在对战:
		在对战 = false
		_收场()


## `onStartPk:230-237` 四步：`closeWindowOnEnterBattle()` → 关竞技场那两扇 → 左侧倒计时 → 藏宠物。
## ⚠ 前两步在这边塌成一条：`窗口管理.全部关闭()` 就是"把所有开着的 `功能窗口` 关掉"，
##   而 `closeWindowOnEnterBattle:4629-4650` 的白名单**全是 HUD 件**（头像/聊天/小地图/任务追踪/
##   连斩/buff 排/获得提示…），一扇 `功能窗口` 都不在里面 ⇒ 不存在"该留却没留"的差。
##   第三步用的就是 `2306:5` 存下来的那份秒数（没收到 ⇒ 0 秒 ⇒ 那一块当场自己藏，与原版一致）。
static func _开局() -> void:
	var 管 := _窗口管理()
	if 管 != null:
		管.call("全部关闭")
	if 是活节点(生命):
		生命.call("显示战场倒计时", 战斗剩余)
		生命.call("显示宠物", false)


## `onEndPk:321-325` = `onExiteBattle()` + `showMyPet(true)`。
## ⚠ `onExiteBattle:4705-4720` 恢复的那几根条（获得提示/心法条/修行条/尾兽来袭）在原版是
##   **被摘掉才需要恢复**，而那几件全在 `closeWindowOnEnterBattle` 的白名单里、根本没被摘 ⇒
##   我们进战斗时也没藏它们 ⇒ 这一档在这边没有对应动作（不是漏，是原版那条本来空转）。
##   另：原版 `showLeftCountDownView:3130` 末尾还喊了一次 `applyTopActivityCollapsedState()`
##   （顶部活动收起那一族），那一族我们没查 ⇒ 记进真值 §未收口。
static func _收场() -> void:
	if 是活节点(生命):
		生命.call("隐藏战场倒计时")
		生命.call("显示宠物", true)


static func 是活节点(节: Node) -> bool:
	return 节 != null and is_instance_valid(节)


static func _窗口管理() -> Node:
	if not 是活节点(生命):
		return null
	return (生命 as Node).get_parent().get_node_or_null("窗口管理") as Node


static func _喊进场钟(根: Node, 文案: String, 秒: int) -> void:
	if 是活节点(根):
		根.call("显示进场钟", 文案, 秒)


## `PVP_PAIMING_PRIZE_TIP`（message 包现查）=
## `<font color='#ffffff'>排名第%1位<br/>本期排名奖励获得<br/></font><font color='#fff000'>%2阅历</font>`
static func 排名奖文案(名次: int, 阅历: int) -> String:
	return "[color=#ffffff]排名第%d位\n本期排名奖励获得[/color]\n[color=#fff000]%d阅历[/color]" % [名次, 阅历]


static func _刷英雄榜() -> void:
	## 榜那扇**开着**才喂（原版 `onPk_showHeroList:327-333` 就是 `if (windowMap[...])` 才 setData）；
	## 没开 ⇒ 数据已经存在 `英雄榜` 这份 static 里，开窗时它自己取。
	## ⚠ 这里用 `load()` 不用 `const preload`：`竞技场英雄榜窗` 反过来 preload 了本脚本，
	##   两边都 preload 就是**静态循环引用**（parse 直接挂）。
	var 脚 = load("res://脚本/界面/窗口/竞技场英雄榜窗.gd")
	if 脚 != null and 脚.页 != null and is_instance_valid(脚.页):
		脚.喂()


## 结算弹层：宿主给 `生命`（地图根）——**不给某一扇窗的 `遮罩`**，
## 因为进战斗那一拍 `onStartPk:232-234` 把所有窗都关了，结算帧是打完之后才来的。
static func _弹出结算(胜: bool, 阅历: int) -> void:
	竞技场结算弹脚本.弹出(生命, 胜, 阅历)


## `管理`（`窗口管理` 那个 CanvasLayer）底下一层整屏浮层，懒建一次。
## 给"不依附任何窗"的弹窗用（排名奖到手 = `FamillyPopUpWindow.popUpWindow` 那一档，
## 原版它也是独立一扇，不是谁的子件）。
## ⚠ 必须**自己带一层 CanvasLayer**、层号取结算弹那一档（400），不能直接当 `管理` 的子 Control：
##   `窗口管理.重排层级:850-853` 给每一扇窗都 `窗.layer = HUD基(110) + 序号` ⇒ 窗自己就是一层
##   CanvasLayer，挂在 管理 默认层上的弹会被**所有窗**盖住（10-24 量具逮到：弹的相对矩形全对、
##   屏上却看不见也点不到）。
static func _全局浮层() -> Control:
	if not 是活节点(管理):
		return null
	if 是活节点(浮层):
		return 浮层
	var 壳 := CanvasLayer.new()
	壳.name = "全局浮层"
	壳.layer = 竞技场结算弹脚本.层号
	管理.add_child(壳)
	var 层 := Control.new()
	层.name = "舞台"
	层.set_anchors_preset(Control.PRESET_FULL_RECT)
	## 这一层挂的是 `FamillyPopUpWindow` 那一族，而它 `popUpWindow` 的第 7 参 `modal` 传的是
	## **false** ⇒ 原版 `centerWindow:74-115` 连遮罩 Sprite 都不加，点击照穿到下面的世界。
	## 这边要是留默认 STOP，整屏就"看着没遮罩却点不动"。
	层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	壳.add_child(层)
	浮层 = 层
	return 层


## = `PvpManager.onPk_challengedReport:369-390` 那三步（逐句转写，顺序不许调）。
## 原版 `_recentReports` 存的是 `CueGird` 实例（要读它 `.data.timeStamp` 与 `.id`）⇒
## 这边存 `{流水号, 时间戳}` 这两份等价信息，别的不改。
static func _塞战报格(条: Dictionary) -> void:
	var 盘 := _托盘()
	if 盘 == null or 条.is_empty():
		return
	var 戳 := int(条.get("timeStamp", 0))
	for 记 in 近期战报:
		if int((记 as Dictionary).get("时间戳", -1)) == 戳:
			return						# `:377-380` 同一条战报不再塞第二格
	while 近期战报.size() > 托盘上限:
		## `:383-387`：`length > 3` ⇒ shift 掉**最旧那一格**（所以屏上最多 4 格，这是原样的数）
		var 旧: Dictionary = 近期战报.pop_front() as Dictionary
		盘.call("删消息", int(旧.get("流水号", -1)))
	var 格 := 盘.call("加消息", 邀请托盘脚本.类型战报, 条) as Control
	if 格 == null:
		return						# 托盘满了/建不出 ⇒ 原版同样没格，不另开提示
	近期战报.append({"流水号": int(格.get("流水号")), "时间戳": 戳})


## 托盘那一格被点 ⇒ `clickGridHandler:81-86`：开 `PvpZhanBaoWindow` + `setZhanBao(那条)`。
static func 战报格被点(条: Dictionary) -> void:
	战报弹脚本.弹出(生命, 战报文本(条, 自己号))


static func _托盘() -> Node:
	if not 是活节点(管理):
		return null
	return 管理.get_node_or_null("邀请托盘") as Node
