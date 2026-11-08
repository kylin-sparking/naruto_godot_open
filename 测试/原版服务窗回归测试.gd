extends SceneTree

## 「原版服务窗」族离线回归门（2026-10-04，木叶村 NPC 批次）。
##
## 覆盖 `数据/界面/原版服务窗_SPEC.json` 里的**每一扇**窗（忍具兑换 / 十拳剑兑换 / …）。
## 口径与工程里其余门一致：**只读磁盘文本**，不 load 场景 ⇒ 无头跑、不写 `user://玩家数据.json`。
##
## 它防的八种复发（1、2、5、7、8 都是 2026-10-04 用户实机抓出来的）：
##   1. **嵌套件把 `parent=` 写成件名** —— `.tscn` 的 `parent=` 是**从场景根算的完整路径**，
##      写错就解析不到、件被静默挂到根 (0,0)（症状：格子里的文字全堆在窗口左上角）。
##   2. **AS3 的 `htmlText` 原样塞进 RichTextLabel** —— `<font color=…>` 被当正文画出来（只认 BBCode）。
##   3. **手改 `.tscn`**：下一次生成会吃掉 ⇒ 沿 parent 链累加逐件比期望表，改一处就红。
##   4. **SPEC 与 `窗口尺寸.json` 不同步**：宽高/标题/整框 对不上 ⇒ 落地页开出来是错的框。
##   5. **三档皮缺一档 / 用 modulate 模拟**：`StyleUtil.as:8-12` 是加性 ±30/−40，乘性替不了；
##      底片还必须是 `MButton_up`(tag18) —— `MButtonF`(tag21) 里烙着作者期的 "Button" 字样。
##   6. **做出一扇没入口的窗 / 指向一扇不存在的窗**：落地页双向钉。
##   7. **格子里少画原版那两层**（2026-10-04 用户第二轮打回）：`showInfo()` 一给 itemData，
##      `SimpleItemCell` 就叠**物品图标**（居中取整）并把 nameField 藏起来，`validateItem()` 再写
##      白色右对齐的**数量**。这两层是运行期画的，但按「编辑器视图 = 运行期」必须烘进场景 ⇒
##      图标路径还要与 `物品图标索引.json` 一致（查无此编号时只许走 原版直解 台账）。
##   8. **说明文案用转述/兜底句**：门直接 contains SPEC 的**逐字真句**（含真换行的转义形式）。
##
## 用法：Godot --headless --path . --script res://测试/原版服务窗回归测试.gd

const SPEC路径 := "res://数据/界面/原版服务窗_SPEC.json"
const 尺寸路径 := "res://数据/界面/窗口尺寸.json"
const NPC表路径 := "res://数据/界面/木叶村NPC.json"
const 皮肤表 := "res://脚本/界面/原版皮肤表.gd"
const 图标索引路径 := "res://数据/物品图标索引.json"
const 容差 := 0.02
# 节点块的正则：`[node name="X" …parent="Y"…]块体`，到下一个 [node 或文末为止
const 重节点 := "(?s)\\[node name=\"([^\"]+)\"[^\\]]*?parent=\"([^\"]*)\"[^\\]]*\\](.*?)(?=\\n\\[node |$)"

## Godot 4 `RichTextLabel` 真认的 BBCode 标记名（写进这个表之外的，标记本身会被当**正文**画出来）。
## 出处：引擎 `scene/gui/rich_text_label.cpp` 的标签解析表；这里只列本工程会用到的那批 + 常见几个。
const 支持标记 := ["b", "i", "u", "s", "color", "bgcolor", "font", "fontname", "font_size",
		"url", "img", "center", "left", "right", "fill", "indent", "dropcap", "p", "lb", "br",
		"code", "hint", "anchor", "table", "cell", "column", "line", "rt", "tobullet",
		"whitespace", "override", "pulse", "wave", "shake", "rainbow", "fade", "tremble",
		"sub", "sup", "overlay", "conceal", "marker"]


## 从一段 BBCode 文本里挑出所有标记名（`[color=#fff]` → `color`、`[/color]` → `color`）。
## 故意不用正则：`[]` 在正则里要转义、而 GDScript 串里的反斜杠又是另一个坑（见 读皮边距 那段注释）。
func 标记名们(文: String) -> Array[String]:
	var 出: Array[String] = []
	var 找 := 0
	while true:
		var 开 := 文.find("[", 找)
		if 开 < 0:
			break
		var 闭 := 文.find("]", 开 + 1)
		if 闭 < 0:
			break
		var 名 := 文.substr(开 + 1, 闭 - 开 - 1)
		for 断 in ["=", " ", "/"]:
			var 位 := 名.find(断)
			if 位 >= 0:
				名 = 名.substr(0, 位)
		名 = 名.strip_edges()
		if not 名.is_empty() and not 出.has(名):
			出.append(名)
		找 = 闭 + 1
	return 出

var 红 := 0
var 日志: Array[String] = []
var SPEC: Dictionary = {}
var 尺寸: Dictionary = {}
var 落地集: Array[String] = []
var 皮边距 := {}
var 图标索引: Dictionary = {}
## 走到"本页最后一件事"的页数 —— 用来抓**门自己中途抛异常**（2026-10-06 实测：
## `String(字典)` 抛错会让那一页后面全不判，而 `红` 仍是 0、退出码仍是 0）。
var 走完 := 0


func _initialize() -> void:
	SPEC = 读JSON(SPEC路径)
	尺寸 = 读JSON(尺寸路径)
	图标索引 = 读JSON(图标索引路径)
	读落地()
	读皮边距()
	for 页 in SPEC:
		验窗(String(页))
	记(走完 == SPEC.size(),
			("每一扇都判到了最后一件（走完 %d / %d 扇）—— 少一扇就是门自己中途抛了异常，"
					+ "后面那一整页等于没判，而 `红` 看不出来") % [走完, SPEC.size()])
	验出处齐全()
	for 一 in 日志:
		print(一)
	print("原版服务窗回归：%s（%d 扇窗，红 %d 项）" % ["通过" if 红 == 0 else "不通过", SPEC.size(), 红])
	quit(1 if 红 > 0 else 0)


func 读文(路径: String) -> String:
	var f := FileAccess.open(路径, FileAccess.READ)
	if f == null:
		记(false, "读不到 %s" % 路径)
		return ""
	return f.get_as_text()


func 读JSON(路径: String) -> Dictionary:
	var 解: Variant = JSON.parse_string(读文(路径))
	if typeof(解) != TYPE_DICTIONARY:
		记(false, "%s 不是字典（读不到/解不开）" % 路径)
		return {}
	return 解


func 记(过: bool, 文本: String) -> void:
	if not 过:
		红 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 文本])


func 取数(段: String, 键: String) -> float:
	for 行 in 段.split("\n"):
		if 行.begins_with(键 + " = "):
			return float(行.substr(键.length() + 3))
	return -99999.0


## 九宫边距**只认运行期真吃得进的那一条**：`NinePatchRect` 认的是 `patch_margin_*`（**int**），
## `texture_margin_*` 是 `TextureRect` / `StyleBoxTexture` 的属性 —— 写在 NinePatchRect 上
## **载入不报错、也不落地**（探针实测 `patch_margin_*` 恒 0 ⇒ 底图整片拉伸、四角从没九宫切过）。
## 2026-10-20 之前这批场景烘的全是 `texture_margin_*`，而这一腿读的也是同一条**死属性** ⇒
## 值跟皮肤表对得上、门照绿，是"门钉在错的名字上"（体检 #51）。
## ⇒ 这边只读 `patch_margin_*`、不留退回：块类型 ↔ 属性名由 场景资源回归测试 钉死。
## 缺这条属性时 `取数` 返回哨兵，下面按"跟皮肤表对不上"报红。
func 九宫边距(段: String) -> Array:
	var out: Array = []
	for 键 in ["left", "right", "top", "bottom"]:
		out.append(取数(段, "patch_margin_" + 键))
	return out


func 编(式: String) -> RegEx:
	var re := RegEx.new()
	if re.compile(式) != OK:
		记(false, "正则编不过：%s" % 式.substr(0, 40))
		return null
	return re


## `.tscn` 的节点名不许带 `/`（那是路径分隔符）⇒ 生成器转成 `_`，这边同一套转换。
func 节点名(名: String) -> String:
	return 名.replace("/", "_")


## 与生成器 `_串()` 同口径：文案里的真换行在 `.tscn` 里是两字符 `\n`，
## 直接拿带真换行的 SPEC 串去 contains 必然不中（忍具那句 desc 就带换行）。
func _串(文: String) -> String:
	return 文.replace("\"", "'").replace("\r\n", "\n").replace("\n", "\\n").replace("\t", "\\t")


## SPEC 的「父」链 → `.tscn` 里的完整节点路径（与生成器同一拼法：根下第一层不带 "./"）。
func 路径of(SPEC件: Array, 件: Dictionary) -> String:
	var 父 := String(件.get("父", "窗"))
	if 父 == "窗":
		return 节点名(String(件["名"]))
	var 母: Variant = null
	for x in SPEC件:
		if String((x as Dictionary)["名"]) == 父:
			母 = x
	if 母 == null:
		return 节点名(String(件["名"]))
	return 路径of(SPEC件, 母) + "/" + 节点名(String(件["名"]))


## 按完整路径取一个 node 块：`name=` 只是本段名、`parent=` 是它上面的路径，两个一起才唯一。
func 取段(文: String, 路径: String) -> String:
	var 斜 := 路径.rfind("/")
	var 本名 := 路径.substr(斜 + 1) if 斜 >= 0 else 路径
	var 父 := "." if 斜 < 0 else 路径.substr(0, 斜)
	var re := 编("(?s)\\[node name=\"" + 本名 + "\"[^\\]]*?parent=\"" + 父 + "\"[^\\]]*\\](.*?)(?=\\n\\[node |$)")
	if re == null:
		return ""
	var m := re.search(文)
	return m.get_string(1) if m != null else ""


## 整张场景走一遍 → {完整路径: 页面绝对矩形}。`offset_*` 是父相对，必须沿 parent 链累加。
func 绝对表(文: String) -> Dictionary:
	var re := 编(重节点)
	if re == null:
		return {}
	var 局部 := {}
	var 父路 := {}
	for m in re.search_all(文):
		var 名 := m.get_string(1)
		var 父 := m.get_string(2)
		var 段 := m.get_string(3)
		var 路 := 名 if 父 == "." else 父 + "/" + 名
		局部[路] = [取数(段, "offset_left"), 取数(段, "offset_top"),
				取数(段, "offset_right"), 取数(段, "offset_bottom")]
		父路[路] = "" if 父 == "." else 父
	var 出 := {}
	for 路 in 局部:
		var x: float = 局部[路][0]
		var y: float = 局部[路][1]
		var 上: String = 父路[路]
		var 步 := 0
		while 上 != "" and 局部.has(上) and 步 < 32:
			x += 局部[上][0]
			y += 局部[上][1]
			上 = 父路[上]
			步 += 1
		出[路] = [x, y, 局部[路][2] - 局部[路][0], 局部[路][3] - 局部[路][1]]
	return 出


func 读落地() -> void:
	var 表 := 读JSON(NPC表路径)
	for 条v in 表.get("npc", []):
		var 条: Dictionary = 条v
		# 入口有**两种**：`菜单`（服务菜单动作值）与 `任务行`（328 帧第 6 段 selection 的补行，
		# 富岳那两扇就走这条）。少收一种 = 做了窗却报"没入口"（2026-10-05 就这么红过一次）。
		for 段 in ["菜单", "任务行"]:
			for rv in (条.get(段, []) as Array):
				var 页 := String((rv as Dictionary).get("落地页", ""))
				if not 页.is_empty() and not 落地集.has(页):
					落地集.append(页)


func 读皮边距() -> void:
	# 故意不用正则：GDScript 的双引号串里 `\\"` 会**提前把串关掉**（`\\` 吃掉反斜杠、`"` 结束串），
	# 于是报 `Closing "]" doesn't have an opening counterpart`（本轮踩过）。这表每行就是
	# `\t按钮按下: [7, 7, 7, 7],` 一个形状，字符串切分足够，且不会因为转义再翻车。
	for 行 in 读文(皮肤表).split("\n"):
		var 冒 := 行.find(": [")
		if 冒 <= 0:
			continue
		var 名 := 行.substr(0, 冒).strip_edges()
		if 名.is_empty() or 名.contains("\"") or 名.contains("(") or 名.contains(" "):
			continue
		var 尾 := 行.substr(冒 + 3)
		var 闭 := 尾.find("]")
		if 闭 < 0:
			continue
		var 数 := 尾.substr(0, 闭).split(",")
		if 数.size() != 4:
			continue
		皮边距[名] = [float(数[0]), float(数[1]), float(数[2]), float(数[3])]


## 资源 id 只许 `[A-Za-z0-9_]`（Godot 场景加载器的硬要求）。
func 是ASCII标识(识: String) -> bool:
	for i in 识.length():
		var c := 识.unicode_at(i)
		var 可: bool = (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95
		if not 可:
			return false
	return not 识.is_empty()


## 取 `前缀"` 之后到下一个 `"` 之间的内容（不用正则：GDScript 双引号串里 `\"` 会提前关串）。
func 之间(文: String, 起: String, 从: int) -> String:
	var i := 文.find(起, 从)
	if i < 0:
		return ""
	var a := i + 起.length()
	var b := 文.find("\"", a)
	return 文.substr(a, b - a) if b > a else ""


## `SubResource("sbN_槽")` → 那张 PNG 的 res 路径（顺着 stylebox → ext_resource 追）。
func 皮路(文: String, 识: String) -> String:
	var 起 := 文.find('[sub_resource type="StyleBoxTexture" id="%s"]' % 识)
	if 起 < 0:
		return ""
	var 识图 := 之间(文.substr(起, 300), 'texture = ExtResource("', 0)
	if 识图.is_empty():
		return ""
	var 尾 := 'id="%s"]' % 识图
	for 行 in 文.split("\n"):
		if 行.begins_with("[ext_resource") and 行.ends_with(尾):
			return 之间(行, 'path="', 0)
	return ""


func 验窗(页: String) -> void:
	var 窗: Dictionary = SPEC[页]
	var SPEC件: Array = 窗["件"] as Array
	日志.append("=== %s（%s）===" % [页, String(窗.get("类", ""))])
	var 规: Dictionary = 尺寸.get(页, {})
	记(not 规.is_empty(), "窗口尺寸.json 有「%s」这一条（没有 = 落地页开不出窗）" % 页)
	if 规.is_empty():
		return
	记(int(规.get("宽", -1)) == int(窗["宽"]) and int(规.get("高", -1)) == int(窗["高"]),
			"尺寸 %sx%s 与尺寸表一致（表 %sx%s）" % [窗["宽"], 窗["高"], 规.get("宽"), 规.get("高")])
	记(bool(规.get("整框", false)), "「%s」标了 整框: true ⇒ 容器原点 (0,29)，场景 y = 窗口 y − 29" % 页)
	记(String(规.get("标题", "")) == String(窗.get("标题", "")),
			"标题一致（尺寸表 %s / SPEC %s）" % [规.get("标题"), 窗.get("标题")])
	if 窗.has("入口"):
		# 「非 NPC 入口」的**唯一**豁免口：这族里有些窗原版根本不是从 NPC 菜单/任务行进（护送提示
		# = 踩到地上那枚护送标记 `CueEventIcon.HUSONG_ICON` ⇒ `HuSongQuestManager.as:609-613`）。
		# 豁免必须把**两边**都写清：原版凭什么开（要带 AS3 行号）+ 本工程这一版怎么开。
		# 空话/TODO 直接红 —— 这条规则一旦被写成"想免就免"，"做了窗没人能点开"就再也抓不到了。
		var 入: Dictionary = 窗["入口"]
		var 原 := String(入.get("原版触发", ""))
		var 本 := String(入.get("本工程", ""))
		记(原.length() >= 20 and 原.contains(":") and 本.length() >= 8,
				"「%s」声明**非 NPC 入口**、两边都写实（原版触发 %d 字含行号 / 本工程 %d 字）：%s"
				% [页, 原.length(), 本.length(), 原])
	else:
		记(落地集.has(页), "木叶村NPC 表里有一行的落地页 = 「%s」（做了窗就要有入口）" % 页)

	var 场景路径 := "res://" + String(窗["场景"])
	var 文 := 读文(场景路径)
	记(文.length() > 0, "场景在盘上：%s" % 场景路径)
	if 文.is_empty():
		return
	var 期望: Dictionary = 读JSON("res://" + String(窗["期望"]))
	记(期望.size() == SPEC件.size(), "期望表 %d 件 == SPEC %d 件" % [期望.size(), SPEC件.size()])
	记(文.contains('[node name="%s" type="Control"]' % String(窗["根名"])), "根节点名 = %s" % 窗["根名"])
	var 带斜 := 0
	var re名 := 编(重节点)
	if re名 != null:
		for m in re名.search_all(文):
			if m.get_string(1).contains("/"):
				带斜 += 1
	记(带斜 == 0, "节点名里没有 `/`（出现即生成器的路径转换被绕过 ⇒ 嵌套件会掉到根上）")
	# 资源 id（ext/sub 的 `id="…"`）**只许字母数字下划线**：中文 id 会让加载器报
	# `The scene unique ID must contain only letters, numbers, and underscores`，
	# 然后**静默丢掉**这条引用（材质/stylebox 全落回默认，门里看文本却像写对了）。
	var 非ASCII: Array[String] = []
	var 找 := 0
	while true:
		找 = 文.find("_resource ", 找)
		if 找 < 0:
			break
		var 行尾 := 文.find("\n", 找)
		if 行尾 < 0:
			行尾 = 文.length()
		var 行 := 文.substr(找, 行尾 - 找)
		var 识 := 之间(行, 'id="', 0)
		if not 识.is_empty() and not 是ASCII标识(识):
			非ASCII.append(识)
		找 = 行尾
	记(非ASCII.is_empty(), "资源 id 全 ASCII（中文 id 会被静默丢弃：%s）" % str(非ASCII))
	var 绝对 := 绝对表(文)

	for 件v in SPEC件:
		var 件: Dictionary = 件v
		var 名 := String(件["名"])
		var 路 := 路径of(SPEC件, 件)
		var 段 := 取段(文, 路)
		if 段.is_empty():
			记(false, "缺节点 %s（路径 %s：生成器没写出来 / parent 拼错解不到）" % [名, 路])
			continue
		var 想: Array = 期望.get(名, [])
		var 实: Array = 绝对.get(路, [-1.0, -1.0, -1.0, -1.0])
		var 偏 := false
		for i in 4:
			if 想.size() <= i or absf(float(实[i]) - float(想[i])) > 容差:
				偏 = true
		if 偏:
			记(false, "%-16s 实 %s ≠ 期 %s" % [名, str(实), str(想)])
		var 类 := String(件["类"])
		match 类:
			"btn":
				# ⚠ 不再断言「我确实写了 SubResource("sb_中文名")」——**非 ASCII 的 id 会被 Godot
				#    场景加载器判为非法**（`The scene unique ID must contain only letters, numbers,
				#    and underscores`）并静默丢掉整条 override。改成顺着 id → stylebox → PNG 追到底，
				#    断言**实际生效的那张皮的文件名**（2026-10-04 灰度材质不生效查出来的同一类坑）。
				var 槽识 := {}
				for 行 in 段.split("\n"):
					for 槽v in ["normal", "hover", "pressed"]:
						var 槽: String = String(槽v)
						var 前: String = "theme_override_styles/" + 槽 + ' = SubResource("'
						if 行.begins_with(前):
							槽识[槽] = 之间(行, 前, 0)
				记(槽识.size() == 3, "%s 三档 = normal/hover/pressed **换皮**（不是 texture_hover、不是 modulate），实 %s" % [名, str(槽识)])
				# 皮的基名 = `皮` 键（一张符号复用 N 次，如跨服 33 枚频道格全是 charId 659 的
				# 三态皮 652/655/658），没给就是件名 —— 与生成器 `btn` 分支同一套口径。
				var 皮基 := String(件.get("皮", 名))
				var 后表 := {"normal": "", "hover": "_悬停", "pressed": "_按下"}
				for 槽名 in 槽识:
					var 实路 := String(皮路(文, String(槽识[槽名])))
					var 该 := "res://素材/界面/原版窗口/%s/%s%s.png" % [String(窗["皮目录"]), 皮基, String(后表[槽名])]
					记(实路 == 该, "%s 的 %s 槽实际指向 %s（应为 %s）" % [名, 槽名, 实路, 该])
				记(段.contains("mouse_default_cursor_shape = 2"), "%s 手型光标（MButton3 buttonMode/useHandCursor）" % 名)
				记(not 段.contains("modulate"), "%s 没有 modulate 染色模拟" % 名)
				if 件.get("禁用同常态"):
					# 符号表里 disabledSkin 与 upSkin 是同一个 characterId ⇒ 禁用槽必须**指回常态那张皮**，
					# 落回主题默认就是"禁用时变成一个灰盒子"（跨服频道格 33 枚全禁用 ⇒ 整屏假灰）。
					var 前度 := 'theme_override_styles/disabled = SubResource("'
					var 度识 := ""
					for 行 in 段.split("\n"):
						if String(行).begins_with(前度):
							度识 = 之间(行, 前度, 0)
					记(度识.ends_with("_n"),
							"%s 的 disabled 槽指回常态皮（%s，因为库里 disabledSkin == upSkin 同一个 charId），实「%s」" % [名, 皮基, 度识])
					记(段.contains("theme_override_colors/font_disabled_color"),
							"%s 有禁用字色（`SelectedChannelCell.as:33` disabledTextColor #717068，不是主题灰）" % 名)
				var 目录 := "res://素材/界面/原版窗口/" + String(窗["皮目录"]) + "/"
				for 后 in ["", "_悬停", "_按下"]:
					记(FileAccess.file_exists(目录 + 皮基 + 后 + ".png"), "皮在盘上：%s%s.png" % [皮基, 后])
			"rich":
				记(段.contains("scroll_active = false"), "%s scroll_active=false（原版是 dynamic TextField，不出滚动条）" % 名)
				记(not (段.contains("<font") or 段.contains("</")), "%s 的文字是 BBCode、没混进 HTML 标签" % 名)
				# ⚠ 光判"没有 HTML"不够：**Godot 不认的标记会原样当正文画出来**（不报错、不崩）。
				#   心法页那三块最初写成 `[font_color=#1e90ff]…[/font_color]`（照着 AS3 的
				#   `<font color>` 直译过来的），HTML 检查照样绿，屏上却露出一行英文
				#   `[/font_color]提高后，`（2026-10-14 用户实机图打回）。Godot 只认 `[color=…]`。
				for 标 in 标记名们(String(件.get("文字", ""))):
					记(支持标记.has(标),
							"%s 的 BBCode 标记「[%s]」在 Godot 的支持表里（不在就会当正文画到屏上）" % [名, 标])
				记(段.contains("autowrap_mode = 3"), "%s autowrap=3（TextArea2.as:84-85 wordWrap=true）" % 名)
				var 行距 := int(件.get("行距", 6))
				记(段.contains("theme_override_constants/line_separation = %d" % 行距),
						"%s 行距 = AS3 leading+2 = %d" % [名, 行距])
				var 文路 := "text = \"%s\"" % _串(String(件.get("文字", "")))
				记(段.contains(文路), "%s 的说明文案是**逐字真句**烘进场景（不是转述/兜底句）" % 名)
			"label":
				记(段.contains('text = "%s"' % _串(String(件.get("文字", "")))),
						"%s 文案逐字落到场景：「%s」" % [名, String(件.get("文字", ""))])
				if bool(件.get("隐藏", false)):
					记(段.contains("visible = false"),
							"%s 烘成隐藏件 —— SimpleItemCell.as:290-302 有 itemData 时 nameField.visible=false" % 名)
			"tex":
				# 格子里那一层「物品图标 + 数量角标」是运行期 `showInfo()/validateItem()` 画的，
				# 但按「编辑器视图 = 运行期」必须烘进场景 ⇒ 这里逐件核对生成器有没有真的写出来。
				var 图标 := String(件.get("图标", ""))
				if 图标.is_empty():
					pass
				else:
					var 编号 := String(件.get("物品", ""))
					var 子路 := 路径of(SPEC件, 件)
					var 图路 := 子路 + "/" + 节点名(名) + "_图标"
					var 图段 := 取段(文, 图路)
					记(not 图段.is_empty(), "%s 有图标件 %s（原版 showIcon() 那一层）" % [名, 图路])
					记(图段.contains('texture = ExtResource(') and 文.contains('path="%s"' % 图标),
							"%s 的图标指向 %s（物品 %s）" % [名, 图标, 编号])
					记(FileAccess.file_exists(图标), "%s 图标在盘上" % 图标)
					var 索引路 := String(图标索引.get(编号, ""))
					if 索引路.is_empty():
						记(图标.contains("素材/原版直解/"),
								"%s（物品 %s）不在 物品图标索引 里 ⇒ 只许走 原版直解 台账（RenJu 那表 数据/物品.json 没并）" % [名, 编号])
					else:
						记(索引路 == 图标, "%s 图标与 物品图标索引[%s] 一致（实 %s）" % [名, 编号, 图标])
					var 数型: Variant = 件.get("数量", "")
					# ⚠ `数量` 在 SPEC 里有**两种形状**：字符串 = 烘进格子的数量文案
					#   （忍具兑换 '0' / 勾玉炼制 ' '）；字典 = 子件几何规格
					#   （卡片套册、两扇互换的 `格/数量` = {文字,x,y,w,h,对齐}）。
					#   上一版无条件 `String(件.get("数量",""))` ⇒ 遇字典当场抛
					#   `Invalid call 'String' constructor`，**那一页后面的件一条都没判，
					#   而退出码照样 0**（2026-10-06 加跨服那页时才撞出来 = 门自己的洞，
					#   已配下面的「每页走到最后一件」自检兜住）。
					var 数组 := String(数型) if typeof(数型) == TYPE_STRING else ""
					if not 数组.is_empty():
						var 数路 := 子路 + "/" + 节点名(名) + "_数量"
						var 数段 := 取段(文, 数路)
						记(not 数段.is_empty(), "%s 有数量件 %s" % [名, 数路])
						记(数段.contains('text = "%s"' % 数组), "%s 数量 = 「%s」" % [数路, 数组])
						记(数段.contains("horizontal_alignment = 2"),
								"%s 右对齐（SimpleItemCell.as:143 countLabel align=right）" % 数路)
						记(数段.contains("font_color = Color(1, 1, 1, 1)"),
								"%s 白色（:137 color=0xFFFFFF）" % 数路)
						记(数段.contains("offset_top = 20") and 数段.contains("offset_bottom = 40"),
								"%s 在格内 (0,20)-(40,40)（:138-139 setSize(40,20)/setPosition(0,20)）" % 数路)
					if bool(件.get("灰化", false)):
						记(段.contains('material = SubResource("mat1")'),
								"%s 挂 禁用灰度 材质（数量<1 时 applyGrayFilter；矩阵系数与 Style.as:63-65 同）" % 名)
					else:
						记(not 段.contains("material"),
								"%s **不挂**灰度材质（原版只给碎片格 applyGrayFilter，主格从不灰）" % 名)
			"panel", "cell":
				var 皮 := String(件["皮"])
				if 皮边距.has(皮):
					var 想边: Array = 皮边距[皮]
					var 实边: Array = 九宫边距(段)
					var 同: bool = true
					# 九宫那条只收 int ⇒ 比**四舍五入后**的整数（皮肤表原值带 .75/.5/0.05 是 XML 九宫格的换算残留）
					for i in 4:
						if absf(float(实边[i]) - float(想边[i])) > 0.5:
							同 = false
					记(同, "%s 九宫格边距 == 原版皮肤表.gd 的「%s」%s（实 %s，禁拟合值）" % [名, 皮, str(想边), str(实边)])
			"box", "sep":
				pass
	# 走到这里 = 本页每一件事都判完了（前面任何一处 `return` 或抛异常都不会 +1）。
	走完 += 1


func 验出处齐全() -> void:
	var 缺: Array[String] = []
	for 页 in SPEC:
		var 窗: Dictionary = SPEC[页]
		if String(窗.get("as3文件", "")).length() < 8:
			缺.append("%s 整窗没写 .as 路径" % String(页))
		for 件v in (窗["件"] as Array):
			var 件: Dictionary = 件v
			var 由 := String(件.get("出处", ""))
			if 由.length() < 12 or not (由.contains(":") or 由.contains("：")):
				缺.append("%s/%s" % [页, String(件["名"])])
			var 字 := String(件.get("文字", ""))
			if 字.contains("<font") or 字.contains("</"):
				缺.append("%s/%s 文字里还有 HTML 标签（要写 BBCode）" % [页, String(件["名"])])
			# ⚠ BBCode 只有 `rich`（RichTextLabel + bbcode_enabled）会解析。`label` 烘出来的是
			#   Godot 的 Label —— **不解析**，`[color=#ff9100]…[/color]` 会原样画到屏上
			#   （2026-10-05 勾玉炼制 面板2 那行「特别注意」实拍抓到的）。
			#   AS3 的 htmlText 落到这种件上 ⇒ 剥标记、颜色走 `色`、居中走 `对齐`。
			var 类 := String(件.get("类", ""))
			if 类 != "rich" and (字.contains("[color=") or 字.contains("[/")
					or 字.contains("[b]") or 字.contains("[url=")):
				缺.append("%s/%s 是「%s」件、文字里却有 BBCode（Label 不解析 ⇒ 标记原样显形）"
						% [页, String(件["名"]), 类])
			# ⚠ 出处里写了 `align=center`（AS3 的居中）而 SPEC 没落 `对齐` ⇒ 一定按左对齐画，
			#   整排文字往左偏（2026-10-05 用户实机图打回「这排文字位置有点偏左」= 材料1-4 那四枚
			#   `ItemCaiLiaoBox.as:136` 的居中标签）。出处是**唯一事实源** ⇒ 它说了就得做。
			if 类 in ["label", "rich"] and 由.contains("align") and 由.contains("center") \
					and not 件.has("对齐"):
				缺.append("%s/%s 出处写了 align=center 却没有 `对齐` ⇒ 会按左对齐画（文字偏左）"
						% [页, String(件["名"])])
			# ⚠ 出处里凡写「十进制 = #十六进制」的，两边必须真的换算得过来，而且件上落地的 `色`
			#   就得是那个值。心法页两枚 Label 我把 `16773120` 记成 `#FFFFE0`、`16748800` 记成
			#   `#FFD000`（正确是 **#FFF000 / #FF9100**）⇒ 心法名与层数整行颜色都不对，
			#   2026-10-14 用户拿实机图并排才抓出来。这种错"有没有色"那类判据永远发现不了。
			var 色匹 := 编("(\\d{6,8})\\s*=\\s*#([0-9a-fA-F]{6})")
			if 色匹 != null:
				var 匹们: Array = 色匹.search_all(由)
				for mm in 匹们:
					var 十 := int(mm.get_string(1))
					var 写 := String(mm.get_string(2)).to_upper()
					var 正 := "%06X" % 十
					if 写 != 正:
						缺.append("%s/%s 出处把 %d 写成 #%s，实际是 #%s"
								% [页, String(件["名"]), 十, 写, 正])
					var 色 := String(件.get("色", "")).to_upper()
					if 匹们.size() == 1 and not 色.is_empty() and 色 != ("#" + 正):
						缺.append("%s/%s 落地的色 %s 与出处的 %d=#%s 不符"
								% [页, String(件["名"]), 色, 十, 正])
	记(缺.is_empty(), "每件都带 AS3 出处、文字没有 HTML 标签、非 rich 件没有 BBCode、出处说居中的件有 `对齐`（缺：%s）" % str(缺))
