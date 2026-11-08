extends SceneTree
## 二级密码六窗（原版 `com.mxw.uifl.controls.twoPassword.*` + 2309 全族）离线门（#48，§3.225）。
## 逐件参照值手抄自 `真值/窗口/二级密码.md` 与 `2.2.3/.../controls/twoPassword/*.as`，
## **不从被测代码反查**：六张矩形表、每一条文案、每一个动作号都在本文件里另抄一份。
##
## 覆盖：
##   ① 尺寸表六条（384×382 / 270×340 / 270×340 / 315×340 / 315×344 / 270×225，全 `整框` +
##      `内容底:false` + 无 `原点`）+ 标题（含 一格/三格 共用「二级密码设置嚮导」、二格 挂「二级密码说明」
##      那两笔原版串门）+ 只有 解锁 进 `居中弹`、六扇都不进 `伴随背包`
##   ② 2309 **解码**：11 种动作各一帧（形状按 `handleAction` 的 case）、
##      四个服务端数各写对（2→类型、5→删除次数=值[2]、6→修改次数=值[1]、8→已解锁、9→值[1]、10→值[0]）、
##      三条坏帧（空帧 / 动作号不认识 / int 少一根）整帧丢弃、
##      **大小端两针**：utf 长度前缀写大端 ⇒ 丢弃；int 写大端 ⇒ 读出 16777216 ⇒ `已解锁` 仍旧 false
##   ③ 上行线格式：`{"action":N,"values":[…]}` 裸 JSON、opcode 2309、**int 也转成字符串**、
##      动作号越界 ⇒ 一条不发
##   ④ 背包那颗「二级密码」= **只发上行 0、一扇窗都不开**（开窗的是回帧 2）+ 缺口表里不再有它
##   ⑤ 状态机十一条腿（含三条原版呆账：帧 3 **不读结果号**、帧 0 失败腿**整条是空的**、
##      帧 6 两支**都不弹字**）+ 帧 1/4/6/9/10 的「建过没建过」闸（建过≠开着）+ 帧 7 走 `打开`（每次回正中）
##      + `打开或收起` 是**开关**（同帧连喂两次 ⇒ 第二次收起）
##   ⑥ 十二路上行判式：一格两枚都要 ≥6 位（`||` 那一支）／不等只弹一句；二格**只判邮箱**
##      （手机/QQ 空着照发）＋ 正则只从**串首**试 ＋ 草稿只写进成功腿；三格 Type1 五句按序
##      **且草稿写在判式之前**、发 3 **不关窗**；Type2 跟**本地草稿**比；Type3「取消」只关窗、
##      「删除」两枚答案任一空即拦；修改四条按序 + 发 7 **不关窗**；解锁空拦、非空发 8 后清输入
##   ⑦ 六页逐件矩形 + 页根尺寸 + 三枚现量提示的高度（66 / 51 / 36 / 21）
##   ⑧ 下拉七项、选「自订」清两格、选别项收那枚输入、菜单提层 z=50、关窗收菜单
##   ⑨ 两份账：四个服务端数只从 `authoritative_second_password` 读；七枚草稿跨窗跨开关活着；
##      三格标题被 Type3 改过之后**再也回不去**；解锁窗的输入**是唯一不留草稿**的那扇
##
## ⚠ 按钮一律 `pressed.emit()`（同 `随身药店仓库回归测试._点`）：六扇窗会同时挂在台上，
##   真鼠标会被层叠的遮罩挡住 ⇒ 判式那条腿用 `disabled` 属性直接钉（那才是真点击被拦的原因）。
##
## 跑法：`Godot --headless --path . --script res://测试/二级密码窗回归测试.gd`

const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 尺寸表路径 := "res://数据/界面/窗口尺寸.json"
const 管理脚本 := preload("res://脚本/界面/窗口管理.gd")
const 背包脚本 := preload("res://脚本/界面/窗口/背包窗口.gd")
const 页脚本 := preload("res://脚本/界面/窗口/二级密码/二级密码窗.gd")
const 测试后端 := preload("res://测试/测试后端连接.gd")

const 六页 := ["二级密码说明", "二级密码设置", "二级密码资料", "二级密码问题", "二级密码修改", "二级密码解锁"]
const 尺寸 := {
	"二级密码说明": [384, 382, "二级密码说明"],
	"二级密码设置": [270, 340, "二级密码设置嚮导"],
	"二级密码资料": [270, 340, "二级密码说明"],
	"二级密码问题": [315, 340, "二级密码设置嚮导"],
	"二级密码修改": [315, 344, "二级密码修改"],
	"二级密码解锁": [270, 225, "解除锁定"],
}
## 页根 = 外框高 − 29（标题那条容器原点 (0,29)）。
const 页尺 := {
	"二级密码说明": [384.0, 353.0], "二级密码设置": [270.0, 311.0],
	"二级密码资料": [270.0, 311.0], "二级密码问题": [315.0, 311.0],
	"二级密码修改": [315.0, 315.0], "二级密码解锁": [270.0, 196.0],
}

## ── 六张矩形表（手抄自真值 §②，**与 `二级密码窗.gd` 里那六张是两份独立的抄件**）──────
const 期说明 := {
	"底2": [6.0, 11.0, 372.0, 310.0],		# `TwoPasswordSayWindow.as:88-89` + `doLayout:81-82`
	"底3": [11.0, 16.0, 362.0, 300.0],		# `:91-92`
	"正文": [16.0, 21.0, 364.0, 290.0],		# `:94-100` 宽 = 底2宽−8、高 = 底3高−10
	"设置密码": [50.0, 326.0, 61.0, 22.0],	# `:101-106` `int((384−61×3)/4) = 50`
	"解除锁定": [161.0, 326.0, 61.0, 22.0],	# x = 50+61+50
	"修改密码": [272.0, 326.0, 61.0, 22.0],	# x = 161+61+50
}
const 期一格 := {
	"底2": [6.0, 11.0, 258.0, 260.0],		# `SetPasswordPane1.as:100-102` 底2 高**写死 260**
	"底3": [11.0, 16.0, 248.0, 250.0],		# `:103-105`
	"步骤": [16.0, 21.0, 248.0, 20.0],		# `:106-107`
	"请输入": [11.0, 41.0, 248.0, 20.0],		# `:113-114` y = 108−23−15
	"密码输入": [73.0, 79.0, 123.0, 23.0],	# `:109-112` x = 11+int((248−123)/2)
	"请再次": [11.0, 145.0, 248.0, 20.0],	# `:119-120` y = 209−20−15
	"确认输入": [73.0, 180.0, 123.0, 23.0],	# `:115-118` y = 108+23+78
	"提示": [11.0, 238.0, 248.0, 20.0],		# `:121-122` y = 209+23+35
	"下一步": [110.0, 276.0, 49.0, 22.0],	# `:123-124` x = int((270−49)/2)
}
const 期二格 := {
	"底2": [6.0, 11.0, 258.0, 260.0],		# `SetPasswordPane2.as:74-79`
	"底3": [11.0, 16.0, 248.0, 250.0],
	"步骤": [16.0, 21.0, 248.0, 20.0],		# `:80-81`
	"标题行": [16.0, 41.0, 248.0, 20.0],		# `:82-83`
	"联系方式": [16.0, 61.0, 248.0, 20.0],	# `:84-85`
	"邮箱": [21.0, 84.0, 65.0, 20.0],			# `:86-91` x = 底x−65、y = 底y + int((23−20)/2)
	"邮箱输入": [86.0, 83.0, 123.0, 23.0],	# x = 11+75、y = 45+67
	"手机": [21.0, 117.0, 65.0, 20.0],			# `:92-97` 步长 = 23+10
	"手机输入": [86.0, 116.0, 123.0, 23.0],
	"号码QQ": [21.0, 150.0, 65.0, 20.0],		# `:98-103`
	"QQ输入": [86.0, 149.0, 123.0, 23.0],
	"提示": [11.0, 187.0, 248.0],				# `:104-105` y = 178+23+15；高现量
	"下一步": [110.0, 276.0, 49.0, 22.0],		# `:106-107`
}
const 期三格 := {
	"底2": [6.0, 11.0, 303.0, 260.0],		# `SetPasswordPane3.as:222-227`
	"底3": [11.0, 16.0, 293.0, 250.0],
	"步骤": [16.0, 21.0, 293.0, 20.0],		# `:228-229`
	"问题1": [21.0, 41.0, 293.0, 20.0],		# `:230-231` x = 底3.x+10
	"下拉1": [61.0, 61.0, 210.0, 20.0],		# `:232-235` x = 底3.x+50
	"自订1": [61.0, 62.0, 190.0, 20.0],		# `:301` 宽 = 210−20、y = 下拉+1
	"答案1": [21.0, 81.0, 293.0, 20.0],		# `:236-237` y = 90+20
	"答案输入1": [61.0, 101.0, 210.0, 23.0],	# `:238-241` y = 110+20
	"问题2": [21.0, 124.0, 293.0, 20.0],		# `:242-243` y = 130+23
	"下拉2": [61.0, 144.0, 210.0, 20.0],		# `:244-247` y = 153+20
	"自订2": [61.0, 145.0, 190.0, 20.0],
	"答案2": [21.0, 164.0, 293.0, 20.0],		# `:248-249` y = 173+20
	"答案输入2": [61.0, 184.0, 210.0, 23.0],	# `:250-253` y = 193+20
	"提示": [16.0, 212.0, 293.0],				# `:254-255` y = 213+23+5；高现量
	"上一步": [72.0, 276.0, 49.0, 22.0],		# `:256-260` `int((315−98)/3) = 72`
	"下一步": [193.0, 276.0, 49.0, 22.0],		# x = 72+49+72（**不是 70**）
}
const 期修改 := {
	"底2": [6.0, 11.0, 303.0, 270.0],		# `UpdatePasswordWindow.as:63-65`
	"底3": [11.0, 16.0, 293.0, 92.0],			# `:66-68`
	"底4": [11.0, 113.0, 293.0, 164.0],		# `:69-71` y = 45+92+5
	"旧": [16.0, 26.0, 293.0, 20.0],			# `:72-73`
	"旧输入": [90.0, 56.0, 123.0, 23.0],		# `:74-77` ⚠ **90 不是 96**：`+` 绑得比 `>>` 紧
	"新": [16.0, 123.0, 293.0, 20.0],			# `:78-79`
	"新输入": [90.0, 153.0, 123.0, 23.0],		# `:80-83` y = 152+20+10
	"再次": [16.0, 186.0, 293.0, 20.0],		# `:84-85` y = 182+23+10
	"再次输入": [90.0, 216.0, 123.0, 23.0],	# `:86-89` y = 215+20+10
	"次数": [11.0, 249.0, 293.0, 20.0],		# `:90-91` 居中
	"修改": [80.0, 286.0, 37.0, 22.0],			# `:92-96` `int((315−74)/3) = 80`
	"取消": [197.0, 286.0, 37.0, 22.0],		# x = 80+37+80
}
const 期解锁 := {
	"底2": [6.0, 11.0, 258.0, 146.0],		# `UnchainLookWindow.as:64-66`
	"底3": [11.0, 16.0, 248.0, 136.0],
	"正文": [11.0, 41.0, 248.0, 20.0],			# `:70-71` y = 45+25、**16 号居中**
	"请输入": [16.0, 87.0, 65.0, 20.0],			# `:74-75` x = 底3.x+5、**右对齐**
	"密码输入": [80.0, 86.0, 123.0, 23.0],		# `:72-73` x = 11+65+4、y = 70+20+25
	"确定": [65.0, 162.0, 37.0, 22.0],			# `:78-82` `int((270−74)/3) = 65`
	"取消": [167.0, 162.0, 37.0, 22.0],			# x = 65+37+65
}
const 期窗件 := {
	"二级密码说明": 期说明, "二级密码设置": 期一格, "二级密码资料": 期二格,
	"二级密码问题": 期三格, "二级密码修改": 期修改, "二级密码解锁": 期解锁,
}

## ── 文案（逐条从 `en_US$message_properties.as` 手抄，键后是行号）─────────────────
const 期文 := {
	"设置密码": "设置密码",					# SETPASSWORD_BTN_TEXT :2295
	"删除密码": "删除密码",					# DELETE_PASSWORD :764
	"解除锁定": "解除锁定",					# UNCHAINLOOK_BTN_TEXT :34
	"修改密码": "修改密码",					# UPDATEPASSWORD_BTN_TEXT :1304
	"一格步骤": "1/3二级密码设置",			# SEPPASSWORDPANE_1_TEXT_1 :925
	"一格已设": "你已经设置了密码保护问题",	# TEXT_5 :917
	"不一致": "密码与确认密码不一致",			# SEPPASSWORDPANE_1_TEXT_6 :916
	"下一步": "下一步",						# NEXT_BTN_TEXT :624
	"上一步": "上一步",						# LAST_BTN_TEXT :2918
	"完成": "完成",							# WANCHENG :2142
	"取消": "取消",							# COMMON_CANCEL :1906
	"确定": "确定",							# COMMON_OK :2325
	"修改": "修改",							# UPDATE_BTN_TEXT :2086
	"删除": "删除",							# FRIEND_DEL :1665
	"邮箱错": "您输入的邮箱不正确",			# SEPPASSWORDPANE_2_TEXT_8 :1874
	"三格标题": "二级密码设置嚮导",			# SEPPASSWORDPANE_3_TITLE :964
	"三格标题2": "二级密码删除",				# SEPPASSWORDPANE_3_TITLE_2 :2224
	"步骤设置": "2/3：密码保护资讯设置",		# SEPPASSWORDPANE_3_TEXT_8 :243
	"步骤确认": "3/3：密码保护资讯设置",		# TEXT_14 :859
	"提示设置": "以上资讯一经填写将不可更改或删除",	# TEXT_13 :861
	"提示确认": "以上是您刚刚设置的密保资讯",	# TEXT_15 :857
	"提示删除": "今天你还可以进行",			# TEXT_18 :852
	"答案注": "（答案长度最多为40位）",		# TEXT_10 :864 / TEXT_12 :862
	"答案裸": "答案1: ",						# TEXT_16 :856（Type2/3 那一句没有红字注）
	"问题重": "两次密码保护问题不能重复",		# SEPPASSWORDPANE_3_NOTICE_2 :1529
	"问题1空": "请选择问题1",					# NOTICE_3 :1528
	"问题2空": "请选择问题2",					# NOTICE_4 :1527
	"答案1空": "请输入答案1",					# NOTICE_5 :1524
	"答案2空": "请输入答案2",					# NOTICE_6 :1522
	"答案不认": "密码保护答案不一致",			# NOTICE_7 :1521
	"答案空": "请输入答案",					# NOTICE_1 :1532
	"旧密码空": "请输入旧密码",				# UPDATEPASSWORD_WINDOW_NOTICE_1 :2739
	"新密码空": "请输入新密码",				# NOTICE_2 :2738
	"确认空": "请输入确认新密码",			# NOTICE_3 :2737
	"次数句": "您今天还可以进行",			# UPDATEPASSWORD_WINDOW_TEXT_1 :66
	"密码空": "请输入密码！",					# UNCHAINLOOK_WINDOW_NOTICE_1 :1365
	"解锁正文": "请输入二级密码进行解锁",		# UNCHAINLOOK_WINDOW_TEXT_1 :1686
	"设置失败": "设置二级密码失败",			# TWOPASSWORD_NOTICE_1 :2190
	"设置成功": "二级密码设置成功",			# NOTICE_2 :2188
	"删除成功": "删除密码成功",				# NOTICE_7 :2171
	"删除失败": "删除密码失败，今天还可以删除",	# NOTICE_8 :2168
}
const 期问题项 := ["请选择问题类型", "你的中学校名是？", "你的生日是？", "你的配偶的姓名是？",
		"你的父亲的姓名是？", "你的母亲的姓名是？", "自订"]	# `SetPasswordPane3.as:24` 的 _dataProvider

var 通过 := 0
var 失败 := 0
var 跑完了 := false
var 帧数 := 0
var 后: Node = null
var 会话: Node = null
var 管: Node = null
var 假: Node = null
var 通告: Array = []
var 帧录: Array = []


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 话)


## 看门狗：门里任何一处运行期报错都会让协程半路断掉 ⇒ `quit()` 永远轮不到、
## 无头进程挂着不出红（工程已栽过）。约 90 秒到点就老实认红。
func _process(秒: float) -> bool:
	帧数 += 1
	if 帧数 > 5400 and not 跑完了:
		print("红：门超时未跑完（约 90 秒），后面的判据没执行")
		print("二级密码窗离线门：通过 %d，红 %d" % [通过, 失败 + 1])
		quit(1)
		return true
	return false


func _initialize() -> void:
	await _跑()
	if not 跑完了:
		失败 += 1
		print("红：门自己没跑完（协程中途报错），汇总行没打出来")
	quit(1 if 失败 > 0 else 0)


static func 去BOM(文: String) -> String:
	return 文.trim_prefix("\uFEFF")


func _等(次: int = 3) -> void:
	for i in 次:
		await process_frame


## 页本体是代码现搭的（`_新页` 挂在宿主的具名变量上）⇒ 每腿现取，别攥着旧句柄：
## 页在 `close` 之后仍活着，但 `打开` 会整页重建（原版 `initWindow` 挂在 `onAddToStage`）。
func _页(窗: Node) -> Control:
	var 页 = 窗.get("_二级密码页")
	if 页 == null or not is_instance_valid(页):
		return null
	return 页 as Control


func _件(窗: Node, 名: String) -> Node:
	var 页 := _页(窗)
	return null if 页 == null else 页.get_node_or_null(名)


func _矩(件: Control) -> Array:
	return [件.position.x, 件.position.y, 件.size.x, 件.size.y]


func _近(实: Array, 参: Array) -> bool:
	if 实.size() != 参.size():
		return false
	for i in 参.size():
		if absf(float(实[i]) - float(参[i])) > 0.51:
			return false
	return true


## 参照值给三格（x/y/宽）= 高由 Flash 的 `textHeight + 6` **现量**，另有一条高度判据单独钉；
## 给四格（x/y/宽/高）= 写死的。六张表混用这两种，所以比对也要两种走。
func _矩形对(件: Control, 期: Array) -> bool:
	if 件 == null:
		return false
	var 实 := _矩(件)
	if 期.size() == 3:
		return _近([实[0], 实[1], 实[2]], 期)
	return _近(实, 期)


func _开着(窗: Node) -> bool:
	if 窗 == null:
		return false
	var 遮 = 窗.get("_overlay")
	return 遮 != null and (遮 as CanvasItem).visible


## 「建过」= 原版 `Boolean(API.ui.content.<getter>)`（`removeWindow:5294-5308` 从不清 `_windowMap`）
## ⇒ 判的是窗表里有没有这一只实例，**与开合无关**。端口就是 `_窗口们.has()`。
func _建过(页名: String) -> bool:
	return 管._窗口们.get(页名) != null


## 真鼠标之外的一切点法：`pressed.emit()`（口径见文件头那条 ⚠）。
## ⚠ 基类要写到 `BaseButton` 不能写 `Button`：下拉那两枚是 **TextureButton**
## （`Button` 的兄弟，不是子孙），`as Button` 直接给 null ⇒ 整条下拉腿会报「页里没有」。
func _按(窗: Node, 名: String) -> bool:
	var 钮 := _件(窗, 名) as BaseButton
	if 钮 == null:
		_判(false, "页里没有「%s」⇒ 这一腿无从跑起" % 名)
		return false
	钮.pressed.emit()
	return true


## 键入 = 赋值 + 手动补一次 `text_changed`（**赋 `.text` 不会自己发**，工程既有口径）。
func _输(窗: Node, 名: String, 词: String) -> void:
	var 框 := _件(窗, 名) as LineEdit
	if 框 == null:
		_判(false, "页里没有输入「%s」" % 名)
		return
	框.text = 词
	框.emit_signal("text_changed", 词)


func _文(窗: Node, 名: String) -> String:
	var 标 := _件(窗, 名) as RichTextLabel
	return "" if 标 == null else String(标.text)


## ── 2309 造帧：`<B 动作>` + `<H 长>+UTF-8` × 串数 + `<i` × 整数数（全小端）──────────
func _帧(动作: int, 串表: Array, 整数表: Array) -> PackedByteArray:
	var 体 := PackedByteArray()
	体.resize(1)
	体[0] = 动作
	for s in 串表:
		var b := String(s).to_utf8_buffer()
		var n := 体.size()
		体.resize(n + 2 + b.size())
		体.encode_u16(n, b.size())
		for i in b.size():
			体[n + 2 + i] = b[i]
	for v in 整数表:
		var m := 体.size()
		体.resize(m + 4)
		体.encode_s32(m, int(v))
	var 帧 := PackedByteArray()
	帧.resize(6 + 体.size())
	帧.encode_u16(4, 2309)		# 前 4 字节 = 校验和+sid，客户端**不验**，留 0
	for i in 体.size():
		帧[6 + i] = 体[i]
	return 帧


## 服务端那份账（四个数）永远写在**真后端**上，喂完一帧同步给假后端 ⇒
## 页面读的还是「后端那一本」，门里不许有第二本。
## ⚠ **共享同一本字典**，不是逐键复制：入帧那四个数写的是**真后端**那本，而 `刷三格`/`刷说明`
## 这类显示是在 `二级密码帧` 的信号处理里**同步**跑的 ⇒ 逐键复制永远慢一拍
## （帧 5 把删除次数写成 3，页上刷出来的还是旧的 7）。
## 断线复位会把 `authoritative_second_password` **整个重新赋值**（不是就地改），
## 所以每次喂帧之后都要重挂一次引用，不能一次挂死。
func _同步账() -> void:
	假.set("authoritative_second_password", 后.get("authoritative_second_password"))


func _设账(类: int, 改: int, 删: int, 解: bool) -> void:
	var 真: Dictionary = 后.get("authoritative_second_password")
	真["类型"] = 类
	真["修改次数"] = 改
	真["删除次数"] = 删
	真["已解锁"] = 解
	_同步账()


func _喂帧(动作: int, 串表: Array, 整数表: Array) -> void:
	后.call("_handle_original_frame", _帧(动作, 串表, 整数表))
	_同步账()


## 只造帧不校对形状 ⇒ 验坏帧那几条用裸 payload。
func _喂裸(动作: int, 尾: PackedByteArray) -> void:
	var 体 := PackedByteArray()
	体.resize(1 + 尾.size())
	体[0] = 动作
	for i in 尾.size():
		体[1 + i] = 尾[i]
	var 帧 := PackedByteArray()
	帧.resize(6 + 体.size())
	帧.encode_u16(4, 2309)
	for i in 体.size():
		帧[6 + i] = 体[i]
	后.call("_handle_original_frame", 帧)


## 把一扇窗摆到「建过 + 关着」这个确定态（`_备` 建实例并把后端换成假后端）。
func _备(页名: String) -> Node:
	var 窗: Node = 管.call("取或建窗口", 页名)
	窗.set("_backend", 假)
	## 无论上一节把它留在什么状态，出来都是**建过 + 关着**：`打开` 对已开的窗幂等
	## （`窗.call("打开")` 重跑一遍 `initWindow`），紧接着 `close` 一定收得掉。
	管.call("打开", 页名)
	窗.call("close")
	return 窗


func _擦() -> void:
	通告.clear()
	假.发过.clear()


## 假后端：`_backend` 走它（记上行），四个服务端数由真后端同步过来。
class 假后 extends Node:
	var in_game := true
	var authoritative_second_password := {"类型": 0, "修改次数": 0, "删除次数": 0, "已解锁": false}
	var 发过: Array = []

	func request_second_password(动作: int, 值: Array) -> bool:
		发过.append([动作, 值.duplicate()])
		return true


## 只会返回 false 的后端：钉「发送失败」那一句。
class 拒后 extends Node:
	var in_game := true
	var authoritative_second_password := {"类型": 0, "修改次数": 0, "删除次数": 0, "已解锁": false}

	func request_second_password(_动作: int, _值: Array) -> bool:
		return false


func _跑() -> void:
	print("二级密码窗离线门开始")
	await process_frame
	后 = root.get_node("BackendConnection")
	会话 = root.get_node_or_null("GameSession")
	_判(会话 != null, "门跑之前 `GameSession` 这个 autoload 必须在（`_通知` 没有判空，缺它就是整脚本崩）")
	后.set("in_game", false)
	root.size = Vector2i(960, 560)
	管 = (load(管理场景) as PackedScene).instantiate()
	root.add_child(管)
	假 = 假后.new()
	root.add_child(假)
	_同步账()
	会话.notification_requested.connect(func(文本: String) -> void: 通告.append(文本))
	后.connect("二级密码帧", func(动作: int, 值: Array) -> void: 帧录.append([动作, 值.duplicate()]))
	await _等(4)

	await _一_静态表()
	await _三_上行线格式()
	## ④ 排在 ② **前面**：② 那十一根帧里有四根会真的把窗开出来（2/5/7/10），
	## 而 ④ 判的正是「点背包入口**一扇都不建**」、② 开头判的也是「六扇还没建过时帧 1/4/6/9 空转」
	## —— 建过是**不可逆**的（`removeWindow` 从不清 `_windowMap`），顺序一颠倒这两条就永久红。
	await _四_背包入口()
	await _二_解码()
	await _五_说明窗()
	await _六_一格()
	await _七_二格()
	await _八_三格()
	await _九_修改窗()
	await _十_解锁窗()
	await _十一_呆账()

	跑完了 = true
	print("二级密码窗离线门：通过 %d，红 %d" % [通过, 失败])


## ── ① 尺寸表六条 + 两张名单 ────────────────────────────────────────────────────
func _一_静态表() -> void:
	var 表: Dictionary = JSON.parse_string(去BOM(FileAccess.get_file_as_string(尺寸表路径))) as Dictionary
	for 页名 in 六页:
		var 条: Dictionary = 表.get(页名, {}) as Dictionary
		var 期: Array = 尺寸[页名]
		_判(not 条.is_empty() and int(条.get("宽", -1)) == int(期[0]) and int(条.get("高", -1)) == int(期[1]),
				"尺寸表「%s」= %d×%d（`super(%d, %d)`），实得 %s×%s" % [
					页名, int(期[0]), int(期[1]), int(期[0]), int(期[1]),
					str(条.get("宽")), str(条.get("高"))])
		_判(String(条.get("标题", "")) == String(期[2]),
				"「%s」的标题 = 「%s」，实得「%s」（一格/三格 与 二格 那两笔串门是原版口径）" % [
					页名, 期[2], String(条.get("标题", ""))])
		_判(bool(条.get("整框", false)) and not bool(条.get("内容底", true))
				and not bool(条.get("小背景", true)) and not 条.has("原点"),
				"「%s」= 整框 true / 内容底 false / 小背景 false 且**不写原点**"
						% 页名 + "（六扇的 `底2` 自己就是内容板，容器原点 (0,29)）")
		_判(not 管理脚本.居中弹.has(页名) or 页名 == "二级密码解锁",
				"除解锁之外没有一扇进 `居中弹`（实得 %s）" % 页名)
	_判(管理脚本.居中弹.has("二级密码解锁"),
			"解锁**进** `居中弹`：`showUnchainLookWindow:5690-5698` = removeWindow + centerWindow(新建)")
	for 页名 in 六页:
		_判(not 管理脚本.伴随背包.has(页名), "「%s」不进 `伴随背包`（原版这六扇没有一处 centerTwoWindow）" % 页名)
	_判(not 背包脚本.缺的那一块.has("二级密码"),
			"背包的缺口表里**不再有**「二级密码」（实得 %s）" % str(背包脚本.缺的那一块.keys()))


## ── ② 解码 11 帧 + 三条坏帧 + 建过闸 ──────────────────────────────────────────
func _二_解码() -> void:
	# 此刻六扇都**没建过** ⇒ 帧 1/4/6/9 那四条「原地刷」的腿应当一条都不动、连字都不弹。
	for 动作 in [1, 4, 6, 9]:
		_擦()
		_喂帧(动作, [], [0, 0])
		_判(通告.is_empty() and 假.发过.is_empty(),
				"窗没建过时帧 %d ⇒ 零动作零提示（原版对 null 解引用抛异常、整帧作废）实得 通告=%s" % [动作, str(通告)])
	_擦()
	_喂帧(4, [], [0])
	_判(通告.is_empty(), "帧 4 连「设置失败」都不许弹（`Client.as:6445` 那句 `addNotice` 圈在 `Boolean(窗)` 里）")

	帧录.clear()
	_喂帧(0, [], [1])
	_喂帧(1, [], [1])
	_喂帧(2, [], [2])
	_喂帧(3, [], [0])
	_喂帧(4, [], [1])
	_喂帧(5, ["问题一", "问题二"], [3])
	_喂帧(6, [], [0, 4])
	_喂帧(7, [], [])
	_喂帧(8, [], [1])
	_喂帧(9, [], [0, 2])
	_喂帧(10, [], [5])
	var 期望 := [[0, [1]], [1, [1]], [2, [2]], [3, [0]], [4, [1]],
			[5, ["问题一", "问题二", 3]], [6, [0, 4]], [7, []], [8, [1]], [9, [0, 2]], [10, [5]]]
	var 一样 := 帧录.size() == 11
	for i in min(帧录.size(), 11):
		if str(帧录[i]) != str(期望[i]):
			一样 = false
	_判(一样, "11 种动作逐根读对（串在前、int 在后），实得 %s" % str(帧录))
	var 账: Dictionary = 后.get("authoritative_second_password")
	_判(int(账["类型"]) == 2, "`类型` ← 帧 2 那根 int（实得 %s）" % str(账["类型"]))
	_判(int(账["删除次数"]) == 2, "`删除次数` ← 帧 **9 的第二个 int**（帧 5 写过 3、被帧 9 盖成 2），实得 %s" % str(账["删除次数"]))
	_判(int(账["修改次数"]) == 5, "`修改次数` ← 帧 10 那根 int（帧 6 的 4 被盖掉），实得 %s" % str(账["修改次数"]))
	_判(bool(账["已解锁"]), "`已解锁` = (帧 8 的 int == 1)（实得 %s）" % str(账["已解锁"]))
	_判(假.发过.is_empty(), "解码这一路**一条上行都不发**（帧 8 也不发）")

	# 三条坏帧：整帧丢弃、不许发信号
	var 基 := 帧录.size()
	后.call("_handle_original_frame", PackedByteArray([0, 0, 0, 0, 221, 9]))	# 只 6 字节
	_喂裸(6, PackedByteArray([0, 0, 0, 1]))									# 形状要两根 int，只给一根
	_喂裸(255, PackedByteArray())											# 动作号不认识
	_判(帧录.size() == 基, "三条坏帧（太短 / int 少一根 / 动作号不认识）一条信号都不发，实发 %d 条" % (帧录.size() - 基))

	# 大小端两针（**这是本工程有意偏离 AS3 的地方，照 AS3 改成大端就连不上服务端**）
	基 = 帧录.size()
	var 大端 := PackedByteArray()
	大端.resize(4)
	大端[1] = 2													# `<H` 写成了 `>H`
	var 尾 := PackedByteArray()
	尾.resize(2 + 4 + 大端.size() + 4)
	for i in 2:
		尾[i] = 大端[i]
	尾[2] = 65
	尾[3] = 66
	尾[4] = 0
	尾[5] = 0
	尾[6] = 0
	尾[7] = 1
	_喂裸(5, 尾)
	_判(帧录.size() == 基,
			"utf 长度前缀写成**大端** ⇒ 读出 512、越界、整帧丢弃（服务端 `original_utf` 用的是 `<H`）")
	_喂裸(8, PackedByteArray([0, 0, 0, 1]))					# int 1 写成大端
	_判(帧录.size() == 基 + 1 and int((帧录[帧录.size() - 1] as Array)[1][0]) == 16777216,
			"int 写成大端 ⇒ 小端读出 16777216（**不是** 1），实得 %s" % str(帧录[帧录.size() - 1]))
	_判(not bool((后.get("authoritative_second_password") as Dictionary)["已解锁"]),
			"上一条 ⇒ `已解锁` 仍旧 false（大端读法在这条门上会**静默判错**，所以钉住）")
	_设账(0, 0, 0, false)


## ── ③ 上行线格式（真 `request_second_password` + 捕获式测试后端）────────────────
func _三_上行线格式() -> void:
	var 线 := 测试后端.new()
	线.request_second_password(3, ["问题一", "答案一", 7])
	_判(线.sent_requests.size() == 1 and int(线.sent_requests[0]["opcode"]) == 2309,
			"上行只走 opcode 2309（`SECOND_LEVEL_PASSWORD` 收发同号），实得 %s" % str(线.sent_requests))
	var 文 := String(线.sent_requests[0]["content"])
	_判(文 == '{"action":3,"values":["问题一","答案一","7"]}',
			"载荷 = 裸 JSON `{\"action\":N,\"values\":[…]}` 而且 **int 也按字符串送**"
			+ "（服务端 `values = [str(v) for v in raw_values]` + 长度校验读的是位数），实得「%s」" % 文)
	var 解: Dictionary = JSON.parse_string(文) as Dictionary
	_判(int(解["action"]) == 3 and (解["values"] as Array).size() == 3
			and String(解["values"][0]) == "问题一", "中文值原样 round-trip（实得 %s）" % str(解))
	线.sent_requests.clear()
	_判(not bool(线.request_second_password(11, ["x"])) and not bool(线.request_second_password(-1, []))
			and 线.sent_requests.is_empty(), "动作号越界（11 / -1）⇒ 返回 false 且一帧不发")
	线.sent_requests.clear()
	线.request_second_password(0, [])
	_判(线.sent_requests.size() == 1 and String(线.sent_requests[0]["content"]) == '{"action":0,"values":[]}',
			"上 0（`queryFirstTime:195-200`）无值 ⇒ `values` 是空表而不是省掉，实得 %s" % str(线.sent_requests))
	线.free()


## ── ④ 背包入口：只发一跳、一扇窗都不开 ─────────────────────────────────────────
func _四_背包入口() -> void:
	var 包: Node = 管.call("取或建窗口", "背包")
	包.set("_backend", 假)
	管.call("打开", "背包")
	await _等(5)
	var 页 := 包.find_child("原版背包内容", true, false) as Control
	var 钮 := 页.get_node_or_null("二级密码") as Button
	_判(钮 != null, "背包页里要有「二级密码」那颗（`ItemWindow2.as:722-729`）")
	if 钮 == null:
		return
	_擦()
	for 页名 in 六页:
		_判(not _建过(页名), "点之前「%s」还没建过" % 页名)
	钮.pressed.emit()
	await _等(2)
	_判(假.发过 == [[0, []]], "点它 = **只发上行 0、零值**（原版 `queryFirstTime` 全文一句），实发 %s" % str(假.发过))
	var 开着的 := []
	for 页名 in 六页:
		if _建过(页名) or _开着(管._窗口们.get(页名)):
			开着的.append(页名)
	_判(开着的.is_empty(), "而且**一扇都不开**（开窗的是回帧 2）⇒ 与 神秘商店/随身药店 同族、与 摊位列表 正相反；实得 %s" % str(开着的))
	_判(通告.is_empty(), "点成功不该弹任何字，实得 %s" % str(通告))

	# 「未连接」与「发送失败」两句：入口那颗自己判（`窗口._backend` 为 null 那一支）
	包.set("_backend", null)
	var 状: Label = 包.get("_status") as Label
	钮.pressed.emit()
	await _等(2)
	_判(状 != null and String(状.text).contains("未连接服务端"),
			"后端为 null ⇒ 给一句看得见的「未连接服务端」（点了没反应会被当成坏了），实得「%s」" % (状.text if 状 != null else "没标签"))
	包.set("_backend", 假)
	包.call("close")


## ── ⑤ 说明窗（`TwoPasswordSayWindow`）────────────────────────────────────────
func _五_说明窗() -> void:
	var 窗 := _备(页脚本.页说明)
	管.call("打开", 页脚本.页说明)
	await _等(5)
	var 页 := _页(窗)
	_判(页 != null and _近([页.size.x, 页.size.y], 页尺["二级密码说明"]),
			"说明页根 = 384×353（整框 382 − 标题 29），实得 %s" % str([页.size.x, 页.size.y]))
	for 名 in 期说明:
		var 件 := 页.get_node_or_null(名) as Control
		_判(_矩形对(件, 期说明[名]),
				"说明「%s」= (%s)，实得 (%s)" % [名, 期说明[名], _矩(件) if 件 != null else "没建"])
	_判(_文(窗, "正文").contains("物品交易") and _文(窗, "正文").contains("宠物进阶"),
			"正文那一段列了 1.物品交易 … 6.宠物进阶（`:3090` 逐条），实得「%s」" % _文(窗, "正文").substr(0, 40))
	_判(页.get_node_or_null("删除密码") == null, "首钮的节点名是「设置密码」，**文字**才会变成「删除密码」")
	_判(String(窗.get("_title").get("text")) == "二级密码说明", "标题取自尺寸表「二级密码说明」")

	# 三种服务端账 ⇒ 三颗钮各刷一次（`updateView:37-42` 三条全读服务端，客户端一个数都不猜）
	for 态 in [[0, false], [1, false], [1, true], [2, false]]:
		_设账(int(态[0]), 0, 0, bool(态[1]))
		窗.call("刷二级密码", -1)
		await _等(2)
		var 首 := 页.get_node_or_null("设置密码") as Button
		var 解 := 页.get_node_or_null("解除锁定") as Button
		var 改 := 页.get_node_or_null("修改密码") as Button
		var 期字 := "删除密码" if int(态[0]) == 1 else "设置密码"
		_判(首 != null and 首.text == 期字,
				"类型=%d ⇒ 首钮文字「%s」（原版同一颗钮换字不换节点），实得「%s」" % [int(态[0]), 期字, 首.text if 首 != null else "没"])
		_判(解 != null and bool(解.disabled) != (int(态[0]) == 1 and not bool(态[1])),
				"类型=%d 已解锁=%s ⇒ 「解除锁定」disabled 应 = %s，实得 %s" % [
					int(态[0]), str(态[1]), not (int(态[0]) == 1 and not bool(态[1])), str(解.disabled) if 解 != null else "没"])
		_判(改 != null and bool(改.disabled) == (int(态[0]) != 1),
				"类型=%d ⇒ 「修改密码」disabled 应 = %s，实得 %s" % [int(态[0]), str(int(态[0]) != 1), str(改.disabled) if 改 != null else "没"])
	_设账(0, 0, 0, false)
	窗.call("刷二级密码", -1)
	await _等(2)

	# 首钮三条腿（`onClickSetPassword:50-61`）：类型 1 ⇒ 发 5；否则**零发**只把一格开出来。两条都关说明窗。
	_擦()
	_按(窗, "设置密码")
	await _等(3)
	_判(假.发过.is_empty(), "类型=0 点首钮**一帧不发**（原版走 `reverseDisplay(PANE1)`），实发 %s" % str(假.发过))
	_判(not _开着(窗) and _开着(管._窗口们.get(页脚本.页一格)),
			"类型=0 ⇒ 关说明 + 开一格（实得 说明=%s 一格=%s）" % [str(_开着(窗)), str(_开着(管._窗口们.get(页脚本.页一格)))])
	管.call("打开", 页脚本.页说明)
	await _等(3)
	_设账(1, 0, 0, false)
	窗.call("刷二级密码", -1)
	await _等(2)
	_擦()
	_按(窗, "设置密码")
	await _等(3)
	_判(假.发过 == [[5, []]], "类型=1 ⇒ 那颗写的是「删除密码」⇒ 发上 5（`requestDeletePassword:280-285`），实发 %s" % str(假.发过))
	_判(not _开着(窗), "发完关自己（`:57` `reverseDisplay(THIS)`），实得 %s" % str(_开着(窗)))

	# 「解除锁定」：**不发帧**，走 `showUnchainLookWindow`（重建 + 居中）再关说明
	管.call("打开", 页脚本.页说明)
	await _等(3)
	_擦()
	_按(窗, "解除锁定")
	await _等(3)
	_判(假.发过.is_empty(), "「解除锁定」一帧不发（`:122-126` 只有 `showUnchainLookWindow()` + 关自己）")
	_判(_开着(管._窗口们.get(页脚本.页解锁)) and not _开着(窗),
			"⇒ 解锁窗开、说明窗关（实得 解锁=%s 说明=%s）" % [
				str(_开着(管._窗口们.get(页脚本.页解锁))), str(_开着(窗))])

	# 「修改密码」：发 9 + 关自己（开窗的是回帧 10）
	管.call("打开", 页脚本.页说明)
	await _等(3)
	_擦()
	_按(窗, "修改密码")
	await _等(3)
	_判(假.发过 == [[9, []]], "「修改密码」发上 9（`requestModifyPassword:38-43`）实发 %s" % str(假.发过))
	_判(not _开着(窗), "发完关自己")
	管.call("打开", 页脚本.页说明)
	await _等(2)
	_设账(0, 0, 0, false)
	窗.call("刷二级密码", -1)
	# 回帧 2 是**开关**（`reverseDisplay`）：同帧连喂两次 ⇒ 第二次收起。
	# 所以先把它关干净 —— 不关的话第一记喂下去是「收起」，两条判据会一起倒过来。
	窗.call("close")
	await _等(2)
	_擦()
	_喂帧(2, [], [0])
	await _等(3)
	_判(_开着(窗) and 通告.is_empty(), "帧 2 ⇒ 开说明、不弹字（`isFirstTimeResult:1569-1577`）实得 开=%s 告=%s" % [str(_开着(窗)), str(通告)])
	_喂帧(2, [], [0])
	await _等(3)
	_判(not _开着(窗), "帧 2 再喂一次 ⇒ **收起**（`reverseDisplay` 是开关，不是每次居中重建）")
	_判(_建过(页脚本.页说明), "但实例留在窗表里 ⇒ 「建过」仍旧为真（`removeWindow:5294-5308` 从不清 `_windowMap`）")


## ── ⑥ 一格（`SetPasswordPane1`）───────────────────────────────────────────────
func _六_一格() -> void:
	var 窗 := _备(页脚本.页一格)
	管.call("打开", 页脚本.页一格)
	await _等(5)
	var 页 := _页(窗)
	_判(页 != null and _近([页.size.x, 页.size.y], 页尺["二级密码设置"]),
			"一格页根 = 270×311，实得 %s" % str([页.size.x, 页.size.y]))
	for 名 in 期一格:
		var 件 := 页.get_node_or_null(名) as Control
		_判(_矩形对(件, 期一格[名]),
				"一格「%s」= (%s)，实得 (%s)" % [名, 期一格[名], _矩(件) if 件 != null else "没建"])
	_判(页.get_node_or_null("底4") == null, "一格只有两张底（修改窗才是三张）")
	var 一 := 页.get_node_or_null("密码输入") as LineEdit
	var 二 := 页.get_node_or_null("确认输入") as LineEdit
	_判(一 != null and 一.secret and 二 != null and 二.secret, "两枚都是打点的（`displayAsPassword`）")
	_判(一.max_length == 14 and 二.max_length == 14, "`maxChars` = 14（`TwoPasswordManager.maxChars:14`），实得 %d/%d" % [一.max_length, 二.max_length])
	_判(String(窗.get("_title").get("text")) == "二级密码设置嚮导",
			"一格标题 = 「二级密码设置嚮导」（`:333` 建窗那句用的是 **Pane3** 那条文案 —— 原版串门，照抄）")

	# 闸：两枚**都**要 ≥6 位（`onInputpas:62-72` 是 `<6 || <6` 的或条件）
	var 钮 := 页.get_node_or_null("下一步") as Button
	for 试 in [["12345", "123456"], ["123456", "12345"], ["12345", "12345"], ["123456", "123456"]]:
		_输(窗, "密码输入", 试[0])
		_输(窗, "确认输入", 试[1])
		await _等(2)
		var 期灰: bool = (试[0].length() < 6 or 试[1].length() < 6)
		_判(钮.disabled == 期灰, "一格「下一步」灰 = %s（%s/%s；写成 `&&` 这一条立刻红）实得 %s" % [
			str(期灰), 试[0], 试[1], str(钮.disabled)])
	_输(窗, "密码输入", "abc")
	_输(窗, "确认输入", "abcdef")
	_擦()
	_按(窗, "下一步")
	await _等(2)
	_判(通告 == ["密码与确认密码不一致"] and 假.发过.is_empty(),
			"不等 ⇒ 只弹「密码与确认密码不一致」一句、一帧不发，实得 告=%s 发=%s" % [str(通告), str(假.发过)])
	_判(_开着(窗), "判式没过 ⇒ **不关窗**")
	_输(窗, "密码输入", "abcdef")
	_擦()
	_按(窗, "下一步")
	await _等(2)
	_判(假.发过 == [[1, ["abcdef", "abcdef"]]], "两枚都够且相等 ⇒ 发上 1（原样两枚，不做规整），实发 %s" % str(假.发过))
	_判(not _开着(窗) and 通告.is_empty(), "发完关自己、不弹字（`:52-58`），实得 开=%s 告=%s" % [str(_开着(窗)), str(通告)])

	# `updateView:74-96`：**先清空两枚再重算闸**，然后两支 `if` **没有 else**
	_输(窗, "密码输入", "zz")
	_设账(1, 0, 0, false)
	管.call("打开", 页脚本.页一格)
	await _等(3)
	页 = _页(窗)
	一 = 页.get_node_or_null("密码输入") as LineEdit
	钮 = 页.get_node_or_null("下一步") as Button
	_判(一.text == "" and 钮.disabled, "开窗（= 原版 `initWindow`）就清空两枚并把那颗钮灰回去，实得「%s」灰=%s" % [一.text, str(钮.disabled)])
	_判(_文(窗, "步骤").contains("1/3二级密码设置") and (页.get_node("下一步") as Button).text == "下一步",
			"类型=1 两支 if 都不进 ⇒ 留着建窗时的「1/3二级密码设置 / 下一步」（不是漏写 else，照抄）实得「%s」" % _文(窗, "步骤"))
	_设账(0, 0, 0, false)
	窗.call("刷二级密码", -1)
	await _等(2)
	_判(_文(窗, "步骤").contains("1/3二级密码设置"), "类型=0 ⇒ 步骤「1/3二级密码设置」（`:76-84`）")
	_设账(2, 0, 0, false)
	窗.call("刷二级密码", -1)
	await _等(2)
	_判(_文(窗, "步骤").contains("你已经设置了密码保护问题")
			and (页.get_node("下一步") as Button).text == "完成",
			"类型=2 ⇒ 换「你已经设置了密码保护问题」+ 钮「完成」（TEXT_5 :917 / WANCHENG :2142）实得「%s」「%s」" % [
				_文(窗, "步骤"), (页.get_node("下一步") as Button).text])
	_设账(0, 0, 0, false)
	窗.call("刷二级密码", -1)
	窗.call("close")


## ── ⑦ 二格（`SetPasswordPane2`）───────────────────────────────────────────────
func _七_二格() -> void:
	var 窗 := _备(页脚本.页二格)
	管.call("打开", 页脚本.页二格)
	await _等(5)
	var 页 := _页(窗)
	_判(_近([页.size.x, 页.size.y], 页尺["二级密码资料"]), "二格页根 = 270×311，实得 %s" % str([页.size.x, 页.size.y]))
	for 名 in 期二格:
		var 件 := 页.get_node_or_null(名) as Control
		_判(_矩形对(件, 期二格[名]),
				"二格「%s」= (%s)，实得 (%s)" % [名, 期二格[名], _矩(件) if 件 != null else "没建"])
	var 提示 := 页.get_node_or_null("提示") as RichTextLabel
	_判(提示 != null and absf(提示.size.y - 81.0) < 0.51,
			"提示高 = `textHeight + 6` = **5** 行 × 15 + 6 = 81（`:104-105` 只钉 x/y/宽）——"
			+ "TEXT_7 尾巴上那枚 `密码<br/>` 在 Flash 里也占一行行盒，四段文字 = 五行高。实得 %s" % (
			提示.size.y if 提示 != null else "没建"))
	var 邮 := 页.get_node_or_null("邮箱输入") as LineEdit
	_判(邮.max_length == 0 and not 邮.secret,
			"三枚输入在 AS3 里**根本没设 maxChars**（`createTextField(宽,20)` 不带那一句）⇒ 这里 0 = 不限")

	# 只判邮箱那一条；正则**从串首**试（AS3 `RegExp.match`），尾随杂字两边都放行
	# ⚠ 式子两头都没锚（`mailRegExp:18` 里没有 `^`/`$`），AS3 用的又是 `test` ⇒ **全串找**：
	# 前头带杂字、尾巴带杂字都放行，只有整串凑不出式子才拦。
	_擦()
	for 试 in ["", "abc", "a@b", "没有@的点"]:
		邮.text = 试
		_按(窗, "下一步")
		await _等(2)
		_判(通告 == ["您输入的邮箱不正确"] and 假.发过.is_empty(),
				"邮箱「%s」整串凑不出式子 ⇒ 只弹「您输入的邮箱不正确」、一帧不发，实得 告=%s 发=%s" % [
					试, str(通告), str(假.发过)])
		_擦()
	for 试 in ["流尘 a@b.co", "a@b.c.o", "n1.x+y@sub-domain.example"]:
		管.call("打开", 页脚本.页二格)
		await _等(3)
		(_页(窗).get_node("邮箱输入") as LineEdit).text = 试
		_擦()
		_按(窗, "下一步")
		await _等(2)
		_判(通告.is_empty() and 假.发过 == [[2, [试, "", ""]]],
				"邮箱「%s」放行（`test` 不锚串首）⇒ 只发上 2、不弹，实得 告=%s 发=%s" % [
					试, str(通告), str(假.发过)])
	_判(String(页脚本.草稿["邮箱"]) == "n1.x+y@sub-domain.example",
			"过了才把草稿写下来 ⇒ 草稿.邮箱 = 「%s」（失败那四回一条都不该写）" % str(页脚本.草稿["邮箱"]))
	_判(假.发过.back()[1][1] == "" and 假.发过.back()[1][2] == "",
			"手机/QQ **空着也照发**（`:181-195` 只判 mail 那一条），实发 %s" % str(假.发过.back()))
	_判(not _开着(窗), "发完关自己")

	# 手机/QQ 的 `restrict = "0123456789"`
	管.call("打开", 页脚本.页二格)
	await _等(4)
	页 = _页(窗)
	_输(窗, "手机输入", "a1b2-c3d")
	await _等(2)
	_判((页.get_node("手机输入") as LineEdit).text == "123",
			"手机那枚剔非数字（`:138` restrict）实得「%s」" % (页.get_node("手机输入") as LineEdit).text)
	_输(窗, "QQ输入", "Q9-0")
	await _等(2)
	_判((页.get_node("QQ输入") as LineEdit).text == "90", "QQ 同一条（`:140`）实得「%s」" % (页.get_node("QQ输入") as LineEdit).text)
	# 三枚回填 = `initWindow:163-168`：**过闸那一刻**才写进草稿，之后关窗不丢、跨窗共享
	_输(窗, "邮箱输入", "x@y.zz")
	_擦()
	_按(窗, "下一步")
	await _等(2)
	_判(假.发过 == [[2, ["x@y.zz", "123", "90"]]],
			"三枚**原样**发出（手机/QQ 那两枚已被 restrict 剔成数字）实发 %s" % str(假.发过))
	_判(String(页脚本.草稿["手机"]) == "123" and String(页脚本.草稿["QQ"]) == "90",
			"草稿记的是**剔过之后**的那两份，实得 %s/%s" % [str(页脚本.草稿["手机"]), str(页脚本.草稿["QQ"])])
	窗.call("close")
	await _等(2)
	管.call("打开", 页脚本.页二格)
	await _等(4)
	页 = _页(窗)
	_判((页.get_node("邮箱输入") as LineEdit).text == "x@y.zz"
			and (页.get_node("手机输入") as LineEdit).text == "123"
			and (页.get_node("QQ输入") as LineEdit).text == "90",
			"再开窗 ⇒ 三枚从草稿回填（`initWindow:165-167`）实得 %s/%s/%s" % [
				(页.get_node("邮箱输入") as LineEdit).text, (页.get_node("手机输入") as LineEdit).text,
				(页.get_node("QQ输入") as LineEdit).text])
	_判(String(窗.get("_title").get("text")) == "二级密码说明",
			"二格标题也是「二级密码说明」（`:1864` 建窗用的 `TWOPASSWORD_SAY_WINDOW_TITLE` —— 原版串门）")
	窗.call("close")


## ── ⑧ 三格（`SetPasswordPane3`，三档共用一扇）──────────────────────────────────
func _八_三格() -> void:
	## ② 那轮的帧 5 已经把这只实例推进过 Type3 ⇒ `三格删过` 脏了、标题也停在「二级密码删除」。
	## 本节验的是「建窗时标题取 SEPPASSWORDPANE_3_TITLE」，先把这枚 static 擦干净
	## （`渲染三格` 每一轮都按 `三格标题()` 重钉标题，所以擦了就回得来）。
	页脚本.三格删过 = false
	var 窗 := _备(页脚本.页三格)
	管.call("打开", 页脚本.页三格)
	await _等(5)
	var 页 := _页(窗)
	_判(_近([页.size.x, 页.size.y], 页尺["二级密码问题"]), "三格页根 = 315×311，实得 %s" % str([页.size.x, 页.size.y]))
	for 名 in 期三格:
		var 件 := 页.get_node_or_null(名) as Control
		_判(_矩形对(件, 期三格[名]),
				"三格「%s」= (%s)，实得 (%s)" % [名, 期三格[名], _矩(件) if 件 != null else "没建"])
	_判((页.get_node("下拉1") as TextureButton).visible and not (页.get_node("自订1") as LineEdit).visible,
			"Type1：下拉亮、那枚 190 宽自由输入**藏着但 editable**（`:126` 只关 visible、`:127` 关的是 mouseEnabled）")
	_判(absf((页.get_node("提示") as RichTextLabel).size.y - 66.0) < 0.51,
			"Type1 提示高 = **4** 行 × 15 + 6 = 66（`:254-255`；TEXT_13 也是尾巴多一枚 `<br/>`），实得 %s" % str((页.get_node("提示") as RichTextLabel).size.y))
	_判((页.get_node("答案输入1") as LineEdit).max_length == 40
			and (页.get_node("自订1") as LineEdit).max_length == 40,
			"四枚都是 `maxChar_result` = 40（`:16`）")
	_判(String(窗.get("_title").get("text")) == "二级密码设置嚮导",
			"标题「二级密码设置嚮导」（`:333` 建窗那一句），实得「%s」" % String(窗.get("_title").get("text")))

	# 下拉：七项、提层、选别项收起、选「自订」清两格
	_按(窗, "下拉1")
	await _等(3)
	var 盘 := _找下拉(窗)
	_判(盘 != null, "点下拉 ⇒ 遮罩上长出一张菜单")
	if 盘 != null:
		_判(盘.get_child_count() == 7, "菜单七项（`_dataProvider:24`），实得 %d" % 盘.get_child_count())
		var 齐 := true
		for i in 7:
			if String((盘.get_child(i) as Button).text) != 期问题项[i]:
				齐 = false
		_判(齐, "七项逐条对上（顺序：占位…自订），实得 %s" % str(项表(盘)))
		_判(int(盘.get("z_index")) == 50, "菜单**提层** z=50（不提时点第三项打在页上、静默没反应）")
		_判((盘.get_child(1) as Button).size.x > 200.0, "项宽 = 下拉宽 − 6 = 204")
		(盘.get_child(2) as Button).pressed.emit()		# 「你的生日是？」
		await _等(3)
	var 字1 := 页.get_node("下拉1/文字") as Label
	var 框1 := 页.get_node("自订1") as LineEdit
	_判(框1.text == "你的生日是？" and 字1.text == "你的生日是？" and not 框1.visible,
			"选别项 ⇒ 收起那枚输入、把该项写进**两处**（判式与上行读的都是 `inputProblem.text`），实得「%s」「%s」亮=%s" % [
				框1.text, 字1.text, str(框1.visible)])
	_判(_找下拉(窗) == null, "选完 ⇒ 菜单收掉（`MComboBox.close()`）")
	_按(窗, "下拉2")
	await _等(3)
	var 盘2 := _找下拉(窗)
	if 盘2 != null:
		(盘2.get_child(6) as Button).pressed.emit()		# 「自订」
		await _等(3)
	var 框2 := 页.get_node("自订2") as LineEdit
	_判(框2.visible and 框2.text == "" and (页.get_node("下拉2/文字") as Label).text == "",
			"选「自订」⇒ 亮出自由输入、把下拉显示与输入**都清空**、焦点给它（`:177-209`）")

	# Type1 五句判式**按序**，而且草稿写在判式**之前**
	_输(窗, "答案输入1", "甲答案")
	_输(窗, "答案输入2", "乙答案")
	(页.get_node("自订1") as LineEdit).text = "同一个问题"
	(页.get_node("自订2") as LineEdit).text = "同一个问题"
	_擦()
	_按(窗, "下一步")
	await _等(2)
	_判(通告 == ["两次密码保护问题不能重复"] and 假.发过.is_empty(),
			"两问相同 ⇒ 第一句就拦（`:78-82` 排在四条非空**前面**），实得 告=%s" % str(通告))
	_判(String(页脚本.草稿["问题1"]) == "同一个问题" and String(页脚本.草稿["答案1"]) == "甲答案",
			"⚠ 四格在判式**之前**就写进草稿（`:71-74`）⇒ 被拦那一回草稿**照样留**")
	(页.get_node("自订1") as LineEdit).text = ""
	(页.get_node("自订2") as LineEdit).text = ""
	_擦()
	_按(窗, "下一步")
	await _等(2)
	_判(通告 == ["两次密码保护问题不能重复"],
			"两枚都空 ⇒ 弹的仍是「不能重复」那一句（两个空串相等，`:78` 先撞上）实得 %s" % str(通告))
	(页.get_node("自订1") as LineEdit).text = "问题一"
	_擦()
	_按(窗, "下一步")
	await _等(2)
	_判(通告 == ["请选择问题2"], "问题2 空 ⇒ 第二句（`:89-98`），实得 %s" % str(通告))
	(页.get_node("自订2") as LineEdit).text = "问题二"
	_输(窗, "答案输入1", "")
	_擦()
	_按(窗, "下一步")
	await _等(2)
	_判(通告 == ["请输入答案1"], "答案1 空 ⇒ 第三句，实得 %s" % str(通告))
	_输(窗, "答案输入1", "甲答案")
	_输(窗, "答案输入2", "")
	_擦()
	_按(窗, "下一步")
	await _等(2)
	_判(通告 == ["请输入答案2"], "答案2 空 ⇒ 第四句，实得 %s" % str(通告))
	_输(窗, "答案输入2", "乙答案")
	_擦()
	_按(窗, "下一步")
	await _等(2)
	_判(假.发过 == [[3, ["问题一", "甲答案", "问题二", "乙答案"]]],
			"四条都过 ⇒ 发上 3 = `sendQuestionsAndAnswers(问1,答1,问2,答2)`（**成对交错**，不是四问四答），实发 %s" % str(假.发过))
	_判(_开着(窗) and 通告.is_empty(), "发完**不关窗**：关窗的是回帧 4 那条成功腿（`Client.as:6451`）")

	# Type1 的「上一步」= 二格开关 + 关自己
	var 二窗: Node = 管._窗口们.get(页脚本.页二格)
	if 二窗 != null and _开着(二窗):
		二窗.call("close")
	await _等(2)
	_擦()
	_按(窗, "上一步")
	await _等(3)
	_判(假.发过.is_empty() and _开着(二窗) and not _开着(窗),
			"Type1「上一步」⇒ 二格被叫出来（`reverseDisplay`）+ 关自己，一帧不发；实得 发=%s 二格=%s 三格=%s" % [
				str(假.发过), str(_开着(二窗)), str(_开着(窗))])

	# 回帧 1 ⇒ 确认档（**原地换显示，不开也不关**）
	_擦()
	管.call("打开", 页脚本.页三格)
	await _等(4)
	_喂帧(1, [], [1])
	await _等(3)
	页 = _页(窗)
	_判(not (页.get_node("下拉1") as TextureButton).visible and (页.get_node("自订1") as LineEdit).visible
			and not (页.get_node("自订1") as LineEdit).editable,
			"确认档：收起下拉、亮出那枚输入且**只读**（`:146` 关的是 mouseEnabled+selectable）")
	_判((页.get_node("自订1") as LineEdit).text == "问题一" and (页.get_node("自订2") as LineEdit).text == "问题二",
			"两枚问题显示回草稿（`:148-149`）实得 %s/%s" % [
				(页.get_node("自订1") as LineEdit).text, (页.get_node("自订2") as LineEdit).text])
	_判((页.get_node("答案输入1") as LineEdit).text == "" and (页.get_node("答案输入1") as LineEdit).editable,
			"两枚答案清零但**始终可编辑**（Type2/3 只 `API.resetFocus`，四枚里被关过的只有 `inputProblem`）")
	_判(_文(窗, "步骤").contains("3/3：密码保护资讯设置") and (页.get_node("下一步") as Button).text == "完成",
			"步骤换 3/3、钮换「完成」（TEXT_14 :859 / WANCHENG :2142）实得「%s」「%s」" % [
				_文(窗, "步骤"), (页.get_node("下一步") as Button).text])
	_判(_文(窗, "答案1").contains("答案1: ") and not _文(窗, "答案1").contains("40位"),
			"两枚答案的标签去掉红字注（TEXT_16 :856）实得「%s」" % _文(窗, "答案1"))
	_判(absf((页.get_node("提示") as RichTextLabel).size.y - 36.0) < 0.51
			and _文(窗, "提示").contains("以上是您刚刚设置的密保资讯"),
			"提示换 2 行那句 ⇒ 高 = 2×15+6 = **36**（TEXT_15 :857），实得 %s「%s」" % [
				str((页.get_node("提示") as RichTextLabel).size.y), _文(窗, "提示")])
	# Type2 的两枚问题输入是**只读**的 ⇒ 只能程序改（真人改不了，这里只为把答案读进来）
	_输(窗, "答案输入1", "错的")
	_输(窗, "答案输入2", "乙答案")
	_擦()
	_按(窗, "下一步")
	await _等(2)
	_判(通告 == ["密码保护答案不一致"] and 假.发过.is_empty(),
			"确认档跟**本地草稿**比（`:107-112` 不发帧也不问服务端），实得 告=%s" % str(通告))
	_输(窗, "答案输入1", "甲答案")
	_擦()
	_按(窗, "下一步")
	await _等(2)
	_判(假.发过 == [[4, ["问题一", "甲答案", "问题二", "乙答案"]]],
			"对上 ⇒ 发上 4 = `sendConformQA(inputProblem1, inputResult1, …)`，实发 %s" % str(假.发过))
	_擦()
	_按(窗, "上一步")
	await _等(3)
	_判(假.发过.is_empty(), "确认档「上一步」**一帧不发**（`:354-357` 只 `updateView(Type1)`）")
	页 = _页(窗)
	_判((页.get_node("答案输入1") as LineEdit).text == "甲答案" and (页.get_node("下拉1") as TextureButton).visible,
			"⇒ 画面切回 Type1、答案从草稿**补回来**（草稿没丢）实得「%s」" % (页.get_node("答案输入1") as LineEdit).text)

	# 回帧 4：非 0 ⇒ 关 + 成功；0 ⇒ 刷确认档 + 失败
	_擦()
	_喂帧(4, [], [1])
	await _等(3)
	_判(通告 == ["二级密码设置成功"] and not _开着(窗),
			"帧 4 = 1 ⇒ 关窗 + 弹「二级密码设置成功」（`else` 是「非 0」不是「==1」）实得 告=%s 开=%s" % [str(通告), str(_开着(窗))])
	_擦()
	_喂帧(4, [], [2])
	await _等(3)
	_判(通告 == ["二级密码设置成功"], "帧 4 = 2（不是 0 也不是 1）⇒ 走的是同一条成功腿（`else` 那一支）")
	管.call("打开", 页脚本.页三格)
	await _等(3)
	_擦()
	_喂帧(4, [], [0])
	await _等(3)
	页 = _页(窗)
	_判(通告 == ["设置二级密码失败"] and _开着(窗) and _文(窗, "步骤").contains("3/3"),
			"帧 4 = 0 ⇒ **不关**、原地刷成确认档 + 弹「设置二级密码失败」实得 告=%s 开=%s" % [str(通告), str(_开着(窗))])

	# 回帧 5 ⇒ 删除档（先摆到「关着」再喂，才验得出这一下是**开**）
	_擦()
	窗.call("close")
	await _等(2)
	_设账(1, 0, 7, false)
	_喂帧(5, ["问题甲", "问题乙"], [3])
	await _等(4)
	_判(_开着(窗), "帧 5 ⇒ 把三格开出来（`Questions:1961-1971`）")
	页 = _页(窗)
	_判((页.get_node("自订1") as LineEdit).text == "问题甲" and (页.get_node("自订2") as LineEdit).text == "问题乙",
			"两枚问题显示**回帧 5 塞进草稿的那两条**（不是玩家自己填的那对）实得 %s/%s" % [
				(页.get_node("自订1") as LineEdit).text, (页.get_node("自订2") as LineEdit).text])
	_判(String(页脚本.草稿["问题1"]) == "问题甲" and int((后.get("authoritative_second_password") as Dictionary)["删除次数"]) == 3,
			"帧 5 的两根串进草稿、第三根 int 进 `删除次数`（**客户端不猜**）")
	_判(_文(窗, "步骤") == "", "删除档把步骤清空（`:166` 那句 `processLabel.text` 被赋成空串）实得「%s」" % _文(窗, "步骤"))
	_判((页.get_node("上一步") as Button).text == "删除" and (页.get_node("下一步") as Button).text == "取消",
			"两颗钮换字：「删除」/「取消」（FRIEND_DEL :1665 / COMMON_CANCEL :1906）实得「%s」「%s」" % [
				(页.get_node("上一步") as Button).text, (页.get_node("下一步") as Button).text])
	_判(_文(窗, "提示").contains("今天你还可以进行3次操作")
			and absf((页.get_node("提示") as RichTextLabel).size.y - 21.0) < 0.51
			and absf((页.get_node("提示") as Control).position.y - 222.0) < 0.51,
			"提示 = 居中那句「今天你还可以进行%%d次操作」（**数字读服务端的删除次数**）⇒ 1 行 21 高、y 从 212 变 **222**（`:172`）实得「%s」%s" % [
				_文(窗, "提示"), str([(页.get_node("提示") as Control).size.y, (页.get_node("提示") as Control).position.y])])
	_判(String(窗.get("_title").get("text")) == "二级密码删除", "标题被 Type3 改成「二级密码删除」（`:333` 只有这一档改标题）")

	_擦()
	_按(窗, "上一步")
	await _等(2)
	_判(通告 == ["请输入答案"] and 假.发过.is_empty(),
			"删除档「删除」：两枚答案**任一**为空就拦（`:358-366`），实得 告=%s" % str(通告))
	_输(窗, "答案输入1", "答一")
	_擦()
	_按(窗, "上一步")
	await _等(2)
	_判(通告 == ["请输入答案"], "只填一枚仍拦（第二条答案还是空）")
	_输(窗, "答案输入2", "答二")
	_擦()
	_按(窗, "上一步")
	await _等(2)
	_判(假.发过 == [[6, ["问题甲", "答一", "问题乙", "答二"]]], "齐了 ⇒ 发上 6，实发 %s" % str(假.发过))
	_判(_开着(窗), "发完**不关**：关不关由回帧 9 判")
	_擦()
	_按(窗, "下一步")
	await _等(2)
	_判(假.发过.is_empty() and 通告.is_empty() and not _开着(窗),
			"删除档那颗「取消」= **只关窗**（`:114-117` 直接 `onCloseBtnClick`），一帧不发")

	# 回帧 9：=1 ⇒ 关 + 成功；否则原地刷 + 那句带次数的失败
	_擦()
	_喂帧(9, [], [1, 0])
	await _等(3)
	_判(通告 == ["删除密码成功"] and not _开着(窗), "帧 9 = 1 ⇒ 关 + 「删除密码成功」（NOTICE_7 :2171）实得 告=%s" % str(通告))
	管.call("打开", 页脚本.页三格)
	await _等(3)
	_擦()
	_喂帧(9, [], [0, 2])
	await _等(3)
	_判(通告 == ["删除密码失败，今天还可以删除2次"] and _开着(窗),
			"帧 9 = 0 ⇒ 留在删除档刷那句、数字用**帧里那根** `值[1]`（不是账里的旧值）实得 告=%s 开=%s" % [str(通告), str(_开着(窗))])
	_判(int((后.get("authoritative_second_password") as Dictionary)["删除次数"]) == 2,
			"同一帧把 `删除次数` 也推进成 2（`:6204`）")
	窗.call("close")
	await _等(2)
	# 帧 3 **不读结果号**：服务端说「资料没存上」也照样往下开三格
	_擦()
	_喂帧(3, [], [0])
	await _等(4)
	_判(_开着(窗) and 通告.is_empty(),
			"帧 3 = 0 ⇒ **照样开三格、一句不弹**（`contactResult:2456-2459` 结果号读都不读 —— 原版呆账）")
	_判((_页(窗).get_node("下拉1") as TextureButton).visible,
			"而且原版这一支没有 `updateView` ⇒ 开出来的是 `initWindow` 那一版（Type1、下拉亮着）")


func 项表(盘: Control) -> Array:
	var 出: Array = []
	for 子 in 盘.get_children():
		出.append(String((子 as Button).text))
	return 出


func _找下拉(窗: Node) -> Control:
	var 台 := 窗.get("_overlay") as Control
	if 台 == null:
		return null
	for 子 in 台.get_children():
		if String(子.name) == "二级密码下拉" and not 子.is_queued_for_deletion():
			return 子 as Control
	return null


## ── ⑨ 修改窗（`UpdatePasswordWindow`）─────────────────────────────────────────
func _九_修改窗() -> void:
	var 窗 := _备(页脚本.页修改)
	# 回帧 10 ⇒ 开合 + 刷那句（`requestModifyPasswordResult:5623-5631`）
	_擦()
	_设账(1, 3, 0, false)
	_喂帧(10, [], [3])
	await _等(5)
	_判(_开着(窗), "帧 10 ⇒ 开修改窗")
	var 页 := _页(窗)
	_判(_近([页.size.x, 页.size.y], 页尺["二级密码修改"]), "修改页根 = 315×315（344−29），实得 %s" % str([页.size.x, 页.size.y]))
	for 名 in 期修改:
		var 件 := 页.get_node_or_null(名) as Control
		_判(_矩形对(件, 期修改[名]),
				"修改「%s」= (%s)，实得 (%s)" % [名, 期修改[名], _矩(件) if 件 != null else "没建"])
	_判(页.get_node_or_null("底4") != null, "修改窗是六扇里唯一画**三张底**的（`:69-71`）")
	_判(_文(窗, "次数").contains("您今天还可以进行3次操作"),
			"那句的数字是**服务端的**：帧 10 那根 int 进 `修改次数` ⇒ 页面读到 3。"
			+ "（AS3 建窗那一句先按 `replaceString(TEXT_1, 5)` 填**字面 5**，同一帧 `updateView` 就盖掉了 ⇒ 观测不到，别当 bug）实得「%s」" % _文(窗, "次数"))
	_判(_文(窗, "次数").contains("3次") and not _文(窗, "次数").contains("%1"),
			"占位符 `%%1` 不许留在页上（实得「%s」）" % _文(窗, "次数"))

	# 「修改」钮建出来就是 disabled，判的是**两枚新密码**、旧密码不算
	var 钮 := 页.get_node_or_null("修改") as Button
	_输(窗, "旧输入", "旧旧旧旧旧旧")
	_判(钮.disabled, "只填旧密码 ⇒ 那颗钮仍旧灰着（`:210-232` 两腿读的都是 newPas/newPasKo）")
	_输(窗, "新输入", "12345")
	_输(窗, "再次输入", "123456")
	_判(钮.disabled, "新密码只有 5 位 ⇒ 灰（任一短就灰）")
	_输(窗, "新输入", "123456")
	_判(not 钮.disabled, "两枚都 6 位 ⇒ 亮")

	_输(窗, "旧输入", "")
	_输(窗, "新输入", "abcdef")
	_输(窗, "再次输入", "abcdef")
	_擦()
	_按(窗, "修改")
	await _等(2)
	_判(通告 == ["请输入旧密码"] and 假.发过.is_empty(), "①旧空 ⇒ 只弹一句不发（NOTICE_1 :2739）实得 %s" % str(通告))
	_输(窗, "旧输入", "旧密码")
	_输(窗, "新输入", "")
	_擦()
	_按(窗, "修改")
	await _等(2)
	_判(通告 == ["请输入新密码"], "②新空 ⇒ NOTICE_2 :2738，实得 %s" % str(通告))
	_输(窗, "新输入", "abcdef")
	_输(窗, "再次输入", "")
	_擦()
	_按(窗, "修改")
	await _等(2)
	_判(通告 == ["请输入确认新密码"], "③确认空 ⇒ NOTICE_3 :2737，实得 %s" % str(通告))
	_输(窗, "再次输入", "abcXXX")
	_擦()
	_按(窗, "修改")
	await _等(2)
	_判(通告 == ["密码与确认密码不一致"], "④两枚不等 ⇒ 与一格同一句文案（TEXT_6 :916），实得 %s" % str(通告))
	_输(窗, "再次输入", "abcdef")
	_擦()
	_按(窗, "修改")
	await _等(2)
	_判(假.发过 == [[7, ["旧密码", "abcdef", "abcdef"]]], "⇒ 发上 7（`modifyPassword:126-134` 三枚原样），实发 %s" % str(假.发过))
	_判(_开着(窗) and 通告.is_empty(), "发完**不关窗**（`:191` 后面没有 `onCloseBtnClick`）⇒ 关不关由回帧 6 判")

	# 回帧 6：两支**都不弹字**
	_擦()
	_喂帧(6, [], [0, 1])
	await _等(3)
	_判(通告.is_empty() and _开着(窗) and _文(窗, "次数").contains("您今天还可以进行1次操作"),
			"帧 6 = 0 ⇒ 不关、只把那句刷成新数、**一句字都不弹**（TWOPASSWORD_NOTICE_3/4 全库无人引用）实得 告=%s「%s」" % [
				str(通告), _文(窗, "次数")])
	_擦()
	_喂帧(6, [], [1, 0])
	await _等(3)
	_判(通告.is_empty() and not _开着(窗), "帧 6 = 1 ⇒ 关窗、同样**不弹字**，实得 告=%s 开=%s" % [str(通告), str(_开着(窗))])

	# 「取消」= 只关窗、一帧不发（`onClickCancelBtn:99-101`）
	管.call("打开", 页脚本.页修改)
	await _等(3)
	_擦()
	_按(窗, "取消")
	await _等(2)
	_判(假.发过.is_empty() and 通告.is_empty() and not _开着(窗), "「取消」只关窗")
	# 帧 10 也是开关
	_喂帧(10, [], [3])
	await _等(3)
	_判(_开着(窗), "帧 10 再喂 ⇒ 又开（`reverseDisplay`）")
	_喂帧(10, [], [3])
	await _等(3)
	_判(not _开着(窗), "同帧第二次 ⇒ 收起")


## ── ⑩ 解锁窗（`UnchainLookWindow`，唯一每次重建 + 居中的那扇）──────────────────
func _十_解锁窗() -> void:
	var 窗 := _备(页脚本.页解锁)
	_擦()
	_喂帧(7, [], [])
	await _等(5)
	_判(_开着(窗), "帧 7 = 服务端**主动**催密码 ⇒ 开解锁窗（`requestPassword:4838-4841`）")
	_判(通告.is_empty() and 假.发过.is_empty(), "帧 7 只开窗，不弹也不发")
	var 页 := _页(窗)
	_判(_近([页.size.x, 页.size.y], 页尺["二级密码解锁"]), "解锁页根 = 270×196（225−29），实得 %s" % str([页.size.x, 页.size.y]))
	for 名 in 期解锁:
		var 件 := 页.get_node_or_null(名) as Control
		_判(_矩形对(件, 期解锁[名]),
				"解锁「%s」= (%s)，实得 (%s)" % [名, 期解锁[名], _矩(件) if 件 != null else "没建"])
	var 正文 := 页.get_node_or_null("正文") as RichTextLabel
	_判(正文 != null and 正文.text.contains("请输入二级密码进行解锁") and not 正文.text.contains("size"),
			"那句带 `size=\"16\"` 的 html：**摘掉 size 属性**交给整枚标签，转换器不会把 `\">` 替坏（实得「%s」）" % 正文.text)
	_判(正文 != null and int(正文.get_theme_font_size("normal_font_size")) == 16,
			"正文 = **16 号**（`:70-71` 那句是六扇里唯一 16 号的），实得 %s" % (正文.get_theme_font_size("normal_font_size") if 正文 != null else "没"))
	_判((页.get_node("请输入") as RichTextLabel).horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT,
			"「请输入」右对齐（`:74-75` 那一支 align=\"right\"）")
	_判((页.get_node("密码输入") as LineEdit).secret and (页.get_node("密码输入") as LineEdit).max_length == 14,
			"输入打点、上限 14 位")

	# 居中的针：挪歪 → 再喂帧 7 → 回正中
	var 原位: Vector2 = 窗.call("取位置偏移")
	窗.call("窗口偏移", Vector2(80, 60))
	await _等(2)
	var 歪位: Vector2 = 窗.call("取位置偏移")
	_喂帧(7, [], [])
	await _等(3)
	_判(歪位.distance_to(原位) > 1.0, "先把窗挪歪（挪没挪动这条要成立才谈得上下一判）实得 %s→%s" % [原位, 歪位])
	_判(窗.call("取位置偏移").distance_to(原位) < 0.6,
			"帧 7 再喂 ⇒ **回到正中央**（`showUnchainLookWindow` 是 removeWindow + centerWindow，不是 `reverseDisplay`）实得 %s vs %s" % [
				str(窗.call("取位置偏移")), str(原位)])

	_擦()
	_按(窗, "确定")
	await _等(2)
	_判(通告 == ["请输入密码！"] and 假.发过.is_empty() and _开着(窗),
			"空 ⇒ 只弹「请输入密码！」（NOTICE_1 :1365 带**全角叹号**）实得 告=%s" % str(通告))
	_输(窗, "密码输入", "abcdef")
	_擦()
	_按(窗, "确定")
	await _等(3)
	_判(假.发过 == [[8, ["abcdef"]]], "非空 ⇒ 发上 8，实发 %s" % str(假.发过))
	_判(not _开着(窗), "发完关窗（`:95` 走的是**被重写过的** `onCloseBtnClick`）")

	# 回帧 8：只写 `已解锁`，别的什么都不动
	_擦()
	_设账(1, 0, 0, false)
	_喂帧(8, [], [1])
	await _等(3)
	_判(通告.is_empty() and 假.发过.is_empty(), "帧 8 ⇒ 不弹不发（`releaseLockResult:6810-6816` 只置 `isunchainLook`）")
	_判(bool((后.get("authoritative_second_password") as Dictionary)["已解锁"]), "⇒ `已解锁` = (值[0]==1)")
	var 说: Node = 管._窗口们.get(页脚本.页说明)
	管.call("打开", 页脚本.页说明)
	await _等(3)
	_判(说 != null and _页(说) != null and (说.get("_二级密码页") as Node) == _页(说),
			"说明窗重新打开 ⇒ 页是**这一下重建**的（`onAddToStage:227-231 → initWindow`），不是建窗时那张死节点树")
	_判((_页(说).get_node("解除锁定") as Button).disabled,
			"已解锁之后 ⇒ 说明窗的「解除锁定」变灰（`updateView:38` 判的是 `type==1 && !isunchainLook`）")
	_设账(1, 0, 0, false)
	说.call("刷二级密码", -1)
	await _等(2)
	_判(not (_页(说).get_node("解除锁定") as Button).disabled, "解掉锁之后再刷 ⇒ 回灰（这一判钉的是**刷说明读账**，不是读上次结果）")
	说.call("close")

	# 这扇的输入**不留草稿**（唯一的一扇：`onCloseBtnClick:42-49` 先清输入再 removeWindow）
	管.call("打开", 页脚本.页解锁)
	await _等(3)
	_输(窗, "密码输入", "abcdef")
	_擦()
	_按(窗, "取消")
	await _等(2)
	_判(假.发过.is_empty() and 通告.is_empty() and not _开着(窗), "「取消」走的也是那枚重写过的关窗")
	管.call("打开", 页脚本.页解锁)
	await _等(4)
	_判((_页(窗).get_node("密码输入") as LineEdit).text == "",
			"再开 ⇒ 输入是**空的**（解锁窗是六扇里唯一关窗清草稿的）")
	窗.call("close")


## ── ⑪ 原版的三笔呆账 + 两份账的分工 ───────────────────────────────────────────
func _十一_呆账() -> void:
	# ① 三格标题被 Type3 改过就**再也回不去**
	var 窗 := _备(页脚本.页三格)
	管.call("打开", 页脚本.页三格)
	await _等(5)
	_判(String(窗.get("_title").get("text")) == "二级密码删除",
			"三格开回来标题仍是「二级密码删除」（`:333` 只有 Type3 那句 `title =`，而 `_windowMap` 记的是同一只实例）实得「%s」" % str(窗.get("_title").get("text")))
	_判(页脚本.三格删过, "端口用 `三格删过` 这一枚复现 ⇒ 别当 bug 修")

	# ② 草稿跨窗、跨开关活着（七枚 = `TwoPasswordManager` 的静态字段）
	_判(String(页脚本.草稿["答案1"]) == "甲答案" and String(页脚本.草稿["问题1"]) == "问题甲",
			"七枚草稿活在**脚本级 static**（六扇窗共享、关窗不清）实得 %s" % str(页脚本.草稿))
	窗.call("close")
	await _等(2)
	管.call("打开", 页脚本.页三格)
	await _等(5)
	_判((_页(窗).get_node("自订1") as LineEdit).text == "问题甲"
			and (_页(窗).get_node("答案输入1") as LineEdit).text == "甲答案",
			"关一次再开 ⇒ Type1 从草稿回填问题与答案（`initWindow:212-215`）实得 %s/%s" % [
				(_页(窗).get_node("自订1") as LineEdit).text, (_页(窗).get_node("答案输入1") as LineEdit).text])
	# ③ 菜单挂在遮罩上 ⇒ **关窗必须自己收掉**，否则盖着整屏
	_按(窗, "下拉1")
	await _等(3)
	_判(_找下拉(窗) != null, "先把菜单弹出来")
	窗.call("close")
	await _等(3)
	_判(_找下拉(窗) == null, "关窗 ⇒ 菜单一起收（`close()` 里那句 `_固定页 == 二级密码问题`）")

	# ④ 未连接 / 发送失败两句：**每一个出口**都要给个说法
	## ⚠ 拿一格那颗钮试，别拿说明窗的首钮：`_点设置` 先按 `_账(宿主).类型` 分流，
	## 而 `_backend == null` 时 `_账` 回的是**默认账**（类型 0）⇒ 那一下走「开一格」那一支、
	## 压根不进 `_发`，两句都不会弹。一格那颗钮是无条件发上 1，才试得出这两条出口。
	var 窗四 := _备(页脚本.页一格)
	管.call("打开", 页脚本.页一格)
	await _等(4)
	_输(窗四, "密码输入", "abcdef")
	_输(窗四, "确认输入", "abcdef")
	窗四.set("_backend", null)
	_擦()
	_按(窗四, "下一步")
	await _等(2)
	_判(通告 == ["二级密码：未连接服务端"], "后端 null ⇒ 弹「未连接服务端」而不是静悄悄，实得 %s" % str(通告))
	管.call("打开", 页脚本.页一格)
	await _等(3)
	_输(窗四, "密码输入", "abcdef")
	_输(窗四, "确认输入", "abcdef")
	var 拒 := 拒后.new()
	root.add_child(拒)
	窗四.set("_backend", 拒)
	_擦()
	_按(窗四, "下一步")
	await _等(2)
	_判(通告 == ["二级密码请求发送失败"], "返回 false ⇒ 弹「请求发送失败」，实得 %s" % str(通告))
	拒.free()
	窗四.set("_backend", 假)
	窗四.call("close")
	# 断线复位：四个数是服务端的 ⇒ 复位后页面读到的就是新数（草稿那一本**不动**）
	var 真: Dictionary = 后.get("authoritative_second_password")
	真["类型"] = 0
	真["已解锁"] = false
	_同步账()
	_判(int((假.get("authoritative_second_password") as Dictionary)["类型"]) == 0,
			"四个数只有**一本**：页面读 `authoritative_second_password`，门里不许有第二本")
