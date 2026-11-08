extends SceneTree

## 排行榜页（原版 `RankWindow2`，opcode **1346**）判据门（§3.254，2026-10-23 用户报修 5）。
##
## 期望值唯一来源 = `2.2.3/map_extract/out/mainlib_as/scripts/com/mxw/uifl/controls/rank2/`
## 那六个 `.as`（`RankWindow2` / `RankListPane2` / `RankListCell2` / `RankMenuCell2` /
## `RankWindowManager` / `../base/utils/PageComponent`）+ `数据/原版杂项.json` 的 `PaiHangBang`。
## 每条判据后面都带行号。
##
## 为什么单开一条：旧版这页是**四枚自造页签 + 好友表造假榜 + 发 2329**。2329 是跨服**充值**榜
## （`SendOpCodes.GLOBLE_PAIHANG:326`），服务端那条 1346 从来没被读过 ⇒ 玩家点开一片空白；
## 而金丝雀 `奖励在线查询回归测试` 从 2026-09-25 起一直卡在第一格 gift、后面压根没跑到。
## 这条门一次钉全：上行串 / 回帧解析 / 23 条表 / 几何色号字号 / 翻页三态 / 不许造假榜。
##
## ⚠ 不写 `user://`、不连真服：用 `测试后端连接`（`send_game_request` 只记录不发包），
##   窗口实例走 `窗口管理.取或建窗口`，跑完把 `_backend` 还原成自动单例。
##
## 跑法：Godot --headless --path . --script res://测试/排行榜回归测试.gd

const 页面场景路径 := "res://场景/界面/窗口/排行榜/排行榜窗口.tscn"
const 条目场景路径 := "res://场景/界面/组件/排行榜条目.tscn"
const 页面根名 := "原版排行榜内容"
const 分类框素材 := "res://素材/界面/原版窗口/排行榜/分类框.png"

const 系统窗口 := preload("res://脚本/界面/窗口/系统窗口.gd")
const 功能窗口脚本 := preload("res://脚本/界面/功能窗口.gd")
const 测试后端 := preload("res://测试/测试后端连接.gd")

const 容差 := 1.0
const 我的编号 := 7001
## 判据总条数：协程中途炸掉时 `判` 会小于它 ⇒ 末行照样打"红 0"也不许算过（工程口径）。
const 判满条数 := 305

## 件名 → [x, y, w, h, AS3 出处]。**窗口局部坐标**（场景根 = `_contentBg` 608×340）。
const 件表 := {
	"外框": [0.0, 0.0, 608.0, 340.0, "RankWindow2.as:113-114 _contentBg 608×340"],
	# bangDanBg = `UISwf_RankWindow_Bg1`（直解出来 120×160），第二块 y = 10 + 高 + 8
	"分类框上": [5.0, 10.0, 120.0, 160.0, ":443-446 bangDanBg.setPosition(5,10)"],
	"分类框下": [5.0, 178.0, 120.0, 160.0, ":459-462 _loc3_.y = 10+160+8 = 178"],
	"分类标题": [50.0, 10.0, 30.0, 20.0, ":447-450 getLabel2(UI_5,30) 摆 (50,10)"],
	# ScrollPane 是 bangDanBg(5,10) 的**子件** ⇒ 绝对 = 5+5 / 10+25
	"榜单滚动": [10.0, 35.0, 105.0, 123.0, ":452-458 rankMenuScrollPane 105×123 @ (5,25)"],
	"规则标题": [39.0, 178.0, 56.0, 20.0, ":463-466 getLabel2(UI_41,56) 摆 (39, _loc3_.y)"],
	"规则": [15.0, 203.0, 106.0, 125.0, ":467-474 TextArea2 setSize(106,125) 摆 (15,178+25)，paddingH/V=0"],
	# rightPanel.x = leftPanel.x + leftPanel.width = 125
	"榜单框": [125.0, 25.0, 477.0, 281.0, ":183-187 rightBg 477×281 @ y=25 in rightPanel(125,0)"],
	# 两枚页签挂在 `榜单分页` 这个盒里（盒本身 = rightPanel(125,0) 的 (5,5)），
	# `_矩形` 比的是**相对父件**的 position ⇒ 这里录盒内局部值，盒的绝对位置单独钉。
	"榜单分页": [130.0, 5.0, 98.0, 22.0, ":167-179 页签在 rightPanel(125,0) 内 x=5、y=5"],
	"榜单分页/忍界榜": [0.0, 0.0, 49.0, 22.0, ":167-172 renJieBtn x/y=5、宽 btn_width_three=49"],
	"榜单分页/同级榜": [49.0, 0.0, 49.0, 22.0, ":174-179 tongJiBtn.x = renJieBtn.x + renJieBtn.width"],
	"提示": [365.0, 5.0, 232.0, 16.0, ":188-194 getLabel(RANK_WINDOW_TIP,UI_GREEN) x=240+125、232×16 居中"],
	# 三枚列头 = RankListPane2.cretateLabel(40/95/90, x 累加)，rankList 挂 rightPanel 的 x=3、y=renJieBtn.y+高=27
	"名次标题": [128.0, 27.0, 40.0, 20.0, "RankListPane2.as:131 宽 40"],
	"名称标题": [168.0, 27.0, 95.0, 20.0, ":132 宽 95（x 累加 40）"],
	"数值标题": [263.0, 27.0, 90.0, 20.0, ":133 宽 90（x 累加 135）"],
	"排行榜列表": [128.0, 50.0, 230.0, 230.0, ":136-140 单元格起点 y=50、列宽 230"],
	"我的排名背景": [125.0, 280.0, 230.0, 25.0, "RankWindow2.as:196-201 myRankbg 230×25 @ y=280"],
	"我的排名": [125.0, 282.0, 230.0, 20.0, ":203-207 cretateLabel(230, 0, myRankbg.y + 2)"],
	# PageComponent 宽 = lastBtn.x + width = 106 + 18 = 124（drawLayout:89）
	# ⇒ x = 230/2 − 124/2 = 53 → 绝对 178；y = myRankbg.y + 30 = 310；高 20 = 构造期那块 10×20 命中矩形
	"分页条": [178.0, 310.0, 124.0, 20.0, "RankWindow2.as:208-214 + PageComponent.as:49-51/89"],
	"分页条/首页": [0.0, 0.0, 18.0, 13.0, "PageComponent.as:64-68 四枚都只设 x、y 留 0；MPageFirstBtnF 自然 18×13"],
	"分页条/上一页": [20.0, 0.0, 15.0, 13.0, ":65 preBtn.x = firstBtn.width + 2 = 20"],
	"分页条/页码": [37.0, 0.0, 50.0, 16.0, ":66 pageText.x = 20+15+2；:144-146 width 50 / height 16"],
	"分页条/下一页": [89.0, 0.0, 15.0, 13.0, ":67 nextBtn.x = 37+50+2"],
	"分页条/末页": [106.0, 0.0, 18.0, 13.0, ":68 lastBtn.x = 89+15+2 ⇒ 合计宽 124"],
}

## 一行 = `RankListCell2.createUI:62-91`：三枚 `cretateLabel(宽, x, 2)`，宽 **40/95/90**、
## x 依次 **0/40/135**、每枚 **20 高、顶边 y=2**（`setPosition(param2, 2)`，行底图 25 高）。
const 行件表 := {
	"名次": [0.0, 2.0, 40.0, 20.0],
	"名称": [40.0, 2.0, 95.0, 20.0],
	"数值": [135.0, 2.0, 90.0, 20.0],
}

## 23 条菜单 = `Etc.PaiHangBang` 键 "0".."22"，**按数值升序**（`getRankEtcData:121-125` 先收键
## 进数组、再 `sort(Array.NUMERIC)` ⇒ 书写序会把 "10" 排到 "2" 前面）。逐字取自数据表。
const 榜名表 := ["等级排行榜", "财富排行榜", "宠物身价榜", "连斩次数榜", "BOSS击杀榜", "百炼忍传榜",
	"忍术境界榜", "八门进度榜", "成就进度榜", "杀戮罪恶榜", "手里剑排行榜", "写轮眼排行榜",
	"意志排行榜", "柔拳排行榜", "轮回六道榜", "十大虫师榜", "赠花排行榜", "决斗排行榜",
	"连斩竞速榜", "美女榜", "玩家代表榜", "帅哥榜", "结印排行榜"]

var 判 := 0
var 红 := 0
var _秒 := 0.0


## 崩而不红防护：协程中途死掉时 headless 会**永远挂着**（§3.227 同型事故）⇒ 90s 看门狗把超时变成明红。
func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 90.0:
		printerr("排行榜回归测试：看门狗超时（90s）—— 中途崩了没走到收尾")
		quit(1)
		return true
	return false


func _比(说明: String, 条: bool) -> void:
	判 += 1
	if not 条:
		红 += 1
		print("!! " + 说明)


func _矩形(说明: String, 件: Control, 录: Array) -> void:
	var 期 := Rect2(float(录[0]), float(录[1]), float(录[2]), float(录[3]))
	var 实 := Rect2(件.position, 件.size)
	var 最大偏 := maxf(maxf(absf(实.position.x - 期.position.x), absf(实.position.y - 期.position.y)),
			maxf(absf(实.size.x - 期.size.x), absf(实.size.y - 期.size.y)))
	var 出处 := String(录[4]) if 录.size() > 4 else "RankListCell2.createUI:62-91"
	_比("%s 矩形 %s ≠ 期望 %s（%s）" % [说明, 实, 期, 出处], 最大偏 <= 容差)


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	_验静态几何()
	_验条目()
	_验表定义()
	await _验在线行为()
	if 判 != 判满条数:
		print("!! 判据只跑了 %d 条，应为 %d 条 ⇒ 中途被运行期错误打断，本条不算过" % [判, 判满条数])
		quit(1)
		return
	if 红 > 0:
		print("排行榜回归测试：失败 %d / %d" % [红, 判])
		quit(1)
		return
	print("排行榜回归测试：通过（%d 条判据：1346 上行与回帧 / 23 条表 / 几何色号字号 / 翻页三态 / 不造假榜）" % 判)
	quit(0)


func _验静态几何() -> void:
	var 根 := (load(页面场景路径) as PackedScene).instantiate() as Control
	root.add_child(根)
	for 件名 in 件表:
		var 件 := 根.get_node_or_null(件名) as Control
		if 件 == null:
			_比("场景里缺件「%s」（出处 %s）" % [件名, 件表[件名][4]], false)
			continue
		_矩形("「%s」" % 件名, 件, 件表[件名] as Array)
	# 分类框是**一张素材**（`UISwf_RankWindow_Bg1` 直解出来的 120×160），两块共用 ⇒ 判在盘上且能解码。
	var 上 := 根.get_node_or_null("分类框上") as TextureRect
	_比("分类框必须是 TextureRect 贴图件（原来是自造色块）", 上 != null)
	if 上 != null:
		var 路 := String(上.texture.resource_path) if 上.texture != null else ""
		_比("分类框贴图 = %s，实际 [%s]" % [分类框素材, 路], 路 == 分类框素材)
		# 走 `FileAccess` + `load_png_from_buffer` 而不是 `Image.load_from_file`：后者对**已导入**的
		# png 会打一条 `Loaded resource as image file` 警告，把全量日志弄脏（判据本身等价）。
		var 盘 := Image.new()
		var 码 := 盘.load_png_from_buffer(FileAccess.get_file_as_bytes(分类框素材))
		_比("分类框 PNG 要在盘上真能解码（只认 FileAccess，不信导入缓存），实际错误码 %d" % 码,
				码 == OK and 盘.get_width() == 120 and 盘.get_height() == 160)
		if 上.texture != null:
			var 然 := 上.texture.get_size()
			_比("分类框贴图自然尺寸必须 120×160（第二块 y = 10+高+8 就是按这个高算的），实得 %s" % 然,
					is_equal_approx(然.x, 120.0) and is_equal_approx(然.y, 160.0))
	# 翻页四枚是 `MButton3` 系 ⇒ 手型光标 + 不许烘死 disabled（禁用态运行期按页算）。
	for 名 in ["首页", "上一页", "下一页", "末页"]:
		var 钮 := 根.get_node_or_null("分页条/" + 名) as TextureButton
		_比("「分页条/%s」要存在" % 名, 钮 != null)
		if 钮 != null:
			_比("「分页条/%s」不许在 .tscn 里预置 disabled（原版 `setBtnEnabled:102-120` 现场算）" % 名, not 钮.disabled)
			_比("「分页条/%s」要手型光标（MButton3 的 buttonMode）" % 名,
					钮.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND)
	# 原版 `:179` 把 tongJiBtn 建出来就是 `selected=visible=enabled=false`，由 `selecteRankMenu:241-245`
	# 按 `descs.length` 决定露不露 ⇒ 场景默认必须**藏**（烘成可见的话，切到等级榜之前那一瞬是错的态）。
	var 同 := 根.get_node_or_null("榜单分页/同级榜") as Button
	_比("场景里「同级榜」默认必须 visible=false（`RankWindow2:179`）", 同 != null and not 同.visible)
	# 装饰件不吃鼠标（原版 Sprite / mouseEnabled=false）
	for 名 in ["分类框上", "分类框下", "竖向分隔线", "我的排名背景", "分页条"]:
		var 件 := 根.get_node_or_null(名) as Control
		_比("「%s」不许吃鼠标（会挡住下面能点的件）" % 名,
				件 != null and 件.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	根.queue_free()


func _验条目() -> void:
	var 条 := (load(条目场景路径) as PackedScene).instantiate() as Control
	root.add_child(条)
	_矩形("排行榜条目 根", 条, [0.0, 0.0, 230.0, 20.0])
	for 名 in 行件表:
		var 件 := 条.get_node_or_null(名) as Control
		if 件 == null:
			_比("条目里缺「%s」" % 名, false)
			continue
		_矩形("条目「%s」" % 名, 件, 行件表[名] as Array)
	_比("条目根不许吃鼠标（原版 cell 里的三枚 label 全 mouseEnabled=false）",
			条.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	# 死件清扫：旧版那一行有第四列「战斗力」，原版只有三列（40/95/90）⇒ 不许回来
	_比("条目里不许有第四列「战斗力」（原版三列）", 条.get_node_or_null("战斗力") == null)
	条.queue_free()


func _验表定义() -> void:
	var 定义 := 系统窗口.榜单定义()
	_比("左侧菜单必须是 `Etc.PaiHangBang` 全量 23 条，实际 %d 条（旧版是自造四枚页签）" % 定义.size(),
			定义.size() == 23)
	if 定义.size() != 23:
		return
	for i in 定义.size():
		var 条 := 定义[i] as Dictionary
		_比("第 %d 条的 menuId 必须 = 键的数值（= 行序），实际 %s" % [i, str(条.get("menuId"))],
				int(条.get("menuId", -1)) == i)
		_比("第 %d 条名字应为「%s」，实际「%s」" % [i, 榜名表[i], String(条.get("name", ""))],
				String(条.get("name", "")) == 榜名表[i])
		_比("第 %d 条要有 desc（规则那一栏直接吃它）" % i, String(条.get("desc", "")).length() > 0)
		# 23 条里**只有 menuId 0（等级榜）没有 tongDesc** ⇒ 只有那一榜藏掉「同级榜」页签。
		_比("第 %d 条「%s」的 tongDesc 有无判错（只有 menuId 0 没有）" % [i, String(条.get("name", ""))],
				条.has("tongDesc") == (i != 0))
		# 只有 menuId 2（宠物身价榜）showType=1 ⇒ 第二列才是「宠物主人」
		_比("第 %d 条 showType 应为 %d" % [i, 1 if i == 2 else 0],
				int(条.get("showType", -1)) == (1 if i == 2 else 0))
	# `menuId` 是**补**出来的（条里本来没这个字段）⇒ 只在副本上补，不许污染原表
	var 原表: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://数据/原版杂项.json"))
	_比("原始 `PaiHangBang` 条里本来没有 menuId（我们只在副本上补键）",
			not (原表["PaiHangBang"]["0"] as Dictionary).has("menuId"))


func _帧(榜: int, 忍界: bool, 名次: int, 行: String) -> String:
	return "1346:1:%d:%s:%d:%s" % [榜, "true" if 忍界 else "false", 名次, 行]


## 造 N 行载荷：`serverId&charId&name&petUid&value`，`@` 连行（`fake_flash_server.py:27511-27518`）。
## `我在第几行`（0 基，−1 = 不在榜上）用来钉"客户端扫行算名次"那条口径。
func _造行(条数: int, 我在: int = -1) -> String:
	var 行: Array[String] = []
	for i in 条数:
		var 编号 := 8000 + i
		if i == 我在:
			编号 = 我的编号
		行.append("1&%d&忍者%02d&0&%d" % [编号, i + 1, 1000 - i])
	return "@".join(行)


func _取页(窗) -> Control:
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	return 内容.get_node_or_null(页面根名) as Control


func _验在线行为() -> void:
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _i in 5:
		await process_frame
	var 管理: Node = 场景.get_node_or_null("窗口管理")
	if 管理 == null:
		_比("拿不到 窗口管理 ⇒ 在线那一半全跑不了", false)
		return
	var 窗 = 管理.call("取或建窗口", "排行榜")
	if 窗 == null:
		_比("取或建窗口(排行榜) 给了 null", false)
		return
	var 真后端: Node = 窗.get("_backend")
	var 假 = 测试后端.new()
	假.in_game = true
	假.character_id = 我的编号
	窗.set("_backend", 假)
	# `_ready` 那一轮连的是自动单例 ⇒ 这里把回帧信号接到**真处理函数**上（走的还是工程那条腿）。
	假.ranking_state_received.connect(窗._on_ranking_state)
	管理.call("打开", "排行榜")
	for _i in 3:
		await process_frame
	var 页 := _取页(窗)
	if 页 == null:
		_比("开「排行榜」页后 `_content` 里查无「%s」" % 页面根名, false)
		窗.set("_backend", 真后端)
		假.free()
		场景.queue_free()
		return
	# ── ① 开窗上行 ────────────────────────────────────────────────────────────
	_比("开窗必须发**一次** 1346 查询（旧版发 2329 ⇒ 服务端那条 1346 永远没人读），实际 %d 次"
			% 假.sent_requests.size(), 假.sent_requests.size() == 1)
	if 假.sent_requests.size() == 1:
		_比("开窗那发的 opcode 必须 1346，实际 %s" % str(假.sent_requests[0].opcode),
				int(假.sent_requests[0].opcode) == 1346)
		_比("开窗上行必须 `0:0:1`（action0 + menuId0 + 忍界位；旧版少最后那格 bool ⇒ 服务端当畸形帧丢），实际 [%s]"
				% String(假.sent_requests[0].content), String(假.sent_requests[0].content) == "0:0:1")
	# ── ② 未回帧 = 原版构造期态 ───────────────────────────────────────────────
	_比("未回帧时**一行都不许画**（旧版这里拿好友表造一张假榜糊玩家）",
			(页.get_node("排行榜列表") as Control).get_child_count() == 0)
	var 码 := 页.get_node("分页条/页码") as Label
	_比("未回帧时页码是 \"1/5\"（`PageComponent(50,10)` 构造期 `_totalPage=ceil(50/10)`），实际 [%s]" % 码.text,
			码.text == "1/5")
	for 名 in ["首页", "上一页"]:
		var 钮 := 页.get_node("分页条/" + 名) as TextureButton
		_比("未回帧时「%s」该禁用（currentPage=1 ⇒ firstBtn/preBtn.enabled=false）" % 名, 钮.disabled)
		_比("禁用那枚要套灰度材质（`StyleUtil.getGrayFilter`），不是换灰图、不是压暗",
				钮.material == 功能窗口脚本.禁用灰度材质())
	for 名 in ["下一页", "末页"]:
		var 钮 := 页.get_node("分页条/" + 名) as TextureButton
		_比("未回帧时「%s」该**亮着**（1 < totalPage=5 ⇒ 原版既成观感，不许\"顺手改成禁用\"）" % 名, not 钮.disabled)
		_比("亮着那枚不许挂材质", 钮.material == null)
	_比("未回帧时「我的排名」保留烘焙的 \"--\"（`RankWindow2:204`，不是「未上榜」）",
			(页.get_node("我的排名") as RichTextLabel).text == "--")
	var 容器 := 页.get_node("榜单滚动/榜单容器") as VBoxContainer
	_比("左侧菜单该有 23 枚，实际 %d" % 容器.get_child_count(), 容器.get_child_count() == 23)
	if 容器.get_child_count() == 23:
		var 第0 := 容器.get_child(0) as Button
		var 第10 := 容器.get_child(10) as Button
		_比("第 0 枚文字 = 「等级排行榜」，实际「%s」" % 第0.text, 第0.text == "等级排行榜")
		_比("第 10 枚文字 = 「手里剑排行榜」（行序按**数值**升序，书写序会把 10 排到 2 前）", 第10.text == "手里剑排行榜")
		_比("第 0 枚该呈选中态（`createRankMenu:335` 默认选 cells[0]）", bool(第0.button_pressed))
		_比("第 10 枚不许跟着亮", not bool(第10.button_pressed))
		# 菜单字色四档全橙（`RankMenuCell2:47 getLabel("", UI_ORANGE, true)`；选中只换底图不改字色）
		for 态 in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			_比("菜单第 0 枚的 %s 必须是 #FF9100，实得 %s" % [态, 第0.get_theme_color(态).to_html(false)],
					第0.get_theme_color(态) == Color("#FF9100"))
		_比("菜单字号 12（`RankMenuCell2:47` → MLabel 默认 12）", 第0.get_theme_font_size("font_size") == 12)
		_比("菜单最小尺寸 90×20（`RankMenuCell2` selectedBg 90×20）", 第0.custom_minimum_size == Vector2(90, 20))
	_比("规则第一屏 = menuId 0 的 desc（`selecteRankMenu:247 _ruleText = descs[0]`），实际「%s」"
			% (页.get_node("规则") as Label).text,
			(页.get_node("规则") as Label).text == "该榜收录等级大于20级，等级最高的前100名玩家")
	_比("等级榜（唯一没有 tongDesc 的那条）该藏掉同级榜", not (页.get_node("榜单分页/同级榜") as Button).visible)
	_比("忍界榜文字 = 「忍界榜」（`RANK_LIST_RENJIE_BANG`，旧版自造「人界榜」）",
			(页.get_node("榜单分页/忍界榜") as Button).text == "忍界榜")
	_比("同级榜文字 = 「同级榜」（`RANK_LIST_TONGJIE_BANG`，旧版自造「统计榜」）",
			(页.get_node("榜单分页/同级榜") as Button).text == "同级榜")
	_比("列头第一列固定「排名」（`RankListPane2:131` 不吃 setListTitle）",
			(页.get_node("名次标题") as Label).text == "排名")
	_比("等级榜第二列 = 「姓名」（showType 0）", (页.get_node("名称标题") as Label).text == "姓名")
	_比("等级榜第三列 = 该榜 valueName「等级」", (页.get_node("数值标题") as Label).text == "等级")
	_比("右上提示 = 「【每日凌晨6点更新排行资料】」",
			(页.get_node("提示") as Label).text == "【每日凌晨6点更新排行资料】")
	# 色号/字号：列头 `cretateLabel` 默认 16777215 白 12；提示 UI_GREEN 12；左栏标题 getLabel2 默认 #FFF000 12
	var 头 := 页.get_node("名次标题") as Label
	_比("列头必须白 12（旧版给的 #e7c37a 米黄原版没有这个色）",
			头.get_theme_color("font_color") == Color.WHITE and 头.get_theme_font_size("font_size") == 12)
	_比("列头居中（`cretateLabel:428 align=\"center\"`）",
			头.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
	var 提 := 页.get_node("提示") as Label
	_比("提示必须 #00FF00、12 号、居中（旧版是 10 号）",
			提.get_theme_color("font_color") == Color("#00ff00") and 提.get_theme_font_size("font_size") == 12
			and 提.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
	var 分 := 页.get_node("分类标题") as Label
	var 规 := 页.get_node("规则标题") as Label
	_比("左栏两标题必须 #FFF000（旧版自造暖黄 #ffd27c）",
			分.get_theme_color("font_color") == Color("#FFF000") and 规.get_theme_color("font_color") == Color("#FFF000"))
	_比("左栏两标题不许居中（`BaseUtil.getLabel2` 不设 align ⇒ 左对齐）",
			分.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT and 规.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT)
	_比("页码白 12 居中（`PageComponent:144-149 textColor=16777215` + TextFormat 默认 12、align=CENTER）",
			码.get_theme_color("font_color") == Color.WHITE and 码.get_theme_font_size("font_size") == 12
			and 码.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
	_比("规则自动换行（`TextArea2.createTf` wordWrap=true）",
			(页.get_node("规则") as Label).autowrap_mode != TextServer.AUTOWRAP_OFF)
	_比("规则行距 6（Flash leading 4 + 工程口径 +2），实际 %d"
			% (页.get_node("规则") as Label).get_theme_constant("line_spacing"),
			(页.get_node("规则") as Label).get_theme_constant("line_spacing") == 6)
	_比("「我的排名」是 RichTextLabel 且开了 BBCode（原版赋的是双色 htmlText）",
			(页.get_node("我的排名") as RichTextLabel).bbcode_enabled)
	_比("「我的排名」字号 12（`RankWindow2:427 _loc7_.size = 12`）",
			(页.get_node("我的排名") as RichTextLabel).get_theme_font_size("normal_font_size") == 12)

	# ── ③ 灌 25 行（我在第 12 行）⇒ 分页 / 染色 / 扫行算名次 ──────────────────
	假.sent_requests.clear()
	假.call("_handle_bridge_text", _帧(0, true, 0, _造行(25, 11)))
	for _i in 3:
		await process_frame
	页 = _取页(窗)
	var 列表 := 页.get_node("排行榜列表") as Control
	_比("回帧后第 1 页该画 10 行（`PageComponent(50,10)` 的 `_pageItems`），实际 %d" % 列表.get_child_count(),
			列表.get_child_count() == 10)
	for i in 列表.get_child_count():
		var 行 := 列表.get_child(i) as Control
		var 名 := 行.get_node("名次") as Label
		var 字 := 行.get_node("名称") as Label
		var 值 := 行.get_node("数值") as Label
		_比("第 %d 行的名次应为 %d（全表下标 +1，不是页内下标）" % [i + 1, i + 1], 名.text == str(i + 1))
		_比("第 %d 行的姓名应取回帧第 3 段，实际「%s」" % [i + 1, 字.text], 字.text == "忍者%02d" % (i + 1))
		_比("第 %d 行的数值应取回帧第 5 段原样串，实际「%s」" % [i + 1, 值.text], 值.text == str(1000 - i))
		var 期 := Color.WHITE
		if i == 0:
			期 = Color("#ff0000")
		elif i == 1:
			期 = Color("#00ff00")
		elif i == 2:
			期 = Color("#1E90FF")
		_比("第 %d 行整行三列同色应为 %s（1红/2绿/3蓝/其余白；不是只染名次那列）" % [i + 1, 期.to_html(false)],
				名.get_theme_color("font_color") == 期 and 字.get_theme_color("font_color") == 期
				and 值.get_theme_color("font_color") == 期)
		_比("第 %d 行 y 应为 %d（步长 23 = cell 高 25 − 2），实际 %s" % [i + 1, i * 23, 行.position.y],
				is_equal_approx(行.position.y, float(i * 23)))
	_比("行宽 230（= myRankbg 与列宽）", is_equal_approx((列表.get_child(0) as Control).size.x, 230.0))
	_比("25 件 ⇒ 页码 \"1/3\"，实际 [%s]" % (页.get_node("分页条/页码") as Label).text,
			(页.get_node("分页条/页码") as Label).text == "1/3")
	# 扫行找自己：我在下标 11 ⇒ 第 12 名（**不吃服务端那个 rank**：`onPaiHang_searchResult:86-92` 丢了它）
	var 我文 := (页.get_node("我的排名") as RichTextLabel).text
	_比("「你的当前排名」应扫到第 12 名，实际 [%s]" % 我文, 我文.contains("你的当前排名") and 我文.contains("12"))
	_比("「你的当前排名」是双色 BBCode（两截 `[color=`），实际 [%s]" % 我文,
			我文.count("[color=") == 2)
	_比("尖括号标签必须已经被剥掉（漏 `<font` 就当正文显示，§3.214 同型事故）", not 我文.contains("<font"))
	_比("扫到了人 ⇒ 不许出现「未上榜」", not 我文.contains("未上榜"))
	# 下一页
	(页.get_node("分页条/下一页") as TextureButton).pressed.emit()
	for _i in 3:
		await process_frame
	页 = _取页(窗)
	列表 = 页.get_node("排行榜列表") as Control
	_比("翻到第 2 页页码 \"2/3\"，实际 [%s]" % (页.get_node("分页条/页码") as Label).text,
			(页.get_node("分页条/页码") as Label).text == "2/3")
	if 列表.get_child_count() == 10:
		var 首 := 列表.get_child(0) as Control
		_比("第 2 页第一行名次应是 11（`(页−1)*10 + i + 1`），实际 [%s]" % (首.get_node("名次") as Label).text,
				(首.get_node("名次") as Label).text == "11")
		_比("第 2 页首行不是前三 ⇒ 白字（染色看**名次**，不是看第几页第几行）",
				(首.get_node("名次") as Label).get_theme_color("font_color") == Color.WHITE)
		_比("第 2 页第一行的 y 要回到 0（页内偏移，不是接着第 11 行往下画）",
				is_equal_approx(首.position.y, 0.0))
	_比("第 2 页首页/上一页该亮（currentPage 2 > 1）",
			not (页.get_node("分页条/首页") as TextureButton).disabled
			and not (页.get_node("分页条/上一页") as TextureButton).disabled)
	_比("第 2 页下一页/末页该亮（2 < 3）",
			not (页.get_node("分页条/下一页") as TextureButton).disabled
			and not (页.get_node("分页条/末页") as TextureButton).disabled)
	(页.get_node("分页条/末页") as TextureButton).pressed.emit()
	for _i in 3:
		await process_frame
	页 = _取页(窗)
	列表 = 页.get_node("排行榜列表") as Control
	_比("末页页码 \"3/3\"，实际 [%s]" % (页.get_node("分页条/页码") as Label).text,
			(页.get_node("分页条/页码") as Label).text == "3/3")
	_比("25 件的第 3 页只有 5 行（`currentPage` setter 把 indexEnd 夹到 totalItems），实际 %d" % 列表.get_child_count(),
			列表.get_child_count() == 5)
	if 列表.get_child_count() == 5:
		_比("末页首行名次应是 21", (列表.get_child(0) as Control).get_node("名次").text == "21")
	_比("末页时下一页/末页该禁用（currentPage 3 不 < totalPage 3）",
			(页.get_node("分页条/下一页") as TextureButton).disabled
			and (页.get_node("分页条/末页") as TextureButton).disabled)
	_比("末页时首页该亮", not (页.get_node("分页条/首页") as TextureButton).disabled)

	# ── ④ 换榜（点菜单第 3 枚 = 宠物身价榜）：上行 / 列头 / 规则 / 藏露同级榜 ──
	假.sent_requests.clear()
	(页.get_node("榜单滚动/榜单容器").get_child(2) as Button).pressed.emit()
	for _i in 3:
		await process_frame
	页 = _取页(窗)
	_比("点菜单第 3 枚要发 `0:2:1`（第二格是**榜单号 menuId**，不是 0..3 的页签序号），实得 [%s]"
			% (String(假.sent_requests[0].content) if 假.sent_requests.size() > 0 else "无"),
			假.sent_requests.size() == 1 and String(假.sent_requests[0].content) == "0:2:1")
	_比("换榜后该榜没回帧 ⇒ 一行不画（不许把上一个榜的行留在页上）",
			(页.get_node("排行榜列表") as Control).get_child_count() == 0)
	_比("换榜后没回帧 ⇒ 页码回到构造期 \"1/5\"（不是接着上一个榜的 3/3）",
			(页.get_node("分页条/页码") as Label).text == "1/5")
	_比("showType=1 那榜的第二列该是「宠物主人」，实际「%s」" % (页.get_node("名称标题") as Label).text,
			(页.get_node("名称标题") as Label).text == "宠物主人")
	_比("宠物身价榜第三列 = valueName「宠物身价」，实际「%s」" % (页.get_node("数值标题") as Label).text,
			(页.get_node("数值标题") as Label).text == "宠物身价")
	_比("换榜后规则 = 该榜 desc，实际「%s」" % (页.get_node("规则") as Label).text,
			(页.get_node("规则") as Label).text == "该榜收录通灵兽身价高于500，身价最高的前100只通灵兽")
	_比("有 tongDesc 的榜要**露出**同级榜", (页.get_node("榜单分页/同级榜") as Button).visible)
	_比("换榜必回忍界榜（`selecteRankMenu:252` 末尾那句 `__onRenJieBtnClick(null)`）",
			(页.get_node("榜单分页/忍界榜") as Button).disabled
			and not (页.get_node("榜单分页/同级榜") as Button).disabled)
	_比("换榜后菜单第 3 枚选中、第 1 枚跟着灭", (页.get_node("榜单滚动/榜单容器").get_child(2) as Button).button_pressed
			and not (页.get_node("榜单滚动/榜单容器").get_child(0) as Button).button_pressed)
	# 点同级榜 ⇒ 上行最后那格 bool 翻成 0（原版 `requestListData:106` = `!renJieBtn.enabled`）
	假.sent_requests.clear()
	(页.get_node("榜单分页/同级榜") as Button).pressed.emit()
	for _i in 3:
		await process_frame
	页 = _取页(窗)
	_比("同级榜上行要发 `0:2:0`，实得 [%s]" % (String(假.sent_requests[0].content) if 假.sent_requests.size() > 0 else "无"),
			假.sent_requests.size() == 1 and String(假.sent_requests[0].content) == "0:2:0")
	_比("点同级榜后规则换成 tongDesc，实际「%s」" % (页.get_node("规则") as Label).text,
			(页.get_node("规则") as Label).text == "该榜收录与您当前级别相同，拥有通灵兽中身价最高的前100只通灵兽")
	_比("选中那枚走 disabled 槽（`MTabButton:38 set enabled(v){selected=!v}` ⇒ 同 `选页签` 口径）",
			(页.get_node("榜单分页/同级榜") as Button).disabled
			and not (页.get_node("榜单分页/忍界榜") as Button).disabled)

	# ── ⑤ 空表回帧 ⇒ "1/0" + 四枚全灰（跟"没回帧"的 1/5 是两种态）─────────────
	假.call("_handle_bridge_text", _帧(2, true, 0, "-"))
	for _i in 3:
		await process_frame
	页 = _取页(窗)
	_比("空表页码 \"1/0\"（`reset(0,10)` ⇒ `_totalPage=0`），实际 [%s]" % (页.get_node("分页条/页码") as Label).text,
			(页.get_node("分页条/页码") as Label).text == "1/0")
	for 名 in ["首页", "上一页", "下一页", "末页"]:
		_比("空表时「%s」四枚全禁用" % 名, (页.get_node("分页条/" + 名) as TextureButton).disabled)
	_比("空表 ⇒ 一行不画（`-` 是\"一个都没有\"，不是一条空行）",
			(页.get_node("排行榜列表") as Control).get_child_count() == 0)

	# ── ⑥ 本榜回帧把页序打回第 1 页；**别的榜**不许打回 ───────────────────────
	# 走到这里当前榜已经是 menuId 2（④ 点的第 4 枚菜单，⑤ 灌的空表也是 2）⇒
	# 本段一律灌 2，灌 0 只能验「不动」。
	假.call("_handle_bridge_text", _帧(2, true, 0, _造行(25, 11)))
	for _i in 3:
		await process_frame
	页 = _取页(窗)
	_比("本榜回帧后页序归 0 ⇒ 宠物身价榜该回 \"1/3\"（原版 `setData:366` 那句 reset），实际 [%s]"
			% (页.get_node("分页条/页码") as Label).text, (页.get_node("分页条/页码") as Label).text == "1/3")
	(页.get_node("分页条/下一页") as TextureButton).pressed.emit()
	for _i in 3:
		await process_frame
	页 = _取页(窗)
	_比("先翻到宠物身价榜第 2 页，实际 [%s]" % (页.get_node("分页条/页码") as Label).text,
			(页.get_node("分页条/页码") as Label).text == "2/3")
	假.call("_handle_bridge_text", _帧(1, true, 0, _造行(3)))
	for _i in 3:
		await process_frame
	页 = _取页(窗)
	_比("别的榜（财富榜）的回帧不许动我正在看的宠物身价榜页序（仍 2/3），实际 [%s]"
			% (页.get_node("分页条/页码") as Label).text, (页.get_node("分页条/页码") as Label).text == "2/3")
	var 首行名 := (((页.get_node("排行榜列表") as Control).get_child(0) as Control).get_node("名称") as Label).text
	_比("别的榜的回帧也不许换掉我正在看的行（第 2 页首行仍是「忍者11」），实际 [%s]" % 首行名, 首行名 == "忍者11")

	# ── ⑦ 不在榜 ⇒ 未上榜 ─────────────────────────────────────────────────────
	假.call("_handle_bridge_text", _帧(2, true, 0, _造行(3)))
	for _i in 3:
		await process_frame
	页 = _取页(窗)
	var 末 := (页.get_node("我的排名") as RichTextLabel).text
	_比("表里没有我 ⇒ 「未上榜」（`queryMyRank:96-100` 找不到走 RANK_MY_RANK_NOT_ENOUGH），实际 [%s]" % 末,
			末.contains("未上榜"))
	_比("cmd1 回帧里服务端那个 rank 不许被界面吃（这里是客户端扫表的结果）", 末.contains("未上榜"))

	窗.set("_backend", 真后端)
	假.free()
	场景.queue_free()
