extends SceneTree

## 「装备打造」左栏的**放入态**（原版 `_itemData`）+ 专属页图标重叠 + 整窗可拖。
## 2026-10-01 用户四条反馈里的 ②③④ 落在这道门上（① 在 `装备穿卸离线回归测试`）。
##
## 钉的四件事（都有 AS3 出处）：
##   A. **开窗时左栏是空的**（`EquipStrengthWindow.as:166/181` `_itemData = null`），
##      「放入装备」点了才放进（我们没光标拾取，空态点击 = 取下一件候选，候选集与右栏列表同）；
##      「取出装备」点了是**清空**（`clickDropBtnHandler:488-492 → backItemToEquip`），
##      不是"换下一件" —— 按钮写着什么、点了就该发生什么。
##   B. **专属页（除强化/天生）必须藏掉共用左栏的装备格**
##      （原版藏的是整个 `_contentBox`，`:659/723/739`；以前逐件藏漏了「装备格」，
##      两枚放入装备图标**错位 8px 同屏重叠** —— 用户报"除强化外都有重叠"）。
##   C. 部位列表里**背包那行**点了要真能放进（以前 `_会话选中` 只读 equipped_items，
##      背包行点了没反应），而且"已装备"标签**只能挂在身上那行**——
##      同 id 的背包件以前也被标成"已装备"（`putOn` 是装配时就知道的，不是 id 反查）。
##   D. 打造窗/活跃度窗（"原点":[0,0] 铺满外框的页）**页面根与外框必须 IGNORE**，
##      否则标题栏那 29px 的点击被页面吞掉，`功能窗口` 的 `拖动区` 收不到 ⇒ 整窗拖不动
##      （能拖的背包页根节点就是 mouse_filter=2）。
##
## 本门只动会话的内存数组（不点打造/穿卸按钮），开场**内存 + 按字节文件**两层快照、收尾原样放回。
## ⚠️ C 段的前置是 `equipped_items.clear()` 后**只挂武器**：以前只覆写武器位、留着档里其余件，
##    于是"身上那件被别人写了档"就多出第 3 行 ⇒ 判据建在存档上（§3.242 就是这么被脏到的）。
##
## 运行：Godot --headless --path . --script res://测试/装备打造放入回归测试.gd

const 门存档快照 := preload("res://测试/门存档快照.gd")

var _失败: Array[String] = []
var _受检 := 0
var _快照: Dictionary = {}
var _文件前: Dictionary = {}


## 只为 H 段钉「购买」那一包：`功能窗口.请求商城商品` 走的就是后端的 `request_cash_item_info`
## （原版共用材料格 `ItemCaiLiaoBox.buyHandler:46-55` 的 `REQUEST_CASH_ITEM_INFO`）。
class 假后端 extends Node:
	var 收到: Array = []

	func request_cash_item_info(物品id: int) -> bool:
		收到.append(物品id)
		return true

	func request_cash_money() -> bool:
		return true

func _initialize() -> void:
	call_deferred("_run")

func _查(ok: bool, 话: String) -> void:
	_受检 += 1
	if not ok:
		_失败.append(话)

func _武器位() -> int:
	return int(load("res://脚本/单例/装备部位.gd").武器)

func _造件(物品id: String, 格: int, 追加: Dictionary = {}) -> Dictionary:
	var 件 := {"id": 物品id, "name": "测试武器", "quantity": 1, "slot_index": 格,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"}
	件.merge(追加, true)
	return 件

## 一件「有内容」的装备实例（J 段用）：提示框只有拿到这些字段才画得出真身
## （`装备提示框._拼明细` 读 endure/max_endure、strengthen、strength_value、born_attr_value、
## base_attr_* 与 plus_attributes）。只喂 `{id, quantity}` 时就退回物品模板白板。
func _实例字段(强化: int) -> Dictionary:
	return {"strengthen": 强化, "strength_value": 77, "born_attr_value": 5,
			"base_attr_type": 1, "base_attr_value": 40, "endure": 50, "max_endure": 100,
			"plus_attributes": [{"type": 1, "value": 9}, {"type": 2, "value": 8},
				{"type": 3, "value": 7}],
			"aptitude": 3, "stage": 1}

func _run() -> void:
	_文件前 = 门存档快照.全快照()
	var 会话 := root.get_node("/root/GameSession")
	_快照 = {
		"inventory": (会话.inventory as Array).duplicate(true),
		"equipped_items": (会话.equipped_items as Dictionary).duplicate(true),
		# 进阶门槛那条腿要临时换职业组（见 E2），收尾原样放回。
		"job": int(会话.player_stats.get("job", 0)),
	}
	# 身上穿着 01010011、背包里放着**同一件 id** 的 01010011（C 里"错标已装备"要的就是同 id）
	# ⚠ 先**清空**再挂：C 数的是行数，档里多一件护腰就多一行 ⇒ 判据不许建在存档上。
	会话.equipped_items.clear()
	会话.equipped_items[_武器位()] = _造件("01010011", -1)
	会话.inventory.clear()
	会话.inventory.append(_造件("01010011", 40))

	var 场景 := (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	for _i in 5:
		await process_frame
	场景.call("open_page", "装备强化")
	for _i in 5:
		await process_frame

	# —— A：开窗 = 没放 ——
	var 页 := _打造页(场景)
	if 页 == null:
		_停("打造页没建出来")
		return
	_查(bool(场景.get("_强化放入中")) == false, "A：开窗时左栏应为**没放**（原版 _itemData=null）")
	_查((页.get_node("内容容器/装备格/装备图标") as TextureRect).texture == null, "A：没放时共用装备格不该有图标")
	_查((页.get_node("内容容器/放入装备") as Button).text == "放入装备", "A：没放时按钮该写「放入装备」")
	_查((页.get_node("开始强化") as Button).disabled, "A：没放时「开始强化」该禁用")

	# —— C：两行；"已装备"只挂身上那行 ——
	var 列表 := 页.get_node("列表内容") as Control
	_查(列表.get_child_count() == 2, "C：部位列表应有 2 行（身上+背包同 id），实际 %d" % 列表.get_child_count())
	if 列表.get_child_count() >= 2:
		var 行0 := 列表.get_child(0)
		var 行1 := 列表.get_child(1)
		_查(_行标签(行0) == "已装备", "C：身上那行的「已装备」该显示")
		_查(_行标签(行1) == "", "C：**背包里同 id 的那行不该标「已装备」**（旧代码拿 id 反查会错标）")
		# 点背包行 ⇒ 放进左栏（来源=背包、按格+id 认件）
		_按下钮(行1).pressed.emit()
		await process_frame
		await process_frame
		页 = _打造页(场景)
		_查(String(场景.get("_强化放入来源")) == "背包", "C：背包行点了来源该是背包")
		_查((页.get_node("内容容器/装备格/装备图标") as TextureRect).texture != null,
				"C：放进后共用装备格要有图标（旧代码点了背包行**没反应**）")
		_查((页.get_node("内容容器/放入装备") as Button).text == "取出装备", "C：放进后按钮该翻成「取出装备」")

	# —— B：切「刻印」（专属页）：共用装备格必须藏、面板自己那格要带着图标 ——
	# ⚠️ 切页签本身**会清空放入态**（原版 `selectedBtnHandler:741` 先 `backItemToEquip()`），
	#    所以这里先钉"切页=清"，再在刻印页里重新放进一件。
	# ⚠️ 刻印页白色件**放不进**（`EquipKeYinPanel.validateItem:128-171`）——先把背包件升紫，
	#    白色拒放留到下面单独一条腿（2026-11-08 补的门槛）。
	for 物 in 会话.inventory:
		(物 as Dictionary)["aptitude"] = 4
	场景.call("_set_strengthen_tab", 5)
	for _i in 3:
		await process_frame
	页 = _打造页(场景)
	_查(bool(场景.get("_强化放入中")) == false, "B2：切页签必须清空放入态（原版 backItemToEquip 那句）")
	_查(not (页.get_node("内容容器/装备格") as CanvasItem).visible,
			"B：专属页必须**藏掉共用装备格**（以前漏藏 ⇒ 两枚图标错位重叠）")
	_查(not (页.get_node("内容容器/放入装备") as CanvasItem).visible, "B：专属页该连「放入装备」一起藏")
	var 刻印面板 := 页.get_node_or_null("面板容器/原版装备刻印页") as Control
	if 刻印面板 == null:
		_失败.append("B：刻印面板没建出来")
	else:
		# 清单次序：身上(0)、背包(1) —— 背包那件已升紫，放得进
		页 = await _点放入选(场景, 页, 刻印面板.get_node("放入装备") as Button, 1)
		刻印面板 = 页.get_node_or_null("面板容器/原版装备刻印页") as Control
		if 刻印面板 == null:
			_失败.append("B：放进后刻印面板重建没了")
		else:
			_查((刻印面板.get_node("装备格/装备图标") as TextureRect).texture != null,
					"B：放进的那件要显示在**面板自己的**装备格里")
			_查(String(场景.get("_强化放入来源")) == "背包", "B：刻印页放进背包件来源该是背包")

			# —— A：「取出装备」= 清空（不是换下一件）——
			(刻印面板.get_node("放入装备") as Button).pressed.emit()
			await process_frame
			await process_frame
			页 = _打造页(场景)
			刻印面板 = 页.get_node_or_null("面板容器/原版装备刻印页") as Control
			_查(bool(场景.get("_强化放入中")) == false, "A：点「取出装备」该清空放入态")
			if 刻印面板 != null:
				_查((刻印面板.get_node("放入装备") as Button).text == "放入装备", "A：取出后按钮翻回「放入装备」")
				_查((刻印面板.get_node("装备格/装备图标") as TextureRect).texture == null, "A：取出后面板那格该空")

				# —— E2：刻印白色拒放（`EQUIPLIANZHIWINDOW_WHITE_EQIP_NOT_KE_YIN`，:2963）——
				for 物 in 会话.inventory:
					(物 as Dictionary)["aptitude"] = 1
				页 = await _点放入选(场景, 页, 刻印面板.get_node("放入装备") as Button, 1)
				_查(bool(场景.get("_强化放入中")) == false, "E2：白色件在刻印页应被拒")
				var 刻印状态 := 场景.get("_status") as Label
				_查(刻印状态 != null and 刻印状态.text.contains("白色属性的装备，无法刻印秘印属性"),
						"E2：刻印白色拒句照原版（实际「%s」）" % (刻印状态.text if 刻印状态 != null else "<无>"))

				# —— F：「刻印图解」帮助窗（原版 `EquipKeYinHelpWindow`，§3.135 收口）——
				# `helpHandler:287-300`：点那枚钮弹出、**再点一次收起**；窗 = 308×406 的**纯图**
				# + 右上角关闭钮，贴面板右缘 `(_width, -58)`。
				var 图解钮 := 刻印面板.get_node("刻印图解") as Button
				图解钮.pressed.emit()
				await process_frame
				var 图解窗 := 刻印面板.get_node_or_null("刻印图解窗") as Control
				_查(图解窗 != null, "F：点「刻印图解」该弹出帮助窗")
				if 图解窗 != null:
					_查(图解窗.visible, "F：弹出后帮助窗该可见")
					_查(is_equal_approx(图解窗.position.y, -58.0), "F：窗该贴面板上方 58px（原版 y = -58）")
					var 图件 := 图解窗.get_node_or_null("图解图") as TextureRect
					_查(图件 != null and 图件.texture != null, "F：帮助窗该挂上那张图")
					if 图件 != null and 图件.texture != null:
						_查(Vector2(图件.texture.get_size()) == Vector2(308.0, 406.0),
								"F：图该是原版那块 308×406，实测 %s" % str(图件.texture.get_size()))
					var 关闭键 := 图解窗.get_node_or_null("关闭键") as Button
					_查(关闭键 != null, "F：帮助窗该有右上角关闭钮")
					if 关闭键 != null:
						关闭键.pressed.emit()
						await process_frame
						_查(not 图解窗.visible, "F：点关闭钮该收起")
					图解钮.pressed.emit()          # 原版是**开关式**，不是只能关
					await process_frame
					_查(图解窗.visible, "F：再点「刻印图解」该重新弹出")

	# —— A：空态点「放入装备」→ 在清单里选「身上那件」（行 0）——
	场景.call("_set_strengthen_tab", 0)
	for _i in 3:
		await process_frame
	页 = _打造页(场景)
	页 = await _点放入选(场景, 页, 页.get_node("内容容器/放入装备") as Button, 0)
	_查(bool(场景.get("_强化放入中")), "A：清单里选身上件后应放进")
	_查(String(场景.get("_强化放入来源")) == "", "A：放进身上件时来源该是空（按部位游标读）")
	_查((页.get_node("内容容器/装备格/装备图标") as TextureRect).texture != null, "A：放进后共用格有图标")

	# —— E：放进那一刻的页签门槛（用户 2026-10-01 原版实测：没天生的低等级件不能天生打造）——
	# 真值：天生页 `reqLevel < EQUIP_PROP_LIMIT_LEVEL(60)` ⇒ 拒放 + "60级以上的装备才能进行该操作"
	# （`EquipStrengthWindow.as:545-553`）；洗附加数值页白色先拒（`EquipPropLianZhiPanel.as:425-433`）。
	# 种子两枚都是 01010011（元数据 required_level=1）→ 天生页该被拒。
	场景.call("_set_strengthen_tab", 4)          # 天生
	for _i in 3:
		await process_frame
	页 = _打造页(场景)
	页 = await _点放入选(场景, 页, 页.get_node("内容容器/放入装备") as Button, 0)
	_查(bool(场景.get("_强化放入中")) == false, "E：低等级件在天生页应被拒、不放")
	var 状态行 := 场景.get("_status") as Label
	_查(状态行 != null and 状态行.text.contains("60级以上的装备才能进行该操作"),
			"E：提示要用原版那句（MENGHUAN_PROP_RESET_LEVEL_LIMIT，实际「%s」）" % (状态行.text if 状态行 != null else "<无>"))
	# 背包件升到 120 级 ⇒ 放得进（身上件仍 1 级：清单里选**背包**那行）
	for 物 in 会话.inventory:
		(物 as Dictionary)["req_level"] = 120
	页 = await _点放入选(场景, 页, 页.get_node("内容容器/放入装备") as Button, 1)
	_查(bool(场景.get("_强化放入中")), "E：120 级的件天生页该放得进（旧版整闸缺失）")
	_查(String(场景.get("_强化放入来源")) == "背包", "E：放进的是背包那行")
	# 天生页的执行按钮**不看强化等级**（旧版把"强化满级禁用"错罩到天生页上）。
	# 给放着的背包件挂个超上限的 strengthen=12，按钮仍须是活的。
	for 物 in 会话.inventory:
		(物 as Dictionary)["strengthen"] = 12
	页 = _打造页(场景)
	(页.get_node("内容容器/放入装备") as Button).pressed.emit()   # 取出（当前放着）
	await process_frame
	await process_frame
	页 = _打造页(场景)                                            # 取出会整页重建，旧句柄已 free
	页 = await _点放入选(场景, 页, 页.get_node("内容容器/放入装备") as Button, 1)   # 再放进来（strengthen=12 那件）
	var 格图标 := (页.get_node("内容容器/装备格/装备图标") as TextureRect).texture
	_查(bool(场景.get("_强化放入中")) and 格图标 != null
			and not (页.get_node("开始强化") as Button).disabled,
			"E：强化=12（超上限）的件在天生页按钮仍须可点（禁用只属于强化页）")
	# 切「洗附加数值」：背包件没 aptitude（=白色）⇒ 白色那句先拒
	场景.call("_set_strengthen_tab", 2)
	for _i in 3:
		await process_frame
	页 = _打造页(场景)
	var 数值面板 := 页.get_node_or_null("面板容器/原版装备洗附加属性页") as Control
	if 数值面板 == null:
		_失败.append("E：洗附加数值面板没建出来")
	else:
		页 = await _点放入选(场景, 页, 数值面板.get_node("放入装备") as Button, 1)
		_查(bool(场景.get("_强化放入中")) == false, "E：白色件在洗附加数值页应被拒")
		_查(状态行.text.contains("白色"), "E：白色拒句照原版 EQUIPLIANZHIWINDOW_WHITE_EQIP_NOT_WASH（实际「%s」）" % 状态行.text)
		for 物 in 会话.inventory:
			(物 as Dictionary)["aptitude"] = 4     # 升到紫色
		页 = _打造页(场景)
		数值面板 = 页.get_node_or_null("面板容器/原版装备洗附加属性页") as Control
		页 = await _点放入选(场景, 页, 数值面板.get_node("放入装备") as Button, 1)
		_查(bool(场景.get("_强化放入中")), "E：紫色 120 级件洗附加数值页应放得进")

	# —— E2：其余三页的放入门槛（2026-11-08 补齐的闸）——
	# 精炼（`EquipBaiLianPanel.validateItem:446-489`）：紫/橙 **且** 强化 ≥10。
	场景.call("_set_strengthen_tab", 6)
	for _i in 3:
		await process_frame
	页 = _打造页(场景)
	var 精炼面板 := 页.get_node_or_null("面板容器/原版装备精炼页") as Control
	if 精炼面板 == null:
		_失败.append("E2：精炼面板没建出来")
	else:
		for 物 in 会话.inventory:
			(物 as Dictionary)["strengthen"] = 9     # 紫但只有 9 星 ⇒ 拒
		页 = await _点放入选(场景, 页, 精炼面板.get_node("放入装备") as Button, 1)
		_查(bool(场景.get("_强化放入中")) == false, "E2：9 星紫件在精炼页应被拒")
		_查(状态行.text.contains("精炼台只能精炼紫色品质强化等级10星以上的装备"),
				"E2：精炼拒句照原版 EQUIPBAILIAN_CAB_NOT_DAZAO（实际「%s」）" % 状态行.text)
		精炼面板 = 页.get_node_or_null("面板容器/原版装备精炼页") as Control
		for 物 in 会话.inventory:
			(物 as Dictionary)["strengthen"] = 10
		页 = await _点放入选(场景, 页, 精炼面板.get_node("放入装备") as Button, 1)
		_查(bool(场景.get("_强化放入中")), "E2：10 星紫件精炼页应放得进")
	# 洗附加属性（`EquipPropResetPanel.validateItem:373-411`）：**没有白色闸**，白件也能放。
	场景.call("_set_strengthen_tab", 1)
	for _i in 3:
		await process_frame
	页 = _打造页(场景)
	var 属性面板 := 页.get_node_or_null("面板容器/原版装备洗附加属性页") as Control
	if 属性面板 == null:
		_失败.append("E2：洗附加属性面板没建出来")
	else:
		for 物 in 会话.inventory:
			(物 as Dictionary)["aptitude"] = 1
		页 = await _点放入选(场景, 页, 属性面板.get_node("放入装备") as Button, 1)
		_查(bool(场景.get("_强化放入中")), "E2：白色件洗附加属性页应放得进（这一页没有白色闸）")
	# 破损（`FAIL_PROMPT_10[0]` 填 `[2]`）：所有页共用那句。
	场景.call("_set_strengthen_tab", 0)
	for _i in 3:
		await process_frame
	页 = _打造页(场景)
	for 物 in 会话.inventory:
		(物 as Dictionary)["crash_time"] = 1
	页 = await _点放入选(场景, 页, 页.get_node("内容容器/放入装备") as Button, 1)
	_查(bool(场景.get("_强化放入中")) == false, "E2：破损件应被拒")
	_查(状态行.text.contains("对不起，该装备已经破损！"),
			"E2：破损拒句照原版（实际「%s」）" % 状态行.text)
	for 物 in 会话.inventory:
		(物 as Dictionary).erase("crash_time")
	# 进阶（`EquipConvertWindow.validateItem:220-253`）：角色装备 + **已卸到背包**
	# （`position <= 0` 是在身上的）+ 目标件存在。默认职业 100（组 1）与 01010011 末位 1
	# **同组 ⇒ 转不了**；临时换到组 2（job=200），目标 01010012 存在 ⇒ 放得进。
	场景.call("_set_strengthen_tab", 3)
	for _i in 3:
		await process_frame
	页 = _打造页(场景)
	var 进阶面板 := 页.get_node_or_null("面板容器/原版装备进阶页") as Control
	if 进阶面板 == null:
		_失败.append("E2：进阶面板没建出来")
	else:
		页 = await _点放入选(场景, 页, 进阶面板.get_node("放入装备") as Button, 0)   # 身上那件
		_查(bool(场景.get("_强化放入中")) == false, "E2：进阶页身上件应被拒（要求先卸到背包）")
		_查(状态行.text.contains("请先将装备卸下到背包再操作"),
				"E2：进阶身上件拒句照原版（实际「%s」）" % 状态行.text)
		进阶面板 = 页.get_node_or_null("面板容器/原版装备进阶页") as Control
		会话.player_stats["job"] = 200
		页 = await _点放入选(场景, 页, 进阶面板.get_node("放入装备") as Button, 1)
		_查(bool(场景.get("_强化放入中")), "E2：换组后背包件进阶页应放得进（目标 01010012 存在）")
		会话.player_stats["job"] = int(_快照["job"])

	# —— D：整框页的根/外框必须 IGNORE，才拖得动 ——
	# （instantiate() 拿到的**就是**页面根本身，不是它的父层 —— 别再去 get_node 同名子节点）
	for 对 in [
		["res://场景/界面/窗口/装备强化/装备强化窗口.tscn", "原版装备强化内容", "外框"],
		["res://场景/界面/窗口/活跃度/活跃度窗口.tscn", "原版活跃度内容", ""],
	]:
		var 根 := (load(String(对[0])) as PackedScene).instantiate() as Control
		_查(String(根.name) == String(对[1]), "D：%s 场景根名字变了（实际 %s）" % [对[0], 根.name])
		_查(int(根.mouse_filter) == 2, "D：%s 页面根必须 IGNORE(2)，才不吞标题栏 29px（整窗拖不动）" % 对[1])
		if not String(对[2]).is_empty():
			var 框 := 根.get_node_or_null(String(对[2])) as CanvasItem
			_查(框 != null and int(框.mouse_filter) == 2, "D：%s/%s 必须 IGNORE(2)" % [对[1], 对[2]])
		根.free()

	# —— H：材料框「购买」不再是"禁用 + 本轮未做"的桩 ——
	# 原版共用材料格 `ItemCaiLiaoBox.buyHandler:46-55` 发 `REQUEST_CASH_ITEM_INFO`（id = 材料 id）
	# ⇒ 走 `功能窗口.请求商城商品`（2026-10-11 接上）。这一页的材料 id 来自 `配置.needItemId`，
	# 所以这条**同时**验了"配置算出来了、按钮才放开"。
	# ⚠️ 先切回「强化」页签（前面几段把页签停在 2/5 上）：**共用左栏只服务强化与天生两页**，
	#    其余五页整列藏掉、那枚购买钮按原版也就没意义 —— 停在专属页上断言必然假红。
	场景.call("_set_strengthen_tab", 0)
	for _i in 3:
		await process_frame
	页 = _打造页(场景)
	if 页 == null:
		_停("H：重取打造页失败")
		return
	var 假 := 假后端.new()
	场景.set("_backend", 假)
	var 购买钮 := 页.get_node_or_null("内容容器/材料框/购买") as Button
	_查(购买钮 != null, "H：材料框里没有「购买」钮")
	if 购买钮 != null:
		_查(not 购买钮.disabled, "H：放了装备后「购买」该可用（原版点它开商城购买窗），现在还是禁用桩")
		if not 购买钮.disabled:
			购买钮.pressed.emit()
			await process_frame
			_查(假.收到.size() == 1 and int(假.收到[0]) > 0,
				"H：点「购买」应发 request_cash_item_info(材料 id)，实测 %s" % str(假.收到))
	场景.set("_backend", null)

	# —— I：悬停详情框（2026-10-20 #6）——
	# 原版打造页的格子挂 `MToolTipItem`（`SimpleItemCell.as:220` / `ItemDropBox` 同源），
	# 这一页原来一处都没接 ⇒ 用户报「悬停不显示详情框」。接线走 `格子提示框.接线`。
	var 提示 := 页.get_node_or_null("物品提示框") as Control
	var 装框 := 页.get_node_or_null("装备提示框") as Control
	_查(提示 != null and 装框 != null, "I：打造页缺「物品提示框 / 装备提示框」节点")
	var 材料格 := 页.get_node_or_null("内容容器/材料框/材料格") as Control
	_查(材料格 != null and int(材料格.mouse_filter) != 2,
		"I：打造页材料格还是 IGNORE(2)，永远收不到悬停")
	if 提示 != null and 材料格 != null and int(材料格.mouse_filter) != 2:
		提示.visible = false
		材料格.mouse_entered.emit()
		_查(提示.visible, "I：材料格悬停没弹「物品提示框」")
		材料格.mouse_exited.emit()
		_查(not 提示.visible, "I：移出材料格后「物品提示框」没收")

	# —— J：放入格 / 右栏行 的悬停必须拿**整件实例**，金币行按原版数据 ——
	# 2026-11-01 用户三条反馈：①放入那格「只显示白板属性」②右栏行「悬停不显示详情框」
	# ③「强化消耗金币一直是 0 吗」。①② 的根因是 `_接打造提示` 只喂 `{id, quantity}`；
	# ③ 不是 bug —— 原版数据里强化 level1..10 的 needMoney 就是 0（只耗强化灵珠）。
	会话.equipped_items.clear()
	会话.inventory.clear()
	会话.equipped_items[_武器位()] = _造件("01010011", -1, _实例字段(3))
	会话.inventory.append(_造件("01010011", 40, _实例字段(5)))
	场景.call("_set_strengthen_tab", 0)
	for _i in 3:
		await process_frame
	页 = _打造页(场景)
	if 页 == null:
		_停("J：重取打造页失败")
		return
	页 = await _点放入选(场景, 页, 页.get_node("内容容器/放入装备") as Button, 0)   # 行 0 = 身上那件（强化 3）
	var 物品框 := 页.get_node_or_null("物品提示框") as Control
	var 装备框 := 页.get_node_or_null("装备提示框") as Control
	if 装备框 == null:
		_停("J：打造页没有装备提示框节点")
		return
	var 放入格 := 页.get_node_or_null("内容容器/装备格") as Control
	_查(放入格 != null and int(放入格.mouse_filter) != 2,
			"J：放入装备那格还是 IGNORE(2)，收不到悬停")
	if 放入格 != null and int(放入格.mouse_filter) != 2:
		装备框.visible = false
		放入格.mouse_entered.emit()
		await process_frame
		var 明细 := String((装备框.get_node("明细") as RichTextLabel).text)
		_查(装备框.visible, "J：放入格悬停没弹「装备提示框」")
		_查(明细.contains("50/100"),
				"J：放入格明细该用**实例**耐久 50/100（只传 id 时是模板值），实际「%s」" % 明细)
		_查(明细.contains("强化等级　3") and 明细.contains("+77"),
				"J：放入格明细该显示实例强化（强化等级　3 + 强化值 +77），实际「%s」" % 明细)
		_查(明细.contains("附加属性"),
				"J：放入格明细该有附加属性段（实例带 3 条），实际「%s」" % 明细)
		_查(物品框 == null or not 物品框.visible, "J：装备悬停不该弹「物品提示框」")
		放入格.mouse_exited.emit()

	# 右栏行：悬停挂在整行那枚「按下」钮上（40x40 图标被它盖住，挂格子节点收不到）。
	# 第 2 行是背包件（强化 5）—— 明细读出 5 才证明交出去的是**这一行**的实例，不是身上那件。
	页 = _打造页(场景)
	var 列表2 := 页.get_node("列表内容") as Control
	_查(列表2.get_child_count() == 2, "J：右栏应有 2 行（身上+背包），实际 %d" % 列表2.get_child_count())
	if 列表2.get_child_count() == 2:
		var 背包钮 := _按下钮(列表2.get_child(1))
		_查(背包钮 != null and 背包钮.mouse_entered.get_connections().size() >= 1,
				"J：右栏行没接悬停（原版那行是 SimpleItemCell 挂 MToolTipItem）")
		if 背包钮 != null:
			装备框.visible = false
			背包钮.mouse_entered.emit()
			await process_frame
			var 行明细 := String((装备框.get_node("明细") as RichTextLabel).text)
			_查(装备框.visible, "J：右栏行悬停没弹「装备提示框」")
			_查(行明细.contains("强化等级　5"),
					"J：右栏行明细该是这一行自己的实例（背包件强化等级　5，身上那件是 3），实际「%s」" % 行明细)
			背包钮.mouse_exited.emit()

	# 金币行：原版 `EQUIP_STRENGTH_DESC_TEMPLATE_0` 直接印 `configInfo.needMoney`
	# （`EquipStrengthWindow.as:573-630`）。下面六个值是 `数据/装备打造.json` 里的字面量：
	# 强化 level1..10 → 0（只耗强化灵珠 1/2/5/10/20…）、洗附加属性/数值 → 2500、
	# 进阶 → 10000、天生(阶 1) → 500、刻印 → 100000。精炼页（`EquipBaiLianPanel.as`）
	# 原版就没有这一行 ⇒ 期望空。
	var 期望金币 := ["0", "2500", "2500", "10000", "500", "100000", ""]
	var 页名 := ["强化", "洗附加属性", "洗附加数值", "进阶", "天生", "刻印", "精炼"]
	for 序 in 期望金币.size():
		场景.call("_set_strengthen_tab", 序)
		for _i in 3:
			await process_frame
		页 = _打造页(场景)
		var 行文 := _消耗文本(页)
		if String(期望金币[序]).is_empty():
			_查(行文.is_empty(), "J：%s页原版没有消耗金币行，实测「%s」" % [页名[序], 行文])
		else:
			_查(行文.contains("本次操作消耗金币：" + String(期望金币[序])),
					"J：%s页消耗金币该是 %s（原版 needMoney），实测「%s」" % [页名[序], 期望金币[序], 行文])

	_收尾()
	if _失败.is_empty():
		print("装备打造放入回归测试：通过（%d 条断言：开窗空放/取出清空/背包行可放/同id不标已装备/专属页藏共用格/整框页可拖/材料框购买发商城请求/格子悬停出详情框/放入格与右栏行用整件实例/七页金币行/七页放入门槛（等级·白色·精炼星级·破损·进阶卸下））" % _受检)
		quit(0)
		return
	for 项 in _失败:
		printerr("装备打造放入回归测试：" + 项)
	quit(1)

func _打造页(场景: Node) -> Control:
	return 场景.find_child("原版装备强化内容", true, false) as Control


## 点「放入装备」→ 在弹层里选第 `行` 条（2026-11-08 起的用户授权通道：清单替代原版跟手光标）。
## 清单名固定「放入选择」（`放入选择器.弹`），次序 = `_打造放入候选`：**先身上、后背包**。
## 返回（可能已重建的）打造页 —— 选中成功后回调会整页重建，旧句柄当场作废。
func _点放入选(场景: Node, 页: Control, 钮: Button, 行: int) -> Control:
	钮.pressed.emit()
	await process_frame
	var 器 := 页.get_node_or_null("放入选择") as PopupMenu
	_查(器 != null, "放入清单没弹出来（放入钮没走 放入选择器）")
	if 器 == null:
		await process_frame
		return _打造页(场景)
	器.id_pressed.emit(行)
	await process_frame
	await process_frame
	return _打造页(场景)

## 页面上所有**可见的**「本次操作消耗…」标签文本（拼一起）。打造页各页签挂在不同的
## 专属面板里，按名字找会漏 —— 全树走一遍，只收 visible 的（藏起来的那份不算）。
func _消耗文本(根: Node) -> String:
	var 出: Array[String] = []
	_收消耗(根, 出)
	return " ‖ ".join(出)

func _收消耗(节点: Node, 出: Array[String]) -> void:
	if 节点 is Label or 节点 is RichTextLabel:
		var 文 := String(节点.get("text"))
		if 文.contains("本次操作消耗") and (节点 as CanvasItem).is_visible_in_tree():
			出.append(文)
	for 子 in 节点.get_children():
		_收消耗(子, 出)


## 行上"已装备"那一枚标签的现在文本。认坐标不认文本 —— 背包行那枚是**空文本**，
## 拿文本找就找不到了（那正是我们要断言的东西本身）。
## 位置真值：`ItemPanelRanderer` 的 @ (91,22)。
func _行标签(行: Node) -> String:
	for 子 in (行 as Control).get_children():
		var 标 := 子 as Label
		if 标 != null and absf(标.position.x - 91.0) < 1.0 and absf(标.position.y - 22.0) < 1.0:
			return 标.text
	return "<找不到已装备标签>"

## 行里唯一的 Button 就是那一层"按下"（`_建部位行` 里 `Button.new()` **没设 name**，
## 按名字找是找不到的——只能按类型；行里也只有它一个 Button）。
func _按下钮(行: Node) -> Button:
	for 子 in (行 as Control).get_children():
		if 子 is Button:
			return 子 as Button
	return null

func _停(原因: String) -> void:
	_收尾()
	printerr("装备打造放入回归测试：中断 - " + 原因)
	quit(1)

func _收尾() -> void:
	if not _快照.is_empty():
		var 会话 := root.get_node("/root/GameSession")
		会话.inventory.assign(_快照["inventory"])
		会话.equipped_items = _快照["equipped_items"]
		会话.player_stats["job"] = int(_快照.get("job", 会话.player_stats.get("job", 0)))
	if not _文件前.is_empty():
		门存档快照.全还原(_文件前)
