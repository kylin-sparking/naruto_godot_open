extends SceneTree

## 把人物面板每个装备格的**运行时状态**逐项打出来，找"为什么同一场景实例会渲染成两种样子"。
##
## 背景：用户报"很多装备槽是红色的"。客观取样确认过 —— 18 个空槽里 10 个底色 (58,33,27)（偏红）、
## 8 个 (35,28,27)；而**原版空装面板里 18 个槽是同一个色**（内部 (43,32,27)、框边 (90,55,47) 一带）。
## 所以那 10 个是 bug。但它们**是同一个 `装备格.tscn` 实例**，静态上看不出差别，
## 差别只可能在运行时状态里 —— 这个工具就是来把那些状态摊开的。
##
## 用法：
##   Godot --headless --path . --script res://开发工具/人物面板槽诊断.gd [-- --快照=<json>]

const 人物窗口脚本 := preload("res://脚本/界面/窗口/人物窗口.gd")
const 部位 := preload("res://脚本/单例/装备部位.gd")

var _快照 := ""


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2 and 键值[0] == "--快照":
			_快照 = 键值[1]
	call_deferred("_跑")


func _跑() -> void:
	var 窗场景 := load("res://场景/界面/功能窗口.tscn") as PackedScene
	var 窗 := 窗场景.instantiate()
	root.add_child(窗)
	await process_frame
	# 走真实入口开人物页（这样才和实机同一条路）
	if 窗.has_method("open_page"):
		窗.call("open_page", "人物")
	for _i in 30:
		await process_frame

	# ⚠️ 2026-10-01 修路径：`遮罩/主窗口/页面容器/…` 是多窗口改造前的旧结构，
	#    现在页面挂在窗口的 `_content` 下 ⇒ 用 find_child（与门同款走法）。
	#    格子也从 `装备栏` 直子层挪进了 `装备栏/装备格子容器`。
	var 面板 := 窗.find_child("原版人物属性面板", true, false)
	if 面板 == null:
		push_error("人物面板槽诊断：找不到 原版人物属性面板")
		quit(1)
		return
	var 栏 := 面板.get_node_or_null("装备栏")
	if 栏 == null:
		push_error("人物面板槽诊断：找不到 装备栏")
		quit(1)
		return
	var 格子区 := 栏.get_node_or_null("装备格子容器")
	if 格子区 != null:
		栏 = 格子区

	print("=== 装备栏下每个格子（按场景顺序）===")
	var 序 := 0
	for 子 in 栏.get_children():
		if not (子 is Button):
			continue
		var 钮 := 子 as Button
		var 位置: Variant = 钮.get("槽位号")
		print("%2d %-6s disabled=%-5s visible=%-5s 槽位号=%-6s modulate=%s self_modulate=%s 主题变体=%s icon=%s" % [
			序, 钮.name, 钮.disabled, 钮.visible, str(位置),
			str(钮.modulate), str(钮.self_modulate),
			str(钮.theme_type_variation),
			"有" if 钮.icon != null else "无",
		])
		# 覆盖层的可见性 —— `耐久红框` 名字里就带"红"，重点看它
		var 覆盖 := []
		for 名 in ["资质框", "破碎角标", "耐久红框", "强化底", "强化数字", "蓝钻", "镶嵌金钻"]:
			var 节 := 钮.get_node_or_null(名)
			if 节 != null and (节 as CanvasItem).visible:
				覆盖.append(名)
		if not 覆盖.is_empty():
			print("      ⚠️ 可见覆盖层: ", 覆盖)
		# 按钮的四个状态样式盒里，disabled 那个是不是被谁换过
		for 态 in ["normal", "disabled", "hover", "pressed"]:
			var 盒 := 钮.get_theme_stylebox(态)
			if 盒 != null:
				print("      %-9s → %s (%s)" % [态, 盒.get_class(), 盒.resource_path if 盒.resource_path != "" else "内建/override"])
		序 += 1

	print()
	print("=== 四个套装图标 ===
")
	for 名 in ["等阶套装", "全紫套装", "满星套装", "六级满融套装"]:
		# 套装图标在 `装备栏/套装图标/` 子容器里（`栏` 此时已被换成 装备格子容器，回父级找）
		var 图: TextureRect = null
		var 容器 := 栏.get_parent()
		if 容器 != null:
			图 = 容器.get_node_or_null("套装图标/%s" % 名) as TextureRect
		if 图 == null:
			print("  %-12s **没找到这个节点**" % 名)
			continue
		var 材 := 图.material
		print("     实际贴图 = ", 图.texture.resource_path if 图.texture != null else "null")
		print("  %-12s rect=(%.0f,%.0f) %s  贴图=%s  material=%s  材质着色器=%s" % [
			名, 图.position.x, 图.position.y, str(图.size),
			"有" if 图.texture != null else "**无**",
			"有" if 材 != null else "**无**",
			(材 as ShaderMaterial).shader.resource_path if 材 is ShaderMaterial and (材 as ShaderMaterial).shader != null else "-"])
	print()
	print("=== 对照：装备部位表里的顺序 ===")
	var 名表: Array = []
	for 位 in 部位.人物面板槽:
		名表.append(String(部位._显示名.get(位, "?")))
	print("  ", " ".join(名表))
	quit(0)
