extends RefCounted
## 「角色改名」窗（原版 `ChangeNameWindow`，`UIWindow(300,320,true)`）控制器。
## 逐件真值：`真值/窗口/人物属性_改钮.md`。
##
## 这一扇有**两个模式**，同一个实例来回切（原版就是同一个单例）：
## · **自己**：点自己人物窗名字右边那颗「改」⇒ `ChangeNameWindow.show()` ⇒
##   标题「角色改名」、输入框/购买/确定/卡格全在，并且 `refreshData()` 顺手发一发
##   `2330:10` 要自己的历史名（`ChangeNameWindow.as:251-256`）。
## · **别人**：点**对方**人物窗那颗「改」⇒ `requestOtherHistoryNamesByName(名)`（`2330:12`）⇒
##   回帧 `2330:12:<那个人的名>:<名单>` ⇒ `setOtherPlayerMode()`（`:88-127`）：
##   藏掉输入框/新名字/确定/购买/卡格/提示/拥有数**七件**，历史名那两行整体**上移 82**，
##   标题改成「<名字> 的历史名字」。**取消钮不藏**（原版没藏它，`:98-117` 那串里没有 `_cancelBtn`）。

const 改名卡号 := "16000180"		## 原版 `RENAME_CARD_ITEM_ID`；服务端 `handle_change_name:33193` 同一个数

## 七件在"别人模式"里要藏掉（`setOtherPlayerMode:90-117` 逐件对照）。
const 别人模式藏 := ["新名字输入", "新名字标题", "确定钮", "购买钮", "改名卡格", "提示文", "拥有数"]
## 历史名那两行在"别人模式"整体上移的量（`:120` `_historyLabel.y = _historyLabelOrigY - 82`、
## `:124` 同一个 82 给 `_historyArea`）。
const 历史上移 := 82.0

const 色_橙 := Color("#ff9100")		## `UIConfig.UI_ORANGE`
const 色_黄 := Color("#fff000")		## `UIConfig.UI_YELLOW`
const 色_白 := Color("#ffffff")		## `UIConfig.UI_WHITE`
const 色_绿 := Color("#00ff00")		## `UIConfig.UI_GREEN`
const 色_红 := Color("#ff0000")		## `UIConfig.UI_RED`


## 页入口：`窗口管理` 收到 `2330` 那一帧时先灌 `窗口._改名名单 / _改名别人名`，再 `打开("角色改名")`。
## 与「他人人物」同一套路子 —— **开窗的是回帧，不是点击**（自己那扇是点了就发请求，
## 但页面数据仍然等 `2330:10` 那一发）。
static func 渲染(窗口, 场景: PackedScene) -> void:
	var 页: Control = 场景.instantiate()
	窗口._content.add_child(页)
	var 别人名: String = 窗口.get("_改名别人名")
	var 名单: PackedStringArray = 窗口.get("_改名名单")

	# —— 别人模式：藏七件 + 两行上移 + 换标题 ——
	if not 别人名.is_empty():
		for 藏 in 别人模式藏:
			var 节 := 页.get_node_or_null(藏) as Control
			if 节 != null:
				节.visible = false
		(页.get_node("历史名标题") as Control).position.y -= 历史上移
		(页.get_node("历史名文") as Control).position.y -= 历史上移
		窗口.设置标题("%s 的历史名字" % 别人名)
	else:
		窗口.设置标题("角色改名")
		# 原版 `show():65` 每次都把标题写回「角色改名」并 `resetToNormalMode()`；
		# 输入框清空是 `refreshData():253` 干的。
		(页.get_node("新名字输入") as LineEdit).text = ""

	# —— 改名卡那一格：图 + 持有数（`updateCardCount:258-269`，有卡绿、没卡红）——
	var 卡数 := int(窗口.改名卡数())
	var 拥有 := 页.get_node("拥有数") as Label
	拥有.text = "当前拥有:%d" % 卡数
	窗口._configure_label(拥有, 12, 色_绿 if 卡数 > 0 else 色_红)
	(页.get_node("提示文") as Label).tooltip_text = "使用改名卡可以修改角色名称"
	(页.get_node("改名卡格/改名卡图标") as TextureRect).texture = 窗口._物品图标(改名卡号)

	# —— 历史名（`setHistoryNames:272-301`：每列 8 行、**按列填**，`N.名字  ` 两空格分隔）——
	(页.get_node("历史名标题") as Label).tooltip_text = "【历史名字】"
	var 文 := 页.get_node("历史名文") as RichTextLabel
	文.text = 排历史名(名单)
	文.add_theme_font_size_override("normal_font_size", 12)
	文.add_theme_color_override("default_color", 色_白)

	# —— 三颗钮 ——
	(页.get_node("取消钮") as Button).pressed.connect(func() -> void: 窗口.close())
	(页.get_node("购买钮") as Button).pressed.connect(func() -> void: 窗口.请求商城商品(改名卡号))
	if 别人名.is_empty():
		(页.get_node("确定钮") as Button).pressed.connect(提交改名.bind(窗口, 页))


## 原版 `setHistoryNames:272-301` 的排版：**8 行一列**、下标按 `列*8+行` 跳着取，
## 每格写成 `序号.名字` 后面垫两个空格，行尾一个 `\n`。空表 ⇒ 「暂无历史名字」。
static func 排历史名(名单: PackedStringArray) -> String:
	if 名单.is_empty():
		return "暂无历史名字"
	var 列数 := int(ceil(float(名单.size()) / 8.0))
	var 出 := ""
	for 行 in 8:
		for 列 in 列数:
			var 序 := 列 * 8 + 行
			if 序 < 名单.size():
				出 += "%d.%s  " % [序 + 1, String(名单[序])]
		出 += "\n"
	return 出


## 「确定」：原版 `onConfirmClick:310-329` 三道本地拦截，**一道不过就不发包**
## （空名 / 长度不在 2~12 / 改名卡数为 0），三道的文案都是 AS3 字面量。
## 卡数这道原版也拦（`:323-327`），不是"发出去让服务端拒"。
static func 提交改名(窗口, 页: Control) -> void:
	var 新名 := String((页.get_node("新名字输入") as LineEdit).text).strip_edges()
	if 新名.is_empty():
		窗口._通知("请输入新名字！")
		return
	if 新名.length() < 2 or 新名.length() > 12:
		窗口._通知("名字长度需要2-12个字符！")
		return
	if int(窗口.改名卡数()) <= 0:
		窗口._通知("改名卡不足！")
		return
	var 后: Node = 窗口._backend
	if 后 == null or not bool(后.get("in_game")):
		窗口._通知("改名需要在线")
		return
	if not bool(后.call("request_change_name", 新名)):
		窗口._通知("改名请求发送失败")
