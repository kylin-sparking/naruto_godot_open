extends Node2D

const OriginalSpriteScript = preload("res://脚本/角色/原始动画精灵.gd")
const 角色造型 := preload("res://脚本/角色/角色造型.gd")	## 头像号 → 身体造型号（8 位补零）
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const CombatActorScript = preload("res://脚本/角色/战斗角色.gd")
const PetCompanionScript = preload("res://脚本/角色/宠物伙伴.gd")
const SkillAnimationScript = preload("res://脚本/角色/技能动画精灵.gd")
const 技能飞行物脚本 := preload("res://脚本/角色/技能飞行物.gd")
const 伤害数字脚本 = preload("res://脚本/角色/伤害数字.gd")
const 飘字队列脚本 := preload("res://脚本/角色/飘字队列.gd")	## 每个角色一条 400 毫秒的飘字队（原版节奏）
const 头顶飘字规则 := preload("res://脚本/界面/头顶属性飘字.gd")	## 哪一档飘、什么颜色（逐条带 AS3 行号）
const 族旗脚本 := preload("res://脚本/角色/族旗.gd")
const 家徽图脚本 := preload("res://脚本/界面/窗口/家族/家徽图.gd")
const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")
## 禁寻路图（迷路森林那两口）：踩箭头触发 / 不向上发拾取。口径见该文件。
const 禁寻路地图 := preload("res://脚本/地图/禁寻路地图.gd")
## 打坐那圈光环 —— 与本地那具身体**同一份素材**（别在别处再导一遍图），见 `_刷新远程打坐光环`。
const 打坐光环场景 := preload("res://场景/角色/打坐光环.tscn")
## 怪脚下那圈变异/首领光环 + 名字下面那排强化图标（原版 `Monster.as:1655-1680` / `:644-666`）。
const 精英外观脚本 := preload("res://脚本/角色/精英外观.gd")
## 别人身上那排状态图标（201/202 驱动）与角色头顶那条血条（1330/203 驱动）。
const 状态图标层脚本 := preload("res://脚本/角色/状态图标层.gd")
const 怪物血条脚本 := preload("res://脚本/角色/怪物血条.gd")
const 战场倒计时脚本 := preload("res://脚本/界面/组件/战场倒计时.gd")
## 原版捉宠流程（TargetHandler.gotoCapturePet → GeneralInternalLoading → requestCatchPet）。
const 捉宠流程脚本 := preload("res://脚本/地图/捉宠流程.gd")	## 左侧那行「离比赛结束还有」
const 竞技场窗脚本 := preload("res://脚本/界面/窗口/竞技场窗.gd")	## `PvpManager` 等价件（isPking 那一步）
## 只为取跳跃那两条物理常数 —— 旁观端那具身体要和真身跑**同一条抛物线**，
## 见 `_远程每帧位移` 与 `脚本/角色/跳跃常数.gd` 顶部（⚠ 别改成 preload `玩家.gd`：
## 那里面有 autoload 标识符，会变成编译期依赖、本地玩家直接建不出来）。
const 跳落 := preload("res://脚本/角色/跳跃常数.gd")
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
## #352 打人链**唯一**的判定入口（原版 `PVPHandler.canAttackPlayer:346-405` /
## `getNoAttackWarning:414-467` 的逐句转写）。本工程别处**不许**再抄一遍那套模式/等级闸。
const PVP判定 := preload("res://脚本/角色/PVP判定.gd")
const INTERACTION_DISTANCE := 115.0
const NAMEPLATE_WIDTH := 160.0
const NAMEPLATE_HEIGHT := 18.0
## 名字文字的净落点（相对角色原点 = 脚点）——**在脚下面，不在头顶**：
## `RoleNamePane` 把文字画在自己原点上方（`_bg.y = -paneHeight`、`_tf.y = _bg.y + 4`），
## 于是 `Character.as:1484` 的 `y = paneHeight - 3` → 人物落点 脚点+1；
## `Monster.as:840/1686` 的 `y = 2 + paneHeight`、`NPCSprite.as:234` 的 `y = paneHeight`
## → 怪物 / NPC 落点 脚点+6。
const 名字相对脚点 := 1.0
const 怪物名字相对脚点 := 6.0
## 名字下面那行称号比名字低多少：`NPCSprite.as:240` 是
## `称号.y = 名字.y + 称号.paneHeight - 5`，而 `paneHeight = textHeight + 10`
## → **间距 = 该行文字高度 + 5**。这里用 Godot 那份字体实际量出来的行高当 textHeight，
## 不钉常数（钉了就会随皮肤表/字号漂）。
const 称号间距补量 := 5.0
## 名牌**行与行**之间、以及**最后一行与那排状态图标**之间的净缝 = **4 个空像素行**。
## `RoleNamePane.as`：`paneHeight = textHeight + 10`（`:180-182`）、`_tf.height = textHeight + 10`（`:171`）、
## `_bg.y = -paneHeight`（`:122`）⇒ 牌的**原点 = bg 盒底边**；`_tf.y = _bg.y + 4`（`:134`）再加
## TextField 自带的 2px 内缩 ⇒ 墨迹盒 `[原点-10+6, 原点-10+6+textHeight)` ⇒ **原点比墨迹底低 10-6 = 4**。
## `Character.as:1486` 家族牌 `y = 名字牌.y + paneHeight - 6`、`:1490/:1494` 称号牌同一条 `- 6`、
## `:1501/:1505/:1510` 图标排 `y = 那张牌.y`（取的是**原点**）⇒ 处处都是"上一行墨迹底 + 4 个空行"。
## 移植时把 AS3 注释里的"底边"读成了**墨迹底**、缝写成 0 ⇒ 用户 2026-10-22 报修 8
## 「家族名称文字与下方家族徽章、忍术境界图标、写轮眼境界图标略微有一点重叠」
## （`开发工具/_probe_头顶重叠量测.gd` 实测：缝 = 0 px，两摊墨上下紧挨）。
## ⚠ 别跟 `称号间距补量` 混用：那条是 NPC 功能称号的**另一行算式**（`NPCSprite.as:240` 用 `- 5`）。
const 名牌行距缝 := 4.0
## 头顶名牌那几行字的**实测行高**（`simsun_原版.ttf` @12px ⇒ 13 个墨迹行，
## `开发工具/_probe_头顶重叠量测.gd` 2026-10-22 量到）。正常路径一律用 `_行高(名牌)` 现量，
## 这条只给"名牌节点还不存在"的兜底分支用（不然那个数只能拍脑袋）。
const 世界名字行高 := 13.0
## 本地玩家头顶那行 `[家族]<族名>` 的颜色。真值 `Character.as:275`：
## `_banghuiPane = new RoleNamePane(4059383)`，4059383 = **0x3DF0F7** —— 与族旗那两行
## 名牌同色（`族旗.gd:44` 的 `名字色`）。族徽缩到 18×18（`Character.as:1447-1449`：
## `getJiaHuiPic` 34×34、`scaleX = scaleY = 18 / 34`）。
const 家族牌色 := Color(0x3D / 255.0, 0xF0 / 255.0, 0xF7 / 255.0)
const 族徽边长 := 18.0

## ── 头顶状态图标排（`_statusIconPane`，`Character.as:706-718`）─────────────
## 原版每个图标块都是 **20×20 的 `Effect_CharStatus_Kuang` 框 + 里面一件图标**，
## 块宽 20、`x = 20*序号`、整排 `x = -10*数量`，`y` 取最下面那张非空牌的**原点**
## （= 牌盒底边，比该行文字墨迹底低 `名牌行距缝`；`真值/地图/头顶状态图标排.md` ⑤）。
## 里面那件图标的缩放逐项照 AS3：
##   · 家族家徽 34→18（`Character.as:1449` `18/34`、内缩 1px）
##   · 忍术境界 30→18（`:1895-1897` `18/30`、偏移 10）
##   · 写轮眼状态 **不缩**（`setXieLunYanState:2640` 只写 `_loc3_.x = _loc3_.y = 0`，
##     整段 2623-2643 没有任何 `scaleX/scaleY`）。导出图 20×20 与底框同尺寸 ⇒ 撑满那一格。
##     ⚠ 旧注释写的「`:2645` `18/30`」是**假前提**：`:2645` 是 `adjustHeights()`，
##     那个比例只属于忍术境界那枚 —— 照它缩把 20×20 压成 12×12（用户 2026-10-21 报修 2.2「太小了」）。
const 状态图标块 := 20.0
const 忍术境界门槛 := [100, 250, 450, 700, 1000, 1400, 1900]
const 忍术境界图标 := "res://素材/特效/Effect_RenShuJingJie/Effect_RenShuJingJie_%d/1.png"
const 忍术境界原边长 := 30.0
const 写轮眼状态图标 := "res://素材/界面/原版窗口/人物/血继界限/写轮眼状态/世界状态/世界状态%02d.png"

## ── 头顶那摞"忍云"榜单徽记（`_paihangTipPane`）────────────────────────────
## 真值两条：
##   · `Character.doTitleLayer:1316-1348` —— 板子挂在角色原点**上方 120**
##     （`_paihangTipPane.y = -120`）。原版还有 -150 / -180 两档，前提分别是"有护航等级图标"
##     和"还有暮叶战称号板"，这两样本工程都没实装 ⇒ 恒走 -120 那一支。
##   · `PaiHangTipPane.redraw:22-46` —— 逐枚 `y = -(长度-1-序号)*28`、**x 一个字都不写**，
##     所以横向落在哪儿全看 SWF 里那枚 symbol 自己的注册点。
const 忍云板相对脚点 := -120.0
const 忍云行距 := 28.0
## 注册点相对 PNG **左上角**的 y（像素）。出处 = JPEXS 把 `Effect_PaiHangBang.swf`
## 转 XML 后每枚 `DefineSpriteTag` 里那一个 `PlaceObject` 的 `shapeBounds`：
## `注册y = -Ymin/20`，141 宽那批 `Ymin = -520` ⇒ 26；143 宽那批（`_14.._17`）
## `Ymin = -500` ⇒ 25。横向我到 `宽/2`（`Xmin/Xmax = ±1410`、`±1430` twips ⇒ 对称）。
## ⚠ 别拿"PNG 高度"顶替这个数：`_0/_1/_2/_3/_4/_5/_9/_12` 那 8 枚的墨迹只到 `y = -1`，
##   画布高 25 而注册点在 26 ⇒ 差的那 1 px 是原版留的空行，量测见
##   `开发工具/_probe_忍云注册点.py` / `_probe_忍云尺寸.py`（产物 `.scratch/_out/_忍云*.txt`）。
const 忍云注册y := {141: 26.0, 143: 25.0}
## 一枚徽记 = 一张静态图（`MCFromDatDefine.create()` 对 `Effect_PaiHangBang*` 那条分支
## 把 `frameCount` 写死成 1，且 `PicTool.getPaiHangIcon:175-187` 建完立刻 `autoTick = false`）
## ⇒ 不需要帧循环。榜号 → 图名是**查表**、不是恒等：`Etc.PaiHangBang[榜号].iconLink`
## （`数据/原版杂项.json`，23 条里 **15 条不跟号数走**：`5↔9` 互换，`10..22` 整体往后错一格
## 到 `11..24`，于是 `_14` 在这张表里根本不出现）。查不到再退
## `Etc.PaiHangBang_Hide[榜号 - 30].iconLink`（原版 `PaiHangTipPane:32-34` 那条兜底，
## 表里只有键 `0` ⇒ 只有榜号 30 能命中，拿到的正是 `_14`）。
const 忍云徽记图 := "res://素材/特效/Effect_PaiHangBang/%s/1.png"

## 世界里那几个名字（角色 / 怪物 / NPC / **掉落物**）的描边宽度。
##
## ⚠️ **它不是 UI 那条 `皮肤表.文字规则_描边数值`（=2）** —— 原版本来就是两个不同的滤镜：
##   `BaseUtil.getGlowFilter()`（`BaseUtil.as:124-126`）= `GlowFilter(0,1,2,2,10)` → **blur 2**，UI 文字用；
##   `RoleNamePane.getFilter()`（`RoleNamePane.as:191-200`）= `GlowFilter(0,1,3,3,6)` → **blur 3**，
##   而 `RoleNamePane` 正是**世界里所有名字**（`Character._namePane` / `Monster._mobNamePane` /
##   `NPCSprite` / `DropItemSprite._namePane`）用的那一套。
## 2026-09-27 用户给并排图报"怪物名称的字体"不对：量下来字号（12）、字体（宋体）、
## 颜色规则（`Monster.as:1270-1287` 五档）**都是对的**，差的只有这层描边 —— 我们 2、原版 3。
## ⚠️ §3.58 那次"把硬写的 3 扫成规则常量"把这里一起扫了；那是**扫错了地方**：
##    这几处是 `RoleNamePane` 的真值复刻，不是 UI 规则的地盘（同 `伤害数字.播放` 那类例外）。
const 世界名字描边 := 3
## 2026-10-25 用户：「玩家名字、npc名字…都有点糊」并要求回到 12px（14px 觉得别扭）。
## 12px 走的是宋体 1-bit 点阵，白芯笔画只有 1px；名字沿用原版 glow blur 3 的**硬描边 3** 时，
## 黑晕像素是白芯的 1.37 倍（4× 裁图实测 235/172），12px 下整行像一团黑。
## 只把**玩家/NPC 名字**降到 2（与 NPC 称号、界面主题的 2 一致，比例约 1.10），
## 怪物名字、家族牌仍保持原版 3 —— 用户没点名它们，别扩散。
const 玩家NPC名字描边 := 2
## 掉落物名字的颜色。原版 `DropItemSprite.render()` 里普通物品/金币都用白（`16777215`），
## 只有神器取 `EquipAptitudeType.getEquipColor(PURPLE)`。这里先给白的默认，
## 神器那一支等有对应美术时再补。
const 世界名字颜色 := Color(1, 1, 1)
## 神器掉落物的名字颜色 —— `EquipAptitudeType.getEquipColor(PURPLE)`（`EquipAptitudeType.as:20`）：
## `EquipColors = [0, 16777215, 589593, 40191, 9503487, 16773120, 16769131]` 的第 4 项 = `0x9102FF`。
const 神器名字颜色 := Color(0x91 / 255.0, 0x02 / 255.0, 0xFF / 255.0)

## 掉落物那两段动画的参数，逐条取自 `DropItemSprite`：
##   出场（`:384-410` + `:125-126`）：`_timeDrop = 800ms`，抛物线顶点在
##        `min(fromY, toY) - h`，`h = 115`；非金币还自转 `_rotationSpeed = 2160°/秒`；
##        落点 = `(toX, toY - 15)`、自转归零。
##   拾取（`:430-441`）：`PICKUP_TIME = 600ms`，alpha 由 1 掉到 **0.3**；
##        y 先升 80px、升到 `toY - 50` 处**镜像弹回**；x 以 **200px/秒**追拾取者。
const 掉落飞行毫秒 := 800.0
const 掉落弧高 := 115.0
const 掉落自转速度 := 2160.0
const 掉落落点抬高 := 15.0
const 拾取毫秒 := 600.0
const 拾取上浮 := 80.0
const 拾取封顶 := 50.0
const 拾取追速 := 200.0
##   待机（`:478-483`）：`_pastTime` 每帧累加、满 `2π·300` 减一圈，
##        `contentContainer.y = floor(3 * sin(_pastTime/300))` ⇒ **±3 像素、一圈 ≈ 1885ms**，
##        落地时 `_pastTime += rnd(0,600)` ⇒ 每枚相位不同。
const 浮动幅度 := 3.0
const 浮动一圈 := 2.0 * PI * 300.0

var _entities: Array[Node2D] = []
var _player: Node2D
var _session: Node
var _activity: Node
var _backend: Node
var _hud: Node
var _pet_companion: Node2D
## 两态并存时的第二只（服务端允许"一只附身 + 一只出战"）。主指针 `_pet_companion` 优先给出战那只。
var _pet_companion_extra: Node2D
## 左侧战场倒计时那一块（原版 `UIMain2.showLingdangZhanchangTime`，懒建一次、走完只是藏起来）
var _战场倒计时: Control = null
## 进场钟三件套 = `Character.as:116 _copyEnterTimerLeft` / `:188 _nowCopyEnterClock` / `:218 _copyText`
## （原版那枚"开没开"的布尔这边用 `> 0` 表示：等价，且少一个能互相顶掉的状态）
var _钟剩毫秒 := 0
var _钟文案 := ""
var _钟上次秒 := -1
var _entities_by_object := {}
var _remote_players := {}
## 谁正在播出手动作（编号 → true）。播完之前移动帧不许覆盖这一招，与本地玩家那条
## `出手中` 同一条口径。⚠ **不能用 `set_meta("出招中", …)`** —— Godot 4 的 metadata 键
## 要求合法标识符，中文键会报 `Invalid metadata identifier` 且**静默存不进去**
## （本轮在线门就是这么抓到：断言读回来永远是 false）。
var _远程出招中 := {}
## 远程玩家的预测外推状态（编号 → {目标, 速度, 收包时刻, 动作}）。见 `_推进远程玩家`。
var _远程外推 := {}
var _待删外推: Array = []
var _server_drops := {}
var _server_authoritative := false
var _hovered_npc_areas := {}
var _selected_character: Node2D
## **目标框显示的那只**。原版这里是 `TargetHandler.viewTarget`，和"点选/攻击目标"(`curTarget`)
## **不是一回事** —— 改它的地方有三处：
##   · 点怪（`Monster.onMouseSelect():727` `viewTarget = this`）；
##   · **挂机自动战斗挑中的那只**（`GuajiHandler.as:833`）；
##   · **技能命中的目标**（`SkillHandler.as:1095`）。
## 我们原来只认第一处，所以"打别的怪时目标框不换"（用户 2026-09-27 报）。
var _view_target: Node2D
## 目标框里那管血的上一帧值，变了才重发（见 `_process`）。
var _选中目标上次血量 := -1
var _选中目标上次蓝量 := -1
## 远程玩家 actor → `{"态": 服务端那份 state, "画": 它的动画精灵}`。
## 目标信息条要跟着别人掉血刷新（原版 `Character` 的 hp 变化会刷 `setTargetWindowHp`），
## 而那份 state 是 `_handle_move_player_text` / 玩家列表回帧在改的，只能从这儿取。
var _远端状态: Dictionary = {}

func _ready() -> void:
	_session = get_node_or_null("/root/GameSession")
	_activity = get_node_or_null("/root/ActivityService")
	_backend = get_node_or_null("/root/BackendConnection")
	_connect_backend_signals()
	_player = get_tree().get_first_node_in_group("player") as Node2D
	call_deferred("_ensure_local_player_nameplate")
	call_deferred("_ensure_local_player_family_marks")
	call_deferred("_find_hud")
	if _session != null:
		_session.settings_changed.connect(_on_settings_changed)
		_session.player_stats_changed.connect(_on_player_stats_changed)
		_session.quests_changed.connect(_refresh_quest_markers.unbind(2))
		_session.pets_changed.connect(_refresh_pet_companion.unbind(1))
		# 忍术境界图标看的是**已学忍术层数之和**；写轮眼状态图标看的是血继阶数。
		# 两者都是回帧推进来的，置标志、帧末统一刷（同家族标示那条）。
		_session.skills_changed.connect(func(_技能们: Array) -> void: _家族标示待刷 = true)
		_session.cultivation_changed.connect(func(族: String, _状态: Dictionary) -> void:
			if 族 == "写轮眼":
				_家族标示待刷 = true)
	call_deferred("_refresh_pet_companion")
	## 换图那一拍核对"在不在竞技场里"（原版 `Client.as:6340` → `PvpManager.onEnterMap`）。
	## ★ 必须排在 `_refresh_pet_companion` **后面**：deferred 按登记顺序跑，早一步就是去藏一只
	##   还没建出来的宠物 ⇒ 进图那一拍藏不住，下一帧宠物又冒出来。
	call_deferred("_核对竞技场对战")
	# ⚠️ 这里原来有一条 `BakedLife` 路（`get_node_or_null("BakedLife")` +
	#    `if ... and map_id == "101010000"` 才走 `_configure_baked_entities`）—— **整条已删**：
	#    * 烘焙器**从不生成 `BakedLife` 节点**（`开发工具/烘焙当前地图.gd` 里零命中；
	#      168 张烘焙产物 `场景/生成/*.tscn` 里也 **0/168** 命中）→ `baked` 恒为 null，
	#      连 `baked.queue_free()` 那一句都是死的；
	#    * 它还是「**按内容特例**」的写法（只有 101010000 走），正是 §3.28.1 第 1 条要禁的那类。
	#    NPC/怪物本来就是运行时按 `地图.json` 的 `life` 段生成的（下面的 `_build_runtime_entities`），
	#    和 `地表`/`攀爬物`/`地图块`/`地图物件` 一样，**不需要按地图号分支**。
	_server_authoritative = _backend != null and bool(_backend.get("in_game"))
	# ⚠️ 族旗**两条路都要刷**：服务端换图时会推 `1815:1`（`_local_flag_spawn_payload`），
	#    而这一句原来只写在离线分支末尾 —— 权威分支提前 `return` 了，于是**进图永远不立旗**。
	#    建在这两行之前，一条都不漏。
	_刷新族旗()
	# ⭐ **进图主动要一次族旗表**：本机服务端**只在换图时推 `1815:1`，登录进图不推**
	#    （实机日志 2026-10-11：`图=100000000 数据图=无` —— 客户端手里一条旗数据都没有）。
	#    要一次表之后，`_刷新族旗` 就能从表里挑出本图那一行把旗立起来。
	if _server_authoritative and _backend.has_method("request_flag_list"):
		_backend.call("request_flag_list")
	if _server_authoritative:
		_hydrate_server_entities()
		print("LifeRoot: using server-authoritative entities")
		return
	var map_id := _get_current_map_id()
	var map_path := MAP_RESOURCES.map_data_path(map_id)
	var map_data := _load_json(map_path)
	var life_entries: Array = _normalize_entries(map_data.get("life", []))
	_build_runtime_entities(life_entries)
	print("LifeRoot: rendered %d life entities" % _entities.size())

## 当前地图上的**族旗**（服务端 `1815:1` 推的那面）。
##
## 真值：`FlagHandler.addFlag`（`FlagHandler.as:134-159`）—— 一图一旗，位置就是服务端给的
## `(x, y)`（服务端从 `MAP_FLAG_LOCATIONS` 取，含 foothold ⇒ `y` 已经是地面高度，
## **不需要**再按 foothold 下落，这与 NPC/怪物不同）。
## 进图时服务端会推一次（`_local_flag_spawn_payload`），插旗/改旗后还会再推
## （`_refresh_family_identity` → `_send_local_flag_spawn(visible=True)`）。
var _族旗: Node2D

func _on_map_flag_changed(_旗: Dictionary) -> void:
	_刷新族旗()


func _on_flag_list_changed(_表: Array) -> void:
	_刷新族旗()


## 族旗诊断日志（**不依赖按键**）：每次判断族旗都往 `user://族旗诊断.txt` 追加一行。
##
## 为什么要有它：F9 那份取证依赖"按键真的到得了这个节点"，用户实机按了却没写出文件
## （2026-10-11）。改成**自动记**：只要进图/收到推送/收到表，就会留痕，
## 排查时直接看文件即可，不用玩家配合按键。
## 只保留最后 200 行（避免长期游玩把文件撑大）。
const 族旗日志 := "user://族旗诊断.txt"

func _记族旗日志(行: String) -> void:
	var 旧 := ""
	var 读 := FileAccess.open(族旗日志, FileAccess.READ)
	if 读 != null:
		旧 = 读.get_as_text()
		读.close()
	var 段 := 旧.split("\n", false)
	while 段.size() >= 200:
		段.remove_at(0)
	段.append("%s %s" % [Time.get_time_string_from_system(), 行])
	var 写 := FileAccess.open(族旗日志, FileAccess.WRITE)
	if 写 != null:
		写.store_string("\n".join(段) + "\n")
		写.close()


func _刷新族旗() -> void:
	var 数据: Dictionary = {}
	if _backend != null:
		数据 = (_backend.get("authoritative_map_flag") as Dictionary).duplicate(true)
		# 推送里没有"本图那一面"时，退回族旗表里找本图那一行（见信号连接处的说明）。
		if int(数据.get("map_id", -1)) != int(_get_current_map_id()):
			for 行 in (_backend.get("authoritative_flag_list") as Array):
				var 记 := 行 as Dictionary
				if int(记.get("map_id", -1)) == int(_get_current_map_id()):
					数据 = 记.duplicate(true)
					break
		# ⚠️⚠️ 族旗表**每张领域战图都有一行**，没旗的那行是"空行"：
		#     `bang_id=0 / 家族名="-" / 血 0/0 / **flag_level=0** / 旗名="-"`（服务端
		#     `_encode_local_flag_info` 里 owner 为 None 的那一支）。**空行 ≠ 有旗**！
		#     原版 `Flag.setIcon` 用 `flag_level` 选美术（`Flag.as:415`），0 级没有美术 ⇒ 必须按
		#     `flag_level > 0` 过滤，否则会立起一面"没有贴图、名字是 `-[0级族旗]`"的空旗
		#     （在线门 2026-10-11 就是这么抓到的）。
		if int(数据.get("flag_level", 0)) <= 0:
			数据 = {}
	var 在本图 := not 数据.is_empty() \
			and int(数据.get("map_id", -1)) == int(_get_current_map_id())
	var 来源 := "推送" if int((_backend.get("authoritative_map_flag") as Dictionary).get("map_id", -1)) == int(数据.get("map_id", -2)) else "表"
	_记族旗日志("刷新: 本图=%s 图=%s 数据图=%s 来源=%s 现有节点=%s"
		% [在本图, _get_current_map_id(), 数据.get("map_id", "无"), 来源,
			str(_族旗 != null and is_instance_valid(_族旗))])
	if not 在本图:
		if _族旗 != null:
			_族旗.queue_free()
			_族旗 = null
		return
	if _族旗 == null or not is_instance_valid(_族旗):
		_族旗 = 族旗脚本.new()
		_族旗.name = "族旗"
		add_child(_族旗)
		_族旗.call("configure", 数据)
		# ⭐⭐ **必须像 NPC/怪物一样按脚点算 z**：这张图的瓦片/物件各自带着
		#    `RenderProfile.角色z(层号, 层内序)` 那套 z 值（`地表.gd:249-256`、`地图物件.gd:80`），
		#    NPC/怪物靠 `z_index = _角色层次(pos)` 才排到地面上方。
		#    旗子原来**没设 z_index（=0）**，于是被地面/街道物件整个盖住 ——
		#    表现就是"日志说建旗了、可见=true，但画面里什么都没有"（用户 2026-10-11 实机）。
		(_族旗 as Node2D).z_index = _角色层次((_族旗 as Node2D).position)
		_记族旗日志("**建旗**: 位置=%s 等级=%s 旗名=%s 家族=%s 可见=%s z=%d"
			% [str((_族旗 as Node2D).global_position), 数据.get("flag_level"),
				数据.get("flag_name"), 数据.get("bang_name"), str((_族旗 as Node2D).visible),
				(_族旗 as Node2D).z_index])
	else:
		_族旗.call("应用数据", 数据)
		(_族旗 as Node2D).z_index = _角色层次((_族旗 as Node2D).position)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact_nearest_npc()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		## 点地面（没有被任何角色/钮接住的左键）**不清选中**。原版 `TargetHandler` 里
		## `viewTarget = null` 只有四个来源：`cancelTarget()`（点信息条上那枚头像）、
		## `setCurTarget(null)`、`clear()`（换图/死亡）、以及角色/怪**离场**那两处
		## （`TargetHandler.as:253/315/466`、`CharacterHandler.as:120`、`MonsterHandler.as:426/477`）
		## —— 移动指令根本不动它。手动一动该停的是**自动追打**（用户 10-15 口径：
		## 「手动一动就取消，选中保留」），所以这里只停追打。
		if _player != null and _player.has_method("停止追打"):
			_player.call("停止追打")

func _exit_tree() -> void:
	_clear_selected_character()
	if not _hovered_npc_areas.is_empty():
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func get_enemies_in_range(center: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for entity in _entities:
		if not is_instance_valid(entity) or entity.kind != "m" or not entity.alive:
			continue
		if entity.global_position.distance_to(center) <= radius:
			result.append(entity)
	return result

## 原版普通攻击的命中判定：拿攻击矩形去和每个怪的 `outerBodyRect` 求交，
## 命中的里面按**离玩家的距离**取最近的一个（`CommonAttack.getNearestMonsterInArea():82-113`）。
func get_nearest_enemy_in_rect(世界矩形: Rect2) -> Node2D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	var 参照 := _player.global_position if _player != null else 世界矩形.get_center()
	var 最近: Node2D = null
	var 最短 := INF
	for entity in _entities:
		if not is_instance_valid(entity) or entity.kind != "m" or not entity.alive:
			continue
		var 盒 := _怪物体型矩形(entity)
		if 盒.size == Vector2.ZERO or not 盒.intersects(世界矩形):
			continue
		var 距离 := entity.global_position.distance_to(参照)
		if 距离 < 最短:
			最短 = 距离
			最近 = entity
	return 最近

## 命中矩形内的**全部**怪。原版技能的自动选敌就是这个口径
## （`AbstractAttackSkill.createSkillMsg():248-257`：`outerBodyRect.intersects(命中矩形)` 的全收）。
func get_enemies_in_rect(世界矩形: Rect2) -> Array:
	var 结果: Array = []
	if 世界矩形.size == Vector2.ZERO:
		return 结果
	# 点选中的那只排**第一个** —— 原版把它当 PlayerAttackInfo 的主目标（`primary`）发出去。
	var 选中 := get_selected_enemy()
	if 选中 != null and is_instance_valid(选中) and 选中.get("alive"):
		var 选中盒 := _怪物体型矩形(选中)
		if 选中盒.size != Vector2.ZERO and 选中盒.intersects(世界矩形):
			结果.append(选中)
	for entity in _entities:
		if not is_instance_valid(entity) or entity.kind != "m" or not entity.alive or entity == 选中:
			continue
		var 盒 := _怪物体型矩形(entity)
		if 盒.size != Vector2.ZERO and 盒.intersects(世界矩形):
			结果.append(entity)
	return 结果

## 原版 `Character.outerBodyRect`（`Character.as:649-660` + `GeomUtil.copyRectangle()`）：
##   体型矩形 = 当前帧的 `bodyRect`（`lt`..`rb`，相对注册点）；
##   朝右时水平镜像 `x = -right; right = -x`；
##   最后平移到角色坐标。
##
## ⚠️ **穿人物皮的那一档要单独给盒子**（2026-10-24 修"竞技场我攻击不了"）：
## 逐帧 `lt`/`rb` 只有**怪**的帧里有（实测 `数据/角色/动画元数据.json`：
## mob 45678/45678 帧全带，character 0/6521 帧带）—— 因为原版根本不从帧里读角色的盒子，
## `Character.as:86` 是**一个常量**：`_bodyRect = new Rectangle(-27,-95,54,95)`，
## `Character.as:728-738` 的 `outerBodyRect` 拿它镜像 + 平移到角色坐标。
## 竞技场那位对手是"穿人物皮的怪"（`_spawn_life_entry:2307` 用 `configure("character", …)`），
## 不补这一档 ⇒ 它的盒子恒空 ⇒ 每一条谓词都在 `盒.size == ZERO` 那行把它剔掉 ⇒
## `_够得着()` 恒假、`_结算攻击` 的 enemy 恒 null ⇒ **连上行 40 都不发**，看着就是"点不动它"。
const 人物体型盒 := Rect2(-27.0, -95.0, 54.0, 95.0)

func _怪物体型矩形(actor: Node) -> Rect2:
	var sprite := actor.get_node_or_null("Sprite")
	if sprite == null or not sprite.has_method("当前身体矩形"):
		return Rect2()
	var 盒: Rect2 = sprite.call("当前身体矩形")
	if 盒.size == Vector2.ZERO:
		if str(sprite.get("造型类别")) != "character":
			return Rect2()
		盒 = 人物体型盒
	if int(actor.get("_朝向")) > 0:
		盒 = Rect2(-盒.end.x, 盒.position.y, 盒.size.x, 盒.size.y)
	盒.position += (actor as Node2D).position
	return 盒


## ── #352 打人链：**玩家**侧的目标查询 ────────────────────────────────
## 原版 `SkillExecute.as:330-365` 出手那一拍的分工是：`curTarget` 是 **Monster** ⇒ 直接打；
## 是 **Character（玩家）** ⇒ 先过 `SkillHandler.canAttack()`（`:Character 那一支
## = !isDead && objectId != 我的 && PVPHandler.canAttackPlayer(目标)`），
## 过了才 `toAttackAnemy = true`，**没过就只说一句 `getNoAttackWarning(目标)`**。
## 上面那四条怪查询（`get_enemies_in_range` / `get_nearest_enemy_in_rect` /
## `get_enemies_in_rect` / `get_selected_enemy`）全都用 `entity.kind != "m"` 把人剔掉，
## **语义一个字不动**（一堆行为门钉着它们）；人和怪**并表**只发生在下面这几个新方法里。

## 玩家的体型盒 = `Character.as:86` 那张**常量**盒（`_bodyRect = new Rectangle(-27,-95,54,95)`），
## 与 `_怪物体型矩形` 给"穿人物皮的怪"补的是同一张（`人物体型盒`）。
## 为什么不走 `_怪物体型矩形`：远程玩家那具是 `Node2D.new()` + 一个**没有命名为
## "Sprite"** 的动画子节点（`_on_server_player_spawned:827-831` 是 `add_child(sprite)`，
## 名字是自动生成的），`get_node_or_null("Sprite")` 取不到 ⇒ 恒回空盒。
## 算式与怪那一条一致：盒平移到角色坐标；水平镜像对这张盒是**恒等变换**
## （`end.x` 就是 27 ⇒ `-27` 镜像回来还是自己），所以不需要 `_朝向`。
func _玩家体型矩形(演员: Node2D) -> Rect2:
	var 盒 := 人物体型盒
	盒.position += 演员.position
	return 盒


## 当前 PK 模式（原版 `DataCenter.pvpMode`）。口径 = HUD 那颗 `_pvpBtn` 走的同一条：
## `GameSession.hud_state.pk_mode`（1 和平 / 2 组队 / 3 家族 / 4 全体 / 5 阵营，
## 由 `1285` 回帧 `_on_backend_pk_mode:2274-2280` 钳在 1..5）。
func _pk模式() -> int:
	var 头 = null if _session == null else _session.get("hud_state")
	if not (头 is Dictionary):
		return PVP判定.和平
	return int((头 as Dictionary).get("pk_mode", PVP判定.和平))


## `PVP判定` 要的**我方**上下文。逐条来源都写在行内（拿不到的一律给 false，不猜）。
func _PVP我方(目标角色号: int) -> Dictionary:
	var 属 = null if _session == null else _session.get("player_stats")
	var 属性: Dictionary = 属 if 属 is Dictionary else {}
	return {
		"等级": int(属性.get("level", 0)),
		## 原版 `player.isDead`：这边没有"我死了"这个字段，血归零就是死了
		## （`游戏会话.玩家被击败` 也只在 hp<=0 那一路发）。
		"死亡": int(属性.get("hp", 1)) <= 0,
		## `peaceMaps` 里存的是**整数图号**（`数据/PVP配置.json`），而 `current_map_id`
		## 是字符串 ⇒ 必须 `int()` 过，不然 `Array.has("100000000")` 恒假、安全图闸形同不存在。
		"图号": int(_get_current_map_id()),
		"同队": 目标角色号 > 0 and _队友号().has(目标角色号),
		"同族": _同族(目标角色号),
		## 原版 `isEnemyPlayer`（仇人/红名表）与 `nowIn3v3 / nowInNinja3v3 / nowInZhanChang /
		## nowInKuaFu` 这四种玩法**本工程都没有**（同 `_冲选中目标` 注掉的 `Job0.isSkillForbiden`
		## 那一条）⇒ 一律 false：少了这几档只会**更保守**（走模式与等级那两道闸），
		## 不会把不该放的包放出去。
		"仇人": false,
		"在3v3": false,
		## `nowInNinja3v3`（`PVPHandler.as:323/325`）：忍者3v3 与 3v3 同权 —— 这两种场里
		## **保护队友**（`:325` 是 `nowIn3v3 || nowInNinja3v3`），而战场/跨服不保护。
		"在忍者3v3": false,
		"在战场": false,
		"在跨服": false,
		## `MuYeDaZhanManager.isSameZhenYing`（`:355`）：木叶大战的阵营归属，本工程没有大战玩法
		## ⇒ false ⇒ 阵营档永远走到后面那几道闸（与"没参加大战"一致）。
		"同阵营": false,
		## `HuSongQuestManager.isDoubleTime`（`:319/:406`）：护送活动的"双倍时段"旗，
		## 本工程只建了护送窗（#115~#118），活动时刻表没接 ⇒ false ⇒ 护送闸按"非双倍"走。
		"护送双倍": false,
	}


## `PVP判定` 要的**目标侧**上下文。
## ⚠ 那三条保护旗（复活保护 / 挂机保护 / 打架旗）我们**没有服务端来源** ⇒ 一律传 false，
## 也**不许**在这边自造计时器 —— 原版那三样都是 buff/flag 帧推下来的。
func _PVP目标(演员: Node2D) -> Dictionary:
	return {
		"等级": int(演员.get_meta("pk_level", 0)),
		"死亡": not bool(演员.get_meta("pk_alive", true)),
		# TODO(#352 复活保护)：等服务端把 `protectTime=1800` 那档复活保护随 buff 帧推下来再接（原版 `Character.isRealiveProtected`）。
		"复活保护": false,
		# TODO(#352 挂机保护)：等服务端推"夜间/挂机保护"标记再接（原版 `Character.isNightProtected`）。
		"挂机保护": false,
		# TODO(#352 打架旗)：等服务端推 `isFlagFighting`（站在家族旗图里打架态）再接 —— 这一条缺会让旗图 PvP 少放行。
		"打架旗": false,
		# TODO(#352 护送旗)：原版 `Character.showHuSongIcon`（`Character.as:1939` 由护送状态置位，
		# `:1594` 复位）随角色状态帧下来；服务端没发 ⇒ false ⇒ 永远按"没在护送"走
		# （护送闸 `PVPHandler.as:319` 不拦，与非护送玩家一致，不会多放行什么）。
		"护送旗": false,
	}


## 同族闸。⚠ **原版比的是 `familyId`**，我们两边都只有 162 出场帧那份**家族名**
## （目标：`state.family_name` = `fields[23]`；我自己：`会话.guild.name`）⇒ 按名字比。
## 两个不同家族重名会误判成"同族打不了"，记为未决（#352）。
## 服务端没家族时发的是字面 `-` ⇒ 当"没有家族"处理，否则两个散人会因为都叫 `-` 而互相打不了。
func _同族(目标角色号: int) -> bool:
	if 目标角色号 <= 0:
		return false
	var 族 = null if _session == null else _session.get("guild")
	if not (族 is Dictionary):
		return false
	var 我的族名 := str((族 as Dictionary).get("name", "")).strip_edges()
	if 我的族名.is_empty() or 我的族名 == "-":
		return false
	var 他 = _remote_players.get(目标角色号)
	if not (他 is Node2D) or not is_instance_valid(他):
		return false
	var 他的族名 := str(他.get_meta("pk_family", "")).strip_edges()
	return 他的族名 != "" and 他的族名 != "-" and 他的族名 == 我的族名


## 某个演员节点上的**服务端角色号**（不是怪的 object_id）；不是玩家就返回 0。
func 玩家角色号(演员: Node) -> int:
	if 演员 == null or not is_instance_valid(演员):
		return 0
	return int(演员.get_meta("pk_char_id", 0))


## 命中盒内的**可打玩家**（`矩形` 传空 ⇒ 全收，TAB 与"看全图有没有人能打"都按全图候选）。
## 闸的顺序照原版：先**存在/可见/不是我/没死/隐身**（`SkillHandler.canAttack` 的
## `!isDead && objectId != 我的`，隐身那一条是 `SkillHandler:465` 与 `TargetHandler:261`），
## 再盒子相交，最后过 `PVP判定`。
func 可打的玩家(矩形: Rect2 = Rect2()) -> Array:
	var 出: Array = []
	if _backend == null or not bool(_backend.get("in_game")):
		return 出	## 离线那些"别人"是本地夹具假人，没有服务端角色号语义 ⇒ 一律不当 PVP 目标
	var 自己的号 := int(_backend.get("character_id"))
	var 模式 := _pk模式()
	for 号 in _remote_players.keys():
		var 演员 := _remote_players[号] as Node2D
		if 演员 == null or not is_instance_valid(演员) or not 演员.visible:
			continue
		if int(号) == 自己的号 or int(号) <= 0:
			continue
		if int(演员.get_meta("pk_char_id", 0)) <= 0:
			continue	## 没补身份的老节点（别的建人路径）⇒ 判不了等级，宁可不给
		if not bool(演员.get_meta("pk_alive", true)):
			continue
		if _隐身角色.get(int(号), false):
			continue
		if 矩形.size != Vector2.ZERO and not _玩家体型矩形(演员).intersects(矩形):
			continue
		if bool(PVP判定.判定(模式, _PVP我方(int(号)), _PVP目标(演员))["可打"]):
			出.append(演员)
	return 出


## 出手那一拍**点了人**（含"点了但按规则打不了"那种 —— 原版也一样把他当 `curTarget`，
## 只是在 Character 那一支被 `canAttack` 拦下、只说一句话）。不是人 ⇒ null。
func 点中的玩家() -> Node2D:
	if not is_instance_valid(_selected_character) or not _selected_character.visible:
		return null
	if 玩家角色号(_selected_character) <= 0:
		return null		# NPC / 怪 / 没身份的节点都不算
	return _selected_character


## 出手那一拍的 PVP 闸（给 `玩家.gd` 用：可打⇒发，不可打⇒把那句 `话` 说出来）。
## 返回 `{"可打":bool,"话":String}`；`话` 是空串时**什么都别说**（原版也是空串，
## `PVPHandler.as:414-467` 在"目标已死 / 在 3v3·战场·跨服"这三档回 ""）。
func PVP能否出手(演员: Node2D) -> Dictionary:
	if 演员 == null or not is_instance_valid(演员):
		return {"可打": false, "话": ""}
	return PVP判定.判定(_pk模式(), _PVP我方(玩家角色号(演员)), _PVP目标(演员))


## 当前目标：**怪或可打的玩家**，只返回一个。
## 怪那一侧原样走 `get_selected_enemy()`（含可见/`kind=="m"` 三道闸）；
## 人这一侧要**仍然在"可打的玩家"名单里**才给（原版出手那一刻重新问 `canAttack`，
## 中途他切了族/进了安全图/掉了线，就不能再把他当目标）。
func 选中目标() -> Node2D:
	var 怪 := get_selected_enemy()
	if 怪 != null:
		return 怪
	var 人 := 点中的玩家()
	if 人 == null:
		return null
	for 候 in 可打的玩家():
		if 候 == 人:
			return 人
	return null


## 命中盒里的**最近一个目标**：怪用原那条 `get_nearest_enemy_in_rect`，
## 人从 `可打的玩家(矩形)` 里取离我最近的，两边再比一次（原版 `SkillExecute` 是
## "curTarget 优先，没有才框最近"，这里给挂机/自动选敌用的那一档）。
func 最近目标(矩形: Rect2) -> Node2D:
	var 参照 := global_position
	if is_instance_valid(_player):
		参照 = _player.global_position
	var 怪 := get_nearest_enemy_in_rect(矩形)
	var 怪距 := INF if 怪 == null else (怪 as Node2D).global_position.distance_to(参照)
	var 人: Node2D = null
	var 人距 := INF
	for 候 in 可打的玩家(矩形):
		var 距 := (候 as Node2D).global_position.distance_to(参照)
		if 距 < 人距:
			人距 = 距
			人 = 候 as Node2D
	if 人 != null and 人距 < 怪距:
		return 人
	return 怪


## 命中盒里的**全部目标**（怪 + 可打的玩家并表）。怪保持原那条的相对顺序在前
## （`get_enemies_in_rect` 把点中的那只排第一个，原版 `PlayerAttackInfo.primary` 就靠它）。
func 目标列表(矩形: Rect2) -> Array:
	var 出: Array = get_enemies_in_rect(矩形)
	出.append_array(可打的玩家(矩形))
	return 出



## ── 挂机（智能托管）专用的四条查询 ────────────────────────────────
## 为什么另开而不复用 `get_nearest_enemy`：那一条**不看层、不看矩形、不看精英**
## （原先 `玩家.gd` 那句 `|Δy| > 100` 就是给它补的土法），而原版挑怪是
## `MonsterHandler.getMonstersInFloor(player.floor, _fightArea)`（`GuajiHandler.as:800`）——
## 层与矩形两个条件都在谓词里，缺一条就会追到别的层、或者跑出活动框。

## 怪此刻所在**层号**（原版 `floor` 由 `currFoothold.floor` 每拍刷新，`Monster.as:1364-1368`）。
## 我们不在怪节点上存层号，所以按它的坐标现反查落脚点表；查不到回 -1
## （原版 `getMonstersInFloor:324` 拿到 floor==-1 直接回空表，这边保持同一种"不猜"）。
func 怪的层号(actor: Node2D) -> int:
	## 原版 `AbstractPhysicObject.floor` = **连通脚点链编号**（`MapData.as:392-440`），
	## 不是 `foothold` JSON 顶层的 `layer`（那是渲染层，整张图常为 1）。以前拿 `layer`
	## ⇒ 上下两层平台同号，挂机锁到 2 层的怪后一直爬梯上下（用户 2026-10-26 实机）。
	var 脚点 := get_parent().get_node_or_null("Footholds")
	if 脚点 == null or actor == null:
		return -1
	var 命中: Dictionary = 脚点.call("find_foothold", actor.position.x, actor.position.y, "")
	if 命中.is_empty():
		return -1
	var 编号 := String(命中.get("id", ""))
	if 编号 == "" or not 脚点.has_method("连通地面号"):
		return -1
	return int(脚点.call("连通地面号", 编号))


func 怪物体型盒(actor: Node) -> Rect2:
	return _怪物体型矩形(actor)


## 挂机托管要把设置页那枚『通灵兽招式』写进出战宠物（原版 `GuajiHandler.set petSkill:1256-1264`
## → `UI.as:931-934` `myPet.curSkillID = id`），而宠物节点是这张图动态建的、名字带宠物号
## ⇒ 只能从这里拿现成的那一个引用，别按节点名猜。
func 宠物伙伴节点() -> Node2D:
	return _pet_companion if is_instance_valid(_pet_companion) else null


## = `PetHandler.showMyPet:548-558`：**出战与附身两只要一起**藏/显（原版是两条分开的 if，
## 两态并存时只藏一只就会看见"半只宠物"）。进竞技场战斗要藏（`PvpManager.as:236`）。
func 显示宠物(是否: bool) -> void:
	if is_instance_valid(_pet_companion):
		_pet_companion.visible = 是否
	if is_instance_valid(_pet_companion_extra):
		_pet_companion_extra.visible = 是否


## 左侧那一行战场倒计时。原版 `UIMain2.showLeftCountDownView:3124-3131`：
## `x = 20`、`y = charactorInfoPane.y + charactorInfoPane.height` ⇒ 摆在头像面板**底下**。
## 我们的头像面板自己是一个 CanvasLayer（layer=300）⇒ 这块挂进同一层，
## 才会跟着屏幕走；挂到 `LifeRoot` 底下就会跟着世界相机滚走（那是另一种错法）。
func _取战场倒计时() -> Control:
	if is_instance_valid(_战场倒计时):
		return _战场倒计时
	var 层 := 战场倒计时脚本.new() as Control
	层.name = "战场倒计时"
	var 面板 := get_parent().get_node_or_null("头像面板") as CanvasLayer
	var 牌: Control = null
	if 面板 != null:
		牌 = 面板.get_node_or_null("头像区域/角色状态") as Control
	if 面板 == null:
		## 离线量具里没有头像面板 ⇒ 至少别把这一块丢掉（判据要拿得到节点）
		add_child(层)
	else:
		层.position = Vector2(20.0, 20.0) if 牌 == null else Vector2(20.0, 牌.position.y + 牌.size.y)
		面板.add_child(层)
	_战场倒计时 = 层
	return 层


func 显示战场倒计时(秒: int) -> void:
	_取战场倒计时().call("设倒计时", 秒)


func 隐藏战场倒计时() -> void:
	if is_instance_valid(_战场倒计时):
		_战场倒计时.call("停")


## = `Character.player_showCopyEnterClock:2960-2980`（竞技场退场那一档：第三参 false、第四参给文案）。
func 显示进场钟(文案: String, 秒: int) -> void:
	_钟文案 = 文案
	_钟剩毫秒 = 秒 * 1000
	_钟上次秒 = -1


## = `Character.tickCopyClock:878-899`：每帧减毫秒、**整秒变了才喊一次**（一秒一行字，不是一帧一行），
## 走到 0 就把三件套复位。喊出去的是头顶飘字那条队：
## `player_addAttriChangeTip(_copyText, 秒, true, 0, 65280, true)` ⇒ 65280 = **#00FF00 绿**。
func _拍进场钟(毫秒: float) -> void:
	if _钟剩毫秒 <= 0:
		return
	_钟剩毫秒 -= int(ceil(毫秒))
	if _钟剩毫秒 > 0:
		var 秒 := int(ceil(_钟剩毫秒 / 1000.0))
		if _钟上次秒 != 秒:
			_钟上次秒 = 秒
			_飘玩家头顶字(_玩家头顶锚点(), 秒, _钟文案, Color(0, 1, 0))
	else:
		_钟剩毫秒 = 0
		_钟上次秒 = -1


## 换图那一拍把"在不在竞技场"这件事交给 `PvpManager` 等价件（原版 `Client.as:6340` 就一句话）。
func _核对竞技场对战() -> void:
	竞技场窗脚本.进图(int(_get_current_map_id()), self)


func 怪按编号(object_id: int) -> Node2D:
	return _活演员(object_id)


func 挂机的同层怪(层号: int, 世界矩形: Rect2) -> Array:
	var 出: Array = []
	if 层号 < 0:
		return 出
	for entity in _entities:
		if not is_instance_valid(entity) or entity.kind != "m" or not entity.alive:
			continue
		var 盒 := _怪物体型矩形(entity)
		if 盒.size == Vector2.ZERO or not 盒.intersects(世界矩形):
			continue
		if 怪的层号(entity) != 层号:
			continue
		出.append(entity)
	return 出


## 放宽那一趟（`:813-:815`）：**同图所有怪**都算候选，但矩形条件仍在
## （由调用方按 `CommonAttack.getNearestMonsterInArea` 的口径判，这里保持同分工）。
func 挂机的全部怪() -> Array:
	var 出: Array = []
	for entity in _entities:
		if not is_instance_valid(entity) or entity.kind != "m" or not entity.alive:
			continue
		出.append(entity)
	return 出


## 活动框/身边盒里的**可捡掉落**，返回掉落状态字典数组。
## 谓词照 `DropItemHandler.getPickableDropItemsInRect:529-541` + `canItemPickUp`：
## **点包含**（`rect.contains`，不是盒相交）、没被 5 秒单枚锁挡住、不在空中/不在被捡动画、
## 且 `!touchUp`（与 `_最近可捡掉落物:1183` 同方向，别改反）。
## ⚠ 状态是从**节点 meta** 现取的（在线与离线掉落都带），不再依赖 `后端.map_drops`——
##   否则本地打怪掉的道具（离线那一条）会整批查不到、挂机不捡自己打的包。
func 挂机的掉落(世界矩形: Rect2) -> Array:
	var 出: Array = []
	for 编号 in _server_drops.keys():
		var 掉 := _server_drops.get(编号) as Node2D
		if not is_instance_valid(掉):
			continue
		if bool(掉.get_meta("drop_touch_up", false)) or bool(掉.get_meta("drop_air", false)) \
				or bool(掉.get_meta("drop_picking", false)) or bool(掉.get_meta("drop_removed", false)):
			continue
		if float(_锁定表.get(编号, 0.0)) > 0.0:
			continue
		if not 世界矩形.has_point(掉.position):
			continue
		出.append({
			"object_id": int(编号),
			"x": 掉.position.x, "y": 掉.position.y,
			"item_id": String(掉.get_meta("drop_item", "")),
			"is_meso": bool(掉.get_meta("drop_meso", false)),
			"owner_id": int(掉.get_meta("drop_owner", -1)),
			"aptitude": int(掉.get_meta("drop_aptitude", 0)),
		})
	return 出


## 挂机"顺手捡"那条路的发帧入口（与点掉落物、身体碰到共用 `_发拾取`，**节流照旧走**）。
## 原版 `GuajiHandler.onEnterFrame():1110` 就是 `pickDropItem(_toPickItems.shift())` —— 走的是
## `DropItemHandler.pickDropItem(param1, param2 = true)` 那个默认值：先 `canItemPickup(item, true)`
## （**这一枚要是撞上 200ms 还在跑，就直接作废**，队列里它已经被 shift 掉了），过了才把
## `pickitemTimeLimit` 置 200。紧接着 `:1111` 一句 `refreshPickTime()` 归零 ⇒ 下一帧又是 0，
## 所以排队的吞吐仍是**每帧一枚**，而"当场绕开节流"是假的快 —— 会把手动按 Z 那一下也顶掉。
func 发拾取(object_id: int, 走节流 := true) -> void:
	_发拾取(object_id, 走节流)


## 原版 `DropItemHandler.refreshPickTime():94-97` —— 把全局 `pickitemTimeLimit` 归 0。
func 刷新拾取时间() -> void:
	_拾取闸 = 0.0


## 原版 `TargetHandler.cancelTarget()`（`:251-257`）里挂机用得到的那一半：
## 把"看住的目标"摘掉（回城打坐前要清，`:718`）。
func 清看住的目标() -> void:
	## 原版 `cancelTarget():251-257` 第一句就是 `this.viewTarget = null`，
	## 而那个 setter 会先把箭头从旧目标身上摘掉（`:267-270`）⇒ 这里必须一起摆，
	## 不然挂机停了、箭头还钉在最后一只怪头上。
	_摆头顶箭头(_view_target, false)
	_view_target = null


func get_nearest_enemy(center: Vector2, radius: float, avoid_boss := false) -> Node2D:
	var nearest: Node2D
	var best_distance := radius
	for entity in _entities:
		if not is_instance_valid(entity) or entity.kind != "m" or not entity.alive:
			continue
		if avoid_boss and _is_boss(entity):
			continue
		var distance := entity.global_position.distance_to(center)
		if distance < best_distance:
			best_distance = distance
			nearest = entity
	return nearest

func _is_boss(actor: CombatActor) -> bool:
	if bool(actor.get_meta("activity_boss", false)):
		return true
	var actor_name := str(actor.get("display_name"))
	return "BOSS" in actor_name.to_upper() or "首领" in actor_name

func _connect_backend_signals() -> void:
	if _backend == null:
		return
	_backend.player_spawned.connect(_on_server_player_spawned)
	_backend.player_removed.connect(_on_server_player_removed)
	_backend.player_moved.connect(_on_server_player_moved)
	## 别人出招 ⇒ 让**他那具身体**播出手动作（用户 2026-10-14 报：特效能看到、人直板板站着）。
	_backend.player_cast.connect(_on_server_player_cast)
	_backend.monster_spawned.connect(_on_server_monster_spawned)
	_backend.monster_removed.connect(_on_server_monster_removed)
	_backend.monster_killed.connect(_on_server_monster_killed)
	_backend.monster_moved.connect(_on_server_monster_moved)
	_backend.monster_attacked.connect(_on_server_monster_attacked)
	_backend.monster_damaged.connect(_on_server_monster_damaged)
	_backend.monster_skill_hit.connect(_on_server_monster_skill_hit)
	_backend.monster_hp_changed.connect(_on_server_monster_hp_changed)
	_backend.npc_spawned.connect(_on_server_npc_spawned)
	_backend.map_drop_spawned.connect(_on_server_drop_spawned)
	_backend.map_drop_removed.connect(_on_server_drop_removed)
	_backend.player_damaged.connect(_on_server_player_damaged)
	## 201/202/1329/1330：旁观端那一侧的状态图标、PVP 伤害数字、别人头顶的血条。
	## ⚠ 这四条**只有在线才有**（离线没有服务端发帧）⇒ 离线门只能验"分派与解析"，
	##   真帧驱动的那一支由 `测试/外来帧表现回归测试.gd` 用**服务端原文**喂 `_handle_bridge_text` 来判。
	_backend.foreign_buff_received.connect(_on_foreign_buff)
	_backend.foreign_buff_cancelled.connect(_on_foreign_buff_cancelled)
	_backend.player_damage_by_player_received.connect(_on_pvp_damage)
	_backend.player_hp_received.connect(_on_player_hp)
	_backend.party_member_stats_received.connect(_on_party_member_stats)
	## 1291:2 连斩阶段 ⇒ 人物脚下那圈光环（原版 `LianzhanHandler.as:77-97`：是**自己**才动 buff + 挂光环，
	## 是别人就只给那个人挂光环）。本工程目前只接"自己"那一支 ⇒ 别人（远程玩家）那支记在未收口。
	_backend.lianzhan_stage_changed.connect(_on_server_lianzhan_stage)
	if _backend.has_signal("char_look_changed"):
		_backend.connect("char_look_changed", _on_server_char_look)
	## 513 到 → 头顶那枚立刻重挂。原版是 `NPCHandler.as:133-140` 收到那一行就同时
	## `NPC.setQuestStatus()` + `SmallMapHandler.setNpcStatus()`；本工程小地图那边有 0.5 秒轮询
	## 兜着，头顶这边以前只有「生成时」与「点过一次之后」两个时机 ⇒ 进图时状态包晚到、
	## 或交付后服务端重推，头顶都不动（用户 2026-10-09 实机报的两条都是这一处）。
	_backend.npc_quest_status_updated.connect(_refresh_quest_markers.unbind(2))
	## 打坐/双修每涨一层心法熟练度 ⇒ 角色头顶一行蓝字（`DataCenter.as:1587`）。
	## 右下角那一行是同一句里的另一件事，走 `获得提示` 信号（`后端连接._apply_skill` 里发）。
	_backend.心法熟练度增加.connect(_on_心法熟练度)
	## 属性帧那一族的头顶飘字（精华/经验/攻防/上下限/罪恶值 + 查克拉那一档不吃 5 秒抑制）
	_backend.属性飘字.connect(_on_属性飘字)
	if _backend.has_signal("guild_state_received"):
		# 家族标示（头顶族徽 + `[家族]<族名>`）的数据源。⚠️ 不要 `.unbind(1)`：
		# `_on_guild_state_received` 本来就吃信号那一个参数。
		_backend.guild_state_received.connect(_on_guild_state_received)
	if _backend.has_signal("map_flag_changed"):
		# ⚠️ **不要 `.unbind(1)`**：`_on_map_flag_changed` 本来就吃信号那一个参数，
		#    unbind 之后再调就会 `Method expected 1 argument(s), but called with 0.`
		#    （连接是成功的、一触发就报错 —— 2026-10-11 族旗不出现就是这么卡的）。
		#    本工程 `.unbind(n)` 只用于"处理函数参数比信号少 n 个"的场合。
		_backend.map_flag_changed.connect(_on_map_flag_changed)
	# ⚠️ 还要跟族旗**表**：本机服务端插旗成功后只重发 `1815:0`（表），**不发** `1815:1`
	#    （`fake_flash_server.handle_map_flag_action` 动作 1 末尾只有 `_send_map_flag_list()`），
	#    而原版的"地图上立旗"是走 `1815:1` 的（`MapFlagProcessor.as:20-41`）。
	#    ⇒ 站在图里插旗时若不跟表，旗要等**重新进图**才出现（用户 2026-10-11 报的就是这个）。
	#    这里从表里把"本图那一行"补出来，服务端一行都不用改。
	if _backend.has_signal("flag_list_received"):
		_backend.flag_list_received.connect(_on_flag_list_changed)
	## 八门「开通穴道」的读秒（`Character.tickMaiDelay:290-328`）：原版在**人物身上**
	## 每秒换一枚 `ColorNumber(剩余秒, NoBlue0)`，不是只在人物窗里做文章
	## （`Client.onMaiDelayExplode` 那半边只是把人物窗藏起来）。信号只在 `1290:1` 出现，
	## 而那一帧**只在成功时发**（服务端 `_attempt_mai_point` 失败支直接回结果帧）。
	if _backend.has_signal("八门倒计时"):
		_backend.八门倒计时.connect(_on_八门读秒)
	## 别人的忍术境界总层数（`1348`，原版 `Character.setTotalSkillLevel` 也管别人）。
	if _backend.has_signal("他人忍术境界收到"):
		_backend.他人忍术境界收到.connect(_on_他人忍术境界)
	## 头顶那摞榜单徽记（`1346` cmd 0）。自己那份登录就推，别人那份在有人开排行榜时广播。
	if _backend.has_signal("榜单徽记收到"):
		_backend.榜单徽记收到.connect(_on_榜单徽记)


func _on_榜单徽记(角色号: int, _榜号列表: Array) -> void:
	## 参数不看，画的时候一律回读 `authoritative_ranking_titles` —— 字典才是那一份权威，
	## 传进来的数组只是"这一格变了"的提示（同 `_on_他人忍术境界` 那条口径）。
	var 演员: Variant
	if _backend != null and 角色号 == int(_backend.get("character_id")):
		if not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group("player") as Node2D
		演员 = _player
	else:
		演员 = _remote_players.get(角色号)
	if is_instance_valid(演员):
		_刷榜单徽记(演员 as Node2D, 角色号)


func _on_他人忍术境界(角色号: int, 总层数: int) -> void:
	var 演员 = _remote_players.get(角色号)
	if is_instance_valid(演员):
		_刷远程境界图标(演员 as Node2D, 总层数)


## 远程玩家头顶那枚忍术境界图标（`Character.setTotalSkillLevel`）。
## 与自家的 `_刷忍术境界图标` 同一套图/档/缩放，只是**摆在那个人自己的名字行上**：
## `_statusIconPane.y = _namePane.y`（`Character.as:1501`），单枚时 `x = -10`。
func _刷远程境界图标(角色: Node2D, 总层: int) -> void:
	if not is_instance_valid(角色):
		return
	var 档 := -1
	for i in 忍术境界门槛.size():
		if 总层 >= int(忍术境界门槛[i]):
			档 = i
	var 图节点 := 角色.get_node_or_null("SkillJingJieIcon") as Sprite2D
	var 框 := 角色.get_node_or_null("SkillJingJieIconFrame") as Sprite2D
	if 档 < 0:
		if 图节点 != null:
			图节点.queue_free()
		if 框 != null:
			框.queue_free()
		return
	var 路 := 忍术境界图标 % 档
	if not ResourceLoader.exists(路):
		if 图节点 != null:
			图节点.queue_free()
		if 框 != null:
			框.queue_free()
		return
	if 图节点 == null:
		图节点 = Sprite2D.new()
		图节点.name = "SkillJingJieIcon"
		图节点.centered = false
		角色.add_child(图节点)
	图节点.texture = load(路) as Texture2D
	图节点.scale = Vector2.ONE * (族徽边长 / 忍术境界原边长)
	var 名牌 := 角色.get_node_or_null("Nameplate") as Label
	图节点.visible = 名牌 == null or 名牌.visible
	var 框图 := 家徽图脚本.取底框()
	if 框图 == null:
		if 框 != null:
			框.queue_free()
		return
	if 框 == null:
		框 = Sprite2D.new()
		框.name = "SkillJingJieIconFrame"
		框.centered = false
		角色.add_child(框)
	框.texture = 框图
	框.visible = 图节点.visible
	var 锚y := 名字相对脚点 + 世界名字行高 + 名牌行距缝
	if 名牌 != null:
		锚y = 名牌.position.y + _行高(名牌) + 名牌行距缝
	var 左 := -10.0
	框.position = Vector2(左, 锚y)
	# 框在图标**下面**（树序）；只在真的排在后面时才挪（`move_child` 摘了再插）。
	var 图下标 := 图节点.get_index()
	if 框.get_index() > 图下标:
		角色.move_child(框, 图下标)
	图节点.position = Vector2(左, 锚y) + Vector2.ONE


## 头顶那摞"忍云"榜单徽记（`Character.updatePaiHangTitle:1184-1203` + `PaiHangTipPane.redraw:22-46`）。
## 数据只有一份来源：`后端连接.authoritative_ranking_titles`（`1346` cmd 0 那个字典），
## 这里**只读不存** ⇒ 谁先到谁后到都不怕漏：信号来了刷一次、角色建好再刷一次，
## 两次都是拿字典当前值重画，幂等。
func _刷榜单徽记(演员: Node2D, 编号: int) -> void:
	if not is_instance_valid(演员):
		return
	var 榜号: Array = []
	if _backend != null:
		var 全表 = _backend.get("authoritative_ranking_titles")
		if 全表 is Dictionary:
			var 那份 = (全表 as Dictionary).get(编号)
			if 那份 is Array:
				榜号 = 那份 as Array
	var 板 := 演员.get_node_or_null("PaiHangPane") as Node2D
	if 榜号.is_empty():
		# 原版空表那条是 `removeChild(_paihangTipPane)`（`Character.as:1186-1191`）⇒ 整摞摘掉。
		if 板 != null:
			板.queue_free()
		return
	if 板 == null:
		板 = Node2D.new()
		板.name = "PaiHangPane"
		演员.add_child(板)
	板.position = Vector2(0, 忍云板相对脚点)
	## 重画 = 先把上一摞**摘出树**再释放：只 `queue_free` 的话它们这一帧还挂在树上，
	## 下面的 `add_child` 会把新徽记插到旧的后头，量测门当场读到一摞双份。
	for 旧 in 板.get_children():
		板.remove_child(旧)
		旧.queue_free()
	var 个数 := 榜号.size()
	for 序号 in 个数:
		var 图 := _榜单徽记图节点(int(榜号[序号]))
		if 图 == null:
			continue
		## `PaiHangTipPane.redraw:41` 只写 `y = -(长度-1-序号)*28` ⇒ **数组最后一枚在最下面**
		## （贴着板原点），越靠前越高。x 一个字都不写 ⇒ 横向由注册点决定（见 `忍云注册点y`）。
		var 宽 := 图.texture.get_width()
		图.position = Vector2(-float(宽) * 0.5,
				-float(个数 - 1 - 序号) * 忍云行距 - _忍云注册点y(宽, 图.texture.get_height()))
		板.add_child(图)
	## 徽记跟名字同隐同显（`Character.setNamePaneVisibleExNamePane:2803-2822` 把
	## `_paihangTipPane` 列在那张数组里）。
	var 名牌 := 演员.get_node_or_null("Nameplate") as Label
	板.visible = 名牌 == null or 名牌.visible


## 一枚徽记的图节点；榜号查不到图（表里没这行、或素材没直解）就返回 null ⇒ 那一格空着，
## 不拿别的图顶上（原版 `PicTool.getPaiHangIcon` 查不到就是 `return null`，
## `PaiHangTipPane:31-33` 拿到 null 再退 3V3 那张，还是 null 就 `if(_loc3_)` 跳过不摆）。
func _榜单徽记图节点(榜号: int) -> Sprite2D:
	var 图名 := _榜单徽记图名(榜号)
	if 图名.is_empty():
		return null
	var 路 := 忍云徽记图 % 图名
	if not ResourceLoader.exists(路):
		return null
	var 图 := Sprite2D.new()
	图.name = "PaiHangBadge_%d" % 榜号
	图.centered = false
	图.texture = load(路) as Texture2D
	return 图


## 榜号 → 图名：`Etc.PaiHangBang[榜号].iconLink`，查不到退 `Etc.PaiHangBang_Hide[榜号-30]`。
## 口径同 `PicTool.getPaiHangIcon:175-187` / `getPaiHang3V3Icon:335-347`（两张表都是
## `ObjectAccessor.getFromObject(表, [键, "iconLink"])`，键是**十进制字符串**）。
func _榜单徽记图名(榜号: int) -> String:
	if GAME_DATA == null:
		return ""
	var 表: Dictionary = GAME_DATA.取表("原版杂项")
	var 直取 := _取iconLink(表.get("PaiHangBang"), 榜号)
	if not 直取.is_empty():
		return 直取
	return _取iconLink(表.get("PaiHangBang_Hide"), 榜号 - 30)


func _取iconLink(段: Variant, 键: int) -> String:
	if not (段 is Dictionary):
		return ""
	var 行 = (段 as Dictionary).get(str(键))
	if not (行 is Dictionary):
		return ""
	return String((行 as Dictionary).get("iconLink", ""))


## 注册点相对 PNG 左上角的 y（见 `忍云注册y` 那段账）。表里没的宽度 ⇒ 退成"画布底边"，
## 也就是把这枚当成普通的下中注册；门 ⑤ 会把 25 张的宽度全钉在 {141,143} 上，
## 真进来了新宽度是**门红**，不是这里静默兜掉。
func _忍云注册点y(宽: int, 高: int) -> float:
	return float((忍云注册y as Dictionary).get(宽, 高))


func _on_八门读秒(秒: int) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player != null and _player.has_method("开始八门读秒"):
		# `1290:1` 的第 4 个字段 `lastPt` 决定归零时爆点的大小（最后一枚放大），
		# 后端把它存进权威状态（和秒数同帧），这里取回来一起交给人物。
		var 最后一点 := false
		if _backend != null:
			var 状态: Dictionary = (_backend.get("authoritative_cultivation") as Dictionary).get("八门", {}) as Dictionary
			最后一点 = bool(状态.get("countdown_last_point", false))
		_player.call("开始八门读秒", 秒, 最后一点)
	# 暗幕/震屏不在原版这条链里 —— 震屏在**归零那一下**（`addExploreEffect` 末尾
	# 的 `API.world.earthquake()`），由人物那边放，所以这里只起读秒。

func _hydrate_server_entities() -> void:
	for state in _backend.map_players.values():
		if _state_matches_current_map(state):
			_on_server_player_spawned(state)
	for state in _backend.map_monsters.values():
		if _state_matches_current_map(state):
			_on_server_monster_spawned(state)
	for state in _backend.map_npcs.values():
		if _state_matches_current_map(state):
			_on_server_npc_spawned(state)
	for state in _backend.map_drops.values():
		if _state_matches_current_map(state):
			_on_server_drop_spawned(state)

## 远程玩家的层带 = 和角色**同一套** `地表.角色z()` 的基准值，**不加任何偏移**。
## ★ 10-17 改口径：以前这里 `+1` 拿平手位（"后进图的压住先进图的"那条原版语义），
## 结果用户实机报"两个角色叠在一起时看不见自己" —— 他要的是**自己永远在最上层**。
## 那条现在挪到本地那一头：`玩家.gd` 的 `z_index = 角色z(...) + 1`（攀爬那一档同改）。
## 于是同格重叠时严格 本地 > 远程 ≥ 怪物/NPC/掉落（它们都是基准值，靠树序分先后）。
## 边界：`渲染配置.角色z` 的 `层内序` 夹在 0..255、角色带是层内 256..511 ⇒ 远程这一头
## 现在**不会**顶到下一层的 0 号位（旧 +1 有这条风险，去掉之后反而更安全）。
func _远程角色层次(位置: Vector2, 动作: int = 0) -> int:
	## ⚠ **爬到梯子/绳子上的人不在落脚点上**：原版 `AbstractPhysicObject.tikcLayer` 给攀爬角色进的是
	## 绳子自己那一层（`getALayer(currLadderRope.page)`，比地形层高 ⇒ 不会被梯子美术盖住）。
	## 本地玩家那一头早就是这条（`玩家.gd` 攀爬那一支），远程这一头以前只按 y 算层 ⇒ 爬到一半
	## "图层显示不对"（用户 2026-10-14 实机报的第一半）。这里取的是**同一张梯子表**
	## （`LadderRoot.get_ladder`，与本地玩家同一个实现），不在工程里抄第二份判定。
	if 动作 == 4 or 动作 == 5:
		var 爬 := _攀爬物(位置)
		if not 爬.is_empty():
			return RenderProfile.角色z(int(爬.get("page", 0)), 200)
	return _角色层次(位置)

## 这一格里那根梯子/绳子（没有就空字典）。口径与本地玩家完全同源，不另写一份命中判定。
func _攀爬物(位置: Vector2) -> Dictionary:
	var 根 = get_parent().get_node_or_null("LadderRoot")
	if 根 == null or not 根.has_method("get_ladder"):
		return {}
	return 根.call("get_ladder", 位置.x, 位置.y, "")

func _state_matches_current_map(state: Dictionary) -> bool:
	return int(state.get("map_id", -1)) == int(_get_current_map_id())

func _on_server_player_spawned(state: Dictionary) -> void:
	if _backend == null or not bool(_backend.get("in_game")) or not _state_matches_current_map(state):
		return
	var remote_id := int(state.get("character_id", 0))
	if remote_id <= 0 or remote_id == int(_backend.get("character_id")):
		return
	_on_server_player_removed(remote_id)
	var actor := Node2D.new()
	actor.name = "远程玩家_%d" % remote_id
	## ⚠ 层带必须显式设，否则"看得见点不着、但屏幕上没有他"（用户 2026-10-14 实机）。
	## 以前这里什么都不设 ⇒ 远程玩家恒为 z=0，而本地玩家/怪物/装饰物都在
	## `层号*512 + 256 + 层内序` 那一档 ⇒ 别人被地面与装饰物整个埋掉。见 `_远程角色层次`。
	actor.position = Vector2(float(state.get("x", 0)), float(state.get("y", 0)))
	actor.z_index = _远程角色层次(actor.position, int(state.get("movement_action", 0)))
	add_child(actor)
	var sprite := OriginalSpriteScript.new()
	actor.add_child(sprite)
	var face_id := str(int(state.get("face", 1))).pad_zeros(8)
	if not sprite.configure("character", face_id, "stand"):
		sprite.configure("character", "00000001", "stand")
	sprite.set_direction(int(state.get("direction", 1)))
	## 第一眼就要在他那一刻的动作上（打坐的人刚进图就该是坐着的，不是站着）。
	_播远程动作(actor, state, false)
	var remote_name := String(state.get("name", "")).strip_edges()
	if remote_name.is_empty():
		remote_name = str(remote_id)
	_create_nameplate(actor, remote_name, sprite, Color.WHITE, 名字相对脚点, 玩家NPC名字描边)
	_attach_selection_marker(actor)
	_add_remote_player_interaction(actor, sprite, state)
	_apply_remote_player_visibility(actor)
	演员编号(actor, remote_id)
	_攻击身份(actor, remote_id, state)
	_remote_players[remote_id] = actor
	# 已知总层数就直接摆（`1348` 一般紧跟生成帧到，重进图时也可能先有记录）。
	if state.has("总层数"):
		_刷远程境界图标(actor, int(state.get("总层数", 0)))
	## 头顶那摞榜单徽记同源：`1346:0` 可能比这个人**先进图**就推过（我后来才看见他），
	## 所以建完人立刻按字典补画一次，不等下一帧。
	_刷榜单徽记(actor, remote_id)

## 给远程玩家那具**裸 Node2D** 补上攻击链要读的三样身份（#352）。
## 为什么要单独补：`_on_server_player_spawned` 建的是 `Node2D.new()`，既没有 `kind`
## 也没有 `alive`/等级，而
##  * 怪那四条谓词按 `entity.kind != "m"` 把人整个剔掉（打人链的门禁 #1），
##  * `PVP判定` 要**双方等级**才走得完 `pkLevel=45` 那两道闸（门禁 #2），
## 所以出手那一拍必须能从节点本身取到"他是谁 / 几级 / 还活着吗"。
## ⚠ meta 键一律 **ASCII** —— 中文 meta 键存不进去（Godot 4 的 metadata 键要合法标识符，
## 静默失败，同 `_置隐身` 与 `演员编号:846` 那条注）。
func _攻击身份(演员: Node2D, 角色号: int, state: Dictionary) -> void:
	演员.set_meta("pk_char_id", 角色号)
	## 等级：162 出场帧就带（`后端连接._handle_spawn_player_text:4196` 的 `level`
	## = 报文体第 19 段，实测 `map_players` 那份 state 里就有 `level` 这个键）⇒ 直接取它，
	## 取不到才给 0（0 < pkLevel=45 ⇒ 判"对方处于新手保护"，**宁可不给出可打**）。
	演员.set_meta("pk_level", int(state.get("level", 0)))
	## 服务端到现在**没有**"别人死了"这一帧（死亡的人是靠 163 离场帧撤掉的，
	## 见 `_on_server_player_removed`）⇒ 这一格建的时候置真、离场随节点一起消失，
	## 等真有一帧能告诉我们 `isDead` 再在这里翻。
	演员.set_meta("pk_alive", true)
	## 家族名（同族闸要用）：同样是 162 那一份（`fields[23]`），没家族服务端发字面 `-`。
	## ⚠ 这是**出场帧的快照**，他中途退族/入族我们收不到 ⇒ 记为未决（#352）。
	演员.set_meta("pk_family", str(state.get("family_name", "")).strip_edges())

## 演员节点上只挂一个 ASCII 键的编号（中文 meta 键存不进去，见 `_远程出招中` 的注）。
func 演员编号(演员: Node2D, 编号: int) -> void:
	演员.set_meta("remote_id", 编号)


func _on_server_player_removed(remote_id: int) -> void:
	var actor = _remote_players.get(remote_id)
	if is_instance_valid(actor):
		if actor == _selected_character:
			_clear_selected_character()
		actor.queue_free()
	_remote_players.erase(remote_id)

func _on_server_player_moved(state: Dictionary) -> void:
	var 编号 := int(state.get("character_id", 0))
	var actor = _remote_players.get(编号) as Node2D
	if actor == null:
		return
	var sprite := actor.get_child(0) as Node2D
	if sprite != null:
		sprite.call("set_direction", int(state.get("direction", 1)))
	var 目标 := Vector2(float(state.x), float(state.y))
	## 层带跟着位置走（本地玩家是每帧在 `玩家.gd:875` 自己刷的，远程玩家没人刷就会
	## 一直停在生成那一刻那一档，走到别的落脚点还被原来的地面压住）。
	actor.z_index = _远程角色层次(目标, int(state.get("movement_action", 0)))
	_播远程动作(actor, state, 目标.distance_squared_to(actor.position) > 1.0)
	## ⚠ **不再用 tween 追点**：以前每收一包 `create_tween()` 补间 0.1 秒到"上一个已知点"，
	## 补完就**停住等下一包** ⇒ 实测 178 帧里有 57 帧（32%）那个人完全没挪，肉眼就是
	## "走一下停一下"（用户 2026-10-14："原版的延迟我肉眼分辨不出来"）。
	## 原版是把移动片段塞进那个角色自己的控制器逐帧走（`Client.onMovePlayer` →
	## `CommandController.addMovements` + `tick()`）⇒ **没收到新包的时候他还在按上一段的速度往前走**。
	## 现在同一套：这里只记账，逐帧推进在 `_推进远程玩家()`（`_process` 每帧调）。
	var 现在 := Time.get_ticks_msec()
	var 上一条 = _远程外推.get(编号)
	var 速度 := Vector2(float(state.get("velocity_x", 0)), float(state.get("velocity_y", 0)))
	if not state.has_all(["velocity_x", "velocity_y"]) and 上一条 != null:
		## ⚠ **判"没给速度"只能看字段在不在，不许看值等不等于 0**（10-15 冻帧尺子抓出来的）：
		## 松手那一包的速度**本来就是 (0,0)**，按值判就把"他停了"当成"字段缺失"，
		## 再拿位移反推出一个 −125 的爬梯速度塞回去 ⇒ 旁观端在他停手之后还接着往上冲、
		## 腿接着蹬几帧（实测 frame_index 在松手后 194/312/491 毫秒各变一次，
		## 全部落在外推条目还活着的那 0.45 秒里，条目一注销才冻住）。
		## 后端 `后端连接.gd:2941-2942` 两条速度字段**一直都给**，所以这个分支只兜"老形状"。
		var 隔秒 := float(maxi(33, 现在 - int(上一条.get("收包时刻", 现在)))) / 1000.0
		速度 = (目标 - (上一条.get("目标") as Vector2)) / maxf(0.033, 隔秒)
	_远程外推[编号] = {"目标": 目标, "速度": 速度, "收包时刻": 现在, "动作": int(state.get("movement_action", 0))}


## 一帧该挪多少：**就是那条 `x += velocity.x * dt/1000`**（原版
## `AbstractPhysicObject.applyVelocity:523`）。⚠ 只有**跳 / 爬梯 / 爬绳**才按 y 的速度积分：
## 平地走时本地那具身体的 `velocity.y` 是重力每帧刷出来的小值，跟着积分会一路往下掉。
## ⚠ **跳跃是匀加速、不是常速**（10-15 用户"跳跃看起来一抖一抖"的第二半）：上一版对动作 2
## 也按 `速度.y × 秒` 常速推，而真身那一头每帧 `velocity.y += gravity × delta`
## （`玩家.gd:1093`）⇒ 两边算的**不是同一条曲线**，旁观端要么冲过头、要么被下一包的绝对 y
## 硬拽回来，一来一回就是"抖"。原版敢只发起跳与落地两包（`Sampler.as:87-90` 明确把
## "跳跃时只有 VELOCITY 脏"排除掉 ⇒ 中途根本不纠偏），靠的就是收端那具身体跑**同一条抛物线**。
## 重力常数从 `玩家.gd` 取，这里不抄第二份。
func _远程每帧位移(速度: Vector2, 动作: int, 秒: float, 起算秒: float = 0.0) -> Vector2:
	var 竖 := 0.0
	if 动作 == 4 or 动作 == 5:
		竖 = 速度.y * 秒		## 爬梯/爬绳：匀速，没有重力项
	elif 动作 == 2:
		竖 = (速度.y + 跳落.重力 * 起算秒) * 秒 \
				+ 0.5 * 跳落.重力 * 秒 * 秒
	return Vector2(速度.x * 秒, 竖)


## 逐帧推进远程玩家。
##
## ⚠ **口径来自原版两处**（2026-10-14 第二版；第一版是"指数追一个总在身后的期望位"，
## 被用户实机顶回来"延迟还是很大"）：
##   · `CommandController.as:31-68` 收到一条移动片段做的是
##     `_target.x = 片段.position` + `_target.setVelocity(片段.pixelsPerSecond)`；
##   · 之后那段位移**根本没有再等网络** —— 是那个角色自己的物理
##     `applyVelocity()`（`AbstractPhysicObject.as:513-548`）`x += velocity.x * dt/1000`
##     逐帧积分出来的。
## ⇒ 旁观者与真身用的是**同一条积分式**，两边每帧挪得一样多，稳态误差只剩
##   「单程网络时间 × 速度」（在线用例实测单向 7 毫秒 ⇒ 240 像素/秒时约 1.7 像素）。
##   这就是原版"肉眼看不出延迟"的全部秘密：不是它延迟低，是**收端不追点、自己走**。
## ⚠ 速度是**像素/秒**（服务端原样转发的 `velocity.x`），每帧位移要乘 `帧长`；
##   把 像素/秒 当 像素/帧 用会一步跨过 40 像素再倒回来（本轮踩过，平滑度尺子当场
##   量出 149 个反向帧）。
func _推进远程玩家(帧长: float) -> void:
	if _远程外推.is_empty():
		return
	var 现在 := Time.get_ticks_msec()
	for 编号 in _远程外推.keys():
		var actor: Node2D = _remote_players.get(编号) as Node2D
		if actor == null:
			远程外推删除(编号)
			continue
		var 态: Dictionary = _远程外推[编号]
		var 目标: Vector2 = 态.get("目标", actor.position)
		var 速度: Vector2 = 态.get("速度", Vector2.ZERO)
		var 过了: float = float(现在 - int(态.get("收包时刻", 现在))) / 1000.0
		var 动作 := int(态.get("动作", 0))
		var 在走: bool = 动作 in [2, 3, 4, 5] and 过了 < 0.45
		## ⚠ **外推窗口按动作分档**（10-15 的"停手尺子"量出来的）：走路 400 像素/秒、包间隔 100 毫秒，
		##   不给 0.2 秒的窗口就会在"一帧攒两包"时把人冻住（就是上面那段历史）；但**爬梯/爬绳只有
		##   125 像素/秒、而且是"手一松就停"、没有惯性** —— 同样 0.2 秒的窗口意味着松手包稍晚到一点，
		##   就先往上多冲 25 像素再倒回来。实测 26.6 像素 ≈ 封顶值本身，肉眼正是用户那句
		##   "我这边已经停止运动了，但他那边还动了一下"。
		var 外推上限 := 0.05 if (动作 == 4 or 动作 == 5) else 0.2
		## 期望位 = 采样点 **按采样里那个速度往前走过了 过了 这么久**（原版就是这条积分）。
		## ⚠ 上限 0.2 秒 = 两个采样周期。第一版压成 0.1 秒：本机两扇窗一起跑、收端一帧里
		##   攒下两包时，第二包晚到 30 毫秒他就**冻在原地**、下一包到了再往前蹦 —— 肉眼正是
		##   "延迟很大 + 一顿一顿"。放开到 0.45 秒又会在"对端停了但那包迟了"时多冲一百多像素
		##   再倒回来。0.2 是这两头的折中。
		var 积 := Vector2.ZERO
		if 在走:
			积 = _远程每帧位移(速度, 动作, minf(过了, 外推上限))
		var 期望: Vector2 = 目标 + 积
		## ⭐ **旁观端也要踩落脚点**（10-15 用户报"对面落下像踩在棉花上、还会弹一下"）。
		## 本地那具身体每帧都吸附到平台面（`玩家.gd:1120-1129`），上一版这边**只有抛物线
		## 积分、没有吸附**：下降末速可到 670 像素/秒，而外推窗口封顶 0.2 秒 ⇒
		## `期望.y` 能穿到平台面**下方** 160 像素（670×0.2 + 0.5×2000×0.04），人先扎进地面，
		## 等"已落地"那一包（y=地面、vy=0）到了再一把拽回来 ⇒ 肉眼看到的就是一次回弹。
		## 参照高度取 **采样点 y** 而不是本帧的 y：采样点是本地身体真实站过的位置，一定在
		## 台面之上，量出来的面是"要落的那一层"；用已经穿下去的 y 去查会直接跳到更下面一层。
		var 面 := INF
		if 动作 == 2 and 速度.y >= 0.0:
			var 脚点 = get_parent().get_node_or_null("Footholds")
			if 脚点 != null:
				面 = float(脚点.call("find_foothold", actor.position.x, 目标.y, "").get("y", INF))
		if 面 != INF and 期望.y > 面:
			期望.y = 面
		## ⚠ **两段分开走，这才是原版的形状**：
		##   ① **本地积分**：`actor += 速度 × 帧长` —— 原版 `applyVelocity()`
		##      （`AbstractPhysicObject.as:523` `x += _velocity.x * dt / 1000`）每帧就是这么算的，
		##      `CommandController` 收到片段只负责把速度交回那具身体（`:56` `setVelocity`）。
		##   ② **慢慢对齐到解析期望位**：收包那一拍的误差（包迟到、帧率抖、他撞墙了）按 30/秒
		##      抹掉，不当帧弹一下。
		## 上一版只有②、没有① ⇒ 稳态永远欠 `速度 ÷ 收敛率`（400÷18 ≈ 22 像素 ≈ 55 毫秒），
		## 用户看到的"延迟"就是这笔欠账；有了①，两边每帧挪得一样多，欠账归零。
		if 期望.distance_to(actor.position) > 200.0:
			actor.position = 期望		## 传送门/换图/连掉几包 ⇒ 直接落位，别慢慢飘
		else:
			if 在走:
				## 起算秒 = 已经从采样点推进了多久（跟期望位用**同一个封顶值**，
				## 不然跳跃那条抛物线会积到 0.2 秒之外去、比期望位还靠前）。
				actor.position += _远程每帧位移(速度, 动作, 帧长, minf(过了, 外推上限))
			var 误差: Vector2 = 期望 - actor.position
			if 误差.length() > 0.5:
				## 30/秒（2026-10-14 用户点头再提速一档）：把"晚看到"的最大值从 55 毫秒压下来。
				## ⚠ 这**不是**回到上一版那种"永远在追"—— 那条路的毛病是**没有①那段积分**，
				## 稳态永远欠 `速度 ÷ 速率`（400÷18≈22 像素）。有了①，速率只决定"迟到包造成的
				## 那几像素多久抹平"，越快越接近原版的硬对齐（原版 `CommandController:46-47`
				## 收到片段直接 `_target.x = 片段.position`，比我们更硬）。
				actor.position += 误差 * minf(1.0, 30.0 * 帧长)
			## ⚠ **期望位与这具身体自己两面都要夹**：上面只夹住了期望位，可身体每帧还在
			## 自己积分（① 那段 `actor += 位移`），一帧就能越过台面十几像素（600 像素/秒
			## × 16.7 毫秒 + 重力项），再靠 30/秒 慢慢拽回来 ⇒ 用户看到的还是那一下回弹。
			## 在线门第一次跑这条实测穿 26.36 像素（10-15），就是漏了这里。
			if 面 != INF and actor.position.y > 面:
				actor.position.y = 面
		var 差: Vector2 = 期望 - actor.position
		if 差.length() > 0.4 or 在走:
			actor.z_index = _远程角色层次(actor.position, 动作)
		if 在走:
			## ⚠ `velocity_y` 必须带上：`_播远程动作` 里"爬着不动⇒冻第 0 帧"那条判据读的就是它，
			## 而这里以前只传 `{"movement_action": 动作}` ⇒ `帧.get("velocity_y", 0)` 恒 0 恒真 ⇒
			## **正在爬的人也永久冻在梯子第一帧**：位置每帧在动、画面一动不动，肉眼读出来的
			## 就是用户 10-15 报的那句"攀爬从别人视角看延迟很高"。
			_播远程动作(actor, {"movement_action": 动作, "velocity_y": 速度.y}, true)
		elif 过了 >= 0.45 and 差.length() < 0.6:
			## 半秒没有下一包 ⇒ 他真的停了（或掉线）：回站立、注销这条外推。
			## ⚠ 两条都不许急：**不许硬把 position 拽到目标**（一拽就是一帧倒退，
			## 尺子量到 45 像素的单帧跳 + 反向帧），也**不许半路注销**（注销得太早会
			## 永远停在外推点、离真值差几十像素 —— 尺子的"终点误差"量的就是这个）。
			## 上面那句 `actor.position += 误差 * …` 每帧都在把他收回期望位，收拢了才注销。
			## ⚠ **只有"走/跳"停下来才回站立**。爬梯/爬绳/单修坐/双修坐（4/5/7/**8**）
			## 停下来是**挂在原姿势上**：原版收端根本没有"超时算停"这一说（那具身体的
			## movementAction 一设就一直挂着），而本端坐下之后**不再发位移包**（原版"变脏即发"，
			## 我们同一条）⇒ 一律回站立就成了"站在半空中"（用户 2026-10-14 第二半）。
			## ★ 10-17 这一列里**漏了 8** ⇒ 对面那具刚换成 sit1、0.45 秒后就被这里改回 stand，
			## 就是用户实机报的那句「双修时一个站着一个坐着」（两台客户端各自只看得到对面站着）。
			_播远程动作(actor, {"movement_action": 动作 if 动作 in [4, 5, 7, 8] else 1, "velocity_y": 0.0}, false)
			远程外推删除(编号)
			continue


## 双修那一对的"对坐"：进双修那一刻**只摆自己这一具**，之后每帧把本地算出的 y 抄给对面。
## 三条口径都照 `HealHandler.as:398-448` + `CharacterHandler.tickHealDouble:722-760` 抄：
## ① 姿势 `SIT1`（在 `玩家.gd::_播放坐姿` 里每帧重判，别在这里做）；
## ② **自己**站到**中点 ∓ 25**并转身朝向对方 —— 谁在左由**角色号比大小**定
##    （`_loc2_.objectId < _loc3_.objectId`，而 `objectId` 就是角色号，见 `Character.as:1910`）；
##    两边各自算同一个中点、各摆各的 ⇒ 对面那一具的坐标**一格都不许写**。
##    ⚠ 10-17 用户实机报的"另一个角色带着另一个角色走了"就是上一版每帧钉对面 x 造成的：
##    原版 `startHealDouble` 里只有 `_loc2_.setFoothold(...)`，`_loc3_` 只被**读**来算中点
##    （`:421` / `:432` 两处 `(_loc3_.x + _loc2_.x) / 2`），它怎么站由**他自己的客户端**摆。
## ③ 之后每帧 `_loc3_.y = param1.y`（`CharacterHandler.as:754`）⇒ 两个人一起浮。
##    ⚠ 抄的是 `position.y` 而**不重算层号**：±8 像素不该把两个人推进别的层
##    （与 `玩家.gd` 那条"收了再浮"同一条口径，10-14 那条"飘"的根因就是浮动顺带把 z 改了）。
var _双修摆位伙伴 := 0
## 摆位那一步到底走没走、为什么没走 —— 只给门看的诊断串（红行里直接带出来）。
## 10-17 在线门量到"两人还是 103.5 像素"，光看数字分不出是**没触发**还是**脚点查无**，
## 而这两条的修法完全不同 ⇒ 别再凭猜改，先把当时那一拍的输入打出来。
var 双修摆位诊断 := ""
## 赶路途中那一支的提示（`tickGotoDoubleHeal` 里才会产生 —— 点那一下 UI 还在，
## 走到一半人没了 / 走到位还是不够远 这两句 UI 已经关了，所以先存着给门读）。
var 双修提示 := ""

func _双修对坐() -> void:
	if _backend == null or _player == null:
		return
	var 我状: Dictionary = _backend.get("authoritative_heal")
	var 伙伴号 := int(我状.get("partner_id", 0))
	var 我号 := int(_backend.get("character_id"))
	if int(我状.get("state", 0)) != 2 or 伙伴号 <= 0 or 伙伴号 == 我号:
		_双修摆位伙伴 = 0
		return
	## 这一条只在我这侧成立才敢摆：`远程双修伙伴[伙伴号] == 我号` 说明**他那一侧也已经双修成**，
	## 否则我把他拽到 ∓25、他那边还在按自己的算式摆 ⇒ 两个人隔着一段距离来回挤。
	var 他那状: Dictionary = _backend.get("远程双修伙伴")
	if int(他那状.get(伙伴号, 0)) != 我号:
		_双修摆位伙伴 = 0
		return
	var 演员 = _remote_players.get(伙伴号)
	if 演员 == null or not (演员 is Node2D):
		双修摆位诊断 = "还没建出对面那具节点（伙伴号 %d 不在 _remote_players 里）" % 伙伴号
		return
	if _双修摆位伙伴 != 伙伴号:
		_双修摆位伙伴 = 伙伴号
		_双修摆位(演员 as Node2D, 伙伴号, 我号)
	## 原版这一支只有一句 `_loc3_.y = param1.y`（`CharacterHandler.as:754`）。
	## x 与朝向**一律不碰**：他的 x 由他自己的包决定、朝向由他自己的包带过来
	## （我们 10-17 已补 `36:` 第 8 段 / 187 第 12 段 —— 上一版每帧钉 x 和图省事的
	## "每帧钉朝向"都是在补一个已经不存在的洞，反而把他钉在原地拖不走）。
	(演员 as Node2D).position.y = _player.position.y

## 一次性把**自己**摆到"中点 ∓ 25"并转身朝向对方。
## 对面那一具只用来读 x 算中点 —— 原版 `startHealDouble` 也只写 `_loc2_`（自己）。
## 原版那一步用 `getRushPositionInfo`（沿当前落脚点平移，走不到就停在段端点）；
## 本工程没有那个函数，用同一张脚点表的 `地表.段上落点()` 做等价的一步 —— **不另写一份平移算法**。
func _双修摆位(演员: Node2D, 伙伴号: int, 我号: int) -> void:
	var 脚点 = get_parent().get_node_or_null("Footholds")
	if 脚点 == null:
		双修摆位诊断 = "取不到 Footholds 节点 ⇒ 没法算落脚点，整步没做"
		return
	## ⚠ 不许写 `String(_player.get("current_fh_id"))` —— 元门「点角色不崩」把
	## `String(X.get("键"))`（**没有默认值**那一型）钉成全工程 0 处：取到 null 时 `String(null)` 当场抛，
	## 函数中途死掉。这里改成带类型的直接赋值（`current_fh_id` 在 `玩家.gd` 里恒是 String）。
	var 我的脚点: String = _player.get("current_fh_id")
	var 摆前我x := float(_player.position.x)
	var 摆前他x := float(演员.position.x)
	var 中心x := (摆前我x + 摆前他x) * 0.5
	var 我在左 := 我号 < 伙伴号
	var 我的目标 := 中心x + (-25.0 if 我在左 else 25.0)
	var 我的落点: Vector2 = 脚点.call("段上落点", 我的脚点, 我的目标)
	var 我动了 := false
	if not is_inf(我的落点.x):
		_player.position = 我的落点
		我动了 = true
	双修摆位诊断 = "我号 %d 他号 %d 我在左 %s｜摆前 我 %.1f 他 %.1f ⇒ 中点 %.1f 目标 %.1f" % [
			我号, 伙伴号, str(我在左), 摆前我x, 摆前他x, 中心x, 我的目标] + \
			"｜我脚点「%s」落点 %s 动了 %s（对面那具不摆，由他自己的客户端摆）" % [
			我的脚点, str(我的落点), str(我动了)]
	## 转身：原版 `direction = Direction.RIGHT / LEFT`（`:421` / `:432`）。
	## 本地这一具要连 `facing` 一起改 —— 每帧那段只在 `dir != 0` 时才刷精灵朝向，
	## 坐着不动 ⇒ 光设数据不设皮 = 看着还是背对。
	_player.call("强制朝向", 1 if 我在左 else -1)


## 发得出双修邀请吗 —— 原版 `HealHandler.canRequestDoubleNow:238-243` 两条闸，逐字照抄：
## ① `|Δx| < 40 && |Δy| < 20`；② 发起方自己在 站/走 两态之一、`grounded`、`landed`、有落脚点。
## 这条闸不是"防作弊"，它是**摆位的前提**：`startHealDouble` 摆的是"两人中点 ∓ 25"，
## 隔着一百多像素时那个中点落在空地上，两个人各被夹到自己落脚点的端点上 ⇒ 还是各坐各的
## （10-17 在线门第一次跑就量到 102.5 像素的间距，就是这么来的）。
func 够得着双修(他: Node2D) -> bool:
	if _player == null:
		return false
	if absf(_player.position.x - 他.position.x) >= 40.0 or absf(_player.position.y - 他.position.y) >= 20.0:
		return false
	var 我动作 := int(_player.get("_同步动作"))
	var 我脚点: String = _player.get("current_fh_id")
	return (我动作 == 1 or 我动作 == 3) and bool(_player.get("on_ground")) \
			and not bool(_player.get("climbing")) and 我脚点 != ""

## 点菜单那一行「双修」= 原版 `API.healHandler.requestToDoubleHeal(id)`（`HealHandler.as:374-395`）。
## 三条出口，逐条照抄：已经在双修 → 说一句；找不到那具身体（不在本场景）→ 说一句；
## **离得不够近 → 不是拒绝，是先自动走过去**（`nowGotoDoubleHealId = id; API.player.pathFind(...)`），
## 走到够近那一拍再由 `_推进赶路双修()` 把邀请发出去（`tickGotoDoubleHeal:88-116`）。
## 回**该说的那句提示**（空串 = 已经发出去了、或正在赶路，什么都不必说）。
## 文案是语言表原文（现查 `原版数据.语言`），本工程没有运行时语言表 ⇒ 烘进来 + 注明键名。
func 请求双修(目标号: int) -> String:
	if _backend == null or _player == null:
		return "双修邀请需要在线"
	if int((_backend.get("authoritative_heal") as Dictionary).get("partner_id", 0)) != 0:
		return "你当前正在双修，无法再发起新的双修"		# SHUANGXIU_WARING_TXT
	var 他 = _remote_players.get(目标号)
	if 他 == null or not (他 is Node2D):
		return "玩家与你不在同一场景内，无法与其双修"		# SHUANGXIU_WARING_TXT_1
	if 够得着双修(他 as Node2D):
		_发双修邀请(目标号)
		return ""
	_赶路双修目标 = 目标号
	_player.call("走向", (他 as Node2D).global_position, true, true)
	return ""

func _发双修邀请(目标号: int) -> void:
	## 原版发之前先 `API.player.forceSamplerSend()` —— 把"我此刻在哪、朝哪"立刻补一发，
	## 免得对面按上一包的位置判定"够不够近"。（朝向那一格现在随 `36` 一起带，见 `send_movement`。）
	_backend.call("request_double_heal_invite", 目标号)

## 赶路那一支的每帧检查 = 原版 `tickGotoDoubleHeal:88-116`。
## ⚠ 三条都要判，少一条就是"点了没反应"：路线走完(`!player_nowPathFinding`)要**再判一次距离**
## 并按 `requestToDoubleHealNoPathFind` 那三条出口收尾；路上那人**消失了**要说一句并取消；
## 还没走到但**已经够近**（他朝我走过来）⇒ 当场发、立刻取消赶路，不许继续往前走。
var _赶路双修目标 := 0

func _推进赶路双修() -> void:
	if _赶路双修目标 == 0 or _player == null or _backend == null:
		return
	var 他 = _remote_players.get(_赶路双修目标)
	if 他 == null or not (他 is Node2D):
		_赶路双修目标 = 0
		双修提示 = "玩家已经离开场景，无法双修"		# SHUANGXIU_WARING_TXT_2
		return
	if 够得着双修(他 as Node2D):
		var 号 := _赶路双修目标
		_赶路双修目标 = 0
		_player.call("cancel_auto_path")
		_发双修邀请(号)
		return
	if not bool(_player.get("click_move_active")):
		## 路走完了还是不够近（他也在走 / 中间隔着墙）⇒ 原版走 `requestToDoubleHealNoPathFind`
		## 的第三条出口：说一句"距离过远"，**不再重新一路追过去**。
		_赶路双修目标 = 0
		双修提示 = "该玩家与你距离过远，无法发起双修"		# SHUANGXIU_WARING_TXT_5


func 远程外推删除(编号: int) -> void:
	## 删键要单独走这里：`_process` 里直接改正在迭代的字典会报 `Dictionary modified` 之类。
	_待删外推.append(编号)

## 让"对面那具身体"真的在动。用户 2026-10-14 报的第一条就是这个：以前只补间 position、
## 从不切动作 ⇒ 看别人走路是**直板板地平移**。
## 动作号那张表在 `原始动画精灵.动作名()`（原版 `Action.as:6`，移动与出招共用一套号）。
## `原始动画精灵.play()` 自己带"同名不重播"，所以每 0.1 秒一拍也不会把走路循环打断。
func _播远程动作(演员: Node2D, 帧: Dictionary, 在动: bool) -> void:
	var 精灵 = 演员.get_child(0)
	if 精灵 == null or not 精灵.has_method("play"):
		return
	if _远程出招中.get(int(演员.get_meta("remote_id", -1)), false):
		return		## 出手动作播完之前不被移动帧覆盖（与本地玩家那条 `出手中` 同一条口径）
	var 名 := OriginalSpriteScript.动作名(int(帧.get("movement_action", 0)))
	if 名.is_empty():
		## 动作槽是 0（对端是老形状的发法，或服务端没给）⇒ 只能按"这帧有没有位移"推。
		名 = "walk" if 在动 else "stand"
	if (名 == "ladder" or 名 == "rope") and absi(int(帧.get("velocity_y", 0))) < 1:
		精灵.call("hold_first_frame", 名)	## 爬着不动要冻在第 0 帧（与本地玩家同一条口径）
	elif 精灵.has_method("有动作") and bool(精灵.call("有动作", 名)):
		精灵.call("play", 名)
	else:
		精灵.call("play", "stand")

## 收到 1328（有人出招）⇒ 让那具远程身体播对应的一招。
func _on_server_player_cast(帧: Dictionary) -> void:
	var 编号 := int(帧.get("character_id", 0))
	var 演员 = _remote_players.get(编号) as Node2D
	if 演员 == null:
		return		## 是自己（本地那支在 `玩家.gd._出招()` 里自己播），或者他还没被建出来
	var 精灵 = 演员.get_child(0)
	if 精灵 == null or not 精灵.has_method("play_once"):
		return
	var 名 := OriginalSpriteScript.动作名(int(帧.get("stance", 0)))
	if 名.is_empty():
		## 服务端**自己发起**的那批广播在 stance 槽写死 0（`fake_flash_server.py` 里 9 处 `stance=0`）
		## ⇒ 只能按技能号查同一张出手动作表（和本地 `_出技能动作` 用的 `数据/技能动作.json` 同源）。
		## 取**第一个**而不是随机：原版是出招方 `getSkillStance()` 里 `rnd()` 挑一个再随包发出来，
		## 号没送到时每个旁观者各随机就会各看各的。
		## ⚠ **必须补零到 7 位**：技能号在数据表里的键是 7 位**带前导零**的字符串
		## （`0002000` 这一整段就是世界/家族/奥义那一类忍术），而包里的技能槽是数字 ⇒
		## `str(int(...))` 会把前导零吃掉 ⇒ 查表落空。本地那一头传的一直是 7 位字符串
		## （`玩家.gd:_spawn_skill_effect(skill_id: String)`）、怪物那条 `:723` 也补了零，
		## 所以只有"别人放这些招"看不见光 —— 用户 10-15 报的正是这一族。
		var 候选: Array = GAME_DATA.skill_stance(str(int(帧.get("skill_id", 0))).pad_zeros(7))
		名 = String(候选[0]) if not 候选.is_empty() else "attack"
	## 出手那一刻先朝他打的方向（原版 `AbstractAttackSkill` 在 hitTest 里就把 character.direction
	## 一起打包发出来，旁观者据此转身）。
	精灵.call("set_direction", int(帧.get("direction", 0)))
	## ⚠ **特效不能排在"这具身体播不播得起这一招"后面**（2026-10-14 在线用例 ⑨′ 抓出来的，
	## 用户实机"还是看不到别人释放技能特效"的第二半）：连发两招时第二招落在上一招 attack
	## 还没播完的那一拍，`play_once()` 回 false ⇒ 上一版在这里就 `return` ⇒ **起手特效和
	## 飞行物整条没放**。自动战斗中"上一招没播完就发下一招"是常态，所以看着就是
	## "他光站着、什么特效都没有"。原版两件事本来就是分开的：特效由技能自己的 effect 对象放
	## （`AbstractAttackSkill` 那套），姿态动画只是 `setMovementAction`。
	_放远程技能特效(演员, 帧)
	if not bool(精灵.call("play_once", 名)):
		return
	_远程出招中[编号] = true
	## 播完回当前移动态（`单次` 那套是"播到尾帧停住"，不自己回 stand）。
	var 毫秒 := int(精灵.call("动作时长毫秒", 名))
	get_tree().create_timer(maxf(0.05, 毫秒 / 1000.0)).timeout.connect(_远程出招播完.bind(编号))

## 远程施法者的**技能特效 + 飞行物**（用户 2026-10-14："技能特效只能看到怪物的受击特效"）。
## 本地那一套在 `玩家.gd._spawn_skill_effect()` / `_放飞行物()`：起手特效锚在**施法者脚点**、
## 朝向跟施法者（`AbstractCloseAttackEffect.as:115` `new Point(character.x, character.y)`），
## 有 `ball` 相位的再抛一个飞行物去追目标。这里同一套，只是**不算伤害**（伤害由服务端的
## 243/194 回包说，飞行物到点自己 `queue_free`，不接它的 `命中` 信号）。
func _放远程技能特效(演员: Node2D, 帧: Dictionary) -> void:
	var 号 := int(帧.get("skill_id", 0))
	if 号 <= 0:
		return		## 普攻没有技能特效（原版普攻也不放：`MainLib` 里普攻没有 effect 美术）
	## ⚠ **必须补零到 7 位**：`数据/技能动画元数据.json` 的键是**带前导零的 7 位串**
	## （`0002000`/`0003000`/`0004005` 这一整段 = 世界/家族/奥义那一类忍术，表里**有** effect 与 ball），
	## 而包里的技能槽是数字 ⇒ `str(int(...))` 把前导零吃掉 ⇒ 查表落空 ⇒ 起手特效 `queue_free`、
	## `有相位(球)` 恒假 ⇒ **施法光与飞行物整条静默**，而受击特效是另一条链（走怪物那支、已补零）
	## ⇒ 症状正好是用户 10-15 报的"只能看到受击特效"。
	## 职业号 3001001 恰好 7 位、没有前导零 ⇒ 那一类一直看得见，所以看起来像"只有某些类别坏了"。
	var 技能号 := str(号).pad_zeros(7)
	if _session != null and not bool(_session.game_settings.get("show_skill_effects", true)):
		return
	var 朝向 := int(帧.get("direction", 0))
	if 朝向 == 0:
		朝向 = 1
	var 特效: Node2D = null
	var 起手 := SkillAnimationScript.new() as Node2D
	add_child(起手)
	起手.position = 演员.get_global_position()
	起手.set_direction(朝向)
	if 起手.configure(技能号):
		特效 = 起手
	else:
		起手.queue_free()
	if not SkillAnimationScript.有相位(技能号, "ball"):
		return
	var 目标 := _远程技能目标(帧)
	if 目标 == null:
		return
	var 弹 := 技能飞行物脚本.new() as Node2D
	add_child(弹)
	var 延迟 := SkillAnimationScript.相位参数(技能号, "ball", "ballAfter", 0)
	if not bool(弹.call("配置", 技能号, 演员, 目标, 朝向, 延迟, 特效)):
		弹.queue_free()


## 从 1328 带的目标串里挑**这一帧还活着、且在本端有演员**的第一只（怪优先，其次人）。
func _远程技能目标(帧: Dictionary) -> Node2D:
	for 串 in [String(帧.get("monsters", "-")), String(帧.get("players", "-"))]:
		if 串 == "-" or 串.is_empty():
			continue
		for 段 in 串.split("@", false):
			var 号 := int(段)
			if 号 <= 0:
				continue
			var 演员 = _活演员(号)
			if 演员 != null:
				return 演员
			var 别人 = _remote_players.get(号)
			if 别人 is Node2D:
				return 别人 as Node2D
	return null


func _远程出招播完(编号: int) -> void:
	var 演员 = _remote_players.get(编号) as Node2D
	if 演员 == null:
		return
	_远程出招中.erase(编号)
	var 态 = _backend.map_players.get(编号) if _backend != null else null
	_播远程动作(演员, 态 if 态 is Dictionary else {}, false)

## 服务端事件与 `queue_free()` 之间差着一帧：那一帧里 `_entities_by_object` 还挂着**已经释放**
## 的实例，直接 `as CombatActor` 会报 `Trying to cast a freed object`（2026-10-11 在线连杀多只怪
## 时每次死亡都刷一条）。所有从这个字典取演员的地方都走这里 —— 取不到就是 null。
func _活演员(object_id: int) -> CombatActor:
	var 存的 = _entities_by_object.get(object_id)
	return (存的 as CombatActor) if is_instance_valid(存的) else null

func _on_server_monster_spawned(state: Dictionary) -> void:
	if int(state.get("map_id", 0)) != int(_get_current_map_id()):
		return
	var object_id := int(state.get("object_id", 0))
	var old = _entities_by_object.get(object_id)
	if is_instance_valid(old):
		old.queue_free()
	var entry := {
		"type": "m", "id": str(int(state.get("monster_id", 0))), "object_id": object_id,
		"x": float(state.get("x", 0)), "y": float(state.get("y", 0)),
		## ⚠ **这两条以前整段没往下传**：`_handle_spawn_monster_text` 把精英段与 `attackedByMob`
		## 解进了 `state`（`后端连接.gd:3435-3452`），但这里拼 entry 时只带了坐标 ⇒
		## `_configure_actor` 里 `entry.get("jingying")` 恒空 ⇒ **在线怪的精英血量/伤害加成一直是失效的**
		## （`战斗角色.clientCombatMaxHp` 那条乘子拿不到列表），脚下光环与强化图标也永远不出来。
		## 键名与 `_configure_actor` 读的完全一致（`jingying` / `attacked_by_mob`），不另立一套。
		"jingying": state.get("jingying", []),
		"attacked_by_mob": bool(state.get("attacked_by_mob", false)),
		## 竞技场对手：一具**长得像玩家**的权威怪（`后端连接._arena_对手帧`）。不带上这一份，
		## 下面 `_spawn_life_entry` 只会按模板号 0 去解怪 → 画不出人。
		"对手": state.get("对手", {}),
	}
	var actor := _spawn_life_entry(entry, _entities.size(), true)
	var sprite := actor.get_node_or_null("Sprite")
	if sprite != null:
		sprite.call("set_direction", int(state.get("direction", 1)))

func _on_server_monster_killed(object_id: int, _animation: int) -> void:
	var actor: CombatActor = _活演员(object_id)
	if actor != null:
		actor.apply_server_kill()
		# KILL 也要像 REMOVE 那样从 `_entities` 摘掉 + 收目标框：
		# 服务端只发 239、不发 163（`_handle_monster_killed` 只广播 KILL_MONSTER），
		# 原来只在 REMOVE 里清 → 在线杀怪 `_entities` 只增不减（尸体节点带 sprite 常驻）。
		# 死亡动画由 `apply_server_kill()` 里那句播完 die1 后 `queue_free` 收尾。
		_entities.erase(actor)
		if actor == _view_target:
			_摆头顶箭头(actor, false)		# 原版 setter：viewTarget 换了就先把旧的箭头摘掉
			_view_target = null
			_选中目标上次血量 = -1
			if _session != null:
				_session.call("clear_map_character_selection")
	_entities_by_object.erase(object_id)

func _on_server_monster_removed(object_id: int) -> void:
	var actor: CombatActor = _活演员(object_id)
	if actor != null:
		_entities.erase(actor)
		# 被打死的那只正好是目标框在看的 → 框跟着收起来
		# （原版 `MonsterHandler.as:426/477` 都是 `viewTarget = null`；`TargetHandler` 的 setter
		#   在 viewTarget 为空时还会把 petTarget/viewTarget 一起清掉）。
		if actor == _view_target:
			_摆头顶箭头(actor, false)
			_view_target = null
			_选中目标上次血量 = -1
			if _session != null:
				_session.call("clear_map_character_selection")
		actor.queue_free()
	_entities_by_object.erase(object_id)

func _on_server_monster_moved(state: Dictionary) -> void:
	var actor: CombatActor = _活演员(int(state.get("object_id", 0)))
	if actor != null:
		actor.apply_server_movement(state)

func _on_server_monster_attacked(state: Dictionary) -> void:
	var actor: CombatActor = _活演员(int(state.get("object_id", 0)))
	if actor != null:
		actor.apply_server_attack(int(state.get("direction", 1)))

func _on_server_monster_damaged(object_id: int, damage: int, critical: bool, 受击动画: bool,
		由自己打出 := false, 打完还活着 := true) -> void:
	var actor: CombatActor = _活演员(object_id)
	if actor == null:
		return
	actor.apply_server_damage(damage, critical, 受击动画)
	## ⭐ 在线这两件以前**整条漏了**（伤害改由服务端算之后，判据都还挂在离线那条
	## `玩家._结算一只` / `战斗角色.take_damage` 上，在线走不到 ⇒ 用户 2026-10-11
	## 报「暴击了但没有震动」）。184 出手帧本来就把需要的两位带过来了：
	## `isPlayer + characterId`（震屏条件）与每只怪的 `alive`（击飞条件）。
	if critical and 由自己打出 and is_instance_valid(_player) and _player.has_method("_震屏"):
		_player.call("_震屏")			# `AbstractSkillEffect.as:321-324`
	if critical and not 打完还活着 and actor.has_method("服务端击飞"):
		# `:245-274`：暴击 + 打死 + 不是 boss ⇒ 抛出去。方向原版拿打者的 x 与怪比，
		# 拿不到才退回出手帧里的 `direction`；这里两个都有。
		var 方向 := 1.0
		if is_instance_valid(_player):
			方向 = 1.0 if _player.global_position.x <= actor.global_position.x else -1.0
		actor.call("服务端击飞", 方向 * 3000.0)

func _on_server_monster_skill_hit(object_id: int, skill_id: int, _damage: int) -> void:
	if skill_id <= 0 or _session == null or not bool(_session.game_settings.get("show_skill_effects", true)):
		return
	var actor: CombatActor = _活演员(object_id)
	if actor == null:
		return
	var effect := SkillAnimationScript.new() as Node2D
	add_child(effect)
	# `MonsterAttackEffect.as:91-95`：特效锚在**怪自己的脚点**（`effect.x = monster.x; effect.y = monster.y`），
	# 朝向按怪的朝向（`scaleX = direction == LEFT ? 1 : -1`，和人物技能同一套）。
	# 原来锚点带了 `-24`、朝向完全没设。
	effect.global_position = actor.global_position
	effect.set_direction(int(actor.get("_朝向")))
	var padded_id := str(skill_id).pad_zeros(7)
	if not effect.configure(padded_id, "hit") and not effect.configure(str(skill_id), "hit"):
		effect.queue_free()

func _on_server_monster_hp_changed(object_id: int, hp_percent: int) -> void:
	var actor: CombatActor = _活演员(object_id)
	if actor != null:
		actor.apply_server_hp_percent(hp_percent)

func _on_server_npc_spawned(state: Dictionary) -> void:
	if not _state_matches_current_map(state):
		return
	var object_id := int(state.get("object_id", 0))
	if _entities_by_object.has(object_id):
		return
	var entry := {
		"type": "n", "id": str(int(state.get("npc_id", 0))).pad_zeros(8), "object_id": object_id,
		"x": float(state.get("x", 0)), "y": float(state.get("y", 0)),
	}
	_spawn_life_entry(entry, _entities.size(), true)

func _on_server_drop_spawned(state: Dictionary) -> void:
	if not _state_matches_current_map(state):
		return
	var object_id := int(state.get("object_id", 0))
	_on_server_drop_removed(object_id)
	var loot := _create_drop_node(state, object_id)
	get_parent().add_child(loot)
	_server_drops[object_id] = loot
	## **掉落生成的那一帧什么都不捡**。原版 `DropItemHandler.addDropItem():504-531` 只建精灵、
	## 挂显示层、发紫装/神器公告，没有一条 `pickDropItem`。自动拾取只发生在挂机循环里
	## （`GuajiHandler.as:749-776` 活动区内、`:848-863` 赶路途中），手动玩时东西就躺在地上
	## 等人点（`World.as:807`）或按拾取键（`KeyController.as:804`）。
	## 2026-09-27 那条"掉落来不及落地"的报障根因就是这里 —— 当时加了一道"只在挂机时直捡"，
	## 但那三个 `auto_pick*` 开关与"生成即捡"都是自造的，10-19 按「逐句转写」整条撤掉。


## 原版掉落物在地上是物品图标本体，不是一个文字按钮
## `离线` = 本地打怪掉的（没有服务端 object_id）。表现**完全同一条**，
## 差别只有两处：拾取时不发协议、以及用负数编号避开服务端的 object_id。
func _create_drop_node(state: Dictionary, object_id: int, 离线 := false) -> Node2D:
	var root := Node2D.new()
	root.set_meta("drop_offline", 离线)
	root.position = Vector2(float(state.get("x", 0)), float(state.get("y", 0)))
	# ⚠️ 这里原来写的是 4500，**超出 Godot 的 z_index 范围 (-4096..4096)**，每次掉落
	# 生成都会报 "Tried to set Z index to an invalid value"，并且 z 直接失效 →
	# 掉落物被地形盖住。掉落物在原版属于 `ALayerType.RANKITEMS`，和角色同层，
	# 排在同层角色之后（后加的在上面），所以直接用角色层带即可。
	root.z_index = _角色层次(root.position)
	var is_meso := bool(state.get("is_meso", false))
	## ⚠ 原版把图标 + 名字挂在 `contentContainer` 上、浮动改的是**它**的 y
	## （`:129-141` 建容器、`:483` 浮动、`:395` 落地把容器的 rotation 归零）。
	## 本工程**不另开这一层**：落地时容器的 rotation 已经是 0、也没有缩放，
	## ⇒ "浮容器" 与 "浮根节点" 画面上逐像素等价；而根节点多一层会让
	## `DropIcon`/`DropName` 的取节点路径全变（四道在跑的检查看的就是这两个名字）。
	## 浮动量只有 ±3 像素，自动拾取那条距离判定不受影响。
	var icon := TextureRect.new()
	icon.name = "DropIcon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 金币走的**不是**物品图标，而是 `PicTool.getMesoPic(数量)` 那四档钱堆动画
	# （`ItemPic.TYPE_MESO`）；物品才按 id 取图标。
	icon.texture = (GAME_DATA.金币图标(int(state.get("item_id", 0))) if is_meso
		else GAME_DATA.item_icon(state.get("item_id", "")))
	## 图标取不到时地上是**完全空的**（一个像素都没有），玩家只会觉得"掉了个寂寞"。
	## 原版这种情况下 `PicTool.getItemObject` 会去 `loadDat` 把缺的那包物品图拉下来再补画，
	## 本工程没有那条兜底 ⇒ 至少要吭一声，别静默。
	if icon.texture == null:
		push_warning("掉落物取不到图标 ⇒ 地上是空的：is_meso=%s item_id=%s" % [
			str(is_meso), str(state.get("item_id", ""))])
	if is_meso:
		## 原版 `render():304-310`：`content.x = -15, content.y = 15`，而容器原点 = 落点 y − 15
		## ⇒ 钱堆的注册点**正好压在地面线上** ⇒ 按"底边中心贴地面"摆。
		var 贴宽 := 34.0
		var 贴高 := 24.0
		if icon.texture != null:
			贴宽 = float(icon.texture.get_width())
			贴高 = float(icon.texture.get_height())
		icon.position = Vector2(-贴宽 / 2.0, 15.0 - 贴高)
		icon.size = Vector2(贴宽, 贴高)
	else:
		## 原版 `render():341-343`：`content.x = -width/2`、`content.y = -height/2`，
		## 而 `ItemPic.createTypeItem():124-131` 先画了一块 **34×34** 的透明底 ⇒
		## **图标的中心 = 容器原点 = 落点上方 15 像素**。
		## ⚠ 这里原先摆成 `(-17,-34)`（底边贴锚点）⇒ 整枚图标高了 17 像素，
		##   用户 10-12 报"掉落物大小也不对"量的就是这一条（尺寸 34×34 本身是对的）。
		icon.position = Vector2(-17.0, -17.0)
		icon.size = Vector2(34.0, 34.0)
	root.add_child(icon)
	# ---- 名字标签：**每个**掉落物都有，且常显 ----
	# 原版 `DropItemSprite.render()` 给每一种掉落物都建一个 `RoleNamePane`（`_namePane`），
	# 建的时候先 `visible = false`，但 `tick()` 里一进屏就把它置 true（`:469-473`）——
	# 所以是**常显**，不是悬停才出。文案：
	#   金币 → `_itemid + CHARACTOR_GOLD_COIN`，即 **`<数量>金币`**（`_itemid` 对金币就是数量），白，y=30
	#   神器 → `StringTool.getItemString(id)`，颜色取 `EquipAptitudeType.getEquipColor(PURPLE)`，y=27
	#   普通物品 → 物品名，白，y=34
	# ⚠️ 2026-09-27 用户给的并排图：我们这边**物品掉落完全没有名字**、金币只写死"金币"（丢了数量）。
	#    原来那句 `fallback` 是自造的兜底（只在画不出图标时才出），不是原版那条常显名字。
	# 出场动画的起点/终点与计时（原版 `tick()` 的头一段）。
	# 起点是**怪物身上**（`from_x/from_y`），终点是落点 `x/y`。
	var 到 := Vector2(float(state.get("x", 0)), float(state.get("y", 0)))
	var 起 := Vector2(float(state.get("from_x", 到.x)), float(state.get("from_y", 到.y)))
	root.position = 起
	root.set_meta("drop_from", 起)
	root.set_meta("drop_to", 到)
	root.set_meta("drop_t", 0.0)
	root.set_meta("drop_air", true)          # 飞行中：名字不显（原版 :386-389）
	root.set_meta("drop_meso", is_meso)
	## 挂机挑"该不该捡"要用这两样（`GuajiHandler.toPickItem:456-:522`：按号段分类 +
	## 装备三档过滤里的**品质**）。品质就在服务端 272 帧第 5 段（`equipAptitude`，
	## 原版 `ItemDropInfo.decode:49 readByte`，本地绝不按物品号推），以前整段没解。
	## ⚠ 一律 `str()`，不许写 `String(...)`：服务端的 item_id 是**整数**，
	## 而 GDScript 4 里 `String(int)` 这个构造器根本不存在 ⇒ 当场抛 "Nonexistent 'String' constructor"、
	## `_create_drop_node` 半路死 ⇒ 掉落物一个都建不出来（10-18 全量门两条红就是这个）。
	root.set_meta("drop_item", str(state.get("item_id", "")))
	root.set_meta("drop_aptitude", int(state.get("aptitude", 0)))
	## 原版 `ItemDropInfo.ownerCharId`（帧里 fields[6]）：谁掉的。
	## `canItemPickup():478-486` 拿它判"无主 / 我的 / 同队的"才让捡。
	root.set_meta("drop_owner", int(state.get("owner_id", 0)))
	## 原版 `:119 _upDownRnd = MathAD.rnd(0,600)`，落地那一刻 `:394 _pastTime += _upDownRnd`
	## ⇒ **每一枚的浮动相位不一样**（不然满地掉落物会整整齐齐一起上下，一眼假）。
	root.set_meta("drop_phase", randf_range(0.0, 600.0))
	## ── `touch_up` 那一档：原版**既不挂鼠标监听、也不建名字标签** ──
	## `ctor:142-151` ⇒ `else mouseChildren = mouseEnabled = false`；
	## `render():311-320`（金币）与 `:355-364`（普通物品）里那句 `if(!this.touchUp)`
	## 把 `_namePane` 整块包住了 ⇒ 这种掉落物地上就是**一个光图标**，
	## 靠"玩家身体碰到"自动捡（见 `_推进身体捡`）。
	## （神器那一支 `:322-338` 例外：名字无条件建 —— 本工程还没接神器掉落图，见 §6。）
	var 碰捡 := bool(state.get("touch_up", false))
	root.set_meta("drop_touch_up", 碰捡)
	if 碰捡:
		return root
	var 名字 := Label.new()
	名字.name = "DropName"
	名字.visible = false                     # 落地后由 `_推进掉落动画` 打开
	名字.text = ("%d金币" % int(state.get("item_id", 0))) if is_meso 		else str(state.get("item_name", state.get("item_id", "")))
	名字.size = Vector2(140.0, 20.0)
	## 原版 `RoleNamePane` 的文本框是 `autoSize = CENTER`（`RoleNamePane.as:39`）
	## ⇒ 代码里给的那个 y 是**文本盒的中心**，不是顶边：金币 30（`:317`）、普通物品 34（`:361`）、
	##   神器 27（`:331`）。Godot 的 Label 从顶边排 ⇒ 再抬半个盒高。
	var 名中心 := 30.0 if is_meso else 34.0
	名字.position = Vector2(-70.0, 名中心 - 名字.size.y / 2.0)
	名字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	名字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	名字.add_theme_font_size_override("font_size", 12)
	名字.add_theme_color_override("font_color", _掉落名字颜色(state))
	名字.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	名字.add_theme_constant_override("outline_size", 世界名字描边)
	root.add_child(名字)
	var click := Button.new()
	## 点击范围按原版 `checkOverMe():503-511`（**不是** `itemTouchRect` —— 那一条 34×34
	## 是"玩家身体碰到时自动拾取"用的，判定对象不同）：非神器 x ∈ [−20,20]、y ∈ [−34,15]。
	## 点击框跟着图标一起浮（原版鼠标判定用的是 `contentContainer.globalToLocal(...)`，
	## 命中区本来就长在浮动的这一层上）—— 本工程浮的是根节点，所以子节点自然跟着走。
	click.position = Vector2(-20.0, -34.0)
	click.size = Vector2(41.0, 50.0)
	click.flat = true
	click.focus_mode = Control.FOCUS_NONE
	click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click.pressed.connect(_点掉落物.bind(object_id))
	root.add_child(click)
	return root

## 掉落物名字的颜色。真值 `DropItemSprite.render()`：
##   `var _loc1_:uint = 16777215;`（白）是初值，**只有神器那一条支**把它换成
##   `EquipAptitudeType.getEquipColor(PURPLE)`（`:326`）。
## 普通装备的品质色**不上名字** —— 那一支（`:346-356`）是给**图标**套 `GlowFilter`，
## 本工程还没做（要辉光滤镜）。
func _掉落名字颜色(state: Dictionary) -> Color:
	if bool(state.get("is_meso", false)):
		return 世界名字颜色
	var 定义: Dictionary = GAME_DATA.item(state.get("item_id", ""))
	return 神器名字颜色 if String(定义.get("category", "")) == "神器" else 世界名字颜色

## 离线掉落物的编号从 -1 往下走 —— `_server_drops` 的正数键是服务端的 object_id，不能撞。
var _离线掉落序号 := -1
## 离线掉落给多少金币。原版这个数是服务端 `DropItemSprite` 的 `_itemid` 给的，
## 本地打怪没有服务端 ⇒ 沿用原来那个按钮上写的 5（**这一条还是自定的**，只是表现改成原版那套）。
const 离线掉落金币 := 5

## ── 捡取这条链（10-12 按原版 `DropItemHandler` 拆成四步）────────────────────────
##   ① 点下去**不立刻捡、也不立刻播动画** —— `gotoPickUpItem():131-164`：
##      不能动 / 死了 ⇒ 直接 return；记 `_curItemGoToPickUp`；
##      距离 < 50 ⇒ 当场 `pickDropItem`，否则 **`API.player.pathFind(item.x, item.y - 5)` 先走过去**。
##   ② 每帧 `tickItemGotoPickUp():451-467`：走近到 < 50 ⇒ 发拾取；
##      玩家已经不再寻路 ⇒ **放弃这一单**（`_curItemGoToPickUp = null`）。
##   ③ `pickDropItem():543-565`：全局节流 `PICK_ITEM_TIME_LIMIT = 200ms`
##      + 这一枚锁定 `LOCK_PICK_UP = 5000ms`（防连点重复发），然后才发协议。
##   ④ **动画由服务端回帧驱动** —— `removeDropItem():401-422` 看 `animation` 字段
##      （`RemoveItemInfo.decode()`：0=过期 1=无动画 **2=拾取** 5=宠物捡）：
##      ≥2 才 `removeItemPickUp()` 起动画，并把 **`picker` 设成回帧里那个 cid 对应的角色/宠物**；
##      0/1 ⇒ `removeItem()` **直接消失、不播动画**。
## ⚠ 原来这四步被压成一步：点下去本地立刻起动画 + 发协议 ⇒ 隔着半张地图点掉落物，
##   它会"隔着空气飞过来"；服务端说"捡不了"（包满/别人的/锁定中）时动画也已经播完了。
const 拾取走近距离 := 50.0			# `:152`/`:456` 那个 `< 50`
const 拾取键隔毫秒 := 100.0			# `KeyController.PICKDELAY:52`
## 玩家身体盒：`Character.as:240` `_charTouchUpRect = Rectangle(-27,-120,54,120)`
## （原点 = 脚点，向上 120、左右各 27）。`touchUpRect():1950-1962` 再把它
## 与"按当前速度扫 100ms 的那一份"取并集 ⇒ 跑动时身体判定盒会往前伸。
const 身体盒 := Rect2(-27.0, -120.0, 54.0, 120.0)
## 掉落物的"被碰到"盒：`DropItemSprite.as:96` `itemTouchRect = Rectangle(-17,-34,34,34)`
const 掉落物盒 := Rect2(-17.0, -34.0, 34.0, 34.0)
const 身体捡横距 := 200.0				# `pickItemLose():79` 的 ±200
var _键隔 := 0.0
const 拾取节流毫秒 := 200.0			# `PICK_ITEM_TIME_LIMIT`
const 单枚锁定毫秒 := 5000.0			# `LOCK_PICK_UP`
## "没有要去捡的那一枚"的哨兵。⚠ **不能用 -1** —— 离线掉落物的编号就是从 -1 往下走的
## （`_离线掉落序号`），拿 -1 当"空"会让 `_点掉落物` 第一行 `_要去捡 == object_id` 直接早退，
## 于是**离线掉落永远点不动**（10-12 自己踩到，被离线门抓出来）。原版这里用的是对象引用 null。
const 无拾取目标 := -999999999
var _要去捡 := 无拾取目标
var _拾取闸 := 0.0
var _锁定表 := {}
## 禁寻路图里"踩到箭头"的 1000ms 去重表：`object_id -> 剩余毫秒`。
## 原版 `DropItemHandler._itemDic` 存的是上次触发时刻，`(now - 上次) < 1000` 就跳过
## （`pickItemInARect():428-450`）—— 踩在箭头上不走会连续触发，所以必须有这一道。
var _触碰表 := {}

## ① 掉落物被点（= 原版 `gotoPickUpItem`）
func _点掉落物(object_id: int) -> void:
	var 掉 := _server_drops.get(object_id) as Node2D
	if not is_instance_valid(掉):
		return
	if _要去捡 == object_id:
		return						# 原版 `if(_curItemGoToPickUp != param1)`：重复点同一枚不再走一遍
	var 捡 := _掉落拾取者()
	if 捡 == null:
		return
	_要去捡 = object_id
	if _够得着掉落物(捡, 掉):
		_发拾取(object_id)
	elif 捡.has_method("走向"):
		## 原版 `pathFind(item.x, item.y - 5)` —— 落点在图标**上方 5 像素**，不是图标中心
		捡.call("走向", Vector2(掉.global_position.x, 掉.global_position.y - 5.0), true, false)


## 原版 `DropItemHandler.getOnePickableDropItem():99-124` + `canItemPickup():478-486`：
## 在"能捡的"里面挑**离玩家最近**的一枚。能捡 = 落地了、不在拾取动画里、没被这一枚的
## 5 秒锁挡住、归属是我（或无主）。⚠ 原版还有一条"同队成员的也算"（`isInTroop`），
## 本工程的队伍成员不在同一张地图实体表里 ⇒ 这一条没接（见 真值/窗口/掉落物.md §6）。
func _最近可捡掉落物() -> int:
	var 谁 := _掉落拾取者()
	if 谁 == null:
		return 无拾取目标
	var 我的号 := int(_backend.get("character_id")) if _backend != null else 0
	var 最佳 := 无拾取目标
	var 最近 := INF
	for 编号 in _server_drops.keys():
		var 掉 := _server_drops.get(编号) as Node2D
		if not is_instance_valid(掉) or bool(掉.get_meta("drop_touch_up", false)):
			continue		# 原版 `getOnePickableDropItem():109` 明确 `if(!_loc4_.touchUp)`
		if not _可捡(掉, 编号, 我的号, _队友号()):
			continue
		var 距 := 谁.global_position.distance_to(掉.global_position)
		if 距 < 最近:
			最近 = 距
			最佳 = int(编号)
	return 最佳


## 这一枚现在能不能捡（= 原版 `canPickUp` + `canItemPickup` 里客户端能判的那几项）。
func _可捡(掉: Node, 编号: int, 我的号: int, 队友: Array = []) -> bool:
	if bool(掉.get_meta("drop_air", false)) or bool(掉.get_meta("drop_picking", false)) 			or bool(掉.get_meta("drop_removed", false)):
		return false						# 原版 `canPickUp`
	if float(_锁定表.get(编号, 0.0)) > 0.0:
		return false						# 原版 `_hasPickUpDic[oid] = LOCK_PICK_UP(5000)`
	var 归属 = 掉.get_meta("drop_owner", -1)
	return int(归属) == 0 or int(归属) == 我的号 or 队友.has(int(归属))
	# 原版 `canItemPickup():480`：`ownerCharId == 0 || == stats.id || isInTroop(ownerCharId)`


## 同队成员的角色号（原版 `DataCenter.isInTroop`）。没入队 ⇒ 空表。
func _队友号() -> Array:
	if _backend == null:
		return []
	var 队: Dictionary = _backend.get("authoritative_party")
	var 出: Array = []
	for 员 in (队.get("members", []) as Array):
		出.append(int((员 as Dictionary).get("character_id", 0)))
	return 出


## 身体碰到就算捡（原版 `pickItemLose():77-83` + `touchPlayerNow():513-520`）：
##   横向纵向各 ±200 的粗筛 + "玩家身体盒平移到掉落物坐标系"与 `(-17,-34,34,34)` 相交。
## 只有 `touch_up=true` 的那一档走这条路。
func _身体碰到掉落物(谁: Node2D, 掉: Node2D) -> bool:
	var 差 := 谁.global_position - 掉.global_position
	if absf(差.x) > 身体捡横距 or absf(差.y) > 身体捡横距:
		return false
	var 盒 := 身体盒
	var 速 = 谁.get("velocity")
	if 速 is Vector2:
		盒 = 盒.merge(Rect2(身体盒.position + (速 as Vector2) * 0.1, 身体盒.size))
	盒.position += 差
	return 盒.intersects(掉落物盒)


func _够得着掉落物(谁: Node2D, 掉: Node2D) -> bool:
	return 谁.global_position.distance_to(掉.global_position) < 拾取走近距离


## 禁寻路图的"踩到箭头/火箭"（原版 `DropItemHandler.pickItemInARect():428-450`）。
##
## 只在 `nowInNotFindPathMap` 那一支里跑（`tick():205-212`），而且**不经过** `canItemPickup`：
## 只要 `touchUp` 且两个矩形相交就调 `player.onTouchItem(itemid)`，同一枚 1000ms 内只触发一次。
## 两个矩形是原版硬编码：
##   玩家 A = (player.x − 20, player.y − 42, 42, 42) —— **和身体盒 `(-27,-120,54,120)` 不是同一个**，
##   道具 B = (item.x − 17, item.y − 17, 34, 34)。
func _推进触碰道具(步进: float) -> void:
	for k in _触碰表.keys():
		var 剩: float = float(_触碰表[k]) - 步进
		if 剩 <= 0.0:
			_触碰表.erase(k)
		else:
			_触碰表[k] = 剩
	if not 禁寻路地图.是禁寻路图(_get_current_map_id()):
		return
	var 谁 := _掉落拾取者()
	if 谁 == null:
		return
	var 甲 := Rect2(谁.global_position.x - 20.0, 谁.global_position.y - 42.0, 42.0, 42.0)
	for 编号 in _server_drops.keys():
		var 掉 := _server_drops.get(编号) as Node2D
		if not is_instance_valid(掉) or not bool(掉.get_meta("drop_touch_up", false)):
			continue
		if float(_触碰表.get(编号, 0.0)) > 0.0:
			continue
		var 乙 := Rect2(掉.global_position.x - 17.0, 掉.global_position.y - 17.0, 34.0, 34.0)
		if not 甲.intersects(乙):
			continue
		_触碰表[编号] = 1000.0
		if 谁.has_method("onTouchItem"):
			谁.call("onTouchItem", int(str(掉.get_meta("drop_item", "0"))))


## 禁寻路图的触发道具（15037xxx）**永远不算"捡起来"**：
## 原版 `pickDropItem():556` 有一句 `itemid / 1000 != 15037` 想把这族挡在拾取请求之外
## （AS3 的 `/` 是浮点除，那句其实恒真；服务端那边也是 persistent，收到也会忽略）。
## 本工程按它的**本意**挡：这一族只吃"踩上去改向/弹射"，不发起拾取、不占 5 秒单枚锁。
func _是触发道具(掉: Node) -> bool:
	return int(int(str(掉.get_meta("drop_item", "0"))) / 1000.0) == 15037


## ③ 真发拾取（= 原版 `pickDropItem`）：节流 + 单枚锁定，然后发协议
func _发拾取(object_id: int, 走节流 := true) -> void:
	if _要去捡 == object_id:
		_要去捡 = 无拾取目标
	var 掉 = _server_drops.get(object_id)
	if 掉 == null or float(_锁定表.get(object_id, 0.0)) > 0.0 or (走节流 and _拾取闸 > 0.0):
		return
	if _是触发道具(掉):
		return
	if 走节流:
		_拾取闸 = 拾取节流毫秒
	_锁定表[object_id] = 单枚锁定毫秒
	if bool(掉.get_meta("drop_offline", false)):
		## 本地掉的没有回帧可等 ⇒ 就地按"服务端说要播拾取动画"处理
		_起拾取动画(object_id, 掉, null)
		return
	if _backend != null:
		_backend.call("request_pickup", object_id)


## ② + 节流计时。挂在 `_process` 里每帧跑（`_推进掉落动画` 空表时会早退，不能塞进去）。
func _推进去捡(步进: float) -> void:
	if _拾取闸 > 0.0:
		_拾取闸 = maxf(_拾取闸 - 步进, 0.0)
	for k in _锁定表.keys():
		var 剩: float = float(_锁定表[k]) - 步进
		if 剩 <= 0.0:
			_锁定表.erase(k)
		else:
			_锁定表[k] = 剩
	## ── 按住 Z 捡（原版 `KeyController.tickPickUpDropItems():793-811`）──
	##   每 `PICKDELAY = 100ms` 看一次；**已经在去捡某枚的路上就不再重挑**
	##   （原版 `if(!dropItemHandler.onRoadGoToPickUp())`）；挑的是"能捡的里面最近的一枚"
	##   （`getOnePickableDropItem():99-124`），然后交给同一条 `gotoPickUpItem`
	##   ⇒ 近了就发、远了**自动寻路走过去**再发（用户 10-12 要的"自动移动到拾取物上"）。
	_键隔 += 步进
	if _键隔 >= 拾取键隔毫秒:
		_键隔 = 0.0
		## ⚠ 必须先问 `InputMap.has_action`：`--script` 跑的门里自动加载没起来 ⇒
		##   `快捷键.确保默认()` 没跑 ⇒ 动作不存在，直接 `is_action_pressed` 会每帧刷错误
		##   （`快捷键.gd` 文件头记的就是这个病）。
		if _要去捡 == 无拾取目标 and InputMap.has_action("pick_up") and Input.is_action_pressed("pick_up"):
			var 候选 := _最近可捡掉落物()
			if 候选 != 无拾取目标:
				_点掉落物(候选)
	_推进身体捡(步进)
	_推进触碰道具(步进)
	if _要去捡 == 无拾取目标:
		return
	var 掉 := _server_drops.get(_要去捡) as Node2D
	var 捡 := _掉落拾取者()
	if not is_instance_valid(掉) or 捡 == null:
		_要去捡 = 无拾取目标
		return
	if _够得着掉落物(捡, 掉):
		_发拾取(_要去捡)
	elif bool(捡.get("click_move_active")) == false:
		_要去捡 = 无拾取目标				# 原版 `!player_nowPathFinding` ⇒ 人停了就放弃这一单


## ④ 起拾取动画（= 原版 `removeItemPickUp` 里那两行 `nowPickUping = true; picker = 谁`）
func _起拾取动画(object_id: int, 掉: Node, 拾取者: Node2D) -> void:
	if not is_instance_valid(掉):
		return
	掉.set_meta("drop_picking", true)
	掉.set_meta("drop_pick_left", 拾取毫秒)
	掉.set_meta("drop_air", false)
	if 拾取者 != null and is_instance_valid(拾取者):
		掉.set_meta("drop_picker", 拾取者)
	var 名 := 掉.get_node_or_null("DropName") as CanvasItem
	if 名 != null:
		名.visible = false


## 回帧里的 cid / pet 标志解析成"飞向谁"。
## 服务端这一帧的字段序就是原版 `RemoveItemInfo.decode()`：`273:animation:oid:pet:cid[:slot]`。
func _找拾取者(角色号: int, 是宠物: bool) -> Node2D:
	if 是宠物 and is_instance_valid(_pet_companion):
		return _pet_companion
	var 我 := _掉落拾取者()
	if 角色号 != 0 and _backend != null and int(_backend.get("character_id")) != 角色号:
		var 远 = _remote_players.get(角色号)
		if 远 != null and is_instance_valid(远):
			return 远 as Node2D
	return 我


## 掉落物的两段动画，逐帧推（原版就是 `tick(param1)` 里逐帧改坐标，不是补间）。
## 放在 `_process` 最前面：`_session` 为空时也要跑（离线看图时同样要动）。
func _推进掉落动画(delta: float) -> void:
	if _server_drops.is_empty():
		return
	var 步进 := delta * 1000.0
	var 拾取者 := _掉落拾取者()
	for 编号 in _server_drops.keys():
		var 掉 := _server_drops.get(编号) as Node2D
		if not is_instance_valid(掉):
			_server_drops.erase(编号)
			continue
		var 到: Vector2 = 掉.get_meta("drop_to")
		if bool(掉.get_meta("drop_air", false)):
			var 起: Vector2 = 掉.get_meta("drop_from")
			var t: float = float(掉.get_meta("drop_t", 0.0)) + 步进
			if t > 掉落飞行毫秒:
				掉.position = Vector2(到.x, 到.y - 掉落落点抬高)
				掉.rotation = 0.0
				掉.set_meta("drop_air", false)
				## 原版 `:394 _pastTime += _upDownRnd` —— 落地那一刻把随机相位叠进去，
				## 满地掉落物才不是一起上下。
				掉.set_meta("drop_t", t + float(掉.get_meta("drop_phase", 0.0)))
				var 名 := 掉.get_node_or_null("DropName") as CanvasItem
				if 名 != null:
					名.visible = true
			else:
				# 抛物线：顶点在 `min(fromY,toY) - h`，越过顶点就镜像回来（原版 :401-403）
				var 顶 := minf(起.y, 到.y) - 掉落弧高
				var 每秒 := (起.y - 顶 + 到.y - 顶) / 掉落飞行毫秒
				var y := 起.y - 每秒 * t
				if y < 顶:
					y = 顶 + (顶 - y)
				掉.position = Vector2(起.x + (到.x - 起.x) * (t / 掉落飞行毫秒), y)
				if not bool(掉.get_meta("drop_meso", false)):
					掉.rotation += deg_to_rad(掉落自转速度 * delta)
				掉.set_meta("drop_t", t)
		elif bool(掉.get_meta("drop_picking", false)):
			var 剩: float = float(掉.get_meta("drop_pick_left", 拾取毫秒)) - 步进
			if 剩 <= 0.0:
				_移除掉落(编号, 掉)
				continue
			掉.set_meta("drop_pick_left", 剩)
			(掉 as CanvasItem).modulate.a = maxf(剩 / 拾取毫秒, 0.3)
			var y2: float = 到.y - (拾取毫秒 - 剩) * 拾取上浮 / 拾取毫秒
			if y2 < 到.y - 拾取封顶:
				y2 = 到.y - 拾取封顶 + (到.y - 拾取封顶 - y2)
			# ⚠️ 原来这里写的是 `拾取者.x` —— **`Node2D` 上没有 `x` 这个属性**，
			#    只要拾取动画一跑，每帧都会报 `Invalid access to property or key 'x'`，
			#    x 也就永远不往拾取者那边挪（拾取物只上浮、不追人）。
			#    2026-10-01 由 `离线掉落表现回归测试` 带出来（离线那条一接上拾取动画就撞见）。
			## 朝**回帧里那个拾取者**飞（原版 `_pickerer`：谁捡的就飞向谁，宠物捡的飞向宠物）；
			## 没设 ⇒ 朝落点 x，等于只上浮不追人 —— 与原版 `:446-451` 同一条。
			## ⚠ `get_meta(键, null)` 在 4.7 仍然会刷一条
			##   `The object does not have any 'meta' values with the key ...` ⇒ 先问 `has_meta`。
			var 谁 = 掉.get_meta("drop_picker") if 掉.has_meta("drop_picker") else null
			if 谁 == null or not is_instance_valid(谁):
				谁 = 拾取者
			var 目标x: float = (谁 as Node2D).global_position.x if 谁 != null else 到.x
			掉.position = Vector2(
				掉.position.x + minf(目标x - 掉.position.x, 拾取追速 * delta), y2)
		elif bool(掉.get_meta("drop_removed", false)):
			_移除掉落(编号, 掉)
		else:
			## ── 躺在地上时的上下浮动（原版 `tick()` 最后一段 `:478-483`）──
			##   `_pastTime += 步进`；超过 `2π·300` 就减掉一圈（⇒ 周期 ≈ 1885ms）；
			##   `contentContainer.y = floor(3 * sin(_pastTime / 300))` ⇒ 幅度 **±3 像素**、
			##   而且是 `floor` ⇒ 取值只有 −3..2 这 6 档，不是平滑小数。
			## ⚠ 用户 10-12 报"掉落物不会动，原版本会上下浮动"缺的就是这一段
			##   （有头量具连拍 60 帧实测：改之前图标 y 只有一个值 157.0）。
			var 浮t: float = float(掉.get_meta("drop_t", 0.0)) + 步进
			while 浮t > 浮动一圈:
				浮t -= 浮动一圈
			掉.set_meta("drop_t", 浮t)
			掉.position = Vector2(到.x, 到.y - 掉落落点抬高 + floorf(浮动幅度 * sin(浮t / 300.0)))


## `touch_up` 那一档：身体碰到就捡（原版每帧对每枚掉落物跑 `pickItemLose`）。
## ⚠ 这条路**不看 200ms 全局节流**（原版 `canItemPickup(item, false)` / `pickDropItem(item, false)`），
##   但仍然吃"这一枚 5 秒锁定"。
func _推进身体捡(_步进: float) -> void:
	var 谁 := _掉落拾取者()
	if 谁 == null:
		return
	var 我的号 := int(_backend.get("character_id")) if _backend != null else 0
	for 编号 in _server_drops.keys():
		var 掉 := _server_drops.get(编号) as Node2D
		if not is_instance_valid(掉) or not bool(掉.get_meta("drop_touch_up", false)):
			continue
		if not _可捡(掉, 编号, 我的号, _队友号()) or not _身体碰到掉落物(谁, 掉):
			continue
		_发拾取(编号, false)


## 拾取动画要"飘向拾取者"（原版 `_pickerer`，没设就飘向落点）。我们拿玩家当拾取者。
func _掉落拾取者() -> Node2D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	return _player


func _移除掉落(object_id: int, 掉: Node) -> void:
	if is_instance_valid(掉):
		掉.queue_free()
	_server_drops.erase(object_id)


## ④ 服务端的"这枚掉落物没了"回帧。`动画` = 原版 `RemoveItemInfo.animation`：
## **≥2 才播拾取动画**（2=拾取、5=宠物捡），0/1（过期 / 无动画）⇒ **直接消失**。
## ⚠️ 播动画时不能直接 `queue_free` —— 原版也是动画跑完才移除；
##    正在播就打个 `drop_removed` 标记，让 `_推进掉落动画` 到点了收。
func _on_server_drop_removed(object_id: int, 动画: int = 0, 角色号: int = 0, 是宠物: bool = false) -> void:
	var loot = _server_drops.get(object_id)
	if 动画 < 2:
		if _要去捡 == object_id:
			_要去捡 = 无拾取目标
		_移除掉落(object_id, loot)
		return
	if is_instance_valid(loot) and bool(loot.get_meta("drop_picking", false)):
		loot.set_meta("drop_removed", true)
		return
	_起拾取动画(object_id, loot, _找拾取者(角色号, 是宠物))

## 1291:2 ⇒ 只认本人那一发（`LianzhanHandler.as:79` 那个 `param5 == playerId` 判断）。
func _on_server_lianzhan_stage(阶段: int, _经验加成: int, _剩余秒: int, _总秒: int, 角色号: int) -> void:
	# `_ready` 里那次取玩家可能早于 Player 自己的 `_ready`（`add_to_group("player")` 还没跑）
	# ⇒ 和 `_on_server_player_damaged` 一样补一次查找，不然这一支静默什么都不做。
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(_player) or not _player.has_method("设连斩阶段"):
		return
	if 角色号 != int(_backend.get("character_id")):
		return
	_player.call("设连斩阶段", 阶段)

## 199(UPDATE_CHAR_LOOK) ⇒ 本人换身体那一套；别人（远程玩家）换他那具。
## 原版 `CharacterHandler.as:283-358` 两个分支最后都落到同一个动作：
## `characterAnimation.clearEquip()` → `face = charLook.face`（本人还额外刷 stats + 左上角头像 + 人物窗立绘）。
## ⚠ 本工程**只换身体那套动画**：装备逐件挂层（`:346-353` 那个 `for each`）没做，
##   因为服务端算 face 时已经把"穿了什么"折进去了（`fake_flash_server.py:17579-17581`）⇒ 见 #190 未收口。
func _on_server_char_look(角色号: int, _性别: int, _肤色: int, 脸: int, _灵气脸: int, _装备串: String) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if 角色号 == int(_backend.get("character_id")):
		if _player != null and is_instance_valid(_player) and _player.has_method("刷新外观"):
			_player.call("刷新外观")
		return
	var 演 = _remote_players.get(角色号)
	if 演 == null or not is_instance_valid(演):
		return
	var 精灵: Node = null
	for 子 in 演.get_children():
		if 子.has_method("configure"):
			精灵 = 子
			break
	if 精灵 == null:
		return
	var 号 := str(脸).pad_zeros(8)
	## 查不到新那套 ⇒ 留着原来那具，绝不刷成空白（与本人、与左上角头像同一口径）
	if 脸 > 0 and OriginalSprite.has_animation("character", 号):
		精灵.call("configure", "character", 号, "stand")

func _on_server_player_damaged(state: Dictionary) -> void:
	if int(state.get("character_id", 0)) != int(_backend.get("character_id")):
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return
	# 原版人物挨打也是同一条伤害数字（`Character.as:1220-1290`）：
	# 颜色走 `CHAR_HP_COMMON` / `CHAR_HP_BSK` = 16711680（红），
	# 锚点是当前贴图高度 `_crtCharHeight`，起手 y = `-锚点 + 12`。
	var 精灵 := _player.get("player_sprite") as Node2D
	var 锚点 := 0.0
	if 精灵 != null and 精灵.has_method("当前贴图高度"):
		锚点 = float(精灵.call("当前贴图高度"))
	# 2026-10-01：原来这里还调了一句 `show_hit_feedback()`（整个角色泛红再淡回来）——
	# **那是我自造的**：原版挨打只有上面这条伤害数字，`Character.as` 里没有任何泛红。
	# 已删（函数本身也一并删了）。
	## ⭐ 在线这一支的**真值就是 `DamageHandler.as:38 addDamage()`**（服务端 194 帧 → 这一条）：
	## `damage > 0` 时看**第六个读出的字段**（AS3 里叫 `direction`，服务端发的其实是
	## `int(critical)`，我们解析成 `hit_flag`）—— `== 1` 且打的是 `API.player` 自己 ⇒
	## 写「致命」`FIGHT_ZHIMING` + `CHAR_HP_BSK`；否则空 tip + `CHAR_HP_COMMON`
	## （`DamageHandler.as:92-106`）。
	## `damage <= 0` **不是空包**：`:130-133` 那一支照样调 `player_addAttriChangeTip("", 0, ...)`，
	## 走到 `Character.as:1244-1256` ⇒ 身上飘「我闪」（正在跳则「跳闪」）。
	## 本机服务端确实会发 0 伤害那一帧（`fake_flash_server.py:36898` 宠物反弹那段把 damage 归 0）。
	## 以前这里写的是"没有暴击位/没有闪开位，不猜 ⇒ 0 伤害不飘字"，那句判断**记错了包**
	## （想当然按 243 那条只有两个 int 的包写的），2026-10-11 按 194 的字段序改回原版。
	var 伤害 := int(state.get("damage", 0))
	_播放玩家伤害数字(锚点, 伤害, "致命" if 伤害 > 0 and int(state.get("hit_flag", 0)) == 1 else "")
	## ⭐ 原版 `DamageHandler.as:107-113`：**这一发的状态效果没生效**（`skillTrigger` 为 false）时，
	## 还要在伤害那条之后**再追加一条**流水字 = 这招的"对手技"名字。
	## 语义（10-11 用户纠正，别写反）：飘出来的是**把这一发挡掉的那一招的名字**
	## （防守方那招抵抗生效 ⇒ 状态没挂上 ⇒ 才进这个分支），不是"提示你拿哪招去解"。
	## 取法与那 14 条数据见 `GAME_DATA.skill_flow_text` 与 `开发工具/导出技能对手技.py`（两处 AS3 行号都在文件头）。
	## 颜色 = `CocoStatType.SKILL` ⇒ `Character.as:580-582` 盖成 3316223 = **#3299FF（蓝）**；
	## `num == 0 && tip 非空` ⇒ **只写文字、不带正负号和数字**（`Character.as:1241`）。
	## 服务端这一位默认就是 false（`fake_flash_server.py:36937` 的 `status_triggered = False`，
	## 只有"技能状态真生效"那两条分支才置 true）⇒ 在线确实看得到，不是接了段死代码。
	if 伤害 > 0 and not bool(state.get("skill_trigger", true)):
		var 流水 := String(GAME_DATA.skill_flow_text(int(state.get("skill_id", 0))))
		if 流水 != "":
			_播放玩家伤害数字(锚点, 0, 流水, Color(50.0 / 255.0, 153.0 / 255.0, 1.0))

## `文字前缀`：打中且暴击 = 「致命」，普通打中 = 空，闪开 = 空 + 数值 0 ⇒ 出「我闪」。
## 三档的出处与颜色（玩家侧蓝绿口径与怪侧不同）都写在 `脚本/角色/伤害数字.gd` 顶部。
## 玩家身上的飘字（红=挨打、绿=我闪、蓝=技能流水字）。**走每个角色一条的 400 毫秒队列**
## （`Character.as:588-601` 入列 + `:2591-2598` 每 400 毫秒放一条）⇒
## "一串红字 + 一条蓝色克制提示"是**错开出现**的，不会叠在同一像素上看不清。
func _播放玩家伤害数字(锚点: float, 数值: int, 文字前缀 := "",
		颜色 := Color(1.0, 0.0, 0.0)) -> void:
	## 挨打那一族原版**恒带负号**（`DamageHandler.as:96-132` 传的 `add=false`）⇒ 在这里统一
	## 取成负数；通用出口那一档"正负号就是屏上的正负号"（心法熟练度那一行要的是 `+`）。
	_飘玩家头顶字(锚点, -absi(数值), 文字前缀, 颜色)


## 玩家头顶飘字的通用出口（挨打 / 我闪 / 技能流水字 / 心法熟练度都走这一条队）。
func _飘玩家头顶字(锚点: float, 数值: int, 文字前缀 := "", 颜色 := Color.WHITE) -> void:
	if not is_instance_valid(_player):
		return
	var 动作 := func() -> void:
		if not is_instance_valid(_player):
			return
		var 数字 := 伤害数字脚本.new() as Node2D
		_player.add_child(数字)
		数字.call("播放", 锚点, 数值, 文字前缀, 颜色,
				int(_player.get("facing")) < 0, true, not bool(_player.get("on_ground")))
	飘字队列脚本.排队于(_player, 动作)


## 打坐/双修涨一层心法 ⇒ 头顶一行「X熟练度  + 1」，ZQ 档蓝 #0099FF、18 号加粗
## （`DataCenter.as:1578-1587` → `Character.as:558-602`，字号式在 `:1219-1241`）。
## 与伤害数字**共用同一条 400 毫秒队**：原版每个角色只有一条 `_aryAttriChangeTips`。
func _on_心法熟练度(名: String, 增量: int) -> void:
	var 条 := 头顶飘字规则.心法熟练度(名, 增量)
	if 条.is_empty():
		return
	_飘玩家头顶字(_玩家头顶锚点(), int(条["数值"]), String(条["前缀"]), 条["颜色"] as Color)


## 属性帧那一档该飘的字（判据与颜色都在 `头顶属性飘字.gd` 那张表里，这里只管落点与符号）。
func _on_属性飘字(前缀: String, 数值: int, 是增: bool, 颜色: Color) -> void:
	_飘玩家头顶字(_玩家头顶锚点(), 数值 if 是增 else -数值, 前缀, 颜色)


## 飘字锚点 = **当前帧贴图高**（`Character.as:1220` 那一套，与怪侧 `mobBmdHeight` 同形）。
## 取不到就是 0 ⇒ 字会掉到脚下面去，所以量具/门要单独断言"参照物取到了"。
func _玩家头顶锚点() -> float:
	if not is_instance_valid(_player):
		return 0.0
	var 精灵: Node2D = _player.get("player_sprite") as Node2D
	if 精灵 != null and 精灵.has_method("当前贴图高度"):
		return float(精灵.call("当前贴图高度"))
	return 0.0

## ──────────────── 201/202 别人身上的状态（旁观端）与 1329/1330 PVP 表现 ────────────────
##
## 为什么这一整块是新的（2026-10-22 夜）：服务端**一直在发**这四条帧，而客户端连分派臂都没有
## （现查 `后端连接.gd` 的 196 条分派臂：201/202/1329/1330 全部不在）⇒
## 两个人对打，旁观者看不见谁中了毒、谁被封、谁隐身，也看不见打在人身上的伤害数字与血条。
## 逐条只认原版：`AllInOneProcessor:1043/515/791/1081` → `Client:2654/729/9252/5977`
## → `SkillHandler.applyOtherPlayerBuff:363-423` / `cancelOhterPlayerBuff:691-743`
## / `AbstractSkillEffect.applyPlayerSkillHit:331-433` / `Character.showHpBar:1515-1545`。

## `CocoBuffStatType.as` 里这一族要用的三档（值就是那张表的字面量，别改）。
const 态隐身 := 5			# DARKSIGHT `CocoBuffStatType.as:18`
const 态变暗 := 18			# ADD_ATK_SPEED `:44`
const 变暗系数 := 0.25		# `SkillHandler:417` `Darkness.applyTo(anim, 0.25)`（第二参，不是默认 0.66）
const 宠物招号上限 := 1000	# `applyOtherPlayerBuff:378` `_loc5_ = skillId < 1000` ⇒ 取宠物招那套图
## 原版 `:393-409` 那一串 case ⇒ 挂头顶图标的 16 档，**逐条搬、不合并、不自加**。
const 挂图标档 := [66, 27, 12, 13, 10, 7, 37, 8, 9, 19, 20, 21, 22, 23, 24, 61]

var _隐身角色 := {}
var _远程血条 := {}
## 203 记下来的队伍成员血蓝（键 = 服务端角色号）；那扇"队伍"窗（原版 TroopHPPane）建起来时读它。
var _队伍成员状态 := {}


## 201：给"那个人"挂状态图标（原版 `applyOtherPlayerBuff` 的 switch 逐档）。
func _on_foreign_buff(角色号: int, 列表: Array, _延迟毫秒: int) -> void:
	var 演员 := _按角色号找演员(角色号)
	if 演员 == null:
		return
	var 层 := _确保状态图标层(演员)
	for 条 in 列表:
		var 录 := 条 as Dictionary
		if 录 == null:
			continue
		var 类型 := int(录.get("type", -1))
		var 招号 := int(录.get("skill_id", 0))
		if 类型 == 态隐身:
			_置隐身(演员, 角色号, true)
			continue
		if 类型 == 态变暗:
			_置变暗(演员, 变暗系数)
			continue
		if 挂图标档.has(类型):
			层.加(招号, 类型, 招号 < 宠物招号上限, int(录.get("duration_ms", -1)))
			continue
		# ADD_ATK / ADD_DEF / ADD_BSK / ADD_AVD / CURE_HP_BUFF / CURE_MP_BUFF
		# ⇒ 原版 `:411-421` 这几档的 case 体是**空的**，什么都不做（不是"我们还没接"）。


## 202：撤状态。原版 `cancelOhterPlayerBuff:702-703` 是**先按类型删图标、再走 switch**
## ⇒ 删图标对**每一档**都做，switch 里只有隐身/变暗两档有身体。
func _on_foreign_buff_cancelled(角色号: int, 类型表: Array) -> void:
	var 演员 := _按角色号找演员(角色号)
	if 演员 == null:
		return
	var 层 := _确保状态图标层(演员)
	for 类型 in 类型表:
		层.减(int(类型))
		if int(类型) == 态隐身:
			_置隐身(演员, 角色号, false)
		elif int(类型) == 态变暗:
			_置变暗(演员, 1.0)		# `:737` Darkness.clearupFrom


## 自己的那具身体走 `_player`，别人走 `_remote_players[角色号]`（键 = 服务端 character_id）。
func _按角色号找演员(角色号: int) -> Node2D:
	if 角色号 <= 0:
		return null
	if _backend != null and 角色号 == int(_backend.get("character_id")):
		return _player if is_instance_valid(_player) else null
	return _remote_players.get(角色号) as Node2D


func _确保状态图标层(演员: Node2D) -> Node:
	var 层 := 演员.get_node_or_null(状态图标层脚本.节点名)
	if 层 != null:
		return 层
	var 件 := 状态图标层脚本.new()
	件.name = 状态图标层脚本.节点名
	演员.add_child(件)
	return 件


## 隐身：原版 `isDarkSight = true` 之后，别人对他的三件事同时成立 ——
## ① 不能被选中当目标（`TargetHandler:261` `param1 is Character && isDarkSight` ⇒ 直接 return）；
## ② 不能当技能目标（`SkillHandler:465` `_loc3_ &&= !isDarkSight`）；
## ③ 身上那三圈光环整圈透明（`Character.tickAura:1080/1097/1114` = **连斩 / 神器 / 铃** 那三圈）。
## 这边①③能落地：①清掉选中；③那三圈**远程玩家我们本来就没画**（连斩只接了自己那一支，
## 神器/铃整件没移植）⇒ 没有可藏的东西，**不许拿"打坐光环"凑数** ——
## 打坐那圈走的是 `tickHealAnimation:2742-2762`，原版那一支**没有** isDarkSight 条件。
## 旗子记在 `_隐身角色`（**不挂中文 meta 键** —— Godot 4 的 metadata 键要合法标识符，中文静默存不进）。
func _置隐身(演员: Node2D, 角色号: int, 是: bool) -> void:
	if 是:
		_隐身角色[角色号] = true
	else:
		_隐身角色.erase(角色号)
	if 是 and is_instance_valid(_selected_character) and _selected_character == 演员:
		_clear_selected_character()


## 变暗只作用在**身体动画**那一个 DisplayObject 上（原版 `characterAnimation`），
## 不许整具一起暗 —— 名字牌与头顶状态图标在原版是兄弟节点、不受滤镜影响。
func _置变暗(演员: Node2D, 系数: float) -> void:
	var 精灵 := 演员.get_child(0) as CanvasItem
	if 精灵 == null:
		return
	精灵.modulate = Color(系数, 系数, 系数, 1.0)


## 某个角色的头顶锚点（本地那具走 `player_sprite`，别人走 `get_child(0)`，与 `_钉远程头顶挂件` 同一口径）。
func _角色头顶锚点(演员: Node2D) -> float:
	if 演员 == null:
		return 0.0
	var 精灵: Node2D = null
	if 演员 == _player:
		精灵 = _player.get("player_sprite") as Node2D
	else:
		精灵 = 演员.get_child(0) as Node2D
	if 精灵 != null and 精灵.has_method("当前贴图高度"):
		return float(精灵.call("当前贴图高度"))
	return 0.0


## 往**任意一具**角色头顶飘一行字（原来那条 `_飘玩家头顶字` 写死了 `_player`，PVP 那一支要打在别人头上）。
## 队仍是"每个角色一条 400 毫秒队"（`Character.as:588-601` + `:2591-2598` ⇒ 同一人错开、不同人互不等待）。
func _飘字到演员(演员: Node2D, 锚点: float, 数值: int, 文字前缀 := "", 颜色 := Color.WHITE) -> void:
	if 演员 == null or not is_instance_valid(演员):
		return
	var 朝左 := int(演员.get("facing")) < 0 if 演员.get("facing") != null else false
	var 动作 := func() -> void:
		if not is_instance_valid(演员):
			return
		var 数字 := 伤害数字脚本.new() as Node2D
		演员.add_child(数字)
		数字.call("播放", 锚点, 数值, 文字前缀, 颜色, 朝左, true, false)
	飘字队列脚本.排队于(演员, 动作)


## 1329 玩家打玩家。原版 `applyPlayerSkillHit` 的可见部分逐条搬（顺序也不许换）：
## ① 状态没生效（`skillTrigger=false`）⇒ 先飘那行**蓝色流水字**（`:355-359`）；
## ② 伤害那一行：暴击且被打的是自己 ⇒ 「致命」，暴击且是别人 ⇒ 「暴击」，否则空前缀（`:394-408`）；
## ③ `damage > 0` ⇒ 受击特效挂在被打者身上（`:410-432`）。
func _on_pvp_damage(信息: Dictionary) -> void:
	var 被打号 := int(信息.get("victim_id", 0))
	var 演员 := _按角色号找演员(被打号)
	if 演员 == null:
		return
	var 伤害 := int(信息.get("damage", 0))
	var 招号 := int(信息.get("skill_id", 0))
	var 锚点 := _角色头顶锚点(演员)
	var 生效: bool = bool(信息.get("skill_trigger", false))
	if not 生效:
		var 流水 := String(GAME_DATA.skill_flow_text(招号))
		if 流水 != "":
			_飘字到演员(演员, 锚点, 0, 流水, Color(50.0 / 255.0, 153.0 / 255.0, 1.0))
	var 是我 := _backend != null and 被打号 == int(_backend.get("character_id"))
	if bool(信息.get("bsk", false)) and 伤害 > 0:
		_飘字到演员(演员, 锚点, -absi(伤害), "致命" if 是我 else "暴击", Color(1.0, 0.0, 0.0))
	elif 伤害 > 0:
		_飘字到演员(演员, 锚点, -absi(伤害), "", Color(1.0, 0.0, 0.0))


## 1330 别人看到的血条。原版 `Client:5977-5985`：**是自己的那条直接丢**（自己走 34 状态帧）；
## 别人的 ⇒ `setHpBarValue(hp,maxhp)` + `showHpBar(true)`，而 `showHpBar` 里那条 10 秒定时器
## 一收到就重开（`Character.as:1531-1534`）⇒ 与怪侧同一口径，只在"刚被打"那 10 秒里显形。
func _on_player_hp(角色号: int, 最大hp: int, hp: int) -> void:
	_挂远程血条(角色号, 最大hp, hp)


## 203 队伍成员状态帧。原版 `RelationShipHandler.onUpdatePartyMemberStats:82-93` 两件事：
## ① `troopHPPane.updateSingleData(...)`（那扇"队伍"窗的每一行血蓝条 —— 本工程整扇没做，见 #322）；
## ② **不是自己**才 `CharacterHandler.setCharHp(charId,currHp,maxHp)` ⇒ 与 1330 同一条落点。
## 数据先记进 `_队伍成员状态`（键 = 服务端角色号），那扇窗建起来时直接读它，不另立第二份状态。
func _on_party_member_stats(角色号: int, hp: int, 最大hp: int, mp: int, 最大mp: int) -> void:
	_队伍成员状态[角色号] = {"hp": hp, "maxhp": 最大hp, "mp": mp, "maxmp": 最大mp}
	if _backend != null and 角色号 == int(_backend.get("character_id")):
		return
	_挂远程血条(角色号, 最大hp, hp)


func _挂远程血条(角色号: int, 最大hp: int, hp: int) -> void:
	var 演员 := _按角色号找演员(角色号)
	if 演员 == null:
		return
	var 条 := _确保远程血条(演员)
	var 比例 := 0.0
	if 最大hp > 0:
		比例 = clampf(float(hp) / float(最大hp), 0.0, 1.0)
	条.call("set_比例", 比例)
	条.visible = true
	_远程血条[角色号] = CombatActorScript.血条停留秒
	_钉远程血条位置(演员, 条)


func _确保远程血条(演员: Node2D) -> Node:
	var 条 := 演员.get_node_or_null("HpBar")
	if 条 != null:
		return 条
	var 件 := 怪物血条脚本.new()
	件.name = "HpBar"
	件.visible = false
	演员.add_child(件)
	return 件


## `Character.as:1526-1527`：`x = -BAR_WIDTH/2`、`y = -_crtCharHeight - BAR_HEIGHT - 2`
## （与怪侧 `Monster.as:838-840` 同一条式子，只是基准从 `mobBmdHeight` 换成"当帧贴图高"）。
func _钉远程血条位置(演员: Node2D, 条: Node) -> void:
	var 高 := _角色头顶锚点(演员)
	if 高 <= 0.0:
		return
	条.position = Vector2(-怪物血条脚本.宽 * 0.5, -高 - 怪物血条脚本.高 - 2.0)


## 每帧把 10 秒倒计时往下掉（挂在已有的 `_推进远程头顶挂件` 之后，见 `_process`）。
func _推进远程血条(帧长: float) -> void:
	if _远程血条.is_empty():
		return
	for 角色号 in _远程血条.keys():
		var 剩 := float(_远程血条[角色号]) - 帧长
		var 演员 := _按角色号找演员(int(角色号))
		if 演员 == null or not is_instance_valid(演员):
			_远程血条.erase(角色号)
			continue
		if 剩 <= 0.0:
			var 条 := 演员.get_node_or_null("HpBar")
			if 条 != null:
				(条 as CanvasItem).visible = false
			_远程血条.erase(角色号)
			continue
		_远程血条[角色号] = 剩
		if 演员 != null:
			_钉远程血条位置(演员, 演员.get_node_or_null("HpBar"))


func _build_runtime_entities(life_entries: Array) -> void:
	for index in range(life_entries.size()):
		var entry: Dictionary = life_entries[index]
		_spawn_life_entry(entry, index, false)

func _spawn_life_entry(entry: Dictionary, index: int, from_server: bool) -> CombatActor:
	var footholds := get_parent().get_node_or_null("Footholds")
	var kind := String(entry.get("type", "n"))
	var entity_id := String(entry.get("id", "0"))
	var x := float(entry.get("x", 0.0))
	var y := float(entry.get("y", 0.0))
	if not from_server and footholds != null and footholds.has_method("find_below"):
		var hit: Dictionary = footholds.find_below(x, y - 220.0, y + 1400.0)
		if not hit.is_empty():
			y = float(hit.get("y", y))
	var actor := CombatActorScript.new() as CombatActor
	actor.name = "Life_%03d_%s_%s" % [index, kind, entity_id]
	# 权威怪要按服务端包里的脚点贴地（`战斗角色._贴脚点`）。离线怪走自己的地面物理，用不上。
	actor.地表 = footholds
	# 离线复活要拿它重新生成一只（键必须 ASCII —— Godot 的 set_meta 只认 ASCII，中文键会静默不写）。
	actor.set_meta("life_entry", entry)
	actor.position = Vector2(x, y)
	add_child(actor)
	var sprite := OriginalSpriteScript.new()
	sprite.name = "Sprite"
	actor.add_child(sprite)
	var 对手: Dictionary = entry.get("对手", {}) as Dictionary
	var sprite_kind := "npc" if kind == "n" else "mob"
	if 对手.is_empty():
		sprite.configure(sprite_kind, entity_id, "stand")
	elif not sprite.configure("character", 角色造型.造型号(int(对手.get("face", 0)), 0), "stand"):
		## 头像号解不出身体（老档 face=0、或那张没导）⇒ **退回怪物**，别画成一团空气。
		sprite.configure(sprite_kind, entity_id, "stand")
	_configure_actor(actor, sprite, entry)
	if from_server:
		var object_id := int(entry.get("object_id", 0))
		var definition := GAME_DATA.monster(entity_id) if kind == "m" else {}
		actor.configure_authoritative(object_id, int(definition.get("max_hp", 100)), entry.get("jingying", []))
		_entities_by_object[object_id] = actor
	return actor

func _configure_actor(actor: CombatActor, sprite: Node2D, entry: Dictionary) -> void:
	var kind := String(entry.get("type", "n"))
	var entity_id := String(entry.get("id", "0"))
	var display_name := "怪物" if kind == "m" else "NPC"
	var 对手名 := String((entry.get("对手", {}) as Dictionary).get("name", ""))
	if not 对手名.is_empty():
		display_name = 对手名
	elif _session != null:
		if kind == "n":
			display_name = String((_session.call("get_npc_info", entity_id) as Dictionary).get("name", display_name))
		else:
			display_name = String(_session.call("get_mob_name", entity_id))
	var left := actor.position.x - 130.0
	var right := actor.position.x + 130.0
	if kind == "m":
		var 范围 := _怪物行走范围(actor)
		left = float(范围[0])
		right = float(范围[1])
	actor.configure_actor(kind, entity_id, display_name, sprite, left, right)
	actor.z_index = _角色层次(actor.position)
	if kind == "m":
		# 离线怪：把 `数据/怪物.json` 里那套 AI 参数（`area`/`areaChase`/`firstAttack`/`speed`…）
		# 交给 `MonsterAI`。权威（服务端）怪在 `configure_authoritative` 里会把 AI 撤掉。
		actor.configure_monster_ai(GAME_DATA.monster(entity_id), actor.position, left, right)
		# 精英属性要留给伤害/血量公式用（`战斗结算.精英倍率`、`最大血量`）。
		actor.精英属性 = entry.get("jingying", [])
		## 脚下那圈光环 + 名字下面那排强化图标。**必须排在 `精英属性` 赋好之后**：
		## 图标排的枚数就是按那份列表算的（原版 `Monster.as:652-665`），先建后填等于让门自证。
		_挂精英外观(actor, entity_id)
		## `attackedByMob`（原版 `MonsterSpawnInfo.as:46`，出生帧读到的那个布尔）。
		## 挂机挑怪要排掉它 —— `SkillHandler.canAttack:447-450`：这一位为真的怪**直接不打**
		## （它已经咬上别的怪/别人了）。以前整段没解，所以这条闸等于不存在。
		actor.set_meta("attacked_by_mob", bool(entry.get("attacked_by_mob", false)))
		## `isPetMonster`（原版 `Monster.as:1652`
		## `_isPetMonster = Boolean(_mobData.info) && Boolean(_mobData.info.petLink) && _mobData.info.petLink > 0`）。
		## 消费者 = `SkillHandler.canAttack:455`：宠物怪**不进**取 `_loc3_` 的那一支 ⇒ canAttack 恒假
		## ⇒ 挂机永不去咬**别人放的通灵兽**（10-19 第 6 条；meta 名照原版语义 `is_pet_monster`，
		## meta 键必须 ASCII，见本文件 1695 行那条旧警告）。
		actor.set_meta("is_pet_monster", _是宠物怪定义(entity_id))
		actor.died.connect(_on_enemy_died)
	# 怪物也要能点选（原版 `Monster.onMouseSelect():697-728` → `targetHandler.setCurTarget(this, true)`
	# → 头顶出选中箭头 + 角色走向目标并持续攻击）。以前**怪物身上什么都没挂**：
	# 点它没反应、也没法选中目标 —— 用户 2026-09-27 报的"不能鼠标选择攻击目标"就是这个。
	_attach_selection_marker(actor)
	if kind == "m":
		_add_monster_interaction(actor, entity_id)
	_entities.append(actor)
	_add_nameplate(actor, display_name, kind, entity_id)

## ── "这是不是宠物怪"（`isPetMonster` 的工程侧对照）────────────────────────
## ⚠ 查了个遍：客户端这份 `数据/怪物.json`（`GAME_DATA.monster()` 的表）**没有导出 `info.petLink`
## 这一列**（全表 1574 条零命中），服务端 162 出生帧也不带这一位 ⇒ 与原版 `Monster.as:1652`
## 逐字同口径的字段在本工程**不存在**，于是按 10-19 口径"在创建那只怪的地方补一个字段"
## （上面 `_configure_actor` 里的 `set_meta("is_pet_monster", …)`）。
## 数据源用的是 `数据/怪物动画索引.json` 的 `source_kind == "pet"` 那 18 条（4000000-4000017）：
## 这张表就是从**原版 GameData 的 `info.petLink`** 导出来的
## （`开发工具/导入怪物动画.mjs:41-47`：`if (帧缺失.length > 0 && Number(怪物.info?.petLink || 0) > 0)`
##   ⇒ `resolution = "petLink" / "petLink-fallback"`，注释原文"petLink=101-104 对应的宠物动画"）
## ⇒ 与原版 `_mobData.info.petLink > 0` 是**同一份数据的两种导出**，不是靠名字猜。
## 表里查不到这一条 = 不是宠物怪（查不到**不补默认**、不猜）。
var _宠物怪表: Dictionary = {}
var _宠物怪表已读 := false

func _是宠物怪定义(entity_id: String) -> bool:
	if not _宠物怪表已读:
		_宠物怪表已读 = true
		var 文 := FileAccess.get_file_as_string("res://数据/怪物动画索引.json")
		var 解: Variant = JSON.parse_string(文) if 文 != "" else null
		if 解 is Dictionary:
			for 号 in (解 as Dictionary):
				var 条: Variant = (解 as Dictionary)[号]
				if 条 is Dictionary and String((条 as Dictionary).get("source_kind", "")) == "pet":
					_宠物怪表[str(号)] = true
	return _宠物怪表.has(entity_id)

## 离线怪的行走挡板 = 它脚下那段脚点**连同 prev/next 链**的 x 跨度。
##
## 真值：原版靠脚点的 `leftBlock`/`rightBlock`（实际碰撞）停住，走到平台边就反身
## （`FreeExecute.MoveFreeLogic` 读的就是它）。离线这条路径没有碰撞体，
## 用脚点链两端的 x 顶替 —— **这是近似，不是原版那套碰撞**；取不到脚点就退回原来的 ±130。
func _怪物行走范围(actor: Node2D) -> Array:
	var 兜底 := [actor.position.x - 130.0, actor.position.x + 130.0]
	var footholds := get_parent().get_node_or_null("Footholds")
	if footholds == null or not footholds.has_method("find_click_target"):
		return 兜底
	var 段号 := String((footholds.call("find_click_target", actor.position) as Dictionary).get("id", ""))
	if 段号 == "":
		return 兜底
	var 最小 := INF
	var 最大 := -INF
	var 待 := [段号]
	var 走过 := {}
	while not 待.is_empty():
		var 当前 := String(待.pop_back())
		if 走过.has(当前) or not footholds.id_map.has(当前):
			continue
		走过[当前] = true
		var 段: Dictionary = footholds.id_map[当前]
		最小 = minf(最小, minf(float(段.x1), float(段.x2)))
		最大 = maxf(最大, maxf(float(段.x1), float(段.x2)))
		for 邻 in [段.prev, 段.next]:
			if 邻 != "" and 邻 != "0" and 邻 != "-1":
				待.append(String(邻))
	if not is_finite(最小) or not is_finite(最大) or 最大 - 最小 < 8.0:
		return 兜底
	return [最小, 最大]

## 点怪选中。和 NPC 的交互区同一套做法（同一个矩形、同一个手型光标）。
func _add_monster_interaction(actor: CombatActor, entity_id: String) -> void:
	if actor.get_node_or_null("MonsterInteractionArea") != null:
		return
	var area := Area2D.new()
	area.name = "MonsterInteractionArea"
	area.input_pickable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(90.0, 110.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -46.0)
	area.add_child(shape)
	area.input_event.connect(_on_monster_input.bind(actor, entity_id))
	area.mouse_entered.connect(_on_npc_mouse_entered.bind(area))
	area.mouse_exited.connect(_on_npc_mouse_exited.bind(area))
	actor.add_child(area)

func _on_monster_input(_viewport: Node, event: InputEvent, _shape_idx: int, actor: CombatActor, _entity_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		## 原版 `Monster.onMouseSelect():705-728`：**点的是野宠就不打，走捕捉那条**
		## （`getCanPetMonsterCapture()` 0=捕捉 / 1=等级不够 / 2=别人爆的）。
		var 宠号 := _宠物号(_entity_id)
		if 宠号 > 0:
			_开始捉宠(actor, 宠号)
			get_viewport().set_input_as_handled()
			return
		_select_character(actor, _monster_selection_info(actor))
		# 选中之后**起一条一次性的自动接近命令**（用户口径：手动一动就取消，选中保留）。
		if _player != null and _player.has_method("开始自动接近"):
			_player.call("开始自动接近", actor)
		get_viewport().set_input_as_handled()

## 目标信息框里的怪物。真值在 `Client.onTargetInfo()`（`Client.as:6969-7010`）的 `type == 0` 分支：
##   · `name = monster.getMobName()` —— **就是怪名，不带" N级"后缀**（那个后缀是**世界名牌**上的）；
##   · `level = monster.mobInfo.level`，框里渲染成 `"LV." + level`（`DetailsWindow.setData():236`）；
##   · `mp = 1; maxMp = 1` —— 原版对怪物是**写死 1/1** 的（怪物没有查克拉条）；
##   · `hp/maxHp` 来自 `TargetInfo` 包，并且每次挨打由 `UI.setTargetWindowHp()` 增量刷新。
## ⚠️ 头像（`setPic()` → `PortraitHead(TYPE_MONSTER).skin = 怪id`）**我们现在拿不到**：
##    要 `Mob_<id>_info_portrait` 这张图 + 元数据 `info.portrait` —— 两样都没导出（见 §3.56.12）。
## 怪物模板 → 通灵兽模板（原版 `monster.info.petLink`）。工程导出的 `数据/怪物.json` 没这一列，
## 小表单独放 `数据/界面/可捕捉怪.json`（18 条，来源见文件头）。
static var _可捕捉怪表: Dictionary = {}


func _宠物号(entity_id: String) -> int:
	if _可捕捉怪表.is_empty():
		var 原 := FileAccess.get_file_as_string("res://数据/界面/可捕捉怪.json")
		var 解 = JSON.parse_string(原)
		if 解 is Dictionary and (解 as Dictionary).get("表") is Dictionary:
			for k in ((解 as Dictionary)["表"] as Dictionary):
				_可捕捉怪表[int(String(k))] = int((解 as Dictionary)["表"][k])
	return int(_可捕捉怪表.get(int(entity_id), 0))


## 点野宠 → 捉宠。原版 `Monster.onMouseSelect()` + `TargetHandler.gotoCapturePet()`：
## 先验等级（`getCanPetMonsterCapture():1208-1225`，`carryLevel`），再停挂机、设成"看的目标"
## （不攻击），然后交给 `捉宠流程`（走过去 → 屏幕中央读条 5 秒 → `requestCatchPet`）。
func _开始捉宠(actor: CombatActor, 宠号: int) -> void:
	var 模板 := GAME_DATA.pet_template(宠号)
	var 信息: Dictionary = 模板.get("info", {})
	var 需要 := int(信息.get("carryLevel", 0))
	var 等级 := 0
	if _backend != null:
		等级 = int((_backend.get("authoritative_stats") as Dictionary).get("level", 0))
	if 等级 < 需要:
		if _session != null:
			_session.notification_requested.emit("你当前等级不能捕捉该通灵兽")
		return
	## 停挂机：原版 `gotoCapturePet` 第一句 `API.guajiHandler.isStart = false`。
	## 托管是玩家身上的子节点（`玩家._托管`），走它现成的唯一出口，不另翻状态。
	if is_instance_valid(_player):
		var 托 = _player.get("_托管")
		if 托 != null and is_instance_valid(托) and (托 as Object).has_method("请求停挂机"):
			(托 as Object).call("请求停挂机")
	_select_character(actor, _monster_selection_info(actor))
	_取捉宠().call("开始", _player, actor, _backend, _session)


## 捉宠进度条挂在**屏幕层**（原版 `positionCaptureLoading` 放 stage 正中）；层随地图场景释放。
var _捉宠层: CanvasLayer
var _捉宠: Control


func _取捉宠() -> Control:
	if is_instance_valid(_捉宠):
		return _捉宠
	_捉宠层 = CanvasLayer.new()
	_捉宠层.name = "捉宠层"
	_捉宠层.layer = 260
	add_child(_捉宠层)
	_捉宠 = 捉宠流程脚本.new() as Control
	_捉宠.name = "捉宠流程"
	_捉宠层.add_child(_捉宠)
	return _捉宠


func _monster_selection_info(actor: CombatActor) -> Dictionary:
	return {
		"name": actor.display_name,
		"level_text": "LV.%d" % _怪物等级(actor.entity_id),
		"hp": actor.hp,
		"max_hp": maxi(1, actor.max_hp),
		"mp": 1,
		"max_mp": 1,
		"portrait": OriginalSpriteScript.portrait("mob", actor.entity_id),
		## `type` = 原版 `DetailsWindow.setData()` 的 `param1.type`（`setPic():383-405` 的六档）：
		## 0 怪、1 玩家、2 NPC。**`hideBtn():287-298` 只认 1** ⇒ 这一档决定那排钮显不显。
		"type": 0, "char_id": 0, "level": _怪物等级(actor.entity_id),
	}

## 选中的目标掉血就刷新目标框。
## 原版：`MonsterHandler.showMobHp()` → `API.ui.setTargetWindowHp(-damage)`（`UI.as:834-837`）。
## 原来只在**点选那一刻**取一次快照，之后打多久框里的血都不动（用户实机报的"血量不对"）。
## 这里用"血量变了才发"的轮询而不是逐处埋点：在线（服务端血量包）与离线（本地扣血）
## 两条路都会经过 `actor.hp`，埋点会漏掉其中一条 —— 而漏掉的那条正是离线。
func _process(_delta: float) -> void:
	_推进去捡(_delta * 1000.0)
	_拍进场钟(_delta * 1000.0)
	_推进掉落动画(_delta)
	_推进远程玩家(_delta)
	_双修对坐()
	_推进赶路双修()
	## 箭头要**每帧**跟着贴图高抬（站立/跳/爬三档的帧高不同）。放在 `_session` 早退之前：
	## 离线量具里没有会话，但选中箭头照样要落在头顶。
	_推进远程头顶挂件()
	_推进远程血条(_delta)
	for 编号 in _待删外推:
		_远程外推.erase(编号)
	_待删外推.clear()
	if _家族标示待刷:
		# 家族数据是 `guild_state_received` 广播推进来的，帧末统一读 `会话.guild` ——
		# 回调当场读可能拿到旧值（广播时序不保证，见函数上面的注释）。
		# 忍术境界（技能层数）与写轮眼状态也走同一条延迟刷：同一个头顶图标排。
		_家族标示待刷 = false
		_刷新状态图标()
	if _session == null:
		return
	## 远程玩家离场后那份登记要丢掉（键是被释放的 Node，留着会一直占着）。
	if not _远端状态.is_empty():
		for 演员 in _远端状态.keys():
			if not is_instance_valid(演员):
				_远端状态.erase(演员)
	if not is_instance_valid(_view_target):
		_选中目标上次血量 = -1
		_选中目标上次蓝量 = -1
		return
	## 原版：怪掉血 `MonsterHandler.showMobHp() → UI.setTargetWindowHp()`，玩家掉血走
	## `Character` 自己那份 hp ⇒ **两条都要刷**。这里用"值变了才发"的轮询覆盖在线/离线两路
	## （埋点会漏掉其中一条）。
	if str(_view_target.get("kind")) == "m":
		var 目标 := _view_target as CombatActor
		if 目标.hp != _选中目标上次血量:
			_选中目标上次血量 = 目标.hp
			_session.call("select_map_character", _monster_selection_info(目标))
		return
	var 记: Dictionary = _远端状态.get(_view_target, {}) as Dictionary
	if 记.is_empty():
		return
	var 态: Dictionary = 记.get("态", {}) as Dictionary
	var 血 := int(态.get("hp", 0))
	var 蓝 := int(态.get("mp", 0))
	if 血 != _选中目标上次血量 or 蓝 != _选中目标上次蓝量:
		_选中目标上次血量 = 血
		_选中目标上次蓝量 = 蓝
		_session.call("select_map_character",
				_remote_player_selection_info(记.get("画") as Node2D, 态))

## 当前选中的怪（没有选中 / 选中的是 NPC 就返回 null）。`玩家` 每帧拿它决定"要不要走向它并打"。
## 换目标框显示的那只（`viewTarget`）。点怪、挂机挑怪、技能命中都走这里。
##
## ⚠ 用户 2026-10-19 实机报「挂机自动打怪时，被打的那只怪头上没有原版那个蓝色箭头」：
##   箭头是**跟着 viewTarget 显隐**的（`TargetHandler.as:259-276` 换对象时先给旧的
##   `showViewTargetEffect(false)`、再给新的 `showViewTargetEffect(true)`；怪那一侧就是
##   `Monster.as:799-816` 那对 add/removeChild(`MobSelected_Effect_Skin`)），
##   而原版挂机锁定目标用的正是同一句 `targetHandler.viewTarget = monster`
##   （`GuajiHandler.as:833`）。本工程以前**只有点选那一条路**把标记显出来（`_select_character`），
##   挂机这条只改了 `_view_target` ⇒ 目标框/血刷了，箭头不出现。现在两条都走这里。
func 显示目标框(actor: Node2D, 重发信息 := false) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if str(actor.get("kind")) != "m":
		return
	if _view_target == actor and not 重发信息:
		return				# 原版 `:261` 同一句：还是同一只就整段跳过（不重摆、不重发）
	var 旧: Node2D = _view_target if is_instance_valid(_view_target) else null
	_view_target = actor
	if 旧 != actor:
		_摆头顶箭头(旧, false)
	_摆头顶箭头(actor, true)
	_选中目标上次血量 = -1
	if _session != null:
		_session.call("select_map_character", _monster_selection_info(actor as CombatActor))
	## `TargetHandler.as:279-282`（**同一个 viewTarget setter** 里）：
	## `else if (param1 is Monster) API.client.requestTargetMonsterInfo(param1.objectId);`
	## —— 原版换目标框的每一跳都发这一发上行，服务端回 `TARGET_INFO(1284)` 的怪档
	## （`fake_flash_server.py:20247-20253` `action == 3` ⇒ `1284:<oid>:0:<模板号>:<hp>:<maxHp>:0:0`）。
	## 上行走**手动点怪已在用的同一个出口**（这里就是点怪/挂机挑怪的唯一收口，
	## 挂机侧 `摆看住的目标 → 显示目标框` 复用，不许有第二份）；包体对照
	## `Client.as:2019-2024` → `AllInOneProcessor.as:1431-1437`：`writeByte(3) + writeInt(objectId)`
	## ⇒ `94:3:<object_id>`（与玩家那一发 `94:4`（`request_character_info`）同族第 3 支）。
	## 只对**在线怪**（有服务端 object_id）发；离线怪没有 objectId，原版那条路压根不存在 ⇒ 不发。
	if _backend != null and bool(_backend.get("in_game")):
		var 对象号 := int((actor as CombatActor).object_id)
		if 对象号 > 0:
			_backend.call("request_target_monster_info", 对象号)


## 摆/摘头顶那枚选中箭头（= 原版 `showViewTargetEffect(显)`）。
## 怪在生成时就预挂了 `SelectionMarker`（`:459`、`:1752` 两处 `_attach_selection_marker`），
## 拿不到再当场挂一个 —— 挂机挑中的怪有可能是别的代码路径建的，不能因为没预挂就静默不显。
func _摆头顶箭头(谁: Node2D, 显: bool) -> void:
	if 谁 == null or not is_instance_valid(谁):
		return
	var 件 := 谁.get_node_or_null("SelectionMarker") as Node2D
	if 件 == null:
		if not 显:
			return
		件 = _attach_selection_marker(谁)
	件.visible = 显
	if 显 and 谁.has_method("_更新头顶挂件位置"):
		谁.call("_更新头顶挂件位置")

func get_selected_enemy() -> Node2D:
	if not is_instance_valid(_selected_character) or not _selected_character.visible:
		return null
	if str(_selected_character.get("kind")) != "m":
		return null
	return _selected_character as Node2D

## NPC / 怪物在世界的 z。原版把它们也放进 `ALayer[脚点层号]`（`NPC.as:168`
## `ALayerManager.getALayer(currFoothold.index1)`、`Character.as` 同），层内按 foothodY
## 排 —— 与玩家同一套。以前 LifeRoot 的实体 z_index 是默认 0，落在层带最底下，
## 于是被同层的**装饰物**和地面一起盖住。
func _角色层次(位置: Vector2) -> int:
	var 脚点 := get_parent().get_node_or_null("Footholds")
	if 脚点 == null:
		return RenderProfile.角色z(0, 128)
	var 命中: Dictionary = 脚点.call("find_foothold", 位置.x, 位置.y, "")
	var id := String(命中.get("id", ""))
	return 脚点.call("角色z", id, 位置.y)

func _on_enemy_died(actor: CombatActor) -> void:
	if _session == null:
		return
	if _server_authoritative:
		return
	var defeated_name := String(actor.get_meta("original_display_name", actor.display_name))
	_session.call("progress_quest", defeated_name)
	_session.call("progress_quest", actor.entity_id)
	if _activity != null:
		_activity.progress_ruins()
	if bool(actor.get_meta("activity_boss", false)):
		if _activity != null:
			_activity.complete_boss_challenge()
		_restore_boss_actor(actor)
	_create_loot(actor.global_position)
	_entities.erase(actor)
	_排下一只(actor)

## 离线模式下的"再刷一只"。
## ⚠️ 原版**没有客户端复活**这回事：`怪物死了就整只消失`，什么时候再出是服务端说了算
## （`fake_flash_server.py:11074-11076` `NORMAL 10 / ELITE 20 / BOSS 60` 秒），
## 客户端只会收到一条新的生成包。离线没有服务端，这里就**按服务端那套延时补上这一环**，
## 而且必须是**重新生成一只新的**（不是把原来那只藏起来再放出来 —— 那会留下一堆
## "名字牌/血条还挂在场上"的尾巴，用户 2026-09-27 报的第 5 条就是这么来的）。
## 精英那档（20 秒）离线拿不到精英属性，只能给普通档的 10 秒。
func _排下一只(actor: CombatActor) -> void:
	if _server_authoritative:
		return
	var 条目 = actor.get_meta("life_entry", {})
	if not 条目 is Dictionary or (条目 as Dictionary).is_empty():
		return
	var 延时 := 60.0 if _is_boss(actor) else 10.0
	await get_tree().create_timer(延时).timeout
	if not is_inside_tree():
		return
	var 序号 := _entities.size()
	_spawn_life_entry((条目 as Dictionary).duplicate(true), 序号, false)

func start_boss_encounter() -> bool:
	if _activity == null or not _activity.start_boss_challenge():
		return false
	var boss: CombatActor
	for entity in _entities:
		if is_instance_valid(entity) and entity.kind == "m" and entity.alive:
			boss = entity as CombatActor
			break
	if boss == null:
		_activity.cancel_boss_challenge()
		_session.notification_requested.emit("当前地图没有可挑战的首领载体")
		return false
	boss.set_meta("activity_boss", true)
	boss.set_meta("original_display_name", boss.display_name)
	boss.set_meta("original_spawn_position", boss.spawn_position)
	boss.set_meta("original_home_left", boss.home_left)
	boss.set_meta("original_home_right", boss.home_right)
	boss.display_name = "%s首领" % boss.display_name
	boss.max_hp = 600
	boss.hp = 600
	if _player != null:
		boss.position = _player.position + Vector2(150.0, 0.0)
		boss.home_left = _player.position.x - 220.0
		boss.home_right = _player.position.x + 220.0
	var nameplate := boss.get_node_or_null("Nameplate") as Label
	if nameplate != null:
		nameplate.text = boss.display_name
	var hp_bar := boss.get("_hp_bar") as ProgressBar
	if hp_bar != null:
		hp_bar.max_value = boss.max_hp
		hp_bar.value = boss.hp
	_session.notification_requested.emit("首领已在附近出现")
	return true

func _restore_boss_actor(actor: CombatActor) -> void:
	actor.max_hp = 120
	actor.display_name = String(actor.get_meta("original_display_name", "守财鼠"))
	actor.spawn_position = actor.get_meta("original_spawn_position", actor.spawn_position)
	actor.home_left = float(actor.get_meta("original_home_left", actor.home_left))
	actor.home_right = float(actor.get_meta("original_home_right", actor.home_right))
	actor.remove_meta("activity_boss")
	actor.remove_meta("original_display_name")
	actor.remove_meta("original_spawn_position")
	actor.remove_meta("original_home_left")
	actor.remove_meta("original_home_right")
	var nameplate := actor.get_node_or_null("Nameplate") as Label
	if nameplate != null:
		nameplate.text = actor.display_name
	var hp_bar := actor.get("_hp_bar") as ProgressBar
	if hp_bar != null:
		hp_bar.max_value = actor.max_hp

## 本地打怪掉的战利品。
##
## ⚠️ 原来这里是**一个写着「拾取 +5 金币」的 `Button`** —— 纯自造（§3.61.4 待办第 6 条：
## "原版掉落物是图标本体 + 名字标签"）。现在走**和服务端掉落完全相同**那条
## `_create_drop_node()`：图标（`PicTool.getMesoPic(数量)` 那四档钱堆）、常显名字
## `<数量>金币`、出场抛物线 + 拾取上浮两段动画，全都一致。
##
## ⚠️ 两处**保留为自定**（本地没有服务端可依）：
##   1. 金币数量固定 `离线掉落金币`（原版是服务端 `_itemid`）；
##   2. 15 秒后自动消失（原版由服务端决定什么时候移除，本地得自己收，否则地图上越堆越多）。
func _create_loot(world_position: Vector2) -> void:
	var 编号 := _离线掉落序号
	_离线掉落序号 -= 1
	var 状态 := {
		"object_id": 编号, "is_meso": true, "item_id": 离线掉落金币,
		"item_name": "", "owner_id": 0,
		"x": world_position.x, "y": world_position.y,
		# 起落同点 ⇒ 不划弧，就地出现（原版 `from` 是怪物身上、落点另算，本地没有那个信息，
		# 与其编一个落点，不如就地 —— 见上面第 1 条）。
		"from_x": world_position.x, "from_y": world_position.y,
		"drop_mode": 0,
	}
	var 掉 := _create_drop_node(状态, 编号, true)
	get_parent().add_child(掉)
	_server_drops[编号] = 掉
	var 收 := get_tree().create_timer(15.0).timeout
	收.connect(func() -> void:
		if is_instance_valid(掉) and _server_drops.has(编号):
			_移除掉落(编号, 掉)
	)

func _on_settings_changed(settings: Dictionary) -> void:
	var show_names := bool(settings.get("show_names", true))
	if _player != null:
		var player_nameplate := _player.get_node_or_null("Nameplate") as Label
		if player_nameplate != null:
			player_nameplate.visible = show_names
		var family_plate := _player.get_node_or_null("NameplateFamily") as Label
		if family_plate != null:
			family_plate.visible = show_names and not family_plate.text.is_empty()
		# 头顶那一整排状态图标（族徽 / 忍术境界 / 写轮眼）跟名字同隐同显。
		# `PaiHangPane` 是**另一块板**（原版 `_paihangTipPane` 与 `_statusIconPane` 平级），
		# 但 `setNamePaneVisibleExNamePane:2811` 把它列进了同一张跟着名字走的数组 ⇒ 一起过。
		for 图标名 in ["FamilyEmblem", "FamilyEmblemFrame", "SkillJingJieIcon",
				"SkillJingJieIconFrame", "XieLunYanStateIcon", "XieLunYanStateIconFrame",
				"PaiHangPane"]:
			var 图标 := _player.get_node_or_null(图标名) as Node2D
			if 图标 != null:
				图标.visible = show_names
	for actor in _entities:
		if not is_instance_valid(actor):
			continue
		var nameplate := actor.get_node_or_null("Nameplate") as Label
		if nameplate != null:
			nameplate.visible = show_names
		var nameplate_title := actor.get_node_or_null("NameplateTitle") as Label
		if nameplate_title != null:
			nameplate_title.visible = show_names
	for remote_actor in _remote_players.values():
		if is_instance_valid(remote_actor):
			_apply_remote_player_visibility(remote_actor as Node2D, settings)
			if remote_actor == _selected_character and not (remote_actor as Node2D).visible:
				_clear_selected_character()

func _apply_remote_player_visibility(actor: Node2D, settings: Dictionary = {}) -> void:
	if actor == null:
		return
	var current_settings: Dictionary = settings
	if current_settings.is_empty() and _session != null:
		current_settings = _session.game_settings
	actor.visible = bool(current_settings.get("show_other_characters", true))
	var nameplate := actor.get_node_or_null("Nameplate") as Label
	if nameplate != null:
		nameplate.visible = actor.visible and bool(current_settings.get("show_names", true))
	## 别人头顶那摞徽记跟他的名字同一条命（`_刷榜单徽记` 末尾那句是同一口径）。
	var 徽记板 := actor.get_node_or_null("PaiHangPane") as Node2D
	if 徽记板 != null:
		徽记板.visible = nameplate == null or nameplate.visible

func _add_nameplate(actor: CombatActor, display_name: String, kind: String, entity_id: String) -> void:
	# ⚠️ 原版 `NPCSprite.initNPC()` 还会看 `info.hideName == 1` 把名字整块摘掉，但那个字段在
	#    **Npc 的 sprite 数据**里（`PicTool.getNpcObject(skin).info`），我们目前没导出这张表
	#    （`数据/NPC.json` 只有 name/title/dialogue/service）—— 所以这条暂时没实现。
	var 颜色 := _怪物名字颜色(entity_id) if kind == "m" else Color.WHITE
	var 文案 := display_name
	if kind == "m":
		# `Monster.as:1266-1267`：名字 + " " + CHAR_NAME_LEVEL("%1级")
		文案 = "%s %d级" % [display_name, _怪物等级(entity_id)]
	var label := _create_nameplate(actor, 文案,
			actor.get_node_or_null("Sprite") as Node2D,
			颜色, 怪物名字相对脚点 if kind == "m" else 名字相对脚点,
			玩家NPC名字描边 if kind == "n" else 世界名字描边)
	if kind == "n":
		_add_npc_title(actor, entity_id, label)
	if kind == "n" and _session != null:
		_挂任务标记(actor, int(_session.call("npc_quest_status", entity_id)))
	if kind == "n":
		var area := Area2D.new()
		area.name = "NpcInteractionArea"
		area.input_pickable = true
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(90.0, 110.0)
		shape.shape = rect
		shape.position = Vector2(0.0, -46.0)
		area.add_child(shape)
		area.input_event.connect(_on_npc_input.bind(actor, entity_id))
		area.mouse_entered.connect(_on_npc_mouse_entered.bind(area))
		area.mouse_exited.connect(_on_npc_mouse_exited.bind(area))
		actor.add_child(area)

func _ensure_local_player_nameplate() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null or _player.get_node_or_null("Nameplate") != null:
		return
	var sprite := _player.get("player_sprite") as Node2D
	var player_name := "忍者"
	if _session != null:
		player_name = String(_session.player_stats.get("name", player_name)).strip_edges()
	# `Character.as:274`：自己的名字黄 16776960(0xFFFF00)，别人的白 16777215。
	_create_nameplate(_player, player_name if not player_name.is_empty() else "忍者", sprite,
			Color(1.0, 1.0, 0.0), 名字相对脚点, 玩家NPC名字描边)

func _on_player_stats_changed(stats: Dictionary) -> void:
	if _player == null:
		return
	var label := _player.get_node_or_null("Nameplate") as Label
	if label == null:
		_ensure_local_player_nameplate()
		label = _player.get_node_or_null("Nameplate") as Label
	if label != null:
		var player_name := String(stats.get("name", "忍者")).strip_edges()
		label.text = player_name if not player_name.is_empty() else "忍者"


## ── 本地玩家的**家族标示**：名牌下面那行 `[家族]<族名>` + 18×18 族徽 ──────────────
## 真值 `Character.setBangHuiFlagStyle`（`Character.as:1436-1454`，由
## `CharacterHandler.onBanghuiShowInfo` 调，`charId` 是自己 ⇒ **只有自己的角色有**）：
##   · `updateBangHuiName(族名)` ⇒ `_banghuiPane` 在**名字下面一行**
##     （`Character.as:1486`：`_banghuiPane.y = _namePane.y + paneHeight - 6`）；
##   · 族徽 = `PicTool.getJiaHuiPic(样式)`（34×34）缩到 **18/34**、`x=y=1`，
##     加进 `_statusIconPane`（与名字/家族牌同层）；**外面还有一圈 20×20 的
##     `Effect_CharStatus_Kuang` 底框**（`Character.as:1449`，与族旗同款，见 `_刷家族徽框`）。
## ⚠️ 位置口径（2026-10-15 用户并排图纠偏后改）：原版把整块交给
##   `insidePositionStatusIconPane`（`Character.as:706-718`）—— **单个块恒居中在角色身上**
##   （`x = -10*数量`）、`y` 取家族牌**盒的底边 = 牌原点**（`:1501-1505`，称号为空时）。
##   ⚠ 那**不是**文字墨迹底 ⇒ 原点比墨迹底低 4（`名牌行距缝`，账见 `真值/地图/头顶状态图标排.md` ⑤）。
##   本工程原来按"家族牌左侧同一行"摆（贴名牌左沿）⇒ 与单机版并排图一眼不符，已按真值改掉。
## 数据只读 `会话.guild`（自己的家族）；族名/样式随 `1552:4` 广播变。
## ⚠️ `guild_state_received` 是**广播**，`会话` 与本节点谁先收到没有保证 ⇒ 回调里只置标志，
##    帧末（`_process`）再读 `会话.guild`，否则会拿到旧值（`功能窗口` 那段同款教训）。
var _家族标示待刷 := false

func _ensure_local_player_family_marks() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return
	if _player.get_node_or_null("Nameplate") == null:
		_ensure_local_player_nameplate()
	_刷新状态图标()
	## 自己头顶那摞榜单徽记：登录那一帧 `1346:0` 很可能比本地人物入组还早到
	## （服务端 `_send_ranking_title_update()` 就排在 `WARP_TO_MAP` 后面），
	## 信号来的时候这里还没有节点可挂 ⇒ 建好节点补画一次。
	_刷榜单徽记(_player, int(_backend.get("character_id")) if _backend != null else -1)


## 头顶三枚状态图标一起刷：家族族徽 / 忍术境界 / 写轮眼状态。
## 数据源分别是 `会话.guild` / `learned_skills` 层数和 `cultivation_states["写轮眼"]`。
func _刷新状态图标() -> void:
	_刷家族标示()
	_刷忍术境界图标()
	_刷写轮眼图标()
	_排状态图标排()

func _on_guild_state_received(_state: Dictionary) -> void:
	_家族标示待刷 = true

func _刷家族标示() -> void:
	if _player == null or _session == null:
		return
	var 名牌 := _player.get_node_or_null("Nameplate") as Label
	if 名牌 == null:
		return
	var 在族 := bool(_session.guild.get("joined", false))
	var 族名 := String(_session.guild.get("name", "")).strip_edges()
	var 牌 := _player.get_node_or_null("NameplateFamily") as Label
	var 徽 := _player.get_node_or_null("FamilyEmblem") as Sprite2D
	if not 在族 or 族名.is_empty():
		# 退族 / 没族：两样都收掉（原版 `updateBangHuiName("")` 清文本、
		# `addFamilyFlagBuff` 的 else 分支 removeBuff(0)）。
		if 牌 != null:
			牌.visible = false
		if 徽 != null:
			徽.queue_free()
		var 旧框 := _player.get_node_or_null("FamilyEmblemFrame") as Sprite2D
		if 旧框 != null:
			旧框.queue_free()
		return
	if 牌 == null:
		牌 = _新建家族牌(名牌)
	# `CNCore.CHAR_NAME_FAMILY` = `"[家族]"`（`en_US$core_properties.as:31`）
	牌.text = "[家族]%s" % 族名
	牌.visible = 名牌.visible
	var 图 := 家徽图脚本.取(int(_session.guild.get("flag_style", 0)))
	if 图 == null:
		if 徽 != null:
			徽.queue_free()          # 没这张样式就宁可不画（`家徽图.gd` 同原则）
		var 没图框 := _player.get_node_or_null("FamilyEmblemFrame") as Sprite2D
		if 没图框 != null:
			没图框.queue_free()
		return
	if 徽 == null:
		# ⚠️ **样式变了不许"释放再新建"**（用户报修 11：家族升级后族徽位置不对）——
		#    `queue_free()` 帧末才真摘树（实测），旧节点当帧还顶着 `FamilyEmblem` 这个名字
		#    ⇒ 新建那枚撞名，被引擎改名成匿名的 `@Sprite2D@<序号>`（实测，**不是** `FamilyEmblem2`）；
		#    而同帧后面跑的 `_排状态图标排`（:2267）按**节点名**找块 ⇒ 摆的是那枚即将被释放的旧件，
		#    留下那枚停在 `(0,0)`（角色脚下）。再下一帧旧件真摘、按名字读到 `null` ⇒ 下次换样式**又**新建
		#    一枚，那枚匿名的从此没人摆位也没人释放 —— **每升一级在脚下漏一枚族徽**（位置错与漏同根源）。
		#    原版没这坑：`Character.as:690-716` 握的是**引用** + 固定优先级 `setChildIndex`。
		#    门钉在 `测试/家族页回归测试.gd` 的 ①b（取证探针 `开发工具/_probe_同名让位.gd`）。
		徽 = Sprite2D.new()
		徽.name = "FamilyEmblem"
		徽.centered = false
		_player.add_child(徽)
	徽.texture = 图
	徽.scale = Vector2.ONE * (族徽边长 / 家徽图脚本.边长)
	徽.visible = 名牌.visible
	# 位置不在这里写死：所有状态图标（家族 / 忍术境界 / 写轮眼）共用一条 20px 步进的排，
	# 由 `_排状态图标排()` 统一摆（`Character.as:706-718` `insidePositionStatusIconPane`）。
	_刷家族徽框(徽)
	_排状态图标排()


## 头顶族徽的底框（`Effect_CharStatus_Kuang`，20×20）。
##
## 真值 `Character.as:1447-1451`：框与家徽同在一个 MovieClip（框 20×20、家徽 18×18 摆在
## `(1,1)`），整个块由 `insidePositionStatusIconPane` 摆位（`x = -10*数量`、`y = _banghuiPane.y`）。
## 这里只负责"框套在家徽外圈"；位置交给 `_排状态图标排()`。
## 素材不在就撤掉框（`家徽图.gd` 同原则），家徽照旧。
func _刷家族徽框(徽: Sprite2D) -> void:
	var 框 := _player.get_node_or_null("FamilyEmblemFrame") as Sprite2D
	var 框图 := 家徽图脚本.取底框()
	if 框图 == null:
		if 框 != null:
			框.queue_free()
		return
	if 框 == null:
		框 = Sprite2D.new()
		框.name = "FamilyEmblemFrame"
		框.centered = false
		_player.add_child(框)
	# 同级 Sprite2D 按树序绘制、先加的在下层 ⇒ 框必须排在徽**前面**。
	# ⚠️ `move_child` 的坑：框已经在徽前面时再 `move_child(框, 徽.get_index())` 会把它
	#    挪到徽**后面**（先摘再插，目标下标是摘完之后的）。只在真的排在后面时才挪。
	if 框.get_index() > 徽.get_index():
		_player.move_child(框, 徽.get_index())
	框.texture = 框图
	框.visible = 徽.visible


## 头顶状态图标排 —— 家族族徽 / 忍术境界（下忍…）/ 写轮眼状态，三件共用一条排。
##
## 真值 `Character.as:706-718`：
##   `getChildAt(i).x = 20 * i`，`_statusIconPane.x = -10 * 数量`；
##   `y`（`:1497-1512`）取称号牌 / 家族牌 / 名字牌里**最下面那张非空牌的原点**
##   （原点 = 该行墨迹底 + `名牌行距缝` 那条 4px 缝，不是墨迹底本身 —— 报修 8 就栽在这一个字上）。
## 插入顺序照原版的 `addCharStatus` 调用链：家族（`setBangHuiFlagStyle`）→
## 忍术境界（`setTotalSkillLevel`）→ 写轮眼（`setXieLunYanState`）。
func _排状态图标排() -> void:
	if _player == null:
		return
	var 名牌 := _player.get_node_or_null("Nameplate") as Label
	if 名牌 == null:
		return
	var 牌 := _player.get_node_or_null("NameplateFamily") as Label
	var 锚y := 名牌.position.y + _行高(名牌) + 名牌行距缝
	if 牌 != null and 牌.visible:
		锚y = 牌.position.y + _行高(牌) + 名牌行距缝
	var 块们: Array[Dictionary] = []
	var 家徽 := _player.get_node_or_null("FamilyEmblem") as Sprite2D
	if 家徽 != null and 家徽.visible:
		块们.append({"图": 家徽, "框": _player.get_node_or_null("FamilyEmblemFrame") as Sprite2D,
			"内缩": 1.0})
	var 境界 := _player.get_node_or_null("SkillJingJieIcon") as Sprite2D
	if 境界 != null and 境界.visible:
		块们.append({"图": 境界, "框": _player.get_node_or_null("SkillJingJieIconFrame") as Sprite2D,
			"内缩": 1.0})
	var 写轮 := _player.get_node_or_null("XieLunYanStateIcon") as Sprite2D
	if 写轮 != null and 写轮.visible:
		# 内缩 0：原版把整枚图标摆在框的 `(0,0)`（`Character.as:2640`），素材本就是 20×20 = 底框尺寸。
		块们.append({"图": 写轮, "框": _player.get_node_or_null("XieLunYanStateIconFrame") as Sprite2D,
			"内缩": 0.0})
	var 数量 := 块们.size()
	for i in 数量:
		var 左 := -10.0 * 数量 + 状态图标块 * i
		var 组: Dictionary = 块们[i]
		var 框 := 组["框"] as Sprite2D
		if 框 != null:
			框.position = Vector2(左, 锚y)
			# 框在图标**下面**（树序），与 `_刷家族徽框` 同一条规矩。
			# ⚠️ 只在框真的排在图标后面时才挪（`move_child` 摘了再插，相等下标会把框挪到后面）。
			var 图标 := 组["图"] as Sprite2D
			if 框.get_index() > 图标.get_index():
				_player.move_child(框, 图标.get_index())
		(组["图"] as Sprite2D).position = Vector2(左, 锚y) + Vector2.ONE * float(组["内缩"])


## 忍术境界图标（`Character.setTotalSkillLevel:1875-1902`）：
## `SkillJingJie.getJingjie(总层数)` → `PicTool.getRenShuJingJieIcon(档)`，
## 档 < 0（总层数 < 100）**整件不画**。总层数 = 已学忍术层数之和（`DataCenter.getTotalSkillLevel`）。
func _刷忍术境界图标() -> void:
	if _player == null or _session == null:
		return
	# 与忍术面板「境界合计」同一份口径（基础层 + 玉链/忍具/勾玉/八门加层）。
	# 只数基础层会出现「合计 450、头顶还是上一档」（用户 2026-11-07 报）。
	var 总层 := int(_session.call("total_skill_level"))
	var 档 := -1
	for i in 忍术境界门槛.size():
		if 总层 >= int(忍术境界门槛[i]):
			档 = i
	var 图节点 := _player.get_node_or_null("SkillJingJieIcon") as Sprite2D
	if 档 < 0:
		if 图节点 != null:
			图节点.queue_free()
		var 旧框 := _player.get_node_or_null("SkillJingJieIconFrame") as Sprite2D
		if 旧框 != null:
			旧框.queue_free()
		return
	var 路 := 忍术境界图标 % 档
	if not ResourceLoader.exists(路):
		if 图节点 != null:
			图节点.queue_free()
		return
	if 图节点 == null:
		图节点 = Sprite2D.new()
		图节点.name = "SkillJingJieIcon"
		图节点.centered = false
		_player.add_child(图节点)
	图节点.texture = load(路) as Texture2D
	图节点.scale = Vector2.ONE * (族徽边长 / 忍术境界原边长)
	var 名牌 := _player.get_node_or_null("Nameplate") as Label
	图节点.visible = 名牌 == null or 名牌.visible
	_刷状态框(图节点, "SkillJingJieIconFrame")


## 写轮眼状态图标（`Character.setXieLunYanState:2623-2656`）：
## 只有 2..12 阶才画；素材是 `UISwf_xielunyanState_state<N>`。
func _刷写轮眼图标() -> void:
	if _player == null or _session == null:
		return
	var 阶 := int((_session.cultivation_states.get("写轮眼", {}) as Dictionary).get("stage", 0))
	var 图节点 := _player.get_node_or_null("XieLunYanStateIcon") as Sprite2D
	if 阶 < 2 or 阶 > 12:
		if 图节点 != null:
			图节点.queue_free()
		var 旧框 := _player.get_node_or_null("XieLunYanStateIconFrame") as Sprite2D
		if 旧框 != null:
			旧框.queue_free()
		return
	var 路 := 写轮眼状态图标 % 阶
	if not ResourceLoader.exists(路):
		if 图节点 != null:
			图节点.queue_free()
		return
	if 图节点 == null:
		图节点 = Sprite2D.new()
		图节点.name = "XieLunYanStateIcon"
		图节点.centered = false
		_player.add_child(图节点)
	图节点.texture = load(路) as Texture2D
	# 原版这一枚**不缩**：`setXieLunYanState:2640` 只写 `_loc3_.x = _loc3_.y = 0`，
	# 整段 2623-2643 没有 `scaleX/scaleY`。`18/30` 只是隔壁忍术境界那枚的事（`:1896-1897`）。
	图节点.scale = Vector2.ONE
	var 名牌 := _player.get_node_or_null("Nameplate") as Label
	图节点.visible = 名牌 == null or 名牌.visible
	_刷状态框(图节点, "XieLunYanStateIconFrame")


## 给一枚状态图标配 20×20 底框（与族徽同一张 `Effect_CharStatus_Kuang`）。
func _刷状态框(图: Sprite2D, 框名: String) -> void:
	var 框图 := 家徽图脚本.取底框()
	var 框 := _player.get_node_or_null(框名) as Sprite2D
	if 框图 == null:
		if 框 != null:
			框.queue_free()
		return
	if 框 == null:
		框 = Sprite2D.new()
		框.name = 框名
		框.centered = false
		_player.add_child(框)
	_player.move_child(框, 图.get_index())
	框.texture = 框图
	框.visible = 图.visible

func _新建家族牌(名牌: Label) -> Label:
	var 牌 := Label.new()
	牌.name = "NameplateFamily"
	牌.size = 名牌.size
	# 家族牌在名字下面一行。`Character.as:1486` 用的是 `名字牌.y + paneHeight - 6`
	# ⇒ 两行墨迹之间净缝 4（`名牌行距缝`）。⚠ 别拿 NPC 功能称号那条 `- 5`（`NPCSprite.as:240`）来套。
	牌.position = _名牌位置(名牌.position.y + _行高(名牌) + 名牌行距缝)
	牌.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	牌.mouse_filter = Control.MOUSE_FILTER_IGNORE
	牌.add_theme_font_size_override("font_size", 12)
	牌.add_theme_color_override("font_color", 家族牌色)
	牌.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	牌.add_theme_constant_override("outline_size", 世界名字描边)
	牌.visible = false
	_player.add_child(牌)
	return 牌

func _create_nameplate(actor: Node2D, display_name: String, _sprite: Node2D,
		颜色: Color = Color.WHITE, 相对脚点: float = 名字相对脚点,
		描边: int = 世界名字描边) -> Label:
	var label := Label.new()
	label.name = "Nameplate"
	label.text = display_name
	label.size = Vector2(NAMEPLATE_WIDTH, NAMEPLATE_HEIGHT)
	label.position = _名牌位置(相对脚点)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", 颜色)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 描边)
	if _session != null:
		label.visible = bool(_session.game_settings.get("show_names", true))
	actor.add_child(label)
	return label

## 名牌的落点。原版名字/称号**不随手在哪个框上**，是固定贴着角色原点的：
##   · `Character.as:1484`  人物  `_namePane.y = paneHeight - 3`
##   · `Monster.as:840/1686` 怪物 `_mobNamePane.y = 2 + paneHeight`
##   · `NPCSprite.as:234`    NPC   `_npcNamePane.y = paneHeight`
## 而 `RoleNamePane` 是把文字画在**自己原点上方**的（`_bg.y = -paneHeight`、
## `_tf.y = _bg.y + 4`），所以换算下来文字净落点都在**脚点下面一点点**，不在头顶。
## 以前那套"量贴图 bbox 顶边再往上让"是自造的 —— 原版名字根本不动，跟帧无关。
## 所以这里改成**一次性定位**，不再接 `visual_bounds_changed`。
func _名牌位置(相对脚点: float) -> Vector2:
	return Vector2(-NAMEPLATE_WIDTH * 0.5, 相对脚点)

func _行高(label: Label) -> float:
	return label.get_theme_font("font").get_height(label.get_theme_font_size("font_size"))

## 怪物名字的颜色按"怪物等级 − 自己等级"分档（`Monster.as:1264-1290`），
## 五档的色值就是原版那几个十进制常量：51543=0x00C957 / 16750866=0xFF9A12 /
## 16777215=白 / 16711680=红 / 8424071=0x808547。
func _怪物名字颜色(entity_id: String) -> Color:
	var 怪等级 := _怪物等级(entity_id)
	var 我等级 := 1
	if _session != null:
		我等级 = int(_session.player_stats.get("level", 1))
	if 怪等级 >= 我等级 - 5 and 怪等级 <= 我等级 + 5:
		return Color(0.0, 0.788235, 0.341176)
	if 怪等级 > 我等级 + 5 and 怪等级 < 我等级 + 10:
		return Color(1.0, 0.603922, 0.070588)
	if 怪等级 > 我等级 - 10 and 怪等级 < 我等级 - 5:
		return Color(1.0, 1.0, 1.0)
	if 怪等级 >= 我等级 + 10:
		return Color(1.0, 0.0, 0.0)
	return Color(0.501961, 0.521569, 0.278431)

func _怪物等级(entity_id: String) -> int:
	return int(GAME_DATA.monster(entity_id).get("level", 1))

## NPC 名字下面那行绿色功能称号（武器商人、药品商人……）
## `NPCSprite.as:55` 给名字白、功能绿 65280(0x00FF00)；`y = 名字.paneHeight + 功能.paneHeight - 5`。
func _add_npc_title(actor: CombatActor, entity_id: String, nameplate: Label) -> void:
	var info: Dictionary = GAME_DATA.npc(entity_id)
	var title := String(info.get("title", "")).strip_edges()
	if title.is_empty():
		return
	var label := Label.new()
	label.name = "NameplateTitle"
	label.text = title
	label.position = _名牌位置(nameplate.position.y + _行高(nameplate) + 称号间距补量)
	label.size = nameplate.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 皮肤表.文字规则_描边数值)
	label.visible = nameplate.visible
	actor.add_child(label)

func _on_npc_input(_viewport: Node, event: InputEvent, _shape_idx: int, actor: CombatActor, npc_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_character(actor, _npc_selection_info(actor, npc_id))
		## 原版 `NPC.as:52-65 globalClick()`：**够近**才 `talkToNPC` + `requestNPCTalk`(54) +
		## `directionNPC`；**不够近只寻路走过去**（`pathFind(x, y-5, skin, false)`）。那第 3 参会存进
		## `KeyController.movingtoLifeId`（`:1032`），走到关节走完那一帧再拿它反查 object_id
		## 发对话（`:211-227`）⇒ 远处点 NPC 是「先自动走到跟前，再自己弹对话」，**不当场弹**。
		## 第 4 参 `showtip=false` ⇒ 这一种不亮「自动寻路中」那条提示。
		## （以前这里不管多远都直接 `_open_dialog` ⇒ 隔半张图也能说话，用户 2026-10-09 实机报的第 3 条。
		##  原版的 `y-5` 那 5 像素没照搬：走到的是同一枚落脚点，5px 不改变寻路结果，为共用
		##  「点任务赶路」那条路让开。）
		if _能对话(actor):
			_open_dialog(npc_id)
		else:
			_走过去找NPC(actor, npc_id)
		get_viewport().set_input_as_handled()


## 能不能直接说话 —— **两轴分别判，不是欧氏距离**：`NPC.as:111-114`
## `canPlayerTalkToMe(): Math.abs(player.x - x) < 100 && Math.abs(player.y - y) < 50`
## （`MarryTable.as:117` 用的是同一式子）。横 100 / 纵 50 是斜 45° 地面的投影：纵向走一步
## 在屏幕上只挪一半，所以阈值也是一半 —— 拿 `distance_to() < 100` 判会把上下方向放宽约 2 倍。
const 可对话横距 := 100.0
const 可对话纵距 := 50.0


func _能对话(演员: Node2D) -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null or 演员 == null:
		return false
	var 差 := _player.global_position - 演员.global_position
	return absf(差.x) < 可对话横距 and absf(差.y) < 可对话纵距


## 远处点 NPC ⇒ 交给 HUD 那份「走到跟前自动开对话」的机制（与点任务赶路**同一条路**，
## 不分两套实现）。第 2 参 = 原版 `showtip`：点 NPC 这一种是 false。
func _走过去找NPC(演员: Node2D, npc_id: String) -> void:
	_find_hud()
	if _hud != null and _hud.has_method("前往NPC"):
		_hud.call("前往NPC", int(npc_id), false)
		return
	## HUD 不在（还没建、或整块 HUD 被换掉）⇒ 至少人要走过去，别静默什么都不做。
	var 玩家 := get_tree().get_first_node_in_group("player") as Node2D
	if 玩家 != null and 玩家.has_method("走向") and is_instance_valid(演员):
		玩家.call("走向", 演员.global_position, true, false)

func _add_remote_player_interaction(actor: Node2D, sprite: Node2D, state: Dictionary) -> void:
	var area := Area2D.new()
	area.name = "CharacterInteractionArea"
	area.input_pickable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(90.0, 110.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -46.0)
	area.add_child(shape)
	area.input_event.connect(_on_remote_player_input.bind(actor, sprite, state))
	_远端状态[actor] = {"态": state, "画": sprite}
	area.mouse_entered.connect(_on_npc_mouse_entered.bind(area))
	area.mouse_exited.connect(_on_npc_mouse_exited.bind(area))
	actor.add_child(area)

func _on_remote_player_input(_viewport: Node, event: InputEvent, _shape_idx: int, actor: Node2D, sprite: Node2D, state: Dictionary) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_character(actor, _remote_player_selection_info(sprite, state))
		get_viewport().set_input_as_handled()

func _npc_selection_info(actor: CombatActor, npc_id: String) -> Dictionary:
	## ⚠ **两条条都钉 -1** —— 原版 `setData():241-246` 对 `type == 2` 走的就是
	## `setBarStartXToZero()` + `setData(-1,-1)`，`MBar.as:158-161` 于是印 `?/?`。
	## 以前这里给的是真血量（100/100），条看着"满"，与原版不一样。
	return {
		"name": actor.display_name,
		"level_text": "NPC",
		"hp": -1,
		"max_hp": -1,
		"mp": -1,
		"max_mp": -1,
		"portrait": OriginalSpriteScript.portrait("npc", npc_id),
		"type": 2, "char_id": 0, "level": 0,
	}

func _remote_player_selection_info(sprite: Node2D, state: Dictionary) -> Dictionary:
	var face_id := str(int(state.get("face", 1))).pad_zeros(8)
	var portrait: Texture2D = OriginalSpriteScript.portrait("character", face_id)
	if portrait == null:
		var frame := sprite.get("sprite") as Sprite2D
		portrait = frame.texture if frame != null else null
	return {
		"name": String(state.get("name", "忍者")),
		"level_text": "LV.%d" % int(state.get("level", 1)),
		## ⚠ 出场帧（162）里**没有**血量那四段（`SpawnPlayerInfo.decode():61-94`），所以这里
		## 一律读不到就是 **0**，不再拿 100 凑 —— 以前那对 `100/100` 是自造的假数
		## （用户 10-15 实机打回）。真数由选中那一刻发的 `94:4` 换回的 1284 填进来
		## （见 `_select_character` 那一支）。
		"hp": int(state.get("hp", 0)),
		"max_hp": int(state.get("max_hp", 0)),
		"mp": int(state.get("mp", 0)),
		"max_mp": int(state.get("max_mp", 0)),
		"portrait": portrait,
		## `type = 1` ⇒ 那排六颗钮全显（`hideBtn():289`）。`char_id` 是**服务端角色编号**，
		## 加好友 / 交易 / 看摊 / 双修 / 师徒 那几发都要它；`名字` 那一发组队邀请用的是名字。
		"type": 1, "char_id": int(state.get("character_id", 0)),
		"level": int(state.get("level", 0)),
		## 脸也带上（`openMarryZengHuaWindow` 的第三参 = `receiveFace`，赠花窗里那具**活的立绘**
		## 只认它）。出场帧 162 里本来就有这一段（`SpawnPlayerInfo.decode` 读 face），
		## 以前只拿来算 `portrait` 那张静态图、没往信息字典里放 ⇒ 菜单那几行拿不到脸。
		"face": int(state.get("face", 1)),
	}

## 把某个演员设成当前目标 —— 走 `_select_character` 这个**真入口**（点人/点怪那条也是它）。
## 人这一侧要把 162 那份选中信息一起递进去，否则信息条拿到的是空字典
## （`_select_character` 里那句 `request_character_info` 认的就是 `info.type == 1`）。
func 设目标(演员: Node2D) -> void:
	if 演员 == null or not is_instance_valid(演员):
		return
	if 玩家角色号(演员) > 0:
		var 记: Dictionary = _远端状态.get(演员, {})
		var 画 = 记.get("画")
		var 态 = 记.get("态")
		if 画 is Node2D and 态 is Dictionary:
			_select_character(演员, _remote_player_selection_info(画 as Node2D, 态 as Dictionary))
			return
	_select_character(演员, {})


func _select_character(actor: Node2D, info: Dictionary) -> void:
	if is_instance_valid(_selected_character) and _selected_character != actor:
		var previous := _selected_character.get_node_or_null("SelectionMarker") as Node2D
		if previous != null:
			previous.visible = false
	_selected_character = actor
	var marker := actor.get_node_or_null("SelectionMarker") as Node2D
	if marker == null:
		push_warning("人物缺少预挂载的选中标记：%s" % actor.name)
		_selected_character = null
		return
	marker.visible = true
	# 点选同时也是"目标框显示它"（原版 `Monster.onMouseSelect()` 里 `setCurTarget` 之后又设了
	# `viewTarget = this`）—— 只走 `select_map_character` 的话，`_process` 的轮询盯不上它，
	# 框里的血就不会跟着掉。
	if str(actor.get("kind")) == "m":
		## 第二参 `true`：挂机可能已经先锁着同一只了，那 Times setter 会整段跳过（原版 `:261`），
		## 但**点选**这一下必须让信息条重新拿到一份数据 ⇒ 显式要求重发。
		显示目标框(actor, true)
	elif _session != null:
		_session.call("select_map_character", info)
	## 选中**玩家** ⇒ 立刻要一份对方的真实属性。原版就在这个位置：
	## `TargetHandler.set viewTarget():275-278` `if (param1 is Character)
	## API.client.requestTargetCharacterInfo(param1.objectId)` ⇒ 服务端回
	## `TARGET_INFO(1284):<对象号>:<type>:<id>:<hp>:<maxHp>:<mp>:<maxMp>`
	## （`Client.onTargetInfo():6966-6977` 拿的就是这四个数喂信息条）。
	## 不发这一发，条上只有出场帧给得出的东西 —— 而 162 出场帧**根本没有血量字段**
	## （`SpawnPlayerInfo.decode():61-94` 那 29 段里没有 hp），所以以前永远显示 100/100。
	if int(info.get("type", -1)) == 1 and _backend != null and bool(_backend.get("in_game")):
		_backend.call("request_character_info", int(info.get("char_id", 0)))

func _clear_selected_character() -> void:
	# 点别处 = 目标框也清掉（原版 `TargetHandler.as:253/315/466` 那几处 `viewTarget = null`）
	_摆头顶箭头(_view_target, false)
	_view_target = null
	_选中目标上次血量 = -1
	_选中目标上次蓝量 = -1
	if is_instance_valid(_selected_character):
		var marker := _selected_character.get_node_or_null("SelectionMarker") as Node2D
		if marker != null:
			marker.visible = false
	_selected_character = null
	if _session != null:
		_session.call("clear_map_character_selection")

## 目标信息条上「点头像」那一发（原版 `onClickHead():473-476` = `API.targetHandler.cancelTarget()`）
## ⇒ 选中、追打、目标框一起清。HUD 拿不到 `_selected_character`，只能由这里开口。
func 取消选中() -> void:
	_clear_selected_character()
	if _player != null and _player.has_method("停止追打"):
		_player.call("停止追打")

## 选中箭头 = 原版 `MobSelected_Effect_Skin`（`asset/effect.swf`，20×30、逐帧上下浮动）。
## 挂点：怪 `Monster.as:810-812` 与 NPC `NPC.as:45-47` 都是 `x = 0`、`y = −贴图高 − 8`，
## 由 `战斗角色._更新头顶挂件位置()` 每帧钉（贴图高随帧变，不能写死常数）。
## ⚠ 以前这里 `preload` 的是 `场景/界面/组件/人物选中标记.tscn` —— 那枚箭头是**两块 Polygon2D
##   手画的**、y 还写死 `-108`。自造美术已废（挪到 `真值/作废素材/`），换成导出的真图。
func _attach_selection_marker(actor: Node2D) -> Node2D:
	var existing := actor.get_node_or_null("SelectionMarker") as Node2D
	if existing != null:
		return existing
	var marker := EffectPlayer.new()
	marker.name = "SelectionMarker"
	marker.visible = false
	actor.add_child(marker)
	marker.call("play", "MobSelected_Effect_Skin")
	if actor.has_method("_更新头顶挂件位置"):
		actor.call("_更新头顶挂件位置")
	else:
		_钉远程头顶挂件(actor)
	return marker


## 远程玩家那一支的箭头落点。**上一轮就是这条漏了**：`_更新头顶挂件位置()` 只加在
## `玩家.gd`（本地那具身体）与 `战斗角色.gd`（怪/NPC）上，而远程玩家的演员是这里
## `_on_server_player_spawned` 用 `Node2D.new()` 建的裸节点 ⇒ 上面那句 `has_method` 落空、
## 箭头停在原点 = 脚点，还压在名字牌上（用户 10-15 实机图打回的那一条）。
## 式子与两侧同源：`Character.as:1469-1470` `MobMouseOverEffectSkin.x = 0; y = -_crtCharHeight - 8`，
## 而 `_crtCharHeight` 是**当前帧**的贴图高（`:2508` 每帧刷）⇒ 不能只在挂上那一刻算一次。
func _钉远程头顶挂件(演员: Node2D) -> void:
	var 箭头 := 演员.get_node_or_null("SelectionMarker") as Node2D
	if 箭头 == null:
		return
	var 精灵 = 演员.get_child(0)
	if 精灵 == null or not 精灵.has_method("当前贴图高度"):
		return
	var 高 := float(精灵.call("当前贴图高度"))
	## 量不到高（帧数据缺失/精灵还没建）⇒ **不动**，别把它按 0 处理回脚边。
	if 高 > 0.0:
		箭头.position = Vector2(0.0, -高 - 8.0)


## 每帧刷一遍所有远程玩家：站立/跳/爬的贴图高不一样，换动作时箭头要跟着抬。
func _推进远程头顶挂件() -> void:
	for 演员 in _remote_players.values():
		if is_instance_valid(演员):
			_钉远程头顶挂件(演员 as Node2D)
			_刷新远程打坐光环(演员 as Node2D)


## 远程玩家的**打坐光环**。原版挂在角色基类上（`Character.as:2742-2762 tickHealAnimation()`）：
## 条件只有 `movementAction == SIT0 || SIT1`，满足就 `new FrameQueueAnimation()` +
## `data = effects.healNew` + `addChild` + `adjustLayer()`、不满足就摘 ⇒ **远程玩家也是 Character**、
## 它的 movementAction 由 `CommandController` 从 187 帧设 ⇒ 旁观者本来就该看到那圈光。
## 本工程以前只有本地那具身体做了（`玩家.gd:769 _刷新打坐光环`），远程这一支只切姿态
## ⇒ 用户 10-15 报的"看不到其他玩家的打坐特效"。
## 层序口径与本地同源：原版两张 `adjustLayer()` 表都把 `healQueueAnimation` 排在身体动画**之后**、
## 名字 pane **之前** ⇒ 光环盖住身体、但被头顶名字压在下面。
## ⚠ "坐没坐"读的是**精灵当前动作名**（`_播远程动作` 已经按包里的 movementAction 设好了），
## 不另立第二份状态 ⇒ 不会出现"姿态是坐着的、光环却没了"。
## 怪脚下那圈光环 + 名字下面那排强化图标。判定/尺寸/摆位全在 `脚本/角色/精英外观.gd` 里按 AS3 字面写，
## 这里只管"拆旧的 → 建新的"：`_configure_actor` 每配一只怪都会调一次（服务端重发同一只的出生帧、
## 离线复活都算一次），先拆后建与原版 `Character.as:666 setLianzhanEffect` 第一句
## `destroyLianZhanAura()` 同一口径 —— 不是"有变化才换"。
func _挂精英外观(actor: Node2D, 怪号: Variant) -> void:
	var 旧 := actor.get_node_or_null("精英外观") as Node2D
	if 旧 != null:
		# `queue_free()` 要等到帧末，同一帧里再挂一枚就重影 ⇒ 先 `remove_child` 立刻摘掉
		actor.remove_child(旧)
		旧.queue_free()
	var 首领档 := int(GAME_DATA.monster(怪号).get("boss", 0))
	var 列表: Array = actor.精英属性
	## 原版 `Monster.as:1659`：`boss==1 || boss==2 || jingyings.length > 0` 才建环
	if 首领档 != 1 and 首领档 != 2 and 列表.is_empty():
		return
	var 环 := 精英外观脚本.new() as Node2D
	环.name = "精英外观"
	## `:1660` 选图：只有 `boss==1` 用首领环，`boss==2` 与"带精英属性"都走变异环
	if not 环.建光环(首领档 == 1, int(怪号)):
		环.queue_free()
		return
	环.设图标(列表)
	actor.add_child(环)
	## 光环要画在**身体后面**（原版 `AuraLayerItem.aLayerType = ALayerType.BOTTOM` ⇒ 实机图上环的远侧弧
	## 被怪肚子盖住）。⚠ 这里**不用 `move_child(环, 0)`**：本文件有 5 处 `actor.get_child(0)` 当精灵用
	## （499 / 820 / 842 / 2460 / 2516 行），插到 0 号会把那些口子全带偏 ⇒ 改用 `z_index = -1`
	## （兄弟节点先按 z 排、同 z 才按树序），图标排在 `精英外观.gd` 里另给 +1 抬回身体之前。
	环.z_index = -1


func _刷新远程打坐光环(演员: Node2D) -> void:
	var 精灵 = 演员.get_child(0)
	if 精灵 == null:
		return
	var 动作名 := str(精灵.get("action"))
	var 在坐: bool = 动作名 == "sit0" or 动作名 == "sit1"
	var 环 := 演员.get_node_or_null("打坐光环") as Node2D
	if 在坐 and 环 == null:
		环 = 打坐光环场景.instantiate() as Node2D
		环.name = "打坐光环"
		演员.add_child(环)
		var 牌: Node = 演员.get_node_or_null("Nameplate")
		if 牌 != null:
			var 序: int = 演员.get_children().find(牌)
			if 序 >= 0:
				演员.move_child(环, 序)
	elif not 在坐 and 环 != null:
		环.queue_free()

func _on_npc_mouse_entered(area: Area2D) -> void:
	_hovered_npc_areas[area.get_instance_id()] = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_npc_mouse_exited(area: Area2D) -> void:
	_hovered_npc_areas.erase(area.get_instance_id())
	if _hovered_npc_areas.is_empty():
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _interact_nearest_npc() -> void:
	var nearest := _find_nearest_npc(INTERACTION_DISTANCE)
	if nearest != null:
		_open_dialog(nearest.entity_id)

func _find_nearest_npc(max_distance: float) -> CombatActor:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return null
	var result: CombatActor
	var best := max_distance
	for entity in _entities:
		if not is_instance_valid(entity) or entity.kind != "n":
			continue
		var distance := _player.global_position.distance_to(entity.global_position)
		if distance < best:
			best = distance
			result = entity
	return result

## 原版 `NPCHandler.as:140-146` 的 `directionNPC(objId)`：
## `npc.direction = npc.x > player.x ? LEFT : RIGHT` —— **说话那一拍 NPC 要转身面朝玩家**，
## 不是保持原样、也不是转向前一帧的移动方向。原版三个说话入口各调一次：
## 点 NPC（`NPC.as:52-65 globalClick`）、走到跟前自动对话（`KeyController:165-178`）、
## 站着按键对话（`:211-227`）。本工程这三条最后都汇到 `_open_dialog` ⇒ 只挂这一处就够。
## ⚠ 用 `_set_facing` 而不是现成的 `面向(玩家x)`：后者算 `sign(目标x − 自己x)`，
## 两者只在 x 完全相等时不同（那一刻原版面朝右，`面向` 会原地不动）。
func _让NPC面朝玩家(npc_id: String) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return
	for 实体 in _entities:
		if not is_instance_valid(实体) or str(实体.get("kind")) != "n":
			continue
		if str(实体.get("entity_id")) != npc_id:
			continue
		if 实体.has_method("_set_facing"):
			实体.call("_set_facing", -1.0 if 实体.global_position.x > _player.global_position.x else 1.0)
		return


func _open_dialog(npc_id: String) -> void:
		# 原版三个入口都在发 54 之前先 `directionNPC` ⇒ 顺序照抄：先转身，再发包/开窗
	_让NPC面朝玩家(npc_id)
	if _backend != null:
		_backend.call("request_npc_dialog", int(npc_id))
	_find_hud()
	if _hud != null and _hud.has_method("show_npc_dialog"):
		_hud.call("show_npc_dialog", npc_id)
	if _session != null:
		_refresh_quest_markers()

func _refresh_quest_markers() -> void:
	if _session == null:
		return
	for entity in _entities:
		if not is_instance_valid(entity) or entity.kind != "n":
			continue
		_挂任务标记(entity, int(_session.call("npc_quest_status", entity.entity_id)))


## NPC 头顶那枚标记 = 原版 `NPCQuestPopup.as:15-36` 按 `NpcQuestStatus` 取的 TickMovie，
## 三张图都在 `asset/effect.swf`（档位 ↔ 特效键见 `游戏会话.任务标记特效()`）。
## ⚠ 以前这里是自造的：`StyleBoxFlat` 画一枚金色圆环 + `Label` 打 "!" / "?" 字符，
##   注释还写着「原版任务标记是 NPC 头顶一枚描边的金色圆环」—— 那句没有出处。
##   真图三档是 可接=金色叹号 / 可交=**金色问号** / 进行中=银灰问号，两档带 1050ms 循环动画。
## 状态 0 不建节点；建过就只换特效 —— 原版是常驻实例（`NPCSprite.as:247-263` 只在状态变了时
## 摘掉再挂），每 0.5s 重建一次会把动画相位打掉。
func _挂任务标记(actor: CombatActor, 状态: int) -> void:
	var 特效名 := String(_session.call("任务标记特效", 状态))
	var 标记 := actor.get_node_or_null("QuestMarker") as EffectPlayer
	if 特效名.is_empty():
		if 标记 != null:
			标记.visible = false
		return
	if 标记 == null:
		标记 = EffectPlayer.new()
		标记.name = "QuestMarker"
		actor.add_child(标记)
	if 标记.entry_name != 特效名:
		标记.play(特效名)
	标记.visible = true
	actor.call("_更新头顶挂件位置")

func _refresh_pet_companion() -> void:
	for 节点 in [_pet_companion, _pet_companion_extra]:
		if is_instance_valid(节点):
			节点.free()
	_pet_companion = null
	_pet_companion_extra = null
	if _session == null or not _session.has_method("get_deployed_pet"):
		return
	# 出战与附身两态都要在地图上出现（原版两种控制器都挂 actor），差别在会不会打怪：
	# 出战 = AttackPetController（跟走 + 自动出手）、附身 = FuShenPetController（只跟走）。
	# 服务端 `_normalize_active_pet_positions()` 允许"一只附身 + 一只出战"并存 ⇒ 两态都在时
	# 就建两个 actor（名字各带宠物 id，不会撞）。
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	var 出战: Dictionary = _session.call("get_deployed_pet")
	var 附身: Dictionary = {}
	if _session.has_method("get_attached_pet"):
		附身 = _session.call("get_attached_pet")
	if 出战.is_empty() and 附身.is_empty():
		return
	if not 出战.is_empty():
		_pet_companion = _建宠物伙伴(出战, "出战")
	if not 附身.is_empty() and str(附身.get("id", "")) != str(出战.get("id", "")):
		var 附身伙伴 := _建宠物伙伴(附身, "附身")
		if _pet_companion == null:
			_pet_companion = 附身伙伴
		else:
			_pet_companion_extra = 附身伙伴

## 建一只地图上的通灵兽 actor：挂在**父节点**（地图实体本身是场景根，伙伴要跟角色同层）。
func _建宠物伙伴(宠物: Dictionary, 角色: String) -> Node2D:
	var 伙伴 := PetCompanionScript.new() as Node2D
	get_parent().add_child(伙伴)
	伙伴.call("configure", 宠物, _player, self, 角色)
	return 伙伴

func _find_hud() -> void:
	_hud = get_tree().get_first_node_in_group("game_hud")

func _get_current_map_id() -> String:
	return String(_session.current_map_id) if _session != null else "101010000"

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("LifeRoot: cannot open " + path)
		return {}
	var text := file.get_as_text()
	file.close()
	if text.begins_with("\ufeff"):
		text = text.substr(1)
	var parsed = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _normalize_entries(raw) -> Array:
	if raw is Array:
		return raw
	if raw is Dictionary:
		var dictionary: Dictionary = raw
		var keys: Array = dictionary.keys()
		keys.sort_custom(func(a, b): return int(a) < int(b))
		var result: Array = []
		for key in keys:
			result.append(raw[key])
		return result
	return []
