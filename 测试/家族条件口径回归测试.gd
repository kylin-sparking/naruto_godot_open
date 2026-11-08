extends SceneTree

## 家族「创建条件 / 升级条件 / 家徽样式」的口径回归门。
##
## 这三条都是**显示与服务端必须一致**的东西，错了的表现是"按钮永远点不动"或
## "显示了玩家根本凑不齐的数字"，肉眼很难发现。所以逐条钉住：
##
##   1. **创建条件** = `flag["1"].cost`：材料 **16000022 ×1**、金币 **0**
##      （原版 `FamillyManager.getFamillyCreateCfg()` 读的就是它）。
##   2. **升级条件** = 单机版写死的 **666 金币 + 春夏秋冬书各 1**，最高 **10 级**。
##      ⚠️ 这里专门断言它**不等于**原始数据里 `flag[2].cost.money`（1000 万）——
##         我们之前就是误用了那张表，导致显示 1000 万而服务端只收 666。
##   3. **家徽样式表** = 1000~1019 共 20 个，且**每一个都必须有对应家徽素材**
##      （否则翻页翻到某项就是空白）。
##
## 另外用真实创建窗场景跑一遍 `家族创建填充.校验()` 的四条拦截文案。
##
## 运行：Godot --headless --path . --script res://测试/家族条件口径回归测试.gd

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 家徽图 := preload("res://脚本/界面/窗口/家族/家徽图.gd")
const 创建填充 := preload("res://脚本/界面/窗口/家族/家族创建填充.gd")

const 创建窗场景 := "res://场景/界面/窗口/家族/家族创建窗.tscn"
const 创建材料 := 16000022
const 升级材料: Array[int] = [16000023, 16000024, 16000025, 16000026]

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_验创建条件()
	_验升级条件()
	_验样式表()
	await _验创建窗校验()
	_结束()

func _结束() -> void:
	if _failures.is_empty():
		print("家族条件口径回归测试：PASS")
		quit(0)
		return
	print("家族条件口径回归测试：FAIL")
	for f in _failures:
		print("  ✗ ", f)
	quit(1)

## ── 1. 创建条件 ───────────────────────────────────────────────────────────
func _验创建条件() -> void:
	var 消耗 := 游戏数据.family_create_cost()
	var 行: Array = 消耗.get("item", [])
	if 行.is_empty():
		_failures.append("创建条件里一件材料都没有")
		return
	var 第一项 := 行[0] as Dictionary
	if int(第一项.get("id", 0)) != 创建材料:
		_failures.append("创建材料应是 %d，实测 %d" % [创建材料, int(第一项.get("id", 0))])
	if int(第一项.get("count", 0)) != 1:
		_failures.append("创建材料数量应是 1，实测 %d" % int(第一项.get("count", 0)))
	if int(消耗.get("money", -1)) != 0:
		_failures.append("创建金币应是 0（单机版一分钱不收），实测 %d" % int(消耗.get("money", -1)))
	# 材料名必须查得到（UI 上那行文案就是它拼的）
	var 名 := 游戏数据.family_material_name(创建材料, "")
	if 名.is_empty():
		_failures.append("物品表里查不到 %d 的名字" % 创建材料)
	else:
		print("  创建条件：%s ×1、金币 0" % 名)

## ── 2. 升级条件 ───────────────────────────────────────────────────────────
func _验升级条件() -> void:
	var 配置 := 游戏数据.family_upgrade_cost(2)
	if 配置.is_empty():
		_failures.append("2 级升级配置为空")
		return
	if int(配置.get("money", 0)) != 666:
		_failures.append("升级金币应是 666，实测 %d" % int(配置.get("money", 0)))
	var 行: Array = 配置.get("item", [])
	if 行.size() != 升级材料.size():
		_failures.append("升级材料应有 %d 种，实测 %d" % [升级材料.size(), 行.size()])
	for i in mini(行.size(), 升级材料.size()):
		var 条目 := 行[i] as Dictionary
		if int(条目.get("id", 0)) != 升级材料[i]:
			_failures.append("升级材料第 %d 项应是 %d，实测 %d" % [i, 升级材料[i], int(条目.get("id", 0))])
		if int(条目.get("count", 0)) != 1:
			_failures.append("升级材料第 %d 项数量应是 1，实测 %d" % [i, int(条目.get("count", 0))])
	# 最高 10 级：11 级必须没有配置（原版 getFamillyUpgradeCfg 这时返回 null）
	if not 游戏数据.family_upgrade_cost(11).is_empty():
		_failures.append("11 级不该有升级配置（最高 %d 级）" % 游戏数据.家族最高等级)
	if not 游戏数据.family_upgrade_cost(1).is_empty():
		_failures.append("1 级是初始等级，不该有'升到 1 级'的配置")
	# ⭐ 关键：**不能**等于原始数据表里的金币（那是线上口径，1000 万起）
	var 原始 := int(float((游戏数据.family_flag_config(2).get("cost", {}) as Dictionary).get("money", 0)))
	if 原始 > 0 and 原始 == int(配置.get("money", 0)):
		_failures.append("升级金币等于原始数据表的 %d —— 说明又用回线上口径了" % 原始)
	print("  升级条件：金币 666 + 春夏秋冬书各 1，最高 %d 级（原始线上数据是 %d 金币，已隔离）" % [
		游戏数据.家族最高等级, 原始])

## ── 3. 家徽样式表 ─────────────────────────────────────────────────────────
func _验样式表() -> void:
	var 表 := 游戏数据.family_create_styles()
	if 表.size() != 20:
		_failures.append("创建窗可翻页样式应有 20 个（1000~1019），实测 %d" % 表.size())
	if 表.is_empty() or 表[0] != 1000 or 表[-1] != 1019:
		_failures.append("样式表范围不对：%s … %s" % [表[0] if 表.size() > 0 else "-", 表[-1] if 表.size() > 0 else "-"])
	var 缺图 := 0
	for 样式 in 表:
		if 家徽图.取(样式) == null:
			缺图 += 1
	if 缺图 > 0:
		_failures.append("有 %d 个样式没有家徽素材（翻到那页会是空白）" % 缺图)
	else:
		print("  样式表：%d 个（%d~%d），全部有家徽素材" % [表.size(), 表[0], 表[-1]])

## ── 4. 创建窗校验（用真场景跑）───────────────────────────────────────────
func _验创建窗校验() -> void:
	var packed := load(创建窗场景) as PackedScene
	if packed == null:
		_failures.append("加载创建窗场景失败")
		return
	var 页 := packed.instantiate() as Control
	root.add_child(页)
	var 宿主 := Node.new()
	root.add_child(宿主)
	# ⚠️ **不要**自己 new 一个叫 BackendConnection 的节点挂到 root：`/root` 下已经有它这个
	#    自动加载单例，Godot 会给我的同名节点改名（`@BackendConnection@2`）——于是
	#    `校验` 里 `宿主.get_node_or_null("/root/BackendConnection")` 拿到的是**自动加载那个**，
	#    我给测试节点塞的背包根本读不到（第一版就栽在这：给了料仍然被拦）。
	var 后端 := root.get_node_or_null("BackendConnection")
	if 后端 == null:
		_failures.append("没有 BackendConnection 自动加载")
		页.queue_free()
		宿主.queue_free()
		return
	await process_frame
	var 名框 := 页.get_node_or_null("输入家族名") as LineEdit
	var 徽框 := 页.get_node_or_null("输入家徽名") as LineEdit
	if 名框 == null or 徽框 == null:
		_failures.append("创建窗缺少 输入家族名 / 输入家徽名")
		return
	_期望拦截(页, 宿主, "", "", "请输入家族名称")
	_期望拦截(页, 宿主, "木", "", "家族名至少 2 个字")
	_期望拦截(页, 宿主, "木叶", "", "请输入家徽名称")
	_期望拦截(页, 宿主, "木叶", "徽", "家徽名至少 2 个字")
	# 料不够：拦截（文案里要出现材料名）
	_期望拦截(页, 宿主, "木叶忍者村", "家徽", "不足")
	# 给足料：必须放行。
	# ⚠️ `authoritative_inventory` 是 `Array[Dictionary]` 的**类型化数组**，
	#    直接赋一个无类型 `Array` 字面量会报 Invalid assignment（而且错误之后行为不可靠）。
	#    必须先建同类型的数组再赋。
	var 背包: Array[Dictionary] = [{"id": 创建材料, "quantity": 1}]
	后端.authoritative_inventory = 背包
	if int(后端.call("inventory_quantity", 创建材料)) != 1:
		_failures.append("背包数量查询没读到自己塞的那一项")
	var 放行 := String(创建填充.校验(页, 宿主))
	if not 放行.is_empty():
		_failures.append("材料给足后仍被拦下：%s" % 放行)
	else:
		print("  创建窗校验：五条拦截 + 材料给足放行，全部符合")
	页.queue_free()
	宿主.queue_free()


func _期望拦截(页: Control, 宿主: Node, 家族名: String, 家徽名: String, 关键字: String) -> void:
	(页.get_node("输入家族名") as LineEdit).text = 家族名
	(页.get_node("输入家徽名") as LineEdit).text = 家徽名
	var 结果 := String(创建填充.校验(页, 宿主))
	if 结果.is_empty():
		_failures.append("「%s / %s」本该被拦下（关键字 %s），却放行了" % [家族名, 家徽名, 关键字])
	elif not 结果.contains(关键字):
		_failures.append("「%s / %s」的提示里没有「%s」：%s" % [家族名, 家徽名, 关键字, 结果])
