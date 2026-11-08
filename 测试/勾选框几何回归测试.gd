extends SceneTree
## 勾选框几何 + `CheckBox/hover_pressed` 的离线门（登记在 `开发工具/验证全部.ps1`）。
##
## 为什么立这条门（§3.279）：工程里三份文档曾把裸 `CheckBox` 的最小高 **27** 说成"引擎死数"，
## 并据此禁止给 `CheckBox` 补 `hover_pressed`、让所有场景把 19 的皮烘成 27 高的控件矩形。
## 10-25 逐条实测，两条都不成立，真因是**主题漏声明这一槽**：
##   ① 未声明的槽沿解算链回落到引擎兜底盒，而兜底的那张 `StyleBoxEmpty` **四边各带 4 像素
##      content_margin**（`_探_盒边距.gd`：兜底盒 `最小=(8.0, 8.0)`）。`Button::_get_minimum_size()`
##      把"当前态样式盒"的 margin 折进控件最小高 ⇒ 裸勾 min = (19, 19+4+4=**27**)。
##   ② 于是 19 的皮在 27 的矩形里**居中** ⇒ 皮比控件顶边低 4（画面比烘的位置下移 4），
##      且原版 20/21/22 的行距被 27 高的控件矩形咬掉 5~6 像素 ⇒ 上一行勾的点击抢走下一行。
##   ③ 反证（阳性对照）：给 `CheckBox/hover_pressed` 声明一张边距 4 的空盒 ⇒ min.y 立刻 27；
##      边距 7 ⇒ 33。**地板跟着声明走**，不是压不动的死数。
##   ④ 修法只在 CheckBox 这一行：`脚本/界面/原版皮肤表.gd` 给六态各声明一张空盒
##      （边距全 0）⇒ min 回 19 ⇒ **控件矩形 == 皮肤矩形**，各场景按皮肤原生 19 重烘。
##      `Button`/`OptionButton` 等**仍不声明** `hover_pressed`：实测缺这槽不闪粉（引擎在解算到
##      兜底盒时退回画 `pressed`，有头量具逐像素判过），补了反而要逐族核对"按下态还是不是那张皮"。
##      ⇒ 下面 `_查缺槽无害` 冻结的就是这个不对称：CheckBox 六槽齐、按钮族 `hover_pressed` 缺着。
##
## ⚠ 三个量具坑（都踩过，别再踩）：
##   · `add_child()` 当帧读 `get_combined_minimum_size()`/`size` 拿到的是**上帧的脏值** ⇒ 一律
##     `await process_frame` 两帧后再读（腿②③都这么办）。
##   · 对 `主题.duplicate()` **清空**一个槽（`clear_stylebox`）**不是有效对照**：解算链在
##     "实例主题没有 → 项目默认主题有"那一步落回默认，读到的是默认主题里那张真盒（`_探_主题改道通不通.gd`）。
##     只有"往重复主题里**塞**一张盒"才改得动 ⇒ 阳性对照只做注入，不做撤槽。
##   · Godot 4.7 样式盒的边距属性叫 `content_margin_*`（`set_content_margin(边, v)`）；
##     `盒.set("margin_left", …)` 是个静默 no-op，会把"我压不动地板"的假结论造出来。
##
## 跑法：Godot --headless --path . --script res://测试/勾选框几何回归测试.gd

const 主题路 := "res://素材/界面/原版主题.tres"
const 皮高 := 19.0				# `MCheckBox.as:81-82` `_height = upSkin.height`；皮 = `复选框未选.png` 19×19
const 原版行距 := 20.0			# 用户给的判据下限：两枚勾的行距不得小于原版最小行距
const 粉盒色 := Color(1.0, 0.365, 0.365, 1.0)

## CheckBox 必须在主题里**逐槽声明**的六态（缺任一张 ⇒ 解算回兜底盒 ⇒ 地板被边距顶起来）。
const 六态 := ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]

## 按钮族 → 该族 `pressed` 档的皮文件名；空串 `""` = 该族按下档**没有皮**（只能空盒）。
## 全部取自 `开发工具/_探_族按下槽.gd` 的普查（不是猜的；文件名写错这条门当场红）。
const 族按下皮 := {
	"Button": "按钮_按下.png",
	"OrigTab": "分页按钮未选_按下.png",
	"OrigListItem": "选中条.png",
	"OrigPayButton": "充值按钮.png",
	"OrigItemSlotButton": "物品格.png",
	"OrigBlankButton": "",
	"CheckBox": "",
	"OptionButton": "输入框.png",
}

## 记名例外：`场景标/父名/件名` → `[运行高, 皮顶差, 理由]`。
## 只有"控件矩形比皮高"且**理由成立**的这一枚允许不等；出现表外的 ⇒ 当场红
## （多出来的高度只可能是有人又给哪一态换了带边距的盒，或改了字号）。
const 例外 := {
	"登录界面/登录卡片/记住密码": [23.0, 2.0,
		# `脚本/界面/登录界面.gd::_apply_theme` 自建 Theme（`default_font_size = 17`），
		# 17 号字的行高 23 > 皮高 19 ⇒ min 被文字撑到 23，皮居中 ⇒ 顶差 (23−19)/2 = 2。
		"这一屏不是原版窗口（本工程自加的登录卡），17 号字撑高 23 是既有事实；皮顶比烘的位置低 2"],
}

## 勾选框在场景里与**可点兄弟**的重叠带（`父名, 勾名, 兄名, 纵, 横`）—— 逐条相等。
## 判据是"逐条相等"：多一条 ⇒ 新增抢点击；少一条或数值变了 ⇒ 有人挪了 y/换了行距，
## 那是要重看布局的信号，不是"更好了"。方向（谁赢这一带）由树序决定。
## 10-25 重烘到 19 后只剩这三条。27 地板年代冻的是 7 条：`使用镇灵石↔使用寄坏玉`（勾抢勾，纵 5）、
## `使用镇灵石↔数量下拉`（4×4）、商城那两条（7×18、6×19）随地板一起消失；
## 余下三条只是**变小**（26→18、21→15、20→19），共同形状都是
## "勾的烘宽（指示框 + 文字，按 AS3 原生宽）右缘压住下拉左缘 2~4 像素"。
## 其中宠物那条对得上真值（`真值/窗口/宠物.md:631`：幸运符数量 MComboBox 在 (280,266) 40×20，
## 勾在 (180,266) 宽 102 ⇒ 右缘 282 ⇒ 横叠 2、纵叠 19，原版就是这 2 像素的贴边）；
## 另两条同形，改它们前先用 `开发工具/_探_勾普查.gd` 复量一遍再回填本表。
## ⚠ 2026-10-27 报修④：寄坏之术页那条（纵 18 横 4）**不是原版的贴边**，是勾烘在 x=154、
##   下拉又比原版 MComboBox 宽 17 ⇒ 下拉右沿压到勾字底下、连带盖住尾文字「个寄坏玉」12 像素。
##   已按 `KunChongStrengthWindow.as:296-321` 把这一行重摆（勾 125 / 下拉 220 宽 57 / 尾文字从
##   下拉左起 60）⇒ 该条重叠带**消失**，本表删掉这一行（表里留着就会红"量不到"）。
##   另两条（开通穴道弹窗、宠物提升页）留着：宠物那条已核对过真值，穴道那条同形未报修。
const 重叠表 := {
	"开通穴道弹窗": [["开通穴道弹窗", "使用八门灵符", "数量下拉", 15.0, 2.0]],
	"宠物提升页": [["宠物提升页", "使用幸运符", "幸运符数量", 19.0, 2.0]],
}

const 场景们 := [
	"res://场景/界面/登录界面.tscn",
	"res://场景/界面/窗口/亲热天堂/亲热天堂窗口.tscn",
	"res://场景/界面/窗口/人物/页面/寄坏之术页.tscn",
	"res://场景/界面/窗口/人物/页面/开通穴道弹窗.tscn",
	"res://场景/界面/窗口/人物/页面/柔拳页.tscn",
	"res://场景/界面/窗口/副本/副本窗口.tscn",
	"res://场景/界面/窗口/宝石工艺/宝石工艺窗口.tscn",
	"res://场景/界面/窗口/宠物/宠物提升页.tscn",
	"res://场景/界面/窗口/秘籍合成/秘籍合成窗口.tscn",
	"res://场景/界面/窗口/装备强化/装备强化窗口.tscn",
	"res://场景/界面/窗口/装备强化/页面/装备打造通用页.tscn",
	"res://场景/界面/窗口/装备强化/页面/装备洗附加属性页.tscn",
	"res://场景/界面/窗口/装备强化/页面/装备精炼页.tscn",
	"res://场景/界面/窗口/装备强化/页面/装备进阶页.tscn",
	"res://场景/界面/窗口/设置/设置窗口.tscn",
	"res://场景/界面/窗口/遗址/意志背包窗口.tscn",
	"res://场景/界面/组件/一键出售窗.tscn",
	"res://场景/界面/组件/商城购买窗.tscn",
]

var _错 := 0
var _判数 := 0
var _勾数 := 0


func _initialize() -> void:
	var 主题 := load(主题路) as Theme
	if 主题 == null:
		_报("读不到主题 %s" % 主题路)
		收尾()
		return
	await _查六槽齐全(主题)
	await _查地板跟着声明(主题)
	_查别处不再抬顶边()
	var 量 := await _量场景(主题)
	_查实高(量)
	_查行距(量)
	_查重叠(量)
	_查代码勾()
	_查缺槽无害(主题)
	收尾()


func 收尾() -> void:
	var 带数 := 0
	for 标 in 重叠表:
		带数 += (重叠表[标] as Array).size()
	if _错 > 0:
		print("!! 勾选框几何门失败 %d 条（勾 %d 枚 / 判 %d 条）" % [_错, _勾数, _判数])
		quit(1)
	else:
		print("勾选框几何门：六槽齐 + 地板跟声明（4→27、7→33 阳性对照） + %d 枚勾 烘高==运行高==19" % _勾数
				+ " + 同父行距≥%s 且纵叠 0 + 兄弟带冻结 %d 条 + 代码勾 + 缺槽无害普查 全对上（共判 %d 条）" % [
					str(原版行距), 带数, _判数])
		quit(0)


func _判(对: bool, s: String) -> void:
	_判数 += 1
	if not 对:
		_报(s)


func _报(s: String) -> void:
	_错 += 1
	print("红  " + s)


## ── ① CheckBox 六态逐槽声明为空盒、且空盒边距为 0 ─────────────────────
## 这条不是形式主义：地板是"当前态样式盒的边距"折出来的，所以只要有一槽漏了或带边距，
## 那一态（悬停按住 / 置灰 / 聚焦）就把控件顶到 27，画面跳一下。逐槽查才拦得住。
func _查六槽齐全(主题: Theme) -> void:
	for 态 in 六态:
		_判(主题.has_stylebox(态, "CheckBox"),
				"`CheckBox/%s` 在主题里没声明 ⇒ 沿解算链回兜底空盒（四边各 4 像素边距），" % 态
				+ "那一态的控件最小高被顶成 27、皮居中下挪 4（改这里去 `脚本/界面/原版皮肤表.gd` 的 CheckBox 段）")
		if not 主题.has_stylebox(态, "CheckBox"):
			continue
		var 盒 := 主题.get_stylebox(态, "CheckBox")
		_判(盒 is StyleBoxEmpty, "`CheckBox/%s` 应是空盒（勾选框的皮只有指示图 + 文字，没有底），实得 %s" % [
			态, 盒.get_class()])
		for 边 in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			## ⚠ `StyleBoxEmpty` 没覆写时 `get_content_margin` 回 **-1**（"未设"），贡献 0；
			##    只有**正值**才把地板顶起来（兜底那张就是四边各 4 ⇒ 27）。所以判 `<= 0`，不是判 `== 0`。
			var 距: float = 盒.get_content_margin(边)
			var 上: float = maxf(0.0, 盒.get_content_margin(SIDE_TOP))
			var 下: float = maxf(0.0, 盒.get_content_margin(SIDE_BOTTOM))
			_判(距 <= 0.0, "`CheckBox/%s` 的边距 %s = %s ⇒ 最小高被加出 %s（地板跟着边距走，见腿②）" % [
					态, _边名(边), str(距), str(皮高 + 上 + 下)])
		_判(盒.get_minimum_size() == Vector2.ZERO, "`CheckBox/%s` 的最小尺寸应是 (0,0)，实得 %s" % [
			态, str(盒.get_minimum_size())])
	var 皮: Texture2D = 主题.get_icon("unchecked", "CheckBox")
	_判(皮 != null and 皮.get_height() == int(皮高),
			"勾选框皮肤高应是 %s（`复选框未选.png` 19×19，`MCheckBox.as:81-82`），实得 %s" % [
				str(皮高), "读不到" if 皮 == null else str(皮.get_height())])


## ── ② 地板跟着声明走（阳性对照）─────────────────────────────────────
## 老门在这里断言"八种切法都压不动 = 27"，那条结论把工程带偏了一个多月：
## 真正压不动的是**没声明的槽**（撤槽无效，见头注释的解算链坑），声明进去的盒边距是**线性**的。
## 所以这一腿三档一起判，缺一个方向都算红。
func _查地板跟着声明(主题: Theme) -> void:
	var 现状 := await _裸勾高(主题)
	_判(现状 == 皮高,
			"现状：六槽齐的空盒边距全 0 ⇒ 裸 CheckBox 最小高应是皮高 %s（控件矩形 == 皮肤矩形），实得 %s" % [
				str(皮高), str(现状)])
	for 档 in [[4.0, 27.0], [7.0, 33.0]]:
		var 边: float = float(档[0])
		var 期: float = float(档[1])
		var 盒 := StyleBoxEmpty.new()
		盒.set_content_margin(SIDE_TOP, 边)
		盒.set_content_margin(SIDE_BOTTOM, 边)
		var 注 := 主题.duplicate(true) as Theme
		注.set_stylebox("hover_pressed", "CheckBox", 盒)
		var 得 := await _裸勾高(注)
		_判(得 == 期, "阳性对照：给 `CheckBox/hover_pressed` 注入边距 %s 的空盒 ⇒ 最小高应是 %s" % [
			str(边), str(期)] + "（= 皮高 19 + 上 %s + 下 %s，证明地板由声明的盒线性撑出、不是引擎死数），实得 %s" % [
				str(边), str(边), str(得)])
	## 反向：皮高没变但盒边距为 0 ⇒ 钉 `minimum_height` 也不该再多长（保证 19 是自然高，不是被夹小的）
	var 钉 := 主题.duplicate(true) as Theme
	钉.set_constant("minimum_height", "CheckBox", int(皮高))
	var 钉得 := await _裸勾高(钉)
	_判(钉得 == 皮高, "钉 `CheckBox/minimum_height=19` 后仍应是 %s，实得 %s" % [str(皮高), str(钉得)])


func _裸勾高(主题: Theme) -> float:
	var 勾 := CheckBox.new()
	勾.theme = 主题
	勾.text = "开奖后自动领奖"
	root.add_child(勾)
	await process_frame
	await process_frame
	var 得: float = 勾.get_combined_minimum_size().y
	root.remove_child(勾)
	勾.free()
	return 得


## ── ③ 别再往各门里塞"顶边抬 4"的补偿 ────────────────────────────────
## 27 地板年代，各窗把控件顶边抬 4 才让 19 的皮落回真值那一行（`意志页回归测试.顶边抬`、
## `真值/窗口/宝石工艺.md` 的"外扩 4"）。现在控件矩形 == 皮肤矩形 ⇒ 抬量一律 0，
## 谁再往里填一项，就是有人以为地板还是 27（那条注释/常量要一起删，不是补回来）。
func _查别处不再抬顶边() -> void:
	var 页 := load("res://测试/意志页回归测试.gd") as GDScript
	if 页 == null:
		_报("读不到 `测试/意志页回归测试.gd` ⇒ 没法核对它的 `顶边抬`")
		return
	var 表: Dictionary = 页.get_script_constant_map().get("顶边抬", {})
	_判(表.is_empty(), "`意志页回归测试.顶边抬` 应是空表（10-25 起不再有 27 地板补偿），实得 %s ⇒ " % [str(表)]
			+ "要么有人把控件顶边又抬回去了，要么地板重新被边距顶起来，先回腿②查主题")


## ── ④ 逐枚勾：烘高 == 运行高 == 皮高，皮顶差 == 0 ────────────────────
## `add_child` 前先取 .tscn 里烘的矩形（add 之后被容器/夹取覆盖就取不到了），
## 两帧后取实际 `size` 与全局矩形；皮顶差 = (运行高 − 皮高)/2（Godot 把皮画在垂直居中处）。
func _量场景(主题: Theme) -> Array:
	var 出: Array = []
	for 路: String in 场景们:
		var 标 := 路.get_file().trim_suffix(".tscn")
		var 包 := load(路) as PackedScene
		if 包 == null:
			_报("载入失败：%s" % 路)
			continue
		var 景 := 包.instantiate()
		var 勾们: Array = []
		_收(景, 勾们)
		var 烘 := {}
		for 件V in 勾们:
			var 件 := 件V as CheckBox
			烘[件.get_instance_id()] = Rect2(件.position, Vector2(
				件.offset_right - 件.offset_left, 件.offset_bottom - 件.offset_top))
		root.add_child(景)
		await process_frame
		await process_frame
		for 件V in 勾们:
			var 件 := 件V as CheckBox
			var 父: Control = 件.get_parent() as Control
			var 图: Texture2D = 件.get_theme_icon("unchecked")
			var 本皮高 := float(图.get_height()) if 图 != null else 皮高
			var 全: Rect2 = 件.get_global_rect()
			出.append({
				"标": 标, "父": String(父.name), "名": String(件.name),
				"烘": 烘[件.get_instance_id()], "运行": Rect2(件.position, 件.size),
				"全局顶": 全.position.y, "皮高": 本皮高,
				"皮顶差": (件.size.y - 本皮高) / 2.0, "最小": 件.get_combined_minimum_size(),
			})
		root.remove_child(景)
		景.free()
	return 出


func _查实高(量: Array) -> void:
	for 条 in 量:
		_勾数 += 1
		var 标 := String(条["标"])
		var 键 := "%s/%s/%s" % [标, String(条["父"]), String(条["名"])]
		var 运行高: float = (条["运行"] as Rect2).size.y
		var 烘高: float = (条["烘"] as Rect2).size.y
		var 皮顶差: float = float(条["皮顶差"])
		if 例外.has(键):
			var 期: Array = 例外[键]
			_判(运行高 == float(期[0]) and is_zero_approx(皮顶差 - float(期[1])),
					"记名例外 `%s` 应是 运行高 %s / 皮顶差 %s（%s），实得 运行高 %s / 皮顶差 %s" % [
						键, str(期[0]), str(期[1]), String(期[2]), str(运行高), str(皮顶差)])
			continue
		var 最小: Vector2 = 条["最小"]
		_判(最小.y == float(条["皮高"]),
				"`%s` 的场景内最小高应是 %s（地板 = 皮高，没有边距把它顶起来），实得 %s ⇒ 腿②的阳性对照在真实场景里重演了" % [
					键, str(条["皮高"]), str(最小.y)])
		_判(运行高 == float(条["皮高"]),
				"`%s` 的裸 `CheckBox` 运行高应是皮肤高 %s（`MCheckBox.as:81-82`；控件矩形 == 皮肤矩形），实得 %s" % [
					键, str(条["皮高"]), str(运行高)] + " ⇒ 有人给某一态换回了带边距的盒，或改了字号（地板跟着声明走，见腿②）")
		_判(烘高 == 运行高, "`%s` 烘高 %s ≠ 运行高 %s ⇒ .tscn 与主题解算脱节：重烘（`开发工具/生成*场景.py`）" % [
			键, str(烘高), str(运行高)])
		_判(is_zero_approx(皮顶差), "`%s` 皮顶差 %s ≠ 0 ⇒ 皮在控件矩形里被居中挪了（27 地板的老毛病：控件比皮高）" % [
			键, str(皮顶差)])


## ── ⑤ 用户判据：同父两枚勾 行距 ≥ 原版 20 且纵叠 == 0 ────────────────
## 两两分组只在**同一个父**内做（不同父的勾各自被父裁剪/分层，不构成抢点击）。
## 竖着排（横叠 > 0 ⇒ 同一列带里）⇒ 行距必须 ≥ 20 且纵叠 0；
## 并排（行距 0）⇒ 必须横叠 0，否则两枚控件矩形左右互相咬住，也一样抢点击。
func _查行距(量: Array) -> void:
	var 组 := {}
	for 条 in 量:
		var 键 := "%s|%s" % [String(条["标"]), String(条["父"])]
		if not 组.has(键):
			组[键] = []
		(组[键] as Array).append(条)
	for 键 in 组:
		var 列: Array = 组[键]
		if 列.size() < 2:
			continue
		for i in range(列.size()):
			for j in range(i + 1, 列.size()):
				var a: Dictionary = 列[i]
				var b: Dictionary = 列[j]
				var ra: Rect2 = a["运行"]
				var rb: Rect2 = b["运行"]
				var 纵: float = maxf(0.0, minf(ra.end.y, rb.end.y) - maxf(ra.position.y, rb.position.y))
				var 横: float = maxf(0.0, minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x))
				var 距: float = absf(rb.position.y - ra.position.y)
				var 说 := "%s 同父「%s」%s↔%s 行距=%s 纵叠=%s 横叠=%s" % [
					String(a["标"]), String(a["父"]), String(a["名"]), String(b["名"]), str(距), str(纵), str(横)]
				if 距 > 0.0:
					_判(距 >= 原版行距, "行距小于原版 %s ⇒ %s（原版最小行距 20，`MCheckBox` 一行的原生占位）" % [
						str(原版行距), 说])
					_判(is_zero_approx(纵), "两枚勾的控件矩形纵向咬住 ⇒ 上一行抢走下一行的点击：%s" % 说)
				_判(横 <= 0.0 or 纵 <= 0.0, "两枚勾两个方向都叠 ⇒ 点击互相盖掉：%s" % 说)


## ── ⑥ 勾 ↔ 可点兄弟的重叠带冻结 ────────────────────────────────────
func _查重叠(量: Array) -> void:
	var 实测 := {}
	for 路: String in 场景们:
		var 标 := 路.get_file().trim_suffix(".tscn")
		var 组 := _扫一扇(路)
		if not 组.is_empty():
			实测[标] = 组
	for 标 in 重叠表:
		_判(实测.has(标), "`%s` 里原本量到的勾选框重叠带整批消失 ⇒ 场景被改过或载入失败，先确认这扇窗还在不在" % 标)
	for 标 in 实测:
		var 列: Array = 实测[标]
		var 期: Array = 重叠表.get(标, [])
		for 条 in 列:
			_判(_有(期, 条), "`%s` 出现表外的勾选框重叠：%s 的 %s ↔ %s 纵 %s 横 %s ⇒ 新增抢点击（要么拉开行距，要么挪 x）" % [
				标, 条[0], 条[1], 条[2], str(条[3]), str(条[4])])
		for 条 in 期:
			_判(_有(列, 条), "`%s` 表里的重叠带 %s 的 %s ↔ %s 量不到或数值变了（期望 纵 %s 横 %s）⇒ 有人挪了 y/行距，布局得重看" % [
				标, 条[0], 条[1], 条[2], str(条[3]), str(条[4])])


func _有(列: Array, 条: Array) -> bool:
	for 它 in 列:
		var x := 它 as Array
		if x[0] == 条[0] and x[1] == 条[1] and x[2] == 条[2] \
				and is_equal_approx(float(x[3]), float(条[3])) and is_equal_approx(float(x[4]), float(条[4])):
			return true
	return false


func _扫一扇(路: String) -> Array:
	var 出: Array = []
	var 包 := load(路) as PackedScene
	if 包 == null:
		return 出
	var 景 := 包.instantiate()
	root.add_child(景)
	var 勾们: Array = []
	_收(景, 勾们)
	for 件N in 勾们:
		var 件 := 件N as Control
		var 父: Control = 件.get_parent() as Control
		if 父 == null:
			continue
		var 序: Array = 父.get_children()
		for 兄N in 序:
			var 兄 := 兄N as Control
			if 兄 == null or 兄 == 件 or not _可点(兄):
				continue
			## 两枚都是勾 ⇒ 只在"我是这一对里树序更前的那一枚"时记一条，避免同一对记两遍。
			if 兄 is CheckBox and 序.find(兄) < 序.find(件):
				continue
			var 纵: float = minf(件.position.y + 件.size.y, 兄.position.y + 兄.size.y) - maxf(件.position.y, 兄.position.y)
			var 横: float = minf(件.position.x + 件.size.x, 兄.position.x + 兄.size.x) - maxf(件.position.x, 兄.position.x)
			if 纵 > 0.0 and 横 > 0.0:
				出.append([String(父.name), String(件.name), String(兄.name), 纵, 横])
	root.remove_child(景)
	景.free()
	return 出


## ── ⑦ 代码里 new 的勾（不在 .tscn 里，上面量不到）───────────────────
## 福袋窗两枚 = AS3 `SuccessWindow.as:125-140` 的 (82,180)/(82,201)，行距 21；
## 意志页「召唤导师」走 `输入确认弹` 的勾选型。两处高以前都写成 27（被当时的"自然高"骗了），
## 现在按 `MCheckBox.as:81-82` 的 19 烘 ⇒ 行距 21 − 19 = 2 的空隙是原版的，不是我们挤出来的。
func _查代码勾() -> void:
	var 袋 := load("res://脚本/界面/窗口/福袋窗.gd") as GDScript
	if 袋 == null:
		_报("读不到 `福袋窗.gd` ⇒ 没法核对两枚勾的行距")
		return
	var 常量: Dictionary = 袋.get_script_constant_map()
	_判(float(常量.get("勾高", 0.0)) == 皮高,
			"`福袋窗.勾高` 应是 %s（`MCheckBox.as:81-82` = upSkin 原生高），实得 %s ⇒ 27 的年代写法没清干净" % [
				str(皮高), str(常量.get("勾高", 0.0))])
	var 上: Vector2 = 常量.get("勾领取位", Vector2.ZERO)
	var 下: Vector2 = 常量.get("勾开始位", Vector2.ZERO)
	var 距: float = 下.y - 上.y
	_判(距 == 21.0, "福袋窗两枚勾的行距应是 21（AS3 `checkBox_take`@(82,180)、`checkBox_start`@(82,201)），实得 %s" % str(距))
	_判(距 >= 原版行距, "福袋窗行距 %s 应 ≥ 原版 %s ⇒ 判据（两勾实际高度与行距 ≥ 20 且不重叠）" % [
		str(距), str(原版行距)])
	_判(距 - float(常量.get("勾高", 0.0)) > 0.0,
			"福袋窗两枚勾应当**不叠**（行距 %s − 勾高 %s = %s）⇒ 实得叠了说明勾高被改大" % [
				str(距), str(常量.get("勾高", 0.0)), str(距 - float(常量.get("勾高", 0.0)))])
	var 弹 := load("res://脚本/界面/窗口/输入确认弹.gd") as GDScript
	if 弹 == null:
		_报("读不到 `输入确认弹.gd` ⇒ 没法核对勾选型那枚的高")
		return
	_判(弹_source_勾选高(弹) == 皮高, "`输入确认弹` 的 `勾选高` 应是 %s（同上 AS3），实得 %s" % [
		str(皮高), str(弹_source_勾选高(弹))])


## `勾选高` 是函数体内的局部 const，常量表照不到 ⇒ 从源码正则取（取不到就红，别静默跳过）。
func 弹_source_勾选高(弹: GDScript) -> float:
	var 源 := String(弹.resource_path)
	var f := FileAccess.open(源, FileAccess.READ)
	if f == null:
		return -1.0
	var 文 := f.get_as_text()
	var 匹 := RegEx.new()
	匹.compile("const\\s+勾选高\\s*:=\\s*([0-9.]+)")
	var m := 匹.search(文)
	return float(m.get_string(1)) if m != null else -1.0


## ── ⑧ `hover_pressed` 缺槽普查（按钮族仍缺，CheckBox 已齐）──────────
## ⚠ 必须按**控件级**解算查（`get_theme_stylebox`），不能按 `Theme.get_stylebox(槽, 族)` 直查：
##    后者不走"变体 → 基类"那条继承链，会把 `OrigListItem/disabled` 这类**本来继承到 Button 的皮**
##    误报成兜底粉盒（`_探_族按下槽.gd` 的直查与 `_探_按下粉盒.gd` 的屏幕实测对不上就是这个坑）。
##    控件级解算链 = [变体] + 类链 [Button → BaseButton → Control]，与运行期真正画的那一层一致。
## 实测结论（有头量具逐像素判，见头注释）：缺这一槽的族**不闪粉** —— 引擎在 `Button::draw()`
## 里先看 `has_theme_stylebox("hover_pressed")`，没有就退回画 `pressed`。
## ⇒ 缺槽 = 正确的原版按下外观；这条门冻结"缺着"与"补了就必须与本族 `pressed` 同皮"两种合法态。
func _查缺槽无害(主题: Theme) -> void:
	for 族 in 族按下皮:
		var 表值 := String(族按下皮[族])
		if not 主题.has_stylebox("pressed", 族):
			_判(false, "`%s/pressed` 在主题里没声明 ⇒ 按下沿引擎兜底粉盒（实色粉），对照表与主题对不上" % 族)
			continue
		var 按皮 := _皮名(主题.get_stylebox("pressed", 族))
		_判(按皮 == 表值, "`%s/pressed` 应是 %s，实得 %s ⇒ 对照表与主题对不上（改主题先改表）" % [
			族, _称(表值), _称(按皮)])
		if 族 == "CheckBox":
			## CheckBox 这一族是**反例**：缺槽会把几何撑坏（腿①②），所以要求声明且必须是空盒。
			_判(主题.has_stylebox("hover_pressed", 族), "`CheckBox/hover_pressed` 必须声明（缺 ⇒ 兜底盒边距把地板顶到 27）")
			continue
		if not 主题.has_stylebox("hover_pressed", 族):
			continue		# 缺槽 = 引擎退回 `pressed`（有头量具实测：按下那一相粉粒 0、均色就是 `pressed` 档）
		var 补 := 主题.get_stylebox("hover_pressed", 族)
		_判(not _兜底(补), "`%s/hover_pressed` 声明成了兜底粉盒 ⇒ 悬停+按住那一态画实色粉" % 族)
		_判(_皮名(补) == 表值,
				"`%s/hover_pressed` 声明了但与本族 `pressed` 不同皮：应是 %s，实得 %s ⇒ 按住那一态不再等于原版" % [
					族, _称(表值), _称(_皮名(补))])
	## `disabled` 只在**声明了**的时候判：没声明的族运行期沿基类 `Button` 继承到 `按钮.png`
	## （有头量具禁用那一相实测：列表项解算到 `按钮.png`、粉粒 0），直查 `.tres` 照不到那条继承。
	for 族 in 族按下皮:
		if 主题.has_stylebox("disabled", 族):
			_判(not _兜底(主题.get_stylebox("disabled", 族)),
					"`%s/disabled` 声明成了兜底粉盒 ⇒ 置灰那一态画实色粉" % 族)


## 引擎兜底粉盒 = "要的样式盒不存在"那个标记（`ThemeDB.get_default_style()` 的 #FF5D5D）。
func _兜底(盒: StyleBox) -> bool:
	var 平 := 盒 as StyleBoxFlat
	return 平 != null and 平.bg_color == 粉盒色


func _称(皮名: String) -> String:
	return 皮名 if 皮名 != "" else "（空盒）"


## 样式盒背后那张皮的文件名；空盒/无图 → `""`。
func _皮名(盒: StyleBox) -> String:
	var 纹 := 盒 as StyleBoxTexture
	if 纹 == null:
		return ""
	var 图: Texture2D = 纹.texture
	if 图 == null:
		return ""
	return String(图.resource_path.get_file())


func _边名(边: int) -> String:
	match 边:
		SIDE_LEFT:
			return "左"
		SIDE_TOP:
			return "上"
		SIDE_RIGHT:
			return "右"
		SIDE_BOTTOM:
			return "下"
	return str(边)


func _可点(件: Control) -> bool:
	if 件.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	return 件 is Button or 件 is LineEdit


func _收(节: Node, 出: Array) -> void:
	for 子 in 节.get_children():
		if 子 is CheckBox:
			出.append(子)
		if 子 is Control:
			_收(子, 出)
