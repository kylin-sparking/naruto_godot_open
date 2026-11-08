extends SceneTree
## 宠物面板回归 —— 钉主窗那四颗钮的「实装」与「逻辑」，外加六根条的条内几何与字号地板。
##
## 覆盖（行为对着 `真值/窗口/宠物.md` §8 的行为契约，外观对着 §1/§10 的逐件真值）：
##   ① 三态钮矩阵 `updatePetStatus:329-358`（#2）：NORMAL / SUMMON / ATTACK 三行 × 文案+禁用；
##   ② 附身/出战的**跨态拦截**（#3 #4）：出战中点附身、附身中点出战 ⇒ 只提示、不发包、不改本地态；
##   ③ `isLevelEnough` 两道闸（#5）：玩家级 < 宠级、玩家级 < carryLevel，提示文案逐字；
##   ④ `isDelay` 1000ms（#8）：同一动作连按两次，第二次被吞；
##   ⑤ 放生确认框正文 = `PROMPT_2`（#6）；
##   ⑥ 服务端拒绝（action 9）⇒ 提示（#14，原来这条信号全工程零消费者）；
##   ⑦ 悬停黄框（#15A）：空行也必须可悬停（`disabled=true` 的 Control 不吃鼠标）；
##   ⑧ 「通灵驯养」副窗随页开：本门只验「没有窗口管理时不崩」，贴位在在线/实机门看；
##   ⑨ 字号地板（2026-10-18 巡检 #28）：宠物这一族七个场景里**任何** `theme_override_font_sizes/*`
##      都不许低于 `皮肤表.默认字号` —— `界面主题回归测试` 那一层只管人物扩展页，这边原先没人管；
##   ⑩ 六根条的条内件（真值 §10）：`底/裁剪/裁剪内填充/值` 五件几何 + 「进度是滑不是压扁」。
##
## ⚠️ 会话层的 `set_pet_deployed/attached` 是**乐观**写法（先改本地再发包），所以「跨态拦截
##    有没有生效」可以用**本地态有没有被翻**来判：拦不住时 GameSession.pets 当场就变了。

const 宠物窗口 := preload("res://脚本/界面/窗口/宠物窗口.gd")
const 功能窗口脚本 := preload("res://脚本/界面/功能窗口.gd")
const 条目场景 := preload("res://场景/界面/组件/宠物条目.tscn")
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 驯养窗 := preload("res://脚本/界面/窗口/通灵驯养窗口.gd")
const 宠物数值 := preload("res://脚本/角色/宠物数值.gd")


## 迷你窗口管理：只实现 `取或建窗口 / 取窗口 / 打开`，够 `_打开驯养窗` 走完整条路。
## 用真的 `功能窗口.tscn` + `设为单页`，所以页面会被真的 instantiate —— 目的是钉 #3.2：
## 首帧渲染时 `_驯养宠物id` **必须已经灌好**，否则 `通灵驯养窗口.gd:144` 会弹
## 「请先在通灵兽列表里选一只通灵兽」。
class 假管理 extends Node:
	const 功能窗口场景 := preload("res://场景/界面/功能窗口.tscn")
	var 窗表: Dictionary = {}
	var 打开次数: int = 0
	## 每扇窗各开了几次（进融魂页会自动开「尾兽预览」窗，总数不能拿来断言驯养窗）。
	var 打开表: Dictionary = {}

	func 取或建窗口(页名: String) -> Node:
		var 窗 := 窗表.get(页名) as Node
		if 窗 == null:
			窗 = 功能窗口场景.instantiate()
			add_child(窗)
			窗.call("设为单页", 页名, Vector2.ZERO)
			窗表[页名] = 窗
		return 窗

	func 取窗口(页名: String) -> Node:
		return 窗表.get(页名) as Node

	func 打开(页名: String) -> void:
		var 窗 := 取或建窗口(页名)
		打开次数 += 1
		打开表[页名] = int(打开表.get(页名, 0)) + 1
		窗.call("打开")

## ⚠️⚠️ 本门会真点放生/附身/出战 ⇒ 会话层每步都 `_save_local_state()` **落盘 user://**。
## 所以按工程口径：**动手前整份按字节快照、收尾按字节还原、再断言还原后与快照逐字节一致**
## （模板 = `测试/那一排按钮回归测试.gd:481-498`）。
## 上一版没有这一段，跑一次就把**三只假宠 + level=1** 写进了真实玩档，隔天三条邻居门全红
## （`功能入口` 的「宠物页缺按钮：附身」= 假宠 attached ⇒ 文案变「回收」；`阿凯洗点徽章页` 的
##  等级断言全崩；`点角色不崩` 被另一条静态规则带红）。别省这一段。
const 存档 := "user://玩家数据.json"

var _fails: Array[String] = []
var _提示: Array[String] = []
var _存前: PackedByteArray = PackedByteArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var 会话 := get_root().get_node_or_null("GameSession")
	if 会话 == null:
		push_error("宠物面板回归测试：拿不到 GameSession autoload")
		quit(1)
		return

	_存前 = _字节()
	_验纯函数()
	_验字号地板()
	_验悬停与空行()
	_验宠物位置互不干扰()
	await _验等级上限收口(会话)
	await _验面板(会话)
	_还原存档()

	if _fails.is_empty():
		print("宠物面板回归测试：通过（三态矩阵/跨态拦/等级双闸/节流/放生文案/action9/空行悬停/副窗兜底/提升页/位置隔离/字号地板/六根条条内件/材料格/首帧提示/预览贴右缘与图标标签扫描/宠物等级上限与满级清经验/存档还原）")
		quit(0)
	else:
		for f in _fails:
			push_error("宠物面板回归测试：失败 - %s" % f)
		quit(1)


func _字节() -> PackedByteArray:
	if not FileAccess.file_exists(存档):
		return PackedByteArray()
	var f := FileAccess.open(存档, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	return f.get_buffer(f.get_length())


## 收尾按字节还原存档（本门点过放生/附身/出战，会话层必然落盘）
func _还原存档() -> void:
	var 现 := _字节()
	if 现 == _存前:
		return
	if _存前.is_empty():
		if FileAccess.file_exists(存档):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(存档))
		_查(not FileAccess.file_exists(存档), "动手前没有存档 ⇒ 收尾应把本门造的那份删掉")
		return
	var w := FileAccess.open(存档, FileAccess.WRITE)
	if w != null:
		w.store_buffer(_存前)
		w.close()
	_查(_字节() == _存前, "存档按字节还原（本门点了放生/附身，会话层会落盘）")


## —— ① ② ③ 的纯函数部分（不碰场景树）
func _验纯函数() -> void:
	# ① 三态矩阵：三种状态逐字段比，别只比文案
	var 常态 := 宠物窗口.按钮状态(false, false)
	_查(String(常态["附身文本"]) == "附身" and String(常态["出战文本"]) == "出战", "NORMAL 文案 %s" % [常态])
	_查(not bool(常态["附身禁用"]) and not bool(常态["出战禁用"]) and not bool(常态["放生禁用"]),
		"NORMAL 三颗都应 enabled：%s" % [常态])
	var 附身态 := 宠物窗口.按钮状态(true, false)
	_查(String(附身态["附身文本"]) == "回收", "SUMMON 附身文案 %s" % 附身态["附身文本"])
	_查(String(附身态["出战文本"]) == "出战" and bool(附身态["出战禁用"]),
		"SUMMON 出战文案仍是「出战」但必须禁用：%s" % [附身态])
	_查(not bool(附身态["附身禁用"]), "SUMMON 附身应 enabled（点它就是回收）")
	_查(bool(附身态["放生禁用"]), "SUMMON 放生必须禁用")
	var 出战态 := 宠物窗口.按钮状态(false, true)
	_查(String(出战态["附身文本"]) == "附身" and bool(出战态["附身禁用"]),
		"ATTACK 附身文案仍是「附身」但必须禁用：%s" % [出战态])
	_查(String(出战态["出战文本"]) == "回收" and not bool(出战态["出战禁用"]), "ATTACK 出战 = 回收 且 enabled")
	_查(bool(出战态["放生禁用"]), "ATTACK 放生必须禁用")

	# ③ 等级双闸：文案 `PETDATAMANAGER_NEED_LEVEL_PROMPT` = 「需要%1级才能%2这只通灵兽！」
	_查(功能窗口脚本.等级不足提示(10, 11, 1, "出战") == "需要11级才能出战这只通灵兽！",
		"第一道闸（玩家级 < 宠级）文案 %s" % 功能窗口脚本.等级不足提示(10, 11, 1, "出战"))
	_查(功能窗口脚本.等级不足提示(30, 20, 31, "携带") == "需要31级才能携带这只通灵兽！",
		"第二道闸（玩家级 < carryLevel）文案 %s" % 功能窗口脚本.等级不足提示(30, 20, 31, "携带"))
	_查(功能窗口脚本.等级不足提示(40, 20, 10, "出战") == "", "两道闸都过应放行")
	# 宠物级 ≥ carryLevel 时先报宠物级（原版先判第一道）
	_查(功能窗口脚本.等级不足提示(5, 12, 30, "携带") == "需要12级才能携带这只通灵兽！",
		"两道闸同时不过时应先报宠级")

	# ②' 品级态两道闸（`PetStrongTab.setType:440-470`）：命中时**只发提示、不切页**。
	#     满资质 = `PetDataManage.MAX_PET_APPITUDE`(4)；模板 `info.aptitude.enable` 是另一道。
	#     `00000101` 的 enable=0 ⇒ 未满足资质时也应报 PRPMPT_1（数据文件，不看玩档）
	_查(驯养窗.品级闸({"aptitude": 4, "item_id": 101}) == "你的通灵兽已经是最高品级！",
		"资质 4 应报 STRONG_PRPMPT_2，实得 %s" % 驯养窗.品级闸({"aptitude": 4, "item_id": 101}))
	_查(驯养窗.品级闸({"aptitude": 5, "item_id": 401}) == "你的通灵兽已经是最高品级！", "尾兽（资质 5）同样算已满")
	_查(驯养窗.品级闸({"aptitude": 1, "item_id": 101}) == "很抱歉，你的通灵兽小于4阶，不能够提高品级！",
		"模板 enable=0 应报 STRONG_PRPMPT_1，实得 %s" % 驯养窗.品级闸({"aptitude": 1, "item_id": 101}))

	# ②'' 提升页中框第二行要用**总潜力**算出的加成（`PetAddValue.maxAttack` 等）：
	#      同公式、只把 potential_real_* 换成 potential_total_* ⇒ 总潜力更大时满值必须更大。
	#      上一版根本没这项，中框那行直接抄了实值 ⇒ 两行一模一样。
	var 验宠 := {"level": 20, "savvy": 300, "item_id": 101, "aptitude": 1, "experience": 0,
		"potential_real_atk": 100, "potential_total_atk": 900,
		"potential_real_def": 100, "potential_total_def": 900,
		"potential_real_dex": 100, "potential_total_dex": 900,
		"potential_real_str": 100, "potential_total_str": 900, "skills": []}
	var 实值: Array = (宠物数值.计算(验宠).get("属性行", []) as Array)
	var 满值: Array = 宠物数值.满值六项(验宠)
	_查(满值.size() == 6, "满值六项应回 6 项（原版只有 hp/mp/atk/def/baoji/duck 有 max 档），实得 %d" % 满值.size())
	_查(int(满值[2]) > int((实值[2] as Dictionary)["值"]),
		"攻击满值(%s)应大于实值(%s)" % [满值[2], (实值[2] as Dictionary)["值"]])
	_查(int(满值[0]) > int((实值[0] as Dictionary)["值"]),
		"生命满值(%s)应大于实值(%s)" % [满值[0], (实值[0] as Dictionary)["值"]])
	_查(String(驯养窗._潜力中框(验宠, 0)).contains("当前为你加成攻击力")
			and String(驯养窗._潜力中框(验宠, 3)).contains("生命值 ："),
		"潜力态中框文案分攻/健两套模板（DESC_5 / DESC_3）")
	_查(String(驯养窗._潜力中框(验宠, 3)).contains("提升至最大后将获得"), "健体态中框表头是 DESC_3 那行橙字")

	# ②''' 品级态中框那张四行表（`getStrongAptPrm:678-687`）：原版拼的是 Flash HTML，
	#      消费点是 `bbcode_enabled` 的 `RichTextLabel` ⇒ 原样吐 `<font>` 会把标签显示给玩家。
	var 信息101: Dictionary = (驯养窗.数据.pet_template(101).get("info", {}) as Dictionary)
	var 中框 := String(驯养窗.中框表(验宠, 信息101, 1))
	_查(中框.contains("攻击潜力") and 中框.begins_with("[color=") and not 中框.contains("<"),
		"品级态中框表必须是 BBCode（不能有裸 HTML 标签），实得 %s" % 中框)
	_查(中框.count("攻击潜力") == 2 and 中框.count("\n") == 4,
		"品级态中框应是四行「左实值 + 右 apt(资质+1) 区间」，实得 %d 行" % 中框.count("\n"))
	_查(String(驯养窗.中框表(验宠, 信息101, 4)) == "",
		"资质 = PetAptitude.PREEMINENCE(4) 时原版返回空串")


## 字号地板：`simsun_原版.ttf` 的内嵌点阵只在 **12** 命中，8~11 走轮廓抗锯齿 ⇒ 又小又暗又糊
## （2026-10-17 用户给并排图报的那一条，同一口径已钉在 `界面主题回归测试._查扩展页字号`，
## 但那一层**只管人物扩展页**；宠物这一族六个场景 + 条目没人管，巡检 #28 就在
## `宠物窗口.tscn` 里抓到 7 处烘成 9 号）。地板值不写死，读 `皮肤表.默认字号`。
func _验字号地板() -> void:
	var 门 := int(皮肤表.默认字号)
	var 违规: Array[String] = []
	var 扫到 := 0
	for 名 in ["窗口/宠物/宠物窗口", "窗口/宠物/宠物进阶页", "窗口/宠物/宠物提升页",
			"窗口/宠物/宠物融魂页", "窗口/宠物/通灵驯养窗口", "窗口/宠物/尾兽预览窗口",
			"组件/宠物条目"]:
		var 路径 := "res://场景/界面/%s.tscn" % 名
		var 文 := FileAccess.get_file_as_string(路径)
		_查(not 文.is_empty(), "%s 读不出来（改名或挪目录了？）" % 路径)
		for 行 in 文.split("\n"):
			行 = 行.strip_edges()
			if not 行.begins_with("theme_override_font_sizes/"):
				continue
			var 划 := 行.find("= ")
			if 划 < 0:
				continue
			扫到 += 1
			if int(行.substr(划 + 2)) < 门:
				违规.append("%s ← %s" % [名, 行])
	# ⚠️ 「扫到 0 处」= 这条腿根本没东西可判（前缀换了 / 场景改名），跟“全绿”不是一回事。
	_查(扫到 > 0, "字号地板扫到 0 处字号覆盖 ⇒ 判据空转")
	_查(违规.is_empty(), "宠物这一族 %d 处字号小于 %d（宋体点阵只在 %d 命中 ⇒ 糊）：%s"
		% [违规.size(), 门, 门, " ／ ".join(违规)])


## ⑦ 悬停：真值 §15A 要求「移出时只有未选中的行收起」，以及空行不能被 disabled 吃掉鼠标。
func _验悬停与空行() -> void:
	var 条目 := 条目场景.instantiate() as Button
	get_root().add_child(条目)
	var 选中条 := 条目.get_node("选中条") as Control
	宠物窗口._接悬停(条目, false)
	_查(not 选中条.visible, "未选中行初始不该亮")
	条目.mouse_entered.emit()
	_查(选中条.visible, "悬停必须点亮黄框（未选中行）")
	条目.mouse_exited.emit()
	_查(not 选中条.visible, "未选中行移出应收起黄框")
	宠物窗口._接悬停(条目, true)
	_查(选中条.visible, "选中行初始就该亮")
	条目.mouse_entered.emit()
	条目.mouse_exited.emit()
	_查(选中条.visible, "选中的行移出后黄框必须留着（原版 outHandler 只收未选中的）")
	# 空行：不能 disabled（禁用 Control 不派发 mouse_entered/mouse_exited）
	宠物窗口._填占位行(条目, "空闲兽栏", Color.WHITE)
	_查(not 条目.disabled, "空闲兽栏行不能置 disabled —— 否则悬停永远不亮")
	_查((条目.get_node("名字") as Label).text == "空闲兽栏", "占位行文案")
	# 名字/等级必须是「MGlowLabel 等价」：12px 汉字在原版带黑 GlowFilter（blur3 strength6 alpha1），
	# Godot 没有辉光，用 2px 不透明黑描边近似 —— 不加描边时 1:1 截图里字边是一圈灰（用户 #3.1 报「模糊」）。
	for 标名 in ["名字", "等级"]:
		var 标 := 条目.get_node_or_null(标名) as Label
		_查(标 != null and int(标.get_theme_constant("outline_size")) == 2
				and 标.get_theme_color("font_outline_color").is_equal_approx(Color(0, 0, 0, 1)),
			"⑬ 宠物行「%s」应有 2px 不透明黑描边（MGlowLabel 的 Godot 近似）" % 标名)
	条目.queue_free()


## —— ⑪ 宠物等级不得超过人物等级 / 满级不再获取经验（2026-10-29 用户规则，§3.314）——
## 规则本体在 `宠物数值.等级上限/收口等级`（服务端 `_pet_level_cap` 同式）；
## 这里钉三样：纯规则、会话迁移那条路真会收口、面板显示的是收口后的值。
## ⚠️ 期望值全写死（50/120/0），不从被测函数反推。
func _验等级上限收口(会话) -> void:
	_查(宠物数值.等级上限(1) == 1, "人物 1 级 ⇒ 宠物上限 1（实得 %d）" % 宠物数值.等级上限(1))
	_查(宠物数值.等级上限(50) == 50, "人物 50 级 ⇒ 宠物上限 50（实得 %d）" % 宠物数值.等级上限(50))
	_查(宠物数值.等级上限(120) == 120, "人物 120 级 ⇒ 宠物上限 120（实得 %d）" % 宠物数值.等级上限(120))
	_查(宠物数值.等级上限(200) == 120, "人物超 120 级也把宠物封在 120（实得 %d）" % 宠物数值.等级上限(200))
	_查(宠物数值.等级上限(0) == 1, "人物等级 0 这种脏档兜到 1（实得 %d）" % 宠物数值.等级上限(0))

	var 超 := {"level": 120, "experience": 38381}
	_查(宠物数值.收口等级(超, 50) and int(超["level"]) == 50 and int(超["experience"]) == 0,
		"120 级宠物在 50 级人物下应压到 50 且经验清零：%s" % [超])
	var 低 := {"level": 10, "experience": 999}
	_查(not 宠物数值.收口等级(低, 50) and int(低["level"]) == 10 and int(低["experience"]) == 999,
		"低于上限的宠物不许被抬/被动：%s" % [低])
	var 满 := {"level": 50, "experience": 400}
	_查(宠物数值.收口等级(满, 50) and int(满["experience"]) == 0,
		"正好在上限的宠物要把经验清零（满级不再获取经验）：%s" % [满])

	var 原宠: Array[Dictionary] = 会话.pets.duplicate(true)
	var 原属性: Dictionary = (会话.player_stats as Dictionary).duplicate(true)
	var 假宠: Array[Dictionary] = [{
		"id": "1", "unique_id": 1, "item_id": 101, "name": "老档宠", "level": 120,
		"aptitude": 1, "savvy": 10, "experience": 38381, "face": 0,
		"potential_real_atk": 100, "potential_real_def": 100,
		"potential_real_dex": 100, "potential_real_str": 100,
		"potential_total_atk": 120, "potential_total_def": 120,
		"potential_total_dex": 120, "potential_total_str": 120,
		"equipment": [], "skills": [{"id": 125, "level": 1}],
		"attached": false, "deployed": false,
	}]
	会话.pets = 假宠
	会话.player_stats["level"] = 50
	会话.call("_migrate_pet_state")
	_查(会话.pets.size() == 1 and int(会话.pets[0].get("level", 0)) == 50
			and int(会话.pets[0].get("experience", -1)) == 0,
		"会话迁移没把本地存档里的 120 级宠物收口到人物 50 级：%s" % [会话.pets])

	# 面板显示的是收口后的等级；经验条从 0 起算（满级清过的经验不许还挂在条上）。
	var 窗口 := (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	get_root().add_child(窗口)
	await process_frame
	窗口._selected_pet_id = "1"
	窗口.open_page("宠物")
	await process_frame
	await process_frame
	var 页 := 窗口._content.get_node_or_null("原版宠物窗口内容") as Control
	var 等级标: Label = (页.get_node_or_null("等级") as Label) if 页 != null else null
	var 值标: Label = (页.get_node_or_null("经验条/值") as Label) if 页 != null else null
	_查(等级标 != null and 等级标.text == "50",
		"面板「等级」应显示收口后的 50（实得 %s）" % (等级标.text if 等级标 != null else "缺节点"))
	_查(值标 != null and 值标.text.begins_with("0/"),
		"满级清过经验后经验条应从 0 起算（实得 %s）" % (值标.text if 值标 != null else "缺节点"))
	窗口.queue_free()
	会话.pets = 原宠
	会话.player_stats = 原属性


## 附身/出战两态并存：服务端允许"一只附身 + 一只出战"，客户端落位置时**不许**把别的宠物刷掉。
func _验宠物位置互不干扰() -> void:
	var 后端 := get_root().get_node_or_null("BackendConnection")
	if 后端 == null:
		return
	var 备份: Array[Dictionary] = 后端.get("authoritative_pets").duplicate(true)
	var 假: Array[Dictionary] = [
		{"unique_id": 910001.0, "id": "00000110", "attached": false, "deployed": true},
		{"unique_id": 910002.0, "id": "00000210", "attached": true, "deployed": false},
	]
	后端.get("authoritative_pets").assign(假)
	后端.call("_set_pet_position", 910002, 0)
	var 表: Array = 后端.get("authoritative_pets")
	_查(bool(表[0].get("deployed", false)) and not bool(表[0].get("attached", false)),
		"给第二只落位置时不许把第一只的出战态刷掉")
	_查(bool(表[1].get("attached", false)) and not bool(表[1].get("deployed", false)), "第二只自己落对了")
	后端.get("authoritative_pets").assign(备份)


## —— ② ④ ⑤ ⑥ ⑧ 场景级：把真面板渲染出来，再按行为去戳
func _验面板(会话) -> void:
	var 窗口 := (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	get_root().add_child(窗口)
	await process_frame

	var 原宠: Array[Dictionary] = 会话.pets.duplicate(true)
	var 原容量 := int(会话.pet_capacity)
	var 原属性: Dictionary = (会话.player_stats as Dictionary).duplicate(true)
	var 假宠: Array[Dictionary] = [
		{"id": "1", "unique_id": 1, "item_id": 101, "name": "小忍犬", "level": 12,
			"aptitude": 1, "savvy": 10, "experience": 0, "face": 0,
			"potential_real_atk": 100, "potential_real_def": 100,
			"potential_real_dex": 100, "potential_real_str": 100,
			"potential_total_atk": 120, "potential_total_def": 120,
			"potential_total_dex": 120, "potential_total_str": 120,
			"equipment": [], "skills": [], "attached": false, "deployed": false},
		{"id": "2", "unique_id": 2, "item_id": 101, "name": "附身中", "level": 12,
			"aptitude": 1, "savvy": 10, "experience": 0, "face": 0,
			"equipment": [], "skills": [], "attached": true, "deployed": false},
		{"id": "3", "unique_id": 3, "item_id": 101, "name": "出战中", "level": 12,
			"aptitude": 1, "savvy": 10, "experience": 0, "face": 0,
			"equipment": [], "skills": [], "attached": false, "deployed": true},
	]
	会话.pets = 假宠
	# ⚠️ `pets` 是 `Array[Dictionary]`：塞普通 Array 会报「Invalid assignment」但**不中断**，
	#    后面的断言就全打在空列表上、白绿。这条断言就是给它上闸。
	_查(会话.pets.size() == 3, "夹具没塞进会话：pets.size()=%d（类型不匹配？）" % 会话.pets.size())
	会话.pet_capacity = 10
	会话.player_stats = 原属性.duplicate(true)
	会话.player_stats["level"] = 1
	_提示.clear()
	会话.notification_requested.connect(func(文: String) -> void: _提示.append(文))

	窗口._selected_pet_id = "1"
	窗口.open_page("宠物")
	await process_frame
	await process_frame

	# ①' 面板上的三态（渲染结果，不是纯函数）
	#    ⚠️ 页面是 `宠物场景.instantiate()` 塞进 `_content` 的：路径前缀不是 `_content/`，
	#    所以按名字递归找，别写死路径（换壳/改名就静默变 null）。
	var 附身 := _找按钮(窗口._content, "附身")
	var 出战 := _找按钮(窗口._content, "出战")
	var 放生 := _找按钮(窗口._content, "放生")
	if 附身 == null or 出战 == null or 放生 == null:
		_fails.append("面板上找不到 附身/出战/放生 三颗钮")
		_收尾(窗口, 会话, 原宠, 原容量, 原属性)
		return
	_查(String(附身.text) == "附身" and not 附身.disabled and not 出战.disabled and not 放生.disabled,
		"NORMAL 渲染态：附身=%s/%s 出战=%s/%s 放生=%s" % [附身.text, 附身.disabled, 出战.text, 出战.disabled, 放生.disabled])

	# —— 六根条的条内件（真值 §10）。上一轮这条只给了进阶页那根祝福条（本文件「驯养三页」那段），
	#    主窗这六根**还留在旧错上**：底用的是整元件 tag167（167×16，含左边 45px 的 label 列和
	#    烘死的 "label"/"0/0" 占位字），于是轨道整体往左压 45px、占位字压在真字底下；
	#    进度靠**改 offset_right 压扁贴图**（`MBar.as:149` 是整条左滑 + mask 不动）；
	#    「值」烘成 9 号（`TextTip`/`getLabel2` 都落到 `MLabel` 默认 12，宋体点阵只在 12 命中）。
	#    ⇒ 逐根钉五件：轨道宽高、mask 几何 + 真裁剪、填充原生宽、值字号/居中、滑动位。
	var 条宽 := {"梦幻条": 114.0}
	for 条名 in ["梦幻条", "经验条"] + 宠物窗口.槽位高亮:
		var 条 := _找节点(窗口._content, 条名) as Control
		if 条 == null:
			_fails.append("%s 不在面板上" % 条名)
			continue
		var W: float = float(条宽.get(条名, 168.0))
		var 底 := 条.get_node_or_null("底") as TextureRect
		var 裁 := 条.get_node_or_null("裁剪") as Control
		var 填 := 条.get_node_or_null("裁剪/填充") as TextureRect
		var 值 := 条.get_node_or_null("值") as Label
		_查(底 != null and 裁 != null and 填 != null and 值 != null,
			"%s 必须是 底/裁剪/裁剪内填充/值 四件（真值 §10 的 barBg/maskMc/bar/tf）" % 条名)
		if 底 == null or 裁 == null or 填 == null or 值 == null:
			continue
		_查(is_equal_approx(条.size.x, W) and is_equal_approx(条.size.y, 11.0),
			"%s 轨道应是 %.0f×11（`PetWindow.as:826`/`:932` 的 width、tag158 原生高 11），实得 %s" % [条名, W, 条.size])
		_查(底.texture != null and is_equal_approx(底.size.x, W),
			"%s 的底必须是**轨道件**（tag158 经验条槽.png，宽 = 轨道宽），实得 %s" % [条名, 底.size])
		_查(is_equal_approx(裁.offset_left, 3.0) and is_equal_approx(裁.offset_top, 3.0)
				and is_equal_approx(裁.size.x, W - 6.0) and is_equal_approx(裁.size.y, 5.0)
				and 裁.clip_contents,
			"%s 的 mask 应是 (3,3) %.0f×5 且真裁剪（tag161 比条芯左右各缩 3px、只 5px 高），实得 %s@%s clip=%s"
				% [条名, W - 6.0, 裁.size, 裁.position, 裁.clip_contents])
		_查(is_equal_approx(填.size.x, W) and 填.texture != null,
			"%s 的填充必须保持**原生宽 %.0f**（进度靠滑不靠压扁），实得 %s" % [条名, W, 填.size])
		_查(值.get_theme_font_size("font_size") == 12
				and 值.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
			"%s 的「值」要 12 号居中（MBar.tf / getLabel2 都是 MLabel 默认 12；9 号打不中宋体点阵 ⇒ 糊），实得 %d"
				% [条名, 值.get_theme_font_size("font_size")])
	# 滑动位抽查：42/100 ⇒ `−3 − int(W·(1−r))`（W=168 那一档由下面「驯养三页」里的祝福条同式钉住）
	宠物窗口._设条(_找节点(窗口._content, "梦幻条").get_parent(), "梦幻条", 42, 100)
	await create_timer(0.7).timeout
	var 梦幻填 := (_找节点(窗口._content, "梦幻条") as Control).get_node("裁剪/填充") as TextureRect
	# 114 × 0.58 = 66.12 ⇒ −3 − 66 = −69（168 那五根同理会到 −100）
	_查(is_equal_approx(梦幻填.position.x, -69.0),
		"梦幻条 42/100 应滑到 −69（= −3 − int(114×0.58)，压扁版会停在别的值上），实得 %.1f" % 梦幻填.position.x)
	_查(String(((_找节点(窗口._content, "梦幻条") as Control).get_node("值") as Label).text) == "42/100",
		"梦幻条「值」必须跟着显 42/100")
	# 满条 ⇒ 条芯右沿对齐 mask 右沿、左沿回到静止位
	for 条名 in ["梦幻条", "经验条"] + 宠物窗口.槽位高亮:
		宠物窗口._设条(_找节点(窗口._content, 条名).get_parent(), 条名, 100, 100)
	await create_timer(0.7).timeout
	for 条名 in ["梦幻条", "经验条"] + 宠物窗口.槽位高亮:
		var 条 := _找节点(窗口._content, 条名) as Control
		var 填 := 条.get_node_or_null("裁剪/填充") as TextureRect
		if 填 == null:
			continue
		_查(is_equal_approx(填.position.x, -3.0),
			"%s 满条时填充应停在静止位 −3（`MBar.as:149` 的 barBg.x + (W−W)/2），实得 %.1f" % [条名, 填.position.x])

	窗口._select_pet("2")			# 附身中
	await process_frame
	附身 = _找按钮(窗口._content, "附身")
	出战 = _找按钮(窗口._content, "出战")
	放生 = _找按钮(窗口._content, "放生")
	_查(String(附身.text) == "回收" and not 附身.disabled, "SUMMON 渲染态附身：%s/%s" % [附身.text, 附身.disabled])
	_查(出战.disabled and String(出战.text) == "出战", "SUMMON 渲染态出战必须灰：%s/%s" % [出战.text, 出战.disabled])
	_查(放生.disabled, "SUMMON 渲染态放生必须灰")

	窗口._select_pet("3")			# 出战中
	await process_frame
	附身 = _找按钮(窗口._content, "附身")
	出战 = _找按钮(窗口._content, "出战")
	放生 = _找按钮(窗口._content, "放生")
	_查(附身.disabled and String(附身.text) == "附身", "ATTACK 渲染态附身必须灰：%s/%s" % [附身.text, 附身.disabled])
	_查(String(出战.text) == "回收" and not 出战.disabled, "ATTACK 渲染态出战 = 回收 且可点")
	_查(放生.disabled, "ATTACK 渲染态放生必须灰")

	# ⑦' 列表空行的悬停（真面板上取「空闲兽栏」那一行）
	var 列表 := _找节点(窗口._content, "宠物列表")
	_查(列表 != null, "列表容器「宠物列表」找不到")
	var 空行: Button = null
	if 列表 != null:
		for 行 in 列表.get_children():
			if 行 is Button and (行 as Button).is_visible_in_tree():
				var 名字 := 行.get_node_or_null("名字") as Label
				if 名字 != null and 名字.text == "空闲兽栏":
					空行 = 行 as Button
					break
	_查(空行 != null, "列表里找不到「空闲兽栏」行")
	if 空行 != null:
		_查(not 空行.disabled, "真面板上的空闲兽栏行被置了 disabled")
		(空行.get_node("选中条") as Control).visible = false
		空行.mouse_entered.emit()
		_查((空行.get_node("选中条") as Control).visible, "真面板上的空闲兽栏行悬停不亮")

	# ② 跨态拦截：出战中点附身 ⇒ 只提示、不发包、不改本地态
	_提示.clear()
	窗口._宠物动作时刻 = {}
	窗口._attach_pet("3")
	var 三 := _宠(会话, "3")
	_查(_提示.has("该通灵兽已经出战！"), "出战中点附身应提示「该通灵兽已经出战！」，实得 %s" % [_提示])
	_查(not bool(三.get("attached", false)) and bool(三.get("deployed", false)),
		"出战中点附身不许改本地态：%s" % [三])
	# 附身中点出战 ⇒ 同理
	_提示.clear()
	窗口._宠物动作时刻 = {}
	窗口._toggle_pet("2", true)
	var 二 := _宠(会话, "2")
	_查(_提示.has("该通灵兽已经附身！"), "附身中点出战应提示「该通灵兽已经附身！」，实得 %s" % [_提示])
	_查(not bool(二.get("deployed", false)) and bool(二.get("attached", false)),
		"附身中点出战不许改本地态：%s" % [二])

	# ③ 等级闸：玩家 1 级 vs 宠 12 级 ⇒ 提示 + 本地态不动
	_提示.clear()
	窗口._宠物动作时刻 = {}
	窗口._toggle_pet("1", true)
	_查(_提示.has("需要12级才能出战这只通灵兽！"), "等级闸提示 %s" % [_提示])
	_查(not bool(_宠(会话, "1").get("deployed", false)), "等级不够不该把本地 deployed 翻成 true")
	_提示.clear()
	窗口._宠物动作时刻 = {}
	窗口._attach_pet("1")
	_查(_提示.has("需要12级才能携带这只通灵兽！"), "附身口径的等级提示 %s" % [_提示])
	_查(not bool(_宠(会话, "1").get("attached", false)), "等级不够不该把本地 attached 翻成 true")

	# ④ 节流：1000ms 内第二次必须被吞
	窗口._宠物动作时刻 = {}
	_查(窗口._宠物按钮节流("出战"), "第一次动作应放行")
	_查(not 窗口._宠物按钮节流("出战"), "1000ms 内第二次动作必须被吞（isDelay）")
	_查(窗口._宠物按钮节流("附身"), "节流按动作键分开，附身不该被出战那次吞掉")

	# ⑤ 放生走原版 `MDialog.showMessageDialog`（`输入确认弹.弹消息` ⇒ 节点名「消息确认框」），
	#    正文 = `PROMPT_2`；旧版是自造的 300×130「确认框」（正文「确定要放生 X 吗？此操作无法撤销。」+标题「放生通灵兽」）。
	窗口._宠物动作时刻 = {}
	var 放前: int = 会话.pets.size()
	窗口._release_pet("1")
	await process_frame
	var 遮: Node = 窗口._overlay.get_node_or_null("消息确认框")
	_查(遮 != null, "放生没弹出消息确认框（应走 输入确认弹.弹消息）")
	var 正文 := _找节点(遮, "正文")
	_查(正文 != null and String(正文.get("text")) == "你确定要放生该通灵兽吗?",
		"放生确认框正文：%s" % (String(正文.get("text")) if 正文 != null else "<无>"))
	# 取消（CANCEL=2）⇒ 什么都不做；确定（OK=1）⇒ 才真的放生
	var 取消键 := _找按钮(遮, "取消")
	_查(取消键 != null, "放生确认框缺「取消」键")
	if 取消键 != null:
		取消键.pressed.emit()
		await process_frame
		_查(会话.pets.size() == 放前, "点「取消」不该放生：%d → %d" % [放前, 会话.pets.size()])
	窗口._宠物动作时刻 = {}
	窗口._release_pet("1")
	await process_frame
	遮 = 窗口._overlay.get_node_or_null("消息确认框")
	var 确定键 := _找按钮(遮, "确定")
	_查(确定键 != null, "放生确认框缺「确定」键")
	if 确定键 != null:
		确定键.pressed.emit()
		await process_frame
		_查(会话.pets.size() == 放前 - 1, "点「确定」应放生一只：%d → %d" % [放前, 会话.pets.size()])

	# ⑤' 改名走 302 版输入弹（`输入确认弹.弹出`）：预填当前名 + `maxChars=12` 落到 `max_length`
	窗口._rename_pet_request("小忍犬")
	await process_frame
	var 输入遮: Node = 窗口._overlay.get_node_or_null("输入确认框")
	_查(输入遮 != null, "改名没弹出输入确认框（应走 输入确认弹.弹出）")
	var 输入框 := _找节点(输入遮, "输入框") as LineEdit
	_查(输入框 != null and 输入框.text == "小忍犬", "改名输入框应预填当前名：%s" % (输入框.text if 输入框 != null else "<无>"))
	_查(输入框 != null and 输入框.max_length == 12, "改名 max_length 应为 12，实得 %s" % (输入框.max_length if 输入框 != null else "<无>"))
	if 输入遮 != null:
		输入遮.free()

	# ⑥ 服务端的**真拒绝**腿（§3.204 更正）。
	#    旧口径「宠物动作回帧 action 9 = 服务端拒绝 ⇒ addNotice(message)」是**读错的**：
	#    `PetProcessor.handlePetAction_chat:472-490` 那条 action 9 是**宠物喊话**
	#    （`charId/petUid/action/text` ⇒ `PetChatInfo`），交给 `channelListener.onPetChat`，
	#    而 `Client.as:1821-1823` 那份实现**是空的**、`ReceiveOpCodes.PET_CHAT`(:158) 也从没注册过
	#    监听 ⇒ 原版收到就丢。真拒绝走 `CHAT_MESSAGE` 的 `MessagePosition.CHAR_NOTICE(512)`
	#    （`MessagePosition.as:24`），原版 `UI.as:375-377` ⇒ `addNotice(text, COLOR_MID_PROM, true)`
	#    —— **只出黄字浮动提示、不进聊天记录**。夹具发的就是这一位（`_send_character_notice`）。
	var 后端 := get_root().get_node_or_null("BackendConnection")
	if 后端 == null:
		_查(false, "⑥ 前置：拿不到 BackendConnection autoload ⇒ 拒绝腿全是空转")
	else:
		_提示.clear()
		后端.call("_handle_chat_text", "1536:1:512:请放入通灵兽装备。:系统:0:0:-::0:0:0".split(":", true))
		_查(_提示.has("请放入通灵兽装备。"),
			"512 位必须把**服务端原句**逐字送进提示口子，实得 %s" % [_提示])
		# 喊话帧反过来：能解析，但一个字都不许提示（照原版的空实现）
		var 宠前: Array[Dictionary] = 会话.pets.duplicate(true)
		_提示.clear()
		后端.call("_handle_pet_action_text", "173:9:1234:9001:0:今天天气不错".split(":", true))
		_查(_提示.is_empty(), "宠物喊话（action 9）照原版**不消费**，实得 %s" % [_提示])
		# `_handle_pet_action_text` 收尾会 `_apply_pets_to_session()` ⇒ 会话那三只被权威表覆盖掉，
		# 这里就地还原，别把后面的腿打在空列表上（后面 ⑨ 虽然会重建，但不能靠它兜）。
		会话.pets = 宠前
		# 聊天记录那一半：512 只许留**通知落成的那一条**，出现两条就是没跳过、零条就是提示断了
		var 面板 := (load("res://场景/界面/聊天面板.tscn") as PackedScene).instantiate()
		get_root().add_child(面板)
		await process_frame
		var 记 := 面板.get("_chat_messages") as Array
		if 记 == null:
			_查(false, "⑥ 前置：聊天面板没有 `_chat_messages`，下面两条会空转")
		else:
			var 记前 := 记.size()
			后端.call("_handle_chat_text", "1536:1:512:宠物需要达到 3 级才能穿戴。:系统:0:0:-::0:0:0".split(":", true))
			await process_frame
			_查(记.size() - 记前 == 1,
				"512 拒绝在聊天里只该有 `通知` 落成的一条『系统』行，实得多出 %+d 条" % (记.size() - 记前))
			_查(记.size() > 记前 and String(记[-1].get("bbcode", "")).contains("宠物需要达到 3 级才能穿戴。"),
				"那一条的正文必须是服务端原句，实得 %s" % (str(记[-1]) if 记.size() > 记前 else "<无>"))
			# 对照：普通频道(8) 该进记录、**不**该走提示口子
			var 普前 := 记.size()
			_提示.clear()
			后端.call("_handle_chat_text", "1536:3:8:训练场见:小忍犬:12:1:-::0:0:0".split(":", true))
			await process_frame
			_查(记.size() - 普前 == 1, "普通聊天帧该进记录一条，实得多出 %+d 条" % (记.size() - 普前))
			_查(_提示.is_empty(), "普通聊天帧不该走提示口子，实得 %s" % [_提示])
		面板.free()

	# ⑨ 属性提升页（真值 §17）：没选属性时占位语在下拉里、`开始提升` disabled；
	#    选了潜力模式后 `幸运符数量` 数据必须是 1..9（上一版只到 5）
	# ⚠️ 必须重建夹具：`会话.pets = 假宠` 传的是**同一个数组实例**，⑤ 里放生会就地把它删成两只
	#    （第一版就是这么让 ⑨ 全红的）。所以走工厂函数拿一份新的。
	会话.pets = _造三只()
	窗口._驯养宠物id = "1"
	窗口._驯养页签 = 1
	窗口._驯养提升模式 = -1
	窗口.open_page("通灵驯养")
	await process_frame
	await process_frame
	var 待提升 := _找节点(窗口._content, "待提升") as Label
	_查(待提升 != null and 待提升.text == "请选择需要提升的属性",
		"提升页提示标签应为「请选择需要提升的属性」，实得 %s" % (待提升.text if 待提升 != null else "<无>"))
	var 模式下拉 := _找节点(窗口._content, "模式下拉") as OptionButton
	_查(模式下拉 != null and 模式下拉.selected == 0 and String(模式下拉.get_item_text(0)) == "点击右侧下拉按钮",
		"没选属性时下拉应停在占位项「点击右侧下拉按钮」")
	var 开始提升 := _找按钮(窗口._content, "提升按钮")
	_查(开始提升 != null and 开始提升.disabled, "没选属性时「开始提升」必须 disabled（真值 §17 type0）")
	窗口._驯养提升模式 = 2
	窗口._render_page()
	await process_frame
	await process_frame
	开始提升 = _找按钮(窗口._content, "提升按钮")
	_查(开始提升 != null and not 开始提升.disabled, "选了潜力模式后「开始提升」应可点")
	var 数量 := _找节点(窗口._content, "幸运符数量") as OptionButton
	_查(数量 != null and 数量.item_count == 9, "幸运符数量下拉应是 1..9（item_count=9），实得 %s" % (数量.item_count if 数量 != null else "<无>"))
	_查(数量 != null and 数量.item_count > 0 and String(数量.get_item_text(数量.item_count - 1)) == "9",
		"幸运符数量最后一项应为 9")

	# ⑩ 驯养三页（真值 §16/§17/§18）：页签几何、三页根偏移、进阶页条/材料格/钮宽、
	#    提升页两态、融魂页「白字不是钮」+ 默认三尾。
	# ⚠️ 同样的夹具重建：⑤ 的放生已经把数组删短了。
	会话.pets = _造三只()
	窗口._驯养宠物id = "1"
	窗口._驯养页签 = 0
	窗口.open_page("通灵驯养")
	await process_frame
	await process_frame
	var 窗页 := _找节点(窗口._content, "原版通灵驯养内容") as Control
	_查(窗页 != null, "驯养窗壳没渲染出来")
	if 窗页 != null:
		var 期望x := [3.0, 57.0, 111.0, 165.0]
		for 号 in 3:
			var 签 := 窗页.get_node_or_null("页签_%d" % 号) as Button
			_查(签 != null and is_equal_approx(签.offset_right - 签.offset_left, 54.0)
					and is_equal_approx(签.offset_bottom - 签.offset_top, 22.0),
				"页签_%d 应是 54×22（真值 §16 isScale9Grid 量出来的宽），实得 %s" % [号, 签.size if 签 != null else "<无>"])
			_查(签 != null and is_equal_approx(签.offset_left, 期望x[号]),
				"页签_%d 的 x 应为 %.0f，实得 %s" % [号, 期望x[号], 签.offset_left if 签 != null else "<无>"])
		var 进化签 := 窗页.get_node_or_null("页签_3") as Button
		_查(进化签 != null and not 进化签.visible, "第 4 枚页签（通灵进化）非尾兽宠物必须隐藏")
	# —— 进阶页：祝福条按 §10 的 底/裁剪/填充/值 四件；格名是固定语言不是道具名；两枚钮宽 30/54
	var 进阶页 := _找节点(窗口._content, "宠物进阶页") as Control
	_查(进阶页 != null, "进阶页没渲染出来")
	if 进阶页 != null:
		var 条 := 进阶页.get_node_or_null("祝福条") as Control
		_查(条 != null and 条.get_node_or_null("底") != null and 条.get_node_or_null("裁剪") != null
				and 条.get_node_or_null("裁剪/填充") != null and 条.get_node_or_null("值") != null,
			"祝福条必须是 底/裁剪/填充/值 四件（真值 §10）")
		if 条 != null:
			var 脚本 := load("res://脚本/界面/窗口/通灵驯养窗口.gd")
			脚本._设条(条, 42, 100)
			await create_timer(0.7).timeout
			var 填充 := 条.get_node("裁剪/填充") as TextureRect
			# 42/100 ⇒ W=168、r=0.42 ⇒ 填充.position.x = −3 − floor(168×0.58) = −3 − 97 = −100
			_查(is_equal_approx(填充.position.x, -100.0),
				"祝福条填充位应按 §10 滑到 −100（不压扁），实得 %.1f" % 填充.position.x)
			_查(String((条.get_node("值") as Label).text) == "42/100",
				"祝福条「值」必须显：%s" % (条.get_node("值") as Label).text)
		var 格名 := 进阶页.get_node_or_null("进阶符格/名") as Label
		_查(格名 != null and 格名.text == "进阶符", "进阶符格格名应是固定语言「进阶符」，实得 %s" % (格名.text if 格名 != null else "<无>"))
		var 记忆格名 := 进阶页.get_node_or_null("记忆符格/名") as Label
		_查(记忆格名 != null and 记忆格名.text == "记忆符", "记忆符格格名应是「记忆符」")
		var 数量标签 := 进阶页.get_node_or_null("进阶符格/数量") as Label
		if 数量标签 != null:
			_查(数量标签.modulate.r < 0.9, "背包不够时数量要跟着图标一起变暗（不是变红）")
		var 提示钮 := 进阶页.get_node_or_null("提示") as Button
		_查(提示钮 != null and is_equal_approx(提示钮.offset_right - 提示钮.offset_left, 30.0),
			"进阶页「提示」钮宽应为 30（2 全角字 + 6）")
		var 开始钮 := 进阶页.get_node_or_null("开始提升") as Button
		_查(开始钮 != null and is_equal_approx(开始钮.offset_right - 开始钮.offset_left, 54.0),
			"进阶页「开始提升」宽应为 54")
		# 悬停详情：材料格在原版是 `ItemCaiLiaoBox`（内含 `SimpleItemCell`），itemData 由
		# `PetLayerTab.as:122-125` 填上 ⇒ `SimpleItemCell.as:220` 自动挂 MToolTipItem。
		# 所以悬停 40×40 的 itemCell 必须弹物品详情（2026-11-02 巡检：三页材料格原缺这一段）。
		var 符图标 := 进阶页.get_node_or_null("进阶符格/图标") as Control
		var 提示框 := 窗页.get_node_or_null("物品提示框") as Control
		_查(符图标 != null and 提示框 != null, "⑩ 驯养窗该在运行期挂物品提示框、进阶符格该有图标")
		if 符图标 != null and 提示框 != null:
			var 进化: Dictionary = ((驯养窗.数据.pet_template(101).get("info", {}) as Dictionary)
					.get("evolution", {})) as Dictionary
			var 符号 := int(进化.get("needItemId", 0))
			_查(符号 > 0, "⑩ 夹具宠物 101 的进阶材料号该非 0（数据/宠物.json 的 info.evolution.needItemId）")
			_查(not 提示框.visible, "⑩ 悬停前提示框应藏着（场景根 visible=false）")
			符图标.mouse_entered.emit()
			_查(提示框.visible, "⑩ 悬停进阶符格该弹出物品提示框")
			_查(String((提示框.get_node("标题") as Label).text) == 驯养窗.数据.item_name(符号),
				"⑩ 提示框标题 = 进阶符道具名，实得 %s" % (提示框.get_node("标题") as Label).text)
			符图标.mouse_exited.emit()
			_查(not 提示框.visible, "⑩ 移开后提示框该收起")
	# —— 提升页：页根 (−2,−2)、type0 与选模式两态
	窗口._驯养页签 = 1
	窗口._驯养提升模式 = -1
	窗口._render_page()
	await process_frame
	await process_frame
	var 提升页 := _找节点(窗口._content, "宠物提升页") as Control
	_查(提升页 != null, "提升页没渲染出来")
	if 提升页 != null:
		var 提升宠: Dictionary = 窗口._pet_by_id(窗口._驯养宠物id)
		_查(提升页.position.is_equal_approx(Vector2(-2, -2)), "提升页根应摆 (−2,−2)（页容器原点 12,60 vs 页根 10,58），实得 %s" % 提升页.position)
		var 中底 := 提升页.get_node_or_null("中底") as Panel
		_查(中底 != null and not 中底.visible, "type0（没选属性）时中框必须整块隐藏（真值 §17）")
		for 名 in ["待提升2", "模型底", "名称等级", "提升提示", "宠物形象"]:
			var 件 := 提升页.get_node_or_null(名) as Control
			_查(件 != null and 件.visible, "type0 下框「%s」应可见" % 名)
		# type0 上框不是空板：原版 `initType:734` 写的是 `STRONG_DESC_13` 六行说明
		var 上文字0 := 提升页.get_node_or_null("上文字") as RichTextLabel
		_查(上文字0 != null and String(上文字0.text).contains("通过属性提升操作可以使你的通灵兽变得更强")
				and String(上文字0.text).contains("提升通灵兽健体潜力"),
			"type0 上框应为 STRONG_DESC_13 六行说明，实得 %s" % (上文字0.text if 上文字0 != null else "<无>"))
		var 提示0 := 提升页.get_node_or_null("提升提示") as Label
		_查(提示0 != null and 提示0.text == "强化通灵兽需要资质符和金币，当背包内准备好后可以点击右上方按钮进行选择",
			"「提升提示」应逐字用 STRONG_PRPMPT_4，实得 %s" % (提示0.text if 提示0 != null else "<无>"))
		var 上底 := 提升页.get_node_or_null("上底") as Panel
		_查(上底 != null and is_equal_approx(上底.offset_bottom, 164.0), "type0 上底高 134（30..164），实得 %.0f" % (上底.offset_bottom if 上底 != null else -1.0))
		var 提升钮 := _找按钮(窗口._content, "提升按钮")
		_查(提升钮 != null and is_equal_approx(提升钮.offset_left, 320.0)
				and is_equal_approx(提升钮.offset_right - 提升钮.offset_left, 54.0),
			"「开始提升」应 @(320,318) 宽 54（真值 §17）")
		# —— 潜力态（攻）：中框 = 标题「提升效果预览」+ 两行（实值 / **总潜力**算出的加成）+ 中尾注；
		#    材料格在 (15,221)、消耗 (200,223)（`createStrongView:828/:861`）
		窗口._驯养提升模式 = 2
		窗口._render_page()
		await process_frame
		await process_frame
		提升页 = _找节点(窗口._content, "宠物提升页") as Control
		if 提升页 != null:
			var 中底2 := 提升页.get_node_or_null("中底") as Panel
			_查(中底2 != null and 中底2.visible and is_equal_approx(中底2.offset_bottom, 212.0),
				"选了潜力模式后中框应可见且高 96（116..212）")
			var 潜标题 := 提升页.get_node_or_null("中效果标题") as Label
			var 潜内容 := 提升页.get_node_or_null("中效果内容") as RichTextLabel
			var 潜尾注 := 提升页.get_node_or_null("中尾注") as Label
			_查(潜标题 != null and 潜标题.visible and 潜标题.text == "提升效果预览",
				"潜力态中框标题应是「提升效果预览」（TI_SHENG_XIAO_GUO），实得 %s" % (潜标题.text if 潜标题 != null else "<无>"))
			_查(潜内容 != null and String(潜内容.text).contains("当前为你加成攻击力")
					and String(潜内容.text).contains("提升到最大后将加成"),
				"潜力态中框应是两行「实值 / 满值加成」，实得 %s" % (潜内容.text if 潜内容 != null else "<无>"))
			_查(潜尾注 != null and 潜尾注.visible, "中尾注（STRONG_PRPMPT_3）只属于潜力态，应可见")
			var 潜上文字 := 提升页.get_node_or_null("上文字") as RichTextLabel
			# ⚠ 「最大可以提升到 ：」后面跟的是**总潜力**（`getStrongApa:520-523` 传 potentialTotalApX），
			#    上一版写的是模板 `values[档].max` ⇒ 同一个数在两个地方对不上
			var 期望总: String = "最大可以提升到 ：%d" % int(提升宠.get("potential_total_atk", 0))
			_查(潜上文字 != null and String(潜上文字.text).contains(期望总),
				"潜力态上框应含「%s」（总潜力），实得 %s" % [期望总, 潜上文字.text if 潜上文字 != null else "<无>"])
			_查(潜上文字 != null and String(潜上文字.text).contains("攻击潜力提升后,你的通灵兽可为你加成更多攻击力"),
				"潜力态上框缺尾句 STRONG_DESC_12")
			var 潜符格 := 提升页.get_node_or_null("资质符格") as Control
			var 潜消耗 := 提升页.get_node_or_null("消耗") as Control
			_查(潜符格 != null and 潜符格.position.is_equal_approx(Vector2(15, 221)),
				"潜力态资质符格应 @(15,221)，实得 %s" % (潜符格.position if 潜符格 != null else Vector2(-1, -1)))
			_查(潜消耗 != null and 潜消耗.position.is_equal_approx(Vector2(200, 223)),
				"潜力态消耗行应 @(200,223)，实得 %s" % (潜消耗.position if 潜消耗 != null else Vector2(-1, -1)))
			var 幸运标签 := 提升页.get_node_or_null("幸运符标签") as Label
			_查(幸运标签 != null and 幸运标签.visible, "潜力模式必须显示「个幸运符」标签")
			var 消耗 := 提升页.get_node_or_null("消耗") as RichTextLabel
			_查(消耗 != null and String(消耗.text).contains("\n") and String(消耗.text).contains("本次操作成功几率"),
				"提升页「消耗」是两行（金币 + 几率），实得 %s" % (消耗.text if 消耗 != null else "<无>"))
			var 上底2 := 提升页.get_node_or_null("上底") as Panel
			_查(上底2 != null and is_equal_approx(上底2.offset_bottom, 110.0), "潜力模式上底高 80（30..110）")
			# —— 品级态：标题换成「当前通灵兽潜力值 ↔ 提升成功后区间」，**没有中尾注**；
			#    只有一格 ⇒ 资质符 (92,221)、消耗跟在右边 (142,236)（`strongApt:179-214`）
			窗口._驯养提升模式 = 0
			窗口._render_page()
			await process_frame
			await process_frame
			提升页 = _找节点(窗口._content, "宠物提升页") as Control
			if 提升页 != null:
				var 级标题 := 提升页.get_node_or_null("中效果标题") as Label
				_查(级标题 != null and 级标题.text == "当前通灵兽潜力值\t\t提升成功后通灵兽潜力区间",
					"品级态中框标题应是 CURRENT_PET_QIANLI 两列标题，实得 %s" % (级标题.text if 级标题 != null else "<无>"))
				_查(not (提升页.get_node_or_null("中尾注") as Label).visible, "品级态没有中尾注（真值 §17）")
				var 级中内容 := 提升页.get_node_or_null("中效果内容") as RichTextLabel
				_查(级中内容 != null and not String(级中内容.text).contains("<"),
					"品级态中框漏了裸 HTML 标签（RichTextLabel 会把标签显示给玩家），实得 %s"
						% (级中内容.text if 级中内容 != null else "<无>"))
				var 级上文字 := 提升页.get_node_or_null("上文字") as RichTextLabel
				_查(级上文字 != null and String(级上文字.text).contains("品级提升后,将大幅提高通灵兽为你带来的属性加成"),
					"「品级提升后…」这句属于**上框**（STRONG_DESC_8 第三行），不在中框")
				var 级符格 := 提升页.get_node_or_null("资质符格") as Control
				var 级消耗 := 提升页.get_node_or_null("消耗") as Control
				_查(级符格 != null and 级符格.position.is_equal_approx(Vector2(92, 221)),
					"品级态资质符格应 @(92,221)（只有一格），实得 %s" % (级符格.position if 级符格 != null else Vector2(-1, -1)))
				_查(级消耗 != null and 级消耗.position.is_equal_approx(Vector2(142, 236)),
					"品级态消耗行应跟在格子右边 @(142,236)，实得 %s" % (级消耗.position if 级消耗 != null else Vector2(-1, -1)))
				_查(not (提升页.get_node_or_null("幸运符标签") as Label).visible, "品级态没有幸运符那一行")
			# —— 悟性态：整个中框撤下，换成两行各 8 格（`strongSav:578-643`）
			窗口._驯养提升模式 = 1
			窗口._render_page()
			await process_frame
			await process_frame
			提升页 = _找节点(窗口._content, "宠物提升页") as Control
			if 提升页 != null:
				_查((提升页.get_node_or_null("技能框") as Control).visible, "悟性态必须显示技能框")
				for 名 in ["中底", "中效果标题", "中效果内容", "中尾注"]:
					var 件2 := 提升页.get_node_or_null(名) as Control
					_查(件2 != null and not 件2.visible, "悟性态「%s」必须让位给技能框（strongSav 先清空中框）" % 名)
				var 技框 := 提升页.get_node_or_null("技能框") as Control
				if 技框 != null:
					var 技标题 := 技框.get_node_or_null("当前标题") as Label
					var 未标题 := 技框.get_node_or_null("未学标题") as Label
					_查(技标题 != null and 技标题.text == "当前通灵兽技能", "技能框首行标题应为 CURRENT_PET_SKILL")
					_查(未标题 != null and 未标题.text == "尚未领悟的技能", "技能框次行标题应为 NOT_STUDY_PET_SKILL")
					# 格位 = 原版 `(42 + (i==0?0:7)) * i + 3` ⇒ 3 / 52 / 101 … 346
					for 行名 in ["当前行", "未学行"]:
						var 行 := 技框.get_node_or_null(行名) as Control
						_查(行 != null and 行.get_child_count() == 8, "%s 应摆满 8 格，实得 %s" % [行名, 行.get_child_count() if 行 != null else -1])
						if 行 != null and 行.get_child_count() == 8:
							_查(is_equal_approx(行.get_child(0).position.x, 3.0)
									and is_equal_approx(行.get_child(1).position.x, 52.0)
									and is_equal_approx(行.get_child(7).position.x, 346.0),
								"%s 的格位应是首格 3、其后 49 间距（3 / 52 … 346），实得 %.0f / %.0f / %.0f" % [
										行名, 行.get_child(0).position.x, 行.get_child(1).position.x, 行.get_child(7).position.x])
					_查(is_equal_approx((技框.get_node_or_null("当前行") as Control).position.y, 110.0)
							and is_equal_approx((技框.get_node_or_null("未学行") as Control).position.y, 172.0),
						"两行技能格应落在 y=110 / y=172（真值 §17）")
				var 悟上文字 := 提升页.get_node_or_null("上文字") as RichTextLabel
				_查(悟上文字 != null and String(悟上文字.text).contains("提升通灵兽悟性"), "悟性态上框应为 STRONG_DESC_7")
				var 悟符格 := 提升页.get_node_or_null("资质符格") as Control
				_查(悟符格 != null and 悟符格.position.is_equal_approx(Vector2(92, 221)),
					"悟性态资质符格同样 @(92,221)（strongSav:657）")
				# 悟性态**下框照留**：`strongSav:644-669` 是 `_downCon.visible = true` 再重建资质符格 + 消耗，
				# 只撤中框。（旧版把这三件跟中框一起藏在 `not 有技能行` 里 ⇒ 悟性页下半全空。）
				for 名 in ["下底", "资质符格", "消耗"]:
					var 下件 := 提升页.get_node_or_null(名) as Control
					_查(下件 != null and 下件.visible, "悟性态下框「%s」必须保留（原版只撤中框）" % 名)
				# 技能格尺寸：`SkillCellF` 是 40×40、图标 34×34（以前写 42/36 ⇒ 整排宽一圈、图标大 2px）
				var 格行 := 技框.get_node_or_null("当前行") as Control if 技框 != null else null
				if 格行 != null and 格行.get_child_count() > 0:
					var 首格 := 格行.get_child(0) as Control
					_查(首格 != null and is_equal_approx(首格.size.x, 40.0) and is_equal_approx(首格.size.y, 40.0),
						"技能格应是 40×40（`SkillCellF` 原尺寸），实得 %s" % (首格.size if 首格 != null else Vector2(-1, -1)))
					var 格底 := 首格.get_node_or_null("底") as Control if 首格 != null else null
					_查(格底 != null and is_equal_approx(格底.size.x, 40.0), "技能格底图应是 40×40")
					var 格图标 := 首格.get_node_or_null("图标") as Control if 首格 != null else null
					_查(格图标 != null and 格图标.position.is_equal_approx(Vector2(3, 3))
							and is_equal_approx(格图标.size.x, 34.0),
						"技能图标应是 34×34 @(3,3)，实得 %s @ %s" % [
							格图标.size if 格图标 != null else Vector2(-1, -1),
							格图标.position if 格图标 != null else Vector2(-1, -1)])
			# 选回占位项 ⇒ 原版 `selectedIndex = -1`，必须真的回到 type0（中框收起）
			var 下拉2 := 提升页.get_node_or_null("模式下拉") as OptionButton
			if 下拉2 != null:
				下拉2.selected = 0
				下拉2.item_selected.emit(0)
				await process_frame
				await process_frame
				_查(窗口._驯养提升模式 == -1, "选回占位项后模式应回 −1，实得 %d" % 窗口._驯养提升模式)
				提升页 = _找节点(窗口._content, "宠物提升页") as Control
				var 中底3 := 提升页.get_node_or_null("中底") as Panel if 提升页 != null else null
				_查(中底3 != null and not 中底3.visible, "选回占位项后中框必须重新收起（type0）")
				var 技框3 := 提升页.get_node_or_null("技能框") as Control if 提升页 != null else null
				_查(技框3 != null and not 技框3.visible, "回到 type0 后技能框必须收起")
	# —— 融魂页：没有「尾兽预览」钮（那是一行白字）；进页默认三尾；点尾兽立即换详情
	窗口._驯养页签 = 2
	窗口._驯养融魂下标 = -1
	窗口._融魂预览已开 = false
	窗口._render_page()
	await process_frame
	await process_frame
	var 融魂页 := _找节点(窗口._content, "宠物融魂页") as Control
	_查(融魂页 != null, "融魂页没渲染出来")
	_查(窗口._驯养融魂下标 == 2, "进融魂页必须默认选中三尾（原版 update() 写死 setWeiShouInfo(2)），实得 %d" % 窗口._驯养融魂下标)
	if 融魂页 != null:
		_查(融魂页.position.is_equal_approx(Vector2(-4, -7)), "融魂页根应摆 (−4,−7)，实得 %s" % 融魂页.position)
		var 预览字 := 融魂页.get_node_or_null("预览字")
		_查(预览字 is Label, "「预览字」必须是一行白字 Label，不是按钮")
		_查(预览字 != null and not (预览字 as Control).visible, "选中尾兽后预览字必须隐藏（真值 §18.1）")
		var 红字 := 融魂页.get_node_or_null("红字") as Label
		_查(红字 != null and 红字.text == "当前只开放4个尾兽形态!", "融魂页红字文案不对：%s" % (红字.text if 红字 != null else "<无>"))
		var 兽名 := 融魂页.get_node_or_null("宠物名") as Label
		_查(兽名 != null and String(兽名.text).contains("三尾"), "默认应显示三尾详情，实得 %s" % (兽名.text if 兽名 != null else "<无>"))
		var 潜力零 := 融魂页.get_node_or_null("潜力_0") as Label
		_查(潜力零 != null and 潜力零.text == "最大潜力总值：24792", "尾兽潜力是常数 6198×4，实得 %s" % (潜力零.text if 潜力零 != null else "<无>"))
		var 四尾钮 := _找按钮(窗口._content, "尾兽_3")
		_查(四尾钮 != null and not 四尾钮.disabled, "四尾按钮应可用")
		if 四尾钮 != null:
			四尾钮.pressed.emit()
			await process_frame
			await process_frame
			兽名 = _找节点(窗口._content, "宠物名") as Label
			_查(兽名 != null and String(兽名.text).contains("四尾"), "点四尾后详情应换成四尾，实得 %s" % (兽名.text if 兽名 != null else "<无>"))
	# 尾兽宠 ⇒ 第 4 枚页签要显出来
	var 尾兽宠: Array[Dictionary] = _造三只()
	尾兽宠[0] = 尾兽宠[0].duplicate(true)
	尾兽宠[0]["item_id"] = 401
	会话.pets = 尾兽宠
	窗口._驯养宠物id = "1"
	窗口._驯养页签 = 0
	窗口._render_page()
	await process_frame
	await process_frame
	var 窗页2 := _找节点(窗口._content, "原版通灵驯养内容") as Control
	if 窗页2 != null:
		var 进化签2 := 窗页2.get_node_or_null("页签_3") as Button
		_查(进化签2 != null and 进化签2.visible, "尾兽宠物必须显示第 4 枚页签（通灵进化）")

	# ⑪ 材料格（#3.3 2026-10-20）：`ItemCaiLiaoBox` 四件套 —— 40×40 底图（`SimpleItemCell` 的
	#    `MGrid_background` = 物品格.png）、图标 34×34 格内居中 (2.5+3)、数量字 40×20 压格子底边右对齐、
	#    格名 `UI_ORANGE #FF9100` + bold（Godot 无粗体字面 ⇒ FontVariation + variation_embolden 0.8）、
	#    购买钮 37×22 @(4,63)。残魂格是 50 宽的同一控件（`PetRongHunTab.as:239-243`，label 空串、也有购买）。
	会话.pets = _造三只()
	窗口._驯养宠物id = "1"
	窗口._驯养页签 = 0
	窗口._render_page()
	await process_frame
	await process_frame
	var 进阶页3 := _找节点(窗口._content, "宠物进阶页") as Control
	if 进阶页3 != null:
		_验材料格(进阶页3.get_node_or_null("进阶符格") as Control, 45.0, "进阶符", "进阶符格")
		_验材料格(进阶页3.get_node_or_null("记忆符格") as Control, 45.0, "记忆符", "记忆符格")
	else:
		_fails.append("⑪ 进阶页没渲染出来")
	窗口._驯养页签 = 1
	窗口._驯养提升模式 = 2
	窗口._render_page()
	await process_frame
	await process_frame
	var 提升页3 := _找节点(窗口._content, "宠物提升页") as Control
	if 提升页3 != null:
		_验材料格(提升页3.get_node_or_null("资质符格") as Control, 45.0, "资质符", "资质符格")
		_验材料格(提升页3.get_node_or_null("幸运符格") as Control, 45.0, "幸运符", "幸运符格")
	else:
		_fails.append("⑪ 提升页没渲染出来")
	窗口._驯养页签 = 2
	窗口._驯养提升模式 = -1
	窗口._render_page()
	await process_frame
	await process_frame
	var 融魂页3 := _找节点(窗口._content, "宠物融魂页") as Control
	if 融魂页3 != null:
		_验材料格(融魂页3.get_node_or_null("残魂格") as Control, 50.0, "", "残魂格")
	else:
		_fails.append("⑪ 融魂页没渲染出来")

	# ⑫ #3.2 首帧提示：`_打开驯养窗` 必须「先建实例 → 灌 `_驯养宠物id` → 再打开」。
	#    上一版是 `管理.打开()` 先跑（立刻渲染一次、宠物 id 还是空串）⇒ 每次开驯养窗都弹
	#    「请先在通灵兽列表里选一只通灵兽」，随后才被第二次渲染盖掉（用户 2026-10-20 报修）。
	#    这里用迷你窗口管理走**真路径**，顺带钉「只打开一次、页面真的渲染出来」。
	var 管理 := 假管理.new()
	get_root().add_child(管理)
	var 宠物窗 := 管理.取或建窗口("宠物")
	宠物窗.set("_selected_pet_id", "1")
	_提示.clear()
	宠物窗.call("_打开驯养窗", "1", 1, -1)
	await process_frame
	await process_frame
	_查(_提示.is_empty(), "⑫ 打开驯养窗首帧不该弹提示，实得 %s" % [_提示])
	_查(int(管理.打开表.get("通灵驯养", 0)) == 1,
		"⑫ 驯养窗应只被「打开」一次，实得 %d" % int(管理.打开表.get("通灵驯养", 0)))
	var 副窗 := 管理.取窗口("通灵驯养")
	_查(副窗 != null and bool(副窗.call("已打开")), "⑫ 驯养窗没真打开")
	if 副窗 != null:
		_查(String(副窗.get("_驯养宠物id")) == "1", "⑫ 驯养窗的宠物 id 应已灌成 1，实得 %s" % str(副窗.get("_驯养宠物id")))
		_查(_找节点(副窗._content, "宠物提升页") != null, "⑫ 驯养窗首帧必须真的渲染出提升页")
		_查(int(副窗.get("_驯养提升模式")) == -1, "⑫ 没指定模式时默认应是 −1（type0 未选），实得 %d" % int(副窗.get("_驯养提升模式")))
	# 再走一次「已经开着」的分支：不许重复打开、也不许弹提示
	_提示.clear()
	宠物窗.call("_打开驯养窗", "1", 2, -1)
	await process_frame
	_查(_提示.is_empty(), "⑫ 已开着的驯养窗重设页签不该弹提示，实得 %s" % [_提示])
	_查(int(管理.打开表.get("通灵驯养", 0)) == 1,
		"⑫ 已开着时不该再次「打开」驯养窗，实得 %d" % int(管理.打开表.get("通灵驯养", 0)))

	# ⑬ 报修 4.2 + 4.1（2026-10-25）：**尾兽预览不是居中弹，是贴在驯养窗右缘外侧的一扇**。
	#    AS3 真值 `PetRongHunTab.showYuLanWindow:567-570` = `new RongHunYuLanWindow();
	#    x=404; y=-6; this.addChild(...)` —— 挂在**融魂页**上；页根实测落驯养窗局部 (8,53)
	#    ⇒ 预览落**驯养窗局部 (412,47)**，而驯养窗只有 410 宽 ⇒ 天生压着右缘外侧 2px。
	#    上一版走的是 `窗口管理` 的默认居中，实测压住宠物主窗 **264×244**（用户报修原话
	#    "尾兽的形象在最右侧，不与其他宠物面板重叠"）。
	#    ⚠️ 本门是 headless 跑的，视口只有 64×64 ⇒ **一律断相对量**（谁贴谁、差几像素、
	#    相不相交），不断绝对坐标。
	#    上面 ⑫ 末尾那次 `_打开驯养窗(…, 2, …)` 已经把预览窗真开出来了
	#    （`_融魂预览已开` 复位 → 渲染 → `通灵驯养窗口.gd:356-359` 的 `call_deferred`）。
	var 预览窗 := 管理.取窗口("尾兽预览")
	## ⚠️ GDScript 4 的 `var` 是**块级**作用域：写在 `if` 里的变量出了那块就没了。
	##   下面"关掉预览后整条回居中"要比对关掉**前后**的主窗左沿，所以先在外层声明。
	var 主框 := Rect2()
	_查(预览窗 != null and bool(预览窗.call("已打开")),
		"⑬ 进融魂页必须自动弹出尾兽预览（原版 update() → setWeiShouInfo(2) → showYuLanWindow）")
	# ⑫ 那两发 `_打开驯养窗` 是在**主窗还没打开**的状态下跑的 ⇒ `_重摆宠物双窗` 的
	# `主.call("已打开")` 闸直接跳过，主窗还停在场景默认的 517×440（人物尺寸）。
	# 真游戏里这条一定成立（驯养窗本来就是从开着的宠物窗里点出来的），这里补一发把它当真。
	管理.打开("宠物")
	await process_frame
	await process_frame
	宠物窗.call("_摆宠物双窗")		# 预览此刻已开着 ⇒ 应当走"整条贴右墙"那一支
	await process_frame
	if 预览窗 != null and bool(预览窗.call("已打开")):
		var 视口尺 := get_root().get_visible_rect().size
		主框 = (宠物窗.get_node("遮罩/主窗口") as Control).get_global_rect()
		var 副框: Rect2 = (副窗.get_node("遮罩/主窗口") as Control).get_global_rect()
		var 预框: Rect2 = (预览窗.get_node("遮罩/主窗口") as Control).get_global_rect()
		_查(is_equal_approx(预框.position.x, 副框.end.x + 2.0),
			"⑬ 预览左沿必须贴驯养窗右缘外侧 2px（页局部 404 + 页根 8 = 窗局部 412，窗宽 410），实得 预%.1f 副右%.1f" % [
				预框.position.x, 副框.end.x])
		_查(is_equal_approx(预框.position.y, 副框.position.y + 47.0),
			"⑬ 预览顶沿必须在驯养窗局部 y=47（页根 y=53 + 原版 y=−6），实得 预%.1f 副%.1f" % [
				预框.position.y, 副框.position.y])
		_查(not 预框.intersects(副框), "⑬ 预览与驯养窗重叠了：%s ∩ %s" % [预框, 副框])
		_查(not 预框.intersects(主框), "⑬ 预览与宠物主窗重叠了：%s ∩ %s（用户报修 4.2 就是这条）" % [预框, 主框])
		_查(预框.end.x <= 视口尺.x + 0.5,
			"⑬ 预览不许推出右墙（整条 1256 > 960 ⇒ `_摆宠物双窗` 要改成贴右墙），实得 预右%.1f 视口%.0f" % [
				预框.end.x, 视口尺.x])
		_查(is_equal_approx(主框.end.x, 副框.position.x), "⑬ 主窗与驯养窗仍要紧贴成对（原版 petTab.x = _width）")
		# —— 4.1 之一：预览窗里那两件事。
		#    ① `图底` 原版是 **scale-9 符号** `PetPic_background`（`initWindowUI:41-46` 只给
		#       width=376/height=280）⇒ 必须是 NinePatchRect；TextureRect+STRETCH_SCALE 会把
		#       198×111 的整幅底图拉成 1.9×2.5 倍，四边渐变糊成一团（用户报修"图标过长"）。
		#    ② 立绘**不缩放**：`setPetSkin:58-65` 建完 `PetSprite` 直接 `x=200; y=315`，
		#       全文件没有一处 `scaleX/scaleY` —— 这扇的名字就叫"真实效果预览"；0.5 是
		#       页内那枚小预览（`drawPetMovie:282-286`）的口径，上一版把两处当成一处。
		var 预页 := _找节点(预览窗._content, "原版尾兽预览内容") as Control
		_查(预页 != null, "⑬ 预览页根没渲染出来")
		if 预页 != null:
			var 图底 := 预页.get_node_or_null("图底")
			_查(图底 is NinePatchRect,
				"⑬ 预览窗图底必须是 NinePatchRect（原版 scale-9 符号），实得 %s" % (
					图底.get_class() if 图底 != null else "<无>"))
			if 图底 is NinePatchRect:
				var 贴 := (图底 as NinePatchRect).texture
				_查(贴 != null, "⑬ 预览窗图底没贴图（改成 NinePatchRect 后贴图烘在场景里，运行期不再赋值）")
				for 边 in ["left", "top", "right", "bottom"]:
					var 尺: float = (图底 as NinePatchRect).get("patch_margin_" + 边)
					_查(尺 >= 8.0 and 尺 <= 16.0,
						"⑬ 预览窗图底 patch_margin_%s 应在 8..16（实测底图四边渐变带正好 12px），实得 %.1f" % [边, 尺])
			var 模型位 := 预页.get_node_or_null("模型位") as Control
			_查(模型位 != null, "⑬ 预览页缺「模型位」")
			if 模型位 != null:
				_查(模型位.get_global_position().is_equal_approx(预框.position + Vector2(200, 315)),
					"⑬ 模型位必须落预览窗局部 (200,315)（`setPetSkin:63-64`），实得 %s / 窗 %s" % [
						模型位.get_global_position(), 预框.position])
				var 立绘 := 模型位.get_child(0) as Node2D if 模型位.get_child_count() > 0 else null
				_查(立绘 != null, "⑬ 预览窗里没有尾兽立绘（`_预览尾兽号` 没灌进渲染那扇的实例 ⇒ §3.62 跨窗状态坑）")
				if 立绘 != null:
					_查(立绘.scale.is_equal_approx(Vector2.ONE),
						"⑬ 预览窗立绘必须 1:1（原版那扇没有 scaleX），实得 %s" % 立绘.scale)
	# —— 切出融魂页 ⇒ 预览必须跟着收（原版它是那一页的孩子，`setType` 换页整页 removeChild）。
	副窗.call("_切驯养页签", 0)
	await process_frame
	await process_frame
	_查(预览窗 != null and not bool(预览窗.call("已打开")), "⑬ 切出融魂页后尾兽预览还开着")
	# 换页重排：预览没了 ⇒ 整条要回到常规居中（主窗左沿比贴右墙时**靠右**）。
	var 主框收 := (宠物窗.get_node("遮罩/主窗口") as Control).get_global_rect()
	_查(主框收.position.x > 主框.position.x,
		"⑬ 预览关掉后整条要回居中，实得 %.1f → %.1f" % [主框.position.x, 主框收.position.x])
	# —— 再进融魂页：预览要能重新弹出来（`_融魂预览已开` 必须跟着复位）。
	副窗.call("_切驯养页签", 2)
	await process_frame
	await process_frame
	_查(bool(预览窗.call("已打开")), "⑬ 再进融魂页预览没重开（`_融魂预览已开` 没复位）")
	# —— 玩家自己点 X 关掉预览 ⇒ 同一件事：整条回居中。
	#    ⚠️ 这条钉的是 `close()` 里那句 `_重摆宠物双窗()` **必须在 `_overlay.visible=false` 之后**：
	#    `已打开()` 读的就是 `_overlay.visible`，摆位函数靠它判断预览还在不在。
	预览窗.call("close")
	await process_frame
	var 主框再 := (宠物窗.get_node("遮罩/主窗口") as Control).get_global_rect()
	_查(主框再.position.x > 主框.position.x,
		"⑬ 玩家自己关掉预览后整条仍留在贴右墙位（%.1f → %.1f）⇒ close() 里重排跑在 `_overlay.visible=false` 之前" % [
			主框.position.x, 主框再.position.x])
	# —— 4.1 之二：驯养四页 + 预览页**一枚缺图、一枚溢出都不许有**（用户报修原话"缺少一些图标"）。
	#    口径同 `开发工具/_探_驯养图标与预览实测.gd` 甲段，这里收成常驻门。
	# ⚠️ `[1, -1]`（属性提升页 **type0**：下拉还没选任何东西）是后补的一档：
	#   原来四档全给了 `模式 >= 0` ⇒ 那一档下半页（`initType:727-771` 的"你将要提升的通灵兽是"
	#   + 模型底 + 名称/等级 + 立绘）从没被扫过，`<b>` 漏字就藏在那儿（§3.277）。
	for 组 in [[0, -1], [1, -1], [1, 0], [1, 2], [2, -1]]:
		副窗._驯养页签 = int(组[0])
		副窗._驯养提升模式 = int(组[1])
		副窗._驯养融魂下标 = -1
		副窗._融魂预览已开 = false
		副窗._render_page()
		await process_frame
		var 病 := _扫图标毛病(副窗._content, 0)
		_查(病.is_empty(), "⑬ 驯养页签 %d/模式 %d 图标有毛病：%s" % [int(组[0]), int(组[1]), " | ".join(病)])
		var 漏 := _扫标签漏字(副窗._content, 0)
		_查(漏.is_empty(), "⑬ 驯养页签 %d/模式 %d 有标签原样显示给玩家：%s" % [int(组[0]), int(组[1]), " | ".join(漏)])
	副窗._切驯养页签(2)
	await process_frame
	if bool(预览窗.call("已打开")):
		var 病预 := _扫图标毛病(预览窗._content, 0)
		_查(病预.is_empty(), "⑬ 尾兽预览窗图标有毛病：%s" % " | ".join(病预))
		var 漏预 := _扫标签漏字(预览窗._content, 0)
		_查(漏预.is_empty(), "⑬ 尾兽预览窗有标签原样显示给玩家：%s" % " | ".join(漏预))
	管理.queue_free()

	# ⑧ 副窗兜底：没有窗口管理（挂在 root 上）时不能崩
	窗口._随选中开驯养窗()

	_收尾(窗口, 会话, 原宠, 原容量, 原属性)


## ⑬ 的图标扫描（口径逐字照 `开发工具/_探_驯养图标与预览实测.gd` 的甲段）：
##   **缺图** = 可见的 `TextureRect` / `TextureButton` 没贴图；
##   **溢出** = 画出来的矩形比节点还大 ⇒ 用户报修 4.1 那句"图标过长远超出按键"。
##     Godot 4 的枚举实数：StretchMode 2=KEEP 3=KEEP_CENTERED 6=KEEP_ASPECT_COVERED，
##     ExpandMode 0=KEEP_SIZE。前三种（外加 KEEP_SIZE）画的都是**贴图原尺寸**，
##     COVERED 会在一个轴上溢出；其余模式收进节点框 ⇒ 不查。
## 隐藏的节点跳过（原版换页时那些 type0/潜力态互斥的件就是靠 visible 收起来的）。
func _扫图标毛病(节: Node, 层: int) -> Array[String]:
	var 出: Array[String] = []
	if 层 > 40:
		return 出
	for 子 in 节.get_children():
		var c := 子 as Control
		if c == null or not c.visible:
			continue
		if c is TextureRect:
			var t := c as TextureRect
			if t.texture == null:
				出.append("%s 没贴图" % String(c.name))
			else:
				var 原 := Vector2(t.texture.get_width(), t.texture.get_height())
				var 画 := c.size
				if int(t.expand_mode) == 0 or int(t.stretch_mode) in [2, 3]:
					画 = 原
				elif int(t.stretch_mode) == 6 and c.size.x > 0.0 and 原.x > 0.0:
					画 = 原 * maxf(c.size.x / 原.x, c.size.y / 原.y)
				if 画.x > c.size.x + 0.6 or 画.y > c.size.y + 0.6:
					出.append("%s 画%.0fx%.0f > 节点%.0fx%.0f（图%.0fx%.0f expand=%d stretch=%d）" % [
						String(c.name), 画.x, 画.y, c.size.x, c.size.y, 原.x, 原.y,
						int(t.expand_mode), int(t.stretch_mode)])
		elif c is TextureButton:
			var 钮 := c as TextureButton
			if 钮.texture_normal == null:
				出.append("%s 没贴图" % String(c.name))
			elif 钮.texture_normal.get_width() > c.size.x + 0.6 or 钮.texture_normal.get_height() > c.size.y + 0.6:
				出.append("%s 图%.0fx%.0f > 钮%.0fx%.0f" % [String(c.name),
					钮.texture_normal.get_width(), 钮.texture_normal.get_height(), c.size.x, c.size.y])
		出.append_array(_扫图标毛病(子, 层 + 1))
	return 出


## ⑬ 的"标签漏字"扫描（报修 4.1 复测时对着原版基线截图抓到的，§3.277）：
## 原版 `TextArea2.htmlText` 吃尖括号 HTML，我们的 `RichTextLabel` 吃方括号 BBCode ⇒
## 只要有一句照抄了 AS3 的 `<b>` / `<font …>` / `<br>`，玩家就会**看见尖括号本身**
## （`富文本._剥所有标签:144-147` 的兜底正则用的同一个口径）。
## ⚠️ 判据取的是**渲染后**的文字：`RichTextLabel.get_parsed_text()` 已经把 `[b]` 这类
##    真 BBCode 解析掉了 ⇒ 正常翻译过的文案不会误报；只有"没被解析、原样画出来"的才算漏。
func _扫标签漏字(节: Node, 层: int) -> Array[String]:
	var 出: Array[String] = []
	if 层 > 40:
		return 出
	var 正则 := RegEx.new()
	正则.compile("<[a-zA-Z/][^>]*>")
	_扫标签漏字进(节, 层, 正则, 出)
	return 出


func _扫标签漏字进(节: Node, 层: int, 正则: RegEx, 出: Array[String]) -> void:
	if 层 > 40:
		return
	for 子 in 节.get_children():
		var c := 子 as Control
		if c == null or not c.visible:
			continue
		var 文 := ""
		if c is RichTextLabel:
			文 = (c as RichTextLabel).get_parsed_text()
		elif c is Label:
			文 = (c as Label).text
		if 文 != "" and 正则.search(文) != null:
			出.append("%s 显示成「%s」" % [String(c.name), 文.replace("\n", "⏎")])
		_扫标签漏字进(子, 层 + 1, 正则, 出)


## ⑪ 的材料格断言（`ItemCaiLiaoBox.as` 逐字对）：`宽` = 45（四符）或 50（残魂）。
## 注意 **position 是相对材料格 Control 的**，几何全按原版 `itemCell.setPosition((宽−40)/2, 20)` 推。
func _验材料格(格: Control, 宽: float, 名文字: String, 叫法: String) -> void:
	if 格 == null:
		_fails.append("⑪ %s：材料格不在场景里" % 叫法)
		return
	var 左 := (宽 - 40.0) * 0.5
	var 名 := 格.get_node_or_null("名") as Label
	_查(名 != null and 名.text == 名文字, "⑪ %s：格名应是「%s」，实得 %s" % [叫法, 名文字, 名.text if 名 != null else "<无>"])
	if 名 != null:
		var 色 := 名.get_theme_color("font_color")
		_查(色.is_equal_approx(Color("#ff9100")),
			"⑪ %s：格名颜色应是 UI_ORANGE #FF9100（`label.color = UIConfig.UI_ORANGE`），实得 %s" % [叫法, 色])
		var 字 := 名.get_theme_font("font")
		_查(字 is FontVariation and is_equal_approx((字 as FontVariation).variation_embolden, 0.8),
			"⑪ %s：格名必须加粗（原版 `label.bold = true` ⇒ FontVariation 0.8），实得 %s" % [叫法, 字])
	var 底 := 格.get_node_or_null("底") as TextureRect
	_查(底 != null and 底.texture != null,
		"⑪ %s：缺 40×40 底图（原版 `SimpleItemCell` 有 `MGrid_background` = 物品格.png）" % 叫法)
	if 底 != null:
		_查(底.position.is_equal_approx(Vector2(左, 20.0)) and 底.size.is_equal_approx(Vector2(40, 40)),
			"⑪ %s：底应 40×40 @(%.1f,20)，实得 %s @ %s" % [叫法, 左, 底.size, 底.position])
	var 图标 := 格.get_node_or_null("图标") as TextureRect
	_查(图标 != null and 图标.position.is_equal_approx(Vector2(左 + 3.0, 23.0))
			and 图标.size.is_equal_approx(Vector2(34, 34)),
		"⑪ %s：图标应 34×34 @(%.1f,23)（`round((40−34)/2)=3`），实得 %s @ %s" % [
			叫法, 左 + 3.0, 图标.size if 图标 != null else Vector2(-1, -1),
			图标.position if 图标 != null else Vector2(-1, -1)])
	var 数 := 格.get_node_or_null("数量") as Label
	_查(数 != null and 数.position.is_equal_approx(Vector2(左, 40.0))
			and 数.size.is_equal_approx(Vector2(40, 20))
			and 数.vertical_alignment == VERTICAL_ALIGNMENT_TOP,
		"⑪ %s：数量字应是格内 40×20 底边右对齐（`countLabel.setPosition(0,20)` 顶对齐），实得 %s @ %s" % [
			叫法, 数.size if 数 != null else Vector2(-1, -1),
			数.position if 数 != null else Vector2(-1, -1)])
	var 购买钮 := 格.get_node_or_null("购买") as Button
	_查(购买钮 != null, "⑪ %s：缺「购买」钮（`buyBtn = new MXWButton()`，残魂格也有）" % 叫法)
	if 购买钮 != null:
		_查(购买钮.size.is_equal_approx(Vector2(37, 22)),
			"⑪ %s：购买钮应 37×22（`btn_width_two`），实得 %s" % [叫法, 购买钮.size])
		_查(购买钮.position.is_equal_approx(Vector2((宽 - 37.0) * 0.5, 63.0)),
			"⑪ %s：购买钮应 @(%.1f,63)（`itemCell.y + 40 + 3`），实得 %s" % [
				叫法, (宽 - 37.0) * 0.5, 购买钮.position])


## ⚠️ `原宠` 必须标 `Array[Dictionary]`：`pets` 是 `Array[Dictionary]`，用普通 `Array` 接
##    再赋回去会 `Invalid assignment`（**报错不中断**）⇒ 假宠留在会话里，还会被下一次落盘写进玩档。
func _收尾(窗口, 会话, 原宠: Array[Dictionary], 原容量: int, 原属性: Dictionary) -> void:
	会话.pets = 原宠
	会话.pet_capacity = 原容量
	会话.player_stats = 原属性
	if is_instance_valid(窗口):
		窗口.queue_free()


func _宠(会话, id: String) -> Dictionary:
	for 只 in 会话.pets:
		if String(只.get("id", "")) == id:
			return 只
	return {}


func _造三只() -> Array[Dictionary]:
	return [
		{"id": "1", "unique_id": 1, "item_id": 101, "name": "小忍犬", "level": 12,
			"aptitude": 1, "savvy": 10, "experience": 0, "face": 0,
			"potential_real_atk": 100, "potential_real_def": 100,
			"potential_real_dex": 100, "potential_real_str": 100,
			"potential_total_atk": 120, "potential_total_def": 120,
			"potential_total_dex": 120, "potential_total_str": 120,
			# 留一条已学技能：悟性页「当前技能」首格才有图标节点可量（空格只画底图）
			"equipment": [], "skills": [{"id": 125, "level": 1}],
			"attached": false, "deployed": false},
		{"id": "2", "unique_id": 2, "item_id": 101, "name": "附身中", "level": 12,
			"aptitude": 1, "savvy": 10, "experience": 0, "face": 0,
			"equipment": [], "skills": [], "attached": true, "deployed": false},
		{"id": "3", "unique_id": 3, "item_id": 101, "name": "出战中", "level": 12,
			"aptitude": 1, "savvy": 10, "experience": 0, "face": 0,
			"equipment": [], "skills": [], "attached": false, "deployed": true},
	]


func _找节点(根: Node, 名字: String) -> Node:
	if 根 == null:
		return null
	for 子 in 根.get_children():
		if String(子.name) == 名字:
			return 子
		var 深 := _找节点(子, 名字)
		if 深 != null:
			return 深
	return null


func _找按钮(根: Node, 名字: String) -> Button:
	return _找节点(根, 名字) as Button


func _找标签(根: Node, 名字: String) -> Label:
	if 根 == null:
		return null
	for 子 in 根.get_children():
		if 子 is Label and String(子.name) == 名字:
			return 子 as Label
		var 深 := _找标签(子, 名字)
		if 深 != null:
			return 深
	return null


func _查(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
