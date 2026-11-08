extends Node

## 原版音频：地图 BGM + `SoundConstants` 的 22 条音效。
##
## 规则**逐条抄自反编译源**，不是自己发明的播放方式：
##   * BGM：`com/mxw/game/world/World.as:932-1080`（选曲 / 防重复 / 淡切 / 播完重选）
##   * 音效：`com/mxw/common/sound/SoundPlayer.as`（可叠加多路、静音直接不播）
##   * 音效清单与职业系分派：`数据/音效.json`（由 `开发工具/导出音频.mjs` 从 AS3 源生成）
##
## ⚠️ 2026-09-26 之前的这版实现找的是 `素材/音效/map_bgm.ogg` —— 那个文件**从来不存在**，
## 所以 BGM 恒为 0 首；`attack/hit/portal.wav` 三个自造占位也被一并换成了原版音效。

const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")
const 表路径 := "res://数据/音效.json"
const BGM目录 := "res://素材/音效/BGM"

# World.as:99-101 —— 淡切每 50ms 走一步、半程 600ms。
const 淡切间隔 := 0.05
const 淡切半程 := 0.6
# 原版 `SoundPlayer.play` 每次 `SoundChannel.play` 都是**新开通道**（同一条音效可叠着响），
# Godot 一个 AudioStreamPlayer 只放得了一路，所以固定开几轮转 —— 这是平台差异，不是新行为。
const 音效通道数 := 8

var _表 := {}
var _bgm := AudioStreamPlayer.new()
var _bgm路径 := ""
var _当前地图 := ""
var _上一首 := ""
var _上一首地图 := ""
var _待播 := ""
var _淡入 := false
var _淡切目标 := 0.0
var _线性音量 := 1.0
var _淡切计时 := Timer.new()

var _音乐音量 := 1.0
var _禁地图音乐 := false
var _音效音量 := 1.0
var _音效静音 := false

var _通道: Array[AudioStreamPlayer] = []
var _通道轮转 := 0
var _流缓存 := {}
var _缺流警告过 := {}
var _权重正则: RegEx

func _ready() -> void:
	_表 = _读json(表路径)
	_权重正则 = RegEx.create_from_string("^(.+?)@([1-9][0-9]*)$")
	_bgm.name = "MapMusic"
	add_child(_bgm)
	# World.as:1165 只监听 PLAY_COMPLETE，循环交给"播完重选"，所以素材的 loop 必须是关的。
	_bgm.finished.connect(_on_bgm_finished)
	for i in 音效通道数:
		var 通道 := AudioStreamPlayer.new()
		通道.name = "Effect%d" % i
		add_child(通道)
		_通道.append(通道)
	_淡切计时.name = "BgmFade"
	_淡切计时.wait_time = 淡切间隔
	_淡切计时.one_shot = false
	add_child(_淡切计时)
	_淡切计时.timeout.connect(_推进淡切)
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.map_changed.connect(_on_map_changed)
		session.settings_changed.connect(_on_settings_changed)
		# Character.as:765 —— 原版唯一挂在这条通路上的玩家音效就是**死亡**（按职业系四条之一）。
		session.player_defeated.connect(_on_player_defeated)
		_apply_settings(session.game_settings)
	# 不在这里放 BGM：原版是 `World` 建好（进图）才 `playBGM()`，登录界面没有地图 = 没有音乐。
	# 真正的触发点是 `地图根节点._ready()` 调 `on_map_ready()`。

## 原版 `SoundPlayer.play(名字)`：名字就是 `SoundConstants` 里那 22 条之一。
func play_effect(音效名: String) -> void:
	if _音效静音 or 音效名.is_empty():
		return
	var 音效表: Dictionary = (_表.get("音效", {}) as Dictionary).get("表", {})
	var 路径 := String(音效表.get(音效名, {}).get("文件", ""))
	var 流 := _取流(路径)
	if 流 == null:
		return
	var 通道 := _空通道()
	通道.stream = 流
	通道.play()

## 原版 `SoundConstants.GetMaiSound/GetBaoJiSound/GetDeadSound/GetSelectSound(职业)`：
## 按 `CocoJob` **精确匹配** 100/200/300/400；土遁 500 和转职细分（110+）落到 default 返回 null，
## 于是原版对这类职业**根本不播**这条音效 —— 照做，不替它补一个"差不多"的声音。
func play_job_effect(分派: String) -> void:
	var 按职业: Dictionary = (_表.get("音效", {}) as Dictionary).get("按职业", {})
	var 系: Dictionary = 按职业.get(分派, {})
	var 职号 := "0"
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		职号 = str(int(session.player_stats.get("job", 0)))
	play_effect(String(系.get(职号, "")))

## World.as:932 `playBGM()` —— 换图、播完、服务端换配置都走这里。
func play_bgm() -> void:
	if _当前地图.is_empty():
		return
	var 同图 := _上一首地图 == _当前地图
	var 选项 := _bgm选项()
	var 池 := 选项
	# World.as:947-977：同图重选且候选多于 1 条时，把"上首"剔出随机池 ——
	# 但当上首是**唯一出现次数最多**的那个候选时不剔（带 `@权重` 的表里，重仓那条允许再来）。
	if 同图 and 选项.size() > 1 and _上一首 != "":
		var 次数 := {}
		for 名 in 选项:
			次数[名] = int(次数.get(String(名), 0)) + 1
		var 最多 := 0
		var 并列 := 0
		for 次 in 次数.values():
			if int(次) > 最多:
				最多 = int(次)
				并列 = 1
			elif int(次) == 最多:
				并列 += 1
		if 最多 <= 1 or int(次数.get(_上一首, 0)) < 最多 or 并列 > 1:
			池 = 选项.filter(func(名): return String(名) != _上一首)
	var 挑 := String(池[randi() % 池.size()])
	_上一首 = 挑
	_上一首地图 = _当前地图
	_switch_bgm(挑, 同图)

## World.as:1017 `switchBGM(名, 是否淡切)` —— 目标就是当前这条、或同图之外的换图，直接切。
func _switch_bgm(名: String, 淡切: bool) -> void:
	var 路径 := _bgm路径_of(名)
	if not 淡切 or _bgm路径.is_empty() or _bgm路径 == 路径:
		_取消淡切()
		_play_mp3(名)
		return
	_开始淡切(名)

# World.as:298 `playMp3`：url 不同才重载；同一条且已经停下就重播。
# `起始音量` 只有淡切路径会传（原版是 play 完立刻把 volume 压 0，这里一次到位，免得响一帧漏音）。
func _play_mp3(名: String, 起始音量: float = -1.0) -> void:
	var 路径 := _bgm路径_of(名)
	var 流 := _取流(路径)
	if 流 == null:
		return
	if 路径 == _bgm路径:
		if 起始音量 >= 0.0:
			_设音量(起始音量)
		if not _bgm.playing:
			_bgm.play()
		return
	_bgm.stop()
	_bgm.stream = 流
	_bgm路径 = 路径
	_设音量(_当前音量() if 起始音量 < 0.0 else 起始音量)
	_bgm.play()

func _bgm路径_of(名: String) -> String:
	# World.as:300 —— 空名落到 `default`。
	var 干净 := 名 if 名 != "" else "default"
	return "%s/%s.mp3" % [BGM目录, 干净]

## World.as:996 `currentBGMChoices`：地图数据里的 `info.bgm`，没有这张图的数据就没得选。
func _bgm选项() -> Array:
	var 数据: Dictionary = MAP_RESOURCES.map_data(_当前地图)
	return _解析选项((数据.get("info", {}) as Dictionary).get("bgm", ""))

## World.as:1091 `parseBGMChoices`：分隔符是 `,` `|` `;`，`名@权重` 让同名重复入池 N 次（上限 1000），
## 去掉 `@` 尾巴和 `.mp3` 后缀、按名字去重；一个都没剩下就用 `default`。
func _解析选项(原值: Variant) -> Array:
	var 段: Array = []
	if 原值 is Array:
		段 = (原值 as Array).duplicate()
	else:
		段 = String(_非空原值(原值)).replace(";", ",").replace("|", ",").split(",")
	var 出: Array = []
	var 见过 := {}
	for 项 in 段:
		var 名 := String(项).strip_edges()
		var 权重 := 1
		var 匹配: RegExMatch = _权重正则.search(名)
		if 匹配 != null:
			名 = 匹配.get_string(1).strip_edges()
			权重 = mini(1000, int(匹配.get_string(2)))
		名 = 名.strip_edges()
		if 名.to_lower().ends_with(".mp3"):
			名 = 名.substr(0, 名.length() - 4)
		if 名 == "" or 见过.get(名, false):
			continue
		见过[名] = true
		for i in 权重:
			出.append(名)
	if 出.is_empty():
		出.append("default")
	return 出

func _非空原值(原值: Variant) -> String:
	return "" if 原值 == null else str(原值)

## World.as:1021 `beginBGMFade`
func _开始淡切(名: String) -> void:
	_取消淡切()
	_待播 = 名
	_淡切目标 = _当前音量()
	if _淡切目标 <= 0.0:
		_play_mp3(名, 0.0)
		return
	if not _bgm.playing:
		_play_mp3(名, 0.0)
		_淡入 = true
		_淡切计时.start()
		return
	_淡入 = false
	_淡切计时.start()

## World.as:1050 `advanceBGMFade`：先淡到 0 换轨，再淡回设置里的音量。
func _推进淡切() -> void:
	_淡切目标 = _当前音量()
	var 步长 := maxf(0.01, _淡切目标 * 淡切间隔 / 淡切半程)
	if not _淡入:
		if _线性音量 <= 步长:
			_play_mp3(_待播, 0.0)
			_淡入 = true
		else:
			_设音量(_线性音量 - 步长)
		return
	if _淡切目标 <= 0.0 or _线性音量 + 步长 >= _淡切目标:
		_设音量(_淡切目标)
		_取消淡切()
	else:
		_设音量(_线性音量 + 步长)

func _取消淡切() -> void:
	_淡切计时.stop()
	_待播 = ""

## World.as:1085 `onBGMComplete` —— 原版没开循环，一首放完就重选（同图时会淡切）。
func _on_bgm_finished() -> void:
	play_bgm()

## 换图请求先记下来；真正放音乐等 `地图根节点._ready()` 调 `on_map_ready()`。
func _on_map_changed(map_id: String) -> void:
	if str(map_id) != _当前地图:
		_当前地图 = str(map_id)
		_上一首地图 = ""

## `地图根节点._ready()` 调这里 —— 对应原版"World 建好才 playBGM"（World.as:932 的开头就是
## `if(!this.map || !this.map.data) return`）。同一张图重复进来不重选曲，避免"回城音乐跳一下"。
func on_map_ready(map_id: String) -> void:
	var 图 := str(map_id)
	if 图 == _上一首地图 and _bgm.playing:
		return
	_当前地图 = 图
	play_bgm()

func _on_settings_changed(settings: Dictionary) -> void:
	_apply_settings(settings)

## Character.as:758-766 —— 玩家死亡放本职业系的 `Sound_Dead_*`。
## 原版同一个判断里还有一条 `if(!API.dataCenter.nowEquipShiZhuang)`：**穿着时装不放**。
## 我们没有"时装"这个字段（服务端才有的外观态），所以照原样不拦 —— 记在未决清单里。
func _on_player_defeated() -> void:
	play_job_effect("GetDeadSound")

## SysCfg.as:237-240 / 361-392：`bgmVolume`/`sfxVolume` 都是 0~1 线性值，
## `forbidMapBackgoundMusic` 直接把 BGM 音量压成 0（**不是暂停**），`mute` 只作用于音效。
func _apply_settings(settings: Dictionary) -> void:
	_音乐音量 = clampf(float(settings.get("music_volume", _音乐音量)), 0.0, 1.0)
	_音效音量 = clampf(float(settings.get("sound_volume", _音效音量)), 0.0, 1.0)
	_禁地图音乐 = bool(settings.get("mute_music", false))
	var 原静音 := _音效静音
	_音效静音 = bool(settings.get("mute_sound", false))
	# SoundPlayer.as:29-38 —— `mute` 一开就把**正在响的**全部掐掉，不只是拦后续的 play。
	if _音效静音 and not 原静音:
		for 掐 in _通道:
			掐.stop()
	if _淡切计时.is_stopped():
		_设音量(_当前音量())
	for 通道 in _通道:
		通道.volume_db = linear_to_db(maxf(0.0001, _音效音量))

func _当前音量() -> float:
	return 0.0 if _禁地图音乐 else _音乐音量

func _设音量(线性: float) -> void:
	_线性音量 = clampf(线性, 0.0, 1.0)
	_bgm.volume_db = linear_to_db(maxf(0.0001, _线性音量))

func _空通道() -> AudioStreamPlayer:
	for i in 音效通道数:
		var 候选 := _通道[(_通道轮转 + i) % 音效通道数]
		if not 候选.playing:
			_通道轮转 = (_通道轮转 + i + 1) % 音效通道数
			return 候选
	# 全占着就抢最久没用的那条（原版是无限开通道，这里封顶防爆炸）。
	var 抢 := _通道[_通道轮转]
	_通道轮转 = (_通道轮转 + 1) % 音效通道数
	抢.stop()
	return 抢

func _取流(路径: String) -> AudioStream:
	if 路径.is_empty():
		return null
	if _流缓存.has(路径):
		return _流缓存[路径]
	if not ResourceLoader.exists(路径):
		if not _缺流警告过.has(路径):
			_缺流警告过[路径] = true
			push_warning("音频管理：缺素材 %s" % 路径)
		return null
	var 流: AudioStream = load(路径)
	_流缓存[路径] = 流
	return 流

func _读json(路径: String) -> Dictionary:
	var 文件 := FileAccess.open(路径, FileAccess.READ)
	if 文件 == null:
		push_error("音频管理：读不到 %s（先跑 开发工具/导出音频.mjs）" % 路径)
		return {}
	var 解析结果 = JSON.parse_string(文件.get_as_text().trim_prefix("\ufeff"))
	return 解析结果 if 解析结果 is Dictionary else {}
