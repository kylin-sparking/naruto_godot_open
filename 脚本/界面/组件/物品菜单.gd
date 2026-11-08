extends Control

## 原版**物品菜单**（`MPopupMenu` + `ItemWindow2.getItemMenu`）。
##
## ⚠️ 触发方式是**左键单击**格子，不是右键 —— `ItemWindowCell.singleClickHandler` 发
## `MSpriteEvent.MSPRITE_CLICK` → `ItemWindow2.onItemClick`（`ItemWindow2.as:428`）
## 建 `MPopupMenu`。**右键在原版没有任何功能**（弹的是 Flash Player 自带菜单），别照右键做。
## 双击走 `doubleClickHandler` → 使用物品；按住 Ctrl 单击 = 发到聊天框（`:483`）。
##
## 版式真值（`MPopupMenu.as`，MARGIN=3、totalMargin=6）
##   :50   按钮 x = 3、y = 累计 + 3，累计 += 按钮高(19)
##   :59   bgWidth = max(按钮自然宽) + 6
##   :76   按钮统一 宽 = bgWidth − 6
##   :85   底高 = 累计 + 6、底宽 = bgWidth
##   :89   底是 `MPopupMenu_background` 时**再 +4 宽、+5 高**
## 按钮宽来自 `MButton.as:167-170`：`宽 = 文本宽 + (paddingLeft-3) + (paddingRight-5) + 1`，
## 两个 padding 默认都是 7 ⇒ **宽 = 文本宽 + 7**。
## 真机复核：原版菜单实测宽 **72**，按「发到聊天框」5 字（≈55）+ 17 = 72 ✓
##
## 菜单项表见 `菜单项表`，出处 `CN.as:8254` 的 `menuArr`，按 `物品类型ID − 1` 取。

signal 选择了(项名: String)

const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")

const 边距 := 3.0
const 按钮高 := 19.0
const 按钮文字留白 := 7.0     ## MButton 的 paddingLeft/Right 各 7，按 :170 化简
const 底加宽 := 4.0
const 底加高 := 5.0
const 槽位数 := 12            ## 原版最长的一套是 10 项（装备-玩家），留点余量

const 使用 := "使用"
const 全部使用 := "全部使用"
const 移动 := "移动"
const 拆分 := "拆分"
const 销毁 := "销毁"
const 发到聊天框 := "发到聊天框"
const 绑定 := "绑定"
const 合成 := "合成"
const 重置 := "重置"
const 佩戴 := "佩戴"
const 宠物佩戴 := "宠物佩戴"
const 强化 := "强化"
const 宝石镶嵌 := "宝石镶嵌"
const 破碎修复 := "破碎修复"
const 升阶 := "升阶"
const 镶嵌勾玉 := "镶嵌勾玉"
const 开光 := "开光"
const 灵化 := "灵化"
const 洗练 := "洗练"

## `CN.as:8254 menuArr`，下标 = `ItemType.getTypeFromId(id) − 1`。
## 类型号见 `ItemType.as:9-61`：1 装备-玩家、2 装备-宠物、3 HP药、4 MP药、5 活力药、
## 6 技能书-玩家、7 技能书-宠物、8 残卷-玩家、9 残卷-宠物、10 任务物品、11 礼包、
## 12 材料、13 宝石、14 舍利子、15 特殊物品、16 辅助物品、17 神器、18 Buff物品、
## 19 魂戒、20 灵器。17/18 在 `getItemMenu` 里被 `isItemAShenQi` 提前拦掉。
const 菜单项表 := [
	[佩戴, 移动, 拆分, 销毁, 发到聊天框, 宝石镶嵌, 破碎修复, 强化, 升阶, 镶嵌勾玉],
	[宠物佩戴, 移动, 拆分, 销毁, 发到聊天框, 宝石镶嵌, 强化],
	[使用, 全部使用, 移动, 拆分, 销毁, 发到聊天框],
	[使用, 全部使用, 移动, 拆分, 销毁, 发到聊天框],
	[使用, 全部使用, 移动, 拆分, 销毁, 发到聊天框],
	[使用, 全部使用, 移动, 拆分, 销毁, 发到聊天框],
	[使用, 全部使用, 移动, 拆分, 销毁, 发到聊天框],
	[移动, 拆分, 销毁, 发到聊天框, 合成, 绑定],
	[移动, 拆分, 销毁, 发到聊天框, 合成, 绑定],
	[移动, 拆分, 销毁, 发到聊天框],
	[使用, 全部使用, 移动, 拆分, 销毁, 发到聊天框, 绑定],
	[使用, 全部使用, 移动, 拆分, 销毁, 发到聊天框],
	[移动, 拆分, 销毁, 发到聊天框, 重置, 合成, 绑定],
	[使用, 全部使用, 移动, 拆分, 销毁, 发到聊天框],
	[使用, 全部使用, 移动, 拆分, 销毁, 发到聊天框],
	[移动, 拆分, 销毁, 发到聊天框],
	[], [],                                   # 17/18：原版给的是 [""]，实际被 isItemAShenQi 拦掉
	[移动, 拆分, 销毁, 发到聊天框, 绑定],
	[佩戴, 移动, 拆分, 销毁, 发到聊天框, 开光, 灵化, 洗练],
]
## 类型超出上表时 `getItemMenu` 的回退（`ItemWindow2.as:624-628`）。
## 会走到这里的有：人具65、昆虫131、徽章石132、徽章141、货币90…
const 回退菜单 := [移动, 拆分, 销毁, 发到聊天框]

const 神器 := 17
## 人具（`ItemType.RenJu = 65`，`ItemType.as:47`）—— 它**不在** `菜单项表` 里，
## 原版给的是 `getItemMenu` 里那条写死的六项菜单（见 `取菜单项`）。
const 人具 := 65


## 按物品取菜单项 —— `ItemWindow2.getItemMenu`（:612）+ `filtrateItemMenu`（:505-）的完整实现。
##
## `物品` 是**这一件**的运行时字段（原版 `ItemData`）：
##   id（8 位字符串）、quantity（件数）、use_all（`info.useAll`，1 才算可全部使用）、
##   can_trade、crash_time（`crashTime`，0 = 没破碎）
##
## 类型判定全部照 `ItemType.as` / `EquipmentPosition.as`：
##   `getTypeFromId = int(id / 10000)`        → 装备部位的 3/4 位码（101=武器、102=护额…）
##   `getItemTypeFromId = int(id / 1000000)`  → 19 魂戒 / 20 灵器 / 65 人具
##   `isItemAShiZhuang` = `lpad(id,8).substr(2,2) == "21"`（变身/时装，不能镶宝石）
##   `isItemAGouYu`     = 宝石 且 `substr(0,3) == "131"`
## 位置类判定用等价的**码值**：`isItemAYuLian` ⇔ 四位码 120、`isItemAHuiZhang` ⇔ 141
## （`getItemEquipPosition` 的 switch 里 120→EquipS1、141→HuiZhang）。
##
## ⚠️ 最后还有一段 `UIConfig.isShowKuaiSuShengJieMenu` 的「快捷升阶」处理，
## 那是个开关，且本客户端菜单表里没有「快捷升阶」这一项，**未实现**（原版开着才会动）。
static func 取菜单项(物品: Dictionary, 是神器 := false) -> Array:
	var 物品id := String(物品.get("id", ""))
	# ⚠️ **按位置的解析一律用"八位补零"那一份**。原版 `ItemType` / `EquipmentPosition`
	#    读的就是 `lpad(id, 8)` 的形态；而**服务端下发的 id 是整数形态**（`"1030013"`，
	#    七位，前导零在传输里丢了），`数据/物品.json` 与离线样例则是八位（`"01030013"`）。
	#    直接 `substr(0,2)` 取类型号会从 `"10"` 变成 `"01"` 边上那档 ——
	#    2026-09-27 用户报"装备除了拖拽还有一个佩戴选项"：**在线时装备的菜单里根本没有「佩戴」**
	#    （落进了「任务物品」那档，只剩 移动/销毁），离线因为 id 是八位反而正常。
	#    （写法同 `后端连接.gd:2225`：非纯数字的 id 原样保留，别硬补。）
	var 补零id := 物品id.pad_zeros(8) if 物品id.is_valid_int() else 物品id
	var 件数 := int(物品.get("quantity", 1))
	# 离线的物品字典可能没带 use_all（只有服务端镜像/`数据/物品.json` 有）—— 兜底回表。
	# 2026-10-01：`use_all` 这一列是 `开发工具/导出物品use_all.py` 从服务端 catalog
	# （GameData `info.useAll`）补进表的；以前表里没有，这条菜单项**任何物品都不出**。
	var 可全部使用 := int(物品.get("use_all",
			GAME_DATA.item(补零id).get("use_all", 0))) == 1
	var 类型号 := int(补零id.substr(0, 2)) if 补零id.length() >= 2 else 0
	# 神器 / 人具是 `getItemMenu:612-621` 的**两条提前返回** —— 都**不看那张表**：
	#   · 神器（`isItemAShenQi:113` = `getTypeFromId == 17`）⇒ `[佩戴, 移动, 销毁, 发到聊天框]`
	#     —— 注意**没有「拆分」**；
	#   · 人具（`isItemARenJu:159` = `== 65`）⇒ `[佩戴, 移动, 拆分, 销毁, 发到聊天框, 开光]`
	#     —— **只有「开光」**（灵化/洗练只在 20 灵器那一档）。
	# ⚠️ 2026-10-13 修：这两条原来都靠**入参** `是神器` 判 —— 而全工程唯一的调用点
	#    （`背包窗口.gd:784`）**写死传 false**，于是神器落进 `菜单项表[16] = []` ⇒
	#    **点神器的格子弹出一个空菜单**；人具（65）超出表长 ⇒ 落回退菜单 ⇒
	#    **「开光」这一项玩家根本点不到**（`合成/打造` 那族的"门绿但玩家用不了"同形状）。
	if 是神器 or 类型号 == 神器:
		return [佩戴, 移动, 销毁, 发到聊天框]
	var 项: Array = []
	if 类型号 == 人具:
		项 = [佩戴, 移动, 拆分, 销毁, 发到聊天框, 开光]
	elif 类型号 >= 1 and 类型号 <= 菜单项表.size():
		项 = (菜单项表[类型号 - 1] as Array).duplicate()
	else:
		项 = 回退菜单.duplicate()

	# ── filtrateItemMenu，逐条照抄 ──────────────────────────────
	# :508 `if(int(String(param2.id).substr(0,3)) == ItemType.KunChong(=131)) ⇒ erase(宝石镶嵌)`
	# ⚠️ **这一条必须两个判据并起来**，因为两族的 id 形态不同（2026-10-11 抓到的真实形状：
	#    只写前三位，真昆虫一件都匹配不到，昆虫的菜单里会多出「宝石镶嵌」）：
	#    · **昆虫** = `01310001..01310006` ⇒ 八位补零后前三位是 `013`、**四位码才是 131**
	#      （服务端口径 `item_id // 10000 == 131`、`装备部位.位置 == 昆虫包`）；
	#    · **勾玉** = `13100000…`（360 件）⇒ 前三位 `131`。
	#    原版那句在 `String(id)` 上判，昆虫的整数形态 `1310001` 前三位正好是 `131` ⇒ 两族都命中；
	#    我们照抄到**补零**形态上就分叉了，所以这里两种形态各判一次，结果与原版一致。
	if int(补零id.substr(0, 4)) == 131 or 补零id.substr(0, 3) == "131":
		项.erase(宝石镶嵌)
	# :516 件数为 1 不能拆
	if 件数 == 1:
		项.erase(拆分)
	# :520 不能全部使用就去掉那一项
	if not 可全部使用:
		项.erase(全部使用)
	# :528 装备-玩家 且 是变身/时装 → 不能镶宝石
	var 四位码 := int(补零id.substr(0, 4))
	var 是装备玩家 := 类型号 == 1
	var 是时装 := 补零id.substr(2, 2) == "21"
	if 是装备玩家 and 是时装:
		项.erase(宝石镶嵌)
	# :532 装备-玩家的三档分支
	if 是装备玩家:
		if 四位码 == 120:              # EquipS1 → 玉链
			项.erase(宝石镶嵌)
			项.erase(破碎修复)
			项.erase(强化)
		elif 四位码 == 141:            # HuiZhang → 徽章
			项.erase(宝石镶嵌)
			项.erase(破碎修复)
			项.erase(升阶)
			项.erase(镶嵌勾玉)
		else:
			# :550 没破碎 → 去掉「破碎修复」；破碎了 → 去掉「宝石镶嵌」
			if int(物品.get("crash_time", 0)) == 0:
				项.erase(破碎修复)
			else:
				项.erase(宝石镶嵌)
			项.erase(升阶)
			项.erase(镶嵌勾玉)
	# :559 宝石 / 技能残卷 / 礼包 / 魂戒
	if 类型号 == 13 or 类型号 == 8 or 类型号 == 9 or 类型号 == 11 or 类型号 == 19:
		if not bool(物品.get("can_trade", true)):
			项.erase(绑定)
		if 类型号 == 13 and 补零id.substr(0, 3) != "131":   # 宝石 且 不是勾玉
			项.erase(重置)
	# :571 灵器：开光 / 灵化 / 洗练 三选一。
	# 原版两个判据都是**定义类上的派生量**（`ItemWindow2.isKaiGuang:1173` / `isLingHua:1489`）：
	#   · `isKaiGuang` = `specialAttrList.length > 0`，那串来自**配置** `wzItem.specialAttr`
	#     （`LingQiData.getSpecialAttr:85`）——**只有开光后那件 id 才有**：服务端
	#     `_open_ling_qi` 把 `20100001` 换成 **`20200001`**（`fake_flash_server.py:52434`，
	#     `TOTSUKA_BLADE/OPENED_TOTSUKA_BLADE:590-591`）。⇒ 等价于**判 id**。
	#   · `isLingHua` = `plusAttrList.length > 0` —— 灵化往它里写 6 条（`:52323`
	#     `item.plus_attributes = [[ATTACK, 1] × 6]`），而这个字段帧里**有**
	#     （LING_QI 文本帧尾部就是它，`_encode_item_payload:50845`）。
	# ⚠ 2026-10-13 修：原来读的是 `物品.kai_guang` / `物品.ling_hua`，而**全工程没有任何一处
	#   写这两个键**（`体检无人调用的函数` 那族扫出来的）⇒ 两条判据恒 false ⇒
	#   **已灵化的十拳剑菜单里永远不出「洗练」**，洗练入口在线是死的。
	if 类型号 == 20:
		if 补零id == "20200001":
			项.erase(开光)
		if not (物品.get("plus_attributes", []) as Array).is_empty():
			项.erase(灵化)
		else:
			项.erase(洗练)
	# :589 人具已开光 → 去掉「开光」（`isRenJuKaiGuang:1185`：**id 恰为 65000002**，
	# 同样"开光换了 id"，不是某个标志位）。
	if 类型号 == 65 and 补零id == "65000002":
		项.erase(开光)
	return 项


## 弹出。`菜单项` 是文案数组，`位置` 是弹出点（调用方已算好"格子 + (20,20) + 容器原点"）。
## `指定宽` > 0 走原版 `MPopupMenu(items, menuWidth)` 的**定宽档**：底宽 = 指定宽（按钮宽 = 指定宽 − 6、
## 整枚控件宽 = 指定宽 + 4），与 `bgWidth = menuWidth` / `button.width = bgWidth − 6` 同口径。
## 定宽时不再按最长文案撑宽 —— 组队面板那一枚原版就是写死 50（`TroopHPPane.as:76`）。
func 弹出(菜单项: Array, 位置: Vector2, 舞台尺寸: Vector2, 指定宽 := 0.0) -> void:
	var 按钮组: Array[Button] = []
	var 项数 := mini(菜单项.size(), 槽位数)
	for i in 槽位数:
		var 按钮 := get_node("项_%d" % i) as Button
		按钮.visible = i < 项数
		if i >= 项数:
			continue
		按钮.text = String(菜单项[i])
		按钮组.append(按钮)
	if 按钮组.is_empty():
		visible = false
		return

	var 字体 := 按钮组[0].get_theme_font("font")
	var 字号 := 按钮组[0].get_theme_font_size("font_size")
	var 最大文本宽 := 0.0
	for 按钮 in 按钮组:
		最大文本宽 = maxf(最大文本宽, 字体.get_string_size(按钮.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 字号).x)
	var 按钮宽 := ceilf(最大文本宽 + 按钮文字留白)
	var 底内容宽 := 按钮宽 + 边距 * 2.0
	if 指定宽 > 0.0:
		## `MPopupMenu.as:59-76`：给了 menuWidth 就 `bgWidth = menuWidth`、按钮宽 = bgWidth − 6。
		底内容宽 = 指定宽
		按钮宽 = 指定宽 - 边距 * 2.0
	for i in 项数:
		var 按钮 := 按钮组[i]
		按钮.position = Vector2(边距, 边距 + 按钮高 * i)
		按钮.size = Vector2(按钮宽, 按钮高)

	var 底 := get_node("底") as TextureRect
	底.position = Vector2.ZERO
	底.size = Vector2(底内容宽 + 底加宽, 按钮高 * 项数 + 边距 * 2.0 + 底加高)
	size = 底.size

	# 贴到弹出点，再钳进舞台（原版 ItemWindow2 没做钳制，但菜单贴到屏幕外就点不到了）。
	var 目标 := 位置
	目标.x = clampf(目标.x, 0.0, maxf(0.0, 舞台尺寸.x - size.x))
	目标.y = clampf(目标.y, 0.0, maxf(0.0, 舞台尺寸.y - size.y))
	position = 目标
	visible = true


func 收起() -> void:
	visible = false


func _ready() -> void:
	for i in 槽位数:
		var 按钮 := get_node("项_%d" % i) as Button
		按钮.pressed.connect(func(): 选择了.emit(按钮.text); 收起())
