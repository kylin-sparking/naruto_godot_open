extends SceneTree
# 设置页「真宿主」实机路径截图器（有头）：不走假宿主，而是加载真正的 地图场景，
# 让 `窗口管理 → 功能窗口 → 系统窗口._render_settings`（就是泄漏那条链）自己把设置页建出来，
# 再把窗口摆正拍图。假宿主演不到的东西（真 `_render_more_settings` 显形、真主题、真遮罩）这里才看得到。
#
# 跑法（不能加 --headless）：Godot --path . --script res://开发工具/截设置页真机.gd

const 地图 := "res://场景/生成/地图_101010000_烘焙.tscn"
const 出图 := "res://测试/截图/设置_对照/"

var _帧 := 0
var _场: Node
var _窗: Node
var _红 := 0


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	DirAccess.make_dir_recursive_absolute(出图)
	_场 = (load(地图) as PackedScene).instantiate()
	root.add_child(_场)


func _层(窗: Node) -> Dictionary:
	var 出 := {}
	for 名 in ["层主页", "层特页", "更多设置"]:
		var 节 := 窗.find_child(名, true, false) as Control
		出[名] = 节.visible if 节 != null else "无此件"
	return 出


func _process(_d: float) -> bool:
	_帧 += 1
	match _帧:
		30:
			var 管 := _场.get_node_or_null("窗口管理")
			if 管 == null:
				print("!! 没有 窗口管理")
				quit(1)
				return true
			_窗 = 管.call("取或建窗口", "设置")
			if _窗 == null:
				print("!! 取不到设置窗口")
				quit(1)
				return true
			# 走 `打开` 而不是只 `open_page`：`打开` 会把这页记进 `_顺序` 并分配 layer，
			# 否则后开的快捷键窗跟它比层号时缺一格，截出来变成快捷键压在设置底下（假象）。
			管.call("打开", "设置")
			_窗.call("open_page", "设置")		# 直接建出来的窗口要显式开这一页
		40:
			var 态 := _层(_窗)
			print("   开局三层：%s" % 态)
			if str(态["层主页"]) == "无此件":		# ⚠ 别写 String(变体)：对 bool 是无效构造，整条 match 分支当场静默中断
				var 列: Array = []
				for 子 in _窗.find_children("*", "Control", true, false):
					列.append(String(子.name))
				print("   窗口里前 20 个 Control：%s" % 列.slice(0, 20))
			_红 += 0 if (态["层主页"] == true and 态["层特页"] != true and 态["更多设置"] != true) else 1
			_拍("真机_系统设置.png")
		44:
			var 客 := _窗.find_child("页签客户端", true, false) as TextureButton
			客.disabled = false
			客.pressed.emit()
		50:
			var 态2 := _层(_窗)
			print("   点客户端后：%s" % 态2)
			_红 += 0 if (态2["层主页"] != true and 态2["更多设置"] == true) else 1
			_拍("真机_客户端.png")
		54:
			var 特 := _窗.find_child("页签特殊设置", true, false) as TextureButton
			特.disabled = false
			特.pressed.emit()
		60:
			var 态3 := _层(_窗)
			print("   点特殊设置后：%s" % 态3)
			_红 += 0 if (态3["更多设置"] != true and 态3["层特页"] == true) else 1
			_拍("真机_特殊设置.png")
		64:
			# 「快速键」页签 = 开关式独立窗（SCW:264 → UM2:3133-3146），不是切页
			var 快 := _窗.find_child("页签快速键", true, false) as TextureButton
			快.disabled = false
			快.pressed.emit()
		74:
			var 管 := _场.get_node_or_null("窗口管理")
			# 每扇窗都是 `功能窗口.tscn` 的实例（节点名同名），页名记在 `_窗口们` 字典里 ⇒ 别按节点名找
			var 快窗: Node = (管.get("_窗口们") as Dictionary).get("快捷键")
			if 快窗 == null:
				_报("点了「快速键」页签没开出快捷键窗（真宿主链路上断）")
			else:
				var 外框 := 快窗.find_child("主窗口", true, false) as Control
				var 页 := 快窗.find_child("原版快速键内容", true, false) as Control
				print("   快捷键窗：外框 %s　页 %s　页里 %d 件　layer 快=%s 设=%s" % [
					外框.size if 外框 != null else "?", 页.size if 页 != null else "?",
					页.get_child_count() if 页 != null else -1,
					快窗.layer, _窗.layer])
				if 快窗.layer <= _窗.layer:
					_报("快捷键窗 layer %s 没高于设置窗 %s ⇒ 后开的该压住先开的" % [快窗.layer, _窗.layer])
				if 外框 == null or absf(外框.size.x - 765.0) > 1.0 or absf(外框.size.y - 455.0) > 1.0:
					_报("快捷键窗外框 ≠ 765×455（时间轴 background 765×345 + KF:128 列表条 110）")
				if 页 == null or 页.get_child_count() < 130:
					_报("快捷键页没建全")
				# 两扇窗都居中、快捷键 765×455 与 设置 423×424 大面积重叠，证据图里分不清哪块属于谁
				# ⇒ 拍这一张前把设置窗收起（快捷键是独立窗，不受父链影响）
				# ⚠ 本帧改的可见性**不会**进本帧的 `root.get_texture()`（那是上一帧的画果）
				# ⇒ 置 false 与拍图必须隔一帧，否则截到的还是叠着的两张窗
				_窗.visible = false
		80:
				_拍("真机_快捷键窗.png")
		84:
			quit(1 if _红 > 0 else 0)
			return true
	return false


func _报(话: String) -> void:
	_红 += 1
	print("!! " + 话)


func _拍(名: String) -> void:
	root.get_texture().get_image().save_png(出图.path_join(名))
	print("   截图 → %s" % 名)
