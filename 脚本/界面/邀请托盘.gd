extends Control
## 邀请托盘 = 原版 `CuePane`（盒子）+ `CueManage`（排队/去重/上限）+ `CueGird`（一格）三合一。
## 逐件出处见 `真值/窗口/交易与邀请托盘.md` §⑧。**只接待发的三类**：交易邀请(3)、
## 推荐徒弟(9)、推荐师傅(10)；其余类型服务端查无对应帧，一律没做（不许自造数据）。
##
## 三条最容易写歪的：
## 1. 格是**从中间往左长**的：首格 x = (800−40)>>1 = 380，每来一格 `下一x −= 40`（`CueManage.as:63-64`）。
## 2. 格的 `流水号` 是全局自增的**序号**（`CueGird.as:58,84-85`），不是玩家号；
##    删一格时把**序号更大**（= 更新、在左边）的那些整体右移 40（`:78-88`）。
## 3. 去重按 `(类型, 数据.id)`，且**只有 `checkExist` 的 switch 里列到的类型才去重**（`:92-150`）——
##    师徒两枚不在那张表里 ⇒ 同一个师父推荐两次会出现两格，这是原样行为，不是漏做。

signal 已点(类型: int, 数据: Dictionary)

const 格脚本 := preload("res://脚本/界面/邀请格.gd")
const 文字提示场景 := preload("res://场景/界面/组件/文字提示框.tscn")
const 提示节点名 := "托盘提示框"

## 类型号照 `CueGird.as:26-56`（那张表是 **数组下标 = 类型号**，不是连续的：
## 0 好友申请 / 1 组队邀请 / 2 组队申请 / 3 交易邀请 / 4 双修邀请 / 5 家族邀请 / 6 家族申请 /
## 7 装备修复 / 8 羁绊申请 / 9 推荐徒弟 / 10 推荐师傅 / 11 战报 / 12 中忍竞技大赛 /
## 13 寄售消息 / 14 家族求救 / 15 收到鲜花 —— tooltip 全部 `原版数据.语言(键)` 现查）。
## 这里只登记**本机服务端发得出帧**的几类；11/12/13/14/7 服务端查无对应帧 ⇒ 不做（不自造数据）。
const 类型好友申请 := 0
const 类型组队邀请 := 1
const 类型组队申请 := 2	## `CueGird.as:38` TYPE_TEAM_APPLY；图标与邀请**同一张**（`:188-190`）
const 类型交易 := 3
const 类型家族邀请 := 5
const 类型家族申请 := 6	## `CueGird.as:42` TYPE_FAMILY_APPLY；图标与家族邀请**同一张**（原版 `:188-190` 同款）
const 类型求婚申请 := 8
const 类型推荐徒弟 := 9
const 类型推荐师傅 := 10
const 类型收到鲜花 := 15
## 竞技场战报 = `CueGird.as:48 TYPE_ZHANBAO:int = 11`（数组下标 = 类型号那张表）。
const 类型战报 := 11

const 格宽 := 40.0				# `GRID_WIDTH` / `GRID_CLICK_SIZE`
const 托盘宽 := 800.0			# `CuePane.as:35` drawRect(0,0,800,50)
const 托盘高 := 50.0
const 首格x := 380.0			# `(GRID_PANE_WIDTH - GRID_WIDTH) >> 1`
const 起始x := 10.0				# `addMsg` 里入场前的 `_loc3_.x = 10`
const 上限格数 := 10			# `getDicLength() < 10`
const 入场秒 := 2.0				# `TweenLite.to(_, 2, ...)`

## 图标 = 原版那几个**单独的小 SWF**里的一个符号，全部现导（`开发工具/导出原版符号.ps1` 同源的路子：
## `swf/UISwf/UISwf_FriendIcon.swf → UISwf_FriendIcon_GridFriendInvite` 等），**天然尺寸都是 46×46**，
## 与已经验收过的 `托盘_交易邀请.png` 同一档 ⇒ 不缩放、不重画。
## tooltip = `CUE_GRID_TYPE_NAMES[类型]`，中文全部 `开发工具/原版数据.语言(键)` 现查（不是我自己起的名字）。
const 图标表 := {
	类型好友申请: "res://素材/界面/原版窗口/通用控件/托盘_好友申请.png",
	类型组队邀请: "res://素材/界面/原版窗口/通用控件/托盘_组队邀请.png",
	类型组队申请: "res://素材/界面/原版窗口/通用控件/托盘_组队邀请.png",
	类型交易: "res://素材/界面/原版窗口/通用控件/托盘_交易邀请.png",
	类型家族邀请: "res://素材/界面/原版窗口/通用控件/托盘_家族邀请.png",
	类型家族申请: "res://素材/界面/原版窗口/通用控件/托盘_家族邀请.png",
	类型求婚申请: "res://素材/界面/原版窗口/通用控件/托盘_求婚.png",
	类型推荐徒弟: "res://素材/界面/原版窗口/通用控件/托盘_师徒推荐.png",
	类型推荐师傅: "res://素材/界面/原版窗口/通用控件/托盘_师徒推荐.png",
	类型收到鲜花: "res://素材/界面/原版窗口/通用控件/托盘_鲜花.png",
	## 图标名 = `CueGird.as:175-177`（`TYPE_ZHANBAO` ⇒ `UISwf_PvpZhanBao_Icon`，ffdec 实测 46×46）
	类型战报: "res://素材/界面/原版窗口/竞技场/UISwf_PvpZhanBao_Icon.png",
}
const 提示表 := {
	类型好友申请: "好友申请",
	类型组队邀请: "组队邀请",
	类型组队申请: "组队申请",
	类型交易: "交易邀请",
	类型家族邀请: "家族邀请",
	类型家族申请: "家族申请",
	类型求婚申请: "羁绊申请",
	类型推荐徒弟: "推荐徒弟",
	类型推荐师傅: "推荐师傅",
	类型收到鲜花: "收到鲜花",
	## tooltip = `CUE_GRID_TYPE_NAMES[11]` = `LangUtil.get("PVP_ZHANBAO_TITLE")` = 「战报」
	## （那张表在 `CueGird.as:24`，第 12 项就是它 ⇒ 不是我起的名）
	类型战报: "战报",
}
## 去重键 = 原版 `CueManage.checkExist:97-154` 那个 switch：
## 只有列进去的类型才去重，而且**比的字段各不相同**（好友/交易 = `id`、组队邀请 = `troopId`、
## 家族邀请 = `charId`）；没列进去的（师徒两枚、求婚、鲜花）同一个来两次就是两格 ⇒ 那是原样行为。
## ⚠ 键名也必须照原版：本工程别处数据里角色号常叫 `character_id`，
## 这里若按它比就永远比不中 ⇒ 同一个邀请连来两次会叠两格（原版只一格）。
## ⇒ 塞消息那侧要把数据凑成原版这三个键名之一。
const 去重键 := {
	类型好友申请: "id",
	类型交易: "id",
	类型组队邀请: "troopId",
	类型组队申请: "partyCharId",
	类型家族邀请: "charId",
	## 入族申请按**申请人角色号**去重（`CueManage.checkExist` 家族申请那一支）
	类型家族申请: "charId",
}

var _格们: Dictionary = {}			# 流水号 → 邀请格
var _下一x := 首格x
var _流水 := 0


func _ready() -> void:
	size = Vector2(托盘宽, 托盘高)
	custom_minimum_size = size
	# `CuePane.mouseEnabled = false`（`CuePane.as:38`）⇒ 盒子本身不吃鼠标，只有格吃
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 现在挂着几格（= 原版 `getDicLength()`）。
func 数量() -> int:
	return _格们.size()


## 挂着的那几格（流水号 → 格）。给量具与别的 HUD 件读，不改状态。
func 格们() -> Dictionary:
	return _格们


## 最后加进来的那一格（没有 ⇒ null）。原版没有这个访问口，是给门用的只读便利。
func 最后一格() -> Control:
	var 最大 := -1
	for 号 in _格们:
		最大 = maxi(最大, 号)
	return (_格们[最大] as Control) if 最大 >= 0 else null


## 把挂着的全收掉。**只给量具与换图清场用** —— 原版没有这一步（它跟着 `UIMain2` 活一辈子）。
func 清空() -> void:
	for 号 in _格们.keys():
		删消息(号)


## 加一格。重复（同类同 id）或已经满 10 格 ⇒ **返回 null 且什么都不加**（`CueManage.as:48-66`）。
## 组队邀请 / 入队申请那一格（原版 `CueManage.addMsg(TYPE_TEAM_INVITE/TYPE_TEAM_APPLY, …)`）。
## ⚠ 类型常量**必须在脚本内部取**：外部用 `盘.get("类型组队邀请")` 读不到 ——
##   `Object.get()` 只认属性，**不认脚本常量**，会回 null，`int(null)` 当场把整条调用打断
##   （实机症状 = 对面永远收不到邀请：既没托盘格也没弹窗）。2026-10-25 实测踩到。
func 加队伍邀请(是申请: bool, 数据: Dictionary) -> Control:
	return 加消息(类型组队申请 if 是申请 else 类型组队邀请, 数据)


func 加消息(类型: int, 数据: Dictionary) -> Control:
	if not 图标表.has(类型):
		return null
	if 数量() >= 上限格数:
		return null
	if _已存在(类型, 数据):
		return null
	var 格 := 格脚本.new(类型, _流水, 数据, String(图标表[类型]), String(提示表.get(类型, "")))
	_流水 += 1
	格.position = Vector2(起始x, 0.0)
	格.modulate.a = 0.0
	add_child(格)
	# `TweenLite.to(_loc3_, 2, {alpha:1, x:nextX})` —— 默认缓动 power1.out ⇒ Godot 的 QUAD+EASE_OUT
	var 补间 := create_tween().set_parallel(true)
	补间.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	补间.tween_property(格, "modulate:a", 1.0, 入场秒)
	补间.tween_property(格, "position:x", _下一x, 入场秒)
	_下一x -= 格宽
	_格们[格.流水号] = 格
	格.被点击.connect(_于被点)
	格.悬停.connect(_于悬停)
	return 格


## 删一格：序号比它大的（更新的那些）整体右移 40 补位，然后 `下一x` 回退一格
## （`CueManage.as:68-91` —— 满表时它把 `下一x` **复位成 380**，这条也算原样行为）。
func 删消息(流水号: int) -> void:
	if _格们.has(流水号):
		var 格 := _格们[流水号] as Control
		_格们.erase(流水号)
		if is_instance_valid(格):
			格.queue_free()
	for 号 in _格们.keys():
		if 号 > 流水号:
			var 邻 = _格们[号]
			if not is_instance_valid(邻):
				continue
			var 补间 := create_tween()
			补间.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			补间.tween_property(邻, "position:x", 邻.position.x + 格宽, 入场秒)
	if _格们.is_empty():
		_下一x = 首格x
	else:
		_下一x += 格宽


## 原版 `checkExist`：**只有 `去重键` 里列到的类型才去重**，比的是那一个字段。
## 没列到的（师徒两枚 / 求婚 / 收到鲜花）原版就是不去重 ⇒ 来两次两格，照做、不"顺手修好"。
func _已存在(类型: int, 数据: Dictionary) -> bool:
	var 键 := String(去重键.get(类型, ""))
	if 键.is_empty() or not 数据.has(键):
		return false
	for 号 in _格们:
		var 格 = _格们[号]
		if not is_instance_valid(格):
			continue
		if 格.类型 == 类型 and str(格.数据.get(键, "")) == str(数据[键]):
			return true
	return false


## 点了格 ⇒ 先按类型往外报，再自删（`CueGird.onClickHand:345-351` 的顺序：
## 派发事件 → `destroy()` → `CueManage.delMsg(id)`）。
func _于被点(类型: int, 流水号: int, 数据: Dictionary) -> void:
	已点.emit(类型, 数据)
	删消息(流水号)


func _于悬停(类型: int, 显: bool) -> void:
	var 框 := get_node_or_null(提示节点名) as Control
	if 框 == null:
		if not 显:
			return
		框 = 文字提示场景.instantiate() as Control
		框.name = 提示节点名
		框.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(框)
	框.设置(String(提示表.get(类型, "")))
	框.visible = 显
