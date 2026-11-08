extends RefCounted

## 三代火影（NPC `00000022`，模板 22，称号「洗点大师」）「洗点」族两扇 = 原版
## `com/mxw/uifl/controls/washPoint/WashPointWindow`（275×324，标题「洗点」）
## + `WashPointConfrimWindow`（240×**198**，标题同一个语言键）。
## 两扇的场景都由 `开发工具/原版服务窗.py 生成 洗点 / 洗点确认` 从 SPEC 烘，**别手改 .tscn**。
## ⚠ 类名拼写照抄原版：`Confrim`（原版就少一个 i），文件与页名都跟着它。
##
## 这一族的四行是**纯本地状态机**（原版也不发帧，直到点确认弹的「确定」）⇒ 交互面全照搬：
##   `WashPointWindowCell.as:43-122` 四枚钮的语义（**注意加减的方向**，与钮名反着）：
##     全收钮 = `addAllPointBtn`(x=145) ⇒ `tempPoints = 0`（把这行已还原的点收回）
##     加钮   = `addPointBtn`(x=167，`MPlusBtnF`) ⇒ **`tempPoints − 1`**（`:55-62`，只在 > 0 时）
##     减钮   = `minusPointBtn`(x=186，`MMinusBtnF`) ⇒ **`tempPoints + 1`**（`:88-95`，只在 < 基数时）
##     全放钮 = `minusAllPointBtn`(x=205) ⇒ `tempPoints = basePoints`（整行都还原成未分配）
##   ⇒ 「+」是把点**加回属性**（还原数变小），「−」是把点**从属性拿下来**（还原数变大）；
##     两件显示：已分配 = `base − temp`（`:111`）、还原数 = `-temp`（`:112`，**带负号**）。
##   `:51-52` 禁用配对：全收/加 同组 = `temp > 0`；减/全放 同组 = `temp < base`。
##   `:174` 开窗把四枚 `minusAllPointBtn.selected = true` —— ⚠ **这边什么都不做**：
##     `MArrowBtnF`(charId 940) 的 `upSkin` 与 `selectedUpSkin` 是**同一个 characterId 939**
##     （查过符号表）⇒ `selected` 换不出第二张皮，原版那一行在这枚钮上没有视觉后果。
##
## 窗级联动（`:79-84 __showAllRevertPoints`，由每行 `setRevertPoints:114-115` 的事件驱动）：
##   获得数值 = 四行 temp 之和；「开始洗点」`enabled = 总和 > 0`。
##   ⚠ 开窗时 `initWindow → setData` **不走这条事件** ⇒ `:191` 那句 `okBtn.enabled = false`
##     就是开屏那一张（哪怕角色一行都没分配），点过任一行钮才会解禁。
##
## 确认弹（`:240-247 __onOkClick`）：本地 new + `setData(四项 temp)` + `PopUpMananger.centerWindow`
##   ⇒ 居中、**不发帧**。两段文案的行数由语言键本身定死（3 行 + 2 行）⇒ 稳态窗高 198 已烘进
##   场景与尺寸表（口径同 跨服频道 的 414→451），控制器不再运行期改高。
##   「确定」⇒ 回主窗 `__confirm:306-323`：**等级 > 30 才查背包洗点卷**，不足 ⇒ 只弹通知、
##   **弹层不关**；够 ⇒ 才发 `REWASH_AP 83` 并关弹。本工程发帧那一步未点头 ⇒ 只回显。
##
## ⚠ 一条已知偏离（登记在真值 md 的未决表，等点头）：
##   原版 `PopUpMananger.centerWindow(w, **true**)` 会铺一层全屏 alpha 0.3 的黑遮罩、
##   **点遮罩 = 取消**（`PopUpMananger.as:58-105`）。本工程的弹窗遮罩是一层工程级机制
##   （要和 `窗口管理` 的层序、`HUD基` 那套一起决定）⇒ 本轮只做**居中**、不做遮罩。
##
## 配置面：`免费级` / `洗点卷` 是**静态配置**（`Etc` 段 `XiDian`，`WashPointWindow.as:107-109`
##   `ImgUtil.getImg(ImgType.Etc,"XiDian")`）⇒ 运行期从 `数据/原版杂项.json` 读，不写死。

const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

## `initWindow:201-202` 的取数顺序 = `ap_ATK / ap_DEF / ap_DEX / ap_PHY`，
## 与我方 `player_stats` 的键一一对应（`服务端会话同步.gd:28` 的改名表）。
const 属性键 := ["ap_atk", "ap_def", "ap_dex", "ap_phy"]
const 行数 := 4
const 钮路 := ["全收钮", "加钮", "减钮", "全放钮"]		# 与上面四枚语义同序

## 文案模板逐字取自语言表（`%1`-式占位、`<br/>` 分隔）：
## `WASH_POINT_CONFIRM_TIP`(`message_properties.as:1451`) —— ⚠「攻击型 %1 点：」后面**有一个空格**、
## 「灵巧型 %3 点：健体型 %4 点」那句里**没有**，两个冒号都是**全角**。
const 方案模板 := "攻击型 %1 点： 防御型 %2 点<br/>灵巧型 %3 点：健体型 %4 点<br/>确认要将它们还原成未分配的潜能点吗？"
## `WASH_POINT_CONFIRM_TIP1`(`:1508`)
const 结果模板 := "还原后，将获得未分配潜能点：%1<br/>本次操作将需要洗点卷：%2"
## `WASH_POINT_TIP_XI_SUI_DAN_SHORTAGE`(`:1545`)
const 卷不足 := "很抱歉，你背包中的洗点卷数量不足，洗点操作失败了"


## 会话级状态（原版是窗内字段 `basePoints` / `_tempPoints`）。
static var _基数: Array[int] = [0, 0, 0, 0]
static var _还原: Array[int] = [0, 0, 0, 0]


static func 新会话() -> void:
	_基数 = [0, 0, 0, 0]
	_还原 = [0, 0, 0, 0]


static func 还原数() -> Array[int]:
	return _还原


static func 基数() -> Array[int]:
	return _基数


static func 总和() -> int:
	var 合 := 0
	for v in _还原:
		合 += v
	return 合


## 主窗。`宿主` = `功能窗口`（要 `_content` / `_session` / `_通知` / `close`）。
static func 渲染(宿主: Node, 场景: PackedScene) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	var 属性: Dictionary = {}
	var 会: Node = 宿主.get("_session") as Node
	if 会 != null:
		属性 = 会.get("player_stats") as Dictionary
	for 序 in 行数:
		_基数[序] = int(属性.get(属性键[序], 0))
		_还原[序] = 0
		_接行(页, 序, 宿主)
	_画行们(页)
	# `:139` pointText 初值 "0"、`:191` `okBtn.enabled = false` —— 都已烘在场景里，
	# 这里只把它们按当前总和再钉一次（`setData` 之后 `:236` 那句 `总和 > 0 ? 文本 : "0"`）。
	(页.get_node("获得数值") as Label).text = str(总和())
	(页.get_node("开始钮") as Button).disabled = true		# 开窗不走 SHOW_ALL_REVERT_POINTS
	(页.get_node("开始钮") as Button).pressed.connect(_点开始.bind(宿主))
	# `:325-328 __onCancelClick` 就是 `onCloseBtnClick` ⇒ 「我再想想」= 关窗，不发帧、不清状态。
	(页.get_node("再想钮") as Button).pressed.connect(func() -> void: 宿主.call("close"))
	return 页


static func _接行(页: Control, 序: int, 宿主: Node) -> void:
	for 名 in 钮路:
		# ⚠ 行里的件名是**带行号前缀**的（生成器按 SPEC 的件名烘 ⇒ `行0全收钮`），
		#   拼成 `行0/全收钮` 会 get_node 拿不到 ⇒ 整扇窗在这一句死掉、后面的 `_画行们`
		#   根本没跑（2026-10-06 行为门抓到的第一条：十二枚行钮一枚都没接上）。
		var 钮 := 页.get_node("行%d/行%d%s" % [序, 序, 名]) as Button
		钮.pressed.connect(_点钮.bind(页, 序, 名, 宿主))


## 四枚钮的分支（`:43-122`），改完统一走 `_画行们`（= `setRevertPoints` + 窗级那条事件）。
static func _点钮(页: Control, 序: int, 名: String, _宿主: Node) -> void:
	match 名:
		"全收钮":
			_还原[序] = 0				# `_addAllPoint:118-122`
		"加钮":
			if _还原[序] > 0:			# `_addPoint:55-62`
				_还原[序] -= 1
		"减钮":
			if _还原[序] < _基数[序]:		# `_minusPoint:88-95`
				_还原[序] += 1
		"全放钮":
			_还原[序] = _基数[序]			# `_minusAllPoint:43-47`
	_画行们(页)


## `setRevertPoints:109-116` + `setBtnEnabled:49-53` + `__showAllRevertPoints:79-84`。
static func _画行们(页: Control) -> void:
	for 序 in 行数:
		var 行 := 页.get_node("行%d" % 序) as Control
		(行.get_node("行%d已分配" % 序) as Label).text = str(_基数[序] - _还原[序])
		(行.get_node("行%d还原数" % 序) as Label).text = "-%d" % _还原[序]
		(行.get_node("行%d全收钮" % 序) as Button).disabled = _还原[序] <= 0
		(行.get_node("行%d加钮" % 序) as Button).disabled = _还原[序] <= 0
		(行.get_node("行%d减钮" % 序) as Button).disabled = _还原[序] >= _基数[序]
		(行.get_node("行%d全放钮" % 序) as Button).disabled = _还原[序] >= _基数[序]
	(页.get_node("获得数值") as Label).text = str(总和())
	(页.get_node("开始钮") as Button).disabled = 总和() <= 0


## `__onOkClick:240-247`：本地开确认弹（居中），不发帧。
static func _点开始(宿主: Node) -> void:
	if 总和() <= 0:
		return			# 原版这枚是 disabled ⇒ 根本进不来；这行只守门，不另造提示
	var 管理: Node = 宿主.get_parent()
	if 管理 == null or not 管理.has_method("打开"):
		return
	管理.call("打开", "洗点确认")


## 确认弹。`方案文本`/`结果文本` 是运行期数据 ⇒ 场景烘空件，这里按逐字模板填。
static func 渲染确认(宿主: Node, 场景: PackedScene) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	var 合 := 总和()
	var 配置: Dictionary = 游戏数据.取表("原版杂项").get("XiDian", {}) as Dictionary
	var 免费级 := int(配置.get("chargeLevel", 30))
	var 级 := 1
	var 会: Node = 宿主.get("_session") as Node
	if 会 != null:
		级 = int((会.get("player_stats") as Dictionary).get("level", 1))
	# `:63` 四项 temp 逐个替 %1..%4；`:64-66` 总和 与 `%2 = 等级 <= 30 ? 0 : 总和`（原版这里**写死 30**）。
	(页.get_node("方案文本") as RichTextLabel).text = 确认弹.文案转BBCode(
			替(方案模板, [str(_还原[0]), str(_还原[1]), str(_还原[2]), str(_还原[3])]))
	(页.get_node("结果文本") as RichTextLabel).text = 确认弹.文案转BBCode(
			替(结果模板, [str(合), str(0 if 级 <= 免费级 else 合)]))
	(页.get_node("确定钮") as Button).pressed.connect(_点确定.bind(宿主, 免费级))
	(页.get_node("取消钮") as Button).pressed.connect(func() -> void: 宿主.call("close"))
	return 页


## `:306-323 __confirm`：先等级闸门、再卷数闸门；**卷不够就不关弹**（`:313` 直接 return）。
static func _点确定(宿主: Node, 免费级: int) -> void:
	var 配置: Dictionary = 游戏数据.取表("原版杂项").get("XiDian", {}) as Dictionary
	var 卷号 := int(配置.get("needItemId", 0))
	var 会: Node = 宿主.get("_session") as Node
	var 级 := 1
	if 会 != null:
		级 = int((会.get("player_stats") as Dictionary).get("level", 1))
	if 级 > 免费级 and 宿主._背包数量(卷号) < 总和():
		宿主._通知(卷不足)
		return
	## ⭐ 真上行（原版 `UI.as:1143-1146` → `Client.requestRewashAp` →
	## `AllInOneProcessor.requestRewashAp:1845-1853` 四个 short，序 = 攻/防/敏/体）。
	## 以前这里只打一句"本工程未接"就关弹 ⇒ 点确定什么都不发生（用户 10-22 点名的这一条）。
	## 顺序就是 `_还原[0..3]`：`initWindow:201-202` 取数序与 `onWashPoint` 的形参序同一份。
	var 后端 := 宿主.get_node_or_null("/root/BackendConnection") as Node
	if 后端 == null or not 后端.has_method("request_rewash_ap"):
		宿主._通知("洗点上行发不出去：取不到 /root/BackendConnection（不是「未接」，是宿主没挂上）")
		return
	后端.call("request_rewash_ap", _还原[0], _还原[1], _还原[2], _还原[3])
	## 这句只说"我发了什么"，**不预报结果**：成功/失败那两句话都来自服务端
	## （`handle_rewash_ap:34319/34338/34361` 的 `_send_native_server_message`）。
	宿主._通知("已发 REWASH_AP 83（攻/防/敏/体 = %d/%d/%d/%d），洗点结果听服务端回话" % [
			_还原[0], _还原[1], _还原[2], _还原[3]])
	## 原版发完就等回帧，成功/失败那两句话都来自服务端（`handle_rewash_ap:34319/34338/34361`
	## 的 `_send_native_server_message`）⇒ 这边**不自造**「洗点成功」之类的提示。
	宿主.call("close")


## `%1`-式占位替换（同 日环任务窗 那条口径：按序号替，不用 fmt）。
static func 替(模板: String, 参数: Array) -> String:
	var 文 := 模板
	for i in 参数.size():
		文 = 文.replace("%" + str(i + 1), str(参数[i]))
	return 文
