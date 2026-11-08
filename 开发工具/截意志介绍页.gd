extends "res://开发工具/量具基类.gd"

## 量「意志介绍」窗（原版 `com/mxw/uifl/controls/yiZhi/YiZhiIntroduceWindow.as`，455×430）。
## 场景由 `开发工具/生成意志介绍场景.py` 从本表的 `件路径 / 件期望` 生成；
## **列表的行不在场景里** —— 原版是 `fl.controls.List` 按 `dataProvider` 动态造行
## （`drawList:56-71` 遍历 `Spirit.items`、剔掉灰色、按品质序号降序），
## 所以行由控制器 `_填意志介绍行()` 现造，本文件只量外壳 + 滚动条，并**数行**。
##
## 坐标链：
##   `super(455,430,false)` `:20`；`_contentBg` MYellow @(8,38) 439×384
##     （`:27-32` x=CONTENT_GAP=8、y=38、w=_width−16、h=_height−8−38）
##   `_list` @(13,43) 427×372（`:33-38` x=8+BORDER_GAP 5、y=38+5、w=439−10−2、h=384−10−2）
##   页面容器原点 (0,29)（`窗口尺寸.json` 的「意志介绍」标 `整框: true`）⇒ **场景 y = 窗口 y − 29**
##   滚动条口径同「资讯查询」页：`ScrollPane`/`List` 都 `extends BaseScrollPane`，
##   `BaseScrollPane:311` 写死 `new ScrollBar()` ⇒ 皮是 `滚动*`（不是 `小滚动*`），
##   `configUI:283-284` `setSize(WIDTH=15,14)` ⇒ 可见宽 15。
##
## 用法（不能加 --headless）：
##   Godot --path . --script res://开发工具/截意志介绍页.gd -- --出目录=res://测试/截图/意志介绍

const 件路径 := {
	"外框黄底": "外框黄底",
	"列表区": "列表区",
	"内容列": "列表区/内容列",
	"竖条": "列表区/竖条",
	"上箭头": "列表区/竖条/上箭头",
	"轨道": "列表区/竖条/轨道",
	"滑块": "列表区/竖条/滑块",
	"下箭头": "列表区/竖条/下箭头",
}

const 件期望 := {
	"外框黄底": [8, 9, 439, 384],					# :27-32
	"列表区": [13, 14, 427, 372],					# :33-38
	"内容列": [13, 14, 412, 372],					# availableWidth = 427 − ScrollBar.WIDTH(15)
	"竖条": [425, 14, 15, 372],						# BaseScrollPane:353-356 x = 列表区.x + (427−15)
	"上箭头": [425, 14, 15, 14],						# ScrollBar:283-284 setSize(15,14) @y=0
	"轨道": [425, 28, 15, 344],						# :266 move(0,14) + :243 h = 372−(14+14)
	# 滑块是**运行期算的**（Flex `ScrollBar.updateThumb`）：
	#   高 = 轨道高 × 视口/内容 =344 × 372 ÷ (38 行 × 26 = 988) = **129.5223**
	#	（量具容差 0.01 ⇒ 这里必须写全 129.5223，写 129.5 会判"偏"）；
	#   偏移 0 时贴在轨道顶 ⇒ y = 上箭头 14 + 14 = 28（页面绝对）。
	# ⚠️ 旧值 [425,42,15,127] 是"烘死的装饰件"时代的拟合数，运行期根本不被使用；
	#   2026-09-28 接上真滚动后按公式改。行数变了（服务器给的意志数不同）⇒ 这条
	#   期望要跟着 `行数` 重算，量具的滚动步会打印实际行数供核对。
	"滑块": [425, 28, 15, 129.5223],
													#   = 14/38 × 344 = 126.7 → 127；y = 轨道.y + 0（滚到顶）
	"下箭头": [425, 372, 15, 14],						# :242 y = max(14, 372−14) = 358
}

## 行模型（`YiZhiItemRenderer`，就写在 `YiZhiIntroduceWindow.as` 文件尾）：
## 行高 26、`MLabel` w=406、其下一条 `LineHPicF` y=22 w=406。
const 行高 := 26
const 行字宽 := 406
const 行线Y := 22


func 页名() -> String:
	return "意志介绍"


func 根节点名() -> String:
	return "原版意志介绍内容"


func 页签数() -> int:
	return 1


func 有页签() -> bool:
	return false


func 期望() -> Dictionary:
	return 件期望


func 路径() -> Dictionary:
	return 件路径


func 公共件() -> Array[String]:
	return ["外框黄底"]


func 页面件表() -> Dictionary:
	return {0: ["外框黄底", "列表区", "内容列", "竖条", "上箭头", "轨道", "滑块", "下箭头"]}


func 额外校验(页: Control, _页号: int) -> void:
	# 一、行数 = 图鉴里**非灰**的意志数（`drawList:57-58` 的 `color != SpiritColor.GRAY`）
	var 图鉴: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://数据/意志图鉴.json"))
	var 想行 := 0
	for k in 图鉴:
		var 记 = 图鉴[k]
		if 记 is Dictionary and String(记.get("color", "")) != "gray":
			想行 += 1
	var 列 := 页.get_node_or_null("列表区/内容列") as Control
	var 实行 := 列.get_child_count() if 列 != null else 0
	有错 = 有错 or 实行 != 想行
	_行("  %-12s 行数=%d（图鉴非灰 %d 条）%s" % ["意志介绍行", 实行, 想行, "√" if 实行 == 想行 else "!! 错"])
	if 实行 < 2:
		return
	# 二、行序：品质序号**降序**（`drawList:70` `sortOn("color", NUMERIC|DESCENDING)`）
	var 首 := 列.get_child(0) as Control
	var 末 := 列.get_child(实行 - 1) as Control
	var 首名 := _行名(首)
	var 末名 := _行名(末)
	_行("  %-12s 首行「%s」末行「%s」%s" % ["行序", 首名, 末名,
		"√" if not 首名.is_empty() and not 末名.is_empty() else "!! 取不到行文字"])
	# 三、行高与分隔线
	var 想y := 0.0
	var 高对 := true
	for i in mini(实行, 40):
		var 行 := 列.get_child(i) as Control
		if 行 == null or abs(行.position.y - 想y) > 0.6 or abs(行.size.y - float(行高)) > 0.6:
			高对 = false
		想y += float(行高)
	有错 = 有错 or not 高对
	_行("  %-12s 每行 y 步进=%d、行高=%d %s" % ["行网格", 行高, 行高, "√" if 高对 else "!! 错"])
	# 四、溢出 ⇒ 滑块必须可见（`updateThumb:156` `thumb.visible = enabled`）
	var 滑 := 页.get_node_or_null(件路径["滑块"]) as CanvasItem
	有错 = 有错 or 滑 == null or not 滑.visible
	_行("  %-12s visible=%s（%d 行 > 可视 %d 行 ⇒ 溢出）%s" % ["滑块",
		str(滑.visible) if 滑 else "<无>", 想行, int(372.0 / float(行高)),
		"√" if 滑 != null and 滑.visible else "!! 错"])


## 五、滚动（用户 2026-09-28 报"意志介绍不能滑动，原版可以"）。
## 判的是**运行期真位移**：滚轮 3 格 ⇒ 内容列上移 78px、滑块按 Flex 比例式落到对应位置；
## 再滚 40 格 ⇒ 必须**钳在底**（`偏移 = 内容高 − 滚动视口`），不能滚出空白。
const 滚动行高 := 26.0			# `YiZhiIntroduceWindow:39 rowHeight=26`
const 滚动视口 := 372.0			# 内容列高（List 427×372）
const 滚动轨顶 := 14.0			# 上箭头高
const 滚动轨高 := 344.0			# 轨道高 = 372 − 14 − 14


## 数「列表区」这一块的**亮字像素**——专防"数字全对但画面是空的"那一类 bug：
## 裁剪框挂错层（挂在被滚动的内容列上）时，位置断言全绿而屏幕上什么都没有，
## 只有数画面像素才抓得住（2026-09-28 实测就是这么发现的）。
func _列表区墨迹() -> int:
	var 区 := 页根().get_node_or_null("列表区") as Control
	var 图像 := root.get_texture().get_image()
	if 区 == null or 图像 == null:
		return -1
	var 起 := Vector2i(int(区.get_global_position().x), int(区.get_global_position().y))
	var 尺 := Vector2i(int(区.size.x), int(区.size.y))
	起.x = clampi(起.x, 0, maxi(图像.get_width() - 1, 0))
	起.y = clampi(起.y, 0, maxi(图像.get_height() - 1, 0))
	尺.x = clampi(尺.x, 1, 图像.get_width() - 起.x)
	尺.y = clampi(尺.y, 1, 图像.get_height() - 起.y)
	var 区图 := 图像.get_region(Rect2i(起, 尺))
	var 出 := 0
	for y in range(0, 区图.get_height(), 2):
		for x in range(0, 区图.get_width(), 2):
			if 区图.get_pixel(x, y).v > 0.55:
				出 += 1
	return 出


func _队列尾() -> void:
	队列.append(_步滚三格)
	队列.append(_步验滚动)
	队列.append(_步滚到底)
	队列.append(_步验到底)
	队列.append(_步收尾校验)


func _滚(次: int) -> void:
	var 区 := 页根().get_node_or_null("列表区") as Control
	if 区 == null:
		_错("取不到 列表区")
		return
	var 点 := 区.get_global_rect().position + Vector2(200, 200)
	for i in 次:
		var 键 := InputEventMouseButton.new()
		键.button_index = MOUSE_BUTTON_WHEEL_DOWN
		键.pressed = true
		键.position = 点
		键.global_position = 点
		root.push_input(键)
	等待 = 3


func _步滚三格() -> void:
	_滚(3)


func _滚动件() -> Array:
	var 页 := 页根()
	return [页.get_node_or_null("列表区/内容列") as Control,
			页.get_node_or_null("列表区/竖条/滑块") as Control]


func _步验滚动() -> void:
	var 件 := _滚动件()
	var 列: Control = 件[0]
	var 滑: Control = 件[1]
	if 列 == null or 滑 == null:
		_错("滚动断言缺件（内容列/滑块）")
		return
	var 行数 := 列.get_child_count()
	var 内容 := float(行数) * 滚动行高
	var 行程 := maxf(0.0, 内容 - 滚动视口)
	var 想滑高 := minf(滚动轨高, maxf(20.0, 滚动轨高 * 滚动视口 / maxf(内容, 滚动视口)))
	var 想y := 滚动轨顶 + (78.0 / 行程 if 行程 > 0.0 else 0.0) * (滚动轨高 - 滑.size.y)
	var 对: bool = abs(列.position.y + 78.0) < 0.6
	对 = 对 and abs(滑.size.y - 想滑高) < 1.2
	对 = 对 and abs(滑.position.y - 想y) < 1.2
	有错 = 有错 or not 对
	var 墨1 := _列表区墨迹()
	对 = 对 and 墨1 > 200		# 屏幕上有字才算真滚出来了
	_行("  滚轮 3 格     %d 行=%.0f 高 列.y=%.1f(想 −78) 滑块高=%.1f(想 %.1f) 滑块y=%.1f(想 %.1f) 区内亮字 %d %s"
			% [行数, 内容, 列.position.y, 滑.size.y, 想滑高, 滑.position.y, 想y, 墨1,
				"√" if 对 else "!! 错"])


func _步滚到底() -> void:
	_滚(40)


func _步验到底() -> void:
	var 件 := _滚动件()
	var 列: Control = 件[0]
	var 滑: Control = 件[1]
	if 列 == null or 滑 == null:
		return
	var 行程 := maxf(0.0, float(列.get_child_count()) * 滚动行高 - 滚动视口)
	var 对: bool = abs(列.position.y + 行程) < 0.6
	对 = 对 and abs(滑.position.y - (滚动轨顶 + 滚动轨高 - 滑.size.y)) < 1.2
	var 末行 := 列.get_child(列.get_child_count() - 1) as Control
	var 在视口 := 末行 != null and 末行.position.y + 列.position.y < 滚动视口
	对 = 对 and 在视口		# 滚到底 ⇒ 最后一行必须进可视区（这就是"能看完介绍"）
	var 墨2 := _列表区墨迹()
	对 = 对 and 墨2 > 200
	有错 = 有错 or not 对
	_行("  滚到底        列.y=%.1f(想 −%.1f) 滑块y=%.1f(想 %.1f) 末行入视口=%s 区内亮字 %d %s"
			% [列.position.y, 行程, 滑.position.y, 滚动轨顶 + 滚动轨高 - 滑.size.y,
				str(在视口), 墨2, "√" if 对 else "!! 错"])
	var 图像 := root.get_texture().get_image()
	var 主 := 主窗()
	var 起 := Vector2i(int(主.get_global_position().x), int(主.get_global_position().y))
	var 尺 := Vector2i(int(主.size.x), int(主.size.y))
	尺.x = clampi(尺.x, 1, 图像.get_width() - 起.x)
	尺.y = clampi(尺.y, 1, 图像.get_height() - 起.y)
	图像.get_region(Rect2i(起, 尺)).save_png("%s/整窗_滚到底.png" % 出目录)
	_行("  截图          %s/整窗_滚到底.png" % 出目录)


func _行名(行: Node) -> String:
	for c in 行.get_children():
		if c is RichTextLabel:
			return (c as RichTextLabel).text
		if c is Label:
			return (c as Label).text
	return ""


func _行(文本: String) -> void:
	行.append(文本)
	print(文本)
