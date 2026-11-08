extends SceneTree

# ============================================================
# 写轮眼页 · 层级 / 轮回眼裁切 自检
# ------------------------------------------------------------
# 用途：一条命令验证「轮回眼圆盘被眼眶开孔裁切 + 圆形裁切材质就位」这条链路没被改坏。
#
# 用法：
#   godot --headless --path . \
#       --script "res://素材/界面/原版窗口/人物/血继界限/脚本/写轮眼页_层级自检.gd"
#
# 断言：
#   A. 写轮眼背景 排在 轮回眼 之前   → 圆盘能盖住旧红眼
#   B. 轮回眼     排在 轮回眼背景 之前 → 开孔才能把圆盘裁成眼眶形状（第十九版修复的核心）
#   C. 轮回眼 挂着 ShaderMaterial，且 u_radius 跑满白盘终半径（第二十版：圆形裁切 shader）
#   D. 切到轮回眼阶段后：扩张跑满 1.0、写轮眼背景 收起、轮回眼背景 亮起
#
# ⚠️ B 失败 = 有人把「把 轮回眼背景 移到 轮回眼 之下」那步加回来了
#    → 圆盘会溢出眼眶、压住眉毛额头（用户 2026-09-24 反馈的 bug 复现）。
# ⚠️ C 失败 = 圆形裁切 shader 没生效 → 边缘会出现 clip_children 时代的台阶锯齿。
# ============================================================

const 场景路径 := "res://场景/界面/窗口/人物/页面/写轮眼页.tscn"
const 白盘终半径_期望 := 95.86    # = 95.86 × 轮回眼缩放(1.00)

func _init() -> void:
	var 失败项: Array[String] = []

	var 页 = load(场景路径).instantiate()
	root.add_child(页)
	await process_frame
	await process_frame

	print("=== 写轮眼页 层级 / 裁切自检 ===")
	print("--- _ready() 之后的直接子节点顺序（越靠后 = 绘制越晚 = 越在上面）---")
	for i in 页.get_child_count():
		print("  [%2d]  %s" % [i, 页.get_child(i).name])

	var 序号 := {}
	for i in 页.get_child_count():
		序号[String(页.get_child(i).name)] = i

	print("")
	print("--- 断言 A / B ---")
	var 立绘 := int(序号.get("写轮眼背景", -1))
	var 圆盘 := int(序号.get("轮回眼", -1))
	var 底色 := int(序号.get("轮回眼背景", -1))

	if 立绘 < 0 or 圆盘 < 0 or 底色 < 0:
		失败项.append("没找到 写轮眼背景 / 轮回眼 / 轮回眼背景 之一：%s" % str(序号))
		print("❌ 节点查找失败，跳过 A/B")
	else:
		print("  写轮眼背景 = %d   轮回眼(圆盘) = %d   轮回眼背景(开孔脸) = %d" % [立绘, 圆盘, 底色])
		if 立绘 < 圆盘:
			print("✅ A 通过：写轮眼背景(%d) 在 轮回眼(%d) 之下 → 圆盘能盖住旧红眼" % [立绘, 圆盘])
		else:
			失败项.append("A 失败：写轮眼背景(%d) 不在 轮回眼(%d) 之下" % [立绘, 圆盘])
			print("❌ A 失败")
		if 圆盘 < 底色:
			print("✅ B 通过：轮回眼(%d) 在 轮回眼背景(%d) 之下 → 开孔会裁切圆盘" % [圆盘, 底色])
		else:
			失败项.append("B 失败：轮回眼背景 被压到了 轮回眼 之下（第十八版的老 bug 复现）")
			print("❌ B 失败：轮回眼背景(%d) 不在 轮回眼(%d) 之上 → 圆盘会溢出眼眶！" % [底色, 圆盘])

	# ---------- F：提升阶数弹窗接线 ----------
	print("")
	print("--- 断言 F：提升写轮眼阶数弹窗接线 ---")
	var 弹窗 = null
	var 按钮 = null
	for i in 页.get_child_count():
		var n := String(页.get_child(i).name)
		if n == "提升写轮眼阶数弹窗":
			弹窗 = 页.get_child(i)
		elif n == "提升写轮眼阶数":
			按钮 = 页.get_child(i)
	if 弹窗 == null or 按钮 == null:
		失败项.append("F 失败：找不到 提升写轮眼阶数弹窗 或 提升写轮眼阶数 按钮")
		print("❌ F 失败：找不到弹窗或按钮")
	else:
		var 动画 = 弹窗.get_node_or_null("滑出动画")
		if not (动画 is AnimationPlayer):
			失败项.append("F 失败：弹窗下没有 AnimationPlayer「滑出动画」")
			print("❌ F 失败：找不到 滑出动画 节点")
		else:
			var 有滑入: bool = 动画.has_animation("滑入")
			var 有滑出: bool = 动画.has_animation("滑出")
			print("  弹窗默认 visible = %s ；动画库 滑入=%s 滑出=%s"
				% [弹窗.visible, 有滑入, 有滑出])
			if 有滑入 and 有滑出:
				print("✅ F1 通过：滑入 / 滑出 两条 0.5s 动画都在")
			else:
				失败项.append("F1 失败：滑入/滑出 动画缺失")
			var 连接数: int = 按钮.pressed.get_connections().size()
			print("  按钮 pressed 的连接数 = %d" % 连接数)
			if 连接数 > 0:
				print("✅ F2 通过：提升按钮已接线")
			else:
				失败项.append("F2 失败：提升按钮没接线")
			按钮.pressed.emit()
			await process_frame
			print("  模拟点击后 弹窗.visible = %s" % 弹窗.visible)
			if 弹窗.visible:
				print("✅ F3 通过：点按钮后弹窗显示、滑入已启动")
			else:
				失败项.append("F3 失败：点按钮后弹窗仍隐藏")
			# 复位，避免影响后面
			弹窗.visible = false

	# ---------- G：两页信号绝不串线 ----------
	print("")
	print("--- 断言 G：写轮眼页 / 柔拳页 的弹窗信号互不通（防串线）---")
	var 柔拳场景 = load("res://场景/界面/窗口/人物/页面/柔拳页.tscn")
	if 柔拳场景 == null:
		print("⚠️ 柔拳页加载失败，跳过断言 G")
	else:
		var 柔拳页 = 柔拳场景.instantiate()
		root.add_child(柔拳页)
		await process_frame
		await process_frame
		var 柔拳弹窗 = 柔拳页.find_child("提升柔拳阶数弹窗", true, false)
		var 柔拳按钮 = 柔拳页.find_child("提升柔拳阶数", true, false)
		var 写轮动画 = null
		if 弹窗 != null:
			写轮动画 = 弹窗.get_node_or_null("滑出动画")
		if 柔拳弹窗 == null or 柔拳按钮 == null or 弹窗 == null or 写轮动画 == null:
			失败项.append("G 失败：两页结构不符合预期，无法判定")
			print("❌ G 失败：柔拳弹窗/按钮 或 写轮眼弹窗/动画 缺一个")
		else:
			var 柔拳动画 = 柔拳弹窗.get_node_or_null("滑出动画")
			if 柔拳动画 == null:
				失败项.append("G 失败：柔拳弹窗下没有 AnimationPlayer")
				print("❌ G 失败：柔拳弹窗下缺少 滑出动画")
			else:
				# 先把两边都复位，避免上一轮的状态干扰
				弹窗.visible = false
				柔拳弹窗.visible = false
				写轮动画.stop()
				柔拳动画.stop()
				await process_frame

				# ① 点【写轮眼】的按钮
				按钮.pressed.emit()
				await process_frame
				var 写在播: bool = 写轮动画.is_playing()
				var 柔在播: bool = 柔拳动画.is_playing()
				print("  点【写轮眼·提升阶数】后 → 写轮眼弹窗 visible=%s 动画在播=%s ｜ 柔拳弹窗 visible=%s 动画在播=%s"
					% [弹窗.visible, 写在播, 柔拳弹窗.visible, 柔在播])
				if 弹窗.visible and 写在播 and not 柔在播 and not 柔拳弹窗.visible:
					print("✅ G1 通过：只弹写轮眼那个，没有串到柔拳")
				else:
					失败项.append("G1 失败：点写轮眼按钮时串到柔拳（或没弹出来）")

				# ② 反向：点【柔拳】的按钮
				#    ★ 柔拳页的弹窗本来就是「常显」的（它那份脚本不会自己亮起来），
				#      所以这里要把它恢复成 true，不能拿 visible 当判据。
				弹窗.visible = false
				柔拳弹窗.visible = true
				写轮动画.stop()
				柔拳动画.stop()
				await process_frame
				柔拳按钮.pressed.emit()
				await process_frame
				var 柔在播2: bool = 柔拳动画.is_playing()
				var 写在播2: bool = 写轮动画.is_playing()
				print("  点【柔拳·提升阶数】后 → 柔拳弹窗 visible=%s 动画在播=%s ｜ 写轮眼弹窗 visible=%s 动画在播=%s"
					% [柔拳弹窗.visible, 柔在播2, 弹窗.visible, 写在播2])
				if 柔在播2 and not 写在播2 and not 弹窗.visible:
					print("✅ G2 通过：只弹柔拳那个，没有串到写轮眼")
				else:
					失败项.append("G2 失败：点柔拳按钮时串到写轮眼（或没弹出来）")

				# 顺便验证：两个弹窗根本不是同一个对象
				if 弹窗 == 柔拳弹窗:
					失败项.append("G3 失败：两页拿到的是同一个弹窗对象")
					print("❌ G3 失败：两页拿到同一个弹窗对象！")
				else:
					print("✅ G3 通过：两页的弹窗是两个独立节点（%s / %s）"
						% [弹窗.get_path(), 柔拳弹窗.get_path()])
			柔拳页.queue_free()
		await process_frame

	# ---------- 切到轮回眼阶段，跑完生长特效 ----------
	print("")
	print("--- 断言 C / D：切到轮回眼阶段并等动画跑完 ---")
	var 眼下标: int = 页._轮回眼索引
	print("  轮回眼阶段序号 = %d（总数 %d）" % [眼下标, 页._按钮列表.size()])
	if 眼下标 < 0:
		失败项.append("找不到轮回眼阶段")
	else:
		页._切换阶段(眼下标)
		# 生长特效当前约 0.8s（速度倍率 0.40）：红眼放大 0.78s + 白盘延迟 0.14s
		# + 时长 0.66s。这里等 1.6s，留足余量。
		for i in 16:
			await create_timer(0.1).timeout

		print("  _扩张进度 = %.3f" % 页._扩张进度)

		# C：圆形裁切材质
		var 圆盘节点: Node = null
		for i in 页.get_child_count():
			if String(页.get_child(i).name) == "轮回眼":
				圆盘节点 = 页.get_child(i)
		if 圆盘节点 == null:
			失败项.append("找不到 轮回眼 节点（断言 C）")
			print("❌ C 失败：找不到 轮回眼 节点")
		elif not (圆盘节点.material is ShaderMaterial):
			失败项.append("轮回眼没有挂圆形裁切 ShaderMaterial（断言 C）")
			print("❌ C 失败：轮回眼 .material 不是 ShaderMaterial → 边缘会退化成台阶锯齿")
		else:
			var r = 圆盘节点.material.get_shader_parameter("u_radius")
			print("✅ C 通过：轮回眼已挂圆形裁切材质；u_radius = %s（跑满应 ≈ %.2f）"
				% [str(r), 白盘终半径_期望])
			if r is float and absf(r - 白盘终半径_期望) < 0.02:
				print("✅ C2 通过：裁切半径已跑满白盘终半径，圆盘被完整揭开")
			else:
				失败项.append("C2 失败：裁切半径 = %s，期望 %.2f" % [str(r), 白盘终半径_期望])
			print("  u_center = %s   u_edge = %s   u_tex_size = %s"
				% [str(圆盘节点.material.get_shader_parameter("u_center")),
				   str(圆盘节点.material.get_shader_parameter("u_edge")),
				   str(圆盘节点.material.get_shader_parameter("u_tex_size"))])

		# D：扩张进度 + 收尾显隐
		if absf(页._扩张进度 - 1.0) < 0.001:
			print("✅ D1 通过：扩张进度跑满 1.0")
		else:
			失败项.append("D1 失败：扩张进度 = %.3f" % 页._扩张进度)

		var 立绘可见 = false
		var 底色可见 = false
		for i in 页.get_child_count():
			var n := String(页.get_child(i).name)
			if n == "写轮眼背景":
				立绘可见 = 页.get_child(i).visible
			elif n == "轮回眼背景":
				底色可见 = 页.get_child(i).visible
		print("  写轮眼背景.visible = %s ／ 轮回眼背景.visible = %s" % [立绘可见, 底色可见])
		if not 立绘可见 and 底色可见:
			print("✅ D2 通过：旧红眼层已收起、开孔脸亮起")
		else:
			失败项.append("D2 失败：收尾显隐不对（立绘可见=%s 底色可见=%s）" % [立绘可见, 底色可见])

	print("")
	if 失败项.is_empty():
		print("★★★ 全部通过：圆盘由 shader 平滑揭开，并被眼眶开孔裁成「嵌在眼眶里」的形状。")
		quit(0)
	else:
		print("### 有 %d 项失败：" % 失败项.size())
		for s in 失败项:
			print("  - " + s)
		quit(1)
