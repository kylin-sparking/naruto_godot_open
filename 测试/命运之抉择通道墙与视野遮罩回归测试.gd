extends SceneTree

## 命运之抉择（403000000）的两件事，缺一件玩家就会报"通道墙能穿 / 整张图黑得看不见路"：
##
## ① 通道隔断是**竖直脚点**。原版 `AbstractPhysicObject.checkFoothold():287-440` 有两类判据：
##    · 离地（`currFoothold == null`）时拿这一帧位移向量和竖直脚点求交（`:297-371`）：
##      `x = 交点.x ± 1`；只有 `vy > 0` 才清 `vx`（上升中撞墙保留水平速度）。
##    · ⚠ 竖直脚点是**单向墙**，不是"两边都挡"：`GVector.findIntersection():108-136` 的
##      `dotProduct(位移, 法线) < 0` 用的法线是 `(rx, ry) = (-vy_f, vx_f) = (y2-y1, 0)`
##      （`GVector.as:28-30/41-42` + `Foothold.as:66` 的 `p0=(x2,y2), p1=(x1,y1)`），
##      后面 `dotProduct(起点→p0, 法线) <= 0` 再卡一次起点单侧。净结果：
##      `y2 < y1` ⇒ 实体在右，只挡**向右**；`y1 < y2` ⇒ 实体在左，只挡**向左**。
##      两边都挡时，端面那十几像素的 y 带会把人贴住 —— 从平台底下跳起、从平台边跳出去
##      都会莫名一卡（用户 2026-10-31 报）。
##    · 站在地面脚点端头、链上的 `next` 是**上墙**（`y2 < y1`，`:404`）/ `prev` 是**下墙**
##      （`y1 < y2`，`:429`）就停在端头，置 `rightBlock/leftBlock`。
##    本工程以前两条都没搬 ⇒ 走出平台边那一帧 `find_foothold` 全表扫，直接落到隔壁通道的
##    平台上 —— 用户 2026-10-28 报的「各个通道之间的墙壁不应该可以通过」。
##
## ② 整图蜡烛视野。`World.tickCandleEffect():444-470` 只认 403000000：每帧取
##    `player.localToGlobal(new Point())`（屏幕坐标）抬 60（`World.as:461`）调
##    `MapCandleEffect.updateEffect()`。`MapCandleEffect.as` 画两笔：整舞台黑底挖 r=250 圆洞，
##    再在同一点叠 RADIAL 渐变 `alphas=[0,0.8,0.9,1]` / `ratios=[0,60,70,80]`。
##    ⚠ ratios 是 Flash 的 0..255 标度、渐变框是单位矩阵 ⇒ 半径 819.2，三档落在
##    192.75 / 224.88 / 257.00 像素（不是 60/70/80 像素）。
##
## 脚点数字一律抄烘焙场景的 `metadata/baked_segments`（真值是地图 JSON），不从被测代码取。

const 场景路径 := "res://场景/生成/地图_403000000_烘焙.tscn"
const 玩家脚本 := "res://脚本/角色/玩家.gd"
const 遮罩脚本 := "res://脚本/地图/视野遮罩.gd"
const 地图根脚本 := "res://脚本/地图/地图根节点.gd"

## 819.2 × 60/255、× 70/255、× 80/255。
const 停1 := 192.752941176471
const 停2 := 224.878431372549
const 停3 := 257.003921568627

var _失败: Array[String] = []
var _条数 := 0
var _已收尾 := false
var _超时 := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _process(delta: float) -> bool:
	if _已收尾:
		return false
	_超时 += delta
	if _超时 > 90.0:
		printerr("命运之抉择通道墙与视野遮罩回归测试：超时 90 秒，判红")
		quit(1)
		return true
	return false


func _断言(成立: bool, 说明: String) -> void:
	_条数 += 1
	if not 成立:
		_失败.append(说明)


## 取 `起` 到 `止` 之间的源码（`止` 找不到就取到文末）。
func _截段(文: String, 起: String, 止: String) -> String:
	var a := 文.find(起)
	if a < 0:
		return ""
	var b := 文.find(止, a + 起.length())
	return 文.substr(a, b - a) if b > 0 else 文.substr(a)


func _run() -> void:
	## 烘焙场景的 `map_id` 在 `_ready` 里从 GameSession.current_map_id 拿（`地图根节点.gd:101`），
	## 不先设就会按默认图载脚点。
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 == null:
		_断言(false, "没有 GameSession 自动加载，本门无法进图")
		_finish()
		return
	会话.set("current_map_id", "403000000")

	var 场景包 := load(场景路径) as PackedScene
	if 场景包 == null:
		_断言(false, "403000000 的可玩场景不在盘上")
		_finish()
		return
	var 场景 := 场景包.instantiate()
	root.add_child(场景)
	for _帧 in 12:
		await process_frame

	var 图 := 场景.get_node_or_null("Footholds")
	var 玩 := 场景.get_node_or_null("Player")
	if 图 == null or 玩 == null:
		_断言(false, "403000000 场景缺 Footholds / Player")
		_finish()
		return
	_断言(玩.get("footholds") == 图, "玩家应自动拿到本图 Footholds（玩家.gd:169），否则墙判据没有脚点表")
	## 脚点表不对，后面的墙判据全部没有意义（直接读 id_map 会运行期报错），只留这一条红就收尾。
	if 玩.get("footholds") != 图:
		_finish()
		return
	_断言(not bool(玩.get("禁寻路")), "403000000 不是禁寻路图，玩家不该处于禁寻路态")
	## 关掉玩家自己的物理/逻辑，免得重力与输入把门里摆好的状态冲掉。
	玩.set_physics_process(false)
	玩.set_process(false)

	# ── ① 地图数据前提：66 号平台右端是上墙 67、左端是下墙 65 ─────────────────
	var 表: Dictionary = 图.get("id_map")
	var 段66: Dictionary = 表.get("66", {})
	var 墙67: Dictionary = 表.get("67", {})
	var 墙65: Dictionary = 表.get("65", {})
	_断言(float(段66.get("x1", 0)) == 490.0 and float(段66.get("x2", 0)) == 886.0
			and float(段66.get("y1", 0)) == 2019.0,
			"66 号平台应仍是 (490,2019)-(886,2019)，实得 %s" % str(段66))
	_断言(str(段66.get("next", "")) == "67" and float(墙67.get("x1", 0)) == 886.0
			and float(墙67.get("x1", 0)) == float(墙67.get("x2", -1))
			and float(墙67.get("y2", 0)) < float(墙67.get("y1", 0)),
			"66 的 next=67 应是 x=886、y2<y1 的上墙，实得 %s" % str(墙67))
	_断言(str(段66.get("prev", "")) == "65" and float(墙65.get("x1", 0)) == 490.0
			and float(墙65.get("y1", 0)) < float(墙65.get("y2", 0)),
			"66 的 prev=65 应是 x=490、y1<y2 的下墙，实得 %s" % str(墙65))
	var 段63: Dictionary = 表.get("63", {})
	var 开64: Dictionary = 表.get("64", {})
	_断言(str(段63.get("next", "")) == "64" and float(开64.get("x1", 0)) == 490.0
			and float(开64.get("y2", 0)) > float(开64.get("y1", 0)),
			"63 的 next=64 是朝下的开口（y2>y1），不该被当墙 —— 反向对照靠它分开两种竖段")
	_断言(float(表.get("33", {}).get("x1", 0)) == 1870.0
			and float(表.get("33", {}).get("x2", 0)) == 1870.0,
			"33 号竖墙应仍在 x=1870，实得 %s" % str(表.get("33", {})))
	## 单向墙的两类样本（数据来自地图 JSON，不从被测代码取）：
	##   33 号 x=1870 y 1887→1525（y2<y1，实体在右，只挡向右）
	##   100 号 x=3453 y 1175→1456（y1<y2，实体在左，只挡向左）
	_断言(float(表.get("33", {}).get("y2", 0)) < float(表.get("33", {}).get("y1", 0)),
			"33 号应是 y2<y1 的右向墙，实得 %s" % str(表.get("33", {})))
	_断言(float(表.get("100", {}).get("x1", 0)) == 3453.0
			and float(表.get("100", {}).get("x1", 0)) == float(表.get("100", {}).get("x2", -1))
			and float(表.get("100", {}).get("y1", 0)) == 1175.0
			and float(表.get("100", {}).get("y1", 0)) < float(表.get("100", {}).get("y2", 0)),
			"100 号应是 x=3453、y1<y2 的左向墙，实得 %s" % str(表.get("100", {})))

	# ── ② 地面：走到端头的墙前就停（checkFoothold:404-440）─────────────────────
	玩.set("position", Vector2(888.0, 2019.0))
	玩.set("velocity", Vector2(200.0, 0.0))
	玩.set("on_ground", true)
	玩.set("current_fh_id", "66")
	玩.call("_挡在脚点端头的墙前", "66", 884.0)
	_断言(absf(玩.position.x - 886.0) < 0.01,
			"向右跨过 66 号平台末端应被 67 号上墙挡回 x=886，实得 %.2f" % 玩.position.x)

	玩.set("position", Vector2(488.0, 2019.0))
	玩.set("velocity", Vector2(-200.0, 0.0))
	玩.call("_挡在脚点端头的墙前", "66", 492.0)
	_断言(absf(玩.position.x - 490.0) < 0.01,
			"向左跨过 66 号平台末端应被 65 号下墙挡回 x=490，实得 %.2f" % 玩.position.x)

	玩.set("position", Vector2(600.0, 2019.0))
	玩.set("velocity", Vector2(-200.0, 0.0))
	玩.call("_挡在脚点端头的墙前", "66", 604.0)
	_断言(absf(玩.position.x - 600.0) < 0.01,
			"在段中间走不该被端头的墙夹住，实得 %.2f" % 玩.position.x)

	玩.set("position", Vector2(492.0, 1177.0))
	玩.set("velocity", Vector2(200.0, 0.0))
	玩.call("_挡在脚点端头的墙前", "63", 488.0)
	_断言(absf(玩.position.x - 492.0) < 0.01,
			"64 号脚点朝下（y2>y1）是开口，不该当墙挡；实得 %.2f" % 玩.position.x)

	# ⚠ 这里原本还有一条「不认识的脚点号不该移动玩家」：去掉 `段.is_empty()` 守卫后
	#   空字典取 `.x2` 会当场运行期报错、函数直接中断，位置照样不动 ⇒ **那条腿无论如何
	#   红不了**（反向对照实测），留着就是自洽空转。

	# ── ③ 空中：跨竖线就贴到交点内侧 1 像素，下落才清水平速度（checkFoothold:297-371）──
	## 33/79/80 号竖段这一片全在 x≈1870、且都是 y2<y1（实体在右，只挡向右）；
	## 100 号在 x=3453 是 y1<y2（实体在左，只挡向左）。测试点都避开邻居的 y 范围，
	## 免得命中顺序影响结果。
	玩.set("position", Vector2(1880.0, 1740.0))
	玩.set("velocity", Vector2(200.0, 100.0))
	玩.call("_空中撞墙", 1840.0, 1700.0)
	_断言(absf(玩.position.x - 1869.0) < 0.01 and absf(玩.position.y - 1730.0) < 0.01,
			"下落中向右撞 33 号竖墙应贴到 (1869,1730)，实得 %s" % str(玩.position))
	_断言(玩.velocity.x == 0.0 and absf(玩.velocity.y - 100.0) < 0.01,
			"下落撞墙只清水平速度，竖直速度保留；实得 %s" % str(玩.velocity))

	玩.set("position", Vector2(1880.0, 1700.0))
	玩.set("velocity", Vector2(200.0, -100.0))
	玩.call("_空中撞墙", 1840.0, 1740.0)
	_断言(absf(玩.position.x - 1869.0) < 0.01 and absf(玩.position.y - 1700.0) < 0.01,
			"上升中向右撞墙只夹 x=1869，不许把这一帧的上升量吃掉，实得 %s" % str(玩.position))
	_断言(absf(玩.velocity.x - 200.0) < 0.01,
			"上升中撞墙原版不清 vx（checkFoothold:330/363），实得 %s" % str(玩.velocity))

	## 反腿 A：33 号是右向墙，**向左跳离**时原版 findIntersection 的
	## `dotProduct(位移, 法线) < 0` 不成立 ⇒ 不该认交点、不许贴回、不许清 vx。
	## 这正是用户 2026-10-31 报的"从平台下方起跳 / 从平台边跳出去会被挡"那一类。
	玩.set("position", Vector2(1840.0, 1740.0))
	玩.set("velocity", Vector2(-200.0, 100.0))
	玩.call("_空中撞墙", 1880.0, 1700.0)
	_断言(absf(玩.position.x - 1840.0) < 0.01 and absf(玩.position.y - 1740.0) < 0.01,
			"33 号是右向墙：向左跳离不该被贴回端面，实得 %s" % str(玩.position))
	_断言(absf(玩.velocity.x + 200.0) < 0.01,
			"没认交点就不许清 vx，实得 %s" % str(玩.velocity))

	## 左向墙 100（x=3453）：下落中向左撞，贴到交点右侧 1 像素并清 vx。
	## 起点 (3480,1260) → 现位 (3440,1300)，跨线处交 y = 1260 + 40×27/40 = 1287。
	玩.set("position", Vector2(3440.0, 1300.0))
	玩.set("velocity", Vector2(-200.0, 100.0))
	玩.call("_空中撞墙", 3480.0, 1260.0)
	_断言(absf(玩.position.x - 3454.0) < 0.01 and absf(玩.position.y - 1287.0) < 0.01,
			"下落中向左撞 100 号竖墙应贴到 (3454,1287)，实得 %s" % str(玩.position))
	_断言(玩.velocity.x == 0.0 and absf(玩.velocity.y - 100.0) < 0.01,
			"向左下落撞墙同样只清 vx，实得 %s" % str(玩.velocity))

	玩.set("position", Vector2(3440.0, 1300.0))
	玩.set("velocity", Vector2(-200.0, -100.0))
	玩.call("_空中撞墙", 3480.0, 1260.0)
	_断言(absf(玩.position.x - 3454.0) < 0.01 and absf(玩.position.y - 1300.0) < 0.01,
			"上升中向左撞墙只夹 x=3454，不许吃掉上升量，实得 %s" % str(玩.position))
	_断言(absf(玩.velocity.x + 200.0) < 0.01,
			"上升中撞墙不清 vx（checkFoothold:330/363），实得 %s" % str(玩.velocity))

	## 反腿 B：100 号是左向墙，向右跳离不该被挡。
	玩.set("position", Vector2(3470.0, 1300.0))
	玩.set("velocity", Vector2(200.0, 100.0))
	玩.call("_空中撞墙", 3430.0, 1260.0)
	_断言(absf(玩.position.x - 3470.0) < 0.01 and absf(玩.position.y - 1300.0) < 0.01,
			"100 号是左向墙：向右跳离不该被贴回端面，实得 %s" % str(玩.position))
	_断言(absf(玩.velocity.x - 200.0) < 0.01,
			"没认交点就不许清 vx，实得 %s" % str(玩.velocity))

	玩.set("position", Vector2(1880.0, 1100.0))
	玩.set("velocity", Vector2(200.0, 0.0))
	玩.call("_空中撞墙", 1840.0, 1100.0)
	_断言(absf(玩.position.x - 1880.0) < 0.01,
			"竖墙顶端以上（y=1100 不在 1175..1505 里）横穿不该被挡，实得 %.2f" % 玩.position.x)

	# ── ④ 蜡烛视野遮罩：只在 403000000 建，圆心 = 玩家屏幕坐标上抬 60 ──────────
	var 遮 := 场景.get_node_or_null("视野遮罩")
	_断言(遮 != null, "403000000 必须挂蜡烛视野遮罩（World.tickCandleEffect:447 只认这张图）")
	if 遮 == null:
		_finish()
		return
	_断言(int(遮.layer) == 12, "遮罩层级应是 12（天气 10 之上、HUD 20 之下），实得 %d" % int(遮.layer))
	var 片 := 遮.get_node_or_null("屏幕遮罩") as ColorRect
	_断言(片 != null, "遮罩下应有全屏 ColorRect '屏幕遮罩'")
	if 片 == null:
		_finish()
		return
	_断言(片.anchor_left == 0.0 and 片.anchor_top == 0.0
			and 片.anchor_right == 1.0 and 片.anchor_bottom == 1.0,
			"屏幕遮罩应铺满整屏（FULL_RECT），实得 %s" % str([片.anchor_left, 片.anchor_top, 片.anchor_right, 片.anchor_bottom]))
	_断言(片.mouse_filter == Control.MOUSE_FILTER_IGNORE, "遮罩不该吃鼠标事件")
	var 视口 := root.get_visible_rect().size
	_断言(片.size.is_equal_approx(视口), "屏幕遮罩尺寸应等于视口 %s，实得 %s" % [视口, 片.size])

	var 材 := 片.material as ShaderMaterial
	_断言(材 != null and 材.shader != null, "屏幕遮罩应带 ShaderMaterial + 着色器")
	if 材 == null or 材.shader == null:
		_finish()
		return
	_断言(absf(float(材.get_shader_parameter("stop1")) - 停1) < 0.001,
			"第一档应是 819.2×60/255=%.3f，实得 %s" % [停1, str(材.get_shader_parameter("stop1"))])
	_断言(absf(float(材.get_shader_parameter("stop2")) - 停2) < 0.001,
			"第二档应是 819.2×70/255=%.3f，实得 %s" % [停2, str(材.get_shader_parameter("stop2"))])
	_断言(absf(float(材.get_shader_parameter("stop3")) - 停3) < 0.001,
			"第三档应是 819.2×80/255=%.3f，实得 %s" % [停3, str(材.get_shader_parameter("stop3"))])
	var 码: String = 材.shader.code
	_断言(码.contains("distance(FRAGCOORD.xy, center)"), "着色器应按屏幕坐标到圆心的距离取透明度")
	_断言(码.contains("alpha = 0.8 * d / stop1"), "圆心全透、到第一档线性压到 0.8")
	_断言(码.contains("mix(0.8, 0.9") and 码.contains("mix(0.9, 1.0"),
			"第二、三档应是 0.8→0.9→1.0 的逐段线性（beginGradientFill 同口径）")
	_断言(码.contains("COLOR = vec4(0.0, 0.0, 0.0, alpha);"), "遮罩是纯黑按 alpha 合成")

	玩.set("position", Vector2(1000.0, 2019.0))
	await process_frame
	var 屏幕: Vector2 = 玩.get_global_transform_with_canvas().origin
	var 世界: Vector2 = 玩.global_position
	_断言(屏幕.distance_to(世界) > 100.0,
			"相机滚动后屏幕/世界坐标应差得够远才分得清两类口径，实得屏幕 %s / 世界 %s" % [屏幕, 世界])
	遮.call("_process", 0.0)
	var 心: Vector2 = 材.get_shader_parameter("center")
	_断言(心.is_equal_approx(屏幕 + Vector2(0.0, -60.0)),
			"圆心应是玩家屏幕坐标上抬 60（World.as:461），期望 %s，实得 %s" % [屏幕 + Vector2(0.0, -60.0), 心])
	_断言(not 心.is_equal_approx(世界 + Vector2(0.0, -60.0)),
			"圆心不许拿世界坐标算（相机一动遮罩就会偏）")

	场景.remove_child(遮)
	遮.free()
	场景.set("map_id", "410000000")
	场景.call("_挂视野遮罩")
	_断言(场景.get_node_or_null("视野遮罩") == null,
			"别的图不该建遮罩（World.tickCandleEffect 的 else 分支要把它摘掉）")

	# ── ⑤ 源码钉：防悄悄回退 ────────────────────────────────────────────────
	var 玩源 := FileAccess.get_file_as_string(玩家脚本)
	var 位移 := 玩源.find("position += velocity * delta")
	var 地墙 := 玩源.find("_挡在脚点端头的墙前(previous_fh_id, prev_x)")
	var 空墙 := 玩源.find("_空中撞墙(prev_x, prev_y)")
	_断言(位移 > 0 and 地墙 > 位移 and 空墙 > 位移,
			"两条墙判据必须排在 position += velocity * delta 之后（位移加完才判）")
	var 地墙段 := _截段(玩源, "func _挡在脚点端头的墙前(", "func _空中撞墙(")
	_断言(地墙段.contains("float(下段.y2) < float(下段.y1)")
			and 地墙段.contains("float(下段.y1) < float(下段.y2)"),
			"端头墙判据应与 checkFoothold:404/429 一致（next 上墙 y2<y1 / prev 下墙 y1<y2）")
	var 空墙段 := _截段(玩源, "func _空中撞墙(", "func _sync_backend_movement(")
	_断言(空墙段.contains("if velocity.y > 0.0:")
			and 空墙段.contains("position = Vector2(贴x, 交y)")
			and 空墙段.contains("position.x = 贴x"),
			"空中撞墙应复制 checkFoothold:330/363：只有下落才清 vx 并贴 y，上升只夹 x")
	_断言(空墙段.contains("var 实体在右 := float(段.y2) < float(段.y1)")
			and 空墙段.contains("if 实体在右 != (步长x > 0.0):"),
			"空中撞墙必须是单向的（findIntersection:108-136 的法线判据）：y2<y1 只挡向右、y1<y2 只挡向左")

	var 遮源 := FileAccess.get_file_as_string(遮罩脚本)
	_断言(遮源.contains("const 层级 := 12"), "遮罩层级常量应仍为 12")
	_断言(遮源.contains("const 圆心抬高 := 60.0"), "World.as:461 的 y-60 应仍是 60")
	_断言(遮源.contains("const 原版半径 := 250.0"), "MapCandleEffect.RANGE_WIDTH 应仍是 250")
	_断言(遮源.contains("const 渐变半径 := 819.2"), "Flash 单位渐变框的径向半径应仍是 819.2")
	_断言(遮源.contains("比值 := [0.0, 60.0 / 255.0, 70.0 / 255.0, 80.0 / 255.0]"),
			"ratios 必须按 0..255 标度折算（直读 60/70/80 像素会把可见圈压成针孔）")
	_断言(遮源.contains("透明度 := [0.0, 0.8, 0.9, 1.0]"), "alphas 应仍是 [0,0.8,0.9,1]")

	var 根源 := FileAccess.get_file_as_string(地图根脚本)
	var 挂段 := _截段(根源, "func _挂视野遮罩(", "func restore_baked_static(")
	_断言(挂段.contains("map_id != \"403000000\""), "只有 403000000 建遮罩")
	_断言(挂段.contains("视野遮罩脚本.new()"), "遮罩应由代码建（174 张烘焙场景里没有这个节点）")

	_finish()


func _finish() -> void:
	_已收尾 = true
	if _失败.is_empty():
		print("命运之抉择通道墙与视野遮罩回归测试：通过（%d 条断言）" % _条数)
		quit(0)
		return
	for 条 in _失败:
		printerr(条)
	print("命运之抉择通道墙与视野遮罩回归测试：共 %d 条，红 %d 条" % [_条数, _失败.size()])
	quit(1)
