extends SceneTree
## 有头量具：两件事都要**在视口图像上看见**才算数。
##   ① 剧情面：上格 NPC 台词 + 下格一行绿色玩家回应，**菜单行一行都不许在**。
##   ② 小地图任务标记：喂 513 那张表（在线同一条路径）之后，标记真的画出来了。
## ⚠ 两处的像素判据都是**同一块区域两个状态比差**，不是数颜色——
##    剧情面 = 把回应块藏掉 / 显回来；小地图 = 513 全 0（原版给无任务 NPC 也画的灰点）
##    与 1/2/3（可接/可交/进行中三档彩色）。数颜色会把灰石头地形和金色 UI 边一起算进来
##    （第一版就因此假绿过）。
## 用法（不能加 --headless）：… --path . --script res://开发工具/截剧情面与小地图标记.gd
const 出 := "res://测试/截图/剧情面与小地图"
var _失败: Array[String] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出))
	call_deferred("_run")


func _断言(成立: bool, 说明: String) -> void:
	if not 成立:
		_失败.append(说明)


func _找(根: Node, 名: String) -> Node:
	if String(根.name) == 名:
		return 根
	for 子 in 根.get_children():
		var 找 := _找(子, 名)
		if 找 != null:
			return 找
	return null


func _绿像素(图: Image) -> int:
	var n := 0
	for y in 图.get_height():
		for x in 图.get_width():
			var c := 图.get_pixel(x, y)
			if c.g > 0.55 and c.r < 0.5 and c.b < 0.5:
				n += 1
	return n


func _差像素(a: Image, b: Image) -> int:
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.35:
				n += 1
	return n


## 画布当前那一组 npc 标记各自顶哪个元件名。像素只能证明「这块变了」，证明不了
## 「变的是我喂的那三枚」—— 少了这一层，喂表没生效 / 贴图查无 / 标记出界 都只会报差 0。
func _组类(画布: Node) -> Array:
	var 出: Array = []
	var 组: Dictionary = 画布.get("组") as Dictionary
	for 条 in (组.get("npc", []) as Array):
		出.append(String((条 as Dictionary).get("类", "")))
	return 出


func _收() -> void:
	if _失败.is_empty():
		print("截剧情面与小地图标记：通过（剧情面无菜单 + 切回菜单 + 小地图标记都画出来了）")
		quit(0)
		return
	for 条 in _失败:
		printerr(条)
	print("截剧情面与小地图标记：红 %d 条" % _失败.size())
	quit(1)


func _run() -> void:
	## ⚠ **必须走 `change_scene_to_packed`，不许 `root.add_child()`**：`_场上实体()` 是按
	## `get_tree().current_scene` 去找 `LifeRoot` 的，与运行期是同一条路（`游戏会话.gd:2267`
	## 换图用的就是它）⇒ 游戏里 `current_scene` 一定有值。而 `add_child` **不设** 它，
	## 于是 `_场上实体()` 返回空、`组` 里一条 NPC 标记都没有，"灰点/三档"必然差 0
	## （2026-10-09 这一条假红了整整一轮，红的是量具不是客户端）。
	## ⚠ 顺带一条 Godot 4.7 形状：`change_scene_to_packed` **是延迟一帧才落到
	## `current_scene`** 的（返回 OK 时还没换完）⇒ 这条断言只能在等帧之后做，写在前面必假红。
	## 运行期不受影响：`_刷标记()` 是 `_process` 里每 0.5 秒重刷（`小地图面板.gd:185-187`）。
	_断言(change_scene_to_packed(load("res://场景/地图/地图场景.tscn") as PackedScene) == OK,
			"换不进地图场景")
	for _帧 in 14:
		await process_frame
	_断言(current_scene != null, "change_scene 并等了 14 帧，current_scene 仍是 null")
	var HUD := get_first_node_in_group("game_hud")
	_断言(HUD != null, "没有 game_hud")
	if HUD == null or current_scene == null:
		_收()
		return

	## ── ① 剧情面 ─────────────────────────────────────────────
	var 窗 := _找(HUD, "原版NPC对话窗")
	if 窗 == null:
		HUD.call("show_npc_dialog", "00000001", "先开一次窗把实例建出来")
		for _帧 in 4:
			await process_frame
		窗 = _找(HUD, "原版NPC对话窗")
	_断言(窗 != null, "HUD 下找不到对话窗实例")
	if 窗 == null:
		_收()
		return
	窗.call("显示", 1, "浅野婆婆", "听老头子说，暗部救回你之后，醒来你就失忆了，对吗？", [], [], "我会用心记住婆婆的话的。")
	for _帧 in 4:
		await process_frame
	var 根: Control = 窗.call("根")
	_断言(根.visible, "剧情模式没把窗打开")
	var 下: Control = _找(根, "下格")
	var 应: Control = _找(根, "回应")
	_断言(下 != null and 应 != null, "找不到下格或回应块")
	if 下 == null or 应 == null:
		_收()
		return
	_断言(应.visible, "回应块没显示")
	var 菜: Control = 下.get_node("菜单")
	var 可见 := 0
	for 行 in 菜.get_children():
		if (行 as Control).visible:
			可见 += 1
	_断言(可见 == 0, "剧情模式下还有 %d 行菜单可见 ⇒ 交易/离开没消失（用户打回的就是这个）" % 可见)
	_断言(String(应.text).contains("[color=#00ff00]"), "回应不是 #00ff00")
	var 框下 := Rect2(下.global_position.x, 下.global_position.y, 下.size.x, 下.size.y)
	var 有应 := root.get_texture().get_image().get_region(框下)
	应.visible = false
	await process_frame
	await process_frame
	var 无应 := root.get_texture().get_image().get_region(框下)
	应.visible = true
	await process_frame
	var 绿 := _绿像素(有应)
	var 差 := _差像素(有应, 无应)
	_断言(绿 > 200, "回应那块绿色像素只有 %d" % 绿)
	_断言(差 > 150, "把回应藏掉后那块只变了 %d 个像素 ⇒ 绿色是别的层贡献的，不是回应自己画的" % 差)
	有应.save_png(出 + "/剧情面下格.png")
	root.get_texture().get_image().save_png(出 + "/整屏剧情面.png")
	print("剧情面：下格 %.0fx%.0f  绿 %d  挂上/摘掉差 %d  菜单可见行 %d" % [下.size.x, 下.size.y, 绿, 差, 可见])

	## 切回菜单模式
	窗.call("显示", 1, "浅野婆婆", "想要点儿什么？我的手艺非常不赖哦！", [["物品交易", 100], ["离开", -1]])
	for _帧 in 4:
		await process_frame
	_断言(not 应.visible, "切回菜单后回应还可见")
	var 可见2 := 0
	for 行 in 菜.get_children():
		if (行 as Control).visible:
			可见2 += 1
	_断言(可见2 == 2, "菜单模式应画 2 行，实际 %d" % 可见2)
	root.get_texture().get_image().save_png(出 + "/整屏菜单面.png")

	## ── ② 小地图任务标记 ─────────────────────────────────────
	## 判据是一条**能点名原因的梯子**，不是只看像素：找得到画布 → 规格非空 → 组里真有三条
	## 且「类」依次对 → 每类取到贴图 → 三枚换算进得了视口 → 最后才比像素。
	## 只留最后一条的话，「喂 513 没生效」「框取错了」「_draw 第一行就 return」「标记画在框外」
	## 这四种病长得一模一样（都报差 0）—— 本轮就是吃了这个亏，红了一整轮才挖到量具自己。
	var 画布: Node = _找(HUD, "RuntimeMinimapCanvas")
	## ⚠ 只认运行期那个真名（`小地图面板.gd:299`）。以前退到 `_找(HUD, 小地图)` 拿到的是
	## **面板**（195x179），于是「差 0」到底是标记没画还是框没罩住画布，分不开。
	_断言(画布 != null, "找不到小地图画布（运行期节点名 RuntimeMinimapCanvas）")
	var 后端: Node = root.get_node_or_null("/root/BackendConnection")
	_断言(后端 != null, "没有 BackendConnection，喂不了 513 那张表")
	if 画布 == null or 后端 == null:
		_收()
		return
	var 规格: Dictionary = 画布.get("规格") as Dictionary
	_断言(not 规格.is_empty(),
			"画布.规格 是空的 ⇒ MinimapCanvas._draw() 第一行就 return，一张标记都不会画")
	## ⚠ 必须先把 `authenticated` 打开：`会话.npc_quest_status()` 按设计**只在已认证时**
	## 才认 513 那张表，离线一律走本地倒推（这是对的——没连服务端就没有 513）。
	## 不打开的话两条腿本来就一样，差值恒 0，量的是个假数。
	后端.set("authenticated", true)
	var 表: Dictionary = 后端.get("npc_quest_status")
	var 本图: Dictionary = 后端.get("map_npcs")
	var 备份: Dictionary = 表.duplicate(true)
	var 本图备份: Dictionary = 本图.duplicate(true)
	var 场: Node = current_scene.get_node_or_null("LifeRoot")
	_断言(场 != null, "current_scene 下面没有 LifeRoot")
	if 场 == null:
		_收()
		return
	var 枚: Array = []
	for 条 in 场.get_children():
		if str(条.get("kind")) == "n":
			枚.append(条)
	_断言(枚.size() >= 3, "本图 NPC 不足 3 枚，量不了三档（实际 %d）" % 枚.size())
	if 枚.size() < 3:
		_收()
		return
	## 513 的键是 **object_id**，`npc_quest_status()` 要先拿 `map_npcs` 把它反查成模板号
	## 才比得上 ⇒ 两张表都得喂，只喂 513 那张会一条都命中不了（第一版就卡在这）。
	## ⚠ 对照腿是**全 0**（原版给无任务 NPC 也画一枚灰点 `minimap_npc_skin`），**不是清空表**：
	## 清空会掉进 `npc_quest_status()` 的本地倒推分支，那三枚照样可能被判成「可接」⇒
	## 两条腿同图 ⇒ 差 0。那是量法自己把对照做没了，不是标记没画。
	var 键: Array = []
	for i in 3:
		var 对: int = 900000 + i
		键.append(对)
		本图[对] = {"npc_id": int(str(枚[i].get("entity_id")))}
	var 框图 := Rect2((画布 as Control).global_position.x, (画布 as Control).global_position.y,
			(画布 as Control).size.x, (画布 as Control).size.y)
	## 三条 NPC 换算到小地图坐标后落在哪 —— 全在视口外就被 `clip_contents` 裁了，量不了。
	## 边界取画布自己的 `size`（= `MinimapCanvas.视口宽/高`，`小地图面板.gd:302`），
	## 别在这儿再抄一份 143/124 —— 抄了就会跟运行期漂移。
	var 偏: Vector2 = 画布.get("面板偏移")
	var 宽: float = (画布 as Control).size.x
	var 高: float = (画布 as Control).size.y
	var 落内 := 0
	for i in 3:
		var q: Vector2 = 偏 + (画布.call("_图素", (枚[i] as Node2D).global_position) as Vector2)
		if q.x > -16.0 and q.x < 宽 and q.y > -18.0 and q.y < 高:
			落内 += 1
	_断言(落内 > 0, "三枚 NPC 在小地图上的坐标全在视口之外 ⇒ 被裁掉，这块量不了（偏移 %s）" % str(偏))
	表.clear()
	for i in 3:
		表[键[i]] = 0
	HUD.call("_刷标记")
	for _帧 in 3:
		await process_frame
	var 无 := root.get_texture().get_image().get_region(框图)
	var 类无 := _组类(画布)
	表.clear()
	for i in 3:
		表[键[i]] = [1, 2, 3][i]
	HUD.call("_刷标记")
	for _帧 in 3:
		await process_frame
	var 有 := root.get_texture().get_image().get_region(框图)
	var 类有 := _组类(画布)
	var 期望 := ["minimap_startnpc_skin", "minimap_endnpc_skin", "minimap_questing_skin"]
	for i in 3:
		_断言(类无.size() > i and str(类无[i]) == "minimap_npc_skin",
				"对照腿第 %d 枚的「类」是 %s（期望灰点）⇒ 513 的全 0 没走到 _刷标记"
				% [i, str(类无[i]) if 类无.size() > i else "缺"])
		_断言(类有.size() > i and str(类有[i]) == 期望[i],
				"挂上腿第 %d 枚的「类」是 %s（期望 %s）⇒ 513 那张表没走到 _刷标记"
				% [i, str(类有[i]) if 类有.size() > i else "缺", 期望[i]])
		_断言(画布.call("_皮", 期望[i]) != null,
				"%s 取不到贴图 ⇒ _draw 里 continue，这一格一个像素都不画" % 期望[i])
	var 差2 := _差像素(有, 无)
	var 金 := 0
	for y in 有.get_height():
		for x in 有.get_width():
			var c := 有.get_pixel(x, y)
			if c.r > 0.75 and c.g > 0.55 and c.b < 0.35 and 无.get_pixel(x, y).r < 0.7:
				金 += 1
	_断言(差2 > 120, "灰点 ⇒ 三档彩色，小地图只变了 %d 个像素 ⇒ 标记其实没画上去" % 差2)
	_断言(金 > 30, "变出来的像素里新金色只有 %d ⇒ 叹号/金问号没画" % 金)
	表.clear()
	本图.clear()
	for k in 备份:
		表[k] = 备份[k]
	for k in 本图备份:
		本图[k] = 本图备份[k]
	HUD.call("_刷标记")
	for _帧 in 2:
		await process_frame
	root.get_texture().get_image().save_png(出 + "/整屏小地图.png")
	有.save_png(出 + "/小地图三档.png")
	无.save_png(出 + "/小地图无任务.png")
	print("小地图：%.0fx%.0f  视口内 %d/3  灰点→三档差 %d  其中新金色 %d"
			% [框图.size.x, 框图.size.y, 落内, 差2, 金])
	print("  对照腿类 %s  挂上腿类 %s" % [str(类无), str(类有)])
	_收()
