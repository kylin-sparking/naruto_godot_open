extends SceneTree

## 远程玩家（同图另一个号）**画不画得出来**的有头量具。
##
## 为什么要这一支：用户 2026-10-14 实机报「两个号在同一张图谁都看不到对面」。在线门
## `测试/双人同图在线回归测试.gd` 已经证明服务端发了 162、客户端也解进了 `map_players`，
## 而「节点挂上去了」和「屏幕上有他的像素」是两件事 —— 打坐光环那次就是门全绿、实机看不到
## （见记忆《Finish claims》：材质/逐帧特效只查节点属性 = 假绿）。所以这里唯一硬判据是
## **同一块屏幕矩形 A/B 两拍数差异像素**：把对面藏起来拍一张、亮出来拍一张，
## 同一个框里必须差出成片像素，否则「看不见」是真的。
##
## ⚠ 不能加 `--headless`（无头拿不到视口图像）。
## 用法：Godot --path . --script res://开发工具/截远程玩家.gd
##
## 喂的是**数据层入口** `_handle_spawn_player_text(字段)`（不是 `emit_signal`），字段序照
## `fake_flash_server.py:15179 _foreign_player_payload()` 的 29 段现拼；坐标取「本方角色 +
## 140 像素」⇒ 保证落在视口里，也保证两号不会重叠在同一个点上（重叠在一点时"看不见"另有原因）。
## 全程只改内存，跑完把 `in_game` / `character_id` / `authoritative_map_id` / `map_players`
## 原样还回去，不碰存档。

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 对编号 := 2
const 对名字 := "社交同伴"
const 对脸 := 1
const 拉开像素 := 140
const 框宽 := 140.0
const 框高 := 210.0
const 抬高 := 100.0		## 注册点在脚底、美术往上长 ⇒ 框要往上抬

var 红 := 0


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	call_deferred("_跑")


## 照 `_foreign_player_payload()` 的 29 段现拼一条 162（读法见 后端连接.gd:2465）。
func _字段(x: int, y: int) -> PackedStringArray:
	var 列 := PackedStringArray()
	列.resize(29)
	列[0] = "162"
	列[1] = str(对编号)		# character_id
	列[2] = 对名字			# name
	列[3] = "1"			# job
	列[4] = "1"			# gender
	列[5] = "1"			# skin_color
	列[6] = str(对脸)		# face
	列[7] = "0"			# hair
	列[8] = "0"
	列[9] = "-"			# 装备外观
	列[10] = "-"
	列[11] = "0"			# ling_face
	列[12] = "0"
	列[13] = "0"			# foothold
	列[14] = str(x)		# x
	列[15] = str(y)		# y
	列[16] = "1"			# movement_flag（= 朝向）
	列[17] = "0"			# movement_action
	列[18] = "0"
	列[19] = "100"			# level
	列[20] = "0"			# shengwang
	列[21] = "0"			# crime
	列[22] = "0"			# family_id
	列[23] = "-"			# family_name
	列[24] = "-"			# 称号
	列[25] = "0"
	列[26] = "0"			# 最高技能等级
	列[27] = "0"			# 连斩档
	列[28] = "0"			# char_type
	return 列


func _判(对: bool, 说明: String) -> void:
	print(("  √ " if 对 else "  !! ") + 说明)
	if not 对:
		红 += 1


func _等(几帧: int) -> void:
	for 弃 in 几帧:
		await process_frame


func _跑() -> void:
	await _主跑()


func _主跑() -> void:
	var 后 = root.get_node_or_null("/root/BackendConnection")
	if 后 == null:
		_判(false, "没有 BackendConnection 单例")
		quit(1)
		return
	var 旧: Array = [后.get("in_game"), 后.get("character_id"), 后.get("authoritative_map_id"),
			(后.get("map_players") as Dictionary).duplicate(true)]
	var 场景: Node = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	后.set("in_game", true)
	后.set("character_id", 1)
	后.set("authoritative_map_id", 101010000)
	await _等(14)
	var 管: Node = 场景.get_node_or_null("窗口管理")
	if 管 != null:
		管.call("全部关闭")
	var 实体: Node = 场景.find_child("LifeRoot", true, false)
	_判(实体 != null, "地图实体（LifeRoot）找到了")
	if 实体 == null:
		_收尾(旧)
		return
	var 玩家: Node2D = get_first_node_in_group("player") as Node2D
	_判(玩家 != null, "本方角色在场景里（组 player）—— 不在就连参照位都没有")
	if 玩家 == null:
		_收尾(旧)
		return
	var 位: Vector2 = 玩家.get_global_position()
	print("  本方角色全局位 %s ⇒ 给他摆在 +%d 像素处" % [str(位), 拉开像素])
	后.call("_handle_spawn_player_text", _字段(int(位.x) + 拉开像素, int(位.y)))
	await _等(10)

	# ── ① 补建那一步到底走没走到 ──────────────────────────────────────
	var 名册 = 实体.get("_remote_players")
	_判(名册 is Dictionary and (名册 as Dictionary).has(对编号),
			"162 走到了「补建」（_remote_players=%s）" % (str((名册 as Dictionary).keys()) if 名册 is Dictionary else "取不到"))
	if not (名册 is Dictionary) or not (名册 as Dictionary).has(对编号):
		_收尾(旧)
		return
	var actor: Node2D = (名册 as Dictionary)[对编号] as Node2D
	var 件 := ""
	for 子 in actor.get_children():
		件 += "%s(%s) " % [str(子.name), 子.get_class()]
	print("  演员节点：名字=%s  子件=%s  visible=%s  modulate=%s  全局位=%s"
			% [str(actor.name), 件, str(actor.visible), str(actor.modulate), str(actor.get_global_position())])
	_判(actor.visible, "演员自己是显示的（show_other_characters 要是关了，这里就是关着的）")
	_判((actor.get_global_position() - 位).length() > 60.0,
			"两个角色拉开 %s 像素（小于 60 = 重叠在一点，判不出画没画）"
					% str((actor.get_global_position() - 位).length()))

	# ── ② 贴图与名字牌各就位没 ────────────────────────────────────────
	var 贴 = actor.get_child(0)
	_判(贴 != null and 贴.get_child_count() > 0, "动画精灵挂上了子件（Sprite2D）")
	var 图: Sprite2D = null
	if 贴 != null:
		for 子 in 贴.get_children():
			if 子 is Sprite2D:
				图 = 子 as Sprite2D
	_判(图 != null and 图.texture != null,
			"角色贴图真的取了到纹理（%s）" % (str(图.texture.get_size()) if 图 != null and 图.texture != null else "无"))
	_判(图 != null and 图.visible, "那层 Sprite2D 自己是显示的")
	var 高: float = float(贴.call("当前贴图高度")) if 贴 != null else 0.0
	_判(高 > 0.0, "站立首帧高度 %s > 0" % str(高))
	var 牌: Label = actor.get_node_or_null("Nameplate") as Label
	_判(牌 != null and not 牌.text.is_empty() and 牌.visible,
			"头顶名字牌挂着且写着「%s」" % (牌.text if 牌 != null else "没有牌"))

	# ── ③ 硬判据：同一块屏幕矩形 A/B 两拍数差异像素 ────────────────────
	var 差 := await 拍两拍(actor, 位, "分开")
	_判(差 > 400, "把对面藏起来 / 亮出来，那块屏幕真差出 %d 个像素 ⇒ 他是被画出来的" % 差)

	# ──  用户实机那一幕：两个号**站在同一个点上**（存档实测 2165,1213 与 2164,1213）──
	## 原版全工程 `grep sortChildren|zIndex` **零命中** ⇒ 角色层就是 addChild 顺序，后进图的人
	## 画在前面的人之上 ⇒ 重叠时你看到的是"对面那个"。我们的本地 `Player` 是 `LifeRoot` 之后的
	## 兄弟节点（无 y 排序、无 z_index）⇒ 远程玩家被自己整个盖住 ⇒ "谁都看不到对面"。
	后.call("_handle_move_player_text", _移动帧(对编号, int(位.x), int(位.y)))
	await _等(14)
	var 重叠差 := await 拍两拍(actor, 位, "重叠")
	_判(重叠差 > 400,
			"两个号重叠在一格上时，屏幕上也该差出像素（实得 %d）—— 差 0 就是被自己整个盖住了" % 重叠差)
	_收尾(旧)
	return


## 一条服务端形状的 187（`187:<command>:<charId>:<type>:<type>:<x>:<y>:<速度x>:…`，
## 出处 `fake_flash_server.py:34712` 的广播与 `:61160` 的翻译器）。
func _移动帧(编号: int, x: int, y: int) -> PackedStringArray:
	var 列 := PackedStringArray()
	列.resize(13)
	列[0] = "187"; 列[1] = "0"; 列[2] = str(编号); 列[3] = "0"; 列[4] = "0"
	列[5] = str(x); 列[6] = str(y); 列[7] = "0"; 列[8] = "0"; 列[9] = "0"
	列[10] = "1"; 列[11] = "0"; 列[12] = "0"
	return 列


## 以 `参照位` 为中心框住演员，藏/亮各拍一张，返回框内差异像素数（并出两张 2× 图）。
func 拍两拍(actor: Node2D, 参照位: Vector2, 名: String) -> int:
	var 屏: Vector2 = root.get_canvas_transform() * actor.get_global_position()
	actor.visible = false
	await _等(3)
	var 无: Image = root.get_texture().get_image()
	actor.visible = true
	await _等(3)
	var 有: Image = root.get_texture().get_image()
	var 左 := int(max(0.0, 屏.x - 框宽 * 0.5))
	var 上 := int(max(0.0, 屏.y - 抬高))
	var 右: int = mini(无.get_width() - 1, 左 + int(框宽))
	var 下: int = mini(无.get_height() - 1, 上 + int(框高))
	var 差 := 0
	for yy in range(上, 下 + 1):
		for xx in range(左, 右 + 1):
			var 甲: Color = 无.get_pixel(xx, yy)
			var 乙: Color = 有.get_pixel(xx, yy)
			if absf(甲.r - 乙.r) + absf(甲.g - 乙.g) + absf(甲.b - 乙.b) > 0.12:
				差 += 1
	print("  A/B[%s]：框 x %d..%d  y %d..%d（演员屏幕位 %s / 本方 %s）差异像素 = %d（框内共 %d）"
			% [名, 左, 右, 上, 下, str(屏), str(参照位), 差, (右 - 左 + 1) * (下 - 上 + 1)])
	存(无, 左, 上, 右 - 左 + 1, 下 - 上 + 1, "对面_%s_藏起来.png" % 名)
	存(有, 左, 上, 右 - 左 + 1, 下 - 上 + 1, "对面_%s_画出来.png" % 名)
	return 差


func 存(全图: Image, 左: int, 上: int, 宽: int, 高: int, 名: String) -> void:
	if 宽 <= 0 or 高 <= 0:
		return
	DirAccess.make_dir_recursive_absolute("res://测试/截图/远程玩家")
	var 裁 := 全图.get_region(Rect2(左, 上, 宽, 高))
	var 大 := Image.create(宽 * 2, 高 * 2, false, Image.FORMAT_RGBA8)
	for yy in 高:
		for xx in 宽:
			var 色 := 裁.get_pixel(xx, yy)
			大.set_pixel(xx * 2, yy * 2, 色)
			大.set_pixel(xx * 2 + 1, yy * 2, 色)
			大.set_pixel(xx * 2, yy * 2 + 1, 色)
			大.set_pixel(xx * 2 + 1, yy * 2 + 1, 色)
	var 错 := 大.save_png("res://测试/截图/远程玩家/%s" % 名)
	print("  存图 %s：%s" % [名, "ok" if 错 == OK else error_string(错)])


func _收尾(旧: Array) -> void:
	var 后 = root.get_node_or_null("/root/BackendConnection")
	if 后 != null:
		后.set("in_game", 旧[0])
		后.set("character_id", 旧[1])
		后.set("authoritative_map_id", 旧[2])
		var 表 = 后.get("map_players")
		if 表 is Dictionary:
			(表 as Dictionary).clear()
			for 键 in (旧[3] as Dictionary).keys():
				(表 as Dictionary)[键] = (旧[3] as Dictionary)[键]
	print("远程玩家有头量具：%s" % ("全过" if 红 == 0 else "红 %d 条" % 红))
	quit(0 if 红 == 0 else 1)
