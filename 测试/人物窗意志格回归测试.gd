extends SceneTree

## 「人物面板意志格」门（2026-10-21）—— 用户实机报：「意志装备上以后，人物面板的意志处
## 没有显示……面板上应该显示意志数，鼠标放上去，会显示所有装备上的意志」。
##
## 钉三样（全走玩家端：真地图场景 → 窗口管理 → 功能窗口._render_page → 人物窗口.渲染，
## 与实机同一条渲染路，不 stub 任何节点）：
##   ① **公式**：意志力 = Σ rongHeExp ÷ 30。⚠️ rongHeExp **≠** 协议第 4 列 exp ——
##      黄 1200 固定、其余 `levelUp.level1[色名] + exp`（`YiZhiData.rongHeExp:92-101`）。
##      原实现只加 exp ⇒ 新学得的蓝意志（exp=0）也显示 0（用户报的"没有显示"的根因）。
##   ② **格子里显示这个数**，且随穿戴重渲染换数（穿 3 件 → 47；全卸 → 0）。
##   ③ **悬停列出所有装备上的意志**（原版 `CharPane.setYiZhiData:290-299` 挂在 `yizhiCell` 上的
##      `_yiZhiTip`，正文 `YiZhiManager.getYiZhiPropToopTioInfo:392-405`）：首行「当前意志：N」
##      + 每件一行 `<彩>名 Lv.级</> <橙>desc</>`，desc 的 `#value#` 按等级替换
##      （`YiZhiData.getYiZhiDesc:147-155`）。
## 反假绿：公式若回退成"只加 exp"，② 的 47 这条直接红（新蓝件会算成 0）。

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 默认地图 := "101010000"

## 三件穿戴样本（id/色/槽/经验/等级）—— 数值刻意错开，公式三项各钉一边：
##   301 强悍 蓝 新件 exp=0  ⇒ rongHeExp = 60+0   = 60
##   601 羁绊 黄 新件 exp=0  ⇒ rongHeExp = 1200   = 1200（黄特例，不走 level1）
##   302 坚韧 蓝 旧件 exp=100 ⇒ rongHeExp = 60+100 = 160
## 意志力 = (60+1200+160)/30 = 47（int 截断）
const 样本 := [
	{"id": 301, "color": 3, "slot": -1, "exp": 0, "level": 1},
	{"id": 601, "color": 6, "slot": -2, "exp": 0, "level": 1},
	{"id": 302, "color": 3, "slot": -3, "exp": 100, "level": 2},
]

var _failures: Array[String] = []
var _已记 := 0


func _initialize() -> void:
	call_deferred("_run")


func _记(条件: bool, 说明: String) -> void:
	_已记 += 1
	if not 条件:
		_failures.append(说明)


func _run() -> void:
	# ⚠ 无头视口是 (64,64) —— 不钉尺寸，后面按坐标做的任何事都落不进视口（门卫生规矩②）
	root.size = Vector2i(960, 560)

	# ① 公式（纯数据，不依赖 UI）：黄特例 / 色系基础+exp / 灰与未知色 = 0
	var 黄 := 游戏数据.意志融经验({"id": 601, "color": 6, "exp": 0})
	var 蓝新 := 游戏数据.意志融经验({"id": 301, "color": 3, "exp": 0})
	var 蓝旧 := 游戏数据.意志融经验({"id": 302, "color": 3, "exp": 100})
	var 灰 := 游戏数据.意志融经验({"id": 101, "color": 1, "exp": 999})
	var 未知 := 游戏数据.意志融经验({"id": 301, "color": 0, "exp": 999})
	_记(黄 == 1200, "黄意志融经验应为 1200（固定），实为 %d" % 黄)
	_记(蓝新 == 60, "新蓝意志融经验应为 level1[blue]=60，实为 %d（只加 exp 就是 0）" % 蓝新)
	_记(蓝旧 == 160, "蓝意志融经验应为 60+exp=160，实为 %d" % 蓝旧)
	_记(灰 == 0, "灰意志融经验应为 0（levelUp.level1 没有 gray），实为 %d" % 灰)
	_记(未知 == 0, "未知色融经验应为 0，实为 %d" % 未知)

	# ②③ UI 链
	var 场景路径: String = 地图资源.playable_scene_path(默认地图)
	if not 场景路径.contains("场景/生成/"):
		_failures.append("加载的不是烘焙场景（%s）—— 实机走的是 playable_scene_path()" % 场景路径)
		_收尾()
		return
	var 打包 := load(场景路径) as PackedScene
	if 打包 == null:
		_failures.append("无法加载地图场景：%s" % 场景路径)
		_收尾()
		return
	var 场景 := 打包.instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _帧 in range(5):
		await process_frame

	var 会话 := root.get_node_or_null("GameSession")
	var 管理 := 场景.get_node_or_null("窗口管理")
	if 会话 == null or 管理 == null:
		_failures.append("依赖节点不完整（GameSession / 窗口管理）")
		_收尾()
		return

	var 窗: Node = 管理.call("取或建窗口", "人物")
	if 窗 == null:
		_failures.append("窗口管理没能建出「人物」这一页")
		_收尾()
		return

	# 真开窗路径（`窗口管理.打开` → 功能窗口.打开 → open_page ⇒ _overlay.visible = true）
	# ⇒ 后面的活刷新（`spirit_state_changed → _refresh_current`）才跑得起来
	窗.call("打开")
	await process_frame
	await process_frame

	# 穿上三件，然后**只发信号**（不直接 _render_page）—— 这就是实机的链路：
	# 穿上意志 → 服务端回 cmd 帧 → 会话发 spirit_state_changed → 当前页重渲染
	会话.set("spirit_equipped", 样本.duplicate(true))
	会话.spirit_state_changed.emit()
	await process_frame
	await process_frame
	await process_frame

	var 面板 := _找人物面板(窗)
	if 面板 == null:
		_failures.append("渲染出来的页面里找不到 原版人物属性面板")
		_收尾()
		return

	# ② 格子数 = 47（公式连了 + 渲染连了）
	var 值 := 面板.get_node_or_null("信息区/意志格/数值") as Label
	_记(值 != null and 值.text == "47",
		"穿上 3 件意志后「意志」格应显示 47，实为 %s" % (值.text if 值 != null else "<无>"))

	# 格必须收得到悬停：场景里 `mouse_filter = 2`（IGNORE），渲染时由 `_挂文字提示` 改 STOP/PASS
	# ⚠️ 合并 `意志模块` 时分支另有 `_接意志格悬停` 把格改 STOP、挂场景里的 `意志提示框`；
	#    主线 §3.234 的十处悬停框架（`_挂文字提示` → 页面内 `文字提示_意志值`，格设 PASS）已取代它，
	#    本门赌的是"格收得到悬停"，不赌具体档位（PASS/STOP 都行，IGNORE 才是不通）。
	var 格 := 面板.get_node_or_null("信息区/意志格") as Control
	_记(格 != null and int(格.mouse_filter) != int(Control.MOUSE_FILTER_IGNORE),
		"意志格没收悬停（mouse_filter 仍是 IGNORE ⇒ mouse_entered 不触发）")

	# ③ 悬停 ⇒ 提示框亮出来，文案列全三件（彩名/等级/橙 desc，#value# 已按级替换）
	# ⚠️ hex 色号大小写随图鉴 JSON（#1E90FF 原样进 BBCode，本工程的转换器不改大小写）⇒ 一律转小写比
	var 页 := 页面节点(窗)
	var 框 := 页.get_node_or_null("文字提示_意志值") as Control if 页 != null else null
	_记(框 != null, "页面里没有 `文字提示_意志值` 节点（§3.234 十处悬停框架那枚 MToolTipText）")
	if 格 != null and 框 != null:
		格.mouse_entered.emit()
		await process_frame
		var 文 := 框.get_node_or_null("文字") as RichTextLabel
		var 文串 := (文.text if 文 != null else "").to_lower()
		_记(框.visible, "悬停意志格后提示框没亮出来")
		_记(文串.contains("当前意志：47"), "提示首行应是「当前意志：47」，实为 %s" % 文串.replace("\n", "⏎"))
		_记(文串.contains("[color=#1e90ff]强悍 lv.1[/color]"), "提示缺 强悍 那一行（实为 %s）" % 文串.replace("\n", "⏎"))
		_记(文串.contains("[color=#ff9100]攻击+40[/color]"), "提示缺 强悍 的 desc（攻击+40，#value# 要按级替换）")
		_记(文串.contains("[color=#fff000]羁绊 lv.1[/color]"), "提示缺 羁绊 那一行")
		_记(文串.contains("[color=#ff9100]经验+1200[/color]"), "提示缺 羁绊 的 desc")
		_记(文串.contains("[color=#1e90ff]坚韧 lv.2[/color]"), "提示缺 坚韧 那一行")
		_记(文串.contains("[color=#ff9100]防御+60[/color]"), "提示缺 坚韧 的 desc（防御+60）")
		# 移开要收起（原版 `removeTip`）
		格.mouse_exited.emit()
		await process_frame
		_记(not 框.visible, "移开鼠标后提示框没收起来")

	# 全卸 ⇒ 0，且悬停只剩首行（同样只发信号）
	会话.set("spirit_equipped", [])
	会话.spirit_state_changed.emit()
	await process_frame
	await process_frame
	await process_frame
	# ⚠️ 页面整棵重建过（_render_page 先 remove+queue_free 旧页）⇒ 面板引用必须**重新取**
	面板 = _找人物面板(窗)
	值 = 面板.get_node_or_null("信息区/意志格/数值") as Label if 面板 != null else null
	格 = 面板.get_node_or_null("信息区/意志格") as Control if 面板 != null else null
	框 = 页面节点(窗).get_node_or_null("文字提示_意志值") as Control if 页面节点(窗) != null else null
	_记(值 != null and 值.text == "0", "全卸后「意志」格应显示 0，实为 %s" % (值.text if 值 != null else "<无>"))
	if 格 != null and 框 != null:
		格.mouse_entered.emit()
		await process_frame
		var 空文 := (框.get_node_or_null("文字") as RichTextLabel)
		var 空串 := 空文.text if 空文 != null else ""
		_记(空串 == "当前意志：0", "无穿戴时提示应只有「当前意志：0」一行，实为 %s" % 空串.replace("\n", "⏎"))
		格.mouse_exited.emit()

	_收尾()


func 页面节点(窗: Node) -> Node:
	var 内容 := 窗.get("_content") as Node
	if 内容 == null:
		return null
	for 子 in 内容.get_children():
		if 子.get_node_or_null("原版人物属性面板") != null:
			return 子
	return null


func _找人物面板(窗: Node) -> Control:
	var 页 := 页面节点(窗)
	if 页 == null:
		return null
	return 页.get_node_or_null("原版人物属性面板") as Control


func _收尾() -> void:
	if _failures.is_empty():
		print("人物窗意志格回归测试：通过（%d 条断言：公式 5 + 格值/悬停/提示文/卸下归零）" % _已记)
		quit(0)
		return
	for 项 in _failures:
		push_error("人物窗意志格：" + 项)
	print("人物窗意志格回归测试：失败 %d / %d 条 —— %s" % [_failures.size(), _已记, ", ".join(_failures)])
	quit(1)
