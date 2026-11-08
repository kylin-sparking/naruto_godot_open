extends SceneTree
## 挂机设置窗离线门（#272）。
##
## 参照值是**这个文件里手抄的 AS3 窗口坐标**（逐条带行号，见 `真值/窗口/挂机设置窗.md`），
## 不从被测场景反查、也不从 `数据/界面/挂机窗口_期望.json` 反查 —— 期望表拿来当**第二道**：
##   ① 场景实际落点 ↔ 手抄表（证明 .tscn 真按 AS3 摆了）
##   ② 生成器期望 ↔ 手抄表（证明 `生成挂机场景.py` 那条链式重算没算错）
## 两道都用，才不会出现"生成器和门一起错、互相印证"那种假绿。
##
## 跑法：`<godot> --headless --path <工程> --script res://测试/挂机窗回归测试.gd`
##
## ⚠ 三条本工程的硬口径（都是栽过的地方）：
## * 复选组件里的可点件是 **`Button`（`BaseButton` 的子类，不是 TextureButton）** ⇒ 转型一律
##   `as BaseButton` / `as Button`，写 `as TextureButton` 会静默拿 null。
## * 所有点击走 `root.push_input(..., true)`，**不用 `pressed.emit()`**：后者绕过命中测试，
##   件摆错位、被邻件压住、disable 了还能点，这三种坏它都测不出来。
## * 无头 `root.size` 必须**跑过一帧之后**再设，否则停在 64×64 ⇒ 拾取整体失效、整批假红。

const 页面路 := "res://场景/界面/窗口/挂机/挂机窗口.tscn"
const 控制器路 := "res://脚本/界面/窗口/挂机窗口.gd"
const 期望路 := "res://数据/界面/挂机窗口_期望.json"
const 尺寸表路 := "res://数据/界面/窗口尺寸.json"
const 原点 := Vector2(8.0, 38.0)		# UIWindow.as:37-38
const 数据表 := preload("res://脚本/单例/游戏数据.gd")
const 离线示例数据 := preload("res://脚本/单例/离线示例数据.gd")

## ── ① 手抄表：全部是 **AS3 窗口坐标**（局部门面坐标 = 这组数 − 8,38）─────────
## 叶盒四块：`:257-277` + `:308-313`；端帽/标题按 `LeafBorder.as:66-72,80-85`（padding=40）。
const 手抄 := {
	"盒吃药": [13.0, 67.0, 352.0, 153.0],			# :258-261
	"端帽左吃药": [53.0, 53.0, 27.0, 22.0],			# x=盒x+40、y=8−22
	"端帽右吃药": [298.0, 53.0, 27.0, 22.0],			# x=盒右−27−padding = 365−67
	"标题吃药": [13.0, 48.0, 352.0, 20.0],			# y=盒y−19
	"盒采集": [13.0, 244.0, 352.0, 86.0],			# :264-268 y=吃药底+24
	"端帽左采集": [53.0, 230.0, 27.0, 22.0],
	"端帽右采集": [298.0, 230.0, 27.0, 22.0],
	"标题采集": [13.0, 225.0, 352.0, 20.0],
	"盒战斗": [370.0, 67.0, 281.0, 263.0],			# :271-275 宽=648−352−15、高=86+153+24
	"端帽左战斗": [410.0, 53.0, 27.0, 22.0],
	"端帽右战斗": [584.0, 53.0, 27.0, 22.0],			# 370+281−27−40
	"标题战斗": [370.0, 48.0, 281.0, 20.0],
	"盒出售": [13.0, 348.0, 638.0, 104.0],			# :308-312 宽=648−10、y=采集底+18
	"端帽左出售": [53.0, 334.0, 27.0, 22.0],
	"端帽右出售": [584.0, 334.0, 27.0, 22.0],
	"标题出售": [13.0, 329.0, 638.0, 20.0],
	# 吃药组 :278-294
	"复选生命阈值": [21.0, 75.0, 19.0, 19.0],			# :278 x=盒x+8
	"标签生命低于": [46.0, 75.0, 76.0, 20.0],			# :279 x=勾x+25
	"输入生命阈值": [126.0, 75.0, 40.0, 21.0],			# :280 x=标签x+80、width=40 :184
	"标签生命时": [166.0, 75.0, 64.0, 20.0],			# :281 x=输入x+40
	"下拉生命药品": [231.0, 75.0, 80.0, 21.0],			# :283 x=输入x+105、width=80 :478
	"标签生命吃药": [311.0, 75.0, 50.0, 20.0],			# :284 x=下拉x+80
	"复选查克拉阈值": [21.0, 99.0, 19.0, 19.0],			# :285 y=上y+19+5
	"输入查克拉阈值": [126.0, 99.0, 40.0, 21.0],
	"下拉查克拉药品": [231.0, 99.0, 80.0, 21.0],
	"复选体力符": [21.0, 138.0, 340.0, 19.0],			# :292 y=查克拉y+19+20
	"复选精华符": [21.0, 162.0, 340.0, 19.0],			# :293 y=+19+5
	"复选通灵体力符": [21.0, 186.0, 340.0, 19.0],		# :294
	# 采集组 :295-306
	"复选拾取总开关": [21.0, 252.0, 19.0, 19.0],		# :295 y=采集盒y+8
	"下拉拾取职业": [76.0, 252.0, 80.0, 21.0],			# :297 x=标签x+30
	"下拉拾取等级": [156.0, 252.0, 80.0, 21.0],			# :298 x=上一个+80
	"下拉拾取品质": [236.0, 252.0, 80.0, 21.0],			# :299
	"标签拾取装备": [316.0, 252.0, 32.0, 20.0],			# :300
	"复选拾取任务品": [21.0, 276.0, 120.0, 19.0],		# :301
	"复选拾取药品": [141.0, 276.0, 120.0, 19.0],			# :302 x=+120
	"复选拾取金币": [261.0, 276.0, 100.0, 19.0],			# :303 x=药品x+120
	"复选拾取材料": [21.0, 300.0, 120.0, 19.0],			# :304 y=276+19+5
	"复选拾取其他": [141.0, 300.0, 120.0, 19.0],			# :305
	"复选自动出售装备": [249.0, 300.0, 128.0, 19.0],		# :306 x=金币x−12
	# 战斗组 :326-348
	"下拉自动忍术": [457.0, 76.0, 80.0, 21.0],			# :327 x=盒x+87、y=标签y+1
	"标签攻击动物一": [537.0, 75.0, 110.0, 20.0],		# :328
	"下拉自动宠物忍术": [457.0, 100.0, 80.0, 21.0],		# :330
	"复选自动续用辅助": [378.0, 125.0, 267.0, 19.0],		# :332 y=100+21+4
	"复选天之咒印": [378.0, 146.0, 101.0, 19.0],			# :333 y=+19+2
	"复选地之咒印": [478.0, 146.0, 167.0, 19.0],			# :334 x=+100
	"复选掌仙术": [378.0, 167.0, 101.0, 19.0],			# :335
	"复选创造再生": [478.0, 167.0, 167.0, 19.0],			# :336
	"复选不离不弃": [378.0, 188.0, 101.0, 19.0],			# :337
	"复选自动升级技能": [478.0, 188.0, 167.0, 19.0],		# :338
	"标签战斗范围": [378.0, 211.0, 112.0, 20.0],			# :339 y=188+19+4
	"输入战斗范围": [493.0, 211.0, 40.0, 21.0],			# :340 x=标签x+115
	"标签格": [533.0, 211.0, 16.0, 20.0],				# :341 无 width ⇒ 字宽+4
	"标签战斗时间": [378.0, 235.0, 84.0, 20.0],			# :342
	"输入战斗时间": [463.0, 235.0, 40.0, 21.0],			# :343 x=标签x+85
	"标签分钟": [503.0, 235.0, 28.0, 20.0],				# :344
	"复选无限时长": [533.0, 235.0, 110.0, 19.0],			# :345 x=分钟标签x+30
	"复选回城打坐": [378.0, 260.0, 267.0, 19.0],			# :346 y=235+21+4
	"复选避开首领": [378.0, 282.0, 267.0, 19.0],			# :347 y=+19+3
	"复选原地复活": [378.0, 304.0, 267.0, 19.0],			# :348
	# 出售组 :315-325
	"复选自动出售开": [21.0, 372.0, 88.0, 19.0],			# :315 y=盒y+24
	"标签等级上限": [116.0, 372.0, 64.0, 20.0],			# :316 x=勾x+95
	"下拉出售等级": [183.0, 372.0, 80.0, 21.0],			# :317 x=勾x+162
	"标签职业": [271.0, 372.0, 48.0, 20.0],				# :318 x=下拉x+88
	"下拉出售职业": [323.0, 372.0, 80.0, 21.0],			# :319 x=下拉x+140
	"标签品质上限": [411.0, 372.0, 60.0, 20.0],			# :320
	"下拉出售品质": [473.0, 372.0, 80.0, 21.0],			# :321 x=下拉x+150
	"复选出售食材": [21.0, 398.0, 160.0, 19.0],			# :322 y=372+26
	"复选出售残卷": [191.0, 398.0, 130.0, 19.0],			# :323 x=+170
	"复选出售技能书": [331.0, 398.0, 110.0, 19.0],		# :324 x=+140
	"标签出售提示": [21.0, 424.0, 420.0, 20.0],			# :325 y=398+26
	# 底栏 :349-355（y 按 `_height − 27`，落在内容底之外）
	"标签提示": [415.0, 465.0, 243.0, 20.0],
	"钮开始": [250.5, 467.0, 61.0, 22.0],				# x=(664−163)/2、width=btn_width_four
	"钮停止": [351.5, 467.0, 61.0, 22.0],				# x=开始x+61+40
}
## 只有这几枚勾是"空文本"（生命/查克拉/拾取总开关）：原版 `createCheckBox(..., " ")`，
## 文字由旁边的独立 MLabel 承担 ⇒ 点击区就只有 19 宽，**不许**盖到旁边的文字上。
const 空文本勾 := ["复选生命阈值", "复选查克拉阈值", "复选拾取总开关"]
## 每枚勾的文案色（`createCheckBox` 的 param4）：`UIConfig` + 那三处字面量。
const 勾色 := {
	"复选体力符": "#ebe381", "复选精华符": "#ebe381", "复选通灵体力符": "#ebe381",
	"复选自动升级技能": "#fff000",
	"复选无限时长": "#dd9e3f", "复选回城打坐": "#dd9e3f", "复选避开首领": "#dd9e3f",
	"复选原地复活": "#dd9e3f",
	"复选拾取任务品": "#1e90ff", "复选自动出售开": "#1e90ff",
}
## 下拉项表（`CN.as` 那四个数组 + `:560-585` 硬编码的品质档）。
const 下拉项数 := {
	"下拉生命药品": 2, "下拉查克拉药品": 2, "下拉拾取职业": 5, "下拉拾取等级": 7,
	"下拉拾取品质": 5, "下拉出售等级": 7, "下拉出售职业": 5, "下拉出售品质": 7,
}
## 输入框上限（`createTextInput` 的 param3：`:280` 缺省 100、`:340` 99、`:343` 500）。
const 输入上限 := {"输入生命阈值": 100, "输入查克拉阈值": 100, "输入战斗范围": 99, "输入战斗时间": 500}

var 通过 := 0
var 失败 := 0
var 跑完了 := false
var 鼠位 := Vector2(-200.0, -200.0)
var 假后端: Node
var 假宿主: Control
var 页: Control
var 控制: GDScript
## ⚠ 离线门**不许留存档**：点「开始挂机」会写 `user://挂机自动出售.json`（原版 `nyaAutoSell` 的对应物），
## 而两份工程同名 ⇒ **共用同一个 user://**，留着就会让下一位（或他的客户端）读到本轮的值。
## 进门先记字节、出门按原样还原（本来不存在就删掉）。
var 出售存档路 := ""
var 出售存档原有 := false
var 出售存档字节 := PackedByteArray()
## ⚠ 同一族的第二份，而且这份**才是用户的档**：本门点勾/换下拉写的是 `会话.game_settings`，
## 而会话那侧有二十多个 `_save_local_state()` 落盘点（`游戏会话.gd:501/601/652/…`）
## ⇒ "本门只改内存、不落盘"这句话**守不住**。10-23 单跑实测（跑完按字节比）：
## `auto_combat` False→True、`auto_rest` True→False、`auto_skills` False→True、
## `auto_skill_id` 0→1001001、`auto_battle_range` 20→7、`auto_hp_value` 70→33、
## `auto_avoid_boss` False→True、`auto_pet_skill_id` 101→-1 —— **八项全是门里那套夹具值**，
## 而他的客户端读的就是这一份（两份工程同名共用 user://）。跑批那侧会按字节还原，
## 但那是兜底不是凭据：谁单独跑这一条门（`--script` 直跑、调试时反复跑）就直接带进他档里。
## ⇒ 进门记字节、出门无条件还原，跑批没跑也一样。
var 玩档原有 := false
var 玩档字节 := PackedByteArray()
var 玩档已还 := false
var 会话: Node
## 进门时的职业 / 已学忍术（⑤c 要按离线默认号判，见 `_跑` 里那段；收尾还原）。
var _职备份 = 0
var _技备份: Array = []


func _判(对: bool, 说明: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 说明)


func _近(a: Array, b: Array) -> bool:
	for i in 4:
		if absf(float(a[i]) - float(b[i])) > 0.6:
			return false
	return true


func _矩形(件: Control) -> Array:
	return [件.position.x, 件.position.y, 件.size.x, 件.size.y]


func _局(窗坐标: Array) -> Array:
	return [窗坐标[0] - 原点.x, 窗坐标[1] - 原点.y, 窗坐标[2], 窗坐标[3]]


## 真点：两跳 + 三帧（同一帧连发两条 MouseMotion，视口只按最后一条做拾取 ⇒ 大距离瞬移
## 不触发 `mouse_entered`，这是 `flash-mbutton3` 那条坑；间隔 3 帧是因为裁的是上一帧的视口图）。
func _移到(目标: Vector2) -> void:
	var 中 := (鼠位 + 目标) * 0.5
	for 点在 in [中, 目标]:
		var 动 := InputEventMouseMotion.new()
		动.position = 点在
		动.global_position = 点在
		root.push_input(动, true)
		鼠位 = 点在
		await process_frame
	await process_frame
	await process_frame


func _点(件: Control) -> void:
	var 心 :=件.global_position + 件.size * 0.5
	await _移到(心)
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.position = 心
	按.global_position = 心
	按.pressed = true
	root.push_input(按, true)
	await process_frame
	var 抬 := InputEventMouseButton.new()
	抬.button_index = MOUSE_BUTTON_LEFT
	抬.position = 心
	抬.global_position = 心
	抬.pressed = false
	root.push_input(抬, true)
	await process_frame
	await process_frame
	await process_frame


## 真打字：逐字符推一对 `InputEventKey`（带 unicode），走 LineEdit 自己的输入路径。
func _打字(串: String) -> void:
	for i in 串.length():
		var c := 串[i]
		var 键 := InputEventKey.new()
		键.unicode = c.unicode_at(0)
		键.physical_keycode = KEY_0 + (c.unicode_at(0) - 48) if c >= "0" and c <= "9" else KEY_A
		键.pressed = true
		root.push_input(键, true)
		await process_frame
		var 抬 := 键.duplicate() as InputEventKey
		抬.pressed = false
		root.push_input(抬, true)
		await process_frame
	await process_frame
	await process_frame


func _勾(件名: String) -> Button:
	return 页.get_node(件名 + "/点击区域") as Button


func _亮(件名: String) -> bool:
	var 记 := 页.get_node(件名 + "/标记") as CanvasItem
	return 记 != null and 记.visible


func _文(件名: String) -> String:
	var 标 := 页.get_node_or_null(件名 + "/文本") as Label
	return 标.text if 标 != null else ""


func _皮(钮: Control) -> String:
	var 图: Texture2D = (钮 as TextureButton).texture_normal
	return 图.resource_path.get_file() if 图 != null else "‹没皮›"


func _字色(钮: Control) -> String:
	var 字 := 钮.get_node_or_null("文字") as Label
	return 字.get_theme_color("font_color").to_html(false) if 字 != null else ""


## 读一张皮的「不透明像素数 / 三通道之和 / 是不是每个不透明像素都 R=G=B」。
## 期望值从**素材文件本身**算，不从被测对象身上读（否则 = 自证）。
func _皮统计(路: String) -> Dictionary:
	var 数 := 0
	var 和 := 0
	var 全灰 := true
	var 图 := load(路) as Texture2D
	if 图 == null:
		return {"数": 0, "和": 0, "全灰": false}
	var 像 := 图.get_image()
	像.convert(Image.FORMAT_RGBA8)
	var 字 := 像.get_data()		# PackedByteArray，RGBA8 ⇒ 步长 4
	var i := 0
	while i + 3 < 字.size():
		if int(字[i + 3]) == 255:
			数 += 1
			var r: int = int(字[i])
			var g: int = int(字[i + 1])
			var b: int = int(字[i + 2])
			和 += r + g + b
			if r != g or g != b:
				全灰 = false
		i += 4
	return {"数": 数, "和": 和, "全灰": 全灰}


func _态皮(件: TextureRect) -> String:
	return 件.texture.resource_path.get_file() if 件 != null and 件.texture != null else "〈没皮〉"


func _还原玩档() -> void:
	if 玩档已还:
		return
	玩档已还 = true
	var 在 := FileAccess.file_exists("user://玩家数据.json")
	if not 玩档原有:
		if 在:
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://玩家数据.json"))
		_判(FileAccess.file_exists("user://玩家数据.json") == 在 and not 在,
				"出门自检：进门时没有玩家数据.json ⇒ 出门也不许留（本门造的那份删掉）")
		return
	if not 在:
		_判(false, "出门自检：进门时有玩家数据.json、现在没了 ⇒ 本门把他的档弄丢了")
		return
	if FileAccess.get_file_as_bytes("user://玩家数据.json") != 玩档字节:
		var f := FileAccess.open("user://玩家数据.json", FileAccess.WRITE)
		if f != null:
			f.store_buffer(玩档字节)
			f.close()
	_判(FileAccess.get_file_as_bytes("user://玩家数据.json") == 玩档字节,
			"出门自检：玩家数据.json 回到进门时的字节（本门确实落过盘，还原由门自己做、不等跑批兜）")


func _initialize() -> void:
	await _跑()
	## 还原放在 `_initialize` 而不是只放在 `_跑` 末尾：中途报错那条路（下面 跑完了==false 那一支）
	## 也得还原 —— 否则"红的那一趟"恰好是他档里留夹具值的那一趟。
	_还原玩档()
	if not 跑完了:
		失败 += 1
		print("红：门没跑到底（中途报错，看上面最后一条 SCRIPT ERROR）")
	if 失败 == 0:
		print("挂机窗离线门：通过 %d，红 0" % 通过)
		quit(0)
		return
	print("挂机窗离线门：通过 %d，红 %d" % [通过, 失败])
	quit(1)


func _跑() -> void:
	print("挂机窗离线门开始")
	await process_frame
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	_判(root.size.x >= 1280,
			"量具自检：窗口尺寸落到 %s（不到 1280 就等于拿 64×64 的视口判点击）" % str(root.size))
	## 先记下 `user://挂机自动出售.json` 的原样（不存在也记 "不存在"），末尾按它还原。
	出售存档路 = ProjectSettings.globalize_path("user://挂机自动出售.json")
	出售存档原有 = FileAccess.file_exists("user://挂机自动出售.json")
	if 出售存档原有:
		出售存档字节 = FileAccess.get_file_as_bytes("user://挂机自动出售.json")
	## 同上，先记 `user://玩家数据.json` 进门时的字节（见上面那段：本门确实会落盘）。
	玩档原有 = FileAccess.file_exists("user://玩家数据.json")
	if 玩档原有:
		玩档字节 = FileAccess.get_file_as_bytes("user://玩家数据.json")
	会话 = root.get_node_or_null("GameSession")
	## ⚠ ⑤c 那条期望值写的是**离线默认号**（job=100、已学 1001001 lv1 与 0002000 lv1）。
	## `player_stats` / `learned_skills` 是从 `user://玩家数据.json` 读进来的，两份工程共用那份存档
	## ⇒ 在线登录过真号之后 job=300、技能整张换掉，下拉变成雷遁三招，红的是环境不是链路
	## （10-22 全量批实测 → ①）。本段自己钉、收尾还原。
	## ⚠ 这行注释原先写的是「**只改内存、不落盘**」—— **那句是错的**（上面 玩档字节 那段实测：
	## 本门确实会触发 `_save_local_state()`，八项挂机设置进过他的真档）。内存备份照旧，
	## 落盘这一头由 `_还原玩档()` 按字节兜住。
	if 会话 != null:
		_职备份 = 会话.player_stats.get("job", 0)
		_技备份 = (会话.learned_skills as Array).duplicate(true)
		会话.player_stats["job"] = 100
		会话.learned_skills.assign(离线示例数据.create().learned_skills)
	_判(会话 != null and 会话.has_signal("挂机配置_changed"),
			"量具自检：GameSession 有 挂机配置_changed（没有这条，回帧回填的判据就是自证）")
	## 假后端**同名**：控制器走 `GameSession.后端连接()` = `/root/BackendConnection`，
	## 名字对不上就取到 null ⇒ "请求发没发"整段静默零覆盖。
	var 真后端 := root.get_node_or_null("BackendConnection")
	if 真后端 != null:
		root.remove_child(真后端)
	假后端 = 假后端类.new()
	假后端.name = "BackendConnection"
	root.add_child(假后端)
	await process_frame
	控制 = load(控制器路)
	假宿主 = 假宿主类.new()
	假宿主.name = "挂机宿主"
	root.add_child(假宿主)
	await process_frame

	# ── ① 开窗：逐件矩形（场景 ↔ 手抄表） ──
	控制.渲染(假宿主)
	页 = 假宿主.页面
	_判(页 != null, "渲染 后宿主拿到了页面")
	if 页 == null:
		跑完了 = true
		return
	_判(假后端.查过 == 1,
			"★ 一开窗就发了一条 1283 查询（载荷就是 `0`，不带 opcode）——「点它有请求」的第一条，实得 %d 条"
					% 假后端.查过)
	_判(_近(_矩形(页), [0.0, 0.0, 648.0, 454.0]),
			"页面根本身 = 内容宽 648 × (492−38) = 454（底栏三件落在内容底之外，靠这一格兜住），实得 %s"
					% str(_矩形(页)))
	var 手抄数 := 0
	for 名 in 手抄:
		手抄数 += 1
		var 件 := 页.get_node_or_null(String(名)) as Control
		_判(件 != null, "场景里有 %s（AS3 %s）" % [名, 手抄[名]])
		if 件 == null:
			continue
		_判(_近(_矩形(件), _局(手抄[名])),
				"%s 矩形 = %s（窗口坐标），实得 %s" % [名, str(_局(手抄[名])), str(_矩形(件))])
	_判(手抄数 >= 70, "手抄表覆盖 %d 件（少于 70 就是门自己缩水了）" % 手抄数)

	# ── ② 生成器期望 ↔ 手抄表（另一道：链式重算对不对） ──
	var 期望: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(期望路))
	_判(not 期望.is_empty(), "读得到 数据/界面/挂机窗口_期望.json（跑生成器）")
	var 差: Array = []
	for 名 in 手抄:
		var 期: Dictionary = 期望.get(String(名), {}) as Dictionary
		if not 期.has("窗口坐标"):
			差.append(String(名) + "‹期望表里没有›")
			continue
		if not _近(期["窗口坐标"] as Array, 手抄[名] as Array):
			差.append("%s 期望=%s 手抄=%s" % [名, str(期["窗口坐标"]), str(手抄[名])])
	_判(差.is_empty(), "生成器算出的窗口坐标与手抄表逐件一致，不一致：%s" % str(差.slice(0, 6)))
	# 场景里没有"期望表之外"的裸件（漏登记 = 门看不见那一件）
	var 表外: Array = []
	for 子 in 页.get_children():
		if not (子 is Control):
			continue
		var 名 := 子.name
		if String(名).begins_with("钮"):
			continue
		if not 期望.has(String(名)) and not String(名).begins_with("输入底"):
			表外.append(String(名))
	_判(表外.is_empty(), "场景每个直接子件都在期望表里登记过，漏登记：%s" % str(表外.slice(0, 8)))

	# ── b 下拉里的字**画得全**：① 只比框的 position/size，缺字它照门绿 ──
	## OptionButton 的可用文字宽 = 框宽 − 样式左右内边距 − 箭头图标宽 − `h_separation`。
	## 上一轮 80 的框被算成 38 ⇒「从大到小」只画得出「从大到」（10-18 用户实机图）。
	## 判的是**解算值**（`get_theme_stylebox` / `get_theme_icon`），不是 .tscn 里写了哪几行。
	## ⚠ 口径：原版是 `fl.controls.ComboBox`，`inputField` 与 `dropdown` 都跟着 80 的框宽走、
	## 文字**超出就裁**（`MComboBox.as` 全程没有 autosize）⇒ 不许拿"每一项都得放得下"当判据，
	## 那比原版还严。真值 = 框宽 80 − 左帽 5 − 右帽 23（皮上那枚箭头按钮）= 52，
	## 而 10 枚下拉的**默认选中项全是四个 12px 汉字**（48）⇒ 判 48 这条线。
	var 窄了: Array = []
	var 扫到 := 0
	for 名 in 手抄:
		if not String(名).begins_with("下拉"):
			continue
		var 件 := 页.get_node(String(名)) as OptionButton
		var 皮: StyleBox = 件.get_theme_stylebox("normal") as StyleBox
		var 箭: Texture2D = 件.get_theme_icon("arrow") as Texture2D
		_判(箭 != null and 箭.get_width() <= 1,
				"%s 的箭头必须是 ≤1px 的空白（箭头本来就烙在皮上，Godot 再画一枚要吃掉 13px 文字宽），实得 %s"
						% [名, "无" if 箭 == null else str(箭.get_width())])
		var 可用: float = 件.size.x - (皮.content_margin_left if 皮 != null else 5.0) \
				- (皮.content_margin_right if 皮 != null else 5.0) \
				- float(箭.get_width() if 箭 != null else 0) - float(件.get_theme_constant("h_separation"))
		_判(可用 <= 52.5, "%s 文字区 %.0f 不该超过皮算出来的 52（超了就是边距写小了）" % [名, 可用])
		扫到 += 1
		var 字: Font = 件.get_theme_font("font") as Font
		var 号: int = 件.get_theme_font_size("font_size")
		for 序 in 件.item_count:
			var 文 := 件.get_item_text(序)
			var 宽: float = 字.get_string_size(文, HORIZONTAL_ALIGNMENT_LEFT, -1, 号).x
			if 宽 <= 48.5 and 宽 > 可用:
				窄了.append("%s#%d「%s」%.0f>%.0f" % [名, 序, 文, 宽, 可用])
	_判(扫到 == 10, "量具自检：扫到 %d 枚下拉（原版 createComboBox 十处，少一枚这条就漏判）" % 扫到)
	_判(窄了.is_empty(), "四字以内的项一个都不能缺字，缺：%s" % str(窄了.slice(0, 6)))

	# ── b2 四块叶盒标题居中（`LeafBorder.as:70` 是 `_label.x = (_width - _label.width)/2`）──
	for 名 in ["标题吃药", "标题采集", "标题战斗", "标题出售"]:
		var 标 := 页.get_node(String(名)) as Label
		_判(标.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
				"%s 居中（上一轮漏了 ⇒ 标题贴到盒子最左边），实得 %d" % [名, 标.horizontal_alignment])

	# ──  外壳规格：窗口尺寸表必须是 664×492 带内容底（旧条目写的是 365 高） ──
	var 尺寸: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(尺寸表路))
	var 挂: Dictionary = 尺寸.get("挂机", {}) as Dictionary
	_判(int(挂.get("宽", 0)) == 664 and int(挂.get("高", 0)) == 492 and bool(挂.get("内容底", false)),
			"窗口尺寸表「挂机」= 664×492 内容底（AS3 :166），实得 %s" % str(挂))
	_判(String(挂.get("标题", "")) == "智能托管打怪设置",
			"标题 = CN.GUAJI_SETTING_WINDOW_TITLE，实得「%s」" % String(挂.get("标题", "")))

	# ── ④ 复选：文本盒/点击区跟着根宽，空文本那三枚只 19 宽 ──
	for 名 in 手抄:
		if not String(名).begins_with("复选"):
			continue
		var 根 := 页.get_node(String(名)) as Control
		var 区 := _勾(String(名))
		_判(区 != null, "%s 取得到内部「点击区域」（拿不到 = 组件换了结构，整段判据失效）" % 名)
		if 区 == null:
			continue
		_判(_近(_矩形(区), [0.0, 0.0, 根.size.x, 19.0]),
				"%s 点击区 = 整根 %s，实得 %s（内部不跟着根宽 ⇒ 点击区压到邻件、点错格）"
						% [名, str(根.size), str(_矩形(区))])
		var 标 := 根.get_node("文本") as Label
		if String(名) in 空文本勾:
			_判(标.text.is_empty() and 根.size.x == 19.0,
					"%s 是原版那三枚「空格文本」：文本盒零宽、根只 19 宽，实得 文「%s」宽 %s"
							% [名, 标.text, str(根.size.x)])
		else:
			_判(not 标.text.is_empty(), "%s 的文案烘进场景了（编辑器里看得见）" % 名)
			_判(标.offset_right <= 根.size.x + 0.6,
					"%s 文本盒不超出根宽（超了就是被旧 177 宽裁字），实得 右%s 根宽%s"
							% [名, str(标.offset_right), str(根.size.x)])
		if 勾色.has(String(名)):
			_判(标.get_theme_color("font_color").to_html(false) == String(勾色[名]).lstrip("#"),
					"%s 文字色 = %s（createCheckBox 的 param4），实得 %s"
							% [名, 勾色[名], 标.get_theme_color("font_color").to_html(false)])

	# ── ⑤ 下拉：项数 / 皮四档 / 手型 ──
	for 名 in 下拉项数:
		var 件 := 页.get_node(String(名)) as OptionButton
		_判(件 != null and 件.item_count == int(下拉项数[名]),
				"%s 有 %d 项，实得 %d" % [名, 下拉项数[名], 件.item_count if 件 != null else -1])
		if 件 != null and 件.item_count > 0:
			var 首 := String(期望.get(名, {}).get("项", [""])[0])
			_判(件.get_item_text(0) == 首 and 件.text == 首,
					"%s 第 0 项文案 = 语言表原文「%s」，实得「%s」" % [名, 首, 件.get_item_text(0)])
	var 忍 := 页.get_node("下拉自动忍术") as OptionButton
	_判(忍 != null and 忍.item_count > 0,
			"技能下拉**不是空的**（空 = 拿 假数据 跑的这扇门自己没喂上技能，判据会退化成 0 比 0）")
	# ── ⑤c 下拉里写的必须是**玩家看到的那个技能名**（用户 2026-10-19 实机打回：
	#      "这个下拉菜单里的技能为什么和原版本不一致呢，应该是叫技能名字的啊"）──
	## 真值 = GameData 顶层 `String` 段的 `Skill` 子表（本机 2.2.3优化版现查 99 条），
	## 原版这一格就是 `StringTool.getSkillString(id)`（`GuaJiSettingWindow.as:386-392` →
	## `StringTool.as:114-119`），键按 `ImgUtil.getSkillNumName:220-229` **左补零到 7 位**。
	## ⚠ 下面的对照值是**手抄在这里的**，不从 `数据/技能文案.json` 反查 —— 那张表是被测链路的产物，
	##    它和访问器一起坏了这扇门就瞎了（10-19 就是这条：`name` 取到了 `Skill` 段的占位结构字段）。
	if 忍 != null:
		var 招名: Array = []
		for 序 in 忍.item_count:
			招名.append(忍.get_item_text(序))
		## 离线默认号：job=100（火遁流）、已学 1001001 lv1 与 0002000 lv1
		## ⇒ 候选表（`DataCenter.getAttackSkills:1501-1546`）过等级筛只剩这三条，`0` 恒在。
		_判(招名 == ["普通攻击", "火遁·烈炎斩", "潜影蛇手"],
				"招式下拉三项 = 普攻 + 火遁·烈炎斩 + 潜影蛇手（技能真名），实得 %s" % str(招名))
		for 垃圾 in ["基本的攻击招式", "单体远程", "面积", "吸血", "减内力"]:
			_判(not (垃圾 in 招名),
					"下拉里不许出现「%s」——那是 `Skill` 段的结构字段（`数据/技能.json` 的 name 列），不是名字" % 垃圾)
		## 访问器那一层单独钉：四位数号不补零就**一条都查不到**（五枚 Debuff + 四枚家族技 + 月读/天照）。
		_判(String(数据表.skill_text(2000).get("name", "")) == "潜影蛇手"
				and String(数据表.skill_text(3204).get("name", "")) == "月读"
				and String(数据表.skill_text(0).get("name", "")) == "普通攻击",
				"skill_text 对四位数号要先补零再查（2000→0002000、3204→0003204、0→0000000），实得 %s / %s / %s"
						% [str(数据表.skill_text(2000).get("name", "")),
							str(数据表.skill_text(3204).get("name", "")),
							str(数据表.skill_text(0).get("name", ""))])
		_判(String(数据表.skill_text(3001001).get("name", "")) == "雷遁·雷切",
				"七位数号原样查得到（3001001=雷遁·雷切，雷遁流第一招）")
		_判((数据表.skill_text(9999999) as Dictionary).is_empty(),
				"阳性对照：查一个没有的号必须回空字典（否则上面那两条是恒真的）")

	# ── ⑥ 输入：上限烘在 metadata、初值 = 原版默认 ──
	for 名 in 输入上限:
		var 件 := 页.get_node(String(名)) as LineEdit
		_判(件 != null, "%s 取到" % 名)
		if 件 == null:
			continue
		_判(int(件.get_meta("max")) == int(输入上限[名]),
				"%s 的上限烘在 metadata/max = %d（AS3 createTextInput 的 param3），实得 %s"
						% [名, 输入上限[名], str(件.get_meta("max"))])
		_判(件.editable, "%s 默认可编辑" % 名)
	_判(页.get_node("输入生命阈值").text == "70" and 页.get_node("输入查克拉阈值").text == "50",
			"吃药阈值默认 70 / 50（GuaJiSettingInfoData.as:46/76），实得 %s / %s"
					% [页.get_node("输入生命阈值").text, 页.get_node("输入查克拉阈值").text])

	# ── ⑦ 真点：勾一格 ⇒ 标记显形，再点 ⇒ 灭 ──
	假后端.清()
	var 起1 := _亮("复选体力符")
	await _点(_勾("复选体力符"))
	_判(_亮("复选体力符") != 起1, "真点「体力符」翻了勾（实得 %s，起点 %s）" % [str(_亮("复选体力符")), str(起1)])
	await _点(_勾("复选体力符"))
	_判(_亮("复选体力符") == 起1, "再点一次回到原样")

	# ── ⑧ 总开关联动（autoSkillHandler:249-252 与 clickCheckBoxHandler:446-456） ──
	# 出厂五枚辅助**本来就全勾**（GuaJiSettingInfoData.as:20/22/42/52/58 都是 true）
	# ⇒ 总开关开局就亮着，第一次点它是把五枚**一律灭掉**，不是点亮。
	_判(_亮("复选自动续用辅助"),
			"出厂五枚全勾 ⇒ 总开关按 :448 那五条 && 自己亮着（先把起点钉住，否则下面三条是 0 比 0）")
	await _点(_勾("复选自动续用辅助"))
	_判(not _亮("复选自动续用辅助"), "点总开关 ⇒ 自己灭（翻转一次）")
	var 五灭 := true
	for 名 in ["复选天之咒印", "复选地之咒印", "复选掌仙术", "复选创造再生", "复选不离不弃"]:
		if _亮(名):
			五灭 = false
	_判(五灭, "点总开关 ⇒ 五枚辅助**一律**跟着灭（:251 那条链式赋值 = 全置成它的状态）")
	await _点(_勾("复选掌仙术"))
	_判(not _亮("复选自动续用辅助"), "五枚里灭一枚 ⇒ 总开关自己灭（:446-456）")
	for 名 in ["复选天之咒印", "复选地之咒印", "复选掌仙术", "复选创造再生", "复选不离不弃"]:
		if not _亮(名):
			await _点(_勾(名))
	_判(_亮("复选自动续用辅助"), "五枚重新凑齐 ⇒ 总开关又亮")

	# ── ⑨ 无限时长只锁输入、不清零（updateTimeInputState:690-697） ──
	var 时件 := 页.get_node("输入战斗时间") as LineEdit
	var 原分钟 := 时件.text
	await _点(_勾("复选无限时长"))
	_判(not 时件.editable and 时件.text == 原分钟,
			"勾「无限制时长」⇒ 时间框锁掉但**数字还在**，实得 editable=%s 文=%s" % [str(时件.editable), 时件.text])
	await _点(_勾("复选无限时长"))
	_判(时件.editable, "取消勾选 ⇒ 时间框恢复可编辑")

	# ── ⑩ 输入超上限强填（:181-193 的 restrict="0-9" + CHANGE 判 maxValue） ──
	## ⚠ **真打字**，不用 `emit_signal("text_changed", …)`：10-18 实测那样整段静默不跑
	## （text 停在 "123"），门看着是"改了没反应"，其实是量具没把事件喂进去。
	var 生件 := 页.get_node("输入生命阈值") as LineEdit
	## 量具自检（10-18 实测：真打字进得去、`text_changed` 的处理却一条没跑 ⇒
	## 先把"这个信号到底连上了几条"钉住，否则下面三条是"改了没反应也算对"的反面——
	## 更坏：它红得像产品 bug，而根子在接线）。
	_判(生件.text_changed.get_connections().size() == 1,
			"量具自检：输入框的 text_changed 恰好连了 1 条（0 条 = 控制器没接、判据整段空转）")
	生件.grab_focus()
	await _打字("123")
	_判(生件.text == "100", "生命阈值打 123 被强填成上限 100，实得「%s」" % 生件.text)
	生件.text = ""
	生件.grab_focus()
	await _打字("5a5")
	_判(生件.text == "55", "字母按 restrict=0-9 收不进来，实得「%s」" % 生件.text)
	var 范件 := 页.get_node("输入战斗范围") as LineEdit
	范件.text = ""
	范件.grab_focus()
	await _打字("350")
	_判(范件.text == "99", "战斗范围打 350 被强填成上限 99（原版输入框 param3=99），实得「%s」" % 范件.text)

	# ── ⑪ 「自动出售装备」**不判 VIP**（2026-10-25 报修 5.1/5.2）─────────────────
	# 原版两道：`updateAutoSellVipState:699-717`（不够 VIP5 ⇒ disabled + 文案补 "(VIP5)"）与
	# `autoSellClickHandler:458-466`（点击时强取消 + 一句提示）；`GuajiHandler.as:276` 发之前还 `&& vipLevel >= 5`。
	# 用户点名「vip 的特权功能…不要求任何 vip 等级」⇒ 这一族整条删掉，本腿钉的是**删干净**：
	# 可用、原文案、vip=false 也点得动、那三个帮手（`func _是VIP5`/`_按VIP闸`/`重刷VIP`）源码里不再定义。
	var 售 := "复选自动出售装备"
	var _vip备份 = 会话.player_stats.get("vip", false)
	会话.player_stats["vip"] = false
	会话.emit_signal("player_stats_changed", 会话.player_stats)
	await process_frame
	## ⚠ 那一发属性帧**不能省**：原版的禁用挂在 `player_stats_changed` → `重刷VIP` → `_按VIP闸` 上，
	## 只在建窗时读一次 vip 的突变**打不红**这一条——10-25 反向对照实测：把 `disabled = not vip` 只写进
	## `_接控件`，766 条全绿。发帧之后，任何"复活的属性帧闸"都会被下面这一条抓到。
	_判(not _勾(售).disabled, "vip=false 也**不许**禁用「自动出售装备」（等级闸已删）")
	_判(_文(售) == "自动出售",
			"文案 = 期望表里的原文，**不许**再补 (VIP5) 后缀（`数据/界面/挂机窗口_期望.json`），实得「%s」" % _文(售))
	var 未勾 := not _亮(售)
	await _点(_勾(售))
	_判(_亮(售) == 未勾, "vip=false 时点一下要**真的翻**（原版这一支会强取消 ⇒ 翻了就是闸没了）")
	await _点(_勾(售))
	_判(_亮(售) != 未勾, "再点一下翻回去（连点不该越点越开）")
	var 控源: String = FileAccess.get_file_as_string("res://脚本/界面/窗口/挂机窗口.gd")
	_判(not 控源.contains("func _是VIP5") and not 控源.contains("func _按VIP闸") \
			and not 控源.contains("func 重刷VIP"),
			"挂机窗口里那三个 VIP 帮手要**真删掉**（注释里提一嘴不算活着）")
	var 挂机托管文本: String = FileAccess.get_file_as_string("res://脚本/角色/挂机托管.gd")
	_判(not 挂机托管文本.contains("func _是VIP5") and not 挂机托管文本.contains("and _是VIP5()"),
			"挂机托管的 `出[\"卖装\"]` 不该再 `and _是VIP5()`（`GuajiHandler.as:276` 那一族）")
	会话.player_stats["vip"] = _vip备份
	会话.emit_signal("player_stats_changed", 会话.player_stats)
	await process_frame

	# ── ⑫ 回帧回填（Client.as:7171 onCharConfig → setData） ──
	控制.喂服务端配置({"auotReplyHpValue": 33, "autoBattleRange": 7, "autoAvoidBoss": true,
			"autoDaZuo": false, "collectLevelType": 3, "autoSellEnabled": true})
	await process_frame
	_判(页.get_node("输入生命阈值").text == "33", "回帧的 70→33 上了屏，实得「%s」" % 页.get_node("输入生命阈值").text)
	_判(页.get_node("输入战斗范围").text == "7", "回帧的战斗范围上了屏，实得「%s」" % 页.get_node("输入战斗范围").text)
	_判(_亮("复选避开首领") and not _亮("复选回城打坐"),
			"回帧的两个布尔按值显形，实得 避开=%s 打坐=%s" % [str(_亮("复选避开首领")), str(_亮("复选回城打坐"))])
	_判((页.get_node("下拉拾取等级") as OptionButton).selected == 3,
			"回帧的等级档落在第 3 项，实得 %d" % (页.get_node("下拉拾取等级") as OptionButton).selected)

	# ── ⑬ 钮三态：实际生效的**文件名** + 手型 + 松手回常态 ──
	var 开始 := 页.get_node("钮开始") as TextureButton
	_判(开始.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
			"「开始挂机」烘了手型光标（MButton3.init:135）")
	var 停止 := 页.get_node("钮停止") as TextureButton
	_判(停止.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "「停止挂机」同理")
	_皮(开始)
	await _移到(开始.global_position + 开始.size * 0.5)
	_判(_皮(开始) == "钮底61_悬停.png", "悬停 ⇒ 实际生效的皮是 钮底61_悬停.png，实得 %s" % _皮(开始))
	_判(_字色(开始) == "ffffc3", "悬停字色 #FFFFC3（_textColors.over），实得 %s" % _字色(开始))
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.position = 开始.global_position + 开始.size * 0.5
	按.global_position = 按.position
	按.pressed = true
	root.push_input(按, true)
	await process_frame
	_判(_皮(开始) == "钮底61_按下.png", "按下 ⇒ 钮底61_按下.png，实得 %s" % _皮(开始))
	_判(_字色(开始) == "acadb2", "按下字色 #ACADB2（_textColors.down），实得 %s" % _字色(开始))
	按.pressed = false
	root.push_input(按, true)
	await process_frame
	_判(_皮(开始) == "钮底61_悬停.png" or _皮(开始) == "钮底61.png",
			"松手立刻回档（还停在按下皮 = 少了那条 button_up→STATE_UP），实得 %s" % _皮(开始))
	## 原版**没有**「挂着就禁开始 / 没挂就禁停止」这一说：全份 `GuaJiSettingWindow.as` 只对
	## `_autoSellCheckBox` 下过 `enabled`（`:708`/`:714` VIP5 闸），`_startBtn`/`_stopBtn`
	## 从头到尾没有禁用档。上一轮我自造了这条 ⇒ 没挂机时「停止挂机」是灰的，用户实机图打回。
	## 判据要**两态各走一遍**：只测一态的话「永远 disabled=false」和「按挂没挂算」分不出来。
	会话.hang_state["active"] = true
	控制.重画钮态()
	await process_frame
	_判(not 开始.disabled and _皮(开始) == "钮底61.png",
			"挂机中 开始钮仍可用、仍是常态皮（原版从不 disable 这两颗），实得 禁用=%s 皮=%s"
					% [str(开始.disabled), _皮(开始)])
	_判(not 停止.disabled and _皮(停止) == "钮底61.png",
			"同一帧 停止钮可用、常态皮，实得 禁用=%s 皮=%s" % [str(停止.disabled), _皮(停止)])
	_字色(开始)
	_判(_字色(开始) == "fcf49c", "挂机中 开始钮字色仍是常态 #FCF49C（没有灰字这一档），实得 %s" % _字色(开始))
	会话.hang_state["active"] = false
	控制.重画钮态()
	await process_frame
	_判(not 开始.disabled and not 停止.disabled and _皮(开始) == "钮底61.png",
			"停挂之后两颗仍可用、仍是常态皮，实得 %s" % _皮(开始))
	## ⚠ 上面那一次「按下 + 松开」是**真点**：`pressed` 已经跑过一遍 `_开始()`（发帧 + 关窗）。
	## 不清零就带进 ⑭⑮，会把"停止不关窗/开始关一次"判成"停止那次关了窗"——量具自己造的假红
	## （10-18 实测：⑭ 报 起停=[]、关窗=1）。
	假宿主.关窗数 = 0
	假后端.清()
	_判(假宿主.关窗数 == 0 and 假后端.起停.is_empty(),
			"量具自检：计数能清零（清不掉 = 有引用没换，那 ⑭⑮ 两条就不判了）")

	# ── ⑭ 点「停止挂机」：只发 1808:1，不发配置、**不关窗** ──
	假后端.清()
	会话.hang_state = {"active": true, "started_at": 0, "map_id": 0, "elapsed_seconds": 0}
	控制.重画钮态()
	await _点(停止)
	## ⚠ 停止这一发 **1808:1 不在这里发**：原版 `requestHang_stopHang()` 只有一个调用点
	## = `GuajiHandler:1053`（`set isStart` 停的那一刻），而这扇门里没有玩家、没有那颗循环
	## ⇒ 页面只该翻状态。"发没发"由 `测试/挂机行为回归测试.gd` 的 辰 段（离线数广播）与
	## `测试/挂机循环在线回归测试.gd`（真服务端数包）两处判（10-18 §⑲-8 拆分工时一起改的）。
	_判(假后端.起停.is_empty(),
			"停止那颗钮只翻状态、一发都不发（1808:1 归循环发），实得 %s" % str(假后端.起停))
	_判(假后端.存过.is_empty() and 假后端.卖出过.is_empty(),
			"停止不发 1283/7779（`stopGuaJi:735-739` 只派发事件），实得 存=%d 卖=%d"
					% [假后端.存过.size(), 假后端.卖出过.size()])
	_判(假宿主.关窗数 == 0, "停止不关窗（原版如此），实得 关窗 %d 次" % 假宿主.关窗数)

	# ── ⑮ 点「开始挂机」：三条上行 + 本地立刻生效 + 关窗 ──
	假后端.清()
	## 四枚出售勾选**全点上**再点开始：默认它们都是 false ⇒ 位掩码恒 0，
	## "`| (8 if ... books)` 那一位被写丢了" 那种变异就永远测不出来
	## （10-18 变异实测第 2 条就是这么漏的：掩码 0 比 0 恒真）。
	for 名 in ["复选自动出售开", "复选出售食材", "复选出售残卷", "复选出售技能书"]:
		if not _亮(名):
			await _点(_勾(名))
	_判(_亮("复选自动出售开") and _亮("复选出售食材") and _亮("复选出售残卷") and _亮("复选出售技能书"),
			"量具自检：四枚出售勾选都点上了（不点上就是 0 比 0，丢哪一位都抓不到）")
	会话.hang_state = {"active": false, "started_at": 0, "map_id": 0, "elapsed_seconds": 0}
	控制.重画钮态()
	await _点(开始)
	## 同上：`requestHang_startHang()` 原版只在 `GuajiHandler:696`「开挂后第一拍」发一次
	## ⇒ 这里必须**一发都没有**；要是页面自己发了 0，加上第一拍那次就变成两发。
	_判(假后端.起停.is_empty(),
			"开始那颗钮只翻状态、不发 1808:0（第一拍才发，`GuajiHandler:693-697`），实得 %s" % str(假后端.起停))
	_判(假后端.存过.size() == 1, "点开始 ⇒ 一条 1283 保存，实得 %d 条" % 假后端.存过.size())
	var 发: Dictionary = 假后端.存过[0] if 假后端.存过.size() == 1 else {}
	_判(发.has("autoReplyHp") and 发.has("auotReplyHpValue") and 发.has("autoBattleRange"),
			"1283 载荷用的是**原版字段名**（含 auot* 错拼），键数 %d，样例 %s" % [发.size(), str(发.keys().slice(0, 6))])
	_判(not 发.has("keyData"), "1283 保存**不带 keyData**（带了会整张替换掉快捷键表）")
	_判(发.has("autoSkillId") and 发.has("collectLevel"), "载荷里带着 data 型字段（autoSkillId / collectLevel）")
	_判(假后端.卖出过.size() == 1 and (假后端.卖出过[0] as Array).size() == 4,
			"点开始 ⇒ 一条 7779 四个 int，实得 %s" % str(假后端.卖出过))
	if 假后端.卖出过.size() == 1:
		var 卖: Array = 假后端.卖出过[0]
		var 掩: int = int(卖[0])
		## 位掩码的期望值**从页面上那四枚勾选现读**：出售那七个键走的是 7779 与本地
		## `nyaAutoSell`，**不在 1283 载荷里** ⇒ 拿 `发.get("autoSellEnabled")` 去算会恒为 0，
		## 掩码只要不是 1 就红 —— 那是判据自己造出来的假红（10-18 实测）。
		var 期望掩: int = ((1 if _亮("复选自动出售开") else 0) | (2 if _亮("复选出售食材") else 0)
				| (4 if _亮("复选出售残卷") else 0) | (8 if _亮("复选出售技能书") else 0))
		_判(掩 == 期望掩,
				"7779 第 1 个整数 = 页面上那四枚勾选的位掩码（:551），实得 %d 期望 %d" % [掩, 期望掩])
	_判(假宿主.关窗数 == 1, "点开始 ⇒ 发完就关窗（:557 onCloseBtnClick），实得 %d 次" % 假宿主.关窗数)
	_判(bool(会话.game_settings.get("auto_avoid_boss", false))
			and int(会话.game_settings.get("auto_hp_value", 0)) == 33
			and int(会话.game_settings.get("auto_battle_range", 0)) == 7,
			"★ 这套值**当场**进了本地循环要读的 game_settings（点它有请求、服务端回帧、画面有反应），实得 %s / %s / %s"
					% [str(会话.game_settings.get("auto_avoid_boss")),
						str(会话.game_settings.get("auto_hp_value")),
						str(会话.game_settings.get("auto_battle_range"))])
	# 战斗范围的单位：原版是"格"，`GuajiHandler.as:561` 边长 = 格 × 50 ⇒ 半宽 = 格 × 25
	_判(absf(_挂机半径()) - 7.0 * 25.0 < 0.01,
			"7 格换算成半宽 = 175 像素（不是把 7 当像素、也不是老口径的 100~2000），实得 %.1f" % _挂机半径())

	# ── ⑮½ 头像下那颗「挂机设置」：真点一下要开/收挂机页（原版 CharactorInfoPane.as:113-127） ──
	## 这颗钮在场景里一直画着，但以前 `mouse_filter=2(IGNORE)`、脚本里零引用 ⇒
	## 玩家看到「挂机设置」四个字，点了什么都不发生（用户 10-18 实机点出来的）。
	## 判据走真事件（`_点` = 两跳移动 + 一次左键按下），不看源码文本。
	var 板包 := load("res://场景/界面/头像面板.tscn") as PackedScene
	_判(板包 != null, "头像面板.tscn 应能加载")
	var 面板 := 板包.instantiate() as CanvasLayer
	root.add_child(面板)
	for _序 in 2:
		await process_frame
	var 挂钮 := 面板.get_node_or_null("头像区域/角色状态/AutoCombatSettings/HangLabel") as Control
	_判(挂钮 != null, "头像面板里应有「挂机设置」那颗钮（AutoCombatSettings/HangLabel）")
	if 挂钮 != null:
		## 原版那颗的坐标是**头像面板自己的局部坐标**（`CharactorInfoPane.as:116-117` x=43,y=51），
		## 所以这里按"钮相对它的父件 + 父件相对面板"合出局部值，别拿屏幕坐标比 ——
		## 面板本身还带着 5 像素的偏移（实测屏幕 x=48、局部 43）。
		var 局部 := 挂钮.position + (挂钮.get_parent() as Control).position
		_判(absf(局部.x - 43.0) <= 1.0 and absf(局部.y - 51.0) <= 2.0,
				"挂机设置钮要落在原版那颗的局部位置（原版 x=43,y=51；实得 %s）" % str(局部))
		_判(挂钮.mouse_filter == Control.MOUSE_FILTER_STOP,
				"挂机设置钮必须收鼠标（场景里原来是 IGNORE ⇒ 点了没反应）")
		_判(挂钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "挂机设置钮要手型光标")
		var 钮字 := 挂钮.get_node_or_null("HangLabelText") as Label
		_判(钮字 != null and 钮字.text == "挂机设置", "钮上的字要是「挂机设置」（原版 UI_24）")
		_判(挂钮.gui_input.get_connections().size() >= 1, "挂机设置钮的 gui_input 必须真的接上处理函数")
		var 收到: Array[String] = []
		var 接 := func(名: String) -> void: 收到.append(名)
		会话.feature_requested.connect(接)
		await _点(挂钮)
		for _序 in 2:
			await process_frame
		会话.feature_requested.disconnect(接)
		_判(收到.has("挂机"), "真点一下挂机设置钮 ⇒ 应发出 feature_requested(\"挂机\")，实得 %s" % str(收到))
	面板.queue_free()

	# ── ⑯ 消费者真的在读这几个键（文本级：不许把期望抄成被测代码里自造的键） ──
	## 10-18：循环从 `玩家.gd` 搬进了 `脚本/角色/挂机托管.gd`（原版 `GuajiHandler` 的
	## 唯一实现），所以这一节改查**新文件在读什么** + **老文件里那份确实没了**。
	## 两条都是文本判据，各有方向：正判 = 新文件必须出现；反判 = 老文件必须不出现。
	## ⚠ 只留正判等于"搬家没人管"：老那份留在原地照常跑，页面门全绿也照不出两份不一致。
	var 托管源 := FileAccess.get_file_as_string("res://脚本/角色/挂机托管.gd")
	var 玩家源 := FileAccess.get_file_as_string("res://脚本/角色/玩家.gd")
	_判(not 托管源.is_empty(), "读不到 脚本/角色/挂机托管.gd（循环的实现体没了，整节判据会假过）")
	_判(托管源.contains("auotReplyHpValue") and 托管源.contains("auotReplyMpValue"),
			"挂机托管 按**原版字段名**读吃药线（auotReplyHpValue / auotReplyMpValue，含原版那两处 auot 拼写）")
	_判(托管源.contains("autoSkillId"),
			"挂机托管 认「下拉里选中的那一招」（原版 autoSkillId，GuaJiSettingWindow.as:540）")
	_判(托管源.contains("autoBattleRange") and 托管源.contains("每格像素"),
			"活动区按 格×每格像素(50) 现算，不写死像素")
	_判(托管源.contains("_fightArea") or 托管源.contains("_活动区"),
			"挑怪/拾取都用那一个活动区矩形")
	for 旧 in ["_run_auto_combat", "_get_auto_combat_direction", "_挂机活动半径像素", "auto_hp_value"]:
		_判(not 玩家源.contains(旧),
				"玩家.gd 里还留着第二份循环的痕迹：%s（同族逻辑实现两遍 ⇒ 变异测试打不中）" % 旧)
	_判(not 玩家源.contains("< 0.45") and not 玩家源.contains("< 0.30")
			and not 托管源.contains("< 0.45") and not 托管源.contains("< 0.30"),
			"那两条写死的 45% / 30% 两处都不该再有（原版默认 70% / 50%）")
	## 会话那侧：无限时长要短路掉自动停（`_update_hang_timeout`）
	var 会话源 := FileAccess.get_file_as_string("res://脚本/单例/游戏会话.gd")
	_判(会话源.contains("auto_battle_unlimited"),
			"游戏会话._update_hang_timeout 认 auto_battle_unlimited（勾了无限制就绝不自停）")
	_判(会话源.contains("func 套用挂机配置"), "游戏会话 有 套用挂机配置（原版字段 → 本地键 的唯一翻译处）")

	# ── ⑮ 复选框交互态（`MCheckBoxF` → `MCheckBox` → `MButton3`：两张皮 + ±30/−40 派生皮）──
	## 用户 2026-10-19 打回「挂机页没有点击交互性，原版点各种内容都有点击效果，做的很死板」。
	## ⚠ 这一段**直接调组件的方法**，不产生真鼠标事件。真事件的证据在有头量具
	## `开发工具/量挂机勾态.gd`（真 `push_input`：按下与抬起落在同一节点、视口拾取到的就是这颗钮）
	## 与像素门 `开发工具/出勾态对照图.py`（屏幕上那 19×19 逐像素 == `clamp(皮+d)`、
	## 文字区一个像素都不许变）。这里钉的是**皮齐不齐、方向会不会写反、接线在不在**，
	## 把这一段当成"用户点过了"是错的（记忆「行为门要吃真事件」）。
	var 勾皮根 := "res://素材/界面/原版窗口/通用控件/复选框"
	var 缺皮: Array = []
	for 名 in ["未选", "选中"]:
		for 后 in ["", "_悬停", "_按下", "_灰"]:
			if not ResourceLoader.exists("%s%s%s.png" % [勾皮根, 名, 后]):
				缺皮.append(名 + 后 + ".png")
	_判(缺皮.is_empty(),
			"复选框两张常态皮 + 六张派生态皮都在盘上（`生成复选框态图.py` 烘的），缺 %s" % str(缺皮))
	## 方向阳性对照：**只判"三张互不相同"不够** —— 把 悬停/按下 两张的内容对调，那种门照样绿
	## （记忆第卅二种）。所以判"悬停更亮、按下更暗、禁用每像素 R=G=B"。
	var 常态 := _皮统计(勾皮根 + "未选.png")
	var 悬停 := _皮统计(勾皮根 + "未选_悬停.png")
	var 按下 := _皮统计(勾皮根 + "未选_按下.png")
	var 禁用 := _皮统计(勾皮根 + "未选_灰.png")
	_判(int(常态["数"]) > 40 and int(悬停["数"]) == int(常态["数"]) and int(按下["数"]) == int(常态["数"]),
			"壬：夹具——三张未选皮的**不透明像素数**要相同（实得 常态 %d / 悬停 %d / 按下 %d）" % [
			int(常态["数"]), int(悬停["数"]), int(按下["数"])])
	_判(int(悬停["和"]) > int(常态["和"]),
			"悬停那张要比常态**亮**（`StyleUtil.as:7-12` over=+30 是加性提亮），实得 和 %d vs %d" % [
			int(悬停["和"]), int(常态["和"])])
	_判(int(按下["和"]) < int(常态["和"]),
			"按下那张要比常态**暗**（down=−40），实得 和 %d vs %d" % [int(按下["和"]), int(常态["和"])])
	_判(bool(禁用["全灰"]) and int(禁用["数"]) > 40,
			"禁用那张每个不透明像素都要 R=G=B（`StyleUtil.getGrayFilter`，不是减亮度），实得 全灰=%s 数=%d" % [
			str(禁用["全灰"]), int(禁用["数"])])
	## 逐枚勾判结构 + 状态机。枚数取本门**自己那张手抄表**里的 27 枚（不是控制器的 勾表 ⇒ 不是自证）。
	var 勾件: Array = []
	for 件名 in 手抄:
		if String(件名).begins_with("复选"):
			勾件.append(String(件名))
	_判(勾件.size() >= 26, "壬：夹具——手抄表里要能数出 26+ 枚勾（实得 %d 枚）⇒ 少了这一段等于没判" % 勾件.size())
	var 判满 := 0
	for 件名 in 勾件:
		var 根 := 页.get_node_or_null(件名) as Control
		var 钮 := 页.get_node_or_null(件名 + "/点击区域") as Button
		var 框 := 页.get_node_or_null(件名 + "/指示框") as TextureRect
		var 记 := 页.get_node_or_null(件名 + "/标记") as TextureRect
		var 字 := 页.get_node_or_null(件名 + "/文本") as Label
		if 根 == null or 钮 == null or 框 == null or 记 == null or 字 == null:
			_判(false, "⑮ 夹具——「%s」五件不齐（根=%s 钮=%s 框=%s 记=%s 字=%s）⇒ 这一枚根本没判" % [
					件名, str(根 != null), str(钮 != null), str(框 != null), str(记 != null), str(字 != null)])
			continue
		判满 += 1
		var 原禁用 := 钮.disabled
		var 色0 := 字.get_theme_color("font_color").to_html(false)
		_判(根.has_method("刷态") and 根.has_method("_设态"),
				"「%s」的组件根要有 `刷态`/`_设态`（这一腿自己就靠 call 刷态 量禁用档，缺了它静默无效、禁用还亮着）" % 件名)
		_判(钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
				"「%s」要手型光标（`MButton3.init()` `:135` buttonMode = useHandCursor）" % 件名)
		_判(钮.flat,
				"「%s」的可点件要 flat：主题的 `按钮.png` 不许整行铺过来（原版整行的反馈只有方框那 19×19 变亮）" % 件名)
		## ⚠ Godot 4 的 `Object` **没有** `get_connections(信号名)`；`get_incoming_connections()`
		## 回来的字典里键叫 `signal`（Signal 对象）不是 `signal_name` —— 两个都踩过，当场
		## `Invalid call` / `Invalid access to property` ⇒ 整段 27 枚一条都没判，
		## 而汇总行只看得到"通过 412"。取某个信号的接线一律走 `get_signal_connection_list`。
		for 信 in ["mouse_entered", "mouse_exited", "button_down", "button_up"]:
			var 接了几 := 钮.get_signal_connection_list(信).size()
			_判(接了几 >= 1,
					"「%s」的 `%s` 至少接了一条（组件 `_ready` 里接的；一条没有 = 鼠标打到它什么也不会发生），实得 %d 条" % [
					件名, 信, 接了几])
		## 四档皮：**框与盖在上面的标记必须同一档**（悬停时点一下打勾，两张不同档会留一块亮底）。
		根.call("_设态", 1)
		_判(_态皮(框) == "复选框未选_悬停.png" and _态皮(记) == "复选框选中_悬停.png",
				"「%s」悬停档 ⇒ 两张皮都要换到 `_悬停`，实得 框=%s 记=%s" % [件名, _态皮(框), _态皮(记)])
		根.call("_设态", 2)
		_判(_态皮(框) == "复选框未选_按下.png" and _态皮(记) == "复选框选中_按下.png",
				"「%s」按下档 ⇒ 两张皮都要换到 `_按下`，实得 框=%s 记=%s" % [件名, _态皮(框), _态皮(记)])
		根.call("_设态", 0)
		_判(_态皮(框) == "复选框未选.png" and _态皮(记) == "复选框选中.png",
				"「%s」松手/移开 ⇒ 回**常态**（`MButton3.as:103-108` 松手回 STATE_UP，不是 OVER），实得 框=%s 记=%s" % [
				件名, _态皮(框), _态皮(记)])
		钮.disabled = true
		根.call("刷态")
		_判(_态皮(框) == "复选框未选_灰.png" and _态皮(记) == "复选框选中_灰.png",
				"「%s」禁用 ⇒ 要压倒悬停/按下、两张皮都成 `_灰`（`MButton3.as:333` + getGrayFilter），实得 框=%s 记=%s" % [
				件名, _态皮(框), _态皮(记)])
		## 重新可用要**退回常态**而不是回到悬停（`MButton3.as:461-470`；且 `BaseButton.disabled`
		## 把 mouse_filter 收成 IGNORE ⇒ 不会有人替它发 exited）。
		根.call("_设态", 1)
		钮.disabled = false
		根.call("刷态")
		_判(_态皮(框) == "复选框未选.png",
				"「%s」由禁用改回可用 ⇒ 皮要回常态（实得 %s）" % [件名, _态皮(框)])
		## 字色**不许**跟着换态：`createCheckBox` 走 `MButton3.as:444-451` 的 `textColor`，
		## 它把 up/over/down/disabled 四档写成同一个数 ⇒ 换色就是自己加戏。
		_判(字.get_theme_color("font_color").to_html(false) == 色0,
				"「%s」走完四档文字色还是 %s（原版四档同一个值），实得 %s" % [
				件名, 色0, 字.get_theme_color("font_color").to_html(false)])
		钮.disabled = 原禁用
		根.call("刷态")
	_判(判满 == 勾件.size(),
			"⑮ 自计到：%d 枚勾要每枚都判到底（实得 %d）⇒ 少了就是中途报错，这一段的汇总不可信" % [
			勾件.size(), 判满])

	跑完了 = true
	# 还原被本门改过的会话状态（内存这一头）。
	# ⚠ "不落存档"这句以前是**假设**、现在是**判据**：`_initialize` 里 `_还原玩档()` 按字节兜
	# 玩家数据.json，下面兜 挂机自动出售.json。离线门写 user:// 会把本轮夹具值带进他的客户端。
	会话.hang_state = {"active": false, "started_at": 0, "map_id": 0, "elapsed_seconds": 0}
	会话.player_stats["job"] = _职备份
	会话.learned_skills.assign(_技备份)
	## 还原 `user://挂机自动出售.json`（点「开始挂机」那一下真写了它）。
	## ⚠ 两份工程同名 ⇒ **共用同一个 user://**，留着就会把本轮的值带进他的客户端。
	if 出售存档原有:
		var f := FileAccess.open("user://挂机自动出售.json", FileAccess.WRITE)
		if f != null:
			f.store_buffer(出售存档字节)
			f.close()
		_判(FileAccess.get_file_as_bytes("user://挂机自动出售.json") == 出售存档字节,
				"出门自检：出售存档回到进门时的字节")
	else:
		DirAccess.remove_absolute(出售存档路)
		_判(not FileAccess.file_exists("user://挂机自动出售.json"),
				"出门自检：进门时没这个文件 ⇒ 出门也必须没有")


func _挂机半径() -> float:
	return clampf(float(会话.game_settings.get("auto_battle_range", 20)), 0.0, 99.0) * 25.0


class 假后端类 extends Node:
	var in_game := true
	var 起停: Array = []
	var 存过: Array = []
	var 卖出过: Array = []
	var 查过 := 0

	func 清() -> void:
		起停.clear()
		存过.clear()
		卖出过.clear()
		查过 = 0

	func request_hang_start() -> bool:
		起停.append(0)
		return true

	func request_hang_stop() -> bool:
		起停.append(1)
		return true

	func request_hang_config_query() -> bool:
		查过 += 1
		return true

	func request_hang_config_save(配置: Dictionary) -> bool:
		存过.append(配置.duplicate(true))
		return true

	func request_auto_sell_config(掩码: int, 等级: int, 职业: int, 品质: int) -> bool:
		卖出过.append([掩码, 等级, 职业, 品质])
		return true


class 假宿主类 extends Control:
	var 页面: Control
	var 关窗数 := 0
	var 提示: Array[String] = []

	func _instantiate_page(场景: PackedScene) -> Control:
		页面 = 场景.instantiate() as Control
		add_child(页面)
		return 页面

	func _show_hint(文: String) -> void:
		提示.append(文)

	func close() -> void:
		关窗数 += 1
