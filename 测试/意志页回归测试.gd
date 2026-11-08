extends SceneTree
## 意志三窗的**离线**几何门（登记进 `开发工具/验证全部.ps1`）。
##
## 为什么再来一条：`开发工具/截意志{学习,背包,介绍}页.gd` 那三条是**有头**量具
## （要 `root.get_texture()` 裁图、要 hover/click），进不了离线门；
## 于是"场景被编辑器的旧缓冲盖掉 / 尺寸表被人改回 410 / 模块接线被删"这类回退
## 只有跑有头门才发现 —— 而 2026-10-03 这一轮恰恰就是这种回退（`真值/窗口/意志.md` §4）。
##
## 期望值**不另立一份**：直接读三条有头量具里的 `件路径 / 件期望` 两张 const 表
## （`GDScript.get_script_constant_map()`）⇒ 真值只有一处，量具表一改这里就跟着改。
## 比的是**场景烘的矩形**（页面局部 = AS3 窗口局部 − 29），逐个件、容差 ±1。
##
## 还钉四件数据侧的不变量：窗尺寸表三条、召唤位、图鉴非灰行数、格数。
##
## 跑法：Godot --path . --headless --script res://测试/意志页回归测试.gd

const 容差 := 1.0
const 尺寸表路径 := "res://数据/界面/窗口尺寸.json"
const 图鉴路径 := "res://数据/意志图鉴.json"
const 常量路径 := "res://数据/意志.json"

## 页名 → (场景, 量具脚本, AS3 里 `super(宽,高)` 的那两个数 + 出处)
const 页面表 := {
	"遗址": ["res://场景/界面/窗口/遗址/意志背包窗口.tscn",
		"res://开发工具/截意志背包页.gd", 663.0, 548.0, "YiZhiPackWindow.as:75"],
	"意志学习": ["res://场景/界面/窗口/遗址/意志学习窗口.tscn",
		"res://开发工具/截意志学习页.gd", 772.0, 564.0, "YiZhiStudyWindow.as:44"],
	"意志介绍": ["res://场景/界面/窗口/遗址/意志介绍窗口.tscn",
		"res://开发工具/截意志介绍页.gd", 455.0, 430.0, "YiZhiIntroduceWindow.as:20"],
}
## 10-25 起这里**不再有「顶边抬」补偿**：`CheckBox/hover_pressed` 在主题里补了空盒
##   ⇒ 控件矩形最小高回到皮肤原生 19，控件矩形 == 皮肤矩形 ⇒ 件期望 直接就是场景烘的矩形。
##   （当年「锁定勾选」要烘 360、把控件顶边抬 4 才让皮肤落在真值 364，那是 27 地板的产物；
##   现在场景烘 364。见 `真值/窗口/意志.md` §2.1、`测试/勾选框几何回归测试.gd`。）
const 顶边抬 := {}

var _错 := 0
var _件数 := 0


func _initialize() -> void:
	var 尺寸表: Dictionary = _读(尺寸表路径)
	for 页名 in 页面表:
		_量一页(页名, 尺寸表)
	_量数据不变量()
	_量意志力算式()
	_量模块在位()
	_量阅历链与导师态()
	_量意志力口径()
	_量三钮动作名()
	_量穿戴八格边界()
	_量学习面板两层()
	if _错 > 0:
		print("!! 意志页离线门失败 %d 项" % _错)
		quit(1)
	else:
		print("意志页离线门：三窗 %d 件逐矩形 + 尺寸表 3 条 + 数据不变量 + 模块接线 + 阅历链/导师态/意志力口径/三钮动作名/穿戴八格边界哨兵 全部对上" % _件数)
		quit(0)


func _读(路径: String) -> Dictionary:
	var 文件 := FileAccess.open(路径, FileAccess.READ)
	if 文件 == null:
		_报("读不到 %s" % 路径)
		return {}
	var 出 = JSON.parse_string(文件.get_as_text())
	文件.close()
	return 出 if 出 is Dictionary else {}


func _常量(脚本路径: String) -> Dictionary:
	var 脚本 := load(脚本路径) as GDScript
	if 脚本 == null:
		_报("载不出量具脚本 %s" % 脚本路径)
		return {}
	return 脚本.get_script_constant_map()


func _量一页(页名: String, 尺寸表: Dictionary) -> void:
	var 定: Array = 页面表[页名]
	var 场景路 := String(定[0])
	var 量具路 := String(定[1])
	# 一、尺寸表三条：宽/高 = AS3 `super()` 那两个数，且必须是 `整框`（页面根 = 窗 − 29）
	var 规格: Dictionary = 尺寸表.get(页名, {}) as Dictionary
	if 规格.is_empty():
		_报("窗口尺寸.json 缺「%s」条目" % 页名)
	else:
		var 宽 := float(规格.get("宽", -1.0))
		var 高 := float(规格.get("高", -1.0))
		_判(abs(宽 - float(定[2])) < 0.01 and abs(高 - float(定[3])) < 0.01,
				# ⚠ GDScript 的 `%%` 格式化**没有 `%g`**（那是 C/Python 的），写了直接
				#   `String formatting error: unsupported format character` 把整步打断。
				"「%s」尺寸表 %d×%d = AS3 %s 的 super(%d,%d)"
						% [页名, int(宽), int(高), 定[4], int(定[2]), int(定[3])],
				"应为 %d×%d（%s）" % [int(定[2]), int(定[3]), 定[4]])
		_判(bool(规格.get("整框", false)),
				"「%s」标了 `整框`（⇒ 容器原点 (0,29)、场景 y = 窗 y − 29）" % 页名,
				"没标整框 ⇒ 整页会右下各偏 8/38px")
	# 二、场景根高 = 窗高 − 29
	if not ResourceLoader.exists(场景路):
		_报("场景缺失 %s" % 场景路)
		return
	var 表 := _常量(量具路)
	var 件路径: Dictionary = 表.get("件路径", {}) as Dictionary
	var 件期望: Dictionary = 表.get("件期望", {}) as Dictionary
	if 件路径.is_empty() or 件期望.is_empty():
		_报("%s 里没有 件路径/件期望 两张 const 表" % 量具路)
		return
	var 根 := (load(场景路) as PackedScene).instantiate() as Control
	root.add_child(根)
	var 想根高: float = float(定[3]) - 29.0
	_判(absf(float(根.size.y) - 想根高) <= 容差 or absf(根.get_combined_minimum_size().y - 想根高) <= 容差,
			"「%s」页面根高 = 窗高 %d − 拖动区 29 = %d" % [页名, int(定[3]), int(想根高)],
			"实际 size=%s min=%s" % [根.size, 根.get_combined_minimum_size()])
	# 三、逐件矩形（件期望 存的就是页面局部绝对矩形 ⇒ 拿全局原点回算）
	var 原点 := 根.get_global_position()
	var 坏名 := ""
	for 件名 in 件路径:
		var 路 := String(件路径[件名])
		var 想v = 件期望.get(件名, null)
		if not (想v is Array):
			continue	# 件名只登记在 件路径 的（父容器占位等）由有头门管
		var 想: Array = 想v as Array
		var 件 := 根.get_node_or_null(路) as Control
		if 件 == null:
			坏名 += " %s" % 件名
			continue
		var 抬: float = float(顶边抬.get(件名, 0.0))
		var 得 := 件.get_global_rect()
		var 偏差 := Vector2(得.position.x - 原点.x - float(想[0]),
				得.position.y - 原点.y - (float(想[1]) - 抬))
		var 想高 := float(想[3])
		var 尺差 := Vector2(得.size.x - float(想[2]), 得.size.y - 想高)
		_件数 += 1
		if 偏差.length() > 容差 or 尺差.length() > 容差:
			坏名 += " %s(实%s期%s)" % [件名,
					"%.0f,%.0f %.0fx%.0f" % [得.position.x - 原点.x, 得.position.y - 原点.y,
							得.size.x, 得.size.y],
					"%.0f,%.0f %.0fx%.0f" % [float(想[0]), float(想[1]) - 抬, float(想[2]), float(想[3])]]
	_判(坏名 == "", "「%s」逐件矩形 %d 条全在容差 ±%s 内" % [页名, 件路径.size(), 容差],
			"偏出：%s" % 坏名)
	根.queue_free()


## 四、数据侧不变量（三条量具都靠它们，改数据不改表就会在这里红）
func _量数据不变量() -> void:
	var 图鉴 := _读(图鉴路径)
	var 记录 := 0
	var 非灰 := 0
	for 键名 in 图鉴:
		var 记 = 图鉴[键名]
		if 记 is Dictionary:
			记录 += 1
			if str((记 as Dictionary).get("color", "")) != "gray":
				非灰 += 1
	_判(记录 == 47, "图鉴 %d 条 = `Spirit.items` 47 个意志" % 记录, "记录数不对")
	_判(非灰 == 38, "图鉴非灰 %d 条 ⇒ 介绍页 38 行（drawList 剔 gray）" % 非灰,
			"介绍页行数会变 ⇒ 尺寸表里 滑块 那条期望（344×372÷(行×26)）要跟着重算")
	var 常 := _读(常量路径)
	var 得: Dictionary = ((常.get("common", {}) as Dictionary).get("gain", {}) as Dictionary)
	var 位 := -1
	for i in 5:
		var 特: Dictionary = ((得.get("NPC%d" % i, {}) as Dictionary).get("special", {}) as Dictionary)
		if int(特.get("needYuanBao", 0)) > 0:
			位 = i
	# `TeacherPanel:65-70` 把召唤位**写死成下标 3** ⇒ 数据与源码必须仍然一致
	_判(位 == 3, "数据里 `needYuanBao>0` 的是 NPC%d ⇒ 与原版写死的 3 吻合（自来也）" % 位,
			"数据是 NPC%d 而源码写死 3 ⇒ 得回查，不能两边各信各的" % 位)
	var 携: Dictionary = (常.get("common", {}) as Dictionary).get("carry", {}) as Dictionary
	_判(携.size() == 8, "carry %d 档 = EQUIP_MAX_COUNT 8 个穿戴位" % 携.size(), "穿戴上限档数不对")


## 六、意志力算式（`YiZhiManager.caculateYiZhiLi:168-181` + `YiZhiData.rongHeExp:92-101`）
##   单件 = **黄帧恒 1200**，否则 `common.levelUp.level1[items[id].spec.color] + exp`（`level1` 是字面量，
##   AS3 那行加的是字符串 "1"，不是 `this.level + 1`）；Σ 完**只除一次** 30、只截断一次。
##   补之前本工程把帧里的 `exp` 直接当成了 rongHeExp ⇒ 0 经验的穿戴算出意志力 **0**。
##   期望值全用**字面量**（数一遍：绿30 蓝60 紫120 粉240 红480 浅粉480 黄恒1200）⇒ 改数据会红。
##   色号按 `SPIRIT_COLOR_IDS`（gray1 green2 blue3 pueple4 pink5 **yellow6** red7 lpink8）。
func _量意志力算式() -> void:
	var 常 := _读(常量路径)
	var 档: Dictionary = ((常.get("common", {}) as Dictionary) \
			.get("levelUp", {}) as Dictionary).get("level1", {}) as Dictionary
	_判(int(档.get("green", -1)) == 30 and int(档.get("blue", -1)) == 60
			and int(档.get("pueple", -1)) == 120 and int(档.get("pink", -1)) == 240
			and int(档.get("red", -1)) == 480 and int(档.get("lpink", -1)) == 480,
			"意志.json `level1` 六色 = 30/60/120/240/480/480（下面的字面期望靠它）",
			"档子被改过 ⇒ 这一节每条腿的期望要一起重算")

	var 会话类 = load("res://脚本/单例/游戏会话.gd")
	var 会 = 会话类.new()
	# ① 三件 0 经验：绿(201)+蓝(301)+紫(401) = 30+60+120 = 210 ⇒ 210/30 = **7**（旧码 0）
	会.spirit_equipped = [_件(201, 2, 0), _件(301, 3, 0), _件(401, 4, 0)]
	_判(int(会.意志力()) == 7, "穿戴绿+蓝+紫（都 0 经验）⇒ Σ210 ⇒ 意志力 7",
			"实际 %d（旧码给 0）" % int(会.意志力()))
	# ② 黄帧恒 1200，**不吃 exp**：210 + 1200 = 1410 ⇒ **47**（旧码 (999)/30 = 33）
	会.spirit_equipped = [_件(201, 2, 0), _件(301, 3, 0), _件(401, 4, 0), _件(601, 6, 999)]
	_判(int(会.意志力()) == 47, "再加一件黄(601,exp999) ⇒ 黄不看 exp 恒 1200 ⇒ Σ1410 ⇒ 47",
			"实际 %d（旧码给 33）" % int(会.意志力()))
	# ③ 帧上的 `exp` **不是** rongHeExp：单件蓝 exp60 ⇒ 60+60 = 120 ⇒ **4**（旧码 2）
	会.spirit_equipped = [_件(301, 3, 60)]
	_判(int(会.意志力()) == 4, "单件蓝 exp60 ⇒ 60(档)+60(exp) = 120 ⇒ 4（exp 只是加数）",
			"实际 %d（旧码给 2 ⇒ 把 exp 当成了 rongHeExp）" % int(会.意志力()))
	# ④ 与**等级无关**：同一件 201 在 1 级和 20 级各算一次，贡献都必须是 30
	var 单1: int = int(会.融合经验(_件(201, 2, 0, 1)))
	var 单20: int = int(会.融合经验(_件(201, 2, 0, 20)))
	_判(单1 == 30 and 单20 == 30, "融合经验取 `level1` 字面档 ⇒ 201 在 1 级与 20 级都是 30（原版同）",
			"实际 %d / %d ⇒ `level1` 被当成了 `level+1`" % [单1, 单20])
	# ⑤ 只截断一次：两件各 80（蓝档 60 + exp 20）⇒ Σ160 ⇒ **5**；逐件先除会得 2+2 = **4**
	会.spirit_equipped = [_件(301, 3, 20), _件(302, 3, 20)]
	_判(int(会.意志力()) == 5, "80+80=160 ⇒ 除 30 截断一次 = 5（逐件先除会得到 4）",
			"实际 %d" % int(会.意志力()))
	# ⑥ 判黄用的是**帧色**、查档用的是**图鉴品质名**（原版 `color` vs `colorType`）：
	#    蓝件 301 挂上帧色 6 ⇒ 走黄支 1200，不是 60+0
	_判(int(会.融合经验(_件(301, 6, 0))) == 1200, "帧色 6 ⇒ 恒 1200（即使图鉴写 blue）",
			"实际 %d ⇒ 黄支改用了图鉴品质名" % int(会.融合经验(_件(301, 6, 0))))
	# ⑦ 只算**穿戴**数组，背包那些不计（原版传的是 `yiZhiEquipDatas`）
	会.spirit_bag = [_件(201, 2, 0), _件(301, 3, 0), _件(401, 4, 0)]
	会.spirit_equipped = []
	_判(int(会.意志力()) == 0, "同样三件放在**背包** ⇒ 意志力 0（Σ 只走穿戴数组）",
			"实际 %d" % int(会.意志力()))
	# ⑧ 灰帧：原版 `level1["gray"]` 无此键 ⇒ `undefined + exp` = NaN，函数返回 `:int` ⇒ **0**。
	#    ⚠️ 合并 `意志模块` 时分支版按"只加 exp"落（45），与主线 `游戏数据.意志融经验` 分叉；
	#    按原版行为收回 **0**（`人物窗意志格回归测试` ① 也断言灰 = 0）。
	_判(int(会.融合经验(_件(101, 1, 45))) == 0,
			"灰件 ⇒ 0（level1 无 gray；原版 NaN 收敛成 0）",
			"实际 %d" % int(会.融合经验(_件(101, 1, 45))))

	# ⑨ 那串**悬停正文**跟同一套账走（`YiZhiManager.getYiZhiPropToopTioInfo:392-405`）。
	#    它是两处宿主共用的一份：意志背包窗「意志值框」`updateYiZhiTipNow:505-514`、
	#    人物窗「意志格」`CharPane.setYiZhiData:290-299`。修前人物页那十处一个都没接、
	#    背包窗那处读的是**没人写的 meta** ⇒ 永远「当前意志：0」（§3.234）。
	#    ⇒ 数字必须与上面的 `意志力()` 同源，每件一行「名 Lv.级 + desc」，行色取图鉴 `textColor`。
	var 提示 = load("res://脚本/界面/组件/意志提示框.gd")
	会.spirit_equipped = [_件(201, 2, 0, 3), _件(601, 6, 777, 1)]
	var 值 := int(会.意志力())
	var 串: String = 提示.意志力提示文案(会.spirit_equipped, 值)
	_判(串.contains("当前意志：%d" % 值) and 值 == 41,
			"正文首行「当前意志：41」= `意志力()` 同一个数（30+1200）/30",
			"实际 %s ⇒ 串里的数与算式分家了（修前正是这句永远是 0）" % 串.substr(0, 24))
	for 片 in ["<font color='#00FF00'>凝神 Lv.3</font>", "查克拉上限+200",
			"<font color='#FFF000'>羁绊 Lv.1</font>", "经验+1200"]:
		_判(串.contains(片), "正文含「%s」（绿 Lv.3 取 1..3 档最大 200、黄 601 恒 1200）" % 片,
				"实读 %s" % 串)
	_判(串.count("<br>") == 2 and 串.count("#ff9100") == 2,
			"两件 ⇒ 两个 `<br>`、两枚 #ff9100 的 desc（原版每件一行、desc 恒橙）",
			"实读 br=%d 橙=%d" % [串.count("<br>"), 串.count("#ff9100")])
	_判(String(提示.意志力提示文案([], 0)) == String(提示.语言表("YIZHI_YIZHILI_LABEL")) + "0",
			"没穿戴 ⇒ 只剩「当前意志：0」一行（不是空串、也不是残留的行）",
			"实读 %s" % 提示.意志力提示文案([], 0))
	会.free()


static func _件(编号: int, 色号: int, 经验: int, 级: int = 1) -> Dictionary:
	return {"id": 编号, "color": str(色号), "slot": -1, "exp": 经验, "level": 级}


## 五、模块在位：三窗的渲染入口与宿主的三个分支必须都还在
##   （本轮之前"缺"的就是这一项 —— 场景与组件都在，但 `功能窗口.gd` 还在用旧手摆版场景，
##     运行期开出来的是旧窗，而有头门只在**开对窗**时才绿）。
func _量模块在位() -> void:
	var 脚本 := load("res://脚本/界面/窗口/意志窗口.gd") as GDScript
	if 脚本 == null:
		_报("载不出 脚本/界面/窗口/意志窗口.gd")
		return
	var 有 := {}
	for 方 in 脚本.get_script_method_list():
		有[String(方.get("name", ""))] = true
	for 名 in ["渲染背包", "渲染学习", "渲染介绍"]:
		_判(bool(有.get(名, false)), "意志窗口.gd 有 %s()" % 名, "缺 ⇒ 宿主那页开不出真窗")
	# —— 拖放（§3.102 欠账②）——
	# 这四件是"接线还在不在"的哨兵：删了任何一件，拖放就静默失效（点了没反应、门照绿）。
	for 名 in ["_接拖放", "_处理意志拖放", "_升级槽那件", "_填升级格"]:
		_判(bool(有.get(名, false)), "意志窗口.gd 有 %s()（拖放接线）" % 名,
				"缺 ⇒ 意志格拖不动/升级槽永远空")
	var 意志文本 := FileAccess.get_file_as_string("res://脚本/界面/窗口/意志窗口.gd")
	for 条 in [
			# ⚠️ 2026-10-24 §3.190：升级格**能拖出**（原版也是 YiZhiCell，downHandler 有货即起拖）。
			#    旧哨兵钉「只接不吐（false）」= 用户报「升级后取不出」的根，改成钉 true。
			['_接拖放(槽, "意志升级", 0, true)', "升级格挂成可拖出的落点、协议槽位号 **0**（§3.190）"],
			# 2026-10-19 阶段二：两条合成一句 `spirit_move(源槽, 目标槽)`
			# （目标槽=0 就是升级格，与 AS3 `upHandler:249` 的 `requestSpirit_move(源, 目的)` 同一条）。
			# 旧断言写死 `spirit_move(源槽, 0)` / `spirit_feed(源槽, 0)` 两条分支，已随合并更新。
			['_宿主._session.spirit_move(源槽, 目标槽)', "落下 ⇒ 动作 10（`requestSpirit_move(slot, 目的)`）"],
			['_宿主._session.spirit_feed(int(来源行.get("slot", 0)), 目标槽)',
				"**落点有货 ⇒ 融合**（`requestSpirit_oneEatOne`，动作 9；确认弹里发）"],
			['int((行 as Dictionary).get("slot", -999)) == 0', "升级槽那件 = `spirit_bag` 里 slot==0 的那条"]]:
		_判(意志文本.contains(String(条[0])), "意志窗口.gd：%s" % 条[1],
				"找不到 `%s` ⇒ 那条链断了" % String(条[0]))
	# —— 阶段二 P1：融合前置 / 黄不穿戴 / 锁格落点 / 锁格扩容（2026-10-19）——
	for 条 in [
			['static func _融合前置(目标行: Dictionary, 来源行: Dictionary, 目标槽: int) -> void:',
				"融合走 `_融合前置`（AS3 `rongHeYiZhi` 的三条前置 + 确认弹）"],
			['if 目色 == 意志黄 and 源色 == 意志黄:', "双黄不许融（`rongHeYiZhi:431-437`）"],
			['_提示满级()', "满级不许融（`rongHeYiZhi:438-445` / `:478-485`）"],
			['_宿主._show_hint(键("YIZHI_YELLOW_NOT_CHUAN_DAI"))',
				"黄不许穿穿戴格（`upHandler:243-246`，一个请求都不发）"],
			['if 目标归属 == "意志背包" and not _背包格开着(目标槽 - 1):',
				"锁格不当落点（`upHandler:232` 的 `_state != 2` ⇒ 直接吐掉）"],
			['static func _点背包格(格: Control, 页: Control, 窗口) -> void:',
				"锁格点击 ⇒ 扩容确认（`clickCellHandler:563-586`）"],
			# ⚠️ 2026-10-23 §3.186：遮罩从「页控件」改传「窗口._overlay」（全屏 ⇒ stage
			#    居中）。旧写法 `页控件` 就是用户报「吞噬弹窗位置错误」的根——别改回去。
			['确认弹.弹消息(窗口._overlay, 填(键("YIZHI_EXPAND_PACK_CELL"), [总价])',
				"扩容确认弹带总价文案 + 遮罩是全屏 overlay（`YIZHI_EXPAND_PACK_CELL` %1=元宝）"],
			# §3.186 同批：融合（吞噬）确认的遮罩也必须是全屏 overlay；`_content.get_child(0)`
			#   （当前页面）当遮罩 ⇒ 弹窗随页面飘（用户报「吞噬弹窗位置错误」的根）。
			['var 遮罩: Control = _宿主._overlay', "融合（吞噬）确认弹挂全屏 overlay（stage 居中）"],
			# §3.186 同批：`_格上那件` 必须按槽位号分流两张表（穿戴位在 equipped）。
			['var 表: Array = _宿主._session.spirit_bag if 槽 >= 0 else _宿主._session.spirit_equipped',
				"_格上那件 按槽位号分流 bag/equipped（身上↔背包融合的前提）"],
			# §3.186 同批：背包/穿戴格三件套（图标+名称+等级）。
			['名.name = "格名称"', "背包/穿戴格三件套之 **名称**（原版 drawYiZhi:195-208）"],
			['级.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER',
				"等级居中（原版 align=center，旧实现右对齐）"],
			['窗口._session.spirit_extend(目标)', "确定 ⇒ `requestSpirit_bagExtend(limit)`（动作 7）"],
			['if 总价 > 现金:', "元宝不足先拦（`sureToExpandCell:355-357` 的 `cashMoney` 判）"],
			['_撤扩容点亮(页控件, 当前, 目标)', "确定第一句就撤预览点亮（`sureToExpandCell:353`）"],
			['static func _扩容花费(当前: int, 目标: int) -> int:',
				"总价按 `common.extend` 累算（`clickCellHandler:571`）"],
		['var 锁 := 格.get_node_or_null("格锁") as Node', "锁态格挂/撤 `格锁` 图标"],
		['图.position = Vector2(-10.0, -16.0)', "锁图落点照 `lockCell:191-192` 的 `_icon.x/y`"],
		['var 下标 := int(str(格.name).substr(2))',
			"锁格下标从名字 `格_<n>` 的第 2 字符起取（`substr(3)` 会得空串、`int(\"\")` 静默变 0 ⇒ 点锁格永远被当开格挡掉）"],
		['static func _刷合成钮态(页: Control) -> void:',
			"一键合成按背包件数定 disabled（`updateHeChengButtonState:301-311`）"],
		['if typeof(行) == TYPE_DICTIONARY and int((行 as Dictionary).get("slot", 0)) > 0:',
			"件数只数 slot>0（升级槽那件不算 —— `onSpirit_updateSpiritInventory:208-215` 把它分给 `yiZhiUpgradeData`）"],
		['钮.disabled = 背包件数 <= 1', "件数 > 1 才亮（AS3 `length > 1`）"],
			['_挂格提示(页, 格, 项, 2, 行)', "有货格挂 type2 提示（`YiZhiTip.createToolTip2`）"]]:
		_判(意志文本.contains(String(条[0])), "P1：%s" % 条[1],
				"找不到 `%s` ⇒ 阶段二那条链断了" % String(条[0]))
	# §3.186 负向两条（本列表只支持正向 contains ⇒ 单独判）：旧遮罩 / `:=` 分表都不许回来
	_判(not 意志文本.contains("确认弹.弹消息(_宿主._content.get_child(0)")
					and not 意志文本.contains("确认弹.弹消息(_content.get_child(0)"),
			"P1：融合确认没把页面当遮罩（负向，旧写法 = 页面内居中、随页面飘）",
			"又把当前页面传给弹消息了 ⇒ 弹窗会随页面飘（§3.186 用户报的根）")
	_判(not 意志文本.contains("var 表 := _宿主._session.spirit_bag if 槽 >= 0"),
			"P1：分表那行没退化成 `:=`（负向，三元两边类型不同 ⇒ 推断不出 ⇒ 编译错）",
			"分表行用了 `:=` ⇒ 编译直接失败（§3.186 踩坑）")
	# 锁图素材与图标源（`开发工具/导出意志格锁.py` 的产物；素材不进 git，只断引用）
	_判(意志文本.contains("res://素材/界面/原版窗口/意志背包/格锁.png"),
			"P1：锁图走 `素材/界面/原版窗口/意志背包/格锁.png`（`UISwf_BailianCopy_Lack`）",
			"换路径/换名 ⇒ 锁态格只剩格底消失，玩家看不出哪格锁着")
	var 组件 := FileAccess.get_file_as_string("res://脚本/界面/组件/意志格.gd")
	_判(组件.contains("if 图 == null or 图.texture == null:"),
			"P1：空格/锁格不起拖（AS3 `downHandler:82-86` 的 `_yiZhiData && _icon`）",
			"删了它 ⇒ 空格也能起拖，拖到哪都被服务端拒（玩家看来没反应）")
	_判(组件.contains("extends Control"),
			"意志格组件是 **Control 基**（`可拖拽格` 是 Button 基，挂不到本窗的空 Control）",
			"换成 Button 基 ⇒ 60 个格子挂不上、拖放全哑")
	# —— 阶段三 P2：图标自转 / 拾取飞入（2026-10-19）——
	var 会话文本 := FileAccess.get_file_as_string("res://脚本/单例/游戏会话.gd")
	_判(FileAccess.file_exists("res://脚本/界面/组件/意志格图标.gd"),
			"P2-1：有 `意志格图标.gd`（格图标自转组件，`RotateComponent` 等价）",
			"缺 ⇒ 图标不转（原版非灰意志都转）")
	var 图标文 := FileAccess.get_file_as_string("res://脚本/界面/组件/意志格图标.gd")
	for 条 in [
			['const 节拍秒 := 1.0 / 24.0', "自转节拍 24fps（与 `意志提示框` 同口径，只影响转速）"],
			['_角 = fmod(_角 + 转速, 360.0)', "每 tick 加 `转速` 度（`RotateComponent.tick:97-101`）"],
			['if 转速 == 0.0 or texture == null:', "灰（speed=0）不转（原版只对非灰加 tick）"]]:
		_判(图标文.contains(String(条[0])), "P2-1：%s" % 条[1],
				"找不到 `%s` ⇒ 自转口径变了" % String(条[0]))
	for 条 in [
			['static func _挂自转(图: TextureRect, 项: Dictionary) -> void:',
				"三个图标点统一走 `_挂自转`（学习格/背包穿戴格/升级槽）"],
			['图.pivot_offset = 图.size / 2.0', "绕自身中心转（`start():65-66` 的 -(w/2) 补偿）"],
			['static func _放飞入(页: Control, 清单: Array) -> void:',
				"拾取飞入（`playPickYiZhiEffect:115-146`）"],
			['补间.tween_property(图, "global_position", 终点, 2.0)',
				"2 秒飞到「打开背包」钮（TweenLite.to(...,2,...)）"],
			['清单.clear()', "播完即清（防紧跟的 cmd1 重播）"],
			['var 拾串 := String(参数[0]) if not 参数.is_empty() else ""',
				"cmd8 拆出 `<itemid&pos>` 清单（服务端 `_pick_spirit_panel_items:22659-263`）"]]:
		_判(意志文本.contains(String(条[0])) or 会话文本.contains(String(条[0])), "P2：%s" % 条[1],
				"找不到 `%s` ⇒ 阶段三那条链断了" % String(条[0]))

	# —— 自动升级循环喂（§3.103 欠账②后半）——
	# 原版 `YiZhiManager` 的 6 状态机 + 五个常量；这几个数是**逐条照 AS3 抄的**，
	# 改一个都会让节奏/停条件变样，所以在这里钉住。
	_判(意志文本.contains("_点自动升级"),
			"意志窗口.gd：钮接的是 `_点自动升级`（原 `onAutoUpgradeBtnClick`）",
			"缺 ⇒ 点了没反应")
	_判(意志文本.contains("停止自动融合"),
			"意志窗口.gd：钮文案在「自动升级意志 / 停止自动融合」之间换",
			"缺 ⇒ 玩家看不出跑没跑")
	for 名 in ["自动升级_开", "自动升级_停", "_自动升级_跳", "_自动升级_状态5",
			"_自动升级_面板帧", "_自动升级_拾取帧", "_自动升级_移除帧", "_自动升级_续跑",
			"意志找可喂", "意志背包件数"]:
		_判(会话文本.contains("func %s(" % 名), "游戏会话.gd 有 %s()（自动升级状态机）" % 名,
				"缺 ⇒ 自动升级跑不起来")
	# 意志力那两条：改名/删掉会让上面第六节的腿**直接崩**（headless 崩了不报红，只在日志里
	#   留一行 script error），所以这里先做文本哨兵。
	# 公式已收回 `游戏数据.意志融经验()` 单源（合并 `意志模块` 时曾抄出 `_意志融合档`/`_意志品质名`）
	for 名 in ["意志力", "融合经验"]:
		_判(会话文本.contains("func %s(" % 名), "游戏会话.gd 有 %s()（意志力算式）" % 名,
				"缺 ⇒ 第六节的腿会崩在调用上，而不是红给你看")
	for 条 in [
			["const 自动升级_间隔 := 0.5", "间隔 500ms（`AUTO_UPGRADE_INTERVAL`）"],
			["const 自动升级_导师 := 4", "导师下标 4（`AUTO_UPGRADE_TEACHER`）"],
			["const 自动升级_空转上限 := 8", "空转上限 8（`AUTO_UPGRADE_MAX_IDLE_CYCLES`）"],
			["const 自动升级_等待上限 := 8", "等帧上限 8（`AUTO_UPGRADE_MAX_WAIT_TICKS`）"],
			["const 自动升级_面板目标 := 10", "面板攒够 10 就全拾取（`AUTO_UPGRADE_PANEL_TARGET`）"],
			["const 意志满级 := 20", "满级 20（`MAX_YIZHI_LEVEL`，与 `common.levelUp` 的 20 条吻合）"]]:
		_判(会话文本.contains(String(条[0])), "游戏会话.gd：%s" % 条[1],
				"找不到 `%s` ⇒ 常量被改过" % String(条[0]))
	# 状态 5 的三条停条件 + 「黄不能喂黄」那条唯一口径
	for 条 in [
			["锁定意志不存在，自动升级已停止", "状态 5：目标没了 ⇒ 停"],
			["意志已达满级，自动升级已停止", "状态 5：满级 ⇒ 停"],
			["背包中的意志无法再喂给当前锁定的意志，自动升级已停止", "状态 5：无可喂且包不空 ⇒ 停"],
			["意志商店暂无可学习的意志，自动升级已停止", "空转到顶 ⇒ 停"],
			["意志黄颜色id := 6", "黄 = `SpiritColor.YELLOW` 的数字 id 6（`SPIRIT_COLOR_IDS`）"],
			["spirit_feed(自动升级目标槽, int(可喂.get(\"slot\", 0)))",
					"喂的是**锁定槽 ↔ 第一件可喂**（动作 9）"]]:
		_判(会话文本.contains(String(条[0])), "游戏会话.gd：%s" % 条[1],
				"找不到 `%s` ⇒ 那条规则没了" % String(条[0]))
	var 宿主 := FileAccess.get_file_as_string("res://脚本/界面/功能窗口.gd")
	for 条 in [["\"遗址\": 意志窗口.渲染背包(self)", "遗址→背包"],
			["\"意志学习\": 意志窗口.渲染学习(self)", "意志学习→学习"],
			["\"意志介绍\": 意志窗口.渲染介绍(self)", "意志介绍→介绍"]]:
		_判(宿主.contains(String(条[0])), "功能窗口 分派 %s" % 条[1], "找不到那行 ⇒ 页面还走旧场景")
	_判(not 宿主.contains("遗址页面场景"),
			"旧手摆版场景 `遗址窗口.tscn` 已无人引用（663×410 那张，尺寸与真值不同源）",
			"还引用着 ⇒ 开出来是旧窗")
	# 2026-10-25 用户：「意志一键学习…直接开放给所有玩家，不需要限制什么 vip 等级」。
	# 本工程这条路径**本来就没有等级闸**（原版 VIP5 特权），这里钉住"以后别再补回来"。
	var 意志源 := FileAccess.get_file_as_string("res://脚本/界面/窗口/意志窗口.gd")
	_判(not 意志源.to_lower().contains("vip"),
			"意志窗口源码里没有 VIP 判断（一键学习对所有人开放）",
			"出现 vip 字样 ⇒ 检查一键学习是不是又被加了等级闸")
	var 服源 := FileAccess.get_file_as_string("res://服务端/runtime/tools/fake_flash_server.py")
	var 起 := 服源.find("    def _learn_all_spirits(")
	var 止 := 服源.find("\n    def ", 起 + 1) if 起 >= 0 else -1
	var 段 := 服源.substr(起, 止 - 起) if 起 >= 0 and 止 > 起 else ""
	_判(not 段.is_empty(), "夹具 `_learn_all_spirits` 存在（一键学习在服务端结算）",
			"找不到函数 ⇒ 被改名/删除")
	_判(not 段.contains("_has_active_vip"),
			"夹具一键学习不判 VIP 等级（开放给所有玩家）",
			"出现 `_has_active_vip` ⇒ VIP 闸又回来了")


## 六、阅历链与导师亮灭（2026-10-19 P0-1/P0-2 的防回退哨兵）。
## 这两条都是"线上功能整条断掉但门全绿"过的事故（阅历恒 0 ⇒ 学习全瘫；
## `spirit_npc_status` 解析了没人读 ⇒ 在线只有召唤位可点），所以按文本钉死接线。
func _量阅历链与导师态() -> void:
	var 窗文 := FileAccess.get_file_as_string("res://脚本/界面/窗口/意志窗口.gd")
	var 会文 := FileAccess.get_file_as_string("res://脚本/单例/游戏会话.gd")
	var 后文 := FileAccess.get_file_as_string("res://脚本/单例/后端连接.gd")
	var 功文 := FileAccess.get_file_as_string("res://脚本/界面/功能窗口.gd")
	# —— P0-1 阅历链：1572 收帧 → 会话字段 → UI 显示/gate 三跳全通 ——
	# 每条 = (该去哪份文本里找, 要找的串, 说明)
	for 条 in [
			[后文, "const OP_PVE_ACTION := 1572", "后端连接.gd 认得 1572（服务端 `_send_pve_status:30856`）"],
			[后文, "signal pve_status_received(progress: int, points: int)", "后端连接.gd 有 1572 信号"],
			[后文, "func request_pve_status() -> bool:", "后端连接.gd 能主动问一次（action 0）"],
			[会文, "var 阅历 := 0", "游戏会话.gd 有 `阅历` 字段（pve_points 拆帧落点）"],
			[会文, "func _on_backend_pve_status(进度: int, 点数: int) -> void:", "游戏会话.gd 有 1572 拆帧函数"],
			[会文, "backend.pve_status_received.connect(_on_backend_pve_status)", "游戏会话.gd 接了这条信号"],
			[会文, "func 请求阅历状态() -> bool:", "游戏会话.gd 有阅历状态请求封装"],
			[会文, "signal 阅历_变化(点数: int)", "阅历有**专用**信号（不走 spirit_state_changed，防成环）"],
			[会文, "阅历_变化.emit(点数)", "1572 拆帧发的是阅历专用信号（不重建学习页）"],
			[功文, "_session.阅历_变化.connect(_on_阅历_变化)", "功能窗口接了阅历信号（就地刷标签）"],
			[窗文, "static func 刷阅历(窗口, 点数: int) -> void:", "意志窗口.gd 有就地刷标签函数（AS3 updateYueLiAndYuanBao）"],
			[窗文, "if bool(窗口.get(\"_刚开窗\")):", "请求阅历状态只在**开窗**那一轮发（防 重建→再请求 成环）"],
			[窗文, "str(int(窗口._session.阅历))", "意志窗口.gd「阅历数值」读的是 `会话.阅历`"],
			[窗文, "var 阅历 := int(窗口._session.阅历)", "意志窗口.gd `_导师点击` 的 gate 读 `会话.阅历`"]]:
		_判(String(条[0]).contains(String(条[1])), "P0-1：%s" % 条[2],
				"找不到 `%s` ⇒ 阅历链又断了（学习页恒 0、导师全弹阅历不足）" % String(条[1]))
	# 老的假键一个都不许回来（`player_stats.spirit_experience` 全工程零处写 ⇒ 恒 0）
	for 文 in [窗文, 会文]:
		_判(not 文.contains("player_stats.get(\"spirit_experience\""),
				"P0-1：没有回退到 `player_stats.spirit_experience`（没人写的键）",
				"又读回那个键了 ⇒ 阅历恒 0")
	# —— P0-2 导师亮灭：cmd0 状态表逐位消费 + 召唤分流照 `clickTeacherHandler` ——
	for 条 in [
			["static func _刷新导师状态(页: Control) -> void:", "签名不带 `亮` 参数（亮灭由状态表定，不再调用方传）"],
			["int(状态[i]) != 0", "非 0 = 亮（`SpiritNpcStat` 0/1/2；1 普通解锁、2 已召唤）"],
			["_宿主._session.spirit_npc_status", "读的是会话里 cmd0 拆出来的 5 位状态"],
			["if 召 != null and 召.visible:", "`_导师点击` 按召唤钮可见分流（AS3 `clickTeacherHandler:133`）"],
			["泡.visible = (i == 末亮)", "气泡只给末亮位（`TeacherPanel:76` 循环末值，全 DARK 回落 0）"],
			# 2026-10-21：末亮必须**先整表算完**再显隐。曾经的实现在显隐循环里边走边判
			# （吃当时的末亮）⇒ 状态 [1,1,0,0,0] 时 0/1 两格的气泡同时亮（用户截图照出）。
			["for i in mini(5, 状态.size()):", "末亮在显隐循环**之前**整表算完（防多泡同亮）"]]:
		_判(窗文.contains(String(条[0])), "P0-2：%s" % 条[1],
				"找不到 `%s` ⇒ 导师亮灭/召唤分流又失效" % String(条[0]))
	_判(窗文.contains("一键.visible = 可召唤"),
			"P0-2：一键学习钮可见性跟随可召唤标志（`TeacherPanel:56` `studyAllBtn.visible = param3`）",
			"缺 ⇒ 一键学习钮不再跟随服务端口径")
	# 2026-10-21 导师气泡两条断言钉在量具表里，文本哨兵防被删：
	#   * `_验气泡图层`：气泡必须是每格**末位子件**（Godot 兄弟后声明 = 画在上层）
	#     —— 用户实机报「图层这里黄色的应该在人物前面，第一个是对的，都要和第一个一样」；
	#   * `_步验单泡`：喂 [1,1,0,0,0] 后只许末亮位一个气泡（原版 `onSpirit_lightNpc` 显新隐旧）。
	var 具文 := FileAccess.get_file_as_string("res://开发工具/截意志学习页.gd")
	for 条 in [
			["func _验气泡图层(页: Control) -> void:", "量具表有气泡图层断言（气泡 = 每格末位子件，压在头像上）"],
			["func _步验单泡() -> void:", "量具表喂多位亮灯状态，钉「任何时刻只有一个气泡」"]]:
		_判(具文.contains(String(条[0])), "P0-2：%s" % 条[1],
				"找不到 `%s` ⇒ 2026-10-21 的气泡图层/单泡断言被删了" % String(条[0]))
	print("  √ 阅历链与导师态哨兵跑完（P0-1/P0-2 防回退）")


## 七、意志力口径与两处悬停提示的防回退哨兵（2026-10-21 §3.181）。
## 用户实机报「意志穿上后人物面板意志处不显示、悬停没有提示」：根因是
## `游戏会话.意志力()` 只加了协议第 4 列（原始 exp，新学得的件恒 0），而 AS3 口径是
## **融经验**（`YiZhiData.rongHeExp:92-101`：黄固定 1200、其余 level1 基础 + exp、
## level1 表没有 gray ⇒ 灰件贡献 0 而不是 0+exp）再 ÷30
## （`YiZhiManager.caculateYiZhiLi:168-181`）。
## 顺带：背包窗「意志值」框的提示原本读页上两个 meta「穿戴数组」/「意志力」——
## 全工程 grep 过没有任何地方 set 过 ⇒ 那枚悬停从接上那天起就只显示「当前意志：0」。
## 现在两处提示（人物面板意志格 / 背包窗意志值框）都走 `意志提示框.意志力提示文案()`
## ——**只许这一份**。合并 `意志模块` 时分支另抄了 `游戏数据.意志提示文()`，
## 主线 §3.234 的十处悬停框架（`_挂文字提示`）才是人物面板的实际通路，那份副本已删。
func _量意志力口径() -> void:
	var 数文 := FileAccess.get_file_as_string("res://脚本/单例/游戏数据.gd")
	var 会文 := FileAccess.get_file_as_string("res://脚本/单例/游戏会话.gd")
	var 窗文 := FileAccess.get_file_as_string("res://脚本/界面/窗口/意志窗口.gd")
	var 人窗文 := FileAccess.get_file_as_string("res://脚本/界面/窗口/人物窗口.gd")
	var 提文 := FileAccess.get_file_as_string("res://脚本/界面/组件/意志提示框.gd")
	for 条 in [
			[数文, "const 意志色名 := {1: \"gray\", 2: \"green\", 3: \"blue\", 4: \"pueple\", 5: \"pink\", 6: \"yellow\", 7: \"red\", 8: \"lpink\"}",
				"游戏数据.gd 有色名表（协议 color int 1..8 = `SpiritColor.as:6-20`）"],
			[数文, "static func 意志融经验(行: Dictionary) -> int:",
				"游戏数据.gd 有 `意志融经验()`（rongHeExp 唯一实现）"],
			[数文, "return 1200", "黄固定 1200（`YiZhiData.rongHeExp:92-101`）"],
			[数文, "if not 基础.has(色):", "level1 没有的色（gray）⇒ 0，不是 0+exp"],
			[提文, "static func 意志力提示文案(穿戴: Array, 值: int) -> String:",
				"意志提示框.gd 有 `意志力提示文案()`（两处提示的唯一一份）"],
			[会文, "func 意志力() -> int:", "游戏会话.gd 有 意志力()"],
			[会文, "总 += GAME_DATA.意志融经验(件 as Dictionary)",
				"意志力只加**融经验**（不是协议第 4 列的原始 exp）"],
			[会文, "return int(总 / 30.0)", "意志力 = Σ融经验 ÷ 30（`caculateYiZhiLi:168-181`）"],
			[窗文, "_宿主._session.spirit_equipped", "背包窗提示读会话真穿戴数组（不是没人写的 meta）"],
			[窗文, "意志提示框.意志力提示文案(", "背包窗提示走共用 `意志力提示文案()`"],
			[人窗文, "意志提示框.意志力提示文案(会.spirit_equipped, int(会.意志力()))",
				"人物面板意志格提示同口径（读会话 + 共用函数）"],
			[人窗文, "_挂文字提示(页面, 面板, \"信息区/意志格\"",
				"人物面板意志格挂在 §3.234 的十处悬停框架上（`CharPane.setYiZhiData:290-299`）"]]:
		_判(String(条[0]).contains(String(条[1])), "§3.181：%s" % 条[2],
				"找不到 `%s` ⇒ 意志力口径/提示链断了" % String(条[1]))
	# 合并后留下的分支副本：`_接意志格悬停` 已被主线 §3.234 的 `_挂文字提示` 取代。
	_判(not 人窗文.contains("func _接意志格悬停("),
			"§3.181：`人物窗口.gd` 不再留着被取代的 `_接意志格悬停()`（合并遗留死代码）",
			"又长回来了 ⇒ 两条悬停通路争同一个格")
	# meta 判死要看**代码行**：注释里引述旧病灶不算（原判把注释也搜进去了）。
	var 窗码 := ""
	for 行 in 窗文.split("\n"):
		if not 行.strip_edges().begins_with("#"):
			窗码 += 行 + "\n"
	_判(not 窗码.contains("get_meta(\"穿戴数组\"") and not 窗码.contains("get_meta(\"意志力\""),
			"§3.181：背包窗不再读「穿戴数组 / 意志力」meta（全工程无人 set 过）",
			"又读回那两个 meta 了 ⇒ 背包窗悬停只剩「当前意志：0」一行")
	print("  √ 意志力口径与两处提示哨兵跑完（§3.181 防回退）")


## 八、一键三钮「动作名三处一致」哨兵（2026-10-22 §3.183）。
## 用户**第三次**实机报「一键学习/一键拾取/一键卖出点击后没有反应」的真凶：
## `_接学习钮` 的 lambda 里 `match 动作` 的三个分支名写的是「一键学习/全部拾取/全部卖出」，
## 而 `学习钮表` 第三列（真正传进 lambda 的 动作 值）是「学习全部/拾取全部/卖出全部」——
## **词序对不上，match 永远不命中** ⇒ `发` 恒 false ⇒ 请求一个都没出客户端，恒弹离线回执。
## §3.178 的 `验意志一键钮.gd` 又把那句离线回执当期望断言 ⇒ 门把 bug 钉住（假绿）；
## §3.182 修好 512 路由也没用——包根本没发。在线真门见
## `测试/一键三钮在线回归测试.gd`（真点钮 + 可观测反馈）；本哨兵是离线第二层。
func _量三钮动作名() -> void:
	var 窗文 := FileAccess.get_file_as_string("res://脚本/界面/窗口/意志窗口.gd")
	# ① 钮表第三列（动作值）三处原样在
	for 值 in ["学习全部", "拾取全部", "卖出全部"]:
		_判(窗文.contains("\"%s\"" % 值), "§3.183：学习钮表有动作值「%s」" % 值,
				"学习钮表里找不到「%s」——钮表被改了？" % 值)
	# ② lambda 的 match 分支名与钮表**逐字一致**（错位就恒 false、请求不发）
	for 行 in [
			"\"学习全部\": 发 = 窗口._session.spirit_learn_all()",
			"\"拾取全部\": 发 = 窗口._session.spirit_pick_all()",
			"\"卖出全部\": 发 = 窗口._session.spirit_sell_all()"]:
		_判(窗文.contains(行), "§3.183：match 分支 `%s`" % 行,
				"找不到 `%s` ⇒ match 与钮表错位，三钮又会变成永不发送" % 行)
	# ③ 错名字不许以分支形态回来（词序颠倒的那三个）
	for 错 in ["\"一键学习\": 发", "\"全部拾取\": 发", "\"全部卖出\": 发"]:
		_判(not 窗文.contains(错), "§3.183：错名字 `%s` 没回来" % 错,
				"`%s` 又出现了 ⇒ 就是 2026-10-22 那个三钮不发送的真凶" % 错)
	# ④ 「自动升级钮」在背包钮表里只为蹭换皮，pressed 必须由 `_接升级槽` 独家接
	#    （原来 `_接背包钮` 的 `_:` 兜底会再挂一条 `spirit_merge_all` = 一颗钮两个动作）
	_判(窗文.contains("\"合成全部\":"),
			"§3.183：_接背包钮 显式接「一键合成」",
			"_接背包钮 没有显式的「合成全部」分支了 ⇒ 一键合成又会掉进兜底")
	_判(窗文.contains("**一颗钮只准有一条 pressed 接线**（工程铁律，见文件头与家族子窗的前科）。"),
			"§3.183：_接背包钮 的兜底分支是「不接 + 说明」",
			"找不到兜底分支的说明注释 ⇒ 自动升级钮可能又被双挂一条一键合成")
	print("  √ 一键三钮动作名对齐哨兵跑完（§3.183 防回退）")


## 九、穿戴八格「循环边界」哨兵（2026-10-22 §3.184）。
## 用户实机报：意志背包窗穿戴盘**左下角那格无法装备意志**（拖任何件进去都没反应）。
## 真凶 = `_填一格层` 的循环上界写成 `for i in 数量`：穿戴传的是 8 ⇒ range(8) 只走到
## 格_7；格_8（左下，`initView:451` 偏移 [-4,161]）**从没接过拖放、没填过内容**
## ⇒ 落点收不到（与 §3.183 的 match 错位同族：边界差一个 ⇒ 静默失灵；截图量具只量
## 几何、在线门此前只挪 -1 ⇒ 覆盖率 0）。修：穿戴上界 `数量 + 1`（range(9)，跳过格_0）。
func _量穿戴八格边界() -> void:
	var 窗文 := FileAccess.get_file_as_string("res://脚本/界面/窗口/意志窗口.gd")
	# ① 修复形状在：上界变量 + 穿戴 +1（闭区间差一，格_8 必须进）
	_判(窗文.contains("var 上界 := 数量 if 背包 else 数量 + 1"),
			"§3.184：_填一格层 的上界按容器分开算（穿戴 8 格要 +1）",
			"找不到 `var 上界 := 数量 if 背包 else 数量 + 1` ⇒ 穿戴 8 格又只会填到格_7")
	# ② 负向：不分容器的旧上界不许回来（那就是格_8 掉线的那一版）
	_判(not 窗文.contains("var 上界 := 数量\n") and not 窗文.contains("for i in 数量:"),
			"§3.184：不分容器的旧上界没回来",
			"上界又写回不分数量的 `数量` ⇒ 穿戴 8 格将再次只填到格_7（左下格收不到拖放）")
	# ③ 场景侧 8 个穿戴格节点必须全在（少一个 ⇒ 那一格连渲染都没有）
	var 场景文 := FileAccess.get_file_as_string("res://场景/界面/窗口/遗址/意志背包窗口.tscn")
	for k in range(1, 9):
		_判(场景文.contains("node name=\"格_%d\" type=\"Control\" parent=\"穿戴容器\"" % k),
				"§3.184：场景里有穿戴格_%d" % k,
				"场景里没有 穿戴容器/格_%d ⇒ 左上到左下的 8 格缺一员" % k)
	print("  √ 穿戴八格边界哨兵跑完（§3.184 防回退）")


## 十、学习面板「第二层」哨兵（2026-10-22 §3.185）。
## 用户实机报：学习窗顶部那排意志**应该有第二层，但是没有显示**。真凶 =
## `_填学习格` 循环上界写成 `for k in 10`：只填一排 10 格。而原版 `YiZhiContainer`
## **按数据动态排两行**（`LENGTH=10`，`getYiZhiPoint:65-71` `y=(i/10)·82`）、服务端
## `SPIRIT_PANEL_LIMIT = 20`（`fake_flash_server.py:11166`）⇒ 面板 ≥11 件时多出的件
## 在客户端**不显示、不可拾取/卖出**（服务端明明存着）。与 §3.183/§3.184 同族：
## 边界差一个 ⇒ 静默失灵。修：上界 20（两行 = 全容量）+ 场景补烘第二排。
## 在线侧真渲染断言见 `一键三钮在线回归测试.gd` 的 `_验第二层与独接`。
func _量学习面板两层() -> void:
	var 窗文 := FileAccess.get_file_as_string("res://脚本/界面/窗口/意志窗口.gd")
	# ① 正向：上界 20（原版动态两行 + 服务端 20 上限）
	_判(窗文.contains("for k in 20:"),
			"§3.185：_填学习格 上界是 20（两行 10 列）",
			"`_填学习格` 的上界不是 20 ⇒ 面板 ≥11 件时第二层填不出来")
	# ② 负向：只填一排的旧上界不许回来（那就是用户报「没有第二层」的那一版）
	_判(not 窗文.contains("for k in 10:\n\t\tvar 槽"),
			"§3.185：一排的旧上界没回来",
			"`for k in 10:` 又出现在 `_填学习格` ⇒ 第二层 10 格将再次收不到内容")
	# ③ 场景侧 20 个学习格节点必须全在（生成器 range(20) 的产物）
	var 场景文 := FileAccess.get_file_as_string("res://场景/界面/窗口/遗址/意志学习窗口.tscn")
	for k in 20:
		_判(场景文.contains("node name=\"意志格_%d\" type=\"Control\" parent=\"意志容器\"" % k),
				"§3.185：场景里有学习格_%d" % k,
				"场景里没有 意志容器/意志格_%d ⇒ 第二层缺员（重跑 生成意志学习场景.py）" % k)
	# ④ 量具表与生成器同步登记（生成器是场景的唯一产出通道）
	var 量具文 := FileAccess.get_file_as_string("res://开发工具/截意志学习页.gd")
	_判(量具文.contains("for k in 20:") and 量具文.contains("\"意志格19\""),
			"§3.185：量具表 页面件表 覆盖 20 格",
			"量具表还只登记一排 ⇒ 门量不到第二层，生成器也不会补烘")
	print("  √ 学习面板两层哨兵跑完（§3.185 防回退）")


func _判(对: bool, 说明: String, 失败话: String) -> void:
	if 对:
		print("  √ %s" % 说明)
	else:
		print("  !! %s —— %s" % [说明, 失败话])
		_错 += 1


func _报(说明: String) -> void:
	print("  !! %s" % 说明)
	_错 += 1
