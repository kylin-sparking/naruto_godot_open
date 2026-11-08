extends SceneTree

## 打开「装备强化」窗并截图 —— 用来核**材料/消耗/成功率**是不是配置表里的真值。
##
## 用法（**不能加 --headless**）：
##   Godot --path . --script res://开发工具/截强化窗.gd [-- --出目录=res://测试/截图/装备强化]
##
## 可选 `--快照=<json>`：先灌一份**真服务端**的装备快照（`测试/基线/装备快照/*.json`），
## 否则离线示例数据身上是空的，"请放入需要强化的忍具"那张证明不了材料区。
##
## ⚠️ 切页之后要隔几帧再抓（§3.15 那个坑：同一帧 set 的内容要到帧末才画进视口）。

var _出目录 := "res://测试/截图/装备强化"
var _快照 := ""
var _场景: Node = null
var _窗: Node = null
var _帧 := 0
var _就绪 := false
var _抓过 := false


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2 and 键值[0] == "--出目录":
			_出目录 = 键值[1]
		elif 键值.size() == 2 and 键值[0] == "--快照":
			_快照 = 键值[1]
	_跑()


func _跑() -> void:
	var 场景脚本 := load("res://场景/地图/地图场景.tscn") as PackedScene
	if 场景脚本 == null:
		push_error("无法加载地图场景")
		quit(1)
		return
	_场景 = 场景脚本.instantiate()
	root.add_child(_场景)
	for _序号 in 10:
		await process_frame

	if not DirAccess.dir_exists_absolute(_出目录):
		DirAccess.make_dir_recursive_absolute(_出目录)
	if not _快照.is_empty():
		_装快照(_快照)

	var 管理 := _场景.get_node_or_null("窗口管理")
	_窗 = 管理.call("取或建窗口", "装备强化") if 管理 != null else null
	if _窗 == null:
		push_error("拿不到装备强化窗")
		quit(1)
		return
	管理.call("打开", "装备强化")
	# 挑一个**身上真有装备**的槽，材料区才有内容可看。
	# ⚠️ 2026-10-01：左栏有了和原版一样的**显式放入态**（`_itemData`），
	# 光挪游标不算放进 —— 截图要连着把 `_强化放入中` 立起来（对位"点部位列表一行"）。
	_窗.set("_selected_strengthen_slot", _找有装备的槽())
	_窗.set("_强化放入中", true)
	_窗.call("open_page", "装备强化")
	for _序号 in 5:
		await process_frame

	await _抓("强化页")
	# 七个分页各来一张，用来核每一页的文案。
	# ⚠️ 切页签会**清空放入态**（原版 `selectedBtnHandler:741`）—— 每页重新放进再截，
	# 不然截到的全是"空格子"，核不了带装备的材料/属性区。
	var 槽 := _找有装备的槽()
	for 序号 in range(1, 7):
		_窗.call("_set_strengthen_tab", 序号)
		for _序号2 in 2:
			await process_frame
		_窗.call("_select_strengthen_slot", 槽)
		for _序号3 in 4:
			await process_frame
		await _抓("分页%d" % 序号)

	print("截强化窗：共 %d 张，目录 %s" % [6 + 1, _出目录])
	quit(0)


## 身上第一个有装备的槽位（位置 int）；都没有就退回武器槽，让它显示"请放入"。
func _找有装备的槽() -> int:
	var 会话 := root.get_node_or_null("/root/GameSession")
	if 会话 == null:
		return -1
	for 位置 in 会话.equipped_items:
		var 物品: Dictionary = 会话.equipped_items[位置]
		if not 物品.is_empty():
			return int(位置)
	return -1


func _装快照(路径: String) -> void:
	if not FileAccess.file_exists(路径):
		push_error("快照不存在：%s" % 路径)
		return
	var 解析: Variant = JSON.parse_string(FileAccess.get_file_as_string(路径))
	if typeof(解析) != TYPE_DICTIONARY:
		push_error("快照解析失败：%s" % 路径)
		return
	var 会话 := root.get_node_or_null("/root/GameSession")
	if 会话 == null:
		return
	会话.equipped_items.clear()
	for 键 in 解析:
		会话.equipped_items[int(键)] = (解析[键] as Dictionary).duplicate(true)
	print("截强化窗：已装载装备快照 %s，槽=%s" % [路径, 会话.equipped_items.keys()])


func _抓(名称: String) -> void:
	await process_frame
	var 图像 := root.get_texture().get_image()
	if 图像 == null:
		push_error("视口图像为空（不能加 --headless）")
		return
	图像.save_png("%s/%s.png" % [_出目录, 名称])
	print("截强化窗：已存 %s" % 名称)
