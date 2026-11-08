extends RefCounted
## 二级密码六窗（原版 `com.mxw.uifl.controls.twoPassword.*`）控制器。
## 逐件真值 = `真值/窗口/二级密码.md`（⓪ 先决口径 / ① 协议 / ② 矩形 / ③ 状态机 / ④ 两份账 / ⑤ 缺口）。
##
## 六个页面名对六只 AS3 类：说明=`TwoPasswordSayWindow`、设置=`SetPasswordPane1`、
## 资料=`SetPasswordPane2`、问题=`SetPasswordPane3`（三档共用一扇）、修改=`UpdatePasswordWindow`、
## 解锁=`UnchainLookWindow`。原版它们各是**独立的一扇窗**（`_windowMap` 四个键 + 一只弹层），
## 所以一个脚本六个 `渲染*`；逐页状态仍按工程口径挂在**宿主的具名变量**上
## （`set_meta` 的中文键会静默存不进去）。
##
## ⚠ 三条会影响读代码的形状：
## 1. **点入口不开窗**：背包那颗「二级密码」只发上行 0，开窗的是回帧 2
##    （`Client.as:1569-1577`）⇒ 与 神秘商店/随身药店 同族，与 摊位列表 正相反。
## 2. **`reverseDisplay` 是开关** ⇒ 回帧那一路走 `窗口管理.打开或收起`；
##    只有解锁窗走 `打开`（`showUnchainLookWindow:5690-5698` = removeWindow + centerWindow(新建)）。
## 3. 上行只带**字符串**（`values` 全 UTF），类型/次数/结果那些 int 是**下行**才有的 ⇒
##    客户端一律不猜，四个数只从 `后端连接.authoritative_second_password` 读；
##    玩家打了一半的草稿才是客户端自己的账（下面那份 `static var 草稿`）。

const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")

const 皮_内容面板 := "res://素材/界面/原版窗口/通用控件/内容面板.png"		# MYellow_background，九宫 [11,10,10,11]
const 皮_子面板 := "res://素材/界面/原版窗口/通用控件/子面板.png"			# MPane_background，九宫 [8,7,7,7]
const 皮_下拉 := "res://素材/界面/原版窗口/通用控件/下拉框.png"			# MComboBox 皮
const 皮_箭头 := "res://素材/界面/原版窗口/通用控件/下拉箭头.png"			# 13×8
const 皮_菜单底 := "res://素材/界面/原版窗口/通用控件/菜单底.png"			# MPopupMenu_background
const 皮_菜单项 := "res://素材/界面/原版窗口/通用控件/菜单按钮.png"		# MPopupMenuButtonF
const 钮字色 := Color(0.988235, 0.956863, 0.611765, 1)	# MButton3._textColors[up] = #fcf49c

## `TwoPasswordManager` 那三个**常量**（`:12/:14/:16`）—— 不是草稿，端口当常量抄。
const 最短密码 := 6			# minChars
const 密码最长 := 14			# maxChars（一格两枚、修改三枚、解锁一枚）
const 答案最长 := 40			# maxChar_result（三格四枚）
## 二格三枚输入在 AS3 里**根本没设 maxChars**（`SetPasswordPane2.as:145-147` 的
## `createTextField(宽,20)` 不带那一句）⇒ 这里给 0（= 不限），别顺手抄成 40。
const 不限 := 0

## 页名 = `数据/界面/窗口尺寸.json` 的键。
const 页说明 := "二级密码说明"
const 页一格 := "二级密码设置"
const 页二格 := "二级密码资料"
const 页三格 := "二级密码问题"
const 页修改 := "二级密码修改"
const 页解锁 := "二级密码解锁"
## 六扇的页根尺寸 = 外框 `宽 × (高 − 29)`（`整框: true` 那一支，容器原点 (0,29)）。
const 页根 := {
	页说明: [384.0, 353.0], 页一格: [270.0, 311.0], 页二格: [270.0, 311.0],
	页三格: [315.0, 311.0], 页修改: [315.0, 315.0], 页解锁: [270.0, 196.0],
}

## 上行动作号（`SecondLevelPasswordProcessor.as` 十个方法，见真值 §① 那张表）。
const 上_查询 := 0				# queryFirstTime:195-200
const 上_首次设置 := 1			# addPasswordFirstTime:18-25
const 上_联系方式 := 2			# sendContactInfo:45-53
const 上_问答 := 3				# sendQuestionsAndAnswers:27-36
const 上_问答确认 := 4			# sendConformQA:136-145
const 上_请求删除 := 5			# requestDeletePassword:280-285
const 上_删除确认 := 6			# conformDeletePassword:115-124
const 上_改密 := 7				# modifyPassword:126-134
const 上_解锁 := 8				# releaseLock:168-174
const 上_请求修改 := 9			# requestModifyPassword:38-43

## 三档（`TwoPasswordManager.setPasswordPane3_Type1/2/3` = 0/1/2）。
const 档设置 := 0
const 档确认 := 1
const 档删除 := 2

## 文案（逐条从 `en_US$message_properties.as` 抄，键后头就是行号）。
## ⚠ 这些是**带 `<font>` 的 html 原样**，画之前过 `输入确认弹.文案转BBCode`；
##   只有 `解锁正文` 那条带 `size="16"`，转换器会把 `">` 那对尾巴替坏 ⇒ 单独处理（见 `渲染解锁`）。
const 文 := {
	"说明正文": '<font color="#ffffff">  开启二级密码保护功能后，该帐号下的角色在每次登陆游戏时<br/>将自动进入锁定状态，锁定下的角色将无法进行以下操作：<br/>    1.物品交易<br/>    2.摆摊交易<br/>    3.元宝、点卷消费<br/>    4.家族捐献、家族管理<br/>    5.装备打造操作<br/>    6.宠物进阶、属性提升<br/>    7.物品丢弃<br/>    每次登陆后，您必须点击“解除锁定”按钮并正确输入二级密<br/>码才可以使用以上功能<br/></font><font color="#ff0000">注：为了您的帐号安全，建议您立即点击“设置密码”按钮进行<br/>二级密码设置。<br/>    *建议二级密码的设置不要与登录密码相同<br/>    *密码保护资讯中的密码保护问题与答案一经填写，将不可更改<br/>、删除。<br/>',	# :3090
	"设置密码": "设置密码",			# SETPASSWORD_BTN_TEXT :2295
	"删除密码": "删除密码",			# DELETE_PASSWORD :764
	"解除锁定": "解除锁定",			# UNCHAINLOOK_BTN_TEXT :34
	"修改密码": "修改密码",			# UPDATEPASSWORD_BTN_TEXT :1304
	"一格步骤": '<font color="#ff9100">1/3二级密码设置</font>',					# SEPPASSWORDPANE_1_TEXT_1 :925
	"一格已设": '<font color="#ff9100">你已经设置了密码保护问题</font>',			# TEXT_5 :917
	"一格请输入": '<font color="#ff9100">请输入密码：<font color="#00ff00">（密码长度为6-14位）</font></font>',	# TEXT_2 :920
	"一格请再次": '<font color="#ff9100">请再次输入密码：</font><font color="#00ff00">（密码长度为6-14位）</font>',	# TEXT_3 :918
	"一格提示": '<font color="#ff0000">温馨提示：请牢记你的二级密码</font>',		# TEXT_4 :919
	"不一致": "密码与确认密码不一致",	# SEPPASSWORDPANE_1_TEXT_6 :916 —— 一格、修改窗共用这一条
	"二格步骤": '<font color="#ff9100">2/3二级密码设置</font>',					# SEPPASSWORDPANE_2_TEXT_1 :1884
	"二格标题行": '<font color="#ff9100">请填写您的保护资料</font>',				# TEXT_2 :1883
	"二格联系方式": '<font color="#ff9100">1.请输入您的联系方式</font>',			# TEXT_3 :1882
	"邮箱": '<font color="#ff9100">联系邮箱:</font>',							# TEXT_4 :1881
	"手机": '<font color="#ff9100">绑定手机:</font>',							# TEXT_5 :1879
	"号码QQ": '<font color="#ff9100">联系QQ号:</font>',							# TEXT_6 :1877
	"二格提示": '<font color="#ff0000">温馨提示：该保护资料一经填写将不<br/>可修改。为避免遗忘，请填写真实信<br/>息，这将有助于您通过申诉找回二级<br/>密码<br/></font>',	# TEXT_7 :1875
	"邮箱错": "您输入的邮箱不正确",		# TEXT_8 :1874
	"三格标题": "二级密码设置嚮导",		# SEPPASSWORDPANE_3_TITLE :964（**一格窗用的也是这条**）
	"三格标题2": "二级密码删除",			# SEPPASSWORDPANE_3_TITLE_2 :2224
	"三格步骤设置": '<font color="#ff9100">2/3：密码保护资讯设置</font>',			# SEPPASSWORDPANE_3_TEXT_8 :243
	"三格步骤确认": '<font color="#ff9100">3/3：密码保护资讯设置</font>',			# TEXT_14 :859
	"问题1": '<font color="#ff9100">问题1:</font>',								# TEXT_9 :241
	"问题2": '<font color="#ff9100">问题2:</font>',								# TEXT_11 :863
	"答案1注": '<font color="#ff9100">答案1: <font color="#ff0000">（答案长度最多为40位）</font></font>',	# TEXT_10 :864
	"答案2注": '<font color="#ff9100">答案2: <font color="#ff0000">（答案长度最多为40位）</font></font>',	# TEXT_12 :862
	"答案1": '<font color="#ff9100">答案1: </font>',								# TEXT_16 :856
	"答案2": '<font color="#ff9100">答案2: </font>',								# TEXT_17 :855
	"三格提示": '<font color="#ff0000">以上资讯一经填写将不可更改或删除。为了避免遗<br/>忘，请填写真实资讯，这将有助于您通过回答问<br/>题快速召回二级密码。<br/></font>',	# TEXT_13 :861
	"三格确认提示": '<font color="#ff0000">以上是您刚刚设置的密保资讯，请依次做出回<br/>答，以便进行确认</font>',	# TEXT_15 :857
	"三格删除提示": '<font color="#ff0000">今天你还可以进行%1次操作</font>',		# TEXT_18 :852（`%1` = 剩余删除次数）
	"下一步": "下一步",			# NEXT_BTN_TEXT :624
	"上一步": "上一步",			# LAST_BTN_TEXT :2918
	"完成": "完成",				# WANCHENG :2142
	"取消": "取消",				# COMMON_CANCEL :1906
	"确定": "确定",				# COMMON_OK :2325
	"修改": "修改",				# UPDATE_BTN_TEXT :2086
	"删除": "删除",				# FRIEND_DEL :1665
	"修改窗旧": '<font color="#ff9100">请输入旧密码：</font>',					# UPDATEPASSWORD_WINDOW_TEXT_2 :64
	"修改窗新": '<font color="#ff9100">请输入新密码：<font color="#00ff00">（密码长度为6-14位）</font></font>',	# TEXT_3 :65
	"修改窗再": '<font color="#ff9100">请再次输入密码：</font>',					# TEXT_4 :63
	"修改窗次数": '<font color="#ff0000">您今天还可以进行%1次操作</font>',		# TEXT_1 :66
	"解锁正文": '<font color="#ff9100" size="16">请输入二级密码进行解锁</font>',	# UNCHAINLOOK_WINDOW_TEXT_1 :1686 ⚠ 带 size
	"解锁请输入": '<font color="#ff9100">请输入密码</font>',						# UNCHAINLOOK_WINDOW_TEXT_2 :1685
	"旧密码空": "请输入旧密码",		# UPDATEPASSWORD_WINDOW_NOTICE_1 :2739
	"新密码空": "请输入新密码",		# NOTICE_2 :2738
	"确认空": "请输入确认新密码",	# NOTICE_3 :2737
	"密码空": "请输入密码！",		# UNCHAINLOOK_WINDOW_NOTICE_1 :1365
	"问题重": "两次密码保护问题不能重复",	# SEPPASSWORDPANE_3_NOTICE_2 :1529
	"问题1空": "请选择问题1",		# NOTICE_3 :1528
	"问题2空": "请选择问题2",		# NOTICE_4 :1527
	"答案1空": "请输入答案1",		# NOTICE_5 :1524
	"答案2空": "请输入答案2",		# NOTICE_6 :1522
	"答案不认": "密码保护答案不一致",	# NOTICE_7 :1521
	"答案空": "请输入答案",			# NOTICE_1 :1532
	"设置失败": "设置二级密码失败",	# TWOPASSWORD_NOTICE_1 :2190
	"设置成功": "二级密码设置成功",	# NOTICE_2 :2188
	"删除成功": "删除密码成功",		# NOTICE_7 :2171
	"删除失败": "删除密码失败，今天还可以删除%1次",	# NOTICE_8 :2168
}

## 下拉七项 = `SetPasswordPane3.as:24` 的 `_dataProvider`（`SEPPASSWORDPANE_3_TEXT_1..7`，
## 语言表 `:251/250/248/247/246/245/244`）。第 0 项是**占位**，第 6 项「自订」才亮那枚 190 宽自由输入。
const 问题项 := ["请选择问题类型", "你的中学校名是？", "你的生日是？", "你的配偶的姓名是？",
		"你的父亲的姓名是？", "你的母亲的姓名是？", "自订"]
const 自订序 := 6

## 邮箱闸 = `TwoPasswordManager.mailRegExp:18`（AS3 字面 `\w+([-+.]\w+)*@\w+([-.]\w+)*\.\w+([\.]\w+)*`）。
const 邮箱式 := "\\w+([-+.]\\w+)*@\\w+([-.]\\w+)*\\.\\w+([\\.]\\w+)*"

## ── 六张矩形表（**页坐标** = AS3 外框坐标 − (0,29)；算式逐条见真值 §②）──────────
## 三元素 [x,y,宽] = 高由 Flash 的 `textHeight + 6` 现量（`_量高`），不是写死的数。
const 窗件说明 := {
	"底2": [6.0, 11.0, 372.0, 310.0],		# `:88-89` + `doLayout:81-82`：由外框高 382 反推出 310
	"底3": [11.0, 16.0, 362.0, 300.0],		# `:91-92`
	"正文": [16.0, 21.0, 364.0, 290.0],		# `:94-100` 宽 = 底2宽−8；高 = 底3高 − 10
	"设置密码": [50.0, 326.0, 61.0, 22.0],	# `:101-106` `_loc1_ = int((384−61×3)/4) = 50`
	"解除锁定": [161.0, 326.0, 61.0, 22.0],	# x = 50+61+50
	"修改密码": [272.0, 326.0, 61.0, 22.0],	# x = 161+61+50
}
const 窗件一格 := {
	"底2": [6.0, 11.0, 258.0, 260.0],		# `:100-102` 底2 高**写死 260**
	"底3": [11.0, 16.0, 248.0, 250.0],
	"步骤": [16.0, 21.0, 248.0, 20.0],		# `:106-107` x = 底3.x+5
	"请输入": [11.0, 41.0, 248.0, 20.0],		# `:113-114` x = 底3.x、y = 108−23−15
	"密码输入": [73.0, 79.0, 123.0, 23.0],	# `:109-112` x = 11+int((248−123)/2)、y = 45+63
	"请再次": [11.0, 145.0, 248.0, 20.0],		# `:119-120` y = 209−20−15
	"确认输入": [73.0, 180.0, 123.0, 23.0],	# `:115-118` y = 108+23+**78**（明写的间距）
	"提示": [11.0, 238.0, 248.0, 20.0],		# `:121-122` y = 209+23+35
	"下一步": [110.0, 276.0, 49.0, 22.0],	# `:123-124` x = int((270−49)/2)
}
const 窗件二格 := {
	"底2": [6.0, 11.0, 258.0, 260.0],		# `:74-79`
	"底3": [11.0, 16.0, 248.0, 250.0],
	"步骤": [16.0, 21.0, 248.0, 20.0],		# `:80-81` processLabel = TEXT_1
	"标题行": [16.0, 41.0, 248.0, 20.0],		# `:82-83` egisDatumLabel = TEXT_2
	"联系方式": [16.0, 61.0, 248.0, 20.0],	# `:84-85` contactLabel = TEXT_3
	"邮箱": [21.0, 84.0, 65.0, 20.0],			# `:86-91` label x = 底x−65、y = 底y + int((23−20)/2)
	"邮箱输入": [86.0, 83.0, 123.0, 23.0],	# 底 x = 11+75、y = 45+67
	"手机": [21.0, 117.0, 65.0, 20.0],			# `:92-97` 步长 = 23+10
	"手机输入": [86.0, 116.0, 123.0, 23.0],
	"号码QQ": [21.0, 150.0, 65.0, 20.0],		# `:98-103`
	"QQ输入": [86.0, 149.0, 123.0, 23.0],
	"提示": [11.0, 187.0, 248.0],				# `:104-105` x = 底3.x、y = 178+23+15；高现量
	"下一步": [110.0, 276.0, 49.0, 22.0],		# `:106-107`
}
const 窗件三格 := {
	"底2": [6.0, 11.0, 303.0, 260.0],		# `:222-227`
	"底3": [11.0, 16.0, 293.0, 250.0],
	"步骤": [16.0, 21.0, 293.0, 20.0],		# `:228-229`
	"问题1": [21.0, 41.0, 293.0, 20.0],		# `:230-231` x = 底3.x+10
	"下拉1": [61.0, 61.0, 210.0, 20.0],		# `:232-235` x = 底3.x+50、y = 问题1.y+20
	"自订1": [61.0, 62.0, 190.0, 20.0],		# `:301` 宽 = 210−20、y = 下拉 + 1
	"答案1": [21.0, 81.0, 293.0, 20.0],		# `:236-237` y = 90+20
	"答案输入1": [61.0, 101.0, 210.0, 23.0],	# `:238-241` y = 110+20、底高 23
	"问题2": [21.0, 124.0, 293.0, 20.0],		# `:242-243` y = 130+23
	"下拉2": [61.0, 144.0, 210.0, 20.0],		# `:244-247` y = 153+20
	"自订2": [61.0, 145.0, 190.0, 20.0],
	"答案2": [21.0, 164.0, 293.0, 20.0],		# `:248-249` y = 173+20
	"答案输入2": [61.0, 184.0, 210.0, 23.0],	# `:250-253` y = 193+20
	"提示": [16.0, 212.0, 293.0],				# `:254-255` x = 底3.x+5、y = 213+23+5；高现量
	"上一步": [72.0, 276.0, 49.0, 22.0],		# `:256-260` `_loc1_ = int((315−98)/3) = **72**`
	"下一步": [193.0, 276.0, 49.0, 22.0],	# x = 72+49+72（两边与中间**都是 72**，不是 70）
}
const 窗件修改 := {
	"底2": [6.0, 11.0, 303.0, 270.0],		# `:63-65`
	"底3": [11.0, 16.0, 293.0, 92.0],		# `:66-68`
	"底4": [11.0, 113.0, 293.0, 164.0],		# `:69-71` y = 45+92+5
	"旧": [16.0, 26.0, 293.0, 20.0],			# `:72-73` x = 底3.x+5、y = 45+10
	"旧输入": [90.0, 56.0, 123.0, 23.0],		# `:74-77` ⚠ **90 不是 96**：`:74` 那句 `+` 绑得比 `>>` 紧
	"新": [16.0, 123.0, 293.0, 20.0],			# `:78-79` y = 底4.y+10
	"新输入": [90.0, 153.0, 123.0, 23.0],		# `:80-83` y = 152+20+10
	"再次": [16.0, 186.0, 293.0, 20.0],		# `:84-85` y = 182+23+10
	"再次输入": [90.0, 216.0, 123.0, 23.0],	# `:86-89` y = 215+20+10
	"次数": [11.0, 249.0, 293.0, 20.0],		# `:90-91` x = 底3.x、y = 245+23+10、居中
	"修改": [80.0, 286.0, 37.0, 22.0],		# `:92-96` `_loc1_ = int((315−74)/3) = 80`
	"取消": [197.0, 286.0, 37.0, 22.0],		# x = 80+37+80
}
const 窗件解锁 := {
	"底2": [6.0, 11.0, 258.0, 146.0],		# `:64-66`
	"底3": [11.0, 16.0, 248.0, 136.0],
	"正文": [11.0, 41.0, 248.0, 20.0],		# `:70-71` x = 底3.x、y = 45+25、**16 号居中**
	"请输入": [16.0, 87.0, 65.0, 20.0],		# `:74-75` x = 底3.x+5、y = 底y+1、**右对齐**
	"密码输入": [80.0, 86.0, 123.0, 23.0],	# `:72-73` x = 11+65+4、y = 70+20+25
	"确定": [65.0, 162.0, 37.0, 22.0],		# `:78-82` `_loc1_ = int((270−74)/3) = 65`
	"取消": [167.0, 162.0, 37.0, 22.0],		# x = 65+37+65
}

## 玩家打了一半的草稿 = `TwoPasswordManager` 那七枚静态字段（`:24-38`）。
## ⚠ **脚本级 `static var`**，不是宿主上的：六扇窗是六个 `功能窗口` 实例，
## 存在实例上这一侧读不到那一侧（`洗点窗.gd` / `摊位窗.待买` 同一件事）。
## 关窗不清、断线也不清 —— 原版那七枚就活到进程结束。
## `类型/修改次数/删除次数/已解锁` **不在这里**：那是服务端推进来的，见真值 §④。
static var 草稿 := {"邮箱": "", "手机": "", "QQ": "", "问题1": "", "问题2": "",
		"答案1": "", "答案2": ""}

## 三格的标题一旦被 Type3 改成「二级密码删除」就**再也回不去**（`:333` 只有 Type3 那句 `title =`，
## 而 `_windowMap` 记的是同一只实例）—— 原版的呆账，端口用这一枚复现，别当 bug 修。
static var 三格删过 := false

## 邮箱正则**编译一次**存着：`RegEx.new()` 每次点钮都新建太浪费，而这条闸一次会话要走好多回。
static var _邮箱re: RegEx = null


## ── 建件 ────────────────────────────────────────────────────────────────────

static func _新页(宿主: Node, 页名: String) -> Control:
	## 页本体**代码现搭、不烘场景**（理由同 `摊位列表窗.gd:12-15`：整页就是一张几何表）。
	var 页 := Control.new()
	页.name = "二级密码内容"
	页.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 尺: Array = 页根[页名]
	页.size = Vector2(float(尺[0]), float(尺[1]))
	宿主._content.add_child(页)
	宿主._二级密码页 = 页
	return 页


static func _底(页: Control, 名: String, 尺: Array, 皮: String, 边: Array) -> NinePatchRect:
	var 面 := NinePatchRect.new()
	面.name = 名
	面.texture = load(皮) as Texture2D
	面.mouse_filter = Control.MOUSE_FILTER_IGNORE
	面.position = Vector2(float(尺[0]), float(尺[1]))
	面.size = Vector2(float(尺[2]), float(尺[3]))
	## ⚠ `patch_margin_*` 是 **int** 属性：收到 float 整条建件都中止（工程栽过）。
	面.patch_margin_left = int(边[0])
	面.patch_margin_right = int(边[1])
	面.patch_margin_top = int(边[2])
	面.patch_margin_bottom = int(边[3])
	页.add_child(面)
	return 面


## `MLabel` / `MGlowLabel`：12 号、**定高 20**、按 `align` 摆。这些句子全是**一段以上颜色**的
## html（嵌套 `<font>`），`Label` 只能一种颜色 ⇒ 一律 `RichTextLabel`（口径同 `周试炼任务窗`）。
static func _富文本(页: Control, 名: String, 尺: Array, html: String, 对齐: int,
		折行 := TextServer.AUTOWRAP_OFF, 字号 := 12) -> RichTextLabel:
	var 标 := RichTextLabel.new()
	标.name = 名
	标.bbcode_enabled = true
	标.scroll_active = false
	标.fit_content = false
	标.autowrap_mode = 折行
	标.position = Vector2(float(尺[0]), float(尺[1]))
	标.size = Vector2(float(尺[2]), float(尺[3]) if 尺.size() > 3 else _量高(html))
	标.add_theme_font_size_override("normal_font_size", 字号)
	标.add_theme_constant_override("line_separation", 0)
	标.mouse_filter = Control.MOUSE_FILTER_IGNORE
	标.horizontal_alignment = 对齐
	标.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	标.text = 确认弹.文案转BBCode(html)
	页.add_child(标)
	return 标


static func _钮(页: Control, 名: String, 尺: Array, 文本: String) -> Button:
	var 钮 := Button.new()
	钮.name = 名
	钮.text = 文本
	钮.focus_mode = Control.FOCUS_NONE
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.add_theme_font_size_override("font_size", 12)
	钮.add_theme_color_override("font_color", 钮字色)
	## `custom_minimum_size` 必须给到**这一档的宽**：`_configure_standard_button` 默认钉的是
	## MButtonF 原生 57×22，37/49/61 那三档不设就会被顶回 57 宽（同 `摊位列表窗._钮`）。
	钮.custom_minimum_size = Vector2(float(尺[2]), float(尺[3]))
	钮.position = Vector2(float(尺[0]), float(尺[1]))
	钮.size = Vector2(float(尺[2]), float(尺[3]))
	页.add_child(钮)
	return 钮


## 一枚输入：AS3 是 `MTextInput_background`(宽×23) + 里面的 `TextField`(宽×20、y+1、**居中**、
## `displayAsPassword` 时打点)。工程的主题已把 输入框.png 挂在 `LineEdit` 的 normal stylebox 上
## ⇒ 底不再另画一枚（口径同 `摊位列表窗` 的搜索框），尺寸拿**底那一格**。
static func _输入(页: Control, 名: String, 尺: Array, 最长: int, 密码: bool, 只读: bool) -> LineEdit:
	var 框 := LineEdit.new()
	框.name = 名
	框.position = Vector2(float(尺[0]), float(尺[1]))
	框.size = Vector2(float(尺[2]), float(尺[3]))
	框.max_length = 最长
	框.secret = 密码
	框.editable = not 只读
	框.focus_mode = Control.FOCUS_NONE if 只读 else Control.FOCUS_ALL
	框.alignment = HORIZONTAL_ALIGNMENT_CENTER		# `createTextField(…, "center")`
	框.add_theme_font_size_override("font_size", 12)
	页.add_child(框)
	return 框


static func _下拉(页: Control, 名: String, 尺: Array) -> TextureButton:
	var 钮 := TextureButton.new()
	钮.name = 名
	钮.ignore_texture_size = true
	钮.stretch_mode = TextureButton.STRETCH_SCALE
	钮.texture_normal = load(皮_下拉) as Texture2D
	钮.focus_mode = Control.FOCUS_NONE
	钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	钮.position = Vector2(float(尺[0]), float(尺[1]))
	钮.size = Vector2(float(尺[2]), float(尺[3]))
	页.add_child(钮)
	var 字 := Label.new()
	字.name = "文字"
	字.position = Vector2(6.0, 2.0)
	字.size = Vector2(尺[2] - 22.0, 16.0)
	字.add_theme_font_size_override("font_size", 12)	# `MComboBox.as:17` `_inputTextFormat` 12 号
	字.add_theme_color_override("font_color", Color.WHITE)
	字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	字.clip_text = true
	字.text_overrun_behavior = 0
	钮.add_child(字)
	var 箭 := TextureRect.new()
	箭.name = "箭头"
	箭.texture = load(皮_箭头) as Texture2D
	箭.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	箭.stretch_mode = TextureRect.STRETCH_KEEP
	箭.mouse_filter = Control.MOUSE_FILTER_IGNORE
	箭.position = Vector2(尺[2] - 15.0, 6.0)
	箭.size = Vector2(13.0, 8.0)
	钮.add_child(箭)
	return 钮


## ── 六个 `渲染*`（`功能窗口._render_page` 的调度表叫进来）─────────────────────

static func 渲染说明(宿主: Node) -> Control:
	var 页 := _新页(宿主, 页说明)
	_底(页, "底2", 窗件说明["底2"], 皮_内容面板, [11, 10, 10, 11])
	_底(页, "底3", 窗件说明["底3"], 皮_子面板, [8, 7, 7, 7])
	_富文本(页, "正文", 窗件说明["正文"], 文["说明正文"],
			HORIZONTAL_ALIGNMENT_LEFT, TextServer.AUTOWRAP_ARBITRARY)
	_钮(页, "设置密码", 窗件说明["设置密码"], 文["设置密码"]).pressed.connect(
			func() -> void: _点设置(宿主))
	_钮(页, "解除锁定", 窗件说明["解除锁定"], 文["解除锁定"]).pressed.connect(
			func() -> void: _点解锁钮(宿主))
	_钮(页, "修改密码", 窗件说明["修改密码"], 文["修改密码"]).pressed.connect(
			func() -> void: _点改密(宿主))
	## `initWindow:33-36` 全文一句 `updateView()` ⇒ 开窗就按服务端那份账刷三颗钮。
	刷说明(宿主)
	return 页


static func 渲染一格(宿主: Node) -> Control:
	var 页 := _新页(宿主, 页一格)
	_底(页, "底2", 窗件一格["底2"], 皮_内容面板, [11, 10, 10, 11])
	_底(页, "底3", 窗件一格["底3"], 皮_子面板, [8, 7, 7, 7])
	_富文本(页, "步骤", 窗件一格["步骤"], 文["一格步骤"], HORIZONTAL_ALIGNMENT_LEFT)
	_富文本(页, "请输入", 窗件一格["请输入"], 文["一格请输入"], HORIZONTAL_ALIGNMENT_CENTER)
	_输入(页, "密码输入", 窗件一格["密码输入"], 密码最长, true, false)
	_富文本(页, "请再次", 窗件一格["请再次"], 文["一格请再次"], HORIZONTAL_ALIGNMENT_CENTER)
	_输入(页, "确认输入", 窗件一格["确认输入"], 密码最长, true, false)
	_富文本(页, "提示", 窗件一格["提示"], 文["一格提示"], HORIZONTAL_ALIGNMENT_CENTER)
	_钮(页, "下一步", 窗件一格["下一步"], 文["下一步"]).pressed.connect(
			func() -> void: _点一格(宿主))
	## 两枚输入的 `Event.CHANGE` ⇒ `onInputpas/onInputpasOK:62-72/:127-137`：只动那颗钮的 enabled。
	var 闸 := func(_词: String) -> void: _闸一格(宿主)
	(页.get_node("密码输入") as LineEdit).text_changed.connect(闸)
	(页.get_node("确认输入") as LineEdit).text_changed.connect(闸)
	## `initWindow:215-217` → `updateView:74-96`（**清空两枚 + 换文字**）。
	刷一格(宿主)
	return 页


static func 渲染二格(宿主: Node) -> Control:
	var 页 := _新页(宿主, 页二格)
	_底(页, "底2", 窗件二格["底2"], 皮_内容面板, [11, 10, 10, 11])
	_底(页, "底3", 窗件二格["底3"], 皮_子面板, [8, 7, 7, 7])
	_富文本(页, "步骤", 窗件二格["步骤"], 文["二格步骤"], HORIZONTAL_ALIGNMENT_LEFT)
	_富文本(页, "标题行", 窗件二格["标题行"], 文["二格标题行"], HORIZONTAL_ALIGNMENT_LEFT)
	_富文本(页, "联系方式", 窗件二格["联系方式"], 文["二格联系方式"], HORIZONTAL_ALIGNMENT_LEFT)
	_富文本(页, "邮箱", 窗件二格["邮箱"], 文["邮箱"], HORIZONTAL_ALIGNMENT_LEFT)
	_输入(页, "邮箱输入", 窗件二格["邮箱输入"], 不限, false, false)
	_富文本(页, "手机", 窗件二格["手机"], 文["手机"], HORIZONTAL_ALIGNMENT_LEFT)
	_输入(页, "手机输入", 窗件二格["手机输入"], 不限, false, false)
	_富文本(页, "号码QQ", 窗件二格["号码QQ"], 文["号码QQ"], HORIZONTAL_ALIGNMENT_LEFT)
	_输入(页, "QQ输入", 窗件二格["QQ输入"], 不限, false, false)
	_富文本(页, "提示", 窗件二格["提示"], 文["二格提示"],
			HORIZONTAL_ALIGNMENT_CENTER, TextServer.AUTOWRAP_ARBITRARY)
	_钮(页, "下一步", 窗件二格["下一步"], 文["下一步"]).pressed.connect(
			func() -> void: _点二格(宿主))
	## 手机/QQ 两枚 `restrict = "0123456789"`（`:138/:140`）⇒ 工程没有 `restrict`，
	## 用 `text_changed` 现剔非数字。**赋 `.text` 不会再发一次 `text_changed`**（工程既有口径）⇒ 不成环。
	for 名 in ["手机输入", "QQ输入"]:
		(页.get_node(名) as LineEdit).text_changed.connect(
				func(词: String) -> void: _只留数字(页.get_node(名) as LineEdit, 词))
	## `initWindow:163-168`：回填三枚草稿 ⇒ 关窗不丢、跨窗共享。
	(页.get_node("邮箱输入") as LineEdit).text = String(草稿["邮箱"])
	(页.get_node("手机输入") as LineEdit).text = String(草稿["手机"])
	(页.get_node("QQ输入") as LineEdit).text = String(草稿["QQ"])
	return 页


static func 渲染三格(宿主: Node) -> Control:
	var 页 := _新页(宿主, 页三格)
	_底(页, "底2", 窗件三格["底2"], 皮_内容面板, [11, 10, 10, 11])
	_底(页, "底3", 窗件三格["底3"], 皮_子面板, [8, 7, 7, 7])
	_富文本(页, "步骤", 窗件三格["步骤"], 文["三格步骤设置"], HORIZONTAL_ALIGNMENT_LEFT)
	_富文本(页, "问题1", 窗件三格["问题1"], 文["问题1"], HORIZONTAL_ALIGNMENT_LEFT)
	_下拉(页, "下拉1", 窗件三格["下拉1"])
	_输入(页, "自订1", 窗件三格["自订1"], 答案最长, false, false)
	_富文本(页, "答案1", 窗件三格["答案1"], 文["答案1注"], HORIZONTAL_ALIGNMENT_LEFT)
	_输入(页, "答案输入1", 窗件三格["答案输入1"], 答案最长, false, false)
	_富文本(页, "问题2", 窗件三格["问题2"], 文["问题2"], HORIZONTAL_ALIGNMENT_LEFT)
	_下拉(页, "下拉2", 窗件三格["下拉2"])
	_输入(页, "自订2", 窗件三格["自订2"], 答案最长, false, false)
	_富文本(页, "答案2", 窗件三格["答案2"], 文["答案2注"], HORIZONTAL_ALIGNMENT_LEFT)
	_输入(页, "答案输入2", 窗件三格["答案输入2"], 答案最长, false, false)
	_富文本(页, "提示", 窗件三格["提示"], 文["三格提示"],
			HORIZONTAL_ALIGNMENT_LEFT, TextServer.AUTOWRAP_ARBITRARY)
	_钮(页, "上一步", 窗件三格["上一步"], 文["上一步"]).pressed.connect(
			func() -> void: _点三格上(宿主))
	_钮(页, "下一步", 窗件三格["下一步"], 文["下一步"]).pressed.connect(
			func() -> void: _点三格下(宿主))
	(页.get_node("下拉1") as TextureButton).pressed.connect(func() -> void: _弹下拉(宿主, 0))
	(页.get_node("下拉2") as TextureButton).pressed.connect(func() -> void: _弹下拉(宿主, 1))
	## `initWindow:211-218`：四格回填草稿、**档回到 Type1**。回帧 1/4/5/9 才叫 `updateView(Type2/3)`。
	## ⚠ 标题这里要**重新钉**：`_apply_original_window` 每次 `open_page` 都从尺寸表取
	##   「二级密码设置嚮导」，而 Type3 那次改过之后原版就永久停在「二级密码删除」⇒ 靠 `三格删过` 复现。
	宿主.设置标题(三格标题())
	刷三格(宿主, 档设置)
	return 页


static func 渲染修改(宿主: Node) -> Control:
	var 页 := _新页(宿主, 页修改)
	_底(页, "底2", 窗件修改["底2"], 皮_内容面板, [11, 10, 10, 11])
	_底(页, "底3", 窗件修改["底3"], 皮_子面板, [8, 7, 7, 7])
	_底(页, "底4", 窗件修改["底4"], 皮_子面板, [8, 7, 7, 7])
	_富文本(页, "旧", 窗件修改["旧"], 文["修改窗旧"], HORIZONTAL_ALIGNMENT_LEFT)
	_输入(页, "旧输入", 窗件修改["旧输入"], 密码最长, true, false)
	_富文本(页, "新", 窗件修改["新"], 文["修改窗新"], HORIZONTAL_ALIGNMENT_LEFT)
	_输入(页, "新输入", 窗件修改["新输入"], 密码最长, true, false)
	_富文本(页, "再次", 窗件修改["再次"], 文["修改窗再"], HORIZONTAL_ALIGNMENT_LEFT)
	_输入(页, "再次输入", 窗件修改["再次输入"], 密码最长, true, false)
	## 建窗那一句 `%1` 填的是**字面 5**（`:148` `CN.replaceString(TEXT_1, 5)`）—— 原版烘在代码里的
	## 占位数，`updateView` 立刻用服务端的 `修改次数` 盖掉。照抄，不是我们猜的默认值。
	_富文本(页, "次数", 窗件修改["次数"], 文["修改窗次数"].replace("%1", "5"),
			HORIZONTAL_ALIGNMENT_CENTER)
	var 钮 := _钮(页, "修改", 窗件修改["修改"], 文["修改"])
	钮.pressed.connect(func() -> void: _点修改(宿主))
	钮.disabled = true		# `:155` 建出来就是 disabled
	_钮(页, "取消", 窗件修改["取消"], 文["取消"]).pressed.connect(
			func() -> void: 宿主.close())		# `onClickCancelBtn:99-101` 只关窗、一帧不发
	var 闸 := func(_词: String) -> void: _闸修改(宿主)
	(页.get_node("新输入") as LineEdit).text_changed.connect(闸)
	(页.get_node("再次输入") as LineEdit).text_changed.connect(闸)
	## `initWindow` → `updateView:104-107`：只重刷那一句「还可以进行%1次」。
	刷修改(宿主)
	return 页


static func 渲染解锁(宿主: Node) -> Control:
	var 页 := _新页(宿主, 页解锁)
	_底(页, "底2", 窗件解锁["底2"], 皮_内容面板, [11, 10, 10, 11])
	_底(页, "底3", 窗件解锁["底3"], 皮_子面板, [8, 7, 7, 7])
	## ⚠ 这句带 `size="16"`，`文案转BBCode` 会把 `">` 那对尾巴替坏 ⇒ **摘掉 size 属性 + 整枚标签 16 号**
	## （AS3 那条 html 除了 color 和 size 没别的东西，size 又作用在整段上 ⇒ 这样等价）。
	_富文本(页, "正文", 窗件解锁["正文"], 文["解锁正文"].replace(' size="16"', ""),
			HORIZONTAL_ALIGNMENT_CENTER, TextServer.AUTOWRAP_OFF, 16)
	_富文本(页, "请输入", 窗件解锁["请输入"], 文["解锁请输入"], HORIZONTAL_ALIGNMENT_RIGHT)
	_输入(页, "密码输入", 窗件解锁["密码输入"], 密码最长, true, false)
	_钮(页, "确定", 窗件解锁["确定"], 文["确定"]).pressed.connect(
			func() -> void: _点解锁(宿主))
	_钮(页, "取消", 窗件解锁["取消"], 文["取消"]).pressed.connect(
			func() -> void: _关解锁(宿主))
	return 页


## ── updateView 那四条腿（`窗口管理._on_second_password` 按回帧叫进来）──────────

## `TwoPasswordSayWindow.updateView:37-42`：三条全读服务端那份账，客户端一个数都不猜。
static func 刷说明(宿主: Node) -> void:
	var 页 := _页在(宿主)
	if 页 == null:
		return
	var 账 := _账(宿主)
	var 类 := int(账.get("类型", 0))
	var 已解锁 := bool(账.get("已解锁", false))
	_设禁用(宿主, 页.get_node("解除锁定"), not (类 == 1 and not 已解锁))
	_设禁用(宿主, 页.get_node("修改密码"), 类 != 1)
	(页.get_node("设置密码") as Button).text = 文["删除密码"] if 类 == 1 else 文["设置密码"]


## `SetPasswordPane1.updateView:74-96`：**先清空两枚输入**、重算闸，再按 `类型` 换文字。
## ⚠ `类型 == 1` 两支 if **都不进**（原版只判 type_1=0 与 type_3=2）⇒ 那一档留着建窗时的
## 「1/3二级密码设置 / 下一步」。不是漏写 else，照抄。
static func 刷一格(宿主: Node) -> void:
	var 页 := _页在(宿主)
	if 页 == null:
		return
	(页.get_node("密码输入") as LineEdit).text = ""
	(页.get_node("确认输入") as LineEdit).text = ""
	_闸一格(宿主)
	var 类 := int(_账(宿主).get("类型", 0))
	if 类 == 0:
		(页.get_node("步骤") as RichTextLabel).text = 确认弹.文案转BBCode(文["一格步骤"])
		(页.get_node("下一步") as Button).text = 文["下一步"]
	if 类 == 2:
		(页.get_node("步骤") as RichTextLabel).text = 确认弹.文案转BBCode(文["一格已设"])
		(页.get_node("下一步") as Button).text = 文["完成"]


## `UpdatePasswordWindow.updateView:104-107` 全文就一句。
static func 刷修改(宿主: Node) -> void:
	var 页 := _页在(宿主)
	if 页 == null:
		return
	(页.get_node("次数") as RichTextLabel).text = 确认弹.文案转BBCode(
			文["修改窗次数"].replace("%1", str(int(_账(宿主).get("修改次数", 0)))))


## `SetPasswordPane3.updateView:120-175`：**三档只换显示与文字，矩形一个都不动**。
## 档 0 = Type1 设置、1 = Type2 确认、2 = Type3 删除。
static func 刷三格(宿主: Node, 档: int) -> void:
	var 页 := _页在(宿主)
	if 页 == null:
		return
	宿主._二级密码问题型 = 档
	关下拉(宿主)
	var 设置 := (档 == 档设置)
	## 下拉与那枚 190 宽自由输入**互斥**：Type1 亮下拉（`:126` 把两枚输入 `visible = false`，
	## 之后只有选了「自订」才由 `onSelectProblem*` 亮回来）；Type2/3 收起下拉、亮输入且**只读**
	## （`:146/:161` 关的是 `mouseEnabled/selectable` ⇒ 端口 `editable = false`）。
	## ⚠ Type1 这一支**不看**上一次是不是选了「自订」：`:126` 无条件把两枚 `inputProblem`
	## 收起来、`:130` 把草稿写进下拉的显示位。所以玩家自订过的问题在回 Type1 之后
	## 是**显示在下拉那一格里**的（原版就这么摆）。
	for 序 in 2:
		var n := str(序 + 1)
		(页.get_node("下拉" + n) as TextureButton).visible = 设置
		var 框 := 页.get_node("自订" + n) as LineEdit
		框.visible = not 设置
		框.editable = 设置
		框.focus_mode = Control.FOCUS_ALL if 设置 else Control.FOCUS_NONE
		## 问题文本**永远写在 `自订n` 里**（AS3 判式与上行读的都是 `inputProblemN.text`）；
		## Type1 时它藏在后面，显示位是下拉那一格的 `文字`。
		框.text = String(草稿["问题" + n])
		if 设置:
			(页.get_node("下拉" + n + "/文字") as Label).text = String(草稿["问题" + n])
	## ⚠ 四枚输入里**只有 `inputProblem` 被关过 mouseEnabled**（`:127/:146/:163`）；
	## 两枚答案在三档里**始终可编辑**（Type2/3 只 `API.resetFocus` + 清文字，`:147-148/:164`）。
	if 档 == 档设置:
		(页.get_node("答案输入1") as LineEdit).text = String(草稿["答案1"])
		(页.get_node("答案输入2") as LineEdit).text = String(草稿["答案2"])
		_换(页, "步骤", 文["三格步骤设置"])
		_换(页, "答案1", 文["答案1注"])
		_换(页, "答案2", 文["答案2注"])
		_提示(页, 文["三格提示"], 窗件三格["提示"], HORIZONTAL_ALIGNMENT_LEFT, 212.0)
		(页.get_node("上一步") as Button).text = 文["上一步"]
		(页.get_node("下一步") as Button).text = 文["下一步"]
	elif 档 == 档确认:
		(页.get_node("答案输入1") as LineEdit).text = ""
		(页.get_node("答案输入2") as LineEdit).text = ""
		_换(页, "步骤", 文["三格步骤确认"])
		_换(页, "答案1", 文["答案1"])
		_换(页, "答案2", 文["答案2"])
		_提示(页, 文["三格确认提示"], 窗件三格["提示"], HORIZONTAL_ALIGNMENT_LEFT, 212.0)
		(页.get_node("上一步") as Button).text = 文["上一步"]
		(页.get_node("下一步") as Button).text = 文["完成"]
	else:
		## Type3 删除档：问题显示**回帧 5 塞进草稿的那两条**、答案清零、步骤清空，
		## 提示换居中那句「今天你还可以进行%1次操作」，y 从 `+5` 变 `+15`（`:172` ⇒ 页 222）。
		(页.get_node("答案输入1") as LineEdit).text = ""
		(页.get_node("答案输入2") as LineEdit).text = ""
		(页.get_node("步骤") as RichTextLabel).text = ""
		_换(页, "答案1", 文["答案1"])
		_换(页, "答案2", 文["答案2"])
		_提示(页, 文["三格删除提示"].replace("%1", str(int(_账(宿主).get("删除次数", 0)))),
				窗件三格["提示"], HORIZONTAL_ALIGNMENT_CENTER, 222.0)
		(页.get_node("上一步") as Button).text = 文["删除"]
		(页.get_node("下一步") as Button).text = 文["取消"]
		三格删过 = true
		宿主.设置标题(三格标题())


## 建窗时标题取 `SEPPASSWORDPANE_3_TITLE`（`:333`）；进过 Type3 之后永久是「二级密码删除」。
static func 三格标题() -> String:
	return String(文["三格标题2"]) if 三格删过 else String(文["三格标题"])


## ── 上行：12 条判式（门槛全在客户端，见真值 §③）──────────────────────────────

## 说明窗首钮（`onClickSetPassword:50-61`）：**类型==1 才是「删除密码」⇒ 发 5**，
## 否则一帧不发、只把一格开出来（`reverseDisplay(SET PASSWORD_PANE1)`）。两条都关说明窗。
static func _点设置(宿主: Node) -> void:
	if int(_账(宿主).get("类型", 0)) == 1:
		_发(宿主, 上_请求删除, [])
	else:
		_开关(宿主, 页一格)
	宿主.close()


## 说明窗「解除锁定」（`onClickUnchainLook:122-126`）：**不发帧**，
## 走 `showUnchainLookWindow()`（每次重建 + 居中）再关说明窗。
static func _点解锁钮(宿主: Node) -> void:
	_打开(宿主, 页解锁)
	宿主.close()


## 说明窗「修改密码」（`onClickUpdatePassword:44-48`）：发 9 + 关自己（开窗的是回帧 10）。
static func _点改密(宿主: Node) -> void:
	_发(宿主, 上_请求修改, [])
	宿主.close()


## 一格「下一步／完成」（`onClickNext:48-60`）：不等 ⇒ 只弹一句；等 ⇒ 发 1 + 关自己。
## ⚠ 原版这里还写了一记 `TwoPasswordManager.twoPassword`（`:56`）—— 那字段全库再没人读，
##   端口不接（真值 §④ 的死字段四条之一）。
static func _点一格(宿主: Node) -> void:
	var 页 := _页在(宿主)
	if 页 == null:
		return
	var 一 := (页.get_node("密码输入") as LineEdit).text
	var 二 := (页.get_node("确认输入") as LineEdit).text
	if 一 != 二:
		宿主._通知(文["不一致"])
		return
	_发(宿主, 上_首次设置, [一, 二])
	宿主.close()


## 二格「下一步」（`onClickNext:181-195`）：**只判邮箱那一条**，手机/QQ 空着也照发。
## 过了才把三枚草稿写下来（写在成功腿里 ⇒ 失败不留）+ 发 2 + 关自己。
static func _点二格(宿主: Node) -> void:
	var 页 := _页在(宿主)
	if 页 == null:
		return
	var 邮 := (页.get_node("邮箱输入") as LineEdit).text
	var 机 := (页.get_node("手机输入") as LineEdit).text
	var 号 := (页.get_node("QQ输入") as LineEdit).text
	if _邮箱re == null:
		_邮箱re = RegEx.new()
		_邮箱re.compile(邮箱式)
	## ⚠ 用 `search`：AS3 那一句是 `TwoPasswordManager.mailRegExp.test(inputMail.text)`
	## （`SetPasswordPane2.as:183`），式子里**没有 `^` 也没有 `$`** ⇒ ECMAScript 语义是**全串找**：
	## 「流尘 a@b.co」「a@b.c.o」这种两边都放行，只有整串里凑不出式子才拦。
	## （Godot `RegEx` 根本没有 `match()`，写成 `match` 是运行期报「Nonexistent function」，
	## 而这一句在 `_点二格` 里 ⇒ 整条上行一帧不发、静默失败。）
	if _邮箱re.search(邮) == null:
		宿主._通知(文["邮箱错"])
		return
	草稿["邮箱"] = 邮
	草稿["手机"] = 机
	草稿["QQ"] = 号
	_发(宿主, 上_联系方式, [邮, 机, 号])
	宿主.close()


## 三格那颗钮三档三条腿（`onClickNext:69-118`）。
static func _点三格下(宿主: Node) -> void:
	var 页 := _页在(宿主)
	if 页 == null:
		return
	var 档 := int(宿主._二级密码问题型)
	var 问1 := (页.get_node("自订1") as LineEdit).text
	var 问2 := (页.get_node("自订2") as LineEdit).text
	var 答1 := (页.get_node("答案输入1") as LineEdit).text
	var 答2 := (页.get_node("答案输入2") as LineEdit).text
	if 档 == 档设置:
		## 判式**之前**先把四格写进草稿（`:71-74` 就那个顺序）⇒ 后面关窗再开还在。
		草稿["问题1"] = 问1
		草稿["问题2"] = 问2
		草稿["答案1"] = 答1
		草稿["答案2"] = 答2
		if 问1 == 问2:
			宿主._通知(文["问题重"])
			return
		if 问1 == "":
			宿主._通知(文["问题1空"])
			return
		if 问2 == "":
			宿主._通知(文["问题2空"])
			return
		if 答1 == "":
			宿主._通知(文["答案1空"])
			return
		if 答2 == "":
			宿主._通知(文["答案2空"])
			return
		_发(宿主, 上_问答, [问1, 答1, 问2, 答2])
		## ⚠ 发完**不关窗**：关窗的是回帧 4 那条成功腿（`Client.as:6451`）。
		return
	if 档 == 档确认:
		## 答案**跟本地草稿比**（`:107-112`）—— 不发帧、也不问服务端。
		if 答1 != String(草稿["答案1"]) or 答2 != String(草稿["答案2"]):
			宿主._通知(文["答案不认"])
			return
		_发(宿主, 上_问答确认, [问1, 答1, 问2, 答2])
		return
	## 档 == 档删除：那颗钮写的是「取消」⇒ 只关窗（`:114-117`）。
	宿主.close()


## 三格另一颗钮三档三条腿（`onClickLast:346-367`）。
static func _点三格上(宿主: Node) -> void:
	var 页 := _页在(宿主)
	if 页 == null:
		return
	var 档 := int(宿主._二级密码问题型)
	if 档 == 档设置:
		_开关(宿主, 页二格)		# reverseDisplay(PANE2)：二格已开着就被这一下**收起**
		宿主.close()
		return
	if 档 == 档确认:
		## ⚠ **一帧不发**，只把画面切回 Type1（`:354-357`）。答案已经在草稿里，不丢。
		刷三格(宿主, 档设置)
		return
	## 档 == 档删除：那颗钮写着「删除」⇒ 两枚答案任一为空就弹一句不发（`:358-366`）。
	var 答1 := (页.get_node("答案输入1") as LineEdit).text
	var 答2 := (页.get_node("答案输入2") as LineEdit).text
	if 答1 == "" or 答2 == "":
		宿主._通知(文["答案空"])
		return
	_发(宿主, 上_删除确认, [
		(页.get_node("自订1") as LineEdit).text, 答1,
		(页.get_node("自订2") as LineEdit).text, 答2])
	## 发完**不关窗**：关不关由回帧 9 判（成功才关；失败留在删除档刷那句次数）。


## 修改窗「修改」（`onClickUpdateBtn:169-192`）：四条非空判式按序 → 两枚新密码一致 → 发 7。
## ⚠ **发完不关窗**（`:191` 后面没有 `onCloseBtnClick`）⇒ 关不关由回帧 6 决定。
static func _点修改(宿主: Node) -> void:
	var 页 := _页在(宿主)
	if 页 == null:
		return
	var 旧 := (页.get_node("旧输入") as LineEdit).text
	var 新 := (页.get_node("新输入") as LineEdit).text
	var 再 := (页.get_node("再次输入") as LineEdit).text
	if 旧 == "":
		宿主._通知(文["旧密码空"])
		return
	if 新 == "":
		宿主._通知(文["新密码空"])
		return
	if 再 == "":
		宿主._通知(文["确认空"])
		return
	if 新 != 再:
		宿主._通知(文["不一致"])
		return
	_发(宿主, 上_改密, [旧, 新, 再])


## 解锁窗「确定」（`onClickOkBtn:85-96`）：非空 ⇒ 发 8 + 走**被重写过的**关窗（先清输入）。
static func _点解锁(宿主: Node) -> void:
	var 页 := _页在(宿主)
	if 页 == null:
		return
	var 码 := (页.get_node("密码输入") as LineEdit).text
	if 码 == "":
		宿主._通知(文["密码空"])
		return
	_发(宿主, 上_解锁, [码])
	_关解锁(宿主)


## `UnchainLookWindow.onCloseBtnClick:42-49`：清输入再 `removeWindow` ⇒ **这扇的草稿不留**
## （和 Pane2/Pane3 那两族正相反）。「取消」那颗走的也是同一个重写过的关窗。
static func _关解锁(宿主: Node) -> void:
	var 页 := _页在(宿主)
	if 页 != null:
		(页.get_node("密码输入") as LineEdit).text = ""
	宿主.close()


## ── 下拉（`MComboBox` 的移植形状 = `摊位列表窗._弹下拉` 那一套）────────────────

static func _弹下拉(宿主: Node, 序: int) -> void:
	关下拉(宿主)
	var 页 := _页在(宿主)
	if 页 == null:
		return
	var 锚 := 页.get_node("下拉%d" % (序 + 1)) as TextureButton
	var 底 := Panel.new()
	底.name = "二级密码下拉"
	var 皮 := StyleBoxTexture.new()
	皮.texture = load(皮_菜单底) as Texture2D
	for i in 4:
		皮.set("texture_margin_%s" % ["left", "top", "right", "bottom"][i], [5.75, 4.75, 9.75, 11.0][i])
	底.add_theme_stylebox_override("panel", 皮)
	底.mouse_filter = Control.MOUSE_FILTER_STOP
	## ⚠ **必须提层**：不提时点第三项会打在页上、**静默没反应**（同 `摊位列表窗._弹下拉`）。
	底.z_index = 50
	## 挂**宿主的遮罩**：页每轮刷新整个重建，挂页里会被连手清掉。
	宿主._overlay.add_child(底)
	var 顶 := 3.0
	for i in 问题项.size():
		var 项 := Button.new()
		项.name = "项%d" % i
		项.text = String(问题项[i])
		项.flat = true
		项.focus_mode = Control.FOCUS_NONE
		项.add_theme_font_size_override("font_size", 12)
		项.add_theme_color_override("font_color", 钮字色)
		项.position = Vector2(3.0, 顶)
		项.size = Vector2(锚.size.x - 6.0, 19.0)
		var 项皮 := StyleBoxTexture.new()
		项皮.texture = load(皮_菜单项) as Texture2D
		for j in 4:
			项皮.set("texture_margin_%s" % ["left", "top", "right", "bottom"][j], [2.25, 2.0, 2.5, 2.5][j])
		for 态 in ["normal", "hover", "pressed"]:
			项.add_theme_stylebox_override(态, 项皮)
		项.pressed.connect(_选题.bind(宿主, 序, i))
		底.add_child(项)
		顶 += 19.0 + 3.0
	底.size = Vector2(锚.size.x + 4.0, 顶 + 3.0)
	底.global_position = Vector2(锚.global_position.x, 锚.global_position.y + 锚.size.y + 2.0)
	宿主._二级密码下拉 = 底


## `onSelectProblem1/2:177-209`：选「自订」⇒ 亮出自由输入、把下拉显示与输入**都清空**、焦点给它；
## 选别的 ⇒ 收起那枚输入、把它的 text 设成该项（显示位仍是下拉里的 `文字`）。
static func _选题(宿主: Node, 序: int, 项: int) -> void:
	var 页 := _页在(宿主)
	if 页 == null:
		return
	var n := str(序 + 1)
	var 框 := 页.get_node("自订" + n) as LineEdit
	var 字 := 页.get_node("下拉" + n + "/文字") as Label
	var 键 := "问题" + n
	if 项 == 自订序:
		框.visible = true
		框.text = ""
		字.text = ""
		草稿[键] = ""
		框.grab_focus()
	else:
		框.visible = false
		框.text = String(问题项[项])
		字.text = String(问题项[项])
		草稿[键] = String(问题项[项])
	关下拉(宿主)


static func 关下拉(宿主: Node) -> void:
	var 盘 = 宿主._二级密码下拉
	if 盘 != null and is_instance_valid(盘):
		盘.queue_free()
	宿主._二级密码下拉 = null


## ── 小工具 ──────────────────────────────────────────────────────────────────

## 当前宿主台上那页；**页没了或已脱离 `_content` ⇒ null**（回帧打进没开的窗就一条都不做）。
static func _页在(宿主: Node) -> Control:
	var 页 = 宿主._二级密码页
	if 页 == null or not is_instance_valid(页) or (页 as Control).get_parent() != 宿主._content:
		return null
	return 页 as Control


static func _账(宿主: Node) -> Dictionary:
	var 后 = 宿主._backend
	if 后 == null:
		return {"类型": 0, "修改次数": 0, "删除次数": 0, "已解锁": false}
	var 账 = 后.get("authoritative_second_password")
	return (账 as Dictionary) if (账 is Dictionary) else {}


static func _发(宿主: Node, 动作: int, 串表: Array) -> void:
	var 后 = 宿主._backend
	if 后 == null or not bool(后.get("in_game")):
		宿主._通知("二级密码：未连接服务端")
		return
	if not bool(后.request_second_password(动作, 串表)):
		宿主._通知("二级密码请求发送失败")


## `窗口管理.打开或收起` = 原版 `reverseDisplay`（**开关**：已开 ⇒ 收起）。
static func _开关(宿主: Node, 页名: String) -> void:
	var 管理: Node = 宿主.get_parent()
	if 管理 != null and 管理.has_method("打开或收起"):
		管理.call("打开或收起", 页名)


## `showUnchainLookWindow` = 每次重建 + 居中 ⇒ 走 `打开`（对已开的窗幂等，`渲染解锁` 重跑就是空输入）。
static func _打开(宿主: Node, 页名: String) -> void:
	var 管理: Node = 宿主.get_parent()
	if 管理 != null and 管理.has_method("打开"):
		管理.call("打开", 页名)


static func _设禁用(宿主: Node, 件: Control, 是: bool) -> void:
	件.disabled = 是
	## 禁用态 = **同一张图套灰度**（`MButton3.updateState:329-339` 的 `getGrayFilter()`）。
	件.material = 宿主.禁用灰度材质() if 是 else null


## 一格那颗钮：两枚**都**要 ≥ 6 位才亮（`:62-72` 那是 `<6 || <6` 的或条件 ⇒ 任一短就灰）。
static func _闸一格(宿主: Node) -> void:
	var 页 := _页在(宿主)
	if 页 == null:
		return
	var 一 := (页.get_node("密码输入") as LineEdit).text.length()
	var 二 := (页.get_node("确认输入") as LineEdit).text.length()
	_设禁用(宿主, 页.get_node("下一步"), 一 < 最短密码 or 二 < 最短密码)


## 修改那颗钮：判的是**两枚新密码**（`:210-232` 两腿读的都是 `newPas`/`newPasKo`），旧密码不算。
static func _闸修改(宿主: Node) -> void:
	var 页 := _页在(宿主)
	if 页 == null:
		return
	var 新 := (页.get_node("新输入") as LineEdit).text.length()
	var 再 := (页.get_node("再次输入") as LineEdit).text.length()
	_设禁用(宿主, 页.get_node("修改"), 新 < 最短密码 or 再 < 最短密码)


static func _换(页: Control, 名: String, html: String) -> void:
	(页.get_node(名) as RichTextLabel).text = 确认弹.文案转BBCode(html)


## `height = textHeight + 6`：Flash 行盒按 15 算（口径同 `周试炼任务窗._盒高`），
## 行数只数 `\n` —— **不去量 Godot 的真实折行**：AS3 那三句提示每行都在 `<br/>` 上断好了，
## 而量出来的行数只会和钉死的外框高打架（真值 §② 那条同款理由）。
static func _量高(html: String) -> float:
	var 文 := 确认弹.文案转BBCode(html)
	if 文.is_empty():
		return 0.0
	var 行 := 文.count("\n") + 1
	if 文.ends_with("\n"):
		行 -= 1
	return 15.0 * float(行) + 6.0


## 三格/二格那枚现量提示：换文字 = 换高度（+ Type3 的 y 比另两档低 10）。
static func _提示(页: Control, html: String, 尺: Array, 对齐: int, y: float) -> void:
	var 标 := 页.get_node("提示") as RichTextLabel
	标.text = 确认弹.文案转BBCode(html)
	标.horizontal_alignment = 对齐
	标.size.y = _量高(html)
	标.position.y = y


## `restrict = "0123456789"` 的等价物：把非数字剔掉再写回去。
static func _只留数字(框: LineEdit, 词: String) -> void:
	var 留 := ""
	for c in 词:
		if c >= "0" and c <= "9":
			留 += c
	if 留 != 词:
		框.text = 留
