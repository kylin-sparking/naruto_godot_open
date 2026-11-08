extends SceneTree

## 聊天正文的服务端 HTML → BBCode 与「通告位不进聊天」（用户 2026-10-21 报修 2.3）。
##
## 报的现象：写轮眼突破时聊天里那句是 `font color = "ffff00" 木叶忍者 成功将写轮眼 进阶至 …`
## —— 尖括号和 `#` 全没了、英文标签当正文显示。
##
## 两条根因（都在 `脚本/界面/聊天面板.gd`，不在解析层）：
##   A. **正文从没过翻译器**。原版聊天是 `tf.htmlText`（`ChatPane.as` 收 `ChatUtil.formatMessage`
##      的结果），HTML 由 Flash 自己渲染；本工程 `RichTextLabel` 吃 BBCode，`<font …>` 不是标签
##      ⇒ 整串原样上屏。`_format_chat_message` 的两个分支（系统/公告、普通频道）都把 `body` 裸拼，
##      `_on_notification` 同样裸拼。
##   B. **`PUB_NOTICE(1)` 被当成聊天位**。服务端每条稀有事件**成对**发两帧
##      （`fake_flash_server.py:40360-40374`）：`1:4:正文` 与 `1:1:[JH]同一句`。原版
##      `UI.as:339-354` 把 `PUB_NOTICE` 只喂 `addScrollAnnounce` / `addChengJIuAnnounce`
##      （`[JH]` 先 `replace` 掉）与 `selectInfoWindowNoticeData`，**没有一条走 `chatPane.addMsg`**
##      ⇒ 这边照收，就变成聊天里同一句出现两遍、其中一遍还糊着字面 `[JH]`。
##
## 这条门钉七组事：
##   ① 逐字夹具：`_rare_event_markup` 真身输出（外层黄 + 人名绿 + 【】内粉 + 数字绿）翻成 BBCode
##      后必须等于钉死的那串 —— 嵌套色一段都不能丢，且上屏后**不含** `font` / `<` / `"`；
##   ② 真渲染：`_chat_log.get_parsed_text()` 就是玩家读到的那行字；
##   ③ 成对帧只落一条：按服务端顺序喂 `4` + `1` ⇒ 数组里只有 `position=4` 那条，全文无 `[JH]`；
##   ④ 跳过不是全跳：`8`(GENERAL) 与公告位照样进，`512`(CHAR_NOTICE) 仍跳过（§3.204 那半不能退）；
##   ⑤ 喇叭不进消息列表、走独立浮条（`ChatSpeakerPane.as`），浮条那行同样要翻译；
##   ⑥ 表情与翻译的**先后**（字面钉 `_parse_chat_faces(富文本.译文为BBCode(原文))`）；
##   ⑦ 旧账不伪装成原版：`1024`(DYNAMIC_INFO) 目前仍进数组、但综合页看不到（原版该给 noticePnl）；
##      翻译**只加在显示层** —— `后端连接.gd` 里不许出现 `富文本`。
##
## 运行：Godot --headless --path . --script res://测试/系统消息富文本回归测试.gd

const 面板场景 := "res://场景/界面/聊天面板.tscn"
const 面板脚本 := "res://脚本/界面/聊天面板.gd"
const 后端脚本 := "res://脚本/单例/后端连接.gd"
const 富文本 := preload("res://脚本/界面/富文本.gd")

## 服务端 `:52917` 那句文案经 `:40252 _rare_event_markup` 上色的**逐字原文**（门当夹具用）。
const 进阶原文 := "<font color=\"#ffff00\"><font color=\"#00ff00\">木叶英雄</font>成功将【<font color=\"#ff5498\">写轮眼</font>】进阶至<font color=\"#00ff00\">3阶</font>！</font>"
## 上面那串过一遍共享翻译器的期望（嵌套四层，一段颜色都不许丢）。
const 进阶BBCode := "[color=#ffff00][color=#00ff00]木叶英雄[/color]成功将【[color=#ff5498]写轮眼[/color]】进阶至[color=#00ff00]3阶[/color]！[/color]"
const 系统头 := "[color=#b0e0e6]『系统』[/color][color=#ffffff]"

var 通过数 := 0
var 红: Array[String] = []
var 存档前 := ""


func _判(条件: bool, 说明: String, 补: String = "") -> void:
	通过数 += 1
	if not 条件:
		红.append(说明 + ("　⇒ " + 补 if 补 != "" else ""))


func _等(n: int) -> void:
	for _i in range(n):
		await process_frame


func _存档字节() -> String:
	var f := FileAccess.open("user://玩家数据.json", FileAccess.READ)
	return "" if f == null else f.get_as_text()


func _清(面板) -> void:
	面板._chat_messages.clear()
	面板._render_chat_messages()


func _帧(面板) -> Dictionary:
	return 面板._chat_messages[面板._chat_messages.size() - 1]


func _收(面板, 类型: int, 位: int, 正文: String, 名: String = "系统") -> void:
	面板.call("_on_backend_chat", {"type": 类型, "positions": 位, "message": 正文, "name": 名})


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)		# 无头也要给视口尺寸，否则聊天栏摆位拿 0
	存档前 = _存档字节()
	var 面板 := (load(面板场景) as PackedScene).instantiate()
	root.add_child(面板)
	for _i in range(5):
		await process_frame
	if 面板 == null or not 面板.has_method("_format_chat_message"):
		_收尾("聊天面板场景没长出来（" + 面板场景 + "）")
		return
	if 面板._chat_log == null:
		_收尾("`消息窗口/消息区` 没取到 —— 下面所有「玩家实际看到什么」的腿全成空测")
		return
	await _量翻译(面板)
	await _量成对帧(面板)
	await _量跳过范围(面板)
	await _量系统提示(面板)
	await _量喇叭(面板)
	await _量表情(面板)
	_量字面()
	_收尾()


## ── ① 逐字夹具：翻译 + 上屏文本 ────────────────────────────────────────────
func _量翻译(面板) -> void:
	_判(富文本.译文为BBCode(进阶原文) == 进阶BBCode,
			"共享翻译器把这条服务端原文翻成钉死的那串（嵌套四层、顺序对）",
			富文本.译文为BBCode(进阶原文))
	var 得: String = 面板.call("_format_chat_message", "系统", "忍者", 进阶原文, true)
	_判(得 == 系统头 + 进阶BBCode + "[/color]",
			"『系统』分支整串逐字 = 玩家名色标签 + 白底 + 翻译后的正文", 得)
	_判(not 得.contains("<font") and not 得.contains("font color") and not 得.contains("\""),
			"结果里没有尖括号标签、没有 `font color`、没有引号（用户报的现象就是这个）", 得)
	_判(得.contains("[color=#ffff00]") and 得.contains("[color=#ff5498]") and 得.count("[color=") == 6,
			"外黄/【】粉/两处绿全保留，`[color=` 正好 6 对（玩家名 + 白底 + 4 段正文色）", str(得.count("[color=")))
	var 普: String = 面板.call("_format_chat_message", "普通", "木叶英雄", 进阶原文, false)
	_判(普.contains("[color=#ffffff]『普通』[/color]") and 普.contains(进阶BBCode) \
			and not 普.contains("<font"),
			"普通频道那支（有发言人的句式）同样过翻译 —— 修的不能只有系统那一路", 普)
	_清(面板)
	_收(面板, 1, 4, 进阶原文)
	await _等(2)
	var 屏: String = 面板._chat_log.get_parsed_text()
	_判(屏 == "『系统』木叶英雄成功将【写轮眼】进阶至3阶！",
			"上屏解析文本就是这一句人话（没有标签残渣）", 屏)


## ── ③ 服务端成对两帧：只落 position=4 那一条，且不带 [JH] ──────────────────
func _量成对帧(面板) -> void:
	_清(面板)
	# `fake_flash_server.py:40371-40372` 的发送顺序就是 comp(4) 在前、pub(1) 在后
	_收(面板, 1, 4, 进阶原文)
	_收(面板, 1, 1, "[JH]" + 进阶原文)
	_判(面板._chat_messages.size() == 1,
			"成对两帧 ⇒ 聊天里**只有** `positions=4` 那一条（PUB_NOTICE 不进聊天，原版 `UI.as:339-354`）",
			str(面板._chat_messages.size()))
	if 面板._chat_messages.size() == 1:
		_判(int(_帧(面板).get("position", -1)) == 4 and String(_帧(面板).get("channel", "")) == "系统",
				"留下的那条是 MISC(4)/『系统』，不是被顶掉的另一条")
	var 全文 := ""
	for 项 in 面板._chat_messages:
		全文 += String(项.get("bbcode", ""))
	_判(not 全文.contains("[JH]"), "聊天里不出现字面 `[JH]`（原版是`replace`掉再画通告条的）")
	_清(面板)
	_收(面板, 1, 1, "[JH]" + 进阶原文)
	_判(面板._chat_messages.is_empty(),
			"单独喂 `positions=1` ⇒ 一条都不落（跳过发生在入口，不靠渲染端过滤）")


## ── ④ 跳过只限 1 与 512：其它位必须照常进 ──────────────────────────────────
func _量跳过范围(面板) -> void:
	_清(面板)
	_收(面板, 3, 8, 进阶原文, "木叶英雄")
	_判(面板._chat_messages.size() == 1, "`GENERAL(8)` 普通频道照常进（跳过没做成\"全跳\"）",
			str(面板._chat_messages.size()))
	_清(面板)
	_收(面板, 2, 4, 进阶原文)
	_判(面板._chat_messages.size() == 1 and String(_帧(面板).get("channel", "")) == "公告",
			"『公告』(type=2) 照常进、正文同样翻译")
	_清(面板)
	_收(面板, 1, 512, 进阶原文)
	_判(面板._chat_messages.is_empty(),
			"`CHAR_NOTICE(512)` 仍不进聊天（§3.204 那半没退）")


## ── ⑤ 系统提示（会话口子）也走同一道翻译 ───────────────────────────────────
func _量系统提示(面板) -> void:
	_清(面板)
	面板.call("_on_notification", 进阶原文)
	_判(面板._chat_messages.size() == 1 and int(_帧(面板).get("position", -1)) == 4,
			"`_on_notification` 落成一条 MISC(4) 的『系统』行")
	var 文 := String(_帧(面板).get("bbcode", "")) if 面板._chat_messages.size() == 1 else ""
	_判(文.contains(进阶BBCode) and not 文.contains("<font"),
			"提示那一路也翻译了 —— 它是服务端 HTML 的第二个入口（`_handle_chat_text` 原样转过来）", 文)


## ── ⑥ 喇叭：独立浮条、不进消息列表，浮条那行同样要翻译 ─────────────────────
func _量喇叭(面板) -> void:
	_清(面板)
	_收(面板, 8, 256, "<font color=\"#e15204\">喇叭也要翻译</font>")
	_判(面板._chat_messages.is_empty(), "喇叭不进 `_chat_messages`（原版 `ChatSpeakerPane` 是浮条）")
	var 条: Node = 面板._喇叭列表
	_判(条 != null and 条.get_child_count() == 1, "浮条长出一行", str(条.get_child_count() if 条 != null else -1))
	if 条 != null and 条.get_child_count() == 1:
		var 行 := 条.get_child(0) as RichTextLabel
		_判(行 != null and 行.get_parsed_text().ends_with("喇叭也要翻译") and not 行.get_parsed_text().contains("font"),
				"浮条那行也没有标签残渣", 行.get_parsed_text() if 行 != null else "无")


## ── ⑦ 表情与翻译共存：`<font>` 里的 `[fN]` 要 both 保住 ────────────────────
func _量表情(面板) -> void:
	# `get_script_constant_map()` 是 **Script** 上的方法（不是 `Object.get`），走面板自己的脚本
	var 脸路 := String((面板.get_script() as GDScript).get_script_constant_map().get("FACE_PATH", ""))
	var 有脸 := 脸路 != "" and ResourceLoader.exists(脸路 % 1)
	var 得: String = 面板.call("_format_chat_message", "普通", "甲", "<font color=\"#00ff00\">加油[f1]</font>", true)
	_判(得.contains("[color=#00ff00]加油") and not 得.contains("<font"),
			"翻译先跑：`<font>` 里的表情占位跟着颜色段一起出来", 得)
	if 有脸:
		_判(得.contains("[img=24x24]"), "表情后跑：`[f1]` 仍换成 24×24 的图（顺序钉在字面那组）", 得)
	else:
		_判(得.contains("[f1]"), "素材缺脸时按原样留 `[f1]`（`_parse_chat_faces` 的既有兜底）", 得)


## ── ⑧ 字面钉：改动本身不许被"顺手优化"掉；旧账要留在明面上 ─────────────────
func _量字面() -> void:
	var 文 := FileAccess.get_file_as_string(面板脚本)
	_判(文.contains("const POS_PUB_NOTICE := 1"),
			"`const POS_PUB_NOTICE := 1` 在（`MessagePosition.as:6` 的位值，注释里的出处不能只靠注释活着）")
	_判(文.contains("if 位 == POS_PUB_NOTICE:") and 文.contains("const POS_MISC := 4"),
			"`_on_backend_chat` 里那记跳过在（按常量、不是按字面 1）")
	_判(文.contains("const 富文本 := preload(\"res://脚本/界面/富文本.gd\")"),
			"用的是**共享**翻译器 `富文本.gd`，不是聊天面板里再抄一份正则")
	_判(文.contains("return _parse_chat_faces(富文本.译文为BBCode(原文))"),
			"`_正文` 那一步的顺序 = 先 BBCode 后表情")
	_判(文.count("_正文(body)") == 2, "`_format_chat_message` 两个分支都走 `_正文`（3 个入口里的 2 个）",
			str(文.count("_正文(body)")))
	_判(文.count("_正文(message)") == 1, "`_on_notification` 也走 `_正文`（第 3 个入口）",
			str(文.count("_正文(message)")))
	_判(not 文.contains("% [channel_color, body]") and not 文.contains("% [CHAT_NAME_COLOR, message]"),
			"老的裸拼形状已经没了（`body`/`message` 不再直接塞进 bbcode）")
	_判(文.contains("const POS_CHAR_NOTICE := 512") and 文.contains("if 位 == POS_CHAR_NOTICE:"),
			"512 那记跳过还在（别在补 1 的时候把它顶掉）")
	_判(文.contains("§3.239 F"), "PUB_NOTICE 那条注释把「中部通告/滚动条/信息查询窗没移植」写成旧账挂编年史")
	_判(文.contains("int(message.get(\"positions\", POS_GENERAL))"),
			"位值仍然按服务端字段读（跳过是**分派**，不是把 1 硬编码成丢弃）")
	var 后端文 := FileAccess.get_file_as_string(后端脚本)
	_判(not 后端文.contains("译文为BBCode") and not 后端文.contains("脚本/界面/富文本.gd"),
			"翻译只加在显示层：`后端连接.gd` 不引翻译器 —— 解析层保持原样透传（`fields[3]` 直接进信号）")
	# 旧账要"看得见地错着"：现在 1024 只是进了数组、综合页看不到
	_判(not 文.contains("POS_DYNAMIC"), "DYNAMIC_INFO(1024)/COPY_NOTICE(2048) 还没按 `UI.as` 分派（§3.239 F 旧账，别把它读成已做完）")


func _收尾(致命: String = "") -> void:
	var 现 := _存档字节()
	_判(现 == 存档前, "跑完 `user://玩家数据.json` **字节没变**（门只喂消息，不落盘）")
	if 致命 != "":
		红.append(致命)
	for 一 in 红:
		if 一 != "":
			print("!! " + 一)
	print("系统消息富文本回归：%s（判 %d 项，红 %d 项）" % ["通过" if 红.is_empty() else "不通过", 通过数, 红.size()])
	quit(1 if not 红.is_empty() else 0)
