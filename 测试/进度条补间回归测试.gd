extends SceneTree

## 报修 **#55**「进度条没有补间、数值一跳一跳」的离线门。
## 真值：`真值/窗口/进度条补间.md`（`MBar.as:128-175` + `gs/TweenLite.as:28/95-117/154-158/199-202`）。
##
## 钉五组东西：
##   A **口径**（`夹过 / 比例 / 滑条终位`）—— 含原版三条反直觉的：超上限夹到上限、
##     `上限 0 ⇒ 满条`（`_isShowBar` 默认 true）、`(-1,-1)` 也算满条；
##   B **件的行为**：动的是补间不是直给（灌完当帧还在原位）、0.5s 内收敛、
##     **同数据整条早退**（`MBar.as:130-133`）、**换数据杀旧补间并从当前位续**（overwrite=1）、
##     曲线是**二次缓出**（`TRANS_QUAD` + `EASE_OUT`，缺省不是它）；
##   C **站点**：`设置状态条` 的字按数据算（读 `条.value` 就会跟着条爬）、
##     `看别人条` 的 `0/0` 画满条、宠物那根滑条同一条早退口径；
##   D **不该动的**：地图头顶血条 `CommonHpBar`（`CommonHpBar.as:18-43` 每帧重画、没有补间）
##     —— 挂机每秒多包，补间会让血条永远追不上真值；
##   E **整页重建续接 / 换页直落**：`功能窗口._render_page` 每帧整棵拆掉重造 ⇒ 新条回到 `.tscn` 烘的默认值。
##     · **同一页**的回帧重建：拆页前按相对路径记下视觉值，建新补间前接回去 ⇒ 60→65 从 60 起（§3.331）；
##     · **换页 / 换页签 / 开窗**：条一律**直落真值**（`直落键`），切换后是多少就是多少，不许扫一遍
##       （用户 2026-10-31「每次切换面板，数值轴都会从 0→当前值」—— 换走的那一页停在 `.tscn` 默认值，
##       拿它当起点就是从 0 扫到当前值）。
##
## ⚠ 计时腿一律等**墙上时钟**（`create_timer`），不拿"等 N 帧"当"等半秒"（§3.207 的假红同源）。
##   中途那一发只断"在起点与终点之间"，**不拿具体时刻的数字当曲线证据** —— 无头帧距不稳，
##   那条会假红；曲线本身用源码字面钉（`TRANS_QUAD` / `EASE_OUT` / `0.5`）。
##
## 运行：Godot --headless --path . --script res://测试/进度条补间回归测试.gd

const 件 := preload("res://脚本/单例/进度条补间.gd")
const 人物脚本 := preload("res://脚本/界面/窗口/人物窗口.gd")
const 宠物脚本 := preload("res://脚本/界面/窗口/宠物窗口.gd")

var _失败: Array[String] = []
var _受检 := 0


## `设置状态条` / `看别人条` 只用到宿主的 `_configure_label` ⇒ 假窗就够（不拖整扇人物窗，
## 那会把 `窗口管理`、存档那一路也拽进来）。
class 假窗 extends RefCounted:
	func _configure_label(_字: Node, _号: int, _色: Color) -> void:
		pass


func _initialize() -> void:
	call_deferred("_跑")


func _查(对: bool, 明: String) -> void:
	_受检 += 1
	if not 对:
		_失败.append(明)


func _等(秒: float) -> void:
	await create_timer(秒).timeout


func _跑() -> void:
	_A口径()
	await _B件()
	await _C站点()
	await _E重建续接()
	_D不该动的()
	收尾()


# ── A. 口径 ────────────────────────────────────────────────────────
func _A口径() -> void:
	_查(is_equal_approx(件.夹过(20.0, 10.0), 10.0), "A：`cur>tot` 要夹到上限（`MBar.as:134-137`）")
	_查(is_equal_approx(件.夹过(5.0, 10.0), 5.0), "A：没超上限原样过")
	# 原版 `if (param1 > param2)` 对 `(-1,-1)` 不夹 ⇒ 后面 `tot > 0` 假 ⇒ 走 `_isShowBar` 那支
	_查(is_equal_approx(件.夹过(-1.0, -1.0), -1.0), "A：`(-1,-1)` 不该被夹（AS3 那条比的是 `>`）")
	_查(is_equal_approx(件.比例(2700.0, 5400.0), 0.5), "A：2700/5400 ⇒ 半条")
	_查(is_equal_approx(件.比例(20.0, 10.0), 1.0), "A：超上限按比例是满（先夹再算）")
	_查(is_equal_approx(件.比例(0.0, 0.0), 1.0),
		"A：**上限 0 ⇒ 满条**（`_isShowBar` 默认 true，`MBar.as:19/140-149`）")
	_查(is_equal_approx(件.比例(0.0, 0.0, false), 0.0),
		"A：`_isShowBar=false` 那一档才是空条（`GuwanshoujiInfoPanel.as:82`）")
	_查(is_equal_approx(件.比例(-1.0, -1.0), 1.0),
		"A：`SkillDetailPane.as:128-129` 的 `setData(-1,-1)` 原版算**满条**，不是空条")
	# `MBar.as:150` 的滑条几何：静止位 −3、槽 114 ⇒ 42/100 落在 −69（`宠物面板回归测试` 同一条）
	_查(is_equal_approx(件.滑条终位(114.0, 0.42, -3.0), -69.0),
		"A：滑条 42/100 该是 −69（= −3 − int(114×0.58)），实得 %.1f" % 件.滑条终位(114.0, 0.42, -3.0))
	_查(is_equal_approx(件.滑条终位(114.0, 1.0, -3.0), -3.0), "A：满条回到静止位 −3")
	_查(is_equal_approx(件.滑条终位(114.0, 0.0, -3.0), -117.0), "A：空条整条滑出遮罩")


# ── B. 件的行为 ────────────────────────────────────────────────────
func _建条(名: String) -> ProgressBar:
	var 条 := ProgressBar.new()
	条.name = 名
	条.min_value = 0.0
	条.max_value = 100.0
	条.value = 0.0
	root.add_child(条)
	return 条


func _补间对象(条: Node) -> Tween:
	return (条.get_meta(件.补间键) as Tween) if 条.has_meta(件.补间键) else null


func _B件() -> void:
	var 条 := _建条("条B")
	件.补间(条, "value", 50.0, [50, 100])
	# ① 当帧还在原位 —— 直给（改前）这里是 50，补间（原版）这里必须还是 0
	_查(is_equal_approx(条.value, 0.0),
		"B：灌完当帧条该还在**原位**（0），实得 %.1f —— 直给就没补间" % 条.value)
	await _等(0.25)
	_查(条.value > 0.001 and 条.value < 49.999,
		"B：0.25 秒时该在起点与终点**之间**，实得 %.1f" % 条.value)
	await _等(0.45)
	_查(is_equal_approx(条.value, 50.0), "B：0.7 秒后收敛到终值 50，实得 %.1f" % 条.value)

	# ② 同数据早退（`MBar.as:130-133`）：再灌一遍 `[50,100]` ⇒ **同一支**补间，不许重启
	var 第一支 := _补间对象(条)
	件.补间(条, "value", 50.0, [50, 100])
	_查(_补间对象(条) == 第一支 and 第一支 != null,
		"B：同数据再灌必须**整条早退**（重启补间 ⇒ 挂机每帧刷一次、条永远在爬）")
	# 数据里**上限**变了（终值仍是 50）⇒ 那是另一发数据，必须重新起
	件.补间(条, "value", 50.0, [50, 200])
	_查(_补间对象(条) != 第一支, "B：`[50,100] → [50,200]` 是不同数据，早退判据要比**入参**不是比终值")

	# ③ 换数据 ⇒ 旧补间被 kill、从当前位续（TweenLite overwrite=1）
	#    ⚠ 必须趁旧补间**还在跑**时灌下一发：跑完的 Tween 自己就 `is_valid() == false`，
	#    那时候再判"被 kill"等于没判（假绿就是这么来的）。
	件.补间(条, "value", 100.0, [100, 100])
	var 跑着的 := _补间对象(条)
	_查(跑着的 != null and 跑着的.is_valid(), "B：新补间该挂在条自己身上（meta），实为 null")
	_查(is_equal_approx(条.value, 50.0), "B：续算的起点是**当前视觉位置** 50，实得 %.1f" % 条.value)
	await _等(0.25)
	var 路上 := 条.value
	_查(路上 > 50.001 and 路上 < 99.999, "B：0.25 秒时该在 50→100 半路上，实得 %.1f" % 路上)
	件.补间(条, "value", 20.0, [20, 100])
	_查(not 跑着的.is_valid(), "B：新补间必须 `kill()` 掉同一根条上的旧补间（两支同抢一个 value ⇒ 抖）")
	_查(is_equal_approx(条.value, 路上),
		"B：kill 之后当帧仍在原位 %.1f（不许跳），实得 %.1f" % [路上, 条.value])
	await _等(0.7)
	_查(is_equal_approx(条.value, 20.0), "B：最终该到 20，实得 %.1f" % 条.value)

	# ④ 曲线与时长：行为只证"在动、半秒内收敛"，曲线本身按字面钉死
	var 源 := FileAccess.get_file_as_string("res://脚本/单例/进度条补间.gd")
	_查(源.contains("const 时长 := 0.5"), "B：补间时长必须是 0.5 秒（`MBar.as:170` 第二个实参）")
	_查(源.contains("Tween.TRANS_QUAD"), "B：曲线必须是二次（`easeOut = -c·u·(u−2)+b`）")
	_查(源.contains("set_ease(Tween.EASE_OUT)"), "B：必须是**缓出**（`gs/TweenLite.as:28/199-202`）")
	_查(源.contains("Tween.TRANS_LINEAR"), "B：`MMaskSprite` 那族要有**线性**那道口子（`:158-169` 逐帧线性插值）")
	# 两条 meta 键必须**以字母开头**：`set_meta` 走 `String::is_valid_identifier`，
	# 中文或 `_` 开头 ⇒ `Invalid metadata identifier`、缓存**根本没存进去**（早退失效、每帧重启补间，
	# 而且 error 不打断执行 ⇒ 没有这条字面闸就是**假绿**）。
	_查(not 源.contains('const 补间键 := "_') and not 源.contains('const 数据键 := "_'),
		"B：两条 meta 键不许下划线开头（`set_meta` 认不得 ⇒ 同数据早退整条失效）")

	# ⑤ 线性那道口子：同样 0.5s、同样早退，只是曲线不同
	var 蓝 := _建条("条蓝")
	件.线性补间(蓝, "value", 40.0, [40, 100])
	_查(is_equal_approx(蓝.value, 0.0), "B：线性补间也不许当帧直给")
	var 支 := _补间对象(蓝)
	件.线性补间(蓝, "value", 40.0, [40, 100])
	_查(_补间对象(蓝) == 支, "B：线性那族也必须同数据早退")
	await _等(0.7)
	_查(is_equal_approx(蓝.value, 40.0), "B：线性 0.7 秒后到 40，实得 %.1f" % 蓝.value)

	# ⑥ 不在树上的条建不了 Tween（Godot 直接报错）⇒ 必须退成直写，不许炸
	var 野 := ProgressBar.new()
	野.name = "条野"
	野.min_value = 0.0
	野.max_value = 100.0
	件.补间(野, "value", 70.0, [70, 100])
	_查(is_equal_approx(野.value, 70.0), "B：不在树上的条要**直写终值**（不能 create_tween 报错）")
	野.free()

	# ⑦ `直写()`（"这一档本来就不动条"的那些场合）：**写完必须作废缓存 + 杀掉还在跑的补间**。
	#    只写 `条.value =` 不作废 ⇒ 缓存里还是上一次那发数据 ⇒ 下一次同样的数据被第 0 步早退吞掉
	#    ⇒ 条永远停在手动值（目标条 `?/?` 那一支就是这么个坑）。
	var 停 := _建条("条停")
	件.补间(停, "value", 50.0, [50, 100])
	await _等(0.7)
	件.直写(停, "value", 0.0)
	_查(is_equal_approx(停.value, 0.0), "B：`直写` 当帧就到 0（它自己不许再补间）")
	件.补间(停, "value", 50.0, [50, 100])
	await _等(0.7)
	_查(is_equal_approx(停.value, 50.0),
		"B：`直写` 之后同数据再灌**不许被早退吞掉**（不作废缓存 ⇒ 条永远停在手动值），实得 %.1f" % 停.value)
	件.补间(停, "value", 100.0, [100, 100])
	var 在跑 := _补间对象(停)
	_查(在跑 != null and 在跑.is_valid(), "B：这一发该有还在跑的补间（前置没成立下面那条等于没判）")
	件.直写(停, "value", 30.0)
	_查(not 在跑.is_valid(), "B：`直写` 也要 `kill()` 还在跑的补间 —— 不然写完它又爬回 100")
	await _等(0.7)
	_查(is_equal_approx(停.value, 30.0), "B：`直写` 之后条该停在 30，实得 %.1f" % 停.value)


# ── C. 站点 ────────────────────────────────────────────────────────
func _C站点() -> void:
	var 窗 := 假窗.new()

	# 生命条：字**立刻**按数据算，条 0.5 秒爬过去（读 `条.value` 就会跟着爬）
	var 面板 := Control.new()
	var 条 := ProgressBar.new()
	条.name = "生命条"
	条.min_value = 0.0
	条.max_value = 1000.0		# 先抬上限再灌值：Range 会**当场把 value 夹到新上限**
	条.value = 900.0			# 上一次渲染停在这儿：字要是读条，就会显成 900/1000
	var 字 := Label.new()
	字.name = "生命数值"
	面板.add_child(条)
	面板.add_child(字)
	root.add_child(面板)
	人物脚本.设置状态条(窗, 面板, "生命", 300, 1000)
	_查(字.text == "300/1000",
		"C：`设置状态条` 的字必须按**数据**算（实得「%s」—— 读 `条.value` 就跟着补间爬）" % 字.text)
	_查(is_equal_approx(条.value, 900.0),
		"C：灌完当帧生命条该还停在上一位的路上（900→300 要补间），实得 %.1f" % 条.value)
	await _等(0.7)
	_查(is_equal_approx(条.value, 300.0), "C：0.7 秒后生命条到 300，实得 %.1f" % 条.value)

	# 看别人那三根：`上限 0` 按原版是**满条**（注释早写了，代码以前画空）
	var 块 := Control.new()
	var 槽 := ProgressBar.new()
	槽.name = "测试槽"
	槽.min_value = 0.0
	var 值 := Label.new()
	值.name = "测试值"
	块.add_child(槽)
	块.add_child(值)
	root.add_child(块)
	人物脚本.看别人条(窗, 块, "测试", 0, 0)
	await _等(0.7)
	_查(is_equal_approx(槽.value, 槽.max_value) and 槽.max_value > 0.0,
		"C：`看别人条` 的 0/0 该画**满条**（`MBar.as:140-149` + 实机图），实得 %s/%s"
		% [槽.value, 槽.max_value])
	_查(值.text == "0/0", "C：满条不改文案，实得「%s」" % 值.text)
	人物脚本.看别人条(窗, 块, "测试", 2700, 5400)
	_查(槽.value < 100.0,
		"C：换数据那一帧条还停在满条那一位（1.0），往 2700 走是补间的事，实得 %.1f" % 槽.value)
	await _等(0.7)
	_查(is_equal_approx(槽.value, 2700.0), "C：2700/5400 ⇒ 0.7 秒后落在 2700，实得 %.1f" % 槽.value)

	# 宠物那根是**滑条几何**：同一个件、另一种属性路径，早退口径必须一模一样
	var 页面 := Control.new()
	var 条根 := Control.new()
	条根.name = "梦幻条"
	条根.size = Vector2(114, 11)
	var 裁剪 := Control.new()
	裁剪.name = "裁剪"
	var 填充 := TextureRect.new()
	填充.name = "填充"
	裁剪.add_child(填充)
	条根.add_child(裁剪)
	var 宠物字 := Label.new()
	宠物字.name = "值"
	条根.add_child(宠物字)
	页面.add_child(条根)
	root.add_child(页面)
	填充.position.x = -3.0
	宠物脚本._设条(页面, "梦幻条", 42, 100)
	_查(is_equal_approx(填充.position.x, -3.0),
		"C：滑条灌完当帧不许瞬移（实得 %.1f —— 直接写位置就没补间）" % 填充.position.x)
	await _等(0.7)
	_查(is_equal_approx(填充.position.x, -69.0),
		"C：42/100 该滑到 −69，实得 %.1f" % 填充.position.x)
	var 那支 := _补间对象(填充)
	宠物脚本._设条(页面, "梦幻条", 42, 100)
	_查(_补间对象(填充) == 那支 and 那支 != null,
		"C：滑条同数据再灌也必须早退（宠物那两处以前只 create_tween、不判重）")
	宠物脚本._设条(页面, "梦幻条", 100, 100)
	_查(not 那支.is_valid(), "C：滑条换数据必须 kill 旧补间（两支同抢一个 x ⇒ 抖）")
	await _等(0.7)
	_查(is_equal_approx(填充.position.x, -3.0), "C：满条滑回静止位 −3，实得 %.1f" % 填充.position.x)
	# ⚠ **已登记的有意偏离**：宠物/驯养那两根 `上限 0` 画**空条**，不跟原版 `MBar` 的满条口径
	#    （原版"没宠物"时六根条全画满，屏面像坏了 ⇒ 用户会当新 bug 报修）。
	#    这条腿钉的就是那个 `false` 实参 —— 少了它 0/0 会滑回 −3（满条）。
	宠物脚本._设条(页面, "梦幻条", 0, 0)
	await _等(0.7)
	_查(is_equal_approx(填充.position.x, -117.0),
		"C：宠物 `上限 0` 该画**空条**（偏离已登记，整条滑出遮罩 −117），实得 %.1f" % 填充.position.x)
	for 宠源 in ["res://脚本/界面/窗口/宠物窗口.gd", "res://脚本/界面/窗口/通灵驯养窗口.gd"]:
		_查(FileAccess.get_file_as_string(宠源).contains("比例(float(数值), float(最大值), false)"),
			"C：「%s」那根滑条必须显式传 上限零当满=false（偏离别被顺手改回原版）" % 宠源.get_file())

	# C-2 **站点接线字面**：九处各引用件的那道口子上去。行为腿只证"抽到的那根会爬"；
	#     这里证**每一根**都接上了 —— 漏一根就是"只有那几根动"，用户报的正是「一跳一跳」。
	var 站点: Array = [
		["res://脚本/界面/窗口/人物窗口.gd", "灌值(经验条"],
		["res://脚本/界面/窗口/人物窗口.gd", "灌值(精华条"],
		["res://脚本/界面/窗口/人物窗口.gd", "灌值(条, float(已开穴位数)"],
		["res://脚本/界面/窗口/人物窗口.gd", "灌值(条, float(定稿)"],
		["res://脚本/界面/窗口/人物窗口.gd", "灌值(祝福条"],
		["res://脚本/界面/窗口/人物窗口.gd", "灌值(状态条"],
		["res://脚本/界面/窗口/人物窗口.gd", "灌值(槽"],
		["res://脚本/界面/窗口/忍术窗口.gd", '补间(进度, "value"'],
		["res://脚本/界面/窗口/宠物窗口.gd", '补间(填充, "position:x"'],
		["res://脚本/界面/窗口/通灵驯养窗口.gd", '补间(填充, "position:x"'],
		["res://素材/界面/原版窗口/人物/手里剑/脚本/手里剑页.gd", "灌值(_等级条"],
		["res://素材/界面/原版窗口/人物/手里剑/脚本/手里剑突破瓶颈弹窗.gd", "灌值(条,"],
		["res://素材/界面/原版窗口/人物/结印/脚本/提升结印阶数弹窗滑动动画.gd", "灌值(条,"],
	]
	for 站: Array in 站点:
		var 源 := FileAccess.get_file_as_string(String(站[0]))
		_查(源.contains(String(站[1])),
			"C：站点「%s」该有 %s —— 缺这一处那根条还是直给" % [站[0].get_file(), String(站[1])])
	# C-3 文案不许再读条自己（§⑤b）：那两处以前是 `100.0 × 经验条.value / 经验条.max_value`
	#     和 `%d/%d % [int(祝福条.value), …]` ⇒ 接了补间就是数字跟着条爬。
	var 人源 := FileAccess.get_file_as_string("res://脚本/界面/窗口/人物窗口.gd")
	_查(not 人源.contains("经验条.value / 经验条.max_value"),
		"C：经验百分比必须按**数据**算（读 `经验条.value` ⇒ 数字跟着补间爬）")
	_查(not 人源.contains("int(祝福条.value)"),
		"C：祝福那行 %d/%d 必须按**数据**算（读 `祝福条.value` 同理）")


# ── E. 整页重建续接 ────────────────────────────────────────────────
## 真值：`MBar.as:130-133`（同数据早退）+ `:170`（`TweenLite.to` 从**当前 x** 起算）——
## MBar 是常驻件，永远只从"它现在停在哪"往新值走；本工程每帧拆页重造，
## 新条带着 `.tscn` 烘的默认值（生命条 100、经验条 0）出生 ⇒ 必须有东西把那一位接回来。
func _E重建续接() -> void:
	# ① 拆页前的快照：按「内容根下的相对路径 → 当前视觉值」记，只收进度条
	var 宿主 = (load("res://脚本/界面/功能窗口.gd") as GDScript).new()
	var 内容 := Control.new()
	内容.name = "内容E"
	var 旧页 := Control.new()
	旧页.name = "人物页"
	var 旧生命 := ProgressBar.new()
	旧生命.name = "生命条"
	旧生命.max_value = 1000.0
	旧生命.value = 60.0
	旧页.add_child(旧生命)
	var 旧滚动 := HScrollBar.new()
	旧滚动.name = "滚动"
	旧滚动.value = 37.0
	旧页.add_child(旧滚动)
	内容.add_child(旧页)
	root.add_child(内容)
	var 表: Variant = 宿主.call("_快照条值", 内容)
	宿主.free()
	var 快照: Dictionary = 表 if typeof(表) == TYPE_DICTIONARY else {}
	_查(is_equal_approx(float(快照.get("/人物页/生命条", -1.0)), 60.0),
		"E：拆页前要按相对路径记下这根条停在 60（键 `/人物页/生命条`），实得 %s" % str(快照))
	_查(not 快照.has("/人物页/滚动"),
		"E：`ScrollBar` 也是 `Range` 但不许进快照（滚动位置有自己那套记录/还原），实得 %s" % str(快照))

	# ② 重建出来的新条（`.tscn` 默认值 100）建补间前必须接回 60，然后才是 60→65
	内容.set_meta(件.重建快照键, 快照)
	for 子 in 内容.get_children():
		内容.remove_child(子)
		子.queue_free()
	var 新页 := Control.new()
	新页.name = "人物页"
	var 新生命 := ProgressBar.new()
	新生命.name = "生命条"
	新生命.max_value = 1000.0
	新生命.value = 100.0		# `.tscn` 烘死的那一档
	新页.add_child(新生命)
	内容.add_child(新页)
	件.补间(新生命, "value", 65.0, [65, 1000])
	_查(is_equal_approx(新生命.value, 60.0),
		"E：重建出来的新条必须先接回 60（不许拿烘死的 100 当起点），实得 %.1f" % 新生命.value)
	await _等(0.7)
	_查(is_equal_approx(新生命.value, 65.0),
		"E：接回来之后才是 60→65 的渐进那一条，实得 %.1f" % 新生命.value)

	# ③' 续接只认进度条：`ScrollBar` 同为 `Range`，但滚动位置有自己那套记录/还原，
	#    被这条口子抢去接 ⇒ 重建后滚动条跳回旧位。
	var 新滚 := HScrollBar.new()
	新滚.name = "滚动"
	新滚.value = 0.0
	新页.add_child(新滚)
	内容.set_meta(件.重建快照键, {"/人物页/滚动": 55.0})
	件.补间(新滚, "value", 30.0, [30, 100])
	_查(is_equal_approx(新滚.value, 0.0),
		"E：`ScrollBar` 不许被续接（它也是 `Range`，接了就和滚动还原打架），实得 %.1f" % 新滚.value)

	# ③ 快照里**没有**的路径 = 这一页新长出来的条（换页/换页签/首次渲染）⇒ **直落真值**，
	#    不许拿 `.tscn` 烘死的默认值当起点扫一遍（用户 2026-10-31：「切换后，数值轴是多少数值
	#    就是多少数值，不要变化一次」）。烘死值故意取 100（不是 0）—— "错接到默认值"和
	#    "根本没接"在 0 上没法区分。
	var 别页 := Control.new()
	别页.name = "别页"
	var 经验 := ProgressBar.new()
	经验.name = "经验条"
	经验.max_value = 1000.0
	经验.value = 100.0
	别页.add_child(经验)
	内容.add_child(别页)
	件.补间(经验, "value", 30.0, [30, 1000])
	_查(is_equal_approx(经验.value, 30.0),
		"E：快照里没有的路径要**当帧直落 30**（换页/换页签不许扫），实得 %.1f" % 经验.value)
	await _等(0.7)
	_查(is_equal_approx(经验.value, 30.0), "E：直落后的条停在 30，实得 %.1f" % 经验.value)

	# ③b 这一趟标了 `直落键`（换页/换页签）⇒ **即使快照里有它**也直落，不接旧位。
	#     只靠快照接不住换页：换走那一页时新页的条压根不在快照里，而"上一次视觉值"
	#     属于另一页 —— 拿它当起点就是从 0 扫到当前值。
	var 直落页 := Control.new()
	直落页.name = "直落页"
	var 直落条 := ProgressBar.new()
	直落条.name = "直落条"
	直落条.max_value = 1000.0
	直落条.value = 100.0
	直落页.add_child(直落条)
	内容.add_child(直落页)
	内容.set_meta(件.重建快照键, {"/直落页/直落条": 60.0})
	内容.set_meta(件.直落键, true)
	件.补间(直落条, "value", 300.0, [300, 1000])
	_查(is_equal_approx(直落条.value, 300.0),
		"E：换页那一趟要**直落 300**（不许接快照里的 60、也不许从默认值 100 爬），实得 %.1f"
			% 直落条.value)
	内容.remove_meta(件.直落键)
	await _等(0.7)
	_查(is_equal_approx(直落条.value, 300.0), "E：换页直落后条停在 300，实得 %.1f" % 直落条.value)
	内容.remove_meta(件.重建快照键)
	内容.free()

	# ④ 接线字面：少任何一句，这条行为就整段失效（且崩/失效都不一定会红）
	var 宿源 := FileAccess.get_file_as_string("res://脚本/界面/功能窗口.gd")
	_查(宿源.contains("_content.set_meta(进度条补间.重建快照键, _快照条值(_content))"),
		"E：`_render_page` 拆页前必须先把快照挂到 `_content` 上（漏了 ⇒ 每条都从 `.tscn` 默认值重爬）")
	_查(宿源.count("_content.remove_meta(进度条补间.重建快照键)") == 2,
		"E：`_render_page` 两条出口都要摘掉快照（漏一条 ⇒ 过期值顶掉下一次渲染），实得 %d 处"
			% 宿源.count("_content.remove_meta(进度条补间.重建快照键)"))
	var 人源 := FileAccess.get_file_as_string("res://脚本/界面/窗口/人物窗口.gd")
	_查(人源.contains("进度条补间.灌值(条, float(clampi(达成, 0, 上限)), float(maxi(1, 上限)), [达成, 上限])"),
		"E：结印那四根（`JieYinPanel.updateProp:302` 的 `MBar.setData`）必须走补间，不许直写 value")
	var 件源 := FileAccess.get_file_as_string("res://脚本/单例/进度条补间.gd")
	_查(件源.contains("if 属性 == \"value\" and not 目标.has_meta(补间键):")
			and 件源.contains("_接重建前的值(目标)"),
		"E：续接只给**新条 + value 路径**（`position:x` 那根滑条有自己那套，不许接）")
	_查(件源.contains("if not (目标 is ProgressBar or 目标 is TextureProgressBar):"),
		"E：续接只认进度条（`ScrollBar/SpinBox` 也是 `Range`，接了就抢滚动位置）")

	# ⑤ 换页直落的接线字面：这一档的整个行为挂在三句话上，少一句就退回"从 0 扫"。
	_查(件源.contains("const 直落键 := "),
		"E：`进度条补间` 必须有 `直落键`（换页这一趟的标记）")
	_查(件源.contains("if 重建态 == 2 or 重建态 == 3:"),
		"E：`_起` 要把「换页」和「新长出来的条」两种状态都直落（只判一种 ⇒ 另一半仍从 0 扫）")
	_查(件源.contains("return 2") and 件源.contains("return 3"),
		"E：`_接重建前的值` 要回三态（1 接回 / 2 换页 / 3 无快照），调用方才分得清")
	_查(宿源.contains("_content.set_meta(进度条补间.直落键, true)"),
		"E：`_render_page(直落)` 要真的把 `直落键` 挂上去（只改签名不改挂 meta = 空转）")
	_查(宿源.count("_content.remove_meta(进度条补间.直落键)") == 2,
		"E：`_render_page` 两条出口都要摘掉 `直落键`（漏一条 ⇒ 下一次同页回帧也被直落、不再有数值变化动画），实得 %d 处"
			% 宿源.count("_content.remove_meta(进度条补间.直落键)"))
	_查(宿源.contains("func _render_page(直落: bool = false) -> void:"),
		"E：`_render_page` 要带 `直落` 开关（回帧那一趟必须仍走快照续接）")
	for 页签 in ["_set_character_main_tab", "_set_character_sub_tab", "_set_shop_tab", "_set_skill_tab",
			"_set_team_tab", "_set_friend_tab", "_set_quest_tab", "_set_settings_tab",
			"_set_prize_tab", "_set_activity_overview_tab", "_set_info_tab", "_set_npc_shop_tab"]:
		_查(_函数体(宿源, 页签).contains("_render_page(true)"),
			"E：换页签「%s」必须走 `_render_page(true)`（漏一处 ⇒ 那个页签的条又从 0 扫）" % 页签)


## 截一段顶层函数体（到下一个顶层 `func ` 为止），用来钉某句接线在不在**那个函数里**。
func _函数体(源: String, 名: String) -> String:
	var 起 := 源.find("func " + 名)
	if 起 < 0:
		return ""
	var 终 := 源.find("\nfunc ", 起 + 5)
	if 终 < 0:
		终 = 源.length()
	return 源.substr(起, 终 - 起)


# ── D. 不该动的 ────────────────────────────────────────────────────
func _D不该动的() -> void:
	# §⑦：地图头顶血条 `CommonHpBar.as:18-43` 每帧 `graphics.clear()` 重画，**没有补间**。
	# 挂机每秒多包 ⇒ 接了补间就永远追不上真值，那是原版没有的行为。
	var 实体源 := FileAccess.get_file_as_string("res://脚本/地图/地图实体.gd")
	_查(not 实体源.contains("进度条补间"),
		"D：地图头顶血条**不许**接补间（`CommonHpBar` 直值重画）—— 一旦引用本件就是给原版加行为")
	# 两条曲线不许混：底栏自己血/蓝是 `MMaskSprite`（0.5s **线性**），不是 MBar
	var 头像源 := FileAccess.get_file_as_string("res://脚本/界面/头像面板.gd")
	_查(头像源.contains("线性补间(_hp_bar") and 头像源.contains("线性补间(_mp_bar"),
		"D：底栏自己血/蓝必须走**线性**那道口子（`MMaskSprite.as:158-169`），不是 MBar 的二次缓出")
	_查(头像源.contains("进度条补间.补间(条"),
		"D：目标那两根（DetailsWindow = MBar 族）必须走件，别再自己 create_tween")


func 收尾() -> void:
	if _失败.is_empty():
		print("进度条补间回归测试：通过（%d 条断言：口径/早退/杀旧补间/曲线/字按数据算/滑条同口径/头顶血条不动/重建续接/换页直落）" % _受检)
		quit(0)
		return
	for 项 in _失败:
		printerr("进度条补间回归测试：" + 项)
	print("进度条补间回归测试：失败 %d / %d 条" % [_失败.size(), _受检])
	quit(1)
