extends RefCounted

## 进度条补间的**唯一一道口子**。真值：`真值/窗口/进度条补间.md`
## （`uifl/base/controls/MBar.as:128-175` + `gs/TweenLite.as:28/95-117/199-202`）。
##
## 原版三件事，缺一条就不是原版的动作：
##   1. **同数据整条早退**（`MBar.as:130-133`）——重复渲染不许重启补间，否则挂机每帧刷一次
##      ⇒ 条永远在爬、数字却不动；
##   2. **新补间杀掉同一根条上的旧补间**（TweenLite overwrite 缺省 = 1）并从**当前视觉位置**
##      重新起算 0.5 秒 —— `MBar extends Sprite`，没有 `MComponent` 那套自动清理；
##   3. **0.5s 二次缓出**（`easeOut = -c·u·(u−2)+b` ≡ `TRANS_QUAD` + `EASE_OUT`）。
##
## ⚠ 只管**比例与补间**，不管文案：各点文案早有各自的分支（百分比 / `x/y` / `?/?`），
##   而且各有已登记的偏离（如目标条"上限 0 画空条"）。调用点算文案一律**按数据算、
##   不许读 `条.value`** —— 读了数字会跟着补间爬（§② 第 5 步的反面）。
##
## ⚠ 三种曲线别混用：`MBar` 族 = 本件；底栏自己血/蓝 = `MMaskSprite` 的 **0.5s 线性**
##   （用 `线性补间()`）；地图头顶血条 `CommonHpBar` **不动**，别接本件。

const 时长 := 0.5
## 整页重建（`功能窗口._render_page`）时挂在**内容根**上的一张表：
## 「内容根下的相对路径 → 重建前那根条停在哪」。页一拆条就没了，新节点上没有任何补间缓存，
## 这是它唯一能和上一帧接上的线索 —— 没有它，条会从 `.tscn` 烘的默认值（经验条 0、生命条 100）
## 重新爬一遍（用户 2026-10-31 报「60 变 65 却从头扫到尾」）。ASCII 键：`set_meta` 只认标识符。
const 重建快照键 := "barSeed"
## 整页重建的这一趟是**换页/换页签**（不是同一页的回帧重建）：条一律**直落真值**。
## 只靠 `重建快照键` 接不住这一档 —— 换走那一页时，新页的条还停在 `.tscn` 烘的默认值（或
## 根本不在快照里），拿它当起点就是从 0 扫到当前值（用户 2026-10-31 报「每次切换面板，
## 数值轴都会从 0→当前值；切换后是多少就该是多少」）。同一页里的数值变化仍走补间。
const 直落键 := "barSnapNew"
## 存在条自己身上的两条 meta：上一支补间、上一次灌进去的数据。
## ⚠ 键名**必须以字母开头**：Godot 的 `set_meta` 走 `String::is_valid_identifier`，
## 中文或 `_` 开头一律 `Invalid metadata identifier` ⇒ **早退缓存根本存不进去**（每帧重启补间、
## 还往控制台刷 error）。这条是门里第一条红抓出来的（error 不打断执行 ⇒ 只写行为腿就是假绿）。
const 补间键 := "tweenBar"
const 数据键 := "tweenBarData"


## 通用：把 `目标.属性` 用 0.5s **二次缓出**推到 `终值`。
## `数据` 是这根条这次渲染的**入参**（一般 `[当前, 上限]`）—— 与上次完全相同则整条早退。
static func 补间(目标: Node, 属性: String, 终值: float, 数据: Variant) -> void:
	_起(目标, 数据, 终值, 属性, Tween.TRANS_QUAD)


## `MMaskSprite` 那一族（底栏自己血/蓝）：**线性**、同样 0.5s、同样"从当前值重新起算"。
static func 线性补间(目标: Node, 属性: String, 终值: float, 数据: Variant) -> void:
	_起(目标, 数据, 终值, 属性, Tween.TRANS_LINEAR)


static func _起(目标: Node, 数据: Variant, 终值: float, 属性: String, 曲线: int) -> void:
	if 目标 == null or not is_instance_valid(目标):
		return
	# §② 第 0 步：同数据早退（比较的是**入参**，不是条的当前值 —— 条正在半路上）
	if 目标.has_meta(数据键) and _相同(目标.get_meta(数据键), 数据):
		return
	目标.set_meta(数据键, 数据)
	# 不在树上的节点建不了 Tween（Godot 直接报错）—— 那就没有"上一次位置"可续，直给终值。
	if not 目标.is_inside_tree():
		_直写(目标, 属性, 终值)
		return
	# 整页重建出来的**新节点**（没有补间缓存）：
	#   · 同一页重建 ⇒ 接回重建前停的位置，补间才是「60→65」；
	#   · 换页/换页签（`直落键`）或这一页新长出来的条 ⇒ **直接落到终值**，不许从 `.tscn`
	#     烘的默认值扫一遍（用户 2026-10-31：「切换后，数值轴是多少数值就是多少数值」）。
	var 重建态 := 0
	if 属性 == "value" and not 目标.has_meta(补间键):
		重建态 = _接重建前的值(目标)
	if 重建态 == 2 or 重建态 == 3:
		_直写(目标, 属性, 终值)
		return
	var 旧 := (目标.get_meta(补间键) as Tween) if 目标.has_meta(补间键) else null
	if 旧 != null and 旧.is_valid():
		旧.kill()
	var 新 := 目标.create_tween()
	新.set_trans(曲线 as Tween.TransitionType)
	新.set_ease(Tween.EASE_OUT)
	新.tween_property(目标, 属性, 终值, 时长)
	目标.set_meta(补间键, 新)


## `Node.set()` 只认属性名，`"position:x"` 那种路径它吃不下 ⇒ 两种几何各自直写。
static func _直写(目标: Node, 属性: String, 终值: float) -> void:
	if 属性 == "value":
		(目标 as Range).value = 终值
	elif 属性 == "position:x":
		(目标 as Control).position.x = 终值
	else:
		目标.set(属性, 终值)


## 从最近的、带重建标记的祖先（= 整页重建时的内容根）里取回上一次的视觉值。
## 返回三种状态（调用方据此决定补间还是直落）：
##   0 = **不归它管**（常驻条 / 非进度条）⇒ 照旧从条自己当前的位置补间；
##   1 = 接回了快照里的值 ⇒ 从那儿补间（同一页内的数值变化）；
##   2 = 这一趟是**换页**（`直落键`）⇒ 调用方直落，忽略快照；
##   3 = 重建页里**没有这根条的快照**（新长出来的/换到一页没渲染过的）⇒ 调用方直落。
static func _接重建前的值(目标: Node) -> int:
	if not (目标 is ProgressBar or 目标 is TextureProgressBar):
		return 0
	var 根 := 目标.get_parent()
	while 根 != null and not 根.has_meta(重建快照键) and not 根.has_meta(直落键):
		根 = 根.get_parent()
	if 根 == null:
		return 0
	if 根.has_meta(直落键) and bool(根.get_meta(直落键)):
		return 2
	var 表: Variant = 根.get_meta(重建快照键)
	if typeof(表) != TYPE_DICTIONARY:
		return 3
	var 键 := String(目标.get_path()).trim_prefix(String(根.get_path()))
	if not (表 as Dictionary).has(键):
		return 3
	(目标 as Range).value = float((表 as Dictionary)[键])
	return 1


## **不走补间**地把一根条停在 `终值`，同时把第 0 步的缓存作废、杀掉还在跑的旧补间。
## 给"这一档原版本来就不动条"的场合用（如目标条的 `?/?`：`MBar.as:158-161` 写完文案就 `return`）。
## ⚠ 不调这里、直接写 `条.value =` 会留下**半缓存**：缓存里还是上一次的数据，
## 于是"下一次同样的数据"被第 0 步早退吞掉 ⇒ 条永远停在手动写的那个值。
static func 直写(目标: Node, 属性: String, 终值: float) -> void:
	if 目标 == null or not is_instance_valid(目标):
		return
	_直写(目标, 属性, 终值)
	目标.set_meta(数据键, null)
	var 旧 := (目标.get_meta(补间键) as Tween) if 目标.has_meta(补间键) else null
	if 旧 != null and 旧.is_valid():
		旧.kill()


static func _相同(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Array:
		var 甲 := a as Array
		var 乙 := b as Array
		if 甲.size() != 乙.size():
			return false
		for 下标 in 甲.size():
			if not _相同(甲[下标], 乙[下标]):
				return false
		return true
	if a is float or a is int:
		return is_equal_approx(float(a), float(b))
	return a == b


## §② 第 1+2 步：`cur > tot` 先夹到 `tot`（夹完才缓存，早退比的就是夹过的）。
static func 夹过(当前: float, 上限: float) -> float:
	return 当前 if 当前 <= 上限 else 上限


## §② 第 3 步：`MBar` 的比例口径。`上限 <= 0` 时按 `_isShowBar` 分岔：
## 真 ⇒ **满条**（默认，原版语义）；假 ⇒ 空条（`GuwanshoujiInfoPanel.as:82` 那一处，
## 以及本工程已登记的"上限 0 画空条"偏离，如目标信息条）。
static func 比例(当前: float, 上限: float, 上限零当满 := true) -> float:
	if 上限 > 0.0:
		return clampf(夹过(当前, 上限) / 上限, 0.0, 1.0)
	return 1.0 if 上限零当满 else 0.0


## `MBar.as:150` 的滑条几何：填充条与槽同宽、靠 **x** 滑进遮罩（不是压扁宽度）。
## `int()` 是**向零截断** ⇒ 这里用 `floorf` 只在正数区间等价，槽宽本就该是正的。
static func 滑条终位(槽宽: float, 比例值: float, 静止位: float = 0.0) -> float:
	return 静止位 - floorf(槽宽 * (1.0 - 比例值))


## **value 型条**（ProgressBar / TextureProgressBar）一次灌完的公共那段：
## `max_value` 直给、填充走 0.5s 补间、`上限 <= 0` 按 `_isShowBar` 画**满条**。
## 终值取**夹过的当前值**而不是 `比例 × 上限`：后者在 `58/62` 这种数上写成 57.99999…，
## 门里 `int(条.value)` 一比就差 1（`比例()` 是给滑条那一族算 x 用的）。
static func 灌值(条: Range, 当前: float, 上限: float, 数据: Variant) -> void:
	if 条 == null or not is_instance_valid(条):
		return
	条.max_value = maxf(1.0, 上限)
	补间(条, "value", (夹过(当前, 上限) if 上限 > 0.0 else 条.max_value), 数据)


## 同 `灌值`，但**当帧直落**、不起补间；`数据` 仍要记（否则下一次同数据会被第 0 步早退吞掉）。
## 给"换了一组条 / 刚建出来的条"这一档用：原版那四根是**常驻** MBar（`JieYinPanel.as:156-168`），
## 换选中阶只是给同一根条 `setData`；本工程按印拆成了各自一套条（`结印页.tscn`），
## 换印 = 换一根从没写过的条（烘的是 0）⇒ 必须当帧坐到真值，不许从 0 扫过去
## （用户 2026-11-01：「切换后，数值轴是多少数值就是多少数值」）。
static func 直灌(条: Range, 当前: float, 上限: float, 数据: Variant) -> void:
	if 条 == null or not is_instance_valid(条):
		return
	条.max_value = maxf(1.0, 上限)
	_直写(条, "value", (夹过(当前, 上限) if 上限 > 0.0 else 条.max_value))
	var 旧 := (条.get_meta(补间键) as Tween) if 条.has_meta(补间键) else null
	if 旧 != null and 旧.is_valid():
		旧.kill()
	条.set_meta(数据键, 数据)
