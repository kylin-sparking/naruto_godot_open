extends "res://开发工具/截意志背包页.gd"

## 开窗前先喂两件意志 —— P1-4（2026-10-19 意志完善计划）起，
## `updateHeChengButtonState:301-311` 按**背包件数**定「一键合成」的 enabled：
## 离线空包 ⇒ 钮全程 disabled ⇒ `_绑三态钮` 见 disabled 直接早退（不接三态、只设灰字）
## ⇒ 四态皮与「钮可点」回执**一条都测不到**（原版实机进窗就有货，钮是亮的）。
## 喂 2 件同 id（101 = 图鉴首项，`素材/界面/意志图标/101.png` 在）⇒ 件数 2 > 1 ⇒ 亮。
## 喂数入口与 `验意志格渲染.gd` 同款：直接写 `会话.spirit_bag`（开窗时 `渲染背包` 读它）。
func _initialize() -> void:
	var 会 := root.get_node_or_null("GameSession")
	if 会 != null:
		会.set("spirit_bag", [
				{"id": 101, "color": "1", "slot": 1, "exp": 0, "level": 1},
				{"id": 101, "color": "1", "slot": 2, "exp": 0, "level": 1}])
	super._initialize()

## 意志背包 3 枚 `MButtonF` 的**三态状态机门**（常态 / 悬停 +30 / 按下 −40 / 松手回常态）。
## 骨架（开窗、撑视口、藏 HUD、逐件量矩形）全在 `截意志背包页.gd` → `量具基类.gd`，
## 本文件只补几何门量不到的那一族东西：**运行期换皮、手型光标、字色三档、松手回哪一态**。
##
## 为什么单独一条门（2026-09-28 的教训，`遗址_对照/真值对照表.md` §八）：
## 这三枚与学习页那五枚不同源 —— 那五枚是 `ProgramButton`（字画在皮里、不换字色），
## 这三枚是 `BaseUtil.getButton()` → **`MButtonF`**：一张共享皮 `tag18 MButton_up`(57×22) +
## **独立的 tf**，所以除换皮还要换字色（`MButton3._textColors:69-74`
## up #FCF49C / over #FFFFC3 / down #ACADB2，disabled #939393）。
## 皮三态由 `开发工具/生成意志钮态图.py` 烘（逐字节 = `加亮(常态, ±d)`，不动 alpha）。
##
## 三条原版硬口径，每条都对应一个曾经的真 bug：
##   ① `MButton3.set enabled:460-477`：disabled 做三件事 —— 卸鼠标事件、画**灰皮**、
##      `mouseEnabled = useHandCursor = false`（**没手型**）。
##      原先灰皮写成 `theme_override_textures/disabled` ⇒ TextureButton 没这条属性，
##      `.tscn` 解析器**静默丢掉** ⇒ 那颗「自动升级意志」一直画亮皮还长手型（bug 1）。
##      ⇒ 下面 `_步验禁用` 既断 `disabled`、也断"悬停后皮名不许变"、还断手型是 ARROW。
##   ② `mouseUpHandler:103-108`：松手回 **STATE_UP 而不是 hover**（与 ① 同族的手感差）。
##   ③ 提示框会盖住钮 ⇒ 状态机跑之前先摘掉页面上所有 `文字提示_*` / `意志提示_*`
##      （学习页那 5 个像素就是这么红的，见 §八 bug 2）。
##
## 用法（**不能加 --headless**，无头拿不到视口图像）：
##   Godot --path . --script res://开发工具/截意志背包钮态.gd -- "--出目录=res://测试/截图/意志背包钮态_对照"
## 然后：python 开发工具/出意志钮态对照图.py

const 步间隔 := 3	# 输入步与验步之间隔 3 帧：裁的是上一帧画完的视口图像
const 态色 := {"常态": Color("#fcf49c"), "悬停": Color("#ffffc3"), "按下": Color("#acadb2"),
	"松手": Color("#fcf49c"), "移开": Color("#fcf49c"), "再悬停": Color("#ffffc3")}
const 禁用字色 := Color("#939393")

## 件名 → 派生皮基名（常态与两态都在 `素材/界面/专用控件/`，同一张图压扁成各自宽度）
const 钮表 := {"一键合成": "意志_一键合成", "前往学习": "意志_前往学习"}
## 禁用那枚（`YiZhiPackWindow:481` 建完就 `enabled=false`）：件名 → 灰皮文件名
const 禁用钮 := {"自动升级钮": "意志_自动升级_灰.png"}
const 步序 := ["常态", "悬停", "按下", "松手", "移开", "再悬停"]
## 步 → 期望生效的皮后缀："" 档 = 回常态那张（这三枚的常态也在 专用控件/，与派生两态同源）
const 步期望 := {"常态": "", "悬停": "_悬停", "按下": "_按下", "松手": "", "移开": "", "再悬停": "_悬停"}

var _摘掉的: Dictionary = {}	## 件名 → pressed 的 Callable 数组（测完原样接回）
var _试过: Dictionary = {}


func _队列尾() -> void:
	# 先把三枚钮的 `pressed` 摘掉：状态机里「按下→松手」是一次**完整点击**，
	# 「前往学习」一被按就开学习窗 ⇒ 后面每枚钮都测不到（学习页那条门同款坑）。
	队列.append(_步拆动作)
	for 名 in 钮表:
		for 步 in 步序:
			队列.append(_步送输入.bind(名, 步))
			# 悬停**分两帧两跳**：同一帧连发两条 motion，视口只按最后一条做拾取，
			# 从远处一步跳到中心会**不发 mouse_entered**。
			if 步 == "悬停" or 步 == "再悬停":
				队列.append(_步进心.bind(名))
			队列.append(_步验.bind(名, 步))
	队列.append(_步验禁用)
	队列.append(_步接回)
	队列.append(_步点合成)
	队列.append(_步验合成回执)
	队列.append(_步点锁格)
	队列.append(_步验扩容弹)
	队列.append(_步点弹钮.bind("取消"))
	队列.append(_步验弹关)
	队列.append(_步点学习)
	队列.append(_步验学习开窗)


func _步拆动作() -> void:
	for 名 in 钮表:
		var 件 := 钮件(名)
		if 件 == null:
			continue
		var 列: Array = []
		for 连 in 件.get_signal_connection_list("pressed"):
			列.append(连.callable)
			件.disconnect("pressed", 连.callable)
		_摘掉的[名] = 列
	_摘提示()
	等待 = 2


## 摘掉页面上所有提示节点（`文字提示_*` / `意志提示_*`）——它们挂在页面根最上层
## （原版挂 stage，层级等价），鼠标停在钮上时就压在钮的右下，把裁图里那块皮盖掉。
func _摘提示() -> void:
	var 页 := 页根()
	if 页 == null:
		return
	for 子 in 页.get_children():
		if String(子.name).begins_with("文字提示_") or String(子.name).begins_with("意志提示_"):
			页.remove_child(子)
			子.queue_free()


func _步接回() -> void:
	for 名 in _摘掉的:
		var 件 := 钮件(String(名))
		if 件 == null:
			continue
		for 回 in (_摘掉的[名] as Array):
			件.connect("pressed", 回 as Callable)
	等待 = 2


func 钮件(名: String) -> Control:
	var 页 := 页根()
	return 页.get_node_or_null(取路径(名)) as Control if 页 != null else null


func 字件(名: String) -> Label:
	var 页 := 页根()
	if 页 == null:
		return null
	return 页.get_node_or_null(取路径({"一键合成": "合成字", "前往学习": "学习字",
			"自动升级钮": "自动升级字"}[名])) as Label


## 落点：页面里那块空白（格排下方、钮排上方的黄底带）——不能拿 `心 + (0,160)`，
## 那几枚钮加 160 就掉出视口，视口外的 motion 不更新 hover ⇒「再悬停」永远拿不到亮态。
func 远点() -> Vector2:
	# (300,470)：格排底 460 以下、钮排 492 以上那条空白黄底带 —— 落在这里既不在任何钮上，
	# 也不会因为"点落在格子上"改变结论。
	return 页根().get_global_position() + Vector2(300, 470)


func _移到(点: Vector2) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 点
	移.global_position = 点
	root.push_input(移)


func _键(点: Vector2, 按下: bool) -> void:
	var 键 := InputEventMouseButton.new()
	键.position = 点
	键.global_position = 点
	键.button_index = MOUSE_BUTTON_LEFT
	键.pressed = 按下
	root.push_input(键)


func 中心(件: Control) -> Vector2:
	var 盒 := 件.get_global_rect()
	return 盒.position + 盒.size / 2.0


func _步送输入(名: String, 步: String) -> void:
	var 件 := 钮件(名)
	if 件 == null:
		_错("取不到钮 %s" % 名)
		return
	var 心 := 中心(件)
	match 步:
		"常态":
			_移到(远点())
		"悬停":
			_移到((心 + 远点()) / 2.0)	# 半程，下一帧 `_步进心` 才进中心
		"按下":
			_移到(心)
			_键(心, true)
		"松手":
			_移到(心)
			_键(心, false)
		"移开":
			_移到(远点())
		"再悬停":
			_移到((心 + 远点()) / 2.0)
	等待 = 2 if 步 == "悬停" or 步 == "再悬停" else 步间隔


func _步进心(名: String) -> void:
	var 件 := 钮件(名)
	if 件 == null:
		return
	_移到(中心(件))
	等待 = 步间隔


func _步验(名: String, 步: String) -> void:
	var 件 := 钮件(名) as TextureButton
	if 件 == null:
		_错("取不到钮 %s" % 名)
		return
	var 皮 := 件.texture_normal as Texture2D
	var 得 := 皮.resource_path.get_file() if 皮 != null else "<无皮>"
	var 后缀 := String(步期望[步])
	var 想名 := "%s.png" % 钮表[名] if 后缀.is_empty() else "%s%s.png" % [钮表[名], 后缀]
	var 对: bool = 得 == 想名
	if not 对:
		_错("%s 第「%s」步 生效皮=「%s」，应为「%s」（rect=%s mf=%d dis=%s vis=%s）" % [
				名, 步, 得, 想名, 件.get_global_rect(), 件.mouse_filter, 件.disabled, 件.visible])
	if not 对 and (步 == "悬停" or 步 == "再悬停") and not _试过.has(名):
		# 首枚钮的 `mouse_entered` 偶发丢失。**重试必须换坐标**（hover 归属只在位置变化时重算，
		# 原地重发同一条 motion 等于什么都没做 —— 2026-09-28 实测原地补一跳仍然红）。只补一次。
		_试过[名] = true
		_移到(中心(件) + Vector2(3, 3))
		等待 = 2
		队列.append(_步进心.bind(名))
		队列.append(_步验.bind(名, 步))
		return
	if 件.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
		_错("%s 没有手型光标（原版 MButton3.init():135 useHandCursor=true）" % 名)
	# 字是**独立 Label**（MButtonF 的 tf）⇒ 除换皮还要按三档换字色
	var 字 := 字件(名)
	var 想色 := 态色[步] as Color
	# ⚠ 颜色**必须近似比**：`Color("#fcf49c")` 是 252/255=0.98823529…，而 .tscn 里烘的是
	#   6 位小数 0.988235 —— 打印出来一模一样、`==` 判不等（2026-10-03 实测就是这么红的）。
	var 色对: bool = 字 != null and 字.get_theme_color("font_color").is_equal_approx(想色)
	if not 色对:
		_错("%s 第「%s」步 字色=%s，应为 %s（MButton3._textColors）" % [名, 步,
				str(字.get_theme_color("font_color")) if 字 != null else "<无字件>", 想色])
	裁图(件, 名, 步)
	_行("  %-6s %-4s 皮=%-26s 应为 %-26s 字色=%s %s" % [名, 步, 得, 想名,
			("√" if 色对 else "×"), "√" if 对 and 色对 else "!!"])


## 每步裁一张**等尺寸、不外扩**的图（视口图不跟 root.size 变，外扩会被屏缘切）。
func 裁图(件: Control, 名: String, 步: String) -> void:
	var 图像 := root.get_texture().get_image()
	var 盒 := 件.get_global_rect()
	var 起 := Vector2i(int(盒.position.x), int(盒.position.y))
	var 尺 := Vector2i(int(盒.size.x), int(盒.size.y))
	尺.x = clampi(尺.x, 1, 图像.get_width() - 起.x)
	尺.y = clampi(尺.y, 1, 图像.get_height() - 起.y)
	图像.get_region(Rect2i(起, 尺)).save_png("%s/态_%s_%s.png" % [出目录, 名, 步])


## 「自动升级意志」这一枚必须**一直灰**：`YiZhiPackWindow:476-482` 建完就 `enabled=false`，
## 只有勾选 + 槽里有货才亮（`updateAutoUpgradeBtnState:679-693`，本工程没这条数据入口）。
## 悬停它一跳：皮名不许变、手型不许出现、字色停在 #939393。
func _步验禁用() -> void:
	for 名 in 禁用钮:
		var 件 := 钮件(名) as TextureButton
		if 件 == null:
			_错("取不到 %s" % 名)
			continue
		if not 件.disabled:
			_错("%s 没 disabled（原版 :481 enabled=false）" % 名)
		var 心 := 中心(件)
		_移到((心 + 远点()) / 2.0)
		等待 = 2
		队列.append(_步禁悬.bind(名))


func _步禁悬(名: String) -> void:
	var 件 := 钮件(名) as TextureButton
	# 断的是**属性**：`texture_disabled` 到底挂没挂上那张灰皮。
	# （"屏幕上画出来的是不是它"由 `出意志钮态对照图.py` 拿 `态_自动升级钮_禁用.png` 逐像素判 ——
	#   属性名写错这里红、皮不对那里红，两道门各管一段。）
	var 灰 := 件.texture_disabled as Texture2D
	var 得 := 灰.resource_path.get_file() if 灰 != null else "<没挂灰皮>"
	var 对: bool = 得 == str(禁用钮[名])
	if not 对:
		_错("%s 的 texture_disabled=「%s」，应为「%s」——灰皮必须写进 `texture_disabled`："
				% [名, 得, 禁用钮[名]]
				+ "TextureButton 没有 `theme_override_textures/disabled` 这条属性，"
				+ "写了会被 .tscn 解析器**静默丢掉** ⇒ 钮照画亮皮（2026-09-28 的 bug 1）")
	if 件.mouse_default_cursor_shape != Control.CURSOR_ARROW:
		_错("%s 禁用态还有手型（MButton3.set enabled 里 mouseEnabled=useHandCursor=false）" % 名)
	var 字 := 字件(名)
	if 字 != null and not 字.get_theme_color("font_color").is_equal_approx(禁用字色):
		_错("%s 禁用字色=%s，应为 #939393" % [名, 字.get_theme_color("font_color")])
	_移到(远点())
	裁图(件, 名, "禁用")
	_行("  %-6s %-4s 灰皮=%-24s 手型=ARROW 字色=#939393 %s" % [名, "禁用", 得,
			"√" if 对 and 件.mouse_default_cursor_shape == Control.CURSOR_ARROW else "!!"])


## 接回 `pressed` 之后真点一次：「一键合成」→ 有背包数据才弹 `FamillyPopUpWindow`
## （`hechengHandler:311-317`），本工程没那条数据也没那扇窗 ⇒ 按约定回状态文案。
func _步点合成() -> void:
	var 件 := 钮件("一键合成")
	if 件 == null:
		return
	var 心 := 中心(件)
	_移到(心)
	_键(心, true)
	_键(心, false)
	等待 = 步间隔


func _步验合成回执() -> void:
	var 主 := 主窗()
	var 状 := 主.get_node_or_null("后端状态") as Label if 主 != null else null
	if 状 == null:
		_错("没有 后端状态 Label")
		return
	if 状.text != "背包内没有可合成的意志":
		_错("点「一键合成」后状态=「%s」，应为「背包内没有可合成的意志」⇒ 钮根本没收到点击" % 状.text)
	else:
		_行("  钮可点        「一键合成」⇒ 状态「%s」√" % 状.text)


## P1-1 锁格点击 ⇒ 扩容确认（`clickCellHandler:563-586`，2026-10-19 补的链路）。
## `spirit_pack_limit` 默认 5（会话 `:106`）⇒ `格_5` 是第一个锁格。点它应当：
##   ① 把 5..5（`packLimit` 到 `position-1`）点亮成选中态（黄框常亮）；
##   ② 按 `common.extend` 累算总价（extend['1']=10）弹「消息确认框」（`FamillyPopUpWindow`）。
## ⚠️ 这条链 2026-10-19 逮过一个静默 bug：`str("格_5").substr(3)` 得空串、
##   `int("")` 静默变 0 ⇒ 点任何锁格都被当成"第 0 格"（开着）挡掉，扩容永远不弹。
##   所以这里**必须真点一次锁格**，光看源码字面照不出来。
func _步点锁格() -> void:
	var 页 := 页根()
	var 格 := 页.get_node_or_null("背包容器/格_5") as Control if 页 != null else null
	if 格 == null:
		_错("取不到 背包容器/格_5（第一个锁格，packLimit=5）")
		return
	var 心 := 中心(格)
	_移到(心)
	_键(心, true)			# 只发按下：`_格输入` 认的就是 pressed（格是 Control 不是 Button）
	等待 = 步间隔


## 弹出来了 + 文案带总价 + 预览点亮了 5..5。
func _步验扩容弹() -> void:
	var 页 := 页根()
	var 弹 := 页.get_node_or_null("消息确认框") as Control if 页 != null else null
	if 弹 == null:
		_错("点锁格 `格_5` 没弹「消息确认框」⇒ `_点背包格` 没被触发（查 `_格输入` 接线 / 名字解析）")
		return
	var 正 := 弹.get_node_or_null("主体/正文") as RichTextLabel
	var 文 := 正.text if 正 != null else "<无正文>"
	if not 文.contains("10"):
		_错("扩容确认框正文=「%s」，应含总价 10（extend['1']=10，`_扩容花费(5,6)`）" % 文)
	var 预览 := 页.get_node_or_null("背包容器/格_5/格悬停") as CanvasItem
	if 预览 == null or not 预览.visible:
		_错("点锁格后 `格_5` 的黄框没点亮（`_设选中` ⇒ `_overSkin.visible`）")
	else:
		_行("  锁格可点        「格_5」⇒ 消息确认框（总价 10）+ 预览点亮 √")


## 点弹上那颗钮（"确定"/"取消"）。确定会真发 `spirit_extend` ⇒ 离线回"服务端结算"，
## 会把后面「前往学习」那步的状态文案搅乱，所以这条门只走**取消**（收摊，零请求）。
func _步点弹钮(名: String) -> void:
	var 页 := 页根()
	var 弹 := 页.get_node_or_null("消息确认框") as Control if 页 != null else null
	if 弹 == null:
		_错("消息确认框不在，点不了「%s」" % 名)
		return
	var 钮 := 弹.get_node_or_null("主体/%s" % 名) as Button
	if 钮 == null:
		_错("消息确认框里没有「%s」钮" % 名)
		return
	var 心 := 中心(钮)
	_移到(心)
	_键(心, true)
	_键(心, false)
	等待 = 步间隔


## 取消 ⇒ 框没了（`收` = queue_free）、预览撤掉、**一个请求都没发**。
func _步验弹关() -> void:
	var 页 := 页根()
	var 弹 := 页.get_node_or_null("消息确认框") if 页 != null else null
	if 弹 != null:
		_错("点「取消」后消息确认框还在（`收` 回调 = queue_free 遮罩层）")
		return
	var 预览 := 页.get_node_or_null("背包容器/格_5/格悬停") as CanvasItem
	if 预览 != null and 预览.visible:
		_错("取消后 `格_5` 的黄框还亮着（`_撤扩容点亮` 没跑）")
	var 主 := 主窗()
	var 状 := 主.get_node_or_null("后端状态") as Label if 主 != null else null
	if 状 != null and 状.text != "" and 状.text != "背包内没有可合成的意志":
		_错("取消扩容后后端状态=「%s」，应为空（取消不许发请求）" % 状.text)
	_行("  取消收摊        「取消」⇒ 框没、预览撤、零请求 √")


## 「前往学习」= `studyHandler:364-367` → `YiZhiManager.showYiZhiStudyWindow()` ⇒ **开学习窗**。
func _步点学习() -> void:
	var 件 := 钮件("前往学习")
	if 件 == null:
		return
	var 心 := 中心(件)
	_移到(心)
	_键(心, true)
	_键(心, false)
	等待 = 步间隔


func _步验学习开窗() -> void:
	var 管理 := 场景.get_node_or_null("窗口管理")
	var 窗 := 管理.call("取窗口", "意志学习") as Node if 管理 != null else null
	var 开: bool = 窗 != null and bool(窗.call("已打开"))
	if not 开:
		_错("点「前往学习意志」没开学习窗（原版 studyHandler → showYiZhiStudyWindow）")
	else:
		_行("  前往学习可点    ⇒ 「意志学习」窗已开 √")
