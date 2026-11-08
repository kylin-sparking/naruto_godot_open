extends SceneTree

## 「多窗口」窗口**行为契约**体检 —— 玩家手感那几条，单独钉一套。
##
## 为什么要有它：`功能入口回归测试` 验的是"入口能不能打开正确的页"，
## 但玩家手感那几条 —— **再点一次要关掉**、**关了再开要回原处**、**点谁谁在前** ——
## 一条都没钉。用户 2026-09-24 实机报的三条症状全落在这个缝里。
##
## ⚠️ 加载的是**运行时真正加载的那个场景**（`地图资源.playable_scene_path()` →
##    `场景/生成/地图_<id>_烘焙.tscn`），不是 `场景/地图/地图场景.tscn`。
##    后者是**源场景**，168 张烘焙图没重烤时两者行为不一致 —— 2026-09-24 拿源场景
##    验过一次，验了个假。所以这里显式断言路径含 `场景/生成/`。
##
## 断言一律打在**绝对矩形**（`get_global_rect()`）上，不依赖 `取位置偏移()` ——
## 后者与 `窗口偏移()` 是否互逆本身就是一条待钉的契约（见 B 组）。
##
## 用法：
##   Godot --headless --path . --script res://测试/窗口行为契约体检.gd [-- --地图=101010000]

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 功能窗口脚本 := preload("res://脚本/界面/功能窗口.gd")
const 摊位窗脚本 := preload("res://脚本/界面/窗口/摆摊/摊位窗.gd")
const 神秘商店窗脚本 := preload("res://脚本/界面/窗口/神秘商店/神秘商店窗.gd")
const 后端连接脚本 := preload("res://脚本/单例/后端连接.gd")

## 戊组里那五页是**数据门控**的（见 `_喂数据`）：有夹具文件的现读原文、不手抄第二份；
## 没有夹具文件的（双修/神秘商店）按**服务端那条线的真字序**现摆一条。
const 交易夹具路径 := "res://数据/界面/交易夹具.json"
const 摆摊夹具路径 := "res://数据/界面/摆摊夹具.json"
const 竞技场夹具路径 := "res://数据/界面/竞技场夹具.json"
const 竞技场窗脚本 := preload("res://脚本/界面/窗口/竞技场窗.gd")
## 「开窗之前灌的那一帧会被开窗那次渲染重新藏掉」的那一族 ⇒ 开窗后按同一条腿再喂一次（见 `_戊_全页走查`）。
const 开窗后补喂: Array[String] = ["竞技场"]
## 双修那页的守卫是「同屏表里查得到邀请者」（`功能窗口._render_shuangxiu_invite`），
## 而体检场景里没有真远程玩家 ⇒ 按 **162 出生帧解出来那一份**塞一条进去。
## ⚠ 键名以前写的是 `guildName`（自造名，162 那一份里根本没有）⇒ 这行在体检里也是空白而没人红。
## 现在与 `_handle_spawn_player_text` 一致：`family_name`（没家族是字面 `-`）。
const 邀请者号 := 1002
const 邀请者态 := {"character_id": 1002, "name": "油女澪", "level": 23, "face": 10000204,
		"job": 2, "family_name": "木叶"}
## 族邀那一页的夹具。⚠ 原文段序 = 服务端 `fake_flash_server._send_family_invitation:22310-22313`
## 那个 f-string（族长名/级/职/脸/族名/族长角色号/家族号），**不是**手写猜的；
## 下面那份字典就是它解出来应该得到的东西 ⇒ 两头一起钉住（离线门 ①、契约体检戊、在线门 §⑦）。
const 族邀原文 := "1552:16:契约族长:31:2:10000204:契约族:2088:91"
const 族邀数据 := {"name": "契约族长", "playerName": "契约族长", "level": 31, "job": 2,
		"face": 10000204, "famillyName": "契约族", "charId": 2088, "id": 91}
## 求婚（羁绊）那一扇的夹具：段序照 `fake_flash_server._handle_multiplayer_friend:23236-23241`
## 那条 f-string `14:<名>:<级>:<职>:<族名>:<脸>:<号>`（**族名在第 4 位**，而 `CharInfoPane` 读的键叫 `banghui`）。
## face 用盘上真有的头像号，理由同族邀那一条。
const 求婚原文 := "61:14:契约求方:31:2:契约族:10000204:2088"
const 求婚数据 := {"是被求": false, "人": {"name": "契约求方", "level": 31, "job": 2,
		"banghui": "契约族", "face": 10000204, "charId": 2088}}
## 赠花那一扇的夹具。⚠ 数据是**两半**，少喂一半就是"页开着但左栏全空"那种假过：
## · 回帧 `58:2`（友好度/统计/五条记录/三档花）——段序照服务端那条十个固定段的 f-string，
##   条内 `&`、条间 `@`、空表写 `-`；
## · 对面那四项（号/名/脸/级）在**点菜单那一刻**存进 `窗口管理._赠花对面`，回帧里没有。
## 下面两条与 `测试/赠花窗回归测试.gd` 的夹具同形状（cid 取 2088，与族邀/求婚那一族对齐，
## 且必须 ≠ 本端 `character_id`，否则走的是原版 `MyFlowerWindow` 那一支、赠花窗根本不顶出来）。
const 赠花号 := 2088
const 赠花原文 := "58:2:2088:10000204:137:60:21:2:" \
		+ "契约花主&2088&20&30&10000204&2&31&16000143" \
		+ "@契约妖姬&2089&99&3600&10000205&1&44&16000149:" \
		+ "99&0&1&500&0&16000149@1&5040&1000&1&0&16000143@20&151200&20&20&0&16000143"
const 赠花对面 := {"charId": 2088, "name": "契约花主", "level": 31, "face": 10000204}

const 默认地图 := "101010000"
## 设计视口（`RenderProfile.DESIGN_SIZE`）。无头下必须显式顶掉，见 `_建场景`。
const 设计视口 := Vector2i(960, 560)
## 几何比较的容差（px）。窗口尺寸是内容撑出来的，取整会有一两像素抖动。
const 容差 := 1.5
## 顶点不动时用来找重叠区的最小窗口数
const 重叠试探步 := 40.0

var _失败: Array[String] = []
var _跳过: Array[String] = []
var _场景: Node = null
var _管理: Node = null
var _会话: Node = null
var _地图 := 默认地图
## 无头环境下合成鼠标事件能不能拿到 GUI 命中（见 `_探合成事件`）。
var _合成可用 := false


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2 and 键值[0] == "--地图":
			_地图 = 键值[1]
	call_deferred("_跑")


func _跑() -> void:
	if not await _建场景():
		_收尾()
		return
	await _甲_开关切换()
	await _乙_位置记忆()
	await _丙_层级()
	await _丁_不出屏()
	await _戊_全页走查()
	await _己_被盖住的窗()
	await _庚_购买弹窗模态()
	await _庚_意志成对()
	_收尾()


# ── 场景 ──────────────────────────────────────────────────────────────

func _建场景() -> bool:
	# ⚠️ 无头模式下根视口是 **64x64**（`DisplayServer` 是 dummy，屏幕报 0x0），
	#    而窗口钳制、居中、越界判定全都按视口算 —— 不顶掉的话这些断言全是失真的。
	#    实测：设成设计尺寸后，人物窗落在 (221.5, 60.0)，与实机截图逐位一致。
	root.size = Vector2i(设计视口)
	await _等帧(1)
	if root.get_visible_rect().size != Vector2(设计视口):
		_失败.append("视口顶不掉：期望 %s 实为 %s —— 几何类断言会失真" % [设计视口, root.get_visible_rect().size])
		return false

	var 路径: String = 地图资源.playable_scene_path(_地图)
	print("窗口行为契约体检：加载 ", 路径)
	if not 路径.contains("场景/生成/"):
		_失败.append("加载的不是烘焙场景（%s）—— 实机走的是 playable_scene_path()，拿源场景验等于验了个假" % 路径)
		return false
	var 包 := load(路径) as PackedScene
	if 包 == null:
		_失败.append("烘焙场景加载失败：%s" % 路径)
		return false
	_场景 = 包.instantiate()
	root.add_child(_场景)
	current_scene = _场景
	_管理 = _场景.get_node_or_null("窗口管理")
	if _管理 == null:
		_失败.append("场景里没有 `窗口管理` 节点 —— 烘焙图没重烤？")
		return false
	_会话 = root.get_node_or_null("GameSession")
	if _会话 == null:
		_失败.append("没有 GameSession 单例")
		return false
	await _等帧(2)
	print("窗口行为契约体检：视口=%s 遮罩=%s" % [root.get_visible_rect().size, _遮罩尺寸()])
	_合成可用 = await _探合成事件()
	return true


## `遮罩` 是窗口的定位基准（`主窗口` 的锚点在它中心），量一下免得对齐算错。
func _遮罩尺寸() -> Vector2:
	for 页 in _页名们():
		var 窗 := _窗(String(页))
		if 窗 != null:
			var 遮 := 窗.get_node_or_null("遮罩") as Control
			if 遮 != null:
				return 遮.size
	return Vector2.ZERO


## 每个分组开始前清干净：全关 + 抹掉"记住的位置"，否则上一组留下的位置会串到下一组。
func _清场() -> void:
	_管理.call("全部关闭")
	_管理.set("_记住的位置", {})
	await _等帧(3)


## 对照组：本环境里合成鼠标事件到底能不能更新 GUI 命中。
##
## 项目验过 `Input.parse_input_event` 对拖放无效，但 `push_input` 在**无头**下的
## 行为没被单独验过（此前所有合成事件的用法都是有头的）。若这里拿不到 hovered，
## 命中类断言一律**跳过而非通过**，并让整套非零退出 —— 免得给出假绿。
## 照 `开发工具/拖放通路体检.gd` 那条"对照组没收到 → 上面各行一律作废"的写法。
func _探合成事件() -> bool:
	_管理.call("打开", "人物")
	await _等帧(3)
	var 矩形 := _矩形("人物")
	if 矩形.size == Vector2.ZERO:
		return false
	_发移动(矩形.position + 矩形.size * 0.5)
	await _等帧(2)
	var 命中 := root.gui_get_hovered_control()
	if 命中 == null:
		print("窗口行为契约体检：⚠️ 本环境合成鼠标拿不到 GUI 命中 —— 命中类断言跳过（请跑有头的 开发工具/窗口走查.gd）")
		return false
	return true


# ── 甲：开 / 关切换 ────────────────────────────────────────────────────

func _甲_开关切换() -> void:
	await _清场()

	await _点底栏("背包")
	_检(_已开("背包"), "A1 点一下应打开背包")
	_检(_当前页("背包") == "背包", "A1 背包窗应停在自己的页，实为「%s」" % _当前页("背包"))
	# 背包的标题会追加计数后缀（「背包(6/96)」），只要求前缀对得上。
	_检(_标题("背包").begins_with("背包"), "A1 背包窗标题应以「背包」开头，实为「%s」" % _标题("背包"))

	await _点底栏("背包")
	_检(not _已开("背包"), "A2 再点一下应**关闭**背包（现在会自己又打开，还会把位置复位）")
	_检(is_instance_valid(_窗("背包")), "A2 关掉的实例应还留在树里，页面状态不该丢")

	await _点底栏("背包")
	_检(_已开("背包"), "A3 第三下应重新打开")

	await _点底栏("人物")
	_检(_已开("人物") and _已开("背包"), "A4 人物与背包应**同时**开着（多窗口的立身之本）")
	_检(_当前页("背包") == "背包", "A4 背包不该被人物顶掉，实为「%s」" % _当前页("背包"))

	_管理.call("全部关闭")
	await _等帧(2)
	var 还开着: Array[String] = []
	for 页 in _页名们():
		if _已开(String(页)):
			还开着.append(String(页))
	_检(还开着.is_empty(), "A5 全部关闭后不该还有开着的窗：%s" % [还开着])


# ── 乙：位置记忆 ──────────────────────────────────────────────────────
#
# 全部用绝对矩形比 —— 拖动（`_on_title_input` 改 `global_position`）最终
# 也是落在矩形上的，所以这才是玩家看到的那条。

func _乙_位置记忆() -> void:
	await _清场()

	await _点底栏("背包")
	var 居中 := _矩形("背包")
	_检(居中.size != Vector2.ZERO, "B0 背包窗应有非零矩形")

	# ⚠️ 偏移的 y 必须落在「钳进视口」的余量内，否则量到的是钳制后的位置、不是偏移本身：
	#    背包 556 高、视口 560 ⇒ 纵向余量只有 ±2（`功能窗口.gd:962-970`）。2026-10-31
	#    背包从 470 长到 556（10 行一屏全露），旧值 40 会被钳成 2，B1 就会红成"偏移不生效"。
	#    钳制本身归丁组（不出屏）钉，这里只要一条**不被钳**的纯偏移。
	var 偏移 := Vector2(120.0, 2.0)
	_窗("背包").call("窗口偏移", 偏移)
	await _等帧(2)
	var 挪过 := _矩形("背包")
	# ⚠️ `居中`（刚打开时的矩形）**不是**居中位 —— 新窗会按已开数量错开一个量
	#    （背包是第二个，错开 (120,78)）。真居中位要从视口与窗口尺寸现算。
	var 真居中 := (_视口() - 居中.size) * 0.5
	_检(挪过.position.distance_to(真居中 + 偏移) <= 容差,
		"B1 `窗口偏移(%s)` 应把窗口摆到「真居中 %s + 该偏移」，实际落在 %s ｜ %s" % [
			偏移, 真居中, 挪过.position, _窗况("背包")])

	# 关 → 开：应回到**上次关掉时**的位置
	await _点底栏("背包")
	await _点底栏("背包")
	var 重开 := _矩形("背包")
	_检(重开.position.distance_to(挪过.position) <= 容差,
		"B2 关了再开应回到上次位置 %s，实际回到 %s（差 %s）" % [挪过.position, 重开.position, 重开.position - 挪过.position])

	# 连做三次，不许越用越偏
	var 漂移: Array[String] = []
	for _次数 in 3:
		await _点底栏("背包")
		await _点底栏("背包")
		var 本次 := _矩形("背包")
		漂移.append("%s" % (本次.position - 挪过.position))
	_检(漂移.all(func(项: String) -> bool: return 项 == 漂移[0]),
		"B3 关了再开连做三次位置该恒定，实际漂移序列 %s" % [漂移])

	# 没拖过的页：开→关→开 应回到它自己的居中位
	_管理.call("全部关闭")
	await _等帧(2)
	await _点底栏("忍术")
	var 忍术首次 := _矩形("忍术")
	await _点底栏("忍术")
	await _点底栏("忍术")
	_检(_矩形("忍术").position.distance_to(忍术首次.position) <= 容差,
		"B4 没拖过的页关了再开应回原处：%s → %s" % [忍术首次.position, _矩形("忍术").position])


# ── 丙：层级 ──────────────────────────────────────────────────────────

func _丙_层级() -> void:
	await _清场()

	_管理.call("打开", "人物")
	await _等帧(2)
	_管理.call("打开", "背包")
	await _等帧(3)

	_检(_最上层页名() == "背包", "C1 后打开的在最上：末位应是背包，实为「%s」" % _最上层页名())

	# 让两窗错开，好找一个"只属于某一方"的点
	_窗("人物").call("窗口偏移", Vector2(-120.0, -60.0))
	_窗("背包").call("窗口偏移", Vector2(120.0, 60.0))
	await _等帧(3)

	# ⚠ `_点合成` 内部自己 `await _等帧(2)`（按下→松开各等一帧）⇒ 调用处**必须 await**，
	#   否则外面那条 `_等帧` 跟它并行推进，命中判定会读到"点击还没落地"的那一帧（假绿来源之一）。
	await _点合成(_矩形("背包").position + _矩形("背包").size * 0.5)
	await _等帧(2)
	_检(_最上层页名() == "背包", "C2 点被盖住那扇不该改变层级（重叠区归最上面的背包）")

	if not _合成可用:
		_跳过.append("C3-C7 命中类（无头合成鼠标无效）")
		return

	# C3：人物露出来的那块，命中应属于人物
	var 人物点 := _只属于("人物", "背包")
	if 人物点 == Vector2.INF:
		_失败.append("C3 两窗错开后应有一块只属于人物，没找到（偏移没生效？）")
	else:
		_发移动(人物点)
		await _等帧(2)
		_检(_命中属于("人物"), "C3 人物露出来的那块应命中人物，实为 %s" % _命中页名())
		# C4：点它 → 置顶 + 那一点的控件照常响应
		await _点合成(人物点)
		await _等帧(3)
		_检(_最上层页名() == "人物", "C4 点人物露出来的那块应把它提到最上，实为「%s」" % _最上层页名())
		# C5：再点重叠区 → 应归人物（现在人物在上面）
		var 重叠点 := _重叠点("人物", "背包")
		if 重叠点 != Vector2.INF:
			_发移动(重叠点)
			await _等帧(2)
			_检(_命中属于("人物"), "C5 人物提到最上后，重叠区该命中人物，实为 %s" % _命中页名())


# ── 丁：不出屏 ────────────────────────────────────────────────────────

func _丁_不出屏() -> void:
	await _清场()
	var 视口 := _视口()
	var 撑破: Array[String] = []
	var 出屏: Array[String] = []
	for 页 in _页名们():
		var 名 := String(页)
		_管理.call("打开", 名)
		await _等帧(2)
		var 矩形 := _矩形(名)
		if 矩形.size == Vector2.ZERO:
			撑破.append("%s(取不到矩形)" % 名)
			continue
		if 矩形.size.x > 视口.x or 矩形.size.y > 视口.y:
			撑破.append("%s(%.0fx%.0f)" % [名, 矩形.size.x, 矩形.size.y])
			continue
		var 出 := Rect2(Vector2.ZERO, 视口).grow(容差)
		if not 出.encloses(矩形):
			出屏.append("%s 矩形%s 视口%s" % [名, 矩形, 视口])
	_检(出屏.is_empty(), "D1 装得下的页应完整在屏内，出屏的有：%s" % [出屏])
	if not 撑破.is_empty():
		print("窗口行为契约体检：比视口大的页（结构上装不下，不判死）：%s" % [撑破])


# ── 戊：全页走查 ──────────────────────────────────────────────────────

## 读夹具 json（原文由 `开发工具/出*夹具.py` 从服务端拼接式逐 token 反查生成）。
## 查不到就**直接红**：夹具没了还照旧开窗 = 这一页等于没量。
func _夹具(路: String) -> Dictionary:
	var 文 := FileAccess.open(路, FileAccess.READ)
	if 文 == null:
		_失败.append("戊 缺夹具：%s（跑一遍对应的 开发工具/出*夹具.py 再体检）" % 路)
		return {}
	var 解: Variant = JSON.parse_string(文.get_as_text())
	文.close()
	if typeof(解) != TYPE_DICTIONARY:
		_失败.append("戊 夹具不是字典：%s" % 路)
		return {}
	return 解 as Dictionary


## 这几页**不是按名字开出来的窗**，是服务端推帧推出来的：`TradeWindow2` 只在 `335:22` 之后
## 被 set、`StallWindow` 只在 `1296:1`、`YaoqingShuangxiuWindow` 只在 `1288:2`、
## 购买确认只在点「购买」那一刻由 `摊位窗.待买` 决定、神秘商店货架只在 `324:` 之后进
## `authoritative_mystery_shop`（`功能窗口` 那五支 `_render_*` 都有守卫）。
## 按名字空开必然拿到空页 ⇒ 先喂各自的真帧原文，再走同一条 打开()。
## E1 判的还是「数据到了画不画得出」，没有被削弱；页真坏了照样红。
## 返回 true = 这一页是数据门控的（走完要 `_撤数据`）。
func _喂数据(名: String) -> bool:
	var 后: Node = root.get_node_or_null("BackendConnection")
	if 后 == null:
		_失败.append("戊 取不到 BackendConnection ⇒ 数据门控的那几页没法喂")
		return false
	match 名:
		"交易":
			var 原: Dictionary = _夹具(交易夹具路径).get("原文", {}) as Dictionary
			后.call("_handle_bridge_text", String(原.get("开始", "")))
			if not bool(后.get("authoritative_trade").get("active", false)):
				_失败.append("戊 交易夹具的「开始」那条 335:22 没把交易态置起来 ⇒ 这页量不到东西"
						+ "（先跑 开发工具/出交易夹具.py）")
				return false
			return true
		"随身摊位":
			后.call("_handle_bridge_text", String(_夹具(摆摊夹具路径).get("原文", "")))
			return true
		"摊位购买":
			后.call("_handle_bridge_text", String(_夹具(摆摊夹具路径).get("原文", "")))
			var 行们: Array = (后.get("authoritative_stall") as Dictionary).get("listings", []) as Array
			if 行们.is_empty():
				_失败.append("戊 摊位夹具解不出挂牌行 ⇒ 「摊位购买」这一页没喂上数据")
				return true
			## 与 `摊位窗._点购买:196-200` 同一份形状（页签在第三档才算现金页）
			摊位窗脚本.待买 = {"行": 行们[0], "货币页": false,
					"摊主号": int((后.get("authoritative_stall") as Dictionary).get("owner_id", 0)),
					"摊主名": String((后.get("authoritative_stall") as Dictionary).get("owner_name", ""))}
			return true
		"摊位上架":
			## `功能窗口._render_stall_up:6851-6853` 在脚本级 `上架单` 为空时**直接 return**
			## （原版这扇只由「物品上架」模式下点背包格开起来 ⇒ `showUpShelfWindow` 是把那一件
			## 存进实例字段 `_itemData` 再建页）⇒ 按名字空开必然一页空白，E1「防空渲染」照样红。
			## 喂一件**真形状**的样品（同 `随身摊位摊主回归测试.上架样品()`），让这页走它平时的腿。
			摊位窗脚本.上架单 = {"物品": {"id": "10000001", "name": "熊皮", "type": 2,
					"quantity": 5, "can_trade": true}, "格": 7}
			return true
		"双修邀请":
			(后.get("map_players") as Dictionary)[邀请者号] = 邀请者态
			后.call("_handle_bridge_text", "1288:2:%d:%s" % [邀请者号, String(邀请者态["name"])])
			return true
		"竞技场":
			## `PvpWindow.initView:280-285` = 开窗即发上行 0 **且** `_panel.visible=false`，等 `2306:0`
			## 回来才显形 ⇒ 按名字空开必然一页空白（10-24 这道门与 `窗口布局体检` 同时红在这条）。
			## 喂 `数据/界面/竞技场夹具.json` 里那发**真服务端原文**（`NARUTO_PACKET_TRACE=1` 从夹具
			## 那台服务端日志逐字抄的，出处见 `真值/窗口/竞技场.md` §⑮），页就走它平时的腿显形。
			var 竞技后: Node = root.get_node_or_null("BackendConnection")
			## ★ 顺序：**先把窗开出来再灌帧**。`打开` 才 `instantiate` 页面，灌到还没建的页上 = 静默无效
			##   （`家族邀请` 那支早就踩过这条，注释还留着）；而 `渲染` 里那句 `页.visible=false` 是
			##   在开窗那一刻设的，灌帧在它之后才可能把它翻回来。
			_管理.call("取或建窗口", "竞技场")
			竞技场窗脚本.挂全局(竞技后)		# 运行期这一句归 `窗口管理._ready`；离线跑没人接 ⇒ 自己接上
			竞技后.call("_handle_bridge_text",
					String((_夹具(竞技场夹具路径).get("原文", {}) as Dictionary).get("面板", "")))
			if (竞技场窗脚本.候选 as Array).is_empty():
				_失败.append("戊 竞技场面板帧没解出候选 ⇒ 夹具串与服务端口径脱节了")
				return false
			return true
		"神秘商店":
			## `324:` 那一帧到本端才建页（`_render_mystery_shop` 空态 return）⇒ 按名字空开必然空白。
			## 线序照 `fake_flash_server.py:_send_mystery_shop`：`324 : 剩余秒 : itemid&count&yb&
			## moneyType&meso&hasBought（条间 @）: 折扣`。
			后.call("_handle_bridge_text", "324:21597:10000001&5&100&0&200000&0:100")
			if (后.get("authoritative_mystery_shop") as Dictionary).is_empty():
				_失败.append("戊 324 没解出货架 ⇒ 「神秘商店」这一页没喂上数据")
				return false
			return true
		"家族邀请":
			## 这一页要**两件事都发生**才有内容：服务端推 `1552:16:` 那一帧 + 点了头顶那一格
			## （`窗口管理._on_托盘已点` 里那句 `家窗.set("_家族邀请", 数据)`）。体检是直接开页 ⇒
			## 自己补第二步，原文段序照 `fake_flash_server._send_family_invitation:22310-22313`。
			## ⚠️ 窗实例此刻还没建（`打开` 才建）⇒ 先 `取或建窗口` 再灌，否则灌到 null 上，
			## 打开时渲染照样是空页（这条以前在分支上是**静默无效**的）。
			后.call("_handle_bridge_text", 族邀原文)
			var 族窗: Node = _管理.call("取或建窗口", "家族邀请")
			if 族窗 != null:
				族窗.set("_家族邀请", 族邀数据)
			return true
		"羁绊申请":
			## 求婚窗的数据来源**不是**点那一格：`61:14` 那一帧到 ⇒ 后端解出来 ⇒ `窗口管理._on_羁绊预览帧`
			## **直接开窗**（与族邀那一支相反）。体检这里两个动作都做一遍：喂原文（证解得开）
			## + 灌宿主缓存（证页填得出），少一个就会有"页开着但四行全空"这种假过。
			后.call("_handle_bridge_text", 求婚原文)
			var 婚窗: Node = _管理.call("取或建窗口", "羁绊申请")
			if 婚窗 != null:
				婚窗.set("_求婚", 求婚数据)
			return true
		"赠花":
			## 照客户端的真序来：点头像菜单那一行 ⇒ `记赠花对面` 存下四项 ⇒ 发 `94:6` ⇒ 回帧 `58:2`
			## ⇒ `窗口管理._on_花档帧` 把页顶出来。体检里没有 TCP ⇒ `94:6` 发不出去，那就自己喂那条
			## 回帧原文，但**仍然走 `_on_花档帧` 这一条腿**（不绕过它：绕过了「点击到开窗」这条链
			## 在体检里就没人验了，跟「羁绊申请」那一支同一个口径）。
			_管理.call("记赠花对面", 赠花对面)
			后.call("_handle_bridge_text", 赠花原文)
			var 档: Dictionary = 后.get("authoritative_flower")
			var 记录数 := (档.get("flowerDayLogInfo") as Array).size()
			var 档数 := (档.get("flowerInfo") as Array).size()
			## ⚠ 这里不能判 `is_empty()`：`authoritative_flower` 一出生就带着八个键（cid 全是 0），
			## 空字典那条判据**永远为假** ⇒ 解帧整条断了也不会红。判的是"我喂的那一份进来了没有"。
			if int(档.get("cid", 0)) != 赠花号 or 记录数 != 2 or 档数 != 3:
				_失败.append("戊 58:2 没把花档解全（要 cid=%d、2 条记录、3 档花），实得 cid=%s、记录=%d、档=%d"
						% [赠花号, str(档.get("cid", 0)), 记录数, 档数])
				return false
			## 对面那四项是**开窗那一刻从窗口管理身上取的** ⇒ 取出来对一遍，取空了左栏就是一片白。
			if (_管理.call("取赠花对面") as Dictionary).get("name", "") != String(赠花对面["name"]):
				_失败.append("戊 `记赠花对面` 没存住 ⇒ 赠花窗的档案文字与立绘会画成空名字")
				return false
			return true
	return false


func _撤数据(名: String) -> void:
	var 后: Node = root.get_node_or_null("BackendConnection")
	if 后 == null:
		return
	match 名:
		"交易":
			后.set("authoritative_trade", 后端连接脚本._空交易状态())
		"随身摊位", "摊位购买":
			后.set("authoritative_stall", {})
			if 名 == "摊位购买":
				摊位窗脚本.待买 = {}
		"摊位上架":
			## 与「摊位购买」清 `待买` 同一理由：脚本级槽是**跨窗共享**的，留着会串到
			## 后面那一页（也留着会被 `_点上架价` 拿旧件发一帧垃圾）。
			摊位窗脚本.上架单 = {}
		"竞技场":
			## `PvpManager` 是常驻单例 ⇒ 这份状态跨窗共享：不清的话下一页/下一条门一开竞技场
			## 就直接是"有数据的"，那等于把「开窗即拉」这条路偷偷跳过了（同一族坑见 #312/#330）。
			竞技场窗脚本.新会话()
		"双修邀请":
			(后.get("map_players") as Dictionary).erase(邀请者号)
			后.set("authoritative_heal", {"state": 0, "character_id": 0, "partner_id": 0,
					"xinfa_id": 0, "pending_inviter_id": 0})
			## 宿主自己记着「这一号的邀请」（`_双修邀请号`，回帧之后 pending 就没了），
			## 不清掉的话下一页会拿旧号去查同屏表。⚠ 只清那个号、**不调 `关掉双修邀请()`** ——
			## 它会顺手 `close()`，而 E2 要的是「走完一遍之后每一扇都还开着」。
			var 双 := _窗("双修邀请")
			if 双 != null:
				双.set("_双修邀请号", 0)
		"神秘商店":
			后.set("authoritative_mystery_shop", {})
			## 秒表与那本 `{剩,文,跑完}` 挂在**宿主**上、跨页重建活着（§3.222）⇒ 光清后端字典不够，
			## 不清的话后面那几页走查期间它还每秒回写一次文案。`复位` 只做"清状态 + stop"，
			## **不关窗**（E2 要每一扇都还开着），也不 `queue_free` 表节点。
			var 秘 := _窗("神秘商店")
			if 秘 != null:
				神秘商店窗脚本.复位(秘)
		"家族邀请":
			## 页数据是**灌在宿主身上**的（`_家族邀请`），后端那一帧解完就没了 ⇒ 必须清宿主这一份，
			## 否则下一页/下一道门继承一个"上一任族长还等着同意"的状态；托盘那一格同理。
			var 族窗 := _窗("家族邀请")
			if 族窗 != null:
				族窗.set("_家族邀请", {})
			var 族盘 = _管理.get_node_or_null("邀请托盘")
			if 族盘 != null:
				族盘.call("清空")
		"羁绊申请":
			## 同上：页数据灌在宿主身上（`_求婚`），而且被求档那一格会留在托盘里 ⇒ 两份都要清。
			var 婚窗 := _窗("羁绊申请")
			if 婚窗 != null:
				婚窗.set("_求婚", {})
			var 婚盘 = _管理.get_node_or_null("邀请托盘")
			if 婚盘 != null:
				婚盘.call("清空")
		"赠花":
			## 三处都得清，少一处就串页：
			## · 后端那份 `authoritative_flower` 不清 ⇒ 后面任何一扇读它的页继承"上一任对面"的友好度；
			## · 宿主 `_赠花` 不清 ⇒ 下一道门按名字空开赠花页会**画出上一任的整页**，E1 就量不到"没数据时应空"；
			## · `窗口管理._赠花对面` 不清 ⇒ 下一帧 `58:2` 会拿上一任的名字/脸把左栏填上（真机上是换个人点的）。
			后.set("authoritative_flower", {"cid": 0, "face": 0, "youhaodu": 0, "totalFlowers": 0,
					"weeklyFlowers": 0, "count": 0, "flowerDayLogInfo": [], "flowerInfo": []})
			var 花窗 := _窗("赠花")
			if 花窗 != null:
				花窗.set("_赠花", {})
			_管理.call("记赠花对面", {})


func _戊_全页走查() -> void:
	await _清场()
	var 页名们 := _页名们()
	var 标题不对: Array[String] = []
	var 空页: Array[String] = []
	var 页错: Array[String] = []
	var 关钮不对: Array[String] = []
	var 表 := 功能窗口脚本._取窗口尺寸表()

	for 页 in 页名们:
		var 名 := String(页)
		var 门控 := _喂数据(名)
		_管理.call("打开", 名)
		await _等帧(2)
		if not _已开(名):
			页错.append("%s(没开)" % 名)
			continue
		if _当前页(名) != 名:
			页错.append("%s(停在%s)" % [名, _当前页(名)])
		## ★ 有一族页**只有"开完窗再到的帧"才显形**：`PvpWindow.initView:280-285` 是开窗即发上行 0
		##   且 `_panel.visible = false`，`handlePanelInfo → updateView:85` 才把它翻回来；
		##   而本门这段在 `打开` 里又跑了一次 `渲染`（`:97` 那句 `页.visible = false`）⇒
		##   「开窗前灌的那一帧」被随后这次渲染重新藏掉 ⇒ 这里开窗后**照同一条腿再喂一次**。
		if 名 in 开窗后补喂:
			_喂数据(名)
			await _等帧(2)
		var 规格: Dictionary = 表.get(名, {})
		# 多数页的标题是尺寸表里那个静态名；少数页会**动态追加**计数后缀
		# （背包「背包(6/96)」、NPC仓库「仓库(0/30)」），那是正常行为 —— 只要求前缀对得上。
		var 期望 := String(规格.get("标题", 名))
		if not _标题(名).begins_with(期望):
			标题不对.append("%s 期望以「%s」开头，实为「%s」" % [名, 期望, _标题(名)])
		if not _有可见内容(名) and not _允许空页(名):
			空页.append(名)
		## 喂过的那份数据当场撤掉：下一页可能是另一扇靠同一份状态的窗（`authoritative_stall`
		## 既喂「随身摊位」也喂「摊位购买」），留着就会串页。窗口本身不用关 —— 后面的
		## 关闭钮/标题断言量的还是这一页。
		if 门控:
			_撤数据(名)
		# E3 关闭钮的外壳不变量（每一扇窗都该一样，`MWindow.drawWindowLayout():215-216`）：
		#   `x = round(bgW − 钮宽 − 6)`、`y = _titleTextFieldY + 1`，而标题基准
		#   普通背景 = 5、`_isSmallBackground` = 3（`:167-174`）⇒ 顶距 6 / 4。
		#   元件 7 `MWindowCloseBtnF` 边界现查 (0,0)-(25,24) ⇒ 符号无透明留白，6 就是墨迹边距。
		#   旧实现写的是 13（补了一份根本不存在的留白）⇒ 全工程每扇窗的 X 左偏 7 像素，
		#   2026-10-14 用户实机图打回；这条判据就是钉住它别再漂。
		var 窗: Node = _窗(名)
		var 钮 := 窗.get_node_or_null("遮罩/主窗口/关闭按钮") as Control
		var 框 := 窗.get_node_or_null("遮罩/主窗口") as Control
		if 钮 == null or 框 == null:
			关钮不对.append("%s(取不到关闭钮或主窗口)" % 名)
		else:
			var 距右 := 框.size.x - (钮.position.x + 钮.size.x)
			var 期望顶 := 4.0 if bool(规格.get("小背景", false)) else 6.0
			if absf(距右 - 6.0) > 0.6 or absf(钮.position.y - 期望顶) > 0.6:
				关钮不对.append("%s 距右 %.1f(应 6) 顶 %.1f(应 %.0f)"
						% [名, 距右, 钮.position.y, 期望顶])

	_检(页错.is_empty(), "E1 逐页打开应停在自己的页，异常：%s" % [页错])
	_检(标题不对.is_empty(), "E1 标题应取尺寸表的「标题」，异常：%s" % [标题不对])
	_检(空页.is_empty(), "E1 页面容器下应有可见控件（防空渲染），空的有：%s" % [空页])
	_检(关钮不对.is_empty(),
			"E3 每一扇窗的关闭钮都该距窗右 6、顶 = 标题基准 + 1（MWindow.as:215-216），异常：%s"
					% [关钮不对])

	var 同时 := 0
	for 页 in 页名们:
		if _已开(String(页)):
			同时 += 1
	_检(同时 == 页名们.size(), "E2 一次开满应 %d 扇同时开着，实际 %d" % [页名们.size(), 同时])

	# 开满后再点第一页：早就在 `_窗口们` 里，也不该跳过置顶
	var 首 := String(页名们[0])
	_管理.call("打开", 首)
	await _等帧(2)
	_检(_最上层页名() == 首, "E4 已开过的页再点也该置顶：末位应是「%s」，实为「%s」" % [首, _最上层页名()])

	_管理.call("全部关闭")
	await _等帧(2)
	_管理.call("打开", 首)
	await _等帧(2)
	_检(_已开(首), "E3 全部关闭后应还能再开")


# ── 己：被盖住的窗 ────────────────────────────────────────────────────

## ── 庚：意志学习 + 意志背包 成对摆位（2026-10-23 §3.189）──
## 用户实机报：点意志学习，学习窗该在意志背包**左边紧挨**、平行（同 y）、整体居中。
## 真值 = 原版 `MWindow.setLocationCenter` + `subWindow` 公式（`MWindow.as:355-363`）：
##   主窗 x = (舞台宽 − 主宽 − 子宽)/2、子窗 x = 主窗 x + 主窗宽 + 1、子窗 y = 主窗 y。
## 工程 `窗口管理.成对摆位("意志学习", "遗址")` 已按此实现；本段钉三窗互开后的摆位。
func _庚_意志成对() -> void:
	await _清场()
	# 先开背包（遗址），再开学习 ⇒ 学习窗（主）在左、遗址（伴）在右
	await _点底栏("遗址")
	await _点底栏("意志学习")
	var 学 := _矩形("意志学习")
	var 背 := _矩形("遗址")
	_检(学.size != Vector2.ZERO and 背.size != Vector2.ZERO,
			"G0 两窗都开着（学习 %s / 遗址 %s）" % [学, 背])
	if 学.size == Vector2.ZERO or 背.size == Vector2.ZERO:
		return
	var 视口 := _视口()
	var 望学x := floorf(maxf(0.0, (视口.x - (学.size.x + 背.size.x + 1.0)) * 0.5))
	_检(absf(学.position.x - 望学x) <= 容差,
			"G1 学习窗该在两窗整体居中的左位（期望 x=%f，实际 %s）" % [望学x, str(学.position)])
	_检(absf(背.position.x - (望学x + 学.size.x + 1.0)) <= 容差,
			"G2 意志背包该紧挨学习窗右侧（期望 x=%f，实际 %s）" % [望学x + 学.size.x + 1.0, str(背.position)])
	_检(absf(背.position.y - 学.position.y) <= 容差,
			"G3 两窗该同 y 顶对齐（学习 %s / 遗址 %s）" % [str(学.position), str(背.position)])
	# 反向：关掉学习窗再单开遗址 ⇒ 仍应重摆成对（搭档已开）
	await _点底栏("意志学习")
	await _点底栏("遗址")
	学 = _矩形("意志学习")
	背 = _矩形("遗址")
	_检(absf(学.position.x - 望学x) <= 容差 and absf(背.position.x - (望学x + 学.size.x + 1.0)) <= 容差,
			"G4 反向（先背后学）重开后仍成对：学习 %s / 遗址 %s" % [str(学.position), str(背.position)])
	# 搭档没开时：学习窗单开（不强制开背包——原版开学习窗不连带开背包），
	# 位置按窗口管理的「新窗错开」设计走（防多窗叠死），只钉它在视口内可见。
	await _清场()
	await _点底栏("意志学习")
	var 单 := _矩形("意志学习")
	# 学习窗 564 高 > 视口 560 ⇒ 垂直居中必然 y=−2（窗比视口高 4px，结构性出界，
	# 与「比视口大的页不判死」同源），x/y 判据都按此放宽。
	_检(单.size != Vector2.ZERO and 单.position.x >= -1.0
			and 单.position.y >= -(单.size.y - 视口.y) - 1.0
			and 单.position.x + 单.size.x <= 视口.x + 1.0,
			"G5 搭档没开时学习窗单开（按错开设计摆在视口内），实际 %s" % str(单.position))


func _己_被盖住的窗() -> void:
	await _清场()
	_管理.call("打开", "人物")
	_管理.call("打开", "背包")
	# ⚠ 这一句**必须 await**：不 await 时它只是"挂起在协程里等两帧"，而下面的 `窗口偏移`
	#   立刻就把两扇挪走了 ⇒ "先让两窗落好位再挪"这个前置根本没生效（#77 沉底那条将来要吃这种假绿）。
	await _等帧(2)
	_窗("人物").call("窗口偏移", Vector2(-120.0, -60.0))
	_窗("背包").call("窗口偏移", Vector2(120.0, 60.0))
	await _等帧(3)

	if not _合成可用:
		_跳过.append("F1-F4（无头合成鼠标无效）")
		return

	var 只属于人物 := _只属于("人物", "背包")
	if 只属于人物 == Vector2.INF:
		_失败.append("F1 两窗错开后应有一块只属于人物，没找到")
	else:
		_发移动(只属于人物)
		await _等帧(2)
		_检(_命中属于("人物"), "F1 人物露出来的那块该能点到，实为 %s" % _命中页名())

	var 重叠 := _重叠点("人物", "背包")
	if 重叠 != Vector2.INF:
		_发移动(重叠)
		await _等帧(2)
		_检(_命中属于("背包"), "F2 重叠区该归最上面的背包，实为 %s" % _命中页名())

		# F3：把压在上面的背包关掉，那一点该让给人物
		await _点底栏("背包")
		_检(not _已开("背包"), "F3 前置：背包应已关掉")
		_发移动(重叠)
		await _等帧(2)
		_检(_命中属于("人物"), "F3 关掉压在上面的窗后，那一点该让给人物，实为 %s" % _命中页名())

		# F4：对人物露出来的那块真的按下+松开，那一点的控件要响应（不是只 hover）
		var 再找 := _只属于("人物", "背包")
		if 再找 != Vector2.INF:
			_发移动(再找)
			await _等帧(2)
			var 按下命中 := _命中页名()
			_检(按下命中 != "null", "F4 对人物按下时该有控件接住，实为 %s" % 按下命中)


# ── 庚：购买弹窗开着期间，点别的窗不许把它压下去（用户 2026-10-22 报修 10）────────
#
# 真值 `CashShopWindow2.as:450`：`PopUpMananger.centerWindow(buyEqpWindow, **true**)`
# ⇒ 弹窗连同那片 `beginFill(0, 0.3)` 的**整舞台遮罩**都挂在 **stage 自己那一层**，
#   底下任何一扇窗被点起来都压不到它。
# 这边弹窗住在**宿主的 CanvasLayer** 里（layer 由 `窗口管理.重排层级` 按 `_顺序` 发），
# 而 `_input` 的「点任何窗都置顶」提的是**整扇宿主窗**的 layer ⇒
# 只要那一句在弹窗开着期间还敢提别的窗，弹窗就跟着宿主一起沉到那扇窗下面 = 报修 10。
# 修法让遮罩长成 `模态弹罩住` 认得的那个形状（`z_index >= 100` + STOP）⇒ 期间一票都不提。
#
# ⚠ 庚3/庚4 打在 `模态弹罩住` 的直接调用上：**不依赖合成鼠标**，无头里合成事件失效时照样判得动；
#   庚5~庚7 才走真的 `_input` 那条链（`_合成可用` 为假时只跳这三条，不跳整组）。
func _庚_购买弹窗模态() -> void:
	await _清场()
	_管理.call("打开", "背包")
	_管理.call("打开", "商城")
	await _等帧(3)
	# 弹窗要开在**最上面那扇**上 —— 报修的形状是"弹窗那扇本来在最上，点一下别处就沉下去"。
	_窗("商城").call("窗口偏移", Vector2(120.0, 60.0))
	_窗("背包").call("窗口偏移", Vector2(-120.0, -60.0))
	await _等帧(3)
	if _最上层页名() != "商城":
		_失败.append("庚0 前置：后开的商城该在最上，实为「%s」（%s / %s）"
				% [_最上层页名(), _窗况("商城"), _窗况("背包")])
		return
	var 场 := _窗("商城")
	var 遮罩层 := 场.get("_overlay") as Control
	场.call("打开商城购买窗", {"id": "16000056", "sn": 4242, "name": "本门用的假商品", "price": 1})
	await _等帧(2)
	var 弹 := 遮罩层.get_node_or_null("商城购买窗") as Control
	if 弹 == null:
		_失败.append("庚1 前置：`打开商城购买窗` 没在宿主遮罩上弹出购买窗")
		return
	var 点 := _只属于("背包", "商城")
	if 点 == Vector2.INF:
		_失败.append("庚2 前置：两窗错开后应有一块只属于背包，没找到（偏移没生效？）")
		return
	# 庚3 = 报修 10 的成因本身：这层模态罩**认不出来**的话，`_input` 就还敢提隔壁那扇。
	_检(bool(场.call("模态弹罩住", 点)),
			"庚3 购买窗开着、遮罩却没被 `模态弹罩住` 认成模态 ⇒ 点隔壁窗会把它连宿主一起压下去（报修 10）")
	# 庚4 罩子挂错了人家 ⇒ 也会红（隔壁那扇不该报"我有模态弹"）。
	_检(not bool(_窗("背包").call("模态弹罩住", 点)), "庚4 隔壁背包自己不该报有模态罩")
	if not _合成可用:
		_跳过.append("庚5-庚7（无头合成鼠标无效）")
		return
	await _点合成(点)
	await _等帧(3)
	_检(_最上层页名() == "商城",
			"庚5 弹窗开着时点背包那块，商城那扇不该被翻上来（翻了弹窗就沉底），实为「%s」" % _最上层页名())
	弹.call("隐藏")
	await _等帧(2)
	_检(not bool(场.call("模态弹罩住", 点)), "庚6 关掉弹窗后那层遮罩还在罩着整屏（模态没撤）")
	await _点合成(点)
	await _等帧(3)
	_检(_最上层页名() == "背包",
			"庚7 撤掉模态之后点背包那块该置顶（「点谁谁在前」这条不能跟着一起废），实为「%s」" % _最上层页名())


# ── 断言 / 报告 ───────────────────────────────────────────────────────

func _收尾() -> void:
	if _场景 != null and is_instance_valid(_场景):
		_场景.queue_free()
		_场景 = null
	await _等帧(2)
	if _失败.is_empty() and _跳过.is_empty():
		print("窗口行为契约体检：通过")
		quit(0)
		return
	for 项 in _失败:
		push_error("窗口行为契约体检：失败 - %s" % 项)
	if not _跳过.is_empty():
		print("窗口行为契约体检：⚠️ 有断言被跳过（不算通过）：%s" % [_跳过])
	quit(1)


func _检(条件: bool, 说明: String) -> void:
	if not 条件:
		_失败.append(说明)


# ── 驱动 ──────────────────────────────────────────────────────────────

## 走底栏那条真信号链：按钮 `pressed` → `技能面板` → `游戏会话.request_feature`。
func _点底栏(页名: String) -> void:
	_会话.call("request_feature", 页名)
	await _等帧(3)


func _等帧(帧数: int) -> void:
	for _序号 in maxi(1, 帧数):
		await process_frame


## 合成鼠标一律走 `Viewport.push_input`，**不用 `Input.parse_input_event`**
## —— 后者不改 `Input` 内部按键状态，视口的拖放/命中判定拿到的 `button_mask` 是空的
## （项目 2026-09-22 实测）。
func _发移动(位置: Vector2) -> void:
	var 事件 := InputEventMouseMotion.new()
	事件.position = 位置
	事件.global_position = 位置
	事件.relative = Vector2(4, 0)
	事件.button_mask = 0
	root.push_input(事件)


func _点合成(位置: Vector2) -> void:
	_发移动(位置)
	var 按下 := InputEventMouseButton.new()
	按下.button_index = MOUSE_BUTTON_LEFT
	按下.pressed = true
	按下.button_mask = MOUSE_BUTTON_MASK_LEFT
	按下.position = 位置
	按下.global_position = 位置
	root.push_input(按下)
	await _等帧(2)
	var 松开 := InputEventMouseButton.new()
	松开.button_index = MOUSE_BUTTON_LEFT
	松开.pressed = false
	松开.button_mask = 0
	松开.position = 位置
	松开.global_position = 位置
	root.push_input(松开)
	await _等帧(3)


# ── 探针 ──────────────────────────────────────────────────────────────

func _窗(页名: String) -> Node:
	return _管理.call("取窗口", 页名)


func _已开(页名: String) -> bool:
	var 窗 := _窗(页名)
	return 窗 != null and bool(窗.call("已打开"))


func _当前页(页名: String) -> String:
	var 窗 := _窗(页名)
	return "" if 窗 == null else String(窗.get("_current_page"))


func _标题(页名: String) -> String:
	var 窗 := _窗(页名)
	if 窗 == null:
		return ""
	var 标 := 窗.get_node_or_null("遮罩/主窗口/标题") as Label
	return "" if 标 == null else 标.text


func _矩形(页名: String) -> Rect2:
	var 窗 := _窗(页名)
	if 窗 == null:
		return Rect2()
	var 主窗 := 窗.get_node_or_null("遮罩/主窗口") as Control
	return 主窗.get_global_rect() if 主窗 != null else Rect2()


func _视口() -> Vector2:
	return root.get_visible_rect().size


## 当前**最上层**的页名 —— 按 `layer` 取，因为同层 CanvasLayer 之间
## 真正决定画序/命中的是 `layer`，不是树序（`move_child` 改不动它，见 `窗口管理.重排层级`）。
func _最上层页名() -> String:
	var 最后 := ""
	var 最高 := -9999
	for 页 in _页名们():
		var 窗 := _窗(String(页))
		if 窗 == null or not _已开(String(页)):
			continue
		var 层 := int(窗.layer)
		if 层 > 最高:
			最高 = 层
			最后 = String(页)
	return 最后


## 打给失败信息用：一扇窗当前的偏移 / 尺寸 / 层号 / 矩形。
func _窗况(页名: String) -> String:
	var 窗 := _窗(页名)
	if 窗 == null:
		return "%s=（没建）" % 页名
	var 主窗 := 窗.get_node_or_null("遮罩/主窗口") as Control
	if 主窗 == null:
		return "%s=（没主窗）" % 页名
	var 遮 := 窗.get_node_or_null("遮罩") as Control
	return "%s 层=%d 遮罩=%s 偏移(%.1f,%.1f) 尺寸=%s 矩形=%s" % [
		页名, int(窗.layer), 遮.size if 遮 != null else Vector2.ZERO,
		主窗.offset_left, 主窗.offset_top, 主窗.size, 主窗.get_global_rect()]


func _有可见内容(页名: String) -> bool:
	var 窗 := _窗(页名)
	if 窗 == null:
		return false
	var 容器 := 窗.get_node_or_null("遮罩/主窗口/页面容器")
	if 容器 == null:
		return false
	for 子 in 容器.find_children("*", "Control", true, false):
		var 控件 := 子 as Control
		if 控件 != null and 控件.is_visible_in_tree() and 控件.size.x > 0.0 and 控件.size.y > 0.0:
			return true
	return false


## 当前鼠标命中落在**哪一扇窗**里。打不出页名就说明命中的不是窗口（或什么都没命中）
## —— 只打节点路径的话是 `@CanvasLayer@190/遮罩/主窗口`，根本看不出归属。
func _命中页名() -> String:
	var 命中 := root.gui_get_hovered_control()
	if 命中 == null:
		return "（无命中）"
	for 页 in _页名们():
		var 窗 := _窗(String(页))
		if 窗 != null and (命中 == 窗 or 窗.is_ancestor_of(命中)):
			return String(页)
	return "（非窗口：%s）" % 命中.get_path()


func _命中属于(页名: String) -> bool:
	return _命中页名() == 页名


## 两窗错开后，找一点**只落在甲窗里**（不在乙窗矩形内）。
func _只属于(甲: String, 乙: String) -> Vector2:
	var 甲框 := _矩形(甲)
	var 乙框 := _矩形(乙)
	if 甲框.size == Vector2.ZERO or 乙框.size == Vector2.ZERO:
		return Vector2.INF
	for y in range(int(甲框.position.y) + 4, int(甲框.end.y) - 4, int(重叠试探步)):
		for x in range(int(甲框.position.x) + 4, int(甲框.end.x) - 4, int(重叠试探步)):
			var 点 := Vector2(x, y)
			if not 乙框.has_point(点):
				return 点
	return Vector2.INF


## 两窗重叠区里的一点。
func _重叠点(甲: String, 乙: String) -> Vector2:
	var 交 := _矩形(甲).intersection(_矩形(乙))
	if 交.size.x <= 4.0 or 交.size.y <= 4.0:
		return Vector2.INF
	return 交.position + 交.size * 0.5


func _页名们() -> Array:
	return 功能窗口脚本._取窗口尺寸表().keys()

## 允许**空渲染**的页 —— **逐条带出处**，不是"看着不对就放行"。
##
## 「家族」：未入族时家族主窗按原版**根本不出现**，只开家族列表窗
## （`FamillyManager.showMainWindow()` `FM.as:1222-1239` 是二选一：
##  `myFamillyInfo.id != 0` → 主窗，否则 → 列表窗）。用户 2026-10-06 报的
## "家族页还在"就是那个**空框**，2026-10-14 家族支把它按原版改成"未入族不出现"了。
## 门里没入族 ⇒ 它本来就该是空的。**入族时不许空**，所以只在"未入族"这一支放行。
func _允许空页(名: String) -> bool:
	if 名 != "家族" or _会话 == null:
		return false
	return not bool((_会话.get("guild") as Dictionary).get("joined", false))
