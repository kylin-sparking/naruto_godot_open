extends "res://开发工具/截意志学习页.gd"

## 意志**格渲染 + 格提示**门（学习页 5 个真 id + 背包态公式各验一段）。
## 骨架在 `截意志学习页.gd` → `量具基类.gd`（开「意志学习」窗、撑视口、藏 HUD、逐件量矩形），
## 本文件在几何门跑完之后**再喂数据**，把空态验不到的那几件事量出来：
##   ① 造格数 = 数据条数（`YiZhiContainer.setData:73-91` 先 removeAllCells 再按条数 new，
##      **0 条 = 一格都没有**，连格底都不画 —— 用户 2026-09-28 拿原版实机图纠正过）；
##   ② 每格的名称/字色/图标（`YiZhiStudyCell:70-83`），**灰色没有「拾取」**、
##      有拾取时「卖出」右对齐、纯灰色时「卖出」居中（`:99-104`）；
##   ③ 悬停出 `YiZhiTip`（`YiZhiStudyCell:119-122`）：宽**定死 246**（不像 `MToolTipText` 随文字缩）、
##      右侧图标位 (181,7)、`desc` 里的 `#value#` 已换成 `attrValue(级)`、末尾黄字是价格行；
##   ④ type2（背包页格）的 `exp/maxExp` 公式（`YiZhiData.maxExp:158-166`）——背包格在工程里
##      还没有数据入口，所以这一段**直接量组件**，不假装页面画出来了。
##
## ⚠ 期望高度**不从被测代码借**：`n = Σ ceil(段宽 / 176)`（`YiZhiTip:62-73` tf.width = 246−70），
##   `底高 = n·13 + (n−1)·7 + 2 + 6 + 10`
##   = Godot 内容高(13n+7(n−1)) + 行盒差 2 + `tf.height = textHeight + 6`(`:98`) + `back = tf + 10`(`:99`)。
##   行数用**字体直量**（`Font.get_string_size`），顺带断言每段墨迹宽 < 354 之外还 < 176 的折行前提。
##
## 用法（**不能加 --headless**，悬停与裁图都要真视口）：
##   Godot --path . --script res://开发工具/验意志格渲染.gd -- "--出目录=res://测试/截图/意志格渲染"

## 五个真 id：灰 107 / 绿 203 / 蓝 301 / 紫 401 / 粉 501（`数据/意志图鉴.json` 的表键）
const 意志提示场景 := preload("res://场景/界面/组件/意志提示框.tscn")
const 喂的号 := ["107", "203", "301", "401", "501"]
const 格名 := ["自掘坟墓", "引导", "强悍", "发奋", "风声鹤唳"]
const 格色 := ["#999999", "#00FF00", "#1E90FF", "#BA01F9", "#FF5498"]
const 字宽 := 176.0		# `YiZhiTip:62-73` MAX_WIDTH 246 − 70
const 定宽 := 246.0		# `:15/:59-61` 宽**定死**
const 单行高 := 13.0		# 本项目 SimSun 12px 实测 `get_height(12) = 13`
const 行距高 := 7.0		# `leading(5) + 2`，与组件 `line_separation` 同一条换算


func _队列尾() -> void:
	队列.append(_步喂数据)
	队列.append(_步验造格)
	队列.append(_步验每格)
	队列.append(_步悬停格)
	队列.append(_步验格提示)
	队列.append(_步格提示照)
	队列.append(_步整窗照)
	队列.append(_步验背包态)


## 把 5 个意志 id 塞进 `_session.spirit_panel`（**#63 接协议后的真入口** = 服务端回包 cmd1 的候选数组；
## 2026-10-03 之前本门塞的是 `player_stats.spirit_items`，那条旧入口已废 —— 2026-10-19 基线实测
## 就是这么红的：一格都造不出来），然后让宿主重建这一页。
## ⚠ 只改**内存里的 session**，一个存档字节都不写（`离线门不许写存档` 同一条规矩）。
func _步喂数据() -> void:
	var 会话: Node = 窗口._session
	if 会话 == null:
		_错("取不到 _session")
		return
	var 原态 = 会话.get("spirit_panel")
	会话.set("spirit_panel", 喂的号.duplicate())
	窗口.call("_render_page")
	记录原态(原态)
	等待 = 4


var _原态存在 := false
var _原态值: Variant = null


func 记录原态(旧: Variant) -> void:
	_原态存在 = 旧 != null
	_原态值 = 旧


func 页() -> Control:
	return 页根()


func 格件(k: int, 尾: String) -> Node:
	var 页 := 页()
	return 页.get_node_or_null("意志容器/意志格_%d/%s" % [k, 尾]) if 页 != null else null


## ① 造格数 = 条数：前 5 格可见、后 5 格必须还隐着（位置槽只是槽，不是格）。
func _步验造格() -> void:
	var 页 := 页()
	if 页 == null:
		return
	var 露: Array = []
	var 隐: Array = []
	for k in 10:
		var 槽 := 页.get_node_or_null("意志容器/意志格_%d" % k) as CanvasItem
		if 槽 == null:
			_错("取不到 意志格_%d" % k)
			continue
		(露 if 槽.visible else 隐).append(k)
	var 对: bool = 露.size() == 喂的号.size() and 隐.size() == 10 - 喂的号.size()
	for k in 露.size():
		对 = 对 and int(露[k]) == k
	有错 = 有错 or not 对
	_行("  造格数        可见=%s 隐=%s（喂 %d 条 ⇒ 前 %d 格）%s" % [str(露), str(隐),
			喂的号.size(), 喂的号.size(), "√" if 对 else "!! 错"])


## ② 逐格：名称/字色/图标/拾取有无/卖出对齐。期望全部从 `数据/意志图鉴.json` 现取。
func _步验每格() -> void:
	var 图鉴: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://数据/意志图鉴.json"))
	for k in 喂的号.size():
		var 项: Dictionary = 图鉴.get(喂的号[k], {}) as Dictionary
		var 名 := 格件(k, "名称") as Label
		var 图 := 格件(k, "图标") as TextureRect
		var 卖 := 格件(k, "卖出") as Label
		var 拾 := 格件(k, "拾取") as CanvasItem
		if 名 == null or 图 == null or 卖 == null or 拾 == null:
			_错("格 %d 缺件（名称/图标/卖出/拾取）" % k)
			continue
		var 灰 := str(项.get("color", "")) == "gray"
		var 想色 := Color(str(项.get("textColor", "#ffffff")))
		# ⚠ 颜色一律近似比：`.tscn`/数据里的十六进制转成 Color 是 6 位小数，
		#   运行期取到的是 252/255=0.98823529…，`==` 会凭空判红。
		var 对: bool = 名.text == str(项.get("name", ""))
		对 = 对 and 名.get_theme_color("font_color").is_equal_approx(想色)
		对 = 对 and 图.visible and 图.texture != null and 图.texture.get_width() > 0
		对 = 对 and 拾.visible == (not 灰)	# `YiZhiStudyCell:92` 只有非灰色才有「拾取」
		对 = 对 and 卖.horizontal_alignment == (
				HORIZONTAL_ALIGNMENT_CENTER if 灰 else HORIZONTAL_ALIGNMENT_RIGHT)	# `:99-104`
		对 = 对 and 名.text == 格名[k] and 想色.is_equal_approx(Color(格色[k]))	# 表也自洽
		有错 = 有错 or not 对
		_行("  格%d %-6s 色=%s 图标=%s 拾取=%s(想%s) 卖出对齐=%d %s" % [k + 1, 名.text,
				"同表" if 名.get_theme_color("font_color").is_equal_approx(想色) else "!!",
				"有" if 图.texture != null else "无", str(拾.visible), str(not 灰),
				卖.horizontal_alignment, "√" if 对 else "!! 错"])


## ③ 悬停每一格（`YiZhiStudyCell:119-122` → ROLL_OVER 才 addChild 到 stage）。
func _步悬停格() -> void:
	var 页 := 页()
	if 页 == null:
		return
	_移到(格全局中心(0))
	等待 = 3


func 格全局中心(k: int) -> Vector2:
	var 件 := 页().get_node_or_null("意志容器/意志格_%d" % k) as Control
	return 件.get_global_rect().position + 件.get_global_rect().size / 2.0


func _移到(点: Vector2) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 点
	移.global_position = 点
	root.push_input(移)


func 提示件(k: int) -> Control:
	var 页 := 页()
	return 页.get_node_or_null("意志提示_意志格_%d" % k) as Control if 页 != null else null


## ④ 五格的提示版式：宽恒 246、底高按**独立公式**算、三段文案逐条对。
func _步验格提示() -> void:
	var 页 := 页()
	if 页 == null:
		return
	var 图鉴: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://数据/意志图鉴.json"))
	for k in 喂的号.size():
		_移到(格全局中心(k))
		等待 = 3
		var 框 := 提示件(k)
		if 框 == null:
			_错("格 %d 没有 意志提示_ 节点" % k)
			continue
		if not 框.visible:
			_错("悬停格 %d 提示没浮出来" % k)
			continue
		var 文: RichTextLabel = 框.get_node("文字") as RichTextLabel
		var 底: TextureRect = 框.get_node("底") as TextureRect
		var 图: TextureRect = 框.get_node_or_null("图标") as TextureRect
		var 字 := 文.get_theme_font("normal_font") as Font
		var 号: int = 文.get_theme_font_size("normal_font_size")
		var 纯 := 文.get_parsed_text()
		var 想 := _期望底(纯, 字, 号)
		var 偏 := (框.size - 想).abs()
		var 对: bool = abs(框.size.x - 定宽) < 0.7 and abs(框.size.y - 想.y) < 0.7
		对 = 对 and abs(底.size.y - 想.y) < 0.7 and abs(底.size.x - 定宽) < 0.7
		对 = 对 and 文.position == Vector2(7, 7) and abs(文.size.x - 字宽) < 0.7
		对 = 对 and 图 != null and 图.position == Vector2(181, 7)	# `:108-114`
		# 内容三段：品质色名 Lv.1 / 白色 desc（`#value#` 已换）/ 黄色价格行
		var 项: Dictionary = 图鉴.get(喂的号[k], {}) as Dictionary
		var 值 := 0 if str(项.get("color", "")) == "gray" else 属性值(项, 1, int(喂的号[k]))
		var 有名 := 纯.contains("%s Lv.1" % str(项.get("name", "")))
		var 有值 := 纯.contains(str(值)) or not str(项.get("desc", "")).contains("#value#")
		var 有价 := 纯.contains(str(int(项.get("price", 0))))
		对 = 对 and 有名 and 有值 and 有价
		有错 = 有错 or not 对
		_行("  提示 格%d %-6s 底=%s 想=%s 图标=%s n=%d 段[%s %s %s] %s" % [k + 1,
				str(项.get("name", "")), 框.size, 想, str(图.position) if 图 != null else "<无>",
				_行数(纯, 字, 号), "√" if 有名 else "×名", "√" if 有值 else "×值",
				"√" if 有价 else "×价", "√" if 对 else "!! 错"])
		if 偏.x > 0.7 or 偏.y > 0.7:
			_行("      纯文=%s" % 纯.replace("\n", "⏎"))


## 与组件同一套度量口径、**独立算一遍**（不读组件里任何常量）：
## 每段按 176 折行 ⇒ 总行数 n；底高 = 13n + 7(n−1) + 2 + 6 + 10。
func _行数(纯: String, 字: Font, 号: int) -> int:
	var n := 0
	for 段 in 纯.split("\n"):
		n += maxi(1, int(ceil(字.get_string_size(段, HORIZONTAL_ALIGNMENT_LEFT, -1, 号).x / 字宽)))
	return n


func _期望底(纯: String, 字: Font, 号: int) -> Vector2:
	var n := _行数(纯, 字, 号)
	return Vector2(定宽, float(n) * 单行高 + float(n - 1) * 行距高 + 2.0 + 6.0 + 10.0)


## 组件里 `#value#` 的算法（`YiZhiData.getAttrValue:66-89`）在门里**重算一遍**：
## 801/802 = `3·clamp(级,1,20)`、601/602 恒 1200、否则取 `attrValues.level1..N` 的最大值。
## id 由调用方给（图鉴记录里没有 id 字段，只有表键 ⇒ 组件靠 `实例.id`，这边同一条口径）。
func 属性值(项: Dictionary, 级: int, id: int) -> int:
	if id == 801 or id == 802:
		return 3 * clampi(级, 1, 20)
	if id == 601 or id == 602:
		return 1200
	var 表: Dictionary = 项.get("attrValues", {})
	var 出 := 0
	for n in range(1, maxi(1, 级) + 1):
		出 = maxi(出, int(表.get(str(n), 0)))
	return 出


## ⑤ 视觉证据：每格提示裁一张 + 整窗一张（有数据态，空态的 客户端_页0.png 已由几何门出）。
func _步格提示照() -> void:
	# 上一步的循环最后停在**第 5 格**上 ⇒ 格 2 的提示已经被 `mouse_exited` 收掉了。
	# 拍照前必须把鼠标**移回要拍的那一格**，隔帧再裁（同帧裁到的是上一帧画面）。
	var 拍格 := 1
	_移到(格全局中心(拍格))
	等待 = 3
	队列.append(_步格提示照2.bind(拍格))


func _步格提示照2(拍格: int) -> void:
	var 页 := 页()
	var 图像 := root.get_texture().get_image()
	var 框 := 提示件(拍格)
	if 页 == null or 框 == null or not 框.visible:
		_错("拍照时格 %d 的提示不在屏上（悬停没浮出来，或隔帧不够）" % 拍格)
		return
	var 起 := Vector2i(int(页.get_global_position().x + 框.position.x),
			int(页.get_global_position().y + 框.position.y))
	var 尺 := Vector2i(int(框.size.x), int(框.size.y))
	尺.x = clampi(尺.x, 1, 图像.get_width() - 起.x)
	尺.y = clampi(尺.y, 1, 图像.get_height() - 起.y)
	var 区 := 图像.get_region(Rect2i(起, 尺))
	区.save_png("%s/提示_学习格%d.png" % [出目录, 拍格])
	# 画没画出来用最硬的办法判：裁矩形里数暗底/亮字采样（几何全对但屏幕是空的，只有数像素才抓得住）
	var 暗 := 0
	var 亮 := 0
	for y in range(0, 区.get_height(), 2):
		for x in range(0, 区.get_width(), 2):
			var 色 := 区.get_pixel(x, y)
			if 色.v < 0.30:
				暗 += 1
			if 色.v > 0.75:
				亮 += 1
	var 对: bool = 暗 > 0 and 亮 > 0
	有错 = 有错 or not 对
	_行("  提示入画      提示_学习格%d.png 矩形 %s@%s 暗底 %d 亮字 %d %s" % [拍格, 尺, 起, 暗, 亮,
			"√" if 对 else "!! 没画出来"])
	# 3× 裁条：绿字「引导 Lv.1」/ 白字「闪避+20」/ 黄字「价格6750」+ 右侧自转图标
	var 外 := Rect2i(起 - Vector2i(14, 10), 尺 + Vector2i(40, 30))
	外.position = 外.position.max(Vector2i.ZERO)
	外.size.x = clampi(外.size.x, 1, 图像.get_width() - 外.position.x)
	外.size.y = clampi(外.size.y, 1, 图像.get_height() - 外.position.y)
	图像.get_region(外).resize(外.size.x * 3, 外.size.y * 3, Image.INTERPOLATE_NEAREST)
	图像.get_region(外).save_png("%s/_看格提示.png" % 出目录)
	_移到(页.get_global_position() + Vector2(300, 300))
	等待 = 2


func _步整窗照() -> void:
	var 主 := 主窗()
	if 主 == null:
		return
	var 图像 := root.get_texture().get_image()
	var 起 := Vector2i(int(主.get_global_position().x), int(主.get_global_position().y))
	var 尺 := Vector2i(int(主.size.x), int(主.size.y))
	尺.x = clampi(尺.x, 1, 图像.get_width() - 起.x)
	尺.y = clampi(尺.y, 1, 图像.get_height() - 起.y)
	图像.get_region(Rect2i(起, 尺)).save_png("%s/整窗_有数据.png" % 出目录)
	_行("  截图          %s/整窗_有数据.png" % 出目录)


## ⑥ type2（`YiZhiCell:152-156` → `YiZhiTip.createToolTip2`）：
## `[色]名 Lv.级` / 白 `意志经验 exp/maxExp` / **红** desc（+白 detailDesc），**没有价格行**。
## 背包格在工程里还没有数据入口（原版数据来自 `updateSpiritInventory`）⇒ 这里**直接量组件**，
## 并把 maxExp 按 `YiZhiData.maxExp:158-166` = `common.levelUp["level"+(级+1)][品质]` 独立算一遍。
func _步验背包态() -> void:
	var 页 := 页()
	var 图鉴: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://数据/意志图鉴.json"))
	var 常: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://数据/意志.json"))
	var 升级: Dictionary = (常.get("common", {}) as Dictionary).get("levelUp", {}) as Dictionary
	var 项: Dictionary = 图鉴.get("301", {}) as Dictionary
	var 框 := 意志提示场景.instantiate() as Control
	if 页 == null or 框 == null:
		_错("量具取不到页面或提示场景")
		return
	框.name = "意志提示_背包态"
	框.mouse_filter = Control.MOUSE_FILTER_IGNORE
	页.add_child(框)
	框.设置背包态(项, {"id": "301", "level": 5, "exp": 100}, 页.get_viewport_rect().size)
	框.visible = true
	var 文: RichTextLabel = 框.get_node("文字") as RichTextLabel
	var 纯 := 文.get_parsed_text()
	var 想上限 := int(((升级.get("level6", {}) as Dictionary)).get(str(项.get("color", "")), 0))
	var 对: bool = 纯.contains("100/%d" % 想上限)
	对 = 对 and not 纯.contains(str(int(项.get("price", 0))))	# type2 没有价格行
	对 = 对 and abs(框.size.x - 定宽) < 0.7
	有错 = 有错 or not 对
	_行("  背包态 type2  「%s」maxExp 独立算=levelUp.level6[%s]=%d 价格行=%s 宽=%.0f %s" % [
			纯.replace("\n", "⏎"), str(项.get("color", "")), 想上限,
			"无√" if not 纯.contains(str(int(项.get("price", 0)))) else "有!!", 框.size.x,
			"√" if 对 else "!! 错"])
	_行("  说明          背包格运行期**有**数据入口（`会话.spirit_bag`，cmd7 整表回帧），但
			`_填一格层` 还没给有货格挂 type2 提示（意志完善计划 P1-5）⇒ 这一段仍只量组件。")
