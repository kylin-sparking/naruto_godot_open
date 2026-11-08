extends RefCounted

## Flash 富文本 → Godot BBCode 的**唯一一份**转换。
##
## 原版提示框是 `tf.htmlText = BaseUtil.formatStr(value)`（`MToolTipText.setValue()`）——
## 也就是说**文案里本来就带 HTML**，交给 Flash 渲染。我们的 `RichTextLabel` 吃 BBCode，
## 中间必须有这一层。
##
## 这段原来只长在 `功能窗口.gd` 里（叫 `译文为BBCode`，只给装备打造那几页用），
## 别的界面拿不到；而且只覆盖了 `<font color>` 一种写法。2026-10-01 抽到这里并补全，
## 覆盖范围按**仓库里真实出现过的标签**逐条定（不是照 HTML 规范猜的）：
##
## | 真实写法 | 出现次数 |
## |---|---|
## | `</FONT>` / `<FONT COLOR="#00FF00">` / `<FONT  COLOR="#00FF00">`（双空格）/ `<FONT COLOR= "#00FF00">` | 449 / 209 / 14 / 3 |
## | `<br/>` | 165 |
## | `<font color='#FFF102'>` / `<font color="#00ff00">` | 30 / 16 |
## | `<font size ='14' color='#a208d'>` 这类 **带 size** 的 | 20+ |
## | `<b>` / `</b>` | 11 / 11 |
## | `<textformat leading='15'>` / `</textformat>` | 7 / 2 |
## | `<a href='#'>` / `</a>` | 7 / 2 |
##
## ⚠️ 两条从老实现里继承下来的坑，别改回去：
## 1. **`<textformat …>` 必须在"末尾 `>`"类的替换之前处理** —— 它的结尾正好是 `>`，
##    先跑别的会把 `>` 吃掉，之后再也找不到标签结尾（老注释记着第一次就是这么错的）；
## 2. `\r` 也是换行（语言表里大量在用），而且**字面 `\n`**（两个字符）在 `BaseUtil.formatStr`
##    里同样会被换成 `<br/>` —— 两种都要认。

const _换行 := ["\r\n", "\r"]

## 主入口。输入原版文案（可带 HTML），输出可直接赋给 `RichTextLabel.text` 的 BBCode。
static func 译文为BBCode(html: String) -> String:
	var 文 := html
	# 1) 换行。`BaseUtil.formatStr()`：`\r` 一律丢掉、`\n`（含**字面** `\n`）→ `<br/>`，
	#    所以这里把字面 `\n` / `\r` 先还原成真换行，再把 `<br/>` 统一成 `\n`。
	文 = 文.replace("\\n", "\n").replace("\\r", "")
	for 序列 in _换行:
		文 = 文.replace(序列, "\n")
	文 = 文.replace("<br/>", "\n").replace("<br />", "\n").replace("<br>", "\n")
	文 = 文.replace("<BR/>", "\n").replace("<BR>", "\n")
	# 2) 样式块：整块剥掉（它带的 `leading` 由调用点自己设，见老注释）
	文 = _剥成对标签(文, "textformat")
	# 3) 字体：只认 color / size，其它属性丢掉
	文 = _换字体标签(文)
	# 4) 粗斜下划线
	for 名 in [["b", "b"], ["B", "b"], ["i", "i"], ["I", "i"], ["u", "u"], ["U", "u"]]:
		文 = 文.replace("<%s>" % 名[0], "[%s]" % 名[1]).replace("</%s>" % 名[0], "[/%s]" % 名[1])
	# 5) 链接：提示框里就是一段文字，剥掉
	文 = _剥成对标签(文, "a")
	# 6) 兜底：还剩的尖括号**一律剥掉** —— 宁可不带样式，也不能把标签原样显示给玩家
	return _剥所有标签(文)

## 把 `<名 …>` 与 `</名>` 成对剥掉（名不区分大小写）。
static func _剥成对标签(文: String, 名: String) -> String:
	var 结果 := 文
	var 小写 := 结果.to_lower()
	var 模式 := "<%s" % 名
	while true:
		var 起 := 小写.find(模式)
		if 起 < 0:
			break
		var 止 := 小写.find(">", 起)
		if 止 < 0:
			break
		结果 = 结果.substr(0, 起) + 结果.substr(止 + 1)
		小写 = 结果.to_lower()
	return 结果.replace("</%s>" % 名, "").replace("</%s>" % 名.to_upper(), "")

## `<font …>`：取 `color` 与 `size` 两个属性，输出 `[color=#rrggbb]` / `[font_size=N]`。
##
## ⚠️ **只认 6 位（或 8 位）色值，短的一律丢样式、不猜**。理由：短色值上 **Flash 和 CSS 的规矩不一样** ——
## CSS 说 `#aabb` 是 RGBA 简写（每位翻倍），而 Flash 的 htmlText 是按十六进制原值读的
## （`#abc` → `0x000abc`，不是 `#aabbcc`）。我手上没有能确定 Flash 行为的手段，
## 与其猜错一个颜色，不如**不带颜色** —— 反正带 size/color 的那几条（`#a208d`、`#6699`、`#ff`）
## 现在都还没有消费者。
##
## 另外：`[color=#ff]` 这种 Godot 解析不了的，会把方括号**原样显示**出来，比不带颜色更糟。
static func _换字体标签(文: String) -> String:
	var 结果 := ""
	var 剩余 := 文
	# 数据里 `<font>` 不嵌套，但**成对**出现 —— 所以按顺序走：遇到 `<font …>` 压一个闭标签进栈，
	# 遇到 `</font>` 弹出并补上。⚠️ 第一版我把闭标签当场补在开标签后面（`[color=#fff][/color]文字`），
	# 那样**一个字都染不上色**。
	var 栈: Array[String] = []
	while true:
		var 小写 := 剩余.to_lower()
		var 开 := 小写.find("<font")
		var 闭 := 小写.find("</font>")
		if 开 < 0 and 闭 < 0:
			结果 += 剩余
			break
		if 闭 >= 0 and (开 < 0 or 闭 < 开):
			结果 += 剩余.substr(0, 闭) + (栈.pop_back() if not 栈.is_empty() else "")
			剩余 = 剩余.substr(闭 + 7)
			continue
		var 止 := 小写.find(">", 开)
		if 止 < 0:
			结果 += 剩余
			break
		结果 += 剩余.substr(0, 开)
		var 属性 := 剩余.substr(开 + 5, 止 - 开 - 5)
		剩余 = 剩余.substr(止 + 1)
		var 开标记 := ""
		var 闭标记 := ""
		var 色 := _取属性(属性, "color")
		if 色 != "":
			var 规范 := _规范颜色(色)
			if 规范 != "":
				开标记 += "[color=%s]" % 规范
				闭标记 = "[/color]" + 闭标记
		var 号 := _取属性(属性, "size")
		if 号.is_valid_int():
			开标记 += "[font_size=%d]" % int(号)
			闭标记 = "[/font_size]" + 闭标记
		栈.append(闭标记)
		结果 += 开标记
	return 结果

## 从 `<font …>` 的属性串里取一个属性的值（去引号）。`color='#fff'` / `color = "#fff"` 都认。
static func _取属性(属性串: String, 键: String) -> String:
	var 小写 := 属性串.to_lower()
	var 下标 := 小写.find(键)
	if 下标 < 0:
		return ""
	var 余 := 属性串.substr(下标 + 键.length())
	余 = 余.strip_edges()
	if 余.begins_with("="):
		余 = 余.substr(1).strip_edges()
	if 余.begins_with("'") or 余.begins_with("\""):
		var 引 := 余[0]
		var 止 := 余.find(引, 1)
		return 余.substr(1, 止 - 1) if 止 > 0 else ""
	var 止2 := 余.find(" ")
	return 余 if 止2 < 0 else 余.substr(0, 止2)

## 只放行 6/8 位色值（`#rrggbb` / `#rrggbbaa`），其余返回空串（见上面那段：短色值不猜）。
static func _规范颜色(值: String) -> String:
	var 十六 := 值.strip_edges().lstrip("#")
	if not 十六.is_valid_hex_number(false):
		return ""
	十六 = 十六.to_lower()
	return "#" + 十六 if 十六.length() in [6, 8] else ""

static func _剥所有标签(文: String) -> String:
	var 正则 := RegEx.new()
	正则.compile("<[a-zA-Z/][^>]*>")
	return 正则.sub(文, "", true)
