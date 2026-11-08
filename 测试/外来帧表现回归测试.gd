extends SceneTree

## 外来帧表现门：201/202（别人身上的状态）、203（队伍成员血蓝）、1329（玩家打玩家）、
## 1330（别人看到的血条）—— 这五条帧**服务端一直在发**，而客户端以前**一条都没分派**。
##
## 为什么必须有它（2026-10-22 夜，用户点名"外来 buff 201/202、PVP 伤害 1329/1330、
## 队伍成员属性 203"）：现查 `后端连接.gd` 的 196 条分派臂，201/202/1329/1330 **全部不在**，
## 203 虽然被分派到 `_handle_party_text`，但那一支把**第二段当动作号**解
## （`203` 其实不是动作帧）⇒ 角色号当成 action、match 不到任何一档 ⇒ 整条静默丢。
## 症状：两个人对打，旁观者看不见谁中毒、谁被封、谁隐身，也看不见打在人身上的伤害数字与血条。
##
## 真值（逐句转写的落点在 `脚本/角色/状态图标层.gd` 与 `脚本/地图/地图实体.gd`）：
## · `AllInOneProcessor.as:1043-1060` 201 → `Client:2654` → `SkillHandler.applyOtherPlayerBuff:363-423`
## · `:515-535` 202 → `Client:729` → `cancelOhterPlayerBuff:691-743`（**先按类型删图标、再走 switch**）
## · `AbstractLifeObject.as:203-247` 图标 `20×20`、`:151` 步距 18、`:154-155` 整层居中 + y=−40、
##   `:205` 键 = `类型_招号`、`:110-128` 移除只按**类型**
## · `:791-810` 1329 → `AbstractSkillEffect.applyPlayerSkillHit:331-433`
## · `:1081-1102` 1330 → `Client:5977-5985`（**是自己的那条直接 return**）→ `Character.setHpBarValue:680`
##   + `showHpBar:1515-1545`（`y = -_crtCharHeight - 11 - 2`、10 秒定时器）
## · `PartyProcessor.as:91` 203 → `RelationShipHandler.onUpdatePartyMemberStats:82-93`
##
## 跑法：Godot --headless --path . --script res://测试/外来帧表现回归测试.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 层名 := "状态图标层"
const 图标边 := 20.0
const 步距 := 18.0
const 层顶距 := -40.0
const 血条宽 := 54.0
const 血条高 := 11.0
## 每段必须钉满的条数（协程被运行期报错打断 ⇒ 后面整段没跑而末行照样打「红 0」）
const 应判 := 26
## 一个**真有图标**的招号：`数据/技能.json` 的 1001001，图标经 `技能素材索引` 落在
## `素材/技能/100/skill/Skill_100_skill_1001001.swf_1_…_icon.png`（阳性对照用，别换成不存在的号）
const 有图招 := 1001001
## 有"对手技"流水字的招号（`数据/技能对手技.json` 的 `0002000` = 针地藏）
const 流水招 := 2000
const 流水名 := "针地藏"

var 红 := 0
var 判数 := 0
var 场: Node
var 后: Node
var 图号 := 0
## 信号侧记账（解析层的判据靠它，不去猜渲染）
var 外来事件 := []
var 取消事件 := []
var 血条事件 := []
var 伤害事件 := []


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	call_deferred("_跑")


func _判(对: bool, s: String) -> void:
	判数 += 1
	if not 对:
		红 += 1
		print("红   " + s)


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _等(秒: float) -> void:
	await create_timer(秒).timeout


func _找场(节: Node) -> Node:
	if 节.get_script() != null and String(节.get_script().resource_path).ends_with("地图实体.gd"):
		return 节
	for 子 in 节.get_children():
		var 得 := _找场(子)
		if 得 != null:
			return 得
	return null


func _远程(号: int) -> Node2D:
	var 表: Dictionary = 场.get("_remote_players") as Dictionary if 场 != null else {}
	return 表.get(号) as Node2D


func _层(演员: Node2D) -> Node:
	return 演员.get_node_or_null(层名) if 演员 != null else null


## 层里"真建出来的一件"（占位但没图的那些件是 null，不算一件）
func _件们(层: Node) -> Array:
	var 出 := []
	if 层 == null:
		return 出
	for 键 in (层.get("项") as Dictionary):
		var 件: Variant = ((层.get("项") as Dictionary)[键] as Dictionary).get("件")
		if 件 != null and is_instance_valid(件):
			出.append(件)
	return 出


func _飘字们(演员: Node2D) -> Array:
	var 出 := []
	if 演员 == null:
		return 出
	for 子 in 演员.get_children():
		if 子.get_script() != null and String(子.get_script().resource_path).ends_with("伤害数字.gd"):
			出.append(子)
	return 出


func _飘字文本(件: Node) -> String:
	var 签 := 件.get("_标签") as Label
	return 签.text if 签 != null else ""


func _飘字颜色(件: Node) -> Color:
	var 签 := 件.get("_标签") as Label
	## 颜色走 `add_theme_color_override("font_color")`（`伤害数字.gd:60`），**不是 modulate** ——
	## 读 modulate 会永远拿到白，把"颜色对不对"这一族测成恒红或恒绿。
	return 签.get_theme_color("font_color") if 签 != null else Color(9, 9, 9, 9)


## 162 出生帧原文（29 段）—— 串本身沿用 `测试/后端协议回归测试.gd:454` 那条**已复核的夹具**，
## 只换角色号与地图号；第 14/15 段是 x/y，第 16 段是朝向。
func _出生帧(号: int) -> String:
	return "162:%d:远程忍者:100:0:0:10000003:10000006:0:-:-:0:0:0:%d:220:1:0:0:12:0:0:0:-:-:-:0:0:0" % [号, 图号]


func _收外来(号: int, 列表: Array, 延迟: int) -> void:
	外来事件.append({"号": 号, "列表": 列表, "延迟": 延迟})


func _收取消(号: int, 类型表: Array) -> void:
	取消事件.append({"号": 号, "类型": 类型表})


func _收血条(号: int, 最大hp: int, hp: int) -> void:
	血条事件.append({"号": 号, "最大hp": 最大hp, "hp": hp})


func _收伤害(信息: Dictionary) -> void:
	伤害事件.append(信息)


func _收(码: int = 0) -> void:
	print("外来帧表现回归测试：判 %d 条 / 红 %d 条" % [判数, 红])
	quit(码 if 红 == 0 else 1)


func _跑() -> void:
	var 场景: Node = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _帧(60)
	场 = _找场(场景)
	后 = root.get_node_or_null("BackendConnection")
	if 场 == null or 后 == null:
		for i in 应判:
			_判(false, "找不到 地图场景 或 BackendConnection ⇒ 后面全部判不了")
		_收()
		return
	图号 = int(场.call("_get_current_map_id"))
	if 图号 <= 0:
		for i in 应判:
			_判(false, "当前图号取出来是 %d ⇒ 162 会被地图过滤掉，后面全部判不了" % 图号)
		_收()
		return
	后.connect("foreign_buff_received", _收外来)
	后.connect("foreign_buff_cancelled", _收取消)
	后.connect("player_hp_received", _收血条)
	后.connect("player_damage_by_player_received", _收伤害)

	## ──  分派层：读源码文本（编译期事实，`load()` 照不到 match 臂）──
	var 源码 := ""
	var 文 := FileAccess.open("res://脚本/单例/后端连接.gd", FileAccess.READ)
	if 文 != null:
		源码 = 文.get_as_text()
		文.close()
	var 净 := ""
	for 行 in 源码.split("\n"):
		var 去 := 行.strip_edges()
		if 去.begins_with("#"):
			continue
		净 += 行 + "\n"
	var 有臂 := func(名: String) -> bool:
		return 净.contains("\t\t" + 名 + ":\n")
	_判(有臂.call("OP_GIVE_FOREIGN_BUFF") and 有臂.call("OP_CANCEL_FOREIGN_BUFF")
			and 有臂.call("OP_PLAYER_DAMAGE_PLAYER") and 有臂.call("OP_PLAYER_HP"),
			"① 201/202/1329/1330 四条分派臂必须都在 match 里（实得 201=%s 202=%s 1329=%s 1330=%s）" % [
			str(有臂.call("OP_GIVE_FOREIGN_BUFF")), str(有臂.call("OP_CANCEL_FOREIGN_BUFF")),
			str(有臂.call("OP_PLAYER_DAMAGE_PLAYER")), str(有臂.call("OP_PLAYER_HP"))])
	## 阳性对照：同一把尺子必须照到**早就存在**的 35 那一条，否则"找不到"是尺子坏了
	_判(有臂.call("OP_GIVE_BUFF"), "② 阳性对照：同一把尺子要照得到已有的 35 分派臂（照不到=判据本身坏）")
	_判(净.contains("OP_PARTY_RESPONSE:\n") and not 净.contains("OP_PARTY_RESPONSE, OP_PARTY_MEMBER_STATE:"),
			"③ 203 必须**从队伍动作帧那一支拆出来**（还并在一起=角色号被当 action 丢）")

	## ── ④ 建一个远程玩家，后面全挂在他身上 ──
	## 先把后端摆成"真的在游戏里、当前就在这张图"——`_on_server_player_spawned` 第一行就挡 `in_game`，
	## 不摆这两下会整条静默不建，那 21 条判据一条都跑不到（这就是"门自己没喂对状态"的假绿）。
	后.set("in_game", true)
	后.call("_apply_map_state", 图号, 120, 220, 100)
	后.call("_handle_bridge_text", _出生帧(7301))
	await _帧(8)
	var 甲 := _远程(7301)
	_判(甲 != null, "④ 喂一发 162 原文 ⇒ 远程玩家必须建出来（查无 7301）")
	if 甲 == null:
		for i in 应判 - 4:
			_判(false, "④ 之后全部判不了：远程玩家没建出来")
		_收()
		return

	## ── 201 一枚 ──
	后.call("_handle_bridge_text", "201:7301:%d&0.5&%d&1&8000:0" % [9, 有图招])
	await _帧(6)
	var 层 := _层(甲)
	_判(层 != null and _件们(层).size() == 1,
			"⑤ 201 一档 POISON(9) ⇒ 头顶状态图标层要有 1 枚（实得 %d 枚）" % (_件们(层).size() if 层 != null else -1))
	if 层 != null and _件们(层).size() == 1:
		var 一件 := _件们(层)[0] as Control
		_判(一件.size == Vector2(图标边, 图标边),
				"⑥ 图标必须 20×20（原版 `AbstractLifeObject.as:244` width=height=20；实得 %s）" % str(一件.size))
	else:
		_判(false, "⑥ 判不了：没有那枚图标")

	## ── 201 第二枚（同一类型不同招 = 两枚；步距 18；整层居中）──
	后.call("_handle_bridge_text", "201:7301:%d&0.5&%d&1&8000:0" % [22, 有图招 + 1])
	await _帧(6)
	var 件们 := _件们(层)
	_判(件们.size() == 2, "⑦ 再来一档 REDUCE_AVD(22) ⇒ 两枚（键是 类型_招号，实得 %d 枚）" % 件们.size())
	var 序 := []
	for 件 in 件们:
		序.append(roundf((件 as Control).position.x))
	序.sort()
	_判(序 == [0.0, 步距], "⑧ 两枚的 x 必须是 0 与 18（`:151` x=18*i；实得 %s）" % str(序))
	var 期望x := -(步距 * 1.0 + 图标边) * 0.5
	var 层位: Vector2 = 层.position if 层 != null else Vector2(99, 99)
	_判(absf(层位.x - 期望x) < 0.001 and absf(层位.y - 层顶距) < 0.001,
			"⑨ 整层水平居中、y=-40（`:154-155`；实得 %.3f, %.3f，期望 %.1f, %.1f）" % [
			层位.x, 层位.y, 期望x, 层顶距])

	## ── 202 按类型删（一删就把该类型的所有招都删）──
	后.call("_handle_bridge_text", "202:7301:9")
	await _帧(6)
	_判(_件们(层).size() == 1,
			"⑩ 202 删类型 9 ⇒ 只剩那一枚 22（实得 %d 枚）" % _件们(层).size())

	## ── 原版空 case 的那几档：不许建图标 ──
	后.call("_handle_bridge_text", "201:7301:%d&0.2&%d&1&5000:0" % [14, 有图招])
	await _帧(6)
	_判(_件们(层).size() == 1,
			"⑪ ADD_ATK(14) 在原版 `:411-415` 的 case 体是空的 ⇒ 不许多出一枚（实得 %d 枚）" % _件们(层).size())

	## ── 隐身(5)：不建图标，但要清掉对他的选中 ──
	后.call("_handle_bridge_text", "201:7301:5&0&%d&1&6000:0" % 有图招)
	await _帧(6)
	var 隐身表: Dictionary = 场.get("_隐身角色") as Dictionary
	_判(bool(隐身表.get(7301, false)) and _件们(层).size() == 1,
			"⑫ DARKSIGHT(5) ⇒ 记隐身旗、不建图标（旗=%s，枚=%d）" % [
			str(bool(隐身表.get(7301, false))), _件们(层).size()])
	场.call("_select_character", 甲, {"name": "远程忍者"})
	await _帧(4)
	## 先钉"选中确实生效"，否则后面那条"隐身把选中清掉了"是**拿没建立起来当通过**（假绿）。
	_判(场.get("_selected_character") == 甲, "⑬-a 夹具先要真的把他选中（没选中 ⇒ 下一条等于没判）")
	后.call("_handle_bridge_text", "201:7301:5&0&%d&1&6000:0" % 有图招)
	await _帧(6)
	_判(场.get("_selected_character") == null or not is_instance_valid(场.get("_selected_character")),
			"⑬ 他隐身时若正被选中 ⇒ 选中要清掉（`TargetHandler.as:261` 隐身者不可选）")

	## ── 变暗(18)：只暗身体动画，取消后回原样 ──
	var 精灵 := 甲.get_child(0) as CanvasItem
	后.call("_handle_bridge_text", "201:7301:18&0&%d&1&4000:0" % 有图招)
	await _帧(6)
	_判(精灵 != null and absf(精灵.modulate.r - 0.25) < 0.001 and 精灵.modulate.g == 精灵.modulate.r,
			"⑭ ADD_ATK_SPEED(18) ⇒ 身体乘 0.25 的暗（`Darkness.applyTo(anim, 0.25)`；实得 %s）" % str(精灵.modulate))
	后.call("_handle_bridge_text", "202:7301:18")
	await _帧(6)
	_判(精灵 != null and 精灵.modulate == Color(1, 1, 1, 1),
			"⑮ 202 取消 18 ⇒ 回到不暗（`Darkness.clearupFrom`；实得 %s）" % str(精灵.modulate))

	## ── 1329 段序：被打者在最后一段，飘字要落在他头上 ──
	后.call("_handle_bridge_text", "162:%d:另一个:100:0:0:10000003:10000006:0:-:-:0:0:0:%d:220:1:0:0:12:0:0:0:-:-:-:0:0:0" % [7302, 图号])
	await _帧(8)
	var 乙 := _远程(7302)
	后.call("_handle_bridge_text", "1329:7301:123:0:%d:1:false:1:7302" % 有图招)
	await _帧(6)
	_判(伤害事件.size() == 1 and int((伤害事件[0] as Dictionary).get("victim_id", 0)) == 7302
			and int((伤害事件[0] as Dictionary).get("attacker_id", 0)) == 7301,
			"⑯ 1329 段序 = 打人者在第 1 段、被打者在最后一段（实得 %s）" % str(伤害事件))
	await _等(1.0)
	_判(乙 != null and _飘字们(乙).size() == 1 and _飘字文本(_飘字们(乙)[0]).contains("123"),
			"⑰ 伤害数字要落在**被打的那个**头上（乙实得 %d 条；甲不该有：%d 条）" % [
			_飘字们(乙).size() if 乙 != null else -1, _飘字们(甲).size()])

	## ── 1329 暴击：别人 = 「暴击」，不是「致命」──
	后.call("_handle_bridge_text", "1329:7301:88:1:%d:1:true:-1:7302" % 有图招)
	await _等(1.0)
	var 乙飘 := _飘字们(乙)
	## ⚠ 只数"还活着的那几条"：一条飘字活 1.2 秒就被自己 free（两段各 0.6 秒），
	## 所以这里判"最后一条"而不是"至少两条"—— 等得久一点上一条就已经离场了。
	_判(乙飘.size() >= 1 and _飘字文本(乙飘[乙飘.size() - 1]).contains("暴击"),
			"⑱ 暴击且被打的是别人 ⇒ 前缀「暴击」（`:396-403` 那个 `== API.player` 分支才给「致命」）；末条实得「%s」" % (
			_飘字文本(乙飘[乙飘.size() - 1]) if 乙飘.size() > 0 else "〈无〉"))

	## ── 1329 状态没生效 ⇒ 追一条蓝色流水字 ──
	后.call("_handle_bridge_text", "1329:7301:0:0:%d:1:false:1:7302" % 流水招)
	## ⚠ 只能等 1.0 秒：一条飘字活 1.2 秒就 self-free，等 1.6 秒就什么都扫不到了
	## （第一次跑这条红就是这个原因，不是没飘）。
	await _等(1.0)
	var 找蓝 := false
	for 件 in _飘字们(乙):
		var 色 := _飘字颜色(件)
		if _飘字文本(件).contains(流水名) and absf(色.r - 50.0 / 255.0) < 0.01 and absf(色.b - 1.0) < 0.01:
			找蓝 = true
	_判(找蓝, "⑲ skillTrigger=false ⇒ 追加一条 #3299FF 的流水字「%s」（`:355-359` + `CocoStatType.SKILL`）" % 流水名)

	## ── 1330：自己的那条不许发信号（原版 `Client:5979-5982` 先 return）──
	var 我号 := int(后.get("character_id"))
	后.call("_handle_bridge_text", "1330:%d:1000:999" % 我号)
	await _帧(6)
	_判(血条事件.is_empty(),
			"⑳ 1330 打给自己的那条必须整条丢（原版是自己的 objectId 就 return；实得 %d 条）" % 血条事件.size())
	后.call("_handle_bridge_text", "1330:7302:1000:250")
	await _帧(6)
	_判(血条事件.size() == 1 and int((血条事件[0] as Dictionary).get("最大hp", 0)) == 1000
			and int((血条事件[0] as Dictionary).get("hp", 0)) == 250,
			"㉑ 1330 别人的那条要解出 最大hp/hp（实得 %s）" % str(血条事件))
	var 条 := 乙.get_node_or_null("HpBar") if 乙 != null else null
	var 比例 := float(条.get("_比例")) if 条 != null else -1.0
	_判(条 != null and absf(比例 - 0.25) < 0.001,
			"㉒ 远程玩家头顶要建出血条且比例 = hp/最大hp = 0.25（实得 %s）" % str(比例))
	if 条 != null:
		var 期望y := -_角色高(乙) - 血条高 - 2.0
		_判(absf((条 as Node2D).position.y - 期望y) < 0.01
				and absf((条 as Node2D).position.x + 血条宽 * 0.5) < 0.01,
				"㉓ 血条摆位 = x:-27、y:-当帧贴图高-11-2（`Character.as:1526-1527`；实得 %.2f, %.2f，期望 %.2f, %.2f）" % [
				(条 as Node2D).position.x, (条 as Node2D).position.y, -血条宽 * 0.5, 期望y])
		场.call("_推进远程血条", 11.0)
		await _帧(4)
		_判(not (条 as CanvasItem).visible, "㉔ 过 10 秒要自己隐掉（`showHpBar` 那条定时器）")
	else:
		_判(false, "㉓ 判不了：血条没建出来")
		_判(false, "㉔ 判不了：血条没建出来")

	## ── 203：不是动作帧，要能落到同一条血条落点 ──
	后.call("_handle_bridge_text", "203:7301:400:800:30:60")
	await _帧(6)
	var 成员表: Dictionary = 场.get("_队伍成员状态") as Dictionary
	var 甲条 := 甲.get_node_or_null("HpBar") if 甲 != null else null
	_判(int((成员表.get(7301, {}) as Dictionary).get("hp", -1)) == 400
			and int((成员表.get(7301, {}) as Dictionary).get("maxmp", -1)) == 60
			and 甲条 != null and absf(float(甲条.get("_比例")) - 0.5) < 0.001,
			"㉕ 203 ⇒ 记进队伍成员状态 + 那个人头顶血条按 hp/maxhp=0.5 显形（实得 %s、条=%s）" % [
			str(成员表.get(7301, {})), "无" if 甲条 == null else str(甲条.get("_比例"))])
	_收(0)


## 当帧贴图高（与 `地图实体._角色头顶锚点` 同一口径，判据里要自己算一遍，不许问被测对象要）
func _角色高(演员: Node2D) -> float:
	var 精灵 := 演员.get_child(0) as Node2D
	if 精灵 != null and 精灵.has_method("当前贴图高度"):
		return float(精灵.call("当前贴图高度"))
	return 0.0
