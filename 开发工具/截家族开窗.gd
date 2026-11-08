extends SceneTree
# 家族**开窗**证据器（有头跑）：走真实接线（`家族子窗壳.切换` / `按动作`）把子窗开进宿主的
# `遮罩`，截图出 `测试/截图/家族子窗/开窗_*.png`。这道步要看到的是**窗壳三件 + 内容**一起成立：
# 半透窗皮在内容之下、标题居中 y=5、关钮贴右上、内容原点 (8,38)、底栏钮落在窗壳内。
# 用法（不能加 --headless）：Godot --path . --script res://开发工具/截家族开窗.gd

const 壳脚本 := preload("res://脚本/界面/窗口/家族/家族子窗壳.gd")
const 宿主脚本 := preload("res://测试/假家族宿主.gd")
const 出图 := "res://测试/截图/家族子窗/"

var _帧 := 0
var _宿主
var _红 := 0


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	DirAccess.make_dir_recursive_absolute(出图)
	_宿主 = 宿主脚本.new()
	root.add_child(_宿主)
	(_宿主._overlay as Control).size = Vector2(960, 560)


func _process(_d: float) -> bool:
	_帧 += 1
	match _帧:
		3:
			# 1) 有壳：成员窗（650×370）—— 底栏 4 钮 + 分页落在 contentBg 之外、窗壳之内
			壳脚本.切换(_宿主, "家族成员窗", "成员管理")
			# 2) 走动作串：贡献窗 → 它的"贡献金币"钮该开金币窗
			壳脚本.按动作(_宿主, "家族贡献")
			壳脚本.按动作(_宿主, "家族贡献窗:贡献金币")
			# 3) 无壳：确认弹（原版 Sprite + 自带 580 号底）
			壳脚本.按动作(_宿主, "家族成员窗:解散家族")
		14:
			_出图("开窗_三态.png")
			# 关掉金币窗，验"取消"串真的收窗
			壳脚本.按动作(_宿主, "家族金币窗:取消")
		18:
			var 剩: Array = []
			for 子 in (_宿主._overlay as Control).get_children():
				剩.append(子.name)
			print("   关掉金币窗后剩：" + str(剩))
			if 剩.size() != 3:
				_红 += 1
			# 关钮必须排在拖动区**之后**（Godot 逆序派发 ⇒ 后加的先拿事件），
			# 否则顶部 29px 的拖动区会吞掉关钮点击（主窗场景里就踩过这条）。
			var 根 := (_宿主._overlay as Control).get_node("家族子窗_家族成员窗") as Control
			var 关 := 根.get_node("关闭按钮") as Control
			var 拖 := 根.get_node("拖动区") as Control
			if 关.get_index() <= 拖.get_index():
				_报("关钮排在拖动区之前 ⇒ 点不到")
			print("   关钮 index=%d > 拖动区 index=%d ✓" % [关.get_index(), 拖.get_index()])
			_出图("开窗_关掉金币窗后.png")
		22:
			print("家族开窗证据：%s" % ("OK" if _红 == 0 else "红 %d" % _红))
			quit(1 if _红 > 0 else 0)
	return false		# ⚠ SceneTree._process 返回 **true = 退出**，中途绝不能返 true


func _报(话: String) -> void:
	_红 += 1
	print("!! " + 话)


func _出图(名: String) -> void:
	root.get_texture().get_image().save_png(出图.path_join(名))
	print("   截图 → %s" % 名)
