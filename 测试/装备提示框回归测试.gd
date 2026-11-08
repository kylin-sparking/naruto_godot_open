extends SceneTree

## 「装备提示框」里**附加属性 / 精炼追加**那一段的回归。
##
## 为什么单独一条：那一段是**四条分支**（上限表里有没有这一条 × 到没到顶 × 有没有精炼追加），
## 光看截图只能看出"渲染出来了"，看不出"走对了哪条"。这里把四条**各钉一条**。
##
## 真值出处：`MToolTipZhuangBei.as:434-582`；上限表 = `StringTool.getPlusPositionConfig`
## → `EquipSystem.plus.stage<N>[<部位类型名>]`（客户端读法见 `装备打造表.取附加属性上限`）。
##
## 用长太刀 01010023 举例：它 stage=2 / type_name=EquipA，
## 而 `plus.stage2.EquipA` = `atk→18 / bsk→11 / maxmp→41`。
##
## 运行：Godot --headless --path . --script res://测试/装备提示框回归测试.gd

const 提示框场景 := preload("res://场景/界面/组件/装备提示框.tscn")

var _失败: Array[String] = []
var _文 := ""


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 框 := 提示框场景.instantiate() as Control
	root.add_child(框)
	# `@onready` 要等一帧才就绪（工具 截装备提示框.gd 也是等几帧再 `设置`）。
	await process_frame
	await process_frame

	var 实例 := {
		"aptitude": 4, "forge_additive_ratio": 3,
		"strengthen": 11, "strength_value": 423, "strength_info": [true],
		"base_attr_type": 4, "base_attr_value": 116,
		"endure": 180, "max_endure": 180, "crash_time": 0,
		"tale_attr_type": -1, "tale_attr_value": 0,
		"plus_attributes": [
			{"attribute_type": 4, "attribute_value": 18},    # atk = 上限 18 → 到顶
			{"attribute_type": 6, "attribute_value": 5},     # bsk 5 < 上限 11 → 没到顶
			{"attribute_type": 7, "attribute_value": 12},    # avd **不在**上限表里
			{"attribute_type": 25, "attribute_value": 8},    # 经验加成 → 单独一段
		],
	}
	框.call("设置", "01010023", 100, 300, 实例)
	_文 = (框.get_node("明细") as RichTextLabel).text

	# —— 抬头：有精炼比例时带【精炼额外追加N% * 5】——
	_查(文含("【精炼额外追加3% * 5】"), "抬头应带【精炼额外追加3% * 5】")
	_查(文含("附加属性"), "抬头应还是「附加属性」")

	# ⚠️ 2026-10-01：基本属性段改成原版行式（`MToolTipZhuangBei.as:405-433`）后，
	# 名字行 `　攻击　+116`（带全角空格与加号）与附加属性行**同前缀**，
	# 抽取必须带上数值才不撞（当年那条"只写攻击会先撞基本属性行"的注释说的就是这事）。
	_查(文含("基本属性"), "基础值>0 ⇒ 有「基本属性」抬头（天生=0 ⇒ 不带百分比）")
	_查(行含("　攻击　+116").contains("116"), "基础名行照原版 `　名　+值`（白字）")

	# —— 到顶那条：追 + 【梦幻满值】——
	#    追加 = ceil(值 × 比例 × 5 / 100) = ceil(18 × 3 × 5 / 100) = ceil(2.7) = 3
	var 攻 := 行含("　攻击　+18")
	_查(攻.contains("追+3"), "攻击(18=上限) 应带「追+3」，实际「%s」" % 攻)
	_查(攻.contains("【梦幻满值】"), "攻击(18=上限) 应带【梦幻满值】，实际「%s」" % 攻)

	# —— 没到顶那条：追 + 最大可提升至+上限 ——
	#    追加 = ceil(5 × 3 × 5 / 100) = ceil(0.75) = 1
	var 暴 := 行含("　暴击　+")
	_查(暴.contains("追+1"), "暴击(5<11) 应带「追+1」，实际「%s」" % 暴)
	_查(暴.contains("最大可提升至+11"), "暴击(5<11) 应带「最大可提升至+11」，实际「%s」" % 暴)

	# —— **不在上限表里**那条：只印属性本身，**连追都不带** ——
	#    这是原版 `matched == false` 那条路（`:524-532`），最容易被我"顺手加上追"改坏。
	var 闪 := 行含("　闪避　+")
	_查(not 闪.contains("追+"), "闪避(avd 不在上限表) **不该**带「追+」，实际「%s」" % 闪)
	_查(not 闪.contains("梦幻满值") and not 闪.contains("最大可提升"),
		"闪避(avd 不在上限表) 不该带上限文案，实际「%s」" % 闪)

	# —— 经验加成单独成段（原版 `:555-563`，不参与上面四条分支）——
	_查(文含("经验加成"), "应有一段「经验加成」")
	_查(行含("　经验加成　+").contains("+8%"), "经验加成那行应是 +8%%，实际「%s」" % 行含("　经验加成　+"))

	# —— 镶嵌属性段（2026-10-02 用户报"镶嵌后提示框里没有宝石信息"）——
	# 真值 `MTTipZhuangBei.as:1686-1729 createInlaySprite`：抬头「镶嵌属性」+ 每颗宝石一行
	# （22x22 图标贴 x=0、文字 x=20、行高 18，行文 = 「名（N级）属性+值」）。
	# 这段不在 `明细` 里（是 `明细/镶嵌块` 下的子 Label），所以读子节点而不是 `_文`。
	var 实例2 := {
		"aptitude": 4,
		"inlays": [
			{"stone_id": 13000005, "stone_level": 1, "attribute_type": 8, "skill_id": 0, "attribute_value": 3},
			{"stone_id": 13000000, "stone_level": 1, "attribute_type": 7, "skill_id": 0, "attribute_value": 3},
		],
	}
	框.call("设置", "01010023", 100, 300, 实例2)
	var 块 := 框.get_node_or_null("镶嵌块") as Control
	_查(块 != null, "镶嵌块应在**提示框根**下（不是 `明细` 里）")
	# ⚠️⚠️ 这条是用户 2026-10-02 报"镶嵌后没宝石信息"的**真因**所在：
	#   `_明细` 是 RichTextLabel、`clip_contents=true`，镶嵌块若挂它底下、又在它矩形之外，
	#   **整段被裁掉、永远看不见**。旧断言只数子节点文本、看不到"裁没裁"，所以没拦住。
	#   这里直接钉**父节点**：必须是提示框根（根不裁，段才画得出来）。
	if 块 != null:
		_查(块.get_parent() == 框,
				"镶嵌块的父节点该是提示框根（`_明细` 是 RTL、会裁剪矩形外的子节点）实际父=%s"
				% (块.get_parent().name if 块.get_parent() else "无"))
	if 块 != null:
		var 文本: Array[String] = []
		for 子 in 块.get_children():
			if 子 is Label:
				文本.append((子 as Label).text)
		_查(文本.has("镶嵌属性"), "镶嵌段抬头该是「镶嵌属性」，实际 %s" % [文本])
		var 有攻速 := false
		var 有闪避 := false
		for t in 文本:
			if t.contains("攻击速度+3"): 有攻速 = true
			if t.contains("闪避+3"): 有闪避 = true
		_查(有攻速, "宝石行该带「…攻击速度+3」（attr 8），实际 %s" % [文本])
		_查(有闪避, "宝石行该带「…闪避+3」（attr 7），实际 %s" % [文本])
		# ⭐ 宝石图标几何：**必须 22×22**（原版 `createInlaySprite` `width=height=22`）。
		# 用户 2026-10-02 报"位置不对"的真因：图标先设贴图后设 size，expand 还是 KEEP_SIZE、
		# 最小尺寸被贴图(34)顶住 → size 被夹回 34，大图标叠在一起。门必须量**实际 size**。
		var 图标22 := 0
		for 子 in 块.get_children():
			if 子 is TextureRect and (子 as TextureRect).texture != null:
				if int((子 as TextureRect).size.x) == 22 and int((子 as TextureRect).size.y) == 22:
					图标22 += 1
		_查(图标22 == 2, "两颗宝石的图标都该是 22×22（不是贴图原尺寸 34），实际命中 %d" % 图标22)
	# —— 玉链那一支：勾玉行是「忍术名 +N层」，**不是** `属性名(-1)` ——
	# 原版 `MTToolTipZhuangBei.createInlaySprite:1709-1711`：`isItemAYuLian`（EquipS1 / 四位码 120）时
	#   `宝石名 + getSkillString(skillId) + "+" + attrValue + "层"`（`MTOOL_TIPITEM_CENG:648`）。
	# 勾玉条目的 `attribute_type` 恒为 **-1**、真加成写在 `skill_id` 上（用户档实测 `[13101102, 3, -1, 3007, 3]`）。
	# ⚠️ 2026-11-01 用户报「玉链镶嵌的勾玉，在装备详情框没有正确显示其勾玉属性」—— 修前这里是
	#   「火之勾玉属性-1+3」（`属性名` 表里没有 -1）。
	var 实例玉 := {
		"aptitude": 4,
		"inlays": [
			{"stone_id": 13101102, "stone_level": 3, "attribute_type": -1, "skill_id": 3007, "attribute_value": 3},
		],
	}
	框.call("设置", "01200060", 100, 300, 实例玉)
	var 块玉 := 框.get_node_or_null("镶嵌块") as Control
	var 文玉: Array[String] = []
	if 块玉 != null:
		for 子 in 块玉.get_children():
			if 子 is Label:
				文玉.append((子 as Label).text)
	_查(文玉.any(func(话: String) -> bool: return 话.ends_with("瞬身+3层")),
			"玉链里的勾玉行该是「…瞬身+3层」（`createInlaySprite:1711`），实际 %s" % [文玉])
	_查(not 文玉.any(func(话: String) -> bool: return 话.contains("属性-1")),
			"勾玉行**不许**退化成 `getBaseAttrName(-1)`（`attribute_type` 是 -1），实际 %s" % [文玉])
	# 没镶嵌 → 不该出这段（原版 `inlays` 空就不建）
	框.call("设置", "01010023", 100, 300, {"aptitude": 4})
	var 块空 := 框.get_node_or_null("镶嵌块") as Control
	_查(块空 != null and 块空.get_child_count() == 0, "无镶嵌时镶嵌块该是空的（不画抬头）")

	# —— 特性属性段（`MTToolTipZhuangBei.as:589-621`，2026-10-14 §3.160 实装）——
	#   条件 = **这件本身是变身卡**（`itemId / 10000 == 121 或 205`）且有特性：
	#   `:590` 那串 `(param2 || !SysCfg.splitEquipExtraTooltip || isTransformCard)` 里，
	#   开关默认 true、`param2` 又等于"这一对里有变身卡"（`createEqpTip:1539`）
	#   ⇒ 单件悬浮就只剩 `isTransformCard` 这一支（**别以为非变身卡也该出**）。
	var 变身卡 := {
		"aptitude": 4,
		"special_attributes": [
			{"attribute_type": 4, "attribute_value": 30},    # 序号 0 → 带 %
			{"attribute_type": 5, "attribute_value": 40},
			{"attribute_type": 6, "attribute_value": 50},
			{"attribute_type": 7, "attribute_value": 60},    # 序号 3 → 仍带 %（变身卡那支是 `< 4`）
			{"attribute_type": 8, "attribute_value": 70},    # 序号 4 → **不带 %**
		],
		"special_effect_type": 2, "afterimage_flag": 1,
	}
	框.call("设置", "01210252", 100, 300, 变身卡)
	_文 = (框.get_node("明细") as RichTextLabel).text
	_查(文含("特性属性 ⚡"), "变身卡该出「特性属性 ⚡」抬头（`:590`）")
	_查(行含("　攻击　+30").contains("+30%"), "特性第 1 条该带 %%，实际「%s」" % 行含("　攻击　+30"))
	_查(行含("　闪避　+60").contains("+60%"), "特性第 4 条（序号 3）仍该带 %%（变身卡支 `< 4`），实际「%s」" % 行含("　闪避　+60"))
	_查(not 行含("　攻击速度　+70").contains("%"), "特性第 5 条（序号 4）**不该**带 %%，实际「%s」" % 行含("　攻击速度　+70"))
	_查(文含("守鹤の力：攻击时2%概率获得特殊buff，提升10%防御，持续5秒"),
		"specialEffectType=2 ⇒ 守鹤の力那句（**与互换窗那份文案不同**，`:610-619` 逐字）")
	_查(文含("残影显现!(特殊效果)"), "afterimageFlag>0 ⇒ 残影那行")
	# 非变身卡（长太刀 101 段）即便有特性也**不出**这一段（默认开关那支）
	框.call("设置", "01010023", 100, 300, {"aptitude": 4, "special_attributes":
		[{"attribute_type": 4, "attribute_value": 30}], "special_effect_type": 1})
	_查(not (框.get_node("明细") as RichTextLabel).text.contains("特性属性"),
		"非变身卡带特性也**不该**出特性段（`splitEquipExtraTooltip` 默认 true 那支）")
	# 变身卡但没特性 → 也不出
	框.call("设置", "01210252", 100, 300, {"aptitude": 4})
	_查(not (框.get_node("明细") as RichTextLabel).text.contains("特性属性"), "变身卡没特性 ⇒ 不出特性段")
	_文 = (框.get_node("明细") as RichTextLabel).text

	# —— 段的**次序**（2026-10-02 用户报"镶嵌跑到秘印下面"）——
	# 真值 `对比图/顶级装备.png` + `MTipZhuangBei.as`：附加 → **传说** → **镶嵌** → 分隔线 → 绑定 →
	# **秘印在最后**（`:889+`）。钉：镶嵌.y < 绑定.y < 秘印容器.y。
	框.call("设置", "01010023", 100, 300, {
		"aptitude": 4, "tale_attr_type": 4, "tale_attr_value": 100,
		"carve_id": 1, "carve_type": 11, "carve_value": 5,
		"inlays": [{"stone_id": 13000005, "stone_level": 6, "attribute_type": 4, "skill_id": 0, "attribute_value": 96}],
	})
	await process_frame
	var 块3 := 框.get_node_or_null("镶嵌块") as Control
	var 绑 := 框.get_node_or_null("绑定") as Control
	var 秘 := 框.get_node_or_null("稀有明细") as Control
	var 传 := 框.get_node_or_null("传说段") as Control
	if 块3 == null or 绑 == null or 秘 == null:
		_查(false, "次序段前置：镶嵌块/绑定/稀有明细 缺 %s" % [块3 == null or 绑 == null or 秘 == null])
	else:
		_查(传 != null and 传.position.y < 块3.position.y, "传说属性该在镶嵌**之上**")
		_查(块3.position.y < 绑.position.y, "镶嵌属性该在**绑定行之上**（原版 :760 < :787）")
		_查(绑.position.y < 秘.position.y, "秘印段该在**绑定行之下（最底）**（原版 :889+；用户报的正是这条）")

	# —— 灵器（十拳剑一族，2026-10-20 用户报「十拳剑没有属性值」）——
	# ⚠️ 真因：灵器的**基础属性不走 wire**（服务端 `_encode_item_payload` 的 LING_QI 支只发
	#   `common_fields + plus_attributes`），原版从 GameData 的 `LingQi.<id>.info.baseAttr` 读。
	#   我们那份静态表在 `数据/物品装备元数据.json` 的 `灵器` 段（`开发工具/导出装备元数据.py` 生成）。
	# 版式照 `MToolTipLingQiTip.as`：基本信息两行（没有阶数）、明细 = 耐久(永不磨损) →
	#   基本属性逐条 → 附加属性（到顶带【梦幻满值】/没到顶带最大可提升）→ 特殊属性。
	框.call("设置", "20100001", 100, 300, {})
	_文 = (框.get_node("明细") as RichTextLabel).text
	_查((框.get_node("信息") as Label).text.contains("佩戴部位　灵器"), "灵器基本信息第一行应是「佩戴部位　灵器」")
	_查(not (框.get_node("信息") as Label).text.contains("阶"), "灵器**不该**再印「装备阶数」那行")
	_查(文含("基本属性"), "灵器该有「基本属性」段（`baseAttr`）")
	_查(文含("　攻击　+5000"), "灵器基础第一条应是 攻击+5000，实际「%s」" % 行含("　攻击　+5000"))
	_查(文含("　生命值上限　+50000"), "灵器基础第二条应是 生命值上限+50000，实际「%s」" % 行含("　生命值上限"))
	_查(文含("永不磨损"), "灵器耐久行应是「永不磨损」")
	_查(not 文含("强化"), "灵器没有强化段（`MToolTipLingQiTip` 不画强化行）")
	# 开光后的 20200001：基础更高 + 附加属性到顶 + 三条特殊属性
	框.call("设置", "20200001", 100, 300, {
		"plus_attributes": [{"attribute_type": 4, "attribute_value": 600}],
	})
	_文 = (框.get_node("明细") as RichTextLabel).text
	_查(文含("　攻击　+6500"), "20200001 基础攻击应 +6500，实际「%s」" % 行含("　攻击　+6500"))
	_查(文含("附加属性(满附加)"), "附加属性到顶（600=上限）抬头应是「附加属性(满附加)」")
	_查(行含("　攻击　+600").contains("【梦幻满值】"), "到顶那条该带【梦幻满值】，实际「%s」" % 行含("　攻击　+600"))
	_查(文含("职业忍术等级　+2"), "特殊属性应有「职业忍术等级　+2」")
	_查(文含("世界忍术等级　+2"), "特殊属性应有「世界忍术等级　+2」")
	_查(文含("抵抗封印的几率 +1%"), "特殊属性应有解印那条（ANTI_SEAL_PET:1）")

	# —— 忍具（八咫镜 65000001/65000002，2026-10-31 §3.332 用户报「八咫镜没有属性」）——
	# 真值 `MToolTipRenJuTip.as:43-253`：标题**恒粉**（这一段根本不读 aptitude）、
	# 基本信息三行（佩戴部位忍具 / 使用等级 / 适用职业，没有阶数）、
	# 明细 = 耐久(永不磨损,白) → 基本属性(橙抬头+白值) → 附加属性(橙抬头+紫值)
	#       → 特殊属性(橙抬头+白值，2026-11-01 用户要求与灵器同段序) → 绑定(居中)；
	# **没有**强化/星排/镶嵌/秘印/传说/价格/过期。静态数据在 `数据/忍具.json` 的 `info`。
	框.call("设置", "65000001", 100, 300, {})
	await process_frame
	_文 = (框.get_node("明细") as RichTextLabel).text
	var 忍标题 := 框.get_node("标题") as Label
	var 忍信息 := 框.get_node("信息") as Label
	var 忍职业 := 框.get_node("职业行") as Label
	var 忍说明 := 框.get_node_or_null("忍具说明") as RichTextLabel
	var 忍绑定 := 框.get_node("绑定") as Label
	_查(忍标题.text == "八咫镜", "忍具标题该是「八咫镜」，实际「%s」" % 忍标题.text)
	_查(忍标题.get_theme_color("font_color").to_html(false) == "ff5498",
		"忍具标题恒粉（`UIConfig.UI_PINK`），实际 #%s"
		% 忍标题.get_theme_color("font_color").to_html(false))
	_查(忍信息.text == "佩戴部位　忍具\n使用等级　80级",
		"忍具基本信息该是「佩戴部位　忍具／使用等级　80级」，实际「%s」" % 忍信息.text.replace("\n", "\\n"))
	_查(忍职业.text == "适用职业　任何职业", "reqJob=0 ⇒ 职业行「适用职业　任何职业」，实际「%s」" % 忍职业.text)
	_查(忍职业.get_theme_color("font_color").to_html(false) == "ffffff",
		"职业行符合时该是白字（红字只给不符），实际 #%s"
		% 忍职业.get_theme_color("font_color").to_html(false))
	_查(文含("耐久度　永不磨损"), "忍具明细则第一行该是「耐久度　永不磨损」")
	_查(not 行含("耐久度").contains("[color="), "耐久行该是白字（与灵器同一口径，2026-11-01 用户点名）")
	_查(文含("基本属性"), "忍具该有「基本属性」段（`baseAttr`）")
	for 条 in [["攻击", 3666], ["防御", 3666], ["暴击", 500], ["闪避", 3666],
			["生命值上限", 20000], ["查克拉上限", 20000]]:
		_查(文含("%s　+%d" % [条[0], int(条[1])]),
			"忍具基础该有「%s　+%d」，实际「%s」" % [条[0], int(条[1]), 行含("　+%d" % int(条[1]))])
	_查(not 文含("强化"), "忍具没有强化段（`MToolTipRenJuTip` 不画）")
	_查(not (框.get_node("镶嵌块") as Control).visible, "忍具不该露出镶嵌块（上一件装备的宝石行）")
	_查(not (框.get_node("价格") as Control).visible, "忍具不显示价格")
	_查(not (框.get_node("稀有明细") as Control).visible, "忍具不显示秘印/稀有段")
	_查(忍说明 != null and 忍说明.visible, "描述非空 ⇒ 「忍具说明」该显示")
	_查(忍说明 != null and 忍说明.text.contains("源自上古三神器的灵镜"),
		"「忍具说明」该带 `RenJu` 那段 desc")
	_查(忍说明 != null and not 忍说明.text.contains("特殊属性"),
		"65000001 没有 specialAttr ⇒ 不该有「特殊属性」抬头")
	_查(not 文含("特殊属性"), "65000001 没有 specialAttr ⇒ 明细里也不该有「特殊属性」抬头")
	_查(忍绑定.text == "[未绑定]", "可交易（can_trade 缺省真）⇒ 绑定行「[未绑定]」，实际「%s」" % 忍绑定.text)
	_查(忍绑定.visible, "忍具绑定行恒显示")
	_查(int(忍绑定.horizontal_alignment) == int(HORIZONTAL_ALIGNMENT_CENTER), "忍具绑定行居中（不用左对齐那支）")
	_查(忍绑定.get_theme_color("font_color").to_html(false) == "8ea8d8",
		"忍具绑定行色 #8ea8d8，实际 #%s" % 忍绑定.get_theme_color("font_color").to_html(false))
	_查((框.get_node("图标框") as Control).position.x == 170.0,
		"图标框该摆 x=170（`:88-93`），实际 %s" % str((框.get_node("图标框") as Control).position.x))

	# 附加属性：上限 = `addAttr.split(":")[1]` = 200 ⇒ 到顶带【梦幻满值】、没到顶带最大可提升至+200
	框.call("设置", "65000001", 100, 300, {
		"plus_attributes": [
			{"attribute_type": 4, "attribute_value": 200},
			{"attribute_type": 5, "attribute_value": 100},
		],
	})
	_文 = (框.get_node("明细") as RichTextLabel).text
	_查(文含("附加属性(满附加)"), "附加第一条到顶（200=上限）⇒ 抬头「附加属性(满附加)」")
	_查(行含("攻击　+200").contains("【梦幻满值】"), "到顶那条带【梦幻满值】，实际「%s」" % 行含("攻击　+200"))
	_查(行含("防御　+100").contains("最大可提升至+200"),
		"没到顶那条带「        最大可提升至+200」，实际「%s」" % 行含("防御　+100"))
	var 附加序 := _文.find("附加属性(满附加)")
	_查(附加序 >= 0 and _文.substr(附加序).contains("[color=#ba01f9] 攻击　+200"),
		"附加属性值是紫字（UI_ZHI_SE = #ba01f9，整块套色）")

	# 开光后的 65000002：desc + 特殊属性两行（`SEAL_PET` 不在原版 switch 里 ⇒ 不出解印）。
	# 2026-11-01 用户口径：特殊属性挪进明细、排在基本属性之后（没有附加属性时紧接基本属性），
	# 抬头橙色、值白字；描述块只留 desc。
	框.call("设置", "65000002", 100, 300, {})
	await process_frame
	忍说明 = 框.get_node_or_null("忍具说明") as RichTextLabel
	_文 = (框.get_node("明细") as RichTextLabel).text
	_查(文含("攻击　+6666"), "65000002 基础攻击该 +6666（开光后那份 baseAttr）")
	_查(忍说明 != null and not 忍说明.text.contains("特殊属性"),
		"特殊属性不再嵌在描述块里（用户要求与灵器同段序）")
	_查(文含("[color=#ff9a16]特殊属性[/color]"), "65000002 有 specialAttr ⇒ 明细末尾该出「特殊属性」抬头（橙）")
	_查(行含("　职业忍术等级　+3") != "" and not 行含("　职业忍术等级　+3").contains("[color="),
		"特殊属性应有白字「　职业忍术等级　+3」，实际「%s」" % 行含("　职业忍术等级　+3"))
	_查(行含("　世界忍术等级　+3") != "" and not 行含("　世界忍术等级　+3").contains("[color="),
		"特殊属性应有白字「　世界忍术等级　+3」，实际「%s」" % 行含("　世界忍术等级　+3"))
	_查(not 文含("【解印】"),
		"数据里是 `SEAL_PET`，不在原版 switch（只认 ANTI_SEAL_PET_SHOW）⇒ **不该**印解印行")
	_查(not 文含("附加属性"), "65000002 没有附加词条 ⇒ 段序就是「基本属性 → 特殊属性」，不许出附加抬头")
	_查(_文.find("基本属性") < _文.find("特殊属性"),
		"特殊属性该排在基本属性**之后**（十拳剑同序），实际序号 %d vs %d"
		% [_文.find("基本属性"), _文.find("特殊属性")])

	# 有附加词条时：基本 → 附加 → 特殊（与十拳剑完全同序）
	框.call("设置", "65000002", 100, 300, {
		"plus_attributes": [{"attribute_type": 4, "attribute_value": 200}],
	})
	_文 = (框.get_node("明细") as RichTextLabel).text
	_查(_文.find("基本属性") < _文.find("附加属性") and _文.find("附加属性") < _文.find("特殊属性"),
		"有附加属性时该是「基本属性 → 附加属性 → 特殊属性」，实际序号 %d/%d/%d"
		% [_文.find("基本属性"), _文.find("附加属性"), _文.find("特殊属性")])

	# —— 玉链按阶戴品质（2026-10-31 用户点名：45/50 白、55 绿、60 蓝、65 紫、70 橙）——
	# 服务端给的 aptitude 不表达品质（夹具/默认值就是 2），标题与附加属性行也必须按阶取色，
	# 否则「框紫、名字绿」自相矛盾。映射见 `装备品质.玉链资质`（阶=id 十位、档=clamp(阶-1,1,5)）。
	for 条 in [["01200010", "ffffff", "白"], ["01200020", "ffffff", "白"],
			["01200030", "08ff19", "绿"], ["01200040", "009cff", "蓝"],
			["01200050", "ba01f9", "紫"], ["01200060", "fff000", "橙"]]:
		框.call("设置", String(条[0]), 100, 300, {
			"aptitude": 2,
			# ⚠️ 附加词条值取 127，**刻意避开**各阶的基础攻击（10/20/30/40/50/60）——
			#    60 会先撞上阶6 的「基本属性　攻击　+60」（这个文件头注释里记过同样的坑）。
			"plus_attributes": [{"attribute_type": 4, "attribute_value": 127}],
		})
		await process_frame
		var 链标题 := 框.get_node("标题") as Label
		_查(链标题.get_theme_color("font_color").to_html(false) == String(条[1]),
			"玉链 %s（%s档）标题该 #%s（只认阶，不认下发的 aptitude=2），实际 #%s"
			% [条[0], String(条[2]), String(条[1]), 链标题.get_theme_color("font_color").to_html(false)])
		_文 = (框.get_node("明细") as RichTextLabel).text
		_查(行含("　攻击　+127").contains("[color=#%s]" % String(条[1])),
			"玉链 %s（%s档）附加属性行该 #%s，实际「%s」"
			% [条[0], String(条[2]), String(条[1]), 行含("　攻击　+127")])

	# 绑定极性：can_trade=false ⇒ 「[已绑定]」（`canTrade ? 未绑定 : 已绑定`）
	框.call("设置", "65000001", 100, 300, {"can_trade": false})
	_查((框.get_node("绑定") as Label).text == "[已绑定]", "can_trade=false ⇒ 「[已绑定]」")

	# 串台：忍具之后紧接一件普通装备 —— 忍具说明/分隔二 必须收起（镶嵌块回到装备那套里）
	框.call("设置", "01010023", 100, 300, {})
	await process_frame
	_查((框.get_node_or_null("忍具说明") as CanvasItem) != null
		and not (框.get_node_or_null("忍具说明") as CanvasItem).visible,
		"回到装备 ⇒ 「忍具说明」必须收起来")
	_查((框.get_node_or_null("忍具分隔二") as CanvasItem) != null
		and not (框.get_node_or_null("忍具分隔二") as CanvasItem).visible,
		"回到装备 ⇒ 忍具第二条分隔线必须收起来")
	_查((框.get_node("镶嵌块") as Control).visible, "回到装备 ⇒ 镶嵌块恢复显示（否则宝石行永远不出现）")

	if _失败.is_empty():
		print("装备提示框回归测试：通过（精炼抬头 / 到顶 / 没到顶 / 不在上限表 / 镶嵌属性段 / 特性属性段 / 灵器静态属性 / 忍具版式+绑定极性 / 玉链按阶取色 各钉）")
		quit(0)
	else:
		for 项 in _失败:
			push_error("装备提示框回归测试：失败 - %s" % 项)
		quit(1)


func 文含(子串: String) -> bool:
	return _文.contains(子串)


## 明细里那一行（BBCode 原样，含 `[color=…]` 标签）。
## ⚠️ 关键词要用 `"　属性名　+"` 这种**带全角空格和加号**的写法 ——
## 只写"攻击"会先撞上「基本属性」那行的 `攻击　116　强化　+423`（第一版就撞了）。
func 行含(关键词: String) -> String:
	for 行 in _文.split("\n"):
		if String(行).contains(关键词):
			return String(行)
	return ""


func _查(条件: bool, 说明: String) -> void:
	if not 条件:
		_失败.append(说明)
