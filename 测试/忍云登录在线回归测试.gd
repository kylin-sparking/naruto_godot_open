extends SceneTree
## 忍云（头顶那摞排行榜徽记）**登录即显示**的在线门。
##
## 用户 2026-10-25 报「排行榜的忍云总是要点了排行榜，才显示出来」。
## 根因（实测）：`fake_flash_server.py` 的**文本腿** `enter_game()` 只发了地图榜单
## （`_send_current_map_rank`），没发自己那份 `1346:0`；二进制腿 `enter_original_game()`
## 从第一天就有这一句。于是本客户端进图后 `authoritative_ranking_titles` 一直是空字典，
## 玩家头顶的 `PaiHangPane` 要等**别人打开排行榜**（`visible=True` 时服务端广播 1346）
## 才会冒出来。修法是在文本腿 `enter_game()` 末尾补同一句 `_send_ranking_title_update()`。
##
## 本门全程**不打开排行榜窗口**，只钉三件事：
##   ① 登录进图后，`authoritative_ranking_titles` 里已经有自己，且列表非空；
##   ② 地图场景里玩家的 `PaiHangPane` 按这份字典建出**同样枚数**的徽记；
##   ③ 每一枚的贴图路径等于「榜号→图号」查表结果（榜号≠图号，防退回错图/错色）。
##
## 反向对照（手工做过）：把服务端 `enter_game()` 里那句 `_send_ranking_title_update()`
## 摘掉再跑本门 ⇒ ① 立刻红（字典里没有自己），② 的徽记数变成 0。恢复后回绿。
##
## 跑法：`powershell -NoProfile -ExecutionPolicy Bypass -File 开发工具\跑在线用例.ps1 -用例 忍云登录`
## 　夹具给独立端口 18748/18749（见 `$夹具额外`）。

const 门名 := "忍云登录在线回归测试"
## 榜号→图号，出处 `原版杂项.PaiHangBang[榜号].iconLink`（离线门 `忍云榜单徽记回归测试.gd`
## 已逐条钉过；这里再独立列一份，因为在线这层要防的是"服务端发错榜号/客户端退回错图"）。
## 5→9、6..8→6..8、9→5、10..22→11..24；30 走 `PaiHangBang_Hide[0]`=_14。
const 榜号图号 := {
	0: 0, 1: 1, 2: 2, 3: 3, 4: 4, 5: 9, 6: 6, 7: 7, 8: 8, 9: 5,
	10: 11, 11: 12, 12: 13, 13: 14, 14: 15, 15: 16, 16: 17, 17: 18, 18: 19,
	19: 20, 20: 21, 21: 22, 22: 23, 30: 14,
}
const 徽记图根 := "res://素材/特效/Effect_PaiHangBang/Effect_PaiHangBang_%d/1.png"

var _失败: Array[String] = []
var _判数 := 0
var _收好了 := false
var 会话引用: Node = null
var 原端口 := -1
var 存档路 := "user://玩家数据.json"
var 存档前 := PackedByteArray()
var 本来有存档 := false


func _记(成立: bool, 说明: String) -> void:
	_判数 += 1
	if not 成立:
		_失败.append(说明)


func _停(话: String) -> void:
	_还原()
	printerr("汇：判 %d 条 / 红 %d 条（%s：中断）" % [_判数, _失败.size() + 1, 门名])
	printerr("  红 - " + 话)
	quit(1)


func _等待(条件: Callable, 毫秒: int = 10000) -> bool:
	for _轮 in range(毫秒 / 50):
		if bool(条件.call()):
			return true
		await create_timer(0.05).timeout
	return bool(条件.call())


func _看门狗() -> void:
	await create_timer(180.0).timeout
	if _收好了:
		return
	printerr("汇：判 %d 条 / 红 %d 条（%s：看门狗超时）" % [_判数, _失败.size() + 1, 门名])
	_还原()
	quit(1)


func 拍快照() -> void:
	var 读 := FileAccess.open(存档路, FileAccess.READ)
	if 读 == null:
		return
	本来有存档 = true
	存档前 = 读.get_buffer(读.get_length())


func _还原() -> void:
	if 会话引用 != null and 原端口 >= 0:
		var 设置: Dictionary = 会话引用.get("game_settings")
		设置["backend_port"] = 原端口
	if 本来有存档:
		var 写 := FileAccess.open(存档路, FileAccess.WRITE)
		if 写 != null:
			写.store_buffer(存档前)


func _initialize() -> void:
	拍快照()
	call_deferred("_跑")
	call_deferred("_看门狗")


func _跑() -> void:
	var 后端 := root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	if 后端 == null or 会话 == null:
		_停("缺单例（BackendConnection / GameSession）")
		return
	会话引用 = 会话

	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18748
	var 设置: Dictionary = 会话.get("game_settings")
	原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口

	## 进图用烘焙场景（与真游戏同一条路），否则没有 LifeRoot → 没有玩家节点。
	var 地图图: Node = null
	后端.entered_game.connect(func(_号: int) -> void:
		var 地图 := String(会话.get("current_map_id"))
		var 地图资源 := load("res://脚本/地图/地图资源.gd")
		change_scene_to_file(地图资源.playable_scene_path(地图)))
	后端.call("sync_character")

	if not await _等待(func(): return bool(后端.get("in_game")), 20000):
		_停("进不了真实后端：%s - %s" % [后端.get("status"), 后端.get("detail")])
		return
	var 我号 := int(后端.get("character_id"))
	_记(我号 > 0, "① 角色号该 >0；实得 %d" % 我号)

	for _i in range(300):
		if current_scene != null and current_scene.get_node_or_null("LifeRoot") != null:
			地图图 = current_scene
			break
		await create_timer(0.1).timeout
	if 地图图 == null:
		_停("没等到地图场景（LifeRoot 不在）")
		return

	## ① 字典：登录后、**没开排行榜**就应该有自己那份
	var 字典: Dictionary = 后端.get("authoritative_ranking_titles")
	var 有自己 := func() -> bool:
		var 表 = 后端.get("authoritative_ranking_titles")
		return 表 is Dictionary and (表 as Dictionary).has(我号)
	if not await _等待(有自己, 15000):
		_停("① 登录进图后 `authoritative_ranking_titles` 里没有自己（%s）—— 文本腿 enter_game() 又漏发 1346:0 了？实际字典=%s"
				% [我号, str(后端.get("authoritative_ranking_titles"))])
		return
	字典 = 后端.get("authoritative_ranking_titles")
	var 自己: Array = 字典.get(我号, [])
	_记(自己.size() > 0, "① 自己那份榜号列表不该为空；实得 %s" % str(自己))
	var 榜号对 := true
	for 号 in 自己:
		if not 榜号图号.has(int(号)):
			榜号对 = false
	_记(榜号对, "① 服务端发的榜号都该在查表里；实得 %s" % str(自己))

	## ② 头顶板：玩家 PaiHangPane 的枚数 == 字典枚数（没点排行榜也该建出来）
	var 玩: Node2D = null
	for _i in range(100):
		玩 = get_first_node_in_group("player") as Node2D
		if 玩 != null and 玩.get_node_or_null("PaiHangPane") != null:
			break
		await create_timer(0.1).timeout
	if 玩 == null:
		_停("② 地图里没有玩家节点")
		return
	var 板 := 玩.get_node_or_null("PaiHangPane") as Node2D
	if 板 == null:
		_停("② 玩家身上没有 PaiHangPane")
		return
	if not await _等待(func() -> bool: return 板.get_child_count() >= 自己.size(), 10000):
		pass  # 下面按实际枚数出断言，不在这里提前中断
	_记(板.get_child_count() == 自己.size(),
			"② 徽记枚数该等于字典里自己的榜号数 %d；实得 %d" % [自己.size(), 板.get_child_count()])
	_记(板.get_child_count() > 0, "② 没点排行榜，头顶也该已经有徽记；实得 0 枚")

	## ③ 每一枚的贴图 = 榜号查表（服务端榜号错/客户端映射错，都在这里红）
	var 名字集 := {}
	for 子 in 板.get_children():
		var 图 := 子 as Sprite2D
		if 图 == null or 图.texture == null:
			_记(false, "③ 徽记 %s 不是带贴图的 Sprite2D" % String(子.name))
			continue
		名字集[String(子.name)] = String(图.texture.resource_path)
	for 号 in 自己:
		if not 榜号图号.has(int(号)):
			continue  # ① 已经红过；这里再索引会直接抛错，把后面几条判据全埋掉
		var 期望 := 徽记图根 % int(榜号图号[int(号)])
		var 键 := "PaiHangBadge_%d" % int(号)
		_记(名字集.get(键, "") == 期望,
				"③ 榜号 %d 的徽记该用 %s；实得 %s" % [int(号), 期望, str(名字集.get(键, "（没有这枚）"))])
	## 枚数与字典一致时，左边逐个对上就说明没多没少
	_记(名字集.size() == 自己.size(), "③ 徽记名集合枚数该=%d；实得 %d" % [自己.size(), 名字集.size()])

	_收好了 = true
	if 地图图 != null:
		地图图.queue_free()
	await process_frame
	_还原()
	for 条 in _失败:
		printerr("  红 - " + 条)
	print("汇：判 %d 条 / 红 %d 条（%s：%s）　自己的榜号=%s"
			% [_判数, _失败.size(), 门名, "通过" if _失败.is_empty() else "失败", str(自己)])
	quit(0 if _失败.is_empty() else 1)
