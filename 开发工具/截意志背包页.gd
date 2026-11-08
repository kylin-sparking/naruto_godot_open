extends "res://开发工具/量具基类.gd"

## 量「意志背包」窗（原版 `com/mxw/uifl/controls/yiZhi/YiZhiPackWindow.as`，663×548）。
## 骨架在 `开发工具/量具基类.gd`；场景由 `开发工具/生成意志背包场景.py` 从本文件的
## `件路径 / 件期望` 两张表生成 ⇒ **改真值只改这里**，别手改 .tscn。
##
## 坐标链（逐条有出处）：
##   `super(663,548,true)` `:75`（第 3 参是 `UIWindow._drawContentBg`，**不是模态**）
##   `_contentBg` MYellow @(8,38) 647×480 —— `UIWindow:36-38,64-65`
##     x=CONTENT_GAP=8、y=38、w=663−16、h=548−68（`UIConfig.as:890,892` = 8 / 5）
##   页面容器原点 (0,29)（`窗口尺寸.json` 的「遗址」标 `整框: true`）
##   ⇒ **场景 y = AS3 窗口局部 y − 29**
##
## 注册名沿用「遗址」（`窗口管理`/`功能入口回归测试` 都用这个名字，页面根节点 = 原版意志背包内容）。
##
## 用法（不能加 --headless）：
##   Godot --path . --script res://开发工具/截意志背包页.gd -- --出目录=res://测试/截图/意志背包

const 件路径 := {
	"外框黄底": "外框黄底",
	"拖动提示": "拖动提示",
	"意志值框": "意志值框",
	"意志力图标": "意志力图标",
	"背包容器": "背包容器",
	"穿戴盘": "穿戴盘",
	"穿戴容器": "穿戴容器",
	"升级格": "升级格",
	"锁定勾选": "锁定勾选",
	"自动升级钮": "自动升级钮",
	"自动升级提示": "自动升级提示",
	"意志介绍": "意志介绍",
	"一键合成": "一键合成",
	"前往学习": "前往学习",
	"背包格0": "背包容器/格_0", "背包格1": "背包容器/格_1", "背包格2": "背包容器/格_2",
	"背包格3": "背包容器/格_3", "背包格4": "背包容器/格_4", "背包格5": "背包容器/格_5",
	"背包格6": "背包容器/格_6", "背包格7": "背包容器/格_7", "背包格8": "背包容器/格_8",
	"背包格9": "背包容器/格_9", "背包格10": "背包容器/格_10", "背包格11": "背包容器/格_11",
	"背包格12": "背包容器/格_12", "背包格13": "背包容器/格_13", "背包格14": "背包容器/格_14",
	"背包格15": "背包容器/格_15", "背包格16": "背包容器/格_16", "背包格17": "背包容器/格_17",
	"背包格18": "背包容器/格_18", "背包格19": "背包容器/格_19", "背包格20": "背包容器/格_20",
	"背包格21": "背包容器/格_21", "背包格22": "背包容器/格_22", "背包格23": "背包容器/格_23",
	"背包格24": "背包容器/格_24", "背包格25": "背包容器/格_25", "背包格26": "背包容器/格_26",
	"背包格27": "背包容器/格_27", "背包格28": "背包容器/格_28", "背包格29": "背包容器/格_29",
	"穿戴格1": "穿戴容器/格_1", "穿戴格2": "穿戴容器/格_2", "穿戴格3": "穿戴容器/格_3",
	"穿戴格4": "穿戴容器/格_4", "穿戴格5": "穿戴容器/格_5", "穿戴格6": "穿戴容器/格_6",
	"穿戴格7": "穿戴容器/格_7", "穿戴格8": "穿戴容器/格_8",
	"合成字": "一键合成/字", "学习字": "前往学习/字", "自动升级字": "自动升级钮/字",
	"格0底": "背包容器/格_0/格底", "格0悬停": "背包容器/格_0/格悬停",
	"格0名称": "背包容器/格_0/名称", "格0等级": "背包容器/格_0/等级",
	# 穿戴位的**封印**（`YiZhiCell.forbidCell:53-65`，`UISwf_yizhiPack_feng` 64×64）
	"穿戴格1封印": "穿戴容器/格_1/封印", "穿戴格2封印": "穿戴容器/格_2/封印",
	"穿戴格3封印": "穿戴容器/格_3/封印", "穿戴格4封印": "穿戴容器/格_4/封印",
	"穿戴格5封印": "穿戴容器/格_5/封印", "穿戴格6封印": "穿戴容器/格_6/封印",
	"穿戴格7封印": "穿戴容器/格_7/封印", "穿戴格8封印": "穿戴容器/格_8/封印",
}

const 件期望 := {
	"外框黄底": [8, 9, 647, 480],					# `UIWindow:36-38,64-65` (8,38) 663−16 × 548−68
	"拖动提示": [38, 19, 473, 19],					# :133-137 setPosition(_contentBg.x+30, +10)、width=473、UI_GREEN
	"意志值框": [522, 23, 125, 21],					# :138-141 MTextInput2（`setSize(125,21)`）
													#   x = 647+8−125−CONTENT_GAP(8) = 522、y = 拖动提示.y+4 = 52
	"意志力图标": [507, 18, 29, 30],					# :142-145 UISwf_yizhiPack_yizhiIcon，x=框.x−15、y=框.y−5
	"背包容器": [16, 51, 340, 409],					# :146-148 x=8+CONTENT_GAP(8)=16、y=48+19+13=80
													#   5 列 × 6 行、格 64 + gap 5 ⇒ 5·69−5=340、6·69−5=409
	"穿戴盘": [391, 83, 230, 230],					# :157-160 UISwf_yizhiPack_equipSkin @(391,112)
	"穿戴容器": [391, 83, 230, 230],					# :155-156 _equipPanel = (_contentBg.x+383, 容器.y+32)
	"升级格": [413, 359, 64, 64],					# :465-468 x=_width−250=413、y=意志介绍.y−100=388
	"锁定勾选": [485, 364, 76, 19],					# :469-474 x=升级格.x+64+8=485、y=388+5=393、text「锁定意志」
													#   ⚠ 宽度 AS3 是 `upSkin.x+upSkin.width+tf.width+2` 量出来的
													#   （`MCheckBox.as:81-91`），语言表里没有常量 ⇒ 76 是**实测烘入**、标未证；
													#   高度 19 = `upSkin.height`（见 skill「MCheckBoxF 收不出 19 高」）
	"自动升级钮": [485, 391, 110, 22],				# :475-482 x=勾选.x、y=勾选.y+19+8=420、width=110、**enabled=false**
	"自动升级提示": [410, 423, 228, 40],				# :483-495 x=钮.x−75=410、y=钮.y+22+10=452、220×40、色 52224=#00CC00、leading 4
													# ⚠ 声明宽 220 是 AS3 `adjustContent=false` 的**固定框宽**；
													#   Godot 的 Label 矩形由内容撑开（两行里长的那行 19 字 ×12），
													#   原版 wordWrap 没开 ⇒ 文字同样是**一行画满不折行**，视觉一致、
													#   只有矩形宽差 8px。烘 228 = 实测，差异登记在真值对照表「已知偏离」。
													#   2026-10-25 晚：全局合成加粗回滚后字距回到原值（228）；
													#   中间短暂量到 234 是全局 embolden 1.5 把每字撑宽 ~0.25px。
	"意志介绍": [538, 459, 110, 19],					# :178-192 x=_width−125=538、y=_height−60=488、w=110、右对齐、#FFF000 下划线
	"一键合成": [80, 492, 143, 22],					# :186-191 x=80、y=548−22−5=521、width=143、isScale9Grid=false
	"前往学习": [440, 492, 82, 22],					# :193-197 x=663−143−80=440、y=同、width=btn_width_six=82（`UIConfig:972`）
	"背包格0": [16, 51, 64, 64], "背包格1": [85, 51, 64, 64], "背包格2": [154, 51, 64, 64],
	"背包格3": [223, 51, 64, 64], "背包格4": [292, 51, 64, 64],
	"背包格5": [16, 120, 64, 64], "背包格6": [85, 120, 64, 64], "背包格7": [154, 120, 64, 64],
	"背包格8": [223, 120, 64, 64], "背包格9": [292, 120, 64, 64],
	"背包格10": [16, 189, 64, 64], "背包格11": [85, 189, 64, 64], "背包格12": [154, 189, 64, 64],
	"背包格13": [223, 189, 64, 64], "背包格14": [292, 189, 64, 64],
	"背包格15": [16, 258, 64, 64], "背包格16": [85, 258, 64, 64], "背包格17": [154, 258, 64, 64],
	"背包格18": [223, 258, 64, 64], "背包格19": [292, 258, 64, 64],
	"背包格20": [16, 327, 64, 64], "背包格21": [85, 327, 64, 64], "背包格22": [154, 327, 64, 64],
	"背包格23": [223, 327, 64, 64], "背包格24": [292, 327, 64, 64],
	"背包格25": [16, 396, 64, 64], "背包格26": [85, 396, 64, 64], "背包格27": [154, 396, 64, 64],
	"背包格28": [223, 396, 64, 64], "背包格29": [292, 396, 64, 64],
	"穿戴格1": [362, 164, 64, 64], "穿戴格2": [387, 84, 64, 64], "穿戴格3": [471, 53, 64, 64],
	"穿戴格4": [556, 84, 64, 64], "穿戴格5": [586, 164, 64, 64], "穿戴格6": [556, 244, 64, 64],
	"穿戴格7": [471, 279, 64, 64], "穿戴格8": [387, 244, 64, 64],
	# ↑ `initView:451` 硬编码偏移 [[-29,81],[-4,1],[80,-30],[165,1],[195,81],[165,161],[80,196],[-4,161]]
	#   相对 _equipPanel(391,112) ⇒ 窗口坐标；再 −29 换页面坐标
	"合成字": [80, 492, 143, 22],					# MButton3 的 tf 居中在钮矩形里
	"学习字": [440, 492, 82, 22],
	"自动升级字": [485, 391, 110, 22],
	"格0底": [16, 51, 64, 64],						# `YiZhiCell:113-114` cellSkin 原生 64×64 @(0,0)
	"格0悬停": [16, 51, 64, 64],					# :115-117 cellOverSkin 64×64，**visible=false**
	"格0名称": [16, 83, 64, 19],					# :118-124 width=64、y=32、align=center（空数据时 text=""）
	"格0等级": [16, 97, 64, 19],					# :125-131 width=64、y=46、text="Lv."+level
	# 封印 = 整格覆盖（与格底同矩形）。穿戴格矩形 = 穿戴容器 + `initView:451` 的硬编码偏移，
	# 所以逐格的 x,y 由下面 `_封印期望()` 现算（**不写死数字**，改了偏移表会一起跟着）。
	"穿戴格1封印": [362, 164, 64, 64], "穿戴格2封印": [387, 84, 64, 64],
	"穿戴格3封印": [471, 53, 64, 64], "穿戴格4封印": [556, 84, 64, 64],
	"穿戴格5封印": [586, 164, 64, 64], "穿戴格6封印": [556, 244, 64, 64],
	"穿戴格7封印": [471, 279, 64, 64], "穿戴格8封印": [387, 244, 64, 64],
}


## 基类只量 `页面件表()[页号]` 点名的件 ⇒ 这里把 14 个散件 + 30 背包格 + 8 穿戴格 + 代表子件全点上。
func 页面件表() -> Dictionary:
	var 全: Array[String] = ["外框黄底", "拖动提示", "意志值框", "意志力图标", "背包容器",
			"穿戴盘", "穿戴容器", "升级格", "锁定勾选", "自动升级钮", "自动升级提示",
			"意志介绍", "一键合成", "前往学习", "合成字", "学习字", "自动升级字",
			"格0底", "格0悬停", "格0名称", "格0等级"]
	for k in 30:
		全.append("背包格%d" % k)
	for k in range(1, 9):
		全.append("穿戴格%d" % k)
		全.append("穿戴格%d封印" % k)
	return {0: 全}


func 页名() -> String:
	return "遗址"


func 根节点名() -> String:
	return "原版意志背包内容"


func 页签数() -> int:
	return 1


## 原版这一页没有页签条（`YiZhiPackWindow` 里没有任何 MTabButton）。
func 有页签() -> bool:
	return false


## 基类默认量 `内容框`（那是"内容底偏移 (8,38)"那类页才有的件）；本页是整窗 1:1 ⇒ 换成 MYellow。
func 公共件() -> Array[String]:
	return ["外框黄底"]


func 期望() -> Dictionary:
	return 件期望


func 路径() -> Dictionary:
	return 件路径


## 文案真值全部读 `数据/界面/意志_文案.json`（`开发工具/出意志文案数据.py` 从 AS3 语言表抽）。
## 「锁定意志」「自动升级意志」「提示:…」三条在原版里是**硬编码**、没有语言键 ⇒ 只能照抄原文。
func 文案表() -> Dictionary:
	return {
		"拖动提示": 键("YIZHI_DRAG_PROMPT_LABEL"),
		"意志介绍": "[" + 键("YIZHI_INTRODUCE_LABEL") + "]",
		"合成字": 键("YIZHI_YI_JIAN_HECHENG_BUTTON_NAME"),
		"学习字": 键("YIZHI_STUDY_BUTTON_NAME"),
		"自动升级字": "自动升级意志",
		"自动升级提示": "提示:任意背包/穿戴意志都可直接拖入此槽\n勾选锁定后点击升级即可",
	}


static func 键(名: String) -> String:
	var 表: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://数据/界面/意志_文案.json"))
	return String(表.get(名, ""))


## 基类按 `页面文案表()[页号]` 的名单去 `文案表()` 取原文逐字比 ⇒ 这里只登记"该页量哪几条"。
func 页面文案表() -> Dictionary:
	# ⚠ 三枚钮的字在**子 Label** 上（原版 MButton3 的 tf 与皮肤是两个显示对象），
	#   所以登记的是 `合成字/学习字/自动升级字`，不是钮本身；`锁定勾选` 是 CheckBox
	#   （基类的文案通道只吃 Label/RichTextLabel）⇒ 挪到 `额外校验` 里单独比。
	return {0: ["拖动提示", "意志介绍", "合成字", "学习字", "自动升级字", "自动升级提示"]}


func 额外校验(页: Control, _页号: int) -> void:
	# 一、格数：原版 `PACK_MAX_COUNT=30`、`EQUIP_MAX_COUNT=8`（`YiZhiManager.as:22,26`）
	var 容 := 页.get_node_or_null("背包容器") as Control
	var n: int = 容.get_child_count() if 容 != null else 0
	有错 = 有错 or n != 30
	_行("  %-12s 子节点=%d（原版 PACK_MAX_COUNT=30）%s" % ["背包容器", n, "√" if n == 30 else "!! 错"])
	var 穿 := 页.get_node_or_null("穿戴容器") as Control
	var n2: int = 穿.get_child_count() if 穿 != null else 0
	有错 = 有错 or n2 != 8
	_行("  %-12s 子节点=%d（原版 EQUIP_MAX_COUNT=8）%s" % ["穿戴容器", n2, "√" if n2 == 8 else "!! 错"])
	# 二、原版初值不可见 / 不可用
	var 悬 := 页.get_node_or_null("背包容器/格_0/格悬停") as CanvasItem
	有错 = 有错 or 悬 == null or 悬.visible
	_行("  %-12s visible=%s（YiZhiCell:117 初值 false）%s" % ["格0悬停",
		str(悬.visible) if 悬 else "<无>", "√" if 悬 != null and not 悬.visible else "!! 错"])
	var 钮 := 页.get_node_or_null("自动升级钮") as BaseButton	# TextureButton 不是 Button，同是 BaseButton
	有错 = 有错 or 钮 == null or not 钮.disabled
	_行("  %-12s disabled=%s（YiZhiPackWindow:481 enabled=false）%s" % ["自动升级钮",
		str(钮.disabled) if 钮 else "<无>", "√" if 钮 != null and 钮.disabled else "!! 错"])
	# 三、锁定勾选的文案（CheckBox 不是 Label，走不到基类的文案通道）
	var 勾 := 页.get_node_or_null("锁定勾选") as CheckBox
	var 勾对: bool = 勾 != null and 勾.text == "锁定意志"	# PW:470 **硬编码**，语言表里没这个键
	有错 = 有错 or not 勾对
	_行("  %-12s text=「%s」（原版硬编码「锁定意志」）%s" % ["锁定勾选",
		勾.text if 勾 else "<无>", "√" if 勾对 else "!! 错"])
	# 3.6、封印：`updateEquipLimit:209-227` 初值 `equipLimit=1` ⇒ 只有格_1 开着，格_2..8 画封印
	#     （`forbidCell` 还 `removeChild(_overSkin)` ⇒ **封印格悬停不亮黄框**，见下面 3.7）
	for k in range(1, 9):
		var 封 := 页.get_node_or_null("穿戴容器/格_%d/封印" % k) as CanvasItem
		var 该显: bool = k != 1
		var 对36: bool = 封 != null and 封.visible == 该显
		有错 = 有错 or not 对36
		_行("  %-12s 格_%d 封印.visible=%s（equipLimit=1 ⇒ 想 %s）%s" % ["封印态", k,
			str(封.visible) if 封 else "<没这件>", str(该显), "√" if 对36 else "!! 错"])
	# 3.7、真事件悬停（"开着的格要亮 / 封印格不许亮"）在下面的 `_队列尾` 里 ——
	#     hover 归属是**帧末** `Viewport.update_gui()` 才重算的，同步步里推完事件立刻读必然量不到。
	# 四、步距：5 列一行、gap 5 ⇒ 69
	var g0 := 页.get_node_or_null("背包容器/格_0") as Control
	var g1 := 页.get_node_or_null("背包容器/格_1") as Control
	var g5 := 页.get_node_or_null("背包容器/格_5") as Control
	var 步对: bool = g0 != null and g1 != null and g5 != null \
		and int(g1.position.x - g0.position.x) == 69 and int(g5.position.y - g0.position.y) == 69
	有错 = 有错 or not 步对
	_行("  %-12s 步距=%s/%s（64+gap5）%s" % ["背包格排",
		str(int(g1.position.x - g0.position.x)) if g0 != null and g1 != null else "?",
		str(int(g5.position.y - g0.position.y)) if g0 != null and g5 != null else "?",
		"√" if 步对 else "!! 错"])


func _行(文本: String) -> void:
	行.append(文本)
	print(文本)


# ═════════════════ 悬停黄框 / 勾选联动 / 意志力提示（真事件，2026-10-03 补）═════════════════
## 上面 `额外校验` 只量得到**初值**（`格悬停 visible=false`）—— 那判不了"悬停到底亮不亮"。
## 用户 2026-10-03 打回「悬停的黄色点击效果都没做出来」，红的正是这一族：
##   `YiZhiCell:163-166` overHandler → `cellOverSkin.visible = true`、`:134-137` outHandler →
##   **`= _selected`**（不是 false ⇒ 选中态移开也常亮）。
## ⚠ 一律 `root.push_input` + 隔帧，**不许 `mouse_entered.emit()`**：emit 只证明接了线，
##   证明不了事件进得来（[[gate-must-use-real-input]]，这条已经立过一次规矩）。

const 空白落点 := Vector2(300, 470)	# 页内那条空白黄底带（格排 51..460 之下、钮排 492 之上）


func _队列尾() -> void:
	队列.append(_步悬格.bind(0))
	队列.append(_步验格亮.bind(0, true))
	队列.append(_步移开)
	队列.append(_步验格亮.bind(0, false))
	队列.append(_步悬格.bind(29))
	队列.append(_步验格亮.bind(29, true))
	队列.append(_步悬升级槽)
	队列.append(_步验升级槽亮)
	队列.append(_步点勾选)
	队列.append(_步验勾选)
	队列.append(_步悬意志值)
	队列.append(_步验意志提示)
	# 开着的穿戴格（格_1）悬停要亮；封印格（格_3）悬停**不许**亮（forbidCell 摘了 overSkin）
	队列.append(_步悬某格.bind("穿戴容器/格_1"))
	队列.append(_步验某格亮.bind("穿戴容器/格_1", true))
	队列.append(_步悬某格.bind("穿戴容器/格_3"))
	队列.append(_步验某格亮.bind("穿戴容器/格_3", false))


func _件(路: String) -> Node:
	return 页根().get_node_or_null(路)


func _送移动(点: Vector2) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 点
	移.global_position = 点
	root.push_input(移)


## 分两跳进中心（大距离一步瞬移时同一帧只按最后一条 motion 做拾取，会不发 mouse_entered）。
func _悬到(件: Control) -> void:
	var 盒 := 件.get_global_rect()
	var 心 := 盒.position + 盒.size / 2.0
	var 远 := 页根().get_global_position() + 空白落点
	_送移动((心 + 远) / 2.0)
	等待 = 2
	_送移动(心)
	等待 = 3


var 悬格 := 0		# 当前正在悬停的背包格下标（-1 = 没悬在任何格上），只给日志看落点用


func _步悬格(k: int = 0) -> void:
	var 名 := "背包格%d" % k
	if not 件路径.has(名):
		_错("件路径表里没登记 %s" % 名)
		return
	var 格 := _件(String(件路径[名])) as Control
	if 格 == null:
		_错("取不到 %s" % 名)
		return
	悬格 = k
	_悬到(格)


func _步移开() -> void:
	_送移动(页根().get_global_position() + 空白落点)
	等待 = 3
	悬格 = -1


func _步验格亮(k: int, 该亮: bool) -> void:
	var 路 := "背包容器/格_%d/格悬停" % k
	var 框 := _件(路) as CanvasItem
	if 框 == null:
		_错("取不到 %s" % 路)
		return
	var 对: bool = 框.visible == 该亮
	有错 = 有错 or not 对
	_行("  %-14s 格悬停.visible=%s（想 %s，当前悬停格=%d）%s" % ["背包格%d" % k,
			str(框.visible), str(该亮), 悬格, "√" if 对 else "!! 错（YiZhiCell overHandler/outHandler）"])


func _步悬升级槽() -> void:
	var 格 := _件("升级格") as Control
	if 格 == null:
		_错("取不到 升级格")
		return
	_悬到(格)


func _步验升级槽亮() -> void:
	var 框 := _件("升级格/格悬停") as CanvasItem
	var 对: bool = 框 != null and 框.visible
	有错 = 有错 or not 对
	_行("  %-14s 格悬停.visible=%s（升级槽也是 YiZhiCell）%s" % ["升级格",
			str(框.visible) if 框 != null else "<无>", "√" if 对 else "!! 错"])


## 槽里没货时点勾选 ⇒ 原版强制取消 + 提示「请先将意志拖入升级槽位」（`:641-646`，硬编码中文）。
## 真点：motion 进中心 + 左键 down/up（`CheckBox` 的 toggled 只在真事件下才代表玩家手感）。
func _步点勾选() -> void:
	var 勾 := _件("锁定勾选") as CheckBox
	if 勾 == null:
		_错("取不到 锁定勾选")
		return
	var 盒 := 勾.get_global_rect()
	var 心 := 盒.position + Vector2(10.0, 盒.size.y / 2.0)	# 点在**方框**上，不是文字上
	_送移动(心)
	等待 = 2
	for 按 in [true, false]:
		var 键 := InputEventMouseButton.new()
		键.position = 心
		键.global_position = 心
		键.button_index = MOUSE_BUTTON_LEFT
		键.pressed = 按
		root.push_input(键)
	等待 = 3


func _步验勾选() -> void:
	var 勾 := _件("锁定勾选") as CheckBox
	var 主 := 主窗()
	var 状 := 主.get_node_or_null("后端状态") as Label if 主 != null else null
	var 想 := "请先将意志拖入升级槽位"
	var 对: bool = 勾 != null and not 勾.button_pressed and 状 != null and 状.text == 想
	有错 = 有错 or not 对
	_行("  %-14s 点后 selected=%s 状态=「%s」%s" % ["勾选联动",
			str(勾.button_pressed) if 勾 != null else "<无>", 状.text if 状 != null else "<无>",
			"√" if 对 else "!! 错（无升级槽货时原版强制取消并提示「%s」）" % 想])
	_送移动(页根().get_global_position() + 空白落点)
	等待 = 2


func _步悬意志值() -> void:
	var 框 := _件("意志值框") as Control
	if 框 == null:
		_错("取不到 意志值框")
		return
	_悬到(框)


func _步验意志提示() -> void:
	var 提示 := 页根().get_node_or_null("文字提示_意志值") as CanvasItem
	var 对: bool = 提示 != null and 提示.visible
	有错 = 有错 or not 对
	if 提示 != null and 提示.visible:
		var 文 := 提示.get_node("文字") as RichTextLabel
		var 纯 := 文.get_parsed_text()
		对 = 对 and 纯.begins_with(_意志键("YIZHI_YIZHILI_LABEL"))	# 「当前意志：」打头
		有错 = 有错 or not 对
		_行("  %-14s 悬停出提示=%s 正文=「%s」%s" % ["意志力提示", str(提示.visible),
				纯.replace("\n", "⏎"), "√" if 对 else "!! 错"])
	else:
		_行("  %-14s visible=%s（updateYiZhiTipNow:505-514 挂的是 _yiZhiField）!! 错"
				% ["意志力提示", str(提示.visible) if 提示 != null else "<无>"])


func _意志键(名: String) -> String:
	var 表: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://数据/界面/意志_文案.json"))
	return String(表.get(名, ""))


## 两步一对：先把鼠标真送进某一格（隔帧），下一拍再读它的 `格悬停`。
## ⚠ 封印格那条是**反向**断言：`forbidCell:57-60` 把 `_overSkin` 从显示列表里摘掉 ⇒ 那格永远不该亮。
##   我第一版接线给 8 枚穿戴格全绑了 hover ⇒ 封印格也跟着亮黄框，就是这条门会红的东西。
var 悬路 := ""


func _步悬某格(路: String) -> void:
	var 格 := 页根().get_node_or_null(路) as Control
	if 格 == null:
		_错("取不到 %s" % 路)
		return
	悬路 = 路
	_悬到(格)


func _步验某格亮(路: String, 该亮: bool) -> void:
	var 框 := 页根().get_node_or_null(路 + "/格悬停") as CanvasItem
	if 框 == null:
		_错("取不到 %s/格悬停" % 路)
		return
	var 对: bool = 框.visible == 该亮
	有错 = 有错 or not 对
	_行("  %-12s 悬停 %s ⇒ 格悬停.visible=%s（想 %s）%s" % ["悬停判格", 路,
			str(框.visible), str(该亮), "√" if 对 else "!! 错"])
	_送移动(页根().get_global_position() + 空白落点)
	等待 = 2
