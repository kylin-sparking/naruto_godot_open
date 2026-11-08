extends RefCounted

## 禁寻路地图（原版 `Map.nowInNotFindPathMap`，`Map.as:142`）。
##
## 原版的数据源是 `StringTool.getNoPathFindMaps()`（`StringTool.as:397`）⇒
## `Pvp/open` 那张表的 `rawAttributeMaps`。那张表本工程没导；现有数据里能定位这一族的
## 锚点是 `原版杂项.json` 的 `FuBen`：**`type == 9`** 那一档正好是迷路森林的两口
## （`FuBen` 7 号：406010000 迷路森林 / 406010001 森林出口）。
##
## 这一类图里原版换了一整套移动控制器 —— `PlayerController.tick()`（`PlayerController.as:295-309`）
## 判 `nowInNotFindPathMap` 就改走 `tickInJingSuMaps()`，于是：
##   · 左右键**不再转向**，撞墙才掉头，其余时间一直朝当前朝向自己走（`:67-85`）；
##   · 没有点地走 / 自动寻路（`KeyController.pathFind` 直接给 `NOT_PATH_FIND` 提示，`:934-941`）；
##   · 踩到地图上的箭头/火箭道具按 `onTouchItem()`（`:250-290`）给一套固定速度；
##   · 打坐/双修请求被 `Client.as:4340/7921` 挡掉，`HealHandler.healStateChange():349-353` 也会把
##     `nowInHeal` 直接清掉；
##   · 金锄副本（406010000）里所有忍术都被 `Job0.isSkillForbiden():422-427` 拦成
##     `WARNING_NOT_SKILL_MAP`（406010001 不在金锄副本里，那一档不拦）。

const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")

## 原版 `Map.nowJinChuFuBen`（`Map.as:243`）只认这一口。
const 金锄副本地图 := "406010000"

static var _禁寻路表 := {}
static var _已读 := false

static func 是禁寻路图(地图号: String) -> bool:
	_确保()
	return _禁寻路表.has(str(地图号))

static func 是金锄副本(地图号: String) -> bool:
	return str(地图号) == 金锄副本地图

## 某一档速度（`JingSuFuBen` 的键名）折算成**可直接赋给 `velocity` 的像素/秒**。
## 原版 `JinChuFuBenRolesSpeedManager.loadSpeedConfig()`（`:76-127`）逐键存的是
## `aspect * speed`，用的时候 `setVelocity({x: walkSpeed * X, y: jumpSpeed * Y})` ——
## x 乘走路速度、y 乘起跳速度，两个系数不是同一个量纲，别合并成一个。
static func 速度(键: String, 走路速度: float, 起跳速度: float) -> Vector2:
	var 表: Dictionary = GAME_DATA.取表("原版杂项").get("JingSuFuBen", {})
	var 档 = 表.get(键, null)
	if not (档 is Dictionary):
		push_warning("禁寻路地图: JingSuFuBen 缺 %s 这一档" % 键)
		return Vector2.ZERO
	var x: Dictionary = 档.get("x", {})
	var y: Dictionary = 档.get("y", {})
	return Vector2(
		float(x.get("aspect", 0)) * float(x.get("speed", 0)) * 走路速度,
		float(y.get("aspect", 0)) * float(y.get("speed", 0)) * 起跳速度)

static func _确保() -> void:
	if _已读:
		return
	_已读 = true
	var 副本: Dictionary = GAME_DATA.取表("原版杂项").get("FuBen", {})
	for 项 in 副本.values():
		if not (项 is Dictionary) or int((项 as Dictionary).get("type", 0)) != 9:
			continue
		var 图: Dictionary = (项 as Dictionary).get("maps", {})
		for 图项 in 图.values():
			if 图项 is Dictionary and (图项 as Dictionary).has("mapid"):
				_禁寻路表[str(int((图项 as Dictionary)["mapid"]))] = true
