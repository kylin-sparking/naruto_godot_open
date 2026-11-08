extends RefCounted

## 伊鲁卡「变身卡属性互换 / 变身卡特性属性互换」= 原版 `UIMain2` 的**内联窗**
## （`showTransformCardSwapWindowByMode(特殊)`，`UIMain2.as:565-703`）—— 两模共用一个 builder，
## 只差：窗高 395/495、标题、说明文案、`_loc4_` 310→410（分隔线二/费用格/数量行/确认钮整体下移 100）、
## 特殊版多四件「A/B 卡特性属性」标签与文本框（`:641-659`）。
## ⇒ 工程里出**两张场景两个页名**（各自 `窗口尺寸.json` 一条），几何全在 `.tscn`（SPEC 生成，别手改），
##   本文件按 `特殊` 走同一套运行期逻辑。
##
## ⚠ **双实现已择一**：另有一版注册类 `equip/TransformCardSwapWindow`（`super(280,200,true)`），
##   但 2.2.3 客户端菜单动作 31/32 的 handler 走 UIMain2 内联这一版 ⇒ 280×200 那版不建。
##
## 校验链照 `onSwapDropA/B`（`:1874-1950`）逐字搬（**这五支全是客户端判断，不发帧**）：
##   `int(id / 10000) != 121` ⇒ 「只能放入变身卡」；`position <= 0` ⇒ 「请先将变身卡卸下到背包再操作」；
##   `expiration > 0` ⇒ 「有期限的变身卡无法交换(特性)属性」；
##   普通版且 `reforgeTime > 0` ⇒ 「此变身卡已交换过属性，无法再次交换」；
##   与另一格 `position` 相同 ⇒ 「不能放入相同的变身卡」。
## 点「确认交换」（`:1952-1966`）：两格没满 ⇒ 「请放入两张变身卡」；`16000555` 不足 1 ⇒
## 「材料不足，需要1个研究所凭证」；否则弹确认框，**确定后 `startSwapAnimation()` 才发交换帧**。
## ⚠️ 2026-10-13 更正：此前这里写着"交换帧未接（未点头）" —— **早就接了**（§3.131 接的帧、
## §3.143 补的演出）；确定那一支现在是 `开始交换演出(态)` → `发交换(宿主, 态)`。
##
## 未收口（登记，不是"这样就是对"）：
##   · ~~**从背包拖进来**那一跳没接~~ —— **2026-10-13 §3.140 接上了**：
##     两枚卡格各挂一枚落点件 `变身卡放入格.gd`（背包格拖到格上 ⇒ `落料` ⇒ `放入`）；
##     双击取出那条原本就有。⚠️ 落下后 `position`/`expiration`/`reforge_time` 里，
##     后两条**我们模型里没有** ⇒ 恒 0、那两条客户端预判不触发（服务端判）；
##   · 交换瞬间的动画（`_swapEffectLayer` 的光效 + 遮罩淡入 + `GeneralInternalLoading` 进度条）没做，
##     场景里只留了那颗常驻隐藏的「动画遮罩」件占住几何。

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
## 附加属性「类型号 → 名字」那张表（原版 `ItemFactory.SUB_ATTR_TYPE_NAMES` 的移植），
## 特性栏逐条渲染要用它（见 `特性文案`）。
const 装备提示框 := preload("res://脚本/界面/组件/装备提示框.gd")
## 两枚卡格的落点件（Control 基；场景里的格是 `TextureRect`、挂不了 `可拖拽格`）。
const 变身卡放入格 := preload("res://脚本/界面/组件/变身卡放入格.gd")
const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
## 交换演出那两件（§3.143）：进度条（原版 `GeneralInternalLoading`）与程序化闪电层。
const 通用进度条 := preload("res://脚本/界面/组件/通用进度条.gd")
const 交换特效 := preload("res://脚本/界面/组件/交换特效.gd")
const 物品提示场景 := preload("res://场景/界面/组件/物品提示框.tscn")

const 费用号 := 16000555					# 研究所凭证（`:677` 写死这一枚）
const 变身卡段 := 121					# `int(id / 10000) != 121` ⇒ 只能放变身卡

const 白 := Color(1, 1, 1)
const 绿 := Color(0, 1, 0)
const 红 := Color(1, 0, 0)
const 橙 := Color(1, 0x91 / 255.0, 0)
const 灰 := Color(0.6, 0.6, 0.6)

## 文案全是 AS3 里的**硬写中文字面**（这一族没有语言键），逐字照抄：
const 说明普通 := "放入两张变身卡，交换基础属性和附加属性"			# :586
const 说明特性 := "放入两张变身卡，只交换特性属性，其他属性保持不变"		# :586 特殊支
const 空特性 := "[color=#999999]放入变身卡后显示特性属性[/color]"		# :717 / :756
const 无特性 := "[color=#ffffff]无特性属性[/color]"				# :760 / :785
const 消耗头 := "消耗[color=#00FF00]【研究所凭证】[/color]1个  当前拥有："	# :1729
const 消耗尾 := "个"
const 只能卡 := "只能放入变身卡"						# :1881
const 先卸下 := "请先将变身卡卸下到背包再操作"					# :1886
const 有期限普 := "有期限的变身卡无法交换属性"					# :1891
const 有期限特 := "有期限的变身卡无法交换特性属性"				# :1891
const 换过了 := "此变身卡已交换过属性，无法再次交换"				# :1897
const 同一张 := "不能放入相同的变身卡"						# :1902
const 要两张 := "请放入两张变身卡"							# :1956
const 料不足 := "材料不足，需要1个研究所凭证"					# :1962
const 问普 := "确定要交换这两张变身卡的属性吗？\n(消耗1个研究所凭证)"		# :1965
const 问特 := "确定要交换这两张变身卡的特性属性吗？\n(消耗1个研究所凭证)"	# :1965
const 传说色 := "#ff9100"


## `宿主` = `功能窗口`。`特殊` = `_swapSpecialMode`。
static func 渲染(宿主: Node, 场景: PackedScene, 特殊: bool) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	var 态 := {"页": 页, "宿主": 宿主, "特殊": 特殊, "A": {}, "B": {}}
	(页.get_node("说明") as RichTextLabel).text = 说明特性 if 特殊 else 说明普通
	页.set_meta("swap_state", 态)			# meta 键只许 ASCII（中文键会被静默拒掉）
	刷数量(态)
	var 钮 := 页.get_node("确认钮") as Button
	钮.pressed.connect(点确认.bind(态))
	接格(态, "卡格A")
	接格(态, "卡格B")
	return 页


static func 接格(态: Dictionary, 路: String) -> void:
	var 格 := (态["页"] as Control).get_node(路) as Control
	格.mouse_filter = Control.MOUSE_FILTER_STOP
	格.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 原版 `doubleClickEnabled` + `DOUBLE_CLICK` 取出（`:610-611` / `:1841-1863`）
	格.gui_input.connect(点格.bind(态, 路))
	# 从背包装入那一跳（原版 `onSwapDropA/B`，`:1874-1950`）：落点件挂在**格里那枚 TextureRect**上
	# （`卡格A/卡格A_格`）。⚠️ 它的 `mouse_filter` 必须是 **PASS 不是 STOP** ——
	# 置 STOP 会把鼠标事件吃掉、上面那句父级的双击取出就再也收不到（`_can_drop_data` 用 PASS 照样会调）。
	var 底 := 格.get_node(路 + "_格") as Control
	底.set_script(变身卡放入格)
	底.set("路", "A" if 路.ends_with("A") else "B")
	底.mouse_filter = Control.MOUSE_FILTER_PASS
	底.connect("请求放入", func(背包格: int) -> void: 落料(态, 路, 背包格))


## 背包那一格放下 ⇒ 组装成原版 `ItemData` 形状（`onSwapDropA/B` 的入参）再走 `放入` 的五道校验。
static func 落料(态: Dictionary, 路: String, 背包格: int) -> void:
	if 背包格 <= 0:
		return
	var 宿主 := 态["宿主"] as Node
	var 条: Dictionary = 宿主._session._占用条(宿主._session.inventory, 背包格)
	if 条.is_empty():
		return
	var 物品 := {
		"id": String(条.get("id", "")),
		"position": int(条.get("slot_index", 背包格)),
		# ⚠️ 这两条**我们的模型里没有**（原版 `ItemData.expiration` / `.reforgeTime`）⇒ 恒 0，
		#    那两条**客户端预判**不会触发，交给服务端判（如实记在 §3.140）。
		"expiration": int(条.get("expire_time", 0)),
		"reforge_time": int(条.get("reforge_time", 0)),
	}
	var 错 := 放入(态, 路, 物品)
	if 错 != "":
		宿主._show_hint(错)


static func 点格(事: InputEvent, 态: Dictionary, 路: String) -> void:
	var 按 := 事 as InputEventMouseButton
	if 按 == null or not 按.pressed or 按.button_index != MOUSE_BUTTON_LEFT:
		return
	if not 按.double_click:
		return
	取出(态, 路)


static func 取出(态: Dictionary, 路: String) -> void:
	var 键 := "A" if 路.ends_with("A") else "B"
	if (态[键] as Dictionary).is_empty():
		return
	态[键] = {}
	画格(态, 路)
	刷特性(态)


## 放入一枚（`onSwapDropA/B` 的五支校验 + 摆图 + 刷特性）。
## 返回 "" = 收下；否则返回原版那句提示（调用方直接落状态行 / 弹窗）。
static func 放入(态: Dictionary, 路: String, 物品: Dictionary) -> String:
	var 号 := int(物品.get("id", 0))
	if int(号 / 10000) != 变身卡段:
		return 只能卡
	if int(物品.get("position", 0)) <= 0:
		return 先卸下
	if int(物品.get("expiration", 0)) > 0:
		return 有期限特 if bool(态["特殊"]) else 有期限普
	if not bool(态["特殊"]) and int(物品.get("reforge_time", 0)) > 0:
		return 换过了
	var 键 := "A" if 路.ends_with("A") else "B"
	var 对 := "B" if 键 == "A" else "A"
	var 另: Dictionary = 态[对]
	if not 另.is_empty() and int(另.get("position", -1)) == int(物品.get("position", -2)):
		return 同一张
	态[键] = 物品
	画格(态, 路)
	刷特性(态)
	return ""


static func 画格(态: Dictionary, 路: String) -> void:
	var 页 := 态["页"] as Control
	# 生成器给嵌套件起的名字是**整条路径把 / 换成 _**：`卡格A` → `卡格A_格` → `卡格A_格_名`
	var 底 := 页.get_node(路 + "/" + 路 + "_格") as Control
	var 键 := "A" if 路.ends_with("A") else "B"
	var 物品: Dictionary = 态[键]
	var 名件 := 底.get_node(路 + "_名") as Label
	var 有 := not 物品.is_empty()
	名件.visible = not 有				# 有 itemData 时 `SimpleItemCell` 自己藏名字
	名件.text = "放入"
	var 号 := String(物品.get("id", ""))
	var 图 := 底.get_node_or_null(路 + "_格_图标") as TextureRect
	if 图 == null:
		图 = TextureRect.new()
		图.name = 路 + "_格_图标"
		图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		图.mouse_filter = Control.MOUSE_FILTER_IGNORE
		底.add_child(图)
	if not 有:
		图.visible = false
	else:
		var 路2 := 游戏数据.item_icon_path(号)
		图.visible = 路2 != "" and ResourceLoader.exists(路2)
		if 图.visible:
			图.texture = load(路2)
			var 寸: Vector2 = 图.texture.get_size()
			图.position = Vector2(roundf((底.size.x - 寸.x) / 2.0), roundf((底.size.y - 寸.y) / 2.0))
			图.size = 寸
	画立绘(态, "立绘" + 键, 物品)


## `showSwapCardIcon`（`:1732-1767`）：容器里摆 `CharacterSprite`@(65,120) + 名字
## `MGlowLabel` UI_ORANGE 130×20 center @(0,135)。
## ⭐ **2026-10-13 立绘接上了**（原先只摆名字，文件头记着"没做"）：原版那句
## `PicTool.getItemObject(id).info.face` 的 **`face` 就是 `装备库` 里导出的 `外观` 列**
## （`导出装备库.mjs` 的字段注释写着 `face(外观)`）⇒ `01210252 → 10000029` 这种。
## 拿它交给 `原始动画精灵`（`configure("character", 脸, "stand")`，先例 `意志窗口._接人物立绘`）。
static func 画立绘(态: Dictionary, 路: String, 物品: Dictionary) -> void:
	var 容 := (态["页"] as Control).get_node(路) as Control
	for 子 in 容.get_children():
		容.remove_child(子)
		子.queue_free()
	if 物品.is_empty():
		return
	var 兽 := OriginalSprite.new()
	if 兽.configure("character", str(装备外观(物品)).pad_zeros(8), "stand"):
		兽.position = Vector2(65.0, 120.0)		# `:1744-1745` 的 `charSprite.x = 65; y = 120`
		容.add_child(兽)
		兽.play("stand")
	var 名 := Label.new()
	名.name = "卡名"
	名.text = 游戏数据.item_name(String(物品.get("id", "")))
	名.position = Vector2(0.0, 135.0)
	名.size = Vector2(130.0, 20.0)
	名.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	名.add_theme_color_override("font_color", 橙)
	名.add_theme_font_size_override("font_size", 12)
	名.mouse_filter = Control.MOUSE_FILTER_IGNORE
	容.add_child(名)


## `装备库.装备[八位id].外观` —— 原版 `PicTool.getItemObject(id)` 的 `info.face`
## （立绘用哪个角色的样子）。认不出返回 0（`configure` 会拒掉、不硬塞一张皮）。
static func 装备外观(物品: Dictionary) -> int:
	var 库: Dictionary = 游戏数据.取表("装备库").get("装备", {})
	var 行: Dictionary = 库.get(str(物品.get("id", "")).pad_zeros(8), {})
	return int(行.get("外观", 0))


static func 刷数量(态: Dictionary) -> void:
	var 宿主 := 态["宿主"] as Node
	var 有 := int(宿主._背包数量(费用号))
	((态["页"] as Control).get_node("数量行") as RichTextLabel).text = (
		"%s[color=%s]%d[/color]%s" % [消耗头, "#00FF00" if 有 > 0 else "#FF0000", 有, 消耗尾])


## `buildSwapSpecialAttrHtml`（`:748-786`）：逐条 `名：+值%`，再传说特性、再残影。
##
## ⚠️ 2026-10-13 修两处：
##  ① 三个键名读错了 —— `special_attrs / special_effect / afterimage` **全工程没人写**，
##     真名是本工程解析帧时用的 `special_attributes / special_effect_type / afterimage_flag`
##     （原版 `CocoEquip.decode` 的 `specialAttrList / specialEffectType / afterimageFlag`，
##     文本桥在装备段尾部补这四段，见 `fake_flash_server._encode_item_payload`）
##     ⇒ 以前**有特性的卡也一律显示「无特性属性」**；
##  ② 每条的属性名要**按类型号查表**（原版 `getSwapAttrName:721-729` =
##     `SUB_ATTR_TYPE_NAMES[SUB_ATTR_TYPES.indexOf(类型)]`，查不到才退 `"属性"+类型`），
##     而我们解析出来的行是 `{attribute_type, attribute_value}`，原来却读 `name/type/value`
##     ⇒ 就算有数据也会印成「属性0：+0」。查表复用 `装备提示框.属性名`（同一张 SUB_ATTR 表）。
static func 特性文案(物品: Dictionary) -> String:
	if 物品.is_empty():
		return 空特性
	var 表: Array = 物品.get("special_attributes", [])
	var 效 := int(物品.get("special_effect_type", 0))
	var 影 := int(物品.get("afterimage_flag", 0))
	if 表.is_empty() and 效 <= 0 and 影 <= 0:
		return 无特性
	var 出 := ""
	for i in 表.size():
		var 项: Dictionary = 表[i]
		var 型 := int(项.get("attribute_type", 项.get("sub_attr_type", 0)))
		var 值 := int(项.get("attribute_value", 项.get("sub_arrt_value", 0)))
		出 += "[color=#ffffff]%s：[/color][color=#00ff00]+%s%s[/color]\n" % [
			String(装备提示框.属性名.get(型, "属性%d" % 型)),
			str(值), "%" if i < 4 and 值 > 0 else ""]
	var 述 := 效果文案(效)
	if 述 != "":
		出 += "[color=%s]传说特性：[/color][color=#ffffff]%s[/color]\n" % [传说色, 述]
	if 影 > 0:
		出 += "[color=%s]残影显现!(特殊效果)[/color]" % 传说色
	return 出 if 出 != "" else 无特性


## `getSwapSpecialEffectDesc`（`:731-746`）逐字。
static func 效果文案(型: int) -> String:
	match 型:
		1: return "攻击时回复自身2%血量"
		2: return "2%概率提升10%防御5秒"
		3: return "2%概率提升10%攻击5秒"
	return ""


static func 刷特性(态: Dictionary) -> void:
	if not bool(态["特殊"]):
		return
	var 页 := 态["页"] as Control
	(页.get_node("特性A") as RichTextLabel).text = 特性文案(态["A"])
	(页.get_node("特性B") as RichTextLabel).text = 特性文案(态["B"])


static func 点确认(态: Dictionary) -> void:
	var 宿主 := 态["宿主"] as Node
	if (态["A"] as Dictionary).is_empty() or (态["B"] as Dictionary).is_empty():
		宿主._show_hint(要两张)
		return
	if int(宿主._背包数量(费用号)) < 1:
		宿主._show_hint(料不足)
		return
	# 原版 `:1952-1966`：两格都满、费用够 ⇒ 弹 `MDialog` 二次确认，**确定后**才
	# `startSwapAnimation()` → 交换帧。我们这边用 `输入确认弹.弹消息`（`showMessageDialog` 的移植）。
	var 遮罩 := 宿主.get("_overlay") as Control
	var 正文 := 问特.strip_edges() if bool(态["特殊"]) else 问普.strip_edges()
	if 遮罩 == null:
		发交换(宿主, 态)
		return
	确认弹.弹消息(遮罩, 正文, func(码: int) -> void:
		if 码 == 1:
			开始交换演出(态)			# 原版 `:1972` 先 `startSwapAnimation()`
			发交换(宿主, 态))


## ── 交换演出（原版 `startSwapAnimation:1976-2012` + `onSwapAnimTick:2034-2073`）──────
## `Timer(33, 60)` ⇒ 约 **2 秒**（`p = currentCount / 60`）；p < 0.85 期间画闪电（`:2051`）。
## 收尾 `onSwapAnimComplete` 把遮罩/特效/进度条/确认钮复原。
static func 开始交换演出(态: Dictionary) -> void:
	var 页 := 态["页"] as Control
	# 遮罩：原版 `_swapMaskLayer` = `beginFill(0, 0.55)` + `drawRect(2,32,416,h-34)`
	# —— 场景里那枚「动画遮罩」就是它的几何占位，这里补上那层黑。
	var 遮 := 页.get_node("动画遮罩") as Control
	if 遮.get_node_or_null("暗") == null:
		var 暗 := ColorRect.new()
		暗.name = "暗"
		暗.set_anchors_preset(Control.PRESET_FULL_RECT)
		暗.color = Color(0.0, 0.0, 0.0, 0.55)
		暗.mouse_filter = Control.MOUSE_FILTER_IGNORE
		遮.add_child(暗)
	遮.visible = true
	# 特效层（`_swapEffectLayer`）
	var 效 := 页.get_node("特效层") as Control
	效.set_script(交换特效)
	效.set("进度", 0.0)
	# 进度条：原版 `_swapLoadingBar.x = 210; y = param1 - 20`（`param1` = 310 普通 / 410 特殊），
	# 而它内部容器再偏 (-90,-10) ⇒ 条的**左上角**在 AS3 (120, param1-30) ⇒ 场景 y 再减 29（窗口 29px 拖动区）。
	var 参数 := 410.0 if bool(态["特殊"]) else 310.0
	var 条 := 通用进度条.弹出(页, Vector2(120.0, 参数 - 30.0 - 29.0),
			"特性交换中..." if bool(态["特殊"]) else "属性交换中...")
	(页.get_node("确认钮") as Button).visible = false		# `:1983-1986` `_swapBtn.visible = false`
	var 计 := Timer.new()
	计.name = "交换演出计时"
	计.wait_time = 0.033
	计.one_shot = false
	页.add_child(计)
	态["演出"] = {"计时": 计, "特效": 效, "进度条": 条, "帧": 0}
	计.timeout.connect(演出一帧.bind(态))
	计.start()


static func 演出一帧(态: Dictionary) -> void:
	var 演: Dictionary = 态.get("演出", {})
	if 演.is_empty():
		return
	var 帧 := int(演["帧"]) + 1
	演["帧"] = 帧
	var p := minf(1.0, float(帧) / 60.0)
	(演["进度条"] as Control).call("设百分比", int(p * 100.0))
	var 效 := 演["特效"] as Control
	if 效 != null and is_instance_valid(效):
		效.set("进度", p)
	# 角色缩放脉动：`1 + 0.06 * sin(p*π*8)`（`:2064-2068`）
	var 页 := 态["页"] as Control
	var 倍 := 1.0 + 0.06 * sin(p * PI * 8.0)
	for 名 in ["立绘A", "立绘B"]:
		for 子 in (页.get_node(名) as Control).get_children():
			if 子 is OriginalSprite:
				(子 as OriginalSprite).scale = Vector2(倍, 倍)
	if 帧 >= 60:
		演出收尾(态)


static func 演出收尾(态: Dictionary) -> void:
	var 演: Dictionary = 态.get("演出", {})
	if 演.is_empty():
		return
	var 计 := 演["计时"] as Timer
	if 计 != null and is_instance_valid(计):
		计.stop()
		计.queue_free()
	var 页 := 态["页"] as Control
	if is_instance_valid(页):
		(页.get_node("动画遮罩") as Control).visible = false
		(页.get_node("确认钮") as Button).visible = true
		var 条 := 演["进度条"] as Control
		if 条 != null and is_instance_valid(条):
			条.queue_free()
		演["特效"].set("进度", 1.0)
	态.erase("演出")


## 交换帧：普通走 29、特性走 39（都只带**背包格号**）。
static func 发交换(宿主: Node, 态: Dictionary) -> void:
	var 后端 = 宿主.get("_backend")
	if 后端 == null:
		宿主._show_hint("交换要在服务端结算（离线不模拟）")
		return
	var 甲 := int((态["A"] as Dictionary).get("position", 0))
	var 乙 := int((态["B"] as Dictionary).get("position", 0))
	var 方法 := "request_transform_card_special_swap" if bool(态["特殊"]) else "request_transform_card_swap"
	if not (后端.has_method(方法) and bool(后端.call(方法, 甲, 乙))):
		宿主._show_hint("交换请求发送失败")
	# 发成功不提示：原版交换那一跳只重绘两格，没有回执文案。
