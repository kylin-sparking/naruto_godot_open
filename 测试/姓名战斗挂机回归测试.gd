extends SceneTree

## 本工程 `GAME_DATA` 不是 autoload，是每个文件自己 preload 的常量（见 脚本/角色/战斗角色.gd:49）。
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
const 门存档快照 := preload("res://测试/门存档快照.gd")

var _failures: Array[String] = []
## 本门会开关挂机/改设置 ⇒ 会话层落盘。开场按字节快照、收尾按字节还原（净效果为零）。
var _文件前 := {}
## 判过的条数。变异实测要靠它证明"条数恒定"——只红不改变总数才算抓到，
## 总数变了说明门自己被打断了，那不是证据。
var 判数 := 0

func _initialize() -> void:
	_文件前 = 门存档快照.全快照()
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	var backend := root.get_node_or_null("BackendConnection")
	if session == null:
		_fail("缺少 GameSession 自动加载")
		_finish()
		return
	var original_hud: Dictionary = session.hud_state.duplicate(true)
	var original_hang: Dictionary = session.hang_state.duplicate(true)
	var original_settings: Dictionary = session.game_settings.duplicate(true)

	if backend == null or not bool(backend.in_game):
		_check(session.request_pk_mode(2), "离线战斗模式请求应成功")
		_check(int(session.hud_state.get("pk_mode", 0)) == 2, "离线战斗模式应立即更新")
		_check(session.request_hang(true), "离线挂机应能开始")
		_check(bool(session.hang_state.get("active", false)), "挂机运行状态应独立记录")
		_check(bool(session.game_settings.get("auto_attack_enabled", true)), "自动战斗选项不应被挂机开停覆盖")
		_check(session.request_hang(false), "离线挂机应能停止")
		_check(not bool(session.hang_state.get("active", true)), "停止挂机后运行状态应关闭")

	var scene := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for _frame in 12:
		await process_frame
	var player := scene.get_node_or_null("Player") as Node2D
	var player_nameplate := player.get_node_or_null("Nameplate") as Label if player != null else null
	_check(player_nameplate != null, "本地玩家应创建姓名牌")
	if player_nameplate != null:
		# 原版名字画在**脚下面**（`Character.as:1484` 的 `_namePane.y = paneHeight - 3`，
		# RoleNamePane 又把文字画在自己原点上方）——以前这条断言钉的是"在头顶"，是照着我
		# 自造的摆法写的，2026-09-27 按 AS3 改掉。
		_check(player_nameplate.position.y >= 0.0, "本地玩家姓名牌应贴在脚点（不高于脚点）")
		_check(player_nameplate.position.y <= 8.0, "本地玩家姓名牌不应离脚点超过一行")
		_check(not player_nameplate.text.strip_edges().is_empty(), "本地玩家姓名牌不应为空")
		# 2026-10-25 用户：「都有点糊…改回去吧」⇒ 字号回 12；清晰度改由**收薄黑晕**承担：
		# 玩家/NPC 名字描边 3 ⇒ 2（与称号/主题一致），怪物名/家族牌仍 3。
		_check(int(player_nameplate.get_theme_font_size("font_size")) == 12,
				"本地玩家姓名牌字号应回 12（14 太大），实测 %d"
				% int(player_nameplate.get_theme_font_size("font_size")))
		_check(int(player_nameplate.get_theme_constant("outline_size")) == 2,
				"本地玩家姓名牌描边应 2（12px 下减薄黑晕），实测 %d"
				% int(player_nameplate.get_theme_constant("outline_size")))
	## 头像下那颗战斗模式钮（原版 `_pvpBtn`）这一腿：按模式换皮 + 点开四行菜单 + 点行才发上行。
	if backend == null or not bool(backend.get("in_game")):
		await _模式钮腿(scene, session)
	else:
		print("注：会话已连着真服务端 ⇒ 跳过模式钮这一腿（它走的是离线立即回落那条路）")
	var life_root := scene.get_node_or_null("LifeRoot")
	var named_life_count := 0
	var animated_actor: Node2D
	var animated_sprite: Node2D
	if life_root != null:
		for actor in life_root.get("_entities") as Array:
			var label := (actor as Node).get_node_or_null("Nameplate") as Label
			var sprite := (actor as Node).get_node_or_null("Sprite") as Node2D
			if label != null and not label.text.strip_edges().is_empty():
				_check_nameplate_below_visual(actor as Node2D, sprite, "NPC 或怪物")
				var 字号 := int(label.get_theme_font_size("font_size"))
				var 描边 := int(label.get_theme_constant("outline_size"))
				if label.text.ends_with("级"):
					_check(字号 == 12, "怪物姓名牌字号应保持原版 12，实测 %d" % 字号)
					_check(描边 == 3, "怪物姓名牌描边应保持原版 3（用户没点名），实测 %d" % 描边)
				else:
					_check(字号 == 12, "NPC 姓名牌字号应回 12，实测 %d" % 字号)
					_check(描边 == 2, "NPC 姓名牌描边应 2（12px 下减薄黑晕），实测 %d" % 描边)
				var 称号 := (actor as Node).get_node_or_null("NameplateTitle") as Label
				if 称号 != null:
					_check(int(称号.get_theme_font_size("font_size")) == 12,
							"NPC 功能称号字号应回 12，实测 %d"
							% int(称号.get_theme_font_size("font_size")))
					_check(int(称号.get_theme_constant("outline_size")) == 2,
							"NPC 功能称号描边应 2，实测 %d"
							% int(称号.get_theme_constant("outline_size")))
				named_life_count += 1
				if animated_actor == null and sprite != null and sprite.has_signal("visual_bounds_changed"):
					animated_actor = actor as Node2D
					animated_sprite = sprite
	_check(named_life_count > 0, "NPC 或怪物应显示贴脚点的非空姓名牌")
	if animated_actor != null:
		# 原版名牌的 y 是个常量（`Monster.as:840/1686` 的 `2 + paneHeight`），**不跟帧走**；
		# 跟帧走的是血条（`Monster.as:840` 的 `mobBmdHeight`）。以前这条钉的是"跟着动"，反了。
		var animated_label := animated_actor.get_node_or_null("Nameplate") as Label
		var visual := animated_sprite.get("sprite") as Sprite2D
		var previous_y := animated_label.position.y
		visual.position.y += 23.0
		animated_sprite.emit_signal("visual_bounds_changed")
		_check(is_equal_approx(animated_label.position.y, previous_y), "动画帧变化时姓名牌不应移动（原版是常量）")
		_check_nameplate_below_visual(animated_actor, animated_sprite, "动画中的 NPC 或怪物")

	if life_root != null:
		var remote_actor := Node2D.new()
		life_root.add_child(remote_actor)
		var remote_sprite := OriginalSprite.new()
		remote_actor.add_child(remote_sprite)
		_check(remote_sprite.configure("character", "10000001", "stand"), "远程玩家测试精灵应能加载")
		life_root.call("_create_nameplate", remote_actor, "远程玩家", remote_sprite)
		_check_nameplate_below_visual(remote_actor, remote_sprite, "远程玩家")
		var remote_label := remote_actor.get_node_or_null("Nameplate") as Label
		var remote_y := remote_label.position.y
		remote_sprite.play("sit0")
		_check(is_equal_approx(remote_label.position.y, remote_y), "远程玩家切换动画时姓名牌不应重定位")
		_check_nameplate_below_visual(remote_actor, remote_sprite, "切换动画后的远程玩家")
		remote_actor.queue_free()

	session.game_settings["show_names"] = false
	session.settings_changed.emit(session.game_settings.duplicate(true))
	await process_frame
	_check(player_nameplate != null and not player_nameplate.visible, "关闭名字显示应同时隐藏本地玩家姓名牌")

	# ---- 战斗表现：伤害数字的**文案/颜色/位置** + 震屏 + 击飞 ----
	# 三档文案的真值都在 `player_addAttriChangeTip(tip, num, add, 类型)` 那一套里：
	#   文字 = `tip + "  " + ("+"|"-") + " " + num`（怪 `Monster.as:908` / 人 `Character.as:1235`）
	#     ⇒ tip 为空时**前面那两个字照拼**，所以普通一刀是「␣␣- 120」而不是「-120」。
	#   `num == 0 且 tip 非空` ⇒ 只写 tip（`Monster.as:911-914`）
	#   `num == 0 且 tip 空`   ⇒ 怪写「未命中」、玩家写「我闪」（跳着时「跳闪」，`:1244-1256`）
	# 颜色：普通打怪 白 16777215、暴击 红 16711680、玩家挨打两档都红；**闪避那档两边不一样**：
	#   怪侧蓝 255（`Monster.as:431-433`）、玩家侧绿 65280（`Character.as:584-586`）。
	# ⚠️ 我们原来还有一句自造的 `玩家.show_hit_feedback()`（整个角色泛红再淡回来）——
	#    原版里没有这个，2026-10-01 已删（函数本身也删了）。门里两件都钉住。
	_check(player != null and not player.has_method("show_hit_feedback"),
			"自造的挨打泛红 `show_hit_feedback` 应已删除（原版只有伤害数字）")
	if life_root != null and player != null:
		var 怪: Node2D = null
		for 实体 in life_root.get("_entities") as Array:
			var 谁 := 实体 as Node2D
			if 谁 != null and String(谁.get("kind")) == "m" and bool(谁.get("alive")):
				怪 = 谁
				break
		if 怪 == null:
			_fail("本地图没有怪，挨打反馈这条没验到")
		else:
			var 存档: Dictionary = session.player_stats.duplicate(true)
			var 根 := 怪.get_parent()
			session.player_stats["dodge"] = 0          # 必中，免得骰子把它摇成未命中
			session.player_stats["hp"] = 100000
			怪.set("authoritative", false)
			var 前 := player.get_child_count()
			_清伤害数字(player)
			怪.call("结算对玩家伤害", player)
			_排空飘字(player)
			_check(player.get_child_count() > 前,
					"怪打中玩家时应在玩家身上放一个伤害数字（原版那条 `Character.as:1220`）")
			## ⭐ 数字**长什么样**：本工程原来传 `absi()` ⇒ 掉血飘「+N」，暴击只换色、漏了前缀。
			## ⚠ 读的是**最后一条**（刚放的那枚）：上一版叫 `_首条`，会读到上一次打的旧文案，
			##    于是「暴击」那条其实一直在比旧数字 —— 2026-10-11 自己踩的，判据读错对象。
			var 玩家文案 := _最新伤害数字文本(player)
			_check(玩家文案.length() > 4 and 玩家文案.begins_with("  - ")
					and 玩家文案.substr(4).is_valid_int(),
					"玩家挨普通打 = 「␣␣- 数字」（tip 为空时那两个空格照原版拼）；实得「%s」" % 玩家文案)
			_check(_最新伤害数字颜色(player) == Color(1.0, 0.0, 0.0),
					"玩家挨打那行是红的（CHAR_HP_COMMON = 16711680，`Character.as:573-575`）；实得 %s"
					% str(_最新伤害数字颜色(player)))

			# ── 怪身上三档：普通 / 暴击 / 未命中 ────────────────────────────
			# ⚠ 这三条腿 + 下面击飞那三条腿都跑在**现造的夹具怪**上，不跑在地图那两只身上：
			#   ① 打死一只真怪会触发场景里的死亡/复活逻辑，后面的腿就在一具正在消失的节点上量；
			#   ② 本图一共只有两只怪，而击飞要三只各死一次（非暴击死 / 暴击死 / boss 暴击死）。
			#   夹具用的是**同一个脚本 + 数据里真实存在的怪 id**，`_是boss()` 之类读的还是真数据。
			var 甲 := _造怪(根, String(怪.get("entity_id")))
			var 血前 := int(甲.get("hp"))
			_清伤害数字(甲)
			甲.call("take_damage", 120, 0.0, false)
			_排空飘字(甲)
			_check(_最新伤害数字文本(甲) == "  - 120",
					"怪挨普通打 = 「␣␣- 120」（`Monster.as:908`：tip + 两个空格 + 符号 + 一个空格 + 数字；"
					+ "实得「%s」）" % _最新伤害数字文本(甲))
			_check(_最新伤害数字颜色(甲) == Color(1.0, 1.0, 1.0),
					"怪挨普通打是白的（MOB_HP_COMMON = 16777215，`Monster.as:423-424`）；实得 %s"
					% str(_最新伤害数字颜色(甲)))
			甲.set("hp", 血前)
			_清伤害数字(甲)
			甲.call("take_damage", 120, 0.0, true)
			_排空飘字(甲)
			_check(_最新伤害数字文本(甲) == "暴击  - 120",
					"怪挨暴击 = 「暴击␣␣- 120」（前缀 = `CNCore.FIGHT_BSK`，`AbstractSkillEffect.as:199-200`；"
					+ "实得「%s」）" % _最新伤害数字文本(甲))
			_check(_最新伤害数字颜色(甲) == Color(1.0, 0.0, 0.0),
					"怪挨暴击是红的（MOB_HP_BSK = 16711680）；实得 %s" % str(_最新伤害数字颜色(甲)))
			血前 = int(甲.get("hp"))
			甲.set("_hit_timer", 0.0)
			_清伤害数字(甲)
			甲.call("take_damage", 0, 1.0, false)
			_排空飘字(甲)
			_check(_最新伤害数字文本(甲) == "未命中",
					"怪被闪开 = 「未命中」（`Monster.as:916` 的 FIGHT_MISS）；实得「%s」" % _最新伤害数字文本(甲))
			_check(_最新伤害数字颜色(甲) == Color(0.0, 0.0, 1.0),
					"「未命中」怪侧是**蓝**（`Monster.as:431-433` 把颜色整个盖成 255）；实得 %s"
					% str(_最新伤害数字颜色(甲)))
			_check(int(甲.get("hp")) == 血前, "未命中不该掉血（原版 damage==0 那一支根本不碰血量）")
			_check(float(甲.get("_hit_timer")) == 0.0,
					"未命中不该进受击僵直（实得 _hit_timer=%f 秒）" % float(甲.get("_hit_timer")))
			## ⭐ 反面对照：**打中也不一定进僵直** —— 原版 `AbstractSkillEffect.as:217-229`：
			##    怪还活着才掷 `MathAD.rnd(1,100)`，普通怪 `< 11`、boss `< 40` 才 `hit()`。
			##    以前这里是**每下都播 `hit1`**，所以"有的播有的不播"这条就是那处偏差的观测点。
			##    概率 10% ⇒ 拿 100 下：一把都不播的概率 0.9^100 ≈ 2.6e-5（不会偶发红），
			##    而"每下都播"的老写法在这 100 下里必然被逮到（概率 1 - 0.1^100 ≈ 1）。
			甲.set("hp", 99999)
			var 播过 := 0
			var 没播过 := 0
			for _下 in 100:
				甲.set("_hit_timer", 0.0)
				甲.call("take_damage", 10, 0.0, false)
				if float(甲.get("_hit_timer")) > 0.0:
					播过 += 1
				else:
					没播过 += 1
			_排空飘字(甲)
			_check(播过 > 0 and 没播过 > 0,
					"100 下普通打应当**有的僵直有的不僵直**（普通怪 11%% 掷中才播，`AbstractSkillEffect.as:222-224`）；"
					+ "实得 播 %d / 不播 %d" % [播过, 没播过])
			_check(int(甲.call("_僵直概率")) == 11,
					"普通怪的受击僵直概率是 11（原版 `MathAD.rnd(1,100) < 11`）；实得 %d"
					% int(甲.call("_僵直概率")))
			甲.set("entity_id", "2000001")		# 数据里 boss=2 的一枚
			_check(int(甲.call("_僵直概率")) == 40 and bool(甲.call("_是boss")),
					"换成 boss 之后 `_僵直概率` 要跟着变 40（原版 boss 那一支 `< 40`），`_是boss()` 要认它；"
					+ "实得 概率=%d 是boss=%s" % [int(甲.call("_僵直概率")), str(bool(甲.call("_是boss")))])

			# ── 数字的**位置**：容器 `y = -锚点 + 12`，文字按自身宽居中 ──
			var 件 := (load("res://脚本/角色/伤害数字.gd") as GDScript).new() as Node2D
			root.add_child(件)
			件.call("播放", 100.0, -120, "")
			_check(absf(件.position.y + 88.0) < 0.01,
					"锚点 100 ⇒ 容器 y = -100 + 12 = -88（`Monster.as:934`）；实得 %f" % 件.position.y)
			var 标签 := 件.get("_标签") as Label
			_check(标签 != null and absf(标签.position.x + 标签.size.x * 0.5) < 0.01,
					"文字按自身宽居中（`_loc2_.x = -textWidth/2`）；实得 x=%s 宽=%s" % [
					str(标签.position.x if 标签 != null else 0.0),
					str(标签.size.x if 标签 != null else 0.0)])
			件.queue_free()

			# ── 飘字队列的节奏本身（原版 `Character.as:2591-2598` / `Monster.as:883+`）──
			## 上面那些"投完就排空再读"的腿只判**字长什么样**；这两条判的是**节奏**：
			## 每个角色每 400 毫秒只放一条、排到 50 条以上丢**最旧**的。
			## 少了这两条，把队列写成"来一条砸一条"（我们接之前的老行为）门也不会红。
			var 庚 := _造怪(根, String(怪.get("entity_id")))
			_清伤害数字(庚)
			庚.set("hp", 999999)
			庚.call("take_damage", 11, 0.0, false)
			庚.call("take_damage", 22, 0.0, false)
			庚.call("take_damage", 33, 0.0, false)
			await process_frame
			_check(_最新伤害数字文本(庚) == "  - 11",
					"连投三条、下一帧只应放出**第一条**（原版每 400 毫秒才放一条）；实得「%s」"
					% _最新伤害数字文本(庚))
			await create_timer(0.45).timeout
			_check(_最新伤害数字文本(庚) == "  - 22",
					"再过 0.45 秒放出第二条（顺序也得是投进去的顺序）；实得「%s」"
					% _最新伤害数字文本(庚))
			await create_timer(0.45).timeout
			_check(_最新伤害数字文本(庚) == "  - 33",
					"再 0.45 秒放出第三条 ⇒ 三条错开出现，不是叠在同一像素上；实得「%s」"
					% _最新伤害数字文本(庚))
			var 队庚 = 庚.get_node_or_null("飘字队列")
			_check(队庚 != null, "角色身上应当挂着一条自己的飘字队列（第一次投字时建出来）")
			庚.set("hp", 999999)
			for _n in 60:
				庚.call("take_damage", 1, 0.0, false)
			_check(队庚 != null and int(队庚.call("待放")) == 50,
					"连投 60 条只剩 50 条 —— 原版 `while (length > 50) shift()` 是**丢最旧**的；实得 %s 条"
					% str(int(队庚.call("待放")) if 队庚 != null else -1))
			_排空飘字(庚)
			庚.queue_free()

			# ── 玩家侧两档：暴击写「致命」（写在自己身上才叫致命，打在别人身上是「暴击」）──
			_清伤害数字(player)
			根.call("_播放玩家伤害数字", 100.0, 7, "致命")
			_排空飘字(player)
			_check(_最新伤害数字文本(player) == "致命  - 7",
					"玩家挨暴击 = 「致命␣␣- 7」（`DamageHandler.as:92-96`：打在**自己**身上用 FIGHT_ZHIMING）；"
					+ "实得「%s」" % _最新伤害数字文本(player))
			_清伤害数字(player)
			根.call("_播放玩家伤害数字", 100.0, 0, "")
			_排空飘字(player)
			_check(_最新伤害数字文本(player) == "我闪",
					"玩家闪开 = 「我闪」（`Character.as:1244-1250`）；实得「%s」" % _最新伤害数字文本(player))
			## `num == 0 且 tip 非空` ⇒ **只写 tip**，不带符号也不带 0
			## （`Monster.as:911-914`、`Character.as:1241`）—— 技能流水文字与连斩那一档走这里。
			_清伤害数字(player)
			根.call("_播放玩家伤害数字", 100.0, 0, "连斩")
			_排空飘字(player)
			_check(_最新伤害数字文本(player) == "连斩",
					"数值 0 而前缀非空 ⇒ 只写前缀（不带「- 0」）；实得「%s」" % _最新伤害数字文本(player))
			## 跳着闪开写「跳闪」（`Character.as:1246-1250` 那一句 `movementAction == JUMP`）。
			## 我们这边对应 `玩家.on_ground == false` ⇒ 把它扳倒再喂，量的是同一条映射。
			var 落地前 = player.get("on_ground")
			player.set("on_ground", false)
			_清伤害数字(player)
			根.call("_播放玩家伤害数字", 100.0, 0, "")
			_排空飘字(player)
			_check(_最新伤害数字文本(player) == "跳闪",
					"在半空闪开 = 「跳闪」（FIGHT_AVD_JUMP）；实得「%s」" % _最新伤害数字文本(player))
			player.set("on_ground", 落地前)
			_check(_最新伤害数字颜色(player) == Color(0.0, 1.0, 0.0),
					"「我闪」玩家侧是**绿** 65280（`Character.as:584-586`，跟怪侧那个蓝不是一档）；实得 %s"
					% str(_最新伤害数字颜色(player)))

			# ── 打坐涨一层心法 ⇒ 头顶一行「X熟练度  + 1」蓝字 ─────────────────────────
			# 真值 `DataCenter.as:1578-1588`：**同一个 `if` 里两件事** ——
			#   头顶 `player_addAttriChangeTip(SKILL_SHU_LIAN_DU 填技能名, 层差, true, CocoStatType.ZQ)`
			#   右下角 `addNotice(PROM_XINFA_GET 填(名, 层差))`
			# ⚠ 喂的是**数据层入口** `_apply_skill`（= 39 帧解析器 `后端连接.gd:2310` 调的那一句），
			#   不是 `emit_signal` ⇒ "认心法 → 算层差 → 发信号 → 挂到玩家身上"整条都跑到。
			#   "服务端那一拍确实发 39"这半截由 `测试/心法在线回归测试.gd` ④ 连真夹具钉。
			var 后 := root.get_node_or_null("/root/BackendConnection")
			if 后 == null:
				_fail("没有 BackendConnection ⇒ 心法熟练度飘字这条根本没跑到")
			else:
				var 心法号 := 1000			# 体能强化（`数据/界面/心法表.json` 21 条里的第一条）
				var 野号 := 1001001			# 普攻：技能表里真存在、但 `xinfa` 不为 1
				## `_apply_skill` 会经 `服务端会话同步.应用技能` 动会话里的技能表（第一条到达时
				## 还会 `learned_skills.clear()`）⇒ 先整份拍快照，跑完原样还回去，别污染后面的腿。
				var 快照 := {
					"已学": (session.learned_skills as Array).duplicate(true),
					"权威": (后.get("authoritative_skills") as Dictionary).duplicate(true),
					"收过技能帧": bool(session.server_skills_loaded),
				}
				var 收: Array[String] = []
				var 收提示 := func(文: String) -> void: 收.append(文)
				后.获得提示.connect(收提示)
				var 基准 := int(((后.get("authoritative_skills") as Dictionary).get(心法号, {}) as Dictionary).get("master_level", 0))
				## 第一次见到这条只登记基准、**不飘**（原版 `:1592` 对表里没有的那条只 push）
				_清伤害数字(player)
				后.call("_apply_skill", 心法号, 3, 基准)
				_排空飘字(player)
				_check(_数飘字(player) == 0, "第一次收到某条心法只登记基准、不飘字（原版 updateSkill 的 else 分支）")
				_清伤害数字(player)
				后.call("_apply_skill", 心法号, 3, 基准 + 1)
				_排空飘字(player)
				_check(_最新伤害数字文本(player) == "体能强化熟练度  + 1",
						"打坐涨一层 ⇒ 头顶「体能强化熟练度␣␣+ 1」（`SKILL_SHU_LIAN_DU` = `%1熟练度`、名与字之间**无空格**，"
						+ "再接 `Character.as:1235` 那个「两个空格 + 符号 + 一个空格 + 数字」式；实得「%s」"
						% _最新伤害数字文本(player))
				_check(_最新伤害数字颜色(player) == Color(0.0, 0.6, 1.0),
						"这一行是 ZQ 档蓝 #0099FF（`Character.as:560-562` 的 39423），不是精华那档的淡蓝；实得 %s"
						% str(_最新伤害数字颜色(player)))
				## 落点：`伤害数字.播放()` 的 `_起点y = -锚点 + 12`，锚点 = **当前帧贴图高**
				## （`Character.as:1220` 那一套）。锚点取不到就是 0 ⇒ 字会掉到脚下面去，
				## 所以参照物（精灵当前帧高度）要**单独钉一次**，不然"y<0 恒真"是假绿。
				var 玩精 = player.get("player_sprite")
				var 精灵高 := 0.0
				if 玩精 != null and (玩精 as Node).has_method("当前贴图高度"):
					精灵高 = float((玩精 as Node).call("当前贴图高度"))
				_check(精灵高 > 0.0, "参照物取到了：玩家精灵当前帧高 %.1f（锚点就是它）" % 精灵高)
				var 那枚 := _最新伤害数字(player) as Node2D
				_check(那枚 != null and 那枚.position.y < 0.0,
						"那行字挂在**头顶**（position.y = %s，负 = 原点之上）；锚点取不到会掉到脚下"
								% str(那枚.position.y if 那枚 != null else 999.0))
				## ⭐ **寿命 = 两段各 0.6 秒、总共 1.2 秒**（`Character.as:1277-1290` 第一段
				## → `onFinishTipUpTween:817-825` 第二段 → `onFinishTipDownTween:1603-1607` 只 removeChild）。
				## 每段里 y 与 alpha 是**同一个 TweenLite.to 的两个键**（同时动）。原来我们写成三段
				## chain（上浮→回落→**停在原地**淡出）= 1.8 秒，最后那 0.6 秒字不动 ⇒ 用户 10-14
				## 说的"看着突兀"。这两条钉住"1.0 秒还在、1.45 秒必须没了"。
				if 那枚 != null:
					await create_timer(1.0).timeout
					_check(is_instance_valid(那枚), "飘字活到 1.0 秒（第一段 0.6 + 第二段进行中）")
					await create_timer(0.45).timeout
					_check(not is_instance_valid(那枚),
							"飘字在 1.45 秒前就该消失（原版总共两段 = 1.2 秒；多出来的一段会让字停在原地淡出）")
				_check(收.size() == 1
						and 收[0] == "[color=#00cc33]体能强化心法熟练度 [color=#f0dd06]+1[/color][/color]",
						"右下角那一行**同时**出（`PROM_XINFA_GET` 原样翻成 BBCode，`+` 是模板里写死的）；实得 %s" % str(收))
				## 掉层不飘：原版这里只有 `层差 > 0` 一个判断（属性那一族"增减都飘"的写法不适用于它）
				收.clear()
				_清伤害数字(player)
				后.call("_apply_skill", 心法号, 3, 基准)
				_排空飘字(player)
				_check(_数飘字(player) == 0 and 收.is_empty(), "熟练度掉层 ⇒ 头顶与右下角都不出（`if(_loc3_ > 0)`）")
				## 非心法涨层 ⇒ 两处都不出（`SkillDataTool.isSkillXinfa()` 为假）
				收.clear()
				_清伤害数字(player)
				后.call("_apply_skill", 野号, 3, 99)
				后.call("_apply_skill", 野号, 3, 100)
				_排空飘字(player)
				_check(_数飘字(player) == 0 and 收.is_empty(),
						"非心法（%d = 普攻，技能表里真在、但 `xinfa` 不为 1）涨层不出字也不出提示" % 野号)
				后.获得提示.disconnect(收提示)
				_清伤害数字(player)
				session.learned_skills.assign(快照["已学"] as Array)
				(后.get("authoritative_skills") as Dictionary).clear()
				(后.get("authoritative_skills") as Dictionary).merge(快照["权威"] as Dictionary)
				session.server_skills_loaded = bool(快照["收过技能帧"])

			# ── 属性帧那一族的头顶飘字（#175 剩下的那半：规则表以前是**死表**）──────────
			# 喂的是真帧入口 `_handle_stats_text`（= 42 那条的解析器），字段号 = `CocoStatType.as`。
			# 挑的几档全是"两条最容易写反的"（规则表表头那两条）：HP 只增、
			# **MP 不吃进游戏 5 秒那个抑制**、攻防六档共用同一个黄、罪恶值字段号是 33 不是 26。
			if 后 != null and is_instance_valid(player):
				var 属性快照: Dictionary = (session.player_stats as Dictionary).duplicate(true)
				var 初更新前 := bool(后.get("_初更新"))
				var 头顶: Array = []
				var 收头顶 := func(前缀: String, 数: int, 增: bool, 色: Color) -> void:
					头顶.append([前缀, 数, 增, 色])
				后.属性飘字.connect(收头顶)
				var 帧 := func(体: String) -> void: 后.call("_handle_stats_text", PackedStringArray(["42", 体]))
				## ① 进游戏 5 秒内：HP 不飘、**查克拉照飘**（`DataCenter.as:2485-2490` 那一档漏了判断）
				后.set("_初更新", true)
				帧.call("6&500@7&300@16&300@33&0@26&0")	# 打底：第一帧只记基准，两处都不出
				_check(头顶.is_empty(), "属性帧第一帧只记基准、不飘字（原版每档最后那句赋值在判断之外）")
				头顶.clear()
				帧.call("6&560@7&360")
				_check(头顶.size() == 1 and String(头顶[0][0]) == "查克拉" and int(头顶[0][1]) == 60,
						"进游戏 5 秒内：生命值不飘、**查克拉照飘**（两档唯一的差别就是这个判断）；实得 %s" % str(头顶))
				## ② 过了 5 秒：HP 只增、攻防都飘、颜色各归各档
				后.set("_初更新", false)
				头顶.clear()
				帧.call("6&500")
				_check(头顶.is_empty(), "生命值**变少不飘**（`:2460-2463` 只有 `> 0`；掉血那两档归 DamageHandler）")
				_清伤害数字(player)
				头顶.clear()
				帧.call("6&600")
				_check(头顶.size() == 1 and String(头顶[0][0]) == "生命值" and bool(头顶[0][2])
						and 头顶[0][3] == Color(1.0, 0.6, 0.0),
						"生命值变多 ⇒ 飘「生命值 + 100」橙（HP 档 16737792）；实得 %s" % str(头顶))
				## ⭐ **满血不该飘**：服务端脱战回血那支是 `min(上限, 当前+5%)`，
				##   只有"跟当前不一样"才发帧（`fake_flash_server.py:35705-35714`）⇒ 到顶之后
				##   客户端根本收不到 hp 帧。这里把**同一个值再喂一遍**，钉住"差 0 ⇒ 不飘"这一判
				##   （用户 10-14 问的就是"血满了怎么还飘"—— 飘是因为那一趟血没满，在回血途中）。
				头顶.clear()
				帧.call("6&600@7&360")
				_check(头顶.is_empty(), "血/蓝**没变**（再喂同一个值）⇒ 一处都不飘；实得 %s" % str(头顶))
				_排空飘字(player)
				_check(_最新伤害数字文本(player) == "生命值  + 100",
						"落到玩家身上那枚的文本 = 前缀 + 两个空格 + 符号 + 一个空格 + 数字"
								+ "（`Character.as:1235`）；实得「%s」" % _最新伤害数字文本(player))
				_清伤害数字(player)
				头顶.clear()
				帧.call("16&295")
				_check(头顶.size() == 1 and String(头顶[0][0]) == "攻击" and int(头顶[0][1]) == 5
						and not bool(头顶[0][2]) and 头顶[0][3] == Color(1.0, 1.0, 0.0),
						"攻击**变少也飘**、数值传绝对值 + 方向位、颜色是默认黄（ATK 档不在颜色 switch 里）；实得 %s" % str(头顶))
				## ③ 罪恶值：字段号 33（26 是 FAME 声望，原版 `updateOneStatu` 根本没那一档）
				头顶.clear()
				帧.call("33&12")
				_check(头顶.size() == 1 and String(头顶[0][0]) == "罪恶值",
						"罪恶值 = 字段号 **33**（`CocoStatType.as:70`）该飘；实得 %s" % str(头顶))
				头顶.clear()
				帧.call("26&9")
				_check(头顶.is_empty(),
						"字段号 26 = FAME（声望）原版**没有这一档** ⇒ 不许飘（规则表原来把它当成罪恶值，10-14 接生产者时改回 33）")
				后.属性飘字.disconnect(收头顶)
				_清伤害数字(player)
				session.player_stats.merge(属性快照, true)
				后.set("_初更新", 初更新前)
			## 接线腿：`_攻击伤害` 到底有没有把 暴击/闪避 两位传下去 —— 这两件是骰子，只能**统计**着验。
			## 拿一枚数据里真实存在、`critical` 顶到夹的怪（`5300152` 咒印突变土蛊 = 507，
			## 被 `战斗率上限=500/1000` 夹成 50%）跑 120 次：一条都不出的概率 0.5^120 ≈ 1e-36。
			## ⚠ 第一版选的是 `5400283`（164 层 boss，暴击 41000）—— 门当场红，因为它的攻击力
			##    把玩家打死了，复活一重建属性，`dodge` 就被抹回原值 ⇒ 闪避那条腿再也掷不出来。
			##    所以夹具要**同时**满足：暴击够顶、攻击别太离谱、血量每轮重新喂满。
			## ⚠ 也不能拿"本图最高的那只"跑：现查本图最高只有 57 ⇒ 120 次里一条不出的概率 0.0085，
			##    看着小，但那是"噪声不是缺陷"的红，门一抖就说不清（也是第一版踩过的）。
			session.player_stats["dodge"] = 0
			session.player_stats["hp"] = 100000000
			var 乙 := _造怪(根, "5300152")
			var 见过致命 := false
			for _次 in 120:
				乙.call("结算对玩家伤害", player)
				_排空飘字(player)
				if _最新伤害数字文本(player).begins_with("致命"):
					见过致命 = true
					break
			_check(见过致命, "高暴击怪打 120 次里至少该出一条「致命」—— 一条都没有 ⇒ 暴击位没接到「致命」那一档")
			session.player_stats["dodge"] = 100000
			session.player_stats["hp"] = 100000000
			var 见过我闪 := false
			for _次 in 120:
				乙.call("结算对玩家伤害", player)
				_排空飘字(player)
				if _最新伤害数字文本(player) == "我闪":
					见过我闪 = true
					break
			_check(见过我闪, "闪避值拉满后打 120 次里至少该出一条「我闪」—— 一条都没有 ⇒ 闪开那支还在被 return 掉")
			session.player_stats = 存档

			# ── 震屏：`Earthquake.as` 的拍子 ────────────────────────────────
			## ⚠ 键的**方向**先钉死（这一条是用户实机打回才发现的）：
			## 原版那枚框是 `hideZhenPingCheckBox.selected = SysCfg.forbidEarthQuake`
			## （`SystemConfigWindow.as:444`，而 `SysCfg.as:30` 默认 `true` ⇒ **起步勾着、不抖**）。
			## 本工程的键 `screen_shake` 是同族 `show_*` 那套「正向能力」口径
			## （生成器里 `写=false` ⇒ 勾上「遮罩」写 false）⇒ **真值 = 真才抖**。
			## 我第一版照 forbid 读，整个反了：勾着反倒抖、取消反倒不抖（用户 2026-10-11 报「暴击了但没有震动」）。
			var 相机 := (load("res://脚本/地图/世界相机.gd") as GDScript).new() as Camera2D
			根.add_child(相机)
			await process_frame
			session.game_settings["screen_shake"] = false
			player.call("_震屏")
			_check(相机.offset == Vector2.ZERO,
					"「遮罩暴击操作的震屏特效」勾着（= 这个键 false）时什么都不该抖；实得 offset=%s"
					% str(相机.offset))
			## ⭐ 光比 `offset` 这一条**测不出闸有没有生效**：原版第一拍本来就延后 50ms，
			## 所以闸坏了（`_震屏` 不看设置直接 `震一下()`）时这一条照样绿 ——
			## 变异 M23 实测就是这个结果（2026-10-11）。加一条"喂一拍看它动没动 + 还剩几拍"才抓得住。
			相机.call("抖一拍", 0.05)
			_check(int(相机.get("_震剩余拍")) == 0 and 相机.offset == Vector2.ZERO,
					"勾着遮罩时喊震**根本没排上拍子**（剩余 0 拍、喂一拍也不动）；"
					+ "实得 剩余=%d 偏移=%s" % [int(相机.get("_震剩余拍")), str(相机.offset)])
			## ⭐ 起步（新号）默认必须**不抖** —— 这才是原版 `forbidEarthQuake = true` 的那份默认。
			## 只钉"值为 false 时不抖"不够：默认值本身写反时门还是绿的（就是这次的事故）。
			var 默认档: Dictionary = (load("res://脚本/单例/离线示例数据.gd") as GDScript)\
					.call("create").get("game_settings", {})
			_check(bool(默认档.get("screen_shake", true)) == false,
					"新号默认 `screen_shake` 必须是 false（= 那枚「遮罩暴击震屏」起步勾着 ⇒ 不抖，"
					+ "对齐 `SysCfg.as:30`）；实得 %s" % str(默认档.get("screen_shake", "(没有这个键)")))
			session.game_settings["screen_shake"] = true
			player.call("_震屏")
			_check(int(相机.get("_震剩余拍")) == 6,
					"拍数 = int(0.3*1000 / int(1000/20)) = 6；实得 %d 拍" % int(相机.get("_震剩余拍")))
			_check(相机.offset == Vector2.ZERO,
					"第一拍要等满 50ms 才响（`new Timer(50, 6)` 不在 0ms 触发）；刚喊完就动了 ⇒ 不对")
			var 抖过 := false
			var 全在界内 := true
			for _拍 in 6:
				相机.call("抖一拍", 0.05)
				var 偏: Vector2 = 相机.offset
				if 偏 != Vector2.ZERO:
					抖过 = true
				for 轴 in [偏.x, 偏.y]:
					if 轴 < -15.0 or 轴 > 14.0 or 轴 != floorf(轴):
						全在界内 = false
			_check(抖过, "六拍里至少要有拍真的动了（一次都没动 ⇒ 抖一拍根本没写 offset）")
			_check(全在界内, "每拍偏移必须是 [-15, 14] 区间里的**整数**（`Math.random()*30 - 15` 截成 int）")
			_check(相机.offset == Vector2.ZERO,
					"抖满 6 拍就复位（`TIMER_COMPLETE` → `resetImage()`）；实得 %s" % str(相机.offset))
			相机.call("震一下")
			相机.call("抖一拍", 0.05)
			相机.call("震一下")
			_check(int(相机.get("_震剩余拍")) == 6 and 相机.offset == Vector2.ZERO,
					"中途重触发要**先复位再重开**（`Earthquake.go():39-45`）；实得 剩余=%d 偏移=%s" % [
					int(相机.get("_震剩余拍")), str(相机.offset)])
			相机.call("抖一拍", 0.02)
			_check(相机.offset == Vector2.ZERO, "没攒满 50ms 不该换偏移（多攒的留给下一拍，不是每帧重掷）")
			## ⭐ **接线腿**：玩家打出一发暴击，真能把相机叫起来抖
			## （原版那句在结算循环之后：`AbstractSkillEffect.as:321-324`）。上面几条只证明了
			## "叫得起来"，这一条证的才是"谁去叫"。暴击是骰子 ⇒ 把 `critical` 顶到夹（50%）连打 60 下。
			相机.call("_震复位")			# 上一条重触发留了 6 拍没跑，不清就会白过
			session.game_settings["screen_shake"] = true
			session.player_stats["critical"] = 5000
			session.player_stats["attack"] = 1
			session.player_stats["hp"] = 100000000
			var 抖起来了 := false
			for _下 in 60:
				甲.set("hp", 100000)
				甲.set("alive", true)
				player.call("_结算一只", 甲, 0)
				if int(相机.get("_震剩余拍")) > 0:
					抖起来了 = true
					break
			_check(抖起来了,
					"玩家暴击应当把相机叫起来抖（`玩家._结算一只` 里那一句）—— 60 下都没抖 ⇒ 触发点没接上")
			session.player_stats = 存档
						## ★★ **在线那一档**（伤害由服务端算、184 出手帧回来）整条以前是漏的：
			## 震屏与击飞的判据都挂在离线的 `take_damage` / `_结算一只` 上 ⇒ 用户连着本地服务端
			## 就"暴击了但没有震动"（2026-10-11 实机打回）。这里喂的就是 184 解析出来的那六位入参。
			var 号 := 777001
			var 表 = 根.get("_entities_by_object")
			表[号] = 甲
			根.set("_entities_by_object", 表)
			甲.set("entity_id", String(怪.get("entity_id")))	# 上面那腿把它换成过 boss，先换回来
			甲.set("authoritative", true)						# 在线的怪全是权威怪
			甲.set("hp", 100000)
			甲.set("alive", true)
			甲.set("_飞着", false)
			session.game_settings["screen_shake"] = true
			相机.call("_震复位")
			根.call("_on_server_monster_damaged", 号, 120, true, true, true, true)
			_排空飘字(甲)
			_check(int(相机.get("_震剩余拍")) > 0,
					"在线出手帧里的暴击也要把相机叫起来抖（`由自己打出` 那一位）—— 没排拍子就是又漏了")
			## 这一发的 `打完还活着` = true ⇒ 只该震、**不该飞**（原版击飞条件带 `!damage.alive`）。
			## 少了这条，`not 打完还活着` 写反或 alive 位读成恒假时，在线每一发暴击都会把活怪打飞，
			## 而门还是绿的（2026-10-11 服务端那条文本位真是 `str(hp>0).lower()`，`int()` 一解就恒假）。
			_check(not bool(甲.get("_飞着")),
					"在线暴击但 184 报『还活着』⇒ 不许击飞（打死了才飞）；实得 _飞着=%s" % str(bool(甲.get("_飞着"))))
			甲.set("_飞着", false)

			_check(_最新伤害数字文本(甲).begins_with("暴击"),
					"在线那一档飘的字也要带「暴击」前缀；实得「%s」" % _最新伤害数字文本(甲))
			相机.call("_震复位")
			session.game_settings["screen_shake"] = false
			根.call("_on_server_monster_damaged", 号, 120, true, true, true, true)
			_排空飘字(甲)
			_check(int(相机.get("_震剩余拍")) == 0,
					"勾着「遮罩暴击震屏」那枚时，在线这一条也不许抖（闸要对两条腿都管用）")
			## 反过来：闸开着、但这一发**不是我自己打出的**（`由自己打出` = false ⇒ 怪互相打、或别人打的）
			## 也不该抖（原版 `isEarthquake && 是玩家自己打出的` 是两个条件与起来的，`AbstractSkillEffect.as:321-324`）。
			session.game_settings["screen_shake"] = true
			相机.call("_震复位")
			根.call("_on_server_monster_damaged", 号, 120, true, true, false, true)
			_check(int(相机.get("_震剩余拍")) == 0,
					"暴击但『不是自己打出的』不该震屏（少了这条，把 `由自己打出` 写死成 true 门也照样绿）")

			session.game_settings["screen_shake"] = true
			## 击飞：184 的 `alive` 位 = 0（这包打完它不活着了）且是暴击 ⇒ 在线也要飞
			甲.set("alive", true)
			甲.set("_飞着", false)
			根.call("_on_server_monster_damaged", 号, 999, true, true, true, false)
			_check(bool(甲.get("_飞着")),
					"在线暴击致死也要把它打飞（`apply_server_damage` 那一支以前根本不碰飞）")
			_check(absf((甲.get("_飞速度") as Vector2).x) == 3000.0,
					"在线那一档的起飞速度也得是 3000（与离线同一个 `_起飞`）；实得 %s"
					% str(甲.get("_飞速度")))
			甲.set("_飞着", false)
			甲.set("alive", true)
			根.call("_on_server_monster_damaged", 号, 999, false, true, true, false)
			_check(not bool(甲.get("_飞着")),
					"在线**不暴击**致死不该飞（原版条件带 `param1.bsk`）")
			表 = 根.get("_entities_by_object")
			表.erase(号)
			根.set("_entities_by_object", 表)
			## ★★ 在线「我挨打」那一档的真值是 `DamageHandler.as:38 addDamage()`（服务端 194 帧）。
			## 这条帧**自带暴击位**（服务端发 `int(critical)`，我们解析成 `hit_flag`），而且 `damage<=0`
			## 那一支照样调 `player_addAttriChangeTip("",0,...)`（`:130-133`）⇒ 身上飘「我闪」。
			## 以前这里按 243（只有两个 int 的包）的口径写成"在线没有暴击位、0 伤害不飘" ⇒
			## 在线挨暴击只有红字没有「致命」、被反弹打成 0 伤害一声不响（2026-10-11 对着 194 字段序改回）。
			var 后端 = 根.get("_backend")
			if 后端 != null:
				var 原角 := int(后端.get("character_id"))
				var 我的号 := 777002
				后端.set("character_id", 我的号)
				_清伤害数字(player)
				根.call("_on_server_player_damaged", {"character_id": 我的号, "damage": 300, "hit_flag": 1})
				_排空飘字(player)
				_check(_最新伤害数字文本(player).begins_with("致命") and _最新伤害数字文本(player).contains("- 300"),
						"在线挨暴击要写「致命  - 300」（`DamageHandler.as:92-96`，暴击位在 194 的 hit_flag）；实得「%s」" % _最新伤害数字文本(player))
				_清伤害数字(player)
				根.call("_on_server_player_damaged", {"character_id": 我的号, "damage": 300, "hit_flag": 0})
				_排空飘字(player)
				_check(not _最新伤害数字文本(player).begins_with("致命") and _最新伤害数字文本(player).contains("- 300"),
						"hit_flag=0 那一发只该是普通红字，不许蹭「致命」；实得「%s」" % _最新伤害数字文本(player))
				_清伤害数字(player)
				根.call("_on_server_player_damaged", {"character_id": 我的号, "damage": 0, "hit_flag": 0})
				_排空飘字(player)
				var 闪字 := _最新伤害数字文本(player)
				_check(闪字 == "我闪" or 闪字 == "跳闪",
						"在线 0 伤害那一帧也要飘字（原版 `:130-133` 照旧调 tip）⇒「我闪」/「跳闪」；实得「%s」" % 闪字)
				_check(_最新伤害数字颜色(player) == Color(0.0, 1.0, 0.0),
						"玩家侧那一档闪避盖的是绿 65280（`Character.as:584-586`），不是怪侧的蓝 255；实得 %s" % str(_最新伤害数字颜色(player)))
				_清伤害数字(player)
				根.call("_on_server_player_damaged", {"character_id": 我的号, "damage": 0, "hit_flag": 1})
				_排空飘字(player)
				_check(_最新伤害数字文本(player) == "我闪" or _最新伤害数字文本(player) == "跳闪",
						"damage<=0 时原版走 else 那一支 ⇒ 就算 hit_flag=1 也不写「致命」；实得「%s」" % _最新伤害数字文本(player))
				_清伤害数字(player)
				根.call("_on_server_player_damaged", {"character_id": 我的号 + 1, "damage": 300, "hit_flag": 1})
				_排空飘字(player)
				_check(_最新伤害数字(player) == null, "194 的 character_id 不是本人 ⇒ 一个字都不该飘（别的玩家挨打不落在自己身上）")
				_清伤害数字(player)
				## ── 194 的**克制提示**（#197）：怪用「五行封印」打你 ⇒ 你身上要飘「五行解印」──
				## 原版 `DamageHandler.as:107-113`：`skillTrigger` 为 false 时，在伤害那条之后**再追加一条**
				## `player_addAttriChangeTip(流水字, 0, true, CocoStatType.SKILL)`；
				## 流水字 = 本技能的 `info.desc.oppositeSkill` 那条技能的 `name`
				## （`AbstractSkillEffect.as:501-510` + `SkillDataTool.as:731-735` + `StringTool.as:114-119`）。
				## 现查这台服务端：`status_triggered` 初值就是 False（`fake_flash_server.py:36937`）
				## ⇒ 在线真看得到，不是接了段永不触发的代码。
				_清伤害数字(player)
				根.call("_on_server_player_damaged", {"character_id": 我的号, "damage": 300, "hit_flag": 0,
						"skill_trigger": false, "skill_id": 2001})
				_排空飘字(player)
				_check(_最新伤害数字文本(player) == "五行解印",
						"194 的 skillTrigger=false ⇒ 伤害那条之后还要飘一条克制提示「五行解印」；实得「%s」"
						% _最新伤害数字文本(player))
				_check(_最新伤害数字颜色(player) == Color(50.0 / 255.0, 153.0 / 255.0, 1.0),
						"克制提示是 `CocoStatType.SKILL` 那档蓝（`Character.as:580-582` = 3316223 = #3299FF），"
						+ "不是挨打的红；实得 %s" % str(_最新伤害数字颜色(player)))
				_check(_数飘字(player) >= 2,
						"伤害那条红字还在 —— 克制提示是**追加**一条，不是把伤害那条顶掉；实得 %d 条"
						% _数飘字(player))
				## 反向对照一：`skillTrigger=true`（这发的状态效果真生效了）⇒ 原版那一支整个不进
				_清伤害数字(player)
				根.call("_on_server_player_damaged", {"character_id": 我的号, "damage": 300, "hit_flag": 0,
						"skill_trigger": true, "skill_id": 2001})
				_排空飘字(player)
				_check(_最新伤害数字文本(player) == "  - 300" and _数飘字(player) == 1,
						"skillTrigger=true 不该飘克制提示（原版 `if(!param1.skillTrigger)`）；"
						+ "实得「%s」共 %d 条" % [_最新伤害数字文本(player), _数飘字(player)])
				## 反向对照二：这招没有对手技（本图那两只小怪用的 8000 就没有）⇒ 不飘
				_清伤害数字(player)
				根.call("_on_server_player_damaged", {"character_id": 我的号, "damage": 300, "hit_flag": 0,
						"skill_trigger": false, "skill_id": 8000})
				_排空飘字(player)
				_check(_最新伤害数字文本(player) == "  - 300" and _数飘字(player) == 1,
						"没有 oppositeSkill 的技能不该飘克制提示（原版 `if(_loc13_)` 判的是非空串）；"
						+ "实得「%s」共 %d 条" % [_最新伤害数字文本(player), _数飘字(player)])
				## 反向对照三：`damage<=0` 那一发原版走 else 支（飘「我闪」），**不配**克制提示
				_清伤害数字(player)
				根.call("_on_server_player_damaged", {"character_id": 我的号, "damage": 0, "hit_flag": 0,
						"skill_trigger": false, "skill_id": 2001})
				_排空飘字(player)
				_check((_最新伤害数字文本(player) == "我闪" or _最新伤害数字文本(player) == "跳闪")
						and _数飘字(player) == 1,
						"0 伤害那一发只飘「我闪」，不该把克制提示挤出来；实得「%s」共 %d 条"
						% [_最新伤害数字文本(player), _数飘字(player)])
				## 数据侧明账：表非空 + 取法对（防"哪天表被清空了，上面几条还全绿"）
				_check(String(GAME_DATA.skill_flow_text(2001)) == "五行解印",
						"`skill_flow_text(2001)` 该查到「五行解印」（数据 `数据/技能对手技.json`）；"
						+ "实得「%s」" % String(GAME_DATA.skill_flow_text(2001)))
				_check(GAME_DATA.取表("技能对手技").size() >= 14,
						"克制提示表该有 14 条（现查 GameData：oppositeSkill 非零 15 条，其中 1 条在文案表里查不到名字"
						+ " ⇒ 原版也不飘）；实得 %d 条" % GAME_DATA.取表("技能对手技").size())

				后端.set("character_id", 原角)
			甲.set("authoritative", false)
			甲.set("_飞着", false)
			甲.set("alive", true)
			甲.set("hp", 100000)
			相机.call("_震复位")
			相机.queue_free()
			session.game_settings["screen_shake"] = bool(original_settings.get("screen_shake", false))

			# ── 击飞：只有「暴击 + 打死 + 不是 boss」才飞（`AbstractSkillEffect.as:245-274`）──
			var 丙 := _造怪(根, String(怪.get("entity_id")))
			_check(not bool(丙.call("_是boss")),
					"这只夹具怪应当不是 boss（是 boss 的话下面两条飞/不飞的腿都白测）")
			丙.set("hp", 5)
			丙.call("take_damage", 50, 1.0, false)
			_check(not bool(丙.get("_飞着")),
					"普通伤害打死**不该飞** —— 原版那个分支的条件里带 `param1.bsk`")
			var 丁 := _造怪(根, String(怪.get("entity_id")))
			丁.set("hp", 5)
			丁.call("take_damage", 50, 1.0, true)
			_check(bool(丁.get("_飞着")), "暴击打死 ⇒ 起飞（原版 `isHitAway=true` + 给速度）")
			var 飞: Vector2 = 丁.get("_飞速度")
			_check(飞 == Vector2(3000.0, -2000.0),
					"起飞速度 = (打者在左 ⇒ +3000, −2000)（`AbstractSkillEffect.as:255-271`）；实得 %s"
					% str(飞))
			var 位前: Vector2 = 丁.position
			丁.call("_飞一拍", 0.1)
			var 位移: Vector2 = 丁.position - 位前
			_check(absf(位移.x - 300.0) < 0.01 and absf(位移.y + 180.0) < 0.01,
					"喂 0.1 秒 ⇒ vy = min(-2000 + 2000*0.1, 670) = -1800 ⇒ 位移 (300, -180)；实得 %s"
					% str(位移))
			for _拍 in 200:
				丁.call("_飞一拍", 0.1)
			_check(absf((丁.get("_飞速度") as Vector2).y - 670.0) < 0.001,
					"竖直速度最终被 `FALL_SPEED = 670` 夹住（`AbstractPhysicObject.as:105-106`）；实得 %f"
					% (丁.get("_飞速度") as Vector2).y)
			## ⭐ 上面那些是**手动喂拍**量的算式；这一条量"谁来喂"—— 真跑帧，怪得自己动。
			##    少了 `_process` 里那一句，飞不起来的就是玩家肉眼看到的那一段抛物线。
			## ⚠ 用 `process_frame` 不用 `physics_frame`：这条门跑在 `extends SceneTree` 的无头脚本里，
			##    实测 `await physics_frame` 会把整趟卡死（物理帧在这个壳里不等我们）。
			var 起飞位: Vector2 = 丁.position
			for _帧 in 8:
				await process_frame
			_check(丁.position != 起飞位,
					"飞着的怪每帧自己积分位移（`_process` 里 `_飞着` 那一支）—— 8 帧过去还钉在原地 ⇒ 抛物线不会动")
			## 打者的**位置**决定飞的方向：原版拿 `打者.x > 怪.x ? -3000 : +3000`，
			## 我们传的是打者的朝向（朝右 ⇒ 怪在右边 ⇒ 往右推）。两个方向都要落到速度上。
			var 戊 := _造怪(根, String(怪.get("entity_id")))
			戊.set("hp", 5)
			戊.call("take_damage", 50, -1.0, true)
			_check((戊.get("_飞速度") as Vector2).x == -3000.0,
					"打者朝左 ⇒ 怪往左飞（-3000）；实得 %s" % str((戊.get("_飞速度") as Vector2)))
			## boss 那一支：原版条件带 `!monster.mobInfo.boss` ⇒ **boss 挨暴击致死也不飞**。
			var 己 := _造怪(根, "2000001")		# 数据里 boss=2 的一枚
			_check(bool(己.call("_是boss")), "夹具怪 2000001 得真是 boss，否则这条腿是空的")
			己.set("hp", 5)
			己.call("take_damage", 50, 1.0, true)
			_check(not bool(己.get("_飞着")), "boss 暴击致死**不飞**（原版 `!monster.mobInfo.boss`）")
			# 夹具怪都是 `根`（LifeRoot）的子节点，末尾 `scene.queue_free()` 一并收掉；
			# 这里不主动 free —— 死掉那几只的 `_die()` 还挂在计时器上等回调，先 free 会撞
			# "已释放实例上继续执行"。

	scene.queue_free()
	session.hud_state = original_hud
	session.hang_state = original_hang
	session.game_settings = original_settings
	session.settings_changed.emit(session.game_settings.duplicate(true))
	session.call("_save_local_state")
	_finish()

## 读出挂在某个节点下的**最后一条**伤害数字文案 / 它的颜色。
## ⚠ 必须是"最后一条"：这些件是 `add_child` 追加的，而上一版取的是**第一条** ——
##    于是"暴击那条"实际一直在比上一次打的旧文案，判据形同虚设（2026-10-11 踩过）。
## 判"数字长什么样"必须读实际文案与颜色：本工程那几处毛病（掉血飘「+N」、漏前缀「暴击」、
## 闪避不飘字、未命中颜色）在"有没有放出来"这种判据下永远是绿的 —— 存在 ≠ 对。
func _最新伤害数字(谁: Node) -> Node:
	if 谁 == null:
		return null
	var 最新: Node = null
	for 子 in 谁.get_children():
		if 子.get_script() != null and String((子.get_script() as Script).resource_path).contains("伤害数字"):
			最新 = 子
	return 最新

func _最新伤害数字文本(谁: Node) -> String:
	var 件 := _最新伤害数字(谁)
	if 件 == null:
		return ""
	var 签 = 件.get("_标签")
	return (签 as Label).text if 签 is Label else ""

func _最新伤害数字颜色(谁: Node) -> Color:
	var 件 := _最新伤害数字(谁)
	if 件 == null:
		return Color(0.0, 0.0, 0.0, 0.0)		# 全透明 = 根本没有这条（跟任何真颜色都不相等）
	var 签 = 件.get("_标签")
	return (签 as Label).get_theme_color("font_color") if 签 is Label else Color(0.0, 0.0, 0.0, 0.0)

## 清掉某节点下所有伤害数字 —— 判"刚放出来的那一条"之前先清，免得旧的混进来。
## 先 `remove_child` 再 `queue_free`（直接 free 会撞"节点还在树上"）。
## 把某个角色身上排着的飘字**立刻放完**再读。
## 队列本身是原版节奏（每个角色每 400 毫秒才放一条，`Character.as:2591-2598`），
## 所以"投进去 → 马上读"读不到 —— 不排空就会读到空串（2026-10-11 接完队列 21 条红全是这个）。
## 节奏对不对另有两条专门的判据在下面（"连投三条只先放第一条" + "上限 50 丢最旧"）。
## 数一数这个角色身上现在挂着几条飘字（判"流水字是**追加**一条、不是替掉伤害那条"用）。
func _数飘字(谁: Node) -> int:
	if 谁 == null or not is_instance_valid(谁):
		return 0
	var 条 := 0
	for 子 in 谁.get_children():
		if 子.get_script() != null and String((子.get_script() as Script).resource_path).contains("伤害数字"):
			条 += 1
	return 条

func _排空飘字(谁: Node) -> void:
	if 谁 == null or not is_instance_valid(谁):
		return
	var 队 = 谁.get_node_or_null("飘字队列")
	if 队 != null:
		队.call("全放")

func _清伤害数字(谁: Node) -> void:
	if 谁 == null:
		return
	for 子 in 谁.get_children():
		if 子.get_script() != null and String((子.get_script() as Script).resource_path).contains("伤害数字"):
			谁.remove_child(子)
			子.queue_free()

## 造一只**只用来量战斗表现**的怪：同一个真脚本 + 数据里真实存在的怪 id，
## 但不进 `_entities`、不建 AI、不建美术。为什么不用地图里那两只：
##   ① 打死真怪会触发场景的死亡/复活逻辑，后面的腿就在一具正在消失的节点上量；
##   ② 本图一共只有两只怪，而击飞要"非暴击死 / 暴击死 / boss 暴击死"各一只；
##   ③ 致命那轮要一枚 `critical` 顶到夹的怪（`5400283` = 41000），本图没有。
## `_是boss()` / `_僵直概率()` / `战斗结算.怪打玩家` 读的都还是**真数据**，所以走的仍是真代码。
func _造怪(宿主: Node, 怪id: String) -> Node2D:
	var 谁 := (load("res://脚本/角色/战斗角色.gd") as GDScript).new() as Node2D
	# 节点名要用 ASCII：烘焙过的场景带 `unique_id`，非 ASCII 的名字会刷
	# "The scene unique ID must contain only letters, numbers, and underscores."
	谁.name = "FixtureMob"
	宿主.add_child(谁)
	谁.set("kind", "m")
	谁.set("entity_id", 怪id)
	谁.set("alive", true)
	谁.set("hp", 100000)
	谁.set("max_hp", 100000)
	return 谁

## 头像下那颗战斗模式钮 = 原版 `CharactorInfoPane._pvpBtn`（`:433-471`）+ 四行菜单 `PKModePane2`。
## 这一腿盯三件以前**没有门钉**的事：① 按当前模式换**整张皮**（不是染色、不是永远同一张）；
## ② 点它是弹菜单，**不许**自己循环换档（以前 `_request_next_pk_mode` 的 `current % 4 + 1` 是自造）；
## ③ 菜单里点中某一行才发上行、发完菜单收掉。点击全部走真 `push_input`（`pressed.emit()` 会演绿）。
func _模式钮腿(scene: Node, session: Node) -> void:
	get_root().size = Vector2(960, 560)		# 无头默认 64×64，真鼠标点不到 64 之外的件
	var 钮 := scene.get_node_or_null("头像面板/头像区域/角色状态/StatusToggle") as TextureButton
	if 钮 == null:
		_fail("找不到头像下的战斗模式钮")
		return
	var 我数 := 0		## 这一腿自己数条数（末尾钉"判满 23 条"）：
	## 上一版拿全局 判数 做差，结果一条判据在已释放实例上调方法把协程打断，
	## 后面四条没跑而末行照样打"通过" ⇒ 条数必须由这一腿自己钉死。
	我数 += 1
	_check(钮.position == Vector2(0, 64), "模式钮应摆原版 (0,64)（CharactorInfoPane.as:466-467）")
	我数 += 1
	_check(钮.size == Vector2(23, 23), "模式钮应 23×23（元件 760/744/748/756 的天然尺寸）")
	我数 += 1
	_check(钮.texture_hover == null and 钮.texture_pressed == null,
		"三档都要换 texture_normal：填 hover/pressed 槽会让松手停在 hover，原版 mouseUpHandler 回 UP")
	我数 += 1
	_check(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "模式钮要手型光标（buttonMode）")
	我数 += 1
	_check(not 钮.toggle_mode, "模式钮不许是 toggle_mode（原版那颗没有按下保持态）")
	var 盘上齐 := true
	for 基 in ["模式_普通", "模式_组队", "模式_家族", "模式_全体"]:
		for 尾 in [".png", "_悬停.png", "_按下.png"]:
			if not FileAccess.file_exists("res://素材/界面/原版窗口/头像面板/%s%s" % [基, 尾]):
				盘上齐 = false
	我数 += 1
	_check(盘上齐, "四枚模式皮 × 三档共 12 张都要在盘上（FileAccess 直读，不信导入缓存）")
	var 皮名 := {4: "模式_全体.png", 2: "模式_组队.png", 3: "模式_家族.png", 1: "模式_普通.png"}
	for 档 in [4, 2, 3, 1]:
		session.request_pk_mode(档)
		await process_frame
		var 现 := String(钮.texture_normal.resource_path).get_file() if 钮.texture_normal != null else "(空)"
		我数 += 1
		_check(现 == String(皮名[档]), "模式 %d 应显示 %s，实际 %s" % [档, 皮名[档], 现])
	我数 += 1
	_check(钮.tooltip_text.find("点击后可更改PK模式") != -1,
		"tooltip 要用原文（CN.PVPBTN_* + CN.PK_MODE），不是自造的「战斗模式：X（点击切换）」")
	var 前 := int(session.hud_state.get("pk_mode", 0))
	await _真点钮(钮)
	await create_timer(0.1).timeout
	var 菜单 := scene.get_node_or_null("头像面板/头像区域/角色状态/PK模式菜单") as Control
	我数 += 1
	_check(菜单 != null, "点模式钮应弹出四行菜单（PKModePane2）")
	我数 += 1
	_check(int(session.hud_state.get("pk_mode", 0)) == 前, "只点钮**不许**自己换档（点前=%d 点后=%d）" % [前, int(session.hud_state.get("pk_mode", 0))])
	if 菜单 == null:
		return
	我数 += 1
	_check(菜单.position == Vector2(0, 87), "菜单摆面板局部 (0,87)（showPvpModeViewHandler:256-259）")
	我数 += 1
	_check(菜单.size == Vector2(390, 106), "菜单 390×106（PKModePane2.as:69-70）")
	我数 += 1
	_check(菜单.get_child_count() == 5, "菜单 = 黄底 + 四行，实际 %d 个直接子件" % 菜单.get_child_count())
	var 色表 := {1: Color(1, 0.941176, 0.0), 2: Color(0.117647, 0.564706, 1.0),
			3: Color(0, 1, 0), 4: Color(1, 0, 0)}
	var 齐 := true
	for 档 in [1, 2, 3, 4]:
		var 行 := 菜单.get_node_or_null("模式行%d" % 档) as Button
		if 行 == null or 行.size != Vector2(382, 25) or 行.position != Vector2(5, 5 + (档 - 1) * 25):
			齐 = false
			continue
		var 字 := 行.get_node_or_null("说明") as Label
		var 图 := 行.get_node_or_null("图标") as TextureRect
		var 线 := 行.get_node_or_null("分隔线") as TextureRect
		if 字 == null or 图 == null or 线 == null:
			齐 = false
		elif 图.size != Vector2(23, 23) or 线.size != Vector2(380, 2):
			齐 = false
		elif not 字.get_theme_color("font_color").is_equal_approx(色表[档]) or 字.text.length() < 20:
			齐 = false
	我数 += 1
	_check(齐, "四行逐件齐：行 382×25 摆 (5,5+25n)、图标 23×23、说明字色 #FFF000/#1E90FF/#00FF00/#FF0000、分隔线 380×2")
	## 说明字的**纵向**落点单独钉一条（上面那条只查颜色与文案）：原版摆的是 MLabel 组件 (23,0)，
	## 组件内 TextField 再往下 2（`MLabel.as:211-212`）+ Flash 文本框 2px 内边距 ⇒ 墨迹顶在行内 y=4。
	## 用户 10-25 实机看出的"文字偏上、应该在中间"就是这一格被摆成 0（实测墨迹中线比图标中线高 4 像素）。
	var 字位 := ""
	for 档 in [1, 2, 3, 4]:
		var 行 := 菜单.get_node_or_null("模式行%d" % 档) as Button
		var 字 := (行.get_node_or_null("说明") as Label) if 行 != null else null
		字位 += ("%s" % 字.position) if 字 != null else "缺"
	我数 += 1
	_check(字位 == "(23.0, 4.0)(23.0, 4.0)(23.0, 4.0)(23.0, 4.0)",
			"四行说明字都摆 (23,4)（组件 (23,0) + textField 内偏 2 + 文本框内边距 2）⇒ 实得 " + 字位)
	var 亮档 := 0
	for 档 in [1, 2, 3, 4]:
		var 行 := 菜单.get_node_or_null("模式行%d" % 档) as Button
		if 行 != null and (行.get_node("选中条") as CanvasItem).visible:
			亮档 = 档
	我数 += 1
	_check(亮档 == 前, "只有当前模式那一行亮选中条（setCheck:39-41），实际亮 %d、当前 %d" % [亮档, 前])
	## 悬停 → 移开那一档。10-25 在线第一跑逮到的真缺陷就坏在这里：
	## `项.set_meta("选中", …)` 的中文键在 Godot 4 里报 `Invalid metadata identifier`
	## 且**静默存不进去** ⇒ 移开后 `get_meta("选中", false)` 恒 false ⇒ 当前那一档的选中条
	## 再也亮不回来（画面缺陷 + 每次换档刷一串 ERROR）。上面那条只查"开出来那一刻"，照不到它。
	var 行四悬 := 菜单.get_node_or_null("模式行4") as Button
	var 行当悬 := 菜单.get_node_or_null("模式行%d" % 前) as Button
	if 行四悬 == null or 行当悬 == null:
		_check(false, "模式行4 / 当前档那一行取不到 ⇒ 悬停这两条等于没测")
		return
	await _真移到((行四悬 as Control).get_global_rect().get_center())
	我数 += 1
	_check((行四悬.get_node("选中条") as CanvasItem).visible,
			"真悬停「全体」那一行 ⇒ 它的选中条亮（overHandler:146-149）")
	await _真移到(Vector2(600, 300))
	我数 += 1
	_check((行当悬.get_node("选中条") as CanvasItem).visible
			and not (行四悬.get_node("选中条") as CanvasItem).visible,
			"真移开 ⇒ 亮回当前那一档、悬停那行灭（outHandler 回的是「是否选中」，不是一律隐藏）")
	## 上面那两条里 当前那一行**从头到尾没被压灭过**（0 比 0 照不到回落这一步）⇒ 第三条才咬人：
	## 悬停当前那一行再移开，走的正是 `outHandler` 的"回落到是否选中"。
	## 变异实测（把 `_悬停` 写成 `条.visible = 在`）：前两条照样绿、只有这一条红。
	await _真移到((行当悬 as Control).get_global_rect().get_center())
	await _真移到(Vector2(600, 300))
	我数 += 1
	_check((行当悬.get_node("选中条") as CanvasItem).visible,
			"悬停当前那一行再移开 ⇒ 它还亮着（选中态没丢；10-25 中文 meta 键那个坑就坏在这儿）")
	await _真点钮(菜单.get_node("模式行4") as Control)
	await create_timer(0.1).timeout
	## ⚠ `关()` 走的是 `queue_free`，一拍之后实例真被释放 ⇒ **不许再对它调方法**
	## （第一版写了 `菜单.get_parent() == null`，运行期报错把整条腿打断，
	## 后面四条判据一条没跑而末行照样打"通过"——这就是"判满 N 条"要钉的理由）。
	我数 += 1
	_check(not is_instance_valid(菜单), "点行之后菜单要收掉（实例已释放）")
	我数 += 1
	_check(int(session.hud_state.get("pk_mode", 0)) == 4, "点「全体」那一行才把模式发到 4")
	我数 += 1
	_check(String(钮.texture_normal.resource_path).get_file() == "模式_全体.png", "换档后钮皮跟着换成全体")
	## 阵营档（`OpenPvpMode.ZHENYING = 5`）：原版那个 switch **没有分支** ⇒ `_pvpBtn` 留 null =
	## 那颗钮根本不出现。服务端从不发 5，只能直接推一帧 hud_state 给消费者看（不发假包）。
	session.hud_state["pk_mode"] = 5
	session.hud_state_changed.emit(session.hud_state)
	await process_frame
	我数 += 1
	_check(not 钮.visible, "阵营档(5) 原版没有这一张皮 ⇒ 那颗钮不出现，不许拿别的档顶")
	session.hud_state["pk_mode"] = 1
	session.hud_state_changed.emit(session.hud_state)
	await process_frame
	我数 += 1
	_check(钮.visible, "回到普通档钮要重新出现")
	_check(我数 == 27, "模式钮这一腿要判满 27 条 ⇒ 少了就是中途被运行期报错打断（实际 %d）" % 我数)



## 真鼠标挪到一个点（只动不按）：`mouse_entered/mouse_exited` 要由视口拾取发，
## `emit_signal` 演出来的那两条不算数（悬停后移开那两条判据就靠它）。
func _真移到(点: Vector2) -> void:
	var 事 := InputEventMouseMotion.new()
	事.position = 点
	事.global_position = 点
	root.push_input(事)
	await process_frame
	await process_frame


## 真鼠标点一下（按下+松开各一帧）：`pressed.emit()` 只能证明信号接了，证明不了命中。
func _真点钮(件: Control) -> void:
	var 心 := 件.get_global_rect().get_center()
	for 按 in [true, false]:
		var 事 := InputEventMouseButton.new()
		事.button_index = MOUSE_BUTTON_LEFT
		事.pressed = 按
		事.position = 心
		事.global_position = 心
		root.push_input(事)
		await process_frame


func _check(condition: bool, message: String) -> void:
	判数 += 1
	if not condition:
		_fail(message)

## 原版规则（2026-09-27 按 AS3 改）：名字**贴在脚点下面**（`RoleNamePane` 把文字画在
## 自己原点上方，而三处窗口把它摆在 `paneHeight` 附近的正 y 上），而且**不跟动画帧走**。
func _check_nameplate_below_visual(actor: Node2D, sprite: Node2D, context: String) -> void:
	if actor == null or sprite == null:
		_fail(context + "缺少可用于姓名牌定位的动画精灵")
		return
	var visual := sprite as Sprite2D
	if visual == null:
		visual = sprite.get("sprite") as Sprite2D
	if visual == null or visual.texture == null:
		_fail(context + "缺少当前帧贴图")
		return
	var nameplate := actor.get_node_or_null("Nameplate") as Label
	if nameplate == null:
		_fail(context + "缺少姓名牌")
		return
	# 角色原点（脚点）在 actor 本地坐标里恒为 0，名字顶边必须落在脚点或其下方、且不超过一行。
	# ⚠️ 判据是"相对**角色原点**（脚点）"，不是"相对当前帧贴图的包围盒"：
	#    每帧的 origin 会变（注册点随帧位移），贴图底边跟着动，而名牌是常量。
	_check(nameplate.position.y >= 0.0, context + "姓名牌不应高过脚点")
	_check(nameplate.position.y <= 8.0, context + "姓名牌离脚点不应超过一行")
	var title := actor.get_node_or_null("NameplateTitle") as Label
	if title != null:
		_check(title.position.y >= nameplate.position.y + nameplate.get_theme_font("font").get_height(
				nameplate.get_theme_font_size("font_size")),
				context + "称号应在名字下面一行，且不与名字重叠")

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	门存档快照.全还原(_文件前)
	if _failures.is_empty():
		print("汇：判 %d 条 / 红 0 条（姓名、战斗模式与挂机回归测试：通过）" % 判数)
		quit(0)
	else:
		print("汇：判 %d 条 / 红 %d 条（姓名、战斗模式与挂机回归测试：失败）" % [判数, _failures.size()])
		quit(1)
