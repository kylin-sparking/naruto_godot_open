extends SceneTree

## 小地图正式化量具（**不能加 `--headless`**，无头拿不到视口图像）。
##
## 用法：
##   Godot --path . --script res://开发工具/截小地图正式化.gd -- --出目录=res://测试/截图/小地图正式化
##
## 出三张图 + 一份几何：
##   `落地_无任务.png` —— 场上 NPC 全是普通绿小人（会话里一条任务都没有）
##   `落地_三态.png`   —— 同一块小地图上同时出现 可接「!」/ 进行中「?」/ 可交「?」三枚
##   `落地_走到右缘.png` —— 玩家走到图右缘，证明滚动钳位与原版一致（图不越过边缘）
##   `几何.txt`        —— 图尺寸 / 可视 / 面板偏移 / 每条标记的类名 + 世界坐标 + 落点像素
##
## 两条口径先说清楚，免得看图的人误判：
##  * 三态那一步是**喂会话里的任务列表**造出来的（`accepted_quests`/`available_quests`）⇒
##    走的是 `会话.npc_quest_status()` 的**离线倒推**那一支。在线那一支由服务端逐枚推
##    `onUpdateQuestStatusPacket`（`Client.as:5079-5085`，本工程已接成 `513`），
##    头顶与小地图读的都是同一条 ⇒ 这张图量的是**画法**，不是协议。
##  * 改状态与拍图**分两步**：`root.get_texture().get_image()` 拍到的是上一帧画完的果。

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 存档 := "user://玩家数据.json"
## 用木叶村而不是默认那张：它的缩略图 495×167、scale 10 ⇒ 显示 309×104，比视口宽 166px，
## 滚动与钳位在截图上看得出来；终结谷那张只有 150 宽，行程 7px，拍了也看不出差别。
## 它还有 9 扇门 pt 分别是 0/1/2 ⇒ `pt==2` 那条过滤在真图上也判得动。
const 默认地图 := "100000000"

var 出目录 := ""
var 场景: Node
var 板: Node
var 画: Node
var 会话: Node
var 玩家: Node2D
var 队列: Array[Callable] = []
var 等待 := 0
var 帧 := 0
var 行: Array[String] = []
var 有错 := false
var 快照 := ""


func _initialize() -> void:
	for 参 in OS.get_cmdline_user_args():
		var 键值 := 参.trim_prefix("--").split("=", false)
		if 键值.size() == 2 and 键值[0] == "--出目录":
			出目录 = 键值[1]
	if 出目录.is_empty():
		出目录 = "res://测试/截图/小地图正式化"
	if not DirAccess.dir_exists_absolute(出目录):
		DirAccess.make_dir_recursive_absolute(出目录)
	if FileAccess.file_exists(存档):
		快照 = FileAccess.get_file_as_string(存档)
	队列.append(_步开图)
	队列.append(_步认路)
	队列.append(_步无任务)
	队列.append(_步拍.bind("落地_无任务.png"))
	队列.append(_步三态)
	队列.append(_步拍.bind("落地_三态.png"))
	队列.append(_步点图)	# 真点小地图（有头 ⇒ 事件走完整拾取链）
	队列.append(_步拍.bind("落地_点小地图寻路.png"))
	队列.append(_步对照复位)
	队列.append(_步对照起路A)
	队列.append(_步对照记划.bind("A 真点小地图"))
	队列.append(_步对照结.bind("A 真点小地图"))
	队列.append(_步拍.bind("落地_对照A_点图.png"))
	队列.append(_步对照复位)
	队列.append(_步对照起路B)
	队列.append(_步对照记划.bind("B 直调走向"))
	队列.append(_步对照结.bind("B 直调走向"))
	队列.append(_步拍.bind("落地_对照B_直调.png"))
	队列.append(_步收尾)


func _process(_d: float) -> bool:
	帧 += 1
	if 等待 > 0:
		等待 -= 1
		return false
	if 帧 < 10:
		return false
	if 队列.is_empty():
		return true
	队列.pop_front().call()
	return false


func _记(成立: bool, 说明: String) -> void:
	行.append("%s %s" % ["OK " if 成立 else "红 ", 说明])
	if not 成立:
		有错 = true


func _步开图() -> void:
	var 路: String = 地图资源.playable_scene_path(默认地图)
	_记(路.contains("场景/生成/"), "加载烘焙场景（实机走 playable_scene_path）：%s" % 路)
	var 包 := load(路) as PackedScene
	if 包 == null:
		_记(false, "加载不到 %s" % 路)
		return
	场景 = 包.instantiate()
	root.size = Vector2i(960, 560)
	root.add_child(场景)
	current_scene = 场景
	等待 = 8


func _步认路() -> void:
	for 层 in root.get_children():
		var 找 := 层.find_child("小地图面板", true, false)
		if 找 != null:
			板 = 找
			break
	if 板 == null:
		_记(false, "找不到 小地图面板 这一层")
		return
	画 = 板.get("_minimap")
	会话 = root.get_node_or_null("GameSession")
	玩家 = get_first_node_in_group("player") as Node2D
	_记(画 != null, "画布在（RuntimeMinimapCanvas）")
	_记(会话 != null, "会话在")
	_记(玩家 != null, "玩家在")
	if 画 == null or 玩家 == null:
		return
	## ⚠ 本量具是**直接 instantiate 地图场景**，没走会话的换图流程 ⇒ `current_map_id` 还停在
	## 默认那张（101010000），于是面板按错的图去取缩略图与 miniMap 规格：
	## 第一版拍出来 图尺寸 150×87.5（终结谷的），而场景是木叶村（应当 309×104）。
	## ⇒ 这里显式把会话指到同一张图，再重接一次面板。
	会话.set("current_map_id", 默认地图)
	板.call("_接地图")
	画 = 板.get("_minimap")
	var 管理 := 场景.get_node_or_null("窗口管理")
	if 管理 != null:
		管理.call("全部关闭")
	玩家.global_position = Vector2(2400.0, 1000.0)
	板.call("_刷标记")
	_记(画.size == Vector2(143, 124), "画布 143×124（视口常数，SmallMapWindow.as:55-61），实得 %s" % 画.size)
	_记(画.get("贴图") != null, "缩略图取到了：%s" % str((画.get("贴图") as Texture2D).resource_path if 画.get("贴图") != null else ""))
	行.append("   规格=%s" % JSON.stringify(画.get("规格")))
	行.append("   图尺寸=%s 可视=%s 面板偏移=%s" % [画.get("图尺寸"), 画.get("可视"), 画.get("面板偏移")])


func _清任务() -> void:
	(会话.get("accepted_quests") as Array).clear()
	(会话.get("available_quests") as Array).clear()


func _步无任务() -> void:
	if 画 == null or 会话 == null:
		return
	_清任务()
	板.call("_刷标记")
	var 人: Array = ((画.get("组") as Dictionary).get("npc", []) as Array)
	_记(人.size() > 0, "场上有 NPC 可画（%d 枚）" % 人.size())
	var 全绿 := true
	for 条 in 人:
		if str((条 as Dictionary).get("类", "")) != "minimap_npc_skin":
			全绿 = false
	_记(全绿, "一条任务都没有 ⇒ 每枚 NPC 都是普通绿小人 minimap_npc_skin")
	_写标记表("无任务")


func _步三态() -> void:
	if 画 == null or 会话 == null:
		return
	var 人: Array = (板.call("_场上实体") as Array)
	if 人.size() < 3:
		_记(false, "场上 NPC 不足 3 枚，造不出三态（实得 %d）" % 人.size())
		return
	var a := int(str(人[0]["号"]))
	var b := int(str(人[1]["号"]))
	var c := int(str(人[2]["号"]))
	_清任务()
	(会话.get("accepted_quests") as Array).append({"id": "9001", "target_npc": a, "completed": true})
	(会话.get("accepted_quests") as Array).append({"id": "9002", "target_npc": b})
	(会话.get("available_quests") as Array).append({"id": "9003", "giver_npc": c})
	板.call("_刷标记")
	var 组: Array = ((画.get("组") as Dictionary).get("npc", []) as Array)
	var 见 := {}
	for 条 in 组:
		见[str((条 as Dictionary).get("类", ""))] = int(见.get(str((条 as Dictionary).get("类", "")), 0)) + 1
	_记(int(见.get("minimap_endnpc_skin", 0)) == 1, "可交那枚 = minimap_endnpc_skin（黄「?」），实得 %s" % str(见.get("minimap_endnpc_skin", 0)))
	_记(int(见.get("minimap_questing_skin", 0)) == 1, "进行中那枚 = minimap_questing_skin（灰「?」）")
	_记(int(见.get("minimap_startnpc_skin", 0)) == 1, "可接那枚 = minimap_startnpc_skin（黄「!」）")
	_记(int(见.get("minimap_npc_skin", 0)) == 组.size() - 3, "其余仍是普通绿小人")
	_写标记表("三态")


## ⚠ 原来这里还有第三步「把玩家走到图右缘再拍一张」，删掉了：**演不出来**。
## 玩家控制器每帧把位置拉回它所在的地面（直接写 (4800,1000) 四帧后已经掉回 2400），
## 而场上最靠右的 NPC 只在 x=1870 ⇒ 图素 118，还在 1/5~4/5 的死区里，面板本来就不该挪。
## 拿假位置拍一张"看起来在滚"的图 = 自证。滚动与两端钳位由 **门** 量（`_行为腿` 7 条：
## 带内不挪 / 越过 4/5 钉在 4/5 / 右缘钳在 可视−图尺寸 / 越过 1/5 钉在 1/5 / 左缘钳回 0 /
## 偏移取整 / 没玩家不挪），而这两张图里 `面板偏移 = (−37, 10)` 本身就是"已经挪过"的实证。


## 真点一下小地图：事件要 **motion → 按(带 button_mask) → 松**，中间留帧
## （`root.get_texture().get_image()` 拍到的是上一帧画完的果，同一帧发同一帧拍 = 拍到旧的）。
func _步点图() -> void:
	if 画 == null or 玩家 == null:
		return
	var 起 := 玩家.global_position
	var 局 := Vector2(104.0, 62.0)		# 画布中间偏右：换算出去是地图右侧那块地面
	var 全: Vector2 = (画 as Control).get_global_position() + 局
	var 移 := InputEventMouseMotion.new()
	移.position = 全
	移.global_position = 全
	root.push_input(移)
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 全
	按.global_position = 全
	root.push_input(按)
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.button_mask = 0
	放.position = 全
	放.global_position = 全
	root.push_input(放)
	等待 = 24	# 让它真的走上二十来帧，截图才看得出"在动"
	_写标记表("点图")
	行.append("〔点图〕画布局部 %s → 世界 %s；点前玩家 %s → 等帧后 %s（click_move_active=%s）" % [
			局, 画._世界位(局), 起, 玩家.global_position, str(玩家.get("click_move_active"))])


## ── A/B 对照：点小地图 vs 直接调 `玩家.走向(同一个世界点)` ──────────────────
##
## 为什么要这一对：`点图` 那步观察到角色往**右**走（x 2400→2800），而目的地在 x=2236（左边）。
## 光看图分不清两种解释 —— ① 寻路本来就要绕右路去爬台；② 这一下被 `玩家._unhandled_input`
## 也吃了一遍（那条的目的地 = 鼠标处的世界位，方向恰好朝右）。
## ⇒ 拿**同一个世界点**走两条路各跑一遍，比「刚起路线时角色自己记的那条 plan」与
## 「同样帧数后的位置」。两条一致 ⇒ 小地图这条路只是「换算 + 交给 走向」，没自造第二套移动，
## 绕不绕路的锅也不在小地图（那是世界寻路本来的行为）。
var 对照世界 := Vector2.INF
var 对照起点A := Vector2.INF
var 对照路线A := ""


func _步对照复位() -> void:
	if 玩家 == null or 画 == null:
		return
	玩家.global_position = Vector2(2400.0, 1212.0)
	玩家.set("click_move_active", false)
	等待 = 40	# 落回地面 + 让面板按新位置重排一次（`_刷标记` 是 0.5s 轮询）


func _步对照起路A() -> void:
	## A 条：真鼠标点小地图（和 `点图` 同样形状：motion → 按(带 button_mask) → 松）
	var 局 := Vector2(104.0, 62.0)
	var 全: Vector2 = (画 as Control).get_global_position() + 局
	对照世界 = 画._世界位(局)
	对照起点A = 玩家.global_position
	var 移 := InputEventMouseMotion.new()
	移.position = 全
	移.global_position = 全
	root.push_input(移)
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 全
	按.global_position = 全
	root.push_input(按)
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.button_mask = 0
	放.position = 全
	放.global_position = 全
	root.push_input(放)
	等待 = 2


func _步对照起路B() -> void:
	## B 条：不经鼠标，宿主直接调同一个 `走向`，目的地 = A 条刚算出的那个世界点。
	## 起点必须和 A 条相同，否则这条对照没有可比性 ⇒ 不相同就直接报红。
	_记(玩家.global_position == 对照起点A, "B 条起点 == A 条起点（A=%s 实=%s）" % [对照起点A, 玩家.global_position])
	玩家.call("走向", 对照世界)
	等待 = 2


func _步对照记划(条名: String) -> void:
	var 划: Array = 玩家.get("auto_actions") as Array
	var 述: Array[String] = []
	for 动 in 划:
		var d := 动 as Dictionary
		述.append("%s@%s" % [str(d.get("type", "?")), str(d.get("x", d.get("edge", "?")))])
	var 路串 := " → ".join(述)
	if 条名.begins_with("A"):
		对照路线A = 路串
	else:
		## 这条才是 A/B 的判据：位置随起步相位差几帧，**路线**必须逐字相同。
		## 一旦小地图自己另起一套移动（或那一下被 `玩家._unhandled_input` 重复吃了），
		## 目的地就会变成鼠标处的世界位 ⇒ 路线立刻和 A 条不同，这里报红。
		_记(路串 == 对照路线A, "B 条路线逐字 == A 条路线｜A：%s｜B：%s" % [对照路线A, 路串])
	行.append("〔对照%s〕起点 %s → 目的地 %s｜路线 %d 步：%s" % [条名, 玩家.global_position,
			Vector2(float(玩家.get("click_move_x")), float(玩家.get("click_move_y"))),
			划.size(), 路串])
	等待 = 22	# A 条已先跑过 2 帧，这里补到同一总帧数再拍


func _步对照结(条名: String) -> void:
	行.append("〔对照%s〕24 帧后玩家 %s（目的地在它%s边）" % [条名, 玩家.global_position,
			"左" if float(玩家.get("click_move_x")) < 玩家.global_position.x else "右"])


func _写标记表(题: String) -> void:
	行.append("〔%s〕面板偏移=%s 可视=%s 图尺寸=%s" % [题, 画.get("面板偏移"), 画.get("可视"), 画.get("图尺寸")])
	行.append("〔%s〕标记清单（类名 | 世界 | 图素+锚点=落点，画序自上而下）：" % 题)
	var 组: Dictionary = 画.get("组") as Dictionary
	## 「自己」不在组里：原版是 playerHelper（:1052）每 tick 由 setPlayerPosition 挪，
	## 这边同样按 玩家 Callable 现取 ⇒ 清单里单独补一行，别以为漏画了。
	if 玩家 != null:
		行.append("   自己 | minimap_user_skin | 世界%s → 图素%s → 落点%s" % [玩家.global_position,
				画._图素(玩家.global_position),
				画.get("面板偏移") + 画._图素(玩家.global_position) + 画._锚("minimap_user_skin")])
	for 名 in 画.get("画序"):
		if str(名) == "图":
			continue
		for 条 in (组.get(名, []) as Array):
			var d := 条 as Dictionary
			var 位: Vector2 = d.get("位", Vector2.ZERO)
			var 类 := str(d.get("类", ""))
			行.append("   %s | %s | 世界%s → 图素%s → 落点%s" % [
					名, 类, 位, 画._图素(位), 画.get("面板偏移") + 画._图素(位) + 画._锚(类)])


func _步拍(图名: String) -> void:
	if 画 == null:
		return
	var 图 := root.get_texture().get_image()
	var 路 := 出目录 + "/" + 图名
	图.save_png(路)
	var 框: Rect2i = Rect2i(画.get_global_rect())
	var 裁 := 图.get_region(Rect2i(maxi(框.position.x, 0), maxi(框.position.y, 0),
			mini(框.size.x, 图.get_width()), mini(框.size.y, 图.get_height())))
	裁.save_png(出目录 + "/" + 图名.replace(".png", "_小地图.png"))
	## 再裁一张**整块小地图（含框皮）**：量「图有没有落在框的内凹口里」只能看这张 ——
	## 只裁画布自身那块 143×124 会把溢出到框皮上的部分一起裁掉，看着永远是满的。
	## ⚠ 面板根是 CanvasLayer（不是 CanvasItem、没有 get_global_rect）⇒ 要裁的是它下面那块控件 _minimap_panel。
	var 块: Control = 板.get("_minimap_panel") as Control
	var 板框: Rect2i = Rect2i(块.get_global_rect())
	var 整 := 图.get_region(Rect2i(maxi(板框.position.x, 0), maxi(板框.position.y, 0),
			mini(板框.size.x, 图.get_width()), mini(板框.size.y, 图.get_height())))
	整.save_png(出目录 + "/" + 图名.replace(".png", "_整块.png"))
	行.append("   截图 %s（整屏 %dx%d / 凹口裁 %dx%d / 整块裁 %dx%d）" % [路, 图.get_width(), 图.get_height(), 裁.get_width(), 裁.get_height(), 整.get_width(), 整.get_height()])
	## 为什么要把 `click_move_*` 打出来：点完观察到玩家往**右**走（x 2400→2800），
	## 而算出来的目的地在 x=2236（左边）。两种解释长得一样 —— ① 寻路真要绕右路上爬；
	## ② `玩家._unhandled_input` 也吃了这一下（它的目的地 = 鼠标处的世界位 ≈2838）。
	## 只看位置猜分不开，必须看角色自己记的那条路线目的地。
	行.append("   拍这一张时玩家 %s｜这条路线的目的地 click_move=(%s, %s) 在走=%s｜小地图上自己那枚落点 %s" % [玩家.global_position,
			玩家.get("click_move_x"), 玩家.get("click_move_y"), 玩家.get("click_move_active"),
			(画.get("面板偏移") as Vector2) + 画._图素(玩家.global_position) + 画._锚("minimap_user_skin")])
	行.append("   凹口全局矩形 %s / 画布全局矩形 %s / 面板偏移 %s" % [(板.get("_minimap_content") as Control).get_global_rect(), (画 as Control).get_global_rect(), 画.get("面板偏移")])


func _步收尾() -> void:
	if 快照 != "":
		var 写 := FileAccess.open(存档, FileAccess.WRITE)
		写.store_string(快照)
		写.close()
	var 现 := FileAccess.get_file_as_string(存档) if FileAccess.file_exists(存档) else ""
	行.append("%s 收尾：存档字节数 %d → %d（还原 %s）" % ["OK " if 现 == 快照 else "红 ",
			快照.length(), 现.length(), "成功" if 现 == 快照 else "失败"])
	if 现 != 快照:
		有错 = true
	var 文 := FileAccess.open(出目录 + "/几何.txt", FileAccess.WRITE)
	文.store_string("\n".join(行) + "\n")
	文.close()
	print("\n".join(行))
	print("截小地图正式化：退出码 %d" % (1 if 有错 else 0))
	quit(1 if 有错 else 0)
