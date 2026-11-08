extends Node
## 挂机（智能托管打怪）的**唯一**实现 —— 原版 `com/mxw/game/world/handlers/GuajiHandler.as`
## （1272 行）的逐条移植。挂在 `玩家.tscn` 的玩家节点下，由 `玩家._physics_process` 每物理帧
## 调 `拍(毫秒)`。
##
## ⚠ **不要再往第二处抄这套逻辑**（10-18 之前它散在 `玩家.gd:1402-1450`、
## `地图实体.gd:949-980`、`游戏会话.gd:2658` 三处）：同族状态机实现两遍 ⇒ 变异测试打在
## 其中一份上、另一份照常跑，门看着敏感其实是假敏感。
##
## 逐段出处（左边原版行号，右边本文件小节）：
##   `:54-:64`   四个节流常数               → 常数区
##   `:232-:282` setConfig() 逐字段读        → `重读配置()`
##   `:557-:575` fightArea = 矩形(格×50)     → `重算活动区()`
##   `:577-:965` tick() 主循环               → `拍()`
##   `:1018-:1092` isStart setter（防抖/特效/PVP/还原）→ `置挂机态()`
##   `:1117-:1204` 挑怪谓词 / 距离 / 黑名单   → `可打()` `拉黑()` `黑名单里()`
##   `:1122-:1165` 任务怪优先                → `任务怪号()`
##   `:193-:347` 嗑药（排序 + 大小瓶两档）    → `药品表()` `从大用到小()` `从小用到小()`
##   `:374-:444` 背包满卖装 + 自动升级技能     → `拍背包满卖装()` `拍自动升级()`
##   `:865-:940` 三瓶双倍与五枚辅助续用        → `拍双倍药()` `拍辅助()`
##
## 三条**已知与原版不同**的（如实，别当已还原）：
##   1. `canUseSkill`（`:546-:573`）三道闸我们齐了（已学 / 蓝够 / 精华够，耗量走
##      `数据/技能消耗.json` → `游戏数据.skill_cost`）；**但**原版对 9030~9033、4005~4012
##      那几招有"按 maxMp 百分比 + 等级衰减"的特例（`SkillDataTool.as:393-:414`），
##      我们的消耗表是按等级的定值 ⇒ 那几招的蓝线会比原版宽。
##   2. 跨服大战（`KuaFuManager.isInKuaFuBattle`）在本工程**没有这个状态**（我们只做了鸣人那扇
##      跨服频道窗，没有跨服战场）⇒ 原版那三处触点全部没接：`:1037-:1040` 在跨服战里**开不了挂机**
##      （注意它排在防抖之后 ⇒ 原版连那 1 秒冷却都已经被吃掉）、`:611-:616` 与 `:638-:643`
##      嗑药时把背包那两张表**换成战场内的药**（`KuaFuManager.getHPMPItems`）。
##      真做出跨服战那天，这三处一起接，别只接开挂闸门。
##   3. 原版死亡只走 `ReliveWindow`（1281 死亡框，倒计时到了强制回城复活）；本工程还没有
##      那扇窗 ⇒ 这里只按 `canOriginLive()` 的两条闸自己发上行，窗口另开一任务。
##   4. 『宠物吃』(`autoChongWuEat`) **原版自己就是一条死配置**：全树只有
##      `GuaJiSettingInfoData:16`（出厂 true）→ `CharacterConfig:152/197`（存盘读盘）→
##      `GuajiHandler:279` 赋给 `isPetEat`，而 `isPetEat` **从没被读过** ⇒ 这边同样只读不用。
##      页面上那枚勾照原版摆着，但它不改变任何行为 —— 这不是漏做，是原版本来就没做。

## 原版 `AUTO_SELL_INTERVAL:54` / `AUTO_UPGRADE_SKILL_INTERVAL:56` / `AUTO_START_WARMUP:58`
## / `AUTO_HEAL_TRIGGER_RATIO:60` / `AUTO_PARTY_HEAL_TRIGGER_PERCENT:62` / `WRONG_TARGET_RETRY_TIME:64`
const 卖装间隔毫秒 := 500.0
const 升级间隔毫秒 := 1500.0
const 预热毫秒 := 800.0
const 自己该补血线 := 0.98
const 队友该补血线 := 98
const 错目标重试毫秒 := 1500.0
## 原版 `:560` `var _loc2_:int = 50` ⇒ 活动区宽 = 格×50、高 = 宽的一半。
const 每格像素 := 50.0
## 原版 `canPickItem:1203` 的"够得着"半径。
const 捡取距离 := 90.0
## ── 途中顺捡盒（`GuajiHandler.as:852-853`）──
## `nearPickRect = player.outerBodyRect.clone(); nearPickRect.inflate(90,55);`
## · 身体盒 = `Character.as:80` 那个**固定** `_bodyRect = Rectangle(-27,-95,54,95)`
##   （注册点在脚底：x ∈ [−27,+27]、y ∈ [−95,0]）。**不是逐帧贴图盒** —— 逐帧 lt/rb
##   那一套是 `MonsterSprite.as:259-266` 给**怪**用的，玩家（`Character`）不走那张。
## · ⚠ `flash.geom.Rectangle.inflate(w,h)` = **中心不变、宽 +w、高 +h** ⇒ 每边只加**一半**
##   （横每边 +45、纵每边 +27.5），**不是四边各外扩 90/55** —— 这是最容易算错的一条。
## ⇒ x ∈ 我.x ± (27 + 90/2) = ±72；y 顶 = 我.y − (95 + 55/2) = −122.5；y 底 = 我.y + 55/2 = +27.5
##   ⇒ `Rect2(我.x − 72, 我.y − 122.5, 144, 150)`。
const 身体盒半宽 := 27.0			# `Character.as:80` 宽 54 ⇒ 半宽 27
const 身体盒顶 := -95.0			# 同上：高 95、注册点在脚底 ⇒ 顶 −95、底 0
const 途中外扩横 := 90.0			# `GuajiHandler.as:853` inflate 的**宽增量**（每边一半）
const 途中外扩纵 := 55.0			# 同上高增量（每边一半）
## 原版 `:839` 归位阈值：离起点超过 50 像素才走回去（走的是 `startPoint.y - 30`）。
const 归位距离 := 50.0
## 三瓶双倍的物品号（`:867/:877/:887`）与本地冷却 `cd = 2000`（`:864`）。
const 双倍经验药 := "15002001"
const 双倍查克拉药 := "15002002"
const 双倍宠物药 := "15002003"
const 双倍药冷却毫秒 := 2000.0
## 五枚辅助的**技能号**（`Job0.as:106/108/110/50/52`；全职业共用，Job100~400 不覆盖）：
## 天之咒印=autoBuff1=3002(AddAttack)、地之咒印=autoBuff2=3003(AddDefence)、
## 不离不弃=autoBuff3=3305(couple5)、创造再生=HEAL2=3001(群疗)、掌仙术=HEAL1=3000(单疗)。
## ⚠ `autoBuff3` 的静态初始化顺序在两份反编译里互相矛盾（一份得 3305、一份得 0），
##   按 3305 实现：`SkillExecute.as:209` 有 `couple5` 专用分支，而 0 会被
##   `DataCenter.getSkillLevel(0)` 当成"已学"（`:2231-:2236`），放出去行为不可预期。
const 辅助号 := {"autoWulinEffect": 3002, "autoZhanYiEffect": 3003, "autoShouhu": 3305,
		"autoZaiSheng": 3001, "autoZhangXian": 3000}
## 只有这两招能用 `hasBuffOfSkill` 判（原版走 `SkillDataTool.getSkillBuffType`，
## 表里只认 `add_atk→14` / `add_def→15`，其它一律 -1 ⇒ 查不到就当"没有"，另三枚用冷却判）。
const 有增益判定号 := {3002: true, 3003: true}
## 复活道具与免费线（`ReliveWindow.canOriginLive:140-162` 读的是
## `Etc.json items.revive = {itemid:16000010, autolevel:31}`，服务端同值
## `fake_flash_server.py:11175-11176`）。
const 复活道具号 := "16000010"
const 免费原地复活等级 := 31
const 回村图号 := "100000000"		# 原版 `:709-711` 写死的 100000000

var _会话: Node = null
var _后端: Node = null
var _玩家: Node2D = null
var _实体: Node = null
var _地表: Node = null

## ── 下面每一份状态都对应原版 GuajiHandler 的一个实例字段（改名对照见头注）──
var 在跑 := false					# `_isStart`
var _帧 := 0						# `i`（`:122`，自增后按位取节流）
var _帧累计毫秒 := 0.0			# ★ 只用来把 `i` 钉在原版 60Hz 那一格上，见 `_推帧()`
const 一帧毫秒 := 1000.0 / 60.0	# `Engine.STAGE_FRAME_RATE = 60`：原版 `i++` 就是每 16.67 毫秒一次
var _预热过 := 0.0					# `pastTime2`
var _已发上行 := false					# `_isSendBuff`
var _计时毫秒 := 0.0					# `pastTime`
var _时长毫秒 := 240.0 * 60.0 * 1000.0		# `_totalTime` = 分×60×1000（`:352`）
var _免时长 := false					# `_ignoreBattleTimeLimit`
var _刚清完 := true					# `justComplete`
## ⚠ **必须是 `static`**：原版 `GuajiHandler` 是**单例**，`_IsgoingHome` 活得比一张图长 ——
## 换图时 `clear()` 读的就是"这一趟是不是为回城而传送"。本工程这份挂在玩家节点下、
## 换图就跟着销毁重建，写成实例变量会在离树前丢掉 ⇒ 回城那一趟也会被当成普通换图关掉挂机。
static var _在回城 := false			# `_IsgoingHome`（`:712` 置真、`setConfig:280` 清）

var _起点 := Vector2(INF, INF)			# `startPoint`
var _活动区 := Rect2()				# `_fightArea`
var _黑名单 := {}					# `wrongTargets`（目标 → 到期毫秒）
var _即时黑名单 := {}					# `tempWrongTargets`
var _卖装毫秒 := 0.0					# `_autoSellElapsed`
var _升级毫秒 := 0.0					# `_autoUpgradeSkillElapsed`
var _药冷却 := {}					# `itemCoolMap` 的本地替身（只放这三瓶双倍）
## 缺血药/蓝药提示的"上膛"状态。原版 `UIMain2.as:5903-5907` / `:2496-2502`：
## `showTipNoHPItems()` 只在 `_isShowTipNoHPItems` 为真时飘一句、然后置假；
## `CharactorInfoPane.setHP:606`（蓝药 `setMP:211`）在 `percent > auotReplyHpValue`
## 时重新置真 ⇒ **每当掉到血线以下只提示一次，回到血线以上才重新上膛**。
var _缺血药可提示 := true
var _缺蓝药可提示 := true
var _特效: Node2D = null				# `_guaJiTip`
var 上行记录: Array = []				# 循环自己发过的每一发 1808：`{档, 在线, 发出}`（在线腿的证据口）
## `_上行()` 离线那一支绕回会话时的那一面闸：见 `_上行()` 里 `GuajiHandler.as:696` +
## `Client.as:3471-3477` 那段出处 —— 原版那一句**不回灌 isStart**，这边也不能回灌。
var _自灌中 := false
var _自动升级还原值 = null				# `_previousAutoUpgradeSkill`
var _pvp记 := -1						# `PVPHandler.notePvpMode()` 记的那一档
var _pvp还原毫秒 := 0.0				# 停挂机那句 `setTimeout(resumePvpMode, 300)` 的倒计时
var _防抖剩余 := 0.0					# `_isCding` + `setTimeout(...,1000)`
var 状态文字 := ""						# `status`（原版只有 DEBUG_GUAJI 才画出来，这里留着给门读）
var 目标 = null							# `pathFindTarget`
var _配置缓存: Dictionary = {}


func _ready() -> void:
	_会话 = get_node_or_null("/root/GameSession")
	_后端 = get_node_or_null("/root/BackendConnection")
	_玩家 = get_parent() as Node2D
	if _实体 == null:
		_实体 = _玩家.get_parent().get_node_or_null("LifeRoot")
	if _地表 == null:
		_地表 = _玩家.get_parent().get_node_or_null("Footholds")
	if _会话 != null and not _会话.hang_changed.is_connected(_接挂机态):
		_会话.hang_changed.connect(_接挂机态)
	## 挂着的时候改设置要立即生效（原版是逐字段写单例；本工程走 `挂机配置_changed` 这一发 ——
	## 它在每次 1283 回帧后发，页面保存与登录回读都走那里）。
	if _会话 != null and not _会话.挂机配置_changed.is_connected(_接配置变更):
		_会话.挂机配置_changed.connect(_接配置变更)
	## ⚠ 受击信号在**后端连接**上（`后端连接.gd:194 signal player_damaged`），玩家节点没有这个
	## 信号 —— 原来写成 `_玩家.player_damaged` 会在 `_ready` 里当场吊死整条协程。
	if _后端 != null and not _后端.player_damaged.is_connected(_记打我的那只):
		_后端.player_damaged.connect(_记打我的那只)
	## ── 换图 = 原版 `World.clearMap():893` 那句 `guajiHandler.clear()` ──
	## `clear():286-293` = `if (!_IsgoingHome) isStart = false;` ⇒ **每次换图都把挂机关掉**
	## （那颗"挂机中"球灭、发 1808:1、清目标），只有"到点回城"那一趟传送例外。
	## 10-19 用户就是这句拍板"照原版：换图就停"，原先这里那段
	## `if 会话.hang_state.active and not 在跑: 置挂机态(true)`（挂着换图自动接回）是**自造的**，已撤。
	## 普通换图那一支在**旧实例**的 `_exit_tree()` 里关（那边才拿得到还没归零的 `在跑`）；
	## 这一支只收尾城那一趟 —— 原版单例带着 `isStart=true` 落到村里，再由 `:721-725`
	## 那一句 `requestHealStart()` + `isStart=false` 结掉。
	if _在回城:
		_在回城 = false
		if _会话 != null and str(_会话.current_map_id) == 回村图号:
			开始打坐()						# `:723` requestHealStart()
			在跑 = true						# 单例这时还是 true，先如实接上再走停的那一支
			请求停挂机()						# `:724` isStart = false（发 1808:1、摘特效、清目标）



func _exit_tree() -> void:
	## 原版 `World.clearMap():893` ⇒ `GuajiHandler.clear():286-293`
	## = `if (!_IsgoingHome) isStart = false;` ⇒ **换图就把挂机关掉**（走的是 `isStart` setter
	## 停的那一整支：`_恢复pvp()` + 1808:1 + 摘"挂机中" + `pastTime=0` + 清目标与追击）。
	## 必须排在摘信号**之前** —— `请求停挂机()` 是靠 `hang_changed` 广播回来驱动的，
	## 先把信号摘了这一发就落空（会话那侧 `active` 还留着真，屏幕上那颗球不会灭）。
	if 在跑 and not _在回城:
		请求停挂机()
	if _会话 != null and _会话.hang_changed.is_connected(_接挂机态):
		_会话.hang_changed.disconnect(_接挂机态)
	if _会话 != null and _会话.挂机配置_changed.is_connected(_接配置变更):
		_会话.挂机配置_changed.disconnect(_接配置变更)
	if _后端 != null and _后端.player_damaged.is_connected(_记打我的那只):
		_后端.player_damaged.disconnect(_记打我的那只)
	## 原版那句 `setTimeout(resumePvpMode, 300)` 挂在**全局计时器**上、`PVPHandler` 又是单例
	## ⇒ 换图也照样还原。这边这份挂在玩家节点下、换图就跟着销毁，所以**离树前把没跑完的那
	## 300ms 补掉** —— 不补的话"停完挂机立刻换图"会把 PVP 模式永远留在普通（玩家看得见）。
	if _pvp还原毫秒 > 0.0:
		_pvp还原毫秒 = 0.0
		_真还原pvp()
	## 屏幕层那枚『挂机中』是本模块建的，离树时自己摘掉。
	## 真换图时 HUD 与玩家同一棵旧场景一起销毁，本来不会留；留的是"玩家被单独回收、HUD 还在"
	## 那种走法 —— 不清就会在屏幕上叠出第二枚，而且再也没人管它（原版 `:1083-:1086` 成对 removeChild）。
	if _特效 != null and is_instance_valid(_特效):
		_特效.queue_free()
	_特效 = null


## 原版 `GuajiHandler` 是单例、`isStart` 由 UI 直接置位；本工程用会话的 `hang_changed`
## 当同一个入口（点「开始挂机」发 1808:0 之后由会话广播）。
## ⚠ `_自灌中` 那一闸：这一条广播**也**是本模块自己 `_上行()` 离线那一支发出来的（见那里的
## 注释与出处），自己发的这一发不许再回头驱动 `置挂机态`。
func _接挂机态(状: Dictionary) -> void:
	if _自灌中:
		return
	置挂机态(bool(状.get("active", false)))


## ── isStart setter 的复刻（`:1018-:1092`）：防抖 → 停/开的两套收尾 → 特效 → PVP → setConfig ──
func 置挂机态(要开: bool) -> void:
	## `:1025-:1036` 防抖排在**任何同状态判断之前**：`value && _isCding` ⇒ 直接不吃，
	## 1 秒后才再接受；过了闸就吃掉这一秒（`_isCding = true` + `setTimeout(...,1000)`）。
	if 要开:
		if _防抖剩余 > 0.0:
			return
		_防抖剩余 = 1.0
	if 要开 == 在跑:
		## `:1088-:1091` 原版那句 `if(value) this.setConfig();` 在 `if(_isStart != value)`
		## 那块**外面** —— "已经在挂、又收到 true" 时开/关动作本身被那三道
		## `value != _isStart` 闸跳过，但**配置重跑不许跳**。10-19 按此把整句早退改掉。
		if 要开:
			重读配置()
		return
	## ⚠ **先落值、再动作** —— 原版 `GuajiHandler.set isStart` 就是这个顺序，而开头那句
	## `value != _isStart` 唯一的用处就是挡住"动作里回头再调一次自己"。
	## 上一版把 `在跑 = 要开` 写在 `_上行(1)` **之后** ⇒ 停挂机时 `_上行` → `request_hang(false)`
	## → 广播 `hang_changed` → `_接挂机态` → 又进 `置挂机态(false)`，那时 `在跑` 还是 true，
	## 闸形同虚设 ⇒ **无限递归**（10-18 行为门实测：`Stack overflow` + 进程挂到超时不出结论）。
	在跑 = 要开
	if 要开:
		# 原版 `:1043` `TargetHandler.stopEverything()`（那里面还会回头把 isStart 置 false，
		# 同样靠上面那句 `value != _isStart` 挡重入）。本工程没有那个"全停"总闸，等价动作就是
		# **清掉手上的目标与追击**，免得带着上一轮的目标开始新一轮。
		_清目标与寻路()
		## `TargetHandler.as:504-507`（stopEverything 里）：
		## `if (player.movementAction == MovementAction.SIT0) HealHandler.getInstance().requestHealStop();`
		## ⇒ **坐着点「开始挂机」要先起身**，不然人坐着不动。排在这句的位置是因为原版
		## stopEverything 的顺序就是 `stopPathFind()`(`:503`) 之后判 SIT0(`:504`)。
		## ⚠ **只补在开挂这一支**：停挂机那支走的是 `TargetHandler.clear()`（`:462-469`），
		## 里面**没有**这一句（`GuajiHandler.as:1064` 调的是 clear，不是 stopEverything）。
		停打坐()
		_记pvp并切1()
	else:
		_恢复pvp()
		_上行(1)						# `:1053` `requestHang_stopHang()` = 1808:1
	_摆特效(要开)
	if not 要开:
		_计时毫秒 = 0.0				# `:1061-:1063` pastTime **只在 isStart(false) 清**
		_刚清完 = true
		_还原自动升级闸()
		_清目标与寻路()
	else:
		重读配置()


## 停挂机一律**绕回会话**（它才是 `hang_state` 的主人，界面那颗球、时长计时、
## 挂机窗的钮态都读它）。直接改本地 `在跑` 会造成"人停了、界面还挂着"的假状态，
## 所以这里只发请求，真正的收尾仍由 `置挂机态(false)` 做（它是唯一出口）。
func 请求停挂机() -> void:
	if _会话 != null:
		_会话.request_hang(false)
	elif 在跑:
		置挂机态(false)


## 原版 `setConfig()`（`:232-:282`）：清空黑名单、定锚点、逐字段灌进实例变量。
## ⚠ `:232-:282` 整段里**既不清 `pastTime`(`:692` 只在 tick 累加)也不清 `pastTime2`(`:66`)** ——
## 10-19 按此删掉了这里的 `_预热过 = 0.0` 与 `_计时毫秒 = 0.0` 两句自造清零：
## 预热 800ms 在一个客户端生命周期里只付一次（否则"第二次点开始要多愣 0.8 秒"），
## `pastTime` 只在 `isStart(false)`（`:1061`）清（否则换图/收到配置帧就把到点回城清零，永远走不到点）。
func 重读配置() -> void:
	_黑名单.clear()					# `:235` wrongTargets = new Dictionary()
	_即时黑名单.clear()				# `:236` tempWrongTargets = new Dictionary()
	_拾取在走 = null				# 开挂/换图都是新的一轮，别把上一轮"答应去捡"的那枚带过来
	拾取发过.clear()				# 证据口同样按"这一趟"计，不跨轮累计
	_已发上行 = false				# `:237` _isSendBuff = false
	_刚清完 = true					# `:238` justComplete = true
	## ⚠ 这里**不清** `_帧`（原版 `i`）：`setConfig:232-282` 整段 51 行里既没有 `i = 0`、
	## 也没有 `pastTime`/`pastTime2`/`_toPickItems` —— `i` 只在 `:122` 声明、`tick():607` 只 `++`。
	## 10-19 删掉这一句之前，"收到一发配置帧就把 4/8/16 帧节流重新对齐到 0"是我们自己加的，
	## 症状：嗑药/双倍药/五枚辅助那三档的节奏每来一发 1283 就被打乱一次。
	_卖装毫秒 = 0.0
	_升级毫秒 = 0.0
	_药冷却.clear()
	_在回城 = false					# `:280` _IsgoingHome = false
	_起点 = _脚下点()				# `:239-:246` startPoint 重定到脚下
	重算活动区(整型("autoBattleRange", 20))		# `:247` fightArea 跟着重摆
	_配置缓存 = 读配置快照()
	_摆宠物招式()
	_摆人物招式()
	_免时长 = bool(设("unlimitedAutoBattleTime", false))
	## `set totalTime:350-353` 就一句 `this._totalTime = param1 * 60 * 1000;` —— **没有任何 clamp**。
	## 原来那个 `clampi(..., 0, 500)` 是自造的 ⇒ 10-19 删掉；输入框那侧的上限归输入框，不许挪进 handler。
	_时长毫秒 = float(整型("autoBattleTime", 240)) * 60.0 * 1000.0
	_挂上自动升级闸()


## ── 挂着的时候改了设置 ⇒ **下一拍就用新值**（原版那些勾选是当场写进单例的）──
## 真值：`GuaJiSettingWindow.as` 每一枚勾选都直接调 `API.guajiHandler.percentHP/percentMP = …`、
## `set fightArea:557-575`、`set playerSkill:1206`、`set petSkill:1256` ⇒ 挂着改设置立即生效。
## ⚠ 10-19 更正上一版留在这里的**错注释**（它断言"只有 `isStart` 由假变真才调 `setConfig()`"）：
##   `Client.as:7180-7190 onCharConfig()` 的**结尾**就有一句**无条件**
##   `GuajiHandler.getInstance().setConfig();` ⇒ 每收到一发配置回帧（本工程 = `挂机配置_changed`，
##   每次 1283 回帧后发）都要**整份重跑配置**：清黑名单(`:235-:236`)、把锚点重定到脚下
##   (`:239-:246`)、按新格数重摆活动区(`:247`)。所以 `_接配置变更` 直接走 `重读配置()`，
##   原来那份"什么都不清、只换值"的 `刷新配置()` 整条删除（它比原版少做的正是本轮要补的）。
func _接配置变更(_状: Dictionary) -> void:
	重读配置()					# `Client.as:7190`


## 逐字段读法照抄 `:247-:279`（含两处原版打错的 `auot*` 拼写，一个字母都不能"顺手改对"）。
func 读配置快照() -> Dictionary:
	var 出 := {}
	出["招式"] = 整型("autoSkillId", 0)
	出["宠招"] = 整型("autoChongwuSkillId", -1)
	出["血线"] = float(整型("auotReplyHpValue", 70)) / 100.0
	出["蓝线"] = float(整型("auotReplyMpValue", 50)) / 100.0
	# `:263-:264` 关掉开关 = 0；开 + 档 0 = 1(大瓶优先)；开 + 档≠0 = -1(小瓶优先)
	出["血档"] = 0 if not bool(设("autoReplyHp", true)) else (1 if 整型("auotReplyHpType", 0) == 0 else -1)
	出["蓝档"] = 0 if not bool(设("autoReplyMp", true)) else (1 if 整型("auotReplyMpType", 0) == 0 else -1)
	出["自动升级"] = bool(设("autoUpgradeSkill", false))
	出["双倍经验"] = bool(设("autoUseEpDrug", false))
	出["双倍宠物"] = bool(设("autoUseChongWuEpDrug", false))
	出["双倍查克拉"] = bool(设("autoUseZhenQiDrug", false))
	出["拾取装备"] = bool(设("autoCollect", true))
	出["装备职业"] = 整型("collectProfession", 0) * 100	# `:270`
	出["装备等级"] = 整型("collectLevel", 0)				# `:271`
	出["装备品质"] = 整型("collectQuality", 0)			# `:272`
	出["拾取任务品"] = bool(设("isCollectQuestion", true))
	出["拾取药品"] = bool(设("isCollectDrug", true))
	出["拾取金币"] = bool(设("isCollectMoney", true))
	出["拾取材料"] = bool(设("isCollectCaiLiao", true))
	出["拾取其他"] = bool(设("isCollectOthers", true))
	出["卖装"] = bool(设("autoSellPickedEquip", false))	# `:276`（原版的 `&& vipLevel >= 5` 2026-10-25 随报修 5.1 删）
	出["避首领"] = bool(设("autoAvoidBoss", false))
	出["原地复活"] = bool(设("autoReply", false))
	出["回城打坐"] = bool(设("autoDaZuo", true))
	出["宠物吃"] = bool(设("autoChongWuEat", false))
	for 字段 in 辅助号:
		出[字段] = bool(设(字段, true))		# 出厂五枚全 true（`GuaJiSettingInfoData.as:56-70`）
	return 出


## `fightArea`（`:557-:575`）：**矩形**，宽 = 格×50、高 = 格×25，锚在 `_起点`（不是玩家当前位置）。
## 原版 y 方向只有 x 的一半 ⇒ 斜上方过远的怪就是不追，这是"挂机不乱跑"的全部原因。
func 重算活动区(格数: int) -> void:
	var 宽 := float(格数) * 每格像素
	_活动区 = Rect2(_起点.x - 宽 / 2.0, _起点.y - 宽 / 4.0, 宽, 宽 / 2.0)


## ── 『通灵兽招式』那一枚下拉真正落地的地方 ──────────────────────────────
## 原版链：`setConfig:250` `this.petSkill = autoChongwuSkillId` → setter `:1256-1264`
## （**只在 `_isStart` 为真、且有出战宠物时**才动）→ `ShortcutColumnPane.guaJiSavePetDefaultSkill:426-437`
## → `UI.onShortcutColumnSetPetDefaultSkill:928-936` `myPet.curSkillID = 那一招`。
## 之后宠物出手走 `AttackPetController.fireTo:27-48` → `petFire(curSkillID || 101)`，
## **能不能打由那一招的命中盒决定**（`PetSkill.canReachTarget` + `SkillDataTool.getPetSkillHitRect`）。
## ⚠ 一处已知偏差：原版要先在**宠物快捷栏**里找到 action==那一招 的格子才写（找不到就整条静不做）；
##   本工程还没做宠物那一排（`技能面板` 只有人物那一排）⇒ 这边直接写，等那排做出来要补这道前置。
func _摆宠物招式() -> void:
	var 号 := int(_配置缓存.get("宠招", -1))
	if _实体 == null or not _实体.has_method("宠物伙伴节点"):
		return
	var 伴: Node2D = _实体.call("宠物伙伴节点")
	if 伴 == null or not 伴.has_method("摆招式"):
		return					# 没出战宠物 ⇒ 原版那条 `Boolean(myPet)` 同样直接 return
	伴.call("摆招式", 号)


## 人物那一枚下拉选中的招 = 原版 **`TargetHandler.defaultSkill`**（`Client.as:7193
## setDefaultSkill(autoSkillId,false)`、`GuajiHandler.set playerSkill:1206-1213`），
## 每帧出手读的就是它（`SkillExecute.moveToAttack():62`）。本工程对应 `会话.默认忍术`。
## ⚠ 它是**全局那一枚选中忍术**，不是挂机私有：原版就是会把它一起改掉（技能栏的选中框跟着动），
## 停挂机也不还原（`set isStart(false)` 只 `TargetHandler.clear()`，不动 `defaultSkill`）。
func _摆人物招式() -> void:
	if _会话 == null or not _会话.has_method("设默认忍术"):
		return
	_会话.call("设默认忍术", int(_配置缓存.get("招式", 0)))


## `:239-:246`：落地就用当前点；没落地就取**脚下那一段**的落点。
func _脚下点() -> Vector2:
	if _玩家 == null:
		return Vector2(INF, INF)
	var 脚: Vector2 = _玩家.get("position") as Vector2
	if bool(_玩家.get("on_ground")):
		return 脚
	if _地表 != null and _地表.has_method("find_foothold"):
		var 中: Dictionary = _地表.call("find_foothold", 脚.x, 脚.y, "")
		if not 中.is_empty():
			return Vector2(脚.x, float(中.get("y", 脚.y)))
	return 脚


## 主循环。`毫秒` = 本次物理帧的时长（原版 tick 收的是毫秒步进）。
## ★ **把原版的 `i++` 折算成时间，不是"每物理拍 +1"**（2026-10-23）。
## 原版 `GuajiHandler.tick():607` 的 `++this.i` 是**舞台帧**计数（`Engine.STAGE_FRAME_RATE = 60`），
## 所以下面 `(_帧 & 3)`（`:609` 吃药）、`& 7`（`:865` 双倍药/战旗/宠物经验）、`& 15` 这些节流点
## 在原版里等于**真实时间** 66.7 / 133.3 / 266.7 毫秒。本工程允许"逻辑节拍跟显示器刷新率"
## （`脚本/调试/镜头节拍记录.gd`，为了治镜头抖），节拍一旦不是 60，按拍自增就会把这些间隔
## 一起改短（100Hz ⇒ 吃药检查 66.7→40 毫秒）。这里按毫秒累计、攒够一帧的量才 +1，
## **60Hz 下与原来逐拍自增完全等价**（`拍()` 每物理拍带 16.67 毫秒进来），其他节拍也守住原语义。
## 同一口径的先例：`脚本/角色/怪物AI.gd:42` 的 `const 帧 := 1.0/60.0` + `_剩余帧 -= delta / 帧`。
func _推帧(毫秒: float) -> void:
	_帧累计毫秒 += 毫秒
	## 上限 4：卡帧/切后台补回来的那些拍不许把 `_帧` 一次推过十几个节流点。
	var 补 := 0
	while _帧累计毫秒 >= 一帧毫秒 and 补 < 4:
		_帧累计毫秒 -= 一帧毫秒
		_帧 += 1
		补 += 1
	if _帧累计毫秒 >= 一帧毫秒:
		_帧累计毫秒 = 0.0


func 拍(毫秒: float) -> void:
	if _玩家 == null or _会话 == null:
		return
	## 拾取队列先吞一枚（原版那条 ENTER_FRAME 独立于本函数的一切早退：预热中、没在挂、
	## 按着移动键、死了 —— 都照样把已经点名的掉落排空）。
	_吞一枚拾取()
	_防抖剩余 = maxf(_防抖剩余 - 毫秒, 0.0)
	## 停挂机那句 `setTimeout(API.pvpHandler.resumePvpMode, 300)`（`:1052`）：**人已经不在挂了
	## 也要把这一拍走完**，所以倒计时必须放在下面 `if not 在跑: return` 之前。
	if _pvp还原毫秒 > 0.0:
		_pvp还原毫秒 = maxf(_pvp还原毫秒 - 毫秒, 0.0)
		if _pvp还原毫秒 == 0.0:
			_真还原pvp()
	走冷却(毫秒)
	## 原版 `resize():1094-1101` 把"挂机中"重摆到水平中线是挂在舞台尺寸事件上的；
	## 本工程没有那个事件 ⇒ 挂着期间每一拍核对一次（只有真偏了才写，代价是一次比较）。
	if 在跑:
		_摆特效位()
	# `:602-:606` 前 800ms 整段不吃（刚点开挂机那一刻先别动）
	if _预热过 < 预热毫秒:
		_预热过 += 毫秒
		return
	_推帧(毫秒)
	var 死了: bool = _血量() <= 0.0
	# `CharactorInfoPane.as:606` / `:211`：血/蓝回到设定线以上就重新上膛缺药提示。
	# 提示本身是一次性消费（`UIMain2.as:5903-5907`），所以掉线那一阵只飘一句，不刷屏。
	var 血线 := float(_配置缓存.get("血线", 0.7))
	var 蓝线 := float(_配置缓存.get("蓝线", 0.5))
	if _血量() / maxf(1.0, _最大血()) > 血线:
		_缺血药可提示 = true
	if _蓝量() / maxf(1.0, _最大蓝()) > 蓝线:
		_缺蓝药可提示 = true
	# `:609-:633` 吃药：每 4 帧一档，HP/MP 各判一次
	if (_帧 & 3) == 0 and not 死了 and int(_配置缓存.get("血档", 0)) != 0 \
			and _血量() / maxf(1.0, _最大血()) < 血线:
		_嗑一种(药品表(true), int(_配置缓存["血档"]), true)
	if (_帧 & 3) == 0 and not 死了 and int(_配置缓存.get("蓝档", 0)) != 0 \
			and _蓝量() / maxf(1.0, _最大蓝()) < 蓝线 and not _在漏蓝():
		_嗑一种(药品表(false), int(_配置缓存["蓝档"]), false)
	if not 在跑:
		return
	# `:665-669` 玩家一按移动/跳跃键，立刻交还控制权
	if _按着移动键():
		请求停挂机()
		return
	# `:670-691` 死亡那一支
	if 死了:
		处理死亡()
		return
	_计时毫秒 += 毫秒
	# `:693-697` 1808:0 只在**第一拍**发一次，不是每帧发
	if not _已发上行:
		_已发上行 = true
		_上行(0)
	拍自动升级(毫秒)
	拍背包满卖装(毫秒)
	# `:700-:727` 时长到点：不勾回城打坐就停；勾了要传回村、到村开始打坐、再停
	if not _免时长 and _计时毫秒 > _时长毫秒:
		走时长到点()
		return
	拾取或打怪(死了)
	# `:848-:863` 寻路途中每 4 帧顺手把身边 90×55 盒里的可捡物捡掉
	## ⚠ 这一支的"在寻路"必须问**有没有活动路线**（`click_move_active`），不能问 `自动寻路中`：
	##   后者是屏幕上那行「自动寻路中」提示的开关，只有小地图/任务那种 `走向(..., 自动=true)`
	##   才点得亮，而挂机自己发的 `走向(落点, true, false)` 是 `自动=false` ⇒ 拿它当条件时
	##   **这一支在挂机全程一次都没跑过**（10-19 在线腿实测：服务端掉了 5 枚、挂机 0 次发拾取，
	##   只有掉落生成那一帧的旧快捷路径捡走 1 枚 ⇒ 用户看到的"拾取之后东西还在地面上"）。
	##   原版那一句的条件就是 `player.isPathFinding()`（有路线），与提示无关。
	if (_帧 & 3) == 0 and _在走路线() and 会去捡():
		for 掉 in _实体.call("挂机的掉落", _途中盒()):
			if 该不该捡(掉) == 捡得动:
				var 顺手号 := int((掉 as Dictionary).get("object_id", 0))
				排队拾取(顺手号)				# 同上：排队，不在这一拍直接发
				拾取发过.append(顺手号)
	拍双倍药()
	拍辅助()


## `:729-:847` 的空闲大块：**不在寻路、没在追击、站着/打坐/爬梯/爬绳** 才会挑目标。
func 拾取或打怪(死了: bool) -> void:
	## 原版 `toAttackAnemy` 不是一面自己举着的旗，是 `SkillExecute.moveToAttack()` **每一拍**
	## 按"这只还打得/还追得到"重算的（`:122-170`：死了、`canAttack` 假、寻路失败 ⇒ 落回 false）。
	## 本工程那面旗对成玩家手里的 `自动接近目标`，所以每一拍要跟它对一次表 ——
	## 不对的话会**永远卡在第一只**（10-18 在线腿实测：目标早已不在，5836 帧不换位、零死亡）。
	if _追击 and not _还在追():
		_追击 = false
		if _玩家.has_method("停止追打"):
			_玩家.call("停止追打")
		目标 = null
	if _在赶路线() or _追击 or not _在待机动():
		return
	## 走过去捡那一枚：**路走完了还够不着 ⇒ 拉黑它**（用户 2026-10-19 实机报 bug2「开始挂机时
	## 自动拾取会卡住角色不动」的根因）。原来只有 `走向()` 返回**假**才拉黑，于是"路找到了、
	## 但只能走到它隔壁平台/正下方"这种永远差 90 像素的情况会**每拍重发同一条寻路** ——
	## 拾取排在打怪前面并且 `return` ⇒ 角色钉在原地、既不打怪也不归位。
	## 追打那一支早就有同一条纪律（`追打失败()` 由 `玩家._维持接近路线` 回灌），拾取这一支原来漏了。
	if _拾取在走 != null:
		var 现 = _掉落还在(_拾取在走)
		if 现 == null:
			_拾取在走 = null						# 已经捡走 / 被服务端收了
		elif _离那枚(现) < 捡取距离:
			_拾取在走 = null						# 到位了：下一拍 `该不该捡` 会给"捡得动"并发拾取帧
		else:
			拉黑(_拾取在走)							# 与原版 `signWrong:1247-1254` 同一档：1.5 秒内不再试
			_拾取在走 = null
	# `:735-:748`：开局那一刻人还在空中（跳/落下）⇒ `startPoint` 是空的，
		# 等到**落地的那一拍**才把锚点定下来，活动区整块跟着搬过去。
	if _起点.x == INF and bool(_玩家.get("on_ground")):
		_起点 = _玩家.get("position") as Vector2
		重算活动区(整型("autoBattleRange", 20))
	# ① 拾取这一支优先
	var 挑中 = null
	var 待走: Array = []
	if 会去捡():
		for 掉 in _实体.call("挂机的掉落", _活动区):
			var 分 := 该不该捡(掉)
			if 分 == 不该要:
				continue
			if 分 == 捡得动:
				var 捡号 := int((掉 as Dictionary).get("object_id", 0))
				排队拾取(捡号)				# 不当场发帧：原版是排队，每帧吞一枚
				拾取发过.append(捡号)
			else:
				待走.append(掉)
		挑中 = 最近的一枚(待走)		# `getNearestDropItem:1229-1245`：纯取最近，**不移除、不判画面**
		if 挑中 != null and 黑名单里(_目标键(挑中)):
			挑中 = null
	if 挑中 != null:
		状态文字 = "拾取"
		停打坐()
		var 落点: Vector2 = Vector2(float((挑中 as Dictionary).get("x", 0)), float((挑中 as Dictionary).get("y", 0)) - 5.0)
		目标 = 挑中
		if bool(_玩家.call("走向", 落点, true, false)):
			_拾取在走 = _目标键(挑中)		# 答应走过去 ⇒ 走完那一拍要验收"到底够得着没有"
		else:
			拉黑(_目标键(挑中))			# `:784-:791` 寻路失败 ⇒ 1.5 秒内不再试这一枚
		return
	# ② 被打的那只优先。⚠ 原版 `:796-:797` 这一支用的谓词是 **`canAttack`，不是 `toAttackMonster`**
	#   ⇒ 没有黑名单、也没有"避首领"那两档：咬我的那只就算是首领、就算刚被我拉黑过，也先还手。
	#   上一版这里写成 `可打()`（两份合并的那一份）⇒ 拉黑期内被打，会**不还手**地挨着打。
	var 打我的 = _打我的那只()
	if 打我的 != null and 能攻(打我的):
		挑中 = 打我的
	else:
		打我的 = null
	if 挑中 == null:
		var 怪群: Array = _实体.call("挂机的同层怪", _层号(), _活动区)
		怪群 = _任务怪优先(怪群)
		while not 怪群.is_empty():
			var 候 = 最近活物(怪群)			# 画面外的候选在这里被剔出队列，取走的那枚也被移除
			if 候 == null:
				break
			if 去攻这只(候):
				挑中 = 候
				break
		if 挑中 == null:
			# `:813-:822` 同层没有 ⇒ 放宽到全部怪，仍限在活动区矩形内。
			# ⚠ 原版 `:813-:814` 是**两句连着**：`monsters = toArray(monsters)` 之后紧跟
			# `monsters = this.preferActiveQuestMonsters(monsters);` ⇒ 第二趟同样先过任务怪优先，
			# 这里复用第一趟那个函数（`_任务怪优先` = `:1122-:1165`），**不写第二份实现**。
			var 全: Array = _实体.call("挂机的全部怪")
			全 = _任务怪优先(全)			# `GuajiHandler.as:814`
			while true:
				var 候 = _区内最近(全)		# 取走即从堆里移除（AS3 是 `splice` 在函数里做的）
				if 候 == null:
					break
				if not _同层(候):
					continue				# 放宽也不能跨层：本工程走向会爬梯，原版这段没有这一跳
				if 去攻这只(候):
					挑中 = 候
					break
	if 挑中 != null:
		目标 = 挑中
		状态文字 = "打怪物"
		_追击 = true
		摆看住的目标(挑中)
		放招()
		return
	状态文字 = "没有怪物"
	# `:838-:844` 没怪 ⇒ 离起点超过 50 就走回去（落点在起点上方 30）
	if _起点.x != INF and (_玩家.get("position") as Vector2).distance_to(_起点) > 归位距离:
		状态文字 += " 归位"
		_玩家.call("走向", Vector2(_起点.x, _起点.y - 30.0), true, false)
	目标 = _起点


## ── 停挂机的三条之一：死亡（`:670-:691`）──
## 原版只在 `ReliveWindow` 已经开着的时候动；本工程那扇窗还没移植 ⇒
## 这里按 `canOriginLive()` 的两条闸自己判（背包有 16000010 **或** 等级 < 31）。
func 处理死亡() -> void:
	追击(false)
	if not bool(_配置缓存.get("原地复活", false)):
		请求停挂机()					# `:687-:689` 没勾 ⇒ 停
		return
	if 能原地复活():
		if _后端 != null and _后端.has_method("request_revive"):
			_后端.call("request_revive", 1, int(复活道具号))	# 1281 的 IN_PLACE + itemId
		# 服务端复活要时间：这一拍起 `_在回城=false`、`_帧` 不动 ⇒ 复活帧到了自己就继续挂
	else:
		请求停挂机()					# `:676-:679` 窗在但按钮点不动 ⇒ 直接停


func 能原地复活() -> bool:
	if _会话 == null:
		return false
	if int(_会话.player_stats.get("level", 0)) < 免费原地复活等级:
		return true					# `:157-:159` stats.level < autolevel
	for 件 in _会话.inventory:
		if str((件 as Dictionary).get("id", "")) == 复活道具号 \
				and int((件 as Dictionary).get("quantity", 0)) > 0:
			return true					# `:143` isBagExistItem(itemid)
	return false


## ── 停挂机的三条之二：时长到点（`:700-:727`）──
## ⚠ 10-19 按 `:707-:725` 原文重排：原版是**先**跑 `justComplete` 那一块（传送+`curTarget=null`+
## `justComplete=false`），**然后独立地**再判"已在村 ⇒ requestHealStart + isStart=false"。
## 上一版把"已在村 ⇒ 打坐+停"提到最前面并 `return` ⇒ 村子里那一支既不 `清看住的目标`
## 也不把 `justComplete` 置回 ⇒ 蓝色箭头钉在最后那只怪身上、到点检查每拍重跑。
func 走时长到点() -> void:
	if not bool(_配置缓存.get("回城打坐", false)):
		请求停挂机()					# `:702-:705` 没勾回城打坐 ⇒ 直接停
		return
	# `:707` 只有站着/走着的空档才动这一支；`justComplete` 保证整个过程只清一次
	if _刚清完 and int(_玩家.get("_同步动作")) in [3, 1]:
		# `:709-717` 内层：不在村才传送；已在村这块什么都不做（但下面两句照跑）
		if str(_会话.current_map_id) != 回村图号:
			_摆特效(false)					# `:713-:716` 回城路上收掉那颗"挂机中"
			_会话.request_map_change(回村图号, "")	# `:711` MovePlayerToMap(100000000)
			_在回城 = true					# `:712` _IsgoingHome = true
		# `:718` 这两句在 Map 判定的 `if` **外面** —— 已在村也一样要清目标、置回 justComplete
		if _实体 != null and _实体.has_method("清看住的目标"):
			_实体.call("清看住的目标")
		_刚清完 = false					# `:719`
	# `:721-:725` **独立**的第二块：已在村 ⇒ requestHealStart() + isStart = false
	if str(_会话.current_map_id) == 回村图号:
		开始打坐()						# `:723` requestHealStart()
		请求停挂机()						# `:724` isStart = false


## ── 停挂机的三条之三：按着移动/跳跃键（`:665-669` + `KeyController.isDownMoveKey:483-486`）──
## 原版是 **5 枚键**：左/右/上/下/跳（跳跃默认空格），全是"此刻按住"。
func _按着移动键() -> bool:
	if _会话 != null and _会话.has_method("键盘被文本占用") and bool(_会话.call("键盘被文本占用")):
		return false
	for 键 in ["ui_left", "ui_right", "ui_up", "ui_down", "jump"]:
		if InputMap.has_action(键) and Input.is_action_pressed(键):
			return true
	return false


## ── 嗑药族（`:193-:347` + `:1267-:1268`）：号段筛 + 只卡等级 + 按回量升序 ──
## 原版 `ItemFactory.getHPItems()` 用的是 `ItemType` 的**号段**（id 左补零到 8 位取前两位，
## 3=血药、4=蓝药），不是 `hp_restore` 字段 —— 所以 `15004001 生命灵药` 那种
## 也有回血量的**不在这张表里**，挂机不会自动嗑它。照号段来才算还原。
func 药品表(要血药: bool) -> Array:
	var 要类 := 类回血 if 要血药 else 类回蓝
	var 出: Array = []
	for 件 in _会话.inventory:
		## ⚠ **号段判定必须走 `_类型()`**（补零到 8 位再取前两位，同一份 `ItemType.getTypeFromId`
		## 口径）：服务端文本帧的 id 是 int（`_encode_item_payload` 的 `str(item.item_id)`）
		## ⇒ `03000001 拉面（小）` 到客户端是 `"3000001"`，按原样 `begins_with("03")` 永远
		## 不成立 ⇒ 背包里明明有拉面也判"没有可吃的血药"，每 4 帧刷一条系统消息
		## （2026-10-31 用户报）。
		var 号 := str((件 as Dictionary).get("id", ""))
		if _类型(号) != 要类:
			continue
		var 定: Dictionary = _会话.GAME_DATA.item(号)
		if 定.is_empty():
			continue
		if int(定.get("required_level", 0)) > int(_会话.player_stats.get("level", 0)):
			continue			# `ConsumeData.isFitMe:70-78` 覆盖版**只卡等级、不看职业**
		var 回量 := float(定.get("hp_restore" if 要血药 else "mp_restore", 0))
		if 回量 <= 0.0:
			continue
		出.append({"id": 号, "回量": 回量})
	出.sort_custom(func(a, b): return float(a["回量"]) < float(b["回量"]))	# `:995-:1015` 升序
	return 出


## `:621-:629`：档 > 0 从**尾**开始（回量最大优先），档 < 0 从**头**开始（回量最小优先）。
## ⚠ 原版是"第一个适合自己的就收手"——`useItemFromBig/Little` 命中即 `break`，
## **即使在冷却里也 break**（那一拍什么都不嗑，下一拍再试），不是"跳过这瓶试下一瓶"。
## 写成跳过会更聪明，但就不是原版了（`_嗑一种` 这条将来被问"为什么血线到了没嗑"时要能对上）。
func _嗑一种(表: Array, 档: int, 是血药: bool) -> void:
	if 表.is_empty():
		## `:631` / `:657` 调 `showTipNoHPItems()` / `showTipNoMPItems()`；
		## 原版那两句由 `UIMain2.as:5903-5907` / `:2496-2502` 的 `_isShowTipNoHPItems`
		## 一次性消费（飘一句就置假），回到血线以上再由 `CharactorInfoPane.as:606` / `:211`
		## 重新上膛 ⇒ 掉线那一阵只提醒一次，不每 4 帧刷屏（2026-10-31 用户报）。
		if 是血药:
			if _缺血药可提示:
				_缺血药可提示 = false
				_会话.notification_requested.emit("没有可吃的血药")
		elif _缺蓝药可提示:
			_缺蓝药可提示 = false
			_会话.notification_requested.emit("没有可吃的查克拉药")
		return
	var 序: Array = 表.duplicate()
	if 档 > 0:
		序.reverse()
	var 首个: Dictionary = 序[0]
	var 号 := str(首个.get("id", ""))
	if _药在冷却(号):
		return
	_会话.use_inventory_item(号)


## 三瓶双倍（`:865-:894`）：每 8 帧一次，已有该 buff 不嗑、2 秒本地冷却。
func 拍双倍药() -> void:
	if (_帧 & 7) != 0:
		return
	_嗑双倍(bool(_配置缓存.get("双倍经验", false)), 双倍经验药)
	_嗑双倍(bool(_配置缓存.get("双倍查克拉", false)), 双倍查克拉药)
	_嗑双倍(bool(_配置缓存.get("双倍宠物", false)), 双倍宠物药)


func _嗑双倍(开着: bool, 号: String) -> void:
	if not 开着:
		return
	var 有 := false
	for 项 in _会话.hud_state.get("effects", []):
		if str((项 as Dictionary).get("item_id", "")) == 号 \
				and float((项 as Dictionary).get("remaining_seconds", 0.0)) > 0.0:
			有 = true
	if 有 or _药在冷却(号):
		return
	for 件 in _会话.inventory:
		if str((件 as Dictionary).get("id", "")) == 号:
			if _会话.use_inventory_item(号):
				_药冷却[号] = 双倍药冷却毫秒
			break


## 五枚辅助续用（`:895-:940`）：每 16 帧一档；1/2/3 各自判"有增益/在冷却"，
## 4(群疗) 要"自己或队友血量 < 98%"，5(单疗) 只在"自己血量 < 98% 且 4 这拍没放"时才放。
func 拍辅助() -> void:
	if (_帧 & 15) != 0:
		return
	for 字段 in ["autoWulinEffect", "autoZhanYiEffect", "autoShouhu"]:
		if not bool(_配置缓存.get(字段, false)):
			continue
		var 号: int = int(辅助号[字段])
		## ⚠ **原版三档不是同一条判据**（`GuajiHandler.as:896-:923`）：
		##   buff1 `:898` = `!hasBuffOfSkill(id) && canUseSkill(id)` —— **不查冷却**
		##   buff2 `:906` = 同上 —— **不查冷却**
		##   buff3 `:914` = `!isCooling(id) && canUseSkill(id)` —— **不查有没有增益**
		## 上一版对三档统一 `_在冷却() → continue` ⇒ 增益图标刚掉、本地冷却表还在转那一段，
		## 原版立刻补上咒印、我们干等着。判定按原文分开。
		if 字段 == "autoShouhu":
			if _在冷却(号) or not 能施放(号):
				continue
		elif 有该招增益(号) or not 能施放(号):
			continue
		放某一招(号)
		记冷却(号, 技能冷却毫秒(号))
	# `:919-:923` 这两档判定也只在 `i & 0xF` 那一拍算
	var 该自补 := _自己缺血()
	var 该群补 := 该自补 or _有残血队友()
	var 放了群 := false
	if bool(_配置缓存.get("autoZaiSheng", false)) and 该群补:
		var 群: int = int(辅助号["autoZaiSheng"])
		if not _在冷却(群) and 能施放(群):
			放某一招(群)
			记冷却(群, 技能冷却毫秒(群))
			放了群 = true
	if 放了群:
		return
	if bool(_配置缓存.get("autoZhangXian", false)) and 该自补:
		var 单: int = int(辅助号["autoZhangXian"])
		if not _在冷却(单) and 能施放(单):
			放某一招(单)
			记冷却(单, 技能冷却毫秒(单))


## `playerNeedsHealing()`（`:1167-:1176`）：血>0、没满、且 血/上限 < 0.98。
func _自己缺血() -> bool:
	var 上限 := _最大血()
	var 血 := _血量()
	if 上限 <= 0.0 or 血 <= 0.0 or 血 >= 上限:
		return false
	return 血 / 上限 < 自己该补血线


## `hasInjuredPartyMember()`（`:1178-:1194`）：同队里血量百分比在 (0, 98) 的算一个。
func _有残血队友() -> bool:
	if _后端 == null:
		return false
	## ⚠ 这条链上有量具把 `_后端` 换成没有 `authoritative_party` 这一键的假节点，
	## 而 `Node.get("缺键")` 回的是 **null** ⇒ 直接绑给 `Dictionary` 类型的局部变量
	## 会当场 `SCRIPT ERROR: Trying to assign value of type 'Nil' to a variable of type 'Dictionary'`，
	## 把整条协程打死（本工程栽过好几次：崩掉的只是被 `await` 的那个函数，调用方照样跑完、
	## 末行照样打"通过" ⇒ 静默零覆盖）。所以先按 Variant 取、类型不对就当没有队友。
	var 队: Variant = _后端.get("authoritative_party")
	if not (队 is Dictionary):
		return false
	var 我的号 := int(_后端.get("character_id"))
	for 员 in ((队 as Dictionary).get("members", []) as Array):

		var 号 := int((员 as Dictionary).get("character_id", 0))
		if 号 == 我的号:
			continue
		var 血 := int((员 as Dictionary).get("hp", -1))
		var 上限 := int((员 as Dictionary).get("max_hp", 0))
		if 上限 > 0 and 血 > 0 and 血 * 100.0 / float(上限) < float(队友该补血线):
			return true
	return false


## ── 自动升级技能（`:402-:433`）：每 1500ms 找**第一条**够条件的升一级 ──
## 原版三条件：`masterLevel >= getSkillReqBreath` 且 人物等级 >= `getSkillReqLevel`
## 且 精华 >= `getSkillReqCoins`；另外 `:360-:372` 开挂机时打开总闸、`:435-:444` 停时要
## **还原成开之前的值**（这条最容易漏：还原错了就是"关了挂机还在自己升技能"）。
func 拍自动升级(毫秒: float) -> void:
	if not 在跑 or not bool(_配置缓存.get("自动升级", false)):
		_升级毫秒 = 0.0
		return
	_升级毫秒 += 毫秒
	if _升级毫秒 < 升级间隔毫秒:
		return
	_升级毫秒 = 0.0
	var 属: Dictionary = _会话.player_stats
	for 技 in _会话.learned_skills:
		var 号 := int(str((技 as Dictionary).get("id", "0")))
		var 等 := int((技 as Dictionary).get("level", 0))
		var 熟 := int((技 as Dictionary).get("master_level", (技 as Dictionary).get("mastery", 0)))
		var 满 := int((技 as Dictionary).get("max_level", 20))
		if 号 == 0 or 等 <= 0 or 等 >= 满:
			continue
		var 需: Array = _会话.GAME_DATA.skill_upgrade_req(等 + 1, 号)
		if 需.size() < 3:
			continue
		# ⚠ 三档口径按**本工程已有的消费者**（`忍术窗口.gd:120/132`、服务端 `:50825-:50832`）：
		# `[0]=需人物等级`、`[1]=需金币`、`[2]=需精华**总量**` ⇒ 比较的是"还差多少精华"，
		# 即 `zq >= 总量 - 熟练`。原版 `GuajiHandler:426` 写的是 `masterLevel >= getSkillReqBreath(...)`，
		# 与本工程的表口径不能逐字对齐（这点在真值文档里记成"存疑"，不硬套）。
		var 还差精华 := maxi(0, int(需[2]) - 熟)
		if 熟 < int(需[2]) and int(属.get("level", 0)) >= int(需[0]) \
				and int(属.get("gold", 0)) >= int(需[1]) and int(属.get("zq", 0)) >= 还差精华:
			_会话.upgrade_skill(str(号))
			return


## ── 背包满才卖装备（`:374-:400`）：500ms 累计 + 三个前置（在挂、勾了卖、也勾了捡装备）──
func 拍背包满卖装(毫秒: float) -> void:
	if not 在跑 or not bool(_配置缓存.get("卖装", false)) or not bool(_配置缓存.get("拾取装备", false)):
		_卖装毫秒 = 0.0
		return
	if not _背包满():
		_卖装毫秒 = 0.0
		return
	_卖装毫秒 += 毫秒
	if _卖装毫秒 < 卖装间隔毫秒:
		return
	_卖装毫秒 = 0.0
	for 件 in _会话.inventory:
		if 该卖这件(件):
			# 原版 `requestNpcShopSellAllNormalEquips(APTITUDE_GREEN=3, 0)` —— 按绿档全卖。
			# ⚠ 第二参**格数必须与服务端同一把尺子**（10-19 按用户口径改）：原来传的是
			# `_会话.格容量`（常量 96，`游戏会话.gd:2764` 自己注明它是"原版
			# `DataCenter.as:1147-1149 getEmptySlots → getEmptySlotsInList(commonItems, commonSlots)`
			# 在 `commonSlots<=0` 时的**回退值**"），而 `request_npc_shop_one_key_sell` 那头按它
			# 逐格扫 —— 本机服务端真实容量是 **90**（`背包总格数()`：服务端权威值 →
			# `player_stats.common_slots` → 回退 96，同族判据 `_有空槽/_背包满`（本文件
			# `:1573-:1583` 旧警告）早就用它）。96 会多扫出 6 个**不存在的格子** ⇒ 第二把尺子。
			# 同族不许留两份口径。
			_后端.call("request_npc_shop_one_key_sell", 1, _会话.背包总格数(), 3)
			# 原版本句是 `API.waiGuaHandler.onPackFull()`（`GuajiHandler.as:775`），
			# `WaiGuaHandler.as:324-342` 做**两件事**：① 上面这句卖装；
			# ② `API.ui.content.removeMessageTipPane2(MessageTipPane2.TYPE_BAG_FULL)`（`:336`，
			#   把"背包已满"那条提示条收掉）。**第②件本工程整条缺失**：提示条本体
			#   `脚本/界面/提示条面板.gd` 只接了任务两档（11/12），TYPE_BAG_FULL(=3) 那一档
			#   **没有任何生产者**（工程里"背包已满"全走 `notification_requested` 聊天通知，
			#   不是 MessageTipPane2 条）⇒ 这里没有现成收口可复用，也**不自造新 UI**。
			#   ⇒ 记为"缺一个消费者/生产者"，裁决见 10-19 报告。
			return


## `shouldAutoSellPickedEquip()`（`:524-:555`）六条，一条不多一条不少。
## 号段 `itemId/10000 ∈ [100,119] ∪ [200,209]`、排除 121/205、品质 < 紫(4)、
## 未强化、未镶嵌、`position > 0`（在背包里而不是身上）。
func 该卖这件(件: Dictionary) -> bool:
	var 号 := str(件.get("id", ""))
	if not 号.is_valid_int():
		return false
	var 段 := int(号) / 10000
	if not ((段 >= 100 and 段 <= 119) or (段 >= 200 and 段 <= 209)):
		return false
	if 段 == 121 or 段 == 205:
		return false
	if int(件.get("aptitude", 1)) >= 4:			# APTITUDE_PURPLE = 4（`CocoEquip.as:16`）
		return false
	if int(件.get("strengthen", 0)) > 0:
		return false
	var 镶 = 件.get("inlay_list", 件.get("inlayList", null))
	if 镶 is Array and (镶 as Array).size() > 0:
		return false
	return int(件.get("equip_position", 件.get("position", 0))) > 0


## ── 挑怪谓词：**逐句转写**，函数边界/条件顺序都按 AS3，不合并 ──────────
## 原版这里本来就是**两个函数**：`SkillHandler.canAttack:443-474`（这只本身打不打得）
## 与 `GuajiHandler.toAttackMonster:1117-1120`（挂机这一轮要不要去攻它）。
## 上一版我抄成一份 `可打()`，结果"哪条属于 canAttack、哪条属于挑怪"糊在一起，
## `outOfStage` 那条就这么整条漏了（⇒ 屏幕外的怪也去追）。

## `SkillHandler.canAttack(怪, 忽略暗视=true):443-474`，四条按原顺序：
## · `:447-450` `spawnInfo.attackedByMob` 真 ⇒ false（这只已经咬上别人，玩家打不了）
## · `:451-454` `!怪 || outOfStage(怪,false)` ⇒ false（**身体盒与舞台矩形不相交=屏幕外**）
## · `:455-458` `if (param1 is Monster && !(param1 as Monster).isPetMonster)` 才进
##   `_loc3_ = Boolean(param1["outerBodyRect"]) && !(param1 as Monster).isDie` ——
##   **宠物怪（别人放的通灵兽）不进这一支**，Character/Flag 两支对怪也不成立 ⇒ `_loc3_` 保持
##   初值 false ⇒ `canAttack` 为假 ⇒ 永远打不了。10-19 补上这一闸：以前没有它，
##   `挂机的同层怪/挂机的全部怪`（`地图实体.gd:265-289`）按 `kind=="m"` 收，别人放的通灵兽
##   也在候选里 ⇒ 挂机要去咬别人的宠物。`is_pet_monster` 的出处见 `地图实体._configure_actor`
##   （原版语义 `Monster.as:1652` `_isPetMonster = mobData.info.petLink > 0`）。
## （`:459-468` 那两支判的是**人**（isDead / 暗视 / PVP），`:469-472` 判 Flag ⇒
##   挂机的候选只有怪（`挂机的同层怪`/`挂机的全部怪` 都只收 `kind=="m"`），那两支在这里恒不进，
##   照 AS3 留注释、不另写一份。）
func 能攻(怪) -> bool:
	if 怪 == null or not is_instance_valid(怪):
		return false
	if bool(怪.get_meta("attacked_by_mob", false)):
		return false
	if not _在画面内(怪):
		return false
	## `SkillHandler.as:455` 的 `!isPetMonster`：宠物怪**不进**取 `_loc3_` 的那一支 ⇒ 恒 false。
	if bool(怪.get_meta("is_pet_monster", false)):
		return false
	return _怪物体型盒(怪) != Rect2() and bool(怪.get("alive"))


## `GuajiHandler.toAttackMonster:1117-1120` 五个条件按原顺序与：
## `mobInfo != null` 查的是**这一类怪**的静态定义（`数据/怪物.json`），查不到就不算一只怪。
func 去攻这只(怪) -> bool:
	if 怪 == null:
		return false
	if _怪物定义(怪).is_empty():
		return false
	if not bool(怪.get("alive")):
		return false
	if 黑名单里(_目标键(怪)):
		return false
	if bool(_配置缓存.get("避首领", false)):
		## 原版这一支是**两个条件并列**：`mobInfo.boss == 0 && !isJingYing`（`:1119`）。
		## 后一个是**这一只实例**身上的精英词缀（`Monster.isJingYing:1122-1125` = `jingyings` 非空），
		## 不是图鉴里的静态档 ⇒ 只查 `boss` 字段会漏掉"普通怪 roll 成精英"那一只。
		var 精: Variant = 怪.get("精英属性")
		if 怪档(怪) != 0 or (精 is Array and not (精 as Array).is_empty()):
			return false
	return 能攻(怪)


## 旧名字留成别名（行为门与调用点一大把），但**判定只有一份**，别再往 `可打` 里塞新条件。
func 可打(怪) -> bool:
	return 去攻这只(怪)


func _怪物定义(怪) -> Dictionary:
	if 怪 == null or _会话 == null:
		return {}
	return _会话.GAME_DATA.monster(str(怪.get("entity_id")))


## 原版"只打屏幕上看得见的那只"有两条并列的闸，量的其实是同一件事：
## · `SkillHandler.canAttack:451` → `DisplayUtil.outOfStage(怪,false)`（`DisplayUtil.as:152-185`）：
##   把怪的身体盒换算到**舞台坐标**，与 `Rectangle(0,0,STAGE_WIDTH,STAGE_HEIGHT)` **不相交就算在舞台外**；
##   怪没挂在 stage 上时（`param2=false` 那一支，`:172-181`）改用它在 ALayer 容器里的坐标自己拼一个点。
## · `CommonAttack.getNearestLifeObj:51-54`：`!inLayerNow` 的候选**当场从队列里 splice 掉**，
##   而 `inLayerNow` 是 `ALayerManager` 挂/摘显示层时写的（`ALayerManager.as:73/102/114`）⇒ 同一回事。
## 本工程以前两条都没有：活动区宽 = `格数 × 50`（出厂 20 格 = **1000 像素**）比视口（960×560）还宽，
## 镜头又有 256 像素死区不居中 ⇒ **镜头外那圈怪会被当成目标** ⇒ 人朝着看不见的怪走、
## 走到墙根/梯子边上一脸"莫名其妙"。 ⇒ 用引擎自己的 `canvas_transform` 现算屏幕位，别写死视口尺寸。

## 舞台矩形本身（原版 `DisplayUtil.as:170` 与 `:181` 的
## `new Rectangle(0,0,Config.STAGE_WIDTH,Config.STAGE_HEIGHT)`）。
## · `Config.as:176-178` 出厂 960×560；
## · `Game.as:76-95 onResizeHand` 运行期按 `stage.stageWidth/stageHeight` 重写，**并夹下限**：
##   `:88-91` 宽 < `STAGE_MIN_WIDTH=600` ⇒ 补成 600；`:92-95` 高 < `STAGE_MIN_HEIGHT=400` ⇒ 补成 400。
##   ⇒ **原版这把尺最短就是 600×400，窗口再小也不会跟着缩**。
## · 夹上限那两支（`:80-87`）在原文里是**死码**：`:78-79` 刚把 `stageWidth/Height` 赋进
##   `STAGE_WIDTH/HEIGHT`，紧接着比 `stage.stageWidth > Config.STAGE_WIDTH` 恒假
##   ⇒ `STAGE_MAX_*`（2000×1200）从没生效过 ⇒ 照原文搬，**不在这里"顺手修好"**。
## ⚠ 10-20 那 6 条红的根子就在这一句：门禁 `--headless` 下 Window 只有 **64×64**
##   （实测 `get_visible_rect().size = (64.0, 64.0)`、`canvas_transform` 平移 (-220,-46)、
##   玩家自己落在屏幕 (32,160)），拿裸视口当舞台 ⇒ **连玩家自己都算舞台外** ⇒ `能攻` 恒假
##   ⇒ `_冲选中目标` 开头那一闸天天走 `_放掉追击`（掐路线 + 放掉目标），
##   于是"点怪走过去打"排不出任何路线、自动追发 0 发。
func _舞台矩形() -> Rect2:
	var 面: Viewport = _玩家.get_viewport()
	if 面 == null:
		return Rect2(Vector2.ZERO, Vector2(600.0, 400.0))	# `Config.as:184-186` 的下限档
	var 尺: Vector2 = 面.get_visible_rect().size
	## `Game.as:88-95`：只夹下限，夹上限那两支原文是死码 ⇒ 不搬。
	return Rect2(Vector2.ZERO, Vector2(maxf(尺.x, 600.0), maxf(尺.y, 400.0)))


func _在画面内(怪) -> bool:
	var 盒 := _怪物体型盒(怪)
	var 面: Viewport = _玩家.get_viewport()
	if 面 == null:
		return true						# 量具里没有视口 ⇒ 这一条不判，别把目标清空
	if 盒 == Rect2():
		## 原版 `DisplayUtil.as:161-169`：`if (param1.width > 0) _loc6_ = getRect(stage);`
		## **else `_loc5_ = localToGlobal(0,0); _loc6_ = new Rectangle(_loc5_.x, _loc5_.y, 2, 2);`**
		## ⇒ "这一帧没有墨迹盒"在原版里退化成**它原点处一枚 2×2 的点盒**，**不等于"在舞台外"**。
		## "这只压根没有 `outerBodyRect` 所以打不了"是另一条闸，由
		## `SkillHandler.canAttack:455-458` 的 `_loc3_ = Boolean(param1["outerBodyRect"]) && !isDie`
		## 判（就在下面 `能攻` 的最后一行），不许在这里替它判掉。
		盒 = Rect2((怪 as Node2D).global_position, Vector2(2.0, 2.0))
	var 画: Transform2D = _玩家.get_canvas_transform()
	## ⚠ Godot 4 的 Transform2D **没有 `xform()`**（写错=整份脚本 parse 失败，
	## 连带 `玩家.gd` 挂不上托管 ⇒ 门只判到 2 条就散场）；换算点用乘号。
	var 左上: Vector2 = 画 * 盒.position
	var 右下: Vector2 = 画 * 盒.end
	return _舞台矩形().intersects(
			Rect2(minf(左上.x, 右下.x), minf(左上.y, 右下.y),
					absf(右下.x - 左上.x), absf(右下.y - 左上.y)))


## 三档编号走 `数据/怪物.json` 的 `boss` 字段（0 普通 / 1 首领 / 2 精英）。
## ⚠ 不能用 `地图实体._is_boss()`：那是"名字里含 BOSS/首领"的启发式（`:243-247`）。
## ⚠ 这一档也**代替不了** `isJingYing`：静态 `boss` 说的是"这类怪是不是首领"，
##   精英词缀是服务端**每一只**roll 出来的（`fake_flash_server._configure_monster_variant:16609-16622`
##   → `_monster_spawn_payload:17663-17667` 的第 19 段），两样在原版里是并列的两个条件。
func 怪档(怪) -> int:
	if _会话 == null:
		return 0
	var 定: Dictionary = _会话.GAME_DATA.monster(str(怪.get("entity_id")))
	return int(定.get("boss", 0))


## ── 任务怪优先（`:1122-:1165`）：进行中任务里"还没杀够"的怪号，命中就只在这堆里挑 ──
func 任务怪号() -> Dictionary:
	var 出 := {}
	if _会话 == null or not _会话.has_method("get_accepted_quests"):
		return 出
	var 本图 := int(str(_会话.current_map_id))
	var 定表: Dictionary = _会话.GAME_DATA.取表("任务")
	for 条 in _会话.get_accepted_quests():
		var 信: Dictionary = 条 as Dictionary
		if int(信.get("flash_status", 0)) != 1:
			continue					# 只要"进行中"（2 = 可交付）
		for 进 in (信.get("目标进度", []) as Array):
			var 项: Dictionary = 进 as Dictionary
			if str(项.get("kind", "")) != "mob":
				continue
			if int(项.get("curr", 0)) >= int(项.get("count", 1)):
				continue					# 已经杀够了就别再优先
			var 怪号 := int(str(项.get("key", "0")))
			if not _在本图(定表, int(str(信.get("id", "0"))), 怪号, 本图):
				continue
			出[怪号] = true
	return 出


## 原版判 `int(_loc4_.map) == 0 || == 当前图` —— 0 = 不限图。
func _在本图(定表: Dictionary, 任务号: int, 怪号: int, 本图: int) -> bool:
	var 条: Dictionary = 定表.get(str(任务号), {})
	if 条.is_empty():
		return true						# 查不到定义就按"不限图"放行，别把候选清空
	var 检 = 条.get("check", {})
	var 阶段: Dictionary = 检.get("1", 检.get("0", {})) if 检 is Dictionary else {}
	## AMF 的 `mob` 到工程里是**字典**（`{"0": {id,map,count}, …}`，72 个任务全是），
	## 以前按 `as Array` 取 ⇒ 每次调用都抛 Invalid cast、函数当场退出，
	## 任务怪优先整条静默失效。两种形状都收，别再把字典判死。
	var 怪列 = 阶段.get("mob", [])
	for 项 in (怪列.values() if 怪列 is Dictionary else 怪列):
		var 行: Dictionary = 项 as Dictionary
		if int(行.get("id", -1)) != 怪号:
			continue
		var 图 := int(行.get("map", 0))
		if 图 == 0 or 图 == 本图:
			return true
	return false


func _任务怪优先(怪群: Array) -> Array:
	var 号表 := 任务怪号()
	if 号表.is_empty():
		return 怪群
	var 出: Array = []
	for 怪 in 怪群:
		if 号表.has(int(str(怪.get("entity_id")))):
			出.append(怪)
	return 出 if not 出.is_empty() else 怪群	# `:1164` 一个都没命中就退回整堆


## ── 该不该捡（`:456-:522`）：6 类分开 + 装备三档 + 要空槽；金币不要空槽 ──
const 不该要 := 0
const 捡得动 := 1
const 要过去 := 2


func 会去捡() -> bool:
	## 原版 `toExecutePickLogic():355-358`：总开关 `_isPick`（本工程没有这个运行时开关，
	## 默认视为开）与**六枚勾里任意一枚**成对，缺一个都不去捡。
	if _实体 == null or not _实体.has_method("挂机的掉落"):
		return false
	var 设 := _配置缓存
	return bool(设.get("拾取装备", false)) or bool(设.get("拾取其他", false)) \
			or bool(设.get("拾取材料", false)) or bool(设.get("拾取金币", false)) \
			or bool(设.get("拾取任务品", false)) or bool(设.get("拾取药品", false))


## 那枚掉落还在不在地上（被捡走/被服务端收掉就查不到）。**全图矩形**查，不受活动区限制：
## 这一条只回答"它还在不在、离我多远"，"要不要去捡"仍由 `会去捡()` + `该不该捡()` 说了算。
func _掉落还在(号) -> Variant:
	if _实体 == null or not _实体.has_method("挂机的掉落"):
		return null
	for 掉 in _实体.call("挂机的掉落", Rect2(-1000000.0, -1000000.0, 2000000.0, 2000000.0)):
		if int((掉 as Dictionary).get("object_id", 0)) == int(号):
			return 掉
	return null


## 角色到那枚掉落的**锚点(脚底)距离** —— 与 `该不该捡()` 里同一个量、同一条算法
## （原版 `canPickItem:1201-1204` 量的就是两点欧氏距离，90 像素）。
func _离那枚(掉: Dictionary) -> float:
	var 我位: Vector2 = _玩家.get("global_position") as Vector2
	return 我位.distance_to(Vector2(float(掉.get("x", 0)), float(掉.get("y", 0))))


func 该不该捡(掉: Dictionary) -> int:
	var 号 := str(掉.get("item_id", ""))
	if not _归属对(掉):
		return 不该要
	var 判定 := _该捡哪一类(号, 掉)
	if 判定 == 不该要:
		return 不该要
	if not _有空槽() and not bool(掉.get("is_meso", false)):
		return 不该要			# `:478/489/497/513`：非金币都要求有空格
	## 距离只许用 `_离那枚()` 这一个量：原版 `canPickItem:1201-1204` 量的就是"脚位到那枚"
	## 的欧氏距离，而这一版以前这里读 `position`、到位验收 `_拾取在走` 读 `global_position`
	## ⇒ 同一枚掉落被两把尺子量，一旦玩家父层带偏移，两者对不上 → 永远判"要走过去"、
	## 走完又永远判"还没够着" → 拉黑 → 循环。现在两边同一条算式。
	return 捡得动 if _离那枚(掉) < 捡取距离 else 要过去


## `toPickItem()` 的分类判定（`:456-:520`）。**类型 = 物品号补零到 8 位之后的前两位**
## （`ItemType.getTypeFromId:139-142` = `parseInt(lpad(id,8).substr(0,2))`），
## 类型表在 `ItemType.as`：1 玩家装备 / 2 宠物装备 / 3 回HP / 4 回MP / 5 火力 /
## 10 任务物品 / 11 礼包 / 12 材料 / 13 宝石 / 90 金币。
## ⚠ 上一版按"11/12/13 开头 = 装备、02 开头 = 材料"分，**恰好把 礼包/材料/宝石 当成装备、
## 把真装备（01/02 开头）当成材料** ⇒ 页面上那三枚"装备职业/等级/品质"下拉对真装备一条都不生效。
const 类玩家装备 := 1
const 类宠物装备 := 2
const 类回血 := 3
const 类回蓝 := 4
const 类火力 := 5
const 类任务品 := 10
const 类材料 := 12


## 原版 `getTypeFromId`：不足 8 位**左补零**再取前两位（服务端下发的是 int，如 `2010060`）。
static func _类型(号: String) -> int:
	var 补 := 号.strip_edges()
	if 补.is_empty() or not 补.is_valid_int():
		return -1
	while 补.length() < 8:
		补 = "0" + 补
	return int(补.substr(0, 2))


func _该捡哪一类(号: String, 掉: Dictionary) -> int:
	var 类 := _类型(号)
	## ⚠ **空号 / 认不出的号不许当场毙掉**：金币掉落那一条 `itemid` 就是空的，
	## 原版靠 `param1.isMeso`（`:501`）接住它 —— 类型算不出来（−1）时继续往下走，
	## 最后落到"其他"那一支（`:515-519`），与原版 `getTypeFromId(0)=0` 的走法一致。
	if 类 == 类玩家装备 or 类 == 类宠物装备:
		if not bool(_配置缓存.get("拾取装备", false)):
			return 不该要				# `isPickEqp` ← `autoCollect`（`setConfig:269`，那枚"拾取"总勾）
		var 定: Dictionary = _会话.GAME_DATA.item(号)
		if 定.is_empty():
			return 不该要				# `:462-465` `createSingleItem()` 造不出来就放过
		## `reqJob` 直接读物品表那条的 `required_job`（本工程 `数据/物品.json` 有这一列；
		## 原先调的 `装备元数据()` **在 GameData 里根本不存在**，`has_method` 挡掉之后
		## 这一档永远是 0 ⇒ "装备职业"那枚下拉白摆，属于静默零覆盖）。
		var 需职 := int(定.get("required_job", 0))
		var 档职业 := int(_配置缓存.get("装备职业", 0))
		if 档职业 != 0 and 需职 != 0 and 需职 != 档职业:
			return 不该要				# `:469-:471`
		if int(_配置缓存.get("装备等级", 0)) != 0 and int(定.get("required_level", 0)) < int(_配置缓存["装备等级"]):
			return 不该要				# `:473-:475`
		if int(_配置缓存.get("装备品质", 0)) != 0 and int(掉.get("aptitude", 0)) < int(_配置缓存["装备品质"]):
			return 不该要				# `:477-:480`（品质就在 272 帧第 5 段，服务端一直有发）
		return 要过去
	if 类 == 类任务品:
		return 要过去 if bool(_配置缓存.get("拾取任务品", false)) else 不该要	# `:487-:492`
	if 类 == 类回血 or 类 == 类回蓝 or 类 == 类火力:
		return 要过去 if bool(_配置缓存.get("拾取药品", false)) else 不该要	# `:493-:500`
	if bool(掉.get("is_meso", false)):
		return 要过去 if bool(_配置缓存.get("拾取金币", false)) else 不该要	# `:501-:507`（金币**不要空槽**）
	if 类 == 类材料:
		return 要过去 if bool(_配置缓存.get("拾取材料", false)) else 不该要	# `:508-:514`
	return 要过去 if bool(_配置缓存.get("拾取其他", false)) else 不该要		# `:515-:519` 兜底


## `canItemPickup:478-486` 归属那一支：无主(0) / 自己的 / 同队的。
func _归属对(掉: Dictionary) -> bool:
	var 归属 := int(掉.get("owner_id", 0))
	if 归属 == 0:
		return true
	var 我的 := int(_后端.get("character_id")) if _后端 != null else 0
	if 归属 == 我的:
		return true
	for 号 in _队友号():
		if 归属 == 号:
			return true
	return false


func _队友号() -> Array:
	var 出: Array = []
	if _后端 == null:
		return 出
	var 队: Dictionary = _后端.get("authoritative_party")
	for 员 in (队.get("members", []) as Array):
		出.append(int((员 as Dictionary).get("character_id", 0)))
	return 出


## ── 黑名单（`:967-:993` + `:1247-:1254`）：1.5 秒内不再试同一个目标 ──
func 拉黑(键) -> void:
	if 键 == null:
		return
	_黑名单[键] = Time.get_ticks_msec() + 错目标重试毫秒


## 原版 `SkillExecute.moveToAttack():133-141`：追这只怪却**寻不出路**（`pathFind(...) != 1`）
## ⇒ `guajiHandler.signWrong(怪)` + `toAttackAnemy = false`，这一只 1.5 秒内不再试、下一拍换目标。
## 调用方是 `玩家._维持接近路线`（本工程 `moveToAttack` 那一支的落点），它拿不到返回值时不会走到这里。
func 追打失败(怪) -> void:
	拉黑(_目标键(怪))
	if 怪 == 目标:
		_追击 = false
		目标 = null
		if _实体 != null and _实体.has_method("清看住的目标"):
			_实体.call("清看住的目标")


func 黑名单里(键) -> bool:
	if 键 == null:
		return true					# `:969-:972` 空目标算"错目标"
	if _即时黑名单.has(键):
		return true
	if not _黑名单.has(键):
		return false
	var 到 := float(_黑名单[键])
	if Time.get_ticks_msec() >= 到:
		_黑名单.erase(键)			# `:987-:990` 过期即摘，不做全表清扫
		return false
	return true


func _目标键(项) -> Variant:
	if 项 is Dictionary:
		return int((项 as Dictionary).get("object_id", 0))
	if 项 is Node:
		## ⚠ 编号只有**在线那一路**才填（`战斗角色.gd:455 configure_authoritative`），
		## 离线烘焙出来的怪 `object_id` 恒为出厂的 0（`战斗角色.gd:8`）⇒ 直接拿它当键就是
		## **全图所有怪共用一个键**：拉黑一只 = 拉黑全部，挂机从此只会"没有怪物 归位"
		## （10-19 行为门 午⑥ 的夹具自检抓到的，单机模式用户天天用）。
		## 原版 `wrongTargets[param1]` 用的是**对象引用**（`isWrong:967-993`）⇒ 等价物 = 实例号。
		var 号 := int((项 as Node).get("object_id"))
		if 号 != 0:
			return 号
		return (项 as Object).get_instance_id()
	return null


## ── 选最近：**原版是三个函数、三种语义，不能并成一个**（并起来就又出"哪条属于哪个"的糊涂账）──
## 三处量的都是**锚点(脚底)**之间的欧氏距离（`GeomUtil.getDistance:46-49`）。

## `CommonAttack.getNearestLifeObj:34-73`（挑怪第一趟用）：
## · `:51-54` 遍历途中把 `!inLayerNow`（当前没挂进显示层容器 `ALayerManager`）的候选**当场 splice 掉**
##   —— 本工程没有那套"按镜头挂/摘显示层"的容器，等价判据就是同一只怪在不在画面里（`_在画面内`）；
## · `:68-71` 返回最近那一枚的同时 `splice` 把它移出队列 ⇒ 调用方 while 循环天然不会重复挑它。
func 最近活物(堆: Array):
	var 出 = null
	var 出位 := -1
	var 最近 := INF
	var 我: Vector2 = _玩家.get("global_position") as Vector2	# ⚠ 与另一头 `_点_of`/怪的 `global_position` **必须同一把尺**（原版 `GeomUtil.getDistance:46-49` 两边取的是同一坐标系）
	var 位 := 0
	while 位 < 堆.size():
		var 项 = 堆[位]
		if not _在画面内(项):
			堆.remove_at(位)				# 原版 `param1.splice(_loc6_--,1)`
			continue
		var 距 := 我.distance_to(_点_of(项))
		if 距 < 最近:
			最近 = 距
			出 = 项
			出位 = 位
		位 += 1
	if 出位 >= 0:
		堆.remove_at(出位)
	return 出


## `GuajiHandler.getNearestDropItem:1229-1245`（走过去捡那一枚用）：纯取最近，
## **既不移除、也不判画面/相交**（候选是上一步已经在活动区里筛出来的）。
func 最近的一枚(堆: Array):
	var 出 = null
	var 最近 := INF
	var 我: Vector2 = _玩家.get("global_position") as Vector2	# ⚠ 与另一头 `_点_of`/怪的 `global_position` **必须同一把尺**（原版 `GeomUtil.getDistance:46-49` 两边取的是同一坐标系）
	for 项 in 堆:
		var 距 := 我.distance_to(_点_of(项))
		if 距 < 最近:
			最近 = 距
			出 = 项
	return 出


## `CommonAttack.getNearestMonsterInArea:76-113`（放宽那一趟用）：只收"外框与活动区**相交**"的，
## 按离玩家最近取，并且 `:110-112` **splice 掉返回的那一枚**；这一趟**不判画面**（与上面那支不同）。
func _区内最近(堆: Array):
	var 出 = null
	var 出位 := -1
	var 最近 := INF
	var 我: Vector2 = _玩家.get("global_position") as Vector2	# ⚠ 与另一头 `_点_of`/怪的 `global_position` **必须同一把尺**（原版 `GeomUtil.getDistance:46-49` 两边取的是同一坐标系）
	var 位 := 0
	for 怪 in 堆:
		var 盒 := _怪物体型盒(怪)
		if 盒 != Rect2() and 盒.intersects(_活动区):
			var 距 := 我.distance_to(怪.get("global_position") as Vector2)
			if 距 < 最近:
				最近 = 距
				出 = 怪
				出位 = 位
		位 += 1
	if 出位 >= 0:
		堆.remove_at(出位)
	return 出


func _点_of(项) -> Vector2:
	if 项 is Dictionary:
		return Vector2(float((项 as Dictionary).get("x", 0)), float((项 as Dictionary).get("y", 0)))
	return (项 as Node2D).global_position


func _怪物体型盒(怪) -> Rect2:
	if _实体 != null and _实体.has_method("怪物体型盒"):
		return _实体.call("怪物体型盒", 怪)
	return Rect2()


## ── 施放 ──
## 原版 `checkAndFire(defaultSkill, true)` 的第二参 = "只登记目标/开追击，别在这里盲开火"
## （`SkillExecute.as:371-:379`）。本工程没有那套追击循环，所以**直接放那一招**，
## 但保留原版的三道闸：已学、蓝够、冷却好（精华那一档我们表里没有字段，见头注①）。
## 原版 `:1107` `SkillExecute.checkAndFire(targetHandler.defaultSkill, true)`：**这一句不打人**，
## 它只是把"打这只"交给目标系统（`toAttackAnemy = true` + `curTarget = 这只`）。
## 真出手在**每帧**的 `moveToAttack():122-158`：够得着 ⇒ 转身 + `fireSkill(defaultSkill)`；
## 够不着 ⇒ `pathFind(怪.x, 怪.y−5)` 走过去；寻路失败 ⇒ `signWrong(怪)`（1.5 秒拉黑）+ 放掉目标。
## ⚠ 上一版写成"挑中那一刻自己放一发"，而 `_追击` 又把上面那块整段挡死 ⇒
## **一轮挂机只出手一次**（10-18 在线腿实测：90 秒、5836 帧、服务端零死亡）。
## 本工程 `moveToAttack` 的那一份早就落在 `玩家._冲选中目标`（#194），这里只负责把目标交给它。
func 放招() -> void:
	if _玩家.has_method("开始自动接近"):
		_玩家.call("开始自动接近", 目标)


## "还在追这一只吗"——对的就是原版 `toAttackAnemy` 那一面旗。
func _还在追() -> bool:
	if 目标 == null or not is_instance_valid(目标):
		return false
	if not _同层(目标):						# 目标换了层 ⇒ 立刻放掉，别跟着爬梯
		return false
	if not 能攻(目标):						# 死了 / 屏幕外 / 变成打不得的档
		return false
	return _玩家.get("自动接近目标") == 目标


## `AbstractAttackSkill.canUseSkill:546-:573` 三闸：**已学(等级>0) + 蓝够 + 精华够**，
## **不判冷却**（冷却在 `hitTest:602` 与 GuajiHandler 自己那边判）。
## 耗量走 `数据/技能消耗.json` → `游戏数据.skill_cost(id, 等级)`，返回 `{mp, zq}`。
## 原版 `AbstractAttackSkill.canUseSkill:546-573` 全工程**只有一份**，落在 `玩家._这一招放得出`
## （`SkillExecute.moveToAttack` 那一支也要用同一条）。上一版这里另写了一份，而且**多加了一道
## 原版没有的闸**："这一招必须先放在快捷栏某一格"（`_号在哪个槽`）。原版三关只查 等级/蓝/精华，
## 与快捷栏无关 ⇒ 症状是"没把天之咒印拖到快捷栏的玩家，原版挂着会自动上咒印、我们一发都不上"。
func 能施放(号: int) -> bool:
	return bool(_玩家.call("_这一招放得出", str(号)))



func _号在哪个槽(号: int) -> int:
	for 格 in _会话.skill_slots.size():
		if int(str((_会话.get_skill_in_slot(格) as Dictionary).get("id", "0"))) == 号:
			return 格
	return -1


func 放某一招(号: int) -> void:
	var 槽 := _号在哪个槽(号)
	if 槽 >= 0:
		_玩家.call("use_skill_slot", 槽)


## `hasBuffOfSkill`（`:1357-:1361`）：只有加攻/加防两技有 buff 类型映射，其余回 false。
func 有该招增益(号: int) -> bool:
	if not 有增益判定号.has(号):
		return false
	for 项 in _会话.hud_state.get("buffs", []):
		if int((项 as Dictionary).get("skill_id", 0)) == 号:
			return true
	return false


func 技能冷却毫秒(号: int) -> float:
	var 定: Dictionary = _会话.GAME_DATA.skill(str(号))
	return maxf(1.0, float(定.get("cooldown", 1.0)) * 1000.0)


## 冷却表：原版是 `skillCoolMap`/`itemCoolMap` 两份、由 tick 递减（`:217-:257`），
## 这里并成一份"号 → 剩余毫秒"，键用 String 以免技能号与物品号互相顶。
func 记冷却(号, 毫秒: float) -> void:
	_冷却[str(号)] = 毫秒


func _在冷却(号) -> bool:
	return float(_冷却.get(str(号), 0.0)) > 0.0


func _药在冷却(号: String) -> bool:
	return float(_药冷却.get(号, 0.0)) > 0.0


var _冷却 := {}


func 走冷却(毫秒: float) -> void:
	for 键 in _冷却.keys():
		var 剩: float = float(_冷却[键]) - 毫秒
		if 剩 <= 0.0:
			_冷却.erase(键)
		else:
			_冷却[键] = 剩
	for 键 in _药冷却.keys():
		var 剩: float = float(_药冷却[键]) - 毫秒
		if 剩 <= 0.0:
			_药冷却.erase(键)
		else:
			_药冷却[键] = 剩


## ── 对外：让玩家知道该往哪走（原版的"追击"由 TargetHandler 驱动，这里给同一份判断）──
var _追击 := false
## 已经答应"走过去捡"的那一枚掉落的编号（`pathFindTarget` 的拾取版）。
## 只为一条判据服务：**走完这条路还够不着 ⇒ 拉黑它**，见 `拾取或打怪()` 开头那段。
var _拾取在走 = null
## 这一趟**点名要捡**的掉落编号（含被 `LifeRoot` 的 200ms 节流/5 秒单枚锁挡掉、实际没发出去的那些）。
## 只为一条在线判据服务：「说要捡的那些枚，最后必须从地面上消失」——用户 10-19 报的
## "挂机自动拾取之后物品竟然还在地面上"就是它。它是**证据口**，不参与任何决策。
var 拾取发过: Array = []


## ── 挂机的拾取队列（原版 `pickDropItem():1219-1227` + `onEnterFrame():1103-1115`）──
## 原版**不当场发帧**：`pickDropItem` 只把那枚 push 进 `_toPickItems` 并注册一个 ENTER_FRAME，
## 由那个监听器**每一帧吞一枚**发出去，而且每吞一枚立刻 `refreshPickTime()`
## （`DropItemHandler.as:94-97`：把全局 `pickitemTimeLimit` 归 0）⇒ 一堆掉落是按**每秒约 60 枚**
## 在清。上一版这里没有队列：同一拍把所有够得着的挨个 `发拾取`，结果被那份 200ms 节流
## 挡成**除第一枚之外全部不发** ⇒ 实际每秒约 5 枚，用户看到的"一地的东西清得很慢"就是它。
var 拾取队列: Array = []


func 排队拾取(号: int) -> void:
	if not 拾取队列.has(号):
		拾取队列.append(号)


## 队列每一拍吞一枚（原版绑在 ENTER_FRAME 上，与 `i` 的 4/8/16 帧节流**无关**，
## 所以这一条要放在 `_帧 += 1` 之前、也不看 `在跑`）。
## 两句照抄 `onEnterFrame():1110-1111`：**吞 → 走节流的 pickDropItem → 紧接着 refreshPickTime**。
## （上一版这里传 `false` 绕开节流，那不等于原版的"吞完再归零"：原版要是这一枚撞上别人
##   刚点下的 200ms，这一枚**当场作废**，工程照发 ⇒ 会把手动按 Z 抢掉。）
func _吞一枚拾取() -> void:
	if 拾取队列.is_empty() or _实体 == null or not _实体.has_method("发拾取"):
		return
	var 号 := int(拾取队列.pop_front())
	_实体.call("发拾取", 号)
	_实体.call("刷新拾取时间")


func 追击(要: bool) -> void:
	_追击 = 要


## ⚠ **这里原来有一支自造的 `移动方向()`**（"横向 72 以内算进位、纵向差 100 不追，否则给 ±1
## 让调用方 `cancel_auto_path()` 再按方向键走"）—— 原版 `GuajiHandler` 里**没有任何一句**
## "朝目标 x 直接走"，靠近一律 `pathFind`（`:143`、`:784`、`:842`、`SkillExecute.moveToAttack:133`），
## 那两个常数 72/100 在 AS3 里也不存在。10-19 按「移植不是重做」整支删掉：
## 挂机发的每一条靠近都走 `走向()` ⇒ 由 `玩家._走点击路线()` 执行真寻路，
## 于是"走过去捡那一枚"和"没怪了归位"这两条才第一次真的有人执行（以前挂机在跑时
## `_走点击路线()` 一次都不被调用，路线发出去却没人走 ⇒ 人原地不动）。
## 挂在绳上不被掐路线那一档，由 `_在赶路线()`（原版 `isGPathFinding`）在调用方之外守住。


## 原版 `Character.isGPathFinding():1645-1648` = `nowInLadderToPathFind || isPathFinding()`，
## 而 `isPathFinding():444-451` 读的是 `KeyController.nowPathFinding:1685-1688`
## = `_nowPathFinding || _tempJumpLadderPathObj != null`（后者是"人在空中/爬梯时先把这条
## 路线记下来，等落到稳定地面再重排"那一枚暂存）。⇒ 本工程的同一件事是
## **身上有没有活动路线**（`click_move_active` 已把 `click_replan_pending` 算进去）
## **加上"这一趟爬梯是不是自动路线带的"**（`自动爬梯中`）。
## ⚠ 这里原来读的是 `自动寻路中` —— 那一把是屏幕顶部「自动寻路中．．．」那行提示的开关，
## 只有 `走向(..., 自动=true)`（任务赶路/小地图）才点亮，而挂机自己发的 `走向(落点, true, false)`
## 是 `自动=false` ⇒ **这道闸对挂机自己的路线永远是开的**：人在梯子上每一拍都重新点目标、
## 重新发一条寻路，而 `走向()` 里 `click_climb_direction` 是**按当下目标的 y 现算**的
## （`玩家.gd:230-231`），目标在拾取物（下层）与怪（上层）之间来回换 ⇒ 竖直方向来回翻，
## 就是用户 2026-10-19 实机报的"上梯子不会卡住了，但一直上下上下"。
func _在赶路线() -> bool:
	return bool(_玩家.get("click_move_active")) or bool(_玩家.get("自动爬梯中"))


## 「身上还挂着一条自动路线」—— 原版 `player.isPathFinding()` 的那一句。
## ⚠ 与提示旗 `自动寻路中` **不是一回事**：那一把只被 `走向(..., 自动=true)` 点亮，
## 拿它当"有没有在走"的条件 ⇒ 途中顺手捡那一支永远不跑（10-19 实测红出来的根因）。
func _在走路线() -> bool:
	return bool(_玩家.get("click_move_active"))


## 原版进大块的条件：`movementAction ∈ {STAND(1), SIT0(7), LADDER(4), ROPE(5)}`（`:729`）。
## 本工程 `_同步动作` 用的是同一套编号（`玩家.gd:125-135`），照抄。
func _在待机动() -> bool:
	return int(_玩家.get("_同步动作")) in [1, 7, 4, 5]


func 摆看住的目标(怪) -> void:
	if _实体 != null and _实体.has_method("显示目标框"):
		_实体.call("显示目标框", 怪)


func 停打坐() -> void:
	if bool(_玩家.get("is_practising")):
		_玩家.call("set_practising", false)


func 开始打坐() -> void:
	_玩家.call("set_practising", true)
	## 带协议那一发（`86:1` = 原版 `HealHandler.requestHealStart()`，服务端按打坐结算收益）。
	if _后端 != null and _后端.has_method("request_heal_start"):
		_后端.call("request_heal_start")


func _清目标与寻路() -> void:
	目标 = null
	_追击 = false
	## ⚠ **不清拾取队列**（10-19 按原版删掉了这里的 `拾取队列.clear()`）：
	## 原版 `_toPickItems` 只由挂在 stage 上那条 ENTER_FRAME（`GuajiHandler.as:1103-1115`）
	## 自然排空 —— `isStart = false`（`:1055-:1069`）与 `TargetHandler.clear()` 都**不动它**
	## ⇒ 已经点名的最后一两枚照样会捡完。本工程 `拍()` 已改成无条件调用，`_吞一枚拾取()`
	## 排在所有早退之前，排空这条路是通的。
	if _玩家.has_method("停止追打"):
		_玩家.call("停止追打")		# 原版 `set isStart(false)` 里 `TargetHandler.clear()` + `stopPathFind()`
	_玩家.call("cancel_auto_path")
	## `clear():462-469` 里除了 `toAttackAnemy=false` 还有 **`viewTarget = null`** 那一行，
	## 而那个 setter 会把头顶那枚蓝色箭头从旧目标身上摘掉（`TargetHandler.as:267-270`）。
	## 以前这里只交了追打命令、没清"看住的那只" ⇒ 停了挂机箭头还钉在最后那只怪身上。
	if _实体 != null and _实体.has_method("清看住的目标"):
		_实体.call("清看住的目标")


## ── 途中顺手捡的盒子（`:852-:853`：身体盒 inflate(90,55)）──
## 尺寸推导见文件头 身体盒/途中外扩 四条常数（`Character.as:80` + `Rectangle.inflate` 的
## "中心不变、每边加一半"语义 ⇒ `Rect2(我.x−72, 我.y−122.5, 144, 150)`，不是 ±90/±120 那种硬编）。
func _途中盒() -> Rect2:
	var 我: Vector2 = _玩家.get("position") as Vector2
	var 半宽 := 身体盒半宽 + 途中外扩横 / 2.0			# 27 + 45 = 72
	var 顶 := 身体盒顶 - 途中外扩纵 / 2.0				# −95 − 27.5 = −122.5
	var 底 := 途中外扩纵 / 2.0						# 0 + 27.5 = +27.5
	return Rect2(我.x - 半宽, 我.y + 顶, 半宽 * 2.0, 底 - 顶)


## ── 特效与 PVP（`:1070-:1086` / `:1041-:1053`）──
func _摆特效(要挂: bool) -> void:
	if 要挂:
		## ⚠ 原版 `:1074-1081` 那句是 `API.stage.addChild(_guaJiTip)` —— **舞台 = 屏幕层**。
		## 上一版 `add_child` 挂在本节点（玩家的子节点）下面 = 把它放进了**世界层**：人一走
		## 那串"挂机中"就跟着角色跑、镜头一移更偏，屏幕上根本不是原版那个位置。
		## 本工程对应的那一层 = 烘焙场景里 group `game_hud` 那枚 CanvasLayer。
		var 层: Node = get_tree().get_first_node_in_group("game_hud")
		if 层 == null:
			return						# 没有 HUD 就宁可不画，也不许挂回世界里
		if _特效 == null or not is_instance_valid(_特效) or _特效.get_parent() != 层:
			if _特效 != null and is_instance_valid(_特效):
				_特效.queue_free()		# 换图后 HUD 是新建的那枚，旧的必须摘掉
			_特效 = load("res://脚本/表现/特效播放器.gd").new()
			_特效.name = "挂机中特效"
			层.add_child(_特效)
			_特效.call("play", "Effect_guaJiZhong")
		_摆特效位()
		_特效.visible = true
	elif _特效 != null:
		_特效.visible = false


## 原版 `x = Config.STAGE_WIDTH/2`（默认 960 ⇒ 480）、`y = 110`，鼠标穿透；而且
## `resize():1094-1101` 每次改舞台尺寸都重摆 ⇒ 挂机中途改窗口宽度，它跟着回水平中线。
## 写死 480 就等于把那条 resize 链删了，所以按视口现算、每拍核对一次（改动才写，不每帧白写）。
func _摆特效位() -> void:
	if _特效 == null or not is_instance_valid(_特效):
		return
	var 宽 := float(_特效.get_viewport_rect().size.x)
	if absf(_特效.position.x - 宽 / 2.0) > 0.5 or absf(_特效.position.y - 110.0) > 0.5:
		_特效.position = Vector2(宽 / 2.0, 110.0)


func _记pvp并切1() -> void:
	if _会话 == null:
		return
	_pvp记 = int(_会话.hud_state.get("pk_mode", 1))
	if _pvp记 != 1:
		_会话.request_pk_mode(1)			# 1 = 普通模式（服务端 `:41617-:41623` 的文案表）


## 原版停挂机那支只做了两件事：`setTimeout(resumePvpMode, 300)` + `requestHang_stopHang()`
## （`:1050-1054`）—— 还原**不是立刻**，是 300 毫秒以后。上一版在这里直接发上行，
## 于是"停完立刻切回普通"比原版快了 300ms，而且绕过了 `resumePvpMode` 里那三条 case 闸。
func _恢复pvp() -> void:
	_pvp还原毫秒 = 300.0


## 原版 `PVPHandler.resumePvpMode:121-149` 逐条照搬：
## ① 记的那档必须**非 0 且与当前不同**才动；
## ② 1(和平) / 4(全体) 直接发；
## ③ 2(组队) 要**此刻还在队里**、3(家族) 要**此刻还在家族里**，否则把记录改成当前档
##    （= 这一档从此不再还原，不是"重试"）；
## ④ 5(阵营) 原版 switch 里根本没有 case ⇒ 什么都不做（别"顺手补一条"）。
func _真还原pvp() -> void:
	var 记 := _pvp记
	if 记 <= 0 or _会话 == null:
		return
	var 现 := int(_会话.hud_state.get("pk_mode", 1))
	if 记 == 现:
		return
	if 记 == 2:
		if not _在队里():
			_pvp记 = 现
			return
	elif 记 == 3:
		if not _在家族里():
			_pvp记 = 现
			return
	elif 记 != 1 and 记 != 4:
		return
	_会话.request_pk_mode(记)


## 原版 `DataCenter.isInTroup(player.objectId)` —— 等价物是后端那份 1552 队伍摘要里的成员表。
func _在队里() -> bool:
	if _后端 == null:
		return false
	return not (_后端.get("authoritative_party") as Dictionary).get("members", []).is_empty()


## 原版 `FamillyManager.getMemberById(player.objectId)` —— 这边只有"我有没有家族号"这一个口径
## （`authoritative_guild.id`，由 1552:1 / 1552:15 两条摘要帧写）。
func _在家族里() -> bool:
	if _后端 == null:
		return false
	return int((_后端.get("authoritative_guild") as Dictionary).get("id", 0)) > 0


## ── 自动升级总闸的开/还原（`:360-:372` / `:435-:444`）──
## 本工程没有 `SkillHandler.autoUpgradeSkill` 这个全局闸；等价物是会话里那条
## "自动升级意志"流水线 —— **不是**同一件事，所以这里只记不碰，
## 真正生效的是 `拍自动升级()` 自己按那枚勾跑（详见 真值/窗口/挂机设置窗.md）。
func _挂上自动升级闸() -> void:
	pass


func _还原自动升级闸() -> void:
	pass


## ── 上行：1808 的 0/1 两档（原版只有这两档，整族没有下行）──
## 分工照原版：这两发由本模块（= `GuajiHandler`）自己发，会话只管翻本地状态。
## 在线 ⇒ 直接走后端的 `request_hang_start()/request_hang_stop()`；
## 离线 ⇒ 没有真后端，绕回 `会话.request_hang()` 那一发本地广播，
## 这样「第一拍只发一次」这类判据在离线门里仍然是**数得出来**的（不是自证）。
func _上行(档: int) -> void:
	if _会话 == null:
		return
	if _后端 != null and bool(_后端.get("in_game")):
		## `发出` = `put_data` 真写进那条已连接的 TCP。⚠ 这**不是**"服务端收到了"：
		## 1808 整族没有下行，服务端那边只把 `hang_active` 记在连接对象上
		## （`fake_flash_server.py:18326-18335`），GM 状态口也没露这一项 ⇒ 客户端之外查不到。
		## 在线腿要"服务端认的"证据只能看后面的打死/掉落，这一列只钉"循环自己发的、发得出去"。
		var 发出 := bool(_后端.call("request_hang_stop" if 档 == 1 else "request_hang_start"))
		上行记录.append({"档": 档, "在线": true, "发出": 发出})
		return
	上行记录.append({"档": 档, "在线": false, "发出": true})
	## ⚠ **原版那一句不会回头改 `isStart`**：`GuajiHandler.as:693-697`
	## ```
	##    if(!this._isSendBuff) {
	##       this._isSendBuff = true;
	##       Client.getInstance().requestHang_startHang();
	##    }
	## ```
	## 而 `Client.as:3471-3477` 整个函数体就是
	## ```
	##    public function requestHang_startHang() : void {
	##       if(this.channelClient) { this.channelClient.hangProcessor.requestStartHang(); }
	##    }
	## ```
	## —— 一句 socket 写，**没有任何一句**回到 `guajiHandler.isStart`。
	## 离线这一支以前直接 `_会话.request_hang()`，而那条会广播 `hang_changed`，本模块又正听着
	## 它（`hang_changed` = "原版 UI 直接写 isStart" 的替身）⇒ **自己给自己下一发 isStart**：
	## `置挂机态(同一个值)` 按原版要重跑 `setConfig()`(`:1088-1091`)，而 `setConfig` 头一件事
	## 就是 `:237 _isSendBuff = false`，接着 `:235-236` 清空两份黑名单、`:239-247` 把
	## `startPoint/fightArea` 重锚到脚下 ⇒ 症状（10-19 离线门实测）：`i` 每拍归 0、1808:0
	## **每一拍发一发**、`_totalTime` 被顶回出厂值所以永远走不到"到点回城"、活动区跟着角色跑、
	## 拾取队列与 `拾取发过` 每拍被清 —— 用户看得见的就是"挂着不干活/地上的东西不清/到点不回城"。
	_自灌中 = true
	_会话.request_hang(档 == 0)
	_自灌中 = false


## ── 读数小工具 ──
func 设(字段: String, 出厂: Variant) -> Variant:
	## 优先读**服务端那份 1283 原样**（`GameSession.挂机配置`），没有才吃原版出厂值。
	## 走原版字段名而不是本地翻译键，是为了让这 27 个字段**一个都不必经过翻译表**也能生效
	## —— 上一版就是栽在"翻了一个键、没翻另一个"，页面全亮、循环只认其中一半。
	if _会话 != null and (_会话.get("挂机配置") as Dictionary).has(字段):
		return (_会话.get("挂机配置") as Dictionary)[字段]
	return 出厂


func 整型(字段: String, 出厂: int) -> int:
	return int(设(字段, 出厂))


func _血量() -> float:
	return float(_会话.player_stats.get("hp", 0))


func _最大血() -> float:
	return float(_会话.player_stats.get("max_hp", 1))


func _蓝量() -> float:
	return float(_会话.player_stats.get("mp", 0))


func _最大蓝() -> float:
	return float(_会话.player_stats.get("max_mp", 1))


## `isPlayerLoseMp:338-342` = 身上有 LOSE_MP(10) 或 TIAN_ZHAO(66) 增益 ⇒ 那段时间不补蓝。
func _在漏蓝() -> bool:
	for 项 in _会话.hud_state.get("buffs", []):
		var 类 := int((项 as Dictionary).get("type", -1))
		if 类 == 10 or 类 == 66:
			return true
	return false


## "这一具站在哪一层"全工程**只有一份实现** = `地图实体.怪的层号()`（原版是 `AbstractPhysicObject.floor`
## 一个字段、由 `currFoothold` 每帧刷，怪和人都读同一个 getter；本工程以前人和怪各写了一份反查链，
## 字段取法不同 ⇒ 同一条 `getMonstersInFloor(player.floor, ...)` 的两头可能算出两个层号）。
## 这里把自己也交给那一份去算，别再留第二份。
func _层号() -> int:
	if _实体 == null or not _实体.has_method("怪的层号"):
		return -1					# `getMonstersInFloor:324` 拿 -1 直接回空表
	return int(_实体.call("怪的层号", _玩家))


## 挂机只打**同一块连通地面**。上下两层平台之间隔着梯子/跳台，锁过去就会一直上下梯子
## （用户 2026-10-26 实机）。原版 `floor` 本来就是这条连通脚点链（`MapData.as:392-440`），
## 原版 `getMonstersInFloor` 第一趟已经拦住；本工程的「放宽到全部怪」那一趟会跨层，
## 所以在这里再补同一道闸。玩家或目标任一方脚点未知（爬梯中/空中，-1）时不额外拦。
func _同层(怪) -> bool:
	if _实体 == null or not _实体.has_method("怪的层号"):
		return true
	var 我这 := _层号()
	if 我这 < 0:
		return true
	var 它那 := int(_实体.call("怪的层号", 怪))
	return 它那 < 0 or 它那 == 我这



## ⚠ 必须按**服务端权威格数**数空格（`会话.背包总格数()`），不许扫到常量 96：
## 原版这一条是 `DataCenter.getEmptySlots().length > 0`（`GuajiHandler:481/489/497/513/519`），
## `getEmptySlots()` 枚举的就是真实格子。按 96 扫会把"尾后第 91 格"当成空格 ⇒ 挂机判断
## "捡得下"、发拾取、服务端按 90 判满而**静默不删那枚掉落** ⇒ 用户 2026-10-19 报的
## "地面这么多东西一个都不捡，只捡了金币"（金币不占格，走 `:501-507` 那一条，所以只有它能进）。
func _有空槽() -> bool:
	return _会话._首空格(_会话.inventory, _会话.背包总格数()) > 0


func _背包满() -> bool:
	return _会话._首空格(_会话.inventory, _会话.背包总格数()) <= 0


# 已删（2026-10-25 报修 5.1/5.2）：`_是VIP5()` —— 原版 `GuajiHandler.as:276` 是
# `autoSellPickedEquip && VIPManager.vipLevel >= GUAJI_AUTO_SELL_EQUIP_LEVEL(=5)`（`VIPManager.as:17`，
# `vipLevel` 由元宝累计帧 `:46` 写）。用户点名「vip 的特权功能…不要求任何 vip 等级」⇒ 这道闸删掉，
# 勾选直接生效。本工程本来也只有 `vip` 布尔、拿不到等级细分，那条**不能算 1:1** 的欠账一并了结。


## 194 受击帧里带着"是哪只怪打的"（`fields[6]`，原版 `DamagePlayerInfo:36 oid`）。
## 原版只有**这一帧**会写 `lastAttacker`（`DamageHandler.as:66`，且必须受害者是我），
## 玩家打玩家(1329)、宠物打玩家(1331)两条路径**不写** —— 所以反击优先级只认怪。
var _打我的: Node2D = null
var _打我到期 := 0.0


func _记打我的那只(状态: Dictionary) -> void:
	if _后端 == null or int(状态.get("character_id", -1)) != int(_后端.get("character_id")):
		return
	if int(状态.get("damage", 0)) <= 0:
		return						# `:69-:71` 只有真掉血才置 isHit
	var 号 := int(状态.get("monster_object_id", 0))
	var 怪 = _实体.call("怪按编号", 号) if _实体 != null and _实体.has_method("怪按编号") else null
	if 怪 == null:
		return
	_打我的 = 怪 as Node2D
	_打我到期 = Time.get_ticks_msec() + 1000.0	# `Character._hitCoolTime:136` 的 1 秒窗口


func _打我的那只():
	if _打我的 == null or not is_instance_valid(_打我的):
		return null
	if Time.get_ticks_msec() > _打我到期:
		return null					# isHit 过期 ⇒ 原版不再反击（lastAttacker 虽然常驻但不作数）
	return _打我的
