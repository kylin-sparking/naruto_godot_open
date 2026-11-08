extends SceneTree

## 精英怪光环 + 小怪强化图标的门（用户 2026-10-22 给三张原版图：守财鼠 / 【精英】木叶叛忍 /
## 沙瀑妖 —— 脚下都有一圈橙色光环，名字下面还有一枚圆形图标）。
##
## 真值（行号 = 2.2.3优化版 的 .as，逐句转写在 `脚本/角色/精英外观.gd`）：
## · `Monster.as:1659` 建环条件 = `info.boss==1 || info.boss==2 || jingyings.length>0`
## · `:1660` 选图 = `boss==1 ? Effect_BossGuanHuan : Effect_BianYiGuanHuan`
## · `:1666-1677` 三档缩放：6000000/6000001 ⇒ 168*2/76 × 40*2/76；boss==1 ⇒ 168/76 × 40/76；
##   其余 ⇒ **118/126 × 28/126**
## · `:1664` `fps=40`（`autoTick=false` ⇒ 一帧 25ms，我们自己喂）⇒ 时间轴 80 帧
## · `:644-666` 图标排：一枚宽 30、第 i 枚 `x=i*(30+2)`、整排 `y=40`、
##   容器 `x = -30/2*枚数 + 30/2`（**枚数 = 列表长度**，图档查不到的那一枚不显但照样占位）
## · `PicTool.as:616-650` attrType→图：0 Money / 1 Hp / 4 Atk / 5 Def / 6 Bsk / 7 Avd / 16 Violent
##
## ⚠ 这道门顺手逮到的**断链**（修前实测）：`地图实体._on_server_monster_spawned` 拼 entry 时
## 只带了坐标，把 `_handle_spawn_monster_text` 解好的 `jingying` / `attacked_by_mob` 丢了 ⇒
## **在线怪的 `精英属性` 恒空**：血量/伤害的精英乘子（`战斗角色.clientCombatMaxHp`）静默退化，
## 光环与图标也永远出不来。判据 ② 就是钉这一条的（以前没有任何门能照到它）。
##
## 跑法：Godot --headless --path . --script res://测试/精英光环图标回归测试.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 环 := "精英外观"
const 光环名 := "光环"
const 图标排 := "精英图标排"
## 每段必须钉满的条数（协程被运行期报错打断 ⇒ 后面整段没跑而末行照样打「红 0」）
const 应判 := 18

var 红 := 0
var 判数 := 0
var 场: Node
var 后: Node
var 图号 := 0


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	call_deferred("_跑")


func _判(对: bool, s: String) -> void:
	判数 += 1
	if not 对:
		红 += 1
		print("红   " + s)


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


## 演员直接问地图场景要（`_活演员` 就是它自己内部用的那张表）—— 比按节点名扫树稳，
## 返回的是 `CombatActor`，`精英属性` 这类成员才拿得到（按 Node 拿会编译不过）。
func _演员(号: int) -> CombatActor:
	return 场.call("_活演员", 号) as CombatActor


## 出生帧原文 = 服务端 `_monster_spawn_payload`（段号见 `后端连接.gd:3435-3441` 那张表）。
## 27 段逐一对的是 `测试/原版协议抓包.json:76` 那条**真机原文**
## （`238:1:7001:0:1001001:<图>:300:400:0:0:0:0:true:0:300:400:0:0:-:-:-:0:false:false:false:0:0`），
## 不是自己拼的 —— 少一段就把"段号读错"这一族给测没了。
## `被打` 填进**第 23 段** = 原版 `MonsterSpawnInfo.as:125 readBoolean()` 的 `attackedByMob`。
func _出生帧(号: int, 模板: int, 精英串: String, 被打: bool = false) -> String:
	return "238:1:%d:0:%d:%d:1178:1018:0:1:1:0:true:0:1178:1018:0:0:-:%s:-:0:false:%s:false:0:0" % [
			号, 模板, 图号, 精英串, "true" if 被打 else "false"]


func _喂(号: int, 模板: int, 精英串: String, 被打: bool = false) -> void:
	后.call("_handle_bridge_text", _出生帧(号, 模板, 精英串, 被打))


func _环的(演员: CombatActor) -> Node2D:
	return 演员.get_node_or_null(环) as Node2D if 演员 != null else null


## 容器里面那一圈环本体（`精英外观.gd` 只是容器，缩放/帧表都在这一层）。
## ⚠ 别拿容器的 `scale` 当环的缩放：容器必须恒等于 (1,1)，否则它下面的图标排会被一起压扁
## （2026-10-22 第一版就栽在这，有头量具量出图标只有 57×7 像素）。
func _环件(演员: CombatActor) -> Node2D:
	var 环 := _环的(演员)
	return 环.get_node_or_null(光环名) as Node2D if 环 != null else null


func _图标们(演员: CombatActor) -> Array:
	var 出: Array = []
	var 排 := _环的(演员).get_node_or_null(图标排) as Node2D if _环的(演员) != null else null
	if 排 != null:
		for 子 in 排.get_children():
			出.append(子)
	return 出


func _档名(演员: CombatActor) -> String:
	var 件 := _环件(演员)
	return String(件.get("档名")) if 件 != null else ""


func _缩放(演员: CombatActor) -> Vector2:
	var 件 := _环件(演员)
	return 件.scale if 件 != null else Vector2(-1, -1)


func _帧数(演员: CombatActor) -> int:
	var 件 := _环件(演员)
	return (件.get("帧表") as Array).size() if 件 != null else -1


func _贴图名(片: Node) -> String:
	var 图 := (片 as Sprite2D).texture as Texture2D
	if 图 == null:
		return "〈没贴图〉"
	return String(图.resource_path).get_file()


func _跑() -> void:
	var 场景: Node = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _帧(60)
	场 = _找场(场景)
	后 = root.get_node_or_null("BackendConnection")
	if 场 == null or 后 == null:
		for i in 应判:
			_判(false, "找不到 地图场景 或 BackendConnection ⇒ 后面全部判不了")
		_收()
		return
	图号 = int(场.call("_get_current_map_id"))
	if 图号 <= 0:
		for i in 应判:
			_判(false, "当前图号取出来是 %d ⇒ 喂进去的出生帧会被地图过滤掉，后面全部判不了" % 图号)
		_收()
		return

	## ── ②③④⑥⑦ 一只"随机强化"的普通小怪（boss==0 + 两条精英属性）──
	## 模板 1000001 幼齿妖蛇：`数据/怪物.json` 里 boss=0 ⇒ 只有"带精英属性"这一条理由才该有环
	_喂(90001, 1000001, "0&5@4&3")
	await _帧(8)
	var 甲 := _演员(90001)
	_判(甲 != null, "① 喂一发真帧原文 ⇒ 在线怪必须建出来（查无 object_id=90001 的演员）")
	if 甲 == null:
		for i in 应判 - 1:
			_判(false, "① 之后全部判不了：怪没建出来")
		_收()
		return
	var 列表: Array = 甲.精英属性
	_判(列表.size() == 2,
			"② 服务端发的精英段必须落到演员身上（实得 %d 条，要 2 条）—— 这一条以前恒为 0：`_on_server_monster_spawned` 拼 entry 时把 jingying 丢了" % 列表.size())
	_判(_环的(甲) != null, "③ 带精英属性 ⇒ 必须有「%s」节点（原版 Monster.as:1659）" % 环)
	_判(_档名(甲) == "变异", "④ boss==0 的强化怪用**变异环**（实得 %s；`:1660` 那个三元只有 boss==1 才走首领环）" % _档名(甲))
	var 缩 := _缩放(甲)
	_判(absf(缩.x - 118.0 / 126.0) < 0.0001 and absf(缩.y - 28.0 / 126.0) < 0.0001,
			"⑤ 变异环缩放必须 = 118/126 × 28/126（实得 %.6f, %.6f）" % [缩.x, 缩.y])
	## ⚠ 每条判据自己挡 null：以前这里直接 `(_环的(甲) as CanvasItem).z_index`，
	## 环没建出来时**当场 SCRIPT ERROR 把整条协程吊死** ⇒ `quit()`  never 调用、无头进程挂到超时，
	## 变异实测跑不完（2026-10-22 第一次跑八条变异就死在这）。
	var 环的 := _环的(甲)
	var 环z := (环的 as CanvasItem).z_index if 环的 != null else -999
	_判(_帧数(甲) == 80 and 环z == -1,
			"⑥ 环的时间轴 80 帧（fps=40）且 z_index=-1（原版 ALayerType.BOTTOM ⇒ 画在身体后面；实得 %d 帧、z=%d）" % [
			_帧数(甲), 环z])
	var 片 := _图标们(甲)
	_判(片.size() == 2, "⑦ 两条精英属性 ⇒ 图标排必须 2 枚（实得 %d 枚）" % 片.size())
	if 片.size() == 2:
		var a := 片[0] as Sprite2D
		var b := 片[1] as Sprite2D
		## 容器 x = -30/2*2 + 30/2 = -15（`:665` 原式）；第 i 枚再 +i*(30+2)（`:660`）；整排 y=40（`:664`）。
		## ⚠ 这两个数是**图标正中**（Flash 的 x/y 指注册点，一枚时原式算出 0 ⇒ 端端正正压在脚点下）。
		## 注册点写成左上角（`centered = false`）整排会往右偏 15 像素 ⇒ 一并断言"贴图盒以节点原点为中心"。
		_判(absf(a.position.x + 15.0) < 0.001 and absf(b.position.x - 17.0) < 0.001
				and absf(a.position.y - 40.0) < 0.001 and absf(b.position.y - 40.0) < 0.001
				and a.get_rect().get_center() == Vector2.ZERO and b.get_rect().get_center() == Vector2.ZERO,
				"⑧ 两枚图标的**中心**应在 (-15,40) 与 (17,40)、且贴图以自身原点为中心（注册点在正中）；实得 (%.1f,%.1f) 与 (%.1f,%.1f)、贴图盒中心 %s 与 %s" % [
				a.position.x, a.position.y, b.position.x, b.position.y,
				str(a.get_rect().get_center()), str(b.get_rect().get_center())])
		_判(_贴图名(a) == "1.png" and String((a.texture as Texture2D).resource_path).contains("EliteMob_Money")
				and String((b.texture as Texture2D).resource_path).contains("EliteMob_Atk"),
				"⑨ attrType 0→Money、4→Atk（实得 %s / %s）" % [
				String((a.texture as Texture2D).resource_path).get_basename(),
				String((b.texture as Texture2D).resource_path).get_basename()])
	else:
		for i in 2:
			_判(false, "⑦ 图标只有 %d 枚 ⇒ ⑧⑨ 判不了" % 片.size())
	## ⑯ 图标排要**抬回身体之前**：环整体 z=-1（原版 `AuraLayerItem.aLayerType = ALayerType.BOTTOM`），
	## 而图标是 `:663 addChild(_loc2_)` 直接挂在怪自己身上 ⇒ 该层最上。
	## 我们靠 `精英外观.gd` 里那句 `图标排.z_index = 1` 抵回来（-1 + 1 = 与精灵同 z、再按树序盖前）。
	var 排 := (环的.get_node_or_null(图标排) as CanvasItem) if 环的 != null else null
	_判(排 != null and 排.z_index == 1,
			"⑯ 图标排 z_index 必须 = 1（环在 -1，图标要盖回身体之前；实得 %s）" % str(排.z_index if 排 != null else "〈没有图标排节点〉"))
	## ⑰ 图标排的**有效缩放**必须是 1：它只能挂在容器下，一旦挂进带压扁缩放的「光环」里，
	## 30×30 的图标会被 `scaleY = 28/126` 压成 7 高、y=40 抬到 y=9（第一版实测差异盒 57×7）。
	var 排全: Vector2 = 排.global_transform.get_scale() if 排 != null else Vector2(-1, -1)
	_判(环的 != null and 环的.scale == Vector2.ONE and 排全.distance_to(Vector2.ONE) < 0.001,
			"⑰ 容器 scale 与图标排的有效缩放都必须 = (1,1)（缩放只许落在「%s」那一层；实得 容器=%s、图标排全局=%s）" % [
			光环名, str(环的.scale) if 环的 != null else "〈无容器〉", str(排全)])

	## ── ⑩ boss==2 的 authored 精英（用户图里那隻【精英】木叶叛忍）⇒ 变异环、**没有图标** ──
	_喂(90002, 2000001, "-")
	await _帧(8)
	var 乙 := _演员(90002)
	_判(乙 != null and _环的(乙) != null and _档名(乙) == "变异" and _图标们(乙).is_empty(),
			"⑩ boss==2 的怪：要有变异环（档=%s）、没有精英图标（实得 %d 枚）—— 环的条件是 boss==2 那一半" % [
			_档名(乙), _图标们(乙).size()])

	## ── ⑪⑫ boss==1 的首领环 + 6000001 那一档翻倍 ──
	_喂(90003, 2100001, "-")
	await _帧(8)
	var 丙 := _演员(90003)
	var 缩丙 := _缩放(丙)
	_判(_档名(丙) == "首领", "⑪ boss==1 必须走**首领环**（实得 %s）" % _档名(丙))
	_判(absf(缩丙.x - 168.0 / 76.0) < 0.0001 and absf(缩丙.y - 40.0 / 76.0) < 0.0001,
			"⑫ 首领环缩放 = 168/76 × 40/76（实得 %.6f, %.6f）" % [缩丙.x, 缩丙.y])
	_喂(90004, 6000001, "-")
	await _帧(8)
	var 丁 := _演员(90004)
	var 缩丁 := _缩放(丁)
	_判(_档名(丁) == "首领" and absf(缩丁.x - 168.0 * 2 / 76.0) < 0.0001
			and absf(缩丁.y - 40.0 * 2 / 76.0) < 0.0001,
			"⑬ mobId 6000001（八尾）⇒ 首领环再放大一倍（档=%s、实得 %.4f, %.4f）" % [_档名(丁), 缩丁.x, 缩丁.y])

	## ── ⑭ 普通怪（boss==0、无精英）⇒ **不许**有环 ──
	_喂(90005, 1000002, "-")
	await _帧(8)
	var 戊 := _演员(90005)
	_判(戊 != null and _环的(戊) == null, "⑭ 没精英、boss==0 的普通怪不许挂环（实得 %s）" % (
			"〈无环〉" if 戊 != null and _环的(戊) == null else str(_环的(戊) != null)))

	## ── ⑮ 表里没有的 attrType：原版返回 null ⇒ 不显那一枚，但**容器仍按列表长度居中** ──
	_喂(90006, 1000003, "99&2@0&5")
	await _帧(8)
	var 己 := _演员(90006)
	var 片己 := _图标们(己)
	_判(片己.size() == 1 and absf((片己[0] as Sprite2D).position.x - 17.0) < 0.001,
			"⑮ 未知档 99 不显形、但占位（枚数按列表长度 2 算 ⇒ 那枚 Money 落在 x=17；实得 %d 枚、x=%s）" % [
			片己.size(), "%.1f" % ((片己[0] as Sprite2D).position.x if not 片己.is_empty() else -999.0)])

	## ── ⑱ 断链的另一半：`attackedByMob`（第 23 段）也要落到演员身上 ──
	## 挂机挑怪那条闸（`SkillHandler.canAttack:447-450` ⇒ `挂机托管.可打`）读的就是这个 meta；
	## 以前 entry 没带 ⇒ 整条闸等于不存在。`测试/挂机行为回归测试.gd:715` 是**手工 set_meta**，
	## 照不到"服务端发了但没传下去"这一族 ⇒ 只有从真帧原文走一遍才算。
	_喂(90007, 1000004, "-", true)
	await _帧(8)
	var 庚 := _演员(90007)
	_判(庚 != null and bool(庚.get_meta("attacked_by_mob", false)),
			"⑱ 出生帧第 23 段 true ⇒ 演员的 attacked_by_mob 必须为真（实得 %s；演员建出来=%s）" % [
			str(庚.get_meta("attacked_by_mob", false)) if 庚 != null else "〈无演员〉", str(庚 != null)])
	_收()


func _收() -> void:
	if 判数 < 应判:
		红 += (应判 - 判数)
		print("红   只判了 %d 条，不足 %d 条 ⇒ 中间有段被运行期报错打断" % [判数, 应判])
	print("精英光环图标回归测试：判 %d 条 / 红 %d 条" % [判数, 红])
	quit(0 if 红 == 0 else 1)
