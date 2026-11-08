extends Node2D
class_name EffectPlayer

## 原版特效播放器：形态、帧间隔、原点、循环/单次全部读 数据/特效.json，脚本里不写死任何数字。
## 表由 开发工具/导出特效与图标.mjs 从 GameData.dat.json + 原版 AS3 播放代码生成。
##
## 三种形态（真值各不同）：
##   · 逐帧位图   Etc.effects —— 每帧一张独立 Bitmap，帧间隔读该帧的 delay（缺省 100ms，FrameQueueAnimation.as:119）
##   · swf 时间轴 Etc.mcEffect / MCFromDatDefine 前缀链 —— 定长 每帧ms（1000/fps，MCFromDatDefine.as:37）
##   · 静态图标   frameCount=1 —— 取模恒为 1，原版只钉第 1 帧（MCFromDatDefine.as:183），所以不推进
##
## 播完行为：单次特效到尾帧**停住不回头**（Animation.as:125-131 + MCFromDatDefine.as:184-195 的 once→pause）；
## 循环特效到尾帧回第 0 帧（Animation.as:133-144 的 gotoAndStop(0)）。
## 原点：贴图位置 = -origin（CharacterItem.as:53-60 / ByteArrayImage.as:100-105）。

const EFFECTS_PATH := "res://数据/特效.json"

static var _entries: Dictionary = {}
static var _texture_cache: Dictionary = {}

signal finished

var entry_name := ""
var entry: Dictionary = {}
var frames: Array = []
var frame_index := 0
var elapsed_ms := 0.0
var paused := false
var single_shot := false
var done := false
var flip_h := false

var _sprite := Sprite2D.new()
var _form := ""
var _frame_ms := 10.0

func _ready() -> void:
	_ensure_entries()
	_sprite.centered = false
	add_child(_sprite)
	if not entry.is_empty():
		play(entry_name)

## 载入并播放一个特效；表里没有这个键返回 false（调用方决定退回什么，这里不猜）。
func play(next_name: String) -> bool:
	_ensure_entries()
	var definition: Dictionary = _entries.get(next_name, {})
	if definition.is_empty():
		push_warning("EffectPlayer: 数据/特效.json 里没有 " + next_name)
		return false
	entry = definition
	entry_name = next_name
	frames = definition.get("帧", [])
	_form = String(definition.get("形态", ""))
	single_shot = bool(definition.get("播法", {}).get("单次", false)) if definition.has("播法") else false
	_frame_ms = maxf(1.0, float(definition.get("播法", {}).get("每帧ms", 10.0))) if definition.has("播法") else 10.0
	frame_index = 0
	elapsed_ms = 0.0
	done = false
	paused = false
	_apply_frame()
	return not frames.is_empty()

## 钉在某一帧不推进 —— 原版伤害数字就是这种用法（ColorNumber.as:62-66 只设 frame，从不 tick）。
func hold(frame: int) -> void:
	single_shot = true
	paused = true
	frame_index = clampi(frame, 0, frames.size() - 1)
	_apply_frame()

func _process(delta: float) -> void:
	if paused or frames.size() < 2 or _form == "静态图标":
		return
	elapsed_ms += delta * 1000.0
	if _form == "逐帧位图":
		# FrameQueueAnimation/Animation.as:116-160：每帧带自己的 delay，超了就进下一帧，循环回 0
		var delay := _current_delay()
		var changed := false
		while elapsed_ms > delay:
			elapsed_ms -= delay
			if frame_index + 1 >= frames.size():
				if single_shot:
					paused = true
					done = true
					finished.emit()
					break
				frame_index = 0
			else:
				frame_index += 1
			changed = true
			delay = _current_delay()
		if changed:
			_apply_frame()
		return
	# MCFromDatDefine.as:183：frame = 累计ms / 每帧ms % frameCount + 1 —— **按时间取模**，不是逐 tick 累加。
	# 所以哪怕屏幕 60fps、每帧 10ms，抽到的帧也和原版同一时刻抽到的一样（这才是"不丢帧"的判据）。
	var total := frames.size() * _frame_ms
	if single_shot and elapsed_ms > total:
		# MCFromDatDefine.as:184-195：once → 走完就 pause，停在最后一帧不回头
		frame_index = frames.size() - 1
		_apply_frame()
		paused = true
		done = true
		finished.emit()
		return
	var next_index := int(elapsed_ms / _frame_ms) % frames.size()
	if next_index != frame_index:
		frame_index = next_index
		_apply_frame()

func _current_delay() -> float:
	if _form == "逐帧位图":
		return maxf(1.0, float(frames[frame_index].get("停留ms", 100)))
	return _frame_ms

func _apply_frame() -> void:
	var frame: Dictionary = frames[frame_index]
	var path := String(frame.get("贴图", ""))
	if path.is_empty():
		# 空帧：原版这一帧只有 delay、不画东西（如 maiTong* 末尾那 10 秒），不是缺图
		_sprite.visible = false
		return
	var texture := _texture(path)
	if texture == null:
		_sprite.visible = false
		return
	var origin: Array = frame.get("原点", [0, 0])
	_sprite.visible = true
	_sprite.texture = texture
	_sprite.position = Vector2(-float(origin[0]), -float(origin[1]))
	_sprite.scale.x = -1.0 if flip_h else 1.0

## 原版 direction：LEFT→scaleX 1，RIGHT→scaleX -1（MCFromDatDefine.as:76-88）。特效跟着人物朝向翻转时调用。
func set_flip_h(value: bool) -> void:
	flip_h = value
	_apply_frame()

static func has_effect(effect_name: String) -> bool:
	_ensure_entries()
	return _entries.has(effect_name)

static func frame_count_of(effect_name: String) -> int:
	_ensure_entries()
	return (_entries.get(effect_name, {}) as Dictionary).get("帧", []).size()

static var _loaded := false

static func _ensure_entries() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(EFFECTS_PATH, FileAccess.READ)
	if file == null:
		push_error("EffectPlayer: cannot read " + EFFECTS_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text().trim_prefix("\ufeff"))
	if typeof(parsed) == TYPE_DICTIONARY:
		_entries = parsed.get("特效", {})

func _texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var loaded = load(path)
	if loaded is Texture2D:
		_texture_cache[path] = loaded
		return loaded
	push_error("EffectPlayer: 贴图读不出来 " + path)
	return null
