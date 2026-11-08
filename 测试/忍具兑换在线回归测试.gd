extends SceneTree

## 忍具兑换（八咫镜）**在线**回归门 —— 报修 14 / #81（2026-10-24）。
##
## 为什么离线那条不够：`兑换窗族回归测试.gd` 自己 `取或建窗口` + `打开`，**入口那一跳没走**，
## 兑换钮又接在**假后端**上 ⇒ 它证的是"页画得对、点下去会调那个方法"。用户报的却是
## "看不到这个功能"，下面四件事一件都没被看过：
##   ① 活动大使（模板 59）**在这张图上吗** —— 服务端只把本图 life 推下来，`map_npcs` 里
##      没有这枚就没有入口，客户端表里写得再全也没用；
##   ② 点它之后 **328 帧的 menu 段**里到底有没有「兑换忍具&28」那一行（菜单是服务端
##      `_send_current_npc_dialog:51490-51509` 现拼的，`NPC_SERVICE_MENUS[59]` 少一行屏上就少一行），
##      还要钉 `player_text` 是 `-`：非 `-` 走的是原版 `QuestDialog:393-395` 的**剧情面**分支，
##      那一支**根本不建菜单行**（`小地图面板.gd:361-363`），玩家看到的是"点了没反应"；
##   ③ 点那一行 **窗真开出来了吗**。原版是服务端回 `1332:<对象号>:61` 才开
##      （`Client.as:5894 onShowNpcTriggerPanel` case 61 → `showRenJuDuiHuanWindow()`）；
##      本工程不接 1332、改由客户端本地 `行被点 → request_feature(页)` 开
##      ⇒ 所以必须钉"**只开一次、开完还留在台上**"：将来谁接了 1332 又没做幂等，
##        `窗口管理.打开或收起:784-797` 会把刚开出来的窗**当场关掉**，症状又是一句"未实装"；
##   ④ 点兑换走**真协议**之后服务端那一跳到底做没做：六碎片各扣 1、`65000001` 进包
##      （`handle_renju:52406-52428`）、窗关掉、客户端镜像跟上。
##
## ④ 的后半截就是本条现在会红的那处：**客户端认不认得这件奖品**。
## `数据/物品.json` 只并了 15 个分类、**不含 RenJu**（`开发工具/导出游戏数据.mjs:312-314` 那句注释
## 记着这件事），13 件忍具 `65000001..65000013` 只活在 `数据/忍具.json` 的 `info` 里 ⇒
## `游戏数据.item("65000001")` = 空字典、`item_name` 兜底成**一串 id**、`item_icon` = **null**、
## `item_detail` = 空。于是玩家换到手的背包格是"没图标 + 名字叫 65000001 + 提示框空白"。
## 原版的名字/文案在 `GameData → String/RenJu/<id>`（每条 `{name, desc, detaildesc}`，
## `RenJuData.as:31-36` 的 `itemDescObj` 读的就是它），本工程从没导过 ⇒ 补一张窄表，
## 再让 `item / item_name / item_detail / item_icon_path` 四处查表**回退**到忍具段。
## ⚠ 别把它塞进 `数据/物品.json`：`物品图标回归测试.gd` 钉死「索引 + 缺失 == 物品总数」，
##   而 物品.json 由 node 管线整份重生成 ⇒ 手改一次、下次导出又没了（口径记 §3.262）。
##
## 判据一律取**行为**、读**服务端那一份**（`authoritative_inventory`）；只有"背包刷新"才另读客户端镜像。
##
## 钉的腿（顺序不能换：L5 之后碎片就没了，L7 那条反向只能踩在 L5 的余烬上）：
##   L0 按**真门**传到木叶村：夹具默认落点是 101010000「终结之谷浅滩」（服务端
##      `DEFAULT_MAP_ID = MapId.FINAL_VALLEY_SHALLOW`），而活动大使（模板 59）在 174 张图里
##      **只烘在 100000000「木叶村」的 `life["10"]`**（`x=2512, y=1192`）⇒ 不先过去，L1 只会红在
##      "本图没有活动大使"，那是**门站错了图**、不是产品坏了（第一跑就是这么红的，2026-10-24）。
##      走的是 `request_map_change` ⇒ 本图 portal 表反查门号、发 `33:2:-1:<门号>`，
##      与玩家自己走到门口点门同一条服务端路径（不是给客户端塞假状态）。
##   L1 本图有模板 59（入口在不在）；
##   L2 328 帧带「兑换忍具&28」+ `player_text` = `-` + HUD 真把那一行**画**出来了；
##   L3 走 `NPC对话窗.按下行`（与鼠标完全同一条代码路径）⇒ 页开出来、1.5s 后仍在台上；
##   L4 六格数量 = 权威件数 = 1、名 = 碎片1..6、图标非空、**不灰**、数量文本不灰；
##   L5 点「兑换」⇒ 真发 `2082:3` ⇒ 六碎片各 −1、`65000001` ×1 进包、窗关掉、镜像同步；
##   L6 奖品认得：名字「八咫镜」/ 图标非空 / 详情非空；
##   L7 再点一次入口 ⇒ 六格 0 且**全灰**；换上计数后端点「兑换」⇒ **一个请求都不发** + 一句提示。
##
## ⚠ 三条口径：
##   · 端口：`夹具端口` 必须与 `跑在线用例.ps1` `$夹具额外` 的 `--port/--gm-http` **同时**改（§3.180），
##     少改一份会静默连到用户自己那台 18684、动真存档；
##   · 夹具默认 `MAIN_ITEMS` 已含六枚八咫镜碎片各 1（`本地服务端夹具.py:116-133` 那段注释就是为这条门
##     写的）⇒ 本条**不需要 `--items`**；种子哪天被改动，门会红在"种子"上而不是红在别处；
##   · 不写 `user://`：只动 `game_settings.backend_port` 一个键。收尾**先**把内存里那份换回原值、
##     **再**按字节还原两份档（`门存档快照`）—— 顺序要紧：`quit()` 之前任何一处 `_save_local_state()`
##     都会把内存里的临时端口再写回去，而在线那支（`游戏会话.gd:3732-3736`）写的是
##     `玩家设置.json` 不是 `玩家数据.json` ⇒ 只盯一份就会让用户客户端明天连到 18744（§3.217 同族）。
##
## 运行：`powershell -NoProfile -ExecutionPolicy Bypass -File 开发工具/跑在线用例.ps1 -用例 忍具兑换`

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 门存档快照 := preload("res://测试/门存档快照.gd")
const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 门名 := "忍具兑换在线回归测试"
const 木叶村 := 100000000			# 活动大使（模板 59）唯一烘在的这张图
const 夹具端口 := 18744			# 必须与 跑在线用例.ps1 `$夹具额外` 的 --port 同时改
const 模板 := 59				# 活动大使
const 动作 := 28				# `NpcMenuAction.RENJU_EXCHANGE`
const 行名 := "兑换忍具"
const 页名 := "忍具兑换"
const 根名 := "原版忍具兑换内容"
const 成品 := 65000001
const 成品号 := "65000001"
const 成品名 := "八咫镜"			# `GameData → String/RenJu/65000001.name`（原版真名）
const 碎片 := [16000278, 16000279, 16000280, 16000281, 16000282, 16000283]

var _后端: Node
var _会话: Node
var _场: Node
var _管理: Node
var _面板: Node
var _对话: Node
var _通知: Array = []
var _红数 := 0
var _秒 := 0.0
var _原端口 := -1
var _收过 := false
var _档前: Dictionary = {}


## 只用来**数调用**：L7 要证"碎片为 0 时一个请求都不发"，在线这门没法像离线门那样
## 拿假后端真发协议 ⇒ 这一颗不转发、只记次数（`_发兑换请求:2232` 只碰 `request_renju_combine`）。
class 计数后端:
	extends Node
	var 次数 := 0

	func request_renju_combine() -> bool:
		次数 += 1
		return true


## 看门狗：中途崩了就再也走不到 `quit()`，夹具会一直等 Godot 退出 —— "崩而不红"比红难查。
func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 240.0:
		_红("看门狗超时（240s）—— 中途崩了没走到收尾")
	return false


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)
	_档前 = 门存档快照.全快照()		# 两份 user:// 档都记（在线那支写的是 玩家设置.json）
	_后端 = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _后端 == null or _会话 == null:
		_红("缺单例：BackendConnection=%s GameSession=%s" % [_后端, _会话])
		return
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 夹具端口
	var 设置: Dictionary = _会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	_会话.notification_requested.connect(func(文: String) -> void: _通知.append(String(文)))
	_后端.sync_character()
	if not await _等(_进图好了, 20000):
		_红("连不上夹具 %d：%s - %s" % [口, _后端.status, _后端.detail])
		return
	if not await _等(_种子好了, 10000):
		_红("夹具种子不对：六枚八咫镜碎片权威件数 %s（要各 ≥1，`MAIN_ITEMS` 16000278..283）" % str(_六碎片件数()))
		return
	_查(_数(成品) == 0,
			"开局权威背包里已经有 %d 件八咫镜（%d）—— 本门后面全按「换到第一件」判" % [_数(成品), 成品])

	# ══ L0 按真门传到木叶村：活动大使只烘在那张图（夹具默认落在 101010000）══
	if int(_后端.authoritative_map_id) != 木叶村:
		if not bool(_后端.call("request_map_change", 木叶村, 0, 0)):
			_红("本图 %s 的 portal 表里没有通往木叶村（%d）的门 ⇒ 走不到活动大使那张图（`_find_portal_to_map:1031`）"
					% [str(_后端.authoritative_map_id), 木叶村])
			return
		if not await _等(_落到木叶村, 15000):
			_红("发了 `33:2:-1:<门号>` 却没落到木叶村：现在图=%s、本图 NPC=%s"
					% [str(_后端.authoritative_map_id), _本图NPC()])
			return

	# ── 真 HUD：入口（NPC 菜单）与窗（窗口管理）都长在地图场景里，离了它这条门就没腿 ──
	_场 = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(_场)
	for _序号 in 24:
		await process_frame
	_管理 = _场.get_node_or_null("窗口管理")
	_面板 = _场.get_node_or_null("小地图面板")
	if _管理 == null or _面板 == null:
		_红("地图场景里没有「%s」⇒ 入口和页都长在它身上，后面的腿一条无从跑起"
				% ("窗口管理" if _管理 == null else "小地图面板"))
		return
	_对话 = _面板.get("_对话")
	if _对话 == null:
		_红("小地图面板没有 `_对话`（§3.106 之后那枚 NPC 对话窗就是入口本体）")
		return

	# ══ L1 入口：本图有没有活动大使 ══
	var 号 := _NPC号()
	if 号 <= 0:
		_红("木叶村（%d）本图没有活动大使（模板 %d）⇒ 玩家根本点不到入口。本图 NPC=%s"
				% [木叶村, 模板, _本图NPC()])
		return

	# ══ L2 点 NPC ⇒ 328 帧的菜单段里那一行真的在 ══
	_后端.request_npc_dialog(号)
	if not await _等(_兑换行就绪, 8000):
		var 快: Dictionary = _后端.last_npc_dialog as Dictionary
		_红("点活动大使之后 328 帧里没有「%s&%d」那一行（menu=%s）—— 服务端 `NPC_SERVICE_MENUS[59]` 少这一行，屏上就少这一行"
				% [行名, 动作, JSON.stringify((快.get("menu", []) as Array))])
		return
	var 帧: Dictionary = _后端.last_npc_dialog as Dictionary
	_查(String(帧.get("player_text", "")) == "-",
			"328 帧 player_text=「%s」不是 `-` ⇒ 客户端走**剧情面**分支、一概不建菜单行（屏上没有那一行）"
				% String(帧.get("player_text", "")))
	for _序号 in 4:
		await process_frame
	var 行表: Array[String] = _面板.call("npc对话菜单行")
	var 序 := 行表.find(行名)
	if 序 < 0:
		_红("HUD 的对话窗没把「%s」画出来（屏上行=%s）—— 帧里有行、屏上没有 = 画的那一跳断了"
				% [行名, JSON.stringify(行表)])
		return

	# ══ L3 点那一行（`按下行` = 与鼠标同一条代码路径）⇒ 页开出来 ══
	_对话.call("按下行", 序)
	for _序号 in 4:
		await process_frame
	var 窗: Node = _管理.call("取窗口", 页名)
	if 窗 == null:
		_红("点了「%s」之后 `窗口管理` 里没有「%s」这扇窗（`_落地[%d]` 的页 → `request_feature` 断了）"
				% [行名, 页名, 动作])
		return
	_查(bool(窗.call("已打开")), "窗建出来了却没打开（`打开()` 那一跳没走到 / 页名对不上渲染分支）")
	await create_timer(1.5).timeout
	_查(bool(窗.call("已打开")),
			"窗开出来之后又被关掉了 —— 服务端随后回的 `1332:%d:61` 若被接成 `打开或收起`，" % 号
			+ "这一跳会把刚开的窗当场收起（原版是收到 1332 才开、只开一次）")
	var 页 := _取页(窗)
	if 页 == null:
		_红("窗里没有「%s」页（`_render_renju_exchange` 那条分支没跑到）" % 根名)
		return

	# ══ L4 六枚碎片格：数量 / 名 / 图标 / 灰化 ══
	_验碎片格(页, _六碎片件数())

	# ══ L5 点「兑换」⇒ 真协议 ⇒ 服务端扣六碎片、发八咫镜、窗关掉 ══
	var 兑 := 页.get_node_or_null("兑换钮") as Button
	if 兑 == null:
		_红("页上找不到「兑换钮」")
		return
	var 前: Array = _六碎片件数()
	兑.pressed.emit()
	if not await _等(func() -> bool: return _数(成品) >= 1, 10000):
		_红("点了兑换，权威背包里始终没有 %d —— `2082:3` 没发出去、或服务端 `handle_renju` 没认（前置=%s）"
				% [成品, str(前)])
		return
	var 后: Array = _六碎片件数()
	for i in 碎片.size():
		_查(int(后[i]) == int(前[i]) - 1,
				"碎片 %d 权威件数 %s→%s，没扣掉那 1 件（`handle_renju:52413-52414` 六种各扣 1）"
					% [int(碎片[i]), str(前[i]), str(后[i])])
	_查(_数(成品) == 1, "八咫镜进包 %d 件，应 1 件" % _数(成品))
	_查(not bool(窗.call("已打开")), "兑换发出去之后窗没关（原版 `RenJuDuiHuanWindow:176 setDOShow(...,false)`）")
	if not await _等(func() -> bool: return 镜像件数(成品号) == 1, 8000):
		_查(false, "服务端发了 %d，客户端背包镜像没跟上（`背包同名件数` 实测 %d）⇒ 玩家打开背包看不见奖品"
				% [成品, 镜像件数(成品号)])

	# ══ L6 这件奖品客户端认不认得（本门现在该红在这里）══
	_查(not 游戏数据.item(成品号).is_empty(),
			"`游戏数据.item(\"%s\")` 是空字典 —— 忍具段（`65000001..65000013`）从没并进查表链" % 成品号)
	_查(游戏数据.item_name(成品号) == 成品名,
			"背包格上那行名字是「%s」，原版是「%s」（`String/RenJu/65000001.name`）"
				% [游戏数据.item_name(成品号), 成品名])
	if 游戏数据.item_icon(成品号) == null:
		_查(false, "八咫镜的图标取不到（`item_icon_path` 空）⇒ 背包格是个空框")
	_查(游戏数据.item_detail(成品号).length() > 0,
			"八咫镜的详情文案是空的 ⇒ 悬停提示框一片空白（原版有 desc，见 §3.262）")

	# ══ L7 反向：碎片没了 ⇒ 六格 0 且全灰，点兑换一个请求都不发 + 一句提示 ══
	_后端.request_npc_dialog(号)
	if not await _等(_兑换行就绪, 8000):
		_红("兑换完再点活动大使，328 帧里那一行没了")
		return
	for _序号 in 4:
		await process_frame
	行表 = _面板.call("npc对话菜单行")
	序 = 行表.find(行名)
	if 序 < 0:
		_红("重开对话后屏上没有「%s」那一行" % 行名)
		return
	_对话.call("按下行", 序)
	for _序号 in 4:
		await process_frame
	_查(bool(窗.call("已打开")), "第二次点入口没把窗开回来（上次关掉的窗复用失败）")
	页 = _取页(窗)
	if 页 == null:
		_红("重开之后页又不在了")
		return
	_查(str(_六碎片件数()) == "[0, 0, 0, 0, 0, 0]",
			"兑换之后权威碎片不是六枚清零，实际 %s —— 下面「六格全灰」的期望就不成立了" % str(_六碎片件数()))
	_验碎片格(页, _六碎片件数())
	var 假 := 计数后端.new()
	窗.set("_backend", 假)
	_通知.clear()
	兑 = 页.get_node_or_null("兑换钮") as Button
	if 兑 == null:
		_红("重开的页上找不到「兑换钮」")
	else:
		兑.pressed.emit()
		for _序号 in 3:
			await process_frame
		_查(假.次数 == 0,
				"六枚碎片都是 0 件却发了 %d 次兑换请求（`_碎片齐` 那道闸没拦住 ⇒ 服务端只会回「请先集齐」）" % 假.次数)
		var 态 := 窗.get("_status") as Label
		_查(_有集齐提示(窗), "碎片不齐时该给一句提示（本页不许静默返回），实际 _status=「%s」 通知=%s"
				% [态.text if 态 != null else "无节点", JSON.stringify(_通知)])
	窗.set("_backend", _后端)
	_查(_数(成品) == 1, "反向这一趟把奖品也一起没了（权威 %d 件）" % _数(成品))
	_查(_档未脏(), "本门脏了 `user://` 那两份档（硬规矩：门不许动用户存档 —— 收尾仍会按字节还原）")
	_收尾()


## 六枚碎片格的三件事实：数量 = 背包真值（原版 `validateItem:134-153`）、名 = 碎片N
## （原版 `:120` 硬编码 `"碎片" + (i+1)`）、图标取到且**只有 0 件的格**灰（`applyGrayFilter`）。
func _验碎片格(页: Control, 件数: Array) -> void:
	for i in 碎片.size():
		var 格 := 页.get_node_or_null("子面板/碎片格%d/碎片格%d_格" % [i + 1, i + 1]) as Control
		if 格 == null:
			_查(false, "缺「碎片格%d_格」节点（版式被改过）" % (i + 1))
			continue
		var 有 := int(件数[i])
		var 数 := 格.get_node_or_null("碎片格%d_格_数量" % (i + 1)) as Label
		var 名 := 格.get_node_or_null("碎片格%d_名" % (i + 1)) as Label
		var 图 := 格.get_node_or_null("碎片格%d_格_图标" % (i + 1)) as TextureRect
		_查(数 != null and 数.text == str(有),
				"碎片格%d 的数量应是背包真值 %d，实际「%s」" % [i + 1, 有, 数.text if 数 != null else "无节点"])
		_查(名 != null and 名.text == "碎片%d" % (i + 1),
				"碎片格%d 的名应是「碎片%d」，实际「%s」" % [i + 1, i + 1, 名.text if 名 != null else "无节点"])
		_查(图 != null and 图.texture != null, "碎片格%d 的图标没取到（`数据/物品.json` 里六种碎片都有）" % (i + 1))
		var 该灰 := 有 == 0
		_查((格.material != null) == 该灰,
				"碎片格%d 的格皮灰化不对：数量 %d ⇒ 应%s灰" % [i + 1, 有, "" if 该灰 else "不"])
		if 图 != null:
			_查((图.material != null) == 该灰,
					"碎片格%d 的图标灰化不对（原版 `applyGrayFilter` 挂的是格皮+图标两件）" % (i + 1))
		_查(数 != null and 数.material == null, "碎片格%d 的**数量文本**不该灰（原版只灰格皮+图标）" % (i + 1))


func _取页(窗: Node) -> Control:
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	return 内容.get_node_or_null(根名) as Control


## 「碎片不全」那句提示：`_show_hint` 写进 `_status.text`，同时走 `_通知` —— 两处任一命中即算。
func _有集齐提示(窗: Node) -> bool:
	var 状态 := 窗.get("_status") as Label
	if 状态 != null and 状态.text.contains("集齐"):
		return true
	for 文 in _通知:
		if String(文).contains("集齐"):
			return true
	return false


func _兑换行就绪() -> bool:
	var 快: Dictionary = _后端.last_npc_dialog as Dictionary
	if int(快.get("npc_id", -1)) != 模板:
		return false
	for 行 in (快.get("menu", []) as Array):
		var 组: Array = 行 as Array
		if 组.size() == 2 and String(组[0]) == 行名 and int(组[1]) == 动作:
			return true
	return false


func _NPC号() -> int:
	for 号 in _后端.map_npcs:
		var 状: Dictionary = _后端.map_npcs[号]
		if int(状.get("npc_id", -1)) == 模板:
			return int(号)
	return -1


func _本图NPC() -> String:
	var 出: Array[String] = []
	for 号 in _后端.map_npcs:
		出.append(str((_后端.map_npcs[号] as Dictionary).get("npc_id")))
	return ", ".join(出)


func _六碎片件数() -> Array:
	var 出: Array = []
	for id in 碎片:
		出.append(_数(int(id)))
	return 出


func _进图好了() -> bool:
	return bool(_后端.in_game) and not (_后端.authoritative_inventory as Array).is_empty()


func _种子好了() -> bool:
	for id in 碎片:
		if _数(int(id)) < 1:
			return false
	return true


func _镜像() -> Array:
	return _后端.authoritative_inventory as Array


## ⚠️ 协议解出来 `id` 是**字符串**（`_parse_item_entry`），别的入口可能是 int ⇒ 归一再比。
func _数(号: int) -> int:
	var 总 := 0
	for 条v in _镜像():
		if 条v is Dictionary and int(str((条v as Dictionary).get("id", 0))) == 号:
			总 += int((条v as Dictionary).get("quantity", 0))
	return 总


func 镜像件数(号: String) -> int:
	return int(_会话.call("背包同名件数", 号))


func _落到木叶村() -> bool:
	## 服务端换图那帧会把 `map_npcs` 清空（`后端连接.gd:3812`）⇒ "非空"只在**新图**那一批 spawn 落地之后成立。
	return int(_后端.authoritative_map_id) == 木叶村 and not (_后端.map_npcs as Dictionary).is_empty()


## 两份 `user://` 档是否还是开场那副字节。
func _档未脏() -> bool:
	for 路 in _档前:
		if 门存档快照.读字节(String(路)) != (_档前[路] as PackedByteArray):
			return false
	return true


func _等(条件: Callable, 毫秒: int) -> bool:
	var 止 := Time.get_ticks_msec() + 毫秒
	while not bool(条件.call()) and Time.get_ticks_msec() < 止:
		await create_timer(0.05).timeout
	return bool(条件.call())


func _查(过: bool, 文: String) -> void:
	if not 过:
		_红数 += 1
		print("!! " + 文)


func _红(文: String) -> void:
	_查(false, 文)
	_收尾()


func _收尾() -> void:
	if _收过:
		return
	_收过 = true
	## 顺序要紧：先把**内存里**那一个键还原，再按字节还文件 —— `quit()` 之前任何一处
	## `_save_local_state()` 都会把临时端口再写回 `玩家设置.json`（§3.217 那夜就是这么脏的）。
	if _会话 != null:
		var 设置: Dictionary = _会话.get("game_settings")
		if _原端口 >= 0:
			设置["backend_port"] = _原端口
		else:
			设置.erase("backend_port")
		_原端口 = -1
	门存档快照.全还原(_档前)
	if _场 != null and is_instance_valid(_场):
		_场.queue_free()
		_场 = null
	if _后端 != null:
		_后端.call("disconnect_backend")
	if _红数 == 0:
		print("%s：通过（真门传到木叶村 / 本图有活动大使 / 328 帧带「%s&%d」且 HUD 画出那一行 / "
				% [门名, 行名, 动作]
				+ "点行只开一次窗并留在台上 / 六格数量=背包真值不灰 / 真发 2082:3 后六碎片各扣 1 且 %d 进包并关窗 / " % 成品
				+ "镜像跟上 / 奖品有名字有图标有详情 / 碎片清零后六格全灰且一个请求都不发 + 提示 / 两份 user:// 档逐字节未脏）")
		quit(0)
	else:
		print("%s：失败 %d 项" % [门名, _红数])
		quit(1)
