extends SceneTree

## 家族页回归（headless）：主窗 617×390 与列表窗 620×370 的**矩形 + 状态**断言。
## 与 `开发工具/截家族页.gd`、`截家族列表窗.gd` 同一批期望值，但不开窗、不截图
## （截图留给那两道量具喂像素门）。真值：`game-client/真值/窗口/家族.md` §1、§2.1。
## 用法：Godot --path . --headless --script res://测试/家族页回归测试.gd

const 容差 := 1
const 填充 := preload("res://脚本/界面/窗口/家族/家族旗帜填充.gd")
const 令牌 := preload("res://脚本/界面/窗口/家族/家族令牌填充.gd")
const 贡献 := preload("res://脚本/界面/窗口/家族/家族贡献填充.gd")
const 列表 := preload("res://脚本/界面/窗口/家族/家族列表填充.gd")
const 成员 := preload("res://脚本/界面/窗口/家族/家族成员填充.gd")
const 升级 := preload("res://脚本/界面/窗口/家族/家族升级填充.gd")
const 壳 := preload("res://脚本/界面/窗口/家族/家族子窗壳.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 主窗件 := {
	"家徽区": ["家徽区", [5, 5, 210, 142]],
	"公告区": ["公告区", [216, 19, 380, 127]],
	"信息区": ["信息区", [5, 167, 210, 149]],
	"成员区": ["成员区", [216, 167, 380, 149]],
	"公告端帽左": ["公告区/端帽左", [246, 5, 27, 22]],
	"公告文本": ["公告区/公告", [216, 19, 380, 137]],
	"修改钮": ["公告区/修改钮", [554, 118, 37, 22]],
	"家徽格": ["家徽区/家徽格", [23, 81, 40, 40]],
	"成员表头": ["成员区/表头", [224, 172, 364, 20]],
	"表头横线": ["成员区/表头横线", [224, 192, 364, 2]],
	"成员列表": ["成员区/列表窗口", [224, 194, 349, 116]],
	"成员滚动条": ["成员区/滚动条", [573, 194, 15, 116]],
}
const 主窗钮 := ["家族列表", "家族升级", "家族技能", "家族尾兽", "家族旗帜", "家族贡献", "家族商店", "成员信息"]
const 列表件 := {
	"列表盒": ["列表盒", [5, 5, 594, 267]],
	"表头": ["表头", [10, 8, 584, 20]],
	"表头横线": ["表头横线", [10, 30, 584, 2]],
	"列表窗口": ["列表窗口", [10, 34, 569, 235]],
	"滚动条": ["滚动条", [579, 34, 15, 235]],
	"每页": ["每页", [20, 275, 28, 20]],
	"页下拉": ["页下拉", [50, 275, 60, 21]],
	"显示": ["显示", [130, 275, 28, 20]],
	"家主下拉": ["家主下拉", [160, 275, 90, 21]],
	"自动同意": ["自动同意", [255, 276, 345, 19]],
	"创建家族": ["创建家族", [142, 305, 61, 22]],
	"分页": ["分页", [248, 307, 124, 18]],
	"申请加入": ["申请加入", [417, 305, 61, 22]],
}

var _红 := 0
var _宿主: Node

func _initialize() -> void:
	root.size = Vector2i(960, 560)
	_宿主 = Node.new()
	_宿主.name = "假宿主"
	_宿主.set_script(load("res://测试/假家族宿主.gd"))
	root.add_child(_宿主)
	_跑场景("res://场景/界面/窗口/家族/家族窗口.tscn", 主窗件, true)
	_跑场景("res://场景/界面/窗口/家族/家族列表窗.tscn", 列表件, false)


## ⚠️ 旗帜窗那一段**必须等第一帧**：`_initialize` 跑的时候 `root` 自己还没进树，
## 挂在它下面的节点 `is_inside_tree()` 是 false —— 那时 `宿主.get_node_or_null("/root/X")`
## 会报 "Can't use get_node() with absolute paths from outside the active scene tree"。
## （老那两段只用相对路径，所以从没碰到这条。）
## 族徽**永久条**（原版 `UIMain2.addFamilyFlagBuff` 那条路：只要在族就有、**不要求站在旗图**）
## + 离线属性公式里的族徽速率（服务端口径：各百分比先求和、再一次性乘）。
## ⚠️ 这里动的是 `/root/GameSession` 单例的 guild/player_stats/hud_state（**纯内存**，
##    不落盘），收尾一律还原 —— 同帧后面还有别的验函数，脏数据会串。
func _验族徽永久条() -> void:
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 == null:
		_红记("拿不到 /root/GameSession")
		return
	var 旧族: Dictionary = 会话.get("guild")
	var 旧属性: Dictionary = 会话.get("player_stats")
	var 旧状: Dictionary = 会话.get("hud_state")
	var 旧权威 := bool(会话.get("backend_authoritative"))
	# ⚠️ 单例启动时会读 `user://` 存档 ⇒ equipped_items / learned_skills / pets 可能非空
	#    （实测带着 200 点被动攻击），离线公式的期望值会被它们污染。
	#    ⚠️⚠️ 不能 `set("learned_skills", [])` —— 它们是 **`Array[Dictionary]`**，
	#    `set` 走 Variant 通道、对类型化成员静默不生效（第一版就这么假绿/假红）；
	#    要拿引用 `.clear()`（Array/Dictionary 是引用类型），还原也只能逐条塞回去。
	var 旧装备: Dictionary = (会话.get("equipped_items") as Dictionary).duplicate(true)
	var 旧技能: Array = (会话.get("learned_skills") as Array).duplicate(true)
	var 旧宠物: Array = (会话.get("pets") as Array).duplicate(true)
	(会话.get("learned_skills") as Array).clear()
	(会话.get("pets") as Array).clear()
	(会话.get("equipped_items") as Dictionary).clear()
	# ① 未入族 ⇒ 没有永久条
	会话.set("guild", {"joined": false})
	var 空条: Dictionary = 会话.call("族徽永久条目")
	_断(空条.is_empty(), "未入族不该有永久族徽条")
	# ② 在族 ⇒ 有；名字=家族名、文案=加成、图标走素材库、有效期 31536000
	会话.set("guild", {"joined": true, "id": 22, "level": 3, "name": "木叶", "flag_style": 1002})
	var 条: Dictionary = 会话.call("族徽永久条目")
	_断(not 条.is_empty(), "在族 3 级该有永久族徽条")
	if not 条.is_empty():
		_断(String(条.get("name", "")) == "木叶", "永久条名字该是家族名（addFamilyFlagBuff 的 param1.name）")
		_断(bool(条.get("family_permanent", false)), "永久条要带 family_permanent 标记（原版 TYPE_FAMILY/skillId=0）")
		_断(int(条.get("remain_time", 0)) == 31536000, "永久条有效期照原版 60*60*24*365")
		_断(String(条.get("desc", "")).contains("3级家徽属性加成"), "永久条文案该是 getJiaHuiJiaChengString")
		var 纹 := String(条.get("icon", ""))
		_断(纹.ends_with("家徽_1002.png"), "永久条图标该是素材库的家徽_1002.png，实为 %s" % 纹)
		_断(ResourceLoader.exists(纹), "永久条图标文件要真实存在")
	# ③ 样式 0（没有对应图）⇒ 宁可不显示
	会话.set("guild", {"joined": true, "id": 22, "level": 3, "name": "木叶", "flag_style": 0})
	_断((会话.call("族徽永久条目") as Dictionary).is_empty(), "样式 0 没图就不显示（宁可不画）")
	# ④ 离线属性公式：flag[3].attr = maxhp 4 / atk 3 / def 3（百分比），
	#    口径照服务端"先求和再一次乘"⇒ 200→208、40→41、25→26（roundi）。
	会话.set("guild", {"joined": true, "id": 22, "level": 3, "name": "木叶", "flag_style": 1002})
	会话.set("backend_authoritative", false)
	会话.set("player_stats", {"ap_phy": 10, "ap_atk": 10, "ap_def": 10, "hp": 99999, "mp": 1})
	会话.call("_recalculate_stats", false)
	var 出: Dictionary = 会话.get("player_stats")
	_断(int(出.get("max_hp", 0)) == 208, "在族离线 max_hp 该含 4%% 族徽加成（200→208），实 %d" % int(出.get("max_hp", 0)))
	_断(int(出.get("attack", 0)) == 41, "在族离线 attack 该含 3%% 族徽加成（40→41），实 %d" % int(出.get("attack", 0)))
	_断(int(出.get("defense", 0)) == 26, "在族离线 defense 该含 3%% 族徽加成（25→26），实 %d" % int(出.get("defense", 0)))
	# ⑤ 退族 ⇒ 离线公式回裸值
	会话.set("guild", {"joined": false})
	会话.call("_recalculate_stats", false)
	var 无: Dictionary = 会话.get("player_stats")
	_断(int(无.get("max_hp", 0)) == 200, "未入族离线 max_hp 该是裸值 200，实 %d" % int(无.get("max_hp", 0)))
	_断(int(无.get("attack", 0)) == 40, "未入族离线 attack 该是裸值 40，实 %d" % int(无.get("attack", 0)))
	# ⑥ 增益显示里要并列出现永久条（与站旗图那条互不覆盖）
	会话.set("guild", {"joined": true, "id": 22, "level": 3, "name": "木叶", "flag_style": 1002})
	会话.call("刷新增益显示")
	var 增: Array = (会话.get("hud_state") as Dictionary).get("buffs", []) as Array
	var 见永久 := false
	for v in 增:
		var b: Dictionary = v as Dictionary
		if bool(b.get("family_permanent", false)):
			见永久 = true
	_断(见永久, "刷新增益显示后 hud_state.buffs 里要带永久族徽条")
	# ⑦ HUD 悬停：族徽条要显示 desc（原版 BuffCell 的 tooltip = {title:name, desc:desc}）
	var 面板: CanvasLayer = load("res://场景/界面/头像面板.tscn").instantiate()
	# 10-25 起一格 = 格底 + 图标 + 扇形（`BuffCell.as:234-292`）⇒ 夹具也要有那两层，
	# 图标贴到「图标」子节点上，格自己的 `texture` 是格底。
	var 格 := TextureRect.new()
	var 格图 := TextureRect.new()
	格图.name = "图标"
	格.add_child(格图)
	var 格扇 := ColorRect.new()
	格扇.name = "扇形"
	格.add_child(格扇)
	面板.set("_status_slots", [格] as Array[TextureRect])
	面板.call("_render_status_effects", -1, [条], [])
	# 提示框改成原版 `MToolTipTextWithTitle` 之后，悬停文案存在 `_状态提示[格]` 里
	# （`title`/`desc`），由 `_显示状态提示` 送进组件；不再写原生 `tooltip_text`。
	var 条示: Dictionary = (面板.get("_状态提示") as Array)[0] as Dictionary
	# ⚠️ 文案是"家徽"不是"族徽"（`getJiaHuiJiaChengString` = "…级**家徽**属性加成…"）。
	_断(String(条示.get("desc", "")).contains("家徽属性加成"),
			"族徽条悬停要显示加成文案，实为 %s" % 条示.get("desc", ""))
	_断(格图.texture != null, "族徽条图标要贴到「图标」层上")
	面板.free()
	# 收尾：还原单例（内存态），别让脏数据串到同帧后面的验函数
	会话.set("guild", 旧族)
	会话.set("player_stats", 旧属性)
	会话.set("hud_state", 旧状)
	会话.set("backend_authoritative", 旧权威)
	# 还原：清空是把原对象掏空了，只能把旧内容逐条塞回去（引用语义，没有"换回旧对象"这条路）。
	var 现装备 := 会话.get("equipped_items") as Dictionary
	for 键 in 旧装备:
		现装备[键] = 旧装备[键]
	var 现技能 := 会话.get("learned_skills") as Array
	for v in 旧技能:
		现技能.append(v)
	var 现宠物 := 会话.get("pets") as Array
	for v in 旧宠物:
		现宠物.append(v)

## 本地玩家头顶的**家族标示**：`[家族]<族名>` 名牌 + 18×18 族徽。
## 真值 `Character.setBangHuiFlagStyle`（`Character.as:1436-1454`）与 `updateBangHuiName`（:2667）。
## ⚠️ `地图实体` **不 add_child**（不进树、不跑 `_ready`），手动喂 `_player`/`_session`
##    再直接调 `_刷家族标示` —— 要测的就是那个纯函数本身（帧末派发那条只置标志，见下）。
func _验家族标示() -> void:
	var 实体: Node = (load("res://脚本/地图/地图实体.gd") as GDScript).new()
	var 玩家 := Node2D.new()
	实体.set("_player", 玩家)
	var 会话 := root.get_node_or_null("GameSession")
	实体.set("_session", 会话)
	var 旧族: Dictionary = (会话 as Node).get("guild")
	var 名牌 := Label.new()
	名牌.name = "Nameplate"
	名牌.size = Vector2(160.0, 18.0)
	名牌.position = Vector2(-80.0, 1.0)
	玩家.add_child(名牌)
	# ① 在族 ⇒ 名牌 + 族徽都出来
	(会话 as Node).set("guild", {"joined": true, "name": "木叶", "flag_style": 1002, "level": 3})
	实体.call("_刷家族标示")
	var 牌 := 玩家.get_node_or_null("NameplateFamily") as Label
	_断(牌 != null, "在族要建 NameplateFamily 名牌")
	if 牌 != null:
		_断(牌.text == "[家族]木叶", "家族牌文案该是 [家族]+族名，实 %s" % 牌.text)
		_断(牌.visible, "有名有族时家族牌要可见")
		# ⚠️ 颜色是 `add_theme_color_override` 设的，读要经 `get_theme_color`（Label 没有 font_color 属性）
		_断(牌.get_theme_color("font_color") == Color(0x3D / 255.0, 0xF0 / 255.0, 0xF7 / 255.0),
			"家族牌颜色该是 RoleNamePane(4059383)=#3DF0F7，实 %s" % str(牌.get_theme_color("font_color")))
	var 徽 := 玩家.get_node_or_null("FamilyEmblem") as Sprite2D
	_断(徽 != null, "在族要建 FamilyEmblem 族徽")
	# 族徽块的锚点真值（`Character.as:706-718 / 1501-1505`）：**居中在角色身上**
	# （`_statusIconPane.x = -10*数量` ⇒ 单个块 20 宽落 -10）+ `y` 取家族牌**原点**
	# ⇒ 家徽 = 块 + (1,1) = (-9, 牌.y + 行高 + **4** + 1)。
	# ⚠ 那个 4 是"上一行墨迹底 → 牌原点"的净缝（`RoleNamePane.as:122/134/171/182`：
	# `paneHeight = textHeight + 10`、`_tf.y = _bg.y + 4`、TextField 自带 2px 内缩 ⇒ 10 − 6 = 4），
	# **手抄字面量**钉在这儿：用户 2026-10-22 报修 8「家族名称文字与下方徽章/境界图标略微重叠」
	# 就是移植时把"原点"当成了"墨迹底"、缝写成 0（像素实测缝 = 0）。
	var 行高 := 牌.get_theme_font("font").get_height(牌.get_theme_font_size("font_size"))
	var 名字行高 := 名牌.get_theme_font("font").get_height(名牌.get_theme_font_size("font_size"))
	_断(absf(牌.position.y - (名牌.position.y + 名字行高 + 4.0)) < 0.01,
		"家族牌该落在名字行墨迹底 + 4px 缝（`Character.as:1486` 的 `paneHeight - 6`），实 y=%f" % 牌.position.y)
	if 徽 != null:
		_断(徽.texture != null and String(徽.texture.resource_path).ends_with("家徽_1002.png"),
			"族徽该用素材库的家徽_1002.png，实 %s" % (徽.texture.resource_path if 徽.texture else "<空>"))
		_断(absf(徽.scale.x - 18.0 / 34.0) < 0.01, "族徽该缩到 18/34，实 %f" % 徽.scale.x)
		_断(absf(徽.position.x - (-10.0 + 1.0)) < 0.01,
			"族徽 x 该**居中在角色身上**（块宽 20/2 再内缩 1 = -9，不是贴名牌左沿），实 %f" % 徽.position.x)
		_断(absf(徽.position.y - (牌.position.y + 行高 + 4.0 + 1.0)) < 0.01,
			"族徽 y 该落在家族牌墨迹底**下面留 4px 缝**（牌 y + 行高 + 缝 4 + 内缩 1），实 %f" % 徽.position.y)
	# 底框（`Effect_CharStatus_Kuang` 20×20，`Character.as:1449`）：框套在族徽外圈（家徽内缩 1px）
	var 框 := 玩家.get_node_or_null("FamilyEmblemFrame") as Sprite2D
	_断(框 != null, "在族要建 FamilyEmblemFrame 族徽底框（`Effect_CharStatus_Kuang`）")
	if 框 != null and 徽 != null:
		_断(框.texture != null and String(框.texture.resource_path).ends_with("族徽底框.png"),
			"底框该用素材库的 族徽底框.png，实 %s" % (框.texture.resource_path if 框.texture else "<空>"))
		_断(absf(框.position.x - (-10.0)) < 0.01 and absf(框.position.y - (牌.position.y + 行高 + 4.0)) < 0.01,
			"底框位该是块的左上角（x=-10 居中、y=家族牌墨迹底 + 4px 缝），实 %s" % str(框.position))
		_断(absf(框.position.x - (徽.position.x - 1.0)) < 0.01 and absf(框.position.y - (徽.position.y - 1.0)) < 0.01,
			"底框位该是族徽位 −(1,1)，实 %s vs 族徽 %s" % [str(框.position), str(徽.position)])
		_断(框.get_index() < 徽.get_index(), "底框要排在族徽前面（同级按树序绘制，先加的在下层）")
	# ①b **样式 A→B**（家族升级换族旗样式，`1552:4` 广播进来就是这条路）——
	#     用户报修 11「家族升级后，人物下方的家族徽章图标位置不对」的根就在这条腿上，
	#     而旧门**从没测过它**（只测了退族 / 样式 0 两条收掉路）：
	#     旧写法 `徽.queue_free()` + 当帧新建同名节点。三件事实测在 `开发工具/_probe_同名让位.gd`：
	#       ① `queue_free()` **帧末**才真摘树 ⇒ 当帧旧件还挂着、还顶着 `FamilyEmblem` 这个名字；
	#       ② 于是新建那枚撞名，引擎给它的是**匿名名 `@Sprite2D@<序号>`**（⚠ **不是** `FamilyEmblem2`，
	#          照 `FamilyEmblem2` 钉的判据实测一条不红，猜不得）；
	#       ③ 同帧后面跑的 `_排状态图标排`（按**节点名**找块）**摆的是那枚将释放的旧件** ⇒ 留下那枚停在
	#          `(0,0)`（角色脚下）；再下一帧旧件真摘 ⇒ 按名字读到 `null`，下次换样式**又新建一枚**，
	#          那枚匿名的没人摆位、也没人释放 ⇒ **每升一级漏一枚族徽在脚下**（漏 + 位置错两个症状同源）。
	#     原版不犯这病：`Character.as:690-716` 握的是**引用**、还按固定优先级 `setChildIndex`。
	# ⚠ 位置那几条判据（上面 ①）在变异态下**照样绿** —— 它们读的是被名字找到的旧件
	#    （§3.250"相对判据自洽 ≠ 位置对"的同族盲区）。只有"在役 + 同名 + 不冒匿名件"咬得住这个根。
	if 徽 != null:
		var 徽前 := 徽.get_instance_id()
		(会话 as Node).set("guild", {"joined": true, "name": "木叶", "flag_style": 1003, "level": 4})
		实体.call("_刷家族标示")
		var 匿名: Array[String] = []
		for 子 in 玩家.get_children():
			var 名 := String(子.name)
			if 子 is Sprite2D and not 子.is_queued_for_deletion() and 名.begins_with("@"):
				匿名.append(名)
		_断(匿名.is_empty(),
			"①b 换样式后头顶不许冒出**匿名活节点** %s：新建那枚与将释放的旧件撞名、被引擎改名让位 "
			% str(匿名) + "⇒ 按名字找块的代码再也找不到它，它停在 (0,0) 且从此没人释放")
		var 徽B := 玩家.get_node_or_null("FamilyEmblem") as Sprite2D
		_断(徽B != null, "①b 样式 A→B 之后还得读得到一枚 FamilyEmblem（不许把徽弄丢）")
		_断(徽B != null and not 徽B.is_queued_for_deletion(),
			"①b 按名字读到的那枚该是**在役**的（读到待释放的旧件 = 走了「释放再新建」那条路）")
		if 徽B != null:
			_断(徽B.get_instance_id() == 徽前,
				"①b 样式变了该**同一枚节点换贴图**（实得换了节点 id %d → %d）" % [徽前, 徽B.get_instance_id()])
			_断(徽B.texture != null and String(徽B.texture.resource_path).ends_with("家徽_1003.png"),
				"①b 贴图该换成 家徽_1003.png，实 %s"
				% (徽B.texture.resource_path if 徽B.texture else "<空>"))
			_断(absf(徽B.position.x - (-10.0 + 1.0)) < 0.01
				and absf(徽B.position.y - (牌.position.y + 行高 + 4.0 + 1.0)) < 0.01,
				"①b 换样式之后徽仍在同一格（**不许跳到 (0,0)**），实 %s" % str(徽B.position))
			var 框B := 玩家.get_node_or_null("FamilyEmblemFrame") as Sprite2D
			_断(框B != null and 框B.get_index() < 徽B.get_index(),
				"①b 换样式之后底框仍要排在徽前面")
			(会话 as Node).set("guild", {"joined": true, "name": "木叶", "flag_style": 1002, "level": 3})
			实体.call("_刷家族标示")
	# ② 退族 ⇒ 家族牌收起、族徽收掉
	(会话 as Node).set("guild", {"joined": false})
	实体.call("_刷家族标示")
	var 牌2 := 玩家.get_node_or_null("NameplateFamily") as Label
	_断(牌2 != null and not 牌2.visible, "退族后家族牌要收起")
	var 徽2 := 玩家.get_node_or_null("FamilyEmblem")
	_断(徽2 != null and (徽2 as Node).is_queued_for_deletion(), "退族后族徽要收掉")
	var 框2 := 玩家.get_node_or_null("FamilyEmblemFrame")
	_断(框2 != null and (框2 as Node).is_queued_for_deletion(), "退族后族徽底框要一起收掉")
	# ③ 样式 0（没有对应的图）⇒ 族徽宁可不画，家族牌照旧
	(会话 as Node).set("guild", {"joined": true, "name": "木叶", "flag_style": 0})
	实体.call("_刷家族标示")
	var 徽3 := 玩家.get_node_or_null("FamilyEmblem")
	_断(徽3 != null and (徽3 as Node).is_queued_for_deletion(), "样式 0 没图就该收掉族徽")
	var 框3 := 玩家.get_node_or_null("FamilyEmblemFrame")
	_断(框3 != null and (框3 as Node).is_queued_for_deletion(), "样式 0 没图时底框也要一起收掉（别留一圈空框）")
	var 牌3 := 玩家.get_node_or_null("NameplateFamily") as Label
	_断(牌3 != null and 牌3.visible and 牌3.text == "[家族]木叶", "没图也不该连家族牌一起收")
	# ④ 广播只置标志（真正读取在帧末，防拿到旧值）
	实体.call("_on_guild_state_received", {})
	_断(bool(实体.get("_家族标示待刷")), "guild_state_received 该把家族标示标记为待刷")
	# 收尾还原
	(会话 as Node).set("guild", 旧族)
	玩家.free()
	实体.free()

func _process(_d: float) -> bool:
	_验旗帜窗势力()
	_验令牌窗()
	_验成员窗列位()
	_验贡献窗()
	_验族徽永久条()
	_验家族标示()
	_验升级入口族长门()
	_验升级窗()
	print("家族页回归：%s" % ("通过" if _红 == 0 else "%d 条不符" % _红))
	quit(0 if _红 == 0 else 1)
	return true


## 升级入口的族长门（`FW.as:417-419`）：`isManager && _isMyFamilly` 才放权，
## `isManager` 真值 `FM.as:455-462`（角色 id 比 `leaderId`）。
## ⚠️ 动的是 `/root/BackendConnection.character_id`（纯内存，收尾还原）。
func _验升级入口族长门() -> void:
	var 后端 := root.get_node_or_null("BackendConnection")
	if 后端 == null:
		_红记("缺 BackendConnection 单例（族长门要设 character_id）")
		return
	var 旧id := int(后端.get("character_id"))
	var 场 := (load("res://场景/界面/窗口/家族/家族窗口.tscn") as PackedScene).instantiate() as Control
	root.add_child(场)
	场.call("装配", _宿主)
	后端.set("character_id", 4242)
	场.call("刷新", {"joined": true, "level": 2, "leader_id": 4242})
	_断(not (场.get_node("家族升级") as TextureButton).disabled, "族长本人 升级钮放权（FW:417-419）")
	场.call("刷新", {"joined": true, "level": 2, "leader_id": 9999})
	_断((场.get_node("家族升级") as TextureButton).disabled, "leader_id 不符 升级钮禁用")
	# 族长 id 拿不到时的兜底：比名字（`会话.guild.leader` 对 `player_stats.name`）
	场.call("刷新", {"joined": true, "level": 2, "leader": "瑞树"})
	_断((场.get_node("家族升级") as TextureButton).disabled,
		"没有 leader_id 又对不上名字时仍禁用（兜底不能把人放进来）")
	后端.set("character_id", 旧id)
	场.free()


## 家族升级窗（用户截图那扇）：消耗文案 + 三种禁用态 + 「确定」的路由。
## 真值 `FamillyUpgradeWindow`（FUW.as）：`setData` 拿 `CN.FAMILLY_UPGRADE_WINDOW_DESC_TANPLATE`
## 的 ☆/●/◇/◆/★ 占位符填 money 与四书；`clickOkBtnHandler`（:41-44）点「确定」
## **不直接发协议**，先弹 `FamillyPopUpWindow` 二次确认 ⇒ 落到壳开窗表
## 「家族升级窗:确定」→ 家族确认弹，`功能窗口._show_guild_action` 接棒。
func _验升级窗() -> void:
	var 后端 := root.get_node_or_null("BackendConnection")
	if 后端 == null:
		_红记("缺 BackendConnection 单例（升级窗要喂 authoritative_guild）")
		return
	var 旧族: Dictionary = (后端.get("authoritative_guild") as Dictionary).duplicate(true)
	var 窗 := (load("res://场景/界面/窗口/家族/家族升级窗.tscn") as PackedScene).instantiate() as Control
	root.add_child(窗)
	# ① 经济数据未知（没收到过贡献帧）⇒ 显示 ? 且**不据此禁用**（拿 0 当不够会永久锁死钮）
	后端.set("authoritative_guild", {"joined": true, "id": 7, "level": 2, "name": "木叶"})
	升级.填(窗, _宿主)
	var 文 := 窗.get_node("文本升级说明") as RichTextLabel
	_断(文.text.contains("666"), "消耗要有家族资金 666（服务端 money_cost）")
	for 书 in ["春の书", "夏の书", "秋の书", "冬の书"]:
		_断(文.text.contains(书), "消耗要有 %s（服务端 item_costs 四本）" % 书)
	_断(文.text.contains("家族升级之后家徽也将升级"), "绿字照 CN.FAMILLY_UPGRADE_WINDOW_DESC_TANPLATE")
	# ⚠️ 颜色标签必须是**单 `#`**：模板写 `[color=#%s]`、常量却带 `#` 时会拼成 `[color=##00ff00]`，
	#    而 `Color.html("##00ff00")` 解析失败返**黑色**（实测 (0,0,0,1)）⇒ 数量数字在深色
	#    窗皮上直接消失（2026-10-14 修）。只钉"不含 ##"不够狠，再钉一条正确的绿标签在役。
	_断(not 文.text.contains("[color=##"), "消耗行的颜色标签不能是双 #（会解析成黑色、数字消失）")
	_断(文.text.contains("[color=#00ff00]"), "经济未知时数量用绿标签（足色 00ff00）")
	_断(not (窗.get_node("钮确定") as TextureButton).disabled,
		"经济未知时不该禁用确定（宁放行让服务端拒）")
	# ② 已知且一样都不够 ⇒ 禁用 + 提示去「族贡」捐
	后端.set("authoritative_guild", {"joined": true, "id": 7, "level": 2, "name": "木叶",
		"fund": 0, "materials": {16000023: 0, 16000024: 0, 16000025: 0, 16000026: 0}})
	升级.填(窗, _宿主)
	_断((窗.get_node("钮确定") as TextureButton).disabled, "资金材料都不够时确定禁用")
	_断((窗.get_node("文本升级说明") as RichTextLabel).text.contains("族贡"), "不足时提示去族贡捐献")
	# ③ 都够 ⇒ 可点；点下去只把动作串交回宿主（转确认弹），**不在这里发协议**
	后端.set("authoritative_guild", {"joined": true, "id": 7, "level": 2, "name": "木叶",
		"fund": 666, "materials": {16000023: 1, 16000024: 1, 16000025: 1, 16000026: 1}})
	升级.填(窗, _宿主)
	var 定 := 窗.get_node("钮确定") as TextureButton
	_断(not 定.disabled, "资金材料都够时确定可点")
	# ⚠️ §3.140 起「确定」的点击**不再由填充脚本接**（那条直连会和子窗通用接线重复触发、
	#    把确认弹开一下又关掉）⇒ 这里补跑一次 `装配`，让通用接线（`家族子窗.gd:53`）上场，
	#    再验"点一次只交回一个动作串"。真实游戏里是壳的 `切换` 调装配，顺序一样。
	窗.call("装配", _宿主)
	var 记: Array = _宿主.get("动作")
	var 前 := 记.size()
	定.pressed.emit()
	_断(记.size() == 前 + 1 and String(记[前]) == "家族升级窗:确定",
		"确定钮只交回「家族升级窗:确定」（转确认弹），实 %s" % str(记))
	# ④ 满级 ⇒ 文案照 `getFamillyUpgradeCfg()` 返 null 那支（FUW.as:60-67：占位符抹空、确定置灰）
	后端.set("authoritative_guild", {"joined": true, "id": 7, "level": 10, "name": "木叶"})
	升级.填(窗, _宿主)
	_断((窗.get_node("钮确定") as TextureButton).disabled, "满级时确定禁用（FUW:66）")
	_断((窗.get_node("文本升级说明") as RichTextLabel).text.contains("最高等级"), "满级文案")
	# ⑤ 「确定」的去处：壳开窗表里必须是**无壳的家族确认弹**（FUW:41-44 的二次确认）
	#    ⚠️ `get_script_constant_map()` 是 **Script 资源**的方法，直接写在 `const := preload()`
	#       上会按"脚本自己的类"解析 ⇒ 报 non-static。转一道 `as Script` 即可（同家族开窗门）。
	var 壳脚: Script = 壳
	var 开窗: Dictionary = (壳脚.get_script_constant_map().get("开窗", {}) as Dictionary)
	var 项: Array = 开窗.get("家族升级窗:确定", [])
	_断(项.size() == 3 and String(项[0]) == "家族确认弹" and not bool(项[2]),
		"升级窗的确定要开家族确认弹（FUW:41-44），实 %s" % str(项))
	# ⑥ 宿主 `功能窗口` 那三条口径（行为级要造整扇功能窗口，代价不值 ⇒ 照本工程既有做法
	#    读源码钉字串，同 `功能入口回归测试` 的 StyleBoxFlat/new() 那几条）：
	#    · 确认弹两串文案照 `en_US$message_properties.as`（正文 + 确定钮文字）；
	#    · **底栏裸名「家族升级」绝不发升级请求** —— 以前 `_show_guild_action` 的 match 里
	#      跟着发过一次 `request_guild_upgrade_flag()`：玩家只是想看一眼条件，服务端却已经
	#      收到升级请求（材料够就未经确认直接升、不够就弹一句"资金不足"），2026-10-14 修；
	#    · 满级时**不开窗只弹提示**（FW:302-312 → CN.FAMILLY_WINDOW_JIAZU_LEVEL_MAX）。
	#    ⚠️ 读回来的源码先 **归一行尾**（`\r\n`→`\n`）：本仓库历史上混过 CRLF/LF
	#       （Edit 工具与 Windows 下 python 文本写都会改行尾），不归一则 `坏样` 那类
	#       多行字串会时红时绿，钉不住真值。
	#    ⚠️ 满级那条必须钉**调用形式**（`_通知("…")`）而不是光钉文案 —— 拦截函数上方的
	#       注释里也引用了同一句文案，只钉文案会被注释蒙混成绿灯（反向对照实测）。
	var 窗源 := FileAccess.get_file_as_string("res://脚本/界面/功能窗口.gd").replace("\r\n", "\n")
	_断(窗源.contains("你确定要升级吗？"), "升级确认弹正文照 CN.FAMILLY_UPGRADE_WINDOW_SHENGJI_OK")
	_断(窗源.contains("你确定要升级吗？\", \"升级\""), "确定钮文字照 CN.FAMILLY_UPGRADE_WINDOW_SHENGJI")
	var 坏样 := "\"家族升级\":\n\t\t\t\t_backend.request_guild_upgrade_flag()"
	_断(not 窗源.contains(坏样), "底栏「家族升级」不该直接发升级请求（FW:302-312 只开窗）")
	_断(窗源.contains("_通知(\"你的家族已经升到最高级！\")"),
		"满级时只弹提示不开窗（FW:302-312）")
	#    拦截的**判据**也要钉：只钉 `_通知(...)` 那句的话，把条件改成 `and false`
	#    照样绿灯（R5 反向对照实测）——条件本身才是"满级不开窗"的真值。
	_断(窗源.contains("if action_name == \"家族升级\" and _session != null"),
		"满级拦截先判动作名与会话非空")
	_断(窗源.contains("and int(_session.guild.get(\"level\", 0)) >= GAME_DATA.家族最高等级:"),
		"满级拦截比的是家族等级 ≥ 家族最高等级")
	后端.set("authoritative_guild", 旧族)
	窗.free()

func _跑场景(路: String, 表: Dictionary, 是主窗: bool) -> void:
	var 场: Node = load(路).instantiate()
	if 场 == null:
		_红记("场景加载失败：" + 路)
		return
	场.position = Vector2(8.0, 38.0)
	root.add_child(场)
	场.call("装配", _宿主)
	for 名 in 表:
		var 据: Array = 表[名]
		var 节 := 场.get_node_or_null(String(据[0])) as Control
		if 节 == null:
			_红记("%s 缺节点 %s" % [路, 据[0]])
			continue
		var g := 节.get_global_transform_with_canvas().origin
		var 实 := [int(round(g.x)) - 8, int(round(g.y)) - 38, int(round(节.size.x)), int(round(节.size.y))]
		for i in 4:
			if absi(实[i] - int((据[1] as Array)[i])) > 容差:
				_红记("%s %s 期%s 实%s" % ["主窗" if 是主窗 else "列表窗", 名, 据[1], 实])
				break
	if 是主窗:
		_验主窗(场)
	else:
		_验列表(场)
	场.free()

func _验主窗(场: Control) -> void:
	for i in 主窗钮.size():
		var 钮 := 场.get_node_or_null(主窗钮[i]) as TextureButton
		if 钮 == null:
			_红记("主窗缺底栏钮 " + 主窗钮[i])
			continue
		var 字 := 钮.get_node_or_null("Label") as Label
		if 字 == null or 字.text != 主窗钮[i]:
			_红记("底栏钮 %s 的 Label 文案不对" % 主窗钮[i])
		# ⚠️ 禁用的钮走 `_设三态` 的 **`_灰` 档**（`钮底61_灰.png`）—— 三态皮本来就是
		#    「61 档 + 态后缀」，灰档也是预烘的同一张，别把它当"没用预烘"（技能/升级钮
		#    按原版口径常态禁用，2026-10-14 起这里必须放行灰档）。
		var 皮 := 钮.texture_normal.resource_path
		if not (皮.contains("钮底61.png") or 皮.contains("钮底61_灰.png")):
			_红记("底栏钮 %s 没用预烘 61 档（TextureButton 不能九宫格）" % 主窗钮[i])
	# 技能钮：原版 `FW.as:245` 生来 `enabled = false`，全篇**再没有一处放权**
	# （家族技能实际摆在人物面板技能窗第 4 页）⇒ 恒灰。以前误按"尾兽那样入族放权"
	# 点亮了它，点下去却什么都不做（壳的开窗表里没有「家族技能」这一项）。
	_断((场.get_node("家族技能") as TextureButton).disabled, "技能钮恒禁用（FW:245）")
	_断(not (场.get_node("家族尾兽") as TextureButton).disabled, "在族时 尾兽 可点（FW:412）")
	场.call("刷新", {"joined": false})
	_断((场.get_node("家族尾兽") as TextureButton).disabled, "不在族时 尾兽 禁用（FW:412）")
	# 家族商店：原版 `FW.as:413-416` 的 `famillyLevel < 2 ⇒ _famillyShopBtn.enabled = false`
	# —— 1 级族灰着、升到 2 级才亮。这正是"家族升级后会变"的一处 UI 联动。
	场.call("刷新", {"joined": true, "level": 1})
	_断((场.get_node("家族商店") as TextureButton).disabled, "1 级族 商店钮禁用（FW:413-416）")
	场.call("刷新", {"joined": true, "level": 2})
	_断(not (场.get_node("家族商店") as TextureButton).disabled, "升到 2 级 商店钮放权（FW:413-416）")
	# 升级钮 = 只有族长（FW:417-419，isManager 真值 FM:455-462 比角色 id）。
	# 这里没给 leader_id 也没给角色 id ⇒ 非族长 ⇒ 禁用（族长的正例在 `_验升级入口族长门`）。
	场.call("刷新", {"joined": true, "level": 2})
	_断((场.get_node("家族升级") as TextureButton).disabled, "非族长 升级钮禁用（FW:417-419）")
	场.call("刷新", {"joined": true, "level": 3})
	_断((场.get_node("家徽区/家徽格/底色") as ColorRect).color == Color(0x1E / 255.0, 0x90 / 255.0, 1.0),
		"3 级家徽底色 = 0x1E90FF（FW:130-145）")
	_断(not (场.get_node("成员区/滚动条") as Control).visible, "无可滚量不出竖条（AUTO 策略）")

func _验列表(场: Control) -> void:
	_断(bool(场.get("_勾上")), "复选默认勾选（FL:239 selected=true）")
	_断(not (场.get_node("滚动条") as Control).visible, "空列表不出竖条")
	# 输入字段名 = 服务端 `handle_banghui` action 101 那 12 字段的语义名
	# （`后端连接._handle_guild_text` action 3 解出来的键），不是自造的名字 ——
	# 自己编一套键名的话，门全绿也证不了它能吃服务端的真行。
	场.call("刷新", [{"name": "木叶家族", "leader": "瑞树", "members": 1, "capacity": 50,
		"level_sum": 60, "flag_level": 8, "flag_name": "木叶旗帜", "boss_sum": 0, "channel_id": 1,
		"flag_style": 1000}])
	var 行 := 场.get_node("列表窗口/内容列").get_child(0) as Control
	_断(行.name == "行1" and 行.size.y == 23.0, "一行 23 高（FL:199 rowHeight）")
	_断((行.get_node("家族名称") as Label).text == "木叶家族", "族名列填上（renderer 列序）")
	# `FamillyListItemRenderer.as:94`：`flagLevel + CN.COMMON_JI + "  " + flagName`
	# ——「级」后面是**两个**空格（逐字节核过 AS3 原文）。
	_断((行.get_node("家徽等级") as Label).text == "8级  木叶旗帜", "家徽等级列 = 「N级␣␣旗名」")
	_断((行.get_node("族中人数") as Label).text == "1/50", "人数列 = 「n/上限」")
	_断((行.get_node("等级总和") as Label).text == "60", "等级总和列（服务端 parts[8]）")
	_断((行.get_node("本周击杀BOSS数") as Label).text == "0", "本周击杀BOSS列（服务端 parts[9]）")
	# renderer 的链式列位：名 @57、族长 @139（`:41-64` 的 `_loc1_ += 宽 + 2`）
	_断(is_equal_approx((行.get_node("家族名称") as Label).position.x, 57.0), "族名列 x=57")
	_断(is_equal_approx((行.get_node("现任族长") as Label).position.x, 139.0), "族长列 x=139")
	# 行首家徽图（`FamillyListItemRenderer.as:85-89`）：`getJiaHuiPic(flagStyle)` 缩到 20/42、落在 (14,3)
	var 徽 := 行.get_node_or_null("家徽图") as TextureRect
	_断(徽 != null and 徽.texture != null, "行首家徽图有图（flag_style=1000）")
	if 徽 != null:
		_断(is_equal_approx(徽.position.x, 14.0) and is_equal_approx(徽.position.y, 3.0), "家徽图落在 (14,3)")
		_断(is_equal_approx(徽.size.x, 34.0 * 20.0 / 42.0), "家徽图边长 = 34×20/42（`FL:86` 的缩放）")
	# 选中态：`CommonItemRenderer.selected`（`:142-149`）——没点过时底是收着的
	_断(not (行.get_node("选中底") as Control).visible, "未选中时选中底不显示")
	_断((场.call("选中家族") as Dictionary).is_empty(), "没点行时 选中家族() 为空")
	场.call("_选中", 0)
	_断((行.get_node("选中底") as Control).visible, "选中后底显出来")
	_断(int((场.call("选中家族") as Dictionary).get("id", 0)) == 0
		and String((场.call("选中家族") as Dictionary).get("name", "")) == "木叶家族",
		"选中家族() 返回的是**这一行**（按行序取 `_家族表`）")

## 家族旗帜窗的「势力对比」（`FF.as:97-175 drawProgress`）——
## **不是行，是进度显示**：按家族分组数族旗数，前三段各自定宽、各自渐变。
## 数字全是钉死的（364 × 占比），抄错公式会得别的值。
func _验旗帜窗势力() -> void:
	var 后端 := root.get_node_or_null("BackendConnection")
	if 后端 == null:
		_红记("缺 BackendConnection 单例（势力对比要读它的 authoritative_flag_list）")
		return
	# 9 面旗：木叶 5 / 砂隐 3 / 雾隐 1 ⇒ 宽 364×5/9、364×3/9、364×1/9
	var 表: Array[Dictionary] = []
	var 名单 := [["木叶家族", 5, 7], ["砂隐村", 3, 9], ["雾隐村", 1, 12]]
	for 条 in 名单:
		for _i in int(条[1]):
			表.append({"bang_id": int(条[2]), "bang_name": String(条[0])})
	var 旧: Array[Dictionary] = (后端.get("authoritative_flag_list") as Array[Dictionary]).duplicate()
	后端.set("authoritative_flag_list", 表)
	var 场 := (load("res://场景/界面/窗口/家族/家族旗帜窗.tscn") as PackedScene).instantiate() as Control
	root.add_child(场)
	填充.填(场, _宿主)
	_断((场.get_node("标题势力/势力富文本") as RichTextLabel).text
		== "[center][color=#00ff00]1:木叶家族(5面)[/color][color=#ff9119]2:砂隐村(3面)[/color]"
			+ "[color=#ffde19]其它(1面)[/color][/center]",
		"势力三色文本 = 1:首名 / 2:次名 / 其它（`FF:136-138`）")
	_断((场.get_node("标题计数") as Label).text == "9面", "计数 = 总面数（`FF:140`）")
	_断((场.get_node("标签旗数上限") as Label).text == "最大可安插9面旗帜",
		"上限 = 「最大可安插N面旗帜」（`FF:141`）")
	_断((场.get_node("输入旗数") as LineEdit).text == "5面", "本族已安插 = 自己那组的数（`FF:170`）")
	_断((场.get_node("输入家族名") as LineEdit).text == "木叶", "左列家族名（`FF:468`）")
	var 段们 := (场.get_node("区进度条") as Control).get_children()
	_断(段们.size() == 3, "进度条三段（`FF:150,155,159`）")
	if 段们.size() == 3:
		_断(is_equal_approx((段们[0] as Control).size.x, 364.0 * 5.0 / 9.0), "首段宽 = 364×5/9")
		_断(is_equal_approx((段们[1] as Control).size.x, 364.0 * 3.0 / 9.0), "次段宽 = 364×3/9")
		_断(is_equal_approx((段们[2] as Control).size.x, 364.0 * 1.0 / 9.0), "其它段宽 = 364×1/9")
		_断(is_equal_approx((段们[1] as Control).position.x, 364.0 * 5.0 / 9.0), "次段紧接在首段之后")
	场.free()
	后端.set("authoritative_flag_list", 旧)


## 家族令牌窗：判定表来自 `GameData.BangHui.cost.contri`（**不是**"服务端才有"），
## 六格按场景 `格0..5` 的矩形叠可拖拽钮（只接不吐，与原版 `dropItemHandler` 一致）。
func _验令牌窗() -> void:
	var 书 := 游戏数据.family_contribution_books()
	_断(书 == [16000022, 16000023, 16000024, 16000025, 16000026],
		"可捐献的书 = GameData.BangHui.cost.contri 的 5 个 id（现读表）")
	var 场 := (load("res://场景/界面/窗口/家族/家族令牌窗.tscn") as PackedScene).instantiate() as Control
	root.add_child(场)
	令牌.填(场, _宿主)
	for i in 6:
		var 背景 := 场.get_node("格%d" % i) as Control
		var 格 := 场.get_node_or_null("令牌格%d" % i) as Button
		_断(格 != null, "令牌格%d 建出来了" % i)
		if 格 != null:
			_断(格.position == 背景.position and 格.size == 背景.size,
				"令牌格%d 与背景 格%d 同矩形（不另抄坐标）" % [i, i])
			_断(String(格.get("格子归属")) == "家族令牌" and not bool(格.get("可拖拽")),
				"令牌格%d 只接不吐（原版这一格没有起拖端）" % i)
	_断(令牌.收取行(场).is_empty(), "空窗时收取行为空（确定不该发协议）")
	场.free()


## 成员窗 9 列的**行/表头对齐**：`_加一行` 的 x 必须减掉 `列表` 容器的原点（10）——
## 不减就是整行右移 10px、对不上表头（2026-10-14 修；做贡献窗列位时一并量出来的）。
## 表头：`列成员0` @10 宽 70、`列成员8` @550 宽 70；容器 @10。
## 2026-10-15 加验三样（用户截图报"成员管理界面不对"的收口）：
##   ① 行配色照原版 `FamillyMemberItemRender`（名绿/职务按 rank/本周BOSS 红/其余白）；
##   ② ⭐ **贡献填充不得污染成员窗**：`家族子窗壳.切换` 开每扇窗都把七个填充器全跑一遍，
##      `家族贡献填充.填` 原先没按页名挡 ⇒ 贡献榜行灌进成员窗（列全叠 x=-10、按名重排、
##      名染贡献窗的 UI_BLUE）—— 这就是截图里那团叠字的正主；
##   ③ 场景要有 `提示底内容底`（UIWindow 的 contentBg，`UIWindow.as:36-38/62-65`）——
##      没它窗皮+盒底叠完底下主窗还透 ~8%，大面积空列表的成员窗看得一清二楚。
func _验成员窗列位() -> void:
	var 会话 := _宿主.get("_session") as Node
	# 2026-11-08：成员窗行渲染已归 `家族成员填充.gd`（17 字段行）。
	# 这一段只钉列位/配色/不串页，故喂最小 17 字段子集；默认按名字升序 ⇒ alpha 在前。
	会话.set("guild", {"joined": true, "id": 7, "member_list": [
		{"character_id": 1, "name": "alpha", "level": 60, "rank": 1, "job": 300,
			"channel_id": 1, "contriValue": 900, "weekly_contribution": 30},
		{"character_id": 2, "name": "beta", "level": 118, "rank": 2, "job": 300,
			"channel_id": -1, "contriValue": 800}]})
	var 场 := (load("res://场景/界面/窗口/家族/家族成员窗.tscn") as PackedScene).instantiate() as Control
	root.add_child(场)
	场.call("装配", _宿主)
	成员.填(场, _宿主)
	var 行 := (场.get_node("列表") as Control).get_node_or_null("行1") as Control
	_断(行 != null, "成员窗画出一行")
	if 行 != null:
		_断((行.get_node("列0") as Label).text == "alpha", "成员行名字列（默认名字升序）")
		_断(is_equal_approx((行.get_node("列0") as Label).position.x, 0.0),
			"成员行首列 x=0（对齐 列成员0 @10）")
		_断(is_equal_approx((行.get_node("列8") as Label).position.x, 540.0),
			"成员行末列 x=540（对齐 列成员8 @550）")
		_断((行.get_node("列0") as Label).get_theme_color("font_color").is_equal_approx(Color("#00ff00")),
			"成员名列=UI_GREEN（FamillyMemberItemRender:83）")
		_断((行.get_node("列2") as Label).get_theme_color("font_color").is_equal_approx(Color("#a800ff")),
			"成员行职务列照 家族职务.职务色（rank1=族长紫）")
		_断((行.get_node("列7") as Label).get_theme_color("font_color").is_equal_approx(Color("#ff0000")),
			"本周BOSS列=UI_RED（FamillyMemberItemRender:100）")
	var 行2 := (场.get_node("列表") as Control).get_node_or_null("行2") as Control
	_断(行2 != null and (行2.get_node("列0") as Label).get_theme_color("font_color").is_equal_approx(Color("#cccccc")),
		"离线成员名列=#CCCCCC（FamillyMemberItemRender:55）")
	_断(场.get_node_or_null("提示底内容底") != null, "成员窗有内容底（UIWindow contentBg）")
	# ② 贡献填充跑过一遍后，成员窗的行必须原样（页名守卫在役）
	贡献.填(场, _宿主)
	var 行后 := (场.get_node("列表") as Control).get_node_or_null("行1") as Control
	_断(行后 != null and (行后.get_node("列0") as Label).text == "alpha"
		and is_equal_approx((行后.get_node("列0") as Label).position.x, 0.0)
		and (行后.get_node("列0") as Label).get_theme_color("font_color").is_equal_approx(Color("#00ff00")),
		"贡献填充跑过之后成员窗的行原样（不被贡献榜覆盖/重排/染色）")
	# ③ 守卫的源码级钉（行为断言靠的是守卫，源码也得钉着）
	var 贡源 := FileAccess.get_file_as_string("res://脚本/界面/窗口/家族/家族贡献填充.gd").replace("\r\n", "\n")
	_断(贡源.contains("String(页.name) != \"家族贡献窗\""), "贡献填充按页名挡（只填自己这扇）")
	场.free()


## 家族贡献窗（原版 `FamillyGongXianWindow`）：2026-10-14 把这扇**纯 UI** 的窗补上数据层 ——
## 5 格库存 / 族贡金币存量 / 剩余贡值 / 9 列贡献榜 / 分页 / 每页 / 列头排序 / 每页下拉。
## 数据源与线上一致：action 5 的 fields[2]（资金）、fields[3]（材料库存）、
## action 20 的族贡值、11 字段成员行（见 `家族贡献填充.gd` 文件头）。
func _验贡献窗() -> void:
	var 后端 := root.get_node_or_null("BackendConnection")
	if 后端 == null:
		_红记("缺 BackendConnection 单例（贡献窗要读 authoritative_guild）")
		return
	var 旧族: Dictionary = (后端.get("authoritative_guild") as Dictionary).duplicate(true)
	后端.set("authoritative_guild", {"fund": 8888, "materials": {
		16000022: 3, 16000023: 7, 16000024: 0, 16000025: 1, 16000026: 12}})
	var 会话 := _宿主.get("_session") as Node
	会话.set("guild", {"joined": true, "id": 7, "contribution": 456,
		"member_list": _贡献表(12)})
	var 场 := (load("res://场景/界面/窗口/家族/家族贡献窗.tscn") as PackedScene).instantiate() as Control
	root.add_child(场)
	场.call("装配", _宿主)
	贡献.填(场, _宿主)
	var 容器 := 场.get_node("列表") as Control
	var 页码 := 场.get_node("分页分页/页码") as Label
	# ① 族贡金币存量 / 剩余贡值：原版这两个框都是只读（`enableInput = false`）
	var 存量 := 场.get_node("输入存量") as LineEdit
	_断(存量.text == "8888" and not 存量.editable, "族贡金币存量 = 家族资金 8888 且只读（FGW:354,182）")
	var 剩贡 := 场.get_node("输入剩贡") as LineEdit
	_断(剩贡.text == "456" and not 剩贡.editable, "剩余贡值 = 族贡值 456 且只读（FGW:307-310,249）")
	# ② 5 格库存：图标 + 件数（件数为 0 也显示 "0" —— 服务端恒下发全部五种书）
	var 件们 := [3, 7, 0, 1, 12]
	for i in 5:
		var 格 := 场.get_node("格%d" % i) as Control
		var 图 := 格.get_node_or_null("图标") as TextureRect
		var 字 := 格.get_node_or_null("数量") as Label
		_断(图 != null and 图.texture != null, "库存格%d 有图标（FuZhuWuPin 那五种书）" % i)
		_断(字 != null and 字.text == str(件们[i]), "库存格%d 件数 = %d（0 也显示）" % [i, 件们[i]])
	# ③ 贡献榜：默认按名字升序（`FGW:60,316-318`）⇒ 行1 = 玩家00
	_断(容器.get_child_count() == 10, "每页默认 10 条（fenYeSelection[0]）")
	var 行1 := 容器.get_node("行1") as Control
	_断((行1.get_node("列0") as Label).text == "玩家00", "行1 名字列（默认按名字升序）")
	_断((行1.get_node("列1") as Label).text == "30", "等级列")
	_断((行1.get_node("列2") as Label).text == "族长", "职务列走 getRankName（rank 1）")
	_断((行1.get_node("列5") as Label).text == "100", "总贡献列（11 字段行的 parts[9]）")
	_断((行1.get_node("列8") as Label).text == "50", "周贡献列（parts[10]）")
	# 列位对齐表头：行画在 `列表` 容器里，x 要减掉容器原点 13（2026-10-14 修的错位）
	_断(is_equal_approx((行1.get_node("列0") as Label).position.x, 0.0), "行首列 x=0（对齐表头 列贡献0）")
	_断(is_equal_approx((行1.get_node("列8") as Label).position.x, 503.0), "行末列 x=503（对齐表头 列贡献8）")
	# 名字列蓝色（`UIConfig.UI_BLUE` = 2003199 = 0x1E90FF），其余白
	_断((行1.get_node("列0") as Label).get_theme_color("font_color") == Color("#1e90ff"),
		"名字列 = UI_BLUE（renderer 的 createItem 口径）")
	# ④ 分页：12 人两页，四钮禁用态照 `PageComponent` 的口径
	_断(页码.text == "1/2", "12 人分两页")
	_断((场.get_node("分页分页/首页") as TextureButton).disabled, "第 1 页时首页禁用")
	_断((场.get_node("分页分页/上一页") as TextureButton).disabled, "第 1 页时上一页禁用")
	_断(not (场.get_node("分页分页/下一页") as TextureButton).disabled, "第 1 页时下一页可点")
	贡献.翻页(场, _宿主, "末页")
	_断(页码.text == "2/2" and 容器.get_child_count() == 2, "末页 2 条")
	_断((场.get_node("分页分页/末页") as TextureButton).disabled, "末页时末页禁用")
	贡献.翻页(场, _宿主, "下一页")		# 越界钳住（`__onArrowBtnClick` 同口径）
	_断(页码.text == "2/2", "末页再点下一页不越界")
	贡献.翻页(场, _宿主, "首页")
	_断(页码.text == "1/2" and 容器.get_child_count() == 10, "回首页 10 条")
	# ⑤ 列头排序：方向按字段写死（见 `家族贡献填充._排序` 的注释）
	# ⚠️ 每次重排都会**重建行节点**（`_渲染` 先清空再加）⇒ 行1 必须现取，
	#    拿着排序前那个引用读到的是旧行（2026-10-14 第一版就这么假绿过）。
	贡献.排序列(场, _宿主, "总贡献")
	_断((_行1(容器).get_node("列5") as Label).text == "100", "按总贡献降序（DESCENDING）")
	贡献.排序列(场, _宿主, "等级")
	_断((_行1(容器).get_node("列1") as Label).text == "41", "按等级降序 ⇒ 玩家11(41级) 到头")
	贡献.排序列(场, _宿主, "族中职务")
	_断((_行1(容器).get_node("列2") as Label).text == "族长", "按职务升序（sortOn rank，1=族长）")
	贡献.排序列(场, _宿主, "玩家名字")
	_断((_行1(容器).get_node("列0") as Label).text == "玩家00", "按名字升序回默认")
	# 排序三角只亮当前列（`SanJiaoLabel.selected` 的对应物）
	_断((场.get_node("列贡献0/排序三角0") as TextureRect).visible, "默认排序列亮三角")
	_断(not (场.get_node("列贡献1/排序三角1") as TextureRect).visible, "别的列不亮三角")
	# ⑥ 每页条数 + 触发器文字
	贡献.选每页(场, _宿主, 3)
	_断(页码.text == "1/1" and 容器.get_child_count() == 12, "每页 100 项 ⇒ 一页 12 条")
	_断((场.get_node("下拉页/文字") as Label).text == "100项", "触发器文字 = 100项")
	贡献.选每页(场, _宿主, 0)
	_断(页码.text == "1/2", "选回 10 项 ⇒ 两页")
	# ⑦ 「每页」下拉：弹层 / 四项 / 选中即换 / 再点收起
	贡献.弹每页下拉(场, _宿主)
	var 弹层 := 场.get_node_or_null("每页弹层") as Control
	_断(弹层 != null, "下拉弹层建出来了")
	if 弹层 != null:
		var 菜单 := 弹层.get_node_or_null("菜单") as Control
		_断(菜单 != null and 菜单.get_child_count() == 4, "菜单 4 项（10/30/50/100）")
		# 下方放不下就往上开：这一页的锚在 y=309，下面只剩 61px，装不下 4 项
		_断(菜单.position.y < 309.0, "下方放不下 ⇒ 菜单往上开")
		(菜单.get_node("项1") as Button).pressed.emit()		# 选 30 项
		_断((场.get_node("下拉页/文字") as Label).text == "30项", "选中 30 项即换每页")
		_断(场.get_node_or_null("每页弹层") == null, "选完就收起")
	贡献.弹每页下拉(场, _宿主)
	_断(场.get_node_or_null("每页弹层") != null, "再弹一次")
	贡献.弹每页下拉(场, _宿主)
	_断(场.get_node_or_null("每页弹层") == null, "再点一次触发器 = 收起")
	# ⑩ 滚轮：列表区 160px 高 = 6.96 行，每页 10 条 ⇒ 第 7 行往后靠滚轮
	#    （原版 `fl.controls.List` 是滚动容器，本页场景也没有可见滚动条）
	var 轮 := InputEventMouseButton.new()
	轮.button_index = MOUSE_BUTTON_WHEEL_DOWN
	轮.pressed = true
	容器.gui_input.emit(轮)
	_断(is_equal_approx((_行1(容器) as Control).position.y, -12.0), "滚轮往下滚 12px")
	容器.gui_input.emit(轮)
	_断(is_equal_approx((_行1(容器) as Control).position.y, -24.0), "再滚 12px")
	var 轮上 := InputEventMouseButton.new()
	轮上.button_index = MOUSE_BUTTON_WHEEL_UP
	轮上.pressed = true
	容器.gui_input.emit(轮上)
	_断(is_equal_approx((_行1(容器) as Control).position.y, -12.0), "滚轮往上回 12px")
	贡献.翻页(场, _宿主, "末页")		# 换页 ⇒ 偏移归零
	_断(is_equal_approx((_行1(容器) as Control).position.y, 0.0), "换页后滚回顶上")
	贡献.翻页(场, _宿主, "首页")
	# ⑪ 表头打开命中（原版是可点的 `SanJiaoLabel`）+ 分页四钮把动作串交回宿主
	_断((场.get_node("列贡献3") as Label).mouse_filter == Control.MOUSE_FILTER_STOP,
		"表头打开命中区（原版是可点的 SanJiaoLabel）")
	for 钮名 in ["首页", "上一页", "下一页", "末页"]:
		(场.get_node("分页分页/" + 钮名) as TextureButton).pressed.emit()
	_断(_宿主.动作.has("家族贡献窗:首页") and _宿主.动作.has("家族贡献窗:末页"),
		"分页四钮把 `家族贡献窗:<钮名>` 交回宿主（通用家族子窗的 pressed→动作）")
	# ⑨ 空列表态
	会话.set("guild", {"joined": true, "id": 7, "contribution": 0, "member_list": []})
	贡献.填(场, _宿主)
	var 空 := 容器.get_node_or_null("空提示") as Label
	_断(空 != null and 空.text == "暂无贡献记录", "空列表有提示")
	_断(页码.text == "1/1", "空表 1/1 页")
	for 钮名 in ["首页", "上一页", "下一页", "末页"]:
		_断((场.get_node("分页分页/" + 钮名) as TextureButton).disabled, "空表四钮全禁用")
	场.free()
	后端.set("authoritative_guild", 旧族)


## 12 个成员（验分页：每页默认 10 ⇒ 两页）。字段名对齐 action 5 的 11 字段行。
func _贡献表(n: int) -> Array[Dictionary]:
	var 出: Array[Dictionary] = []
	for i in n:
		出.append({
			"character_id": 100 + i, "name": "玩家%02d" % i, "level": 30 + i,
			"rank": 1 if i == 0 else 4, "books": i, "gold": i * 10,
			"week_books": i * 2, "week_gold": i * 20, "line": 1,
			"contribution": 100 - i, "weekly_contribution": 50 - i, "online": true})
	return 出


## 现取当前页第一行（重排/翻页都会重建行，别缓存引用）。
func _行1(容器: Control) -> Control:
	return 容器.get_node_or_null("行1") as Control


func _断(真: bool, 说: String) -> void:
	if not 真:
		_红 += 1
	print("  %s %s" % ["√" if 真 else "!!", 说])

func _红记(说: String) -> void:
	_红 += 1
	print("  !! " + 说)
