extends SceneTree
## 家族升级**端到端**在线回归门：真起客户端连真服务端，把玩家那套点击路径整条走一遍。
##
## 为什么要有它：用户 2026-10-15 报"升级条件都满足了，点升级没反应"。
## §3.140 修掉了"一颗钮上接了两条同样的动作"（表现正是"点了没反应"），并由
## `家族升级确认回归测试.gd`（离线）钉住 UI 链；但**协议那一端**离线门碰不到
## （服务端不在）⇒ 立这一条在线的，把两端接上：
##   建族 → 捐献（家族资金 666 + 四书各 1）→ 开升级窗 → **点「确定」→ 点确认弹的「升级」**
##   → 等服务端把 `flagLevel +1` 推回来。
## 任何一级断了这里就红，并且指出断在哪一级（含"确定钮接了几条线"这种离线才发现得了的）。
##
## 用法（由夹具起，别手工跑；也可走 `开发工具/跑在线用例.ps1 -用例 家族升级端到端`）：
##   运行时/python/python.exe 开发工具/本地服务端夹具.py --root ./测试/输出/夹具存档/e2e --reset \
##       --run res://测试/家族升级端到端在线回归测试.gd --godot <你的 Godot console.exe>
## ⚠️ `--root` 必须指向**临时目录**并带 `--reset`（夹具自己的规矩：绝不指玩家的 `.fixture-play`）。
## ⚠️ 这条门**自己建族、自己解散**，不依赖任何预置账号数据。

var _后端: Node
var _窗: CanvasLayer
var _红 := 0


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	_后端 = root.get_node_or_null("BackendConnection")
	if _后端 == null:
		_失败("缺 BackendConnection 单例")
		_收尾()
		return
	_后端.sync_character()
	if not await _等到(func(): return bool(_后端.in_game), 15000):
		_失败("连不上真实后端 / 进不了游戏：%s %s" % [_后端.status, _后端.detail])
		_收尾()
		return
	print("√ 已连上后端并进入游戏")

	# ① 建族（服务端要扣 1000 金币）
	var 族名 := "E%d" % (int(Time.get_unix_time_from_system()) % 100000)
	if not _后端.request_guild_create(族名):
		_失败("创建家族请求没发出去")
		_收尾()
		return
	if not await _等到(func(): return bool(_后端.authoritative_guild.get("joined", false)), 8000):
		_失败("服务端没认下新建家族")
		_收尾()
		return
	print("√ 建族成功：%s" % 族名)

	# ② 捐献：家族资金 666 + 四种家族材料各 1（服务端 action 10 收的正是这两样）
	var 族号 := int(_后端.authoritative_guild.get("id", 0))
	if not _后端.request_guild_donate([[0, 666], [16000023, 1], [16000024, 1], [16000025, 1], [16000026, 1]]):
		_失败("捐献请求没发出去")
		_收尾()
		return
	if not await _等到(func(): return int(_后端.authoritative_guild.get("fund", 0)) >= 666, 8000):
		_失败("捐献没进家族资金")
		_收尾()
		return
	if not _后端.request_guild_members(族号) or not await _等到(func(): return _后端.authoritative_guild.has("materials"), 8000):
		_失败("服务端没回贡献帧（action 5）—— 升级窗里那两行数字就全靠它")
		_收尾()
		return
	print("√ 捐献到位：资金=%d 材料=%s" % [int(_后端.authoritative_guild.get("fund", 0)),
		str(_后端.authoritative_guild.get("materials", {}))])

	# ③ 开家族主窗 + 升级窗（= 底栏「家族升级」那颗钮）
	_窗 = (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate() as CanvasLayer
	root.add_child(_窗)
	await process_frame
	await process_frame
	_窗.call("_show_guild_action", "家族升级")
	await process_frame
	await process_frame
	var 升 := _内容("家族子窗_家族升级窗")
	if 升 == null:
		_失败("升级窗没开出来")
		_收尾()
		return
	var 文 := 升.get_node_or_null("文本升级说明") as RichTextLabel
	if 文 == null or not 文.text.contains("666"):
		_失败("升级窗没填上消耗（后端 authoritative_guild 没喂进填充）：%s" % (文.text if 文 else "<无节点>"))
	var 确定 := 升.get_node_or_null("钮确定") as TextureButton
	if 确定 == null:
		_失败("升级窗里没有「钮确定」")
		_收尾()
		return
	if 确定.disabled:
		_失败("条件全够但「确定」是灰的")
	_断(确定.pressed.get_connections().size() == 1, "「确定」上只该有 1 条 pressed，实为 %d"
		% 确定.pressed.get_connections().size())
	print("√ 升级窗开着、消耗已填、确定可点（接线 %d 条）" % 确定.pressed.get_connections().size())

	# ④ **点「确定」** ⇒ 确认弹
	var 级前 := int(_后端.authoritative_guild.get("level", 0))
	确定.pressed.emit()
	await process_frame
	await process_frame
	var 弹 := _内容("家族子窗_家族确认弹")
	if 弹 == null:
		_失败("点「确定」没弹出确认弹（§3.140 那个双接线 bug 还在？）")
		_收尾()
		return
	print("√ 确认弹出来了")

	# ⑤ **点确认弹的「升级」** ⇒ 发协议 + 关升级窗
	(弹.get_node_or_null("钮确定") as TextureButton).pressed.emit()
	await process_frame
	await process_frame
	if _内容("家族子窗_家族升级窗") != null:
		_失败("点「升级」后升级窗没关（协议分支没跑到）")
	if not await _等到(func(): return int(_后端.authoritative_guild.get("level", 0)) == 级前 + 1, 8000):
		_失败("服务端没把家族升上一级（级前 %d，现在 %d）" % [级前, int(_后端.authoritative_guild.get("level", 0))])
		_收尾()
		return
	print("√ 家族等级 %d → %d（整条链打通）" % [级前, int(_后端.authoritative_guild.get("level", 0))])

	# ⑥ 收尾：解散，别把测试族留在存档里
	_后端.request_guild_disband()
	await _等到(func(): return not bool(_后端.authoritative_guild.get("joined", true)), 5000)
	_收尾()


## 取某扇子窗的**内容页**（壳的孩子里第一个非「窗壳」的）。
func _内容(根名: String) -> Control:
	var 遮罩 := _窗.get_node_or_null("遮罩") as Control
	if 遮罩 == null:
		return null
	var 根 := 遮罩.get_node_or_null(根名) as Control
	if 根 == null:
		return null
	for 子 in 根.get_children():
		if String(子.name) == "窗壳":
			continue
		return 子 as Control
	return null


func _等到(判: Callable, 毫秒: int) -> bool:
	var 限 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 限:
		if 判.call():
			return true
		await process_frame
	return false


func _断(条件: bool, 话: String) -> void:
	if not 条件:
		_失败(话)


func _失败(话: String) -> void:
	_红 += 1
	print("  !! " + 话)


func _收尾() -> void:
	if _红 == 0:
		print("_探针_升级端到端：通过（建族→捐献→开窗→点确定→点升级→服务端升级）")
		quit(0)
	else:
		print("_探针_升级端到端：FAIL %d 条" % _红)
		quit(1)
