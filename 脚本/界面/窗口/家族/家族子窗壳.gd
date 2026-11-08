extends RefCounted

const 家族列表填充 := preload("res://脚本/界面/窗口/家族/家族列表填充.gd")
const 家族成员填充 := preload("res://脚本/界面/窗口/家族/家族成员填充.gd")
const 家族贡献填充 := preload("res://脚本/界面/窗口/家族/家族贡献填充.gd")
const 家族旗帜填充 := preload("res://脚本/界面/窗口/家族/家族旗帜填充.gd")
const 家族令牌填充 := preload("res://脚本/界面/窗口/家族/家族令牌填充.gd")
const 家族商城填充 := preload("res://脚本/界面/窗口/家族/家族商城填充.gd")
const 家族升级填充 := preload("res://脚本/界面/窗口/家族/家族升级填充.gd")
const 家族创建填充 := preload("res://脚本/界面/窗口/家族/家族创建填充.gd")

## 家族子窗外壳 = 原版 `UIWindow`/`MWindow` 的**窗壳**，把 SPEC 生成的"内容页"包成能开的浮窗。
##
## 窗壳三件的落点全部来自 `MWindow.as:162-221`（`drawWindowLayout`）：
##   标题  y = 5、高 18、整幅居中
##   关钮  x = round(背景宽 − 钮宽 − 6)、y = 标题y + 1 = 6（`MWindowCloseBtnF` 25×24）
##   内容  `UIWindow.as:36-38`：`_contentBg = (CONTENT_GAP=8, 38)`
##
## 内容页自己不含窗壳，且它的尺寸是 **窗−16 × 窗−38**（不是 −68）：底栏钮/分页在 AS3 里挂在
## **窗口**上、y 按 `_height − 钮高 − 5` 算，会落到 contentBg 下沿之外。
## ⇒ 反推窗尺寸 = 内容 + (16, 38)（成员窗 634×332 ⇒ 650×370 ✓）。
##
## `壳=假` 的三种（确认弹 / 旗帜帮助 / Boss 两窗）原版就不是 UIWindow：自带整幅底和自己的关钮
## （580 号 / 外载帮助图 / 175 号）⇒ 不套窗壳，内容即窗。
##
## 拖动：`MWindow.isDrag` 默认 true（`FFH:26` 显式 false）⇒ 顶部 29px 是拖动区。
## ⚠ 拖动区必须排在关钮**之前**（Godot 按子节点逆序派发输入，否则吞掉关钮点击）。

const 内容原点 := Vector2(8, 38)
const 窗补 := Vector2(16, 38)		# 窗尺寸 = 内容尺寸 + 这个（见文件头）
const 关钮尺寸 := Vector2(25, 24)
const 关钮边 := 6.0			# `MWin.as:212`
const 标题Y := 5.0			# `MWin.as:173` 非小底标题 y = 5
const 拖动高 := 29.0			# `MWin.as:176` titleBackground 以 29 为标题栏基准高
const 关钮皮 := "res://素材/界面/原版窗口/通用控件/关闭按钮.png"
## 那颗 X 的交互态状态机（悬停 +30 / 按下 −40，`StyleUtil.as:7-12`）。
## 和挂机页那 27 枚勾、每一扇原版窗的 X **同一族**（`MWindowCloseBtnF.as` `extends MButton3`）
## ⇒ 只能预烘派生皮 + 换 `texture_normal`；`texture_hover`（松手仍亮）和 `modulate`（乘性）都不许用。
const 三态皮 := preload("res://脚本/界面/组件/原版三态钮.gd")
const 子窗目录 := "res://场景/界面/窗口/家族/"
## 把窗名塞给内容页用的 meta 键（`家族子窗.装配` 读它）。
## ⚠️ 必须 ASCII：中文键在这个工程里会被静默丢掉（`set_meta("档")` 那次教训）。
const guild_subwindow_name_meta_key := "guild_subwindow_name"

## ── 「独立底」：给**下面没有不透明主窗垫着**的子窗用的一层自带底 ────────────────
##
## 为什么要有它：子窗的窗皮是 `窗口边框.png`（`OrigWindowFrame`），实测其**内部像素
## alpha 只有 0.843**（采样器 `开发工具/探窗皮透明度.gd`）。家族这套子窗平时都开在
## 「家族主窗」上面，两层窗皮叠起来才够实（0.843 + 0.843×0.157 ≈ 0.975，看着就是实心）。
## 而**未入族的家族列表窗是全屏唯一的一扇** —— 主窗被藏掉了（原版 `FM:1222-1239`
## 是二选一，只有列表窗），于是单层窗皮会透出底下的游戏画面。用户 2026-10-07 报的
## 「家族页还在」修完之后紧接着就会看到这一层变半透。
## ⇒ 这种"独立显示"的子窗自带一层底，尺寸跟着窗根走（拖动也一起动）。
##
## ⚠️ 这层底是**第二张窗框皮**（`OrigWindowFrame`），不是不透明色块：
##    窗框是**圆角**的，四角在贴图里 alpha = 0（实测同见 `探窗皮透明度.gd` 的「角(...)」），
##    铺满整块矩形的实色会把圆角外那两块涂成黑方块 ——
##    用户 2026-10-07 报的「家族列表左上/右上两块黑」就是这一条。
const 独立底名 := "独立底"

## 每个宿主（`功能窗口` 实例）各存自己开过的子窗：`窗口管理` 是一页一实例，不能串。
static var _已开 := {}

## ── 动作 → 窗 的注册表（原版 `FamillyManager.showWindow(UIConfig.FAMILLY_*_WINDOW)` 的对应物）──
## 放这里而不是 功能窗口：① 窗壳与它的落点/标题本来就是一体的；
## ② `功能窗口.gd` 的 preload 链很长，门想读这张表就得整包加载（还会牵出一串无关的解析噪声）。
## 标题 = 语言表字面值（`真值/窗口/家族.md` §5）；第三项 = 要不要套 MWindow 窗壳
## （确认弹/旗帜帮助/Boss 两窗原版不是 UIWindow ⇒ 壳=假）。
## key 用 `入口名` 或 `窗名:钮名`（后者是子窗自己的钮交回来的动作串）。
const 开窗 := {
	"家族列表": ["家族列表窗", "家族列表", true],			# FAMILLY_LIST_WINDOW_TITLE
	"家族升级": ["家族升级窗", "家族升级", true],			# FAMILLY__WINDOW_SHENGJI
	"家族尾兽": ["家族守卫窗", "设置家族尾兽活动时间", true],	# FAMILLY_PET_WINDOW_TITLE
	"家族旗帜": ["家族旗帜窗", "家族旗帜", true],			# FAMILLY_FLAG_WINDOW_TITLE
	"家族贡献": ["家族贡献窗", "家族贡献", true],			# FAMILLY_GONGXIAN_WINDOW_TITLE
	"家族商店": ["家族商城窗", "家族商城", true],			# FAMILLYSHOP_TITLE
	"成员信息": ["家族成员窗", "成员管理", true],			# FAMILLY_MEMBERS_WINDOW_TITLE
	"家族列表窗:创建家族": ["家族创建窗", "家族创建", true],		# FC:132
	"家族成员窗:添加成员": ["家族搜索窗", "查询玩家", true],		# SPW:88 SELCET_PLAYER_WINDOW_TITLE
	"家族成员窗:解散家族": ["家族确认弹", "解散家族", false],		# FM:421-429 走确认弹
	"家族成员窗:退出家族": ["家族确认弹", "退出家族", false],
	# 升级也要二次确认：原版 `FamillyUpgradeWindow.clickOkBtnHandler`（FUW.as:41-44）——
	# 点「确定」先弹 `FamillyPopUpWindow`（正文 `FAMILLY_UPGRADE_WINDOW_SHENGJI_OK`
	# 「你确定要升级吗？」、确定钮 `FAMILLY_UPGRADE_WINDOW_SHENGJI`「升级」），
	# **不是**直接发协议。真发协议在弹窗的「确定」里（`sureToUpgrade`，FUW.as:37-40）。
	"家族升级窗:确定": ["家族确认弹", "家族升级", false],
	# 主窗公告区那个钮：在族是「修改」（走 `1552:7`，见 `家族窗口._按修改钮`），
	# 不在族文案变「创建家族」⇒ 开创建窗（原版 `FamillyManager.showWindow(CREATE)`）。
	"修改钮": ["家族创建窗", "家族创建", true],
	"家族贡献窗:贡献金币": ["家族金币窗", "族　贡", true],		# ZGM:116 标题也是 ZUGONGLING_WINDOW_TITLE
	"家族贡献窗:贡献书籍": ["家族令牌窗", "族　贡", true],		# ZGL:41
	"家族旗帜窗:说明资讯": ["家族旗帜帮助窗", "家族旗帜帮助", false],	# FFH:整幅外载图、无窗壳
}
## 取消/关闭类动作 = 收掉自己那扇窗（原版 `onCloseBtnClick`）。
## ⚠ `确定`/`购买` 不在这里：那些要发协议，等服务器数据接上再动，别在 UI 层假装成功。
##    （`申请加入` 已于 2026-09-30 接上，但它的协议在 `功能窗口._发申请加入`，因为要先读
##      列表窗里**选中**的那一行 —— 开关窗表读不到选中态。）
## ⚠ Boss 两窗（奖励条/完成窗）原版由家族 BOSS 事件推开、没有 UI 入口 ⇒ 只出现在收窗表。
const 收窗 := {
	"家族升级窗:取消": "家族升级窗",
	"家族令牌窗:取消": "家族令牌窗",
	"家族金币窗:取消": "家族金币窗",
	"家族确认弹:取消": "家族确认弹",
	"家族确认弹:确定": "家族确认弹",
	"家族搜索窗:取消": "家族搜索窗",
	"家族Boss完成窗:关闭": "家族Boss完成窗",
	"家族Boss奖励条:收起": "家族Boss奖励条",
}


## 子窗钮交回来的动作串 → 开/收对应窗。`功能窗口._show_guild_action` 只在开头调这一行，
## 原有的 `request_*` 一条都不动 ⇒ 协议/逻辑零改动。
static func 按动作(宿主: Object, 动作: String) -> void:
	var 开: Array = 开窗.get(动作, [])
	if 开.size() == 3:
		切换(宿主, String(开[0]), String(开[1]), bool(开[2]))
	var 收 := String(收窗.get(动作, ""))
	if 收 != "":
		关掉(宿主, 收)


## 开关式：再点同一个入口 = 收起（同 `窗口管理.打开或收起` 的手感）。
##
## `目录` = 子窗场景所在的目录（默认家族那一份）。好友页复用这一套窗壳，传
## `res://场景/界面/窗口/好友/`（见 `好友页_给融合方的说明.md` §2 ④）。
##
## `独立` = 这扇窗**下面没有不透明主窗垫着**（未入族时的家族列表窗就是这样）⇒ 自带一层
## 不透明底。放在参数表**最后**：前面几位的实参在好友页那边是按位置传的，插在前面会错位。
static func 切换(宿主: Object, 窗名: String, 标题: String, 有壳 := true, 目录 := 子窗目录,
		独立 := false) -> void:
	var 表: Dictionary = _已开.get(宿主, {})
	_已开[宿主] = 表
	# ⚠️ 表里可能留着**上一次收掉的窗**（已 queue_free），而 `as Control` 对已释放对象
	#    不是返回 null、是**当场抛 "Trying to cast a freed object"** —— 这一抛会把整个
	#    开窗流程打断在第一行，表现为"点了按钮没反应"（用户 2026-10-05 报的
	#    「无法退出家族」：确认弹收过一次之后，再点「退出家族」就再也开不出来）。
	#    ⇒ 一律先用 Variant 判 `is_instance_valid`，确认活着才 cast。
	var 旧 := _存活(表, 窗名)
	if 旧 != null and 旧.get_parent() != null:
		关掉(宿主, 窗名)
		return
	var 内容 := (load(目录 + 窗名 + ".tscn") as PackedScene).instantiate() as Control
	var 尺 := 内容.get_combined_minimum_size()
	var 根 := Control.new()
	根.name = "家族子窗_" + 窗名
	根.add_child(内容)
	if 有壳:
		_装窗壳(根, 内容, 标题, 尺 + 窗补, 宿主, 窗名)
	内容.position = 内容原点 if 有壳 else Vector2.ZERO
	根.custom_minimum_size = 尺 + 窗补 if 有壳 else 尺
	根.size = 根.custom_minimum_size
	if 有壳 and 独立:
		_铺独立底(根)
	var 层 := 宿主.get("_overlay") as Control
	if 层 == null:
		push_error("家族子窗：宿主没有 _overlay，开不出来")
		根.free()		# 内容挂在根上，只放根（先放子再放父会二次释放）
		return
	层.add_child(根)
	根.position = Vector2(floorf(maxf(0.0, (层.size.x - 根.size.x) * 0.5)),
			floorf(maxf(0.0, (层.size.y - 根.size.y) * 0.5)))
	表[窗名] = 根
	# 窗名**由壳显式交给内容页**：场景里那行 `窗名 = "..."` 在部分窗上没被认成脚本属性
	# （读出来是空串），子窗的按钮就会拼出没有前缀的动作串 ⇒ 点击静默失效。
	# 走 meta 而不走 `装配` 的第二参数：`家族列表窗.gd` 的装配是单参数的。
	内容.set_meta(guild_subwindow_name_meta_key, 窗名)
	内容.call("装配", 宿主)
	# ⚠️ 我们的补充（用户定的分工：UI 以他为主、逻辑归我们）：
	#    他的子窗只做了 UI，成员/家族列表/族旗的行渲染器没移植（说明 §5.2）。
	#    数据来源都是主项目已有的权威解析，见各自的文件头。
	家族列表填充.填(内容, 宿主)
	家族成员填充.填(内容, 宿主)
	家族贡献填充.填(内容, 宿主)
	家族旗帜填充.填(内容, 宿主)
	家族令牌填充.填(内容, 宿主)
	家族商城填充.填(内容, 宿主)
	家族升级填充.填(内容, 宿主)
	家族创建填充.填(内容, 宿主)


## 只在没开的时候开（页面每次重绘都会跑接线，用 `切换` 会把已经开着的窗又关掉）。
static func 只在未开时开(宿主: Object, 窗名: String, 标题: String, 有壳 := true,
		目录 := 子窗目录, 独立 := false) -> void:
	if not 已开(宿主, 窗名):
		切换(宿主, 窗名, 标题, 有壳, 目录, 独立)


## 某扇**已经开着**的子窗，事后补/撤它的「独立底」（见 `独立底名`）。
##
## 为什么需要事后同步：宿主的不透明主窗显隐会变（家族页在"在族/未在族"之间切），
## 而窗可能**早就开着了** —— 开窗那一刻传的 `独立` 这时已经过期。典型场景是**退族**：
## `退族要收的窗` 特意不收家族列表窗，于是它是"开着的那扇"，主窗却在同一刻转为隐藏。
static func 设独立底(宿主: Object, 窗名: String, 要: bool) -> void:
	var 根 := _存活(_已开.get(宿主, {}) as Dictionary, 窗名)
	if 根 == null:
		return
	var 底 := 根.get_node_or_null(独立底名) as Panel
	if 要:
		if 底 == null:
			_铺独立底(根)
	elif 底 != null:
		根.remove_child(底)
		底.queue_free()


## 在窗根里铺一层「独立底」，并挪到 0 号位 —— `_装窗壳` 已经把窗壳摆在 0 了，
## 底必须垫在窗壳**之下**（后加的子节点画在上层，不挪的话底会盖住整扇窗）。
##
## ⚠️ 垫的必须是**同一张窗框九宫格**（`OrigWindowFrame`），**不能**用不透明 `ColorRect`：
##    窗框是**圆角**的，四角在贴图里 alpha = 0（实测见 `开发工具/探窗皮透明度.gd` 的「角(...)」）；
##    铺满整块矩形的实色会把圆角外那两块涂成黑方块 ——
##    用户 2026-10-07 报的「家族列表左上/右上两块黑」就是这一条。
##    用同一张皮叠第二层，既是原来的观感（α 0.843 两层 ≈ 0.975），圆角也照样透。
static func _铺独立底(根: Control) -> void:
	var 底 := Panel.new()
	底.name = 独立底名
	底.theme_type_variation = &"OrigWindowFrame"
	底.set_anchors_preset(Control.PRESET_FULL_RECT)
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	根.add_child(底)
	根.move_child(底, 0)


## 取某扇子窗的**内容页**（没开/已收 ⇒ null）。宿主想跟窗内控件说话时走这里。
##
## ⚠️ 别自己去 `_overlay.get_node_or_null("家族子窗_X/X")` 拼路径 —— 那要求**场景根节点名
## 恰好等于窗名**，而 `家族列表窗.tscn` 的根叫「原版家族列表内容」，路径恒为 null，
## 于是「申请加入」静默什么都不做（2026-09-30 的在线用例抓到的）。这里直接问壳自己记的表。
##
## ⚠️ 也不能取 `get_child(0)`：有壳时 `_装窗壳` 会把「窗壳」移到 0 号位（半透窗皮要垫在内容下），
##    内容就成了 1 号 ⇒ 取到的是那张 Panel。所以**跳过窗壳那个节点**取第一个别的孩子。
##    带「独立底」的窗（未入族的家族列表窗）在 0 号位还多一层底，一并跳过。
static func 取内容(宿主: Object, 窗名: String) -> Control:
	var 根 := _存活(_已开.get(宿主, {}) as Dictionary, 窗名)
	if 根 == null or 根.get_parent() == null:
		return null
	for 子 in 根.get_children():
		if 子.name == "窗壳" or 子.name == 独立底名:
			continue
		return 子 as Control
	return null


## 某扇子窗此刻开着吗（页面重绘时用它避免"再刷一次反而把窗关掉"）。
static func 已开(宿主: Object, 窗名: String) -> bool:
	var 根 := _存活(_已开.get(宿主, {}) as Dictionary, 窗名)
	return 根 != null and 根.get_parent() != null


## 收掉某扇子窗（`取消`/`关闭` 类动作走这里；没开过就什么都不做）。
static func 关掉(宿主: Object, 窗名: String) -> void:
	var 表: Dictionary = _已开.get(宿主, {})
	var 根 := _存活(表, 窗名)
	# ⚠️ 表项**必须先摘再放**：原来写成 `return 表.erase(窗名)`（一行里 `return` 在前），
	#    `erase` 是永远不会执行的死代码 ⇒ 收掉的窗一直留在这张表里。
	#    下次 `切换` 取到它，`as Control` 对已释放对象直接抛错，窗就再也开不出来了。
	表.erase(窗名)
	if 根 != null:
		var 父 := 根.get_parent()
		if 父 != null:
			父.remove_child(根)
		根.queue_free()
	_通知宿主已收(宿主, 窗名)


## 收窗之后回头告诉宿主一声。只有 `功能窗口` 认这个消息（它实现 `_家族子窗已收`），
## 别的宿主（`测试/假家族宿主.gd`、好友页那一套）没这个方法就静默跳过。
##
## 为什么需要它：未入族时家族主窗（= 通用窗壳）是不显示的，屏上只剩 `遮罩`
## （一张接点击、不画东西的暗层）+ 家族列表窗。玩家点列表窗自己的关钮收掉它之后，
## **遮罩还在** —— 画面看着是正常游戏，可点哪儿都没反应。详见 `功能窗口._家族子窗已收`。
static func _通知宿主已收(宿主: Object, 窗名: String) -> void:
	if not is_instance_valid(宿主):
		return
	if 宿主.has_method("_家族子窗已收"):
		宿主.call("_家族子窗已收", 窗名)


## 从登记表里取一个**还活着**的窗根；已释放的顺手清掉（返回 null）。
## 统一在这里做，是因为 `as Control` 碰到 freed object 是**抛错**而不是返回 null。
static func _存活(表: Dictionary, 窗名: String) -> Control:
	var 值: Variant = 表.get(窗名)
	if 值 == null:
		return null
	if not is_instance_valid(值):
		表.erase(窗名)
		return null
	return 值 as Control


static func _装窗壳(根: Control, 内容: Control, 标题: String, 尺: Vector2, 宿主: Object, 窗名: String) -> void:
	var 框 := Panel.new()
	框.name = "窗壳"
	框.set_anchors_preset(Control.PRESET_FULL_RECT)
	框.theme_type_variation = &"OrigWindowFrame"
	框.mouse_filter = Control.MOUSE_FILTER_STOP
	根.add_child(框)
	根.move_child(框, 0)			# 半透窗皮必须在内容之下
	var 拖 := Control.new()
	拖.name = "拖动区"
	拖.size = Vector2(尺.x, 拖动高)
	根.add_child(拖)				# 排在关钮之前（见文件头）
	拖.gui_input.connect(_拖.bind(根))
	var 题 := Label.new()
	题.name = "标题"
	题.text = 标题
	题.theme_type_variation = &"OrigWindowTitle"
	题.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	题.mouse_filter = Control.MOUSE_FILTER_IGNORE
	题.position = Vector2(0.0, 标题Y)
	题.size = Vector2(尺.x, 18.0)
	根.add_child(题)
	var 关 := TextureButton.new()
	## `set_script` 必须在**设皮之前**：状态机是在 `_ready()`（= `add_child` 那一刻）抄常态皮当主干，
	## 皮晚设一步就抄不到 ⇒ 它认定"这颗没有可换的皮"，整条静默不接（不报错，看着像悬停没做）。
	关.set_script(三态皮)
	关.name = "关闭按钮"
	关.texture_normal = load(关钮皮) as Texture2D
	关.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND		# `MButton3.init()` `:135`
	关.ignore_texture_size = true
	关.focus_mode = Control.FOCUS_NONE
	关.size = 关钮尺寸
	关.position = Vector2(round(尺.x - 关钮尺寸.x - 关钮边), 标题Y + 1.0)
	关.tooltip_text = "关闭"
	根.add_child(关)
	关.pressed.connect(关掉.bind(宿主, 窗名))


## 拖动窗壳。⚠️ **形参顺序必须是 `(事件, 根)`**：`Callable.bind()` 的参数**追加在信号参数
## 之后**，`gui_input` 先发事件，所以连出来实际调用的是 `(事件, 根)` —— 写成 `(根, 事件)`
## 会报 `Cannot convert argument 1 from Object to Object.`，表现为**子窗根本拖不动**
## （2026-10-07 修说明窗复选框时顺出来的同一类错；本工程别处都是"事件在前"，只有家族这几处写反了）。
static func _拖(事件: InputEvent, 根: Control) -> void:
	if 事件 is InputEventMouseButton:
		var 按 := 事件 as InputEventMouseButton
		if 按.button_index == MOUSE_BUTTON_LEFT:
			# ⚠️ 键**必须 ASCII**（原来是 `"拖"`）：中文键会被 `set_meta` 拒掉，
			#    于是 `get_meta` 每次都拿默认 `Vector2.INF` —— **拖动一次都生效不了**，
			#    而且不报错、只是没反应（§3.64.4 坑清单同一条）。
			根.set_meta("drag_grab", 根.get_global_mouse_position() - 根.position if 按.pressed else Vector2.INF)
	elif 事件 is InputEventMouseMotion and (事件 as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		var 起 := 根.get_meta("drag_grab", Vector2.INF) as Vector2
		if 起 != Vector2.INF:
			根.position = 根.get_global_mouse_position() - 起
