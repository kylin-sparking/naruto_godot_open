class_name SkillHitBox
extends RefCounted

## 技能命中矩形的**唯一一份**几何口径 —— 玩家放技能与离线怪放技能共用。
##
## 原来这段只长在 `玩家.技能命中矩形()` 里；2026-10-01 离线怪要按原版 `AttackExecute.canFireSkillTo`
## 判"这个技能够不够得着"，同一张定表要是抄第二份，两边迟早会漂。真值两段：
##
##   · `SkillDataTool.getSkillHitRect():60-131` —— 按技能 `range` 取一张**定表**：
##     `1 → (-100,-100)-(0,50)`、`2 → (-400,-100)-(0,50)`、`3 → (-150,-150)-(150,50)`、
##     `4 → (-1200,-600)-(1200,600)`，其它 range → 空盒。
##   · `AbstractAttackSkill.getSkillHitRect():571-582` —— `y += 施法点.y`；
##     朝左 `x += 施法点.x`；朝右 `x = -right + 施法点.x`。
##
## ⚠️ range 1/2 的表是**单侧**的（贴着朝向那一侧），range 3 是左右对称的 ——
## 所以镜像**不能**一律写成 `x - 宽`，得按 left/right 分别算。这也是
## `MobAttackTool.computeSkillHitRect():91-97`（先 `right=-left; left=-right` 再整体平移）
## 的等价写法，两处镜像结果一致。

## `range` → `[左, 右, 上, 下]`（`SkillDataTool.getSkillHitRect` 的定表）。
const 范围表 := {
	1: [-100.0, 0.0, -100.0, 50.0],
	2: [-400.0, 0.0, -100.0, 50.0],
	3: [-150.0, 150.0, -150.0, 50.0],
	4: [-1200.0, 1200.0, -600.0, 600.0],
}

## 按技能 `range` 算。表里没有的 range 返回**空盒**（原版 default 分支就是 (0,0,0,0)，
## 等于"这个技能没有自动选敌"）。
static func 由范围(range值: int, 施法点: Vector2, 朝向: int) -> Rect2:
	if not 范围表.has(range值):
		return Rect2()
	var 表: Array = 范围表[range值]
	return 摆放(float(表[0]), float(表[1]), float(表[2]), float(表[3]), 施法点, 朝向)

## 怪物技能槽自带的 `hitRect`（`{lt:{x,y}, rb:{x,y}}`）优先于上面的定表
## （`MobAttackTool.computeSkillHitRect()` 就是这个优先级）。没有 `hitRect` 时返回空盒，
## 由调用方回落到 `由范围()`。
static func 由槽位(槽: Dictionary, 施法点: Vector2, 朝向: int) -> Rect2:
	var 槽盒: Dictionary = 槽.get("hitRect", {})
	if 槽盒.is_empty():
		return Rect2()
	var lt: Dictionary = 槽盒.get("lt", {})
	var rb: Dictionary = 槽盒.get("rb", {})
	if lt.is_empty() or rb.is_empty():
		return Rect2()
	return 摆放(float(lt.get("x", 0)), float(rb.get("x", 0)),
			float(lt.get("y", 0)), float(rb.get("y", 0)), 施法点, 朝向)

static func 摆放(左: float, 右: float, 上: float, 下: float, 施法点: Vector2, 朝向: int) -> Rect2:
	var 起点x := 施法点.x + 左 if 朝向 < 0 else 施法点.x - 右
	return Rect2(起点x, 施法点.y + 上, 右 - 左, 下 - 上)
