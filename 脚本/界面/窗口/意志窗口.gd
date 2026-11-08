extends RefCounted
## 意志三窗（原版 `com/mxw/uifl/controls/yiZhi/`，是**三扇互相独立的窗口**、不是页签）：
##   背包 `YiZhiPackWindow` 663×548（工程注册名沿用「遗址」）
##   学习 `YiZhiStudyWindow` 772×564
##   介绍 `YiZhiIntroduceWindow` 455×430（图鉴；点背包右下角 `[意志介绍]` 开、再点收起）
##
## 几何全在 .tscn 里（场景由 `开发工具/生成意志*场景.py` 从量具表生成 ⇒ **别手改场景**），
## 本文件只做三件事：**填数据、接交互、按原版态换皮**。逐件出处见
## `game-client/真值/窗口/意志.md` §1~§3 与 `测试/截图/{意志学习,遗址,意志介绍}_对照/真值对照表.md`。
##
## **协议已接通（2026-10-03 §3.90.6，任务 #63 还账）**：`SPIRIT_ACTION 1823` 的 12 个动作全部
##   经 `游戏会话.spirit_*` 封装发出（`后端连接.request_spirit_action`），回帧 cmd0..8 驱动
##   `spirit_bag/spirit_equipped/spirit_panel/上下限/导师状态` 五个状态面。
##   **离线时**所有钮回到诚实回执（"要在服务端结算（离线不模拟）"）——不发就是不发。
##   未接的两件（欠账）：格与格**拖放**（action10 的 UI 面，他们包的 #8）与自动升级循环喂（action9 连发）。

const 背包场景 := preload("res://场景/界面/窗口/遗址/意志背包窗口.tscn")
const 学习场景 := preload("res://场景/界面/窗口/遗址/意志学习窗口.tscn")
const 介绍场景 := preload("res://场景/界面/窗口/遗址/意志介绍窗口.tscn")
const 文字提示场景 := preload("res://场景/界面/组件/文字提示框.tscn")
const 意志提示场景 := preload("res://场景/界面/组件/意志提示框.tscn")
const 意志提示框 := preload("res://脚本/界面/组件/意志提示框.gd")
const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 灰度着色器 := preload("res://脚本/界面/组件/禁用灰度.gdshader")

const 文案路径 := "res://数据/界面/意志_文案.json"
const 图鉴路径 := "res://数据/意志图鉴.json"
const 常量路径 := "res://数据/意志.json"
const NPC表路径 := "res://数据/NPC.json"
const 意志图 := "res://素材/界面/原版窗口/意志/"
const 派生图 := "res://素材/界面/专用控件/"
const 线皮 := "res://素材/界面/原版窗口/通用控件/横向分隔线.png"	# 原版 `LineHPicF`，原生 252×2

## `MButton3._textColors`（:69-74）up #FCF49C / over #FFFFC3 / down #ACADB2；
## disabled 的字色是 **#939393**（`updateState:335-339` 的 disabled 不是加性滤镜，是换灰皮）。
const 态色 := [Color("#fcf49c"), Color("#ffffc3"), Color("#acadb2")]
const 禁用字色 := Color("#939393")
## `SpiritColor.YELLOW`（`SpiritColor.as`：灰1/绿2/蓝3/紫4/粉5/**黄6**/红7/亮粉8）。
## 会话里行的 `color` 是数字字符串（`_spirit_行` 的 `String(段[1])`）⇒ 比较时转 int。
## 黄的三个特殊口径都在这：不许穿（`upHandler:243`）、双黄不许融（`rongHeYiZhi:431`）、
## 融合经验恒 1200（`YiZhiData.rongHeExp:94`）。
const 意志黄 := 6

## 学习页五枚：原版 `ProgramButton extends MButton3`，**每组只有一张皮**、字画在皮里
## ⇒ 只换 `texture_normal`（不设 texture_hover，否则主题会再叠一层）。
## 件名 → [常态原件（`原版窗口/意志/`）, 派生基名（`专用控件/`）, 动作]
const 学习钮表 := {
	"导师面板/一键学习": ["钮_一键学习.png", "意志_一键学习", "学习全部"],
	"导师面板/全部拾取": ["钮_全部拾取.png", "意志_全部拾取", "拾取全部"],
	"导师面板/全部卖出": ["钮_全部卖出.png", "意志_全部卖出", "卖出全部"],
	"导师面板/返回": ["钮_返回.png", "意志_返回", "关闭"],
	"导师面板/打开背包": ["打开背包钮.png", "意志_打开背包", "打开背包"],
}
## 三条 request 后端没有 ⇒ 回执文案（交互门 `截意志钮态.gd` 逐字断言这三条）。
const 学习回执 := {
	"学习全部": "一键学习意志需要连接原版服务端",
	"拾取全部": "拾取全部意志需要连接原版服务端",
	"卖出全部": "卖出全部意志需要连接原版服务端",
}
## 背包页三枚 = `BaseUtil.getButton()` → `MButtonF`（tag18 `MButton_up` 57×22，
## `isScale9Grid=false` ⇒ 整张非等比压扁）；**字是独立子 Label** ⇒ 除换皮还要换字色。
## 件名 → [常态皮基名, 字件名, 动作]
const 背包钮表 := {
	"一键合成": ["意志_一键合成", "字", "合成全部"],
	"前往学习": ["意志_前往学习", "字", "打开学习"],
	"自动升级钮": ["意志_自动升级", "字", "自动升级"],
}
const 背包回执 := {
	"合成全部": "背包内没有可合成的意志",
	"自动升级": "请先将意志拖入升级槽位",
}

## `initView:429,442,446`：一行 5 格、格 64 + gap 5 ⇒ 步距 69（常量在场景里，这里只留给门核对）
const 背包每行 := 5
const 格距 := 69.0
## `YiZhiIntroduceWindow:39` `rowHeight=26`；`YiZhiItemRenderer:100-104` 字宽 406、分隔线 y=22
const 行高 := 26.0
const 行字宽 := 406.0
const 行线Y := 22.0
## 滚动条运行期量（`BaseScrollPane:266,243,283-284` + `ScrollBar:153`）：轨顶 14、轨高 344、视口 372
const 滚动轨顶 := 14.0
const 滚动轨高 := 344.0
const 滚动视口 := 372.0

static var _文案: Dictionary = {}
static var _图鉴: Dictionary = {}
static var _常量: Dictionary = {}
static var _NPC: Dictionary = {}
static var _灰度: ShaderMaterial = null
static var _标签 := RegEx.create_from_string("<[^>]+>")
## 原版 `YiZhiManager.isPrompt`（`TeacherCell:81-89`）；召唤次数已改读 cmd0（服务端账本）
static var _要提示 := true
## 介绍页滑块：正在被拖的那一枚 + 按下时指针在滑块内的落点
static var _拖着的滑块: Control = null
static var _拖偏 := 0.0
## 渲染入口存一次宿主(`_填格内容/_召喚次数文/_穿戴上限` 这些静态函数要拿 `_session`,
## 与 `首領窓口的.gd` 同形)。
static var _宿主

## 意志格的拖放件（`extends Control`；`可拖拽格` 是 Button 基，挂不到本窗的空 Control 上）。
## 场景由 `生成意志*场景.py` 生成、**不许手改**（见文件头）⇒ 脚本只能**运行期挂**。
const 意志格 := preload("res://脚本/界面/组件/意志格.gd")
## action0 只在**头一回**开页发（开面板回 0/1/6/7 四帧 → 每帧 `spirit_state_changed`
## → 宿主重渲染本函数 → 若无此 guard 会再发 open = **无限自激环**）。登出后重置见会话注释。
static var _面板已开 := false


static func _读(路径: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(路径))


static func 键(名: String) -> String:
	if _文案.is_empty():
		_文案 = _读(文案路径)
	return str(_文案.get(名, ""))


## `CN.replaceString(模板, a, b, c)`：占位符是 `%1/%2/%3`（不是 `%s`）。
static func 填(模板: String, 参数: Array) -> String:
	var 出 := 模板
	for i in 参数.size():
		出 = 出.replace("%%%d" % (i + 1), str(参数[i]))
	return 出


## 纯文本（给普通 Label 用：Godot 的 Label 不认 `[color]`，原版那串里的 `<font>` 只能整块剥掉）。
static func 去标记(串: String) -> String:
	var 出 := 串.replace("<br/>", "\n").replace("<br>", "\n")
	return _标签.sub(出, "", true)


static func 导师(i: int) -> Dictionary:
	if _常量.is_empty():
		_常量 = _读(常量路径)
	var 得: Dictionary = ((_常量.get("common", {}) as Dictionary).get("gain", {}) as Dictionary)
	var 记 = 得.get("NPC%d" % i, {})
	return 记 as Dictionary if 记 is Dictionary else {}


static func 图鉴项(编号: Variant) -> Dictionary:
	if _图鉴.is_empty():
		_图鉴 = _读(图鉴路径)
	var 记 = _图鉴.get(str(编号), null)
	return 记 as Dictionary if 记 is Dictionary else {}


## `StringTool.getNpcString(npcId)`：id 补零到 8 位再查 `数据/NPC.json`。
static func NPC名(i: int) -> String:
	if _NPC.is_empty():
		_NPC = _读(NPC表路径)
	var 记 = _NPC.get("%08d" % int(导师(i).get("npcId", 0)), {})
	return str((记 as Dictionary).get("name", "")) if 记 is Dictionary else ""


## 召唤位：`TeacherPanel:65-70` 把下标写死成 3，真实条件却是 `TeacherCell:56` 的
## `special.needYuanBao > 0` ⇒ 按数据算（数据一改就暴露，量具 `_验召唤态` 也会红）。
static func 召唤位() -> int:
	for i in 5:
		if int((导师(i).get("special", {}) as Dictionary).get("needYuanBao", 0)) > 0:
			return i
	return -1


static func _灰度材质() -> ShaderMaterial:
	if _灰度 == null:
		_灰度 = ShaderMaterial.new()
		_灰度.shader = 灰度着色器
	return _灰度


static func _件(页: Control, 路: String) -> Node:
	return 页.get_node_or_null(路)


static func _写文字(页: Control, 路: String, 值: String) -> void:
	var 件 := _件(页, 路)
	if 件 is Label:
		(件 as Label).text = 值
	elif 件 is LineEdit:
		(件 as LineEdit).text = 值


## 阅历到了**就地刷两个货币标签**（AS3 `YiZhiStudyWindow.updateYueLiAndYuanBao:221-225`：
## `_yuanBaoLabel.text = API.dataCenter.cashMoney`、`_jinBiLabel.text = yueLi`）——
## 原版就是改 Label 文字，**不重建窗口**。由 `功能窗口` 在 `_current_page == "意志学习"`
## 时调（1572 帧到达 ⇒ `会话.阅历_变化`）。
## ⚠️ 页面可能已被换掉（玩家切到背包页）⇒ 找不到件就静默返回（`_写文字` 对 null 安全）。
static func 刷阅历(窗口, 点数: int) -> void:
	var 页 := 窗口._content.get_child(0) as Control
	if 页 == null:
		return
	_写文字(页, "货币条/阅历数值", str(点数))
	_写文字(页, "货币条/元宝数值", str(int(窗口._session.player_stats.get("cash", 0))))


static func _舞台(页: Control) -> Vector2:
	return 页.get_viewport_rect().size


# ═════════════════════ 一、意志学习窗（772×564）═════════════════════

static func 渲染学习(窗口) -> void:
	_宿主 = 窗口
	var 页: Control = 窗口._instantiate_page(学习场景)
	# 开面板 = action0：一次回 cmd1(候选) + cmd7(背包/穿戴) + cmd6(上限) + cmd0(导师状态)。
	# 原版 `showYiZhiStudyWindow` 前 `initView` 走的就是它（`SpiritProcessor` 开面板回 1 与 7）。
	if not _面板已开:
		_面板已开 = 窗口._session.spirit_open()
	var 状态: Dictionary = 窗口._session.player_stats
	# 元宝 = `API.dataCenter.cashMoney`（`updateYueLiAndYuanBao:221-225`）。
	# ⚠ 节点名工程里叫「火影币」，值必须是**元宝**（意志.md §1.1 的 ⚠）。
	_写文字(页, "货币条/元宝数值", str(int(状态.get("cash", 0))))
	# 阅历 = 服务端 1572 状态帧的 `pve_points`（`_send_pve_status:30856`），落在 `会话.阅历`。
	# ⚠️ 以前这里读 `player_stats.spirit_experience`——全工程没有任何地方写这个键
	#    （2026-10-19 排查：只此两处读、零处写）⇒ 恒 0。别再回退到那个键。
	_写文字(页, "货币条/阅历数值", str(int(窗口._session.阅历)))
	# 今日免费次数 = `onSpirit_npcStatus(param2)` 的 `freeCount`，服务端没回 ⇒ 0
	_写文字(页, "导师面板/今日次数", 去标记(填(键("YIZHI_TODAY_STUDY_DESC"), [0])))
	for 件名 in 学习钮表:
		var 定: Array = 学习钮表[件名]
		_绑三态钮(页, 件名, 意志图 + str(定[0]), str(定[1]), null)
		_接学习钮(页, 件名, str(定[2]), 窗口)
	_接导师(页, 窗口)
	_刷新导师状态(页)
	_填学习格(页, 窗口._session.spirit_panel, 窗口)
	# 阅历值**开窗时**补要一次（见 `会话.请求阅历状态` 的注释：开面板 action0 不回 1572）。
	# ⚠️ 只在开窗那一轮发（宿主 `_刚开窗` 闸，口径同 `功能窗口.open_page:851-858`：
	#   "开窗发查询、回帧重建不再发"）—— 学习页会被每一条意志回帧重建，不设闸就会
	#   发→回帧→重建→再发 成环。离线返回 false ⇒ 阅历保持 0，UI 照实显示。
	if bool(窗口.get("_刚开窗")):
		窗口._session.请求阅历状态()
	# P2-2 拾取飞入：cmd8 带来的清单在这时候播（播完即清 ⇒ 紧跟的 cmd1 重渲不会重播）。
	# 其他页渲染时也会清（见 `渲染背包`/`渲染介绍`）⇒ 学习页没开时的拾取不会留成"过时动画"。
	_放飞入(页, 窗口._session.spirit_picked)


## P2-2 拾取飞入 —— `playPickYiZhiEffect:115-146`：每件从「学习格格位 + (10,10)」
## 飞 **2s** 到导师面板的「打开背包」钮，`onComplete` 回收（`onEffectEnd:213-219` = removeChild）。
## 格位 = `YiZhiContainer.getYiZhiPoint:65-71`：`(pos % 10) * 72`、`(pos / 10) * 82`
## （LENGTH=10、hGap=10、vGap=20、格 62×62）＋ 容器原点；工程用 `global_position` 累加等价。
## ⚠️ 起点格位与格子**内容**无关（格子按 pos 排）⇒ cmd8 后紧跟的 cmd1 重渲不挪位。
## ⚠️ `spirit_picked` 用完即清：服务端 `_pick_spirit_panel_items:22608-22665` 在 cmd8 后必发
##   cmd1（面板帧）⇒ 不清就会在同一串回帧里重播一次。
static func _放飞入(页: Control, 清单: Array) -> void:
	if 页 == null:
		return
	if 清单.is_empty():
		return
	var 容器 := _件(页, "意志容器") as Control
	var 终点件 := _件(页, "导师面板/打开背包") as Control
	if 容器 == null or 终点件 == null:
		清单.clear()
		return
	for 项 in 清单:
		var 行: Dictionary = 项 if 项 is Dictionary else {}
		var 图鉴 := 图鉴项(行.get("id", ""))
		if 图鉴.is_empty():
			continue
		var 图 := TextureRect.new()
		图.texture = load(str(图鉴.get("icon", ""))) as Texture2D
		图.size = Vector2(56, 56)			# 与格图标同尺寸（`_填一格层`）
		图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		图.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		图.mouse_filter = Control.MOUSE_FILTER_IGNORE
		图.z_index = 10						# 压在格子与钮上面，别被格底盖住
		页.add_child(图)
		var 位 := int(行.get("pos", 0))
		图.global_position = 容器.global_position \
				+ Vector2((位 % 10) * 72, (位 / 10) * 82) + Vector2(10, 10)
		var 终点 := 终点件.global_position
		var 收 := func() -> void:
			if is_instance_valid(图):
				图.queue_free()
		var 补间 := 图.create_tween()
		补间.tween_property(图, "global_position", 终点, 2.0)
		补间.finished.connect(收)
	清单.clear()


## 五枚钮的点击。原版三条发 request、一条关窗、一条开窗（`TeacherPanel` 各 handler）。
static func _接学习钮(页: Control, 件名: String, 动作: String, 窗口) -> void:
	var 钮 := _件(页, 件名) as BaseButton
	if 钮 == null:
		return
	match 动作:
		"关闭":		# backMainTownHandler:214-217 = `setDOShow(学习窗,false)`
			钮.pressed.connect(窗口.close)
		"打开背包":	# openPackHandler:84-87 = `setDOShow(背包窗,true)`
			钮.pressed.connect(窗口.导航到.bind("遗址"))
		_:
			# 2026-10-03 接 `1823`：三枚发真动作（11/4/6），成功后**不出声**——
			# 回帧（cmd7/3/8）驱动棋盘与背包重画；发送失败（离线）才给诚实话。
			# ⚠️⚠️ 2026-10-22 修（用户第三次实机报「一键三钮点了没反应」）：
			#   这三个 match 分支名原来写的是「一键学习/全部拾取/全部卖出」，而**钮表
			#   `学习钮表` 第三列给的动作名是「学习全部/拾取全部/卖出全部」**——词序对不上，
			#   match 永远不命中 ⇒ `发` 恒为 false ⇒ **请求一个都没发出去**，恒弹离线回执。
			#   2026-10-20 的 `验意志一键钮.gd` 又把那句离线回执当期望断言 ⇒ 门绿得假
			#   （bug 被门钉住）。§3.182 修了 512 路由也没用——包根本没出客户端。
			#   复现手法：同会话直调 `spirit_pick_all()` 返回 true、走按钮返回 false
			#   ⇒ 只可能是 match 没命中（临时探针 `复现一键三钮.gd` 已随该轮收尾删除，
			#   防线固化在 `测试/源码健全性回归测试.gd` ⑤ 与在线门
			#   `测试/一键三钮在线回归测试.gd`）。
			#   分支名必须与 `学习钮表` 第三列、`学习回执` 的键**三处一致**（回执按 动作 查）。
			钮.pressed.connect(func() -> void:
				var 发: bool = false
				match 动作:
					"学习全部": 发 = 窗口._session.spirit_learn_all()
					"拾取全部": 发 = 窗口._session.spirit_pick_all()
					"卖出全部": 发 = 窗口._session.spirit_sell_all()
				if not 发:
					窗口._show_hint(str(学习回执.get(动作, "意志协议要在服务端结算（离线不模拟）"))))


## 只接一次的事件（`_刷新导师状态` 会被反复调，接线绝不能重复挂）。
static func _接导师(页: Control, 窗口) -> void:
	for i in 5:
		var 像 := _件(页, "导师面板/导师容器/导师_%d/头像" % i) as Control
		if 像 != null:
			_独接输入(像, _导师输入.bind(i, 窗口))
			# overHandler / outHandler（`:91-99`）：黄框跟着 hover 显隐。
			# ⚠ 悬停框/气泡自己必须 IGNORE —— 它们吃鼠标就会和头像来回抢 hover（用户报的"一闪一闪"）
			var 框 := _件(页, "导师面板/导师容器/导师_%d/悬停框" % i) as CanvasItem
			if 框 != null:
				像.mouse_entered.connect(func() -> void: 框.visible = true)
				像.mouse_exited.connect(func() -> void: 框.visible = false)
		# ⚠ `TextureButton` **不是** `Button` 的子类（两者同继承 `BaseButton`）——
		#   写成 `as Button` 取到的是 null，于是这颗钮静默永远接不上（2026-10-03 实测踩过）。
		var 召 := _件(页, "导师面板/导师容器/导师_%d/召唤" % i) as BaseButton
		if 召 != null:
			召.pressed.connect(_导师点击.bind(i, 窗口))	# `TeacherCell:49` 钮自己也挂 CLICK


## `TeacherPanel.updateNpcStatus:49-82` + `TeacherCell.lightTeacher:175-204` 的逐位还原。
## 服务端 cmd0 回 5 位状态（`SpiritNpcStat`：0=DARK / 非 0=亮，其中 1=普通解锁、2=已召唤的特殊导师）：
##   · **亮** ⇒ 头像去灰度、可点；召唤钮藏掉（`TeacherCell:181-185`）。
##   · **DARK** ⇒ 头像套灰度；只有下标 == 召唤位（数据里 needYuanBao>0 的那位，AS3 写死 3）
##     且今日还能召唤（`会话.spirit_special_enabled`）时才显示召唤钮、头像才吃鼠标
##     （`TeacherPanel:67-69` → `setZhaoHunButtonVisible` → `TeacherCell:108/189`）。
##   · 气泡给**最后一个**亮位（`TeacherPanel:76` 的 `_loc5_` 循环末值），全 DARK 回落到下标 0（初值 0）。
##   · 一键学习钮可见性 = `special_enabled`（`TeacherPanel:56` 的 `studyAllBtn.visible = param3`）。
## 离线（状态表空）= 按"没回状态帧"处理：五位全 DARK，只有召唤位可点 —— 与 2026-10-19
## P0-2 前的既有离线行为一致（那会儿 `亮` 参数恒 -1，等价于本函数的离线支）。
static func _刷新导师状态(页: Control) -> void:
	var 位 := 召唤位()
	var 状态: Array = []
	var 可召唤 := true
	if _宿主 != null and _宿主._session != null:
		状态 = _宿主._session.spirit_npc_status
		可召唤 = bool(_宿主._session.spirit_special_enabled)
	var 在线态 := not 状态.is_empty()
	# ⚠ 末亮必须**先整表算完**再拿来显隐气泡。原版 `onSpirit_lightNpc`
	# （`TeacherPanel:148-158`）是"显新隐旧"——任何时刻**只有一个**气泡。
	# 曾经在下面那个循环里边走边显隐（`泡.visible = (i == 末亮)` 吃的是**当时的**末亮）
	# ⇒ 状态 [1,1,0,0,0] 时 0/1 两格的气泡**同时亮着**（2026-10-21 用户截图照出：
	# 导师1 的气泡在人物前面、导师2 的气泡同时也出现）。语义不变，仍是 `TeacherPanel:76`
	# 那个循环末值，全 DARK 回落到下标 0。
	var 末亮 := 0
	if 在线态:
		for i in mini(5, 状态.size()):
			if int(状态[i]) != 0:
				末亮 = i
	for i in 5:
		var 组 := "导师面板/导师容器/导师_%d" % i
		var 像 := _件(页, 组 + "/头像") as TextureRect
		var 召 := _件(页, 组 + "/召唤") as CanvasItem
		var 泡 := _件(页, 组 + "/气泡") as CanvasItem
		if 像 == null:
			continue
		if 在线态 and i < 状态.size() and int(状态[i]) != 0:
			像.material = null				# `lightTeacher(true)`：去灰度
			像.mouse_filter = Control.MOUSE_FILTER_STOP
			if 召 != null:
				召.visible = false			# `TeacherCell:181-185`：亮着的没有召唤钮
		else:
			像.material = _灰度材质()		# `lightTeacher(false)`：`getGrayFilter()`
			var 该召: bool = (i == 位 and 可召唤)
			像.mouse_filter = Control.MOUSE_FILTER_STOP if 该召 else Control.MOUSE_FILTER_IGNORE
			if 召 != null:
				召.visible = 该召			# `TeacherCell:189`：鼠标只归可见的召唤钮
		if 泡 != null:
			泡.visible = (i == 末亮)
	# 一键学习钮：`TeacherPanel:56` 的 `studyAllBtn.visible = param3`（param3 = 可召唤标志）
	var 一键 := _件(页, "导师面板/一键学习") as CanvasItem
	if 一键 != null:
		一键.visible = 可召唤
	# 三处悬浮提示：5 枚费用 + 1 枚召唤次数（只在召唤位）+ 1 枚打开背包
	for i in 5:
		_挂文字提示(页, _件(页, "导师面板/导师容器/导师_%d/头像" % i) as Control,
				_导师费用文(i), "导师%d" % i)
	if 位 >= 0:
		_挂文字提示(页, _件(页, "导师面板/导师容器/导师_%d/召唤" % 位) as Control,
				_召唤次数文(位), "召唤%d" % 位)
	_挂文字提示(页, _件(页, "导师面板/打开背包") as Control,
			键("YIZHI_OPEN_PACK_TOOLTIP"), "打开背包")


static func _导师费用文(i: int) -> String:
	## `TeacherCell:74-75`：`<font color='#ffffff'>名</font><br><font color='#fff000'>学习所需：X</font>`
	return "<font color='#ffffff'>%s</font><br><font color='#fff000'>%s</font>" % [
			NPC名(i), 填(键("YIZHI_STUDY_FEI_YONG"), [int(导师(i).get("needYueLi", 0))])]


static func _召唤次数文(i: int) -> String:
	## `TeacherCell:111-112`：今日召唤次数 已用/总额、花费 X元宝。
	## 已用 = cmd0 的 `spirit_special_count`（服务端账本）；总额 99 = 服务端
	## `SPIRIT_SPECIAL_LIMIT`（`fake_flash_server.py:12376`，每日重置）。
	## ⚠️ 曾是 20（旧夹具口径）——服务端 99 之后忘改，2026-10-19 照服务端纠正。
	var 已用: int = _宿主._session.spirit_special_count if _宿主 != null else 0
	return 填(键("YIZHI_ZHAN_HUAN_NPC_TIP"), [已用, 99,
			int((导师(i).get("special", {}) as Dictionary).get("needYuanBao", 0))])


static func _导师输入(事件: InputEvent, i: int, 窗口) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed \
			and int((事件 as InputEventMouseButton).button_index) == MOUSE_BUTTON_LEFT:
		_导师点击(i, 窗口)


## `clickTeacherHandler:131-142`：**召唤钮可见 ⇒ 走召唤**；否则发学习请求并把自己气泡收起（`:140`）。
## （原版判的就是 `zhaoHuanBtn.visible`——亮着的导师召唤钮被 `lightTeacher(true)` 藏掉，
##  于是自然走学习；我们照抄这个判据，不另立"是不是召唤位"的条件。）
static func _导师点击(i: int, 窗口) -> void:
	var 页 := 窗口._content.get_child(0) as Control
	var 召 := _件(页, "导师面板/导师容器/导师_%d/召唤" % i) as CanvasItem
	if 召 != null and 召.visible:
		_召唤流程(i, 窗口)
		return
	var 泡 := _件(页, "导师面板/导师容器/导师_%d/气泡" % i) as CanvasItem
	if 泡 != null:
		泡.visible = false
	var 费用 := int(导师(i).get("needYueLi", 0))
	# 阅历 = `会话.阅历`（1572 帧拆出来的 `pve_points`）。同 `渲染学习` 的 ⚠️：
	# 以前读 `player_stats.spirit_experience`（没人写的键）⇒ gate 恒真、导师全点不动。
	var 阅历 := int(窗口._session.阅历)
	# `YiZhiManager.requestYiZhi:95-101`：免费次数 <1 且阅历不够 ⇒ 只提示，一个包都不发
	if 阅历 < 费用:
		窗口._show_hint(键("YIZHI_NO_ENOUGH_YUELI_TIP"))
	elif not 窗口._session.spirit_gain_from_teacher(i):
		# 接 `1823` 后真发 action2（扣阅历/得件全在服务端，回帧 cmd2+7 驱动棋盘重画）；
		# 离线才给诚实话。**不本地扣阅历**（那是服务端的账）。
		窗口._show_hint("意志学习要在服务端结算（离线不模拟）")


## `zhaoHuanHandler:144-161`：次数已满 ⇒ 只提示；`isPrompt` 还开着 ⇒ 弹**带勾选**的确认；
## 勾掉过（`isPrompt=false`）就直接召唤。
static func _召唤流程(i: int, 窗口) -> void:
	# 次数口径交给服务端（夹具 cmd0 的 `special_enabled = count < 20`）；离线初值 true ⇒ 走到弹窗。
	if not 窗口._session.spirit_special_enabled:
		窗口._show_hint(键("YIZHI_NPC_ZHAOHUAN_FINISHED"))
		return
	var 元宝 := int((导师(i).get("special", {}) as Dictionary).get("needYuanBao", 0))
	var 正文 := 填(键("YIZHI_ZHAO_HUAN_NPC_DILOG_TEXT"), [元宝, NPC名(i)])
	# `showCheckBoxDialog` 的第 2 参 = `isSelected`，`TeacherCell:155` 传的是**字面 true** ⇒ 默认勾上
	if _要提示:
		确认弹.弹勾选(窗口._overlay, 正文, 键("YIZHI_ZHAO_HUAN_NPC_DILOG_CHECK_TEXT"), true,
				func(选: Variant) -> void: _召唤回执(i, 元宝, 选, 窗口), "召唤确认框")
	else:
		_召唤回执(i, 元宝, true, 窗口)


## `sureToZhaoHuan:81-89`：取消那一支拿到的是 **null** ⇒ 直接 return（不召唤、不改 isPrompt）；
## 确定 ⇒ `isPrompt = !勾选` 再 `zhaoHuanTeacher(position, needYuanBao)`。
static func _召唤回执(i: int, 元宝: int, 选: Variant, 窗口) -> void:
	if 选 == null:
		return
	_要提示 = not bool(选)
	# `YiZhiManager:242-245` 的余额判**随 1823 接通一起回来**（在线时 cash 是真元宝，不再撒谎）。
	var 余额: int = int(窗口._session.player_stats.get("cash", 0))
	if 元宝 > 余额:
		窗口._show_hint(键("YIZHI_NO_ENOUGH_YUANBAO_TIP"))
		return
	# 真发 action1（点亮特殊导师）：扣元宝、置导师状态、回 cmd0+2+7 全在服务端；**不本地计数**。
	if not 窗口._session.spirit_summon(i):
		窗口._show_hint("召唤导师要在服务端结算（离线不模拟）")


## 学习页意志格：`YiZhiContainer.setData:73-91` 是**按数据条数造格** ⇒ 0 条 = 一格都没有
## （连格底都不画；用户拿原版实机图纠正过这一点）。所以槽位只是位置，控制器逐格显隐。
static func _填学习格(页: Control, 列表: Variant, 窗口) -> void:
	var 数组: Array = 列表 if 列表 is Array else []
	# ⚠️⚠️ 2026-10-22 §3.185（用户实机报「应该有第二层，但是没有显示」）：上界 **20**。
	#   原版 `YiZhiContainer` 按数据**动态排两行**（`LENGTH=10`，`getYiZhiPoint:65-71`：
	#   `x=(i%10)·72`、`y=(i/10)·82`）⇒ 第 11..20 件落第二排；服务端
	#   `SPIRIT_PANEL_LIMIT = 20`（`fake_flash_server.py:11166`）⇒ 两行就是全部容量。
	#   旧写法 `for k in 10` 只填一排：面板 ≥11 件时多出的件在客户端**不显示、
	#   不可拾取/卖出**（服务端明明存着）。场景第二排 10 格已由生成器补烘
	#   （`开发工具/生成意志学习场景.py` range(20) + 量具表 `截意志学习页.gd`）。
	for k in 20:
		var 槽 := _件(页, "意志容器/意志格_%d" % k) as Control
		if 槽 == null:
			continue
		槽.visible = false
		if k >= 数组.size():
			continue
		var 项 := 图鉴项(数组[k])
		if 项.is_empty():
			continue
		槽.visible = true
		var 图 := _件(页, "意志容器/意志格_%d/图标" % k) as TextureRect
		图.texture = load(str(项.get("icon", ""))) as Texture2D
		_挂自转(图, 项)
		var 名 := _件(页, "意志容器/意志格_%d/名称" % k) as Label
		名.text = str(项.get("name", ""))
		名.add_theme_color_override("font_color", Color(str(项.get("textColor", "#ffffff"))))
		# `YiZhiStudyCell:92-104`：只有**非灰色**才有「拾取」；有拾取时卖出右对齐、纯灰色时卖出居中
		var 灰 := str(项.get("color", "")) == "gray"
		var 拾 := _件(页, "意志容器/意志格_%d/拾取" % k) as Control
		拾.visible = not 灰
		var 卖 := _件(页, "意志容器/意志格_%d/卖出" % k) as Label
		卖.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if 灰 else HORIZONTAL_ALIGNMENT_RIGHT
		_挂格提示(页, 槽, 项, 1, {"id": str(数组[k])})
		# ⚠ Godot 的 Label 默认 `mouse_filter=IGNORE` ⇒ 不先设 STOP，下面两条
		#   `gui_input` **永远收不到**（点击直接穿透到更下层的图标上）——2026-10-20
		#   玩家实机报「学习到的意志无法拾取、点拾取/卖出没反应」正是这一条
		#   （量具 `开发工具/验意志一键钮.gd` 实测：点「拾取」后 hovered=图标）。
		#   原版这两个字是 `MLabel + buttonMode + useHandCursor + CLICK`
		#   （`YiZhiStudyCell.as:95-101,109-117`）⇒ 一律 STOP + 手型光标。
		# ⚠ 传**面板位 k**（原版 `this._position`），不是 id —— 夹具按位置索引面板数组
		卖.mouse_filter = Control.MOUSE_FILTER_STOP
		卖.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_独接输入(卖, _格按钮.bind(窗口, "卖出", k))
		if not 灰:
			拾.mouse_filter = Control.MOUSE_FILTER_STOP
			拾.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			_独接输入(拾, _格按钮.bind(窗口, "拾取", k))


## 背包/穿戴格的内容（2026-10-03 接 `1823` 时补——他们留的 `_填背包格` 活）：
## 原版 `YiZhiCell.createChildren` 是运行期造 [格底, 悬停框, 名称, 等级] + 有货 `addChildAt(图标,1)`；
## 本场景背包格只有空 Control（格底皮在容器上），所以这里运行期挂 **图标 + 等级** 两件套。
## 行 = `cmd7` 的 {id,color,slot,exp,level}；icon 路径从图鉴拿（`_填学习格` 同一条链）。
## P2-1 图标自转 —— 照 `RotateComponent`（`:97-101` tick 加 `_speed` 度、`:90-102` 绕自身中心）。
## 速度 = 图鉴项 `speed`（`YiZhiData.setTextColor:204-239`：灰0/绿1/蓝3/黄3/粉5/紫5/红7/淡粉7）。
## 三个图标点都走这里：学习格（场景节点）/背包穿戴格与升级槽（运行期 new）⇒ 统一 `set_script`。
## `speed=0`（灰）不挂 ⇒ 不转，与原版一致（原版 `RotateComponent` 也只对非灰加 tick）。
static func _挂自转(图: TextureRect, 项: Dictionary) -> void:
	if 图 == null:
		return
	var 转速 := float(项.get("speed", 0))
	if 转速 == 0.0:
		return
	图.set_script(load("res://脚本/界面/组件/意志格图标.gd"))
	图.set("转速", 转速)
	图.pivot_offset = 图.size / 2.0	# `start():65-66` 的 `-(w/2)` 补偿 ⇒ 绕自身中心


static func _填格内容(页: Control) -> void:
	_填一格层(页, "背包容器", 30, true)
	_填一格层(页, "穿戴容器", 8, false)
	_刷合成钮态(页)


## `updateHeChengButtonState:301-311`：`yiZhiPackDatas.length > 1` ⇒ enabled，否则 disabled。
## ⚠️ `yiZhiPackDatas` **不含升级槽那件** —— `onSpirit_updateSpiritInventory:208-215` 把
##   slot==0 分给 `yiZhiUpgradeData`，只 push slot>0。工程 `spirit_bag` 是 `slot >= 0`
##   （见 `游戏会话.gd:2348` 注释）⇒ 这里必须自己过滤，否则「1 件背包 + 升级槽 1 件」
##   会被算成 2 件而点亮（原版是灰的）。
## ⚠️ 必须在 `_绑三态钮` **之前**定 —— 那个函数见 `disabled` 直接 return（不接三态、
## 只设灰字与箭头），所以顺序只能是「先填数据 → 再绑钮」（`渲染背包` 里已这么排）。
static func _刷合成钮态(页: Control) -> void:
	var 钮 := _件(页, "一键合成") as BaseButton
	if 钮 == null:
		return
	var 背包件数 := 0
	for 行 in _宿主._session.spirit_bag:
		if typeof(行) == TYPE_DICTIONARY and int((行 as Dictionary).get("slot", 0)) > 0:
			背包件数 += 1
	钮.disabled = 背包件数 <= 1

static func _填一格层(页: Control, 容器: String, 数量: int, 背包: bool) -> void:
	var 行集: Array = _宿主._session.spirit_bag if 背包 else _宿主._session.spirit_equipped
	var 按槽: Dictionary = {}
	for 行 in 行集:
		if typeof(行) == TYPE_DICTIONARY:
			按槽[int((行 as Dictionary).get("slot", 0))] = 行
	var 上界 := 数量 if 背包 else 数量 + 1		# 穿戴 8 格 = 格_1..格_8 ⇒ range 上界 9（闭区间差一）
	for i in 上界:
		# 背包 slot 1..30 → 格_0..29；穿戴 slot -1..-8 → 格_1..格_8（穿戴容器没有格_0）
		# ⚠️⚠️ 2026-10-22 修（用户实机报「左下角无法装备意志」）：穿戴 8 格的循环上界
		#   必须是**闭区间**（格_8 也要进）。旧写法 `for i in 数量(8)` 只走到格_7 ——
		#   格_8（穿戴盘左下，offset [-4,161]）从没接过拖放、没填过内容 ⇒ 拖任何意志
		#   进左下格都**没有任何反应**（与 §3.183 的 match 错位同族：边界差一个 ⇒ 静默失灵）。
		#   背包容器有格_0（30 格），穿戴容器没有 ⇒ 只有穿戴要 +1 且从 i=1 起。
		if not 背包 and i == 0:
			continue
		var 格 := _件(页, "%s/格_%d" % [容器, i]) as Control
		if 格 == null:
			continue
		# 每格都挂成**可拖拽源**（空格子也要能当落点 ⇒ 归属一律填）。
		# 协议槽位号：背包 1..30 → `i+1`；穿戴 -1..-8 → `-i`（与下面 `按槽.get` 同一套映射）。
		_接拖放(格, "意志背包" if 背包 else "意志穿戴", (i + 1) if 背包 else -i)
		for 旧 in 格.find_children("格图标", "TextureRect", true, false):
			(旧 as Node).free()
		for 旧 in 格.find_children("格名称", "Label", true, false):
			(旧 as Node).free()
		for 旧 in 格.find_children("格等级", "Label", true, false):
			(旧 as Node).free()
		var 行: Dictionary = 按槽.get((i + 1) if 背包 else -i, {})
		if 行.is_empty():
			continue
		var 项 := 图鉴项(行.get("id", ""))
		# type2 格提示：`YiZhiCell.setToolTip:311-317` → `YiZhiTip.createToolTip2`
		# （`_type=2`：彩名+等级 / 经验 exp/maxExp / 红字 desc / 白字 detailDesc）。
		# 2026-10-03 欠账（「`spirit_items` 时代接不了」）到此结清：`spirit_bag` 已拆出整表。
		_挂格提示(页, 格, 项, 2, 行)
		var 图 := TextureRect.new()
		图.name = "格图标"
		图.position = Vector2(4, 4)
		图.size = Vector2(56, 56)		# 原版图标 56×56 视觉居中（`YiZhiCell:196-208` 图标 x=y=4）
		图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		图.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		图.mouse_filter = Control.MOUSE_FILTER_IGNORE
		图.texture = load(str(项.get("icon", ""))) as Texture2D
		_挂自转(图, 项)
		格.add_child(图)
		# ⚠️⚠️ 2026-10-23 补（用户实机报「意志光有等级是不对的，你看一下单机版是怎么写的」）：
		#   原版 `YiZhiCell.drawYiZhi:195-208` 每格是 **图标 + 名称 + 等级** 三件——
		#   `_nameLabel`（`createChildren:113-119`：宽 64、y=**32**、居中、色 = `textColor`）、
		#   `_levelLabel`（`:120-126`：宽 64、y=**46**、居中、`"Lv."+level`）。
		#   工程旧实现只挂了图标 + 等级 ⇒ 格子里只有一个等级数。名称/等级都吃 textColor
		#   （品质色），与图标自转速度同源（`_挂自转` 那条链）。
		var 名 := Label.new()
		名.name = "格名称"
		名.position = Vector2(0, 32)		# 原版 `createChildren:117` y=32（工程格同为 64×64，原值）
		名.size = Vector2(64, 16)
		名.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		名.add_theme_font_size_override("font_size", 12)
		名.add_theme_color_override("font_color", Color(str(项.get("textColor", "#ffffff"))))
		名.mouse_filter = Control.MOUSE_FILTER_IGNORE
		名.text = str(项.get("name", ""))
		格.add_child(名)
		var 级 := Label.new()
		级.name = "格等级"
		级.position = Vector2(0, 46)		# 原版 `:123` y=46
		级.size = Vector2(64, 16)
		级.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER	# 原版 align="center"（旧实现右对齐，错）
		级.add_theme_font_size_override("font_size", 12)
		级.add_theme_color_override("font_color", Color(str(项.get("textColor", "#ffffff"))))
		级.mouse_filter = Control.MOUSE_FILTER_IGNORE
		级.text = "Lv.%d" % int(行.get("level", 1))
		格.add_child(级)


## `sellOne / pickUpOne`（`YiZhiStudyCell:109-117`）传的是 **`this._position`（面板位，不是 id）**。
## 2026-10-03 接 1823 时顺手纠了合并轮带来的错位：旧 bind 喂的是数组里的 **id**，
## 夹具 `_pick/_sell_spirit_panel_items(raw_positions)` 按**位置**索引——id≥面板长度时会被整批丢弃。
static func _格按钮(事件: InputEvent, 窗口, 动作: String, 面板位: Variant) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed:
		var 发: bool = false
		match 动作:
			"拾取": 发 = 窗口._session.spirit_pick(int(面板位))
			"卖出": 发 = 窗口._session.spirit_sell(int(面板位))
		if not 发:
			窗口._show_hint("%s意志要在服务端结算（离线不模拟）" % 动作)


# ═════════════════════ 二、意志背包窗（663×548）═════════════════════

static func 渲染背包(窗口) -> void:
	_宿主 = 窗口
	var 页: Control = 窗口._instantiate_page(背包场景)
	# 学习页没开时的拾取（如自动升级在后台跑）不该留成"过时飞入" ⇒ 到这就清。
	窗口._session.spirit_picked.clear()
	# 开面板 = action0（原版 `showYiZhiPackWindow` 同款）：回帧 cmd6/7 供意志力、格锁态、格内容。
	if not _面板已开:
		_面板已开 = 窗口._session.spirit_open()
	# 意志力 = `YiZhiManager.caculateYiZhiLi:168-181`（穿戴数组的 Σ rongHeExp / 30）——
	# 2026-10-03 接 `1823` 后走真账：穿戴数组 = cmd7(is_bag=false) 的 `session.spirit_equipped`。
	_写文字(页, "意志值框", str(窗口._session.意志力()))
	# 顺序（2026-10-19 阶段二调）：**先数据后皮**。
	#   `_填格内容` → 填 38 格 + 定一键合成 disabled；
	#   `_刷新格锁态` → 照 `lockCell`「先 clear 再挂锁」压掉锁格里的残留；
	#   钮表循环 → `_绑三态钮` 按上一步的 disabled 分流（disabled 时不接三态）。
	_填格内容(页)
	_刷新格锁态(页)
	for 件名 in 背包钮表:
		var 定: Array = 背包钮表[件名]
		var 字 := _件(页, "%s/%s" % [件名, 定[1]]) as Label
		_绑三态钮(页, 件名, 派生图 + "%s.png" % 定[0], str(定[0]), 字)
		_接背包钮(页, 件名, str(定[2]), 窗口)
	_接介绍开关(页, 窗口)
	_接格悬停(页)
	# 背包锁格点击 ⇒ 扩容确认（`clickCellHandler` 只挂 `_packCells`；穿戴格没有这回事）。
	# 走 `gui_input` 而不是 `pressed`：格子是 Control 不是 Button，且拖放也占这条事件链
	# （`_点背包格` 自己按 `state` 分流，开格/有货格点击一律空转，与 AS3 一致）。
	for k in 30:
		var 格 := _件(页, "背包容器/格_%d" % k) as Control
		if 格 != null:
			_独接输入(格, _格输入.bind(格, 页, 窗口))
	_接升级槽(页, 窗口)
	_接意志力提示(页, 窗口)
	_接人物立绘(页, 窗口)


## 锁格点击入口。只认左键按下；开格点击空转（`_点背包格` 里按 `packLimit` 判）。
static func _格输入(事件: InputEvent, 格: Control, 页: Control, 窗口) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed \
			and (事件 as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_点背包格(格, 页, 窗口)


## `YiZhiCell:163-166 / 134-137`：`overHandler` 把 `cellOverSkin` 显出来、
## `outHandler` 回到的是 **`_selected`**（不是 false）⇒ 选中态（= 锁定勾选的升级槽、扩格时被点亮的
## 那一排背包格）移开也常亮。`_overSkin` 自己 `mouseEnabled=false` ⇒ 场景里已烘 `mouse_filter=2`，
## 不会像学习页那回那样和格子互相抢 hover（同一个坑的两种形态，别再让它长回来）。
static func _接格悬停(页: Control) -> void:
	# 背包 30 格：初值 `packLimit=30` ⇒ 全开；穿戴 8 格：只有 `k <= equipLimit` 的开
	# （`updatePackLimit:516-534` / `updateEquipLimit:209-227`）。
	for k in 30:
		_接一格悬停(页, "背包容器/格_%d" % k)
	for k in range(1, 9):
		if _穿戴格开着(k):
			_接一格悬停(页, "穿戴容器/格_%d" % k)
	_接一格悬停(页, "升级格")


## `updateEquipLimit:209-227`：`i < equipLimit` ⇒ `unLockCell()`；否则 `forbidCell(carrayInfo[i])`。
## 初值 `equipLimit=1`（`YiZhiManager.as:56`）⇒ 只有第 1 格开着，2..8 画封印。
static func _穿戴格开着(k: int) -> bool:
	return k <= _穿戴上限()


static func _穿戴上限() -> int:
	# 服务端 `onSpirit_updateInventoryLimit(packLimit, equipLimit)` 的第二值（cmd6）——
	# 2026-10-03 接 `1823` 后有真账：夹具 `spirit_equip_limit(等级)` 按 `Spirit.common.carry`
	# 现算（55/58/…/76 八档）。离线会话初值 1 = 原版 `YiZhiManager.as:56` 的 `equipLimit=1`。
	return 会_取("spirit_equip_limit", 1)

## 从会话读一个字段（渲染入口都经宿主 `_session`；这里只为静态函数好写，读不到回退缺省）。
static func 会_取(名: String, 缺省: Variant) -> Variant:
	if _宿主 == null:
		return 缺省
	var v: Variant = _宿主._session.get(名)
	return 缺省 if v == null else v


## `carrayInfo` = `common.carry` 的键名里那个数字（`setCarrayInfo:536-554` 取 `levelNN` 的 NN）
## 按数值排序 ⇒ [55,58,61,64,67,70,73,76]；`forbidCell(carrayInfo[i])` 的 i 是**格下标**（0 基）。
static func 穿戴开启等级(k: int) -> int:	## k 是 1 基的格号
	if _常量.is_empty():
		_常量 = _读(常量路径)
	var 表: Dictionary = (_常量.get("common", {}) as Dictionary).get("carry", {}) as Dictionary
	var 列: Array = []
	for 键名 in 表:
		列.append(int(str(键名).substr(5)))
	列.sort()
	return int(列[k - 1]) if k - 1 < 列.size() else 0


## 背包格开没开 —— `updatePackLimit:516-534` 的判据是**格下标 0 基 vs packLimit（格数）**：
##   `if(_loc3_ < param1) unLockCell(); else lockCell();`
## `spirit_pack_limit` 就是那个 `param1`（cmd6 第 1 参；服务端新档默认 5 ⇒ 6..30 全锁）。
static func _背包格开着(下标: int) -> bool:
	return 下标 < int(会_取("spirit_pack_limit", 5))


## 选中态 = 黄框常亮。AS3 就是 `YiZhiCell.selected` setter：`_selected=值; _overSkin.visible=值`
## ⇒ 工程同款：meta 钉真值（`_设格悬停回落` 要读它）+ 直接刷框。
## 用在两处：锁定勾选的升级槽（`_锁定勾选变了`）、扩容预览点亮的一排背包格。
static func _设选中(格: Control, 开: bool) -> void:
	if 格 == null:
		return
	格.set_meta("selected", 开)
	_设格悬停(格, 开)


## 扩容一格要多少元宝 —— 照 `clickCellHandler:571` 的累加：
##   `while(_loc7_ < _loc4_) { _loc5_ += common.extend[_loc7_ - 4]; _loc7_++ }`
## `_loc7_` 是 `_packCells` 下标（0 基），从 packLimit 起到 position-1；`_loc4_` = position（1 基）。
## 服务端口径（`spirit_pack_extension_cost`）：`Σ extend[limit-4]`，limit ∈ [max(5,当前), min(30,目标))。
## 两边等价：当前=5、目标=8 ⇒ extend['1']+['2']+['3'] = 10+20+30 = 60。
## `common.extend` 是 dict（键 '1'..'25'，值 10..250 等差）。
static func _扩容花费(当前: int, 目标: int) -> int:
	if _常量.is_empty():
		_常量 = _读(常量路径)
	var 表: Dictionary = (_常量.get("common", {}) as Dictionary).get("extend", {}) as Dictionary
	var 总 := 0
	var 格数 := maxi(5, 当前)			# 服务端同款钳制（`max(5, current_limit)`）
	var 止 := mini(30, 目标)			# `min(30, target_limit)`
	while 格数 < 止:
		总 += int(表.get(str(格数 - 4), 0))	# 格数 5 ⇒ extend['1']（=10）
		格数 += 1
	return 总


## 锁态那一格：`lockCell:185-193` 干四件事 —— `_state=0`、`clear()`、
## **`_bgSkin.visible=false`**（格底隐）、挂 `UISwf_BailianCopy_Lack`（`x=-10,y=-16`，
## 素材由 `开发工具/导出意志格锁.py` 出，84×81）+ **不给 tooltip**（那是 `forbidCell` 的）。
## `unLockCell:168-176`：去锁图、格底显、把悬停框加回子列表。
## ⚠️ `lockCell` **不动 `_overSkin`** ⇒ 锁格悬停照样亮黄框 —— 原版就这样，保真（别"顺手修了"）。
static func _刷新格锁态(页: Control) -> void:
	for i in 30:
		var 格 := _件(页, "背包容器/格_%d" % i) as Control
		if 格 == null:
			continue
		var 底 := 格.get_node_or_null("格底") as CanvasItem
		var 锁 := 格.get_node_or_null("格锁") as Node
		if _背包格开着(i):
			if 锁 != null:
				锁.queue_free()
			if 底 != null:
				底.visible = true
		else:
			if 底 != null:
				底.visible = false
			if 锁 == null:
				var 图 := TextureRect.new()
				图.name = "格锁"
				图.texture = load("res://素材/界面/原版窗口/意志背包/格锁.png") as Texture2D
				图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				图.position = Vector2(-10.0, -16.0)	# `lockCell:191-192` 的 `_icon.x/y`
				图.size = Vector2(84.0, 81.0)			# sprite bounds 整张（含注册点补偿）
				图.mouse_filter = Control.MOUSE_FILTER_IGNORE
				格.add_child(图)
				格.move_child(图, 1)					# `addChildAt(_icon,1)`：压在格悬停下面
	for k in range(1, 9):
		var 路 := "穿戴容器/格_%d" % k
		var 封 := _件(页, 路 + "/封印") as CanvasItem
		var 框 := _件(页, 路 + "/格悬停") as CanvasItem
		var 开 := _穿戴格开着(k)
		if 封 != null:
			封.visible = not 开
		if 框 != null:
			框.visible = false		# 被摘出显示列表 ⇒ 既不亮也不残留
		if not 开:
			_挂文字提示(页, _件(页, 路) as Control,
					填(键("YIZHI_CELL_OPEN_TOOLTIP"), [穿戴开启等级(k)]), "穿戴%d" % k)


## 背包锁格的点击 —— `clickCellHandler:563-586`（只挂在 `_packCells` 上，穿戴格没有这回事）：
##   `state == 0`（锁态）才进；从 `packLimit` 到 `position-1` 逐个 `selected=true`（预览要开哪些格）；
##   按 `common.extend` 累算总价；弹「确定/取消」窗带 `{yuanBao, limit}` 两个参数。
## 开格点击什么都不做（AS3 同样空转）。
static func _点背包格(格: Control, 页: Control, 窗口) -> void:
	if 格 == null:
		return
	# 名字是 "格_<下标>"（场景 `格_0..格_29`）⇒ 数字从下标 2 起（"格_" 两个字符）。
	# ⚠️ 别写 substr(3)：GDScript String 按字符计（UTF-32），"格_7" 只有 3 个字符，
	#   substr(3) 得空串、int("") 静默变 0 ⇒ 点任何锁格都当成"第 0 格"被当成开格挡掉。
	var 下标 := int(str(格.name).substr(2))
	if _背包格开着(下标):
		return
	var 当前 := int(会_取("spirit_pack_limit", 5))
	var 目标 := 下标 + 1						# position 是 1 基（`initView:433` `_loc6_.position = _loc4_`）
	var 页控件 := 页
	for j in range(当前, 目标):
		_设选中(_件(页控件, "背包容器/格_%d" % j) as Control, true)
	var 总价 := _扩容花费(当前, 目标)
	# `FamillyPopUpWindow.popUpWindow` 的确定/取消两款 ⇒ 工程 `输入确认弹.弹消息`
	# （回调：确定=1 / 取消=2，`MDialog.OK/CANCEL` 同值）。
	# ⚠️ 遮罩用**窗壳全屏 overlay**（stage 居中），别传页面控件——2026-10-23 与吞噬确认
	# 同批修（用户实机报「弹窗位置错误」：页面内居中会随页面飘）。
	确认弹.弹消息(窗口._overlay, 填(键("YIZHI_EXPAND_PACK_CELL"), [总价]), func(回: int) -> void:
		_撤扩容点亮(页控件, 当前, 目标)			# `sureToExpandCell:353` 第一句就是这句
		if 回 != 1:
			return
		var 现金 := int(窗口._session.player_stats.get("cash", 0))
		if 总价 > 现金:
			# `sureToExpandCell:355-357`：`yuanBao > API.dataCenter.cashMoney` ⇒ addNotice
			窗口._show_hint(键("YIZHI_NO_ENOUGH_YUANBAO_TIP"))
			return
		窗口._session.spirit_extend(目标))		# `requestSpirit_bagExtend(limit)`


## `cancelToExpandCell:197-206`：从 `packLimit` 到 `limit-1` 逐个 `selected=false`。
## 确定/取消/点暗层三条路都归它（保真：原版取消回调与确定回调第一行都是它）。
static func _撤扩容点亮(页: Control, 当前: int, 目标: int) -> void:
	for j in range(当前, 目标):
		_设选中(_件(页, "背包容器/格_%d" % j) as Control, false)


static func _接一格悬停(页: Control, 路: String) -> void:
	var 格 := _件(页, 路) as Control
	var 框 := _件(页, 路 + "/格悬停") as CanvasItem
	if 格 == null or 框 == null:
		return
	格.set_meta("selected", false)	# 先钉一个真值，省得 `get_meta` 拿不到键刷 ERROR
	格.set_meta("over", 框)
	格.mouse_entered.connect(_设格悬停.bind(格, true))
	格.mouse_exited.connect(_设格悬停回落.bind(格))


static func _设格悬停(格: Control, 显: bool) -> void:
	var 框 := 格.get_meta("over") as CanvasItem if 格.has_meta("over") else null
	if 框 != null:
		框.visible = 显


## `outHandler` 的 `_overSkin.visible = _selected`：移开时回落到选中态而不是关掉。
static func _设格悬停回落(格: Control) -> void:
	var 框 := 格.get_meta("over") as CanvasItem if 格.has_meta("over") else null
	if 框 != null:
		框.visible = bool(格.get_meta("selected", false))


## 升级槽 + 「锁定意志」勾选 + 「自动升级意志」钮这三件是一组联动的：
##   `onLockCheckBoxClick:639-660`：槽里**没有货** ⇒ 强制把勾取消、提示「请先将意志拖入升级槽位」；
##     有货 ⇒ 勾选态同步成 `_upgradeCell.selected`（就是让黄框常驻），再 `updateAutoUpgradeBtnState`；
##   `updateAutoUpgradeBtnState:679-693`：**槽有货 且 已勾** 才 enabled，否则 disabled 并把跑着的自动升级停掉；
##   `onAutoUpgradeBtnClick:662-677`：跑着就停；没跑要求"有货且已勾"，否则直接 return（不发请求）。
## 槽里的货来自拖放（`onUpgradeCellMouseUp:615-637` → `requestSpirit_move(slot,0)`）——
## 拖放与 1823 都还没接（#8 / #63）⇒ 离线时 `_升级槽货` 恒 null：勾不上、钮恒灰。
## 这不是"半截实现"，是原版在无数据时的同一副样子；接线后要回到这条链上。
static var _升级槽货: Dictionary = {}


static func _接升级槽(页: Control, 窗口) -> void:
	# —— 升级格：协议槽位号 **0** ——
	# ⚠️⚠️ 2026-10-24 修（用户实机报「升级过后，意志无法从升级框里取出」）：
	#   原版升级格是 `new YiZhiCell()`（`YiZhiPackWindow.as:463`、`position = 0`），
	#   `downHandler:93-99` 只要「有货且有图标」就起拖 ⇒ **升级格能当拖出源**。
	#   「只接不吐」只在**接收拖入**那侧（`onUpgradeCellMouseUp:615-637` 对
	#   `dragData.slot == 0` 即拖自己/拖其它槽 0 直接吐掉）。旧实现把升级格接成
	#   可拖出=false + `_处理意志拖放` 里 `源槽==0` 直接 return ⇒ 升级槽里的意志
	#   永远取不出（用户报的真凶）。改：升级格也**可拖出**，落点侧照常处理。
	var 槽 := _件(页, "升级格") as Control
	if 槽 != null:
		_接拖放(槽, "意志升级", 0, true)
	_填升级格(页)
	var 勾 := _件(页, "锁定勾选") as CheckBox
	var 钮 := _件(页, "自动升级钮") as BaseButton
	if 勾 != null:
		# ⚠️⚠️ 2026-10-24 修（用户实机报第二刀：「锁定意志在自动升级开始后就没有被
		#   勾选了，自动升级意志也变灰了」）：自动升级每跳都触发重渲 ⇒ 页面重建 ⇒
		#   勾选框恢复场景默认**未勾** ⇒ 钮 disabled。原版 Flash 窗常驻、勾选天然
		#   持续 ⇒ 工程必须显式恢复：勾选态记在会话（`自动升级锁定`），渲染时
		#   `set_pressed_no_signal` 回填（不走信号，避免递归触发 `_锁定勾选变了`）。
		if _宿主 != null and _宿主._session != null:
			勾.set_pressed_no_signal(bool(_宿主._session.自动升级锁定))
		勾.toggled.connect(_锁定勾选变了.bind(页, 窗口))
	if 钮 != null:
		钮.pressed.connect(_点自动升级.bind(页, 窗口))
	_刷新自动升级钮(勾, 钮)
	# 停下来的那句话是**一次性**的（原版走 `addNotice`）—— 渲染时消费掉，别反复弹。
	var 提 := String(_宿主._session.自动升级提示) if _宿主 != null else ""
	if not 提.is_empty():
		_宿主._session.自动升级提示 = ""
		窗口._通知(提)
		_件(页, "自动升级提示").text = 提


## 「自动升级意志」钮 —— 原版 `YiZhiPackWindow.onAutoUpgradeBtnClick:662-677`：
## **跑着就停**；没跑则要求"**有货 且 已勾**"，否则直接 return（一个请求都不发）。
## 文案在「自动升级意志 / 停止自动融合」之间换（`startAutoUpgrade` 与 `onAutoUpgradeStopped`）。
## ⚠️ 原版 `startAutoUpgrade(0)` 传的就是**升级槽的槽位号 0**。
static func _点自动升级(页: Control, 窗口) -> void:
	var 会话 = _宿主._session
	if 会话 == null:
		return
	if bool(会话.自动升级跑着):
		会话.自动升级_停()
		窗口._refresh_current()
		return
	if _升级槽货.is_empty():
		return
	var 勾 := _件(页, "锁定勾选") as CheckBox
	if 勾 == null or not 勾.button_pressed:
		return
	会话.自动升级_开(0)
	窗口._refresh_current()


## 给一个输入控件的 `gui_input` **独接一条线**（口径同 `_接拖放`：先断尽再接）。
## ⚠️ 为什么必须独接：本文件的渲染函数**每次回帧都会重跑**（学习页每收一条意志回帧
##   重建一次、背包页 cmd7 同理），而 `bind()` 每次产生的是**新 Callable** ⇒ Godot
##   的连接去重（同 Callable 才并）形同虚设 ⇒ 不先断就会**叠线**：刷新 N 次后点一次
##   「拾取/卖出」发 N 个请求。这既是浪费，也是 §3.183 服务端双表 pop 竞态
##   （两颗 pop 之间夹毫秒级查价，多个并发请求撞 50ms tick）的客户端放大器——
##   用户原话「一键出售时不时掉线」的隐性推手之一。
static func _独接输入(控件: Control, 回调: Callable) -> void:
	for 连 in 控件.gui_input.get_connections():
		控件.gui_input.disconnect(连["callable"])
	控件.gui_input.connect(回调)


## 把一个意志格挂成拖放件（**运行期挂** —— 场景是生成器产物，不许手改，见文件头）。
## `归属` 用 `"意志背包" / "意志穿戴" / "意志升级"`；`槽位号` 是**协议里的槽位号**。
static func _接拖放(格: Control, 归属: String, 槽位号: int, 可拖出: bool = true) -> void:
	格.set_script(意志格)
	格.格子归属 = 归属
	格.槽位号 = 槽位号
	格.可拖拽 = 可拖出
	for 连 in 格.拖放.get_connections():
		格.拖放.disconnect(连["callable"])
	格.拖放.connect(_处理意志拖放)


## 落下判定 —— 逐条照原版两条处理器：
##   `YiZhiPackWindow.onUpgradeCellMouseUp:615-637`（升级格）：拖自己 ⇒ 不做；空 ⇒ move(源,0)；有货 ⇒ 融合；
##   `YiZhiCell.upHandler:229-255`（背包/穿戴格）：`_state != 2`（锁/封印）⇒ 直接吐掉；
##     空格 ⇒ 黄不许穿（`YIZHI_YELLOW_NOT_CHUAN_DAI`）+ `requestSpirit_move(源, 目的)`；
##     有货 ⇒ `rongHeYiZhi(目的那件, 拖来那件)`（融合，含三条客户端前置）。
## 融合前置（黄+黄 / 满级）原版在客户端弹 `FamillyPopUpWindow`；服务端 `_merge_spirit_slots`
## 也会挡 —— 客户端前置只是提前说明，**服务端仍是权威**。
## ⚠️ 2026-10-19 修一个接线 bug：`意志格._drop_data` 的 `拖放` 信号第 4 参传的是
##   **来源格**的槽位号（`字典.get("槽位号")` 取自拖放载荷），旧代码把它当"目标槽"用
##   ⇒ move(源,源) 全部落空。现在目标槽从 `目标格.槽位号` 现取。
static func _处理意志拖放(来源格: Control, 目标格: Control, _归属: String, _来源槽: int) -> void:
	if 来源格 == null or 目标格 == null or 来源格 == 目标格:
		return
	var 源槽 := int(来源格.get("槽位号"))
	# ⚠️ 2026-10-24 修：原版升级格可当拖出源（`YiZhiCell.downHandler:93-99` 有货即起拖），
	#   「只接不吐」只存在于接收拖入侧（`onUpgradeCellMouseUp` 对 `dragData.slot==0`
	#   拖自己直接吐掉，等价于下面「来源格==目标格」的早退）。旧实现这里 `源槽==0`
	#   直接 return ⇒ 升级槽里的意志拖不出去（用户报「无法从升级框取出」）。
	var 目标归属 := str(目标格.get("归属"))
	var 目标槽 := int(目标格.get("槽位号"))
	# 锁/封印格不当落点（AS3 `upHandler:232-235` 的 `_state != 2` ⇒ removeDragDataProxy + return）
	if 目标归属 == "意志背包" and not _背包格开着(目标槽 - 1):
		return
	if 目标归属 == "意志穿戴" and not _穿戴格开着(-目标槽):
		return
	# 落点有货 ⇒ 融合（含前置 + 确认）；空格才谈移动/穿戴
	var 目标行 := _格上那件(目标格, 目标槽)
	if not 目标行.is_empty():
		_融合前置(目标行, _格上那件(来源格, 源槽), 目标槽)
		return
	if 目标归属 == "意志穿戴" and int(_格上那件(来源格, 源槽).get("color", 0)) == 意志黄:
		# `upHandler:243-246`：黄 + position<0 ⇒ `YIZHI_YELLOW_NOT_CHUAN_DAI`，一个请求都不发
		_宿主._show_hint(键("YIZHI_YELLOW_NOT_CHUAN_DAI"))
		return
	_宿主._session.spirit_move(源槽, 目标槽)      # 背包↔背包 / 背包↔穿戴 / 穿脱 / 放进升级槽


## 某一格上那件意志（按协议槽位号查表；空格 = 空 Dictionary）。
## ⚠️⚠️ 2026-10-23 修（用户实机报「身上的意志无法吞噬背包中的意志」）：必须**按槽位号
##   分流两张表**——工程 `spirit_bag` 收 `slot >= 0`（背包 1..30 + 升级槽 0），
##   `spirit_equipped` 收负数（穿戴 -1..-8）。旧实现只查 bag ⇒ 穿戴位（负数）永远取不到行：
##   ① 身上件拖到背包有货格 ⇒ 来源行空 ⇒ 融合前置全跑偏（不弹确认/参数错）；
##   ② 背包件拖到身上有货格 ⇒ 目标行空 ⇒ 该融合的场景走了 `spirit_move`（服务端拒绝）；
##   ③ 升级格（槽 0）有货 ⇒ 目标行空 ⇒ 该融合的也走了 move。
##   原版 `YiZhiCell.upHandler:237-250` 的融合分支用的是**落点格自己持有的 `_yiZhiData`**
##   与拖来的 `dragData`，两边都可能来自任一张表 ⇒ 不分来源，只看槽位号。
static func _格上那件(_格: Control, 槽: int) -> Dictionary:
	# ⚠️ 显式标注 Array：三元两边一个是 bag 一个是 equipped，`:=` 推断不出 set type
	#    （GDScript 编译直接报错）⇒ 别手滑改回 `:=`。
	var 表: Array = _宿主._session.spirit_bag if 槽 >= 0 else _宿主._session.spirit_equipped
	for 行 in 表:
		if typeof(行) == TYPE_DICTIONARY and int((行 as Dictionary).get("slot", -999)) == 槽:
			return 行
	return {}


## 融合三条前置 + 确认弹 —— 逐条照 `YiZhiManager.rongHeYiZhi:420-513`：
##   1. 双黄 ⇒ `YIZHI_YELLOW_NOT_RONGHE`（确定/取消都是空回调）；
##   2. 双满级 / 一方满级一方黄 ⇒ `YIZHI_MAX_LEVEL_NOT_RONGHE`（%1 = 20）；
##   3. 定主副（黄永远当副；否则比 color，大的当主；同色比 level，`>=` 时来件当主）
##      ⇒ 主已满级 ⇒ 同 2；
##   4. 过审才弹 `YIZHI_RONGHE_TIP`（%1=主名 %2=副名 %3=副的 rongHeExp），
##      预计升级再缀 `YIZHI_RONGHE_TIP_1`（%1=新级）；确定 ⇒ `requestSpirit_oneEatOne(来件, 目的)`。
## ⚠️ 参数顺序：AS3 弹窗带 `{slot1: 来件.slot, slot2: 目的.slot}`，`sureToRongHe` 原样转交
##   ⇒ 工程 `spirit_feed(源槽, 目标槽)`（源=拖来的那件）与之一致。
## `MAX_YIZHI_LEVEL = 20`（`YiZhiManager.as:24`）。
static func _融合前置(目标行: Dictionary, 来源行: Dictionary, 目标槽: int) -> void:
	var 满级 := 20
	var 目色 := int(目标行.get("color", 0))
	var 源色 := int(来源行.get("color", 0))
	if 目色 == 意志黄 and 源色 == 意志黄:
		_宿主._show_hint(键("YIZHI_YELLOW_NOT_RONGHE"))
		return
	var 目级 := int(目标行.get("level", 1))
	var 源级 := int(来源行.get("level", 1))
	if (目级 == 满级 and 源级 == 满级) or (目级 == 满级 and 源色 == 意志黄) \
			or (源级 == 满级 and 目色 == 意志黄):
		_提示满级()
		return
	# 定主副：`_loc3_` = 主（保留、得经验），`_loc4_` = 副（被吞）
	var 主: Dictionary
	var 副: Dictionary
	if 源色 == 意志黄:
		主 = 目标行; 副 = 来源行
	elif 目色 == 意志黄:
		主 = 来源行; 副 = 目标行
	elif 源色 > 目色:
		主 = 来源行; 副 = 目标行
	elif 源色 == 目色:
		if 源级 >= 目级:
			主 = 来源行; 副 = 目标行
		else:
			主 = 目标行; 副 = 来源行
	else:
		主 = 目标行; 副 = 来源行
	if int(主.get("level", 1)) == 满级:
		_提示满级()
		return
	# 预计级：`_loc5_ = 主.exp + 副.rongHeExp`，查 `common.levelUp` 找能达到的最高级
	var 主项 := 图鉴项(主.get("id", ""))
	var 副项 := 图鉴项(副.get("id", ""))
	var 预计 := int(主.get("level", 1))
	if _常量.is_empty():
		_常量 = _读(常量路径)
	var 升级表: Dictionary = (_常量.get("common", {}) as Dictionary).get("levelUp", {}) as Dictionary
	var 总经 := int(主.get("exp", 0)) + 副经验(副)
	var 档 := 满级
	while 档 > int(主.get("level", 1)):
		var 行: Dictionary = 升级表.get("level%d" % 档, {}) as Dictionary
		if not 行.is_empty() and 总经 >= int(行.get(str(主项.get("color", "")), 0)):
			预计 = 档
			break
		档 -= 1
	var 文 := 填(键("YIZHI_RONGHE_TIP"), [主项.get("name", ""), 副项.get("name", ""), 副经验(副)])
	if 预计 > int(主.get("level", 1)):
		文 += 填(键("YIZHI_RONGHE_TIP_1"), [预计])
	# 遮罩挂**窗壳的全屏 overlay**（`功能窗口._overlay` = 「遮罩」节点，`_resize_overlay:1081-1083`
	# 撑到视口全屏）⇒ 弹窗 stage 居中。⚠️⚠️ 2026-10-23 修（用户实机报「意志吞噬的弹窗
	# 位置是错误的」）：旧写法传 `_content.get_child(0)`（当前**页面**）当遮罩 ⇒ 弹窗只在
	# 页面矩形内居中 ⇒ 页面偏左它就偏左（截图里飘在两窗之间）。同款错在扩容确认
	# （`_点背包格` 传 `页控件`）一并修；召唤确认（`:455`）本来就对，以它为准。
	# ⚠️ `_overlay` 无静态类型 ⇒ 必须显式标注 Control（`:=` 推断不出 ⇒ 编译错）。
	var 遮罩: Control = _宿主._overlay
	确认弹.弹消息(遮罩, 文, func(回: int) -> void:
		if 回 == 1:
			_宿主._session.spirit_feed(int(来源行.get("slot", 0)), 目标槽))


## 副件给出的融合经验 —— 原版 `YiZhiData.rongHeExp:92-101`：
##   黄 ⇒ **固定 1200**；否则 ⇒ `common.levelUp.**level1**[colorType] + 自身 exp`
## ⚠️ 是 `level1` 不是"副的级"那一档（原版字面如此，2026-10-19 照抄）。
## 2026-10-21：实现收敛到 `游戏数据.意志融经验()` —— 人物面板「意志力」也是这一条公式，
## 别再在这儿读第二份 levelUp 表（同一真值抄两份，抄漏就静默错）。
## 色名取自**协议 color int**（`SpiritColor.as:6-20`），与旧写法按 id 查图鉴同结果
## （服务端 `_spirit_color_id` 本就从 dat 的 spec.color 推 int）。
static func 副经验(副: Dictionary) -> int:
	return 游戏数据.意志融经验(副)


static func _提示满级() -> void:
	_宿主._show_hint(填(键("YIZHI_MAX_LEVEL_NOT_RONGHE"), [20]))


## 升级槽那一件 —— `spirit_bag` 里 `slot == 0` 的那条。
## ⚠️ 槽 0 **不会**画进背包格（`_填一格层` 的映射是 `按槽.get(i+1)`，0 落不到任何格）：
## 它只住在升级格里。原版对应 `YiZhiPackWindow.setUpgradeData(CocoSpirit)`（`:717-738`）——
## 有货就摆进 `_upgradeCell` 并把勾选态同步过去，没货就清空 + 取消勾选 + 停掉自动升级。
static func _升级槽那件() -> Dictionary:
	if _宿主 == null:
		return {}
	for 行 in _宿主._session.spirit_bag:
		if typeof(行) == TYPE_DICTIONARY and int((行 as Dictionary).get("slot", -999)) == 0:
			return 行
	return {}


## 把槽 0 那件画进升级格（`名称` / `等级` 两枚 Label 是场景里烘好的），并据它刷新勾选与钮。
static func _填升级格(页: Control) -> void:
	var 槽 := _件(页, "升级格") as Control
	if 槽 == null:
		return
	var 行 := _升级槽那件()
	# 先清掉上一次运行期挂的图标（格子是场景节点，会跨渲染复用）
	for 旧 in 槽.find_children("格图标", "TextureRect", true, false):
		(旧 as Node).free()
	_升级槽货 = 行
	var 名 := 槽.get_node_or_null("名称") as Label
	var 级 := 槽.get_node_or_null("等级") as Label
	if 行.is_empty():
		if 名 != null:
			名.text = ""
		if 级 != null:
			级.text = ""
		return
	var 项 := 图鉴项(行.get("id", ""))
	if 名 != null:
		名.text = String(项.get("name", ""))
	if 级 != null:
		级.text = "Lv.%d" % int(行.get("level", 1))
	var 图 := TextureRect.new()
	图.name = "格图标"
	图.position = Vector2(4, 4)
	图.size = Vector2(56, 56)
	图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	图.texture = load(str(项.get("icon", ""))) as Texture2D
	_挂自转(图, 项)
	槽.add_child(图)
	# ⚠️⚠️ 2026-10-24 修（用户实机报「意志的信息会跳在模型后面」）：**图标必须插到
	#   名称/等级之前**。场景子序 = 格底(0)/格悬停(1)/名称(2)/等级(3)，`add_child`
	#   把图标追加到 index 4（最顶层）⇒ 图标盖住名称/等级文字（用户看到信息"跳到
	#   图标后面"）。`move_child(图, 2)` ⇒ 格底<悬停<图标<名称<等级，文字在上层。
	#   背包/穿戴格（`_填一格层`）是先挂图标再挂文字，没这个问题；升级格的文字是
	#   场景预置节点，顺序才反。
	槽.move_child(图, 2)


static func _锁定勾选变了(开: bool, 页: Control, 窗口) -> void:
	# 勾选态记进会话（渲染恢复用，见 `_接升级槽`）。
	if _宿主 != null and _宿主._session != null:
		_宿主._session.自动升级锁定 = 开
	# ⚠️ 原版 `onLockCheckBoxClick:656-660`：**跑着时取消勾 ⇒ 停自动升级**（用户
	#    手感：取消锁定就该停下来）。工程此前缺这条 ⇒ 取消勾后循环还在后台跑。
	if not 开 and _宿主 != null and _宿主._session != null and bool(_宿主._session.自动升级跑着):
		_宿主._session.自动升级_停()
	var 勾 := _件(页, "锁定勾选") as CheckBox
	var 钮 := _件(页, "自动升级钮") as BaseButton
	var 槽 := _件(页, "升级格") as Control
	if _升级槽货.is_empty():
		if 勾 != null:
			勾.button_pressed = false				# :641-646 强制取消
		# :644 那句「请先将意志拖入升级槽位」原版走 `API.ui.addNotice`（**硬编码中文、语言表里没键**）
		# ⇒ 工程等价是 `_通知`（聊天/系统消息那一族）。**同时**镜像进 `_status`：
		#   量具抓图前会把 HUD 藏掉（`_步藏HUD`），只走 _通知 的话门量不到、玩家却在两处都看得见。
		var 提示 := "请先将意志拖入升级槽位"
		窗口._通知(提示)
		窗口._show_hint(提示)
		return
	if 槽 != null:
		槽.set_meta("selected", 开)
		_设格悬停回落(槽)							# 立刻按新选中态重画黄框
	_刷新自动升级钮(勾, 钮)


static func _刷新自动升级钮(勾: CheckBox, 钮: BaseButton) -> void:
	if 钮 == null:
		return
	# 原版这里还会换灰皮与手型（`MButton3.set enabled:460-477`）；本工程 disabled 那一支
	# 由 `_绑三态钮` 的早退分支管 ⇒ 这里只改 enabled，不补第二套皮逻辑。
	钮.disabled = not (not _升级槽货.is_empty() and 勾 != null and 勾.button_pressed)
	# 文案跟着"跑没跑"换（原版 `startAutoUpgrade` 置「停止自动融合」、
	# `onAutoUpgradeStopped` 置回「自动升级意志」）。字挂在 `自动升级钮/字` 上。
	var 字 := 钮.get_node_or_null("字") as Label
	if 字 != null and _宿主 != null:
		var 跑着 := bool(_宿主._session.自动升级跑着) if _宿主._session != null else false
		字.text = "停止自动融合" if 跑着 else "自动升级意志"


## 意志力框的 tooltip（`YiZhiPackWindow.updateYiZhiTipNow:505-514` →
## `getYiZhiPropToopTioInfo:392-405`）：第一行「当前意志：N」，其后每条穿戴一行。
## ⚠️ 2026-10-21 修：原来这里读的是 `页.get_meta("穿戴数组")` / `"意志力"` —— **全工程没有任何
##   一处写这两枚 meta**（`grep 穿戴数组 脚本/ 开发工具/ 测试/` 只命中这一行读）⇒ 提示永远是
##   「当前意志：0」、下面每件穿戴一行也永远缺。而同一扇页上面的数字 `_写文字(页, "意志值框",
##   窗口._session.意志力())` 走的是真账 ⇒ 用户看到的是「数字对、悬停话不对」。
##   真值源和那行数字同一个：`session.spirit_equipped` + `session.意志力()`。
## 无穿戴 ⇒ 只有一行（单行底高 28，公式同学习页那三枚）。
static func _接意志力提示(页: Control, 窗口) -> void:
	var 框 := _件(页, "意志值框") as Control
	if 框 == null or _宿主 == null or _宿主._session == null:
		return
	var 会 = 窗口._session
	_挂文字提示(页, 框,
			意志提示框.意志力提示文案(会.spirit_equipped, int(会.意志力())), "意志值")


static func _接背包钮(页: Control, 件名: String, 动作: String, 窗口) -> void:
	var 钮 := _件(页, 件名) as BaseButton
	if 钮 == null:
		return
	match 动作:
		"打开学习":	# studyHandler:364-367 → `showYiZhiStudyWindow()`
			钮.pressed.connect(窗口.导航到.bind("意志学习"))
		"合成全部":
			# 「一键合成」= action8（夹具 `bagMergeAll` 一次把背包里所有同级对子逐级合完）。
			# 发成功不出声（cmd7 整表回帧驱动重画）；离线才给原版那句回执。
			钮.pressed.connect(func() -> void:
				if not 窗口._session.spirit_merge_all():
					窗口._show_hint(str(背包回执.get(动作, "意志协议要在服务端结算（离线不模拟）"))))
		_:
			# ⚠️ 2026-10-22：`自动升级钮` 也在 `背包钮表` 里（只为蹭 `_绑三态钮` 的换皮），
			#   但它的 pressed 已由 `_接升级槽` 独家接给 `_点自动升级`（`onAutoUpgradeBtnClick`）。
			#   原来这里一个 `_:` 兜底把它**又**接了一条 `spirit_merge_all()` ⇒ 点一下自动升级
			#   会连带真发一次一键合成（§3.182 修好发送后这条就从"无害"变成真 bug）。
			#   **一颗钮只准有一条 pressed 接线**（工程铁律，见文件头与家族子窗的前科）。
			return


## `[意志介绍]` = `showIntroduceWindow:408-411` 的 `reverseDisplay` ⇒ **再点一次收起**。
static func _接介绍开关(页: Control, 窗口) -> void:
	var 牌 := _件(页, "意志介绍") as Control
	if 牌 == null:
		return
	牌.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND	# :177 buttonMode/useHandCursor
	_独接输入(牌, func(事件: InputEvent) -> void:
		if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed:
			var 管理: Node = 窗口.get_parent()
			if 管理 != null and 管理.has_method("打开或收起"):
				管理.call("打开或收起", "意志介绍"))


## 背包/穿戴格上的 `YiZhiTip`（type2）**这一版还没接**：原版格子数据来自 `YiZhiManager`
## 的背包数组（`updateSpiritInventory`），本工程 `session` 里只有学习页在用的 `spirit_items`
## ⇒ 不擅自造第二个键（`对照表` §六 同一条口径）。接协议时补 `_填背包格()` 即可，
## type2 的文案与 `maxExp` 公式已经在 `组件/意志提示框.gd` 里实现并被门验过。


# ═════════════════════ 三、意志介绍窗（455×430，图鉴）═════════════════════

## `drawList:44-72`：`Spirit.items` 全表 → **剔掉 gray** → 按品质序号**降序**（lpink8 … green2）。
static func 渲染介绍(窗口) -> void:
	_宿主 = 窗口
	var 页: Control = 窗口._instantiate_page(介绍场景)
	窗口._session.spirit_picked.clear()
	_填介绍行(页)
	_接介绍滚动(页)


static func _介绍行数据() -> Array:
	if _图鉴.is_empty():
		_图鉴 = _读(图鉴路径)
	var 出: Array = []
	for 编号 in _图鉴:
		var 记 = _图鉴[编号]
		if not (记 is Dictionary) or str((记 as Dictionary).get("color", "")) == "gray":
			continue
		出.append([int(编号), 记 as Dictionary])
	出.sort_custom(func(a, b) -> bool:
		return int(a[1].get("colorRank", 0)) > int(b[1].get("colorRank", 0)))
	return 出


static func _填介绍行(页: Control) -> void:
	var 列 := _件(页, "列表区/内容列") as Control
	if 列 == null:
		return
	for 旧 in 列.get_children():
		列.remove_child(旧)
		旧.queue_free()
	var 行们 := _介绍行数据()
	for i in 行们.size():
		var 项: Dictionary = 行们[i][1]
		var 行 := Control.new()
		行.name = "行%d" % i
		行.mouse_filter = Control.MOUSE_FILTER_IGNORE
		行.position = Vector2(0.0, 行高 * i)
		行.size = Vector2(float(列.size.x), 行高)
		列.add_child(行)
		# `%1` 是 `textColor.toString(16)` —— **不带 #**（AS3 模板自己写了井号）
		var 模板 := "YIZHI_DETALI_YELLOW_TEXT" if str(项.get("color", "")) == "yellow" \
				else "YIZHI_DETALI_TEXT"
		var 字 := RichTextLabel.new()
		字.name = "文字"
		字.bbcode_enabled = true
		字.scroll_active = false
		字.mouse_filter = Control.MOUSE_FILTER_IGNORE
		字.position = Vector2.ZERO
		字.size = Vector2(行字宽, 行线Y)
		字.add_theme_font_size_override("normal_font_size", 12)
		字.add_theme_color_override("default_color", Color.WHITE)
		字.text = 确认弹.文案转BBCode(填(键(模板),
				[str(项.get("textColor", "#ffffff")).replace("#", ""),
						项.get("name", ""), 项.get("introduceDesc", "")]))
		行.add_child(字)
		var 线 := TextureRect.new()	# `LineHPicF`：y=22、宽 406、原生高 2
		线.name = "分隔线"
		线.texture = load(线皮) as Texture2D
		线.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		线.mouse_filter = Control.MOUSE_FILTER_IGNORE
		线.position = Vector2(0.0, 行线Y)
		线.size = Vector2(行字宽, 2.0)
		行.add_child(线)
	_设偏移(页, 0.0)


## 运行期量（Flex `ScrollBar.updateThumb:153`）：`滑块高 = 轨道高 × 视口/内容`（最小 20），
## `滑块y = 轨顶 + 偏移/行程 × (轨道高 − 滑块高)`。返回 [内容列, 行程, 滑块高]。
static func _滚动量(页: Control) -> Array:
	var 列 := _件(页, "列表区/内容列") as Control
	var 行们: int = 列.get_child_count() if 列 != null else 0
	var 内容 := float(行们) * 行高
	var 行程 := maxf(0.0, 内容 - 滚动视口)
	var 高 := minf(滚动轨高, maxf(20.0, 滚动轨高 * 滚动视口 / maxf(内容, 滚动视口)))
	return [列, 行程, 高]


## 偏移变了就把两层一起摆回去（内容列上移、滑块按比例下移）。
static func _设偏移(页: Control, 偏移: float) -> void:
	var 量 := _滚动量(页)
	var 列 := 量[0] as Control
	var 滑 := _件(页, "列表区/竖条/滑块") as Control
	if 列 == null or 滑 == null:
		return
	var 行程 := float(量[1])
	var 高 := float(量[2])
	var 落 := clampf(偏移, 0.0, 行程)
	列.position.y = -落
	滑.size.y = 高
	滑.position.y = 滚动轨顶 + (落 / 行程 if 行程 > 0.0 else 0.0) * (滚动轨高 - 高)
	滑.visible = 行程 > 0.0	# `:156` `thumb.visible = enabled`


static func _移偏移(页: Control, 增量: float) -> void:
	var 列 := _件(页, "列表区/内容列") as Control
	if 列 == null:
		return
	_设偏移(页, -float(列.position.y) + 增量)


## 接线（用户 2026-09-28 报"意志介绍不能滑动，原版可以"）：
## 滚轮一格 = 一行 26px（**未证**，Flex 本体没导出）、点箭头走一行、拖滑块线性互推。
## ⚠ 行里的 RichTextLabel/分隔线一律 `IGNORE`，否则它们吃掉滚轮事件、`列表区` 永远收不到。
static func _接介绍滚动(页: Control) -> void:
	var 区 := _件(页, "列表区") as Control
	if 区 == null:
		return
	_独接输入(区, func(事件: InputEvent) -> void:
		var 键 := 事件 as InputEventMouseButton
		if 键 == null or not 键.pressed:
			return
		if int(键.button_index) == MOUSE_BUTTON_WHEEL_DOWN:
			_移偏移(页, 行高)
		elif int(键.button_index) == MOUSE_BUTTON_WHEEL_UP:
			_移偏移(页, -行高))
	for 项 in [["上箭头", -行高], ["下箭头", 行高]]:
		var 件 := _件(页, "列表区/竖条/%s" % 项[0]) as Control
		if 件 == null:
			continue
		_独接输入(件, _走一行.bind(页, float(项[1])))
	var 滑 := _件(页, "列表区/竖条/滑块") as Control
	if 滑 != null:
		_独接输入(滑, _拖滑块.bind(页, 滑))


static func _走一行(事件: InputEvent, 页: Control, 增量: float) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed:
		_移偏移(页, 增量)


static func _拖滑块(事件: InputEvent, 页: Control, 滑: Control) -> void:
	var 键 := 事件 as InputEventMouseButton
	if 键 != null:
		if 键.pressed and int(键.button_index) == MOUSE_BUTTON_LEFT:
			_拖着的滑块 = 滑
			_拖偏 = 键.position.y	# 按下点在滑块内部 ⇒ 拖的时候不让滑块跳过去
		elif not 键.pressed:
			_拖着的滑块 = null
		return
	var 移 := 事件 as InputEventMouseMotion
	if _拖着的滑块 != null and 移 != null:
		var 量 := _滚动量(页)
		var 行程 := float(量[1])
		var 轨 := 滚动轨高 - 滑.size.y
		# 指针在竖条里的 y = 滑块当前 y + (指针在滑块内的 y − 按下时的偏移)
		var 尖 := 滑.position.y + 移.position.y - _拖偏
		var 顶 := clampf(尖 - 滑.size.y / 2.0, 滚动轨顶, 滚动轨顶 + maxf(0.0, 轨))
		_设偏移(页, ((顶 - 滚动轨顶) / 轨 if 轨 > 0.0 else 0.0) * 行程)


# ═════════════════════ 四、共用：钮三态 / 提示 ═════════════════════

## 一张皮三态换图（`MButton3.updateState` → `StyleUtil.skinFilters` up 0 / over +30 / down −40）。
## 派生两态是 `开发工具/生成意志钮态图.py` 烘的，逐字节等于 `加亮(常态, ±d)`。
## 禁用态按 `MButton3.set enabled:460-477`：卸掉鼠标事件、**没有手型**、字色 #939393。
static func _绑三态钮(页: Control, 件名: String, 常皮路径: String, 基名: String, 字: Label) -> void:
	var 钮 := _件(页, 件名) as TextureButton
	if 钮 == null:
		return
	if 钮.disabled:
		钮.mouse_default_cursor_shape = Control.CURSOR_ARROW
		if 字 != null:
			字.add_theme_color_override("font_color", 禁用字色)
		return
	var 皮: Array = [load(常皮路径) as Texture2D,
			load("%s%s_悬停.png" % [派生图, 基名]) as Texture2D,
			load("%s%s_按下.png" % [派生图, 基名]) as Texture2D]
	钮.set_meta("skins", 皮)
	if 字 != null:
		钮.set_meta("label", 字)	# ⚠ 存 null 等于没存（`get_meta` 会刷"没有这个 meta 键"）
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND	# `MButton3.init():135`
	钮.mouse_entered.connect(_设钮态.bind(钮, 1))
	钮.mouse_exited.connect(_设钮态.bind(钮, 0))
	钮.button_down.connect(_设钮态.bind(钮, 2))
	# ⚠ 松手回 **STATE_UP**，不是 hover（`mouseUpHandler:103-108`）——这是原版手感的一条硬差
	钮.button_up.connect(_设钮态.bind(钮, 0))
	钮.texture_normal = 皮[0]


static func _设钮态(钮: TextureButton, 态: int) -> void:
	var 皮: Array = 钮.get_meta("skins", [])
	if 皮.is_empty():
		return
	钮.texture_normal = 皮[态]
	var 字 := 钮.get_meta("label") as Label if 钮.has_meta("label") else null
	if 字 != null:
		字.add_theme_color_override("font_color", 态色[态])


## 原版 `MToolTipText.createToolTip(API.stage, 宿主, 文案)`：提示**挂 stage**，只在 ROLL_OVER
## 才 `addChild`（`MToolTip.as:94-106`）⇒ 工程挂页面根（同一扇窗里的最高层，层级等价）、初值全隐。
## 节点名固定 `文字提示_<名>`：交互门按这个名字取件，钮态门按前缀摘干净再裁图。
## ⚠ **同一个名字只建一次、复用同一节点**（文案变了就重排）：
##   原版 `setZhaoHuanButtonVisible` 每次 hover 都 `new` 一条，照搬的话这里会给同一个宿主
##   越挂越多的 `mouse_entered` 连接，而旧连接指着**已 queue_free 的旧节点**
##   ⇒ 2026-10-03 实测：召唤过一次之后每次 hover 刷 `Invalid assignment of 'visible' on Nil`。
##   观测等价（文本/底尺寸/落点都由同一套公式重算），连接不再累积。
static func _挂文字提示(页: Control, 宿主: Control, 文案: String, 名: String) -> void:
	if 宿主 == null:
		return
	var 节点名 := "文字提示_" + 名
	var 框 := _件(页, 节点名) as Control
	var 新建 := 框 == null
	if 新建:
		框 = 文字提示场景.instantiate() as Control
		框.name = 节点名
		框.mouse_filter = Control.MOUSE_FILTER_IGNORE
		页.add_child(框)
	框.设置(确认弹.文案转BBCode(文案), _舞台(页))
	框.visible = false
	if 新建:
		宿主.mouse_entered.connect(_显提示.bind(节点名, 页, true))
		宿主.mouse_exited.connect(_显提示.bind(节点名, 页, false))


## 用**节点名**现取现显（不捕获对象引用 ⇒ 页面拆了也不会打到 Nil）。
static func _显提示(节点名: String, 页: Control, 显: bool) -> void:
	var 框 := _件(页, 节点名) as CanvasItem
	if 框 != null:
		框.visible = 显


## 意志格提示（`YiZhiTip`，宽**定死 246** + 右侧按品质速度自转的图标）。型 1=学习页格、2=背包页格。
static func _挂格提示(页: Control, 格: Control, 项: Dictionary, 型: int,
		实例: Dictionary = {}) -> void:
	var 节点名 := "意志提示_" + str(格.name)
	var 框 := _件(页, 节点名) as Control
	var 新建 := 框 == null
	if 新建:
		框 = 意志提示场景.instantiate() as Control
		框.name = 节点名
		框.mouse_filter = Control.MOUSE_FILTER_IGNORE
		页.add_child(框)
	if 型 == 1:
		框.设置学习态(项, 实例, _舞台(页))
	else:
		框.设置背包态(项, 实例, _舞台(页))
	框.visible = false
	if 新建:
		格.mouse_entered.connect(_显提示.bind(节点名, 页, true))
		格.mouse_exited.connect(_显提示.bind(节点名, 页, false))


## 圆盘正中那个主角：`YiZhiPackWindow.drawCharImage:387-406`
##   脸 = `API.dataCenter.stats.face`、动作 = `stand`、`play()` ⇒ **会呼吸**（6 帧、
##   帧时长 360/180/180/480/180/180ms，读 `数据/角色/动画元数据.json` 的 delay）；
##   落点 `x = _charSkin.width/2`、`y = (_charSkin.height − 人物高)/2 + 人物高`
##   ⇒ `_charSkin` 是 equipSkin 那张 **230×230** 的矩形（`:160-163` 画的就是它的尺寸），
##   而 `y` 是**脚底**（Flash 里 CharacterSprite 的注册点在脚下，本工程 `当前原点().y=122` 同一条）。
## 层序：`onSkinReady:158-159` 是 equipSkin → **charSkin** → equipPanel ⇒
##   **8 枚穿戴格压在人物之上**（所以必须 `move_child` 插到穿戴容器前面，不能简单 add 在最后）。
## ⚠ 这是**运行期按脸新建**的件（原版也是），不是版式件 ⇒ 编辑器里看不见，别当"编辑器≠运行期"。
static func _接人物立绘(页: Control, 窗口) -> void:
	var 盘 := _件(页, "穿戴盘") as Control
	var 容 := _件(页, "穿戴容器") as Node
	var 兽 := OriginalSprite.new()
	兽.name = "人物立绘"
	页.add_child(兽)
	if 容 != null:
		页.move_child(兽, 容.get_index())	# 压在它下面（穿戴格要盖住它）
	var 脸 := str(int(窗口._session.player_stats.get("face", 1))).pad_zeros(8)
	if not 兽.configure("character", 脸, "stand"):
		兽.queue_free()
		return
	兽.play("stand")
	var 高 := 兽.当前贴图高度()
	if 高 <= 0.0:
		高 = 123.0							# 站姿身体帧实测高（`:395-399` 的 height==0 兜底支路另说）
	兽.position = 盘.position + Vector2(float(盘.size.x) / 2.0,
			(float(盘.size.y) - 高) / 2.0 + 高)
