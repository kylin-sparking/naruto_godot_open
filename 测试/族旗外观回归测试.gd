extends SceneTree
## 地图族旗「外观」回归门（离线）。
##
## 钉的是原版 `com.mxw.roles.Flag`：
##   * `Flag.as:307-322` `initializeLook()`：美术 `skin = flag_level`、`stand` 动作、
##     旗名牌 y=20 / 家族牌 y=38 / 家徽块在 `_namePane.y + 18 = 38`；
##   * `Flag.as:413-427` `setIcon()`：旗名牌 = `旗名 + "[<级>级族旗]"`、家族牌 = `"[家族]<族名>"`、
##     家徽 34×34 缩到 **18×18**、颜色 `new RoleNamePane(4059383)` = `#3DF0F7`；
##   * `Flag.as:352-366` `showHp()`：血条按 `hp/maxhp` 铺满、10 秒后自收。
## 以及 `data/flag/MapFlagInfo.as` 的 12 字段解析（`后端连接._解族旗行`）。
##
## 用法：Godot --headless --path . --script res://测试/族旗外观回归测试.gd

const 族旗 := preload("res://脚本/角色/族旗.gd")
const 后端: GDScript = preload("res://脚本/单例/后端连接.gd")
const 家徽图 := preload("res://脚本/界面/窗口/家族/家徽图.gd")

var _失败: Array[String] = []
## "外观这一节跑完了"的标记 —— 见 `_跑` 结尾那段（防"中途报错却打印通过"的假绿）。
var _外观跑完 := false


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	_查解析()
	await _查外观()
	# ⚠️ **"跑完了吗"也要断言**（2026-10-15 做反向对照时踩到）：GDScript 里一次
	#    `Invalid call`（例如被依赖的脚本编译失败 ⇒ `族旗.new()` 报错）会**当场中断 `_查外观`**，
	#    而 `_失败` 里可能一条都没有 ⇒ 门照样打印"通过"（那次假绿就是这么来的）。
	#    ⇒ 结尾放一个"这一节跑到最后一行"的标记，和 `_失败` 一起判。
	if not _外观跑完:
		_失败.append("外观一节没跑完（中途报错/提前返回 ⇒ 下面这些断言其实一条都没执行）")
	if _失败.is_empty():
		print("族旗外观回归测试：通过（12 字段解析 → 等级选美术 → 两行名牌/家徽+底框/血条/注册点）")
		quit(0)
		return
	for 条 in _失败:
		print("  !! " + 条)
	print("族旗外观回归测试：FAIL %d 条" % _失败.size())
	quit(1)


func _查解析() -> void:
	# 服务端 `_encode_local_flag_info` 的那一行（12 字段，顺序 = `MapFlagInfo.decode`）
	var 行 := "101010000&2372&1209&1&9&22&10000&10000&3&1000&0&22"
	var 解: Dictionary = 后端._解族旗行(PackedStringArray(行.split("&", true)))
	if 解.is_empty():
		_失败.append("12 字段没解出来")
		return
	var 期望 := {
		"map_id": 101010000, "x": 2372, "y": 1209, "channel": 1, "bang_id": 9,
		"bang_name": "22", "flag_hp": 10000, "flag_maxhp": 10000,
		"flag_level": 3, "flag_style": 1000, "flag_color": 0, "flag_name": "22",
	}
	for 键 in 期望:
		if 解.get(键) != 期望[键]:
			_失败.append("字段 %s 解成了 %s，应为 %s" % [键, 解.get(键), 期望[键]])
	if 后端._解族旗行(PackedStringArray(["1", "2"])).is_empty() == false:
		_失败.append("字段不足 12 个时应当返回空字典（否则会拿半截数据去建旗）")


func _查外观() -> void:
	# 每一级的美术都得齐。**范围是 1..10**：服务端 `flagLevel` 只有 1..10，
	# 包里也没有 `BangHui_0_stand.swf`（0 不是真实等级），别把 0 也当等级去要图。
	for 级 in range(1, 11):
		for 帧 in 族旗.帧数:
			var 路 := "%s旗_%d_%d.png" % [族旗.美术目录, 级, 帧]
			if not ResourceLoader.exists(路):
				_失败.append("缺美术 %s（`开发工具/导出族旗.py` 应导出 0~10 级各 4 帧）" % 路)
	var 根 := Node2D.new()
	root.add_child(根)
	var 旗: Node2D = 族旗.new()
	根.add_child(旗)
	旗.call("configure", {
		"map_id": 101010000, "x": 2372, "y": 1209, "channel": 1, "bang_id": 9,
		"bang_name": "22", "flag_hp": 5000, "flag_maxhp": 10000,
		"flag_level": 3, "flag_style": 1000, "flag_color": 0, "flag_name": "22",
	})
	await process_frame
	if 旗.position != Vector2(2372, 1209):
		_失败.append("落点应为服务端给的 (x,y)=(2372,1209)，实为 %s" % str(旗.position))
	var 精灵 := 旗.get_node_or_null("Sprite") as Sprite2D
	if 精灵 == null:
		_失败.append("没有 Sprite（等级 3 的美术没建起来）")
	else:
		if 精灵.texture == null or not String(精灵.texture.resource_path).ends_with("旗_3_0.png"):
			_失败.append("站立帧不是 `旗_3_0.png`（原版 `skin = flag_level` 是按等级取美术）")
		if 精灵.position.y >= 0.0:
			_失败.append("Sprite 没有上移（注册点应在节点原点、旗子往上立），实为 %s" % str(精灵.position))
	var 名牌们: Array[String] = []
	for 子 in 旗.get_children():
		if 子 is Label:
			名牌们.append((子 as Label).text)
	if not 名牌们.has("22[3级族旗]"):
		_失败.append("旗名牌文案不对：%s（应为 `旗名 + \"[3级族旗]\"`）" % str(名牌们))
	if not 名牌们.has("[家族]22"):
		_失败.append("家族牌文案不对：%s（应为 `\"[家族]\" + 族名`）" % str(名牌们))
	for 子 in 旗.get_children():
		if 子 is Label:
			var 色 := (子 as Label).get_theme_color("font_color")
			if absf(色.r - 0x3D / 255.0) > 0.01 or absf(色.g - 0xF0 / 255.0) > 0.01:
				_失败.append("名牌颜色不是 #3DF0F7（RoleNamePane(4059383)），实为 %s" % 色.to_html(false))
			break
	if 旗.get_node_or_null("家徽") == null:
		_失败.append("没有家徽节点（`PicTool.getJiaHuiPic(flag_style)` 那张 18×18 的图标）")
	elif 旗.get_node_or_null("家徽").scale.x < 0.5:
		_失败.append("家徽缩放不对：应为 18/34 ≈ 0.53，实为 %s" % str(旗.get_node_or_null("家徽").scale.x))
	else:
		# 底框（`Effect_CharStatus_Kuang` 20×20）：`Flag.as:419-421` 先 addChild 框、后 addChild 家徽，
		# 家徽内缩 1px（`_loc4_.x = _loc4_.y = 1`），整块宽取 20 ⇒ `_iconPane.x = -10`、家徽落 -9。
		var 徽 := 旗.get_node_or_null("家徽") as Sprite2D
		var 框 := 旗.get_node_or_null("底框") as Sprite2D
		if 家徽图.取底框() != null:
			if 框 == null:
				_失败.append("没画底框（`Effect_CharStatus_Kuang`，素材在 `素材/界面/原版窗口/家族/族徽底框.png`）")
			else:
				if 框.texture == null or not String(框.texture.resource_path).ends_with("族徽底框.png"):
					_失败.append("底框用的不是 族徽底框.png，实为 %s"
						% (框.texture.resource_path if 框.texture else "<空>"))
				if not is_equal_approx(框.position.x, -家徽图.底框边长 * 0.5):
					_失败.append("底框 x 应为 -20/2 = -10（`_iconPane.x = -width/2`），实为 %f" % 框.position.x)
				if not is_equal_approx(框.position.y, 族旗.家族牌Y) or not is_equal_approx(徽.position.y, 族旗.家族牌Y + 1.0):
					_失败.append("底框/家徽 y 应为 %f / %f（家族牌 y、内缩 1px），实为 %f / %f"
						% [族旗.家族牌Y, 族旗.家族牌Y + 1.0, 框.position.y, 徽.position.y])
				if 框.get_index() > 徽.get_index():
					_失败.append("底框排在家徽后面了 —— 同级按树序绘制，框必须在下层")
		elif 框 != null:
			_失败.append("底框素材不在却画了框（应退回只画家徽）")
		if not is_equal_approx(徽.position.x, -家徽图.底框边长 * 0.5 + 1.0):
			_失败.append("家徽 x 应为 -20/2 + 1 = -9（块宽按**底框**算，不是 -18/2），实为 %f" % 徽.position.x)
	# ⭐ **刚立起来的旗子不该有血条**：原版 `Flag.showHp` 是懒建的，只有挨打才第一次出现
	#    （用户 2026-10-11 实机确认"正常情况旗帜不应该显示血量"）。
	if 旗.get_node_or_null("血条") != null:
		_失败.append("刚建出来的旗子就带了血条 —— 原版是 `showHp()` 里按需懒建的，不该这样")
	# 掉血之后才亮，且按 hp/maxhp 铺
	旗.set("info", {"flag_hp": 5000, "flag_maxhp": 10000})
	旗.call("show_hp")
	await process_frame
	var 血条根 := 旗.get_node_or_null("血条")
	if 血条根 == null:
		_失败.append("`show_hp()` 之后仍然没有血条（懒建没生效）")
	elif not 血条根.visible:
		_失败.append("`show_hp()` 之后血条没显示")
	else:
		var 填充 := 血条根.get_children()[1] as ColorRect
		var 比 := 填充.size.x / 族旗.血条宽
		if absf(比 - 0.5) > 0.02:
			_失败.append("血条比例不对：5000/10000 应铺一半，实为 %.2f" % 比)
		旗.call("hide_hp")
		await process_frame
		if 血条根.visible:
			_失败.append("`hide_hp()` 之后血条还亮着（原版 `setTimeout(hideMobHpBar,10000)`）")
	_外观跑完 = true
