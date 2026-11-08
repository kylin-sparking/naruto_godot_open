extends SceneTree

## 竞技场开窗自检（**有头**，不能加 --headless —— 要拿视口图像）。
##
## 为什么走「真地图场景 + 窗口管理」这一条，而不是自己 new 一扇 `功能窗口`：
## 假宿主会失配 ⇒ 门绿而实机不开（口径见 user 记忆 `feedback-finish-claims`）。
## 这里跟 `截商城窗.gd` 同一套路：`场景/地图/地图场景.tscn` → `窗口管理.取或建窗口` → `open_page`。
##
## 喂进去的那一帧是**服务端原文串**（段序照 `fake_flash_server.py:29270-29275` 的 `2306:0`），
## 走 `_handle_arena_text` 解析 ⇒ 判的是"包形对不对 + 数据落没落进对的控件"，不是"我确实调过填充"。
##
## 用法：Godot --path . --script res://开发工具/验竞技场开窗.gd
##   退出码 0 = 全过；1 = 有红；2 = 前置条件不满足（拿不到窗口管理/建不出窗）

const 出图 := "res://测试/截图/竞技场/开窗.png"
const 出图2 := "res://测试/截图/竞技场/开窗_从小地图点开.png"
const 出图3 := "res://测试/截图/竞技场/开窗_排名奖弹窗.png"
## 职业立绘的**独立参照表**（逐条抄 `PvpWindow.drawFace:174-191`，四张都是 240×334 的整幅皮）。
## 判的是「运行期节点上真正挂上去的那张图」，所以这张表**不许**从 `竞技场窗.gd` 的 const 里读 ——
## 两边一起写错就会互相印证（同一族坑见 user 记忆 gate-must-be-run-not-listed 第卅七种）。
const 立绘真值 := {
	100: "UISwf_PvpHuo_Skin.png",
	200: "UISwf_PvpShui_Skin.png",
	300: "UISwf_PvpLei_Skin.png",
	400: "UISwf_PvpFeng_Skin.png",
}
const 竞技场窗脚本 := preload("res://脚本/界面/窗口/竞技场窗.gd")
## 候选一行 12 段（`_arena_candidate_row:29193`）：角色号 排名 头像 等级 名字 在对战 攻 防 暴击 闪避 攻速 移速
## 头像号用**盘上真有图的**（`数据/角色/动画素材索引.json` 里的 `Char_10000204_info_portrait`）⇒
## 判"头像挂上了"才是判图取到了，不是判一个查无此号的空分支。
const 候选行 := [
	"301&7&10000204&55&甲一&0&900&800&12&9&7&175",
	"302&8&10000205&54&甲二&1&880&810&11&8&7&175",
	"303&6&10000204&56&甲三&0&920&790&13&10&6&175",
	"304&9&10000205&53&甲四&0&870&820&10&7&7&175",
	"305&5&10000204&57&甲五&1&930&780&14&11&6&175"]
## 战报一行 8 段（`_arena_report_row:29225`）：挑战者 胜者号 胜者名 败者号 败者名 时间戳 用时 结果排名
const 战报行 := [
	"301&301&甲一&9001&乙一&1&60&7",
	"9001&9001&乙一&302&甲二&2&120&6"]

var _帧 := 0
var _场景: Node = null
var _管理: Node = null
var _后端: Node = null
var _窗: Node = null
var _页: Control = null
var _判: Array = []
var _阶段 := 0
var _等待 := 0
var _钮位 := Vector2.ZERO
var _小地图条 := -1		# 这一段实际判了几条（中途被运行期报错带走就会少于 13 ⇒ 阶段 4 点名）
var _立绘条 := -1
var _弹条 := -1
var _弹心 := Vector2.ZERO


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://测试/截图/竞技场"))
	var 场 := load("res://场景/地图/地图场景.tscn") as PackedScene
	if 场 == null:
		push_error("拿不到 地图场景.tscn")
		quit(2)
		return
	_场景 = 场.instantiate()
	root.add_child(_场景)


func _process(_秒: float) -> bool:
	_帧 += 1
	if _帧 < 10:
		return false
	match _阶段:
		0:
			_管理 = _场景.get_node_or_null("窗口管理")
			if _管理 == null:
				push_error("地图场景里没有 窗口管理 ⇒ 前置条件不满足")
				quit(2)
				return true
			_后端 = root.get_node_or_null("BackendConnection")
			_判.append(["后端自动加载在（root/BackendConnection）", _后端 != null])
			_窗 = _管理.call("取或建窗口", "竞技场")
			_判.append(["建得出竞技场那扇窗", _窗 != null])
			if _窗 == null:
				_收()
				return true
			_窗.call("open_page", "竞技场")
			_阶段 = 1
			_等待 = 4
		1:
			if _等待 > 0:
				_等待 -= 1
				return false
			_页 = _找页()
			_判.append(["页面建出来了（宿主._content 下）", _页 != null])
			_判.append(["没收到帧之前面板藏着（initView:283）", _页 != null and not _页.visible])
			if _页 == null:
				_收()
				return true
			_喂帧("2306:0:2:15:37:3:8000:12:" + "@".join(候选行) + ":" + "@".join(战报行))
			_阶段 = 2
			_等待 = 3
		2:
			if _等待 > 0:
				_等待 -= 1
				return false
			_判数据()
			_判立绘()
			_判.append(["立绘那一段跑满 7 条（中途被运行期报错带走就会少 = 假绿）", _立绘条 == 7])
			_喂帧("2306:1:9")			# 排名变了 ⇒ 只刷那一格
			_阶段 = 3
			_等待 = 3
		3:
			if _等待 > 0:
				_等待 -= 1
				return false
			_判.append(["收到 2306:1 之后排名跟着变 9", _文("面板/左列/排名行/值") == "9"])
			_抓图(出图)		## 主证据图：这一屏是"喂过数据、面板显形"的那一帧
			_判小地图入口()
			## 真点击那一步：先把窗关掉，点下去之后还能再开出来，才算"入口真的接上了开窗那条腿"。
			_管理.call("全部关闭")
			if _钮位 != Vector2.ZERO:
				点一下(_钮位)
			else:
				push_error("拿不到「竞技场钮」的屏幕位 ⇒ 真点击那一步没法判")
			_阶段 = 4
			_等待 = 4
		4:
			if _等待 > 0:
				_等待 -= 1
				return false
			var 再窗: Node = _管理.call("取或建窗口", "竞技场")
			_判.append(["真点小地图那颗「竞技场钮」⇒ 那扇窗又开出来了", 再窗 != null and bool(再窗.call("已打开"))])
			_判.append(["小地图那一段跑满 13 条（中途被运行期报错带走就会少 = 假绿）", _小地图条 == 13])
			## 点出来那一屏原版也是"面板藏着等回帧"（`initView:283`）⇒ 再喂一帧让它显形，
			## 这张图才是"从小地图那颗钮一路点开的竞技场"。
			_页 = _找页()
			_喂帧("2306:0:2:15:37:3:8000:12:" + "@".join(候选行) + ":" + "@".join(战报行))
			_阶段 = 5
			_等待 = 3
		5:
			if _等待 > 0:
				_等待 -= 1
				return false
			_抓图(出图2)
			## 领完排名奖那一拍服务端回的是 `2306:8:<排名>:<阅历>` ⇒ 让**真帧**去叫那枚弹，
			## 不是我手动调 `弹单钮`（自调 = 只测了函数，没测"这一档有人接"）。
			_喂帧("2306:8:1000:5000")
			_阶段 = 6
			_等待 = 4
		6:
			if _等待 > 0:
				_等待 -= 1
				return false
			_判排名奖弹()
			_判.append(["排名奖弹那一段跑满 13 条（中途被运行期报错带走就会少 = 假绿）", _弹条 == 13])
			_抓图(出图3)
			if _弹心 != Vector2.ZERO:
				点一下(_弹心)
			else:
				push_error("拿不到「确定」的屏幕位 ⇒ 真点击那一步没法判")
			_阶段 = 7
			_等待 = 4
			return false
		7:
			if _等待 > 0:
				_等待 -= 1
				return false
			_判.append(["真点那颗「确定」⇒ 弹收掉（原版 `clickOkBtnHandler:73 destroy()`）", _找家族弹() == null])
			_收()
			return true
	return false


## 小地图那一排里竞技场那两颗入口钮（`SmallMapButtonBox` 数组第 12、15 位）——
## 判的是**地图场景里那颗真节点**的显隐与摆位，不是我再调一遍 `_刷竞技钮` 自证。
func _判小地图入口() -> void:
	var 起 := _判.size()
	var 盘: CanvasLayer = null
	for 候 in get_nodes_in_group("game_hud"):
		if String((候 as Node).name) == "小地图面板":
			盘 = 候 as CanvasLayer
	_判.append(["地图场景里带着小地图面板（game_hud）", 盘 != null])
	if 盘 == null:
		return
	var 排: Control = 盘.get_node_or_null("小地图区域/功能按钮") as Control
	var 竞技场钮: TextureButton = null
	var 奖钮: TextureButton = null
	if 排 != null:
		竞技场钮 = 排.get_node_or_null("竞技场钮") as TextureButton
		奖钮 = 排.get_node_or_null("排名奖钮") as TextureButton
	_判.append(["那一排里有「竞技场钮」「排名奖钮」两颗", 竞技场钮 != null and 奖钮 != null])
	if 竞技场钮 == null or 奖钮 == null:
		return
	## 摆位（`updateLayout:434-450` 是**从右往左**排：`x = 前一个的x − 自己的宽`）⇒
	## 竞技场(42 宽)接在意志背包(−277)之后、排名奖(44 宽)再接在它之后。
	_判.append(["竞技场钮盒 = 42×38（`width=42`、皮天然 42×38）",
			absf(竞技场钮.size.x - 42.0) < 0.6 and absf(竞技场钮.size.y - 38.0) < 0.6])
	_判.append(["排名奖钮点击盒 44 宽、皮按天然 39 画（`width=44` 只撑点击区）",
			absf(奖钮.size.x - 44.0) < 0.6 and absf(奖钮.size.y - 42.0) < 0.6
			and 奖钮.stretch_mode == TextureRect.STRETCH_KEEP and 奖钮.ignore_texture_size])
	_判.append(["两颗的相对次序照原版（排名奖紧贴竞技场左边 44 宽）",
			is_equal_approx(奖钮.position.x, 竞技场钮.position.x - 44.0)])
	_判.append(["手型光标（MButton3.init:135 buttonMode/useHandCursor）",
			竞技场钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND
			and 奖钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND])
	## 等级闸：`showPvpButton:541` 读的是 `stats.level >= PVP_ENTER_LEVEL(30)` ⇒ 29/30 两档各判一次。
	var 会话: Node = root.get_node_or_null("GameSession")
	var 状态: Dictionary = 会话.get("player_stats") if 会话 != null else {}
	状态["level"] = 29
	盘.call("_刷竞技钮")
	_判.append(["等级 29 ⇒「竞技场钮」藏（30 级那道闸）", not 竞技场钮.visible])
	状态["level"] = 30
	盘.call("_刷竞技钮")
	_判.append(["刚满 30 ⇒ 亮", 竞技场钮.visible])
	## 领奖钮：`onPk_updateAwardStat:136-148` 只在 `PkAwardStat.NOT_AWARDED`(1) 时点亮 ⇒ 喂**服务端真帧形状**。
	_喂帧("2306:11:5:2")
	_判.append(["奖状态 2（本期已领）⇒ 领奖钮藏", not 奖钮.visible])
	_喂帧("2306:11:5:1")
	_判.append(["奖状态 1（有奖未领）⇒ 领奖钮亮（`showHaiPangPrizeButton(true)`）", 奖钮.visible])
	_喂帧("2306:11:5:0")
	_判.append(["奖状态 0（未上榜）⇒ 又藏回去", not 奖钮.visible])
	## 三档换的是**烘出来的皮**（MButton3 一族：悬停 +30 / 按下 −40），不是 `modulate` 染色。
	## 直接叫面板自己那套换档（`_设三态`）再回读**实际生效的文件名**—— 断言"我确实调过 _设三态"等于没断言。
	var 常态 := String(奖钮.texture_normal.resource_path)
	盘.call("_设三态", 奖钮, 1)
	var 悬 := String(奖钮.texture_normal.resource_path)
	盘.call("_设三态", 奖钮, 2)
	var 按 := String(奖钮.texture_normal.resource_path)
	盘.call("_设三态", 奖钮, 0)
	_判.append(["领奖钮三档各落到自己的烘图、且没染色（常态%s / 悬停%s / 按下%s）" % [
			常态.get_file(), 悬.get_file(), 按.get_file()],
			常态.ends_with("小地图排名奖.png") and 悬.ends_with("小地图排名奖_悬停.png")
			and 按.ends_with("小地图排名奖_按下.png") and 奖钮.modulate == Color(1, 1, 1, 1)])
	## 接线：按下连的必须是面板自己的 `_领排名奖`（这条只管"线接对了"；
	## 「这条上行真发得出去、服务端真回帧」归在线腿第⑨段，两半合起来才是整条链）。
	var 奖接 := 奖钮.pressed.get_connections()
	var 接对 := false
	for 连 in 奖接:
		if String(连["callable"].get_method()) == "_领排名奖" \
				and (连["callable"].get_object() as Object) == 盘:
			接对 = true
	_判.append(["领奖钮按下连的是面板的 _领排名奖（接线表实读，%d 条）" % 奖接.size(), 接对])
	_钮位 = 竞技场钮.global_position + 竞技场钮.size * 0.5
	_小地图条 = _判.size() - 起


## 整幅职业立绘按 `stats.job` 换（`PvpWindow.drawFace:174-193`）—— 10-24 用户实机报的第二条：
## 雷号（job 300）进竞技场看到的还是场景里烘死的那张火。
## 判的是**节点上实际挂起来的图**（`texture.resource_path`），参照表是量具自己按 AS3 抄的 `立绘真值`，
## 不许从 `竞技场窗.gd` 的 const 里读 —— 两边一起写错会互相顶掉（同一族坑见 gate-must-be-run-not-listed 第卅七种）。
func _判立绘() -> void:
	var 起 := _判.size()
	var 方 := _节点("面板/立绘") as TextureRect
	_判.append(["主窗里有「面板/立绘」这块（原版 `_facePanel`）", 方 != null])
	if 方 == null:
		_立绘条 = _判.size() - 起
		return
	var 会话: Node = _窗.get("_session") as Node
	if 会话 == null:
		_立绘条 = _判.size() - 起
		return
	var 状态: Dictionary = 会话.get("player_stats")
	var 原号 = int(状态.get("job", 0))
	for 职 in [100, 200, 300, 400]:
		状态["job"] = 职
		竞技场窗脚本.画立绘(_页, _窗)
		var 名 := (String(方.texture.resource_path).get_file() if 方.texture != null else "〈没挂上图〉")
		_判.append(["职业 %d ⇒ 立绘=%s（屏上实际=%s）" % [职, 立绘真值[职], 名],
				名 == String(立绘真值[职])])
	## 还原成这个号自己的档，再判一次 ⇒ 证明换档不是"只剩最后一次调用"（四档跑完停在风）。
	状态["job"] = 原号
	竞技场窗脚本.画立绘(_页, _窗)
	var 回 := (String(方.texture.resource_path).get_file() if 方.texture != null else "〈没挂上图〉")
	## 期望：号自己的职业在四档里 ⇒ 就是那一档；不在 ⇒ `画立绘` 查不到号原样返回、屏上留的是
	## 上一档（循环最后一档 = 风）。原版这一档会在 `_facePanel.y` 上抛 null，我们保守留旧图，不另发明行为。
	var 望 := String(立绘真值.get(原号, "UISwf_PvpFeng_Skin.png"))
	_判.append(["还原成号自己的职业 %d 之后跟着回到 %s（屏上实际=%s）" % [原号, 望, 回], 回 == 望])
	_判.append(["立绘盒 = 240×334（屏上没被皮顶大，四张皮天然就是 240×334）",
			absf(方.size.x - 240.0) < 0.6 and absf(方.size.y - 334.0) < 0.6])
	_立绘条 = _判.size() - 起


## 全局浮层（`窗口管理/全局浮层`）里那一枚家族弹窗。按 **meta** 认，不按节点名认
## （同名再弹一层时 Godot 会把后一个改名 `@Control@N`）。
func _找家族弹() -> Control:
	if _管理 == null:
		return null
	var 浮: Node = _管理.get_node_or_null("全局浮层")
	if 浮 == null:
		return null
	var 栈: Array = [浮]
	while not 栈.is_empty():
		var 节: Node = 栈.pop_back()
		if not is_instance_valid(节):
			continue
		if 节.has_meta("mdialog") and String(节.get_meta("mdialog")) == "family" \
				and not 节.is_queued_for_deletion():
			return 节 as Control
		for 子 in 节.get_children():
			栈.append(子)
	return null


## 「本期排名奖励获得」那枚弹 = `PvpManager.as:98-103` → `FamillyPopUpWindow.popUpWindow(文案, null,
## null, "", null, "", false)` + `hideCancelButton()`。
## 期望值**逐条从 AS3 现算后写死在这里**，不向 `家族弹窗.gd` 要（两边一起写错会互相印证 = 假绿，
## 见 user 记忆 gate-must-be-run-not-listed 第卅七种）：
##   底宽 = 皮肤原生 **216**（`FamillyPopUpWindow:113-114`；`popUpWindow` 这一支不调 `windowWidth`）
##   区高 = 15·3 行 + pad 8 + pad 8 + 6 = **67**（`:178` + `:122` CONTENT_GAP，12px 宋体行盒 15）
##   底高 = 25 + 67 + 43 = **135**（`:186-188`，67 严格大于 `MIN_TEXT_HEIGHT` 51 ⇒ 才撑）
##   正文 = (5, 25, 216−12, 67)（`:123-124`）；确定宽 = 12·2 + 6 = 30、x = (216−30)/2 = **93**、
##   y = 135 − 22 − 12 = **101**（`:167` + `:190`）
func _判排名奖弹() -> void:
	var 起 := _判.size()
	var 弹 := _找家族弹()
	_判.append(["喂 `2306:8:1000:5000` 那一帧之后，浮层上真长出一枚家族弹窗", 弹 != null])
	if 弹 == null:
		_弹条 = _判.size() - 起
		return
	var 主 := 弹.get_node_or_null("主体") as Control
	_判.append(["这一枚自己有「主体」那一层（原版 Sprite 本体）", 主 != null])
	if 主 == null:
		_弹条 = _判.size() - 起
		return
	var 底 := 主.get_node_or_null("底") as Control
	_判.append(["底 = 216×135（原生宽 + `25+67+43` 撑高）", 底 != null
			and absf(底.size.x - 216.0) < 0.6 and absf(底.size.y - 135.0) < 0.6])
	## 居中那一条必须量**屏幕上的位置**：遮罩刚建出来那一帧 size 还是 0 ⇒ 以前会算成 (−108,−68)，
	## 弹整个跑到屏幕外左上角，而逐件的相对矩形照样全绿。
	_判.append(["整枚弹居中在舞台上（主体 = (372,212) 实得 (%d,%d)）" % [
			int(主.position.x), int(主.position.y)],
			absf(主.position.x - 372.0) < 0.6 and absf(主.position.y - 212.0) < 0.6])
	var 正 := 主.get_node_or_null("正文") as RichTextLabel
	_判.append(["正文盒 = (5,25,204,67)", 正 != null and absf(正.position.x - 5.0) < 0.6
			and absf(正.position.y - 25.0) < 0.6 and absf(正.size.x - 204.0) < 0.6
			and absf(正.size.y - 67.0) < 0.6])
	## ★ 这一条就是用户实机报的那个症状：三行文案露出半截。量的是**内容需要多高**对**盒子多高**，
	## 不是量我"确实按 67 摆了"。
	_判.append(["三行文字**装得下**（内容高 %d ≤ 盒高 %d）" % [
			正.get_content_height() if 正 != null else -1, 正.size.y if 正 != null else -1],
			正 != null and 正.get_content_height() <= int(正.size.y) + 1])
	var 文 := 正.get_parsed_text() if 正 != null else ""
	var 行: PackedStringArray = 文.split("\n")
	var 三 := String(行[2]) if 行.size() > 2 else "〈没有第三行〉"
	_判.append(["正文是三行（实得 %d 行）" % 行.size(), 行.size() == 3])
	_判.append(["第三行是那笔阅历：实得「%s」" % 三, 三 == "5000阅历"])
	var 确 := 主.get_node_or_null("确定") as Control
	_判.append(["确定 = (93,101,30,22)（`hideCancelButton` 把它搬到正中）", 确 != null
			and absf(确.position.x - 93.0) < 0.6 and absf(确.position.y - 101.0) < 0.6
			and absf(确.size.x - 30.0) < 0.6 and absf(确.size.y - 22.0) < 0.6])
	var 取 := 主.get_node_or_null("取消") as Control
	_判.append(["取消那颗**藏着**（节点在、visible=false）", 取 != null and not 取.visible])
	_判.append(["没有暗层（`popUpWindow` 第 7 参 modal=false）", 弹.get_node_or_null("暗层") == null])
	var 壳: Node = _管理.get_node_or_null("全局浮层") if _管理 != null else null
	var 台: Control = (壳.get_node_or_null("舞台") as Control) if 壳 != null else null
	## 层号这一条是 10-24 那条真窟窿：`窗口管理.重排层级` 给每扇窗 `窗.layer = 110 + 序号`，
	## 弹要是落在 管理 的默认层上，**相对矩形全对、屏上却被窗整个盖住、点不到**。
	_判.append(["浮层自己带一层 CanvasLayer 且层号 400（稳在窗口层之上）、舞台不拦点击",
			壳 is CanvasLayer and int((壳 as CanvasLayer).layer) == 400 and 台 != null
			and 台.mouse_filter == Control.MOUSE_FILTER_IGNORE])
	var 箱 := ((底 as Panel).get_theme_stylebox("panel") as StyleBoxTexture) if 底 is Panel else null
	_判.append(["底用的是 `弹窗底.png` 且九宫边 9（原生 216×134 被拉高 ⇒ 不九宫圆角会糊）",
			箱 != null and String(箱.texture.resource_path).ends_with("弹窗底.png")
			and is_equal_approx(箱.texture_margin_left, 9.0)])
	_弹心 = 确.global_position + 确.size * 0.5 if 确 != null else Vector2.ZERO
	_弹条 = _判.size() - 起


func _找页() -> Control:
	var 容器: Control = _窗.get("_content") as Control
	if 容器 == null:
		return null
	for 子 in 容器.get_children():
		if String(子.name).begins_with("竞技场页"):
			return 子 as Control
	return null


func _喂帧(串: String) -> void:
	if _后端 == null:
		return
	_后端.call("_handle_arena_text", PackedStringArray(串.split(":")))


func _节点(路: String) -> Node:
	return _页.get_node_or_null(路) if _页 != null else null


func _文(路: String) -> String:
	var n := _节点(路)
	return String(n.text) if n != null else "〈没有这个件〉"


func _判数据() -> void:
	_判.append(["喂帧之后面板显形", _页 != null and _页.visible])
	_判.append(["排名落进「排名行/值」= 12", _文("面板/左列/排名行/值") == "12"])
	_判.append(["连胜落进「连胜行/值」= 3", _文("面板/左列/连胜行/值") == "3"])
	_判.append(["今日还可挑战 13 次", "13" in _文("面板/候选块/剩余次数")])
	_判.append(["我的排名那行有 12", "12" in _文("面板/候选块/我的排名")])
	## 候选按 `pkLevel` **降序**（`updateCandidates:341`）⇒ 第 1 枚是 9（甲四），第 5 枚是 5（甲五）
	_判.append(["候选按排名降序：第1枚=9", _文("面板/候选块/候选容器/候选格1/排名") == "9"])
	_判.append(["第1枚名字=甲四", _文("面板/候选块/候选容器/候选格1/名字") == "甲四"])
	_判.append(["第1枚等级行含 53", "53" in _文("面板/候选块/候选容器/候选格1/等级")])
	_判.append(["第5枚=5", _文("面板/候选块/候选容器/候选格5/排名") == "5"])
	var 头 := _节点("面板/候选块/候选容器/候选格1/头像") as TextureButton
	_判.append(["第1枚头像挂上了图（按 face 取）", 头 != null and 头.texture_normal != null])
	var 悬 := _节点("面板/候选块/候选容器/候选格1/悬停层") as Control
	_判.append(["悬停层默认藏", 悬 != null and not 悬.visible])
	var 清CD := _节点("面板/候选块/清CD钮") as Control
	_判.append(["CD 37 秒 ⇒ 清CD钮亮了", 清CD != null and 清CD.visible])
	_判.append(["CD 秒数打的是 00:37", _文("面板/候选块/CD秒") == "00:37"])
	## 战报：`sortReport` 按 timeStamp **降序** ⇒ 戳 2 那条在前
	_判.append(["战报第1行是戳 2 那条（乙一）", "乙一" in _文("面板/战报块/战报容器/战报行1/文本")])
	_判.append(["战报第2行是戳 1 那条（甲一）", "甲一" in _文("面板/战报块/战报容器/战报行2/文本")])
	_判.append(["第3行没数据 ⇒ 藏起来", not ((_节点("面板/战报块/战报容器/战报行3") as Control).visible)])
	_判.append(["战报行2 走「挑战/被挑战」那一对文案之一", ("你挑战" in _文("面板/战报块/战报容器/战报行2/文本")) or ("挑战你" in _文("面板/战报块/战报容器/战报行2/文本"))])
	## 逐件矩形回读：证明 .tscn 没被改动过（量具先报错，别拿错坐标去比图）
	_判.append(["底图矩形 = 10,11,750,516", _矩("底图")])
	_判.append(["候选块原点 = 240,155", _矩("面板/候选块")])
	_判.append(["战报块原点 = 240,361", _矩("面板/战报块")])
	_判.append(["公告宽 = 490", _宽("面板/公告")])
	_判.append(["第2枚候选在容器内 x = 104（步距 90）", _矩("面板/候选块/候选容器/候选格2")])


func _矩(路: String) -> bool:
	var n := _节点(路) as Control
	if n == null:
		return false
	return _矩对(路, n.get_rect())


func _矩对(路: String, r: Rect2) -> bool:
	var 望 := {
		"底图": [10.0, 11.0, 750.0, 516.0],
		"面板/候选块": [240.0, 155.0, 0.0, 0.0],
		"面板/战报块": [240.0, 361.0, 0.0, 0.0],
		"面板/候选块/候选容器/候选格2": [104.0, 0.0, 75.0, 156.0],
	}
	var v: Array = 望.get(路, [])
	return v.size() == 4 and is_equal_approx(r.position.x, v[0]) and is_equal_approx(r.position.y, v[1]) \
		and is_equal_approx(r.size.x, v[2]) and is_equal_approx(r.size.y, v[3])


func _宽(路: String) -> bool:
	var n := _节点(路) as Control
	return n != null and is_equal_approx(n.get_rect().size.x, 490.0)


## 真 `push_input` 点一下（`emit_signal("pressed")` 演出来的绿不算 —— 口径见 user 记忆 gate-must-use-real-input）。
func 点一下(位: Vector2) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 位
	root.push_input(移)
	var 按 := InputEventMouseButton.new()
	按.position = 位
	按.global_position = 位
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	root.push_input(按)
	var 放 := InputEventMouseButton.new()
	放.position = 位
	放.global_position = 位
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	root.push_input(放)


func _抓图(路: String) -> void:
	var 图 := root.get_texture().get_image()
	if 图 == null or 图.is_empty():
		push_error("拿不到视口图像 —— 是不是加了 --headless？")
		return
	if 图.save_png(路) != OK:
		push_error("存图失败：" + 路)
		return
	print("竞技场开窗：%s（%dx%d）" % [路, 图.get_width(), 图.get_height()])


func _收() -> void:
	var 红 := 0
	for 一 in _判:
		var 过: bool = bool(一[1]) if 一.size() > 1 else false
		if not 过:
			红 += 1
		print("  %-4s  %s" % ["通过" if 过 else "红", 一[0]])
	print("竞技场开窗自检：判 %d 条，红 %d 条" % [_判.size(), 红])
	quit(0 if 红 == 0 else 1)
