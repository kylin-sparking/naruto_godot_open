extends SceneTree
## 设计期 vs 运行期一致性核对。
##
## 用户要求「在编辑器里看到的就是游戏里的效果」，所以凡是运行时才刷上去的文案/颜色/字号，
## 场景里必须预先烘一份同样的值。这里把 人物窗口.tscn **只实例化、不跑渲染脚本** 的每个 Label
## 与像素基线导出的运行期控件表逐条对比。
##
## 用法：Godot --path . --script res://开发工具/设计期核对.gd -- --运行期=测试/差异/人物坐标3/人物_控件.json

func _init():
	var 运行期路径 := ''
	for 参 in OS.get_cmdline_user_args():
		if 参.begins_with('--运行期='):
			运行期路径 = 参.substr(6)
	if 运行期路径 == '':
		push_error('必须给 --运行期=<控件.json>')
		quit(1)
		return
	var 文件 := FileAccess.open('res://%s' % 运行期路径, FileAccess.READ)
	var 表: Array = JSON.parse_string(文件.get_as_text())['控件']
	文件.close()
	var 运行期 := {}
	for 记 in 表:
		if 记['类'] == 'Label':
			运行期[_规范(String(记['路径']))] = 记
	var 场景: Node = load("res://场景/界面/窗口/人物/人物窗口.tscn").instantiate()
	root.add_child(场景)
	var 色差 := 0
	var 字差 := 0
	var 待查: Array = [场景]
	while not 待查.is_empty():
		var 节 = 待查.pop_back()
		for 子 in 节.get_children():
			待查.append(子)
		if not (节 is Label):
			continue
		var 名 := 节 as Label
		var 尾 := _规范(String(场景.get_path_to(名)))
		if not 运行期.has(尾):
			continue
		var 记: Dictionary = 运行期[尾]
		var 色: Color = 名.get_theme_color('font_color')
		var 我色 := [int(色.r8), int(色.g8), int(色.b8)]
		var 运色: Array = 记['色']
		if 我色[0] != int(运色[0]) or 我色[1] != int(运色[1]) or 我色[2] != int(运色[2]):
			色差 += 1
			print('色  %-46s 设计期 %s ≠ 运行期 %s' % [尾, 我色, 运色])
		if 名.get_theme_font_size('font_size') != int(记['字号']):
			字差 += 1
			print('字号 %-46s 设计期 %d ≠ 运行期 %d' % [尾, 名.get_theme_font_size('font_size'), 记['字号']])
	场景.free()
	print('=== 设计期/运行期差异：颜色 %d 处、字号 %d 处（应为 0）===' % [色差, 字差])
	quit()


func _规范(路径: String) -> String:
	# 运行期表的路径是从 主窗口 起算（页面容器/原版人物窗口内容/…），场景内是从根起算，
	# 两边都截到 `原版人物属性面板` 之后才可比。
	return 路径.replace('页面容器/原版人物窗口内容/', '')
