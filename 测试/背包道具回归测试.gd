extends SceneTree

## 背包/道具这六个洞的离线回归（2026-10-01 用户进入"背包和道具"阶段后扫出的）。
## 每条都有 AS3/服务端出处，**没有一条是自造行为**：
##   ① 销毁件数：`背包窗口` 的销毁确认用 (id,件数) 两参调 `_discard_item`，
##      旧签名一参 ⇒ GDScript Invalid call，销毁点了=没点（门里用真信号端到端钉）。
##   ② 全部使用：原版 useAll 在 USE_ITEM 报文第 4 段（`PacketCreator.as:396-404`）——
##      **那只有一个布尔槽、双语义**：`info.useAll` 的礼包类整摞吃
##      （`fake_flash_server.py:50234-50246`），回复药剂则是"自动喝药请求"
##      （满血不消耗，`:50374-50398`；见 §3.80.1-2）。客户端 `use_all` 列由
##      `开发工具/导出物品use_all.py` 从服务端 catalog 补齐；离线按保守口径模拟。
##      菜单出现判据照 `filtrateItemMenu :520`（`useAll!=1` 就没有「全部使用」那一项）。
##   ③ 出售价：原版 `ShopWindow2.as:151-158` 单价 = `floor(price/3)`（price>0 下限 1），
##      弹窗显示与实际进账必须是同一个算式（旧离线进账是 `price/2` 自造）。
##   ④ 拖拽换位：在线发包回包驱动；离线照服务端交换语义
##      （`fake_flash_server.py:47483-47491`），稳定格位制下（见⑦）空格/洞都放得下。
##   ⑤ 拆分：在线 ITEM_SPLIT 发包；离线源摞减量 + 拆出的进第一个空格（洞优先复用）。
##   ⑥ 拆分入参校验：`数量>=总件数` 拒（拆了等于没拆的态不允许）。
## ㉑（2026-10-17 巡检 #16）使用/出售/存/取**按格**：这四条原来按 id 反查第一摞，
##    同 id 两摞时点第二摞动的是第一摞；销毁⑩、绑定⑪早就按格了，这里补上余下四条。
## ㉒（2026-10-18 巡检 #27）给通灵兽佩戴：**宠物那 5 槽的位置是正数 1..5**，而服务端
##    `handle_item_move` 只把 `destination < 0` 当装备位 ⇒ 旧写法（兽铠也进
##    `useItem → request_item_move(0, 格, 1..5, 0)`）发出去的报文实际是
##    **"把这一件和背包第 1..5 格对调"**，一件也没穿上。现在按原版在 `use_inventory_slot`
##    开头分叉，菜单「宠物佩戴」与双击两个入口都走 `equip_pet_item_from_bag`，
##    并补上原版那条**不可逆绑定**的二次确认（绿/紫 + 可交易才弹）。
## ㉓（2026-10-19 体检报告 #44）底部五颗钮 + 菜单兜底：点下去弹的那句话要**点名缺的是哪条协议**，
##    且必须写在**看得见**的 `后端状态` 上（旧写法五颗共用一句"本轮未实现"，玩家分不清坏了还是没做）。
## ㉔（2026-10-31 用户口径五轮）每页 90 格：10 列 x 9 行、9 行一屏全露、格区不滚。
##    格 40x40（复用 `物品格.tscn`，与 `装备格.tscn` 同高）、横距 42 / 纵距 40，窗口 453x556。
##    第三轮用户：「格子左右两边空了一格」—— 旧写法把 364 见方的格区在页里居中（44..408），
##    左右各剩 37/36 白边；格区与格区底同框（11..444），格子从九宫格内沿 19 铺到 437。
##    第四轮用户：「单格高度改小了、图标越过格子下边框」「最下一行还越过下框」——
##    格子回到 40 高（34 图标 + 6px 描边都在格内）。
##    第五轮用户：「除了格子数，其他布局不要做改变」—— 版式回第三轮原样（453 宽、货币三行
##    在左下、底部四键 + 右列三键原位），格区框回到 71..435（364 高）；40 高一格只装得下
##    9 行（4 + 9×40 = 364）⇒ 每页 90 格，末行下沿正好落在框下沿。
##    滚一开 ScrollContainer 会把滚动条宽 19 算进最小尺寸、把视口撑出页面，所以两轴都
##    SCROLL_MODE_DISABLED。
##    **有意偏离原版** 30 格/页（`ItemWindow2.as:1333`），页数仍 9 ⇒ 上限 810；
##    门钉格子数/坐标/格尺寸、容器与视口同大、格区底与内层底的下沿、底部控件在框内、
##    窗口尺寸表与 tscn 同值、分页槽位号（1..90、91..）、
##    末页只画真实格位（合成的容量 128 ⇒ 第 2 页只露 38 格、标题仍 …/128）。
##    真档里 128 不会出现：服务端读档就补整页（`page_aligned_capacity`，128 → 180），
##    这里是客户端防御层——收到非整页容量也不能画出点不到的假空格。
##
## ⚠️ 本门每步都会 `_save_local_state()` 落盘 user:// ⇒ 开场快照、收尾**还原并再落盘**
##    （§3.76.1 规约；新门先连跑两遍，第二遍红=第一遍污染了存档）。
##
## 运行：Godot --headless --path . --script res://测试/背包道具回归测试.gd

var _失败: Array[String] = []
var _受检 := 0
var _快照: Dictionary = {}
## 内存态还原后再 `_save_local_state()` 的**字节并不等于磁盘原文件** ⇒ 再加一层文件级快照。
const 门存档快照 := preload("res://测试/门存档快照.gd")
## `字体落点()`：default_font 自 2026-10-25 起是 FontVariation（合成加粗），裸 `resource_path` 是空的。
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
var _文件前 := {}

var _秒 := 0.0

func _initialize() -> void:
	_文件前 = 门存档快照.全快照()
	call_deferred("_run")


## 秘笈合成窗的"放入态"是**静态变量** `_放入格`（1 基槽位）—— 实例上 `get()` 取不到静态量，
## 只能按脚本读（⑭ 那条端到端断言要用）。
const 秘笈合成窗脚本 := preload("res://脚本/界面/窗口/秘笈合成窗口.gd")
## 常量（`伴随背包`）只能从脚本资源的常量表里取，实例 `get()` 拿不到。
const 管理脚本 := preload("res://脚本/界面/窗口管理.gd")
## 徽章打造窗的当前页也是静态量（`当前页()` 是静态取值口）。
const 徽章打造窗脚本 := preload("res://脚本/界面/窗口/徽章打造窗.gd")
## ⑯ 那条要钉"昆虫 vs 勾玉"的 id 空间假设，用它的位置口径问。
const 装备部位 := preload("res://脚本/单例/装备部位.gd")
## ㉓ 底部那三颗占口钮的"缺的是哪一条"要**当场点对、当场比**，所以拿真表比对而不是抄一份。
## （2026-10-19 §3.222：第五颗「神秘商店」已经接上 ⇒ 它不在这张表里了，改成断"只发一跳、不开窗"。
##  2026-10-20 §3.223：「随身药店」也接上了 ⇒ 表里只剩三颗，它走另一扇门。）
const 背包窗口脚本 := preload("res://脚本/界面/窗口/背包窗口.gd")


## ⑲ 用的假后端：只认破碎修复那一条（原版 `requestRecoverEquip` = 子命令 8）。
class 假后端 extends Node:
	var 收到: Array = []

	func request_recover_equipment(背包格: int) -> bool:
		收到 = ["recover:%d" % 背包格]
		return true

	## ⚠️ 反向对照用：真代码若走成**子命令 7（NPC 商店的修理，修身上全部）**那条，门要**红**而不是崩——
	## 假后端缺方法时 `call` 会抛 Invalid call、协程当场断、看门狗才超时（撞过一次）。
	func request_repair_equip(修理方式: int) -> bool:
		收到 = ["repair:%d" % 修理方式]
		return true

	## ㉓「神秘商店」那颗钮 = NPC_SHOP **动作 6**（`Client.as:4411-4417 requestSecretShopOpen`
	## → `NPCShopProcessor.requestSecretShopOpen`）。它**只发一跳**，开窗的是回帧 `324:`，
	## 所以这一条断的是"发出去的子命令号"，不是"窗开没开"。
	func request_secret_shop_open() -> bool:
		收到 = ["6"]
		return true

	## ⑳ 灵器炼制三条（`LING = 2081` 子命令 0 开光 / 1 灵化 / 2 洗炼）。
	func request_ling_equip_kai_guang(物品号: int, 格: int) -> bool:
		收到 = ["0:%d:%d" % [物品号, 格]]
		return true

	func request_ling_equip_ling_hua(物品号: int, 格: int) -> bool:
		收到 = ["1:%d:%d" % [物品号, 格]]
		return true

	func request_ling_equip_wash(物品号: int, 格: int) -> bool:
		收到 = ["2:%d:%d" % [物品号, 格]]
		return true

	## ⑳b 人具开光走 `RENJU = 2082` 子命令 0（版式同一扇窗、只换协议）。
	func request_renju_kai_guang(物品号: int, 格: int) -> bool:
		收到 = ["renju0:%d:%d" % [物品号, 格]]
		return true

## 看门狗：协程里任何没被守卫住的崩溃（Index 越界/空引用）都不会走到 quit ——
## 无头进程**永久挂起**，而且**快照还原不执行、脏存档留在盘上坑别的门**
## （R2 反向跑就是这么把 `格子悬停` 饿红的）。超时就还原快照、报红退出。
func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 120.0:
		_收尾()
		printerr("背包道具回归测试：看门狗超时（120s）—— 中途崩了没走到收尾，已强制还原快照")
		quit(1)
	return false

func _查(ok: bool, 话: String) -> void:
	_受检 += 1
	if not ok:
		_失败.append(话)

func _件(物品id: String, 件数: int, 补丁 := {}) -> Dictionary:
	var 条 := {"id": 物品id, "name": 物品id, "category": "消耗品",
			"quantity": 件数, "hp": 10, "price": 20,
			# 种子也要带 icon：背包格子渲染只在 `ResourceLoader.exists(icon)` 时才摆图标，
			# `格子悬停提示回归测试` 按 `icon != null` 认"有货格" —— 不带 icon 的脏种子
			# 会把**别的门**饿着（2026-10-01 R2 崩溃跑污染存档后就是这样连环红的）。
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"}
	条.merge(补丁, true)
	return 条

func _run() -> void:
	var 会话 := root.get_node("/root/GameSession")
	_快照 = {
		"player_stats": (会话.player_stats as Dictionary).duplicate(true),
		"inventory": (会话.inventory as Array).duplicate(true),
		"storage": (会话.storage as Array).duplicate(true),
		"equipped_items": (会话.equipped_items as Dictionary).duplicate(true),
	}
	var 菜单脚本 := load("res://脚本/界面/组件/物品菜单.gd")

	# —— ②a 菜单：可全吃才有「全部使用」；件数=1 连「拆分」都要没有 ——
	var 项全吃: Array = 菜单脚本.取菜单项({"id": "11000021", "quantity": 3, "use_all": 1})
	_查(项全吃.has("全部使用"), "可全吃的多件摞菜单应有「全部使用」（实际 %s）" % [项全吃])
	var 项拉面: Array = 菜单脚本.取菜单项({"id": "03000001", "quantity": 5})
	_查(not 项拉面.has("全部使用"), "拉面（服务端 use_all=False）不该有「全部使用」")
	var 项单件: Array = 菜单脚本.取菜单项({"id": "11000021", "quantity": 1, "use_all": 1})
	_查(not 项单件.has("拆分"), "件数=1 不该有「拆分」（filtrateItemMenu :516）")
	# 离线的物品字典不带 use_all 时**回表**（表由导出器补好）—— 这是以前整列缺失的主症状
	# ⚠️ 2026-10-11：这条**必须两种 id 形态各判一次**（`filtrateItemMenu:508` 是
	#    `String(id).substr(0,3) == 131`，在**未补零**的整数形态上判 ⇒ 昆虫(`1310001`)、
	#    勾玉(`13100000`) 都命中）。只写前三位的话，昆虫会多出「宝石镶嵌」。
	_查(not (菜单脚本.取菜单项({"id": "01310001", "quantity": 1}) as Array).has("宝石镶嵌"),
			"昆虫（`01310001`，四位码 131）的菜单**不该有「宝石镶嵌」**（`:508`）")
	_查(not (菜单脚本.取菜单项({"id": "13100000", "quantity": 1}) as Array).has("宝石镶嵌"),
			"勾玉（`13100000`，前三位 131）的菜单也不该有「宝石镶嵌」")
	_查((菜单脚本.取菜单项({"id": "01010011", "quantity": 1}) as Array).has("宝石镶嵌"),
			"普通装备**该有**「宝石镶嵌」（反向哨兵：别把这一项一刀切掉）")
	var 项回表: Array = 菜单脚本.取菜单项({"id": "11000021", "quantity": 3})
	_查(项回表.has("全部使用"), "离线件没带 use_all 字段时要回 `数据/物品.json` 兜底（列已补齐）")

	# —— ②b 离线全部使用：use_all=1 整摞、=0 只吃 1 ——
	会话.inventory.clear()
	会话.inventory.append(_件("11000021", 5, {"use_all": 1}))
	会话.player_stats["max_hp"] = 100
	会话.player_stats["hp"] = 1
	_查(bool(会话.call("use_inventory_item", "11000021", true)), "全部使用应返回 true")
	_查(_背包件数(会话, "11000021") == 0, "整摞 5 个应吃完（实际 %d）" % _背包件数(会话, "11000021"))
	_查(int(会话.player_stats.get("hp", 0)) == 51,
			"5 口 ×10 回复（1 起步）应到 51，实际 %s" % str(会话.player_stats.get("hp", 0)))
	会话.inventory.append(_件("03000001", 5, {"use_all": 0}))
	会话.call("use_inventory_item", "03000001", true)
	# 离线保守口径：非 use_all 件误传"全部"也只吃 1（药剂在线的那半语义是"自动喝药请求"，
	# 满血不消耗 —— 见 `游戏会话.use_inventory_item` 头注；菜单本来不会给药剂列「全部使用」）。
	_查(_背包件数(会话, "03000001") == 4, "非 use_all 件传了全部也只吃 1")

	# —— ① 销毁：按件数扣 + 真信号端到端 ——
	会话.inventory.clear()
	会话.inventory.append(_件("03000001", 4))
	_查(bool(会话.call("discard_item", "03000001", 2)), "discard_item 带件数应成功")
	_查(_背包件数(会话, "03000001") == 2, "销毁 2 后应剩 2（实际 %d）" % _背包件数(会话, "03000001"))
	# 销毁确认信号 → `_discard_item(id, 件数)`：旧一参签名在这里必 INVALID CALL（数量不动）
	var 场景 := (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	await process_frame
	场景.call("open_page", "背包")
	for _i in 4:
		await process_frame
	var 页 := 场景.find_child("原版背包内容", true, false) as Control
	if 页 == null:
		_失败.append("背包页没建出来")
	else:
		var 销毁窗 := 页.get_node_or_null("销毁窗口") as Control
		_查(销毁窗 != null, "背包页上应有销毁窗口节点")
		if 销毁窗 != null:
			销毁窗.emit_signal("确认销毁", "背包", 1, "03000001", 1)
			await process_frame
			_查(_背包件数(会话, "03000001") == 1,
					"销毁窗确认(件数1)应真扣 1（旧签名两参调用必报错、什么都没扣）")
	_查(true, "端到端段跑完不崩（元数匹配的哨兵）")
	场景.queue_free()
	await process_frame

	# —— ③ 出售价 = floor(price/3)（与买卖数量窗同一算式）——
	会话.inventory.clear()
	会话.inventory.append(_件("03000001", 3, {"price": 20}))
	会话.player_stats["gold"] = 100
	_查(bool(会话.call("sell_inventory_item", "03000001", 2)), "出售应成功")
	_查(int(会话.player_stats.get("gold", 0)) == 100 + 6 * 2,
			"卖 2 个 20 价件进账 2×floor(20/3)=12，实际 %s" % str(会话.player_stats.get("gold", 0)))
	_查(_背包件数(会话, "03000001") == 1, "卖掉 2 应剩 1")
	会话.inventory.append(_件("03000002", 1, {"price": 2}))
	会话.player_stats["gold"] = 0
	会话.call("sell_inventory_item", "03000002", 1)
	_查(int(会话.player_stats.get("gold", 0)) == 1, "price>0 单价下限 1（floor(2/3)=0 → 1）")

	# —— ④ 离线换位（对调 / 移尾格 / 非法目标）——
	会话.inventory.clear()
	会话.inventory.append(_件("AAAA1111", 1, {"slot_index": 1}))
	会话.inventory.append(_件("BBBB1111", 1, {"slot_index": 2}))
	_查(bool(会话.call("move_inventory_items", 1, 2)), "对调应成功")
	if 会话.inventory.size() == 2:
		_查(String(会话.inventory[0].get("id", "")) == "BBBB1111"
				and String(会话.inventory[1].get("id", "")) == "AAAA1111", "对调后顺序应反过来")
		_查(int(会话.inventory[0].get("slot_index", 0)) == 1
				and int(会话.inventory[1].get("slot_index", 0)) == 2,
				"slot_index 要跟着格子走（字段和下标不许各说各话）")
	else:
		_查(false, "对调段前置就缺两件（实际 %d），后面索引跳过" % 会话.inventory.size())
	_查(bool(会话.call("move_inventory_items", 1, 3)), "移到尾后第一空格应成功")
	if 会话.inventory.size() == 2:
		_查(String(会话.inventory[1].get("id", "")) == "BBBB1111", "尾移后 [A,B]→[B,A]（B 留在原位）")
	_查(not bool(会话.call("move_inventory_items", 1, 999)), "超出格容量(96)的目标要拒")
	_查(not bool(会话.call("move_inventory_items", 2, 2)), "同格自己换位要拒")

	# —— ⑤/⑥ 离线拆分 ——
	会话.inventory.clear()
	会话.inventory.append(_件("03000001", 5, {"slot_index": 1}))
	_查(bool(会话.call("split_inventory_item", 1, 2)), "5 拆 2 应成功")
	_查(会话.inventory.size() == 2 and _背包件数(会话, "03000001") == 5,
			"拆完两摞合计守恒（3+2=5，实际 %d）" % _背包件数(会话, "03000001"))
	# 索引前判长度：反向对照时这里可能只有一摞 —— 协程里炸 Invalid access 会**永不 quit**
	# （挂起的跑批比红更难查），门必须"红得下来"而不是崩。
	if 会话.inventory.size() >= 2:
		var 第二摞: Dictionary = 会话.inventory[1]
		_查(int(第二摞.get("quantity", 0)) == 2 and int(第二摞.get("slot_index", 0)) == 2,
				"拆出的摞占尾后第一空格（格 2）")
	else:
		_查(false, "拆完应有两摞可查（实际 %d 摞，后面索引跳过）" % 会话.inventory.size())
	_查(not bool(会话.call("split_inventory_item", 1, 5)), "拆出数>=源件数要拒")
	_查(not bool(会话.call("split_inventory_item", 1, 0)), "0 件要拒")

	# —— ⑦ 稳定格位（2026-10-01 用户报②"使用后背包自动整理"的核心回归）——
	# 三件：格1 / 格2(消耗摞×9) / 格3。先吃一口（9→8，位置就该已经不许动），
	# 再按格销光中间那摞 → 格2 变洞；两边的件**任何一步都不许位移**。
	会话.inventory.clear()
	会话.inventory.append(_件("AAAA1111", 1))
	会话.inventory.append(_件("03000001", 9))
	会话.inventory.append(_件("CCCC1111", 1))
	会话.player_stats["hp"] = 1
	会话.player_stats["max_hp"] = 999
	会话.call("use_inventory_item", "03000001")          # 9→8
	_查(String(会话._占用条(会话.inventory, 3).get("id", "")) == "CCCC1111",
		"吃一口后格3 的件不许动（旧紧凑数组：吃光才位移，这里先钉不位移）")
	_查(bool(会话.call("discard_inventory_slot", 2, 8)), "按格销光中间摞应成功")
	_查(会话._占用条(会话.inventory, 2).is_empty(), "吃空的那格留洞（不许拿后面的件填上来）")
	_查(String(会话._占用条(会话.inventory, 1).get("id", "")) == "AAAA1111"
			and String(会话._占用条(会话.inventory, 3).get("id", "")) == "CCCC1111",
			"洞的两侧件格号原样（1/A、3/C）")
	_查(会话._占用数(会话.inventory) == 2, "占格数=2（标题用它，不再 size()）")
	会话.call("_add_inventory_item", {"id": "04000001", "name": "牛奶", "category": "消耗品"}, 2)
	_查(String(会话._占用条(会话.inventory, 2).get("id", "")) == "04000001",
		"新到货落进第一个洞（格2），不许无脑追加到尾")
	# —— ⑧ 同 id 穿着不再误报（用户报①：销毁背包那条，身上戴的是另一条）——
	会话.equipped_items[-4] = _件("01040011", 1, {"category": "装备"})
	会话.inventory.clear()
	会话.inventory.append(_件("01040011", 1, {"category": "装备"}))
	_查(bool(会话.call("discard_item", "01040011", 1)),
		"身上戴着同 id 的件**不许**拦背包这格的销毁（原版按格位，从无此检查；旧误报=用户报①）")
	_查(会话._占用条(会话.inventory, 1).is_empty() and not 会话.equipped_items[-4].is_empty(),
		"销掉的是背包那一格；身上那条原样不动")

	# —— ⑨ 拖到空处判定表（`ItemWindow2.destroyItem:633-678`，
	#   值线判据 `curEquipStage <= stage` 是**档<=阶**进确认组）——
	var 背包脚本 := load("res://脚本/界面/窗口/背包窗口.gd")
	会话.player_stats["level"] = 10                       # 档1
	var 决 := func(条: Dictionary) -> String:
		return String(背包脚本.拖放销毁决定(会话, 条))
	_查(决.call({"id": "03000001"}) == "销毁", "药剂(类型3) → 直接销")
	_查(决.call({"id": "16000016"}) == "确认", "强化灵珠(类型16 辅助物品) → 确认")
	_查(决.call({"id": "12100000"}) == "确认", "千手柱间卡(类型12 材料) → 确认（原版 case 群里有它，别自作主张挪走）")
	_查(决.call({"id": "13000001"}) == "确认", "宝石(类型13) → 确认")
	_查(决.call({"id": "11000021"}) == "确认", "礼包(类型11) → 确认")
	_查(决.call({"id": "01010011", "strengthen": 3}) == "确认", "强化过的武器 → 确认")
	_查(决.call({"id": "01010011", "aptitude": 4}) == "确认", "紫武器 → 确认")
	_查(决.call({"id": "01010011", "inlays": [{}, {}]}) == "确认", "有镶嵌 → 确认")
	_查(决.call({"id": "01210011"}) == "确认", "时装(21) → 确认")
	_查(决.call({"id": "01010011"}) == "确认", "lv10(档1) 对 1 阶白装：档<=阶(1<=1) 成立 → 确认组（防记反）")
	会话.player_stats["level"] = 45                       # 档3
	_查(决.call({"id": "01010011"}) == "销毁", "lv45(档3) 对 1 阶白装：3<=1 不成立、其余不命中 → 直接销")
	_查(决.call({"id": "01010011", "strengthen": 1}) == "确认", "高角色档也拦不住强化过的件 → 确认")

	# —— ⑩ 按格销毁精确到那一格 ——
	会话.inventory.clear()
	会话.inventory.append(_件("03000001", 2))
	会话.inventory.append(_件("03000001", 3))
	_查(bool(会话.call("discard_inventory_slot", 2, 1)), "按格销应成功")
	_查(int(会话._占用条(会话.inventory, 1).get("quantity", 0)) == 2
			and int(会话._占用条(会话.inventory, 2).get("quantity", 0)) == 2,
			"同 id 两摞：按格销**只动格2**，格1 不许被错杀")
	会话.call("drop_destroy_inventory_slot", 2)
	_查(会话._占用条(会话.inventory, 2).is_empty()
			and int(会话._占用条(会话.inventory, 1).get("quantity", 0)) == 2,
			"拖空销毁=整摞：格2 清空留洞，格1 原样")

	# —— ⑪ 绑定（2026-10-02 实装：原版 `onClickPopupMenu:798` 直发 `requestBindItem(position)`，
	#   不开窗；服务端 `handle_item_change` BIND `fake_flash_server.py:53506-53519`）——
	# 菜单出现判据（menuArr[类型13 宝石]带「绑定」；`filtrateItemMenu :559` 已绑就抹掉）
	var 项未绑: Array = 菜单脚本.取菜单项({"id": "13000001", "quantity": 2})
	_查(项未绑.has("绑定"), "未绑宝石(类型13)菜单应有「绑定」")
	var 项已绑: Array = 菜单脚本.取菜单项({"id": "13000001", "quantity": 2, "can_trade": false})
	_查(not 项已绑.has("绑定"), "已绑件菜单不许再有「绑定」（filtrateItemMenu :559）")
	# 离线绑定：置位不可逆 + **按格精确**（同 id 两摞只动那一格——§3.81.1 那族）
	var 通知: Array[String] = []
	var 通知收集: Callable = func(话: String): 通知.append(话)
	会话.notification_requested.connect(通知收集)
	会话.inventory.clear()
	会话.inventory.append(_件("13000001", 2))
	会话.inventory.append(_件("13000001", 3))
	_查(bool(会话.call("bind_inventory_slot", 2)), "按格绑定应成功")
	_查(not bool(会话._占用条(会话.inventory, 2).get("can_trade", true)), "格2 应转不可交易")
	_查(bool(会话._占用条(会话.inventory, 1).get("can_trade", true))
			and int(会话._占用条(会话.inventory, 1).get("quantity", 0)) == 2,
			"同 id 的格1 不许被连坐（绑定按格、不许按 id 反查）")
	_查(通知.size() == 1 and 通知[0] == "物品绑定成功。",
			"成功文案逐字照服务端 :53349（实际 %s）" % [通知])
	通知.clear()
	_查(not bool(会话.call("bind_inventory_slot", 2)), "已绑再绑应静默 false（服务端 :47057 一个包都不发）")
	_查(通知.is_empty(), "已绑件重绑不许弹任何文案")
	_查(not bool(会话.call("bind_inventory_slot", 5)), "空格(洞)绑定应 false")
	# 禁绑件（`Etc.NeverBindItems` → `数据/原版杂项.json`）：服务端**先判禁绑再判已绑**
	# （:53341 在 :47057 之前）——禁绑件即便已绑也回那句"不能绑定"，离线判序照它。
	会话.inventory.clear()
	会话.inventory.append(_件("16000053", 1))
	_查(not bool(会话.call("bind_inventory_slot", 1)), "NeverBindItems 的件要拒")
	_查(bool(会话._占用条(会话.inventory, 1).get("can_trade", true)), "拒绑不许动状态")
	_查(通知.size() == 1 and 通知[0] == "该物品不能绑定。",
			"拒绑文案逐字照服务端 :53342（实际 %s）" % [通知])
	# 端到端：真物品菜单的「绑定」信号 → `_执行菜单项` → 会话（旧代码这条路落「未实现」兜底）
	会话.notification_requested.disconnect(通知收集)
	会话.inventory.clear()
	会话.inventory.append(_件("13000001", 2))
	var 窗2 := (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(窗2)
	await process_frame
	窗2.call("open_page", "背包")
	for _i in 4:
		await process_frame
	var 页2 := 窗2.find_child("原版背包内容", true, false) as Control
	if 页2 == null:
		_失败.append("绑定端到端：背包页没建出来")
	else:
		# 等价于"单击那一格"记下的选中态（`_选中格子` 同两行赋值）。
		窗2.set("_selected_inventory_id", "13000001")
		窗2.set("_selected_inventory_格", 1)
		var 菜2 := 页2.get_node_or_null("物品菜单") as Control
		_查(菜2 != null, "端到端：背包页上应有物品菜单节点")
		if 菜2 != null:
			菜2.emit_signal("选择了", "绑定")
			_查(not bool(会话._占用条(会话.inventory, 1).get("can_trade", true)),
					"真菜单「绑定」→ 会话应把格1 置不可交易（旧代码这里只弹『未实现』）")
	窗2.queue_free()
	await process_frame
	# 还原：通知是本地态，测试件都清了再回快照
	会话.inventory.clear()

	# —— ⑫ 发到聊天框 端到端（2026-10-02）——
	# 这条 14bf477 就"接上了真实行为"，但**没有任何门点过它**：菜单/Ctrl+单击那两处
	# 都用 `窗口.get_parent().get_node_or_null("聊天面板")` 找面板 —— 那是**单窗时代**的父链，
	# 多窗化后窗口挂在 窗口管理(CanvasLayer) 下、聊天面板是它的**兄弟** ⇒ 实机永远拿到 null，
	# 点「发到聊天框」只弹"找不到聊天框"。改成按 group `chat_panel` 找，这条钉住别再退回去。
	会话.inventory.clear()
	会话.inventory.append(_件("13000001", 1, {"name": "白色宝石"}))
	var 聊天场景 := (load("res://场景/界面/聊天面板.tscn") as PackedScene).instantiate()
	root.add_child(聊天场景)
	await process_frame
	var 管理 := (load("res://场景/界面/窗口管理.tscn") as PackedScene).instantiate()
	root.add_child(管理)
	await process_frame
	# ⚠ 原来这条写的是 `bool(取窗口("背包") == null) or true` ⇒ **恒真、永远不会红**
	#   （GDScript 的 `or` 返回 bool，不是兜底值；§3.244）。判"开窗前还没有背包窗"也不成立：
	#   `取窗口` 是**取或建**，一取就建出来了。改成判前置本身：管理件建出来了、接口在。
	_查(管理 != null and 管理.has_method("取窗口"), "⑫前置：窗口管理建出来了、`取窗口` 接口在")
	管理.call("打开", "背包")
	for _i in 4:
		await process_frame
	var 背窗 := 管理.call("取窗口", "背包") as Node
	if 背窗 == null:
		_失败.append("⑫端到端：背包窗没从窗口管理开出来")
	else:
		背窗.set("_selected_inventory_id", "13000001")
		背窗.set("_selected_inventory_格", 1)
		var 页12 := 背窗.find_child("原版背包内容", true, false) as Control
		if 页12 == null:
			_失败.append("⑫端到端：背包页没建出来")
		else:
			var 菜12 := 页12.get_node_or_null("物品菜单") as Control
			if 菜12 == null:
				_失败.append("⑫端到端：物品菜单节点不在")
			else:
				菜12.emit_signal("选择了", "发到聊天框")
				await process_frame
				var 输入 := (聊天场景.get("_chat_input") as LineEdit)
				_查(输入 != null and 输入.text.contains("【白色宝石】"),
						"真菜单「发到聊天框」应把【物品名】插进聊天输入框（旧父链写法在这里必拿 null）")

	# —— ⑬ 强化：开装备打造窗 + 页签切 0 + 把**这一格**放进左栏 ——
	# 原版 `onClickPopupMenu :807-818` → `UIMain2.showEquipStrengthWindowWithData:4846-4854`
	# → `EquipStrengthWindow.init:302-308`（`selectedIndex=param1; _itemData=param2`）：
	# 菜单这条入口是**开窗即带物**，不走拖放门槛；放置复用现成的 `_应用选中部位`（同一条状态机）。
	if 背窗 != null:
		会话.inventory.clear()
		会话.inventory.append(_件("01010011", 1))      # 玩家武器：装备部位位置 != 0 才放得进
		会话.inventory.append(_件("01410002", 1))      # 一尾徽章（四位码 0141）⇒ 走它自己那扇窗
		var 项武: Array = 菜单脚本.取菜单项({"id": "01010011", "quantity": 1})
		_查(项武.has("强化"), "⑬前置：玩家装备菜单该有「强化」")
		背窗.set("_selected_inventory_id", "01010011")
		背窗.set("_selected_inventory_格", 1)
		var 页13 := 背窗.find_child("原版背包内容", true, false) as Control
		var 菜13 := 页13.get_node_or_null("物品菜单") as Control if 页13 != null else null
		if 菜13 == null:
			_失败.append("⑬端到端：背包页/菜单不在")
		else:
			菜13.emit_signal("选择了", "强化")
			await process_frame
			var 打窗 := 管理.call("取窗口", "装备强化") as Node
			_查(打窗 != null, "⑬菜单「强化」该把装备打造窗开出来（原版 init 同物）")
			if 打窗 != null:
				_查(int(打窗.get("_strengthen_tab")) == 0, "⑬页签应切到 0=强化（init 的 param1）")
				_查(bool(打窗.get("_强化放入中")), "⑬左栏应处于已放入态")
				_查(String(打窗.get("_强化放入来源")) == "背包"
						and int(打窗.get("_强化放入格")) == 1
						and String(打窗.get("_强化放入id")) == "01010011",
						"⑬放进去的该是**那一格背包件**（来源=背包/格1/id 对上）")
				# 徽章分流：原版开的是 `showBeastBadgeCreateWindowWithData(1, …)`（**页 1 = 打造**），
				# 走**它自己那扇窗**、不塞通用打造窗。2026-10-11 接上导航那一跳。
				打窗.call("_清放入")
				背窗.set("_selected_inventory_id", "01410002")
				背窗.set("_selected_inventory_格", 2)
				菜13.emit_signal("选择了", "强化")
				for _i in 3:
					await process_frame
				_查(not bool(打窗.get("_强化放入中")), "⑬徽章(141)不该塞进通用打造窗（走它自己那扇）")
				_查(管理.call("取窗口", "徽章打造") != null,
						"⑬徽章(141)点「强化」该把「徽章打造」窗开出来（原版 showBeastBadgeCreateWindowWithData(1,…)）")
				_查(徽章打造窗脚本.当前页() == 1, "⑬该切到页 1（打造徽章那一面），实测 %d" % 徽章打造窗脚本.当前页())

	# —— ⑭ 合成（残卷）：开「秘笈合成」窗 + 连背包 + **把这一格残卷带进去** ——
	# 原版 `showCanJuanHeChengWindowWithData:5848-5860` = `centerTwoWindow(秘笈合成, 背包)`
	# + `validateItem(curCellData)`。2026-10-11 之前这条只回一句"本轮未接"（窗其实早就有）。
	if 背窗 != null:
		会话.inventory.clear()
		会话.inventory.append(_件("08000011", 1))     # 《五行封印术》残卷（canjuan_book 有配方）
		背窗.set("_selected_inventory_id", "08000011")
		背窗.set("_selected_inventory_格", 1)
		var 页14 := 背窗.find_child("原版背包内容", true, false) as Control
		var 菜14 := 页14.get_node_or_null("物品菜单") as Control if 页14 != null else null
		if 菜14 == null:
			_失败.append("⑭端到端：背包页/菜单不在")
		else:
			菜14.emit_signal("选择了", "合成")
			for _i in 3:
				await process_frame
			var 秘窗 := 管理.call("取窗口", "技能书") as Node
			_查(秘窗 != null,
					"⑭残卷点「合成」该把「秘笈合成」窗开出来（原版 showCanJuanHeChengWindowWithData）")
			_查(int(秘笈合成窗脚本._放入格) == 1,
					"⑭该把这一格残卷带进窗的放入态（validateItem 那一跳），实测 _放入格=%s" % str(秘笈合成窗脚本._放入格))
			var 背 := 管理.call("取窗口", "背包") as Node
			_查(背 != null and bool(背.call("已打开")),
					"⑭原版 `centerTwoWindow` ⇒ 背包该一起开着（`窗口管理.伴随背包` 登记的）")

		# —— ⑮ 合成（徽章石）：开「徽章打造」窗、切到页 0（合成） ——
		# 原版 `showBeastBadgeCreateWindowWithData(0, curCellData)`。⚠️ 那扇窗的**投料**本工程
		# 还没做（原版是 `ItemCaiLiaoBox` 的光标/拖放）⇒ 这里只钉**导航**那一跳。
		会话.inventory.clear()
		会话.inventory.append(_件("13200000", 1))     # 一尾徽章打造石（`isItemHuiZhangShi` = 前三位 132）
		背窗.set("_selected_inventory_id", "13200000")
		背窗.set("_selected_inventory_格", 1)
		var 页15 := 背窗.find_child("原版背包内容", true, false) as Control
		var 菜15 := 页15.get_node_or_null("物品菜单") as Control if 页15 != null else null
		if 菜15 == null:
			_失败.append("⑮端到端：背包页/菜单不在")
		else:
			菜15.emit_signal("选择了", "合成")
			for _i in 3:
				await process_frame
			_查(管理.call("取窗口", "徽章打造") != null,
					"⑮徽章石点「合成」该把「徽章打造」窗开出来（原版 showBeastBadgeCreateWindowWithData）")
			_查(徽章打造窗脚本.当前页() == 0, "⑮该切到页 0（合成徽章石那一面），实测 %d" % 徽章打造窗脚本.当前页())

		# —— ⑯ 强化（昆虫）：开人物窗的「寄坏之术」页 + **把这只虫带进去** ——
		# 原版 `KunChongManager.showStrengthView(curCellData)`（`ItemWindow2.as:808-811`）。
		# ⚠️ 判据必须是**四位码 0131 / 装备部位 = 昆虫包**：昆虫 id 是 `01310001..01310006`，
		#    而**前三位 131 的是勾玉**（`13100000` 起 360 件）—— 旧写法按前三位判，
		#    一件真昆虫都匹配不到（会掉进通用打造窗）。这里先钉住这段 id 空间的假设。
		_查(装备部位.位置("01310001") == 装备部位.昆虫包 and 装备部位.位置("13100000") != 装备部位.昆虫包,
				"⑯id 空间假设：昆虫(`01310001…`) 位置=昆虫包，勾玉(`13100000…`) 不是")
		会话.inventory.clear()
		会话.inventory.append(_件("01310001", 1))     # 蝉（寄坏虫，四位码 0131）
		背窗.set("_selected_inventory_id", "01310001")
		背窗.set("_selected_inventory_格", 1)
		var 页16 := 背窗.find_child("原版背包内容", true, false) as Control
		var 菜16 := 页16.get_node_or_null("物品菜单") as Control if 页16 != null else null
		if 菜16 == null:
			_失败.append("⑯端到端：背包页/菜单不在")
		else:
			菜16.emit_signal("选择了", "强化")
			for _i in 3:
				await process_frame
			var 人窗 := 管理.call("取窗口", "人物") as Node
			_查(人窗 != null, "⑯昆虫点「强化」该开人物窗（原版 showStrengthView 那条路）")
			if 人窗 != null:
				var 携入: Dictionary = 人窗.get("_角色携入虫")
				_查(String(携入.get("id", "")) == "01310001",
						"⑯该把这一格虫带进寄坏之术页当强化目标，实测 %s" % str(携入.get("id", "")))
				_查(int(人窗.get("_角色携入位置")) == 1,
						"⑯携带位置该是**背包格号 1**（服务端拿它 `inventory.get(slot)` 取件），实测 %s"
						% str(人窗.get("_角色携入位置")))
				_查(int(人窗.get("_character_main_tab")) == 1 and int(人窗.get("_character_sub_tab")) == 2,
						"⑯该切到「秘术 / 寄坏之术」（主分页 1 / 子分页 2），实测 %s / %s"
						% [人窗.get("_character_main_tab"), 人窗.get("_character_sub_tab")])

		# —— ⑰ 镶嵌勾玉：**同一扇窗、另一条协议**（勾玉 13/14，宝石 1/2） ——
		# 原版 `onClickPopupMenu:827 showGouYuCarryWindow(curCellData)`；两族版式逐字相同
		# （`StoneCarryWindow` / `GouYuCarryWindow` 的两处 `createChildren` 可逐行对照），
		# 只差 `ITEM_NAMES[0/1]`（宝石/勾玉）那个 `%1` 与提交那条请求。
		会话.inventory.clear()
		会话.inventory.append(_件("01410002", 1, {"slot_index": 1}))                     # 占位
		会话.inventory.append(_件("01200020", 1, {"slot_index": 2}))                      # 稻荷玉链 stage2（**不带 stage 键** = 生产形态）
		会话.inventory.append(_件("13100000", 1, {"slot_index": 3}))                      # 勾玉（前三位 131）
		# 菜单：玉链那类**只有「镶嵌勾玉」、没有「宝石镶嵌」**（`:532` 把宝石镶嵌 erase 掉）
		var 项链: Array = 菜单脚本.取菜单项({"id": "01200020", "quantity": 1})
		_查(项链.has("镶嵌勾玉") and not 项链.has("宝石镶嵌"),
				"⑰玉链该有「镶嵌勾玉」、没有「宝石镶嵌」，实测 %s" % [项链])
		背窗.set("_selected_inventory_id", "01200020")
		背窗.set("_selected_inventory_格", 2)
		var 页17 := 背窗.find_child("原版背包内容", true, false) as Control
		# ⚠ 「宝石镶嵌」现在登记在 `窗口管理.伴随背包`（原版 `centerTwoWindow(STONE_CARRY_WINDOW,
		# ITEM_WINDOW2_F)` 那一对）⇒ 每开一次镶嵌窗都会 `打开("背包")` 重渲背包页，旧
		# `物品菜单` 节点随即 free（`_render_page` 拆页）⇒ 每次点之前都得现取，别攥旧手柄。
		var 点菜单17 := func(项: String) -> bool:
			var 页现 := 背窗.find_child("原版背包内容", true, false) as Control
			var 菜现 := 页现.get_node_or_null("物品菜单") as Control if 页现 != null else null
			if 菜现 == null:
				return false
			菜现.emit_signal("选择了", 项)
			return true
		if 页17 == null or 页17.get_node_or_null("物品菜单") == null:
			_失败.append("⑰端到端：背包页/菜单不在")
		else:
			点菜单17.call("镶嵌勾玉")
			for _i in 4:
				await process_frame
			var 镶窗 := 管理.call("取窗口", "宝石镶嵌") as Node
			_查(镶窗 != null, "⑰「镶嵌勾玉」该把镶嵌窗开出来（原版 showGouYuCarryWindow）")
			if 镶窗 != null:
				_查(bool(镶窗.get("_镶嵌勾玉模式")), "⑰该进**勾玉模式**（同一扇窗、另一条协议）")
				_查(String(镶窗.get("_title").text) == "勾玉镶嵌与取出",
						"⑰标题该是「勾玉镶嵌与取出」，实测「%s」" % 镶窗.get("_title").text)
				var 页镶 := (镶窗.get("_content") as Control).get_child(0) as Control
				_查(页镶 != null and String((页镶.get_node("镶嵌说明") as RichTextLabel).text).contains("勾玉镶嵌"),
						"⑰镶嵌说明该换成勾玉那版（原版 `ITEM_NAMES[1]` 替 %1）")
				# 玉链孔数 = `special.inlay.stage<阶>.count`，阶数取 `数据/物品装备元数据.json` 的
				# `物品.<八位id>.stage`（同 `功能窗口._装备阶数`）。
				# ⚠️ 旧版这条的种子**手灌了 `"stage": 2`** —— 生产里的背包行根本没有这个键
				#    （`_parse_item_entry` 那 29 个字段里没有 stage），于是真机六阶玉链只剩 1 孔的
				#    bug（2026-11-01 用户报）在这里照样绿。现在种子就是生产形态，且三阶各钉一遍。
				for 例 in [["01200010", 1], ["01200020", 2], ["01200060", 6]]:
					var 链id := String(例[0])
					var 应孔 := int(例[1])
					(会话.inventory[1] as Dictionary)["id"] = 链id
					背窗.set("_selected_inventory_id", 链id)
					点菜单17.call("镶嵌勾玉")
					for _i in 4:
						await process_frame
					页镶 = (镶窗.get("_content") as Control).get_child(0) as Control
					var 亮孔 := 0
					for i in 6:
						if (页镶.get_node("孔面板/孔_%d" % i) as Control).visible:
							亮孔 += 1
					_查(亮孔 == 应孔,
							"⑰玉链 %s（stage%d）该亮 %d 个孔（`special.inlay.stage%d.count`），实测 %d"
							% [链id, 应孔, 应孔, 应孔, 亮孔])
				# 拖勾玉那一下的上限：stage6 已镶 2 枚时**不许**报"最多只能镶嵌 1 个"；
				# stage1 已镶 1 枚时必须报、且数字是 1（同一份阶数来源，两头各钉一边）。
				var 提示表: Array[String] = []
				var 记账 := func(文本: String) -> void: 提示表.append(文本)
				会话.notification_requested.connect(记账)
				(会话.inventory[1] as Dictionary)["id"] = "01200060"
				(会话.inventory[1] as Dictionary)["inlays"] = [{}, {}]
				背窗.set("_selected_inventory_id", "01200060")
				点菜单17.call("镶嵌勾玉")
				for _i in 4:
					await process_frame
				提示表.clear()
				镶窗.call("_宝石镶嵌_落入", 0, 3)
				_查(not 提示表.any(func(话: String) -> bool: return 话.contains("最多只能镶嵌")),
						"⑰stage6 玉链已镶 2 枚，再拖一枚**不许**被判上限（实发 %s）" % [提示表])
				(会话.inventory[1] as Dictionary)["id"] = "01200010"
				(会话.inventory[1] as Dictionary)["inlays"] = [{}]
				背窗.set("_selected_inventory_id", "01200010")
				点菜单17.call("镶嵌勾玉")
				for _i in 4:
					await process_frame
				提示表.clear()
				镶窗.call("_宝石镶嵌_落入", 0, 3)
				_查(提示表.any(func(话: String) -> bool: return 话.contains("最多只能镶嵌1个勾玉")),
						"⑰stage1 玉链已镶 1 枚，再拖一枚必须报「最多只能镶嵌1个勾玉」（实发 %s）" % [提示表])
				会话.notification_requested.disconnect(记账)
	# 源码 tripwire：模式分支必须走 13/14 那两条（离线发不出去，只能钉住"走的是哪一对"）。
	var 源功能 := FileAccess.get_file_as_string("res://脚本/界面/功能窗口.gd")
	_查(源功能.contains("_镶嵌勾玉模式") and 源功能.contains("jade_inlay") and 源功能.contains("jade_uninlay"),
			"⑰镶嵌窗的勾玉模式分支该走 `jade_inlay` / `jade_uninlay`（子命令 13/14）")
	var 源后端 := FileAccess.get_file_as_string("res://脚本/单例/后端连接.gd")
	_查(源后端.contains("func request_jade_inlay") and 源后端.contains("request_item_change(13, ["),
			"⑰`request_jade_inlay` 该发子命令 **13**（`ItemChangeProcessor.requestJadeInlay:564 writeByte(13)`）")
	_查(源后端.contains("func request_jade_uninlay") and 源后端.contains("request_item_change(14, ["),
			"⑰`request_jade_uninlay` 该发子命令 **14**（`:637 writeByte(14)`）")
	_查(源后端.contains("request_item_change(1, [") and 源后端.contains("request_item_change(2, ["),
			"⑰宝石那条仍是 1/2（反向哨兵：别把两条协议并成一条）")

	# —— ⑲ 破碎修复：开「装备修复」窗（**只有破碎的装备**菜单里才有这一项）——
	# 原版 `onClickPopupMenu:802 showEquipRepairWindow(0, curCellData)`；提交走
	# `requestRecoverEquip` = 子命令 **8**（不是 7 那条 NPC 商店修理）。
	会话.inventory.clear()
	会话.inventory.append(_件("01010011", 1, {"slot_index": 1}))                       # 完好的长太刀
	会话.inventory.append(_件("01010012", 1, {"slot_index": 2, "crash_time": 1}))      # 破碎的长太刀
	会话.inventory.append(_件("01410002", 1, {"slot_index": 3}))                       # 徽章（非打造装备）
	var 完好菜单: Array = 菜单脚本.取菜单项({"id": "01010011", "quantity": 1, "crash_time": 0})
	var 破损菜单: Array = 菜单脚本.取菜单项({"id": "01010012", "quantity": 1, "crash_time": 1})
	_查(not 完好菜单.has("破碎修复") and 完好菜单.has("宝石镶嵌"),
			"⑲完好的装备**不该有**「破碎修复」、该有「宝石镶嵌」（`filtrateItemMenu` 二选一），实测 %s" % [完好菜单])
	_查(破损菜单.has("破碎修复") and not 破损菜单.has("宝石镶嵌"),
			"⑲破碎的装备该反过来（有「破碎修复」、没「宝石镶嵌」），实测 %s" % [破损菜单])
	背窗.set("_selected_inventory_id", "01010012")
	背窗.set("_selected_inventory_格", 2)
	var 页19 := 背窗.find_child("原版背包内容", true, false) as Control
	var 菜19 := 页19.get_node_or_null("物品菜单") as Control if 页19 != null else null
	if 菜19 == null:
		_失败.append("⑲端到端：背包页/菜单不在")
	else:
		菜19.emit_signal("选择了", "破碎修复")
		for _i in 4:
			await process_frame
		var 修窗 := 管理.call("取窗口", "装备修复") as Node
		_查(修窗 != null, "⑲「破碎修复」该把「装备修复」窗开出来（原版 showEquipRepairWindow）")
		if 修窗 != null:
			_查(String(修窗.get("_title").text) == "装备打造",
					"⑲标题该是「装备打造」（`EQUIP_STRENGTH_WINDOW_TITLE`，与打造窗同名），实测「%s」"
					% 修窗.get("_title").text)
			_查(int(修窗.get("_装备修复格")) == 2, "⑲该带上那一格的格号（提交发的就是它）")
			var 页修 := (修窗.get("_content") as Control).get_child(0) as Control
			_查(页修 != null and (页修.get_node("内容容器/放入装备") as Button).text == "取出装备",
					"⑲带物开窗 ⇒ 放入钮该显示「取出装备」（原版 init 把 dropBtn 换文案）")
			_查(页修 != null and String((页修.get_node("内容容器/说明") as RichTextLabel).text).contains("破碎装备修复步骤说明"),
					"⑲说明该是 `EQUIP_STRENGTH_DESC_TEMPLATE_6` 那三段")
			_查(页修 != null and (页修.get_node("内容容器/材料框/材料格/材料数量") as Label).text == "1",
					"⑲材料角标该是 1（原版 `_configInfo.needItemCnt = 1` 写死）")
			# 提交：闸门全过才发，且发的是**子命令 8 + 背包格号**
			会话.player_stats["gold"] = 9999999
			会话.inventory.append(_件("16000029", 5, {"slot_index": 4}))   # `crash.needItemId` 修装备的材料
			var 假修 := 假后端.new()
			修窗.set("_backend", 假修)
			(页修.get_node("内容容器/开始修复") as Button).pressed.emit()
			for _i in 2:
				await process_frame
			_查(假修.收到 == ["recover:2"],
					"⑲「开始修复」该发 `request_recover_equipment(2)`（子命令 8 + 背包格号），实测 %s" % str(假修.收到))
			修窗.set("_backend", null)
	# —— ⑳ 灵器炼制三扇（洗练/灵化/开光）：一个场景 + 模式位，协议是 LING 2081 的 0/1/2 ——
	# 原版三扇 `super(520,345,true)`、`createChildren` 逐行相同，只有材料格枚数与文案不同。
	# 灵器菜单是「开光 / 灵化 / 洗练」**三选一**（`:571-579`：已开光去「开光」；
	# 已灵化去「灵化」、**否则去「洗练」**）⇒ 十拳剑没灵化之前根本不该有「洗练」。
	# ⚠ 两个判据的真源都不是"标志位"：**开光会换 id**（`20100001` → `20200001`，
	#   服务端 `_open_ling_qi:52310`）、**灵化写 `plus_attributes` 6 条**（`:52323`）。
	# 灵化那条：服务端写的正是 **6 行** `[ATTACK, 1]`（`_spiritualize_ling_qi:52323`）
	var 六条附加: Array = []
	for _i in 6:
		六条附加.append({"attribute_type": 0, "attribute_value": 1})
	var 新剑: Array = 菜单脚本.取菜单项({"id": "20100001", "quantity": 1})
	_查(新剑.has("开光") and 新剑.has("灵化") and not 新剑.has("洗练"),
			"⑳未开光/未灵化的十拳剑：菜单该有「开光」「灵化」、**没有**「洗练」，实测 %s" % [新剑])
	var 开光过的: Array = 菜单脚本.取菜单项({"id": "20200001", "quantity": 1})
	_查(not 开光过的.has("开光") and 开光过的.has("灵化"),
			"⑳已开光（id 换成 20200001）⇒ 去掉「开光」、留着「灵化」，实测 %s" % [开光过的])
	var 灵化过的: Array = 菜单脚本.取菜单项({"id": "20100001", "quantity": 1, "plus_attributes": 六条附加})
	_查(灵化过的.has("洗练") and not 灵化过的.has("灵化"),
			"⑳已灵化（`plus_attributes` 非空）⇒ 去掉「灵化」、**这时才出「洗练」**，实测 %s" % [灵化过的])
	# 人具「开光」那条：`isRenJuKaiGuang:1185` 是**判 id == 65000002**，同样不是标志位。
	var 人具未开: Array = 菜单脚本.取菜单项({"id": "65000001", "quantity": 1})
	var 人具已开: Array = 菜单脚本.取菜单项({"id": "65000002", "quantity": 1})
	_查(人具未开.has("开光") and not 人具已开.has("开光"),
			"⑳人具：65000001 有「开光」、开光后的 65000002 没有再出「开光」")
	会话.inventory.clear()
	会话.inventory.append(_件("20100001", 1, {"slot_index": 1}))          # 十拳剑（未灵化 ⇒ 只能开光/灵化）
	会话.inventory.append(_件("16000120", 3, {"slot_index": 2}))          # 洗炼石
	会话.inventory.append(_件("16000118", 3, {"slot_index": 3}))          # 灵化石
	会话.inventory.append(_件("16000116", 3, {"slot_index": 4}))          # 开光锤
	会话.inventory.append(_件("16000117", 3, {"slot_index": 5}))          # 开光石
	var 假灵 := 假后端.new()
	背窗.set("_selected_inventory_id", "20100001")
	背窗.set("_selected_inventory_格", 1)
	for 项 in [["洗练", "洗炼", 1, 2, "洗炼石"], ["灵化", "灵化", 1, 1, "灵化石"], ["开光", "开光", 2, 0, "开光锤"]]:
		# 洗练那扇要**已灵化**的十拳剑才开得出来（菜单三选一）⇒ 每轮先把那件摆成对应态
		# （灵化 = `plus_attributes` 有 6 条，服务端 `_spiritualize_ling_qi:52323`）。
		会话.inventory[0]["plus_attributes"] = 六条附加.duplicate() if String(项[0]) == "洗练" else []
		var 页20 := 背窗.find_child("原版背包内容", true, false) as Control
		var 菜20 := 页20.get_node_or_null("物品菜单") as Control if 页20 != null else null
		if 菜20 == null:
			_失败.append("⑳端到端：背包页/菜单不在")
			break
		菜20.emit_signal("选择了", String(项[0]))
		for _i in 4:
			await process_frame
		var 窗20 := 管理.call("取窗口", String(项[0])) as Node
		_查(窗20 != null, "⑳菜单「%s」该开出对应那扇窗" % 项[0])
		if 窗20 == null:
			continue
		_查(String(窗20.get("_title").text) == String(项[1]),
				"⑳%s 窗标题该是「%s」，实测「%s」" % [项[0], 项[1], 窗20.get("_title").text])
		var 页灵 := (窗20.get("_content") as Control).get_child(0) as Control
		var 亮格 := 0
		for i in 2:
			if (页灵.get_node("内容底/材料格%s" % ["一", "二"][i]) as Control).visible:
				亮格 += 1
		_查(亮格 == int(项[2]), "⑳%s 该亮 %d 枚材料格（开光两枚、另两扇一枚），实测 %d" % [项[0], int(项[2]), 亮格])
		# ⑳f 悬停详情框（§3.332）：材料格是原版 `ItemCaiLiaoBox`（内嵌 `SimpleItemCell`，
		#   `SimpleItemCell.as:220` 每枚挂 `MToolTipItem`）。炼制的场景里**没有烘**提示框节点
		#   ⇒ `_render_ling_forge` 要运行期补两套、并把材料格抬成 PASS 才收得到悬停。
		var 物品框 := 页灵.get_node_or_null("物品提示框") as Control
		var 装备框 := 页灵.get_node_or_null("装备提示框") as Control
		_查(物品框 != null and 装备框 != null,
				"⑳%s 该在页上补出「物品提示框」「装备提示框」（实测 物品=%s 装备=%s）"
				% [项[0], str(物品框 != null), str(装备框 != null)])
		var 首材 := 页灵.get_node("内容底/材料格一") as Control
		_查(首材.mouse_filter != Control.MOUSE_FILTER_IGNORE,
				"⑳%s 材料格一 的 mouse_filter 不该是 IGNORE（否则永远收不到悬停）" % 项[0])
		if 物品框 != null and 首材.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			首材.emit_signal("mouse_entered")
			await process_frame
			_查(物品框.visible, "⑳%s 悬停材料格一该弹出物品提示框" % 项[0])
			var 材标 := 物品框.get_node("标题") as Label
			_查(材标.text == String(项[4]),
					"⑳%s 材料提示框标题该是「%s」，实测「%s」" % [项[0], String(项[4]), 材标.text])
			物品框.visible = false
		# 开光那扇的第二枚（开光石）也要单独接上
		if String(项[0]) == "开光" and 物品框 != null:
			var 二材 := 页灵.get_node("内容底/材料格二") as Control
			_查(二材.mouse_filter != Control.MOUSE_FILTER_IGNORE,
					"⑳开光 材料格二 的 mouse_filter 不该是 IGNORE")
			if 二材.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				二材.emit_signal("mouse_entered")
				await process_frame
				_查(物品框.visible and (物品框.get_node("标题") as Label).text == "开光石",
						"⑳开光 悬停材料格二该弹出「开光石」提示框")
				物品框.visible = false
		# ⑳d 洗炼窗那句「洗炼效果：攻击 +N」的 N = **附加属性[0] × 6**
		#   （`LingQiManager.updatePlusAttr:280`；没附加属性 ⇒ 0，`XiLianWindow.setData:72`）。
		#   门旧版没量它 ⇒ `条.plus_attr`（全工程没人写的键）恒 0 也没人发现。
		if String(项[0]) == "洗练":
			var 洗文 := String((页灵.get_node("内容底/文案") as RichTextLabel).text)
			_查(洗文.contains("攻击 +6"),
					"⑳洗炼文案该按「附加属性[0]×6」填（6 条、值 1 ⇒ 攻击 +6），实测「%s」"
					% 洗文.replace("\n", "\\n").substr(0, 120))
		# ⑳c 开光那扇的三处不同（`KaiGuangWindow.as:76/80/131`，人具同版式）：第一枚材料格
		#   在 `文案x+文案宽−10` = 340；开始钮在 `文案x+文案宽+20` = **370**（比材料格右 **30**，
		#   写成右 20 就差 10px —— 门旧版没量这三处，正是"门绿但摆错"那一族）。
		#   且第一枚是 `ItemCaiLiaoBox(false)`（开光锤）⇒ **没有「购买」钮**。
		var 是开光 := String(项[0]) == "开光"
		var 首格x := (页灵.get_node("内容底/材料格一") as Control).position.x
		_查(首格x == (340.0 if 是开光 else 350.0),
				"⑳%s 第一枚材料格 x 该是 %s，实测 %s" % [项[0], "340" if 是开光 else "350", str(首格x)])
		var 开始x := (页灵.get_node("内容底/开始") as Button).position.x
		_查(开始x == (370.0 if 是开光 else 350.0),
				"⑳%s 开始钮 x 该是 %s，实测 %s" % [项[0], "370" if 是开光 else "350", str(开始x)])
		var 购一 := (页灵.get_node("内容底/材料格一购买") as Button).visible
		_查(购一 == (not 是开光),
				"⑳%s 第一枚材料格的「购买」钮该%s（开光锤是 `ItemCaiLiaoBox(false)`），实测 %s"
				% [项[0], "不显" if 是开光 else "显", str(购一)])
		if 是开光:
			_查((页灵.get_node("内容底/材料格二购买") as Button).visible, "⑳开光 第二枚（开光石）该带「购买」钮")
		_查(String((页灵.get_node("内容底/文案") as RichTextLabel).text).contains("成功率"),
				"⑳%s 文案该按 `%s_WINDOW_Lable` 填出来" % [项[0], 项[0]])
		窗20.set("_backend", 假灵)
		(页灵.get_node("内容底/开始") as Button).pressed.emit()
		for _i in 2:
			await process_frame
		_查(假灵.收到 == ["%d:20100001:1" % int(项[3])],
				"⑳%s 该发 LING 子命令 %d + (物品号, 格号)，实测 %s" % [项[0], int(项[3]), str(假灵.收到)])
		# ⑳e1 发出去那一刻：只有**开光**那扇把钮按住（`KaiGuangWindow.as:160` 请求前置
		# `kaiGuangBtn.enabled = false`），洗炼/灵化两扇原版没有这一句 ⇒ 照旧亮着。
		_查((页灵.get_node("内容底/开始") as Button).disabled == 是开光,
				"⑳%s 发出去以后那枚钮该%s，实测 disabled=%s"
				% [项[0], "按住" if 是开光 else "照旧亮着", str((页灵.get_node("内容底/开始") as Button).disabled)])
		窗20.set("_backend", null)
	# ⑳b 人具（类型 65）点「开光」⇒ 同一扇窗、换 `RENJU 2082` 子命令 0。
	# 配置回落到 `Etc.LingQi.kaiguang`（`RenJuManager.as:94-99`）。
	会话.inventory.clear()
	会话.inventory.append(_件("65000001", 1, {"slot_index": 1}))          # 忍具（人具）
	背窗.set("_selected_inventory_id", "65000001")
	背窗.set("_selected_inventory_格", 1)
	var 页21 := 背窗.find_child("原版背包内容", true, false) as Control
	var 菜21 := 页21.get_node_or_null("物品菜单") as Control if 页21 != null else null
	if 菜21 == null:
		_失败.append("⑳b端到端：背包页/菜单不在")
	else:
		菜21.emit_signal("选择了", "开光")
		for _i in 4:
			await process_frame
		var 窗21 := 管理.call("取窗口", "开光人具") as Node
		_查(窗21 != null,
				"⑳b人具点「开光」该开**人具那扇**（版式同本尊、协议换 RENJU 2082 子命令 0）")
		if 窗21 != null:
			窗21.set("_backend", 假灵)
			var 页21b := (窗21.get("_content") as Control).get_child(0) as Control
			(页21b.get_node("内容底/开始") as Button).pressed.emit()
			for _i in 2:
				await process_frame
			_查(假灵.收到 == ["renju0:65000001:1"],
					"⑳b人具开光该发 `request_renju_kai_guang`（RENJU 0 + 物品号 + 格号），实测 %s" % str(假灵.收到))
			窗21.set("_backend", null)
	# —— ⑳e 结果帧回来以后（2026-10-25）：门旧版只钉到"发出去"那半，回帧**一直没有消费者**
	#     （2081/2082 两条 opcode 没人接 ⇒ 点开光就是白等）。这里钉四件事：
	#     ① 两族结果帧**一句提示都不发**（`LingEquipProcessor:53-73` / `RenJuProcessor:44-51` 只往管理器递）；
	#     ② 灵化(1) 成功把洗炼文案硬置 **1**（`onLingEquipLingHuaResult:266` 写的就是字面量 1，
	#        不是 6 条 ×1），洗炼(2) 成功才走 `updatePlusAttr:278-281` 的「第一条 ×6」；
	#     ③ 开光(0)/合成(3) 两支在原版是**空函数**（`onLingEquipKaiGuangResult:302-304`）⇒ 一动不动、
	#        按住的那枚钮再也不放开；失败同样被外层 `if(param1 == 1)` 吞掉；
	#     ④ 人具(2082) 那支第一句**无条件**放回钮、只有成功才关窗（`handleKaiGuangResult:70-77`）。
	var 后端e: Node = root.get_node_or_null("/root/BackendConnection") as Node
	if 后端e == null:
		_失败.append("⑳e没有 /root/BackendConnection 这根autoload，回帧那条腿没跑成")
	else:
		会话.inventory.clear()
		会话.inventory.append(_件("20100001", 1, {"slot_index": 1, "plus_attributes": 六条附加.duplicate()}))
		会话.inventory.append(_件("16000120", 3, {"slot_index": 2}))          # 灵器洗炼石
		背窗.set("_selected_inventory_id", "20100001")
		背窗.set("_selected_inventory_格", 1)
		var 页e := 背窗.find_child("原版背包内容", true, false) as Control
		var 菜e := 页e.get_node_or_null("物品菜单") as Control if 页e != null else null
		if 菜e == null:
			_失败.append("⑳e端到端：背包页/菜单不在")
		else:
			var 读文案: Callable = func(窗: Node) -> String:
				var 内 := (窗.get("_content") as Control)
				if 内 == null or 内.get_child_count() == 0:
					return ""
				return String(((内.get_child(0) as Control).get_node("内容底/文案") as RichTextLabel).text)
			var 取加: Callable = func(文: String) -> int:
				var 标 := "攻击 +"
				var 位 := 文.find(标)
				if 位 < 0:
					return -999
				# ⚠ `String.find` 给的是**字符**下标、不是字节：`"攻击 +"` 是 4 个字符（9 个字节），
				# 按字节 +6 会从数字后面两位开始数 ⇒ 恒 -998（本机踩过一次）。
				var 起 := 位 + 标.length()
				var 止 := 起
				while 止 < 文.length() and 文[止] >= "0" and 文[止] <= "9":
					止 += 1
				return int(文.substr(起, 止 - 起)) if 止 > 起 else -998
			var 无提示: Callable = func(窗: Node) -> bool:
				var 状 := (窗.get("_status") as Label)
				return 状 == null or not 状.visible
			# ⚠ 反向对照用的取法：`_灵器开始钮` 记的是**页里那一枚 Button**，页一重建它就没了
			# （`_refresh_current` 会 free 旧页）⇒ 直接 `.disabled` 会踩到 "previously freed"
			# 而**崩门**（看门狗超时、走不到还原快照）。判"按住没有"一律过这个口径。
			var 按住: Callable = func(窗: Node) -> bool:
				var 钮 := (窗.get("_灵器开始钮") as Button)
				return 钮 != null and is_instance_valid(钮) and 钮.disabled
			菜e.emit_signal("选择了", "洗练")
			for _i in 4:
				await process_frame
			var 洗窗e := 管理.call("取窗口", "洗练") as Node
			_查(洗窗e != null and 无提示.call(洗窗e), "⑳e回帧进来之前那扇洗炼窗不该挂着提示条")
			_查(取加.call(读文案.call(洗窗e)) == 6,
					"⑳e开窗那一下该按 `XiLianWindow.setData:63-77` 灌「攻击 +6」（第一条 1×6），实测 %d"
					% 取加.call(读文案.call(洗窗e)))
			for 帧 in ["2081:0:1", "2081:3:1", "2081:1:0:-", "2081:2:0:-"]:
				后端e.call("_handle_bridge_text", 帧)
				for _i in 3:
					await process_frame
				_查(取加.call(读文案.call(洗窗e)) == 6 and 无提示.call(洗窗e),
						"⑳e「%s」在原版不动界面（开光/合成是空函数、失败被 `if(param1 == 1)` 吞），实测文案=%d、提示可见=%s"
						% [帧, 取加.call(读文案.call(洗窗e)), str(((洗窗e.get("_status") as Label).visible))])
			后端e.call("_handle_bridge_text", "2081:1:1:4&1@4&1@4&1@4&1@4&1@4&1")
			for _i in 3:
				await process_frame
			_查(取加.call(读文案.call(洗窗e)) == 1 and 无提示.call(洗窗e),
					"⑳e灵化成功该把洗炼文案刷成「攻击 +1」（原版写死字面量 1，不是 6），实测 %d"
					% 取加.call(读文案.call(洗窗e)))
			后端e.call("_handle_bridge_text", "2081:2:1:4&7")
			for _i in 3:
				await process_frame
			_查(取加.call(读文案.call(洗窗e)) == 42 and 无提示.call(洗窗e),
					"⑳e洗炼成功该按「附加[0]×6」填（回帧 4&7 ⇒ 攻击 +42），实测 %d"
					% 取加.call(读文案.call(洗窗e)))
			var 开e := 管理.call("取窗口", "开光") as Node
			_查(开e != null and 按住.call(开e), "⑳e开光那扇在 ⑳ 里发过那一发 ⇒ 这枚钮该还按着")
			后端e.call("_handle_bridge_text", "2081:0:1")
			for _i in 3:
				await process_frame
			_查(按住.call(开e) and 无提示.call(开e),
					"⑳e灵器开光的成功回帧在原版是空函数 ⇒ 钮不放开、也不提示")
			var 人e := 管理.call("取窗口", "开光人具") as Node
			var 假人 := 假后端.new()
			人e.set("_backend", 假人)
			人e.set("_灵器开光已点", false)
			人e.call("打开")
			for _i in 2:
				await process_frame
			var 钮人 := (人e.get("_灵器开始钮") as Button)
			_查(钮人 != null and is_instance_valid(钮人) and not 钮人.disabled,
					"⑳e人具那扇重新进来时钮该是亮的（按住那档记在宿主 `_灵器开光已点` 上）")
			钮人.pressed.emit()
			for _i in 2:
				await process_frame
			_查(按住.call(人e), "⑳e人具发出去也按住（`RenJuKaiGuangWindow.as:172`）")
			后端e.call("_handle_bridge_text", "2082:0:0")
			for _i in 3:
				await process_frame
			_查((not 按住.call(人e)) and bool(人e.call("已打开")) and 无提示.call(人e),
					"⑳e人具**失败**的结果帧第一句放回钮、但不关窗（`handleKaiGuangResult:72/75`）")
			后端e.call("_handle_bridge_text", "2082:0:1")
			for _i in 3:
				await process_frame
			_查(not bool(人e.call("已打开")),
					"⑳e人具开光**成功**该关窗（原版 `setDOShow(RENJU_KAIGUANG_WINDOW,false)`）")
			人e.set("_backend", null)
	聊天场景.queue_free()
	管理.queue_free()
	await process_frame
	会话.inventory.clear()

	# —— ⑮ 消耗品/礼包的离线上路（2026-10-02，用户实机报"点券用了不加"）——
	# 在线那条钉在 `道具真实事务`（CASH_BIND 字段号 30）；这条钉**离线仿真**：
	# 真值列由 `开发工具/导出物品使用效果.py` 从服务端 catalog 补进 `数据/物品.json`，
	# 发放/拒因逐条对 `handle_use_item`。⚠️ 全部用**不带手写 hp 的裸字典**当背包件 ——
	# 种子的 hp 是 `离线示例数据` 手写进字典的（老逻辑只认它），裸字典才会走表里的效果列。
	var 通知15: Array[String] = []
	var 收集15: Callable = func(话: String): 通知15.append(话)
	会话.notification_requested.connect(收集15)
	会话.player_stats["level"] = 100
	会话.player_stats["max_hp"] = 1000
	# 真表拉面（hp_restore=250，走表列而非种子）
	会话.inventory.clear()
	会话.inventory.append({"id": "03000001", "name": "拉面（小）", "quantity": 2, "slot_index": 1,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"})
	会话.player_stats["hp"] = 1
	_查(bool(会话.call("use_inventory_item", "03000001")), "⑮真表拉面离线该能用（以前只认手写种子）")
	_查(int(会话.player_stats.get("hp", 0)) == 251,
			"⑮拉面按表里 hp_restore=250 回血（1+250，实际 %s）" % str(会话.player_stats.get("hp", 0)))
	# —— ⑮＃20 满血/死亡不许"默默吃掉一件"（2026-10-17 巡检 #20-C）——
	# 原版这六条闸在**发包之前**（`UI.as:1310-1343`）；离线以前没有，`heal_player`
	# 把 hp 钳在上限、**件照扣** ⇒ 满血吃拉面 = 白丢一件。文案抄原版
	# `en_US$message_properties.as:62/1752/1972`。
	# ⚠️ 三段各自**重新铺一格**：不重铺的话前一段扣掉一件、后一段就变成"格是空的所以
	#    返回 false"，看着像红过其实那条腿是空转的（R1 反向对照实测踩过）。
	for 段 in [["满血", 1000], ["死亡", 0]]:
		会话.inventory.clear()
		会话.inventory.append({"id": "03000001", "name": "拉面（小）", "quantity": 2, "slot_index": 1})
		会话.player_stats["max_hp"] = 1000
		会话.player_stats["hp"] = int(段[1])
		通知15.clear()
		_查(not bool(会话.call("use_inventory_item", "03000001")),
				"⑮＃20 %s 状态吃回血药要**拒**（原版是 addNotice/systemMsg 之后 return，不发也不扣）" % 段[0])
		_查(通知15.size() == 1 and 通知15[0] == (
				"你的血值已经满了!" if String(段[0]) == "满血" else "死亡状态下不能使用物品"),
				"⑮＃20 %s 那句要照原版文案（满血=ITEM_HP、死亡=DEAD_NO_USE_ITEM；实际 %s）" % [段[0], 通知15])
		_查(int(会话._占用条(会话.inventory, 1).get("quantity", 0)) == 2,
				"⑮＃20 %s 拒的时候**不许扣件**（以前这里白丢一件拉面）" % 段[0])
	会话.player_stats["hp"] = 1
	会话.player_stats["max_hp"] = 1000
	# 等级不够（服务端 `:50333` 也是裸 return）现在同样要有话说。
	会话.inventory.clear()
	会话.inventory.append({"id": "11000241", "name": "新手礼包", "quantity": 1, "slot_index": 1})
	会话.player_stats["level"] = 20
	通知15.clear()
	_查(not bool(会话.call("use_inventory_item", "11000241")),
			"⑮＃20 required_level=30 的礼包 20 级要用不了（下面金币礼包那段接着判它不消耗）")
	_查(通知15.size() == 1 and 通知15[0] == "你的等级不够，不能佩戴该物品!",
			"⑮＃20 等级闸照原版文案 ITEM_LEVEL_NO_FIT，别静默（实际 %s）" % [通知15])
	# 点券礼包：coupon_reward=388、use_all=1；「全部」= 3 件 ×388 = 1164
	会话.inventory.clear()
	会话.inventory.append({"id": "11000156", "name": "388点券", "quantity": 3, "slot_index": 1,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"})
	会话.player_stats["cash_bind"] = 0
	_查(bool(会话.call("use_inventory_item", "11000156")), "⑮点券礼包单件该能用（旧代码 category≠消耗品 直接 false）")
	_查(int(会话.player_stats.get("cash_bind", 0)) == 388,
			"⑮用 1 件点券 +388（实际 %s）" % str(会话.player_stats.get("cash_bind", 0)))
	_查(int(会话._占用条(会话.inventory, 1).get("quantity", 0)) == 2, "⑮用一件应剩两件")
	_查(bool(会话.call("use_inventory_item", "11000156", true)), "⑮use_all=1 的礼包「全部」应成功")
	_查(int(会话.player_stats.get("cash_bind", 0)) == 388 + 776
			and 会话._占用条(会话.inventory, 1).is_empty(),
			"⑮「全部」吃剩两件 → +776、吃空留洞（实际 cash_bind=%s）" % str(会话.player_stats.get("cash_bind", 0)))
	# 金币礼包：required_level=30 的等级闸 + contents 原子发放
	会话.inventory.clear()
	会话.inventory.append({"id": "11000241", "name": "新手礼包", "quantity": 1, "slot_index": 1,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"})
	会话.player_stats["gold"] = 0
	会话.player_stats["level"] = 20
	_查(not bool(会话.call("use_inventory_item", "11000241")), "⑮required_level=30 的角色 20 级要用不了")
	_查(int(会话._占用条(会话.inventory, 1).get("quantity", 0)) == 1 and int(会话.player_stats.get("gold", 0)) == 0,
			"⑮等级闸拒时**不消耗、不进账**（服务端 :50192 静默 return 同口径）")
	会话.player_stats["level"] = 100
	_查(bool(会话.call("use_inventory_item", "11000241")), "⑮够级后金币礼包应能用")
	_查(int(会话.player_stats.get("gold", 0)) == 20000, "⑮money_reward=20000 应进账（实际 %s）" % str(会话.player_stats.get("gold", 0)))
	# ⚠️ 落位顺序跟**服务端 flatten 的顺序**，不是 `数据/物品.json` 里 `contents` 那一列的顺序（2026-10-20）：
	#   服务端 `_decode_gift_contents:8442-8457` 按 `raw_items["0"]` **作者填写顺序**摊平
	#   ⇒ 本礼包 `数据/礼包详情.json` 的 `items["0"]` 是 slot0=`16000010`×10、slot1=`11000242`×1，
	#   所以先发千纸鹤（格2）再发大礼包（格3）。物品.json 的 contents 列是另一条解码出来的、
	#   顺序相反 —— 拿它当期望值的话，客户端越"对"这条门越红。
	_查(会话._占用条(会话.inventory, 2).get("id", "") == "16000010"
			and int(会话._占用条(会话.inventory, 2).get("quantity", 0)) == 10
			and String(会话._占用条(会话.inventory, 3).get("id", "")) == "11000242",
			"⑮contents 应按服务端 flatten 顺序落进 格2=16000010×10 / 格3=11000242×1（稳定格位制）")
	# 材料拒（服务端原话）与 buff 族拒（离线不模拟），都不许消耗
	会话.inventory.clear()
	会话.inventory.append({"id": "16000016", "name": "强化灵珠", "quantity": 5, "slot_index": 1,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"})
	通知15.clear()
	_查(not bool(会话.call("use_inventory_item", "16000016")), "⑮材料不能直接用")
	_查(通知15.size() == 1 and String(通知15[0]).ends_with("是材料或任务物品，不能直接使用。"),
			"⑮材料拒的文案照服务端 :50367 原话（实际 %s）" % [通知15])
	_查(int(会话._占用条(会话.inventory, 1).get("quantity", 0)) == 5, "⑮拒时不许消耗")
	会话.inventory.clear()
	会话.inventory.append({"id": "18003011", "name": "防御加成", "quantity": 1, "slot_index": 1,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"})
	通知15.clear()
	_查(not bool(会话.call("use_inventory_item", "18003011")), "⑮buff 类（shuxing）离线要**明确拒**，不许假成功")
	_查(通知15.size() == 1 and 通知15[0].contains("服务端结算"),
			"⑮buff 拒因要说清楚（实际 %s）" % [通知15])
	_查(int(会话._占用条(会话.inventory, 1).get("quantity", 0)) == 1, "⑮buff 拒也不许消耗")
	# 容量回滚：格位塞满后开带 contents 的礼包 → 整单回滚（对照 :50216-50219 的先验后扣）
	会话.inventory.clear()
	会话.inventory.append({"id": "11000241", "name": "新手礼包", "quantity": 1, "slot_index": 1,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"})
	for 格 in range(2, 会话.格容量 + 1):
		会话.inventory.append({"id": "99999999", "name": "占位", "quantity": 9999, "slot_index": 格})
	通知15.clear()
	_查(not bool(会话.call("use_inventory_item", "11000241")), "⑮背包满时开带 contents 的礼包要拒")
	_查(通知15.size() == 1 and 通知15[0] == "背包空间不足，无法打开礼包。",
			"⑮容量拒文案照服务端 :50224 原话（实际 %s）" % [通知15])
	_查(int(会话._占用条(会话.inventory, 1).get("quantity", 0)) == 1
			and int(会话.player_stats.get("gold", 0)) == 20000
			and 会话._占用数(会话.inventory) == 会话.格容量,
			"⑮回滚：礼包没扣、金币**没进账**（原子性）、占位一根不少（gold=%s）" % str(会话.player_stats.get("gold", 0)))
	# —— ⑮＃20 自选/随机礼包**不许把候选整套发出去**（2026-10-17 巡检 #20-A）——
	# 表里的 contents 是 `_decode_gift_contents:8438-8454` 扁平化出来的**候选清单**，
	# 不是"这一包给什么"：`libao_select` 只发选中的那 1 条、`libao_rand` 按 weight 抽 1 条
	# （`_use_authored_gift_item:49661-49703`）。离线原来不分 kinds 全发 ⇒
	# 吃一件「勾玉可选礼包（81颗）」凭空得 24 种×81 颗。真服务端没带 selection 时
	# 回提示并 `return 0` —— **一件不扣**，所以这里两条都要钉"不消耗 + 不落任何候选"。
	for 件 in [["11020003", "要先选一件奖励"], ["11010001", "随机"]]:
		会话.inventory.clear()
		会话.inventory.append({"id": String(件[0]), "name": "礼包", "quantity": 1, "slot_index": 1})
		通知15.clear()
		_查(not bool(会话.call("use_inventory_item", String(件[0]))),
				"⑮＃20 %s（%s 族）离线要**拒**，不许假成功" % [件[0], 件[1]])
		_查(int(会话._占用条(会话.inventory, 1).get("quantity", 0)) == 1,
				"⑮＃20 %s 拒时不许消耗（照 :49679-49682 的 return 0）" % 件[0])
		_查(会话._占用数(会话.inventory) == 1,
				("⑮＃20 %s 用后背包只该有它自己那一格 —— 多出任何一格就是"
				+ "把 contents 的候选整套发了（那是刷物品）") % 件[0])
		_查(通知15.size() == 1 and String(通知15[0]).contains(String(件[1])),
				"⑮＃20 %s 的拒因要说清（要含「%s」，实际 %s）" % [件[0], 件[1], 通知15])
	会话.notification_requested.disconnect(收集15)
	会话.inventory.clear()

	# —— ⑯ 堆叠数量字的几何/字号（2026-10-02 用户报"字体看着不对"）——
	# 真值 `ItemWindowCell.as:54-62`：tf x=1/y=24/w=37、autoSize=RIGHT（左锚点）、size=12；
	# 发光 `:69 getGlowFilter(0)` ≈ 2px 黑描边（由 `configure_label` 统一给）。
	# 我们原来是 **size 9、右对齐、20..37** —— 三条都不对，观感就是"数字小、贴在右下"。
	var 格场景 := (load("res://场景/界面/组件/物品格.tscn") as PackedScene)
	var 格实例 := 格场景.instantiate() as Control
	var 量 := 格实例.get_node("数量") as Label
	_查(量 != null, "⑯物品格应有 数量 Label")
	if 量 != null:
		_查(int(量.offset_top) == 24 and int(量.offset_right) == 38,
				"⑯数量字右下：上界 y=24、右界 x=38（autoSize=RIGHT 右边界固定），实际 top=%d right=%d" % [量.offset_top, 量.offset_right])
		_查(量.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT,
				"⑯数量字该**右对齐**（Flash autoSize=RIGHT＝右边界固定往左长，数字贴右下）——别再被改成左")
		_查(int(量.get_theme_font_size("font_size")) == 12,
				"⑯场景字号该 12（AS3 _loc1_.size），实际 %d" % int(量.get_theme_font_size("font_size")))
		# 数字用**原版那份 simsun.ttf**（系统 SimSun 拉丁太细矮、黑体/Arial Black 又不像原版点阵）——
		# 数量 Label 不写 font override、继承全局 default_font。钉这条防全局字体又被换回系统宋体。
		# 2026-10-25 晚：§3.275 的全局合成加粗已回滚（它把数字/字母的边缘抹糊，用户实机报）。
		# AS3 `ItemWindowCell.as:60-62` 的数量字只有 size=12 + glow，**没有 bold** ⇒ 这里也要
		# 钉住"没有吃到全局加粗壳"，防止再把全局 embolden 加回来。
		var 量字 := 量.get_theme_font("font")
		_查(皮肤表.字体落点(量字).contains("simsun_原版"),
				"⑯数量字该走全局 `simsun_原版.ttf`（原版自带字体），实际 %s" % 皮肤表.字体落点(量字))
		_查(not (量字 is FontVariation),
				"⑯数量字不该吃全局合成加粗（实际 %s）—— 原版 `ItemWindowCell` 只设 size=12 + glow，没有 bold；全局加粗会把 12px 数字抹糊" % str(量字))
	格实例.free()
	# 运行时：渲染背包页，塞一件 20 个的堆叠，核渲染后 Label 的文本/字号/描边
	会话.inventory.clear()
	会话.inventory.append(_件("16000016", 20))
	var 格2 := (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(格2)
	await process_frame
	格2.call("open_page", "背包")
	for _i in 5:
		await process_frame
	var 页16 := 格2.find_child("原版背包内容", true, false) as Control
	if 页16 == null:
		_失败.append("⑯运行时：背包页没建出来")
	else:
		var 量2 := 页16.find_child("数量", true, false) as Label
		if 量2 == null:
			_失败.append("⑯运行时：没找到数量 Label")
		else:
			_查(量2.text == "20", "⑯数量=20 该显示「20」（>1 才显，:281），实际 %s" % 量2.text)
			# 2026-10-25（用户：「背包可堆叠道具的数量显示字体，可以略微大一点」）：
			# 原版真值是 12，但这是**有意的画面偏离** ⇒ 门钉 14 而不是 12。
			# 14 仍在宋体点阵档（12~17）内，且 antialiasing=0 单色 ⇒ 数字实心、不会回灰度。
			_查(int(量2.get_theme_font_size("font_size")) == 14,
					"⑯运行时字号该被 configure_label 设成 14（原版 12；用户 2026-10-25 要求略大）")
			_查(int(量2.get_theme_constant("outline_size")) == 2,
					"⑯黑描边=2（≈原版 GlowFilter，走 皮肤表.文字规则_描边数值）")
		# —— ⑯b 标题里的格子数、底部三行货币值（2026-10-25 用户报「模糊、偏小」）——
		# 均为**有意偏离**：原版标题/货币值都是 12（`ItemWindow2.as:1108/1401-1406`）。
		# 标题拆两段：主标题「背包」保持标题变体 14（用户：「背包字体没问题」）；
		# 尾巴「(已用/总)」改走**裸 FontFile** 16 —— 标题变体的 `FontVariation` 合成加粗
		# 会把 ASCII 轮廓抹粗/走形（§3.281），用户因此说尾巴「还是模糊、大小差不多」；
		# 20 号嫌大 ⇒ 18 号后仍要「再小一点」⇒ 16 号：数字墨高 11px、括号 14px、
		# 笔画 2px、字芯纯 255。整条标题同时在 29px 标题栏内垂直居中。
		var 题16 := 格2.get("_title") as Label
		var 尾16 := 格2.get("_title_数值") as Label
		if 题16 == null or 尾16 == null:
			_失败.append("⑯b 运行时：拿不到窗口标题/标题数值")
		else:
			_查(int(题16.get_theme_font_size("font_size")) == 14,
					"⑯b 主标题「背包」该 14（原版 12；用户 2026-10-25 要求略大），实际 %d"
					% int(题16.get_theme_font_size("font_size")))
			_查(题16.text == "背包",
					"⑯b 主标题该只剩「背包」（尾巴另起一枚 Label），实际「%s」" % 题16.text)
			_查(尾16.visible, "⑯b 标题尾巴「(已用/总)」该显示")
			_查(尾16.text.begins_with("(") and 尾16.text.ends_with(")")
					and 尾16.text.contains("/"),
					"⑯b 标题尾巴该是「(已用/总)」，实际「%s」" % 尾16.text)
			_查(int(尾16.get_theme_font_size("font_size")) == 16,
					"⑯b 标题尾巴该 16（裸字体下数字墨高 11px；20 嫌大、18 后用户仍要再小），实际 %d"
					% int(尾16.get_theme_font_size("font_size")))
			_查(not (尾16.get_theme_font("font") is FontVariation),
					"⑯b 标题尾巴必须走裸 FontFile（合成加粗会把 ASCII 抹灰），实际 %s"
					% str(尾16.get_theme_font("font")))
			_查(尾16.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
					and 尾16.vertical_alignment == VERTICAL_ALIGNMENT_CENTER,
					"⑯b 标题尾巴该在自己的矩形里水平+垂直居中")
			# 尾巴字号更大 ⇒ Label 最小高度被字体撑高，尺寸可以不同；同一行看的是**垂直中心**。
			_查(is_equal_approx(尾16.position.y + 尾16.size.y * 0.5,
						题16.position.y + 题16.size.y * 0.5),
					"⑯b 尾巴该和主标题垂直中心对齐，题 y=%.1f h=%.1f 中心 %.1f，尾 y=%.1f h=%.1f 中心 %.1f"
					% [题16.position.y, 题16.size.y, 题16.position.y + 题16.size.y * 0.5,
						尾16.position.y, 尾16.size.y, 尾16.position.y + 尾16.size.y * 0.5])
			_查(is_equal_approx(尾16.position.x, 题16.position.x + 题16.size.x),
					"⑯b 尾巴该紧接在主标题右沿（题 %.1f+%.1f，尾 x=%.1f）"
					% [题16.position.x, 题16.size.x, 尾16.position.x])
			var 组宽 := 题16.size.x + 尾16.size.x
			var 窗宽 := float((格2.get("_window") as Control).size.x)
			_查(absf((题16.position.x + 组宽 * 0.5) - 窗宽 * 0.5) <= 1.0,
					"⑯b 「背包+格子数」整组该在窗口标题行居中（组中心 %.1f / 窗中心 %.1f）"
					% [题16.position.x + 组宽 * 0.5, 窗宽 * 0.5])
			# 2026-10-25 用户：「另外最好也是那个框内的中间位置」⇒ 整条标题在 29px
			# 标题栏的**垂直正中**（原来 y=2、离中心高 4px）。
			var 栏中心 := 29.0 * 0.5
			var 题中心 := 题16.position.y + 题16.size.y * 0.5
			_查(is_equal_approx(题中心, 栏中心),
					"⑯b 标题该在 29px 标题栏内垂直居中（标题中心 %.1f / 栏中心 %.1f）"
					% [题中心, 栏中心])
			# 换页必须清掉主标题/尾巴的 override 与尾巴文本：
			# 同一实例背包→人物时不能把 14/16 和「(已用/总)」带过去。
			格2.call("_apply_original_window", "人物")
			_查(int(题16.get_theme_font_size("font_size")) == 12,
					"⑯b 换页后标题字号该回主题 12（override 必须清），实际 %d"
					% int(题16.get_theme_font_size("font_size")))
			_查(is_equal_approx(题16.position.y, 2.0),
					"⑯b 换页后标题要回原落点 y=2（不能把背包的垂直居中带到别的窗），实际 %.1f"
					% 题16.position.y)
			_查(尾16.text.is_empty() and not 尾16.visible
					and not 尾16.has_theme_font_size_override("font_size"),
					"⑯b 换页后标题尾巴该整截收掉（文本/字号 override/可见性），实际「%s」%s"
					% [尾16.text, "可见" if 尾16.visible else "已藏"])
		for 货币 in [["游戏金币", "金币底", "金币图标"], ["商城元宝", "元宝底", "元宝图标"],
				["商城点券", "点券底", "点券图标"]]:
			var 货币标题 := 页16.find_child("%s标题" % 货币[0], true, false) as Label
			var 货币值 := 页16.find_child("%s值" % 货币[0], true, false) as Label
			var 货币底 := 页16.find_child(货币[1], true, false) as Control
			var 货币图 := 页16.find_child(货币[2], true, false) as Control
			if 货币值 == null or 货币底 == null or 货币图 == null or 货币标题 == null:
				_失败.append("⑯b 运行时：%s 的标题/值/底/图标没找齐" % 货币[0])
				continue
			# 第五轮版式回到左下：行标题 16..69（12 号）、值 98..372（14 号）横跨整行，
			# 行标题来自原版 `ItemWindow2.as:1395-1400` 的三枚行标签（文本直接烘在场景里）。
			_查(货币标题.text == 货币[0],
					"⑯b %s 标题文案该是「%s」（AS3 原文），实际「%s」" % [货币[0], 货币[0], 货币标题.text])
			_查(int(货币标题.get_theme_font_size("font_size")) == 12,
					"⑯b %s 标题字号该 12（原版行标题 12，放大只放大值），实际 %d"
					% [货币[0], int(货币标题.get_theme_font_size("font_size"))])
			_查(货币标题.mouse_filter == Control.MOUSE_FILTER_IGNORE,
					"⑯b %s 标题该不吃鼠标（压在底框上，别挡拖放）" % 货币[0])
			_查(is_equal_approx(货币标题.offset_left, 16.0)
					and is_equal_approx(货币标题.offset_right, 69.0),
					"⑯b %s 标题该在原版行首 16..69，实际 %.0f..%.0f"
					% [货币[0], 货币标题.offset_left, 货币标题.offset_right])
			var 题中 := 货币标题.offset_top + (货币标题.offset_bottom - 货币标题.offset_top) * 0.5
			_查(题中 >= 货币底.offset_top and 题中 <= 货币底.offset_bottom,
					"⑯b %s 标题该落在自己那行底框里（标题中线 %.1f，底框 %.0f..%.0f）"
					% [货币[0], 题中, 货币底.offset_top, 货币底.offset_bottom])
			_查(int(货币值.get_theme_font_size("font_size")) == 14,
					"⑯b %s 字号该 14（原版 12；用户要求略大），实际 %d"
					% [货币[0], int(货币值.get_theme_font_size("font_size"))])
			_查(货币值.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT,
					"⑯b %s 该靠左对齐（用户：靠图标留一点点距离但不要太远）" % 货币[0])
			_查(货币值.vertical_alignment == VERTICAL_ALIGNMENT_CENTER,
					"⑯b %s 该在货币底框内上下居中（用户报偏上）" % 货币[0])
			_查(is_equal_approx(货币值.offset_top, 货币底.offset_top)
					and is_equal_approx(货币值.offset_bottom, 货币底.offset_bottom),
					"⑯b %s 的上下沿该贴齐底框（%s..%s），实际 %s..%s"
					% [货币[0], 货币底.offset_top, 货币底.offset_bottom,
						货币值.offset_top, 货币值.offset_bottom])
			_查(is_equal_approx(货币值.offset_right, 货币底.offset_right),
					"⑯b %s 的右沿该贴齐底框右沿，底框右 %.0f、值右 %.0f"
					% [货币[0], 货币底.offset_right, 货币值.offset_right])
			# 用户 2026-10-25：先「还是靠左吧，跟图标一点点距离但不要太远」，随后「略微再近一点」
			# ⇒ 值框左沿 100 ⇒ **98**，离图标右沿实测 8/6/5px（字墨多 1px = 9/7/6）。
			# 98 本身钉死（挪回 100 即红）；5~12px 区间挡住贴图标或甩到框中间。
			_查(is_equal_approx(货币值.offset_left, 98.0),
					"⑯b %s 的左沿该 98（用户：略微再近一点），实际 %.0f"
					% [货币[0], 货币值.offset_left])
			_查(货币值.offset_left >= 货币图.offset_right + 5.0
					and 货币值.offset_left <= 货币图.offset_right + 12.0,
					"⑯b %s 该离货币图标 5~12px（一点点距离但不要太远），图标右 %.0f、值左 %.0f"
					% [货币[0], 货币图.offset_right, 货币值.offset_left])
			# 1 亿是用户点名的上限：左对齐时从 offset_left 起算，右沿不能顶出值框。
			var 宽亿 := 货币值.get_theme_font("font").get_string_size(
					"100,000,000", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var 右亿 := 货币值.offset_left + 宽亿
			_查(右亿 <= 货币值.offset_right,
					"⑯b %s 的 1 亿「100,000,000」左对齐后要放得下：字宽 %.1f / 值框 %.1f，右沿 %.1f / 框右 %.0f"
					% [货币[0], 宽亿, 货币值.size.x, 右亿, 货币值.offset_right])
	格2.queue_free()
	await process_frame
	会话.inventory.clear()

	# —— ⑰ 宝石镶嵌窗：装备菜单开、5/6 孔、摘除信号（2026-10-02 接菜单分发） ——
	# 真值：`onClickPopupMenu:777` `showStoneCarryWindow(curCellData)`；
	# `StoneCarryWindow.draw(param1)`：param1 = 装备是否橙装（aptitude == ORANGE），true 才 6 孔、宽 300。
	# 服务端 `_inlay_equipment_stone:54246-54252` 的口径是 `aptitude >= 5` 才 6 孔，一致。
	会话.inventory.clear()
	会话.inventory.append(_件("01010011", 1, {"aptitude": 1}))     # 紫下白/绿/蓝装：5 孔
	会话.inventory.append(_件("01010012", 1, {"aptitude": 5}))     # 橙装：6 孔
	var 管2 := (load("res://场景/界面/窗口管理.tscn") as PackedScene).instantiate()
	root.add_child(管2)
	await process_frame
	管2.call("打开", "背包")
	for _i in 5:
		await process_frame
	var 背窗2 := 管2.call("取窗口", "背包") as Node
	if 背窗2 == null:
		_失败.append("⑰背包窗没从窗口管理开出来")
	else:
		背窗2.set("_selected_inventory_id", "01010011")
		背窗2.set("_selected_inventory_格", 1)
		var 页17 := 背窗2.find_child("原版背包内容", true, false) as Control
		var 菜17 := 页17.get_node_or_null("物品菜单") as Control if 页17 != null else null
		# 「宝石镶嵌」登记在 `窗口管理.伴随背包`（原版 `centerTwoWindow`）⇒ 每开一次都重渲背包页，
		# 旧 `物品菜单` 句柄随即 free ⇒ 每点一次现取。
		var 点菜单17 := func(项: String) -> bool:
			var 页现 := 背窗2.find_child("原版背包内容", true, false) as Control
			var 菜现 := 页现.get_node_or_null("物品菜单") as Control if 页现 != null else null
			if 菜现 == null:
				return false
			菜现.emit_signal("选择了", 项)
			return true
		if 菜17 == null:
			_失败.append("⑰背包页/物品菜单不在")
		else:
			点菜单17.call("宝石镶嵌")
			await process_frame
			var 镶窗 := 管2.call("取窗口", "宝石镶嵌") as Node
			_查(镶窗 != null, "⑰菜单「宝石镶嵌」该开出镶嵌窗（旧代码走『未实现』兜底）")
			if 镶窗 != null:
				_查(int(镶窗.get("_宝石镶嵌装备格")) == 1
						and String(镶窗.get("_宝石镶嵌装备id")) == "01010011",
						"⑰装备格/id 该记到宿主上（跨窗状态：设在渲染那页的宿主，§3.62 老坑）")
				var 镶页 := 镶窗.find_child("原版宝石镶嵌内容", true, false) as Control
				if 镶页 == null:
					_失败.append("⑰镶嵌页没建出来")
				else:
					var 板17 := 镶页.get_node("孔面板") as Control
					var 可见 := 0
					for i in 6:
						if (板17.get_node("孔_%d" % i) as Control).visible:
							可见 += 1
					_查(可见 == 5, "⑰资质 1 的装备该 5 孔，实际 %d" % 可见)
					_查(int(镶页.get_node("内容底").offset_right) == 249,
							"⑰非橙装窗宽 254（内容底 right=249）")
		# 橙装 6 孔分流
		背窗2.set("_selected_inventory_id", "01010012")
		背窗2.set("_selected_inventory_格", 2)
		点菜单17.call("宝石镶嵌")
		await process_frame
		var 镶页2 := (管2.call("取窗口", "宝石镶嵌") as Node).find_child("原版宝石镶嵌内容", true, false) as Control
		var 板2 := 镶页2.get_node("孔面板") as Control
		var 可见2 := 0
		for i in 6:
			if (板2.get_node("孔_%d" % i) as Control).visible:
				可见2 += 1
		_查(可见2 == 6, "⑰橙装资质>=5 该 6 孔，实际 %d（`_inlay_equipment_stone:54246-52`）" % 可见2)
		_查(int(镶页2.get_node("内容底").offset_right) == 295,
				"⑰橙装窗加宽到 300（内容底 right=295，`StoneCarryWindow:58 setSize(300,204)`）")
		# 摘除信号：填一颗假 inlay 到 0 号孔、点它，看页面收到 请求摘除
		var 孔0 := 镶页2.get_node("孔面板/孔_0") as Button
		孔0.物品id = "13000001"
		var 收到: Array[int] = []
		var 收集: Callable = func(孔号: int): 收到.append(孔号)
		孔0.请求摘除.connect(收集)
		孔0.pressed.emit()
		_查(收到.size() == 1 and 收到[0] == 0, "⑰点已镶孔该发请求摘除(0基孔号)，实际 %s" % [收到])
		孔0.请求摘除.disconnect(收集)
		# 空孔不响应点击（原版 `deleteStoneHandler:232` 只在有宝石时才发协议）
		var 孔1 := 镶页2.get_node("孔面板/孔_1") as Button
		孔1.物品id = ""
		var 收到2: Array[int] = []
		var 收集2: Callable = func(孔号: int): 收到2.append(孔号)
		孔1.请求摘除.connect(收集2)
		孔1.pressed.emit()
		_查(收到2.is_empty(), "⑰空孔点下去不该发请求摘除（原版同样只在有宝石时发）")
		孔1.请求摘除.disconnect(收集2)
		# —— 走**真拖放路径**：空孔收一颗背包来的宝石（`_can_drop_data/_drop_data`）——
		# ⚠️ 这条是补的：上一版在线门**直接调 `会话.inlay_stone`**、没走 UI，于是漏掉了一个真 bug ——
		#   `请求镶嵌` 信号只带 1 参、处理函数要 2 参 → "Method expected 2 arguments"、处理链根本没跑，
		#   表现正是用户报的"拖进去没反应"。这里从 UI 入口钉住整条链（孔空→收宝石→发信号→处理函数→会话）。
		var 孔3 := 镶页2.get_node("孔面板/孔_2") as Button
		孔3.物品id = ""
		var 源格: Button = (load("res://场景/界面/组件/物品格.tscn") as PackedScene).instantiate()
		源格.槽位号 = 5
		var 载荷 := {"来源格": 源格, "归属": "背包", "物品id": "13000001"}
		_查(孔3._can_drop_data(Vector2.ZERO, 载荷), "⑰空孔该收背包来的宝石（可落）")
		_查(not 孔3._can_drop_data(Vector2.ZERO,
				{"来源格": 源格, "归属": "背包", "物品id": "03000001"}),
				"⑰非宝石（药剂）不该落进孔里")
		var 系统话: Array[String] = []
		var 收系统: Callable = func(话: String): 系统话.append(话)
		会话.notification_requested.connect(收系统)
		孔3._drop_data(Vector2.ZERO, 载荷)
		await process_frame
		_查(not 系统话.is_empty(),
				"⑰拖宝石进孔→处理链要跑到（离线走系统消息反馈）；空=信号参数不匹配、函数没执行")
		会话.notification_requested.disconnect(收系统)
		源格.free()
	管2.queue_free()
	await process_frame
	会话.inventory.clear()

	# —— ⑰c/d/e 镶嵌窗三件（2026-11-02 用户报，§3.362）——
	# 真值：`UIMain2.as:2720-2733`（宝石）与 `:5558-5570`（勾玉）开窗都是
	# `centerTwoWindow(STONE/GOUYU_CARRY_WINDOW, ITEM_WINDOW2_F)`：
	#   · 镶嵌窗在**左**、背包在**右**、主窗左沿 = (视口宽 − 主宽 − 包宽 − 1)/2、
	#     背包左沿 = 主窗左沿 + 主宽 + 1（`UIMain2.as:3170-3176`）；
	#   · 后开的那扇（镶嵌窗）在**顶上**（`setDOShow` 顺序 + `bringMWindowToTop`）。
	# 每枚孔 = `SimpleItemCell`，它填图标时挂 `MToolTipItem.createToolTip`
	# （`SimpleItemCell.as:220`）⇒ 已镶的勾玉悬停要弹物品详情。
	# 这扇窗是常驻件：回帧重渲只重排孔，**窗的位置不动**。
	# 摆位是几何题：headless 默认视口 64x64 会把「整对居中」算成负数，按真实舞台钉住
	# （口径同 `窗口行为契约体检` 开头那句 `root.size = 设计视口`）。
	root.size = Vector2i(960, 560)
	会话.inventory.clear()
	会话.inventory.append(_件("01410002", 1, {"slot_index": 1}))               # 占位
	会话.inventory.append(_件("01200020", 1, {"slot_index": 2,
			"inlays": [{"stone_id": 13100001}]}))                                # 玉链 stage2，0 号孔已镶一颗 2 级勾玉
	会话.inventory.append(_件("13100001", 1, {"slot_index": 3}))               # 背包里待镶的勾玉
	var 管152 := (load("res://场景/界面/窗口管理.tscn") as PackedScene).instantiate()
	root.add_child(管152)
	await process_frame
	管152.call("打开", "背包")
	for _i in 5:
		await process_frame
	var 背152 := 管152.call("取窗口", "背包") as Node
	if 背152 == null:
		_失败.append("⑰c 背包窗没开出来")
	else:
		背152.set("_selected_inventory_id", "01200020")
		背152.set("_selected_inventory_格", 2)
		var 页152 := 背152.find_child("原版背包内容", true, false) as Control
		var 菜152 := 页152.get_node_or_null("物品菜单") as Control if 页152 != null else null
		if 菜152 == null:
			_失败.append("⑰c 背包页/物品菜单不在")
		else:
			菜152.emit_signal("选择了", "镶嵌勾玉")
			for _i in 5:
				await process_frame
			_查(管理脚本.伴随背包.has("宝石镶嵌"),
					"⑰c「宝石镶嵌」该登记进 `伴随背包`（原版 showStone/GouYuCarryWindow 都 centerTwoWindow）")
			var 镶152 := 管152.call("取窗口", "宝石镶嵌") as Node
			_查(镶152 != null and bool(镶152.call("已打开")), "⑰c 镶嵌窗该开着")
			if 镶152 != null and 背152 != null:
				# 成对摆位：主窗左、背包右、紧贴 1px、整对水平居中
				var 主框 := 镶152.get_node("遮罩/主窗口") as Control
				var 包框 := 背152.get_node("遮罩/主窗口") as Control
				var 主矩 := 主框.get_global_rect()
				var 包矩 := 包框.get_global_rect()
				var 视口 := root.get_visible_rect().size
				var 应主左 := maxf(0.0, (视口.x - (主矩.size.x + 包矩.size.x + 1.0)) * 0.5)
				_查(absf(主矩.position.x - 应主左) <= 0.6,
						"⑰c 镶嵌窗该在整对里居左：左沿 %.1f，应 (视口−主宽−包宽−1)/2 = %.1f"
						% [主矩.position.x, 应主左])
				_查(absf((主矩.position.x + 主矩.size.x + 1.0) - 包矩.position.x) <= 0.6,
						"⑰c 背包该紧贴镶嵌窗右侧 1px：镶嵌右沿 %.1f、背包左沿 %.1f（UIMain2.as:3176）"
						% [主矩.position.x + 主矩.size.x, 包矩.position.x])
				_查(int(镶152.layer) > int(背152.layer),
						"⑰c 后开的镶嵌窗层级要高过背包（layer %d vs %d）"
						% [int(镶152.layer), int(背152.layer)])
				_查(管152.call("取最上层窗口") == 镶152,
						"⑰c 镶嵌窗该是当前最上层窗口（后开的子面板压在背包上）")
				# ⑰d 已镶勾玉的孔：悬停弹物品详情（含「勾玉属性」那一段）
				var 页镶152 := 镶152.find_child("原版宝石镶嵌内容", true, false) as Control
				if 页镶152 == null:
					_失败.append("⑰d 镶嵌页没建出来")
				else:
					var 提示 := 页镶152.get_node_or_null("物品提示框") as Control
					_查(提示 != null, "⑰d 镶嵌页该在运行期挂上「物品提示框」（场景是 SPEC 生成物）")
					if 提示 != null:
						_查(not 提示.visible, "⑰d 没人悬停时详情框该收着")
						var 孔镶 := 页镶152.get_node("孔面板/孔_0") as Button
						_查(String(孔镶.物品id) == "13100001",
								"⑰d 0 号孔该认得镶在里面的那颗勾玉，实际「%s」" % 孔镶.物品id)
						孔镶.emit_signal("mouse_entered")
						await process_frame
						var 抬头 := 提示.get_node_or_null("宝石抬头") as Label
						var 值 := 提示.get_node_or_null("宝石值") as Label
						_查(提示.visible, "⑰d 悬停已镶的孔该弹出详情框（SimpleItemCell.as:220）")
						_查(String((提示.get_node("标题") as Label).text) == "勾玉（2级）",
								"⑰d 详情框标题该是那颗勾玉的名字")
						_查(抬头 != null and 抬头.visible and String(抬头.text) == "勾玉属性",
								"⑰d 详情框该有「勾玉属性」抬头")
						_查(值 != null and 值.visible and String(值.text) == "怪力  +2层",
								"⑰d 详情框该写「技能名 +N层」（1002001=怪力 / gouyu_level=2），实际「%s」"
								% ("" if 值 == null else String(值.text)))
						孔镶.emit_signal("mouse_exited")
						_查(not 提示.visible, "⑰d 移开鼠标该把详情框收掉")
						# 空孔悬停：把框强行点亮，再 hover 空格 ⇒ 必须被收掉（`格子提示框` 空格分支）
						提示.visible = true
						var 空孔 := 页镶152.get_node("孔面板/孔_1") as Button
						_查(String(空孔.物品id) == "", "⑰d 1 号孔该是空的（stage2 只镶 1 颗）")
						空孔.emit_signal("mouse_entered")
						_查(not 提示.visible, "⑰d 悬停空孔该把残留的详情框收掉")
				# ⑰e 回帧重渲（库存变了 ⇒ `_refresh_current` ⇒ `_render_page` ⇒ `_镶嵌定宽`）
				# 不许把玩家拖过的窗挪回正中。
				镶152.call("窗口偏移", Vector2(-150.0, -40.0))
				await process_frame
				var 旧偏: Vector2 = 镶152.call("取位置偏移")
				var 旧矩 := 主框.get_global_rect()
				(会话.inventory[1] as Dictionary)["inlays"] = [{"stone_id": 13100001}, {"stone_id": 13100001}]
				会话.inventory_changed.emit(会话.inventory)
				for _i in 5:
					await process_frame
				var 新偏: Vector2 = 镶152.call("取位置偏移")
				var 主框2 := 镶152.get_node("遮罩/主窗口") as Control
				var 新矩 := 主框2.get_global_rect()
				_查(新偏.distance_to(旧偏) <= 0.6,
						"⑰e 回帧重渲不该改窗的偏移：拖到 %s，重渲后变 %s" % [旧偏, 新偏])
				_查(新矩.position.distance_to(旧矩.position) <= 0.6,
						"⑰e 回帧重渲不该挪窗的位置：原 %s、后 %s" % [旧矩.position, 新矩.position])
				_查(主框2.size.x == 254.0,
						"⑰e 重渲后仍是 stage2 的 254 宽（孔数没变），实际 %.0f" % 主框2.size.x)
	管152.queue_free()
	await process_frame
	会话.inventory.clear()

	# —— ⑱ 宝石工艺窗·合成页（2026-10-03 实装）——
	# 真值：`StoneCompositeWindow.as`（validateItem/submitToHandle/updateDescription/
	# operationResultHandler）+ `UIMain2.showStoneWindowWithData:4523-4540`（满级**连窗都不开**）。
	# ⚠️ **全走真入口**：物品菜单「合成」/ 拖放落点 / 点按钮 —— 不直接调 `会话.merge_stone`
	#   （§3.85.5 那条：只调会话会漏掉整条 UI 接线）。数据全用 `数据/物品.json` 真行，不编属性。
	会话.inventory.clear()
	会话.inventory.append(_件("13010000", 4, {"category": "宝石", "slot_index": 1}))   # 黄色宝石(1级)×4：能合成
	会话.inventory.append(_件("13000009", 1, {"category": "宝石", "slot_index": 2}))   # 红色宝石(影10级)：满级闸
	会话.inventory.append(_件("13020000", 2, {"category": "宝石", "slot_index": 3}))   # 只有 2 颗：不足3闸
	会话.inventory.append(_件("03000001", 5, {"slot_index": 4}))                        # 药剂：不该能落进合成格
	会话.player_stats["gold"] = 100000
	var 通知18: Array[String] = []
	var 收18: Callable = func(话: String): 通知18.append(话)
	会话.notification_requested.connect(收18)
	var 管18 := (load("res://场景/界面/窗口管理.tscn") as PackedScene).instantiate()
	root.add_child(管18)
	await process_frame
	管18.call("打开", "背包")
	for _i in 5:
		await process_frame
	var 背窗18 := 管18.call("取窗口", "背包") as Node
	var 页18: Control = 背窗18.find_child("原版背包内容", true, false) as Control if 背窗18 != null else null
	var 菜18: Control = 页18.get_node_or_null("物品菜单") as Control if 页18 != null else null
	if 菜18 == null:
		_失败.append("⑱背包页/物品菜单不在")
	else:
		# 取一次页面上当前那份「宝石工艺」的渲染节点（每次刷新都是新建的，引用别存着复用）
		var 艺页 := func() -> Control:
			var 窗: Node = 管18.call("取窗口", "挖矿")
			return 窗.find_child("原版宝石工艺内容", true, false) as Control if 窗 != null else null
		# 1) 菜单「合成」开门：带**那一格**、切到合成页、三页签齐（原版 `showStoneWindowWithData`）
		背窗18.set("_selected_inventory_id", "13010000")
		背窗18.set("_selected_inventory_格", 1)
		菜18.emit_signal("选择了", "合成")
		await process_frame
		var 艺窗 := 管18.call("取窗口", "挖矿") as Node
		_查(艺窗 != null, "⑱菜单「合成」该开出「宝石工艺」窗（旧代码走『未实现』兜底）")
		if 艺窗 != null:
			_查(int(艺窗.get("_宝石合成格")) == 1 and String(艺窗.get("_宝石合成id")) == "13010000",
					"⑱带进来的该是**点的那一格**那颗（跨窗状态设在宿主，§3.62 老坑）")
			_查(int(艺窗.get("_stone_tab")) == 0, "⑱开门该停在「宝石合成」页（showCompositeWindow 切 tab0）")
		var 面18 := 艺页.call() as Control
		if 面18 == null:
			_失败.append("⑱合成页没建出来")
		else:
			_查((面18.get_node("分页/宝石幸运合成") as Button).visible,
					"⑱三页签窗：`EQUIP_STONE_TAB_NAMES_3`「宝石幸运合成」得在（基线也是三页）")
			_查(面18.get_node("内容框").offset_right == 327.0,
					"⑱内容盒右界 327（AS3 contentBox (5,58) 宽 322 整框，页局部 = 窗口 −29）")
			_查(面18.get_node("开始合成").position.is_equal_approx(Vector2(266, 343)),
					"⑱开始合成按钮 (266,343)（AS3 右下、边距 5：332-61-5 / 399-22-5-29）")
			# 放进来的那颗：图标 + 整摞件数角标；预览格 = `inlay.next` 那颗；按钮换「取出宝石」
			var 源钮18 := 面18.get_node("内容框/宝石合成页/放入宝石区/原宝石格") as Button
			_查(源钮18.icon != null, "⑱放进来的宝石该摆上图标")
			_查(String((源钮18.get_node("数量") as Label).text) == "4",
					"⑱数量角标=整摞件数（`itemCell.label=count`，实际 %s）" % (源钮18.get_node("数量") as Label).text)
			_查((面18.get_node("内容框/宝石合成页/放入宝石区/放入宝石") as Button).text == "取出宝石",
					"⑱放下后那颗钮该换「取出宝石」（DROP_ITEM_BTN_NAMES_2）")
			var 预览18 := 面18.get_node("内容框/宝石合成页/放入宝石区/合成宝石格/图标") as TextureRect
			_查(预览18.texture != null and String(预览18.texture.resource_path).contains("13010001"),
					"⑱产物预览 = `inlay.next` 那颗（13010001，链列由导出器补）")
			var 说明18 := 面18.get_node("内容框/宝石合成页/结果说明区/结果说明") as RichTextLabel
			_查(说明18.text.contains("消耗金币：800") and 说明18.text.contains("成功几率：80%"),
					"⑱金币=needMoney×批数（level2=800×1）、几率=merge.level2.prob=80（实际 %s）" % 说明18.text)
			_查(not 说明18.text.contains("[color=#ff0000]800[/color]"),
					"⑱金币够付时那个 800 不该是红的（红字只剩 DESCS_3 那句注意）")
			# 2) 满级那颗：只弹「该宝石已经是最高等级！」，**不顶掉已放的**（原版开门前就 return）
			# ⚠️ 重取菜单：挖矿已登记 `伴随背包`（§3.385）⇒ 上一步开它时 `打开("背包")`
			#    把背包页整页重建，`页18`/`菜18` 已 free。
			通知18.clear()
			背窗18.set("_selected_inventory_id", "13000009")
			背窗18.set("_selected_inventory_格", 2)
			菜18 = (背窗18.find_child("原版背包内容", true, false) as Control).get_node_or_null("物品菜单") as Control
			if 菜18 == null:
				_失败.append("⑱背包重开后物品菜单不在")
			else:
				菜18.emit_signal("选择了", "合成")
			await process_frame
			_查(通知18.size() == 1 and 通知18[0] == "该宝石已经是最高等级！",
					"⑱满级开门逐字 CN.IS_STONE_LEVEL_MAX（实际 %s）" % [通知18])
			_查(艺窗 != null and int(艺窗.get("_宝石合成格")) == 1, "⑱满级那颗不许覆盖已放的这一格")
			# 3) 真拖放落点：药剂拒、宝石收；满级宝石落上来只弹话不收
			# ⚠️ 重新取一次源格：上一步若**又触发了开窗/重建**（满级开门被改坏时会重开），
			#    `面18`/`源钮18` 就成 previously-freed —— 重取让坏版本报**断言红**而不是崩到看门狗。
			源钮18 = (艺页.call()).get_node("内容框/宝石合成页/放入宝石区/原宝石格") as Button
			var 假源 := (load("res://场景/界面/组件/物品格.tscn") as PackedScene).instantiate() as Button
			假源.槽位号 = 4
			_查(not 源钮18._can_drop_data(Vector2.ZERO,
					{"来源格": 假源, "归属": "背包", "物品id": "03000001"}),
					"⑱药剂不该能落进合成格（`validateItem` 只认宝石）")
			假源.槽位号 = 3
			_查(源钮18._can_drop_data(Vector2.ZERO,
					{"来源格": 假源, "归属": "背包", "物品id": "13020000"}),
					"⑱背包来的宝石该能落进合成格")
			源钮18._drop_data(Vector2.ZERO, {"来源格": 假源, "归属": "背包", "物品id": "13020000"})
			await process_frame
			var 面18b := 艺页.call() as Control
			_查(艺窗 != null and int(艺窗.get("_宝石合成格")) == 3,
					"⑱拖进来该经**真信号**放上格 3（空=处理函数没跑，§3.85.5 同族）")
			_查(String((面18b.get_node("内容框/宝石合成页/放入宝石区/原宝石格/数量") as Label).text) == "2",
					"⑱换上 2 颗的那摞后角标该跟到 2")
			# 满级宝石拖上来 → 弹话、不放、放置态原样
			通知18.clear()
			var 假源2 := (load("res://场景/界面/组件/物品格.tscn") as PackedScene).instantiate() as Button
			假源2.槽位号 = 2
			源钮18 = 面18b.get_node("内容框/宝石合成页/放入宝石区/原宝石格") as Button
			源钮18._drop_data(Vector2.ZERO, {"来源格": 假源2, "归属": "背包", "物品id": "13000009"})
			await process_frame
			_查(通知18.size() == 1 and 通知18[0] == "该宝石已经是最高等级！",
					"⑱满级那颗落上来只弹话（`validateItem:191-196`），实际 %s" % [通知18])
			_查(int(艺窗.get("_宝石合成格")) == 3, "⑱满级那颗不许把已放的顶掉")
			# 4) 「开始合成」的三道客户端闸（`submitToHandle:354-375`，**判序**照原版）
			#    a) 不足 3：格 3 那摞只有 2 颗 —— 弹 CN.EQUIP_STONE_FAIL_PROMPT_1，不发协议
			通知18.clear()
			var 成钮18 := (艺页.call()).get_node("开始合成") as Button
			成钮18.pressed.emit()
			await process_frame
			_查(通知18.size() == 1 and 通知18[0] == "对不起，宝石合成需要三颗以上的宝石！",
					"⑱不足 3 颗的文案逐字（实际 %s）" % [通知18])
			_查(int(会话._占用条(会话.inventory, 3).get("quantity", 0)) == 2, "⑱闸拦下后一件都不许扣")
			#    b) 金币不够：换回 4 颗那摞（花费 800），gold=0 → 「很抱歉，你的金币不够」+ 数字换红
			假源.槽位号 = 1
			源钮18._drop_data(Vector2.ZERO, {"来源格": 假源, "归属": "背包", "物品id": "13010000"})
			await process_frame
			会话.player_stats["gold"] = 0
			艺窗.call("_refresh_current")
			await process_frame
			通知18.clear()
			var 面18c := 艺页.call() as Control
			((面18c.get_node("开始合成")) as Button).pressed.emit()
			await process_frame
			_查(通知18.size() == 1 and 通知18[0] == "很抱歉，你的金币不够",
					"⑱金币闸文案逐字（FAIL_PROMPT_2[0]→[1]，实际 %s）" % [通知18])
			var 说明18c := 面18c.get_node("内容框/宝石合成页/结果说明区/结果说明") as RichTextLabel
			_查(说明18c.text.contains("[color=#ff0000]800[/color]"),
					"⑱金币不够时那个 800 该换红（`updateDescription:95`，实际 %s）" % 说明18c.text)
			_查(int(会话._占用条(会话.inventory, 1).get("quantity", 0)) == 4, "⑱被闸拦下不许消耗")
			#    c) 三关都过、但离线 → 系统消息说清"要在服务端结算"，镜像一根手指都不动
			会话.player_stats["gold"] = 100000
			艺窗.call("_refresh_current")
			await process_frame
			通知18.clear()
			((艺页.call()).get_node("开始合成") as Button).pressed.emit()
			await process_frame
			_查(通知18.size() == 1 and 通知18[0].contains("服务端结算"),
					"⑱离线要明说在服务端结算（同 §3.85.2 宝石族口径，实际 %s）" % [通知18])
			_查(int(会话._占用条(会话.inventory, 1).get("quantity", 0)) == 4, "⑱离线不模拟、一颗都不许扣")
			# 5) 取出宝石：清空放置 + 预览 + 三格，按钮换回「放入宝石」
			((艺页.call()).get_node("内容框/宝石合成页/放入宝石区/放入宝石") as Button).pressed.emit()
			await process_frame
			var 面18d := 艺页.call() as Control
			_查(int(艺窗.get("_宝石合成格")) == 0, "⑱取出后放置态清零")
			_查((面18d.get_node("内容框/宝石合成页/放入宝石区/放入宝石") as Button).text == "放入宝石",
					"⑱取出后按钮换回「放入宝石」")
			_查(((面18d.get_node("内容框/宝石合成页/放入宝石区/合成宝石格/图标")) as TextureRect).texture == null,
					"⑱没放东西时预览格该空着")
			# 6) 页签：镶嵌摘除页**没有提交**（AS3 tab1 藏 upgradeBtn）；幸运页有按钮但只给诚实话
			((面18d.get_node("分页/宝石镶嵌与摘除")) as Button).pressed.emit()
			await process_frame
			var 面18e := 艺页.call() as Control
			_查(not (面18e.get_node("开始合成") as Button).visible,
					"⑱镶嵌摘除页该藏「开始合成」（`selectedBtnHandler:82`）")
			_查((面18e.get_node("内容框/镶嵌摘除页") as Control).visible, "⑱切到镶嵌摘除页")
			((面18e.get_node("分页/宝石幸运合成")) as Button).pressed.emit()
			await process_frame
			var 面18f := 艺页.call() as Control
			_查((面18f.get_node("开始合成") as Button).visible,
					"⑱幸运页按原版**显着**提交按钮（`selectedBtnHandler:91`）")
			# 2026-10-11 §3.100：这一页从"诚实提示"换成**真面板**（与合成页同族 + 一行幸运符）。
			for 路 in ["内容框/幸运合成页/放入宝石区/放入宝石",
					"内容框/幸运合成页/结果格/成功/物品格/底", "内容框/幸运合成页/结果格/退还/物品格/底",
					"内容框/幸运合成页/结果格/剩余/物品格/底", "内容框/幸运合成页/幸运符格/物品格/底",
					"内容框/幸运合成页/使用幸运符", "内容框/幸运合成页/幸运符数量",
					"内容框/幸运合成页/张", "内容框/幸运合成页/结果说明区/结果说明"]:
				_查(面18f.get_node_or_null(路) != null, "⑱幸运页该有 `%s`（§3.100 实装的真面板）" % 路)
			_查(String((面18f.get_node("内容框/幸运合成页/使用幸运符") as CheckBox).text) == "本次操作使用",
					"⑱幸运符勾选文字 = `EQUIP_STRENGTH_DESC_TEMPLATE_2`「本次操作使用」")
			_查((面18f.get_node("内容框/幸运合成页/幸运符数量") as OptionButton).item_count == 20,
					"⑱张数下拉 = `LUCKY_MAX_COUNT` 20 项")
			# ★ 2026-10-11 修：勾选 / 选张数**不许重建这一页**。
			#   这一页每次渲染整个重建 ⇒ 若跟着 `_refresh_current()`，勾上就立刻弹回未勾、
			#   张数永远回到 1（幸运符这条功能实际用不了）。原版
			#   `clickCheckBoxHandler:320` / `comboBoxChangeHandler:326` 只 `updateDescription()`。
			var 勾18 := 面18f.get_node("内容框/幸运合成页/使用幸运符") as CheckBox
			var 拉18 := 面18f.get_node("内容框/幸运合成页/幸运符数量") as OptionButton
			勾18.button_pressed = true
			await process_frame
			await process_frame
			_查(is_instance_valid(面18f) and 面18f.is_inside_tree(),
					"⑱勾上「使用幸运符」后幸运页**不许被重建**（重建 = 勾选态被丢掉）")
			# ⚠️ 上一句如果红了（= 页面真被重建），`勾18/拉18/面18f` 可能已经 previously-freed；
			#    再摸它们会**崩成看门狗超时**、门只会说"崩了"说不出哪条坏 —— 先判存活再摸
			#    （见交接文档"形状"第 2 条）。
			if not (is_instance_valid(勾18) and is_instance_valid(拉18) and is_instance_valid(面18f)):
				_查(false, "⑱勾选/下拉/页面节点已被重建释放 —— 后面的交互断言做不了")
			else:
				_查(勾18.button_pressed, "⑱勾上后勾选态保持不弹回")
				_查(not 拉18.disabled, "⑱勾上后「张数」下拉该解禁")
				拉18.select(19)
				拉18.item_selected.emit(19)
				await process_frame
				await process_frame
				_查(is_instance_valid(面18f) and 面18f.is_inside_tree(), "⑱选「张数」后幸运页**不许被重建**")
				_查(拉18.selected == 19, "⑱张数下拉选中的还是第 20 张（`LUCKY_MAX_COUNT`）")
			# 后面统一**重取**页面（旧引用可能已释放；`艺页` 是个 Callable，每次取当前页）。
			var 面18幸 := 艺页.call() as Control
			通知18.clear()
			((面18幸.get_node("开始合成")) as Button).pressed.emit()
			await process_frame
			_查(通知18.size() == 1 and not 通知18[0].contains("未实装"),
					"⑱幸运合成不再是「未实装」（子命令 31 已实装，实际 %s）" % [通知18])
			_查(通知18.size() == 1 and (通知18[0].contains("服务端结算") or 通知18[0].contains("请放入宝石")),
					"⑱幸运页提交走真路径（离线落到「要在服务端结算」或四道前置提示，实际 %s）" % [通知18])
			((面18幸.get_node("分页/宝石合成")) as Button).pressed.emit()
			await process_frame
			# 7) 1042 回包 → 成功/退还/剩余 三格（走真处理链 `_on_item_change_result`，数据全真 id）
			#    先放回 4 颗那摞（放回会顺手清掉上一次的三格，正好验证清空→回包再填这条顺序）
			假源.槽位号 = 1
			(艺页.call()).get_node("内容框/宝石合成页/放入宝石区/原宝石格")._drop_data(
					Vector2.ZERO, {"来源格": 假源, "归属": "背包", "物品id": "13010000"})
			await process_frame
			艺窗.call("_on_item_change_result", 1042, {
				"kind": "stone_merge",
				"success_count": 1, "success_item_id": 13010001, "success_level": 2,
				"failed_count": 0, "failed_item_id": 13010000, "failed_level": 1,
				"left_count": 6, "left_item_id": 13010000, "left_level": 1,
			})
			await process_frame
			var 面18g := 艺页.call() as Control
			var 成格18 := 面18g.get_node("内容框/宝石合成页/结果格/成功/物品格") as Control
			var 退格18 := 面18g.get_node("内容框/宝石合成页/结果格/退还/物品格") as Control
			var 余格18 := 面18g.get_node("内容框/宝石合成页/结果格/剩余/物品格") as Control
			_查(((成格18.get_node("图标")) as TextureRect).texture != null
					and String(((成格18.get_node("图标")) as TextureRect).texture.resource_path).contains("13010001")
					and String((成格18.get_node("数量") as Label).text) == "1",
					"⑱成功格=回包那颗产物+计数（`operationResultHandler:135-141`）")
			_查(((退格18.get_node("图标")) as TextureRect).texture == null,
					"⑱这回合成功，退还格该空（原版 count<=0 不摆，:146-156）")
			_查(String((余格18.get_node("数量") as Label).text) == "6"
					and String(((余格18.get_node("图标")) as TextureRect).texture.resource_path).contains("13010000"),
					"⑱剩余格=吃掉3颗后剩下的那摞（left_count 6）")
			假源.free()
			假源2.free()
	会话.notification_requested.disconnect(收18)
	管18.queue_free()
	await process_frame
	会话.inventory.clear()
	会话.player_stats["gold"] = int(_快照["player_stats"].get("gold", 0))

	# —— ㉑ 使用/出售/存/取按**玩家点的那一格**（2026-10-17 巡检 #16）——
	# 病根：这四条一直写成 `会话._inventory_index(id)` 反查**第一摞** —— 背包里同 id 两摞
	# （拆分、发放、买两趟都会造出来）时，点第二摞动的是第一摞：吃错药、卖错那一款、
	# 存仓库存走另一摞。销毁早在 2026-10-01 A/C 就改按格了（⑩），「绑定」也按
	# `_selected_inventory_格`（⑪），这四条一直漏着。
	# 造两摞同 id、**数量不同**（9 / 3）⇒ 一验就知道动的是哪摞。
	会话.inventory = 会话.落位带洞([_件("03000001", 9, {"slot_index": 1}),
			_件("03000001", 3, {"slot_index": 2})])
	_查(bool(会话.call("use_inventory_slot", 2)), "㉑按格使用应成功")
	_查(int(会话._占用条(会话.inventory, 2).get("quantity", 0)) == 2
			and int(会话._占用条(会话.inventory, 1).get("quantity", 0)) == 9,
			"㉑点第二摞该吃第二摞（旧写法按 id 反查吃的是第一摞 9→8），实测格1=%d 格2=%d" % [
				int(会话._占用条(会话.inventory, 1).get("quantity", 0)),
				int(会话._占用条(会话.inventory, 2).get("quantity", 0))])
	# 出售：单价 floor(20/3)=6，卖**格2** 一件 ⇒ 只动格2、进账 6。
	会话.player_stats["gold"] = 0
	_查(bool(会话.call("sell_inventory_slot", 2, 1)), "㉑按格出售应成功")
	_查(int(会话._占用条(会话.inventory, 2).get("quantity", 0)) == 1
			and int(会话._占用条(会话.inventory, 1).get("quantity", 0)) == 9
			and int(会话.player_stats.get("gold", 0)) == 6,
			"㉑卖格2 不许动格1（旧写法会卖掉第一摞），实测格1=%d 格2=%d 金币=%d" % [
				int(会话._占用条(会话.inventory, 1).get("quantity", 0)),
				int(会话._占用条(会话.inventory, 2).get("quantity", 0)),
				int(会话.player_stats.get("gold", 0))])
	# 存仓库：整摞搬走的是格2 那一摞（3 件），格1 的 9 件留在背包。
	会话.inventory = 会话.落位带洞([_件("03000001", 9, {"slot_index": 1}),
			_件("03000001", 3, {"slot_index": 2})])
	会话.storage.clear()
	_查(bool(会话.call("deposit_slot", 2)), "㉑按格存入应成功")
	_查(会话._占用条(会话.inventory, 2).is_empty()
			and int(会话._占用条(会话.inventory, 1).get("quantity", 0)) == 9
			and _仓库件数(会话, "03000001") == 3,
			"㉑存格2 该搬 3 件进仓库、格1 原样，实测仓库=%d 格1=%d" % [
				_仓库件数(会话, "03000001"), int(会话._占用条(会话.inventory, 1).get("quantity", 0))])
	# 取回：仓库两摞同 id（9 / 3），取**格2** ⇒ 搬 3 件回背包、仓库格1 不动。
	会话.inventory.clear()
	会话.storage = 会话.落位带洞([_件("03000001", 9, {"slot_index": 1}),
			_件("03000001", 3, {"slot_index": 2})])
	_查(bool(会话.call("withdraw_slot", 2)), "㉑按格取回应成功")
	_查(会话._占用条(会话.storage, 2).is_empty()
			and int(会话._占用条(会话.storage, 1).get("quantity", 0)) == 9
			and _背包件数(会话, "03000001") == 3,
			"㉑取仓库格2 该搬 3 件回背包、仓库格1 原样，实测背包=%d 仓库格1=%d" % [
				_背包件数(会话, "03000001"), int(会话._占用条(会话.storage, 1).get("quantity", 0))])
	# 越界/空格（洞）要静默 false，不许拿 0 当"格1"用。
	_查(not bool(会话.call("use_inventory_slot", 0)), "㉑格 0（非法）使用要 false")
	_查(not bool(会话.call("withdraw_slot", 999)), "㉑越界取回要 false")
	# 端到端：真点第二格（`pressed` → `_选中格子` 记 `_selected_inventory_格`）
	# → 菜单「使用」→ `_执行菜单项` → 会话。旧链路在这里把格号丢掉、按 id 反查。
	会话.inventory = 会话.落位带洞([_件("03000001", 9, {"slot_index": 1}),
			_件("03000001", 3, {"slot_index": 2})])
	var 窗21q := (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(窗21q)
	await process_frame
	窗21q.call("open_page", "背包")
	for _i in 5:
		await process_frame
	var 页21q := 窗21q.find_child("原版背包内容", true, false) as Control
	if 页21q == null:
		_失败.append("㉑端到端：背包页没建出来")
	else:
		var 第二格 := 页21q.get_node("格子滚动/格子容器/物品格_1") as Button
		_查(第二格 != null and int(第二格.槽位号) == 2,
				"㉑第二格的 1 基槽位号该是 2（渲染按 页*100+i+1 设），实测 %s" % [str(第二格)])
		if 第二格 != null:
			第二格.pressed.emit()
			await process_frame
			_查(int(窗21q.get("_selected_inventory_格")) == 2,
					"㉑点第二格后选中态要记**格号** 2，实测 %d" % int(窗21q.get("_selected_inventory_格")))
			var 菜21q := 页21q.get_node_or_null("物品菜单") as Control
			_查(菜21q != null, "㉑单击该弹出物品菜单")
			if 菜21q != null:
				菜21q.emit_signal("选择了", "使用")
				await process_frame
				_查(int(会话._占用条(会话.inventory, 2).get("quantity", 0)) == 2
						and int(会话._占用条(会话.inventory, 1).get("quantity", 0)) == 9,
						"㉑真点第二格后「使用」该吃第二摞，实测格1=%d 格2=%d" % [
							int(会话._占用条(会话.inventory, 1).get("quantity", 0)),
							int(会话._占用条(会话.inventory, 2).get("quantity", 0))])
	窗21q.queue_free()
	await process_frame
	会话.inventory.clear()
	会话.storage.clear()

	# —— ㉒（2026-10-18 巡检 #27）给通灵兽佩戴：这条链以前是**包级损坏**的 ——
	# 病根：**宠物 5 槽的位置是正数 1..5**（`EquipmentPosition.as` 的 PetA..PetE，
	# `脚本/单例/装备部位.gd` 同值），而服务端 `handle_item_move`（`fake_flash_server.py:47534`）只把
	# `destination < 0` 当装备位，**正数一律当背包格号**。旧的
	# `use_inventory_slot` 只看 `是装备(id)` 就把兽铠丢给 `equip_item` ⇒ 在线发的是
	# `request_item_move(0, 格, 1..5, 0)` = **把这一件和背包第 1..5 格对调**
	# （一件没穿上、背包还乱两格），离线则写进 `equipped_items[1..5]`
	# （那本里只该存人物的**负数**槽，宠物件归服务端 CocoPet）。
	# 原版在这里就分叉、永不进 useItem：`onItemDoubleClick:879-882` 与菜单
	# `MENU_CHONGWUPEIDAI:757` 都走 `ItemWindow2.petPutOnEquip:209-219`
	# （绿/紫且可交易先弹 `PEIDAI_BANGDING:2864`）→ `PetHandler.petPutOnEquip`
	# （无附身宠 PROMPT_3 :1895、等级不够 PROMPT_4 :1894，才 `requestPutOnEquip`）。
	# 菜单那一项此前谁也没接 ⇒ 掉进兜底「本轮未实现（独立窗口）」。
	会话.inventory = 会话.落位带洞([_件("2010010", 1, {"slot_index": 1, "req_level": 10}),
			_件("2020010", 1, {"slot_index": 2, "aptitude": 3}),
			_件("03000001", 9, {"slot_index": 3})])
	_查(装备部位.位置("2010010") == 装备部位.宠物一 and 装备部位.是宠物槽(装备部位.位置("2010010")),
			"㉒兽铠 2010010 该落在**宠物一**（正数 1..5），实测 %d" % 装备部位.位置("2010010"))
	# ⚠ 七位 id 的「前四位」取到 201，八位 id 先被**七位前缀 20** 截走 ⇒ 这两个只差一个 0 的
	#   id 走的是**两条完全不同的协议**。判错就是发错包，所以钉在门上而不是靠注释。
	_查(装备部位.位置("20100001") == 装备部位.灵器,
			"㉒八位 20100001（十拳剑）该是灵器、不许被当宠物槽，实测 %d" % 装备部位.位置("20100001"))
	var 通22: Array[String] = []
	var 收22 := func(文: String) -> void: 通22.append(文)
	会话.notification_requested.connect(收22)
	var 包22: Array = 会话.inventory.duplicate(true)
	var 穿22: Dictionary = 会话.equipped_items.duplicate(true)
	_查(not bool(会话.call("use_inventory_slot", 1)),
			"㉒离线点兽铠「使用」要 false（旧写法当场本地穿上、还把那一格清掉）")
	_查(会话.inventory == 包22 and 会话.equipped_items == 穿22,
			"㉒离线给宠物佩戴**一件都不许动**（旧写法清格/对调/写进 equipped_items），实测 %s %s" % [
				str(会话.inventory), str(会话.equipped_items)])
	_查(_正数装备键(会话).is_empty(),
			"㉒`equipped_items` 只该有人物的负数槽，实测多出 %s" % str(_正数装备键(会话)))
	_查(通22 == ["未连接服务器，「给通灵兽佩戴装备」不可用"],
			"㉒离线要说清是「给通灵兽佩戴装备」，实测 %s" % str(通22))
	# 分叉自己的第一道闸（防直调）：非宠物件进来要**静默**拒，不许冒出台词。
	通22.clear()
	_查(not bool(会话.call("equip_pet_item_from_bag", 3)),
			"㉒格 3 是拉面、不是宠物装备 ⇒ 直调也要拒")
	_查(通22.is_empty(), "㉒非宠物装备被拒时不该出声，实测 %s" % str(通22))
	# 空格同样静默 false（不许拿 0 当"格 1"用 —— ㉑ 那条口径）。
	通22.clear()
	_查(not bool(会话.call("equip_pet_item_from_bag", 7)) and 通22.is_empty(),
			"㉒空格（洞）佩戴要静默 false，实测 %s" % str(通22))

	# 端到端：菜单「宠物佩戴」与**双击**都要落到佩戴链上。
	会话.inventory = 会话.落位带洞([_件("2010010", 1, {"slot_index": 1, "req_level": 10})])
	var 窗22 := (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(窗22)
	await process_frame
	窗22.call("open_page", "背包")
	for _i in 5:
		await process_frame
	var 遮22 := 窗22.get("_overlay") as Control
	# ⚠ 每一轮**重新取页面/格子/菜单**：佩戴链一旦真把装备穿上（MUT 反向对照就是这样）就会
	#   `inventory_changed` → `渲染()` 重建整页，手上的节点引用当场作废
	#   （`previously freed` 撞过一次，见 10-18 巡检探针同样的处理）。
	var 点菜单项 := func(项名: String) -> bool:
		var 页W: Control = 窗22.find_child("原版背包内容", true, false) as Control
		var 菜W: Control = null if 页W == null else (页W.get_node_or_null("物品菜单") as Control)
		if 菜W == null:
			return false
		菜W.emit_signal("选择了", 项名)
		return true
	var 点第一格 := func() -> bool:
		var 页X: Control = 窗22.find_child("原版背包内容", true, false) as Control
		var 格X: Button = null if 页X == null else (页X.get_node_or_null("格子滚动/格子容器/物品格_0") as Button)
		if 格X == null:
			return false
		格X.pressed.emit()
		return true
	var 页22 := 窗22.find_child("原版背包内容", true, false) as Control
	if 页22 == null or 遮22 == null:
		_失败.append("㉒端到端：背包页/遮罩没建出来（页=%s 遮罩=%s）" % [str(页22), str(遮22)])
	else:
		# ① 单击 → 菜单里那一项的名字（`CN.as:8254` menuArr[1] 第一档就是宠物佩戴）
		_查(点第一格.call(), "㉒端到端：第一格（物品格_0）没建出来")
		await process_frame
		var 项22: Array = 菜单脚本.取菜单项(会话._占用条(会话.inventory, 1), false)
		_查(项22.has("宠物佩戴"), "㉒兽铠的菜单该有「宠物佩戴」，实测 %s" % str(项22))
		# ② 菜单点「宠物佩戴」⇒ 接到佩戴链（旧写法弹的是「本轮未实现（独立窗口）」）
		通22.clear()
		var 包22b: Array = 会话.inventory.duplicate(true)
		_查(点菜单项.call("宠物佩戴"), "㉒端到端：物品菜单没弹出来，佩戴链的断言做不了")
		await process_frame
		_查(通22 == ["未连接服务器，「给通灵兽佩戴装备」不可用"],
				"㉒菜单「宠物佩戴」该走到佩戴链，实测 %s" % str(通22))
		_查(会话.inventory == 包22b, "㉒菜单那条也不许动背包，实测 %s" % str(会话.inventory))
		# ③ 双击同一格（`onItemDoubleClick:879-882` 的分叉）。两击之间谁先被判成
		#    "单击/双击"取决于 300ms 窗口，但**两条腿都只会出声一次** ⇒ 等式不受时序影响。
		通22.clear()
		for _击 in 2:
			点第一格.call()
			await process_frame
		_查(通22 == ["未连接服务器，「给通灵兽佩戴装备」不可用"],
				"㉒双击兽铠该走佩戴链（旧写法进 useItem ⇒ request_item_move 正数 dst 被服务端当背包格），实测 %s" % str(通22))
		# ④ 绿（资质 3）/紫（4）**且还能交易** ⇒ 先弹 `PEIDAI_BANGDING`，点「确定」才发。
		#    ⚠ 这不是装饰：服务端 `_binds_when_equipped` 用的正是同一判据
		#    （`CocoEquip.APTITUDE_GREEN=3 / APTITUDE_PURPLE=4` + can_trade），
		#    而 `_bind_item_instance` **不可逆**。
		会话.inventory = 会话.落位带洞([_件("2020010", 1,
				{"slot_index": 1, "aptitude": 3, "can_trade": true})])
		窗22.set("_selected_inventory_格", 1)
		通22.clear()
		点菜单项.call("宠物佩戴")
		await process_frame
		var 框22 := 遮22.get_node_or_null("消息确认框") as Control
		_查(框22 != null, "㉒绿/紫可交易的兽铠该先弹绑定确认（`petPutOnEquip:209-219`）")
		_查(通22.is_empty(), "㉒确认框还没点「确定」就发了包，实测 %s" % str(通22))
		if 框22 != null:
			var 文22 := String((框22.get_node("主体/正文") as RichTextLabel).text)
			_查(文22.contains("佩戴后，该装备将与您绑定") and 文22.contains("您希望佩戴该装备吗？")
					and not 文22.contains("<font"),
					"㉒确认正文该是 `PEIDAI_BANGDING:2864` 那两句、且已折成 BBCode，实测 %s" % 文22)
			(框22.get_node("主体/取消") as Button).pressed.emit()
			for _i in 2:
				await process_frame
			_查(通22.is_empty(), "㉒点「取消」不许发（旧写法根本没这框，点一下就穿）")
		# ⑤ 判据的**另一半**各来一次：蓝装（资质 2）与已绑定的紫装都不该弹框、直发。
		for 态 in [[2, true], [4, false]]:
			会话.inventory = 会话.落位带洞([_件("2030010", 1,
					{"slot_index": 1, "aptitude": int(态[0]), "can_trade": bool(态[1])})])
			窗22.set("_selected_inventory_格", 1)
			通22.clear()
			点菜单项.call("宠物佩戴")
			await process_frame
			_查(遮22.get_node_or_null("消息确认框") == null,
					"㉒资质 %d / can_trade=%s 不该弹绑定确认（判据是 aptitude∈{3,4} **且** can_trade）" % [
						int(态[0]), str(bool(态[1]))])
			_查(通22 == ["未连接服务器，「给通灵兽佩戴装备」不可用"],
					"㉒资质 %d / can_trade=%s 该直接发，实测 %s" % [
						int(态[0]), str(bool(态[1])), str(通22)])
		# ⑥ 点「确定」那一路**确实**会发（离线 ⇒ 出声的是 `_离线拒绝`；在线腿见
		#    `测试/宠物真实事务回归测试.gd`，那里才看得到服务端把件穿上、背包格清空）。
		会话.inventory = 会话.落位带洞([_件("2020010", 1, {"slot_index": 1, "aptitude": 3})])
		窗22.set("_selected_inventory_格", 1)
		通22.clear()
		点菜单项.call("宠物佩戴")
		await process_frame
		var 框22b := 遮22.get_node_or_null("消息确认框") as Control
		if 框22b == null:
			_失败.append("㉒第⑥条：绿装的绑定确认框没弹出来")
		else:
			(框22b.get_node("主体/确定") as Button).pressed.emit()
			await process_frame
			_查(通22 == ["未连接服务器，「给通灵兽佩戴装备」不可用"],
					"㉒点「确定」后该发佩戴，实测 %s" % str(通22))
	会话.notification_requested.disconnect(收22)
	窗22.queue_free()
	for _i in 2:
		await process_frame

	# ㉓（2026-10-19 体检报告 #44）底部那一排钮**点下去要给一句真话**，而且这句真话
	#    要钉住：旧写法五颗都弹同一句"本轮未实现（独立窗口）"——开发周期的话烂在包里，
	#    玩家看不出缺的是哪条协议、开发者也看不出缺的是哪一段。
	#    ⚠️ 断的是**点出来之后 `后端状态` 那个 Label 上的字**，不是脚本里的常量：
	#      `_show_hint` 只写 `_status.text`，而这条链以前还漏过 `visible`（见 :4744 注释）。
	#    2026-10-19 §3.222：「神秘商店」那颗已经接上（表里只剩四颗），它改成断
	#    "点下去发的是动作 6、且**不**弹占位话" —— 见本腿末尾。
	#    2026-10-20 §3.223：「随身药店」也接上了（表里只剩**三**颗）。它与「随身仓库」那条
	#    VIP 那三支判式不在这里断，另立一扇 `测试/随身药店仓库回归测试.gd`（要拿真窗口管理才能验"切显隐"）。
	#    ⚠ 2026-10-25 报修 5.1/5.2：原版的等级闸（`CANG_KU_LEVEL`）与「购买VIP确认」弹**整条删了**，
	#    那一扇门里的腿也改成"等级是多少都照发"。
	会话.inventory = 会话.落位带洞([_件("2010010", 1, {"slot_index": 1})])
	var 窗23 := (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(窗23)
	await process_frame
	窗23.call("open_page", "背包")
	for _i in 5:
		await process_frame
	var 页23 := 窗23.find_child("原版背包内容", true, false) as Control
	var 状23 := 窗23.get("_status") as Label
	if 页23 == null or 状23 == null:
		_失败.append("㉓背包页(%s) 或 后端状态 标签(%s) 没建出来" % [str(页23), str(状23)])
	else:
		# 表本身也要钉死：门里**照抄一份字面**，谁把某颗的理由悄悄改回通用话（"未实现"那种），
		# 光靠"点出来的字 == 表里的字"是自洽的、抓不住，必须有这份字面才红得起来。
		# 2026-10-20 §3.226：最后一颗「随身摊位」（摊主侧上架／下架／改名）接上了 ⇒ **表清空**。
		# ⚠️ 空表这条同样要钉死：占位循环改成"照表走"之后，谁把某颗的理由悄悄塞回表里、
		#    或把循环改回硬编码那一列，都得红 —— 这条腿从前钉的是"每颗点名自己缺哪条协议"，
		#    现在钉的是"没有一颗缺"，两头的字面都得在门里留一份。
		var 实表: Dictionary = 背包窗口脚本.缺的那一块
		_查(实表.is_empty(),
				"㉓底部缺口表该是空的（八颗都接上了），实测 %s" % str(实表.keys()))
		# 「随身摊位」那颗（#49 接上）：原版 `ItemWindow2.as:1515-1525 viewStallHandler` 两支 =
		# 自己那扇开着就收（一个包都不发）、否则 `requestStallOpen(stats.id)` = `1296:2:<自己号>`。
		# 这里 窗23 直接挂 root、台上没有窗口管理 ⇒ 命中的是那句兜底，所以本腿只断
		# "**不再弹『还没接』那种占位话**"＋ 状态行仍可见；真开关＋发帧那两条在
		# `测试/随身摊位摊主回归测试.gd` 的 ①（那边有真 窗口管理）。
		var 摊23 := 页23.get_node_or_null("随身摊位") as Button
		if 摊23 == null:
			_失败.append("㉓底部那颗「随身摊位」在场景里没有")
		else:
			状23.text = ""
			摊23.pressed.emit()
			await process_frame
			_查(not 状23.text.contains("还没接"),
					"㉓「随身摊位」已经接上，不该再弹占位话，实测 %s" % 状23.text)
			_查(状23.visible,
					"㉓「随身摊位」弹了话但 后端状态 不可见（写进看不见的标签＝玩家眼里仍是点了没反应）")
			_查(not 状23.text.contains("本轮"),
					"㉓反馈里不许出现开发周期的话，实测 %s" % 状23.text)
		# 「摊位列表」那颗（§3.224 接上）：从缺口表里**摘掉**了 ⇒ 点下去走 `窗口管理.打开或收起`，
		# 原版 `ItemWindow2.as:1547-1557` 那对开关一跳都不发（发 `1296:0:0:11` 的是开窗那一刻，
		# 在 `功能窗口.open_page`）。这里 窗23 直接挂 root、台上没有窗口管理 ⇒ 命中的是那句兜底，
		# 所以本腿只断「**不再弹『还没接』那种占位话**」；真开窗＋发包那一条在
		# `测试/摊位列表窗回归测试.gd` 的 ②（那边有真 窗口管理）。
		var 摊列23 := 页23.get_node_or_null("摊位列表") as Button
		if 摊列23 == null:
			_失败.append("㉓底部那颗「摊位列表」在场景里没有")
		else:
			状23.text = ""
			摊列23.pressed.emit()
			await process_frame
			_查(not 状23.text.contains("还没接"),
					"㉓「摊位列表」已经接上，不该再弹占位话，实测 %s" % 状23.text)
		# 「二级密码」那颗（§3.225 接上）：`ItemWindow2.as:722-729` 全文一句 `queryFirstTime()`
		# ⇒ **点下去只发一跳 2309:0，一扇窗都不开**（开窗的是回帧 2）。这颗台上没有 窗口管理，
		# 所以这里只断「不再弹『还没接』那种占位话」；六扇窗与四种发送出口在
		# `测试/二级密码窗回归测试.gd` 里逐件钉。
		var 密23 := 页23.get_node_or_null("二级密码") as Button
		if 密23 == null:
			_失败.append("㉓底部那颗「二级密码」在场景里没有")
		else:
			状23.text = ""
			密23.pressed.emit()
			await process_frame
			_查(not 状23.text.contains("还没接"),
					"㉓「二级密码」已经接上，不该再弹占位话，实测 %s" % 状23.text)
		# 「神秘商店」那颗（§3.222 接上）：`ItemWindow2.as:1763-1766` 全文一句
		# `MysteryManager.requestOpenMystery()` ⇒ **只发一跳 NPC_SHOP 动作 6，本端绝不开窗**
		# （开窗的是服务端那帧 `324:`，消费者在 `窗口管理._on_mystery_shop`）。
		# 两条都要钉：发错号（发成 7/8 就是买东西/刷新）和"顺手把窗开出来"都会被抓。
		var 秘23 := 页23.get_node_or_null("神秘商店") as Button
		if 秘23 == null:
			_失败.append("㉓底部那颗「神秘商店」在场景里没有")
		else:
			var 假秘 := 假后端.new()
			窗23.set("_backend", 假秘)
			状23.text = ""
			秘23.pressed.emit()
			await process_frame
			_查(假秘.收到 == ["6"],
					"㉓「神秘商店」点下去该只发 NPC_SHOP 动作 6，实测 %s" % str(假秘.收到))
			_查(状23.text == "",
					"㉓「神秘商店」已经接上了，不该再弹占位话，实测 %s" % 状23.text)
			_查(String(窗23.get("_current_page")) == "背包",
					"㉓那颗钮**只发一跳**、开窗等回帧；这里直接把页切走了（当前页=%s）"
							% String(窗23.get("_current_page")))
			# 没连服务端时要给一句话（点了完全没反应＝会被当成坏了）。
			窗23.set("_backend", null)
			状23.text = ""
			秘23.pressed.emit()
			await process_frame
			_查(状23.text == "神秘商店：未连接服务端" and 状23.visible,
					"㉓离线点「神秘商店」该弹「未连接服务端」且标签可见，实测 %s / visible=%s" % [
						状23.text, str(状23.visible)])
			假秘.queue_free()
		# 菜单兜底那支：走到兜底 = 菜单表冒出了**分派表没写**的一项（不是"故意不做"）。
		var 菜23 := 页23.get_node_or_null("物品菜单") as Control
		if 菜23 == null:
			_失败.append("㉓物品菜单没建出来，兜底那支的断言做不了")
		else:
			状23.text = ""
			菜23.emit_signal("选择了", "分派表里没有的一项")
			await process_frame
			_查(状23.text == "分派表里没有的一项：还没接 —— 背包菜单这一项没有分派",
					"㉓菜单兜底该说「这一项没有分派」（以前它弹的是通用「未实现」），实测 %s" % 状23.text)
		# 整页扫一遍：任何**看得见的**文字/悬停里都不该残留「本轮」那种开发周期口径。
		var 脏: Array[String] = []
		var 栈: Array[Node] = [页23]
		while not 栈.is_empty():
			var 节: Node = 栈.pop_back()
			for 子 in 节.get_children():
				栈.append(子)
			if 节 is Label:
				if (节 as Label).text.contains("本轮"):
					脏.append("%s=%s" % [节.name, (节 as Label).text])
			elif 节 is Button:
				if (节 as Button).text.contains("本轮") or (节 as Button).tooltip_text.contains("本轮"):
					脏.append("%s=%s/%s" % [节.name, (节 as Button).text, (节 as Button).tooltip_text])
		_查(脏.is_empty(), "㉓背包页里有控件把开发周期的话摆到了脸上：%s" % str(脏))
	窗23.queue_free()
	for _i in 2:
		await process_frame

	# ---- ㉔ 每页 90 格、9 行一屏全露（用户 2026-10-31 五轮口径）----
	# 口径来源：用户「一行 10 格」+「10 行也可以一屏全露，不用上下滚动」
	#   + 第三轮「格子左右两边空了一格」「边缘框只覆盖 7 行半」「底部四键也不在框中」
	#   + 第四轮「单格高度改小了、图标越过格子下边框」「最下一行还越过下框」
	#   + 第五轮「除了格子数，其他布局不要做改变」。
	# 有意偏离原版（`ItemWindow2.as:1333` 30 格/页、6x5 全露）：格 40x40（34 图标 + 6 描边，
	#   与 `装备格.tscn` 同高）、横距 42 / 纵距 40、起点 (8,4)。版式回第三轮原样：
	#   格区 433x364 与格区底同框（11..444 × 71..435）；364 高只装得下 9 行（4 + 9×40 = 364）
	#   ⇒ 10 列 x 9 行 = 90 格/页，末行下沿 435 = 框下沿。窗口 453x556，货币三行仍在左下。
	#   两条滚动都关 —— 一开 ScrollContainer 就把滚动条宽 19 算进最小尺寸，视口会撑出页面。
	# 门钉五件事：格子数与坐标、容器/视口同大且不滚、窗口尺寸两处同值、分页槽位号、
	#   末尾按真实格位藏尾（合成容量 128 ⇒ 第 2 页只露 38 格、标题仍写 …/128；真档读档即补整页）。
	var 包场景 := load("res://场景/界面/窗口/背包/背包窗口.tscn") as PackedScene
	var 包页 := 包场景.instantiate() as Control
	var 屏24 := 包页.get_node_or_null("格子滚动") as ScrollContainer
	var 容24 := 包页.get_node_or_null("格子滚动/格子容器") as Control
	if 屏24 == null or 容24 == null:
		_失败.append("㉔背包场景里没有 格子滚动/格子容器（90 格版没落进 tscn？）")
	else:
		_查(容24.get_child_count() == 90,
				"㉔格区该有 90 个格子（10 列 x 9 行），实测 %d" % 容24.get_child_count())
		var 末24 := 容24.get_node_or_null("物品格_89") as Button
		_查(末24 != null, "㉔该有 物品格_89（第 90 格）")
		if 末24 != null:
			_查(Vector2i(int(末24.position.x), int(末24.position.y)) == Vector2i(386, 324),
					"㉔物品格_89 该在第 9 行第 10 列 (386,324)（40 格宽/42 距、40 高：8 + 9×42, 4 + 8×40），实测 %s" % str(末24.position))
			_查(Vector2i(int(末24.size.x), int(末24.size.y)) == Vector2i(40, 40),
					"㉔格子该是 40x40（原版 MCell 尺寸，用户第四轮：别把高度改小），实测 %s" % str(末24.size))
			# 用户第四轮第 1 条：34px 图标 + 上下各 3px 才 40；`物品格.png` 的下描边占 6px ⇒
			# 格子高度低于 34 + 6 = 40 时图标会压住自己格子的下边框。
			_查(末24.size.y >= 34.0 + 6.0,
					"㉔格子高度必须容得下 34 图标 + 6px 描边（≥40），实测 %.0f" % 末24.size.y)
			# 与人物面板的装备格同尺寸（用户点名「参考角色人物装备格的高度」）。
			var 装格24 := (load("res://场景/界面/组件/装备格.tscn") as PackedScene).instantiate() as Control
			var 装备格尺 := 装格24.custom_minimum_size
			装格24.free()
			_查(装备格尺 == 末24.size,
					"㉔背包格该与 装备格.tscn 同尺寸（装备格 %s / 背包 %s）" % [
							str(装备格尺), str(末24.size)])
		var 十24 := 容24.get_node_or_null("物品格_9") as Button
		_查(十24 != null and Vector2i(int(十24.position.x), int(十24.position.y)) == Vector2i(386, 4),
				"㉔第 10 格该在第 1 行第 10 列 (386,4)，实测 %s" % (str(十24.position) if 十24 else "缺"))
		var 十一24 := 容24.get_node_or_null("物品格_10") as Button
		_查(十一24 != null and Vector2i(int(十一24.position.x), int(十一24.position.y)) == Vector2i(8, 44),
				"㉔第 11 格该折到第 2 行第 1 列 (8,44)（10 列换行、行距 40 = 格高，行间不留缝），实测 %s" % (
						str(十一24.position) if 十一24 else "缺"))
		_查(屏24.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
				"㉔格区不该横向滚（10 列正好一屏宽），实测 %d" % 屏24.horizontal_scroll_mode)
		_查(屏24.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
				"㉔格区不该纵向滚（用户口径：9 行一屏全露），实测 %d" % 屏24.vertical_scroll_mode)
		_查(Vector2i(int(容24.custom_minimum_size.x), int(容24.custom_minimum_size.y)) == Vector2i(433, 364),
				"㉔容器该是 433x364（8 + 9×42 + 40, 4 + 8×40 + 40），实测 %s —— 只加列/行不改容器，第 10 列会被裁" % (
						str(容24.custom_minimum_size)))
		_查(int(屏24.offset_left) == 11 and int(屏24.offset_right) == 444
				and int(屏24.offset_top) == 71 and int(屏24.offset_bottom) == 435,
				"㉔格区视口该是 11..444 × 71..435（与格区底同框，格子贴内沿），实测 %d..%d × %d..%d" % [
						int(屏24.offset_left), int(屏24.offset_right),
						int(屏24.offset_top), int(屏24.offset_bottom)])
		# 格区底必须**整行包住**最后一行：末行下沿（页坐标）= 视口顶 71 + 末格 y 324 + 40 = 435，
		# 框下沿 435 ⇒ 末行正好压在框内沿上（第三轮起就是这个关系）。
		var 框24 := 包页.get_node_or_null("格区底") as NinePatchRect
		_查(框24 != null and int(框24.offset_top) == 71 and int(框24.offset_bottom) == 435
				and int(框24.offset_left) == 11 and int(框24.offset_right) == 444,
				"㉔格区底该和格区同框 11..444 × 71..435（9 行 360 高 + 上下各 4），实测 %s" % (
						str(框24.get_rect()) if 框24 else "缺"))
		if 框24 != null and 末24 != null:
			var 末行下沿 := float(屏24.offset_top) + 末24.position.y + 末24.size.y
			_查(is_equal_approx(框24.offset_bottom, 末行下沿),
					"㉔末行下沿该正好落在框下沿（框 %.0f / 末行 %.0f），实际差 %.0f —— 越过就是最后一排跨出框"
					% [框24.offset_bottom, 末行下沿, 末行下沿 - 框24.offset_bottom])
		# 窗内底要包住底部四键 + 左下三行货币（用户：「四键也不在框中」）：页面 556 ⇒ 下沿 550（6px 边）。
		var 内24 := 包页.get_node_or_null("内层底") as NinePatchRect
		_查(内24 != null and int(内24.offset_top) == 39 and int(内24.offset_bottom) == 550
				and int(内24.offset_left) == 6 and int(内24.offset_right) == 447,
				"㉔内层底该是 6..447 × 39..550（453x556 页面四周留 6px 边），实测 %s" % (
						str(内24.get_rect()) if 内24 else "缺"))
		if 内24 != null:
			var 底外: Array[String] = []
			for 名 in ["整理背包", "二级密码", "摊位列表", "随身摊位", "随身仓库", "随身药店",
					"神秘商店", "分隔线", "金币底", "元宝底", "点券底", "金币图标", "元宝图标",
					"点券图标", "游戏金币标题", "商城元宝标题", "商城点券标题",
					"游戏金币值", "商城元宝值", "商城点券值"]:
				var 件 := 包页.get_node_or_null(名) as Control
				if 件 == null:
					底外.append("%s(缺)" % 名)
					continue
				var 外 := Rect2(Vector2(件.offset_left, 件.offset_top),
						Vector2(件.offset_right - 件.offset_left, 件.offset_bottom - 件.offset_top))
				if 外.position.x < 内24.offset_left or 外.position.y < 内24.offset_top \
						or 外.end.x > 内24.offset_right or 外.end.y > 内24.offset_bottom:
					底外.append("%s%s" % [名, str(外)])
			_查(底外.is_empty(), "㉔底部这些控件跑到窗内底外面了：%s" % str(底外))
		_查(int(包页.offset_right) == 453 and int(包页.offset_bottom) == 556,
				"㉔背包页根该是 453x556（用户第五轮：除格子数外版式不动），实测 %dx%d" % [
						int(包页.offset_right), int(包页.offset_bottom)])
	包页.queue_free()
	# 窗口尺寸表与 .tscn 根 offsets 必须同值（外框比表、页面比根，两处各钉一遍）。
	var 规格24: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://数据/界面/窗口尺寸.json"))
	var 条24: Dictionary = (规格24 as Dictionary).get("背包", {}) if 规格24 is Dictionary else {}
	_查(int(条24.get("宽", 0)) == 453 and int(条24.get("高", 0)) == 556,
			"㉔窗口尺寸表「背包」该是 453x556，实测 %sx%s" % [str(条24.get("宽")), str(条24.get("高"))])
	# 每页格数常量与回退值必须同值（回退取**恰好一页**，否则第 1 页画不满）。
	var 包脚本24 := load("res://脚本/界面/窗口/背包窗口.gd")
	var 常量24: Dictionary = 包脚本24.get_script_constant_map()
	_查(int(常量24.get("每页格数", 0)) == 90,
			"㉔每页格数该是 90（10 列 x 9 行），实测 %s" % str(常量24.get("每页格数")))
	_查(int(常量24.get("格数回退", 0)) == 90,
			"㉔格数回退该是 90（恰好一页），实测 %s" % str(常量24.get("格数回退")))
	var 需求24 := load("res://脚本/界面/扩容需求.gd")
	_查(int(需求24.每页格数("背包")) == 90 and int(需求24.每页格数("仓库")) == 30,
			"㉔扩容页宽该是 背包 90 / 仓库 30，实测 %d / %d" % [
					int(需求24.每页格数("背包")), int(需求24.每页格数("仓库"))])
	# 分页槽位号：容量 90 ⇒ 第 1 页 1..90；放到 180 ⇒ 第 2 页从 91 起；810 ⇒ 9 页全露。
	var 后端24: Node = root.get_node_or_null("/root/BackendConnection")
	var 旧容量24 := int(后端24.authoritative_bag_capacity) if 后端24 != null else 0
	var 窗24 := (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(窗24)
	await process_frame
	if 后端24 != null:
		后端24.authoritative_bag_capacity = 90
	窗24.call("open_page", "背包")
	for _i in 4:
		await process_frame
	var 页24 := 窗24.find_child("原版背包内容", true, false) as Control
	if 页24 == null:
		_失败.append("㉔背包页没建出来（90 格版）")
	else:
		var 格一24 := 页24.get_node_or_null("格子滚动/格子容器/物品格_0") as Button
		var 格末24 := 页24.get_node_or_null("格子滚动/格子容器/物品格_89") as Button
		_查(格一24 != null and int(格一24.槽位号) == 1,
				"㉔第 1 格槽位号该是 1，实测 %s" % (str(int(格一24.槽位号)) if 格一24 else "缺"))
		_查(格末24 != null and int(格末24.槽位号) == 90,
				"㉔第 90 格槽位号该是 90（页×90+90），实测 %s" % (
						str(int(格末24.槽位号)) if 格末24 else "缺"))
		_查((页24.get_node("分页/第2页") as Button).visible == false,
				"㉔容量 90 时只有 1 页，第 2 个页签不该露出来")
		_查((页24.get_node("分页/扩充") as Button).visible,
				"㉔容量 90 时「扩充」该在（还没满 9 页）")
		# 真窗口里 ScrollContainer 的尺寸 = max(offset, 子最小尺寸 + 滚动条)。
		# 两轴都关 ⇒ 不该加那 19px；格区必须正好 433x364 并整块留在页面里。
		var 屏24b := 页24.get_node_or_null("格子滚动") as ScrollContainer
		if 屏24b == null:
			_失败.append("㉔真窗口里没有 格子滚动")
		else:
			_查(Vector2i(int(屏24b.size.x), int(屏24b.size.y)) == Vector2i(433, 364),
					"㉔真窗口格区该正好 433x364（不滚 ⇒ 不加滚动条宽），实测 %dx%d" % [
							int(屏24b.size.x), int(屏24b.size.y)])
			_查(屏24b.get_global_rect().end.x <= 页24.get_global_rect().end.x
					and 屏24b.get_global_rect().end.y <= 页24.get_global_rect().end.y,
					"㉔格区不该挤出页面：格区右下 (%s, %s) > 页右下 (%s, %s)" % [
							屏24b.get_global_rect().end.x, 屏24b.get_global_rect().end.y,
							页24.get_global_rect().end.x, 页24.get_global_rect().end.y])
		# 扩容窗的物品格 = 原版 `ItemWindowCell`（`EnlargeWindow.as:239`，悬停 `:309-314` 挂
		# MToolTipItem）。2026-11-02 巡检：这格原缺悬停详情（同生命料理/秘笈合成那族）。
		var 扩充钮24 := 页24.get_node_or_null("分页/扩充") as Button
		if 扩充钮24 == null:
			_失败.append("㉔背包页缺「扩充」钮，扩容窗打不开")
		else:
			扩充钮24.pressed.emit()
			await process_frame
			var 扩容24 := 页24.get_node_or_null("扩容窗口") as Control
			var 扩图24 := 扩容24.get_node_or_null("物品格") as Control if 扩容24 != null else null
			var 扩框24 := 页24.get_node_or_null("物品提示框") as Control
			if 扩图24 == null or 扩框24 == null:
				_失败.append("㉔扩容窗物品格/物品提示框缺（悬停详情接不上）")
			else:
				var 扩需求24 := load("res://脚本/界面/扩容需求.gd")
				var 游24 := load("res://脚本/单例/游戏数据.gd")
				var 密卷24 := String(扩需求24.取需求("背包", 1).get("密卷id", ""))
				扩图24.mouse_entered.emit()
				var 扩标题 := (扩框24.get_node("标题") as Label).text
				_查(扩框24.visible and 扩标题 == 游24.item_name(密卷24),
						"㉔悬停扩容密卷格该弹详情（期望「%s」，实测「%s」）" % [
								游24.item_name(密卷24), 扩标题 if 扩框24.visible else "<没弹>"])
				扩图24.mouse_exited.emit()
				_查(not 扩框24.visible, "㉔移开扩容密卷格该收框")
			if 扩容24 != null:
				扩容24.visible = false
			# 格子必须贴在格区框里（用户：「左右两边空了一格」）：九宫格内沿 = 左 11+8、右 444−7，
			# 上下用格区自己的 71..435。期望值是门里写死的字面量，不回读场景常量。
			var 页角 := 页24.get_global_rect().position
			var 首格24 := 页24.get_node_or_null("格子滚动/格子容器/物品格_0") as Control
			var 末格24 := 页24.get_node_or_null("格子滚动/格子容器/物品格_89") as Control
			if 首格24 == null or 末格24 == null:
				_失败.append("㉔真窗口里缺 物品格_0 / 物品格_89")
			else:
				var 首盒 := 首格24.get_global_rect()
				var 末盒 := 末格24.get_global_rect()
				_查(absf(首盒.position.x - 页角.x - 19.0) <= 0.6
						and absf(末盒.end.x - 页角.x - 437.0) <= 0.6,
						"㉔格子该贴格区框内沿（左 19、右 437），实测 左 %.1f 右 %.1f" % [
								首盒.position.x - 页角.x, 末盒.end.x - 页角.x])
				_查(absf(首盒.position.y - 页角.y - 75.0) <= 0.6
						and absf(末盒.end.y - 页角.y - 435.0) <= 0.6,
						"㉔9 行该从 75 铺到 435（格区框 71..435，上留 4 边框、下沿对齐），实测 上 %.1f 下 %.1f" % [
								首盒.position.y - 页角.y, 末盒.end.y - 页角.y])
		if 后端24 != null:
			后端24.authoritative_bag_capacity = 180
		窗24.call("_render_page")
		for _i in 3:
			await process_frame
		页24 = 窗24.find_child("原版背包内容", true, false) as Control
		(页24.get_node("分页/第2页") as Button).pressed.emit()
		await process_frame
		var 格91 := 页24.get_node_or_null("格子滚动/格子容器/物品格_0") as Button
		_查(格91 != null and int(格91.槽位号) == 91,
				"㉔第 2 页第 1 格槽位号该是 91（页×90+1），实测 %s" % (
						str(int(格91.槽位号)) if 格91 else "缺"))
		# 末页只画**真实格位**：这里直接塞一个非整页的 128 来验客户端防御层
		# （真档不会出现——服务端读档就补整页，128 → 180）⇒ 2 个页签，
		# 第 2 页只有槽 91..128 存在，129 起必须隐藏。以前照样画满一格 ⇒ 假空格，
		# 用户看到的就是「占用数/总 跟格子对不上」。
		if 后端24 != null:
			后端24.authoritative_bag_capacity = 128
		窗24.call("_render_page")
		for _i in 3:
			await process_frame
		页24 = 窗24.find_child("原版背包内容", true, false) as Control
		var 页签露 := 0
		for _i in 9:
			if (页24.get_node("分页/第%d页" % (_i + 1)) as Button).visible:
				页签露 += 1
		_查(页签露 == 2, "㉔容量 128（ceil(128/90)=2）该露 2 个页签，实测 %d" % 页签露)
		(页24.get_node("分页/第2页") as Button).pressed.emit()
		await process_frame
		var 格128甲 := 页24.get_node_or_null("格子滚动/格子容器/物品格_37") as Button
		var 格128乙 := 页24.get_node_or_null("格子滚动/格子容器/物品格_38") as Button
		var 格128末 := 页24.get_node_or_null("格子滚动/格子容器/物品格_89") as Button
		_查(格128甲 != null and 格128甲.visible,
				"㉔容量 128 的第 2 页，第 38 格（槽 128）该露")
		_查(格128乙 != null and not 格128乙.visible,
				"㉔容量 128 的第 2 页，槽 129 不存在 ⇒ 第 39 格必须隐藏（不然就是假空格）")
		_查(格128末 != null and not 格128末.visible,
				"㉔容量 128 的第 2 页，第 90 格（槽 180）必须隐藏")
		# 标题「已用/总」：总写**客户端收到的容量原值** 128，不做第二次取整
		# （取整是服务端读档的职责，客户端只管如实显示）；
		# 已用 = 背包里非空条数（独立数一遍，不回读 `_占用数`）。
		var 标题128 := (窗24.get("_title") as Label)
		var 尾128 := (窗24.get("_title_数值") as Label)
		var 标题文128 := ""
		if 标题128 != null:
			标题文128 += 标题128.text
		if 尾128 != null and 尾128.visible:
			标题文128 += 尾128.text
		_查(标题文128.ends_with("/128)"),
				"㉔容量 128 时标题该以「(已用/128)」收尾，实测 %s" % 标题文128)
		var 会话24 := root.get_node_or_null("/root/GameSession")
		var 非空条 := 0
		if 会话24 != null:
			for 条 in 会话24.inventory:
				if not (条 as Dictionary).is_empty():
					非空条 += 1
		var 左括 := 标题文128.find("(")
		var 斜杠 := 标题文128.find("/")
		_查(左括 >= 0 and 斜杠 > 左括
				and int(标题文128.substr(左括 + 1, 斜杠 - 左括 - 1)) == 非空条,
				"㉔标题「已用」该是背包非空条数 %d，实测 %s" % [非空条, 标题文128])
		# 回第 1 页：90 格必须全部重新露出来（尾巴格的隐藏只能作用于越界那一页）。
		(页24.get_node("分页/第1页") as Button).pressed.emit()
		await process_frame
		var 格回24 := 页24.get_node_or_null("格子滚动/格子容器/物品格_89") as Button
		_查(格回24 != null and 格回24.visible,
				"㉔翻回第 1 页后 90 个格子该全露（隐藏不能粘在节点上），实测 %s"
				% ("缺格" if 格回24 == null else str(格回24.visible)))
		if 后端24 != null:
			后端24.authoritative_bag_capacity = 810
		窗24.call("_render_page")
		for _i in 3:
			await process_frame
		页24 = 窗24.find_child("原版背包内容", true, false) as Control
		var 全露24 := true
		for _i in 9:
			全露24 = 全露24 and (页24.get_node("分页/第%d页" % (_i + 1)) as Button).visible
		_查(全露24, "㉔容量 810（9×90）时 9 个页签该全露")
		_查(not (页24.get_node("分页/扩充") as Button).visible,
				"㉔9 页满了「扩充」该藏起来")
	窗24.queue_free()
	if 后端24 != null:
		后端24.authoritative_bag_capacity = 旧容量24
	for _i in 2:
		await process_frame

	_收尾()
	if _失败.is_empty():
		print("背包道具回归测试：通过（%d 条断言）" % _受检)
		quit(0)
		return
	for 项 in _失败:
		printerr("背包道具回归测试：" + 项)
	quit(1)

func _背包件数(会话, 物品id: String) -> int:
	var 总 := 0
	for 条 in 会话.inventory:
		if String((条 as Dictionary).get("id", "")) == 物品id:
			总 += int((条 as Dictionary).get("quantity", 1))
	return 总

## ㉑ 存/取那两条要按**仓库**数件数（上面那条只扫背包）。
func _仓库件数(会话, 物品id: String) -> int:
	var 总 := 0
	for 条 in 会话.storage:
		if String((条 as Dictionary).get("id", "")) == 物品id:
			总 += int((条 as Dictionary).get("quantity", 1))
	return 总

## ㉒ `equipped_items` 里的**正数**键。人物的槽全是负数（`EquipA..EquipL` = -1..-12，
## 勾玉/变身/徽章/灵器/忍具/羁绊/神器同理），只有**宠物那 5 槽是正数 1..5**，
## 而那 5 槽存在服务端 `CocoPet` 上、不在人物这本账里 ⇒ 这里冒出正数键就是走错了包。
func _正数装备键(会话) -> Array:
	var 出: Array = []
	for 键 in 会话.equipped_items:
		if int(键) > 0:
			出.append(键)
	return 出

func _收尾() -> void:
	if not _快照.is_empty():
		var 会话 := root.get_node("/root/GameSession")
		会话.player_stats = _快照["player_stats"]
		# ⚠️ `inventory`/`storage` 都是 `Array[Dictionary]` ⇒ 直接赋普通 Array 会
		#    Invalid assignment 报错但不中断（§3.196 同型坑），走 `assign`。
		(会话.inventory as Array).assign(_快照["inventory"] as Array)
		(会话.storage as Array).assign(_快照["storage"] as Array)
		会话.equipped_items = _快照["equipped_items"]
		会话.call("_save_local_state")
	# 文件级还原放在最后：`_save_local_state()` 重写的字节与原档不必一致。
	门存档快照.全还原(_文件前)
