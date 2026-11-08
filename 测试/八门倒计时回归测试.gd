extends SceneTree

## 八门「开通穴道」的**延迟引爆倒计时**（`1290:1`）。
##
## 真事（用户 2026-10-16 报"还是说八门开通请求已发送，等待服务端"）：这一帧原来被当成
## **祝福值**存了 —— `state["blessing"] = int(fields[2])`，两处都错：
##   ① `fields[2]` 是**角色号**不是秒数；② 八门本来就没有"祝福值"那一支。
## ⇒ 原版那套「**关掉人物窗 → `delaySeconds*1000+1000` 毫秒后再开回来**」
##   （`Client.onMaiDelayExplode:11464-11485`）一步都没发生 ⇒ 玩家点完只看到一句提示、画面不动。
##
## 这条门钉两件事：
##   ① 帧解出来的是 **`countdown_seconds`**（且**不许**再冒出 `blessing`）；
##   ② **人物窗真的关了，并在 `秒+1` 之后自己回来**（到点时服务端已结算，重开即点亮穴位）。

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 默认地图 := "101010000"

var _failures: Array[String] = []
var _已记 := 0


func _initialize() -> void:
	call_deferred("_run")


func _记(条件: bool, 说明: String) -> void:
	_已记 += 1
	if not 条件:
		_failures.append(说明)


func _run() -> void:
	root.size = Vector2i(960, 560)
	var 场景 := (load(地图资源.playable_scene_path(默认地图)) as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _帧 in range(5):
		await process_frame

	var 后端 := root.get_node_or_null("BackendConnection")
	var 管理 := 场景.get_node_or_null("窗口管理")
	if 后端 == null or 管理 == null:
		_失败("依赖节点不完整")
		return
	管理.call("打开", "人物")
	await process_frame
	var 窗: Node = 管理.call("取或建窗口", "人物")
	_记(bool(窗.call("已打开")), "人物窗没开起来，后面的判据没法做")

	# 喂一条**真形状**的倒计时帧：`1290:1:<角色号>:<秒>:<true|false>`
	# （字段序照原版 `MaiProcessor.actionMaiDelayExplode`：playerId / delaySeconds / lastPt）
	var 我 := int(后端.get("character_id"))
	后端.call("_handle_cultivation_text", 1290,
		PackedStringArray(["1290", "1", str(我), "2", "true"]))
	await process_frame

	var 状态: Dictionary = (后端.get("authoritative_cultivation") as Dictionary).get("八门", {}) as Dictionary
	_记(int(状态.get("countdown_seconds", -1)) == 2,
		"倒计时秒数没解出来（现在是 %s）—— `1290:1` 的字段序是 角色号/秒/成败" % 状态.get("countdown_seconds"))
	_记(not 状态.has("blessing"),
		"八门回包里又出现了 `blessing`（八门没有祝福值那一支；原来就是把它当祝福值吞了倒计时帧）")
	_记(bool(状态.get("countdown_last_point", false)),
		"`lastPt` 没解出来 —— `1290:1` 第 4 个字段是 lastPt（最后一枚穴位），归零爆点大小靠它")

	# 人物窗应当**立刻关掉**，并在 秒+1 之后自己回来
	await process_frame
	_记(not bool(窗.call("已打开")), "收到倒计时帧后人物窗没关（原版 `Client.onMaiDelayExplode` 是当场关掉）")

	# 读秒归零那一下：`Character.tickMaiDelay:318-327` 放 `ExplodeEffect`（`addExploreEffect`）。
	# 大小由 `!lastPt` 决定：最后一枚（lastPt=true）⇒ `getExplodeEffectBig()` = 25 枚/波。
	var 人物 := get_first_node_in_group("player") as Node2D
	if 人物 == null:
		_失败("找不到 player 组里的人物，爆点没法判")
	var 爆点: Node = null
	var 截止爆 := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < 截止爆:
		var 找到 := 场景.find_child("八门爆炸", true, false)
		if 找到 != null:
			爆点 = 找到
			break
		await create_timer(0.05).timeout
	_记(爆点 != null, "读秒归零后没有出现爆点特效（原版 `addExploreEffect` 那一放）")
	if 爆点 != null:
		_记(爆点 is Node2D and (爆点 as Node2D).global_position.is_equal_approx(人物.global_position),
			"爆点没落在人物脚下（原版 `movieDO.x/y = 人物.x/y`）")
		_记(int(爆点.get("每波枚数")) == 25,
			"最后一枚（lastPt=true）应当放大爆（25 枚/波），实为 %s" % str(爆点.get("每波枚数")))

	# 等 秒+1（2+1=3 秒）—— 留足余量
	var 截止 := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < 截止:
		if bool(窗.call("已打开")):
			break
		await create_timer(0.2).timeout
	_记(bool(窗.call("已打开")), "倒计时结束后人物窗没自己回来（玩家会以为卡住了）")

	_收尾()


func _失败(说明: String) -> void:
	push_error("八门倒计时：" + 说明)
	quit(1)


func _收尾() -> void:
	if _failures.is_empty():
		print("八门倒计时回归测试：通过（%d 条断言：秒数/lastPt 解对 / 无 blessing / 当场关窗 / 归零爆点在脚下且最后一枚放大爆 / 到点回窗）" % _已记)
		quit(0)
		return
	for 项 in _failures:
		push_error("八门倒计时：" + 项)
	print("八门倒计时回归测试：失败 %d / %d 条 —— %s" % [_failures.size(), _已记, ", ".join(_failures)])
	quit(1)
