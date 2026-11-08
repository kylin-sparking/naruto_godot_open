extends Node2D

## 通灵兽在地图上的那一个 actor。原版有两种控制器，**都会生成可见的宠物**：
##   * 出战（`PetPosition.ATTACKING=125`）= `AttackPetController`：跟着主人走 + 自动打怪；
##   * 附身（`PetPosition.ATTACHED=0`）= `FuShenPetController`：跟着主人走，**不出手**。
## 服务端 `fake_flash_server._pet_spawn_payload()` 对两态都发 SHOW(4)/ATTACH(5) 帧，
## 所以两态都得建 actor —— 以前只认 `deployed`，附身那只永远不显示（用户 2026-10-17 报的
## "附身、出战的宠物都没有显示出来"里的另一半）。
##
## 跟随的三条硬要求（用户 2026-10-18 报修，全部钉在 `测试/功能入口回归测试.gd` 里）：
##   1. **不许踏空**：宠物贴的是"主人脚下那条地面"，主人跳/爬梯时地面 y 不变，宠物留在地上；
##   2. **两只不许叠**：取值口径见下面两个常量（用户 10-18 报一次、10-21 复报"还是太近" ⇒ §3.241）；
##   3. **站住就是站住**：动画按"这一帧真的动了没有"切，不按目标差切（否则人物静止时一直播 move）。
##
## 2026-10-24 又报两条（钉在 `测试/宠物跟随重叠回归测试.gd` ⑤′/⑦ 组，§3.257）：
##   4. **和主人同一条水平线**：脚点直接取地面 y，不再减那个没出处的 18 像素；
##   5. **速度跟着主人**：`主人.move_speed × 跟随比例`，主人吃到加速宠物同步变快（比例 0.9 = 用户要的
##      "略微慢一点"，比原版 1.0 等速**有意偏一档**，别当 bug 改回去）。

## 出战 / 附身各自"停在距主人哪里"。**原版没有固定偏移**，只有停止阈值：
##   · `PetController.as:262-299 movePetFold` —— `abs(主人.x - 宠物.x) < _follow_xDis` 就 `stopPet()` 原地站住，
##     否则按 `walkSpeed` 朝主人走（基类默认 `_follow_xDis = 150`，`PetController.as:31`）；
##   · 出战 `AttackPetController.as:24` = **200**、附身 `FuShenPetController.as:9` = **100**。
## ⇒ 主人朝一个方向连走时，两只分别停在"差一点到 200 / 差一点到 100"，**稳态间距 = 200 − 100 = 100**。
## 本工程用固定偏移来落这个稳态（服务端宠物出生 x 没消费 ⇒ 照搬纯阈值模型会让两只都从主人脚下起步、
## 站着不动时永远叠）。一帧立绘宽 45~47 × `scale 1.15` ≈ 54 ⇒ **旧值那 46px 间距必叠**，这就是用户报的重叠。
const 偏移_出战 := -200.0
const 偏移_附身 := -100.0
## 跟随速度 = **主人现在的走路速度 × `跟随比例`**（用户 2026-10-24 报修 1.2「宠物移动速度，随人物
## 速度提升而提升（比人物略微慢一点）」；以前是一条死数 245 ⇒ 主人吃到 `WLK_SPEED` 加速反超 245
## 之后宠物就掉队，而主人 175 时宠物又比人快、看着像贴着人滑）。
## 原版的口径是**宠物与主人严格等速**：`AbstractPhysicObject.as:850`
## `walkSpeed = Physics.WALK_SPEED * walkSpeedFactor`（`Physics.as:8` WALK_SPEED = 125），而
## `WLK_SPEED` 那道加速把**同一个 factor** 同时推给三个对象 —— `player` / `attackPet` /
## `myFuShenPet`（`DataCenter.as:2783-2790`、`SkillHandler.as:967-974` 与 `:1273-1280`、
## `PetHandler.as:488`）。
## ⚠ `0.9` 这一档是**用户明确要求的有意偏离**（原版 1.0 等速），别当 bug 改回去，见 §3.257。
const 跟随比例 := 0.9
## 主人还没吃到服务端属性帧、或挂机的假主人没有 `move_speed` 时，按原版本体常数取。
const 基础跟随 := 125.0
## |Δ| 超过这个距离不再走、直接吸过去。原版是 `PetController.as:19 MAX_RANGE = 500`。
const 瞬移距离 := 420.0
## 竖直方向差超过这个值（换了平台/爬完梯子）就把脚吸到地面，别在空中慢慢飘。
const 竖直吸附 := 120.0
## 一帧走这么多像素才算"在移动"。
const 移动阈值 := 0.6
const 宠物数值 := preload("res://脚本/角色/宠物数值.gd")

## 招式表直接 preload 模块（口径同 `脚本/角色/宠物数值.gd:21`）——不绕会话，
## 免得撞上"实例方法里裸写自动加载名 = 编译时机坑"那一族。
const 数据 = preload("res://脚本/单例/游戏数据.gd")

## 宠物此刻使的那一招 = 原版 `Pet.as:35` 的 `curSkillID`（出厂 101「猛击」）。
## 挂机设置页那枚『通灵兽招式』下拉在**开挂机那一刻**写它
## （`GuajiHandler.set petSkill:1256-1264` → `UI.as:931-934` `myPet.curSkillID = id`）；
## 停挂机**不还原** —— 原版没有那一条，所以这里也不做。
var _当前招式 := 101
var _pet: Dictionary
var _player: Node2D
var _life_root: Node
var _attack_timer := 0.0
var _sprite: Node2D
## "出战" / "附身"，只影响会不会自动打怪、以及跟随偏移。
var _角色 := "出战"
## 宠物脚下那条地面的 y：主人腾空/攀爬时保持不动（这就是"不踏空"的关键）。
var _地面y := 0.0
var _上次位置 := Vector2.INF
## 当前播放的状态名，用来避免每帧重复 play_state（重复调用会把动画重置）。
var _当前动画 := ""
## 出招动作的锁：这段时间内不按位移改动画，否则攻击帧会被 stand 立刻盖掉。
var _动作锁 := 0.0

func configure(pet: Dictionary, player: Node2D, life_root: Node, 角色 := "出战") -> void:
	_pet = pet.duplicate(true)
	_player = player
	_life_root = life_root
	_角色 = 角色
	name = "宠物伙伴_%s" % str(_pet.get("id", "0"))
	_build_visual()
	if _player != null:
		_地面y = _player.global_position.y
		global_position = Vector2(
			_player.global_position.x + _横向偏移() * _朝向(),
			_地面y)
		_上次位置 = global_position
		_当前动画 = "stand"

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_动作锁 = maxf(0.0, _动作锁 - delta)
	var 朝向 := _朝向()
	var 目标x := _player.global_position.x + _横向偏移() * 朝向
	# 地面按**主人脚下那条**采，不按宠物将要站的 目标x 采。出战那只现在停在主人身后 200px
	# （原版阈值，§3.241），stepped 地图上这 200px 里很可能正好跨一级台阶 ⇒ 按 目标x 采会让
	# 宠物顺着台阶滑到下一级去。原版是靠寻路把宠物带上主人的平台
	# （`PetController.as:50-58 needSeachPath` + `:301-311 beginPath`，目标点就是 `主人.x, 主人.y - 10`），
	# 本工程不给宠物做 PathFinder ⇒ 直接把"主人那条地面"当它的地面。
	_地面y = _地面高度(_player.global_position.x, _地面y)
	## 脚点 = 地面那条线，**不减任何偏移**（用户 2026-10-24 报修 1.1「宠物移动和人物不是一个水平线」）。
	## 以前那句 `- 18.0` 没有出处，就是根因：`原始动画精灵.gd:264-266` 已经把每一帧立绘按 flash 的
	## `origin` 抬上去了 ⇒ 节点 y 本身就是脚点，和主人同一个口径（`玩家.gd:800` 的命中盒同样以施法者
	## 脚点为原点）。再减 18 就是把宠物整只提到半空，两条水平线差 18 像素。
	var 目标 := Vector2(目标x, _地面y)
	var 距离 := global_position.distance_to(目标)
	if 距离 > 瞬移距离:
		global_position = 目标
	elif 距离 > 8.0:
		global_position = global_position.move_toward(目标, _跟随速度() * delta)
	# 换平台/爬完梯子：主人已经站到别的高度上，宠物走不过去就直接吸到地面，不要悬空平移。
	if absf(global_position.y - _地面y) > 竖直吸附 or global_position.distance_to(目标) <= 8.0:
		global_position.y = _地面y
	# 主人跳出/跳下平台后，宠物还落在身后那层：主人那列的地面可能突然低一截，直接套上去
	# 会让宠物埋进自己脚下这层地形（用户 2026-11-07 报「人物跳跃在空中移动时」）。
	# 按**自己这一列**的普通地面收脚，两个方向都收：比自己脚下高就抬上去，低就落下来。
	# ⚠ 只抬不降会把宠物挂在旧高度上悬空（用户 2026-11-07 追加：降要降到正常地面，
	#   不是不许降）；也不能用下沉换跟层 —— 落点取自己列，不取主人空中那一列。
	var 自身地 := _自身列地面(global_position.x)
	if is_finite(自身地):
		global_position.y = 自身地
	_update_animation(目标x)
	# 层次必须和**人物用同一把尺子**（用户 2026-11-02 报「人物的显示优先级应该高于宠物，不能被宠物盖住」）。
	# 以前是 `101 + int(global_position.y)` —— **绝对屏幕 y**，而人物走的是
	# `玩家.gd:1600 z_index = footholds.角色z(current_fh_id, position.y) + 1`（层带 512、层内序 0..255）。
	# 两个坐标系一撞，y ≈ 155 以下的宠物就窜到人物上面，越靠地图下方越严重。
	# 现在取**主人脚下那条脚点**的层号/层内序（宠物本来就贴主人那条地面走，口径同 `_地面y`），
	# 且**不带 +1** ⇒ 同格时宠物严格排在人物之后（那个 +1 是用户 2026-10-17 定的偏离，见玩家.gd）。
	var 地表 = _player.get("footholds")
	if 地表 != null and 地表.has_method("角色z"):
		z_index = int(地表.call("角色z", str(_player.get("current_fh_id")), _地面y))
	if _角色 == "出战":
		_try_attack()

## 这一帧真的移动了吗 —— 动画只认位移，不认"和目标的距离差"。
func _update_animation(目标x: float) -> void:
	var 位移 := 0.0
	if _上次位置 != Vector2.INF:
		位移 = global_position.distance_to(_上次位置)
	_上次位置 = global_position
	if _sprite == null or not _sprite.has_method("play_state"):
		return
	if 位移 > 移动阈值 and _sprite.has_method("set_direction"):
		# 和怪物/NPC 同一套口径（美术默认朝左）—— 往左走传 -1，往右传 1。
		_sprite.call("set_direction", -1 if 目标x < global_position.x else 1)
	if _动作锁 > 0.0:
		return
	var 状态 := "move" if 位移 > 移动阈值 else "stand"
	if 状态 == _当前动画:
		return
	_当前动画 = 状态
	_sprite.call("play_state", 状态)

func _朝向() -> int:
	var 值 = _player.get("facing") if _player != null else 1
	return int(值) if 值 != null else 1

func _横向偏移() -> float:
	return 偏移_附身 if _角色 == "附身" else 偏移_出战

## 宠物这一帧走多快 = **主人现在的走路速度 × `跟随比例`**（用户报修 1.2）。
## 主人的 `move_speed` 由 `玩家.gd:197-201 应用移动速度属性()` 按服务端 `player_stats.move_speed`
## 现算（`跳落.走路速度()` 就是原版的 `Physics.WALK_SPEED * walkSpeedFactor`）⇒ 主人吃到加速，
## 宠物同步变快；这一形状与原版同源（原版把同一个 factor 同时推给 player / attackPet / myFuShenPet）。
func _跟随速度() -> float:
	var 主人速度 := 0.0
	if _player != null and is_instance_valid(_player):
		var 值 = _player.get("move_speed")
		if 值 != null:
			主人速度 = float(值)
	return (主人速度 if 主人速度 > 0.0 else 基础跟随) * 跟随比例

## 主人脚下那条地面的 y。**主人腾空（跳/爬梯）时整段冻结，返回上一帧的地面 y** ——
## 这是"宠物踏空而行"的修法：以前直接拿 `_player.global_position.y`，主人一跳宠物就跟着飞。
## 腾空时连 `find_foothold` 都不采：主人空中横移后的那一列可能是下一级（跳崖时正好更低），
## 拿它当宠物地面会把身后还站在上层的宠物埋到地形下面（用户 2026-11-07 报）。
## 只有主人真的往下掉超过 40（跳下/爬下）才把兜底换成主人当前 y，让宠物跟下去。
func _地面高度(目标x: float, 兜底y: float) -> float:
	if _player == null:
		return 兜底y
	var 在地 := bool(_player.get("on_ground"))
	if 在地:
		兜底y = _player.global_position.y
	elif _player.global_position.y > 兜底y + 40.0:
		兜底y = _player.global_position.y
	if not 在地:
		return 兜底y
	var 地表 = _player.get("footholds")
	if 地表 != null and 地表.has_method("find_foothold"):
		var 脚点: Variant = 地表.call("find_foothold", 目标x, 兜底y, str(_player.get("current_fh_id")))
		if 脚点 is Dictionary and not (脚点 as Dictionary).is_empty():
			var 高度 := float((脚点 as Dictionary).get("y", INF))
			if 高度 != INF:
				return 高度
	return 兜底y

## 宠物**自己这一列**的地面（只认主人当前那条脚点及其 prev/next，不跨到无关平台）。
## 取不到就返回 INF —— 调用方只拿它做"抬脚不埋地"的上限，不做主要落点。
func _自身列地面(目标x: float) -> float:
	if _player == null:
		return INF
	var 地表 = _player.get("footholds")
	if 地表 == null or not 地表.has_method("find_connected_ground"):
		return INF
	var 脚点: Variant = 地表.call("find_connected_ground", 目标x, str(_player.get("current_fh_id")))
	if 脚点 is Dictionary and not (脚点 as Dictionary).is_empty():
		return float((脚点 as Dictionary).get("y", INF))
	return INF

func _build_visual() -> void:
	var original := OriginalSprite.new()
	var pet_id := String(_pet.get("id", "")).pad_zeros(8)
	if original.configure("pet", pet_id, "stand"):
		_sprite = original
	else:
		var fallback := Sprite2D.new()
		var icon_path := String(_pet.get("icon", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			fallback.texture = load(icon_path) as Texture2D
		fallback.position = Vector2(0.0, -26.0)
		_sprite = fallback
	_sprite.scale = Vector2(1.15, 1.15)
	add_child(_sprite)
	# 真值 `Pet.as:showName:284-327` + `RoleNamePane.as:41-60`：
	#   · 文字 = 宠物显示名（非尾兽带"(品质)"）+ `[出战]` / `[附身]`；
	#   · 字号 **12**（`RoleNamePane(param1, **param2=12**)`，本工程以前写 11 ⇒ 点阵发灰）；
	#   · 颜色按品质（`PetAptitude.getApitudeColor`，尾兽恒黄）；
	#   · 黑描边（`new GlowFilter(0, 0.6)`）。
	var label := Label.new()
	var 显示名 := 宠物数值.显示名(_pet)
	label.text = "%s[%s]" % [显示名, _角色]
	label.position = Vector2(-60.0, 3.0)
	label.size = Vector2(120.0, 20.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", 宠物数值.品质色_of(
		int(_pet.get("aptitude", 1)), 宠物数值.是尾兽(int(_pet.get("item_id", 0)))))
	# ⚠ 描边宽：原版 `RoleNamePane` 挂的是黑 `GlowFilter(0, 1, 3, 3, 6)`（`RoleNamePane.as:191-200`），
	#   纯黑、alpha 1；Godot 没有软辉光，用实心黑描边近似。宽度取 **2**：12px 汉字用 3px 时
	#   横画两侧的灰边会被吃掉（2026-10-20 真渲染器 1:1 + 4× 对照，见 #3.1），2px 最接近原版观感。
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 2)
	add_child(label)
	## 名牌**恒以宠物 x 居中**。原版 `RoleNamePane.as:47-48` 是 `autoSize = CENTER`
	## ⇒ 框宽 = 实测字宽、涨也是两边对称涨；上面那个写死的 `-60` 只在"字宽正好 120"时才居中，
	## 字一宽（长名字、2026-10-25 全局合成加粗 1.5）Godot 的 Label 就只往右胀 ⇒ 整块牌子偏右。
	## 进树后字体才解析得出来，所以在这里按实测宽回居中一次（`#宠物跟随重叠` ③ 钉这条）。
	label.reset_size()
	if label.size.x < 120.0:
		label.size = Vector2(120.0, label.size.y)
	label.position = Vector2(-label.size.x * 0.5, 3.0)

func _try_attack() -> void:
	if _attack_timer > 0.0 or _life_root == null:
		return
	var 有全部怪 := _life_root.has_method("挂机的全部怪")
	if not 有全部怪 and not _life_root.has_method("get_nearest_enemy"):
		return
	var session := get_node_or_null("/root/GameSession")
	var hanging := session != null and bool(session.hang_state.get("active", false))
	if hanging and not bool(session.game_settings.get("auto_pet_skills", true)):
		return
	## 原版这条链是 `AttackPetController.fireTo:27-48` → `SkillHandler.petCanFire`
	## → `PetSkill.canReachTarget(curSkillID, pet, 目标)`：**能不能打从来不看半径，只看命中盒**，
	## 而那只怪的方位先决定宠物朝哪边（`fireTo:30-31` 就是 `pet.direction = 目标.x > 宠物.x`）。
	## 所以这里也按"每只候选各按朝它的盒判一次"来算，不再用以前那个 145 像素圆。
	var 招 := 出手招式()
	var 打我的首领闸 := hanging and bool(session.game_settings.get("auto_avoid_boss", false))
	## 但目标**是谁**仍归主人：`AttackPetController.tick:60-63` 打的是
	## `API.targetHandler.petTarget`（主人的目标系统），不是"宠物半径内最近那只"。
	## 出战那只按阈值停在主人身后 200px，若只按宠物脚下算命中盒，主人身前的怪就全在盒外；
	## 原版这时走 `fireTo:41-44` 的 `movePetToPoint` 追过去，而本工程用固定偏移落稳态、
	## 没有那趟追击 ⇒ 必须留一条"主人的 145 内目标"兜底，否则挂机打怪会静默停摆（§3.241）。
	var 参照 := global_position
	if is_instance_valid(_player):
		参照 = _player.global_position
	var 主人目标: Node2D = null
	if _life_root.has_method("get_nearest_enemy"):
		主人目标 = _life_root.call("get_nearest_enemy", 参照, 145.0, 打我的首领闸) as Node2D
	var 托管 = _player.get_node_or_null("挂机托管") if _player != null else null
	var 命中: Array = []
	for 怪 in (_life_root.call("挂机的全部怪") if 有全部怪 else []):
		if not is_instance_valid(怪):
			continue
		if 打我的首领闸 and 托管 != null and 托管.has_method("怪档") \
				and int(托管.call("怪档", 怪)) != 0:
			continue			# 勾了避开首领 ⇒ 宠物也不碰（与玩家那一侧同一口径）
		var 体 := _life_root.call("怪物体型盒", 怪) as Rect2
		if 体.size == Vector2.ZERO:
			continue			# 查不到体型盒就当打不到（原版 outerBodyRect 为空同样不相交）
		if 命中盒(招, (怪 as Node2D).global_position).intersects(体):
			命中.append(怪)
	if 命中.is_empty():
		## 盒子够不着 ≠ 不打：目标由主人点名（`petTarget`），原版会先追到盒内再打。
		## 本工程没有追击，就沿用主人 145 口径直接出手（同 3748c9d 的兜底），
		## 但竖直差仍按原版的同层限制卡 90。
		if 主人目标 == null or not is_instance_valid(主人目标):
			return
		if absf(主人目标.global_position.y - 参照.y) > 90.0:
			return
		命中 = [主人目标]
	var 信息 := (_招式行(招) as Dictionary).get("info", {}) as Dictionary
	if int((信息.get("desc", {}) as Dictionary).get("target", 1)) != 2:
		命中 = [_离宠物最近(命中)]		# 单体招只打那一只（原版命中盒里有多个时主目标取最近）
	for 怪 in 命中:
		_出手(招, 怪 as Node2D)
	## 冷却 = 这一招自己的 `cdBase`（原版 `SkillHandler.isCooling(curSkillID)`，
	## 101/102 是 1.12 秒、103 是 1.379 秒），不再是一条写死的 1.35。
	_attack_timer = float((信息.get("cool_down", {}) as Dictionary).get("cdBase", 1.12))


func _出手(招: int, 怪: Node2D) -> void:
	var 方向 := signf(怪.global_position.x - global_position.x)
	if _sprite != null and _sprite.has_method("set_direction"):
		_sprite.call("set_direction", -1 if 方向 < 0 else 1)
	if _sprite != null and _sprite.has_method("play_state"):
		_sprite.call("play_state", "attack1")
		_当前动画 = "attack1"
		_动作锁 = 0.35
	var damage := maxi(1, int(_pet.get("attack", 1)))
	if 怪.has_method("take_damage"):
		怪.call("take_damage", damage, 方向)
	var tween := create_tween()
	var start := position
	tween.tween_property(self, "position", position + Vector2(方向 * 18.0, -4.0), 0.10)
	tween.tween_property(self, "position", start, 0.14)


func 摆招式(号: int) -> void:
	_当前招式 = 号


## 原版 `AttackPetController.fireTo:35` 那句 `pet.curSkillID || 101`：0 与负数一律落回出厂那招。
func 出手招式() -> int:
	return _当前招式 if _当前招式 > 0 else 101


func _招式行(招: int) -> Dictionary:
	return 数据.pet_skill(招)


## 命中盒：原版 `SkillDataTool.getPetSkillHitRect:1188-1215` 按 `info.desc.range` 给三块固定盒
## （以宠物**脚下那点**为原点，y 轴向上为负），再由 `PetSkill.getPetSkillHitRect:100-112` 按朝向搬：
## 朝左 `x = 左 + 宠物x`、朝右 `x = −右 + 宠物x`（盒宽 = 右−左，两种朝向正好镜像）。
func 命中盒(招: int, 目标中心: Vector2) -> Rect2:
	var 信息 := (_招式行(招) as Dictionary).get("info", {}) as Dictionary
	var 段 := int((信息.get("desc", {}) as Dictionary).get("range", 1))
	var 盒 := Rect2(-100.0, -100.0, 100.0, 100.0)
	if 段 == 2:
		盒 = Rect2(-400.0, -100.0, 400.0, 100.0)
	elif 段 == 3:
		盒 = Rect2(-150.0, -200.0, 300.0, 300.0)
	var 朝左 := 目标中心.x < global_position.x
	## 朝左：`x = 宠物x + 左`；朝右：`x = 宠物x − 右`（右 = 左 + 宽）。
	## 拿 101（左 −100、右 0）验：朝左 ⇒ [宠物−100, 宠物]，朝右 ⇒ [宠物, 宠物+100]，正好镜像。
	var x := global_position.x + (盒.position.x if 朝左 else -盒.end.x)
	return Rect2(x, global_position.y + 盒.position.y, 盒.size.x, 盒.size.y)


func _离宠物最近(堆: Array) -> Variant:
	var 出 = null
	var 最近 := INF
	for 项 in 堆:
		var 距 := global_position.distance_to((项 as Node2D).global_position)
		if 距 < 最近:
			最近 = 距
			出 = 项
	return 出
