extends SceneTree

## 「人物面板家族格」门（2026-11-01 用户报修：「已经有了家族，但在角色人物面板，家族依旧是 -」）。
##
## 原版真值：
##   * `Client.as:2470-2481 onBanghuiInfo`：收到自族身份帧就 `API.dataCenter.guildName = param1.name`；
##   * `DataCenter.as:1455 getDataForCharacterInfoWindow()`：`_loc1_.family = this.guildName`；
##   * `CharPane.as:228`：`familyCell.text = param1.family ? param1.family : "-"`（空串按 falsy 落 `-`）。
##
## 本工程的病根是两层，缺一层症状都还是 `-`：
##   ① `离线示例数据.player_stats` **根本没有 `family` 这个键** —— 面板读
##      `属性.get("family", "-")`，键不在就永远 `-`；
##   ② 后端早把 `1552:1` / `1552:15` 的自族身份解析进 `authoritative_guild` 了，
##      却**没有一处**把它落到人物面板读的那份属性上。
##
## 所以本门**不手搓** `player_stats`，而是把真帧文本灌进真派发器（`_handle_bridge_text`），
## 让 解析 → `_同步家族到人物属性` → `player_stats_changed` → 功能窗口重建 → 人物面板
## 这整条链自己跑，再从**渲染出来的节点**读那一格的字。任一环断了对应那条腿就红。
##
## 运行：`Godot --headless --path . --script res://测试/人物面板家族格回归测试.gd`

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 门存档快照 := preload("res://测试/门存档快照.gd")
const 默认地图 := "101010000"

## 期望值一律**字面量**：帧里的名字、面板上该出现的字，两头都手写在这里。
## （拿 `authoritative_guild` / 会话现算当期望 = 自洽比较，对"同步写错了"免疫，本工程踩过。）
const 帧_摘要甲 := "1552:15:7:木叶家族:欢迎回家:1721552400:42:千手柱间"
const 帧_摘要乙 := "1552:15:7:木叶新族:欢迎回家:1721552400:42:千手柱间"
const 帧_详情 := "1552:1:9:砂隐村:新公告:12:我爱罗:0:0:1721552400:5:砂之纹:2:-"
const 帧_退族 := "1552:14:4242:木叶忍者"

var _失败: Array[String] = []
var _已记 := 0
var _秒 := 0.0
## 家族那几条腿真跑了几条（期望 6）。GDScript 运行期错误只掐断当前这一段、
## 后面的 `_记` 全不执行 —— 不给计数，整段被跳过后门照样可能打「通过」。
var _家族腿数 := 0
var _文件前: Dictionary = {}


func _initialize() -> void:
	call_deferred("_跑")


func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 90.0:
		printerr("人物面板家族格回归测试：看门狗超时（90s）—— 中途崩了没走到收尾")
		quit(1)
		return true
	return false


func _记(条件: bool, 说明: String) -> void:
	_已记 += 1
	if not 条件:
		_失败.append(说明)


func _跑() -> void:
	_文件前 = 门存档快照.全快照()
	# ⚠ 无头视口是 (64,64) —— 后面的重建/取节点都按实机尺寸走，先钉住（门卫生规矩②）
	root.size = Vector2i(960, 560)
	var 场景路径: String = 地图资源.playable_scene_path(默认地图)
	if not 场景路径.contains("场景/生成/"):
		_失败.append("加载的不是烘焙场景（%s）—— 实机走的是 playable_scene_path()" % 场景路径)
		_收尾()
		return
	var 打包 := load(场景路径) as PackedScene
	if 打包 == null:
		_失败.append("无法加载地图场景：%s" % 场景路径)
		_收尾()
		return
	var 场景 := 打包.instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _帧 in range(5):
		await process_frame
	var 后端 := root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	var 管理 := 场景.get_node_or_null("窗口管理")
	if 后端 == null or 会话 == null or 管理 == null:
		_失败.append("依赖节点不完整（BackendConnection / GameSession / 窗口管理）")
		_收尾()
		return

	# ① 模型键在 —— 用户报修的第一层：键不在，后端写哪儿都没用
	_家族腿数 += 1
	_记((会话.player_stats as Dictionary).has("family"),
		"离线示例数据的 player_stats 没有 family 键 —— 面板读 `属性.get(\"family\", \"-\")`，键不在就恒为 -")

	var 窗: Node = 管理.call("取或建窗口", "人物")
	if 窗 == null:
		_失败.append("窗口管理没能建出「人物」这一页")
		_收尾()
		return
	窗.call("打开")
	await process_frame
	await process_frame

	# ② 未入族：`1552:14` 退族帧 ⇒ 面板 `-`
	await _灌帧并取格(后端, 窗, 帧_退族, "-", "退族帧之后（未入族）")
	# ③ 摘要帧 `1552:15`（服务端登录/入族时发的那条）⇒ 面板出现真族名
	await _灌帧并取格(后端, 窗, 帧_摘要甲, "木叶家族", "摘要帧 1552:15（木叶家族）")
	# ④ 族名被改（同一条 15 帧带新名字）⇒ 面板跟着变，不是只在开窗那一刻读一次
	await _灌帧并取格(后端, 窗, 帧_摘要乙, "木叶新族", "改名后的摘要帧（木叶新族）")
	# ⑤ 详情帧 `1552:1`（14 字段布局）⇒ 面板跟着换成详情里的名字
	await _灌帧并取格(后端, 窗, 帧_详情, "砂隐村", "详情帧 1552:1（砂隐村）")
	# ⑥ 再退族 ⇒ 回到 `-`（不能停在上一族的名字上）
	await _灌帧并取格(后端, 窗, 帧_退族, "-", "再次退族")
	# ⑦ 断线复位：入族后再断，家族名要跟着清掉（否则换号/重连后人物面板还挂着上一族）
	await _灌帧并取格(后端, 窗, 帧_摘要甲, "木叶家族", "断线前的摘要帧（木叶家族）")
	_家族腿数 += 1
	后端.call("disconnect_backend")
	for _帧 in range(4):
		await process_frame
	_记(str(会话.player_stats.get("family", "<无键>")) == "",
		"断线后 player_stats.family 应为空串，实为「%s」" % str(会话.player_stats.get("family", "<无键>")))
	var 格 := _家族格(窗)
	_记(格 != null and 格.text == "-",
		"断线后「家族」格应回到「-」，实为「%s」" % (格.text if 格 != null else "<找不到格子>"))

	_收尾()


## 灌一条 1552 文本帧、等重渲染、读「信息区/家族格/数值」那一格。
## ⚠ 页面整棵重建过（`_render_page` 先 remove + queue_free 旧页）⇒ 每次都要重新取节点。
func _灌帧并取格(后端: Node, 窗: Node, 帧: String, 期望: String, 名: String) -> void:
	_家族腿数 += 1
	后端.call("_handle_bridge_text", 帧)
	for _帧 in range(4):
		await process_frame
	var 格 := _家族格(窗)
	_记(格 != null and 格.text == 期望,
		"%s 之后「家族」格应为「%s」，实为「%s」" % [名, 期望, 格.text if 格 != null else "<找不到格子>"])


func _家族格(窗: Node) -> Label:
	var 页 := 页面节点(窗)
	if 页 == null:
		return null
	var 面板 := 页.get_node_or_null("原版人物属性面板") as Control
	if 面板 == null:
		return null
	return 面板.get_node_or_null("信息区/家族格/数值") as Label


func 页面节点(窗: Node) -> Node:
	var 内容 := 窗.get("_content") as Node
	if 内容 == null:
		return null
	for 子 in 内容.get_children():
		if 子.get_node_or_null("原版人物属性面板") != null:
			return 子
	return null


func _收尾() -> void:
	_记(_家族腿数 == 8, "家族腿只跑了 %d/8 条 —— 中途有运行期错误把这一段掐了，别让剩下的判据假绿" % _家族腿数)
	_记(门存档快照.全还原(_文件前), "user:// 没能按字节还原（跑批器会点名「写档」）")
	if _失败.is_empty():
		print("人物面板家族格回归测试：通过（%d 条断言：键在 · 退族 - · 摘要帧 · 改名 · 详情帧 · 再退族）" % _已记)
		quit(0)
		return
	for 项 in _失败:
		push_error("人物面板家族格：" + 项)
	print("人物面板家族格回归测试：失败 %d / %d 条 —— %s" % [_失败.size(), _已记, ", ".join(_失败)])
	quit(1)
