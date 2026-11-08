extends SceneTree

## 逐个物品跑一遍**背包真正用的那条链**：id → 名字 → 图标路径 → ResourceLoader.exists → load 成 Texture2D。
##
## 为什么要有它：`导入物品图标.mjs` 只证明磁盘上有文件，而 背包窗口.gd:247 判的是
## `ResourceLoader.exists(路径)` —— 没跑过 `--import` 的 PNG 在磁盘上存在、在 Godot 里不存在。
## 光看导出日志会漏掉这一整类问题。
##
## 用法：Godot --headless --path . --script res://开发工具/全道具体检.gd

const 游戏数据脚本 := preload("res://脚本/单例/游戏数据.gd")

func _init() -> void:
	var 物品表: Dictionary = 游戏数据脚本.取表("物品")
	var 总数 := 0
	var 有图 := 0
	var 无名: Array[String] = []
	var 无路径: Dictionary = {}
	var 未导入: Array[String] = []
	var 加载失败: Array[String] = []
	var 尺寸异常: Array[String] = []
	var 按类 := {}

	for 编号 in 物品表.keys():
		var 定义: Dictionary = 物品表[编号]
		var 分类 := String(定义.get("source_category", "(无分类)"))
		按类[分类] = 按类.get(分类, {"总": 0, "图": 0})
		按类[分类]["总"] += 1
		总数 += 1

		if String(游戏数据脚本.item_name(编号)) == str(编号):
			无名.append(编号)

		var 路径 := 游戏数据脚本.item_icon_path(编号)
		if 路径.is_empty():
			无路径[分类] = int(无路径.get(分类, 0)) + 1
			continue
		if not ResourceLoader.exists(路径):
			未导入.append("%s %s" % [编号, 路径])
			continue
		var 纹理 := load(路径) as Texture2D
		if 纹理 == null:
			加载失败.append("%s %s" % [编号, 路径])
			continue
		var 大小 := 纹理.get_size()
		if 大小.x < 8 or 大小.y < 8:
			尺寸异常.append("%s %dx%d" % [编号, int(大小.x), int(大小.y)])
			continue
		有图 += 1
		按类[分类]["图"] += 1

	print("物品 %d 条：图标可用 %d，路径为空 %d，Godot 里不存在 %d，加载失败 %d，尺寸异常 %d，名字查不到 %d" % [
		总数, 有图, 无路径.values().reduce(func(a, b): return a + b), 未导入.size(), 加载失败.size(),
		尺寸异常.size(), 无名.size()])
	print("── 按分类 ──")
	for 分类 in 按类.keys():
		print("  %-14s %4d / %4d" % [分类, 按类[分类]["图"], 按类[分类]["总"]])
	for 段 in [["路径为空(原版就没定义图标)", 无路径.keys()], ["Godot 里不存在(没 --import)", 未导入],
		["加载失败", 加载失败], ["尺寸异常", 尺寸异常], ["名字查不到", 无名]]:
		var 列表: Array = 段[1]
		if 列表.is_empty():
			continue
		print("── %s：%d 条 ──" % [段[0], 列表.size()])
		for 项 in 列表.slice(0, 60):
			print("  ", 项)
	quit(0)
