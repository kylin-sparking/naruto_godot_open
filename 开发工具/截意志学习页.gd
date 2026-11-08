extends "res://开发工具/量具基类.gd"

## 量「意志学习」窗（原版 `com/mxw/uifl/controls/yiZhi/YiZhiStudyWindow.as`，772×564）。
## 骨架在 `开发工具/量具基类.gd`；场景由 `开发工具/生成意志学习场景.py` 从本文件的
## `件路径 / 件期望` 两张表生成 ⇒ **改真值只改这里**，别手改 .tscn。
##
## 坐标链（逐条有出处，全表见 `game-client/真值/窗口/意志学习.md`）：
##   `super(772,564,false)` `:44`；`_contentBg` MYellow @(8,38) 756×518 `:183-188`
##   `_housePanel` @ `_contentBg + 2` = (10,40) `:70-72`
##   页面容器原点 (0,29)（`窗口尺寸.json` 的「意志学习」标 `整框: true`）
##   ⇒ **场景 y = AS3 窗口局部 y − 29**
##
## 用法（不能加 --headless）：
##   Godot --path . --script res://开发工具/截意志学习页.gd -- --出目录=res://测试/截图/意志学习

const 件路径 := {
	"外框黄底": "外框黄底",
	"主背景": "主背景",
	"小标题条": "小标题条",
	"元宝图标": "货币条/元宝图标", "元宝数值": "货币条/元宝数值",
	"阅历图标": "货币条/阅历图标", "阅历数值": "货币条/阅历数值",
	"意志容器": "意志容器",
	"意志格0": "意志容器/意志格_0", "意志格1": "意志容器/意志格_1", "意志格2": "意志容器/意志格_2",
	"意志格3": "意志容器/意志格_3", "意志格4": "意志容器/意志格_4", "意志格5": "意志容器/意志格_5",
	"意志格6": "意志容器/意志格_6", "意志格7": "意志容器/意志格_7", "意志格8": "意志容器/意志格_8",
	"意志格9": "意志容器/意志格_9",
	# 第二层（§3.185，2026-10-22 用户实机报「应该有第二层，但是没有显示」）：
	# 原版 YiZhiContainer LENGTH=10 动态排两行 ⇒ 第 11..20 件在第二排。
	"意志格10": "意志容器/意志格_10", "意志格11": "意志容器/意志格_11", "意志格12": "意志容器/意志格_12",
	"意志格13": "意志容器/意志格_13", "意志格14": "意志容器/意志格_14", "意志格15": "意志容器/意志格_15",
	"意志格16": "意志容器/意志格_16", "意志格17": "意志容器/意志格_17", "意志格18": "意志容器/意志格_18",
	"意志格19": "意志容器/意志格_19",
	"格0底": "意志容器/意志格_0/格底", "格0图标": "意志容器/意志格_0/图标",
	"格0名称": "意志容器/意志格_0/名称", "格0卖出": "意志容器/意志格_0/卖出",
	"格0拾取": "意志容器/意志格_0/拾取",
	"导师面板": "导师面板",
	"导师条底": "导师面板/条底",
	"导师容器": "导师面板/导师容器",
	"导师0": "导师面板/导师容器/导师_0", "导师1": "导师面板/导师容器/导师_1",
	"导师2": "导师面板/导师容器/导师_2", "导师3": "导师面板/导师容器/导师_3",
	"导师4": "导师面板/导师容器/导师_4",
	"导师0头像": "导师面板/导师容器/导师_0/头像", "导师0悬停框": "导师面板/导师容器/导师_0/悬停框",
	"导师0气泡": "导师面板/导师容器/导师_0/气泡", "导师0召唤": "导师面板/导师容器/导师_0/召唤",
	"召唤文字": "导师面板/导师容器/导师_0/召唤/召唤文字",
	"导师1气泡": "导师面板/导师容器/导师_1/气泡",
	"今日次数": "导师面板/今日次数", "说明文字": "导师面板/说明文字",
	"一键学习": "导师面板/一键学习", "全部拾取": "导师面板/全部拾取",
	"全部卖出": "导师面板/全部卖出", "返回": "导师面板/返回",
	"打开背包": "导师面板/打开背包",
}

## 页面局部 = AS3 窗口局部 − (0,29)。每条注释是算式与出处行。
const 件期望 := {
	"外框黄底": [8, 9, 756, 518],				# :183-188 x=CONTENT_GAP=8 y=38 w=772−16 h=564−8−38
	"主背景": [10, 11, 750, 514],				# :74-75 housePanel(10,40) 内 (0,0)，UISwf_yizhi_background 原生 750×514
	"小标题条": [15, 16, 190, 25],				# :76-80 x=BORDER_GAP=5 y=5 width=190（原生 171×25，只设宽 ⇒ 高保持 25）
	"元宝图标": [20, 21, 19, 13],				# :81-83 x=5+5=10 y=5+5=10；MIconGoldYuanBaoF(703) 原生 19×13
	"元宝数值": [39, 19, 60, 19],				# :85-87 x=图标.x+图标.width=10+19 y=图标.y−2=8；宽=测量(未证，见真值表§5)
	"阅历图标": [109, 23, 17, 13],				# :89-91 x=元宝label.x+70=109 y=图标.y+2=12；原生 17×13
	"阅历数值": [126, 19, 60, 19],				# :94-96 x=阅历.x+阅历.width=109+17 y=元宝label.y
	"意志容器": [15, 71, 712, 144],				# :98-100 x=标题.x=5 y=标题.y+标题.height+30=5+25+30=60；**两行**10 格 ⇒ 宽 9·72+62、高 62+82+62
	"意志格0": [15, 71, 62, 62],					# YiZhiContainer:64-69 x=(i%10)·(62+10) y=(i/10)·(62+20)
	"意志格1": [87, 71, 62, 62], "意志格2": [159, 71, 62, 62], "意志格3": [231, 71, 62, 62],
	"意志格4": [303, 71, 62, 62], "意志格5": [375, 71, 62, 62], "意志格6": [447, 71, 62, 62],
	"意志格7": [519, 71, 62, 62], "意志格8": [591, 71, 62, 62], "意志格9": [663, 71, 62, 62],
	# ⚠️ 2026-10-22 第二层（用户实机报「应该有第二层，但是没有显示」）：原版容器
	#   `YiZhiContainer` **按数据动态排两行**（LENGTH=10，`y=(i/10)·(62+20)`）⇒ 第 11..20
	#   件落第二排 y=153。服务端 `SPIRIT_PANEL_LIMIT = 20`（`fake_flash_server.py:11166`）
	#   ⇒ 两行就是全部容量；旧场景只烘一排，面板 ≥11 件时多出的件**无处显示**。
	"意志格10": [15, 153, 62, 62], "意志格11": [87, 153, 62, 62], "意志格12": [159, 153, 62, 62],
	"意志格13": [231, 153, 62, 62], "意志格14": [303, 153, 62, 62], "意志格15": [375, 153, 62, 62],
	"意志格16": [447, 153, 62, 62], "意志格17": [519, 153, 62, 62], "意志格18": [591, 153, 62, 62],
	"意志格19": [663, 153, 62, 62],
	"格0底": [15, 71, 62, 62],					# YiZhiStudyCell:66-68 UISwf_yizhi_cellBg 原生 62×62 @(0,0)
	"格0图标": [18, 74, 56, 56],					# :70-75 RotateComponent x=3 y=3（图标本体尺寸随道具，格内 56 为可视上限·未证）
	"格0名称": [15, 95, 62, 19],					# :76-82 width=62 adjustContent=false align=center y=24
	"格0卖出": [17, 109, 58, 19],				# :83-87 y=height−24=38 x=2 width=58（UI_YELLOW）
	"格0拾取": [20, 109, 24, 19],				# :92-96 仅非灰色意志有；y=卖出.y x=5，**width 原版不设**
												#   （MLabel adjustContent 按墨迹自适应）⇒ 24 = 2×12px。
												#   曾登记 52（未证）⇒ 矩形盖住「卖出」右对齐文字区，
												#   点「卖出」会命中上层的「拾取」（2026-10-20 实测复现并修复）。
	"导师面板": [41, 425, 688, 87],				# :102-104 x=31 y=背景.height−100=414 ⇒ 窗 (41,454)
	"导师条底": [41, 425, 688, 87],				# TeacherPanel:142-146 UISwf_yizhi_npcBg 原生 688×87 @(0,0)
	"导师容器": [55, 441, 360, 57],				# :101-103 x=14 y=16；5 枚 ×76 步距 ⇒ 4·76+56
	"导师0": [55, 441, 56, 57],					# createTeachers:163-166 x=0,76,152,228,304
	"导师1": [131, 441, 56, 57], "导师2": [207, 441, 56, 57],
	"导师3": [283, 441, 56, 57], "导师4": [359, 441, 56, 57],
	"导师0头像": [55, 441, 56, 57],				# TeacherCell:46 UISwf_yizhi_npc(k+1) 原生 56×57 @(0,0)
	"导师0悬停框": [55, 441, 57, 57],			# :50-52 YellowBorder 拉到 57×57，**visible=false**
	"导师0气泡": [89, 419, 46, 48],				# :67-69 x=width−22=34 y=−22（29 帧动画，本轮烘首帧）
	"导师1气泡": [165, 419, 46, 48],				# 同上，导师_1 位（x=131+34）⇒ **只当前位显**，这位该隐
	"导师0召唤": [64.5, 487, 37, 22],			# TeacherCell:57-64 `isScale9Grid=false`、width=btn_width_two=37
												# x=(56−37)/2=9.5、y=57−22/2=46 ⇒ **骑在头像下沿**（46..68）
	"召唤文字": [64.5, 487, 37, 22],				# MButton3 的 tf 居中在钮矩形里，色 #fcf49c
	"今日次数": [423, 425, 218, 19],				# :106-109 setPosition(382,0) width=218 adjustContent=false
	"说明文字": [423, 443, 226, 70],				# :110-114 x=382 y=0+18 setSize(226,70) paddingH=paddingV=0 hasGlow
	"一键学习": [313, 390, 98, 33],				# :91-92 x=pickAll.x−w−10=272 y=−35；UISwf_Text_YiJianXueXi 98×33
	"全部拾取": [421, 395, 96, 28],				# :87-88 x=sellAll.x−w−10=380 y=−30；PickUpButtonSKin 96×28
	"全部卖出": [527, 395, 94, 28],				# :83-84 x=backBtn.x−w−10=486 y=−30；SellUpSkin 94×28
	"返回": [631, 392, 88, 33],					# :79-80 x=width−98=590 y=−33；BackUpSkin 88×33
	"打开背包": [657, 441, 57, 61],				# :121-126 x=688−57−15=616 y=导师容器.y=16；openPackUpSkin 57×61
}


func 页名() -> String:
	return "意志学习"


func 根节点名() -> String:
	return "原版意志学习内容"


func 页签数() -> int:
	return 1


## 原版这一页**没有页签条**（`YiZhiStudyWindow` 里没有任何 MTabButton，
## 导师是 5 枚头像、不是页签）⇒ 关掉基类的切页/页签量宽通道。
func 有页签() -> bool:
	return false


func 期望() -> Dictionary:
	return 件期望


func 路径() -> Dictionary:
	return 件路径


func 页面件表() -> Dictionary:
	var 全: Array[String] = ["外框黄底", "主背景", "小标题条", "元宝图标", "元宝数值", "阅历图标", "阅历数值",
		"意志容器", "导师面板", "导师条底", "导师容器", "今日次数", "说明文字",
		"一键学习", "全部拾取", "全部卖出", "返回", "打开背包"]
	# ⚠️ 20 格 = 两行 × 10（`YiZhiContainer:64-69` 动态排 + 服务端 `SPIRIT_PANEL_LIMIT = 20`）。
	#    只列一排 ⇒ 面板 ≥11 件时第二层根本不在场景里（§3.185 用户实机报）。
	for k in 20:
		全.append("意志格%d" % k)
	for k in 5:
		全.append("导师%d" % k)
	全 += ["格0底", "格0图标", "格0名称", "格0卖出", "格0拾取",
		"导师0头像", "导师0悬停框", "导师0气泡", "导师0召唤", "导师1气泡", "召唤文字"]
	return {0: 全}


func 页面文案表() -> Dictionary:
	return {}


func 公共件() -> Array[String]:
	return ["外框黄底", "主背景", "导师条底"]


const 钮文案 := {
	"一键学习": ["YIJIANXUEXI_SKIN 图 + 无字", ""],
	"今日次数": ["YIZHI_TODAY_STUDY_DESC", "今日还可免费学习意志0次"],
}
## 说明正文**不抄第二份**：与生成器共读 `数据/界面/意志_说明原文.txt`
## （该文件由 `开发工具/出意志原文数据.py` 从 AS3 语言表 `YIZHI_LEAVE_DESC` 一次解出）。
func 说明原文() -> String:
	var 文 := FileAccess.get_file_as_string("res://数据/界面/意志_说明原文.txt")
	assert(文.contains("font color") and 文.contains("离开教室"), "意志_说明原文.txt 内容不对")
	return 文


## 抓图前把气泡动图**冻住**，并把冻住时那一帧的序号写进 `气泡帧.txt`。
## 不冻就没法判：气泡压在 导师_0 头像右上角 22×26 那块，每 0.375s 换一张图，
## 像素对证拿哪帧当参照都是随机红/绿（动图本身会不会动，另由 `验意志导师交互.gd` 连拍证明）。
func _步抓图(页号: int) -> void:
	var 页 := 页根()
	if 页 != null:
		var 泡 := 页.get_node_or_null(取路径("导师0气泡")) as TextureRect
		if 泡 != null and 泡.texture is AnimatedTexture:
			var 动 := 泡.texture as AnimatedTexture
			动.speed_scale = 0.0
			var f := FileAccess.open(出目录 + "/气泡帧.txt", FileAccess.WRITE)
			if f != null:
				f.store_line("%d" % 动.current_frame)
				f.close()
			_行("  气泡冻在第 %d 帧（对证按这一帧比，动图会动另由 验意志导师交互.gd 连拍判）"
					% 动.current_frame)
	super(页号)


func 额外校验(页: Control, _页号: int) -> void:
	# 一、五枚原版钮的皮**必须是各自的原件**、互不共用（原版每张不同尺寸、各是独立符号）：
	#     四枚大钮 = `UISwf_Text.swf`（前缀规则 `BaseUtil.getLocalPath:74-77`），
	#     打开背包 = `UISwf_yizhi_openPackUpSkin`。都是 `ProgramButton extends MButton3`
	#     ⇒ 一张皮 + 运行时加性滤镜 ⇒ 场景里就该是 TextureButton 直接贴皮（文字画在皮里）。
	var 皮表 := {"一键学习": 98, "全部拾取": 96, "全部卖出": 94, "返回": 88, "打开背包": 57}
	var  seen := {}
	for 名 in 皮表:
		var 钮 := 页.get_node_or_null(件路径[名]) as TextureButton
		var 皮: Texture2D = 钮.texture_normal if 钮 != null else null
		var 对: bool = 皮 != null and int(皮.get_size().x) == 皮表[名]
		有错 = 有错 or not 对
		_行("  %-12s 钮皮宽=%s（原件原生 %d）%s" % [名,
			皮.get_size().x if 皮 != null else "<无皮>", 皮表[名], "√" if 对 else "!! 错"])
		if 皮 != null:
			if seen.has(皮.resource_path):
				_错("%s 与 %s 用了同一张皮（原版是各自独立的符号）" % [名, seen[皮.resource_path]])
			seen[皮.resource_path] = 名
	# 二、原版初值不可见的件：`TeacherCell` 的悬停框/召唤钮造出来就是 false；
	#     `YiZhiCell` 更狠 —— 图标/名称/卖出/拾取**只在 setData 有数据时才 addChild**
	#     （`YiZhiContainer.setData`），所以空态整排只剩格底。
	#     意志格更彻底：**空态连格底都没有**（`YiZhiContainer.setData:78-93` 按数据条数造格），
	#     隐的是"格位"本身，见下面 3.5；格内子件自己都是 visible=true。
	for 名 in ["导师0悬停框", "导师0召唤", "导师1气泡"]:
		var 件: CanvasItem = 页.get_node_or_null(件路径[名])
		var 对2: bool = 件 != null and not 件.visible
		有错 = 有错 or not 对2
		_行("  %-12s visible=%s（原版初值 false）%s" % [名, 件.visible if 件 else "<无>", "√" if 对2 else "!! 错"])
	# 3.5、空态：10 个格位**全部隐藏**（用户拿原版截图指出"这一页没有格子"）
	var 露: Array = []
	for k in 10:
		var 槽 := 页.get_node_or_null("意志容器/意志格_%d" % k) as CanvasItem
		if 槽 != null and 槽.visible:
			露.append(k)
	有错 = 有错 or not 露.is_empty()
	_行("  %-12s 空态可见格=%s（原版无数据时 0 格）%s" % ["意志格空态",
		str(露) if not 露.is_empty() else "无", "√" if 露.is_empty() else "!! 错"])
	# 三、格位/导师位数量与步距
	var 容器 := 页.get_node_or_null("意志容器") as Control
	var n1 := 容器.get_child_count() if 容器 != null else 0
	有错 = 有错 or n1 != 10
	_行("  %-12s 子节点=%d（原版 LENGTH=10 格）%s" % ["意志容器", n1, "√" if n1 == 10 else "!! 错"])
	var 导容 := 页.get_node_or_null("导师面板/导师容器") as Control
	var n2 := 导容.get_child_count() if 导容 != null else 0
	有错 = 有错 or n2 != 5
	_行("  %-12s 子节点=%d（原版 NPC0..4 共 5 位）%s" % ["导师容器", n2, "√" if n2 == 5 else "!! 错"])
	# 四、说明文字 = 语言表原文（BBCode 化后逐字比）
	var 说 := 页.get_node_or_null("导师面板/说明文字") as RichTextLabel
	# 数据文件里换行是**两字符转义** `\n`，而 .tscn 的 text 被 Godot 解成**真换行**；
	# 两边都折成转义再比，避免 114 vs 115 这种假不一致。
	var 想文 := 译文为BBCode(说明原文()).replace("\n", "\\n")
	var 实 := (说.text if 说 != null else "").replace("\n", "\\n")
	var 说对: bool = 说 != null and 实 == 想文 and not 说.scroll_active
	有错 = 有错 or not 说对
	if not 说对 and 说 != null:
		var k := 0
		while k < mini(实.length(), 想文.length()) and 实[k] == 想文[k]:
			k += 1
		_行("      长度 实=%d 期=%d；第%d字 实码位=%d 期码位=%d" % [实.length(), 想文.length(), k,
			实.unicode_at(k), 想文.unicode_at(k)])
	_行("  %-12s %s（YIZHI_LEAVE_DESC）%s" % ["说明文字", "与语言表逐字一致" if 说对 else "!! 不一致",
		"scroll_active=false" if 说 != null and not 说.scroll_active else "!! 还在滚"])
	_验召唤态(页)
	_验气泡图层(页)


## 六、导师格气泡的**图层**：气泡必须是每格的**末位子件**（= 画在头像前面）。
## 原版 `TeacherCell.as` 的 addChild 顺序：头像(:48) → 悬停框(:54) → 召唤钮(:63)
## → 气泡(:72)，气泡在**最后**。Godot 兄弟节点**后声明 = 绘制/命中都在上层**，
## 所以「气泡 idx > 头像 idx」就是"黄色在人物前面"的充要条件。
## ⚠️ 2026-10-21 用户实机报「图层这里黄色的应该在人物前面，第一个是对的，把所有的
##    核对一样，都要和第一个一样」——当时导师_1 的气泡节点排在头像**之前**（量具表
##    件路径登记「导师1气泡」被生成器提前发射），画在人物后面、还被 2/3/4 号头像盖住
##    一截。生成器已改 canonical 归位，本条钉死防回退。
func _验气泡图层(页: Control) -> void:
	for k in 5:
		var 格 := 页.get_node_or_null("导师面板/导师容器/导师_%d" % k) as Node
		var 像 := 格.get_node_or_null("头像") as CanvasItem if 格 != null else null
		var 泡 := 格.get_node_or_null("气泡") as CanvasItem if 格 != null else null
		var 层对: bool = 格 != null and 像 != null and 泡 != null \
			and 泡.get_index() == 格.get_child_count() - 1 and 像.get_index() < 泡.get_index()
		有错 = 有错 or not 层对
		_行("  %-12s 气泡 idx=%s/末位%s（头像 idx=%s；原版气泡 addChild 在最后）%s"
			% ["导师%d气泡层" % k, 泡.get_index() if 泡 != null else -1,
				(格.get_child_count() - 1) if 格 != null else -1,
				像.get_index() if 像 != null else -1, "√" if 层对 else "!! 错"])


## 喂一个**多位点亮**的导师状态，钉"任何时刻只有一个气泡"（显新隐旧）。
## 原版 `onSpirit_lightNpc`（`TeacherPanel:148-158`）先把上一个的气泡收掉再显新的；
## 我们曾经的实现在显隐循环里边走边判（吃**当时的**末亮）⇒ 状态 [1,1,0,0,0] 时
## 0/1 两格的气泡**同时亮着**（2026-10-21 用户截图照出：导师1 的气泡在人物前面、
## 导师2 的气泡同时也出现）。喂法与 `验意志一键钮.gd` 同一条路：写会话 +
## `spirit_state_changed` 让功能窗口重渲（在线回帧同路）。
func _队列尾() -> void:
	super._队列尾()		# 基类默认会挂 _步收尾校验
	队列.append(_步喂导师状态)
	队列.append(_步验单泡)


func _步喂导师状态() -> void:
	var 会 := root.get_node_or_null("GameSession")
	if 会 == null:
		_错("取不到 GameSession")
		return
	会.set("spirit_npc_status", ["1", "1", "0", "0", "0"])
	if 会.has_signal("spirit_state_changed"):
		会.emit_signal("spirit_state_changed")
	等待 = 4
	行.append("  喂导师状态     npc_status=[1,1,0,0,0] ⇒ 已触发重渲染")


func _步验单泡() -> void:
	var 页 := 页根()
	var 显: Array = []
	if 页 != null:
		for k in 5:
			var 泡 := 页.get_node_or_null("导师面板/导师容器/导师_%d/气泡" % k) as CanvasItem
			if 泡 != null and 泡.visible:
				显.append(k)
	# 末亮位 = 最后一个非 0 位 = 1；原版显新隐旧 ⇒ 只此一个
	if 显 != [1]:
		_错("状态 [1,1,0,0,0] 时可见气泡=%s，应只有 [1]（末亮位；原版 onSpirit_lightNpc 显新隐旧）"
			% str(显))
	行.append("  单泡          可见气泡=%s（末亮位 1）%s" % [str(显), "√" if 显 == [1] else "!! 错"])


func _行(文本: String) -> void:
	行.append(文本)
	print(文本)


## 五、召唤态：**期望值从 `数据/意志.json` 现算**，不写死下标。
## 原版 `TeacherPanel:68` 把召唤位写死成 `if(_loc6_ == 3)`；这里改成按数据判
## （`special.needYuanBao > 0` 的那一位），若两者不一致就报错 —— 这样数据一改就会暴露出来。
func _验召唤态(页: Control) -> void:
	var 常: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://数据/意志.json"))
	var 得: Dictionary = (常.get("common", {}) as Dictionary).get("gain", {})
	var 召唤位 := -1
	for k in 5:
		var 特: Dictionary = ((得.get("NPC%d" % k, {}) as Dictionary).get("special", {}) as Dictionary)
		if int(特.get("needYuanBao", 0)) > 0:
			召唤位 = k
	if 召唤位 != 3:
		_错("数据里 needYuanBao>0 的是 NPC%d，而原版 `TeacherPanel:68` 写死 3 ⇒ 二者不符，得回查" % 召唤位)
	for k in 5:
		var 召 := 页.get_node_or_null("导师面板/导师容器/导师_%d/召唤" % k) as CanvasItem
		var 像 := 页.get_node_or_null("导师面板/导师容器/导师_%d/头像" % k) as Control
		var 泡 := 页.get_node_or_null("导师面板/导师容器/导师_%d/气泡" % k) as CanvasItem
		var 该召: bool = k == 召唤位
		var 对: bool = 召 != null and 召.visible == 该召
		# `lightTeacher(:187-193)`：灰位只有召唤钮可见时才可点
		var 想滤 := Control.MOUSE_FILTER_STOP if 该召 else Control.MOUSE_FILTER_IGNORE
		对 = 对 and 像 != null and 像.mouse_filter == 想滤
		# 全 DARK（服务端没回）⇒ 五张头像都该套 getGrayFilter 材质
		对 = 对 and 像 != null and 像.material != null
		对 = 对 and 泡 != null and 泡.visible == (k == 0)	# 无亮位 ⇒ `onSpirit_lightNpc(0)`
		# 「召唤」的字是钮的**子 Label**：控制器只切父钮 ⇒ 子件自己必须 visible=true，
		# 靠父隐藏才不画。烘成 false 就"钮亮着但没字"（用户报过）。
		var 字 := 页.get_node_or_null("导师面板/导师容器/导师_%d/召唤/召唤文字" % k) as CanvasItem
		对 = 对 and 字 != null and 字.visible
		# 1..4 位的钮矩形必须由第 0 位 + 步距 76 推出来（上一轮只有第 0 位改了坐标，
		# 其余四位还吃生成器里的旧常量 ⇒ 用户报"按钮位置也不对"）
		var 想x := 64.5 + 76.0 * k
		对 = 对 and 召 is Control and abs((召 as Control).get_global_position().x - (想x + 页.get_global_position().x)) < 0.6
		有错 = 有错 or not 对
		_行("  %-12s 召唤=%s 头像mf=%d(想%d) 灰=%s 泡=%s 字=%s x=%.1f %s" % ["导师%d" % k,
			str(召.visible) if 召 else "<无>", 像.mouse_filter if 像 else -1, 想滤,
			str(像.material != null) if 像 else "<无>", str(泡.visible) if 泡 else "<无>",
			str(字.visible) if 字 else "<无>",
		(召 as Control).get_global_position().x - 页.get_global_position().x if 召 is Control else -1,
		"√" if 对 else "!! 错"])
