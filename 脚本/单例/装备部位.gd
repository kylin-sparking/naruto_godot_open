extends RefCounted
## 装备部位 —— **全套移植里唯一的一份**部位真值表。
##
## 为什么要有这个文件（2026-09-21）：
##   在这之前，同一个"装备部位"在客户端里有 **五份互不一致** 的定义
##   （`后端连接.gd` 的 `_equipment_name` / `_equipment_position_for_item`、
##     `服务端会话同步.gd` 的 `装备部位`、`游戏会话.gd` 的 `_equipment_position_for_name`、
##     `人物窗口.gd` 的 `装备部位`），数量不同（6 / 24 / 18）且值有错位。
##   装备模块动的第一刀就是把它们合并成这一份。
##
## 真值出处（2.2.3，**不是推断**）：
##   * 位置值      `com/mxw/data/enums/EquipmentPosition.as:6-64`
##   * 物品→位置   `EquipmentPosition.getItemEquipPosition()`（同文件 :71-142）：
##                 先判 7 位前缀（19 魂戒 / 20 灵器 / 65 人具），再判 4 位前缀
##   * 面板顺序    `EqpData.EQUIP_PARTS`（`EqpData.as:27`）
##   * 显示名      `EqpData.EQUIP_NAMES`（`EqpData.as:29` → `en_US$message_properties.as`）
##                 **外加两处格子类自带的 SLOT_NAME**（语言表里没有）：
##                 `LingQiCell.as:20 = "灵器"`、`RenJuCell.as:20 = "忍具"`
##   * 格的位置    `EquipPaneF`(符号 94) 时间轴 + `EquipPane.as` 的 set*XY 公式
##                 + 用户 2026-09-21 跑着的原版实测（见下）
##
## ⚠️ 用户 2026-09-21 口径：**以跑着的原版为准**（§3.10.11 第 1 条）。
##    人物面板 20 格的落点已对着原版 4× 放大图逐格核过：
##    `人物窗口.tscn` 里 忍具(51,120)/灵器(51,162)/徽章(155,162)/羁绊(155,204)/
##    勾玉(59,316)/变身(102,316) 与实测逐格吻合；神器镜(59,154)/神器剑(59,226) 同法量得。

## 位置常量（值与 2.2.3 `EquipmentPosition` 一一对应，**别改**——协议里就是这个数）
const 武器 := -1
const 手套 := -2
const 衣服 := -3
const 护额 := -4
const 护腰 := -5
const 忍鞋 := -6
const 斗笠 := -7
const 项链 := -8
const 戒指 := -9
const 手环 := -10
const 忍包 := -11
const 斗篷 := -12
const 勾玉 := -20
const 变身 := -21
const 徽章 := -22
const 灵器 := -23
const 忍具 := -24
const 羁绊 := -50
const 神器剑 := -100
const 神器镜 := -101

## 宠物 5 槽（**正数**，存在 CocoPet 里，不在人物面板）
const 宠物一 := 1
const 宠物二 := 2
const 宠物三 := 3
const 宠物四 := 4
const 宠物五 := 5

## 昆虫 4 槽 + 昆虫包（原版 `KunChongPanel` 建格，不在人物面板）
const 昆虫一 := -200
const 昆虫二 := -201
const 昆虫三 := -202
const 昆虫四 := -203
const 昆虫包 := -205

## 标准 12 槽（`EquipA..EquipL`），左右两列各 6。
const 标准槽 := [武器, 手套, 衣服, 护额, 护腰, 忍鞋, 斗笠, 项链, 戒指, 手环, 忍包, 斗篷]

## **人物面板**上有的槽。顺序按原版 `EquipPane.init` 的建格顺序：
##   cell0..cell11 = 标准 12 槽；huizhangCell = 徽章；
##   createShenQiCell → 神器剑/镜；createLingQiCell → 灵器；
##   createRenJuCell → 忍具；createHunjieCell → 羁绊；cell12/13 = 变身/勾玉。
## 宠物 5 槽在宠物窗、昆虫 4 槽与昆虫包在昆虫窗，**都不进人物面板**。
const 人物面板槽 := [
	武器, 手套, 衣服, 护额, 护腰, 忍鞋,
	斗笠, 项链, 戒指, 手环, 忍包, 斗篷,
	勾玉, 变身, 徽章, 神器剑, 神器镜, 灵器, 忍具, 羁绊,
]

## 位置 → 显示名。**取自原版，不是自造**：
##   标准 12 + 变身/勾玉/徽章/项链 用 `EQUIP_NAMES` 对应的语言表条目；
##   灵器/忍具用各自格子类里的 `SLOT_NAME`；羁绊用 `EQUIPMENT_EQUIP_HJ`；
##   神器剑/神器镜**原版格子上不显示名字**
##   （`ShenQiCell.setCellValue` 里 `equipNameText.visible = false`），
##   这里给的是结构性标识名，只用于日志/调试 —— **别往画面上写**，写了就是自绘（§0 第一原则）。
const _显示名 := {
	武器: "武器", 手套: "手套", 衣服: "衣服", 护额: "护额", 护腰: "护腰", 忍鞋: "忍鞋",
	斗笠: "斗笠", 项链: "项链", 戒指: "戒指", 手环: "手环", 忍包: "忍包", 斗篷: "斗篷",
	勾玉: "勾玉", 变身: "变身", 徽章: "徽章", 灵器: "灵器", 忍具: "忍具", 羁绊: "羁绊",
	神器剑: "神器剑", 神器镜: "神器镜",
	宠物一: "兽铠", 宠物二: "兽爪", 宠物三: "兽符", 宠物四: "兽盔", 宠物五: "变身",
	昆虫一: "昆虫一", 昆虫二: "昆虫二", 昆虫三: "昆虫三", 昆虫四: "昆虫四", 昆虫包: "昆虫",
}

## 4 位前缀 → 位置（`getItemEquipPosition` 的 switch，101→武器 … 205→宠物五）
const _前四位表 := {
	101: 武器, 102: 手套, 103: 衣服, 104: 护额, 105: 护腰, 106: 忍鞋,
	107: 斗笠, 108: 项链, 109: 戒指, 110: 手环, 111: 忍包, 112: 斗篷,
	120: 勾玉, 121: 变身, 131: 昆虫包, 141: 徽章,
	201: 宠物一, 202: 宠物二, 203: 宠物三, 204: 宠物四, 205: 宠物五,
	1710: 神器剑, 1720: 神器镜,
}

## 7 位前缀 → 位置（**优先判**，`getItemEquipPosition` 的头三个 if）
const _前七位表 := {19: 羁绊, 20: 灵器, 65: 忍具}


static func 显示名(位置: int) -> String:
	return String(_显示名.get(位置, ""))


static func 是人物面板槽(位置: int) -> bool:
	return 人物面板槽.has(位置)


static func 是宠物槽(位置: int) -> bool:
	return 位置 in [宠物一, 宠物二, 宠物三, 宠物四, 宠物五]


static func 是昆虫槽(位置: int) -> bool:
	return 位置 in [昆虫一, 昆虫二, 昆虫三, 昆虫四]


## 物品 id → 装备位置。**逐字照抄 `EquipmentPosition.getItemEquipPosition`**。
## 认不出来返回 0（原版返回 `int.MIN_VALUE`；客户端用 0 表示"不是装备位"，
## 与 `_item_display_fields` 里 `equip_position = 0` 的约定一致）。
static func 位置(id文本: String) -> int:
	if not id文本.is_valid_int():
		return 0
	var 数值 := int(id文本)
	var 前七位 := int(数值 / 1000000)
	if _前七位表.has(前七位):
		return int(_前七位表[前七位])
	return int(_前四位表.get(int(数值 / 10000), 0))


## 这个 id 是不是能穿的装备
static func 是装备(id文本: String) -> bool:
	return 位置(id文本) != 0
