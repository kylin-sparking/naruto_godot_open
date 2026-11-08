extends SceneTree
func _initialize() -> void:
	var s := load("res://场景/界面/窗口/组队/队伍窗.tscn")
	if s == null:
		print("LOAD_FAIL"); quit(1); return
	var root: Node = s.instantiate()
	if root == null:
		print("INST_FAIL"); quit(1); return
	var 总 := 0
	var 栈 := [root]
	while 栈:
		var n = 栈.pop_front()
		总 += 1
		for c in n.get_children():
			栈.append(c)
	print("节点数=", 总, " 根尺寸=", root.size)
	var 格 := root.find_child("成员格1", true, false)
	print("成员格1 存在=", 格 != null, " 位置=", 格.position if 格 else "-", " 尺寸=", 格.size if 格 else "-")
	var 皮 := root.get_node_or_null("内容区/附近队伍/左皮/底")
	print("左皮底 patch_left=",皮.patch_margin_left if 皮 else "-")
	var 页 := root.get_node_or_null("分页")
	print("分页 子节点=", 页.get_child_count() if 页 else -1)
	quit(0)
