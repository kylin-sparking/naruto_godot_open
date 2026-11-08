extends SceneTree

## 全项目 GDScript **加载**回归：把 `脚本/`、`开发工具/`、`测试/` 下的 .gd 逐个 `load()`，
## **只要有一个加载不出来（parse error）就红**。
##
## 为什么需要它（2026-09-23 真栽过）：给「装备提示框」加附加属性那一段时，新变量撞了个
## 重名（`上限`），**整个脚本加载失败** —— 场景根节点会退化成"没有脚本的空 Control"。
## 而当时顺手跑的三条用例（功能入口 / 物品菜单 / UI资源）**全绿**：
## 它们都不实例化那个组件，跑不到它。运行期的表现是"这个控件点了没反应"，
## 很难往"脚本压根没加载"上想 —— 正是 §0.0d「验证环节本身不可靠」那一类。
##
## 这一条不查行为，只查"能不能加载"。**便宜且全覆盖**，补的正是上面那个盲区。
##
## 运行：Godot --headless --path . --script res://测试/脚本加载回归测试.gd

## 要扫的根目录。`res://` 下第三方插件（addons）不算我们的代码，跳过。
const 根目录 := ["res://脚本", "res://开发工具", "res://测试"]

var _失败: Array[String] = []
var _总数 := 0


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	for 根 in 根目录:
		_扫(根)
	if _失败.is_empty():
		print("脚本加载回归测试：通过（%d 个 .gd 全部可加载）" % _总数)
		quit(0)
	else:
		for 项 in _失败:
			push_error("脚本加载回归测试：失败 - %s" % 项)
		print("脚本加载回归测试：失败 %d / %d" % [_失败.size(), _总数])
		quit(1)


func _扫(目录路径: String) -> void:
	var 目录 := DirAccess.open(目录路径)
	if 目录 == null:
		return
	目录.list_dir_begin()
	var 名 := 目录.get_next()
	while 名 != "":
		if 名.begins_with("."):
			名 = 目录.get_next()
			continue
		var 全路径 := 目录路径.path_join(名)
		if 目录.current_is_dir():
			_扫(全路径)
		elif 名.ends_with(".gd"):
			_查一个(全路径)
		名 = 目录.get_next()
	目录.list_dir_end()


func _查一个(路径: String) -> void:
	_总数 += 1
	# ⚠️ 不要在这里 `preload` —— preload 是编译期的，一个坏脚本会让**本条用例自己**编译不过，
	# 那就从"报出谁坏了"退化成"用例也挂了"。
	#
	# ⚠️⚠️ **`load()` 对有 parse error 的脚本照样返回非 null**（第一版就栽在这：
	# 拿一个故意写坏的脚本试，`load()` 给了个对象，用例报"全部可加载"，假绿）。
	# 真正能分辨的是 `can_instantiate()` —— 编译不过的 GDScript 它回 false。
	var 资源 := ResourceLoader.load(路径)
	if 资源 == null:
		_失败.append("%s 加载不出来" % 路径)
	elif 资源 is GDScript and not (资源 as GDScript).can_instantiate():
		_失败.append("%s 加载了但**不可实例化**（几乎肯定是 parse error，看上面的控制台报错）" % 路径)
