extends SceneTree
## 目标信息条（原版 `DetailsWindow`）离线门：逐件矩形 + 层序 + 三档显隐 + 条上文案与比例 +
## 六颗钮各发哪一发请求 + 菜单三档行表 + 点头像取消选中。
##
## 参照值**全部从 `真值/窗口/目标信息条.md` 的表手抄**（每条带 AS3/XML 出处），
## 不从被测场景反查 —— 拿被测对象当参照 = 自证。
##
## 跑法：`"godot" --path . --headless --script res://测试/目标信息条回归测试.gd`

const 场景路径 := "res://场景/界面/头像面板.tscn"
const 皮目录 := "res://素材/界面/原版窗口/目标信息/"
## ⑨ 层序判据要用到的两个数（都是**手抄真值**，不从被测对象反查）：
## `窗口管理.gd:32` `const HUD基 := 110`、`窗口管理.gd:259` `窗.layer = HUD基 + i + 1`；
## 模态确认弹层 = `场景/界面/窗口管理.tscn` 里 `模态确认弹层` 的 `layer = 400`。
const 窗口带基 := 110
const 模态层 := 400
const 尺寸表路径 := "res://数据/界面/窗口尺寸.json"
## ⑩ 玩家头顶箭头那条判据要实例化的脚本（远程玩家/本地玩家同一个）
const 玩家脚本 := "res://脚本/角色/玩家.gd"

## §① 层栈：件名 → [x, y, 宽, 高]，Flash 局部坐标（条的左上角为原点）
const 逐件 := {
	"头像框": [0.0, 0.0, 62.0, 62.0],		# iconMc 号 232，时间轴 depth 0
	"头像": [0.0, 0.0, 62.0, 62.0],			# setPic():379-381 PortraitHead(true,62,62,TYPE_CHAR)
	"底板": [38.0, 0.0, 194.0, 21.0],		# 号 235，depth 1
	"名字": [62.0, 4.0, 120.0, 16.0],		# 号 256 @(61.95,4)；盒 = bounds 2360×280 twip ÷20
	"等级": [182.0, 4.0, 46.0, 16.0],		# 号 257 @(181.95,4)；Xmax 880 twip = 44px
	"血条底": [62.0, 21.0, 113.0, 12.0],	# :114-119 x=62 y=19 + 件内 barBg.y=2；天然 135×12 压到 113
	"血条": [65.0, 23.0, 107.0, 7.0],		# MBar.setBarStartXToZero():97-98 ⇒ bar.x=(135−129)>>1=3；
											# set width():81 ⇒ 113−6=107；件内 bar.y=4
	"血字": [62.0, 22.0, 113.0, 18.0],		# tf 件内 y=3；MBar.as:58 钉高 18；width setter 给到 113
	"蓝条底": [62.0, 33.0, 113.0, 12.0],	# :120-125 y=31
	"蓝条": [65.0, 35.0, 107.0, 7.0],
	"蓝字": [62.0, 34.0, 113.0, 18.0],
	"钮_查看资料": [40.0, 43.0, 33.0, 18.0],	# 号 239 depth 2
	"钮_交易": [73.0, 42.0, 17.0, 18.0],		# 号 243 depth 3
	"钮_加好友": [90.0, 42.0, 17.0, 18.0],	# 号 247 depth 4
	"钮_组队": [107.0, 42.0, 17.0, 18.0],	# 号 251 depth 5
	"钮_私聊": [124.0, 42.0, 17.0, 18.0],	# 号 255 depth 6
	"钮_菜单": [141.0, 42.0, 34.0, 18.0],	# 构造函数 :97-100，皮 = UISwf_Text #21
}
## 弹窗挂在 `(menuBtn.x, menuBtn.y + menuBtn.height)` = (141, 60)（`_menu():322-323`）
const 菜单位 := [141.0, 60.0]
## `MBar` 的可见条宽 = `barBg.width(113) − 6`（`setBarStartXToZero():97-98` 把 bar.x 钉在 3）
## ⇒ 填充图的天然宽与控件的运行期宽**都必须是 107**。
const 条真值宽 := 107
## §① 层序 = Flash 的 addChild 顺序（同 z 只能靠树序，`CanvasItem` 没有 sort_offset）
const 层序 := ["头像框", "头像", "底板", "名字", "等级",
		"血条底", "血条", "血字", "蓝条底", "蓝条", "蓝字",
		"钮_查看资料", "钮_交易", "钮_加好友", "钮_组队", "钮_私聊", "钮_菜单", "目标菜单"]
## 六颗钮：基名皮 / 提示（`init():113` btnTips 的语言值）/ 点下去该发的那一发
const 钮表 := {
	"钮_查看资料": ["钮_查看资料.png", "查看信息", "查资料"],
	"钮_交易": ["钮_交易.png", "邀请交易", "交易"],
	"钮_加好友": ["钮_加好友.png", "加为好友", "好友"],
	"钮_组队": ["钮_组队.png", "邀请组队", "组队"],
	"钮_私聊": ["钮_私聊.png", "私聊", "私聊"],
	"钮_菜单": ["钮_菜单.png", "补充菜单", "菜单"],
}

var 通过 := 0
var 失败 := 0
var 假: Node
var 跑完了 := false

func _判(对: bool, 说明: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 说明)

func _initialize() -> void:
	## ⚠ 必须 `await` 之后再 `exit`：`_跑()` 是协程，不接住它的话主循环一路空转、
	## 门永远不退出（10-14 在线门那次挂死到超时就是同一个形状）。
	await _跑()
	## ⚠ 兜底：协程中途报错时最后那句汇总根本不会打印，`失败` 还是 0 ⇒ 退出码 0 = **假绿**。
	## 所以"没跑到最后一行"本身就是一条红。
	if not 跑完了:
		失败 += 1
		print("红：门自己没跑完（协程中途报错），汇总行没打出来")
	quit(1 if 失败 > 0 else 0)

func _矩形(件: Control) -> Array:
	return [件.offset_left, 件.offset_top,
			件.offset_right - 件.offset_left, 件.offset_bottom - 件.offset_top]

func _近(实: Array, 参: Array) -> bool:
	if 实.size() != 4 or 参.size() != 4:
		return false
	for i in 4:
		if absf(float(实[i]) - float(参[i])) > 0.51:
			return false
	return true

func _玩家信息(号: int, 名: String, 等级: int, 血: int, 上限: int) -> Dictionary:
	return {"name": 名, "level_text": "LV.%d" % 等级, "hp": 血, "max_hp": 上限,
			"mp": 260, "max_mp": 260, "type": 1, "char_id": 号, "level": 等级,
			## 脸：生产里由 `地图实体._remote_player_selection_info` 从出场帧带进来（赠花窗那具
			## 活的立绘只认它）。这里给一个**非 1** 的值，好把"面板真的把 face 交出去了"量出来。
			"face": 5}

## 找菜单里那一行并**走它自己的 pressed**（`物品菜单.gd:229` 里 pressed → 选择了.emit → 我们的分发）。
## 直接 `emit_signal("选择了")` 会跳过组件自己那道连接，等于没测。
func _点行(菜单: Control, 文: String) -> bool:
	for i in 12:
		var 钮 := 菜单.get_node_or_null("项_%d" % i) as Button
		if 钮 != null and 钮.visible and 钮.text == 文:
			钮.emit_signal("pressed")
			return true
	return false

func _行表(菜单: Control) -> Array:
	var 出: Array = []
	for i in 12:
		var 钮 := 菜单.get_node_or_null("项_%d" % i) as Button
		if 钮 == null or not 钮.visible:
			continue
		出.append(钮.text)
	return 出

func _跑() -> void:
	print("目标信息条离线门开始")
	await process_frame
	var 真后端 := root.get_node_or_null("BackendConnection")
	if 真后端 != null:
		root.remove_child(真后端)
	假 = 假后端.new()
	假.name = "BackendConnection"
	root.add_child(假)
	## 「私聊」那颗钮走的是"找到聊天栏、把对象填进去"这一条（原版 `ChatEvent.CHECK_ONLINE` 不发包）。
	## 这里挂一个**同组同名同签名**的替身，让那条路真的走到"有人接"，而不是退化成一句提示。
	var 聊 := 假聊天.new()
	聊.name = "假聊天栏"
	聊.记 = 假
	root.add_child(聊)
	var 件 := (load(场景路径) as PackedScene).instantiate()
	root.add_child(件)
	## 「双修」那一行的落点在**地图**（见 `假地图`）：面板 `get_parent().get_node_or_null("LifeRoot")`。
	## 没有它时面板只会说"需要先进图"，什么都量不到 ⇒ 挂一个同名同签名的替身。
	## 它**没有** `取消选中`，所以 §⑪ 点头像那条走的是原来的 session 兜底，行为不变。
	var 地图 := 假地图.new()
	地图.name = "LifeRoot"
	root.add_child(地图)
	## 「赠花」那一行的**另一半交接**落在 `窗口管理`（面板 `get_parent().get_node_or_null("窗口管理")`，
	## 生产里两者都是地图场景里 map root 的 CanvasLayer 兄弟 ⇒ 这里同样摆成 root 的孩子）。
	var 管 := 假窗口管理.new()
	管.name = "窗口管理"
	root.add_child(管)
	for i in 4:
		await process_frame
	var 条 := 件.get_node_or_null("头像区域/选中人物信息") as Control
	_判(条 != null, "条本体取到了（场景没被改坏）")
	if 条 == null:
		跑完了 = true
		print("目标信息条离线门：通过 %d，红 %d" % [通过, 失败])
		return

	# ① 逐件矩形
	for 名 in 逐件:
		var 子 := 条.get_node_or_null(名) as Control
		_判(子 != null, "逐件：%s 在" % 名)
		if 子 == null:
			continue
		_判(_近(_矩形(子), 逐件[名]),
				"%s 矩形 = (%s)，实得 (%s)" % [名, 逐件[名], _矩形(子)])
	var 菜单 := 条.get_node_or_null("目标菜单") as Control
	_判(菜单 != null and absf(菜单.position.x - 菜单位[0]) < 0.51
			and absf(菜单.position.y - 菜单位[1]) < 0.51,
			"弹窗挂在钮的正下方 (%s)，实得 (%.1f, %.1f)" % [菜单位,
			菜单.position.x if 菜单 != null else -9.0, 菜单.position.y if 菜单 != null else -9.0])

	# ② 层序（树序 == addChild 序）
	var 实序: Array[String] = []
	for 子 in 条.get_children():
		实序.append(String(子.name))
	var 歪: Array = []
	for i in mini(实序.size(), 层序.size()):
		if 实序[i] != String(层序[i]):
			歪.append("%d:%s≠%s" % [i, 实序[i], 层序[i]])
	_判(实序.size() == 层序.size() and 歪.is_empty(),
			"层序与 addChild 顺序一致（底板盖圆框、条盖底板、钮最后）；错位：%s，条数 %d/%d" % [
			歪, 实序.size(), 层序.size()])

	# ③ 条在屏幕上 = 顶部水平居中（positionWindow():184-185：x=(STAGE_WIDTH−width)/2、y=0）
	# ⚠ 无头跑起来的窗口宽不等于工程设置那 960，所以判的是**关系**（条心 == 父宽一半、
	#   屏幕顶 == 0），不是拿一个绝对像素硬判。
	var 父 := 条.get_parent() as Control
	_判(absf(条.position.x + 116.0 - 父.size.x / 2.0) <= 1.0,
			"条水平居中：条心 x=%.1f，父宽一半 %.1f" % [条.position.x + 116.0, 父.size.x / 2.0])
	_判(absf(条.get_global_rect().position.y) <= 1.0,
			"条贴在屏幕最上沿 y=0（原版 positionWindow 那一档），实得 %.1f"
			% 条.get_global_rect().position.y)

	# ⚠⚠ **元判据必须放在最前面**：控制器只要 parse 失败，`_接目标钮()` 就一行没跑，
	# 于是"提示没设、四态没接、钮还隐着"这一大片会**伪装成 0 条红**（10-15 真栽过一次，
	# 那次退出码还是 0）。所以先钉"钮真的被控制器接上了"，后面那批才有意义。
	_判((条.get_node("钮_查看资料") as TextureButton).tooltip_text != "",
			"元判据：控制器确实跑过 `_接目标钮()`（钮的提示非空 ⇒ 脚本没 parse 死）")
	_判((条.get_node("钮_菜单") as TextureButton).tooltip_text == "补充菜单",
			"元判据：六颗里最后一颗也接上了（实得「%s」"
			% (条.get_node("钮_菜单") as TextureButton).tooltip_text)

	# ④ 六颗钮的皮 / 提示 / 手型 / 三态接线
	for 名 in 钮表:
		var 钮 := 条.get_node(名) as TextureButton
		var 基名 := String(钮表[名][0])
		var 主干 := 基名.substr(0, 基名.length() - 4)
		_判(钮.texture_normal != null and String(钮.texture_normal.resource_path).ends_with(基名),
				"%s 的常态皮就是原版那张 %s（实得 %s）" % [
				名, 基名, 钮.texture_normal.resource_path if 钮.texture_normal != null else "无"])
		for 后缀 in ["_悬停", "_按下"]:
			_判(ResourceLoader.exists(皮目录 + 主干 + 后缀 + ".png"),
					"%s 的派生皮在盘上：%s" % [名, 主干 + 后缀 + ".png"])
		_判(钮.tooltip_text == String(钮表[名][1]),
				"%s 的悬停提示 = 「%s」（btnTips 的语言值），实得「%s」" % [
				名, 钮表[名][1], 钮.tooltip_text])
		_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
				"%s 悬停是手型（MButton3.init():135 buttonMode = useHandCursor）" % 名)
		_判(钮.texture_hover == null and 钮.texture_pressed == null,
				"%s 没挂 texture_hover/texture_pressed —— 松手要回 up，挂了就会停在悬停档" % 名)
		_判(_有换皮连接(钮),
				"%s 四态都接了换皮（进→悬停、出→常态、按下→按下、松手→常态）" % 名)

	var 会话 := root.get_node("GameSession")
	var 原等级 := int(会话.player_stats.get("level", 1))

	# ⑤ 三档显隐 + 条上文案
	会话.call("select_map_character", _玩家信息(1002, "夕日光", 7, 650, 650))
	for i in 2:
		await process_frame
	_判(条.visible, "选中玩家 ⇒ 条出现")
	var 全显 := true
	for 名 in 钮表:
		if not (条.get_node(名) as Control).visible:
			全显 = false
	_判(全显, "选中玩家 ⇒ 那六颗钮全显（hideBtn 只认 type==1）")
	_判((条.get_node("血字") as Label).text == "650/650",
			"条上印「650/650」不是百分数（MBar.as:163），实得「%s」" % (条.get_node("血字") as Label).text)
	_判((条.get_node("蓝字") as Label).text == "260/260",
			"蓝条同理印 260/260，实得「%s」" % (条.get_node("蓝字") as Label).text)
	_判((条.get_node("等级") as Label).text == "LV.7",
			"等级文案 = \"LV.\" + level（setData():236），实得「%s」" % (条.get_node("等级") as Label).text)
	_判((条.get_node("名字") as Label).text == "夕日光", "名字那枚跟着改成夕日光")
	_判((条.get_node("等级") as Label).get_theme_color("font_color") == Color(1, 0.8, 0),
			"等级色 = #FFCC00（setData():239 的 16747008）")
	_判((条.get_node("名字") as Label).get_theme_color("font_color") == Color(1, 1, 1),
			"名字色 = 白（setData():226 的 16777215）")

	会话.call("select_map_character", {
			"name": "暴走忍犬", "level_text": "LV.12", "hp": 100, "max_hp": 100,
			"mp": 1, "max_mp": 1, "type": 0, "char_id": 0, "level": 12})
	var 全隐 := true
	for 名 in 钮表:
		if (条.get_node(名) as Control).visible:
			全隐 = false
	_判(全隐, "选中的是怪 ⇒ 六颗钮全隐（原版怪没有这一排）")

	会话.call("select_map_character", {
			"name": "纲手", "level_text": "NPC", "hp": -1, "max_hp": -1,
			"mp": -1, "max_mp": -1, "type": 2, "char_id": 0, "level": 0})
	_判((条.get_node("血字") as Label).text == "?/?",
			"NPC 档两条都印 ?/?（setData():241-246 钉 setData(-1,-1) ⇒ MBar.as:158-161），实得「%s」"
			% (条.get_node("血字") as Label).text)
	_判(absf((条.get_node("血条") as TextureProgressBar).value) < 0.02, "NPC 档血条不填充")

	# ⑥ 掉血 ⇒ 比例跟着变（左端对齐、右边收缩）
	会话.call("select_map_character", _玩家信息(1002, "夕日光", 7, 300, 600))
	## 补间是**按真实时间**走的（`MBar.as:170` 的 0.5 秒），无头下一帧可以短到微秒 ⇒
	## 拿"等 60 帧"当"等半秒"必然假红。这里等的是墙上时钟。
	await create_timer(0.7).timeout
	var 血 := 条.get_node("血条") as TextureProgressBar
	_判(absf(血.value - 0.5) < 0.02, "300/600 ⇒ 半条（补间 0.5 秒后实得 %.3f）" % 血.value)
	_判(血.fill_mode == TextureProgressBar.FILL_LEFT_TO_RIGHT,
			"填充方向 = 从左往右（bar 被钉在 x=3 的遮罩裁，右边收缩）")
	_判((条.get_node("血字") as Label).text == "300/600", "掉血后文案跟着改成 300/600")

	# ⑦ 六颗钮各发哪一发
	会话.call("select_map_character", _玩家信息(1002, "夕日光", 7, 650, 650))
	for 名 in 钮表:
		假.清()
		(条.get_node(名) as BaseButton).emit_signal("pressed")
		var 该发 := String(钮表[名][2])
		if 该发 == "菜单":
			_判(假.发过.is_empty() and 菜单.visible,
					"点「菜单」不发包，只把弹窗开出来（_menu():300-328），实得请求 %s" % str(假.发过))
		elif 该发 == "私聊":
			_判(假.发过.is_empty() and 假.私聊到 == "夕日光",
					"点「私聊」不发包，只把聊天框切过去并填好对象（发的是 ChatEvent），实得私聊到「%s」"
					% 假.私聊到)
		else:
			_判(假.发过.size() == 1 and String(假.发过[0]) == 该发,
					"点「%s」发出的是「%s」那一发，实得 %s" % [名, 该发, 假.发过])
	_判(假.资料号 == 1002, "查资料那一发带的是被选中那个人的角色编号（实得 %d）" % 假.资料号)
	_判(假.交易号 == 1002, "交易那一发带角色编号（实得 %d）" % 假.交易号)
	_判(假.好友号 == 1002, "加好友那一发带角色编号，不是名字（实得 %d）" % 假.好友号)
	_判(假.组队名 == "夕日光", "邀请组队那一发带的是名字（原版 TroopWindowEvent 只塞 charName），实得「%s」"
			% 假.组队名)

	# ⑧ 已经是好友 ⇒ 只提示不发包（_addFriend():193-196）
	假.是好友 = true
	假.清()
	(条.get_node("钮_加好友") as BaseButton).emit_signal("pressed")
	_判(假.发过.is_empty() and 假.提示 == "该玩家已经是你的好友",
			"已经是好友 ⇒ 只弹那一句、不发包（实得请求 %s 提示「%s」）" % [假.发过, 假.提示])
	假.是好友 = false

	# ⑨ 菜单三档行表（_menu():309-320，线 = ShituList.as:15 的 60）
	# ⚠ 我方等级必须**自己钉**：不钉就是拿 user:// 那份存档的等级去比，
	#    换台机器/换个号结论就翻（同一形状的坑在别处红过）。
	会话.player_stats["level"] = 7
	假.清()
	(条.get_node("钮_菜单") as BaseButton).emit_signal("pressed")	# 收起
	(条.get_node("钮_菜单") as BaseButton).emit_signal("pressed")	# 再开
	_判(_行表(菜单) == ["族邀", "赠花", "羁绊", "看摊", "双修"],
			"我方 7 级、对方 7 级 ⇒ 五行（实得 %s）" % str(_行表(菜单)))
	会话.call("select_map_character", _玩家信息(1002, "夕日光", 70, 650, 650))
	(条.get_node("钮_菜单") as BaseButton).emit_signal("pressed")
	(条.get_node("钮_菜单") as BaseButton).emit_signal("pressed")
	_判(_行表(菜单) == ["族邀", "赠花", "羁绊", "看摊", "双修", "拜师"],
			"我方未满 60、对方已满 60 ⇒ 多一行「拜师」（实得 %s）" % str(_行表(菜单)))
	(条.get_node("钮_菜单") as BaseButton).emit_signal("pressed")
	_判(not 菜单.visible, "再点一次「菜单」= 收起（_menu():302-306 那一档）")
	会话.player_stats["level"] = 70
	会话.call("select_map_character", _玩家信息(1003, "新人", 5, 650, 650))
	(条.get_node("钮_菜单") as BaseButton).emit_signal("pressed")
	_判(_行表(菜单) == ["族邀", "赠花", "羁绊", "看摊", "双修", "收徒"],
			"我方已满 60、对方未满 ⇒ 多一行「收徒」（实得 %s）" % str(_行表(菜单)))

	# ⑩ 菜单里那几行各自落地
	假.清()
	地图.请求过.clear()
	地图.回话 = ""
	_判(_点行(菜单, "双修") and 地图.请求过 == [1003] and 假.双修号 == 0,
			"点「双修」把对方号交给地图去判距离/赶路（`HealHandler.requestToDoubleHeal:377-389`），"
			+ "面板自己**不发** 86:3（实得 地图收到 %s、面板发过 %s）" % [地图.请求过, 假.发过])
	_判(假.提示.is_empty(), "地图没回话 ⇒ 面板不弹提示（实得「%s」）" % 假.提示)
	假.清()
	地图.请求过.clear()
	地图.回话 = "你当前正在双修，无法再发起新的双修"
	_判(_点行(菜单, "双修") and 地图.请求过 == [1003] and 假.提示 == 地图.回话,
			"地图回一句拒绝 ⇒ 面板原样弹出来（实得「%s」）" % 假.提示)
	地图.回话 = ""
	假.清()
	假.清()
	_判(_点行(菜单, "看摊") and 假.发过 == ["看摊"] and 假.摊号 == 1003,
			"点「看摊」发 1296:2:<对方号>（实得 %s 号 %d）" % [假.发过, 假.摊号])
	假.清()
	_判(_点行(菜单, "收徒") and 假.发过 == ["收徒"] and 假.徒号 == 1003,
			"点「收徒」发 77:4:<对方号>（实得 %s 号 %d）" % [假.发过, 假.徒号])
	假.清()
	_判(_点行(菜单, "族邀") and 假.发过 == ["族邀"] and 假.族邀号 == 1003,
			"点「族邀」发 1552:19:<对方号>（`DetailsWindow.as:334-336` → `FamillyManager.invateToJoinFamilly:779-782`"
			+ "就一行转发、**客户端侧没有族长闸**，权限在服务端 `fake_flash_server.py:33547`）实得 %s 号 %d"
			% [假.发过, 假.族邀号])
	假.清()
	_判(_点行(菜单, "羁绊") and 假.发过 == ["羁绊"] and 假.戒号 == 1003,
			"点「羁绊」发 127:15:<对方号>（`DetailsWindow.as:343-345` → `SwitchController.requestWedding:200-210`"
			+ " → `Friend_requestTaStart:9103`；服务端 `:23266-23283` 拿 `61:14` 把**对面资料回给发起方**）实得 %s 号 %d"
			% [假.发过, 假.戒号])
	假.清()
	管.对面 = {}
	_判(_点行(菜单, "赠花") and 假.发过 == ["赠花"] and 假.花号 == 1003,
			"点「赠花」发 `94:6:<对方号>`（`DetailsWindow.as:337-342` → `openMarryZengHuaWindow:184-197`"
			+ " → `AllInOneProcessor.requestFlowerInfo:3691-3697`；以前这一行报的是「本机服务端还没有这条协议」，"
			+ "那句是假的 ⇒ §3.256 已接真上行）实得 %s 号 %d" % [假.发过, 假.花号])
	_判(管.对面 == {"charId": 1003, "name": "新人", "face": 5, "level": 5},
			"并且**先**把「对面是谁」四项交给 `窗口管理.记赠花对面`（原版存在 Manager 自己身上、"
			+ "窗里那三行档案读的就是它们）⇒ 交接的键名/取值逐字段对上，实得 %s" % str(管.对面))
	_判(假.提示.is_empty(),
			"点这一行**既不开窗也不弹提示**：原版 `openMarryZengHuaWindow` 只存四项 + 发查询，"
			+ "开窗在回帧那一刻（`receiveRefreshFlowerWindow:338`）（实得提示「%s」）" % 假.提示)
	会话.player_stats["level"] = 原等级

	# ⑪ 点头像 = 取消选中（onClickHead():473-476）—— **真事件**，不是 emit_signal
	var 圆 := 条.get_node("头像框") as Control
	var 心 := 圆.get_global_rect().get_center()
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.position = 心
	按.global_position = 心
	按.pressed = true
	root.push_input(按, true)
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.position = 心
	放.global_position = 心
	放.pressed = false
	root.push_input(放, true)
	for i in 3:
		await process_frame
	_判(not 条.visible, "点头像那一下把条收起来（cancelTarget ⇒ viewTarget 为空）")

	# ⑧ **条的贴图天然宽必须正好是真值那个 107**（用户 10-15 实机图：血条/查克拉条戳出面板外）。
	#    根因不是"贴图比框宽"这么简单 —— `TextureProgressBar` 默认 `ignore_texture_size = false`，
	#    贴图的天然尺寸会**直接把控件自己撑大**（129 的图摆在偏移算出来 107 的框里，
	#    运行期 `size.x` 就变成 129）。所以"贴图宽 == 控件宽"是**恒真的假判据**
	#    （10-15 第一次写就是这么错的，变异实测才抓出来）⇒ 参照值必须是真值那个数本身。
	#    素材已按 Flash 的 `bar.width = 107` 重烘（`开发工具/烘信息条填充.py`）。
	for 档 in [["血条", "血条填充.png"], ["蓝条", "蓝条填充.png"]]:
		var 条儿 := 条.get_node_or_null(String(档[0])) as TextureProgressBar
		_判(条儿 != null, "⑧ %s 取到了" % 档[0])
		if 条儿 == null:
			continue
		var 图 := 条儿.texture_progress
		_判(图 != null, "⑧ %s 有填充图（没图 = 条根本不画，别以为绿了）" % 档[0])
		_判(图 != null and 图.get_width() == 条真值宽,
				"%s 的填充图天然宽 = 真值 %d（MBar 的 113−6），实得 %d ⇒ 素材 %s 又变宽了：TextureProgressBar 会把自己撑到贴图宽、条就溢出" % [档[0], 条真值宽, 图.get_width() if 图 != null else -1, 档[1]])
		_判(int(round(条儿.size.x)) == 条真值宽,
				"%s 运行期控件宽 = %d（贴图一宽它会被一起撑大），实得 %.1f" % [档[0], 条真值宽, 条儿.size.x])
	## 底板是**非等比压**（Flash `barBg.width = 113` 把 135 压进 113）。
	## ⚠ Godot 4.7 的 `TextureRect.StretchMode` 不是按文档那排：**`STRETCH_SCALE = 0`**、
	##    `TILE = 1`、`KEEP = 2`、`KEEP_CENTERED = 3`、`KEEP_ASPECT = 4`（实测量出来的）。
	##    写 `3` 是"原尺寸居中"= 135 的图摆在 113 的框里两头各溢出 11 像素，
	##    比原来的 `4`（等比）更糟 —— 这一条就是把那次改错钉住。
	for 名 in ["血条底", "蓝条底"]:
		var 板 := 条.get_node_or_null(名) as TextureRect
		_判(板 != null, "⑧ %s 取到了" % 名)
		if 板 == null:
			continue
		_判(板.stretch_mode == 0, "%s 用 STRETCH_SCALE(=0) 压，实为 %d" % [名, 板.stretch_mode])
		_判(板.texture != null and 板.texture.get_width() > int(round(板.size.x)),
				"%s 贴图天然宽(%d) 大于框宽(%d) ⇒ 这条在盯「压」这个动作本身" % [名,
						板.texture.get_width() if 板.texture != null else -1, int(round(板.size.x))])
	# ⑨ **整块左上角 HUD 要在窗口带之上**（用户 10-15：「头像应该处于最上层，
	#    不会被其他按钮或者窗口挡住」）。窗口带 = `窗口管理.HUD基`(110) + 开窗序号
	#    （`窗口管理.gd:259` `窗.layer = HUD基 + i + 1`）⇒ 上界就是 110 + 全部页数。
	#    110 这个数是**手抄的真值**（不向被测对象要数），尺寸表条数现读。
	var 表: Variant = JSON.parse_string(FileAccess.get_file_as_string(尺寸表路径))
	var 页数: int = (表 as Dictionary).size() if typeof(表) == TYPE_DICTIONARY else -1
	_判(页数 > 0, "⑨ 窗口尺寸表读到了（%d 页）" % 页数)
	_判(件.layer > 窗口带基 + 页数,
			"头像面板整块 layer(%d) 必须高于窗口带顶(%d+%d=%d) ⇒ 任何一扇窗都不该盖住它" % [
			件.layer, 窗口带基, 页数, 窗口带基 + 页数])
	_判(件.layer < 模态层, "⑨ 但仍要低于模态确认弹层(%d) —— 弹出来时它该压住一切" % 模态层)
	# ⑩ **玩家头顶的选中箭头跟帧算高**（用户 10-15：箭头掉在脚边、压在名字牌上）。
	#    原版对玩家也是 `Character.as:1469-1470` `y = -_crtCharHeight - 8`。
	#    这里直接调玩家脚本那条函数（不进树、不跑 `_ready`，避开地图依赖）：
	#    假精灵报 96 高 ⇒ 期望 y = −104。
	var 玩: Node2D = (load(玩家脚本) as GDScript).new() as Node2D
	_判(玩 != null, "⑩ 玩家脚本能实例化（改坏了 parse 就是红，不会静默跳过）")
	if 玩 != null:
		var 箭 := Node2D.new()
		箭.name = "SelectionMarker"
		玩.add_child(箭)
		var 精 := 假精灵.new()
		玩.set("player_sprite", 精)
		玩.call("_更新头顶挂件位置")
		_判(absf(箭.position.x) < 0.01 and absf(箭.position.y + 104.0) < 0.01,
				"玩家档箭头 = (0, −贴图高96 − 8) = (0,−104)，实得 (%.1f,%.1f)" % [箭.position.x, 箭.position.y])
		## 换动作 ⇒ 高度变了要跟着挪（原来只在挂上那一刻算一次 = 跳起来就错位）
		精.高 = 60.0
		玩.call("_更新头顶挂件位置")
		_判(absf(箭.position.y + 68.0) < 0.01,
				"贴图高换成 60 ⇒ 箭头跟着到 −68（实得 %.1f）" % 箭.position.y)
		## 量不到高（精灵没建/帧数据缺）⇒ **不许**按 0 处理掉到脚边，保持原位
		玩.set("player_sprite", null)
		玩.call("_更新头顶挂件位置")
		_判(absf(箭.position.y + 68.0) < 0.01,
				"取不到贴图高时箭头**不动**（实得 %.1f）—— 按 0 算就是掉回脚边" % 箭.position.y)
		玩.queue_free()

	跑完了 = true
	print("目标信息条离线门：通过 %d，红 %d" % [通过, 失败])


## 只认"确实接了换皮、并且绑的是这一档"，不接受"我调过函数"。
func _有换皮连接(钮: TextureButton) -> bool:
	var 要 := {"mouse_entered": 1, "mouse_exited": 0, "button_down": 2, "button_up": 0}
	for 信号名 in 要:
		var 档 := int(要[信号名])
		var 中 := false
		for 连 in 钮.get_signal_connection_list(信号名):
			var 呼: Callable = 连.get("callable") as Callable
			var 参: Array = 呼.get_bound_arguments()
			if not 参.is_empty() and int(参[参.size() - 1]) == 档:
				中 = true
		if not 中:
			return false
	return true


class 假地图 extends Node:
	## 「双修」那一行**不在面板里判距离**：原版是 `HealHandler.requestToDoubleHeal:377-389`
	## 拿到目标之后交给 `canRequestDoubleNow:238-243` / `tickGotoDoubleHeal:88-116`
	## （不够近就先 `pathFind` 走过去，走到位再发）⇒ 我们照抄成"面板问地图、地图管闸与赶路"。
	## 这个替身就让那条路**真的走到有人接**，同时把"面板自己发没发 86:3"分开判。
	var 请求过: Array = []
	var 回话 := ""

	func 请求双修(号: int) -> String:
		请求过.append(号)
		return 回话


class 假聊天 extends Node:
	var 记: Node

	func _ready() -> void:
		add_to_group("chat_panel")

	func 开始私聊(玩家名: String) -> void:
		记.私聊到 = 玩家名


class 假窗口管理 extends Node:
	## 「赠花」那一项的**另一半交接**：面板把「对面是谁」四项交给 `窗口管理.记赠花对面`
	## （原版存进 `MarryTableManager` 自己身上，`openMarryZengHuaWindow:184-197`），窗和托盘都从那一侧取。
	## 挂替身就是为了把"交了什么过来"逐字段量到，而不是只看有没有发包。
	var 对面: Dictionary = {}

	func 记赠花对面(对面: Dictionary) -> void:
		self.对面 = 对面


class 假后端 extends Node:
	var in_game := true
	var 发过: Array = []
	var 提示 := ""
	var 资料号 := 0
	var 交易号 := 0
	var 好友号 := 0
	var 组队名 := ""
	var 双修号 := 0
	var 摊号 := 0
	var 徒号 := 0
	var 族邀号 := 0
	var 戒号 := 0
	var 花号 := 0
	var 私聊到 := ""
	var 是好友 := false

	func 清() -> void:
		发过.clear()
		提示 = ""
		私聊到 = ""

	func _ready() -> void:
		var 会 := get_parent().get_node_or_null("GameSession")
		if 会 != null:
			会.connect("notification_requested", func(话): 提示 = String(话))

	func request_character_info(号: int) -> bool:
		发过.append("查资料")
		资料号 = 号
		return true

	func request_trade_invite(号: int) -> bool:
		发过.append("交易")
		交易号 = 号
		return true

	func request_friend_add(号: int) -> bool:
		发过.append("好友")
		好友号 = 号
		return true

	func is_friend(号: int) -> bool:
		return 是好友

	func request_party_invite(名: String) -> bool:
		发过.append("组队")
		组队名 = 名
		return true

	func request_double_heal_invite(号: int) -> bool:
		发过.append("双修")
		双修号 = 号
		return true

	func request_stall_open(号: int) -> bool:
		发过.append("看摊")
		摊号 = 号
		return true

	func request_tutor_apply(动作: int, 号: int) -> bool:
		发过.append("收徒" if 动作 == 4 else "拜师")
		徒号 = 号
		return true

	func request_family_invite(号: int) -> bool:
		发过.append("族邀")
		族邀号 = 号
		return true

	func request_bond_start(号: int) -> bool:
		发过.append("羁绊")
		戒号 = 号
		return true

	## `94:6:<对面号>`（`AllInOneProcessor.requestFlowerInfo:3691-3697`）。赠花那一行**只发这一发**，
	## 不开窗、不重查 —— 开窗的是回帧 `58:2`（见 `赠花窗回归测试`）。
	func request_flower_info(号: int) -> bool:
		发过.append("赠花")
		花号 = 号
		return true


## ⑩ 用的假精灵：只报一个"当前帧贴图高"，让判据能脱离美术数据算箭头落点。
## ⚠ `高` 要能改 —— 换动作时高度会变，这条判据判的就是"跟着帧走"而不是写死常数。
class 假精灵 extends Node2D:
	var 高 := 96.0

	func 当前贴图高度() -> float:
		return 高
