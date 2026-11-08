extends Node2D

const 资源解析 := preload("res://脚本/单例/资源解析.gd")

const METADATA_PATH := "res://数据/技能动画元数据.json"
const INDEX_PATH := "res://数据/技能素材索引.json"

static var _metadata: Dictionary = {}
static var _index: Dictionary = {}
static var _textures: Dictionary = {}

## 循环播（飞行物用：原版 `createBall()` 里 `new FrameQueueAnimation(true)`）。
## 注意**默认是 false** —— 施法/命中特效都是单次播完就消失。
var 循环 := false
var _sprite := Sprite2D.new()
var _frames: Array[Dictionary] = []
var _frame_index := 0
var _elapsed_ms := 0.0

func _ready() -> void:
	_sprite.centered = false
	add_child(_sprite)

func configure(skill_id: String, phase := "effect") -> bool:
	_ensure_data()
	var definition: Dictionary = _metadata.get(skill_id, {})
	if definition.is_empty():
		return false
	var frame_set = definition.get(phase, {})
	if phase == "hit" or (frame_set is Dictionary and not _is_frame_set(frame_set)):
		frame_set = _first_frame_set(frame_set)
	if not frame_set is Dictionary or frame_set.is_empty():
		frame_set = _first_frame_set(definition.get("hit", {}))
	if not frame_set is Dictionary or frame_set.is_empty():
		return false
	_frames.clear()
	var keys := (frame_set as Dictionary).keys()
	keys.sort_custom(func(left, right): return int(left) < int(right))
	for key in keys:
		var frame = frame_set[key]
		if frame is Dictionary:
			_frames.append(frame)
	if _frames.is_empty():
		return false
	_apply_frame()
	return true

func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	_elapsed_ms += delta * 1000.0
	var delay := maxf(1.0, float(_frames[_frame_index].get("delay", 80)))
	if _elapsed_ms < delay:
		return
	_elapsed_ms -= delay
	_frame_index += 1
	if _frame_index >= _frames.size():
		if 循环:
			_frame_index = 0
		else:
			queue_free()
			return
	_apply_frame()

## 特效美术的朝向口径：**和怪物 / NPC / 宠物一样"默认朝左"**。
## 依据（十几处全是同一个式子，`LEFT → scaleX = 1`）：
##   `AbstractThrowSkillEffect.as:33/103`、`BuffSkillEffect.as:43`、`CoupleSkillEffect.as:54`、
##   `MonsterAttackEffect.as:94/98`、`PetBuffEffect.as:41`、`PetThrowSkillEffect.as:69/77/221`。
## 原来施法时给的是 `scale.x = facing`（右→1），**正好反了** —— 用户 2026-09-27 实机报的"特效反向"。
## （`AbstractCloseAttackEffect.as:162-165` 那处 `LEFT?1:-1` 后面还挂了一句
##  `if(getReverseEffectDirection(skillId) != 0) scaleX *= -1`，而那个字段在 GameData 里**根本不存在**，
##  AS3 里 `null != 0` 恒为真 —— 那是原版自己的一处隐患；同族的投掷/宠物/Buff 特效都没有这一下，
##  以它们为准。）
func set_direction(方向: int) -> void:
	if 方向 == 0:
		return
	scale.x = -1.0 if 方向 > 0 else 1.0

func _apply_frame() -> void:
	var frame := _frames[_frame_index]
	var class_name_value := String((frame.get("value", {}) as Dictionary).get("className", ""))
	var texture := _texture(class_name_value)
	if texture == null:
		return
	var origin: Dictionary = frame.get("origin", {})
	_sprite.texture = texture
	_sprite.position = Vector2(-float(origin.get("x", 0)), -float(origin.get("y", 0)))
	z_index = 3000 + int(frame.get("z", 0))

## 这个技能有没有某个相位（`effect` / `ball` / `hit` …）。飞行物要先问一句再建。
static func 有相位(skill_id: String, phase: String) -> bool:
	_ensure_data()
	return (_metadata.get(skill_id, {}) as Dictionary).has(phase)

## 相位的整型参数。`ball` 那一份里除了逐帧数据还挂着 **`ballAfter`**
## （`AbstractThrowSkillEffect.canBallAppear()` 读它），取的就是它。
static func 相位参数(skill_id: String, phase: String, 键: String, 默认 := 0) -> int:
	_ensure_data()
	var 相位 = (_metadata.get(skill_id, {}) as Dictionary).get(phase, {})
	if 相位 is Dictionary:
		return int((相位 as Dictionary).get(键, 默认))
	return 默认

static func _ensure_data() -> void:
	if _metadata.is_empty():
		_metadata = _read_dictionary(METADATA_PATH)
	if _index.is_empty():
		_index = _read_dictionary(INDEX_PATH)

static func _read_dictionary(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path).trim_prefix("\ufeff"))
	return parsed if parsed is Dictionary else {}

static func _texture(class_name_value: String) -> Texture2D:
	if _textures.has(class_name_value):
		return _textures[class_name_value]
	var path := 资源解析.解析(String(_index.get(class_name_value, "")))
	var texture := load(path) as Texture2D if ResourceLoader.exists(path) else null
	if texture != null:
		_textures[class_name_value] = texture
	return texture

static func _is_frame_set(value: Dictionary) -> bool:
	for frame in value.values():
		if frame is Dictionary and (frame as Dictionary).has("value"):
			return true
	return false

static func _first_frame_set(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	if _is_frame_set(value):
		return value
	for child in value.values():
		var result := _first_frame_set(child)
		if not result.is_empty():
			return result
	return {}
