extends SceneTree

## 修行收益页（原版「领取修行收益」`LingquBiguanShouyi`）逐件几何门 + 数据链门。
##
## 期望值唯一来源 = `真值/窗口/修行收益.md` §②（逐件时间轴，每条带 AS3 行号）与 §③（元件/边距）。
## 场景按 **AS3 窗口局部坐标**画（`数据/界面/窗口尺寸.json` 里那页的 `原点` = [0,0]），
## 所以这里直接比节点的 `position`/`size`，不再做二次换算。
##
## 除了摆位，这一条还钉 10-20 用户拿原版对照图打回时查实的那三链：
##   ① 密卷 id 从 `数据/原版杂项.json` 取到的是**整数** ⇒ 必须解成 "16000003"（`String(整数)` 会静默空串）；
##   ② 图标路径必须**在盘上且 PNG 能直读**（判素材只认 `FileAccess`，不认 `ResourceLoader.exists` ⇒ 防导入缓存假绿）；
##   ③ 格内角标按原版口径：0 本 ⇒ 空串（不是 ×0）、N 本 ⇒ 十进制数字，且右对齐。
##
## 跑法：Godot --headless --path . --script res://测试/修行收益页回归测试.gd

const 容差 := 1.0
const 页面场景 := "res://场景/界面/窗口/闭关/领取修行收益.tscn"
const 尺寸表 := "res://数据/界面/窗口尺寸.json"
const 密卷图标期望 := "res://素材/物品/原版/FuZhuWuPin/FuZhuWuPin_16000003_info.swf_1_FuZhuWuPin_16000003_info_icon.png"

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 系统窗口 := preload("res://脚本/界面/窗口/系统窗口.gd")
const 窗口管理脚本 := preload("res://脚本/界面/窗口管理.gd")

## 判据总条数：协程中途炸掉时 `判` 会小于它 ⇒ 末行照样能打「红 0」也不许算过（工程口径）。
const 判满条数 := 78

## 件名 → [x, y, w, h, AS3 出处]
const 件表 := {
	"外层面板": [6.0, 39.0, 255.0, 146.0, "LingquBiguanShouyi.as:232-237 cellBackground=MYellow_background(10)"],
	"子面板底": [11.0, 85.0, 245.0, 94.0, ":238-243 background3=MPane_background(97)"],
	"密卷格": [21.0, 94.0, 40.0, 40.0, ":95-98 iocnContaier=ItemWindowCell（MGrid_background 172）"],
	"密卷格/角标": [1.0, 24.0, 37.0, 16.0, "ItemWindowCell.as:54-58 tf=(1,24,37,16) autoSize=RIGHT"],
	"经验底图": [172.0, 125.0, 68.0, 21.0, ":99-104 _experienceBg=MTextInput_background(437)"],
	"精华底图": [172.0, 152.0, 68.0, 21.0, ":105-110 _zhenQiBg"],
	"经验标题": [83.0, 123.0, 85.0, 18.0, ":111-112 _experienceLabel（MLabel，带全角冒号）"],
	"经验值": [172.0, 127.0, 68.0, 18.0, ":113-119 _experience（纯 TextField，不是输入框）"],
	"精华标题": [83.0, 151.0, 85.0, 18.0, ":120-121 _zhenQiLabel"],
	"精华值": [174.0, 154.0, 68.0, 18.0, ":122-128 _zhenQi"],
	"购买": [22.0, 143.0, 37.0, 22.0, ":131-137 buyBtn，btn_width_two=37、isScale9Grid=false ⇒ 高取 upSkin 22"],
	"单倍领取": [35.0, 189.0, 61.0, 22.0, ":138-144 + :152 danbeiBtn，btn_width_four=61"],
	"双倍领取": [171.0, 189.0, 61.0, 22.0, ":145-151 + :153-154 shuangbeiBtn，x=6+255-61-29=171（不是 :146 那个 163）"],
	"收益标题": [119.0, 92.0, 127.0, 18.0, ":155-156 shouyiTf，色 2003199=#1E90FF"],
	"提示盒": [13.0, 47.0, 242.0, 40.0, ":157-161 匿名 Box（hintTf 的父容器）"],
}

var 判 := 0
var 红 := 0


## 一个只用来喂 `背包密卷数量` 的假会话（原版 `isBagExisItem` 只看背包里该 id 的总数）
class 假会话:
	extends Node
	var inventory: Array = []


## ── 左窗「修行设定与收益」（原版 `BiGuanWindow` + 子面板 `ShouyiWindow`）──────────────
## 件名 → [x, y, w, h, AS3 出处]。前 10 件是**窗口局部坐标**，`收益面板/…` 是**子面板局部坐标**
## （子面板自己挂在窗口 (11,136)，`BiGuanWindow.as:95-98`）。
const 左窗场景 := "res://场景/界面/窗口/闭关/闭关窗口.tscn"
const 左窗件表 := {
	"外层面板": [6.0, 39.0, 255.0, 230.0, "BiGuanWindow.as:130-135 cellBackground=MYellow_background"],
	"开启提示": [20.0, 44.0, 235.0, 18.0, ":52-53 unlockTf（表里带 `<font color=#00ff00>` ⇒ 绿）"],
	"分隔线": [11.0, 66.0, 245.0, 2.0, ":136-141 _line=LineHPicF（extends Sprite ⇒ 九宫格无效）"],
	"时间标题": [18.0, 74.0, 99.0, 18.0, ":54-55 curBiguanTimerTf = CN.BIGUAN_WINDOW_CUR_TIMER"],
	"小时值": [114.0, 74.0, 40.0, 21.0, ":142-147 hourBg（原版 hourTf 在框内 (115,74,38,18)）"],
	"小时": [155.0, 74.0, 29.0, 18.0, ":56-57 hourLable"],
	"分钟值": [186.0, 74.0, 40.0, 21.0, ":148-153 minuteBg（minuteTf (188,74,38,18)）"],
	"分钟": [228.0, 74.0, 31.0, 18.0, ":58-59 minuteLable"],
	"提示盒": [18.0, 97.0, 238.0, 40.0, ":64-66 匿名 Box（regardTf 的父容器）"],
	"提示盒/说明": [0.0, 0.0, 238.0, 40.0, ":67-77 regardTf，高 = textHeight + 6（声明框 40）"],
	"收益面板": [11.0, 136.0, 245.0, 110.0, ":95-98 shouyiWindow 挂点 + ShouyiWindow.as:58-63 background"],
	"收益面板/标题": [4.0, 10.0, 146.0, 18.0, "ShouyiWindow.as:77-78 dangQianShouyiTf"],
	"收益面板/经验标题": [6.0, 40.0, 72.0, 18.0, ":79-80 experienceLable（表里带全角冒号）"],
	"收益面板/经验": [91.0, 41.0, 82.0, 21.0, ":64-69 experienceBg + :80-81 experience（纯 TextField）"],
	"收益面板/金币标题": [6.0, 70.0, 85.0, 18.0, ":82-83 zhenQiLable"],
	"收益面板/金币": [91.0, 69.0, 82.0, 21.0, ":70-75 zhenQiBg + :83-84 zhenQi"],
	"收益面板/领取收益": [193.0, 49.0, 37.0, 22.0, ":86-91 lingquBtn（宽 btn_width_two=37、高取 upSkin 22）"],
}


func _比(说明: String, 条: bool) -> void:
	判 += 1
	if not 条:
		红 += 1
		print("!! " + 说明)


## `数据/界面/窗口尺寸.json` 的数字一律解成 float ⇒ 只按数值判 0，不许比 `[0, 0]` 那种串
## （实测 `[0.0, 0.0]`，比串是一条永远红、谁也改不动的死判据）。
func _是零原点(值: Variant) -> bool:
	if not (值 is Array) or (值 as Array).size() != 2:
		return false
	return absf(float((值 as Array)[0])) < 0.001 and absf(float((值 as Array)[1])) < 0.001


func _initialize() -> void:
	var 页面根 := (load(页面场景) as PackedScene).instantiate() as Control
	root.add_child(页面根)

	# ---- ① 窗尺寸：只认尺寸表（场景根尺寸由它驱动）----
	var 表: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(尺寸表))
	var 页: Dictionary = 表.get("领取修行收益", {})
	_比("尺寸表里应有「领取修行收益」这一页", not 页.is_empty())
	_比("窗宽必须 = AS3 字面 267（`LingquBiguanShouyi.as:225`），实际 %s" % str(页.get("宽")), int(页.get("宽", 0)) == 267)
	_比("窗高必须 = AS3 字面 218（`:226`），实际 %s" % str(页.get("高")), int(页.get("高", 0)) == 218)
	_比("这一页按 AS3 窗口局部坐标画 ⇒ 原点必须是 (0,0)，实际 %s" % str(页.get("原点")),
			_是零原点(页.get("原点")))

	# ---- ② 逐件矩形 ----
	for 件名 in 件表:
		var 录: Array = 件表[件名]
		var 件 := 页面根.get_node_or_null(件名) as Control
		if 件 == null:
			_比("场景里缺件「%s」（出处 %s）" % [件名, 录[4]], false)
			continue
		var 期 := Rect2(float(录[0]), float(录[1]), float(录[2]), float(录[3]))
		var 最大偏 := maxf(maxf(absf(件.position.x - 期.position.x), absf(件.position.y - 期.position.y)),
				maxf(absf(件.size.x - 期.size.x), absf(件.size.y - 期.size.y)))
		_比("「%s」矩形 %s ≠ 期望 %s（%s）" % [件名, Rect2(件.position, 件.size), 期, 录[4]], 最大偏 <= 容差)

	# ---- ③ 三颗钮不许被置灰（原版 `:172-174` 全程只挂监听、没有一句 disabled）----
	for 件名 in ["购买", "单倍领取", "双倍领取"]:
		var 钮 := 页面根.get_node_or_null(件名) as Button
		_比("「%s」场景里不许预置 disabled（置灰是本工程自造的）" % 件名, 钮 != null and not 钮.disabled)
		_比("「%s」要手型光标（MButton3 的 buttonMode）" % 件名,
				钮 != null and 钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND)
	var 格 := 页面根.get_node_or_null("密卷格") as Button
	_比("密卷格不许 disabled（原版 ItemWindowCell 自带 buttonMode + 单击/双击）", 格 != null and not 格.disabled)
	_比("密卷格要手型光标（同一处 buttonMode）",
			格 != null and 格.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND)

	# ---- ④ 提示件：RichTextLabel + BBCode + 12 号 + 行距 2（本页 leading 全查无 ⇒ +2）----
	var 提示 := 页面根.get_node_or_null("提示盒/提示") as RichTextLabel
	_比("提示必须是 RichTextLabel（原版 htmlText 双色）", 提示 != null)
	if 提示 != null:
		_比("提示必须开 bbcode_enabled", 提示.bbcode_enabled)
		_比("提示字号必须 12（`:168-169` 走默认 12），实际 %d" % 提示.get_theme_font_size("normal_font_size"),
				提示.get_theme_font_size("normal_font_size") == 12)
		_比("提示行距必须 2（= Flash leading 0 + 工程口径 +2），实际 %d" % 提示.get_theme_constant("line_separation"),
				提示.get_theme_constant("line_separation") == 2)
		_比("提示不许自己出滚动条（原版没有这一档）", not 提示.scroll_active)
		_比("提示不许吃鼠标（`:169-170` mouseEnabled=false）",
				提示.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	else:
		_比("提示必须存在（`提示盒/提示` 查无 ⇒ 后面四条无从可判）", false)

	# ---- ⑤ 数据链：密卷 id ⇒ 图标 ⇒ 名字，一条不许断 ----
	var 号 := 系统窗口.修行密卷id()
	_比("密卷 id 必须从 `数据/原版杂项.json` 解出 16000003，实际 [%s]（整数被 String() 吃成空串就是 10-20 那个症状）" % 号,
			号 == "16000003")
	var 图标 := String(游戏数据.item_icon_path(号))
	_比("图标路径要解得出来，实际 [%s]" % 图标, 图标 == 密卷图标期望)
	_比("图标文件必须在盘上（FileAccess 直读，不信导入缓存）：%s" % 图标, FileAccess.file_exists(图标))
	_比("图标 PNG 要能真解码（拿到 null 就说明文件在但读不出）", Image.load_from_file(图标) != null)
	_比("密卷名字必须从物品表取到「修行密卷」，实际 [%s]" % String(游戏数据.item(号).get("name", "")),
			String(游戏数据.item(号).get("name", "")) == "修行密卷")

	# ---- ⑥ 角标口径（原版只判有没有，数字给角标）----
	var 会 := 假会话.new()
	会.inventory = [{"id": "16000003", "quantity": 2}, {"id": "03000001", "quantity": 9}]
	_比("背包里两枚密卷 ⇒ 角标数应为 2，实际 %d" % 系统窗口.背包密卷数量(会, 号),
			系统窗口.背包密卷数量(会, 号) == 2)
	会.inventory = [{"id": "03000001", "quantity": 9}]
	_比("一枚都没有 ⇒ 应为 0（角标此时画空串，不画 ×0）", 系统窗口.背包密卷数量(会, 号) == 0)
	会.inventory = [{"id": 16000003, "quantity": 3}]
	_比("背包里该字段是整数时也要数到，实际 %d"
			% 系统窗口.背包密卷数量(会, 号), 系统窗口.背包密卷数量(会, 号) == 3)
	会.inventory = [{"id": 16000003.0, "quantity": 3}, {"id": "16000003", "quantity": 1}]
	_比("JSON 解出来的 id 一律是 float（16000003.0）⇒ 也要数到，且与串形式同键（实际 %d，应为 4）"
			% 系统窗口.背包密卷数量(会, 号), 系统窗口.背包密卷数量(会, 号) == 4)
	会.free()
	var 角 := 页面根.get_node_or_null("密卷格/角标") as Label
	_比("角标右对齐（ItemWindowCell tf autoSize=RIGHT）",
			角 != null and 角.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT)

	# ---- ⑦ 成对开窗（`UIMain2.as:5955 centerTwoWindow`）----
	_比("窗口管理必须登记「领取修行收益 → 闭关经验」这一对成对伴随",
			String(窗口管理脚本.成对伴随.get("领取修行收益", "")) == "闭关经验")

	# ---- ⑧ 左窗「修行设定与收益」：窗尺寸 + 逐件矩形 + 那颗钮必须藏着 ----
	var 左页: Dictionary = 表.get("闭关经验", {})
	_比("左窗宽必须 = AS3 字面 267（`BiGuanWindow.as:122-125`），实际 %s" % str(左页.get("宽")),
			int(左页.get("宽", 0)) == 267)
	_比("左窗高必须 = AS3 字面 274（同上），实际 %s" % str(左页.get("高")), int(左页.get("高", 0)) == 274)
	# ⚠ 整条串一次成型：GDScript 里 `%` 比 `+` 结合更紧，`"…%s…" + "…" % x` 会把格式
	#   只套到后半段上 ⇒ 前半段的 `%s` 原样漏进日志（工程记忆里为这条踩过）。
	var 左原点说明 := "左窗也按 AS3 窗口局部坐标画 ⇒ 原点必须是 (0,0)，实际 %s（漏了这条会被容器整体再推 (8,38)，两道错还会互相顶掉 ⇒ 见工程记忆「原点键优先于整框」）" % str(左页.get("原点"))
	_比(左原点说明, _是零原点(左页.get("原点")))

	var 左根 := (load(左窗场景) as PackedScene).instantiate() as Control
	root.add_child(左根)
	for 件名 in 左窗件表:
		var 录: Array = 左窗件表[件名]
		var 件 := 左根.get_node_or_null(件名) as Control
		if 件 == null:
			_比("左窗场景里缺件「%s」（出处 %s）" % [件名, 录[4]], false)
			continue
		var 期 := Rect2(float(录[0]), float(录[1]), float(录[2]), float(录[3]))
		var 最大偏 := maxf(maxf(absf(件.position.x - 期.position.x), absf(件.position.y - 期.position.y)),
				maxf(absf(件.size.x - 期.size.x), absf(件.size.y - 期.size.y)))
		_比("左窗「%s」矩形 %s ≠ 期望 %s（%s）" % [件名, Rect2(件.position, 件.size), 期, 录[4]], 最大偏 <= 容差)
	# 原版 `ShouyiWindow.as:92` 先挂 CLICK、`:94` 才 `visible = false` ⇒ **这颗钮在原版上看不见**。
	# 断言的是**场景里烘的**那个 visible（不是运行期被代码改完的值）⇒ 编辑器里打开就是玩家看到的样子。
	var 左领 := 左根.get_node_or_null("收益面板/领取收益") as Button
	_比("左窗「领取收益」在 .tscn 里就必须 visible=false（原版 :94；运行期再藏 = 编辑器里是个骗人的钮）",
			左领 != null and not 左领.visible)
	var 左说 := 左根.get_node_or_null("提示盒/说明") as Label
	_比("左窗红字说明不许吃鼠标（`BiGuanWindow.as:76 mouseEnabled=false`）",
			左说 != null and 左说.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	# 分隔线：`LineHPicF`(133) 是 `extends Sprite` ⇒ 只能**整帧拉伸**，而且它**是一张素材**
	# （天然 252×2、两端半透明渐隐），不是自画的色块 ⇒ 钉类型 + 钉贴图 + 钉"真能解码"。
	var 线 := 左根.get_node_or_null("分隔线") as TextureRect
	_比("分隔线必须是 TextureRect（原来是 ColorRect 画一条实色 #806047 ⇒ 两端没有渐隐、颜色也是编的）",
			线 != null)
	if 线 != null:
		var 线路 := String(线.texture.resource_path) if 线.texture != null else ""
		_比("分隔线贴图必须是素材里的 横向分隔线.png（= LineHPicF），实际 [%s]" % 线路,
				线路.ends_with("通用控件/横向分隔线.png"))
		_比("分隔线贴图要在盘上真能解码（只认 FileAccess，不信导入缓存）：%s" % 线路,
				FileAccess.file_exists(线路) and Image.load_from_file(线路) != null)
		var 线说明 := "分隔线不许带九宫格语义：贴图要整帧拉伸到 245×2（`LineHPicF.as:6 extends Sprite`），实际 rect=%s 拉伸档=%d" % [str(线.size), 线.stretch_mode]
		_比(线说明, 线.stretch_mode == TextureRect.STRETCH_SCALE)
	# 数字字号：用户 10-20 报「左页的数字有点小和原版本不一致」。
	# 原版这四件是 `BaseUtil.getLabel("",16777215)` = `MLabel`（`BiGuanWindow.as:60-63`、
	# `ShouyiWindow.as:80-85`），而 `MLabel.as:218-219` 的默认 `TextFormat.size = 12`。
	# ⚠ 问的是**运行期解算值**（`get_theme_font_size`），不是主题表里声明的那个数 ——
	#   声明被场景里的 `theme_override_font_sizes/*` 顶掉时，屏幕上仍是小的（记忆第十六种）。
	for 件名 in ["小时值", "分钟值", "收益面板/经验", "收益面板/金币"]:
		var 数 := 左根.get_node_or_null(件名) as LineEdit
		_比("左窗「%s」应是 LineEdit 数值件（出处见 左窗件表）" % 件名, 数 != null)
		if 数 != null:
			var 字 := 数.get_theme_font_size("font_size")
			_比("左窗「%s」的数字字号解算应是 12（`MLabel.as:218-219`），实得 %d" % [件名, 字], 字 == 12)
	左根.queue_free()

	页面根.queue_free()
	if 判 != 判满条数:
		print("!! 判据只跑了 %d 条，应为 %d 条 ⇒ 中途有判据没被执行（协程被报错打断），本条不算过" % [判, 判满条数])
		quit(1)
		return
	print("修行收益页回归测试：通过（%d 条判据，红 %d 条）" % [判, 红])
	quit(0 if 红 == 0 else 1)
