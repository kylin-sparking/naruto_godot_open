extends RefCounted

## 图像比对引擎：配准 → 边缘掩码 → 逐像素/分块差 → 连通域聚类 → 控件点名。
##
## 为什么单独抽一份：有头跑批（`开发工具/窗口像素基线.gd`）负责渲染，
## 无头套件负责读已经截好的图 —— 两边必须用**同一套算法**，否则同样的图会得出
## 不同结论，那就又回到"验证环节本身不可靠"了。
##
## 三条硬约束（都有实测依据）：
##  1. **基线是 1:1**，只需平移不需缩放。但每次都由配准算出来，不写死偏移；
##     算完还要在 1.0 邻域复核尺度，最佳不是 1.00 就拒绝输出几何结论。
##  2. **文字必然有非零差** —— Flash 的 GDI 点阵与 Godot 的 hinted 轮廓光栅化
##     逐字形都不同（`开发工具/截图比对.gd` 头部已记）。所以只在"两边都不是边缘"
##     的像素上判差异，否则报告会被字形噪声淹没。
##  3. **置信度不够就不出结论**。配歪了还照常报差异域，会让人去改一个本来没错的数字。

## 配准搜索：由粗到细。粗层步长大范围宽，细层只在最优附近收窄。
const 粗步长 := 8
const 粗半径 := 80
const 中步长 := 2
const 中半径 := 8
## 算置信度时要排除的半径：最优附近这一圈里的偏移代价天然接近，不能算作“次优”。
const 隔离半径 := 12
## 参与统计要求的最小不透明度（九宫格边框四角是圆角透明的）。
const 最小透明 := 8


## 图 → {宽, 高, 灰, 透}，灰度与不透明度各一条 PackedByteArray。
## 用 `get_data()` 直接索引字节，比 `get_pixel()` 快一个数量级。
static func 转灰(图: Image) -> Dictionary:
	var 拷 := 图.duplicate() as Image
	if 拷.get_format() != Image.FORMAT_RGBA8:
		拷.convert(Image.FORMAT_RGBA8)
	var 宽 := 拷.get_width()
	var 高 := 拷.get_height()
	var 源 := 拷.get_data()
	var 灰 := PackedByteArray()
	var 透 := PackedByteArray()
	灰.resize(宽 * 高)
	透.resize(宽 * 高)
	for i in 宽 * 高:
		var o := i * 4
		灰[i] = (源[o] * 77 + 源[o + 1] * 150 + 源[o + 2] * 29) >> 8
		透[i] = 源[o + 3]
	# 边缘强度也一起算好：配准的代价要按它加权，否则画面主体是一片大色块时
	# 很多偏移的代价都差不多、极小值不尖锐（实测置信度只有 1.01，等于配不准）。
	return {"宽": 宽, "高": 高, "灰": 灰, "透": 透, "边": _梯度(灰, 宽, 高)}


## 把 `甲` 摆到 `乙` 的某个位置上，算平均绝对差。只在两边都够不透明的采样点上算。
static func _代价(甲: Dictionary, 乙: Dictionary, 偏移: Vector2i, 步长: int, 上限: float) -> float:
	var 累计 := 0.0
	var 点数 := 0
	var 甲灰: PackedByteArray = 甲["灰"]
	var 乙灰: PackedByteArray = 乙["灰"]
	var 甲透: PackedByteArray = 甲["透"]
	var 乙透: PackedByteArray = 乙["透"]
	var 甲边: PackedByteArray = 甲["边"]
	var 乙边: PackedByteArray = 乙["边"]
	var 甲宽: int = 甲["宽"]
	var 甲高: int = 甲["高"]
	var 乙宽: int = 乙["宽"]
	var 乙高: int = 乙["高"]
	var y := 0
	while y < 甲高:
		var 乙y := y + 偏移.y
		if 乙y >= 0 and 乙y < 乙高:
			var x := 0
			while x < 甲宽:
				var 乙x := x + 偏移.x
				if 乙x >= 0 and 乙x < 乙宽:
					var 甲i := y * 甲宽 + x
					if 甲透[甲i] > 最小透明:
						var 乙i := 乙y * 乙宽 + 乙x
						if 乙透[乙i] > 最小透明:
							累计 += absf(float(甲灰[甲i]) - float(乙灰[乙i]))
							点数 += 1
							if 点数 >= 上限 and 上限 > 0.0:
								return 累计 / float(maxi(1, 点数))
				x += 步长
		y += 步长
	return 累计 / float(点数) if 点数 > 0 else 1e9


## 由粗到细找 `甲` 在 `乙` 里的落点。
## 返回 {偏移, 代价, 置信度, 尺度, 可信}。
## 置信度 = 次优局部极小 / 最优（越大于 1 越可信）；< 1.05 视为配歪，`可信` 为 false。
static func 配准(甲: Image, 乙: Image) -> Dictionary:
	var 甲灰 := 转灰(甲)
	var 乙灰 := 转灰(乙)
	var 最优 := Vector2i.ZERO
	var 最优代价 := INF
	var 次优 := INF

	# 粗：步长 8，在 ±粗半径 内全搜。基线都只是比窗口大一圈的截图，这个范围足够。
	var d := 粗半径
	while d >= -粗半径:
		var x := 粗半径
		while x >= -粗半径:
			var 偏 := Vector2i(x, d)
			var c := _代价(甲灰, 乙灰, 偏, 粗步长, 4000.0)
			if c < 最优代价:
				最优代价 = c
				最优 = 偏
			x -= 粗步长
		d -= 粗步长

	# 中：在粗解附近 ±中半径 内细搜。
	for dy in range(-中半径, 中半径 + 1):
		for dx in range(-中半径, 中半径 + 1):
			var 偏 := 最优 + Vector2i(dx, dy)
			var c := _代价(甲灰, 乙灰, 偏, 中步长, 0.0)
			if c < 最优代价:
				最优代价 = c
				最优 = 偏

	# 置信度 = **排除最优附近一圈之后**的次优 / 最优。
	# ⚠️ 不能直接拿全局次优比：相邻偏移的代价本来就几乎一样，那样算永远趋近 1.00，
	#    等于把"配准可信"判成"不可信"（第一版就是这么误报的）。
	#    隔开一圈再比，问的才是"换到明显不同的位置，代价会不会显著变差"。
	次优 = INF
	for dy in range(-粗半径, 粗半径 + 1, 粗步长):
		for dx in range(-粗半径, 粗半径 + 1, 粗步长):
			if absi(dx) <= 隔离半径 and absi(dy) <= 隔离半径:
				continue
			var c := _代价(甲灰, 乙灰, 最优 + Vector2i(dx, dy), 粗步长 * 2, 2000.0)
			if c < 次优:
				次优 = c

	# 尺度复核：最佳若不是 1.00 就说明基线不是 1:1，此时**拒绝出几何结论**。
	var 最优尺度 := 1.0
	var 尺度代价 := 最优代价
	for 试 in [0.98, 0.99, 1.01, 1.02]:
		var 缩 := 甲.duplicate() as Image
		缩.resize(int(round(甲.get_width() * 试)), int(round(甲.get_height() * 试)), Image.INTERPOLATE_BILINEAR)
		var c := _代价(转灰(缩), 乙灰, 最优, 中步长, 0.0)
		if c < 尺度代价:
			尺度代价 = c
			最优尺度 = 试

	var 置信 := (次优 / 最优代价) if 最优代价 > 0.0 and 次优 < INF else 99.0
	return {
		"偏移": 最优, "代价": 最优代价, "置信度": 置信,
		"尺度": 最优尺度, "可信": 置信 >= 1.05 and is_equal_approx(最优尺度, 1.0),
		"甲灰": 甲灰, "乙灰": 乙灰,
	}


## 逐像素 + 分块比对。只在"两边梯度都不超过 `梯度门`"的像素上判（排除文字光栅化噪声）。
## 返回 {掩码, 域们, 块们, 统计}。
static func 比对(配: Dictionary, 选项: Dictionary) -> Dictionary:
	var 阈值 := int(选项.get("阈值", 8))
	var 块 := int(选项.get("块", 16))
	var 块阈值 := float(选项.get("块阈值", 20))
	var 梯度门 := int(选项.get("梯度门", 12))
	var 用掩码 := bool(选项.get("掩码", true))
	var 甲: Dictionary = 配["甲灰"]
	var 乙: Dictionary = 配["乙灰"]
	var 偏移: Vector2i = 配["偏移"]
	var 甲宽: int = 甲["宽"]
	var 甲高: int = 甲["高"]
	var 乙宽: int = 乙["宽"]
	var 乙高: int = 乙["高"]
	var 甲灰: PackedByteArray = 甲["灰"]
	var 乙灰: PackedByteArray = 乙["灰"]
	var 甲透: PackedByteArray = 甲["透"]
	var 乙透: PackedByteArray = 乙["透"]

	var 梯甲 := _梯度(甲灰, 甲宽, 甲高)
	var 梯乙 := _梯度(乙灰, 乙宽, 乙高)

	# 差异图（局部坐标 = 甲坐标）与差异值表
	var 差异 := PackedByteArray()
	差异.resize(甲宽 * 甲高)
	var 差值 := PackedInt32Array()
	差值.resize(甲宽 * 甲高)
	var 超阈 := 0
	var 计点 := 0
	var 最大差 := 0
	for y in 甲高:
		var 乙y := y + 偏移.y
		for x in 甲宽:
			var 甲i := y * 甲宽 + x
			var 乙x := x + 偏移.x
			if 甲透[甲i] <= 最小透明 or 乙y < 0 or 乙y >= 乙高 or 乙x < 0 or 乙x >= 乙宽:
				差值[甲i] = -1
				continue
			var 乙i := 乙y * 乙宽 + 乙x
			if 乙透[乙i] <= 最小透明:
				差值[甲i] = -1
				continue
			if 用掩码 and (梯甲[甲i] > 梯度门 or 梯乙[乙i] > 梯度门):
				差值[甲i] = -1
				continue
			var d := absi(int(甲灰[甲i]) - int(乙灰[乙i]))
			差值[甲i] = d
			计点 += 1
			最大差 = maxi(最大差, d)
			if d > 阈值:
				超阈 += 1
				差异[甲i] = 1

	var 域们 := _聚类(差值, 甲宽, 甲高, 阈值)

	# 分块：粗版式错位（少一格、整体偏几像素）在块级上很显眼，文字差在块级上被平均掉。
	var 块们: Array = []
	var 块x := int(ceil(float(甲宽) / 块))
	var 块y := int(ceil(float(甲高) / 块))
	for by in 块y:
		for bx in 块x:
			var 和 := 0
			var 数 := 0
			for y in range(by * 块, mini((by + 1) * 块, 甲高)):
				for x in range(bx * 块, mini((bx + 1) * 块, 甲宽)):
					var d := 差值[y * 甲宽 + x]
					if d >= 0:
						和 += d
						数 += 1
			if 数 > 0:
				var 均 := float(和) / 数
				if 均 > 块阈值:
					块们.append({"块": Vector2i(bx, by), "矩形": Rect2i(bx * 块, by * 块, 块, 块), "均值": 均})
	块们.sort_custom(func(a, b): return a["均值"] > b["均值"])

	return {
		"差异": 差异, "差值": 差值, "域们": 域们, "块们": 块们,
		"统计": {
			"甲宽": 甲宽, "甲高": 甲高, "计点": 计点, "超阈": 超阈,
			"最大差": 最大差, "掩码": 用掩码, "阈值": 阈值, "梯度门": 梯度门,
		},
	}


## 每个像素取四邻居里最大的梯度。用来识别"边缘像素"（文字/线条的光栅化差异都在那儿）。
static func _梯度(灰: PackedByteArray, 宽: int, 高: int) -> PackedByteArray:
	var 出 := PackedByteArray()
	出.resize(宽 * 高)
	for y in 高:
		for x in 宽:
			var i := y * 宽 + x
			var 中 := int(灰[i])
			var m := 0
			if x > 0:
				m = maxi(m, absi(中 - int(灰[i - 1])))
			if x < 宽 - 1:
				m = maxi(m, absi(中 - int(灰[i + 1])))
			if y > 0:
				m = maxi(m, absi(中 - int(灰[i - 宽])))
			if y < 高 - 1:
				m = maxi(m, absi(中 - int(灰[i + 宽])))
			出[i] = m
	return 出


## 差异像素做 8 连通域聚类，按**差异能量（Σ差）**降序。
## 不按面积排：一条 12x2 的线面积微不足道，但每像素差 40，能量照样进榜 ——
## 只按面积会把这种"细长但很显眼"的错位埋掉。
static func _聚类(差值: PackedInt32Array, 宽: int, 高: int, 阈值: int, 最小点数 := 6) -> Array:
	var 已访 := PackedByteArray()
	已访.resize(宽 * 高)
	var 出: Array = []
	for 起 in 宽 * 高:
		if 已访[起] == 1 or 差值[起] <= 阈值:
			continue
		var 队 := [起]
		已访[起] = 1
		var 左 := 起 % 宽
		var 右 := 左
		var 上 := 起 / 宽
		var 下 := 上
		var 点数 := 0
		var 能量 := 0
		var 最大 := 0
		while not 队.is_empty():
			var i: int = 队.pop_back()
			var x := i % 宽
			var y := i / 宽
			点数 += 1
			能量 += 差值[i]
			最大 = maxi(最大, 差值[i])
			左 = mini(左, x)
			右 = maxi(右, x)
			上 = mini(上, y)
			下 = maxi(下, y)
			for 邻 in [i - 1, i + 1, i - 宽, i + 宽, i - 宽 - 1, i - 宽 + 1, i + 宽 - 1, i + 宽 + 1]:
				if 邻 < 0 or 邻 >= 宽 * 高 or 已访[邻] == 1 or 差值[邻] <= 阈值:
					continue
				# 8 邻域要挡掉换行处的串门
				if absi((邻 % 宽) - x) > 1:
					continue
				已访[邻] = 1
				队.append(邻)
		if 点数 >= 最小点数:
			出.append({
				"矩形": Rect2i(左, 上, 右 - 左 + 1, 下 - 上 + 1),
				"点数": 点数, "最大差": 最大, "能量": 能量,
				"平均差": float(能量) / 点数,
			})
	出.sort_custom(func(a, b): return a["能量"] > b["能量"])
	return 出


## 给一个差异域找"最近控件"：拿 sidecar 里的控件矩形表，取重叠面积最大的那个。
## 这一步是"让工具自己指出来"的关键 —— 报告里写的应该是
## 「局部 (263,307) ↔ 页面容器/分隔线 (11,307,280x2)」，而不是一串坐标让人去数。
## ⚠️ 取**重叠率够高里最小的那个**控件，不是"重叠面积最大"的那个 ——
##    窗口边框（Panel）覆盖整窗，按面积永远它赢，报出来全是"窗口边框"，等于没点名。
static func 点名(域: Rect2i, 控件表: Array) -> String:
	var 最佳 := ""
	var 最佳面积 := 1 << 30
	var 域面 := maxi(1, 域.size.x * 域.size.y)
	for 项 in 控件表:
		var 数: Array = 项.get("矩形", [0, 0, 0, 0])
		var r := Rect2i(int(数[0]), int(数[1]), int(数[2]), int(数[3]))
		var 交 := 域.intersection(r)
		var 面积 := 交.size.x * 交.size.y
		if 面积 == 0:
			continue
		var 重叠率 := float(面积) / 域面
		if 重叠率 < 0.5:
			continue
		var 控件面积 := r.size.x * r.size.y
		if 控件面积 < 最佳面积:
			最佳面积 = 控件面积
			最佳 = "%s  %s  %s  重叠%d%%" % [
				项.get("路径", "?"), r, 项.get("类", ""), int(round(重叠率 * 100.0))]
	return 最佳 if not 最佳.is_empty() else "（附近没有已登记的控件）"


## 差异图：基线压暗作底 + 洋红高亮差异 + 画出配准落点框。人一眼能判配歪没有。
static func 画差异图(甲: Image, 乙: Image, 配: Dictionary, 比: Dictionary) -> Image:
	var 出 := 乙.duplicate() as Image
	if 出.get_format() != Image.FORMAT_RGBA8:
		出.convert(Image.FORMAT_RGBA8)
	var 偏移: Vector2i = 配["偏移"]
	var 甲宽 := 甲.get_width()
	var 甲高 := 甲.get_height()
	var 差异: PackedByteArray = 比["差异"]
	# 压暗：只在甲覆盖的那块上减半，让人看得出比的是哪一块
	for y in 甲高:
		for x in 甲宽:
			var 乙x := x + 偏移.x
			var 乙y := y + 偏移.y
			if 乙x < 0 or 乙y < 0 or 乙x >= 出.get_width() or 乙y >= 出.get_height():
				continue
			var c := 出.get_pixel(乙x, 乙y)
			出.set_pixel(乙x, 乙y, Color(c.r * 0.55, c.g * 0.55, c.b * 0.55, 1.0))
	for y in 甲高:
		for x in 甲宽:
			if 差异[y * 甲宽 + x] != 1:
				continue
			var 乙x := x + 偏移.x
			var 乙y := y + 偏移.y
			if 乙x >= 0 and 乙y >= 0 and 乙x < 出.get_width() and 乙y < 出.get_height():
				出.set_pixel(乙x, 乙y, Color(1.0, 0.0, 1.0))
	_画框(出, Rect2i(偏移, Vector2i(甲宽, 甲高)), Color(0.2, 1.0, 0.4))
	return 出


static func _画框(图: Image, r: Rect2i, 色: Color) -> void:
	for x in range(r.position.x, r.position.x + r.size.x):
		for y in [r.position.y, r.position.y + r.size.y - 1]:
			if x >= 0 and y >= 0 and x < 图.get_width() and y < 图.get_height():
				图.set_pixel(x, y, 色)
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in [r.position.x, r.position.x + r.size.x - 1]:
			if x >= 0 and y >= 0 and x < 图.get_width() and y < 图.get_height():
				图.set_pixel(x, y, 色)
