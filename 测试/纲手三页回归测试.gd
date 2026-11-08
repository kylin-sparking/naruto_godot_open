extends SceneTree

## 「纲手三页」离线回归门：NPC 对话窗 / 副本传送窗 / 精英副本窗。
##
## 一页一个 `测试/<页>页回归测试.gd` 是这工程的惯例，但这次三扇窗是**同一个入口带出来的一族**
## （纲手 → 挑战副本 / 挑战精英副本），共享同一批新素材（`素材/界面/原版窗口/副本/` 12 张）、
## 同一份语言表（`数据/界面/副本_文案.json`）与同一份尺寸表条目 ⇒ 合成一道门，
## 三段的判据互不共享，红在哪一段日志里直接点名。
##
## 口径（和 宝石工艺/秘笈合成 那两道门同一条）：
##   * **只读磁盘文本**，不 `load()` 场景 ⇒ 无头跑、不写存档、不碰 `user://玩家数据.json`。
##   * 容差 `容差 := 0.02` 像素（不是 1.0 —— 1.0 会放过整整 1px 的漂移，2026-10-03 变异测试抓到）。
##   * 每条判据都要**能红**：改错一个数它必须响。表里每条都注了它在防哪一种复发。
##
## 用法：Godot --headless --path . --script res://测试/纲手三页回归测试.gd

const 容差 := 0.02
const 表 := {
	"对话": "res://场景/界面/窗口/NPC对话/NPC对话窗.tscn",
	"副本": "res://场景/界面/窗口/副本/副本窗口.tscn",
	"精英": "res://场景/界面/窗口/副本/精英副本窗.tscn",
}

var 红 := 0
var 日志: Array[String] = []


func _initialize() -> void:
	读表()
	验对话()
	验副本()
	验精英()
	验共用()
	for 一 in 日志:
		print(一)
	print("纲手三页回归：%s（红 %d 项）" % ["通过" if 红 == 0 else "不通过", 红])
	quit(1 if 红 > 0 else 0)


func 读(路径: String) -> String:
	var f := FileAccess.open(路径, FileAccess.READ)
	if f == null:
		记(false, "读不到 %s" % 路径)
		return ""
	return f.get_as_text()


func 记(过: bool, 文本: String) -> void:
	if not 过:
		红 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 文本])


func 数(文: String, 式: String) -> int:
	var re := RegEx.new()
	re.compile(式)
	return re.search_all(文).size()


var 文本 := {}
var 尺寸 := {}
var 文案 := {}
var 布局 := {}
var 配置 := {}


func 读表() -> void:
	for k in 表:
		文本[k] = 读(表[k])
	var f := FileAccess.open("res://数据/界面/窗口尺寸.json", FileAccess.READ)
	尺寸 = JSON.parse_string(f.get_as_text()) if f else {}
	f = FileAccess.open("res://数据/界面/副本_文案.json", FileAccess.READ)
	文案 = JSON.parse_string(f.get_as_text()) if f else {}
	f = FileAccess.open("res://数据/界面/精英副本_布局.json", FileAccess.READ)
	布局 = JSON.parse_string(f.get_as_text()) if f else {}
	f = FileAccess.open("res://数据/副本.json", FileAccess.READ)
	配置 = JSON.parse_string(f.get_as_text()) if f else {}


func 验对话() -> void:
	日志.append("=== 一、NPC 对话窗（QuestDialog 506 两格）===")
	var 文: String = 文本["对话"]
	# 15 → **16**：2026-10-09 加「剧情面」那枚 `下格/回应`（原版 `createPlayerTextArea():404-416`
	# 的一行绿色玩家回应）。由 `开发工具/生成NPC对话场景.py` 烘，别手改场景。
	记(数(文, '(?m)^\\[node name=') == 16, "节点 16 个（15 + 剧情面的 下格/回应；实 %d）" % 数(文, '(?m)^\\[node name='))
	记(数(文, 'parent="\\.\"') == 2, "根的直接子节点 2 个（上格 / 下格）")
	记('parent=""' not in 文, "没有 parent=\"\"（会让 load 递归爆栈）")
	记(数(文, 'name="行[0-9]"') == 3, "菜单烘了 3 行（纲手：挑战副本/挑战精英副本/离开）")
	记('text = "纲手"' in 文, "名字烘的是语言表/NPC.json 的「纲手」")
	记('text = "挑战精英副本"' in 文, "第 2 行文案逐字对（不是自造的「精英副本」）")
	记(数(文, 'mouse_default_cursor_shape = 2') == 3, "三行都是手型（`SelectionLalel:446-447`）")
	# 九宫格边距只认 MainLib.xml 的 DefineScalingGridTag（禁拟合值）
	# ⚠ 名字认 `patch_margin_*`：上格/下格是 **NinePatchRect**，`texture_margin_*` 落不进（体检 #51，
	#   2026-10-20 之前这两条读的是**同一条死属性** ⇒ 门绿着、底图却整片拉伸）。
	#   且 NinePatchRect 的边距是 **int** ⇒ XML 的 41.5 / 7.75 / 10.5 / 9.05 只能四舍五入落 42/8/11/9。
	记('patch_margin_left = 8' in 文 and 'patch_margin_top = 30' in 文
			and 'patch_margin_right = 42' in 文 and 'patch_margin_bottom = 8' in 文,
			"上格边距 8/41.5→42/30/7.75→8（794 @MainLib.xml:11757，九宫 int ⇒ 取整）")
	记('patch_margin_left = 11' in 文 and 'patch_margin_right = 9' in 文
			and 'patch_margin_top = 8' in 文 and 'patch_margin_bottom = 9' in 文,
			"下格边距 10.5→11/9.05/8/9（797 @MainLib.xml:11792）")
	记('offset_right = 506' in 文, "两格都 506 宽（元件原生宽，不是截图量出来的 504）")
	记(数(文, 'name="台词"') == 1 and '[color=#ffffff]' in 文, "台词套白（`:384` 硬写的 #ffffff）")
	记('font_color = Color(1, 0.941176, 0, 1)' in 文, "名字 = UI_YELLOW #FFF000")
	记('font_color = Color(0, 1, 0, 1)' in 文, "菜单字 = UI_GREEN #00FF00")


func 验副本() -> void:
	日志.append("=== 二、副本传送窗（CopyWindow 570×283）===")
	var 文: String = 文本["副本"]
	var 条: Array = (配置.get("副本", []) as Array)
	记(数(文, '(?m)^\\[node name=') == 92, "节点 92 个（2.2.3 版 8 行 × 7 件；实 %d）" % 数(文, '(?m)^\\[node name='))
	记('parent=""' not in 文, "没有 parent=\"\"")
	记(数(文, 'name="行[0-9]+" type="Control"') == 8, "列表烘了 8 行 = 2.2.3 版 getAllFuBenObj+filterData 之后 8 条")
	# 数据源漂移哨兵：2.2.3 那版是这 8 个名字；读到 V2.6 会多出「刷连斩」、血之羁绊变单人
	for 名 in ["第1演习场", "命运之抉择", "秽土转生", "挑战第七班", "挑战尾兽",
			"血之羁绊", "迷路森林", "修炼场"]:
		记(('text = "%s"' % 名) in 文, "副本名 %s 在（2.2.3 版）" % 名)
	记('text = "刷连斩"' not in 文, "没有「刷连斩」（那是 V2.6 多出来的一条 ⇒ 出现就是数据源漂了）")
	记('text = "组队"' in 文, "血之羁绊那行是「组队」（2.2.3 teamType=2；V2.6 会全变单人）")
	# 通关奖励三条 ×1（2.2.3）：进阶符 / 手里剑木桩 / 柔拳灵符（16000012 / 32 / 57）
	for 奖 in ["【进阶符×1】", "【手里剑木桩×1】", "【柔拳灵符×1】"]:
		记(('text = "[color=#00ff00]' in 文) and (奖 in 文), "奖励含 %s" % 奖)
	记("×100" not in 文, "没有 ×100 那批（V2.6 把奖励数量整体放大过）")
	记(数(文, 'name="星[0-9]+"') == 7, "星级烘 7 槽（数据最大 stars=6）")
	# 旧薄壳的四样东西必须一个都不剩（防"生成器没跑、场景被回退"）
	for 旧 in ['name="副本列表框"', 'name="详情框"', 'type="ItemList"', 'name="领取" type="Button"']:
		记(旧 not in 文, "旧薄壳的 %s 已经不在了" % 旧)
	记('text = "副本名称"' in 文 and 'text = "组队"' in 文 and 'text = "次数"' in 文,
			"三枚列头逐字对语言表（COPY_NAME / TROOP_TITLE / COPYWINDOW_COUNT）")
	记('text = "副本内奖励丰厚度："' in 文, "COPY_MEED 整句在（含全角冒号，少一个字就红）")
	记('text = "只显示我可以参与的副本"' in 文, "COPY_MCHECK 整句在")
	记('text = "副本密卷进入"' in 文, "COPY_MIJUAN_JINRU 是「密卷」不是「密室」")
	记('text = "查看副本竞速榜"' in 文, "COPY_PAIHANG 烘着且只是 visible=false（原版没删这颗钮）")
	记(数(文, 'name="竖向分隔线"') + 数(文, 'name="列分隔') == 3, "三根列分隔（TableSeparatorLineF 2×20）")
	记('horizontal_scroll_mode = 3' in 文, "两个滚动区都锁横向滚动（原版 horizontalScrollPolicy=OFF）")
	# 钮必须是预烘到目标宽的整帧皮三档（isScale9Grid=false ⇒ 不许九宫格、不许 modulate）
	for 组 in [["钮_进入.png", 37], ["钮_密卷.png", 82]]:
		记(('name="%s"' % 组[0]) not in 文 and ('res://素材/界面/原版窗口/副本/%s' % 组[0]) in 文,
				"%s 被引用" % 组[0])
		记('texture_margin_left = 0' in 文, "钮的样式盒边距全 0（整帧拉伸，不是九宫格）")
	记(数(文, 'mouse_default_cursor_shape = 2') == 6,
			"底栏 6 颗钮全是手型（进入/密卷/排行 + 本工程那三枚流程钮；`MButton3.init:135`）")
	# 次数列：实机是 `0/1次`（COPY_CELL_COUNT = %1/%2次）
	记(数(文, 'text = "0/1次"') == 8, "8 行的次数列都烘成 0/1次（语言表 %1/%2次 填 0 与上限）")
	记(str((尺寸.get("副本", {}) as Dictionary).get("标题", "")) == "副本传送",
			"窗口标题 = COPY_WINDOW_TITLE「副本传送」（不是自造的「挑战副本」）")
	记(bool((尺寸.get("副本", {}) as Dictionary).get("整框", false)),
			"尺寸表 副本 有 `整框: true`（缺了整页右下各偏 8/38px）")


func 验精英() -> void:
	日志.append("=== 三、精英副本窗（EliteCopyWindow 500×426）===")
	var 文: String = 文本["精英"]
	var 页: Array = (布局.get("页", []) as Array)
	记(数(文, '(?m)^\\[node name=') == 186, "节点 186 个（实 %d）" % 数(文, '(?m)^\\[node name='))
	记('parent=""' not in 文, "没有 parent=\"\"")
	记(数(文, 'name="页签[0-9]"') == 4, "4 枚页签 = Hero 表 4 页")
	记(数(文, 'name="格[0-9]+" type="Control"') == 21, "21 枚格全烘（4+5+5+7，编辑器=运行期）")
	记(数(文, 'name="线[0-9]"') == 3, "3 根分隔线（5 枚以上的页才有，`createCell:114-122`）")
	记(数(文, 'name="页[0-9]" type="Control"') == 4, "4 个子页容器")
	记(数(文, 'visible = false') >= 4, "非当前页常驻隐藏")
	# 页签四档皮：disabled 档 = selectedUpSkin 原色（那张名叫 `*_disabled` 的皮）
	for 皮 in ["页签_未选.png", "页签_未选_悬停.png", "页签_选中.png"]:
		记(('res://素材/界面/原版窗口/副本/%s' % 皮) in 文, "页签皮 %s 接上了" % 皮)
	记(数(文, 'texture_margin_left = 0') > 0, "页签样式盒边距 0（isScale9Grid=false ⇒ 整帧）")
	记(数(文, 'name="页签0"') == 1 and 'button_pressed = true' in 文 and 'disabled = true' in 文,
			"第 0 枚烘成选中态（`createTabBtn:340-341` curSelectTabBtn.enabled=false）")
	# 格内子件序 = addChild 序；头像只有 6 张有源，其余必须**留空**而不是拿别的怪凑
	for 件 in ["格底", "锁", "选中底", "名", "章节", "头像", "次数"]:
		记(数(文, 'name="%s"' % 件) == 21, "每枚格都有「%s」" % 件)
	记(数(文, 'name="精英格底.png"') == 0 and '原版窗口/副本/精英格底.png' in 文, "格底 = UISwf chid 9")
	记('原版窗口/副本/精英格锁.png' in 文 and '原版窗口/副本/精英格选中.png' in 文,
			"锁 = chid 6、选中 = chid 3（ffdec 打的 cls 为准）")
	# bug1 的哨兵：`PortraitHead` 的取图走 `PicTool.getMonsterObject`，那里有 `info.link` 兜底
	# （`PicTool.as:76-88`：BOSS 自己没头像就用它 link 的那个基础怪的头像）。
	# 上一轮我漏了这条，判成"原版数据就没有" ⇒ 15 个格子空圈。
	var 无脸 := 0
	var 走兜底 := 0
	for 页据 in ((布局.get("页", []) as Array)):
		for 格 in (页据["格"] as Array):
			if str(格["头像"]) == "":
				无脸 += 1
			# ⚠ 表里"没有 link"是**显式写 null**，不是缺键 ⇒ `get(键, 0)` 的兜底不会生效。
			#   而 `int(null)` 与 `bool(null)` 同族抛 `Nonexistent 'int' constructor`（§3.244），
			#   当场打断本函数 ⇒ 后面几条判据静默不计、门照样绿。旧写法 `int(... or 0)` 靠
			#   `or` 返回 bool 碰巧不抛，但那正是"恒真/恒假"的坑，不要退回它。
			#   ⚠ `JSON.parse_string` 把这些号解成 **float** ⇒ `链 is int` 恒 false（本轮先红过一次才看清）。
			var 链: Variant = 格.get("链接自")
			if (typeof(链) == TYPE_INT or typeof(链) == TYPE_FLOAT) and int(链) != 0:
				走兜底 += 1
	记(无脸 == 0, "21 枚格全部有头像（空圈 %d 个）" % 无脸)
	记(走兜底 == 15, "15 枚走 link 兜底（实 %d）—— 5200001~14、5200045 自己没头像" % 走兜底)
	记(int(((布局["页"][0] as Dictionary)["格"][0] as Dictionary)["头像怪"]) == 2000001,
			"波之国第1章(5200010) 的头像取自 link 的 2000001")
	记(int(((布局["页"][3] as Dictionary)["格"][5] as Dictionary)["头像怪"]) == 2000023,
			"挑战佩恩 天道(5200045) 的头像取自 link 的 2000023（佩恩六道）")
	记(str((尺寸.get("精英副本", {}) as Dictionary).get("标题", "")) == "精英副本",
			"尺寸表 精英副本 标题 = ELITECOPY_WINDOW_TITLE")
	记(bool((尺寸.get("精英副本", {}) as Dictionary).get("整框", false)),
			"尺寸表 精英副本 有 `整框: true`")


func 验共用() -> void:
	日志.append("=== 四、三页共用件与接线 ===")
	for 键 in ["COPY_WINDOW_TITLE", "COPY_NAME", "COPY_MEED", "COPY_MCHECK", "COPY_JINRU",
			"COPY_MIJUAN_JINRU", "COPY_CELL_COUNT", "ELITECOPY_WINDOW_TITLE",
			"ELITECOPY_WINDOW_COPYNAME", "CHAPTER", "ELITE_COPY_CELL_COUNT", "FAMILLY_MANAGER_WU"]:
		记(文案.has(键), "文案表有 %s" % 键)
	记(str(文案.get("COPY_CELL_COUNT", "")) == "%1/%2次", "COPY_CELL_COUNT 占位符没被提前吃掉")
	记(str(文案.get("CHAPTER", "")) == "第%1章", "CHAPTER 占位符没被提前吃掉")
	# 控制器切件：功能窗口 必须不再自己 preload 那两页的场景
	var 功: String = 读("res://脚本/界面/功能窗口.gd")
	var 系: String = 读("res://脚本/界面/窗口/系统窗口.gd")
	记('const 副本窗口 := preload("res://脚本/界面/窗口/副本窗口.gd")' in 系,
			"系统窗口 preload 的是副本控制器（不是场景）")
	记('const 精英副本窗口 := preload("res://脚本/界面/窗口/精英副本窗口.gd")' in 功,
			"功能窗口 preload 的是精英副本控制器")
	记('"精英副本": _render_elite_copy()' in 功, "match 表里有「精英副本」这一页")
	记(副本页面场景已切走(系), "系统窗口 不再 preload 副本场景、也不再自己画那一页")
	记("_copy_selected_id" not in 功 and "_copy_selected_id" not in 系,
			"宿主不再留 _copy_selected_id 副本（页态只存控制器自己的 static var）")
	# 菜单必须是解析服务端 328 帧来的，不许客户端自造菜单表
	var 后: String = 读("res://脚本/单例/后端连接.gd")
	记("func _解析NPC菜单" in 后, "后端连接 有 328 帧 menu 段的解析")
	记('"menu"' in 后 and '@'.length() > 0, "menu 段按 @ 拆项")
	var 对: String = 读("res://脚本/界面/窗口/NPC对话窗.gd")
	记("request_npc_menu_action" in 对, "点行走既有 request_npc_menu_action（57 子命令 2）")
	记("signal 行被点" in 对 and "行被点.emit" in 对,
			"点行之后广播 `行被点(动作值)` —— 原版是回包开窗（Client.as:1212 / :1149），"
			+ "本工程这两扇是 功能窗口 的页，必须有人把页叫出来")
	记("get_viewport()" in 对 and "_居中()" in 对,
			"对话窗自己按视口居中（原版 `PopUpMananger.centerWindow`；症状 = 弹窗跑到左上角）")
	var 面: String = 读("res://脚本/界面/小地图面板.gd")
	# 2026-10-04 并「木叶村NPC页」后：落地表**不再硬编码在脚本里**，改成由 `数据/界面/木叶村NPC.json`
	# 现算（作者口径：客户端不自己发明菜单）⇒ 真值改从那张表里验。
	记('const NPC表路径 := "res://数据/界面/木叶村NPC.json"' in 面 and "_落地[码]" in 面,
			"小地图面板 的落地表由 `木叶村NPC.json` 现算（不再硬编码页名字典）")
	# ⚠ 2026-10-08 补两条：并包时这两处被静默弄断过（副本/精英副本点了不开）——
	#   ① "等回帧"那条路的**唯一连接点**必须在 `_connect_session()` 里；
	#   ② `request_copy_history()` 在**后端**上，写 `_session.` 会 Nonexistent function 当场中断。
	记('_session.copy_changed.connect(_on_copy_landed)' in 面
			and '_session.hero_state_changed.connect(_on_hero_landed)' in 面,
			"小地图面板 在 `_connect_session()` 里连了 copy_changed / hero_state_changed（等回帧的唯一入口）")
	记('_session.request_copy_history' not in 面,
			"819 兜底自拉走后端（`_session.request_copy_history` 不存在，写了就是当场中断）")
	var 表: Dictionary = JSON.parse_string(读("res://数据/界面/木叶村NPC.json"))
	var 映射: Dictionary = {}
	for 枚 in (表.get("npc", []) as Array):
		for 行 in (枚.get("菜单", []) as Array):
			映射[int(行.get("动作", -1))] = String(行.get("落地页", ""))
	记(映射.get(12, "") == "副本" and 映射.get(30, "") == "精英副本",
			"动作值 12/30 在表里各自落到 副本 / 精英副本（服务端 NpcMenuAction.COPY / ELITE_COPY）")
	记('_对话.connect("行被点", _开NPC菜单页)' in 面, "该信号确实接到了 `_开NPC菜单页`")
	# 2026-10-04 用户点头三通:1828 从"未接"升级为"必须已接"——反向钉。
	var 英: String = 读("res://脚本/界面/窗口/精英副本窗口.gd")
	记("request_hero_enter" in 英, "精英点格走真 1828 HERO_ENTER（用户已批准接通，回退成回执=红）")
	记("request_hero_info" in 英 and "hero_entries" in 英,
			"精英开窗自拉 1828/0 + 「x/y 次」吃回帧（hero_entries），不偷偷退回只读磁盘表")
	记("request_hero_enter" not in 对.to_lower(),
			"对话窗本体不碰 1828（发包归精英控制器，它只广播 行被点）")


func 副本页面场景已切走(系: String) -> bool:
	return 'const 副本页面场景 := preload' not in 系 and '副本窗口.渲染(窗口)' in 系
