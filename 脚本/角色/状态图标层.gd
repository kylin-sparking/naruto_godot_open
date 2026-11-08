extends Node2D

## 角色头顶那一排"状态图标"—— 原版 `AbstractLifeObject.as` 的 `debuffIcons` / `debuffIconLayer`。
##
## 为什么要它（2026-10-22 夜）：服务端一直在发 **201/202**（`GIVE_FOREIGN_BUFF` / `CANCEL_FOREIGN_BUFF`），
## 那是"**别人**身上挂了什么状态"给同屏其他人看的帧（原版 `AllInOneProcessor:1043/515`
## → `Client.onGiveForeignBuff:2654` → `SkillHandler.applyOtherPlayerBuff:363`
## → `_loc6_.addDebuffIcon(...)`）。本工程以前**连分派臂都没有** ⇒ 两个人对打，
## 谁中了毒、谁被封、谁隐身，旁观端屏幕上一个像素都不变。
##
## 三条只认原版的口径（一条都不许自己发明）：
## · 键 = `类型_招号`（`:205` `_loc1Key_ = param2 + "_" + param1`）⇒ **同一类型不同招是两枚**，
##   而移除（`removeDebuffIcon:110-128`）只按**类型**删 ⇒ 一删就把这一类型的所有招都删掉。
## · 图标 `20×20`（`:244` `width = height = 20`）、**步距 18**（`:151` `x = 18 * i`）⇒ 相邻两枚压 2 像素。
## · 整层**水平居中**、挂在头顶上方 40 像素（`:154-155` `layer.x = -layer.width/2`、`layer.y = -40`）。
##   ⚠ 这里的 -40 是"角色自己坐标系里往上 40"，与怪物脚下那排精英图标（`Monster.as:644-666`，y=+40）
##   不是同一件事，别复用同一个常数。
##
## 时长：`duration < 0` ⇒ 永不过期（`:240` `endAt = -1`）；否则 `endAt = 现在 + duration`，
## 同一枚再次挂上时**只在已经过期时才顺延**（`:215-222`），不是每次都把尾巴推后。

const 节点名 := "状态图标层"
## 与 `地图实体.gd:21` 同一口径：技能表按 preload 取，不依赖 autoload 的注册顺序。
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
const 图标边 := 20.0
const 步距 := 18.0
const 层顶距 := -40.0

var 项 := {}
var 隐身 := false


func _ready() -> void:
	z_index = 2


## 原版 `addDebuffIcon:203-247`。`是宠物招` 决定取哪一套图（`PicTool.getPetSkillPic` / `getSkillPic`）。
func 加(招号: int, 类型: int, 是宠物招: bool, 时长毫秒: int) -> void:
	var 键 := "%d_%d" % [类型, 招号]
	var 现在 := Time.get_ticks_msec()
	var 旧: Dictionary = 项.get(键, {}) as Dictionary
	if not 旧.is_empty():
		var 旧件: Variant = 旧.get("件")
		if 旧件 != null and is_instance_valid(旧件):
			(旧件 as Control).visible = true
		旧["时长"] = 时长毫秒
		if 时长毫秒 < 0:
			旧["止于"] = -1
		elif int(旧.get("止于", -1)) < 0 or int(旧["止于"]) < 现在:
			旧["止于"] = 现在 + 时长毫秒
		_摆位()
		return
	var 图 := _取图(招号, 是宠物招)
	if 图 == null:
		# 原版拿不到图也会留一枚空 MovieClip（占位、把后面的往后推）⇒ 这边同样**占位**，
		# 只是画不出像素；不占位会让"少一张图"改变整排的位置，那是自造。
		项[键] = {"招号": 招号, "类型": 类型, "时长": 时长毫秒, "止于": (现在 + 时长毫秒 if 时长毫秒 >= 0 else -1), "件": null}
	else:
		var 件 := TextureRect.new()
		件.name = "状态_%d_%d" % [类型, 招号]
		件.texture = 图
		## 原版是 `width = height = 20` —— **强制显示尺寸**，与源图多大无关。
		## ⚠ 必须同时把 `expand_mode` 设成 IGNORE_SIZE：缺省 KEEP_SIZE 会被贴图顶回天然尺寸
		## （实测 34×34 ⇒ 整排的居中与步距全歪，而"声明的 size"看着是对的 —— 量具读声明值就漏掉）。
		件.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		件.stretch_mode = TextureRect.STRETCH_SCALE
		件.custom_minimum_size = Vector2(图标边, 图标边)
		件.size = Vector2(图标边, 图标边)
		件.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(件)
		项[键] = {"招号": 招号, "类型": 类型, "时长": 时长毫秒, "止于": (现在 + 时长毫秒 if 时长毫秒 >= 0 else -1), "件": 件}
	_摆位()


## 原版 `removeDebuffIcon:110-128`：**按类型**删（不是按键），删完重排。
func 减(类型: int) -> void:
	var 删了 := false
	for 键 in 项.keys():
		if int((项[键] as Dictionary).get("类型", -1)) == 类型:
			var 件: Variant = (项[键] as Dictionary).get("件")
			if 件 != null and is_instance_valid(件):
				(件 as Node).queue_free()
			项.erase(键)
			删了 = true
	if 删了:
		_摆位()


func 有几枚() -> int:
	return 项.size()


func 有类型(类型: int) -> bool:
	for 键 in 项:
		if int((项[键] as Dictionary).get("类型", -1)) == 类型:
			return true
	return false


## 原版 `doLayoutDebuffIcons:143-156`：枚内 x = 18*i，整层 x = -层宽/2、y = -40。
func _摆位() -> void:
	var 序 := 0
	for 键 in 项:
		var 件: Variant = (项[键] as Dictionary).get("件")
		if 件 != null and is_instance_valid(件):
			(件 as Control).position = Vector2(步距 * 序, 0.0)
		序 += 1
	var 宽 := 步距 * maxf(0.0, float(序 - 1)) + 图标边
	position = Vector2(-宽 * 0.5, 层顶距)


## 原版 `:260` 那个 getter：`endAt >= 0 ? max(0, endAt - now) : -1`。
## ⚠ **原版这边没有本地到期回收** —— 图标只被 202 那条帧删（服务端过期扫描 `:37970-37982` 会补发）。
## 所以这一档只给悬停提示用，不许拿它偷偷做"到点自己消失"（那是自造，会把"服务端没发 202"这个真 bug 盖掉）。
func 剩余毫秒(类型: int) -> int:
	for 键 in 项:
		var 录 := 项[键] as Dictionary
		if int(录.get("类型", -1)) == 类型:
			var 止于 := int(录.get("止于", -1))
			return maxi(0, 止于 - Time.get_ticks_msec()) if 止于 >= 0 else -1
	return -1


## `PicTool.getSkillPic(id)` / `getPetSkillPic(id)` 的对应物：技能表里那条的 `icon`。
## 招号 < 1000 走宠物招那一套（原版 `applyOtherPlayerBuff:378` `_loc5_ = _loc4_ < 1000`）。
## ⚠ 宠物招那 33 张图**不在** `数据/技能素材索引.json` 里（现查：`PetSkill` 关键字 0 命中），
## 但图在盘上（`素材/技能/PetSkill/<号>/…_icon.png`，33 个目录）⇒ 只能按那张表的命名式取路径。
static func _取图(招号: int, 是宠物招: bool) -> Texture2D:
	var 路 := ""
	if 是宠物招:
		路 = 宠物招图标路(招号)
	else:
		var 录 := GAME_DATA.skill(招号)
		if 录.is_empty():
			录 = GAME_DATA.skill(str(招号).pad_zeros(7))
		路 = String(录.get("icon", ""))
	if 路 == "" or not ResourceLoader.exists(路):
		return null
	return load(路) as Texture2D


## 宠物招图标的完整路径（拼一次、门里也读这一条，别在别处再写第二份式子）。
static func 宠物招图标路(招号: int) -> String:
	return "res://素材/技能/PetSkill/%d/Skill_PetSkill_%d.swf_1_Skill_PetSkill_%d_icon.png" % [招号, 招号, 招号]
