extends RefCounted
## 家族升级窗（家徽升级）数据填充。
##
## 口径 = **单机版 hub 通道**（我们夹具实际走的那条）：
##   服务端 `_handle_multiplayer_family` 的 `action == 10`：
##     `money_cost = 666`、`item_costs = {16000023..16000026: 1}`、`next_level > 10` 直接拒绝；
##     扣的是**家族资金 `family.fund`** 与**家族材料 `family.materials`**，
##     **不是玩家自己的金币/背包**（那是另一条无 hub 的本地通道的口径）。
##   客户端同源真值：`getFamillyUpgradeCfg()` 也是 `{money:666, item:[{count:1}×4]}`
##   且 `level >= 10` 时返回 null。
##
## ⚠️ 我们原来读的是 `family_flag_config(等级+1).cost` —— 那是**原始线上数据**
##    （2 级 1000 万、3 级 3000 万…最高 52 亿），和单机版服务端收的 666 差着好几个数量级。
##    后果：升级窗显示"要 1000 万"、服务端只收 666，而家族资金根本不够 1000 万时按钮还会被
##    错误禁用 —— 玩家永远升不了级。这个文件就是来修这条口径的。
##
## 家族资金/材料来自 `authoritative_guild.fund` / `.materials`
## （后端 `_handle_guild_text` 的 action 5 解析，源是服务端 `_send_family_contribution`）。

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 家族页回调 := preload("res://脚本/界面/窗口/家族/家族页回调.gd")

## ⚠️⚠️ **这两个常量绝不能带 `#`**：下面两行模板写的是 `[color=#%s]`（已经有一个 `#`），
##    常量再带一个就拼成 `[color=##00ff00]` —— `Color.html()` 对这种串**解析失败并返回黑色**
##    （实测：`Color.html("##00ff00")` = (0,0,0,1)），于是"够"的数字本该是绿的、变成**黑的**，
##    在深色窗皮上等于看不见。`装备提示框.gd` 那边同一模式的常量走 `Color.to_html(false)`
##    （不带 `#`）就是对的。
const 足色 := "00ff00"
const 缺色 := "ff5a5a"


static func 填(页: Control, 宿主: Node) -> void:
	if 页 == null or 宿主 == null or String(页.name) != "家族升级窗":
		return
	var 后端 := 宿主.get_node_or_null("/root/BackendConnection")
	if 后端 != null and 后端.has_signal("guild_state_received") and not 页.has_meta("guild_upgrade_hooked"):
		页.set_meta("guild_upgrade_hooked", true)
		家族页回调.挂(页, 后端.guild_state_received, func(_state: Dictionary) -> void: 填(页, 宿主))
	var 家族: Dictionary = {}
	if 后端 != null:
		家族 = (后端.get("authoritative_guild") as Dictionary).duplicate(true)
	var 当前等级 := maxi(1, int(家族.get("level", 1)))
	var 已入族 := bool(家族.get("joined", false))
	# 家族资金/材料只在服务端发过贡献帧（action 5）之后才知道。
	# ⚠️ **不知道就绝不据此禁用**：拿 0 当"不够"会把升级按钮永久锁死 ——
	#    宁可放行让服务端拒（它会回「家族资金不足，升级需要 666 金币。」这种权威提示）。
	var 经济已知 := 家族.has("materials") or 家族.has("fund")
	var 配置 := 游戏数据.family_upgrade_cost(当前等级 + 1)
	_拉家族数据(页, 后端, 已入族)
	var 文本 := 页.get_node_or_null("文本升级说明") as RichTextLabel
	var 确定 := 页.get_node_or_null("钮确定") as TextureButton
	if 文本 == null:
		return

	if 配置.is_empty():
		# 已满级：原版 `getFamillyUpgradeCfg()` 这时返回 null，窗口把占位符全替换成空格、
		# 「确定」置灰。文案照 `CN.FAMILLY_UPGRADE_WINDOW_DESC_TANPLATE` 的占位符位置排。
		文本.text = "家族旗帜已经达到最高等级（%d 级）" % 游戏数据.家族最高等级
		if 确定 != null:
			确定.disabled = true
		return

	# 家族资金/材料**只在服务端发过贡献帧（action 5）之后才知道**（`经济已知` 已在上方判定）。
	var 资金 := int(家族.get("fund", 0))
	var 材料: Dictionary = (家族.get("materials", {}) as Dictionary) if 家族.get("materials", null) is Dictionary else {}
	var 金币需求 := int(配置.get("money", 0))
	var 行 := "[color=#ff9100]家族资金：[/color][color=#%s]　%s / %d[/color]\n" % [
		足色 if (not 经济已知 or 资金 >= 金币需求) else 缺色,
		str(资金) if 经济已知 else "?", 金币需求]
	var 缺料 := 0
	for 项 in (配置.get("item", []) as Array):
		var 条目 := 项 as Dictionary
		var 物品号 := int(条目.get("id", 0))
		var 需求 := int(条目.get("count", 0))
		var 拥有 := int(材料.get(物品号, 材料.get(str(物品号), 0)))
		if 经济已知 and 拥有 < 需求:
			缺料 += 1
		行 += "[color=#ff9100]%s：[/color][color=#%s]　%s / %d[/color]\n" % [
			游戏数据.family_material_name(物品号, "家族材料"),
			足色 if (not 经济已知 or 拥有 >= 需求) else 缺色,
			str(拥有) if 经济已知 else "?", 需求]
	行 += "\n[color=#00ff00]家族升级之后家徽也将升级，更高级的家徽将获得更多的属性加成[/color]"
	if not 已入族:
		行 += "\n[color=#ff5a5a]你还没有加入家族。[/color]"
	elif 经济已知 and (资金 < 金币需求 or 缺料 > 0):
		# 捐献入口就在家族页的「族贡」两窗（金币窗捐金币、令牌窗捐书），提示一下省得来回找。
		行 += "\n[color=#ffd76a]不足的部分可先在「族贡」里捐献，再回来升级。[/color]"
	文本.text = 行

	if 确定 != null:
		# 只在**已知**经济数据时才据它禁用（见上面 `经济已知` 的说明）。
		确定.disabled = not 已入族 or (经济已知 and (资金 < 金币需求 or 缺料 > 0))
	# ⛔⛔ **这里原来还有一条 `确定.pressed.connect(...)` —— 必须删掉，别再加回来**（§3.140）：
	#    `家族子窗.gd:53` 已经给**所有带 `metadata/act` 的 TextureButton** 统一接了一条
	#    `_发动作(act)` ⇒ `_show_guild_action("家族升级窗:确定")`。升级窗场景里这两颗钮
	#    恰好都写了 `metadata/act`（"确定"/"取消"），于是点一次「确定」会**触发两遍**同一个动作：
	#      第一遍 ⇒ 壳按开窗表把 `家族确认弹` 开出来；
	#      第二遍 ⇒ 壳发现它已经开着 ⇒ 按"再点同一个入口 = 收起"**当场关掉**。
	#    净效果 = 弹窗开一下就没 ⇒ 玩家看到的就是"**点升级完全没反应**"
	#    （用户 2026-10-15 报的，正是这条；`pressed.emit()` 与真点击都会复现）。
	#    ⚠️ 同类坑：**任何填充脚本都不要给"场景里已写 `metadata/act` 的钮"再接 pressed** ——
	#       统一走子窗的通用接线（要发协议的在 `功能窗口._show_guild_action` 里按动作名分支）。


## 开窗时主动拉一次家族数据（服务端 action 104 → `_send_family_contribution` → 回 action 5 帧，
## 家族资金与材料库存只在那帧里）。用 meta 挡住重复发送。
static func _拉家族数据(页: Control, 后端: Node, 已入族: bool) -> void:
	if 后端 == null or not 已入族 or 页.has_meta("guild_upgrade_pulled"):
		return
	页.set_meta("guild_upgrade_pulled", true)
	后端.call("request_guild_members", 0, false)
