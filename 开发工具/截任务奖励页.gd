extends SceneTree
## 任务面板「奖励」那一段的**有头量具**：喂两条真任务，拍两张图 + 回读几何。
##
## 为什么必须**有头**：无头拿不到视口图像（工程里反复踩过）。
## 跑法：Godot --path . --script res://开发工具/截任务奖励页.gd
##
## 两条夹具各卡一个点：
##   1009 新手武器 —— 奖励是**四件按职业分的装备**（1010011/12/13/14 = 火水雷风），
##     玩家职业 300 ⇒ 只该出**一格**（这条同时核 `getEncourage:271-292` 的职业过滤）。
##     门槛那条（原版 `MQuestionInfoPanel:147` 是「有文字奖励 **或** 有奖励道具」）
##     由门里 `测试/任务奖励显示回归测试.gd` 造夹具判，这里只出图。
##     装备四件按职业分（1010011/12/13/14 = 火/水/雷/风）⇒ 玩家职业 300 只该出**一格**。
##   1018 初醒后续 —— 经验 300 + 四件按职业分的道具 ⇒ 文字与格子**同时**出现，
##     并且格子必须排在**正文底下**（不是面板底下），这是原版那条 `+2` 的口径。
##
## ⚠ 本量具只往会话内存里塞两条任务、不调任何会落盘的接口；
##   跑完还要比对 `user://玩家数据.json` 的字节 —— 变了就是量具坏了（离线门不许写存档）。

const 页面场景 := "res://场景/界面/窗口/任务/任务窗口.tscn"
const 出目录 := "res://测试/截图/任务奖励"
const 几何表 := "res://测试/截图/任务奖励/几何.txt"
const 存档 := "user://玩家数据.json"

var 行: Array[String] = []
var _会 = null
var 存档前 := ""


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	存档前 = _字节()
	_跑()


func _字节() -> String:
	if not FileAccess.file_exists(存档):
		return ""
	var f := FileAccess.open(存档, FileAccess.READ)
	if f == null:
		return ""
	var 文 := f.get_as_text()
	f.close()
	return 文


func _写() -> void:
	var f := FileAccess.open(几何表, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行) + "\n")
		f.close()


func _拍(名: String) -> void:
	root.get_texture().get_image().save_png(出目录 + "/" + 名 + ".png")


func _跑() -> void:
	root.size = Vector2i(960, 540)
	var 会 = root.get_node_or_null("GameSession")
	if 会 == null:
		行.append("!! 没有 GameSession 单例（--script 模式下 autoload 没起来？）")
		_写()
		quit(1)
		return
	## 职业/等级**每喂一条再设一次**：GameSession 起档时从 user:// 读回来的值会盖掉
	## 只设一次的那种写法（实测第一版设 300、量出来按 100 过滤）。
	_会 = 会
	var 包 = load(页面场景)
	if 包 == null:
		行.append("!! 打不开 " + 页面场景)
		_写()
		quit(1)
		return
	var 页: Control = 包.instantiate() as Control
	root.add_child(页)
	await _帧(4)
	_量(页, await _喂(页, "1009", "新手武器", false), "01 只有装备奖励(1009)")
	_量(页, await _喂(页, "1018", "波之国任务", false), "02 经验+道具(1018)")
	_写()
	var 现 := _字节()
	if 现 != 存档前:
		print("!! 量具动了存档（user://玩家数据.json 字节变了）")
		quit(2)
		return
	print("\n".join(行))
	quit(0)


## 把会话的已接列表换成这一条，再走页面自己的 刷新 + 选任务。
## ⚠ `accepted_quests` / `available_quests` 在会话里是**带类型的** `Array[Dictionary]`
##   ⇒ 赋一份无类型 Array 会运行期报错，必须先声明成同类型再走。
func _喂(页: Control, id: String, 名: String, 完成: bool) -> Dictionary:
	var 会 = root.get_node_or_null("GameSession")
	var 列: Array[Dictionary] = [{"id": id, "name": 名, "completed": 完成}]
	var 空: Array[Dictionary] = []
	会.accepted_quests = 列
	会.available_quests = 空
	会.player_stats["job"] = 300
	会.player_stats["level"] = 30
	页.call("刷新")
	await _帧(3)
	return {"id": id, "名": 名}


func _名单(页: Control) -> String:
	var 出: Array[String] = []
	for 子 in (页.get_node("详情") as Control).get_children():
		出.append(String(子.name))
	return ", ".join(出)


func 夹名(夹: Dictionary) -> String:
	## 图名只用任务号，别把中文塞进文件名（跨机器/压缩包更容易出岔子）
	return String(夹["id"])


func _量(页: Control, 夹: Dictionary, 说: String) -> void:
	var 详情: Control = 页.get_node("详情") as Control
	var 下: RichTextLabel = 详情.get_node("下文本") as RichTextLabel
	var 底: Panel = 详情.get_node("下底") as Panel
	var 格们: Array = []
	for 子 in 详情.get_children():
		if String(子.name).begins_with("奖励格"):
			格们.append(子)
	行.append("%s｜任务 %s 选中=%s 职业=%d 奖励物品=%s" % [说, String(夹["id"]),
			String(页.get("_选中id")), int(页.call("_玩家职业")),
			JSON.stringify(页.call("_奖励物品", 页.get("_当前任务")))])
	行.append("    下文本 含「任务奖励」= %s；文高 %.0f 面板高 %.0f" % [
		str(String(下.text).contains("任务奖励")), 下.get_content_height(), 底.size.y])
	行.append("    详情子节点：%s" % _名单(页))
	行.append("    奖励格 %d 个：" % 格们.size())
	for 子 in 格们:
		var 图 := 子.get_node_or_null("图标") as TextureRect
		var 标 := 子.get_node_or_null("数量") as Label
		行.append("      %s @%s 图标=%s 数量=%s" % [String(子.name), str((子 as Control).position),
				"无" if 图 == null or 图.texture == null else String(图.texture.resource_path).get_file(),
				"无" if 标 == null else 标.text])
	_拍(夹名(夹))
