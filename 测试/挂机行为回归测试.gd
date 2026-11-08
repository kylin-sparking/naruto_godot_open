extends SceneTree
## 挂机（智能托管）**行为**回归门 —— 判的是 `脚本/角色/挂机托管.gd` 这个循环本身，
## 不是页面长什么样（那是 `挂机窗回归测试.gd` 的活）。
##
## 为什么要单开一条：10-18 之前全工程**没有任何判据调过这套循环**（`grep _run_auto_combat`
## 只有页面门里的源码文本匹配）⇒ 循环怎么跑都没人管，页面门全绿也照不出来。
##
## 口径：
##   * 地图与人物用**烘焙场景**（与实机同一条 `playable_scene_path`），不是手搭的空壳；
##   * 驱动靠**直接调 `拍(毫秒)`**（`玩家.set_physics_process(false)` 关掉引擎那份），
##     这样"每 4/8/16 帧""预热 800ms"这类判据才不随帧率漂（旧坑：抛物线判据随负载 4.45→7.96）；
##   * 进/出门按字节快照 `user://玩家数据.json`（离线门写 user:// 会让邻居门次日假红）。
##
## 运行：Godot --headless --path . --script res://测试/挂机行为回归测试.gd

const 地图路 := "res://场景/生成/地图_101010000_烘焙.tscn"
## ⚠ 会话写盘是**两份**（`游戏会话.gd:2999` 玩家设置.json + `:3026` 玩家数据.json），
## 而这两份与另一份同名工程**共用同一个 user://** ⇒ 只快照一份就是另一份任由它带着
## 本门的临时值过夜（10-19 就是 `backend_port` 留在 玩家设置.json 里，用户客户端明天连不到他那台）。
const 存档路 := "user://玩家数据.json"
const 设置路 := "user://玩家设置.json"

var _红: Array[String] = []
var _判数 := 0
var _会话: Node = null
var _后端: Node = null		# PVP 还原那三条 case 闸要读队伍/家族摘要
var _玩家: Node = null
var _托管: Node = null
var _存档前 := {}				# 两份 user:// 文件各自的原字节（见上面 存档路/设置路 的注）


func _initialize() -> void:
	call_deferred("_跑")


func _判(条件: bool, 说明: String) -> void:
	_判数 += 1
	if not 条件:
		_红.append(说明)


func _等帧(帧数: int) -> void:
	for _序 in maxi(1, 帧数):
		await process_frame


func _快照() -> Dictionary:
	## 一份文件对应一段原字节；文件不存在 ⇒ 空字节，还原时**删掉**本门新建出来的那份
	## （不许把"上一份工程本来没有这个文件"变成"有了"）。
	var 出 := {}
	for 路 in [存档路, 设置路]:
		出[路] = FileAccess.get_file_as_bytes(路) if FileAccess.file_exists(路) else PackedByteArray()
	return 出


func _还原(快照: Dictionary) -> void:
	for 路 in 快照:
		var 字节: PackedByteArray = 快照[路]
		if 字节.is_empty():
			if FileAccess.file_exists(路):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(路))
			continue
		var f := FileAccess.open(路, FileAccess.WRITE)
		if f != null:
			f.store_buffer(字节)
			f.close()


## ⚠ GDScript **没有** try/except ⇒ 这条协程里任何一行运行期报错都会**静默终止整道门**，
## 后面的 `_收尾()/quit()` 永远跑不到：进程挂着不出声，看日志像"量具坏了"（10-18 那次
## 就是 `root.get_first_node_in_group` —— Window 没这个方法）。所以：
##   ① 每一步都先 `_判` 再往下走，取不到节点就 return（return 前一定 `_收尾()`）；
##   ② 跑批侧必须把**超时**算成"挂"，不许当"没跑到所以不算红"（`开发工具/跑全部离线门.py`）。
func _跑() -> void:
	_存档前 = _快照()
	root.size = Vector2i(960, 560)			# 无头视口默认 64×64，先钉成设计尺寸（契约门同一条坑）
	await _等帧(1)
	var 包 := load(地图路) as PackedScene
	if 包 == null:
		_红.append("地图烘焙场景加载失败：%s" % 地图路)
		_收尾()
		return
	var 图 := 包.instantiate()
	root.add_child(图)
	current_scene = 图						# ⚠ 契约门建场景时也设了这个；不设的话后面等帧会停
	_会话 = root.get_node_or_null("GameSession")
	_后端 = root.get_node_or_null("BackendConnection")
	## ⚠ 别在 `root`（它是 `Window`）上调 `get_first_node_in_group` —— Window 的绑定里没有这个方法，
	## 报 `Nonexistent function` 之后**整条协程当场死**，后面的 `_收尾()/quit()` 永远跑不到 ⇒
	## 表现是"地图加载完就没声音、进程挂到超时"，看着像量具坏了，其实是这一行（10-18 实测）。
	## 玩家是进图之后**异步**建出来的（`LifeRoot` 那一支），固定等 10 帧会**偶发取不到**
	## —— 10-18 变异实测里就撞上一次"会话/玩家没建出来"，那条红与变异无关，是量具自己不稳。
	## 改成有界轮询：最多等 240 帧，取到就走。
	for _次 in 240:
		var 家: Array = get_nodes_in_group("player")
		if not 家.is_empty():
			_玩家 = 家[0]
			break
		await _等帧(1)
	_判(_会话 != null and _玩家 != null, "会话/玩家没建出来（等了 240 帧）")
	if _会话 == null or _玩家 == null:
		_收尾()
		return
	_托管 = _玩家.get_node_or_null("挂机托管")
	_判(_托管 != null, "玩家下没有 挂机托管 子节点（循环实现体没挂上）")
	if _托管 == null:
		_收尾()
		return
	_玩家.set_physics_process(false)			# 由本门按拍驱动，避免引擎那份重复 tick
	## ⚠ 关掉引擎那份 tick 之后，`current_fh_id` 这一格就再也没人写了（只有 `_physics_process`
	## 的落地判定写它）⇒ 先按**地图自己的查询**把角色落到脚点上，细节见 `落到脚点()`。
	_判(落到脚点(), "夹具：角色要能落到一条脚点上（`current_fh_id` 空 ⇒ `走向()` 恒发不出路线、"
			+ "`_能放招()` 恒假，一整族判据会变成与代码无关的红；实得 fh=%s on_ground=%s）"
			% [str(_玩家.get("current_fh_id")), str(_玩家.get("on_ground"))])
	_喂配置()
	## 每一步都打一行 + **每段必须判满预定的条数**：GDScript 没有 try/except，段中间任何一行
	## 运行期报错都会把那条协程**当场打断**，而 `_跑` 照样往下走、末行照打「通过」
	## （10-19 实测两次：午④⑤ 整段没跑，门打的还是「通过（192 条判据）」）。
	## "完成"那句不算证据，**判据条数**才算 ⇒ 条数不够就红。
	## ⚠ 别把这些收进一个数组循环 —— GDScript 里 `f()` 会**立刻跑到第一个 await** 才返回，
	## 数组字面量会把十几段全部启动、彼此交错。
	await _段("甲 开挂与特效", 1, _甲_开挂与特效)
	await _段("乙 预热与活动区", 1, _乙_预热与活动区)
	await _段("乙丙 置挂机态四条闸", 1, _乙丙_置挂机态四条闸)
	await _段("丙 停挂机三条", 1, _丙_停挂机三条)
	await _段("丁 挑怪谓词", 1, _丁_挑怪谓词)
	await _段("戊 拾取分类", 1, _戊_拾取分类)
	await _段("己 嗑药", 1, _己_嗑药)
	await _段("庚 辅助与升级", 1, _庚_辅助与升级)
	await _段("辛 挑怪次序", 1, _辛_挑怪次序)
	await _段("壬 拾取路线", 1, _壬_拾取路线)
	await _段("癸 嗑药闸", 1, _癸_嗑药闸)
	await _段("子 双倍药", 1, _子_双倍药)
	await _段("丑 辅助排程", 1, _丑_辅助排程)
	await _段("寅 自动升级", 1, _寅_自动升级)
	await _段("卯 卖装闸", 1, _卯_卖装闸)
	await _段("辰 上行只发一次", 1, _辰_上行只发一次)
	await _段("巳 宠招", 1, _巳_宠招)
	await _段("午 追打与换目标", 1, _午_追打与换目标)
	if _托管 == null:
		_收尾()
		return
	await _段("午乙 追按下回退普攻", 1, _午乙_追按下回退普攻)
	if _托管 == null:
		_收尾()
		return
	await _段("申 锁定怪头顶箭头", 1, _申_锁定怪头顶箭头)
	if _托管 == null:
		_收尾()
		return
	await _段("酉 掐路线与爬梯豁免", 1, _酉_爬绳不被抢路线)
	if _托管 == null:
		_收尾()
		return
	await _段("未 换图关挂机", 1, _未_换图关挂机)
	if _托管 == null:
		_收尾()
		return
	await _段("戌 赶路途中不重排", 1, _戌_赶路途中不重排)
	if _托管 == null:
		_收尾()
		return
	await _段("亥 两份挑怪谓词", 1, _亥_两份谓词)
	await _段("跨层 不锁上层怪", 12, _跨层_不锁上层怪)
	_收尾()


## 跑一段并钉住"这段真的判满了 N 条"。条数不够 ⇒ 中间有运行期报错把协程打断了。
## 末行会把实得条数打出来，改完判据要**重新核一遍这些下限**（下限只许比实得小）。
func _段(名: String, 最少: int, 协程: Callable) -> void:
	var 前 := _判数
	prints("行为门：进入 " + 名)
	await 协程.call()
	var 得: int = _判数 - 前
	_判(得 >= 最少, "%s：这段应至少判 %d 条，实得 %d ⇒ 中间有运行期报错把协程打断了" % [名, 最少, 得])
	prints("行为门：完成 %s（判 %d 条）" % [名, 得])


## 原版出厂值 + 把"当前这份"直接写进 `挂机配置`（模块的 `设()` 读的就是它）。
func _喂配置() -> void:
	var 配 := {
		"autoReplyHp": true, "autoReplyMp": true,
		"auotReplyHpValue": 70, "auotReplyMpValue": 50,
		"auotReplyHpType": 0, "auotReplyMpType": 0,
		"autoBattleRange": 20, "autoBattleTime": 240, "unlimitedAutoBattleTime": false,
		"autoAvoidBoss": false, "autoReply": false, "autoDaZuo": true,
		"autoCollect": true, "isCollectQuestion": true, "isCollectDrug": true,
		"isCollectMoney": true, "isCollectCaiLiao": true, "isCollectOthers": true,
		"autoSkillId": 0, "autoChongwuSkillId": 101,
		"autoWulinEffect": false, "autoZhanYiEffect": false, "autoShouhu": false,
		"autoZaiSheng": false, "autoZhangXian": false, "autoUpgradeSkill": false,
		"autoUseEpDrug": false, "autoUseZhenQiDrug": false, "autoUseChongWuEpDrug": false,
		"collectProfession": 0, "collectLevel": 0, "collectQuality": 0,
		"autoChongWuEat": false, "autoSellPickedEquip": false,
	}
	_会话.套用挂机配置(配)
	for 键名 in 配:
		_会话.挂机配置[键名] = 配[键名]


func _改配置(键: String, 值) -> void:
	_会话.挂机配置[键] = 值
	_会话.game_settings[键] = 值
	## ⚠ 模块在"开挂机那一刻"把配置快照进 `_配置缓存`；门中途改配置必须手动刷新，
	## 否则判的是上一套值（这一族最容易造出"改坏了也不红"的假绿）。
	_托管._配置缓存 = _托管.读配置快照()


## ── "读源码文本"那一族判据的共用前处理：**先把注释剥掉再匹配** ──────────
## 为什么必须剥（10-19 实测红出来的）：删掉一支自造代码时，**说明注释里把被删掉的那句原话
## 抄了一遍**（`玩家.gd:1259` 那句"上一版这里用 `auto_combat_active` 挡在外面"），
## 于是"分派链里不许再有 `elif auto_combat_active`"这条判到的是注释 ⇒ **代码已经改对、
## 判据照样红**；反过来更糟：一支真被禁的东西如果只写在注释里，判据也分不清。
## 剥法：逐行扫，第一个"不在双引号里"的 `#` 之后整段丢掉；只剩空白的行丢掉。
## ⚠ 已知限度：不认三引号/转义引号里的 `#`（本工程 .gd 里没有这种写法）。
##   ⇒ 所以每条文本判据都各带**两条量具自检**：同一句插到非注释处必须查得到、
##     只写在注释里必须查不到 —— 否则"没查到"可能是剥注释把代码也剥没了。
func 剥注释(源: String) -> String:
	var 出 := PackedStringArray()
	for 行 in 源.split("\n"):
		var 在引号 := false
		var 切 := -1
		var 位 := 0
		var 长 := 行.length()
		while 位 < 长:
			var 字 := 行[位]
			if 字 == "\"":
				在引号 = not 在引号
			elif 字 == "#" and not 在引号:
				切 = 位
				break
			位 += 1
		var 段: String = 行 if 切 < 0 else 行.substr(0, 切)
		段 = 段.strip_edges()
		if 段.is_empty():
			continue
		出.append(段)
	return "\n".join(出)


## 在**已经剥掉注释**的源码里查一句话。
func 源码含(源: String, 串: String) -> bool:
	return 剥注释(源).contains(串)


## ── 甲：开挂机后的三件（在跑 / 特效 / PVP 切 1）────────────────────────
func _甲_开挂与特效() -> void:
	_会话.hud_state["pk_mode"] = 3			# 先摆一个"家族模式"，看开挂机有没有强制切 1
	var 开前: Vector2 = _玩家.position
	_重开()
	await _等帧(2)
	_判(bool(_托管.在跑), "点开始后 在跑 应为真")
	## ⚠ 找那枚特效一律走**模块自己的引用** `_托管._特效`，不按节点名找：
	## 同层里已有同名兄弟时 `add_child` 会把后挂进去的那个改名（实测第二枚叫 `@Node2D@115`），
	## 按名字找就成了"只找得到第一枚" ⇒ 换图那一段的判据会永远看到旧的（10-19 变异实测漏抓）。
	var 特效 = _托管.get("_特效") as Node
	_判(特效 != null and (特效 as CanvasItem).visible,
			"开挂机后要有『挂机中』特效，而且真的挂上去（原版 `:1074-1081`）")
	_判(特效 != null and 特效.get_parent() != null and 特效.get_parent().is_in_group("game_hud"),
			"那枚特效必须挂在**屏幕层**（HUD 那枚 CanvasLayer）下；实得父节点 %s（挂在玩家/世界里它就会跟着角色跑）"
			% str(特效.get_parent() if 特效 != null else null))
	_判(int(_会话.hud_state.get("pk_mode", 0)) == 1,
			"开挂机要强制切到普通模式 1（原版 `:1041-1049`；实得 %s）" % str(_会话.hud_state.get("pk_mode")))
	## 屏幕层那一枚的**屏幕位**不随角色走（挂进世界就会跟着跑），而且每一拍钉回
	## `(视口宽/2, 110)` —— 那就是原版 `resize():1094-1101` 重摆的等价物。
	if 特效 != null:
		var 屏前: Vector2 = (特效 as Node2D).global_position
		_玩家.position += Vector2(200.0, 0.0)
		_托管.拍(16.7)
		_判((特效 as Node2D).global_position.distance_to(屏前) < 0.01,
				"角色走开 200 像素后『挂机中』的屏幕位不许动（挂在世界里就会跟着跑；实得 %s）"
				% str((特效 as Node2D).global_position))
		var 宽 := float((特效 as CanvasItem).get_viewport_rect().size.x)
		(特效 as Node2D).position = Vector2(13.0, 77.0)		# 假装窗口刚被拉宽
		_托管.拍(16.7)
		_判(absf((特效 as Node2D).position.x - 宽 / 2.0) < 0.6
				and absf((特效 as Node2D).position.y - 110.0) < 0.6,
				"每一拍要把它钉回 (视口宽/2, 110)（原版 `resize()` 那条重摆；实得 %s / 宽 %s）"
				% [str((特效 as Node2D).position), str(宽)])

	## ── ⑦ 坐着点「开始挂机」⇒ 要先起身 ────────────────────────────────
	## 原版 `GuajiHandler.as:1043` 开挂那一支调的是 `TargetHandler.stopEverything()`，
	## 而那里面 `:503` 是 `stopPathFind()`、`:504-507` 紧跟
	## `if (player.movementAction == MovementAction.SIT0) HealHandler.getInstance().requestHealStop();`
	## ⇒ **坐着挂上机人 Must 站起来**，否则 `:729` 那块虽然认 SIT0 是"空档"，`moveToAttack` 里
	## 那一句（`SkillExecute.as:158-161` `if (API.healHandler.nowInHeal) requestHealStop();`）
	## 只在**有追打目标**时才跑到 ⇒ 一直坐着不出手。
	_重开()
	_玩家.set("is_practising", true)
	_重开()
	_判(not bool(_玩家.get("is_practising")),
			"开着挂机的途中被摆成打坐、再点一次『开始挂机』要起身（原版 stopEverything:504-507；实得 打坐=%s）"
			% str(_玩家.get("is_practising")))
	## 反面（阳性对照的另一侧）：**停挂机**那一支走的是 `TargetHandler.clear():462-469`
	## （`GuajiHandler.as:1064` 调的是 clear，不是 stopEverything），里面**没有** requestHealStop
	## ⇒ 停挂机不许把人顶起来。把这一句补到停的那一支，本条就红。
	_玩家.set("is_practising", true)
	_会话.request_hang(false)
	_判(bool(_玩家.get("is_practising")),
			"停挂机那一支**不许**停打坐（原版 clear():462-469 里没有这一句；实得 打坐=%s）"
			% str(_玩家.get("is_practising")))
	_玩家.call("set_practising", false)


## ── 乙丙：`置挂机态()` 的"已经在挂又收到 true"那一支（`:1088-1091`）──
## 原版 `set isStart` 结尾那句 `if (value) this.setConfig();` 排在
## `if (this._isStart != value) { … }` 那块**外面** ⇒ 同状态的第二次 `true` 不开/不关任何东西，
## 但**配置照样整份重跑**（`Client.as:7180-7190 onCharConfig()` 结尾也是无条件调 setConfig）。
## 而 `setConfig():232-282` 里既不清 `i`(`:122`)、也不清 `pastTime`(`:692` 累加) 与 `pastTime2`(`:66`)。
## 这一段一律**直接调函数**、不走 `拍()` ⇒ 量的是这一支自己，不掺循环那份状态。
func _乙丙_置挂机态四条闸() -> void:
	_重开()
	_托管._防抖剩余 = 0.0					# `:1025-1036` 那一秒防抖排在同状态判断**之前**，先把它排掉
	var 键 := 424242
	_托管.拉黑(键)
	_判(bool(_托管.黑名单里(键)), "乙丙：夹具——这一枚此刻确实在黑名单里（否则下面那条恒真）")
	var 预热前: float = float(_托管._预热过)
	var 计时前: float = float(_托管._计时毫秒)
	var 我位: Vector2 = _玩家.position as Vector2
	var 落地前 = _玩家.get("on_ground")
	_玩家.set("on_ground", true)				# `:239` `landed` ⇒ startPoint 直接取当下点
	_改配置("autoBattleRange", 40)
	_托管.置挂机态(true)						# 已经在挂 + 又收到 true
	_判(not bool(_托管.黑名单里(键)),
			"『已经在挂、再收到 true』也要重跑配置 ⇒ 黑名单被清（原版 `:1088-1091` + `setConfig:235`）")
	_判(_托管._活动区.get_center().distance_to(我位) < 0.5,
			"同一趟还要把锚点重定到脚下并按新格数重摆活动区（`setConfig:239-247`；实得中心 %s / 我 %s）"
			% [str(_托管._活动区.get_center()), str(我位)])
	_判(absf(_托管._活动区.size.x - 2000.0) < 0.5, "重摆用的格数要读**改过之后**的配置（实得 %s）" % str(_托管._活动区.size))
	_判(float(_托管._预热过) == 预热前 and float(_托管._计时毫秒) == 计时前,
			"重跑配置不许清预热(`pastTime2:66`)与时长(`pastTime`)——`setConfig:232-282` 整段都不碰这两个（预热 %s→%s / 时长 %s→%s）"
			% [str(预热前), str(_托管._预热过), str(计时前), str(_托管._计时毫秒)])
	## 反面：停挂机那一支**不**重跑配置（`:1050-1054` 只有 resumePvp + stopHang，
	## `:1059-1068` 清的是 pastTime/justComplete/TargetHandler.clear()）⇒ 黑名单必须还在。
	_托管._防抖剩余 = 0.0
	_托管.拉黑(键)
	_托管.置挂机态(false)
	_判(bool(_托管.黑名单里(键)),
			"停挂机那一支不许重跑配置（原版 setConfig 只在 `if(value)` 那一支；实得 黑名单里有=%s）" % str(bool(_托管.黑名单里(键))))
	## ⑩ `set totalTime:350-353` 就一句 `_totalTime = param1 * 60 * 1000;` —— **没有任何 clamp**。
	_改配置("autoBattleTime", 600)
	_托管._防抖剩余 = 0.0
	_托管.置挂机态(true)
	_判(absf(float(_托管._时长毫秒) - 36000000.0) < 0.5,
			"totalTime 收到 600 分钟就是 600×60×1000 毫秒，**不许**夹到 500（原版 `:350-353`；实得 %s）" % str(_托管._时长毫秒))
	_改配置("autoBattleTime", 240)
	_托管._防抖剩余 = 0.0
	_托管.置挂机态(true)
	_判(absf(float(_托管._时长毫秒) - 14400000.0) < 0.5,
			"乙丙·阳：出厂 240 分钟也按同一条算式（夹过 500 的那份实现这里照样对不上；实得 %s）" % str(_托管._时长毫秒))
	_改配置("autoBattleRange", 20)
	_托管._防抖剩余 = 0.0
	_托管.置挂机态(true)
	_托管._黑名单.clear()
	_玩家.set("on_ground", 落地前)


# ── 乙：预热 800ms 与"矩形活动区锚在开挂那一刻" ───────────────────────
## ⚠ 预热那四条**必须拿一份干净实例判**：原版 `pastTime2`（`:66` 声明、`tick():602-605` 只累加）
## 在 `setConfig():232-282` 与 `isStart` setter 里**都没有清零的那一句** ⇒ 一个客户端生命周期里
## 800ms 只付**一次**（10-19 按此删掉了 `重读配置()` 里自造的 `_预热过 = 0.0`）。
## 本门在 甲 段就已经把这一份的 800ms 付掉了，再拿它判"预热期内一帧都不走"永远是 0 比 0。
func _乙_预热与活动区() -> void:
	var 清: Node = load("res://脚本/角色/挂机托管.gd").new()
	_玩家.add_child(清)
	_判(float(清.get("_预热过")) == 0.0, "乙：夹具——新建实例的预热计时应为 0（实得 %s）" % str(清.get("_预热过")))
	for _i in 10:
		清.call("拍", 16.7)
	_判(int(清.get("_帧")) == 0, "预热 800ms 内一帧都不该走（167ms 时实得 %d；原版 `:602-605`）" % int(清.get("_帧")))
	清.call("拍", 700.0)
	_判(int(清.get("_帧")) == 0, "累计 867ms 仍在预热里（实得 %d）" % int(清.get("_帧")))
	清.call("拍", 16.7)
	_判(int(清.get("_帧")) == 1, "过了 800ms 就该走第一帧（实得 %d）" % int(清.get("_帧")))
	_判(absf(float(清.get("_预热过")) - 867.0) < 0.5,
			"乙：夹具——上面那三拍确实累加到了这份新实例身上（16.7×10 + 700 = 867；第三拍已在阈值之外不再累加，实得 %s）" % str(清.get("_预热过")))
	清.free()
	await _等帧(1)
	## 已经付过 800ms 的这一份：再开一次挂机**不许**再愣 0.8 秒（`_预热过` 不被 `重读配置()` 清零）。
	## ⚠ 10-19 改判据：**开挂那一刻帧计数不该是 0**。原版 `i` 全份只有两处：
	## `:122 private var i:int = 0;`（声明）与 `tick():607 ++this.i;`（自增），
	## 其余 12 处命中全是 `(this.i & 3/7/0x0F) == 0` 这类读；`setConfig():232-282` 那 51 行
	## **一句都不碰 `i`** ⇒ "开挂把 4/8/16 帧节流重新对齐到 0"是我们自己加的，
	## 而且它和本段下面那条"重跑配置**不许**清帧计数"互相矛盾（同一条 `setConfig` 两次判相反）。
	_会话.request_hang(false)
	_托管.拍(1200.0)							# 排掉上一轮那句 1 秒防抖（`_重开()` 的同一件事，
	var 帧基 := int(_托管._帧)					#   只是这里要在开挂**之前**先把帧计数抄下来）
	_会话.request_hang(true)
	_判(bool(_托管.在跑), "乙：夹具——这一跑要真的开着挂（开不起来下面三条全是 0 比 0）")
	_判(float(_托管._预热过) >= 800.0, "重开挂机时预热早该付完了（实得 %s）" % str(_托管._预热过))
	_判(int(_托管._帧) == 帧基,
			"开挂那一句（`isStart(true)` 结尾的 `setConfig()`，`:1088-1091`）**不许**把帧计数归零（帧 %d→%d）" % [帧基, int(_托管._帧)])
	_托管.拍(16.7)
	_判(int(_托管._帧) == 帧基 + 1,
			"第二次开挂不必重走预热 ⇒ 第一拍就要走**一**帧（原版 `pastTime2:66` 全份无清零点；帧 %d→%d）" % [帧基, int(_托管._帧)])
	var 活: Rect2 = _托管._活动区
	_判(absf(活.size.x - 1000.0) < 0.5 and absf(活.size.y - 500.0) < 0.5,
			"20 格的活动区应为 1000×500（宽=格×50、高=一半；实得 %s）" % str(活.size))
	_判(活.get_center().distance_to(_托管._起点) < 0.5, "活动区中心要压在开挂点（实得中心 %s / 起点 %s）" % [str(活.get_center()), str(_托管._起点)])
	var 旧位 := 活.position
	_玩家.position += Vector2(300.0, 0.0)
	_托管.拍(16.7)
	_判(_托管._活动区.position.distance_to(旧位) < 0.5,
			"人走开 300 像素后活动区不许跟着跑（原版锚的是开局点；实得 %s）" % str(_托管._活动区.position))
	_玩家.position -= Vector2(300.0, 0.0)
	## ── 挂着的时候改设置要**立即生效**（原版每一枚勾选都是当场写单例：`percentHP:188`、
	## `set fightArea:557-575`、`set playerSkill:1206`、`set petSkill:1256`）。
	## ⚠ 10-19 改判据：配置回帧**不是**"只换值"，而是**整份重跑** ——
	## `Client.as:7180-7190 onCharConfig()` 的结尾就有一句**无条件**
	## `GuajiHandler.getInstance().setConfig();`，而 `setConfig:239-246` 头一件事是把
	## `startPoint` 重定到**脚下**（`landed` 就取当下点，否则 `getPointOnFootholdBelow`），
	## `:247` 再按新格数重摆 `fightArea` ⇒ 重摆之后矩形中心压的必须是**重跑那一刻的脚下点**，
	## 旧判据钉的"仍压在开挂那一刻的锚点"是自造的（那一句只在 `tick():735-738` 的
	## "开局时人还在空中、落地那一拍才补锚点"里成立，与配置回帧无关）。
	var 帧前 := int(_托管._帧)
	var 预热前: float = float(_托管._预热过)
	var 计时前: float = float(_托管._计时毫秒)
	var 落地前 := bool(_玩家.get("on_ground"))
	_玩家.set("on_ground", true)
	_改配置("autoBattleRange", 40)
	_改配置("autoSkillId", 9029)
	_会话.call("设默认忍术", 777)
	_会话.挂机配置_changed.emit(_会话.挂机配置.duplicate(true))
	_判(absf(_托管._活动区.size.x - 2000.0) < 0.5 and absf(_托管._活动区.size.y - 1000.0) < 0.5,
			"挂着把范围从 20 格改成 40 格 ⇒ 活动区要立刻变 2000×1000（宽=格×50、高=一半；实得 %s）" % str(_托管._活动区.size))
	## 参照值自己按 `setConfig:239-246` 算：`landed=true` ⇒ startPoint == 人此刻的位置。
	var 脚下: Vector2 = _玩家.position as Vector2
	_判(_托管._活动区.get_center().distance_to(脚下) < 0.5,
			"配置回帧之后矩形中心要压在**重跑那一刻的脚下点**（`Client.as:7190` → `setConfig:239-247`；实得中心 %s / 脚下 %s）"
			% [str(_托管._活动区.get_center()), str(脚下)])
	_判(float(_托管._预热过) == 预热前 and float(_托管._计时毫秒) == 计时前,
			"重跑配置**不许**清预热与时长（`setConfig:232-282` 整段都不碰 `pastTime2:66`/`pastTime:692`；预热 %s→%s / 时长 %s→%s）"
			% [str(预热前), str(_托管._预热过), str(计时前), str(_托管._计时毫秒)])
	_判(int(_托管._帧) == 帧前,
			"重跑配置**不许**清帧计数（原版 `i` 只在 `:122` 声明、`tick():607` 只 `++`，setConfig 一句都不碰；帧 %d→%d）" % [帧前, int(_托管._帧)])
	_判(int(_会话.get("默认忍术")) == 9029,
			"挂着改『人物自动使用』也要立刻换招（原版 `set playerSkill` 当场写 defaultSkill；实得 %s）" % str(_会话.get("默认忍术")))
	_改配置("autoBattleRange", 20)
	_改配置("autoSkillId", 0)
	_会话.挂机配置_changed.emit(_会话.挂机配置.duplicate(true))
	_判(absf(_托管._活动区.size.x - 1000.0) < 0.5, "改回 20 格 ⇒ 活动区要跟着缩回 1000 宽（实得 %s）" % str(_托管._活动区.size))
	_玩家.set("on_ground", 落地前)


# ── 丙：停挂机三条（按移动键 / 死亡两分支 / 到点不回城就停）+ PVP 还原 ──
func _丙_停挂机三条() -> void:
	Input.action_press("ui_left")			# 原版 `isDownMoveKey` 里就有左右
	for _i in 3:
		_托管.拍(16.7)
	Input.action_release("ui_left")
	_判(not bool(_托管.在跑), "按着移动键 ⇒ 立刻停挂机（原版 `:665-669`）")
	_判(not bool(_会话.hang_state.get("active", true)), "停挂机要回会话（界面那颗球跟着灭），不能只改本地")
	## 原版停挂机那句是 `setTimeout(API.pvpHandler.resumePvpMode, 300)`（`:1052`）——
	## **300 毫秒之后**才还原，不是立刻。所以这两拍要分开判：先到点前仍是 1，排完倒计时才回 3。
	_判(int(_会话.hud_state.get("pk_mode", 0)) == 1,
			"刚停的那一瞬间 PVP 还不该还原（原版延后 300ms；实得 %s）" % str(_会话.hud_state.get("pk_mode")))
	_判(float(_托管._pvp还原毫秒) > 240.0,
			"停挂机要把还原倒计时摆成 300ms（实得 %s）" % str(_托管._pvp还原毫秒))
	_托管.拍(200.0)
	_判(int(_会话.hud_state.get("pk_mode", 0)) == 1, "200ms 时还没到点，仍不许还原")
	_托管.拍(200.0)
	## ⚠ 这里**不能**直接断言"回到 3"：`resumePvpMode:121-149` 的 3=家族档有一条闸 ——
	## 只有**此刻还在家族里**才还原，否则把记录改成当前档、从此不再还原。本夹具没家族，
	## 所以忠实的结果就是"停在 1"。家族/组队那三条闸单独在 §丙乙 里逐条量。
	_判(int(_会话.hud_state.get("pk_mode", 0)) == 1,
			"没家族的人停挂机 300ms 后**不该**被还原成家族模式（原版 case PVP_FAMILY 那条闸）")
	_判(int(_托管._pvp记) == 1, "放弃还原时要把记录改成当前档（原版 `_lastPvpMode = pvpMode`）")
	_丙乙_PVP还原三条闸()
	var 特效 = _托管.get("_特效") as Node
	_判(特效 == null or not is_instance_valid(特效) or not (特效 as CanvasItem).visible,
			"停挂机后『挂机中』特效要摘掉（原版 `:1083-:1086` removeChild）")

	# 死亡 + 没勾原地复活 ⇒ 停
	_改配置("autoReply", false)
	_重开()
	_等预热带过()
	_会话.player_stats["hp"] = 0
	_托管.拍(16.7)
	_判(not bool(_托管.在跑), "死了又没勾原地复活 ⇒ 停挂机（原版 `:687-689`）")
	_会话.player_stats["hp"] = int(_会话.player_stats.get("max_hp", 100))

	# 死亡 + 勾了原地复活 + 等级 < 31（或背包有复活道具）⇒ 继续挂着等复活
	_改配置("autoReply", true)
	var 级前 = _会话.player_stats.get("level", 0)
	_会话.player_stats["level"] = 30			# 原版 `:157-159` 第一条闸：level < 31 直接算能原地活
	_重开()
	_等预热带过()
	_判(bool(_托管.能原地复活()), "等级 30 < 31 时应满足原版 canOriginLive 的第一条闸（当前等级 %s）" % str(_会话.player_stats.get("level")))
	var 复活前 := bool(_托管.在跑)
	_会话.player_stats["hp"] = 0
	_托管.拍(16.7)
	## ⚠ 等级**要撑过这一条再还原**：上一版在这里先还原成 60，于是 `能原地复活()` 当场变假、
	## 循环自己停了 ⇒ 看着像实现错，其实是夹具把前提撤了。
	_判(复活前 and bool(_托管.在跑), "勾了原地复活且满足闸 ⇒ 不许自己停（原版 `:674-684`）")
	_会话.player_stats["level"] = 级前
	_会话.player_stats["hp"] = int(_会话.player_stats.get("max_hp", 100))

	# 时长到点 + 没勾回城打坐 ⇒ 停；且"没怪就打坐"那条错语义必须不存在
	_改配置("autoDaZuo", false)
	_改配置("autoBattleRange", 1)				# 50 像素的小框：保证里面没怪
	_重开()
	_等预热带过()
	_托管._时长毫秒 = 0.0
	_托管._计时毫秒 = 1.0
	_托管.拍(16.7)
	_判(not bool(_托管.在跑), "时长到点且没勾回城打坐 ⇒ 停（原版 `:702-705`）")
	_判(not bool(_玩家.get("is_practising")), "『回城打坐』不是『没怪就打坐』——停挂机时不许把人摆成打坐")
	_改配置("autoBattleRange", 20)
	_改配置("autoDaZuo", true)
	_丙丙_到点回城两分支()


## ── ⑫ 时长到点那一块按 `:707-:725` 原文重排之后，两块各自都可证伪 ──────────
## 原文形状（**不是** if/else，是**连着的两块**）：
##   `:707` `if (justComplete && [WALK,STAND].indexOf(movementAction) != -1)`
##     `:709` `if (Map.data.id != 100000000)` → `:711` MovePlayerToMap + `:712` _IsgoingHome=true
##                + `:713-716` removeChild(_guaJiTip)
##     `:718` `targetHandler.curTarget = null;`   ← **在 Map 判定之外**：已在村也一样要清
##     `:719` `justComplete = false;`             ← 同上，无条件置回
##   `:721` `if (Map.data.id == 100000000)` → `:723` requestHealStart() + `:724` isStart = false
## 上一版把"已在村 ⇒ 打坐+停"提到最前面并 `return` ⇒ 村子里那一支既不 `curTarget=null`
## 也不把 `justComplete` 置回 ⇒ 蓝色箭头钉在最后那只怪身上、到点检查每拍重跑。
## ⚠ 这一段把 `_托管._会话/_后端` 换成**记录桩**：真会话的 `request_map_change` 会把整张图
##   换掉（后面的段就没有宿主了），而这一支要判的正是"有没有发那一发换图"。
func _丙丙_到点回城两分支() -> void:
	var 实体 = _玩家.get_parent().get_node_or_null("LifeRoot")
	if 实体 == null:
		_判(false, "丙丙：拿不到 LifeRoot，这一段整块没判")
		return
	var 怪群: Array = 实体.call("挂机的全部怪")
	if 怪群.is_empty():
		_判(false, "丙丙：图上要至少有一只怪当『看住的目标』（缺了这一段判不了 ⑫）")
		return
	var 怪: Node2D = 怪群[0] as Node2D
	## 先把状态摆好（`_改配置` 与 `重读配置()` 都要读**真会话**的 `挂机配置`，必须在换桩之前做完）
	_重开()
	_等预热带过()
	_改配置("autoDaZuo", true)
	_玩家.set("on_ground", true)
	_玩家.set("_同步动作", 1)					# `:707` 那块只认 WALK(3)/STAND(1)
	_玩家.set("is_practising", false)
	_托管.重读配置()							# 把 `_在回城`(`:280`) 与 `_刚清完`(`:238`) 摆回出厂
	var 会前 = _托管._会话
	var 后前 = _托管._后端
	var 落地前 = bool(_玩家.get("on_ground"))
	var 假会话 := 记录会话.new()
	var 假后端 := 记录后端.new()
	root.add_child(假会话)
	root.add_child(假后端)
	_托管._会话 = 假会话
	_托管._后端 = 假后端
	## ── A：不在村 ⇒ 传送 + 清看住目标 + justComplete 置回；**不**停挂、**不**打坐
	假会话.current_map_id = "101010000"
	_托管._刚清完 = true
	_托管.摆看住的目标(怪)
	_判(实体.get("_view_target") == 怪, "丙丙：夹具——先要让『看住的目标』真的挂着（否则下面那条恒真）")
	假会话.换图请求.clear()
	_托管.走时长到点()
	_判(假会话.换图请求.size() == 1 and str(假会话.换图请求[0]) == "100000000",
			"不在村 ⇒ 要发那一发回村传送（原版 `:711` MovePlayerToMap(100000000)；实得 %s）" % str(假会话.换图请求))
	_判(实体.get("_view_target") == null,
			"清看住的目标排在 Map 判定**外面**（`:718` 那句 `curTarget=null`）——不在村这一支也要清")
	_判(not bool(_托管._刚清完), "`justComplete` 要置回（`:719`），否则这一整块每拍重跑")
	_判(假会话.停挂次数 == 0 and not bool(_玩家.get("is_practising")),
			"不在村 ⇒ **不许**就地打坐、也**不许**停挂（`:721` 那块没进去；停挂 %d 次 / 打坐 %s）" % [假会话.停挂次数, str(_玩家.get("is_practising"))])
	## ── B：已在村 ⇒ 上面那两句**照做**，然后独立地打坐 + 停挂
	假会话.current_map_id = "100000000"			# 原版 `Map.data.id == 100000000`
	假会话.换图请求.clear()
	_托管._刚清完 = true
	_玩家.set("is_practising", false)
	_托管.摆看住的目标(怪)
	_判(实体.get("_view_target") == 怪, "丙丙：夹具——B 支开跑前看住的目标也要真的挂着")
	_托管.走时长到点()
	_判(假会话.换图请求.is_empty(), "已在村 ⇒ `:709` 那一块整块跳过，不许再发传送（实得 %s）" % str(假会话.换图请求))
	_判(实体.get("_view_target") == null,
			"⑫ 已在村那一支**同样**要清看住的目标（`:718` 在 Map 判定的 if 外面，上一版把它挪进 else 就漏了）")
	_判(not bool(_托管._刚清完), "⑫ 已在村那一支**同样**要把 justComplete 置回（`:719`）")
	_判(bool(_玩家.get("is_practising")) and 假后端.打坐次数 == 1,
			"落回村 ⇒ requestHealStart（`:723`；打坐=%s 上行=%d 次）" % [str(_玩家.get("is_practising")), 假后端.打坐次数])
	_判(假会话.停挂次数 == 1, "落回村 ⇒ isStart = false（`:724`；实停挂 %d 次）" % 假会话.停挂次数)
	_玩家.set("is_practising", false)
	_玩家.set("on_ground", 落地前)
	_托管._会话 = 会前
	_托管._后端 = 后前
	假会话.free()
	假后端.free()


## 原版 `PVPHandler.resumePvpMode:121-149` 一个 switch 四种结局，逐条量：
## 1(和平)/4(全体) 无条件发；2(组队) 要还在队里；3(家族) 要还在家族里；5(阵营) 没有 case。
## 判的是"有没有发出那条改模式上行"——用会话的 `hud_state.pk_mode` 当回执（本工程
## `request_pk_mode()` 就地把这一格写成新值，甲段已证）。
func _丙乙_PVP还原三条闸() -> void:
	var 会话模式备份 = _会话.hud_state.get("pk_mode", 1)
	var 队备份 = null
	var 族备份 = null
	if _后端 != null:
		队备份 = (_后端.get("authoritative_party") as Dictionary).duplicate(true)
		族备份 = (_后端.get("authoritative_guild") as Dictionary).duplicate(true)
	## 全体档（4）：无条件还原
	_会话.hud_state["pk_mode"] = 4
	_托管._pvp记 = 1
	_托管._真还原pvp()
	_判(int(_会话.hud_state.get("pk_mode", 0)) == 1, "记的是和平(1)、当前全体(4) ⇒ 要发还原（原版 case NONE）")
	## 组队档（2）：没队就不还原
	_会话.hud_state["pk_mode"] = 4
	_托管._pvp记 = 2
	if _后端 != null:
		(_后端.get("authoritative_party") as Dictionary).clear()
	_托管._真还原pvp()
	_判(int(_会话.hud_state.get("pk_mode", 0)) == 4, "记的是组队(2) 但已经不在队里 ⇒ 不许还原（原版 case PVP_TEAM 的 else）")
	_判(int(_托管._pvp记) == 4, "放弃那一条要把记录改成当前档（原版 `_lastPvpMode = pvpMode`）")
	## 组队档：在队里就要还原
	if _后端 != null:
		(_后端.get("authoritative_party") as Dictionary)["members"] = [{"character_id": 1}]
	_托管._pvp记 = 2
	_托管._真还原pvp()
	_判(int(_会话.hud_state.get("pk_mode", 0)) == 2, "还在队里 ⇒ 组队档要还原")
	## 家族档（3）：有家族号才还原
	_会话.hud_state["pk_mode"] = 4
	_托管._pvp记 = 3
	if _后端 != null:
		(_后端.get("authoritative_guild") as Dictionary)["id"] = 77
	_托管._真还原pvp()
	_判(int(_会话.hud_state.get("pk_mode", 0)) == 3, "有家族号 ⇒ 家族档要还原（原版 case PVP_FAMILY 的 if）")
	## 阵营档（5）：原版 switch 里没有这一条 ⇒ 什么都不许做
	_会话.hud_state["pk_mode"] = 4
	_托管._pvp记 = 5
	_托管._真还原pvp()
	_判(int(_会话.hud_state.get("pk_mode", 0)) == 4, "阵营(5) 在原版 switch 里没有 case ⇒ 一律不动（别顺手补一条）")
	## 当前档已经就是记的档 ⇒ 一句都不发。
	## ⚠ 只判 `pk_mode` 的值**判不出来**：发同一档就是把这一格写成它自己，前后一样
	## （10-18 变异实测：把 `if 记 == 现: return` 去掉之后整道门照样全绿 ⇒ 假敏感）。
	## `request_pk_mode()` 每次都会 emit `hud_state_changed` ⇒ 拿广播次数当"发没发"的探针。
	_会话.hud_state["pk_mode"] = 2
	_托管._pvp记 = 2
	var 发过: Array[int] = [0]
	var 数 := func(_状: Dictionary) -> void: 发过[0] += 1
	_会话.hud_state_changed.connect(数)
	_托管._真还原pvp()
	_会话.hud_state_changed.disconnect(数)
	_判(发过[0] == 0 and int(_会话.hud_state.get("pk_mode", 0)) == 2,
			"记的档 == 当前档 ⇒ 一次都不许发（原版 `_lastPvpMode != pvpMode`；实发 %d 次）" % 发过[0])
	## 阳性对照：这一句必须**能测出发**，否则上面那个 0 是量具坏了而不是没发
	_会话.hud_state["pk_mode"] = 4
	var 发过2: Array[int] = [0]
	var 数2 := func(_状: Dictionary) -> void: 发过2[0] += 1
	_会话.hud_state_changed.connect(数2)
	_托管._pvp记 = 1
	_托管._真还原pvp()
	_会话.hud_state_changed.disconnect(数2)
	_判(发过2[0] >= 1, "夹具自检：档不同时探针要数得到「发过一次」（实发 %d 次 ⇒ 探针本身坏了）" % 发过2[0])
	if _后端 != null:
		if 队备份 != null:
			(_后端.get("authoritative_party") as Dictionary).clear()
			(_后端.get("authoritative_party") as Dictionary).merge(队备份, true)
		if 族备份 != null:
			(_后端.get("authoritative_guild") as Dictionary).clear()
			(_后端.get("authoritative_guild") as Dictionary).merge(族备份, true)
	_会话.hud_state["pk_mode"] = 会话模式备份
	_托管._pvp记 = -1


func _等预热带过() -> void:
	_托管.拍(900.0)


## 重开一次挂机，并且**当场断言真的开起来了**。
## ⚠ 原版 `isStart` 那条 1 秒防抖（`GuajiHandler:1025-1036`）会**静默吃掉**紧跟着的第二次开：
## 上一版门里"停→立刻再开"那几段就是这么开了个寂寞 ⇒ 后面所有靠循环推进的判据
## 全变成 0 比 0 的假绿（10-18 实测：乙段"人走开 300 像素活动区不跟跑"那条根本没在跑循环）。
## 先 `拍(1200)` 把上一轮的防抖排掉（`拍()` 第一行就减它），再开，再断言。
func _重开() -> void:
	_会话.request_hang(false)
	_托管.拍(1200.0)
	_会话.request_hang(true)
	_判(bool(_托管.在跑), "量具自检：这一段真的开起来了（开不起来后面全是 0 比 0）")


# ── 丁：挑怪谓词（三档 / 同层 / 黑名单 / 攻击者标记）────────────────────
func _丁_挑怪谓词() -> void:
	var 实体 = _玩家.get_parent().get_node_or_null("LifeRoot")
	_判(实体 != null and 实体.has_method("挂机的同层怪"), "LifeRoot 上要有挂机专用查询（同层怪/全部怪/掉落）")
	if 实体 == null:
		return
	var 怪群: Array = 实体.call("挂机的全部怪")
	_判(not 怪群.is_empty(), "木叶村烘焙图里应有怪（否则挑怪族判据是 0 比 0）")
	if 怪群.is_empty():
		return
	var 一只 = 怪群[0]
	_判(int(_托管.怪档(一只)) in [0, 1, 2], "怪档只能是 0普通/1首领/2精英（实得 %s）" % str(_托管.怪档(一只)))
	_改配置("autoAvoidBoss", true)
	var 档 := int(_托管.怪档(一只))
	_判(bool(_托管.可打(一只)) == (档 == 0),
			"勾了避开首领后：普通怪可打、首领/精英都不可打（这只档=%d、可打=%s）" % [档, str(_托管.可打(一只))])
	_改配置("autoAvoidBoss", false)
	_判(bool(_托管.可打(一只)), "没勾避开首领时普通/首领都该可打")
	## ── 精英那一档是**每一只实例**身上的词缀（`Monster.isJingYing:1122-1125` = `jingyings` 非空），
	##    服务端逐只 roll（`fake_flash_server._configure_monster_variant:16609-16622` → 生成包第 19 段），
	##    图鉴里的静态 `boss` 代替不了它 ⇒ 少判这一支，"普通怪 roll 成精英"那只照样会被挂机吃掉。
	var 普通怪 = null
	for 候 in 怪群:
		if int(_托管.怪档(候)) == 0:
			普通怪 = 候
			break
	_判(普通怪 != null, "木叶村烘焙图里要有一只静态档=普通的怪，否则『精英词缀』那一支根本没被判到（0 比 0）")
	if 普通怪 != null:
		_改配置("autoAvoidBoss", true)
		_判(bool(_托管.可打(普通怪)),
				"阳性对照：普通档 + 空精英词缀 + 勾了避首领 ⇒ 该可打（这条不立，下面那条恒真）")
		普通怪.set("精英属性", [{"属性类型": 1, "数值": 2}])
		_判(not bool(_托管.可打(普通怪)),
				"这只普通怪挂了精英词缀，勾着『避开首领』还放它进挑怪（原版 `:1119` 要 `mobInfo.boss == 0 && !isJingYing`）")
		_改配置("autoAvoidBoss", false)
		_判(bool(_托管.可打(普通怪)), "没勾避开首领时，带精英词缀的普通怪也要可打")
		普通怪.set("精英属性", [])
	一只.set_meta("attacked_by_mob", true)
	_判(not bool(_托管.可打(一只)), "出生帧里 attacked_by_mob 为真的怪不许打（原版 SkillHandler.canAttack:447-450）")
	一只.set_meta("attacked_by_mob", false)
	## ── ⑧ `SkillHandler.as:455` 那一句 `if (param1 is Monster && !(param1 as Monster).isPetMonster)`
	##    —— **宠物怪（别人放的通灵兽）不进**取 `_loc3_` 的那一支，Character/Flag 两支对怪也不成立
	##    ⇒ `_loc3_` 留初值 false ⇒ `canAttack` 恒假。本工程这一位由 `地图实体._configure_actor` 里
	##    `set_meta("is_pet_monster", _是宠物怪定义(id))` 写（数据源 `数据/怪物动画索引.json` 的
	##    `source_kind == "pet"`，与原版 `Monster.as:1652` `_isPetMonster = info.petLink > 0` 同源）。
	##    以前整条没有 ⇒ `挂机的同层怪/挂机的全部怪` 按 `kind=="m"` 收，别人的宠物也在候选里。
	_判(bool(_托管.能攻(一只)), "丁：夹具——这一只摘掉全部标记时必须算能攻（否则下面两条恒真）")
	一只.set_meta("is_pet_monster", true)
	_判(not bool(_托管.能攻(一只)),
			"别人放的通灵兽（isPetMonster）不许算『能攻』（原版 `SkillHandler.as:455`；挂机从此不咬别人的宠物）")
	_判(not bool(_托管.去攻这只(一只)),
			"宠物怪同样不许被挑中去攻（`toAttackMonster:1117-1120` 末尾那一条就是 canAttack）")
	一只.set_meta("is_pet_monster", false)
	_判(bool(_托管.能攻(一只)),
			"丁·阳：只把这一位摘掉、其余一律不动 ⇒ 又算能攻（没有这条，上面两条就是恒真）")

	var 层 := int(_托管._层号())
	_判(层 >= 0, "玩家应能算出所在层号（实得 %d）" % 层)
	var 全村 := Rect2(0.0, -1000.0, 3000.0, 3000.0)
	var 同层: Array = 实体.call("挂机的同层怪", 层, 全村)
	for 怪 in 同层:
		if int(实体.call("怪的层号", 怪)) != 层:
			_判(false, "同层查询里混进了别的层的怪（%s）" % str(怪))
			break
	_判(同层.size() >= 0, "同层查询能跑（实得 %d 只）" % 同层.size())
	var 空表: Array = 实体.call("挂机的同层怪", 9999, 全村)
	_判(空表.is_empty(), "不存在的层号要回空表（原版 floor==-1 同理）")

	var 键 := 987654
	_判(not bool(_托管.黑名单里(键)), "没拉黑过的目标不在黑名单")
	_托管.拉黑(键)
	_判(bool(_托管.黑名单里(键)), "拉黑后 1.5 秒内不许再挑它")
	_托管._黑名单[键] = Time.get_ticks_msec() - 1
	_判(not bool(_托管.黑名单里(键)), "黑名单过期后要自己失效（原版 `:987-990`）")
	_判(bool(_托管.黑名单里(null)), "空目标算错目标（原版 `isWrong:969-972`）")


# ── 戊：拾取 6 类分开 + 装备三档 + 空槽 + 金币例外 ──────────────────────
func _戊_拾取分类() -> void:
	## 号段一律按**原版 `ItemType.getTypeFromId`（补零到 8 位取前两位）**挑，不按 category 文本：
	## 01=玩家装备 / 02=宠物装备 / 03=回HP消耗 / 10=任务物品 / 12=材料 / 11=礼包（**不是装备**）。
	var 装备号 := "01210441"				# type 01，required_level=1 ⇒ 门槛 99 那条能判出"不捡"
	var 药号 := "03000001"					# type 03
	var 材料号 := "12100000"				# type 12
	var 任务号 := "10000001"				# type 10
	for 号 in [装备号, 药号, 材料号, 任务号]:
		_判(not _会话.GAME_DATA.item(号).is_empty(), "夹具用的号 %s 在物品表里（否则这一条是空转）" % 号)
		_判(int(_托管._类型(号)) == int(str(号).substr(0, 2)),
				"夹具 %s 的类型要等于号段前两位（原版 getTypeFromId），实得 %d" % [号, int(_托管._类型(号))])
	var 掉 := func(号: String, 品质 := 0, 金 := false) -> Dictionary:
		## ⚠ `owner_id` 必须给 **0（无主）**：`canItemPickup:478-486` 认的是"无主/自己的/同队的"，
		## 上一版夹具给了 −1 ⇒ 每一条都先死在归属闸上，"关了某枚勾⇒不捡"那几条全是 0 比 0 的假绿。
		return {"item_id": 号, "aptitude": 品质, "is_meso": 金, "owner_id": 0, "x": _玩家.position.x, "y": _玩家.position.y}
	# 装备：品质门槛 4（紫）
	_改配置("collectQuality", 4)
	_判(int(_托管.该不该捡(掉.call(装备号, 3))) == 0, "装备品质 3 < 门槛 4 ⇒ 不捡（原版 `:477-480`）")
	_判(int(_托管.该不该捡(掉.call(装备号, 5))) != 0, "装备品质 5 ≥ 门槛 4 ⇒ 要捡")
	_改配置("collectQuality", 0)
	# 职业/等级门槛
	_改配置("collectLevel", 99)
	_判(int(_托管.该不该捡(掉.call(装备号, 1))) == 0, "拾取等级门槛 99 ⇒ 需求等级不够的装备不捡（原版 `:473-475`）")
	_改配置("collectLevel", 0)
	# 六类开关
	_改配置("isCollectDrug", false)
	_判(int(_托管.该不该捡(掉.call(药号, 0))) == 0, "关了『拾取药品』⇒ 药不捡")
	_改配置("isCollectDrug", true)
	_判(int(_托管.该不该捡(掉.call(药号, 0))) != 0, "开着就捡")
	_改配置("isCollectMoney", false)
	_判(int(_托管.该不该捡(掉.call("", 0, true))) == 0, "关了『拾取金币』⇒ 金币不捡")
	_改配置("isCollectMoney", true)
	_判(int(_托管.该不该捡(掉.call("", 0, true))) != 0, "开着就捡")
	if not 任务号.is_empty():
		_改配置("isCollectQuestion", false)
		_判(int(_托管.该不该捡(掉.call(任务号, 0))) == 0, "关了『拾取任务品』⇒ 任务品不捡（这枚勾以前根本没人读）")
		_改配置("isCollectQuestion", true)
	_判(not _会话.GAME_DATA.item(材料号).is_empty(), "夹具用的材料号 %s 在物品表里" % 材料号)
	_改配置("isCollectCaiLiao", false)
	_判(int(_托管.该不该捡(掉.call(材料号, 0))) == 0, "关了『拾取材料』⇒ 材料不捡（材料号 %s）" % 材料号)
	_改配置("isCollectCaiLiao", true)
	## `autoCollect` 在原版是喂给 **`isPickEqp`** 的（`setConfig:269`），不是 `toExecutePickLogic`
	## 里那个恒真的 `_isPick`（`GuajiHandler.as:154` 声明 = true，全份没人再赋值）。
	## 所以：关掉它 ⇒ 只有装备不捡，别的五类照跑；**六枚全关**才是整条拾取支线不跑。
	_改配置("autoCollect", false)
	_判(int(_托管.该不该捡(掉.call(装备号, 6))) == 0, "关掉 autoCollect（=isPickEqp）⇒ 装备不捡")
	_判(int(_托管.该不该捡(掉.call(药号, 0))) != 0, "但药品那一类照捡（_isPick 恒真，不是一枚总闸）")
	var 六枚: Array = ["autoCollect", "isCollectQuestion", "isCollectDrug", "isCollectMoney", "isCollectCaiLiao", "isCollectOthers"]
	var 存六 := {}
	for 键 in 六枚:
		存六[键] = _会话.挂机配置[键]
		_改配置(键, false)
	_判(not bool(_托管.会去捡()), "六枚全关 ⇒ 整条拾取支线不跑（原版 toExecutePickLogic:355-357）")
	for 键 in 六枚:
		_改配置(键, true)
	_判(bool(_托管.会去捡()), "六枚全开 ⇒ 跑拾取")
	for 键 in 六枚:
		_改配置(键, 存六[键])
	# 背包满：装备不捡、金币照捡（原版 `:478/501-507`）
	var 备份: Array[Dictionary] = []
	for 条 in _会话.inventory:
		(备份 as Array).append((条 as Dictionary).duplicate(true))
	_会话.inventory.clear()
	# ⚠️ 灌满的格数取会话真实容量：背包 2026-10-31 起每页 90 格（10 列 x 9 行），写死 96
	#    只是占了 96 格，`_有空槽()` 照样有格子，这条腿会红成"满了还有空槽"。
	var 容量 := int(_会话.call("背包总格数"))
	_判(容量 >= 90, "背包总格数应起于 90（每页 90 格口径），实际 %d" % 容量)
	for _i in 容量:
		_会话.inventory.append({"id": "00000000", "quantity": 1})
	_判(not bool(_托管._有空槽()), "塞满 %d 格后应判『没空槽』" % 容量)
	_判(int(_托管.该不该捡(掉.call(装备号, 6))) == 0, "背包满 ⇒ 装备不捡（原版 `:478`）")
	_判(int(_托管.该不该捡(掉.call("", 0, true))) != 0, "背包满 ⇒ 金币照捡（原版金币不占格）")
	_会话.inventory.clear()
	for 条 in 备份:
		_会话.inventory.append(条)


func _找一类(类名: String) -> String:
	var 表: Dictionary = _会话.GAME_DATA.取表("物品")
	for 号 in 表.keys():
		if 类名 in str((表[号] as Dictionary).get("category", "")):
			return str(号)
	return ""


# ── 己：嗑药（号段筛 + 按回量升序 + 大/小瓶两档 + 没药提示）────────────
func _己_嗑药() -> void:
	var 备份: Array[Dictionary] = []
	for 条 in _会话.inventory:
		(备份 as Array).append((条 as Dictionary).duplicate(true))
	## ⚠ 等级必须**本段自己钉**：`药品表` 那支按 `required_level <= 玩家等级` 筛，
	## 而 `player_stats.level` 是从 `user://玩家数据.json` 读进来的 —— 那文件与另一份工程**共用**，
	## 任何一条在线腿登录过临时夹具，回来就是 1 级（10-19 实测：血药表从 2 条掉成 1 条，
	## "大瓶优先/小瓶优先"两条跟着变假红）。拿环境值当前提 = 门自己不稳。
	var 级备份 = _会话.player_stats.get("level", 0)
	_会话.player_stats["level"] = 60
	## ⚠ 血也要**压到未满**：`_嗑一种` 原样走 `UI.useItem`（`GuajiHandler.as:193-216`），
	## 而 `UI.as:1321-1325` 对纯回血药有一条 `hp >= maxHp ⇒ ITEM_HP 拒`。
	## 原版只在血线以下才走到这一支（`GuajiHandler.as:609-633`），满血调用 = 夹具不在前置里，
	## 判据会变成"门拦没拦满血"，不是本段要测的大瓶/小瓶顺序。共用存档里 hp/max_hp 常常正满。
	var 血备份 = _会话.player_stats.get("hp", 0)
	var 血上限 := int(_会话.player_stats.get("max_hp", 1))
	_会话.player_stats["hp"] = maxi(1, 血上限 / 2)
	var 需03 := int(_会话.GAME_DATA.item("03000003").get("required_level", 0))
	var 需06 := int(_会话.GAME_DATA.item("03000006").get("required_level", 0))
	_判(需03 <= 60 and 60 < 需06,
			"己：夹具——60 级必须正好卡在『大瓶能喝、极品不能喝』中间（实得 03 需 %d、06 需 %d）" % [需03, 需06])
	_会话.inventory.clear()
	_会话.inventory.append({"id": "03000001", "quantity": 5})	# 250
	_会话.inventory.append({"id": "03000003", "quantity": 5})	# 700
	_会话.inventory.append({"id": "03000006", "quantity": 5})	# 1800，但需求等级 80 ⇒ 不该入表
	var 表: Array = _托管.药品表(true)
	_判(表.size() == 2, "血药表只收『号段 03 + 等级够 + 有回量』的，实得 %d 条" % 表.size())
	if 表.size() == 2:
		_判(float(表[0]["回量"]) < float(表[1]["回量"]), "血药表按回量升序（原版 hpSortFunc）")
	_改配置("auotReplyHpType", 0)			# 0 = 大瓶优先
	_托管._嗑一种(表, 1, true)
	_判(_数量("03000003") == 4 and _数量("03000001") == 5,
			"大瓶优先 ⇒ 先嗑 03000003（实得 03=%d / 01=%d）" % [_数量("03000003"), _数量("03000001")])
	_会话.player_stats["hp"] = maxi(1, 血上限 / 2)	# 上一瓶已把血补满 ⇒ 再压回未满（同一条 ITEM_HP 闸）
	_改配置("auotReplyHpType", 1)			# ≠0 = 小瓶优先
	_托管._嗑一种(表, -1, true)
	_判(_数量("03000001") == 4, "小瓶优先 ⇒ 先嗑 03000001（实得 %d）" % _数量("03000001"))
	# 没药：空表只飘一句，不许崩
	_会话.inventory.clear()
	_托管._缺血药可提示 = true
	var 提示: Array[String] = []
	var 接 := func(句: String) -> void: 提示.append(句)
	_会话.notification_requested.connect(接)
	_托管._嗑一种([], 1, true)
	_会话.notification_requested.disconnect(接)
	_判(提示.size() == 1, "背包里没血药时要飘一句提示（原版 showTipNoHPItems；实得 %d 句）" % 提示.size())
	## ── 在线 id 形态：服务端文本帧 `_encode_item_payload` 是 `"&".join(str(值) ...)`
	##    ⇒ `03000001 拉面（小）` 到客户端就是 `"3000001"`（`后端连接._parse_item_entry`
	##    原样存 `values[1]`）。上一版 `药品表` 在补零**之前**按 `begins_with("03")` 筛 ⇒
	##    在线背包里有拉面也被判"没有可吃的血药"，每 4 帧刷一条（2026-10-31 用户报）。
	##    本段离线种子一直用八位补零写法，所以以前从未红过 —— 这里补上线上形态。
	## ⚠ 摆成**回量降序**：这样下面那条"按回量升序"才真的在量排序
	## （摆成升序时删掉 `sort_custom` 也照样绿 —— 假绿）。
	_摆背包([
		{"id": "3000003", "quantity": 3},		# 03000003 拉面（大），回 700
		{"id": "3000001", "quantity": 3},		# 03000001 拉面（小），回 250
		{"id": "4000001", "quantity": 3},		# 04000001 牛奶（小），回蓝 100
		{"id": "18000001", "quantity": 3},		# 18 号段「拉面+牛奶」：回 250/300 也不许进表
	])
	var 血表二: Array = _托管.药品表(true)
	var 蓝表二: Array = _托管.药品表(false)
	_判(血表二.size() == 2,
			"在线未补零 id（\"3000001\"/\"3000003\"）要进血药表（实得 %d 条）" % 血表二.size())
	_判(蓝表二.size() == 1, "在线未补零 id（\"4000001\"）要进蓝药表（实得 %d 条）" % 蓝表二.size())
	_判(not _表里有(血表二, "18000001") and not _表里有(蓝表二, "18000001"),
			"「拉面+牛奶」是 18 号段（BuffWuPin）—— 有回血回蓝也**不许**进挂机药表（原版按 ItemType 号段筛，不是按 hp_restore 筛）")
	if 血表二.size() == 2:
		_判(float(血表二[0]["回量"]) < float(血表二[1]["回量"]), "线上形态的血药表同样按回量升序")
	_会话.inventory.clear()
	for 条 in 备份:
		_会话.inventory.append(条)
	_会话.player_stats["level"] = 级备份		# 本段钉过的等级要还回去（后面还有段读它）
	_会话.player_stats["hp"] = 血备份


func _数量(号: String) -> int:
	for 条 in _会话.inventory:
		if str((条 as Dictionary).get("id", "")) == 号:
			return int((条 as Dictionary).get("quantity", 0))
	return -1


## 药表里的 id 可能是八位补零也可能是线上未补零形态 ⇒ 按数值比。
func _表里有(表: Array, 号: String) -> bool:
	for 条 in 表:
		if int(str((条 as Dictionary).get("id", "0"))) == int(号):
			return true
	return false


# ── 庚：辅助/升级的闸（没有对应技能时必须一律 false，而不是"随便放"）──
func _庚_辅助与升级() -> void:
	_判(int(_托管._号在哪个槽(9999999)) == -1, "没学过的招式要找不到槽")
	_判(not bool(_托管.能施放(9999999)), "没学过的招式：能施放=false（原版 `:554` lv>0）")
	_判(not bool(_托管.有该招增益(3000)), "掌仙术不在『能判 buff 类型』的两招里 ⇒ 有增益=false（原版只认 add_atk/add_def）")
	var 学过的 := 0
	for 技 in _会话.learned_skills:
		if int(str((技 as Dictionary).get("level", 0))) > 0:
			学过的 += 1
	_判(学过的 > 0, "离线种子要有已学忍术（否则『能施放』那族判据是 0 比 0）")
	## ── ④ `能施放()` 现在**转发** `玩家._这一招放得出`（原版
	##    `AbstractAttackSkill.canUseSkill:546-573` 全树只有这一份，三关 =
	##    `getSkillLevel>0`(`:552/:554`) / `stats.mp >= getSkillMp`(`:553-554`) /
	##    `stats.zq >= getSkillConsumeZQ`(`:556-557`)，**与快捷栏一件都没有关系**）。
	##    上一版这里另写了一份，而且**多加一道闸**"这一招必须先放在快捷栏某一格"（`_号在哪个槽`）
	##    ⇒ 症状：没把天之咒印拖到快捷栏的玩家，原版挂着会自动上咒印、我们一发都不上。
	var 槽备份: Array = _备份槽位()
	var 学备份 = _备份已学()
	var 蓝备份 = _会话.player_stats.get("mp", 0)
	var 精备份 = _会话.player_stats.get("zq", 0)
	_会话.skill_slots.clear()					# 把快捷栏**整排清空** ⇒ 下面这两枚都是"没上栏"的
	_会话.learned_skills.clear()
	_会话.learned_skills.append(_造已学("3002"))
	var 耗蓝: Dictionary = _会话.GAME_DATA.skill_cost(3002, 1)
	var 需蓝 := int(耗蓝.get("mp", 0))
	_判(需蓝 > 0, "庚：夹具——3002 一级要真的耗查克拉（不然『蓝不够』那一支是 0 比 0；实得 %d）" % 需蓝)
	_判(int(_托管._号在哪个槽(3002)) == -1, "庚：夹具——这一招此刻确实**没放在快捷栏**")
	_会话.player_stats["mp"] = 需蓝
	_会话.player_stats["zq"] = int(耗蓝.get("zq", 0))
	_判(bool(_托管.能施放(3002)),
			"已学 + 蓝/精刚好够、但**没上快捷栏** ⇒ 能施放仍须为真（原版三关里根本没有快捷栏这一项）")
	_会话.player_stats["mp"] = 需蓝 - 1
	_判(not bool(_托管.能施放(3002)),
			"蓝差 1 就不许放（`:554` `stats.mp >= getSkillMp`；mp=%d 需 %d）" % [需蓝 - 1, 需蓝])
	_会话.player_stats["mp"] = 需蓝
	_判(int(_托管._号在哪个槽(3002)) == -1,
			"庚·阳：这一招此刻**仍然**没上栏 ⇒ 上面那条量到的确实是蓝，不是栏（否则恒真）")
	## 精华那一档（`:556-559`，`param2.type = "zq"`）：9030 一级不耗蓝、耗 300 精华
	_会话.learned_skills.append(_造已学("9030"))
	var 耗精: Dictionary = _会话.GAME_DATA.skill_cost(9030, 1)
	var 需精 := int(耗精.get("zq", 0))
	_判(需精 > 0, "庚：夹具——9030 一级要真的耗精华（不然这一支是 0 比 0；实得 %d）" % 需精)
	_会话.player_stats["zq"] = 需精
	_判(bool(_托管.能施放(9030)), "精华刚好够 ⇒ 放得出（`:557`）")
	_会话.player_stats["zq"] = 需精 - 1
	_判(not bool(_托管.能施放(9030)),
			"精华差 1 就不许放（`:556-559` getSkillConsumeZQ；zq=%d 需 %d）" % [需精 - 1, 需精])
	_会话.player_stats["zq"] = 需精
	_还原已学(学备份)
	_还原槽位(槽备份)
	_会话.player_stats["mp"] = 蓝备份
	_会话.player_stats["zq"] = 精备份
	# 自动升级：那枚勾关着时，计时器必须清零（原版 `:408-411`）
	## ⚠ `拍自动升级()` 第一行就是 `if not 在跑 ... : 清零 return` ⇒ 这一段**必须挂着判**，
	## 不然"勾开着也不攒"那种真 bug 会被"根本没挂"顺手糊过去（10-18 第一条红就是这么来的）。
	_重开()
	_等预热带过()
	_改配置("autoUpgradeSkill", false)
	_托管._升级毫秒 = 0.0
	_托管.拍自动升级(1000.0)
	_判(float(_托管._升级毫秒) == 0.0, "勾关着 ⇒ 升级计时器清零，不许攒着")
	_改配置("autoUpgradeSkill", true)
	_托管._升级毫秒 = 0.0
	_托管.拍自动升级(1000.0)
	_判(absf(float(_托管._升级毫秒) - 1000.0) < 0.01, "勾开着 ⇒ 计时器按毫秒累加（实得 %s）" % str(_托管._升级毫秒))
	_改配置("autoUpgradeSkill", false)



# ── 共用小工具 ────────────────────────────────────────────────────────
func _备份背包() -> Array:
	var 出: Array = []
	for 条 in _会话.inventory:
		出.append((条 as Dictionary).duplicate(true))
	return 出


func _还原背包(备份: Array) -> void:
	_会话.inventory.clear()
	for 条 in 备份:
		_会话.inventory.append(条)


func _摆背包(表: Array) -> void:
	_会话.inventory.clear()
	for 条 in 表:
		_会话.inventory.append((条 as Dictionary).duplicate(true))


## 把"大块进得去"那三个前提一次性摆正：没在寻路、没在追击、站着。
## ⚠ 上一段的循环会把人留在寻路/追击态 ⇒ 下一段第一行就 `return`，
##    于是整段判据全是"什么都没发生"的假绿（10-18 数过这一族）。
func _摆空闲态() -> void:
	_玩家.set("自动寻路中", false)
	## ⚠ 10-19 补的两把：**大块现在问的是真路线旗**（原版 `isGPathFinding()`，
	## 见 `挂机托管._在赶路线()`），只清「自动寻路中」那行提示旗不够 —— 上一段的循环
	## 会把 `click_move_active` 留在真，那段判据就全变成"什么都没发生"的假绿。
	_玩家.set("click_move_active", false)
	_玩家.set("自动爬梯中", false)
	_玩家.set("_同步动作", 1)
	_玩家.set("自动接近目标", null)		# 原版 `toAttackAnemy`/`curTarget`：空闲态就是"手里没追打命令"
	落到脚点()							# "站着"在引擎那一侧的**全部含义**见下面那个函数
	_托管._追击 = false
	_托管.目标 = null
	## ⚠ "空闲"里还包含**手里没攥着答应去捡的那一枚**：`_拾取在走`（原版 `pathFindTarget` 的
	## 拾取版）不清 ⇒ 下一拍 `拾取或打怪()` 开头先走进"路走完了还够不着 ⇒ 拉黑"那一支验收，
	## 把场上编号相同的那枚（离线掉落的小号是循环复用的）**当场拉黑**，本段①②就量不到了
	## （10-19 实测：戌 段认到的靶子其实正是上一段那枚 `-2`，promise 还挂着 → 状态变"打怪物"）。
	## 这清的是"夹具自己声明的空闲态"，与被测那一句无关：验收那一支自己由 壬②/戌② 现场摆出来。
	_托管._拾取在走 = null
	_托管.状态文字 = ""
	_托管._打我的 = null
	_托管._打我到期 = 0.0


## 这一份托管有没有真的把会话那两条信号接上（= `_ready()` 跑过的唯一可查证据）。
## ⚠ Godot 4 里节点**离树再重新入树不会重跑 `_ready()`**（`_enter_tree` 会），而本模块是在
## `_exit_tree()` 里把 `hang_changed` 摘掉的 ⇒ "重挂同一份"得到的是一个**聋的**实例：
## 后面每一处 `_重开()` 都只翻会话、翻不动它。量具要是拿它当宿主，整段判据都会变成
## "什么都没发生"（10-19 未/戌/亥 那三条"量具自检"红就是这条）。
func 挂机信号已连(一份: Node) -> bool:
	var 会 = 一份.get("_会话")
	if 会 == null:
		return false
	return bool(会.is_connected("hang_changed", 一份._接挂机态))


## 夹具：照 `玩家.gd:160-162` 那三句给这一具玩家**重建**一个托管实现体，并把
## **两处引用一起换掉**（`_玩家._托管` 与本门的 `_托管`）。
## 真换图时 `地图实体` 建的是**新的一具玩家**，而那一具玩家的 `_ready()` 里那三句才是
## 实现体的两个持有者：玩家那一侧的 `_unhandled_input`（点地面关挂）、`_冲选中目标`
## （追击回灌拉黑）读的是 `_玩家._托管`，本门判的是 `_托管`。**只换一边** ⇒ 玩家还攥着
## 已经 free 掉的旧实现体 ⇒ "点空白地面要关挂机"那三条投递路（push_input /
## parse_input_event / 手工调函数）全都"没反应"（10-19 实测：三条都不动 `在跑`）。
func 重建托管() -> Node:
	var 新: Node = load("res://脚本/角色/挂机托管.gd").new()
	新.name = "挂机托管"						# 与 `玩家.gd:161` 同一句
	_玩家.add_child(新)							# 与 `玩家.gd:162` 同一句（`_ready()` 当场跑）
	_玩家.set("_托管", 新)
	_托管 = 新
	return 新


## 夹具：把一份**已经离树**的旧实现体收掉。先摘 `_会话` 再 free ——
## 与 辰 段同一手法：不许它的 `_exit_tree()` 回头去动真会话/真特效（那颗球归本段自己判）。
func 收掉旧托管(旧: Node) -> void:
	if 旧 == null or not is_instance_valid(旧):
		return
	旧.set("_会话", null)
	旧.free()


## 夹具：把角色摆成**真机上"站着"的那一副态** = 站在一条脚点上。
## ⚠ 这一格从来没人填过：本门为了让"每 4/8/16 帧"这类判据不随帧率漂，把
## `_physics_process` 关了（`_跑()` 里那句 `set_physics_process(false)`），而
## `current_fh_id` **只有** `_physics_process` 的落地判定会写（`玩家.gd:1396-1405`：
## `find_foothold` 命中 ⇒ `position.y = 地面y`、`on_ground = true`、`current_fh_id = res.id`）
## ⇒ 实测进图后是 `我=(252,199) on_ground=false fh=""`，之后一直空。少了这一格**必然**红的两类：
##   · `走向()` 里 `plan(current_fh_id, …)` 拿到空号 ⇒ `自动寻路.gd:21-24`
##     `get_component("") == -1` 直接回空表 ⇒ 挂机/追击**一条路线都发不出去**
##     （壬② 的"记不下那一枚 / 夹具自检不该已拉黑"、酉 的"先要真的发出一条路线 /
##      路线旗必须亮着 / 爬梯这一跑也要先发出路线 / 正在爬梯时不许掐路线"、
##      戌④ 的"要发出一条真寻路路线 / 必须是分格的动作序列"全是它）；
##   · `use_skill_slot` 第一道 `_能放招()`（原版 `AbstractSkill.fire():112-117` 要
##     `currFoothold && grounded && landed`；`SkillExecute.as:86` 外层那条也写着
##     `canReachTarget(...) && Boolean(player.currFoothold)`）恒假
##     ⇒ **一发技能都放不出去**（丑 的 buff1、午乙 的两条阳性对照）。
## 取脚点用的就是 `走向()` 自己那一句 `footholds.find_click_target()` —— 同一个函数、
## 同一把尺，不是手工点亮一面旗；**查不到脚点就保持离地态**（辛/戌 有几条正是判"人站在
## 查不到落脚点的地方 ⇒ 层号 -1"的，那种地方本来就不该有脚点）。
func 落到脚点() -> bool:
	var 脚点: Node = _玩家.get("footholds")
	if 脚点 == null:
		return false
	var 中: Dictionary = 脚点.call("find_click_target", _玩家.get("position") as Vector2)
	if float(中.get("y", INF)) == INF:
		return false
	var 我: Vector2 = _玩家.get("position") as Vector2
	_玩家.set("position", Vector2(我.x, float(中["y"])))
	_玩家.set("velocity", Vector2.ZERO)
	_玩家.set("climbing", false)
	_玩家.set("on_ground", true)
	_玩家.set("current_fh_id", str(中.get("id", "")))
	return bool(_玩家.get("on_ground")) and String(_玩家.get("current_fh_id")) != ""


## 刚掉下来的东西在原版**飞行中不许捡**（`getPickableDropItemsInRect:529-541` 滤 `dropAir`），
## 所以夹具必须等它落地；等不到就自己红，不许拿"查不到"当"没东西要捡"。
## 等**指定编号**那一枚落地（离线掉落的编号建之前就能从 `_离线掉落序号` 抄到）。
func _等这枚落地(实体, 区: Rect2, 编号: int) -> bool:
	for _次 in 180:
		for 掉 in (实体.call("挂机的掉落", 区) as Array):
			if int((掉 as Dictionary).get("object_id", 1)) == 编号:
				return true
		await _等帧(1)
	return false


func _等落地(实体, 区: Rect2, 期望 := 1) -> int:
	for _次 in 180:
		var n: int = (实体.call("挂机的掉落", 区) as Array).size()
		if n >= 期望:
			return n
		await _等帧(1)
	return (实体.call("挂机的掉落", 区) as Array).size()


# ── 辛：挑怪次序（反击优先 / 同层空⇒放宽 / 全空⇒归位）────────────────
func _辛_挑怪次序() -> void:
	var 实体 = _玩家.get_parent().get_node_or_null("LifeRoot")
	if 实体 == null:
		_收尾("辛：拿不到 LifeRoot")
		return
	var 全: Array = 实体.call("挂机的全部怪")
	_判(not 全.is_empty(), "辛：木叶村里要有怪（否则这三条全是 0 比 0）")
	if 全.is_empty():
		_收尾("辛：没有怪")
		return
	_重开()
	_等预热带过()
	## ① 反击优先（原版 `:796-:797`）：把活动区收到 1 格（50 像素），
	##    再挑一只**不在框里**的怪当成"打我的那只" ⇒ 只有反击这一支能选中它。
	_摆空闲态()
	_托管.重算活动区(1)
	var 区外 = null
	for 怪 in 全:
		if not _托管._活动区.has_point((怪 as Node2D).global_position):
			区外 = 怪
			break
	_判(区外 != null, "辛：夹具——要能找到活动区之外的怪（活动区已收到 50 像素）")
	if 区外 != null:
		(区外 as Node).set_meta("attacked_by_mob", false)
		_判(bool(_托管.可打(区外)), "辛：夹具——这只反击目标必须判得出『可打』（否则下面那条恒真）")
		_托管._打我的 = 区外 as Node2D
		_托管._打我到期 = Time.get_ticks_msec() + 1000.0
		_托管.拾取或打怪(false)
		_判(_托管.目标 == 区外, "活动区外但正在打我的那只要被选中（原版反击优先；实得 %s）" % str(_托管.目标))
		_判(str(_托管.状态文字) == "打怪物", "反击那拍状态要写『打怪物』（实得 %s）" % str(_托管.状态文字))
		_托管._打我的 = null
	## ②·甲/乙 + ⑥ **两趟挑怪都要先过"任务怪优先"**（原版 `:801` 与 `:814` 是连着各写一遍的）
	## ⚠ 10-19 改夹具：原来这里靠"摘掉 `_托管._地表`"把 `_层号()` 打成 -1。但 `_层号()` 现在
	## 已经收成**一份**（`挂机托管._层号()` → `地图实体.怪的层号(玩家)` → `Footholds.find_foothold`），
	## `_地表` 只剩 `_脚下点()` 还在用 ⇒ 摘了它层号照旧是 0（实测红项「实得 0」），
	## 放宽那一趟根本没跑。现在按**原版真正的前置**摆：`player.floor == -1`
	## ⇔ 人站在一处查不到落脚点的位置（`getMonstersInFloor:324` 拿 floor==-1 直接回空表）。
	_摆空闲态()
	var 拾取六: Array = ["autoCollect", "isCollectQuestion", "isCollectDrug",
			"isCollectMoney", "isCollectCaiLiao", "isCollectOthers"]
	for 键名 in 拾取六:
		_改配置(键名, false)			# 拾取排在打怪前面，不关掉就量不到挑怪那两趟
	var 原位: Vector2 = _玩家.position as Vector2
	_判(全.size() >= 2, "辛：夹具——要两只怪才分得出『最近』与『任务怪』（实得 %d）" % 全.size())
	if 全.size() < 2:
		for 键名 in 拾取六:
			_改配置(键名, true)
		return
	搬到画面内(全[0] as Node2D, 140.0)
	搬到画面内(全[1] as Node2D, 320.0)
	_玩家.set("on_ground", true)
	_托管._起点 = 原位
	_托管.重算活动区(640)
	var 近怪 = 全[0]
	var 远怪 = 全[1]
	var 远号 := str((远怪 as Node).get("entity_id"))
	var 近号 := str((近怪 as Node).get("entity_id"))
	## 这张烘焙图上两只怪是**同一个物种**（实测都是 4100000）⇒ 原版那一支按 `mobInfo` 的
	## 物种号筛，同物种就筛不出差别。把近怪换成图鉴里另一个**真实物种**（`数据/怪物.json`），
	## 两只就分开了；换完要还回去（亥 那段自己也会动 entity_id）。
	## ⚠ "两只物种号不同"这条夹具自检**只能摆在换完之后**：摆在前面就是判"这张图出厂是不是
	##   两个物种"，而这一段夹具的**全部作用**就是把它们换成两个物种 —— 那种判据恒红，
	##   与代码好坏无关（10-19 门里那条就是这么红的）。
	var 近号原 := 近号
	if 远号 == 近号:
		var 怪表: Dictionary = _会话.GAME_DATA.取表("怪物")
		var 另一号 := ""
		for 号 in 怪表.keys():
			if str(号) != 远号 and (怪表[号] as Dictionary) is Dictionary:
				另一号 = str(号)
				break
		_判(not 另一号.is_empty(), "辛：夹具——图鉴里要还有第二个物种可换（实得 %s）" % 另一号)
		近怪.set("entity_id", 另一号)
		近号 = 另一号
	_判(远号 != 近号, "辛：夹具——换完之后两只怪的图鉴号必须不同，`preferActiveQuestMonsters` 才筛得出东西（实得 %s / %s）" % [近号, 远号])
	_判(bool(_托管.去攻这只(近怪)) and bool(_托管.去攻这只(远怪)),
			"辛：夹具——两只都要判得出『可去攻』（否则『挑中哪一只』是运气）")
	var 任务备份: Array = []
	for 条 in _会话.accepted_quests:
		任务备份.append((条 as Dictionary).duplicate(true))
	_会话.accepted_quests.clear()
	_会话.accepted_quests.append(_造任务怪(远号))
	_判((_会话.get_accepted_quests() as Array).size() == 1,
			"辛：夹具——进行中任务要真挂进会话（否则任务怪优先那条是空转）")
	_判(not _托管.任务怪号().is_empty(),
			"辛：夹具——`任务怪号()` 必须从这条任务里解出怪号（原版 `preferActiveQuestMonsters:1122-1165`；实得 %s）" % str(_托管.任务怪号()))
	## —— 第一趟（同层没空）：`:800-:801`
	_摆空闲态()
	_托管.拾取或打怪(false)
	_判(_托管.目标 == 远怪,
			"第一趟（同层）也要先过任务怪优先：任务里那只虽远但仍要挑它（原版 `:801` preferActiveQuestMonsters；实得 %s）" % str(_托管.目标))
	## —— 第一趟的对照：把任务撤掉 ⇒ 同一夹具下应回到『离我最近』
	_会话.accepted_quests.clear()
	_托管._黑名单.clear()
	_摆空闲态()
	var 应挑近 = _托管._区内最近(实体.call("挂机的全部怪"))
	_判(应挑近 == 近怪, "辛：夹具——没任务时放宽那一趟按最近应挑到近怪（实得 %s；不对就说明摆位漂了）" % str(应挑近))
	_托管.拾取或打怪(false)
	_判(_托管.目标 == 近怪,
			"辛·阳：没有进行中任务时挑的就是『最近那只』（没有这条，上面那条『挑远怪』就是恒真）")
	## —— 第二趟（同层查空）：`:813-:814` 同样是**两句连着**
	_会话.accepted_quests.clear()
	_会话.accepted_quests.append(_造任务怪(远号))
	_摆空闲态()
	_玩家.position = 原位 + Vector2(3000.0, 0.0)		# 这一段 x 上没有落脚点 ⇒ 层号 -1
	_托管._起点 = _玩家.position
	_托管.重算活动区(640)
	_判(int(_托管._层号()) == -1,
			"辛：夹具——人站在一处查不到落脚点的位置时层号该回 -1（原版 `player.floor`；实得 %d）" % int(_托管._层号()))
	_判((实体.call("挂机的同层怪", int(_托管._层号()), _托管._活动区) as Array).is_empty(),
			"辛：夹具——层号 -1 时同层查询必须为空（`getMonstersInFloor:324`），否则量不到放宽那一趟")
	_托管.拾取或打怪(false)
	_判(_托管.目标 == 远怪,
			"⑥ 第二趟（放宽到全图）也必须先过任务怪优先（原版 `:813-:814` 连着两句；实得 %s）" % str(_托管.目标))
	## —— 第二趟的对照：撤掉任务 ⇒ 放宽那一趟挑的就是矩形内离我最近
	_会话.accepted_quests.clear()
	_托管._黑名单.clear()
	_摆空闲态()
	_玩家.position = 原位 + Vector2(3000.0, 0.0)
	_托管._起点 = _玩家.position
	_托管.重算活动区(640)
	_判(int(_托管._层号()) == -1, "辛：夹具——对照那一跑层号同样得是 -1（实得 %d）" % int(_托管._层号()))
	var 应挑二 = _托管._区内最近(实体.call("挂机的全部怪"))
	_判(应挑二 != null, "辛：夹具——放宽那一趟要有矩形内的怪可挑（否则下面那条是 0 比 0）")
	_托管.拾取或打怪(false)
	_判(_托管.目标 == 应挑二,
			"辛·阳：没任务时第二趟取的就是『矩形内离我最近』（原版 `:815` getNearestMonsterInArea；实得 %s / 应 %s）" % [str(_托管.目标), str(应挑二)])
	_玩家.position = 原位
	_托管._起点 = 原位
	近怪.set("entity_id", 近号原)			# 换掉的物种号要还回去（后面的段按原物种判）
	for 条 in 任务备份:
		_会话.accepted_quests.append(条)
	## ③ 一只都挑不到 ⇒ 归位走回起点（原版 `:838-:844`，落点 = 起点上方 30）
	_摆空闲态()
	_托管._活动区 = Rect2(999999.0, 999999.0, 10.0, 10.0)
	_托管._起点 = Vector2(_玩家.position.x + 300.0, _玩家.position.y)
	_托管.拾取或打怪(false)
	_判(str(_托管.状态文字) == "没有怪物 归位",
			"矩形内没怪且人离起点 >50 像素 ⇒ 状态要写『没有怪物 归位』（实得 %s）" % str(_托管.状态文字))
	_判(_托管.目标 == _托管._起点, "归位那一拍的『目标』要落回起点（原版把 startPoint 交给寻路）")
	_改配置("autoBattleRange", 20)
	_托管.重算活动区(20)
	for 键名 in 拾取六:
		_改配置(键名, true)			# 夹具恢复出厂：拾取那六档后面还有三段要判


## 造一条"进行中、要杀某号怪、还没杀够"的任务（⑥ 的输入）。
## 形状照 `任务怪号()` 真正读的那几个键：`flash_status==1`(`ACCEPTED`) +
## `目标进度[{kind:"mob", key:<怪号>, curr, count}]`；任务号用一个**表里没有的**，
## 让 `_在本图()` 走"查不到定义就按不限图放行"那一句，不牵动任务表。
func _造任务怪(怪号串: String) -> Dictionary:
	return {"id": 987654, "flash_status": 1,
			"目标进度": [{"kind": "mob", "key": 怪号串, "curr": 0, "count": 5}]}


# ── 壬：拾取的两条路（够得着直接发 / 够不着先寻路 / 寻路失败拉黑 / 途中顺手捡）─
func _壬_拾取路线() -> void:
	var 实体 = _玩家.get_parent().get_node_or_null("LifeRoot")
	if 实体 == null:
		_收尾("壬：拿不到 LifeRoot")
		return
	_重开()
	_等预热带过()
	_摆空闲态()
	_改配置("isCollectMoney", true)
	## ① 够得着（≤90 像素）⇒ 当场发，不走寻路
	## ⚠ 摆位要**偏 40 像素**：既在挂机的 90 像素捡取半径里，又不在"身体碰到就捡"那一圈内
	## —— 不然等落地的这段时间里引擎自己就先捡走了，判的就不是挂机那条路。
	实体.call("_create_loot", _玩家.position + Vector2(40.0, 0.0))
	_判(await _等落地(实体, _托管._活动区, 1) >= 1,
			"壬：夹具——刚掉的这枚金币落地后要能在活动区里查到（飞行中的东西原版本来就不许捡）")
	var 掉前: Array = 实体.call("挂机的掉落", _托管._活动区)
	_判(not 掉前.is_empty(), "壬：刚掉的这枚金币要能在活动区里查到（否则这一段是 0 比 0）")
	_托管.拾取或打怪(false)
	## 原版 `pickDropItem():1219-1227` **不当场发帧**：只把那枚 push 进 `_toPickItems` 并注册
	## ENTER_FRAME，由 `onEnterFrame():1103-1115` 每帧吞一枚、每吞一枚立刻 `refreshPickTime()`。
	## ⇒ 这里先要看到"它进了队列"，再自己吞一拍，才轮到"地面上少一枚"。
	_判((_托管.拾取队列 as Array).size() == 1,
			"够得着的掉落要先进拾取队列（原版只 push，不当场发）；实得 %s" % str(_托管.拾取队列))
	_托管._吞一枚拾取()
	var 掉后: Array = 实体.call("挂机的掉落", _托管._活动区)
	_判(掉后.size() < 掉前.size(),
			"够得着的掉落吞一拍就要真发出去（发完就被单枚锁挡住 ⇒ 查询里少一枚；前 %d 后 %d）" % [掉前.size(), 掉后.size()])
	_判(str(_托管.状态文字) != "拾取", "够得着时不许改走『寻路过去捡』那条（实得 %s）" % str(_托管.状态文字))
	## ② 够不着（在活动区里、但离人 >90）⇒ 记下目标 + 状态写『拾取』
	_摆空闲态()
	实体.call("_create_loot", Vector2(_玩家.position.x + 320.0, _玩家.position.y))
	await _等落地(实体, _托管._活动区, 1)
	var 全中: Array = 实体.call("挂机的掉落", _托管._活动区)
	var 那枚 = null
	for 掉 in 全中:
		if absf(float((掉 as Dictionary).get("x", 0.0)) - _玩家.position.x) > 200.0:
			那枚 = 掉
			break
	_判(那枚 != null, "壬：夹具——要能在活动区里找到一枚离人 >200 像素的掉落（实得 %d 枚）" % 全中.size())
	if 那枚 != null:
		var 落点壬 := Vector2(float((那枚 as Dictionary).get("x", 0)), float((那枚 as Dictionary).get("y", 0)) - 5.0)
		var 脚点壬: Node = _玩家.get("footholds")
		prints("探针壬·② 我=", str(_玩家.position), "on_ground=", str(_玩家.get("on_ground")),
				"fh=", str(_玩家.get("current_fh_id")), "pf=", str(_玩家.get("auto_pathfinder") != null),
				"落点=", str(落点壬),
				"查点=", str(脚点壬.call("find_click_target", 落点壬)) if 脚点壬 != null else "无脚点")
		_托管.拾取或打怪(false)
		prints("探针壬·②之后 拾取在走=", str(_托管._拾取在走), "旗=", str(_玩家.get("click_move_active")),
				"replan=", str(_玩家.get("click_replan_pending")), "段=", str((_玩家.get("auto_actions") as Array).size()),
				"落点x=", str(_玩家.get("click_move_x")))
		_判(str(_托管.状态文字) == "拾取", "够不着时要走『寻路过去捡』（原版 `:778-:791`；实得 %s）" % str(_托管.状态文字))
		_判(_托管.目标 is Dictionary
				and int((_托管.目标 as Dictionary).get("object_id", -99999)) == int((那枚 as Dictionary).get("object_id", -1)),
				"寻路那拍记下的目标就是那一枚掉落（实得 %s）" % str(_托管.目标))
		## ②·B **路走完还够不着 ⇒ 拉黑这一枚**（用户 2026-10-19 实机报 bug2：开着自动拾取
		## 一点开始挂机，角色就钉在原地不动）。③ 那一段只堵了"寻路当场失败"，真机上更常见的
		## 是"路找到了、但只能走到隔壁平台/正下方" —— `走向` 返回**真**，原来没有任何一条路
		## 会把它拉黑 ⇒ 每拍重发同一条寻路，而拾取排在打怪前面并且 `return`。
		var 那枚号 := int((那枚 as Dictionary).get("object_id", 0))
		## ⚠ 这里不许写 `int(_拾取在走)`：那一枚没被记下的时候它是 **null**，而 4.7 里
		## `int(null)` 直接报 `Invalid call. Nonexistent 'int' constructor` 把整条协程打死
		## （10-19 变异壬那一跑实测：壬只判到 8 条、戌只判到 4 条，红项里根本没有本该点名的那一条）。
		_判(_托管._拾取在走 == 那枚号,
				"答应走过去捡之后要把这一枚记下来（实得 %s，期望 %d）" % [str(_托管._拾取在走), 那枚号])
		_判(not bool(_托管.黑名单里(那枚号)),
				"壬：夹具自检——这一枚此刻不该已在黑名单里（否则下面那条恒真）")
		_玩家.set("自动寻路中", false)		# 这一趟"走完了"：人没动、那枚还在 320 像素外
		_玩家.set("click_move_active", false)	# ⚠ 10-19 起大块问的是这一把（原版 isGPathFinding），
												# 只清提示旗等于"路还在跑"⇒ 验收那段根本不进
		_托管.拾取或打怪(false)
		_判(bool(_托管.黑名单里(那枚号)),
				"走完还够不着的那一枚要拉黑 1.5 秒（与追打同一套纪律），否则挂机每拍重发同一条寻路")
		_判(_托管._拾取在走 == null, "拉黑之后这条承诺要一起清掉（实得 %s）" % str(_托管._拾取在走))
		_托管.拾取或打怪(false)
		_判(str(_托管.状态文字) != "拾取",
				"拉黑之后不许再钉在那一枚上（应落到打怪/归位；实得 %s）" % str(_托管.状态文字))
		_托管._黑名单.clear()
		_托管._拾取在走 = null
	## ③ 寻路失败 ⇒ 拉黑 1.5 秒（先做阳性对照：这个落点确实到不了）
	_摆空闲态()
	## ⚠ 这一段的框要**只圈住极远那一枚**：前两段的金币可能已经解锁回到场上，
	## 用全图那么大的框会让『最近的一枚』变成它们 ⇒ 寻路成功、拉黑那条永远不跑（假不敏感）。
	var 巨区 := Rect2(_玩家.position.x + 890000.0, _玩家.position.y - 400.0, 20000.0, 800.0)
	var 老区: Rect2 = _托管._活动区
	_托管._活动区 = 巨区
	## 摆成**同高度、极远**：天上那种永远不落地（`drop_air` 一直真）⇒ 原版连查都查不到，
	## 判据就变成"没东西可捡"的假不敏感；同高度才既能落地、又寻不到路。
	## ⚠ 等的必须是**这一枚**（离线掉落号是 -1 往下走的序号，建之前先抄下来）：
	## 前两段留下的金币还挂在场上，"场子里有任意一枚"会立刻为真，而这一枚仍在飞。
	var 那号: int = int(实体.get("_离线掉落序号"))
	实体.call("_create_loot", Vector2(_玩家.position.x + 900000.0, _玩家.position.y))
	await _等这枚落地(实体, 巨区, 那号)
	var 远枚 = null
	for 掉 in (实体.call("挂机的掉落", 巨区) as Array):
		if int((掉 as Dictionary).get("object_id", 1)) == 那号:
			远枚 = 掉
			break
	_判(远枚 != null, "壬：夹具——极远那枚（号 %d）落地后要查得到（查不到这条支路根本没跑）" % 那号)
	if 远枚 != null:
		var 键 = int((远枚 as Dictionary).get("object_id", 0))
		_判(not bool(_玩家.call("走向", Vector2(float((远枚 as Dictionary).get("x", 0.0)),
				float((远枚 as Dictionary).get("y", 0.0)) - 5.0), true, false)),
				"壬：夹具自检——这个落点确实寻不到路（否则下面那条拉黑判据恒假）")
		_摆空闲态()
		_托管.拾取或打怪(false)
		_判(bool(_托管.黑名单里(键)), "寻路失败的目标要拉黑 1.5 秒（原版 `:784-:791`）")
	_托管._活动区 = 老区
	## ④ 途中顺手捡：**身上还有自动路线** + `(_帧 & 3)==0` ⇒ 身边 90×55 盒里的可捡物顺手捡掉
	## ⚠ 这里必须摆**真机挂机那个态**：屏幕上那行「自动寻路中」(`_玩家.自动寻路中`) 在挂机自己
	##   发的 `走向(落点, true, false)` 里是**假**（那一把只给小地图/任务那种 `自动=true` 的调用
	##   点亮）。上一版这里手工把它设成 true 才让判据过 ⇒ "途中顺手捡读错旗"这件事门全绿、
	##   真机上那一支一次都没跑过（10-19 在线腿实测：服务端掉 5 枚、挂机 0 次发拾取 ⇒
	##   用户报的"挂机自动拾取之后物品还在地面上"）。原版那一支的条件是 `isPathFinding()`。
	_摆空闲态()
	_玩家.set("自动寻路中", false)
	_玩家.set("click_move_active", true)
	_判(bool(_托管._在走路线()) and not bool(_玩家.get("自动寻路中")),
			"壬：夹具——挂机走路的态是『有路线、但没点亮那行提示』（实得 在走=%s 提示=%s）" % [
				str(_托管._在走路线()), str(bool(_玩家.get("自动寻路中")))])
	_托管.拾取发过.clear()
	## ⚠ 活动区要 temporarily 挪到别处：不然"空闲那一支"会先把这枚捡掉，量到的就不是途中那一条
	## （两支用的是同一个 `该不该捡 == 捡得动`，只能靠区域把它们分开）。
	var 老区四: Rect2 = _托管._活动区
	_托管._活动区 = Rect2(999990.0, 999990.0, 10.0, 10.0)
	实体.call("_create_loot", _玩家.position + Vector2(40.0, 0.0))
	var 盒 = _托管._途中盒()
	## ── ④ 途中盒的**尺寸**逐点判（原版 `GuajiHandler.as:852-853`
	##    `nearPickRect = player.outerBodyRect.clone(); nearPickRect.inflate(90, 55);`）
	##    · 身体盒 = `Character.as:80` 那个**固定** `_bodyRect = Rectangle(-27,-95,54,95)`
	##      （注册点在脚底 ⇒ x ∈ [-27,+27]、y ∈ [-95,0]），**不是**逐帧贴图盒（那是 `MonsterSprite` 给怪用的）；
	##    · `flash.geom.Rectangle.inflate(w,h)` = **中心不变、宽加 w、高加 h** ⇒ 每边只加**一半**。
	##    ⇒ x ∈ 我.x ± (27 + 45) = ±72；y 顶 = 我.y − (95 + 27.5) = −122.5；底 = 我.y + 27.5。
	##    这一族最容易算错成"四边各外扩 90/55"（⇒ ±117 / −150…），所以四个边界各判一次。
	var 我脚: Vector2 = _玩家.position as Vector2
	_判(absf(float((盒 as Rect2).size.x) - 144.0) < 0.01 and absf(float((盒 as Rect2).size.y) - 150.0) < 0.01,
			"④ 途中盒必须是 144×150（宽 = 54+90、高 = 95+55；`Character.as:80` + `inflate` 每边加一半；实得 %s）" % str((盒 as Rect2).size))
	_判(bool((盒 as Rect2).has_point(我脚 + Vector2(71.9, 0.0))), "④ 右边界内沿 +71.9 要算在盒里（实得 %s）" % str(盒))
	_判(not bool((盒 as Rect2).has_point(我脚 + Vector2(72.1, 0.0))), "④ 越过右边界 +72.1 就不许算在盒里")
	_判(bool((盒 as Rect2).has_point(我脚 + Vector2(-71.9, 0.0))), "④ 左边界内沿 −71.9 要算在盒里（左右必须对称，注册点在脚底不在身侧）")
	_判(not bool((盒 as Rect2).has_point(我脚 + Vector2(-72.1, 0.0))), "④ 越过左边界 −72.1 就不许算在盒里")
	_判(bool((盒 as Rect2).has_point(我脚 + Vector2(0.0, -122.4))), "④ 头顶上沿内 −122.4 要算在盒里（−95−27.5）")
	_判(not bool((盒 as Rect2).has_point(我脚 + Vector2(0.0, -122.6))), "④ 越过上沿 −122.6 就不许算在盒里")
	_判(bool((盒 as Rect2).has_point(我脚 + Vector2(0.0, 27.4))), "④ 脚下下沿内 +27.5 一侧要算在盒里（inflate 将**中心**下移 ⇒ 脚底下还有 27.5）")
	_判(not bool((盒 as Rect2).has_point(我脚 + Vector2(0.0, 27.6))), "④ 越过下沿 +27.6 就不许算在盒里（写成 ±122.5 那种硬编这条会红）")
	await _等落地(实体, 盒, 1)
	var 前: int = (实体.call("挂机的掉落", 盒) as Array).size()
	_判(前 > 0, "壬：夹具——身边盒里要有一枚（实得 %d）" % 前)
	_判((实体.call("挂机的掉落", _托管._活动区) as Array).is_empty(),
			"壬：夹具——空闲那一支此刻要查不到东西（活动区已挪走），否则下面量不到途中那一条")
	_托管._帧 = 3
	_托管._预热过 = 99999.0
	_托管.拍(16.7)
	## 原版途中顺手捡那一条调的也是 `pickDropItem` —— **只排队，不当场发帧**（发帧在另一条
	## ENTER_FRAME 上，下一帧才吞一枚）。所以这里要两拍才看得见"地上少一枚"。
	_判((_托管.拾取队列 as Array).size() >= 1,
			"壬：途中那一枚要先排进拾取队列（原版 `:1219-1227` 只 push）；实得 %s" % str(_托管.拾取队列))
	_托管.拍(16.7)
	_判((实体.call("挂机的掉落", 盒) as Array).size() < 前,
			"寻路途中每 4 帧要把身边盒里的可捡物顺手捡掉（原版 `:848-:863`；前 %d 后 %d）" % [前, (实体.call("挂机的掉落", 盒) as Array).size()])
	_判((_托管.拾取发过 as Array).size() > 0,
			"途中这一发要留在 `拾取发过` 里（在线腿靠这份记录钉『说要捡的最后必须从地上消失』；实得 %s）"
					% str(_托管.拾取发过))
	_托管._活动区 = 老区四
	_玩家.set("click_move_active", false)


# ── 癸：嗑药的四条闸（每 4 帧 / 血线 / 开关 / 漏蓝 / 死了）──────────────
func _癸_嗑药闸() -> void:
	var 备份 = _备份背包()
	_重开()
	_等预热带过()
	_会话.player_stats["max_hp"] = 100
	_会话.player_stats["max_mp"] = 100
	_改配置("auotReplyHpValue", 70)
	_改配置("auotReplyMpValue", 50)
	_改配置("autoReplyHp", true)
	_改配置("autoReplyMp", true)
	_摆背包([{"id": "03000001", "quantity": 4}, {"id": "04000001", "quantity": 4}])
	_会话.player_stats["hp"] = 50
	_会话.player_stats["mp"] = 30
	_托管._药冷却.clear()
	_托管._预热过 = 99999.0
	## ① 帧节流：`(_帧 & 3)==0` 那一拍才嗑
	_托管._帧 = 4
	_托管.拍(16.7)
	_判(_数量("03000001") == 4, "第 5 帧（5&3≠0）不许嗑血药（实得 %d 个）" % _数量("03000001"))
	_托管._帧 = 3
	_托管.拍(16.7)
	_判(_数量("03000001") == 3, "第 4 帧（4&3==0）且血线 50%%<70%% ⇒ 要嗑一颗（实得 %d 个）" % _数量("03000001"))
	## ② 蓝也一样，但身上有"漏蓝"增益时不补
	_托管._药冷却.clear()
	_托管._帧 = 3
	_托管.拍(16.7)
	_判(_数量("04000001") == 3, "第 4 帧且蓝 30%%<50%% ⇒ 要嗑一颗蓝药（实得 %d 个）" % _数量("04000001"))
	_会话.hud_state["buffs"] = [{"type": 10, "skill_id": 0}]
	_托管._药冷却.clear()
	_托管._帧 = 3
	_会话.player_stats["mp"] = 10
	_托管.拍(16.7)
	_判(_数量("04000001") == 3, "有 LOSE_MP(10) 增益时不补蓝（原版 `isPlayerLoseMp:338-342`；实得 %d 个）" % _数量("04000001"))
	_会话.hud_state["buffs"] = []
	## ③ 开关关掉 ⇒ 一档都不嗑
	_改配置("autoReplyHp", false)
	_托管._药冷却.clear()
	_会话.player_stats["hp"] = 20
	_托管._帧 = 3
	_托管.拍(16.7)
	_判(_数量("03000001") == 3, "『自动吃药』关掉 ⇒ 血线再低也不嗑（原版 `:263` 把档位算成 0）")
	_改配置("autoReplyHp", true)
	## ④ 血线没到 ⇒ 不嗑
	_托管._药冷却.clear()
	_会话.player_stats["hp"] = 90
	_托管._帧 = 3
	_托管.拍(16.7)
	_判(_数量("03000001") == 3, "血 90%% > 线 70%% ⇒ 不嗑（实得 %d 个）" % _数量("03000001"))
	## ⑤ 死了 ⇒ 血药那一支整个不走（`!player.isDie`），并且按死亡那条停/复活
	_改配置("autoReply", false)
	_托管._药冷却.clear()
	_会话.player_stats["hp"] = 0
	_托管._帧 = 3
	_托管.拍(16.7)
	_判(_数量("03000001") == 3, "死了不嗑药（原版 `!player.isDie` 与嗑药同一条 if）")
	## ⑥ 缺血/缺蓝提示：**一次性 + 回到线以上重新上膛**（2026-10-31 用户报"一直发没有可吃的血药"）。
	##    原版 `UIMain2.as:5903-5907` / `:2496-2502` 的 `_isShowTipNoHPItems` 飘一句就置假，
	##    重新上膛只在 `CharactorInfoPane.as:606` / `:211`（`percent > auotReplyHpValue`）。
	_摆背包([])						# 背包里没有药
	_会话.hud_state["buffs"] = []		# 别落在漏蓝分支上
	_托管._缺血药可提示 = true
	_托管._缺蓝药可提示 = true
	var 缺血: Array[String] = []
	var 缺蓝: Array[String] = []
	var 接缺 := func(句: String) -> void:
		if "没有可吃的血药" in 句:
			缺血.append(句)
		elif "没有可吃的查克拉药" in 句:
			缺蓝.append(句)
	_会话.notification_requested.connect(接缺)
	for 轮 in 3:
		_会话.player_stats["hp"] = 50		# 50% < 70%，每拍压回去（防挂机循环把血改了）
		_会话.player_stats["mp"] = 30		# 30% < 50%
		_托管._帧 = 3
		_托管.拍(16.7)
	_判(缺血.size() == 1, "缺血药：血线以下连拍三拍只许飘一句（原版 `_isShowTipNoHPItems` 一次性；实得 %d 句）" % 缺血.size())
	_判(缺蓝.size() == 1, "缺蓝药：蓝线以下连拍三拍只许飘一句（实得 %d 句）" % 缺蓝.size())
	_判(not bool(_托管._缺血药可提示) and not bool(_托管._缺蓝药可提示),
			"飘完那两句的闸要置假（否则下一拍又飘）")
	## 上膛支：`setHP`/`setMP` 在 `percent > auotReplyHpValue` 时置真
	_会话.player_stats["hp"] = 90			# 90% > 70%
	_会话.player_stats["mp"] = 90			# 90% > 50%
	_托管._帧 = 3
	_托管.拍(16.7)
	_判(bool(_托管._缺血药可提示) and bool(_托管._缺蓝药可提示),
			"血/蓝回到线以上 ⇒ 重新上膛（原版 `CharactorInfoPane.as:606`/`:211`）")
	_判(缺血.size() == 1 and 缺蓝.size() == 1,
			"上膛那一拍只置闸、不许补飘（实得 血 %d / 蓝 %d）" % [缺血.size(), 缺蓝.size()])
	_会话.player_stats["hp"] = 50
	_会话.player_stats["mp"] = 30
	_托管._帧 = 3
	_托管.拍(16.7)
	_判(缺血.size() == 2, "重新掉到血线以下 ⇒ 再飘一句（实得 %d 句）" % 缺血.size())
	_判(缺蓝.size() == 2, "重新掉到蓝线以下 ⇒ 再飘一句（实得 %d 句）" % 缺蓝.size())
	_会话.notification_requested.disconnect(接缺)
	_会话.player_stats["hp"] = 100
	_还原背包(备份)


# ── 子：三瓶双倍的排程（每 8 帧 / 已有 buff 不吃 / 2 秒本地冷却 / 开关）──
func _子_双倍药() -> void:
	var 备份 = _备份背包()
	_重开()
	_等预热带过()
	_摆背包([{"id": "15002001", "quantity": 3}])
	_改配置("autoUseEpDrug", true)
	_会话.hud_state["effects"] = []
	_托管._药冷却.clear()
	## ⚠ 这三瓶是 **buff 族**，离线那支 `use_inventory_item` 明说"效果要在服务端结算"
	## 并**不消耗**（`游戏会话.gd` 的离线仿真只仿回血/回蓝/金币/开盒四类）。
	## 所以这一段落**不能数背包**，只数"到底有没有下手"——用那条拒因飘条当探针。
	var 飘: Array[String] = []
	var 接 := func(句: String) -> void: 飘.append(句)
	_会话.notification_requested.connect(接)
	_托管._帧 = 1
	_托管.拍双倍药()
	_判(飘.is_empty(), "第 1 帧（1&7≠0）连手都不许下（实得 %d 句）" % 飘.size())
	_托管._帧 = 0
	_托管.拍双倍药()
	_判(飘.size() == 1 and "双倍经验符" in 飘[0],
			"帧号对齐 8 的倍数 ⇒ 要真的去用那一瓶（离线只到'下手'这一步；实得 %s）" % str(飘))
	_托管._药冷却["15002001"] = 1500.0
	飘.clear()
	_托管._帧 = 8
	_托管.拍双倍药()
	_判(飘.is_empty(), "本地 2 秒冷却里再到点也不许再下手（原版 `itemCoolMap` + `cd=2000`）")
	_托管._药冷却.clear()
	_会话.hud_state["effects"] = [{"item_id": "15002001", "remaining_seconds": 10.0}]
	飘.clear()
	_托管._帧 = 0
	_托管.拍双倍药()
	_判(飘.is_empty(), "身上已经有这瓶的 buff ⇒ 不重复嗑（原版 `:868-:874`）")
	_会话.hud_state["effects"] = []
	_改配置("autoUseEpDrug", false)
	飘.clear()
	_托管._帧 = 0
	_托管.拍双倍药()
	_判(飘.is_empty(), "那枚勾关掉 ⇒ 一次都不嗑（实得 %d 句）" % 飘.size())
	_改配置("autoUseEpDrug", true)
	_会话.notification_requested.disconnect(接)
	_判(_数量("15002001") == 3, "离线不该把 buff 族扣掉（扣了就是本地自造服务端结算；实得 %d 个）" % _数量("15002001"))
	_托管._药冷却.clear()
	_还原背包(备份)


# ── 丑：五枚辅助的排程与两档补血的先后 ───────────────────────────────
func _丑_辅助排程() -> void:
	var 槽备份: Array = []
	for 格 in _会话.skill_slots.size():
		槽备份.append((_会话.skill_slots[格] as Dictionary).duplicate(true))
	var 学备份 = _备份已学()
	## ⚠ **槽与已学要一起喂**：`get_skill_in_slot()` 是拿槽里的 id **回 learned_skills 找那条**
	## （`游戏会话.gd:555-560`，找不到就回空字典）⇒ 只改槽等于什么都没学，`_号在哪个槽()`
	## 恒 -1、`能施放()` 恒假，整段五枚辅助判据全在 0 比 0（10-18 第二轮实测）。
	_会话.skill_slots.clear()
	_会话.learned_skills.clear()
	for 号 in ["3001", "3000", "3002"]:
		_会话.skill_slots.append({"id": 号, "level": 1})
		_会话.learned_skills.append(_造已学(号))
	_改配置("autoWulinEffect", false)
	_改配置("autoZhanYiEffect", false)
	_改配置("autoShouhu", false)
	_改配置("autoZaiSheng", true)
	_改配置("autoZhangXian", false)
	_会话.player_stats["max_hp"] = 100
	_托管._冷却.clear()
	## ① 帧节流：`(_帧 & 15)!=0` 那一拍整段不走
	_会话.player_stats["hp"] = 50
	## `能施放` 里那三闸要过：**3001/3002 一级各 13 蓝**（`数据/技能消耗.json` 的 0003001/0003002），
	## 上一段留给我的 mp 是 10 ⇒ 蓝档就把整段挡死（那种红与排程无关，是夹具没喂够）。
	_会话.player_stats["mp"] = 900
	_会话.player_stats["max_mp"] = 900
	_会话.player_stats["zq"] = 900000
	_托管._帧 = 1
	_托管.拍辅助()
	_判(bool(_托管.能施放(3001)), "丑：夹具——3001 已学、蓝够、精够，`能施放` 必须为真（否则下面全是 0 比 0）")
	_判(not bool(_托管._在冷却(3001)), "第 1 帧（1&15≠0）群疗不该放（原版每 16 帧一档）")
	## ② 到点 + 缺血 ⇒ 放，并且放完自己记冷却
	_托管._帧 = 0
	_托管.拍辅助()
	_判(bool(_托管._在冷却(3001)), "血 50%%<98%% 且开了群疗 ⇒ 那一拍要放出去（放了才记冷却）")
	## ③ 放过群疗 ⇒ 这一拍不再走单疗那档（原版 `supportSkillFired` 之后直接 return）
	_托管._冷却.clear()
	_改配置("autoZhangXian", true)
	_会话.player_stats["hp"] = 50
	_托管._帧 = 0
	_托管.拍辅助()
	_判(bool(_托管._在冷却(3001)) and not bool(_托管._在冷却(3000)),
			"这拍放了群疗就不许再放掌仙术（原版 `:931` 的 return；群 %s / 单 %s）"
			% [str(_托管._在冷却(3001)), str(_托管._在冷却(3000))])
	## ④ 血满 ⇒ 两档都不放
	_托管._冷却.clear()
	_会话.player_stats["hp"] = 100
	_托管._帧 = 0
	_托管.拍辅助()
	_判(not bool(_托管._在冷却(3001)) and not bool(_托管._在冷却(3000)),
			"血 100%% ≥ 98%% ⇒ 群疗/单疗都不放")
	## ⑤ 加攻/加防那两枚：已经有同名增益时不续（原版 `hasBuffOfSkill`）
	_托管._冷却.clear()
	_改配置("autoZaiSheng", false)
	_改配置("autoZhangXian", false)
	_改配置("autoWulinEffect", true)
	_托管._冷却.clear()
	_会话.hud_state["buffs"] = [{"type": 14, "skill_id": 3002}]
	_托管._帧 = 0
	_托管.拍辅助()
	_判(not bool(_托管._在冷却(3002)), "身上已经挂着 3002 的增益 ⇒ 不续（原版 `hasBuffOfSkill:1357-1361`）")
	_会话.hud_state["buffs"] = []
	_托管._帧 = 0
	_托管.拍辅助()
	_判(bool(_托管._在冷却(3002)), "没挂增益且开了『天之咒印』⇒ 那一拍要放")
	_改配置("autoWulinEffect", false)
	## ── ④ 三档 buff 的判据**原文不是一条**（`GuajiHandler.as:896-:923`）：
	##   buff1 `:898` = `!hasBuffOfSkill(id) && canUseSkill(id)` —— **不查 isCooling**
	##   buff2 `:906` = 同上 —— **不查 isCooling**
	##   buff3 `:914` = `!isCooling(id) && canUseSkill(id)` —— **查冷却、不查有没有增益**
	## 上一版对三档统一 `_在冷却() → continue` ⇒ 增益图标刚掉、本地那份冷却表还在转的那一段，
	## 原版立刻补上咒印、我们干等着。
	_会话.skill_cooldowns.clear()			# 上一发 3002 的**会话侧**冷却要摘掉，否则量不到"补放"
	_玩家.set("出手中", false)
	_玩家.set("attack_cooldown", 0.0)
	var 施法前 := int(_玩家.get("施法次数"))
	var 应CD3002 := float(_会话.GAME_DATA.skill("3002").get("cooldown", 0.0)) * 1000.0
	_托管._冷却["3002"] = 5000.0				# 本地冷却表里还挂着（一个与这一招 CD 不同的值）
	_会话.hud_state["buffs"] = []				# 身上确实没有这招的增益
	_改配置("autoWulinEffect", true)
	_托管._帧 = 0
	_托管.拍辅助()
	prints("探针丑·buff1 施法=", int(_玩家.get("施法次数")), "出手中=", str(_玩家.get("出手中")),
			"能放招=", str(_玩家.call("_能放招")), "fh=", str(_玩家.get("current_fh_id")),
			"on_ground=", str(_玩家.get("on_ground")), "槽=", int(_托管._号在哪个槽(3002)),
			"冷却表=", str(_托管._冷却.get("3002")), "会话冷却=", str(_会话.get_skill_cooldown(_托管._号在哪个槽(3002))),
			"mp=", str(_会话.player_stats.get("mp")), "在跑=", str(_托管.在跑), "帧=", int(_托管._帧))
	_判(int(_玩家.get("施法次数")) == 施法前 + 1,
			"buff1(天之咒印) 只判『没挂增益 + canUseSkill』，**不判本地冷却**（`:898`）⇒ 冷却表里还挂着也要补（施法 %d→%d）" % [施法前, int(_玩家.get("施法次数"))])
	_判(absf(float(_托管._冷却["3002"]) - 应CD3002) < 0.01,
			"放过之后要把本地冷却**写成这一招自己的 CD**（`:899-:903`；实得 %s / 应 %s）" % [str(_托管._冷却.get("3002")), str(应CD3002)])
	## buff3(生死相许 3305) 反过来：`:914` 判的**就是** `!isCooling` ⇒ 冷却里整支都不许走。
	## ⚠ 不能用 `_在冷却()` 的真假当证据（冷却是我自己摆的），要判"表里那个值有没有被改写"。
	_会话.learned_skills.append(_造已学("3305"))
	_会话.skill_slots.append({"id": "3305", "level": 1})
	_改配置("autoWulinEffect", false)
	_改配置("autoZhanYiEffect", false)
	_改配置("autoShouhu", true)
	_会话.player_stats["mp"] = 200				# 3305 一级耗 110 蓝（`数据/技能消耗.json` 的 0003305）
	_会话.player_stats["zq"] = 900000
	var 应CD3305 := float(_会话.GAME_DATA.skill("3305").get("cooldown", 0.0)) * 1000.0
	_判(bool(_托管.能施放(3305)) and 应CD3305 > 0.0,
			"丑：夹具——3305 已学、蓝/精都够 ⇒ `能施放` 必须为真且 CD 查得到（否则下面两条恒真/恒假）")
	_托管._冷却["3305"] = 5000.0
	_托管._帧 = 0
	_托管.拍辅助()
	_判(absf(float(_托管._冷却["3305"]) - 5000.0) < 0.01,
			"buff3(生死相许) 在本地冷却里 ⇒ 整支跳过，**连冷却表都不许改写**（`:914` 判的就是 `!isCooling`；实得 %s）" % str(_托管._冷却.get("3305")))
	_托管._冷却.clear()
	_会话.skill_cooldowns.clear()
	_玩家.set("出手中", false)
	_托管._帧 = 0
	_托管.拍辅助()
	_判(absf(float(_托管._冷却.get("3305", -1.0)) - 应CD3305) < 0.01,
			"丑·阳：把冷却表摘掉，同一支就要走进去并把它自己的 CD 写回去（没这条上面那条就是恒真；实得 %s / 应 %s）" % [str(_托管._冷却.get("3305")), str(应CD3305)])
	_改配置("autoShouhu", false)
	_还原已学(学备份)
	_会话.skill_slots.clear()
	for 格 in 槽备份:
		_会话.skill_slots.append(格)


## 按生产方的形状造一条"已学"：`离线示例数据._skill()` 就是 **表行 duplicate + 覆盖**。
## 只写 {id, level} 会让 `_rebuild_skill_slots()` 的 `skill.name` 点号取键当场炸
## （`游戏会话.gd:2898`），等级加到一半死 ⇒ 既不 emit 也不落盘，看着像实现的 bug，
## 其实是夹具缺字段（10-18 深夜实测）。
func _造已学(号: Variant, 等级 := 1) -> Dictionary:
	var 条: Dictionary = (_会话.GAME_DATA.skill(str(号)) as Dictionary).duplicate(true)
	条["id"] = str(号)
	条.merge({"level": 等级, "max_level": 20, "master_level": 0}, true)
	return 条


func _备份已学() -> Array:
	var 出: Array = []
	for 技 in _会话.learned_skills:
		出.append((技 as Dictionary).duplicate(true))
	return 出


## 快捷栏也要能整排备份/还原（庚段要判"这一招没上栏"，就得真的把栏清空）。
func _备份槽位() -> Array:
	var 出: Array = []
	for 格 in _会话.skill_slots.size():
		出.append((_会话.skill_slots[格] as Dictionary).duplicate(true))
	return 出


func _还原槽位(备份: Array) -> void:
	_会话.skill_slots.clear()
	for 格 in 备份:
		_会话.skill_slots.append(格)


func _还原已学(备份: Array) -> void:
	_会话.learned_skills.clear()
	for 技 in 备份:
		_会话.learned_skills.append(技)


## 寅那段要改 `level/gold/zq`（+hp/max_hp/**remaining_sp**）才凑得出升级需求，**这些键别的段也读**：
## 己按等级筛血药、卯按金币判买卖。还回去之前它就是下一段的假红
## （10-19 实测：血药表从 2 条掉成 1 条、"大瓶优先/小瓶优先"跟着红）。
## ⚠ `remaining_sp` 也在这张表里：本工程的 `游戏会话.upgrade_skill():1128-1130` 头一道就是
## `remaining_sp <= 0 ⇒ "忍术点不足" return false` —— 那是**我们这侧的闸**，原版三档之外，
## 寅 要判"三档都够 ⇒ 真升一级"就必须先把它摆开（摆开≠放宽：判据仍钉"升了一级"）。
func _备份人物三键() -> Dictionary:
	var 出 := {}
	for 键名 in ["level", "gold", "zq", "max_hp", "hp", "remaining_sp"]:
		出[键名] = _会话.player_stats.get(键名, 0)
	return 出


func _还原人物三键(备份: Dictionary) -> void:
	for 键名 in 备份:
		_会话.player_stats[键名] = 备份[键名]


# ── 寅：自动升级真的升一级（三档闸，逐条按表算）───────────────────────
func _寅_自动升级() -> void:
	var 技备份 = _备份已学()
	var 人物备份 = _备份人物三键()
	_会话.player_stats["max_hp"] = 100
	_会话.player_stats["hp"] = 100
	## 从**表里**挑一条"一级→二级"有完整三项需求的招式，需求值全部按表反推，
	## 人物属性摆到刚好够 —— 期望是"等级 +1"，不是"代码说升了就升了"。
	var 号 := 0
	var 需: Array = []
	for 候 in range(1001001, 1001004):
		var 行: Array = _会话.GAME_DATA.skill_upgrade_req(2, 候)
		if 行.size() >= 3:
			号 = 候
			需 = 行
			break
	_判(号 > 0, "寅：夹具——要在技能升级需求表里找到一条能升的招式（表里没有就这段没判）")
	if 号 <= 0:
		_收尾("寅：没有升级需求表数据")
		return
	_会话.learned_skills.clear()
	_会话.learned_skills.append(_造已学(号))
	_会话.player_stats["level"] = maxi(1, int(需[0]))
	_会话.player_stats["gold"] = maxi(0, int(需[1]))
	_会话.player_stats["zq"] = maxi(0, int(需[2]))
	_会话.player_stats["remaining_sp"] = 5				# 本工程的第四道闸（见 `_备份人物三键` 那条）
	_判(int(_会话.player_stats.get("remaining_sp", 0)) > 0,
			"寅：夹具——要有可花的忍术点（`upgrade_skill:1128` 第一道就咽掉 ⇒ 下面两条量不到三档）")
	_改配置("autoUpgradeSkill", true)
	_托管._升级毫秒 = 0.0
	_托管.在跑 = true
	_托管.拍自动升级(1400.0)
	_判(_技能等级(号) == 1, "没攒够 1500ms 之前不许升（原版 `AUTO_UPGRADE_SKILL_INTERVAL`）")
	_托管.拍自动升级(200.0)
	_判(_技能等级(号) == 2, "攒够 1500ms 且三档需求都够 ⇒ 真的升一级（实得 %d 级）" % _技能等级(号))
	## 差一条就不许升：把人物等级降到需求之下
	_会话.learned_skills.clear()
	_会话.learned_skills.append(_造已学(号))
	_会话.player_stats["level"] = maxi(0, int(需[0]) - 1)
	_托管._升级毫秒 = 0.0
	_托管.拍自动升级(2000.0)
	_判(_技能等级(号) == 1, "人物等级低于需求 ⇒ 不升（原版 `:424` getSkillReqLevel）")
	_还原已学(技备份)
	_还原人物三键(人物备份)


func _技能等级(号: int) -> int:
	for 技 in _会话.learned_skills:
		if int(str((技 as Dictionary).get("id", "0"))) == 号:
			return int((技 as Dictionary).get("level", 0))
	return 0


# ── 卯：该不该卖（原版 shouldAutoSellPickedEquip 六条 + 卖装那三枚前置）──
func _卯_卖装闸() -> void:
	var 件 = func(号: String, 品 := 1, 强 := 0, 镶 := [], 位 := 1) -> Dictionary:
		return {"id": 号, "aptitude": 品, "strengthen": 强, "inlay_list": 镶, "position": 位}
	_判(bool(_托管.该卖这件(件.call("01100001"))), "玩家装备(段 110)、品质<紫、没强化没镶 ⇒ 该卖（原版 `:524-:555`）")
	_判(bool(_托管.该卖这件(件.call("02000001"))), "宠物装备(段 200) 同样该卖")
	_判(not bool(_托管.该卖这件(件.call("01210001"))), "段 121 被原版点名排除 ⇒ 不许卖")
	_判(not bool(_托管.该卖这件(件.call("02050001"))), "段 205 被原版点名排除 ⇒ 不许卖")
	_判(not bool(_托管.该卖这件(件.call("01100001", 4))), "品质 ≥ 紫(4) ⇒ 不卖")
	_判(not bool(_托管.该卖这件(件.call("01100001", 1, 3))), "强化过(strengthen>0) ⇒ 不卖")
	_判(not bool(_托管.该卖这件(件.call("01100001", 1, 0, [{"id": "1"}]))), "镶过宝石 ⇒ 不卖")
	_判(not bool(_托管.该卖这件(件.call("01100001", 1, 0, [], 0))), "position=0 是穿在身上而不是背包里 ⇒ 不卖")
	_判(not bool(_托管.该卖这件(件.call("03000001"))), "回血药（段 300）不在装备号段里 ⇒ 不卖")
	## 三枚前置：没在挂 / 没勾卖 / 没勾捡装备 ⇒ 计时器一律清零（原版 `:376-:384`）
	_改配置("autoSellPickedEquip", true)
	_改配置("autoCollect", true)
	_托管.在跑 = false
	_托管._卖装毫秒 = 400.0
	_托管.拍背包满卖装(200.0)
	_判(float(_托管._卖装毫秒) == 0.0, "没在挂机 ⇒ 卖装计时器必须清零（实得 %s）" % str(_托管._卖装毫秒))
	_托管.在跑 = true
	_改配置("autoCollect", false)
	_托管._卖装毫秒 = 400.0
	_托管.拍背包满卖装(200.0)
	_判(float(_托管._卖装毫秒) == 0.0, "『拾取』那枚总闸关着 ⇒ 卖装整条支线都不跑（原版 `_isPickEquip`）")
	_改配置("autoCollect", true)
	_改配置("autoSellPickedEquip", false)
	_托管._卖装毫秒 = 400.0
	_托管.拍背包满卖装(200.0)
	_判(float(_托管._卖装毫秒) == 0.0, "没勾『自动卖装备』⇒ 计时器清零")
	## 背包不满 ⇒ 也不跑（原版要 `bagIsFull`）
	_改配置("autoSellPickedEquip", true)
	_改配置("collectQuality", 0)
	_托管._卖装毫秒 = 400.0
	_托管.拍背包满卖装(200.0)
	_判(float(_托管._卖装毫秒) == 0.0 or _背包不满(),
			"背包没满 ⇒ 不该攒卖装计时（不满时这一支直接 return）")
	## ── ⑪ 卖装那一发传的**格数**必须与服务端同一把尺子（`_会话.背包总格数()`），不许是常量 96
	## 原版 `GuajiHandler.as:386` → `WaiGuaHandler.onPackFull():324-342` 第一句
	## `requestNpcShopSellAllNormalEquips(APTITUDE_GREEN=3, 0)`；本工程
	## `request_npc_shop_one_key_sell(商店, 格数, 品质档)` 那头**按格数逐格扫** ⇒
	## 传 96（`游戏会话.gd` 那个 `格容量` 常量，原版只是 `commonSlots<=0` 的**回退值**）
	## 会多扫出不存在的格子。同族 `_有空槽/_背包满` 早就吃 `背包总格数()`，这里不许留第二把尺子。
	var 备卯 = _备份背包()
	var 容量备份 = _后端.get("authoritative_bag_capacity")
	var 真后端 = _托管._后端
	var vip备份 = _会话.player_stats.get("vip", 0)
	var 记录 := 记录后端.new()
	root.add_child(记录)
	_托管._后端 = 记录
	_会话.player_stats["vip"] = 0				# 2026-10-25 报修 5.1：`GuajiHandler.as:276` 那道
	## `&& vipLevel >= GUAJI_AUTO_SELL_EQUIP_LEVEL(=5)` 整条删了 ⇒ 这里**故意摆成没 VIP**，
	## 下面那一发卖装照发就是"闸真没了"的钉子（写回 1 就把这条判据悄悄吃掉了）。
	_改配置("autoSellPickedEquip", true)
	_改配置("autoCollect", true)
	_托管.在跑 = true
	for 容 in [2, 5]:
		_后端.set("authoritative_bag_capacity", 容)
		_摆背包([])
		for _格 in int(容):
			_会话.inventory.append({"id": "01100001", "quantity": 1, "aptitude": 1, "position": 1})
		_托管._配置缓存 = _托管.读配置快照()
		_判(bool(_托管._背包满()) and int(_会话.背包总格数()) == int(容),
				"卯：夹具——塞满 %s 格就该判『背包满』且总格数就得跟着权威值（实得 满=%s 总=%d）" % [str(容), str(bool(_托管._背包满())), int(_会话.背包总格数())])
		_托管._卖装毫秒 = 0.0
		记录.卖装.clear()
		_托管.拍背包满卖装(600.0)
		_判(记录.卖装.size() == 1,
				"卯：夹具——三前置都开着 + 背包满 + 攒够 500ms ⇒ 必须真的发一发卖装（实得 %s）" % str(记录.卖装))
		if not 记录.卖装.is_empty():
			var 传的格 := int((记录.卖装[0] as Array)[1])
			_判(传的格 == int(容),
					"⑪ 那一发传的格数必须是 `背包总格数()`（=%s），不是常量 96（实得整包 %s）" % [str(容), str(记录.卖装[0])])
			_判(int((记录.卖装[0] as Array)[2]) == 3,
					"品质档要按原版 `APTITUDE_GREEN = 3` 传（实得 %s）" % str((记录.卖装[0] as Array)[2]))
	_托管._后端 = 真后端
	_后端.set("authoritative_bag_capacity", 容量备份)
	_会话.player_stats["vip"] = vip备份
	_还原背包(备卯)
	记录.free()
	_改配置("autoSellPickedEquip", false)
	_托管._卖装毫秒 = 0.0


func _背包不满() -> bool:
	return not bool(_托管._背包满())


# ── 辰：1808:0 只在开挂后第一拍发一次（不是每帧发）───────────────────
## 原版那一条闸是 `tick():693-697`：`if (!_isSendBuff) { _isSendBuff = true; requestHang_startHang(); }`，
## 而 `_isSendBuff` 只由 `setConfig():237` 摆回 false ⇒ **每一趟开挂发一发**，不是每一帧一发。
## ⚠ 预热（`:602-605`）排在它**前面** ⇒ "预热没过一发都不许发"这一条必须拿一份**没付过预热的
##   干净实例**来判（`pastTime2` 一个客户端生命周期只付一次，见 乙）。那份实例的后端换成
##   `in_game = true` 的记录桩 ⇒ `_上行()` 走**在线那一支**（原版 `GuajiHandler` 自己 put_data，
##   不回头改 isStart），既不会被离线那份本地广播牵进本门别的段，也不会被防抖那一处干扰。
func _辰_上行只发一次() -> void:
	_会话.hud_state["pk_mode"] = 1				# 免得那份实例的开挂动作顺带发一发改模式上行
	var 清: Node = load("res://脚本/角色/挂机托管.gd").new()
	_玩家.add_child(清)
	var 桩 := 记录挂上行.new()
	root.add_child(桩)
	清.set("_后端", 桩)
	清.set("_防抖剩余", 0.0)
	清.call("置挂机态", true)
	_判(bool(清.get("在跑")) and int(桩.停) == 0, "辰：夹具——那份干净实例要真的开着挂（且开挂不算停）")
	_判(float(清.get("_预热过")) == 0.0, "辰：夹具——那份实例的预热必须是没付过的（实得 %s）" % str(清.get("_预热过")))
	清.call("拍", 700.0)
	_判(int(桩.开) == 0 and int(清.get("_帧")) == 0,
			"预热还没跨过 800ms 时一帧都不走、一发都不许发（`:602-605` 排在 `:693-697` 之前；发 %d 帧 %d）" % [int(桩.开), int(清.get("_帧"))])
	清.call("拍", 200.0)
	_判(int(桩.开) == 0, "累计刚跨过 800 的那一拍依然 return，不发（原版同一句；实发 %d 次）" % int(桩.开))
	清.call("拍", 16.7)
	_判(int(桩.开) == 1, "过了预热的第一拍要发一次 1808:0（实发 %d 次）" % int(桩.开))
	_判(bool(清.get("_已发上行")), "发过之后 `_isSendBuff` 要立起来（`:695`）")
	for _i in 20:
		清.call("拍", 16.7)
	_判(int(桩.开) == 1, "后面 20 拍一次都不许再发（实发 %d 次；原版 `:693-697` 只发一次）" % int(桩.开))
	_判(int(桩.停) == 0, "挂着的这几拍一发 1808:1 都不许发（实发 %d 次）" % int(桩.停))
	清.set("_会话", null)			# 摘掉会话引用再 free：不许那份实例的离树收尾去动真会话
	清.free()
	桩.free()
	await _等帧(1)
	var 次数: Array[int] = [0]
	var 接 := func(状: Dictionary) -> void:
		if bool(状.get("active", false)):
			次数[0] += 1
	_会话.hang_changed.connect(接)
	_会话.request_hang(false)
	_托管.拍(1200.0)
	次数[0] = 0
	_会话.request_hang(true)
	_判(bool(_托管.在跑), "辰：这一段真的开起来了")
	_判(not bool(_托管._已发上行), "刚点开时还没发过 1808:0（原版在 tick 里发，不在 setter 里发）")
	var 开局 = 次数[0]
	_托管.拍(900.0)						# 这一拍只是**跨过** 800ms 阈值就 return（原版同一句）
	_判(次数[0] == 开局 + 1, "主实例这份的预热在 甲 段就付完了（`pastTime2:66` 全份没有清零点）⇒ 这一拍就是开挂后的第一拍，要发一次（实发 %d 次）" % (次数[0] - 开局))
	_托管.拍(16.7)						# 这才是第一拍 ⇒ 在这里发
	_判(次数[0] == 开局 + 1, "第二拍就不许再发了（`_isSendBuff` 已经立起来；实发 %d 次）" % (次数[0] - 开局))
	_判(bool(_托管._已发上行), "发过之后标志要立起来")
	for _i in 20:
		_托管.拍(16.7)
	_判(次数[0] == 开局 + 1, "后面 20 拍一次都不许再发（实发 %d 次；原版 `:693-:697` 只发一次）" % (次数[0] - 开局))
	_会话.hang_changed.disconnect(接)


# ── 巳：通灵兽招式真正落到出战宠物身上 + 三档命中盒 + 『宠物吃』是死字段 ──
func _巳_宠招() -> void:
	var 实体 = _玩家.get_parent().get_node_or_null("LifeRoot")
	if 实体 == null or not 实体.has_method("宠物伙伴节点"):
		_收尾("巳：LifeRoot 上要有 宠物伙伴节点() 这个取用口")
		return
	## 夹具：往会话里塞一只"出战"的宠物，再让 LifeRoot 用它自己那条链建伙伴节点
	## —— 这样托管找到的就是**真身**，不是我手搭的替身（替身=假宿主失配那一族假绿）。
	var 兽备份: Array = []
	for 兽 in _会话.pets:
		兽备份.append((兽 as Dictionary).duplicate(true))
	_会话.pets.clear()
	_会话.pets.append({"id": "07000001", "name": "夹具兽", "attack": 7, "deployed": true})
	实体.call("_refresh_pet_companion")
	var 伴: Node2D = 实体.call("宠物伙伴节点")
	_判(伴 != null and is_instance_valid(伴), "巳：夹具——出战宠物要真把伙伴节点建出来")
	if 伴 == null or not is_instance_valid(伴):
		_会话.pets.clear()
		for 兽 in 兽备份:
			_会话.pets.append(兽)
		实体.call("_refresh_pet_companion")
		_收尾("巳：宠物伙伴没建出来")
		return
	## ① 出厂就是 101（原版 `Pet.as:35 curSkillID = 101`），`|| 101` 兜住 0
	_判(int(伴.call("出手招式")) == 101, "没设过宠招时出手招式应为出厂 101（实得 %d）" % int(伴.call("出手招式")))
	伴.call("摆招式", 0)
	_判(int(伴.call("出手招式")) == 101, "宠招填 0 ⇒ 落回出厂那招（原版 `pet.curSkillID || 101`）")
	## ② 开挂机那一刻由托管写进去（原版 setter `:1256-1264` 只在 `_isStart` 为真时动）
	_改配置("autoChongwuSkillId", 103)
	_重开()
	_判(int(伴.call("出手招式")) == 103,
			"开了挂机就要把『通灵兽招式』写进出战宠物（原版 setConfig `:250` → setter；实得 %d）" % int(伴.call("出手招式")))
	_改配置("autoChongwuSkillId", 101)
	_重开()
	_判(int(伴.call("出手招式")) == 101, "换一档再开挂机 ⇒ 宠物跟着换（实得 %d）" % int(伴.call("出手招式")))
	## ③ 三档命中盒逐条按原版数字钉死（1 近身 100×100、2 远端 400×100、3 群体 300×300）
	var 位: Vector2 = 伴.global_position
	var 盒1: Rect2 = 伴.call("命中盒", 101, Vector2(位.x + 50.0, 位.y))	# 目标在右 ⇒ 朝右
	_判(absf(盒1.size.x - 100.0) < 0.01 and absf(盒1.size.y - 100.0) < 0.01,
			"101 近身档 = 100×100（实得 %s）" % str(盒1.size))
	_判(absf(盒1.position.x - 位.x) < 0.01 and absf(盒1.end.x - (位.x + 100.0)) < 0.01,
			"朝右时 101 的盒要压在宠物**右侧** [x, x+100]（实得 %s→%s）" % [str(盒1.position.x), str(盒1.end.x)])
	var 盒1左: Rect2 = 伴.call("命中盒", 101, Vector2(位.x - 50.0, 位.y))
	_判(absf(盒1左.position.x - (位.x - 100.0)) < 0.01 and absf(盒1左.end.x - 位.x) < 0.01,
			"朝左时同一个盒要镜像到 [-100, 0]（实得 %s→%s）" % [str(盒1左.position.x), str(盒1左.end.x)])
	var 盒2: Rect2 = 伴.call("命中盒", 102, Vector2(位.x + 300.0, 位.y))
	_判(absf(盒2.size.x - 400.0) < 0.01, "102 远端档宽 400（原版 `case 2: x=-400`；实得 %s）" % str(盒2.size.x))
	var 盒3: Rect2 = 伴.call("命中盒", 103, Vector2(位.x + 10.0, 位.y))
	_判(absf(盒3.size.x - 300.0) < 0.01 and absf(盒3.size.y - 300.0) < 0.01,
			"103 群体档 300×300（原版 `case 3`：左 −150 右 150 上 −200 下 100；实得 %s）" % str(盒3.size))
	_判(bool(伴.call("命中盒", 102, Vector2(位.x + 300.0, 位.y)).has_point(Vector2(位.x + 300.0, 位.y - 50.0))),
			"远端档要能打到 300 像素外的目标")
	_判(not bool(伴.call("命中盒", 101, Vector2(位.x + 300.0, 位.y)).has_point(Vector2(位.x + 300.0, 位.y - 50.0))),
			"近身档打不到 300 像素外 ⇒ 换了宠招，宠物能打多远真的会变")
	## ④ 『宠物吃』(`autoChongWuEat`) 在原版是**写了没人读**的死字段 ⇒ 这边也不许拿它做任何事
	_改配置("autoChongWuEat", true)
	_判(bool(_托管.读配置快照().get("宠物吃", false)), "『宠物吃』照样读进快照（页面上那枚勾要有去处）")
	_改配置("autoChongwuSkillId", 102)
	_托管._摆宠物招式()
	_判(int(伴.call("出手招式")) == 102, "『宠物吃』开关翻转后，宠招那一招不受影响（实得 %d）" % int(伴.call("出手招式")))
	## 还原：把夹具兽撤掉、让 LifeRoot 自己把伙伴节点收走
	_改配置("autoChongwuSkillId", -1)
	_改配置("autoChongWuEat", false)
	_会话.pets.clear()
	实体.call("_refresh_pet_companion")
	_判(实体.call("宠物伙伴节点") == null, "撤掉出战宠物后伙伴节点要被收走（夹具不许留在场景里）")
	## ⚠ 判完**再**还存档里的宠物：共用存档里可能本来就带着出战兽，
	## 先还原再判 ⇒ 判的是"存档里有没有宠"，而不是"撤宠会不会收走节点"（10-22 全量批实测 → ①）。
	for 兽 in 兽备份:
		_会话.pets.append(兽)
	实体.call("_refresh_pet_companion")


## ── 午：追打与换目标（原版那面 `toAttackAnemy` 旗到底谁在维护）──────────────
## 10-18 **在线腿**实测到的原始事故：挑中一只怪之后 `_追击` 一直举着 ⇒ 空闲大块再也没进过，
## 整轮挂机只出手一次，90 秒 5836 帧、服务端一只没死。离线门当时全绿，因为它的判据只到"挑中了"。
## 这一段判的是挑中**之后**的那串：交出追打命令、目标死了要换、追不到要拉黑、停了要交还。
## 原版挑怪还有一条我先前没写的：`SkillHandler.canAttack:451` → `DisplayUtil.outOfStage(怪,false)`
## —— **身体盒与舞台矩形(0,0,960,560)不相交的怪根本不算能打的**；
## `CommonAttack.getNearestLifeObj:51-54` 是同一件事的另一半（不在显示层里的候选直接 splice 掉）。
## 这张烘焙图上两只怪相距上万像素，夹具不搬进画面，判的就是"原版永远不会发生"的那种换目标 ⇒ 先搬再判。
func 搬到画面内(怪: Node2D, 偏: float) -> void:
	var 我: Vector2 = _玩家.get("position") as Vector2
	怪.position = Vector2(我.x + 偏, 我.y)
	怪.set("global_position", 怪.position)


func 把对照怪搬进画面(框内: Array, 第一) -> void:
	var 序 := 0
	for 怪 in 框内:
		if 怪 == 第一:
			continue
		序 += 1
		搬到画面内(怪 as Node2D, 140.0 + float(序) * 40.0)


func _午_追打与换目标() -> void:
	var 实体 = _玩家.get_parent().get_node_or_null("LifeRoot")
	if 实体 == null:
		_收尾("午：拿不到 LifeRoot")
		return
	var 全: Array = 实体.call("挂机的全部怪")
	_判(全.size() >= 2, "午：夹具要至少两只怪（『换目标』这条一只照不出来；实得 %d）" % 全.size())
	if 全.size() < 2:
		_收尾("午：怪不够")
		return
	_重开()
	_等预热带过()
	## ⚠ 先把**六类拾取一起**关掉：前面 壬/癸 几段在图上留过掉落，`拾取或打怪` 会**先走拾取**
	## （原版就是拾取优先），那样挑中的是一个 Dictionary、`_追击` 恒假 ⇒ 这一段判的就不再是追打。
	## 上一版只关了 `autoCollect`，那只是"装备"那一档 ⇒ 掉在地上的**金币**照样被捡（`isCollectMoney` 还开着）。
	## 原版 `toExecutePickLogic():355` = `_isPick || 六档任一` ⇒ 要断就得六档全断。
	var 拾取键: Array = ["autoCollect", "isCollectQuestion", "isCollectDrug",
			"isCollectMoney", "isCollectCaiLiao", "isCollectOthers"]
	for 键名 in 拾取键:
		_改配置(键名, false)
	_摆空闲态()
	_托管.拾取或打怪(false)
	var 第一 = _托管.目标
	_判(第一 is Node2D, "午：夹具——这一拍要挑中一只怪（实得 %s）" % str(第一))
	if not (第一 is Node2D):
		for 键名 in 拾取键:
			_改配置(键名, true)
		_收尾("午：没挑中怪，后面判不了")
		return
	## ① 挑中之后的动作 = **把这只交给追打**（原版 `checkAndFire` 置 `toAttackAnemy` + `curTarget`），
	##    真出手在每帧的 `moveToAttack`（本工程 `玩家._冲选中目标`），不是自己打一发就算完。
	_判(bool(_托管._追击), "挑中之后『在追』要举着（原版 toAttackAnemy=true）")
	_判(bool(_托管._还在追()), "午：阳性对照——此刻目标还活着、追打命令也在，`_还在追()` 必须为真")
	_判(_玩家.get("自动接近目标") == 第一,
			"挑中之后要把这只交给玩家的追打命令（不然下一拍没人接着打；实得 %s）" % str(_玩家.get("自动接近目标")))
	## ② 那只被打死 ⇒ **同一拍**放掉并换到另一只（原版 moveToAttack 每拍重算那面旗）。
	## ⚠ 先把活动区撑大再判：这张烘焙图上的怪**离得极开**（10-19 现查：一只在 251,490、
	## 另一只在 15761,1098，相差 1.5 万像素），原版 40 格也才 2000×1000 ⇒ 框内常常只剩一只，
	## 那样"换目标"只会走到"没怪 ⇒ 归位"，而**归位那支把 `_起点`（Vector2）写进 `目标`**，
	## 拿它跟 Node 直接 `!=` 报 `Invalid operands 'Vector2' and 'Object'` —— 这一族报错
	## **不中断进程**，却把本段协程当场打断（10-19 实测两次：④⑤ 整段没跑，门照样打「通过」）。
	## 640 格 = 32000×16000，纯粹为了"框里凑够两只"，判的还是同一条谓词。
	_托管.重算活动区(640)
	var 框内: Array = []
	for 怪 in 实体.call("挂机的全部怪"):
		if is_instance_valid(怪) and bool(怪.get("alive")) \
				and _托管._活动区.has_point((怪 as Node2D).global_position):
			框内.append(怪)
	_判(框内.size() >= 2, "午：夹具——撑大活动区之后框内至少要两只活怪（实得 %d）" % 框内.size())
	把对照怪搬进画面(框内, 第一)
	if 框内.size() < 2:
		(第一 as Node).set("alive", true)
		for 键名 in 拾取键:
			_改配置(键名, true)
		_收尾("午：框内怪不够，换目标那条判不了")
		return
	(第一 as Node).set("alive", false)
	## ⚠ 判据别写成"`_追击` 要落回 false"：同一拍释放之后**立刻又挑到下一只**、把旗重新举起来
	## 才是正确行为（原版也是这样：`toAttackAnemy` 落回 false 后 GuajiHandler 下一帧就设新的）。
	## 上一条跑过就红在这里（10-19 实测）。要看的是"手里那面旗指的是不是**新**的那只"，
	## 所以先单独问一次谓词，再看换目标的结果。
	_判(not bool(_托管._还在追()), "目标死了之后『还在追』这个谓词必须立刻为假（原版 moveToAttack 每拍重算 toAttackAnemy）")
	_托管.拾取或打怪(false)
	var 第二 = _托管.目标
	_判(第二 is Node2D and 第二 != 第一, "死了那只之后同一拍要换到**另一只怪**（实得 %s）" % str(第二))
	_判(_玩家.get("自动接近目标") == 第二,
			"换过去那只要立刻接成追打命令，朝尸体的那条必须已经清掉（实得 %s）" % str(_玩家.get("自动接近目标")))
	if not (第二 is Node2D):
		(第一 as Node).set("alive", true)
		for 键名 in 拾取键:
			_改配置(键名, true)
		_收尾("午：没换到第二只，后面几条判不了")
		return
	## ③ 追不到（寻路失败）⇒ 拉黑 + 放掉 + 这一只在黑名单期内不再被挑中（原版 `signWrong`）。
	_托管.追打失败(第二)
	_判(bool(_托管.黑名单里(_托管._目标键(第二))), "寻路失败那只要进黑名单（原版 `signWrong:1247`）")
	_判(not bool(_托管._追击) and _托管.目标 == null, "拉黑之后要把追击与目标一起放掉")
	_托管.拾取或打怪(false)
	## ⚠ `目标` 在"没怪可挑"那一支会被写成 `_起点`（Vector2），拿它跟 Node 直接 `!=`
	## 会 `Invalid operands 'Vector2' and 'Object'` —— 这一族报错**不中断进程**，
	## 但会把本段协程当场打断（10-19 实测：④⑤ 两条判据整段没跑，看日志以为都判过了）。
	var 换到 = _托管.目标
	_判(not (换到 is Node2D) or 换到 != 第二,
			"黑名单里那一只这一拍不许再被挑中（实得 %s）" % str(换到))
	(第一 as Node).set("alive", true)
	## ⑥ **真接线**：够不着又寻不出路时，是玩家那一侧回灌给挂机模块拉黑的
	## （`玩家._维持接近路线` 拿 `走向()` 的返回值 ⇒ `托管.追打失败`）。
	## 上一版只判了 `追打失败()` 函数本身，把那句回调删掉门照样绿 = 等于没判（10-19 口径）。
	var 第三 = 换到 if (换到 is Node2D) else 第二
	_摆空闲态()
	## ③ 刚把这只拉黑过（`换到` 常常就是 null：这张烘焙图出生点附近统共两只怪，
	## 一只"打死"一只"拉黑"，第三只根本不存在 ⇒ ⑥ 只能复用到同一只）。
	## 这一段判的是**回调有没有真接上**，所以先把黑名单清空，让"待会儿它进黑名单"成为新证据。
	_托管._黑名单.clear()
	_玩家.call("开始自动接近", 第三)
	var 原位: Vector2 = (第三 as Node2D).global_position
	_判(not bool(_托管.黑名单里(_托管._目标键(第三))), "午：夹具——这只此刻不该已经在黑名单里")
	(第三 as Node2D).global_position = Vector2(999999.0, 999999.0)		# 没有落脚点的远处 ⇒ 寻路必失败
	_玩家.call("_冲选中目标", 第三)
	(第三 as Node2D).global_position = 原位
	_判(bool(_托管.黑名单里(_托管._目标键(第三))),
			"寻路失败要由玩家那一侧回灌给挂机模块拉黑（`_维持接近路线`→`追打失败`；实得 %s）"
			% str(_托管.黑名单里(_托管._目标键(第三))))
	## ④ 『人物自动使用』那一枚下拉的值要落到**全局默认忍术**（原版 `Client.as:7193` /
	##    `set playerSkill:1206-1213` ⇒ `TargetHandler.defaultSkill`），每帧出手读的就是它。
	##    ⚠ 先摆一个**别的**值再开挂机：出厂 默认忍术=0、配置 招式 也默认 0 ⇒
	##    直接比 0 就是"0 比 0"的假绿（10-17 那条二次踩的口径，这里同一族）。
	_会话.call("设默认忍术", 777)
	_改配置("autoSkillId", 9029)
	_重开()
	_等预热带过()
	_判(int(_会话.get("默认忍术")) == 9029,
			"开挂机要把『人物自动使用』写进全局默认忍术（原版那句 setDefaultSkill；实得 %s）"
			% str(_会话.get("默认忍术")))
	_会话.call("设默认忍术", 777)
	_改配置("autoSkillId", 0)
	_重开()
	_等预热带过()
	_判(int(_会话.get("默认忍术")) == 0,
			"选了『普通攻击』(0) 也要照写不误（原版 0 就是 CommonAttack；实得 %s）"
			% str(_会话.get("默认忍术")))
	## ⑤ 停挂机 ⇒ 追打命令交还玩家（原版 `set isStart(false)` 里 `TargetHandler.clear()` + `stopPathFind()`）。
	_会话.request_hang(false)
	_判(_玩家.get("自动接近目标") == null, "停挂机要把追打命令交还玩家（不然人还在往那只怪走）")
	## ⑦ 类型闸（**源码文本判据 + 阳性对照**）：归位那一支会把 `_起点`（Vector2）写进 `目标`
	## （原版 `pathFindTarget = startPoint` 同样是个 Point），而 `移动方向()` 是"直线朝目标走"，
	## 没有类型闸就每物理帧报一次 `Invalid cast` —— 10-19 在线腿实测刷了 1200 行。
	## 为什么只能查文本：报错那条路径返回的还是 0，与"提前 return 0"在行为上一模一样，
	## 任何行为判据都照不出来（§1CG 那一族编译时机坑同一套路子）。
	## ⚠ 这一族一律走 `源码含()` = **先把注释剥掉再匹配**，每条后面各带两条量具自检
	## （插到非注释处必须查得到 / 只写在注释里必须查不到）。理由（10-19 实测）：删掉自造那一支时
	## 我在 `玩家.gd:1259` 写的**说明注释里含被删那句的原话**，于是"代码已经改对、判据照样红"——
	## 文本判据判的必须是**代码**，不是"注释里有没有这句话"。
	var 源 := FileAccess.get_file_as_string("res://脚本/角色/挂机托管.gd")
	_判(not 源码含(源, "func 移动方向"),
			"10-19 删掉了自造的 `func 移动方向()`（原版 `GuajiHandler` 里没有任何一句『朝目标 x 直接走』，靠近一律 pathFind：`:143`/`:784`/`:842`/`SkillExecute.moveToAttack:133`）")
	_判(源码含(源 + "\nfunc 移动方向(参数: int) -> int:\n\treturn 参数\n", "func 移动方向"),
			"文本量具自检·阳：把被禁的那个函数名插到**非注释处**必须查得到（查不到 ⇒ 上面那条是恒真）")
	_判(not 源码含("# func 移动方向(参数: int) -> int:", "func 移动方向"),
			"文本量具自检·阴：同一句只写在**注释里**必须查不到（查得到 ⇒ 剥注释没生效，判的是注释）")
	_判(not bool(_托管.has_method("移动方向")),
			"运行期同样不许存在（旧判据那条『类型闸』本来就是给它补的，函数没了闸也不用了）")
	var 玩源 := FileAccess.get_file_as_string("res://脚本/角色/玩家.gd")
	_判(not 源码含(玩源, "elif auto_combat_active") and not 源码含(玩源, "_is_auto_combat_active"),
			"玩家那一侧的分派链里不许再有 `elif auto_combat_active: dir = 移动方向()` 那一支 ⇒ 挂机期间人的移动只由 `走向()` 发的**真寻路**执行（`_走点击路线()`）")
	_判(源码含(玩源 + "\n\telif auto_combat_active: dir = 移动方向()\n", "elif auto_combat_active"),
			"文本量具自检·阳：那一支原话插到**非注释处**必须查得到（查不到 ⇒ 上面那条是恒真）")
	_判(not 源码含("## 上一版这里用 `elif auto_combat_active: dir = 移动方向()` 挡在外面", "elif auto_combat_active"),
			"文本量具自检·阴：同一句原话**只写在注释里**必须查不到（这条就是当年把我顶红的那一句）")
	_判(源码含(玩源, "_托管.拍(delta * 1000.0)"),
			"`_托管.拍()` 必须是无条件调那一句（原版 `World.tick():651` 不带任何开关）")
	_判(not 源码含("## 出处：`_托管.拍(delta * 1000.0)` 无条件调", "_托管.拍(delta * 1000.0)"),
			"文本量具自检·阴：要求存在的那句如果只出现在注释里，**不算**存在（否则判据会被注释喂绿）")
	## 无条件调用的**行为侧**证据：`tick()` 里嗑药那两段（`:610-:658`）排在
	## `:660 if(!this._isStart) return;` **之前** ⇒ 没在挂也照样按血线吃药。
	## 上一版这里用 `auto_combat_active` 把 `拍()` 整个挡在外面 ⇒ 一关挂机连"把最后两枚捡完"都没了。
	_会话.request_hang(false)
	_判(not bool(_托管.在跑), "午：夹具——这一段开头要先把挂机停掉（不然下面两条量不到『没在挂也照跑』）")
	var 备份午 = _备份背包()
	var 级备份午 = _会话.player_stats.get("level", 0)
	_会话.player_stats["level"] = 60				# 本段自己钉等级：`药品表` 按 `required_level <= 等级` 筛
	_会话.player_stats["max_hp"] = 100
	_会话.player_stats["hp"] = 30
	_改配置("autoReplyHp", true)
	_改配置("auotReplyHpValue", 70)
	_摆背包([{"id": "03000001", "quantity": 4}])
	_托管._药冷却.clear()
	_托管._预热过 = 99999.0
	_托管._帧 = 3							# 摆成 `(帧 & 3) == 0` 那一拍
	_托管.拍(16.7)
	_判(_数量("03000001") == 3,
			"没在挂也照样按血线吃药 ⇒ 证明 `拍()` 是无条件调的（实得 %d 个）" % _数量("03000001"))
	_托管._帧 = 4
	_托管._药冷却.clear()
	_托管.拍(16.7)
	_判(_数量("03000001") == 3,
			"午·阳：帧号不对齐时那一拍不嗑（没有这条，上面那条就是『谁都别嗑』也能绿；实得 %d 个）" % _数量("03000001"))
	_还原背包(备份午)
	_会话.player_stats["level"] = 级备份午		# 本段钉过的等级要还回去（己/寅都按等级筛）
	## 戌·同一条尺子（文本层）：`该不该捡` 的档位与"到位验收"`_离那枚` 必须出自**同一条算式**。
	## 为什么查文本：离线夹具里 `position == global_position`（Player 与 LifeRoot 都是
	## 零偏移场景根的直接子节点），两边写不同的尺子在这里量不出差别 ⇒ 行为判据照不出来，
	## 只能钉住"这个函数里不许自己再距离一次"。（与上面那条类型闸同一套路子）
	var 剥 := 剥注释(源)
	var 起 := 剥.find("func 该不该捡(")
	var 止 := 剥.find("\nfunc ", 起 + 1)
	var 体 := 剥.substr(起, 止 - 起) if 起 >= 0 and 止 > 起 else ""
	_判(not 体.is_empty() and 体.contains("_离那枚(掉)") and not 体.contains("distance_to"),
			"该不该捡() 里不许再自己算距离，必须走 `_离那枚()`（两把尺子=真机上永远判『要走过去』）")
	_判(剥注释(体 + "\n\treturn 0 if 我.distance_to(怪) < 90.0 else 1\n").contains("distance_to"),
			"文本量具自检·阳：把 `distance_to` 插到**非注释处**必须查得到（查不到 ⇒ 上面那条恒真）")
	_判(not 剥注释(体 + "\n\t# return 0 if 我.distance_to(怪) < 90.0 else 1\n").contains("distance_to"),
			"文本量具自检·阴：同一句只写在注释里必须查不到（查得到 ⇒ 判的是注释，不是代码）")
	for 键名 in 拾取键:
		_改配置(键名, true)		# 夹具恢复出厂：拾取那六档后面还有段要判
	_改配置("autoBattleRange", 20)
	_托管.重算活动区(20)			# 本段为了"框内还有第二只"把框撑到 40 格，还回去


## ── 午乙：追按下放招的"回退普攻"那一转（`SkillExecute.moveToAttack():75-78`）──
## 原文：
##   `if (SkillDataTool.isLongCdSkill(_loc2_) && Boolean(API.skillHandler.isCooling(_loc2_))`
##   `    || !AbstractAttackSkill.canUseSkill(_loc2_)) { _loc2_ = 0; }`
## ⇒ **长 CD 正在转**、或者**这一招现在放不出去**，号就直接换成 0（普攻）。
## 而 `canUseSkill(0)` **恒真**：`DataCenter.getSkillLevel(0)`(`:2231-2236`) 对 0 直接 `return 1`、
## `SkillDataTool.getSkillMp(0, lv)`(`:393-398`) 的 switch 里没有 0 这一档 ⇒ 耗 0 ⇒ 三关全过
## ⇒ 降级之后那一发普攻**永远放得出去**。
## 症状（用户实机最容易看出来的那一条）：大招一进 CD（或蓝空了），我们这具以前贴到怪脸上不出手。
## ⚠ 参照值全由本门自己算：普攻的证据是 `perform_basic_attack` 自己写的 `attack_cooldown = 0.45`；
##   技能的证据是 `玩家.施法次数` 这个计数器（只有 `use_skill_slot` 真出手才 +1）。
func _午乙_追按下回退普攻() -> void:
	var 实体 = _玩家.get_parent().get_node_or_null("LifeRoot")
	if 实体 == null:
		_收尾("午乙：拿不到 LifeRoot")
		return
	var 全: Array = 实体.call("挂机的全部怪")
	_判(全.size() >= 1, "午乙：夹具——至少要有一只怪当追打目标（实得 %d）" % 全.size())
	if 全.is_empty():
		_收尾("午乙：没有怪")
		return
	var 槽备份: Array = _备份槽位()
	var 学备份 = _备份已学()
	var 蓝备份 = _会话.player_stats.get("mp", 0)
	var 精备份 = _会话.player_stats.get("zq", 0)
	var 默认备份 = int(_会话.get("默认忍术"))
	var 怪: Node2D = 全[0] as Node2D
	_重开()
	_等预热带过()
	_托管._黑名单.clear()
	## 贴脸摆位：普攻命中盒 `攻击矩形()` 只有 50×50（注册点在脚底、朝朝向那一侧）
	## ⚠ 必须把这只**选成当前目标**（原版 `moveToAttack` 里的 `_loc3_ = targetHandler.curTarget`
	##    与 `fireSkill` 打的那只**本来就是同一只**；本工程 `use_skill_slot` 读的是全局
	##    `get_selected_enemy()`，不选就会拿上一段留下的旧目标去判"够不够得着"）。
	var 血备份 = 怪.get("hp")
	var 摆好 := func() -> void:
		_摆空闲态()
		怪.set("alive", true)
		## ⚠ **打不死的那一具假人**：这一段判的是"这一拍该放哪一发"（长CD/蓝不够 ⇒ 降级平 A），
		## 不是"能不能把怪打死"。而离线那侧 `_结算攻击 → _结算一只` 是**真扣血**的，这几拍连着
		## 平 A 会把这具假人打死 ⇒ `战斗角色._die():343-345` 把精灵切成 `die1`，
		## 而 `_怪物体型矩形`（`地图实体.gd:217-227`）读的是**当前帧**的 lt/rb，
		## `die1` 的帧没有体型盒 ⇒ `当前身体矩形()` 回零 ⇒ `能攻()` 与 `_够得着()` 从此恒假
		## ⇒ 本段后面几拍走进 `_放掉追击` 那一支（还顺手把这具拉黑），申 段整段量不到东西
		## （10-19 实测：血 48→24→0、盒变成 `(0,0,0,0)`）。血量是这具自己的战斗资源、
		## 不是任何一面决策旗，把它摆满不改变被测那一句走哪一支。
		怪.set("hp", 900000)
		怪.set_meta("attacked_by_mob", false)
		怪.set_meta("is_pet_monster", false)
		搬到画面内(怪, 25.0)
		实体.call("_select_character", 怪, {})
		_玩家.set("attack_cooldown", 0.0)
		_玩家.set("出手中", false)
		_玩家.set("自动接近目标", 怪)
		_托管.目标 = 怪
		_托管._追击 = true
		_判(bool(_托管.能攻(怪)) and bool(_玩家.call("_够得着", 怪)),
				"午乙：夹具——每一拍开头这具假人都要还站得住（查得到体型盒=没被打死；"
				+ "实得 能攻=%s 够着=%s 血=%s 盒=%s）" % [str(_托管.能攻(怪)), str(_玩家.call("_够得着", 怪)),
						str(怪.get("hp")), str(实体.call("怪物体型盒", 怪))])
	摆好.call()
	_判(bool(_托管.能攻(怪)), "午乙：夹具——这只必须先判得出『能攻』（否则 `_冲选中目标` 走的是放掉追击那一支）")
	_判(bool(_玩家.call("_够得着", 怪)),
			"午乙：夹具——摆位要落在普攻命中盒里（够不着就走到 `_维持接近路线`，量不到出手那一支）")
	_判(实体.call("get_selected_enemy") == 怪,
			"午乙：夹具——这一只要真是**当前选中目标**（原版 `curTarget`；`use_skill_slot` 读的就是它）")
	_会话.skill_slots.clear()
	_会话.learned_skills.clear()
	_会话.skill_slots.append({"id": "0009029", "level": 1})
	_会话.learned_skills.append(_造已学("0009029"))
	_会话.player_stats["mp"] = 5000
	_会话.player_stats["zq"] = 5000
	_会话.skill_cooldowns.clear()
	_会话.call("设默认忍术", 9029)
	_判(int(_会话.默认忍术槽()) == 0, "午乙：夹具——默认忍术要真落在这一格（实得 %d）" % int(_会话.默认忍术槽()))
	_判(float(_会话.GAME_DATA.skill("0009029").get("cooldown", 0.0)) > 10.0,
			"午乙：夹具——这一招按表就得算长 CD（原版阈值 `isLongCdSkill:737-740` = 10000 毫秒）")
	_判(bool(_玩家.call("长CD招", "0009029")), "午乙：夹具——`长CD招()` 自己也要认这一招（表与函数两头都要对上）")
	## ── ① 长 CD 且正在转 ⇒ 号换成 0 ⇒ 走普攻那一支
	var 施法前 := int(_玩家.get("施法次数"))
	_会话.skill_cooldowns[0] = 20.0
	_玩家.call("_冲选中目标", 怪)
	_判(float(_玩家.get("attack_cooldown")) > 0.4,
			"① 长 CD 正在转 ⇒ 降级打这一发普攻（原版 `:75-78` `_loc2_ = 0`；普攻会把自己那份 0.45 秒冷却写上，实得 %s）" % str(_玩家.get("attack_cooldown")))
	_判(int(_玩家.get("施法次数")) == 施法前,
			"① 同一拍**不许**再去放那招在转 CD 的长 CD（`:122-131` 那一支这会儿不该进；施法 %d→%d）" % [施法前, int(_玩家.get("施法次数"))])
	## ── ① 的阳性对照：CD 转完 ⇒ 同一摆位必须走技能那一支、且不写普攻冷却
	_会话.skill_cooldowns.clear()
	摆好.call()
	施法前 = int(_玩家.get("施法次数"))
	_玩家.call("_冲选中目标", 怪)
	_判(int(_玩家.get("施法次数")) == 施法前 + 1,
			"午乙·阳：CD 空了同一招就要放得出去（没有这条，上面『降级』那两条靠『谁都别放』也能绿；施法 %d→%d）" % [施法前, int(_玩家.get("施法次数"))])
	_判(float(_玩家.get("attack_cooldown")) <= 0.0,
			"午乙·阳：走技能那一支时不写普攻冷却（降级只在 CD 里才发生；实得 %s）" % str(_玩家.get("attack_cooldown")))
	## ── ② 蓝不够 ⇒ 同一句的后半个条件，照样降级
	_会话.skill_slots.clear()
	_会话.learned_skills.clear()
	_会话.skill_slots.append({"id": "0003002", "level": 1})
	_会话.learned_skills.append(_造已学("0003002"))
	_会话.call("设默认忍术", 3002)
	_会话.skill_cooldowns.clear()
	var 耗蓝 := int(_会话.GAME_DATA.skill_cost(3002, 1).get("mp", 0))
	_判(耗蓝 > 0, "午乙：夹具——3002 一级要真耗查克拉（否则『蓝不够』那一支是 0 比 0；实得 %d）" % 耗蓝)
	_判(not bool(_玩家.call("长CD招", "0003002")),
			"午乙：夹具——3002 按表**不是**长 CD ⇒ 这一跑只可能靠 `canUseSkill` 那一半降级（否则分不清是谁挡的）")
	_会话.player_stats["mp"] = 耗蓝 - 1
	_判(not bool(_玩家.call("_这一招放得出", "0003002")),
			"② 蓝差 1 ⇒ `_这一招放得出` 必须假（`canUseSkill:553-554`）")
	摆好.call()
	施法前 = int(_玩家.get("施法次数"))
	_玩家.call("_冲选中目标", 怪)
	_判(float(_玩家.get("attack_cooldown")) > 0.4,
			"② 蓝不够 ⇒ 一样降级打普攻（同一句 `:75-78` 的后半个条件；实得 %s）" % str(_玩家.get("attack_cooldown")))
	_判(int(_玩家.get("施法次数")) == 施法前,
			"② 蓝不够那一拍一发技能都不许出（施法 %d→%d）" % [施法前, int(_玩家.get("施法次数"))])
	_会话.player_stats["mp"] = 耗蓝
	_判(bool(_玩家.call("_这一招放得出", "0003002")), "午乙·阳：蓝补回去 ⇒ 谓词立刻变真")
	摆好.call()
	施法前 = int(_玩家.get("施法次数"))
	_玩家.call("_冲选中目标", 怪)
	_判(int(_玩家.get("施法次数")) == 施法前 + 1,
			"午乙·阳：蓝补回去同一拍就要走技能那一支（没有这条上面那两条『降级』就是恒真；施法 %d→%d）" % [施法前, int(_玩家.get("施法次数"))])
	## ── ② 的另一半：没学过这一招（等级取不到 ⇒ `:554` 那一关就死）
	_会话.learned_skills.clear()
	_会话.player_stats["mp"] = 5000
	_会话.player_stats["zq"] = 5000
	_判(not bool(_玩家.call("_这一招放得出", "0003002")),
			"② 没学过 ⇒ `_这一招放得出` 必须假（`getSkillLevel` 回 0，`:554` `lv > 0` 那关就死）")
	摆好.call()
	施法前 = int(_玩家.get("施法次数"))
	_玩家.call("_冲选中目标", 怪)
	_判(float(_玩家.get("attack_cooldown")) > 0.4,
			"② 没学过这一招也要降级打普攻（本工程的形状是『槽里查不到已学』⇒ 号直接取空，落进同一条普攻支）")
	_判(int(_玩家.get("施法次数")) == 施法前, "② 没学过 ⇒ 那一拍一发技能都不许出（施法 %d→%d）" % [施法前, int(_玩家.get("施法次数"))])
	## ── 本轮新增能力的根：`canUseSkill(0)` 恒真 ⇒ 降级之后那一发普攻一定放得出去
	_会话.skill_slots.clear()
	_会话.learned_skills.clear()
	_会话.player_stats["mp"] = 0
	_会话.player_stats["zq"] = 0
	_判(bool(_玩家.call("_这一招放得出", "")),
			"`canUseSkill(0)` 恒真（空号就是普攻）：什么都没学、蓝 0 也放得出 —— `getSkillLevel(0)` 回 1 + `getSkillMp` 对 0 无 case")
	_判(not bool(_玩家.call("_这一招放得出", "0003002")),
			"午乙·阳：同一副状态下**真招式**放不出（没有这条，上面那条就是『谁都放得出』混过去）")
	_会话.call("设默认忍术", 0)
	摆好.call()
	_玩家.call("_冲选中目标", 怪)
	_判(float(_玩家.get("attack_cooldown")) > 0.4,
			"选了『普通攻击』(0) 且蓝 0 ⇒ 照样平 A 得出去（这就是原版大招转 CD 时人还能把怪打死的那一条）")
	_玩家.set("attack_cooldown", 0.0)
	_还原已学(学备份)
	_还原槽位(槽备份)
	_会话.player_stats["mp"] = 蓝备份
	_会话.player_stats["zq"] = 精备份
	_会话.call("设默认忍术", 默认备份)
	_会话.skill_cooldowns.clear()
	怪.set("alive", true)
	怪.set("hp", 血备份)						# 假人的血量要还回去（后面的段按真血量判）
	_托管._追击 = false
	_托管.目标 = null


## ── 申：挂机锁定那只怪，头顶要出原版那枚蓝色箭头（用户 2026-10-19 实机报）──
## 原版 `GuajiHandler.as:833` 挑中之后写的就是 `targetHandler.viewTarget = monster`，
## 而 `TargetHandler.as:259-276` 那个 setter 换对象时先给旧的 `showViewTargetEffect(false)`、
## 再给新的 `showViewTargetEffect(true)`；怪那一侧 `Monster.as:799-816` 就是
## add/removeChild(`MobSelected_Effect_Skin`) ⇒ **箭头是跟着"看住的那只"显隐的**。
## 本工程以前只有**点选**那一条会 `marker.visible = true`（`_select_character`），
## 挂机这条只改了 `_view_target` ⇒ 目标框与血一直在刷，箭头从来不出现。
func _申_锁定怪头顶箭头() -> void:
	var 实体 = _玩家.get_parent().get_node_or_null("LifeRoot")
	if 实体 == null:
		_收尾("申：拿不到 LifeRoot")
		return
	var 拾取键: Array = ["autoCollect", "isCollectQuestion", "isCollectDrug",
			"isCollectMoney", "isCollectCaiLiao", "isCollectOthers"]
	for 键名 in 拾取键:
		_改配置(键名, false)			# 拾取优先，关掉才保证挑中的是**怪**（与 午 同一条口径）
	_重开()
	_等预热带过()
	_摆空闲态()
	_托管.拾取或打怪(false)
	var 第一 = _托管.目标
	_判(第一 is Node2D, "申：夹具——这一拍要挑中一只怪（实得 %s）" % str(第一))
	if not (第一 is Node2D):
		for 键名 in 拾取键:
			_改配置(键名, true)
		_收尾("申：没挑中怪，箭头判不了")
		return
	var 一件 = (第一 as Node).get_node_or_null("SelectionMarker")
	_判(一件 != null, "怪生成时就要预挂 SelectionMarker（`地图实体._attach_selection_marker`，点选与挂机共用）")
	_判(一件 != null and bool(一件.get("visible")) and (一件 as CanvasItem).is_visible_in_tree(),
			"挂机锁定之后这只怪头顶的箭头要显形（原版 setter 里那句 showViewTargetEffect(true)），实得 %s"
					% str(null if 一件 == null else [一件.get("visible"), (一件 as CanvasItem).is_visible_in_tree()]))
	## 阳性对照：**没被锁定的那一只**此刻箭头必须是灭的。
	## 没有这一条，"亮"可能只是所有箭头本来就亮（那第 2 条等于没判）。
	_托管.重算活动区(640)				# 这张图出生点附近两只怪相距上万像素，框要撑大才凑得齐
	var 框内: Array = []
	for 怪 in 实体.call("挂机的全部怪"):
		if is_instance_valid(怪) and bool(怪.get("alive")) \
				and _托管._活动区.has_point((怪 as Node2D).global_position):
			框内.append(怪)
	var 另一: Node2D = null
	for 怪 in 框内:
		if 怪 != 第一:
			另一 = 怪
			break
	_判(另一 != null, "申：夹具——框内要还有第二只怪当对照（实得 %d 只）" % 框内.size())
	if 另一 != null:
		搬到画面内(另一, 180.0)			# 原版 `canAttack` 有 `!outOfStage`：画面外那只根本不算目标
	if 另一 == null:
		(第一 as Node).set("alive", true)
		for 键名 in 拾取键:
			_改配置(键名, true)
		_收尾("申：没有对照怪")
		return
	var 二件 = (另一 as Node).get_node_or_null("SelectionMarker")
	_判(二件 != null and not bool(二件.get("visible")),
			"申：阳性对照——没被锁定的那只箭头必须是灭的（实得 %s）" % str(二件.get("visible")))
	## 换目标：旧的那只箭头要**摘掉**、新的要挂上（setter 那两行的另一半）。
	(第一 as Node).set("alive", false)
	_摆空闲态()
	var 全probe: Array = 实体.call("挂机的全部怪")
	var 同层probe: Array = 实体.call("挂机的同层怪", int(_托管._层号()), _托管._活动区)
	prints("探针申 我=", str(_玩家.position), "层号=", int(_托管._层号()),
			"活动区=", str(_托管._活动区), "全部怪=", 全probe.size(), "同层怪=", 同层probe.size(),
			"另一=", str(另一.global_position), "另一能攻=", str(_托管.能攻(另一)),
			"另一在画面=", str(_托管._在画面内(另一)), "另一可去攻=", str(_托管.去攻这只(另一)),
			"黑名单=", str(_托管._黑名单), "框内=", 框内.size(),
			"画=", str(_玩家.get_canvas_transform()), "第一=", str(第一.global_position))
	for 怪 in 实体.get("_entities"):
		if not is_instance_valid(怪) or 怪.get("kind") != "m":
			continue
		var 皮 = 怪.get_node_or_null("Sprite")
		prints("  探针申·怪 号=", str(怪.get_instance_id()), "位=", str(怪.global_position),
				"alive=", str(怪.get("alive")), "皮动作=", str(皮.get("action") if 皮 != null else "无"),
				"盒=", str(实体.call("怪物体型盒", 怪)), "血=", str(怪.get("hp")))
	_托管.拾取或打怪(false)
	var 第二 = _托管.目标
	_判(第二 is Node2D and 第二 != 第一, "申：夹具——打死那只之后要换到另一只（实得 %s）" % str(第二))
	if not (第二 is Node2D):
		(第一 as Node).set("alive", true)
		for 键名 in 拾取键:
			_改配置(键名, true)
		_收尾("申：没换到第二只")
		return
	_判(第二 == 另一 or bool((另一 as Node).get_node_or_null("SelectionMarker").get("visible")),
			"换过去那一只的箭头要亮（实得 %s）" % str((另一 as Node).get_node_or_null("SelectionMarker").get("visible")))
	_判(not bool((一件 as Node).get("visible")),
			"旧那只的箭头必须当场摘掉（原版 setter 先 showViewTargetEffect(false)），实得还亮着")
	## 停挂机 ⇒ 原版 `TargetHandler.clear():462-469` 里有 `viewTarget = null` 那一行，
	## 箭头要跟着收（我们这边的落点是 `挂机托管._清目标与寻路`）。
	_判(实体.has_method("清看住的目标"),
			"申：夹具——LifeRoot 上要有 清看住的目标（停挂机那一路靠它收箭头，方法不存在就是静默零覆盖）")
	_会话.request_hang(false)
	_判(not bool((另一 as Node).get_node_or_null("SelectionMarker").get("visible")),
			"停挂机之后头顶箭头要收掉（不清的话箭头钉在最后那只怪身上），实得还亮着")
	(第一 as Node).set("alive", true)
	for 键名 in 拾取键:
		_改配置(键名, true)
	_改配置("autoBattleRange", 20)
	_托管.重算活动区(20)


## ── 酉：掐路线那一支不许在爬梯时下手，也不许把人钉死（用户 2026-10-19 报）──
## 10-19 之前这一段的①判的是自造的 `挂机托管.移动方向()`（"返回 0 就不许 cancel 路线"）。
## 那一支已经整条删掉了（原版靠近一律 `pathFind`），但**同一条坑还在**，换了个落点：
## 原版 `SkillExecute.moveToAttack():163-170` 放掉追打那一支是
## ```
##    targetHandler.toAttackAnemy = false;
##    if (player.isPathFinding() && !player.climbing) player.stopPathFind();
## ```
## ⇒ **正在爬梯时绝对不许把身上那条路线掐掉**：路线一没、`click_climb_direction` 被清 0、
##   又没人按键 ⇒ 竖直速度恒 0 而 `climbing` 还真 ⇒ 钉在绳上（根因量在 `开发工具/量爬梯卡住.gd`：
##   那张图 5 把梯子，第 30 帧一取消路线就 45 帧位移 0，全中）。
func _酉_爬绳不被抢路线() -> void:
	var 实体 = _玩家.get_parent().get_node_or_null("LifeRoot")
	var 梯根: Node = _玩家.get("ladder_root")
	if 实体 == null or 梯根 == null:
		_收尾("酉：拿不到 LifeRoot / ladder_root")
		return
	var 全: Array = 实体.call("挂机的全部怪")
	_判(全.size() >= 1, "酉：夹具——图上要至少有一只怪当追打目标（实得 %d）" % 全.size())
	var 绳 = 找根能站的绳(梯根)
	_判(绳 != null, "酉：夹具——这张图要有一把能站人的绳/梯（没有②那半判不了）")
	if 全.is_empty() or 绳 == null:
		_收尾("酉：夹具不齐")
		return
	_重开()
	_等预热带过()
	var 怪: Node2D = 全[0]
	var 顶 := float(绳.y1)
	var 底 := float(绳.y2)
	var 绳心 := Vector2(float(绳.x), (顶 + 底) * 0.5)
	## ③ `_放掉追击`：有活动路线**且不 climbing** ⇒ 当场把路线掐掉（原版 `:168-171` 那一句）
	_摆空闲态()
	_玩家.set("position", 绳心)
	_玩家.set("climbing", false)
	_玩家.set("自动爬梯中", false)
	落到脚点()							# 人挪到绳这里之后**重新落一次脚点**：`走向()` 是从
										# `current_fh_id` 起步规划的，位置变了脚点没跟着变就是
										# 从错误的起点排路（10-19 实测这样 `走向()` 直接回假）
	怪.set("position", 绳心 + Vector2(90.0, 0.0))
	怪.set("global_position", 怪.get("position"))
	var 脚点酉: Node = _玩家.get("footholds")
	prints("探针酉 绳心=", str(绳心), "on_ground=", str(_玩家.get("on_ground")), "fh=", str(_玩家.get("current_fh_id")),
			"查点=", str(脚点酉.call("find_click_target", 怪.position)) if 脚点酉 != null else "无脚点")
	_判(bool(_玩家.call("走向", 怪.position + Vector2(0.0, 0.0), true, false)),
			"酉：夹具——先要真的发出一条路线（发不出来下面两条就是 0 比 0）")
	_判(bool(_玩家.get("click_move_active")), "酉：夹具——路线旗必须亮着（实得 %s）" % str(_玩家.get("click_move_active")))
	_玩家.set("自动接近目标", 怪)
	_玩家.call("_放掉追击", 怪)
	_判(not bool(_玩家.get("click_move_active")) and (_玩家.get("auto_actions") as Array).is_empty(),
			"③ 目标丢了要把身上那条追过去的路线**当场掐掉**（原版 `moveToAttack:168-171` `isPathFinding() && !climbing ⇒ stopPathFind()`；人否则会自己走到怪站过的地方才停）")
	_判(_玩家.get("自动接近目标") == null, "同一支还要把追打命令交还（`:167` 的 toAttackAnemy=false）")
	_托管._黑名单.clear()
	## ③ 的反面：**正在爬梯时不许掐** —— 这就是把人钉在绳上的那一下
	_摆空闲态()
	_玩家.set("position", 绳心)
	_玩家.set("ladder_cooldown", 0.0)
	落到脚点()							# 同上：这一跑也要先有一个真起点才排得出路线
	_判(bool(_玩家.call("走向", 怪.position, true, false)), "酉：夹具——爬梯这一跑也要先发出路线（实得假=量不到）")
	_玩家.set("climbing", true)
	_玩家.set("自动爬梯中", true)
	_玩家.set("自动接近目标", 怪)
	_玩家.call("_放掉追击", 怪)
	_判(bool(_玩家.get("click_move_active")),
			"③ 正在爬梯时**不许**掐路线（原版那一句带 `&& !player.climbing`；掐了就钉在绳上，实得 %s）" % str(_玩家.get("click_move_active")))
	_判(_玩家.get("自动接近目标") == null, "酉·阳：同一支里 `toAttackAnemy=false` 那一句照样要执行（只掐另一半不算转写）")
	_玩家.set("climbing", false)
	_玩家.set("自动爬梯中", false)
	_玩家.set("click_move_active", false)
	_托管._黑名单.clear()
	_会话.request_hang(false)
	## ② 自动带上绳、路线中途没了 ⇒ 要自己松手（直接点 `_physics_process`，不让托管在旁边抢）
	_玩家.set("position", 绳心)
	_玩家.set("ladder_cooldown", 0.0)
	_玩家.set("velocity", Vector2.ZERO)
	_玩家.set("on_ground", false)
	_玩家.set("climbing", true)
	_玩家.set("自动爬梯中", true)
	_玩家.set("click_climb_direction", 0.0)
	_玩家.call("cancel_auto_path")				# 停挂机 / 换目标 那一路就是这个调用
	for _i in 12:
		_玩家.call("_physics_process", 1.0 / 60.0)
	_判(not bool(_玩家.get("climbing")),
			"自动路线断了之后必须松手（不许把人钉在绳上），实得 在爬=%s 竖直速度=%s" % [
				str(_玩家.get("climbing")), str((_玩家.get("velocity") as Vector2).y)])
	## 手动上的绳（自己按住上/下）⇒ **原版行为：停在绳上不动**，这条把上面那半钉死成"只放自动的"
	_玩家.set("position", 绳心)
	_玩家.set("ladder_cooldown", 0.0)
	_玩家.set("velocity", Vector2.ZERO)
	_玩家.set("on_ground", false)
	_玩家.set("climbing", true)
	_玩家.set("自动爬梯中", false)
	_玩家.call("cancel_auto_path")
	for _i in 12:
		_玩家.call("_physics_process", 1.0 / 60.0)
	_判(bool(_玩家.get("climbing")),
			"玩家自己按住上/下挂上绳的，松手之后**不该**被甩下去（原版停在绳上），实得 在爬=%s"
					% str(_玩家.get("climbing")))
	_玩家.set("climbing", false)
	_玩家.set("自动爬梯中", false)


## 从这张图的攀爬物里挑一根"中段站得住人"的绳（顶底太近的测不出爬）。
func 找根能站的绳(梯根: Node):
	for 梯 in (梯根.get("ladders") as Array):
		if float((梯 as Dictionary).y2) - float((梯 as Dictionary).y1) >= 60.0:
			return 梯
	return null


## ── 未：换图 = **关挂机**（10-19 用户拍板"照原版"；旧判据"换图续挂"是反的，已倒过来）──
## 真值链：`World.clearMap():893` → `GuajiHandler.clear():286-293`
## = `if (!_IsgoingHome) { this.isStart = false; }` ⇒ **每次换图都把挂机关掉**
## （屏幕上那颗"挂机中"灭、发 1808:1、`TargetHandler.clear()` 收箭头、`pastTime=0`），
## 只有"到点回城"那一趟传送（`:712` 把 `_IsgoingHome` 摆真）例外。
## 所以 `_ready()` 里那段"换图自动接回挂机"是**自造的**，已撤；`_在回城` 改成 `static var`
## （原版是单例，那颗旗必须活得比一张图长）。
## ⚠ 本段一律**真建新实例**：托管挂在玩家节点下 ⇒ 换图 = 旧实例离树、新实例新建，
##   光在同一个实例上翻标志照不到"`_exit_tree` 那一支"。
##   而 `_在回城` 是 static ⇒ 全部门共享一份，本段结束时必须把它清回假（`重读配置():269`）。
func _未_换图关挂机() -> void:
	var 层 = _玩家.get_tree().get_first_node_in_group("game_hud")
	if 层 == null:
		_收尾("未：拿不到 HUD 那一层")
		return
	_重开()
	_等预热带过()
	_托管.重读配置()							# `:280` `_IsgoingHome = false` ⇒ 摆成"普通换图"
	_判(not bool(_托管._在回城), "未：夹具——这一跑必须不是回城那一趟（实得 _在回城=%s）" % str(_托管._在回城))
	_判(bool(_会话.hang_state.get("active", false)), "未：夹具——此刻会话里应还是挂着的状态")
	## ── A：新建的那一份**不许**自己接上挂机（`_ready` 里那段"自动接回"是自造的，已撤）
	var 新: Node = load("res://脚本/角色/挂机托管.gd").new()
	_玩家.add_child(新)
	_判(not bool(新.get("在跑")),
			"⑮ 换图新建的那一份不许自己接上挂机（原版 clear():289-295 换图就 isStart=false；实得 在跑=%s）" % str(新.get("在跑")))
	_判(float(新.get("_预热过")) == 0.0 and int(新.get("_帧")) == 0,
			"未：夹具——那份新实例确实是干净的（预热/帧都没走过）")
	_判(挂机信号已连(新),
			"未：夹具——新建那一份的 `_ready()` 必须真跑过（信号没连上 ⇒ 后面所有 `_重开()` 都是空转）")
	收掉旧托管(新)								# 与 辰 段同一手法：摘掉会话引用再 free，
	## ── B：旧实例离树（= 换图那一刻）⇒ 关掉挂机 + 发 1808:1 + 摘掉自己那枚屏幕特效
	var 旧特效 = _托管.get("_特效") as Node
	var 停前 := _上行发过几发(_托管, 1)
	_判(旧特效 != null and is_instance_valid(旧特效) and bool((旧特效 as CanvasItem).visible),
			"未：夹具——离树之前主实例这一枚『挂机中』要真的挂着（否则成对摘掉那两条没得比）")
	_玩家.remove_child(_托管)					# 旧地图那一具玩家被回收 ⇒ `_exit_tree()` 那一支
	_判(not bool(_托管.在跑),
			"⑮ 非回城的换图（离树）必须**关掉挂机**（原版 `World.clearMap():893` → `clear():289-295`；实得 在跑=%s）" % str(_托管.在跑))
	_判(_上行发过几发(_托管, 1) == 停前 + 1,
			"同一支还要**恰好**补发那一发 1808:1（`isStart=false` 走 `_上行(1)`，`:1053` requestHang_stopHang；实得 %d→%d）" % [停前, _上行发过几发(_托管, 1)])
	_判(not bool(_会话.hang_state.get("active", true)), "离树关挂要回会话（那颗『挂机中』球跟着灭），不能只改本地")
	await _等帧(3)
	_判(旧特效 == null or not is_instance_valid(旧特效),
			"离树要把自己那枚屏幕特效摘掉（原版 `:1083-:1086` 成对 removeChild），不许留在 HUD 上没人管")
	## ⚠ **不许把这一份再 add_child 回去**：实测 Godot 4.7 里节点离开场景树再重新入树
	## **不会重跑 `_ready()`**（`_enter_tree` 会），而这一份的信号正是在 `_exit_tree()`
	## 里摘掉的 ⇒ 重挂回去的那一份永远听不到 `hang_changed`，后面每一处 `_重开()` 都开成
	## 假的（10-19 三条"量具自检：这一段真的开起来了"就是这么红的，未/戌/亥 三段被连坐）。
	## 真换图时旧的那一具是**连场景一起被回收**的，所以这里照真机做：摘掉旧的、
	## 按 `玩家.gd:160-162` 那三句重建新的一具（**两处引用一起换**，见 `重建托管()`）。
	var 旧一份 = _托管
	收掉旧托管(旧一份)
	重建托管()
	_判(挂机信号已连(_托管),
			"未：夹具——换图后那一份新实例的 `_ready()` 要真跑过（会话与 `hang_changed` 都接上）")
	_重开()									# 把主实例重新开起来，给后面 C/D 两支用
	_等预热带过()
	## ── C：回城那一趟离树**不许**关（`_IsgoingHome` 真 ⇒ `clear()` 整句跳过）
	## `_在回城` 是 static，只有被测那一句能把它摆真：`走时长到点():712`（不在村那一支）。
	var 会前 = _托管._会话
	var 假会话 := 记录会话.new()
	root.add_child(假会话)
	假会话.current_map_id = "101010000"
	_托管._会话 = 假会话
	_玩家.set("_同步动作", 1)
	_玩家.set("on_ground", true)
	_托管._刚清完 = true
	_托管.走时长到点()
	_托管._会话 = 会前
	假会话.free()
	_判(bool(_托管._在回城), "未：夹具——`走时长到点():712` 必须把 `_IsgoingHome` 摆真（实得 %s）" % str(_托管._在回城))
	_判(bool(_托管.在跑), "未：夹具——回城这一趟离开村图之前，挂机还得是开着的")
	_玩家.remove_child(_托管)
	_判(bool(_托管.在跑),
			"回城那一趟离树**不许**关挂机（原版 `clear():291` 那句 `if(!_IsgoingHome)`；单例带着 isStart=true 落到村里；实得 在跑=%s）" % str(_托管.在跑))
	## ── D：落回村里 ⇒ **新实例**的 `_ready()` 那一支 打坐 + 停挂，并且 `_IsgoingHome` 只消费一次
	## ⚠ 这里必须是 `new()` 而不是"把旧的那份重新挂回树"：`_ready()` 不会再跑第二次（见上面 B 末那条），
	##   拿旧实例判这一支等于判一段永远不会执行的代码（10-19 实测那三条红就是这么来的）。
	var 图备份 = _会话.current_map_id
	_会话.current_map_id = "100000000"
	_玩家.set("is_practising", false)
	var 村里那份 = _托管					# 离树那一支已经判完了，别让它 free 时再动真会话
	收掉旧托管(村里那份)
	重建托管()							# `_ready()` 当场跑：`_在回城` 还是真
	_判(bool(_玩家.get("is_practising")),
			"落回村 ⇒ requestHealStart（`:723`；由 `_ready` 里那一支补做，实得 打坐=%s）" % str(_玩家.get("is_practising")))
	_判(not bool(_托管.在跑) and not bool(_会话.hang_state.get("active", true)),
			"落回村 ⇒ isStart=false（`:724`；实得 在跑=%s 会话=%s）" % [str(_托管.在跑), str(_会话.hang_state.get("active"))])
	_判(not bool(_托管._在回城), "`_IsgoingHome` 要被这一支消费掉（`:712` 摆真、`setConfig:280`/`_ready` 清）")
	var 第三: Node = load("res://脚本/角色/挂机托管.gd").new()
	_玩家.add_child(第三)
	_判(not bool(第三.get("在跑")), "未·阳：`_IsgoingHome` 只能消费一次（再新建一份不该又走那一支）")
	收掉旧托管(第三)
	_会话.current_map_id = 图备份
	_玩家.set("is_practising", false)
	_托管._防抖剩余 = 0.0
	## ── ⑬ 挂机中点舞台空白地面 ⇒ 整个关掉（`World.as:814-817`）
	_重开()
	_等预热带过()
	_判(bool(_托管.在跑), "未：夹具——点地面之前要真的挂着")
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.position = Vector2(300.0, 300.0)
	按.global_position = Vector2(300.0, 300.0)
	var 停发前 := _上行发过几发(_托管, 1)
	## ── 临时量具：三条投递路各自到不到 `_unhandled_input`，以及 (300,300) 这点被哪些控件挡住
	var 挡的: Array = []
	var 列: Array = [_玩家.get_tree().get_root()] + _玩家.get_tree().get_root().get_children()
	for 控 in _玩家.find_children("*", "Control", true, 0):
		var gr: Rect2 = (控 as Control).get_global_rect()
		if gr.has_point(Vector2(300.0, 300.0)) and (控 as Control).visible \
				and int((控 as Control).mouse_filter) != 2:
			挡的.append(str((控 as Control).name) + ":" + str(int((控 as Control).mouse_filter)))
	for 控2 in _玩家.get_parent().get_children():
		if 控2 is Control:
			var g2: Rect2 = (控2 as Control).get_global_rect()
			if g2.has_point(Vector2(300.0, 300.0)):
				挡的.append("同层:" + str(控2.name))
	prints("探针未·甲 挡住(300,300)的控件=", str(挡的), "列=", 列.size())
	root.push_input(按)
	prints("探针未·乙 push_input 之后 在跑=", str(_托管.在跑), "停挂=", _上行发过几发(_托管, 1))
	if bool(_托管.在跑):
		Input.parse_input_event(按)
		await _等帧(2)
		prints("探针未·丙 parse_input_event 之后 在跑=", str(_托管.在跑), "停挂=", _上行发过几发(_托管, 1))
	if bool(_托管.在跑):
		_玩家.call("_unhandled_input", 按)
		prints("探针未·丁 手工调函数 之后 在跑=", str(_托管.在跑), "停挂=", _上行发过几发(_托管, 1))
	## ── 临时量具到此
	## ⚠ **真投递**，不是手工调 `_unhandled_input()`：`World.as:814` 那一支的前提是
	## "这一下点到了空白地面"，而事件要走到玩家那一侧才有那一支可言 —— 手工调函数只能证明
	## "我调过它"，证明不了"这一发 1808:1 真的出去了"（10-19 口径）。证据一律数会话那侧的出口。
	root.push_input(按)
	_判(not bool(_托管.在跑),
			"⑬ 挂机中点空白地面 ⇒ 关挂机（原版 `World.as:817` `guajiHandler.isStart = false`；以前只 `toAttackAnemy=false` ⇒ 下一拍又自动打起来；实得 在跑=%s）" % str(_托管.在跑))
	_判(not bool(_会话.hang_state.get("active", true)), "同一支要回会话（那颗『挂机中』球要灭，不能只改本地）")
	_判(_上行发过几发(_托管, 1) == 停发前 + 1,
			"点地面那一支就是走 `isStart=false` 那一整支 ⇒ 恰好补发一发 1808:1（实得 %d→%d）" % [停发前, _上行发过几发(_托管, 1)])
	## 反面：没在挂的时候再点一次地面 ⇒ 一发都不许补发（`value != _isStart` 那三道闸）
	root.push_input(按)
	_判(_上行发过几发(_托管, 1) == 停发前 + 1,
			"未·阳：没在挂时点地面不许再补发 1808:1（`置挂机态` 里 `要开 == 在跑` 那一道）；实得 %d" % _上行发过几发(_托管, 1))
	## ⚠ 段末约定：`_在回城` 是 **static**（原版单例的那面旗活得比一张图长）⇒ 全部门共用一份，
	## 本段不许把它带进后面的段（`重读配置():280` 是唯一清它的地方，`_重开()` 会走那一句）。
	_重开()
	_判(not bool(_托管._在回城), "未：段末必须把 static 的 `_IsgoingHome` 清回假（带着它污染后面每一段换图）")
	_摆空闲态()
	_改配置("autoBattleRange", 20)
	_托管.重算活动区(20)


## 数一份实例发过几发 1808 的某一档。`上行记录` 是模块给**在线腿**留的证据口，
## 这里只拿它数次数；期望次数由本段按原版自己算（离树那一支恰好一发）。
func _上行发过几发(一份: Node, 档: int) -> int:
	var 数 := 0
	for 条 in (一份.get("上行记录") as Array):
		if int((条 as Dictionary).get("档", -1)) == 档:
			数 += 1
	return 数


## ── 戌：赶路途中不许重排（用户 2026-10-19 实机报"上梯子一直上下上下"+"地面东西不捡只捡金币"）──
## 原版挑目标那一整块的入口条件是 `!player.isGPathFinding()`（`GuajiHandler.as:729`），而
## `isGPathFinding():1645-1648` = `nowInLadderToPathFind || isPathFinding()` —— **身上还挂着路线
## （含"等落地再重排"那枚暂存、以及"正在靠梯子完成寻路"）时一律不重新点目标、不再发寻路**。
## 本工程原来问的是 `自动寻路中`（屏幕那行提示的开关，挂机自己发的路线从来不点亮它）⇒ 这道闸
## 对挂机永远是开的：人在梯子上每一拍重发 `走向()`，而 `走向()` 里 `click_climb_direction`
## 按当下目标的 y 现算（`玩家.gd:230-231`）⇒ 目标在"下层掉落"与"上层怪"之间来回换 ⇒ 竖直方向来回翻。
## 追击那一侧同一道闸在 `SkillExecute.moveToAttack():95/133`，本工程也漏了（`_维持接近路线`）。
func _戌_赶路途中不重排() -> void:
	var 实体 = _玩家.get_parent().get_node_or_null("LifeRoot")
	if 实体 == null:
		_收尾("戌：拿不到 LifeRoot")
		return
	_重开()
	_等预热带过()
	_改配置("isCollectMoney", true)
	## 夹具：活动区里放一枚"要走过去才够得着"的掉落（>200 像素，同层 ⇒ 一定寻得出路）
	## ⚠ **要按编号等自己那一枚**（与 壬③ 同一手法）：前面几段在场上留过没被捡走的掉落，
	## 离线那侧的编号是**从 -1 往下走的循环小号**（本段实测拿到的就是上一段同一枚 `-2`），
	## 只按"区里有 ≥1 枚 / 离人 >200"来认靶子 ⇒ 认到的其实是**别人那一枚**，而 `_拾取在走`
	## 恰好也还攥着同一个编号 ⇒ 下一拍走进"到位验收"那一支被当场拉黑 ⇒ 本段①②量不到东西。
	_摆空闲态()
	var 戌号: int = int(实体.get("_离线掉落序号"))
	实体.call("_create_loot", Vector2(_玩家.position.x + 320.0, _玩家.position.y))
	_判(await _等这枚落地(实体, _托管._活动区, 戌号),
			"戌：夹具——本段自己掉的那一枚（号 %d）要落到地上并查得到（等不到就是靶子不存在）" % 戌号)
	var 那枚 = null
	for 掉 in (实体.call("挂机的掉落", _托管._活动区) as Array):
		if int((掉 as Dictionary).get("object_id", 1)) == 戌号 \
				and absf(float((掉 as Dictionary).get("x", 0.0)) - _玩家.position.x) > 200.0:
			那枚 = 掉
			break
	_判(那枚 != null, "戌：夹具——要有一枚离人 >200 像素的掉落当重排靶子（没有这段判不了）")
	if 那枚 == null:
		_收尾("戌：夹具不齐")
		return
	prints("探针戌·甲 会去捡=", str(_托管.会去捡()), "活动区=", str(_托管._活动区),
			"区内掉落=", str((实体.call("挂机的掉落", _托管._活动区) as Array).map(
					func(掉): return [int(掉.get("object_id", 0)), int(_托管.该不该捡(掉)), roundf(float(掉.get("x", 0))), roundf(float(掉.get("y", 0)))])),
			"我=", str(_玩家.global_position), "黑名单=", str(_托管._黑名单), "即时=", str(_托管._即时黑名单),
			"六档=", str([_托管._配置缓存.get("拾取装备"), _托管._配置缓存.get("拾取任务品"), _托管._配置缓存.get("拾取药品"),
					_托管._配置缓存.get("拾取金币"), _托管._配置缓存.get("拾取材料"), _托管._配置缓存.get("拾取其他")]),
			"空槽=", str(_托管._有空槽()))
	var 那枚号 := int((那枚 as Dictionary).get("object_id", 0))
	## ① 阳性对照：两把旗都关着 ⇒ 这一拍**必须真发出一条路线**（否则②③就是"什么都没发生"的假不敏感）
	_摆空闲态()
	var 旧落点 = _玩家.get("click_move_x")
	prints("探针戌·乙 调之前 会去捡=", str(_托管.会去捡()), "活动区=", str(_托管._活动区),
			"掉落=", str((实体.call("挂机的掉落", _托管._活动区) as Array).map(
					func(掉): return [int(掉.get("object_id", 0)), int(_托管.该不该捡(掉))])),
			"在赶路线=", str(_托管._在赶路线()), "追击=", str(_托管._追击), "待机动=", str(_托管._在待机动()),
			"拾取在走=", str(_托管._拾取在走), "我=", str(_玩家.global_position))
	_托管.拾取或打怪(false)
	prints("探针戌·丙 调之后 状态=", str(_托管.状态文字), "目标=", str(_托管.目标), "拾取在走=", str(_托管._拾取在走))
	_判(str(_托管.状态文字) == "拾取", "戌·阳：空档时这一枚要走过去捡（实得 %s）" % str(_托管.状态文字))
	_判(bool(_玩家.get("click_move_active")) or float(_玩家.get("click_move_x")) != float(旧落点),
			"戌·阳：这一拍要真的发出路线（点亮路线旗或改写落点，否则下面几条是 0 比 0）")
	_判(_托管._拾取在走 == 那枚号, "戌·阳：答应走过去就得记下这一枚（实得 %s）" % str(_托管._拾取在走))
	## ② 路线还在身上（真机挂机那一刻就是这副态：路线旗真、提示旗假）⇒ 整块不许动
	_摆空闲态()
	_玩家.set("click_move_active", true)
	_玩家.set("自动寻路中", false)
	var 落点二 = _玩家.get("click_move_x")
	_托管._拾取在走 = 那枚号
	_托管.拾取或打怪(false)
	_判(str(_托管.状态文字) == "", "身上有活动路线时不许重新点目标（原版 `!isGPathFinding():729`；实得 %s）"
			% str(_托管.状态文字))
	_判(float(_玩家.get("click_move_x")) == float(落点二), "更不许插一条新路线（落点被改写=抢路线，就是上下抖那股力）")
	_判(not bool(_托管.黑名单里(那枚号)), "赶路途中那一枚不许被拉黑（原版只在**寻路当场失败**时才 signWrong，`:784-791`）")
	## ③ 只剩"自动爬梯中"这一半（路线尾格已交完、人还在梯上）⇒ 同样不许动
	_摆空闲态()
	_玩家.set("click_move_active", false)
	_玩家.set("自动爬梯中", true)
	var 落点三 = _玩家.get("click_move_x")
	_托管.拾取或打怪(false)
	_判(str(_托管.状态文字) == "", "只有『自动爬梯中』时也属于 isGPathFinding，不许重排（实得 %s）" % str(_托管.状态文字))
	_判(float(_玩家.get("click_move_x")) == float(落点三), "爬梯途中不许改写落点")
	_摆空闲态()
	## ④ 10-19 删掉自造的"直线走"（`挂机托管.移动方向()` + 72/100 两个常数）之后，
	##    挂机挑中怪/掉落/归位这三条**只剩一条**执行路径：`走向()` 发的真寻路，
	##    由 `玩家._走点击路线()` 逐格执行（旧判据"移动方向给不给 ±1"随那一支一起删）。
	var 全: Array = 实体.call("挂机的全部怪")
	var 怪: Node2D = null
	if 全.is_empty():
		_判(false, "戌：夹具——图上要至少有一只怪当追打目标（缺了④判不了）")
	else:
		怪 = 全[0]
		搬到画面内(怪, 320.0)					# 320 像素 ⇒ 普攻盒够不着（原版 `moveToAttack:133` 走 pathFind）
		_摆空闲态()
		_玩家.set("_接近冷却", 0.0)
		_玩家.set("_接近上次目标", Vector2.INF)
		_玩家.call("开始自动接近", 怪)
		_玩家.call("_冲选中目标", 怪)
		_判(bool(_玩家.get("click_move_active")),
				"④ 够不着时这一拍要发出**一条真寻路路线**（原版 `SkillExecute.moveToAttack:133-143` 那一支 `pathFind(怪.x, 怪.y-5)`；实得 %s）" % str(_玩家.get("click_move_active")))
		_判((_玩家.get("auto_actions") as Array).size() > 0,
				"④ 而且必须是**分格的动作序列**（自造那条直线走只会给 ±1、从来不排 auto_actions ⇒ 路线发出去没人执行，就是用户报的『开始挂机人钉在原地』；实得 %d 段）" % (_玩家.get("auto_actions") as Array).size())
		_玩家.set("click_move_active", false)
	## ⑤ 玩家侧：`_维持接近路线` 重排前要有 `!isGPathFinding()`（原版 `SkillExecute:95/133`）
	if 怪 != null:
		_托管.set("目标", null)
		_玩家.set("_接近冷却", 0.0)
		_玩家.set("_接近上次目标", Vector2.INF)
		_玩家.set("click_move_active", true)
		var 追击落点 = _玩家.get("click_move_x")
		_玩家.call("_维持接近路线", 怪)
		_判(_玩家.get("_接近上次目标") == Vector2.INF,
				"追击在有路线时不许重排（`_接近上次目标` 被写=它插了新路线，实得 %s）" % str(_玩家.get("_接近上次目标")))
		_判(float(_玩家.get("click_move_x")) == float(追击落点), "同上：落点不许被追击那一支改写")
		_玩家.set("click_move_active", false)
		_玩家.set("_接近冷却", 0.0)
		_玩家.call("_维持接近路线", 怪)
		_判(_玩家.get("_接近上次目标") != Vector2.INF, "戌·阳：没有路线时追击必须重排（否则上面两条是恒真）")
	## ⑥ 空格口径必须按**服务端权威格数**数（用户"只捡金币"那条的口径锁，与 09-27 活跃度提示同病）
	var 备 := _备份背包()
	var 原容量 = _后端.get("authoritative_bag_capacity")
	_摆背包([{"id": "01210441", "quantity": 1}, {"id": "03000001", "quantity": 1}])
	_后端.set("authoritative_bag_capacity", 2)
	_判(int(_会话.背包总格数()) == 2, "戌：总格数必须先吃服务端权威值（实得 %d）" % int(_会话.背包总格数()))
	_判(not bool(_托管._有空槽()), "真实 2 格占满 ⇒ 要判『没空格』。按常量 96 扫会数到第 3 格=空 ⇒ 挂机发拾取、"
			+ "服务端按 2 格判满而**静默不删那枚掉落** ⇒ 地上的东西永远躺着、只有不占格的金币进得来")
	_后端.set("authoritative_bag_capacity", 5)
	_判(bool(_托管._有空槽()), "戌·阳：容量 5、只占 2 ⇒ 要有空格（没有这条阳性对照，上面那条就是恒真）")
	_后端.set("authoritative_bag_capacity", 原容量)
	_还原背包(备)
	## ⑦ 90 像素这一档是原版 `canPickItem:1201-1204` 的字面值，两侧都要钉
	for 档 in [[80.0, 1], [95.0, 2]]:
		var 假 := {"item_id": "", "is_meso": true, "owner_id": 0,
				"x": float((_玩家.get("global_position") as Vector2).x) + float(档[0]),
				"y": float((_玩家.get("global_position") as Vector2).y)}
		_判(int(_托管.该不该捡(假)) == int(档[1]),
				"离那枚 %s 像素 ⇒ 档位应为 %s（实得 %d）" % [str(档[0]), str(档[1]), int(_托管.该不该捡(假))])
	## ⑧ 拾取队列：一次排若干、**每一拍只吞一枚**，而且吞的时候**不许被那份 200ms 全局节流挡住**
	## （原版 `onEnterFrame():1103-1115` 每吞一枚就 `refreshPickTime()` ⇒ 一堆掉落按每秒约 60 枚排空；
	## 上一版没有队列 ⇒ 同一拍把所有够得着的都发一遍、被 `_拾取闸` 挡成只发第一枚 ⇒ 每秒约 5 枚，
	## 用户看到的"一地东西清得很慢"就是它）。
	_摆空闲态()
	_托管.拾取队列.clear()
	for 偏 in [-40.0, 0.0, 40.0]:
		实体.call("_create_loot", _玩家.position + Vector2(偏, 30.0))
	var 落了: int = await _等落地(实体, _托管._活动区, 3)
	_判(落了 >= 3, "戌：夹具——身边要至少落着 3 枚（缺了⑧判不了），实得 %d" % 落了)
	var 前八: int = (实体.call("挂机的掉落", _托管._活动区) as Array).size()
	_托管.拾取或打怪(false)
	_判((_托管.拾取队列 as Array).size() >= 3,
			"够得着的每一枚都要进队列（原版对每枚都只 push）；实得 %d 枚，场上 %d 枚" % [
				(_托管.拾取队列 as Array).size(), 前八])
	_托管._吞一枚拾取()
	_托管._吞一枚拾取()
	_托管._吞一枚拾取()
	var 后八: int = (实体.call("挂机的掉落", _托管._活动区) as Array).size()
	_判(前八 - 后八 == 3,
			"连吞三拍要真发出三枚（被 200ms 节流挡住就是只发得出第一枚 ⇒ 清得慢的那条老毛病）；前 %d 后 %d" % [前八, 后八])
	_摆空闲态()
	_托管.拾取队列.clear()
	## ── ⑤ `_吞一枚拾取()` 转写的是原版 `onEnterFrame():1110-1111` **两句**：
	##   `pickDropItem(_toPickItems.shift())` —— 走节流的 `DropItemHandler.pickDropItem(item, true)`，
	##     里面 `canItemPickup(item, true)` 那一关要是撞上 `pickitemTimeLimit > 0` **就直接 return**
	##     （这一枚已经被 shift 掉了 ⇒ **当场作废**，不重排）；过了才把 `pickitemTimeLimit = 200`；
	##   `refreshPickTime()` —— 紧接着把那份全局节流归 0（`DropItemHandler.as:94-97`）。
	##   两句各自的证据分得很开：**单枚锁定表**只有第一句会写、**闸归零**只有第二句会写。
	##   上一版这里传 `false` 绕开节流（"吞的时候永远发得出"），那是假的快：把手动按 Z 抢掉。
	var 全图 := Rect2(-1000000.0, -1000000.0, 2000000.0, 2000000.0)
	_摆空闲态()
	_托管.拾取队列.clear()
	实体.call("_create_loot", _玩家.position + Vector2(30.0, 60.0))
	_判(await _等落地(实体, 全图, 1) >= 1, "戌：夹具——⑤ 这一枚要落到地上（飞行中的原版本来就不许捡）")
	var 掉列: Array = 实体.call("挂机的掉落", 全图)
	_判(掉列.size() >= 1, "戌：夹具——⑤ 要查得到那一枚掉落（查不到这一段是 0 比 0）")
	if 掉列.size() >= 1:
		var 号一 := int((掉列[0] as Dictionary).get("object_id", 0))
		var 锁表: Dictionary = 实体.get("_锁定表")
		## A：闸是开的 ⇒ 两句都跑到
		实体.set("_拾取闸", 0.0)
		锁表.erase(号一)
		_托管.排队拾取(号一)
		_托管._吞一枚拾取()
		_判((_托管.拾取队列 as Array).is_empty(),
				"⑤ 吞一枚要把队首 pop 掉（原版 `shift()`，作废也一样被吞走）；实得 %s" % str(_托管.拾取队列))
		_判(float(锁表.get(号一, 0.0)) > 0.0,
				"⑤ 第一句 `发拾取(号)` 要真跑到（只有它会给这一枚上单枚锁；实得锁=%s ⇒ 第一句没调）" % str(锁表.get(号一)))
		_判(float(实体.get("_拾取闸")) == 0.0,
				"⑤ 第二句 `刷新拾取时间()` 要紧接着把那份 200ms 全局节流归零（`:1111`；实得 %s ⇒ 少了第二句，吞吐退回每秒 5 枚）" % str(实体.get("_拾取闸")))
		## B：闸 >0 ⇒ 这一枚**当场作废**（原版 `canItemPickup(item, true)` 挡住）
		实体.set("_拾取闸", 200.0)
		锁表.erase(号一)
		_托管.排队拾取(号一)
		var 场上前: int = (实体.call("挂机的掉落", 全图) as Array).size()
		_托管._吞一枚拾取()
		_判((_托管.拾取队列 as Array).is_empty(),
				"⑤ 撞上节流时这一枚也已经被吞走（原版不重排 ⇒ 当场作废；实得 %s）" % str(_托管.拾取队列))
		_判(float(锁表.get(号一, 0.0)) == 0.0,
				"节流闸 >0 ⇒ 这一枚**不许**发出去（`canItemPickup(item, true)` 那一关；上一版传 false 绕开就是抢手动按 Z；实得锁=%s）" % str(锁表.get(号一)))
		_判(float(实体.get("_拾取闸")) == 0.0,
				"作废那一跑第二句 `刷新拾取时间()` 照样要执行（`:1111` 排在 if 外面，与第一句过没过无关；实得 %s）" % str(实体.get("_拾取闸")))
		## B 的阳性对照：把闸摆回 0、同一枚再排一次 ⇒ 必须发得出去
		实体.set("_拾取闸", 0.0)
		_托管.排队拾取(号一)
		_托管._吞一枚拾取()
		_判(float(锁表.get(号一, 0.0)) > 0.0,
				"戌·阳：闸一开同一枚就发得出去（没有这条，上面『不许发出去』那条就是恒真）；实得锁=%s" % str(锁表.get(号一)))
		var 场上后: int = (实体.call("挂机的掉落", 全图) as Array).size()
		_判(场上后 <= 场上前, "戌：夹具——作废那一跑场上不许少东西（发了才算少；前 %d 后 %d）" % [场上前, 场上后])
		实体.set("_拾取闸", 0.0)
		锁表.erase(号一)
	_摆空闲态()
	_托管.拾取队列.clear()


## ── 亥：挑怪那两份谓词**逐句转写**之后，各条自己可证伪（10-19 深夜）──
## 原版是两个函数：`SkillHandler.canAttack:443-474`（这只打不打得）与
## `GuajiHandler.toAttackMonster:1117-1120`（这一轮要不要去攻它），
## 而"被打还手"那一支（`:796-:797`）用的**只有 canAttack**。上一版我合成一份 `可打()`，
## 于是 `outOfStage`（屏幕外不算目标）整条漏掉，黑名单也串到了还手那一支上。
func _亥_两份谓词() -> void:
	var 实体 = _玩家.get_parent().get_node_or_null("LifeRoot")
	if 实体 == null:
		_收尾("亥：拿不到 LifeRoot")
		return
	_重开()
	_等预热带过()
	var 全: Array = 实体.call("挂机的全部怪")
	_判(全.size() >= 1, "亥：夹具——图上至少要有一只怪（实得 %d）" % 全.size())
	if 全.is_empty():
		_收尾("亥：夹具不齐")
		return
	var 怪: Node2D = 全[0]
	怪.set("alive", true)
	怪.set_meta("attacked_by_mob", false)
	_托管._黑名单.clear()
	## ① `outOfStage`：屏幕外那一只不算能打的（原版 `:451-454`），搬回画面里就必须算
	搬到画面内(怪, 120.0)
	_判(bool(_托管.能攻(怪)), "亥·阳：画面内、活着、没咬上别人的怪要算『能攻』")
	var 我位: Vector2 = _玩家.get("position") as Vector2
	怪.set("position", 我位 + Vector2(9000.0, 0.0))
	怪.set("global_position", 怪.get("position"))
	_判(not bool(_托管.能攻(怪)),
			"屏幕外那一只不算能攻（原版 `SkillHandler:451` + `DisplayUtil.outOfStage:152-185`；"
			+ "以前整条漏掉 ⇒ 挂机去追镜头外的怪，人朝看不见的方向走）")
	搬到画面内(怪, 120.0)
	## ② 黑名单只挡"要不要去攻它"，**不挡"这只打不打得"** ⇒ 咬我的那只即使在拉黑期内也要还手
	_托管.拉黑(_托管._目标键(怪))
	_判(bool(_托管.能攻(怪)), "亥：在黑名单里不影响『能攻』（那一档属于 toAttackMonster，不属于 canAttack）")
	_判(not bool(_托管.去攻这只(怪)), "亥：但在黑名单里的这只，挑怪那一趟不许再去攻（原版 `:1118` 的 `!isWrong`）")
	_托管._黑名单.clear()
	## ③ `mobInfo != null`：图鉴里查不到这一类怪就不算一只怪（原版 `:1117`，在 canAttack 之外）
	var 原号 = 怪.get("entity_id")
	怪.set("entity_id", "99999999")
	_判(not bool(_托管.去攻这只(怪)), "亥：图鉴里查不到定义的怪不算可攻目标（原版 `mobInfo != null`）")
	_判(bool(_托管.能攻(怪)), "亥：但 canAttack 那一支不看图鉴（两支的分工要分得开，否则合成一份就又糊了）")
	怪.set("entity_id", 原号)
	## ④ `getNearestLifeObj:51-54/68-71`：画面外的候选**当场剔出堆**，取走的那一枚也**移出堆**
	var 堆: Array = [怪]
	怪.set("position", 我位 + Vector2(9000.0, 0.0))
	怪.set("global_position", 怪.get("position"))
	_判(_托管.最近活物(堆) == null and (堆 as Array).is_empty(),
			"最近活物要把屏幕外的候选从堆里剔掉（原版 splice 同一件事，`getNearestLifeObj:51-54`）")
	搬到画面内(怪, 120.0)
	堆 = [怪]
	_判(_托管.最近活物(堆) == 怪 and (堆 as Array).is_empty(),
			"最近活物取走的那一枚要同时移出堆（原版 `:68-71` 的 splice ⇒ 调用方 while 循环不会重复挑它）")
	_摆空闲态()


## ── ⑫ 与 ⑮ 那两段的记录桩 ──────────────────────────────────────────
## ⚠ 期望值一律本门自己算、自己数，不许拿"实现里那份 `上行记录`"当证据
## （问被测对象要答案 = 自证；桩只接住被测函数会打出去的那几个口，别的什么都不做）。
class 记录会话 extends Node:
	var current_map_id := "101010000"
	var 挂机配置: Dictionary = {}			# `读配置快照()` 走 `设()` 时要知道这张表存在
	var 换图请求: Array = []
	var 停挂次数 := 0
	var 开挂次数 := 0

	func request_map_change(图号: String, _门: String) -> void:
		换图请求.append(图号)

	func request_hang(要开: bool) -> bool:
		if 要开:
			开挂次数 += 1
		else:
			停挂次数 += 1
		return true


class 记录后端 extends Node:
	var in_game := false
	var 打坐次数 := 0
	var 卖装: Array = []

	func request_heal_start() -> bool:
		打坐次数 += 1
		return true

	## 原版 `WaiGuaHandler.onPackFull():324-342` 的第一句；
	## 参数顺序照 `fake_flash_server` 那支 `(shop, 格数, 品质档)`。
	func request_npc_shop_one_key_sell(店: int, 格数: int, 档: int) -> bool:
		卖装.append([店, 格数, 档])
		return true


## 辰段那份干净实例的后端：`in_game = true` ⇒ `_上行()` 走在线那一支
## （原版 `GuajiHandler` 自己 `put_data`，**不回头改 isStart**），
## 于是"这一趟到底发了几发 1808"是本门自己数的两个计数器，不是模块那份 `上行记录`。
class 记录挂上行 extends Node:
	## ⚠ 桩**必须把 `player_damaged` 也声明上**：`挂机托管._exit_tree:177` 无条件读
	##   `_后端.player_damaged.is_connected(...)`，桩没这条信号 ⇒ 释放那一刻抛
	##   `Invalid access to property or key 'player_damaged'`（判据照样全绿、退出码照样 0，
	##   只在日志里留一行 —— §3.253 在全量日志里抓到过一次）。
	signal player_damaged(state: Dictionary)
	var in_game := true
	var 开 := 0
	var 停 := 0

	func request_hang_start() -> bool:
		开 += 1
		return true

	func request_hang_stop() -> bool:
		停 += 1
		return true


func _收尾(额外失败 := "") -> void:
	if not 额外失败.is_empty():
		_红.append(额外失败)
	if _会话 != null:
		_会话.request_hang(false)
		## ⚠ 光按字节还原文件不够：`quit()` 之前任何一处 `_save_local_state()` 都会把
		## **内存里那份**再写回盘 ⇒ 本门跑完 `auto_combat` 又变回 true（10-19 实测：
		## 共用 user:// 的`玩家数据.json`带着"挂机中"过夜，用户自己那台客户端一起就是挂机态）。
		## 所以还原前先把会话内存里的 `game_settings` 换回快照那一份。
		var 原字节: PackedByteArray = _存档前.get(存档路, PackedByteArray())
		if not 原字节.is_empty():
			var 解 = JSON.parse_string(原字节.get_string_from_utf8())
			if 解 is Dictionary and (解 as Dictionary).has("game_settings"):
				var 旧: Dictionary = (解 as Dictionary)["game_settings"]
				var 设置: Dictionary = _会话.game_settings
				设置.clear()
				for 键名 in 旧:
					设置[键名] = 旧[键名]
	_还原(_存档前)
	if _红.is_empty():
		print("挂机行为回归测试：通过（%d 条判据）" % _判数)
		quit(0)
		return
	for 条 in _红:
		print("红：", 条)
	print("挂机行为回归测试：判 %d 条，红 %d 条" % [_判数, _红.size()])
	quit(1)


## 跨层：玩家在 1 层、目标在 2 层时，挂机不许锁它（10-26 实机「一直上下梯子」）。
## 原版 `floor` 是**连通脚点链编号**（`MapData.as:392-440`），不是渲染层 `layer`；
## 本工程旧实现读了 `layer`（整张烘焙图都是同一个值）⇒ 上下层判成同层。
func _跨层_不锁上层怪() -> void:
	var 场 := _玩家.get_parent()
	var 实体 = 场.get_node_or_null("LifeRoot")
	var 脚点 = 场.get_node_or_null("Footholds")
	if 实体 == null or 脚点 == null:
		_判(false, "跨层：夹具——LifeRoot / Footholds 都要在")
		return
	_重开()
	_等预热带过()
	var 我层 := int(_托管._层号())
	_判(我层 >= 0, "跨层：夹具——玩家要算得出地面号（实得 %d）" % 我层)
	var 表: Dictionary = 脚点.get("id_map")
	var 我脚 := String((脚点.call("find_foothold", _玩家.position.x, _玩家.position.y, "") as Dictionary).get("id", ""))
	var 我段: Dictionary = 表.get(我脚, {})
	_判(not 我段.is_empty(), "跨层：夹具——玩家脚下要有脚点段")
	var 同链 := ""
	for 邻 in [我段.get("prev"), 我段.get("next")]:
		var 邻号 := String(邻)
		if 邻号 != "" and 邻号 != "0" and 邻号 != "-1" and 表.has(邻号):
			同链 = 邻号
			break
	_判(not 同链.is_empty() and int(脚点.call("连通地面号", 同链)) == 我层,
			"同一条连通链的相邻段必须同地面号（原版 MapData.floor）")
	var 异段: Dictionary = {}
	for id in 表:
		var 号 := int(脚点.call("连通地面号", String(id)))
		if 号 >= 0 and 号 != 我层:
			异段 = 表[id] as Dictionary
			break
	_判(not 异段.is_empty(), "跨层：夹具——地图里要有一条和玩家不同地面号的脚点")
	if 异段.is_empty():
		return
	_判(int(脚点.call("连通地面号", String(异段.get("id", "")))) != 我层,
			"不同连通链的地面号必须不同（旧实现读渲染层 layer，整张图都是 1）")
	var 全: Array = 实体.call("挂机的全部怪")
	var 怪 = null
	for e in 全:
		if is_instance_valid(e) and bool(e.get("alive")):
			怪 = e
			break
	_判(怪 != null, "跨层：夹具——要有一只活怪可搬")
	if 怪 == null:
		return
	var 原位: Vector2 = (怪 as Node2D).global_position
	var 异x := (float(异段.get("x1", 0)) + float(异段.get("x2", 0))) * 0.5
	(怪 as Node2D).global_position = Vector2(异x, float(异段.get("y1", 0)))
	var 异号 := int(实体.call("怪的层号", 怪))
	_判(异号 == int(脚点.call("连通地面号", String(异段.get("id", "")))) and 异号 != 我层,
			"搬到另一条地面后，怪的层号要跟着变（实得 %d / 我 %d）" % [异号, 我层])
	_判(not bool(_托管._同层(怪)), "跨层目标 `_同层` 必须为假")
	var 全村 := Rect2(-100000.0, -100000.0, 200000.0, 200000.0)
	var 同层表: Array = 实体.call("挂机的同层怪", 我层, 全村)
	_判(not 同层表.has(怪), "跨层怪不许出现在『挂机的同层怪』里（旧实现会混进来）")
	var 源 := FileAccess.get_file_as_string("res://脚本/角色/挂机托管.gd")
	_判(源码含(源, "if not _同层(候):"), "放宽到全部怪那一趟也要过同层闸（不能只靠第一趟）")
	_判(源码含(源 + "\n\t\t\t\tif not _同层(自检):\n", "if not _同层(自检):"),
			"文本量具自检·阳：同层闸插到非注释处必须查得到")
	_判(not 源码含(源 + "\n\t\t\t\t## if not _同层(自检):\n", "if not _同层(自检):"),
			"文本量具自检·阴：只写在注释里必须查不到")
	(怪 as Node2D).global_position = 原位
