extends SceneTree
## 换皮件交互态离线门（#292）：每一扇原版窗右上角那颗 X、数量框左右那两颗加减。
##
## 这一族的原版真值（2026-10-19 夜回 AS3 逐条现查，都是 `extends MButton3`、类体里除
## `[Embed]` 什么都不写 ⇒ **一族一张皮 + 运行时加性滤镜**，不是每态一张独立 skin）：
##   `MWindowCloseBtnF.as` symbol **7**（每一扇窗的 X、提示条 `MessageTipPane2.as:321`、
##     刻印图解 `EquipKeYinHelpWindow.as:44` 都是 `new MWindowCloseBtnF()`）
##   `MPlusBtnF.as` symbol **600** / `MMinusBtnF.as` symbol **604**（数量框那两颗）
##   `StyleUtil.as:7-12` up 0 / over **+30** / down **−40**；`:43-47` 逐通道 clamp、alpha 行不动；
##   `MButton3.as:103-108` 松手回 **STATE_UP**；`MButton3.as:467-470` 重新可用也钉回 UP；
##   `MButton3.init()` `:135` 手型光标。
##
## 门判三层，**期望值全部写死在本文件**（不从被测件反查 —— 判据的参照值必须自己带）：
##   ① 文本层：`.tscn` 里那个节点块确实挂了 `原版三态钮.gd`、烘了手型、
##      并且常态皮（顺着 `ExtResource` / `SubResource(StyleBoxTexture)` 解到底）== 表里那张；
##   ② 文件层：`<主干>_悬停.png` / `_按下.png` 在盘上、和不透明数与常态一致、
##      三通道和 **悬停 > 常态 > 按下**（方向反了=两张皮放错，等值=有人复制了同一张）；
##   ③ 运行层：把场景实例化挂进树 ⇒ 状态机**真的抄到了主干**（`_形态`>0、`_主干`==期望）、
##      四条信号各**恰好一条**连接、换档落到期望的文件名。
##
## ⚠ ③ 里换档用 `emit_signal("mouse_entered")` 而**不是** `push_input`：这一层判的是
## "节点挂了脚本、脚本接了信号、处理器会把皮换成对的那张"这条**接线**；
## "鼠标真的能打到这颗钮"由有头量具 `开发工具/量换皮件态.gd` 用 `root.push_input` 判
## （同一个键在两处各判各的，缺一个就是半个结论 —— 见记忆「行为门要吃真事件」）。
##
## 跑法：`<godot> --headless --path <工程> --script res://测试/换皮件三态回归测试.gd`

const 三态路 := "res://脚本/界面/组件/原版三态钮.gd"
const 通用 := "res://素材/界面/原版窗口/通用控件/"
const 纹理 := "纹理"
const 图标 := "图标"
const 样式盒 := "样式盒"
## 常态皮来自**全局主题**的 `Button/normal`（节点块里一条 `theme_override_styles` 都没有）。
## 这一族就是工程里所有走主题的标准钮（`MButtonF`）⇒ 判据要连"主题那张槽指向哪张图"一起钉。
const 主题皮 := "主题皮"
const 主题路 := "res://素材/界面/原版主题.tres"

## ── 手抄表：场景 → [[节点路径, 形态, 常态皮主干], …] ─────────────────────────
## 节点路径与形态来自 两轮一次性普查（10-19 夜，本地临时脚本），
## 每一处都手工开场景核对过父节点。
const 表 := {
	"res://场景/界面/功能窗口.tscn": [["遮罩/主窗口/关闭按钮", 图标, 通用 + "关闭按钮"]],
	"res://场景/界面/窗口/双修/双修简介窗.tscn": [["关钮", 纹理, 通用 + "关闭按钮"]],
	"res://场景/界面/窗口/双修/双修选人窗.tscn": [["关钮", 纹理, 通用 + "关闭按钮"],
			["上一页钮", 纹理, 通用 + "上一页", true], ["下一页钮", 纹理, 通用 + "下一页", true]],
	"res://场景/界面/窗口/好友/好友打探窗.tscn": [["关钮", 纹理, 通用 + "关闭按钮"]],
	"res://场景/界面/窗口/好友/好友私聊窗.tscn": [["关钮", 纹理, 通用 + "关闭按钮"]],
	"res://场景/界面/窗口/好友/好友选人窗.tscn": [["关钮", 纹理, 通用 + "关闭按钮"],
			["上一页钮", 纹理, 通用 + "上一页", true], ["下一页钮", 纹理, 通用 + "下一页", true]],
	"res://场景/界面/窗口/家族/家族Boss完成窗.tscn": [["钮关闭", 纹理, 通用 + "关闭按钮"]],
	"res://场景/界面/组件/扩容窗口.tscn": [["关闭", 纹理, 通用 + "关闭按钮"]],
	"res://场景/界面/组件/买卖数量窗.tscn": [["关闭", 图标, 通用 + "关闭按钮"],
			["加", 图标, 通用 + "增加按钮"], ["减", 图标, 通用 + "减少按钮"]],
	"res://场景/界面/组件/商城购买窗.tscn": [["关闭", 图标, 通用 + "关闭按钮"],
			["加", 图标, 通用 + "增加按钮"], ["减", 图标, 通用 + "减少按钮"]],
	## 这两扇的加减原先是**四个样式槽指向同一个 StyleBoxTexture** ⇒ 主题自己没有任何档差；
	## 那颗 `关闭` 原先**连皮都没有**（点得到、看不见）⇒ 本门同时钉"皮补上了"。
	"res://场景/界面/组件/存取金额窗口.tscn": [["关闭", 图标, 通用 + "关闭按钮"],
			["加", 样式盒, 通用 + "增加按钮"], ["减", 样式盒, 通用 + "减少按钮"]],
	"res://场景/界面/组件/拆分窗口.tscn": [["关闭", 图标, 通用 + "关闭按钮"],
			["加", 样式盒, 通用 + "增加按钮"], ["减", 样式盒, 通用 + "减少按钮"]],
	## ── 翻页条那四枚箭头（`MPageFirstBtnF/MPagePreBtnF/MPageNextBtnF/MPageEndBtnF`
	## 四颗类**全部 `extends MButton3`**，10-19 深夜现查）──
	## 第四项 `有灰`：这一族禁用档原版也推 `getGrayFilter()`（`MButton3.as:333-344`），
	## 而箭头是真会被禁的（第一页时 首页/上一页 点不动）⇒ 派生料里有 `_灰`，判据就问它要灰皮；
	## X 与加减那几处实测从不禁用（只禁 确定/购买）、也没烘 `_灰` ⇒ 那种只能要求
	## "回落常态、不许停在上一档"。两种分开钉，否则一边必然假红。
	## ⚠ 一张场景在 `表` 里**只能有一个键**（重复键是 parse 错误）⇒
	## `双修选人窗`、`好友选人窗` 的箭头并到各自上面那一条里去了。
	## ⚠ **`首领窗口` 与五张 `家族*窗` 不在这里** —— 它们各自的控制器里已经有一份
	## 实现好的同类状态机（`首领窗口.gd:217-235` 接四条信号换 `texture_normal`、
	## `家族子窗.gd:60-90` 按 `metadata/skin` 换皮换字色）。再挂一份就是**两条闸互相顶掉**
	## （本门自己就把"某条信号 2 条连接"当红 —— 见 `_判运行` 里那句"宿主又接了一遍"）。
	## ⇒ 那 14 枚本轮**没动**，欠的一条写在 `真值/窗口/挂机设置窗.md` §㉑ 的"未收口"里。
	"res://场景/界面/窗口/商城/商城窗口.tscn": [["分页条/首页", 纹理, 通用 + "首页", true],
			["分页条/上一页", 纹理, 通用 + "上一页", true],
			["分页条/下一页", 纹理, 通用 + "下一页", true],
			["分页条/末页", 纹理, 通用 + "末页", true]],
	## ── 10-20 修行页右窗三颗（`LingquBiguanShouyi.as:131-151` 全是 `MButtonF`
	## = `extends MButton3`（`MButtonF.as:6` 类体只有构造函数）⇒ 同一族一张皮 + ±30/−40）。
	## ⚠ 这三颗与前 31 个件**唯一的差别**：常态皮不在 `.tscn` 里，是**从全局主题的
	##   `Button/normal` 解算出来的**（`theme_override_styles` 一条都没有）⇒
	##   `_判文本` 走 `主题皮` 那一支：先证节点块确实没自带皮，再去 `原版主题.tres` 的文本里
	##   把 `Button/styles/normal` 解到底（参照值自己算，不向被测件要）。
	## 第四项 有灰=false：原版这三颗全程没有一句 `disabled`（`:172-174` 只挂 CLICK），
	## 所以只要求"禁用回落常态、不许停在上一档的皮上"。
	"res://场景/界面/窗口/闭关/领取修行收益.tscn": [["购买", 主题皮, 通用 + "按钮"],
			["单倍领取", 主题皮, 通用 + "按钮"], ["双倍领取", 主题皮, 通用 + "按钮"]],
}
## 运行层要实例化的场景。`功能窗口.tscn` **不在这里**：那是整个 HUD 壳（挂 4500 行控制器、
## 要 GameSession 与存档），无头 instantiate 出来的不是"这颗 X 坏了"就是"壳自己先报错"，
## 红了也说不清测的是谁 ⇒ 那颗 X 的运行证据由有头量具 `量挂机勾态.gd::_走关钮` 出（真 push_input）。
const 运行表 := [
	"res://场景/界面/窗口/双修/双修简介窗.tscn",
	"res://场景/界面/窗口/双修/双修选人窗.tscn",
	"res://场景/界面/窗口/好友/好友打探窗.tscn",
	"res://场景/界面/窗口/好友/好友私聊窗.tscn",
	"res://场景/界面/窗口/好友/好友选人窗.tscn",
	"res://场景/界面/窗口/家族/家族Boss完成窗.tscn",
	"res://场景/界面/组件/扩容窗口.tscn",
	"res://场景/界面/组件/买卖数量窗.tscn",
	"res://场景/界面/组件/商城购买窗.tscn",
	"res://场景/界面/组件/存取金额窗口.tscn",
	"res://场景/界面/组件/拆分窗口.tscn",
	"res://场景/界面/窗口/商城/商城窗口.tscn",
	"res://场景/界面/窗口/闭关/领取修行收益.tscn",
]

var 判数 := 0
var 红数 := 0
var 行 := []


func _判(对: bool, 说明: String) -> void:
	判数 += 1
	if 对:
		return
	红数 += 1
	行.append("红：%s" % 说明)
	print("红：%s" % 说明)


## ① 文本层：节点块里挂了脚本 + 烘了手型 + 常态皮解到底 == 期望那张。
func _判文本(路: String, 件路: String, 形态: String, 主干: String) -> void:
	var 名 := 路.get_file()
	var 件 := 件路.split("/")[-1]
	var 文 := FileAccess.get_file_as_string(路)
	_判(文 != "", "%s 读不到 ⇒ %s/%s 这一条根本没判" % [名, 名, 件])
	if 文 == "":
		return
	## ext_resource：id → path；StyleBoxTexture：id → 它那张 texture 的 ExtResource id
	var 资源 := {}
	for m in RegEx.create_from_string(
			"\\[ext_resource[^\\]]*?path=\"([^\"]+)\"[^\\]]*?id=\"([^\"]+)\"").search_all(文):
		资源[m.get_string(2)] = m.get_string(1)
	var 盒皮 := {}
	var 正盒 := RegEx.create_from_string(
			"\\[sub_resource type=\"StyleBoxTexture\" id=\"([^\"]+)\"\\]\\ntexture = ExtResource\\(\"([^\"]+)\"\\)")
	for m in 正盒.search_all(文):
		盒皮[m.get_string(1)] = m.get_string(2)
	var 起 := 文.find("[node name=\"%s\"" % 件)
	_判(起 >= 0, "%s/%s 节点块在这张 .tscn 里找不到（表写错或节点被改名）" % [名, 件])
	if 起 < 0:
		return
	var 下 := 文.find("\n[node ", 起)
	var 块 := 文.substr(起, (下 - 起) if 下 > 0 else 文.length() - 起)
	_判(块.find("script = ExtResource(") >= 0, "%s/%s 节点块里没有 script 行 ⇒ 状态机没挂上" % [名, 件])
	var 脚本id := ""
	var m2 := RegEx.create_from_string("script = ExtResource\\(\"([^\"]+)\"\\)").search(块)
	if m2 != null:
		脚本id = 资源.get(m2.get_string(1), "")
	_判(脚本id == 三态路, "%s/%s 挂的脚本应是 %s，实得 %s" % [名, 件, 三态路, 脚本id])
	_判(块.contains("mouse_default_cursor_shape = 2"),
			"%s/%s 要烘手型（`MButton3.init()` `:135`），节点块里没这条" % [名, 件])
	var 实 := ""
	if 形态 == 主题皮:
		## 这一族**不许**在节点块里自带皮：`add_theme_stylebox_override` / 场景里的
		## `theme_override_styles/*` 会无条件压过主题，主题改了这颗不动（工程铁律，见
		## `脚本/界面/窗口/界面皮肤.gd` 文件头）。
		_判(块.find("theme_override_styles/") < 0 and 块.find("icon = ") < 0,
				"%s/%s 该走主题 `Button` 族，节点块里却有自带皮 ⇒ 主题的态改动在这一颗上无效" % [名, 件])
		实 = _解主题常态()
		_判(实 == 主干 + ".png",
				"%s/%s 全局主题 `Button/normal` 应是 %s.png，实得 %s（从 %s 的文本解到底）" % [
				名, 件, 主干.get_file(), 实 if 实 != "" else "〈主题里查不到〉", 主题路.get_file()])
	else:
		实 = _解常态皮(块, 资源, 盒皮)
		_判(实 == 主干 + ".png", "%s/%s 常态皮应是 %s，实得 %s（形态 %s）" % [名, 件, 主干, 实, 形态])


## 从 `素材/界面/原版主题.tres` 的**文本**里把 `Button/styles/normal` 解到那张 png。
## 为什么现读文本：主题由 `开发工具/生成界面主题.gd` 产出、子资源 id 会随序号漂，
## 而这条判据要钉的是"哪张图"，不是"哪个 id" ⇒ 按属性名取、自己算，不向被测件要参照值。
func _解主题常态() -> String:
	var 文 := FileAccess.get_file_as_string(主题路)
	if 文 == "":
		return ""
	var m := RegEx.create_from_string(
			"Button/styles/normal = SubResource\\(\"([^\"]+)\"\\)").search(文)
	if m == null:
		return ""
	var 盒头 := "[sub_resource type=\"StyleBoxTexture\" id=\"%s\"]" % m.get_string(1)
	var 起 := 文.find(盒头)
	if 起 < 0:
		return ""
	var 段 := 文.substr(起, 文.find("[", 起 + 盒头.length()) - 起)
	var 皮 := RegEx.create_from_string("texture = ExtResource\\(\"([^\"]+)\"\\)").search(段)
	if 皮 == null:
		return ""
	for e in RegEx.create_from_string(
			"\\[ext_resource[^\\]]*?path=\"([^\"]+)\"[^\\]]*?id=\"([^\"]+)\"").search_all(文):
		if e.get_string(2) == 皮.get_string(1):
			return e.get_string(1)
	return ""


func _解常态皮(块: String, 资源: Dictionary, 盒皮: Dictionary) -> String:
	var m := RegEx.create_from_string("(?:icon|texture_normal) = ExtResource\\(\"([^\"]+)\"\\)").search(块)
	if m != null:
		return String(资源.get(m.get_string(1), ""))
	m = RegEx.create_from_string("theme_override_styles/normal = SubResource\\(\"([^\"]+)\"\\)").search(块)
	if m == null:
		return ""
	var 内 := String(盒皮.get(m.get_string(1), ""))
	return String(资源.get(内, ""))


## ② 文件层：两张派生皮**在盘上**、不透明数与常态一致、亮度方向对。
## ⚠ 一律走 `FileAccess` + `Image.load_png_from_buffer` 直接读那张 `.png`，**不走 `ResourceLoader`**：
## 引擎的导入缓存（`.godot/imported/*.ctex`）在源文件被挪走之后**照样 load 得出来**
## （变异实测乙档：`增加按钮_悬停.png` 已不在盘上，`ResourceLoader.exists/load` 仍然成功 ⇒ 门全绿）。
## 素材对不对只能问文件本身，问引擎等于让引擎替素材作证。
func _判文件(主干: String, 有灰: bool) -> void:
	var 基名 := 主干.get_file()
	var 档s := ["", "_悬停", "_按下"] + (["_灰"] if 有灰 else [])
	for 档 in 档s:
		_判(FileAccess.file_exists(主干 + 档 + ".png"),
				"%s%s.png 这张文件不在盘上 ⇒ 那颗钮这一档只能回落常态，看着就是「点了没反应」（烘：开发工具/生成关钮态图.py、生成加减钮态图.py、生成翻页钮态图.py）" % [基名, 档])
	var 常 := _皮统计(主干 + ".png")
	var 悬 := _皮统计(主干 + "_悬停.png")
	var 按 := _皮统计(主干 + "_按下.png")
	if not 常.is_empty() and not 悬.is_empty() and not 按.is_empty():
		_判(int(悬["不透明"]) == int(常["不透明"]) and int(按["不透明"]) == int(常["不透明"]),
				"%s 三档的不透明像素数应相同（加性滤镜不动 alpha）：常态 %d / 悬停 %d / 按下 %d" % [
				基名, int(常["不透明"]), int(悬["不透明"]), int(按["不透明"])])
		_判(int(悬["和"]) > int(常["和"]) and int(按["和"]) < int(常["和"]),
				"%s 亮度方向要 悬停 > 常态 > 按下（+30 / −40），实得 %d / %d / %d ⇒ 等值=有人把同一张复制成三张" % [
				基名, int(悬["和"]), int(常["和"]), int(按["和"])])


func _皮统计(路: String) -> Dictionary:
	if not FileAccess.file_exists(路):
		return {}
	var 名 := FileAccess.open(路, FileAccess.READ)
	if 名 == null:
		return {}
	var 图 := Image.new()
	if 图.load_png_from_buffer(名.get_buffer(名.get_length())) != OK:
		return {}
	var 数 := 0
	var 和 := 0
	for y in 图.get_height():
		for x in 图.get_width():
			var c := 图.get_pixel(x, y)
			var a := int(round(c.a * 255.0))
			if a == 0:
				continue
			数 += 1
			和 += int(round(c.r * 255.0)) + int(round(c.g * 255.0)) + int(round(c.b * 255.0))
	return {"不透明": 数, "和": 和}


## ③ 运行层。
func _判运行(路: String) -> void:
	var 装 := load(路) as PackedScene
	if 装 == null:
		_判(false, "%s 装不出来 ⇒ 这一张的运行层整段没判" % 路)
		return
	var 页 := 装.instantiate() as Control
	if 页 == null:
		_判(false, "%s instantiate 出来不是 Control" % 路)
		return
	root.add_child(页)
	## ⚠ **必须先等两帧**：`root.add_child()` 之后同一调用栈里，节点自己脚本的 `_ready()`
	## 还没跑（10-19 深夜两拍探针现查：当时 `主干=[]`、四条信号 0 条连接；两帧之后才有值）。
	## 不 await 就是拿"`_ready` 还没跑"当"状态机没接"来判 ⇒ 假红；
	## 所以 `_跑` 那侧调用这里是 `await _判运行(路)`（协程不 await = 没跑完就当跑完）。
	await process_frame
	await process_frame
	for 项 in 表[路]:
		var 件路: String = 项[0]
		var 形态: String = 项[1]
		var 主干: String = 项[2]
		var 名 := 路.get_file()
		var 件 := 页.get_node_or_null(件路) as Node
		if 件 == null:
			_判(false, "%s/%s 运行期查无此节点 ⇒ 表与场景对不上" % [名, 件路])
			continue
		_判(件.get_script() != null and str(件.get_script().resource_path) == 三态路,
				"%s/%s 运行期挂的脚本应是 %s，实得 %s" % [
				名, 件路, 三态路, "<无>" if 件.get_script() == null else str(件.get_script().resource_path)])
		## `_形态`>0 = 状态机在 `_ready()` 真抄到了常态皮。抄不到它**什么都不断**（静默不接），
		## 所以这一条是这一层的地基：没有它，后面四条换档判据会全绿而那颗钮根本没接上。
		_判(int(件.get("_形态")) > 0, "%s/%s 状态机没抄到常态皮（`_形态`=%d）⇒ 后面换档根本不会发生" % [
				名, 件路, int(件.get("_形态"))])
		_判(str(件.get("_主干")) == 主干, "%s/%s 状态机抄到的主干应是 %s，实得 %s" % [
				名, 件路, 主干, str(件.get("_主干"))])
		for 信 in ["mouse_entered", "mouse_exited", "button_down", "button_up"]:
			var n := 件.get_signal_connection_list(信).size()
			_判(n == 1, "%s/%s 的 `%s` 要**恰好一条**连接，实得 %d（0=没接，2=宿主又接了一遍会换两次皮）" % [
					名, 件路, 信, n])
		_判(件.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
				"%s/%s 运行期手型应是 CURSOR_POINTING_HAND，实得 %d" % [名, 件路, 件.mouse_default_cursor_shape])
		_判(_生效图(件, 形态) == 主干.get_file() + ".png",
				"%s/%s 开跑应挂常态皮 %s.png，实得 %s" % [
				名, 件路, 主干.get_file(), _生效图(件, 形态)])
		件.emit_signal("mouse_entered")
		_判(_生效图(件, 形态) == 主干.get_file() + "_悬停.png",
				"%s/%s 悬停 ⇒ 实际生效的图应是 _悬停，实得 %s" % [名, 件路, _生效图(件, 形态)])
		件.emit_signal("button_down")
		_判(_生效图(件, 形态) == 主干.get_file() + "_按下.png",
				"%s/%s 按下 ⇒ 应是 _按下，实得 %s" % [名, 件路, _生效图(件, 形态)])
		件.emit_signal("button_up")
		_判(_生效图(件, 形态) == 主干.get_file() + ".png",
				"%s/%s 松手（鼠标还压在钮上）要回 **STATE_UP = 常态**（`MButton3.as:103-108`），实得 %s" % [
				名, 件路, _生效图(件, 形态)])
		件.emit_signal("mouse_exited")
		_判(_生效图(件, 形态) == 主干.get_file() + ".png",
				"%s/%s 移开 ⇒ 要回常态，实得 %s（停在悬停档=松手还亮着那一族）" % [
				名, 件路, _生效图(件, 形态)])
		## 禁用档：表里第四项说有没有 `_灰`。箭头那一族真会被禁（第一页时 首页/上一页 点不动），
		## 原版禁用推 `getGrayFilter()`（`MButton3.as:333-344`）⇒ 必须落到灰皮；
		## X / 加减那几处实测从不禁用、也没烘灰皮 ⇒ 只能要求"回落常态、不许停在上一档的皮上"。
		var 有灰: bool = 项.size() > 3 and bool(项[3])
		var 禁期 := 主干.get_file() + ("_灰.png" if 有灰 else ".png")
		(件 as BaseButton).disabled = true
		件.call("刷")
		_判(_生效图(件, 形态) == 禁期,
				"%s/%s 禁用档应是 %s（有灰=%s），实得 %s ⇒ 停在上一档就是「灰掉了还亮着」" % [
				名, 件路, 禁期, str(有灰), _生效图(件, 形态)])
		(件 as BaseButton).disabled = false
		件.call("刷")
		_判(_生效图(件, 形态) == 主干.get_file() + ".png",
				"%s/%s 重新可用要回 **STATE_UP = 常态**（`MButton3.as:467-470`），实得 %s" % [
				名, 件路, _生效图(件, 形态)])
	root.remove_child(页)
	页.queue_free()


func _生效图(件: Node, 形态: String) -> String:
	match 形态:
		纹理:
			var t: Texture2D = (件 as TextureButton).texture_normal
			return t.resource_path.get_file() if t != null else "〈没图〉"
		图标:
			var i: Texture2D = (件 as Button).icon
			return i.resource_path.get_file() if i != null else "〈没图〉"
	var 盒: StyleBox = (件 as Button).get_theme_stylebox("normal")
	if 盒 is StyleBoxTexture and (盒 as StyleBoxTexture).texture != null:
		return str((盒 as StyleBoxTexture).texture.resource_path.get_file())
	return "〈没图〉"


func _initialize() -> void:
	print("换皮件三态门开始")
	_跑()


func _跑() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var 件数 := 0
	var 主干集 := {}
	for 路 in 表:
		for 项 in 表[路]:
			件数 += 1
			var 主 := String(项[2])
			if not 主干集.has(主):
				主干集[主] = false
			if 项.size() > 3 and bool(项[3]):
				主干集[主] = true
			_判文本(路, String(项[0]), String(项[1]), 主)
	for 主 in 主干集:
		_判文件(String(主), bool(主干集[主]))
	for 路 in 运行表:
		if not 表.has(路):
			_判(false, "运行表里的 %s 没写进手抄表 ⇒ 这张场景一条都没判" % 路)
			continue
		await _判运行(路)
	## 自计到：件数与表必须对得上，否则"表少写一行"这种坏法会让整段静默少判
	## （记忆：每段必须钉『判满 N 条』）。数取自 10-19 深夜两条普查：
	## 窗壳 X 与加减 = 20 个件（12 张场景 + 2 处代码建钮）、翻页箭头 = 22 个件（8 张场景）、
	## 修行页右窗三颗 `MButtonF` = 3 个件（10-20，走主题皮那一支）。
	_判(件数 == 31, "壬：手抄表要判满 31 个件（20 颗 X/加减 + 8 枚翻页箭头 + 3 颗标准钮），实得 %d ⇒ 表被删了行" % 件数)
	_判(主干集.size() == 8, "壬：常态皮应正好八张（关闭/增加/减少 + 首页/上一页/下一页/末页 + 按钮），实得 %d" % 主干集.size())
	print("换皮件三态门：判 %d 条，红 %d 条（件 %d / 常态皮 %d 张 / 运行场景 %d 张）" % [
			判数, 红数, 件数, 主干集.size(), 运行表.size()])
	quit(0 if 红数 == 0 else 1)
