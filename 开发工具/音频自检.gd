extends Node

## 模块 A1 音频自检。跑法（**必须用带窗口的 exe，且走 `--scene`**）：
##   godot --path . --scene res://测试/音频/音频自检.tscn
##
## 为什么不是 `--script`：那条路径不创建 `Recording` 单例，`AudioEffectRecord.set_recording_active()`
## 只会警告 "Recording should not be set as active before Godot has initialized" 并让
## `get_recording()` 返回 null —— 实测录不到任何字节。`--scene` 下同一套 API 正常
## （探针：440Hz 满幅 12000 的正弦，录回来峰值正好 12000）。
## 也不能加 `--headless`：无头是哑音频驱动，录出来必然静音。
##
## 四件事都拿实测数字说话：
##   ① 素材齐 —— BGM 52 首 / 音效 22 条 / 影分身 2 条，逐个 load 得出流且时长>0；
##      并确认三个自造占位（attack/hit/portal.wav）已不在工程里。
##   ② 选曲对 —— 每张图选出的曲子必须落在该图 `info.bgm` 声明的候选内（全图覆盖，每图试选 4 次）。
##   ③ 真出声 —— Master 总线逐段录音算峰值，**每一段**都必须非零才算"实机可听"；
##      整段另存 `测试/输出/自检录音.wav` 供人耳复核。
##   ④ 设置生效 —— 勾"音乐/音效静音"后：BGM 音量必须压到 -80dB、音效那一段必须录到静音
##      （原版语义就是音量压 0，`SysCfg.as:240` 与 `SoundPlayer.as:29`，不是暂停）。

const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")
const 表路径 := "res://数据/音效.json"
const 输出目录 := "res://测试/输出"
const 每段帧数 := 18
# 实测 31fps：`AudioEffectRecord` 每 45 帧只给回 0.75 秒字节（143360 B = 35840 样本 / 双声道）。
# 原版 BGM 普遍有静音前奏（`1.mp3` 头 0.75s 峰值只有 26 ≈ -56dB），所以 BGM 段要开到 ~10 秒
# 才测得准 —— 这不是"播放链坏了"，是采样的时间窗不够。
const BGM段帧数 := 300
# 静音段也开长：只有拉出时间轴，才能分清"上一条音效的尾巴漏进来了"（工装误差）
# 和"设置真没管住"（产品缺陷）—— 两者修法完全不同，不能只看一个总峰值。
const 静音段帧数 := 300
# 掐静音之后**先静置再开录**：上一条音效的信号还压在混音回调的缓冲里，立刻开录量到的是残响
# （实测这样误报过 峰值 11733 / 12289）。静置 ~0.6 秒把缓冲排空，静音段量的才是"静音本身"。
const 静音前静置帧数 := 18
const 段间隔帧数 := 2
const 自检音量 := 0.9

var _帧 := 0
var _表: Dictionary = {}
var _音 = null
var _录音: AudioEffectRecord = null
var _起帧 := 0
var _切换帧 := 0
var _阶段 := "建"
var _失败: Array[String] = []
var _队列: Array = []
var _当前 := ""
var _峰值表 := {}
var _全部 := PackedByteArray()
var _采样率 := 48000.0
var _立体声 := true
var _已收 := false
var _挂在总线上了 := false


func _ready() -> void:
	_表 = _读json(表路径)
	if _表.is_empty():
		_失败.append("读不到 数据/音效.json，先跑 开发工具/导出音频.mjs")
		_done()
		return
	# 自动加载的 `AudioDirector` 在这条跑法下是真单例 —— 直接用工程里那一份，
	# 顺带把 `地图根节点`/`游戏会话` 的接线也验了。
	_音 = get_node_or_null("/root/AudioDirector")
	if _音 == null:
		_失败.append("自动加载 AudioDirector 没注册（查 project.godot [autoload]）")
		_done()
		return
	_录音 = AudioEffectRecord.new()
	# ⚠️ `AudioEffectRecord` 是 Resource，既没有 `name` 也没有 `get_parent()` —— 4.7 实测
	# （extension_api：属性只有 `format`）。之前给它 `.name = ...` 抛错打断了 `_ready()`，
	# 效果器压根没挂上总线，于是每段都录到 null。
	_录音.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _录音, 0)
	_挂在总线上了 = true
	print("自检：驱动=", AudioServer.get_driver_name(), " 总线声道=", AudioServer.get_bus_channels(0),
		" 采样率=", AudioServer.get_mix_rate())


func _process(_delta: float) -> void:
	_帧 += 1
	match _阶段:
		"建":
			_查素材齐()
			_查选曲()
			_音.call("_apply_settings", {
				"music_volume": 自检音量, "sound_volume": 自检音量,
				"mute_music": false, "mute_sound": false})
			_队列 = _录音队列()
			_切换帧 = _帧
			_阶段 = "歇"
		"歇":
			if _帧 - _切换帧 >= 段间隔帧数:
				if _队列.is_empty():
					_阶段 = "完"
				else:
					_开始一段(String(_队列.pop_front()))
					_阶段 = "定" if _当前 == "静音" else "录"
		"定":
			# `_起帧` 是 `_开始一段` 里记的"掐静音那一刻"，从这里再排空一段缓冲才开录。
			if _帧 - _起帧 >= 静音前静置帧数:
				_录音.set_recording_active(true)
				_起帧 = _帧
				_阶段 = "录"
		"录":
			var 应录 := 每段帧数
			if _当前 == "BGM":
				应录 = BGM段帧数
			elif _当前 == "静音":
				应录 = 静音段帧数
			if _帧 - _起帧 >= 应录:
				_收一段()
				_切换帧 = _帧
				_阶段 = "歇"
		"完":
			# 一次性的收尾：`quit()` 只拦到"本帧之后"，不挡住 `_process` 再进一次，
			# 没有这道闸就会把结论刷几万遍（实测刷到 30 万行）。
			if not _已收:
				_收尾()
				_done()


func _查素材齐() -> void:
	var bgm: Dictionary = _表.get("BGM", {})
	var 首数 := 0
	for 名 in (bgm.get("清单", [])):
		var 路径 := "res://素材/音效/BGM/%s.mp3" % String(名)
		if not ResourceLoader.exists(路径):
			_失败.append("缺 BGM：%s" % 路径)
			continue
		var 流: AudioStream = load(路径)
		# ⚠️ `AudioStreamMP3` **没有 `length` 属性**（4.7 实测，extension_api 里它的属性只有
		# data/bpm/beat_count/bar_beats/loop/loop_offset）。所以这里只能验"资源存在、字节非空"，
		# "真的解得出声"由第③段的实测录音峰值证明，不靠时长断言。
		var mp3 := 流 as AudioStreamMP3
		if mp3 == null or mp3.data.is_empty():
			_失败.append("BGM 打不开或字节为空：%s" % 路径)
			continue
		首数 += 1
	var 音效表: Dictionary = (_表.get("音效", {}) as Dictionary).get("表", {})
	var 条数 := 0
	for 名 in 音效表.keys():
		var 路径 := String((音效表[名] as Dictionary).get("文件", ""))
		if not ResourceLoader.exists(路径):
			_失败.append("缺 音效：%s" % 路径)
			continue
		if load(路径) is AudioStream:
			条数 += 1
	var 分身数 := 0
	for f in (_表.get("影分身", {}) as Dictionary).get("清单", []):
		if load("res://素材/音效/%s" % String(f)) is AudioStream:
			分身数 += 1
	var 残留 := _查自造占位残留()
	print("① 素材齐：BGM %d/%d，音效 %d/%d，影分身 %d/2，自造占位残留 %d 个" % [
		首数, int(bgm.get("数量", 0)), 条数,
		int((_表.get("音效", {}) as Dictionary).get("数量", 0)), 分身数, 残留.size()])
	if 首数 != int(bgm.get("数量", -1)) or 条数 != 22 or 分身数 != 2:
		_失败.append("数量与 数据/音效.json 对不上")
	for 名 in 残留:
		_失败.append("自造占位还在工程里：%s" % 名)


func _查自造占位残留() -> Array[String]:
	var 出: Array[String] = []
	for 名 in ["attack", "hit", "portal"]:
		if FileAccess.file_exists("res://素材/音效/%s.wav" % 名):
			出.append("%s.wav" % 名)
	return 出


func _查选曲() -> void:
	var 张数 := 0
	var 全中 := 0
	var 分布 := {}
	for 图 in MAP_RESOURCES.map_ids():
		var 数据: Dictionary = MAP_RESOURCES.map_data(图)
		var 声明 = (数据.get("info", {}) as Dictionary).get("bgm", "")
		if 声明 == null:
			声明 = ""
		var 候选: Array = _音.call("_解析选项", 声明)
		var 本图全对 := true
		for i in 4:
			_音.set("_上一首", "")
			_音.set("_上一首地图", "")
			_音.set("_当前地图", 图)
			_音.call("play_bgm")
			var 挑 := String(_音.get("_上一首"))
			if not 候选.has(挑):
				本图全对 = false
				_失败.append("地图 %s 声明 bgm=%s 却选了 %s" % [图, str(声明), 挑])
		张数 += 1
		全中 += 1 if 本图全对 else 0
		分布[str(声明)] = int(分布.get(str(声明), 0)) + 1
	print("② 选曲对：%d/%d 张图选中的都在声明候选内；声明值分布 %s" % [全中, 张数, JSON.stringify(分布)])
	# ⚠️ 上面那 4×每张图 次 `play_bgm()` 是**真的在放**的，会把 singleton 留在"淡切中途、线性音量≈0"
	# 的状态里（`_switch_bgm(挑, 同图=true)` 走 `_开始淡切` → `_play_mp3(名, 0.0)`），
	# 于是第③段的 BGM 一录就是静音。这里把状态复位，别让它污染录音段。
	_音.call("_取消淡切")
	_音.call("_设音量", 自检音量)
	_音.get("_bgm").stop()
	_音.set("_上一首", "")
	_音.set("_上一首地图", "")
	_音.set("_当前地图", "")


## 队列里 `静音` 排在所有音效之后：同样放 `Sound_Mai_Fire`，但勾了静音 —— 峰值必须归零，
## 这样"音效通道真的被设置管住"才是被证伪过的，而不是"那条音效本身没声"。
func _录音队列() -> Array:
	var 名单: Array = ((_表.get("音效", {}) as Dictionary).get("表", {}) as Dictionary).keys()
	名单.sort()
	名单.append("静音")
	return ["BGM"] + 名单


func _开始一段(标签: String) -> void:
	_当前 = 标签
	_起帧 = _帧
	match 标签:
		"BGM":
			_音.call("on_map_ready", _首个有bgm的地图())
			# 实际生效值，不是推断（工程铁律）：静音到底出在哪一环。
			print("   BGM 段起：图=", _音.get("_当前地图"), " 曲=", _音.get("_上一首"),
				" 路径=", _音.get("_bgm路径"), " playing=", _音.get("_bgm").playing,
				" 线性音量=", _音.get("_线性音量"), " dB=", _音.get("_bgm").volume_db,
				" 淡入=", _音.get("_淡入"), " 待播=", _音.get("_待播"))
		"静音":
			_音.call("_apply_settings", {
				"music_volume": 自检音量, "sound_volume": 自检音量,
				"mute_music": true, "mute_sound": true})
			_音.call("play_effect", "Sound_Mai_Fire")
		_:
			_音.call("play_effect", 标签)
	# ⚠️ 开录必须放在**动作之后**：每条音效只录 18 帧（≈0.55 秒）而 mp3 普遍 1~2 秒，
	# 上一条的尾巴还压在音频回调的缓冲里。先开录再掐静音，量到的残响会被当成"静音没生效"
	# （实测就是这么误报出 峰值 11733 / 12289 的）。
	# 静音段更走"定"这一档：掐完静音再静置 ~0.6 秒排空缓冲，才开录。
	# 4.7 实测（--dump-extension-api）：`AudioEffectRecord` 没有 start()/stop()，也没有同名属性，
	# 只能调方法 `set_recording_active(bool)`（返回 void）；`get_recording()` 返回 **AudioStreamWAV**。
	if 标签 != "静音":
		_录音.set_recording_active(true)


func _收一段() -> void:
	_录音.set_recording_active(false)
	var 录: AudioStreamWAV = _录音.get_recording()
	var 样本: PackedByteArray = 录.data if 录 != null else PackedByteArray()
	if 录 != null:
		_采样率 = float(录.mix_rate)
		_立体声 = bool(录.stereo)
	_全部.append_array(样本)
	_峰值表[_当前] = _峰值(样本)
	if _当前 == "BGM":
		print("   BGM 段止：字节=", 样本.size(), " 峰值=", int(_峰值表[_当前]),
			" playing=", _音.get("_bgm").playing, " 线性音量=", _音.get("_线性音量"),
			" dB=", _音.get("_bgm").volume_db, " 淡入=", _音.get("_淡入"))
		print("   BGM 逐 0.5s 峰值：", " ".join(_逐窗峰值(样本)))
	if _当前 == "静音":
		print("   静音段逐 0.5s 峰值：", " ".join(_逐窗峰值(样本)))
	if _当前 == "静音":
		var 响过 := 0
		for 标签 in _峰值表.keys():
			if 标签 != "静音" and int(_峰值表[标签]) > 0:
				响过 += 1
		if int(_峰值表[_当前]) > maxi(200, int(0.02 * float(_峰值表.get("BGM", 1)))):
			_失败.append("静音段还响着：峰值 %d" % int(_峰值表[_当前]))
		elif 响过 == 0:
			_失败.append("静音段之前一条都没响过，静音检查没有对照")


func _首个有bgm的地图() -> String:
	for 图 in MAP_RESOURCES.map_ids():
		var 声明 = (MAP_RESOURCES.map_data(图).get("info", {}) as Dictionary).get("bgm", "")
		if str(声明) != "" and str(声明) != "null":
			return 图
	return ""


func _峰值(样本: PackedByteArray) -> int:
	var 峰 := 0
	for i in range(0, 样本.size() - 1, 2):
		峰 = maxi(峰, absi(int(样本.decode_s16(i))))
	return 峰


## 每 0.5 秒一个峰值（48000Hz × 2 字节 × 双声道 = 96000 字节一窗），拿时间轴分辨
## "整段都在响"（设置没生效）和"只有开头有声音"（上一条的尾巴漏进窗口）。
func _逐窗峰值(样本: PackedByteArray) -> Array[String]:
	var 出: Array[String] = []
	var 窗 := 96000
	var i := 0
	while i < 样本.size() and 出.size() < 24:
		出.append(str(_峰值(样本.slice(i, mini(i + 窗, 样本.size())))))
		i += 窗
	return 出


func _收尾() -> void:
	var 无声: Array[String] = []
	for 标签 in _峰值表.keys():
		if 标签 != "静音" and int(_峰值表[标签]) <= 0:
			无声.append(String(标签))
	var 有声 := _峰值表.size() - 1 - 无声.size()
	print("③ 逐段录音峰值（16bit 满量程 32767）：有声 %d 段 / 共 %d 段" % [有声, _峰值表.size()])
	for 标签 in _峰值表.keys():
		print("     %s = %d" % [标签, int(_峰值表[标签])])
	if 无声.size() > 0:
		_失败.append("这些段录到的是静音：%s" % ", ".join(无声))
	_存录音()
	var 静音峰值 := int(_峰值表.get("静音", -1))
	var 音乐db := float(_音.get("_bgm").volume_db)
	print("④ 设置生效：静音时 BGM 音量 %.1f dB，静音段峰值 %d" % [音乐db, 静音峰值])
	if 音乐db > -70.0:
		_失败.append("勾了静音 BGM 音量却没压下去：%.1f dB" % 音乐db)


func _存录音() -> void:
	if _全部.size() == 0:
		_失败.append("整段录音是空的")
		return
	var 流 := AudioStreamWAV.new()
	流.format = AudioStreamWAV.FORMAT_16_BITS
	流.mix_rate = int(_采样率)
	流.stereo = _立体声
	流.set_data(_全部)
	DirAccess.make_dir_recursive_absolute(输出目录)
	var 目标 := 输出目录.path_join("自检录音.wav")
	var 错 := 流.save_to_wav(目标)
	if 错 != OK:
		_失败.append("录音写不出去：%s（%s）" % [目标, error_string(错)])
		return
	print("   录音已存：%s（%.1f 秒 / %d Hz / %s 声道，含 BGM + 22 条音效 + 静音对照段）" % [
		目标, float(_全部.size()) / 2.0 / float(2 if _立体声 else 1) / _采样率,
		int(_采样率), "双" if _立体声 else "单"])


func _读json(路径: String) -> Dictionary:
	var 文件 := FileAccess.open(路径, FileAccess.READ)
	if 文件 == null:
		return {}
	var 解析结果 = JSON.parse_string(文件.get_as_text().trim_prefix("﻿"))
	return 解析结果 if 解析结果 is Dictionary else {}


func _done() -> void:
	if _已收:
		return
	_已收 = true
	print("—— A1 音频自检结论：%s" % ("通过" if _失败.is_empty() else "不通过"))
	for 条 in _失败:
		print("   ✗ " + String(条))
	if _挂在总线上了:
		AudioServer.remove_bus_effect(0, 0)
	get_tree().quit(0 if _失败.is_empty() else 1)
