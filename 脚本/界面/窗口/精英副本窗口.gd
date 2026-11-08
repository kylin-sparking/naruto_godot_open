extends RefCounted
## 精英副本页（原版 `com/mxw/uifl/controls/copy/EliteCopyWindow.as`，`super(500,426)` 在 `:57`）。
##
## ⚠ **不摆样式、不摆控件**：186 个节点全烘在 `.tscn`（`开发工具/生成精英副本场景.py` ←
## `数据/界面/精英副本_布局.json` ← `开发工具/出精英副本布局.py`，最后那份照抄
## `createCell():101-149`）。四个页签子页的格都烘进来，运行期只翻 `visible` ⇒ 编辑器里
## 看到的就是实机那一屏。逐件出处 `game-client/真值/窗口/精英副本.md`。
##
## 三条运行期职责（对应原版同名函数）：
##   * `onClickTabBtn`（`:286-298`）⇒ 旧选中枚 `enabled=true`、新枚 `enabled=false`
##     （`MTabButton.as:38` 把 `enabled` 反转成 `selected` ⇒ **disabled 档才是选中样式**），
##     然后 `setCopyName` + 换页。
##   * `setCopyName`（`:300-305`）⇒ `height = textHeight + 5`、`y = 子面板.y + (110 − 高)/2`。
##   * `setCellData`（`:249-263`）⇒ 每枚格按 `reqLevel <= 玩家等级` 决定锁不锁
##     （`BailianCell.as:182-185` 的 `lack`：锁住时只留 `lackMc`，其余四件全隐）。
##
## ⚠ **协议一条都没发**：原版点格 = `API.client.requestHeroEnter(copyId)`（`:311`，
## `SendOpCodes.as:274 HERO_ENTER=1828`），本工程 `后端连接.gd` 里没有这条钩子
## （服务端 `fake_flash_server.py:17287 _send_hero_enter_info` 已实现，客户端缺）⇒
## 加钩子属于改协议，按约定要点头才动。这里只给状态行回执，不发裸包。

const 精英场景 := preload("res://场景/界面/窗口/副本/精英副本窗.tscn")
const 布局路径 := "res://数据/界面/精英副本_布局.json"
const 文案路径 := "res://数据/界面/副本_文案.json"
const 行高字 := 17
const 名宽 := 84
const 每行字 := 6		# 84 宽 / 12px 汉字，实机折成 6+1（见 出精英副本布局.py 的注）
const 抬 := 29		# 「精英副本」在 窗口尺寸.json 里 `整框: true` ⇒ 场景 y = 窗口 y − 29
const 子面板y := 36		# 场景局部（窗口 65 − 29）

static var _宿主
static var _页: Control
static var _布局: Array = []
static var _文案: Dictionary = {}
static var _页号 := 0


static func 渲染(宿主) -> void:
	_宿主 = 宿主
	if _布局.is_empty():
		var f := FileAccess.open(布局路径, FileAccess.READ)
		if f != null:
			var 体: Variant = JSON.parse_string(f.get_as_text())
			_布局 = (体 as Dictionary).get("页", []) as Array
	if _文案.is_empty():
		var f2 := FileAccess.open(文案路径, FileAccess.READ)
		if f2 != null:
			_文案 = JSON.parse_string(f2.get_as_text())
	_页 = _宿主._instantiate_page(精英场景)
	# 2026-10-04 接 1828:没拿到过进入列表就自拉一次(菜单 30 的路服务端已随包推过,
	# 从别的入口开这扇窗时这条兜底)。回帧 hero_state_changed ⇒ 宿主重渲染 ⇒ _刷次数 吃上真数。
	if not _宿主._session.hero_state_loaded:
		_宿主._session.request_hero_info()
	(_页.get_node("副本名") as RichTextLabel).scroll_active = false
	for n in _页号数():
		var 钮 := _页.get_node("分页/页签%d" % n) as Button
		钮.button_group = null
		钮.pressed.connect(_切页.bind(n))
	_接格()
	_切页(_页号)


static func _页号数() -> int:
	return _布局.size()


static func _会话() -> Node:
	return _宿主._session if _宿主 != null else null


static func _玩家等级() -> int:
	var 会 := _会话()
	return int(会.player_stats.get("level", 1)) if 会 != null else 1


## `onClickTabBtn`（`:286-298`）+ `setCopyName`（`:300-305`）。
static func _切页(号: int) -> void:
	if 号 >= _布局.size() or _页 == null:
		return
	_页号 = 号
	var 页: Dictionary = _布局[号]
	for n in _页号数():
		var 钮 := _页.get_node("分页/页签%d" % n) as Button
		钮.disabled = n == 号		# MTabButton：enabled=false ⇒ 显示 selectedUpSkin（选中样式）
		钮.set_pressed_no_signal(n == 号)
		(_页.get_node("格滚动/格容器/页%d" % n) as Control).visible = n == 号
	var 名 := _页.get_node("副本名") as RichTextLabel
	名.text = _译(str(页["名文本"]))
	# 高/位直接取布局表（`出精英副本布局.py` 已按 `setCopyName:303-304` 算好）。
	# ⚠ 别在这儿重数行数：名文本带 `<font>` 标签，按字符数折行会把 3 行数成 6 行
	#   ⇒ 高 107、y 37.5，整页左侧那截字往下掉 25px（2026-10-03 门抓到）。
	名.size = Vector2(float(名宽), float(页["名高"]))
	名.position = Vector2(11.0, float(int(页["名y"])) - 抬)
	_刷锁(页)
	_刷次数(页)


## 「今日 x/y 次」= 1828/0 回帧(hero_entries/hero_max_enter);没帧保持布局表烘的初值。
## 页签枚数不跟帧走:布局表与服务端同读 `Etc.Hero`,以表为准更稳(帧只当账本,不当版面)。
static func _刷次数(页: Dictionary) -> void:
	var 会 = _宿主._session if _宿主 != null else null
	if 会 == null or not bool(会.hero_state_loaded):
		return
	for 格 in (页["格"] as Array):
		var 件 := _页.get_node("格滚动/格容器/页%d/格%d" % [int(页["页号"]), int(格["序号"])]) as Control
		var 数 := 件.get_node("次数") as Label
		var 已: int = int((会.hero_entries as Dictionary).get(int(格["copyId"]), 0))
		数.text = "（%d/%d次）" % [已, int(会.hero_max_enter)]


## `setCopyName` 的 htmlText 里带 `<font>` ⇒ 转 BBCode（与 `功能窗口.译文为BBCode` 同一套）。
static func _译(文: String) -> String:
	文 = 文.replace("<br/>", "\n").replace("<br>", "\n")
	文 = 文.replace("<font color='", "[color=").replace('<font color="', "[color=")
	文 = 文.replace("'>", "]").replace('">', "]")
	return 文.replace("</font>", "[/color]")


static func _行数(名文本: String) -> int:
	## 名行 = 副本名折行 + 那行「（N级）」，与 `出精英副本布局.py` 同一条。
	var 纯 := 名文本.replace("<br/>", "\n")
	var 段 := 纯.split("\n")
	var 名: String = 段[0]
	return maxi(1, int(ceil(float(名.length()) / float(每行字)))) + maxi(0, 段.size() - 1)


## `setCellData:256`：`reqLevel <= 玩家等级` 才不锁。锁住时原版只留 `lackMc`
## （`BailianCell.as:133-134` 初始就把 background/名/章节/头像全隐，只显锁）。
static func _刷锁(页: Dictionary) -> void:
	var 锁住: bool = int(页["reqLevel"]) > _玩家等级()
	for 格 in (页["格"] as Array):
		var 件 := _页.get_node("格滚动/格容器/页%d/格%d" % [int(页["页号"]), int(格["序号"])]) as Control
		(件.get_node("锁") as Control).visible = 锁住
		for 名 in ["格底", "名", "章节", "头像"]:
			(件.get_node(名) as Control).visible = not 锁住
		(件.get_node("选中底") as Control).visible = false
		件.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not 锁住 \
				else Control.CURSOR_ARROW


## `onClickItem` → `sureToClickItem`（`:307-314`）：不锁才发进本请求，之后一律关窗。
static func _接格() -> void:
	for 页 in _布局:
		for 格 in (页["格"] as Array):
			var 件 := _页.get_node("格滚动/格容器/页%d/格%d" % [int(页["页号"]), int(格["序号"])]) as Control
			件.gui_input.connect(_点格.bind(int(页["页号"]), int(格["序号"])))
			件.mouse_entered.connect(_悬停格.bind(int(页["页号"]), int(格["序号"]), true))
			件.mouse_exited.connect(_悬停格.bind(int(页["页号"]), int(格["序号"]), false))


## `BailianCell.as:210-214`：hover 显 `selectedBg`，out 隐（选中态另说）。
static func _悬停格(页号: int, 序号: int, 进: bool) -> void:
	var 件 := _页.get_node("格滚动/格容器/页%d/格%d" % [页号, 序号]) as Control
	(件.get_node("选中底") as Control).visible = 进


static func _点格(事件: InputEvent, 页号: int, 序号: int) -> void:
	if not (事件 is InputEventMouseButton) or not (事件 as InputEventMouseButton).pressed:
		return
	var 页: Dictionary = _布局[页号]
	if int(页["reqLevel"]) > _玩家等级():
		_宿主._show_hint(String(_文案.get("COPY_DENGJI_TAIDI", "")))
		return
	# `onClickItem → sureToClickItem`(:307-314):发进本请求(1828:1:copyId)、**之后一律关窗**。
	# 三道校验(等级/已在副本/今日次数)全在服端,被拒不弹窗、只有系统聊天帧——照办不预判。
	var 格: Dictionary = {}
	for 候 in (页["格"] as Array):
		if int((候 as Dictionary).get("序号", -1)) == 序号:
			格 = 候 as Dictionary
			break
	if 格.is_empty():
		return
	if not _宿主._session.request_hero_enter(int(格["copyId"])):
		_宿主._show_hint("精英副本进入要在服务端结算（离线不模拟）")
		return
	_宿主.close()
