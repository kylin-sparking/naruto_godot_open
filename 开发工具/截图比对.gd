extends SceneTree

## 逐像素比对两个截图目录，输出差异报告与高亮图。
##
## 运行：
##   Godot --headless --path . --script res://开发工具/截图比对.gd -- \
##     --甲=测试/基线/godot_1280x720 --乙=测试/截图/P1 [--出=测试/差异] [--阈值=8]
##
## 刻意用 GDScript 而非 Python/npm：整条工具链只需一个二进制，CI 也能跑。
##
## 阈值说明：九宫格框架应接近零差（同一批源像素九宫拉伸）。
## 文字必然有非零差 —— Flash GDI 点阵 vs Godot hinted 轮廓光栅化会逐字形不同。
## 故不设单一全局通过门槛，只输出数字与高亮图供判读。

var _甲目录 := ""
var _乙目录 := ""
var _出目录 := "测试/差异"
var _阈值 := 8


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--甲="):
			_甲目录 = arg.trim_prefix("--甲=")
		elif arg.begins_with("--乙="):
			_乙目录 = arg.trim_prefix("--乙=")
		elif arg.begins_with("--出="):
			_出目录 = arg.trim_prefix("--出=")
		elif arg.begins_with("--阈值="):
			_阈值 = int(arg.trim_prefix("--阈值="))

	if _甲目录.is_empty() or _乙目录.is_empty():
		push_error("用法：--甲=<目录> --乙=<目录> [--出=<目录>] [--阈值=N]")
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute("res://%s" % _出目录)

	var 目录 := DirAccess.open("res://%s" % _甲目录)
	if 目录 == null:
		push_error("打开失败：%s" % _甲目录)
		quit(1)
		return

	var 名单: Array[String] = []
	for 文件 in 目录.get_files():
		if 文件.ends_with(".png"):
			名单.append(文件)
	名单.sort()

	var 有差 := 0
	var 缺失 := 0
	print("阈值=%d（通道差超过它才计入超阈值像素）" % _阈值)
	print("%-22s %8s %10s %8s" % ["页面", "最大差", "超阈值", "占比%"])

	for 文件 in 名单:
		var 甲路径 := "res://%s/%s" % [_甲目录, 文件]
		var 乙路径 := "res://%s/%s" % [_乙目录, 文件]
		if not FileAccess.file_exists(乙路径):
			print("%-22s %s" % [文件, "← 乙目录缺此文件"])
			缺失 += 1
			continue

		var 甲 := Image.load_from_file(甲路径)
		var 乙 := Image.load_from_file(乙路径)
		if 甲 == null or 乙 == null:
			print("%-22s %s" % [文件, "← 读取失败"])
			缺失 += 1
			continue
		if 甲.get_size() != 乙.get_size():
			print("%-22s 尺寸不同 %s vs %s" % [文件, 甲.get_size(), 乙.get_size()])
			有差 += 1
			continue

		var 结果 := _比对(甲, 乙, 文件)
		if 结果["超阈值"] > 0:
			有差 += 1
		var 总数 := float(甲.get_width() * 甲.get_height())
		print("%-22s %8d %10d %8.3f" % [
			文件, 结果["最大差"], 结果["超阈值"], 100.0 * float(结果["超阈值"]) / 总数,
		])

	print("\n共 %d 张，有差异 %d 张，缺失/读取失败 %d 张" % [名单.size(), 有差, 缺失])
	print("高亮图写入 res://%s/" % _出目录)
	quit(0)


func _比对(甲: Image, 乙: Image, 文件: String) -> Dictionary:
	var 宽 := 甲.get_width()
	var 高 := 甲.get_height()
	var 高亮 := Image.create(宽, 高, false, Image.FORMAT_RGBA8)
	var 最大差 := 0
	var 超阈值 := 0

	for y in 高:
		for x in 宽:
			var 甲色 := 甲.get_pixel(x, y)
			var 乙色 := 乙.get_pixel(x, y)
			var 差 := maxi(
				maxi(
					int(absf(甲色.r - 乙色.r) * 255.0),
					int(absf(甲色.g - 乙色.g) * 255.0),
				),
				maxi(
					int(absf(甲色.b - 乙色.b) * 255.0),
					int(absf(甲色.a - 乙色.a) * 255.0),
				),
			)
			最大差 = maxi(最大差, 差)
			if 差 > _阈值:
				超阈值 += 1
				# 洋红高亮差异，便于在深色 UI 上一眼看到
				高亮.set_pixel(x, y, Color(1, 0, 1, 1))
			else:
				# 保留乙图作底，压暗以突出高亮
				高亮.set_pixel(x, y, Color(乙色.r * 0.35, 乙色.g * 0.35, 乙色.b * 0.35, 1.0))

	if 超阈值 > 0:
		高亮.save_png("res://%s/差异_%s" % [_出目录, 文件.trim_prefix("截图_")])
	return {"最大差": 最大差, "超阈值": 超阈值}
