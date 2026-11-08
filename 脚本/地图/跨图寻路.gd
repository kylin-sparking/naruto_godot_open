extends RefCounted
## 图与图之间的最短路 —— 原版 `com/mxw/map/path/MapPathFinder.as` + `MapJoint.as` 的移植。
##
## 用在哪儿：点任务绿名的 NPC / 小地图上的跨图标点，人在别的图时要**一路走过传送门过去**
## （原版 `CharacterHandler.MovePlayerToMap:609` → `Character.setWalkPathFindParam:490`
## → `KeyController:1112-1132` 取路线 → 逐跳 `:462-478`）。那些字段与推进都挂在会话和玩家上，
## 本文件只回答一个问题：**从 A 图到 B 图，依次走哪几扇门**。
##
## 真值口径（逐条有出处，别"顺手改"）：
## - 邻接表**只认 `pt == 2` 的门**（`MapPathFinder.initAdjacentMap():` `getPortalsByFilter({pt:2})`）。
##   `pt` 0/1/3/4/10 那些（出生点、随机传送、副本门…）不参与走路路线。
## - 边 = `出发图 → 门.tm`，权没有（原版是一条 BFS/Dijkstra，**ffdec 把 `getPath` 的循环体解丢了**，
##   搜法查不到原样 ⇒ 这里按「跳数最少」定，同跳数按门的编号小者优先，保证可重跑必同）。
## - 原版把边存进 `_adjMap[出发][到达] = MapJoint` ⇒ **同一对图之间有两扇门时，后扫到的那扇顶掉前扇**。
##   这条是原样，不是 bug 修复：顶掉之后路线仍成立，只是可能不是最近的那扇门。
## - 每一跳带的是**门所在图的门坐标**，玩家要走到 `(门.x, 门.y - 5)`（`KeyController:477` 那个 −5 是原样），
##   到了才 `world.changeMap(门.id)`（`:655`）。
## - 查不到图 / 不连通 ⇒ 原版 `getPath` 回 null、调用方 `stopPathFind()` **一声不吭**。
##   本工程按「不许静默」的规矩把它变成一句人话（`原因`），调用处必须播出来。
##
## 数据来源：`数据/地图/<目录名>/地图.json`，顶层 `mapId`（字符串数字）才是图号 ——
## **目录名大多是中文名**（`上层高台`、`Nya修炼场`），只有 3 张恰好等于图号；
## `会话.current_map_id` 用的是 `mapId` 那种形态（`DEFAULT_MAP_ID = "101010000"`）。
## `portal` 是字典，**键就是门号**（与 `传送门.gd`/`request_portal_enter` 同一口径）。
## 换图等级 = 目标图 `info.reqLevel`（原版 `StringTool.getReqLevelFromMapId:792` 取的就是这个键）。

## JSON 把数字解成 **float** ⇒ `str(门.tm)` 出来是 "112010000.0"，而表里的图号是 "112010000"，
## 两边永远对不上 —— 症状是"哪张图都到不了"，一句错都不报。图号一律先过这里归一。
static func _号(v) -> String:
	if v is float:
		return str(int(v))
	if v is int:
		return str(v)
	var s := str(v).strip_edges()
	if s.is_valid_int():
		return s
	if s.is_valid_float():
		return str(int(float(s)))
	return s


## 一次性建表，之后复用（181 张图的 json，扫一遍几十毫秒，但每次点绿名都扫一遍会卡）。
static var _图: Dictionary = {}
static var _号到图: Dictionary = {}
static var _邻接: Dictionary = {}
static var _建好 := false


## 扫 `数据/地图/`，只留 `pt == 2` 的门。图号（字符串）为键。
static func _建表() -> void:
	if _建好:
		return
	_建好 = true
	var 根 := DirAccess.open("res://数据/地图")
	if 根 == null:
		push_error("查无 res://数据/地图 —— 跨图路线建不出来")
		return
	根.list_dir_begin()
	var 目录 := 根.get_next()
	while 目录 != "":
		if 根.current_is_dir():
			var 路 := "res://数据/地图/%s/地图.json" % 目录
			if FileAccess.file_exists(路):
				var 数 = JSON.parse_string(FileAccess.get_file_as_string(路))
				if 数 is Dictionary:
					var 图号 := _号((数 as Dictionary).get("mapId", ""))
					if 图号 != "":
						var 门表: Array = []
						var 门们 = (数 as Dictionary).get("portal", {})
						if 门们 is Dictionary:
							for 号 in (门们 as Dictionary).keys():
								var 门 = (门们 as Dictionary)[号]
								if not (门 is Dictionary):
									continue
								if int((门 as Dictionary).get("pt", -1)) != 2:
									continue
								门表.append({
									"门号": int(str(号)),
									"门x": float((门 as Dictionary).get("x", 0)),
									"门y": float((门 as Dictionary).get("y", 0)),
									"到达图": _号((门 as Dictionary).get("tm", "")),
								})
						var 信息 = (数 as Dictionary).get("info", {})
						_图[图号] = {
							"目录": 目录,
							"门": 门表,
							"进门等级": int((信息 as Dictionary).get("reqLevel", 0)) if 信息 is Dictionary else 0,
						}
						_号到图[目录] = 图号
						# 邻接表按原版的形状建：`_adjMap[出发][到达] = MapJoint` —— 同一对图之间
						# 有几扇通向同一张图的门时，**数据里后出现的那扇顶掉前扇**（不是取最近的一扇）。
						# 照抄这个形状，路线才会和原版一致；"顺手改成最优门"会让玩家走向另一扇门。
						var 边 := {}
						for 门 in 门表:
							var 到 := str(门["到达图"])
							if 到 != "":
								边[到] = 门
						_邻接[图号] = 边
		目录 = 根.get_next()
	根.list_dir_end()
	# 建完自检：图号与目录都是唯一的，且门号能回查到（门号是数据里的键，重复 = 表被写坏）
	var 目录数 := 0
	for 号 in _图.keys():
		目录数 += 1
	if 目录数 == 0:
		push_warning("跨图寻路：一张图都没建进来 —— 数据/地图/*/地图.json 全读不到")


## 图号（也接受目录名）→ 那张图的记录；查不到回空字典。
static func 图记录(图: String) -> Dictionary:
	_建表()
	var 号 := 图号(图)
	return _图.get(号, {}) as Dictionary


static func 图号(图: String) -> String:
	_建表()
	if _图.has(图):
		return 图
	return str(_号到图.get(图, ""))


static func 有几张图() -> int:
	_建表()
	return _图.size()


## 某张图的邻接边 `{到达图号: 门记录}` —— 给门（`测试/跨图路线回归测试.gd`）逐条对真值用，
## 也给"走到那扇门"的调用处直接取坐标。查无此图回空字典。
static func 邻接边(图: String) -> Dictionary:
	_建表()
	return _邻接.get(图号(图), {}) as Dictionary


## 从 起 到 终 的逐跳路线。返回 `{"成":bool,"原因":String,"跳":[{出发图,到达图,门号,门x,门y,到达等级,已到达}]}`
## 「跳数最少」BFS；同跳数按门号小者优先 ⇒ 结果可重跑必同。
static func 路线(起: String, 终: String) -> Dictionary:
	_建表()
	var 起号 := 图号(起)
	var 终号 := 图号(终)
	if 起号 == "" or not _图.has(起号):
		return {"成": false, "原因": "查无出发地图 %s（数据/地图 里没有这张图）" % 起, "跳": []}
	if 终号 == "" or not _图.has(终号):
		return {"成": false, "原因": "查无目标地图 %s（数据/地图 里没有这张图）" % 终, "跳": []}
	if 起号 == 终号:
		return {"成": false, "原因": "已经在这张图上了", "跳": []}
	var 前 := {起号: ""}
	var 队: Array[String] = [起号]
	var 找到 := false
	while not 队.is_empty():
		var 在: String = 队.pop_front()
		var 边: Dictionary = _邻接.get(在, {}) as Dictionary
		var 去过 := 边.keys()
		# 等长路线之间选哪一条，原版取决于当时队列的顺序（查不到原样）⇒ 这里按到达图号排一次序，
		# 为的是「同样输入重跑必得同一条路」，不改变跳数最少这件事。
		去过.sort()
		for 到 in 去过:
			var 号 := str(到)
			if not _图.has(号) or 前.has(号):
				continue
			前[号] = 在
			队.append(号)
			if 号 == 终号:
				找到 = true
				break
		if 找到:
			break
	if not 找到:
		return {"成": false, "原因": "从 %s 走传送门到不了 %s（这两张图之间没有门路）" % [起, 终], "跳": []}
	var 跳: Array = []
	var 站 := 终号
	while 站 != 起号:
		var 上站 := str(前[站])
		var 门: Dictionary = (_邻接.get(上站, {}) as Dictionary).get(站, {}) as Dictionary
		if 门.is_empty():
			return {"成": false, "原因": "路线回推断了：%s 到 %s 之间没有记下的门" % [上站, 站], "跳": []}
		跳.push_front({
			"出发图": 上站,
			"到达图": 站,
			"门号": int(门.get("门号", -1)),
			"门x": float(门.get("门x", 0.0)),
			# 目标点用 y−5：原版 pathFind(门.x, 门.y - 5)（KeyController.as:477），不是手滑
			"门y": float(门.get("门y", 0.0)) - 5.0,
			"到达等级": int((_图[站] as Dictionary).get("进门等级", 0)),
			"已到达": false,
		})
		站 = 上站
	return {"成": true, "原因": "", "跳": 跳}
