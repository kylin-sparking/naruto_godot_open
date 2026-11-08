## NPC 头顶的任务标记 + 选中箭头落在哪、是不是原版那三张真图。
##
## 真值一：标记的挂点 `NPCSprite.as:385`（在 `set cy()` 里）
##     `this._npcQuestIcon.y = -this.ci.bmd.height - 5;`   x = 0（`:260`）
## `cy` 每帧都会被设 ⇒ 这个 y **跟当前帧的贴图高走**（和血条同一档，
## 不是世界名字那种"跟脚点的常量"）。
## ⚠ 我们原来写死 `-122`。它大约等于"本图 NPC 美术高 117"时的值 —— 正是
## §0.0 里那条**"别硬编码量出来的常数"**：换张图、换套 NPC 美术就错位。
##
## 真值二：选中箭头的挂点 `Monster.as:810-812` / `NPC.as:45-47`
##     `x = 0; y = -贴图高 - 8`（不是 -5！两档差 3px）。
##
## 真值三：三档标记各是哪张图 —— `NPCQuestPopup.as:15-36` 按 `NpcQuestStatus`
## （`data/enums/NpcQuestStatus.as:5-13` = 0 无 / 1 可接 / 2 可交 / 3 进行中）取
## `QuestIcon_0 / _2 / _1`。**可交是金色问号、只有可接才是叹号**；
## 以前 `游戏会话.get_quest_marker()` 把枚举读成「1 进行中 / 2 可接 / 3 可交」，
## 于是可交那档被画成叹号 —— 这条也钉住，别再翻回去。
##
## 门：① 每个 NPC 的标记 y == `-贴图高 - 5`；② 图里有两种以上不同高的 NPC ⇒ y 必须不一样
##    （只测①的话写死 117 也能蒙混）；③ 故意摆错后重算要回到原处（"跟帧走"的直接证据）；
##    ④ 四档状态各自落到哪张特效、0 档不建节点；⑤ 箭头 y == `-贴图高 - 8` 且播的是真图；
##    ⑥ 源上不许再有自造的圆环皮 / 手画箭头场景。
extends SceneTree

const 状态表 := {"无": 0, "可接": 1, "可交": 2, "进行中": 3}

var _failures: Array[String] = []
var _checked := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	_checked += 1
	if not ok:
		_failures.append(message)

func _run() -> void:
	_验档位对应(load("res://脚本/单例/游戏会话.gd"))
	_验源上没有自造件()

	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	for _frame in 12:
		await process_frame
	var 生怪根 := 场景.get_node_or_null("LifeRoot")
	if 生怪根 == null:
		_check(false, "没有 LifeRoot")
		_finish()
		return
	var 高度表 := {}
	var 检查过 := 0
	var 挂过 := 0
	for 实体 in 生怪根.get("_entities") as Array:
		var 谁 := 实体 as Node2D
		if 谁 == null or String(谁.get("kind")) != "n":
			continue
		# 强制挂上标记（不去依赖"这一帧正好有任务"），再让它自己归位
		生怪根.call("_挂任务标记", 谁, 状态表["可接"])
		var 标记 := 谁.get_node_or_null("QuestMarker") as Node2D
		if 标记 == null:
			continue
		挂过 += 1
		var 高: float = 谁.call("贴图高")
		if 高 <= 0.0:
			continue
		检查过 += 1
		_check(absf(标记.position.y - (-高 - 5.0)) < 0.01,
				"标记的 y 应为 -贴图高-5（贴图高 %.0f ⇒ 期望 %.0f，实际 %.0f）" % [高, -高 - 5.0, 标记.position.y])
		_check(absf(标记.position.x) < 0.01, "标记的 x 应为 0（`NPCSprite.as:260`），实际 %.1f" % 标记.position.x)
		高度表[int(高)] = 标记.position.y
	_check(挂过 > 0, "本地图应有可挂标记的 NPC（实际 0 个）")
	_check(检查过 > 0, "本地图应有带美术（贴图高 > 0）的 NPC 可供检查（实际 0 个）")
	_check(高度表.size() > 1,
			"本地图应有两种以上不同高的 NPC，好证明 y 不是个常数（实际 %d 种高度：%s）"
			% [高度表.size(), str(高度表.keys())])

	# 换个帧（贴图高变了）后，标记要跟着走
	for 实体 in 生怪根.get("_entities") as Array:
		var 谁 := 实体 as Node2D
		if 谁 == null or String(谁.get("kind")) != "n":
			continue
		var 标记 := 谁.get_node_or_null("QuestMarker") as Node2D
		if 标记 == null:
			continue
		var 旧 := 标记.position.y
		标记.position.y = 0.0                      # 故意摆错
		谁.call("_更新头顶挂件位置")
		_check(absf(标记.position.y - 旧) < 0.01, "重算后标记应回到原处（期望 %.1f，实际 %.1f）" % [旧, 标记.position.y])
		break

	_验选中箭头(生怪根)
	_finish()

## ④ 状态 → 特效键，逐条对着 `NPCQuestPopup.as:15-36` 钉
func _验档位对应(会话类) -> void:
	var 期望 := {状态表["无"]: "", 状态表["可接"]: "QuestIcon_0", 状态表["可交"]: "QuestIcon_2",
			状态表["进行中"]: "QuestIcon_1"}
	for 状态 in 期望:
		var 实得 := String(会话类.任务标记特效(int(状态)))
		_check(实得 == String(期望[状态]),
				"状态 %s 应取特效「%s」，实际「%s」（`NPCQuestPopup.as:15-36`）" % [str(状态), 期望[状态], 实得])
		if String(期望[状态]).is_empty():
			continue
		_check(ResourceLoader.exists("res://素材/特效/%s/%s_0.png" % [期望[状态], 期望[状态]]),
				"特效 %s 的首帧贴图不在盘上" % 期望[状态])
		var 条目: Dictionary = _特效条目(String(期望[状态]))
		_check(not 条目.is_empty(), "数据/特效.json 里没有 %s" % 期望[状态])
		if 条目.is_empty():
			continue
		_check(String(条目.get("元件", "")) == String(期望[状态]),
				"%s 这条的「元件」应当就是它自己，实际「%s」" % [期望[状态], 条目.get("元件", "")])

func _特效条目(名: String) -> Dictionary:
	var 文件 := FileAccess.open("res://数据/特效.json", FileAccess.READ)
	if 文件 == null:
		return {}
	var 解: Variant = JSON.parse_string(文件.get_as_text().trim_prefix("﻿"))
	if typeof(解) != TYPE_DICTIONARY:
		return {}
	var 特效: Dictionary = 解.get("特效", {})
	return 特效.get(名, {}) as Dictionary

## ⑥ 自造件不许回来。`_create_quest_marker` 那版是 `StyleBoxFlat` 画的圆环 + `Label` 打字符，
## 箭头那版是 `人物选中标记.tscn` 里两块 Polygon2D —— 两处都已换成导出的真图。
func _验源上没有自造件() -> void:
	var 宿主 := FileAccess.get_file_as_string("res://脚本/地图/地图实体.gd")
	_check(not 宿主.contains("_create_quest_marker"), "地图实体.gd 里还留着 _create_quest_marker（自造圆环那版）")
	_check(not 宿主.contains("QuestMarkerRing"), "地图实体.gd 里还留着 QuestMarkerRing")
	_check(not 宿主.contains("SELECTION_MARKER_SCENE"), "地图实体.gd 还 preload 着手画箭头那个场景")
	_check(not ResourceLoader.exists("res://场景/界面/组件/人物选中标记.tscn"),
			"手画的 人物选中标记.tscn 又回到 场景/ 里了（它已挪到 真值/作废素材/）")
	var 角色 := FileAccess.get_file_as_string("res://脚本/角色/战斗角色.gd")
	_check(not 角色.contains("QuestMarkerRing"), "战斗角色.gd 的 附属件 里还留着 QuestMarkerRing")
	## 只查**赋值语句**里有没有硬编码的头顶 y —— 注释里那两个数是拿来记教训的，不算违规。
	## 逐行只汇成**一条**断言：一行一条会把断言数撑到几百，"多少条"就没有意义了。
	var 硬码: Array[String] = []
	for 行 in 角色.split("
"):
		if 行.strip_edges().begins_with("##") or not 行.contains("="):
			continue
		if 行.contains("-122") or 行.contains("-108"):
			硬码.append(行.strip_edges())
	_check(硬码.is_empty(), "战斗角色.gd 里又出现写死的头顶 y（-122 / -108）：%s" % " ; ".join(硬码))

## ⑤ 选中箭头：挂点 -8（不是 -5），播的是 `MobSelected_Effect_Skin`
func _验选中箭头(生怪根) -> void:
	for 实体 in 生怪根.get("_entities") as Array:
		var 谁 := 实体 as Node2D
		if 谁 == null or String(谁.get("kind")) != "n":
			continue
		var 箭头 := 谁.get_node_or_null("SelectionMarker") as Node2D
		if 箭头 == null:
			_check(false, "NPC 上没有预挂的 SelectionMarker")
			return
		var 高: float = 谁.call("贴图高")
		if 高 <= 0.0:
			continue
		_check(absf(箭头.position.y - (-高 - 8.0)) < 0.01,
				"选中箭头的 y 应为 -贴图高-8（`Monster.as:811` / `NPC.as:46`；贴图高 %.0f ⇒ 期望 %.0f，实际 %.0f）"
				% [高, -高 - 8.0, 箭头.position.y])
		_check(String(箭头.get("entry_name")) == "MobSelected_Effect_Skin",
				"选中箭头应播 MobSelected_Effect_Skin，实际「%s」" % String(箭头.get("entry_name")))
		_check(not 箭头.visible, "没选中时箭头不该可见")
		箭头.visible = true
		var 标记 := 谁.get_node_or_null("QuestMarker") as Node2D
		if 标记 != null:
			_check(absf(float(标记.position.y) - float(箭头.position.y) - 3.0) < 0.01,
					"两档挂点应差 3px（-5 与 -8），实际差 %.2f" % (float(标记.position.y) - float(箭头.position.y)))
		return

func _finish() -> void:
	if _failures.is_empty():
		print("任务标记位置回归测试：通过（%d 条断言）" % _checked)
		quit(0)
		return
	for failure in _failures:
		if not failure.is_empty():
			printerr(failure)
	quit(1)
