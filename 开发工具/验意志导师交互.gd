extends "res://开发工具/截意志学习页.gd"

## 运行时交互探针：只验用户报的两条缺陷（几何门由 `截意志学习页.gd` 负责，本文件不重复量坐标）。
##   ① 导师头像可点 —— 原版 `TeacherCell.as:46-49`（`_header.buttonMode=true` + CLICK）、
##      `:131-142` `clickTeacherHandler`（无召唤钮 ⇒ `requestYiZhi` + **把自己气泡收起**）。
##   ② 头像上的气泡是**动图** —— 原版 `:67-72` `UISwf_yizhi_PaoPao` 是 MovieClip，
##      29 帧里只有 3 张不同图（帧 1/10/20，实测差 33/41 像素）⇒ Godot 用 `AnimatedTexture(frames=3)`。
## 用法（不能加 --headless）：
##   Godot --path . --script res://开发工具/验意志导师交互.gd -- "--出目录=res://测试/截图/意志导师交互"

const 点后提示 := "已选择第%d位意志导师；等待原服务端返回学习结果"

var _快照数组: Array = []
var _帧号数组: Array[int] = []
var _点前泡显 := false
var _弹窗: Control

## 唯一 `special.needYuanBao>0` 的一位（`数据/意志.json` NPC3 = 自来也，400 元宝），
## 也是原版 `TeacherPanel:68` 写死的召唤位。
const 召唤位 := 3


func _队列尾() -> void:
	队列.append(_步查动图素材)
	队列.append(_步悬停)
	# 采满 40 帧（>0.6s）：气泡每 0.375s 换一帧，闪若与换帧同周期，8 帧会漏检
	for i in 40:
		队列.append(_步采悬停)
	队列.append(_步判闪)
	for i in 4:
		队列.append(_步采移出)
	队列.append(_步判移出)
	队列.append(_步点击)
	队列.append(_步照弹窗)
	队列.append(_步点取消)
	队列.append(_步验取消)
	队列.append(_步点召唤钮)
	队列.append(_步点确定)
	队列.append(_步验确定)
	队列.append(_步充元宝)
	队列.append(_步再点召唤钮)
	队列.append(_步验再召唤)
	队列.append(_步挪开鼠标)
	for i in 6:
		队列.append(_步气泡快照)
	队列.append(_步比动图)
	# --- 三处悬浮提示（`TeacherCell:74-75/111-112`、`TeacherPanel:139`）---
	队列.append(_步查提示节点)
	队列.append(_步查提示版式)
	队列.append(_步悬停出提示)
	for i in 4:
		队列.append(_步提示连拍)
	for i in 2:
		队列.append(_步查跟随)	# 第一次可能只是把鼠标悬回去，第二次才量位移
	队列.append(_步移出收提示)


## 整窗裁一张（弹窗开着时用来出视觉证据）。
func 整窗照(名: String) -> void:
	var 主 := 主窗()
	if 主 == null:
		return
	var 图像 := root.get_texture().get_image()
	var 起 := Vector2i(int(主.get_global_position().x), int(主.get_global_position().y))
	var 尺 := Vector2i(int(主.size.x), int(主.size.y))
	尺.x = clampi(尺.x, 1, 图像.get_width() - 起.x)
	尺.y = clampi(尺.y, 1, 图像.get_height() - 起.y)
	图像.get_region(Rect2i(起, 尺)).save_png("%s/%s.png" % [出目录, 名])
	行.append("  截图 %s.png" % 名)


func _状态文案() -> String:
	var 主 := 主窗()
	var 状 := 主.get_node_or_null("后端状态") as Label if 主 != null else null
	return 状.text if 状 != null else ""


func _全部后代(父: Node) -> Array:
	var 出: Array = []
	for c in 父.get_children():
		出.append(c)
		出.append_array(_全部后代(c))
	return 出


func _找勾选(窗: Node) -> CheckBox:
	for 件 in _全部后代(窗):
		if 件 is CheckBox:
			return 件 as CheckBox
	return null


func _找钮(窗: Node, 文字: String) -> Control:
	for 件 in _全部后代(窗):
		if 件 is Button and (件 as Button).text == 文字:
			return 件 as Control
	return null


func _钮文字(窗: Node) -> String:
	var 出 := ""
	for 件 in _全部后代(窗):
		if 件 is Button:
			出 += String((件 as Button).text) + "/"
	return 出


func 导师件(页: Control, 索引: int, 尾: String) -> Control:
	return 页.get_node_or_null("导师面板/导师容器/导师_%d/%s" % [索引, 尾]) as Control


## 向控件中心送鼠标事件。`root.push_input` 走的是真输入派发 ⇒ hover/点击都会被 Control 收到
## （实测：motion 先送、press/release 后送，`gui_input` 与 `mouse_entered` 都会触发）。
func _点(件: Control) -> Vector2:
	var 盒 := 件.get_global_rect()
	return 盒.position + 盒.size / 2.0


func _送悬停(件: Control) -> void:
	_送移动(_点(件))


## 合成移动事件走 `root.push_input`。三条实测口径（见 `开发工具/探针_合成输入.gd`
## → `测试/截图/合成输入探针.txt`）：
##   ① `push_input` **既**触发 `mouse_entered/exited`（pick 段）**又**触发 `Node._input`；
##   ② `Input.parse_input_event` 只触发 `_input`，**不触发 hover** ⇒ 用它悬停会"提示浮不出来"；
##   ③ 两种都不更新 `get_local_mouse_position()/get_global_mouse_position()` ——
##      那两个读的是操作系统真实光标。所以提示框的跟随必须由 `_input` 用**事件自带坐标**算
##      （`文字提示框.gd` 就是这么写的），量具这边也用 `_点(件)` 反推期望落点。
func _送移动(点: Vector2) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 点
	移.global_position = 点
	root.push_input(移)


func _送点击(件: Control) -> void:
	var 点 := _点(件)
	var 移 := InputEventMouseMotion.new()
	移.position = 点
	移.global_position = 点
	root.push_input(移)
	for 按 in [true, false]:
		var 键 := InputEventMouseButton.new()
		键.position = 点
		键.global_position = 点
		键.button_index = MOUSE_BUTTON_LEFT
		键.pressed = 按
		root.push_input(键)


## ① 素材侧：气泡件的 texture 必须是 AnimatedTexture、3 帧。
##    （Godot 4.7 的 AnimatedTexture **没有 `loop` 属性**：帧号按 `frames` 取模，天然循环。）
func _步查动图素材() -> void:
	var 页 := 页根()
	if 页 == null:
		return
	var 件 := 导师件(页, 0, "气泡") as TextureRect
	if 件 == null:
		_错("取不到 导师_0/气泡")
		return
	var 动图 := 件.texture as AnimatedTexture
	if 动图 == null:
		_错("气泡 texture 不是 AnimatedTexture（原版气泡是会动的 MovieClip）")
		return
	if 动图.frames != 3:
		_错("气泡帧数=%d，应为 3（原版 29 帧里只有帧 1/10/20 三张不同图）" % 动图.frames)
	var 时长 := 动图.get_frame_duration(0)
	if 时长 > 0.5:
		_错("气泡每态 %.2fs，原版每态约 0.375s（24fps×9 帧）⇒ 看起来像不动" % 时长)
	if not 件.visible:
		_错("当前位（导师_0）的气泡初值没显（onSpirit_lightNpc:149-158 只显当前位）")
	_点前泡显 = 件.visible
	# 基类的抓图步会把动图 `speed_scale=0` 冻住（像素对证要定帧）⇒ 这里解冻，本探针判的是"会不会动"。
	动图.speed_scale = 1.0
	行.append("  气泡素材        AnimatedTexture frames=%d 每态=%.3fs speed=%s（帧号取模=循环），当前位已显 √"
			% [动图.frames, 时长, 动图.speed_scale])
	等待 = 2


## 悬停黄框**防闪**断言：鼠标停住不动，连采 8 帧，`悬停框.visible` 必须恒为 true。
## 用户报"黄框一闪一闪"就是这里 —— 原版 `TeacherCell:53,71` 把 `_overSkin`/`_paoPao` 的
## `mouseEnabled/mouseChildren` 全设 false；Godot 侧若这两件吃鼠标，显示出来的 57×57 框会
## 盖住头像 ⇒ hover 归属在 头像↔悬停框 之间每帧来回踢（`Viewport.update_gui()` 每帧重算 hover，
## 鼠标不动也照闪）。
var _悬停采样: Array[int] = []


func _步采悬停() -> void:
	var 页 := 页根()
	if 页 == null:
		return
	var 像 := 导师件(页, 召唤位, "头像") as Control
	var 框 := 导师件(页, 召唤位, "悬停框")
	# 真人的手不会绝对静止：每帧在头像中心抖 ±1px 再采。
	# 只送一次静态 motion 是复现不出"一闪一闪"的（实测静态 40 帧恒显），
	# 因为 hover 归属只在**位置变化**时重算 ⇒ 抖动才把 头像↔悬停框 的互相抢焦点暴露出来。
	var 抖 := Vector2(_悬停采样.size() % 3 - 1, _悬停采样.size() % 2)
	var 移 := InputEventMouseMotion.new()
	移.position = _点(像) + 抖
	移.global_position = _点(像) + 抖
	root.push_input(移)
	_悬停采样.append(1 if (框 != null and 框.visible) else 0)


func _步判闪() -> void:
	if _悬停采样.is_empty():
		_错("没采到悬停样本")
		return
	var 页 := 页根()
	var 框 := 导师件(页, 召唤位, "悬停框")
	var 泡 := 导师件(页, 召唤位, "气泡")
	var 串 := ""
	for v in _悬停采样:
		串 += "%d" % v
	var 恒 := true
	for v in _悬停采样:
		if v != _悬停采样[0]:
			恒 = false
	if not 恒:
		var 说 := "鼠标不动时悬停框在闪：%d 帧采样=%s" % [_悬停采样.size(), 串]
		说 += "（悬停框 mouse_filter=%d 气泡 mouse_filter=%d，原版 :53,71 两件都 mouseEnabled=false）" % [
				框.mouse_filter if 框 != null else -1, 泡.mouse_filter if 泡 != null else -1]
		_错(说)
		return
	if _悬停采样[0] != 1:
		_错("%d 帧采样=%s ⇒ 悬停后黄框根本没留住" % [_悬停采样.size(), 串])
		return
	行.append("  悬停不闪        鼠标不动连采 %d 帧 %s（恒显；悬停框 mf=%d 气泡 mf=%d）√"
			% [_悬停采样.size(), 串, 框.mouse_filter, 泡.mouse_filter if 泡 != null else -1])
	# 移出后必须恒隐（outHandler）
	var 像 := 导师件(页, 召唤位, "头像") as Control
	_送点开(像)
	等待 = 2


## 把鼠标挪开（头像右下 200px，落在导师条空白处）⇒ 触发 `outHandler:96-99`。
func _送点开(像: Control) -> void:
	var 点 := _点(像) + Vector2(200, 200)
	var 移 := InputEventMouseMotion.new()
	移.position = 点
	移.global_position = 点
	root.push_input(移)


var _移出采样: Array[int] = []


func _步采移出() -> void:
	var 页 := 页根()
	var 框 := 导师件(页, 召唤位, "悬停框")
	_移出采样.append(1 if (框 != null and 框.visible) else 0)


func _步判移出() -> void:
	var 串 := ""
	for v in _移出采样:
		串 += "%d" % v
	if _移出采样.is_empty() or _移出采样[0] != 0:
		_错("鼠标移开后黄框还显着（采样=%s，outHandler 没生效）" % 串)
		return
	行.append("  移开收框        鼠标挪走后连采 %d 帧 %s（恒隐）√" % [_移出采样.size(), 串])


## 悬停：`overHandler:91-95` 显 YellowBorder。测的是**导师_3（自来也）**——
## 全 DARK 态里只有这一位带召唤钮、头像仍可点（`lightTeacher:189` `mouseEnabled = zhaoHuanBtn.visible`），
## 其余四位的头像是 `IGNORE`，悬停本就不该出框（那才是原版）。
func _步悬停() -> void:
	var 页 := 页根()
	if 页 == null:
		return
	var 像 := 导师件(页, 召唤位, "头像") as Control
	if 像 == null:
		_错("取不到 导师_%d/头像" % 召唤位)
		return
	if 像.mouse_filter != Control.MOUSE_FILTER_STOP:
		_错("导师_%d/头像 mouse_filter=%d，召唤位该可点" % [召唤位, 像.mouse_filter])
	_送悬停(像)
	等待 = 2
	var 框 := 导师件(页, 召唤位, "悬停框")
	if 框 == null or not 框.visible:
		_错("悬停后 导师_%d/悬停框 没显（TeacherCell:91-95 overHandler）" % 召唤位)
	else:
		行.append("  悬停黄框        导师_%d/悬停框 visible=true √" % 召唤位)
	# 反证：灰位（导师_0）不可点，悬停也不该出框
	var 灰 := 导师件(页, 0, "头像") as Control
	var 灰框 := 导师件(页, 0, "悬停框")
	if 灰 != null and 灰.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_错("灰位 导师_0/头像 mouse_filter=%d，应为 IGNORE（lightTeacher(false) 关鼠标）" % 灰.mouse_filter)
	if 灰框 != null and 灰框.visible:
		_错("灰位 导师_0 的悬停框不该显（头像根本收不到 hover）")


## ② 点头像 = 走召唤（`clickTeacherHandler:131-142`：召唤钮可见时 `zhaoHuanHandler(null)`），
##    弹出的是**带勾选框的 MDialog**，不是直接发请求。
func _步点击() -> void:
	var 页 := 页根()
	if 页 == null:
		return
	var 像 := 导师件(页, 召唤位, "头像") as Control
	if 像 == null:
		_错("取不到 导师_%d/头像" % 召唤位)
		return
	_送点击(像)
	等待 = 3
	var 窗 := 场景.find_child("召唤确认框", true, false) as Control
	if 窗 == null:
		_错("点了召唤位的头像，没弹出「召唤确认框」（原版 zhaoHuanHandler→showCheckBoxDialog）")
		return
	var 文 := ""
	for 件 in _全部后代(窗):
		if 件 is RichTextLabel:
			文 = (件 as RichTextLabel).text
	行.append("  点头像出弹窗    「%s」" % 文.replace("\n", " "))
	if not 文.contains("400元宝") or not 文.contains("自来也"):
		_错("弹窗正文缺实参（应含「400元宝」「自来也」，取自 数据/意志.json + 数据/NPC.json）：%s" % 文)
	var 勾 := _找勾选(窗)
	if 勾 == null:
		_错("弹窗里没有 CheckBox（原版 showCheckBoxDialog 第 1 参 true）")
	elif not 勾.button_pressed:
		_错("勾选框初值没勾上（原版 `TeacherCell:155` 第 2 个实参 true ⇒ 默认勾「今日不再提示」）")
	else:
		行.append("  勾选初值        「%s」已勾 √" % 勾.text)
	var 钮 := _钮文字(窗)
	行.append("  弹窗钮          %s（原版 确定 x=77 / 取消 x=186）" % 钮)
	_弹窗 = 窗
	# ⚠️ 这里**不能**截图：弹窗是本帧 input 处理时才 add_child 的，还没画过一帧，
	#    裁到的是上一帧 ⇒ 交给下一步 `_步照弹窗`（隔 3 帧）拍。


## 点「取消」⇒ `handler(null)`，`sureToZhaoHuan:81-85` 直接 return：不召唤、窗关掉。
## 隔帧再拍弹窗（同上一条门里"输入步与验步隔 3 帧"的理由）。
func _步照弹窗() -> void:
	if _弹窗 == null or not is_instance_valid(_弹窗):
		_错("弹窗在拍照前就没了")
		return
	var 内 := _弹窗.get_child(1) if _弹窗.get_child_count() > 1 else null
	行.append("  弹窗矩形        主体=%s 高=%s" % [内.get_global_rect() if 内 else "<无>",
			内.size.y if 内 else -1])
	整窗照("召唤弹窗")
	等待 = 2


func _步点取消() -> void:
	if _弹窗 == null or not is_instance_valid(_弹窗):
		return
	_送点击(_找钮(_弹窗, "取消"))
	等待 = 3


func _步验取消() -> void:
	if is_instance_valid(_弹窗):
		_错("点「取消」后弹窗还在")
		return
	var 状 := _状态文案()
	if 状.contains("召唤"):
		_错("点取消却发了召唤（原版 handler(null) 直接 return）：状态=「%s」" % 状)
		行.append("  取消不召唤      状态仍「%s」√" % 状)
	else:
		行.append("  取消不召唤      弹窗已关、状态未变「%s」√" % 状)


## 直接点「召唤」钮本体（`TeacherCell:49` 也给钮挂了 CLICK）⇒ 同一个弹窗；
## 这次点「确定」⇒ `handler(true)` ⇒ `isPrompt=false` + 发请求（本工程无该协议 ⇒ 回执文案）。
func _步点召唤钮() -> void:
	var 页 := 页根()
	var 召 := 导师件(页, 召唤位, "召唤") as Control
	if 召 == null:
		_错("取不到 导师_%d/召唤" % 召唤位)
		return
	_送点击(召)
	等待 = 3
	_弹窗 = 场景.find_child("召唤确认框", true, false) as Control
	if _弹窗 == null:
		_错("点「召唤」钮没弹窗（TeacherCell:49 钮自己也挂了 CLICK→zhaoHuanHandler）")


func _步点确定() -> void:
	if _弹窗 == null or not is_instance_valid(_弹窗):
		return
	_送点击(_找钮(_弹窗, "确定"))
	等待 = 3


func _步验确定() -> void:
	if is_instance_valid(_弹窗):
		_错("点「确定」后弹窗还在")
		return
	var 状 := _状态文案()
	# 2026-10-19（意志完善计划阶段零）：#63 接协议后按 AS3
	# `YiZhiManager.zhaoHuanTeacher:240-245` 走**元宝余额判** —— 离线 `cash` 恒 0 < 400
	# ⇒ 该走「元宝不足」那一支。**这才是原版行为**（旧断言期望的「要在服务端结算」
	#   是 #63 之前"不判余额"的偏离态，见 `真值/窗口/意志.md` §4.3 第三条）。
	if not 状.contains("元宝不足"):
		_错("点确定后状态=「%s」，应有「很抱歉，您的元宝不足！」（离线 cash=0<400，AS3 余额判）" % 状)
		return
	行.append("  确定召唤        状态「%s」√（AS3 余额判；离线 cash=0 ⇒ 挡在发协议之前）" % 状)


## 第二分支：给会话灌 999 元宝（**只改内存、不落盘**）⇒ 余额够 ⇒ 走 `spirit_summon`（action1）
## ⇒ 离线 ⇒ 诚实话「召唤导师要在服务端结算（离线不模拟）」。
## 此时 `_要提示` 已被上一次「确定」置 false（`TeacherCell:81-89` 的回写）⇒ 再点召唤钮
## **不再弹勾选窗**、直接发（照 AS3 `sureToZhaoHuan(true)` 那一支）。
func _步充元宝() -> void:
	var 会话: Node = 窗口._session
	if 会话 == null:
		_错("取不到 _session")
		return
	var 态: Dictionary = 会话.player_stats
	态["cash"] = 999
	行.append("  灌元宝          会话 cash=999（只改内存）")


func _步再点召唤钮() -> void:
	var 页 := 页根()
	var 召 := 导师件(页, 召唤位, "召唤") as Control
	if 召 == null:
		_错("取不到 导师_%d/召唤" % 召唤位)
		return
	_送点击(召)
	等待 = 3


func _步验再召唤() -> void:
	var 状 := _状态文案()
	if not 状.contains("召唤导师") or not 状.contains("服务端"):
		_错("灌了元宝再召唤，状态=「%s」，应有「召唤导师要在服务端结算（离线不模拟）」" % 状)
		return
	行.append("  再召唤          状态「%s」√（余额够 ⇒ 发 action1；离线 ⇒ 诚实话）" % 状)


## 把鼠标从召唤钮上挪开（下面「没人悬停却显示着提示」那条断言要求鼠标不在任何提示宿主上；
## 再召唤那一步点完鼠标还停在召唤钮上 ⇒ 必须先挪走，否则召唤3 的提示会一直亮着）。
func _步挪开鼠标() -> void:
	var 页 := 页根()
	if 页 == null:
		return
	_送移动(页.get_global_position() + Vector2(300, 300))
	等待 = 3


## 连拍气泡区域图（每张之间 等待=12 帧；原版每态 0.375s ≈ 23 帧@60fps ⇒ 6 连拍必然跨帧）。
## 同时记 `AnimatedTexture.current_frame`：帧号在动 = 引擎在播；画面哈希也在变 = 真的画出来了。
func _步气泡快照() -> void:
	var 页 := 页根()
	if 页 == null:
		return
	var 件 := 导师件(页, 0, "气泡")
	if 件 == null:
		_错("快照缺气泡件")
		return
	var 动图 := 件.texture as AnimatedTexture
	var 图像 := root.get_texture().get_image()
	var 盒 := 件.get_global_rect()
	var 起 := Vector2i(int(盒.position.x), int(盒.position.y))
	var 尺 := Vector2i(int(盒.size.x), int(盒.size.y))
	尺.x = clampi(尺.x, 1, 图像.get_width() - 起.x)
	尺.y = clampi(尺.y, 1, 图像.get_height() - 起.y)
	var 区 := 图像.get_region(Rect2i(起, 尺))
	区.save_png("%s/气泡_%d.png" % [出目录, _快照数组.size()])
	快照存(区, 动图.current_frame if 动图 != null else -1)


func 快照存(区: Image, 帧号: int) -> void:
	_快照数组.append(区)
	_帧号数组.append(帧号)
	行.append("  气泡快照 %d      current_frame=%d %s/气泡_%d.png（%dx%d）"
			% [_快照数组.size() - 1, 帧号, 出目录, _快照数组.size() - 1,
				区.get_width(), 区.get_height()])
	等待 = 12


## 6 张快照里必须出现 ≥2 个不同帧号 **且** ≥2 种不同画面，否则气泡根本没在播。
func _步比动图() -> void:
	if _快照数组.size() < 4:
		_错("气泡快照不足 4 张（%d）" % _快照数组.size())
		return
	var 种类 := {}
	for i in _快照数组.size():
		种类[_散列(_快照数组[i])] = true
	var 帧集 := {}
	for n in _帧号数组:
		if n >= 0:
			帧集[n] = true
	if 帧集.size() < 2:
		_错("6 连拍 current_frame 一直是 %s ⇒ AnimatedTexture 没在推进" % str(_帧号数组))
		return
	if 种类.size() < 2:
		_错("气泡 6 连拍画面完全相同 ⇒ 帧号在动但没画出来（visible/遮挡/尺寸问题）")
		return
	行.append("  气泡动画        current_frame 走过 %s，%d 张快照 %d 种画面 √（点点点在动）"
			% [str(帧集.keys()), _快照数组.size(), 种类.size()])
	var 主 := 主窗()
	if 主 != null:
		var 图像 := root.get_texture().get_image()
		var 起 := Vector2i(int(主.get_global_position().x), int(主.get_global_position().y))
		var 尺 := Vector2i(int(主.size.x), int(主.size.y))
		尺.x = clampi(尺.x, 1, 图像.get_width() - 起.x)
		尺.y = clampi(尺.y, 1, 图像.get_height() - 起.y)
		图像.get_region(Rect2i(起, 尺)).save_png("%s/整窗_交互后.png" % 出目录)
		行.append("  截图            %s/整窗_交互后.png" % 出目录)


func _散列(图: Image) -> String:
	var 尺 := 图.get_size()
	var 总 := 0
	for y in range(0, 尺.y, 2):
		for x in range(0, 尺.x, 2):
			var 色 := 图.get_pixel(x, y)
			总 = (总 * 31 + int(色.r * 255) + int(色.g * 19) + int(色.b * 7)
					+ int(色.a * 3)) & 0x7fffffff
	return "%d-%d-%d" % [尺.x, 尺.y, 总]


# ==================== 三、悬浮提示（MToolTipText）====================

## 提示节点名 = `文字提示_<名>`，由 `功能窗口._挂文字提示` 挂在**页面根**下。
func _提示(页: Control, 名: String) -> Control:
	return 页.get_node_or_null("文字提示_" + 名) as Control


## 从语言表原文取文案（被测代码不参与）：`数据/界面/意志_文案.json` 就是
## `en_US$message_properties.as` 抽出来的那 28 键。
func _表(键: String) -> String:
	var 表: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://数据/界面/意志_文案.json"))
	return String(表.get(键, ""))


func _导师表(索引: int) -> Dictionary:
	var 常: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://数据/意志.json"))
	var 得: Dictionary = (常.get("common", {}) as Dictionary).get("gain", {})
	return 得.get("NPC%d" % 索引, {}) as Dictionary


## **版式期望从 AS3 公式现算**，不从被测代码借：
##   Flash 宋体行盒 15、leading 5 ⇒ `textHeight = 15n + 5(n−1) = 20n − 5`
##   `MToolTipText:91`  `tf.height = textHeight + 4`
##   `MToolTipText:90`  `tf.width  = textWidth + 6`，而 `textWidth = 墨迹宽 + 4`（TextField 左右各 2px 内槽）
##   `MToolTipText:61-62` `back.width = tf.width + 16 − 5`、`back.height = tf.height + 16 − (n>1 ? 3 : 7)`
## ⇒ `底高 = 20n − 5 + 4 + 16 − (3|7)`：n=1 → **28**、n=2 → **52**；`底宽 = 墨迹宽 + 21`。
## 行数 n 取**语言表里的 `<br>` 个数**（不靠 Godot 折行）；这三串都远窄于 MAX_WIDTH=354，
## 所以顺带断言「墨迹宽 < 354」，把"没折行"这个前提钉住。
func _提示期望(纯文: String, 行数: int, 字: Font, 号: int) -> Vector2:
	var 墨迹 := 0.0
	for 段 in 纯文.split("\n"):
		墨迹 = maxf(墨迹, 字.get_string_size(段, HORIZONTAL_ALIGNMENT_LEFT, -1, 号).x)
	if 墨迹 >= 354.0:
		_错("提示串宽 %.1f ≥ MAX_WIDTH 354 ⇒ 会折行，行数不再是 %d，得按折行重算" % [墨迹, 行数])
	var 盒宽 := minf(354.0, 墨迹 + 4.0) + 6.0
	return Vector2(盒宽 + 16.0 - 5.0,
			(20.0 * 行数 - 5.0 + 4.0) + 16.0 - (3.0 if 行数 > 1 else 7.0))


## ① 节点存在性 + 默认可见性。原版 `TeacherCell:74-75` 的提示是**构造时就 create**、
## 但 `MToolTip.as:94-106` 只在 ROLL_OVER 才 `addChild` 进 stage ⇒ 没悬停时页面上根本不该有提示。
func _步查提示节点() -> void:
	var 页 := 页根()
	if 页 == null:
		return
	var 该有 := ["导师0", "导师1", "导师2", "导师3", "导师4", "召唤%d" % 召唤位, "打开背包"]
	var 缺 := ""
	var 亮着 := ""
	for 名 in 该有:
		var 框 := _提示(页, 名)
		if 框 == null:
			缺 += 名 + " "
			continue
		if 框.visible:
			亮着 += 名 + " "
	if 缺 != "":
		_错("提示节点缺失：%s（应有 %d 枚）" % [缺, 该有.size()])
	if 亮着 != "":
		_错("没人悬停却显示着提示：%s（原版悬停才 addChild 到 stage）" % 亮着)
	if 缺 == "" and 亮着 == "":
		行.append("  提示节点        %d 枚都在、未悬停全隐 √" % 该有.size())
	# 不该存在的：灰位不该有召唤提示（`setZhaoHuanButtonVisible` 只在钮可见时 new）
	for k in 5:
		if k != 召唤位 and _提示(页, "召唤%d" % k) != null:
			_错("导师_%d 没召唤钮却挂了召唤提示" % k)
	等待 = 1


## ② 逐枚量版式（底尺寸 = AS3 公式、文字偏移 = tf.x=tf.y=7）。
func _步查提示版式() -> void:
	var 页 := 页根()
	if 页 == null:
		return
	var 查 := {
		"导师0": [2, _表("YIZHI_STUDY_FEI_YONG")],
		"导师3": [2, _表("YIZHI_STUDY_FEI_YONG")],
		"召唤%d" % 召唤位: [2, _表("YIZHI_ZHAN_HUAN_NPC_TIP")],
		"打开背包": [1, _表("YIZHI_OPEN_PACK_TOOLTIP")],
	}
	for 名 in 查:
		var 框 := _提示(页, 名)
		if 框 == null:
			continue
		var 文: RichTextLabel = 框.get_node("文字") as RichTextLabel
		var 底: TextureRect = 框.get_node("底") as TextureRect
		var 字: Font = 文.get_theme_font("normal_font")
		var 号: int = 文.get_theme_font_size("normal_font_size")
		var 纯 := 文.get_parsed_text()
		var 想 := _提示期望(纯, int(查[名][0]), 字, 号)
		var 偏 := (框.size - 想).abs()
		var 对 := 偏.x < 0.7 and 偏.y < 0.7 and 底.size == 想 and 文.position == Vector2(7, 7)
		# 串里的实参必须来自数据表，不是写死的字
		if 名 == "打开背包":
			对 = 对 and 纯 == String(查[名][1])
		var 召费 := int((_导师表(召唤位).get("special", {}) as Dictionary).get("needYuanBao", 0))
		if 名 == "召唤%d" % 召唤位:
			# 本轮探针在前面已点过一次「确定」⇒ 次数是 1/99，不是初值 0/99；
			# 断言只钉「总次数 99 + 元宝费来自数据表」，具体次数由 `_步验确定` 那条状态文案判。
			# （总额 99 = 服务端 `SPIRIT_SPECIAL_LIMIT`，2026-10-19 意志完善计划 P1-6 起；
			# 原版客户端写死 20，实机服务端是 99 ⇒ 以服务端为准。）
			对 = 对 and 纯.contains("/99") and 纯.contains("%d元宝" % 召费)
		if 名.begins_with("导师"):
			var 阅 := int(_导师表(int(名.substr(2)) ).get("needYueLi", 0))
			对 = 对 and 纯.contains("学习所需：%d" % 阅)
		有错 = 有错 or not 对
		_行("  提示版式 %-10s 底=%s 想=%s 文位=%s 行=%d「%s」%s" % [名, 框.size, 想, 文.position,
				纯.count("\n") + 1, 纯.replace("\n", "⏎"), "√" if 对 else "!! 错"])
	等待 = 1


## ③ 悬停必须真的浮出来，并且**跟着鼠标走**（`MToolTip.as:104` container MOUSE_MOVE）。
func _步悬停出提示() -> void:
	var 页 := 页根()
	if 页 == null:
		return
	for 对 in [["导师%d" % 召唤位, 导师件(页, 召唤位, "头像")],
			["召唤%d" % 召唤位, 导师件(页, 召唤位, "召唤")],
			["打开背包", 页.get_node_or_null("导师面板/打开背包")]]:
		var 名 := String(对[0])
		var 件 := 对[1] as Control
		var 框 := _提示(页, 名)
		if 件 == null or 框 == null:
			_错("悬停检查缺件：%s（宿主=%s 提示=%s）" % [名, str(件 != null), str(框 != null)])
			continue
		_送悬停(件)
		等待 = 3
		if not 框.visible:
			_错("悬停 %s 后提示没出来（原版 ROLL_OVER → showTip）" % 名)
			continue
		var 鼠 := _点(件) - 页.get_global_position()
		var 落 := 框.position
		# 期望落点 = 鼠标 + (10,20)，再钳进舞台（`MToolTip.setLocation:136-143`）
		# 钳制框 = **组件自己的舞台**（挂载时从 `get_viewport().get_visible_rect()` 拿到的
		# 960×560）换算到页面局部。⚠️ 不能用 `root.get_visible_rect()`：量具基类的
		# `_步撑视口` 为了截全整窗把根视口撑到了 960×580，用它当舞台会少钳 20px。
		var 舞台: Vector2 = ((框.get("_舞台") as Vector2) - 页.get_global_position()).max(Vector2.ZERO)
		var 想 := (鼠 + Vector2(10, 20)).clamp(Vector2.ZERO, 舞台 - 框.size)
		var 合 := (落 - 想).length() < 0.7
		有错 = 有错 or not 合
		_行("  悬停出提示      %-12s 底 %s 位=%s 想=%s（鼠=%s +10/+20 钳进 %s）%s" % [名, 框.size, 落, 想, 鼠, 舞台, "√" if 合 else "!! 错"])
	# ⚠️ 这一步**不截图**：提示框是本帧 pick 段才 `visible=true` 的，
	#   `root.get_texture()` 拿到的是**上一帧**的画面 ⇒ 同帧抓拍必然拍不到（2026-09-28 实测）。
	#   交给后面的 `_步提示连拍`（每枚之间隔 3 帧）。


## 逐枚抓拍当前悬停中的提示：拍完这一枚就把鼠标挪到下一枚的宿主上，隔 3 帧再进本步。
var _拍索引 := -1
var _拍清单: Array = []


func _步提示连拍() -> void:
	var 页 := 页根()
	if 页 == null:
		return
	if _拍索引 < 0:
		_拍清单 = [["导师%d" % 召唤位, 导师件(页, 召唤位, "头像")],
				["召唤%d" % 召唤位, 导师件(页, 召唤位, "召唤")],
				["打开背包", 页.get_node_or_null("导师面板/打开背包")]]
		_拍索引 = 0
		_送悬停(_拍清单[0][1] as Control)
		等待 = 3
		return
	var 项 = _拍清单[_拍索引]
	var 框 := _提示(页, String(项[0]))
	var 名 := String(项[0])
	整窗照("提示_" + 名)
	root.get_texture().get_image().save_png("%s/提示全画布_%s.png" % [出目录, 名])
	# 画没画出来用最硬的办法判：把提示矩形裁出来数**非背景像素**
	var 图像 := root.get_texture().get_image()
	var 起 := Vector2i(int(页.get_global_position().x + 框.position.x),
			int(页.get_global_position().y + 框.position.y))
	var 尺 := Vector2i(int(框.size.x), int(框.size.y))
	尺.x = clampi(尺.x, 1, 图像.get_width() - 起.x)
	尺.y = clampi(尺.y, 1, 图像.get_height() - 起.y)
	var 区 := 图像.get_region(Rect2i(起, 尺))
	var 暗 := 0
	var 亮 := 0
	for y in range(0, 区.get_height(), 2):
		for x in range(0, 区.get_width(), 2):
			var 色 := 区.get_pixel(x, y)
			if 色.v < 0.30:
				暗 += 1		# 提示框底是深色半透（ToolTip_background）
			if 色.v > 0.75:
				亮 += 1		# 白/黄文字
	var 判 := "√" if (暗 > 0 and 亮 > 0) else "!! 没画出来（暗 %d 亮 %d）" % [暗, 亮]
	有错 = 有错 or not (暗 > 0 and 亮 > 0)
	_行("  提示入画 %-10s 矩形 %s@%s 暗底采样 %d 文字采样 %d %s" % [名, 尺, 起, 暗, 亮, 判])
	_拍索引 += 1
	if _拍索引 >= _拍清单.size():
		_拍索引 = -1
		return
	_送悬停(_拍清单[_拍索引][1] as Control)
	等待 = 3


## 鼠标在宿主内挪 18×7 px，提示位必须同步挪同样的量（跟随，而非钉死在首次落点）。
func _步查跟随() -> void:
	var 页 := 页根()
	if 页 == null:
		return
	var 件 := 导师件(页, 召唤位, "头像") as Control
	var 框 := _提示(页, "导师%d" % 召唤位)
	if 件 == null or 框 == null:
		return
	if not 框.visible:		# 上一步的鼠标停在别的宿主上 ⇒ 先悬回本宿主再量位移
		_送悬停(件)
		等待 = 3
		return
	var 前 := 框.position
	# 往**左上**挪 (18,7)：头像在窗口下沿，其提示本来就被钳在画布底边（+y 会被钳住，
	# 量不出跟随），往左上挪才既留在头像内、又不撞钳制。
	var 想 := _点(件) + Vector2(18, -7)
	_送移动(想)
	等待 = 3
	var 后 := 框.position
	var 舞台2: Vector2 = ((框.get("_舞台") as Vector2) - 页.get_global_position()).max(Vector2.ZERO)
	var 裸 := 想 - 页.get_global_position() + Vector2(10, 20)	# 未钳制的落点
	var 落 := 裸.clamp(Vector2.ZERO, 舞台2 - 框.size)
	# ⚠️ 头像贴在窗口下沿，其提示**本来就被舞台钳住底边**（原版同理：`setLocation` 钳
	#   `STAGE_HEIGHT − height`）⇒ 纵向位移量不出来，只有横向能量。所以判两件事：
	#   ① 落点必须等于「鼠标 +(10,20) 再钳进舞台」（含被钳住的情形）；
	#   ② 没被钳住的那个轴必须真的挪了 18px。
	var 钳y: bool = 裸.y > 舞台2.y - 框.size.y
	var 对y := (后.y - 前.y) == (0.0 if 钳y else -7.0)
	if (后 - 落).length() > 0.7 or abs((后.x - 前.x) - 18.0) > 0.7 or not 对y:
		_错("提示没跟鼠标：挪 (18,−7) 后位移=%s 落点=%s 想=%s（裸=%s 钳y=%s 舞台矩=%s）"
				% [后 - 前, 后, 落, 裸, str(钳y), 舞台2])
	else:
		行.append("  提示跟鼠标      挪 (18,−7) ⇒ 位移 %s 落点 %s=想（y 被舞台钳住=%s）√"
				% [后 - 前, 后, str(钳y)])
	整窗照("提示_跟随后")


## 移开必须收（`MToolTip.as:62-66 __onMouseRollOut → closeTip`）。
func _步移出收提示() -> void:
	var 页 := 页根()
	if 页 == null:
		return
	var 件 := 导师件(页, 召唤位, "头像") as Control
	_送点开(件)
	等待 = 3
	var 还亮 := ""
	for 名 in ["导师%d" % 召唤位, "召唤%d" % 召唤位, "打开背包"]:
		var 框 := _提示(页, 名)
		if 框 != null and 框.visible:
			还亮 += 名 + " "
	if 还亮 != "":
		_错("鼠标移开后提示还亮着：%s（outHandler/closeTip 没生效）" % 还亮)
	else:
		行.append("  移开收提示      三枚全隐 √")
