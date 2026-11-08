extends SceneTree
## 宠物装备格（右侧 5 格）的**落点判定**回归。
##
## 为什么单独钉：这 5 格是 2026-09-28 重建主窗时才接上拖放的，原版对应
## `SimpleItemCell.dropItemFun = petPutOnEquip`（`PetWindow.as:502`）。判据是**部位**，
## 走**公共表** `装备部位.gd:97` 的 `位置(id) == 槽位号`
## （`0201→宠物一(兽铠) … 0205→宠物五(变身)`，与人物面板 `装备格.gd` 同一条），
## 服务端 `_put_on_pet_equipment` 再复核等级/部位。
## ⚠️ 这条用例**当天就抓到一个真 bug**：场景里那 5 格的节点名原来是按**屏幕摆位**编的
## （`装备槽_2` 在中间、其实是变身位 = 部位 5），渲染又把"第几个循环"当部位号塞进去，
## 于是兽爪/变身两格装反。现已把节点名改成**等于部位号**。
##
## ⚠️ 离线没有后端，`equip_pet_item_by_id` 里 `_online_backend() == null` 会直接返回 false，
## 所以本用例**只钉落点判定**（那是我们自己的逻辑），不钉"真的穿上"——
## 真穿的服务端事务在 `宠物真实事务回归测试` 那条在线用例里。

const 兽铠 := "02010060"   # 部位 1
const 兽爪 := "02020070"   # 部位 2
const 兽符 := "02030060"   # 部位 3
const 兽盔 := "02040060"   # 部位 4
const 变身 := "02050404"   # 部位 5
const 普通武器 := "01010013"   # 不是宠物装备

var _failures: Array[String] = []
var _会话: Node
var _宠窗: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://场景/地图/地图场景.tscn") as PackedScene
	if packed == null:
		_failures.append("无法加载地图场景")
		_finish()
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	for _帧 in range(5):
		await process_frame

	_会话 = root.get_node_or_null("GameSession")
	## 10-12 修：这道门以前**直接吃存档里剩什么** —— 别的离线门把 `pets` 写成空，它就红
	## （#166 那一类"离线门读共享存档"的复发形态）。改成**开窗之前**先从出厂夹具种一份：
	## 五枚装备格的归属/槽号/拖放信号是**渲染那一次**按宠物条数建的，开窗之后再补就晚了。
	if _会话 != null and _会话.pets.is_empty():
		var 出厂: Dictionary = (load("res://脚本/单例/离线示例数据.gd") as GDScript).create()
		_会话.pets.assign(出厂.get("pets", []))
	var 管理 := scene.get_node_or_null("窗口管理")
	# ⚠️ 要用 `打开`（它才会 open_page 渲染）；`取或建窗口` 只建空壳，页面是空的
	if 管理 != null:
		管理.call("打开", "宠物")
	_宠窗 = 管理.call("取窗口", "宠物") if 管理 != null else null
	if _会话 == null or _宠窗 == null:
		_failures.append("拿不到 GameSession 或宠物窗口")
		_finish()
		return
	for _帧 in range(3):
		await process_frame

	var 内容: Control = _宠窗.get("_content")
	var 页面 := 内容.get_node_or_null("原版宠物窗口内容")
	if 页面 == null:
		_failures.append("宠物页面没建出来")
		_finish()
		return
	var 宠物: Dictionary = _会话.pets[0] if not _会话.pets.is_empty() else {}
	if 宠物.is_empty():
		_failures.append("离线示例宠是空的，先补 离线示例数据")
		_finish()
		return

	var 格表 := {}
	for 号 in [1, 2, 3, 4, 5]:
		var 格 := 页面.get_node_or_null("装备槽_%d" % 号)
		if 格 == null:
			_failures.append("缺装备槽_%d" % 号)
			continue
		格表[号] = 格
		if String(格.get("格子归属")) != "宠物装备":
			_failures.append("装备槽_%d 的格子归属没设成 宠物装备" % 号)
		# 部位判据走公共表 装备部位.gd（宠物一..五 = 1..5），格子上的槽位号就是它
		if int(格.get("槽位号")) != 号:
			_failures.append("装备槽_%d 的槽位号是 %s" % [号, 格.get("槽位号")])
		var 拖放信号: Signal = 格.get("拖放")
		if 拖放信号 == null or 拖放信号.get_connections().is_empty():
			_failures.append("装备槽_%d 的拖放信号没接上（拖进去会没反应）" % 号)
	if 格表.size() != 5:
		_finish()
		return

	var 来源 := _造来源格("背包")

	# ① 部位对得上 → 接受（五件各进各的格）
	for 件 in [[兽铠, 1], [兽爪, 2], [兽符, 3], [兽盔, 4], [变身, 5]]:
		var 载荷 := _载荷(来源, String(件[0]))
		if not bool(格表[件[1]].call("_can_drop_data", Vector2.ZERO, 载荷)):
			_failures.append("%s 落在装备槽_%d 上竟然被拒" % [件[0], 件[1]])

	# ② 部位对不上 → 拒（兽铠落在别的四格上）
	for 号 in [2, 3, 4, 5]:
		var 载荷 := _载荷(来源, 兽铠)
		if bool(格表[号].call("_can_drop_data", Vector2.ZERO, 载荷)):
			_failures.append("兽铠落在装备槽_%d（非兽铠位）竟然被接受" % 号)

	# ③ 不是宠物装备 → 拒（普通武器 id/10000 = 101，哪个部位都对不上）
	for 号 in [1, 2, 3, 4, 5]:
		var 载荷 := _载荷(来源, 普通武器)
		if bool(格表[号].call("_can_drop_data", Vector2.ZERO, 载荷)):
			_failures.append("普通武器落在装备槽_%d 竟然被接受" % 号)

	# ④ 来源不是背包（例如随身仓库）→ 拒（与人物面板同一条：原版只认 ITEM_WINDOW 来源）
	var 仓库来源 := _造来源格("仓库")
	var 载荷仓 := _载荷(仓库来源, 兽铠)
	if bool(格表[1].call("_can_drop_data", Vector2.ZERO, 载荷仓)):
		_failures.append("仓库来的兽铠落在装备槽_1 竟然被接受")

	# ⑤ 宠物装备格自己起不了拖（只接不吐，与原版一致）
	if 格表[1].call("_get_drag_data", Vector2.ZERO) != null:
		_failures.append("宠物装备格竟然能当拖拽源")

	if _failures.is_empty():
		print("宠物装备拖拽回归测试：通过（部位对得上才接 / 非宠物装备拒 / 非背包来源拒 / 只接不吐）")
		quit(0)
	else:
		for f in _failures:
			push_error("宠物装备拖拽回归测试：失败 - %s" % f)
		quit(1)


## 造一个"来源格"：真的物品格组件，只填拖放判定要用的那几个字段。
func _造来源格(归属: String) -> Button:
	var 格 := Button.new()
	格.set_script(load("res://脚本/界面/组件/可拖拽格.gd"))
	格.set("格子归属", 归属)
	root.add_child(格)
	return 格


func _载荷(来源: Button, 物品id: String) -> Dictionary:
	return {"来源格": 来源, "归属": String(来源.get("格子归属")), "物品id": 物品id}


func _finish() -> void:
	for f in _failures:
		push_error("宠物装备拖拽回归测试：失败 - %s" % f)
	quit(1 if not _failures.is_empty() else 0)
