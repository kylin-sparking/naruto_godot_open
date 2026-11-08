@tool
extends Node2D

## 打坐时角色身上那圈光环 —— 原版 `Character.tickHealAnimation():2742-2765` 挂的
## `FrameQueueAnimation`，数据是 GameData `Etc.effects.healNew`（`Character.as:2750-2752`）。
##
## ★ 这一圈是**场景里的九个 Sprite2D**（`场景/角色/打坐光环.tscn`，由
##   `开发工具/生成打坐九帧场景.py` 从帧表烘出来），不是运行时 `new()` 出来的 ——
##   这样你在编辑器里打开这张场景就**看得见九帧**：勾上根节点的 `全显`，九帧同时显示，
##   盘没对齐就看得见重影；点中那一帧直接拖，存盘就是游戏里的效果。
##   拖完跑 `开发工具/读回打坐九帧位.py` 把九帧位置与"字面公式"的差打出来对账。
##   ⚠ 重跑生成器会**覆盖**你手拖的结果 ⇒ 先跑对账脚本把差量记下来。
##
## 为什么九帧尺寸互不相同却要逐帧换节点、而不是 `AnimatedTexture`：
##   实测 150×79 ~ 219×199。`AnimatedTexture` 把所有帧叠成一张 texture array，尺寸不齐时
##   它报出的宽高是错的、采样越界在部分机器上直接出**白块**（掉落物金币踩过同样的坑，
##   见 `真值/窗口/掉落物.md` §4）。
##
## 播放节奏照 GameData：**第 0 帧停 12000 毫秒**（常驻的底座光环），1~8 帧各 200 毫秒
##   （一圈"起气"脉冲）⇒ 整圈 13600 毫秒。原版 `Animation.tick():116-165` 一次 tick 只前进一格。
##
## 层序：原版 `adjustLayer()` 两张表（`Character.as:1414`、`:1626`）都把 `healQueueAnimation`
##   排在角色动画**之后**、名字条之前 ⇒ 光环盖身体、被名字压住。挂上去之后
##   `玩家.gd::_刷新打坐光环()` 会把它 `move_child` 到 `Nameplate` 之前。
##
## 摆位（2026-10-13 定案，改之前先读）：每帧的 `position` 就是 AS3
##   `CharacterItem.setOrigin():53-60` 的字面公式 `(−原点x, −原点y)`，**不加任何补偿**。
##   我先后加过两种补偿（拿 `环底距` 钉平、拿 `阵底` 钉平），两次都被用户实机打回 ——
##   那两个地标量的都是**盘底下那团半透明辉光**，不是八卦阵，钉它等于亲手把盘顶走。
##   定案依据（不依赖任何自动地标）：① GameData `healNew` 每帧只有 `origin` 与 `delay`；
##   ② 注册点对齐 + 4 倍放大的肉眼对照（`开发工具/放大看盘位.py`、`数亮条.py`）。
##   ⇒ 要整体挪位置只许用下面的 `水平偏移`/`竖直偏移`（整圈一起走，不动帧间关系）。

const 表路径 := "res://数据/界面/打坐光环.json"

var _帧表: Array = []
var _号 := 0
var _剩毫秒 := 0.0
## ★ 这张场景**被 F6 单独跑**时的标记（判据：自己就是 `current_scene`）。
##   单独跑 = 没有角色、没有相机，而九帧的 position 全是负数 ⇒ 整张特效落在屏幕左上角之外，
##   画面上什么看不见（2026-10-13 用户报"特效没在画面中心 我根本看不到"就是这个）。
##   ⇒ 单独跑时只做一件事：**把整圈挪到屏幕正中**，动画与节奏**原样不动**（用户要的就是
##     "跟游戏里打坐一样按顺序播"，好逐帧比对哪一帧的盘在跳）。挂在角色身上时这条不生效。
##   另外 `全显` 在单独跑时**不被强制关掉** ⇒ 想九帧叠在一起看重的，勾上存盘再 F6 即可。
var _单独跑 := false
## 单独跑时用来居中的取景偏移：九帧内容盒 x∈[−110,109]、y∈[−150,49] ⇒ 内容中心在注册点上方 50，
## 于是把根往下挪 50 就让内容落在屏幕正中。
const 取景偏移 := Vector2(0.0, 50.0)

## 编辑器工具：勾上 ⇒ 九帧同时显示（用来肉眼比对盘有没有重合），并且**不推进动画**。
## 游戏里（跑起来之后）勾上也没意义 ⇒ 运行期忽略它，只显示当前帧。
@export var 全显: bool = false: set = _设全显
## 整圈的手动微调。默认 0 = 逐像素照原版公式。运行期改也立刻生效（`_process` 每帧重摆根节点）。
@export var 水平偏移 := 0.0
@export var 竖直偏移 := 0.0


func _设全显(值: bool) -> void:
	全显 = 值
	if Engine.is_editor_hint():
		# 编辑器里：勾上 = 九张全开（看有没有重影）；取消 = 回到"只开第 0 帧"
		for 号 in _帧数():
			var 点 := _帧节点(号)
			if 点 != null:
				点.visible = 值 or 号 == 0
		return
	_刷可见()


func _帧数() -> int:
	return _帧表.size() if not _帧表.is_empty() else 9


func _ready() -> void:
	# ⚠ `全显` 是给**编辑器对图**用的。忘了关就存进场景 ⇒ 游戏里九张叠一起画（比错位还糟）。
	#   所以挂在角色身上时一律强制关掉；但**这张场景被 F6 单独跑**时反过来强制打开 ——
	#   那时它就是"对图模式"，九帧同显才看得出盘对不对齐（见上面 `_单独跑` 那段）。
	_单独跑 = self == get_tree().current_scene
	if not Engine.is_editor_hint() and not _单独跑:
		全显 = false
	var 读 := FileAccess.open(表路径, FileAccess.READ)
	if 读 == null:
		push_warning("打坐光环：读不到 %s（打坐时身上不会有任何特效）" % 表路径)
		return
	var 表: Variant = JSON.parse_string(读.get_as_text())
	if not (表 is Dictionary):
		push_warning("打坐光环：数据表读不出字典（%s）" % 表路径)
		return
	# ⚠ **播的就是 `帧`（healNew 九帧）** —— 用户 2026-10-13 两次拍板：他自己从原版导的那包
	#   素材就是这九张 `Effect_healNew_0..8.png`。我一度拿"原版 GIF 里脚底圈不动"当证据
	#   判实机播的是另一条 `heal` 六帧并整条换掉 ⇒ 被打回（"那六帧我在 flash 里从没见过"），
	#   已退回并按令删掉那六张图。⇒ 素材条不许再动。
	var 灵: Array = (表 as Dictionary).get("帧", []) as Array
	if 灵.is_empty():
		push_warning("打坐光环：`帧`(healNew 九帧) 是空的 ⇒ 打坐身上不会有特效")
		return
	_帧表 = 灵
	if _帧节点(0) == null:
		push_warning("打坐光环：场景里没有 `第0帧` 这些子节点 ⇒ 重跑 开发工具/生成打坐九帧场景.py")
		return
	if Engine.is_editor_hint():
		# ★ 编辑器里**什么都不动**：可见性、位置全交给用户自己勾/拖。
		#   之前这里也跑 `_落帧(0)`、下面 `_process` 也每帧跑一遍 ⇒ 脚本每帧把
		#   "只亮第 0 帧"和根节点位置写回去，用户手动勾的 visible、手拖的位置当场被覆盖
		#   （用户问"为什么不可以切换可见性呢"就是这个 bug）。
		return
	_落帧(0)
	_剩毫秒 = float(int(_帧表[0].get("停毫秒", 400)))


## 摆根节点。挂在角色身上时 = (0,0) + 用户那两个微调；被 F6 单独跑时挪到屏幕正中（见 `_单独跑`）。
func _摆根() -> void:
	position = Vector2(水平偏移, 竖直偏移)
	if _单独跑:
		position += get_viewport_rect().size * 0.5 + 取景偏移


func _process(秒: float) -> void:
	if Engine.is_editor_hint():
		return		# 编辑器里不推进动画、不改可见性、不挪位置（见 _ready 那条注释）
	if _帧表.is_empty() or 全显:
		_摆根()
		return
	_剩毫秒 -= 秒 * 1000.0
	while _剩毫秒 <= 0.0:
		_号 = (_号 + 1) % _帧表.size()
		_剩毫秒 += float(int(_帧表[_号].get("停毫秒", 200)))
	_落帧(_号)


func _帧节点(号: int) -> Sprite2D:
	return get_node_or_null("第%d帧" % 号) as Sprite2D


## 只显示当前那一帧（`全显` 时九帧都显示）。摆位本身在场景里，不在这里改。
func _刷可见() -> void:
	for 号 in (_帧表.size() if not _帧表.is_empty() else 9):
		var 点 := _帧节点(号)
		if 点 != null:
			点.visible = 全显 or 号 == _号


## 原版 `FrameQueueAnimation.tick(ms)`：当前帧停够时间就前进一格、到尾回到第 0 帧。
func _落帧(号: int) -> void:
	_号 = 号
	_摆根()
	_刷可见()
	var 点 := _帧节点(号)
	if 点 != null and 点.texture == null:
		push_warning("打坐光环：第 %d 帧的贴图没挂上（场景里的 ExtResource 丢了？）" % 号)


## 给门/量具用：当前是第几帧、贴图名、这一帧节点的位置与剩余时长。
func 状态() -> Dictionary:
	if _帧表.is_empty():
		return {"帧数": 0}
	var 点 := _帧节点(_号)
	return {"帧数": _帧表.size(), "当前帧": _号,
			"贴图名": String(点.texture.resource_path).get_file() if 点 != null and 点.texture != null else "",
			"原点": Vector2(int(_帧表[_号].get("原点x", 0)), int(_帧表[_号].get("原点y", 0))),
			"停毫秒": int(_帧表[_号].get("停毫秒", 0)),
			"画布位置": 点.position if 点 != null else Vector2.INF,
			"已上图": 点 != null and 点.texture != null}
