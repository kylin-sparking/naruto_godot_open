extends SceneTree
## 十拳剑/八咫镜「炼制」四支的**在线**端到端门（2081:0/1/2 + 2082:0）。
##
## 离线门 `背包道具回归测试.gd` 的 ⑳/⑳e 只喂假帧，钉的是「客户端怎么解、窗口怎么改」；
## 这条把同一组动作钉在**真服务端 + 真存档**上（§3.265 补的那半：结果帧以前根本没有消费者，
## 点开光就是白等）：
##   ① 前置：夹具把十拳剑、八咫镜与四种材料真发进背包（`--items` 覆盖默认背包）；
##   ② 开光(0) 成功 ⇒ 服务端**重发那一格**（clear + add，id 换成 20200001）⇒ 客户端照回包改账。
##      另钉「客户端不许自己合成物品数据」与原版那两记呆账：钮**按住不放开**、窗**不关**
##      （`onLingEquipKaiGuangResult:302-304` 是空函数）；
##   ③ 灵化(1) 成功 ⇒ 真件带 6 条 [ATTACK,1]（服务端 `_spiritualize_ling_qi`），
##      在场窗的附加展示置**字面量 1**（`onLingEquipLingHuaResult:266` 不是 6×1）；
##   ④ 洗炼(2) 成功 ⇒ 展示 = **第一条 ×6**（`updatePlusAttr:278-281`），且服务端真把 6 条各 +1~3；
##   ⑤ 两条拒绝腿（已灵化再灵化 / 洗炼石耗尽 ⇒ `:0:`）⇒ 文案一动不许动；
##   ⑥ 人具开光(2082:0) 成功 ⇒ 换 65000002、**无条件放开**、成功**关窗**（`handleKaiGuangResult:70-77`）。
##
## 跑法（由 `开发工具/跑在线用例.ps1 -用例 灵器炼制在线` 调，端口 18750/18751）：
##   python 开发工具/本地服务端夹具.py --root .fixture --reset \
##     --port 18750 --gm-http 18751 \
##     --items "20100001:1,65000001:1,16000116:3,16000117:300,16000118:100,16000120:1" \
##     --run res://测试/灵器炼制在线回归测试.gd --godot <Godot console exe>

const 门名 := "灵器炼制在线回归测试"
const 十拳剑 := "20100001"
const 开光剑 := "20200001"
const 人具 := "65000001"
const 开光人具 := "65000002"
const 开光锤 := "16000116"
const 开光石 := "16000117"
const 灵化石 := "16000118"
const 洗炼石 := "16000120"

var _失败: Array[String] = []
var _判数 := 0
var _回帧: Array = []
var _收好了 := false
var 会话引用: Node = null
var 原端口 := -1


func _记(成立: bool, 说明: String) -> void:
	_判数 += 1
	if not 成立:
		_失败.append(说明)


func _停(话: String) -> void:
	_还原设置()
	printerr("汇：判 %d 条 / 红 %d 条（%s：中断）" % [_判数, _失败.size() + 1, 门名])
	printerr("  红 - " + 话)
	quit(1)


func _帧(n := 1) -> void:
	for _i in range(n):
		await process_frame


func _等待(条件: Callable, 毫秒: int = 10000) -> bool:
	for _轮 in range(毫秒 / 50):
		if bool(条件.call()):
			return true
		await create_timer(0.05).timeout
	return bool(条件.call())


func _看门狗() -> void:
	await create_timer(240.0).timeout
	if _收好了:
		return
	printerr("汇：判 %d 条 / 红 %d 条（%s：看门狗超时）" % [_判数, _失败.size() + 1, 门名])
	quit(1)


func _还原设置() -> void:
	if 会话引用 != null and 原端口 >= 0:
		var 设置: Dictionary = 会话引用.get("game_settings")
		设置["backend_port"] = 原端口


func _on_回帧(操作码: int, 结果: Dictionary) -> void:
	_回帧.append([操作码, 结果])


## 背包行是**按格下标**摆的（`游戏会话._占用条` = 清单[格-1]，空格是 {}）⇒ 找件要扫全表。
func _槽(清单: Array, 编号: String) -> int:
	for i in range(清单.size()):
		var 条 = 清单[i]
		if 条 is Dictionary and String((条 as Dictionary).get("id", "")) == 编号:
			return i + 1
	return -1


func _条(清单: Array, 编号: String) -> Dictionary:
	var 格 := _槽(清单, 编号)
	return (清单[格 - 1] as Dictionary) if 格 > 0 else {}


func _件数(清单: Array, 编号: String) -> int:
	var 总 := 0
	for 条 in 清单:
		if 条 is Dictionary and String((条 as Dictionary).get("id", "")) == 编号:
			总 += int((条 as Dictionary).get("quantity", 0))
	return 总


## 洗炼文案里「攻击 +N」的 N —— 门自己拆一遍字符串，不调窗里那个 `_洗炼加成`（同源自证不算证据）。
func _取加(文: String) -> int:
	var 标 := "攻击 +"
	var 位 := 文.find(标)
	if 位 < 0:
		return -999
	var 起 := 位 + 标.length()   # ⚠ `find` 给的是**字符**下标不是字节
	var 止 := 起
	while 止 < 文.length() and 文[止] >= "0" and 文[止] <= "9":
		止 += 1
	return int(文.substr(起, 止 - 起)) if 止 > 起 else -998


func _按住(窗: Node) -> bool:
	var 钮 := (窗.get("_灵器开始钮") as Button)
	return 钮 != null and is_instance_valid(钮) and 钮.disabled


func _附加(窗: Node) -> int:
	var 值 = 窗.get("_灵器附加展示")
	return int(值) if 值 != null else -999


func _首条(条: Dictionary) -> int:
	var 表: Array = 条.get("plus_attributes", []) as Array
	return int((表[0] as Dictionary).get("attribute_value", 0)) if 表.size() > 0 else -1


func _清单() -> Array:
	return 会话引用.get("inventory") as Array


func _摘要() -> String:
	var 当: Array = _清单()
	return "锤%d 石%d 灵%d 洗%d 剑槽%d 开槽%d 镜槽%d 开镜槽%d" % [
		_件数(当, 开光锤), _件数(当, 开光石), _件数(当, 灵化石), _件数(当, 洗炼石),
		_槽(当, 十拳剑), _槽(当, 开光剑), _槽(当, 人具), _槽(当, 开光人具)]


func _内容(窗: Node) -> Control:
	if 窗 == null:
		return null
	var 内 := (窗.get("_content") as Control)
	return (内.get_child(0) as Control) if 内 != null and 内.get_child_count() > 0 else null


func _文案(窗: Node) -> String:
	var 内 := _内容(窗)
	if 内 == null:
		return "<无窗>"
	return String((内.get_node("内容底/文案") as RichTextLabel).text)


func _一行(窗: Node) -> String:
	return _文案(窗).replace("\n", "\\n").substr(0, 140)


## 点「开始」；钮不在/内容没建出来 ⇒ 直接算一条红（别静默把这一腿跳过）。
func _点开始(窗: Node, 腿: String) -> bool:
	var 内 := _内容(窗)
	if 内 == null:
		_记(false, "%s 点开始前：窗内容没建出来" % 腿)
		return false
	var 钮 := 内.get_node_or_null("内容底/开始") as Button
	if 钮 == null:
		_记(false, "%s 点开始前：没有「开始」钮" % 腿)
		return false
	钮.pressed.emit()
	return true


## 走背包那扇的**真菜单**开炼制窗。`背包窗口._开灵器炼制窗` 是私有 static，
## 点菜单是它唯一的真调用方 ⇒ 门不自己抄一遍「带物开窗 + 打开」（抄了就成了同源自证）。
## ⚠ `窗名` 与菜单项**不总是同名**：人具那扇的键是 `开光人具`（同一颗「开光」按 `_是忍具` 分流）。
func _开窗(管理: Node, 背窗: Node, 编号: String, 菜单项: String, 窗名: String) -> Node:
	var 格 := _槽(_清单(), 编号)
	if 格 <= 0:
		_记(false, "开窗前置：背包里没有 %s（%s）" % [编号, _摘要()])
		return null
	背窗.set("_selected_inventory_id", 编号)
	背窗.set("_selected_inventory_格", 格)
	var 页 := 背窗.find_child("原版背包内容", true, false) as Control
	var 菜 := 页.get_node_or_null("物品菜单") as Control if 页 != null else null
	if 菜 == null:
		_记(false, "开窗前置：背包页/物品菜单不在")
		return null
	菜.emit_signal("选择了", 菜单项)
	await _帧(6)
	var 窗 := 管理.call("取窗口", 窗名) as Node
	_记(窗 != null, "菜单「%s」该开出「%s」那一扇" % [菜单项, 窗名])
	return 窗


func _initialize() -> void:
	call_deferred("_跑")
	call_deferred("_看门狗")


func _跑() -> void:
	var 后端 := root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	if 后端 == null or 会话 == null:
		_停("缺单例（BackendConnection / GameSession）")
		return
	会话引用 = 会话
	后端.item_change_result_received.connect(_on_回帧)

	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18750
	var 设置: Dictionary = 会话.get("game_settings")
	原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	后端.call("sync_character")
	if not await _等待(
			func() -> bool: return bool(后端.get("in_game")) and (_清单() as Array).size() > 0,
			20000):
		_停("进不了真实后端：%s - %s" % [后端.get("status"), 后端.get("detail")])
		return

	# ── ① 前置：夹具真把那几件发进背包 ──
	var 到了 := await _等待(
			func() -> bool:
				var 当: Array = _清单()
				return _槽(当, 十拳剑) > 0 and _槽(当, 人具) > 0 \
					and _件数(当, 开光石) >= 300 and _件数(当, 灵化石) >= 100 \
					and _件数(当, 开光锤) >= 3 and _件数(当, 洗炼石) >= 1,
			10000)
	_记(到了, "① 夹具前置该把 剑/镜/锤3/石300/灵化石100/洗炼石1 发齐；实得 %s" % _摘要())
	if not 到了:
		_停("① 前置不齐（多半是 `--items` 没照门头那串给）")
		return

	# 窗口台子：在线时 root 下那层 CanvasLayer 是游戏壳建的；单跑这条门时台子未必在，
	# 没有就自己摆一层（与 `背包道具回归测试.gd` 的 ⑫ 同法）。
	var 管理: Node = null
	for 儿 in root.get_children():
		if 儿.has_method("取窗口") and 儿.has_method("打开"):
			管理 = 儿
			break
	if 管理 == null:
		管理 = (load("res://场景/界面/窗口管理.tscn") as PackedScene).instantiate()
		root.add_child(管理)
		await _帧(4)
	管理.call("打开", "背包")
	await _帧(6)
	var 背窗 := 管理.call("取窗口", "背包") as Node
	if 背窗 == null:
		_停("背包窗没从窗口管理开出来")
		return

	# ── ② 开光：真发 2081:0 ⇒ 服务端重发那一格 ⇒ 客户端照回包把 id 换成 20200001 ──
	var 开光窗 := await _开窗(管理, 背窗, 十拳剑, "开光", "开光")
	if 开光窗 == null:
		_停("② 开光窗没开出来")
		return
	var 锤基 := _件数(_清单(), 开光锤)
	var 石基 := _件数(_清单(), 开光石)
	_回帧.clear()
	if not _点开始(开光窗, "②"):
		_停("② 开光那扇点不动")
		return
	if not await _等待(func() -> bool: return _回帧.size() > 0, 15000):
		_停("② 发了 2081:0 但没收到结果帧（真服务端没回 = 端口/夹具没对上）")
		return
	_记(int(_回帧[0][0]) == 2081 and String(_回帧[0][1].get("kind", "")) == "ling_qi_result"
			and int(_回帧[0][1].get("action", -1)) == 0 and int(_回帧[0][1].get("result", 0)) == 1,
			"② 开光该回 2081 / kind=ling_qi_result / action=0 / result=1；实得 %s" % [_回帧[0][1]])
	_记(not _条(_清单(), 开光剑).is_empty(),
			"② 成功后背包里该出现 20200001 —— **只能来自服务端 clear+add 重发**（客户端不许自己合成）；实得 %s" % _摘要())
	_记(_件数(_清单(), 开光锤) == 锤基 - 1 and _件数(_清单(), 开光石) == 石基 - 100,
			"② 开光吃 1 锤 + 100 石；实得 锤 %d→%d、石 %d→%d"
			% [锤基, _件数(_清单(), 开光锤), 石基, _件数(_清单(), 开光石)])
	# 原版 `KaiGuangWindow.as:160` 请求前把钮按住，而 `onLingEquipKaiGuangResult` 是**空函数**
	# ⇒ 回帧回来既不放开、也不关窗（这一扇的「再点一次」本来就是废的）。
	_记(_按住(开光窗), "② 开光回帧以后那枚钮仍该按住（原版空函数、不放开）")
	_记(bool(开光窗.call("已打开")), "② 灵器开光成功不该关窗（只有 2082 人具那支关）")

	# ── ③ 灵化：2081:1:1 ⇒ 真件 6 条 [4,1]；在场窗的附加展示置**字面量 1** ──
	var 灵化窗 := await _开窗(管理, 背窗, 开光剑, "灵化", "灵化")
	if 灵化窗 == null:
		_停("③ 灵化窗没开出来")
		return
	_记(_附加(灵化窗) == 0,
			"③ 未灵化的件开窗时附加展示该是 0；实得 %d" % _附加(灵化窗))
	var 灵基 := _件数(_清单(), 灵化石)
	_回帧.clear()
	if not _点开始(灵化窗, "③"):
		_停("③ 灵化那扇点不动")
		return
	if not await _等待(func() -> bool: return _回帧.size() > 0, 15000):
		_停("③ 发了 2081:1 但没收到结果帧")
		return
	_记(int(_回帧[0][0]) == 2081 and int(_回帧[0][1].get("action", -1)) == 1
			and int(_回帧[0][1].get("result", 0)) == 1,
			"③ 灵化该回 action=1 / result=1；实得 %s" % [_回帧[0][1]])
	var 剑 := _条(_清单(), 开光剑)
	var 表: Array = 剑.get("plus_attributes", []) as Array
	_记(表.size() == 6 and int((表[0] as Dictionary).get("attribute_type", 0)) == 4
			and _首条(剑) == 1,
			"③ 服务端 `_spiritualize_ling_qi` 该写 6 条 [ATTACK,1]；实得 %d 条 / 首条 %s" % [表.size(), 剑.get("plus_attributes")])
	_记(_附加(灵化窗) == 1,
			"③ 灵化成功把附加展示置**字面量 1**（`onLingEquipLingHuaResult:266`，不是 6 条 ×1=6）；实得 %d" % _附加(灵化窗))
	_记(_件数(_清单(), 灵化石) == 灵基 - 100,
			"③ 灵化吃 100 颗灵化石；实得 %d→%d" % [灵基, _件数(_清单(), 灵化石)])

	# ── ④ 洗炼窗现在才开得出来（菜单三选一的规律）：开窗种子 = 服务端真值第一条 ×6 ──
	var 洗炼窗 := await _开窗(管理, 背窗, 开光剑, "洗练", "洗练")
	if 洗炼窗 == null:
		_停("④ 洗炼窗没开出来")
		return
	_记(_取加(_文案(洗炼窗)) == _首条(_条(_清单(), 开光剑)) * 6,
			"④ 开窗时洗炼文案该按「附加[0]×6」灌（`带物开窗` = 原版 `setData`）；实测「%s」，期望 攻击 +6"
			% _一行(洗炼窗))

	# ── ⑤ 灵化拒绝腿：已灵化的件再点一次 ⇒ 服务端回 `:1:0:-` ⇒ 两扇都不许动 ──
	_回帧.clear()
	if _点开始(灵化窗, "⑤"):
		if not await _等待(func() -> bool: return _回帧.size() > 0, 10000):
			_停("⑤ 第二次灵化没收到结果帧（服务端 `if item.plus_attributes` 那支也得回帧）")
			return
		_记(int(_回帧[0][1].get("result", 1)) == 0
				and (_回帧[0][1].get("plus_attributes", []) as Array).is_empty(),
				"⑤ 拒绝帧该是 result=0、`-` 解成**空**词条表；实得 %s" % [_回帧[0][1]])
		_记(_取加(_文案(洗炼窗)) == 6,
				"⑤ 失败回帧不许改洗炼文案（外层 `if(param1 == 1)` 吞掉）；实测「%s」" % _一行(洗炼窗))
		_记(_附加(灵化窗) == 1, "⑤ 失败回帧不许改附加展示；实得 %d" % _附加(灵化窗))

	# ── ⑥ 洗炼成功：文案 = **服务端回包第一条 ×6**（跟 ③ 的字面量 1 分流） ──
	_回帧.clear()
	if not _点开始(洗炼窗, "⑥"):
		_停("⑥ 洗炼那扇点不动")
		return
	if not await _等待(func() -> bool: return _回帧.size() > 0, 15000):
		_停("⑥ 发了 2081:2 但没收到结果帧")
		return
	var 洗帧: Dictionary = _回帧[0][1]
	var 洗表: Array = 洗帧.get("plus_attributes", []) as Array
	_记(int(洗帧.get("action", -1)) == 2 and int(洗帧.get("result", 0)) == 1 and 洗表.size() == 6,
			"⑥ 洗炼回帧该是 action=2 / result=1 / 6 条新词条预览；实得 %s" % [洗帧])
	var 回值 := int((洗表[0] as Dictionary).get("attribute_value", 0)) if 洗表.size() == 6 else -1
	_记(_取加(_文案(洗炼窗)) == 回值 * 6,
			"⑥ 洗炼成功走 `updatePlusAttr` = 第一条×6（服务端真值 %d ⇒ 期望 攻击 +%d）；实测「%s」"
			% [回值, 回值 * 6, _一行(洗炼窗)])
	_记(_首条(_条(_清单(), 开光剑)) == 回值,
			"⑥ 背包里那条该被服务端重发覆盖（客户端不自己加数值）；实得 %d vs 回帧 %d"
			% [_首条(_条(_清单(), 开光剑)), 回值])
	_记(_附加(灵化窗) == 回值 * 6,
			"⑥ `updateInfo()` 会把**在场**的三扇一起重刷 ⇒ 灵化那扇的附加展示也该是 第一条×6；实得 %d"
			% _附加(灵化窗))

	# ── ⑦ 洗炼拒绝腿：洗炼石只发了 1 颗、已吃光 ⇒ `:2:0:<原词条>` ⇒ 文案仍不许动 ──
	var 旧文案 := _文案(洗炼窗)
	_回帧.clear()
	if _点开始(洗炼窗, "⑦"):
		if not await _等待(func() -> bool: return _回帧.size() > 0, 10000):
			_停("⑦ 第二次洗炼没收到结果帧（材料不足服务端也回 `2081:2:0:`）")
			return
		_记(int(_回帧[0][1].get("result", 1)) == 0,
				"⑦ 洗炼石耗尽该被拒（result=0）；实得 %s" % [_回帧[0][1]])
		_记(_文案(洗炼窗) == 旧文案,
				"⑦ 失败回帧不许改洗炼文案；实测「%s」vs 原「%s」" % [_一行(洗炼窗), 旧文案.replace("\n", "\\n").substr(0, 140)])

	# ── ⑧ 人具开光：2082:0:1 ⇒ 换 id、**无条件放开**、成功**关窗** ──
	var 人窗 := await _开窗(管理, 背窗, 人具, "开光", "开光人具")
	if 人窗 == null:
		_停("⑧ 人具那扇开不出来")
		return
	_记(String(人窗.get("_固定页")) == "开光人具",
			"⑧ 人具该走 `开光人具` 那一页（与灵器开光分扇、走 2082）；实得 %s" % 人窗.get("_固定页"))
	_回帧.clear()
	if not _点开始(人窗, "⑧"):
		_停("⑧ 人具那扇点不动")
		return
	if not await _等待(func() -> bool: return _回帧.size() > 0, 15000):
		_停("⑧ 发了 2082:0 但没收到结果帧")
		return
	_记(int(_回帧[0][0]) == 2082 and String(_回帧[0][1].get("kind", "")) == "ren_ju_result"
			and int(_回帧[0][1].get("result", 0)) == 1,
			"⑧ 人具开光该回 2082 / kind=ren_ju_result / result=1；实得 %s" % [_回帧[0]])
	_记(not _条(_清单(), 开光人具).is_empty(),
			"⑧ 成功后八咫镜该换成 65000002（服务端重发）；实得 %s" % _摘要())
	await _帧(6)
	_记(not bool(人窗.call("已打开")),
			"⑧ 人具开光成功该**关掉**那一扇（`handleKaiGuangResult` 的 `setDOShow(false)`）")
	_记(not _按住(人窗),
			"⑧ `handleKaiGuangResult:70` 第一句**无条件**放回钮（失败也能重试）")

	_收好了 = true
	_还原设置()
	for 条 in _失败:
		printerr("  红 - " + 条)
	print("汇：判 %d 条 / 红 %d 条（%s：%s）" % [_判数, _失败.size(), 门名, "通过" if _失败.is_empty() else "失败"])
	quit(0 if _失败.is_empty() else 1)
