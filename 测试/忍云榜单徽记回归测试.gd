extends SceneTree

## 头顶那摞"忍云"榜单徽记（用户 2026-10-20 报修 5「排行榜未实装 + 榜上忍云没显示」剩下的那半条）。
##
## 原版两条线，一条都不许猜：
##   · `Character.updatePaiHangTitle:1184-1203` —— 空表 `removeChild`、非空才 `addChild` +
##     `doTitleLayer`；`doTitleLayer:1316-1348` 在没有护航/暮叶战时把板钉在 **`y = -120`**。
##   · `PaiHangTipPane.redraw:22-46` —— 逐枚 `y = -(长度-1-序号)*28`、**x 一个字都不写**，
##     取图走 `PicTool.getPaiHangIcon(榜号)`（= `Etc.PaiHangBang[榜号].iconLink` 查表），
##     查不到退 `getPaiHang3V3Icon(榜号 - 30)`（= `Etc.PaiHangBang_Hide[榜号-30].iconLink`）。
##
## ⚠ 两处最容易猜错的地方，都在本门里钉死：
##   ① **榜号 ≠ 图号**：23 条里 15 条不跟号数走（`5↔9` 互换、`10..22` 整体错一格到 `11..24`），
##      于是图 `_14` 在正表里根本不出现，只能由榜号 30 走兜底那条拿到。
##   ② **注册点不是画布中心**：ffdec 出的 PNG 是按墨迹裁的，注册点丢了。JPEXS 转 XML 量到
##      每枚 `shapeBounds` 的 `Ymin` ⇒ 注册点 = `(-Xmin/20, -Ymin/20)` = **下中**，
##      141 宽那批 y=26、143 宽那批（`_14.._17`）y=25。其中 `_0/_1/_2/_3/_4/_5/_9/_12` 八枚
##      画布只有 25 高 ⇒ 注册点落在**画布下边缘再往下 1 px**（原版那 1 px 是透明空行，
##      裁图裁掉了）。量测脚本 `开发工具/_probe_忍云注册点.py` / `_probe_忍云尺寸.py`。
##
## 用法：Godot --headless --path . --script res://测试/忍云榜单徽记回归测试.gd

const 测试后端 := preload("res://测试/测试后端连接.gd")
const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 默认地图 := "101010000"
const 徽记图根 := "res://素材/特效/Effect_PaiHangBang/%s/1.png"
## 25 枚图名后缀（`Effect_PaiHangBang_0..24`），逐张量素材腿用。
const 全部图名 := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]
## ⑤′ 像素内容账。**这 25 张不是 ffdec `-export sprite` 的原样输出**：
## 那套导出把 RGB 又除了一次 alpha（实测 `asset ≈ stored/a`，低 alpha 处被放大成
## 蓝/绿/红彩点 —— 用户 2026-10-25 报「十大仙人/忍术仙人/传说忍者/十大瞳术两侧云很脏」）。
## 现由 `python 开发工具/重导忍云素材.py --写` 换回 **SWF 存储 RGB**、alpha 一个字节不动；
## 这里钉 md5，防哪天顺手又用 ffdec 重导把噪声带回来。SWF 真更新时重导完同步改这张表。
const 素材md5 := {
	0: "7f56f74c82d53f9734f8138b67948627", 1: "827e04cfba38596d38e57f57a5e79b22",
	2: "6002856c519e5b907cacc792e881749f", 3: "ab9cdab9e18d88cc02388188e5c7f695",
	4: "ae58a885b2ea772563f3096d5a40efa9", 5: "3b49bf347faa408dd2f432b72f588b10",
	6: "328a35dcaad05488d4422e92c87d3d09", 7: "b93f4109d92b04a62d316c994faa86ac",
	8: "1619a0fd1dd0fd80292cea33254d5ec8", 9: "8968dc94e1d5da079e6c2f9de9bed850",
	10: "c88e82c16b3bc4135cb99d45d6dd99b3", 11: "8444c32767be7ab71f36aa7b8b97de57",
	12: "6d46fcf0da24e8aa0cea1fbd12315e39", 13: "5765fb7c63b64c1b11fde9a1ce120275",
	14: "427cc631e8331e3b8f89bb1527c9c5b7", 15: "18e773fc6832a0352db2e8f039c1cbb1",
	16: "106dad04e0bb1b27eada26d387469ab0", 17: "1ea0126c4e747c2705b77897e538f2ae",
	18: "6b26c95edfe9090338978a7d5876521b", 19: "c09122d3e05a4a8dacf4b9d24592c193",
	20: "b70e21d93aa39b581b331b5b81648218", 21: "8f6dd527aa6d4f25101ef5633b2f4228",
	22: "4a98049edf65bf10e4798ff8d15fa2e2", 23: "3e0d8ed38b0570484b31ad3aa774cddc",
	24: "d3b2e6667cb93860f84dc84527f24d26",
}

var _通过 := 0
var _失败: Array[String] = []


func _判(条件: bool, 说明: String, 补: String = "") -> void:
	_通过 += 1
	if not 条件:
		_失败.append(说明 + ("　" + 补 if not 补.is_empty() else ""))


func _initialize() -> void:
	call_deferred("_跑")


## ── ① 解码腿：`1346:0` 那三档读序 ────────────────────────────────────────
func _跑解码腿() -> void:
	var 假 = 测试后端.new()
	root.add_child(假)
	var 收到: Array = []
	假.榜单徽记收到.connect(func(编号: int, 列表: Array) -> void: 收到.append([编号, 列表]))
	var 表: Dictionary = 假.get("authoritative_ranking_titles")
	假.call("_handle_bridge_text", "1346:0:7001:3:0@5@30")
	假.call("_handle_bridge_text", "1346:0:7002:0:-")
	假.call("_handle_bridge_text", "1346:0:7003:1:22")
	假.call("_handle_bridge_text", "1346:0:7004")
	_判(表.get(7001) != null and Array(表[7001]) == [0, 5, 30],
		"① `1346:0:7001:3:0@5@30` 应解成 [0,5,30]", "实得 %s" % str(表.get(7001)))
	_判(表.get(7002) != null and (表[7002] as Array).is_empty(),
		"② 空载荷 `-` 要存成**空数组**（不是没这条）", "实得 %s" % str(表.get(7002)))
	_判(表.get(7003) != null and Array(表[7003]) == [22],
		"① 单人一枚 `22` 应解成 [22]", "实得 %s" % str(表.get(7003)))
	_判(not 表.has(7004), "① 段数不够（缺 cnt）那条整帧丢掉，不留脏键")
	_判(收到.size() == 3, "① 三条合法的都应发一次信号（含空表那条）", "实得 %d" % 收到.size())
	if 收到.size() >= 1:
		_判(int(收到[0][0]) == 7001 and Array(收到[0][1]) == [0, 5, 30],
			"① 信号带的是角色号 + 榜号数组")
	## ⚠ 这条**不挂在 `收到.size() == 3` 里面**：那条计数判点一红，块里的判点就不执行了，
	##   "空表也要发"这个具体主张于是没人咬（§3.259 同族：单点变异被上一层吸收）。
	var 空表那条: Variant = null
	for 条 in 收到:
		if int((条 as Array)[0]) == 7002:
			空表那条 = 条
	_判(空表那条 != null and ((空表那条 as Array)[1] as Array).is_empty(),
		"② **空表也要发信号** —— 原版空数组是 `removeChild`（摘板），不是当没看见",
		"实得 %s" % str(收到))
	假.free()


## ── ② 查表腿：榜号 → 图名（这一步猜成恒等就全错）────────────────────────
func _跑查表腿(实体) -> void:
	var 期望 := {
		0: "Effect_PaiHangBang_0", 4: "Effect_PaiHangBang_4",
		5: "Effect_PaiHangBang_9", 9: "Effect_PaiHangBang_5",
		10: "Effect_PaiHangBang_11", 13: "Effect_PaiHangBang_15",
		22: "Effect_PaiHangBang_24", 30: "Effect_PaiHangBang_14",
		23: "", 29: "", 31: "", 99: "",
	}
	for 榜号 in 期望.keys():
		var 得: String = 实体.call("_榜单徽记图名", int(榜号))
		_判(得 == String(期望[榜号]),
			"② 榜号 %d 的图名应为 `%s`" % [榜号, 期望[榜号]], "实得 `%s`" % 得)


## ── ③④⑤ 摆位 / 摘板 / 跟随名字 ──────────────────────────────────────────
func _板子(人物: Node) -> Node2D:
	return 人物.get_node_or_null("PaiHangPane") as Node2D


func _灌(实体, 表: Dictionary, 编号: int, 榜号: Array) -> void:
	表[编号] = 榜号
	实体.call("_刷榜单徽记", 实体.get("_player"), 编号)


func _跑摆位腿(实体, 人物: Node, 表: Dictionary, 编号: int) -> void:
	_灌(实体, 表, 编号, [0, 5, 30])
	var 板 := _板子(人物)
	if 板 == null:
		_判(false, "③ 灌 [0,5,30] 后应当长出 PaiHangPane —— 后面几条都不作数了")
		return
	_判(true, "③ 灌 [0,5,30] 后长出 PaiHangPane")
	_判(is_equal_approx(板.position.y, -120.0) and is_equal_approx(板.position.x, 0.0),
		"③ 板钉在角色原点**上方 120**（`doTitleLayer:1344-1347`）", "实得 %s" % 板.position)
	var 子 := 板.get_children()
	_判(子.size() == 3, "③ 三枚榜号该长三枚（一枚都没被吞）", "实得 %d" % 子.size())
	if 子.size() != 3:
		return
	## 手抄的期望值（板局部坐标）：注册点 = 下中，141 宽 y=26、143 宽 y=25；行距 28。
	var 期望: Array = [
		{"名": "Effect_PaiHangBang_0", "x": -70.5, "y": -82.0},
		{"名": "Effect_PaiHangBang_9", "x": -70.5, "y": -54.0},
		{"名": "Effect_PaiHangBang_14", "x": -71.5, "y": -25.0},
	]
	for i in 3:
		var 枚 := 子[i] as Sprite2D
		var 钉: Dictionary = 期望[i]
		if 枚 == null or 枚.texture == null:
			_判(false, "③ 第 %d 枚拿不到贴图" % i)
			continue
		_判(String(枚.texture.resource_path).contains(String(钉["名"])),
			"③ 第 %d 枚（数组第 %d 个）该贴 %s" % [i, i, 钉["名"]],
			"实得 %s" % 枚.texture.resource_path)
		_判(is_equal_approx(枚.position.x, float(钉["x"]))
			and is_equal_approx(枚.position.y, float(钉["y"])),
			"③ 第 %d 枚左上角应为 (%s, %s)" % [i, 钉["x"], 钉["y"]],
			"实得 %s" % 枚.position)
		_判(not 枚.centered, "③ 徽记必须 centered=false（摆的是左上角，注册点自己算）")
	_判(子[0].position.y < 子[1].position.y and 子[1].position.y < 子[2].position.y,
		"③ **数组最后一枚在最下面**（`y = -(长度-1-序号)*28`，序号 0 最高）")
	_判(子[0].position.x == 子[1].position.x,
		"③ 同为 141 宽的两枚横向应当**完全对齐**（原版从不写 x）")

	## 重画腿：`PaiHangTipPane.redraw` 开头是 `DisplayUtil.removeAllChildren(this)` ⇒
	## 同一摞刷两遍**还是三枚**。旧节点只 `queue_free` 不摘出树的话这一帧会长成六枚，
	## 而且排在后面的新徽记会被旧的盖住（戊刀就是钉这条，光靠下面的单枚腿咬不准）。
	_灌(实体, 表, 编号, [0, 5, 30])
	var 重画 := _板子(人物)
	_判(重画 != null and 重画.get_child_count() == 3,
		"③ 同一摞刷两遍仍是 3 枚（旧的摘干净，不留双份）",
		"实得 %d" % (-1 if 重画 == null else 重画.get_child_count()))

	# ──  注册点那 1 px：画布 25 高与 26 高的两枚，注册点都是 26 ⇒ 节点同高、墨迹差 1 ──
	_灌(实体, 表, 编号, [0])
	var 单 := _板子(人物)
	var 甲: Vector2 = (单.get_child(0) as Sprite2D).position if 单 != null and 单.get_child_count() > 0 else Vector2.INF
	_灌(实体, 表, 编号, [6])
	单 = _板子(人物)
	var 乙: Vector2 = (单.get_child(0) as Sprite2D).position if 单 != null and 单.get_child_count() > 0 else Vector2.INF
	_判(甲 == 乙 and is_equal_approx(甲.y, -26.0),
		"④ 单独一枚时两枚图（25 高 / 26 高）节点**同点** = -26（注册点都是 26，不是画布高）",
		"实得 %s / %s" % [甲, 乙])

	# ── ④ 空表摘板 / 未知榜号不冒充 ───────────────────────────────────────
	_灌(实体, 表, 编号, [])
	await process_frame
	_判(_板子(人物) == null, "④ 空表要把整块板摘掉（`Character.as:1186-1191` 的 removeChild）")
	_灌(实体, 表, 编号, [99])
	单 = _板子(人物)
	_判(单 != null and 单.get_child_count() == 0,
		"④ 查不到图的榜号：板还在、里面**一枚都不摆**（不许拿别的图顶上）",
		"实得 %s" % ("无板" if 单 == null else str(单.get_child_count())))
	_灌(实体, 表, 编号, [])
	await process_frame

	# ──  跟随名字同隐同显 ───────────────────────────────────────────────
	_灌(实体, 表, 编号, [0, 5, 30])
	实体.call("_on_settings_changed", {"show_names": false})
	单 = _板子(人物)
	_判(单 != null and not 单.visible, "⑥ 关名字时徽记一起藏（`setNamePaneVisibleExNamePane:2811`）")
	实体.call("_on_settings_changed", {"show_names": true})
	_判(单 != null and 单.visible, "⑥ 开名字时徽记一起显")
	_灌(实体, 表, 编号, [])
	await process_frame


## ── ⑤ 素材腿：25 张都在、尺寸只允许那两种 ───────────────────────────────
func _跑素材腿(实体) -> void:
	var 缺 := ""
	var 错尺 := ""
	for 后缀 in 全部图名:
		var 路 := 徽记图根 % ("Effect_PaiHangBang_%d" % 后缀)
		if not ResourceLoader.exists(路):
			缺 += "%d " % 后缀
			continue
		var 图 := load(路) as Texture2D
		var 宽: int = 图.get_width() if 图 != null else 0
		var 高: int = 图.get_height() if 图 != null else 0
		if not (宽 in [141, 143]) or not (高 in [25, 26]):
			错尺 += "%d:%dx%d " % [后缀, 宽, 高]
	_判(缺.is_empty(), "⑤ 25 枚徽记素材都得在盘上（`Effect_PaiHangBang.swf` 直解）", "缺 %s" % 缺)
	_判(错尺.is_empty(), "⑤ 每张只允许 141×25/26 或 143×25（注册点表就按这两种宽度抄的）",
		"异常 %s" % 错尺)
	var 表: Dictionary = 实体.get_script().get_script_constant_map().get("忍云注册y", {})
	_判(表.has(141) and 表.has(143), "⑤ 注册点表得覆盖 141 与 143 两种宽度", "实得 %s" % str(表))
	_判(is_equal_approx(float(表.get(141)), 26.0) and is_equal_approx(float(表.get(143)), 25.0),
		"⑤ 注册点 y：141 宽 = 26、143 宽 = 25（JPEXS 量的 `-Ymin/20`）", "实得 %s" % str(表))
	## 逐张核对"画布高 ≠ 注册点"那 8 枚 —— 这正是裁图丢掉的那 1 px。
	var 该差一: Array = [0, 1, 2, 3, 4, 5, 9, 12]
	var 账错 := ""
	for 后缀 in 该差一:
		var 图 := load(徽记图根 % ("Effect_PaiHangBang_%d" % 后缀)) as Texture2D
		if 图 == null or 图.get_height() != 25:
			账错 += "%d:%s " % [后缀, "无" if 图 == null else 图.get_height()]
	for 后缀 in [6, 7, 8, 10, 11, 13, 18, 19, 20, 21, 22, 23, 24]:
		var 图 := load(徽记图根 % ("Effect_PaiHangBang_%d" % 后缀)) as Texture2D
		if 图 != null and 图.get_height() != 26:
			账错 += "%d:%d " % [后缀, 图.get_height()]
	for 后缀 in [14, 15, 16, 17]:
		var 图 := load(徽记图根 % ("Effect_PaiHangBang_%d" % 后缀)) as Texture2D
		if 图 == null or 图.get_width() != 143 or 图.get_height() != 25:
			账错 += "%d:%s " % [后缀, "无" if 图 == null else "%dx%d" % [图.get_width(), 图.get_height()]]
	_判(账错.is_empty(),
		"⑤ 高度账：`_0/_1/_2/_3/_4/_5/_9/_12` 与 `_14.._17` 是 25 高、其余 26 高（8 枚要往下让 1 px）",
		"对不上 %s" % 账错)
	var 变 := ""
	for 后缀 in 全部图名:
		var 路 := 徽记图根 % ("Effect_PaiHangBang_%d" % 后缀)
		if not ResourceLoader.exists(路):
			continue
		if FileAccess.get_md5(路) != String(素材md5.get(后缀, "")):
			变 += "%d " % 后缀
	_判(变.is_empty(),
		"⑤ 像素必须是 SWF 存储 RGB（ffdec 导出会把低 alpha 的彩点放大；重导跑 `开发工具/重导忍云素材.py --写`）",
		"内容已变 %s" % 变)


## ──  字面腿：断掉的旧说法不许回来 ──────────────────────────────────────
func _跑字面腿() -> void:
	var 文 := FileAccess.get_file_as_string("res://脚本/地图/地图实体.gd")
	var 起 := 文.find("func _刷榜单徽记")
	_判(起 >= 0, "⑦ 找得到 `func _刷榜单徽记`")
	if 起 >= 0:
		var 止 := 文.find("\nfunc ", 起 + 1)
		var 体 := 文.substr(起, 止 - 起 if 止 > 起 else -1)
		_判(体.contains("忍云板相对脚点"), "⑦ 板的 y 走常量 `忍云板相对脚点`（不在函数体里写死）")
		_判(体.contains("忍云行距"), "⑦ 行距走常量 `忍云行距`")
		_判(not 体.contains("Vector2.ONE"), "⑦ 函数体里不该再有 `Vector2.ONE` 那种自造内缩")
		_判(not 体.contains("-150") and not 体.contains("-180"),
			"⑦ 不该出现 -150/-180 那两档（前提是护航/暮叶战，本工程没实装）")
	_判(文.contains("const 忍云板相对脚点 := -120.0"), "⑦ 常量 = -120（`doTitleLayer:1346`）")
	_判(文.contains("const 忍云行距 := 28.0"), "⑦ 行距 = 28（`PaiHangTipPane.redraw:41`）")
	_判(文.contains("\"PaiHangPane\""), "⑦ 跟随名字的图标名单里有这块板")
	_判(文.contains("_backend.榜单徽记收到.connect"), "⑦ `1346:0` 那条信号真的接上了")
	## 时序两条腿都得在：信号先到（角色还没建）与角色先到（信号后到）。
	var 生 := 文.find("func _on_server_player_spawned")
	_判(生 >= 0 and 文.find("_刷榜单徽记(actor, remote_id)", 生) > 0,
		"⑦ 远程玩家**建完就补画**（徽记可能比他先进图）")
	var 本 := 文.find("func _ensure_local_player_family_marks")
	_判(本 >= 0 and 文.find("_刷榜单徽记(", 本) > 0,
		"⑦ 本地人物建好时补画（登录那一帧的 `1346:0` 早于人物入组）")
	## 后端那份过期注释（"素材未直解 / 画的那一半挂在 #87"）必须清掉。
	var 后 := FileAccess.get_file_as_string("res://脚本/单例/后端连接.gd")
	_判(not 后.contains("未直解进仓"), "⑦ 后端注释不再说这批素材未直解")
	var 注起 := 后.find("var authoritative_ranking_titles")
	_判(注起 >= 0 and 后.substr(maxi(0, 注起 - 700), 700).contains("_刷榜单徽记"),
		"⑦ 那份字典上方写明了画在哪（别让人再去找消费者）")
	_判(后.contains("榜单徽记收到.emit(int(fields[2]), 称号)"),
		"⑦ cmd 0 分支真的 emit（只存字典不发信号 = 画不出来）")


func _跑() -> void:
	root.size = Vector2i(960, 560)
	_跑解码腿()

	var 场景 := (load(地图资源.playable_scene_path(默认地图)) as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _帧 in range(5):
		await process_frame
	var 实体 := 场景.get_node_or_null("LifeRoot")
	if 实体 == null:
		_失败.append("拿不到 LifeRoot（地图实体）")
		_收尾()
		return
	var 人物 := get_first_node_in_group("player") as Node2D
	if 人物 == null:
		_失败.append("拿不到 player 分组里的真身")
		_收尾()
		return
	var 后端: Node = root.get_node_or_null("BackendConnection")
	if 后端 == null:
		_失败.append("拿不到 BackendConnection autoload")
		_收尾()
		return
	实体.set("_backend", 后端)
	实体.set("_player", 人物)
	var 表: Dictionary = 后端.get("authoritative_ranking_titles")
	var 原样 = 表.duplicate(true)
	var 我的编号 := 990001
	## 名牌先备着：`_刷榜单徽记` 末尾要看名牌的 visible 决定板的可见性。
	if 人物.get_node_or_null("Nameplate") == null:
		实体.call("_ensure_local_player_nameplate")

	_跑查表腿(实体)
	_跑摆位腿(实体, 人物, 表, 我的编号)
	_跑素材腿(实体)
	_跑字面腿()

	表.clear()
	for 键 in 原样.keys():
		表[键] = 原样[键]
	await process_frame
	_收尾()


func _收尾() -> void:
	print("忍云榜单徽记回归：通过 %d 条，失败 %d 条" % [_通过, _失败.size()])
	for 条 in _失败:
		print("  ✗ " + 条)
	print("跑完了")
	quit(1 if not _失败.is_empty() else 0)
