extends SceneTree

## 通灵驯养「属性提升页」中框回归门（§3.144）。
##
## 病根：我们那一版中框**写了一句通用话**（"生命/查克拉/攻击/防御/暴击/闪避/攻速/移速 都会随潜力提高"），
## 而原版 `PetStrongTab.getStrongAptPrm:678-687` 是**四行两列表** ——
##   左列 = 该宠的**当前潜力实值**（`potentialRealApAtk/Def/Dex/Str`），
##   右列 = **该资质档的 `min-max`**。
## ⚠️ 两条真值：① `if (pet.aptitude != PetAptitude.PREEMINENCE)` —— **资质 = 4 时原版返回空串**；
## ② 右侧区间取自 `info.potential.values["apt" + (资质 + 1)]`（= **升到下一档后**的区间），
##    这份数据 `数据/宠物.json` 里已经导出。
##
## 本门钉的是**算式与真值**（纯函数），不搭窗 —— 那扇窗的运行期渲染另由宠物那几道门看着。
## ② 2026-10-19（体检报告 P1-2）补 ④⑤ 两腿：「本次操作成功几率」漏算幸运符加成，
##    以及"算对了但没人重画"那半个 bug —— 所以 ⑤ 破例读一次窗脚本源码钉接线（纯函数门测不到）。
##
## 运行：`Godot --headless --path . --script res://测试/通灵驯养中框回归测试.gd`

const 驯养 := preload("res://脚本/界面/窗口/通灵驯养窗口.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 装备打造表 := preload("res://脚本/界面/装备打造表.gd")

var 红数 := 0


func _记(过: bool, 文: String) -> void:
	if not 过:
		红数 += 1
		print("!! " + 文)


func _initialize() -> void:
	# 拿一只真宠的模板（`00000101`，`info.potential.values` 是 apt1..apt4）
	var 信息: Dictionary = 游戏数据.pet_template(101).get("info", {})
	if 信息.is_empty():
		print("!! 读不到宠物模板 101 的 info")
		quit(1)
		return
	var 值: Dictionary = (信息.get("potential", {}) as Dictionary).get("values", {}) as Dictionary
	var 二档: Dictionary = 值.get("apt2", {}) as Dictionary
	if 二档.is_empty():
		print("!! `potential.values.apt2` 不在表里（该被导出）")
		quit(1)
		return

	# 刻意不对称的四个潜力值 —— 防"两边一起错"（§3.61.3）
	var 宠 := {"potential_real_atk": 896, "potential_real_def": 850,
		"potential_real_dex": 784, "potential_real_str": 940}

	# ① 资质 1 ⇒ 用 `values.apt2`（升到下一档后的区间），四行顺序 = 攻/防/灵/健
	var 文 := 驯养.中框表(宠, 信息, 1)
	# ⚠️ 钉的是**本工程消费的标记**，不是 AS3 的字面标签。原版 `:684` 拼的是 Flash 那套
	#    `<font color='#ffffff'>…<br>…</font>`；本工程把这段塞给 `中效果内容`
	#    （`场景/界面/窗口/宠物/宠物提升页.tscn` 上 `bbcode_enabled = true` 的 RichTextLabel），
	#    原标签不会被解释 ⇒ **整串显示给玩家**（2026-10-18 巡检 #28 的第⑤项扫的就是这类漏网的裸标签）。
	#    ⇒ 移植时按口径换成 BBCode，这里跟着钉 BBCode；`测试/宠物面板回归测试.gd:155` 同一条。
	_记(文.begins_with("[color=#ffffff]") and 文.ends_with("[/color]"),
			"中框该是 `[color=#ffffff]…[/color]` 包起来（原版 `:684` 那两个 font 的 BBCode 等价物）")
	for 对 in [["攻击潜力", 896], ["防御潜力", 850], ["灵巧潜力", 784], ["健体潜力", 940]]:
		_记(文.contains("%s ：%d" % [对[0], 对[1]]),
				"左列该是**当前潜力实值**：%s ：%d，实测文里「%s」" % [对[0], 对[1], 文])
	_记(文.count(" ：%d-%d" % [int(二档.get("min", 0)), int(二档.get("max", 0))]) == 4,
			"右列四行都该是 `values.apt2` 的 %d-%d（资质 1 看的是**下一档**）"
			% [int(二档.get("min", 0)), int(二档.get("max", 0))])
	_记(文.count("\n") == 4, "四行都要带换行（原版四个 `<br>`），实测 %d" % 文.count("\n"))

	# ② 资质 4（`PetAptitude.PREEMINENCE`）⇒ 原版**返回空串**。
	# ⚠️ 老实说：这条**不区分**是"PREEMINENCE 那道 guard"还是"`apt5` 不在表里"的兜底生效 ——
	#    本数据里 `values` 只有 apt1..apt4，两条路都给空串（反向对照实测过：把 guard 改成 99 仍绿）。
	#    钉的是**行为**（资质 4 不给表），不是那条 guard 本身。
	_记(驯养.中框表(宠, 信息, 4) == "", "资质 = 4（稀有/顶级）时原版返回**空串**，实测「%s」"
			% 驯养.中框表(宠, 信息, 4))
	# ③ 牌面没有那一档 ⇒ 空串（不硬凑）
	_记(驯养.中框表(宠, 信息, 5) == "", "`values` 里没有 `apt6` ⇒ 该返回空串，实测「%s」"
			% 驯养.中框表(宠, 信息, 5))

	# ④ 「本次操作成功几率」漏算幸运符（2026-10-19 体检报告 P1-2，实测确认为真）。
	#    真值 `PetStrongTab.as:704-712`：`int(param1.probability)` 起算，
	#    **只有勾了幸运符**才 `+ (selectedIndex + 1) * UIConfig.xingYunJingRatio`（那颗数 = 3，`UIConfig.as:976`）。
	#    我们那一版只画 `probability` 就完事 ⇒ 勾了符、选了 9 颗，窗上的百分比一动不动。
	var 低 := {"probability": 30.7, "needMoney": 1000}
	_记(驯养.提升几率(低, false, 9) == 30, "不勾幸运符 ⇒ 就是 `int(probability)`（30.7 → 30，**先取整后加**）")
	_记(驯养.提升几率(低, true, 1) == 33, "勾 1 颗 ⇒ +3（`selectedIndex + 1`）")
	_记(驯养.提升几率(低, true, 9) == 57, "勾 9 颗 ⇒ +27")
	# ⚠ 原版这一支**没有** `mini(100, …)`（装备那条路 `装备打造表.实际成功率` 才有）⇒ 高基础 + 满符就是 >100。
	#    钉住这个"不夹"：将来有人"顺手统一"成夹 100，这里会红，逼他来看真值。
	_记(驯养.提升几率({"probability": 80}, true, 9) == 107,
			"原版不夹 100 ⇒ 基础 80% 勾 9 颗写 107%（`PetStrongTab.as:711` 直接把数塞进模板）")
	_记(驯养.幸运符每张加成 == 装备打造表.幸运符加成 and 装备打造表.幸运符加成 == 3,
			"宠物与装备**共用同一颗** `xingYunJingRatio`（原版是全局常量）⇒ 不许各写一份 3")

	# ⑤ 勾了符数字要**重画**（`:714-719` 与下拉 CHANGE 都汇进 `xinYunJingSelectedHandler:352-356`
	#    重写整段 htmlText）。只钉纯函数会漏掉这一半 —— 算对了但没人再调它，玩家看到的还是旧数。
	var 源 := FileAccess.get_file_as_string("res://脚本/界面/窗口/通灵驯养窗口.gd")
	_记(源.contains("勾选.toggled.connect"),
			"幸运符勾选没接 `toggled`（原版 `MCheckBox` 点击走 `checkBoxClickHandler:714-719`）")
	_记(源.contains("数量.item_selected.connect"),
			"幸运符颗数没接 `item_selected`（原版下拉 CHANGE ⇒ `xinYunJingSelectedHandler`）")
	_记(源.count("画消耗.call()") >= 3,
			"开页画一次 + 勾选 + 颗数各调一次 `画消耗`（实测 %d 处）⇒ 少一处就是勾了不动"
			% 源.count("画消耗.call()"))
	_记(源.contains("_驯养幸运符数 = 号 + 1"),
			"下拉**下标**要 +1 才是颗数（真值 §17：combo 数据 1..9）")

	if 红数 == 0:
		print("通灵驯养中框回归测试：通过（四行两列 / 左列实值 / 右列下一档区间 / PREEMINENCE 空串 / 幸运符几率与重画）")
		quit(0)
	else:
		print("通灵驯养中框回归测试：失败 %d 项" % 红数)
		quit(1)
