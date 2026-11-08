extends SceneTree

## #66 出战 / 附身两只宠物**立绘重叠**（用户 2026-10-21 报修 4「附身、出站的两个宠物距离间隔还是太近，有重叠」）。
##
## 原版**没有"固定偏移"这个东西**：`PetController.as:262-299 movePetFold` 只做一件事 ——
## 横向差 `< _follow_xDis` 就 `stopPet()` 原地站住，`>=` 才朝主人走。两态各自把这个阈值改成
## 出战 **200**（`AttackPetController.as:24`）、附身 **100**（`FuShenPetController.as:9`）
## （基类默认 150，`PetController.as:31`）⇒ 主人朝一个方向连走时两只分别停在"差一点到 200 / 差一点到 100"，
## **稳态间距 = 200 − 100 = 100**。移植时把阈值当成了偏移，还各拍了 −54 / −100 ⇒ 两只只隔 46px，
## 而一帧立绘宽 45~47 × `scale 1.15` ≈ 54 ⇒ **必然压在一起**（就是用户说的"还是太近、有重叠"）。
##
## 这条门钉这几组事：
##   ① 字面：两个常量按原版阈值取值、带 AS3 出处，旧值 −54 不得残留；真值文档与 §3.241 都得登记；
##   ② 站位：同屏两只静止后横向差**恰好 100**，出战 200 / 附身 100，且按朝向镜像；
##   ③ 不叠：立绘盒宽 ≤ 100（并把"旧 46 < 立绘宽"这条根因数字钉住）、名牌仍以各自宠物 x 居中；
##      名牌**墨迹**在 100 间距下相切 ~20px —— 原版同几何、同样相切 ⇒ 本门只钉"这个事实别漂"，不判它；
##   ④ 打怪没被推远搞坏：出战那只停在主人身后 200px，怪在主人身前 120px 仍要出手 ——
##      原版选的是**主人的目标**（`AttackPetController.tick:60-63` 用 `API.targetHandler.petTarget`），
##      不是宠物自己附近那只 ⇒ 检索参照改成主人；附身那只永远不出手；
##   ⑤ 老账不动：腾空不跟着飞 / 主人静止播 stand / 存档字节不变（换偏移不能把这三条撞翻）；
##   ⑥ 台阶：偏移抬到 200 之后，地面必须按**主人脚下那条**采 —— 否则宠物顺着身后那一级台阶滑下去。
##   ⑦ 速度（用户 2026-10-24 报修 1.2）：跟随速度 = **主人 `move_speed` × 0.9**，主人吃到加速宠物同步
##      变快；原版是同一个 factor 推给 player/attackPet/myFuShenPet ⇒ 严格等速，0.9 这档是**有意偏离**。
##   水平线（同一轮报修 1.1）：脚点直接就是地面 y，那句没出处的 `- 18.0` 不许回来（①/②/⑥ 三条钉它）。
##
## 用法：Godot --headless --path . --script res://测试/宠物跟随重叠回归测试.gd

const 伙伴脚本 := preload("res://脚本/角色/宠物伙伴.gd")
const 出战偏移 := -200.0
const 附身偏移 := -100.0
const 稳态间距 := 100.0
const 旧间距 := 46.0
const 死区 := 8.0
const 立绘缩放 := 1.15
const 宠物索引 := "res://数据/角色/动画素材索引.json"

class 假主人 extends Node2D:
	var facing := 1
	var on_ground := true
	var footholds = null
	## ⑦ 那条要它：宠物跟随速度按主人**现值**取（`玩家.gd:30` 真实主人就是这个属性，默认 175）。
	var move_speed := 175.0

class 假怪 extends Node2D:
	var 伤害 := 0
	func take_damage(值: int, _向: float) -> void:
		伤害 += int(值)

class 假地表 extends Node:
	# 主人脚下（x > 500）是 300 那一层；身后那 200px（x ≤ 500）是 490 的下一级台阶。
	func find_foothold(x: float, _兜底: float, _fh: String) -> Dictionary:
		return {"y": 490.0 if x <= 500.0 else 300.0, "id": "1"}

## ⑧ 用：形状照真实 `地表.角色z(脚点id, 兜底y)`（`地表.gd:289`），给一个远离 `101 + y` 的固定带值，
## 这样「宠物改没改用层带口径」一眼就红/绿。
## ⚠ 地面取 1500（不是 300）：宠物旧口径 `101 + y` = 1601 > 人物 901 才会真的"盖住人物"，
## 地面若给 300 旧口径只有 401，那条"人物在上"的腿在反向对照里会假绿。
class 带层次地表 extends Node:
	func find_foothold(_x: float, _兜底: float, _fh: String) -> Dictionary:
		return {"y": 1500.0, "id": "503"}
	func 角色z(_fh: String, _y: float) -> int:
		return 900

class 假地脉 extends Node:
	var 参照 := Vector2(INF, INF)
	var 怪: Node2D
	func get_nearest_enemy(center: Vector2, 半径: float, _避王 := false) -> Node2D:
		参照 = center
		if 怪 == null:
			return null
		return 怪 if center.distance_to((怪 as Node2D).global_position) <= 半径 else null

## ⑨/⑩ 用：主人那列（x > 500）低一截 490；身后（x ≤ 500）还是上层 300。
class 跳崖地表 extends Node:
	func find_foothold(x: float, _兜底: float, _fh: String) -> Dictionary:
		return {"y": 490.0 if x > 500.0 else 300.0, "id": "1"}
	func find_connected_ground(x: float, _fh: String) -> Dictionary:
		return {"y": 490.0 if x > 500.0 else 300.0, "id": "1"}

var _通过 := 0
var _失败: Array[String] = []
var _存前 := PackedByteArray()


func _判(条件: bool, 说明: String, 补: String = "") -> void:
	_通过 += 1
	if not 条件:
		_失败.append(说明 + ("　" + 补 if not 补.is_empty() else ""))


func _走(次: int) -> void:
	for i in 次:
		await process_frame


func _字节(路: String) -> PackedByteArray:
	if not FileAccess.file_exists(路):
		return PackedByteArray()
	var f := FileAccess.open(路, FileAccess.READ)
	if f == null:
		return PackedByteArray([1])
	var b := f.get_buffer(f.get_length())
	f.close()
	return b


func _建宠物(序: int, 名: String) -> Dictionary:
	return {"id": "%08d" % (100 + 序), "item_id": 0, "name": 名, "aptitude": 1, "attack": 7, "skills": []}


func _找名牌(伙伴: Node) -> Label:
	for c in 伙伴.get_children():
		if c is Label:
			return c as Label
	return null


## 名牌墨迹半宽。原版 `RoleNamePane.as:47-48` 是 `autoSize=CENTER`（框宽 = 文字宽、居中挂在宠物头顶），
## 本工程用 120 宽的居中 Label ⇒ 墨迹同样以宠物 x 为中心 ⇒ 拿半宽就能判两行墨迹相不相交。
func _墨迹半宽(牌: Label) -> float:
	if 牌 == null:
		return -1.0
	var 字 := 牌.get_theme_font("font")
	if 字 == null:
		字 = ThemeDB.fallback_font
	var 号 := 牌.get_theme_font_size("font_size")
	return 字.get_string_size(牌.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 号).x / 2.0


## 一帧宠物立绘的盒宽（`_sprite.scale = 1.15` 之后）。原版素材每帧 45~47 宽 ⇒ 盒宽 ≈ 54。
func _立绘宽() -> float:
	var 宽 := 0.0
	var 索: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(宠物索引))
	for key in 索.keys():
		if String(key).begins_with("Pet_00000101_stand0"):
			var 张 := load(String(索[key])) as Texture2D
			if 张 != null:
				宽 = maxf(宽, 张.get_size().x * 立绘缩放)
	return 宽


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)
	await process_frame
	## 存档基线要在**单例启动之后**取：跨天首次启动时 `游戏会话._reset_daily_quests_if_needed()`
	## 会按日重置并落一次盘（产品行为，不是本门写的）。基线取在启动前 ⇒ 每天第一次跑都假红。
	_存前 = _字节("user://玩家数据.json")
	Engine.time_scale = 20.0

	# 立绘盒宽先算：② 那条"最坏间距 vs 盒宽"要用它，而 ③ 再把同一份数字判一遍。
	var 立绘宽 := _立绘宽()

	# ── ① 字面：常量取值、出处、登记 ────────────────────────────────
	var 文 := FileAccess.get_file_as_string("res://脚本/角色/宠物伙伴.gd")
	_判(文.contains("const 偏移_出战 := -200.0"), "① `偏移_出战` 应为 -200.0（出战阈值 200）")
	_判(文.contains("const 偏移_附身 := -100.0"), "① `偏移_附身` 应为 -100.0（附身阈值 100）")
	_判(not 文.contains("= -54.0"), "① 旧值 -54.0 不得残留")
	_判(文.contains("AttackPetController.as:24"), "① 出战 200 的 AS3 出处要在注释里")
	_判(文.contains("FuShenPetController.as:9"), "① 附身 100 的 AS3 出处要在注释里")
	_判(文.contains("PetController.as:31") and 文.contains("movePetFold"),
		"① 基类默认 150 与 `movePetFold` 的阈值语义得写清楚（否则后人还会把它当偏移改）")
	_判(文.contains("_地面高度(_player.global_position.x, _地面y)"),
		"① 地面采样点必须是**主人 x**（偏移抬到 200 之后按宠物 x 采会跨台阶）")
	# 1.1「宠物移动和人物不是一个水平线」+ 1.2「随人物速度提升而提升」（用户 2026-10-24 报修，§3.257）
	_判(not 文.contains("_地面y - 18.0"),
		"① 那句**没有出处**的 `- 18.0` 抬起不得残留（立绘自己按 origin 抬过，节点 y 就是脚点）")
	_判(文.contains("原始动画精灵.gd:264-266"),
		"① 为什么不该再抬 18px 的**证据**（origin 由子精灵负责）得写在注释里，否则还会有人加回来")
	_判(not 文.contains("const 跟随速度 := 245.0"),
		"① 死数 245 不得残留（主人吃到加速时它会反过来拖宠物掉队）")
	_判(文.contains("const 跟随比例 := 0.9"),
		"① 跟随速度应是**主人现值 × 0.9**（0.9 = 用户要的「略微慢一点」，比原版 1.0 等速有意偏一档）")
	_判(文.contains("Physics.WALK_SPEED") and 文.contains("DataCenter.as:2783"),
		"① 「原版把同一个 factor 同时推给 player/attackPet/myFuShenPet」这条真值出处要在注释里")
	_判(文.contains("const 基础跟随 := 125.0"),
		"① 主人属性还没到位时的兜底要取原版本体常数 125（`Physics.as:8`），不是再拍一个数")
	# ⑧ 显示层级（用户 2026-11-02 报「人物的显示优先级应该高于宠物，不能被宠物盖住」）：
	# 宠物以前用绝对屏幕 y（`101 + int(global_position.y)`），人物用 `footholds.角色z(...)+1`（层带 512）
	# ⇒ y 一过 ~155 宠物就压住人物。这里钉住"改用了同一把尺子、且旧口径没残留"。
	_判(not 文.contains("z_index = 101 +"),
		"① 绝对 y 那套宠物 z 不得残留（y≥155 就压过人物）")
	_判(文.contains("地表.call(\"角色z\""),
		"① 宠物 z 要跟人物一样走 `footholds.角色z(脚点, y)`（同一份层带口径）")
	var 攻起 := 文.find("func _try_attack")
	_判(攻起 >= 0, "① 找得到 `func _try_attack`")
	if 攻起 >= 0:
		var 攻止 := 文.find("\nfunc ", 攻起 + 1)
		var 攻体 := 文.substr(攻起, 攻止 - 攻起 if 攻止 > 攻起 else -1)
		_判(攻体.contains("参照 = _player.global_position"),
			"① `_try_attack` 的检索参照应取**主人**坐标（原版打的是主人的目标）")
		_判(攻体.contains('get_nearest_enemy", 参照, 145.0'),
			"① 射程 145 的口径没变，只换参照")
	var 真 := FileAccess.get_file_as_string("res://真值/地图/宠物跟随站位.md")
	_判(真.contains("停止阈值") and 真.contains("movePetFold") and 真.contains("AttackPetController.as:24"),
		"① 真值页要写明 `_follow_xDis` 是停止阈值、原版没有固定偏移（三条锚点）")
	_判(真.contains("200") and 真.contains("100") and 真.contains("150"),
		"① 真值页要钉住三个阈值（200 / 100 / 默认 150）")
	_判(FileAccess.get_file_as_string("res://真值/地图/宠物跟随站位.md").contains("walkSpeedFactor"),
		"① 真值页要留 `walkSpeedFactor` 那条原版口径（宠物与主人等速的证据）")
	var 邻 := FileAccess.get_file_as_string("res://测试/功能入口回归测试.gd")
	_判(邻.contains("95.0") and not 邻.contains("< 20.0"),
		"① 老门里那条「两只不许叠」的判据也得从 <20 抬到 ≥95（否则它咬不住 46px 这种间距）")

	# ── ② 站位：同屏两只差恰好 100、按朝向镜像 ─────────────────────
	var 主人 := 假主人.new()
	root.add_child(主人)
	主人.global_position = Vector2(600, 300)
	await _走(3)

	var 出战 := 伙伴脚本.new() as Node2D
	var 附身 := 伙伴脚本.new() as Node2D
	root.add_child(出战)
	root.add_child(附身)
	出战.call("configure", _建宠物(1, "一阶忍犬"), 主人, null, "出战")
	附身.call("configure", _建宠物(2, "二阶忍犬"), 主人, null, "附身")
	await _走(12)

	_判(absf(出战.global_position.x - (600.0 + 出战偏移)) < 1.0,
		"② 出战应停在主人身后 200", "实测 x=%.1f" % 出战.global_position.x)
	_判(absf(附身.global_position.x - (600.0 + 附身偏移)) < 1.0,
		"② 附身应停在主人身后 100", "实测 x=%.1f" % 附身.global_position.x)
	_判(absf(absf(出战.global_position.x - 附身.global_position.x) - 稳态间距) < 0.5,
		"② 两只横向差应恰好 100（= 两态阈值之差）",
		"实测 %.1f" % absf(出战.global_position.x - 附身.global_position.x))
	# 1.1：宠物和主人**必须踩同一条线**。主人 y=300、假地表还没挂上 ⇒ `_地面高度` 就返回 300，
	# 所以两只的 y 也该正好 300 —— 以前那句 `- 18.0` 让它停在 282，看上去就是"飘在半空、和人物不
	# 是一条水平线"（用户 2026-10-24 报修）。
	_判(absf(出战.global_position.y - 300.0) < 0.5 and absf(附身.global_position.y - 300.0) < 0.5,
		"② 两只脚点与主人同一条水平线（y 都 = 300，不再抬 18）",
		"实测 出战 y=%.1f / 附身 y=%.1f" % [出战.global_position.y, 附身.global_position.y])

	主人.facing = -1
	await _走(200)
	# ⚠ 容差 = 跟随环的死区：`宠物伙伴.gd:_process:72` 只在 `距离 > 8.0` 时才 move_toward ⇒
	#   每只最多停在理想位前 8px。换向这种"要走 400px"的瞬态里，理想间距 100 会缩到 **100 − 2×8 = 84**。
	#   判"叠不叠"要看**最坏间距 vs 立绘盒宽**，不是看 100 这个整数。
	_判(absf(出战.global_position.x - (600.0 - 出战偏移)) <= 死区 + 0.5,
		"② 主人朝左时出战应走到主人**右**侧 200（死区内）", "实测 x=%.1f" % 出战.global_position.x)
	_判(absf(附身.global_position.x - (600.0 - 附身偏移)) <= 死区 + 0.5,
		"② 主人朝左时附身应走到主人右侧 100（死区内）", "实测 x=%.1f" % 附身.global_position.x)
	var 换向间距 := absf(出战.global_position.x - 附身.global_position.x)
	_判(absf(换向间距 - 稳态间距) <= 死区 * 2.0 + 0.5,
		"② 换向后两只仍是 100 ± 死区(2×8)", "实测 %.1f" % 换向间距)
	_判(换向间距 >= 立绘宽, "② 最坏情况（两只都停在死区边缘）也不许叠：间距 ≥ 立绘盒宽",
		"间距 %.1f / 立绘 %.1f" % [换向间距, 立绘宽])
	主人.facing = 1
	await _走(400)
	_判(absf(出战.global_position.x - (600.0 + 出战偏移)) <= 死区 + 0.5,
		"② 转回朝右后出战回到主人身后 200（死区内）", "实测 x=%.1f" % 出战.global_position.x)
	_判(absf(附身.global_position.x - (600.0 + 附身偏移)) <= 死区 + 0.5,
		"② 转回朝右后附身回到主人身后 100（死区内）", "实测 x=%.1f" % 附身.global_position.x)

	# ── ③ 不叠：立绘盒宽与名牌墨迹 ─────────────────────────────────
	_判(立绘宽 > 0.0, "③ 取得到一帧宠物立绘（③ 的前提）", "实测 %.1f" % 立绘宽)
	_判(立绘宽 <= 稳态间距, "③ 立绘盒宽 %.1f 应 ≤ 间距 100 ⇒ 两只不叠" % 立绘宽)
	_判(立绘宽 > 旧间距, "③ 立绘盒宽 %.1f 应 > 旧间距 46 —— 这个差就是「旧值必叠」的根因数字" % 立绘宽)
	var 出战半 := _墨迹半宽(_找名牌(出战))
	var 附身半 := _墨迹半宽(_找名牌(附身))
	_判(出战半 > 0.0 and 附身半 > 0.0, "③ 两只都该有名牌（③ 墨迹腿的前提）",
		"%.1f / %.1f" % [出战半, 附身半])
	# 名牌几何：原版 `RoleNamePane.as:131` 是 `_bg.x = -PanelWidth/2` ⇒ 文字**以宠物 x 居中**。
	# 两条都居中 ⇒ 两只一分开，名牌就跟着分开；这条钉"没把牌子挪到别人头上去"。
	var 牌出 := _找名牌(出战)
	var 牌附 := _找名牌(附身)
	_判(absf(牌出.position.x + 牌出.size.x / 2.0) < 0.5 and absf(牌附.position.x + 牌附.size.x / 2.0) < 0.5,
		"③ 两只名牌都应以各自的宠物 x 为中心（`RoleNamePane.as:131`）")
	# ⚠ 名牌**墨迹**这一条本门**不判**：12px 宋体下「一阶忍犬(普通)[出战]」实测半宽 60 ⇒ 两只牌子
	#   在 100 间距下边缘相切 ~20px。原版同几何（同 120 宽、同 100 稳态间距）也相切 ⇒ 不是移植引入的
	#   偏离。数字记在 `真值/地图/宠物跟随站位.md` ④-5，要改得先由用户定夺（换行 / 缩字 / 分侧站）。
	_判(出战半 + 附身半 > 稳态间距 and 出战半 + 附身半 <= 稳态间距 + 25.0,
		"③ 名牌相切这条**已知事实**要稳定（半宽和应落在 100~125，超出说明美术/字号被动过）",
		"实测 %.1f + %.1f" % [出战半, 附身半])

	# ── ④ 打怪：参照改到主人身上，附身永不出手 ─────────────────────
	var 怪 := 假怪.new()
	root.add_child(怪)
	怪.global_position = Vector2(720, 300)
	var 地脉 := 假地脉.new()
	root.add_child(地脉)
	地脉.怪 = 怪
	var 出战打 := 伙伴脚本.new() as Node2D
	root.add_child(出战打)
	出战打.call("configure", _建宠物(3, "三阶忍犬"), 主人, 地脉, "出战")
	var 附身打 := 伙伴脚本.new() as Node2D
	root.add_child(附身打)
	附身打.call("configure", _建宠物(4, "四阶忍犬"), 主人, 地脉, "附身")
	await _走(10)
	_判(absf(地脉.参照.x - 600.0) < 1.0,
		"④ 选敌参照应是**主人** x=600（不是宠物站的 400）", "实测 %.1f" % 地脉.参照.x)
	_判(怪.伤害 > 0, "④ 怪在主人身前 120、出战停在身后 200 时仍要打得到（推远不能把挂机打怪搞停摆）",
		"伤害 %d" % 怪.伤害)
	_判(str(附身打.get("_当前动画")) != "attack1", "④ 附身那只不许出手（只跟走）")

	# ── ⑤ 老账不动：腾空 / 静止动画 / 存档字节 ──────────────────────
	var 原y := 出战.global_position.y
	主人.on_ground = false
	主人.global_position.y = 150.0
	await _走(6)
	_判(absf(出战.global_position.y - 原y) < 1.0,
		"⑤ 主人腾空时宠物不许跟着飞（还站在那条地面上）", "y %.1f → %.1f" % [原y, 出战.global_position.y])
	主人.global_position.y = 300.0
	主人.on_ground = true
	await _走(60)
	_判(str(出战.get("_当前动画")) == "stand", "⑤ 主人静止时出战应播 stand",
		"实测 %s" % str(出战.get("_当前动画")))
	var 终间距 := absf(出战.global_position.x - 附身.global_position.x)
	_判(终间距 >= 立绘宽 and absf(终间距 - 稳态间距) <= 死区 * 2.0 + 0.5,
		"⑤ 走完这一切两只仍是「100 ± 死区、且 ≥ 立绘宽」", "实测 %.1f" % 终间距)

	# ── ⑥ 台阶：宠物贴**主人那条地面**，不许滑到身后那一级 ───────────
	# 这是把偏移从 54 抬到 200 之后**必须一起改**的一条：地面若按宠物自己的 目标x 采，
	#  stepped 地图上那 200px 里跨一级台阶，宠物就顺着台阶滑下去了（原版由 PathFinder 带上主人平台）。
	var 地表 := 假地表.new()
	root.add_child(地表)
	主人.footholds = 地表
	主人.global_position = Vector2(600, 300)
	var 台阶宠 := 伙伴脚本.new() as Node2D
	root.add_child(台阶宠)
	台阶宠.call("configure", _建宠物(5, "五阶忍犬"), 主人, null, "出战")
	await _走(120)
	_判(absf(float(台阶宠.call("_地面高度", 600.0, 300.0)) - 300.0) < 0.5,
		"⑥ 主人 x 采到的应是主人那条地面（300）")
	_判(absf(float(台阶宠.call("_地面高度", 400.0, 300.0)) - 490.0) < 0.5,
		"⑥ 前提：身后 200px 那一级确实是 490（这关真跨了台阶）")
	_判(absf(台阶宠.global_position.y - 300.0) < 1.0,
		"⑥ 出战仍站在主人那条地面上（不许滑到 490 那一级，也不许再抬 18）",
		"实测 y=%.1f" % 台阶宠.global_position.y)
	_判(absf(台阶宠.global_position.x - 400.0) <= 死区 + 0.5,
		"⑥ 改了地面口径，横向仍是主人身后 200", "实测 x=%.1f" % 台阶宠.global_position.x)
	for 偏差 in [-7.0, 7.0]:
		台阶宠.global_position = Vector2(400.0, 300.0 + 偏差)
		台阶宠.call("_process", 1.0 / 60.0)
		_判(absf(台阶宠.global_position.y - 300.0) < 0.01,
			"⑥ 停止跟随的死区不能留下竖直偏差 %.1f" % 偏差,
			"实测 y=%.2f" % 台阶宠.global_position.y)
		_判(absf(台阶宠.global_position.x - 400.0) < 0.01,
			"⑥ 修正脚底高度不能改变已经停稳的横向站位")
	主人.footholds = null

	# ── ⑦ 跟随速度跟着主人现值（用户 2026-10-24 报修 1.2「随人物速度提升而提升，比人物略微慢一点」）──
	# 直接把 delta 喂进 `_process` ⇒ 位移 = 跟随速度 × delta，不吃 time_scale 与真帧时长的噪声。
	# 摆位：主人 x=700 朝右 ⇒ 目标 = 700 − 200 = 500；宠物摆 x=400 ⇒ 差 100（> 死区 8、< 瞬移 420）。
	主人.facing = 1
	主人.global_position = Vector2(700.0, 300.0)
	出战.global_position = Vector2(400.0, 300.0)
	主人.move_speed = 175.0
	出战.call("_process", 0.1)
	_判(absf(出战.global_position.x - 415.75) < 0.01,
		"⑦ 主人 175 ⇒ 宠物 157.5（0.9 倍），0.1s 追 15.75px",
		"实测 x=%.2f" % 出战.global_position.x)
	主人.move_speed = 300.0
	出战.call("_process", 0.1)
	_判(absf(出战.global_position.x - 442.75) < 0.01,
		"⑦ 主人吃到加速（300）⇒ 同样 0.1s 追 27px（速度真跟着属性走，不是死数 245）",
		"实测 x=%.2f" % 出战.global_position.x)
	主人.move_speed = 0.0
	_判(absf(float(出战.call("_跟随速度")) - 112.5) < 0.01,
		"⑦ 主人速度还没到账时退回原版常数 125 × 0.9，宠物不许定在原地",
		"实测 %.2f" % float(出战.call("_跟随速度")))
	主人.move_speed = 175.0

	# ── ⑧ 显示层级：人物压住宠物（用户 2026-11-02 报「人物的显示优先级应该高于宠物，不能被宠物盖住」）──
	# 假地表给带值 900（远离 `101 + y` 的 401）⇒ 只要宠物还按绝对 y 算，第一条就红。
	# 人物自己那一头是 `角色z + 1`（`玩家.gd:1600` 的「自己压住别人」偏离）⇒ 这里把主人的 z 摆成 901。
	var 层次地表 := 带层次地表.new()
	root.add_child(层次地表)
	主人.footholds = 层次地表
	主人.global_position = Vector2(600, 1500)
	主人.z_index = 901
	var 层宠 := 伙伴脚本.new() as Node2D
	root.add_child(层宠)
	层宠.call("configure", _建宠物(6, "六阶忍犬"), 主人, null, "出战")
	await _走(4)
	_判(int(层宠.z_index) == 900,
		"⑧ 宠物 z 取脚点层带（假地表给 900），而不是 101+y=1601",
		"实测 %d" % int(层宠.z_index))
	_判(int(层宠.z_index) < int(主人.z_index),
		"⑧ 人物（901）必须压在宠物（900）上面 —— 同格时宠物不许盖住自己",
		"宠 %d / 人 %d" % [int(层宠.z_index), int(主人.z_index)])
	_判(int(层宠.z_index) > 255,
		"⑧ 宠物仍落在角色带里（> 255），没有掉到地形/物件下面",
		"实测 %d" % int(层宠.z_index))
	主人.footholds = null
	主人.z_index = 0

	# ── ⑨ 跳跃空中横移：地面冻结在起跳层（用户 2026-11-07 报「人物跳跃在空中移动时宠物沉到地下」）──
	# 旧实现腾空时仍按主人移动中的 x 调 `find_foothold`：主人跳下台、空中横移到低一层的列上，
	# 宠物地面就跟着采成 490，而宠物自己还站在身后的 300 那层 ⇒ 整只埋进台面下。
	var 崖地 := 跳崖地表.new()
	root.add_child(崖地)
	主人.footholds = 崖地
	主人.global_position = Vector2(700.0, 330.0)	# 已跳下 30px、还没落地
	主人.on_ground = false
	var 跳宠 := 伙伴脚本.new() as Node2D
	root.add_child(跳宠)
	跳宠.call("configure", _建宠物(7, "七阶忍犬"), 主人, null, "出战")
	跳宠.set("_地面y", 300.0)						# 起跳层（configure 用的是主人空中的 y）
	跳宠.global_position = Vector2(500.0, 300.0)
	await _走(6)
	_判(absf(float(跳宠.call("_地面高度", 700.0, 300.0)) - 300.0) < 0.5,
		"⑨ 腾空横移到低一层的列上，宠物地面仍冻结在起跳层（旧实现采到 490）",
		"实测 %.1f" % float(跳宠.call("_地面高度", 700.0, 300.0)))
	_判(absf(跳宠.global_position.y - 300.0) < 1.0,
		"⑨ 空中横移时宠物不许沉到下层地面", "实测 y=%.1f" % 跳宠.global_position.y)

	# ── ⑩ 宠物自己这一列更高：脚抬回台面上（不埋进身后那层地形）──
	主人.on_ground = true
	主人.global_position = Vector2(700.0, 490.0)
	var 抬宠 := 伙伴脚本.new() as Node2D
	root.add_child(抬宠)
	抬宠.call("configure", _建宠物(8, "八阶忍犬"), 主人, null, "出战")
	抬宠.global_position = Vector2(500.0, 490.0)	# 刚按主人那列地面落下的样子
	抬宠.call("_process", 1.0 / 60.0)
	_判(absf(抬宠.global_position.y - 300.0) < 0.5,
		"⑩ 宠物列是 300、主人列是 490 ⇒ 抬起脚回到 300（不许埋进台面下）",
		"实测 y=%.1f" % 抬宠.global_position.y)
	_判(absf(抬宠.global_position.x - 500.0) < 0.01, "⑩ 抬脚不改变横向站位",
		"实测 x=%.1f" % 抬宠.global_position.x)
	_判(absf(float(抬宠.call("_地面高度", 700.0, 490.0)) - 490.0) < 0.5,
		"⑩ 主人站着时地面仍按主人那列采（490），抬脚只是上限，不是换落点")

	# ── ⑪ 宠物自己这一列更低：必须落到该列的**正常地面**（用户 2026-11-07：
	#   「降就跟正常地面高度一样，别停在旧高度悬空、也别低于地面」）。
	#   主人腾空 ⇒ 主人那条地面冻结在 300；宠物已经横移到自己列（x>500 ⇒ 490）却还挂在 300。
	var 落宠 := 伙伴脚本.new() as Node2D
	root.add_child(落宠)
	落宠.call("configure", _建宠物(9, "九阶忍犬"), 主人, null, "出战")
	落宠.set("_地面y", 300.0)						# 主人空中冻结的旧地面
	落宠.global_position = Vector2(700.0, 300.0)	# 还挂在起跳层
	主人.on_ground = false
	主人.global_position = Vector2(900.0, 330.0)	# 主人在上层那条列、空中（目标 x = 700，宠物不横移）
	落宠.call("_process", 1.0 / 60.0)
	_判(absf(落宠.global_position.y - 490.0) < 0.5,
		"⑪ 自己列地面是 490 ⇒ 落下来贴正常地面（只抬不降会停在 300 悬空）",
		"实测 y=%.1f" % 落宠.global_position.y)
	_判(absf(落宠.global_position.x - 700.0) < 0.01, "⑪ 落地不改变横向站位",
		"实测 x=%.1f" % 落宠.global_position.x)
	主人.on_ground = true
	主人.footholds = null

	Engine.time_scale = 1.0
	for n in [主人, 出战, 附身, 出战打, 附身打, 怪, 地脉, 地表, 台阶宠, 层次地表, 层宠, 崖地, 跳宠, 抬宠, 落宠]:
		if is_instance_valid(n):
			n.free()
	_判(_字节("user://玩家数据.json") == _存前, "⑤ 存档字节不得变化")
	_收尾()


func _收尾() -> void:
	print("宠物跟随重叠回归：通过 %d 条，失败 %d 条" % [_通过, _失败.size()])
	for 条 in _失败:
		print("  ✗ " + 条)
	print("跑完了")
	quit(1 if not _失败.is_empty() else 0)
