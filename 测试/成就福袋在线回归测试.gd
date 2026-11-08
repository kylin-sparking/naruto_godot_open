extends SceneTree

## 成就福袋**在线**回归门 —— #74 那一串里"服务端那半边"（2026-10-24）。
##
## 为什么离线门不够：`成就福袋回归测试.gd` 喂的是**我们按 AS3 格式自己造的帧**，
## 对撞的是两份自己的实现。它照不到四件事，只有真服务端能证：
##   ① **件是服务端在 `1286:1` 的处理里扣的**（`fake_flash_server.py:31903 _consume_bag_slot`）
##      ⇒ 权威背包里 15008001 少一枚，且**一件奖励都没进包**（不是"使用了"）；
##   ② 候选 16 件是 `random.sample(CAPTURED_FUDAI_REWARD_POOL, 16)`（`:31739`，**不放回**）
##      ⇒ 16 种互不相同、且每件都能在客户端物品表里查到（查不到 = 格子空图标）；
##   ③ 落点是服务端 `randrange(len(candidates))` 掷的（`:31927`），**奖品必须正是那一格**：
##      `1289:2:2:<index>` → 客户端跑完跑马灯 → `奖品格.id == 候选[index].id`、黄框停在那格；
##   ④ 领奖发 `1286:3` 之后服务端**三件事一起做**：发那一件 ×1（`:31936 _add_inventory_item`）、
##      找下一枚同种福袋并扣掉（`:31958` 起，**先看 `source_slot` 那一摞、再扫整张背包**）、
##      推下一条 `1289:1:1`（连开）或链尾 `1289:1:0:-:-:1`（`:31992`）。
##      ⚠️ 走哪一支是**服务端背包里还剩几枚**决定的 ⇒ 下面用 while 把轮数跑到来为止，
##      两条分支都要被踩到（连开 ≥1 轮、链尾恰好 1 轮），不写死轮数。
##
## ⚠ 种子口径（2026-10-24 首跑就撞出来的）：`--items "15008001:2"` **不是**整张背包的全部 ——
##   建角那一步服务端**自带** `11000001..11000012` + **15008001 ×1** 共 13 格
##   （`本地服务端夹具.py:222-232` 那句容量注释记着这件事），所以这条门实际拿到 **3 枚**：
##   第 1 轮的"下一枚"来自同一摞（`source_slot` 支），第 2 轮跨到建角那一摞（扫背包支），
##   第 3 轮才空 ⇒ 连开/链尾两支自然都过。别把它"修正"成 2 枚 —— 那样 `source_slot` 那条
##   服务端分支就没人跑了。开场先把实际件数读出来并钉住 `>= 3`，建角那 13 件若被改动，
##   这条门会红在"种子"上而不是红在别处。
##
## 钉的腿（顺序不能换：L3 要靠 L1 扣剩的那一枚、下一轮的落点要靠上一轮的连开帧）：
##   L1 双击 → 只发 `1286 "1:格位"` → `1289:1:1:-:<16>:1` → **窗在这条帧里开出来**（居中、标题=物品名）
##      + 服务端吃掉一枚 + 客户端镜像跟着刷新（`背包同名件数` 同步少一枚）；
##   L2 「开始」→ `1289:2:2:<index>` → 跑马灯**自己走完**（真 Timer，不手摇）→ 奖品格 = 候选[index]、黄框停在它上面；
##   L3 **事务活着时再点一次福袋** ⇒ 服务端不重复扣件、只重推状态（`state=2` + `gained` 非空）
##      ⇒ 窗不重建、领奖钮当场开、件数不变（服务端那支不看格位，客户端要挑还剩福袋的那格）；
##   L4 每轮「领奖」⇒ 那一件进包 ×1、`isBagExistItem` 分流（有下一枚⇒清奖品格；没有⇒留图标）、
##      连开帧 `1289:1:1` 复用同一枚窗 / 链尾帧 `1289:1:0:-:-:1` 不清环也不关窗；
##   L5 链尾之后硬发一条 `1286 "2"`（绕过灰钮直接调 `_福袋发开始`）⇒ 服务端 `:31925` 直接
##      `return`，**一帧都不回** ⇒ 客户端也不许自己演（奖品格纹丝不动）。
##
## ⚠ 三条口径：
##   · 判定一律读 `authoritative_inventory`（服务端那一份），"背包刷新"才另外读客户端镜像；
##   · 端口：`夹具端口` 必须和 `跑在线用例.ps1` `$夹具额外` 的 `--port` **同时**改（§3.180），
##     少改一份会静默连到用户自己那台 18684、动真存档；
##   · "从不发 USE_ITEM" 钉在**离线门**（那里数得到 opcode）；这条门的等价证法是走错分支
##     的话 1289 首帧根本不会来 ⇒ L1 直接红。
##
## 运行：`powershell -NoProfile -ExecutionPolicy Bypass -File 开发工具/跑在线用例.ps1 -用例 成就福袋`

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 窗场景 := "res://场景/界面/功能窗口.tscn"
const 福袋 := 15008001
const 福袋号 := "15008001"
const 夹具发 := 2				# `$夹具额外` 的 `--items "15008001:2"`
const 建角自带 := 1				# 服务端建角那 13 件里有一枚福袋（见头注释）
const 最多轮 := 6				# 兜圈上限：真值到得了的只有 3 轮，多出来的是保险
const 夹具端口 := 18742			# 必须与 跑在线用例.ps1 `$夹具额外` 的 --port 同时改
const 标题字 := "成就福袋"		# `数据/物品.json` 里 15008001 的 name（`setData:247` 用它覆盖 CN 标题）

var _红数 := 0
var _秒 := 0.0
var _原端口 := -1
var _起始 := 0
var _连开 := 0				# 连开轮数（服务端 `source_slot`/扫背包两支各算一轮），只为收尾那句打印
var _后端: Node
var _会话: Node
var _场: CanvasLayer
var _帧: Array = []


## 看门狗：`_run` 里任何一句崩了就再也走不到 `quit()`，夹具会一直等 Godot 退出
## —— "崩而不红"比红更难查，所以超时也算失败（240s：夹具启动 ≈50s + 三轮 ≈30s）。
func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 240.0:
		_红("看门狗超时（240s）—— 中途崩了没走到收尾")
	return false


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)
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
	_后端.fudai_state_received.connect(_收帧)
	_后端.sync_character()
	if not await _等(_进图好了, 20000):
		_红("无法进入真实后端：%s - %s" % [_后端.status, _后端.detail])
		return
	if not await _等(_种子好了, 10000):
		_报种子()
		return
	_起始 = _数(福袋)

	_场 = (load(窗场景) as PackedScene).instantiate() as CanvasLayer
	root.add_child(_场)
	await process_frame
	await process_frame

	var 格位 := _格位()
	_查(格位 > 0, "权威镜像里查不到福袋的 slot_index（现有 %d 格）" % _镜像().size())
	if 格位 <= 0:
		_收尾()
		return

	# ══ L1 双击 → `1286 "1:格位"` → `1289:1:1` 开帧 → 窗开出来 + 服务端扣一枚 ══
	_帧.clear()
	_场.call("_use_item", 格位)
	if not await _等(func() -> bool: return _帧.size() >= 1, 8000):
		_红("双击福袋后一条 1289 都没回 —— 走成 USE_ITEM 了，或服务端没认这件（`fudai_item_types[15008001]` 该是 1）")
		_收尾()
		return
	var 首: Dictionary = _帧[0]
	var 候选: Array = 首.get("candidates", []) as Array
	_查(int(首.get("action", 0)) == 1 and int(首.get("state", -1)) == 1,
			"首帧应是 action=1/state=1（新建的事务还没落点），实得 %s" % str(首))
	_查(int(首.get("type", -1)) == 1, "15008001 的福袋类型应是 1（`数据/宝盒.json` fudai[\"1\"].itemid）")
	_查((首.get("gained", {}) as Dictionary).is_empty(), "刚建的事务不该带已得件（`_send_fudai_state` 里 selected<0 ⇒ `-`）")
	_查(候选.size() == 16, "服务端应推 16 格候选（`sample(池, 16)`），实得 %d" % 候选.size())
	var 种 := 0
	var 种类 := {}
	var 查不到 := 0
	for 项 in 候选:
		var 号 := str((项 as Dictionary).get("id", ""))
		if not 种类.has(号):
			种类[号] = true
			种 += 1
		if 游戏数据.item(号).is_empty():
			查不到 += 1
	_查(种 == 16, "服务端是不放回抽 ⇒ 16 候选该 16 种各不相同，实得 %d 种（`@`/`&` 解析错位会串门）" % 种)
	_查(查不到 == 0, "有 %d 件候选客户端物品表查不到（格子上空图标、提示框空白）" % 查不到)
	_查(_数(福袋) == _起始 - 1,
			"服务端没吃掉那枚福袋（权威镜像 %d 枚，应 %d）—— 扣件在 action 1 的 `_consume_bag_slot`"
				% [_数(福袋), _起始 - 1])
	var 镜像 := await _等(func() -> bool: return 镜像件数(福袋号) == _起始 - 1, 6000)
	_查(镜像, "服务端扣了件，客户端镜像却没刷新（`背包同名件数` 实测 %d，应 %d ⇒ 玩家看到扣不动）"
			% [镜像件数(福袋号), _起始 - 1])

	var 窗 := await _等窗()
	if 窗 == null or not await _版式齐(窗):
		_收尾()
		return
	_查(窗.visible, "收到 `1289:1` 却没把窗显出来（原版 `onShowFudaiInfo` 里 reverseDisplay + setData）")
	_查(窗.size == Vector2(274, 306), "窗尺寸 %s ≠ 274×306" % str(窗.size))
	_查(窗.position == Vector2(343, 127), "新窗没摆到舞台正中 %s ≠ (343,127)（960×560 下 `setLocationCenter`）" % str(窗.position))
	_查((窗.get_node("标题") as Label).text == 标题字,
			"标题不是物品名「%s」（实得「%s」）" % [标题字, (窗.get_node("标题") as Label).text])
	_查(not _钮(窗, "开始").disabled, "state=1 时「开始」该可点")
	_查(_钮(窗, "领奖").disabled, "state=1（还没落点）时「领奖」该禁用")
	_查(_id(窗, "奖品格") == "", "刚开窗（gained=`-`）奖品格就该是空的")
	for 序 in 16:
		_查(_id(窗, "格_%d" % 序) == str((候选[序] as Dictionary).get("id", "")),
				"环上第 %d 格没填上服务端候选那件（格=%s 帧=%s）"
					% [序, _id(窗, "格_%d" % 序), str((候选[序] as Dictionary).get("id", ""))])

	# ══ L2 「开始」→ 落点帧 → 跑马灯走完 → 奖品格 = 候选[index] ══
	# ⚠ `await` 的优先级低于 `<`，直接写 `if await _落定(...) < 0` 会先把 `< 0` 交给 await ⇒ 一律先落到变量。
	var 首落 := await _落定(窗, 候选)
	if 首落 < 0:
		_收尾()
		return
	var 奖品id := _id(窗, "奖品格")

	# ══ L3 事务活着时再点福袋 ⇒ 服务端不重复扣件、只重推 state=2 + gained ══
	# ⚠ 重取格位：`--items` 那 2 枚与建角自带那 1 枚**是否叠在同一格**由服务端堆叠规则决定，
	#   L1 若把整摞扣空（`removed=True` → `_send_inventory_clear`）这一格就没件了 ⇒ 客户端
	#   `_开福袋` 见空格直接 return、连请求都不发（看着像"重推没生效"）。服务端在
	#   `transaction != null` 那一支**压根不看 fields[1]**（`:31908-31910`），所以换到还剩福袋的
	#   任意一格点的都是同一条活事务。
	var 袋前 := _数(福袋)
	格位 = _格位()
	_查(格位 > 0, "L3 前权威背包里已经没有福袋了（应剩 %d 枚）—— 后面钉不了重推" % 袋前)
	if 格位 <= 0:
		_收尾()
		return
	_帧.clear()
	_场.call("_use_item", 格位)
	if not await _等(func() -> bool: return _帧.size() >= 1, 6000):
		_查(false, "第二次点福袋没重推状态帧（服务端那段该走 `transaction != null` ⇒ 直接 `_send_fudai_state`）")
	else:
		var 重: Dictionary = _帧[0]
		_查(int(重.get("state", -1)) == 2,
				"已有落点时重推该是 state=2（`_send_fudai_state` 里 selected>=0），实得 %s" % str(重))
		var 已: Dictionary = 重.get("gained", {}) as Dictionary
		_查(not 已.is_empty(), "state=2 那一条该把已中选的那件塞进 gained（`selected>=0` 分支），实得 %s" % str(重))
		_查(str(已.get("id", "")) == 奖品id, "重推的 gained 和屏幕上奖品格不是同一件（帧=%s 屏=%s）"
				% [str(已.get("id", "")), 奖品id])
		_查(_数(福袋) == 袋前,
				"重复点同一格被服务端**又扣了一枚**（%d→%d；扣件只在 `if transaction is None` 那一支）"
					% [袋前, _数(福袋)])
		_查(_窗() == 窗, "重推帧把窗**重建**了（原版守卫看 `_windowMap`，在台上就只 setData）")
		_查(not _钮(窗, "领奖").disabled, "重推 state=2 后「领奖」该开（`setBtnEnabled` 的 2 那一档）")
	# L3 那次重推把 gained 填进了奖品格 ⇒ 下一轮 `_落定` 的"奖品格从空跑到非空"才成立
	_查(_id(窗, "奖品格") == 奖品id, "L3 重推的 gained 没被抄进奖品格（屏上 %s）" % _id(窗, "奖品格"))

	# ══ L4 领奖轮：每轮钉「发那一件 + 扣下一枚 + 连开帧」，空了就钉「链尾帧」═══
	var 轮 := 0
	var 到尾 := false
	var 清过 := false
	var 留过 := false
	while 轮 < 最多轮 and not 到尾:
		轮 += 1
		var 在手 := _数(福袋)		# 本轮领奖前服务端手里还剩几枚 ⇒ 决定连开还是链尾
		var 镜像前 := 镜像件数(福袋号)
		_查(镜像前 == 在手, "第 %d 轮领奖前客户端镜像和权威背包对不上（镜像 %d、权威 %d）" % [轮, 镜像前, 在手])
		_查(_id(窗, "奖品格") != "", "第 %d 轮领奖前奖品格是空的（落点没落上件）" % 轮)
		var 应得前 := _数(int(奖品id))
		var 基 := _帧.size()			# ⚠ 必须在点击**之前**取：发奖/扣件/状态帧是同一次 handler
		var 屏前 := _id(窗, "奖品格")	#    连着写进 socket 的，客户端一 poll 就全进来
		_钮(窗, "领奖").pressed.emit()
		# `onClickTakeBtn:299-306`：`isBagExistItem(currItemID)` 用**客户端镜像**判 ⇒
		#   >0 ⇒ `cleanAwardData()` 清奖品格；==0 ⇒ 只关钮、图标留着。
		if 在手 > 0:
			_查(_id(窗, "奖品格") == "",
					"第 %d 轮领奖时包里还有 %d 枚同种福袋，奖品格却留着 %s（`isBagExistItem>0` 该清）"
						% [轮, 在手, _id(窗, "奖品格")])
			清过 = true
		else:
			_查(_id(窗, "奖品格") == 屏前,
					"福袋领完了却把奖品格清空了（原版 `isBagExistItem==0` 那支只关钮，图标留着）")
			留过 = true
		if not await _等(func() -> bool: return _数(int(奖品id)) >= 应得前 + 1, 8000):
			_查(false, "第 %d 轮领奖后服务端没把奖品格那件（%s）发进包（action 3 → `_add_inventory_item`）"
					% [轮, 奖品id])
			break
		if not await _等(func() -> bool: return _帧.size() > 基, 8000):
			_查(false, "第 %d 轮领奖后服务端没推后续状态帧（应要么连开 `1289:1:1` 要么链尾 `1289:1:0:-:-:1`）" % 轮)
			break
		var 帧: Dictionary = _帧[基]
		var 新候选: Array = 帧.get("candidates", []) as Array
		if 在手 > 0:
			_连开 += 1
			_查(_数(福袋) == 在手 - 1,
					"第 %d 轮领奖后服务端没扣掉下一枚福袋（权威 %d，应 %d）—— `:31958` 那段" % [轮, _数(福袋), 在手 - 1])
			_查(int(帧.get("action", 0)) == 1 and int(帧.get("state", -1)) == 1 and 新候选.size() == 16
					and (帧.get("gained", {}) as Dictionary).is_empty(),
					"连开帧应是 action=1/state=1/16 候选/gained `-`，实得 %s" % _缩(帧))
			_查(_窗() == 窗, "连开帧把窗重建了（服务端自己推的帧也走 `if(!content.successWindow)` 守卫）")
			_查(not _钮(窗, "开始").disabled, "连开（state=1）后「开始」该回可点")
			_查(_id(窗, "奖品格") == "", "连开帧 gained=`-` ⇒ 奖品格该留着空")
			var 落下 := await _落定(窗, 新候选)
			if 落下 < 0:
				break
			奖品id = _id(窗, "奖品格")
			continue
		# —— 链尾：`1289:1:0:-:-:1` ——
		# 原版 `setData:252` 是 `if(param1) setBtnEnabled(param1)` ⇒ state=0 那一帧**不调**三态闸：
		# 两枚钮留在上一档（开始被 state=2 关掉、领奖被 `_点领奖` 关掉），窗也不关、环也不清。
		_查(_数(福袋) == 0, "链尾那一轮领奖后权威背包还剩 %d 枚福袋" % _数(福袋))
		_查(int(帧.get("action", 0)) == 1 and int(帧.get("state", -1)) == 0
				and (帧.get("gained", {}) as Dictionary).is_empty()
				and 新候选.is_empty() and int(帧.get("type", -1)) == 1,
				"链尾帧该是 action=1/state=0/gained `-`/候选 `-`/类型 1，实得 %s" % _缩(帧))
		_查(_窗() == 窗, "链尾帧把窗关了/重建了（原版 state=0 只是不刷钮，不关窗）")
		_查(_钮(窗, "开始").disabled and _钮(窗, "领奖").disabled,
				"链尾（state=0）后两枚钮没留在上一档（开始=%s 领奖=%s）"
					% [_钮(窗, "开始").disabled, _钮(窗, "领奖").disabled])
		var 留 := 0
		for 序 in 16:
			if _id(窗, "格_%d" % 序) != "":
				留 += 1
		_查(留 == 16, "链尾帧候选是 `-` ⇒ 环上该**留着**上一批 16 格（`设数据` 那段 mini(0) 不覆盖），实留 %d" % 留)
		到尾 = true

	_查(_连开 >= 1 and 到尾, "整条链里该既有连开（source_slot / 扫背包两支）又有链尾，实测连开 %d 轮、到尾 %s"
			% [_连开, 到尾])
	_查(清过 and 留过, "`isBagExistItem` 两条分支都该踩到（清奖品格 / 留图标），实测清=%s 留=%s" % [清过, 留过])

	# ══ L5 事务空了还硬发一条 `1286 "2"` ⇒ 服务端 `return`、客户端不许自己演 ══
	if 到尾:
		_帧.clear()
		_场.call("_福袋发开始")
		await create_timer(1.5).timeout
		_查(_帧.is_empty(), "服务端事务为空时却回了帧（`:31925` 那段该直接 return）：%s" % str(_帧))
		_查(奖品id == _id(窗, "奖品格"), "没落点帧，客户端却自己动了奖品格/跑马灯（自造结果）")

	_查(_数(福袋) == 0, "整条链跑完权威背包里还留着 %d 枚福袋" % _数(福袋))
	_查(轮 >= 1, "一轮领奖都没跑起来")
	_收尾()


## 一次「开始 → 落点帧 → 跑马灯走完」，L2 和每轮连开之后都走这里。
## 返回落点 index；-1 = 没等到（已经红过，调用方直接收摊）。
func _落定(窗: Control, 候选: Array) -> int:
	var 基 := _帧.size()
	_钮(窗, "开始").pressed.emit()
	if not await _等(func() -> bool: return _帧.size() > 基, 8000):
		_查(false, "点「开始」后服务端没回落点帧（`1286 \"2\"` → `1289:2:2:<index>` 这一环断了）")
		return -1
	var 落: Dictionary = _帧[基]
	var index := int(落.get("index", -1))
	_查(int(落.get("action", 0)) == 2 and int(落.get("state", -1)) == 2,
			"落点帧应是 action=2/state=2，实得 %s" % _缩(落))
	_查(index >= 0 and index < 16, "服务端落点越界：%d" % index)
	_查(_钮(窗, "开始").disabled, "`1289:2`（state=2）后「开始」该禁用（`setBtnEnabled:328-333`）")
	if index < 0 or index >= 16:
		return -1
	if not await _等(func() -> bool: return _id(窗, "奖品格") != "", 8000):
		_查(false, "跑马灯没走完/奖品格没落上件（8s 超时）—— 真 Timer 那一拍没跑起来，或 `_奖品落定` 没调到")
		return -1
	var 奖品 := _id(窗, "奖品格")
	_查(奖品 == str((候选[index] as Dictionary).get("id", "")),
			"奖品格落的是 %s，服务端 index %d 那格却是 %s —— 抄错格（`setAwardData:386-390`）"
				% [奖品, index, str((候选[index] as Dictionary).get("id", ""))])
	_查(not _钮(窗, "领奖").disabled, "跑马灯走完「领奖」该开（`enterFrame:414` 那句）")
	var 亮 := 0
	var 停在 := -1
	for 序 in 16:
		var 环 := (_钮(窗, "格_%d" % 序) as Control).get_node_or_null("选中") as Control
		if 环 != null and 环.visible:
			亮 += 1
			停在 = 序
	_查(亮 == 1 and 停在 == index, "跑完该只有第 %d 格亮着黄框（实亮 %d 格、停在 %d）" % [index, 亮, 停在])
	return index


## 帧字典直接 `str()` 出来一条 16 格候选就是十几 KB，日志里没法读 ⇒ 只留判据要的字段。
func _缩(帧: Dictionary) -> String:
	return "action=%s state=%s 候选%d件 gained=%s type=%s index=%s" % [
		str(帧.get("action", "?")), str(帧.get("state", "?")),
		(帧.get("candidates", []) as Array).size(),
		"-" if (帧.get("gained", {}) as Dictionary).is_empty() else str(帧.get("gained", {}).get("id", "?")),
		str(帧.get("type", "?")), str(帧.get("index", "-"))]


## 环上的格 / 两枚钮都按**节点名**取。`_格们` 是 `Array[Button]`，跨脚本 `get()` 出来当
## untyped Array 用有类型摩擦 ⇒ 一律走 `get_node_or_null`，同名即同物（`福袋窗._建件`）。
func _钮(窗: Control, 名: String) -> Button:
	return 窗.get_node_or_null(名) as Button


func _id(窗: Control, 名: String) -> String:
	var 格 := _钮(窗, 名)
	if 格 == null:
		return "<无此格>"
	return str(格.get("物品id"))


func _窗() -> Control:
	if _场 == null:
		return null
	var 遮罩 := _场.get("_overlay") as Control
	if 遮罩 == null:
		return null
	var 窗 := 遮罩.get_node_or_null("福袋窗") as Control
	if 窗 != null and 窗.is_queued_for_deletion():
		return null
	return 窗


## 窗是**回帧**开的，所以要等帧到齐再取；等不到就红并说清是没开出来。
func _等窗() -> Control:
	if await _等(func() -> bool: return _窗() != null, 6000):
		return _窗()
	_红("`1289:1:1` 到了却没把福袋窗开出来（`功能窗口._收到福袋帧` 那条链没接上）")
	return null


## 版式节点齐不齐 —— 缺任一枚就红并**退出这条门**，别让后面几十条判据全撞在 null 上
## （崩而不红比红难查，§3.76）。
func _版式齐(窗: Control) -> bool:
	var 缺: Array[String] = []
	for 名 in ["开始", "领奖", "奖品格", "标题"]:
		if 窗.get_node_or_null(名) == null:
			缺.append(名)
	for 序 in 16:
		if _钮(窗, "格_%d" % 序) == null:
			缺.append("格_%d" % 序)
	_查(缺.is_empty(), "福袋窗上节点名不齐（版式被改过）：缺 %s" % str(缺))
	return 缺.is_empty()


func _收帧(状态: Dictionary) -> void:
	_帧.append(状态)


func _进图好了() -> bool:
	return bool(_后端.in_game) and not _镜像().is_empty()


func _种子好了() -> bool:
	return _数(福袋) >= 夹具发 + 建角自带


func _镜像() -> Array:
	return _后端.authoritative_inventory as Array


## 权威镜像里这件的件数。⚠️ 协议解出来 `id` 是**字符串**（`_parse_item_entry`），
## 别的入口可能是 int ⇒ 一律 `str()` + `int()` 归一再比。
func _数(号: int) -> int:
	var 总 := 0
	for 条v in _镜像():
		if 条v is Dictionary and int(str((条v as Dictionary).get("id", 0))) == 号:
			总 += int((条v as Dictionary).get("quantity", 0))
	return 总


## 客户端那一份镜像的同种件数（`游戏会话.背包同名件数` 收 **String**，别递 int —— `String(int)`
## 在 GDScript 4 是非法构造，#74 那轮在 `游戏数据.福袋类型` 上就栽过一次）。
func 镜像件数(号: String) -> int:
	return int(_会话.call("背包同名件数", 号))


func _格位() -> int:
	for 条v in _镜像():
		if 条v is Dictionary and int(str((条v as Dictionary).get("id", 0))) == 福袋:
			var 格 := int((条v as Dictionary).get("slot_index", 0))
			if 格 > 0:
				return 格
	return 0


func _报种子() -> void:
	_红(("夹具没发够福袋：权威镜像里 15008001 只有 %d 枚（要 %d = 夹具 %d + 建角自带 %d，" +
			"`--items 15008001:2` 那一条；现有镜像 %d 格）")
			% [_数(福袋), 夹具发 + 建角自带, 夹具发, 建角自带, _镜像().size()])


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
	if _后端 != null and is_instance_valid(_后端) \
			and bool(_后端.is_connected("fudai_state_received", _收帧)):
		_后端.disconnect("fudai_state_received", _收帧)
	if _场 != null and is_instance_valid(_场):
		var 窗 := _窗()
		if 窗 != null:
			窗.call("隐藏")
		_场.queue_free()
		_场 = null
	if _原端口 >= 0 and _会话 != null:
		(_会话.get("game_settings") as Dictionary)["backend_port"] = _原端口
		_原端口 = -1
	if _后端 != null:
		_后端.call("disconnect_backend")
	if _红数 == 0:
		print("成就福袋在线回归测试：通过（action1 扣件并开帧 / 16 候选不放回且客户端全认得 / "
				+ "落点帧定奖品格与黄框 / 重复点不重复扣件 / 连开 %d 轮各发一件并复用同一枚窗 / " % _连开
				+ "链尾 state=0 留档不清屏 / isBagExistItem 两支都踩到 / 空事务硬发 1286:2 服务端沉默）")
		quit(0)
	else:
		print("成就福袋在线回归测试：失败 %d 项" % _红数)
		quit(1)
