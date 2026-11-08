extends Button
## 可拖拽格 —— 「能拖出去、也能当落点」的格子控件的公共部分。
##
## 原版这两件事都在 `DragManager` 里：起拖走 `createDragDataProxy`
## （`com/mxw/uifl/base/managers/DragManager.as:137-155`），落点由各窗口自己的
## `onItemUp` 判定（`EquipPane.as:968` / `ItemWindow2.as:1647`）。
## Godot 这边换成内置拖放（`_get_drag_data` / `_can_drop_data` / `_drop_data`），
## **把"从哪格到哪格"换算成协议的事交给页面脚本** —— 组件本身不认识背包/装备/仓库。
##
## 继承者：`物品格.gd`（背包 / 仓库）、`装备格.gd`（人物面板装备格）。
## 子类可以重写 `_can_drop_data` 加自己的准入条件
## （装备格就要求"这件装备只能落在它自己的那个槽"，见 `装备格.gd`）。
##
## ⚠️ 默认**不启用**：要页面把 `可拖拽 = true` 打开，并且 `格子归属` 填上
## （页面用来区分"背包内移动"还是"背包↔仓库/装备"）。

## 落下时带上"来源格那件物品的 id"——跨容器搬动要用它，免得落下时再反查。
signal 拖放(来源格: Button, 目标格: Button, 物品id: String)

## 页面填：这一格属于哪个容器（例如 "背包" / "仓库" / "装备"）。空串 = 不参与拖放。
var 格子归属 := ""
## 页面填：这一格在该容器里的**绝对格位**。
## 背包/仓库用原版 position（1 基）；**装备格填的是装备位置 int，是负数**
## （武器 -1 … 斗篷 -12、勾玉 -20 … 羁绊 -50、神器 -100/-101，见 `脚本/单例/装备部位.gd`）。
var 槽位号 := -1
## 页面填：格子里那件物品的 id（空格子留空）。拖放时随载荷带走，
## 免得落下时再从图标反查（反查要拿到宿主窗口，很脆）。
var 物品id := ""
## 页面填：这一格能不能**被拖出去**（能不能当拖拽源）。
##
## ⚠️ 这跟"能不能当落点"是**两件事**，别混（原来 `物品格.gd` 用同一个开关管两头）。
## 装备格就是"只接、不吐"：**原版从装备格起拖是死代码** ——
## `EquipPane.as` 里 `onItemMove`（`:759-766`，唯一一处 `createDragDataProxy(..., EQUIP_WINDOW)`）
## 全文件只有 3 处 `removeEventListener(MSpriteEvent.MSPRITE_MOVE, this.onItemMove)`
## （`:589` / `:765` / `:971`）、**一处 addEventListener 都没有**，所以它从来不会被调用；
## 原版卸装备走的是双击（`onItemDoubleClick` → `unequip`）或物品菜单「卸下」（**左键**单击弹出）。
## → 装备格填 `false`，拖它**连半透明代理都不出现**，与原版一致。
var 可拖拽 := false:
	set(值):
		可拖拽 = 值
		# Godot 的拖放要求源控件 mouse_filter 不是 IGNORE
		mouse_filter = Control.MOUSE_FILTER_STOP if 值 else mouse_filter


## 资质（品质）覆盖层 —— 背包格、仓库格、人物装备格叠的是**同一套**东西，
## 入口放在公共父类；条件、素材、几何全在 `脚本/单例/装备品质.gd` + `数据/装备品质.json`，
## 这里不再抄一份常量表（原来 `装备格.gd`/`装备提示框.gd`/`功能窗口.gd` 各抄了一份，
## 三份还互相打架 —— 文件名被 AS3 的类名带偏过，见 `装备品质.gd` 开头那段）。
const 品质表 := preload("res://脚本/单例/装备品质.gd")


## 按**物品实例**叠资质框 + 紫橙流光。原版对应关系：
##   背包/仓库格 = `ItemWindowCell.showIcon`（`:237-267`），
##   人物装备格 = `EquipmentWindowCell.showIcon`（`:118-143`）。
## **灵器/忍具两族是恒粉框 + 流光**（不看 aptitude），原版把它们写进了各自专用的
## 格子类，而本工程人物面板统一用这一个 `装备格` 顶：
##   灵器 `LingQiCell.setCellValue`（`:85-92`）、忍具 `RenJuCell.setCellValue`（`:85-92`）；
##   背包格那边是 `ItemWindowCell` 的 `addLingQiitemAnima`（`:169-188`）/
##   `addRenJuItemFrame`（`:191-204`）。
## 所以页面要按**自己这格属于哪族**把 `认灵气` / `认忍具` 打开 —— 背包两种都开，
## 人物面板的灵器格开前者、忍具格开后者。仓库格/列表行原版没有这两条分支，保持关。
## 没填 `aptitude` 的物品（消耗品、材料）与资质 1(白) 一样：什么都不叠。
func 设置品质(物品: Dictionary, 认灵气: bool = false, 认忍具: bool = false) -> void:
	品质表.挂覆盖层(self, 物品, 认灵气, "格子", Vector2.ZERO, 认忍具)


## 空格子 / 换数据前清场。原版 `showIcon` 之前先 `removeChild` 掉旧的
## aptitudeIcon 与 equipAnimationF（`ItemWindowCell.as:375-383`）。
func 清空品质覆盖层() -> void:
	品质表.挂覆盖层(self, {})



## 拖出来的**预览**。原版 `DragManager.createDragDataProxy`（`:137-155`）只做三件事：
##   ① 代理 = 格子**图标**的一个副本（`BaseUtil.getMCCopy(param2)`，param2 是 `getCellIcon()`）
##      —— 所以资质框/破碎角标/耐久红框那六层覆盖层**不跟着走**；
##   ② `_dragDataProxy.alpha = 0.5`（`:143`）；
##   ③ 代理**居中在鼠标下**（`setDragLocation`：`x = mouseX - width/2`）。
## 下面三条逐条对应。⚠️ 空格子（`icon == null`）起不了拖 —— 原版同样
## （`EquipPane.as:761` / `ItemWindow2` 都是先看 `getCellValue()` 有没有值）。
func _get_drag_data(_位置: Vector2) -> Variant:
	if not 可拖拽 or disabled or icon == null or 格子归属.is_empty():
		return null
	var 预览 := TextureRect.new()
	预览.texture = icon
	预览.size = Vector2(40.0, 40.0)
	预览.modulate = Color(1.0, 1.0, 1.0, 0.5)
	var 宿主 := Control.new()
	宿主.add_child(预览)
	预览.position = Vector2(-20.0, -20.0)
	set_drag_preview(宿主)
	return {"来源格": self, "归属": 格子归属, "物品id": 物品id}


## 能不能当**落点**。只看两件事：填了归属（页面认领了这一格）、
## 以及 `mouse_filter` 不是 IGNORE（Godot 就是靠它做命中的）。
## **不看 `可拖拽`** —— 装备格只接不吐。
##
## 顺带记一条量出来的结论（`开发工具/拖放通路体检.gd`，2026-09-22）：
## **`disabled = true` 挡不住落点** —— 对照组（启用物品格）与禁用物品格都收到了拖放。
## 所以人物面板那个 `装备格.disabled = not 有装备` 可以留着不动，空格照样能接装备。
func _can_drop_data(_位置: Vector2, 数据: Variant) -> bool:
	if 格子归属.is_empty() or mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	if typeof(数据) != TYPE_DICTIONARY:
		return false
	var 字典 := 数据 as Dictionary
	if 字典.get("归属") == "料理":
		return 格子归属 == "背包" and 字典.get("来源格") is Control
	return 字典.has("来源格") and 字典["来源格"] != self


func _drop_data(_位置: Vector2, 数据: Variant) -> void:
	var 字典 := 数据 as Dictionary
	if 字典.get("归属") == "料理":
		(字典["来源格"] as Control).emit_signal("请求取出")
		return
	拖放.emit(字典["来源格"] as Button, self, String(字典.get("物品id", "")))
