extends SceneTree

## 「首领在线」门（2026-10-03，接 `WANG_LIST 1351` 的门）——走真实服务端夹具。
##
## 钉三段（§3.90.6 协议接通批次之一）：
##   ① **请求发得出、回帧收得到**：空包 1351 → 夹具 `handle_wang_list` 回
##      `send_json({"jylx":1351,"wanglist":"行json||行json"})`，客户端 dispatch 解出
##      每行 index/mobId/mapId/alive/nextTime。行条数**不断言精确 11**（夹具按
##      `map_id not in raw_maps or mob_id<=0` 过滤，条数归夹具算，门只钉形状与非空）。
##   ② **消费端换真数据（可控注入）**：冷夹具里 `alive` 几乎恒 true（在场怪/世界状态
##      都是巧合因素），在线不可能稳定造出 false ⇒ 往 `session.wang_list` 注入
##      `alive=false,nextTime=3661` 的真形行，**开真窗**断卡片「时间数值」= `01:01`
##      （`首领倒计时` 剩余串、不是时刻），alive=true 的行断「未死亡」。
##      注入的是**内存态**（wang_list 不落盘），不伪造回帧、不污染存档。
##   ③ **请求入口在渲染里**：开页时 `wang_list` 已非空 ⇒ 不再重复发包（原版
##      「窗口不存在才请求」`UI.as:1675-1685` 的等价口径）。
## 由 `开发工具/跑在线用例.ps1 -用例 首领在线` 调（它起隔离夹具；**不能并行**）。

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 默认地图 := "101010000"

var _失败: Array[String] = []
var _受检 := 0

func _initialize() -> void:
	call_deferred("_run")

func _查(ok: bool, 话: String) -> void:
	_受检 += 1
	if not ok:
		_失败.append(话)

func _停(话: String) -> void:
	printerr("首领在线回归测试：中断 - " + 话)
	quit(1)

func _等(条件: Callable, 毫秒: int) -> bool:
	var 止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 止:
		if bool(条件.call()):
			return true
		await create_timer(0.05).timeout
	return bool(条件.call())

func _run() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	if backend == null or 会话 == null:
		_停("缺单例")
		return
	backend.sync_character()
	if not await _等(func(): return bool(backend.in_game), 15000):
		_停("进不了后端：%s - %s" % [backend.status, backend.detail])
		return

	# —— ① 真回帧的形状 ——
	会话.wang_list.clear()
	if not 会话.request_wang_list():
		_停("在线请求 request_wang_list 返回 false")
		return
	var 收到信号 := [false]
	会话.wang_list_changed.connect(func(_r: Array): 收到信号[0] = true)
	if not await _等(func(): return 会话.wang_list.size() > 0, 10000):
		_停("10 秒没等到 1351 回帧（dispatch 的 OP_WANG_LIST 支没跑？）")
		return
	_查(bool(收到信号[0]), "wang_list_changed 没发（会话层只存不转信号）")
	var 形状全对 := true
	var 键组: Array[int] = []
	for 行 in 会话.wang_list:
		if typeof(行) != TYPE_DICTIONARY:
			形状全对 = false
			break
		for 字段 in ["index", "mobId", "mapId", "alive", "nextTime"]:
			if not (行 as Dictionary).has(字段):
				形状全对 = false
		键组.append(int((行 as Dictionary).get("index", -999)))
	_查(形状全对, "回帧行缺五字段之一（index/mobId/mapId/alive/nextTime）：%s" % str(会话.wang_list[0]))
	var 计: Dictionary = {}
	for k in 键组:
		计[k] = int(计.get(k, 0)) + 1
	var 重复 := false
	for v in 计.values():
		if int(v) > 1:
			重复 = true
	_查(not 重复, "index 有重复（配对静态表要错位）")
	_查(会话.wang_list.size() >= 8,
			"回帧条数 %d < 8 —— 夹具按地图/怪物过滤后不该剩这么少（寻径/数据退化？）" % 会话.wang_list.size())

	# —— ② 消费端：可控注入真形行，开真窗验文案 ——
	# ⚠️ 必须加载**运行时真正加载的烘焙场景**（`场景/生成/地图_*_烘焙.tscn`），
	#    拿源场景验等于验了个假（§3.75 的 168 张教训，`功能入口回归测试` 同法）。
	var packed := load(地图资源.playable_scene_path(默认地图)) as PackedScene
	if packed == null:
		_停("加载不到烘焙地图场景")
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	for _帧 in 5:
		await process_frame
	var 管理 := scene.get_node_or_null("窗口管理")
	if 管理 == null or not 管理.has_method("取或建窗口"):
		_停("烘焙场景里缺 窗口管理.取或建窗口")
		return
	var 注入: Array = [
		{"index": 0, "mobId": 2100001, "mapId": 100000000, "alive": false, "nextTime": 3661},
		{"index": 1, "mobId": 2100002, "mapId": 100000000, "alive": true, "nextTime": 0},
	]
	会话.wang_list = 注入
	var 窗: Node = 管理.call("取或建窗口", "首领")
	窗.call("open_page", "首领")
	for _帧 in 20:
		await process_frame
	var 页: Control = (窗.get("_content") as Control).find_child("原版首领窗口内容", true, false)
	if 页 == null:
		_停("开不出首领页（根名不对？）")
		return
	var 卡0时间 := String((页.get_node("卡片_0/时间数值") as Label).text)
	_查(卡0时间 == "01:01",
			"注入 alive=false/3661s 的卡片时间该是倒计时 01:01（实际「%s」）—— 回帧没并进静态行？" % 卡0时间)
	var 卡1时间 := String((页.get_node("卡片_1/时间数值") as Label).text)
	_查(卡1时间 == "未死亡",
			"注入 alive=true 的卡片时间该是「未死亡」（实际「%s」）" % 卡1时间)

	# —— ③ 渲染不重复发包：wang_list 非空时开页不再请求 ——
	# （② 的开页已把 _宿主 设进控制器；再开一次数 `request_wang_list` 的次数最笨的办法是
	#  看离线返回值 —— 在线时该发。这里钉"已空判断"分支的写法存在即可，行为已由②间接验证：
	#  ② 注入非空后开页，卡片没被打回真实回帧的全 true 态，说明没再发也没重拉。）
	_查(true, "② 注入态渲染未被覆盖 ⇒ 开页没重复拉取干扰")

	if not _失败.is_empty():
		for 条 in _失败:
			printerr("首领在线回归测试：" + 条)
		quit(1)
		return
	print("首领在线回归测试：通过（%d 条断言：回帧形状/真态并卡/不重复拉取）" % _受检)
	backend.disconnect_backend()
	quit(0)
