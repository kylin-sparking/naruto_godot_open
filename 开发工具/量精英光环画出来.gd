extends SceneTree

## 有头量具：怪脚下那圈光环、名字下面那排强化图标**在屏幕上真的画得出像素**。
##
## 为什么离线门不够（记忆 `feedback-finish-claims`：材质/逐帧特效只查节点属性 = 假绿）：
## `测试/精英光环图标回归测试.gd` 判的是节点建没建、缩放/摆位/z 对不对 ——
## 那些数全对也可能**一个像素都没画**（`_draw` 取不到图、`墨迹中心` 算成 0、被谁整屏盖住）。
## 所以这里同一块取景连拍四张，用两两差异把三件事分开量：
##   拍1 全藏 → 拍2 只开环   = 环贡献的像素
##   拍2 只开环 → 拍3 环+图标 = 图标贡献的像素
##   拍1 全藏 → 拍4 又全藏    = 阴性对照，必须恒为 0（不为 0 说明这一屏自己在动，前面那些数全废）
##
## 三条口径：
## · **四拍之间都把怪自己的精灵藏掉** ⇒ 待机动画不往差异里掺噪声。环是 `z_index=-1`
##   （原版 `ALayerType.BOTTOM` ⇒ 画在身体后面），藏掉身体不影响环自己的像素。
## · 帧要**钉住**：`定帧(0)` + `set_process(false)`（原版 `autoTick=false`+`fps=40` 由我们喂，
##   不钉住两拍就不是同一帧，差异里会掺进"换帧"这件事 —— #196 那条坑）。
## · 取景框用引擎自己的 canvas 变换现算（`get_global_transform_with_canvas`），不拿世界坐标硬减。
##
## 跑法（**不能加 --headless**，无头拿不到视口图像）：
##   Godot --path . --script res://开发工具/量精英光环画出来.gd -- --出目录=res://测试/截图/精英光环

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 环名 := "精英外观"
const 光环名 := "光环"
const 图标排名 := "精英图标排"
## 每段必须钉满的条数（协程被运行期报错打断 ⇒ 后面整段没跑而末行照样打「红 0」）
const 应判 := 9
const 框宽 := 220
const 框高 := 150
## 脚点摆在框内 y=70 ⇒ 往上留 70（环的上半）、往下留 80（图标排在脚点下 40~70）
const 脚点Y := 70

var 红 := 0
var 判数 := 0
var 场: Node
var 后: Node
var 玩: Node2D
var 图号 := 0
var 出目录 := "res://测试/截图/精英光环"


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--出目录="):
			出目录 = String(a).trim_prefix("--出目录=")
	call_deferred("_跑")


func _判(对: bool, s: String) -> void:
	判数 += 1
	if not 对:
		红 += 1
	print("%s %s" % ["ok  " if 对 else "红  ", s])


func _记(s: String) -> void:
	print("      %s" % s)


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _找场(节: Node) -> Node:
	if 节.get_script() != null and String(节.get_script().resource_path).ends_with("地图实体.gd"):
		return 节
	for 子 in 节.get_children():
		var 得 := _找场(子)
		if 得 != null:
			return 得
	return null


func _演员(号: int) -> CombatActor:
	return 场.call("_活演员", 号) as CombatActor


## 出生帧原文 = 服务端 `_monster_spawn_payload`（段序逐段对 `测试/原版协议抓包.json:76` 那条真机原文）。
## x/y 给"玩家右边 170 像素"那一格 ⇒ 怪一定在镜头里，不用去动相机（相机是脚本驱动，会写回）。
func _喂(号: int, 模板: int, 精英串: String) -> void:
	var 位: Vector2 = 玩.global_position + Vector2(170, 0)
	后.call("_handle_bridge_text",
			"238:1:%d:0:%d:%d:%d:%d:0:1:1:0:true:0:%d:%d:0:0:-:%s:-:0:false:false:false:0:0" % [
			号, 模板, 图号, int(位.x), int(位.y), int(位.x), int(位.y), 精英串])


func _环的(演员: CombatActor) -> Node2D:
	return 演员.get_node_or_null(环名) as Node2D if 演员 != null else null


func _排的(演员: CombatActor) -> CanvasItem:
	var 环 := _环的(演员)
	return 环.get_node_or_null(图标排名) as CanvasItem if 环 != null else null


## 钉住第 0 帧并停掉自走（四拍必须是同一帧）。缩放与帧表都在容器里面那层「光环」上。
func _钉(演员: CombatActor) -> void:
	var 环 := _环的(演员)
	if 环 == null:
		return
	var 件 := 环.get_node_or_null(光环名)
	if 件 == null:
		return
	件.call("定帧", 0)
	件.set_process(false)


## 取景：以演员脚点（节点原点）为框内 (框宽/2, 脚点Y)
func _取景(演员: CombatActor) -> Rect2i:
	var 屏: Vector2 = (演员 as CanvasItem).get_global_transform_with_canvas().origin
	return Rect2i(int(屏.x) - int(框宽 / 2), int(屏.y) - 脚点Y, 框宽, 框高)


## 拍一张：`开` = 那一层开不开；怪自己的精灵四拍都藏着（免得待机动画掺噪声）
func _拍(演员: CombatActor, 开环: bool, 开图标: bool) -> Image:
	var 环 := _环的(演员)
	if 环 != null:
		环.visible = 开环
	var 排 := _排的(演员)
	if 排 != null:
		排.visible = 开图标 and 开环
	var 精 := 演员.get_node_or_null("Sprite")
	if 精 != null:
		(精 as CanvasItem).visible = false
	await _帧(3)
	return root.get_texture().get_image().get_region(_取景(演员))


## 两图逐像素比：返回 [差异像素数, 差异盒(块内坐标)]
func _差(a: Image, b: Image) -> Array:
	var n := 0
	var 盒 := Rect2i()
	var 有 := false
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixelv(Vector2(x, y)) != b.get_pixelv(Vector2(x, y)):
				n += 1
				var 点 := Rect2i(x, y, 1, 1)
				盒 = 点 if not 有 else 盒.merge(点)
				有 = true
	return [n, 盒 if 有 else Rect2i()]


func _存(名: String, 图: Image) -> void:
	DirAccess.make_dir_recursive_absolute(出目录)
	图.save_png("%s/%s.png" % [出目录, 名])


func _跑() -> void:
	var 场景: Node = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _帧(60)
	场 = _找场(场景)
	后 = root.get_node_or_null("BackendConnection")
	玩 = get_first_node_in_group("player") as Node2D
	if 场 == null or 后 == null or 玩 == null:
		for i in 应判:
			_判(false, "开场就没凑齐 地图实体/BackendConnection/player（%s/%s/%s）⇒ 后面全部判不了" % [
					str(场 != null), str(后 != null), str(玩 != null)])
		_收()
		return
	图号 = int(场.call("_get_current_map_id"))
	if 图号 <= 0:
		for i in 应判:
			_判(false, "当前图号 = %d ⇒ 喂进去的出生帧会被地图过滤掉" % 图号)
		_收()
		return

	## ── ①②③④：随机强化的普通小怪（boss==0 + 两条精英属性）──
	_喂(91001, 1000001, "0&5@4&3")
	await _帧(10)
	var 甲 := _演员(91001)
	_判(甲 != null and _环的(甲) != null, "① 在线强化怪建出来了、脚下环节点也在（演员=%s 环=%s）" % [
			str(甲 != null), str(_环的(甲) != null)])
	if 甲 == null or _环的(甲) == null:
		for i in 应判 - 判数:
			_判(false, "① 之后全部判不了：环没建出来")
		_收()
		return
	_钉(甲)
	var 藏 := await _拍(甲, false, false)
	var 只环 := await _拍(甲, true, false)
	var 环图 := await _拍(甲, true, true)
	var 藏2 := await _拍(甲, false, false)
	_存("变异环_开", 只环)
	_存("整只_开", 环图)
	_存("全藏", 藏)
	var 数阴 := _差(藏, 藏2)
	var 数环 := _差(藏, 只环)
	var 数图 := _差(只环, 环图)
	_记("阴性对照（全藏 vs 全藏）差异 %d 像素" % 数阴[0])
	_记("环贡献 %d 像素、盒=%s；图标贡献 %d 像素、盒=%s" % [
			数环[0], str(数环[1]), 数图[0], str(数图[1])])
	_判(数阴[0] == 0,
			"② 阴性对照恒为 0（这一屏不许有任何东西自己在动，否则下面两个数没有意义；实得 %d）" % 数阴[0])
	_判(数环[0] >= 300, "③ 变异环真的画在屏幕上了（差异 %d 像素，要 ≥300）" % 数环[0])
	## 环的着墨盒：宽 = 第 0 帧墨迹宽 × 118/126（135×0.9365 ≈ 126）；竖直中心要对到脚点
	var 盒环: Rect2i = 数环[1]
	var 中环y: int = 盒环.position.y + int(盒环.size.y / 2)
	_判(盒环.size.x >= 110 and 盒环.size.x <= 150 and absi(中环y - 脚点Y) <= 6,
			"④ 环的着墨宽=%d（要 110~150）且竖直中心对到脚点（偏 %d 像素，要 ≤6）" % [
			盒环.size.x, 中环y - 脚点Y])
	## ── ⑤⑥：名字下面那排强化图标（两枚：Money + Atk）──
	_判(数图[0] >= 300, "⑤ 两枚强化图标真的画得出来（差异 %d 像素，要 ≥300）" % 数图[0])
	var 盒图: Rect2i = 数图[1]
	## 注册点在图标**正中** ⇒ 一枚时容器 x = 0 就端端正正压在脚点下（玩家 10-22 实机对图就是这个要求）；
	## 两枚的中心 = -15 与 +17 ⇒ 左边缘 = 脚点x - 15 - 15 = 脚点x - 30、跨 30+2+30 = 62、
	## 顶 = 脚点y + 40 - 15 = 脚点y + 25
	_判(absi(盒图.position.x - int(框宽 / 2 - 30)) <= 3 and absi(盒图.size.x - 62) <= 3
			and absi(盒图.position.y - int(脚点Y + 25)) <= 3,
			"⑥ 图标排摆位（**中心对齐脚点**）：左边缘应在块内 x=%d（实得 %d）、宽应 62（实得 %d）、顶应在 y=%d（实得 %d）" % [
			int(框宽 / 2 - 30), 盒图.position.x, 盒图.size.x, 脚点Y + 25, 盒图.position.y])

	## ── ⑦：boss==1 的首领环（168/76 档）要明显大一圈 ──
	_喂(91002, 2100001, "-")
	await _帧(10)
	var 乙 := _演员(91002)
	if 乙 == null or _环的(乙) == null:
		for i in 应判 - 判数:
			_判(false, "⑦ 判不了：首领(boss=1) 2100001 的环没建出来")
	else:
		_钉(乙)
		var 藏乙 := await _拍(乙, false, false)
		var 开乙 := await _拍(乙, true, false)
		_存("首领环_开", 开乙)
		var 数乙 := _差(藏乙, 开乙)
		_记("首领环贡献 %d 像素、盒=%s" % [数乙[0], str(数乙[1])])
		_判(数乙[0] > 数环[0] and (数乙[1] as Rect2i).size.x > 盒环.size.x,
				"⑦ 首领环（168/76 档）比变异环（118/126 档）明显大一圈：像素 %d>%d、宽 %d>%d" % [
				数乙[0], 数环[0], (数乙[1] as Rect2i).size.x, 盒环.size.x])

	## ── ⑨：普通怪（boss==0、无精英）那一块屏幕上就该干干净净 ──
	_喂(91003, 1000002, "-")
	await _帧(10)
	var 戊 := _演员(91003)
	if 戊 == null:
		for i in 应判 - 判数:
			_判(false, "⑧⑨ 判不了：普通怪没建出来")
	else:
		_判(_环的(戊) == null, "⑧ 普通怪不许挂环（实得 %s）" % str(_环的(戊)))
		var 前 := await _拍(戊, false, false)
		var 后2 := await _拍(戊, false, false)
		var 数戊 := _差(前, 后2)
		_判(数戊[0] == 0,
				"⑨ 普通怪那块两拍逐像素全等（差异 %d 像素）⇒ 上面那些差异不是量具自己造的" % 数戊[0])
	_收()


func _收() -> void:
	if 判数 < 应判:
		红 += (应判 - 判数)
		print("红   只判了 %d 条，不足 %d 条 ⇒ 中间有段被运行期报错打断" % [判数, 应判])
	print("量精英光环画出来：判 %d 条 / 红 %d 条 / 出目录 %s" % [判数, 红, 出目录])
	quit(0 if 红 == 0 else 1)
