extends Control

const 家族页回调 := preload("res://脚本/界面/窗口/家族/家族页回调.gd")

## 家族列表窗内容页（原版 `FamillyListWindow` 620×370 ⇒ 内容区 604×302，本页以内容区左上为 (0,0)）。
## 真值：`游戏系统与差距.md` §3.63.1b/§3.63.1c；逐条出处是 `FL.as`（`FamillyListWindow.as`）
## 与 `FamillyListItemRenderer.as` 的行号。只做美术与交互，协议一律走宿主的 `_show_guild_action`。
##
## ⚠️ **行填充归本文件**（`家族列表填充.gd` 不再管这一窗）：行是 `FL:195-202` 的 `list` +
## `FamillyListItemRenderer`，座椅尺寸由 `FamillyListItemRenderer.as:29-31`（`super(569,23)`）
## 与 `:41-64` 的链式列位定死 —— `列` 常量就是那份链式列位（含 `_loc1_ += _loc2_ + 2` 的 +2 间隙）。
##
## 选中态：原版 `CommonItemRenderer`（`CommonItemRenderer.as:130-149`）—— 悬停/选中都把
## `_background`（`MSelected_background1`，符号 **705**）显出来，`selected` 时鼠标移开也不收。
## 9 宫格取自该符号的 `DefineScalingGridTag`。
##
## 家徽图 —— `FamillyListItemRenderer.as:85-89`：`PicTool.getJiaHuiPic(flagStyle)` 缩到 20/42、
## 落在行内 x=14、y=3。
##
## ⚠️ **图源不在离线素材里，本轮查过，别再翻一遍**：`PicTool:503`
##   `ImgUtil.getImg(ImgType.BangHui, flagStyle)` 取的是 `ImgManager` 那份**运行时图像包**
##   里的 `BangHui/<样式号>/icon/value`；原版每个样式号各一个图形包
##   （`swf/BangHui/BangHui_flagStyle_<n>.swf`，本机 222 个）。家族那 12 字段行里只有
##   `flag_style` 编号，没有任何图标数据。⇒ 这一格**先空着**，等图像下发链路接上再补
##   （宁可空着也不编图，§0.0 第一原则）。
const 家徽尺寸 := 20.0
const 家徽位置 := Vector2(14.0, 3.0)

const 钮皮 := "res://素材/界面/原版窗口/家族/钮底%d%s.png"
const 行选中底皮 := "res://素材/界面/原版窗口/家族/行选中底.png"
## 下拉用的菜单皮（与 `好友菜单.gd` 同一套：`MPopupMenu_background` / `MPopupMenuButtonF`），
## 边距也照那边抄 —— 项目里没有通用下拉组件，`MComboBox` 的列表就用这套皮现搭。
const 菜单底皮 := "res://素材/界面/原版窗口/通用控件/菜单底.png"
const 菜单项皮 := "res://素材/界面/原版窗口/通用控件/菜单按钮.png"
const 下拉项高 := 19.0
const 下拉边 := 3.0
const 家徽图 := preload("res://脚本/界面/窗口/家族/家徽图.gd")
## `DefineScalingGridTag characterId=705`：RECT(Xmin=140 Xmax=3622 Ymin=107 Ymax=265) ÷20
## ⇒ (7, 5.35)-(181.1, 13.25)，原图 189×19 ⇒ 右 7.9、下 5.75。
const 选中底边 := {"左": 7.0, "上": 5.35, "右": 7.9, "下": 5.75}

const 行高 := 23.0			# `FL:199` list.rowHeight = 23
const 行宽 := 569.0			# `FamillyListItemRenderer.as:31` super(569,23)
## renderer `createItem` 链式列（宽 +2 间隙）：家徽图 55 → 名 80 蓝 → 族长 82 绿 → 人数 69
## → 等级总和 69 → 家徽等级 105 紫 → 本周击杀BOSS数 100（`:63` 的 `_loc2_ = 100`）
const 列 := [["家徽图", 55.0], ["家族名称", 80.0], ["现任族长", 82.0], ["族中人数", 69.0],
	["等级总和", 69.0], ["家徽等级", 105.0], ["本周击杀BOSS数", 100.0]]
const 列色 := {"家族名称": Color("#87CEEB"), "现任族长": Color("#00FF00"), "家徽等级": Color("#DA70D6")}
const 族长离线色 := Color("#CCCCCC")		# `FamillyListItemRenderer.as:71` 0xCCCCCC

# ── 显示分页 / 列头排序 / 每页条数（原版 `FL.as:73-133,205-334`）──────────────────
#
# ⚠️ 别和后端那三个字段（total/page_size/page）混了：服务端那三个是**取数分页**
#    —— 一次给 100 条、累计到 `total` 为止（见 `后端连接.request_guild_list` 与其 action 3 注释）；
#    这里做的是**显示分页**：数据整份已经在手上，`getPage()`（`FL.as:112-120`）只是本地 slice。
#
# ⚠️「显示」那个下拉（筛 `autoAccept`）**暂不实现**：服务端 action 101 的 12 字段行里没有
#    这个字段（`FamillyListItemRenderer` 也只认那 12 个），拿不到就不编（§0.0 第一原则）。
const 每页选项 := [10, 30, 50, 100]			# `UIConfig.fenYeSelection` 的 data
const 每页文案 := ["10项", "30项", "50项", "100项"]	# PAGE_TEN / THIRTY / FIFTY / HUNDRED
const 显示文案 := ["所有家族", "自动招人家族", "招人验证家族"]	# `FL.as:225` 的三个选项
## 可点排序的列 → 排序键。**「家徽」那一列不在表里**：原版 `FL.as:171` 给它传的是 `null`
## （`createSanJiaoLable(LABEL_STRINGS[2], …, null)`），也就是那一列本来就不给点。
const 列排序 := {
	"家族名称": "name", "现任族长": "leader", "族中人数": "members",
	"等级总和": "level_sum", "家徽等级": "flag_level", "本周击杀BOSS数": "boss_sum",
}
## 默认排序列 = 原版 `_sortField` 的初值 `"level_jiaHui"`（`FL.as:56`），走 `sortComprareFun`：
## 家徽等级降序，同则等级总和降序（`FL.as:136-156`）。
const 默认排序列 := "家徽等级"

var _宿主: Node
var _会话: Node
var _窗口: Control
var _列: Control
var _条: Control
var _滑块: TextureButton
var _勾上 := true	# FL:239 checkBox.selected = true
var _偏移 := 0.0
var _可视 := 235.0
## 行与选中态。`_选中序` 是**行序**（不是家族 id）—— 原版 `list.selectedItem` 同理。
## ⚠️ `_家族表` 是**当前页**那一段（`getPage` 的产物），不是全量。
var _家族表: Array = []
var _行: Array[Control] = []
var _选中序 := -1
var _悬停序 := -1
## 分页/排序状态。`_全部表` = 原版 `_source`，`_显示表` = 原版 `_viewSource`。
var _全部表: Array = []
var _显示表: Array = []
var _每页序 := 0			# `initView()` 里 `_yeComboBox.selectedIndex = 0`（`FL.as:359`）
var _页码 := 1
var _排序列 := 默认排序列
## 现开着的下拉（一次只允许一个；再点触发器/点别处就收掉）。
var _下拉: Control
var _下拉钮: TextureButton


func 装配(宿主: Node) -> void:
	_宿主 = 宿主
	_会话 = get_node_or_null("/root/GameSession")
	_窗口 = get_node("列表窗口") as Control
	_列 = get_node("列表窗口/内容列") as Control
	_条 = get_node("滚动条") as Control
	_滑块 = get_node("滚动条/滑块") as TextureButton
	for 名 in ["创建家族", "申请加入"]:
		var 钮 := get_node(名) as TextureButton
		钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		钮.pressed.connect(_发动作.bind(名))
	_列.get_parent().gui_input.connect(_滚轮)
	# 复选：原版 `MCheckBoxF.selected=true`（FL:239）⇒ 可见框换选中皮，点击翻态
	var 勾 := get_node("自动同意") as Control
	勾.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	勾.gui_input.connect(_翻复选.bind(勾))
	# 每页条数 / 显示 两个下拉（原版 `FL.as:210-216` / `:224-232` 的 MComboBox）。
	# ⚠️ 回调写成**具名方法**而不是多行 lambda：跨行 lambda 当实参时缩进规则很容易踩空，
	#    这个工程里已经有过一次"lambda 报错把整条填充链打断"的教训（见 `家族创建填充`）。
	_接下拉("页下拉", 每页文案, _取每页序, _选每页)
	# 「显示」筛的是每行的 `autoAccept`，服务端 12 字段行里没有这个字段（见文件头常量说明）
	# ⇒ 控件保留可点（原版那儿就有一个），但**不拿编出来的值当它生效了**。
	_接下拉("家主下拉", 显示文案, _取显示序, _选显示)
	# 分页四钮（原版 `PageComponent` + `PageEvent.SET_PAGE`，`FL.as:247-251`）。
	_接翻页钮("分页/首页", func() -> int: return 1)
	_接翻页钮("分页/上一页", func() -> int: return _页码 - 1)
	_接翻页钮("分页/下一页", func() -> int: return _页码 + 1)
	_接翻页钮("分页/末页", func() -> int: return _总页数())
	# 列头排序（原版 `clickSanJiaoLabelHandler`，`FL.as:377-382`）。
	for 列 in 列排序:
		_接列头(String(列))
	_同步三角()
	# 滚动条两端箭头（原版 `ScrollBar` 上下箭头，一次一行）。
	_接滚动钮("滚动条/滚动上", -1.0)
	_接滚动钮("滚动条/滚动下", 1.0)
	# 列表是异步到的：开窗先按现状画一次，再挂 `social_changed` 重画
	# （服务端收到 `101` 后回 `1552:3`，会话把它转成 `social_changed`）。
	if _会话 != null and _会话.has_signal("social_changed") and not has_meta("guild_list_hooked"):
		set_meta("guild_list_hooked", true)
		# ⚠️ 闭包捕获的必须是**渲染这一页的那个实例**（self），不是宿主 —— 跨窗状态的老坑。
		# ⚠️ 还要在窗收掉时断开：不然单例每次广播都会报
		#    "Lambda capture at index 0 was freed"（`家族页回调.挂` 就是干这个的）。
		家族页回调.挂(self, _会话.social_changed, func() -> void: 从后端刷新())
	从后端刷新()


## 从后端权威列表重画（数据源 `BackendConnection.authoritative_guild_list` ← 服务端 `1552:3`）。
func 从后端刷新() -> void:
	var 后端 := get_node_or_null("/root/BackendConnection")
	var 表: Array = []
	if 后端 != null:
		表 = (后端.get("authoritative_guild_list") as Array).duplicate()
	刷新(表)
	# 原版 `init()`（`FL:123-133`）：已在某个家族里 ⇒ 「创建家族」「申请加入」都置灰。
	# 点灰钮走原版那句 `CN.FAMILLY_MANAGER_SORRY_YOU_JIAZU = "很抱歉，你已经有家族了！"`。
	var 有家族 := false
	if _会话 != null:
		有家族 = bool((_会话.get("guild") as Dictionary).get("joined", false))
	for 名 in ["创建家族", "申请加入"]:
		var 钮 := get_node_or_null(名) as TextureButton
		if 钮 == null:
			continue
		钮.disabled = 有家族
		_换皮(钮, 0)


func 刷新(列表: Array) -> void:
	_全部表 = 列表
	_页码 = 1
	_重算()


## 原版 `updateList()`（`FL.as:103-108`）：筛选 → 排序 → 分页 → 取当前页。
## 「显示」那一步（`applyFilter`，`FL.as:71-102`）跳过，原因见文件头常量说明。
func _重算() -> void:
	_显示表 = _全部表.duplicate()
	_排序()
	var 每页: int = int(每页选项[_每页序])
	_页码 = clampi(_页码, 1, _总页数())
	_渲染(_显示表.slice((_页码 - 1) * 每页, mini(_显示表.size(), _页码 * 每页)))
	_同步分页()


func _总页数() -> int:
	var 每页: int = int(每页选项[_每页序])
	return maxi(1, int(ceilf(float(_显示表.size()) / float(每页))))


## 列头排序（原版 `applySort`，`FL.as:290-317`）。
##
## ⚠️ 方向是**按字段写死的**：名字类 `Array.CASEINSENSITIVE`（升序），其余都带
##    `Array.DESCENDING`（降序）。`_isDesending` 那个字段在 `applySort` 里**根本没被读**
##    —— 是原版的死代码，别照抄。
func _排序() -> void:
	var 键 := String(列排序.get(_排序列, ""))
	if 键 == "" or 键 == "flag_level":
		# 默认「家徽等级」：走 `sortComprareFun`（`FL.as:136-156`）—— 先比家徽等级，同则等级总和
		_显示表.sort_custom(func(甲: Dictionary, 乙: Dictionary) -> bool:
			var 甲级 := int(甲.get("flag_level", 0))
			var 乙级 := int(乙.get("flag_level", 0))
			if 甲级 != 乙级:
				return 甲级 > 乙级
			return int(甲.get("level_sum", 0)) > int(乙.get("level_sum", 0)))
		return
	if 键 == "name" or 键 == "leader":
		_显示表.sort_custom(func(甲: Dictionary, 乙: Dictionary) -> bool:
			return String(甲.get(键, "")) < String(乙.get(键, "")))
		return
	_显示表.sort_custom(func(甲: Dictionary, 乙: Dictionary) -> bool:
		return int(甲.get(键, 0)) > int(乙.get(键, 0)))


func _同步分页() -> void:
	var 总 := _总页数()
	var 页 := get_node_or_null("分页/页码") as Label
	if 页 != null:
		页.text = "%d/%d" % [_页码, 总]
	for 对 in [["分页/首页", 1], ["分页/上一页", _页码 - 1], ["分页/下一页", _页码 + 1], ["分页/末页", 总]]:
		var 钮 := get_node_or_null(String(对[0])) as TextureButton
		if 钮 != null:
			钮.disabled = int(对[1]) == _页码 or int(对[1]) < 1 or int(对[1]) > 总


## 只把当前页那一段渲染成行（原版 `updateCurrentPage`，`FL.as:262-265`：整表换 dataProvider）。
func _渲染(页行: Array) -> void:
	_家族表 = 页行
	_选中序 = -1
	_悬停序 = -1
	for 行 in _行:
		if is_instance_valid(行):
			_列.remove_child(行)	# queue_free 是延迟释放，当帧还在树里 ⇒ 新行会排到它后面
			行.queue_free()
	_行.clear()
	var 空提示 := _列.get_node_or_null("空提示") as Label
	if 空提示 != null:
		空提示.visible = 页行.is_empty()
	# 行插到最前面（`_建行` 里 `move_child(行, i)`），把场景自带的「空提示」始终挤到最后一个 ——
	# 它只在没行时才可见，排在末尾不会挡行；而 `内容列.get_child(0)` 恒是 `行1`
	# （门 `家族页回归测试._验列表` 就是这么取的）。
	for i in 页行.size():
		_建行(页行[i] as Dictionary, i)
	# 内容列在场景里是**显式尺寸**（钉死 235），不随子节点长大 —— 不自己撑开的话
	# `_上限()` 恒 0，滚动条永远不出现、滚轮也滚不动（原版 `list` 是滚动容器，自带内容高）。
	_列.size = Vector2(行宽, maxf(_可视, 页行.size() * 行高))
	_偏移 = 0.0
	_同步滚动()


func _建行(记: Dictionary, 序: int) -> void:
	var 行 := Control.new()
	行.name = "行%d" % (序 + 1)
	行.size = Vector2(行宽, 行高)
	行.position = Vector2(0.0, 序 * 行高)
	# ⚠️ 必须 STOP：`IGNORE` 收不到 `mouse_entered`/`gui_input`，行就既不能选、也没悬停态。
	行.mouse_filter = Control.MOUSE_FILTER_STOP
	# ⚠️ meta 的键**必须 ASCII**：中文键会被 `set_meta` 直接拒掉（报 "Invalid metadata identifier"），
	#    而后续 `get_meta` 拿到的是默认值 —— 静默错，见 §3.64.4 的坑清单。
	行.set_meta("row_index", 序)
	# 选中/悬停底：原版排在最底下（`CommonItemRenderer.createItem` 的 `addChildAt(_background, 0)`）
	var 底 := NinePatchRect.new()
	底.name = "选中底"
	底.texture = load(行选中底皮) as Texture2D
	底.position = Vector2.ZERO
	底.size = Vector2(行宽, 行高)
	底.patch_margin_left = float(选中底边["左"])
	底.patch_margin_top = float(选中底边["上"])
	底.patch_margin_right = float(选中底边["右"])
	底.patch_margin_bottom = float(选中底边["下"])
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	底.visible = 序 == _选中序
	行.add_child(底)
	行.mouse_entered.connect(_悬停.bind(行, true))
	行.mouse_exited.connect(_悬停.bind(行, false))
	行.gui_input.connect(_点行.bind(序))
	_列.add_child(行)
	_列.move_child(行, 序)		# 让「空提示」恒排在所有行之后（见 `刷新` 里的说明）
	_行.append(行)
	# 列位是 renderer 的链式累加：**先按当前 x 落这一格，再 `_loc1_ += 宽 + 2`**
	# ⇒ 名/族长/人数/等级总和/家徽等级/BOSS 依次落在 57/139/223/294/365/472。
	var x := 0.0
	for c in 列.size():
		var 名 := String(列[c][0])
		var 宽 := float(列[c][1])
		if 名 == "家徽图":
			# `FamillyListItemRenderer.as:85-89`：`getJiaHuiPic(flagStyle)` 缩到 20/42、
			# 落在 x=14、y=3。缩放在原点左上进行，左上角不动。
			var 图 := 家徽图.取(int(记.get("flag_style", -1)))
			if 图 != null:
				var 徽 := TextureRect.new()
				徽.name = "家徽图"
				徽.texture = 图
				徽.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				徽.stretch_mode = TextureRect.STRETCH_SCALE
				徽.size = Vector2.ONE * (家徽图.边长 * 家徽图.列表缩放)
				徽.position = Vector2(14.0, 3.0)
				徽.mouse_filter = Control.MOUSE_FILTER_IGNORE
				行.add_child(徽)
			x += 宽 + 2.0
			continue
		var 字 := Label.new()
		字.name = 名
		字.position = Vector2(x, 0.0)
		字.size = Vector2(宽, 20.0)
		字.text = _值(名, 记)
		字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		字.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# `CommonItemRenderer.cretateLabel` 是裸 `new TextField()` + `textFormat.size = 12`
		# ⇒ 字号 12（主题默认是 11），见 `开发记录（本地）` 的「Flash 文字两条固定换算」。
		字.add_theme_font_size_override("font_size", 12)
		if 列色.has(名):
			字.add_theme_color_override("font_color", 列色[名])
		# `:69-79`：族长**在线**才用绿；离线（channelId < 0）换 0xCCCCCC、且不挂提示框
		if 名 == "现任族长" and int(记.get("channel_id", -1)) < 0:
			字.add_theme_color_override("font_color", 族长离线色)
		字.tooltip_text = _提示(名, 记)
		行.add_child(字)
		x += 宽 + 2.0


## 行提示框。原版只有族长那一格挂（`FamillyListItemRenderer.as:71-79`）：
## 在线 `"[<线>线]<族长名>"`；离线 `destroyTip()` ⇒ 没有提示。
func _提示(名: String, 记: Dictionary) -> String:
	if 名 != "现任族长":
		return ""
	var 线 := int(记.get("channel_id", -1))
	if 线 < 0:
		return ""
	return "[%d线]%s" % [线, String(记.get("leader", ""))]


## 每列的取数。字段名对齐服务端 `handle_banghui` action 101 的 12 字段行
## （见 `后端连接._handle_guild_text` action 3 的注释）。
func _值(名: String, 记: Dictionary) -> String:
	match 名:
		"家族名称":
			return String(记.get("name", "-"))
		"现任族长":
			return String(记.get("leader", "-"))
		"族中人数":
			return "%d/%d" % [int(记.get("members", 0)), int(记.get("capacity", 0))]
		"等级总和":
			return str(int(记.get("level_sum", 0)))
		"家徽等级":
			# `:94`：`_data.flagLevel + CN.COMMON_JI + "  " + _data.flagName`（"级" + 两个空格）
			return "%d级  %s" % [int(记.get("flag_level", 1)), String(记.get("flag_name", ""))]
		"本周击杀BOSS数":
			return str(int(记.get("boss_sum", 0)))
	return ""


## 选中的那条家族（没选中 / 行数变了 ⇒ 空字典）。宿主发「申请加入」时读它 ——
## 对应原版 `joinJiaZhuHandler`（`FL:364-372`）读 `list.selectedItem.id`。
func 选中家族() -> Dictionary:
	if _选中序 < 0 or _选中序 >= _家族表.size():
		return {}
	return _家族表[_选中序] as Dictionary


## 点行选中。⚠️ **形参顺序必须是 `(事件, 序)`**：`Callable.bind()` 的参数追加在信号参数
## **之后**，`gui_input` 先发事件 —— 写成 `(序, 事件)` 会报 `Cannot convert argument 1`
## 然后静默什么都不做，也就是**列表行根本点不中**（原版靠 `list.selectedItem` 才发得出
## 「申请加入」的家族 id）。2026-10-07 与 `家族子窗.gd`/`家族子窗壳.gd` 那两处一并修。
func _点行(事件: InputEvent, 序: int) -> void:
	if not (事件 is InputEventMouseButton):
		return
	var 按 := 事件 as InputEventMouseButton
	if 按.pressed and 按.button_index == MOUSE_BUTTON_LEFT:
		_选中(序)
		get_viewport().set_input_as_handled()


func _选中(序: int) -> void:
	_选中序 = 序
	for i in _行.size():
		var 底 := _行[i].get_node_or_null("选中底") as NinePatchRect
		if 底 != null:
			底.visible = i == 序 or i == _悬停序


func _悬停(行: Control, 进: bool) -> void:
	if not is_instance_valid(行):
		return
	var 序 := int(行.get_meta("row_index", -1))
	_悬停序 = 序 if 进 else -1
	var 底 := 行.get_node_or_null("选中底") as NinePatchRect
	if 底 != null:
		底.visible = 进 or 序 == _选中序


## ⚠️ 前缀必须是**窗名**（= 场景文件名），**不是根节点名**。
##    `家族列表窗.tscn` 的根叫「原版家族列表内容」，用根名拼出来的是
##    「原版家族列表内容:申请加入」—— 宿主的 `开窗`/`收窗` 与 `_show_guild_action`
##    里都没有这个键，于是**两个钮都静默什么都不做**（2026-09-30 在线用例抓到的；
##    其它子窗的根恰好等于窗名，所以这个坑只在这一窗显形）。
func _窗名() -> String:
	var 路 := get_scene_file_path()
	return 路.get_file().get_basename() if not 路.is_empty() else "家族列表窗"


func _发动作(名: String) -> void:
	if _宿主 != null and _宿主.has_method("_show_guild_action"):
		_宿主.call("_show_guild_action", "%s:%s" % [_窗名(), 名])


func _上限() -> float:
	return 0.0 if _列 == null else maxf(0.0, _列.size.y - _可视)


func _滚像素(px: float) -> void:
	_偏移 = clampf(_偏移 + px, 0.0, _上限())
	_同步滚动()


func _滚轮(事件: InputEvent) -> void:
	if not (事件 is InputEventMouseButton) or not (事件 as InputEventMouseButton).pressed:
		return
	var 键 := 事件 as InputEventMouseButton
	if 键.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_滚像素(-12.0 if 键.button_index == MOUSE_BUTTON_WHEEL_UP else 12.0)
		get_viewport().set_input_as_handled()


func _同步滚动() -> void:
	if _列 == null or _条 == null:
		return
	var 上限 := _上限()
	_条.visible = 上限 > 0.0
	_列.position.y = -_偏移
	if _滑块 != null:
		var 轨道 := 241.0					# 滚动槽 14..255（箭头各 14，`ScrollBar.as:278,283`）
		var 高 := maxf(20.0, 轨道 * _可视 / maxf(_可视, _可视 + 上限))
		_滑块.size = Vector2(15.0, 高)
		var 比 := 0.0 if 上限 <= 0.0 else _偏移 / 上限
		_滑块.position = Vector2(0.0, 14.0 + (轨道 - 高) * 比)
		var 底 := _条.get_node_or_null("滑块底") as NinePatchRect
		if 底 != null:
			底.position = _滑块.position
			底.size = _滑块.size


## 勾选。⚠️ **形参顺序必须是 `(事件, 勾)`** —— `Callable.bind()` 的参数追加在信号参数
## **之后**，`gui_input` 先发事件，写成 `(勾, 事件)` 会报 `Cannot convert argument 1`
## 然后静默什么都不做（`家族子窗.gd` 里那份同一个错，2026-10-07 一并修）。
func _翻复选(事件: InputEvent, 勾: Control) -> void:
	if 事件 is InputEventMouseButton and (事件 as InputEventMouseButton).pressed 			and (事件 as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_勾上 = not _勾上
		(勾.get_node("框") as TextureRect).texture = load(
			"res://素材/界面/原版窗口/家族/复选框%s.png" % ("_选中" if _勾上 else ""))
		get_viewport().set_input_as_handled()


func _换皮(钮: TextureButton, 态: int) -> void:
	var 后缀 := ""
	if 钮.disabled:
		后缀 = "_灰"
	elif 态 == 1:
		后缀 = "_悬停"
	elif 态 == 2:
		后缀 = "_按下"
	钮.texture_normal = load(钮皮 % [61, 后缀]) as Texture2D
	var 字 := 钮.get_node_or_null("Label") as Label
	if 字 != null:
		字.add_theme_color_override("font_color", Color.WHITE if not 钮.disabled else Color("#939393"))


# ── 分页 / 排序 / 下拉的接线 ────────────────────────────────────────────────
#
# 这几样原来全是**空转控件**：场景里建好了，`装配` 一条都没接。
# 后果最重的是「每页」默认 10（原版 `initView` 的 `selectedIndex = 0`）配上分页钮不生效 ——
# 玩家永远只能看到前 10 个家族，而需求正是"看到所有游戏中已经创建的家族"。

## 接一个 `MComboBox` 式下拉。`取当前` / `选中` 都是 Callable（参数：索引）。
func _接下拉(节点名: String, 选项: Array, 取当前: Callable, 选中: Callable) -> void:
	var 钮 := get_node_or_null(节点名) as TextureButton
	if 钮 == null:
		return
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_刷新下拉文字(钮, 选项, int(取当前.call()))
	钮.pressed.connect(func() -> void:
		if _下拉钮 == 钮:
			_关下拉()
			return
		_弹下拉(钮, 选项, 取当前, 选中))


## 触发器上那行文字（原版 MComboBox 的 selectedLabel）。
func _刷新下拉文字(钮: TextureButton, 选项: Array, 序: int) -> void:
	var 字 := 钮.get_node_or_null("文字") as Label
	if 字 != null:
		字.text = String(选项[clampi(序, 0, 选项.size() - 1)])


## 两个下拉的取值/选中回调（具名方法，理由见 `装配` 里的说明）。
func _取每页序() -> int:
	return _每页序


func _选每页(序: int) -> void:
	_每页序 = clampi(序, 0, 每页选项.size() - 1)
	_页码 = 1
	_重算()


func _取显示序() -> int:
	return 0


## 「显示」暂为惰性：服务端行里没有 `autoAccept`，按它筛只会得到编出来的结果。
func _选显示(_序: int) -> void:
	pass


## 下拉列表本身。挂到**窗根**上（不是内容页里）—— 内容页会被列表窗口裁掉，
## 下拉就压不住下面那些行。点别处/再点触发器都会收掉（见 `_input`）。
func _弹下拉(锚: TextureButton, 选项: Array, 取当前: Callable, 选中: Callable) -> void:
	_关下拉()
	var 层 := get_parent() as Control
	if 层 == null:
		return
	var 宽 := 0.0
	for 文 in 选项:
		宽 = maxf(宽, _字宽(String(文)))
	宽 = maxf(宽 + 6.0, 锚.size.x)
	var 底 := Panel.new()
	底.name = "下拉"
	var 底皮 := StyleBoxTexture.new()
	底皮.texture = load(菜单底皮) as Texture2D
	for i in 4:
		底皮.set("texture_margin_%s" % ["left", "top", "right", "bottom"][i], [5.75, 4.75, 9.75, 11.0][i])
	底.add_theme_stylebox_override("panel", 底皮)
	底.mouse_filter = Control.MOUSE_FILTER_STOP
	层.add_child(底)
	var 顶 := 下拉边
	for i in 选项.size():
		var 项 := Button.new()
		项.name = "项%d" % i
		项.text = String(选项[i])
		项.flat = true
		项.focus_mode = Control.FOCUS_NONE
		项.add_theme_font_size_override("font_size", 12)
		项.add_theme_color_override("font_color", Color("#FCF49C"))
		项.position = Vector2(下拉边, 顶)
		项.size = Vector2(宽 - 6.0, 下拉项高)
		_贴项皮(项)
		# ⚠️ 用 `bind` 把序号**显式**带进去，不靠 lambda 捕获 `i`（循环变量的捕获语义不值得赌）。
		项.pressed.connect(_选下拉项.bind(选中, 取当前, 锚, 选项, i))
		底.add_child(项)
		顶 += 下拉项高 + 下拉边
	底.size = Vector2(宽 + 4.0, 顶 + 3.0)
	底.global_position = Vector2(锚.global_position.x, 锚.global_position.y + 锚.size.y + 2.0)
	_下拉 = 底
	_下拉钮 = 锚


func _选下拉项(选中: Callable, 取当前: Callable, 锚: TextureButton, 选项: Array, 序: int) -> void:
	_关下拉()
	选中.call(序)
	# 触发器文字从 `取当前` **重新读**，而不是直接写 `选项[序]`：像「显示」那种当前值恒为 0
	# 的下拉，直接写下选中项的文字就成了一句谎话（选了"自动招人家族"其实并没有筛）。
	_刷新下拉文字(锚, 选项, int(取当前.call()))


func _关下拉() -> void:
	if _下拉 != null and is_instance_valid(_下拉):
		_下拉.queue_free()
	_下拉 = null
	_下拉钮 = null


## 点下拉以外的任何地方都收掉（原版 `MComboBox` 失焦即收）。
func _input(事件: InputEvent) -> void:
	if _下拉 == null or not is_instance_valid(_下拉):
		return
	var 按 := 事件 as InputEventMouseButton
	if 按 == null or not 按.pressed or 按.button_index != MOUSE_BUTTON_LEFT:
		return
	if not (_下拉 as Control).get_global_rect().has_point(按.global_position):
		_关下拉()


func _贴项皮(钮: Button) -> void:
	var 皮 := StyleBoxTexture.new()
	皮.texture = load(菜单项皮) as Texture2D
	for i in 4:
		皮.set("texture_margin_%s" % ["left", "top", "right", "bottom"][i], [2.25, 2.0, 2.5, 2.5][i])
	for 态 in ["normal", "hover", "pressed"]:
		钮.add_theme_stylebox_override(态, 皮)


## 分页钮：`目标页` 是个 Callable（首页 1 / 上一页 _页码−1 / 下一页 _页码+1 / 末页 _总页数）。
func _接翻页钮(路径: String, 目标页: Callable) -> void:
	var 钮 := get_node_or_null(路径) as TextureButton
	if 钮 == null:
		return
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.pressed.connect(func() -> void:
		var 新 := clampi(int(目标页.call()), 1, _总页数())
		if 新 == _页码:
			return
		_页码 = 新
		_重算())


## 列头点击排序（原版 `SanJiaoLabel` + `clickSanJiaoLabelHandler`，`FL.as:174-189,377-382`）。
## 场景里那一格是 `Label`（原版是可点的 `SanJiaoLabel`）⇒ 运行时把 `mouse_filter` 打开再加输入。
## 列宽就是那一格的宽度（版式里 `createSanJiaoLable` 的第 3 参就是列宽），无需再改尺寸。
func _接列头(列: String) -> void:
	var 头 := get_node_or_null("表头/%s" % 列) as Label
	if 头 == null:
		return
	头.mouse_filter = Control.MOUSE_FILTER_STOP
	头.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	头.gui_input.connect(func(事件: InputEvent) -> void:
		var 按 := 事件 as InputEventMouseButton
		if 按 == null or not 按.pressed or 按.button_index != MOUSE_BUTTON_LEFT:
			return
		if _排序列 == 列:
			return
		_排序列 = 列
		_页码 = 1
		_重算()
		_同步三角()
		get_viewport().set_input_as_handled())


## 排序三角只亮在**当前排序列**（`FL.as:171` 里「家徽」那一列不可点，它的三角恒不亮）。
func _同步三角() -> void:
	for 列 in ["家徽", "家族名称", "现任族长", "族中人数", "等级总和", "家徽等级", "本周击杀BOSS数"]:
		var 三 := get_node_or_null("表头/三角%s" % 列) as TextureRect
		if 三 != null:
			三.visible = 列 == _排序列


func _接滚动钮(路径: String, 行数: float) -> void:
	var 钮 := get_node_or_null(路径) as TextureButton
	if 钮 == null:
		return
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.pressed.connect(func() -> void: _滚像素(行数 * 行高))


## 下拉宽度用的字宽估算（中文 12px、其余 6px，与 `好友菜单._字宽` 同一套）。
func _字宽(文: String) -> float:
	var 尺 := 0.0
	for i in 文.length():
		尺 += 12.0 if 文.unicode_at(i) > 0x2E80 else 6.0
	return 尺
