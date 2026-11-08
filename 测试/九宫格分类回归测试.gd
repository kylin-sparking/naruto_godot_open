## 九宫格边距表里，"哪些图**本来就不该有九宫格**"。
##
## 判定标准（§3.60.2）：看该图对应元件的**基类**——
##   * `ScaleSprite` 系（`ScaleSprite` / `MNoResizeWidth9ScaleSprite`）⇒ 九宫格**有效**；
##   * 普通 `Sprite` / `MovieClip` ⇒ `width=` 是**整帧非等比缩放**，九宫格根本不生效
##     ⇒ 四边必须**全 0**，否则只是把两端"拉长"。
##
## ⚠️ 这条门存在的理由：§3.60.2 当年那句结论把 `MGrid_background`（物品格）和
##    `BaowuBtn1~3` 一起说成"普通 Sprite"，**2026-10-01 复核发现只有 `LineHPicF` 是对的**。
##    谁照那句去"顺手修"物品格，就会把物品格拉变形。门把分类钉死，防止这种"照着错记录修"。
##
## **2026-10-01 20 项全部逐个核过**（元件与 PNG 按包围盒尺寸完全相等对上，
## 基类在 `2.2.3/.../mainlib_as/scripts` 下 grep `class X extends`）。完整对照表见
## `脚本/界面/原版皮肤表.gd` 的注释。这里只把**能判定的**三类钉成断言：
##   * 普通 `Sprite`（只有 横向分隔线）⇒ 四边**必须全 0**；
##   * `MNoResizeWidth9ScaleSprite`（滚动槽/滑块，宽度锁死）⇒ **左右必须 0**；
##   * 其余 `ScaleSprite` 系 ⇒ **不能全 0**（全 0 等于白配）。
## `分页选中` 那格对上的是**按钮本体**（`MTabButtonF` extends MButton3 extends Sprite），
## 判据对它不适用 ⇒ **豁免**，但显式列出来，免得被当成"漏了"。
##
## ⚠️ 这条门存在的理由：§3.60.2 当年把 `MGrid_background`（物品格）说成"普通 Sprite"，
##    谁照那句去"顺手修"就会把物品格拉变形。
extends SceneTree

const 皮肤 := preload("res://脚本/界面/原版皮肤表.gd")

var _failures: Array[String] = []
var _checked := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	_checked += 1
	if not ok:
		_failures.append(message)

func _全零(边距: Array) -> bool:
	for v in 边距:
		if int(v) != 0:
			return false
	return true

func _run() -> void:
	var 表: Dictionary = 皮肤.九宫格
	# ① 普通 Sprite ⇒ 必须全 0
	for 项 in [[皮肤.横向分隔线, "横向分隔线（LineHPicF extends Sprite）"]]:
		_check(表.has(项[0]), "表里应有 %s" % 项[1])
		if 表.has(项[0]):
			_check(_全零(表[项[0]]), "%s 必须全 0（实际 %s）" % [项[1], str(表[项[0]])])
	# ② 宽度锁死 ⇒ 左右必须 0
	for 项 in [[皮肤.滚动槽, "滚动槽"], [皮肤.滚动滑块, "滚动滑块"]]:
		if not 表.has(项[0]):
			_check(false, "表里应有 %s" % 项[1])
			continue
		var 边距: Array = 表[项[0]]
		_check(int(边距[0]) == 0 and int(边距[1]) == 0,
				"%s 的元件 width setter 被覆盖成空（宽度锁死）⇒ 左右边距必须 0（实际 %s）"
				% [项[1], str(边距)])
	# ③ ScaleSprite 系 ⇒ 不能全 0；豁免项单列
	var 豁免 := [皮肤.分页选中]
	var 有效 := [皮肤.窗口边框, 皮肤.小窗口边框, 皮肤.窗口内底, 皮肤.子面板, 皮肤.浅色面板,
			皮肤.内容面板, 皮肤.按钮, 皮肤.按钮按下, 皮肤.分页未选, 皮肤.物品格,
			皮肤.分页未选悬停, 皮肤.分页未选按下, 皮肤.方向箭头,   # 2026-10-04 并包新增（±30/−40 派生态与 ItemArrow，均 ScaleSprite 系）
			皮肤.按钮悬停, 皮肤.按钮按下态,   # 2026-10-20 标准钮的 ±30/−40 派生态（`开发工具/生成标准钮态图.py`）
			皮肤.输入框, 皮肤.选中条, 皮肤.进度槽, 皮肤.进度填充, 皮肤.提示框, 皮肤.列表分隔,
			# 2026-10-10 提示条底板（符号175 `MessageTipPane2_background`）。
			# 它的"九宫格生效"不是靠 AS3 基类判的，是靠**元件自己带 DefineScalingGridTag**：
			# MainLib 里 175 号有 `splitter Xmin=805 Xmax=5019 Ymin=585 Ymax=4630`（twips），
			# 而 `MessageTipPane2.as:156-204` 正是靠改 background 的宽/高来适配文案长度。
			皮肤.提示条底板]
	for 路径 in 有效:
		if not 表.has(路径):
			_check(false, "表里应有 %s" % String(路径).get_file())
			continue
		_check(not _全零(表[路径]),
				"%s 是 ScaleSprite 系，九宫格有效 ⇒ 不该全 0（实际 %s）"
				% [String(路径).get_file(), str(表[路径])])
	for 路径 in 豁免:
		_check(表.has(路径), "豁免项也该在表里：%s" % String(路径).get_file())
	# ④ 表里不许有"没被本门分类到"的漏网项
	var 已列 := 有效 + 豁免 + [皮肤.横向分隔线, 皮肤.滚动槽, 皮肤.滚动滑块]
	var 漏网: Array[String] = []
	for k in 表:
		if not 已列.has(k):
			漏网.append(String(k).get_file())
	_check(漏网.is_empty(),
			"这张表里出现了本门没分类的图：%s —— 加进上面某一类，别让它悄悄溜过" % ", ".join(漏网))
	if _failures.is_empty():
		print("九宫格分类回归测试：通过（%d 条断言）" % _checked)
		quit(0)
		return
	for failure in _failures:
		if not failure.is_empty():
			printerr(failure)
	quit(1)
