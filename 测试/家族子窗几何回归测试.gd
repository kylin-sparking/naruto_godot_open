extends SceneTree
# 家族子窗表驱动几何门：期望值直接读 `数据/界面/家族子窗_*.json`（与场景同一份 SPEC 生成），
# 逐件比 页面坐标矩形，容差 ±1；顺带钉两件事：
#   ① 钮/下拉 的 texture_normal 必须非空（TextureButton 丢贴图 = 白框，门要拦）；
#   ② 根节点 custom_minimum_size 必须等于期望的"内容"尺寸（壳公式 窗−16 / 窗−68 的落地证据）。
# 跑法：Godot --path . --headless --script res://开发工具/量家族子窗.gd

const 目录 := "res://场景/界面/窗口/家族/"
const 期望目录 := "res://数据/界面/"
const 容差 := 1.0


func _initialize() -> void:
	var 错 := 0
	var 窗数 := 0
	var 件数 := 0
	var 名单 := Array(DirAccess.get_files_at(期望目录))
	名单.sort()
	for 名 in 名单:
		var 文件 := String(名)
		if not 文件.begins_with("家族子窗_") or not 文件.ends_with(".json"):
			continue
		var 窗名: String = 文件.trim_prefix("家族子窗_").trim_suffix(".json")
		var f := FileAccess.open(期望目录.path_join(文件), FileAccess.READ)
		var 期: Dictionary = JSON.parse_string(f.get_as_text())
		f.close()
		var 场景 := 目录.path_join(窗名 + ".tscn")
		if not ResourceLoader.exists(场景):
			print("!! %s 场景缺失" % 窗名)
			错 += 1
			continue
		var 根 := (load(场景) as PackedScene).instantiate() as Control
		root.add_child(根)					# 进树才拿得到 position/size 的最终值
		窗数 += 1
		var 本机 := 0
		var 本错 := 0
		var 根尺 := 根.get_combined_minimum_size()
		if (根尺 - Vector2(期["内容"][0], 期["内容"][1])).length() > 容差:
			print("!! %s 根尺寸 %s ≠ 期望 %s" % [窗名, 根尺, 期["内容"]])
			本错 += 1
		for 键 in 期["件"]:
			if 键 == "_模板":
				continue
			件数 += 1
			var 录: Array = 期["件"][键]
			var 局: Array = 录[0]
			var 节 := 根.get_node_or_null(录[3] if 录.size() > 3 else 键.get_slice("|", 1))
			if 节 == null:
				print("!! %s/%s 节点没找到" % [窗名, 键])
				本错 += 1
				continue
			var a := 节 as Control
			var dx: float = a.position.x - 局[0]
			var dy: float = a.position.y - 局[1]
			var dw: float = a.size.x - 局[2]
			var dh: float = a.size.y - 局[3]
			if max(absf(dx), absf(dy), absf(dw), absf(dh)) > 容差:
				print("!! %s/%s dx=%.1f dy=%.1f dw=%.1f dh=%.1f（期望 %s）" % [窗名, 键, dx, dy, dw, dh, 局])
				本错 += 1
			if a is TextureButton and (a as TextureButton).texture_normal == null:
				print("!! %s/%s texture_normal 为空（白框）" % [窗名, 键])
				本错 += 1
			本机 += 1
		错 += 本错
		print("   %-14s %d 件 %s" % [窗名, 本机, "✓" if 本错 == 0 else "红 %d" % 本错])
		根.free()
	print("家族子窗几何门：%d 窗 / %d 件，红项 %d" % [窗数, 件数, 错])
	quit(1 if 错 > 0 else 0)
