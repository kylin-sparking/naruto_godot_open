extends SceneTree

## 右下角「获得提示」（原版 `NoticePnl`）的**有头量具**：把真 HUD 摆起来，
## 从 `后端连接` 发几条真文案，拍玩家会看到的那一块，并回读几何。
##
## 为什么必须**有头**：无头拿不到视口图像（工程里反复踩过，见 godot-cli-verify-harness）。
## 为什么只摆 HUD、不摆整张地图：`场景/地图/地图场景.tscn` 在有头的探针进程里进不去
##   （2026-10-10 实测：起 5 分钟没出一帧，只能杀掉）⇒ 这里只实例化 HUD 那一层，
##   底下铺一块中性灰当世界，**这一列的位置/右对齐/折行/淡出没变**，变的只是背景。
## 跑法：`Godot --path . --script res://开发工具/截获得提示页.gd`
##
## 三张图各看一件事：
##   01_满八行.png    一次来 10 条 ⇒ 屏上只剩最新 8 行、右对齐、越新的越靠下（贴在 W−250 / H−125 那块）
##   02_折行与配色.png  长文案折行（原版 wordWrap）+ 绿标签黄数字的两档色 + 黑色描边
##   03_淡出中.png     过了 10 秒整块一起淡（alpha 0.5 那一拍），不是某一行单独消失
##
## ⚠ 只发信号 + 建控件，不登录、不点任何按钮 ⇒ 不许写 `user://`（末尾按字节比对，动了就 exit 3）。

const HUD场景路 := "res://场景/界面/小地图面板.tscn"
const 出目录 := "res://测试/截图/获得提示"
const 几何表 := "res://测试/截图/获得提示/几何.txt"
const 后端路 := "/root/BackendConnection"

var 行: Array[String] = []


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_跑.call_deferred()


func _存档() -> String:
	if not FileAccess.file_exists("user://玩家数据.json"):
		return "<无文件>"
	var f := FileAccess.open("user://玩家数据.json", FileAccess.READ)
	return "<打不开>" if f == null else f.get_as_text()


func _记(说: String) -> void:
	行.append(说)
	print(说)


func _跑() -> void:
	root.size = Vector2i(960, 560)		# ⚠ 必须在建场景之前钉（视口图按工程设置走，见 skill）
	DirAccess.make_dir_recursive_absolute(出目录)
	var 前 := _存档()
	var 后端 = root.get_node_or_null(后端路)
	if 后端 == null:
		_记("!! 拿不到 /root/BackendConnection")
		_写()
		quit(2)
		return
	var 包 = load(HUD场景路)
	if 包 == null:
		_记("!! HUD 场景 load 不出来（%s）" % HUD场景路)
		_写()
		quit(2)
		return
	## 底下铺一块中性灰当"世界"，好让右对齐/描边/折行在图上一眼看得出来
	var 底 := ColorRect.new()
	底.color = Color(0.16, 0.18, 0.22, 1.0)
	底.size = Vector2(960, 560)
	底.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(底)
	var HUD = (包 as PackedScene).instantiate()
	root.add_child(HUD)
	await _帧(8)
	if HUD == null:
		_记("!! HUD 没建起来")
		_写()
		quit(2)
		return
	var 层 := HUD.get_node_or_null("获得提示层") as Control
	_记("HUD = %s　获得提示层 = %s" % [HUD.get_path(), "有" if 层 != null else "**没有**"])
	if 层 == null:
		_记("!! 运行期 HUD 上没挂到那一层 ⇒ 后面三张都白拍")
		_写()
		quit(2)
		return
	_记("层 position = %s（视口 %s ⇒ 期望 (%.0f, %.0f)）"
		% [str(层.position), str(root.get_visible_rect().size), 960.0 - 250.0, 560.0 - 125.0])
	_记("层 mouse_filter = %d（0 = STOP，2 = IGNORE）" % 层.mouse_filter)
	层.set_process(false)		# 手动喂 _process，拍照时机由我定，不让引擎自己推进计时

	# ── 01：一次来 10 条，屏上留最新 8 行 ──
	层.call("清空")
	for i in 10:
		后端.emit_signal("获得提示", 文(i))
	await _帧(3)
	_几何(层, "01 满八行")
	_拍("01_满八行")

	# ── 02：一条超长（要折行）+ 一条普通 ──
	层.call("清空")
	后端.emit_signal("获得提示", "[color=#00cc33]获得了[color=#f0dd06]1[/color]个[color=#f0dd06]"
		+ "十枚一阶查克拉卡（可交易）与一盒拉面（小）外加两把竹制忍杖"
		+ "[/color][/color]")
	后端.emit_signal("获得提示", "[color=#00cc33]金币 [color=#f0dd06]+300[/color][/color]")
	await _帧(3)
	_几何(层, "02 折行与配色")
	_拍("02_折行与配色")

	# ── 03：停 10 秒后淡到 0.5 那一拍 ──
	层.call("清空")
	后端.emit_signal("获得提示", "[color=#00cc33]经验 [color=#f0dd06]+160[/color][/color]")
	后端.emit_signal("获得提示", "[color=#00cc33]查克拉上限 [color=#f0dd06]+20[/color][/color]")
	await _帧(2)
	for i in 20:
		层.call("_process", 0.5)		# 10.0 秒：原版这一拍 alpha 仍是 1
	_记("03 满 10 秒那一拍 alpha = %.2f（期望 1.00）" % 层.modulate.a)
	for i in 5:
		层.call("_process", 0.05)	# 再走 5 拍 ⇒ 0.5
	_记("03 再走 5 拍 alpha = %.2f（期望 0.50）行数 = %d" % [层.modulate.a, int(层.call("行数"))])
	await _帧(2)
	_拍("03_淡出中")
	for i in 5:
		层.call("_process", 0.05)
	_记("03 再走 5 拍（共 10 拍）alpha = %.2f 行数 = %d（期望整块清空 ⇒ 0）"
		% [层.modulate.a, int(层.call("行数"))])
	层.set_process(true)

	var 后 := _存档()
	_记("存档 %s（长度 %d → %d）" % ["没动" if 前 == 后 else "**被写了**", 前.length(), 后.length()])
	_写()
	quit(0 if 前 == 后 else 3)


## 十条样例：把语言包那一族都走一遍（经验/金币/绑定金币/点券/元宝/精华/上下限/攻速/移速/道具）
func 文(i: int) -> String:
	var 案 = [
		"[color=#00cc33]经验 [color=#f0dd06]+160[/color][/color]",
		"[color=#00cc33]金币 [color=#f0dd06]+300[/color][/color]",
		"[color=#00cc33]绑定金币 [color=#f0dd06]-200[/color][/color]",
		"[color=#00cc33]点券 [color=#f0dd06]+8[/color][/color]",
		"[color=#00cc33]元宝 [color=#f0dd06]+1[/color][/color]",
		"[color=#00cc33]精华 [color=#f0dd06]+25[/color][/color]",
		"[color=#00cc33]生命值上限 [color=#f0dd06]+40[/color][/color]",
		"[color=#00cc33]移动速度 [color=#f0dd06]+2[/color][/color]",
		"[color=#00cc33]获得了[color=#f0dd06]1[/color]个[color=#f0dd06]白羽扇[/color][/color]",
		"[color=#00cc33]失去了[color=#f0dd06]3[/color]个[color=#f0dd06]拉面（小）[/color][/color]",
	]
	return String(案[i % 案.size()])


func _几何(层: Control, 说: String) -> void:
	_记("%s：行数 = %d，历史 = %d" % [说, int(层.call("行数")), (层.get("历史") as Array).size()])
	var 序 := 0
	for 子 in 层.get_children():
		if not (子 is RichTextLabel):
			continue
		var 条 := 子 as Control
		_记("    [%d] y=%.1f 高=%.1f 宽=%.1f 右对齐=%d 描边=%d 文=%s" % [序,
			条.position.y, 条.size.y, 条.size.x,
			(条 as RichTextLabel).horizontal_alignment,
			(条 as RichTextLabel).get_theme_constant("outline_size"),
			(条 as RichTextLabel).text])
		序 += 1


func _拍(名: String) -> void:
	var 图 := root.get_texture().get_image()
	var 错 := 图.save_png(出目录 + "/" + 名 + ".png")
	_记("拍 %s.png：%s" % [名, "OK" if 错 == OK else "失败(%d)" % 错])


func _写() -> void:
	var f := FileAccess.open(几何表, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行) + "\n")
		f.close()
