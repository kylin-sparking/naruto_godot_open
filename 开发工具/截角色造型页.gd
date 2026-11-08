extends SceneTree

## #183 的**有头**量具：喂四种服务端 `face`（裸男 / 裸女 / 雷装束40+ / 风装束低档）+
## 一种 face 缺位（按性别兜底），各起一次真地图场景，读出**运行期真贴到玩家身上**的那张纹理，
## 并各拍一张实机图（我自己看）。
## ⚠ 不能加 `--headless`（无头拿不到视口图像）。
## 跑法：godot --path . --script res://开发工具/截角色造型页.gd
##
## 这条补的是离线门照不到的那一层：门里 `configure()` 只证明「那套身体能加载」，
## 这里证明「**玩家节点真的按服务端 face 挑中了它**」—— 也就是把 `玩家.gd` 里
## 从「写死 00000001」改成「读 face」这一跳，在真场景里跑一遍。

const 出 := "res://测试/截图/角色造型/"
const 地图 := "res://场景/地图/地图场景.tscn"
const 角色造型 := preload("res://脚本/角色/角色造型.gd")

var 日志: Array[String] = []
var 红 := 0
var 判 := 0
var 存前 := PackedByteArray()
var 收 := false

## [服务端 face, 性别, 期望造型号, 说明]
var 四组 := [
	[1, 1, "00000001", "裸体·男（创角选火/雷且没穿装备）"],
	[2, 2, "00000002", "裸体·女（创角选水/风且没穿装备）"],
	[303, 1, "00000303", "雷装束·40 级以上那一档"],
	[400, 2, "00000400", "风装束·低档"],
]
## face 缺位（离线数据 / 老包）⇒ 按性别兜底
var 兜底组 := [[0, 2, "00000002", "face 缺位 + 女"], [0, 1, "00000001", "face 缺位 + 男"]]


func _写() -> void:
	var f := FileAccess.open(出 + "造型.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(日志) + "\n")
		f.close()


func _步(说: String) -> void:
	日志.append("· " + 说)
	_写()


func _判(过: bool, 说: String) -> void:
	判 += 1
	日志.append("%s %s" % ["ok " if 过 else "!!红", 说])
	if not 过:
		红 += 1
	_写()


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _字节(路: String) -> PackedByteArray:
	if not FileAccess.file_exists(路):
		return PackedByteArray()
	var g := FileAccess.open(路, FileAccess.READ)
	if g == null:
		return PackedByteArray([1])
	var 字 := g.get_buffer(g.get_length())
	g.close()
	return 字


func _看门狗() -> void:
	var 截止 := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < 截止:
		await create_timer(0.5).timeout
	if 收:
		return
	日志.append("!!红 看门狗：跑到 120 秒没收尾（最后一步见上一行）")
	红 += 1
	_收尾()


func _initialize() -> void:
	call_deferred("_跑")
	call_deferred("_看门狗")


func _跑() -> void:
	存前 = _字节("user://玩家数据.json")
	root.size = Vector2i(960, 560)
	var 会: Node = root.get_node_or_null("BackendConnection")
	var 会话: Node = root.get_node_or_null("GameSession")
	_判(会 != null and 会话 != null, "缺 BackendConnection / GameSession 单例")
	if 会 == null or 会话 == null:
		_收尾()
		return

	# ---- 服务端下发 face（在线那条路） ----
	for 组 in 四组:
		var 号 := await _进图并读数(会, 会话, int(组[0]), int(组[1]), String(组[2]), true)
		_判(号.contains("Char_%s_stand_" % String(组[2])),
				"%s ⇒ 运行期贴的应是 Char_%s 的 stand（实得 %s）" % [String(组[3]), 组[2], 号])

	# ---- face 缺位 ⇒ 按性别兜底（离线那条路，没有服务端图可拍就别拍） ----
	for 组 in 兜底组:
		var 号2 := await _进图并读数(会, 会话, int(组[0]), int(组[1]), String(组[2]), false)
		_判(号2.contains("Char_%s_stand_" % String(组[2])),
				"%s ⇒ 应是 Char_%s 的 stand（实得 %s）" % [String(组[3]), 组[2], 号2])
	_步("face 四档 + 缺位兜底两档各走完一遍")
	_收尾()


## 起一次真地图场景，读玩家身上那张纹理的类名（`Char_00000103_stand_0_body` 这种）。
## 在线 = 写 `authoritative_stats`；离线 = 清空它、改写 `GameSession.player_stats`。
func _进图并读数(会: Node, 会话: Node, 脸: int, 性别: int, 号: String, 要截图: bool) -> String:
	## 只喂 `face`/`gender` 两个字段：`_自身外观()` 判的是「authoritative_stats 非空」，
	## 所以这一份就代表服务端角色包那一条路。
	## ⚠ 必须连 `in_game` 一起钉：取值口是 `游戏会话.自身外观()`，它走 `_online_backend()`，
	##   而后者的定义就是「**只有真的在游戏会话里**才认服务端那份权威数据」
	##   （`游戏会话.gd:2749-2751`）⇒ 不设 in_game 就会退回离线 player_stats，
	##   六档全变成 00000001（本轮实测：探针报 8 条红，红的是量具没喂对状态）。
	会.set("in_game", true)
	会.set("authoritative_stats", {"face": 脸, "gender": 性别, "level": 1})
	var 景: Node = (load(地图) as PackedScene).instantiate()
	root.add_child(景)
	await _帧(60)
	## ⚠ 用 SceneTree 自己的 `get_first_node_in_group`（`测试/技能单体与面积行为门.gd:125` 那条能跑通）；
	##   第一版这里写 `root.get_first_node_in_group(...)` 拿回来是 null ⇒ 八条判据全红，
	##   而那**不是**游戏坏（量具坏）。
	var 玩: Node2D = get_first_node_in_group("player") as Node2D
	var 类名 := "?"
	if 玩 != null:
		var 片 = 玩.get("player_sprite")
		if 片 != null and 片.get("sprite") != null and (片.get("sprite") as Sprite2D).texture != null:
			类名 = String(((片 as Node).get("sprite") as Sprite2D).texture.resource_path).get_file().get_basename()
		## 左上角那枚头像也要跟着换（#191）：HUD 长在地图场景里 ⇒ 同一帧里就能读到。
		var 头像 := String(_找图(景, "头像面板/头像区域/角色状态/Portrait"))
		## ⚠ 截图必须在**场景还在**的时候拍。第一版把 _截一张 放到本函数返回之后，
		##   而那时场景已经 queue_free 掉了 ⇒ 四张"实机图"全是 3KB 的空帧（看着像量具坏了）。
		_步("   ↳ 头像=%s" % 头像)
		_判(头像.contains("Char_%s_info_portrait" % 号),
				"face=%d ⇒ 头像应是 Char_%s_info_portrait，实得「%s」" % [脸, 号, 头像])
		_步("face=%d gender=%d → 纹理=%s" % [脸, 性别, 类名])
		## 第三处消费者 = 人物窗口的立绘（`人物窗口.gd:99-104`）。它是**开窗时才烤**的，
		## 静态门只能证明"代码里读的是同一个口"，这里把窗真开一次、把那张图读出来。
		var 管理 := 景.get_node_or_null("窗口管理")
		var 立绘 := "?"
		if 管理 != null:
			管理.call("打开", "人物")
			await _帧(12)
			立绘 = _找图名(管理.call("取窗口", "人物"), "角色站立图")
			管理.call("全部关闭")
			await _帧(3)
		else:
			_步("地图场景里没有 窗口管理 节点 ⇒ 人物窗立绘这一条量不到")
		_判(立绘.contains("Char_%s_stand_" % 号),
				"face=%d ⇒ 人物窗立绘应是 Char_%s 的 stand（实得「%s」）" % [脸, 号, 立绘])
	if 要截图:
		await _截一张(号)
	景.queue_free()
	await _帧(3)
	return 类名


## 从场景里按节点路径取 TextureRect 的图名（取不到返回空串，让判据去说话）。
func _找图(景: Node, 路径: String) -> String:
	var 节 := 景.get_node_or_null(路径) as TextureRect
	if 节 == null or 节.texture == null:
		return ""
	return String(节.texture.resource_path).get_file().get_basename()


## 按**节点名**递归找第一张有图的 TextureRect（窗口内容是运行期挂进去的，路径不稳）。
func _找图名(节: Node, 名: String) -> String:
	if 节 == null:
		return ""
	if 节.name == 名 and 节 is TextureRect and (节 as TextureRect).texture != null:
		return String((节 as TextureRect).texture.resource_path).get_file().get_basename()
	for 子在 in 节.get_children():
		var 得 := _找图名(子在, 名)
		if 得 != "":
			return 得
	return ""


func _截一张(号: String) -> void:
	var 图 := root.get_texture().get_image()
	if 图 == null:
		_步("拿不到视口图（是不是加了 --headless？）")
		return
	图.save_png(出 + "实机_" + 号 + ".png")
	_步("存了 " + 号)


func _收尾() -> void:
	if 收:
		return
	收 = true
	_判(_字节("user://玩家数据.json") == 存前, "量具不许动存档（user://玩家数据.json 字节一致）")
	_写()
	for 项 in 日志:
		print(项)
	print("角色造型有头量具：判 %d 条 / 红 %d 条" % [判, 红])
	quit(0 if 红 == 0 else 1)
