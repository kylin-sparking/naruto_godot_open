extends SceneTree

## 忍术「勾玉/玉链 +N 层」离线门（2026-10-31）。
##
## 用户报的原话：「客户端仍不处理 SKILL_CHANGE_TMP(1813)（忍术页只显示基础层）」。
## 修前客户端只认 1814，服务端每次刷新都会发的 1813 落在 `_handle_original_frame` 的
## 「收到**没接的**原始二进制回帧」告警里 ⇒ 忍术页永远只有基础层（加成只在服务端伤害结算里）。
##
## 真值（逐条到行）：
##   * 报文：`AllInOneProcessor.as:576-607 handleTmpSkillChange` 只读两段
##     `id = readInt()` / `skillLevel = readInt()`，`masterLevel = 0`；
##     服务端 `fake_flash_server.py:49667 _send_skill_gem_bonuses` 发
##     `<i 条数>` + 每行 `struct.pack("<ii", skill_id, bonus)`，**只在 `wire_mode == "original"`** 时发
##     （`BaseClient.as:155` 把收帧 buffer 设成 LITTLE_ENDIAN ⇒ 全帧小端）。
##   * 语义：`DataCenter.as:566-578 setAddedSkillLevelList` **先 delete 光旧表再填** ⇒
##     卸下勾玉（加成消失）靠服务端发一张空表，**不是 merge**。
##   * 展示：`DataCenter.as:795-810 getAddedSkillLevel` = `addedSkillLevel + list[id]`
##     （夫妻技恒 0；世界忍术再 += addedWorldSkillLevel、职业忍术再 += addedJobSkillLevel）。
##     `SkillCell.as:216-227`：格子文字 = `floor`，只有 `floor>0 && added>0 && isMySkill`
##     才写成 `floor+"+"+added`；**详情区不跟** —— `SkillDetailPane.as:160` 只印 `param1.floor`。
##
## 五段腿：① 1813 回帧解码（补零键 / 整表替换 / 空表 / 坏帧丢弃）
##          ② 会话公式（勾玉 + 世界 + 职业 + 夫妻技 0 + 未知 0）
##          ③ 格子文字与详情区口径 ④ 功能窗口把 `added_level` 挂到页签条目上（且不改存档数据）
##          ⑤ 接线判据（客户端两处 + 服务端仍按原版发两段）
##
## 跑法：Godot --headless --path . --script res://测试/忍术勾玉加成回归测试.gd

const 测试后端 := preload("res://测试/测试后端连接.gd")
const 功能窗口 := preload("res://脚本/界面/功能窗口.gd")
const 忍术窗口 := preload("res://脚本/界面/窗口/忍术窗口.gd")

const 出 := "res://测试/截图/忍术勾玉加成.txt"
const 存档 := "user://玩家数据.json"
const 设置档 := "user://玩家设置.json"
const 后端源 := "res://脚本/单例/后端连接.gd"
const 会话源 := "res://脚本/单例/游戏会话.gd"
const 功能窗源 := "res://脚本/界面/功能窗口.gd"
const 忍术窗源 := "res://脚本/界面/窗口/忍术窗口.gd"
const 服务端源 := "res://服务端/runtime/tools/fake_flash_server.py"

var 判 := 0
var 红 := 0
var 日志: Array[String] = []
var 存前 := PackedByteArray()
var 设前 := PackedByteArray()
var 收到: Array = []
var 会
var 假
var 备层 := {}
var 备技能: Array[Dictionary] = []
var 备统计 := {}
var 备有 := {}


func _判(过: bool, 说: String) -> void:
	判 += 1
	日志.append("%s %s" % ["ok " if 过 else "!!红", 说])
	if not 过:
		红 += 1


func _字节(路: String) -> PackedByteArray:
	if not FileAccess.file_exists(路):
		return PackedByteArray()
	var g := FileAccess.open(路, FileAccess.READ)
	if g == null:
		return PackedByteArray([1])
	var 字 := g.get_buffer(g.get_length())
	g.close()
	return 字


## 剥掉注释行再比 —— 注释里会写旧字段名与 AS3 标识符，拿原文 grep 会自证。
func _净码(路: String) -> String:
	var g := FileAccess.open(路, FileAccess.READ)
	if g == null:
		return ""
	var 文 := g.get_buffer(g.get_length()).get_string_from_utf8()
	g.close()
	var 留: Array[String] = []
	for 行 in 文.split("\n"):
		if 行.lstrip("\t ").begins_with("#"):
			continue
		留.append(行)
	return "\n".join(留)


func _尾() -> void:
	会.skill_added_levels = 备层
	会.learned_skills.assign(备技能)
	for 键 in ["add_world_skill_level", "add_job_skill_level", "job"]:
		if bool(备有.get(键, false)):
			会.player_stats[键] = 备统计[键]
		else:
			会.player_stats.erase(键)
	_判(_字节(存档) == 存前, "门不许动存档（%s 字节一致）" % 存档)
	_判(_字节(设置档) == 设前, "门不许动设置档（%s 字节一致）" % 设置档)
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(日志) + "\n")
		f.close()
	for 行 in 日志:
		print(行)
	if 红 == 0:
		print("忍术勾玉加成回归测试：通过（%d 条断言）" % 判)
	else:
		printerr("忍术勾玉加成回归测试：红 %d 条（共 %d）" % [红, 判])
	quit(0 if 红 == 0 else 1)


## 体 = 长度/校验和 4 字节（客户端不验）+ 小端 opcode + 载荷。
func _包(载荷: PackedByteArray) -> PackedByteArray:
	var 体 := PackedByteArray()
	体.resize(6)
	体.encode_u16(4, 1813)
	体.append_array(载荷)
	return 体


## `<i 条数>` + 每行 `<ii 忍术号, 加成层>`（小端）。
func _载荷(行: Array) -> PackedByteArray:
	var 载 := PackedByteArray()
	载.resize(4 + 行.size() * 8)
	载.encode_s32(0, 行.size())
	var 位 := 4
	for 条 in 行:
		载.encode_s32(位, int(条[0]))
		载.encode_s32(位 + 4, int(条[1]))
		位 += 8
	return 载


func _层() -> Dictionary:
	return 假.get("authoritative_skill_added_levels")


func _帧腿() -> void:
	日志.append("=== ① 1813 原始回帧解码（AllInOneProcessor.as:576-607 / send_original_packet）===")
	假.call("_handle_original_frame", _包(_载荷([[1002001, 2], [3002, 7]])))
	var 表 := _层()
	_判(表.size() == 2 and int(表.get("1002001", -1)) == 2 and int(表.get("0003002", -1)) == 7,
			"两行（1002001→2、3002→7）解成补零七位的表，实际 %s" % str(表))
	_判(not 表.has("3002"),
			"键一律补到七位（与 `learned_skills[i].id` 同一套），没补零的 3002 不许留着")
	var 首帧: Dictionary = 收到[0] if 收到.size() == 1 and 收到[0] is Dictionary else {}
	_判(收到.size() == 1 and int(首帧.get("0003002", -1)) == 7 and int(首帧.get("1002001", -1)) == 2,
			"`skill_added_levels_received` 发的是这张表（页面靠它重画），实收 %d 次" % 收到.size())
	_判(int(会.skill_added_levels.get("0003002", -1)) == 7
			and int(会.skill_added_levels.get("1002001", -1)) == 2,
			"解码后镜像进 `GameSession.skill_added_levels`（忍术页读的是它），实为 %s"
			% str(会.skill_added_levels))

	假.call("_handle_original_frame", _包(_载荷([[3002, 3]])))
	_判(_层().size() == 1 and int(_层().get("0003002", -1)) == 3,
			"第二帧只带 3002 ⇒ 旧那张**整份替换**（原版先 delete 再填），1002001 必须消失，实际 %s" % str(_层()))

	假.call("_handle_original_frame", _包(_载荷([])))
	# 前三帧（两行 / 一行 / 空表）各发一次 —— 空表也是一张真表，要发信号让页面重画。
	_判(_层().is_empty() and 会.skill_added_levels.is_empty() and 收到.size() == 3,
			"空表（卸下勾玉/玉链）⇒ 两处都清空，且照发信号（实收 %d 次）" % 收到.size())

	# 下面三张坏帧：**既不许落表、也不许发信号**（发一张空表会把旧加成误清）。
	var 坏 := _载荷([[3002, 3]])
	坏.encode_s32(0, 2)		# 声称两行、实际一行
	var 信 := 收到.size()
	假.call("_handle_original_frame", _包(坏))
	_判(_层().is_empty() and 收到.size() == 信,
			"条数与载荷长度对不上 ⇒ 整帧丢弃（不许收半张表、不发信号）")

	var 负 := _载荷([])
	负.encode_s32(0, -1)
	信 = 收到.size()
	假.call("_handle_original_frame", _包(负))
	_判(_层().is_empty() and 收到.size() == 信,
			"条数为负 ⇒ 整帧丢弃（不发信号）")

	信 = 收到.size()
	假.call("_handle_original_frame", _包(PackedByteArray([2, 0])))
	_判(_层().is_empty() and 收到.size() == 信,
			"载荷不足 4 字节（读不出条数）⇒ 丢弃，且不发信号（实收信号 %d 次）" % 收到.size())


func _文本腿() -> void:
	日志.append("=== ①b AMF3 文本帧（1813:<条数>[:<忍术号>:<加成层>…]，本客户端实机走这条）===")
	假.call("_handle_bridge_text", "1813:2:1002001:2:3002:7")
	var 表 := _层()
	_判(表.size() == 2 and int(表.get("1002001", -1)) == 2 and int(表.get("0003002", -1)) == 7,
			"文本帧两行解成补零七位的表，实际 %s" % str(表))
	_判(int(会.skill_added_levels.get("0003002", -1)) == 7,
			"文本帧同样镜像进 GameSession（实机忍术页读的就是它），实为 %s"
			% str(会.skill_added_levels))
	假.call("_handle_bridge_text", "1813:1:3002:3")
	_判(_层().size() == 1 and int(_层().get("0003002", -1)) == 3,
			"文本帧同样是**整表替换**（旧行的 1002001 必须消失），实际 %s" % str(_层()))
	var 信 := 收到.size()
	假.call("_handle_bridge_text", "1813:2:3002")
	_判(_层().size() == 1 and 收到.size() == 信,
			"条数与字段数对不上 ⇒ 整帧丢弃（旧表不动、不发信号）")
	信 = 收到.size()
	假.call("_handle_bridge_text", "1813:-1")
	_判(_层().size() == 1 and 收到.size() == 信,
			"条数为负 ⇒ 整帧丢弃（不发信号）")
	假.call("_handle_bridge_text", "1813:0")
	_判(_层().is_empty() and 会.skill_added_levels.is_empty() and 收到.size() == 信 + 1,
			"空表 `1813:0` ⇒ 两处清空并照发信号（卸下玉链/勾玉）")


func _会话腿() -> void:
	日志.append("=== ② 会话公式（DataCenter.as:795-810 getAddedSkillLevel）===")
	会.skill_added_levels = {}
	会.player_stats["add_world_skill_level"] = 20
	会.player_stats["add_job_skill_level"] = 10
	# 0009029（特别技能）= 普通忍术；1001/3002/3301 分别落职业/世界/夫妻技三档。
	会.apply_added_skill_levels({"9029": 2, "3002": 7, "3301": 4, "1001": 5})
	_判(会.skill_added_levels.has("0003002") and 会.skill_added_levels.has("0003301")
			and 会.skill_added_levels.has("0001001") and not 会.skill_added_levels.has("3002"),
			"`apply_added_skill_levels` 归一成七位键（int/短键都不许留原样）")
	_判(会.added_skill_level("0009029") == 2,
			"普通忍术（三张表都不在）：只有勾玉那 2 层，实际 %d" % 会.added_skill_level("0009029"))
	_判(会.added_skill_level("0003002") == 27,
			"世界忍术（Job0.isWorldSkill）：勾玉 7 + add_world_skill_level 20 = 27，实际 %d"
			% 会.added_skill_level("0003002"))
	_判(会.added_skill_level("0001001") == 15,
			"职业忍术：勾玉 5 + add_job_skill_level 10 = 15，实际 %d"
			% 会.added_skill_level("0001001"))
	_判(会.added_skill_level("0003301") == 0,
			"夫妻技（Job0.isCoupleSkill）恒 0，表里写着 4 也不许加，实际 %d"
			% 会.added_skill_level("0003301"))
	_判(会.added_skill_level("0009999") == 0,
			"表里没有的忍术 ⇒ 0（原版 `int(undefined)` 也是 0），实际 %d"
			% 会.added_skill_level("0009999"))


func _显示腿() -> void:
	日志.append("=== ③ 格子文字 / 详情区（SkillCell.as:216-227 / SkillDetailPane.as:160）===")
	_判(忍术窗口.层数文字({"level": 5, "added_level": 2}) == "5+2",
			"基础 5、加成 2 ⇒ 「5+2」")
	_判(忍术窗口.层数文字({"level": 0, "added_level": 2}) == "0",
			"基础 0（没学）⇒ 只印 0，不印「0+2」（原版 `floor > 0` 那一条）")
	_判(忍术窗口.层数文字({"level": 5, "added_level": 0}) == "5",
			"加成为 0 ⇒ 只印 5（原版 `added > 0` 那一条）")
	_判(忍术窗口.层数文字({"level": 3}) == "3",
			"条目里没有 `added_level` ⇒ 按 0 处理，不许崩")


func _功能窗腿() -> void:
	日志.append("=== ④ 功能窗口把 added_level 挂到页签条目上（且不改会话里的那一条）===")
	会.learned_skills.assign([{"id": "1002001", "name": "怪力", "level": 5, "master_level": 0,
		"cooldown": 1.0, "icon": "res://图标/测试占位.png"}])
	# 两条世界/职业统计清零 ⇒ 这一条只剩勾玉那 2 层，免得和 ② 的 15/27 混淆。
	会.player_stats["add_world_skill_level"] = 0
	会.player_stats["add_job_skill_level"] = 0
	会.player_stats["job"] = 200
	会.apply_added_skill_levels({"1002001": 2})
	var 窗 = 功能窗口.new()
	窗.set("_session", 会)
	var 表: Array = 窗._skills_for_tab(0)
	窗.free()
	var 条 := {}
	for 项 in 表:
		if String(项.get("id", "")) == "1002001":
			条 = 项
			break
	_判(not 条.is_empty() and int(条.get("added_level", -1)) == 2,
			"职业忍术页里 1002001 那条带上 `added_level` = 2（勾玉那 2 层），实为 %s"
			% str(条.get("added_level", "缺")))
	_判(not 会.learned_skills[0].has("added_level"),
			"会话里那条**没被写脏**（`_skill_with_icon` 有图标时原样返回 ⇒ 必须先拷一份）")


func _接线腿() -> void:
	日志.append("=== ⑤ 接线判据（源码钉）===")
	var 后 := _净码(后端源)
	var 会源 := _净码(会话源)
	var 功 := _净码(功能窗源)
	var 忍 := _净码(忍术窗源)
	var 服 := _净码(服务端源)
	_判(后.contains("const OP_SKILL_CHANGE_TMP := 1813"),
			"`后端连接` 认了 1813 这个 opcode（修前只认 1814，1813 落进「没接的」告警）")
	_判(后.contains("if opcode == OP_SKILL_CHANGE_TMP:") and 后.contains("_decode_skill_change_tmp(payload)"),
			"`_handle_original_frame` 把 1813 交给解码器")
	_判(后.contains("authoritative_skill_added_levels = 表")
			and not 后.contains("authoritative_skill_added_levels.merge"),
			"解码落表是**整份赋值**（原版先清空再填），不是 merge")
	_判(后.contains("session.apply_added_skill_levels(表)"),
			"解码后转进 GameSession（页面读的是会话那张表）")
	_判(后.contains("authoritative_skill_added_levels.clear()"),
			"断线复位一起清（否则重连后玉链还没穿上的那段会印着上一局的 +N）")
	_判(会源.contains("func apply_added_skill_levels(表: Dictionary) -> void:")
			and 会源.contains("归一[str(int(键)).pad_zeros(7)] = int(表[键])"),
			"会话的落表函数把键归一成七位")
	_判(会源.contains("func added_skill_level(skill_id: String) -> int:")
			and 会源.contains("if 号 in 情侣忍术:") and 会源.contains("return 0"),
			"`added_skill_level` 先判夫妻技恒 0（原版那个 else 分支）")
	_判(会源.contains("层 += int(player_stats.get(\"add_world_skill_level\", 0))")
			and 会源.contains("层 += int(player_stats.get(\"add_job_skill_level\", 0))"),
			"世界/职业两条加成各接一个统计（服务端 39/40）")
	_判(功.contains("条目[\"added_level\"] = _session.added_skill_level(技能id)")
			and 功.contains("_skill_with_icon(学过的[技能id]).duplicate(true)"),
			"`功能窗口._skills_for_tab` 挂 `added_level` 前先拷一份（防写脏存档）")
	_判(忍.contains("static func 层数文字(忍术: Dictionary) -> String:")
			and 忍.contains("等级标签.text = 层数文字(忍术)"),
			"忍术格子的层数文字走 `层数文字`")
	_判(忍.contains("_设标签(窗口, 详情, \"层数\", str(等级), 忍术等级字号, 色_标签)"),
			"详情区的「层数」仍只印基础层（`SkillDetailPane.as:160` 不跟加成）")
	_判(服.contains("SKILL_CHANGE_TMP = 1813"),
			"服务端 opcode 常量还是 1813")
	_判(服.contains("struct.pack(\"<ii\", skill_id, bonus)"),
			"服务端每行只发两段 `<ii 忍术号, 加成层>`（第三段会把后面的号全串位）")
	_判(后.contains("OP_SKILL_CHANGE_TMP:\n\t\t\t_handle_skill_change_tmp_text(fields)"),
			"`_handle_bridge_text` 把 1813 文本帧交给文本解码器（本客户端恒走 AMF3）")
	_判(后.contains("func _handle_skill_change_tmp_text(fields: PackedStringArray) -> void:")
			and 后.contains("func _apply_skill_added_levels(表: Dictionary) -> void:")
			and 后.contains("_apply_skill_added_levels(表)"),
			"文本解码与二进制解码共用同一落表函数（整表替换 + 转会话）")
	_判(服.contains("f\"{op(ServerOpcode.SKILL_CHANGE_TMP)}:{len(rows)}\""),
			"服务端非原始模式下改用文本帧发 1813（修前直接 return ⇒ 实机永远收不到）")
	_判(服.contains("self._send_all_stats()\n        self._refresh_skill_gem_levels()"),
			"AMF3 进图 `enter_game` 也发一次加成表（修前只有 `enter_original_game` 发）")
	_判(服.contains("if self.wire_mode != \"original\":")
			and 服.contains("self.send_original_packet(ServerOpcode.SKILL_CHANGE_TMP, bytes(body))"),
			"服务端原始二进制模式仍照旧发 1813 二进制帧")


func _initialize() -> void:
	call_deferred("_开跑")


## ⚠ 自动加载的 `_ready()` 跑在 `_initialize()` **之后**（直接读 `player_stats` 拿到的是还没装好的白板值），
## 所以先隔几帧再快照。
func _开跑() -> void:
	for _i in 6:
		await process_frame
	存前 = _字节(存档)
	设前 = _字节(设置档)
	会 = root.get_node_or_null("GameSession")
	if 会 == null:
		_判(false, "拿不到 GameSession 单例")
		quit(1)
		return
	备层 = 会.skill_added_levels.duplicate(true)
	备技能 = 会.learned_skills.duplicate(true)
	for 键 in ["add_world_skill_level", "add_job_skill_level", "job"]:
		备有[键] = 会.player_stats.has(键)
		备统计[键] = 会.player_stats.get(键, 0)
	假 = 测试后端.new()
	root.add_child(假)
	假.set("in_game", true)
	假.skill_added_levels_received.connect(func(层: Dictionary) -> void: 收到.append(层))
	_帧腿()
	_文本腿()
	_会话腿()
	_显示腿()
	_功能窗腿()
	_接线腿()
	假.queue_free()
	_尾()
