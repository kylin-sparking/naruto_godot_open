extends SceneTree

## 截「开心有礼」四页的**悬停详情框**（2026-11-01 用户报修：道具格鼠标放上去没有详情框）。
##
## 为什么要单写：离线门（`测试/福利页去充值回归测试.gd` 的悬停腿）只能证明
## `visible`/标题对；**框摆在哪、有没有被 ScrollContainer 裁掉、底板是不是糊在左上角**
## 这些必须拿眼睛看。这里用真视口跑一遍，把鼠标 warp 到格子上再截图。
##
## ⚠️ **不能加 --headless**（无头拿不到视口图像）。存图在 `res://测试/截图/福利悬停/`
##    （`.gitignore` 挡着：盘上有、仓里没有），**不碰 `user://`**。
##
## 用法：
##   Godot --path . --script res://开发工具/截福利悬停框.gd

const 福利场景路径 := "res://场景/界面/窗口/福利/福利窗口.tscn"
const 活动窗口脚本 := "res://脚本/界面/窗口/活动窗口.gd"
const 出目录 := "res://测试/截图/福利悬停"


class 假后端 extends RefCounted:
	var in_game := true
	var authoritative_czhuodong: Dictionary = {}
	var authoritative_gifts: Dictionary = {}

	func request_czhuodong_gain(_a: String, _b: String, _c: int) -> bool:
		return true

	func request_czhuodong_gain_first_kill() -> bool:
		return true

	func request_czhuodong_gain_xinfu(_a: String, _b: int) -> bool:
		return true


class 假宿主 extends RefCounted:
	var _backend
	var _session := {"player_stats": {"level": 90, "job": 1}, "equipped_items": {}}
	var _activity := {"state": {}}

	func _show_hint(_文: String) -> void:
		pass

	func _舞台尺寸() -> Vector2:
		return Vector2(960.0, 560.0)

	func _today() -> int:
		return 1

	func 禁用灰度材质() -> Material:
		return null


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出目录))
	call_deferred("_跑")


func _跑() -> void:
	var 场 := (load(福利场景路径) as PackedScene).instantiate() as Control
	root.add_child(场)
	var 宿主 := 假宿主.new()
	宿主._backend = 假后端.new()
	宿主._backend.authoritative_czhuodong = _配置()
	var 页代码 = load(活动窗口脚本).new(宿主)
	var 内容 := 场.get_node("滚动区/内容") as VBoxContainer

	var 用例 := [
		{"名": "签到_第1天", "页": 0, "格": "滚动区/内容/每日签到/第1天/物品2格",
			"填": func(): 页代码._填签到(内容.get_child(0) as Control)},
		{"名": "首杀礼包_礼包格", "页": 2, "格": "滚动区/内容/首杀礼包/奖励框/礼包格格",
			"填": func(): 页代码._填首杀礼包(内容.get_child(2) as Control)},
		{"名": "限时大奖_累计1", "页": 4, "格": "滚动区/内容/限时大奖/累计1/奖励1格",
			"填": func(): 页代码._填限时大奖(内容.get_child(4) as Control)},
		{"名": "新服有礼_每档1", "页": 5, "格": "滚动区/内容/新服有礼/大奖框/每档1/物品0格",
			"填": func(): 页代码._填新服有礼(内容.get_child(5) as Control)},
	]
	for 案 in 用例:
		for i in 内容.get_child_count():
			(内容.get_child(i) as Control).visible = i == int(案["页"])
		(案["填"] as Callable).call()
		await process_frame
		await process_frame
		var 格 := 场.get_node_or_null(String(案["格"])) as Control
		var 框 := 场.get_node_or_null("物品提示框") as Control
		if 格 == null or 框 == null:
			push_error("找不到格子或提示框：%s" % 案["名"])
			continue
		# 悬停闭包里读的是**当前鼠标位置** —— 先把指针挪到格子中心，再发信号。
		Input.warp_mouse(格.get_global_rect().get_center())
		await process_frame
		格.mouse_entered.emit()
		await process_frame
		await RenderingServer.frame_post_draw
		var 图 := root.get_texture().get_image()
		if 图 == null or 图.is_empty():
			push_error("拿不到视口图像 —— 是不是加了 --headless？")
			break
		var 路径 := "%s/%s.png" % [出目录, String(案["名"])]
		if 图.save_png(路径) != OK:
			push_error("存图失败：%s" % 路径)
			continue
		print("截福利悬停框：%s → %s（框 visible=%s 标题=「%s」 位置=%s）" % [
			String(案["名"]), 路径, 框.visible,
			(框.get_node("标题") as Label).text, 框.position])
		格.mouse_exited.emit()
		await process_frame
	场.queue_free()
	await process_frame
	quit(0)


## 与服务端 `_czhuodong_configs` 同形（够画四页即可）。
func _配置() -> Dictionary:
	return {
		"config": {
			"fc": {"info": {"libaoId": 11_010_041.0},
				"actions": {"each": {"0": {"items": [{"id": 11_010_041.0, "count": 10.0}]}}}},
			"limit": {"info": {"id": 1.0}, "actions": {
				"total": [{"cash": 1.0, "items": [{"id": 11_010_057.0, "count": 1.0}]}],
				"each": [{"cash": 2.0, "items": [{"id": 15_009_004.0, "count": 4.0}]}],
			}},
			"_xinfu": {"actions": {
				"each": {"6000057": {"items": [{"id": 15_012_001.0, "count": 1.0}]}},
				"rank": {"6000058": {"items": [{"id": 15_009_005.0, "count": 1.0}]}},
			}},
		},
		"first_kill": {"active": 0, "bossKills": 1},
		"limit": {"active": 1, "bossKills": 1,
			"beginTime": "2026-11-01 00:00:00", "endTime": "2026-12-01 00:00:00",
			"statusTotal": [1, 0, 0, 0, 0, 0, 0, 0, 0], "statusEach": [1, 0, 0, 0],
			"detailTotal": [], "detailEach": []},
		"xinfu": {"active": 1,
			"detailEach": {"6000057": {"curr": 0, "count": 1}},
			"detailRank": {"6000058": {"curr": 0, "count": 1}}},
	}
