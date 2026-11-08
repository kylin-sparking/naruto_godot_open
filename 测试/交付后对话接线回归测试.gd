extends SceneTree

## 「交完任务、这枚 NPC 还有下一环 ⇒ 对话窗自己再弹一次」的**接线门**（#182，2026-10-11）。
##
## 与在线用例的分工（别混，也别互相顶替）：
##  * `测试/交付后自动弹对话在线回归测试.gd` 判的是**真服务端真客户端**那一趟：
##    交付生效之后确实收到一帧带下一环的 328（只有连着服务端才测得出这一条）；
##  * 本门判的是**形状**：那一帧是从服务端哪一句发出去的、守卫在不在、
##    客户端有没有被人顺手加一条"自己再点一次 NPC"的自造路。
##    在线用例一天只跑得起一次，形状必须有一道秒级的门钉住。
##
## 原版口径（逐条带出处）：
##  * 客户端点完「交付」只发一个包就结束 —— `UI.as:2262-2265` 的 `onQuestItemHandWindowHand`
##    ⇒ `requestNPCMoreTalkEx(NPCTalkCmdType.COMMIT=4, value)`；全量 1898 份 .as 里
##    **没有任何一处**在交付之后再 `requestNPCTalk`（这条是本轮重新查的，也据此撤回了
##    白天那句「原版靠 `NPCHandler.autoSpeak()` 路过自动搭话」——`autoSpeak` 零调用点）。
##  * 客户端收到 328 就开窗，且是无条件开 —— `小地图面板.gd:133 → _on_backend_npc_dialog
##    → show_npc_dialog`。
##  ⇒ 两头合起来：「再弹一次」只能由**服务端重推一帧 328**实现，客户端一律不许自己补。

const 服务端路 := "res://服务端/runtime/tools/fake_flash_server.py"
const 面板路 := "res://脚本/界面/小地图面板.gd"
const 对话窗路 := "res://脚本/界面/窗口/NPC对话窗.gd"
const 任务表路 := "res://数据/任务.json"

var _失败: Array[String] = []
var _条数 := 0


func _initialize() -> void:
	call_deferred("_run")


func _断言(成立: bool, 说明: String) -> void:
	_条数 += 1
	if not 成立:
		_失败.append(说明)


## 取 `func X` 到下一个顶层 `def ` 之间的源码（Python 侧）。
func _截段def(文: String, 头: String) -> String:
	var i := 文.find(头)
	if i < 0:
		return ""
	var 尾 := 文.find("\n    def ", i + 头.length())
	return 文.substr(i, 尾 - i) if 尾 > i else 文.substr(i)


## 取 GDScript 里 `func X` 到下一个 `func ` 的那段。
func _截段gd(文: String, 头: String) -> String:
	var i := 文.find(头)
	if i < 0:
		return ""
	var 尾 := 文.find("\nfunc ", i + 头.length())
	return 文.substr(i, 尾 - i) if 尾 > i else 文.substr(i)


## 逐行去掉 `#` 之后的内容（对本门够用：只用来搜一个标识符，不参与求值）。
func _剥注释(文: String) -> String:
	var 行: Array[String] = []
	for 原行 in 文.split("
"):
		var 位 := (原行 as String).find("#")
		行.append((原行 as String).substr(0, 位) if 位 >= 0 else (原行 as String))
	return "
".join(行)


func _run() -> void:
	var 服 := FileAccess.get_file_as_string(服务端路)
	if 服.is_empty():
		_断言(false, "读不到服务端源码 %s ⇒ 本门整条没判" % 服务端路)
		_收尾()
		return

	# ================= ① 那个骗过我的死参数，不许回来 =================
	var 交付函数 := _截段def(服, "    def _complete_original_quest(")
	_断言(not 交付函数.is_empty(), "找不到 `_complete_original_quest` 的定义（函数改名 ⇒ 本门要跟着改）")
	_断言(服.count("    def _complete_original_quest(") == 1,
			"`_complete_original_quest` 的定义不止一处")
	var 签名 := 交付函数.substr(0, 交付函数.find("\"\"\"") if 交付函数.find("\"\"\"") > 0 else 400)
	_断言(not 签名.contains("show_dialog"),
			"`show_dialog` 又回到形参表了 —— 它就是 #182 的作案工具：三个调用点全写 False、"
			+ "函数体一次都没读过它，看上去像「可选重开对话」，其实是个死参数")
	_断言(签名.contains(") -> bool:"),
			"`_complete_original_quest` 现在必须返回 bool（调用方拿它决定要不要重推对话），实得签名：%s" % 签名.strip_edges())
	_断言(交付函数.count("return False") >= 3,
			"交付函数里 `return False` 少于 3 条（三条早退：NPC 不是交付人 / 状态不是可交付 / 背包放不下）")
	_断言(交付函数.contains("return True"),
			"交付函数末尾没有 `return True` ⇒ 重推那一支永远不会触发")
	# 全文级别：不许再有任何"把它当参数传"的写法。
	# ⚠ 必须先剥注释：本文件自己的注释里就写着「全写 show_dialog=False」这句解释，
	#   不剥就会假红（提示条门那一轮踩过同一条，见 测试/提示条本体回归测试.gd 的 `_有码`）。
	var 代码 := _剥注释(服)
	_断言(not 代码.contains("show_dialog"),
			"服务端**代码**里还有 show_dialog（剥掉注释之后仍能搜到 = 那个死参数回来了）")

	# ================= ② 对话那一支：接住返回值 → 守卫 → 重推 =================
	var 对话函数 := _截段def(服, "    def _finish_original_quest_dialog(")
	_断言(对话函数.contains("= self._complete_original_quest(definition, npc.template_id)"),
			"_finish_original_quest_dialog 没有接住交付函数的返回值（返回值没人用 = 白改）")
	_断言(对话函数.contains("if 交付掉了:"),
			"交付重推没被 `if 交付掉了:` 包住 —— 背包满/状态不对这类「其实没交付成」也会弹一扇空窗")
	_断言(对话函数.contains("self._npc_quest_selections(npc, include_automatic=自动档) != \"-\""),
			"重推前少了「这枚 NPC 还有没有任务行」的守卫 —— 链尾交完会莫名弹一扇没有任务行的对话窗（原版不会）")
	_断言(对话函数.contains("self._send_current_npc_dialog(npc, include_automatic=自动档)"),
			"重推没走 `_send_current_npc_dialog`（服务端造 328 的唯一出口，与玩家自己点 NPC 同一个构造函数）")
	var 守卫位 := 对话函数.find("!= \"-\"")
	var 重推位 := 对话函数.find("self._send_current_npc_dialog(npc")
	_断言(守卫位 > 0 and 重推位 > 守卫位,
			"守卫必须在重推**之前**（先推再判就没意义了）")

	# ================= ③ 另外两个调用点不许跟着弹（它们没有 NPC 对话上下文） =================
	_断言(服.count("self._complete_original_quest(") == 3,
			"`_complete_original_quest` 的调用点数变了（应当 3 处：编辑器动作 / 对话交付 / 环任务瞬时完成）")
	_断言(服.count("self._complete_original_quest(definition, definition.end_npc_id)") == 2,
			"编辑器动作与环任务瞬时完成那两支应当都是「拿定义里的交付人、不带重推」的单行写法")
	var 环 := _截段def(服, "        if action == QuestAction.COMPLETE_LOOP:")
	_断言(not 环.contains("_send_current_npc_dialog"),
			"环任务瞬时完成那一支不许重推 NPC 对话（它的窗是环任务窗，不是 NPC 对话窗）")
	var 动作 := _截段def(服, "    def handle_quest_action(")
	_断言(not 动作.contains("_send_current_npc_dialog"),
			"`handle_quest_action`（任务面板那颗「完成任务」）不许重推对话 —— 原版那一条走的是 QUEST_ACTION，不经过对话")

	# ================= ④ 客户端两头：收到就开、点完不许自己补 =================
	var 板 := FileAccess.get_file_as_string(面板路)
	_断言(板.contains("_backend.npc_dialog_received.connect(_on_backend_npc_dialog)"),
			"HUD 不再监听 `npc_dialog_received` ⇒ 服务端推了窗也不会亮")
	var 消费 := _截段gd(板, "func _on_backend_npc_dialog(")
	_断言(消费.contains("show_npc_dialog("), "消费端没调 `show_npc_dialog`")
	_断言(not 消费.contains("_待对话NPC"),
			"消费端被加了「只有玩家主动点过 NPC 才开窗」的闸 ⇒ 服务端主动推的那一帧会被丢掉")

	var 窗 := FileAccess.get_file_as_string(对话窗路)
	var 点行 := _截段gd(窗, "func 按下行(")
	var 说完 := _截段gd(窗, "func 说完了(")
	_断言(窗.contains("request_npc_selection") and 点行.contains("request_npc_selection"),
			"任务行不再发 57:3 ⇒ 交付这一跳整个断了（那条包才是服务端落交付的地方）")
	_断言(not 点行.contains("request_npc_dialog") and not 说完.contains("request_npc_dialog"),
			"客户端在点完任务行/翻完台词之后**自己**又发了一次 54 —— 这条路要走就得由服务端推，"
			+ "客户端补发会变成「一次交付弹两扇窗」，而且离线在线两种表现分家")

	# ================= ⑤ 数据现查：这不是只有 1003 一条的特例 =================
	var 表 = JSON.parse_string(FileAccess.get_file_as_string(任务表路))
	if not (表 is Dictionary):
		_断言(false, "任务表读不出来")
	else:
		var 同枚 := 0
		var 不同枚 := 0
		for 号 in (表 as Dictionary).keys():
			var 条 = (表 as Dictionary)[号]
			if not (条 is Dictionary):
				continue
			var 校 = ((条 as Dictionary).get("check", {}) as Dictionary).get("0", {})
			if not (校 is Dictionary):
				continue
			var 前置 = (校 as Dictionary).get("quest", {})
			if not (前置 is Dictionary):
				continue
			for v in (前置 as Dictionary).values():
				if not (v is Dictionary):
					continue
				var 前号 := str(int((v as Dictionary).get("id", 0)))
				if not (表 as Dictionary).has(前号):
					continue
				var 前条: Dictionary = (表 as Dictionary)[前号] as Dictionary
				var 前n: Dictionary = 前条.get("npc", {}) as Dictionary
				var 本n: Dictionary = (条 as Dictionary).get("npc", {}) as Dictionary
				if 前n.is_empty() or 本n.is_empty():
					continue
				if int(前n.get("1", -1)) == int(本n.get("0", -2)) and int(前n.get("1", -1)) > 0:
					同枚 += 1
				else:
					不同枚 += 1
		print("⑤ 前置链普查：同一枚 NPC 交接 %d 对 / 跨 NPC %d 对" % [同枚, 不同枚])
		_断言(同枚 >= 100,
				"「交完这条、下一条还在同一枚 NPC」的对数掉到 %d（<100）⇒ 任务表换版了，" % 同枚
				+ "本门的价值也跟着掉，重查一次再放宽")
		var 三: Dictionary = (表 as Dictionary).get("1003", {}) as Dictionary
		var 六: Dictionary = (表 as Dictionary).get("1006", {}) as Dictionary
		_断言(int(((三.get("npc", {}) as Dictionary)).get("1", 0)) == 1
				and int(((六.get("npc", {}) as Dictionary)).get("0", 0)) == 1,
				"在线用例的夹具前提（1003 交给 NPC 1、1006 也从 NPC 1 发）在任务表里不成立了")

	_收尾()


func _收尾() -> void:
	## 末行必须带 `汇：` —— `开发工具/分段跑离线门.py` 只把含「汇：」的行存进日志，
	## 换成别的词日志里这条门就是空白行，看证据的人分不清"跑了但没话说"和"没跑"。
	print("汇：共 %d 条，红 %d 条%s" % [_条数, _失败.size(),
			"" if _失败.is_empty() else " —— " + " | ".join(_失败)])
	quit(0 if _失败.is_empty() else 1)
