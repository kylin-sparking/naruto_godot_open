extends SceneTree

## **场景资源体检**：把 `场景/` 下每个 `.tscn` 都过一遍 ——
##   ① 场景本身能不能 `load()` + `instantiate()`；
##   ② 它 `[ext_resource]` 引用的每个文件**在不在**（缺素材是静默的：Godot 只会打一行 warning，
##      运行时那块图/那段脚本就是空的）；
##   ③ 引用的每个**脚本**能不能加载（等价于 `脚本加载回归测试` 对 .gd 那一层，这里是按场景角度再查一遍）；
##   ④ **九宫格属性名对不对块**（§3.228）：`NinePatchRect` 只认 `patch_margin_*`（**int**），
##      `texture_margin_*` 是 `TextureRect` / `StyleBoxTexture` 的属性。写错名字 **Godot 既不报错也不落地**
##      （探针实测：`set("texture_margin_left")` 之后 `patch_margin_left` 仍是 0）⇒ 底图整片拉伸、
##      四角从没九宫切过，而值本身还能和皮肤表对得上，**只有按属性名扫一遍才抓得住**。
##
## 为什么需要它（2026-09-24 接入四位开发者的四个页面时立的）：
## `脚本加载回归测试` 只扫 `.gd`，**场景里少一张图它一句话都不会说** ——
## 而那四个页面一共引用了 46 个当时项目里没有的文件，全靠手工比出来。
## 这类"引用悬空"必须有一条常驻的用例兜着。
##
## 运行：Godot --headless --path . --script res://测试/场景资源回归测试.gd

const 场景根 := "res://场景"

## 每种块**不许**出现的边距属性前缀（写错了 Godot 不报错、也不落地）。
const _九宫禁属性 := {
	"NinePatchRect": "texture_margin_",
	"TextureRect": "patch_margin_",
	"StyleBoxTexture": "patch_margin_",
}

var _失败: Array[String] = []
var _场景数 := 0
var _引用数 := 0
var _九宫件 := 0


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	_扫(场景根)
	if _失败.is_empty():
		print("场景资源回归测试：通过（场景 %d 个，外部引用 %d 条，九宫件 %d 枚，全部落地）" % [_场景数, _引用数, _九宫件])
		quit(0)
	else:
		for 项 in _失败:
			push_error("场景资源回归测试：失败 - %s" % 项)
		print("场景资源回归测试：失败 %d 项（场景 %d 个 / 引用 %d 条 / 九宫件 %d 枚）" % [_失败.size(), _场景数, _引用数, _九宫件])
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
		elif 名.ends_with(".tscn"):
			_查场景(全路径)
		名 = 目录.get_next()
	目录.list_dir_end()


func _查场景(路径: String) -> void:
	_场景数 += 1
	var 文件 := FileAccess.open(路径, FileAccess.READ)
	if 文件 == null:
		_失败.append("%s 打不开" % 路径)
		return
	var 文本 := 文件.get_as_text()
	文件.close()

	# ① 引用的文件在不在（**先查这个**：素材缺了场景通常还能加载，只是画不出来）
	for 行 in 文本.split("\n"):
		if not 行.begins_with("[ext_resource"):
			continue
		_引用数 += 1
		var 命中 := _取属性(行, "path=\"")
		if 命中.is_empty():
			continue
		# ⚠️  里写的就是**完整**的 `res://xxx`，别再补一次前缀
		# （第一版补了，于是每条都变成 `res://res://…`，241 个场景全线报错）。
		var 引用路径 := 命中
		# ⚠️ 判据用 **`FileAccess.file_exists`（源文件在不在）**，不能只看 `ResourceLoader.exists`：
		# 源文件被删、但旁边的 `.import` 还在时，`ResourceLoader.exists` 照样回 true。
		# 实测：`下拉箭头2.png` 只给了 `.import` 没给 PNG，用它就**漏过去了**。
		if not FileAccess.file_exists(引用路径):
			_失败.append("%s 引用的文件不存在：%s" % [路径, 引用路径])

	# ①b `[sub_resource ... id="X"]` 的 X 就是 Godot 的 **scene unique ID**，只许 `[A-Za-z0-9_]`
	#    且**不能以数字开头**。中文 id（`sb_内容面板`）或数字开头（`10tuq`）每加载一次吐一行
	#    `ERROR: The scene unique ID must contain only letters, numbers, and underscores.`
	#    —— 2026-10-11 实测：5 个场景 18 个 id，全量跑一轮 77 道门共 **720 行**这种 ERROR，
	#    把日志里真正的错误淹掉（§3.109 那两条 `Node not found` 正是从这堆行里挖出来的）。
	#    ⚠️ **只管 sub_resource**：`[ext_resource ... id="1_krnc2"]` 那种数字开头是
	#    **Godot 编辑器自己的标准写法、从来不报错**（全工程 260+ 个场景都这么写）——
	#    第一版按"所有 id"查，把 260 个正常场景全判红，误报撑爆。
	for 行 in 文本.split("\n"):
		if not 行.begins_with("[sub_resource"):
			continue
		var 识id := _资源id(行)
		if not 识id.is_empty() and not _是ASCII标识(识id):
			_失败.append("%s 的 sub_resource id 不是 ASCII：%s（Godot 会报 scene unique ID 并丢弃）" % [路径, 识id])

	# ④ 九宫边距的属性名**对不对块**（§3.228：17 扇窗 336 行把 `patch_margin_*` 写成
	#    `texture_margin_*`，值一路和皮肤表对得上、门照绿，屏上却是整片拉伸）。
	var 块 := ""
	for 行 in 文本.split("\n"):
		if 行.begins_with("[node ") or 行.begins_with("[sub_resource "):
			块 = _块类型(行)
			if 块 == "NinePatchRect":
				_九宫件 += 1
			continue
		if 块.is_empty():
			continue
		var 头 := 行.strip_edges()
		var 禁: String = _九宫禁属性.get(块, "")
		if not 禁.is_empty() and 头.begins_with(禁):
			_失败.append("%s 的「%s」块里写了 %s ⇒ 属性名不属于这个类，" % [路径, 块, 头.split(" = ")[0]]
					+ "Godot 既不报错也不落地（九宫格的边距是 patch_margin_*）")
		elif 块 == "NinePatchRect" and 头.begins_with("patch_margin_") and 头.contains("."):
			_失败.append("%s 的 %s 不是整数 ⇒ NinePatchRect 的边距只收 int" % [路径, 头.split(" = ")[0]])

	# ② 场景本身能不能加载 + 实例化
	var 资源 := load(路径)
	if 资源 == null:
		_失败.append("%s 加载不出来" % 路径)
		return
	var 场景 := 资源 as PackedScene
	if 场景 == null:
		_失败.append("%s 不是 PackedScene" % 路径)
		return
	var 实例 := 场景.instantiate()
	if 实例 == null:
		_失败.append("%s 实例化失败" % 路径)
		return
	# ③ 实例化出来的节点里，**本该挂脚本的却光着** = 那段脚本没加载上
	_查脚本(路径, 实例)
	实例.free()


## 场景文件里给某节点写了 `script = ExtResource(...)`，实例化后那个节点就该有脚本。
## 逐节点核一遍 —— 脚本加载失败时 Godot 只打一行 error，节点照样建出来（光着），很容易漏。
func _查脚本(路径: String, 节点: Node) -> void:
	if 节点.get_script() == null and 节点.has_meta("__要脚本"):
		_失败.append("%s 的节点「%s」脚本没挂上" % [路径, 节点.name])
	for 子 in 节点.get_children():
		_查脚本(路径, 子)


## 块头行（`[node …]` / `[sub_resource …]`）里的 `type="…"`；没有（实例化的子场景）回空。
func _块类型(行: String) -> String:
	var 命中 := _取属性(行, "type=\"")
	return 命中


## `[sub_resource ...]` 行里那枚 `id="…"`。
## ⚠️ 不能直接 `行.find("id=\"")` 取第一条：`uid="uid://…"` 里也含子串 `id="…"`，
##    会一把抓成 uid（2026-10-11 写这个检查时实测踩到）。
func _资源id(行: String) -> String:
	var 找 := 行.find("id=\"")
	while 找 >= 0:
		var 前 := 行.unicode_at(找 - 1) if 找 > 0 else -1
		var 是词字符: bool = 前 >= 0 and ((前 >= 48 and 前 <= 57) or (前 >= 65 and 前 <= 90)
				or (前 >= 97 and 前 <= 122) or 前 == 95)
		if not 是词字符:
			return _取属性(行.substr(找), "id=\"")
		找 = 行.find("id=\"", 找 + 1)
	return ""


## 资源 id 的合法形状：`[A-Za-z_]` 开头、其余 `[A-Za-z0-9_]`（= Godot `String.is_valid_identifier`）。
func _是ASCII标识(识: String) -> bool:
	if 识.is_empty():
		return false
	var 首 := 识.unicode_at(0)
	if not ((首 >= 65 and 首 <= 90) or (首 >= 97 and 首 <= 122) or 首 == 95):
		return false
	for i in 识.length():
		var c := 识.unicode_at(i)
		if not ((c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95):
			return false
	return true


func _取属性(行: String, 键: String) -> String:
	var 起 := 行.find(键)
	if 起 < 0:
		return ""
	起 += 键.length()
	var 止 := 行.find("\"", 起)
	return 行.substr(起, 止 - 起) if 止 > 起 else ""
