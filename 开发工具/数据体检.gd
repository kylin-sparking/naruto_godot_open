extends SceneTree

## 一次性数据体检：补齐后的 16 张原版分区能否被 GameData 读到、条数对不对。

func _init() -> void:
	var 脚本: GDScript = load("res://脚本/单例/游戏数据.gd")
	var 失败 := 0
	for 名 in ["怪物", "NPC", "物品", "技能", "地图名", "物品图标", "技能素材",
		"精华消耗", "装备基础属性", "任务", "增益状态", "成就", "活动", "经脉",
		"意志", "师徒", "VIP", "公告", "宝箱", "宝盒", "卡片", "忍具", "礼包奖励", "原版杂项"]:
		var 表: Dictionary = 脚本.取表(名)
		var 条数 := 表.size()
		if 条数 == 0:
			print("❌ %s = 0 条" % 名)
			失败 += 1
		else:
			print("✅ %s = %d 条" % [名, 条数])

	var 物品: Dictionary = 脚本.取表("物品")
	var 带属性 := 0
	var 带说明 := 0
	for 号 in 物品:
		if (物品[号] as Dictionary).has("attributes"):
			带属性 += 1
		if not String((物品[号] as Dictionary).get("detail_description", "")).is_empty():
			带说明 += 1
	print("物品：带 attributes %d，带 detail_description %d，图标命中 %d" % [
		带属性, 带说明, 脚本.取表("物品图标").size()])
	print("抽样 物品(11000001) = ", JSON.stringify(脚本.item(11000001)).left(260))
	print("抽样 礼包(11000001) = ", JSON.stringify(脚本.取表("礼包奖励").get("11000001", {})).left(200))
	print("抽样 精华消耗(30) = ", JSON.stringify(脚本.取表("精华消耗").get("30", {})))
	print("抽样 装备基础属性(basic.EquipF.stage5) = ",
		JSON.stringify((脚本.取表("装备基础属性").get("basic", {}) as Dictionary).get("EquipF", {}).get("stage5", {})))
	print("抽样 地图名 = ", 脚本.map_name(100010000), " / 怪物名 = ", 脚本.monster_name(1000017))
	print("RESULT 全部有数据" if 失败 == 0 else "RESULT %d 张表为空" % 失败)
	quit(0 if 失败 == 0 else 1)
