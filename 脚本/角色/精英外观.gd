extends Node2D

## 精英怪 / 强化小怪身上那一组"外挂件"的**容器**：脚下那圈光环 + 名字下面那排强化属性图标。
## 挂在怪（`CombatActor`）节点下，由 `地图实体._挂精英外观` 建。
##
## 为什么要有这一层容器（2026-10-22 有头量具逮出来的）：
## 原版这两件**不在同一个显示对象上** —— 环走 `Monster.as:1681 layerAura()` 进落脚点层，
## 图标走 `Monster.as:644-666 addJingyingIcons()` 里的 `addChild(_loc2_)` 挂在怪自己身上。
## 环带着 `scaleX = 118/126、scaleY = 28/126` 这个**压扁**比例（一圈扁椭圆），
## 图标是 30×30 原样、摆在脚点下 40 像素。第一版把图标排塞进了带缩放的环节点下面 ⇒
## 两枚图标被一起压成 28×7、还从 y=40 抬到 y=9（量具实测差异盒 57×7 @ y=79）。
## ⇒ 容器自己**不带缩放**，缩放只在孩子「光环」那一层，图标排与它同辈。
##
## 逐条对照（行号 = 2.2.3优化版 的 .as）：
## · 建不建：`Monster.as:1659` ⇒ `info.boss == 1 || info.boss == 2 || jingyings.length > 0` 才建
##   （判定在调用方 `地图实体._挂精英外观`，口径一样）。
## · 环本体：见 `脚本/角色/精英光环.gd`（选图、三档缩放、80 帧、fps=40、墨迹居中都在那边逐句转写）。
## · 图标排：`:644-666` ⇒ 一枚宽 **30**、第 i 枚 `x = i*(30+2)`、整排 `y = 40`、
##   容器 `x = -30/2 * 枚数 + 30/2`。⚠ **注册点在图标正中**（Flash 的 x/y 指注册点）：
##   一枚时容器 x 算出来正好是 0 ⇒ 那枚**端端正正压在脚点下方**；两枚时中心落在 −15 与 +17（中点 +1）。
##   第一版把注册点当成左上角（显式 `centered = false`）⇒ 整排往右偏 15 像素，被玩家实机看图打回。
##   图由 `PicTool.getEliteMobIcon(attrType)` 按档取，七个档见 `PicTool.as:616-650`；
##   **表里没有的 attrType 原版返回 null**（本工程跳过那一枚、不崩，但**照样占位** ——
##   原式 `:665` 的枚数用的是循环末位计数，跟显不显没关系）。
## · 层序：环要画在身体后面（`ALayerType.BOTTOM`）⇒ 调用方给本容器 `z_index = -1`；
##   图标排在怪自己身上 = 该层最上 ⇒ 这里另给 `z_index = 1` 抵回 0，与精灵同 z、再按树序盖在前面。
##   ⚠ 不用 `move_child(环,0)`：`地图实体.gd` 有 5 处 `actor.get_child(0)` 当精灵用。
## · 跟随与显形：`:1406-1413` ⇒ 每帧 `x = 怪.x, y = 怪.y`、`visible = 在镜头里 && !isDie`。
##   本工程挂在怪节点下 ⇒ 位置自动跟；"死了要藏"由 `战斗角色.附属件` 那份清单管（本节点名 `精英外观`）。

const 光环脚本 := preload("res://脚本/角色/精英光环.gd")
const 环名 := "光环"
const 图标排名 := "精英图标排"
## `:660` 一枚图标在原版里的占位宽（`var _loc1_:int = 30`）与缝（`+ 2`）
const 图标宽 := 30.0
const 图标缝 := 2.0
## `:664` 整排 y = 40（相对怪的脚点）
const 图标排Y := 40.0
## `PicTool.as:616-650` 的 switch：`SubAttrType` 号 → 图名。别的号原版返回 null ⇒ 不显。
const 图标档 := {0: "Money", 1: "Hp", 4: "Atk", 5: "Def", 6: "Bsk", 7: "Avd", 16: "Violent"}
const 图标目录 := "res://素材/特效/Effect_EliteMob/Effect_EliteMob_%s/1.png"

var 光环: Node2D
var 图标排: Node2D


## 装脚下那圈环。`要首领环` = 原版 `boss==1`；`怪号` 只为一尾/八尾那一档翻倍。
## 素材不在返回 false（调用方决定要不要报，这里不猜）。
func 建光环(要首领环: bool, 怪号: int) -> bool:
	if 光环 != null and is_instance_valid(光环):
		光环.free()
	光环 = null
	var 件 = 光环脚本.new()
	件.name = 环名
	if not 件.call("装", 要首领环, 怪号):
		件.free()
		return false
	add_child(件)
	光环 = 件 as Node2D
	return true


## 名字下面那排强化图标。`列表` = `[{attr_type,value},…]`（原版的 `jingyings`）。
## 每次先拆旧的再建（与原版 `setLianzhanEffect` 第一句先拆同一口径：不是"有变化才换"）。
func 设图标(列表: Array) -> void:
	if 图标排 != null and is_instance_valid(图标排):
		图标排.queue_free()
	图标排 = Node2D.new()
	图标排.name = 图标排名
	## 容器整体是 `z_index = -1`（环在身体后面），图标要抵回 0 才能盖在精灵之前。
	图标排.z_index = 1
	add_child(图标排)
	var 枚数 := 列表.size()
	var 容器X := -图标宽 / 2.0 * 枚数 + 图标宽 / 2.0		# `Monster.as:665` 原式
	for i in 枚数:
		var 号 := int((列表[i] as Dictionary).get("attr_type", -1))
		if not 图标档.has(号):
			continue
		var 图 := load(图标目录 % String(图标档[号])) as Texture2D
		if 图 == null:
			continue
		var 片 := Sprite2D.new()
		片.name = "图标%d" % 号
		片.texture = 图
		## ⚠ **注册点 = 图标正中**（Flash 里 `x/y` 指的是注册点，而 `:665` 那式一枚时算出来正好是 0
		## ⇒ 一枚就摆在脚点正下方；要是注册点在左上角，一枚时整枚会偏右 15 像素 —— 玩家 10-22 实机
		## 对原版图量的就是"在中间"）。Godot 的 `Sprite2D.centered` 默认就是 true，
		## 第一版我显式写了 `false` ⇒ 两枚偏右 15、一枚偏右 15，被打回。别改回去。
		# `:660` 第 i 枚 x = i*(30+2)；容器再整体左移居中 ⇒ 落点 = 容器X + i*32（**这是中心**）
		片.position = Vector2(容器X + i * (图标宽 + 图标缝), 图标排Y)
		图标排.add_child(片)
