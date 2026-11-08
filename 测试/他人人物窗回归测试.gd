extends SceneTree

## 「人物属性（看别人）」离线门（#240，2026-10-15）。
##
## 参照值全部手抄自 `真值/窗口/人物属性_看别人.md`（AS3 行号 + `读符号时间轴.py` 的元件时间轴），
## **不从被测场景反查、不从截图量**。喂进去那条协议串是**真机原文**
## （`数据/界面/查看信息夹具.json`，由 `测试/查看信息在线回归测试.gd` 在独立端口 18706 的隔离夹具上实收导出）。
##
## 覆盖：① 真机原文喂进真解析器 ⇒ 24 个键逐项对 + 两种坏帧的出口 ② 那一帧到本端 ⇒ 窗自己开
## ③ `他人信息面板` 逐件矩形（块原点与 `addPointPane` 同一个 243,223）④ 页上数字跟着档案变
## ⑤ 三根条的文字与填充（含 `total == 0` 画满那条原版口径）⑥ 加点那一整块必须全隐
## ⑦ 装备格只读（拖放一帧不接、点击菜单不接，但**悬停提示要留**）⑧ 立绘 = 对方那张脸
## ⑨ 四颗钮三态：真鼠标悬停 +30 皮、按下 −40 皮、**松手回常态** ⑩ 四颗钮各发什么（含"已是好友不发包"）
## ⑪ 尺寸表那一条 ⑫ 没档案不许开一屏 0。
##
## 跑法：`"godot" --path . --headless --script res://测试/他人人物窗回归测试.gd`

const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 夹具路径 := "res://数据/界面/查看信息夹具.json"
const 尺寸表路径 := "res://数据/界面/窗口尺寸.json"
const 职业表 := preload("res://脚本/单例/职业.gd")
## ⑱ 那一页的虫槽判定要用**部位表的槽号常量**（−200..−203），属性行要用品类表那份
## **唯一的**属性中文名（`ItemFactory.SUB_ATTR_TYPES/_NAMES` 逐字抄的那张）。
const 装备部位 := preload("res://脚本/单例/装备部位.gd")
const 装备提示框 := preload("res://脚本/界面/组件/装备提示框.gd")
const 人物窗口 := preload("res://脚本/界面/窗口/人物窗口.gd")
const 宠物页脚本 := preload("res://脚本/界面/窗口/宠物窗口.gd")
const 页根名 := "原版人物窗口内容"
const 面板名 := "原版人物属性面板"
const 块名 := "他人信息面板"
const 块路 := 面板名 + "/" + 块名

## §③ 逐件矩形 [x, y, 宽, 高]，**块局部**。出处见真值表 §④：
## 条 = 符号 962（label 宽 58 ⇒ 槽 x=58；槽 = 122×0.877029 = 107 宽、11 高、条局部 y=3），
## 行距 19 来自时间轴 @(0,0)/(0,19)/(0,38)；钮 58×22（`CharPointInfoPane.as:91`）
## 在 (20,74)/(96,74)/(20,105)/(96,105) = 时间轴 (20.2,65)/(96,65)/(20,90)/(96,90) + AS3 的 y+=9 / +=15。
const 块件 := {
	"忍术境界名": [0.0, 2.0, 58.0, 16.0],
	"忍术境界槽": [58.0, 3.0, 107.0, 11.0],
	"忍术境界值": [58.0, 1.0, 107.0, 16.0],
	"八门进度名": [0.0, 21.0, 58.0, 16.0],
	"八门进度槽": [58.0, 22.0, 107.0, 11.0],
	"八门进度值": [58.0, 20.0, 107.0, 16.0],
	"成就进度名": [0.0, 40.0, 58.0, 16.0],
	"成就进度槽": [58.0, 41.0, 107.0, 11.0],
	"成就进度值": [58.0, 39.0, 107.0, 16.0],
	"条下分隔线": [0.0, 58.0, 173.0, 2.0],
	"密语钮": [20.0, 74.0, 58.0, 22.0],
	"交易钮": [96.0, 74.0, 58.0, 22.0],
	"加友钮": [20.0, 105.0, 58.0, 22.0],
	"组队钮": [96.0, 105.0, 58.0, 22.0],
}
## 加点那一整块（看别人时**七件一起隐**：它们是 `原版人物属性面板` 的兄弟节点，藏背景带不走别的）
const 加点件 := ["加点属性底板", "加点属性标题", "基础属性", "潜能点", "潜能点值", "确认加点", "推荐加点"]
const 钮常态 := "窗内按钮.png"
const 钮悬停 := "窗内按钮_悬停.png"
## 四颗钮的提示（与顶栏那排同一批语言键，`DetailsWindow.as:113`）
const 钮提示 := {"密语钮": "私聊", "交易钮": "邀请交易", "加友钮": "加为好友", "组队钮": "组队邀请"}
## `MButton3.as:69-74` `_textColors[STATE_UP]` = 16773276 = #FCF49C
const 钮字色 := [0.9882353, 0.95686275, 0.6117647]

var 通过 := 0
var 失败 := 0
var 跑完了 := false
var 夹: Dictionary = {}
var 通知: Array = []
var 假后: Node = null
var 聊天: Node = null
var 管: Node = null
var 窗: Node = null


## 只记不发。`功能窗口._backend` 声明成 `Node` ⇒ 假对象必须也是 Node（写成 RefCounted 会 set 失败）。
class 假后端 extends Node:
	var 发的: Array = []
	var map_players := {}
	var in_game := true
	var 是好友 := false
	func request_trade_invite(号: int) -> bool:
		发的.append(["交易", 号]); return true
	func request_friend_add(号: int) -> bool:
		发的.append(["加好友", 号]); return true
	func request_party_invite(名: String) -> bool:
		发的.append(["组队", 名]); return true
	func is_friend(_号: int) -> bool:
		return 是好友
	## 装备串的解码**不在这里写第二份**：转给树上那个真 `BackendConnection`。
	## 少了这一条，`人物窗口.他人装备` 里那句 `后.call("_parse_item_entry", …)` 会在
	## 假对象上找不到方法 ⇒ 返回 null ⇒ 二十格静默全空，而门只会红在"没图标"上（10-16 现场）。
	func _parse_item_entry(串: String) -> Dictionary:
		var 真 = get_node_or_null("/root/BackendConnection")
		return 真.call("_parse_item_entry", 串) if 真 != null else {}
	## 宠物串（段 32）的解码同一条口径：**必须在假对象上转给真解析器**。
	## 少了这一条，`人物窗口.他人宠物()` 里那句 `后.call("_parse_pet_fields", …)` 拿到 null，
	## 清单永远空 ⇒ ⑲ 整组"他有几只就几行"变成"零行"，而零行看着跟"他没宠物"一模一样（假绿）。
	func _parse_pet_fields(段: PackedStringArray, 起点: int, 行分隔 := "!", 字段分隔 := "#") -> Dictionary:
		var 真 = get_node_or_null("/root/BackendConnection")
		return 真.call("_parse_pet_fields", 段, 起点, 行分隔, 字段分隔) if 真 != null else {}


## 「密　语」那一发的落点：原版 `ChatEvent.CHECK_ONLINE(playName)` 不发包，是聊天框切私聊频道。
class 假聊天 extends Node:
	var 收到: Array = []
	func 开始私聊(名: String) -> void:
		收到.append(名)


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 话)


func _initialize() -> void:
	await _跑()
	if not 跑完了:
		失败 += 1
		print("红：门自己没跑完（协程中途报错），汇总行没打出来")
	quit(1 if 失败 > 0 else 0)


func _矩形(件: Control) -> Array:
	return [件.offset_left, 件.offset_top,
			件.offset_right - 件.offset_left, 件.offset_bottom - 件.offset_top]


func _近(实: Array, 参: Array) -> bool:
	if 实.size() != 4:
		return false
	for i in 4:
		if absf(float(实[i]) - float(参[i])) > 0.51:
			return false
	return true


func _开着() -> bool:
	if 窗 == null:
		return false
	var 遮 = 窗.get("_overlay")
	return 遮 != null and (遮 as CanvasItem).visible


## 按名字找页（⚠ `功能窗口` 的根是 CanvasLayer，别 `as Control` 取它）
func _页() -> Control:
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	for 子 in 内容.get_children():
		if String(子.name) == 页根名:
			return 子 as Control
	return null


func _块() -> Control:
	var 页 := _页()
	return 页.get_node_or_null(块路) as Control if 页 != null else null


func _文(路径: String) -> String:
	var 页 := _页()
	if 页 == null:
		return "<没有页>"
	var 件 := 页.get_node_or_null(路径) as Label
	return 件.text if 件 != null else "<没有 %s>" % 路径


## 真输入。**不用 `mouse_entered.emit()`** —— 那会把"接错了线"也演成绿的。
##
## ⚠ 无头模式一条实测口径（本门第一次跑就是栽在这）：`root.size = Vector2i(960,560)` **过一帧就被
## headless 显示服务打回 64×64**，而视口外的坐标根本不参与拾取 ⇒ 钉完不能再 `await`，
## 必须**同帧内钉完立刻 push**（拾取是同步的，`mouse_entered`/`pressed` 当场就发）。
## 坐标按"当前(64×64)那一版布局"算 —— 同帧内没重排，件还在原地，所以算出来就是它落点。
func _屏心(件: Control) -> Vector2:
	return 件.get_global_rect().position + 件.size * 0.5


func _钉() -> void:
	root.size = Vector2i(960, 560)


func _移到(件: Control) -> void:
	var 屏 := _屏心(件)
	var 移 := InputEventMouseMotion.new()
	移.position = 屏
	移.global_position = 屏
	_钉()
	root.push_input(移)


## 把鼠标挪到**窗外**去（同一个件上再发一次 motion 不会重发 `mouse_entered` ⇒ 悬停那条判据
## 必须先把鼠标移开再移回来，否则测的是"上一次悬停的残余"）。
func _移开() -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = Vector2(-400, -400)
	移.global_position = Vector2(-400, -400)
	_钉()
	root.push_input(移)


func _按下(件: Control) -> void:
	var 屏 := _屏心(件)
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 屏
	按.global_position = 屏
	_钉()
	root.push_input(按)
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 屏
	放.global_position = 屏
	_钉()
	root.push_input(放)
	for 帧 in 2:
		await process_frame


func _皮(钮: TextureButton) -> String:
	if 钮.texture_normal == null:
		return "<空>"
	return String((钮.texture_normal as Resource).resource_path).get_file()


## 重新灌一帧并等渲染完（原版：窗已存在时 `setData` 逐段灌，不重建窗口本体）。
func _再灌(档: Dictionary) -> void:
	## 回帧按原版 `setData()` 的 `setPanel(0,0)` 会把页签拉回「人物」（master 10-22 那条
	## `_刚开窗` 判据，`看别人属性窗回归测试` ⑩a 钉着）。本门量的是**其它子页**的量法：
	## 先把当前下标记下来，等开窗/回帧那一轮跑完再写回去重绘一次 —— 这样各用例里
	## "set 下标 → 灌帧" 的既有写法不用逐条改，而回帧重置行为本身不被这条门抹掉。
	var 主 := int(窗.get("_character_main_tab")) if 窗 != null else 0
	var 子 := int(窗.get("_character_sub_tab")) if 窗 != null else 0
	管.call("_on_他人详细信息", 档)
	for 帧 in 8:
		await process_frame
	if 窗 == null:
		return
	窗.set("_character_main_tab", 主)
	窗.set("_character_sub_tab", 子)
	窗.call("_render_page")
	for 帧 in 8:
		await process_frame


## 按**页名**取它在某一排里的页签序号（别写死数字）。
## 为什么：`他人子分页组` 里插一枚页签就把所有写死的序号全体错位，而错位之后
## "那页照样显、那颗钮照样找得到"（因为找的是**另一页**的同名件）⇒ 红绿都不可信。
## ⑯ 那三行原来全写 `0`、轮回六道一直在看写轮眼，就是同一族的错（10-16 现查）；
## 10-16 晚把「宠物」插进 0 排第二位，又是一次全体错位 —— 这次靠这个函数免疫。
## ⚠ 一律按 `等级 = 99` 数：这一步之后的用例都把等级抬到 100（`高`/`换`），
##   那一档下每一排的页签是全的，序号才与窗里实际建出来的那排一致。
func _序号(排: int, 页名: String) -> int:
	return (人物窗口.他人子分页表(排, 99) as Array).find(页名)


func _跑() -> void:
	print("他人人物窗门开始")
	root.size = Vector2i(960, 560)			# 无头默认视口太小，GUI 拾取拿不到命中
	夹 = JSON.parse_string(FileAccess.get_file_as_string(夹具路径)) as Dictionary
	if 夹 == null or 夹.is_empty():
		_判(false, "夹具读不到：%s —— 先跑 `跑在线用例.ps1 -用例 查看信息` 导出来" % 夹具路径)
		跑完了 = true
		return
	var 原文 := String(夹.get("原文", ""))
	var 期望档: Dictionary = 夹.get("关键字段", {}) as Dictionary
	var 会话 := root.get_node_or_null("GameSession")
	var 后 := root.get_node_or_null("BackendConnection")
	_判(后 != null and 会话 != null, "真后端与真会话都在树上（本门判的是真解析器 + 真窗）")
	if 后 == null or 会话 == null:
		跑完了 = true
		return
	会话.connect("notification_requested", func(文本: String) -> void: 通知.append(文本))

	# ── ① 真机原文喂进真解析器 ────────────────────────────────────────────
	后.set("他人详细信息", {})
	后.set("他人详细信息原文", "")
	后.call("_handle_bridge_text", 原文)
	var 解: Dictionary = 后.get("他人详细信息")
	_判(not 解.is_empty(), "① 真机那条 `58:0` 喂进去 ⇒ 解析出档案（实得 %d 键）" % 解.size())
	_判(int(解.get("段数", 0)) == int(夹.get("段数", 0)),
			"① 段数 = 夹具记的 %s（实得 %s）" % [str(夹.get("段数", 0)), str(解.get("段数", 0))])
	_判(String(后.get("他人详细信息原文")) == 原文,
			"① 原文逐字节还原 ⇒ 离线喂的确实是真机那一帧，不是手写样本")
	for 键 in 期望档.keys():
		_判(解.get(键) == 期望档[键],
				"① 键「%s」= %s（实得 %s）" % [键, str(期望档[键]), str(解.get(键, "<无>"))])
	var 旧: Dictionary = 解.duplicate(true)
	后.call("_handle_bridge_text", "58:0:2:社交同伴:1")
	## cmd 1 = `CharacterSimpleInfo`（同一条 58 上的另一种形状，`handleCharInfoPacket:2643-2646`）
	## ⇒ 不许当成完整档案；段数不够的 cmd 0 也不许凑。
	后.call("_handle_bridge_text", "58:1:2:社交同伴:1:300:1:同伴家族:-:0:0:0:20:20000:10:500:500:200:200:1:1:1:1:160:100:0:0:0:1")
	_判((后.get("他人详细信息") as Dictionary) == 旧, "① 截断帧与 cmd 1 帧都整条丢掉，档案一字不动")
	## 同一条 `58:0` 但号换成**我自己** ⇒ 那是进游戏时服务端发的自己的档案，不许当"别人的"
	后.set("character_id", 2)
	后.call("_handle_bridge_text", 原文)
	_判((后.get("他人详细信息") as Dictionary) == 旧,
			"① 号 == 我自己的 `58:0` 判成自己的档案丢掉（否则一进游戏就弹一扇看自己的窗）")
	后.set("character_id", 0)
	后.call("_handle_bridge_text", 原文)

	# ── ② 那一帧到本端 ⇒ 窗自己开（走真的 `窗口管理` 消费者）──────────────────
	管 = (load(管理场景) as PackedScene).instantiate()
	root.add_child(管)
	for 帧 in 8:
		await process_frame
	_判(管.has_method("_on_他人详细信息"),
			"② `窗口管理` 有 `_on_他人详细信息` 这个消费者（没有 ⇒ 服务端发了也没人开窗）")
	假后 = 假后端.new() as Node
	root.add_child(假后)
	(假后.map_players as Dictionary)[2] = {"gender": 0, "name": "社交同伴"}
	窗 = 管.call("取或建窗口", "他人人物")
	窗.set("_backend", 假后)
	管.call("_on_他人详细信息", 解)
	for 帧 in 8:
		await process_frame
	_判(_开着(), "② 收到 `58:0` 那一帧 ⇒ 窗自己开出来了（不是靠点出来的）")
	_判(_页() != null and _块() != null, "② 页根与 `他人信息面板` 都在（页 %s / 块 %s）"
			% ["有" if _页() != null else "无", "有" if _块() != null else "无"])
	if _页() == null or _块() == null:
		跑完了 = true
		print("他人人物窗门：通过 %d，红 %d" % [通过, 失败])
		return

	# ── ③ 逐件矩形 ───────────────────────────────────────────────────────
	var 块 := _块()
	var 面板节 := (_页() as Control).get_node(面板名) as Control
	_判(_近(_矩形(块), [243.0, 223.0, 173.0, 137.0]),
			"③ 块矩形 = 时间轴 (243,223) 173×137（实得 %s）—— 与 `addPointPane` 同一个位置" % str(_矩形(块)))
	_判(_近(_矩形(面板节), [69.0, 20.0, 435.0, 366.0]),
			"③ `原版人物属性面板` 落点没被改动（实得 %s）" % str(_矩形(面板节)))
	for 件名 in 块件.keys():
		var 件 := 块.get_node_or_null(件名) as Control
		_判(件 != null and _近(_矩形(件), 块件[件名] as Array),
				"③ %s 矩形 = %s（实得 %s）" % [件名, str(块件[件名]), str(_矩形(件))])

	# ── ④ 页上数字跟着档案变 ──────────────────────────────────────────────
	## ⚠ 参照值**从夹具原文那几段现取**（`夹["原文"].split(":")`），不写死数字：
	##   这条判的是「原始帧 → 解字段 → 画上那行字」这一段会不会走歪；
	##   写死数字的话，每次重导真帧（对端穿/脱一件装备属性就变）都得回来改门
	##   —— 10-16 给对端穿上两只寄坏虫之后，攻击 35→125、血上限 500→750，
	##   旧的六个写死数一下红了六条，就是这个道理。
	var 段: PackedStringArray = String(夹.get("原文", "")).split(":")
	_判(段.size() >= 25, "④ 夹具原文有 25 段以上（实得 %d）—— 少了这几条判据全是空的" % 段.size())
	_判(_文("%s/信息区/姓名格/数值" % 面板名) == 段[3],
			"④ 名字 = 段3「%s」（实得「%s」）" % [段[3], _文("%s/信息区/姓名格/数值" % 面板名)])
	_判(_文("%s/信息区/等级格/数值" % 面板名) == 段[4],
			"④ 等级 = 段4「%s」（实得「%s」）" % [段[4], _文("%s/信息区/等级格/数值" % 面板名)])
	var 职 := _文("%s/信息区/职业格/数值" % 面板名)
	_判(职 == 职业表.取(int(段[5])) and 职 != "" and 职 != 段[5],
			"④ 职业那格是**职号查出来的名字**（实得「%s」，表[%s]=「%s」）—— 显示裸号就是没查表"
					% [职, 段[5], 职业表.取(int(段[5]))])
	_判(_文("%s/信息区/家族格/数值" % 面板名) == 段[7],
			"④ 家族 = 段7「%s」（实得「%s」）" % [段[7], _文("%s/信息区/家族格/数值" % 面板名)])
	_判(_文("%s/信息区/羁绊格/数值" % 面板名) == 段[8],
			"④ 羁绊读帧里的 spouseName（段8「%s」，实得「%s」）"
					% [段[8], _文("%s/信息区/羁绊格/数值" % 面板名)])
	## 战斗六项读段 19..24。这几项现在**含穿在身上的装备加成**（段 29 有武器 + 两只虫）⇒
	## 这一组顺带证明"档案里的属性是穿上装备之后的数"，不是裸号基值。
	for 对在 in [["攻击", 19], ["防御", 20], ["暴击", 21], ["闪避", 22],
			["攻击速度", 23], ["移动速度", 24]]:
		var 实 := _文("%s/战斗属性/%s" % [面板名, String(对在[0])])
		_判(实 == 段[int(对在[1])],
				"④ 战斗属性「%s」= 段%d「%s」（实得「%s」）" % [对在[0], 对在[1], 段[int(对在[1])], 实])
	var 经验上限 := int(float(段[12]))
	var 经验档 := "%d%%" % (int(float(段[11])) * 100 / 经验上限 if 经验上限 > 0 else 0)
	_判(_文("%s/经验数值" % 面板名) == 经验档,
			"④ 经验 %s/%s ⇒ %s（实得「%s」）" % [段[11], 段[12], 经验档, _文("%s/经验数值" % 面板名)])
	var 精华档 := "%d%%" % (int(float(段[13])) * 100 / 500000)
	_判(_文("%s/精华数值" % 面板名) == 精华档,
			"④ 精华 %s/500000 ⇒ %s（实得「%s」）—— 分母是 `UIConfig.ZQ_MAX`，不是兜底的 100"
					% [段[13], 精华档, _文("%s/精华数值" % 面板名)])
	_判(_文("%s/生命数值" % 面板名).contains("%s/%s" % [段[15], 段[16]]),
			"④ 生命值那行 %s/%s（实得「%s」）" % [段[15], 段[16], _文("%s/生命数值" % 面板名)])
	_判(_文("%s/查克拉数值" % 面板名).contains("%s/%s" % [段[17], 段[18]]),
			"④ 查克拉那行 %s/%s（实得「%s」）" % [段[17], 段[18], _文("%s/查克拉数值" % 面板名)])

	# ── ⑤ 三根条：文字与填充（`MBar.as:129-170` 三条口径）───────────────────
	## ⚠ 成就那一根的**分子一律从段 28 现取**：上一版写死 `1/503`，而夹具里那位
	## 社交同伴的成就点会随在线用例跑到 18 —— 那时客户端算得对、门反倒红，
	## 看着像"客户端算错"其实是参照值过期（分母 503 是 `成就上限`，与等级无关）。
	## ⚠ 填充走 `进度条补间` 的 0.5 秒补间（§3.243）：上限与文字**立即**写，`value` 要等墙钟。
	##   ⇒ 这里先钉文字与上限，再等 0.7s 钉当前值（"等 N 帧"在无头里必然假红）。
	## `八门进度` 上限 0 ⇒ `MBar` 口径**画满**（`灌值` 把 value 设成 max=1），不是空条。
	var 成就点 := int(解.get("成就点", 0))
	## 上限 0 那根：`灌值` 先把 max 抬到 1、value 设成 max ⇒ 满条（原版 `MBar._isShowBar`）。
	var 条表 := {"忍术境界": ["0/5400", 0, 5400], "八门进度": ["0/0", 1, 1],
			"成就进度": ["%d/503" % 成就点, 成就点, 503]}
	for 条名 in 条表.keys():
		var 值 := (块.get_node(条名 + "值") as Label).text
		var 槽 := 块.get_node(条名 + "槽") as ProgressBar
		_判(值 == String((条表[条名] as Array)[0]),
				"⑤ %s 条上文字 = %s（实得「%s」）" % [条名, (条表[条名] as Array)[0], 值])
		_判(int(槽.max_value) == int((条表[条名] as Array)[2]),
				"⑤ %s 槽上限 = %d（实得 %d）" % [条名, int((条表[条名] as Array)[2]), int(槽.max_value)])
	await create_timer(0.7).timeout
	for 条名 in 条表.keys():
		var 填: float = (块.get_node(条名 + "槽") as ProgressBar).value
		_判(int(填) == int((条表[条名] as Array)[1]),
				"⑤ %s 值填到 %d（实得 %.4f）—— 八门那根 0/0 按原版**画满**，不是空条"
						% [条名, int((条表[条名] as Array)[1]), 填])

	# ── ⑥ 加点那一整块必须全隐（同一位置的二选一）──────────────────────────
	for 件名 in 加点件:
		var 节 := 面板节.get_node_or_null(件名) as Control
		_判(节 != null and not 节.visible, "⑥ 看别人时「%s」是隐的（实得 %s）"
				% [件名, "取不到" if 节 == null else str(节.visible)])
	_判(块.visible, "⑥ 而 `他人信息面板` 是显的")
	_判(not (面板节.get_node("基础属性/攻击加点") as Control).is_visible_in_tree(),
			"⑥ 连里面的加点滴子都不许**有效可见**（父级 `基础属性` 隐了就整块不露）")

	# ── ⑦ 装备格只读：拖放一帧不接，但鼠标还在收（悬停提示要能出）─────────────
	var 容器 := 面板节.get_node("装备栏/装备格子容器") as Control
	var 武格 := 容器.get_node("武器格") as Button
	var 拖: Signal = 武格.get("拖放")
	_判(拖.get_connections().is_empty(),
			"⑦ 装备格的拖放信号**一条都没连**（实得 %d 条）—— 原版 `removeMouseEvents` 那一档"
					% 拖.get_connections().size())
	_判(武格.mouse_filter != Control.MOUSE_FILTER_IGNORE,
			"⑦ 格子还在收鼠标（悬停提示要出得来），实得 mouse_filter=%d" % 武格.mouse_filter)
	## 夹具现在带一件**真穿上的武器**（段 29 = `1&1010013&-1&…`）⇒ 武器格必须有图，
	## 而没装备的那格仍要照常写部位名。上一版这里钉的是"二十格全空"（因为夹具的段 29 是 `-`），
	## 那是把 bug 当预期钉住了 —— 见 `人物窗口.他人装备` 里 `slot`/`equip_position` 那条注。
	_判(String(武格.get("物品id")) == "1010013",
			"⑦ 武器格上挂的物品号 = 1010013（实得「%s」）" % String(武格.get("物品id")))
	_判(int(武格.get("槽位号")) == -1, "⑦ 武器格的槽位号 = -1（实得 %d）" % int(武格.get("槽位号")))
	_判(武格.icon != null, "⑦ 武器格取到了图标（实得 %s）"
			% ("null" if 武格.icon == null else str(武格.icon.resource_path).get_file()))
	_判(not (容器.get_node("武器格/名称") as Label).visible,
			"⑦ 有装备 ⇒ 那格的部位名**隐掉**（原版 `showIcon()` 里 `equipNameText.visible=false`）")
	var 衣格 := 容器.get_node("衣服格") as Button
	_判(String(衣格.get("物品id")) == "" and (容器.get_node("衣服格/名称") as Label).visible,
			"⑦ 反向对照：没装备的「衣服格」还是空格 + 照常写部位名（实得 id「%s」）"
					% String(衣格.get("物品id")))

	# ── ⑧ 立绘 = 对方那张脸 ───────────────────────────────────────────────
	# ⚠ 10-25 起这一格是**会播待机的精灵**（原版 `EquipPane.as:376-390` 就是 `setAction(stand)+play()`），
	#   静态图只当"查不到美术"时的退路 ⇒ 判据必须两边都认，且认的是**帧图文件名里那个脸号**，
	#   不然"节点在、图是别人的"照样能骗过 `texture != null`。
	var 立 := 面板节.get_node_or_null("角色站立图") as TextureRect
	var 立皮 := ""
	if 立 != null:
		立皮 = String(立.texture.resource_path).get_file() if 立.texture != null else ""
		var 播 := 立.get_node_or_null("角色待机")
		if 播 != null:
			for 子在 in (播 as Node).get_children():
				if 子在 is Sprite2D and (子在 as Sprite2D).texture != null:
					立皮 = String(((子在 as Sprite2D).texture as Texture2D).resource_path).get_file()
					break
	_判(立 != null and 立皮 != "",
			"⑧ 立绘取到了（`equipPane.setOtherImgChar(face)` 那一档；实得 %s）"
					% (立皮 if 立皮 != "" else "null"))

	# ──  四颗钮三态（真鼠标）────────────────────────────────────────────
	for 钮名 in ["密语钮", "交易钮", "加友钮", "组队钮"]:
		var 钮 := 块.get_node(钮名) as TextureButton
		_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "⑨ %s 是手型光标" % 钮名)
		_判(钮.tooltip_text == String(钮提示[钮名]),
				"⑨ %s 提示 = 「%s」（实得「%s」）" % [钮名, 钮提示[钮名], 钮.tooltip_text])
		_判(_皮(钮) == 钮常态, "⑨ %s 起手是常态皮 %s（实得 %s）" % [钮名, 钮常态, _皮(钮)])
		var 色: Color = (钮.get_node("文字") as Label).get_theme_color("font_color")
		_判(absf(色.r - float(钮字色[0])) < 0.01 and absf(色.g - float(钮字色[1])) < 0.01
				and absf(色.b - float(钮字色[2])) < 0.01,
				"⑨ %s 的字色 = #fcf49c（实得 %s）" % [钮名, str(色)])
	聊天 = 假聊天.new() as Node
	聊天.add_to_group("chat_panel")
	root.add_child(聊天)
	var 密 := 块.get_node("密语钮") as TextureButton
	_移开()
	_移到(密)
	_判(_皮(密) == 钮悬停,
			"⑨ 悬停 ⇒ 换 +30 那张皮（实得 %s）—— 走的是换 `texture_normal`，不是 `texture_hover`" % _皮(密))
	_按下(密)
	_判(_皮(密) == 钮常态,
			"⑨ **松手回常态**（实得 %s）—— 原版 `MButton3.as:103-108` 推的是 STATE_UP" % _皮(密))

	# ──  四颗钮各发什么 ─────────────────────────────────────────────────
	_移开()
	(聊天.收到 as Array).clear()
	假后.发的.clear()
	通知.clear()
	_移到(密)
	_判((聊天.收到 as Array).is_empty() and 通知.is_empty() and 假后.发的.is_empty(),
			"⑩ 悬停本身不发任何东西、也不弹提示（实得 包 %s / 通知 %s）" % [str(假后.发的), str(通知)])
	_按下(密)
	_判((聊天.收到 as Array) == ["社交同伴"],
			"⑩ 密　语 ⇒ 聊天框切私聊并带上**对方的名字**（实得 %s；`ChatEvent.CHECK_ONLINE` 不发包）"
					% str(聊天.收到))
	_判((假后.发的 as Array).is_empty(), "⑩ 密语这一发**一个包都不发**（实得 %s）" % str(假后.发的))

	var 交 := _块().get_node("交易钮") as TextureButton
	_移到(交)
	_按下(交)
	_判((假后.发的 as Array) == [["交易", 2]], "⑩ 交　易 ⇒ `119:2:<对方号>`（实得 %s）" % str(假后.发的))
	_判(not _开着(), "⑩ 转发出去之后**本窗关掉**（`CharOtherWindow2.as:80-86`）")

	await _再灌(解)
	假后.是好友 = true
	假后.发的.clear()
	通知.clear()
	var 加 := _块().get_node("加友钮") as TextureButton
	_移到(加)
	_按下(加)
	_判((假后.发的 as Array).is_empty(),
			"⑩ 已经是好友 ⇒ 加好友**不发包**（实得 %s；`CharPointInfoPane.as:194-200`）" % str(假后.发的))
	_判(通知.size() == 1 and String(通知[0]).contains("好友"),
			"⑩ 只弹一句「已经是你的好友」（实得 %s）" % str(通知))
	假后.是好友 = false

	await _再灌(解)
	假后.发的.clear()
	var 组 := _块().get_node("组队钮") as TextureButton
	_移到(组)
	_按下(组)
	_判((假后.发的 as Array) == [["组队", "社交同伴"]],
			"⑩ 组　队 ⇒ `120:4:<名字>`（**按名字不是号**，实得 %s）" % str(假后.发的))
	_判(not _开着(), "⑩ 组队转发后同样关掉本窗（`CharOtherWindow2.as:173-179`）")

	# 对方已在自己队里 ⇒ 那颗钮是灰的（`troopBtn.enabled = !isInTroop(id)`）
	后.set("authoritative_party", {"joined": true, "id": 1, "name": "本方队",
			"leader_id": 1, "members": [{"id": 2, "name": "社交同伴"}], "invites": []})
	await _再灌(解)
	_判((_块().get_node("组队钮") as TextureButton).disabled,
			"⑩ 对方在队里 ⇒ 组队钮 disabled（实得 %s）"
					% str((_块().get_node("组队钮") as TextureButton).disabled))
	后.set("authoritative_party", {"joined": false, "members": [], "invites": []})
	await _再灌(解)
	_判(not (_块().get_node("组队钮") as TextureButton).disabled,
			"⑩ 不在队 ⇒ 组队钮可点（实得 %s）" % str((_块().get_node("组队钮") as TextureButton).disabled))

	# ── ⑪ 尺寸表那一条 ───────────────────────────────────────────────────
	var 表: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(尺寸表路径)) as Dictionary
	# 页名已收成 master 的功能键「人物属性看别人」（`窗口管理.规范页名` 把分支的「他人人物」
	# 映射到这一条），尺寸表里只留一条，不再挂两份同值条目。
	var 规: Dictionary = 表.get("人物属性看别人", {}) as Dictionary
	_判(float(规.get("宽", 0)) == 517.0 and float(规.get("高", 0)) == 440.0,
			"⑪ 外框 517×440 = `BaseCharWindow.as:27` `super(517,440,false)`（实得 %s×%s）"
					% [str(规.get("宽", 0)), str(规.get("高", 0))])
	_判(String(规.get("标题", "")) == "人物属性",
			"⑪ 标题 = `CHARACTOR_TITLE`「人物属性」（实得「%s」）—— 与自己那扇同名" % String(规.get("标题", "")))
	await _再灌(解)
	var 外 := 窗.get("_window") as Control
	_判(外 != null and is_instance_valid(外) and 外.size.x > 0.0,
			"⑪ 窗真的量得出尺寸（实得 %s）" % ("取不到" if 外 == null else str(外.size)))

	# ── ⑫ 没档案不许开一屏 0 ─────────────────────────────────────────────
	await _再灌(解)
	通知.clear()
	(窗 as Node).set("_他人档案", {})
	人物窗口.渲染他人(窗)
	for 帧 in 3:
		await process_frame
	_判(通知.size() == 1, "⑫ 档案是空的 ⇒ 不开页、只通知一句（实得 %d 条：%s）" % [通知.size(), str(通知)])

	# ──  页签闸表：按**对方的等级**筛，不够级根本不建这一枚 ────────────────────
	## 出处 `CharOtherWindow2.as:213-268`；闸值 `JingMaiSource.as:30`=15、`LunHuiYanManager.as:15`=65、
	## `KunChongManager.as:14`=40、`JieYinManager.as:19`=70。
	## ⚠ 与自己那扇**不是一套语义**：自己那扇是"建出来置灰 + 提示 XX 级开放"（`页面开放等级`），
	##   这一扇是"那个人不够级就不建" ⇒ 这里判的是**建没建**，不是灰没灰。
	## 每一行 = `[主分页序号, 对方等级, 期望的页签名按序]`（顺序也是真值：
	## `case 0` 人物→宠物→手里剑→结印、`case 1` 柔拳→昆虫、`case 2` 写轮眼→轮眼）。
	for 试 in [
			[0, 1, ["人物", "宠物"]],
			[0, 14, ["人物", "宠物"]],
			[0, 15, ["人物", "宠物", "手里剑"]],
			[0, 69, ["人物", "宠物", "手里剑"]],
			[0, 70, ["人物", "宠物", "手里剑", "结印"]],
			[1, 1, ["柔拳"]],
			[1, 39, ["柔拳"]],
			[1, 40, ["柔拳", "寄坏之术"]],
			[2, 1, ["写轮眼"]],
			[2, 64, ["写轮眼"]],
			[2, 65, ["写轮眼", "轮回六道"]],
		]:
		var 名表 := 人物窗口.他人子分页表(int(试[0]), int(试[1]))
		var 期望: Array = 试[2]
		_判(名表 == 期望,
				"⑬ 主分页 %d、对方 %d 级 ⇒ 这一排该建 %s（实得 %s）"
						% [试[0], 试[1], str(期望), str(名表)])
	## 10-16 这条从"不许有"翻成"必须有、而且必须在第二枚、没有等级闸"：
	## `CharOtherWindow2.as:222-224` 的 `case 0` push 完「人物」就无条件 push `CHAR_OTHER_TAB_BTN_2`=宠物。
	## ⑬ 那五条 1 级/14 级的期望已经把"宠物恒有"钉住了一半，这里再钉**位置**——
	## 插到第三枚去就等于 `case 0` 的顺序错了，而顺序错了页签文字与页面会整套错位。
	var 页签全表 := 人物窗口.他人子分页表(0, 99)
	_判(页签全表.find("宠物") == 1,
			"⑬b「宠物」必须排在第二枚（原版 `case 0` 顺序 人物→宠物→手里剑→结印，实得 %s）" % str(页签全表))
	_判(not (人物窗口.他人子分页表(1, 99) as Array).has("八门"),
			"⑬ 秘术那一排**永远没有八门**（原版 `case 1` 只 push 柔拳/昆虫；八门只在自己那扇）")
	_判(not (人物窗口.他人子分页表(0, 99) as Array).has("寄坏之术"),
			"⑬ 昆虫只在秘术那一排（原版 `case 0` 没有它）⇒ 跑错排就是页签表串了排")

	# ──  手里剑只读页：数据取**对方那一份档案**，三件交互全灰、一条请求都不接 ──
	## 值全部来自真帧（`数据/界面/查看信息夹具.json` 段 34..37 = 1/1/0/0）⇒
	## 全局等级 = (1−1)×4+1 = 1、上限 = 4×1 = 4 ⇒「1/4级」，与实机 `R2_角色_手里剑.png` 逐字对得上。
	var 高: Dictionary = 解.duplicate(true)
	高["等级"] = 100		## 只为把 ≥15 这道闸抬开；**其余字段仍是真帧解出来的**，不凑数
	(窗 as Node).set("_character_main_tab", 0)
	(窗 as Node).set("_character_sub_tab", _序号(0, "手里剑"))
	await _再灌(高)
	var 页根 := _页()
	var 剑页 := 页根.get_node("人物扩展页/手里剑内容") as Control
	_判(剑页.visible, "⑭ 切到「手里剑」⇒ 这一页显")
	_判(not (页根.get_node("原版人物属性面板") as Control).visible, "⑭ 人物页同时隐掉（两页不同时露）")
	for 项 in [["当前信息/当前使用/值", "基础手里剑"], ["当前信息/当前进度/值", "0/5000"],
			["当前信息/当前等级/值", "1/4级"], ["当前信息/当前触发几率/值", "10%"]]:
		var 实 := String((剑页.get_node(项[0]) as Label).text)
		_判(实 == String(项[1]), "⑭ 「%s」= %s（实得「%s」）—— 帧里 stage/level/master/trigger = 1/1/0/0"
				% [项[0], 项[1], 实])
	## 只读三件：原版 `isMyShouLiJian = false` ⇒ 复选框 + 提升速度 + 突破瓶颈 全 disabled
	var 复 := 剑页.get_node("当前信息/启用复选框") as TextureButton
	var 提 := 剑页.get_node("详情面板/提升速度") as Button
	var 破 := 剑页.get_node("详情面板/突破瓶颈") as Button
	_判(复.disabled and 提.disabled and 破.disabled,
			"⑭ 只读 ⇒ 启用复选框/提升速度/突破瓶颈 三件全灰（实得 %s/%s/%s）"
					% [str(复.disabled), str(提.disabled), str(破.disabled)])
	for 名 in ["启用切换", "提速请求", "突破请求"]:
		var 连: Array = 剑页.get_signal_connection_list(名)
		_判(连.is_empty(),
				"⑭ 只读档页面信号「%s」**一条都没接**（实得 %d 条）⇒ 点它发不出请求"
						% [名, 连.size()])
	假后.发的.clear()
	通知.clear()
	_按下(提)
	for 帧 in 3:
		await process_frame
	_判(假后.发的.is_empty() and 通知.is_empty(),
			"⑭ 真点「提升速度」⇒ 一个包都不发、也不弹提示（实得 包 %s / 通知 %s）"
					% [str(假后.发的), str(通知)])
	_判(String((剑页.get_node("详情面板/攻击能力值") as Label).text).contains("(10%的人物攻击力)"),
			"⑭ 攻击能力那行按**对方的攻击**换算（帧里段 19 = 35）（实得「%s」）"
					% String((剑页.get_node("详情面板/攻击能力值") as Label).text))

	# ── ⑮ 段号 → 档案键（真帧那一份）+ 换算专项（另喂一组**有区分度**的数）────────
	## 为什么两段都要：真帧里段 34..37 恰好是 `1/1/0/0`，**拿它测不出"段序挪一格"**
	## （34↔35 互换照样全对）。所以先用真帧钉"键名与默认值"，再喂一组各不相同的数钉换算式
	## `(阶−1)×4 + 阶内级`（原版 `CharOtherWindow2.as:376`）。
	_判(int(解.get("手里剑阶", 0)) == 1 and int(解.get("手里剑级", 0)) == 1
			and int(解.get("手里剑熟练", -1)) == 0 and int(解.get("手里剑触发", -1)) == 0,
			"⑮ 真帧段 34..37 ⇒ 阶/级/熟练/触发 = 1/1/0/0（实得 %s/%s/%s/%s）"
					% [str(解.get("手里剑阶")), str(解.get("手里剑级")),
							str(解.get("手里剑熟练")), str(解.get("手里剑触发"))])
	_判(int(解.get("柔拳阶", 0)) == 1 and int(解.get("结印阶", 0)) == 1
			and int(解.get("写轮眼阶", 0)) == 1 and int(解.get("轮眼阶", 0)) == 1,
			"⑮ 真帧段 39/44/46/41 四枚阶段全解成 1（柔拳/结印/写轮眼/轮眼）")
	_判(String(解.get("轮眼技能", "?")) == "-",
			"⑮ 段 43 轮眼技能是 `-`（服务端 `:20338` 那格**写死**，不是客户端漏接 ⇒ 他那页技能格恒空）")
	## 段 32 现在**有货**了：`本地服务端夹具.py: seed_peer_pets` 给对端造了三只（全在背包）。
	## 上一版这里钉的是"段 32 = `-`"，因为夹具从没给对端造过宠物 —— 那一版⑲整组跑在空清单上。
	_判(String(解.get("宠物串", "-")) != "-"
			and String(解.get("宠物串", "-")).split("@", false).size() >= 2,
			"⑮ 段 32 至少有两只宠物（实得「%s」）⇒ ⑲ 那组判据才有东西可比"
					% String(解.get("宠物串", "-")).left(30))
	var 换: Dictionary = 解.duplicate(true)
	换["等级"] = 100
	换["手里剑阶"] = 3
	换["手里剑级"] = 2
	换["手里剑熟练"] = 1234
	(窗 as Node).set("_character_sub_tab", _序号(0, "手里剑"))
	await _再灌(换)
	var 页二 := _页()
	var 剑二 := 页二.get_node("人物扩展页/手里剑内容") as Control
	_判(String((剑二.get_node("当前信息/当前使用/值") as Label).text) == "八方手里剑",
			"⑮ 阶=3 ⇒ 名字查表取「八方手里剑」（实得「%s」）"
					% String((剑二.get_node("当前信息/当前使用/值") as Label).text))
	_判(String((剑二.get_node("当前信息/当前进度/值") as Label).text) == "1234/5000",
			"⑮ 熟练度 1234 直接进那行（实得「%s」）"
					% String((剑二.get_node("当前信息/当前进度/值") as Label).text))
	_判(String((剑二.get_node("当前信息/当前等级/值") as Label).text) == "10/12级",
			"⑮ 全局等级 = (3−1)×4+2 = 10、上限 = 4×3 = 12 ⇒「10/12级」（实得「%s」）"
					% String((剑二.get_node("当前信息/当前等级/值") as Label).text))

	# ──  柔拳 / 写轮眼两页：只读路径**真的走一遍**（钮名猜错只会 push_error，不红就不算过）──
	## 原版给别人那扇是 `TongshuWindow(readOnly=true)`（`CharOtherWindow2.as:137`）；
	## 本工程这两页的交互是页面脚本自己在 `_ready()` / 场景 `[connection]` 里接的，
	## 宿主只能按**钮名**把它 disable 掉 ⇒ 名字必须钉死（取 `写轮眼切换_修正版.gd:392` 的
	## `弹窗按钮名`，柔拳同形那颗叫「提升柔拳阶数」）。
	## ⚠ 第四个数是**这一排在第几枚**：血继界限那一排是 `["写轮眼","轮回六道"]`，
	##   原来这里三行全写死 `_character_sub_tab = 0` ⇒ 轮回六道那行其实一直在看写轮眼那页，
	##   「提升轮回六道」从没被关掉却照样绿着（判据看错了对象，10-16 现查）。
	for 页项 in [[1, "柔拳", "提升柔拳阶数", 0], [2, "写轮眼", "提升写轮眼阶数", 0],
			[2, "轮回六道", "提升轮回六道", 1]]:
		(窗 as Node).set("_character_main_tab", int(页项[0]))
		(窗 as Node).set("_character_sub_tab", _序号(int(页项[0]), String(页项[1])))
		await _再灌(高)
		var 页三 := _页()
		var 扩展 := 页三.get_node("人物扩展页") as Control
		var 内容 := 页三.get_node("人物扩展页/%s内容" % String(页项[1])) as Control
		_判(扩展.visible and 内容.visible, "⑯ 主分页 %d ⇒ 切到「%s」这一页" % [页项[0], 页项[1]])
		var 钮 := 内容.find_child(String(页项[2]), true, false) as Button
		_判(钮 != null, "⑯ 找得到那颗「%s」（找不到=钮名改了而 `只读要关的钮` 没跟着改）" % 页项[2])
		if 钮 != null:
			# 写轮眼那族原版是**整枚藏**（`TongshuWindow.as:491-496 exaltBtn.visible = false`），
			# 其余两族是摁住 ⇒ 两种都算"点了没用"。
			_判(钮.disabled or not 钮.visible,
					"⑯ 只读 ⇒「%s」是灰的/藏起来的（实得 disabled=%s visible=%s）"
							% [页项[2], str(钮.disabled), str(钮.visible)])
	# ──  结印只读页：亮他那一阶、四根条按原版插值、那颗钮三档 + 灰、点印一个包都不发 ──
	## 出处 `CharOtherWindow2.as:385-393`（`JieYinPanel(false)` + `resetView(jieYinState, jieYinEatCount)`）
	## 插值与三档真值 `JieYinManager.getJieYinProps:145` / `JieYinPanel.updateProp:321-359`。
	## ⚠ 这里喂的是**合成档案**（阶 7 / 进度 1234，等级 100 只为抬开 ≥70 那道闸）——
	##   真号是 1 级、六项修行全在 1 阶，拿真帧测不出"画的是他的数还是我的数"（同 ⑮ 那条口径）。
	var 结档: Dictionary = 解.duplicate(true)
	结档["等级"] = 100
	结档["结印阶"] = 7
	结档["结印进度"] = 1234
	(窗 as Node).set("_character_main_tab", 0)
	(窗 as Node).set("_character_sub_tab", _序号(0, "结印"))
	await _再灌(结档)
	var 结页 := _页().get_node("人物扩展页/结印内容") as Control
	_判(结页.visible, "⑰ 切到「结印」⇒ 这一页显")
	_判(not (结页.get_node("印式按钮/印1/选中手势框") as Control).visible
			and (结页.get_node("印式按钮/印7/选中手势框") as Control).visible,
			"⑰ 亮的是**印7**（他那一阶），不是印1（`updateButtonState:497` 用的是 `_stage`）")
	_判((结页.get_node("印式按钮/印7/数值容器") as Control).visible
			and not (结页.get_node("印式按钮/印3/数值容器") as Control).visible,
			"⑰ 数值面板只露印7那一份")
	## 参照值**自己在门里从配置表算**（`JieYin.stages.stage6/7` + 上限），不问被测对象要。
	var 全表: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://数据/原版杂项.json")) as Dictionary
	var 阶表: Dictionary = (全表.get("JieYin", {}) as Dictionary).get("stages", {}) as Dictionary
	var 本阶: Dictionary = (阶表.get("stage7", {}) as Dictionary).get("attrs", {}) as Dictionary
	var 上阶: Dictionary = (阶表.get("stage6", {}) as Dictionary).get("attrs", {}) as Dictionary
	var 本阶上限 := int(((阶表.get("stage7", {}) as Dictionary).get("stageUp", {}) as Dictionary).get("needPointCnt", 0))
	_判(本阶上限 == 15000, "⑰ 印7 的熟练度上限（配置 stageUp.needPointCnt）= 15000（实得 %d）" % 本阶上限)
	var 条位 := {"maxhp": ["生命", "生命值", "生命"], "maxmp": ["查克拉", "查克拉值", "查克拉"],
			"atk": ["攻击", "攻击值", "攻击"], "def": ["防御", "防御值", "防御"]}
	var 结容器 := 结页.get_node("印式按钮/印7/数值容器") as Control
	# 四根条是原版 MBar ⇒ 0.5s 补间（`JieYinPanel.updateProp:302` 的 `setData`、§3.243）。
	# 量之前等**墙上时钟**：不等就会量到半路上的值（改前是直写，这条腿当时不用等）。
	await create_timer(0.7).timeout
	for 类型 in 本阶:
		var 记录: Dictionary = 本阶[类型]
		var 名 := String(记录.get("type", ""))
		var 位: Array = 条位.get(名, []) as Array
		if 位.is_empty():
			continue
		var 上限 := int(记录.get("value", 0))
		var 上一 := 0.0
		for 项 in 上阶.values():
			if String((项 as Dictionary).get("type", "")) == 名:
				上一 = float((项 as Dictionary).get("value", 0))
		var 达成 := int(round(上一 + (float(上限) - 上一) * 1234.0 / float(本阶上限)))
		var 条 := 结容器.get_node(String(位[0])) as ProgressBar
		var 标 := 结容器.get_node(String(位[1])) as Label
		_判(is_equal_approx(条.max_value, float(上限)) and is_equal_approx(条.value, float(达成)),
				"⑰ 「%s」条 = %d/%d（实得 %s/%s）" % [位[2], 达成, 上限, str(条.value), str(条.max_value)])
		_判(String(标.text) == "%s %d/%d" % [位[2], 达成, 上限],
				"⑰ 「%s」那行 = 「%s %d/%d」（实得「%s」）" % [位[1], 位[2], 达成, 上限, str(标.text)])
	var 结弹 := 结页.get_node("提升结印阶数弹窗") as Control
	_判(String((结弹.get_node("印7阶段/熟练度进度条/熟练度值数值") as Label).text) == "1234/15000",
			"⑰ 弹窗里露的是印7档、进度 1234（实得「%s」）"
					% String((结弹.get_node("印7阶段/熟练度进度条/熟练度值数值") as Label).text))
	var 结钮 := 结页.get_node("提升结印") as Button
	_判(String(结钮.text) == "结印训练",
			"⑰ 选中==他那一阶 ⇒ 钮文案 = 语言表 `JIEYIN_TISHENGBTN_NAME`「结印训练」（实得「%s」）"
					% String(结钮.text))
	_判(结钮.disabled, "⑰ 只读 ⇒ 那颗钮是灰的（原版 `updateProp:356-359`）")
	## 点一枚**更低的**印：只换显示、文案转「已完成」、并且**一个包都不发**。
	## ⚠ 这里用 `pressed.emit()` 走的是「信号→回调」那一段；**鼠标命中盒那一段本门判不到**
	##   （无头门拿不到真拾取），那条口径记在 `真值/窗口/人物属性_看别人.md §⑬`。
	假后.发的.clear()
	通知.clear()
	(结页.get_node("印式按钮/印3/印式03") as TextureButton).pressed.emit()
	for 帧 in 3:
		await process_frame
	_判((结页.get_node("印式按钮/印3/数值容器") as Control).visible
			and not (结页.get_node("印式按钮/印7/数值容器") as Control).visible,
			"⑰ 点印3 ⇒ 数值面板跟着换到印3（原版 `clickJieYinBtnHandler` 只换显示）")
	_判(String(结钮.text) == "已完成",
			"⑰ 选中(3) < 他的阶(7) ⇒ 钮文案 = `ACTIVITY_COMPELETE_TEXT`「已完成」（实得「%s」）"
					% String(结钮.text))
	_判(结钮.disabled, "⑰ 这一档本来也是 disabled（`:344`）+ 只读再压一层")
	_判(假后.发的.is_empty() and 通知.is_empty(),
			"⑰ 点印**不发请求**（实得 包 %s / 通知 %s）" % [str(假后.发的), str(通知)])
	## 弹窗里那两颗提交钮在只读窗里**一条接线都没有**（`初始化结印页` 在 `只读` 分支就 return 了）。
	## 少这一条，"只读还去 connect 协议"那种改法没人抓 —— 点一下就是替别人练结印。
	for 钮名 in ["开始提升按钮", "自动提升按钮"]:
		var 提钮 := 结弹.get_node_or_null(String(钮名)) as Button
		_判(提钮 != null and 提钮.pressed.get_connections().is_empty(),
				"⑰ 只读 ⇒ 弹窗里「%s」一条都没接（实得 %s 条）"
						% [钮名, "查无此钮" if 提钮 == null else str(提钮.pressed.get_connections().size())])

	# ──  寄坏之术只读页：四格按 slot_index 摆**他的**虫、点格不卸下、属性行按原版汇总 ──
	## 出处 `CharOtherWindow2.as:115-123`（`KunChongPanel(false)` + `updateView(_data.kunChongItems)`）；
	## 不挂 CLICK/MOUSE_UP 是 `KunChongPanel.createCell:241-245` 那个 `_isMyself` 判断。
	## 这一段吃的是**真帧**（`数据/界面/查看信息夹具.json` 段 29 里 −200/−201 那两只虫）。
	## ⚠ 这一段必须从"我身上一只虫都没有"出发（看别人那扇窗的强化目标只认**我自己的**虫）。
	##   本机 `user://玩家数据.json` **可能穿着虫**（2026-10-30 实测：蜻蜓在 −201）——
	##   不先淘空这层，"槽位 0"那条就随存档变红（与假绿 #26 同一条毛病，只是方向相反）。
	##   跑完原样放回。
	var 原我装备: Dictionary = (会话.get("equipped_items") as Dictionary).duplicate(true)
	会话.set("equipped_items", {})
	var 高虫: Dictionary = 解.duplicate(true)
	高虫["等级"] = 100
	(窗 as Node).set("_character_main_tab", 1)
	(窗 as Node).set("_character_sub_tab", 1)
	await _再灌(高虫)
	var 虫页 := _页().get_node("人物扩展页/寄坏之术内容") as Control
	_判(虫页.visible, "⑱ 切到「寄坏之术」⇒ 这一页显")
	var 一格 := 虫页.get_node("虫槽区域/寄坏槽一") as TextureButton
	var 二格 := 虫页.get_node("虫槽区域/寄坏槽二") as TextureButton
	var 三格 := 虫页.get_node("虫槽区域/寄坏槽三") as TextureButton
	var 四格 := 虫页.get_node("虫槽区域/寄坏槽四") as TextureButton
	## 2026-10-30：判据从"原生 tooltip_text"改成**格里真的摆出来那一份**（图标 + 名称）。
	## 原写法在 999cf6d（§3.302 悬停提示）之后就红了：`格子提示框.接线` 按原版把原生
	## tooltip 一律清空让位给 `物品提示框`（`格子提示框.gd:42-43`），tooltip_text 恒为 ""
	## ⇒ 那三条红是**判旧实现**，不是窗坏了。现在同时判"提示框确实接上了"。
	for 项 in [[一格, "虫槽一（段29 的 −200）", "寄坏虫"], [二格, "虫槽二（−201）", "甲虫"]]:
		var 格 := 项[0] as TextureButton
		var 图标 := 格.get_node_or_null("昆虫图标") as TextureRect
		var 名称 := 格.get_node_or_null("昆虫名称") as Label
		_判(图标 != null and 图标.visible and 图标.texture != null,
				"⑱ %s 摆的是**他**那只：图标显且有贴图（实得 visible=%s texture=%s）"
						% [项[1], str(图标.visible) if 图标 != null else "查无", str(图标.texture) if 图标 != null else "查无"])
		_判(名称 != null and 名称.visible and String(名称.text).contains(String(项[2])),
				"⑱ %s 名称含「%s」+强化等级（实得「%s」）"
						% [项[1], 项[2], String(名称.text) if 名称 != null else "查无"])
	var 三图 := 三格.get_node_or_null("昆虫图标") as TextureRect
	var 三名 := 三格.get_node_or_null("昆虫名称") as Label
	_判((三图 == null or not 三图.visible) and (三名 == null or not 三名.visible)
			and (三名 == null or String(三名.text) == ""),
			"⑱ 虫槽三没穿 ⇒ 图标/名称都不显（原版 `hideIcon`）")
	## 悬停提示：原版 `KunChongCell.as:122` 传三参 `MToolTipItem` ⇒ 原生 tooltip 让位给
	## `物品提示框`，接线挂在 `mouse_entered` 上（`格子提示框.gd:39-49`）。
	var 接线数 := 一格.mouse_entered.get_connections().size() if 一格 else 0
	_判(String(一格.tooltip_text) == "" and 接线数 >= 1,
			"⑱ 他的虫格悬停走原版提示框（原生 tooltip 已让位 + mouse_entered 接线 %d 条）" % 接线数)
	## ⚠ **先判接线、再模拟点**：只判"点下去没发包"是不够的 —— 这一页的卸下走
	##   `窗口._unequip`（宿主自己的路），不经过 `假后.发的`，那条红永远不来。
	##   10-16 变异实测就是这么逮到的：删掉只读分支里那句 `continue` 之后门照样全绿。
	for 格 in [一格, 二格, 三格, 四格]:
		## ⚠ 虫格是 **TextureButton**，`as Button` 会得到 null（Godot 4 里两者都从
		##   `BaseButton` 来、但 Button 不是 TextureButton 的父类）⇒ 这里按 Variant 直接取信号。
		_判(格.pressed.get_connections().is_empty(),
				"⑱ 只读 ⇒ 虫格上**一条 pressed 接线都没有**（实得 %d 条）"
						% 格.pressed.get_connections().size())
	假后.发的.clear()
	通知.clear()
	一格.pressed.emit()
	for 帧 in 3:
		await process_frame
	_判(假后.发的.is_empty() and 通知.is_empty(),
			"⑱ 点他的虫格**不发卸下**（原版 `_isMyself=false` 根本不挂 CLICK）—— 实得 包 %s / 通知 %s"
					% [str(假后.发的), str(通知)])
	## 属性行 = 原版 `updatePropDesc`：按 `base_attr_type` 汇总 `base+strength`，名只认
	## `装备提示框.属性名`。参照值在门里**自己从段 29 解一遍**，不写死。
	var 合计 := {}
	for 件 in String(解.get("装备串", "")).split("@", false):
		var 解件: Dictionary = 假后._parse_item_entry(String(件))
		if 解件.is_empty() or not 装备部位.是昆虫槽(int(解件.get("slot_index", 0))):
			continue
		var 类 := int(解件.get("base_attr_type", -1))
		合计[类] = int(合计.get(类, 0)) + int(解件.get("base_attr_value", 0)) \
				+ int(解件.get("strength_value", 0))
	_判(合计.size() >= 2, "⑱ 段 29 里至少解出两种虫属性（实得 %s）⇒ 属性行才有得比" % str(合计))
	var 属性 := 虫页.get_node("属性面板/属性") as RichTextLabel
	var 文 := String(属性.text)
	_判(文.contains("加成属性") and 文.contains("注意：") and 文.contains("四隻昆虫"),
			"⑱ 属性行两段原文都在（语言表 PROP_DESC2 / PROP_DESC，含繁体量词「四隻」）：「%s」" % 文.left(60))
	for 类 in 合计:
		var 名 := String(装备提示框.属性名.get(int(类), "属性%d" % int(类)))
		_判(文.contains("%s +%d" % [名, int(合计[类])]),
				"⑱ 属性行该有「%s +%d」这一条（实得「%s」）" % [名, int(合计[类]), 文.left(80)])
	var 虫弹窗 := 虫页.find_child("昆虫强化弹窗", true, false) as Control
	_判(虫弹窗 != null and int(虫弹窗.get_meta("kunchong_slot", -999)) == 0,
			"⑱ 强化目标取的是**我自己**的虫（上面已清空我的装备 ⇒ 槽位 0），不是他的那只"
					+ "（实得 %s）—— 原版那颗钮点开的是 `KunChongManager` 那一份自己的窗"
					% ("取不到弹窗" if 虫弹窗 == null else str(虫弹窗.get_meta("kunchong_slot", -999))))
	会话.set("equipped_items", 原我装备)
	# ── ⑲ 宠物只读页：吃**真帧段 32**，他有几只就几行、四颗永远灰、一条请求都不接 ──────
	## 出处与整段推导见 `真值/窗口/人物属性_看别人.md §⑳`（页从哪来、两段换算、七条行为差）。
	var 宠档: Dictionary = 解.duplicate(true)
	宠档["等级"] = 100		## 只为把 ≥15 那道闸抬开；其余字段仍是真帧解出来的，不凑数
	(窗 as Node).set("_character_main_tab", 0)
	(窗 as Node).set("_character_sub_tab", _序号(0, "宠物"))
	await _再灌(宠档)
	var 页宠 := _页()
	var 宠页 := 页宠.get_node("人物扩展页/宠物内容") as Control
	_判(宠页 != null and 宠页.visible, "⑲ 切到「宠物」⇒ 这一页显（取不到 = 没进 `扩展子页表` 或改了名）")
	_判(not (页宠.get_node("原版人物属性面板") as Control).visible, "⑲ 人物页同时隐掉（两页不同时露）")
	var 宠串 := String(解.get("宠物串", "-"))
	var 只们: Array = 宠串.split("@", false) if 宠串 != "-" and 宠串 != "" else []
	_判(只们.size() >= 2,
			"⑲ 段 32 得**真有两只以上**（实得 %d 只「%s」）—— 一只测不出换行，没宠的夹具会把这一组跑成空的"
					% [只们.size(), 宠串.left(24)])
	## 逐只**从原文按下标数**出来当参照（`_encode_pet` 的字段序：0=item_id、1=position、
	## 8=unique_id、10=名字、11=等级）。行 key 用的是 8 号那位（原版 `:596` 塞的就是 uniqueId）。
	var 名册: Array = []
	for 只 in 只们:
		var 宠段: PackedStringArray = String(只).split("&", true)
		名册.append({"名": String(宠段[10]), "级": String(宠段[11]), "位": int(宠段[1]),
				"号": str(int(String(宠段[8])))})
	var 列 := 宠页.get_node("列表滚动/宠物列表") as VBoxContainer
	_判(String((宠页.get_node("携带数量") as Label).text)
			== "携带数量%d/%d" % [只们.size(), int(解.get("宠物上限", 10))],
			"⑲「携带数量」= 他有几只 / 段 14 的上限（实得「%s」上限 %s）"
					% [String((宠页.get_node("携带数量") as Label).text), str(解.get("宠物上限", 10))])
	## 只读那一扇的 DataProvider 只 push 他有的那几只（`updateShouLanList:570-604`）⇒
	## **没有「空闲兽栏」空行、也没有「扩展兽栏」行**，那两样是 `PetWindow` 才有的。
	var 露的行 := 0
	for 序 in 列.get_child_count():
		var 条 := 列.get_child(序) as Button
		if 条 != null and 条.visible and String(条.name) != "扩展兽栏":
			露的行 += 1
	_判(露的行 == 只们.size(),
			"⑲ 露出来的行数 = 他有几只（实得 %d 行 vs %d 只）⇒ 多出来的是「空闲兽栏」空行" % [露的行, 只们.size()])
	_判(not (列.get_node("扩展兽栏") as Button).visible, "⑲「扩展兽栏」那一行不许出现（只读没有扩容入口）")
	for 序 in 只们.size():
		var 条 := 列.get_node("宠物条目_%d" % 序) as Button
		_判(String((条.get_node("名字") as Label).text).contains(String(名册[序]["名"])),
				"⑲ 第 %d 行摆的是**他**那只「%s」（实得「%s」）"
						% [序 + 1, String(名册[序]["名"]), String((条.get_node("名字") as Label).text)])
		_判(String((条.get_node("等级") as Label).text) == String(名册[序]["级"]),
				"⑲ 第 %d 行等级 = 段 32 第 %d 只的第 11 位（实得「%s」要「%s」）"
						% [序 + 1, 序 + 1, String((条.get_node("等级") as Label).text), String(名册[序]["级"])])
	## 行首那个状态图标：`PetPosition` 0=附身、125=出战（服务端那份枚举），别的值不亮。
	## ⚠ 夹具现在给对端的三只**全在背包**（`实亮 == 该亮 == 0`）—— 给一只出战的会当场把服务端
	##   那条连接打死（`_equipped_attribute_bonus` 遍历 inventory 时被改大小，见 `真值 §⑳`），
	##   改服务端要点头 ⇒ 这里只钉"亮的位置对"，附身/出战那一档由自己那扇的门覆盖。
	var 该亮 := 0
	var 实亮 := 0
	for 序 in 只们.size():
		if int(名册[序]["位"]) == 0 or int(名册[序]["位"]) == 125:
			该亮 += 1
		if (列.get_node("宠物条目_%d" % 序).get_node("状态") as Control).visible:
			实亮 += 1
	_判(实亮 == 该亮,
			"⑲ 行首状态图标只在附身/出战那几只上亮（实得 %d 个，按段 32 的 position 该 %d 个）" % [实亮, 该亮])
	## ⚠ 上面那条在**当前夹具**里是 0 比 0（三只全背包）⇒ 只证了"不该亮的不亮"，
	## 亮的那一档整个没跑过。原版这一档是真有的：`SimplePetWindow.as:580-590` 把
	## `position` 0→`STATUS_SUMMON`、125→`STATUS_ATTACK`、别的→`STATUS_NORMAL` 塞进行数据。
	## ⇒ 用**真帧解出来的那份清单**只翻 `attached`/`deployed` 两个布尔（= 把 position 挪到另一档，
	## 协议原文一个字不改），直接喂 `渲染进` 把正亮那一档跑出来。
	var 真清单: Array = (人物窗口.他人宠物(窗, 解).get("宠物清单", []) as Array).duplicate(true)
	_判(真清单.size() == 只们.size() and 只们.size() >= 3,
			"⑲ 探针用的那份就是真帧解出来的（%d 只 vs %d 只）—— 数量对不上别往下测"
			% [真清单.size(), 只们.size()])
	## 两档各测一行：**出战打在没选中的第 2 行**（证明"只有那一行亮"不是跟着选中条走的）、
	## **附身打在当前选中的那一行**（第 1 行）—— 因为"文案换不换「回收」"读的是**选中那一只**，
	## 附身不落在选中行上就永远测不出（10-16 深夜变异 `宠己` 第一次跑就是全绿，栽在这一条上）。
	for 探组 in [["出战", 1], ["附身", 0]]:
		var 档名 := str(探组[0])
		var 探针行 := int(探组[1])
		var 探针: Array = 真清单.duplicate(true)
		for 序 in 探针.size():
			(探针[序] as Dictionary)["attached"] = (档名 == "附身" and 序 == 探针行)
			(探针[序] as Dictionary)["deployed"] = (档名 == "出战" and 序 == 探针行)
		宠物页脚本.渲染进(窗, 宠页, {"宠物清单": 探针,
				"宠物上限": int(解.get("宠物上限", 10)), "归属号": int(解.get("cid", -1))})
		for 帧 in 3:
			await process_frame
		var 亮行: Array = []
		var 张图 := ""
		for 序 in 只们.size():
			var 图 := (列.get_node("宠物条目_%d" % 序) as Button).get_node("状态") as TextureRect
			if 图.visible:
				亮行.append(序)
				张图 = "" if 图.texture == null else String(图.texture.resource_path)
		var 该哪张 := 宠物页脚本.状态战斗 if 档名 == "出战" else 宠物页脚本.状态附
		_判(亮行 == [探针行],
				"⑲ 他的第 %d 只标成「%s」⇒ **只有那一行**亮状态图标（实得 %s）"
				% [探针行 + 1, 档名, str(亮行)])
		_判(亮行.size() == 1 and 张图 == 该哪张,
				"⑲「%s」那行亮的是 %s（实得「%s」）" % [档名, 该哪张.get_file(), 张图.get_file()])
		## 他正附身着也不许把钮文案换成「回收」、也不许解禁（`:485` 建时就灰，全文没有第二处 enabled；
		## 换「回收」是 `PetWindow.updatePetStatus` 那一段，只读那扇根本没有它）。
		if 档名 == "附身":
			var 附钮 := 宠页.get_node("附身") as Button
			var 出钮 := 宠页.get_node("出战") as Button
			_判(String(附钮.text) == "附身" and String(出钮.text) == "出战",
					"⑲ 他就算**选中那一只**正附身着：两颗钮仍写「附身」「出战」（实得「%s」「%s」）"
					% [String(附钮.text), String(出钮.text)])
			_判(附钮.disabled and 出钮.disabled,
					"⑲ 同上，两颗钮也不许跟着解禁（灰=%s / %s）"
					% [str(附钮.disabled), str(出钮.disabled)])
	## 还原**不要再灌一帧**：`_再灌` 会把这一页重建，手里那个 `宠页`/`列` 当场变成
	## 已释放实例（10-16 就这么把门跑崩过一次：`get_node on a previously freed instance`）。
	## 直接拿没翻过的那份真清单再渲染一次，节点句柄全程有效。
	宠物页脚本.渲染进(窗, 宠页, {"宠物清单": 真清单,
			"宠物上限": int(解.get("宠物上限", 10)), "归属号": int(解.get("cid", -1))})
	for 帧 in 3:
		await process_frame
	for 灭行 in [0, 1, 2]:
		_判(not (列.get_node("宠物条目_%d/状态" % 灭行) as TextureRect).visible,
				"⑲ 探针撤掉后第 %d 行的图标灭掉（还原不干净会污染后面那几组）" % (灭行 + 1))
	## 行 key 必须是 `unique_id` 而不是 item_id（原版 `updateShouLanList:596` 往行数据里塞的就是
	## `"id":_loc3_.uniqueId`）：他只要有**两隻同种**，用 item_id 当 key 就两行同时亮选中条、
	## 点第二行画的还是第一只。真帧里三只不同种 ⇒ 造一份"把第一只复制一遍、unique_id 换一个"的
	## 清单喂进去（其余字段仍是真帧解出来的），这一档才测得出来。
	var 同种: Array = 真清单.duplicate(true)
	var 复制: Dictionary = (真清单[0] as Dictionary).duplicate(true)
	复制["unique_id"] = 990001
	复制["level"] = 77
	同种.insert(1, 复制)
	宠物页脚本.渲染进(窗, 宠页, {"宠物清单": 同种,
			"宠物上限": int(解.get("宠物上限", 10)), "归属号": int(解.get("cid", -1))})
	for 帧 in 3:
		await process_frame
	_判((列.get_node("宠物条目_0/选中条") as Control).visible
			and not (列.get_node("宠物条目_1/选中条") as Control).visible,
			("⑲ 同种两隻 ⇒ **只有当前那一只**亮选中条（实得 第 1 行 %s / 第 2 行 %s；"
			+ "两行一起亮就是 key 用了 item_id）")
			% [str((列.get_node("宠物条目_0/选中条") as Control).visible),
				str((列.get_node("宠物条目_1/选中条") as Control).visible)])
	_判(String((宠页.get_node("等级") as Label).text) == String(名册[0]["级"]),
			"⑲ 右侧画的还是**选中那一只**的等级（实得「%s」要「%s」；画成 77 就是撞 key 查到副本了）"
			% [String((宠页.get_node("等级") as Label).text), String(名册[0]["级"])])
	宠物页脚本.渲染进(窗, 宠页, {"宠物清单": 真清单,
			"宠物上限": int(解.get("宠物上限", 10)), "归属号": int(解.get("cid", -1))})
	for 帧 in 3:
		await process_frame
	## 到这儿同一批节点被连着渲染了 4 轮（探针不改 cid ⇒ 不重建整页），
	## 这正是"每次渲染不先断开就一路叠加"那条路：每行应该**还是只挂一条** pressed。
	## ⚠ 不能在"点行"之后测 —— 点行走 `_render_page` 会把这一页整个重建，节点是新的，
	##   恒为 1 条 = 假绿（10-16 现查：`get_node on a previously freed instance` 就是这么撞出来的）。
	for 号 in [0, 1, 2]:
		var 条数 := (列.get_node("宠物条目_%d" % 号) as Button).pressed.get_connections().size()
		_判(条数 == 1, "⑲ 渲染 4 轮后第 %d 行仍只挂**一条** pressed（实得 %d 条 = 没先断开）"
				% [号, 条数])
	_判(not (宠页.get_node("属性底板/空提示") as Control).visible, "⑲ 有宠 ⇒ 那段「附身通灵兽作用」不露")
	_判(not (宠页.get_node("改名") as Control).visible, "⑲「改名」这一枚只读那扇没有（`SimplePetWindow` 根本不建 `_labChangeName`）")
	_判(not (宠页.get_node("内容底") as Panel).visible,
			"⑲ 整页大底板不露（背景是宿主窗那块 422×366，不是这页再铺一层）")
	## 摆位两段换算：`petPane(-5,-27)` + 「场景 = pane − (3,30)」⇒ 页根落在 (−2,+3)。
	## 抽两件对上的：`列表底板` pane (8,32) → (3,5)、`附身` pane (214,182) → (209,155)。
	_判(宠页.position == Vector2(-2.0, 3.0), "⑲ 这一页在面板里的摆位 (−2,+3)（实得 %s）" % str(宠页.position))
	_判((宠页.get_node("列表底板") as Control).position + 宠页.position == Vector2(3.0, 5.0),
			"⑲ 列表底板落在 (3,5)（= `SimplePetWindow.as:217-225` 的 pane (8,32) 减 (5,27)）")
	_判((宠页.get_node("附身") as Control).position + 宠页.position == Vector2(209.0, 155.0),
			"⑲ 附身那颗落在 (209,155)（`:492-495` 的 pane x=214、间隔 12，不是 `PetWindow` 的 200/20）")
	## 四颗钮：**永远灰 + 一条都没接**（`:485` 建时就 `enabled=false`，全文件没有第二处 `enabled`；
	## `:486-495` 只有 addChild）⇒ 他第一只正附身着，钮上写的也还是「附身」而不是「回收」。
	for 钮名 in ["附身", "驯养", "出战", "放生"]:
		var 钮 := 宠页.get_node(钮名) as Button
		_判(钮.disabled, "⑲「%s」在只读那扇永远是灰的（选到宠也不解禁）" % 钮名)
		_判(钮.pressed.get_connections().is_empty(),
				"⑲「%s」一条 pressed 都没接（实得 %d 条）" % [钮名, 钮.pressed.get_connections().size()])
	for 钮名 in ["附身", "出战"]:
		_判(String((宠页.get_node(钮名) as Button).text) == 钮名,
				"⑲「%s」的文案不换「回收」（只读那扇构造期写死一次，`PetWindow.updatePetStatus` 那一段没有）"
						% 钮名)
	## 五个装备格：不是落点、点也不卸（`格子归属` 留空 = `_can_drop_data` 直接挡，交易窗同一口径）。
	## ⚠ 摆位参照**从 `SimplePetWindow.as:241-259` 的字面量现场算**，不读 `只读摆位` 那张表
	## ——那张表把 _2/_3/_5 写过串（编号≠屏幕位：`equip1..5` 绑的是 PetA/D/C/B/E = 1/4/3/2/5），
	## 拿它自己当参照就永远测不出。屏位 = pane − (5,27)。
	var 面板 := Vector2(8.0 + 177.0 + 3.0, 32.0)		# `:241-242` x=leftUpSkin.x+width+3、y=leftUpSkin.y
	var 格宽 := 40.0								# `SimpleItemCell` 天然 40×40
	var 期望屏位 := {
		1: 面板 + Vector2(8.0, 10.0),				# `:251-252` equip1（左上）
		4: 面板 + Vector2(8.0, 10.0 + 格宽 + 4.0),	# `:253-254` equip2（左下）
		3: 面板 + Vector2(8.0 + 180.0, 10.0),		# `:255-256` equip3（右上）
		2: 面板 + Vector2(8.0 + 180.0, 10.0 + 格宽 + 4.0),	# `:257-258` equip4（右下）
		5: 面板 + Vector2(8.0 + 格宽 + 5.0, 10.0 + 格宽 + 4.0),	# `:259` equip5（中下）
	}
	for 号 in [1, 2, 3, 4, 5]:
		var 格 := 宠页.get_node("装备槽_%d" % 号) as Button
		var 落 := 格.position + 宠页.position
		var 该落: Vector2 = (期望屏位[号] as Vector2) - Vector2(5.0, 27.0)
		_判(落 == 该落, "⑲ 装备格 %d（部位号，不是第几格）落在 %s（实得 %s）"
				% [号, str(该落), str(落)])
		_判(String(格.get("格子归属")) == "", "⑲ 宠物装备槽 %d 的归属留空（他的格不是落点）" % 号)
		_判(格.pressed.get_connections().is_empty(), "⑲ 宠物装备槽 %d 没接卸下（实得 %d 条）"
				% [号, 格.pressed.get_connections().size()])
	假后.发的.clear()
	通知.clear()
	for 钮名 in ["附身", "驯养", "出战", "放生"]:
		(宠页.get_node(钮名) as Button).pressed.emit()
	for 格号 in [1, 2, 3, 4, 5]:
		(宠页.get_node("装备槽_%d" % 格号) as Button).pressed.emit()
	for 帧 in 3:
		await process_frame
	_判(假后.发的.is_empty() and 通知.is_empty(),
			"⑲ 真点那四颗 + 五个格 ⇒ 一个包都不发、也不弹提示（实得 包 %s / 通知 %s）"
					% [str(假后.发的), str(通知)])
	## 点他列表第二行：原版唯一挂着的那条监听就是列表 ITEM_CLICK（`SimplePetWindow.as:143`）
	## ⇒ **换显示是允许的**，只是不许发请求。参照 = 段 32 第二只的名字。
	if 只们.size() >= 2:
		var 我的选前 := String(窗.get("_selected_pet_id"))
		(列.get_node("宠物条目_1") as Button).pressed.emit()
		for 帧 in 3:
			await process_frame
		var 宠页二 := (_页().get_node("人物扩展页/宠物内容") as Control)
		_判(String((宠页二.get_node("名称") as Label).text).contains(String(名册[1]["名"])),
				"⑲ 点第二行 ⇒ 右侧换成他第二只「%s」（实得「%s」）"
						% [String(名册[1]["名"]), String((宠页二.get_node("名称") as Label).text)])
		_判(假后.发的.is_empty() and 通知.is_empty(),
				"⑲ 点行只换显示，**一个包都不发**（实得 包 %s / 通知 %s）" % [str(假后.发的), str(通知)])
		## 他的游标与我那扇的游标必须是**两个字段**：原版两扇各带一个
		## （`PetWindow.selectedPet` / `SimplePetWindow._curPet`）。改之前只读页点行是写在
		## `_selected_pet_id` 上的 —— 两扇今天是不同窗口实例（`窗口管理` 按页名分实例），
		## 所以**没有**实测到的用户可见症状，属状态归属修正；这条钉的是"只读页不许改我的字段"这个形状。
		_判(String(窗.get("_selected_pet_id")) == 我的选前,
				"⑲ 点他的行**不许**顶掉我自己那扇的选宠号（实得「%s」要「%s」）"
				% [String(窗.get("_selected_pet_id")), 我的选前])
		_判(String(窗.get("_他人宠物选中号")) == String(名册[1]["号"]),
				"⑲ 他的游标存在 `_他人宠物选中号`（= 段 32 第 2 只的第 8 位 unique_id）"
				+ "（实得「%s」要「%s」）" % [String(窗.get("_他人宠物选中号")), String(名册[1]["号"])])
		## ⚠ 换一个人看 ⇒ 必须回到**第一只**（`setPetData:549-556` 每喂一份新档案就 `_curPet = 0`）。
		##   这里**只改 cid、宠物串一个字不动** —— 夹具给两个号造的宠物 `unique_id` 是同一段
		##   （`910_000+i` / `920_000+i`），光比 id 判不出换人，撞号还能回第一只才算钉住那条。
		var 换人档: Dictionary = 解.duplicate(true)
		换人档["等级"] = 100
		换人档["cid"] = int(解.get("cid", 2)) + 500
		(假后.map_players as Dictionary)[int(换人档["cid"])] = {"gender": 0, "name": "另一个同伴"}
		await _再灌(换人档)
		var 宠页三 := (_页().get_node("人物扩展页/宠物内容") as Control)
		_判(String((宠页三.get_node("名称") as Label).text).contains(String(名册[0]["名"])),
				"⑲ 换一个人看 ⇒ 选中回到他的第一只（实得「%s」要「%s」）"
						% [String((宠页三.get_node("名称") as Label).text), String(名册[0]["名"])])

	(窗 as Node).set("_character_main_tab", 0)
	(窗 as Node).set("_character_sub_tab", _序号(0, "人物"))
	await _再灌(解)
	# ──  角色页那四件"画"不许串到别的子页（10-16 深夜：用户红框圈出来那张淡淡的角色背景）──
	## 原版事实（`python 开发工具/读符号时间轴.py --符号 987`，987 = `CharPaneF` = 角色页那个元件）：
	## `d1 #942 CharWindowMPane_background`、`d3 #495 @(8,59)`、`d5 #495 @(8,317)`、`d239 #94 EquipPaneF @(8,64)`
	## 全在**面板自己**的时间轴上，而 `BaseCharWindow.createPanel:104-131` 每次换页都
	## `_content.removeChild(_currentPanel)` ⇒ 原版切页时这些画跟着整块消失，只有 `_contentBg`
	## （`BaseCharWindow.as:33-38`，窗口级）留下。移植时这四件挂在窗口级 `内容背景` 下面 ⇒
	## 半透明的扩展子页一压上去就透出来（用户看到的"淡淡的角色背景"）。
	var 页画 := ["角色背景", "角色背景框", "分隔线1", "分隔线2"]
	var 画页根 := _页()
	var 人物页 := 画页根.get_node("原版人物属性面板") as Control
	_判(人物页.visible, "⑳ 人物页这一页该是显的（不显的话下面那四条全是空跑）")
	for 件名 in 页画:
		## 从**页根往下找**（不是从面板里取）：挂错地方时也要能报出它真正在哪，
		## 否则 `get_node_or_null` 取不到只说"查无"，看日志的人分不清"删了"还是"挂错了"。
		var 件甲: Node = 画页根.find_child(件名, true, false)
		_判(件甲 != null and String(件甲.get_parent().name) == "原版人物属性面板"
				and (件甲 as Control).is_visible_in_tree(),
				"⑳ **人物页**上「%s」该看得见、且该挂在角色页节点里（实得 父=%s 在树里显=%s）"
				% [件名, "查无" if 件甲 == null else String(件甲.get_parent().name),
					str(件甲 != null and (件甲 as Control).is_visible_in_tree())])
	(窗 as Node).set("_character_sub_tab", _序号(0, "宠物"))
	await _再灌(宠档)
	var 页根二 := _页()
	var 人物页二 := 页根二.get_node("原版人物属性面板") as Control
	_判(not 人物页二.visible, "⑳ 切到「宠物」⇒ 人物页整块隐掉（这条不成立则下面四条是空跑）")
	for 件名 in 页画:
		var 件乙: Node = 页根二.find_child(件名, true, false)
		_判(件乙 != null and String(件乙.get_parent().name) == "原版人物属性面板"
				and not (件乙 as Control).is_visible_in_tree(),
				("⑳ 切到「宠物」⇒「%s」**不许**还留在屏幕上（实得 父=%s 在树里显=%s）—— "
				+ "挂回窗口级 `内容背景` 就是那张串页的淡背景")
				% [件名, "查无" if 件乙 == null else String(件乙.get_parent().name),
					str(件乙 != null and (件乙 as Control).is_visible_in_tree())])

	## ㉑ 分隔线**画出来**多宽（10-16 交易页那条实机报障的同类，这里一起钉住）。
	## ⚠ 判 `size` 不判 `offset_*`：`TextureRect` 缺省 `expand_mode = EXPAND_NONE` 时
	## 最小尺寸 = 贴图天然尺寸（横向分隔线.png 是 **252×2**）⇒ 场景写 173、引擎给 252，
	## 线会越出它该在的那块面板，而按 offsets 判的逐件门一条都不红。
	var 画页二 := _页()
	var 条线: Node = 画页二.find_child("条下分隔线", true, false)
	_判(条线 != null, "㉑ 「条下分隔线」找得到（查无 = 那条被删了或改名了）")
	if 条线 != null:
		_判((条线 as Control).size == Vector2(173, 2),
				"㉑ 「条下分隔线」**画出来** 173×2（实得 %s —— 被 252 宽的贴图顶大就是越界）"
						% str((条线 as Control).size))
		_判((条线 as Control).expand_mode == TextureRect.EXPAND_IGNORE_SIZE,
				"㉑ 「条下分隔线」必须 EXPAND_IGNORE_SIZE（实得 %s）" % (条线 as Control).expand_mode)

	跑完了 = true
	print("他人人物窗门：通过 %d，红 %d" % [通过, 失败])
