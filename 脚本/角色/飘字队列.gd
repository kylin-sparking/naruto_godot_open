extends Node
class_name 飘字队列

## 每个角色**自己一条**头顶飘字队列 —— 原版就是这么做的，不是我们自造的节流：
##
## · 入列：`Character.as:588-601` / `Monster.as:435-447`
##     `_aryAttriChangeTips.push({tip,num,add,color,noAdd})`，紧跟
##     `while (_aryAttriChangeTips.length > 50) _aryAttriChangeTips.shift();`
##     ⇒ **超过 50 条丢最旧的**（不是丢最新的）。
## · 放出：`Character.as:2591-2598`（怪那侧 `Monster.as:883+` 同款）
##     `if (timeLeftAttriChangeTip > 0) timeLeftAttriChangeTip -= 这一拍毫秒;`
##     `if (timeLeftAttriChangeTip <= 0 && 队列非空) { showFristAttriChangeTip(); timeLeftAttriChangeTip = 400; }`
##     ⇒ **同一个角色最多 0.4 秒出一条**，每条自己的补间长 0.6 秒
##     （`TIME_ATTRI_CHANGE_TIP*3/1000`，`Character.as:78/1277`）⇒ 相邻两条会**部分重叠**，
##     看起来是错开的一串，而不是"来一条立刻砸一条"（我们以前就是立刻砸，连打时满屏叠成一坨）。
##
## 队列里存的是 **Callable**（"到点了你自己去建那条字"），因为怪/人两侧建法不同
## （锚点、朝向、是不是玩家、在不在空中），这里不耦合那些参数；
## 而且**锚点要等到真正放的那一刻再算** —— 原版 `showFristAttriChangeTip()` 就是在
## 放的时候才读 `mobBmdHeight` / `_crtCharHeight`（`Monster.as:921-923`、`Character.as:1264`），
## 提前算好的话，怪在这 0.4 秒里换了动画帧就会错位。

## 一条占多久（`timeLeftAttriChangeTip = 400`，单位毫秒 ⇒ 这里换成秒）
const 间隔秒 := 0.4
## 队列上限（`while (length > 50) shift()`）
const 上限 := 50

var _队: Array[Callable] = []
var _剩 := 0.0


## 宿主（怪 / 玩家）身上找或建一条队列，把"建这条飘字"的动作排进去。
static func 排队于(宿主: Node, 动作: Callable) -> void:
	if 宿主 == null or not is_instance_valid(宿主) or not 动作.is_valid():
		return
	## ⚠ 不用 `飘字队列.new()` / `as 飘字队列`：`class_name` 要等全局类表刷新才认，
	## 新文件在 `--check-only` 下直接 `Compile Error: Identifier not found`
	## ⇒ 单例/门一 load 就炸。改成运行时 `load(自己)`。
	var 队: Node = 宿主.get_node_or_null("飘字队列")
	if 队 == null:
		队 = (load("res://脚本/角色/飘字队列.gd") as GDScript).new()
		队.name = "飘字队列"
		宿主.add_child(队)
	队.投(动作)


## 只给量具/门用：把排着的飘字**立刻全放掉**（跳过 400 毫秒节奏）。
## 节奏本身有专门的判据在量（`测试/姓名战斗挂机回归测试.gd` 那两条），
## 这里只是让"放出来的字长什么样"那批判据不必每条等 0.4 秒。**运行期谁都别调。**
func 全放() -> void:
	while not _队.is_empty():
		var 动作: Callable = _队.pop_front()
		if 动作.is_valid():
			动作.call()
	_剩 = 0.0

func 投(动作: Callable) -> void:
	_队.append(动作)
	while _队.size() > 上限:
		_队.pop_front()		# 原版 `shift()`：溢出丢**最旧**的那条


## 还有几条没放（量具/门用它等队列排空）
func 待放() -> int:
	return _队.size()


func _process(delta: float) -> void:
	if _队.is_empty():
		_剩 = 0.0			# 空队不攒时间：原版只在"刚放过一条"时才把 400 摆回去
		return
	_剩 -= delta
	if _剩 > 0.0:
		return
	_剩 = 间隔秒
	var 动作: Callable = _队.pop_front()
	if 动作.is_valid():
		动作.call()
