extends RefCounted
## 通灵驯养窗（原版 `PetStudyWindow.as`，410×408）—— 宠物主窗右侧的子窗。
##
## 原版从主窗点「品级 / 悟性 / 攻·防·灵·健 四潜力」打开（`PetWindow.onOpenStudyWindow`），
## 并**贴在主窗右缘**（`petTab.x = _width`，PetWindow.as:638）。四个页签：
## `通灵进阶(PetLayerTab) / 属性提升(PetStrongTab) / 宠物融魂(PetRongHunTab) / 通灵进化(隐藏)`。
##
## 三页的几何与文案全部按 `真值/窗口/宠物.md` §16（进阶）/ §17（提升）/ §18（融魂）搬：
##   * 页签原生 39×22、`isScale9Grid` ⇒ 量出来 **54 宽**，x = 11/65/119/173（窗局部）
##   * 第 4 枚页签 **默认隐藏**，只有当前宠是尾兽才显示；点了只提示、不切页
##   * 三个页根不是同一个原点：进阶 (12,60)=页容器原点、提升 (10,58) ⇒ 页内 (−2,−2)、
##     融魂 (8,53) ⇒ 页内 (−4,−7)
##   * 提升页**两态共用一张页**：type0（没选属性）与选了模式是两套下框；中框 type0 整块隐藏
##   * 融魂页**没有「尾兽预览」这颗钮**：那是一行盖在空模型框上的白字；点尾兽直接开预览窗
##
## 文案真值：原版这些串走的是语言表 `CN.*`，本工程的读法是把
## `2.2.3/map_extract/out/mainlib_as/scripts/en_US$message_properties.as` 里的**原句逐字搬进代码**
## （`<font>`/`<br>` → BBCode，`%1..%3` → `%s/%d`），每条都注了它在语言表里的行号 —— 别再写"暂拟"。

const 窗口场景 := preload("res://场景/界面/窗口/宠物/通灵驯养窗口.tscn")
const 进阶页场景 := preload("res://场景/界面/窗口/宠物/宠物进阶页.tscn")
const 融魂页场景 := preload("res://场景/界面/窗口/宠物/宠物融魂页.tscn")
const 提升页场景 := preload("res://场景/界面/窗口/宠物/宠物提升页.tscn")
## 进阶页那根祝福滑条的 0.5s 补间（与 `宠物窗口._设条` 同一个件、同一套口径）。
const 进度条补间 := preload("res://脚本/单例/进度条补间.gd")
const 预览窗场景 := preload("res://场景/界面/窗口/宠物/尾兽预览窗口.tscn")
## 下拉框六项（`PETSTRONGTAB_STRONG_NAMES_1..6`）——**顺序就是协议里的模式号**
const 提升模式名 := ["提升通灵兽品级", "提升通灵兽悟性", "提升通灵兽攻击潜力",
	"提升通灵兽防御潜力", "提升通灵兽灵巧潜力", "提升通灵兽健体潜力"]
## —— 提升页文案（语言表原句，行号 = `en_US$message_properties.as`）——
## `PETSTRONGTAB_STRONG_DESC_13`（:2848）type0 上框：六行说明
const 上框_未选 := ("[color=#f08900]通过属性提升操作可以使你的通灵兽变得更强[/color]\n" +
	"[color=#ffffff]提升通灵兽品级：有几率让你的通灵兽变为稀有品级\n提升通灵兽悟性：有几率让你的通灵兽领悟更多技能\n" +
	"提升通灵兽攻击潜力：通灵兽将为你提升更多的攻击属性\n提升通灵兽强身潜力：通灵兽将为你提升更多的防御属性\n" +
	"提升通灵兽灵巧潜力：通灵兽将为你提升更多的暴击和闪避\n提升通灵兽健体潜力：通灵兽将为你提升更多的生命值和查克拉[/color]")
## `STRONG_DESC_8`（:207）品级上框，两个占位 = 当前资质名 / 下一级资质名（`getStrongApt:689-692`）
const 上框_品级 := "[color=#f08900]提升通灵兽品级[/color]\n[color=#ffffff]当前通灵兽品级为 ：%s\n可以选择提升到 ：%s\n品级提升后,将大幅提高通灵兽为你带来的属性加成[/color]"
## `STRONG_DESC_7`（:209）悟性上框；中间那串**全角空格**是原句里的对齐用法，照抄
const 上框_悟性 := "[color=#f08900]提升通灵兽悟性[/color]\n[color=#ffffff]当前通灵兽悟性为 ：%d　　　　　　　最大可以提升到 ：100\n悟性提升后,你的通灵兽将可以领悟更多的技能[/color]"
## `STRONG_DESC_6`（:211）+ 各模式尾句 `DESC_12/11/9/10`（:2849/:2851/:203/:2853）潜力上框。
## ⚠ 第三占位是 **`potentialTotalApX`（总潜力）**，不是模板 `values.max`（`getStrongApa:520-523`）
const 上框_潜力 := "[color=#f08900]提升通灵兽%s[/color]\n[color=#ffffff]当前%s为 ：%d\n最大可以提升到 ：%d\n%s[/color]"
const 潜力尾句 := ["攻击潜力提升后,你的通灵兽可为你加成更多攻击力", "防御潜力提升后,你的通灵兽可为你加成更多防御力",
	"灵巧潜力提升后,你的通灵兽可为你加成更多闪避", "健体潜力提升后,你的通灵兽可为你加成更多生命值和查克拉"]
## `TI_SHENG_XIAO_GUO`（:2017）潜力态中框标题；`CURRENT_PET_QIANLI`（:3193）品级态标题
const 中框标题_预览 := "提升效果预览"
const 中框标题_品级 := "当前通灵兽潜力值\t\t提升成功后通灵兽潜力区间"
## 潜力态中框两行：`DESC_5`+`DESC_2`（:212/:219）、`DESC_4`+`DESC_2`（:214/:219）、
## `DESC_1`+`DESC_2`（:220/:219）—— 数值 = 实值潜力 / **总潜力**（`getStrongApaPrm:395` 等）
const 中框_攻防 := ["[color=#ffffff]当前为你加成攻击力 ：%d\n提升到最大后将加成 ：%d[/color]",
	"[color=#ffffff]当前为你加成防御力 ：%d\n提升到最大后将加成 ：%d[/color]",
	"[color=#ffffff]当前为你加成闪避率 ：%d\n提升到最大后将加成 ：%d[/color]"]
## `STRONG_DESC_3`（:216）健体态中框：两列四行（生命/查克拉 的实值与满值），表头橙色
const 中框_健体 := ("[color=#ff9100]当前为你增加                         提升至最大后将获得[/color]\n" +
	"[color=#ffffff]生命值 ：%d\t\t                     生命值 ：%d\n查克拉 ：%d\t                         查克拉 ：%d[/color]")
## `STRONG_PRPMPT_4`（:1358）type0 下框那段提示
const 提升提示语 := "强化通灵兽需要资质符和金币，当背包内准备好后可以点击右上方按钮进行选择"
## `STRONG_PRPMPT_1/2`（:1364/:1361）品级态两道闸的提示（`setType:440-470`：**只提示、不切页**）
const 品级未开放提示 := "很抱歉，你的通灵兽小于4阶，不能够提高品级！"
const 品级已满提示 := "你的通灵兽已经是最高品级！"
## `PetManager.as:11-12` 的原表：按钮下标 → 尾兽模板 id / 天赋技能 id。
## **下标就是发给服务端的 selection**（2=三尾 3=四尾 7=八尾 8=九尾），
## 与 `PetSoulFusionSelection` 的枚举值相等 —— 这条对上了，在线用例才转绿。
const 尾兽id := [0, 0, 401, 402, 0, 0, 0, 403, 404]
const 尾兽技能 := [0, 0, 125, 124, 0, 0, 0, 123, 126]
## `PET_RONGHUN_REAL_NAME`（`#` 分隔）逐项抄下，索引与上面两张表对齐
const 尾兽全名 := ["一尾(守鹤)", "二尾(又旅)", "三尾(矶怃)", "四尾(孙悟空)", "五尾(穆王)",
	"六尾(犀犬)", "七尾(重明)", "八尾(牛鬼)", "九尾(九喇嘛)"]
## `PetRongHunTab.TOPQIANLI`：预览里尾兽潜力是**常数**（不是当前宠的）
const 尾兽潜力 := 6198
const 数据 := preload("res://脚本/单例/游戏数据.gd")
const 装备打造表 := preload("res://脚本/界面/装备打造表.gd")
## 每颗幸运符加的成功率百分点。原版是**一个全局常量**：`UIConfig.xingYunJingRatio = 3`
## （`UIConfig.as:976`），宠物（`PetStrongTab.as:709`）与装备洗点/强化（`EquipPropResetPanel.as:421`、
## `EquipUpgradeWindow.as:337`）用的是同一颗数 ⇒ 这里引用工程里那份，不重抄一遍。
const 幸运符每张加成 := 装备打造表.幸运符加成
const 内容面板 := "res://素材/界面/原版窗口/通用控件/内容面板.png"
## 技能格/空格的底 —— 与宠物主窗「技能栏」用同一张 `物品格.png`（`MGrid_background` 的对应物）
const 格底图 := preload("res://素材/界面/原版窗口/通用控件/物品格.png")
## 页签名（`CN.PETSTUDYWINDOW_JIN_JIE_TAB / _STRONG_TAB / PET_TAB_RONGHUN`）
const 页签表 := ["通灵进阶", "属性提升", "宠物融魂"]
const 进化页签名 := "通灵进化"
## `PetLayerTab.as:177-183` 的两段说明文案（原文含 <br>/<font>，这里保留可解析的 BBCode）
const 流程文案 := "[color=#f08900]　　　　进阶流程[/color]\n[color=#ffffff]1.背包内有进阶道具进阶符\n2.背包内有足够数量的金币\n3.点击按钮【开始提升】[/color]"
## `PET_RONGHUN_DESC_TXT`（融合说明，四行）
const 融合说明 := "[color=#fcc399]　　　　　融合说明：[/color]
1.总梦幻度达到70且未经融魂的稀有品质宠物才可以融魂
2.融魂需消耗背包内相应的尾兽残魂（“挑战第七班”副本可获得）
3.融魂需要花费一定数量的金币
4.每个尾兽都拥有不同的天赋技能"
const 记忆符说明 := "在进行通灵兽进阶操作时，若使用“记忆符”作为辅助道具则可确保通灵兽在进行进阶操作时其品级、悟性和技能保持不变"
## 祝福条（`MBarExpF` tag167）的轨道宽 —— 真值 §10：`set width` 到 168
const 祝福条宽 := 168.0
## 材料格格名（`ItemCaiLiaoBox.label`）：原版是 `MGlowLabel`、`bold = true`、12px、`UI_ORANGE`。
## simsun 没有独立粗体字面 ⇒ 对等实现 = `FontVariation` + `variation_embolden`
## （同 `技能面板.取标号字体`；⚠ `base_font` 必须写，不写 FontVariation 什么都不渲染）。
const 格名字体路径 := "res://素材/界面/simsun_原版.ttf"
const 格名粗体量 := 0.8
static var _格名字体: FontVariation = null


static func 取格名字体() -> FontVariation:
	if _格名字体 != null:
		return _格名字体
	var 底 := load(格名字体路径) as FontFile
	if 底 == null:
		push_error("材料格名字体查无：%s" % 格名字体路径)
		return null
	var 粗 := FontVariation.new()
	粗.base_font = 底
	粗.variation_embolden = 格名粗体量
	_格名字体 = 粗
	return 粗


static func 渲染(窗口) -> void:
	var 会话 = 窗口._session
	var 页面 := 窗口场景.instantiate() as Control
	窗口._apply_common_control_skins(页面)
	窗口._content.add_child(页面)
	# 材料格/残魂格都是原版 `ItemCaiLiaoBox`（内含 `SimpleItemCell`）⇒ 每枚都带悬停详情
	# （`ItemCaiLiaoBox.as:128` 建 itemCell、`SimpleItemCell.as:220` 一有 itemData 就挂 MToolTipItem；
	# itemData 由 `PetLayerTab.as:122-125` / `PetRongHunTab.as:123` 填上）。场景是烘出来的，
	# 提示框运行期挂（同 `勾玉炼制窗.建提示框` / 宝石镶嵌那页）。
	窗口._给页挂提示框(页面)
	(页面.get_node("内容底") as Panel).add_theme_stylebox_override("panel", 窗口._texture_style(内容面板))
	# 宠物要先取出来：第 4 枚页签的可见性由"是不是尾兽"决定（真值 §16）
	var 宠物: Dictionary = 窗口._驯养宠物()
	var 尾兽宠 := not 宠物.is_empty() and 宠物数值.是尾兽(int(宠物.get("item_id", 0)))
	for 号 in 3:
		var 签 := 页面.get_node("页签_%d" % 号) as Button
		窗口._apply_tab_skin(签)
		签.text = 页签表[号]
		# 原版 `enabled = false` 表示"当前页"（MTabButton 的禁用态就是选中态）
		签.disabled = 号 == 窗口._驯养页签
		签.pressed.connect(func() -> void: 窗口._切驯养页签(号))
	# 第 4 枚（通灵进化）：原版 `_btnJinHun.visible = false` 默认隐藏、仅尾兽显示；
	# **点了只 notice、不切页**（`PetStudyWindow.as:80-83`）。
	var 进化签 := 页面.get_node("页签_3") as Button
	窗口._apply_tab_skin(进化签)
	进化签.text = 进化页签名
	进化签.visible = 尾兽宠
	进化签.disabled = false
	进化签.pressed.connect(func() -> void:
		会话.notification_requested.emit("功能尚未开启，敬请期待！"))
	var 容器 := 页面.get_node("页容器") as Control
	for 旧 in 容器.get_children():
		容器.remove_child(旧)
		旧.queue_free()
	if 宠物.is_empty():
		窗口._通知("请先在通灵兽列表里选一只通灵兽")
		return
	match 窗口._驯养页签:
		0:
			_填进阶页(窗口, 容器, 宠物)
		1:
			_填提升页(窗口, 容器, 宠物)
		2:
			_填融魂页(窗口, 容器, 宠物)
			_自动预览三尾(窗口)
		_:
			窗口._通知("「%s」尚未移植，敬请期待！" % 页签表[窗口._驯养页签])


## 通灵进阶页（`PetLayerTab`）。几何全在 .tscn 里，这里只填数据与接线。
static func _填进阶页(窗口, 容器: Control, 宠物: Dictionary) -> void:
	var 会话 = 窗口._session
	var 页面 := 容器.get_parent() as Control		# 提示框挂在外面那层页上（见 `渲染`）
	var 页 := 进阶页场景.instantiate() as Control
	容器.add_child(页)
	var 行 := 数据.pet_template(int(宠物.get("item_id", 0)))
	var 信息: Dictionary = 行.get("info", {}) as Dictionary
	var 进化: Dictionary = 信息.get("evolution", {})
	var 阶 := int(信息.get("jie", 0))
	# —— 标题：`getNext()`（PetLayerTab.as:339-353）
	var 名称 := 宠物数值.显示名(宠物)
	var 下一 := int(进化.get("nextPetId", 0))
	var 下一名 := String(数据.pet_template(下一).get("info", {}).get("name", "")) if 下一 > 0 else ""
	if 下一名.is_empty():
		(页.get_node("标题") as Label).text = "你当前通灵兽 ：%s，已达到最高阶，不需要进阶" % 名称
	else:
		(页.get_node("标题") as Label).text = "你当前通灵兽 ：%s，可以进阶为 ：%s(%s)" % [
			名称, 下一名, 宠物数值.品质名_of(int(宠物.get("aptitude", 1)))]
	(页.get_node("流程") as RichTextLabel).text = 流程文案
	(页.get_node("说明") as Label).text = 记忆符说明
	# —— 祝福值条（`_barAdd.setData(petData.zhufu, totalZhuFu)`，totalZhuFu = 模板 info.maxZhuFu）
	var 祝福 := int(宠物.get("blessing", 0))
	var 祝福上限 := int(信息.get("maxZhuFu", 1000))
	_设条(页.get_node("祝福条") as Control, 祝福, 祝福上限)
	(页.get_node("祝福标签") as Label).text = "进阶成功几率祝福值："
	# 阶数 > 4：原版换成"失败增加 1-3 点祝福值…达到 N 必成 ！"，
	# 且**"达到%3必成 ！"那一截是红的**（FAIL_PROMPT_1，PetLayerTab.as:272-283）
	var 祝福说明 := 页.get_node("祝福说明") as RichTextLabel
	if 阶 > 4:
		var 祝: Dictionary = 进化.get("zhufu", {}) if 进化.get("zhufu") is Dictionary else {}
		var 低 := int(祝.get("reqZhuFu1", 0))
		var 高 := int(祝.get("reqZhuFu2", 0))
		祝福说明.text = "失败增加1-3点祝福值，本次升阶成功祝福值为%d-%d，[color=#ff0000]达到%d必成 ！[/color]" % [低, 高, 高]
	else:
		祝福说明.text = "每次进阶失败增加祝福值,值越高则下次进阶成功率越高"		# FAIL_PROMPT_2：整句白
	# —— 材料格（进阶符 = needItemId × needItemCnt；记忆符 = helpItemId × 1）
	# 格上那行字是**固定语言**（UI_44 进阶符 / UI_43 记忆符），不是道具名（真值 §16）
	var 进阶符 := int(进化.get("needItemId", 0))
	var 需要 := int(进化.get("needItemCnt", 0))
	var 记忆符 := int(进化.get("helpItemId", 0))
	_填材料格(窗口, 页面, 页.get_node("进阶符格") as Control, 进阶符, 需要, "进阶符")
	_填材料格(窗口, 页面, 页.get_node("记忆符格") as Control, 记忆符, 1, "记忆符")
	# —— 消耗与成功率（`getMoney()` / `getRadom()`：钱不够**只把数字包红**）
	var 金币: int = 窗口._金币()
	var 需钱 := int(进化.get("needMoney", 0))
	(页.get_node("消耗") as RichTextLabel).text = "本次操作消耗金币 ：" + _钱串(需钱, 金币 >= 需钱)
	# `jie > 4` 时几率那行置空（`_textOpRadom.text = " "`，PetLayerTab.as:275）
	var 几率行 := 页.get_node("成功率") as RichTextLabel
	几率行.text = " " if 阶 > 4 else "本次操作成功几率 ：%d%%" % int(进化.get("probability", 0))
	# —— 两个复选框（`MCheckBoxF`：本次操作使用记忆符 / 失败后自动继续）
	var 用记忆符 := 页.get_node("用记忆符") as Button
	窗口._配置复选项(用记忆符, 窗口._驯养用记忆符)
	用记忆符.pressed.connect(func() -> void:
		窗口._驯养用记忆符 = not 窗口._驯养用记忆符
		窗口._配置复选项(用记忆符, 窗口._驯养用记忆符))
	# `jie > 4` 时这枚复选框上移到 y=265（PetLayerTab.as:282）
	var 记忆符顶 := 265.0 if 阶 > 4 else 285.0
	用记忆符.offset_top = 记忆符顶
	用记忆符.offset_bottom = 记忆符顶 + 20.0
	var 失败继续 := 页.get_node("失败后继续") as Button
	窗口._配置复选项(失败继续, 窗口._驯养失败继续)
	失败继续.pressed.connect(func() -> void:
		窗口._驯养失败继续 = not 窗口._驯养失败继续
		窗口._配置复选项(失败继续, 窗口._驯养失败继续))
	# —— 开始提升（原版 `onClickHand`：逐条先拦，最后 requestEvolutionUp(uid, 用记忆符?1:0)）
	var 开始 := 页.get_node("开始提升") as Button
	窗口._configure_standard_button(开始)
	开始.custom_minimum_size = Vector2(54.0, 22.0)		# `MButton3.measure`：4 全角字 + 6
	开始.pressed.connect(func() -> void:
		窗口._请求进阶(宠物, 进化, 进阶符, 需要, 记忆符, 需钱))
	var 提示 := 页.get_node("提示") as Button
	窗口._configure_standard_button(提示)
	提示.custom_minimum_size = Vector2(30.0, 22.0)		# 2 全角字 + 6
	提示.pressed.connect(func() -> void:
		窗口._通知("进阶失败不清零祝福值；祝福值越高，下次进阶成功率越高。"))
	# —— 模型预览：原版显示的是**下一阶**的样子（`_petMovie.skin = nextPetId`），尾兽缩 0.5
	var 模型位 := 页.get_node("模型位") as Control
	for 旧 in 模型位.get_children():
		模型位.remove_child(旧)
		旧.queue_free()
	var 预览号 := 下一 if 下一 > 0 else int(宠物.get("item_id", 0))
	var 精灵 := preload("res://脚本/角色/原始动画精灵.gd").new()
	if 精灵.configure("pet", str(预览号).pad_zeros(8), "stand"):
		模型位.add_child(精灵)
		if 宠物数值.是尾兽(预览号):
			精灵.scale = Vector2(0.5, 0.5)


## 材料格（原版 `ItemCaiLiaoBox`）：格名是**固定语言**、格内图标+数量一起灰、
## 数量恒白（不够是"变暗"不是"变红"）、「购买」宽 37。
static func _填材料格(窗口, 页面: Control, 格: Control, 物品号: int, 需要: int, 固定名: String) -> void:
	var 拥有: int = 窗口._背包数量(物品号)
	var 名 := 格.get_node("名") as Label
	名.text = 固定名
	# `ItemCaiLiaoBox.createChildren`：`label.color = UI_ORANGE(#ff9100)`、`label.bold = true`
	名.add_theme_color_override("font_color", Color("#ff9100"))
	var 粗 := 取格名字体()
	if 粗 != null:
		名.add_theme_font_override("font", 粗)
	var 图标 := 格.get_node("图标") as TextureRect
	图标.texture = 数据.item_icon(物品号)
	var 数量 := 格.get_node("数量") as Label
	数量.text = str(需要) if 需要 > 0 else ""
	var 灰 := Color(0.55, 0.55, 0.55, 1) if 拥有 < 需要 else Color(1, 1, 1, 1)
	# `applyGrayFilter` 只挂 `itemCell` 整格（`ItemCaiLiaoBox.as:41-43`）⇒ 40×40 底也一起灰，
	# 格名和「购买」不动（它们不在 itemCell 里）。
	var 底 := 格.get_node_or_null("底") as TextureRect
	if 底 != null:
		底.modulate = 灰
	图标.modulate = 灰
	数量.modulate = 灰
	# 悬停详情（见 `渲染` 的注释）：绑在 40×40 的图标上 = 原版 `itemCell` 的命中区；
	# 拥有数为 0 也照样弹（`itemCell.itemData` 一直挂着，展示的是物品本身）。
	窗口._接打造提示(页面, 图标, 物品号, 拥有)
	var 购买 := 格.get_node("购买") as Button
	窗口._configure_standard_button(购买)
	购买.custom_minimum_size = Vector2(37.0, 22.0)		# `UIConfig.btn_width_two`，x=(45−37)/2
	# 「购买」= 共用材料格 `ItemCaiLiaoBox.buyHandler:46-55`：dispatch `REQUEST_CASH_ITEM_INFO`
	# （原版 `buyHandler` 第一句是 `if(!itemCell.itemData) return;` ⇒ 没有物品号就不接线）
	if 物品号 > 0:
		购买.pressed.connect(func() -> void: 窗口.请求商城商品(str(物品号).pad_zeros(8)))


## 钱不够只把**数字**包红，其余保持白（真值 §16 「消耗」那行/tag `<font color='#ff0000'>`）
static func _钱串(钱: int, 够: bool) -> String:
	if 够:
		return "%d" % 钱
	return "[color=#ff0000]%d[/color]" % 钱


## 属性提升页「本次操作成功几率」那一行的数。原版 `PetStrongTab.getConfigureString:704-712`：
## `int(probability)`，**只有勾了幸运符**才 `+ (selectedIndex + 1) × xingYunJingRatio`。
## ⚠ 这一支**不夹 100**（装备那边 `装备打造表.实际成功率` 有 `mini(100,…)`，宠物原版没有 ⇒
##   基础 80% 勾 9 颗原版就写 107%）。别"顺手统一"成夹住的，那是改口径。
static func 提升几率(配置: Dictionary, 用符: bool, 颗数: int) -> int:
	var 率 := int(配置.get("probability", 0))
	return 率 + maxi(0, 颗数) * 幸运符每张加成 if 用符 else 率


## `MBarExpF`（tag167）按真值 §10 重建后的驱动：`底 / 裁剪 / 填充 / 值`。
## 进度**不是压扁**：整条往左滑、mask 不动 ⇒ `填充.position.x = −3 − int(W·(1−r))`，0.5s 补间。
static func _设条(条: Control, 数值: int, 最大值: int) -> void:
	var 填充 := 条.get_node("裁剪/填充") as TextureRect
	var 值 := 条.get_node("值") as Label
	# 同 `宠物窗口._设条`：比例/终位/补间走同一道口子（含同数据早退 + 换数据杀旧补间）。
	# `上限零当满 = false` 那处偏离的理由也见那边（原版会把 0/0 画满，本工程维持空条）。
	进度条补间.补间(填充, "position:x", 进度条补间.滑条终位(祝福条宽,
		进度条补间.比例(float(数值), float(最大值), false), -3.0), [数值, 最大值])
	值.text = "%d/%d" % [数值, 最大值]


## 宠物融魂页（`PetRongHunTab.as`）。
## 九只尾兽里**只有 三/四/八/九尾 可用**（`PetManager.petID` 非 0 的那四个，
## 与语言表 `PET_RONGHUN_NAME` 的可用位一致）；点一只 → 右侧显示那只尾兽的
## 形态/天赋/潜力预览 + 它要的残魂与金币；「开始融魂」发 `SOUL_FUSION(22)`。
## ⚠️ 真值 §18.1：这页**没有「尾兽预览」钮** —— `预览字` 是盖在空模型框上的一行白字；
##    点尾兽 = `setWeiShouInfo(i)` 里直接 `showYuLanWindow()`，没有第二下。
static func _填融魂页(窗口, 容器: Control, 宠物: Dictionary) -> void:
	var 页面 := 容器.get_parent() as Control		# 提示框挂在外面那层页上（见 `渲染`）
	var 页 := 融魂页场景.instantiate() as Control
	页.position = Vector2(-4.0, -7.0)		# 页根 = 窗口 (8,53)；页容器原点 = (12,60)
	容器.add_child(页)
	for 板名 in ["信息底", "下底", "说明底"]:
		(页.get_node(板名) as Panel).add_theme_stylebox_override("panel", 窗口._sub_panel_style())
	(页.get_node("说明") as RichTextLabel).text = 融合说明
	(页.get_node("宠物行") as Label).text = "宠物名称：%s" % 宠物数值.显示名(宠物)
	(页.get_node("等级行") as Label).text = "等级：%d" % int(宠物.get("level", 0))
	(页.get_node("残魂说明") as Label).text = "融魂需要："
	(页.get_node("红字") as Label).text = "当前只开放4个尾兽形态!"
	# 进页默认 = 三尾（`update():414-419` 写死 `_curIndex=-1` + `setWeiShouInfo(2)`）
	if 窗口._驯养融魂下标 < 0:
		窗口._驯养融魂下标 = 2
	var 预览字 := 页.get_node("预览字") as Label
	# —— 九个尾兽按钮（3 个一行，位置在 .tscn 里）
	for 号 in 9:
		var 钮 := 页.get_node("尾兽_%d" % 号) as Button
		窗口._configure_standard_button(钮)
		钮.custom_minimum_size = Vector2(49.0, 22.0)   # UIConfig.btn_width_three
		钮.text = 尾兽全名[号].split("(")[0]
		钮.disabled = 尾兽id[号] == 0
		if not 钮.disabled:
			钮.pressed.connect(func() -> void:
				窗口._驯养融魂下标 = 号
				窗口._开尾兽预览(尾兽id[号])		# 原版 setWeiShouInfo 里直接开预览
				窗口._render_page())
	# —— 融魂按钮（原版 `onRongHunHandler`：已融魂 → 提示1；资质 < 4 → 提示2；否则发协议）
	var 融魂 := 页.get_node("融魂按钮") as Button
	窗口._configure_standard_button(融魂)
	融魂.custom_minimum_size = Vector2(61.0, 22.0)		# `btn_width_four`
	融魂.pressed.connect(func() -> void: 窗口._请求融魂(宠物))
	if 窗口._驯养融魂下标 < 0:
		预览字.visible = true
		return
	预览字.visible = false			# `setWeiShouInfo:104` 第一句就 visible=false
	_填融魂详情(窗口, 页面, 页, 宠物, 窗口._驯养融魂下标)


## 进页自动预览三尾（`update()` → `setWeiShouInfo(2)` → `showYuLanWindow()`）。
## 只在"刚进页/刚换宠"那一次开，重渲染不重复弹（玩家自己关掉了就别硬顶回来）。
static func _自动预览三尾(窗口) -> void:
	if 窗口._驯养融魂下标 != 2 or 窗口._融魂预览已开:
		return
	窗口._融魂预览已开 = true
	窗口.call_deferred("_开尾兽预览", 尾兽id[2])


## 选中某只尾兽后的右侧详情（`setWeiShouInfo`）。
static func _填融魂详情(窗口, 页面: Control, 页: Control, 宠物: Dictionary, 下标: int) -> void:
	var 兽号: int = 尾兽id[下标]
	var 行 := 数据.pet_template(兽号)
	var 进化: Dictionary = (行.get("info", {}) as Dictionary).get("evolution", {})
	(页.get_node("宠物名") as Label).text = "名称：%s" % 尾兽全名[下标]
	# 天赋（技能）：`_skillCell` + 名称 + 描述
	var 技号: int = 尾兽技能[下标]
	var 技能行 := 数据.pet_skill(技号)
	(页.get_node("技能格/技能图标") as TextureRect).texture = _技能图标(技号)
	(页.get_node("技能名") as Label).text = "天赋名称：%s" % String(技能行.get("name", ""))
	(页.get_node("技能说明框/技能说明") as Label).text = "天赋描述：%s" % String(技能行.get("desc", ""))
	# 五条潜力是**常数**（`updateWeiShouView` 全用 TOPQIANLI=6198）
	(页.get_node("潜力_0") as Label).text = "最大潜力总值：%d" % (尾兽潜力 * 4)
	(页.get_node("潜力_1") as Label).text = "最大攻击潜力：%d" % 尾兽潜力
	(页.get_node("潜力_2") as Label).text = "最大灵巧潜力：%d" % 尾兽潜力
	(页.get_node("潜力_3") as Label).text = "最大防御潜力：%d" % 尾兽潜力
	(页.get_node("潜力_4") as Label).text = "最大健体潜力：%d" % 尾兽潜力
	# 残魂格（灰化条件照 `validateItem`：背包数量 < needItemCnt；格名是空串）
	_填残魂格(窗口, 页面, 页.get_node("残魂格") as Control, int(进化.get("needItemId", 0)), int(进化.get("needItemCnt", 0)))
	# `_rhMoney` 恒白（原版没有"不够就变红"这一档）
	var 需钱 := int(进化.get("needMoney", 0))
	(页.get_node("金币") as Label).text = "当前操作需要金币：%d" % 需钱
	# 预览：显示这只尾兽的形态（尾兽一律 0.5 倍）
	var 预览位 := 页.get_node("预览宠物") as Control
	for 旧 in 预览位.get_children():
		预览位.remove_child(旧)
		旧.queue_free()
	var 精灵 := preload("res://脚本/角色/原始动画精灵.gd").new()
	if 精灵.configure("pet", str(兽号).pad_zeros(8), "stand"):
		预览位.add_child(精灵)
		精灵.scale = Vector2(0.5, 0.5)


static func _填残魂格(窗口, 页面: Control, 格: Control, 物品号: int, 需要: int) -> void:
	var 拥有: int = 窗口._背包数量(物品号)
	var 名 := 格.get_node("名") as Label
	名.text = ""		# `ItemCaiLiaoBox.label.text = ""`（两处显式置空）
	# 文字空着也照样套原版样式（`label.color = UIConfig.UI_ORANGE`、`bold = true`、12px）。
	名.add_theme_color_override("font_color", Color("#ff9100"))
	var 粗 := 取格名字体()
	if 粗 != null:
		名.add_theme_font_override("font", 粗)
	var 图标 := 格.get_node("图标") as TextureRect
	图标.texture = 数据.item_icon(物品号)
	var 数量 := 格.get_node("数量") as Label
	数量.text = str(需要)
	var 灰 := Color(0.55, 0.55, 0.55, 1) if 拥有 < 需要 else Color(1, 1, 1, 1)
	var 底 := 格.get_node_or_null("底") as TextureRect
	if 底 != null:
		底.modulate = 灰
	图标.modulate = 灰
	数量.modulate = 灰
	# 悬停详情（同 `_填材料格`）：`PetRongHunTab.as:123` 也把 itemData 填成那颗残魂。
	窗口._接打造提示(页面, 图标, 物品号, 拥有)
	# `PetRongHunTab.as:239` 建的是 `ItemCaiLiaoBox(true)` ⇒ 这颗格**有「购买」**
	#（宽 50 的格：`buyBtn.x = (50−37)/2 = 6.5`，位置在 .tscn 里）。
	var 购买 := 格.get_node_or_null("购买") as Button
	if 购买 != null:
		窗口._configure_standard_button(购买)
		购买.custom_minimum_size = Vector2(37.0, 22.0)
		if 物品号 > 0:
			购买.pressed.connect(func() -> void: 窗口.请求商城商品(str(物品号).pad_zeros(8)))


static func _技能图标(技号: int) -> Texture2D:
	var 路径 := 数据.skill_icon_path({"icon_class": "Skill_PetSkill_%d_icon" % 技号})
	if 路径.is_empty() or not ResourceLoader.exists(路径):
		return null
	return load(路径) as Texture2D


## 中框那两列（原版 `PetStrongTab.getStrongAptPrm:678-687`）：
## **四行两列表** —— 左列是**当前潜力实值**、右列是该资质档的 **`min-max`**。
## ⚠️ 两条真值：① `if (pet.aptitude != PetAptitude.PREEMINENCE)` —— **资质 = 4（稀有）时原版返回空串**；
## ② 右侧的 min/max 取自 `info.potential.values["apt" + (资质 + 1)]`
##    （= **升到下一档后的**区间），这份数据 `数据/宠物.json` 里**已经导出**。
## 原版拼的是 HTML（`<font color='#ffffff'>…<br>…</font>`），这里直接写 BBCode ——
## 消费点是 `bbcode_enabled` 的 `RichTextLabel`，原标签会**整串显示给玩家**。
## 行名 = `PETWINDOW_GONGJI/FANGYU/LINGQIAO/JIANSHENQIANLI`（语言表 :2461/:2204/:1871/:3037），
## 两列间距 `\t\t` 也是原句里的。
static func 中框表(宠物: Dictionary, 信息: Dictionary, 资质: int) -> String:
	if 资质 == 4:							# `PetAptitude.PREEMINENCE`
		return ""
	var 值: Dictionary = (信息.get("potential", {}) as Dictionary).get("values", {}) as Dictionary
	var 档: Dictionary = 值.get("apt%d" % (资质 + 1), {}) as Dictionary
	if 档.is_empty():
		return ""
	var 行名 := ["攻击潜力", "防御潜力", "灵巧潜力", "健体潜力"]
	var 键名 := ["potential_real_atk", "potential_real_def", "potential_real_dex", "potential_real_str"]
	var 出 := "[color=#ffffff]"
	for i in 4:
		出 += "%s ：%d\t\t%s ：%d-%d\n" % [行名[i], int(宠物.get(键名[i], 0)),
				行名[i], int(档.get("min", 0)), int(档.get("max", 0))]
	return 出 + "[/color]"


## 品级态的两道闸（`setType:440-470`）：资质已满（`PetDataManage.MAX_PET_APPITUDE = 4`）
## ⇒ `STRONG_PRPMPT_2`；模板 `info.aptitude.enable != 1` ⇒ `STRONG_PRPMPT_1`。
## 命中时原版**既不切页也不重画**（`_typeStrong` 回滚）⇒ 这里只回提示串，空串 = 放行。
static func 品级闸(宠物: Dictionary) -> String:
	if clampi(int(宠物.get("aptitude", 1)), 1, 5) >= 4:
		return 品级已满提示
	var 信息: Dictionary = (数据.pet_template(int(宠物.get("item_id", 0))).get("info", {}) as Dictionary)
	if int((信息.get("aptitude", {}) as Dictionary).get("enable", 0)) != 1:
		return 品级未开放提示
	return ""


## 潜力态中框那两行（`getStrongApaPrm:395-398` / `getStrongApdPrm:694-697` /
## `getStrongApdexPrm:515-518` / `getStrongApstrPrm:699-702`）：
## 第一行 = 拿**实值潜力**算出的加成，第二行 = 拿**总潜力**算出的加成（`宠物数值.满值六项`）。
## 下标 0攻 1防 2灵 3健。⚠ 灵巧那一行原版写的是 **duck（闪避）**，不是暴击（`DESC_1`）。
static func _潜力中框(宠物: Dictionary, 下标: int) -> String:
	var 实: Array = (宠物数值.计算(宠物).get("属性行", []) as Array)
	var 满: Array = 宠物数值.满值六项(宠物)
	if 下标 >= 3:
		return 中框_健体 % [int((实[0] as Dictionary)["值"]), int(满[0]), int((实[1] as Dictionary)["值"]), int(满[1])]
	var 行号: int = [2, 3, 5][下标]
	return 中框_攻防[下标] % [int((实[行号] as Dictionary)["值"]), int(满[行号])]


## 悟性态中框（`strongSav:578-643`）：两行各 8 格。
## 格 x 用原版那条怪公式 `(42 + (i == 0 ? 0 : 7)) * i + 3` ⇒ 首格贴左、其后 49 间距。
## 第二行的候选 = 模板 `skills` 里**带 `skillid` 的项**减掉已学
## （`DataCenter.getPetCanStudySkills:2301-2329`；`default` 那个子对象没有 `skillid` ⇒ 天然被跳过）。
static func _填技能行(页: Control, 宠物: Dictionary) -> void:
	var 已学: Array = []
	var 当前: Array = []
	for 技 in (宠物.get("skills", []) as Array):
		var 技项 := 技 as Dictionary
		已学.append(int(技项.get("id", 0)))
		当前.append({"id": int(技项.get("id", 0)), "level": int(技项.get("level", 0))})
	var 可学: Array = []
	var 模板技: Dictionary = (数据.pet_template(int(宠物.get("item_id", 0))).get("skills", {}) as Dictionary)
	for 项 in 模板技.values():
		if not (项 is Dictionary) or not (项 as Dictionary).has("skillid"):
			continue
		var 技号 := int((项 as Dictionary)["skillid"])
		if not 已学.has(技号):
			可学.append({"id": 技号, "level": 0})
	_摆技能行(页.get_node("技能框/当前行") as Control, 当前)
	_摆技能行(页.get_node("技能框/未学行") as Control, 可学)


## 一行 8 格（`SkillCellF` / 空格 `MGrid_background`）：有技能就画图标 + 提示，没有就留空底。
## `setFloorTextVisible(false)` ⇒ **格子里不显示层数**，等级只进提示框（与主窗技能栏同一口径）。
static func _摆技能行(容器: Control, 列表: Array) -> void:
	for 旧 in 容器.get_children():
		容器.remove_child(旧)
		旧.queue_free()
	for 号 in 8:
		var 格 := Control.new()
		格.name = "格_%d" % 号
		格.position = Vector2(3.0 if 号 == 0 else 49.0 * 号 + 3.0, 0.0)
		# 真值 §17：`SkillCellF` 是 **40×40**（`MGrid_background` 原尺寸），图标 **34×34** 居中 (3,3)，
		# 格距 **49**。以前写成 42/36 —— 整排比原版宽一圈、图标也大了 2px。
		格.size = Vector2(40.0, 40.0)
		容器.add_child(格)
		var 底 := TextureRect.new()
		底.name = "底"
		底.texture = 格底图
		底.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		底.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		底.size = Vector2(40.0, 40.0)
		底.mouse_filter = Control.MOUSE_FILTER_IGNORE
		格.add_child(底)
		if 号 >= 列表.size():
			continue
		var 项 := 列表[号] as Dictionary
		var 技号 := int(项.get("id", 0))
		var 图标 := TextureRect.new()
		图标.name = "图标"
		图标.texture = _技能图标(技号)
		图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		图标.position = Vector2(3.0, 3.0)
		图标.size = Vector2(34.0, 34.0)
		图标.mouse_filter = Control.MOUSE_FILTER_IGNORE
		格.add_child(图标)
		var 记录 := 数据.pet_skill(技号)
		格.tooltip_text = "%s Lv.%d\n%s" % [String(记录.get("name", "宠物技能 %d" % 技号)),
			int(项.get("level", 0)), String(记录.get("desc", ""))]


## 属性提升页（`PetStrongTab.as`）。**六种模式共用一个下拉框**（不是六个子页签）：
##   0 品级重置 → `REWASH_APTITUDE(6)` / 1 悟性 → `CHANGE_SAVVY(7)` /
##   2..5 攻·防·灵·健四潜力 → `STRENGTH_POTENTIAL(18, potential_type=1..4)`。
##
## 真值 §17 的两态（`type0` = 没选属性）：
##   常驻 = 提示标签(8,0) / 下拉(153,0) / 顶分隔线 / 开始提升(320,318,type0 灰)
##   type0 下框 = 待提升(20,170) / 模型底(2,192) / 名称等级(212,194) / 中分隔线 / 提升提示 / 底分隔线 / 宠物形象
##   选了模式 = 上框(高随模式 134/80/60) / 中框(116,382×96) / 下框(220,382×91，含两格+消耗+幸运符)
static func _填提升页(窗口, 容器: Control, 宠物: Dictionary) -> void:
	var 页面 := 容器.get_parent() as Control		# 提示框挂在外面那层页上（见 `渲染`）
	var 页 := 提升页场景.instantiate() as Control
	页.position = Vector2(-2.0, -2.0)		# 页根 = 窗口 (10,58)；页容器原点 = (12,60)
	容器.add_child(页)
	for 板名 in ["上底", "中底", "下底"]:
		(页.get_node(板名) as Panel).add_theme_stylebox_override("panel", 窗口._sub_panel_style())
	# 真值 §17：常驻提示标签 = MGlowLabel、**align=right、宽 145、@(8,0)**，
	# 文字「请选择需要提升的属性」。`STRONG_TITLE`「点击右侧下拉按钮」是**下拉的占位语**。
	(页.get_node("待提升") as Label).text = "请选择需要提升的属性"
	var 模式: int = clampi(窗口._驯养提升模式, -1, 5)
	var 下拉 := 页.get_node("模式下拉") as OptionButton
	窗口._configure_option_button(下拉)
	下拉.clear()
	下拉.add_item("点击右侧下拉按钮", -2)		# 占位项（id=−2）；⚠ 别写 −1：`add_item` 里 −1 是
	# 「自动编号」的哨兵值，会被改成 0 ⇒ 与「提升通灵兽品级」撞 id，选占位项反而变成选品级。
	for 号 in 6:
		下拉.add_item(提升模式名[号], 号)
	下拉.selected = 模式 + 1 if 模式 >= 0 else 0
	下拉.item_selected.connect(func(项: int) -> void:
		var 号 := 下拉.get_item_id(项)
		if 号 < 0:
			# 选回占位项 = 原版 `selectedIndex = -1` ⇒ 回到 type0（中框/下框收起、开始提升变灰）
			窗口._驯养提升模式 = -1
			窗口._render_page()
			return
		# `setType:440-470`：品级态两道闸命中时**只发提示、不切页**（连视图都不重画）
		if 号 == 0:
			var 闸 := 品级闸(宠物)
			if 闸 != "":
				窗口._通知(闸)
				下拉.selected = 模式 + 1 if 模式 >= 0 else 0
				return
		窗口._驯养提升模式 = 号
		窗口._render_page())
	# —— 宠物形象（尾兽 0.5 倍）
	var 形象位 := 页.get_node("宠物形象") as Control
	for 旧 in 形象位.get_children():
		形象位.remove_child(旧)
		旧.queue_free()
	var 精灵 := preload("res://脚本/角色/原始动画精灵.gd").new()
	var 宠号 := int(宠物.get("item_id", 0))
	if 精灵.configure("pet", str(宠号).pad_zeros(8), "stand"):
		形象位.add_child(精灵)
		if 宠物数值.是尾兽(宠号):
			精灵.scale = Vector2(0.5, 0.5)
	# —— 按模式取模板里的消耗行（都在已导出的 数据/宠物.json 里）
	var 行 := 数据.pet_template(宠号)
	var 信息: Dictionary = 行.get("info", {}) as Dictionary
	var 资质: int = clampi(int(宠物.get("aptitude", 1)), 1, 5)
	var 档 := "apt%d" % 资质
	var 配置: Dictionary = {}
	var 说明 := ""
	var 中段 := ""
	var 中标题 := 中框标题_预览
	var 有尾注 := false
	var 有技能行 := false
	var 是潜力 := 模式 >= 2
	match 模式:
		-1:
			# type0：上框是最高的那一档（底 134 / 文 130）+ `STRONG_DESC_13` 六行说明
			#（`initType:732-734`）；中框整块隐藏（`:735`）⇒ 原来这里给的是**空串**，一块空板
			说明 = 上框_未选
		0:
			var 表: Dictionary = 信息.get("aptitude", {}) as Dictionary
			配置 = 表.get(档, {}) as Dictionary
			说明 = 上框_品级 % [宠物数值.品质名_of(资质), 宠物数值.品质名_of(mini(资质 + 1, 5))]
			# `strongApt:179-188`：品级态中框 = 「当前潜力值 ↔ 提升成功后区间」四行表，
			# **没有中尾注**（`STRONG_PRPMPT_3` 只在潜力态 `createStrongView:810-814` 出现）。
			# 原来这两态的内容**互相放反了**：品级放了一句说明、四行表被塞进潜力态。
			中标题 = 中框标题_品级
			中段 = 中框表(宠物, 信息, 资质)
		1:
			var 表: Dictionary = 信息.get("savvy", {}) as Dictionary
			配置 = 表.get(档, {}) as Dictionary
			说明 = 上框_悟性 % int(宠物.get("savvy", 0))
			# `strongSav:578-643`：悟性态把**中底连同标题/内容/尾注一起撤下**，换成两行技能格
			有技能行 = true
		_:
			var 潜力键: String = ["potential_real_atk", "potential_real_def", "potential_real_dex", "potential_real_str"][模式 - 2]
			var 总潜力键: String = ["potential_total_atk", "potential_total_def", "potential_total_dex", "potential_total_str"][模式 - 2]
			var 潜力名: String = ["攻击潜力", "防御潜力", "灵巧潜力", "健体潜力"][模式 - 2]
			var 表: Dictionary = 信息.get("potential", {}) as Dictionary
			配置 = 表.get(档, {}) as Dictionary
			# ⚠ 第三占位是**总潜力**（`getStrongApa:520-523` 传 `potentialTotalApX`），
			#    不是模板 `values[档].max` —— 原来用 max 会把「最大可以提升到」写成另一个数
			说明 = 上框_潜力 % [潜力名, 潜力名, int(宠物.get(潜力键, 0)), int(宠物.get(总潜力键, 0)), 潜力尾句[模式 - 2]]
			中段 = _潜力中框(宠物, 模式 - 2)
			有尾注 = true
	(页.get_node("上文字") as RichTextLabel).text = 说明
	(页.get_node("中效果标题") as Label).text = 中标题
	(页.get_node("中效果内容") as RichTextLabel).text = 中段
	# —— 上框高度随模式变（真值 §17：type0 134 / 品级 80 / 悟性 60 / 潜力 80）
	var 上底 := 页.get_node("上底") as Panel
	var 上文字 := 页.get_node("上文字") as RichTextLabel
	var 底高 := 80.0
	var 文高 := 78.0
	if 模式 < 0:
		底高 = 134.0
		文高 = 130.0
	elif 模式 == 1:
		底高 = 60.0
		文高 = 58.0
	上底.offset_bottom = 30.0 + 底高
	上文字.offset_bottom = 35.0 + 文高
	# —— 两态切换：中框/下框（选了模式）↔ 待提升/模型底/名称等级/提示（type0）
	var 有模式 := 模式 >= 0
	# 中框三件：悟性态整块撤下 —— `strongSav:576-580` 先把 `_midCon` 清空，
	# 而 `_midBg` 是 `_midCon` 的**子节点**（`:407-414`）⇒ 连底板一起没了。
	for 名 in ["中底", "中效果标题", "中效果内容"]:
		(页.get_node(名) as Control).visible = 有模式 and not 有技能行
	# 下框（资质符/金币/几率）**悟性态照留**：`strongSav:644-669` 里 `_downCon.visible = true`
	# 并重建资质符格 + 消耗，悟性提升同样要材料与金币。
	# 以前这三件跟着 `not 有技能行` 一起藏 ⇒ 悟性页下半整块空白。
	for 名 in ["下底", "资质符格", "消耗"]:
		(页.get_node(名) as Control).visible = 有模式
	# 中尾注只属于潜力态；技能框只属于悟性态（`strongSav:578-581` 先把中框清空）
	(页.get_node("中尾注") as Control).visible = 有尾注
	(页.get_node("技能框") as Control).visible = 有技能行
	if 有技能行:
		_填技能行(页, 宠物)
	for 名 in ["待提升2", "模型底", "名称等级", "中分隔线", "提升提示", "底分隔线", "宠物形象"]:
		(页.get_node(名) as Control).visible = not 有模式
	# —— 材料格落位随模式变：潜力态两格 ⇒ 资质符 (15,221)、消耗 (200,223)（`createStrongView:828/:861`）；
	#    品级·悟性只有一格 ⇒ 资质符挪到 (92,221)，消耗跟在它右边 (92+45+5, 221+15)（`strongApt:202-212`）
	var 只有一格 := 模式 == 0 or 模式 == 1
	(页.get_node("资质符格") as Control).position = Vector2(92.0, 221.0) if 只有一格 else Vector2(15.0, 221.0)
	(页.get_node("消耗") as Control).position = Vector2(142.0, 236.0) if 只有一格 else Vector2(200.0, 223.0)
	# —— type0 下框那三块文字
	(页.get_node("待提升2") as Label).text = "你将要提升的通灵兽是 :"
	## ⚠️ **必须写 BBCode，不能照抄 AS3 的尖括号**：`getName:280-287` 拼的是
	## `<font><b>名称 ： </b>名<br><b>等级： </b>级</font>`，而消费点 `名称等级` 是
	## `bbcode_enabled = true` 的 `RichTextLabel` —— 它只认方括号，尖括号**整串当正文画出来**
	## （实测 `测试/截图/驯养/驯养_提升未选.png`：`<b>名称 ： </b>小忍犬`）。
	## 同文件 `中框表:437-438` 早就写过这条规矩，这一行是漏网的一处。
	## 加粗本身：`原版皮肤表.全局粗体量` 已把 `default_font` 整体 embolden ⇒ `[b]` 在这里是个
	## 无害的空标记（原版只粗"名称 ："四个字、不粗宠名，这一档差异属全局加粗的既成偏离）。
	(页.get_node("名称等级") as RichTextLabel).text = "[b]名称 ： [/b]%s\n[b]等级： [/b]%d" % [
		宠物数值.显示名(宠物), int(宠物.get("level", 0))]
	# `STRONG_PRPMPT_4`（语言表 :1358）逐字
	(页.get_node("提升提示") as Label).text = 提升提示语
	# —— 材料格：资质符(needItemId×needItemCnt)；潜力模式多一个幸运符(helpItemId)
	var 幸运符 := int(配置.get("helpItemId", 0))
	_填材料格(窗口, 页面, 页.get_node("资质符格") as Control, int(配置.get("needItemId", 0)), int(配置.get("needItemCnt", 0)), "资质符")
	_填材料格(窗口, 页面, 页.get_node("幸运符格") as Control, 幸运符, 1, "幸运符")
	# —— 消耗（两行：金币 + 几率；钱不够只把数字包红）。
	#    几率这一行**必须跟着勾选与颗数走**：原版 `_checkBox` 点击（`PetStrongTab.as:714-719`）
	#    和下拉 CHANGE（`:854`）都汇进 `xinYunJingSelectedHandler`（`:352-356`）⇒ 整段
	#    `_configureDescField.htmlText` 重写。以前这里只在开页时画一次基础值，勾了符数字不动。
	var 需钱 := int(配置.get("needMoney", 0))
	var 画消耗 := func() -> void:
		var 金币: int = 窗口._金币()
		(页.get_node("消耗") as RichTextLabel).text = "本次操作消耗金币 ：%s\n本次操作成功几率 ：%d%%" % [
			_钱串(需钱, 金币 >= 需钱),
			提升几率(配置, 窗口._驯养用幸运符, 窗口._驯养幸运符数)]
	画消耗.call()
	var 幸运格 := 页.get_node("幸运符格") as Control
	var 勾选 := 页.get_node("使用幸运符") as CheckBox
	var 数量 := 页.get_node("幸运符数量") as OptionButton
	var 幸运标签 := 页.get_node("幸运符标签") as Label
	for 件 in [幸运格, 勾选, 数量, 幸运标签]:
		(件 as Control).visible = 有模式 and 是潜力
	if 有模式 and 是潜力:
		窗口._configure_checkbox(勾选)
		勾选.button_pressed = 窗口._驯养用幸运符
		# 这一格只有 40 宽、右边紧挨「个幸运符」⇒ 走功能窗口那个压窄入口
		# （`OptionButton` 默认最小宽 70，见 `功能窗口._配置幸运符下拉`）。
		窗口._配置幸运符下拉(数量)
		数量.clear()
		# 真值 §17：`幸运符数量` 是 MComboBox，**数据 1..9**
		for 颗 in range(1, 10):
			数量.add_item(str(颗), 颗)
		数量.selected = clampi(窗口._驯养幸运符数 - 1, 0, 8)
		数量.disabled = not 窗口._驯养用幸运符
		勾选.toggled.connect(func(开: bool) -> void:
			窗口._驯养用幸运符 = 开
			数量.disabled = not 开
			画消耗.call())
		数量.item_selected.connect(func(号: int) -> void:
			窗口._驯养幸运符数 = 号 + 1
			画消耗.call())
	# —— 开始提升（原版 `onClickHand`：材料够 → 金币够 → 按模式发不同协议）
	#    `MButtonF.isDelay = true`（1000ms 节流，真值 §17）⇒ 连点不会连发三条协议。
	var 提升 := 页.get_node("提升按钮") as Button
	窗口._configure_standard_button(提升)
	提升.custom_minimum_size = Vector2(54.0, 22.0)
	# 真值 §17：没选属性（type0）时 `开始提升` **enabled=false**
	提升.disabled = 模式 < 0
	提升.pressed.connect(func() -> void:
		if 模式 < 0:
			return
		if 窗口._宠物按钮节流("开始提升"):
			窗口._请求提升(宠物, 配置, 模式, 幸运符))


## 尾兽预览窗（`RongHunYuLanWindow`，400×360「尾兽真实效果预览」）——
## 融魂页点尾兽弹出，显示那只尾兽**在游戏里的真实形态**。
##
## `图底` 的贴图不再运行时赋值：原版 `initWindowUI:41-46` 是 `new PetPic_background()`
## （**scale-9 符号**）后直接 `width=376; height=280`，只拉伸中间平色区。
## 场景里已把它换成 `NinePatchRect` + `patch_margin_*=12`（实测 `宠物装备面板.png` 198×111
## 的四边渐变带正好 12px、12px 之后是常量色），烘在 `.tscn` 里 ⇒ 这里删掉那行 `as TextureRect`。
static func 渲染预览(窗口) -> void:
	var 页面 := 预览窗场景.instantiate() as Control
	窗口._apply_common_control_skins(页面)
	窗口._content.add_child(页面)
	var 模型位 := 页面.get_node("模型位") as Control
	for 旧 in 模型位.get_children():
		模型位.remove_child(旧)
		旧.queue_free()
	var 兽号: int = 窗口._预览尾兽号
	if 兽号 <= 0:
		return
	var 精灵 := preload("res://脚本/角色/原始动画精灵.gd").new()
	if 精灵.configure("pet", str(兽号).pad_zeros(8), "stand"):
		模型位.add_child(精灵)
		# ⚠️ **不缩放**：`RongHunYuLanWindow.setPetSkin:58-65` 建完 `PetSprite` 直接
		# `x=200; y=315`，全文件没有一处 `scaleX/scaleY` —— 这一扇的名字就叫「真实效果预览」，
		# 半尺寸是页内那枚小预览（`PetRongHunTab.drawPetMovie:282-286` 才给尾兽压到 0.5）的口径，
		# 上一版把两处当成一处了。
