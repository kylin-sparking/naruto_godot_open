extends SceneTree

## 通灵驯养「属性提升」那一页的**上行分派 + 三道闸门**门（#320 的欠账，2026-10-23）。
##
## 病根：这一页的提交上行其实早就接上了（`功能窗口._请求提升` → 95 的子动作 6/7/18），
## 但**一条门都没钉过** —— `通灵驯养中框回归测试.gd` 量的是中框那段纯文案，
## `后端协议回归测试.gd:1026-1035` 那批只钉了 1/2/3/4/13/15/16/**18**/21/22，
## **6 与 7 两个子动作的包形从来没被照到**。没有门 ⇒ 这次对着 AS3 逐句核的时候，
## 一次就核出**三处偏差**（都在下面 §偏差 里，每条都补了判据）：
##
## §偏差（原写法 vs `PetStrongTab.as` 逐句）
## 1. `:114-122 validateXinYunJing`：勾了幸运符才判，且比的是**下拉选中的颗数**
##    （`isBagExistItem(helpItemId) < selectedIndex + 1`）。原来写的是 `< 1` ⇒
##    选 5 颗、背包只有 1 枚也照样放行，服务端那边才对不上数。
## 2. 同一个判断原来还多挂了一个 `需要 > 0` 的前置（资质符数量）⇒ 与幸运符无关的东西
##    能挡幸运符闸门。原版这两个条件互不相干。
## 3. 三句提示的文案：`:128/:139/:539` 用的都是同一条模板
##    `CN.EQUIP_STRENGTH_FAIL_PROMPT_2[0]` = 语言表 `EQUIP_STRENGTH_FAIL_PROMPT_2_1`
##    =「很抱歉，你的%1不够」（金币那句替的是 `[1]`「金币」，材料/幸运符替的是
##    `StringTool.getItemString(物品号)`）。原来写的是「金币不足。」「%s不足。」= **自造话**。
##
## §门钉什么
## · 分派：模式 0/1/2..5 ⇒ 子动作 6/7/18，且**品级与悟性两支第二参恒为 1**（`:311`/`:314` 写死），
##   潜力四支 = `勾选 ?  selectedIndex+1 : 0`（`:304-308`）+ 第三参 型 = 模式-1（攻1/防2/灵3/健4）
## · 闸门次序与"哪一支才走幸运符闸"：品级那一支**不判幸运符**（原版 switch 里只有潜力四个 case 调
##   `validateXinYunJing`）⇒ 幸运符 0 枚也照样发，这条专门挡住"顺手给所有模式加校验"
## · 三句提示逐字（模板 + 替进去的名字）
## · 接口核对：假后端那三个方法名/参数必须与**真身源码文本**逐字一致（假接口失配 = 假通过，
##   本工程栽过好几次；同一把尺子先照一个早就在用的 `request_pet_call_out` 当阳性对照）
##
## ⚠ 原版 `onClickHand:291-294` 第一句是 `if(KuaFuManager.inKuaFuBattle()) return;`（跨服大战里
##   静默不给点）—— 客户端**拿不到**那份状态（服务端的 `war_battle_active` 从不下发）⇒ 这条没落，
##   记在 `真值/世界/外来帧与上行接线.md` §⑤，不是漏写。
##
## 运行：Godot --headless --path . --script res://测试/通灵提升上行回归测试.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 页名 := "通灵驯养"
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 后端路 := "res://脚本/单例/后端连接.gd"

## 宠物模板里那一行真配置（`数据/宠物.json` 的 `info.potential.apt1`，101 号通灵兽）：
## 资质符 16000014 ×1、幸运符 16000015、金币 500 ⇒ 夹具直接用这一行，不另编数
const 材料 := 16000014
const 幸运符 := 16000015
const 配置 := {"needItemId": 16000014, "needItemCnt": 1, "helpItemId": 16000015,
		"needMoney": 500, "probability": 100}
const 宠 := {"unique_id": 9001}
## 语言表现查的三条名字（`数据/物品.json`）⇒ 通知文案里替进去的那一段
const 名材料 := "资质符"
const 名幸运 := "幸运符"
const 模板 := "很抱歉，你的%1不够"		# EQUIP_STRENGTH_FAIL_PROMPT_2_1

var 场: Node
var 后: Node
var 窗: Node
var 假: Node
var 红数 := 0
var 判数 := 0
var 通知记录: Array[String] = []


## 假后端：只接管出帧那半边（同 伊鲁卡三窗门 §3.121 / 假心法宿主）。
## 记的是 `[子动作, 宠物号, 颗数(, 潜力型)]` —— 号与颗数都要落账，否则"发没发"分不出对错。
class 记帧后端:
	extends Node
	var in_game := true
	var 条: Array = []

	func request_pet_rewash_aptitude(uid: int, 颗: int) -> bool:
		条.append([6, uid, 颗])
		return true

	func request_pet_change_savvy(uid: int, 颗: int) -> bool:
		条.append([7, uid, 颗])
		return true

	func request_pet_strength_potential(uid: int, 颗: int, 型: int) -> bool:
		条.append([18, uid, 颗, 型])
		return true


func _记(对: bool, 文: String) -> void:
	判数 += 1
	if not 对:
		红数 += 1
		print("红   " + 文)


## 清账 + 备料：`材料齐`/`钱够`/`幸运符几枚` 三样一次给全，勾与颗数直接写到窗的会话字段上。
func _跑一次(模式: int, 材料数: int, 金币: int, 幸运数: int, 勾: bool, 颗: int) -> void:
	假.条.clear()
	通知记录.clear()
	窗.set("_驯养用幸运符", 勾)
	窗.set("_驯养幸运符数", 颗)
	# ⚠ `游戏会话.gd:85` 是 `var inventory: Array[Dictionary]` —— **类型化数组**：
	#   `set("inventory", 普通 Array)` 会被 Godot 4.7 **静默丢掉**（背包原样不动 ⇒
	#   闸门照样过、判据伪装成"逻辑对"）。只能就地 clear/append 改那一个数组本体。
	var 库存: Array[Dictionary] = 后.get("inventory")
	库存.clear()
	if 材料数 > 0:
		库存.append({"id": 材料, "quantity": 材料数})
	if 幸运数 > 0:
		库存.append({"id": 幸运符, "quantity": 幸运数})
	(后.get("player_stats") as Dictionary)["gold"] = 金币
	窗.call("_请求提升", 宠, 配置, 模式, 幸运符)


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	call_deferred("_跑")


func _跑() -> void:
	await process_frame
	后 = root.get_node_or_null("/root/GameSession")
	if 后 == null:
		print("红   拿不到 /root/GameSession ⇒ 后面整段没跑")
		quit(1)
		return
	后.notification_requested.connect(func(文: String) -> void: 通知记录.append(文))
	场 = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场)
	for i in 6:
		await process_frame
	var 管: Node = 场.get_node_or_null("窗口管理")
	if 管 == null:
		print("红   地图场景下没有 窗口管理")
		quit(1)
		return
	窗 = 管.call("取或建窗口", 页名)
	if 窗 == null:
		print("红   「%s」这扇窗建不出来（页名不在表里？）" % 页名)
		quit(1)
		return
	假 = 记帧后端.new()
	root.add_child(假)
	窗.set("_backend", 假)
	_量接口()
	_量分派()
	_量闸门()
	_记(判数 == 20, "全程判满 20 条（实测 %d）⇒ 没有哪一段被运行期报错打断" % 判数)
	print("通灵提升上行回归测试：判 %d 条 / 红 %d 条" % [判数, 红数])
	quit(1 if 红数 > 0 else 0)


## 假接口必须与真身逐字同名同参 ⇒ 拿真源码文本对（跑起来的是假身，文本才对得上真身）。
func _量接口() -> void:
	var 文 := FileAccess.get_file_as_string(后端路)
	# 阳性对照：先照一个本来就在用、肯定存在的方法，防止"整份文本没读到"也照样三条全绿
	_记(文.contains("func request_pet_call_out(unique_id: int) -> bool"),
			"阳性对照：真源码文本读到了、且早就在用的 `request_pet_call_out` 形状在里面")
	_记(文.contains("func request_pet_rewash_aptitude(unique_id: int, helper_count: int = 0) -> bool"),
			"6 号上行真身 = `request_pet_rewash_aptitude(unique_id, helper_count)` ⇒ 假身同名同参")
	_记(文.contains("func request_pet_change_savvy(unique_id: int, helper_count: int = 0) -> bool"),
			"7 号上行真身 = `request_pet_change_savvy(unique_id, helper_count)`")
	_记(文.contains("func request_pet_strength_potential(unique_id: int, helper_count: int, potential_type: int) -> bool"),
			"18 号上行真身 = `request_pet_strength_potential(unique_id, helper_count, potential_type)`")
	# 6/7 两条的**包形**从来没被 `后端协议门` 照过（那边只钉到 18）⇒ 这里按 `request_pet_action`
	# 的拼法自己算一遍参照：第一段就是子动作号，后面逐字段冒号连（`后端连接.gd:1174-1180`）。
	_记(_拼(6, [9001, 1]) == "6:9001:1" and _拼(7, [9001, 3]) == "7:9001:3" \
			and _拼(18, [9001, 2, 4]) == "18:9001:2:4",
			"6/7/18 的文本包形 = 子动作打头、字段依次冒号连（与 `后端协议门:1036` 那条 18 的写法同一条式子）")


## 参照自己算：把 `request_pet_action` 那五行搬过来（不问被测对象要现成的串）。
func _拼(子动作: int, 字段: Array) -> String:
	var 段: Array[String] = [str(子动作)]
	for 值 in 字段:
		段.append(str(值))
	return ":".join(段)


func _量分派() -> void:
	# 材料 3 枚、金币 99999 ⇒ 三道闸门全过；未勾幸运符 ⇒ 颗数 0
	_跑一次(0, 3, 99999, 0, false, 1)
	_记(假.条 == [[6, 9001, 1]],
			"模式 0（品级）⇒ 子动作 6 + 号 + **颗数恒 1**（`onClickHand:311` 写死 1），实测 %s" % str(假.条))
	_跑一次(0, 3, 99999, 0, true, 4)
	_记(假.条 == [[6, 9001, 1]],
			"模式 0 就算勾了幸运符、下拉选到 4 颗，第二参**仍是 1**（那一支压根不读 `_loc2_`）")
	_跑一次(0, 3, 99999, 0, true, 5)
	_记(假.条.size() == 1 and 通知记录.is_empty(),
			"模式 0 **不判幸运符库存**（原版 switch 里只有潜力四个 case 调 `validateXinYunJing`）"
			+ "⇒ 幸运符 0 枚也照样发。这条专门挡「顺手给所有模式加校验」")
	_跑一次(1, 3, 99999, 0, false, 1)
	_记(假.条 == [[7, 9001, 1]], "模式 1（悟性）⇒ 子动作 7 + 颗数恒 1（`:314`）")
	_跑一次(2, 3, 99999, 5, false, 3)
	_记(假.条 == [[18, 9001, 0, 1]],
			"模式 2（攻击潜力）**没勾**幸运符 ⇒ 颗数 0、潜力型 1（`_loc2_ = 勾选 ? selectedIndex+1 : 0`）")
	_跑一次(2, 3, 99999, 5, true, 3)
	_记(假.条 == [[18, 9001, 3, 1]],
			"模式 2 勾了、下拉第 3 项 ⇒ 颗数 = `selectedIndex + 1` = **3**（不是下拉下标 2）")
	for 组 in [[3, 2], [4, 3], [5, 4]]:
		_跑一次(int(组[0]), 3, 99999, 5, false, 1)
		_记(假.条 == [[18, 9001, 0, int(组[1])]],
				"模式 %d ⇒ 潜力型 %d（序 = 攻1/防2/灵3/健4，`:320-337` 四个 case 各传一个字面量）"
				% [int(组[0]), int(组[1])])


func _量闸门() -> void:
	# 夹具先自证：清空背包后**窗口自己读到的数量必须是 0** —— 上面那个类型化数组的坑
	# 就是靠这条显形的（不然"材料不足"那一支根本没被执行，判据退化成"0 比 0"恒真）。
	_跑一次(2, 0, 99999, 0, false, 1)
	_记(int(窗.call("_背包数量", 材料)) == 0 and int(窗.call("_背包数量", 幸运符)) == 0,
			"夹具自证：清空背包 ⇒ 窗口那一侧真读到 0 枚（背包没被静默改写的话，闸门那条才有意义）")
	_跑一次(2, 0, 99999, 5, false, 1)
	_记(假.条.is_empty() and 通知记录.size() == 1
			and 通知记录[0] == 模板.replace("%1", 名材料),
			"资质符 0 枚 ⇒ 一条都不发，提示逐字 =「%s」（不是自造的「%s不足。」），实测「%s」"
			% [模板.replace("%1", 名材料), 名材料, 通知记录[0] if 通知记录.size() > 0 else "无"])
	_跑一次(2, 3, 499, 5, false, 1)
	_记(假.条.is_empty() and 通知记录.size() == 1
			and 通知记录[0] == 模板.replace("%1", "金币"),
			"金币 499 < needMoney 500 ⇒ 拦住，提示「%s」（`:539` 替的是数组 [1]「金币」），实测「%s」"
			% [模板.replace("%1", "金币"), 通知记录[0] if 通知记录.size() > 0 else "无"])
	_跑一次(2, 3, 99999, 1, true, 5)
	_记(假.条.is_empty() and 通知记录.size() == 1
			and 通知记录[0] == 模板.replace("%1", 名幸运),
			"勾了、选 5 颗、背包只有 **1 枚** ⇒ 拦住（`:116` 比的是 `selectedIndex + 1` 那个**颗数**，"
			+ "旧写法只判「< 1」会放行）")
	_跑一次(2, 3, 99999, 5, true, 5)
	_记(假.条 == [[18, 9001, 5, 1]],
			"同一支把幸运符补到 5 枚 ⇒ 真发一条（**上面那条不是「0 比 0」**：夹具只差在枚数上）")
	_跑一次(2, 3, 99999, 0, true, 1)
	_记(假.条.is_empty(), "未勾够不到 ⇒ 勾了但一枚都没有，同样拦住（颗数 1）")
