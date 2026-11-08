extends SceneTree

## 八门读秒落点回归门（2026-10-22，用户报修 2「贯通穴位读秒显示偏下，应该在人物上方，
## 现在在人物头部的位置」）。
##
## 原版的账（都是逐行读出来的，不是推的）：
##   · `Character.as:2380/2508` ⇒ `_crtCharHeight = 当帧 body 位图高 + 3`（**逐帧**刷，不是常数）；
##   · `Character.as:313` ⇒ `tickMaiDelay` 里 `_maiNum.y = -_crtCharHeight - 5`；
##   · `ColorNumber.as:54-72/74-102` ⇒ 拼串只按**墨迹左缘**接 x、末了 `container.x = -宽/2`，
##     **从头到尾没有一行写过 y** ⇒ 竖直落点完全由元件自己的注册点决定；
##   · `数据/特效.json` 那 6 组 No* 的每帧 `原点` 都是 `[0,0]`（本工程抽出素材时读到的注册点）。
## 我们上一版 `-贴图高 - 5` 少抄了那个 `+3`，但**3 px 撑不起这句报修**：真正的原因是
## `NoBlue0` 十个数字实测画布一律 31×33、**墨迹贴着画布下沿**（顶空只有 0~1 px）⇒
## 注册点钉在头顶上方 5~8 px、墨迹却往下长 33 px ⇒ 原版就是把读秒垂在头上。
## ⚠ 所以这一条是**有意偏离**（同 §3.203 商城删充值键、§3.236 堆叠上限抬 9999 那类，用户实机口径优先）：
## 把整串的**底边**摆到原版顶边那个位置 ⇒ 数字整体落到头顶之上，`+3` 与 `5` 两个常数照旧保留。
##
## 盯八件：
##   ① 素材账（画布 31×33、注册点 [0,0]）——换了素材这五条要红；
##   ② 两位数建出两枚、左右对称于 x=0（原版 `container.x = -宽/2`）；
##   ③ 竖直底边 = −(当帧贴图高 + 3 + 5)，**3 与 5 是手抄的字面量**，不读产品码里的常量；
##   ④ 整串在头顶之上（底边 ≤ −原点.y），这才是要修的表象；
##   ⑤ 一位数与两位数同一条底边（换秒不许上下跳）；
##   ⑥ 量不到高 ⇒ **不动**（不许按 0 把数字甩到身上，同 `玩家.gd:976` 那根箭头的口径）；
##   ⑦ 高又能量到了 ⇒ 下一帧跟回公式；
##   ⑧ 层序 2000（原版 `adjustLayer` 把 `_maiNum` 排在 `_namePane` **之后** ⇒ 盖名字牌）、收秒即摘。
##
## ⚠ 三条口径：
##   · 本门**不截屏**，纯算几何 ⇒ `--headless` 能跑，进得了全量清单；
##   · 贴图高/原点取的是**真实角色帧**（stand 第 0 帧），别拿常数当期望值 —— 期望值只有
##     字面量 3、5 与素材的 31×33，其余都跟着实测走（§3.223「参照物不能来自被测对象」的反面：
##     被测对象是落点算式，参照是手抄常数 + 素材实测）；
##   · 加载地图场景会碰 `user://`，靠 runner 的逐门字节快照兜底（§3.217）。
##
## 运行：`Godot --headless --path . --script res://测试/八门读秒落点回归测试.gd`

var 通过 := 0
var 红: Array[String] = []
var _秒 := 0.0


## 手抄字面量（改动原版账时这里要跟着改，不是跟着产品码改）
const 抬常量 := 3.0		# `Character.as:2380/2508` 的 `charHeight + 3`
const 间距常量 := 5.0		# `Character.as:313` 的 `- _crtCharHeight - 5`
const 画布宽 := 31.0		# `素材/特效/Effect_colorNumber/NoBlue0/1..10.png` 实测
const 画布高 := 33.0


func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 90.0:
		printerr("八门读秒落点回归测试：看门狗超时（90s）—— 中途崩了没走到收尾")
		quit(1)
		return true
	return false


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
	else:
		红.append(话)
		print("红：%s" % 话)


func _initialize() -> void:
	await _跑()
	print("八门读秒落点：绿 %d 红 %d" % [通过, 红.size()])
	quit(1 if 红.size() > 0 else 0)


## 数字串在**人物局部坐标**里的墨迹盒
func _盒(玩: Node) -> Rect2:
	var 结 = 玩.get_node_or_null("八门读秒")
	if 结 == null:
		return Rect2()
	var 合 := Rect2()
	for 片 in 结.get_children():
		var r := Rect2(结.position + (片 as Control).position, (片 as Control).size)
		合 = r if 合.size.x <= 0.0 or 合.size.y <= 0.0 else 合.merge(r)
	return 合


func _跑() -> void:
	root.size = Vector2i(960, 560)
	for i in 4:
		await process_frame
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	for i in 30:
		await process_frame
	var 玩 = 场景.get_node_or_null("Player")
	_判(玩 != null, "地图场景里有 Player 节点")
	if 玩 == null:
		return
	var 精灵 = 玩.get("player_sprite")
	_判(精灵 != null, "Player 建出了精灵")
	if 精灵 == null:
		return
	var 内层 = 精灵.get("sprite")
	_判(内层 != null, "精灵里有那枚真正贴图的子节点")
	var 高 := float(精灵.call("当前贴图高度"))
	var 头顶 := -float((精灵.call("当前原点") as Vector2).y)
	_判(高 > 0.0, "量到了当帧贴图高（实得 %.1f）" % 高)

	## ── ① 素材账 ────────────────────────────────────────────────
	for 帧号 in [1, 2, 7, 10]:
		var 纹 := load("res://素材/特效/Effect_colorNumber/NoBlue0/%d.png" % 帧号) as Texture2D
		_判(纹 != null, "NoBlue0 第 %d 帧纹理在库" % 帧号)
		if 纹 != null:
			_判(absf(纹.get_width() - 画布宽) < 0.01 and absf(纹.get_height() - 画布高) < 0.01,
					"NoBlue0 第 %d 帧画布仍是 %s×%s（实得 %.0f×%.0f）" % [
							帧号, str(画布宽), str(画布高), 纹.get_width(), 纹.get_height()])

	## ── ②③④ 两位数：建串、底边、在头顶之上 ─────────────────────
	玩.call("开始八门读秒", 12, false)
	for i in 2:
		await process_frame
	var 结 = 玩.get_node_or_null("八门读秒")
	_判(结 != null, "开读秒后身上挂出了「八门读秒」节点")
	if 结 == null:
		return
	var 双 := _盒(玩)
	var 枚数 := 结.get_children().size()
	_判(枚数 == 2, "12 秒 ⇒ 两枚数字（实得 %d）" % 枚数)
	_判(absf(双.position.x + 画布宽) < 0.01 and absf(双.end.x - 画布宽) < 0.01,
			"整串左右对称于 x=0（原边 %s、实得 [%.1f, %.1f]）" % [str(-画布宽), 双.position.x, 双.end.x])
	var 期望底 := -(高 + 抬常量 + 间距常量)
	print("当帧贴图高=%.1f 头顶=%.1f ⇒ 底边期望 %.1f（= −(高+%.0f+%.0f)）实得 %.1f" % [
			高, 头顶, 期望底, 抬常量, 间距常量, 双.end.y])
	_判(absf(双.end.y - 期望底) < 0.01,
			"底边 = −(贴图高 + 3 + 5)（实得 %.1f，期望 %.1f）" % [双.end.y, 期望底])
	_判(absf(双.size.y - 画布高) < 0.01, "整串高 = 画布高 %s（实得 %.1f）" % [str(画布高), 双.size.y])
	_判(双.end.y <= 头顶 + 0.01, "整串在**头顶之上**（底边 %.1f ≤ 头顶 %.1f）" % [双.end.y, 头顶])
	_判(双.end.y < 0.0, "整串在脚点之上（没掉回身上）")
	_判(头顶 - 双.end.y >= 1.0, "头顶与数字底边之间留得出缝（缝 %.1f px）" % (头顶 - 双.end.y))

	## ── ⑤ 一位数与两位数同一条底边 ──────────────────────────────
	玩.call("_停八门读秒")
	for i in 2:
		await process_frame
	_判(玩.get_node_or_null("八门读秒") == null or
			(玩.get_node_or_null("八门读秒") as Node).get_children().is_empty(),
			"收秒后那串数字不留在身上")
	玩.call("开始八门读秒", 3, false)
	for i in 2:
		await process_frame
	var 单 := _盒(玩)
	var 结2 = 玩.get_node_or_null("八门读秒")
	_判(结2 != null and 结2.get_children().size() == 1, "3 秒 ⇒ 一枚数字")
	_判(absf(单.end.y - 期望底) < 0.01,
			"换秒（两位→一位）底边不动（实得 %.1f，期望 %.1f）" % [单.end.y, 期望底])
	_判(absf(单.position.x + 画布宽 * 0.5) < 0.01 and absf(单.end.x - 画布宽 * 0.5) < 0.01,
			"一枚时整串居中在 x=0（实得 [%.1f, %.1f]，期望 [%.1f, %.1f]）" % [
					单.position.x, 单.end.x, -画布宽 * 0.5, 画布宽 * 0.5])

	## ── ⑥⑦ 量不到高 ⇒ 不动；又能跟回来 ──────────────────────────
	var 旧y := (结2 as Node2D).position.y
	var 原贴图 = 内层.get("texture")
	内层.set("texture", null)
	玩.call("开始八门读秒", 7, false)
	for i in 2:
		await process_frame
	var 结3 = 玩.get_node_or_null("八门读秒")
	_判(结3 != null, "贴图量不到时那串数字照样建出来了")
	if 结3 != null:
		_判(absf((结3 as Node2D).position.y - 旧y) < 0.01,
				"量不到高 ⇒ **不动**（y 仍是 %.1f，没按 0 甩到 %.1f）" % [
						旧y, -(抬常量 + 间距常量 + 画布高)])
	内层.set("texture", 原贴图)
	玩.call("_刷新八门读秒")
	for i in 2:
		await process_frame
	var 结4 = 玩.get_node_or_null("八门读秒")
	if 结4 != null:
		## 节点原点 = 墨迹顶边 = 底边 − 画布高
		_判(absf((结4 as Node2D).position.y - (期望底 - 画布高)) < 0.01,
				"高又量得到 ⇒ 位置跟回公式（实得 %.1f，期望 %.1f）" % [
						(结4 as Node2D).position.y, 期望底 - 画布高])
	_判(内层.get("texture") == 原贴图, "把贴图还回去了（别把角色的脸留在 null 上）")

	## ── ⑧ 层序 ──────────────────────────────────────────────────
	_判(结4 != null and int((结4 as Node2D).z_index) == 2000,
			"读秒 z=2000 ⇒ 盖在名字牌之上（原版 adjustLayer 把 _maiNum 排在 _namePane 之后）")
	玩.call("_停八门读秒")
	for i in 3:
		await process_frame
	_判(玩.get_node_or_null("八门读秒") == null, "收秒后整个读秒节点摘掉")
	print("八门读秒落点：跑完")
