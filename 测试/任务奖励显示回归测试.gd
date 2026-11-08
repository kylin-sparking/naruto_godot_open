extends SceneTree
## 离线门：任务面板右侧「任务奖励」那一段（文字 + 一排奖励道具格子）。
##
## 三条腿：
##  * **算式腿**：`_奖励物品` 的职业过滤 / 顺序、`_奖励` 的三行文案、
##   `_下半` 的挂标题门槛（原版 `MQuestionInfoPanel:147` 是「有文字奖励**或**有奖励道具」，
##   而且这一段在 if/else **之外** ⇒ 可接页也要挂）。全部自己按 AS3 重算一遍再比。
##  * **几何腿**：把真页面建进树里喂夹具，量第一格的 x=24、y=下文本顶+**文本高**+2、
##   格 40×40、图标居中取整、数量 (0,20) 40×20 右对齐、超宽折行回 24 / y+=45。
##  * **回归腿**：钉两条本轮实机抓到的坑 ——
##   ① `_指标符` 里 `String(数字)` 无效会让整段 `_下半` 崩掉（选了杀怪类任务详情不刷新）；
##   ② 清旧格必须**先 remove_child 再 queue_free**，否则同名新格被自动改名、下次清不掉。
##
## 跑法：Godot --path . --headless --script res://测试/任务奖励显示回归测试.gd
## ⚠ 本门**不许写存档**：只往会话内存里塞任务、不调任何落盘接口，
##   末了还要比对 `user://玩家数据.json` 的字节，变了就是量具坏了。

const 页面路 := "res://场景/界面/窗口/任务/任务窗口.tscn"
const 存档 := "user://玩家数据.json"
## 原版 `MQuestionInfoPanel.drawView:176-200` 与 `QuestInfoData.getEncourage:235-295`
const 起x := 24.0
const 格边 := 40.0
const 格距 := 5.0
const 文本下距 := 2.0
const 任务号 := "1009"

var 总 := 0
var 红 := 0
var 日志: Array[String] = []
var 存档前 := ""


func _记(过: bool, 说: String) -> void:
	总 += 1
	if not 过:
		红 += 1
		日志.append("  !! " + 说)
	else:
		日志.append("  √ " + 说)


func _同(实, 期, 说: String) -> void:
	_记(str(实) == str(期), "%s：实得 %s，期望 %s" % [说, str(实), str(期)])


func _字节() -> String:
	if not FileAccess.file_exists(存档):
		return ""
	var f := FileAccess.open(存档, FileAccess.READ)
	if f == null:
		return ""
	var 文 := f.get_as_text()
	f.close()
	return 文


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	call_deferred("_跑")


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _跑() -> void:
	# 新档首次启动时引擎自己会在头几帧落一份默认档（空脚本实测就会生成 9853 字节），
	# 基线必须取在那之后；否则「凭空多出一个档」会被记成门写了盘。
	await _帧(3)
	存档前 = _字节()
	var 包 = load(页面路)
	_记(包 != null, "任务窗口场景能 load（parse 炸在这里就会红，不会静默零覆盖）")
	if 包 == null:
		_尾()
		return
	var 会 = root.get_node_or_null("GameSession")
	_记(会 != null, "--script 模式下 GameSession 单例在（不在就没法喂职业）")
	if 会 == null:
		_尾()
		return
	var 页: Control = 包.instantiate() as Control
	root.add_child(页)
	await _帧(3)
	_算式腿(页)
	_进度腿(页)
	_选中腿(页, 会)
	await _几何腿(页, 会)
	_回归腿()
	页.queue_free()
	await _帧(2)
	_记(_字节() == 存档前, "门不许动存档（user://玩家数据.json 字节要一致）")
	_尾()


## 会话里换一个职业 ⇒ 奖励列表该跟着变（原版比的是 `API.dataCenter.stats.job`）
func _设职业(会, 职: int) -> void:
	会.player_stats["job"] = 职


## 拿列表第一条的某个键；列表空就回 -1（让断言红，而不是让门崩）
func _首(得: Array, 键: String) -> int:
	if 得.is_empty():
		return -1
	return int((得[0] as Dictionary).get(键, -1))


func _算式腿(页: Control) -> void:
	var 会 = root.get_node_or_null("GameSession")
	_设职业(会, 300)
	## ① 四件按职业分的装备 ⇒ 只该留 job==300 那件
	var 定 := {"act": {"1": {"equip": {
			"0": {"id": 1010011, "job": 100, "count": 1},
			"1": {"id": 1010012, "job": 200, "count": 1},
			"2": {"id": 1010013, "job": 300, "count": 1},
			"3": {"id": 1010014, "job": 400, "count": 1}}}}}
	var 得: Array = 页.call("_奖励物品", 定)
	_同(得.size(), 1, "职业 300 ⇒ 四件职业装只出一件")
	_同(_首(得, "id"), 1010013, "出的那件是 job=300 的 1010013")
	_设职业(会, 100)
	得 = 页.call("_奖励物品", 定)
	_同(_首(得, "id"), 1010011, "换成职业 100 ⇒ 该出 1010011（过滤是真在读职业，不是写死）")
	_设职业(会, 300)
	## ② 没写 job 这个键 ⇒ 不限职业，两件都出
	var 不限 := {"act": {"1": {"item": {
			"0": {"id": 3000001, "count": 20}, "1": {"id": 4000001, "count": 20}}}}}
	得 = 页.call("_奖励物品", 不限)
	_同(得.size(), 2, "不带 job 的条目不限职业 ⇒ 两件都在")
	_同(_首(得, "count"), 20, "数量照抄 count（不是写死 1）")
	## ③ 顺序：原版先 item 后 equip（`getEncourage:271` 在前、`:282` 在后）
	var 两样 := {"act": {"1": {"equip": {"0": {"id": 1010013, "count": 1}},
			"item": {"0": {"id": 6000013, "count": 1}}}}}
	得 = 页.call("_奖励物品", 两样)
	_同(得.size(), 2, "道具+装备两样都在")
	_同(_首(得, "id"), 6000013, "排在前面的是 item 段（顺序照 AS3 那两段 for each）")
	## ④ 文字奖励三行
	var 三行: String = 页.call("_奖励", {"act": {"1": {"exp": 300, "money": 150, "zq": 20}}})
	_记(三行.contains("经验值：300"), "经验那行「经验值：300」（CHARACTOR_EXP + 全角冒号）")
	_记(三行.contains("金币：150"), "金币那行「金币：150」")
	_记(三行.contains("20") and 三行.split("\n").size() == 3, "三行用换行分开（原版 \\n 拼接）")
	## ⑤ 门槛：只有道具、没有文字奖励 ⇒ 「任务奖励」这行标题**仍要出现**
	页.set("_当前页", 0)
	页.set("_当前任务", {"id": 任务号, "act": {"1": {"item": {"0": {"id": 6000013, "count": 1}}}},
			"npc": {"1": 3}, "check": {}})
	var 下: String = 页.call("_下半", 页.get("_当前任务"))
	_记(下.contains("任务奖励"), "只有道具奖励时也要挂「任务奖励」标题（原版 :147 的 || 门槛）")
	页.set("_当前页", 1)
	var 下2: String = 页.call("_下半", 页.get("_当前任务"))
	_记(下2.contains("任务奖励"), "可接页同样要挂（那一段在 if/else **之外**，以前只挂在当前页）")
	_记(下2.contains("接任务NPC"), "可接页那行是「接任务NPC」")
	页.set("_当前页", 0)


## 在线条目的逐目标进度只叫 `目标进度`（`444` 折成 kind/key/curr/count），
## 而 `_指标符` 照原版 `finishedNum` 读 `进度{键: 当前}`。以前两边没接上 ⇒
## 杀怪/收集永远 (0/总)、NPC 永远「未找到」（2026-10-26 用户任务窗截图那条）。
## 默认选中必须落在**显示顺序第一条**（主线），不是等级最低的日环。
## 用户 2026-10-26 截图：一开窗高亮和详情都是 `[20]日环式任务`（等级最低），
## 列表最上面却是主线；点主线像"跳到别处"。
func _选中腿(页: Control, 会) -> void:
	var 列: Array[Dictionary] = [
		{"id": "1279", "completed": false},
		{"id": "8001", "completed": false},
	]
	var 空: Array[Dictionary] = []
	会.accepted_quests = 列
	会.available_quests = 空
	页.call("刷新")
	_同(String(页.get("_选中id")), "1279",
			"默认选中主线 1279（旧写法按等级会选 20 级的日环 8001）")
	## 用户实机第二条：点主线行后选中自己跳走。回帧会重建整棵列表，选中必须跟着点的那条，
	## 不能被「默认选第一条」顶掉，也不能落到别组（同 50 级的 1270 先出）。
	var 列2: Array[Dictionary] = [
		{"id": "1270", "completed": false},
		{"id": "1279", "completed": false},
		{"id": "8001", "completed": false},
	]
	会.accepted_quests = 列2
	页.call("刷新")
	_记(String(页.get("_选中id")) in ["1270", "1279"],
			"三条混排时默认仍落在主线上（不是 8001）：实得 %s" % 页.get("_选中id"))
	页.call("_选任务", "1279")
	_同(String(页.get("_选中id")), "1279", "点了第二条主线就选中它")
	var 上: RichTextLabel = (页.get_node("详情") as Control).get_node("上文本") as RichTextLabel
	_记(上.get_parsed_text().contains("败北的滋味"),
			"详情跟着切到 1279（不是停在别条）：'%s'" % 上.get_parsed_text().left(30))
	页.call("刷新")
	_同(String(页.get("_选中id")), "1279", "回帧重建列表后选中仍是 1279（不跳回第一条）")


func _进度腿(页: Control) -> void:
	var 运 := {"id": "1018", "completed": false, "目标进度": [
		{"kind": "mob", "key": "1000001", "curr": 2, "count": 3}]}
	var 合: Dictionary = 页.call("_合并", 运)
	var 进: Dictionary = 合.get("进度", {}) as Dictionary
	_同(int(进.get("1000001", -1)), 2, "合并后 进度[怪号] = 当前数")
	var 文 := String(页.call("_指标符", 合))
	_记(文.contains("(2/3)"), "杀怪行显示真进度 (2/3)：'%s'" % 文)
	var 运2 := {"id": "1135", "completed": false, "目标进度": [
		{"kind": "npc", "key": "33", "curr": 0, "count": 1}]}
	var 文未 := String(页.call("_指标符", 页.call("_合并", 运2)))
	_记(文未.contains("未找到"), "NPC 进度 0 ⇒ 「未找到」：'%s'" % 文未)
	运2["目标进度"][0]["curr"] = 1
	var 文到 := String(页.call("_指标符", 页.call("_合并", 运2)))
	_记(文到.contains("找到") and not 文到.contains("未找到"),
			"NPC 进度 1 ⇒ 「找到」（不是永远未找到）：'%s'" % 文到)
	## 怪物名必须是**寻路链接**（原版 `#o<怪号>-<图号>#` ⇒ qusetClickText(2,…)）。
	## 以前只画绿名、点了只弹「目标：…」⇒ 玩家在详情里没法走到怪跟前（2026-10-26 实机）。
	var 合怪: Dictionary = 页.call("_合并", {"id": "1279", "completed": false,
			"目标进度": [{"kind": "mob", "key": "2000016", "curr": 0, "count": 1}]})
	var 文怪 := String(页.call("_指标符", 合怪))
	_记(文怪.contains("event:mob106020000:2000016"),
			"怪物名挂上寻路链接 event:mob<图>:<怪号>：'%s'" % 文怪)


## 把真页面喂上夹具，量运行期节点
func _几何腿(页: Control, 会) -> void:
	var 列: Array[Dictionary] = [{"id": "1009", "name": "新手武器", "completed": false}]
	var 空: Array[Dictionary] = []
	会.accepted_quests = 列
	会.available_quests = 空
	页.call("刷新")
	await _帧(3)
	var 详情: Control = 页.get_node("详情") as Control
	var 下: RichTextLabel = 详情.get_node("下文本") as RichTextLabel
	var 底: Panel = 详情.get_node("下底") as Panel
	var 格们 := _格们(详情)
	_同(格们.size(), 1, "1009（职业 300）该排 1 格")
	## 下面这一串**无条件跑**：一格都没有时也要逐条报红，而不是 `return` 掉 ——
	## 早退会让总条数掉下来，那种"红 1 条但少了 10 条"分不清是判红还是没判。
	var 格: Control = 格们[0] as Control if not 格们.is_empty() else null
	_同(格.size if 格 != null else Vector2(-1, -1), Vector2(格边, 格边),
			"格 40×40（SimpleItemCell 的 MGrid_background）")
	_同(格.position.x if 格 != null else -1.0, 起x, "第一格 x = 24（`_loc5_ = 24`）")
	_同(格.position.y if 格 != null else -1.0, 下.position.y + float(下.get_content_height()) + 文本下距,
			"第一格 y = 下文本顶 + **文本高** + 2（不是面板底）")
	_记(格 != null and 格.position.y + 格边 <= 底.position.y + 底.size.y,
			"格子落在下那块板的框内（y=%.0f 高=%.0f 板底=%.0f）" % [
			0.0 if 格 == null else 格.position.y, 格边, 底.position.y + 底.size.y])
	var 图 := (格.get_node_or_null("图标") as TextureRect) if 格 != null else null
	var 标 := (格.get_node_or_null("数量") as Label) if 格 != null else null
	_记(图 != null and 图.texture != null, "格里有真物品图标（不是空板）")
	var 寸 := 图.texture.get_size() if 图 != null and 图.texture != null else Vector2(-1, -1)
	_同(图.position if 图 != null else Vector2(-1, -1),
			Vector2(roundf((格边 - 寸.x) / 2.0), roundf((格边 - 寸.y) / 2.0)),
			"图标在格内**居中取整**（SimpleItemCell.as:164-165）")
	_记(标 != null, "格上有数量角标（showCount=true）")
	_同(标.position if 标 != null else Vector2(-1, -1), Vector2(0.0, 20.0), "数量在 (0,20)")
	_同(标.size if 标 != null else Vector2(-1, -1), Vector2(40.0, 20.0), "数量盒 40×20")
	_同(标.horizontal_alignment if 标 != null else -1, HORIZONTAL_ALIGNMENT_RIGHT, "数量**右对齐**")
	_同(标.text if 标 != null else "", "1", "数量文本 = 表里的 count")
	_同(格.mouse_default_cursor_shape if 格 != null else -1,
			Control.CURSOR_POINTING_HAND, "奖励格是手型（原版 buttonMode）")
	## 折行：造 8 件（无 job ⇒ 全出），第二行该回到 x=24、y 再 +45
	var 多 := {}	# AMF3 的 {"0":…,"1":…} 形状，不是数组
	for i in 8:
		多[str(i)] = {"id": 3000001, "count": 1}
	页.set("_当前任务", {"id": "夹具8件", "act": {"1": {"item": 多}}, "npc": {"1": 3}, "check": {}})
	页.call("_排奖励格")
	await _帧(2)
	格们 = _格们(详情)
	_同(格们.size(), 8, "八件奖励排八格")
	var 版宽 := 底.size.x
	var 每行 := int(floor((版宽 - 起x) / (格边 + 格距))) + 1
	# 这两条**无条件跑**：凑不够就报 -1（红），不因为"数量不对"整段跳过 ——
	# 跳过了总条数会掉，掉条数的门分不清"判红"和"没判"。
	var 折行 := 格们[每行] as Control if 格们.size() > 每行 else null
	var 首格 := 格们[0] as Control if not 格们.is_empty() else null
	_同(折行.position.x if 折行 != null else -1.0, 起x,
			"第 %d 格折行后 x 回 24（**先加后判**那条）" % (每行 + 1))
	_记(折行 != null and 首格 != null
			and absf(折行.position.y - (首格.position.y + 格边 + 格距)) < 0.01, "折行后 y += 40+5")
	## 换任务不许留旧格（remove_child 那条坑）
	var 列2: Array[Dictionary] = [{"id": "1018", "name": "小试牛刀", "completed": false}]
	会.accepted_quests = 列2
	页.set("_选中id", "")
	页.call("刷新")
	await _帧(3)
	var 名: Array[String] = []
	for 子 in 详情.get_children():
		名.append(String(子.name))
	_记(名.count("奖励格1") == 1, "换任务后只剩一格（实得 %s）" % ", ".join(名))
	var 漏网: Array[String] = []
	for 一个 in 名:
		if 一个.find("@TextureRect") >= 0:
			漏网.append(一个)
	_记(漏网.is_empty(), "没有漏网的自动改名节点（漏的：%s｜全部：%s）" % [
			", ".join(漏网), ", ".join(名)])


func _格们(详情: Control) -> Array:
	var 出: Array = []
	for 子 in 详情.get_children():
		if String(子.name).begins_with("奖励格"):
			出.append(子)
	return 出


func _回归腿() -> void:
	var 文 := _读("res://素材/界面/任务界面/脚本/任务窗口.gd")
	_记(文.length() > 1000, "任务窗口控制器读到了（%d 字节）" % 文.length())
	## ① 这条是**运行期真炸过**的：`String(数字)` 在 GDScript 没有这个构造，
	##   选了杀怪/收集类任务时整段 `_下半` 抛 Invalid call ⇒ 详情还留着上一条的文字。
	_记(文.contains("String(m.get(\"id\"") == false,
			"_指标符 里不许再出现 String(数字)（杀怪类任务会整段崩）")
	_记(文.contains("String(it.get(\"id\"") == false,
			"_指标符 的收集分支同上")
	_记(文.contains("str(int(m.get(\"id\", 0)))"),
			"怪物 id 走 int→str（`str(浮点)` 会给出 1000001.0，进度键对不上）")
	## ② 清旧格必须先摘下来
	_记(文.contains("_详情.remove_child(子)"),
			"_清奖励格 必须先 remove_child 再 queue_free（否则同名新格被改名、越攒越多）")
	## ③ 皮与职业过滤的出处别丢
	_记(文.contains("const 格皮 := \"res://素材/界面/原版窗口/通用控件/物品格.png\""),
			"奖励格底还是那张 物品格.png（MGrid_background）")
	_记(文.contains("int(it[\"job\"]) != 职"),
			"职业过滤是**逐条比玩家职业**，不是把 job 当数量用")


func _读(路: String) -> String:
	var f := FileAccess.open(路, FileAccess.READ)
	if f == null:
		return ""
	var 文 := f.get_as_text()
	f.close()
	return 文


func _尾() -> void:
	日志.append("")
	日志.append("汇：共 %d 条，红 %d 条" % [总, 红])
	for 行 in 日志:
		print(行)
	quit(0 if 红 == 0 else 1)
