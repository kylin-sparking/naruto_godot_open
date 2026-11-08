extends SceneTree
## 快捷键设置窗（KeyboardFrame 移植）几何 + 交互门（headless）。
##
## ⚠ 本门**不读** `快捷键窗期望.json` 来判几何 —— 期望和场景同一个生成器出的，
## 生成器算错一位两边一起错，门照样绿（上一版「86 枚格少减 29 抬、整排压住操作钮」就是这么漏过去的）。
## 这里改成拿**两份原始真值**独立复算：`数据/界面/快捷键_时间轴.json`（94 个命名实例的窗口坐标）
## 与 `数据/界面/键位表.json`（KeyDef 的格标签/格宽/可绑性 + 31 条动作槽），
## 页坐标 = 窗口坐标 − (0, 拖动区高 29)。
##
## 另验五条会复发的假绿：
##   ① 逐件取不到就报；② `canSet=false` 的格不吃鼠标、且**不给它烘牌**（原版不挂事件）；
##   ③ 宽键（空格 224 / Shift 87 / …）必须按 KeyDef.width 拉，不能一律 40；
##   ④ 拖放后**格上的牌**跟着变（原版格上小字永远是键名，动作名在牌上）；
##   ⑤ 方案钮 / 保存方案不能是空标签（语言表缺键时曾渲成空白，看着像没做完）。

const 场景 := "res://场景/界面/窗口/设置/快捷键窗.tscn"
const 时轴文件 := "res://数据/界面/快捷键_时间轴.json"
const 键表文件 := "res://数据/界面/键位表.json"
const 补文文件 := "res://数据/界面/快捷键_补文案.json"
## 钮上文案的**原始语言表**。原来写的是作者机上的
## `2.2.3/真值文档/UI/texts/message.json`（本机没有 ⇒ 4 枚操作钮全红）。
## 改成读**本工程一直在用的那份原版语言表**：AS3 字面量 `en_US$message_properties.as`
## —— 它才是这份工程意义上的"原始语言表"（`开发工具/原版数据.py` 读的也是它）。
## ⚠️ 口径没变：仍然**不经过生成器那个 JSON**，避免"生成器抄错也照样自证自绿"。
## ⚠️ 用**相对工程根**的路径（`globalize_path` 之后再拼），别写 `res://../…`
##    —— Godot 不解析 `res://` 里的 `..`；也别写绝对盘符（换台机器就断）。
const 语言表相对 := "../2.2.3/map_extract/out/mainlib_as/scripts/en_US$message_properties.as"
var _语言表绝对 := ""


func 语言表() -> String:
	if _语言表绝对.is_empty():
		_语言表绝对 = ProjectSettings.globalize_path("res://").path_join(语言表相对).simplify_path()
	return _语言表绝对
const 容差 := 1.0
const 抬 := 29.0
const 窗宽 := 765.0
const 格高 := 40.0

var _红 := 0
var 时轴: Dictionary
var 键表: Dictionary
var 键槽: Array
var 补文: Dictionary
var _语: Dictionary = {}


func _initialize() -> void:
	时轴 = (JSON.parse_string(FileAccess.get_file_as_string(时轴文件)) as Dictionary)["件"]
	var 数: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(键表文件))
	键表 = 数.get("表", {})
	键槽 = 数.get("槽", [])
	补文 = (JSON.parse_string(FileAccess.get_file_as_string(补文文件)) as Dictionary)["表"]
	var 窗 := (load(场景) as PackedScene).instantiate() as Control
	if 窗 == null:
		print("!! instantiate null")
		quit(1)
		return
	root.add_child(窗)
	var 宿: Node = load("res://测试/假设置宿主.gd").new()
	root.add_child(宿)
	窗.call("装配", 宿)
	验格几何(窗)
	验列表与底(窗)
	验操作钮(窗)
	验方案钮(窗)
	验不可绑(窗)
	验拖放(窗, 宿)
	验取消(窗, 宿)
	验确定(窗, 宿)
	验尺寸(窗)
	var 件数 := 0
	for 子 in 窗.get_children():
		件数 += 1
	print("快捷键窗：件 %d、键位格 %d、列表格 34、操作钮 4、方案钮 6，红 %d" % [件数, 时轴.size() - 8, _红])
	quit(1 if _红 > 0 else 0)


func 验尺寸(窗: Control) -> void:
	if absf(窗.custom_minimum_size.x - 窗宽) > 容差:
		_报("页宽 %s ≠ 时间轴 background 765" % 窗.custom_minimum_size.x)


## 86 枚键位格：位置 = 时间轴 (x, y−29)，宽 = KeyDef.width，高恒 40。
func 验格几何(窗: Control) -> void:
	var 查 := 0
	for 名 in 时轴:
		var 录: Array = 时轴[名]
		if String(录[1]) != "KeyboardCellF":
			continue
		var 全 := "格" + String(名)
		var 格 := 窗.get_node_or_null(NodePath(全)) as Control
		if 格 == null:
			_报("缺件：%s" % 全)
			continue
		var 键 := String(名).trim_suffix("Cell")
		var 数: Dictionary = 键表.get(键, {})
		var 宽 := float(数.get("width", 格高))
		var d := maxf(maxf(absf(格.position.x - float(录[2])), absf(格.position.y - (float(录[3]) - 抬))),
				maxf(absf(格.size.x - 宽), absf(格.size.y - 格高)))
		if d > 容差:
			_报("%s 实测 (%s,%s,%s,%s) ≠ 时间轴 (%s,%s−29) 宽 %s" % [
				全, 格.position.x, 格.position.y, 格.size.x, 格.size.y, 录[2], 录[3], 宽])
		var 字 := 格.get_node_or_null(NodePath("字" + String(名))) as Label
		if 字 == null:
			_报("%s 上没有字件（原版 keyTextField 恒在）" % 全)
		elif 字.text != String(数.get("name", "")):
			_报("%s 字 = %s ≠ KeyDef name %s" % [全, 字.text, 数.get("name", "")])
		elif bool(数.get("canSet", true)) and (字.position.x != 2.0 or 字.position.y != 3.0):
			_报("%s 字落点 (%s,%s) ≠ KC:49-53+ML:206-207 的 (2,3)" % [全, 字.position.x, 字.position.y])
		# 层序：原版牌进 cellBg（先一层）、键名后加在格上 ⇒ 键名永远在牌之上。
		# 反过来写，36×36 的牌会把 (2,3) 处的键名整个盖掉。
		var 牌 := 格.get_node_or_null("牌") as TextureRect
		if 牌 != null and 字 != null \
				and (格.get_children().find(牌) as int) > (格.get_children().find(字) as int):
			_报("%s 的牌排在键名之后 ⇒ 牌盖住键名（KC:87 牌在 cellBg 内、KC:51 键名晚一层）" % 全)
		查 += 1
	if 查 != 86:
		_报("只核到 %d 枚键位格，时间轴 KeyboardCellF 应有 86" % 查)
	# 宽键单独点一遍：整排 40 宽是上一版最扎眼的一处
	for 键 in ["space", "shiftLeft", "lock", "ctrlLeft", "enter", "tab", "bksp"]:
		var 格 := 窗.get_node_or_null(NodePath("格" + String(键) + "Cell")) as Control
		var 应 := float((键表[键] as Dictionary).get("width", 40))
		if 格 == null or absf(格.size.x - 应) > 容差:
			_报("宽键 %s 宽 %s ≠ KeyDef %s" % [键, 格.size.x if 格 != null else "缺件", 应])


## 列表条 + 34 枚列表格：条 = KF:128 的 110 高、格 17 列 × 2 行距 42 居中、格内牌 36×36 居中。
func 验列表与底(窗: Control) -> void:
	var 底 := 窗.get_node_or_null("九宫列表底") as Control
	if 底 == null:
		_报("缺 九宫列表底")
	elif maxf(absf(底.position.y - (345.0 - 抬)), absf(底.size.y - 110.0)) > 容差:
		_报("九宫列表底 (%s,%s,%s,%s) ≠ (0,316,765,110)" % [底.position.x, 底.position.y, 底.size.x, 底.size.y])
	if 窗.get_node_or_null("九宫内容底") != null:
		_报("页里又出现自造的 九宫内容底 —— 时间轴 94 件里没有 MYellow(532)，窗框由宿主画")
	var x0 := int((765.0 - 17 * 42 - 2) / 2.0)
	var y0 := int((110.0 - 2 * 40 - 2) / 2.0)
	var 位表 := {}
	for 条 in 键槽:
		位表[int((条 as Dictionary)["position"])] = 条	# ⚠ 数组顺序 ≠ position 顺序（拔旗 pos30 排在 上 pos25 之前）
	var 带牌 := 0
	for i in range(34):
		var 全 := "列格%d" % i
		var 列 := 窗.get_node_or_null(NodePath(全)) as Control
		if 列 == null:
			_报("缺件：%s" % 全)
			continue
		var 局 := [float(x0 + i % 17 * 42), 345.0 - 抬 + y0 + int(i / 17.0) * 42.0, 40.0, 40.0]
		var d := maxf(maxf(absf(列.position.x - 局[0]), absf(列.position.y - 局[1])),
				maxf(absf(列.size.x - 40.0), absf(列.size.y - 40.0)))
		if d > 容差:
			_报("%s 实测 (%s,%s) ≠ KF:131-143 的 (%s,%s)" % [全, 列.position.x, 列.position.y, 局[0], 局[1]])
		var 牌 := 列.get_node_or_null("牌") as TextureRect
		if 位表.has(i):
			if 牌 == null:
				_报("%s 没有牌（KLC:44-49 非忍术槽必铺 KeyboardShortcurIconF）" % 全)
				continue
			带牌 += 1
			if maxf(absf(牌.position.x - 2.0), absf(牌.position.y - 2.0)) > 容差:
				_报("%s/牌 落点 (%s,%s) ≠ (40−36)/2 = (2,2)" % [全, 牌.position.x, 牌.position.y])
			var 字 := 牌.get_node_or_null("牌字") as Label
			var 应 := 牌文(String((位表[i] as Dictionary)["文"]))
			if 字 == null or 字.text != 应:
				_报("%s/牌/牌字 = %s ≠ 槽名 %s（KSI:31-44 宋体分支）" % [
					全, 字.text if 字 != null else "缺件", 应])
		elif 牌 != null:
			_报("%s 是第 %d 位、原版 31 条槽之外，不该有牌" % [全, i])
	if 带牌 != 键槽.size():
		_报("带牌的列表格 %d ≠ %d 条动作槽" % [带牌, 键槽.size()])


## 四枚操作钮：KF:109-120 的宽 32/32/54/54 与右对齐链，文案按语言表。
func 验操作钮(窗: Control) -> void:
	var 右 := 765.0 - 14.0 - 54.0
	var 表 := {"钮全部消除": [右, 54.0, "KEYBOARD_OPERATE_BTNS_4"],
			"钮全部重置": [右 - 54.0 - 5.0, 54.0, "KEYBOARD_OPERATE_BTNS_3"],
			"钮取消": [右 - 54.0 - 5.0 - 32.0 - 54.0, 32.0, "KEYBOARD_OPERATE_BTNS_2"],
			"钮确定": [右 - 54.0 - 5.0 - 32.0 - 54.0 - 32.0 - 5.0, 32.0, "KEYBOARD_OPERATE_BTNS_1"]}
	for 名 in 表:
		var 录: Array = 表[名]
		var 钮 := 窗.get_node_or_null(NodePath(String(名))) as TextureButton
		if 钮 == null:
			_报("缺件：%s" % 名)
			continue
		var d := maxf(maxf(absf(钮.position.x - 录[0]), absf(钮.position.y - (317.0 - 抬))),
				maxf(absf(钮.size.x - 录[1]), absf(钮.size.y - 22.0)))
		if d > 容差:
			_报("%s 实测 (%s,%s,%s,%s) ≠ KF:109-120 (%s,%s,%s,22)" % [
				名, 钮.position.x, 钮.position.y, 钮.size.x, 钮.size.y, 录[0], 317.0 - 抬, 录[1]])
		var 字 := 钮.get_node_or_null(NodePath("字" + String(名).trim_prefix("钮"))) as Label
		var 应 := String(语(String(录[2])))
		if 字 == null or 字.text != 应:
			_报("%s 文字 = %s ≠ 语言表 %s" % [名, 字.text if 字 != null else "缺字件", 应])
		if 钮.stretch_mode != TextureButton.STRETCH_SCALE:
			_报("%s stretch_mode=%s 应为 SCALE（原版 isScale9Grid=false ⇒ 整张非等比拉）" % [名, 钮.stretch_mode])


## 五枚方案钮 + 保存方案：KF:766-793。文案在 SWF 资源包里（`快捷键_补文案.json`），不能空白。
func 验方案钮(窗: Control) -> void:
	var 前 := String(补文["KEYBOARD_SCHEME_PREFIX"])
	var 空 := String(补文["KEYBOARD_SCHEME_EMPTY_SUFFIX"])
	for i in range(1, 6):
		var 名 := "钮方案%d" % i
		var 钮 := 窗.get_node_or_null(NodePath(名)) as TextureButton
		if 钮 == null:
			_报("缺件：%s" % 名)
			continue
		var d := maxf(absf(钮.position.x - (14.0 + (i - 1) * 75.0)), absf(钮.size.x - 72.0))
		if d > 容差 or absf(钮.position.y - (317.0 - 抬)) > 容差:
			_报("%s 实测 (%s,%s,%s) ≠ KF:766-785 (%s,%s,72)" % [
				名, 钮.position.x, 钮.position.y, 钮.size.x, 14.0 + (i - 1) * 75.0, 317.0 - 抬])
		var 字 := 钮.get_node_or_null(NodePath("字" + 名.trim_prefix("钮"))) as Label
		var 应 := 前 + str(i) + 空		# KF:806 首次进游戏无已存方案 ⇒ 都带「(空)」
		if 字 == null or 字.text != 应:
			_报("%s 文字 = %s ≠ %s（表里缺键时曾渲成空白）" % [名, 字.text if 字 != null else "缺字件", 应])
		var 选中 := String(钮.get_meta("skin", "")).ends_with("钮底选中")
		if 选中 != (i == 1):
			_报("%s 皮 %s ⇒ selected 态与 KF:795-812 的 selectedScheme=1 不符" % [名, 钮.get_meta("skin", "")])
	var 存 := 窗.get_node_or_null("钮保存方案") as TextureButton
	if 存 == null or absf(存.position.x - 392.0) > 容差:
		_报("钮保存方案 缺失或 x=%s ≠ KF:786-793 的 14+5·75+3=392" % (存.position.x if 存 != null else "缺件"))
	else:
		var 字 := 存.get_node_or_null("字保存方案") as Label
		if 字 == null or 字.text != String(补文["KEYBOARD_SCHEME_SAVE"]):
			_报("钮保存方案 文字 = %s ≠ %s" % [字.text if 字 != null else "缺字件", 补文["KEYBOARD_SCHEME_SAVE"]])


## `KeyDef` 里 canSet=false 的格（ESC/Shift/Ctrl/方向键…）原版**不挂事件** ⇒ 不吃鼠标、也没有牌。
func 验不可绑(窗: Control) -> void:
	var 查 := 0
	for 键 in 键表:
		if bool((键表[键] as Dictionary).get("canSet", true)):
			continue
		var 格 := 窗.get_node_or_null(NodePath("格" + String(键) + "Cell")) as Control
		if 格 == null:
			continue
		查 += 1
		if 格.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			_报("不可绑的格 %s 还吃鼠标（mouse_filter=%s）" % [键, 格.mouse_filter])
		if 格.get_node_or_null("牌") != null:
			_报("不可绑的格 %s 烘了牌（原版 KF:100-105 不给它挂监听，永远绑不上）" % 键)
	if 查 < 20:
		_报("只核到 %d 枚不可绑格（表里应有 26 枚）⇒ 断言范围不够" % 查)
	# 反向：可绑格必须人手一张牌（未绑 hidden），否则运行期绑上时无皮可显
	var 可绑 := 0
	for 键 in 键表:
		if not bool((键表[键] as Dictionary).get("canSet", true)):
			continue
		var 格 := 窗.get_node_or_null(NodePath("格" + String(键) + "Cell")) as Control
		if 格 != null and 格.get_node_or_null("牌") != null:
			可绑 += 1
	if 可绑 < 60:
		_报("只有 %d 枚可绑格带牌（可绑共 60 枚）⇒ 拖放上去会显不出动作" % 可绑)


func 牌文(名: String) -> String:
	if 名.length() == 2:
		return "\n" + 名
	if 名.length() == 3:
		return "　" + 名
	return 名


## 钮上文案直接回**原始语言表**查（工程外的绝对路径，headless 下 FileAccess 读得到），
## 不让生成器当二传手 —— 生成器把文案抄错也照样自证自绿。
## AS3 字面量 `"KEY":"VALUE"` → 字典。**值里可以有 `\"` 转义**（原版有 281 处），
## 所以别用无脑正则，逐行取第一个 `":"` 与行尾 `",` 之间的内容再反转义 —— 与
## `开发工具/原版数据.py:_语言行/_反转义` 同口径。
func 语(键: String) -> String:
	if _语.is_empty():
		_语 = _读语言表(语言表())
	if (_语 as Dictionary).has(键):
		return String(_语[键])
	# 语言表在**作者机器上**（`../2.2.3/...`），换台机器整表读不到 —— 那是环境耦合，不是文案错。
	# 第二真源 = 本工程自带的 `数据/界面/快捷键_补文案.json`（逐键写了出处）。
	# 两边都没有才报缺键：**不许静默回退成生成器抄的那份**（那等于自证）。
	if 补文.has(键):
		return String(补文[键])
	return "«语言表与补文案都缺这一键 %s»" % 键


func _读语言表(路径: String) -> Dictionary:
	var 出 := {}
	var f := FileAccess.open(路径, FileAccess.READ)
	if f == null:
		return 出		# 读不到就空表 —— 上面那个 «语言表缺键» 会把红报出来，不会静默变绿
	while not f.eof_reached():
		var 行 := f.get_line().strip_edges()
		var 冒号 := 行.find('":"')
		if not 行.begins_with('"') or 冒号 < 0:
			continue
		var 值 := 行.substr(冒号 + 3)
		值 = 值.trim_suffix(",").trim_suffix(";").strip_edges()
		if 值.ends_with('"'):
			值 = 值.substr(0, 值.length() - 1)
		值 = 值.replace('\\"', '"').replace("\\\\", "\\")
		出[行.substr(1, 冒号 - 1)] = 值
	return 出


func 验拖放(窗: Control, 宿: Node) -> void:
	# 开窗时的默认态：人物→c、背包→b（KeyDef 的 defaultKeyId），牌就该亮在这两枚上
	var 快照: Dictionary = (窗.get("_原绑") as Dictionary).duplicate(true)
	if String(快照.get("KEYBOARD_SHORTCUT_KEY_CHAR", "")) != "c":
		_报("默认绑定没烘对：人物 应绑 c，实得 %s" % 快照.get("KEYBOARD_SHORTCUT_KEY_CHAR"))
	验牌(窗, "c", "人物")
	验牌(窗, "b", "背包")
	# 把「人物」拖到 bCell ⇒ b 牌改「人物」，且原格 c 灭牌、原本占着 b 的「背包」被摘掉
	窗.call("_放格", "b", Vector2(0, 0), {"类": "槽", "键": "KEYBOARD_SHORTCUT_KEY_CHAR"})
	验牌(窗, "b", "人物")
	验牌(窗, "c", "")
	var 绑: Dictionary = 窗.get("_绑")
	if String(绑.get("KEYBOARD_SHORTCUT_KEY_BAG", "")) != "":
		_报("b 被人物占了，背包 还留着 b（原版落点先摘旧动作，KF:416-420）：%s"
			% 绑.get("KEYBOARD_SHORTCUT_KEY_BAG"))
	# 格上的小字永远是键名，不能被动作名顶掉
	var 字 := (窗.get_node("格bCell") as Control).get_node("字bCell") as Label
	if 字.text != "B":
		_报("拖放后 b 格键名被改成 %s（原版 keyTextField 恒显键名）" % 字.text)
	# 反向：把 f 格拖到「背包」槽 ⇒ 人物（正占 f）被清，背包 落到 f
	窗.call("_放格", "f", Vector2(0, 0), {"类": "槽", "键": "KEYBOARD_SHORTCUT_KEY_CHAR"})
	窗.call("_放列", "KEYBOARD_SHORTCUT_KEY_BAG", Vector2(0, 0), {"类": "格", "键": "f"})
	绑 = 窗.get("_绑")
	if String(绑.get("KEYBOARD_SHORTCUT_KEY_BAG", "")) != "f":
		_报("拖到列表槽后 背包 应指向 f，实得 %s" % 绑.get("KEYBOARD_SHORTCUT_KEY_BAG"))
	if String(绑.get("KEYBOARD_SHORTCUT_KEY_CHAR", "")) != "":
		_报("f 已改绑给背包，人物 还留着 f（一动作一键没生效）：%s" % 绑.get("KEYBOARD_SHORTCUT_KEY_CHAR"))
	验牌(窗, "f", "背包")
	if not bool(窗.call("有改动")):
		_报("拖放后没标脏（原版 isChange 决定确定时发不发）")


## 某键格上牌的现状：期望 "" = 牌必须灭着。
func 验牌(窗: Control, 键: String, 应: String) -> void:
	var 格 := 窗.get_node_or_null(NodePath("格" + 键 + "Cell")) as Control
	if 格 == null:
		_报("缺件：格%sCell" % 键)
		return
	var 牌 := 格.get_node_or_null("牌") as TextureRect
	if 牌 == null:
		_报("格%sCell 没有牌（可绑格应人手一张，未绑 hidden）" % 键)
		return
	var 字 := 牌.get_node_or_null("牌字") as Label
	if 应.is_empty():
		if 牌.visible:
			_报("格%s 不该有绑定，牌还亮着写 %s" % [键, 字.text])
		return
	if not 牌.visible or 字.text != 牌文(应):
		_报("格%s 牌 = %s（visible=%s）≠ %s" % [键, 字.text, 牌.visible, 牌文(应)])


func 验取消(窗: Control, 宿: Node) -> void:
	var 快照: Dictionary = (窗.get("_原绑") as Dictionary).duplicate(true)
	(窗.get_node("钮取消") as TextureButton).pressed.emit()
	var 写: Array = 宿.get("写")
	if 写.size() > 0:
		_报("点取消却写了会话（原版取消纯 UI 回滚，KF:736-744）：%s" % 写)
	var 绑: Dictionary = 窗.get("_绑")
	for 条 in 键槽:
		var 键 := String((条 as Dictionary)["语言键"])
		if String(绑.get(键, "")) != String(快照.get(键, "")):
			_报("取消没回滚：%s 从 %s 变成 %s" % [键, 快照.get(键), 绑.get(键)])
			break
	验牌(窗, "c", "人物")		# 回滚后牌也要跟着回去


func 验确定(窗: Control, 宿: Node) -> void:
	窗.call("恢复默认")
	(窗.get_node("钮确定") as TextureButton).pressed.emit()
	var 设: Dictionary = (宿.get("_session") as Node).get("game_settings")
	if not 设.has("keybind_KEYBOARD_SHORTCUT_KEY_CHAR"):
		_报("确定后没落 keybind_*：%s" % 设.keys().slice(0, 6))
	var 动: Array = 宿.get("动作")
	if not 动.has("快捷键窗|确定"):
		_报("确定没把动作交回宿主（原版这里要发 requestKeyChange，本工程只交回出口）：%s" % 动)
	# 全部重置 = 回基本设定；全部消除 = 抹干净（KF:300-307 两枚不是一回事）
	# ⚠️ 2026-10-11 起这两枚**先弹二次确认**（原版 `KF:306` 全部重置 / `:761` 全部消除
	#    都走 `MDialog.showMessageDialog`）⇒ 按了钮只出框、**还没动手**，点「确定」才生效。
	#    判据钉的是行为：出框且点了确定才变 —— 不是"钮在不在"。
	var 前绑: Dictionary = (窗.get("_绑") as Dictionary).duplicate(true)
	(窗.get_node("钮全部消除") as TextureButton).pressed.emit()
	var 框 := _确认框(宿)
	if 框 == null:
		_报("按「全部消除」没弹二次确认框（原版 KF:761 是 showMessageDialog）")
	else:
		if String(窗.call("取绑", "KEYBOARD_SHORTCUT_KEY_CHAR")) != String(前绑.get("KEYBOARD_SHORTCUT_KEY_CHAR", "")):
			_报("确认框还没点确定，绑定就已经被抹了")
		(框.find_child("确定", true, false) as Button).pressed.emit()
		for 条 in 键槽:
			if not String(窗.call("取绑", String((条 as Dictionary)["语言键"]))).is_empty():
				_报("点「确定」后「全部消除」没抹干净：%s 还有绑定 %s" % [条["文"], 窗.call("取绑", 条["语言键"])])
				break
	# 「取消」= 一点不动（原版 `cancelAll(param1)` 只在 `param1 == MDialog.OK` 时才动手）
	窗.call("恢复默认")
	(窗.get_node("钮全部重置") as TextureButton).pressed.emit()
	var 框2 := _确认框(宿)
	if 框2 == null:
		_报("按「全部重置」没弹二次确认框（原版 KF:306）")
	else:
		(框2.find_child("取消", true, false) as Button).pressed.emit()
		if String(窗.call("取绑", "KEYBOARD_SHORTCUT_KEY_CHAR")) != "c":
			_报("点了「取消」绑定却动了：人物 = %s（应保持 c）" % 窗.call("取绑", "KEYBOARD_SHORTCUT_KEY_CHAR"))
		(窗.get_node("钮全部重置") as TextureButton).pressed.emit()
		var 框3 := _确认框(宿)
		if 框3 == null:
			_报("第二次按「全部重置」没弹框")
		else:
			(框3.find_child("确定", true, false) as Button).pressed.emit()
			if String(窗.call("取绑", "KEYBOARD_SHORTCUT_KEY_CHAR")) != "c":
				_报("点「确定」后 人物 没回到基本设定 c，实得 %s" % 窗.call("取绑", "KEYBOARD_SHORTCUT_KEY_CHAR"))


## 宿主的遮罩上那枚「消息确认框」。
## ⚠️ 按**标记**找，不按名字：连着弹两枚时 Godot 会把后一枚改名 `@Control@N`
##   （`输入确认弹.gd` 自己注释过这条）；`queue_free()` 也是延迟的 ⇒ 跳过待回收的那枚。
func _确认框(宿: Node) -> Control:
	var 遮罩: Control = 宿.get("_overlay")
	if 遮罩 == null:
		return null
	var 出: Control = null
	for 子 in 遮罩.get_children():
		if 子.is_queued_for_deletion():
			continue
		if 子.has_meta("mdialog") and String(子.get_meta("mdialog")) == "message":
			出 = 子 as Control
	return 出


func _报(话: String) -> void:
	_红 += 1
	print("!! " + 话)
