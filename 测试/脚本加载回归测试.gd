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
var _每根 := {}		# 根目录 → 扫到的个数（下面「每根都要有货」那条判据用）
var _单例们: Array[String] = []	## `/root` 的直接子节点名 = autoload 名（不硬抄清单）
## 数量下限是**承重判据**：`DirAccess.open` 打不开时整趟扫描可以一条都不收，
## 那时「0 个失败」是彻底的假绿（`_扫` 第一版就是 `if 目录 == null: return` 静默返回）。
## 300 = 2026-10-09 现查 322 个，留 22 个删文件的余量。
const 下限 := 300


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	## autoload 名**运行期从 `/root` 现列**：清单硬抄会漏掉以后新加的单例，
	## 而列出来连 `GameSession` 都没有 ⇒ 下面的文本判据就是「0 比 0」恒真，所以先验它。
	for 子 in root.get_children():
		_单例们.append(String(子.name))
	if not _单例们.has("GameSession"):
		_失败.append("autoload 名现列得到的是 %s：连 GameSession 都没有 ⇒ 静态裸单例普查是假的" % str(_单例们))
	# 阳性对照：拿一段"static func 里裸写 GameSession."的样本文本喂给同一段判据，
	# **必须**报命中。它不报，就说明扫描本身坏了（文件读得到、命中永远是 0 的那种假绿）。
	if _扫静态裸单例("static func f() -> void:\n\tGameSession.套用挂机配置({})\n").is_empty():
		_失败.append("静态裸单例普查的阳性对照没命中 ⇒ 这条判据等于没跑")
	for 根 in 根目录:
		_每根[根] = _总数
		_扫(根)
		_每根[根] = _总数 - int(_每根[根])
	if _总数 < 下限:
		_失败.append("只扫到 %d 个 .gd（下限 %d）⇒ 有目录没打开，这条门的覆盖是假的" % [_总数, 下限])
	for 根 in 根目录:
		if int(_每根.get(根, 0)) <= 0:
			_失败.append("%s 下一个 .gd 都没扫到" % 根)
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
		## 以前是静默 `return` ⇒ 目录改名/移动之后这条门一条都不扫，照样报"全部可加载"。
		_失败.append("打不开目录 %s（这条门的覆盖是假的）" % 目录路径)
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
	for 项 in _扫静态裸单例(FileAccess.get_file_as_string(路径)):
		_失败.append("%s%s" % [路径, 项])


## `static func` 体内**不许裸写 autoload 名**（`GameSession.` 这种）。
## 为什么要单独一条：2026-10-18 `挂机窗口.gd:50` 裸写 `GameSession.`，
## `挂机窗回归测试.gd` 里跑得好好的（354 判全过），换到 `窗口行为契约体检.gd` 那条
## `preload` 链上就报 `Compile Error: Identifier not found: GameSession` ⇒
## `系统窗口`/`功能窗口` 整链编译失败 ⇒ 挂机页画空，门报的是"E1 页面容器下应有可见控件"。
## **同一个脚本、同一份工程，只因为编译时机不同** —— 所以 `load()`/`can_instantiate()`
## 抓不到它（本条门自己那趟 `load` 是绿的），只能查源码文本。
## 正确写法：运行期取节点，`get_node_or_null("/root/GameSession")`（`后端连接.gd`、
## `功能窗口.gd:364`、`挂机窗口.gd:_会()` 都是这个形态）。
## 返回命中的描述串数组（带行号）；调用方负责把文件名拼在前面。
func _扫静态裸单例(文: String) -> Array[String]:
	var 出: Array[String] = []
	if _单例们.is_empty():
		## 名单没备好的时候**不返回空数组**（那会被读成"这个文件很干净"）：直接报覆盖有问题。
		出.append("：autoload 名单是空的 ⇒ 这条文本判据没判任何东西")
		return 出
	var 静 := false
	var 号 := 0
	for 行 in 文.split("\n"):
		号 += 1
		var 头 := 行.strip_edges()
		if 头 == "" or 头.begins_with("#"):
			continue						# 注释里提一嘴单例名是常事（真值注记），不算命中
		var 缩进了 := 行.begins_with("\t") or 行.begins_with(" ")
		if 头.begins_with("static func "):
			静 = true
		elif not 缩进了:
			静 = false						# 顶格的 func / const / class ⇒ 离开上一个静态体
		if not 静:
			continue
		for 名 in _单例们:
			if 头.contains(名 + "."):
				出.append(":%d 静态函数里裸写 %s.（autoload 名是编译期解析的，换条 preload 链就编不出来）" % [号, 名])
	return 出
