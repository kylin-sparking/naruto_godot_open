## Flash 富文本 → BBCode（`脚本/界面/富文本.gd`）。
##
## 两条路子：
##   A **真实数据**：把 `数据/**/*.json` 里**所有含 `<` 的字符串**全过一遍转换器，
##     断言输出里**一个尖括号标签都不剩**（原版这些串是喂给 `tf.htmlText` 的，
##     我们这边一旦漏掉一种写法，玩家就会在界面上看到 `<FONT COLOR="#00FF00">` 这种原文）。
##     这一条的价值在于**覆盖面是数据给的**，不靠我列全标签。
##   B **逐条手算**：把仓库里真实出现过的每种写法各钉一条期望输出。
extends SceneTree

const 富文本 := preload("res://脚本/界面/富文本.gd")

var _failures: Array[String] = []
var _checked := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	_checked += 1
	if not ok:
		_failures.append(message)

func _run() -> void:
	_A_真实数据()
	_B_逐条手算()
	if _failures.is_empty():
		print("富文本回归测试：通过（%d 条断言）" % _checked)
		quit(0)
		return
	for failure in _failures:
		if not failure.is_empty():
			printerr(failure)
	quit(1)

## 把 `数据/` 下每个 json 里的字符串抠出来，凡含 `<` 的都过一遍转换器。
func _A_真实数据() -> void:
	var 目录 := DirAccess.open("res://数据")
	if 目录 == null:
		_check(false, "打不开 res://数据")
		return
	var 总数 := 0
	var 残留 := 0
	var 样例 := ""
	var 文件数 := 0
	for 文件 in _递归收集("res://数据"):
		var 原文 := FileAccess.get_file_as_string(文件)
		if 原文.is_empty():
			continue
		文件数 += 1
		for 串 in _抠字符串(原文):
			if not 串.contains("<"):
				continue
			总数 += 1
			var 出 := 富文本.译文为BBCode(串)
			if _有残留标签(出):
				残留 += 1
				if 样例.is_empty():
					样例 = "%s ← %s" % [出.substr(0, 120), 串.substr(0, 120)]
	_check(文件数 > 100, "应该扫到一百多个数据文件（实际 %d）" % 文件数)
	_check(总数 > 150, "含 `<` 的字符串应有一百多条（实际 %d）" % 总数)
	_check(残留 == 0, "转换后不该剩尖括号标签（剩 %d 条，例：%s）" % [残留, 样例])

func _有残留标签(文: String) -> bool:
	var 正则 := RegEx.new()
	正则.compile("<[a-zA-Z/][^>]*>")
	return 正则.search(文) != null

func _递归收集(目录: String) -> Array[String]:
	var 结果: Array[String] = []
	var 访问 := DirAccess.open(目录)
	if 访问 == null:
		return 结果
	访问.list_dir_begin()
	var 名 := 访问.get_next()
	while 名 != "":
		if 名.begins_with("."):
			名 = 访问.get_next()
			continue
		var 全 := "%s/%s" % [目录, 名]
		if 访问.current_is_dir():
			结果.append_array(_递归收集(全))
		elif 名.ends_with(".json"):
			结果.append(全)
		名 = 访问.get_next()
	访问.list_dir_end()
	return 结果

## 从 json 文本里抠出所有**字符串值**（粗抠：找引号对，允许 `\"` 转义）。
## 只为"喂给转换器"用，不要求解析正确 —— 抠多了也无妨（不含 `<` 的会被跳过）。
func _抠字符串(文本: String) -> Array[String]:
	var 结果: Array[String] = []
	var 当前 := ""
	var 在串内 := false
	var i := 0
	while i < 文本.length():
		var c := 文本[i]
		if not 在串内:
			if c == "\"":
				在串内 = true
				当前 = ""
		elif c == "\\" and i + 1 < 文本.length():
			当前 += 文本[i + 1]
			i += 1
		elif c == "\"":
			在串内 = false
			结果.append(当前)
		else:
			当前 += c
		i += 1
	return 结果

## 逐条钉死 —— 每一条都是仓库里**真实出现过**的写法（次数见 `富文本.gd` 文件头）。
func _B_逐条手算() -> void:
	var 例 := [
		["<br/>", "\n", "换行"],
		["a<br>b", "a\nb", "不带斜杠的 br"],
		["<font color='#FFF102'>甲</font>", "[color=#fff102]甲[/color]", "单引号小写 font"],
		["<font color=\"#00ff00\">甲</font>", "[color=#00ff00]甲[/color]", "双引号小写 font"],
		["<FONT COLOR=\"#00FF00\">甲</FONT>", "[color=#00ff00]甲[/color]", "全大写 FONT COLOR"],
		["<FONT  COLOR=\"#00FF00\">甲</FONT>", "[color=#00ff00]甲[/color]", "双空格"],
		["<FONT COLOR= \"#00FF00\">甲</FONT>", "[color=#00ff00]甲[/color]", "等号后带空格"],
		["<font>甲</font>", "甲", "无属性的 font 也该剥干净"],
		["<font size ='18' color='#990099'>甲</font>",
			"[color=#990099][font_size=18]甲[/font_size][/color]", "size 在前"],
		["<font size ='14' color='#a208d'>甲</font>",
			"[font_size=14]甲[/font_size]", "5 位色值补不出来 ⇒ 只丢样式、不吐半截标签"],
		["<font color='#6699'>甲</font>", "甲", "4 位色值**不猜**（Flash 与 CSS 的短色值规矩不同）⇒ 只丢样式"],
		["<font color='#ff'>甲</font>", "甲", "2 位色值同上"],
		["<font color='#AABBCC'>甲</font>", "[color=#aabbcc]甲[/color]", "6 位色值原样（大小写归一）"],
		["<b>甲</b>", "[b]甲[/b]", "加粗"],
		["<textformat leading='15'>甲</textformat>", "甲", "样式块整块剥掉"],
		["<a href='#'>甲</a>", "甲", "链接剥成纯文字"],
		["<font color='#ff9100'>甲</font><br/>乙", "[color=#ff9100]甲[/color]\n乙", "混排"],
		["<font color='#FFF102'>甲</font>乙</font>", "[color=#fff102]甲[/color]乙", "多余的闭标签不该吞掉后面的字"],
		["<br>", "\n", "无斜杠 br"],
	]
	for 项 in 例:
		var 得: String = 富文本.译文为BBCode(项[0])
		_check(得 == 项[1], "%s：期望 %s，实际 %s" % [项[2], JSON.stringify(项[1]), JSON.stringify(得)])
	# 字面 `\n`（两个字符）按 `BaseUtil.formatStr()` 也算换行
	_check(富文本.译文为BBCode("甲\\n乙") == "甲\n乙", "字面 \\n 也要当换行")
	# 真换行原样保留
	_check(富文本.译文为BBCode("甲\n乙") == "甲\n乙", "真换行原样保留")
	# 不含任何标签的普通文案必须原样返回（不能顺手改字）
	_check(富文本.译文为BBCode("普通的说明文字") == "普通的说明文字", "无标签文案应原样返回")
