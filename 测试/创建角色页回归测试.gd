extends SceneTree

## 创建角色页（原版独立 SWF `MainCreateChar.swf` 里的 `CreateCharWindow3`，249×410）离线回归门。
##
## 这一页和别的页不一样：**它是空号唯一出得去的路**。上一轮工程里空号被当成"一枚空角色"
## 塞进列表 ⇒ `select_character(0)` 直接 return ⇒ 界面永远停在"正在读取角色"，既不报错也不提示。
## 所以判据分两半：A 段只读盘（防手改场景/皮/文案），B 段真的 instantiate（防"画得出但点不动"）。
##
## 它防的十二种复发（都带出处）：
##   A1 逐件矩形漂了 —— `.tscn` 文本 vs `数据/界面/创建角色_尺寸.json` vs **门里独立硬编码的 AS3 锚点**，
##      三份互比。只比前两份 = 生成器和数据一起漂就永远绿（这条工程里踩过"两份一起错"）。
##   A2 四格的 job/gender 被"顺手改成 1/2/3/4 顺序号" —— 原版 `CreateCharWindow3.as:250-278` 是
##      火100/男、水200/女、**风400/女、雷300/男**（`:32-38` `NINJA_LIGHTING=300`、`NINJA_WIND=400`）。
##   A3 `.tscn` 里出现**非 ASCII 的 `id=`** —— Godot 4.7 把它直接喂 `Resource::set_scene_unique_id`，
##      每条 load 报一次 `The scene unique ID must contain only letters, numbers, and underscores`
##      （本轮实测这份场景报了 10 条）。
##   A4 皮字面量缺一档：四格各三档 12 张、随机钮四态 4 张、转圈 **70 帧**一张不能少
##      （`CreateButtonMovie` 的 frameCount = 70，SWF 头 frameRate = 24）。
##   A5 校验六条的**顺序**与文案 —— 原版 `createCharFail():145-184` 判序是
##      ①宽度>76 ②空 ③正则 ④长度>12 ⑤长度<2；文案逐字来自 `en_US$createChar_properties.as`。
##   A6 随机钮四档字色（`#fcf49c/#ffffc3/#acadb2/#939393`）被拿 modulate 冒充。
##   A7 手型光标丢了 —— 原版 `buttonMode = useHandCursor = true`。
##   A8 「编辑器 == 运行期」：烘进场景的 `texture_normal/hover`、`max_length = 12`、`mouse_filter`、
##      名标签那六个字都要从**文本**读（读运行期值等于自证）。
##   A9 随机选格的阈值分布（`randomChar():199-225`：r>=70 格3、>=40 格2、>=20 格4、else 格1）
##      —— 被"优化"成 `randi()%4` 就红。
##   B1 选中那枚必须把 `texture_hover` 也指回"选中"图（`CharBox2.as:56-66` 悬停只在未选中时生效），
##      且换格后旧格要回落到未选/悬停两档（停在悬停档 = "上一枚还亮着"）。
##   B2 悬停说明（`CreatCharToolTip`）：文本 = 该职业描述、移开收掉。
##      ⚠ 曾经 `int(节点)` 把 `_格悬停` 从第一行打死 ⇒ 提示全浮不出来而门是绿的。
##   B3 转圈的可见性：**开窗就在转**（原版 MovieClip 建出来 visible=true，`mouseDownHandler:121-124`
##      藏、`mouseUpHandler:123-127` 显）⇒ 门钉"场景里不许出现 visible = false"，
##      谁"顺手初始隐藏"就把这条改红。
##
## ⚠ 三条硬口径：无头跑；不落存档（跑前记 `user://玩家数据.json` 字节、跑完断言没变）；
##   源文本断言只比**单行**（本工程 .gd 一度被写成 CRLF，多行字面量断言会永远对不上）。
##   全文件**不用正则**：往盘上写 `\[` 这类"字面反斜杠"会被工具吃掉一层，
##   换成 `char(34)/char(10)` + find/substr 手工切 —— 少一类静默坏法。
##
## 运行：Godot --headless --path . --script res://测试/创建角色页回归测试.gd

const 场景路 := "res://场景/界面/窗口/创建角色/创建角色窗.tscn"
const 尺寸路 := "res://数据/界面/创建角色_尺寸.json"
const 控制器路 := "res://脚本/界面/窗口/创建角色窗.gd"
const 皮目录 := "res://素材/界面/原版窗口/创建角色"
const 容差 := 0.02
const 转圈帧数 := 70
const 转圈帧率 := 24.0

## —— 门里独立硬编码的 AS3 锚点（第三份真值，不许拿它去"对齐"前两份）——
const 窗宽 := 249.0
const 窗高 := 410.0
const 格宽 := 111.0
const 格高 := 136.0
const 锚 := {
	"窗口底": [0.0, 0.0, 249.0, 410.0],
	"标题": [88.5, 5.0, 72.0, 19.0],
	"面板底": [8.0, 32.0, 233.0, 330.0],
	"职业格1": [13.0, 37.0, 111.0, 136.0],
	"职业格2": [125.0, 37.0, 111.0, 136.0],
	"职业格3": [13.0, 174.0, 111.0, 136.0],
	"职业格4": [125.0, 174.0, 111.0, 136.0],
	"名标签": [56.0, 314.0, 78.0, 19.0],
	## 输入栏 = 原版那张 CTextInput_background 的矩形（:288-291）；文字内缩 6/1/6/1 在
	## sb_input 的 content_margin 里（= TextField 的 :300-304 那两个偏移与 −12 宽）。
	## ⚠ 这里**没有**「输入底」那一件：原版是底 + 无底 TextField 两个兄弟，Godot 的 LineEdit
	##   一定要画自己那份皮 ⇒ 兄弟 Panel 必然互相盖（2026-10-10 被打回「不是用他自带的输入栏，
	##   是你自己做了一个栏覆盖在上面」），合成一件才是原版那个样子。
	"角色名输入": [46.0, 335.0, 125.0, 21.0],
	"随机钮": [173.0, 335.0, 34.0, 22.0],
	"进入游戏": [67.0, 368.0, 115.0, 34.0],
	## 原版 `CreateCharWindow3.as:220-224` 摆的是**符号注册点**：`_movie.x = 进入钮.x + 80`、
	## `_movie.y = 进入钮.y + 18` ⇒ 注册点要落在窗口坐标 (147, 386)。
	## ⚠ 注册点**不在导出画布正中**（2026-10-10 用户报"特效偏移"的根因：旧写法按正中摆 ⇒
	##   整颗往右 21.55px、往下 4.05px，光扫跑到钮右边去了）。注册点像素由符号 36 的子件包围盒算：
	##   #28/#35 光条自身 x∈[−23.35,23.3]、y∈[−23.75,23.75]，最左帧放在 x=−89.7、最右放在 x=+46.6
	##     ⇒ 符号坐标 minX = −113.05、maxX = +69.95 ⇒ 宽 183.0 = 画布宽 ✓
	##     ⇒ 注册点像素 x = 113.05（不是 91.5）
	##   y：光条放在 y=−4.3 ⇒ minY = −28.05、maxY = +19.45 ⇒ 高 47.5 ≈ 画布 48 ✓
	##     ⇒ 注册点像素 y = 28.05（不是 24）
	##   ⇒ 节点左上 = (147 − 113.05, 386 − 28.05) = (33.95, 357.95)。
	## 反向校验（这才是"摆对了"的证据）：钮形高光 #27（自身 x∈[−78.15,30.45] y∈[−21.05,10.45]
	##   放在 (0.65,3) ⇒ 画布 x 35.55..144.15、y 10..41.5）换算到窗口 = 69.5..178.1 × 367.95..399.45
	##   —— 与钮矩形 67..182 × 368..402 四边各内缩 2.5~4px，光扫本来就该盖在钮身上。
	"提交转圈": [33.95, 357.95, 183.0, 48.0],
}
## 七块九宫格的边距（左/上/右/下，像素）—— 独立抄的第三份真值，出处 = MainCreateChar.swf 的
## DefineScalingGridTag splitter(twips ÷ 20) 与各张导出图的原生尺寸：
##   sb_win       符号15 X[960,4539] Y[585,6140]  原生 275×325
##   sb_panel     符号22 X[150,4920] Y[135,4095]  原生 253×212
##   sb_input     符号18 X[125,2365] Y[100,300]   原生 125×21
##   sb_rand_*    符号74/77/80/83 X[143,994]/[143,995]/[140,992]/[142,998]
##                Y[143,300]/[145,303]/[140,303]/[140,300]  原生 57×22
## ⚠️ 这条判据是 2026-10-10 补的：生成器原先拿一条「Xmin…Xmax…Ymin…Ymax」顺序的正则去解，
##    而 ffdec 写的是 `Xmax Xmin Ymax Ymin` ⇒ `.*?` 跨到**别的 tag** 凑数，七块全被抓坏
##    （上恒 0、右/下负到 −128）。负边距不报错，等于整幅拉伸，看着就是自己盖了一块板。
const 皮边 := {
	"sb_win": [48.0, 29.25, 48.05, 18.0],
	"sb_panel": [7.5, 6.75, 7.0, 7.25],
	"sb_input": [6.25, 5.0, 6.75, 6.0],
	"sb_rand_normal": [7.15, 7.15, 7.3, 7.0],
	"sb_rand_hover": [7.15, 7.25, 7.25, 6.85],
	"sb_rand_pressed": [7.0, 7.0, 7.4, 6.85],
	"sb_rand_disabled": [7.1, 7.0, 7.1, 7.0],
}
## 每块的 content_margin（六块必须是 0 —— 不写会取 texture_margin 把件顶宽；
## 唯一例外是输入框那块：6/1/6/1 就是原版 TextField 相对底的内缩）
const 皮内缩 := {"sb_input": [6.0, 1.0, 6.0, 1.0]}


## 四格表：job/gender 逐字照 `CreateCharWindow3.as:28-38,250-278`；音 = 原版四段 Sound_Select_*
const 格表 := [
	{"名": "职业格1", "job": 100, "gender": 1, "图": "格_火男", "音": "选中火"},
	{"名": "职业格2", "job": 200, "gender": 2, "图": "格_水女", "音": "选中水"},
	{"名": "职业格3", "job": 400, "gender": 2, "图": "格_风女", "音": "选中风"},
	{"名": "职业格4", "job": 300, "gender": 1, "图": "格_雷男", "音": "选中雷"},
]
## 随机钮四档字色（`MButton3.as:69-74` 那一族；场景里是烘死的 theme_override_colors）
const 字色表 := {"normal": "Color(0.988235, 0.956863, 0.611765, 1)",
		"hover": "Color(1, 1, 0.764706, 1)",
		"pressed": "Color(0.701961, 0.678431, 0.698039, 1)",
		"disabled": "Color(0.576471, 0.576471, 0.576471, 1)"}
## 逐字文案（`en_US$createChar_properties.as` + `createCharFail()` 四支红字）
const 案 := {
	"名": "请输入角色名",
	"太长": "你输入的角色名太长，请重新输入！",
	"空": "角色名不能为空",
	"非法": "角色名不能以数位开头或含有非法字元",
	"超长": "角色名长度不能大于12",
	"超短": "角色名长度不能小于2",
	"确定": "确定",
}

var 红数 := 0
var 日志: Array[String] = []
var 文 := ""			# .tscn 全文
var 源码 := ""			# 控制器全文
var 尺寸: Dictionary = {}
var 件 := {}			# 节点名 -> {"父":…, "类":…, "属":{属性:值}}
var 资源号 := {}		# id -> {"类":…, "路":…}
var 窗: Control
var 存档前 := ""
var 引 := char(34)		# 双引号：从 char() 拿，别在源码里写 \ 转义（会被吃一层）
var 换 := char(10)		# 换行：同上


var 总 := 0


func _记(过: bool, 说明: String) -> void:
	总 += 1
	if not 过:
		红数 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 说明])


func _等帧(n: int) -> void:
	for _i in n:
		await process_frame


func _读(路: String) -> String:
	return FileAccess.get_file_as_string(路)


func _数(一: float, 二: float) -> bool:
	return absf(一 - 二) <= 容差


## 夹在 前…后 之间的那段；查不到返回 ""
func _夹(从: String, 前: String, 后: String) -> String:
	var a := 从.find(前)
	if a < 0:
		return ""
	var s := a + 前.length()
	var b := 从.find(后, s)
	return 从.substr(s, b - s) if b >= 0 else 从.substr(s)

## 原版 addChild 序（`CreateCharWindow3.as:130-160` createView + `:200-224`）⇒ 场景里的文档序
const 层栈 := ["创建角色", "背景", "窗口", "窗口底", "标题", "面板底",
		"职业格1", "职业格2", "职业格3", "职业格4", "名标签",
		"角色名输入", "随机钮", "进入游戏", "提交转圈"]
## 尺寸表里的键名与场景节点名有两处不同名（生成器就这么定的，门里照抄一份）
const 表键 := {"角色名输入": "输入框"}


func _initialize() -> void:
	call_deferred("_跑")
	call_deferred("_看门狗")


func _存档字节() -> String:
	var 路 := OS.get_user_data_dir() + "/玩家数据.json"
	if not FileAccess.file_exists(路):
		return "无"
	return str(FileAccess.get_file_as_string(路).length())


func _跑() -> void:
	root.size = Vector2i(1209, 970)		# 无头也要钉视口：B 段要真 push_input
	存档前 = _存档字节()
	文 = FileAccess.get_file_as_string(场景路)
	源码 = FileAccess.get_file_as_string(控制器路)
	_记(文.length() > 2000, "场景文本读到了（%d 字节）" % 文.length())
	_记(源码.length() > 2000, "控制器文本读到了（%d 字节）" % 源码.length())
	var 解 = JSON.parse_string(FileAccess.get_file_as_string(尺寸路))
	if 解 is Dictionary:
		尺寸 = 解
	_记(not 尺寸.is_empty(), "尺寸表是 Dictionary")
	_切文本()
	_A_层栈()
	_A_矩形()
	_A_四格表()
	_A_皮与帧()
	_A_边距()
	_A_文案与判序()
	_A_烘值()
	_D_登录接线()
	await _B_开窗()
	await _B_换格()
	## ⚠ `_填描述()` 以前**从没被调过** ⇒ `描述真值` 是空数组 ⇒ `_B_悬停` 在
	##   `描述真值[序]` 那一句抛 `Out of bounds get index '1'`、当场打断自己
	##   （§3.245：调用处照旧往下跑，门照样绿）。也就是说"悬停说明 == 原版四条逐字"
	##   这条**从来没计过数**，不是"通过了很久"。
	_填描述()
	_记(描述真值.size() == 4, "四条职业描述拼好了（实得 %d 条）—— 悬停那条判据的前提" % 描述真值.size())
	await _B_悬停()
	await _B_六条校验()
	await _B_弹框()
	_尾()


## 手工切 .tscn（不用正则：字面反斜杠在这套工具链里会被吃一层，见 docstring）
func _切文本() -> void:
	var 序: Array[String] = []
	var 片 := 文.split(换 + "[node ")
	for i in range(1, 片.size()):
		var 一: String = 片[i]
		var 头终 := 一.find(换)
		var 名 := _夹(一, "name=" + 引, 引)
		var 体 := 一.substr(头终 + 1) if 头终 >= 0 else ""
		var 属 := {}
		for 行 in 体.split(换):
			var k := 行.find(" = ")
			if k > 0:
				属[行.substr(0, k)] = 行.substr(k + 3)
		件[名] = {"父": _夹(一, "parent=" + 引, 引), "类": _夹(一, "type=" + 引, 引), "属": 属}
		序.append(名)
	层栈实测 = 序
	for 行 in 文.split(换):
		if 行.begins_with("[ext_resource") or 行.begins_with("[sub_resource"):
			var 号 := _夹(行, "id=" + 引, 引)
			资源号[号] = {"类": _夹(行, "type=" + 引, 引),
					"路": _夹(行, "path=" + 引, 引),
					"外部": 行.begins_with("[ext_resource")}
			if not _是ASCII(号):
				坏号.append(号)


var 层栈实测: Array[String] = []
var 坏号: Array[String] = []


func _是ASCII(s: String) -> bool:
	for c in s.length():
		var v := s.unicode_at(c)
		if not ((v >= 48 and v <= 57) or (v >= 65 and v <= 90) or (v >= 97 and v <= 122) or v == 95):
			return false
	return true


func _件路(Ext号: String) -> String:
	return str((资源号.get(Ext号, {}) as Dictionary).get("路", "")) if Ext号 != "" else ""
func _A_层栈() -> void:
	_记(层栈实测.size() == 层栈.size(),
			"场景节点 %d 个（门里期望 %d：根 + 背景 + 窗口 + 窗内 12 件）" % [层栈实测.size(), 层栈.size()])
	var 差: Array[String] = []
	for i in min(层栈实测.size(), 层栈.size()):
		if 层栈实测[i] != 层栈[i]:
			差.append("%d:%s≠%s" % [i, 层栈实测[i], 层栈[i]])
	_记(差.is_empty(), "文档序 == 原版 addChild 序（差处 %s）" % str(差))
	var 父错: Array[String] = []
	for 名 in ["窗口底", "标题", "面板底", "职业格1", "职业格2", "职业格3", "职业格4",
			"名标签", "角色名输入", "随机钮", "进入游戏", "提交转圈"]:
		if str((件.get(名, {}) as Dictionary).get("父", "")) != "窗口":
			父错.append("%s→%s" % [名, str((件.get(名, {}) as Dictionary).get("父", "?"))])
	_记(父错.is_empty(), "窗内 12 件的 parent= 全是「窗口」（写错就静默掉到根 (0,0)）%s" % str(父错))
	_记(坏号.is_empty(), "所有资源 id 都是 ASCII（非 ASCII 会被 4.7 的 set_scene_unique_id 每条报一次错）%s" % str(坏号))


## 一件在场景里写成的矩形（相对父节点）
func _矩形(名: String) -> Array:
	var 属: Dictionary = (件.get(名, {}) as Dictionary).get("属", {}) as Dictionary
	var 左 := float(str(属.get("offset_left", "0")))
	var 上 := float(str(属.get("offset_top", "0")))
	var 右 := float(str(属.get("offset_right", "0")))
	var 下 := float(str(属.get("offset_bottom", "0")))
	return [左, 上, 右 - 左, 下 - 上]


func _A_矩形() -> void:
	for 名 in 锚.keys():
		var 实 := _矩形(名)
		var 望: Array = 锚[名]
		var 好 := _数(实[0], 望[0]) and _数(实[1], 望[1]) and _数(实[2], 望[2]) and _数(实[3], 望[3])
		_记(好, "%s 矩形 == 门里 AS3 锚点 %s（场景实写 %s）" % [名, str(望), str(实)])
		var 表名 := str(表键.get(名, 名))
		var 条: Dictionary = ((尺寸.get("件", {}) as Dictionary).get(表名, {}) as Dictionary)
		if not 条.is_empty() and 条.has("x"):
			var 二 := _数(float(str(条.get("x"))), 实[0]) and _数(float(str(条.get("y"))), 实[1])
			if 条.has("w"):
				二 = 二 and _数(float(str(条.get("w"))), 实[2])
			if 条.has("h"):
				二 = 二 and _数(float(str(条.get("h"))), 实[3])
			_记(二, "%s 场景 == 尺寸表（两份一起漂才会漏，所以外面还有一层 AS3 锚点）" % 名)
	var 根属: Dictionary = (件.get("创建角色", {}) as Dictionary).get("属", {}) as Dictionary
	var 尺 := str(根属.get("custom_minimum_size", ""))
	_记(尺 == "Vector2(249, 410)",
			"根 custom_minimum_size = Vector2(249, 410)（实际 %s）—— 空的 _记 等于没判，所以打实际值" % 尺)


func _A_四格表() -> void:
	var 表: Dictionary = 尺寸.get("件", {}) as Dictionary
	for 定 in 格表:
		var 名 := str(定["名"])
		var 条: Dictionary = 表.get(名, {}) as Dictionary
		_记(int(条.get("job", -1)) == int(定["job"]) and int(条.get("gender", -1)) == int(定["gender"])
				and str(条.get("音", "")) == str(定["音"]) and str(条.get("未选", "")).begins_with(str(定["图"])),
				"%s 的 job/gender/音/图 == 原版表（%s/%s %s）实际 %s/%s %s" % [
					名, str(定["job"]), str(定["gender"]), str(定["音"]),
					str(条.get("job")), str(条.get("gender")), str(条.get("音"))])
		var 属: Dictionary = (件.get(名, {}) as Dictionary).get("属", {}) as Dictionary
		var 路 := _件路(_夹(str(属.get("texture_normal", "")), "ExtResource(" + 引, 引))
		var 悬 := _件路(_夹(str(属.get("texture_hover", "")), "ExtResource(" + 引, 引))
		_记(路.ends_with(str(定["图"]) + "_未选.png") and 悬.ends_with(str(定["图"]) + "_悬停.png"),
				"%s 烘的是 %s_未选/_悬停 两张（编辑器视图 == 运行期未选中态）实际 %s|%s" % [名, str(定["图"]), 路, 悬])
	_记(str(((表.get("职业格1", {}) as Dictionary).get("说明键", ""))) == "ZHIYE_DESC_1"
			and str(((表.get("职业格2", {}) as Dictionary).get("说明键", ""))) == "ZHIYI_DESC_2",
			"描述键名照抄原版的拼写不一致（1 是 ZHIYE、2 之后是 ZHIYI）—— 顺手统一就红")


func _A_皮与帧() -> void:
	var 缺: Array[String] = []
	var 皮数 := 0
	for 号 in 资源号.keys():
		var 信: Dictionary = 资源号[号] as Dictionary
		var 路 := str(信.get("路", ""))
		if not bool(信.get("外部", false)) or not 路.begins_with("res://素材/"):
			continue
		皮数 += 1
		if not FileAccess.file_exists(路):
			缺.append(路)
	_记(缺.is_empty(), "场景引的 %d 张皮/音全在盘上（缺则白一块且不报错）%s" % [皮数, str(缺)])
	var 三档 := 0
	var 帧 := 0
	for 号 in 资源号.keys():
		var 路 := str((资源号[号] as Dictionary).get("路", ""))
		if 路.begins_with(皮目录) and 路.ends_with(".png"):
			if 路.get_file().begins_with("格_") and ("_未选." in 路 or "_悬停." in 路 or "_选中." in 路):
				三档 += 1
			if "提交转圈/" in 路:
				帧 += 1
	_记(三档 == 8, "场景烘了四格各两档（未选/悬停）= 8 张（实际 %d；选中那档运行期才换）" % 三档)
	var 盘上 := 0
	for 态 in ["_未选", "_悬停", "_选中"]:
		for 定 in 格表:
			if FileAccess.file_exists("%s/%s%s.png" % [皮目录, str(定["图"]), 态]):
				盘上 += 1
	_记(盘上 == 12, "盘上四格三档 12 张齐（缺一张 = 点上去换皮失败，运行期静默回到未选）实际 %d" % 盘上)
	_记(帧 == 转圈帧数, "转圈 70 帧逐条 ext_resource（实际 %d；少帧=运行期 AnimatedTexture 空转）" % 帧)
	_记("frames = %d" % 转圈帧数 in 文, "AnimatedTexture 的 frames == 70")
	## ↓ 2026-10-10：用户报「进入游戏按钮的特效帧率很低很低」。量具有头实测（开发工具/量转圈帧率.gd）
	##   连拍 36 个引擎帧 ⇒ 画面变化 **0 次** = 每秒才走一帧。根因是 4.7 的 AnimatedTexture
	##   **没有 fps、也没有 loop 属性**（get_property_list 只有 frames/current_frame/pause/
	##   one_shot/speed_scale/frame_N/texture/frame_N/duration），而 `frame_N/duration` 的单位是**秒**
	##   ⇒ 以前那行 `fps = 24` 被静默丢掉，每帧时长就是字面的 1.0 秒。**旧门钉的是「文里有 fps = 24
	##   这行字」—— 一行 Godot 根本不认的死属性，钉它等于没钉**（这条假绿一起收）。
	_记(not ("fps = " in 文),
			"场景里**没有** `fps =` 这一行（4.7 的 AnimatedTexture 没这个属性，写了静默丢 = 骗过旧门）")
	_记(not ("loop = true" in 文), "同理没有 `loop =`（one_shot 默认 false 就是循环）")
	var 时长数 := 0
	var 时长错: Array[String] = []
	for 行 in 文.split(换):
		if 行.begins_with("frame_") and 行.contains("/duration = "):
			时长数 += 1
			var 值 := float(行.substr(行.find("/duration = ") + 12))
			if absf(值 - 0.041667) > 0.0005:
				时长错.append("%s→%s" % [行.substr(0, 行.find("=")), str(值)])
	_记(时长数 == 转圈帧数 and 时长错.is_empty(),
			"70 帧逐条 duration = 1/24 秒（0.041667，一圈 70/24 ≈ 2.917 秒）实际 %d 条，错 %s"
			% [时长数, str(时长错)])
	for 定 in 格表:
		var 音 := "%s/%s.mp3" % [皮目录, str(定["音"])]
		_记(FileAccess.file_exists(音), "点格子的音效在盘上：%s" % 音.get_file())
	for 槽 in 字色表.keys():
		_记(str(字色表[槽]) in 文, "随机钮 %s 档字色是烘死的真值（不是 modulate 冒充）" % 槽)


## 一块 StyleBoxTexture 的属性（按子资源 id 现查 .tscn 文本；门只读盘上的字，不读运行期值）
func _子块(资号: String) -> Dictionary:
	var 头 := "[sub_resource type=" + 引 + "StyleBoxTexture" + 引 + " id=" + 引 + 资号 + 引 + "]"
	var a := 文.find(头)
	if a < 0:
		return {}
	var 体 := 文.substr(a + 头.length())
	var b := 体.find(换 + "[")
	if b >= 0:
		体 = 体.substr(0, b)
	var 属 := {}
	for 行 in 体.split(换):
		var k := 行.find(" = ")
		if k > 0:
			属[行.substr(0, k)] = 行.substr(k + 3)
	return 属


## 七块九宫格逐块对 splitter 真值。这条是 2026-10-10 补的：生成器原先按
## 「Xmin→Xmax→Ymin→Ymax」的顺序抓，而 ffdec 写的是 `Xmax Xmin Ymax Ymin` ⇒ `.*?` 跨到
## 别的 tag 去凑数，七块全被抓坏（上恒 0、右/下负到 −128）—— 负边距不报错，在 Godot 里
## 就是整幅拉伸，看上去像"自己拿一块板盖在原版皮上"。
func _A_边距() -> void:
	var 坏: Array[String] = []
	var 负: Array[String] = []
	for 号 in 皮边.keys():
		var 属: Dictionary = _子块(号)
		var 望: Array = 皮边[号]
		if 属.is_empty():
			坏.append(号 + "(查无此块)")
			continue
		var 实: Array = [float(str(属.get("texture_margin_left", ""))), float(str(属.get("texture_margin_top", ""))),
				float(str(属.get("texture_margin_right", ""))), float(str(属.get("texture_margin_bottom", "")))]
		var 好 := true
		for i in 4:
			if not _数(float(实[i]), float(望[i])):
				好 = false
		if not 好:
			坏.append("%s 实%s 望%s" % [号, str(实), str(望)])
		for v in 实:
			if float(v) < 0.0:
				负.append("%s=%s" % [号, str(v)])
	_记(坏.is_empty(), "七块九宫格边距逐块 == splitter 真值（左/上/右/下 像素）坏 %s" % str(坏))
	_记(负.is_empty(), "没有一条边距是负数（负数不报错 = 整幅拉伸，就是这次被打回的成因）%s" % str(负))
	for 号 in 皮内缩.keys():
		var 属2: Dictionary = _子块(号)
		var 望2: Array = 皮内缩[号]
		var 键序: Array = ["content_margin_left", "content_margin_top",
				"content_margin_right", "content_margin_bottom"]
		var 齐 := true
		var 实2: Array = []
		for i in 4:
			实2.append(float(str(属2.get(str(键序[i]), ""))))
			if not _数(float(实2[i]), float(望2[i])):
				齐 = false
		_记(齐, "%s 的文字内缩 == 原版 TextField 相对底的 6/1/6/1（:300-304）实际 %s" % [号, str(实2)])


func _A_文案与判序() -> void:
	for 键 in 案.keys():
		if 键 == "确定":
			continue
		_记(str(案[键]) in 源码, "校验文案逐字：%s" % 案[键])
	_记("const 名字最长 := 12" in 源码 and "const 名字最短 := 2" in 源码 and "const 名字最宽 := 76.0" in 源码,
			"三条常量 = 12 / 2 / 76.0（`CreateCharWindow3.as:22-26`）")
	var 起 := 源码.find("func _点进入")
	var 止 := 源码.find("func _收到建角")
	_记(起 >= 0 and 止 > 起, "取到 _点进入 的函数体")
	if 起 >= 0 and 止 > 起:
		var 段 := 源码.substr(起, 止 - 起)
		var 序: Array = ["_弹(提示太长)", "_弹(提示空)", "_弹(提示非法", "_弹(提示超长", "_弹(提示超短"]
		var 上一 := -1
		var 顺 := true
		for s in 序:
			var 此 := 段.find(str(s))
			顺 = 顺 and 此 > 上一
			上一 = 此
		_记(顺, "六条校验的**判序** = 宽度→空→正则→>12→<2（原版 createCharFail 就是这个顺序，重排会换文案）")
	_记("if r >= 70.0:" in 源码 and "elif r >= 40.0:" in 源码 and "elif r >= 20.0:" in 源码,
			"随机选格阈值 70/40/20 照抄（`randomChar():199-225`，不是均匀四选一）")

## 四条职业描述逐字（`en_US$createChar_properties.as` 的 ZHIYE_DESC_1 + ZHIYI_DESC_2/3/4）。
## 原版用 `<br/>` 断三行 ⇒ 这里拆成三段常量，运行期再拼（成员初始化器里不许调 chr()/函数）。
const 描一 := ["以宇智波家为代表的火遁术，可使用火系忍术对敌人造成巨大伤害。",
		"水孕育出的元素精华水遁，利用无所不在的水分子释放出伤害巨大的忍术。",
		"以风属性查克拉为基质的风遁术，将有如刀刃一般的查克拉，把敌人撕裂切碎。",
		"雷属性查克拉释放出的雷遁术，以能量巨大的雷系忍术给敌人带来致命创伤。"]
const 描二 := ["基本武器：忍杖", "基本武器：吹矢", "基本武器：扇子", "基本武器：太刀"]
const 描三 := ["流派忍术：火遁•烈焰斩、火遁•凤仙花之术、火遁•火龙炎弹",
		"流派忍术：水遁•水之刃、水遁•水龙弹、水遁•大瀑布术",
		"流派忍术：风遁•螺旋丸、风遁•真空玉、风遁•风杀阵",
		"流派忍术：雷遁•雷切、雷遁•雷球术、雷遁•千鸟流"]
var 描述真值: Array = []


func _填描述() -> void:
	描述真值 = []
	for i in 描一.size():
		描述真值.append(str(描一[i]) + 换 + str(描二[i]) + 换 + str(描三[i]))


func _A_烘值() -> void:
	var 属: Dictionary
	属 = (件.get("角色名输入", {}) as Dictionary).get("属", {}) as Dictionary
	_记(str(属.get("max_length", "")) == "12", "输入框烘了 max_length = 12（运行期截断，不是弹框才管）实际 %s" % str(属.get("max_length")))
	## ↓ 输入栏这三条是 2026-10-10 被打回「输入角色名应该用他自带的输入栏，不是你做一个栏盖在上面」
	## 之后补的。根因有两条，各钉一条：① 那块自造的兄弟 Panel；② 边距被抓歪（见 皮边 / _A_边距）。
	_记(not 件.has("输入底"),
			"场景里**没有**「输入底」那一件 —— 原版是底 + 无底 TextField，Godot 的 LineEdit 必画自己的皮，"
			+ "再加一块兄弟底就是「自己做个栏盖上去」（被打回的原话），谁加回来这条就红")
	var 常 := _夹(str(属.get("theme_override_styles/normal", "")), "SubResource(" + 引, 引)
	var 焦 := _夹(str(属.get("theme_override_styles/focus", "")), "SubResource(" + 引, 引)
	_记(常 == "sb_input" and 焦 == "sb_input",
			"输入框把原版 CTextInput_background 挂成**自己的** normal+focus 皮（两档同一张 = 原版聚焦不换底）实际 %s|%s" % [常, 焦])
	_记(str(属.get("alignment", "")) == "0",
			"输入框左对齐：原版 TextFormat 只给 color/size（:295-298），没给 align ⇒ 居中是自造（实际 %s）" % str(属.get("alignment")))
	_记(str(属.get("theme_override_colors/font_color", "")) == "Color(1, 1, 1, 1)",
			"输入框字色 == 16777215（:296）实际 %s" % str(属.get("theme_override_colors/font_color", "")))
	属 = (件.get("名标签", {}) as Dictionary).get("属", {}) as Dictionary
	_记(str(属.get("text", "")) == 引 + str(案["名"]) + 引,
			"名标签烘的文本 == CREATE_CHAR_TIP_INPUT_NAME（`CreateCharWindow3.as:284`）实际 %s" % str(属.get("text")))
	_记(str(属.get("material", "")) == "SubResource(" + 引 + "sm_grad" + 引 + ")",
			"名标签挂渐变材质（原版 GradientTextField 是上下两色）")
	_记("shader_parameter/box_height = 19.0" in 文, "渐变材质的 box_height == 19.0（= 名标签盒高）")
	属 = (件.get("提交转圈", {}) as Dictionary).get("属", {}) as Dictionary
	_记(not 属.has("visible"),
			"转圈**没有**被初始隐藏 —— 原版 MovieClip 建出来就在转（`:220-224`），"
			+ "mouseDown 才藏、mouseUp 再显（`:121-127`）⇒ 谁顺手写 visible=false 这条就红")
	_记(str(属.get("mouse_filter", "")) == "2", "转圈 mouse_filter = IGNORE（原版 mouseEnabled = false）")
	属 = (件.get("背景", {}) as Dictionary).get("属", {}) as Dictionary
	_记(str(属.get("anchor_right", "")) == "1.0" and str(属.get("expand_mode", "")) == "0",
			"背景铺满父节点且尺寸听锚点（expand_mode=1 是 FIT_WIDTH ⇒ 背景只剩一小块，踩过）")
	var 手数: Array[String] = []
	for 名 in ["职业格1", "职业格2", "职业格3", "职业格4", "随机钮", "进入游戏"]:
		var 势: Dictionary = (件.get(名, {}) as Dictionary).get("属", {}) as Dictionary
		if str(势.get("mouse_default_cursor_shape", "")) != "2":
			手数.append(名)
	_记(手数.is_empty(), "六颗可点件烘了手型光标（原版 buttonMode=useHandCursor）缺 %s" % str(手数))
	_记(文.count("content_margin_") == 28,
			"七块 StyleBoxTexture 都显式写了 content_margin（六块 0，输入框那块 6/1/6/1 = 原版文字内缩；"
			+ "不写会取 texture_margin ⇒ 钮被四条边距顶宽）实际 %d 行"
			% 文.count("content_margin_"))


func _B_开窗() -> void:
	var 包 = load(场景路)
	_记(包 != null, "创角场景能 load（非 ASCII id / 缺皮都会在这儿炸）")
	if 包 == null:
		_记(false, "B 段（换格/悬停/六条校验/弹框）整段没跑 —— 场景没 load 出来，"
				+ "上面那条红才是根因；总条数会因此变少，别把它误读成\"没抓到\"")
		return
	窗 = (包 as PackedScene).instantiate() as Control
	_记(窗 != null, "能实例化成 Control")
	if 窗 == null:
		return
	root.add_child(窗)
	await _等帧(6)
	var 内: Node = 窗.get_node("窗口")
	_记(内.get_child_count() == 12, "窗内 12 件（运行期子节点数，与场景文档序那条互相独立）实际 %d" % 内.get_child_count())
	_记(窗.get_rect().size.x >= 窗宽, "运行期根撑满了视口（原版 resize():186-196 把 _bg 拉满舞台）")
	var 当: Dictionary = 窗.get("_当前")
	_记(not 当.is_empty(), "开窗就自动随机选好一格（原版 ADDED_TO_STAGE → randomChar）")
	var 表: Array = [100, 200, 300, 400]
	_记(表.has(int(当.get("job", -1))), "自动选出来的 job 在四条真值里（实际 %s）" % str(当.get("job")))
	var 格: Array = 窗.get("_格")
	var 信: Dictionary = 窗.get("_格信息")
	var 错: Array[String] = []
	for i in 格.size():
		var 一: Dictionary = 信[(格[i] as Node).get_instance_id()]
		var 定: Dictionary = 格表[i]
		if int(一.get("job", -1)) != int(定["job"]) or int(一.get("gender", -1)) != int(定["gender"]):
			错.append("%s=%s/%s" % [str(定["名"]), str(一.get("job")), str(一.get("gender"))])
	_记(错.is_empty(), "四格运行期表 == 门里 AS3 表（错 %s）" % str(错))


func _钮(名: String) -> TextureButton:
	return 窗.get_node("窗口/" + 名) as TextureButton


func _皮名(钮: TextureButton, 槽: String) -> String:
	var 皮: Texture2D = null
	if 槽 == "normal":
		皮 = 钮.texture_normal
	elif 槽 == "hover":
		皮 = 钮.texture_hover
	else:
		皮 = 钮.texture_pressed
	return 皮.resource_path.get_file() if 皮 != null else "<空>"


func _B_换格() -> void:
	var 甲 := _钮("职业格1")
	var 乙 := _钮("职业格2")
	窗.call("_选中", 乙)
	_记(_皮名(乙, "normal") == "格_水女_选中.png", "点格2 ⇒ normal 换成「水女选中」（实际 %s）" % _皮名(乙, "normal"))
	_记(_皮名(乙, "hover") == "格_水女_选中.png",
			"选中那枚的 hover **也**指回选中图（`CharBox2.as:56-66` 悬停只对未选中生效，"
			+ "指回未选图=鼠标一划过去选中框就掉）实际 %s" % _皮名(乙, "hover"))
	窗.call("_选中", 甲)
	_记(_皮名(乙, "normal") == "格_水女_未选.png" and _皮名(乙, "hover") == "格_水女_悬停.png",
			"换到格1 后格2 回落 未选/悬停 两档（旧枚停在选中档 = 两枚同时亮）实际 %s|%s" % [
			_皮名(乙, "normal"), _皮名(乙, "hover")])
	var 当: Dictionary = 窗.get("_当前")
	_记(int(当.get("job", -1)) == 100 and int(当.get("gender", -1)) == 1,
			"当前 = 火男 100/1（实际 %s/%s）" % [str(当.get("job")), str(当.get("gender"))])

func _提示件() -> Control:
	return 窗.get("_提示") as Control


func _提示文() -> String:
	var 提 := _提示件()
	if 提 == null or not 提.visible:
		return ""
	var 标 := 提.get_node_or_null("文本") as Label
	return 标.text if 标 != null else ""


func _B_悬停() -> void:
	var 当: Dictionary = 窗.get("_当前")
	var 当前钮 := 当.get("钮", null) as TextureButton
	var 别 = null
	for 名 in ["职业格1", "职业格2", "职业格3", "职业格4"]:
		var 钮 := _钮(名)
		if 钮 != 当前钮:
			别 = 钮
			break
	_记(别 != null, "找得到一枚「不是当前」的格子来测悬停")
	if 别 == null:
		return
	窗.call("_格悬停", 当前钮)
	await _等帧(2)
	_记(_提示文() == "", "悬停当前那枚**不出**说明（原版只给未选中的加监听，`selectedBoxHandler`）")
	窗.call("_格悬停", 别)
	await _等帧(3)
	var 序 := (窗.get("_格") as Array).find(别)
	_记(_提示文() == str(描述真值[序]),
			"悬停第 %d 格 ⇒ 说明 == 原版描述逐字（长 %d，实际回来 %d）" % [序 + 1,
			str(描述真值[序]).length(), _提示文().length()])
	窗.call("_格离开", 别)
	await _等帧(2)
	_记(_提示文() == "", "移开 ⇒ 说明收掉")


func _清弹() -> void:
	for 子 in root.get_children():
		if str(子.name) == "创角弹框":
			子.queue_free()
	await _等帧(3)


func _板() -> Control:
	for 子 in root.get_children():
		if str(子.name) != "创角弹框":
			continue
		for 孙 in (子 as Control).get_children():
			if str(孙.name) == "板":
				return 孙 as Control
	return null


func _弹文() -> String:
	var 板 := _板()
	if 板 == null:
		return ""
	for 内 in 板.get_children():
		if 内 is Label:
			return (内 as Label).text
	return ""


func _弹红() -> bool:
	var 板 := _板()
	if 板 == null:
		return false
	for 内 in 板.get_children():
		if 内 is Label:
			var 色: Color = (内 as Label).get_theme_color("font_color")
			return 色.r > 0.9 and 色.g < 0.2 and 色.b < 0.2
	return false


## 点一次「进入游戏」并回读弹框（`_点进入` 里 `_弹` 是协程 ⇒ 必须隔帧再读）
func _点一次(名: String) -> void:
	await _清弹()
	窗.set("_用户输入过", true)
	(窗.get("_输入") as LineEdit).text = 名
	await _等帧(2)
	var 松 := InputEventMouseButton.new()
	松.button_index = MOUSE_BUTTON_LEFT
	松.pressed = false
	窗.call("_点进入", 松)
	await _等帧(4)


func _B_六条校验() -> void:
	await _点一次("")
	_记(_弹文() == str(案["空"]) and not _弹红(),
			"空名 ⇒ 白字「%s」（`createCharFail()` 第二支，色是默认色不是红）实际「%s」红=%s" % [
			str(案["空"]), _弹文(), str(_弹红())])
	var 长名 := "测试角色测试角色测"		# 10 个汉字 = 120px > 76 ⇒ 撞第一支
	var 宽: float = 窗.call("_字宽", 长名)
	await _点一次(长名)
	_记(_弹文() == str(案["太长"]) and not _弹红(),
			"名字宽度 %.1f > 76 ⇒ 白字「%s」，且这一支**排在**正则/长度三条之前（先量宽度）实际「%s」" % [
			宽, str(案["太长"]), _弹文()])
	await _点一次("12abc")
	_记(_弹文() == str(案["非法"]) and _弹红(),
			"数字开头 ⇒ 红字「%s」（原版这三支传了 16711680 = #FF0000）实际「%s」红=%s" % [
			str(案["非法"]), _弹文(), str(_弹红())])
	await _点一次("a")
	_记(_弹文() == str(案["超短"]) and _弹红(),
			"1 个字 ⇒ 红字「%s」实际「%s」" % [str(案["超短"]), _弹文()])
	# 原版 `:301` `_input.maxChars = MAX_NAME_CHARS` ⇒ **打不进第 13 个字**，
	# 「长度 > 12」那一支从 UI 上根本走不到（跟原版一样，不是漏做）。这里钉截断本身。
	var 十三 := "iiiiiiiiiiiii"
	await _点一次(十三)
	var 停: String = (窗.get("_输入") as LineEdit).text
	_记(停.length() == 12, "输入框把 13 个字截成 12（原版 maxChars=12）实际 %d 个：%s" % [停.length(), 停])
	_记(_弹文() != str(案["超长"]) and _弹文() != str(案["太长"]) and _弹文() != str(案["非法"]),
			"截断后的 12 个窄字母（实测宽 %.1f ≤ 76）不过早弹「超长/太长」" % 窗.call("_字宽", 停))
	await _点一次("abc123")
	_记(_弹文() != str(案["空"]) and _弹文() != str(案["太长"]) and _弹文() != str(案["非法"])
			and _弹文() != str(案["超长"]) and _弹文() != str(案["超短"]),
			"合法名过了六条校验（这里弹的是「%s」—— 本工程补的离线提示，原版没这一支）" % _弹文())


func _B_弹框() -> void:
	await _点一次("")
	var 板 := _板()
	_记(板 != null, "弹框建出来了（查无 = 判序或 _弹 死了）")
	if 板 == null:
		return
	_记(_数(板.size.x, 302.0), "弹框宽 == 302（CDilog_bgSkin 原生宽）实际 %.1f" % 板.size.x)
	var 舞台: Vector2 = 窗.get_parent().get_visible_rect().size
	_记(_数(板.position.x, roundf((舞台.x - 302.0) * 0.5)), "弹框水平居中（round((舞台-302)/2)）实际 %.1f" % 板.position.x)
	var 内: Control = 板.get_node("内容底") as Control
	var 标: Label = 板.get_node("文本") as Label
	_记(_数(内.position.x, 6.0) and _数(内.position.y, 6.0), "内容底在 (6,6)")
	_记(_数(内.size.x, 283.0), "内容底宽 == 283（302-6-6+…按原版）实际 %.1f" % 内.size.x)
	_记(_数(标.position.x, 14.0) and _数(标.position.y, 14.0), "文本盒在 (14,14)")
	_记(_数(标.size.x, 267.0), "文本盒宽 == 267（textWidth 真值）实际 %.1f" % 标.size.x)
	_记(_数(板.size.y - 内.size.y, 64.0),
			"面板高 - 内容高 == 64（= 14 顶距 + 50 底部钮区，`Dialog.as:124-183`）实际 %.1f" % (板.size.y - 内.size.y))
	var 钮: Button = 板.get_node("确定") as Button
	_记(钮 != null and 钮.text == str(案["确定"]), "确定钮文字 == 确定（OK 那条键）")
	_记(钮 != null and 钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "确定钮是手型")
	for 子 in 板.get_parent().get_children():
		if 子 is ColorRect:
			_记(_数((子 as ColorRect).color.a, 0.3), "遮罩黑 30%%（原版 0.3）实际 %.2f" % (子 as ColorRect).color.a)
	# —— 关框两路：回车 + 真鼠标点确定。都不许用"我确实连了信号"自证。——
	_记(root.gui_get_focus_owner() == 钮,
			"弹框起来后焦点在确定钮上（`gui_input` 的键盘事件只发给焦点持有者；"
			+ "原版 `Dialog.as:255` 关 stageFocusRect 就是抢焦点的痕迹）实际焦点=%s" % str(root.gui_get_focus_owner()))
	var 键 := InputEventKey.new()
	键.keycode = KEY_ENTER
	键.pressed = true
	root.push_input(键)
	await _等帧(5)
	_记(_板() == null, "回车把弹框关掉（`Dialog.as:202-208` keyCode==13 → destroy）")
	# 再弹一次，用真鼠标点确定
	await _点一次("")
	var 板2 := _板()
	_记(板2 != null, "第二次弹框建出来了（要给鼠标点）")
	if 板2 != null:
		var 钮2: Button = 板2.get_node("确定") as Button
		var 心: Vector2 = 钮2.get_global_rect().get_center()
		# ⚠ 无头 push_input 的鼠标事件 **position 与 global_position 都要写**，
		#    只写 global_position 时视口拿不到命中点 ⇒ 点了静默不生效（本轮实测）。
		for 压 in [true, false]:
			var 按 := InputEventMouseButton.new()
			按.button_index = MOUSE_BUTTON_LEFT
			按.position = 心
			按.global_position = 心
			按.pressed = 压
			root.push_input(按)
			await _等帧(2)
		_记(_板() == null, "真鼠标点确定 ⇒ 弹框关掉（`addCloseListener`→destroy）")





## 看门狗：`_跑` 里任何一条 script error 都会让它**直接中断**（不 return、不 quit）
## ⇒ 进程挂着不走，外面看就是「跑了三分钟没结果」（本轮量具真挂过一次，180 秒超时才发现）。
## 有了这条，中途坏掉也会留下「共 N 条，红 >=1」和一个非 0 退出码，变异实测才读得懂。
func _等条件(谓词: Callable, 毫秒: int) -> bool:
	var 截止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 截止:
		if bool(谓词.call()):
			return true
		await create_timer(0.05).timeout
	return false

func _看门狗() -> void:
	if await _等条件(func(): return 总 > 0 and str(日志[日志.size() - 1]).begins_with("汇"), 90000):
		return
	_记(false, "看门狗：90 秒没跑到汇总（_跑 中途 script error 或某步没回帧）")
	_尾()



func _尾() -> void:
	var 存档后 := _存档字节()
	_记(存档后 == 存档前, "跑完 user://玩家数据.json 没被写（前 %s 后 %s）" % [存档前, 存档后])
	日志.append("")
	日志.append("汇：共 %d 条，红 %d 条" % [总, 红数])
	var f := FileAccess.open("res://测试/截图/创角/门日志.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(换.join(日志) + 换)
		f.close()
	for 行 in 日志:
		print(行)
	quit(0 if 红数 == 0 else 1)

## —— D：空号出得去的那条接线（端到端量具是自己开窗的，这一层只有这里钉）——
## 用户 2026-10-09 报的就是这一层：注册完的新号进不去游戏，界面停在「正在读取角色」。
## 光有那扇窗没用 —— 得有人**开它**，而且两条路（loginStatus==1 与 角色列表为空）都要开。
func _D_登录接线() -> void:
	var 登录 := _读("res://脚本/界面/登录界面.gd")
	var 选角 := _读("res://脚本/界面/选角窗.gd")
	_记(登录.length() > 1000 and 选角.length() > 500, "登录界面与选角窗的源都读到了")
	var 几处 := 0
	for 行 in 登录.split(换):
		if 行.strip_edges() == "_开创角窗()":
			几处 += 1
	_记(几处 == 2, "空号两条路都叫了 _开创角窗()（loginStatus==1 与 角色列表为空；实际 %d 处）" % 几处)
	_记(登录.contains(引 + "res://场景/界面/窗口/创建角色/创建角色窗.tscn" + 引),
			"登录层 load 的就是这扇创角窗（不是旧选角窗的占位面板）")
	_记(登录.contains("_创角窗.move_child(_创角窗, get_child_count() - 1)"),
			"创角窗提到最后一个子节点 ⇒ 盖得住登录卡片（不排序就会压在卡片下面看不见）")
	_记(登录.contains("_创角窗.建好角了.connect"), "建完角要回手把窗收掉（不然留在屏幕上挡选角）")
	var 起 := 登录.find("func _开创角窗")
	if 起 >= 0:
		var 段 := 登录.substr(起, 900)
		_记(段.contains("_card.visible = false"), "开创角窗时把登录卡片收掉（两层表单叠着就是当年那个形状）")
	_记(选角.contains("父.has_method(" + 引 + "_开创角窗" + 引 + ")"),
			"选角窗把创建这一步**交回**登录层（它自己不再造面板）")
	var 旧调用 := 0
	for 行 in 选角.split(换):
		var 去 := 行.strip_edges()
		if 去.begins_with("#"):
			continue
		if 去.contains("create_character("):
			旧调用 += 1
	_记(旧调用 == 0, "选角窗里不许再有 create_character( 调用 —— 旧占位面板用的是**旧签名**，"
			+ "对不上新的 (name, job, gender) 就是编译期错）实际 %d 处" % 旧调用)
