extends RefCounted

## 原版富文本 —— 把 Flash 的 HTML + StructuredText 标记转换成 Godot BBCode。
##
## 真值来源（不许凭截图猜）：
##   · com/mxw/common/ui/textParser/StructuredText.as  —— 标记替换顺序与颜色常量
##   · com/mxw/common/ui/UIConfig.as                   —— UI_BLUE / UI_ORANGE 等
##   · com/mxw/common/tools/StringTool.as              —— getNpcNameWidthMapName 等
##
## 替换顺序**必须照抄 StructuredText.as:87-105**，否则嵌套会错：
##   icc → mcc → h0c → pc → mc → m → tc/t → #b → #r → #d → #g → #color_ → #c
##
## 用法：
##   const 富文本 := preload("res://素材/界面/任务界面/脚本/原版富文本.gd")
##   rich.text = 富文本.转换(npc_desc, 富文本.建表())

# ============================ 颜色真值 ============================
# 标签橙 —— message 表 QUEST_NAME / QUEST_DESCRIPTION / QUEST_TRACK /
#            HANDIN_NPC_QUEST / MEET_NPC_QUEST / QUEST_HORTATION 里的 <font color='#ff9100'>
const 橙 := "#ff9100"
# 正文白 —— MQuestionInfoPanel 把整段包在 <font color='#ffffff'>
const 白 := "#ffffff"
# 链接蓝 —— UIConfig.UI_BLUE = 2003199；MQuestionInfoPanel 的交任务NPC 用它
const 蓝 := "#1e90ff"
# 目标绿 —— StructuredText.COLOR_ITEM / COLOR_NPC / COLOR_MONSTER = "#color_00FF00"
const 绿 := "#00ff00"
# 未达成红 —— StructuredText.COLOR_COUNT_ABSENCE = "#color_FF0000"
const 红 := "#ff0000"
# 玩家名绿 —— StructuredText.COLOR_PLAYER_NAME = "#color_00B000"
const 玩家绿 := "#00b000"
# 地图名黄 —— StructuredText.COLOR_MAP = "#color_FCF49C"
const 地图黄 := "#fcf49c"
# 内联色 —— StructuredText.as:99-105 的 handleColor 参数
const 内联蓝 := "#0000ff"
const 内联紫 := "#553388"
const 内联橙 := "#ff9932"

# ============================ 数据表 ============================

## NPC 所在地图（原版 Etc["NpcLocation"]，75 条，真值，勿改）
## StringTool.getNpcLocation(id) → getMapString(该值) → "[地图名]NPC名"
const NPC所在地图 := {
	"00000001": 101010000, "00000002": 101010000, "00000003": 101010000, "00000004": 101010000,
	"00000005": 101020000, "00000006": 101020000, "00000007": 101010000, "00000008": 101010000,
	"00000009": 101010000, "00000010": 101040000, "00000011": 100000000, "00000012": 100000000,
	"00000013": 100000000, "00000014": 100000000, "00000015": 100000000, "00000016": 100000000,
	"00000017": 100000000, "00000018": 100000000, "00000019": 100000000, "00000020": 100000000,
	"00000021": 100000000, "00000022": 100000000, "00000023": 100000000, "00000024": 100000000,
	"00000025": 100000000, "00000026": 100000000, "00000027": 100000000, "00000028": 100000000,
	"00000029": 100000000, "00000030": 100000000, "00000031": 100000000, "00000032": 100000000,
	"00000033": 100000000, "00000034": 100000000, "00000035": 100000000, "00000036": 100000000,
	"00000037": 100010000, "00000038": 100010000, "00000039": 100000000, "00000040": 100000000,
	"00000041": 100000000, "00000042": 100000000, "00000043": 100000000, "00000044": 104030000,
	"00000045": 101010000, "00000046": 105030000, "00000047": 105010000, "00000048": 100000000,
	"00000049": 100000000, "00000050": 100000000, "00000051": 100000000, "00000052": 100000000,
	"00000053": 100000000, "00000054": 100000000, "00000055": 100000000, "00000056": 100000000,
	"00000057": 100000000, "00000058": 100000000, "00000059": 100000000, "00000060": 100000000,
	"00000061": 100000000, "00000062": 100000000, "00000063": 100000000, "00000064": 100000000,
	"00000065": 100000000, "00000066": 100000000, "00000067": 100000000, "00000068": 100000000,
	"00000069": 100000000, "00000070": 100000000, "00000071": 100000000, "00000072": 100000000,
	"00000073": 100000000, "00000074": 100000000, "00000075": 100000000,
}


## 建查表上下文。相机工程已有的数据表，缺哪张就留空（对应名字会退化成原文标记）。
static func 建表() -> Dictionary:
	var t := {"npc": {}, "map": {}, "item": {}, "mob": {}, "player": ""}
	t.npc = _读表("res://数据/NPC.json")
	t.map = _读表("res://数据/地图名.json")
	t.item = _读表("res://数据/物品.json")
	t.mob = _读表("res://数据/怪物.json")
	return t


static func _读表(路径: String) -> Dictionary:
	if not FileAccess.file_exists(路径):
		return {}
	var f := FileAccess.open(路径, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}


# ============================ 主入口 ============================

## Godot 的 [ ] 是 BBCode 语法，字面量必须写成 [lb] / [rb]，否则会被当标签吃掉。
## ⚠️ 必须用占位符做**单趟**替换：先 replace("[","[lb]") 再 replace("]","[rb]")
## 会把刚生成的 "[lb]" 自己的 "]" 也换掉，得到 "[lb[rb]"（已踩过）。
## 转换开头先转义一次；**转换过程中插入的名字也要转义**（否则二次出现在输出里，
## 表现为文字里直接显示 "[lb]"）。
const _占位左 := "\u0001"
const _占位右 := "\u0002"

static func _字面(s: String) -> String:
	return s.replace("[", _占位左).replace("]", _占位右) \
		.replace(_占位左, "[lb]").replace(_占位右, "[rb]")


## 把原版富文本转成 Godot BBCode。
## 悬停 / 按下 传的是 _编号链接 产出的 token（原 url + "@" + 出现序号），不是 url。
## 做成参数而不是全局状态：任务面板和追踪栏各自有各自的悬停目标，共用一个全局会互相染色。
static func 转换(源: String, 表: Dictionary = {}, 悬停: String = "", 按下: String = "", 命名空间: String = "") -> String:
	用表(表)
	if 源.is_empty():
		return ""
	var s := _字面(源)

	# 1~2. 计数着色。原版 replaceItemCountColor/replaceMobCountColor(:690/:649)
	#      是把 #icc / #mcc 整个换成 COLOR_COUNT_ABSENCE = #color_FF0000，
	#      再由 handleOtherColor 配 #k 收口 —— 起点是**红**，不是绿。
	s = _着色(s, "#icc", "#k", 红)
	s = _着色(s, "#mcc", "#k", 红)

	# 3. 玩家名（#h0c# 带色 / #h0# 不带）
	s = _换名(s, "#h0c#", "#k", 玩家绿, 表.player)
	s = _换名(s, "#h0#", "#k", 玩家绿, 表.player)

	# 4. NPC 名：#pc = 绿（replaceNPCColorNames :319），#p = 本色（replaceNPCNames :532）
	s = _换NPC(s, "l")
	s = _换NPC(s, "")
	s = _换NPC无色(s, "l")
	s = _换NPC无色(s, "")

	# 5. 地图名：#mc = 黄（:610），#m = 本色（:396）
	s = _换地图(s, "l")
	s = _换地图(s, "")
	s = _换地图无色(s, "l")
	s = _换地图无色(s, "")

	# 6. 怪物名：#oc = 绿（:800），#o = 本色（:880）。原版这两族都没有 l 形态
	s = _换怪(s)
	s = _换怪无色(s)

	# 7. 物品名：#tc… = 绿（:252/:661），#t… = 绿（:297）
	s = _换物品(s)

	# 8. 内联色（顺序照抄 StructuredText.as:99-105）
	s = _着色(s, "#b", "#k", 内联蓝)
	s = _着色(s, "#r", "#k", 红)
	s = _着色(s, "#d", "#k", 内联紫)
	s = _着色(s, "#g", "#k", 玩家绿)
	s = _着色(s, "#c", "#", 内联橙)

	# 9. #color_XXXXXX ... #k
	s = _换其他色(s)

	# 10. Flash HTML → BBCode
	s = _转HTML(s)

	# 11. 清掉残留的 StructuredText 标记
	s = _清残留(s)

	# 12. 给每个链接 occurrence 编号 + 加下划线。
	#     原版 StyleSheet a:link = textDecoration:"underline" —— **常态就带下划线**。
	#     编号是为了悬停能精确命中：Godot 的 meta_hover_started 只回传 url 字符串，
	#     同一个 url 出现两次时无法区分，所以给每次出现一个唯一 token。
	s = _编号链接(s, 命名空间)

	# 13. 悬停/按下上色。原版 StructuredText.onLinkMouseMove(:731) 用 setTextFormat
	#     把**光标所在那一整段**染成 #FF0000（优先级高于 <font> 与 styleSheet），
	#     a:active = #B19B50。
	s = _套悬停色(s, 悬停, 按下)
	return s


## 匹配 _编号链接 要处理的链接起点（源文本的 "[" 已被 _字面 转成 [lb]，不会误命中）
static var _链接式: RegEx = _建链接式()

const _token分隔 := "@"


static func _建链接式() -> RegEx:
	var r := RegEx.new()
	r.compile("\\[url=([^\\]]*)\\]")
	return r


## 按出现顺序把 [url=X] 改写成 [url=X@<命名空间><序号>]，并套上 [u]。
## 命名空间用来隔开同一段文字里的不同控件（任务面板的上半/下半、追踪栏的每一行）：
## 否则"上半的第 0 个链接"和"下半的第 0 个链接"token 相同，会互相染色。
static func _编号链接(s: String, 命名空间: String) -> String:
	var 出 := ""
	var 余 := s
	var 序 := 0
	while true:
		var m := _链接式.search(余)
		if m == null:
			break
		var 起 := m.get_start()
		var 止 := m.get_end()
		var url := m.get_string(1)
		var 闭 := 余.find("[/url]", 止)
		if 闭 < 0:
			出 += 余.substr(0, 止)
			余 = 余.substr(止)
			continue
		出 += 余.substr(0, 起) + "[url=" + url + _token分隔 + 命名空间 + str(序) + "][u]" \
			+ 余.substr(止, 闭 - 止) + "[/u][/url]"
		余 = 余.substr(闭 + 6)
		序 += 1
	return 出 + 余


## 把当前该高亮的那一个链接 occurrence 整段染色（token 已由 _编号链接 保证唯一）
static func _套悬停色(s: String, 悬停: String, 按下: String) -> String:
	var token := 按下 if not 按下.is_empty() else 悬停
	if token.is_empty():
		return s
	var 色 := 链接按下色 if token == 按下 else 链接悬停色
	var 起标 := "[url=" + token + "]"
	var i := s.find(起标)
	if i < 0:
		return s
	var j := s.find("[/url]", i)
	if j < 0:
		return s
	return s.substr(0, i) + "[color=" + 色 + "]" + s.substr(i, j + 6 - i) + "[/color]" + s.substr(j + 6)


# ============================ 各标记实现 ============================

## handleColor(start, end, color)：把 start…end 之间整体染色。
## 用非贪婪 + 循环处理最内层，避免嵌套吃掉外层。
## （Godot 4 没有 RegEx.escape，这里自己转义正则元字符）
static func _转义(s: String) -> String:
	var 出 := ""
	for i in s.length():
		var c := s[i]
		if "\\^$.|?*+()[]{}".contains(c):
			出 += "\\"
		出 += c
	return 出


static func _着色(s: String, 起: String, 止: String, 色: String) -> String:
	var re := RegEx.new()
	re.compile(_转义(起) + "((?:(?!" + _转义(止) + "|" + _转义(起) + ")[\\s\\S])*)" + _转义(止))
	var 上限 := 200
	while 上限 > 0:
		上限 -= 1
		var m := re.search(s)
		if m == null:
			break
		s = s.substr(0, m.get_start()) + "[color=" + 色 + "]" + m.get_string(1) + "[/color]" + s.substr(m.get_end())
	return s


## #color_XXXXXX … #k
static func _换其他色(s: String) -> String:
	var re := RegEx.new()
	re.compile("#color_([0-9a-fA-F]{6})((?:(?!\\#color_|\\#k)[\\s\\S])*)#k")
	var 上限 := 200
	while 上限 > 0:
		上限 -= 1
		var m := re.search(s)
		if m == null:
			break
		s = s.substr(0, m.get_start()) + "[color=#" + m.get_string(1) + "]" + m.get_string(2) + "[/color]" + s.substr(m.get_end())
	return s


## 通用「取名字 → 染色（可带链接）」
static func _换名(s: String, 起标记: String, 止标记: String, 色: String, 名字: String) -> String:
	if s.find(起标记) < 0:
		return s
	var a := s.find(起标记)
	while a >= 0:
		var b := s.find(止标记, a + 起标记.length())
		if b < 0:
			break
		s = s.substr(0, a) + "[color=" + 色 + "]" + _字面(名字) + "[/color]" + s.substr(b + 止标记.length())
		a = s.find(起标记)
	return s


static func _取ID(原: String) -> String:
	var 数字 := ""
	for i in 原.length():
		var c := 原[i]
		if c >= "0" and c <= "9":
			数字 += c
	return 数字


## #pc<id>l# / #pc<id># —— 带绿色（COLOR_NPC）
static func _换NPC(s: String, 尾巴: String) -> String:
	var re := RegEx.new()
	re.compile("#pc(\\w+)" + 尾巴 + "#")
	var 上限 := 300
	while 上限 > 0:
		上限 -= 1
		var m := re.search(s)
		if m == null:
			break
		var id := _取ID(m.get_string(1))
		var 名 := _NPC名(id)
		var 替换 := "[color=" + 绿 + "]"
		if 尾巴 == "l":
			替换 += "[url=event:npc" + id + "]"
		替换 += _字面(名)
		if 尾巴 == "l":
			替换 += "[/url]"
		替换 += "[/color]"
		s = s.substr(0, m.get_start()) + 替换 + s.substr(m.get_end())
	return s


## #p<id>l# / #p<id># —— 本色（replaceNPCNames :532，只加链接不加色）
static func _换NPC无色(s: String, 尾巴: String) -> String:
	var re := RegEx.new()
	re.compile("#p(\\w+)" + 尾巴 + "#")
	var 上限 := 300
	while 上限 > 0:
		上限 -= 1
		var m := re.search(s)
		if m == null:
			break
		var id := _取ID(m.get_string(1))
		var 替换 := ""
		if 尾巴 == "l":
			替换 = "[url=event:npc" + id + "]" + _字面(_NPC名(id)) + "[/url]"
		else:
			替换 = _字面(_NPC名(id))
		s = s.substr(0, m.get_start()) + 替换 + s.substr(m.get_end())
	return s


## StringTool.getNpcString → String.Npc[id].name（纯名字）
static func _NPC名(id: String) -> String:
	var 表 := _缓存
	var 键 := id
	if 键.length() < 8:
		键 = "0".repeat(8 - 键.length()) + 键
	if 表.has("npc") and 表.npc.has(键):
		var e: Variant = 表.npc[键]
		if e is Dictionary:
			return String(e.get("name", ""))
		if e is String:
			return e
	return ""


## StringTool.getNpcNameWidthMapName → "[" + 地图名 + "]" + NPC名
static func _NPC全名(id: String) -> String:
	var 表 := _缓存
	var 键 := id
	if 键.length() < 8:
		键 = "0".repeat(8 - 键.length()) + 键
	var npc名 := ""
	if 表.has("npc") and 表.npc.has(键):
		var e: Variant = 表.npc[键]
		if e is Dictionary:
			npc名 = String(e.get("name", ""))
		elif e is String:
			npc名 = e
	var 地图名 := ""
	var 图 := _所在地图(键)
	if 图 > 0:
		var mid := str(图)
		if 表.has("map") and 表.map.has(mid):
			var mv: Variant = 表.map[mid]
			地图名 = String(mv.get("mapName", "")) if mv is Dictionary else String(mv)
	return "[" + 地图名 + "]" + npc名


## NPC 所在地图：**先查 `数据/界面/NPC所在地图.json`**（10-25 从 `数据/地图/*/地图.json` 的
## life `type=n` 现扫，76 条、与真实摆位同源），查不到才回落到上面那份旧常量。
## ⚠ 旧常量在后期主线是错的（实例：模板 60 写 100000000，实际在 107010000 的粘土巢穴；
##   45 写 101010000，实际在 105030000）⇒ 追踪栏会印错 `[地图名]`。
static var _地图表: Dictionary = {}

static func _所在地图(键: String) -> int:
	if _地图表.is_empty():
		var 原 := FileAccess.get_file_as_string("res://数据/界面/NPC所在地图.json")
		if not 原.is_empty():
			var 解析 = JSON.parse_string(原)
			if 解析 is Dictionary and (解析 as Dictionary).get("表") is Dictionary:
				## JSON 的键是裸号（"37"），调用方一律传 8 位（"00000037"）⇒ 载入时统一补零，
				## 否则查不到就回落到下面那份旧常量（37 写成 100010000，实际水木在 102020000）。
				for 旧键 in ((解析 as Dictionary)["表"] as Dictionary):
					_地图表["%08d" % int(String(旧键))] = (解析 as Dictionary)["表"][旧键]
	var 列 = _地图表.get(键, [])
	if 列 is Array and not (列 as Array).is_empty():
		return int((列 as Array)[0])
	return int(NPC所在地图.get(键, 0))


## #mc<id>l# / #mc<id># —— 地图黄（replaceMapColorNames :610；l 形态带 event:map 链接）
static func _换地图(s: String, 尾巴: String) -> String:
	var re := RegEx.new()
	re.compile("#mc(\\w+)" + 尾巴 + "#")
	var 上限 := 300
	while 上限 > 0:
		上限 -= 1
		var m := re.search(s)
		if m == null:
			break
		var id := _取ID(m.get_string(1))
		var 替换 := "[color=" + 地图黄 + "]"
		if 尾巴 == "l":
			替换 += "[url=event:map" + id + "]"
		替换 += _字面(_地图名(id))
		if 尾巴 == "l":
			替换 += "[/url]"
		替换 += "[/color]"
		s = s.substr(0, m.get_start()) + 替换 + s.substr(m.get_end())
	return s


## #m<id>l# / #m<id># —— 本色地图（replaceMapNames :396）
static func _换地图无色(s: String, 尾巴: String) -> String:
	var re := RegEx.new()
	re.compile("#m(\\w+)" + 尾巴 + "#")
	var 上限 := 300
	while 上限 > 0:
		上限 -= 1
		var m := re.search(s)
		if m == null:
			break
		var id := _取ID(m.get_string(1))
		var 替换 := ""
		if 尾巴 == "l":
			替换 = "[url=event:map" + id + "]" + _字面(_地图名(id)) + "[/url]"
		else:
			替换 = _字面(_地图名(id))
		s = s.substr(0, m.get_start()) + 替换 + s.substr(m.get_end())
	return s


static func _地图名(id: String) -> String:
	var 表 := _缓存
	if 表.has("map") and 表.map.has(id):
		var mv: Variant = 表.map[id]
		return String(mv.get("mapName", "")) if mv is Dictionary else String(mv)
	return id


## #oc<id>-<map># / #oc<id># —— 怪物绿（replaceMobColorNames :800）
## 注意：原版只有这两种形态，**没有 #oc…l#**；带 map 的那条链接是 event:mob<id>-<map>
static func _换怪(s: String) -> String:
	var re := RegEx.new()
	re.compile("#oc(\\w+)(?:-(\\w+))?#")
	var 上限 := 300
	while 上限 > 0:
		上限 -= 1
		var m := re.search(s)
		if m == null:
			break
		var id := _取ID(m.get_string(1))
		var 名 := _字面(_怪物名(id))
		var 尾 := m.get_string(2)
		var 内 := 名
		if 尾 != "" and 尾 != null:
			内 = "[url=event:mob" + id + "-" + _取ID(尾) + "]" + 名 + "[/url]"
		s = s.substr(0, m.get_start()) + "[color=" + 绿 + "]" + 内 + "[/color]" + s.substr(m.get_end())
	return s


## #o<id>-<map># / #o<id># —— 本色怪物（replaceMobNames :880）
static func _换怪无色(s: String) -> String:
	var re := RegEx.new()
	re.compile("#o(\\w+)(?:-(\\w+))?#")
	var 上限 := 300
	while 上限 > 0:
		上限 -= 1
		var m := re.search(s)
		if m == null:
			break
		var id := _取ID(m.get_string(1))
		var 名 := _字面(_怪物名(id))
		var 尾 := m.get_string(2)
		var 替换 := 名
		if 尾 != "" and 尾 != null:
			替换 = "[url=event:mob" + id + "-" + _取ID(尾) + "]" + 名 + "[/url]"
		s = s.substr(0, m.get_start()) + 替换 + s.substr(m.get_end())
	return s


static func _怪物名(id: String) -> String:
	var 表 := _缓存
	if 表.has("mob") and 表.mob.has(id):
		var e: Variant = 表.mob[id]
		return String(e.get("name", id)) if e is Dictionary else String(e)
	return id


## 物品名：#tc<id>-<mob>-<map># / #tc<id>-shop# / #tc<id>-<npc># / #tc<id># / #t<id>#
## 链接目标逐项照抄 StructuredText.as:264/276/286 与 :661/:297
static func _换物品(s: String) -> String:
	# #tc<id>-<a>-<b># → event:mob<a>-<b>
	var re := RegEx.new()
	re.compile("#tc(\\w+)-(\\w+)-(\\w+)#")
	var 上限 := 300
	while 上限 > 0:
		上限 -= 1
		var m := re.search(s)
		if m == null:
			break
		var id := _取ID(m.get_string(1))
		var 内 := "[url=event:mob" + _取ID(m.get_string(2)) + "-" + _取ID(m.get_string(3)) + "]" \
			+ _字面(_物品名(id)) + "[/url]"
		s = s.substr(0, m.get_start()) + "[color=" + 绿 + "]" + 内 + "[/color]" + s.substr(m.get_end())
	# #tc<id>-shop# → event:sch<id>
	var re2 := RegEx.new()
	re2.compile("#tc(\\w+)-shop#")
	上限 = 300
	while 上限 > 0:
		上限 -= 1
		var m2 := re2.search(s)
		if m2 == null:
			break
		var id2 := _取ID(m2.get_string(1))
		var 内2 := "[url=event:sch" + id2 + "]" + _字面(_物品名(id2)) + "[/url]"
		s = s.substr(0, m2.get_start()) + "[color=" + 绿 + "]" + 内2 + "[/color]" + s.substr(m2.get_end())
	# #tc<id>-<npc># → event:npc<npc>
	var re3 := RegEx.new()
	re3.compile("#tc(\\w+)-(\\w+)#")
	上限 = 300
	while 上限 > 0:
		上限 -= 1
		var m3 := re3.search(s)
		if m3 == null:
			break
		var id3 := _取ID(m3.get_string(1))
		var 内3 := "[url=event:npc" + _取ID(m3.get_string(2)) + "]" + _字面(_物品名(id3)) + "[/url]"
		s = s.substr(0, m3.get_start()) + "[color=" + 绿 + "]" + 内3 + "[/color]" + s.substr(m3.get_end())
	# #tc<id># / #t<id># —— 只有名字，不带链接
	var re4 := RegEx.new()
	re4.compile("#t[cr]?(\\w+)#")
	上限 = 300
	while 上限 > 0:
		上限 -= 1
		var m4 := re4.search(s)
		if m4 == null:
			break
		s = s.substr(0, m4.get_start()) + "[color=" + 绿 + "]" + _字面(_物品名(_取ID(m4.get_string(1)))) + "[/color]" + s.substr(m4.get_end())
	return s


static func _物品名(id: String) -> String:
	var 表 := _缓存
	if 表.has("item") and 表.item.has(id):
		var e: Variant = 表.item[id]
		return String(e.get("name", id)) if e is Dictionary else String(e)
	return id


## Flash HTML → BBCode
static func _转HTML(s: String) -> String:
	# <br/> <br>
	s = s.replace("<br/>", "\n").replace("<br />", "\n").replace("<br>", "\n")
	# <p align='...'>  </p>
	var re_p := RegEx.new()
	re_p.compile("<p[^>]*>")
	s = re_p.sub(s, "", true)
	s = s.replace("</p>", "\n")
	# <font color='#xxx'> ... </font>
	var re_font := RegEx.new()
	re_font.compile("<font\\s+color=[\"']?(#[0-9a-fA-F]{6})[\"']?[^>]*>")
	s = re_font.sub(s, "[color=$1]", true)
	s = s.replace("</font>", "[/color]")
	# <a href='event:xxx'> ... </a>
	var re_a := RegEx.new()
	re_a.compile("<a\\s+href=[\"']?([^\"'>]+)[\"']?[^>]*>")
	s = re_a.sub(s, "[url=$1]", true)
	s = s.replace("</a>", "[/url]")
	# <u> </u> <b> </b>
	s = s.replace("<u>", "[u]").replace("</u>", "[/u]")
	s = s.replace("<b>", "[b]").replace("</b>", "[/b]")
	return s


## 清掉残留标记，避免露出 #k / #v… 之类
static func _清残留(s: String) -> String:
	s = s.replace("#k", "")
	s = s.replace("#e", "")
	var re := RegEx.new()
	re.compile("#f[a-zA-Z./0-9]+#")
	s = re.sub(s, "", true)
	re.compile("#(v|s)\\w+#")
	s = re.sub(s, "", true)
	re.compile("#L[0-9]+#")
	s = re.sub(s, "", true)
	return s


# ============================ 对外名字解析 ============================
# 供面板脚本直接取用（外部调用这些公开名，不用碰内部实现）。

## StringTool.getNpcNameWidthMapName → "[" + 地图名 + "]" + NPC名
static func NPC全名(id: String) -> String:
	return _NPC全名(id)


static func 物品名(id: String) -> String:
	return _物品名(id)


static func 怪物名(id: String) -> String:
	var 表 := _缓存
	if 表.has("mob") and 表.mob.has(id):
		var e: Variant = 表.mob[id]
		return String(e.get("name", id)) if e is Dictionary else String(e)
	return id


static func 地图名(id: String) -> String:
	return _地图名(id)


# ============================ 上下文缓存 ============================
# 转换是 static，表通过 转换() 的第二个参数传入；为方便 _NPC全名 / _地图名 / _物品名
# 等内部函数取用，这里留一个当前表引用（单线程渲染，安全）。
static var _缓存: Dictionary = {}

## 原版 a:hover / a:active 的颜色真值（StructuredText.as:719/723 与 :771）
const 链接悬停色 := "#ff0000"
const 链接按下色 := "#b19b50"


static func 用表(表: Dictionary) -> void:
	_缓存 = 表


## 把 meta 回传的 token 还原成原版 url（去掉 "@序号"）
static func 解链接(token: String) -> String:
	var t := String(token)
	var i := t.rfind(_token分隔)
	return t.substr(0, i) if i > 0 else t
