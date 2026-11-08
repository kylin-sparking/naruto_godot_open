extends SceneTree
## 离线门：`脚本/地图/跨图寻路.gd`（图与图之间走哪几扇门）。
##
## 为什么这一道要**自己再解一遍数据**：路线算错不会崩、不会报错，只会"带着玩家往另一扇门走"
## 或"走一半停住" —— 那种错拿运行期断言测不出来。所以 A 组判据全部由本文件**独立解析
## `数据/地图/*/地图.json`** 得出期望，再与 `跨图寻路` 的表逐条比（两份一起漂才会漏，
## 和创建角色页那道同一个套路）。
##
## 真值出处（都写在 `脚本/地图/跨图寻路.gd` 的头注释）：
##   只用 `pt == 2` 的门 = `MapPathFinder.initAdjacentMap`；
##   同到一图的 later 门顶掉 earlier = `_adjMap[出发][到达] = MapJoint` 那句赋值；
##   目标点 = `(门.x, 门.y - 5)` = `KeyController.as:477`。
##
## 跑法：Godot --path . --headless --script res://测试/跨图路线回归测试.gd
## 纯逻辑、不开窗、不点鼠标 ⇒ 不碰 user://（`离线门不许写存档`）。

const 路脚本 := "res://脚本/地图/跨图寻路.gd"
const 现查图数 := 174
const 缺mapId目录 := ["终结之谷", "终结之谷东侧", "终结之谷西侧"]
## 现查（2026-10-10）：木叶村 → 112010000 的最短跳序。改了地图数据这条会红，那是**应该红**。
const 四跳 := ["103010000", "104010000", "104040000", "112010000"]
const 起点 := "100000000"
const 终点 := "112010000"
## 现查：没有任何一张图的 pt==2 门指向它 ⇒ 从木叶村走不过去（是单向门），必须报"到不了"而不是空转。
const 不可达 := "112040002"

var 总 := 0
var 红 := 0
var 日志: Array[String] = []
var 表 := {}


## 与 跨图寻路._号() 同义，但这里**自己写一遍**：两份实现都错到一块儿才会一起绿，
## 抄它的函数就等于没核。
func _号(v) -> String:
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


func _记(过: bool, 说: String) -> void:
	总 += 1
	if not 过:
		红 += 1
		日志.append("  !! " + 说)
	else:
		日志.append("  √ " + 说)


func _initialize() -> void:
	_跑()


## 自己把数据解一遍：`{图号: {"目录":…, "门":[按数据序的 pt==2 门], "进门等级":…}}`
func _解数据() -> void:
	var 根 := DirAccess.open("res://数据/地图")
	if 根 == null:
		_记(false, "读不到 res://数据/地图 这个目录（整道门没数据可核）")
		return
	根.list_dir_begin()
	var 目录 := 根.get_next()
	while 目录 != "":
		if 根.current_is_dir():
			var 路 := "res://数据/地图/%s/地图.json" % 目录
			if FileAccess.file_exists(路):
				var 数 = JSON.parse_string(FileAccess.get_file_as_string(路))
				if 数 is Dictionary:
					var 号 := _号((数 as Dictionary).get("mapId", ""))
					if 号 == "":
						号 = "无mapId:" + 目录
					var 门: Array = []
					var 门们 = (数 as Dictionary).get("portal", {})
					if 门们 is Dictionary:
						for k in (门们 as Dictionary).keys():
							var v = (门们 as Dictionary)[k]
							if v is Dictionary and int((v as Dictionary).get("pt", -1)) == 2:
								门.append({"门号": int(str(k)),
										"x": float((v as Dictionary).get("x", 0)),
										"y": float((v as Dictionary).get("y", 0)),
										"tm": _号((v as Dictionary).get("tm", ""))})
					var 信 = (数 as Dictionary).get("info", {})
					表[号] = {"目录": 目录, "门": 门,
							"进门等级": int((信 as Dictionary).get("reqLevel", 0)) if 信 is Dictionary else 0}
		目录 = 根.get_next()
	根.list_dir_end()


func _跑() -> void:
	var S = load(路脚本)
	_记(S != null, "跨图寻路 能 load（parse 炸在这里就会红，不会静默零覆盖）")
	if S == null:
		_尾(); return
	_解数据()
	_记(表.size() > 150, "门自己解出来的图张数 %d（低于 150 = 数据目录漂了）" % 表.size())
	var 有号 := 0
	for k in 表.keys():
		if not str(k).begins_with("无mapId:"):
			有号 += 1
	_记(S.有几张图() == 有号, "脚本建的图张数 == 门独立解出「有 mapId 的」张数（脚本 %d / 门 %d，表里另有 %d 条无 mapId 的目录）" % [S.有几张图(), 有号, 表.size() - 有号])
	_记(S.有几张图() == 现查图数, "有 mapId 的图恰好 %d 张（%s 这三个目录的 json 没有 mapId，进不了图级路线；重导数据补上后这条会红，那时把表值一起改）实际 %d 张" % [现查图数, str(缺mapId目录), S.有几张图()])
	_A_逐图对表(S)
	_B_路线(S)
	_尾()


## A 组：每张图的邻接边逐条对独立解析的结果（只认 pt==2、后扇顶前扇、门坐标原样）
func _A_逐图对表(S) -> void:
	var 错: Array[String] = []
	var 边数 := 0
	for 号 in 表.keys():
		if str(号).begins_with("无mapId:"):
			continue
		var 门: Array = (表[号] as Dictionary)["门"] as Array
		var 望 := {}
		for x in 门:
			if str((x as Dictionary)["tm"]) != "":
				望[str((x as Dictionary)["tm"])] = x
		var 实: Dictionary = S.邻接边(str(号)) as Dictionary
		边数 += 实.size()
		if 实.size() != 望.size():
			错.append("%s 边数 %d≠%d" % [号, 实.size(), 望.size()])
			continue
		for 到 in 望.keys():
			var w: Dictionary = 望[到] as Dictionary
			var r: Dictionary = (实.get(到, {}) as Dictionary)
			if r.is_empty():
				错.append("%s→%s 查无此边" % [号, 到])
			elif int(r.get("门号", -1)) != int(w.get("门号", -2)):
				# 这条钉的就是"后出现的门顶掉前面的门"这个原版形状
				错.append("%s→%s 门号 %d≠%d（同到一图的门要取数据里**最后**那一扇）"
						% [号, 到, int(r.get("门号", -1)), int(w.get("门号", -2))])
			elif (absf(float(r.get("门x", 0.0)) - float(w.get("x", 0.0))) > 0.01
					or absf(float(r.get("门y", 0.0)) - float(w.get("y", 0.0))) > 0.01):
				错.append("%s→%s 门坐标不对 实(%s,%s) 望(%s,%s)（脚本那边应等于 y−5）" % [
					号, 到, str(r.get("门x")), str(r.get("门y")), str(w.get("x")), str(w.get("y"))])
	_记(错.is_empty(), "全部 %d 张图的邻接边逐条 == 独立解析（只收 pt==2、同目标取数据里最后一扇、坐标是门原值）错 %s"
			% [表.size(), str(错.slice(0, 5))])
	_记(边数 > 100, "邻接边总数 %d（现查 173 张图有 pt==2 门、共 238 条门、顶扇后应仍有一百多条）" % 边数)
	var 等级错: Array[String] = []
	for 号 in 表.keys():
		if str(号).begins_with("无mapId:"):
			continue
		var 记2: Dictionary = S.图记录(str(号)) as Dictionary
		if int(记2.get("进门等级", -1)) != int((表[号] as Dictionary).get("进门等级", -2)):
			等级错.append("%s %d≠%d" % [号, int(记2.get("进门等级", -1)), int((表[号] as Dictionary)["进门等级"])])
	_记(等级错.is_empty(), "每张图的进门等级 == 该图 info.reqLevel（原版 getReqLevelFromMapId 取的就是这个键）错 %s"
			% str(等级错))
	_记(str(S.图记录("木叶村").get("目录", "")) == str((表.get("100000000", {}) as Dictionary).get("目录", "")),
			"传目录名也认（current_map_id 是图号，数据目录多半是中文名，两边都要能进）")


## B 组：路线本身
func _B_路线(S) -> void:
	var a: Dictionary = S.路线(起点, 终点)
	_记(bool(a.get("成", false)), "木叶村→%s 走得通（现查 4 跳）实际 %s" % [终点, str(a.get("原因", ""))])
	var 跳: Array = a.get("跳", []) as Array
	_记(跳.size() == 四跳.size(), "跳数 == 现查 %d 跳，实际 %d" % [四跳.size(), 跳.size()])
	var 序: Array[String] = []
	for x in 跳:
		序.append(str((x as Dictionary).get("到达图", "")))
	_记(" ".join(序) == " ".join(四跳), "逐跳的到达图序列 == 现查 %s，实际 %s" % [str(四跳), " ".join(序)])
	var 断: Array[String] = []
	if not 跳.is_empty():
		if str((跳[0] as Dictionary)["出发图"]) != 起点:
			断.append("第一跳的出发图不是起点")
		if str((跳[跳.size() - 1] as Dictionary)["到达图"]) != 终点:
			断.append("最后一跳的到达图不是终点")
		for i in range(1, 跳.size()):
			if str((跳[i] as Dictionary)["出发图"]) != str((跳[i - 1] as Dictionary)["到达图"]):
				断.append("%d 跳接不上" % i)
	_记(断.is_empty(), "链条首尾相接（上一跳到达 = 下一跳出发），断处 %s" % str(断))
	var 全: Array[String] = []
	for x in 跳:
		var h: Dictionary = x as Dictionary
		for k in ["出发图", "到达图", "门号", "门x", "门y", "到达等级", "已到达"]:
			if not h.has(k):
				全.append("%s 缺键 %s" % [str(h.get("到达图", "?")), k])
		if bool(h.get("已到达", true)):
			全.append("新路线的 已到达 必须是 false")
	_记(全.is_empty(), "每跳都带齐推进要用的七个字段（出发图/到达图/门号/门x/门y/到达等级/已到达）%s" % str(全))
	var 五错: Array[String] = []
	for h0 in 跳:
		var h: Dictionary = h0 as Dictionary
		var 上: String = str(h.get("出发图", ""))
		var 找: Array = ((表.get(上, {}) as Dictionary).get("门", []) as Array)
		var 原 := -999.0
		for x in 找:
			if int((x as Dictionary).get("门号", -2)) == int(h.get("门号", -1)):
				原 = float((x as Dictionary).get("y", 0.0))
		if absf(float(h.get("门y", 0.0)) - (原 - 5.0)) > 0.01:
			五错.append("%s→%s 门y %s ≠ 原值 %s − 5" % [上, str(h.get("到达图")), str(h.get("门y")), str(原)])
	_记(五错.is_empty(),
			"每一跳的落点是 (门.x, 门.y − 5) —— 原版 KeyController.as:477 那个 −5 是原样，不是手滑 %s" % str(五错))
	_记(JSON.stringify(S.路线(起点, 终点)) == JSON.stringify(a), "同一起终点连跑两次结果逐字相同（不定序就没法当判据）")
	var 同: Dictionary = S.路线(起点, 起点)
	_记(not bool(同.get("成", true)) and str(同.get("原因", "")).contains("已经在这张图上"),
			"同图 ⇒ 不成并说明原因（原版这里发的是 NO_TRANSFER_IN_MAP 提示，不是静默）实际 %s" % str(同.get("原因", "")))
	var 无: Dictionary = S.路线(起点, "888888888")
	_记(not bool(无.get("成", true)) and str(无.get("原因", "")).contains("查无目标地图"),
			"查无此图 ⇒ 点名哪一头查不到（原版 getPath 回 null 后只是 stopPathFind，玩家看不出为什么）实际 %s"
			% str(无.get("原因", "")))
	var 不: Dictionary = S.路线(起点, 不可达)
	_记(not bool(不.get("成", true)) and str(不.get("原因", "")).contains("到不了")
			and (不.get("跳", []) as Array).is_empty(),
			"没有门路 ⇒ 说「到不了」而不是回一条半路（%s 现查就是单向进得去出不来）实际 %s"
			% [不可达, str(不.get("原因", ""))])
	var 反: Dictionary = S.路线(不可达, 起点)
	_记(bool(反.get("成", false)) and (反.get("跳", []) as Array).size() >= 1,
			"反过来走得通（%s 有一扇 pt==2 的门通到 112010000）⇒ 证明上面那条红是方向不是查无" % 不可达)
	_记(str((反.get("跳", []) as Array)[0]).contains("112010000"),
			"第一跳的到达图就是它自己那扇门指向的图 实际 %s" % str((反.get("跳", []) as Array)[0]))


func _尾() -> void:
	日志.append("")
	日志.append("汇：共 %d 条，红 %d 条" % [总, 红])
	for 行 in 日志:
		print(行)
	quit(0 if 红 == 0 else 1)
