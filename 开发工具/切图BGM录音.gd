extends Node

## A1 交付物之一：**切图 → BGM 跟着变** 的实机录音。
##
## `移植模块清单.md` §A1 要求"录一段切图 → BGM 跟着变的屏"。这里录的是**声音本身**
## （`测试/输出/切图BGM.wav`）而不是屏幕 —— 对音频而言波形比截图更硬：两条曲子接在
## 一个文件里，前半是 A 图的曲子、后半是 B 图的曲子，中间那一下换轨就是切图那一刻。
##
## 跑法（同 `音频自检`：必须带窗口、必须 `--scene`）：
##   godot --path . --scene res://测试/音频/切图BGM录音.tscn

const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")
const 输出目录 := "res://测试/输出"
const 每段帧数 := 240
const 自检音量 := 0.9

var _帧 := 0
var _音 = null
var _录音: AudioEffectRecord = null
var _阶段 := "起A"
var _起帧 := 0
var _切换帧 := 0
var _段A := PackedByteArray()
var _段B := PackedByteArray()
var _图A := ""
var _图B := ""
var _曲A := ""
var _曲B := ""
var _已收 := false


func _ready() -> void:
	_音 = get_node_or_null("/root/AudioDirector")
	if _音 == null:
		push_error("自动加载 AudioDirector 没注册")
		get_tree().quit(1)
		return
	_录音 = AudioEffectRecord.new()
	_录音.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _录音, 0)
	var 表 := _两张不同的图()
	_图A = String(表[0])
	_图B = String(表[1])
	_音.call("_apply_settings", {
		"music_volume": 自检音量, "sound_volume": 自检音量,
		"mute_music": false, "mute_sound": false})
	print("切图录音：A 图=", _图A, " B 图=", _图B)


func _process(_delta: float) -> void:
	_帧 += 1
	match _阶段:
		"起A":
			_音.call("on_map_ready", _图A)
			_曲A = String(_音.get("_上一首"))
			_录音.set_recording_active(true)
			_起帧 = _帧
			_阶段 = "录A"
			print("   A 段：曲=", _曲A, " 路径=", _音.get("_bgm路径"))
		"录A":
			if _帧 - _起帧 >= 每段帧数:
				_录音.set_recording_active(false)
				_段A = _取样()
				_切换帧 = _帧
				_阶段 = "切B"
		"切B":
			# 切图之间留几帧，让上一首彻底停掉，换轨那一下在波形上是干净的一刀。
			if _帧 - _切换帧 >= 12:
				_音.call("on_map_ready", _图B)
				_曲B = String(_音.get("_上一首"))
				_录音.set_recording_active(true)
				_起帧 = _帧
				_阶段 = "录B"
				print("   B 段：曲=", _曲B, " 路径=", _音.get("_bgm路径"))
		"录B":
			if _帧 - _起帧 >= 每段帧数:
				_录音.set_recording_active(false)
				_段B = _取样()
				_阶段 = "完"
		"完":
			if not _已收:
				_已收 = true
				_收尾()


func _取样() -> PackedByteArray:
	var 录: AudioStreamWAV = _录音.get_recording()
	return 录.data if 录 != null else PackedByteArray()


## 找两张 `info.bgm` 声明值不同的图 —— 只有声明不同，原版才会选到不同的曲子。
func _两张不同的图() -> Array:
	var 首 := ""
	var 首值 := ""
	for 图 in MAP_RESOURCES.map_ids():
		var 声明 = (MAP_RESOURCES.map_data(图).get("info", {}) as Dictionary).get("bgm", "")
		if 首 == "" and str(声明) != "" and str(声明) != "<null>":
			首 = 图
			首值 = str(声明)
			continue
		if 首 != "" and str(声明) != "" and str(声明) != "<null>" and str(声明) != 首值:
			return [首, 图]
	return [首, ""]


func _收尾() -> void:
	var 全部 := PackedByteArray()
	全部.append_array(_段A)
	全部.append_array(_段B)
	print("   A 段字节=", _段A.size(), " 峰值=", _峰值(_段A), " 逐 0.5s=", " ".join(_逐窗(_段A)))
	print("   B 段字节=", _段B.size(), " 峰值=", _峰值(_段B), " 逐 0.5s=", " ".join(_逐窗(_段B)))
	var 流 := AudioStreamWAV.new()
	流.format = AudioStreamWAV.FORMAT_16_BITS
	流.mix_rate = 48000
	流.stereo = true
	流.set_data(全部)
	DirAccess.make_dir_recursive_absolute(输出目录)
	var 目标 := 输出目录.path_join("切图BGM.wav")
	var 错 := 流.save_to_wav(目标)
	AudioServer.remove_bus_effect(0, 0)
	if 错 != OK:
		push_error("切图录音写不出去：%s（%s）" % [目标, error_string(错)])
		get_tree().quit(1)
		return
	var 秒 := float(全部.size()) / 2.0 / 2.0 / 48000.0
	var 换轨 := _曲A != _曲B
	print("已存：%s（%.1f 秒；A=%s → B=%s，%s）" % [
		目标, 秒, _曲A, _曲B, "换了曲" if 换轨 else "两段同曲（不算证据）"])
	get_tree().quit(0 if 换轨 else 2)


func _峰值(样本: PackedByteArray) -> int:
	var 峰 := 0
	for i in range(0, 样本.size() - 1, 2):
		峰 = maxi(峰, absi(int(样本.decode_s16(i))))
	return 峰


func _逐窗(样本: PackedByteArray, 上限 := 12) -> Array[String]:
	var 出: Array[String] = []
	var 窗 := 96000
	var i := 0
	while i < 样本.size() and 出.size() < 上限:
		出.append(str(_峰值(样本.slice(i, mini(i + 窗, 样本.size())))))
		i += 窗
	return 出
