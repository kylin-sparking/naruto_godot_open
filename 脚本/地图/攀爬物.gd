extends Node2D

const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")
# 梯子/绳子的**碰撞**数据与攀爬查询。梯子是一条 x 固定的竖直线段，跨 [y1, y2]；
# 角色吸附到梯子 x 上，上下键攀爬。
#
# ⚠️ 这里**不画任何东西**。原版 `LadderRope` 是纯数据（`map/data/LadderRope.as` 只有
# x/y1/y2/l/page/uf/id），梯子的美术本来就在地图的物件/瓦片层里；唯一会画梯形的是
# `map/renders/PhysicRender.as`，而 `Map.as:225` 明写 `physicLayer.visible = this.isDebug`
# —— 那是调试层。旧实现在这里自己画了一套棕色梯子，叠在物件层已有的梯子美术上，
# 看上去就是"每个梯子里还嵌着一个小梯子"。

@export var map_id := "101010000"

var ladders := []  # array of {x, y1, y2, is_ladder}

func _ready():
	map_id = GameSession.current_map_id
	if has_meta("baked_ladders"):
		ladders.clear()
		for ladder_data in get_meta("baked_ladders", []):
			if ladder_data is Dictionary:
				ladders.append(ladder_data.duplicate(true))
		print("LadderRoot: using %d baked ladders/ropes" % ladders.size())
	else:
		load_ladders()

func load_ladders():
	var p := MAP_RESOURCES.map_data_path(map_id)
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		push_error("LadderRoot: cannot read " + p)
		return
	var txt := f.get_as_text()
	f.close()
	if txt.begins_with("\ufeff"):
		txt = txt.substr(1)
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var lr = data.get("ladderRope", {})
	for key in lr:
		var d: Dictionary = lr[key]
		var x = float(d["x"])
		var y1 = float(d["y1"])
		var y2 = float(d["y2"])
		# Original AbstractPhysicObject.checkLadder: isLadder = ladderRope.l == 1.
		# Our map data stores the original `l` field, so a rope has l != 1.
		var is_ladder = int(d.get("l", 0)) == 1
		# `page`：原版 `AbstractPhysicObject.tikcLayer` 里
		# `if(currLadderRope && climbing) getALayer(currLadderRope.page).addChild(this)`
		# —— 爬梯/爬绳时角色进的是**绳子自己的这一层**，通常比地形层高，
		# 所以人不会被梯子/绳子的美术盖住。丢了它就只能退回脚点层，人就被盖住。
		ladders.append({"x": x, "y1": y1, "y2": y2, "is_ladder": is_ladder,
			"page": int(d.get("page", 0))})

## 查脚下的梯子/绳子。
## `意图` 是 "up" / "down" / ""，两条方向的判定**不一样**：
##   按上（向上爬）：绳子末端可以离脚底还有约一个身位（`bottom_reach`），
##                   这样站在绳子正下方按上就能抓住、不必先跳 —— 原有行为。
##   按下（向下爬）：绳子**必须够到脚底**（`y2 + 4` 以内）。
##                   否则站在地面、绳子末端还悬在半空时按"下"也会被判定成吸附，
##                   角色明明没上绳子却播了往下爬的动作。
func get_ladder(x: float, y: float, 意图 := "") -> Dictionary:
	for l in ladders:
		var bottom_reach := 96.0 if not bool(l.is_ladder) else 72.0
		if 意图 == "down":
			bottom_reach = 4.0
		# 按上时要求**脚底在绳子顶端之下**（`y1 + 8`）：站在平台/绳子顶端按上，
		# 上方已经没有绳子可爬了，不该吸附 —— 否则会吸附→立刻到顶脱开→播一次
		# "上爬到顶"的收尾动作，让人以为自己在爬（用户看到的"上爬梯子结束的动作"）。
		var 上界: float = float(l.y1) - 20.0
		if 意图 == "up":
			上界 = float(l.y1) + 8.0
		if abs(x - l.x) <= 16.0 and y >= 上界 and y <= l.y2 + bottom_reach:
			var result: Dictionary = l.duplicate()
			result["bottom_reach"] = bottom_reach
			return result
	return {}
