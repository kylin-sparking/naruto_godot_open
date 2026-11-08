extends SceneTree

## ⚠️ 加载的必须是**运行时真正加载的那个场景**（`地图资源.playable_scene_path()` →
##    `场景/生成/地图_<id>_烘焙.tscn`），不是 `场景/地图/地图场景.tscn`。
##    后者是**源场景**，只是烘焙的输入；168 张烘焙图没重烤时两者行为不一致 ——
##    2026-09-24 就因为"只改了源场景、168 张没重烤"整轮白干过。
##    `窗口行为契约体检.gd` / `窗口像素基线.gd` 早已显式断言路径含 `场景/生成/`，
##    本文件原来是漏的（拿源场景验等于验了个假），2026-09-25 补齐。

const 地图资源 := preload("res://脚本/地图/地图资源.gd")

const 默认地图 := "101010000"

var _failures: Array[String] = []
var _秒 := 0.0

## 中途崩（运行期错误掐断 `_run`）时 `_finish` 永远走不到，SceneTree 会一直空转、
## 被跑批器当「挂」杀掉；给个看门狗把挂转成红，至少能看见是哪条门。
func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 120.0:
		printerr("功能入口回归测试：看门狗超时（120s）—— 中途崩了没走到收尾")
		quit(1)
		return true
	return false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_verify_scene_ui_architecture()
	var 场景路径: String = 地图资源.playable_scene_path(默认地图)
	if not 场景路径.contains("场景/生成/"):
		_failures.append("加载的不是烘焙场景（%s）—— 实机走的是 playable_scene_path()，拿源场景验等于验了个假" % 场景路径)
		_finish()
		return
	print("功能入口回归测试：加载 ", 场景路径)
	var packed := load(场景路径) as PackedScene
	if packed == null:
		_failures.append("无法加载地图场景：%s" % 场景路径)
		_finish()
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	for _frame in range(5):
		await process_frame

	var session := root.get_node_or_null("GameSession")
	# 多窗口改造后没有名为「功能窗口」的固定节点了 —— 每个页面各自一个实例。
	# 用例要的是"功能窗口这一层能建出来并工作"，这里向窗口管理要人物那一份。
	var 管理 := scene.get_node_or_null("窗口管理")
	var feature_window: Node = 管理.call("取或建窗口", "人物") if 管理 != null else null
	var bottom_menu := scene.get_node_or_null("技能面板/技能栏") as Control
	if session == null or feature_window == null or bottom_menu == null:
		_failures.append("功能入口依赖节点不完整")
		_finish()
		return
	if bottom_menu.find_child("忍者传承Button", true, false) != null:
		_failures.append("技能栏仍显示忍者传承按钮")
	# 2026-10-25 用户：「左上角还有 vip 标志，帮我完整的删掉」⇒ 原版那颗徽记
	# （`CharactorInfoPane.as:532`，VIP<6 隐藏）连同节点一起摘了，这里钉**整颗不存在**。
	var vip_badge := scene.get_node_or_null("头像面板/头像区域/角色状态/VipBadge")
	if vip_badge != null:
		_failures.append("VIP 徽章应已整体删除（用户 2026-10-25），实测节点还在：%s" % vip_badge.get_path())
	var chat_panel := scene.get_node_or_null("聊天面板")
	var chat_content := scene.get_node_or_null("聊天面板/聊天内容") as Control
	if chat_panel == null or chat_content == null:
		_failures.append("聊天面板依赖节点不完整")
	else:
		# 2026-09-29 换成另一位开发者按原版 `ChatPane.as` 重建的那一版（节点名全中文）。
		# 老断言量的是我们旧实造版的英文节点名与 `_set_chat_expanded()`，已按新实现改写。
		var 面板底 := chat_content.get_node_or_null("面板底") as NinePatchRect
		var 消息窗口 := chat_content.get_node_or_null("消息窗口") as Control
		var 输入条 := chat_content.get_node_or_null("输入条") as Control
		var 页签 := chat_content.get_node_or_null("页签综合") as Control
		var 展开钮 := chat_content.get_node_or_null("展开钮") as Control
		var 滚动条 := chat_content.get_node_or_null("滚动条") as Control
		var 滚动下 := chat_content.get_node_or_null("滚动条/滚动下") as Control
		if 面板底 == null or 消息窗口 == null or 输入条 == null or 页签 == null or 展开钮 == null or 滚动条 == null or 滚动下 == null:
			_failures.append("聊天面板缺少独立背景、底栏或滚动控件")
		else:
			if not 输入条.visible:
				_failures.append("聊天输入底栏未使用独立可见素材")
			# 展开：`ChatPane.as:353-383` —— 面板底与滚动区**高 +200、y −200** 向上长，
			# 页签与输入行不动（新控制器由 `_摆展开几何()` 落这套几何）。
			chat_panel.set("_chat_expanded", true)
			chat_panel.call("_摆展开几何")
			await process_frame
			if not is_equal_approx(面板底.size.y, 399.0) or not is_equal_approx(面板底.position.y, -200.0):
				_failures.append("聊天展开后面板底几何不对（应 278×399 @ y=-200，实际 %s @ %s）"
					% [面板底.size, 面板底.position])
			if not is_equal_approx(消息窗口.size.y, 344.0):
				_failures.append("聊天展开后消息窗口没跟着长高")
			if 滚动下.position.y < 滚动条.get_node("滚动槽").size.y:
				_failures.append("聊天滚动下箭头压在滚动槽上")
			chat_panel.set("_chat_expanded", false)
			chat_panel.call("_摆展开几何")
			await process_frame
			if not is_equal_approx(面板底.size.y, 199.0) or not is_zero_approx(面板底.position.y):
				_failures.append("聊天收起后尺寸或位置未复位")

	# 10-12 #185 去掉了两条：「闭关经验」「挂机」。**原版那两颗钮不是功能窗入口** ——
	#   `guaJiBtn` = `guajiHandler.isStart = !isStart`（开关，`BreathPane.as:100-107`），
	#   `biGuanExpBtn` = `showLingquPane()`（开「领取修行收益」，`:72-82`）；
	#   开窗「智能托管打怪设置」的入口在原版是 **J 键「挂机设置」**（槽 15）与小地图那侧（#35，未做）。
	#   按钮自己那条路由由 `测试/那一排按钮回归测试.gd` 用真鼠标判，别在这里重复判一份。
	var features := ["人物", "背包", "忍术", "宠物", "任务", "组队", "好友", "家族", "商城", "设置"]
	var fixed_layouts := {
		"人物": "原版人物属性面板", "背包": "原版背包内容", "忍术": "原版忍术窗口内容",
		"宠物": "原版宠物窗口内容", "任务": "原版任务窗口内容", "组队": "原版组队窗口内容",
		"好友": "原版好友窗口内容", "家族": "原版家族窗口内容", "商城": "原版商城窗口内容",
		"设置": "原版系统设置内容", "闭关经验": "原版闭关窗口内容",
		# 10-12 #185：这两页**不再由底栏按钮进**（原版那三颗分别是"开关"和"开领取那扇"），
		# 但页面本身还得核"用的是原版布局"，所以留在这里、由下面那段按名字点收起版那颗进。
		"领取修行收益": "原版领取修行收益内容",
		"挂机": "原版挂机设置内容", "地图信息": "原版世界地图内容", "排行榜": "原版排行榜内容",
		"兑换": "原版礼品码内容", "活动": "原版活动窗口内容", "信息": "原版信息窗口内容",
		"签到": "原版开心有礼内容", "福利": "原版开心有礼内容",
		# 活跃度（原版 ActivityTaskWindow）—— 2026-09-27 合并对方「活跃度页」后新加的页。
		# ⚠️ 它是**独立窗口**，不是「福利 → 线上有礼」那一页；别因为名字像就并进去。
		"活跃度": "原版活跃度内容",
		"藏宝图": "原版亲热天堂内容", "挖矿": "原版宝石工艺内容", "首领": "原版首领窗口内容",
		"装备强化": "原版装备强化内容", "技能书": "原版秘籍合成内容", "遗址": "原版意志背包内容",
		"NPC商店": "原版NPC商店内容", "NPC仓库": "原版NPC仓库内容",
	}
	for feature_name in features:
		var button := _find_button(bottom_menu, feature_name)
		if button == null:
			_failures.append("缺少入口：%s" % feature_name)
			continue
		button.pressed.emit()
		await process_frame
		# 多窗口后每页是**各自的实例**，所以每轮要取回"该页那扇窗"再断言 ——
		# 不能像以前那样用一个 `feature_window` 从头的走到尾（那是换页时代的写法）。
		var 本页窗: Node = 管理.call("取窗口", feature_name) if 管理 != null else null
		if 本页窗 == null:
			_failures.append("入口没有为页面建出窗口：%s" % feature_name)
			continue
		if String(本页窗.get("_current_page")) != feature_name:
			_failures.append("入口未打开正确页面：%s" % feature_name)
		var content := 本页窗.get("_content") as Control
		if content == null or content.get_child_count() < 1:
			# 「家族」未入族时按原版**只有列表窗、主窗内容为空**是**真值**
			# （`FM.as:1222-1239` 二选一）；入族时这条判据照旧。
			var 在族 := session != null and bool((session.get("guild") as Dictionary).get("joined", false))
			if not (feature_name == "家族" and not 在族):
				_failures.append("页面没有有效内容：%s" % feature_name)
		elif content.find_child(String(fixed_layouts.get(feature_name, "")), true, false) == null:
			_failures.append("页面未使用原版固定布局：%s" % feature_name)
		elif feature_name == "背包" and content.find_child("原版背包内容", true, false) == null:
			_failures.append("背包页面未使用原版固定布局")
		elif feature_name == "背包":
			# 翻到第 2 页 → 触发一次重建 → 页码必须还在第 2 页。
			# 背景（2026-09-27 用户报"背包的装备拖到人物面板装备后，背包会自动返回第一页"）：
			# 页码原来是个 `static`、而且 `渲染()` 里每次都 `_当前页 = 0`；
			# 而"穿上装备"会触发 `equipment_changed` → `_refresh_current()` → 整页重建。
			# 现在页码存窗口上、只在开窗时复位。
			var 第二页 := content.find_child("第2页", true, false) as Button
			# 2026-10-31 每页 100 格：夹具容量 100 ⇒ 只有 1 页。这条腿验的是"翻页后重建不跳回"，
			# 临时把权威容量抬到 200（两页）再翻，验完还原（紧接着那条还会把容量改成 60）。
			var 后端页 := root.get_node_or_null("BackendConnection")
			var 容量前 := 0
			var 抬过 := false
			if (第二页 == null or not 第二页.visible) and 后端页 != null:
				容量前 = int(后端页.get("authoritative_bag_capacity"))
				抬过 = true
				后端页.set("authoritative_bag_capacity", 200)
				本页窗.call("_render_page")
				await process_frame
				第二页 = content.find_child("第2页", true, false) as Button
			if 第二页 == null or not 第二页.visible:
				_failures.append("背包页签「第2页」不可用（容量应 ≥ 200 才有第 2 页）")
			else:
				第二页.pressed.emit()
				await process_frame
				if int(本页窗.get("_背包页")) != 1:
					_failures.append("点了「第2页」但页码没变成 1")
					本页窗.call("_render_page")
				await process_frame
				if int(本页窗.get("_背包页")) != 1:
					_failures.append("背包被重建后打回了第一页（页码没存住）")
			if 抬过 and 后端页 != null:
				后端页.set("authoritative_bag_capacity", 容量前)
				本页窗.call("_render_page")
				await process_frame

			# 背包格数**必须跟着服务端的容量走**，不能退回兜底常量。
			# 背景（2026-09-27 用户报"活跃度奖励提示背包空间不足，实际上我背包是有空间的"）：
			# 服务端角色帧里那一格原来**写死 96**、客户端又没解析它，于是那条链一路退到
			# `格数回退 = 96`；而本机 `bag_capacity` 是 **90** —— 界面凭空多出 6 个空格，
			# 玩家以为放得下，服务端按 90 判"已满"并拒发奖励。两头都已修（见 §3.59 追加）。
			var 后端格数 := root.get_node_or_null("BackendConnection")
			if 后端格数 != null:
				var 原容量: Variant = 后端格数.get("authoritative_bag_capacity")
				后端格数.set("authoritative_bag_capacity", 60)
				本页窗.call("_render_page")
				await process_frame
				# §3.286 起格子数拆成独立尾巴 `_title_数值`（不走标题加粗变体），
				# 主标题只剩「背包」⇒ 必须把可见尾巴拼回来再判，否则必假红。
				var 标题 := (本页窗.get("_title") as Label)
				var 尾 := (本页窗.get("_title_数值") as Label)
				var 标题文 := ""
				if 标题 != null:
					标题文 += 标题.text
				if 尾 != null and 尾.visible:
					标题文 += 尾.text
				if not 标题文.ends_with("/60)"):
					_failures.append("背包标题没按服务端权威格数走：%s（应为 …/60)）"
						% (标题文 if not 标题文.is_empty() else "<无标题>"))
				# ⚠️ 无论断言结果如何都要还原（同活跃度那段：漏还原会污染后面所有断言）。
				后端格数.set("authoritative_bag_capacity", 原容量)
				本页窗.call("_render_page")
				await process_frame
		elif feature_name == "忍术":
			if content.find_child("原版忍术窗口内容", true, false) == null:
				_failures.append("忍术页面未使用原版固定布局")
			if content.find_child("忍术详情", true, false) == null:
				_failures.append("忍术页面缺少详情面板")
			if content.find_children("忍术格_*", "Button", true, false).is_empty():
				_failures.append("忍术树没有可交互忍术格")
		elif feature_name == "宠物" and content.find_child("原版宠物窗口内容", true, false) == null:
			_failures.append("宠物页面未使用原版固定布局")
		elif feature_name == "宠物":
			if DisplayServer.get_name() != "headless":
				_save_screenshot("宠物主窗")
			# §3.62 第 2 片重建后的原版结构断言（旧版钉的是自造「技能面板」入口，已删）：
			# ① 8 行属性名 = PET_PROP_STRS 逐行（自造版是 生命/查克拉/…6 行假属性）
			var 属性面板 := content.get_node_or_null("原版宠物窗口内容/属性底板/属性") as Control
			if 属性面板 == null or 属性面板.get_child_count() != 8:
				_failures.append("宠物属性区应为 8 行 TextThree（实际 %s）" % (属性面板.get_child_count() if 属性面板 != null else "无节点"))
			elif String((属性面板.get_child(0).get_node("名") as Label).text) != "增加主人生命值":
				_failures.append("宠物属性第 1 行名不对：%s" % (属性面板.get_child(0).get_node("名") as Label).text)
			# ② 四按钮在且文案随状态（无宠灰掉、有宠可点）
			#   ⚠ 2026-10-17：**别再按文案找按钮**。真值 §8 #2 的三态矩阵里，附身/出战
			#   在 SUMMON/ATTACK 态下文案是「回收」——玩档里只要有一只附身中的通灵兽，
			#   按「附身」找就恒找不到（本轮就吃了这条假红）。改成按**节点名**找 + 文案白名单。
			for 钮名 in ["附身", "驯养", "出战", "放生"]:
				var 钮 := content.get_node_or_null("原版宠物窗口内容/%s" % 钮名) as Button
				if 钮 == null:
					_failures.append("宠物页缺按钮：%s" % 钮名)
				elif 钮名 == "附身" and not (String(钮.text) in ["附身", "回收"]):
					_failures.append("宠物「附身」文案只能是 附身/回收（§8 #2），实测「%s」" % String(钮.text))
				elif 钮名 == "出战" and not (String(钮.text) in ["出战", "回收"]):
					_failures.append("宠物「出战」文案只能是 出战/回收（§8 #2），实测「%s」" % String(钮.text))
			# ③ 5 装备槽名 = PET_EQUIP_STRS（兽铠/兽盔/兽符/兽爪/变身）。
			#    ⚠️ 别用 find_child("装备槽_") 当存在性判断 —— find_child 是**精确名匹配**，
			#    前缀永远找不到，上一版这个 if-break 让整组断言**静默跳过**（反向对照不红，§3.61.5 同型）。
			var 槽名字表: Array[String] = []
			for 槽号 in [1, 2, 3, 4, 5]:
				var 格 := content.get_node_or_null("原版宠物窗口内容/装备槽_%d/槽名" % 槽号) as Label
				if 格 != null:
					槽名字表.append(String(格.text))
			for 槽名 in ["兽铠", "兽盔", "兽符", "兽爪", "变身"]:
				if not 槽名字表.has(槽名):
					_failures.append("宠物装备槽缺格子名：%s（实际 %s）" % [槽名, 槽名字表])
			# ④ 图标几何（§3.146 补；他 §14.1 那条"门只钉了格底、没钉图标 ⇒ 错了一整轮"的教训）：
			#    `MCell.drawIcon:68-69` 是 `icon.x = round((格宽 − 图标宽) >> 1)` —— **按原生尺寸居中、不缩放**；
			#    宠物技能图标原生 **34×34** ⇒ 技能格（40×40，内含 3px 内衬）落 (6,6)-(40,40)；
			#    装备槽落 (3,3)-(37,37)。我们原先烘的是 (8,8)-(32,32)=24×24 还把图标缩进去。
			for i in 8:
				var 图标 := content.get_node_or_null("原版宠物窗口内容/技能栏/技能格_%d/图标" % i) as TextureRect
				if 图标 == null:
					_failures.append("技能格_%d 没有图标节点" % i)
					continue
				if not (is_equal_approx(图标.offset_left, 6.0) and is_equal_approx(图标.offset_top, 6.0)
						and is_equal_approx(图标.size.x, 34.0) and is_equal_approx(图标.size.y, 34.0)):
					_failures.append("技能格_%d 图标该是 (6,6) 34×34（原生尺寸居中、不缩放），实测 %s %s"
							% [i, str(图标.position), str(图标.size)])
			for 槽号 in [1, 2, 3, 4, 5]:
				var 格 := content.get_node_or_null("原版宠物窗口内容/装备槽_%d/图标" % 槽号) as TextureRect
				if 格 == null:
					_failures.append("装备槽_%d 没有图标节点" % 槽号)
					continue
				if not (is_equal_approx(格.offset_left, 3.0) and is_equal_approx(格.offset_top, 3.0)
						and is_equal_approx(格.size.x, 34.0) and is_equal_approx(格.size.y, 34.0)):
					_failures.append("装备槽_%d 图标该是 (3,3) 34×34，实测 %s %s" % [槽号, str(格.position), str(格.size)])
			# ⑤b 六颗标签必须是**活的**（§3.146：它们其实是 `LinkButton` ⇒ `extends BaseButton`，
			#     以前那圈写成 `as Button` ⇒ 恒 null ⇒ `continue` ⇒ **六颗一颗都没接上、点了没反应**，
			#     而门里当时没有任何断言看得见。这里钉的正是"接线在不在"。）
			for 标签 in ["品级标题", "悟性标题", "攻击潜力标题", "防御潜力标题", "灵巧潜力标题", "健体潜力标题"]:
				var 标钮 := content.get_node_or_null("原版宠物窗口内容/%s" % 标签) as BaseButton
				if 标钮 == null:
					_failures.append("宠物页缺标签：%s" % 标签)
				elif 标钮.pressed.get_connections().is_empty():
					_failures.append("宠物「%s」没接处理器（它是 LinkButton，别用 `as Button` 取）" % 标签)
			# ⑤ 8 枚技能格是 `Button`，必须**关掉主题按钮皮** —— 否则格皮半透时橙按钮底会从底下透出来
			#    （他 §14.3：修完物品格 alpha 后像素门从 9.82% 涨到 89.61%，照出的正是这一条）。
			for i in 8:
				var 钮 := content.get_node_or_null("原版宠物窗口内容/技能栏/技能格_%d" % i) as Button
				if 钮 == null:
					continue
				for 态 in ["normal", "hover", "pressed", "disabled"]:
					if 钮.get_theme_stylebox(态) != null and not (钮.get_theme_stylebox(态) is StyleBoxEmpty):
						_failures.append("技能格_%d 的 `%s` 还挂着主题按钮皮（该是 StyleBoxEmpty）" % [i, 态])
			# ③b 几何：关键控件的**窗口局部矩形**必须等于 AS3 值。
			#    ⚠️ 这条防的是一类**系统性**偏差：页面容器原点是窗口局部 (8,38)，
			#    而宠物页第一版按旧自造场景的换算（AS3−(10,41)）铺的 → **整页偏 (2,3)px**，
			#    当时所有"页内相对关系"看着都对，只有换算到窗口坐标才露馅。
			#    出处：PetWindow.as 的 `_leftUpSkin.x = BORDER_GAP+CONTENT_GAP`(=13)、
			#    `y = CONTENT_GAP+BORDER_GAP+27`(=40)。
			var 窗口 := 本页窗.get("_window") as Control
			var 期望 := {"列表底板": Rect2(13, 40, 177, 136), "属性底板": Rect2(13, 181, 177, 170),
				"装备面板": Rect2(195, 40, 236, 108), "附身": Rect2(200, 190, 37, 22)}
			for 名 in 期望:
				var 控件 := content.get_node_or_null("原版宠物窗口内容/%s" % 名) as Control
				if 控件 == null:
					_failures.append("宠物页缺控件：%s" % 名)
					continue
				var 实 := Rect2(控件.get_global_rect().position - 窗口.get_global_rect().position, 控件.size)
				if not 实.position.is_equal_approx(期望[名].position):
					_failures.append("宠物页 %s 的窗口坐标 %s ≠ AS3 的 %s（页面容器原点是 (8,38)，别用别的换算）"
						% [名, 实.position, 期望[名].position])

			# ④ 扩展兽栏行为：**压到小容量再渲染**，逼它显形后验"可见且可点"。
			#    （离线默认容量 10，按原版 MaxSolt 规则扩展行本来就不出，测不到任何东西。）
			var 原容量: int = session.pet_capacity
			session.pet_capacity = 4
			本页窗.call("_render_page")
			await process_frame
			var 扩展行 := content.get_node_or_null("原版宠物窗口内容/列表滚动/宠物列表/扩展兽栏") as Button
			if 扩展行 == null:
				_failures.append("扩展兽栏节点缺失")
			else:
				if not 扩展行.visible:
					_failures.append("容量 4 时扩展兽栏行没出现（原版应在第 4 行）")
				elif 扩展行.disabled:
					_failures.append("可见的扩展兽栏行被禁用（空壳）")
				# ★ 2026-10-11：上面 `not disabled` 是**假绿** —— 钮不禁用≠接了线。真正的判据是
				#   "点下去有反应"：原版 `PetWindow.as:366-370` 点开 `EnlargeWindow` 并
				#   `setData(curSoltNum − 3, 2)`（归属号 2 = 兽栏）。这里点一下，验窗口真的开了、
				#   归属/需要数对得上（并反证"点了什么也不发生"那条空壳形状）。
				elif not 扩展行.pressed.get_connections().is_empty():
					var 扩容窗 := content.get_node_or_null("原版宠物窗口内容/扩容窗口") as Control
					if 扩容窗 == null:
						_failures.append("宠物页缺「扩容窗口」节点（扩展兽栏点不开）")
					else:
						扩展行.pressed.emit()
						await process_frame
						if not 扩容窗.visible:
							_failures.append("点「扩展兽栏」后「扩容窗口」没开（空壳钮）")
						else:
							var 需 := 扩容窗.get_node_or_null("需要数") as Label
							var 询 := 扩容窗.get_node_or_null("询问") as Label
							# 容量 4 ⇒ max(1, 4−3) = 1（与 `_extend_pet_capacity` 同式）
							if 需 == null or not 需.text.contains("1"):
								_failures.append("兽栏扩容窗「需要数」应是 1（容量4−3），实际「%s」" % [需.text if 需 != null else "无"])
							if 询 == null or not 询.text.contains("兽栏"):
								_failures.append("兽栏扩容窗询问文案不对：%s" % [询.text if 询 != null else "无"])
							扩容窗.call("隐藏")
				else:
					_failures.append("「扩展兽栏」钮没有任何 pressed 接线（点下去什么也不发生）")
			session.pet_capacity = 原容量
			本页窗.call("_render_page")
			await process_frame
		elif feature_name == "任务" and content.find_child("原版任务窗口内容", true, false) == null:
			_failures.append("任务页面未使用原版固定布局")
		elif feature_name == "组队" and content.find_child("原版组队窗口内容", true, false) == null:
			_failures.append("组队页面未使用原版固定布局")
		elif feature_name == "组队":
			# 页签名真值取自原版语言表（别照旧场景抄：旧场景写的是「我的配偶/配偶列表」，
			# 原版是 `TROOP_WINDOW_WODE_PEIOU`=我的羁绊、`TROOP_TAB_BTN_MARRY_LIST`=酒宴列表）：
			# `TroopWindow2.as:115` 的 `tabBtnNames` 五枚 + `en_US$message_properties.as`。
			for tab_name in ["我的队伍", "附近队伍", "附近玩家", "我的羁绊", "酒宴列表"]:
				if _find_button_text(content, tab_name) == null:
					_failures.append("组队页面缺少原版分页：%s" % tab_name)
		elif feature_name == "好友" and content.find_child("原版好友窗口内容", true, false) == null:
			_failures.append("好友页面未使用原版固定布局")
		elif feature_name == "好友":
			for tab_name in ["好友", "师徒", "仇人", "黑名单", "最近"]:
				if _find_button_text(content, tab_name) == null:
					_failures.append("好友页面缺少原版分页：%s" % tab_name)
		elif feature_name == "家族" and content.find_child("原版家族窗口内容", true, false) == null:
			_failures.append("家族页面未使用原版固定布局")
		elif feature_name == "家族":
			# 另一位开发者的家族页（2026-09-29 合并）：**节点名就是动作名**（说明 §2 的动作串口径），
			# 不像别的页那样靠 tooltip 找 —— 改成按节点名取，并顺手钉"点了有反应"（不是空壳钮）。
			var 家族页根 := content.get_node_or_null("原版家族窗口内容")
			if 家族页根 == null:
				家族页根 = content
			for action_name in ["家族列表", "家族升级", "家族技能", "家族尾兽", "家族旗帜", "家族贡献", "家族商店", "成员信息"]:
				var 钮 := 家族页根.get_node_or_null(action_name) as BaseButton
				if 钮 == null:
					_failures.append("家族页面缺少原版入口：%s" % action_name)
				elif 钮.pressed.get_connections().is_empty():
					_failures.append("家族入口「%s」没接处理器（空壳钮）" % action_name)
		elif feature_name == "商城" and content.find_child("原版商城窗口内容", true, false) == null:
			_failures.append("商城页面未使用原版固定布局")
		elif feature_name == "商城":
			# 九个页签**烘在场景里**（§3.138）—— 以前是运行期 `Button.new()` 现造、**没有名字**，
			# 这一段正是以前寻址不到、断言不了的东西（§3.113 规矩 5）。
			var 页签们: Array = 本页窗.call("_取商城分页表").get("页签", [])
			var 分页条 := content.find_child("分页", true, false) as Control
			if 分页条 == null:
				_failures.append("商城页找不到 `分页` 容器")
			else:
				var 烘的 := 分页条.get_children()
				if 烘的.size() != 页签们.size():
					_failures.append("商城页签该烘 %d 枚、实测 %d 枚" % [页签们.size(), 烘的.size()])
				for i in mini(页签们.size(), 烘的.size()):
					var 签名钮 := 烘的[i] as Button
					if 签名钮 == null:
						_failures.append("商城页签%d 不是 Button" % i)
						continue
					if String(签名钮.name) != "页签%d" % i:
						_failures.append("商城第 %d 枚页签该叫「页签%d」，实测「%s」（没名字 ⇒ 门寻址不到）"
								% [i, i, 签名钮.name])
					if 签名钮.text != String(页签们[i]):
						_failures.append("商城页签%d 文字该是「%s」，实测「%s」" % [i, 页签们[i], 签名钮.text])
					if 签名钮.theme_type_variation != &"OrigTab":
						_failures.append("商城页签%d 的皮该走变体 `OrigTab`，实测 `%s`"
								% [i, 签名钮.theme_type_variation])
				# 选中态：**恰好一枚**，而且走的是 `disabled` 槽（`MTabButton` 既有口径，§3.138）
				var 选中 := 0
				for i in 烘的.size():
					var 钮 := 烘的[i] as Button
					if 钮 != null and 钮.disabled and 钮.button_pressed:
						选中 += 1
				if 选中 != 1:
					_failures.append("商城页签该**恰好一枚**处于选中态（disabled+button_pressed 同置），实测 %d 枚" % 选中)
		elif feature_name == "设置" and content.find_child("原版系统设置内容", true, false) == null:
			_failures.append("设置页面未使用原版固定布局")
		elif feature_name == "设置":
			# 另一位开发者的设置页（2026-10-01 合并）。原版三枚页签里「快速键」**不是切页**，
			# 而是**开关式弹独立窗**（`SCW:264` → `UM2:3133-3146 setKeyboardWindowvisible`）
			# ⇒ 旧那条"在页里找「向左移动快捷键」按钮"已经不适用（那是旧自造页的控件，
			# 新页里根本没有，照旧写会恒红）。
			# 改成验**真链路**：点「快速键」页签 ⇒ `request_feature("快捷键")`
			# ⇒ `窗口管理` 里那扇独立窗真的开出来。
			var 快页 := content.get_node_or_null("原版系统设置内容/页签快速键") as BaseButton
			if 快页 == null:
				快页 = content.get_node_or_null("页签快速键") as BaseButton
			if 快页 == null:
				_failures.append("设置页缺「快速键」页签")
			else:
				快页.pressed.emit()
				await process_frame
				var 快窗: Node = 管理.call("取窗口", "快捷键") if 管理 != null else null
				if 快窗 == null or not bool(快窗.call("已打开")):
					_failures.append("点「快速键」后快捷键独立窗没开（原版是开关式弹窗，不是页内换页）")
		if DisplayServer.get_name() != "headless":
			_save_screenshot(feature_name)

	var 那一排 := scene.get_node_or_null("技能面板/技能栏") as Control
	if 那一排 != null:
		# 展开版第三颗 = 原版 `showLingquPane()` ⇒ 开「领取修行收益」
		var 领钮 := 那一排.get_node_or_null("闭关经验Button") as BaseButton
		if 领钮 == null or 领钮.pressed.get_connections().is_empty():
			_failures.append("展开版第三颗（闭关经验Button）没绑定 —— 原版它调 showLingquPane()")
		else:
			# ⚠ 点**那颗钮本身**（不是替它调 request_feature）—— 否则这条判的是"页面能开"，
			#   不是"这颗钮接对了页"（10-12 的口径：入口门必须走按钮自己那条信号）。
			领钮.pressed.emit()
			await process_frame
			if _当前页(管理, "领取修行收益") != "领取修行收益":
				_failures.append("第三颗那条链没把「领取修行收益」开出来")
			var 领内容 := _页内容(管理, "领取修行收益")
			if 领内容 == null or 领内容.find_child("原版领取修行收益内容", true, false) == null:
				_failures.append("「领取修行收益」页没按原版布局渲染")
		# 收起版那颗 = 原版 `showBiguanWindow()` ⇒ 开「修行设定与收益」（两版开的**不是**同一扇）
		var 修钮 := 那一排.get_node_or_null("精华收起/修Button") as BaseButton
		if 修钮 == null or 修钮.pressed.get_connections().is_empty():
			_failures.append("收起版那颗（修Button）没绑定 —— 原版它调 showBiguanWindow()")
		else:
			修钮.pressed.emit()
			await process_frame
			var 闭内容 := _页内容(管理, "闭关经验")
			if 闭内容 == null or 闭内容.find_child("原版闭关窗口内容", true, false) == null:
				_failures.append("收起版那颗没把「修行设定与收益」按原版布局开出来")
		# 「智能托管打怪设置」这页：原版的入口是 **J 键「挂机设置」**（槽 15），
		# 而本工程那四个原版键位还没接（与本地 普攻/移动 撞，等点头）⇒ 现在**游戏里没有入口**。
		# 这一条只证明"页面本身还在、还是原版布局"，不证明有入口 —— 别把它当入口过了。
		session.request_feature("挂机")
		await process_frame
		var 挂内容 := _页内容(管理, "挂机")
		if 挂内容 == null or 挂内容.find_child("原版挂机设置内容", true, false) == null:
			_failures.append("「挂机设置」页没按原版布局渲染")

	# ⚠ 这颗钮**按节点名找**，不再按 tooltip 找：10-12 #185 把提示换成原版原句
	#   （`CN.MENU_PRACTISE_BTN_TIP_TEXT_1` = "打坐/取消打坐" + "，快速键：无"），
	#   原来那句自造的"打坐"两个字已经没了。
	var 面板 := scene.get_node_or_null("技能面板") as Node
	var practise_button := 那一排.get_node_or_null("打坐Button") as BaseButton if 那一排 != null else null
	var player := scene.get_tree().get_first_node_in_group("player")
	if practise_button == null or practise_button.pressed.get_connections().is_empty():
		_failures.append("打坐按钮未按原版绑定")
	elif player == null or not player.has_method("toggle_practise"):
		_failures.append("玩家缺少原版打坐状态切换")
	else:
		player.set("on_ground", true)
		# 原版 `HealHandler` 那条分支带 1 秒防抖（`requestCDlast`），量具要连着点两次就得先放行；
		# 防抖本身由 `测试/那一排按钮回归测试.gd` 用真鼠标判（那条判的是"不放行就不许生效"）。
		if 面板 != null:
			面板.set("_上次打坐毫秒", -1000000)
		practise_button.pressed.emit()
		await process_frame
		if not bool(player.get("is_practising")):
			_failures.append("打坐按钮未进入 sit0 状态")
		if _当前页(管理, "人物") == "修炼":
			_failures.append("打坐按钮仍错误打开修炼窗口")
		if 面板 != null:
			面板.set("_上次打坐毫秒", -1000000)
		practise_button.pressed.emit()
		await process_frame
		if bool(player.get("is_practising")):
			_failures.append("打坐按钮无法取消打坐")

	# ⚠️ 这一串是**手写列举**的，不是遍历 `fixed_layouts` —— 往 `fixed_layouts` 里加一条
	#    而忘了往这里加，那条就**永远不会被跑到**（看着像"覆盖了"，其实是假绿）。
	#    活跃度就是 2026-09-27 这么漏过一次：先只加了 fixed_layouts，用例照样全绿。
	for extra_page in ["地图信息", "排行榜", "活跃度"]:
		session.request_feature(extra_page)
		await process_frame
		if _当前页(管理, extra_page) != extra_page:
			_failures.append("扩展入口未打开：%s" % extra_page)
		var content := _页内容(管理, extra_page)
		if content == null or content.find_child(String(fixed_layouts.get(extra_page, "")), true, false) == null:
			_failures.append("扩展页未使用原版固定布局：%s" % extra_page)
		# 活跃度页还要证明**它是活的**：15 行任务与 8 档奖励都得按数据填出来，
		# 不是"场景加载成功就算过"（那种过法连数据没接上都看不出来）。
		elif extra_page == "活跃度":
			var 列表 := content.find_child("任务列表", true, false)
			var 行数 := 列表.get_child_count() if 列表 != null else -1
			if 行数 != 15:
				_failures.append("活跃度页任务行应为 15 行，实际 %d" % 行数)
			var 档数 := 0
			for i in range(1, 12):
				if content.find_child("奖励%d" % i, true, false) != null:
					档数 += 1
			if 档数 != 8:
				_failures.append("活跃度页奖励档应为 8 档，实际 %d" % 档数)
			var 条文本 := content.find_child("条文本", true, false) as Label
			if 条文本 == null or not 条文本.text.contains("/150"):
				_failures.append("活跃度页底部条文本未按数据填充（应形如 N/150）")
			# 行上的三个动作（原版 `ActivityTaskPaneCell`）要**真的绑上**：
			#   链接 open=1 → 打开窗口；open=2 → 走本图 NPC；小鸟 → 跨图传送（4027）。
			# ⚠️ 小鸟 的 `mouse_filter` 场景烘的是 **IGNORE**，不改成 STOP 就永远收不到鼠标 ——
			#    这条断言就是防"哪天顺手改回去"。
			if 列表 != null:
				for 序 in 列表.get_child_count():
					var 行 := 列表.get_child(序) as Control
					var 链接 := 行.get_node_or_null("链接") as Label
					if 链接 == null or 链接.gui_input.get_connections().is_empty():
						_failures.append("活跃度页第 %d 行的链接没绑动作" % (序 + 1))
						break
				for 序 in 列表.get_child_count():
					var 鸟 := (列表.get_child(序) as Control).get_node_or_null("小鸟") as TextureRect
					if 鸟 != null and 鸟.mouse_filter != Control.MOUSE_FILTER_STOP:
						_failures.append("活跃度页第 %d 行的小鸟点不动（mouse_filter 不是 STOP）" % (序 + 1))
						break
			# 底部那颗「领取奖励」也要查同一个形状：**凡是可点的，必须接了处理器**。
			# 与福利各页那条同源（2026-09-27 用户报"看着能点、点了没反应"）。
			var 领取奖励 := content.find_child("领取奖励", true, false) as Button
			if 领取奖励 == null:
				_failures.append("活跃度页缺「领取奖励」按钮")
			elif not 领取奖励.disabled and 领取奖励.pressed.get_connections().is_empty():
				_failures.append("活跃度页的「领取奖励」可点却没接处理器")

			# ---- 正向：**符合条件时它必须真的能点** ----
			# 上面那条只证明"没坏"（离线数据是空的，按钮本来就该灰）。用户报的是
			# "已经符合条件却不能领取"，所以要**注入一份可领状态再渲染一次**，
			# 验的是"达标之后按钮真的活过来、而且点了有处理器"。
			# ⚠️ 活跃度页读 `authoritative_activity` 时**不看 `in_game`**，所以离线注入有效。
			var 后端 := root.get_node_or_null("BackendConnection")
			if 后端 != null:
				var 旧状态: Variant = 后端.get("authoritative_activity")
				后端.set("authoritative_activity", {
					"task_counts": [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
					"claimed_level": -1, "points": 150,
				})
				var 活跃度窗: Node = 管理.call("取窗口", "活跃度")
				if 活跃度窗 != null:
					活跃度窗.call("_render_page")
				await process_frame
				var 可领钮 := content.find_child("领取奖励", true, false) as Button
				if 可领钮 == null:
					_failures.append("活跃度页重渲染后找不到「领取奖励」")
				elif 可领钮.disabled:
					_failures.append("活跃度满分 150 时「领取奖励」仍是灰的（应该可领）")
				elif 可领钮.pressed.get_connections().is_empty():
					_failures.append("活跃度「领取奖励」可领却没接处理器")
				# ⚠️ 无论断言结果如何都要还原 —— 只在某个分支里还原的话，
				#    注入的那份"满分活跃度"会漏给后面所有断言（第一版就是这样）。
				后端.set("authoritative_activity", 旧状态)

			# ---- 小地图活跃度图标的呼吸光晕：**有奖励可领才挂** ----
			# 原版 `SmallMapWindow.setHuoyueduBtn:418-433`：true 才挂 GlowFilter 的
			# ENTER_FRAME，false 时 `filters = null`（光晕整块消失），判据是
			# `ActivityTaskWindow.setDataBottom:272-282` 的 `param1 < 7 && levelArr[param1+1] <= param2`。
			# 门槛真值取 `数据/活跃度奖励.json` 前两档的 reqScore = 10 / 20（写死，不读被测常量）。
			# 本工程的光晕是烘好的 AnimatedTexture ⇒ 「闪不闪」就是这颗节点的 visible。
			var 光晕 := scene.get_node_or_null("小地图面板/小地图区域/小地图/常驻活动图标/活跃度光晕") as TextureRect
			if 光晕 == null:
				_failures.append("小地图缺活跃度光晕节点（原版 _huoyueduBtn 的 GlowFilter）")
			elif 后端 == null:
				_failures.append("测试环境缺 BackendConnection：活跃度光晕无法验")
			else:
				var 光晕旧状态: Variant = 后端.get("authoritative_activity")
				for 用例 in [
					[{"claimed_level": -1, "points": 9}, false, "连第一档都不够（9/10）"],
					[{"claimed_level": -1, "points": 10}, true, "第一档刚好够（10 分）"],
					[{"claimed_level": 0, "points": 19}, false, "第一档已领、第二档还差 1 分（19/20）"],
					[{"claimed_level": 0, "points": 20}, true, "第二档刚好够（20 分）"],
					[{"claimed_level": 7, "points": 150}, false, "八档全领完，没得领了"],
				]:
					后端.set("authoritative_activity", 用例[0])
					后端.emit_signal("activity_state_received", 用例[0])
					if 光晕.visible != 用例[1]:
						_failures.append("活跃度光晕：%s 时应%s，实际%s"
							% [用例[2], "闪" if 用例[1] else "不闪", "闪" if 光晕.visible else "不闪"])
				后端.set("authoritative_activity", 光晕旧状态)
				后端.emit_signal("activity_state_received", 光晕旧状态)
		if DisplayServer.get_name() != "headless":
			_save_screenshot(extra_page)

	# ---- 福利六个子页（`福利` 不在上面的 features 列表里，所以单独走一遍）----
	# 六个子页**逐页**走一遍（`_render_prize_window` 只填当前页签，不切过去等于没验），
	# 每一页都查：「看着能点、点了没反应」的空壳按钮不许存在。
	#
	# 背景（2026-09-27 用户报"这些面板还是不能领取奖励，即便已经符合条件"）：
	# 福利窗口里那几个领取钮在 `.tscn` 里烘的是 `disabled = false`，而各子页的填充函数
	# 拿不到数据时会**直接 return** —— 按钮既没置灰、也没接处理器，用户点了**什么都不发生**。
	# ⚠️ 不能加 `is_visible_in_tree()` 过滤：那会把 5 个没选中的页签整个跳过去，
	#    而空壳恰恰就藏在那些页里（第一版就是这么写的，反向对照**没能变红**才发现的）。
	# 判据：文字里带「领取/签到」的按钮，要么置灰，要么接了 `pressed`。
	# ⚠️ 这个用例里没有别人会去开福利窗（`福利` 既不在 `features` 里，也不在 extra_page 里），
	#    所以必须**自己先 request_feature 开一次** —— 否则 `取窗口` 返回 null、循环直接 break，
	#    整段断言变成空转（第一版就是这样，反向对照没能变红才发现）。
	session.request_feature("福利")
	await process_frame
	var 福利窗: Node = 管理.call("取窗口", "福利") if 管理 != null else null
	if 福利窗 == null:
		_failures.append("福利窗口没能建出来")
	var 子页名 := ["每日签到", "线上有礼", "首杀礼包", "活动奖励", "限时大奖", "新服有礼"]
	for 页号 in 子页名.size():
		if 福利窗 == null:
			break
		福利窗.set("_prize_tab", 页号)
		福利窗.call("_render_page")
		await process_frame
		var 本页内容 := 福利窗.get("_content") as Control
		if 本页内容 == null:
			continue
		# ⚠️ **只查当前页签那棵子树**：切页签会整页重建（`_render_prize_window` 每次都
		#    `_instantiate_page`），没被选中的那 5 页停在烘死的状态、用户也永远点不到 ——
		#    把它们一起算进来会报一堆假阳性（第一版全页扫，报的 6 条全是非当前页）。
		# ⚠️ 必须从 `滚动区/内容` 取子页 —— **不能 `find_child(子页名)`**：
		#    页签按钮与内容页**同名**（`分页/新服有礼` 与 `滚动区/内容/新服有礼`），
		#    `find_child` 按树序会先命中页签那颗按钮，于是整段检查扫了个空、永远绿
		#    （反向对照没能变红才发现）。
		var 滚动区 := 本页内容.find_child("滚动区", true, false)
		var 本子页 := 滚动区.get_node_or_null("内容/%s" % 子页名[页号]) as Control if 滚动区 != null else null
		if 本子页 == null:
			_failures.append("福利第 %d 页缺子页节点：%s" % [页号, 子页名[页号]])
			continue
		for 节点 in 本子页.find_children("*", "Button", true, false):
			# ⚠️ 必须限定 `Button` —— `TextureButton`（礼包入口那类）**没有 `text` 属性**，
			#    写成 `BaseButton` 会在这句报 "Invalid access to property or key 'text'"
			#    并把整段检查打断，于是断言永远绿（反向对照没能变红才发现）。
			var 钮 := 节点 as Button
			if 钮 == null or 钮.disabled:
				continue
			if not (钮.text.contains("领取") or 钮.text.contains("签到")):
				continue
			if 钮.pressed.get_connections().is_empty():
				_failures.append("福利「%s」页有可点却没接处理器的领取钮：%s（%s）"
					% [子页名[页号], 本子页.get_path_to(钮), 钮.text])
				break
		if DisplayServer.get_name() != "headless":
			_save_screenshot("福利第%s页" % 子页名[页号])

	# ---- 掉落物：**每一个都有名字标签，而且常显** ----
	# 原版 `DropItemSprite.render()` 给每种掉落物都建一个 `RoleNamePane`（`_namePane`），
	# 建时 `visible=false`，但 `tick()` 一进屏就置 true（`:469-473`）→ **常显**。
	# 文案：金币 = `_itemid + "金币"`（`_itemid` 对金币就是**数量**）；物品 = 物品名。
	# 用户 2026-09-27 给的并排图：我们这边**物品掉落完全没有名字**、金币只写死"金币"（丢了数量）。
	var 生命根 := scene.get_node_or_null("LifeRoot")
	if 生命根 == null or not 生命根.has_method("_on_server_drop_spawned"):
		_failures.append("地图里没有 LifeRoot —— 掉落物名字没地方验")
	else:
		var 当前图 := int(生命根.call("_get_current_map_id"))
		生命根.call("_on_server_drop_spawned", {
			"object_id": 990001, "is_meso": true, "item_id": 35,
			"x": 1178.0, "y": 900.0, "from_x": 1150.0, "from_y": 820.0, "map_id": 当前图,
		})
		生命根.call("_on_server_drop_spawned", {
			"object_id": 990002, "is_meso": false, "item_id": 1010013, "item_name": "小太刀",
			"x": 1200.0, "y": 900.0, "from_x": 1170.0, "from_y": 830.0, "map_id": 当前图,
		})
		await process_frame
		var 掉落表: Dictionary = 生命根.get("_server_drops")
		var 金 := _掉落名(掉落表, 990001)
		var 物 := _掉落名(掉落表, 990002)
		if 金 == null or 金.text != "35金币":
			_failures.append("金币掉落的名字应为「35金币」（原版是**数量**+金币），实际 %s"
				% (金.text if 金 != null else "<没有名字标签>"))
		if 物 == null or 物.text != "小太刀":
			_failures.append("物品掉落应有物品名标签，实际 %s"
				% (物.text if 物 != null else "<没有名字标签>"))
		# 金币掉落还要有**图标本体** —— 原版 `PicTool.getMesoPic(数量)` 的四档钱堆动画
		# （`ItemPic.TYPE_MESO`），不是"只有一行文字"。素材在 素材/物品/原版/FuZhuWuPin/。
		var 金节点 := 掉落表.get(990001) as Node
		var 金图标 := 金节点.get_node_or_null("DropIcon") as TextureRect if 金节点 != null else null
		if 金图标 == null or 金图标.texture == null:
			_failures.append("金币掉落没有图标（应有四档钱堆动画中的一档）")
		elif not (金图标.texture is AnimatedTexture):
			_failures.append("金币掉落的图标应是 4 帧动画（AnimatedTexture），实际 %s"
				% 金图标.texture.get_class())
		elif (金图标.texture as AnimatedTexture).frames != 4:
			_failures.append("金币图标应是 4 帧，实际 %d 帧"
				% (金图标.texture as AnimatedTexture).frames)
		# ---- 两段动画：出场抛物线 / 拾取上浮 ----
		# 真值 `DropItemSprite.tick()`：出场 800ms 从 `from_*` 抛到落点，顶点在
		# `min(fromY,toY) - 115`，落点抬高 15；拾取 600ms、alpha 掉到 0.3、朝拾取者飘。
		var 物节点 := 掉落表.get(990002) as Node2D
		if 物节点 == null:
			_failures.append("物品掉落没建出来（动画没得验）")
		else:
			if not bool(物节点.get_meta("drop_air", false)):
				_failures.append("掉落物刚生成时应在**飞行中**（原版从怪物身上抛出）")
			# ⚠️ 不能要求"正好等于起点"：夹在中间 `await process_frame` 会让 `_process`
			#    先推一两帧（实测差 ~5px）。判"还在起点附近"就够。
			if 物节点.position.distance_to(Vector2(1170.0, 830.0)) > 30.0:
				_failures.append("掉落物生成时应从**起点**（怪物身上）出发，实际 %s" % 物节点.position)
			var 名字节点 := 物节点.get_node_or_null("DropName") as Label
			if 名字节点 != null and 名字节点.visible:
				_failures.append("飞行途中不该显示名字（原版 :386-389）")
			# 推 0.9 秒（> 800ms）—— 用假步长，不依赖真实帧率
			生命根.call("_推进掉落动画", 0.9)
			if bool(物节点.get_meta("drop_air", false)):
				_failures.append("推 0.9 秒后掉落物应已落地")
			elif not 物节点.position.is_equal_approx(Vector2(1200.0, 900.0 - 15.0)):
				_failures.append("落点应为 (x, y-15)，实际 %s" % 物节点.position)
			elif 名字节点 != null and not 名字节点.visible:
				_failures.append("落地后应显示名字")
			# ---- 拾取这条链：动画**由服务端回帧的 animation 字段驱动** ----
			# 原版 `RemoveItemInfo.decode()`：0=过期 1=无动画 **2=拾取** 5=宠物捡；
			# `DropItemHandler.removeDropItem():401-422` ⇒ `animation >= 2` 才
			# `removeItemPickUp()`（起动画 + `picker` = 回帧那个 cid），否则 `removeItem()` 当场消失。
			# ① 只发请求 ⇒ 本地**不许**自己播
			生命根.call("_发拾取", 990002)
			if bool(物节点.get_meta("drop_picking", false)):
				_failures.append("刚发拾取请求就自己起动画 ⇒ 没等服务端回帧（旧 bug）")
			# ② 回帧 animation=1（无动画）⇒ 当场移除、不播
			生命根.call("_on_server_drop_removed", 990002, 1, 0, false)
			if 掉落表.has(990002):
				_failures.append("animation=1（无动画）应当场移除，不该留在表里")
			# ③ 回帧 animation=2（拾取）⇒ 起动画，推完 0.7 秒（> 600ms）才收掉
			生命根.call("_on_server_drop_removed", 990001, 2, 0, false)
			var 金拾 := 掉落表.get(990001) as Node2D
			if 金拾 == null or not bool(金拾.get_meta("drop_picking", false)):
				_failures.append("animation=2 应进入拾取动画状态")
			生命根.call("_推进掉落动画", 0.7)
			# ⚠️ 判"从掉落表里摘掉了"，不能判 `is_instance_valid` ——
			#    `queue_free()` 是延迟的，当帧对象仍然 valid（第一版就这么假红了）。
			if 掉落表.has(990001):
				_failures.append("拾取动画跑完后掉落物应从地图上移除")
			物节点.queue_free()
			金拾.queue_free() if 金拾 != null else 0
			掉落表.erase(990002)
			掉落表.erase(990001)
		for 编号 in [990001, 990002]:
			var 掉 := 掉落表.get(编号) as Node
			if 掉 != null:
				掉.queue_free()
			掉落表.erase(编号)

	var actual_entries := {
		"头像面板/头像区域/角色状态/UnderBarButtons/ExchangeButton": "兑换",
		"头像面板/头像区域/角色状态/UnderBarButtons/CheckInButton": "签到",
		"小地图面板/小地图区域/小地图/活动按钮": "活动",
		"小地图面板/小地图区域/小地图/福利按钮": "福利",
		# 小地图左下那两个「常驻活动入口」（原版 SmallMapWindow 的 _huoyueduBtn / _activityPrizeBtn）。
		# 活跃度入口开的是**独立窗口** ActivityTaskWindow（不是「活动」页）——两者别混。
		"小地图面板/小地图区域/小地图/常驻活动图标/活跃度入口": "活跃度",
		"小地图面板/小地图区域/小地图/常驻活动图标/礼包入口": "福利",
		"小地图面板/小地图区域/小地图/信息按钮": "信息",
		"小地图面板/小地图区域/功能按钮/亲热天堂钮": "藏宝图",
		"小地图面板/小地图区域/功能按钮/宝石工艺钮": "挖矿",
		"小地图面板/小地图区域/功能按钮/首领刷新钮": "首领",
		"小地图面板/小地图区域/功能按钮/装备打造钮": "装备强化",
		"小地图面板/小地图区域/功能按钮/秘笈合成钮": "技能书",
		"小地图面板/小地图区域/功能按钮/意志背包钮": "遗址",
	}
	for node_path in actual_entries:
		var button := scene.get_node_or_null(node_path) as BaseButton
		if button == null:
			_failures.append("缺少实际活动入口：%s" % actual_entries[node_path])
			continue
		button.pressed.emit()
		await process_frame
		var page_name := String(actual_entries[node_path])
		if _当前页(管理, page_name) != page_name:
			_failures.append("实际按钮未打开页面：%s" % page_name)
		var content := _页内容(管理, page_name)
		if content == null or content.find_child(String(fixed_layouts.get(page_name, "")), true, false) == null:
			_failures.append("活动页未使用原版固定布局：%s" % page_name)
		if DisplayServer.get_name() != "headless":
			_save_screenshot(page_name)

	# 「装备打造」窗：原版是**一个窗、一条共用左栏**（`EquipStrengthWindow.createChildren` +
	# `refresh()` 的 switch），不是每页换一份页面 —— 所以这里钉的是
	# "切到任何一页，共用左栏那几件都还在"，而不是旧的"每页都换成固定场景"。
	# （旧断言是照着客户端上一版的自造结构写的，2026-09-22 重做时一并改掉。）
	管理.call("取或建窗口", "装备强化").call("open_page", "装备强化")
	await process_frame
	# ⚠️ `_页内容` 返回的是窗口的 `_content`，**页面本身是它的子节点**，
	# 所以要先拿到页面根（`原版装备强化内容`）再按页面局部路径取。
	var 打造页 := _打造页(管理)
	if 打造页 == null:
		_failures.append("装备强化页取不到")
	else:
		# 七个页签一个都不能少。
		# ⚠️ 原版这里是**十项**（后三项「神话属性锻造 / 神话重置 / 特性属性」按
		#   `EquipStrengthWindow.as:327` 硬编码进数组）。**2026-09-25 用户明确决定本重制版
		#   不做那三页**，页签按钮已从 `装备强化窗口.tscn` 里删掉 —— 所以期望值跟着降到七项。
		#   别把这三项加回来当"待办"：那是**已决定不做**，不是没做。
		var 应有 := ["强化", "洗附加属性", "洗附加数值", "进阶", "天生", "刻印", "精炼"]
		for 名 in 应有:
			if 打造页.get_node_or_null("分页/%s" % 名) == null:
				_failures.append("装备打造缺页签：%s" % 名)
		# 切遍每一页，共用左栏的六件必须一直在；
		# 而且**专属页（除强化/天生）必须把它们藏掉** —— 2026-10-01 用户报
		# "除强化外都有放入的装备图标重叠"：藏名单漏了「装备格」，共用左栏那枚
		# 装备图标和各专属页自己那枚**错位 8px 同屏**（原版藏的是整个 `_contentBox`，
		# `EquipStrengthWindow.as:659/723/739`）。这条同时把七件+装备格的显/藏钉死。
		var 共用件 := ["放入装备", "装备格", "说明", "注意", "标签", "材料框"]
		for tab_index in range(应有.size()):
			管理.call("取或建窗口", "装备强化").call("_set_strengthen_tab", tab_index)
			await process_frame
			var 页 := _打造页(管理)
			if 页 == null:
				_failures.append("装备打造分页 %d 后取不到页面" % tab_index)
				break
			for 路径 in ["内容容器/放入装备", "内容容器/说明", "内容容器/注意", "内容容器/标签",
					"内容容器/材料框", "内容容器/材料框/消耗几率", "开始强化"]:
				if 页.get_node_or_null(路径) == null:
					_failures.append("装备打造分页 %d 少了共用左栏的 %s" % [tab_index, 路径])
			var 该露 := tab_index in [0, 4]          # 强化 / 天生 用共用左栏
			for 名 in 共用件:
				var 件 := 页.get_node_or_null("内容容器/%s" % 名) as CanvasItem
				if 件 == null:
					_failures.append("分页 %d 找不到内容容器/%s" % [tab_index, 名])
				elif 件.visible != 该露:
					_failures.append("分页 %d（%s）的共用「%s」应%s，实际%s" % [
						tab_index, 应有[tab_index], 名, "露" if 该露 else "藏", "露" if 件.visible else "藏"])
		# 回到「强化」页：材料应来自配置表（强化灵珠），消耗/几率那两行照原版措辞
		管理.call("取或建窗口", "装备强化").call("_set_strengthen_tab", 0)
		await process_frame
		var 强化页 := _打造页(管理)
		if 强化页 != null:
			var 耗 := 强化页.get_node_or_null("内容容器/材料框/消耗几率")
			var 耗文 := String(耗.get("text")) if 耗 != null else ""
			if 耗 == null or not 耗文.contains("本次操作消耗金币：") or not 耗文.contains("本次操作成功几率："):
				_failures.append("强化页的消耗/几率文案不是原版那两行：%s" % (耗文 if 耗 != null else "节点缺失"))
			elif not (耗 is RichTextLabel):
				_failures.append("「消耗几率」必须是 RichTextLabel —— 金币不够时原版把数字标红（Label 装不了两段色）")
			var 说明 := 强化页.get_node_or_null("内容容器/说明") as RichTextLabel
			if 说明 == null or not 说明.text.contains("基础属性强化步骤说明"):
				_failures.append("强化页说明不是原版模板")

		# —— 金币不够 ⇒ 消耗数字标红（原版 `needMoney < cocoNuts 才正常`，**相等也红**；
		#    `EquipStrengthWindow.as:595` 等四页同句）。强化表 level1 金币是 0，
		#    拿**天生页**试（stage1 金币 500，未放入也照配置填那两行）。
		var 窗打造 = 管理.call("取或建窗口", "装备强化")
		窗打造.call("_set_strengthen_tab", 4)
		await process_frame
		var 原余额: Variant = session.player_stats.get("gold", 0)
		session.player_stats["gold"] = 0
		窗打造.call("_render_page")
		await process_frame
		var 天生页 := _打造页(管理)
		var 红文 := ""
		if 天生页 != null:
			var 红节点 := 天生页.get_node_or_null("内容容器/材料框/消耗几率")
			红文 = String(红节点.get("text")) if 红节点 != null else ""
		if not 红文.contains("[color=#ff0000]500[/color]"):
			_failures.append("金币余额 0 < 天生 stage1 金币 500 ⇒ 数字应标红，实际「%s」" % 红文)
		session.player_stats["gold"] = 原余额
		窗打造.call("_render_page")
		await process_frame
		窗打造.call("_set_strengthen_tab", 0)
		await process_frame
		# 上面两次重建把旧的 `强化页` free 掉了，必须重取（拿着死引用进下一段=脚本红）
		强化页 = _打造页(管理)
		for tab_name in 应有:
			var tab_button := _find_button_text(强化页, tab_name)
			if tab_button == null:
				_failures.append("装备打造分页缺失：%s" % tab_name)
			elif tab_button.disabled and not tab_button.button_pressed:
				# ⚠️ 2026-10-13（§3.139）改判据：**选中那枚按原版就是 `disabled`**
				# （`MTabButton.as:38` `set enabled(v){selected=!v}` ⇒ 选中走 disabled 槽显示真皮），
				# 原本"disabled 即不可用"的写法会**在选中那枚上假红**。
				# 真死钮的定义收窄成"disabled 且不是选中态"。
				_failures.append("装备打造分页不可用：%s" % tab_name)

		# 「开始强化 / 开始合成」必须是**活的**（有 pressed 连接）。
		# 守的是这一类真 bug：我重做这扇窗时把换页结构删了，执行按钮一度变成死按钮
		# （点了没反应），而用例当时全绿 —— 因为没人查"按钮接没接线"。
		# 两个页签各查一次：强化走共用左栏、进阶走专属面板，是两条不同的接线路径。
		# 页签序号 → 该页执行按钮的文案（0 强化 / 1 洗附加属性 / 3 进阶）
		var 执行按钮名 := {0: "开始强化", 1: "开始重置", 2: "开始重置", 3: "开始合成", 5: "开始刻印"}
		for 页签序号 in 执行按钮名:
			管理.call("取或建窗口", "装备强化").call("_set_strengthen_tab", 页签序号)
			await process_frame
			var 本页 := _打造页(管理)
			var 执行按钮 := _find_button_text(本页, String(执行按钮名[页签序号]))
			if 执行按钮 == null:
				_failures.append("装备打造页签 %d 找不到执行按钮" % 页签序号)
			elif 执行按钮.pressed.get_connections().is_empty():
				_failures.append("装备打造页签 %d 的执行按钮没接接线（点了不会有反应）" % 页签序号)

		# 幸运符「勾选 / 下拉」必须**接了刷新**（原版公式 `勾选 ? int(prob + 下拉值 * 3) : int(prob)`，
		# `EquipPropResetPanel.as:421` / `EquipUpgradeWindow.as:337`；`xingYunJingRatio = 3`）。
		#
		# ⚠️ **这条只证明"接上了"，不证明"算对了"** —— 别把它当成完整覆盖：
		#   * 修之前 `勾选.toggled` **也**挂着一条 lambda（联动禁用下拉），`get_connections()`
		#     照样非空 —— 所以「勾选」那一半在当时是**假绿**，真正为空的是 `下拉.item_selected`；
		#   * 「勾上之后成功率真的 +3N」要**有装备**才能验（配置里 `maxHelpCnt > 0`），
		#     而离线跑没有装备。那一步留给实机 / `开发工具/截强化窗.gd --快照=` 那条路。
		# 洗附加属性(1) 的控件在「材料框」下，进阶(3) 的在「结果区」下 —— 按名找即可。
		# ⚠️ 洗附加数值(2) **不在表里**：原版那一页（`EquipPropLianZhiPanel(isWashProp = true)`）
		# 只有 `_caiLiao1`，没有幸运符那组（用户 2026-11-01 要求删）；场景共用的四件被
		# `_配置洗附加数值页` 藏掉且**不再接线**，查接线只会恒红。「藏掉」由
		# `洗附加数值对照回归测试` 钉。
		for 页签序号 in [1, 3]:
			管理.call("取或建窗口", "装备强化").call("_set_strengthen_tab", 页签序号)
			await process_frame
			var 幸运页 := _打造页(管理)
			if 幸运页 == null:
				continue
			var 幸运勾选 := 幸运页.find_child("使用幸运符", true, false) as CheckBox
			var 幸运下拉 := 幸运页.find_child("幸运符数量", true, false) as OptionButton
			if 幸运勾选 == null or 幸运勾选.toggled.get_connections().is_empty():
				_failures.append("装备打造页签 %d 的「使用幸运符」勾选没接刷新（勾了成功率也不会变）" % 页签序号)
			if 幸运下拉 == null or 幸运下拉.item_selected.get_connections().is_empty():
				_failures.append("装备打造页签 %d 的幸运符数量下拉没接刷新" % 页签序号)
			# 0.4（用户 2026-11-01）：这颗下拉在场景里只有 40~45 宽，而 OptionButton
			# 最小宽默认 70 ⇒ 右沿压到后面的「个幸运符」上。三项覆盖（不按最长项撑宽 /
			# 溢出裁剪 / 箭头边距 0）后实测 40。洗附加数值页把它藏了，只量露出来的。
			if 幸运下拉 != null and 幸运下拉.visible \
					and 幸运下拉.get_combined_minimum_size().x > 45.0:
				_failures.append("装备打造页签 %d 的幸运符数量下拉最小宽 %.1f > 45（会压到后面的单位字样）"
					% [页签序号, 幸运下拉.get_combined_minimum_size().x])

		# 精炼页（页签 6）**得单独查**，不能并进上面那张表：
		# 它的执行按钮与页签**同名**（都叫「精炼」），`_find_button_text` 撞上页签那个的概率很大，
		# 而页签是接过线的 —— 那样这个用例就成了"永远绿"，恰恰是它要守的那类假绿。
		# 所以这里限定在 `面板容器` 里找。
		管理.call("取或建窗口", "装备强化").call("_set_strengthen_tab", 6)
		await process_frame
		var 精炼页 := _打造页(管理)
		var 精炼面板 := 精炼页.get_node_or_null("面板容器/原版装备精炼页") as Control if 精炼页 != null else null
		if 精炼面板 == null:
			_failures.append("装备打造「精炼」页没有建出专属面板")
		else:
			for 路径 in ["说明", "注意", "标签", "放入装备", "装备格", "材料框/材料一/材料格",
					"材料框/选择锻造项", "材料框/精炼项", "材料框/锻造成功率", "材料框/成功率条",
					"材料框/成功率文本", "材料框/自动精炼至满属性", "精炼", "自动精炼"]:
				if 精炼面板.get_node_or_null(路径) == null:
					_failures.append("精炼页少了 %s" % 路径)
			# 2.1（用户 2026-11-01）：装备格原来**没给底图**，没放装备时那个空框根本不出现。
			for 名 in ["装备格", "材料框/材料一/材料格"]:
				var 框 := 精炼面板.get_node_or_null(名) as TextureRect
				if 框 == null or 框.texture == null:
					_failures.append("2.1 精炼页「%s」少了物品格底图（空框看不见）" % 名)
			# 2.4（用户 2026-11-01）：条上读数原版 `MBar.tf` 是 12 号、宽 = 条宽、水平+垂直居中；
			# 矩形按条心摆 —— 条在材料框 (150,57) 100×11 ⇒ 中心 y=62.5，19 高文字框 y=53。
			var 成功率文本 := 精炼面板.get_node_or_null("材料框/成功率文本") as Label
			if 成功率文本 == null:
				_failures.append("2.4 精炼页少了成功率文本")
			else:
				if 成功率文本.get_theme_font_size("font_size") != 12:
					_failures.append("2.4 成功率文本应是 12 号，实际 %d"
						% 成功率文本.get_theme_font_size("font_size"))
				if 成功率文本.position != Vector2(150.0, 53.0) or 成功率文本.size != Vector2(100.0, 19.0):
					_failures.append("2.4 成功率文本矩形应是 (150,53) 100×19，实际 %s %s"
						% [成功率文本.position, 成功率文本.size])
				if 成功率文本.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER \
						or 成功率文本.vertical_alignment != VERTICAL_ALIGNMENT_CENTER:
					_failures.append("2.4 成功率文本应水平+垂直居中")
			var 精炼按钮 := 精炼面板.get_node_or_null("精炼") as Button
			if 精炼按钮 == null or 精炼按钮.pressed.get_connections().is_empty():
				_failures.append("精炼页的执行按钮没接接线（点了不会有反应）")
			# 成功率条的填充宽度：`MBar.setData` 是**遮罩显影**，可见宽 = `100×ratio − 3`，
			# 不是 `94×ratio`（那 3px 是 `bar` 画在符号 x=45、`maskMc` 在 48 的差）。
			# 默认项「提升附加属性」prob = 25（2026-11-01 用户要求提到 25%）→ 22px。
			var 精炼下拉 := 精炼面板.get_node_or_null("材料框/精炼项") as OptionButton
			if 精炼下拉 != null:
				精炼下拉.selected = 0
				精炼下拉.item_selected.emit(0)
				await process_frame
			var 条 := 精炼面板.get_node_or_null("材料框/成功率条")
			var 填 := 条.get_node_or_null("填充") as TextureRect if 条 != null else null
			if 填 == null or 填.texture == null:
				_failures.append("精炼页成功率条没有填充（或没给贴图）")
			elif absf(填.size.x - 22.0) > 0.01:
				_failures.append("精炼页成功率条填充宽应为 22（prob=25 → 100×0.25−3），实际 %.2f" % 填.size.x)

			# 说明段必须是**原版那一整段**（Flash 的 \r 要翻译成换行，挤成一行就是没翻译）
			var 精炼说明 := 精炼面板.get_node_or_null("说明") as RichTextLabel
			if 精炼说明 == null or not 精炼说明.text.contains("装备精炼步骤说明") \
					or 精炼说明.text.contains("<font") or not 精炼说明.text.contains("\n"):
				_failures.append("精炼页说明没按原版翻译：%s" % (精炼说明.text if 精炼说明 else "节点缺失"))
			# 下拉换项要真的换掉注意段 —— 这是"两项各走各的配置"在界面上的证据
			var 下拉 := 精炼面板.get_node_or_null("材料框/精炼项") as OptionButton
			var 注意 := 精炼面板.get_node_or_null("注意") as RichTextLabel
			if 下拉 == null or 下拉.item_count != 2:
				_failures.append("精炼页的下拉应有 2 项（提升附加属性 / 提升强化星级）")
			elif 注意 == null:
				_failures.append("精炼页少了注意段")
			else:
				下拉.selected = 0
				下拉.item_selected.emit(0)
				await process_frame
				var 附加属性段 := 注意.text
				下拉.selected = 1
				下拉.item_selected.emit(1)
				await process_frame
				if 附加属性段 == 注意.text or not 注意.text.contains("提升强化星数"):
					_failures.append("精炼页下拉切到「提升强化星级」后注意段没换：%s" % 注意.text)

			# 2.2（用户 2026-11-01）：精炼回包会整页重渲染，**不该**把玩家选的锻造项打回默认
			# —— 只有换页签/重开窗（`_set_strengthen_tab`）才重置。
			if 下拉 != null:
				var 窗刷新 = 管理.call("取或建窗口", "装备强化")
				窗刷新.call("_refresh_current")
				await process_frame
				await process_frame
				var 新页 := _打造页(管理)
				var 新面板 := 新页.get_node_or_null("面板容器/原版装备精炼页") as Control if 新页 != null else null
				var 新下拉 := 新面板.get_node_or_null("材料框/精炼项") as OptionButton if 新面板 != null else null
				if 新下拉 == null:
					_failures.append("2.2 精炼页重渲染后拿不到下拉")
				elif 新下拉.get_selected_id() != 1:
					_failures.append("2.2 重渲染后锻造项被打回默认（id=%d），应保住玩家选的「提升强化星级」"
						% 新下拉.get_selected_id())

			# 0.5（用户 2026-11-01）：精炼成功/失败原版走 `API.ui.addNotice`（屏幕通知），
			# 不能压在这页的状态行上。
			var 通知: Array[String] = []
			session.notification_requested.connect(func(文: String) -> void: 通知.append(文))
			var 窗精炼 = 管理.call("取或建窗口", "装备强化")
			var 状态 := 窗精炼.get("_status") as Label
			if 状态 != null:
				状态.text = "哨兵"
			窗精炼.call("_on_item_change_result", 6, {"kind": "forge_additive", "result": 1})
			await process_frame
			if not 通知.any(func(文: String) -> bool: return 文 == "恭喜您精炼成功"):
				_failures.append("0.5 精炼成功应发屏幕通知「恭喜您精炼成功」，实际 %s" % [通知])
			if 状态 != null and 状态.text != "哨兵":
				_failures.append("0.5 精炼结果不该写面板状态行，实际「%s」" % 状态.text)
			通知.clear()
			窗精炼.call("_on_item_change_result", 6, {"kind": "forge_strength", "result": 0})
			await process_frame
			if not 通知.any(func(文: String) -> bool: return 文 == "很抱歉，装备精炼失败"):
				_failures.append("0.5 精炼失败应发屏幕通知「很抱歉，装备精炼失败」，实际 %s" % [通知])

	管理.call("取或建窗口", "遗址").call("open_page", "遗址")
	await process_frame
	var ruins_content := _页内容(管理, "遗址")
	var study_button := _find_button_text(ruins_content, "前往学习意志")
	if study_button == null:
		_failures.append("意志背包缺少前往学习入口")
	else:
		study_button.pressed.emit()
		await process_frame
		if _当前页(管理, "意志学习") != "意志学习":
			_failures.append("意志背包未打开意志学习窗口")
		elif (_页内容(管理, "意志学习") as Control).find_child("原版意志学习内容", true, false) == null:
			_failures.append("意志学习未使用原版分级固定场景")

	var status_button := scene.get_node_or_null("头像面板/头像区域/角色状态/StatusToggle") as BaseButton
	if status_button == null or status_button.pressed.get_connections().is_empty():
		_failures.append("战斗状态切换按钮未绑定")

	var original_pets: Array = session.pets.duplicate(true)
	if not session.pets.is_empty():
		session.pets[0]["deployed"] = true
		session.pets_changed.emit(session.pets.duplicate(true))
		await process_frame
		await process_frame
		var 出战伙伴 := scene.get_node_or_null("宠物伙伴_%s" % String(session.pets[0].get("id", "0")))
		if 出战伙伴 == null:
			_failures.append("宠物出战后未生成场景伙伴")
		elif str(出战伙伴.get("_角色")) != "出战":
			_failures.append("出战宠物伙伴的角色标记不是「出战」：%s" % str(出战伙伴.get("_角色")))
		# 附身那只也要在地图上出现（服务端 ATTACHED(0) 同样发 spawn 帧，原版是
		# FuShenPetController），差别只是**不自动打怪** —— 以前只认 deployed，附身永不显示。
		for 宠 in session.pets:
			宠["deployed"] = false
			宠["attached"] = false
		session.pets[0]["attached"] = true
		session.pets_changed.emit(session.pets.duplicate(true))
		await process_frame
		await process_frame
		var 附身伙伴 := scene.get_node_or_null("宠物伙伴_%s" % String(session.pets[0].get("id", "0")))
		if 附身伙伴 == null:
			_failures.append("宠物附身后未生成场景伙伴")
		elif str(附身伙伴.get("_角色")) != "附身":
			_failures.append("附身宠物伙伴的角色标记不是「附身」：%s" % str(附身伙伴.get("_角色")))
		# 两态并存：服务端 `_normalize_active_pet_positions()` 允许"一只附身 + 一只出战"
		# ⇒ 地图上要同时有两只 actor，各按自己的角色跑（出战打怪、附身只跟走）。
		if session.pets.size() >= 2:
			for 宠 in session.pets:
				宠["deployed"] = false
				宠["attached"] = false
			session.pets[0]["deployed"] = true
			session.pets[1]["attached"] = true
			session.pets_changed.emit(session.pets.duplicate(true))
			await process_frame
			await process_frame
			var 两只出战 := scene.get_node_or_null("宠物伙伴_%s" % String(session.pets[0].get("id", "0")))
			var 两只附身 := scene.get_node_or_null("宠物伙伴_%s" % String(session.pets[1].get("id", "0")))
			if 两只出战 == null or 两只附身 == null:
				_failures.append("附身与出战并存时没有同时生成两只场景伙伴")
			elif str(两只出战.get("_角色")) != "出战" or str(两只附身.get("_角色")) != "附身":
				_failures.append("两态并存时伙伴角色标记错：%s / %s" % [
					str(两只出战.get("_角色")), str(两只附身.get("_角色"))])
			# 用户 2026-10-18 报的三条：两只不许叠 / 人物静止不播 move / 腾空不跟着飞。
			for _frame in range(12):
				await process_frame
			if 两只出战 is Node2D and 两只附身 is Node2D:
				var 出战x := (两只出战 as Node2D).global_position.x
				var 附身x := (两只附身 as Node2D).global_position.x
				# ⚠ 判据从 `< 20` 抬到 `< 95`：一帧宠物立绘宽 45~47 × `scale 1.15` ≈ 54 ⇒ 旧值那 46px 间距
				#   **本来就叠**，用 20 去量是条假绿（用户 2026-10-21 复报"还是太近、有重叠"）。
				#   原版两态停止阈值 200 / 100 ⇒ 稳态间距 100，口径见 §3.241 与 `真值/地图/宠物跟随站位.md`。
				if absf(出战x - 附身x) < 95.0:
					_failures.append("出战与附身两只叠在一起了（x 差只有 %.1f，应 ≈100）" % absf(出战x - 附身x))
			var 静止态 := str(两只出战.get("_当前动画"))
			if 静止态 != "stand":
				_failures.append("人物静止时出战宠物在播「%s」，应该 stand（动画要按真实位移切）" % 静止态)
			var 玩家节点 := scene.get_node_or_null("Player")
			if 玩家节点 != null and 两只出战 is Node2D:
				var 原脚y: float = (玩家节点 as Node2D).global_position.y
				var 原在地: Variant = 玩家节点.get("on_ground")
				玩家节点.set("on_ground", false)
				(玩家节点 as Node2D).global_position.y = 原脚y - 150.0
				# ⚠ 采样点用的是**主人的 x**，不是宠物的 x：§3.241 之后 `_process` 就按主人那条地面取高度
				#   （出战停在身后 200px，按宠物 x 采会跨台阶）。这条腿要验的是"腾空时不许跟着主人飞"，
				#   换成主人 x 才是原语义（主人脚下那条地面 == 原脚y）。
				var 算出的地面 := float(两只出战.call("_地面高度", (玩家节点 as Node2D).global_position.x, 原脚y))
				if absf(算出的地面 - 原脚y) > 6.0:
					_failures.append("主人腾空时宠物跟着飞了（地面算出 %.1f，原地面 %.1f）" % [算出的地面, 原脚y])
				(玩家节点 as Node2D).global_position.y = 原脚y
				玩家节点.set("on_ground", 原在地)
		session.pets.assign(original_pets)
		session.pets_changed.emit(session.pets.duplicate(true))

	var minimap_panel := scene.get_node_or_null("小地图面板")
	if minimap_panel != null and minimap_panel.has_method("show_npc_dialog"):
		var life_root := scene.get_node_or_null("LifeRoot")
		var interaction_player := scene.get_node_or_null("Player") as Node2D
		var npc: Node2D
		if life_root != null:
			for entity in life_root.get("_entities") as Array:
				if String(entity.get("kind")) == "n":
					npc = entity as Node2D
					break
		# 2026-10-11 §3.106：旧假气泡已退役 ⇒ 判据改成**新窗**（`NPC对话窗` 现建那个）。
		# 原来这里看的是 `_dialog_panel.visible`，现在那件连节点都没了。
		var 对话窗: Node = minimap_panel.get("_对话")
		if npc == null or interaction_player == null or 对话窗 == null:
			_failures.append("NPC 点击交互测试依赖不完整")
		else:
			var original_player_position := interaction_player.global_position
			interaction_player.global_position = npc.global_position
			(对话窗.call("根") as Control).visible = false
			var blank_click := InputEventMouseButton.new()
			blank_click.button_index = MOUSE_BUTTON_LEFT
			blank_click.pressed = true
			life_root.call("_unhandled_input", blank_click)
			await process_frame
			if (对话窗.call("根") as Control).visible:
				_failures.append("点击 NPC 之外的区域仍会触发人物对话")
			var npc_area := npc.get_node_or_null("NpcInteractionArea") as Area2D
			if npc_area == null:
				_failures.append("NPC 缺少独立鼠标命中区域")
			else:
				npc_area.mouse_entered.emit()
				if (life_root.get("_hovered_npc_areas") as Dictionary).is_empty():
					_failures.append("鼠标进入 NPC 后未进入交互悬停状态")
				npc_area.mouse_exited.emit()
				if not (life_root.get("_hovered_npc_areas") as Dictionary).is_empty():
					_failures.append("鼠标离开 NPC 后未清除交互悬停状态")
				npc_area.input_event.emit(scene.get_viewport(), blank_click, 0)
				await process_frame
				var selection_marker := npc.get_node_or_null("SelectionMarker") as Node2D
				var target_panel := scene.get_node_or_null("头像面板/头像区域/选中人物信息") as Control
				if selection_marker == null or not selection_marker.visible:
					_failures.append("选中 NPC 后头顶未显示蓝色箭头")
				if target_panel == null or not target_panel.visible:
					_failures.append("选中 NPC 后页面上方未显示人物信息")
				elif (target_panel.get_node("名字") as Label).text.is_empty() or (target_panel.get_node("头像") as TextureRect).texture == null:
					# 2026-10-15 目标信息条按原版 `DetailsWindow` 重建：件名从 `Name`/`Portrait`
					# 改成原版的 `_name`/头像档（`名字`/`头像`）。⚠ 新场景里 `头像` **不再烤死一张图**，
					# 所以这一条从"节点在不在"变成了真判"按 face/npc 号取到图没有"。
					_failures.append("选中人物信息缺少姓名或头像")
				## 10-15 用户实机打回的那一条：「点那个角色之后显示的头像界面，我再点地面不会消失才对」。
				## 原版 `TargetHandler` 里 `viewTarget = null` 只有四个来源：`cancelTarget()`
				## （点信息条上那枚头像）、`setCurTarget(null)`、`clear()`（换图/死亡）、角色/怪**离场**
				## （`TargetHandler.as:253/315/466`、`CharacterHandler.as:120`、`MonsterHandler.as:426/477`）
				## —— **移动指令根本不动它**。空白处那一发只该停掉自动追打。
				## （"点头像仍然清得掉"这一半由 `测试/目标信息条回归测试.gd` 用真 `push_input` 钉着。）
				life_root.call("_unhandled_input", blank_click)
				await process_frame
				if not selection_marker.visible or target_panel == null or not target_panel.visible:
					_failures.append("点空白之后选中**应该还在**（原版移动指令不清 viewTarget），现在被清掉了")
			interaction_player.global_position = original_player_position
		minimap_panel.call("show_npc_dialog", "00000002")
		await process_frame
		# 2026-10-04 合并「纲手三页」包：对话窗改成原版 `QuestDialog` 两格 + 手形菜单行，
		# 「服务入口」不再是 Button.text，而是菜单行。判据跟着换成读行文字 + 走同一条 `按下行`。
		var npc菜单: Array[String] = minimap_panel.call("npc对话菜单行")
		if npc菜单.is_empty() or npc菜单[0] != "打开商店":
			_failures.append("商人对话未显示商店入口（菜单第一行=%s）" % str(npc菜单))
		else:
			minimap_panel.call("npc对话点行", 0)
			await process_frame
			if _当前页(管理, "NPC商店") != "NPC商店":
				_failures.append("NPC 商店入口未打开商品页面")
			else:
				# ⚠️ 这条断言 2026-09-26 改过判据。原判据是「页面里能找到 SpinBox」，
				# 那其实**钉死的是我们自己的实现**：原版 `ShopWindow2` 的格子里根本没有数量控件
				# （格子只有 110x41 = 物品格 40x40 + 价格底条，塞不下），数量是在
				# **点出来的 `BuyAndSaleItemWindow`（187x199）里选**的。
				# 新判据按原版链路验：格子在 → 点它 → 弹出来的买卖窗里有数量输入。
				# 这比原来强：连"弹不弹得出来"一起验了。
				var 商店页 := _页内容(管理, "NPC商店") as Control
				var 买卖窗 := 商店页.find_child("买卖数量窗", true, false) as Control
				var 格子 := _找商店商品格(商店页)
				if 买卖窗 == null:
					_failures.append("NPC 商店缺少买卖数量窗（原版 BuyAndSaleItemWindow）")
				elif 格子 == null:
					_failures.append("NPC 商店没有商品格")
				else:
					格子.pressed.emit()
					await process_frame
					if not 买卖窗.visible:
						_failures.append("点商品格没有弹出买卖数量窗")
					elif (买卖窗.get_node("数量") as LineEdit) == null:
						_failures.append("买卖数量窗缺少数量输入")
					else:
						买卖窗.call("隐藏")
			if DisplayServer.get_name() != "headless" and _当前页(管理, "NPC商店") == "NPC商店":
				_save_screenshot("NPC商店")
		session.open_npc_service("00000013")
		await process_frame
		if _当前页(管理, "NPC仓库") != "NPC仓库":
			_failures.append("仓库管理员未打开仓库页面")
		elif (_页内容(管理, "NPC仓库") as Control).find_child(String(fixed_layouts["NPC仓库"]), true, false) == null:
			_failures.append("NPC 仓库未使用原版固定布局")
		elif DisplayServer.get_name() != "headless":
			_save_screenshot("NPC仓库")
		var accepted_backup: Array = session.accepted_quests.duplicate(true)
		var available_backup: Array = session.available_quests.duplicate(true)
		session.accepted_quests.clear()
		session.available_quests.assign([{
			"id": "入口测试", "name": "测试任务", "type": "主线",
			"description": "与测试 NPC 交谈", "giver_npc": "00000001",
		}])
		minimap_panel.call("show_npc_dialog", "00000001")
		await process_frame
		var npc_dialog_text := String(minimap_panel.get("_dialog_text"))
		if not npc_dialog_text.contains("测试任务") or not npc_dialog_text.contains("与测试 NPC 交谈"):
			_failures.append("任务 NPC 对话未显示任务名称和说明")
		# 同商人段：菜单行判据（`按下行` 走 Callable 本地跳转分支）
		var 任务菜单: Array[String] = minimap_panel.call("npc对话菜单行")
		if 任务菜单.is_empty() or 任务菜单[0] != "打开任务":
			_failures.append("任务 NPC 对话未显示任务入口（菜单第一行=%s）" % str(任务菜单))
		else:
			minimap_panel.call("npc对话点行", 0)
			await process_frame
			if _当前页(管理, "任务") != "任务":
				_failures.append("任务 NPC 未直达任务页面")
		session.accepted_quests.assign(accepted_backup)
		session.available_quests.assign(available_backup)

	# ⚠️ 这条断言的**范围**在多窗口改造后必须收窄，否则一定误报：
	# 改造前功能窗口是"换页"的，页面用完就销毁 —— 于是只有**当时开着的那一页**
	# 会被扫到（实测基线 0 条）。现在每个页面各自一个常驻窗口，全都在树里，
	# 于是各页**子页签**里的按钮（八门/手里剑/结印…那些切页签时才接线的）
	# 也会被扫进来，一口气报一百多条。
	#
	# 断言的**本意**是"当前打开的这个窗口，可交互的按钮都该接了信号"，
	# 所以这里只扫当前这扇窗（`feature_window`），不再扫整个场景。
	# （各页子页签的接线是否齐全，是另一件事，另开用例，别混在这条里。）
	for node in feature_window.find_children("*", "BaseButton", true, false):
		var runtime_button := node as BaseButton
		if runtime_button == null:
			continue

	if DisplayServer.get_name() != "headless":
		var screenshot := root.get_texture().get_image()
		if screenshot != null and not screenshot.is_empty():
			screenshot.save_png("user://功能入口回归截图.png")
			print("Regression screenshot: ", ProjectSettings.globalize_path("user://功能入口回归截图.png"))
	_finish()

func _verify_scene_ui_architecture() -> void:
	var scene_checks := {
		"res://场景/界面/窗口/人物/人物窗口.tscn": ["原版人物属性面板", 0],
		"res://场景/界面/窗口/背包/背包窗口.tscn": ["物品格_*", 90],
		# 忍术格的数量**按页签不同**（职业忍术 15 / 世界忍术 18 / 其他忍术 12 /
		# 奥义禁术 13 / 特别技能 8，见 数据/界面/忍术树_箭头与元件.json），
		# 场景里按最多的那一页（世界忍术 18）备足，其余由 忍术窗口.gd 按页签显示/隐藏。
		"res://场景/界面/窗口/忍术/忍术窗口.tscn": ["忍术格_*", 18],
		"res://场景/界面/窗口/宠物/宠物窗口.tscn": ["宠物条目_*", 10],
	}
	for scene_path in scene_checks:
		var packed := load(scene_path) as PackedScene
		if packed == null:
			_failures.append("无法加载分级界面场景：%s" % scene_path)
			continue
		var instance := packed.instantiate()
		var pattern := String(scene_checks[scene_path][0])
		var expected_count := int(scene_checks[scene_path][1])
		var matches := instance.find_children(pattern, "", true, false)
		if expected_count == 0 and instance.find_child(pattern, true, false) == null:
			_failures.append("界面场景缺少固定节点：%s -> %s" % [scene_path, pattern])
		elif expected_count > 0 and matches.size() != expected_count:
			_failures.append("界面场景固定槽位数量错误：%s，应为 %d，实际 %d" % [scene_path, expected_count, matches.size()])
		instance.free()
	var page_scripts := [
		"res://脚本/界面/窗口/人物窗口.gd", "res://脚本/界面/窗口/背包窗口.gd",
		"res://脚本/界面/窗口/忍术窗口.gd", "res://脚本/界面/窗口/宠物窗口.gd",
	]
	var forbidden_constructors := ["Control.new()", "Panel.new()", "Button.new()", "TextureRect.new()", "ProgressBar.new()"]
	for script_path in page_scripts:
		var source := FileAccess.get_file_as_string(script_path)
		for constructor in forbidden_constructors:
			if source.contains(constructor):
				_failures.append("页面脚本仍在运行时创建固定控件：%s -> %s" % [script_path, constructor])
	var feature_source := FileAccess.get_file_as_string("res://脚本/界面/功能窗口.gd")
	var chat_source := FileAccess.get_file_as_string("res://脚本/界面/聊天面板.gd")
	var minimap_source := FileAccess.get_file_as_string("res://脚本/界面/小地图面板.gd")
	if feature_source.contains("StyleBoxFlat.new()") or chat_source.contains("StyleBoxFlat.new()"):
		_failures.append("界面脚本重新使用了 StyleBoxFlat 绘制原版边框")
	for required_skin in ["NINE_SLICE", "ORIGINAL_WINDOW_FRAME", "ORIGINAL_BUTTON_DOWN", "ORIGINAL_TAB_ON", "ORIGINAL_INPUT", "ORIGINAL_SELECTED"]:
		if not feature_source.contains(required_skin):
			_failures.append("功能窗口缺少原版贴图皮肤定义：%s" % required_skin)
	if chat_source.contains("专用控件/火影币.png"):
		_failures.append("聊天弹层仍错误使用火影币图片作为面板背景")
	if chat_source.contains("_create_channel_menu") or chat_source.contains("_create_face_panel"):
		_failures.append("聊天固定弹层仍由脚本创建")
	if minimap_source.contains("_build_dialog") or minimap_source.contains("_build_toast"):
		_failures.append("小地图固定弹层仍由脚本创建")
	var chat_scene := (load("res://场景/界面/聊天面板.tscn") as PackedScene).instantiate()
	if chat_scene.find_child("频道菜单", true, false) == null:
		_failures.append("聊天场景缺少频道菜单")
	var 表情网格 := chat_scene.find_child("表情网格", true, false) as Control
	if 表情网格 == null or 表情网格.get_child_count() != 36:
		_failures.append("聊天表情面板必须固定 36 格（原版 FaceWindow2 6×6）")
	chat_scene.free()
	var minimap_scene := (load("res://场景/界面/小地图面板.tscn") as PackedScene).instantiate()
	# 2026-10-11 §3.106：旧那枚「单格假气泡」`原版NPC对话` 已**连子树一起退役**
	# （台词源搬进了 `小地图面板.gd` 的 String 变量）⇒ 这条改钉「**它确实不在了**」+
	# 通知条还在。留着旧节点的场景会让"新窗到底在不在跑"看不出来。
	if minimap_scene.find_child("原版NPC对话", true, false) != null:
		_failures.append("小地图场景里那枚旧假气泡又回来了（§3.106 已退役，新窗由 NPC对话窗.gd 现建）")
	var 通知条 := minimap_scene.find_child("通知条", true, false) as Label
	if 通知条 == null:
		_failures.append("小地图场景缺少通知节点")
	else:
		## 通知条 = 原版 `API.ui.addNotice` → `MessageTipPane`：容器摆在 (0.6W, 0.6H)、
		## 文字宽 300 自动换行（`UIMain2.as:3512-3513`、`MessageTipPane.as:createTextField`）。
		## 2026-11-02 用户报「装备打造的信息不要显示在地图最上方」—— 它以前 y=60 且留在
		## CanvasLayer 20，既在顶上、又被功能窗(110+) 盖住。
		if (not is_equal_approx(通知条.anchor_left, 0.6) or not is_equal_approx(通知条.anchor_top, 0.6)
				or not is_equal_approx(通知条.anchor_right, 0.6) or not is_equal_approx(通知条.anchor_bottom, 0.6)):
			_failures.append("通知条锚点必须是 (0.6, 0.6)：原版 MessageTipPane 容器在 3/5 W、3/5 H（UIMain2.as:3512-3513）")
		if not is_zero_approx(通知条.offset_left) or 通知条.offset_right < 299.0:
			_failures.append("通知条文字宽必须是 300（原版 MessageTipPane.createTextField 的 tf.width）")
		if 通知条.autowrap_mode == TextServer.AUTOWRAP_OFF:
			_failures.append("通知条必须自动换行（原版 MessageTipPane 的 wordWrap=true）")
		var 通知层 := 通知条.get_parent().get_parent() as CanvasLayer
		if 通知层 == null or 通知层.layer < 300:
			_failures.append("通知条所在层必须高于 HUD/头像面板(300)：实测 %s" % (str(通知层.layer) if 通知层 != null else "无 CanvasLayer"))
		elif 通知层.layer >= 400:
			_failures.append("通知条不该盖过模态确认/Boss 进图确认层(400)：实测 %d" % 通知层.layer)
	var minimap_icons := {
		"活动按钮": ["res://素材/界面/通用界面/UISwf_Text.swf_22.png", Vector2(16.0, 25.0)],
		"福利按钮": ["res://素材/界面/通用界面/UISwf_Text.swf_28.png", Vector2(20.0, 52.0)],
		"信息按钮": ["res://素材/界面/通用界面/UISwf_Text.swf_25.png", Vector2(20.0, 75.0)],
	}
	for button_name in minimap_icons:
		var button := minimap_scene.find_child(button_name, true, false) as TextureButton
		var expected_path := String(minimap_icons[button_name][0])
		var expected_position := minimap_icons[button_name][1] as Vector2
		if button == null or button.texture_normal == null:
			_failures.append("小地图缺少原版按钮：%s" % button_name)
		elif button.texture_normal.resource_path != expected_path or button.position != expected_position:
			_failures.append("小地图按钮贴图或位置错误：%s" % button_name)
	if minimap_scene.find_child("屏蔽按钮", true, false) == null or minimap_scene.find_child("音量按钮", true, false) == null:
		_failures.append("小地图不应删除原版屏蔽或声音按钮")
	minimap_scene.free()
	var character_source := FileAccess.get_file_as_string("res://脚本/界面/窗口/人物窗口.gd")
	var backend_source := FileAccess.get_file_as_string("res://脚本/单例/后端连接.gd")
	## 寄坏虫强化要发的是**虫槽位置**（−200..−203）。这条以前钉的字面量是
	## `首个物品.get("equip_position", 0)` —— 那个字段按 id 前四位查表，四只虫**全都算成 −205**
	## （昆虫包）⇒ 发出去的槽位既不是虫槽也不是背包格，服务端 `inventory.get(槽)` 取不到那件。
	## 也就是说：**这条门当时把一段错代码当"原版口径"钉住了**（10-16 现查，
	## 见 `真值/窗口/人物属性_看别人.md §⑫·4`）。所以这里改成钉"用循环里记下的槽键"，
	## 并**反向钉旧写法不许回来** —— 只钉新式子不够，两种写法能同时存在就看不出退步。
	if not character_source.contains("var 强化位置 := 携入位置 if not 携入.is_empty() else 我的首虫位置"):
		_failures.append("寄坏虫强化没有发虫槽位置（−200..−203）：要用 `我的首虫位置`")
	if character_source.contains('首个物品.get("equip_position"'):
		_failures.append("寄坏虫强化又用回 `equip_position` 了 —— 四只虫它恒算成 −205（昆虫包）")
	if backend_source.contains("request_kunchong_strength(item_unique_id"):
		_failures.append("寄坏虫强化协议仍错误使用 unique_id")

func _save_screenshot(page_name: String) -> void:
	var screenshot := root.get_texture().get_image()
	if screenshot != null and not screenshot.is_empty():
		screenshot.save_png("user://功能页面_%s.png" % page_name)

## 取某个掉落物的名字标签（`_create_drop_node` 建的那个常显 Label 叫 `DropName`）。
func _掉落名(掉落表: Dictionary, 编号: int) -> Label:
	var 掉 := 掉落表.get(编号) as Node
	return 掉.get_node_or_null("DropName") as Label if 掉 != null else null


func _find_button(parent: Control, tooltip: String) -> BaseButton:
	for node in parent.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button != null and button.tooltip_text == tooltip:
			return button
	return null

## 按**文字**找按钮。⚠️ `BaseButton` 不保证有 `text`（`TextureButton` 就没有），
## 直接取 `.text` 会报 "Invalid access to property 'text' on TextureButton" ——
## 所以先判类型。（多窗口改造后页面里出现了 TextureButton，这个脆弱点才暴露出来。）
## 取某个页面那扇窗。**多窗口后每页一个实例**，断言必须指明是哪一页的窗，
## 不能再像换页时代那样拿一个 `feature_window` 从头的走到尾。
func _窗(管理: Node, 页名: String) -> Node:
	return 管理.call("取或建窗口", 页名) if 管理 != null else null


## 「装备打造」的**页面根**（`原版装备强化内容`）。`_页内容` 给的是窗口的 `_content`，
## 页面是它的子节点 —— 按页面局部路径取节点前必须先拿到这一层。
func _打造页(管理: Node) -> Control:
	var 容器 := _页内容(管理, "装备强化")
	return 容器.find_child("原版装备强化内容", true, false) as Control if 容器 != null else null


## NPC 商店的商品格（`场景/界面/组件/商店商品格.tscn`，根节点就叫「商店商品格」）。
func _找商店商品格(页: Control) -> BaseButton:
	for node in 页.find_children("商店商品格*", "BaseButton", true, false):
		return node as BaseButton
	return null


func _页内容(管理: Node, 页名: String) -> Control:
	var 窗 := _窗(管理, 页名)
	return 窗.get("_content") as Control if 窗 != null else null


func _当前页(管理: Node, 页名: String) -> String:
	var 窗 := _窗(管理, 页名)
	return String(窗.get("_current_page")) if 窗 != null else ""


## 找一个"文案 = button_text"的按钮。
##
## ⚠️ 2026-10-01 扩了一条：**`TextureButton` 也要认**。原来遇到 TextureButton 直接 `continue`，
## 是因为当时各页都用 `Button.text`；合并好友页/设置页之后，那两页的页签是
## **TextureButton + 子 Label**（原版 `MTabButton` 的皮+字分开）⇒ 旧写法恒返回 null，
## 报出来是"好友页面缺少原版分页：好友"（其实 5 枚一枚不少，就在 `页签条/页签<名>`）。
## 这里对 TextureButton 改看它子节点里那个 Label 的文案 —— **判据本身没放宽**：
## 仍然要求"页面上真的有一个显示该文案的按钮"。
func _find_button_text(parent: Control, button_text: String) -> BaseButton:
	for node in parent.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null:
			continue
		if button is TextureButton:
			# 三态钮族：文字子节点在旧页叫 "Label"，意志/首领三窗（2026-10-03 合并包）叫 "字"
			var 字: Label = null
			for 子 in button.get_children():
				if 子 is Label:
					字 = 子 as Label
					break
			if 字 != null and 字.text == button_text:
				return button
			continue
		if button.text == button_text:
			return button
	return null

func _finish() -> void:
	var exit_code := 0
	if _failures.is_empty():
		print("功能入口回归测试：通过")
	else:
		exit_code = 1
		for failure in _failures:
			push_error(failure)
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		current_scene = null
	await process_frame
	await process_frame
	quit(exit_code)
