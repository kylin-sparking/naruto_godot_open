extends Node2D
class_name OriginalSprite

signal visual_bounds_changed

const 资源解析 := preload("res://脚本/单例/资源解析.gd")

const METADATA_PATH := "res://数据/角色/动画元数据.json"
const ASSET_INDEX_PATH := "res://数据/角色/动画素材索引.json"
const SPRITE_DIR := "res://素材/角色动画"

static var _metadata: Dictionary = {}
static var _怪物头像表: Dictionary = {}
const 怪物头像表路径 := "res://数据/角色/怪物头像.json"
static var _asset_index: Dictionary = {}
static var _texture_cache: Dictionary = {}

static func has_animation(kind: String, id: String) -> bool:
	_ensure_metadata()
	return not (_metadata.get(kind, {}).get(id, {}) as Dictionary).is_empty()

## 头像贴图。原版三条来源（`PortraitHead.as:130-160` 的 `skin` setter）：
##   角色 `M_Char[id].info.portrait`、NPC `PicTool.getNPCObject(id).info.portrait`、
##   怪物 `PicTool.getMonsterObject(id).info.portrait` —— 三处都是 `<前缀>_<id>_info_portrait` 这个类名。
## ⚠️ 怪物那一档**目前恒为 null**：`Mob_*_info_portrait` 这张图一个都没导出（素材树里 0 个），
##    元数据也被 `导入怪物动画.mjs` 把 `info` 一起过滤掉了。目标信息框的怪物头像因此是空的。
static func portrait(kind: String, id: String) -> Texture2D:
	if kind == "mob":
		return _怪物头像(id)
	var prefix := ""
	match kind:
		"npc": prefix = "Npc"
		"character": prefix = "Char"
		"pet": prefix = "Pet"
	if prefix.is_empty():
		return null
	return _get_texture("%s_%s_info_portrait" % [prefix, id])

## 怪物头像。原版 `DetailsWindow.setPic()` 的 type 0 分支：
## `PortraitHead(TYPE_MONSTER)` → `PicTool.getMonsterObject(id).info.portrait` ——
## 类名是 `Mob_<id>_info_portrait`，原版客户端里**每个怪一份专门的库**
## （`www/act_web_nya_208_isolated/swf/Mob/Mob_<id>_info_portrait.swf`）。
## 图由 `开发工具/导出怪物头像.py` 解到 `素材/原版直解/Mob/`，表在 `数据/角色/怪物头像.json`。
## ⚠️ 文件名口径沿用直解包：`<类名>.swf_1_<类名>.png`。
static func _怪物头像(id: String) -> Texture2D:
	if _怪物头像表.is_empty():
		var file := FileAccess.open(怪物头像表路径, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text().trim_prefix("﻿"))
			if parsed is Dictionary:
				_怪物头像表 = parsed
	var 条目 = _怪物头像表.get(str(int(id)) if str(id).is_valid_int() else id, null)
	if not 条目 is Dictionary:
		return null
	var 类名 := String((条目 as Dictionary).get("class", ""))
	if 类名.is_empty():
		return null
	return _怪物头像纹理(类名)

static func _怪物头像纹理(类名: String) -> Texture2D:
	if _texture_cache.has(类名):
		return _texture_cache[类名]
	var 路径 := "res://素材/原版直解/Mob/%s.swf_1_%s.png" % [类名, 类名]
	if not ResourceLoader.exists(路径):
		return null
	var tex = load(路径)
	if tex is Texture2D:
		_texture_cache[类名] = tex
		return tex
	return null

var sprite := Sprite2D.new()
var actions: Dictionary = {}
var action := ""
var frame_index := 0
var elapsed_ms := 0.0
## 停住不动：冻在当前帧不再推进。爬梯/爬绳不动时用（原版这时不循环播攀爬动画）。
var paused := false
## 单次动作：播到尾帧就停住，不回头（原版 `_toLoopThisAction == false`）。
var 单次 := false
var flip_h := false:
	set(value):
		flip_h = value
		scale.x = -1.0 if value else 1.0

## 原版有**两套**默认朝向，别用一套通吃（2026-09-27 修）：
##   · 基类 `Animation.as:55-66`（怪物 / NPC / 宠物 / 旗帜）：`LEFT → scaleX = 1`，**美术朝左**；
##   · `CharacterSprite.as:1718-1732` 覆盖（玩家 / 远程玩家）：`LEFT → scaleX = -1`，**美术朝右**。
## 我们原来到处写 `flip_h = 方向 < 0` —— 对角色是对的，对怪物/NPC 正好**左右颠倒**；
## 而且每帧 origin 是注册点（会随攻击前冲而变），镜像反了之后那点前冲也跟着反向，
## 看着就像"轨迹画反了/贴图没跟着走"。
var 左向美术 := true
## `configure()` 用的那一档（character / npc / mob / pet）。
## 要存下来，因为**人物帧没有逐帧体型盒**（见 `当前身体矩形()`），命中那一侧得靠它分辨
## "这具是穿人物皮的"，才能改走原版角色的常量体型盒。
var 造型类别 := ""

## 原版**动作号 ↔ 动作名**的唯一一张表：`com/mxw/roles/enums/Action.as:6`
## `ActionName = [null,"stand","jump","walk","ladder","rope","alert","sit0","sit1","hit","dead","attack","stab1","stab2","stab3"]`
## —— 移动包(187)的动作槽与出招包(1328)的 stance 槽用的都是这一套号（`AbstractAttackSkill.as:610-613`
## 出招时 `character.setMovementAction(useStance)` 并把同一个号写进 `createSkillMsg`）。
const 动作号表 := ["", "stand", "jump", "walk", "ladder", "rope", "alert", "sit0",
		"sit1", "hit", "dead", "attack", "stab1", "stab2", "stab3"]

## 号 → 名；越界或 0（服务端自己发的广播在 stance 槽补 0）一律回空串，由调用方兜。
static func 动作名(号: int) -> String:
	if 号 > 0 and 号 < 动作号表.size():
		return 动作号表[号]
	return ""

## 名 → 号（找不到回 0）。
static func 动作号(名: String) -> int:
	return 动作号表.find(名)

func _ready() -> void:
	sprite.centered = false
	add_child(sprite)

func configure(kind: String, id: String, initial_action: String) -> bool:
	_ensure_metadata()
	actions = _metadata.get(kind, {}).get(id, {})
	if actions.is_empty():
		return false
	造型类别 = kind
	左向美术 = kind != "character"
	play(initial_action, true)
	return not action.is_empty()

## 角色自己的**立绘**（人物窗口里那具站着的身体）：与身体、头像是同一个 face 号。
## 原版 `CharacterHandler.as:303` 的 `charWindow.setMyImgChar(...)` 走的就是这一档。
static func 角色立绘(号: String) -> Texture2D:
	return _get_texture("Char_%s_stand_0_body" % 号)


## 按原版语义朝某个方向。`方向` 取 -1(左) / +1(右) —— 与 `后端连接` 解析原始包时
## 折出来的口径一致（移动包看 `速度x` 的正负，没给就按位移推；见 `_handle_move_player_text`）。
func set_direction(方向: int) -> void:
	if 方向 == 0:
		return
	var 朝右 := 方向 > 0
	if 左向美术:
		scale.x = -1.0 if 朝右 else 1.0
	else:
		scale.x = 1.0 if 朝右 else -1.0

## 当前帧在 PNG 里的注册点（`CharacterItem.as:53-60` 的 `bmp.x = -origin.x`）。
## 会随帧变 —— 怪物血条的竖直位置就挂在它上面（`Monster.as:840` 的 `mobBmdHeight`）。
func 当前原点() -> Vector2:
	var origin: Dictionary = _当前视觉().get("origin", {})
	return Vector2(float(origin.get("x", 0)), float(origin.get("y", 0)))

## 这个角色美术本体朝左还是朝右（-1 / +1），供调用方换算"世界里的朝向"用。
func 美术朝向() -> int:
	return -1 if 左向美术 else 1

func _当前视觉() -> Dictionary:
	var frame: Dictionary = actions.get(action, {}).get(str(frame_index), {})
	if frame.has("body"):
		return frame.body
	return frame

## 播一次、停在最后一帧（不回头）。原版角色的 attack / hit / dead 都是这个语义：
## `Animation.as:127-160` 里 `_toLoopThisAction == false` 时到尾帧就 `_isPlaying = false`，
## 再由 `AbstractLifeObject.tickStance():194-200` 在 `actionEnd()` 那一刻把 stance 复位。
## 返回**是否真的播起来了** —— 调用方要用它决定"要不要进入出招状态"，
## 否则动作名不存在时会卡在"自以为在出招、动作已播完永远为假"的死状态里。
## 怪物与角色是**两张动作词表**（`数据/角色/动画元数据.json` 现查：
## mob = `attack1/die1/hit1/move/stand`，character = `alert/attack/dead/hit/info/jump/ladder/
## rope/sit0/sit1/stab1/stab2/stab3/stand/walk`）。竞技场的对手按服务端是**一只权威怪**
## （走的正是 `move/attack1/hit1/die1` 这一套帧），身体却按玩家画 ⇒ 在**精灵这一层**翻译一次。
## 只在"这套美术里没有这个名字"时才翻 ⇒ 真怪物六个名字都有，一条都不受影响。
const 动作别名 := {"move": "walk", "attack1": "attack", "hit1": "hit", "die1": "dead"}


## 把要播的动作名解成这套美术**真的拥有**的那个名字（翻不到就原样返回，调用方自己判有没有）。
func _动作名(要播: String) -> String:
	if actions.has(要播):
		return 要播
	var 替 := String(动作别名.get(要播, ""))
	return 替 if (not 替.is_empty() and actions.has(替)) else 要播


func play_once(next_action: String) -> bool:
	next_action = _动作名(next_action)
	if not actions.has(next_action):
		return false
	paused = false
	单次 = true
	action = next_action
	frame_index = 0
	elapsed_ms = 0.0
	_apply_frame()
	return true

## 这套美术有没有这个动作名（原版 `allActions` 那套）。
func 有动作(要查的动作: String) -> bool:
	return actions.has(_动作名(要查的动作))

## 单次动作是否已经播到尾帧（对应原版 `actionEnd()`）。
func 动作已播完() -> bool:
	if not 单次:
		return false
	var frames: Dictionary = actions.get(action, {})
	return frames.is_empty() or frame_index >= frames.size() - 1

## 某个动作的完整时长（毫秒）——原版同一条时间轴由每帧 delay 累加而来。
func 动作时长毫秒(要查的动作: String) -> int:
	var frames: Dictionary = actions.get(_动作名(要查的动作), {})
	var 合计 := 0
	for frame in frames.values():
		合计 += int((frame as Dictionary).get("delay", 100))
	return 合计

## 当前帧贴图的高度 —— 原版人物的伤害数字锚点就是这个（`Character.as:1275` 的 `_crtCharHeight`）。
func 当前贴图高度() -> float:
	if sprite.texture == null:
		return 0.0
	return float(sprite.texture.get_height())

## 当前帧的身体矩形（相对注册点）——`MonsterSprite.calculateFrameData():255-266`：
##   `_bodyRect = Rectangle(lt.x, lt.y, rb.x, rb.y)`
## 原版拿它当命中盒（`Character.outerBodyRect`：朝右时水平镜像后再平移到角色坐标）。
## 帧里没有 lt/rb 时返回空矩形（人物帧就没有这两个字段）。
func 当前身体矩形() -> Rect2:
	var frame: Dictionary = actions.get(action, {}).get(str(frame_index), {})
	if not frame.has("lt") or not frame.has("rb"):
		return Rect2()
	var lt: Dictionary = frame.get("lt")
	var rb: Dictionary = frame.get("rb")
	var 左 := float(lt.get("x", 0))
	var 上 := float(lt.get("y", 0))
	return Rect2(左, 上, float(rb.get("x", 0)) - 左, float(rb.get("y", 0)) - 上)

## 停在某个动作的第 0 帧。爬梯/爬绳**不动**时用 —— 一直循环播攀爬动画是错的。
func hold_first_frame(next_action: String) -> void:
	if action != next_action:
		play(next_action, true)
	frame_index = 0
	elapsed_ms = 0.0
	paused = true
	_apply_frame()

func play(next_action: String, force := false) -> void:
	next_action = _动作名(next_action)
	paused = false
	单次 = false
	if not force and action == next_action:
		return
	if not actions.has(next_action):
		return
	action = next_action
	frame_index = 0
	elapsed_ms = 0.0
	_apply_frame()

func play_state(next_action: String) -> void:
	play(next_action)


## 直接把某动作的某帧摆出来、并且**自己不再推进**。
## 灵器外观跟身体同帧时需要它：原版 `CharacterSprite.reanderLingQi` 每帧读的正是
## 身体的 `_action` / `_frame`（没有独立时间轴），缺那一帧时**保留上一张**、不退回 stand。
## 返回是否摆上了；调用方拿 false 时别动当前画面。
func 显示帧(next_action: String, next_frame: int) -> bool:
	var frames: Dictionary = actions.get(next_action, {})
	if frames.is_empty() or next_frame < 0 or next_frame >= frames.size():
		return false
	paused = true
	单次 = false
	action = next_action
	frame_index = next_frame
	elapsed_ms = 0.0
	_apply_frame()
	return true

func _process(delta: float) -> void:
	if paused or action.is_empty():
		return
	var frames: Dictionary = actions.get(action, {})
	if frames.is_empty():
		return
	var frame: Dictionary = frames.get(str(frame_index), {})
	var delay := maxf(1.0, float(frame.get("delay", 100)))
	elapsed_ms += delta * 1000.0
	while elapsed_ms > delay:
		elapsed_ms -= delay
		if 单次 and frame_index >= frames.size() - 1:
			# 原版单次动作到尾帧就停住（`Animation.as:125-131` 的 `_isPlaying = false`），
			# 停在最后一帧等 `tickStance()` 复位，不回头。
			paused = true
			return
		frame_index = (frame_index + 1) % frames.size()
		_apply_frame()
		frame = frames.get(str(frame_index), {})
		delay = maxf(1.0, float(frame.get("delay", 100)))

func _apply_frame() -> void:
	var visual := _当前视觉()
	var value: Dictionary = visual.get("value", {})
	var class_name_value := String(value.get("className", ""))
	var texture := _get_texture(class_name_value)
	if texture == null:
		return
	var origin: Dictionary = visual.get("origin", {})
	sprite.texture = texture
	sprite.position = Vector2(-float(origin.get("x", 0)), -float(origin.get("y", 0)))
	visual_bounds_changed.emit()

static func _ensure_metadata() -> void:
	if not _metadata.is_empty():
		return
	var file := FileAccess.open(METADATA_PATH, FileAccess.READ)
	if file == null:
		push_error("OriginalSprite: missing " + METADATA_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_metadata = parsed

static func _ensure_asset_index() -> void:
	if not _asset_index.is_empty():
		return
	var file := FileAccess.open(ASSET_INDEX_PATH, FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text().trim_prefix("\ufeff"))
		if parsed is Dictionary:
			_asset_index = parsed
			return
	_index_directory(SPRITE_DIR)

static func _index_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_index_directory(path.path_join(file_name))
		elif file_name.ends_with(".png"):
			var marker := file_name.find("_Char_")
			if marker < 0:
				marker = file_name.find("_Npc_")
			if marker < 0:
				marker = file_name.find("_Mob_")
			if marker < 0:
				marker = file_name.find("_Pet_")
			if marker >= 0:
				var class_name_value := file_name.substr(marker + 1, file_name.length() - marker - 5)
				_asset_index[class_name_value] = path.path_join(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

static func _get_texture(class_name_value: String) -> Texture2D:
	if class_name_value.is_empty():
		return null
	if _texture_cache.has(class_name_value):
		return _texture_cache[class_name_value]
	_ensure_asset_index()
	var resource_path := 资源解析.解析(String(_asset_index.get(class_name_value, "")))
	if resource_path.is_empty():
		return null
	var texture = load(resource_path)
	if texture is Texture2D:
		_texture_cache[class_name_value] = texture
		return texture
	return null
