extends Node2D

## 坐下去之后身上那圈 GameData `healNew` 九帧。**走场景不走 new()** ——
## 用户 2026-10-13 要"在编辑器里看得见这九帧才好手动调"，所以九帧是场景里九个 Sprite2D
## （`开发工具/生成打坐九帧场景.py` 烘），脚本只负责"轮到哪一帧就显哪一帧"。
const 打坐光环场景 := preload("res://场景/角色/打坐光环.tscn")

const SkillAnimation := preload("res://脚本/角色/技能动画精灵.gd")
const 角色造型 := preload("res://脚本/角色/角色造型.gd")
const 灵器外观脚本 := preload("res://脚本/角色/灵器外观.gd")

# Custom foothold physics. Generic version - reads map_id from export var.
# The player is a point that falls under gravity and snaps onto the nearest
# foothold segment below it (no Godot collision shapes).
# Left/Right walk, Up/W jumps. Camera2D follows the player.

@export var map_id := "101010000"
## 跳跃抛物线的两条物理常数。真值在 `脚本/角色/跳跃常数.gd`（**本地与旁观端同源**，
## 为什么不能写在这里、也不能在 `地图实体.gd` 再抄一份，那份文件顶部写了原因）。
const 跳落 := preload("res://脚本/角色/跳跃常数.gd")
@export var gravity := 跳落.重力
@export var max_fall_speed := 跳落.末速上限
## ⚠ 这三个数**只是"移动速度属性 = 100"那一档的原版值**（走路 125×1.4=175、
## 攀爬 125×1.4=175、起跳 555×1.2=666）。真正生效的值在 `_ready()` 与每次收到
## 服务端属性帧时由 `应用移动速度属性()` 按 `GameSession.player_stats.move_speed` 现算
## —— 整条链与行号写在 `脚本/角色/跳跃常数.gd`。
## 这里原来把 `climb_speed` 写死成 **125**：走路恰好撞上"属性 100"那个点所以看不出问题，
## 攀爬却比原版慢 28.6%（10-15 用户"攀爬不对劲"的一半），而且**任何加移速的装备/心法/宠物
## 都不生效**（面板数字会变、人不变快）⇒ 服务端 field 21 一路下发到我们这儿，
## 只有人物面板读它，移动代码零消费。
@export var move_speed := 175.0
@export var jump_speed := 666.0
@export var climb_speed := 175.0

var velocity := Vector2.ZERO
var on_ground := false
var climbing := false
## 本图是不是禁寻路图（迷路森林那两口）。移动换成原版 `PlayerController.tickInJingSuMaps()`：
## 左右键不转向、撞墙才掉头、平时一直朝当前朝向走，见 `脚本/地图/禁寻路地图.gd` 文件头。
var 禁寻路 := false
## 上一帧物理判定"往右/往左撞在墙上"（原版 `rightBlock` / `leftBlock`）。
## 原版在 `checkInit():246` 每帧先清零、`checkFoothold()` 撞上再置位，控制器读的是**上一帧**的值
## ⇒ 这里同样在 `_禁寻路方向()` 读完就清零。
var 右被挡 := false
var 左被挡 := false
## 这一趟上绳是**自动路线**带上来的（`_走点击路线` 的 `climb` 段），不是玩家自己按上/下。
## 只有这一种才允许在"路线半路没了"的时候自动松手 —— 手动挂在绳上不动是**原版行为**
## （`AbstractPhysicObject.checkLadder():249-267` 每帧重算这根绳，没人按上/下就停在绳上），不许改。
var 自动爬梯中 := false
var footholds: Node = null
var ladder_root: Node = null
var portal_root: Node = null
var bounds := Rect2()
var spawn_pos := Vector2.ZERO
var current_fh_id := ""
var player_sprite: Node = null
## 十拳剑「改变外观」那层须佐能乎残影。挂在身体之后 ⇒ 画在身体上面（原版是
## `CharacterSprite` 的子级 `ciAfterImage`，同样在身体之上）。
var 灵器外观: Node2D = null
var facing := 1
var portal_cooldown := 0.0
## 刚脱离梯子/绳子的冷却。爬到顶脱离后，"上"键往往还按着，而 `get_ladder_at` 在
## `y1-20` 范围内仍会返回这根绳子 —— 于是同一帧脱开、下一帧又吸附，来回横跳，
## 攀爬动画每帧重播一次（用户看到的"梯子结束动画一直循环"）。给一小段冷却断开这个环。
var ladder_cooldown := 0.0
var jump_was_pressed := false
var attack_was_pressed := false
var attack_cooldown := 0.0
## 攻击动作播完之前：不接受移动输入覆盖动作、也不水平移动 —— 原版攻击动作期间
## `KeyController.as:1405-1411` 把水平速度清零，`AbstractLifeObject.tickStance():194-200`
## 等动画 `actionEnd()` 才把 stance 复位回 STAND。
var 出手中 := false
## 这一出手**实际播的是哪个动作名**（普攻=attack、技能=技能记录里的 stance 之一）。
## 发 1328 时把它折成动作号填进 stance 槽，旁观者才知道要播哪一招
## （原版 `AbstractAttackSkill.as:610-626` 就是把同一个 `useStance` 既播出去又发出去）。
var _出招动作名 := ""
## 点怪之后那条**一次性**的"自动接近并攻击"命令（原版 `Monster.onMouseSelect` → `setCurTarget(this, true)`
## → `toAttackAnemy`）。口径由用户 2026-09-27 两次澄清定死：
##   · 点怪 → 选中目标 + 起这条命令（自己走过去打）；
##   · **玩家自己一移动（方向键 / 点地面）→ 这条命令立刻取消**，
##     但**选中目标保留**（目标框还在，再攻击/放技能仍然打它）；
##   · 目标死了 / 选中被清掉 → 命令也取消。
## ⚠️ 我上一轮把它做成了"只要选中就一直追"—— 那是把用户的**期望**读成了 bug 报告，已改回。
var 自动接近目标: Node2D = null
## 「走过去打」这条命令用的**真寻路**路线状态（原版 `toAttackAnemy` → `GuajiHandler` 的 A*，
## 不是直线朝 x 走）。怪会自己走动，所以目标点变了、或上一段路线走完了，就重排一次；
## 加冷却是为了"目的地到不了"时不要每帧都重排一遍图。
var _接近上次目标 := Vector2.INF
var _接近冷却 := 0.0
const 接近重排间隔 := 0.35
const 接近重排位移 := 24.0
var is_practising := false
var click_move_active := false
## 原版 `MovementAction.JUMP` 那一档：空中**没有横向控制** ——
## `KeyController.tick():1275-1297` 只在 STAND/WALK/SIT0 写水平速度，JUMP 那一档
## （`:1375-1395`）只改朝向；起跳那一下的横向速度已由 `jumpRight/LeftTarget():488/1623`
## （朝向×walkSpeed）或 `jumpUpTarget():626`（0）定死，落地 `:1398-1408` 才 `x:0`。
## 本工程以前每帧都拿 `dir * move_speed` 覆盖 ⇒ 空中按键能把人从平台边上推出去，
## 落点不在任何脚点上就一直掉（用户 2026-10-30 报"跳跃移动 / 下+跳穿台落到地平线以下"）。
var 跳起中 := false
## 爬顶那一跳（原版 `KeyController.tick():1441-1449` 把 ROPE/LADDER 翻成 JUMP 的那一支）：
## 用户 2026-10-31 口径 —— 这一跳里**保留左右移动**（普通跳跃仍然不许），但要有**惯性**：
## 从当前速度按 `走速 / 爬顶跳加速时长` 的斜率逼近 `dir × 走速`，松手同样按这个斜率回 0。
## 用户原话：「爬顶后的跳跃，可以移动……移速有点怪」「有惯性（渐加速）」——
## 逐帧直写 `velocity.x = dir × 走速`（§3.321 的首版）是"按一下人就在空中平移"，太飘。
const 爬顶跳加速时长 := 0.15
var 爬顶跳中 := false
## 爬顶脱开那一下的**竖直**速度（实现在 `_physics_process` 脱开梯子那一支）：用户 2026-10-31
## 口径 —— 高度 = 普通起跳 + 基础速度的爬顶跳
## （`跳跃常数.爬顶跳离速()`：√(666² + 175²) ≈ 688.6；175 = `CLIMB_SPEED 125 × 1.4`，
## 属性 100 的原版口径）。原版 `KeyController.tick():1441-1449` 是"速度原样保留"，而那份速度
## 带移动速度属性 ⇒ 照搬会让爬顶的高度随移速涨 —— 用户已明确否掉，所以基础那一段按常量算。
## ⚠ 只改"脱开梯子那一帧"的竖直速度；攀爬过程本身仍按 `climb_speed`（原版口径不动）。
## 自动赶路中 ⇒ 舞台顶部要挂「自动寻路中．．．」。
## 真值 `KeyController.as:933` 的第 5 参 `param5 = showtip`：
##   · `CharacterHandler.as:710`（MovePlayerToNpc）、`:881/:885`（MovePlayerToMob）、
##     `SmallMapWindow.as:1137`（点小地图）传 true ⇒ 挂到 `API.stage`（:996-1002 / :1058-1066）；
##   · `World.as:392`（鼠标点地走）**不传** ⇒ :1004-1007 把已挂着的那枚 removeChild；
##   · 路线结束/`stopPathFind()`（:446-449、:1222-1225）同样 removeChild。
## 本工程把「画在哪」交给 HUD（`小地图面板.gd`），这里只报状态 —— 与 42/51 那两条回帧同一个形状。
signal 自动寻路态(在走: bool)
var 自动寻路中 := false
var click_move_x := 0.0
var click_move_y := INF
var click_target_fh_id := ""
var click_climb_direction := 0.0
var click_replan_pending := false
var auto_jump_direction := 0
const CLICK_STOP_DISTANCE := 8.0
const PORTAL_COOLDOWN := 1.0
const CLICK_RIPPLE_SCRIPT := preload("res://脚本/角色/点击涟漪.gd")
## 脚下那圈连斩阶段光环（原版 `Character.as:663-676 setLianzhanEffect`，8 档 × 80 帧）。
const 连斩光环脚本 := preload("res://脚本/角色/连斩光环.gd")
var _连斩光环: Node2D = null
const AUTO_PATHFINDER_SCRIPT := preload("res://脚本/角色/自动寻路.gd")
## 技能命中矩形的几何只有一份，见该文件（`SkillHitBox`）。用 preload 而不是光靠 class_name：
## 全局类名要等 Godot 扫过一遍才进 `.godot/` 的类缓存，冷启动那一次会报"未声明"。
const SKILL_HITBOX := preload("res://脚本/角色/技能命中盒.gd")
## 离线「我打怪」的伤害结算（原版 `Client.applyClientPveAttack()`）。同样 preload 不用 class_name。
const COMBAT_FORMULA := preload("res://脚本/角色/战斗结算.gd")
const 技能动画 := preload("res://脚本/角色/技能动画精灵.gd")
const 原始精灵脚本 := preload("res://脚本/角色/原始动画精灵.gd")
const 技能目标选择 := preload("res://脚本/角色/技能目标选择.gd")
const 飞行物脚本 := preload("res://脚本/角色/技能飞行物.gd")
const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
## 禁寻路地图（迷路森林那两口）的判定与速度表，口径写在那个文件里。
const 禁寻路地图 := preload("res://脚本/地图/禁寻路地图.gd")

var auto_pathfinder: RefCounted = null
var auto_actions: Array = []
var auto_action_index := 0
## 挂机（智能托管）那一整套循环的实现体 —— 与 `auto_pathfinder` 同类：**逻辑对象，不带样式**。
## 它的存在就是为了"原版 GuajiHandler 在这工程里只有一份"。
const 挂机托管脚本 := preload("res://脚本/角色/挂机托管.gd")
var _托管: Node = null
var _backend: Node
var _movement_sync_elapsed := 0.0
var _last_synced_position := Vector2.INF
const MOVEMENT_SYNC_INTERVAL := 0.1
## 发给服务端的**动作号**（`fake_flash_server.py:111-118` 的 `PLAYER_MOVEMENT_ACTION_*`）。
## 以前 `send_movement` 第二参发的是朝向（±1）⇒ 落在服务端的 movement_action 槽里，
## 对面收到的永远是"站立"（-1 还会被夹成站立）⇒ **别人走路只有位移、没有走路帧**
## （用户 2026-10-14 报的第一条）。朝向改由第 5 段的速度 x 带出去（服务端在广播包的第 8 段
## 原样转给同伴，它自己的「文本→原版」翻译器也是拿那一格推朝向的）。
const 动作站立 := 1
const 动作跳跃 := 2
const 动作行走 := 3
const 动作爬梯 := 4
const 动作爬绳 := 5
const 动作打坐 := 7
## 双修那一档。原版 `MovementAction.SIT1 = Action.sit1 = 8`（`Action.as:6/22`），
## 由 `HealHandler.as:415` 在**进双修那一刻** `setMovementAction(SIT1)` 设上；
## 单修才是 `SIT0=7`（`Character.as:2735`）。两帧美术完全不同：`sit0` 是正面打坐，
## `sit1` 是**侧身对坐**、身前那张小桌已经烘在帧里（用户 10-17 两张原版截图对的就是这一帧）。
const 动作双修 := 8
var _同步动作 := 动作站立
## 「打坐中自己走了一步 ⇒ 停坐」那一条的现场诊断（只给门读，运行期没人看）。
var 打坐打断诊断 := ""
var _上次同步动作 := 0
var _上次同步速度 := Vector2.INF		## 见 `_sync_backend_movement` 的"速度一变当场发"
var _上次同步朝向 := 0			## 同上：原版 `Sampler` 的脏标记里就有 DIRECTION 这一格

func _ready():
	add_to_group("player")
	map_id = GameSession.current_map_id
	禁寻路 = 禁寻路地图.是禁寻路图(map_id)
	var root = get_parent()
	footholds = root.get_node_or_null("Footholds")
	if footholds != null and footholds.segments.is_empty():
		footholds.load_map(MAP_RESOURCES.map_data_path(map_id))
	ladder_root = root.get_node_or_null("LadderRoot")
	## ⚠ `AutoPathfinder._init` 当场就读 `footholds.segments`（`自动寻路.gd:12→85`），场景里没有
	##   `Footholds` 时旧写法抛 `Invalid access to property or key 'segments' on a base object of
	##   type 'null instance'`。§3.245 实测的两种坏法里这属于**构造器那一种**：抛错只中断 `_init`
	##   自己，`_ready` 照常跑完 ⇒ 拿到的是一个**图没建起来的半构建寻路器**：所有脚点号都查不到
	##   （`get_component` 恒 -1）⇒ `plan()` 永远回空、寻路静默失效，日志里只留一条 SCRIPT ERROR。
	##   ⇒ 取不到脚点节点就**干脆不建**；下游一律经 `走向()`（那里已判 `auto_pathfinder == null`）。
	if footholds != null:
		auto_pathfinder = AUTO_PATHFINDER_SCRIPT.new(footholds, ladder_root)
	## 挂机的实现体（`Node` 子节点，自己的 `_ready` 里连会话/后端并接受击信号）。
	_托管 = 挂机托管脚本.new()
	_托管.name = "挂机托管"
	add_child(_托管)
	portal_root = root.get_node_or_null("PortalRoot")
	if portal_root != null and portal_root.has_method("get_entry_position"):
		position = portal_root.get_entry_position(GameSession.pending_portal_name)
	var requested_spawn = GameSession.get_requested_spawn(map_id)
	if requested_spawn is Vector2:
		position = requested_spawn
	if position == Vector2.INF and footholds != null and footholds.has_method("get_spawn"):
		position = footholds.get_spawn()
	spawn_pos = position
	velocity = Vector2(0, 5)
	if footholds != null:
		bounds = footholds.map_bounds
	var world_camera := root.get_node_or_null("WorldCamera")
	if world_camera != null and world_camera.has_method("configure"):
		world_camera.configure(self, bounds)
	setup_player_sprite()
	GameSession.player_defeated.connect(_on_player_defeated)
	_backend = get_node_or_null("/root/BackendConnection")
	应用移动速度属性()
	## 服务端每次推属性（换装 / 心法 / 宠物 / 减速 buff 都会单推一条 field 21）都要重算，
	## 对应原版 `DataCenter.as:2783-2784` 收到 `WLK_SPEED` 当场刷 `walkSpeedFactor`。
	if _backend != null and _backend.has_signal("stats_received"):
		_backend.stats_received.connect(func(_载荷: Dictionary) -> void: 应用移动速度属性())

## 走路 / 攀爬速度 = `125 × (1.4 × 服务端移动速度属性 / 100)`（`跳跃常数.gd` 里有整条行号链）。
## 起跳不跟属性走：原版 `jumpSpeedFactor` 全树没有赋值点，恒为初值 1.2 ⇒ 666。
func 应用移动速度属性() -> void:
	var 属性 := float(GameSession.player_stats.get("move_speed", 100))
	## 属性缺失/为 0 时**不许把人物冻住**：按原版默认 100 算（`CharacterStats.as:70`）。
	if 属性 <= 0.0:
		属性 = 100.0
	move_speed = 跳落.走路速度(属性)
	climb_speed = 跳落.攀爬速度(属性)
	jump_speed = 跳落.起跳速度()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 点地面也是一种"自己移动" → 取消自动接近命令（点怪那条路会重新起一条，见 `开始自动接近`）。
		# 这一句对照 `World.as:816` `targetHandler.toAttackAnemy = false;`。
		自动接近目标 = null
		## `World.as:817` 紧跟的是 **`guajiHandler.isStart = false;`** —— 原版挂机中随手点一下
		## 空白地面（没点到掉落物那一支，`:814` `if(!_loc8_ && API.player)`），挂机**整个关掉**：
		## 屏幕上那颗"挂机中"球灭、发 1808:1。以前这边只 `自动接近目标 = null; 走向(...)`
		## ⇒ 只是取消这一次追击、下一拍又自动打起来。复用 `挂机托管` 现成的停挂机入口
		## （`请求停挂机` → 会话 `request_hang(false)` → `置挂机态(false)` 唯一出口），不新写状态翻转。
		if _托管 != null and _托管.has_method("请求停挂机"):
			_托管.call("请求停挂机")
		走向(get_global_mouse_position())


## 让角色走到世界坐标 `目标`（自动处理"没有落脚点"与"在空中"两种情况）。
##
## 原版是 `CharacterHandler.MovePlayerToNpc` → 内部同样落到这套点击寻路上，
## 所以「前往」/小鸟这类按钮**不该另写一套移动**，直接调它。
## 返回 true 表示已经起了一条路线（不等于一定会走到 —— 中途再点一下会换路线）。
## `自动` = 原版 `pathFind` 的第 5 参 `showtip`：任务赶路/点小地图/去某个 NPC 传 true，
## 鼠标点地走（`World.as:392`）与战斗自动接近传 false。
func 走向(目标: Vector2, 显示涟漪 := true, 自动 := false) -> bool:
	# 原版每次寻路前清一整列活动状态（`SmallMapWindow.as:1131-1136`）⇒ 停打坐收在这里，
	# 小地图点图与「前往」按钮都是**直接调 走向**、不经过 `_unhandled_input`。
	_stop_practise()
	if 禁寻路:
		## 原版 `KeyController.pathFind():934-941`：禁寻路图里点地 / 「前往」/ 点小地图
		## 一律只给这一行提示，**不排路线**。
		_提示(提示_无法寻路)
		return false
	if footholds == null or auto_pathfinder == null:
		return false
	var target: Dictionary = footholds.find_click_target(目标)
	if target.y == INF:
		return false
	click_move_x = 目标.x
	click_move_y = target.y
	click_target_fh_id = target.id
	# 新的目的地一律顶掉旧路线。在空中或爬梯时先记下来，等落到稳定地面再重排。
	click_climb_direction = 0.0
	auto_jump_direction = 0
	auto_actions.clear()
	auto_action_index = 0
	click_replan_pending = not on_ground
	if climbing:
		click_climb_direction = 1.0 if click_move_y > position.y else -1.0
	if on_ground:
		auto_actions = auto_pathfinder.plan(current_fh_id, click_target_fh_id, click_move_x, position.x)
	click_move_active = click_replan_pending or not auto_actions.is_empty()
	if 显示涟漪:
		show_click_ripple(Vector2(click_move_x, click_move_y))
	## 原版把提示挂在「路线真的起来了」那两个 return 上（`:996` 在 `return 1` 前、`:1058` 在
	## `return 2` 前），而**没路线的早退根本不动它** —— 所以这里也只在走到这一步才改状态。
	_设自动寻路态(自动 and click_move_active)
	return click_move_active

func _设自动寻路态(在走: bool) -> void:
	if 自动寻路中 == 在走:
		return
	自动寻路中 = 在走
	自动寻路态.emit(在走)

func show_click_ripple(click_position: Vector2) -> void:
	var ripple := Node2D.new()
	ripple.name = "ClickRipple"
	ripple.set_script(CLICK_RIPPLE_SCRIPT)
	ripple.position = click_position
	get_parent().add_child(ripple)

func perform_basic_attack(damage := -1, radius := 105.0, ignore_cooldown := false) -> bool:
	# 原版 `AbstractSkill.fire()`：动作没播完（movementAction == ATTACK）就**不能再出招**
	# —— `canExeMovementAction()` 只认 JUMP/STAND/WALK（AbstractSkill.as:63-66、CommonAttack.as:29）。
	if 出手中:
		return false
	if (attack_cooldown > 0.0 and not ignore_cooldown) or climbing:
		return false
	_stop_practise()
	attack_cooldown = 0.45
	cancel_auto_path()
	# ⭐ 出手之前先面向目标 —— 原版 `SkillExecute.moveToAttack():125` 那一句服务的是
	# `defaultSkill`，而**普攻就是 `defaultSkill` 为 0 时那一条**（`:66-77` 取号、`:122-127` 转身再放），
	# 所以点了怪打不到身后去：够得着 ⇒ 转身 ⇒ 才 `fireSkill`。没选中怪就不转（原版这一刻根本没有 `curTarget`）。
	# ⭐ #352：`_选中怪()` 换成 `_选中目标()` —— 怪那一侧它原样返回 `get_selected_enemy()`
	# （判据一个字没动），**多出来的只有"点中的是可打玩家"这一档也要先转身**
	# （原版 `curTarget` 一个变量装怪和人，`:125` 那句转身对两种类型都跑）。
	_面向目标(_选中目标())
	_出招()
	return _结算攻击(damage, radius)

## 命中判定与结算（不含出手动作）——技能离线那条也要走它，不能让技能再调一次
## `perform_basic_attack`（那会被 `出手中` 挡掉，等于技能打不到人）。
func _结算攻击(damage := -1, radius := 105.0) -> bool:
	# ⚠️ `damage`/`radius` 是历史遗留参数：**伤害现在不再由调用方给** ——
	# 离线走 `脚本/角色/战斗结算.gd` 的公式（原版 `Client.applyClientPveAttack()`），
	# 在线由服务端算。全工程的调用点本来就不传这两个参数，保留签名只为少动调用处。
	# 这里原来放 `play_effect("attack")` —— **原版普通攻击没有音效**：MainLib 全量 grep `soundPlayer.play`
	# 的调用点只有 脉爆(Character.as:322)/死亡(:765)/暴击(AbstractSkillEffect:326)/
	# 跳跃落地(KeyController)/闪现/手里剑/假怪消失与召唤(Monster) 七类，普攻不在其中。
	var 命中盒 := 攻击矩形()
	var life_root := get_parent().get_node_or_null("LifeRoot")
	if life_root == null:
		return false
	## ⭐ #352 打人链最后一环：**出手这一拍**先问"当前点的是不是人"
	## （原版 `SkillExecute.as:330-365` 那一支的分工 —— `curTarget` 是 `Character` 时
	## 走 `SkillHandler.canAttack()`：过 ⇒ `toAttackAnemy=true` + `stopPathFind()`，
	## **不过 ⇒ 只把 `pvpHandler.getNoAttackWarning()` 那一句贴到屏幕上，这一发不发**，
	## 也**不回落到**"框最近的怪"那一条（回落只在 `curTarget` 根本不存在时才走）。
	var 盯的人: Node2D = null
	if life_root.has_method("点中的玩家") and life_root.has_method("PVP能否出手") \
			and life_root.has_method("玩家角色号"):
		盯的人 = life_root.call("点中的玩家") as Node2D
	if 盯的人 != null:
		var 判: Dictionary = life_root.call("PVP能否出手", 盯的人)
		if not bool(判["可打"]):
			_说一句(str(判["话"]))
			return false
		_面向目标(盯的人)
		## 目标信息条**不在这里重开**：点人那一刻 `_select_character` 已经把条摆上并发了
		## `request_character_info`（`地图实体._select_character` 那一支），`显示目标框` 是怪那条。
		if not (_backend != null and bool(_backend.get("in_game"))):
			## 打人的伤害**只能由服务端结算**（原版 PVP 伤害从来不在客户端算，本工程离线
			## 也没有 PVP 公式）⇒ 离线既不发也不假结算，`_结算一只` 那条只给怪用。
			return false
		return bool(_backend.call("request_pvp_basic_attack",
				int(life_root.call("玩家角色号", 盯的人)), global_position, facing))
	# 原版命中判定 = 攻击矩形 ∩ 每个怪的 `outerBodyRect`，取**最近的一个**
	# （`CommonAttack.getAtkRect():116-128` + `getNearestMonsterInArea():82-113`）。
	# 以前这里是"以角色前方 48px 为心、半径 105 的圆、打中圈内全部"，是自造的。
	var enemy: Node2D = null
	# 点了怪就先打它（原版 `CommonAttack.getAttackInfo():182-193` 就是拿 `targetHandler.curTarget`
	# 当目标发出的）；没选中才退回"命中盒里最近的一个"。
	var 选中 := _选中怪()
	if 选中 != null and life_root.has_method("get_enemies_in_rect"):
		if (life_root.call("get_enemies_in_rect", 命中盒) as Array).has(选中):
			enemy = 选中
	if enemy == null and life_root.has_method("get_nearest_enemy_in_rect"):
		enemy = life_root.call("get_nearest_enemy_in_rect", 命中盒) as Node2D
	elif life_root.has_method("get_enemies_in_range"):
		enemy = _最近敌人(life_root.call("get_enemies_in_range",
				global_position + Vector2(float(facing) * 48.0, -24.0), radius))
	if enemy != null and life_root.has_method("显示目标框"):
		life_root.call("显示目标框", enemy)   # 打谁，目标框就显示谁（原版 `SkillHandler.as:1095` 同义）
	var online := _backend != null and bool(_backend.get("in_game"))
	if online:
		if enemy != null:
			_backend.call("request_basic_attack", int(enemy.get("object_id")), global_position, facing)
	elif enemy != null:
		_结算一只(enemy, 0)      # 普攻：`getSkillAddedAtk` 为 0 ⇒ 系数 = max(25, 100) = 100
	return enemy != null

## 离线结算一只怪 —— 原版 `Client.applyClientPveAttack()` 的那一套（命中/防御/系数/暴击/五刀鼠）。
## 普攻与技能都走它，只是 `技能加成攻击` 不同。
func _结算一只(enemy: Node2D, 技能加成攻击: int) -> void:
	if not enemy.has_method("take_damage"):
		return
	var 精英: Array = enemy.get("精英属性") if enemy.get("精英属性") is Array else []
	var 结果 := COMBAT_FORMULA.判定(GameSession.player_stats, GAME_DATA.monster(enemy.get("entity_id")),
			精英, 技能加成攻击, int(str(enemy.get("entity_id"))), int(enemy.get("max_hp")))
	enemy.call("take_damage", int(结果["伤害"]), float(facing), bool(结果["暴击"]))
	## 暴击 ⇒ 震屏。`AbstractSkillEffect.as:198-200` 把 `isEarthquake` 置真，`:321-324`
	## 只在"**玩家自己**打出的那一发"上调 `API.world.earthquake()`（= 30 / 0.3 秒）。
	## 同一条里还放暴击音 `SoundConstants.GetBaoJiSound(职业)`（穿了时装不放）——
	## 那条声音本工程**没接**，见 `真值/窗口/战斗表现.md`。
	if bool(结果["暴击"]):
		_震屏()

## 震屏的闸 —— ⚠ **判向**（2026-10-11 用户实机打回「暴击了但没有震动」，我第一版整个读反了）：
## 原版那个量是**反义**的：`SysCfg.as:30` `_forbidEarthQuake = true`（默认禁止），
## 设置页 `SystemConfigWindow.as:444` 直接把 `forbidEarthQuake` 画成「遮罩暴击操作的震屏特效」的勾选态。
## 而本工程的 `game_settings.screen_shake` 是同族 `show_*` 那套**正向能力**口径
## （`开发工具/生成设置场景.py:60` 那条 `写=false` ⇒ 勾上「遮罩」写进去的是 false）
## ⇒ 到这一行只能是「**真值 = 真才抖**」；新号默认 false ⇒ 起步不抖，与原版一致
## （要看到抖：设置 → 常规 → 取消勾选「遮罩暴击操作的震屏特效」）。
func _震屏() -> void:
	if not bool(GameSession.game_settings.get("screen_shake", false)):
		return
	var 相机 := get_viewport().get_camera_2d()
	if 相机 != null and 相机.has_method("震一下"):
		相机.call("震一下")

## `SkillDataTool.getSkillAddedAtk()`（`SkillDataTool.as:516-524`）—— 它先读技能的
## `value2Base/value2Level`，**本工程没导这两个字段**（`数据/技能.json` 只有 `valueBase/valueLevel`
## = `damage`/`damage_growth`）⇒ 少了 value2 那一档，只有 value2 非 0 的技能会偏低。
## `getSkillValue()` 里还有几个写死的特例（`:287-303`），照抄。
func _技能加成攻击(skill_id: String, 等级: int) -> int:
	match int(skill_id):
		4005: return 160
		4008: return 350
		4010: return 260
		4011: return 220
	var 定义 := GAME_DATA.skill(skill_id)
	return int(定义.get("damage", 0)) + int(定义.get("damage_growth", 0)) * maxi(1, 等级)

## 出招：播角色的 `attack` 动作（原版动作名就是 `Action.ActionName[11] = "attack"`），
## **单次**播完停住；播完之前 `出手中` 为真 —— 期间不接受移动输入覆盖动作、也不水平移动
## （`KeyController.as:1405-1411` 在攻击动作期间把水平速度清零）。
func _出招() -> void:
	if player_sprite == null or not player_sprite.has_method("play_once"):
		return
	var 起来了: bool = player_sprite.call("play_once", "attack")
	_出招动作名 = "attack" if 起来了 else ""
	# 原版只有站在地面才被定身（`KeyController.as:1407` 那句 `if(target.grounded)`），
	# 空中出招不锁。
	出手中 = 起来了 and on_ground

## 放技能时的出手动作。原版 `AbstractAttackSkill.hitTest():602-612` 会把角色的
## movementAction 设成 `useStance`，**动作名来自技能记录的 `action` 字段**；
## 没写这条的技能用基类默认 `alert`（`AbstractSkill.as:16`）。
## 播法同普攻：单次播完、期间定身、不能再出招。
func _出技能动作(skill_id: String) -> void:
	if player_sprite == null or not player_sprite.has_method("play_once"):
		return
	var 候选: Array = GAME_DATA.skill_stance(skill_id)
	if 候选.is_empty():
		return
	# 原版 `getSkillStance():134` 是 `stances[MathAD.rnd(0, len-1)]` —— 列表里随机挑一个
	var 动作 := String(候选[randi() % 候选.size()])
	_出招动作名 = 动作
	if not player_sprite.call("play_once", 动作):
		return
	出手中 = on_ground

func _攻击动作结束了吗() -> bool:
	if player_sprite == null:
		return true
	if player_sprite.has_method("动作已播完"):
		return bool(player_sprite.call("动作已播完"))
	return true

## 选中的怪（点怪选中；原版 `targetHandler.curTarget`）。没有就返回 null。
func _选中怪() -> Node2D:
	var life_root := get_parent().get_node_or_null("LifeRoot")
	if life_root == null or not life_root.has_method("get_selected_enemy"):
		return null
	return life_root.call("get_selected_enemy") as Node2D


## 选中的**可打玩家**（#352 打人链；原版同一个 `curTarget` 变量的另一种类型）。
## 走 `LifeRoot.选中目标()` 那条并表口，没有这个方法（别的图根/夹具）时退回只看怪。
func _选中目标() -> Node2D:
	var life_root := get_parent().get_node_or_null("LifeRoot")
	if life_root == null or not life_root.has_method("选中目标"):
		return _选中怪()
	return life_root.call("选中目标") as Node2D


## 屏幕下方那一行字 —— 工程里现成的唯一说话口 `GameSession.notification_requested`
## （同 `游戏会话.gd:529`「查克拉不足」那几条）。
## ⚠ **空串就什么都不说**：原版 `PVPHandler.getNoAttackWarning:414-467` 在"目标已死"和
## "我在 3v3/战场/跨服"这几档就是回 ""，`SkillExecute.as:359` 拿 "" 去 `addNotice` 也是静默。
func _说一句(文: String) -> void:
	if 文.strip_edges().is_empty():
		return
	GameSession.notification_requested.emit(文)

## 把某只怪设成当前目标 —— 走 `LifeRoot._select_character` 这个**真入口**
## （它同时设 `_selected_character` 与目标框，而 `get_selected_enemy()` 读的是前者；
## 只调 `显示目标框` 的话选中态是空的，行为门量过一次）。
func _设为目标(目标: Node2D) -> void:
	var 根 := get_parent().get_node_or_null("LifeRoot")
	if 根 != null and 根.has_method("_select_character"):
		根.call("_select_character", 目标, {})


## TAB 切目标。原版 `SkillHandler.switchTarget():1022-1098`（键位 `KeyDef.as:479-484`，
## `canSet=true` ⇒ 走 `快捷键` 那张表，不硬判 KEY_TAB；派发在 `GameKey.as:402`）。
## PVE 档（PK 模式 NONE）候选表 = **全部怪**，取最近的一只；"轮换"是靠
## `getNearestLifeObj` 会把它返回的那个从数组里 `splice` 掉 ⇒ 最近者就是当前目标时，
## 第二次取到的是**第二近**。这里等价地"排除当前目标后取最近"。
func 切换目标() -> Node2D:
	var 根 := get_parent().get_node_or_null("LifeRoot")
	if 根 == null:
		return null
	var 怪: Array = []
	for 客 in 根.get_children():
		if 客 is Node2D and str(客.get("kind")) == "m" and bool(客.get("alive")):
			怪.append(客)
	## ⭐ #352：候选表 = 怪 + **可打的玩家**。原版 `SkillHandler.switchTarget():1022-1098`
	## 遍历的是 `getFlagObjList` 那张 flag 表，**人和怪本来就在同一张表里**、用同一把尺取最近，
	## 所以 TAB 从来不是"只在怪里轮"。名单已经由 `LifeRoot.可打的玩家` 过完 PVP 判定
	## ⇒ 打不了的人不会被 TAB 选中（原版也是：选不中 ≠ 点不了，点人另走 TargetHandler 那条）。
	var 人: Array = []
	if 根.has_method("可打的玩家"):
		人 = 根.call("可打的玩家")
	## 排除的是**当前出手目标**（怪或人都算），轮换口径与原版 `splice` 那条一致。
	var 得 := 技能目标选择.最近(怪 + 人, global_position, _选中目标())
	if 得 == null:
		return null
	var 得节点 := 得 as Node2D
	if 根.has_method("设目标"):
		根.call("设目标", 得节点)		## 人那一侧要带 162 那份选中信息，信息条才不会空
	else:
		_设为目标(得节点)
	return 得节点


## 走向选中的怪；进了攻击盒就出招。返回这一帧要走的方向（0 = 不动）。
## ── 10-19 按「移植不是重做」把整段改成 `SkillExecute.moveToAttack():66-171` 的逐句转写 ──
## 原来这一段的形状是我自己定的（"有选中忍术就只放它，转 CD / 蓝不够这一拍什么都不放"），
## 那句注释还写着"原版没有回落普攻这一档" —— **那句是错的**：
## `DataCenter.getSkillLevel:2231-2236` 对 0 直接 `return 1`，`SkillDataTool.getSkillMp:393-398`
## 的 `switch(param1)` 里没有 0 这一档 ⇒ 耗 0，`AbstractAttackSkill.canUseSkill:546-573` 三关全过
## ⇒ **`canUseSkill(0)` 恒真**。所以原版 `:75-78` 那一转就把招式号换成 0，人**站着平A把怪打死**。
## 症状（用户实机最容易看出来的那一条）：大招一进 CD（或蓝空了），我们这具就贴到怪脸上不出手。
func _冲选中目标(目标: Node2D) -> int:
	if not bool(目标.get("alive")):
		cancel_auto_path()
		return 0
	_面向目标(目标, 2.0)
	## `:70-73` `if (API.skillHandler.isYuedu) toAttackAnemy = false;`（被"阅读/剧情锁定"状态占了手）
	## ⇒ **本工程没有这个状态的字段**，这一条整档缺失，已记在 `真值/窗口/挂机设置窗.md` 的"不是 1:1"。
	var 槽 := GameSession.默认忍术槽()
	var 招 := "" if 槽 < 0 else String((GameSession.get_skill_in_slot(槽) as Dictionary).get("id", ""))
	## `:75-78` 长CD 且正在转，或者这一招现在放不出去 ⇒ **降级成普攻**（原版写 `_loc2_ = 0`）。
	if 招 != "" and ((长CD招(招) and GameSession.get_skill_cooldown(槽) > 0.0) or not _这一招放得出(招)):
		招 = ""
	## `:79-82` `else if (Job0.isSkillForbiden(_loc2_)) defaultSkill = _loc2_ = 0;`
	## 禁招那一条查的是 `nowJinChuFuBen / nowInKuaFu / nowIn3v3 / nowInKaoShi / 木叶大战 / 木vs晓`
	## 这几张玩法图（`Job0.as:422-435`），**本工程没有这些玩法** ⇒ 这一整档同样缺失，不硬凑。
	if _托管 != null and _托管.has_method("能攻") and not bool(_托管.call("能攻", 目标)):
		_放掉追击(目标)
		return _走点击路线()
	if 招 == "":
		if _够得着(目标):
			## `:126-131`：够得着且不在冷却 ⇒ **先转身**（`API.player.direction = getRectangleDirection`）
			## 再 `fireSkill`。`perform_basic_attack` 自带冷却与"出手中"闸门，也自带 `cancel_auto_path()` ——
			## 这里再补一次，是因为它在出招中/冷却中会**提前返回**、不取消路线，
			## 那样角色会一边挥空一边继续往前挪。
			_面向目标(目标)
			perform_basic_attack()
			cancel_auto_path()
			return 0
		_维持接近路线(目标)
		## `:158-161` `if (API.healHandler.nowInHeal) requestHealStop();` 挂在外层 if 的尾巴上，
		## **够得着放招、还是发路线靠近，都要先把打坐停掉**（上一版只在"挑中掉落"那一支停）。
		_停正在打的坐()
		return _走点击路线()
	var 档 := int(GAME_DATA.skill(招).get("target", 0))
	if 技能够得着(招, 档, 目标):
		if GameSession.get_skill_cooldown(槽) > 0.0:
			## `:132-135` 够得着**却在转 CD** ⇒ `player.stopPathFind()`（这一拍站着，别边走边等 CD）。
			## 招在这里已经降级过了，走到这一步只可能是"不是长CD、却还在冷却"那一档。
			cancel_auto_path()
			return 0
		_面向目标(目标)
		use_skill_slot(槽)
		cancel_auto_path()
		_停正在打的坐()
		return 0
	_维持接近路线(目标)
	_停正在打的坐()
	return _走点击路线()


## 原版 `API.targetHandler.toAttackAnemy = false` 那一支（`:163-170`）：除了放掉追打命令，
## 还有一句 **`if (player.isPathFinding() && !player.climbing) player.stopPathFind();`**
## ⇒ 目标死了/丢了/打不了，**身上那条追过去的路线当场掐掉**，人会停在原地而不是走到
## 那只怪站过的地方才停。上一版 `停止追打()` 只有 `自动接近目标 = null` 一行，缺这一句。
func _放掉追击(目标: Node2D) -> void:
	自动接近目标 = null
	if bool(click_move_active) and not climbing:
		cancel_auto_path()
	if _托管 != null and _托管.has_method("追打失败"):
		_托管.call("追打失败", 目标)


## 原版 `SkillDataTool.isLongCdSkill:737-740` = `getSkillCooltime(id, 1) > 10000`（毫秒）。
## 本工程 `数据/技能.json` 的 `cooldown` 是**秒**（`游戏会话.use_skill:521` 直接按秒倒数），
## 所以这条阈值是 `> 10.0` 秒。
func 长CD招(技号: String) -> bool:
	return float(GAME_DATA.skill(技号).get("cooldown", 0.0)) > 10.0


## 原版 `AbstractAttackSkill.canUseSkill:546-573`：只看**等级 > 0、查克拉够、精华够**这三样，
## 与这招有没有放在快捷栏**无关**（`canUseSkill(0)` 因为等级写死 1、消耗 0 而恒真）。
func _这一招放得出(技号: String) -> bool:
	if 技号 == "":
		return true
	var 等 := 0
	for 技 in GameSession.learned_skills:
		if str((技 as Dictionary).get("id", "")) == 技号:
			等 = int((技 as Dictionary).get("level", 1))
			break
	if 等 <= 0:
		return false
	var 耗: Dictionary = GAME_DATA.skill_cost(int(技号), 等)
	return float(GameSession.player_stats.get("mp", 0)) >= float(耗.get("mp", 0)) \
			and float(GameSession.player_stats.get("zq", 0)) >= float(耗.get("zq", 0))


## 原版挂在外层那一支尾句 `:158-161`（以及 `:781-784` 拾取那一支）：只要人在打坐就先起身。
func _停正在打的坐() -> void:
	if is_practising:
		_stop_practise()
		_上行停坐()



## 出手/靠近前把朝向对准目标。原版 `SkillExecute.as:122-127`：够得着 ⇒
## **`API.player.direction = GeomUtil.getRectangleDirection(player.outerBodyRect, target.outerBodyRect)`
## 然后才 `fireSkill`** —— 所以"背对怪也能放"在原版不是这样：它先转身再放（#192）。
## `死区` 是给靠近那一支留的：原地别抖（水平差不到 2px 就不翻）。
func _面向目标(目标: Node2D, 死区 := 0.0) -> void:
	if 目标 == null or not is_instance_valid(目标):
		return
	var 水平 := float(目标.global_position.x) - global_position.x
	if absf(水平) <= 死区:
		return
	设朝向(1 if 水平 > 0.0 else -1)


func 设朝向(方向: int) -> void:
	var 新 := -1 if 方向 < 0 else 1
	if 新 == facing:
		return
	facing = 新
	if player_sprite != null and player_sprite.has_method("set_direction"):
		player_sprite.call("set_direction", facing)


## 目标的体型盒是否已经压进普攻命中盒 —— 与 `perform_basic_attack` 用的是**同一个** `攻击矩形()`，
## 不另编一个距离常数，免得出现"站住了却打不到"。
## 原版 `AbstractAttackSkill.canReachTarget():388-404`：拿**这个技能**的命中盒去压目标的体型盒，
## 当前朝向压不到就**再按反方向试一次**（不是"距离小于某个常数"）。
func 技能够得着(技号: String, 档: int, 目标: Node2D) -> bool:
	if 目标 == null or not is_instance_valid(目标):
		return false
	if 档 == 3:
		return true		# 自身技（隐身/瞬移/加血单体…）没有"够不够得着"这一说
	var life_root := get_parent().get_node_or_null("LifeRoot")
	if life_root == null:
		return false
	## #352：这一格从"只看怪"换成**怪 + 可打玩家**并表（`LifeRoot.目标列表`）。
	## 并表里怪那一部分就是原来 `get_enemies_in_rect` 的那一批、顺序也没变
	## （点中的那只仍然排第一），所以对"打怪"这条链一个字节都没动；
	## 没有这个方法时（别的图根/夹具）退回原口径，老路径不许被我打死。
	var 框到 := _框住目标的表(life_root, 技能命中矩形(技号))
	if 框到.has(目标):
		return true
	var 反向 := SKILL_HITBOX.由范围(int(GAME_DATA.skill(技号).get("range", 0)), position, -facing)
	return _框住目标的表(life_root, 反向).has(目标)


func _够得着(目标: Node2D) -> bool:
	var life_root := get_parent().get_node_or_null("LifeRoot")
	if life_root == null:
		return false
	return _框住目标的表(life_root, 攻击矩形()).has(目标)


## 命中盒框到的目标表：**怪（原口径、原顺序）+ 可打的玩家**并表；
## `LifeRoot` 没有 `目标列表` 时退回只看怪（保持改造前的行为）。
func _框住目标的表(life_root: Node, 命中盒: Rect2) -> Array:
	if life_root.has_method("目标列表"):
		return life_root.call("目标列表", 命中盒)
	if life_root.has_method("get_enemies_in_rect"):
		return life_root.call("get_enemies_in_rect", 命中盒)
	return []

## 维持一条通向怪的**寻路**路线：怪走到别处（或上一段路线走完）就重排。
## 走路/爬梯/跳跃/下落全部交给已有的 `click_move_*` 那套（`_走点击路线`），不另写一套移动。
func _维持接近路线(目标: Node2D) -> void:
	if _接近冷却 > 0.0:
		return
	## ⚠ 原版这两处重排**都带同一道闸** `!player.isGPathFinding()`（`SkillExecute.moveToAttack():95`
	## 同层侧移、`:133` 跨层追击），而 `isGPathFinding():1645-1648` = `nowInLadderToPathFind ||
	## isPathFinding()` ⇒ **身上还有活动路线（含"等落地再重排"那枚暂存）时，追击一律不许插一条新路线**。
	## 上一版只在"怪没怎么动"时跳过，怪一动就照发 `走向()` —— 而 `走向()` 里
	## `click_climb_direction` 是按当下目标 y 现算的（本文件 `:230-231`）⇒ 人正在爬梯时被它
	## 每 0.35 秒改一次竖直方向，用户 2026-10-19 实机报的"上梯子一直上下上下"两股力就有这一股。
	if click_move_active or 自动爬梯中:
		return
	if _接近上次目标 != Vector2.INF \
			and absf(目标.global_position.x - _接近上次目标.x) <= 接近重排位移:
		return
	_接近上次目标 = 目标.global_position
	_接近冷却 = 接近重排间隔
	## 原版 `SkillExecute.moveToAttack():133-141`：`pathFind(怪.x, 怪.y−5)` **返回不是 1（寻不出路）**
	## ⇒ `guajiHandler.signWrong(怪)`（这只 1.5 秒内不再试）+ `toAttackAnemy = false` 放掉它。
	## 上一版这里把返回值丢了 ⇒ 挂着时对面是一只永远走不到的怪，人就卡在原地打一辈子空
	## （10-18 在线腿实测：怪在另一层平台上、纵向差 284 像素，90 秒零死亡）。
	if not bool(走向(目标.global_position, false)):
		自动接近目标 = null
		if _托管 != null and _托管.has_method("追打失败"):
			_托管.call("追打失败", 目标)

## 点怪时由 `地图实体._on_monster_input` 调：起一条"自己走过去打"的命令。
func 开始自动接近(目标: Node2D) -> void:
	自动接近目标 = 目标
	_接近上次目标 = Vector2.INF
	_接近冷却 = 0.0
	cancel_auto_path()

func _最近敌人(列表) -> Node2D:
	var 最近: Node2D = null
	var 最短 := INF
	for 项 in 列表:
		if 项 == null:
			continue
		var 距离 := global_position.distance_to((项 as Node2D).global_position)
		if 距离 < 最短:
			最短 = 距离
			最近 = 项
	return 最近

## 原版普通攻击的命中盒：`Character.getDefaultAttackRect():1296-1304` 给的是
## `left=-50, right=0, top=-50, bottom=0`（相对脚点），`CommonAttack.getAtkRect()` 再
## 按朝向翻到身前并平移到角色坐标 —— 也就是**脚点往上一格、身前 50px 的 50×50 方块**。
func 攻击矩形() -> Rect2:
	var 盒 := Rect2(-50.0, -50.0, 50.0, 50.0)
	盒.position.y += position.y
	盒.position.x = position.x if facing > 0 else position.x - 50.0
	return 盒

## 技能的命中矩形。真值两段：
##   · `SkillDataTool.getSkillHitRect():60-131` —— 按技能 `range` 取一张**定表**（left/top/right/bottom）
##     `1 → (-100,-100)-(0,50)`、`2 → (-400,-100)-(0,50)`、`3 → (-150,-150)-(150,50)`、
##     `4 → (-1200,-600)-(1200,600)`、其它 → 空；
##   · `AbstractAttackSkill.getSkillHitRect():571-582` ——
##     `y += 施法点.y`；朝左 `x += 施法点.x`；朝右 `x = -right + 施法点.x`。
## 注意 range 1/2 的表是**单侧**的（贴着朝向那一侧），range 3 是左右对称的 ——
## 所以镜像不能一律写成 `x - 宽`，得按 left/right 分别算。现在这段几何只有一份，
## 在 `脚本/角色/技能命中盒.gd`。
func 技能命中矩形(skill_id: String) -> Rect2:
	# 2026-10-01：定表与摆放抽去了 `脚本/角色/技能命中盒.gd`（`SkillHitBox`）——
	# 离线怪放技能要判同一件事（原版 `AttackExecute.canFireSkillTo`），不能抄第二份。
	return SKILL_HITBOX.由范围(int(GAME_DATA.skill(skill_id).get("range", 0)), position, facing)

## 能不能在这一刻放招 —— 原版只有一处判据：
##   `AbstractSkill.as:26` `exeMovementActions = [STAND, WALK]`（**默认只有站与走**）
##   + `:62-65 canExeMovementAction()` = `exeMovementActions.indexOf(movementAction) != -1`
##   + `:106-124 fire()`：站着放还要求 `currFoothold && grounded && landed`。
## ⇒ 跳（JUMP）与爬梯（CLIMB）都放不了技能；`CLIMB` 不在**任何**一支的表里，连普攻也不行。
## 两个例外照抄：普攻 `[JUMP, STAND, WALK]`（`CommonAttack.as:27`，跳砍可以）、
## 瞬移类 `[JUMP]`（`AbstractFlashJumpSkill.as:15`，只能空中放）—— 后者本工程还没接。
func _能放招(允许空中 := false) -> bool:
	if climbing:
		return false
	if not on_ground:
		return 允许空中
	# 站着但要"站稳"：原版 `fire():112-117` 的 `currFoothold && grounded && landed`
	return String(current_fh_id) != ""


func use_skill_slot(slot: int) -> void:
	# 出手动作没播完 = `movementAction == ATTACK`，它不在 `exeMovementActions` 里
	# ⇒ 原版这一刻同样放不出去（这就是"得等技能放完才能再动/再放"的那一半）。
	if 出手中:
		return
	## 金锄副本（406010000）里所有忍术都被拦掉并给提示 ——
	## `SkillHandler.fireSkillKeyDown():1108-1114` → `Job0.isSkillForbiden():422-427`
	## ⇒ `WARNING_NOT_SKILL_MAP`。普攻不走这条（`isSkillForbiden(0)` 之后 `defaultSkill` 回落 0）。
	if 禁寻路地图.是金锄副本(map_id):
		_提示(提示_此图禁忍术)
		return
	if not _能放招():
		return
	var 预检: Dictionary = GameSession.get_skill_in_slot(slot)
	var 预检号 := String(预检.get("id", ""))
	var 档 := int(GAME_DATA.skill(预检号).get("target", 0))
	## ⭐ #352：出手那一拍的 PVP 闸（原版 `SkillExecute.as:352-360`：`curTarget` 是
	## `Character` 而 `skillHandler.canAttack()` 为假 ⇒ **不发这一发**，只把
	## `pvpHandler.getNoAttackWarning(curTarget)` 那一句 `addNotice` 出去）。
	## 放在扣蓝/转 CD **之前** —— 与"单体没选中不放""够不着先走过去"那几条同一个口径，
	## 白转冷却在原版不存在。话是空串就什么都不说（见 `_说一句`）。
	var 盯的人: Node2D = null
	var 图根: Node = get_parent().get_node_or_null("LifeRoot")
	if 图根 != null and 图根.has_method("点中的玩家") and 图根.has_method("PVP能否出手"):
		盯的人 = 图根.call("点中的玩家") as Node2D
	if 盯的人 != null:
		var 判: Dictionary = 图根.call("PVP能否出手", 盯的人)
		if not bool(判["可打"]):
			_说一句(str(判["话"]))
			return
	## 当前目标：怪**或**那个已经过了闸的人（原版 `targetHandler.curTarget` 一个变量装两种类型）。
	var 选中 := _选中怪()
	if 选中 == null:
		选中 = 盯的人
	# ⭐ **单体（`target=1`）没有选中怪就不放这一发** —— 原版 `AbstractAttackSkill.hitTest():622-623`
	# 只把 `targetHandler.curTarget` 发出去，没有目标就没有这一号；
	# 而 `SkillExecute.moveToAttack()` 会先走到够得着再放。所以正确表现是"选中它 = 开始追打"，
	# **不是**"框到几只打几只"（用户 2026-10-10 报的那条）。放在扣蓝之前，免得白转冷却。
	if 档 == 1 and 选中 == null:
		# ⭐ **按技能键这件事本身会顺手锁目标** —— 原版 `SkillExecute.as:420-436`：
		# 当前没有目标时，拿这个技能的命中盒（`getSkillHitRect(技能, 玩家, 朝向)`）框一遍怪表，
		# 取**最近的一只**设成 `viewTarget` + `curTarget`、`stopPathFind()`，然后才走 `hitTest`。
		# ⇒ 玩家看到的就是"走到怪旁边按下 1，它自己朝最近那只放"（用户 2026-10-11 报的这条）。
		# 盒里真没怪才作罢（不是拿全图最近、也不是拿固定半径）。
		var 根: Node = get_parent().get_node_or_null("LifeRoot")
		if 根 != null and 根.has_method("get_enemies_in_rect"):
			var 框到: Array = 根.call("get_enemies_in_rect", 技能命中矩形(预检号))
			选中 = 技能目标选择.盒内最近(框到, global_position)
			if 选中 != null:
				_设为目标(选中)
				cancel_auto_path()
				自动接近目标 = 选中
	if 档 == 1 and 选中 == null:
		return
	## ⭐ **够不着 ⇒ 这一发不放，先走过去**（用户 2026-10-11 报的 #194：螺旋丸 / 雷切 / 烈焰斩 / 水之刃
	## 这种近战技，选中一只远处的怪按技能，应该**走进射程再放**，不是站原地打空）。
	## 原版 `SkillExecute.as:376-435` 那一整支**从头到尾没有 `fireSkill`**，它只做三件事：
	##   `curTarget = viewTarget`（:378-380）、是怪就 `toAttackAnemy = true` + `stopPathFind()`（:386-390）、
	##   收尾 `defaultSkill = param1`（:435）。真正放出去的是**下一拍** `tick()` → `moveToAttack()`：
	##   够得着 ⇒ 转身 + `fireSkill`（:122-127）；够不着 ⇒ `pathFind(目标.x, 目标.y − 5)`（:133-158）。
	## ⇒ "按一下就扣蓝转冷却、结果挥了个空"在原版不存在，所以这条判据放在扣蓝之前。
	if 档 == 1 and not 技能够得着(预检号, 档, 选中):
		GameSession.设默认忍术(int(预检号))		# 对应 :435：按下哪一枚，追打时就用哪一枚
		_面向目标(选中)
		## ⚠ 目标若是**玩家** ⇒ 只记招式号、转身，**不挂追击**。
		## 原版 `SkillExecute.moveToAttack()` 对人确实也会 `pathFind`，但本工程"点人 = 选中"
		## 这条链（`TargetHandler` 那一套）之外没有配"追人"的落脚点/层带口径，
		## 自造追击路线是本任务明确不要的行为 ⇒ 记为未决（#352：等 `_冲选中目标`
		## 那一条能读人的 `alive`/层号之后再接）。够得着才出手，所以现在站着放不了就不放。
		if 图根 != null and 图根.has_method("玩家角色号") \
				and int(图根.call("玩家角色号", 选中)) <= 0:
			自动接近目标 = 选中
		return
	## ⭐ **放出去之前先面向目标**（原版 `SkillExecute.as:125`，见 `_面向目标` 的注释）。
	##   放在扣蓝之前：转身是这一发的一部分，不是"打完了再摆个姿势"。
	##   档 3（自身技）没有目标可言 ⇒ `_选中怪()` 为空时自然不转。
	_面向目标(选中)
	if not GameSession.use_skill(slot):
		return
	var skill: Dictionary = GameSession.get_skill_in_slot(slot)
	var skill_id := String(skill.get("id", ""))
	var damage := int(GameSession.player_stats.get("attack", 24)) + int(skill.get("power", 0)) * int(skill.get("level", 1))
	_出技能动作(skill_id)
	_上次施法特效 = _spawn_skill_effect(skill_id)
	# ⭐ **没选目标时自动选敌**：原版 `AbstractAttackSkill.createSkillMsg():239-257` 走的就是这条 ——
	# 拿技能命中矩形去框，**框到的怪全部作为目标**（不是最近一个、也不需要玩家先点怪）。
	# 以前这里是"以角色前方 48px 为心、半径 130+槽位*18 的圆"，半径是自造的，圈不到就打空。
	var 命中盒 := 技能命中矩形(skill_id)
	var life_root := get_parent().get_node_or_null("LifeRoot")
	var enemies: Array = []
	if life_root != null:
		## #352：框到的目标 = 怪（原口径原顺序）+ **可打的玩家**并表。
		## 原版面积技那条是 `createSkillMsg` 不带目标、服务端按范围结算（`target=2` 那一支），
		## 本工程服务端只结算客户端报上来的那一批 ⇒ 这里把"人"一起报上去，
		## 并且人**已经在 `可打的玩家` 里过完 PVP 判定**（打不了的人不会被报）。
		enemies = _框住目标的表(life_root, 命中盒)
	# 报几只怪 = 原版那个 switch（判据与行号在 `脚本/角色/技能目标选择.gd` 顶部）：
	# 1 = 只报选中的那一只；2 = 面积报命中盒框到的全部；3 = 自身技不报怪。
	# ⚠ 原来这里有一句"没选目标就拿框到的第一只去 `显示目标框`" —— 那是**施法自己改选目标**，
	#   原版没有这一号（选中只由点怪和挂机挑怪改），删掉。
	var 目标: Array = 技能目标选择.目标(档, enemies, 选中)
	上次施法目标 = 目标.duplicate()		# 门要判「这一发报出去了哪几只」
	施法次数 += 1
	if 施法目标历史.size() < 32:
		施法目标历史.append(目标.duplicate())
	# 技能已经出过手了（`_出技能动作`），这里只做命中结算，别再走 perform_basic_attack
	# ——它会因为 `出手中` 直接返回 false，技能就成了空挥。
	var hit := not 目标.is_empty()
	var 加成 := _技能加成攻击(skill_id, int(skill.get("level", 1)))
	var online := _backend != null and bool(_backend.get("in_game"))
	## ⭐ **出手这一拍就把 1328 广播发出去，不管有没有目标**（2026-10-14 用户实机
	## "从别人窗口看技能特效延迟也很高"）。上一轮 #193 为了"弹到身上才算伤害"，
	## 把广播与结算**捆在一起**压到命中帧 ⇒ 旁观者要看投掷技得等整段飞行时间（几百毫秒），
	## 而在木叶村这种周围没怪的地方目标列表是空的，干脆一发都不发。
	## 原版的分工：`AbstractAttackSkill.hitTest():629` 一出手就发广播（动画/特效归它），
	## 伤害本来就是客户端在**命中帧**算的（那才是 #193 要压的那一条）。
	if online:
		_广播出手(skill, 目标)
	var 有球 := hit and 技能动画.有相位(skill_id, "ball")
	var 在飞 := false
	if 有球:
		# 投掷类技能。**飞行物两种模式都要放** —— 原版里特效/飞行物是客户端表现
		# （`AbstractThrowSkillEffect` 全程在客户端跑），差别只在伤害由谁算：
		# 离线等命中自己结算（`canApplayDamage()` 返回 false 就是不让命中帧直接结算），
		# 在线把**伤害请求**也压到命中那一帧再发（见 `_发技能攻击请求` 的注释）。
		在飞 = _放飞行物(skill_id, 目标, 加成, not online,
				_发技能攻击请求.bind(skill, 目标) if online else Callable())
	if online:
		## ⭐ **#193 在线的投掷技也要等弹到身上才算伤害**：服务端一收到 42 就立刻结算并回包，
		## 掉血与受击特效跟着回包当场出现 —— 飞行物还在半路，玩家看到的就是"先掉血、后飞到"。
		## 这里只压**结算**那一条；广播已经在上面 `_广播出手` 当场发出去了。
		## 弹没放出去（没球美术 / 配置失败）⇒ 照旧立刻结算，不能因为等不到命中就把这一发吞了。
		if not 在飞:
			_发技能攻击请求(skill, 目标)
		return
	if not 有球:
		for enemy in 目标:
			if enemy != null:
				_结算一只(enemy, 加成)
	if hit and skill_id == "0002000":
		# 治疗量沿用原来那口（`damage` 只在这条用得上，不再参与伤害）
		GameSession.heal_player(maxi(1, damage / 4))

## 最近一次的施法特效节点 —— 飞行物要**等它播完**才现形
## （`AbstractThrowSkillEffect.canBallAppear()`：`ballAfter == 0` 时看 `effect.actionEnd()`）。
## 最近一发技能**报出去的目标**（原版 `hitTest()` 那个 switch 的结果）。
## 门判「单体只报选中的那一只 / 面积报框到的全部」要看这个：血量得等飞行物落地，
## 拿它当唯一观测点会假红（实测同一份代码 5 次红 1 次）。
var 上次施法目标: Array = []
## 真正放出去的每一发：次数 + 各发了谁（封顶 32 条，只给量具看）。
## 有这两个量，门就不必拿"血量掉没掉"当观测点 —— 血量要等飞行物落地，会假红。
var 施法次数 := 0
var 施法目标历史: Array = []

var _上次施法特效: Node2D = null

## 返回建出来的特效节点（没有就返回 null）—— 飞行物要拿它判"该不该现形"。
func _spawn_skill_effect(skill_id: String) -> Node2D:
	if skill_id.is_empty() or not bool(GameSession.game_settings.get("show_skill_effects", true)):
		return null
	var effect := SkillAnimation.new()
	# 锚点 = **施法者的脚点**，前后位置交给美术自己的 `origin`
	# （`AbstractCloseAttackEffect.as:115`：`new Point(character.x, character.y)`）。
	# 以前额外推了 `(facing*48, -24)`，是自造的。
	effect.position = global_position
	effect.set_direction(facing)
	get_parent().add_child(effect)
	if not effect.configure(skill_id):
		effect.queue_free()
		return null
	return effect

## 抛一个飞行物；命中时才对 `enemies` 里还活着的那几只结算，并在**受击者身上**放命中特效。
## 返回**是否真的有一个飞行物在飞**（没球美术 / 配置失败 ⇒ 假，调用方要当场把伤害补上，
## 不能因为等不到"命中"就把这一发吞了）。
## `在线补发` = 在线那一档要在命中帧发出的伤害请求（#193）。
func _放飞行物(skill_id: String, enemies: Array, 加成: int, 结算伤害 := true,
		在线补发: Callable = Callable()) -> bool:
	var 目标 := enemies[0] as Node2D
	if 目标 == null:
		return false
	var 弹 := 飞行物脚本.new() as Node2D
	get_parent().add_child(弹)
	var 延迟 := 技能动画.相位参数(skill_id, "ball", "ballAfter", 0)
	if not bool(弹.call("配置", skill_id, self, 目标, facing, 延迟, _上次施法特效)):
		弹.queue_free()
		return false
	弹.connect("命中", func(受击: Node2D) -> void: _飞行物命中(skill_id, enemies, 加成, 受击, 结算伤害, 在线补发))
	return true

## 在线那一档的**伤害结算请求**（42）。原来这段直接写在 `use_skill_slot` 里（按下就发），
## 现在离线/在线两条都在**命中帧**调它 —— 包体一字未改，只改发送时机（#193）。
func _发技能攻击请求(skill: Dictionary, 目标: Array) -> void:
	if _backend == null:
		return
	var target_ids: Array = []
	var 人号: Array = []
	_pvp拆分(目标, target_ids, 人号)
	if target_ids.is_empty() and 人号.is_empty():
		return
	var 出手号 := 原始精灵脚本.动作号(_出招动作名)
	## 打怪那一发**包体一字未改**（`target_ids` 为空时它自己 return false，与以前一样）。
	if not target_ids.is_empty():
		_backend.call("request_skill_damage", int(skill.get("id", 0)), int(skill.get("level", 1)),
				target_ids, facing, 出手号 if 出手号 > 0 else 11)
	## #352：同一招打到**人** ⇒ 再补一发 42，targets 那格换服务端角色号
	## （原版这一发本来就是"打怪/打人同一张帧、靠 isPlayer 与目标号类型分家"）。
	if not 人号.is_empty():
		_backend.call("request_pvp_skill_damage", int(skill.get("id", 0)), int(skill.get("level", 1)),
				人号, facing, 出手号 if 出手号 > 0 else 11)


## 把一批发射目标拆成"怪的 object_id"与"玩家的服务端角色号"两串。
## 判据只有一条：节点上有没有 `pk_char_id` 这枚 meta（`地图实体._攻击身份` 只在 162
## 出场帧给远程玩家挂它）⇒ 怪 / NPC / 掉落物一律走原来那串，打人链不误伤它们。
func _pvp拆分(目标: Array, 怪号: Array, 人号: Array) -> void:
	for enemy in 目标:
		if not (enemy is Object) or not is_instance_valid(enemy):
			continue
		var 号 := int((enemy as Object).get_meta("pk_char_id", 0))
		if 号 > 0:
			人号.append(号)
		else:
			怪号.append(int((enemy as Object).get("object_id")))

## 在线那一档的**出手广播**（1328）：动作 + 起手特效 + 服务端那"授权每个目标的伤害回包"的登记。
## ⚠ **没有目标也要发**（列表给空数组，`后端连接` 把目标槽写成 `-`）—— 原版 `hitTest():629`
## 一出手就发，旁观者看的是"他在放这一招"，跟这一招打没打到谁无关。
func _广播出手(skill: Dictionary, 目标: Array) -> void:
	if _backend == null:
		return
	var target_ids: Array = []
	var 人号: Array = []
	_pvp拆分(目标, target_ids, 人号)
	var 出手号 := 原始精灵脚本.动作号(_出招动作名)
	if 人号.is_empty():
		## 这一发没打到人（**含目标列表为空那一档 —— 空列表也要发**）⇒ 原样那一发，一个字节都不变。
		_backend.call("announce_skill_cast", int(skill.get("id", 0)), int(skill.get("level", 1)),
				target_ids, global_position, facing, 出手号 if 出手号 > 0 else 11)
		return
	if not target_ids.is_empty():
		## ⚠ 面积技**同时**框到人和怪 ⇒ 发两发 1328（怪那发填 `monsters(@)`、人那发填
		## `players(@)`）。旁观者会把起手动画看两遍 —— 一帧只有一组目标槽的直接后果，
		## 等服务端肯同时吃两组之后再收成一条（记为未决 #352）。
		_backend.call("announce_skill_cast", int(skill.get("id", 0)), int(skill.get("level", 1)),
				target_ids, global_position, facing, 出手号 if 出手号 > 0 else 11)
	_backend.call("announce_pvp_skill_cast", int(skill.get("id", 0)), int(skill.get("level", 1)),
			人号, global_position, facing, 出手号 if 出手号 > 0 else 11)

func _飞行物命中(skill_id: String, enemies: Array, 加成: int, 受击: Node2D, 结算伤害 := true,
		在线补发: Callable = Callable()) -> void:
	# 命中特效（原版 `SkillHit`，由 `DamageHandler` 在结算时挂）锚在**受击者**身上 ——
	# 和怪物那条（`地图实体._on_server_monster_skill_hit`）同一个口径。
	if 受击 != null and is_instance_valid(受击) and 技能动画.有相位(skill_id, "hit"):
		var 特效 := SkillAnimation.new()
		get_parent().add_child(特效)
		特效.position = 受击.position
		if not 特效.configure(skill_id, "hit"):
			特效.queue_free()
	if not 结算伤害:
		## 在线：伤害由服务端算 ⇒ **弹到身上这一帧**才把请求发出去（#193）。
		if 在线补发.is_valid():
			在线补发.call()
		return
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy) and bool(enemy.get("alive")):
			_结算一只(enemy, 加成)

## 每次"取消自动寻路"都 +1。跨图路线挂在 HUD（`小地图面板`）里，而原版这两件事本来就归
## 同一个 `KeyController` 管 —— 手动按键 / 出招 / 技能都会走 `stopPathFind()`（`:1205-1212` 与
## `SkillHandler.as:278`），它连跨图那包一起清（`:1577-1590`）。本工程 HUD 只能轮询玩家，
## 所以拿这个印当"刚才取消过"的信号，免得 HUD 去反向猜。
var auto_path_cancel_stamp := 0
## 路线**走完**（最后一个关节落到位）时 +1，被打断时不动。
## 原版 `KeyController.as:212` 只在路径关节走完那一刻发 NPC 对话（`talkToNPC` + `requestNPCTalk`），
## `stopPathFind` 半路掐掉那一支（`:196-211`）不说话；两条都会让 `click_move_active` 变假，
## 所以要另立一个只认"走到头"的印，HUD 才分得开。
## ⚠ 走完也走 `cancel_auto_path()`（同一个收尾），所以 `auto_path_cancel_stamp` 分不出来。
var auto_path_arrive_stamp := 0


## 目标信息条上「点头像取消选中」（原版 `onClickHead():473-476` = `API.targetHandler.cancelTarget()`）
## 之后，**追打这一路也要停** —— 原版的 `toAttackAnemy` 是挂在 target 上的，target 一空就不再走。
func 停止追打() -> void:
	自动接近目标 = null


func cancel_auto_path() -> void:
	## 原版 `KeyController.as:442-449`：停路线时 `PathFindDst` 与 `PathFindingTip` 一起 removeChild。
	auto_path_cancel_stamp += 1
	_设自动寻路态(false)
	click_move_active = false
	click_replan_pending = false
	click_climb_direction = 0.0
	auto_jump_direction = 0
	auto_actions.clear()
	auto_action_index = 0

## 打坐身上的光环（原版 `Character.tickHealAnimation():2742-2765`）。
## 原版的写法是**每帧判一次动作**："是坐的动作就挂上、不是就从角色身上摘掉"，
## 这里同口径 —— 三个开关出口都调一次，不靠"开始打坐时建一个"（那样中途被别的逻辑
## 直接改掉 `is_practising` 就会留一个挂在身上的孤儿特效）。
var _打坐光环: Node2D = null

## 双修时那具**打坐的人**上下浮 8 像素（原版 `CharacterHandler.tickHealDouble:725-759`）。
## 三条口径都照字面抄，别"顺手修正"成看着更顺眼的连续波动：
## · 只有 `healSinTime > HEAL_TIME_SIN(=10000 毫秒)` 才开始浮 ⇒ 坐下头 10 秒是**不动的**；
## · 到 `10000 + π·500·3`(≈4712 毫秒，正好 1.5 个周期、sin(3π)=0 回到原点) 把计时清零
##   ⇒ 于是节奏是「浮 4.7 秒 → 停 10 秒 → 再浮」，原版就是这么写的；
## · `Math.floor` 取整 ⇒ 偏移是整数像素（不是亚像素抖动）。
## ⚠ 「谁算」与「谁动」是两件事，别抄错：进入条件里那句 `param1 == API.player`（`:731`）说的是
## **选举** —— 本地这一具抢到 `healMain`，只有它累加 `healSinTime`、只有它算 sine；
## 而紧接着一行 `_loc3_.y = param1.y`（`:754`）把算出来的 y **抄给对面那一具**
## ⇒ 原版屏幕上是**两个人一起浮**（另一具不自己算，跟着贴同一水平线）。
## 本工程这一支只算本地这一具，抄那一具在 `脚本/地图/地图实体.gd::_双修对坐`。
const 双修起浮毫秒 := 10000.0			# `HEAL_TIME_SIN`（`CharacterHandler.as:50`）
const 双修浮幅 := 8.0				# `8 * Math.sin(...)`（`:753`）
const 双修一轮毫秒 := float(PI) * 500.0 * 3.0	# 归零那一档（`:755`）
var _双修毫秒 := 0.0
var _浮动偏移 := 0.0
var _浮基准y := 0.0			# 上一帧物理算完的那个"真落脚点"，收回时按它赋值（不做浮点往返）

## 双修成了没有：服务端那一份 `86:1` 里 `partner_id` 非 0。
## 只管"是不是双修"这一件事 —— 姿势（`sit1`）与浮动都读它，别各写一份判定。
func _双修已成() -> bool:
	if _backend == null:
		return false
	return int((_backend.get("authoritative_heal") as Dictionary).get("partner_id", 0)) != 0

## 坐着该播哪一帧：单修 `sit0`（正面打坐）、双修 `sit1`（侧身对坐）。
## ⚠ 三处坐下（`toggle_practise` / `set_practising` / 每帧那段）一律走这里，
## 别在调用那头各写一遍 `play("sit0")` —— 10-17 用户报"双修姿势不对"就是这三处写死了 sit0。
func _播放坐姿() -> void:
	if player_sprite == null:
		return
	player_sprite.play("sit1" if _双修已成() else "sit0")

## 双修摆位要"转身朝向对方"（`HealHandler.as:421/432` 的 `direction = RIGHT/LEFT`）。
## ⚠ 必须连精灵一起设：每帧那一段只在 `dir != 0`（有人真按着方向键）时才刷朝向，
## 而坐着不动 ⇒ 只改 `facing` 的数据、屏幕上还是坐下前那一侧 ⇒ 摆位等于白做。
func 强制朝向(方向: int) -> void:
	facing = 方向
	if player_sprite == null:
		return
	if player_sprite.has_method("set_direction"):
		player_sprite.call("set_direction", 方向)
	else:
		player_sprite.set("flip_h", 方向 < 0)

## 这一帧该不该浮：坐着 **且** 双修已成。
func _双修在浮() -> bool:
	return is_practising and _双修已成()

## 把上一帧浮出去的那几像素收回来。**必须排在 `_physics_process` 最前面**：
## 层号(`z_index`)、落脚点吸附、发对面的位置帧都在这之后读 `position.y`，
## 让它们看到的是**真基准**而不是浮动的量 —— 原版广播的是浮后的 y，
## 本工程广播基准值（±8 像素不该把对面的落脚点吸附带偏，见真值表那条偏离记录）。
func _收回双修浮动() -> void:
	if _浮动偏移 != 0.0:
		## ⚠ **按记下的基准赋值**，不要写 `position.y -= _浮动偏移`：
		## 那是一次"减回去"的浮点往返（`a - (a - b)` 不保证等于 `b`），
		## 1 个 ULP 的残差会被后面的落脚点/层号放大成两拍轨迹分叉（10-17 打坐门实测红 2 条就是这么来的）。
		position.y = _浮基准y
		_浮动偏移 = 0.0

## 排在 `_sync_backend_movement()` **之后**：物理全算完、这一发也发完了，才把身体抬起来画。
func _推进双修浮动(秒: float) -> void:
	if not _双修在浮():
		_双修毫秒 = 0.0
		_收回双修浮动()
		return
	_双修毫秒 += 秒 * 1000.0
	if _双修毫秒 <= 双修起浮毫秒:
		return
	## `基准` = 这一帧物理算完的真落脚点（把上一帧的浮动减掉之后那个 y）。
	## ⚠ `floor()` 这类全局数学函数回的是 Variant ⇒ **必须写显式类型**，
	## 否则 `:=` 推成 Variant，被本工程那条"警告当错误"的门直接拒掉（实测 parse 失败）。
	var 基准 := position.y
	var 目标: float = floor(基准 - 双修浮幅 * sin((_双修毫秒 - 双修起浮毫秒) / 500.0))
	_浮动偏移 = 目标 - 基准
	_浮基准y = 基准
	position.y = 目标
	if _双修毫秒 >= 双修起浮毫秒 + 双修一轮毫秒:
		_双修毫秒 = 0.0

## 相机该跟的那个点 —— 把"只为画而抬起来"的那几像素摘掉，回真落脚点。
## 原版这条不是显式写的，是**死区**给的：`Camera.tick()` 走 `gotoFocusObject`（`Camera.as:97-155`），
## 焦点确实是 player 本体（`World.as:287` `setFocusObject(this.player)`，读的 y **含**那 ±8），
## 但外面套着一张 256×256 的 `_innerRect`：焦点没走出死区 ⇒ `_rect` 一格都不动 ⇒ 镜头静止。
## 本工程是**每物理帧硬跟** `global_position`（没有死区），所以必须在这里显式摘掉偏移，
## 否则浮动会顺着相机变成"整幅世界上下动"（用户 2026-10-17 报的那一条）。
## ⚠ 死区那一整条**没有**照抄 —— 它会改掉平时走路的手感（角色会先走离屏幕中心 128 像素
## 相机才动），要改要单独点头，见 `真值/窗口/双修邀请窗.md` 那条未决。
func 相机锚点() -> Vector2:
	return global_position - Vector2(0.0, _浮动偏移)

func _刷新打坐光环() -> void:
	if is_practising and _打坐光环 == null:
		_打坐光环 = 打坐光环场景.instantiate() as Node2D
		_打坐光环.name = "打坐光环"
		add_child(_打坐光环)
		# 原版 `adjustLayer()` 两张表（`Character.as:1626`、`:1414`）都把 `healQueueAnimation`
		# 排在 `animation` **之后**、`_namePane` **之前** ⇒ 光环盖住身体、但被头顶名字压在下面。
		# 本工程的名字牌是 spawn 时就挂好的 `Nameplate`（`地图实体._create_nameplate:1444`），
		# 而光环是坐下时才建 ⇒ 直接 add_child 会排到名字之后、同 z 值按树序把名字糊掉。
		var 牌: Node = get_node_or_null("Nameplate")
		if 牌 != null:
			# ⚠ Godot 4 **没有**"取某节点下标"的方法（`get_child_index(i)` 是按下标取节点），
			#   写错会让整个 玩家.gd parse 失败 ⇒ 进图没有玩家。
			var 序: int = get_children().find(牌)
			if 序 >= 0:
				move_child(_打坐光环, 序)
	elif not is_practising and _打坐光环 != null:
		if is_instance_valid(_打坐光环):
			_打坐光环.queue_free()
		_打坐光环 = null

func toggle_practise() -> bool:
	if is_practising:
		_stop_practise()
		return false
	if 禁寻路:
		## 禁寻路图里打坐/双修请求被原版直接咽掉（`Client.as:4340` / `HealHandler.requestHealStart():349-353`）
		## ⇒ 这里连本地坐姿都不该起来，否则画面坐着、服务端没有任何响应。
		return false
	if not on_ground or climbing:
		return false
	cancel_auto_path()
	velocity.x = 0.0
	is_practising = true
	_播放坐姿()
	_刷新打坐光环()
	return true

func set_practising(active: bool) -> void:
	if active:
		if 禁寻路:
			return
		if not on_ground or climbing:
			return
		cancel_auto_path()
		velocity.x = 0.0
		is_practising = true
		_播放坐姿()
		_刷新打坐光环()
	else:
		_stop_practise()

func _stop_practise() -> void:
	if not is_practising:
		return
	is_practising = false
	if player_sprite != null and on_ground and not climbing:
		player_sprite.play("stand")
	_刷新打坐光环()

## 把"我停止打坐"这件事**告诉服务端**（上行 `86:2`）。
## ⚠ 必须与 `_stop_practise()` 成对：只清本地状态 = 服务端还当他在打坐，
## 于是双修不中断、单人奖励照发、对面那具永远挂在双修坐上（用户 10-17 报的那条）。
## 离线量具里没有会话 ⇒ 这里按 `in_game` 自己咽掉，不许让显示层去要求一条连接。
func _上行停坐() -> void:
	if _backend == null or not bool(_backend.get("in_game")):
		return
	打坐打断诊断 = "动了一步 ⇒ 已上行 86:2（服务端态=%s）" % str(
			int((_backend.get("authoritative_heal") as Dictionary).get("state", 0)))
	_backend.call("request_heal_stop")

func advance_auto_action() -> void:
	auto_action_index += 1
	click_climb_direction = 0.0
	if auto_action_index >= auto_actions.size():
		auto_path_arrive_stamp += 1
		cancel_auto_path()

func replan_auto_path() -> void:
	if not on_ground or current_fh_id == "":
		return
	auto_actions = auto_pathfinder.plan(current_fh_id, click_target_fh_id, click_move_x, position.x)
	auto_action_index = 0
	click_replan_pending = false
	click_climb_direction = 0.0
	auto_jump_direction = 0
	click_move_active = not auto_actions.is_empty()

## 穿台直落 —— 原版 `KeyController.jumpDownTarget()`（`:1592`）：向下的那一步（寻路的
## `drop` 边、以及"目标在下"的 `jump` 边）是**从脚下平台穿下去**（原版 `target.y += 5`、
## 速度归零后由重力接管），**不是向上跳**。
## ⚠️ 若按向上跳执行：人跳起又落回**本层**、落地判定对不上目标分量 ⇒ `auto_action_index`
##    永不推进 ⇒ **原地反复起跳**（2026-10-04 用户报"不会自己下降平台"）。
func _穿台下落() -> void:
	on_ground = false
	跳起中 = true
	爬顶跳中 = false
	current_fh_id = ""
	position.y += 4.0
	velocity.y = 80.0
	## 原版 `jumpDownTarget():1596-1601` 是 `x:0, y:0`（纯直落），落地前没有横向控制。
	## 以前只在禁寻路图清 x ⇒ 普通图上"下+跳"时若还按着方向键，人会边穿台边横着飘，
	## 飘出平台边缘后就再也落不到脚点上（用户 2026-10-30 报的另一半）。
	velocity.x = 0.0

## ── 禁寻路图（迷路森林 406010000 / 森林出口 406010001）──────────────────────────
## 原版这类图把整个控制器换掉：`PlayerController.tick():295-309` 判 `nowInNotFindPathMap`
## 就只跑 `tickInJingSuMaps()`。所以**左右键、点地走、自动寻路在这里全都没有**，
## 取而代之的是"自己一直朝朝向走 + 撞墙掉头 + 踩箭头弹射"。
const 提示_无法寻路 := "在当前地图无法开启自动寻路"		# `NOT_PATH_FIND`（`en_US$core_properties.as:33`）
const 提示_此图禁忍术 := "在当前地图不能使用该忍术"		# `WARNING_NOT_SKILL_MAP`（同上 :76）

## 这一帧该朝哪边走 —— 原版 `tickInJingSuMaps():67-85`：
##   撞在右边且人正朝右 ⇒ 掉头向左；撞在左边且正朝左 ⇒ 掉头向右；
##   其余一律朝当前朝向走（原版 `movementAction == STAND` 的那一支，本工程地面永远算"在走"）。
## 旗标读完即清；原版 `checkInit():246` 也是每帧先清零、撞上再置位。
func _禁寻路方向() -> int:
	var 右 := 右被挡
	var 左 := 左被挡
	右被挡 = false
	左被挡 = false
	if 右 and facing > 0:
		return -1
	if 左 and facing < 0:
		return 1
	return facing

## 踩到地图上的箭头 / 火箭（原版 `PlayerController.onTouchItem()`，`PlayerController.as:250-290`）。
##
## 15037001 = 就地掉头（`toZheFan():209-217` 转调 `moveLeft/RightTarget`，人不起跳）；
## 其余八枚都是"射出去"：`setVelocity({x: walkSpeed × X, y: jumpSpeed × Y})`，系数在
## `JingSuFuBen` 表里按 `aspect × speed` 折算（`JinChuFuBenRolesSpeedManager.as:76-127`）；
## 15037006/07/08/09 先改朝向再射（`jumpLeft/Right*Target2` 各自带 direction）。
func onTouchItem(物品号: int) -> void:
	if not 禁寻路:
		return
	if 物品号 == 15037001:
		facing = -facing
		if not climbing:
			velocity.x = float(facing) * move_speed
		return
	var 键 := ""
	match 物品号:
		15037002: 键 = "downJianTouSpeed"
		15037003: 键 = "upJianTouSpeed"
		15037004: 键 = "upHuoJianSpeed"
		15037005: 键 = "downHuoJianSpeed"
		15037006: 键 = "leftUpHuoJianSpeed"
		15037007: 键 = "rightUpHuoJianSpeed"
		15037008: 键 = "leftDownHuoJianSpeed"
		15037009: 键 = "rightDownHuoJianSpeed"
		_:
			return
	if 物品号 == 15037006 or 物品号 == 15037008:
		facing = -1
	elif 物品号 == 15037007 or 物品号 == 15037009:
		facing = 1
	climbing = false
	自动爬梯中 = false
	on_ground = false
	current_fh_id = ""
	velocity = 禁寻路地图.速度(键, move_speed, jump_speed)

## 一行右下角提示（原版 `UI.addNotice`）。本工程没有单独那一层，落到「获得提示」那一列。
func _提示(文本: String) -> void:
	if _backend == null or not _backend.has_signal("获得提示"):
		return
	_backend.emit_signal("获得提示", 文本)

## 走一条已排好的点击路线（`auto_actions`），返回这一帧该走的方向。
##
## 这段原来内联在 `_physics_process` 的 `elif click_move_active …` 分支里；2026-10-01
## 抽成函数，是为了让「点怪走过去打」那条命令**也能走它**（§3.56.17 那条命令以前是
## 直线朝 x 挪，怪在上一层平台时会撞墙够不着）。**逻辑逐行照搬，没有改判据。**
func _走点击路线() -> int:
	var dir := 0
	if not (click_move_active and auto_action_index < auto_actions.size()):
		return 0
	var action: Dictionary = auto_actions[auto_action_index]
	if action.type == "walk" and on_ground:
		if auto_pathfinder.get_component(current_fh_id) != int(action.target_component):
			replan_auto_path()
		else:
			var target_delta: float = float(action.x) - position.x
			if absf(target_delta) <= CLICK_STOP_DISTANCE:
				position.x = float(action.x)
				advance_auto_action()
			else:
				dir = 1 if target_delta > 0.0 else -1
	elif action.type == "climb":
		if on_ground:
			var ladder_delta: float = float(action.x) - position.x
			if absf(ladder_delta) <= CLICK_STOP_DISTANCE:
				position.x = float(action.x)
				climbing = true
				自动爬梯中 = true
				on_ground = false
				velocity = Vector2.ZERO
				click_climb_direction = float(action.direction)
				if click_climb_direction > 0.0:
					var route_ladder: Dictionary = action.ladder
					position.y = maxf(position.y, float(route_ladder.y1) + 4.0)
					current_fh_id = ""
			else:
				dir = 1 if ladder_delta > 0.0 else -1
		elif not climbing:
			replan_auto_path()
	elif action.type == "jump":
		if on_ground:
			var jump_delta: float = float(action.x) - position.x
			if absf(jump_delta) <= CLICK_STOP_DISTANCE:
				position.x = float(action.x)
				auto_jump_direction = int(action.direction)
				if bool(action.get("down", false)):
					_穿台下落()
				else:
					velocity.y = -jump_speed
					跳起中 = true
					爬顶跳中 = false
					on_ground = false
			else:
				dir = 1 if jump_delta > 0.0 else -1
		elif not climbing:
			var landing_delta: float = float(action.landing_x) - position.x
			if auto_jump_direction > 0:
				dir = 1 if landing_delta > 0.0 else 0
			elif auto_jump_direction < 0:
				dir = -1 if landing_delta < 0.0 else 0
	elif action.type == "drop" and on_ground:
		var drop_delta: float = float(action.x) - position.x
		if absf(drop_delta) <= CLICK_STOP_DISTANCE:
			_穿台下落()
		else:
			dir = 1 if drop_delta > 0.0 else -1
	return dir

## 键盘被文本输入框占着时，下面那几个动作键一律当"没按"。
##
## 真值：原版靠 Flash 的**舞台焦点**分流 —— `ChatPane.__onKeyDown`（`ChatPane.as:813`）
## `if(API.stage.focus == this.inputTextField)` 那一支把键全喂给输入框，键盘事件
## **根本走不到 `KeyController`**，所以在聊天框里打字不会顺手走路/跳跃。
## Godot 这边：`Input.is_action_pressed` 是**轮询 Input 单例**、不认 GUI 焦点
## （认焦点的只有 `_unhandled_input` —— `技能面板.gd:29` 的快捷键格用的就是那条）
## ⇒ 不自己挡的话，在聊天框/搜索框里打 "asd" 会一边打字一边左右移动、按空格还会跳。
## （`聊天面板.is_input_focused()` 早就在那儿、一直零调用点 —— 就是为这件事留的。）
func _键盘被文本占用() -> bool:
	var 焦点 := get_viewport().gui_get_focus_owner()
	return 焦点 is LineEdit or 焦点 is TextEdit


## 头顶挂件的落点（选中箭头）。怪/NPC 那一侧同一个式子在 `战斗角色._更新头顶挂件位置()`，
## 原版对**玩家**也是这么算的：`Character.as:1469-1470`
## `MobMouseOverEffectSkin.x = 0; y = -_crtCharHeight - 8`，而 `_crtCharHeight` 是
## **当前帧**的贴图高（`:2508` 每帧刷）。以前玩家节点上根本没有这个方法 ⇒
## `地图实体._attach_selection_marker()` 那句 `has_method` 落空，箭头就停在角色原点
## （= 脚边，还压在名字牌上）—— 用户 10-15 实机图打回的那一条。
## 名字与怪侧**保持一致**：挂上箭头时（`_attach_selection_marker`）与每帧都会调这一条。
func _更新头顶挂件位置() -> void:
	var 箭头 := get_node_or_null("SelectionMarker") as Node2D
	if 箭头 == null:
		return
	var 高 := 0.0
	if player_sprite != null and player_sprite.has_method("当前贴图高度"):
		高 = float(player_sprite.call("当前贴图高度"))
	## 量不到高（帧数据缺失/精灵还没建）⇒ **不动**，别把它按 0 处理掉到脚边去。
	if 高 > 0.0:
		箭头.position = Vector2(0.0, -高 - 8.0)


## 八门「开通穴道」读秒（原版 `Character.tickMaiDelay:290-328`）。
## 每秒换一枚 `ColorNumber(剩余秒, NoBlue0)`：数字素材是
## `素材/特效/Effect_colorNumber/NoBlue0/%d.png`，`ColorNumber.dicts` 里
## **第 1 帧是 "0"**（`ColorNumber.as:52`: `[null,"0","1",...,"9","miss"]`）
## ⇒ 数字 d 对应文件 `d+1.png`。
## 原版竖直账：`Character.as:2380/2508` `_crtCharHeight = 当帧贴图高 + 3`，
## `:313` `_maiNum.y = -_crtCharHeight - 5`；而 `ColorNumber.as:65` 拼串**只挪 x、从不挪 y**
## ⇒ 那个 y 钉的是画布的**顶边**，`NoBlue0` 每帧画布 31×33 且墨迹贴着下沿（十个数字实测顶空 0~1、底空 0）
## ⇒ 照搬就是把 33 px 的数字**从头顶往下垂**，压在头上（用户 2026-10-22 报修 2）。
## ⚠ **有意偏离**（不是修漏）：把整串**底边**摆到原版顶边那个位置 ⇒ 数字整体落到头顶之上，
## 而 `+3` 与间距 `5` 这两个常数照旧保留，日后要还原只需把 `_八门串高` 改成 0。
const 八门读秒纹理 := "res://素材/特效/Effect_colorNumber/NoBlue0/%d.png"
const 八门读秒抬 := 3.0		# `Character.as:2380/2508` 的 `charHeight + 3`
const 八门读秒距 := 5.0		# `Character.as:313` 的 `- _crtCharHeight - 5`

var _八门剩余毫秒 := 0.0
var _八门读秒节点: Node2D = null
var _八门读秒显示 := -1
var _八门串高 := 0.0		# 当前这串数字的墨迹高，抬到头顶之上时要用它当抬升量
## `1290:1` 的第 4 个字段 = `lastPt`（这一枚是不是该门最后一个穴位）⇒ 归零时的爆点
## 「小/大」由它决定：`addExploreEffect(this, !lastPt)` —— **最后一枚放大**。
var _八门最后一点 := false


## `Client.onMaiDelayExplode` → `CharacterHandler.maiDelayExplode` → `Character.maiDelayExplode`。
func 开始八门读秒(秒: int, 最后一点 := false) -> void:
	_八门最后一点 = 最后一点
	_八门剩余毫秒 = maxf(0.0, float(秒) * 1000.0)
	_八门读秒显示 = -1
	_刷新八门读秒()


func _刷新八门读秒() -> void:
	var 显示 := int(ceilf(_八门剩余毫秒 / 1000.0))
	if 显示 <= 0:
		_停八门读秒()
		return
	if 显示 == _八门读秒显示:
		_更新八门读秒位置()
		return
	_八门读秒显示 = 显示
	if _八门读秒节点 == null:
		_八门读秒节点 = Node2D.new()
		_八门读秒节点.name = "八门读秒"
		_八门读秒节点.z_index = 2000
		add_child(_八门读秒节点)
	for 旧 in _八门读秒节点.get_children():
		_八门读秒节点.remove_child(旧)
		旧.queue_free()
	var 总宽 := 0.0
	var 串高 := 0.0
	var 片们: Array[TextureRect] = []
	for 字符 in str(显示):
		var 纹 := load(八门读秒纹理 % (int(字符) + 1)) as Texture2D
		if 纹 == null:
			continue
		var 片 := TextureRect.new()
		片.texture = 纹
		片.size = 纹.get_size()
		片.position = Vector2(总宽, 0.0)
		总宽 += 纹.get_width()
		串高 = maxf(串高, 纹.get_height())
		片.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_八门读秒节点.add_child(片)
		片们.append(片)
	# `ColorNumber.draw():97`：`container.x = -container.width / 2`（整串居中）
	for 片 in 片们:
		片.position.x -= 总宽 * 0.5
	_八门串高 = 串高
	_更新八门读秒位置()


func _更新八门读秒位置() -> void:
	if _八门读秒节点 == null:
		return
	var 高 := 0.0
	if player_sprite != null and player_sprite.has_method("当前贴图高度"):
		高 = float(player_sprite.call("当前贴图高度"))
	## 量不到高（帧数据缺失/精灵还没建）⇒ **不动**，同 `:976` 那根箭头的口径：
	## 按 0 算会把数字甩到身上，而原版压根没有"高为 0"这一帧。
	if 高 <= 0.0:
		return
	_八门读秒节点.position = Vector2(0.0, -高 - 八门读秒抬 - 八门读秒距 - _八门串高)


func _停八门读秒() -> void:
	_八门剩余毫秒 = 0.0
	_八门读秒显示 = -1
	_八门串高 = 0.0
	if _八门读秒节点 != null:
		_八门读秒节点.queue_free()
		_八门读秒节点 = null


## 读秒归零（原版 `Character.tickMaiDelay:318-327`）：先播职业音效，再放爆点特效，最后收读秒。
##   ① 音效 `SoundConstants.GetMaiSound(职业)` —— 原版还带一条「穿时装不放」，
##      本工程没有时装字段（同 `脚本/单例/音频管理.gd:257` 那条口径），照原样不拦；
##   ② `addExploreEffect(this, !_maiLastPt)`：**最后一枚大爆**，其余小爆；
##   ③ `addExploreEffect` 末尾还调 `API.world.earthquake()`（30 / 0.3 秒）——
##      震屏闸在调用那头（`Earthquake.go:38-41` 的 `forbidEarthQuake`），复用 `_震屏()`。
func _八门读秒到点() -> void:
	_停八门读秒()
	var 音频 := get_node_or_null("/root/AudioDirector")
	if 音频 != null and 音频.has_method("play_job_effect"):
		音频.call("play_job_effect", "GetMaiSound")
	var 效 := (load("res://脚本/表现/八门爆炸特效.gd") as GDScript).call("造", not _八门最后一点) as Node2D
	效.name = "八门爆炸"
	效.z_index = 2000
	# 原版挂到世界特效层（`EffectHandler`）而不是人物身上：人物走动不拖着爆点走。
	var 层 := get_parent()
	if 层 != null:
		层.add_child(效)
		效.global_position = global_position
	else:
		add_child(效)
	_震屏()


## 跟帧：站立/跳跃/爬绳的贴图高不一样，只在挂上那一刻算一次会在换动作时错位。
func _process(delta: float) -> void:
	_更新头顶挂件位置()
	if _八门剩余毫秒 > 0.0:
		_八门剩余毫秒 -= delta * 1000.0
		if _八门剩余毫秒 > 0.0:
			_刷新八门读秒()
		else:
			_八门读秒到点()
	elif _八门读秒节点 != null:
		_停八门读秒()

func _physics_process(delta):
	## **第一件事**：把上一帧为"画"而抬起来的那几像素收回来。
	## 下面每一处读 `position.y` 的（层号、落脚点吸附、发对面的位置帧）都要看到基准值，
	## 否则浮动会顺着 `z_index = 角色z(fh, position.y)` 变成层序抖动（10-14 那条"飘"的根因）。
	_收回双修浮动()
	if footholds == null:
		return
	## 路线走完 ⇒ 原版 `removeChild(PathFindingTip)`（`KeyController.as:446-449`）。
	## 不逐处追收尾：拿「还在自动」且「已经没有路线」当停止条件，路线以任何方式结束都落到这一条。
	if 自动寻路中 and not click_move_active:
		_设自动寻路态(false)
	_movement_sync_elapsed += delta
	# 原版把角色放进 `ALayer[所站脚点的层号]`，层内排在该层全部地形之后、角色之间按
	# foothodY 排。所以 z 必须由**脚点**决定，不能只用 y —— 只用 y 会让角色落进层 0 的
	# 带里，被它脚下那一层（比如木叶村的主街在层 2）的瓦片整个盖住。
	## ★ `+1` = **自己压住别人**（用户 2026-10-17 令："两个角色叠在一起应该是显示自己为最上层"）。
	## 远程那一头在 `地图实体._远程角色层次` 里拿的是**不带 +1 的基准值** ⇒ 同一格重叠时严格我在上。
	## 原版没有这条（`grep sortChildren|zIndex` 在 2.2.3 全量 AS3 里零命中，角色层就是 addChild 顺序
	## ⇒ 后进图的压住先进图的，自己那具并不特殊）—— 这是一条**有意偏离**，理由：单机端永远只有
	## 自己这一具是要操作的，被 NPC/别人盖住 = 看不见自己动。
	z_index = footholds.角色z(current_fh_id, position.y) + 1
	portal_cooldown = maxf(0.0, portal_cooldown - delta)
	ladder_cooldown = maxf(0.0, ladder_cooldown - delta)
	_接近冷却 = maxf(0.0, _接近冷却 - delta)

	var dir := 0
	var 键可用 := not _键盘被文本占用()
	if 禁寻路:
		## 迷路森林那一族：**没有自由移动**（原版 `tickInJingSuMaps():67-85`）——
		## 左右键只是「按一下等于没按」，人永远朝当前朝向自己走，撞墙才掉头。
		## 用户报的"转向键失效"就是这一幕：不是坏了，是原版本来就不给转向。
		dir = _禁寻路方向()
		自动接近目标 = null
	else:
		var manual_dir := 0
		if 键可用 and Input.is_action_pressed("ui_left"): manual_dir -= 1
		if 键可用 and Input.is_action_pressed("ui_right"): manual_dir += 1
		if manual_dir != 0:
			# 玩家自己动了 → **取消这次自动接近**（选中目标保留，见 `自动接近目标` 的说明）
			自动接近目标 = null
			dir = manual_dir
			cancel_auto_path()
		elif 自动接近目标 != null and not is_instance_valid(自动接近目标):
			自动接近目标 = null
		elif 自动接近目标 != null and bool(自动接近目标.get("alive")):
			# 「过去打它」这条命令在跑：够得着就出招、否则维持一条**真寻路**路线。
			# 路线本身由下面那套 `click_move_*` 执行（`_冲选中目标` 内部会调 `_走点击路线`）。
			dir = _冲选中目标(自动接近目标)
		else:
			dir = _走点击路线()
	if 出手中 and _攻击动作结束了吗():
		出手中 = false
	if 出手中:
		dir = 0    # 出招定身：原版攻击动作期间水平速度清零（KeyController.as:1405-1411）
	var up_pressed := 键可用 and Input.is_action_pressed("ui_up")
	var down_pressed := 键可用 and Input.is_action_pressed("ui_down")
	var jump_down := 键可用 and Input.is_action_pressed("jump")
	var jump_pressed := jump_down and not jump_was_pressed
	jump_was_pressed = jump_down
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var attack_down := 键可用 and Input.is_action_pressed("basic_attack")
	if 键可用 and Input.is_action_just_pressed("switch_target"):
		# TAB：只换选中目标（原版 `switchTarget` 也只设 `viewTarget`，不直接出手）
		切换目标()
	var attack_pressed := attack_down and not attack_was_pressed
	attack_was_pressed = attack_down
	if is_practising and (dir != 0 or up_pressed or down_pressed or jump_pressed or attack_pressed):
		## ⚠ 光把**本地**的坐着状态清掉不够：服务端还当他在打坐 ⇒ 双修不中断、单人奖励继续发、
		## 对面那具一直挂在双修坐上。原版这条是 `HealHandler.tick():171-175` ——
		## 动作一离开 SIT0/SIT1 的**那一帧就 `requestHealStop()` 上行**。
		## 10-17 用户实机报的"一方走了双修就该中断"缺的就是这一发上行（本地画面早就站起来了，
		## 所以从屏幕上完全看不出来少了什么）。
		_stop_practise()
		_上行停坐()
	if attack_pressed:
		perform_basic_attack()
	## **无条件调**：原版 `World.tick():651` 那句 `guajiHandler.tick(param1)` 不带任何开关，
	## "要不要干活"是 `tick` 自己在 `:660 if(!this._isStart) return;` 里判的 —— 所以**嗑药那两段
	## （`:610-:658`）排在早退之前**、没在挂也照样按配置里的血/蓝线吃药，而拾取队列那条
	## 独立 ENTER_FRAME（`:1103-1115`）更是停挂机后仍会把已经点名的掉落排空。
	## 上一版这里用 `auto_combat_active` 挡在外面 ⇒ 一关挂机连"把最后两枚捡完"都没了。
	_托管.拍(delta * 1000.0)
	var below_platform: Dictionary = footholds.find_platform_below(position.x, position.y, current_fh_id) if on_ground else {}
	var drop_through: bool = on_ground and down_pressed and jump_pressed and not climbing and not below_platform.is_empty() and float(below_platform.y) != INF
	if drop_through:
		cancel_auto_path()
		_穿台下落()

	if not climbing and up_pressed and portal_cooldown <= 0.0 and try_enter_portal():
		portal_cooldown = PORTAL_COOLDOWN
		return

	# ⚠️ 两个查询**不能合成一个**：
	#   `ladder`  —— 宽松口径，用于"已经在爬"时的续爬与脱手判定。收紧它会让爬到顶前
	#                就判定绳子没了 → 直接脱手下落（我上一版就这么把上爬弄坏的）。
	#   `抓取`    —— 严格口径（按上要求上方还有绳、按下要求绳子够到脚底），
	#                **只用于"要不要吸附上去"这一步**，避免站在平台/地面上按方向键
	#                被误判成上了梯子、播一段爬梯动作。
	var 意图 := "down" if (down_pressed and not up_pressed) else ("up" if up_pressed else "")
	var ladder = get_ladder_at(position.x, position.y)
	var 抓取 := get_ladder_at(position.x, position.y, 意图)
	if ladder_cooldown > 0.0:
		ladder = {}
		抓取 = {}
	if not climbing and (up_pressed or down_pressed) and not 抓取.is_empty():
		ladder = 抓取
		cancel_auto_path()
		climbing = true
		自动爬梯中 = false			# 自己按上/上来的 ⇒ 松手也不许把人甩下去（原版停在绳上）
		on_ground = false
		velocity = Vector2.ZERO
		爬顶跳中 = false
		position.x = float(ladder.x)
		if down_pressed:
			# Move the feet just below the top one-way foothold. Otherwise the
			# landing pass immediately snaps the player back onto that platform.
			position.y = maxf(position.y, float(ladder.y1) + 4.0)
			current_fh_id = ""
	if climbing:
		var bottom_reach := float(ladder.get("bottom_reach", 4.0))
		if ladder.is_empty() or position.y < ladder.y1 - 4.0 or position.y > ladder.y2 + bottom_reach:
			var 到顶: bool = not ladder.is_empty() and position.y < float(ladder.y1) - 4.0
			climbing = false
			自动爬梯中 = false
			if 到顶:
				# 上爬到顶：贴到顶上那层脚点，并进入冷却，避免"脱开→又吸附"横跳
				position.y = float(ladder.y1)
				ladder_cooldown = 0.35
				velocity.y = -跳落.爬顶跳离速(jump_speed)		# 普通起跳 + 基础爬跳（见常量注释）
			## 原版 `KeyController.tick():1441-1449`：ROPE/LADDER 只要 `!grounded` 就翻成 JUMP，
			## **速度原样保留** —— 爬梯/爬绳时 `x` 一直是 0 ⇒ 爬到顶是原地直上；JUMP 档左右键
			## 只改朝向（`:1375-1395`），落地才 `setVelocity({x:0})` 回 STAND（`:1396-1408`）。
			## ⚠ 竖直那一半**有意偏离**：上面那行用的是 `跳跃常数.爬顶跳离速(jump_speed)`
			## （普通起跳 + 基础爬跳），不继承 `climb_speed`（见那段说明）。
			## 用户 2026-10-31 口径（**有意偏离 `:1375-1395`**）：爬顶这一跳的左右移动要留着，
			## 但**带惯性**（不是逐帧直写走速）—— 所以这里进 `爬顶跳中`，横向速度由下面
			## `move_toward` 那条支路按斜率逼近期望值；普通跳跃不受影响。
			跳起中 = true
			爬顶跳中 = true
		elif jump_pressed and dir != 0:
			climbing = false
			自动爬梯中 = false
			velocity.y = -jump_speed * 0.5
			## 原版 `KeyController.tick():1414-1440`：从绳/梯上跳离时，水平速度**当场定成**
			## 朝向×走路速度（之后 JUMP 档只改朝向）。§3.320 锁掉空中控制后，这里必须自己给，
			## 否则「跳+方向」离开梯子会变成原地直上。
			velocity.x = float(dir) * move_speed
			跳起中 = true
			爬顶跳中 = false		# 这一支是"当场给速度后锁住"，不是爬顶那一跳，别继承惯性控制

	var on_ladder := climbing
	# 原版 `AbstractPhysicObject.tikcLayer`：爬梯/爬绳时角色进的是
	# `getALayer(currLadderRope.page)` —— **绳子自己那一层**，比地形层高，
	# 所以人不会被梯子/绳子的美术盖住。上面那句按脚点算的在这里被覆盖掉。
	if on_ladder and not ladder.is_empty():
		z_index = RenderProfile.角色z(int(ladder.get("page", 0)), 200) + 1
	if on_ground:
		跳起中 = false
		爬顶跳中 = false
	## 原版 `KeyController.tick():1275-1297` 只在 STAND/WALK/SIT0 三档写水平速度；
	## JUMP 那一档（`:1375-1395`）只改朝向 ⇒ 起跳后直到落地没有空中控制。
	## 自动寻路是**例外**：`_走点击路线()` 的 `jump` 边靠空中改 `dir` 对准落点
	## （`landing_delta`，`:1379-1384`），那是本工程自己的路线执行器，不是玩家手动操作。
	## 爬顶那一跳也是例外（用户口径）：保留左右移动，但**带惯性** —— 目标 `dir × 走速`，
	## 斜率 `走速 / 爬顶跳加速时长`（≈0.15 秒到满速），松手同样按这个斜率回 0。
	if on_ladder:
		velocity.x = 0.0
	elif 爬顶跳中 and not click_move_active:
		var 爬顶步进: float = absf(move_speed) / 爬顶跳加速时长 * delta
		velocity.x = move_toward(velocity.x, float(dir) * move_speed, 爬顶步进)
	elif 跳起中 and not click_move_active:
		pass
	elif 禁寻路 and not on_ground:
		## 禁寻路图里空中的横向速度是**起跳/踩箭头那一下**给的（原版 `setVelocity` 之后没人再改
		## `_velocity.x`，`applyVelocity` 逐帧照搬）⇒ 这一帧不许用 `dir * move_speed` 覆盖它，
		## 否则火箭把人往左上射出去、下一帧就被抹成平地走路速度（表现就是"飞不起来"）。
		pass
	else:
		velocity.x = dir * move_speed
	if dir != 0 and player_sprite != null:
		facing = dir
		# 角色是"美术朝右"那一套（CharacterSprite.as:1718-1732），和怪物/NPC 相反；
		# 两套口径都在 原始动画精灵.set_direction 里收口。
		if player_sprite.has_method("set_direction"):
			player_sprite.call("set_direction", facing)
		else:
			player_sprite.set("flip_h", facing < 0)
	if player_sprite != null:
		if 出手中:
			pass    # 出招动作播完之前不覆盖（原版 movementAction==ATTACK 时控制器整段跳过）
		elif on_ladder:
			# Original AbstractPhysicObject: isLadder = ladderRope.l == 1.
			# This map's climbables are ropes (l != 1), so play the "rope" action.
			var 爬动作 := "ladder" if ladder.get("is_ladder", false) else "rope"
			_同步动作 = 动作爬梯 if 爬动作 == "ladder" else 动作爬绳
			# 爬梯/爬绳**不动**时不该一直循环播攀爬动画 —— 冻在第 0 帧。
			if absf(velocity.y) < 0.01 and dir == 0:
				player_sprite.hold_first_frame(爬动作)
			else:
				player_sprite.play(爬动作)
		elif not on_ground:
			_同步动作 = 动作跳跃
			player_sprite.play("jump")
		elif dir != 0:
			_同步动作 = 动作行走
			player_sprite.play("walk")
		elif is_practising:
			## 双修那一档要**每帧重判**：`1288:1:2:…` 那一条常常在坐下之后才到，
			## 原版是 `healStateChange` 里当场 `setMovementAction(SIT1)`，这里靠这一支跟上。
			_同步动作 = 动作双修 if _双修已成() else 动作打坐
			_播放坐姿()
		else:
			_同步动作 = 动作站立
			player_sprite.play("stand")

	if on_ladder:
		if click_move_active and click_climb_direction != 0.0 and not up_pressed and not down_pressed:
			velocity.y = click_climb_direction * climb_speed
		else:
			velocity.y = (float(down_pressed) - float(up_pressed)) * climb_speed
			## ⚠ 用户 2026-10-19 实机报"角色容易卡在梯子上不动"：自动路线把人带上绳之后被
			## `cancel_auto_path()` 掐掉（停挂机 / 换目标 / 直线走 那几路都会走到它），此刻
			## 没人按键、`click_climb_direction` 又被清成 0 ⇒ 竖直速度恒 0、`climbing` 还真
			## ⇒ **人就钉在绳上**（量具 `开发工具/量爬梯卡住.gd` 乙：这张图 5 把梯子一把不落，
			## 第 30 帧取消路线之后连续 45 帧位移 0.0）。只有"自动带上来的"才自动松手，
			## 玩家自己按住上/下再松开仍然停在绳上（那是原版行为，别一起改掉）。
			if 自动爬梯中 and not click_move_active and not up_pressed and not down_pressed:
				climbing = false
				自动爬梯中 = false
				velocity.y = 0.0
		if dir == 0:
			position.x = ladder.x
	else:
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	var prev_y := position.y
	var prev_x := position.x
	var was_on_ground := on_ground
	var previous_fh_id := current_fh_id
	position += velocity * delta
	if bounds.has_area():
		position.x = clamp(position.x, bounds.position.x, bounds.end.x)
	## 原版 `AbstractPhysicObject.checkFoothold():286-440` 的两条**墙**判据，本工程一直没搬：
	##   ① 离地（`currFoothold == null`）时把这一帧的位移向量和**竖直脚点**求交，撞上就贴到
	##      交点旁 1 像素、清水平速度（下落中保留竖直速度）；
	##   ② 站在脚点端头、链上的下一段是"墙"（`next` 的 `y2 < y1` / `prev` 的 `y1 < y2`）
	##      就停在端头不许迈过去。
	## 命运的抉择（403000000）1~8 号竖井之间的隔断就是这两类竖直脚点；缺了它们，走出平台边
	## 那一帧会直接落到**隔壁**平台面上（`find_foothold` 是全表扫的），也就是用户
	## 2026-10-28 报的「通道之间的墙壁可以通过」。
	if on_ladder or climbing:
		pass
	elif was_on_ground:
		_挡在脚点端头的墙前(previous_fh_id, prev_x)
	else:
		_空中撞墙(prev_x, prev_y)
	## 原版 `AbstractPhysicObject.checkAbyss():722-736`（`Character.as:2565-2571` 每帧在
	## `applyVelocity` 之后调）：x 夹回 `[minX+2, maxX-2]` 并清水平速度；y 夹到**这一列最低地面**
	## （`getLowestYByX`，见 `地表.最低地面y()`）。⇒ 原版角色**永远掉不到地平线以下**。
	## 本工程以前只搬了"掉出底边 +300 才回出生点"这一条，中间那一段没有任何拦截 ——
	## 就是用户 2026-10-30 报的「跳跃移动 / 下+跳跃穿台，会落到地平线以下」。
	## 夹完 y 之后下面那条落脚判定会当帧接住人（`find_foothold` 的 `gy >= 前y-1` 仍然成立）。
	if bounds.has_area():
		var 夹x := clampf(position.x, bounds.position.x + 2.0, bounds.end.x - 2.0)
		if not is_equal_approx(夹x, position.x):
			position.x = 夹x
			velocity.x = 0.0
		var 最低地面: float = footholds.call("最低地面y", position.x)
		if 最低地面 != INF and position.y > 最低地面:
			position.y = 最低地面
	## ⚠ 发包点**不能留在这里**：下面 1103~1126 才是落脚点吸附，而 `position += velocity * delta`
	## 这一帧已经按末速（最大 `max_fall_speed` 670 像素/秒 ⇒ 一帧 11 像素）**穿过**落脚点了。
	## 在穿过点发出去的包，收端还要再拿同一个末速往下积分（0.1 秒 = 67 像素），下一包（吸附后的
	## 地面 y）又把他拽回来 ⇒ 旁观者看到的就是用户 10-15 报的那句"跳跃看起来一抖一抖"。
	## 挪到本帧物理全部算完之后再发（见函数末尾那条）。

	var followed_ground := false
	if was_on_ground and not on_ladder:
		var connected = footholds.find_connected_ground(position.x, previous_fh_id)
		if connected.y != INF:
			position.y = connected.y
			velocity.y = 0.0
			on_ground = true
			current_fh_id = connected.id
			followed_ground = true
	if not followed_ground:
		## 原版 `checkFoothold():373-389`：离地时先拿**这一帧的位移向量**与所有非竖直脚点扫掠求交，
		## 相交就落到交点。`find_foothold` 那种"按落点这一列取面 + `gy >= 前y-1`"的 1 像素容差，
		## 会在斜坡一帧抬升超过 1px 时把已经穿过的面判掉 ⇒ 人从斜坡里穿下去落到下层平台
		## （用户 2026-11-02 报的「移动跳跃时跳到当前平台下面，一般有斜坡的地方」；基础走速
		## 175 下全图实测 23 个点会中，例：100010000 段15 x=778 向左跳，旧语义落到 y=767）。
		var 扫 := {}
		var can_land: bool = not on_ladder or velocity.y > 0.0
		## ⚠ 只在**离地**时扫：原版这段就在 `checkFoothold():373` 的 `currFoothold == null` 分支里。
		## 站在平台上也被扫时，起脚点正好压在脚下那条面上 ⇒ 交点 t=0、落点=起点，人被每帧拽回
		## 边缘、永远走不出去（用户 2026-11-02 报的「小平台移动到尽头不会下落，必须跳跃」）。
		if not was_on_ground and can_land and velocity.y >= 0.0:
			扫 = footholds.call("扫掠落点", Vector2(prev_x, prev_y),
					Vector2(prev_x + velocity.x * delta, prev_y + velocity.y * delta))
		if not 扫.is_empty():
			position = Vector2(float(扫.x), float(扫.y))
			velocity.y = 0.0
			## 原版 `KeyController.tick():1396-1408`：JUMP 落地 ⇒ STAND 且 `setVelocity({"x":0})`。
			if 跳起中:
				velocity.x = 0.0
				跳起中 = false
				爬顶跳中 = false
			on_ground = true
			current_fh_id = String(扫.id)
			if on_ladder:
				climbing = false
				自动爬梯中 = false
		else:
			var res = footholds.find_foothold(position.x, prev_y, previous_fh_id)
			var ground = res.y
			# Entering from the top already nudges the feet below that platform, so
			# every platform crossed while descending is a valid landing surface.
			if can_land and velocity.y >= 0.0 and ground != INF and position.y >= ground:
				position.y = ground
				velocity.y = 0.0
				## 原版 `KeyController.tick():1396-1408`：JUMP 落地 ⇒ STAND 且 `setVelocity({"x":0})`。
				if 跳起中:
					velocity.x = 0.0
					跳起中 = false
					爬顶跳中 = false
				on_ground = true
				current_fh_id = res.id
				if on_ladder:
					climbing = false
					自动爬梯中 = false
			else:
				on_ground = false
				current_fh_id = ""

	if click_move_active and on_ground:
		if click_replan_pending:
			replan_auto_path()
		elif auto_action_index < auto_actions.size():
			var landed_action: Dictionary = auto_actions[auto_action_index]
			if landed_action.type in ["climb", "drop", "jump"] and auto_pathfinder.get_component(current_fh_id) == int(landed_action.target_component):
				advance_auto_action()
			elif landed_action.type in ["climb", "drop", "jump"]:
				replan_auto_path()

	if on_ground and jump_pressed and not on_ladder and not down_pressed:
		velocity.y = -jump_speed
		## 原版 `jumpUpTarget():626`（站着起跳）就是 `x:0`；走着起跳两种图口径不同，
		## 下一帧起 `跳起中` 挡住逐帧覆盖，速度就停在起跳这一下（见 `跳起中` 的说明）。
		跳起中 = true
		爬顶跳中 = false
		if 禁寻路:
			## 走着起跳 = 原版 `jumpRightTarget()/jumpLeftTarget()`（`KeyController.as:488-497/1623-1632`）：
			## 竖向 `-jumpSpeed` 之外还得把水平速度**定成朝向 × 走路速度**；
			## 站着起跳（`jumpUpTarget():626-635`）才是 `x = 0`。禁寻路图里人一直在走 ⇒ 走这一支。
			velocity.x = float(facing) * move_speed
		on_ground = false

	if bounds.has_area() and position.y > bounds.end.y + 300.0:
		position = spawn_pos
		velocity = Vector2(0, 5)
		on_ground = false
		跳起中 = false
		爬顶跳中 = false
	## 原版 `HealHandler.tick():171-175` 那一支：
	## `nowInHeal && serverHealState != 0 && movementAction != SIT0 && != SIT1` ⇒ **当场 `requestHealStop()`**。
	## 人话：**打坐中只要我自己动了一步（走 / 跳 / 爬），这一局打坐立刻作废并告诉服务端**，
	## 双修跟着中断（对面那一具怎么处理在服务端 `_stop_healing` 里，10-17 一并改）。
	## 10-17 用户实机报的"一方走了双修就该中断"就是这一条：以前只有画面在走，
	## 服务端还当他坐着 ⇒ 奖励继续发、对面那具还挂在双修上。
	if _backend != null and is_practising:
		var 坐态 := int((_backend.get("authoritative_heal") as Dictionary).get("state", 0))
		## 每帧都记一行"当时是什么状态"：10-17 在线门量到"我走了但服务端还是双修态"，
		## 光看结果分不出是**这一支没触发**还是**触发了但上行没生效** ⇒ 两条各自要能红。
		打坐打断诊断 = "坐着 服务端态=%d 这一帧动作=%d" % [坐态, _同步动作]
		if 坐态 != 0 and _同步动作 != 动作打坐 and _同步动作 != 动作双修:
			打坐打断诊断 += " ⇒ 当场停坐并上行 86:2"
			_stop_practise()
			_上行停坐()
	## 本帧的 `position / velocity / on_ground` **全部算完**（落脚点吸附、起跳冲量、掉出界回出生点
	## 都在这行之前）才采样发出去 —— 对面拿到的才是"他这一帧真正在哪儿、带着什么速度"。
	## 原版 `Character.as:2520-2523` 每帧调的 `Sampler.tick()` 同样排在物理之后。
	_sync_backend_movement()
	## **最后一件事**才是"为画而抬起来"：双修那 8 像素正弦（原版 `tickHealDouble:725-759`，
	## 口径写在上面那组常量旁边）。放在发帧之后 ⇒ 对面收到的永远是基准 y，不是浮动的量。
	_推进双修浮动(delta)

## 站在脚点端头、链上的下一段是竖直"墙"时停在端头（`checkFoothold:404-440` 的 `else if` 两支）。
## 原版只在**朝端头走**（`(x2-x1)*vx > 0` 且离端头不超过一个步长）时才判。
func _挡在脚点端头的墙前(脚点id: String, 前x: float) -> void:
	if velocity.x == 0.0 or 脚点id == "":
		return
	var 段: Dictionary = footholds.id_map.get(脚点id, {})
	if 段.is_empty():
		return
	var 朝右 := velocity.x > 0.0
	var 端x := float(段.x2 if 朝右 else 段.x1)
	if 朝右:
		if 前x > 端x or position.x < 端x:
			return
	else:
		if 前x < 端x or position.x > 端x:
			return
	var 下段: Dictionary = footholds.id_map.get(str(int(段.next if 朝右 else 段.prev)), {})
	if 下段.is_empty() or float(下段.x1) != float(下段.x2):
		return
	# 原版口径：`next` 方向的"墙"是 y2 < y1，`prev` 方向的"墙"是 y1 < y2。
	var 是墙 := float(下段.y2) < float(下段.y1) if 朝右 else float(下段.y1) < float(下段.y2)
	if not 是墙:
		return
	position.x = 端x
	## 原版 `checkFoothold:322-326` 撞上端头那张"墙"就置 `rightBlock/leftBlock`；
	## 禁寻路图的掉头判据读的就是它（`tickInJingSuMaps():67-74`）。
	if 禁寻路:
		if 朝右:
			右被挡 = true
		else:
			左被挡 = true

## 空中横移撞竖直脚点：贴到交点内侧 1 像素、水平速度清零（`checkFoothold:297-371`）。
## 只扫**这一帧真的跨过**的那条竖线，所以站在平台上不动不会被脚下的墙误判。
## ⚠ 竖墙按原版算**单向**（只挡朝向实体那一侧的位移），见循环里 `实体在右` 那段。
##
## ⚠ 与原版的两处口径差（都是"检查跑在移动之后"逼出来的）：
##   · 原版 `checkInit():244-250` 先拿**这一帧将要走**的位移向量求交、再 `applyVelocity`，
##     所以它把 y 也贴到交点上；我们这一帧的位移已经加过了，交点 y 一定在起点与终点**之间**
##     ⇒ 上升中照抄会把这一帧的上升量吃掉（贴着墙往上跳会越跳越慢）。⇒ **只夹 x**；
##     下落时（`vy > 0`）才把 y 贴到交点，和原版"沿墙滑下去"一致。
##   · 原版只在 `vy > 0` 时清 `vx`（`:328-333`）；上升中撞墙它保留水平速度，只是每帧被夹回来。
##     ⇒ 我们同样只在 `vy > 0` 时清，别把"贴墙起跳"变成"一碰墙就再也横移不了"。
func _空中撞墙(前x: float, 前y: float) -> void:
	if velocity.x == 0.0:
		return
	var 起 := Vector2(前x, 前y)
	var 终 := position
	var 步长x := 终.x - 起.x
	if absf(步长x) < 0.001:
		return
	for 段 in footholds.segments:
		if float(段.x1) != float(段.x2):
			continue
		## 竖直脚点是**单向墙**：原版 `findIntersection()` 里那道 `dotProduct(this.myVector1,_loc6_) < 0`
		## 拿的是脚点法线 (y2-y1, 0)，只有"实体在**来向**的对面"才认交点 ——
		##   · `y2 < y1`（数据指向上）⇒ 实体在右，只挡**向右**的位移；
		##   · `y1 < y2`（数据指向下）⇒ 实体在左，只挡**向左**的位移。
		## 不看方向一律挡会多挡一半：端面那十几到几十像素的 y 带里，脚点正落在里面，
		## 于是从平台底下跳起、或从平台边**跳出去**时人被贴住端面不动 —— 用户 2026-10-31 报的
		## 「移动起跳会被阻碍，从平台下方起跳碰到平台会挡着」。174 张图全扫：942 个空中卡点里
		## 309 个是这种反向假挡，改后 0 个（见 `开发记录（本地）` §3.324）。
		var 实体在右 := float(段.y2) < float(段.y1)
		if 实体在右 != (步长x > 0.0):
			continue
		var 墙x := float(段.x1)
		var t := (墙x - 起.x) / 步长x
		if t < 0.0 or t > 1.0:
			continue
		var 交y := 起.y + (终.y - 起.y) * t
		if 交y < minf(float(段.y1), float(段.y2)) - 1.0 or 交y > maxf(float(段.y1), float(段.y2)):
			continue
		var 贴x := 墙x + (-1.0 if 步长x > 0.0 else 1.0)
		if 禁寻路:
			if 步长x > 0.0:
				右被挡 = true
			else:
				左被挡 = true
		if velocity.y > 0.0:
			position = Vector2(贴x, 交y)
			velocity.x = 0.0
		else:
			position.x = 贴x
		return

func _sync_backend_movement() -> void:
	if _backend == null or not bool(_backend.get("in_game")):
		return
	## ⚠ **动作一翻（起步 / 停下 / 起跳 / 上梯 / 打坐）立刻发，不等那 0.1 秒** ——
	## 原版就是这一条：`Sampler.tick()` 只要 朝向/动作/移动动作/位置/速度 里任何一格变脏，
	## 马上 `sampleMovement(true)` 当场发出去（`Sampler.as:83-95` + `Character.as:2520-2523`）。
	## 停在原地慢一拍才发，对面就会看着那个人**多走一个采样周期再倒回来**
	## （延迟尺子上那个"最大 46 毫秒"就是这么来的）。
	var 动作翻了 := _同步动作 != _上次同步动作
	## ⚠ **水平速度一变也当场发**（10-15 照原版 `Sampler.tick()` 的脏标记补的）：
	## `sampleMovement` 那条 100 毫秒节流分支**全量 AS3 里一个调用者都没有** —— 四处调用点
	## （`Sampler.as:93`、`Character.as:2663`、`MonsterSampler.as:40`、`PetSampler.as:66`）
	## 一律传 `true` ⇒ 原版实际是"**变脏即发**"，不是每 0.1 秒一发。上一版只看"动作翻没翻"，
	## 于是**原地换向 / 变速** 要等满一个节流周期才传出去（最多晚 100 毫秒；400 像素/秒时
	## 对面看着他多跑 40 像素再拐 —— 用户 10-15"总体还是能感觉到一丢丢延迟"就是这一笔）。
	## ⚠ 竖直速度**只在爬梯/爬绳时算脏**：平地走时 `velocity.y` 是重力每帧刷出来、又被落脚点
	## 吸附清零的小值（0 ↔ 33），跟着判就退化成每帧发包；跳跃时原版还**专门排除**了
	## "只有 VELOCITY 脏"那一种（`Sampler.as:87-90`）—— 抛物线是留给收端自己积分的。
	var 看竖直 := _同步动作 == 动作爬梯 or _同步动作 == 动作爬绳
	var 速度翻了 := absf(velocity.x - _上次同步速度.x) > 1.0 \
			or (看竖直 and absf(velocity.y - _上次同步速度.y) > 1.0)
	## ★ **朝向翻了也算脏**（原版 `Sampler.tick()` 那一串脏标记里就有 `DIRECTION`，`Sampler.as:83-95`）。
	## 少了这一条，"原地转身"（双修摆位那一下、锁定目标转身）永远传不出去 —— 收端只能停在
	## 上一次移动时的朝向。10-17 用户实机看到的双修"他该朝我，结果背对我"就是这一笔。
	var 朝向翻了 := facing != _上次同步朝向
	## 停下来那一拍位置已经不再变了，但**动作从"走"翻回"站"必须发出去** ——
	## 只按位移发的话，对面永远收不到"停"这一帧，会看着我原地踏步。
	var 位置没变 := _last_synced_position != Vector2.INF \
			and position.distance_squared_to(_last_synced_position) < 1.0
	if not 跳落.该发位移包(动作翻了 or 朝向翻了, 速度翻了, 位置没变,
			_movement_sync_elapsed, MOVEMENT_SYNC_INTERVAL):
		return
	_movement_sync_elapsed = 0.0
	_last_synced_position = position
	_上次同步动作 = _同步动作
	_上次同步速度 = velocity
	_上次同步朝向 = facing
	_backend.call("send_movement", position, _同步动作, velocity, facing)

func _on_player_defeated() -> void:
	cancel_auto_path()
	position = spawn_pos
	velocity = Vector2(0.0, 5.0)
	on_ground = false
	跳起中 = false
	爬顶跳中 = false

func try_enter_portal() -> bool:
	if portal_root == null or not portal_root.has_method("get_portal_at"):
		return false
	var portal: Dictionary = portal_root.get_portal_at(position)
	if portal.is_empty():
		return false
	return portal_root.enter_portal(portal)

func get_ladder_at(x: float, y: float, 意图 := "") -> Dictionary:
	if ladder_root == null:
		return {}
	if ladder_root.has_method("get_ladder"):
		return ladder_root.get_ladder(x, y, 意图)
	return {}

## 身体用哪一套 = **服务端下发的 `face`**（原版只有这一个入口，见 `脚本/角色/角色造型.gd`）。
## 以前这里写死 `00000001` ⇒ 服务端算得再对也白算、女角色进游戏仍是金发男（#183）。
## 远程玩家那头本来就在用 face（`地图实体.gd:270`），这次是把本地玩家接上同一条口径。
func setup_player_sprite():
	var 身: Dictionary = GameSession.自身外观()
	var 号 := 角色造型.造型号(int(身["face"]), int(身["gender"]))
	var original_sprite := OriginalSprite.new()
	add_child(original_sprite)
	if original_sprite.configure("character", 号, "stand"):
		player_sprite = original_sprite
		灵器外观 = 灵器外观脚本.new() as Node2D
		if 灵器外观 != null:
			add_child(灵器外观)
			灵器外观.call("绑定", original_sprite)
			灵器外观.call("刷新")
		return
	original_sprite.queue_free()
	var fallback := ColorRect.new()
	fallback.size = Vector2(34, 56)
	fallback.color = Color(0.9, 0.32, 0.32)
	fallback.position = Vector2(-17, -56)
	add_child(fallback)

## 199(UPDATE_CHAR_LOOK) 换装/变身回帧 ⇒ **就地**换身体那套动画。
## 原版 `CharacterHandler.as:339-343`：`characterAnimation.clearEquip()` → `skin/face/lingQiFace/lingQiColor=`
## ⇒ 身体那套从头到尾**只有一个来源**（服务端下发的 face），客户端从不自己挑。
## 查不到新那套 ⇒ **留着原来那具**，不许刷成空白（与左上角头像同一口径：空白比"暂时没换"更难查）。
func 刷新外观() -> void:
	if player_sprite == null or not is_instance_valid(player_sprite) \
			or not player_sprite.has_method("configure"):
		return
	var 身: Dictionary = GameSession.自身外观()
	var 号 := 角色造型.造型号(int(身["face"]), int(身["gender"]))
	if not OriginalSprite.has_animation("character", 号):
		return
	var 取到的动作 = player_sprite.get("action")
	var 动作: String = str(取到的动作) if 取到的动作 != null else ""
	if 动作.is_empty() or not bool(player_sprite.call("configure", "character", 号, 动作)):
		## configure 失败会把内部 actions 清成空 ⇒ 传 "stand" 再试一次，别让身体停在没动画的态
		player_sprite.call("configure", "character", 号, "stand")
	if player_sprite.has_method("set_direction"):
		player_sprite.call("set_direction", facing)
	if 灵器外观 != null and is_instance_valid(灵器外观) and 灵器外观.has_method("刷新"):
		灵器外观.call("刷新")


## 原版 `Character.as:663-676`：**第一句永远是先拆旧的**（不是"阶段变了才换"），阶段 <= 0 就只拆不建。
func 设连斩阶段(阶段: int) -> void:
	if _连斩光环 != null and is_instance_valid(_连斩光环):
		remove_child(_连斩光环)
		_连斩光环.queue_free()
	_连斩光环 = null
	if 阶段 <= 0:
		return
	var 环 = 连斩光环脚本.new() as Node2D
	if 环 == null or not bool(环.call("建", 阶段)):
		return
# 遮挡：原版挂进"当前落脚点那一层"（`layerAura` :915-918）⇒ 与人物同深度桶；本工程挂在人物节点下、
# 压在贴图之后画（脚下一圈扁环该被身体挡一半）。这一条遮挡关系未逐像素对过。
	add_child(环)
	环.z_index = -1
	_连斩光环 = 环
