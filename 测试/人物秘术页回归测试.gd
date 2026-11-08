extends SceneTree

## 命名坑（10-18 实测踩过，别再犯）：本文件里的辅助函数**不能取名 `_可见`** ——
## `SceneTree` 自带属性 `SceneTree.visible`，同名函数会被解析成"调用一个布尔属性"，
## 报 `Called non-existant function "_可见" on base "SceneTree"`。下面统一叫 `_一路可见下来`。

## 人物面板「秘术 / 血继界限」五个页面的回归：**写轮眼 / 柔拳 / 寄坏之术 / 轮回六道 / 八门**，
## 外加结印那一整串（`_验结印页`，2026-10-17 巡检 #12：自动提升的客户端循环 + 二次确认 + 弹窗跨重建；
## ⓿ `_验结印置灰`，2026-10-27 用户报修：**未完成的印（印号 > 当前阶）整枚套禁用灰度**，
##    真值 `JieYinPanel.as:475-500 updateButtonState` —— 当前阶那枚不灰、数值容器不灰）。
##
## 为什么要单拎一条（2026-09-24）：这四页的**界面由另一位开发者重做过**，
## 走的是「用他的 `.tscn` + 由 `人物窗口.gd` 按他的节点接线」这条路
## （与八门页同一套，见 `人物窗口.初始化八门页` 上方的说明）。
## 换场景那天，`脚本加载回归测试` 与 `功能入口回归测试` **两条都是绿的** ——
## 因为它们**一条都不会打开这些页面**。旧接线照的还是旧节点路径
## （`页面.get_node("写轮眼状态")` / `"阶段图"` …），他那一版里一个都没有，
## 点开就报错，而全套用例毫无反应。**这条就是补那个盲区**。
##
## 钉三件事：
##  ① 四页都**能建出来**（场景实例化、可见、页面自己的脚本挂上了）；
##  ② **服务端的 `stage` 真的推到了他的脚本里** —— 每页读他那边的字段回验
##     （写轮眼 `_当前阶段` / 柔拳 `当前阶段` / 轮回六道 `current_index`），
##     注意这四套的**起算基数不一样**：写轮眼与轮回六道是 0 起算，柔拳是 1 起算；
##  ③ 提升弹窗的 **「开始提升按钮」接了线**（点了要能发协议）。
##
## 运行：Godot --headless --path . --script res://测试/人物秘术页回归测试.gd

# 主分页序号：0 角色 / 1 秘术 / 2 血继界限
const 页表 := [
	[2, 0, "写轮眼", "写轮眼切换_修正版.gd", "_当前阶段", 9, 8, "提升写轮眼阶数弹窗"],
	[2, 1, "轮回六道", "轮回六道切换.gd", "current_index", 4, 3, "提升轮回阶数弹窗"],
	[1, 1, "柔拳", "柔拳切换阶段.gd", "当前阶段", 5, 5, "提升柔拳阶数弹窗"],
	[1, 2, "寄坏之术", "", "", 0, 0, "昆虫强化弹窗"],
	[0, 2, "结印", "结印切换.gd", "", 0, 0, ""],   # 自己那扇的结印页走下面 ②c 那一坨
	[1, 0, "八门", "", "", 0, 0, ""],   # 顺带守「开通穴道弹窗」那个常亮 bug（见 ③b）
	# 结印在**角色**那一组（子分页组第 0 行是 `人物 / 手里剑 / 结印`），70 级开放。
	[0, 2, "结印", "结印切换.gd", "meta:stage", 7, 7, "提升结印阶数弹窗"],
]

## 寄坏槽位置（-200..-203）用公共表，别写死数字。
const 装备部位表 := preload("res://脚本/单例/装备部位.gd")
## 物品表（静态）：报修②要按"这一格实际穿着哪只虫"算期望名，不许写死蝉。
const 游戏数据表 := preload("res://脚本/单例/游戏数据.gd")

## 虫槽落点那双腿（2026-10-27 用户报修「昆虫不能佩戴 / 强化按键不能点击」）要直接问组件的类型闸。
const 昆虫放入格脚本 := preload("res://脚本/界面/组件/昆虫放入格.gd")
## 离线穿卸会真走 `_save_local_state()` 落盘 user:// ⇒ §3.76.1 规约：按字节快照、按字节还原。
const 门存档快照 := preload("res://测试/门存档快照.gd")

## 人物窗的**全部**子页（`人物窗口.主分页名称` × `子分页组`，8 个）—— 给第⑩条整窗扫选用。
const 子页清单 := [
	[0, 0, "人物"], [0, 1, "手里剑"], [0, 2, "结印"],
	[1, 0, "八门"], [1, 1, "柔拳"], [1, 2, "寄坏之术"],
	[2, 0, "写轮眼"], [2, 1, "轮回六道"],
]

## 三族「自动提升」那一串的参数表（巡检 #13）：
## `[族, 主分页, 子分页, 入口钮, 弹窗名, Etc 表段, 结果帧 opcode, 间隔毫秒, 成功要不要关弹窗, 起始阶]`。
## 后三列都是**有出处的差集**，不是随手填的：
##  · 间隔 = `RouQuanTiShengWindow:66` / `LunHuiYanTiShengWindow:201` 的 **800**，
##    写轮眼在 `TongshuSource:71`（循环挂管理器、不挂弹窗）是 **1000**；
##  · 成功关弹窗 = 写轮眼 `TongshuSource:78 onCloseBtnClick(null)`、轮回 `LunHuiYan:196
##    closeWindowHandler(null)` 当场收窗，柔拳 `:62` 只 `clearTimeout`、窗留着；
##  · 起始阶 = 上面 `页表` 灌进会话的那三档（取下一级配置用的就是这个数）。
const 自动族腿 := [
	["写轮眼", 2, 0, "提升写轮眼阶数", "提升写轮眼阶数弹窗", "XieLunYan", 1821, 1000, true, 9],
	["柔拳", 1, 1, "提升柔拳阶数", "提升柔拳阶数弹窗", "RouQuan", 2307, 800, false, 5],
	["轮回六道", 2, 1, "提升轮回六道", "提升轮回阶数弹窗", "LunHuiYan", 2313, 800, true, 4],
]

## 寄坏槽位置（-200..-203）用公共表，别写死数字。

var _失败: Array[String] = []

## ⑭ 那条腿**跑到底**的哨兵。2026-10-21 实测踩过：`窗.call("渲染人物页", …)` 报
## `Invalid call. Nonexistent function` 只把 `_验信息提示` 当场打断、不往 `_失败` 里记一笔
## ⇒ 门照样打「通过」。函数最后一句才置真，调用点见到假就判红。
var _信息提示跑完 := false

## ④ 昆虫强化弹窗那一条长腿（①~⑬ + 2026-10-27 的报修①②③④）的**跑到底**哨兵，同上面那条。
## 2026-10-27 反向对照实测：`_验昆虫弹窗` 在 ⑫ 那一腿被一枚 freed 的 `弹窗` 打断
## （`SCRIPT ERROR: Cannot call method 'get_node_or_null' on a previously freed instance`），
## 后面的报修①②③**一条都没跑**，门照样打「通过」⇒ 25 条变异里 11 条当场逃走。
## 光靠"退出码 + 失败行数"看不出这种截断 ⇒ 函数最后一句才置真，调用点见假就判红。
var _弹窗腿跑完 := false

## 2026-10-31 昆虫强化面板三修（没放虫/详情框层级/成功后同步）那条腿的跑到底哨兵。
var _同步腿跑完 := false

## §3.76.1「净效果为零」：虫槽落点那双腿会真走离线 `equip_item` ⇒ 落盘 user://。
var _文件前 := {}


func _initialize() -> void:
	_文件前 = 门存档快照.全快照()
	call_deferred("_跑")


func _跑() -> void:
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _序号 in 5:
		await process_frame

	var 会话: Node = root.get_node_or_null("/root/GameSession")
	if 会话 == null:
		_停("拿不到 GameSession")
		return
	# 灌一份**已知**的服务端状态，好逐页回验"推没推对"。
	会话.cultivation_states["写轮眼"] = {"stage": 9, "count": 3, "blessing": 40}
	会话.cultivation_states["柔拳"] = {"stage": 5, "count": 7}
	会话.cultivation_states["轮回六道"] = {"stage": 4, "count": 2}
	会话.cultivation_states["结印"] = {"stage": 7, "count": 12}

	var 管理: Node = 场景.get_node_or_null("窗口管理")
	var 窗 = 管理.call("取或建窗口", "人物") if 管理 != null else null
	if 窗 == null:
		_停("拿不到人物窗")
		return
	管理.call("打开", "人物")
	for _序号 in 4:
		await process_frame

	for 项: Array in 页表:
		var 主分页 := int(项[0])
		var 子分页 := int(项[1])
		var 名 := String(项[2])
		窗.call("_set_character_main_tab", 主分页)
		await process_frame
		窗.call("_set_character_sub_tab", 子分页)
		for _序号 in 3:
			await process_frame

		# ⚠️ 换页会重建 `_content`，上一轮的引用全部失效 —— 每轮重新取。
		var 页 := _取页(窗, 名)
		if 页 == null:
			_失败.append("「%s」没建出来" % 名)
			continue
		if not 页.visible:
			_失败.append("「%s」切过去之后不可见" % 名)
		# ①b **按需建**：一次渲染只该有当前这一页存在。
		#     7 个 .tscn 合计 2.6 万行，全建一次约 1.5 s，全花在一个看不见的页上。
		#     见 人物窗口.gd::确保子页。
		var 面板 := _扩展面板(窗)
		if 面板 != null and 面板.get_child_count() != 1:
			_失败.append("「%s」渲染后扩展页里有 %d 个子页（期望只建当前这 1 个）"
				% [名, 面板.get_child_count()])
		# ①c 三页的场景尺寸覆盖（`offset_right/bottom = 421/367`）不能丢
		if 名 in ["结印", "寄坏之术", "轮回六道"] and 页.offset_right != 421.0:
			_失败.append("「%s」的宽度覆盖丢了：offset_right=%s（期望 421）"
				% [名, str(页.offset_right)])
		var 期望脚本 := String(项[3])
		if not 期望脚本.is_empty():
			var 脚本: Script = 页.get_script()
			if 脚本 == null or (脚本 as Script).resource_path.get_file() != 期望脚本:
				_失败.append("「%s」上挂的不是他的脚本（期望 %s，实际 %s）"
					% [名, 期望脚本, (脚本 as Script).resource_path.get_file() if 脚本 != null else "无"])
			else:
				# ② 服务端 stage 有没有推到他那边去。结印页他脚本里**没有**阶段字段
				#   （`结印切换.gd` 只管选中框），阶段是宿主写进 `meta("stage")` 的 ⇒ 用
				#   `meta:` 前缀区分取法，别为了这条去改他的脚本。
				var 字段 := String(项[4])
				## 字段留空 = 这一行**只查页在不在/脚本挂没挂**，不查阶段
				## （`[0,2,"结印",…,""]` 那一行是给 ②c 的结印腿占位用的）。
				## ⚠️ 不判空就直接 `int(页.get(""))` ⇒ null 转 int 当场抛
				## `Nonexistent 'int' constructor`，_跑 断在这、门挂死（2026-10-22 全量批踩到）。
				if not 字段.is_empty():
					var 实测 := 0
					if 字段.begins_with("meta:"):
						实测 = int(页.get_meta(字段.trim_prefix("meta:"), -999))
					else:
						实测 = int(页.get(字段))
					var 期望 := int(项[6])
					if 实测 != 期望:
						_失败.append("「%s」服务端 stage=%d 应推成他的 %s=%d，实际 %d"
							% [名, int(项[5]), 字段, 期望, 实测])

		# ②b 写轮眼页的「轮回眼立绘」必须是**根下那张 TextureRect**，不是阶段列表里那枚同名**按钮**
		#    （§3.114：原来用 `find_child("轮回眼")`，取的是树序第一枚 —— 现在恰好对，
		#     但场景里两块换个先后就会静默取到按钮、`as TextureRect` 变 null、立绘整段失效）。
		if 名 == "写轮眼":
			var 立绘 = 页.get("轮回眼立绘")
			if 立绘 == null:
				_失败.append("写轮眼页的 `轮回眼立绘` 取不到（脚本没挂上？）")
			elif not (立绘 is TextureRect) or (立绘 as Node).get_parent() != 页:
				_失败.append("`轮回眼立绘` 应指向**页面根下**那张 TextureRect「轮回眼」，实际指向 %s（%s）"
					% [(立绘 as Node).get_path() if 立绘 is Node else 立绘,
						(立绘 as Node).get_class() if 立绘 is Node else "非节点"])

		# ②c 柔拳**没突破的境界**要灰：原版 `RouQuanPanel.as:464-480 updateButtonState()`
		#   `按钮下标 < _stage` ⇒ 亮，其余套 `StyleUtil.getGrayFilter()`。本行灌的是 5 阶
		#   ⇒ 阶段1..5 亮、阶段6..8 灰；灰钮**仍然能点**（原版只是滤镜，不置 disabled）。
		#   另外钉两条边界：服务端 0 阶按原版 `:327-328` 当 1 阶；8 阶全亮。
		if 名 == "柔拳":
			var 柔拳脚本 := load("res://脚本/界面/窗口/人物窗口.gd")
			var 柔拳区 := 页.get_node_or_null("阵法面板/阶段图标切换区") as Control
			if 柔拳区 == null:
				_失败.append("柔拳页找不到「阵法面板/阶段图标切换区」，灰化无从验起")
			else:
				for 柔拳序 in range(1, 9):
					var 柔拳钮 := 柔拳区.get_node_or_null("阶段%d" % 柔拳序) as TextureButton
					if 柔拳钮 == null:
						_失败.append("柔拳页找不到「阶段%d」钮" % 柔拳序)
						continue
					var 期望解锁 := 柔拳序 <= 5
					if bool(柔拳钮.get("是否解锁")) != 期望解锁:
						_失败.append("柔拳 5 阶时「阶段%d」是否解锁=%s（期望 %s）"
							% [柔拳序, str(柔拳钮.get("是否解锁")), str(期望解锁)])
					if 期望解锁:
						if 柔拳钮.material != null:
							_失败.append("柔拳 5 阶时「阶段%d」已突破，不该套灰度材质" % 柔拳序)
					else:
						var 柔拳材 := 柔拳钮.material as ShaderMaterial
						if 柔拳材 == null:
							_失败.append("柔拳 5 阶时「阶段%d」未突破，却没套灰度材质" % 柔拳序)
						elif 柔拳材.shader == null \
								or 柔拳材.shader.resource_path.get_file() != "禁用灰度.gdshader":
							_失败.append("柔拳「阶段%d」的灰度着色器不是逐字照抄的禁用灰度（实际 %s）"
								% [柔拳序, 柔拳材.shader.resource_path if 柔拳材.shader != null else "无"])
						if 柔拳钮.disabled:
							_失败.append("柔拳「阶段%d」未突破就被 disabled 了 —— 原版只灰、仍能点开看" % 柔拳序)
				# 灰钮仍能翻页：点阶段6 → 页面进第6阶（属性条照样能给"看未突破阶"画 0）
				var 灰钮 := 柔拳区.get_node_or_null("阶段6") as TextureButton
				if 灰钮 != null:
					灰钮.pressed.emit()
					if int(页.get("当前阶段")) != 6:
						_失败.append("点灰掉的「阶段6」没翻到第 6 阶（当前 %s）" % str(页.get("当前阶段")))
				柔拳脚本.切柔拳阶段(页, 5)		# 无论对错都还原，别把后面的腿带到 6 阶
				# 边界 0 阶 ⇒ 原版按 1 阶处理；8 阶 ⇒ 全亮
				柔拳脚本.柔拳阶段解锁(页, 0)
				if not bool((柔拳区.get_node("阶段1") as TextureButton).get("是否解锁")):
					_失败.append("柔拳阶段解锁(0) 没按原版当 1 阶处理（阶段1 应该亮）")
				if bool((柔拳区.get_node("阶段2") as TextureButton).get("是否解锁")):
					_失败.append("柔拳阶段解锁(0) 后阶段2仍是亮的（0 阶只到第 1 阶）")
				柔拳脚本.柔拳阶段解锁(页, 8)
				for 验序 in range(1, 9):
					var 满阶钮 := 柔拳区.get_node_or_null("阶段%d" % 验序) as TextureButton
					if 满阶钮 != null and (not bool(满阶钮.get("是否解锁")) or 满阶钮.material != null):
						_失败.append("柔拳阶段解锁(8) 后「阶段%d」仍灰着（8 阶该全亮）" % 验序)
				柔拳脚本.柔拳阶段解锁(页, 5)		# 还原给后面几条腿用

			# ②d 右列标题不许压到同一行的属性条上（2026-10-25 用户报「文字跟属性值重叠，应该往左一点」）。
			#   原版 `RouQuanPanel.as:195-213` 这 5 根是 `createBar(名字, 90)` ⇒ `MBar.setLabelWidth(90)`
			#   把 mLabel 摆成 [2,92]、barBg 从 90 起（`MBar.as:184-199`），标题框右沿只到条子左沿 +2，
			#   且文本是**居中**（symbol 里 EditText 166 align=2）；修前 Godot 是 49px 左对齐，
			#   「攻 击 速 度」66px、「手里剑触发几率」84px 都从 227/205 一路画进条子。
			#   这里按 Godot 实际字体度量算**墨迹右沿**，不许越过条子左沿。
			var 柔拳数值区 := 页.get_node_or_null("阵法面板/数值，阶段名称切换区") as Control
			if 柔拳数值区 == null:
				_失败.append("柔拳页找不到「阵法面板/数值，阶段名称切换区」")
			else:
				for 阶段名 in ["第五阶段", "第六阶段", "第七阶段", "第八阶段"]:
					var 阶段节点 := 柔拳数值区.get_node_or_null(阶段名) as Control
					if 阶段节点 == null:
						_失败.append("柔拳页缺少「%s」" % 阶段名)
						continue
					for 标题 in 阶段节点.get_children():
						if not (标题 is Label) or not String(标题.name).ends_with("标题"):
							continue
						var 条 := 阶段节点.get_node_or_null(String(标题.name).trim_suffix("标题")) as Control
						if 条 == null:
							continue
						var 字: Font = (标题 as Label).get_theme_font("font")
						if 字 == null:
							_失败.append("柔拳%s「%s」取不到主题字体" % [阶段名, String(标题.name)])
							continue
						var 号 := (标题 as Label).get_theme_font_size("font_size")
						var 宽 := 字.get_string_size((标题 as Label).text, HORIZONTAL_ALIGNMENT_LEFT, -1, 号).x
						var 框宽 := (标题 as Control).offset_right - (标题 as Control).offset_left
						var 绘左: float
						match (标题 as Label).horizontal_alignment:
							HORIZONTAL_ALIGNMENT_CENTER:
								绘左 = (标题 as Control).offset_left + (框宽 - 宽) * 0.5
							HORIZONTAL_ALIGNMENT_RIGHT:
								绘左 = (标题 as Control).offset_right - 宽
							_:
								绘左 = (标题 as Control).offset_left
						var 最小宽 := (标题 as Control).get_combined_minimum_size().x
						if 框宽 + 0.5 < 最小宽:
							_失败.append("柔拳%s「%s」标题框 %.0fpx 窄于文字最小 %.0fpx ⇒ 运行时会被撑宽压进属性条"
								% [阶段名, String(标题.name), 框宽, 最小宽])
						if 绘左 + 宽 > 条.offset_left:
							_失败.append("柔拳%s「%s」墨迹画到 %.1f，压进了属性条（条左 %.0f）"
								% [阶段名, String(标题.name), 绘左 + 宽, 条.offset_left])

		# ②e 写轮眼页右列标题也不许压属性条（2026-10-25 用户报「血继界限写轮眼也是右列标题压属性条」）。
		#   本页右列照的是原版截图 `.scratch/写轮眼_描述放大.png`：五个标题**右沿对齐**
		#   （图里「反弹伤害」「伤害免疫」两行右端齐、条子在右），条子左沿 278。
		#   场景里「手里剑触发几率 / 反弹伤害 / 伤害免疫」本来就是 RIGHT，
		#   「攻击速度 / 移动速度」漏成 LEFT ⇒「攻 击 速 度」从 221 一路画进 278 的条子。
		#   这里按 Godot 实际字体墨迹算右沿，必须落在条子左沿之内；并钉住右列五组的条数，
		#   别让节点改名后这条腿空转变绿。
		#   ⚠ §3.295 续（2026-10-26 用户「攻击速度、移动速度标题还是跟数值轴重叠」）：
		#   改成 RIGHT 后仍压 —— 真因不是对齐，是 **Godot 的 Control 撑不到最小尺寸以下**。
		#   「攻 击 速 度」框 49px、文字 66px，运行时 offset_left 不动、右沿被撑到 287（条左 278）。
		#   修法：右列 34 个标题框统一放宽成 [180,270]（右沿/对齐不动），另加"框窄于文字"硬断言 ——
		#   这条断言能把 §3.268 那种"只量 offset_right"的假绿逮出来。
		if 名 == "写轮眼":
			var 写轮眼区 := 页.get_node_or_null("属性面板/阶段，数值名称切换区") as Control
			if 写轮眼区 == null:
				_失败.append("写轮眼页找不到「属性面板/阶段，数值名称切换区」")
			else:
				var 右列应有 := {"攻击速度": 8, "移动速度": 8, "手里剑触发几率": 7, "反弹伤害": 6, "伤害免疫": 5}
				var 右列实有 := {}
				var 标题总数 := 0
				for 阶段节点 in 写轮眼区.get_children():
					if not (阶段节点 is Control):
						continue
					for 标题 in 阶段节点.get_children():
						if not (标题 is Label) or not String(标题.name).ends_with("标题"):
							continue
						var 条 := (阶段节点 as Control).get_node_or_null(String(标题.name).trim_suffix("标题")) as Control
						标题总数 += 1
						if 条 == null:
							continue
						var 字: Font = (标题 as Label).get_theme_font("font")
						if 字 == null:
							_失败.append("写轮眼%s「%s」取不到主题字体"
								% [String(阶段节点.name), String(标题.name)])
							continue
						var 号 := (标题 as Label).get_theme_font_size("font_size")
						var 宽 := 字.get_string_size((标题 as Label).text, HORIZONTAL_ALIGNMENT_LEFT, -1, 号).x
						var 框宽 := (标题 as Control).offset_right - (标题 as Control).offset_left
						var 绘左: float
						match (标题 as Label).horizontal_alignment:
							HORIZONTAL_ALIGNMENT_CENTER:
								绘左 = (标题 as Control).offset_left + (框宽 - 宽) * 0.5
							HORIZONTAL_ALIGNMENT_RIGHT:
								绘左 = (标题 as Control).offset_right - 宽
							_:
								绘左 = (标题 as Control).offset_left
						if 绘左 + 宽 > 条.offset_left:
							_失败.append("写轮眼%s「%s」墨迹画到 %.1f，压进了属性条（条左 %.0f）"
								% [String(阶段节点.name), String(标题.name), 绘左 + 宽, 条.offset_left])
						var 最小宽 := (标题 as Control).get_combined_minimum_size().x
						if 框宽 + 0.5 < 最小宽:
							_失败.append("写轮眼%s「%s」标题框 %.0fpx 窄于文字最小 %.0fpx ⇒ 运行时会被撑宽压进属性条"
								% [String(阶段节点.name), String(标题.name), 框宽, 最小宽])
						var 列名 := String(标题.name).trim_suffix("标题")
						if 右列应有.has(列名):
							右列实有[列名] = int(右列实有.get(列名, 0)) + 1
				for 列名 in 右列应有:
					if int(右列实有.get(列名, 0)) != int(右列应有[列名]):
						_失败.append("写轮眼右列「%s」只扫到 %d 行（期望 %d）—— 这条腿扫漏了"
							% [列名, int(右列实有.get(列名, 0)), int(右列应有[列名])])
				if 标题总数 < 80:
					_失败.append("写轮眼页只扫到 %d 个带同名条的标题（期望 ≥80，12 阶 × 左四 + 右列 34）" % 标题总数)

		# ②f/②g/②h 轮回六道页三条（2026-10-26 用户四项报修）：
		#   ②f 箭头 = `LunHuiYanPanel.as:201-220` 的 ProgramButton **只铺 upSkin**：
		#      悬停不许冒出主题那张九宫格大图案（§3.295 同款"stylebox 撑控件"病根），
		#      右箭头不许"底图一张 + icon 又一张"叠成两个（修前 normal stylebox 就是箭头本身）。
		#   ②g 未提升的道 = `setImageFilters:314-333`：阶段号 > currIndex 套 getGrayFilter；
		#      正在看的**再叠**红辉光 ⇒ 翻看未达成阶段 = 灰 + 红边同时。
		#   ②h 技能格提示 = `SkillCell.as:191-228` 每次 ROLL_OVER 现建 `MToolTipLunHuiYanSkill`。
		#   ②i 未学技能格 **图标**灰 = `LunHuiYanPanel.as:650-655`（getDisableFilter，只灰 icon）。
		if 名 == "轮回六道":
			# ── ②f 箭头 ──
			var 箭头坏 := false
			for 钮名 in ["上一页", "下一页"]:
				var 钮 := 页.get_node_or_null(钮名) as TextureButton
				if 钮 == null:
					_失败.append("轮回六道「%s」不是 TextureButton（修前是 Button+theme stylebox，悬停出巨大图案）" % 钮名)
					箭头坏 = true
					continue
				if 钮.texture_normal == null:
					_失败.append("轮回六道「%s」texture_normal 丢了（原版只铺 upSkin）" % 钮名)
				if 钮.texture_hover != null:
					_失败.append("轮回六道「%s」多了 hover 贴图（原版没有 over 皮）" % 钮名)
				if 钮.has_theme_stylebox_override("normal"):
					# 不查 `icon`：TextureButton 根本没有这个属性（`Button` 才有）⇒ 查了永远是 null、
					# 是条假绿；修前"多一枚箭头"的真身（icon + 把箭头当 stylebox 底）都被**类型**这一条逮住。
					_失败.append("轮回六道「%s」仍带 theme_override_styles/normal（把箭头贴图塞 stylebox 就是「多余箭头」的病根）" % 钮名)
			if not 箭头坏:
				# 点箭头仍要翻页（转 TextureButton 后 pressed 接线没断）
				var 右钮 := 页.get_node_or_null("下一页") as TextureButton
				右钮.pressed.emit()
				if int(页.get("current_index")) != 4:
					_失败.append("点「下一页」后 current_index=%s（期望 4）" % str(页.get("current_index")))
				var 左钮 := 页.get_node_or_null("上一页") as TextureButton
				左钮.pressed.emit()
				左钮.pressed.emit()
				if int(页.get("current_index")) != 2:
					_失败.append("连点两下「上一页」后 current_index=%s（期望 2）" % str(页.get("current_index")))
				页.set("current_index", 3)
				页.call("_update_ui")
			# ── g 灰显（会话灌的是 4 阶）──
			# 阶段号查 `LunHuiYanPanel.onComplete:404-411` 的原版后缀表：
			#   [六道开启(Bg_8)=8, 天道=2, 畜生=3, 人间=4, 修罗=5, 饿鬼=6, 地狱=7, 外道(WaiDao_9)=9]
			# ⇒ 4 阶时**连背景都灰**（8>4，修前用 i+1 永远不灰），外道 9>4 灰；
			#   红边条件 `后缀 == 在看阶段号`（setImageFilters:321-327）⇒ 看 1 阶没有一块匹配（不发光）、
			#   看 8 阶红边落背景、外道永远不吃红边。全达成特例：Bg `createLunHuiYanBtn:475-477`、
			#   外道 `setImageFilters:328-331`。
			if int(页.get("real_stage")) != 4:
				_失败.append("real_stage=%s（服务端 stage=4 应推成 4；不推 ⇒ 永远全亮，就是用户报的第 4 条）" % str(页.get("real_stage")))
			var 描边材 = 页.get("red_outline_material")
			var 壁画组: Array = 页.get("stage_sprites")
			var 阶表 := [8, 2, 3, 4, 5, 6, 7, 9]
			for 序 in 壁画组.size():
				var 画: TextureRect = 壁画组[序]
				var 未达成: bool = 阶表[序] > 4
				var 在看: bool = 阶表[序] == 4
				var 材 := 画.material as ShaderMaterial
				if not 未达成 and not 在看:
					if 材 != null:
						_失败.append("轮回「%s」已达成又没在看，却套了材质（应无滤镜）" % String(画.name))
				elif 在看:
					if 材 == null:
						_失败.append("轮回「%s」正在看，却没套红边" % String(画.name))
					elif 材 != 描边材:
						_失败.append("轮回「%s」正在看且已达成，红边却不是共享的 red_outline_material" % String(画.name))
					elif _灰量(材) > 0.0:
						_失败.append("轮回「%s」已达成，红边材质的 gray_amount 却不是 0" % String(画.name))
				else:
					if 材 == null:
						_失败.append("轮回「%s」未提升却没灰（原版 getGrayFilter，用户报的第 4 条）" % String(画.name))
					elif 材.shader == null or 材.shader.resource_path.get_file() != "禁用灰度.gdshader":
						_失败.append("轮回「%s」的灰材质不是逐字照抄矩阵的禁用灰度（实际 %s）"
							% [String(画.name), 材.shader.resource_path if 材.shader != null else "无"])
			# 看「外道」(current_index=7 ⇒ 在看阶段号 8)：红边在**背景**（Bg_8）上且它没达成 ⇒ 灰+红边同叠；
			# 「外道」壁画（WaiDao_9）自己只灰不发光 —— 修前（阶段号=9→8、i+1）两处都反着。
			页.set("current_index", 7)
			页.call("_update_ui")
			var 翻看材 := (壁画组[0] as TextureRect).material as ShaderMaterial
			if 翻看材 == null or 翻看材.shader == null \
					or 翻看材.shader.resource_path.get_file() != "红色描边.gdshader" \
					or not is_equal_approx(_灰量(翻看材), 1.0):
				_失败.append("看「外道」时背景壁画（Bg_8，未达成）应是 灰+红边（红色描边.gdshader gray_amount=1），实际 %s"
					% (str(翻看材) if 翻看材 != null else "无材质"))
			var 外道材 := (壁画组[7] as TextureRect).material as ShaderMaterial
			if 外道材 == null or 外道材.shader == null \
					or 外道材.shader.resource_path.get_file() != "禁用灰度.gdshader":
				_失败.append("看「外道」时 WaiDao_9 壁画应只灰不发光（原版没有后缀 9 会等于在看阶段号），实际 %s"
					% (str(外道材) if 外道材 != null else "无材质"))
			# 8 阶全达成 ⇒ 一律不灰（背景/外道两个特例），且看 8 阶时背景带**纯红边**（无灰）
			var 旧真阶 := int(页.get("real_stage"))
			页.set("real_stage", 8)
			页.call("_update_ui")
			if (壁画组[6] as TextureRect).material != null:
				_失败.append("real_stage=8 时「地狱道」壁画仍带材质（全达成应不灰）")
			if (壁画组[7] as TextureRect).material != null:
				_失败.append("real_stage=8 时「外道」壁画仍带材质（setImageFilters:328-331 特例应取消灰）")
			var 全成材 := (壁画组[0] as TextureRect).material as ShaderMaterial
			if 全成材 != 描边材 or _灰量(全成材) > 0.0:
				_失败.append("real_stage=8 且看「外道」时背景应是共享红边（gray_amount=0），实际 %s" % str(全成材))
			页.set("real_stage", 旧真阶)
			页.set("current_index", 3)
			页.call("_update_ui")
			# ── ②h 技能格悬停提示 ──
			# 先切走再切回：换子页会重建 `_content`、宿主全新一批，而框常驻 `遮罩` 层 ——
			# 这一腿钉的是"接线守卫打在**宿主信号已有连线**上（is_connected）"：守卫若退回
			# 框的"新建"标志，切回来的新宿主没接线，悬停永远不出框（2026-10-26 R3 反向实测红 58）。
			窗.call("_set_character_sub_tab", 0)
			for _序号 in 3:
				await process_frame
			窗.call("_set_character_sub_tab", 1)
			for _序号 in 3:
				await process_frame
			页 = _取页(窗, 名)
			# 在**同一批**宿主上再跑一遍 `初始化轮回六道页` —— 这就是修炼结果帧在真系统里落的同宿主路：
			# `人物窗口.原地刷新族页`（:991，只重跑那一族的 `初始化X页`，不重建页面、不碰弹窗）。
			# 守卫若退化（裸 connect / 拿框的"新建"当标志），这一腿会叠第二根线或刷 already-connected。
			# ⚠️ 2026-10-26 探针实测：`窗.call("_render_character")` = 直接 `人物窗口.渲染`，**不清旧树**
			# （清树在 `_render_page:1419-1422` 的 remove_child+queue_free），会叠出第二棵
			# `原版人物窗口内容`（`@Control@529`），旧宿主根本没被重初始化 ⇒ 那一版这条腿"再渲染"
			# 是名不副实的（假绿#19 同族：判据没作用在目标上）。别 `窗.call("渲染")` 也是老教训
			# （static func 不进 Object 方法表，`Nonexistent function` 无判定挂死，假绿#16）。
			var 人物脚本 := load("res://脚本/界面/窗口/人物窗口.gd")
			if not bool(人物脚本.原地刷新族页(窗, "轮回六道")):
				_失败.append("「原地刷新族页」返回 false：轮回六道页开着却没原地重初始化 —— 本腿没验到同宿主复跑")
			for _序号 in 2:
				await process_frame
			var 格区 := 页.get_node_or_null("属性面板/技能格区") as Control
			if 格区 == null:
				_失败.append("轮回六道页找不到「属性面板/技能格区」")
			else:
				# 2026-10-26 用户报修「提示框只显示在轮回六道面板里，下面的信息完全看不到」：
				# 秘术子页整体挂在 `人物扩展页`（Panel，clip_contents=true）里，框挂页面根下
				# 越出面板的下半截被裁整刀。原版 `MToolTip.showTip:98-103` 挂
				# `PopUpMananger.stage`（= flash.display.Stage，整屏顶层弹层，`setLocation`
				# 钳 STAGE 从不钳面板）⇒ 框必须挂窗口 `遮罩` 层，且**祖先链不许有任何裁层**。
				var 层 := 窗.get_node_or_null("遮罩") as Control
				if 层 == null:
					_失败.append("窗口下找不到 `遮罩` 层（原版 PopUpMananger.stage 的等价物）")
					continue
				var 提示数 := 0
				for 子 in 层.get_children():
					if String(子.name).begins_with("轮回技能提示_"):
						提示数 += 1
				if 提示数 != 5:
					_失败.append("遮罩层上的轮回技能提示框应有 5 枚（五格），扫到 %d 枚" % 提示数)
				if 页.get_node_or_null("轮回技能提示_空技能格") != null:
					_失败.append("空技能格挂上了提示 —— 原版那两格没 value、不挂（LunHuiYanPanel.as:628-660）")
				for 子 in 页.get_children():
					if String(子.name).begins_with("轮回技能提示_"):
						_失败.append("提示框仍挂在页面根下 —— 页面在 `人物扩展页`(clip_contents) 里，下半截会被裁（改挂遮罩层，§3.298）")
						break
				for 格名 in ["轮回·灵魂吞噬", "轮回·阿修罗形态", "轮回·吞噬", "轮回·判决", "轮回·万象天引"]:
					var 宿主 := 格区.get_node_or_null(格名) as Control
					var 框 := 层.get_node_or_null("轮回技能提示_" + 格名) as Control
					if 宿主 == null or 框 == null:
						_失败.append("轮回技能格「%s」或它的提示框取不到" % 格名)
						continue
					if 框.get_parent() != 层:
						_失败.append("「%s」提示框的父层不是 `遮罩`（实际 %s）" % [格名, String(框.get_parent().name)])
					elif _链上有裁(框):
						_失败.append("「%s」提示框祖先链上有 clip_contents=true 的层 ⇒ 会被裁（原版挂整屏 stage，从不钳面板）" % 格名)
					# 接线**恰好一根**：0 根 = 重建后新宿主没接上（R3 反向实测悬停全空，红 58）。
					# ⚠️ 2 根这判据**天然抓不到** —— Godot 的 `connect` 自己拒重复连线（R4 反向实测
					# 计数恒 1、但日志刷出 30 条 `already connected ... 'GDScript::显轮回技能提示'`）。
					# 所以"守卫没退化"跑在门外的固定一查：**本门日志里那条 callable 的
					# already connected 必须 = 0**（跑批器 `grep -c` 同 SCRIPT ERROR 一条规格）。
					var 线数 := 0
					for 连 in 宿主.mouse_entered.get_connections():
						var 合: Callable = 连["callable"]
						if String(合.get_method()) == "显轮回技能提示":
							线数 += 1
					if 线数 != 1:
						_失败.append("「%s」悬停接线 %d 根（应恰好 1；is_connected 守卫失效，重复渲染叠线）" % [格名, 线数])
					if 宿主.mouse_filter != Control.MOUSE_FILTER_PASS:
						_失败.append("「%s」mouse_filter 不是 PASS ⇒ 悬停事件进不来" % 格名)
					if String(宿主.tooltip_text) != "":
						_失败.append("「%s」还留着原生 tooltip_text（应让位给原版提示框）" % 格名)
					if 框.visible:
						_失败.append("「%s」提示框没悬停就常亮" % 格名)
					宿主.mouse_entered.emit()
					var 文 := String(框.get_node("文").get_parsed_text())
					var 题 := String(框.get_node("标题").text)
					var 原 := String(框.get_node("文").text)
					宿主.mouse_exited.emit()
					if not 框.get_node("标题").text.contains("ffff00") or not 框.get_node("标题").text.contains("[center]"):
						_失败.append("「%s」提示标题不是原版居中大黄字（#ffff00，MToolTipLunHuiYanSkill:120-127）" % 格名)
					for 钉 in ["描述资讯", "学习条件：", "秘笈需求：《", "击杀野外Boss有几率获得轮回秘笈",
							"【轮回六道突破", "后通过秘笈书学习】", "技能效果：", "【尚未学会】"]:
						if not 文.contains(钉):
							_失败.append("「%s」未学提示缺原文一段：%s" % [格名, 钉])
					var 原小 := 原.to_lower()	# `富文本._规范颜色` 会把 #FF9203 规范成小写
					if not 原小.contains("ff0000") or not 原小.contains("ff9203"):
						_失败.append("「%s」提示没带原版色号（红【尚未学会】/ 橙说明段）" % 格名)
					if 格名 == "轮回·灵魂吞噬" and not 文.contains("人间道"):
						_失败.append("「轮回·灵魂吞噬」提示没写突破「人间道」（2020↔jieDuanName[3]，MToolTipLunHuiYanSkill:161-168）")
					# 主动/被动 = `数据/技能.json` 的 skill_type（照原版 `SkillDataTool.getSkillType`：
					# 2020/2021 主动、2022/2023/2024 被动）。
					if (格名 == "轮回·灵魂吞噬" or 格名 == "轮回·阿修罗形态") != 文.contains("【主动技能】"):
						_失败.append("「%s」主动/被动标记不对（应%s）" % [格名,
							"【主动技能】" if (格名 == "轮回·灵魂吞噬" or 格名 == "轮回·阿修罗形态") else "被动加成，无需使用"])
					if 格名 == "轮回·万象天引" and not 文.contains("被动加成，无需使用"):
						_失败.append("「轮回·万象天引」该是被动（2024 skill_type=1，SKILL_TOOLTIP_PASSIVIZE）")
					# ②i 未学 ⇒ 图标灰（用户报修 2026-10-26；原版 `LunHuiYanPanel.as:650-655`
					# 未学 `_loc4_.icon.filters = Style.getDisableFilter()`，矩阵 `Style.as:63-67`
					# = 0.3086/0.6094/0.082 与 ②g 道按钮那颗 `禁用灰度.gdshader` 逐系数相同）。
					# 默认会话五格全未学 ⇒ 每格图标都必须挂着那颗 shader 的材质。
					var 灰图 := _格图标(宿主)
					var 灰材 := (灰图.material as ShaderMaterial) if 灰图 != null else null
					if 灰图 == null:
						_失败.append("「%s」技能格扫不到图标 TextureRect（灰没有落点）" % 格名)
					elif 灰材 == null or 灰材.shader == null \
							or 灰材.shader.resource_path.get_file() != "禁用灰度.gdshader":
						_失败.append("未学「%s」图标没套禁用灰度（原版 icon.filters=getDisableFilter，用户报的「未学习应该灰色」）" % 格名)
				# 学会之后：绿行 = 冷却/消耗（`formatLunHuiSkillInfo:52-57`），不再有【尚未学会】；
				# ②i 灰也要**跟着回帧走** —— 原版 `updateSkillData:603-609 → updateInfo` 现算重铺，
				# 移植侧同宿主那一条 = `原地刷新族页 → 初始化轮回六道页 → 接轮回技能提示`（真
				# `skills_changed` 帧走 `_refresh_current` 整页重烘，跑的也是同一段初始化）。
				# 原地刷新**不重建树**，格区/宿主引用继续有效 —— 别改回 `_render_character`（见上面 ②h 的探针注）。
				会话.learned_skills.append({"id": "0002020", "level": 1, "master_level": 0})
				if not bool(人物脚本.原地刷新族页(窗, "轮回六道")):
					_失败.append("已学腿：「原地刷新族页」返回 false，灰没机会跟着已学集重算")
				var 吞格 := 格区.get_node_or_null("轮回·灵魂吞噬") as Control
				var 吞文 := ""
				if 吞格 != null:
					吞格.mouse_entered.emit()
					var 吞框 := 层.get_node_or_null("轮回技能提示_轮回·灵魂吞噬") as Control
					if 吞框 != null:
						吞文 = String(吞框.get_node("文").get_parsed_text())
						吞框.get_node("文").text = ""		# 不管对错都拆掉，别把"已学"文案漏给下面的腿
						吞框.visible = false
					# ②i 已学腿的灰：重烘 = 原版 `updateSkillData:603-609 → updateInfo` 重建格。
					# 学会 2020 后**这格**图标该摘灰；同区仍未学的「万象天引」(2024) **不许跟着亮**
					# —— 灰显逐格跟已学集，不是一刀切。
					var 吞图 := _格图标(吞格)
					if 吞图 == null:
						_失败.append("已学腿：重烘后的「轮回·灵魂吞噬」扫不到图标")
					elif 吞图.material != null:
						_失败.append("已学「灵魂吞噬」图标还灰着（原版 isStudied 不加 getDisableFilter，学会要显式清回 null）")
					var 判格 := 格区.get_node_or_null("轮回·万象天引") as Control
					var 判图 := _格图标(判格)
					if 判图 == null or 判图.material == null:
						_失败.append("学会 2020 后仍未学的「轮回·万象天引」图标不该跟着摘灰 —— 灰显要逐格跟已学集")
				会话.learned_skills.pop_back()		# pop 挪出 `if`：吞格取不到也不能把灌进去的 0002020 漏给后面的腿（假绿#10）
				for 钉 in ["冷却时间：", "10分0.00秒", "消耗查克拉：", "11"]:
					if not 吞文.contains(钉):
						_失败.append("已学「灵魂吞噬」提示缺 %s（cooldown=600 ⇒ seconds2DayHourMinute\"10分0.00秒\"、mpCost=11）" % 钉)
				if 吞文.contains("【尚未学会】"):
					_失败.append("已学「灵魂吞噬」还显示【尚未学会】")

		# ③b 八门页的「开通穴道弹窗」必须是**藏着的**、而且关闭按钮接着线。
		# 守的是 2026-09-24 那个 bug：`八门页.tscn` 里那个实例被写成 `script = null`，
		# 于是它自己 `_ready()` 里的「起始隐藏 + 接关闭按钮」两条全都不执行 ——
		# 表现是**一进八门页弹窗就常亮、还关不掉**（用户报的「贯通穴位面板一直关不掉」）。
		if 名 == "八门":
			var 穴道 := 页.get_node_or_null("开通穴道弹窗") as Control
			if 穴道 == null:
				_失败.append("八门页找不到「开通穴道弹窗」")
			else:
				if 穴道.get_script() == null:
					_失败.append("八门页的「开通穴道弹窗」脚本被摘掉了（script = null？）")
				if 穴道.visible:
					_失败.append("八门页的「开通穴道弹窗」进页面就亮着（应该藏着）")
				var 关 := 穴道.get_node_or_null("关闭按钮") as Button
				if 关 == null or 关.pressed.get_connections().is_empty():
					_失败.append("八门页的「开通穴道弹窗」关闭按钮没接线（点了关不掉）")

			# ③c 八门「开通穴道」那条链（§3.162）。真值 = 原版 `ChongMaiWindow.as:272`
			#   `requestMaiExplode(maiId, pointId, 勾选 ? 下拉.selectedIndex+1 : 0)`；
			#   其中 `pointId` = **配置键序**（`pts` 的 "0".."N"）—— 原版 `for each` 枚举数值键是升序，
			#   所以**实机原版开门第一枚＝头维**（`pts["0"]`）。
			#   ⚠️ 2026-10-17 更正：这里原来写的是"Ruffle 哈希序（第 0 枚＝攒竹）"，用户实机打回。
			#   已由 `开发工具/导出八门点序.py` 导进 `数据/经脉.json._客户端点序`（现＝配置键序），
			#   **不是**配置里的键序 —— 这里先钉住这条映射，再钉按钮真发什么。
			var 人物脚本 := load("res://脚本/界面/窗口/人物窗口.gd")
			if 人物脚本.八门穴位下标("开门", "头维") != 0:
				_失败.append("客户端点序表不对：开门第 0 枚该是「头维」（配置键序 pts[0]），实测下标 %s（点序表没导？）"
					% str(人物脚本.八门穴位下标("开门", "头维")))
			var 穴位层 := 页.get_node_or_null("穴位面板/穴位图/穴位点层_开门") as Control
			var 首点 := (穴位层.get_node_or_null("点_头维") if 穴位层 != null else null) as Control
			if 首点 == null:
				_失败.append("开门那一层里找不到「点_头维」（点位名跟配置/点序表对不上？）")
			else:
				var 假八 := 假后端.new()
				窗.set("_backend", 假八)
				首点.emit_signal("点击", 首点.name)
				await process_frame
				var 弹 := 页.get_node_or_null("开通穴道弹窗") as Control
				var 确 := (弹.get_node_or_null("开通穴道按钮") if 弹 != null else null) as Button
				if 确 == null or 确.pressed.get_connections().is_empty():
					_失败.append("「开通穴道按钮」没接线（点了不会发协议）")
				else:
					确.pressed.emit()
					await process_frame
					if 假八.八门.size() != 1 or 假八.八门[0] != [2, 0, 0, 0]:
						_失败.append("点开门第 0 枚穴位后按「开通穴道」该发 MAI 动作 2 + (门0, 穴位0, 铜人0)，实测 %s（状态行「%s」、meta=%s）"
							% [str(假八.八门), String(窗.get("_status").text), str(页.has_meta("八门选中"))])
					var 勾 := 弹.get_node_or_null("使用八门灵符") as CheckBox
					var 下 := 弹.get_node_or_null("数量下拉") as OptionButton
					if 勾 != null and 下 != null:
						勾.button_pressed = true
						下.selected = 2			# 下拉项文字 = 1..9 ⇒ 选第 3 项 = 用 3 个铜人
						确.pressed.emit()
						await process_frame
						if 假八.八门.size() != 2 or 假八.八门[1] != [2, 0, 0, 3]:
							_失败.append("勾了八门灵符 + 下拉第 3 项 ⇒ 铜人数该是 3，实测 %s" % str(假八.八门))
				# ③d 灵符格那枚「购买」：原版 `ItemCaiLiaoBox.buyHandler:45-54` 只派发
				#   `REQUEST_CASH_ITEM_INFO(id)`（问商城要条目，回 1079 才弹购买窗）；
				#   本工程统一出口 = `功能窗口.请求商城商品` ⇒ 1086 只带物品 id。
				#   ⚠️ 不置灰（`hasItem:56-62` 只灰图标）、`itemData` 空才 no-op ⇒ 这里只要接线+号对。
				if 弹 != null:
					var 购 := 弹.get_node_or_null("购买") as Button
					if 购 == null:
						_失败.append("八门开通弹窗里没有「购买」钮（灵符格那枚 ItemCaiLiaoBox 的）")
					elif 购.disabled:
						_失败.append("八门开通弹窗的「购买」被置灰（原版只灰图标，这枚钮一直可点）")
					elif 购.pressed.get_connections().is_empty():
						_失败.append("八门开通弹窗的「购买」没接线（点了不发 1086）")
					else:
						var 灵符号 := int((_经脉表().get("info", {}) as Dictionary).get("itemid", 0))
						假八.商城.clear()
						购.pressed.emit()
						await process_frame
						if 灵符号 <= 0:
							_失败.append("经脉表 info.itemid 读不到 ⇒「购买」那条没法量（表坏了？）")
						elif 假八.商城 != [灵符号]:
							_失败.append("八门「购买」该发 1086(%d)（经脉 info.itemid），实发 %s"
								% [灵符号, str(假八.商城)])
				窗.set("_backend", null)
				# 点亮：统计帧说开门已开 2 枚 ⇒ 点序**前两枚**亮、第三枚不亮
				会话.cultivation_states["八门"] = {"list_id": 0, "exploded": {0: 2}}
				窗.call("_refresh_current")
				for _序号2 in 4:
					await process_frame
				var 页2 := _取页(窗, "八门")		# ⚠️ 重建后旧引用全失效，重新取
				var 层2 := (页2.get_node_or_null("穴位面板/穴位图/穴位点层_开门") if 页2 != null else null) as Control
				if 层2 == null:
					_失败.append("重建后取不到开门穴位层 ⇒ 点亮那一腿没量到")
				else:
					var 亮 := []
					for 名2 in ["头维", "发际", "阴白"]:		# 点序前三枚（开门，配置键序）
						var 点2 := 层2.get_node_or_null("点_%s" % 名2)
						亮.append(bool(点2.get("已开启")) if 点2 != null else false)
					if 亮 != [true, true, false]:
						_失败.append("已开 2 枚 ⇒ 开门点序前两枚该亮、第三枚不亮，实测 %s" % str(亮))

			# ③e 「开通失败回帧不该被弹回总览」（2026-10-20 报修 #2.3）。
			#   原版 tabBar 是**常驻对象**，数据回包不会把玩家从正在看的那扇门弹回主页
			#   （`JingMaiPanel.initView:358` 只在初始化时选 0）。我们的页面每次回帧重建 ⇒
			#   选中门记在窗口上（`_八门选中门`），重建时按它复原。
			var 页3 := _取页(窗, "八门")
			var 门钮 := (页3.get_node_or_null("门列表/按钮列/开门") if 页3 != null else null) as Button
			if 门钮 == null:
				_失败.append("③e 取不到「开门」门按钮")
			else:
				门钮.pressed.emit()
				await process_frame
				if str(窗.get("_八门选中门")) != "开门":
					_失败.append("③e 点「开门」后窗口应记住选中门，实测「%s」" % str(窗.get("_八门选中门")))
				# 模拟开通失败的结果帧：`cultivation_changed` ⇒ `功能窗口` 整页重建
				窗.call("_refresh_current")
				for _序号3 in 4:
					await process_frame
				if str(窗.get("_八门选中门")) != "开门":
					_失败.append("③e 回帧重建后选中门丢了（会被弹回总览）")
				var 页4 := _取页(窗, "八门")
				var 线4 := (页4.get_node_or_null("穴位面板/穴位连线_开门") if 页4 != null else null) as Line2D
				if 线4 == null or not 线4.visible:
					_失败.append("③e 重建后没回到「开门」视图（穴位连线_开门 应可见）")

			# ③f 「突破瓶颈」那一整串：入口钮显隐、弹窗里的数、以及**谁才真该发 1290:3**。
			await _验突破瓶颈(窗, 会话)

		# ③ 提升弹窗的开始按钮必须接了线（弹窗名留空 = 这一页不走这套，比如八门）
		var 弹窗 := 页.find_child(String(项[7]), true, false) if not String(项[7]).is_empty() else null
		if String(项[7]).is_empty():
			pass
		elif 弹窗 == null:
			_失败.append("「%s」找不到弹窗 %s" % [名, String(项[7])])
		else:
			var 开始 := 弹窗.find_child("开始提升按钮", true, false) as Button
			if 开始 == null:
				_失败.append("「%s」的 %s 里没有「开始提升按钮」" % [名, String(项[7])])
			elif 开始.pressed.get_connections().is_empty():
				_失败.append("「%s」的「开始提升按钮」没接接线（点了不会发协议）" % 名)

		# ③d 提升弹窗的**默认可见性**（2026-10-17 巡检）：三页统一口径 =
		#   场景根写 `visible = false`、`open_popup()` 必须把它亮起来。
		#   修前两种坏：柔拳页根是隐藏的、脚本 open_popup 不置 visible ⇒ **点了提升永远看不见**；
		#   写轮眼/轮回页根**没写** visible=false ⇒ **一进页弹窗常亮、烘的示例值全外露**。
		#   反向对照：摘掉场景那行 visible=false ⇒ 第一句点名；把脚本的 visible=true 删掉 ⇒ 第二句点名。
		if 名 in ["写轮眼", "柔拳", "轮回六道"] and 弹窗 != null:
			if 弹窗.visible:
				_失败.append("「%s」的提升弹窗一进页就亮着（场景根应写 visible=false）" % 名)
			if 弹窗.has_method("open_popup"):
				弹窗.call("open_popup")
				await process_frame
				if not 弹窗.visible:
					_失败.append("「%s」的 open_popup 没把弹窗亮起来（点了提升看不见）" % 名)
			else:
				_失败.append("「%s」的提升弹窗没有 open_popup 方法（谁在响应提升按钮？）" % 名)

		# ③e 提升弹窗里的**数字是真值**（2026-10-17 巡检 #6）。
		#   场景烘的是美术按 **stage2** 抄的示例（成功率 50%、条上限 1000、祝福 0-6），
		#   原版三个弹窗类全部读客户端 Etc 表 `stage<当前阶+1>.stageUp`
		#   （`RouQuanTiShengWindow.as:222-242`、`TishengTongshuPanel.as:97-127`、
		#    `LunHuiYanTiShengWindow.as:92-111`），服务端**从不下发**这些字段。
		#   上面灌的状态：写轮眼 9 阶→stage10（prob 1、show 3000、1800-3000）、
		#   柔拳 5 阶→stage6（4、1000、400-550）、轮回 4 阶→stage5（6、1000、280-360）
		#   ⇒ 只要还显示 50%/100/0-6 就是没读表。
		#   反向对照：把 `接提升弹窗` 末尾那句 `填提升弹窗(...)` 删掉 ⇒ 三条点名。
		if 名 in ["写轮眼", "柔拳", "轮回六道"] and 弹窗 != null:
			var 人物表: Dictionary = {
				"写轮眼": "XieLunYan", "柔拳": "RouQuan", "轮回六道": "LunHuiYan",
			}
			var 族表 := String(人物表[名])
			var 本页状态: Dictionary = 会话.cultivation_states[名] as Dictionary
			var 下一阶: int = int(本页状态.get("stage", 1)) + 1
			var 配置 := _提升表配置(族表, 下一阶)
			if 配置.is_empty():
				_失败.append("「%s」这一腿没配到 stage%d 的 stageUp ⇒ 表读不到，弹窗没法验" % [名, 下一阶])
			else:
				var 比率 := 弹窗.find_child("成功率说明文字", true, false) as Label
				if 比率 == null or 比率.text != "本次提升成功率：%d%%" % int(配置.get("prob", 0)):
					_失败.append("「%s」的成功率该读表（stage%d prob=%s），实测「%s」"
						% [名, 下一阶, str(配置.get("prob")), 比率.text if 比率 != null else "无"])
				var 条 := 弹窗.find_child("祝福值进度条", true, false) as ProgressBar
				if 条 == null or int(条.max_value) != int(配置.get("zhufu_show", 0)):
					_失败.append("「%s」的祝福条上限该是 stage%d 的 zhufu_show=%s（不是写死 100），实测 %s"
						% [名, 下一阶, str(配置.get("zhufu_show")), str(条.max_value) if 条 != null else "无"])
				var 祝福文案 := 弹窗.find_child("说明文字1", true, false) as RichTextLabel
				var 期望祝福 := "%d-%d" % [int(配置.get("zhufu_min", 0)), int(配置.get("zhufu_max", 0))]
				if 祝福文案 == null or not 祝福文案.text.contains(期望祝福):
					_失败.append("「%s」的祝福值区间该带 stage%d 的 zhufu_min/max（应含「%s」），实测「%s」"
						% [名, 下一阶, 期望祝福, 祝福文案.text if 祝福文案 != null else "无"])
				var 消耗文案 := 弹窗.find_child("消耗说明文字", true, false) as RichTextLabel
				var 期望消耗 := "%d张" % int(配置.get("needItemCnt", 0))
				if 消耗文案 == null or not 消耗文案.text.contains(期望消耗):
					_失败.append("「%s」的消耗该带 stage%d 的 needItemCnt（应含「%s」），实测「%s」"
						% [名, 下一阶, 期望消耗, 消耗文案.text if 消耗文案 != null else "无"])
				# 满阶时按钮该点不动（原版 `RouQuanManager.as:167-170`：8 阶 canTiSheng = false）。
				会话.cultivation_states[名] = {"stage": _表最高阶(族表)}
				窗.call("_refresh_current")
				for _满帧 in 3:
					await process_frame
				var 满页 := _取页(窗, 名)
				var 弹窗满 := 满页.find_child(String(项[7]), true, false) as Control if 满页 != null else null
				var 满按钮 := 弹窗满.find_child("开始提升按钮", true, false) as Button if 弹窗满 != null else null
				if 满按钮 == null or not 满按钮.disabled:
					_失败.append("「%s」已到最高阶，「开始提升按钮」该置灰（实测 %s）"
						% [名, "取不到这个按钮" if 满按钮 == null else "还能点"])
				会话.cultivation_states[名] = 本页状态
				窗.call("_refresh_current")
				for _补帧 in 3:
					await process_frame

		# ④ 昆虫强化弹窗（§3.112）—— 上面 ③ 那条对**这一页是假绿**：寄坏之术页里有**两枚**
		#   名叫「开始提升按钮」的节点，`find_child` 命中的是「底图/放置区底图」那枚（文案
		#   「放入昆虫」，其实是原版的 `_itemBox.dropBtn`）⇒ "接得上"恒为真。
		#    这里改用**直取路径**判真提交钮，并把行为钉住（点"放入"不许发协议；点"开始强化"
		#    必须带 [位置, 用镇灵石, 张数] 三个字段 —— 少了后两个，镇灵石与寄坏玉都不生效）。
		if 名 == "寄坏之术":
			await _验昆虫弹窗(窗, 页, 会话)
			if not _弹窗腿跑完:
				_失败.append("④ `_验昆虫弹窗` 没跑到底（中途 return 或脚本报错退出）⇒ ⑫ 数量行几何与报修①②③一整串没量到")
			# 虫槽落点 + 强化入口（2026-10-27 用户报修①「昆虫不能佩戴」②「强化按键不能点击」）。
			# ⚠ 不把 `页` 传进去：④ 弹窗腿结尾又重渲染过，手里那枚 `页` 早是 **freed**
			#   （第一版就这么死过一次：类型化参数收到 freed Control ⇒ `_跑` 抛错挂死、无判定）。
			await _验虫槽落点(窗, 会话)
			# 2026-10-31 用户报修①没放虫结果格里却有图标 ②详情框被强化面板盖住 ③成功后不同步。
			await _验昆虫面板三修(窗, 会话)
			if not _同步腿跑完:
				_失败.append("④b `_验昆虫面板三修` 没跑到底（中途 return 或脚本报错）⇒ 2026-10-31 那三条没量到")

	# ⑤ 八门**统计帧**的解析：`1290:3:list_id:exploded:属性列:总穴位数:已开穴位数:共享经验:共享次数`。
	# ⚠️ 八门的**回包动作号跟别族不一样**（原版 `MaiProcessor.handleMaiStatePacket`）：
	#    1 = 开通倒计时 · 2 = 一门已开数更新 · **3 = 统计帧** · 4/5 = 突破信息；
	#    八门**没有**祝福值那一支（`_send_cultivation_blessing` 只发给手里剑/柔拳/写轮眼那几族）。
	#    ⚠️ 这条腿第一版喂的是 `1290:1:…`（照着"action 1 = 别族的祝福值"想当然），
	#    而服务端真发的是 3 —— **手编帧喂错动作号 = 门自己假绿**，所以这里逐字段对 AS3 动作表。
	var 后端: Node = root.get_node_or_null("/root/BackendConnection")
	if 后端 == null:
		_失败.append("拿不到 BackendConnection ⇒ 八门统计帧那一腿没量到")
	else:
		后端.call("_handle_bridge_text", "1290:3:0:0&24@1&21@2&17:4&30!5&40:62:62:1000:3")
		var 八: Dictionary = (后端.get("authoritative_cultivation") as Dictionary).get("八门", {})
		var 已开: Dictionary = 八.get("exploded", {}) as Dictionary
		if int(八.get("list_id", -1)) != 0 or int(已开.get(0, -1)) != 24 or int(已开.get(2, -1)) != 17:
			_失败.append("八门统计帧该解析出 list_id=0 与每门已开数 {0:24,1:21,2:17}，实测 %s" % str(八))
		if int(八.get("total_points", 0)) != 62 or int(八.get("exploded_total", 0)) != 62 \
				or int(八.get("shared_exp", 0)) != 1000:
			_失败.append("八门统计帧的总穴位数/已开总数/共享经验该解析出来，实测 %s" % str(八))
		if 八.has("blessing"):
			_失败.append("八门不该有 `blessing`（那一支是别族的，八门没有祝福值）")
		# 开通一次的结果帧：`2:list_id:mai_id:该门已开数`（成功失败都发）
		后端.call("_handle_bridge_text", "1290:2:0:3:7")
		var 已开2: Dictionary = ((后端.get("authoritative_cultivation") as Dictionary).get("八门", {}) as Dictionary).get("exploded", {}) as Dictionary
		if int(已开2.get(3, -1)) != 7:
			_失败.append("开通结果帧（动作 2）该把那一门的已开数更新成 7，实测 %s" % str(已开2))

		# ⑤b 统计帧的**属性列**（fields[4] = 原版 `MaiStatistic.totalAttrGain`）——
		#   突破弹窗块1 那两行「已为你提升属性」唯一来源；修前整列没解析 ⇒ 只能显示美术烘的假数。
		#   属性号 = 原版 `SubAttrType`（1=maxhp 2=maxmp 4=atk 5=def 6=bsk 7=avd，
		#   与服务端 `_mai_sub_attribute_rows` 用的 `EquipmentAttribute` 同一套号）。
		后端.call("_handle_bridge_text", "1290:3:0:0&24@1&21:1&50@4&30@99&7:62:62:1000:3")
		var 属性: Dictionary = ((后端.get("authoritative_cultivation") as Dictionary).get("八门", {}) as Dictionary).get("attrs", {}) as Dictionary
		if int(属性.get("maxhp", 0)) != 50 or int(属性.get("atk", 0)) != 30:
			_失败.append("统计帧属性列该解析出 {maxhp:50, atk:30}，实测 %s" % str(属性))
		if 属性.has(99) or 属性.has("99"):
			_失败.append("认不出的属性号（99）该丢掉，不能猜成某个属性：%s" % str(属性))
		# ⑤c 突破信息两帧：修前**整条静默丢**（既不进状态也不提示）。
		#   ⚠️ 1290:4 是**角色外观**帧（原版 `MaiProcessor.actionUpdateMaiExplodedCount`
		#     → `CharacterHandler.as:962` → `Character.setMaiExploedCount`，0..8 一档光环），
		#     不喂页面数据；1290:5 = `MaiLevelupInfo.decode`（6 个字段：`nextAttrGain` 原版
		#     只 new 不解码）。两帧在原版 UI 里都没人用（`Client.onMaiLevelupInfo` 是空函数），
		#     存下来只为「服务端主动发时不静默丢」，界面口径仍以客户端表为准。
		后端.call("_handle_bridge_text", "1290:4:777:1:3")
		var 八门档: Dictionary = (后端.get("authoritative_cultivation") as Dictionary).get("八门", {})
		if int(八门档.get("look_list_id", -1)) != 1 or int(八门档.get("look_exploded_gates", -1)) != 3:
			_失败.append("1290:4 该存 look_list_id=1 / look_exploded_gates=3，实测 %s" % str(八门档))
		后端.call("_handle_bridge_text", "1290:5:1:4&30@1&50:2:16000027:9:10000")
		var 信: Dictionary = ((后端.get("authoritative_cultivation") as Dictionary).get("八门", {}) as Dictionary).get("levelup_info", {}) as Dictionary
		if int(信.get("list_id", -1)) != 1 or int(信.get("next_list_id", -1)) != 2 \
				or int(信.get("item_id", 0)) != 16000027 or int(信.get("item_count", 0)) != 9 \
				or int(信.get("zq", 0)) != 10000:
			_失败.append("1290:5 该按 MaiLevelupInfo 的六个字段存下，实测 %s" % str(信))
		if int((信.get("attrs", {}) as Dictionary).get("atk", 0)) != 30:
			_失败.append("1290:5 的属性列该一起解析（lastAttrGain），实测 %s" % str(信))

		# ⑤d **2054 已装备寄坏虫整包**（2026-10-17 巡检 #9）。修前客户端全文没有 2054 这一支
		#   ⇒ 服务端每次上线/穿卸/强化后发的这份快照被整条丢掉，寄坏之术页四格永远空
		#   （2052 那份装备快照不含它们：服务端 `EQUIPPED_INFO` 支只收 `-199 <= slot < 0`，
		#   昆虫四位是 -200..-203）。键**必须取包里的 slot** —— `装备部位.位置(id)` 那张表
		#   昆虫只有「昆虫包」(131) 一项，按 id 算出来是 0，会把整份装备表覆盖掉。
		var 虫一体 := _虫体("01310001", 装备部位表.昆虫一, 3)
		var 虫二体 := _虫体("01310002", 装备部位表.昆虫二, 0)
		后端.call("_handle_bridge_text", "2054:%s@%s" % [虫一体, 虫二体])
		var 装备档: Dictionary = 后端.get("authoritative_equipment") as Dictionary
		var 会话装备: Dictionary = 会话.equipped_items
		if not (装备档.get(装备部位表.昆虫一, {}) as Dictionary).has("id") \
				or String((装备档.get(装备部位表.昆虫一) as Dictionary).get("id", "")) != "01310001":
			_失败.append("2054 该按包里的 slot 存进昆虫一（-200），实测 %s" % str(装备档.keys()))
		if not (会话装备.get(装备部位表.昆虫二, {}) as Dictionary).has("id"):
			_失败.append("2054 该同步进会话.equipped_items（昆虫二），实测键 %s" % str(会话装备.keys()))
		if 装备档.has(0):
			_失败.append("昆虫位算不出 equip_position ⇒ 绝不能往键 0 里存（会污染整份装备表）")
		# ⑤e 四格**回显**：修前这一格只写 tooltip，穿上虫页面什么都不会变。
		# ⚠️ 得先**切到寄坏之术页**再刷 —— `_refresh_current` 只渲染当前页，
		#   停在八门页时 `初始化寄坏之术页` 根本不会跑（第一版就这么假绿过一次）。
		窗.call("_set_character_main_tab", 1)
		await process_frame
		窗.call("_set_character_sub_tab", 2)
		for _帧 in 3:
			await process_frame
		窗.call("_refresh_current")
		for _帧 in 4:
			await process_frame
		var 虫页 := _取页(窗, "寄坏之术")
		if 虫页 == null:
			_失败.append("⑤e 取不到寄坏之术页 ⇒ 回显那一腿没量到")
		else:
			var 槽 := 虫页.get_node_or_null("虫槽区域/寄坏槽一") as TextureButton
			var 图标 := 槽.get_node_or_null("昆虫图标") as TextureRect if 槽 != null else null
			var 名称 := 槽.get_node_or_null("昆虫名称") as Label if 槽 != null else null
			if 图标 == null or 名称 == null:
				_失败.append("寄坏槽一里缺烘好的「昆虫图标 / 昆虫名称」子节点（页面脚本不许运行期 new）")
			else:
				if not 图标.visible or 图标.texture == null:
					_失败.append("2054 有虫时格子里的昆虫图标该亮起来并有图")
				# ⚠️ 2026-10-29 用户报修「寄坏之术页不显示昆虫图标」：上面那条只量「有图」，
				#   修前这四枚 `昆虫图标` 一个偏移都没烘 ⇒ 矩形 0×0，纹理有也画不出来（门照样绿）。
				#   这里量**画得出来的落点**：虫图标 PNG 实际 34×34、槽底 `无装备虫槽.png` 64×64
				#   ⇒ 居中 15..49。期望值写死，不许从场景自身反推。
				if 槽.size != Vector2(64, 64):
					_失败.append("寄坏槽该是 64×64（无装备虫槽.png 实际尺寸），实测 %s" % str(槽.size))
				if 图标.size != Vector2(34, 34):
					_失败.append("昆虫图标该占 34×34（虫图标 PNG 实际尺寸），实测 %s —— 0×0 就是有纹理也画不出来" % str(图标.size))
				if 图标.position != Vector2(15, 15):
					_失败.append("昆虫图标该在 64×64 槽里居中 (15,15)，实测 %s" % str(图标.position))
				if 图标.texture != null and 图标.texture.get_size() != Vector2(34, 34):
					_失败.append("虫图标纹理该是 34×34，实测 %s" % str(图标.texture.get_size()))
				if not 名称.visible or 名称.text != "蝉+3":
					_失败.append("格下那行该是原版 `KunChongCell:108`「物品名+强化等级」= 蝉+3，实测「%s」"
						% 名称.text)
			var 空格 := 虫页.get_node_or_null("虫槽区域/寄坏槽四") as TextureButton
			var 空图标 := 空格.get_node_or_null("昆虫图标") as TextureRect if 空格 != null else null
			if 空图标 != null and 空图标.visible:
				_失败.append("没装备的第四格图标不该亮着")
		# 卸完再发一份空包：整包语义 ⇒ 四格该清空，不能留着旧虫回显。
		后端.call("_handle_bridge_text", "2054:-")
		if 装备档.has(装备部位表.昆虫一) or 会话装备.has(装备部位表.昆虫一):
			_失败.append("2054:- 该把昆虫四格清掉，实测还在 %s" % str(装备档.keys()))
		窗.call("_refresh_current")
		for _帧 in 4:
			await process_frame
		var 槽2 := _取页(窗, "寄坏之术").get_node_or_null("虫槽区域/寄坏槽一") as TextureButton
		var 图标2: TextureRect = 槽2.get_node_or_null("昆虫图标") if 槽2 != null else null
		if 图标2 != null and (图标2.visible or 图标2.texture != null):
			_失败.append("收到空包后重渲染，第一格图标该熄灭并清掉纹理（否则留着上一只虫的残影）")

		# ⑥ 别族**升阶结果帧** `opcode:2:成功:用神符`（2026-10-17 巡检：修前整条被丢 ⇒
		#   点「开始提升」零反馈）。文案逐族对原版语言表（轮回复用柔拳那两句话，照抄）。
		#   反向对照：删掉 _handle_cultivation_text 的 action==2 支 ⇒ 三条提示全丢、当场点名。
		var 通知列: Array = []
		会话.notification_requested.connect(func(文: String) -> void: 通知列.append(文))
		var 结果腿: Array = [
			["1821:2:1:true", "恭喜你，使用写轮眼神符提升成功。", "写轮眼", true],
			["2307:2:0:false", "很抱歉，进阶失败！", "柔拳", false],
			["2313:2:1:false", "恭喜你进阶成功！", "轮回六道", true],
		]
		for 腿: Array in 结果腿:
			通知列.clear()
			后端.call("_handle_bridge_text", String(腿[0]))
			if 通知列.find(String(腿[1])) < 0:
				_失败.append("升阶结果帧 %s 该提示「%s」，实测通知 %s" % [腿[0], 腿[1], str(通知列)])
			var 一族: Dictionary = (后端.get("authoritative_cultivation") as Dictionary).get(String(腿[2]), {})
			if bool(一族.get("last_success", false)) != bool(腿[3]):
				_失败.append("升阶结果帧 %s 该把 %s 的 last_success 记成 %s，实测 %s" % [腿[0], 腿[2], 腿[3], str(一族)])
		# 八门的 1290:2 是**该门已开数**，绝不能落进别族提示支
		通知列.clear()
		后端.call("_handle_bridge_text", "1290:2:0:3:7")
		if not 通知列.is_empty():
			_失败.append("八门结果帧不该弹升阶提示，实测 %s" % str(通知列))

	# ⑦ 八门**总览页**读真值 + 默认视图（2026-10-17 巡检 #11）
	await _验总览页(窗, 会话)

	# ⑨ 写轮眼 / 柔拳那两页**按阶段烘死的「击杀 / 获得」文案**逐条回表（2026-10-18 三面板巡检 #26）
	_验阶段文案()

	# ⑩ 整窗扫「可见按钮必须接线」（同一次巡检 #26：当场抓到两枚死钮，见 `_验无死按钮` 上方）
	await _验无死按钮(窗)

	# ⑧ 结印页那一整串（2026-10-17 巡检 #12）：自动提升的客户端循环、二次确认、
	#   弹窗跨重建保持。放在**最后**：它结尾要 `close()` 一次，之后不能再有别的腿量这扇窗。
	if 后端 == null:
		_失败.append("⑧ 拿不到 BackendConnection ⇒ 结印那一整串没量到")
	else:
		await _验结印页(窗, 会话, 后端)

	# ⑪ 三族**自动提升**那一串（2026-10-18 三面板巡检 #13 = 结印 #12 那套管线的推广）。
	#     必须排在结印**之后**：结印那串结尾 `close()` 一次，而 `_overlay.visible`
	#     是这三族定时器三道闸之一（`_排族下一跳` 里的 `已打开()`），不重新开窗就永远量不到第二发。
	if 后端 == null or 管理 == null:
		_失败.append("⑪ 拿不到 BackendConnection / 窗口管理 ⇒ 三族自动提升那一串没量到")
	else:
		await _验族自动提升(窗, 会话, 后端, 管理)

	# ⑫「战斗属性」右边那枚箭头开合的**「其他属性」浮板**（2026-10-18 三面板巡检 #29）。
	#     放最后：它自己换 `_backend`、自己改 `会话.equipped_items` 与三条率，且结尾必须把窗关回原样。
	if 管理 == null:
		_失败.append("⑫ 拿不到窗口管理 ⇒「其他属性」浮板那一串没量到")
	else:
		await _验其他属性浮板(窗, 会话, 管理)

	# ⑬ 提升弹窗里那枚「购买」（2026-10-19 体检报告 P1-3）：原版是**问商城要这件材料的条目**
	#     （1086 一个字段 = 物品 id），修前三族灰着、寄坏两格只弹一句占位提示。
	#     放最后：它自己换 `_backend`、自己改三族的 `stage`，结尾两样都还原。
	if 管理 == null:
		_失败.append("⑬ 拿不到窗口管理 ⇒「购买」那一串没量到")
	else:
		await _验材料购买(窗, 会话, 管理)

	# ⑭ 人物信息区那十处悬停提示（2026-10-21 用户报修 #53：原版有、我们一直没接）。
	await _验信息提示(窗, 会话, 管理)
	if not _信息提示跑完:
		_失败.append("⑭ `_验信息提示` 没跑到底（中途报错退出）⇒ 那十处提示一律没量到")

	# ⑮ 写轮眼 / 轮回六道两页的**逐件落位**（数字全部现算自 `真值/窗口/人物窗秘术页.md` §① §②，
	#     不是从截图上量的）+ 那列阶段钮**真能滚**（10-25 被打回的头一条：改完 `vertical_scroll_mode`
	#     仍然滚不动，因为内容框的 `custom_minimum_size` 还停在视口高 ⇒ 行程 0）
	#     + 服务端同档帧**不许把页签打回第一档**（第二条）。
	await _验秘术页几何(窗)
	if not _几何跑完:
		_失败.append("⑮ `_验秘术页几何` 没跑到底 ⇒ 两页的逐件落位与滚动一条都没判到")

	if _失败.is_empty():
		print("人物秘术页回归测试：通过（四页建得出 / stage 推得进 / 提升按钮接得上 / 八门突破"
			+ "：入口显隐·开窗不发包·弹窗读表·两道拦截·发完关窗 / 1290:4·5 与属性列解析"
			+ " / 2054 寄坏虫整包回显四格"
			+ " / 扩展页按需只建当前页·三页尺寸覆盖不丢 / 柔拳右列标题墨迹不压属性条"
			+ " / 总览页九处烘值改真值·默认视图=总览·两视图互斥"
			+ " / 写轮眼 24 段·柔拳 8 句按阶段文案逐条回表（怪名/物名/gain）"
			+ " / 八个子页逐页扫死按钮（可见·有内容·没置灰 ⇒ 必须接点击信号之一，OptionButton 认 `item_selected`）"
			+ " / 结印：手动一发 byte0·满阶静默·二次确认五行不压钮·0.8s 循环·三条件停·弹窗跨重建不闪 / 三族自动提升：间隔 1000·800·800、成功分族关窗、手动即停、停止即重开不补旧发、中途不够即停、满阶双钮置灰" \
			+ " / 结印置灰：印号>当前阶整枚禁用灰度（当前阶不灰、数值容器不灰），随 2318 真帧换阶重烘"
			+ " / 其他属性浮板：默认关·箭头接线不发包·(493,84)·三格全角文案与橙绿字号·附加行 4-5-1-2-6-7 顺序累加·每件 3 条上限（变身卡 4）·灵器忍具不进账·板高 121+22n·跨整页重建保持"
			+ " / 购买钮：不置灰·发的就是本阶表里的 needItemId·满阶只提示不发·寄坏两格 16000136/16000137·每枚只一根 pressed"
			+ " / 信息区十处悬停提示：语言表原文逐条·宿主 mouse_filter 已开·原生 tooltip 让位·意志串跟穿戴数组走 / 轮回六道：箭头=TextureButton 无 hover 皮无 stylebox（悬停不出巨大图案、右边不叠第二枚）·未提升壁画套禁用灰度+翻看未达成=灰叠红边（real_stage 由服务端 stage 推）·五技能格悬停原版 MToolTipLunHuiYanSkill（未学红/已学绿冷却消耗、道名·秘笈·获取途径逐句；框挂 `遮罩` 层=原版 stage 弹层，祖先链无裁层、不被 `人物扩展页` 裁下半截·未学技能格**图标**套禁用灰度（原版 getDisableFilter 同矩阵，已学摘灰、逐格跟已学集、重烘随回帧）"
			+ " / 虫槽落点：拖虫上格=穿虫唯一路径（131 前缀闸**连勾玉也放**、兜底=物品表分类镜像服务端 `_can_equip`）·双击佩戴算出的 -205 拦死不留幽灵键·看别人不挂落点·强化入口**永不置灰**（原版整文件无 enabled 赋值）·身上没虫目标兜背包第一只（发背包格号）"
			+ " / 2026-10-27 报修①②③④：放置格认背包来的拖=换强化目标（落点**不判类型**、拒绝出在 validateItem 之后、原文「不是昆虫不能强化」且目标不动、发的是背包格号）" \
			+ "·弹窗四格+虫槽四格悬停原版提示（虫名按该格/强化目标实际那只**现算**、镇灵石/寄坏玉逐字、空格只收不弹、移出即收、原生 tooltip 让位、每格恰好一根线、框挂 `提示宿主` 层不被裁）" \
			+ "·这一页放开 `人物扩展页` 裁剪（八门那页仍钉着裁 ⇒ 不是整扇放开）+ 顶部 29px 真 `push_input` 拖拽跟手·条下不拖·钳 (960-358, 560-30) 与 (0,0)·跨整页重绘保持位置" \
			+ "·数量下拉按引擎地板 57 烘、勾-下拉-尾文字三段不压字（§3.295 那一族的现形）"
			+ " / 2026-10-31 报修①②③：没放入时成功格空+两行 0+自动勾灰+两格悬停不弹（原版 `_itemData` 为空）·放入后产物与 strength[3] 12 万/100% 登场·详情框层序压过强化弹窗 z=100（原版提示挂整屏 stage）·服务端换新字典后携入按背包格重取 ⇒ 详情框星级与成功几率当场同步到 3→4 星 13 万/95%·件没了回到「没放入」")
		quit(0)
	else:
		for 项2 in _失败:
			push_error("人物秘术页回归测试：失败 - %s" % 项2)
		门存档快照.全还原(_文件前)
		quit(1)


## 八门**总览页**（原版 `JingMaiPanel.updateZongLanView:252-282`）。
## 场景里这九处**全烘了值**（进度 `0/181`、属性 `攻击：1299 防御：653`、说明文字是抄表时手打的
## ——「门人」那处与原文「八门」不一样），不覆盖就永远显示设计师的示例数。
## 数据口径 = 统计帧 `1290:3` 存进会话的那几项；解析本身由 ⑤ 那几腿守着，
## 这里直接写 `cultivation_states` 只量**界面读得对不对**。
func _验总览页(窗, 会话) -> void:
	窗.call("_set_character_main_tab", 1)
	await process_frame
	窗.call("_set_character_sub_tab", 0)
	for _帧 in 3:
		await process_frame
	会话.cultivation_states["八门"] = {
		"list_id": 1, "total_points": 62, "exploded_total": 58,
		"shared_exp": 1000, "shared_exp_count": 7,
		"attrs": {"atk": 30, "def": 12, "bsk": 5, "avd": 8, "maxhp": 50, "maxmp": 20},
	}
	窗.call("_refresh_current")
	for _帧 in 4:
		await process_frame
	var 页 := _取页(窗, "八门")
	if 页 == null:
		_失败.append("⑦ 取不到八门页 ⇒ 总览那一腿没量到")
		return
	# ① 默认视图 = 总览（原版 `initView:358` `tabBar.selectedIndex = 0`）
	var 总览页 := 页.get_node_or_null("总览页") as Control
	var 穴位面板 := 页.get_node_or_null("穴位面板") as Control
	if 总览页 == null or not 总览页.visible:
		_失败.append("八门页默认该停在「总览」（原版 selectedIndex=0），实测 %s"
			% ["没有总览页" if 总览页 == null else str(总览页.visible)])
	if 穴位面板 != null and 穴位面板.visible:
		_失败.append("停在总览时门内容（穴位面板）不该同时显示 —— 原版两视图互斥")
	# ② 进度条 + 那行「已开/总数」
	#    ⚠ 填充现在是 `进度条补间` 的 0.5 秒补间（§3.243）⇒ 量之前等**墙上时钟**，不等就是假红；
	#    那行字按数据立刻写，不受影响。
	await create_timer(0.7).timeout
	var 条 := 页.get_node_or_null("总览页/内容面板/块1/进度条") as ProgressBar
	var 数值 := 页.get_node_or_null("总览页/内容面板/块1/进度条/进度数值") as Label
	if 条 == null or int(条.max_value) != 62 or int(条.value) != 58:
		_失败.append("总览进度条该是 58/62（统计帧的 exploded_total/total_points），实测 %s"
			% ["无此节点" if 条 == null else "%d/%d" % [int(条.value), int(条.max_value)]])
	if 数值 == null or 数值.text != "58/62":
		_失败.append("进度数值该跟着走（期望「58/62」），实测「%s」（烘的是 0/181）"
			% ["无此节点" if 数值 == null else 数值.text])
	# ③ 已提升属性两行（`getCurrentMaiProps`）—— 场景烘的 1299/653 那组数必须被冲掉
	var 行一 := 页.get_node_or_null("总览页/内容面板/块1/属性行1") as Label
	var 行二 := 页.get_node_or_null("总览页/内容面板/块1/属性行2") as Label
	if 行一 == null or 行二 == null:
		_失败.append("总览缺「属性行1/属性行2」节点")
	else:
		for 对: Array in [["攻击：30", 行一], ["防御：12", 行一], ["暴击：5", 行一], ["闪避：8", 行一],
				["生命上限：50", 行二], ["查克拉上限：20", 行二]]:
			if not 对[1].text.contains(String(对[0])):
				_失败.append("总览属性行该含「%s」，实测「%s」/「%s」" % [对[0], 行一.text, 行二.text])
		if 行一.text.contains("1299") or 行一.text.contains("653"):
			_失败.append("总览属性行还留着场景烘的示例数：%s" % 行一.text)
	# ④ 三段说明换成原文（烘的那版把 SAY_2 里的「八门」打成了「门人」）
	var 块二一 := 页.get_node_or_null("总览页/内容面板/块2/说明1") as Label
	if 块二一 == null or not 块二一.text.contains("控制体内查克拉的八门"):
		_失败.append("总览 SAY_2 该是原文「…控制体内查克拉的八门，…」，实测「%s」"
			% ["无此节点" if 块二一 == null else 块二一.text.substr(0, 40)])
	var 块三二 := 页.get_node_or_null("总览页/内容面板/块3/说明2") as Label
	if 块三二 == null or not 块三二.text.contains("剩余7次") or not 块三二.text.contains("经验值：1000"):
		_失败.append("总览 SAY_5/6 该带统计帧的共享次数与共享经验（剩余7次 / 经验值：1000），实测「%s」"
			% ["无此节点" if 块三二 == null else 块三二.text])
	# ⑤ 八卦图按脉换（`getBaMenImage`：0表 1里 2魂 3/4印）
	var 图 := 页.get_node_or_null("总览页/内容面板/块4/八卦图") as TextureRect
	if 图 == null or 图.texture == null or not String(图.texture.resource_path).ends_with("里八门.png"):
		_失败.append("list_id=1 时八卦图该是里八门，实测 %s"
			% ["无此节点" if 图 == null else (图.texture.resource_path if 图.texture != null else "无纹理")])
	# ⑥ 点门按钮回门内容、点「总览」再回来 —— 且回来的那一刻 8 枚门按钮不能还按着
	var 开门 := 页.get_node_or_null("门列表/按钮列/开门") as Button
	var 总览钮 := 页.get_node_or_null("门列表/按钮列/总览") as Button
	if 开门 == null or 总览钮 == null:
		_失败.append("总览那条链要用的门按钮取不到（开门 / 总览）")
		return
	开门.pressed.emit()
	for _帧 in 3:
		await process_frame
	页 = _取页(窗, "八门")
	if 页 == null:
		return
	if (页.get_node_or_null("总览页") as Control).visible:
		_失败.append("点了「开门」总览页还亮着（原版两视图互斥）")
	页 = _取页(窗, "八门")
	(页.get_node_or_null("门列表/按钮列/总览") as Button).pressed.emit()
	for _帧 in 3:
		await process_frame
	var 回到总览 := _取页(窗, "八门")
	if 回到总览 == null:
		_失败.append("点「总览」之后取不到八门页")
		return
	if not (回到总览.get_node_or_null("总览页") as Control).visible:
		_失败.append("点「总览」没切回总览视图")
	var 按死: Array = []
	for 门名 in ["开门", "休门", "生门", "伤门", "杜门", "景门", "惊门", "死门"]:
		var 钮 := 回到总览.get_node_or_null("门列表/按钮列/%s" % 门名) as Button
		if 钮 != null and 钮.button_pressed:
			按死.append(门名)
	if not 按死.is_empty():
		_失败.append("停在总览时这些门按钮还呈按下态（原版同一个 tabBar，总览和门不能同亮）：%s"
			% str(按死))


## ⓿ 结印格子的置灰腿（用户 2026-10-27 报修「未完成的印是灰色」）。
## 真值 `JieYinPanel.as:475-500 updateButtonState`：`index < _stage ⇒ filters=[]`、否则
## `[StyleUtil.getGrayFilter()]` ⇒ **印号 > 当前阶才灰；当前阶那枚不灰**；灰套整枚格子
## （默认/选中手势框 + 印式NN 三件贴图件），**数值容器不灰**（原版底部四根 MBar 不在按钮里）。
## 阶用**真帧**推（`2318:0:<阶>:<熟练>` ⇒ `cultivation_received` ⇒ `skills_changed` ⇒
## `_refresh_current` 整页重烘，和 ⑤ 同一条管线）；⚠ 重建后旧引用全失效，**每轮重取页**
## （门卫生规矩④；这里别用 `_render_character` 直调 —— 假绿#20 会叠第二棵树把断言落在旧页上）。
## 反向对照（每条只动一处）：R8 摘掉 `_刷结印置灰` 的调用 ⇒ 两轮 stage3 各 27 条灰红；
## R9 边界 `>` 改 `>=`（当前阶也灰）⇒ 两轮共 6 条"彩色侧"红；R10 边界 `+1` 慢一阶 ⇒ 4 道
## 两轮 6 条"该灰"红；R11 去掉贴图件筛选（数值容器一起涂）⇒ 容器红 36 条。
func _验结印置灰(窗, 后端) -> void:
	# 进页前那发 `2318:0:3:100` 已把 stage=3 落进会话；三档 = 3 → 12（满阶全彩）→ 回 3（给 ① 起留基线）。
	for 档 in [[3, ""], [12, "2318:0:12:50000"], [3, "2318:0:3:100"]]:
		var 期望阶 := int(档[0])
		var 帧文 := String(档[1])
		if 帧文 != "":
			后端.call("_handle_bridge_text", 帧文)
			for 帧 in 4:
				await process_frame
		var 页 := _取页(窗, "结印")
		if 页 == null:
			_失败.append("⓿（第%d档）取不到结印页 ⇒ 这一档的置灰没量到" % 期望阶)
			continue
		for 印号 in 12:
			var 视觉: Array = []
			var 格 := 页.get_node_or_null("印式按钮/印%d" % (印号 + 1)) as Control
			if 格 == null:
				_失败.append("⓿ 缺格子「印式按钮/印%d」" % (印号 + 1))
				continue
			for 子 in 格.get_children():
				if 子 is TextureRect or 子 is TextureButton:
					视觉.append(子 as CanvasItem)
			if 视觉.is_empty():
				_失败.append("⓿ 印%d 没有手势框/印式图（灰没有落点）" % (印号 + 1))
			var 该灰 := (印号 + 1) > 期望阶
			for 件 in 视觉:
				var 材 := (件 as CanvasItem).material as ShaderMaterial
				if 该灰:
					if 材 == null or 材.shader == null \
							or 材.shader.resource_path.get_file() != "禁用灰度.gdshader":
						_失败.append("⓿ 阶%d：印%d 未完成却没灰（原版 updateButtonState 给整枚套 getGrayFilter，"
							% [期望阶, 印号 + 1] + "用户报的「未完成的印是灰色」）")
				elif 材 != null:
					var 词 := "已完成" if 印号 + 1 < 期望阶 else "当前阶"
					_失败.append("⓿ 阶%d：印%d 是%s，原版 filters=[] 该回彩，实测还压着灰材" % [期望阶, 印号 + 1, 词])
			# 数值容器（Control）**不许跟着涂** —— 原版 bars 从没进过按钮的 filters
			var 容: CanvasItem = 格.get_node_or_null("数值容器") as CanvasItem
			if 容 == null:
				_失败.append("⓿ 印%d 缺数值容器（这条判据落空）" % (印号 + 1))
			elif 容.material != null:
				_失败.append("⓿ 阶%d：印%d 的数值容器被涂了灰（原版底部 MBar 不灰）" % [期望阶, 印号 + 1])


## 结印页那一整串（2026-10-17 巡检 #12）。真值逐条对 `JieYinTiShengWindow.as`：
##  · 自动提升 = 客户端**每 0.8 秒重发 byte 0**（`onJieYin_stageupResult:182-193` 那句
##    `setTimeout(tiShengJieYin, 800)`），**不是**服务端一次吞光精华 —— 上行只有 byte 0
##    这一个动作，byte 1（`eatUpAutoConsumeAllZq`）全工程没有一处 UI 调用；
##  · 点「自动提升」先过 `FamillyPopUpWindow` 二次确认（`autoTiShengHandler:68-87`），
##    确认了才换钮文字并立刻跳第一下（`sureToAutoTiSheng:205-211`）；点取消 ⇒ 什么都不发生；
##  · 三条停止条件：精华 < `needZq`（`tiShengJieYin:99-104`）· `result=1` 升阶（`:186-188`）
##    · 手动那一跳或点「停止提升」（`tiShengHandler:213-217` 起手就 `clearTimeOut()`）；
##  · **结果帧一句提示都不弹**（`Client.onJieYin_eatUpResult:8285-8291` 只把它转给提升弹窗）；
##  · 关窗 = 停（原版关掉 `CharWindow2` 连带 `JieYinTiShengWindow.destroy():54-57`，
##    那函数就一句 `clearTimeOut()`）。
## 另钉两条界面账：弹窗开合要**跨整页重建**保持（修前每 0.8 秒闪没一次）、
## 二次确认那**五行**正文不能被按一行算高（修前 87 高的窗 + 钮 y=52 ⇒ 直接压在文字上）。
##
## 反向对照（2026-10-17 都实跑过，每条只摘一处、摘完即还原）：
## ① 摘掉 `初始化结印页` 里那句 `直接展开` ⇒「刷新一次弹窗就闪没了」点名；
## ② 去掉 `_收到结印帧` 的 `success` 判据 ⇒「result=1…该停掉自动提升」点名
##    （下游「停掉之后不该再补包」「钮文字该换回自动提升」跟着红，是同一处）；
## ③ 删 `_排结印下一跳` 的令牌比对 ⇒ ⑧b 点名（期望 4 发、实测 5 发）。
##    ⚠️ 光有 ⑧（点停止后等 1.1 秒）**量不到**：`停结印自动()` 已经把 `_结印自动提升`
##    置 false，旧定时器自己就被那条判据拦下了；令牌防的是**停止后立刻重开**——
##    那时自动态又是 true、窗口又开着，只有 `计 != _结印自动计时` 还拦得住。
## ④ `弹消息` 退回写死一行 ⇒「正文只按一行开高（实测 23.0）」点名；
## ⑤ `close()` 里删 `停结印自动()` ⇒「关窗没停掉自动提升」点名；
## ⑥ 把 `OP_JIE_YIN` 改回塞进 `_handle_cultivation_text` ⇒「结印结果帧弹了别族的升阶
##    提示：很抱歉，进阶失败！」点名（其余腿红是整条帧没处解，同一处引起）。
## ①④⑤ 三条同一次跑里各红各的，互不掩盖。
func _验结印页(窗, 会话, 后端) -> void:
	var 假 := 假后端.new()
	窗.set("_backend", 假)
	var 通知: Array = []
	会话.notification_requested.connect(func(文: String) -> void: 通知.append(文))
	会话.player_stats["zq"] = 5000
	# 权威状态**从帧里来**（stage=3 ⇒ 他的上限表 4000、`Etc` 表 needZq 1000）：
	# 修前这里喂的是 `2318:0:1:4:1000:100:19000` —— 后面那三段是线上**根本没有的字段**。
	后端.call("_handle_bridge_text", "2318:0:3:100")
	await _去结印页(窗)
	# ── ⓿ 未完成的印该灰（用户 2026-10-27 报修；真值 `JieYinPanel.as:475-500`）
	await _验结印置灰(窗, 后端)
	var 弹窗 := _结印弹窗(窗)
	if 弹窗 == null:
		_失败.append("⑧ 取不到结印页的提升弹窗 ⇒ 结印那一整串没量到")
		窗.set("_backend", null)
		return

	# ── ① 进页时弹窗收着，熟练度按**当前阶**那一档画
	if 弹窗.visible:
		_失败.append("结印的提升弹窗一进页就亮着（他 `_ready` 该收起 + 隐藏）")
	if 弹窗.position != Vector2(5.0, 700.0):
		_失败.append("进页时弹窗该停在收起位 (5,700)，实测 %s" % str(弹窗.position))
	var 阶三 := 弹窗.get_node_or_null("印3阶段") as Control
	var 阶一 := 弹窗.get_node_or_null("印1阶段") as Control
	if 阶三 == null or 阶一 == null:
		_失败.append("结印弹窗里缺「印1阶段 / 印3阶段」节点")
	else:
		if not 阶三.visible or 阶一.visible:
			_失败.append("stage=3 时只该亮「印3阶段」，实测 印3=%s、印1=%s"
				% [str(阶三.visible), str(阶一.visible)])
		var 条 := 阶三.get_node_or_null("熟练度进度条") as ProgressBar
		var 数值 := 阶三.get_node_or_null("熟练度进度条/熟练度值数值") as Label
		# 熟练度那根也接了 0.5s 补间（`JieYinTiShengWindow.as:35` 的 `_shulianBar` 是 MBarExpF，
		# §3.243）⇒ 先等墙上时钟再量；上面那两条 visible 判据不受影响，不用等。
		await create_timer(0.7).timeout
		if 条 == null or int(条.max_value) != 4000 or int(条.value) != 100:
			_失败.append("3 阶的熟练度该是 100/4000（上限 = 他表里 stage3 的 needPointCnt），实测 %s"
				% ["无进度条" if 条 == null else "%d/%d" % [int(条.value), int(条.max_value)]])
		if 数值 == null or 数值.text != "100/4000":
			_失败.append("进度条上那行字该跟着真值走，期望「100/4000」，实测「%s」"
				% ["无此节点" if 数值 == null else 数值.text])

	# ── ② 开弹窗 → 整页重建之后**还展开着**；关闭 → 重建之后收回
	var 页 := _取页(窗, "结印")
	var 入口 := 页.get_node_or_null("提升结印") as Button
	if 入口 == null or 入口.pressed.get_connections().size() < 2:
		_失败.append("「提升结印」该有两条触发（他场景的 open_popup + 宿主记开合），实测 %s"
			% ["无按钮" if 入口 == null else "%d 条" % 入口.pressed.get_connections().size()])
	else:
		入口.pressed.emit()
		await process_frame
		窗.call("_refresh_current")
		for 帧 in 4:
			await process_frame
		var 弹窗2 := _结印弹窗(窗)
		if 弹窗2 == null:
			_失败.append("② 刷新后取不到结印弹窗 ⇒ 保持那一腿没量到")
		else:
			if not 弹窗2.visible:
				_失败.append("刷新一次弹窗就闪没了（开合没记在窗口上，或重建时没调 `直接展开`）"
					+ " —— 自动提升每 0.8 秒闪一次就是这条")
			elif 弹窗2.position != Vector2(5.0, 228.0):
				_失败.append("重建后该**直接落回展开位**、不重播滑入，期望 (5,228)，实测 %s"
					% str(弹窗2.position))
			var 关 := 弹窗2.get_node_or_null("关闭按钮") as Button
			if 关 == null or 关.pressed.get_connections().size() < 2:
				_失败.append("结印弹窗的「关闭按钮」缺接线（他场景一条 + 宿主记状态一条）")
			else:
				关.pressed.emit()
				await process_frame
				窗.call("_refresh_current")
				for 帧 in 4:
					await process_frame
				var 弹窗3 := _结印弹窗(窗)
				if 弹窗3 == null:
					_失败.append("② 关闭后刷新取不到结印弹窗")
				elif 弹窗3.visible:
					_失败.append("点了关闭、重建之后弹窗还亮着（`_结印弹窗开着` 没跟着清）")

	# ── ③ 手动那一跳 = **一发** byte 0，别的不带
	弹窗 = _结印弹窗(窗)
	var 开始: Button = null
	if 弹窗 != null:
		开始 = 弹窗.get_node_or_null("开始提升按钮") as Button
	if 开始 == null:
		_失败.append("③ 取不到「开始提升按钮」⇒ 结印后面几腿没量到")
		窗.set("_backend", null)
		return
	通知.clear()
	假.结印 = 0
	开始.pressed.emit()
	await process_frame
	if 假.结印 != 1:
		_失败.append("点「开始提升」该发**一发** 2318:0（`requestJieYin_EatUp`），实测 %d 发" % 假.结印)
	if not 假.收到.is_empty() or not 假.八门.is_empty():
		_失败.append("结印那一跳不该顺带发别族的包，实测 寄坏 %s、八门 %s" % [str(假.收到), str(假.八门)])
	if not 通知.is_empty():
		_失败.append("手动那一跳发成功不该刷任何回执（用户 2026-10-18 报修），实测通知 %s" % str(通知))

	# ── ④ 精华不够：只提示、**零发包**（`tiShengJieYin` 的 `param1=false` 那一支）
	会话.player_stats["zq"] = 999		# stage3 的 needZq = 1000
	通知.clear()
	假.结印 = 0
	开始.pressed.emit()
	await process_frame
	if 假.结印 != 0:
		_失败.append("精华 999 < needZq 1000 时不该发包，实测 %d 发" % 假.结印)
	if 通知.find("很抱歉，你的精华不够") < 0:
		_失败.append("手动那一跳精华不够该发 `EQUIP_STRENGTH_FAIL_PROMPT_2_1`「很抱歉，你的精华不够」，实测 %s"
			% str(通知))
	会话.player_stats["zq"] = 5000

	# ── ⑤ 满阶（12 阶 + 熟练度到本阶上限）：原版 `canTiSheng=false` ⇒ **一句 return**，
	#     不发也不提示（`JieYinManager.getJieYinProps:149-156`）
	后端.call("_handle_bridge_text", "2318:0:12:50000")
	for 帧 in 4:
		await process_frame
	弹窗 = _结印弹窗(窗)
	开始 = null
	if 弹窗 != null:
		开始 = 弹窗.get_node_or_null("开始提升按钮") as Button
	if 开始 == null:
		_失败.append("⑤ 满阶那一腿取不到「开始提升按钮」")
	else:
		通知.clear()
		假.结印 = 0
		开始.pressed.emit()
		await process_frame
		if 假.结印 != 0 or not 通知.is_empty():
			_失败.append("12 阶满熟练度时「开始提升」该像原版一样什么都不做（canTiSheng=false 直接 return），"
				+ "实测发 %d 包、通知 %s" % [假.结印, str(通知)])
	后端.call("_handle_bridge_text", "2318:0:3:100")
	for 帧 in 4:
		await process_frame

	# ── ⑥ 点「自动提升」先弹**原版五行二次确认**
	弹窗 = _结印弹窗(窗)
	var 自动钮: Button = null
	if 弹窗 != null:
		自动钮 = 弹窗.get_node_or_null("自动提升按钮") as Button
	if 自动钮 == null or 自动钮.pressed.get_connections().is_empty():
		_失败.append("「自动提升按钮」没接线（点了不会有反应）")
		窗.set("_backend", null)
		return
	if 自动钮.text != "自动提升":
		_失败.append("没进自动态时钮文字该是「自动提升」，实测「%s」" % 自动钮.text)
	假.结印 = 0
	自动钮.pressed.emit()
	await process_frame
	var 弹 := _取消息弹(窗)
	if 弹 == null:
		_失败.append("点「自动提升」没弹二次确认（原版 `autoTiShengHandler:75` 走 FamillyPopUpWindow）")
	else:
		var 正文 := 弹.find_child("正文", true, false) as RichTextLabel
		var 主体 := 弹.find_child("主体", true, false) as Control
		for 句 in ["你确定自动使用已有查克拉精华提升结印境界",
				"当遇到以下情况时，系统会停止自动提升操作",
				"剩余的查克拉精华小于1000",
				"结印阶段成功的提升到了下一层",
				"尝试手动提升操作或点击停止提升按钮"]:
			if 正文 == null or not 正文.text.contains(String(句)):
				_失败.append("二次确认正文缺原版那一句「%s」（JIEYIN_AUTO_TISHENG_PROMPT）" % 句)
		# **五行**必须真开出五行的高度：修前 `弹消息` 写死一行 ⇒ 正文高 0、整窗 87，
		# 两枚按钮 y=52 落在文字中间。
		if 正文 == null or 正文.size.y < 15.0 * 5.0:
			_失败.append("正文只按一行开高（实测 %s），五行文字没地方站 —— 高必须按行数算"
				% ["无正文" if 正文 == null else str(正文.size.y)])
		elif 主体 == null or not is_equal_approx(主体.size.y, 正文.position.y + 正文.size.y + 50.0):
			_失败.append("窗高该跟着正文底走（正文 y + 正文高 + 底高 50），实测主体 %s、正文底 %s"
				% [str(主体.size.y), str(正文.position.y + 正文.size.y)])
		elif 主体.get_node_or_null("确定") != null \
				and (主体.get_node_or_null("确定") as Button).position.y < 正文.position.y + 正文.size.y:
			_失败.append("确定钮压在正文上（钮 y=%s < 正文底 y=%s）"
				% [str((主体.get_node_or_null("确定") as Button).position.y),
					str(正文.position.y + 正文.size.y)])
		# 取消 ⇒ 不进自动态、不发任何包、弹层收掉
		var 取消 := 主体.get_node_or_null("取消") as Button if 主体 != null else null
		if 取消 == null:
			_失败.append("二次确认框里没有「取消」钮")
		else:
			假.结印 = 0
			取消.pressed.emit()
			for 帧 in 3:
				await process_frame
			if bool(窗.get("_结印自动提升")) or 假.结印 != 0:
				_失败.append("点「取消」之后不该进自动态、也不该发包（自动=%s、包=%d）"
					% [str(窗.get("_结印自动提升")), 假.结印])
			if _取消息弹(窗) != null:
				_失败.append("点「取消」之后确认框还挂在遮罩上（没被收起）")
	# 确定 ⇒ 进自动、钮文字换「停止提升」、**立刻**跳第一发
	自动钮 = _结印自动钮(窗)
	if 自动钮 == null:
		_失败.append("⑥ 之后取不到「自动提升按钮」⇒ 确认那一腿没量到")
		窗.set("_backend", null)
		return
	假.结印 = 0
	自动钮.pressed.emit()
	await process_frame
	弹 = _取消息弹(窗)
	if 弹 == null:
		_失败.append("第二次点「自动提升」还是没弹确认框")
		窗.set("_backend", null)
		return
	var 主体二 := 弹.find_child("主体", true, false) as Control
	var 确二 := 主体二.get_node_or_null("确定") as Button if 主体二 != null else null
	if 确二 == null:
		_失败.append("二次确认框里没有「确定」钮")
	else:
		确二.pressed.emit()
		await process_frame
		if not bool(窗.get("_结印自动提升")):
			_失败.append("确认之后该进自动态（`sureToAutoTiSheng`：selected=true、_isAutoTiSheng=true）")
		if 假.结印 != 1:
			_失败.append("确认之后该**立刻**跳第一发 byte 0，实测 %d 发" % 假.结印)
		var 钮二 := _结印自动钮(窗)
		if 钮二 == null:
			_失败.append("自动态下取不到「自动提升按钮」⇒ 文字那一腿没量到")
		elif 钮二.text != "停止提升":
			_失败.append("自动态下钮文字该是「停止提升」（ROUQUAN_STOP_TISHENG），实测「%s」" % 钮二.text)

	# ── ⑥b 结果帧**零提示**：2318 绝不能落进 `_handle_cultivation_text` 那条别族「神符升阶」文案支
	通知.clear()
	后端.call("_handle_bridge_text", "2318:2:0:4")
	await process_frame
	for 一条 in 通知:
		var 句子 := String(一条)
		if 句子.contains("进阶") or 句子.contains("神符") or 句子.contains("恭喜"):
			_失败.append("结印结果帧弹了别族的升阶提示（原版 `onJieYin_eatUpResult` 零提示）：%s" % 句子)

	# ── ⑦ result=0 ⇒ 0.8 秒后**再发一发同一个 byte 0**；result=1（升阶）⇒ 停
	var 起点 := 假.结印
	await _等毫秒(950)
	if 假.结印 != 起点 + 1:
		_失败.append("自动态收到 result=0 该在 0.8 秒后再发一发 byte 0（客户端循环），实测从 %d 到 %d 发"
			% [起点, 假.结印])
	后端.call("_handle_bridge_text", "2318:2:1:4")
	await process_frame
	if bool(窗.get("_结印自动提升")):
		_失败.append("result=1（阶段推到下一层 = 停止条件 2）该停掉自动提升（原版 clearTimeout）")
	var 定格 := 假.结印
	await _等毫秒(1000)
	if 假.结印 != 定格:
		_失败.append("停掉之后不该再补包，实测又多发了 %d 发" % (假.结印 - 定格))
	var 钮三 := _结印自动钮(窗)
	if 钮三 == null:
		_失败.append("⑦ 之后取不到「自动提升按钮」⇒ 文字回退那一腿没量到")
	elif 钮三.text != "自动提升":
		_失败.append("停掉自动后钮文字该换回「自动提升」，实测「%s」" % 钮三.text)

	# ── ⑧ 已经排下去的那一发，点「停止提升」之后**不许补**（AS3 clearTimeout 的等效令牌）
	var 钮四 := _结印自动钮(窗)
	if 钮四 == null:
		_失败.append("⑧ 取不到「自动提升按钮」⇒ 停止那一腿没量到")
		窗.set("_backend", null)
		return
	假.结印 = 0
	钮四.pressed.emit()
	await process_frame
	var 弹四 := _取消息弹(窗)
	if 弹四 == null:
		_失败.append("⑧ 没弹二次确认框")
	else:
		var 主体四 := 弹四.find_child("主体", true, false) as Control
		var 确四 := 主体四.get_node_or_null("确定") as Button if 主体四 != null else null
		if 确四 == null:
			_失败.append("⑧ 确认框里没有「确定」钮")
		else:
			确四.pressed.emit()
			await process_frame
			# 第一发已经跳出去；喂一帧 result=0 ⇒ 排下第二发，然后在 0.8 秒到点**之前**点停止
			后端.call("_handle_bridge_text", "2318:2:0:4")
			await _等毫秒(150)
			var 停止 := _结印自动钮(窗)
			if 停止 == null or 停止.text != "停止提升":
				_失败.append("⑧ 自动态下取不到文字为「停止提升」的那颗钮")
			else:
				var 定格二 := 假.结印
				停止.pressed.emit()
				await process_frame
				await _等毫秒(1100)
				if 假.结印 != 定格二:
					_失败.append("点了「停止提升」，已经排下去的那一发还是补了出去（`_排结印下一跳` 的令牌比对没生效）")

	# ── ⑧b 点了停止**又马上**重开 ⇒ 上一轮排下去的那一发不该跟着补
	#     （`停结印自动()` 只把 `_结印自动提升` 置 false，光靠这个判据拦不住重开后的旧定时器）
	var 钮六 := _结印自动钮(窗)
	if 钮六 == null:
		_失败.append("⑧b 取不到「自动提升按钮」⇒ 停止后重开那一腿没量到")
	else:
		钮六.pressed.emit()
		await process_frame
		var 主体六 := _取弹主体(窗)
		if 主体六 == null:
			_失败.append("⑧b 没弹二次确认框")
		else:
			var 定格四 := 假.结印
			(主体六.get_node_or_null("确定") as Button).pressed.emit()	# 第 1 发
			await process_frame
			后端.call("_handle_bridge_text", "2318:2:0:4")				# 排下 T1
			await _等毫秒(80)
			var 停止二 := _结印自动钮(窗)
			if 停止二 == null:
				_失败.append("⑧b 自动态下取不到「停止提升」钮")
			else:
				停止二.pressed.emit()			# 停：T1 还在飞
				await process_frame
				var 再开 := _结印自动钮(窗)
				if 再开 == null:
					_失败.append("⑧b 停止后取不到「自动提升」钮 ⇒ 重开那一腿没量到")
				else:
					再开.pressed.emit()
					await process_frame
					var 主体七 := _取弹主体(窗)
					var 确七 := 主体七.get_node_or_null("确定") as Button if 主体七 != null else null
					if 确七 == null:
						_失败.append("⑧b 停止后没能重新弹出带「确定」的确认框")
					else:
						确七.pressed.emit()	# 第 2 发
					await process_frame
					后端.call("_handle_bridge_text", "2318:2:0:4")				# 排下 T2
					await _等毫秒(1200)
					# 期望：第 1 发 + 第 2 发 + T2 = 3 发；T1 必须被令牌吃掉
					if 假.结印 != 定格四 + 3:
						_失败.append("停止后立刻重开，上一轮排下去的那一发补了出来：期望 %d 发、实测 %d 发"
							% [定格四 + 3, 假.结印])
					# 收个尾：这一腿跑完是**自动态**，⑨ 要从「非自动」起手才有二次确认框可点
					var 收尾 := _结印自动钮(窗)
					if 收尾 != null and 收尾.text == "停止提升":
						收尾.pressed.emit()
						await process_frame

	# ── ⑨ 关窗 = 停（原版 `destroy()` 就一句 clearTimeOut）
	var 钮五 := _结印自动钮(窗)
	if 钮五 == null:
		_失败.append("⑨ 取不到「自动提升按钮」⇒ 关窗那一腿没量到")
	else:
		钮五.pressed.emit()
		await process_frame
		var 弹五 := _取消息弹(窗)
		if 弹五 == null:
			_失败.append("⑨ 没弹二次确认框")
		else:
			var 主体五 := 弹五.find_child("主体", true, false) as Control
			var 确五 := 主体五.get_node_or_null("确定") as Button if 主体五 != null else null
			if 确五 == null:
				_失败.append("⑨ 确认框里没有「确定」钮")
			else:
				确五.pressed.emit()
				await process_frame
				if not bool(窗.get("_结印自动提升")):
					_失败.append("⑨ 没能重新进入自动态 ⇒ 关窗那一腿没量到")
				else:
					窗.call("close")
					if bool(窗.get("_结印自动提升")):
						_失败.append("关窗没停掉自动提升（原版关 CharWindow2 连带 destroy() ⇒ clearTimeOut()）")
					if bool(窗.get("_结印弹窗开着")):
						_失败.append("关窗后弹窗开合状态该归零（下次进来是原版那个收起着的初始态）")
					var 定格三 := 假.结印
					await _等毫秒(1000)
					if 假.结印 != 定格三:
						_失败.append("关窗之后延迟到期那一发还在补（实测 +%d 发）" % (假.结印 - 定格三))
	窗.set("_backend", null)


## 结印在**角色**那一组（`子分页组[0] = 人物 / 手里剑 / 结印`）⇒ 主分页 0、子分页 2。
func _去结印页(窗) -> void:
	窗.call("_set_character_main_tab", 0)
	await process_frame
	窗.call("_set_character_sub_tab", 2)
	for 帧 in 4:
		await process_frame


func _结印弹窗(窗) -> Control:
	var 页 := _取页(窗, "结印")
	if 页 == null:
		return null
	return 页.get_node_or_null("提升结印阶数弹窗") as Control


func _结印自动钮(窗) -> Button:
	var 弹窗 := _结印弹窗(窗)
	if 弹窗 == null:
		return null
	return 弹窗.get_node_or_null("自动提升按钮") as Button


## 遮罩上那枚**消息型**确认弹（`输入确认弹.弹消息` 自己打的 meta 标记，同名叠两层也认得出）。
func _取消息弹(窗) -> Control:
	var 遮罩 := 窗.get("_overlay") as Control
	if 遮罩 == null:
		return null
	for 子 in 遮罩.get_children():
		var 件 := 子 as Control
		if 件 != null and String(件.get_meta("mdialog", "")) == "message":
			return 件
	return null


## 消息弹里的「主体」（正文 + 确定/取消 都挂在它下面）。
func _取弹主体(窗) -> Control:
	var 弹 := _取消息弹(窗)
	if 弹 == null:
		return null
	return 弹.find_child("主体", true, false) as Control


## 等**现实时间**：`get_tree().create_timer(0.8)` 用的是真表，而 headless 的
## `process_frame` 跑得飞快 ⇒ 不按时等就永远量不到自动提升的那第二发。
func _等毫秒(毫秒: int) -> void:
	var 起 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - 起 < 毫秒:
		await process_frame


## 三族二次确认正文里**必须有**的三句（逐字抄 `en_US$message_properties.as`：
## `ROUQUAN_AUTO_TISHENG_PROMPT`:528 / `LUNHUIYAN_AUTO_TISHENG_PROMPT`:994 /
## `TISHENG_TONGSHU_WINDOW_ZIDONGTISHENG_SAY`:2129）。
## ⚠️ 门里**故意再抄一遍**、不去 preload `升阶文案.gd`：两边各抄各的才叫对照
##   （同上面 `_提升表配置` 不复用 `人物窗口.提升配置` 的理由）。
const 确认关键句 := {
	"写轮眼": ["你确定自动使用背包中的写轮眼灵符提升写轮眼境界？",
		"2 写轮眼阶段成功的提升到了下一层",
		"在写轮眼4阶以后，若背包中有写轮眼神符"],
	"柔拳": ["你确定自动使用背包中的柔拳灵符提升瞳术境界？",
		"2 柔拳阶段成功的提升到了下一层",
		"在柔拳4阶以后，若背包中有柔拳神符"],
	"轮回六道": ["你确定自动使用背包中的轮回灵符提升轮回六道境界？",
		"2 轮回六道成功提升到下一阶段",
		"在轮回六道4阶以后，若背包中有轮回神符"],
}

## 不够那两句：`*_TISHENG_PROMPT`（自动中途）与 `CHONG_MAI_WINDOW_SORRY_WUPIN_BUGOU` /
## `EQUIP_STRENGTH_FAIL_PROMPT_2_1`（手动 + 点自动时就不够）。`%1/%2` 用 `.replace` 填
## （§3.205：GDScript 的 `%` 只认格式符，`"…%1不够" % 名` 直接报错）。
const 手动不够期望 := {
	"写轮眼": "很抱歉，你的背包中没有足够的%1！",
	"柔拳": "很抱歉，你的%1不够",
	"轮回六道": "很抱歉，你的%1不够",
}
const 自动不够期望 := {
	"写轮眼": "背包内%1数量不足：你的背包内没有足够数量的【%2】，已停止自动提升。",
	"柔拳": "您的背包内没有足够数量的【%1】，已停止自动提升",
	"轮回六道": "您的背包内没有足够数量的【%1】，已停止自动提升",
}


## 刷完页面等几帧（他的页面脚本在 `_ready` 里自己接按钮，慢一帧才挂得上）。
func _重建并等(窗) -> void:
	窗.call("_refresh_current")
	for 帧 in 4:
		await process_frame


func _去族页(窗, 项: Array) -> void:
	窗.call("_set_character_main_tab", int(项[1]))
	await process_frame
	窗.call("_set_character_sub_tab", int(项[2]))
	for 帧 in 4:
		await process_frame


## ⚠️ 每次重建之后都得**重新取**：`_render_page` 把整页 free 掉重烘，旧按钮是已释放实例。
func _族弹窗(窗, 项: Array) -> Control:
	var 页 := _取页(窗, String(项[0]))
	if 页 == null:
		return null
	return 页.get_node_or_null(String(项[4])) as Control


func _族钮(窗, 项: Array, 钮名: String) -> Button:
	var 弹窗 := _族弹窗(窗, 项)
	if 弹窗 == null:
		return null
	return 弹窗.get_node_or_null(钮名) as Button


func _开族弹窗(窗, 项: Array) -> void:
	var 页 := _取页(窗, String(项[0]))
	if 页 == null:
		return
	var 入口 := 页.get_node_or_null(String(项[3])) as Button
	if 入口 != null:
		入口.pressed.emit()
		await process_frame


## 掏掉这一族的灵符与神符（别的 leg 的道具不动；`_背包数量` 按 id 求和，两摞也算）。
func _清族道具(会话, 编号们: Array) -> void:
	for 序 in range((会话.inventory as Array).size() - 1, -1, -1):
		var 件 := 会话.inventory[序] as Dictionary
		if 件 != null and int(件.get("id", 0)) in 编号们:
			会话.inventory.remove_at(序)


## 「进自动 → 喂 result=0 排下一发 → 到点前点停止 → 立刻重开 → 再喂一发排第二台」整条走完，
## 返回是否一路走通（走不通时 `_失败` 里已经写了原因）。期望发数 = 3。
func _进重开自动(窗, 项: Array, 后端, 假, 码: int, 毫秒: int) -> bool:
	var 族 := String(项[0])
	if not await _进族自动(窗, 项):
		_失败.append("⑪ %s 7b 第一次进自动失败" % 族)
		return false
	后端.call("_handle_bridge_text", "%d:2:0:false" % 码)		# 排下 T1
	await _等毫秒(80)
	var 停 := _族钮(窗, 项, "自动提升按钮")
	if 停 == null or 停.text != "停止提升":
		_失败.append("⑪ %s 7b 自动态下取不到文字为「停止提升」的那颗钮" % 族)
		return false
	停.pressed.emit()
	await process_frame
	if not await _进族自动(窗, 项):
		_失败.append("⑪ %s 7b 停止后没能立刻重开自动（确认框那一路走不通）" % 族)
		return false
	后端.call("_handle_bridge_text", "%d:2:0:false" % 码)		# 排下 T2
	await _等毫秒(毫秒 + 400)
	return true


## 点「自动提升」→ 确认框点「确定」走到底 ⇒ 返回**进没进自动态**。
func _进族自动(窗, 项: Array) -> bool:
	var 钮 := _族钮(窗, 项, "自动提升按钮")
	if 钮 == null:
		return false
	钮.pressed.emit()
	await process_frame
	var 主体 := _取弹主体(窗)
	if 主体 == null:
		return false
	var 确 := 主体.get_node_or_null("确定") as Button
	if 确 == null:
		return false
	确.pressed.emit()
	await process_frame
	return bool(窗.call("族自动中", String(项[0])))


## ── ⑪ 三族「自动提升」（2026-10-18 三面板巡检 #13 = 结印 #12 那套管线的推广）
##
## 原版三族的循环**长得一样但不同文件**，逐条对齐的出处：
##   · 柔拳 `RouQuanTiShengWindow.as`：`autoTiShengHandler:83-102`（不够只提示、够才弹确认）
##     / `sureToAutoTiSheng`（换钮文字 + 立刻一跳）/ `:62-67`（结果帧：成功 clearTimeout、
##     失败 `setTimeout(…, 800)`）/ `tiShengHandler:267-271`（手动那一跳先停自动）；
##   · 轮回 `LunHuiYanTiShengWindow.as`：同一套，间隔 800（`:201`），成功**还顺手 closeWindow**（`:196`）；
##   · 写轮眼 `TishengTongshuPanel.as` + `TongshuSource.as`：确认在 `onClickZidongBtn:255-276`，
##     循环挂在**管理器**上（`TongshuSource:61-86`），间隔 **1000**（`:71`），
##     成功那句 addNotice 之后 `onCloseBtnClick(null)`（`:78`）把提升面板关掉。
##
## 每一族九步，步与步互不掩盖：
##  1 弹窗进页收着；开 → 整页重建后**还亮着、且不重播滑入**；关 → 重建后收回；
##  2 灵符神符都不够 ⇒ 一句「不够」，**连确认都不弹**、零发包、不进自动；
##  3 够了 ⇒ 弹原版二次确认（正文按真实行数开高、钮不压字）；取消 ⇒ 什么都不做；
##  4 确定 ⇒ 进自动 + **立刻**跳第一发 + 钮文字换「停止提升」；
##  5 喂 `opcode:2:0:false` ⇒ 间隔-150ms 不许有第二发、间隔+150ms 必须恰好多一发（钉 800 vs 1000）；
##  6 喂成功帧 ⇒ 停 + 文字回退 + **分族**关弹窗；
##  7 重进自动后点「开始提升」⇒ 自动态立刻没、只多发手动那一发、排下去的那发被令牌吃掉；
##  8 自动中途掏空背包 ⇒ 到点那一跳走「不够」支：发那句 + 停；
##  9 满阶 ⇒ 下一级无配置 ⇒ 开始/自动两枚钮都 disabled。
## ⑩ 收尾（循环外）：三族**同时**挂着待发的定时器 ⇒ `close()` 一下全停、开合标记清零。
## ⚠️ 排在结印那串**之后**、开头先重新 `打开`：`_排族下一跳` 的三道闸里有 `已打开()`。
func _验族自动提升(窗, 会话, 后端, 管理) -> void:
	var 假 := 假后端.new()
	窗.set("_backend", 假)
	var 通知: Array = []
	会话.notification_requested.connect(func(文: String) -> void: 通知.append(文))
	var 原背包: Array = (会话.inventory as Array).duplicate(true)
	管理.call("打开", "人物")
	for 帧 in 4:
		await process_frame
	var 物品表 := _读磁盘表("物品")

	for 项: Array in 自动族腿:
		var 族 := String(项[0])
		var 族表 := String(项[5])
		var 码 := int(项[6])
		var 毫秒 := int(项[7])
		var 成功关窗 := bool(项[8])
		var 起始阶 := int(项[9])
		var 配置 := _提升表配置(族表, 起始阶 + 1)
		var 灵符 := int(配置.get("needItemId", 0))
		var 神符 := int(配置.get("fakeItemId", 0))
		var 需要数 := int(配置.get("needItemCnt", 0))
		var 灵符名 := _表名(物品表, 灵符)
		if 配置.is_empty() or 灵符 <= 0:
			_失败.append("⑪ %s 的 stage%d 没有 stageUp ⇒ 这一族没法对照" % [族, 起始阶 + 1])
			continue
		会话.cultivation_states[族] = {"stage": 起始阶, "count": 3, "blessing": 0}
		_清族道具(会话, [灵符, 神符])
		await _去族页(窗, 项)

		# ── 1 弹窗跨整页重建保持（自动提升每 0.8/1.0 秒重建一次页面 ⇒ 这条就是"会不会闪"）
		var 弹窗 := _族弹窗(窗, 项)
		var 页 := _取页(窗, 族)
		if 弹窗 == null or 页 == null:
			_失败.append("⑪ %s 取不到提升弹窗或页面 ⇒ 这一族没量到" % 族)
			continue
		if 弹窗.visible or 弹窗.position != Vector2(5.0, 228.0):
			_失败.append("⑪ %s 刚进页弹窗该收着、烘在 (5,228)，实测 visible=%s、位置 %s"
				% [族, str(弹窗.visible), str(弹窗.position)])
		var 入口 := 页.get_node_or_null(String(项[3])) as Button
		if 入口 == null or 入口.pressed.get_connections().size() < 2:
			_失败.append("⑪ %s 的入口钮该有两条触发（他场景 open_popup + 宿主记开合），实测 %s"
				% [族, "无按钮" if 入口 == null else "%d 条" % 入口.pressed.get_connections().size()])
			continue
		入口.pressed.emit()
		await process_frame
		await _重建并等(窗)
		var 弹窗2 := _族弹窗(窗, 项)
		if 弹窗2 == null:
			_失败.append("⑪ %s 重建后取不到弹窗 ⇒ 保持那一腿没量到" % 族)
			continue
		if not 弹窗2.visible:
			_失败.append("⑪ %s 刷新一次弹窗就闪没了（`_族弹窗开着` 没记在窗口上 / 重建时没补 visible）" % 族)
		elif 弹窗2.position != Vector2(5.0, 228.0):
			_失败.append("⑪ %s 重建后该**直接落回展开位**、不重播滑入，期望 (5,228)，实测 %s"
				% [族, str(弹窗2.position)])
		var 关 := 弹窗2.get_node_or_null("关闭按钮") as Button
		if 关 == null or 关.pressed.get_connections().size() < 2:
			_失败.append("⑪ %s 弹窗的「关闭按钮」缺接线（他场景一条 + 宿主记状态一条）" % 族)
			continue
		关.pressed.emit()
		await process_frame
		await _重建并等(窗)
		var 弹窗3 := _族弹窗(窗, 项)
		if 弹窗3 == null:
			_失败.append("⑪ %s 关闭后重建取不到弹窗" % 族)
			continue
		if 弹窗3.visible:
			_失败.append("⑪ %s 点了关闭、重建之后弹窗还亮着（`_族弹窗开着` 没跟着清）" % 族)

		# ── 2 空背包点自动 ⇒ 只一句「不够」，零发包、不弹确认、不进自动
		var 自动钮 := _族钮(窗, 项, "自动提升按钮")
		if 自动钮 == null or 自动钮.pressed.get_connections().is_empty():
			_失败.append("⑪ %s 的「自动提升按钮」没接线（点了不会有反应）" % 族)
			continue
		if 自动钮.text != "自动提升":
			_失败.append("⑪ %s 没进自动态时钮文字该是「自动提升」，实测「%s」" % [族, 自动钮.text])
		if 自动钮.disabled:
			_失败.append("⑪ %s 在 %d 阶（离满阶还远）自动钮不该置灰" % [族, 起始阶])
		通知.clear()
		假.升阶 = {}
		自动钮.pressed.emit()
		await process_frame
		if _取消息弹(窗) != null:
			_失败.append("⑪ %s 道具不够时不该弹二次确认（原版 `autoTiShengHandler` 先判 `canTiSheng`，不够直接 addNotice 走人）" % 族)
		if 假.计(族) != 0 or bool(窗.call("族自动中", 族)):
			_失败.append("⑪ %s 不够那一支不该发包、也不该进自动态（实测 %d 发）" % [族, 假.计(族)])
		var 不够句 := String(手动不够期望.get(族, "")).replace("%1", 灵符名).replace("%2", 灵符名)
		if 通知.find(不够句) < 0:
			_失败.append("⑪ %s 不够时该提示「%s」，实测 %s" % [族, 不够句, str(通知)])

		# ── 3 灌够 ⇒ 弹原版确认；取消 ⇒ 什么都不做
		会话.inventory.append({"id": str(灵符), "quantity": 需要数})
		await _重建并等(窗)
		通知.clear()
		自动钮 = _族钮(窗, 项, "自动提升按钮")
		if 自动钮 == null:
			_失败.append("⑪ %s 灌够之后取不到自动钮 ⇒ 确认那一腿没量到" % 族)
			continue
		自动钮.pressed.emit()
		await process_frame
		var 弹 := _取消息弹(窗)
		if 弹 == null:
			_失败.append("⑪ %s 道具够了点自动却没弹二次确认（原版 `FamillyPopUpWindow.popUpWindow`）" % 族)
		else:
			var 正文 := 弹.find_child("正文", true, false) as RichTextLabel
			for 句 in (确认关键句.get(族, []) as Array):
				if 正文 == null or not 正文.text.contains(String(句)):
					_失败.append("⑪ %s 的确认正文缺原版那一句「%s」" % [族, String(句)])
			# 六行文字必须真开出六行的位置：`弹消息` 写死一行 ⇒ 钮压在字上（结印 #12 的教训）
			if 正文 == null or 正文.size.y < 15.0 * 5.0:
				_失败.append("⑪ %s 确认正文只按一行开高（实测 %s）"
					% [族, "无正文" if 正文 == null else str(正文.size.y)])
			var 主体 := _取弹主体(窗)
			var 确: Button = null
			var 取: Button = null
			if 主体 != null:
				确 = 主体.get_node_or_null("确定") as Button
				取 = 主体.get_node_or_null("取消") as Button
			if 确 == null or 取 == null:
				_失败.append("⑪ %s 的确认框里缺「确定 / 取消」" % 族)
			elif 正文 != null and 确.position.y < 正文.position.y + 正文.size.y:
				_失败.append("⑪ %s 确定钮压在正文上（钮 y=%s < 正文底 y=%s）"
					% [族, str(确.position.y), str(正文.position.y + 正文.size.y)])
			else:
				假.升阶 = {}
				取.pressed.emit()
				for 帧 in 3:
					await process_frame
				if bool(窗.call("族自动中", 族)) or 假.计(族) != 0:
					_失败.append("⑪ %s 点了「取消」还进了自动态或发了包（自动=%s、%d 发）"
						% [族, str(bool(窗.call("族自动中", 族))), 假.计(族)])
				if _取消息弹(窗) != null:
					_失败.append("⑪ %s 点了「取消」确认框还挂在遮罩上" % 族)

		# ── 4 确定 ⇒ 进自动 + 立刻一发 + 文字换「停止提升」
		var 进了四 := await _进族自动(窗, 项)
		if not 进了四:
			_失败.append("⑪ %s 确认之后没进自动态，或进完立刻那一发没跳出去" % 族)
			continue
		if 假.计(族) != 1:
			_失败.append("⑪ %s 确认之后该**立刻**跳第一发，实测 %d 发" % [族, 假.计(族)])
		var 钮二 := _族钮(窗, 项, "自动提升按钮")
		if 钮二 == null:
			_失败.append("⑪ %s 自动态下取不到自动钮 ⇒ 文字那一腿没量到" % 族)
			continue
		if 钮二.text != "停止提升":
			_失败.append("⑪ %s 自动态下钮文字该是「停止提升」（ROUQUAN_STOP_TISHENG），实测「%s」"
				% [族, 钮二.text])

		# ── 5 间隔：800 / 写轮眼 1000（差集就靠这两刀钉死）
		#    先喂一帧 result=0（没升阶）⇒ 这才是要重发的那一发；⚠️ 喂帧会让会话转
		#    `skills_changed` ⇒ `_refresh_current` 把整页重烘 ⇒ 手里所有节点引用当场作废，
		#    所以这一步之后每次点钮都得**重新取**（结印那条腿从头到尾都是这么写的）。
		后端.call("_handle_bridge_text", "%d:2:0:false" % 码)
		await _等毫秒(毫秒 - 150)
		if 假.计(族) != 1:
			_失败.append("⑪ %s 在 %d 毫秒之内就补了第二发（实测 %d 发）⇒ 间隔写短了" % [族, 毫秒 - 150, 假.计(族)])
		await _等毫秒(300)
		if 假.计(族) != 2:
			_失败.append("⑪ %s 结果帧 result=0 之后该在 %d 毫秒后重发同一发（客户端循环），实测到 %d 发"
				% [族, 毫秒, 假.计(族)])

		# ── 6 成功帧 ⇒ 停 + 文字回退 + 分族关弹窗
		await _开族弹窗(窗, 项)
		await _等毫秒(200)
		后端.call("_handle_bridge_text", "%d:2:1:false" % 码)
		for 帧 in 3:
			await process_frame
		if bool(窗.call("族自动中", 族)):
			_失败.append("⑪ %s 升阶成功该停自动（原版成功那一支 clearTimeout）" % 族)
		var 定格 := 假.计(族)
		await _等毫秒(毫秒 + 300)
		if 假.计(族) != 定格:
			_失败.append("⑪ %s 停掉之后不该再补包，实测又多发 %d 发" % [族, 假.计(族) - 定格])
		var 钮三 := _族钮(窗, 项, "自动提升按钮")
		if 钮三 != null and 钮三.text != "自动提升":
			_失败.append("⑪ %s 停掉自动后钮文字该换回「自动提升」，实测「%s」" % [族, 钮三.text])
		var 弹窗4 := _族弹窗(窗, 项)
		if 弹窗4 == null:
			_失败.append("⑪ %s 成功帧之后取不到弹窗 ⇒ 关窗那一腿没量到" % 族)
		elif 弹窗4.visible == 成功关窗:
			var 期望 := "被顺手关掉" if 成功关窗 else "留着"
			_失败.append("⑪ %s 升阶成功时弹窗该%s（写轮眼 `TongshuSource:78 onCloseBtnClick`、轮回 `LunHuiYanTiShengWindow:196 closeWindowHandler` 关，柔拳 `:62` 只 clearTimeout）"
				% [族, 期望])

		# ── 7 手动那一跳 = 先停自动再发一发，**已排下去的那发不许补**
		var 进了七 := await _进族自动(窗, 项)
		if not 进了七:
			_失败.append("⑪ %s 第二次进自动失败 ⇒ 手动那一腿没量到" % 族)
			continue
		var 起点 := 假.计(族)
		# 先喂一帧 result=0 ⇒ 排下 T1（还没到点），再点手动：T1 必须被令牌吃掉。
		# ⚠️ 喂帧会连带重烘整页 ⇒ 钮要在等完之后**重新取**。
		后端.call("_handle_bridge_text", "%d:2:0:false" % 码)
		await _等毫秒(150)
		var 开始 := _族钮(窗, 项, "开始提升按钮")
		if 开始 == null or 开始.pressed.get_connections().is_empty():
			_失败.append("⑪ %s 的「开始提升按钮」没接线" % 族)
			continue
		开始.pressed.emit()
		await process_frame
		if bool(窗.call("族自动中", 族)):
			_失败.append("⑪ %s 点「开始提升」该先把自动态摘掉（确认正文里的停止条件 3）" % 族)
		if 假.计(族) != 起点 + 1:
			_失败.append("⑪ %s 手动那一跳该发**一发**，实测从 %d 到 %d 发" % [族, 起点, 假.计(族)])
		await _等毫秒(毫秒 + 300)
		if 假.计(族) != 起点 + 1:
			_失败.append("⑪ %s 手动停掉之后，已经排下去的那一发还是补了出去（`_排族下一跳` 的令牌比对没生效）" % 族)

		# ── 7b 点了「停止提升」**又马上**重开 ⇒ 上一轮排下去的那一发不该跟着补
		#      （光靠 `族自动中` 判拦不住重开后的旧定时器：那时它又变回 true 了。
		#       删掉 `_排族下一跳` 里的 `_族自动计时.get(族) != 计` ⇒ 这一腿点名多发的那 1 发。）
		var 起点七 := 假.计(族)
		var 走了七b := await _进重开自动(窗, 项, 后端, 假, 码, 毫秒)
		if 走了七b:
			if 假.计(族) != 起点七 + 3:
				_失败.append("⑪ %s 停止后立刻重开，上一轮排下去的那一发补了出来：期望 %d 发、实测 %d 发"
					% [族, 起点七 + 3, 假.计(族)])
			# 7b 跑完是**自动态**（T2 那发已跳出去），⑧ 要从非自动起手才谈得上"进自动"
			窗.call("停族自动", 族)

		# ── 8 自动中途掏空背包 ⇒ 走「不够」支：那句提示 + 停
		var 进了八 := await _进族自动(窗, 项)
		if not 进了八:
			_失败.append("⑪ %s 第三次进自动失败 ⇒ 中途不够那一腿没量到" % 族)
			continue
		var 起点二 := 假.计(族)
		后端.call("_handle_bridge_text", "%d:2:0:false" % 码)
		_清族道具(会话, [灵符, 神符])
		await _等毫秒(毫秒 + 300)
		if bool(窗.call("族自动中", 族)):
			_失败.append("⑪ %s 自动中途道具用光该停（停止条件 1：背包内剩余的提升道具已使用完毕）" % 族)
		if 假.计(族) != 起点二:
			_失败.append("⑪ %s 不够那一支不该发包，实测从 %d 到 %d 发" % [族, 起点二, 假.计(族)])
		var 那句 := String(自动不够期望.get(族, "")).replace("%1", 灵符名).replace("%2", 灵符名)
		if 通知.find(那句) < 0:
			_失败.append("⑪ %s 中途不够该提示「%s」，实测 %s" % [族, 那句, str(通知)])
		会话.inventory.append({"id": str(灵符), "quantity": 需要数})

		# ── 9 满阶（stage = 表里最高阶 ⇒ 下一级没有配置）⇒ 两枚钮都 disabled
		会话.cultivation_states[族] = {"stage": _表最高阶(族表), "count": 0, "blessing": 0}
		await _重建并等(窗)
		var 开始满 := _族钮(窗, 项, "开始提升按钮")
		var 自动满 := _族钮(窗, 项, "自动提升按钮")
		if 开始满 == null or 自动满 == null:
			_失败.append("⑪ %s 满阶那一腿取不到钮" % 族)
		else:
			if not 开始满.disabled:
				_失败.append("⑪ %s 满阶时「开始提升」该置灰（原版 `!_cfg` / canTiSheng=false）" % 族)
			if not 自动满.disabled:
				_失败.append("⑪ %s 满阶时「自动提升」也该置灰 —— 不然玩家会以为能自动冲阶" % 族)
			# 9b 置灰只是**表象**，`emit()` 绕过它照样能打到处理函数 ⇒ 再钉一层"一句 return"：
			#   原版满阶 `canTiSheng=false` / `!_cfg`，点下去既不发包也不提示（`RouQuanManager:167-170`）。
			通知.clear()
			var 满阶起点 := 假.计(族)
			开始满.pressed.emit()
			自动满.pressed.emit()
			await process_frame
			if 假.计(族) != 满阶起点:
				_失败.append("⑪ %s 满阶还发了 %d 包（下一级没有配置 ⇒ `族一跳` 该先 return）"
					% [族, 假.计(族) - 满阶起点])
			if not 通知.is_empty() or _取消息弹(窗) != null:
				_失败.append("⑪ %s 满阶点两枚钮该**一声不响**（不发也不提示也不弹确认），实测通知 %s"
					% [族, str(通知)])
		会话.cultivation_states[族] = {"stage": 起始阶, "count": 3, "blessing": 0}
		await _重建并等(窗)

	# ── ⑩ 三族**同时**挂着待发的定时器 ⇒ 关窗一下全停（原版 destroy() 就一句 clearTimeOut）
	通知.clear()
	for 项2: Array in 自动族腿:
		var 族2 := String(项2[0])
		await _去族页(窗, 项2)
		await _开族弹窗(窗, 项2)
		var 进了十 := await _进族自动(窗, 项2)
		if not 进了十:
			_失败.append("⑩ 关窗那一腿：%s 没能进自动态" % 族2)
			continue
		后端.call("_handle_bridge_text", "%d:2:0:false" % int(项2[6]))
	var 定格九 := {}
	for 项3: Array in 自动族腿:
		定格九[String(项3[0])] = 假.计(String(项3[0]))
	窗.call("close")
	var 开着: Dictionary = 窗.get("_族弹窗开着")
	for 项4: Array in 自动族腿:
		var 族4 := String(项4[0])
		if bool(窗.call("族自动中", 族4)):
			_失败.append("⑩ 关窗没停掉 %s 的自动提升（`close()` 里要逐族 `停族自动`）" % 族4)
		if bool(开着.get(族4, false)):
			_失败.append("⑩ 关窗后 %s 的弹窗开合标记该归零（下次进来是原版那个收起着的初始态）" % 族4)
	await _等毫秒(1400)
	for 项5: Array in 自动族腿:
		var 族5 := String(项5[0])
		if 假.计(族5) != int(定格九.get(族5, 0)):
			_失败.append("⑩ 关窗之后延迟到期的那几发还在补（%s +%d 发）"
				% [族5, 假.计(族5) - int(定格九.get(族5, 0))])
	# 还原：背包、三族阶段、假后端（后面已经没有腿了，但别把脏状态留给下一次的 _跑）
	会话.inventory.clear()
	for 件2 in 原背包:
		会话.inventory.append(件2)
	窗.set("_backend", null)


## 假后端：只收不连（用来**看请求里到底带了什么**）。
class 假后端:
	extends Node
	var in_game := true
	var 收到: Array = []
	var 八门: Array = []
	var 结印 := 0

	func request_kunchong_strength(位置: int, 用镇灵石: bool, 张数: int) -> bool:
		收到.append([位置, 用镇灵石, 张数])
		return true

	func request_bamen(动作: int, 门序号 := 0, 穴位下标 := 0, 铜人数 := 0) -> bool:
		八门.append([动作, 门序号, 穴位下标, 铜人数])
		return true

	# 结印**只有这一个**上行方法：byte 0 = `requestJieYin_EatUp`。原来这里还有
	# `request_jieyin(自动)` + `request_jieyin_state()`（发 `2318:2`）—— 原版那条动作号
	# 是**下行**的结果帧，上行发出去永远无回帧（空枪），已删。
	func request_jieyin() -> bool:
		结印 += 1
		return true

	# 「购买」那一跳的上行 = 1086，**只有一个字段 = 物品 id**（`后端连接.gd:1253-1260`；
	# 多发一个 shop_type 会让服务端 fields[0] 变成 0、不回 1079）。记**数组**才量得出
	# "一次点击发几发" —— 连接堆叠（每渲染多挂一根）就表现为这里一次点击进 N 条。
	var 商城: Array = []

	func request_cash_item_info(物品号: int, _店型 := 0) -> bool:
		商城.append(物品号)
		return true

	# 三族升阶上行**没有参数**（`RouQuanTiShengWindow:130`、`TongshuSource:88`、
	# `LunHuiYanTiShengWindow:230` 各发一发本族 opcode 的 byte 0），
	# 「自动」只是客户端把同一发重发几遍 ⇒ 计数按族分开记，才能量出"这一发到底是谁发的"。
	var 升阶 := {}

	func 计(族: String) -> int:
		return int(升阶.get(族, 0))

	func _跳(族: String) -> void:
		升阶[族] = int(升阶.get(族, 0)) + 1

	func request_rouquan_stage_up() -> bool:
		_跳("柔拳")
		return true

	func request_xielunyan_stage_up() -> bool:
		_跳("写轮眼")
		return true

	func request_lunhuiyan_stage_up() -> bool:
		_跳("轮回六道")
		return true


## 昆虫强化弹窗的真行为（§3.112）。
func _验昆虫弹窗(窗, 页: Control, 会话) -> void:
	var 弹窗 := 页.get_node_or_null("昆虫强化弹窗") as Control
	if 弹窗 == null:
		_失败.append("寄坏之术页找不到「昆虫强化弹窗」")
		return
	var 提交 := 弹窗.get_node_or_null("开始提升按钮") as Button
	var 放入 := 弹窗.get_node_or_null("底图/放置区底图/开始提升按钮") as Button
	if 提交 == null or 提交.text != "开始强化":
		_失败.append("真提交钮应是「昆虫强化弹窗/开始提升按钮」且文案「开始强化」，实际「%s」"
			% [提交.text if 提交 != null else "无"])
	elif 提交.pressed.get_connections().is_empty():
		_失败.append("「开始强化」没接线（点了不发协议）")
	if 放入 == null:
		_失败.append("找不到「放入昆虫」那枚（底图/放置区底图/开始提升按钮）")

	# 造一只**够格用镇灵石**的寄坏虫（12 + 1 ≥ levelCanUse 11），并把两种材料塞进背包。
	var 槽: int = 装备部位表.昆虫一
	会话.equipped_items[槽] = {"id": "1310001", "name": "测试寄坏虫", "equip_position": 槽,
		"strengthen": 12, "quantity": 1}
	会话.inventory.append({"id": "16000136", "quantity": 3})
	会话.inventory.append({"id": "16000137", "quantity": 9})
	# ⚠️ 钱包：`canStrngthKunChong:499-503` 那道金币闸按**原价** `strength[下一阶].needMoney`
	#   拦（12 星 → 下一阶 13 = 22 万），默认存档未必有这么多 ⇒ 先灌满，
	#   "钱不够"那条单独在 ⑧ 里量（不灌满的话下面每一腿都会被它顶成同一句提示 = 假绿）。
	会话.player_stats["gold"] = 99999999
	var 通知: Array = []
	会话.notification_requested.connect(func(文: String) -> void: 通知.append(文))
	# 开场必须是**没放入**：这一族量的是"点放入之后勾才变亮"，若上一段把宿主留在"已放"，
	# 重绘时勾本来就可点 ⇒ 这条腿量不到「放入当场刷新」那一跳。
	窗._昆虫强化态["放"] = false
	窗.call("_render_page")
	for _序号 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	if 弹窗 == null:
		_失败.append("塞了昆虫之后重渲染，找不到「昆虫强化弹窗」")
		return
	提交 = 弹窗.get_node_or_null("开始提升按钮") as Button
	放入 = 弹窗.get_node_or_null("底图/放置区底图/开始提升按钮") as Button

	var 假 := 假后端.new()
	窗.set("_backend", 假)
	# ① 点「放入昆虫」**不许**发协议（修前正是这里当场发强化请求），但要把虫放进格、按钮换文案
	# ⚠️ 判据取**可见性**，不取"节点在不在" —— 图标是场景里烘好的（一直存在），
	#    只判存在等于没判（正是这一轮在治的那种假绿）。
	var 图标 := 弹窗.get_node_or_null("底图/放置区底图/放置格/昆虫图标") as TextureRect
	if 放入 != null:
		if 放入.text != "放入昆虫":
			_失败.append("开场「放入」钮文案应是「放入昆虫」，实际「%s」" % 放入.text)
		if 图标 != null and 图标.visible:
			_失败.append("开场放置格里不该有昆虫图标")
		放入.pressed.emit()
		await process_frame
		if not 假.收到.is_empty():
			_失败.append("点「放入昆虫」不该发强化请求，实际发了 %s" % [假.收到])
		if 放入.text != "取出昆虫":
			_失败.append("点过「放入昆虫」后文案该换成「取出昆虫」，实际「%s」" % 放入.text)
		if 图标 == null:
			_失败.append("放置格里没有烘好的「昆虫图标」节点")
		elif not 图标.visible:
			_失败.append("点过「放入昆虫」后格子里的昆虫图标该显出来")
	# ② 用镇灵石 + 3 张寄坏玉 ⇒ 请求必须是 [位置, true, 3]
	var 镇勾 := 弹窗.get_node_or_null("底图/强化区底图/使用镇灵石") as CheckBox
	var 玉勾 := 弹窗.get_node_or_null("底图/强化区底图/使用寄坏玉") as CheckBox
	var 下拉 := 弹窗.get_node_or_null("底图/强化区底图/数量下拉") as OptionButton
	if 镇勾 == null or 玉勾 == null or 下拉 == null or 提交 == null:
		_失败.append("昆虫强化弹窗缺 使用镇灵石/使用寄坏玉/数量下拉/提交钮")
		return
	if 镇勾.disabled:
		_失败.append("强化等级 12 时镇灵石该可用（levelCanUse=11 是拿**下一阶**比的）")
	if 下拉.item_count != 9:
		_失败.append("张数下拉应是 `help.maxHelpCnt` 9 项，实际 %d" % 下拉.item_count)
	镇勾.button_pressed = true
	玉勾.button_pressed = true
	下拉.select(2)
	提交.pressed.emit()
	await process_frame
	if 假.收到 != [[槽, true, 3]]:
		_失败.append("「开始强化」该发 [%d, true, 3]，实际 %s" % [槽, 假.收到])
	# ③ 镇灵石不够 ⇒ 只能出提示、一个请求都不发（原版 `KUNCHONG_TIP1`）
	假.收到.clear()
	通知.clear()
	# ⚠️ `会话.inventory` 是**类型化数组**，整份赋值会被 Godot 拒（"Invalid assignment … Array"）
	#    ⇒ 只能原地删。
	for 序 in range(会话.inventory.size() - 1, -1, -1):
		if String((会话.inventory[序] as Dictionary).get("id", "")) == "16000136":
			会话.inventory.remove_at(序)
	提交.pressed.emit()
	await process_frame
	if not 假.收到.is_empty():
		_失败.append("镇灵石不够时不该发请求，实际发了 %s" % [假.收到])
	if not 通知.any(func(文: String) -> bool: return String(文).contains("镇灵石")):
		_失败.append("镇灵石不够应提示「你没有足够的镇灵石」，实际通知 %s" % [通知])

	# ── ④ 材料角标 = **同 id 各摞累加**（原版 `DataCenter.isBagExistItem:3166-3182` 是累加的）。
	#    报修 1.1（徽章打造石恒灰、不带数量）与这里同一条：修前 `装备打造表.拥有数` 只数**第一摞**，
	#    两摞 3+2 会读成 3；而第一摞恰好是 0 时，明明背包里还有 5 颗也照样判"不够"⇒ 恒灰。
	会话.inventory.append({"id": "16000136", "quantity": 3})
	会话.inventory.append({"id": "16000136", "quantity": 2})		# 第二摞 ⇒ 角标该是 5
	窗.call("_render_page")
	for _序号 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	if 弹窗 == null:
		_失败.append("④ 重渲染之后找不到「昆虫强化弹窗」⇒ 后面的腿没量到")
		return
	提交 = 弹窗.get_node_or_null("开始提升按钮") as Button
	var 镇格 := 弹窗.get_node_or_null("底图/强化区底图/镇灵石格") as Control
	var 玉格 := 弹窗.get_node_or_null("底图/强化区底图/寄坏玉格") as Control
	if 镇格 == null or 玉格 == null:
		_失败.append("④ 弹窗里缺「镇灵石格 / 寄坏玉格」")
		return
	var 镇标 := 镇格.get_node_or_null("数量") as Label
	var 玉标 := 玉格.get_node_or_null("数量") as Label
	if 镇标 == null:
		_失败.append("④ 镇灵石格里没有烘好的「数量」角标")
	elif 镇标.text != "5":
		_失败.append("④ 镇灵石角标该是两摞累加的 5，实际「%s」" % 镇标.text)
	if 玉标 == null:
		_失败.append("④ 寄坏玉格里没有烘好的「数量」角标")
	elif 玉标.text != "9":
		_失败.append("④ 寄坏玉角标该是 9，实际「%s」" % 玉标.text)
	# 够 ⇒ 不挂灰；不够 ⇒ **图标与角标**挂灰皮、购买钮**不跟着挂**
	# （`ItemCaiLiaoBox.applyGrayFilter:44-47` 只作用在 `itemCell`，那枚 buyBtn 随时能点）。
	var 镇图 := 镇格.get_node_or_null("镇灵石图标") as CanvasItem
	var 镇买 := 镇格.get_node_or_null("购买按钮") as Button
	if 镇图 == null:
		_失败.append("④ 镇灵石格里取不到图标节点")
	elif 镇图.material != null:
		_失败.append("④ 手里有 5 颗镇灵石，图标不该挂灰皮（报修 1.1 说的「一直是灰的」）")
	if 镇买 != null and 镇买.material != null:
		_失败.append("④ 购买钮跟着灰了 —— 原版只灰物品格，不灰购买钮")
	for 序 in range(会话.inventory.size() - 1, -1, -1):
		if String((会话.inventory[序] as Dictionary).get("id", "")) == "16000136":
			会话.inventory.remove_at(序)
	窗.call("_render_page")
	for _序号 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	if 弹窗 == null:
		_失败.append("④b 清空镇灵石后重渲染找不到弹窗")
		return
	镇格 = 弹窗.get_node_or_null("底图/强化区底图/镇灵石格") as Control
	镇图 = 镇格.get_node_or_null("镇灵石图标") as CanvasItem if 镇格 != null else null
	镇标 = 镇格.get_node_or_null("数量") as Label if 镇格 != null else null
	镇买 = 镇格.get_node_or_null("购买按钮") as Button if 镇格 != null else null
	if 镇标 != null and 镇标.text != "0":
		_失败.append("④b 卖掉镇灵石后角标该归 0，实际「%s」" % 镇标.text)
	if 镇图 != null and 镇图.material == null:
		_失败.append("④b 一颗都没有时图标该挂灰皮")
	if 镇买 != null and 镇买.material != null:
		_失败.append("④b 不够也不该灰购买钮（随时能点去商城买）")

	# ── ⑤ 产物格 + 消耗/几率那两行（`updateView:127` 与 `updateXingYunRatio:452-487`）。
	#    12 星 → 下一阶 13：`needMoney 220000`、`ratio 21`；虫没填资质 ⇒ 因子取 `needMoneyFactor["0"]` = 100。
	# 先把勾选回干净（② 那两下已经写进宿主、④ 重渲染又灌回控件）⇒ 这一腿要的是"什么都没勾"的基线。
	窗._昆虫强化态["玉"] = false
	窗._昆虫强化态["镇"] = false
	窗._昆虫强化态["张"] = 1
	窗.call("_render_page")
	for _序号 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	if 弹窗 == null:
		_失败.append("⑤ 清勾选重渲染后找不到弹窗")
		return
	var 产物 := 弹窗.get_node_or_null("底图/放置区底图/成功格/昆虫图标") as TextureRect
	if 产物 == null:
		_失败.append("⑤ 成功格里没有烘好的「昆虫图标」（产物预览没地方摆）")
	elif not 产物.visible or 产物.texture == null:
		_失败.append("⑤ 有下一阶配置时产物格该亮出下一级虫的图标（报修 1.2「看不到强化产物」同一条）")
	var 富 := 弹窗.get_node_or_null("底图/强化区底图/强化消耗与几率") as RichTextLabel
	if 富 == null:
		_失败.append("⑤ 取不到「强化消耗与几率」（或它不是 RichTextLabel ⇒ 红字出不来）")
	else:
		if not 富.text.contains("本次操作消耗金币：220000") or not 富.text.contains("本次操作成功几率：21%"):
			_失败.append("⑤ 那两行该按 strength[13] 算（22 万 / 21%%），实测「%s」" % 富.text.replace("\n", " / "))
		if 富.text.contains("#ff0000"):
			_失败.append("⑤ 钱包 9999 万，金币那一行不该红")
		镇勾 = 弹窗.get_node_or_null("底图/强化区底图/使用镇灵石") as CheckBox
		玉勾 = 弹窗.get_node_or_null("底图/强化区底图/使用寄坏玉") as CheckBox
		下拉 = 弹窗.get_node_or_null("底图/强化区底图/数量下拉") as OptionButton
		# 勾玉 + **3 张** ⇒ 几率 = min(100, 3×`help.probUp`(3) + 21) = 30。
		# ⚠️ 用 `item_selected.emit` 而不是 `select()`：`select()` 不发信号（原版读的是
		#    `_jhyComboBox.selectedIndex`，我们这边宿主状态只认信号）⇒ 拿它当"玩家点了下拉"= 假绿。
		玉勾.button_pressed = true
		下拉.select(2)
		下拉.item_selected.emit(2)
		if not 富.text.contains("本次操作成功几率：30%"):
			_失败.append("⑤ 勾了 3 张寄坏玉，几率该是 21+3×3=30%%，实测「%s」" % 富.text.replace("\n", " / "))
		if 下拉.disabled:
			_失败.append("⑤ 勾了寄坏玉，张数下拉该可用（原版 `_comboBox.enabled` 跟着勾选走）")
		# 红字：`_loc4_ < cocoNuts ? 原样 : <font color='#ff0000'>` ⇒ **钱不够（≥）才红**。
		会话.player_stats["gold"] = 220000
		玉勾.button_pressed = false
		if not 富.text.contains("[color=#ff0000]220000[/color]"):
			_失败.append("⑤ 刚好不够本时应把金币那行标红，实测「%s」" % 富.text.replace("\n", " / "))
		会话.player_stats["gold"] = 99999999
		玉勾.button_pressed = true
		if 富.text.contains("#ff0000"):
			_失败.append("⑤ 钱够了还红 ⇒ 判据写反了（原版是 `money < cocoNuts` 才不红）")
		玉勾.button_pressed = false

	# ── ⑥ 满级闸（`canStrngthKunChong:495-498`）+ 满级时产物格空、那两行归 0。
	(会话.equipped_items[槽] as Dictionary)["strengthen"] = 19		# 表里 19 阶之上没有键
	窗.call("_render_page")
	for _序号 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	if 弹窗 == null:
		_失败.append("⑥ 满级重渲染后找不到弹窗")
		return
	提交 = 弹窗.get_node_or_null("开始提升按钮") as Button
	产物 = 弹窗.get_node_or_null("底图/放置区底图/成功格/昆虫图标") as TextureRect
	富 = 弹窗.get_node_or_null("底图/强化区底图/强化消耗与几率") as RichTextLabel
	if 产物 != null and 产物.visible:
		_失败.append("⑥ 已经到顶（没有下一阶配置）时产物格该是空的")
	if 富 != null and (not 富.text.contains("消耗金币：0") or not 富.text.contains("成功几率：0%")):
		_失败.append("⑥ 满级时那两行该回到 0（原版没有 `_configInfo` 就写 0），实测「%s」" % 富.text.replace("\n", " / "))
	假.收到.clear()
	通知.clear()
	提交.pressed.emit()
	await process_frame
	if not 假.收到.is_empty():
		_失败.append("⑥ 满级不该发请求，实际发了 %s" % [假.收到])
	if not 通知.any(func(文: String) -> bool: return String(文).contains("已经强化到最顶级")):
		_失败.append("⑥ 满级该提示 KUNCHONG_STRENGTH_TOP_PROMPT「已经强化到最顶级」，实际 %s" % [通知])

	# ── ⑦ 没放虫 ⇒ 「请放入昆虫」（重渲染后放置格是空的，只有宿主记着"放"才回灌）。
	窗._昆虫强化态["放"] = false
	窗._昆虫强化态["镇"] = false
	(会话.equipped_items[槽] as Dictionary)["strengthen"] = 12
	窗.call("_render_page")
	for _序号 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	if 弹窗 == null:
		_失败.append("⑦ 重渲染后找不到弹窗")
		return
	提交 = 弹窗.get_node_or_null("开始提升按钮") as Button
	假.收到.clear()
	通知.clear()
	提交.pressed.emit()
	await process_frame
	if not 假.收到.is_empty():
		_失败.append("⑦ 没放虫不该发请求，实际发了 %s" % [假.收到])
	if not 通知.any(func(文: String) -> bool: return String(文).contains("请放入昆虫")):
		_失败.append("⑦ 没放虫该提示「请放入昆虫」，实际 %s" % [通知])

	# ── ⑧ 金币闸（`canStrngthKunChong:499-503` 比的是**原价** `needMoney`，不是乘过因子的那行）。
	(会话.equipped_items[槽] as Dictionary)["strengthen"] = 18		# 下一阶 19 = 28 万
	会话.player_stats["gold"] = 1000
	窗.call("_render_page")
	for _序号 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	放入 = 弹窗.get_node_or_null("底图/放置区底图/开始提升按钮") as Button if 弹窗 != null else null
	提交 = 弹窗.get_node_or_null("开始提升按钮") as Button if 弹窗 != null else null
	富 = 弹窗.get_node_or_null("底图/强化区底图/强化消耗与几率") as RichTextLabel if 弹窗 != null else null
	if 放入 == null or 提交 == null:
		_失败.append("⑧ 重渲染后取不到弹窗里的钮")
	else:
		放入.pressed.emit()			# 先放虫（否则先撞「请放入昆虫」那道）
		假.收到.clear()
		通知.clear()
		提交.pressed.emit()
		await process_frame
		if not 假.收到.is_empty():
			_失败.append("⑧ 金币不够时不该发请求，实际发了 %s" % [假.收到])
		if not 通知.any(func(文: String) -> bool: return String(文).contains("你的金币不够")):
			_失败.append("⑧ 金币不够该提示 EQUIP_STRENGTH_FAIL_PROMPT_2「很抱歉，你的金币不够」，实际 %s" % [通知])
		# 显示那一行是乘了资质因子的 ⇒ 与拦截用的原价**不是同一个数**（原版就这样），
		# 这里钉的是「面板显示 28 万」（资质缺省 → 因子 100%）；钱不够时它带红皮 ⇒ 只数对得上就行。
		if 富 != null and not 富.text.contains("280000"):
			_失败.append("⑧ 18→19 星那档消耗该显示 28 万，实测「%s」" % 富.text.replace("\n", " / "))
	会话.player_stats["gold"] = 99999999

	# ── ⑨ 回帧那三句（`onStengthResult:561-592`）+ 槽位不符 ⇒ **一句不发**。
	#    ⚠️ 每一发 2066 都会 `_refresh_current()` 重建整页 ⇒ 上一轮的 `提交`/`弹窗` 全成了
	#    **已释放的节点**，必须先重新取一遍再用（直接对旧引用 emit = 报错或假绿）。
	var 真后端: Node = root.get_node_or_null("/root/BackendConnection")
	窗._昆虫强化态["放"] = true
	(会话.equipped_items[槽] as Dictionary)["strengthen"] = 12
	窗.call("_render_page")
	for _序号 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	提交 = 弹窗.get_node_or_null("开始提升按钮") as Button if 弹窗 != null else null
	if 真后端 == null or 提交 == null:
		_失败.append("⑨ 拿不到 BackendConnection 或提交钮 ⇒ 回帧三句没量到")
	else:
		假.收到.clear()
		通知.clear()
		提交.pressed.emit()
		await process_frame
		if 假.收到.is_empty():
			_失败.append("⑨ 这一腿的前置：点「开始强化」该发出一发，实际没发")
		# 成功帧 ⇒ 「强化%1星成功」，`%1` = **发起前**的星级 + 1（原版 `_lastLevel + 1`）
		# ⚠️ 槽位按**服务端真实出帧**写 73：身上四格服务端回的是原版件序 73..76
		#    （`_strengthen_kun_chong` 的 `73 + (KUN_CHONG_A - slot)`），我们自己的装备位是
		#    -200..-203 ⇒ 折回在 `后端连接.gd` 的 2066 解码那一段。这里若只喂 -200，等于
		#    **自己编帧**：真实服务端发 73 时「槽位对不上⇒一句不发」这条缺陷永远照不到
		#    （2026-10-31 用户报的星级不同步 + 自动循环断跳，真机上就是它）。
		真后端.call("_handle_bridge_text", "2066:73:1")
		await process_frame
		if not 通知.any(func(文: String) -> bool: return String(文).contains("强化13星成功")):
			_失败.append("⑨ 12 星成功回来该提示「强化13星成功」，实际 %s" % [通知])
		通知.clear()
		假.收到.clear()
		页 = _取页(窗, "寄坏之术")
		弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
		提交 = 弹窗.get_node_or_null("开始提升按钮") as Button if 弹窗 != null else null
		if 提交 == null:
			_失败.append("⑨ 回帧重建后取不到提交钮 ⇒ 后面三句没量到")
		else:
			提交.pressed.emit()
			await process_frame
			真后端.call("_handle_bridge_text", "2066:%d:0" % 槽)
			await process_frame
			# 旧阶 12 > 7 ⇒ 走 `KUNCHONG_QIANGHUA_FAIL_LEVEL10`（带玩家名），**不是**「强化失败」
			if not 通知.any(func(文: String) -> bool: return String(文).contains("真遗憾，还差一点点就成功了")):
				_失败.append("⑨ 12 星失败该提示「…真遗憾，还差一点点就成功了！」，实际 %s" % [通知])
			通知.clear()
			假.收到.clear()
			# 3 星失败 ⇒ 走 `KUNCHONG_QIANGHUA_FAIL`「强化失败」（那句带名字的只给 8 星以上）
			窗._昆虫强化态["放"] = true
			(会话.equipped_items[槽] as Dictionary)["strengthen"] = 3
			窗.call("_render_page")
			for _序号 in 3:
				await process_frame
			页 = _取页(窗, "寄坏之术")
			弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
			提交 = 弹窗.get_node_or_null("开始提升按钮") as Button if 弹窗 != null else null
			if 提交 == null:
				_失败.append("⑨ 换 3 星后取不到提交钮")
			else:
				提交.pressed.emit()
				await process_frame
				真后端.call("_handle_bridge_text", "2066:%d:0" % 槽)
				await process_frame
				if not 通知.any(func(文: String) -> bool: return String(文) == "强化失败"):
					_失败.append("⑨ 3 星失败该是 `KUNCHONG_QIANGHUA_FAIL`「强化失败」，实际 %s" % [通知])
				# 槽位对不上 ⇒ `onStengthResult:563-567` 默默 `backItemToEquip()`，**一句都不发**
				通知.clear()
				假.收到.clear()
				窗._昆虫强化态["放"] = true
				(会话.equipped_items[槽] as Dictionary)["strengthen"] = 5
				窗.call("_render_page")
				for _序号 in 3:
					await process_frame
				页 = _取页(窗, "寄坏之术")
				弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
				提交 = 弹窗.get_node_or_null("开始提升按钮") as Button if 弹窗 != null else null
				if 提交 == null:
					_失败.append("⑨ 换 5 星后取不到提交钮")
				else:
					提交.pressed.emit()
					await process_frame
					# 74 = 原版件序的昆虫二（折回 -201）；发起的是昆虫一 ⇒ 仍须一句不发，
					# 防「折回」写成「任何 73..76 都当昆虫一」那种一刀切。
					真后端.call("_handle_bridge_text", "2066:74:1")
					await process_frame
					if not 通知.is_empty():
						_失败.append("⑨ 回帧的槽位与发起的不是同一只 ⇒ 原版一句不发，实际 %s" % [通知])

	# ── ⑩ **跨整页重绘保留**：开窗态、格里有虫、两枚勾、张数都得从宿主回灌。
	#    每发回帧都重建整页（`功能窗口._render_page`），弹窗/CheckBox/OptionButton 全是**新节点**
	#    ⇒ 不记不灌的话"点一次看一次闪没"，自动循环更是走一跳就被抹掉勾选（报修 2.1 的表现）。
	窗._昆虫强化态["开"] = true
	窗._昆虫强化态["镇"] = true
	窗._昆虫强化态["玉"] = true
	窗._昆虫强化态["张"] = 4
	窗._昆虫强化态["放"] = true
	窗.call("_render_page")
	for _序号 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	放入 = 弹窗.get_node_or_null("底图/放置区底图/开始提升按钮") as Button if 弹窗 != null else null
	镇勾 = 弹窗.get_node_or_null("底图/强化区底图/使用镇灵石") as CheckBox if 弹窗 != null else null
	玉勾 = 弹窗.get_node_or_null("底图/强化区底图/使用寄坏玉") as CheckBox if 弹窗 != null else null
	下拉 = 弹窗.get_node_or_null("底图/强化区底图/数量下拉") as OptionButton if 弹窗 != null else null
	if 弹窗 == null:
		_失败.append("⑩ 重渲染后找不到弹窗")
		return
	if not 弹窗.visible:
		_失败.append("⑩ 宿主记着「窗开着」，重渲染后弹窗却还是隐藏的 ⇒ 玩家每发回帧看一次闪没")
	if 放入 != null and 放入.text != "取出昆虫":
		_失败.append("⑩ 宿主记着「格里有虫」，重渲染后「放入」钮该是「取出昆虫」，实际「%s」" % 放入.text)
	图标 = 弹窗.get_node_or_null("底图/放置区底图/放置格/昆虫图标") as TextureRect
	if 图标 != null and not 图标.visible:
		_失败.append("⑩ 重渲染后放置格的虫图标该亮着")
	if 玉勾 != null and not 玉勾.button_pressed:
		_失败.append("⑩ 重渲染后寄坏玉勾选被抹掉了")
	if 下拉 != null and 下拉.selected != 3:
		_失败.append("⑩ 重渲染后张数该回灌成第 4 档（下标 3），实际 %d" % [-1 if 下拉 == null else 下拉.selected])
	if 下拉 != null and 下拉.disabled:
		_失败.append("⑩ 勾了寄坏玉，张数下拉该可用")
	# 关窗也要跨重绘：点「关闭」后记着关，别再自己亮回来
	var 关钮 := 弹窗.get_node_or_null("关闭按钮") as Button
	if 关钮 == null:
		_失败.append("⑩ 弹窗里没有「关闭按钮」")
	else:
		关钮.pressed.emit()
		窗.call("_render_page")
		for _序号 in 3:
			await process_frame
		页 = _取页(窗, "寄坏之术")
		弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
		if 弹窗 != null and 弹窗.visible:
			_失败.append("⑩ 点了关闭、重渲染后弹窗又被亮回来了（宿主没记「关」）")
	# 不可用时强制取消：下一阶 < `guarantee.levelCanUse` ⇒ 镇灵石勾禁用且勾选被抹
	(会话.equipped_items[槽] as Dictionary)["strengthen"] = 5
	窗.call("_render_page")
	for _序号 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	镇勾 = 弹窗.get_node_or_null("底图/强化区底图/使用镇灵石") as CheckBox if 弹窗 != null else null
	if 镇勾 == null:
		_失败.append("⑩ 取不到镇灵石勾选")
	else:
		if not 镇勾.disabled:
			_失败.append("⑩ 6 星（下一阶 6 < levelCanUse 11）时镇灵石该禁用")
		if 镇勾.button_pressed:
			_失败.append("⑩ 不可用时原版强制取消勾选（`updateView:109-121`）")

	# ── ⑪ 自动强化循环（`autoQiangHuaHankdler:548-559` + `onStengthResult:580-590`）：
	#    勾上 ⇒ 每发回帧 500ms 后客户端自己再发一跳；成功且旧阶 ≥9 ⇒ 停；前置没过也停。
	窗._昆虫强化态["开"] = true
	窗._昆虫强化态["放"] = true		# ⑪ 量的是"格里有虫"时的自动循环 ⇒ 目标得先放进格（原版 `_itemData` 非空）
	(会话.equipped_items[槽] as Dictionary)["strengthen"] = 8
	窗.call("_render_page")
	for _序号 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	放入 = 弹窗.get_node_or_null("底图/放置区底图/开始提升按钮") as Button if 弹窗 != null else null
	提交 = 弹窗.get_node_or_null("开始提升按钮") as Button if 弹窗 != null else null
	var 自动勾 := 弹窗.get_node_or_null("使用寄坏玉") as CheckBox if 弹窗 != null else null
	if 自动勾 == null:
		_失败.append("⑪ 找不到「自动强化到10并停止」那枚勾（节点名 `昆虫强化弹窗/使用寄坏玉`）")
		return
	if 自动勾.disabled:
		_失败.append("⑪ 格里有虫时自动勾该可用（原版 `_autoCheckBox.enabled = _itemData`）")
	自动勾.button_pressed = true
	假.收到.clear()
	通知.clear()
	窗._昆虫强化自动计时 = null
	提交.pressed.emit()
	await process_frame
	if 假.收到.size() != 1:
		_失败.append("⑪ 手动那一发该只发一跳，实际 %s" % [假.收到])
	真后端.call("_handle_bridge_text", "2066:%d:1" % 槽)		# 旧阶 8 ⇒ 成功、还没到 10 ⇒ 该排下一跳
	await process_frame
	if 窗._昆虫强化自动计时 == null:
		_失败.append("⑪ 勾了自动、回帧后没排下一跳（原版 `setTimeout(strengthHandler, 500)`）")
	# 把虫"抬"到 9 星：强化等级字段是同一个 Dictionary 引用 ⇒ 改了它就等于服务端回了新等级
	(会话.equipped_items[槽] as Dictionary)["strengthen"] = 9
	await create_timer(0.8).timeout
	if 假.收到.size() != 2:
		_失败.append("⑪ 500ms 后客户端该自己再发一跳，实际收了 %s" % [假.收到])
	真后端.call("_handle_bridge_text", "2066:%d:1" % 槽)		# 旧阶 9 且成功 ⇒ 满 10 星 ⇒ 停
	await process_frame
	if bool(窗._昆虫强化态.get("自动", false)):
		_失败.append("⑪ 成功到 10 星后自动态没清（原版 `clearAutoQiangHua`）")
	if 窗._昆虫强化自动计时 != null:
		_失败.append("⑪ 停的时候该把排着的下一跳撤掉")
	假.收到.clear()
	await create_timer(0.8).timeout
	if not 假.收到.is_empty():
		_失败.append("⑪ 停了之后还继续发跳，实际 %s" % [假.收到])
	if not 通知.any(func(文: String) -> bool: return String(文).contains("强化10星成功")):
		_失败.append("⑪ 9 星成功该提示「强化10星成功」，实际 %s" % [通知])
	# 已经 10 星（`strengthen >= 10`）再勾 ⇒ 立刻停 + 原文提示（`KUNCHONG_QIANGHUA_ENOUGH_LEVEL10`）
	# ⚠ 回帧之后整页又重绘过 ⇒ 上面那枚 `弹窗` 早是 freed，勾选要**现找**（本门每一腿都这待遇）。
	通知.clear()
	(会话.equipped_items[槽] as Dictionary)["strengthen"] = 10
	窗._昆虫强化态["放"] = true
	窗.call("_render_page")
	for _序号 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	var 自动勾2 := 弹窗.get_node_or_null("使用寄坏玉") as CheckBox if 弹窗 != null else null
	if 自动勾2 == null:
		_失败.append("⑪ 10 星那一腿取不到自动勾")
		return
	自动勾2.button_pressed = true
	await process_frame
	if not 通知.any(func(文: String) -> bool: return String(文).contains("已经强化到10星了")):
		_失败.append("⑪ 10 星再勾自动该提示「这只昆虫已经强化到10星了！」，实际 %s" % [通知])
	if bool(窗._昆虫强化态.get("自动", false)):
		_失败.append("⑪ 那句提示之后自动态还挂着 ⇒ 下一发回帧又会自己跳一次")

	# ── ⑫ 寄坏玉那一行的几何（2026-10-27 用户报修④「数值框有点过大，右侧都扩展到字体下面了」）。
	# AS3 真值 `KunChongStrengthWindow.as:296-321`：勾 x=125、下拉 x=220（宽 40）、
	# 尾文字 x = 下拉.x + 下拉.width ⇒ **文字贴在下拉右沿之外**，三者互不压。
	# 咱这边 `OptionButton` 的最窄是引擎地板 57（主题盒 25 + 箭头 12 + 间隔 + 字宽），
	# 比原版宽 17 —— 修前场景把下拉烘成 43、尾文字挂在下拉局部 45 ⇒ 控件真实右沿（303）
	# 压在「个寄坏玉」（291）底下 12 像素（§3.295「Control 烘得比地板窄 ⇒ 引擎悄悄长大、
	# 谁都不知道长了多少」那一族的现形）。这里量**运行时实际矩形**、不读 .tscn 里烘的偏移：
	# 只有实际矩形才能证明不压字（`勾选框几何回归测试` 用项目默认主题量，量不到这一层）。
	# ⚠ ⑪ 那一腿收尾又 `_render_page` + 等帧重绘过 ⇒ 函数开头（甚至 ⑪ 里现取）的那枚 `弹窗`
	#   连同 `玉勾`/`下拉` 全是 **freed**，直接拿去 `get_node_or_null` 就是 `SCRIPT ERROR`，
	#   整条长腿当场断在半路（2026-10-27 反向对照抓到的假绿就是这么来的）。本腿现取现用。
	页 = _取页(窗, "寄坏之术")
	弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	if 弹窗 == null:
		_失败.append("⑫ 10 星那一腿之后取不到弹窗 ⇒ 数量行几何 + 报修①②③一整串没量到")
		return
	玉勾 = 弹窗.get_node_or_null("底图/强化区底图/使用寄坏玉") as CheckBox
	下拉 = 弹窗.get_node_or_null("底图/强化区底图/数量下拉") as OptionButton
	if 玉勾 == null or 下拉 == null:
		_失败.append("⑫ 取不到「使用寄坏玉」或「数量下拉」（%s / %s）⇒ 这一行没法量"
			% ["有" if 玉勾 != null else "无", "有" if 下拉 != null else "无"])
		return
	var 区 := 弹窗.get_node_or_null("底图/强化区底图") as Control
	var 尾 := 下拉.get_node_or_null("寄坏玉数量") as Label
	if 区 == null or 尾 == null:
		_失败.append("⑫ 缺「强化区底图」或缺下拉里的尾文字「寄坏玉数量」⇒ 这一行没法量")
	else:
		var 勾右: float = 玉勾.position.x + 玉勾.size.x
		var 下右: float = 下拉.position.x + 下拉.size.x
		var 尾左: float = 尾.position.x + 下拉.position.x
		var 尾右: float = 尾左 + 尾.size.x
		if 下拉.size.x < 下拉.get_combined_minimum_size().x:
			_失败.append("⑫ 数量下拉烘的宽 %s 比引擎地板 %s 还窄 ⇒ 实际会被悄悄撑大，"
				% [str(下拉.size.x), str(下拉.get_combined_minimum_size().x)]
				+ "摆在它右边的东西全部要跟着错位（§3.295）")
		if 勾右 > 下拉.position.x:
			_失败.append("⑫ 勾「本次操作使用」右沿 %s 压住数量下拉左沿 %s ⇒ 抢点击" % [
				str(勾右), str(下拉.position.x)])
		if 下右 > 尾左:
			_失败.append("⑫ 数量下拉右沿 %s 压住「个寄坏玉」左沿 %s ⇒ 就是报修④那条" % [
				str(下右), str(尾左)])
		if 尾右 > 区.size.x:
			_失败.append("⑫ 「个寄坏玉」右沿 %s 出了强化区底图（宽 %s）⇒ 文字跑到面板外" % [
				str(尾右), str(区.size.x)])

	# ── 报修②（2026-10-27 用户报修「格子里鼠标放上去也不显示昆虫信息」）───────────────
	# 真值：弹窗这四格全是 `SimpleItemCell`（放置格=`ItemDropBox.itemCell`、成功格=`resultCell`、
	# 两格材料=`ItemCaiLiaoBox.itemCell`），`SimpleItemCell.showIcon:220` 末尾统一挂
	# `MToolTipItem.createToolTip(this, _itemData, _data)`；虫槽那四格 = `KunChongCell.as:122` 同一句。
	# ⇒ 与背包/人物装备格**共用** `格子提示框.接线`，**三参**（不挂穿戴对比：原版这几处都不是
	#   `ItemWindowCell`，见 `格子提示框.gd` 分流表）。框必须挂在 `提示宿主(页)` 那一层
	#   （`原版人物窗口内容`）：挂页里就落在 `人物扩展页` 的裁层下 ⇒ §3.298 那批轮回框的同一条坑。
	var 人物脚本 := load("res://脚本/界面/窗口/人物窗口.gd")
	var 提示层: Control = 人物脚本.提示宿主(页)
	if 提示层 == null:
		_失败.append("报修② `提示宿主(页)` 走完整条祖先链找不到提示框层 ⇒ 八格提示一整串没量到")
	else:
		var 虫框 := 提示层.get_node_or_null("装备提示框") as Control
		var 物框 := 提示层.get_node_or_null("物品提示框") as Control
		if 虫框 == null or 物框 == null:
			_失败.append("报修② 宿主层 `%s` 上缺提示框节点（装备=%s 物品=%s）" % [
				String(提示层.name), "有" if 虫框 != null else "无", "有" if 物框 != null else "无"])
		else:
			# `[名, 格子, 该亮的框, 正文必含]`；框=空 ⇒ 这格没件，悬停该把**两套都收掉**（修前这八格
			# 一句接线都没有 ⇒ 悬停什么都不出，正是报修②）。
			# ⚠️ 期望名**必须按"这一格实际是谁"现算**，不许写死「蝉」：这一串跑的是玩家真存档
			#    （夹具/本机玩档），四个虫槽里穿哪几只由玩家决定；10-30 全量时就因本机玩档
			#    -201 穿的是蜻蜓、而门里四个槽的期望全写死「蝉」⇒ 寄坏槽二假红。
			#    放置格/成功格同理：显示的是「强化目标」（`人物窗口:2937-2958` 携入→首个已装备
			#    →背包首虫），目标是谁就期望谁。
			var 目标名 := _强化目标虫名(窗, 会话)
			if 目标名.is_empty():
				_失败.append("报修② 定不出「强化目标」是哪只虫（放置格/成功格的期望名无从算）"
					+ " ⇒ 这一串的放置格/成功格两腿没判满")
			var 提腿: Array = [
				["放置格", 弹窗.get_node_or_null("底图/放置区底图/放置格") as Control, 虫框, 目标名],
				["成功格", 弹窗.get_node_or_null("底图/放置区底图/成功格") as Control, 虫框, 目标名],
				["镇灵石格", 弹窗.get_node_or_null("底图/强化区底图/镇灵石格") as Control, 物框, "镇灵石"],
				["寄坏玉格", 弹窗.get_node_or_null("底图/强化区底图/寄坏玉格") as Control, 物框, "寄坏玉"],
			]
			for 序号 in 4:
				var 槽号: int = [装备部位表.昆虫一, 装备部位表.昆虫二,
					装备部位表.昆虫三, 装备部位表.昆虫四][序号]
				var 身上: Dictionary = (会话.equipped_items as Dictionary).get(槽号, {}) as Dictionary
				提腿.append(["寄坏槽%s" % "一二三四"[序号],
					页.get_node_or_null("虫槽区域/寄坏槽%s" % "一二三四"[序号]) as Control,
					虫框 if not 身上.is_empty() else null,
					_虫名(身上) if not 身上.is_empty() else ""])
			for 腿: Array in 提腿:
				var 格 := 腿[1] as Control
				if 格 == null:
					_失败.append("报修②「%s」取不到节点 ⇒ 这一格的提示没量到" % String(腿[0]))
					continue
				if 格.mouse_filter == Control.MOUSE_FILTER_IGNORE:
					_失败.append("报修②「%s」mouse_filter=IGNORE ⇒ 悬停事件根本进不来" % String(腿[0]))
				if 格.tooltip_text != "":
					_失败.append("报修②「%s」还挂着原生 tooltip（%s）⇒ 原版提示框要让位给共享那一套，不留两套"
						% [String(腿[0]), 格.tooltip_text])
				if 格.mouse_entered.get_connections().size() != 1:
					_失败.append("报修②「%s」悬停接线 %d 根（应恰好 1；`格子提示框.接线` 的先拆再接被删 ⇒ 叠线）"
						% [String(腿[0]), 格.mouse_entered.get_connections().size()])
				虫框.visible = false
				物框.visible = false
				格.mouse_entered.emit()
				var 该亮 := 腿[2] as Control
				if 该亮 == null:
					if 虫框.visible or 物框.visible:
						_失败.append("报修②「%s」这格本来没件，悬停却把提示框点亮了（原版空格只收不弹）"
							% String(腿[0]))
				else:
					if not 该亮.visible:
						_失败.append("报修②「%s」悬停后「%s」没亮 ⇒ 就是用户报的那条：格子里没有昆虫信息"
							% [String(腿[0]), String(该亮.name)])
					elif not _格子提示全文(该亮).contains(String(腿[3])):
						_失败.append("报修②「%s」的提示正文里没有「%s」（实读：%s）"
							% [String(腿[0]), String(腿[3]), _格子提示全文(该亮).replace("\n", "⏎")])
				格.mouse_exited.emit()
				if 该亮 != null and 该亮.visible:
					_失败.append("报修②「%s」移出后提示框还亮着（原版 ROLL_OUT 就 removeChild）" % String(腿[0]))

	# ── 报修①（2026-10-27 用户报修「不能手动拖拽背包的昆虫到强化格里，自由选择强化哪一个」）──
	# 真值 `KunChongStrengthWindow.as:415-418 dropItemHandler` → `:420-439 validateItem`：
	# 落点 `SimpleItemCell` **只认"从背包来的拖"、不看类型**（`SimpleItemCell.as:109-117`），
	# 类型判在落下**之后**：`isItemAKunChong` 过 ⇒ 这件就是目标，不过 ⇒ 弹原文「很抱歉，该物品不是
	# 昆虫不能强化！」且目标不动。⇒ 反例里材料也得先放行，否则钉的是"我们自己加的严闸"。
	var 背包快照: Array = (会话.inventory as Array).duplicate(true)
	var 原携虫: Dictionary = 窗._角色携入虫
	var 原携位: int = int(窗._角色携入位置)
	var 原态: Dictionary = 窗._昆虫强化态.duplicate(true)
	var 放置 := 弹窗.get_node_or_null("底图/放置区底图/放置格") as Control
	if 放置 == null or not 放置.has_signal("请求选虫"):
		_失败.append("报修① 放置格没挂上落点件（`set_script(昆虫强化落格)` 掉了 ⇒ 拖进来什么都不发生）")
	else:
		if 放置.mouse_filter != Control.MOUSE_FILTER_STOP:
			_失败.append("报修① 放置格 mouse_filter=%d ⇒ 接不到 `_drop_data`" % 放置.mouse_filter)
		if (放置.get("请求选虫") as Signal).get_connections().size() != 1:
			_失败.append("报修① 落点连线该**恰好一根**（页面实例复用，先拆再接被删 ⇒ 这里会堆）")
		var 起拖 := 假虫来源.new()
		起拖.槽位号 = 2
		var 虫荷 := {"来源格": 起拖, "归属": "背包", "物品id": "1310003"}
		if not bool(放置.call("_can_drop_data", Vector2.ZERO, 虫荷)):
			_失败.append("报修① 背包虫起拖，放置格该放行（`_can_drop_data` 挡了 ⇒ 就是「不能拖进来」）")
		for 反: Array in [[{"来源格": 起拖, "归属": "仓库", "物品id": "1310003"}, "归属不是背包"],
				[{"来源格": 放置, "归属": "背包", "物品id": "1310003"}, "起拖格就是落点自己"],
				[{"归属": "背包", "物品id": "1310003"}, "载荷没有来源格"]]:
			if bool(放置.call("_can_drop_data", Vector2.ZERO, 反[0])):
				_失败.append("报修① 反例：%s ⇒ 该被挡（原版只认 dragSource==ITEM_WINDOW）" % String(反[1]))
		if not bool(放置.call("_can_drop_data", Vector2.ZERO,
				{"来源格": 起拖, "归属": "背包", "物品id": "16000136"})):
			_失败.append("报修① 落点**不该比原版严**：原版材料也放行，拒绝发生在 `validateItem`")
		var 假虫 := 假后端.new()
		通知.clear()
		放置.call("_drop_data", Vector2.ZERO,
			{"来源格": 起拖, "归属": "背包", "物品id": "16000136"})
		if not 通知.any(func(文: String) -> bool: return String(文).contains("不是昆虫不能强化")):
			_失败.append("报修① 非虫落下该出原文「很抱歉，该物品不是昆虫不能强化！」，实际通知 %s" % [通知])
		if int(窗._角色携入位置) != 原携位:
			_失败.append("报修① 非虫落下却换了目标（原版 `validateItem` 不过 ⇒ 目标不动）")
		# 真虫：格2 = 蜻蜓 ⇒ 换目标 + 重渲染后格子里就是它，「开始强化」发的是**背包格号 2**
		会话.inventory.clear()
		会话.inventory.append({})
		会话.inventory.append({"id": "01310003", "name": "蜻蜓", "quantity": 1, "strengthen": 2})
		窗._昆虫强化态["镇"] = false
		窗._昆虫强化态["玉"] = false
		窗._昆虫强化态["张"] = 1
		通知.clear()
		放置.call("_drop_data", Vector2.ZERO, 虫荷)
		for _帧 in 3:
			await process_frame
		if int(窗._角色携入位置) != 2:
			_失败.append("报修① 拖完 `_角色携入位置` 该是背包格 2，实得 %d" % int(窗._角色携入位置))
		elif String((窗._角色携入虫 as Dictionary).get("id", "")) != "01310003":
			_失败.append("报修① 拖完携入的那件该是蜻蜓，实得 %s" % str(窗._角色携入虫))
		var 页1 := _取页(窗, "寄坏之术")
		var 弹1 := 页1.get_node_or_null("昆虫强化弹窗") as Control if 页1 != null else null
		if 弹1 == null:
			_失败.append("报修① 拖完重渲染后取不到弹窗 ⇒ 下面的回显没量到")
		else:
			var 钮1 := 弹1.get_node_or_null("底图/放置区底图/开始提升按钮") as Button
			var 图1 := 弹1.get_node_or_null("底图/放置区底图/放置格/昆虫图标") as TextureRect
			if 钮1 == null or 钮1.text != "取出昆虫":
				_失败.append("报修① 拖进虫后那枚钮该换成「取出昆虫」（原版 `dropItemHandler:417`），实得「%s」"
					% ("取不到" if 钮1 == null else 钮1.text))
			if 图1 == null or not 图1.visible or 图1.texture == null:
				_失败.append("报修① 拖进虫后放置格里没有图标 ⇒ 看着像没落上")
			if not bool(窗._昆虫强化态.get("开", false)):
				_失败.append("报修① 拖完弹窗的「开」被自己关掉了（重画后整扇闪没）")
			var 提1 := 弹1.get_node_or_null("开始提升按钮") as Button
			if 提1 == null or 提1.pressed.get_connections().is_empty():
				_失败.append("报修① 换完目标后「开始强化」没接线")
			else:
				窗.set("_backend", 假虫)
				假虫.收到.clear()
				提1.pressed.emit()
				await process_frame
				# AS3 `strengthEquip:353` = `_jhyCheckBox.selected ? selectedIndex+1 : 0`
				# ⇒ 本腿没勾寄坏玉，**张数就该是 0**（不是字段丢了）；勾了才带张数那一腿在 ④/⑩。
				if 假虫.收到 != [[2, false, 0]]:
					_失败.append("报修① 拖蜻蜓进格后「开始强化」该发 [背包格2, false, 0]（没勾寄坏玉⇒张数 0），实得 %s" % [假虫.收到])
	# —— 还原：这一腿动的三样（背包、携入、弹窗宿主态）原样还回去，后面的腿看到的世界才与本腿开始时一致
	会话.inventory.clear()
	for 件 in 背包快照:
		会话.inventory.append(件)
	窗._角色携入虫 = 原携虫
	窗._角色携入位置 = 原携位
	for 键 in 原态:
		窗._昆虫强化态[键] = 原态[键]

	# ── 报修③（2026-10-27 用户报修「卡在人物属性面板里，不能拖拽移动，下方的信息被遮挡」）──
	# 遮挡那一半：`人物扩展页` 是 `clip_contents = true` 的 Panel（`人物窗口.tscn:1955`），
	# 而弹窗 358×393 摆在 422×366 的面板里 ⇒ 下沿越出面板（修前实测被裁 27px，「开始强化」
	# 「自动强化到10并停止」正好在那一条里）。这一页放开裁 ⇒ 用 `_链上有裁` 整条祖先链验，
	# 顺手钉住**别页还裁着**（放开整扇 = 给以后的越界改动留后门，只准这一页）。
	# 同一颗雷：报修① 那一腿里 `_drop_data` 走过重渲染 ⇒ `页`/`弹窗` 又是 freed，现取。
	页 = _取页(窗, "寄坏之术")
	弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	if 弹窗 == null:
		_失败.append("报修③ 拖完那一腿之后取不到弹窗 ⇒ 裁层与拖拽一整串没量到")
		return
	var 面板层 := 页.get_parent() as Control
	if 面板层 == null or String(面板层.name) != "人物扩展页":
		_失败.append("报修③ 弹窗的父层不是「人物扩展页」（实得 %s）⇒ 遮挡那条判错对象了"
			% ("无" if 面板层 == null else String(面板层.name)))
	elif 面板层.clip_contents:
		_失败.append("报修③ `人物扩展页.clip_contents` 还开着 ⇒ 弹窗下沿被裁（用户报的「下方的信息被遮挡」）")
	elif 弹窗.get_global_rect().end.y <= 面板层.get_global_rect().end.y:
		# 原判据是 `_链上有裁(弹窗)`（"祖先链里还得有一层裁"）—— 2026-10-27 第一次跑到底就红：
		# 这一页的裁**只有** `人物扩展页` 那一层，放开之后整条链本来就没有裁层 ⇒ 那条判据
		# 与修法互相矛盾。换成钉"弹窗下沿确实越出面板下沿"：越出去才说明放开裁剪是有必要的，
		# 哪天窗改小 / 面板改大 / 位置挪了，这条会红着提醒复核。
		_失败.append((("报修③ 弹窗下沿 %s 没越出「人物扩展页」下沿 %s ⇒「被遮挡」这条判据失去意义"
			+ "（窗改小了？面板改大了？位置挪了？）") % [
			str(弹窗.get_global_rect().end.y), str(面板层.get_global_rect().end.y)]))
	窗.call("_set_character_main_tab", 1)
	await process_frame
	窗.call("_set_character_sub_tab", 0)
	for _帧 in 3:
		await process_frame
	var 八页面 := _取页(窗, "八门")
	var 八面板 := 八页面.get_parent() as Control if 八页面 != null else null
	if 八面板 == null:
		_失败.append("报修③ 切不到八门页 ⇒ 没能钉住「别页仍然裁着」")
	elif not 八面板.clip_contents:
		_失败.append("报修③ 「人物扩展页」整扇被放开裁剪了（只有寄坏之术那一页该放开，其余六页的越界改动要能被裁住）")
	窗.call("_set_character_sub_tab", 2)
	for _帧 in 3:
		await process_frame
	# 拖动那一半：`MWindow.as:333-340` —— MOUSE_DOWN 且 `mouseY < _startDragY`（29，只有顶部
	# 标题条）⇒ `startDrag(false, Rectangle(0,0,STAGE_WIDTH-width, STAGE_HEIGHT-30))`。
	# 这条用**真输入**（`push_input`）：`gui_input` 的拾取、29px 那条界线、鼠标全局坐标都得真走一遍。
	var 页2 := _取页(窗, "寄坏之术")
	var 弹2 := 页2.get_node_or_null("昆虫强化弹窗") as Control if 页2 != null else null
	if 弹2 == null:
		_失败.append("报修③ 切回寄坏之术页后取不到弹窗 ⇒ 拖拽那一串没量到")
	else:
		if 弹2.mouse_filter != Control.MOUSE_FILTER_STOP:
			_失败.append("报修③ 弹窗本体 mouse_filter=%d ⇒ 标题条收不到 `gui_input`，拖不动" % 弹2.mouse_filter)
		if not 弹2.visible:
			_失败.append("报修③ 拖拽那一腿开跑时弹窗不可见（无头拾取只落在可见件上 ⇒ 后面全是假红）")
		# 拾取的三条硬前置（2026-10-27 `测试/_探针无头拾取.gd` 逐条量过）：**整条祖先链都得可见**、
		# 链上**不许有 clip_contents**（越出裁剪框的件整个不参与拾取）、**点在最上层的非 IGNORE 件**
		# 收到事件后按父链往上传、碰到 STOP 就断。后两条是"拖不动"的真病根，先钉前置，红得才有指向。
		var 隐链: Array = []
		var 裁链: Array = []
		var 上: Node = 弹2.get_parent()
		while 上 != null:
			if 上 is Control:
				if not (上 as Control).visible:
					隐链.append(String((上 as Control).name))
				if (上 as Control).clip_contents:
					裁链.append(String((上 as Control).name))
			上 = 上.get_parent()
		if not 隐链.is_empty():
			_失败.append("报修③ 拖拽开跑前祖先链上这些件是隐藏的 %s ⇒ 无头拾取根本不落在弹窗上（后面几条必假红）" % str(隐链))
		if not 裁链.is_empty():
			_失败.append("报修③ 拖拽开跑前祖先链上还开着裁剪 %s ⇒ 越出裁剪框的弹窗整个不参与拾取" % str(裁链))
		# 落点**不写死坐标**，让 Godot 自己仲裁：把弹窗摆到候选全局点、鼠标移到"落点+局部偏移"，
		# 只有 `gui_get_hovered_control()` 报的就是这扇弹窗，这个落点才算能用。
		# ⚠ 为什么非要这么绕（2026-10-27 探针实测）：先前把弹窗摆到左上角 (120,60) 好让它整个进
		#   960×560 视口，结果 `gui_input` 一条不进 —— 悬停报的是 **HUD 那枚
		#   `头像面板/角色状态/AutoCombatSettings/HangLabel`（TextureRect 钮）**，它在绘制序上压过
		#   窗口分支 ⇒ 按下被整个吞掉，看着像"拖拽没接线"（其实是根本没送到）。"标题条以下"那个
		#   反例点更危险：指到被子（真被哪枚钮盖住）时事件压根进不了弹窗 ⇒ **当然不挪 = 假绿**。
		# ⚠ 顺序要紧：**先 `_钉()` 撑视口，再摆位置**（`_按全局/_移全局` 里各还有一次 `_钉()`，
		#   尺寸没变就是幂等）；先摆后撑的话第一次 push 触发的重排会按锚点把弹窗弹回烘死位。
		var 烘位全 := 弹2.get_global_position()
		var 挑上 := _挑拖点(弹2, [弹2.get_global_position(), Vector2(400, 120), Vector2(560, 150), Vector2(300, 300)],
			[Vector2(10, 10), Vector2(30, 8), Vector2(60, 6)])
		var 拖后全 := Vector2.ZERO
		var 能拖 := false
		if 挑上.is_empty():
			_失败.append("报修③ 四个候选落点 × 三个标题条偏移，没有一处「按下真能送进弹窗的 `gui_input`」⇒ 拖拽腿无从量（弹窗被别处压住）")
		else:
			能拖 = true
			var 起全: Vector2 = 挑上[0]
			var 抓: Vector2 = 挑上[1]		# 处理函数记的抓取偏移 = 按下点 − 弹窗全局 = `抓`（逐字对上）
			# **按住不放连拖三段**：跟手 → 右下越界 → 左上越界（真玩家就是一次拖到底，中途不松手）
			_按全局(起全 + 抓, true)
			_移全局(起全 + 抓 + Vector2(-60.0, -40.0))
			var 跟手后: Vector2 = 弹2.get_global_position()
			_移全局(Vector2(900.0, 540.0))
			var 右下后: Vector2 = 弹2.get_global_position()
			_移全局(Vector2(1.0, 1.0))
			var 左上后: Vector2 = 弹2.get_global_position()
			_按全局(Vector2(1.0, 1.0), false)
			拖后全 = 弹2.get_global_position()
			if 跟手后 != 起全 + Vector2(-60.0, -40.0):
				_失败.append("报修③ 按住标题条拖 (-60,-40) 该跟手到 %s，实得 %s（落点=%s 抓=%s mouse_filter=%d 可见=%s 悬=%s）"
					% [str(起全 + Vector2(-60.0, -40.0)), str(跟手后), str(起全), str(抓),
						弹2.mouse_filter, str(弹2.visible), str(root.gui_get_hovered_control())])
			elif 右下后 != Vector2(602.0, 530.0):
				_失败.append("报修③ 往右下甩该钳在 (602,530)=舞台960×560 −(窗宽358, 下沿留30)，实得 %s" % str(右下后))
			elif 左上后 != Vector2.ZERO:
				_失败.append("报修③ 往左上甩该钳回 (0,0)（原版 `Rectangle(0,0,…)` 两条边都钳），实得 %s" % str(左上后))
			elif not (窗._昆虫强化态.get("置", null) is Vector2):
				_失败.append("报修③ 拖完宿主「置」里根本没有位置（实得 %s）⇒ 整页重绘会弹回烘死位（原版 MWindow 记住上次位置）"
						% str(窗._昆虫强化态.get("置", null)))
			elif (窗._昆虫强化态.get("置", null) as Vector2) != 弹2.position:
				_失败.append("报修③ 宿主「置」记的是 %s、弹窗在 %s ⇒ 记歪了，整页重绘会弹到别处"
						% [str(窗._昆虫强化态.get("置")), str(弹2.position)])
		# 整页重绘（`_render_page` 把 `_content` free 重建 ⇒ 弹窗是**新节点**）后位置该回来。
		# ⚠ `拖后全` 早在 free 之前就抄进变量了：重绘后再碰 `弹2` 一下就是 `SCRIPT ERROR`，
		#   整条尾巴静默跳掉、门照样打「通过」（假绿#20，2026-10-27 踩过）。
		if 能拖:
			窗.call("_render_page")
			for _帧 in 3:
				await process_frame
			var 页3 := _取页(窗, "寄坏之术")
			var 弹3 := 页3.get_node_or_null("昆虫强化弹窗") as Control if 页3 != null else null
			if 弹3 == null:
				_失败.append("报修③ 重绘后取不到弹窗 ⇒ 保持那条没量到")
			elif 弹3.get_global_position() != 拖后全:
				_失败.append("报修③ 整页重绘后弹窗在 %s，拖完明明是 %s（烘死位 %s ⇒ 位置没回灌）"
					% [str(弹3.get_global_position()), str(拖后全), str(烘位全)])
			elif 弹3.gui_input.get_connections().size() != 1:
				# 复用的页不重建 ⇒ `drag_wired` 守卫要在；重建的页没这 meta ⇒ 重接一根。两种都只该一根。
				_失败.append("报修③ 重绘后 `gui_input` 接线 %d 根（应恰好 1 ⇒ 守卫掉了会叠线、一次拖动跑两遍）"
					% 弹3.gui_input.get_connections().size())
			else:
				# 反例：标题条**以下**按下不许拖（`mouseY < 29` 那道闸；掉了的话点面板里任何一处都在挪窗）。
				# ⚠ 这条**先确认那一点真能送进弹窗**再判「没挪」：否则测的是「事件被别处吞了」，
				#   闸掉了也照样绿（2026-10-27 就被这种假绿骗过一轮）。
				var 挑下 := _挑拖点(弹3, [弹3.get_global_position(), Vector2(400, 120), Vector2(560, 150), Vector2(300, 300)],
					[Vector2(10, 40), Vector2(30, 60), Vector2(60, 120), Vector2(10, 200)])
				if 挑下.is_empty():
					_失败.append("报修③ 反例无从量：四个「标题条以下」的落点没有一处送得进弹窗 ⇒「29px 那道闸还在」根本没被验证过（别当绿）")
				else:
					var 停全: Vector2 = 挑下[0]
					var 条下: Vector2 = 挑下[1]
					_按全局(停全 + 条下, true)
					_移全局(停全 + 条下 + Vector2(50.0, 50.0))
					_按全局(停全 + 条下 + Vector2(50.0, 50.0), false)
					if 弹3.get_global_position() != 停全:
						_失败.append("报修③ 在标题条以下（局部 %s）拖动却挪了窗 ⇒ 29px 那道闸没了（实得 %s）"
							% [str(条下), str(弹3.get_global_position())])
		# 收尾：位置/开合还原成这一腿开始前的样子，别把拖歪了的弹窗留给后面的腿
		窗._昆虫强化态["置"] = null
		窗._昆虫强化态["开"] = bool(原态.get("开", false))
		窗.call("_render_page")
		for _帧 in 3:
			await process_frame
	_弹窗腿跑完 = true


## 起拖那一头的假格：`昆虫放入格._drop_data` 只问 `来源格.get("槽位号")`
## （同 `勾玉炼制页回归测试` 的 `假来源格` 先例；不需要真 Button、不入树、不 free）。
class 假虫来源:
	extends Control
	var 槽位号 := 0


## 虫槽落点 + 「昆虫强化」入口（2026-10-27 用户报修①「昆虫不能佩戴」②「强化按键不能点击」）。
## 真值逐字引在 `昆虫放入格.gd` 与 `人物窗口.初始化寄坏之术页` 的注释里，这里钉**行为**：
##  · **拖上虫槽是穿虫唯一路径**（原版 `KunChongPanel.as:152-164` 发 `requestMoveItem(背包格,-200..-203)`；
##    双击/菜单「佩戴」算出的 `KunChongE(-205)` 被服务端 `_can_equip:48064` 拒 ⇒ 离线镜像同拦）；
##  · 客户端类型闸 = `ItemType.as:285-288` 前三位 "131" —— **勾玉（分类「宝石」）也放**，
##    兜底的是服务端装备定义 ⇒ 离线拿 `物品.json` 的 `category=="装备"` 镜像；
##  · `_strengthBtn` 整文件没有一处 enabled/disabled 赋值 ⇒ 入口**永不置灰**（旧写法
##    `disabled = 强化目标.is_empty()` 是移植自己加的，就是用户报的「不能点击」）；
##  · 看别人**根本没有落点**（`createCell:241-245` 只给 `_isMyself` 挂 MOUSE_UP）。
func _验虫槽落点(窗, 会话) -> void:
	var 人物脚本 := load("res://脚本/界面/窗口/人物窗口.gd")
	var 页 := _取页(窗, "寄坏之术")	# ⚠ 自己现取：传进来的引用可能已 freed
	var 虫槽四: Array = [装备部位表.昆虫一, 装备部位表.昆虫二, 装备部位表.昆虫三, 装备部位表.昆虫四]
	# 快照（收尾逐样还原 ⇒ 后面的腿看到的世界与本腿开始时一致）
	var 原背包: Array = (会话.inventory as Array).duplicate(true)
	var 原虫: Dictionary = {}
	for 槽号 in 虫槽四:
		原虫[槽号] = (会话.equipped_items as Dictionary).get(槽号, null)
	var 原开 = 窗._昆虫强化态.get("开", false)
	var 原放 = 窗._昆虫强化态.get("放", false)

	# ⓪ 类型闸逐字（纯函数直接问）：`String(id).substr(0,3)=="131"`，**原版就这么宽**——
	#    补零形态与勾玉都照它放（勾玉 `13100xxx` 前缀同为 131，兜底在服务端那半道）。
	for 号 in ["01310001", "1310003", "13100000"]:
		if not 昆虫放入格脚本.可收(号):
			_失败.append("⓪ `%s` 该过原版 131 前缀闸（`ItemType.as:285-288`），可收却=false" % 号)
	for 号 in ["1210001", "16000136", "", "abc"]:
		if 昆虫放入格脚本.可收(号):
			_失败.append("⓪ `%s` 不该过 131 闸，可收却=true" % 号)

	# ① 挂上落点件：`set_script` 运行期挂（场景不许手改）⇒ 信号在、槽位号被重填、认鼠标。
	#    ⚠ 上一腿（④ 强化弹窗）重绘过页面，引用作废 ⇒ 现取。
	页 = _取页(窗, "寄坏之术")
	if 页 == null:
		_失败.append("① 取不到寄坏之术页 ⇒ 虫槽落点整串没量到")
		return
	var 槽一 := 页.get_node_or_null("虫槽区域/寄坏槽一") as TextureButton
	if 槽一 == null or not 槽一.has_signal("请求放入"):
		_失败.append("① 寄坏槽一没挂上落点件（`set_script(昆虫放入格)` 掉了 ⇒ 拖进来什么都不会发生）")
		return
	if int(槽一.get("槽位号")) != 装备部位表.昆虫一:
		# ⚠ 措辞吃过一次亏：`set_script` 挂**同一份**脚本是 no-op、**不**重建实例（2026-10-27 门 ⑦ 实测），
		#    旧句"会重建"把病因说反了 —— 真规矩是「每轮**显式**重填，不靠挂脚本复位」。
		_失败.append("① 槽位号该每轮**显式**重填（`set_script` 同脚本是 no-op，不会自己复位）（实得 %d，应 %d）"
			% [int(槽一.get("槽位号")), 装备部位表.昆虫一])
	if 槽一.mouse_filter != Control.MOUSE_FILTER_STOP:
		_失败.append("① 落点格 mouse_filter 该是 STOP，不然接不到 `_drop_data`")
	if (槽一.get("请求放入") as Signal).get_connections().size() != 1:
		_失败.append("① 每轮渲染该**恰好一根**落点连线（先拆再接被删 ⇒ 这里会堆）")

	# ② 真拖放穿虫（离线镜像）：格2 一只蜻蜓 ⇒ 拖上**寄坏槽二** ⇒ 穿上 + 格2 留洞。
	for 槽号 in 虫槽四:
		(会话.equipped_items as Dictionary)[槽号] = {}
	会话.inventory.clear()
	会话.inventory.append({})
	会话.inventory.append({"id": "01310003", "name": "蜻蜓", "quantity": 1})
	窗.call("_render_page")
	for _帧 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	var 槽二 := (页.get_node_or_null("虫槽区域/寄坏槽二") as TextureButton) if 页 != null else null
	if 槽二 == null:
		_失败.append("② 重渲染后取不到寄坏槽二")
	else:
		var 起拖 := 假虫来源.new()
		起拖.槽位号 = 2
		var 载荷 := {"来源格": 起拖, "归属": "背包", "物品id": "01310003"}
		if not bool(槽二.call("_can_drop_data", Vector2.ZERO, 载荷)):
			_失败.append("② 虫（131 前缀）从背包起拖，落点该认（`_can_drop_data` 挡了 ⇒ 还是「不能佩戴」）")
		else:
			槽二.call("_drop_data", Vector2.ZERO, 载荷)
			var 穿上: Dictionary = (会话.equipped_items as Dictionary).get(装备部位表.昆虫二, {}) as Dictionary
			if String(穿上.get("id", "")) != "01310003":
				_失败.append("② 拖完该穿到昆虫二（-201），实得 %s" % str(穿上))
			if not (会话._占用条(会话.inventory, 2) as Dictionary).is_empty():
				_失败.append("② 背包那件没挪走 ⇒ 一穿就复制（服务端 `handle_item_move` 是两边 pop 交换）")
		# 反例三道（都该 `_can_drop_data`=false）：归属不是背包 / 起拖就是自己 / 没有来源格。
		if bool(槽二.call("_can_drop_data", Vector2.ZERO, {"来源格": 起拖, "归属": "仓库", "物品id": "01310003"})):
			_失败.append("反例：`归属=仓库` 该被挡（原版只认 `dragSource==ITEM_WINDOW`）")
		if bool(槽二.call("_can_drop_data", Vector2.ZERO, {"来源格": 槽二, "归属": "背包", "物品id": "01310003"})):
			_失败.append("反例：起拖格就是落点自己 ⇒ 该挡（同 `可拖拽格._can_drop_data:103`）")
		if bool(槽二.call("_can_drop_data", Vector2.ZERO, {"归属": "背包", "物品id": "01310003"})):
			_失败.append("反例：载荷没有来源格 ⇒ 该挡")
		if bool(槽二.call("_can_drop_data", Vector2.ZERO, {"来源格": 起拖, "归属": "背包", "物品id": "16000136"})):
			_失败.append("反例：材料（160 段）不过 131 闸 ⇒ 落点就该拒（连发包都不发）")

	# ③ 勾玉走**完整路径**：131 前缀过客户端闸（真值就这么宽）⇒ 兜底必须在处理函数的
	#    分类闸（镜像服务端 `_can_equip`：勾玉没有装备定义）。不许穿进虫槽（幽灵数据）。
	会话.inventory.clear()
	会话.inventory.append({})
	会话.inventory.append({"id": "13100000", "name": "勾玉（1级）", "quantity": 1})
	for 槽号 in 虫槽四:
		(会话.equipped_items as Dictionary)[槽号] = {}
	窗.call("_render_page")
	for _帧 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	var 槽三 := (页.get_node_or_null("虫槽区域/寄坏槽三") as TextureButton) if 页 != null else null
	if 槽三 == null:
		_失败.append("③ 重渲染后取不到寄坏槽三")
	else:
		var 起拖3 := 假虫来源.new()
		起拖3.槽位号 = 2
		var 载荷3 := {"来源格": 起拖3, "归属": "背包", "物品id": "13100000"}
		if not bool(槽三.call("_can_drop_data", Vector2.ZERO, 载荷3)):
			_失败.append("③ 客户端闸**不该比原版严**：勾玉同为 131 前缀、原版放它进门（`ItemType.as:285-288`）")
		else:
			槽三.call("_drop_data", Vector2.ZERO, 载荷3)
			if not ((会话.equipped_items as Dictionary).get(装备部位表.昆虫三, {}) as Dictionary).is_empty():
				_失败.append("③ 勾玉被穿进虫槽了 ⇒ 虫槽的分类兜底没了，离线会长幽灵数据")

	# ③b 处理函数那道**分类闸独有的向量**：勾玉（8 位 `13100xxx`）其实被**两层**挡着
	#    （处理函数 `category=="装备"` 一道、`游戏会话.equip_item` 的 `是装备` 一道——它的
	#    前四位 `1310` 认不出装备位），2026-10-27 反向 R14 只拆处理函数那道 ⇒ 门照样绿，
	#    ③ 那条**点不到名**（假绿形状 #14：摘掉仍绿 ⇒ 该向量下这层是冗余）。
	#    编一个「int 化后前四位是 131、物品表里却没有」的 id（`01319999`）：`是装备` 认得出
	#    （→ 昆虫包 -205）、`可收` 也放（131 前缀），**只剩处理函数的分类闸**挡它 —— 原版
	#    服务端 `_can_equip` 查 `GAME_DATA_CATALOG` 同样没有这件 ⇒ 离线这道闸必须挡，
	#    不挡就长幽灵键。
	会话.inventory.clear()
	会话.inventory.append({})
	会话.inventory.append({"id": "01319999", "name": "编造虫", "quantity": 1})
	for 槽号 in 虫槽四:
		(会话.equipped_items as Dictionary)[槽号] = {}
	窗.call("_render_page")
	for _帧 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	var 槽四 := (页.get_node_or_null("虫槽区域/寄坏槽四") as TextureButton) if 页 != null else null
	if 槽四 == null:
		_失败.append("③b 重渲染后取不到寄坏槽四")
	else:
		var 起拖4 := 假虫来源.new()
		起拖4.槽位号 = 2
		var 载荷4 := {"来源格": 起拖4, "归属": "背包", "物品id": "01319999"}
		if not bool(槽四.call("_can_drop_data", Vector2.ZERO, 载荷4)):
			_失败.append("③b 客户端闸只认 131 前缀（原版真值）⇒ 表里没有的编造 id 也该放进门（挡它的是分类闸）")
		else:
			槽四.call("_drop_data", Vector2.ZERO, 载荷4)
			if not ((会话.equipped_items as Dictionary).get(装备部位表.昆虫四, {}) as Dictionary).is_empty():
				_失败.append("③b 编造 131 段 id 被穿进虫槽了 ⇒ 处理函数分类闸（物品表 category==装备）掉了")
			elif (会话._占用条(会话.inventory, 2) as Dictionary).is_empty():
				_失败.append("③b 分类闸拒绝不许动背包格（件被吞掉找不回来）")

	# ④ 强化入口「身上没虫」也不置灰（报修②正主）。旧写法 `disabled = 强化目标.is_empty()` ⇒
	#    四格空 + 背包无虫时置灰；原版 `_strengthBtn`（`KunChongPanel.as:205-211`）**整文件
	#    没有一处 enabled/disabled 赋值** ⇒ 永远可点，开窗后提交被「请放入昆虫」拦（⑦ 腿已量）。
	会话.inventory.clear()
	窗.call("_render_page")
	for _帧 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	var 入口 := (页.get_node_or_null("强化寄坏虫") as Button) if 页 != null else null
	var 弹窗 := (页.find_child("昆虫强化弹窗", true, false) as Control) if 页 != null else null
	if 入口 == null or 弹窗 == null:
		_失败.append("④ 取不到「强化寄坏虫」入口或弹窗")
	else:
		if 入口.disabled:
			_失败.append("④ 身上与背包都没虫时入口被置灰了 ⇒ 原版从不 disable 这枚钮（报修②「不能点击」）")
		if int(弹窗.get_meta("kunchong_slot", -9)) != 0:
			_失败.append("④ 没虫时该把**0**传下去（提交靠它拦「请放入昆虫」），实得 %s" % str(弹窗.get_meta("kunchong_slot")))
		if not (窗._昆虫强化态.get("虫", {}) as Dictionary).is_empty() or int(窗._昆虫强化态.get("位", -1)) != 0:
			_失败.append("④ 宿主 `虫/位` 该同步成空/0，实得 %s" % str([窗._昆虫强化态.get("虫"), 窗._昆虫强化态.get("位")]))

	# ⑤ 虫**只在背包**：入口照样可点，且目标兜到背包第一只、发的是**背包格号**
	#    （与「携入」同一口径：服务端 `_strengthen_kun_chong` 拿它 `inventory.get(slot)` 取件）。
	会话.inventory.clear()
	会话.inventory.append({"id": "01310001", "name": "蝉", "quantity": 1})	# 格1
	窗.call("_render_page")
	for _帧 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	入口 = 页.get_node_or_null("强化寄坏虫") if 页 != null else null
	弹窗 = 页.find_child("昆虫强化弹窗", true, false) as Control if 页 != null else null
	if 入口 == null or 弹窗 == null:
		_失败.append("⑤ 取不到入口或弹窗")
	else:
		if 入口.disabled:
			_失败.append("⑤ 虫只在背包里，入口也被置灰了（兜底扫描没跑？）")
		if String((窗._昆虫强化态.get("虫", {}) as Dictionary).get("id", "")) != "01310001" \
				or int(窗._昆虫强化态.get("位", -1)) != 1:
			_失败.append("⑤ 目标该兜到背包第一只虫、位=背包格1（携入口径），实得 %s"
				% str([窗._昆虫强化态.get("虫"), 窗._昆虫强化态.get("位")]))
		if int(弹窗.get_meta("kunchong_slot", -9)) != 1:
			_失败.append("⑤ 弹窗 `kunchong_slot` 该跟着兜底成 1，实得 %s" % str(弹窗.get_meta("kunchong_slot")))

	# ⑥ 双击/菜单「佩戴」那条路：按 id 算出的落位是 `KunChongE(-205)`，服务端拒
	#    （`_can_equip` 只放行 -200..-203）⇒ `equip_item` 的 -205 闸必须挡住且**不留幽灵键、不动背包**。
	if bool(会话.call("equip_item", "01310001", 0, 1)):
		_失败.append("⑥ 双击佩戴（不传指定槽位）算出 -205 却回了 true ⇒ 离线会穿出一条服务端不认的装备")
	if (会话.equipped_items as Dictionary).has(装备部位表.昆虫包):
		_失败.append("⑥ `equipped_items` 冒出 -205 键 ⇒ 幽灵数据（原版昆虫包只是**格子归属**，不是装备位）")
	if String((会话._占用条(会话.inventory, 1) as Dictionary).get("id", "")) != "01310001":
		_失败.append("⑥ 佩戴被拦时背包不该动（件还必须在格1）")

	# ⑦ 看别人（只读）：原版 `createCell:241-245` 只给 `_isMyself` 挂 MOUSE_UP ⇒ **落点根本不存在**。
	#    直接调 `初始化寄坏之术页(窗, 页, 只读档)`；`他人昆虫` 读 `窗._backend`，
	#    ④ 那腿留的是假后端（没有 `_parse_item_entry`）⇒ 先把 `_backend` 摘干净。
	窗.set("_backend", null)
	人物脚本.初始化寄坏之术页(窗, 页, {"装备串": "-"})
	var 槽一7 := 页.get_node_or_null("虫槽区域/寄坏槽一") as TextureButton if 页 != null else null
	if 槽一7 == null:
		_失败.append("⑦ 只读重初始化后取不到寄坏槽一")
	else:
		if int(槽一7.get("槽位号")) != 0:
			_失败.append("⑦ 看别人时槽位号该停在 0（不认领落点），实得 %d" % int(槽一7.get("槽位号")))
		if (槽一7.get("请求放入") as Signal).get_connections().size() != 0:
			_失败.append("⑦ 看别人时落点连线该拆干净（复用页面没拆 ⇒ 能把他人的格穿成我的）")
		var 起拖7 := 假虫来源.new()
		起拖7.槽位号 = 1
		if bool(槽一7.call("_can_drop_data", Vector2.ZERO, {"来源格": 起拖7, "归属": "背包", "物品id": "01310001"})):
			_失败.append("⑦ 只读页 `_can_drop_data` 还放行 ⇒ 槽位号!=0 的守卫没生效")

	# —— 还原：背包、四格、弹窗宿主开/放，再重渲染回「自己」态（⑤d 之后的腿接着用这页）——
	会话.inventory.clear()
	for 件 in 原背包:
		会话.inventory.append(件)
	for 槽号 in 虫槽四:
		if 原虫[槽号] == null:
			(会话.equipped_items as Dictionary).erase(槽号)
		else:
			(会话.equipped_items as Dictionary)[槽号] = 原虫[槽号]
	窗._昆虫强化态["开"] = 原开
	窗._昆虫强化态["放"] = 原放
	窗.call("_render_page")
	for _帧 in 3:
		await process_frame


## 2026-10-31 用户报修三条（昆虫强化面板）：
##   ① 没放入昆虫时结果格里不该有昆虫图标；
##   ② 已放入的昆虫详情框被强化面板盖住；
##   ③ 强化成功后详情框与「本次操作成功几率」停在旧值。
## AS3 真值：`updateView:109-137` 里的「有件」= `_itemData` —— 件落进 `_itemBox` 之前是 null
## ⇒ 产物格 `getNextLevelData:530` 返回 null、两行 `updateXingYunRatio:452` 写 0；
## `itemDatachanged:382-398` 按 `_itemData.position` 重取件（星级随新件走，件没了才清空）；
## 提示框挂 `PopUpMananger.stage`（`MToolTip.as:98-103`）⇒ 永远压在所有窗口之上。
func _验昆虫面板三修(窗, 会话) -> void:
	var 人物脚本 := load("res://脚本/界面/窗口/人物窗口.gd")
	var 虫槽四: Array = [装备部位表.昆虫一, 装备部位表.昆虫二, 装备部位表.昆虫三, 装备部位表.昆虫四]
	var 原背包: Array = (会话.inventory as Array).duplicate(true)
	var 原虫 := {}
	for 槽号 in 虫槽四:
		原虫[槽号] = (会话.equipped_items as Dictionary).get(槽号, null)
	var 原携虫: Dictionary = 窗._角色携入虫
	var 原携位 := int(窗._角色携入位置)
	var 原态: Dictionary = 窗._昆虫强化态.duplicate(true)

	# 目标走「背包带虫」那条（`_开寄坏之术带虫` 同一通道）：宿主上的携入件是一份**快照**，
	# 服务端回帧换的是会话里的新字典 ⇒ 快照不重取就会停在旧星级（③ 的病根）。
	for 槽号 in 虫槽四:
		(会话.equipped_items as Dictionary)[槽号] = {}
	会话.inventory.clear()
	会话.inventory.append({})
	会话.inventory.append({"id": "01310003", "name": "蜻蜓", "quantity": 1,
		"strengthen": 2, "aptitude": 1, "base_attr_value": 100})
	窗._角色携入虫 = (会话._占用条(会话.inventory, 2) as Dictionary).duplicate(true)
	窗._角色携入位置 = 2
	窗._昆虫强化态["开"] = true
	窗._昆虫强化态["放"] = false
	窗._昆虫强化态["镇"] = false
	窗._昆虫强化态["玉"] = false
	窗._昆虫强化态["张"] = 1
	窗.call("_render_page")
	for _帧 in 3:
		await process_frame
	var 页 := _取页(窗, "寄坏之术")
	var 弹窗 := 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	if 弹窗 == null:
		_失败.append("三修 取不到弹窗 ⇒ 三条都没量到")
		return
	var 产物 := 弹窗.get_node_or_null("底图/放置区底图/成功格/昆虫图标") as TextureRect
	var 富 := 弹窗.get_node_or_null("底图/强化区底图/强化消耗与几率") as RichTextLabel
	var 放入 := 弹窗.get_node_or_null("底图/放置区底图/开始提升按钮") as Button
	var 自动勾 := 弹窗.get_node_or_null("使用寄坏玉") as CheckBox
	var 提示层: Control = 人物脚本.提示宿主(弹窗)
	var 虫框: Control = 提示层.get_node_or_null("装备提示框") as Control if 提示层 != null else null
	if 产物 == null or 富 == null or 放入 == null or 虫框 == null:
		_失败.append("三修 缺 产物格/几率行/放入钮/装备提示框（%s/%s/%s/%s）" % [
			str(产物 != null), str(富 != null), str(放入 != null), str(虫框 != null)])
		return
	# ① 没放入：产物格空、两行 0、自动勾不可用、放置格/成功格悬停都不弹框
	if 产物.visible or 产物.texture != null:
		_失败.append("① 没放入昆虫，成功格里却亮着昆虫图标（用户报的那条）")
	if not 富.text.contains("消耗金币：0") or not 富.text.contains("成功几率：0%"):
		_失败.append("① 没放入时两行该写 0（原版 `_itemData` 为空），实测「%s」" % 富.text.replace("\n", " / "))
	if 自动勾 != null and not 自动勾.disabled:
		_失败.append("① 没放入时自动勾该不可用（`_autoCheckBox.enabled = _itemData`）")
	var 放置格 := 弹窗.get_node_or_null("底图/放置区底图/放置格") as Control
	var 成功格 := 弹窗.get_node_or_null("底图/放置区底图/成功格") as Control
	for 格变 in [放置格, 成功格]:
		var 格 := 格变 as Control
		if 格 == null:
			continue
		虫框.visible = false
		格.mouse_entered.emit()
		if 虫框.visible:
			_失败.append("① 没放入时悬停「%s」不该弹昆虫详情框" % String(格.name))
		虫框.visible = false
	# ② 放入之后出现；提示框层序必须压过弹窗（原版挂整屏 stage）
	放入.pressed.emit()
	await process_frame
	if not 产物.visible or 产物.texture == null:
		_失败.append("① 放入之后成功格该亮出下一级虫的图标（2 星 → 3 星 = 12 万 / 100%）")
	if not 富.text.contains("消耗金币：120000") or not 富.text.contains("成功几率：100%"):
		_失败.append("① 放入后两行该按 strength[3] 算（12 万 / 100%%），实测「%s」" % 富.text.replace("\n", " / "))
	if 放置格 != null:
		虫框.visible = false
		放置格.mouse_entered.emit()
		if not 虫框.visible or not _格子提示全文(虫框).contains("蜻蜓"):
			_失败.append("① 放入后悬停放置格该弹蜻蜓详情框（实读：%s）" % _格子提示全文(虫框).replace("\n", "⏎"))
		elif _层序(虫框) <= _层序(弹窗):
			_失败.append("② 详情框层序 %d 不高于强化弹窗 %d ⇒ 会被面板盖住（原版提示挂整屏 stage）"
				% [_层序(虫框), _层序(弹窗)])
		虫框.visible = false
	# ③ 服务端重下发那一格（整份换新字典）⇒ 面板与提示都该跟到新星级
	#    （`apply_backend_inventory` 走 `落位带洞` 的 `.duplicate(true)` ⇒ 宿主那份快照不会被就地改）
	会话.inventory[1] = {"id": "01310003", "name": "蜻蜓", "quantity": 1,
		"strengthen": 3, "aptitude": 1, "base_attr_value": 100}
	窗.call("_render_page")
	for _帧 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	# 整页重绘把提示层一起 free 掉了 ⇒ 详情框节点得现找（旧句柄是 freed）
	提示层 = 人物脚本.提示宿主(弹窗) if 弹窗 != null else null
	虫框 = 提示层.get_node_or_null("装备提示框") as Control if 提示层 != null else null
	if 弹窗 == null:
		_失败.append("③ 回帧重渲染后取不到弹窗")
	else:
		富 = 弹窗.get_node_or_null("底图/强化区底图/强化消耗与几率") as RichTextLabel
		放置格 = 弹窗.get_node_or_null("底图/放置区底图/放置格") as Control
		if 富 != null and (not 富.text.contains("消耗金币：130000") or not 富.text.contains("成功几率：95%")):
			_失败.append("③ 强化成功后成功几率该按新星级算（3→4 星：13 万 / 95%%），实测「%s」"
				% 富.text.replace("\n", " / "))
		if 虫框 != null and 放置格 != null:
			虫框.visible = false
			放置格.mouse_entered.emit()
			var 文 := _格子提示全文(虫框)
			if not 文.contains("强化等级　3"):
				_失败.append("③ 成功后的详情框该同步到 3 星（应含「强化等级　3」，实读：%s）"
					% 文.replace("\n", "⏎"))
			虫框.visible = false
	# 件没了（失败销毁那一支）⇒ 回到「没放入」（原版 `itemDatachanged` → `backItemToEquip`）
	会话.inventory[1] = {}
	窗.call("_render_page")
	for _帧 in 3:
		await process_frame
	页 = _取页(窗, "寄坏之术")
	弹窗 = 页.get_node_or_null("昆虫强化弹窗") as Control if 页 != null else null
	if 弹窗 != null:
		if bool(弹窗.get_meta("kunchong_in", false)):
			_失败.append("③ 件被销毁后格子该回到「没放入」（原版 → `backItemToEquip`）")
		var 产物2 := 弹窗.get_node_or_null("底图/放置区底图/成功格/昆虫图标") as TextureRect
		if 产物2 != null and 产物2.visible:
			_失败.append("③ 件没了成功格还亮着图标")

	# 还原：背包、四格、携入、弹窗宿主态，再重画回调用方看到的样子
	会话.inventory.clear()
	for 件 in 原背包:
		会话.inventory.append(件)
	for 槽号 in 虫槽四:
		if 原虫[槽号] == null:
			(会话.equipped_items as Dictionary).erase(槽号)
		else:
			(会话.equipped_items as Dictionary)[槽号] = 原虫[槽号]
	窗._角色携入虫 = 原携虫
	窗._角色携入位置 = 原携位
	for 键 in 原态:
		窗._昆虫强化态[键] = 原态[键]
	窗.call("_render_page")
	for _帧 in 3:
		await process_frame
	_同步腿跑完 = true


## 八门「突破瓶颈」那一串（2026-10-17 巡检 #8）。真值三处：
##  · 显隐 `JingMaiPanel.as:266`：`listId < MAX_MAI(4) && 已开穴位 >= 总穴位`（且要有统计帧）；
##  · 入口 `JingMaiPanel.throughHandler:349-351` → `JingMaiSource.showThroughWindow()` —— **只开弹窗**；
##  · 发包 `ThroughAllMaiWindow.throughHandler:195-214`：精华不够 / 神符不够 两道提示，
##    都够才 `requestMaiLevelUp()`（1290:3）+ `onCloseBtnClick` 关窗。
## 弹窗里那些数**全部来自客户端表**（`info.levelup[脉+1]` + `getTroughMaiString(脉+1)`）：
## 原版 `Client.onMaiLevelupInfo` 是**空函数**、`requestMaiLevelUpInfo` 没人调 ⇒ 1290:5 是死帧。
func _验突破瓶颈(窗, 会话) -> void:
	var 假 := 假后端.new()
	var 通知: Array = []
	会话.notification_requested.connect(func(文: String) -> void: 通知.append(文))
	# ── ① 入口钮显隐四态
	var 入口: Button = await _刷突破入口(窗, 会话, {})
	if 入口 == null:
		_失败.append("八门页找不到入口钮「门列表/按钮列/突破瓶颈」")
		return
	if 入口.visible:
		_失败.append("还没有统计帧时「突破瓶颈」不该亮（原版那一刻 maiData 还是空）")
	入口 = await _刷突破入口(窗, 会话, {"list_id": 0, "total_points": 62, "exploded_total": 61})
	if 入口 == null:
		_失败.append("刷新后取不到入口钮 ⇒ 显隐那一腿没量到")
		return
	if 入口.visible:
		_失败.append("穴位只开了 61/62 时「突破瓶颈」不该亮（原版要求全部开完）")
	入口 = await _刷突破入口(窗, 会话, {"list_id": 4, "total_points": 62, "exploded_total": 62})
	if 入口 != null and 入口.visible:
		_失败.append("已经到仙•八门（list_id=4 = MAX_MAI，没有下一脉）时入口钮不该亮")
	入口 = await _刷突破入口(窗, 会话, {"list_id": 0, "total_points": 62, "exploded_total": 62,
		"attrs": {"atk": 11, "def": 22, "bsk": 33, "avd": 44, "maxhp": 55, "maxmp": 66}})
	if 入口 == null:
		_失败.append("刷新后取不到入口钮 ⇒ 突破那一串后面的腿没法量")
		return
	if not 入口.visible:
		_失败.append("穴位全开（62/62）+ 还有下一脉 + **总览视图** ⇒ 入口钮该亮，实测没亮")
	# ── ①b 门内容视图里这颗钮**根本不该在场**（原版 `showZongLanView:110-120` 只在总览 addChild）
	var 门视图钮: Button = await _刷突破入口(窗, 会话, {"list_id": 0, "total_points": 62,
		"exploded_total": 62}, false)
	if 门视图钮 == null:
		_失败.append("切到开门视图后取不到入口钮")
	elif 门视图钮.visible:
		_失败.append("门内容视图里「突破瓶颈」该收起来（原版只在总览视图挂这颗钮）")
	入口 = await _刷突破入口(窗, 会话, {"list_id": 0, "total_points": 62, "exploded_total": 62,
		"attrs": {"atk": 11, "def": 22, "bsk": 33, "avd": 44, "maxhp": 55, "maxmp": 66}})
	if 入口 == null:
		_失败.append("①b 之后切回总览取不到入口钮 ⇒ 突破那一串后面的腿没法量")
		return
	# ── ② 点入口钮：**只许开弹窗，一颗包都不许发**（修前正是这里当场发 1290:3）
	窗.set("_backend", 假)
	var 弹窗 := 入口.get("popup") as Control
	if 弹窗 == null:
		_失败.append("入口钮的 `popup` 没指向「突破瓶颈弹窗」（场景 NodePath 断了？）")
		return
	入口.pressed.emit()
	await process_frame
	if not 假.八门.is_empty():
		_失败.append("点开突破弹窗那一刻不该发八门包，实测发了 %s" % str(假.八门))
	if not 弹窗.visible:
		_失败.append("点了入口钮「突破瓶颈弹窗」该亮起来")
	# ── ③ 弹窗里的数是真值（场景烘的是美术按表八门抄的示例：8张 / 攻击1040…）
	var 钮 := 弹窗.find_child("突破瓶颈按钮", true, false) as Button
	if 钮 == null or 钮.pressed.get_connections().is_empty():
		_失败.append("弹窗里那颗「突破瓶颈按钮」没接线（点了不会发协议）")
		return
	var 标题 := 弹窗.get_node_or_null("突破标题") as Label
	if 标题 == null or 标题.text != "开启里•八门":
		_失败.append("脉 0 的标题该是「开启里•八门」（THROUGHALLMAI_WINDOW_TITLE），实测「%s」"
			% ["无" if 标题 == null else 标题.text])
	var 配置 := _经脉突破配置(1)
	var 符 := 弹窗.get_node_or_null("总块/神符说明") as Label
	var 期望符 := "开启里•八门需要消耗八门神符%d张，查克拉精华%d\n开启里•八门成功几率：%d" % [
		int((配置.get("item", {}) as Dictionary).get("count", 0)),
		int(配置.get("zq", 0)), int(配置.get("prob", 0))]
	if 符 == null or 符.text != 期望符:
		_失败.append("神符那两行该按 info.levelup[脉+1] 拼，期望「%s」实测「%s」"
			% [期望符, "无" if 符 == null else 符.text])
	# 块1 = 统计帧的 `totalAttrGain`（fields[4]，后端解析成 `attrs`）；块3 = 下一脉整脉合计（客户端表）
	var 栏1 := 弹窗.get_node_or_null("总块/块1/属性栏1") as Label
	var 栏2 := 弹窗.get_node_or_null("总块/块1/属性栏2") as Label
	if 栏1 == null or not 栏1.text.contains("攻击：11") or not 栏1.text.contains("闪避：44"):
		_失败.append("块1 那行该是统计帧下发的当前属性（含「攻击：11」「闪避：44」），实测「%s」"
			% ["无" if 栏1 == null else 栏1.text])
	if 栏2 == null or not 栏2.text.contains("生命上限：55") or not 栏2.text.contains("查克拉上限：66"):
		_失败.append("块1 第二行该含「生命上限：55」「查克拉上限：66」，实测「%s」"
			% ["无" if 栏2 == null else 栏2.text])
	var 合计 := _下一脉合计(1)
	var 新栏 := 弹窗.get_node_or_null("总块/块3/滚动区/VBoxContainer/属性栏") as Label
	var 名号 := {"atk": "攻击", "def": "防御", "bsk": "暴击", "avd": "闪避",
		"maxhp": "生命上限", "maxmp": "查克拉上限"}
	if 新栏 == null:
		_失败.append("块3 的属性栏取不到")
	else:
		for 键 in 名号:
			var 期望串 := "%s：%d" % [String(名号[键]), int(合计.get(键, 0))]
			if not 新栏.text.contains(期望串):
				_失败.append("块3 该显示下一脉（里•八门）整脉合计 %s（门 + 每穴累加，独立算的），实测「%s」"
					% [期望串, 新栏.text])
		# ⚠️ 别再用"含不含 1299"判有没有被覆盖：美术烘的那版**就是照表抄的**，
		#    里•八门整脉合计实测 `atk=1299 def=653 bsk=230 avd=545 maxhp=2847 maxmp=717`，
		#    跟示例数一模一样 ⇒ 那条判据**永远红**（2026-10-17 踩到）。
		#    真正的区分点是**排版**：场景那版是无空格的 `"攻击：1299防御：653…"`，
		#    我们覆盖成带空格的两行 ⇒ 直接比整串。
		var 期望全文 := "攻击：%d 防御：%d  暴击：%d  闪避：%d\n生命上限：%d  查克拉上限：%d" % [
			int(合计.get("atk", 0)), int(合计.get("def", 0)), int(合计.get("bsk", 0)),
			int(合计.get("avd", 0)), int(合计.get("maxhp", 0)), int(合计.get("maxmp", 0))]
		if 新栏.text != 期望全文:
			_失败.append("块3 属性栏该是覆盖后的两行排版，期望「%s」实测「%s」" % [期望全文, 新栏.text])
	var 介绍 := 弹窗.get_node_or_null("总块/块3/滚动区/VBoxContainer/介绍栏") as Label
	if 介绍 == null or 介绍.text != "开通里•八门内穴道与每一门内穴道完整开通你将获得属性加成：":
		_失败.append("块3 橙句该是 THROUGHALLMAI_WINDOW_LABEL_3 原文，实测「%s」"
			% ["无" if 介绍 == null else 介绍.text])
	var 奖励 := 弹窗.get_node_or_null("总块/块3/滚动区/VBoxContainer/说明栏") as Label
	if 奖励 == null or not 奖励.text.contains("全部里•八门内穴道打通后，所有忍术的当前层数+1层"):
		_失败.append("块3 绿句该是 THROUGHALLMAI_WINDOW_MIDDLE 原文，实测「%s」"
			% ["无" if 奖励 == null else 奖励.text])
	var 数量 := 弹窗.get_node_or_null("总块/道具框/数量") as Label
	var 框 := 弹窗.get_node_or_null("总块/道具框") as Control
	if 数量 == null or 数量.text != "0":
		_失败.append("背包里没有八门神符时道具格数量该是 0，实测「%s」"
			% ["无" if 数量 == null else 数量.text])
	if 框 != null and 框.modulate == Color(1, 1, 1):
		_失败.append("持有 0 < 需要 %d 时道具格该压灰（原版 applyGrayFilter）"
			% int((配置.get("item", {}) as Dictionary).get("count", 0)))
	# ── ④ 那颗钮的两道校验：不够只出提示、**绝不发包**
	会话.player_stats["zq"] = 0
	通知.clear()
	钮.pressed.emit()
	await process_frame
	if 通知.find("很抱歉，你的精华不够！") < 0 or not 假.八门.is_empty():
		_失败.append("精华 0 时该提示「很抱歉，你的精华不够！」且不发 1290:3，实测通知 %s、包 %s"
			% [str(通知), str(假.八门)])
	会话.player_stats["zq"] = int(配置.get("zq", 0))
	通知.clear()
	钮.pressed.emit()
	await process_frame
	if not 假.八门.is_empty():
		_失败.append("神符一张没有时不该发突破包，实测 %s" % str(假.八门))
	if not 通知.any(func(文: String) -> bool: return String(文).contains("不够")):
		_失败.append("神符不够该提示「很抱歉，您的<道具名>不够！」（FAMILLY_MANAGER_SORRY_BUGOU），实测通知 %s"
			% str(通知))
	# ── ⑤ 两道都过 ⇒ 才发 1290:3，并且**立刻关窗**（原版 onCloseBtnClick）
	会话.inventory.append({"id": str((配置.get("item", {}) as Dictionary).get("id", 0)),
		"quantity": int((配置.get("item", {}) as Dictionary).get("count", 0))})
	通知.clear()
	钮.pressed.emit()
	await process_frame
	if 假.八门 != [[3, 0, 0, 0]]:
		_失败.append("材料与精华都够时该发一发 MAI 动作 3（突破），实测 %s" % str(假.八门))
	if 弹窗.visible:
		_失败.append("发完突破包弹窗该关掉（原版 onCloseBtnClick）")
	# ── ⑥ 补齐材料后重开一次：数量与灰显跟着真背包走
	入口 = await _刷突破入口(窗, 会话, {"list_id": 0, "total_points": 62, "exploded_total": 62})
	if 入口 == null:
		_失败.append("⑥ 刷新后取不到入口钮")
	else:
		var 需要数 := int((配置.get("item", {}) as Dictionary).get("count", 0))
		var 弹窗2 := 入口.get("popup") as Control
		入口.pressed.emit()
		await process_frame
		var 数2: Label = null
		var 框2: Control = null
		if 弹窗2 != null:
			数2 = 弹窗2.get_node_or_null("总块/道具框/数量") as Label
			框2 = 弹窗2.get_node_or_null("总块/道具框") as Control
		if 数2 == null or 数2.text != str(需要数):
			_失败.append("补了神符再开，数量该是背包里的张数 %d，实测「%s」"
				% [需要数, "无" if 数2 == null else 数2.text])
		if 框2 != null and 框2.modulate == Color(0.45, 0.45, 0.45):
			_失败.append("够数时道具格不该还是灰的")
		入口.pressed.emit()		# 关掉，别把弹窗/暗幕留给后面的腿
		await process_frame
	# ── ⑦ 弹窗开着时页面重建 ⇒ 屏幕层里不能留僵尸窗（§3.200 手里剑那一型的八门版）。
	#     `突破瓶颈按钮._搬到屏幕层` 把弹窗 reparent 到 root 的「屏幕弹窗层」，页面 `queue_free`
	#     带不走它；留下的那张连的是已释放的旧页面 ⇒ 亮着却点不动，而 `突破瓶颈暗幕` 是全屏
	#     `MOUSE_FILTER_STOP`，一直亮着会把**整屏**点击吞掉（比手里剑更凶）。
	入口 = await _刷突破入口(窗, 会话, {"list_id": 0, "total_points": 62, "exploded_total": 62,
		"attrs": {"atk": 11, "def": 22, "bsk": 33, "avd": 44, "maxhp": 55, "maxmp": 66}})
	if 入口 == null:
		_失败.append("⑦ 刷新后取不到入口钮 ⇒ 僵尸弹窗这一腿没量到")
		窗.set("_backend", null)
		return
	var 弹窗7 := 入口.get("popup") as Control
	if 弹窗7 == null:
		_失败.append("⑦ 入口钮的 `popup` 取不到")
		窗.set("_backend", null)
		return
	入口.pressed.emit()
	await process_frame
	var 数7 := _层同名("突破瓶颈弹窗")
	if 数7 != [1, 1]:
		_失败.append("点开时屏幕层该只有 1 枚、且亮着（弹窗确实搬出去了），实测 亮%d/共%d"
			% [数7[0], 数7[1]])
	# 服务端来一帧状态 ⇒ `_refresh_current` ⇒ 整棵 `_content` 重建（页面是新实例）
	窗.call("_refresh_current")
	for _帧 in 4:
		await process_frame
	数7 = _层同名("突破瓶颈弹窗")
	if 数7 != [0, 0]:
		_失败.append("重绘后屏幕层里不该还留着一枚突破弹窗（点不动的僵尸窗），实测 亮%d/共%d"
			% [数7[0], 数7[1]])
	var 暗幕 := root.get_node_or_null("屏幕弹窗层/突破瓶颈暗幕") as CanvasItem
	if 暗幕 != null and 暗幕.visible:
		_失败.append("重绘后暗幕该跟着收掉，否则整屏点击一直被全屏 STOP 吞着")
	# 再点开 ⇒ 必须是**活的**那一张：名字没被层里旧件顶成自动名、点「突破瓶颈」真发 1290:3
	入口 = await _刷突破入口(窗, 会话, {"list_id": 0, "total_points": 62, "exploded_total": 62,
		"attrs": {"atk": 11, "def": 22, "bsk": 33, "avd": 44, "maxhp": 55, "maxmp": 66}})
	var 弹窗8 := (入口.get("popup") as Control) if 入口 != null else null
	if 弹窗8 == null:
		_失败.append("⑦ 重绘后取不到入口钮的 `popup` ⇒ 后半腿没量到")
	else:
		入口.pressed.emit()
		await process_frame
		var 数8 := _层同名("突破瓶颈弹窗")
		if 数8 != [1, 1]:
			_失败.append("重绘后再点开：屏幕层该只有 1 枚、亮着，实测 亮%d/共%d" % [数8[0], 数8[1]])
		if String(弹窗8.name) != "突破瓶颈弹窗":
			_失败.append("搬进屏幕层的弹窗名不该被层里旧件顶成自动名，实测「%s」" % 弹窗8.name)
		var 钮8 := 弹窗8.find_child("突破瓶颈按钮", true, false) as Button
		if 钮8 == null:
			_失败.append("重绘后那张弹窗里找不到「突破瓶颈按钮」")
		else:
			if 钮8.pressed.get_connections().size() != 1:
				_失败.append("弹窗那颗钮该只接 1 条线（多连会一次发好几跳），实测 %d 条"
					% 钮8.pressed.get_connections().size())
			假.八门.clear()
			通知.clear()
			钮8.pressed.emit()
			await process_frame
			if 假.八门 != [[3, 0, 0, 0]]:
				_失败.append("重绘后新开的那张窗点「突破瓶颈」该发一发 1290:3，实测 %s" % str(假.八门))
			if not 通知.is_empty():
				_失败.append("突破发成功不该刷回执（§3.200 口径），实测 %s" % str(通知))
			if 弹窗8.visible:
				_失败.append("发完突破包那张窗该关掉（原版 onCloseBtnClick）")
	窗.set("_backend", null)


## 「屏幕弹窗层」里同名的窗：[亮着的枚数, 总枚数]。搬进那层的窗已经不属于页面，
## 页面重绘后它是**独立存活**的 ⇒ 只能从 root 那层数（同 `手里剑修炼页回归测试`）。
func _层同名(名: String) -> Array[int]:
	var 层 := root.get_node_or_null("屏幕弹窗层") as CanvasLayer
	var 亮 := 0
	var 共 := 0
	if 层 == null:
		return [0, 0]
	for 子 in 层.get_children():
		if String(子.name) != 名:
			continue
		共 += 1
		if (子 as CanvasItem).visible:
			亮 += 1
	return [亮, 共]


## 2054 的物品体：**照服务端的 EQUIPMENT 编码**拼（`_encode_item_payload`：
## 昆虫的 `section == "ZhuangBei"` ⇒ `is_equipment_item` 为真 ⇒ `common_fields[0] = 1`，
## 后面接 19 段装备字段；第一版手编成 `2&…`（普通物品）是**假绿**——短体走不到
## `values[22] = strengthen`，格下那行「蝉+3」永远拼不出来）。
func _虫体(号: String, 格: int, 强化: int) -> String:
	var 段 := ["1", 号, str(格), "1", "0", "0", "1", "测试", "0", "7001",
		"0", "100", "100", "4", "30", "0", "5", "-", "0", "0", "0", "-",
		str(强化), "-", "0", "0", "0", "0", "0"]
	return "&".join(段)


## 灌一份八门状态 → 重渲染 → 回八门页取入口钮。
func _刷突破入口(窗, 会话, 状态: Dictionary, 总览: bool = true) -> Button:
	会话.cultivation_states["八门"] = 状态
	窗.call("_refresh_current")
	for _帧 in 4:
		await process_frame
	var 页 := _取页(窗, "八门")
	if 页 == null:
		return null
	# 原版这颗钮**只挂在总览视图**（`showZongLanView` addChild/removeChild），而我们的默认视图
	# 是开门 ⇒ 想让它按判据亮起来，得先切到总览。走**真按钮**的 `pressed`，顺带验接线。
	var 页签 := 页.get_node_or_null("门列表/按钮列/%s" % ("总览" if 总览 else "开门")) as Button
	if 页签 == null:
		return null
	页签.pressed.emit()
	await process_frame
	return 页.get_node_or_null("门列表/按钮列/突破瓶颈") as Button


## 门**自己**读一遍 `数据/经脉.json`（不复用 `人物窗口.突破配置`）—— 两边各算各的才叫对照。
func _经脉表() -> Dictionary:
	var 包: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/经脉.json"))
	return 包 as Dictionary if 包 is Dictionary else {}


func _经脉突破配置(脉: int) -> Dictionary:
	var 信息: Dictionary = _经脉表().get("info", {}) as Dictionary
	var 表: Dictionary = (信息.get("levelup", {}) as Dictionary)
	return (表.get(str(脉), {}) as Dictionary)


## 原版 `JingMaiSource.getTroughMaiString`：整脉**每一门的 attr/value** 加**该门每一个穴位的 attr/value**。
func _下一脉合计(脉: int) -> Dictionary:
	var 合计: Dictionary = {}
	var 条: Dictionary = (_经脉表().get(str(脉), {}) as Dictionary)
	for 门 in (条.get("mai", {}) as Dictionary).values():
		var 门条 := 门 as Dictionary
		_累加(合计, String(门条.get("attr", "")), int(门条.get("value", 0)))
		for 穴 in (门条.get("pts", {}) as Dictionary).values():
			var 穴条 := 穴 as Dictionary
			_累加(合计, String(穴条.get("attr", "")), int(穴条.get("value", 0)))
	return 合计


func _累加(合计: Dictionary, 属性名: String, 值: int) -> void:
	if 属性名.is_empty():
		return
	合计[属性名] = int(合计.get(属性名, 0)) + 值


func _扩展面板(窗) -> Panel:
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	var 页面 := 内容.find_child("原版人物窗口内容", true, false) as Control
	return 页面.get_node_or_null("人物扩展页") as Panel if 页面 != null else null


func _取页(窗, 名: String) -> Control:
	var 面板 := _扩展面板(窗)
	return null if 面板 == null else 面板.get_node_or_null("%s内容" % 名) as Control


## 门**自己**读一遍 Etc 表（不复用 `人物窗口.提升配置`）—— 两边各算各的才叫对照。
func _原版杂项() -> Dictionary:
	var 包: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/原版杂项.json"))
	return 包 as Dictionary if 包 is Dictionary else {}


func _提升表配置(族表: String, 阶: int) -> Dictionary:
	var 段: Dictionary = _原版杂项().get(族表, {}) as Dictionary
	var 行: Dictionary = 段.get("stage%d" % 阶, {}) as Dictionary
	return 行.get("stageUp", {}) as Dictionary


func _读磁盘表(表名: String) -> Dictionary:
	var 包: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/%s.json" % 表名))
	return 包 as Dictionary if 包 is Dictionary else {}


## 表里的显示名：物品表键是**八位补零**、怪物表是裸数字 ⇒ 两种形态都试一次。
func _表名(表: Dictionary, 号: Variant) -> String:
	var 键 := str(int(str(号)))
	if not 表.has(键) and 表.has(键.pad_zeros(8)):
		键 = 键.pad_zeros(8)
	return str((表.get(键, {}) as Dictionary).get("name", ""))


## ⑨ 写轮眼 / 柔拳的**按阶段说明文案**回表。
##
## 原版这两句是**运行期现取**的：`TongshuWindow.as:589`（`TONGSHU_WINDOW_SAY_TEXTFIELD`
## 用 `_curSageData.levelUp` 的 mobid / itemId 填）与 `RouQuanPanel.as:417`
## （`ROUQUAN_TISHENG_DESC` 用 `levelUp.itemId / gain` 填）。
## 本工程把它**烘进了 .tscn**（12 + 8 段），烘死本身可以，但手抄就会错 ——
## 这一腿第一次跑就抓出两处：
##   · 写轮眼 11 阶（轮回写轮眼）写「长角砂**十**兽」，`数据/怪物.json:1000044` 是「长角砂**土**兽」；
##   · 柔拳八条全写「秘**籍**」，而物品表与原版语言表都是「秘**笈**」
##     （`en_US$message_properties.as` 里 `秘籍` **0 次**、`秘笈` 13 次）。
## ⚠️ 只读磁盘文本、不 load 场景（同 `木叶村NPC回归测试` 的口径）：这两页的场景实例化
##    要几百毫秒，而这里量的是**静态文案**，运行期没有人覆盖它。
func _验阶段文案() -> void:
	var 杂项 := _原版杂项()
	var 物品 := _读磁盘表("物品")
	var 怪物 := _读磁盘表("怪物")

	# ── 写轮眼：12 阶 × 【怪】【物】，按树序交替出现 ⇒ 期望序列也是「怪,物,怪,物…」
	var 眼段 := _取方括号名("res://场景/界面/窗口/人物/页面/写轮眼页.tscn")
	var 眼期望: Array[String] = []
	var 眼表: Dictionary = 杂项.get("XieLunYan", {}) as Dictionary
	for 阶 in range(1, 13):
		var 升级: Dictionary = (眼表.get("stage%d" % 阶, {}) as Dictionary).get("levelUp", {}) as Dictionary
		if 升级.is_empty():
			_失败.append("⑨ 原版杂项 XieLunYan.stage%d 没有 levelUp ⇒ 这一腿没法对照" % 阶)
			return
		眼期望.append(_表名(怪物, 升级.get("mobid", 0)))
		眼期望.append(_表名(物品, 升级.get("itemId", 0)))
	if 眼段.size() != 眼期望.size():
		_失败.append("⑨ 写轮眼页的【】段数是 %d，期望 24（12 阶 × 怪/物）—— 说明节点被增删过，这条得人工核"
			% 眼段.size())
	else:
		for i in 眼期望.size():
			if 眼段[i] != 眼期望[i]:
				_失败.append("⑨ 写轮眼第 %d 阶的「%s」和表里的「%s」不一致"
					% [int(i / 2) + 1, 眼段[i], 眼期望[i]])

	# ── 柔拳：8 条整句，句里【物】两次 + 一个「N-M级」
	var 拳表: Dictionary = 杂项.get("RouQuan", {}) as Dictionary
	var 拳文 := FileAccess.get_file_as_string("res://场景/界面/窗口/人物/页面/柔拳页.tscn")
	var 句 := RegEx.create_from_string("text = \"(当前境界下[^\"]*)\"")
	var 抓到句 := 0
	for 匹 in 句.search_all(拳文):
		抓到句 += 1
		var 阶 := 抓到句
		if 阶 > 8:
			_失败.append("⑨ 柔拳页多出一第 %d 条「当前境界…」句（表里只有 8 阶）" % 阶)
			break
		var 升级: Dictionary = (拳表.get("stage%d" % 阶, {}) as Dictionary).get("levelUp", {}) as Dictionary
		if 升级.is_empty():
			_失败.append("⑨ 原版杂项 RouQuan.stage%d 没有 levelUp" % 阶)
			continue
		var 名 := _表名(物品, 升级.get("itemId", 0))
		var 段落 := String(匹.get_string(1))
		var 括号 := _括内名(段落)
		if 括号.size() != 2:
			_失败.append("⑨ 柔拳第 %d 阶句里应有两处【物品名】，实测 %d 处：%s" % [阶, 括号.size(), 段落])
		for 段名 in 括号:
			if 段名 != 名:
				_失败.append("⑨ 柔拳第 %d 阶写「%s」，物品表是「%s」" % [阶, 段名, 名])
		var 级 := RegEx.create_from_string("(\\d+-\\d+)级").search(段落)
		var 期望级 := str(升级.get("gain", ""))
		if 级 == null:
			_失败.append("⑨ 柔拳第 %d 阶句里没有「N-M级」（期望 %s级）：%s" % [阶, 期望级, 段落])
		elif String(级.get_string(1)) != 期望级:
			_失败.append("⑨ 柔拳第 %d 阶写「%s级」，表里 gain 是「%s」" % [阶, 级.get_string(1), 期望级])
	if 抓到句 != 8:
		_失败.append("⑨ 柔拳页应有 8 条「当前境界…」说明，实测 %d 条" % 抓到句)


## 页面上所有 `text = "【xxx】"` 里的 xxx，按出现顺序。
func _取方括号名(路径: String) -> Array[String]:
	var 出: Array[String] = []
	var 则 := RegEx.create_from_string("text = \"【([^】]+)】\"")
	for 匹 in 则.search_all(FileAccess.get_file_as_string(路径)):
		出.append(String(匹.get_string(1)))
	return 出


## 一句富文本里所有【xxx】的内容。
func _括内名(段落: String) -> Array[String]:
	var 出: Array[String] = []
	for 匹 in RegEx.create_from_string("【([^】]+)】").search_all(段落):
		出.append(String(匹.get_string(1)))
	return 出


func _表最高阶(族表: String) -> int:
	var 段: Dictionary = _原版杂项().get(族表, {}) as Dictionary
	var 最高 := 0
	for 键 in 段:
		最高 = maxi(最高, int(String(键).trim_prefix("stage")))
	return 最高


## ShaderMaterial 的 `get_shader_parameter` 对**从未显式写过**的参数回 null（.tres 里没这条、
## 着色器默认值不进表），换算前先过一手 ⇒ "没写过"按 0 处理。
func _灰量(材: ShaderMaterial) -> float:
	var 值 = 材.get_shader_parameter("gray_amount")
	return 0.0 if 值 == null else float(值)


## 从 n 的**父链**一路走到根，任一 Control `clip_contents=true` 就 true。
## 框能不能画到面板外，不是 offset 说了算，是这条链上第一块裁层说了算。
func _链上有裁(n: Node) -> bool:
	var 级 := n.get_parent()
	while 级 != null and 级 != root:
		if 级 is Control and (级 as Control).clip_contents:
			return true
		级 = 级.get_parent()
	return false


## 技能格下第一枚 TextureRect = 原版 `SkillCell.icon` 那颗图标。
## ⚠ 按**类型**扫不按名：tscn 里五格名字不同口径（「技能图标轮回·灵魂吞噬」vs
## 「技能轮回·吞噬」），按名匹配就是假绿清单第 10 种的形状。
func _格图标(格: Node) -> TextureRect:
	if 格 == null:
		return null
	for 子 in 格.get_children():
		if 子 is TextureRect:
			return 子 as TextureRect
	return null


func _停(原因: String) -> void:
	push_error("人物秘术页回归测试：中断 - %s" % 原因)
	quit(1)


## ⑩ **八个子页全扫**：凡是「一路可见 + 有内容（文字或图标）+ 没置灰」的 Button，
## 必须挂着 `pressed`/`button_up`/`toggled`/`button_down` 四条点击信号之一
## （OptionButton 是 Button 的子类，它的点击语义只有 `item_selected` ⇒ 按类型补进清单）。
##
## 为什么要有这一条（2026-10-18 巡检 #26）：这一轮在**角色页**抓到「战斗属性展开」——
## 原版它是 `CharPane.as:193` 挂在 `secondAttributePane.extraAttrBtn` 上的
## `onToggleCombatExtraAttr`（`:333-339`，开关「其他属性」那三格）；**写轮眼页**抓到每阶
## 提升说明里那枚绿字【怪名】—— 原版它走 `StructuredText.as:465` ⇒ `UI.as:760-776
## qusetClickText(2, mobid, mapid)` ⇒ `CharacterHandler.as:849 MovePlayerToMob`。
## 两枚都是**别人场景里烘好的控件**，宿主没接线，玩家点了静默不响；而既有各腿只点
## 自己关心的那几枚按钮 ⇒ **全套绿**。静态普查（数场景里没被代码提过的按钮名）也抓不到，
## 因为这两枚的名字分别被动态拼出来（`"%s全加"` 那套）和写成占位节点名（`【叛忍喽啰】`）。
##
## 置灰的放过：`disabled` 是本工程"显式承认未做"的口径（`人物窗口.gd` 的「本轮未做」那几处），
## 有 tooltip 说明，不算死钮。
## ⚠ 扫到 0 枚 = 本条自己假绿 ⇒ 直接判失败（第 22 条：会红的门才是门）。
func _验无死按钮(窗) -> void:
	var 扫到 := 0
	for 项 in 子页清单:
		var 名 := String(项[2])
		窗.call("_set_character_main_tab", int(项[0]))
		await process_frame
		窗.call("_set_character_sub_tab", int(项[1]))
		for _补帧 in 3:
			await process_frame
		var 页 := _取子页(窗, 名)
		if 页 == null:
			_失败.append("⑩ 切到「%s」之后取不到页面节点 ⇒ 死按钮那一腿没量到" % 名)
			continue
		var 死: Array[String] = []
		扫到 += 扫按钮(页, 死)
		for 条 in 死:
			_失败.append("⑩「%s」里的死按钮：%s（可见、有内容、没置灰，点击信号一条都没接）" % [名, 条])
	if 扫到 == 0:
		_失败.append("⑩ 一个可见按钮都没扫到 ⇒ 本条是假绿（页面没建出来？）")
	print("⑩ 扫到 %d 枚可见按钮，全部接线" % 扫到)


func _取子页(窗, 名: String) -> Control:
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	var 页面 := 内容.find_child("原版人物窗口内容", true, false) as Control
	if 页面 == null:
		return null
	# 「人物」是**内联面板**，不在 `人物扩展页` 那套按需建的子页里。
	if 名 == "人物":
		return 页面.get_node_or_null("原版人物属性面板") as Control
	var 面板 := 页面.get_node_or_null("人物扩展页") as Panel
	return null if 面板 == null else 面板.get_node_or_null("%s内容" % 名) as Control


## 递归收集死按钮；`一路可见下来` 保证**祖先藏着的不算**（阶段面板里没选中的那些阶本来就不可见）。
## 返回**参与判定的按钮数**（可见 + 有内容 + 没置灰），死按钮追加进 `死`。
func 扫按钮(节: Node, 死: Array[String]) -> int:
	var 计 := 0
	for 子 in 节.get_children():
		if not (子 is Control):
			continue
		var c := 子 as Control
		if not 一路可见下来(c):
			continue
		if c is Button:
			var 钮 := c as Button
			var 已接 := false
			# OptionButton **是** Button 的子类，它的点击语义是 `item_selected`（`控件矩形转储.gd:139`
			# 同一口径）⇒ 按类型补进清单。⚠ 不能无脑加：普通 Button 没有这条信号，
			#   `get_signal_connection_list("item_selected")` 对不存在的信号会 ERR_PRINT 刷满日志。
			var 信号清单 := ["pressed", "button_up", "toggled", "button_down"]
			if 钮 is OptionButton:
				信号清单.append("item_selected")
			for 信 in 信号清单:
				if not 钮.get_signal_connection_list(信).is_empty():
					已接 = true
			if (not 钮.text.is_empty() or 钮.icon != null) and not 钮.disabled:
				计 += 1
				if not 已接:
					死.append("%s(%s) @ %s" % [String(钮.name), 钮.text, String(钮.get_path())])
		计 += 扫按钮(c, 死)
	return 计


func 一路可见下来(c: Control) -> bool:
	var 节点: Node = c
	while 节点 is Control:
		if not (节点 as Control).visible:
			return false
		节点 = 节点.get_parent()
	return true


## ── ⑫「其他属性」浮板（2026-10-18 三面板巡检 #29）──────────────────────────────
##
## ⑩ 那条死按钮腿当初就是在**角色页**抓到这只箭头（那时它接的是「本轮未移植」提示）。
## 接线之后必须能量到**内容**，所以整串钉在这里。原版依据全部是
## `2.2.3/map_extract/out/mainlib_as/scripts/com/mxw/uifl/controls/char/CharPane.as`，逐行：
##  · `:167-195` 建三件（`combatExtraAttrBg` / `combatExtraAttrPane` / `combatExtraAttrExtendPane`）。
##    **位置是关系式、不是绝对像素**：`bg.x = secondAttributePane.x + width + 8`、`bg.y = pane.y`、
##    尺寸同 `secondAttributePane`（本工程 173×150）⇒ 板落在**页面根** (493, 84)
##    （`原版人物属性面板` 在页面根的原点是 69,20）。底板 `:173-174` 关了 `mouseEnabled`
##    ⇒ 本工程 `mouse_filter = IGNORE`。
##  · `:333-339` 开关只翻三件的 `visible`，**不发任何包** ⇒ 断言假后端三本账全程为 0。
##  · `:341-352` 三格固定行，`:523-532` 单行样式：标签宽 78、数值 x=78 宽 56，
##    `UI_ORANGE` 标签 / `UI_GREEN` 数值，值写 `"+ N %"`（两侧各一个空格，照抄）。
##    三行 y 由本工程「战斗属性」那六格量出：首行 21、行距 22、数值再低 1px。
##  · `:354-418` 附加行按 `4,5,1,2,6,7` **固定顺序**累加、只出 >0、每件最多 **3** 条
##    （`isCombatExtraTransformCard ? 4 : 3`，变身卡 = id 前缀 121/205）；
##  · `:540-544` 只算徽章(-22)…武器(-1)、宠物 1..5、羁绊(-50) ⇒ **灵器/忍具/神器/昆虫不进账**；
##  · `:474-516` 底板长高：基准 150，有附加行时 `87 + (22n + 18 + 4) + 12` = **121 + 22n**。
## ⚠️ 每一步之后都重新 `get_node_or_null`：整页每次回包重建，旧引用指向的是已 `queue_free` 的节点
##    （§3.206 那条纪律，本工程第 8 次引用）。
const 浮板其他属性题 := ["伤 害 减 免", "伤 害 反 弹", "无 视 防 御"]


func _箭头(窗) -> Button:
	var 页 := _取子页(窗, "人物")
	return null if 页 == null else 页.get_node_or_null("战斗属性展开") as Button


## 浮板**烘在场景里**，爹是页面根（`原版人物属性面板` 的父节点 `原版人物窗口内容`），
## 不挂属性面板里 —— 那块 `clip_contents = true`，而按原版这个关系式板本来就出窗。
## ⚠ 正因为是固定控件，它**一直存在**，"开着"必须按 `visible` 判（见 `_开板`）。
func _浮板(窗) -> Control:
	var 页 := _取子页(窗, "人物")
	if 页 == null or 页.get_parent() == null:
		return null
	return (页.get_parent() as Control).get_node_or_null("其他属性面板") as Control


## **开着**的那块板：节点是烘在场景里的，"板在不在"永远为真 ⇒ 只能按 `visible` 判开没开。
func _开板(窗) -> Control:
	var 板 := _浮板(窗)
	return null if 板 == null or not 板.visible else 板


## 第 `序` 行（0 起）的 `[题文字, 值文字, 题y, 值y]`；取不到返回空数组。
func _板行(板: Control, 序: int) -> Array:
	var 题 := 板.get_node_or_null("第%d行题" % 序) as Label
	var 值 := 板.get_node_or_null("第%d行值" % 序) as Label
	if 题 == null or 值 == null:
		return []
	return [题.text, 值.text, 题.position.y, 值.position.y]


## 三格固定行之后的**附加行**摘要：`[题文字, 值文字]` 逐行，遇到没亮的那行即停。
## ⚠ 附加行是**场景里烘死的 6 行池**（最多 6 行 = 六类加成），所以判"有没有这一行"
## 只能看 `visible`，不能看节点在不在 —— 按节点在不在判，池里那六行会永远算进去。
func _板附加行(板: Control) -> Array:
	var 出: Array = []
	for 序 in range(3, 9):
		var 题 := 板.get_node_or_null("第%d行题" % 序) as Label
		var 值 := 板.get_node_or_null("第%d行值" % 序) as Label
		if 题 == null or 值 == null or not 题.visible or not 值.visible:
			break
		出.append([题.text, 值.text])
	return 出


## 造一件"已穿在身上"的装备（直接写 `equipped_items`，不走 `穿装备()` —— 那条会动背包）。
func _装一件(会话, 位置: int, id: String, 特性: Array) -> void:
	会话.equipped_items[位置] = {
		"id": id, "equip_position": 位置, "special_attributes": 特性,
	}


func _特(型: int, 值: int) -> Dictionary:
	return {"attribute_type": 型, "attribute_value": 值}


func _验其他属性浮板(窗, 会话, 管理) -> void:
	var 率键 := ["damage_reduce", "damage_reflect", "ignore_def"]
	var 率值 := [7, 3, 12]
	var 原装备: Dictionary = (会话.equipped_items as Dictionary).duplicate(true)
	var 原率 := {}
	for 序 in 率键.size():
		var 键 := String(率键[序])
		原率[键] = 会话.player_stats.get(键, null)
		会话.player_stats[键] = 率值[序]
	会话.equipped_items.clear()
	# 换一份假后端：它只有 `收到 / 八门 / 结印` 三本账 ⇒ 点箭头**一个包都不该发**（`:333-339`）。
	var 假 := 假后端.new()
	窗.set("_backend", 假)
	管理.call("打开", "人物")
	for _帧 in 4:
		await process_frame
	窗.call("_set_character_main_tab", 0)
	await process_frame
	窗.call("_set_character_sub_tab", 0)
	for _帧 in 3:
		await process_frame

	# ── ① 默认**关着**，但箭头可见且接了线（不靠 disabled 承认没做）
	var 展开 := _箭头(窗)
	if 展开 == null:
		_失败.append("⑫ 角色页取不到「战斗属性展开」⇒ 这一整串没量到")
		窗.set("_backend", null)
		假.free()
		_恢复其他属性(窗, 会话, 原装备, 原率, 率键)
		return
	if not 展开.visible:
		_失败.append("⑫ 看自己时箭头该可见（原版 :193 无条件挂 CLICK），实测藏着")
	if 展开.get_signal_connection_list("pressed").is_empty():
		_失败.append("⑫ 箭头没接 pressed ⇒ 又是⑩那种死钮")
	var 默认板 := _浮板(窗)
	if 默认板 == null:
		_失败.append("⑫ 场景里没烘出「其他属性面板」⇒ 箭头点了不会有板"
			+ "（架构闸：固定控件烘在 .tscn，不许页面脚本运行时 new）")
	elif 默认板.visible:
		_失败.append("⑫ 没点之前浮板就该藏着（原版三件建好但 visible=false，:333-339）")

	# ── ② 点开：位置 / 尺寸 / 不吃点击 / 标题 / 无附加行时不垫底板
	展开.pressed.emit()
	for _帧 in 3:
		await process_frame
	var 板 := _开板(窗)
	if 板 == null:
		_失败.append("⑫ 点了箭头之后浮板没显示（节点在=%s）" % str(_浮板(窗) != null))
		窗.set("_backend", null)
		假.free()
		_恢复其他属性(窗, 会话, 原装备, 原率, 率键)
		return
	if 板.position != Vector2(493.0, 84.0):
		_失败.append("⑫ 浮板该挂在页面根 (493,84)（关系式 `pane.x+width+8, pane.y`），实 %s"
			% str(板.position))
	if 板.size != Vector2(173.0, 150.0):
		_失败.append("⑫ 无附加行时板高该是基准 150（同 secondAttributePane），实 %s" % str(板.size))
	if 板.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_失败.append("⑫ 底板原版 `mouseEnabled=false`（:173-174）⇒ 该不吃点击，实 mouse_filter=%d"
			% 板.mouse_filter)
	var 标题 := 板.get_node_or_null("标题") as Label
	if 标题 == null or 标题.text != "其他属性" or 标题.position != Vector2(62.0, 0.0):
		_失败.append("⑫ 标题该是「其他属性」@(62,0)（`CharSecondAttributePane.init` 写死 x=62、"
			+ "`setTitleText` 不重新居中），实 %s" % (str(标题.text) if 标题 != null else "没有"))
	elif 标题.get_theme_font_size("font_size") != 12 or 标题.get_theme_color("font_color") != Color("#fff000"):
		_失败.append("⑫ 标题字号/色该是 12·#fff000（与「战斗属性」那格同款式），实 %d·%s"
			% [标题.get_theme_font_size("font_size"), str(标题.get_theme_color("font_color"))])
	if 板.get_node_or_null("顶图") == null:
		_失败.append("⑫ 没有「战斗属性」那块烘焙底（顶图）⇒ 六条深色横带与蜗牛图标没了")
	var 默认底板 := 板.get_node_or_null("底板") as Panel
	if 默认底板 == null:
		_失败.append("⑫ 场景里没烘出「底板」⇒ 有附加行时那层 9 宫格底没处垫")
	elif 默认底板.visible:
		_失败.append("⑫ 173×150 这块顶图本身就是完整底板，无附加行时不该再垫一层 Panel 把 9 宫格边框叠上去")

	# ── ③ 三格固定行：文案逐字（全角空格是原版写死的）、值 `+ N %`、橙/绿、12 号、y 21/43/65
	for 序 in 3:
		var 行 := _板行(板, 序)
		if 行.is_empty():
			_失败.append("⑫ 第 %d 格固定行没建出来" % 序)
			continue
		if 行[0] != 浮板其他属性题[序]:
			_失败.append("⑫ 第 %d 格文案该是「%s」（:344-346 逐字，含全角空格），实「%s」"
				% [序, 浮板其他属性题[序], 行[0]])
		if 行[1] != "+ %d %%" % 率值[序]:
			_失败.append("⑫ 第 %d 格值该是「+ %d %%」（:531 两侧各一空格），实「%s」" % [序, 率值[序], 行[1]])
		if 行[2] != 21.0 + 22.0 * 序 or 行[3] != 22.0 + 22.0 * 序:
			_失败.append("⑫ 第 %d 格 y 该是 %f/%f（首行 21、行距 22、数值低 1px），实 %s/%s"
				% [序, 21.0 + 22.0 * 序, 22.0 + 22.0 * 序, str(行[2]), str(行[3])])
		var 题节 := 板.get_node_or_null("第%d行题" % 序) as Label
		var 值节 := 板.get_node_or_null("第%d行值" % 序) as Label
		if 题节.size != Vector2(78.0, 18.0) or 值节.position.x != 115.0 or 值节.size != Vector2(56.0, 18.0):
			_失败.append(("⑫ 第 %d 格款式该是标签 @(37,·)78×18、数值 x=115 宽 56×18（:525-530），"
				+ "实标签 %s、数值 %s") % [序, str(题节.position) + str(题节.size), str(值节.position) + str(值节.size)])
		if 题节.get_theme_color("font_color") != Color("#ff9100") or 值节.get_theme_color("font_color") != Color("#00ff00"):
			_失败.append("⑫ 第 %d 格该是 UI_ORANGE 标签 / UI_GREEN 数值，实 %s / %s"
				% [序, str(题节.get_theme_color("font_color")), str(值节.get_theme_color("font_color"))])
		# 2026-10-25（用户喜欢背包数量 14px 的效果，要求人物面板数值也试试）：
		# 题仍 12（原版 MLabel 口径），**值**改成 14 且是有意偏离 ⇒ 这条按新值钉。
		if 题节.get_theme_font_size("font_size") != 12 or 值节.get_theme_font_size("font_size") != 14:
			_失败.append("⑫ 第 %d 格该是题 12 / 值 14（值 14 为 2026-10-25 用户要求的偏离；:525 的 134 是整格宽、不是字号），实 %d / %d"
				% [序, 题节.get_theme_font_size("font_size"), 值节.get_theme_font_size("font_size")])

	# ── ④ 再点一次**关**（板藏起来，节点还在 —— 它是烘在场景里的固定控件）
	展开 = _箭头(窗)
	if 展开 == null:
		_失败.append("⑫ 重建后取不到箭头 ⇒ 关板那一半没量到")
	else:
		展开.pressed.emit()
		for _帧 in 3:
			await process_frame
		if _开板(窗) != null:
			_失败.append("⑫ 再点一次箭头浮板没藏起来（原版 :336 三件一起藏）")

	# ── ⑤ 附加行：顺序 4,5,1,2,6,7、跨件累加、每件 3 条上限、灵器不进账、板高 121+22n
	#     这一半同时量**跨整页重建保持**：`_refresh_current()` 就是一次重建，
	#     开着的状态记在窗口上（`_其他属性开着`）而不是页面上 ⇒ 重建后板还在。
	展开 = _箭头(窗)
	if 展开 == null:
		_失败.append("⑫ 关闭之后取不到箭头 ⇒ 附加行那一半没量到")
	else:
		展开.pressed.emit()
		for _帧 in 2:
			await process_frame
		_装一件(会话, 装备部位表.徽章, "01410004", [_特(4, 10), _特(5, 20), _特(1, 30), _特(2, 40)])
		_装一件(会话, 装备部位表.武器, "01010013", [_特(4, 5), _特(6, 7)])
		_装一件(会话, 装备部位表.宠物一, "02010060", [_特(7, 3)])
		_装一件(会话, 装备部位表.灵器, "20100001", [_特(4, 999)])
		_装一件(会话, 装备部位表.羁绊, "19010001", [_特(5, 1)])
		窗.call("_refresh_current")
		for _帧 in 3:
			await process_frame
		板 = _开板(窗)
		if 板 == null:
			_失败.append("⑫ 喂完装备再刷新，浮板不亮了 ⇒ 状态记错了地方（该记在窗口上）")
		else:
			# ⚠️ 这里写的是**成品字符串**、不是格式串 ⇒ 百分号只写一个（`其他属性值文案` 里那对
			# `%%` 是被 `%` 运算符吃掉之后才变成 1 个的）。
			var 期望附加: Array = [["攻 击 加 成", "+ 15 %"], ["防 御 加 成", "+ 21 %"],
				["生 命 加 成", "+ 30 %"], ["暴 击 加 成", "+ 7 %"], ["闪 避 加 成", "+ 3 %"]]
			var 实测附加 := _板附加行(板)
			if str(实测附加) != str(期望附加):
				_失败.append(("⑫ 附加行该是 %s（4,5,1,2,6,7 顺序、跨件累加、徽章第 4 条查克拉被 3 条上限吃掉、"
					+ "灵器那 999 不进账），实 %s") % [str(期望附加), str(实测附加)])
			if 板.size != Vector2(173.0, 231.0):
				_失败.append("⑫ 5 行附加时板高该是 121+22×5=231（:508-515），实 %s" % str(板.size))
			var 垫底 := 板.get_node_or_null("底板") as Panel
			if 垫底 == null or not 垫底.visible:
				_失败.append("⑫ 板高超过基准 150 时该垫一层底板（`MYellow_background` 随高拉伸）")
			var 第五 := _板行(板, 7)
			if 第五.is_empty() or 第五[2] != 21.0 + 22.0 * 7 or 第五[3] != 22.0 + 22.0 * 7:
				_失败.append("⑫ 第 7 行（最后一条附加行）y 该是 %s/%s，实 %s"
					% [str(21.0 + 22.0 * 7), str(22.0 + 22.0 * 7), str(第五)])

	# ── ⑥ 变身卡上限 4：**同一件、同样四条特性、同一个位置**，只换 id ⇒ 差一条「查克拉加成」
	#     id 用真表里的号（物品 id 是**八位补零**，`int(id/10000)` 取到的是前四位：
	#     `01210441`（终极角都变身卡）→ 121 ✓ 变身；`01410004`（三尾徽章）→ 141 ✗。
	#     注意 `12100001`「千手柱间卡」是**材料**、算出来是 1210 而不是 121 —— 原版这个算式
	#     认的就是穿在身上的那张卡（前缀 121 人物变身位 / 205 宠物变身），不是材料卡。
	会话.equipped_items.clear()
	_装一件(会话, 装备部位表.变身, "01210441", [_特(4, 10), _特(5, 20), _特(1, 30), _特(2, 40)])
	窗.call("_refresh_current")
	for _帧 in 3:
		await process_frame
	板 = _开板(窗)
	var 变身四行: Array = [["攻 击 加 成", "+ 10 %"], ["防 御 加 成", "+ 20 %"],
		["生 命 加 成", "+ 30 %"], ["查克拉加成", "+ 40 %"]]
	if 板 == null or str(_板附加行(板)) != str(变身四行):
		_失败.append("⑫ 变身卡（id 前缀 121/205）该收 4 条 ⇒ %s，实 %s"
			% [str(变身四行), str(_板附加行(板)) if 板 != null else "没有板"])
	elif 板.size != Vector2(173.0, 209.0):
		_失败.append("⑫ 4 行附加时板高该是 121+22×4=209，实 %s" % str(板.size))
	会话.equipped_items.clear()
	_装一件(会话, 装备部位表.变身, "01410004", [_特(4, 10), _特(5, 20), _特(1, 30), _特(2, 40)])
	窗.call("_refresh_current")
	for _帧 in 3:
		await process_frame
	板 = _开板(窗)
	if 板 == null:
		_失败.append("⑫ ⑥ 后半（非变身卡那一轮）浮板不亮 ⇒ 后面三条上限没量到")
	elif _板附加行(板).size() != 3:
		_失败.append("⑫ 同一件非变身卡（前缀 141）只该收前 3 条，实 %d 条：%s"
			% [_板附加行(板).size(), str(_板附加行(板))])

	# ── ⑦ 只出 >0 的行：0 与负数特性都不该占一行（`:383` 的 `Number(value) > 0`）
	会话.equipped_items.clear()
	_装一件(会话, 装备部位表.武器, "01010013", [_特(4, 0), _特(6, -5)])
	窗.call("_refresh_current")
	for _帧 in 3:
		await process_frame
	板 = _开板(窗)
	if 板 == null:
		_失败.append("⑫ ⑦ 这一轮浮板没了")
	elif _板附加行(板).size() != 0 or 板.size != Vector2(173.0, 150.0):
		_失败.append("⑫ 0 与负数特性不该出行、板高该回基准 150，实 %d 行、高 %s"
			% [_板附加行(板).size(), str(板.size)])

	# ── ⑧ 关掉之后重建：不该自己再冒出来
	展开 = _箭头(窗)
	if 展开 == null:
		_失败.append("⑫ ⑧ 取不到箭头 ⇒ 关闭态跨重建那一半没量到")
	else:
		展开.pressed.emit()
		窗.call("_refresh_current")
		for _帧 in 3:
			await process_frame
		if _开板(窗) != null:
			_失败.append("⑫ 关掉的浮板在下一次重建后又亮起来了 ⇒ 态没跟着翻")
	if 假.收到.size() + 假.八门.size() + 假.结印 != 0:
		_失败.append("⑫ 点箭头该一个包都不发（`:333-339` 只翻 visible），实发 %s / %s / %d"
			% [str(假.收到), str(假.八门), 假.结印])
	窗.set("_backend", null)
	假.free()
	_恢复其他属性(窗, 会话, 原装备, 原率, 率键)


## 把会话与窗口恢复成进来时的样子：这条腿改了 `equipped_items` 与三条率。
## 恢复之后**不再重建**（本进程紧接着就 `quit()`）—— 只为不留测试数据，
## 各门本身是独立进程，不会互相污染。
func _恢复其他属性(窗, 会话, 原装备: Dictionary, 原率: Dictionary, 率键: Array) -> void:
	窗.set("_其他属性开着", false)
	会话.equipped_items.clear()
	for 键 in 原装备:
		会话.equipped_items[键] = 原装备[键]
	for 键 in 率键:
		if 原率[String(键)] == null:
			会话.player_stats.erase(String(键))
		else:
			会话.player_stats[String(键)] = 原率[String(键)]


## ⑬ 提升弹窗里那枚「购买」（2026-10-19 外部体检报告 P1-3）。
##
## 原版语义在 `ItemCaiLiaoBox.as`：`createChildren:130-141` 建出 `buyBtn` 并挂
## `MouseEvent.CLICK → buyHandler`，而 `buyHandler:45-54` 干的是
## `new CashShopWindowEvent(REQUEST_CASH_ITEM_INFO).id = itemCell.itemData.id` 派发出去 ——
## **问服务端要这件材料的商城条目**（回包 1079 才开购买窗；本工程同一条链 = §3.125，
## 统一出口 `功能窗口.请求商城商品` ⇒ 上行 1086 只带一个字段 = 物品 id）。
## 两个容易想反的点，都在原版里写死了：
##   · 材料不够时它**从不置灰这枚钮** —— `hasItem():56-62` / `applyGrayFilter:37-39`
##     只给**图标** `itemCell.filters` 加灰滤镜，`buyBtn` 照点（原版要跳得进商城才买得到）；
##   · 只有 `itemData` 为空才是 no-op（`buyHandler:46-49` `if(!itemCell.itemData) return`）。
## 修前这五枚（三族 + 寄坏两格）全是死路：三族 `购买.disabled = true` 配一句
## "原版跳商城，本轮未做"，寄坏两格接一句占位提示。而"未做"那句**前提是假的**：
## 出口一直有（`通灵驯养窗口` 的材料格、扩容窗、秘笈合成、手里剑突破都在用同一发）。
##
## 量四件事：① 钮不置灰、点一发就发**本阶**的 `stage<阶+1>.needItemId`（各族不同号，
##    接线接错号当场点名）；② 满阶（`stage<阶+1>` 没有配置）⇒ 一句提示、**一个包都不发**；
## ③ 寄坏两格发 KunChong 段配的 `guarantee.guaranteeId` / `help.helpItemId`；
## ④ 每枚钮身上**只有一根** `pressed` 连接（连渲染三次之后仍然只有一根、点一次只发一发）。
##    ⚠ ④ 今天测的是"幂等"而不是"修好了一处堆叠"：`功能窗口._render_page:1106-1108`
##    每次重绘把 `_content` 整片 free 掉重烘，页上的弹窗是**新节点** ⇒ 老代码那句没守卫的
##    `connect` 也不会真堆起来（**实测**：把 `人物窗口.gd` 里三族那圈 `disconnect` 删掉，
##    本腿仍绿、连接数还是 1）。留着这根判据是因为哪天这页改成跨重绘缓存
##    （`确保子页` 已经在同一棵子树里那么干了），没守卫就当场多挂一根。
func _验材料购买(窗, 会话, 管理) -> void:
	var 原态 := {}
	for 腿0: Array in 自动族腿:
		原态[String(腿0[0])] = (会话.cultivation_states.get(String(腿0[0]), {}) as Dictionary).duplicate(true)
	var 假 := 假后端.new()
	窗.set("_backend", 假)
	管理.call("打开", "人物")
	for 帧 in 4:
		await process_frame

	for 腿: Array in 自动族腿:
		var 族 := String(腿[0])
		var 表段 := String(腿[5])
		var 起阶: int = maxi(1, int(腿[9]))
		会话.cultivation_states[族] = {"stage": 起阶, "count": 0}
		await _去族页(窗, 腿)
		await _开族弹窗(窗, 腿)
		var 弹窗 := _族弹窗(窗, 腿)
		if 弹窗 == null:
			_失败.append("⑬「%s」取不到「%s」⇒ 这一腿整条没量到" % [族, String(腿[4])])
			continue
		var 购买 := 弹窗.find_child("购买按钮", true, false) as Button
		if 购买 == null:
			_失败.append("⑬「%s」弹窗里没有「购买按钮」（三族各烘一枚，就在弹窗直属）" % 族)
			continue
		# ── ① 不置灰 + 接了线 + 发的号 = 本阶表里的 needItemId
		if 购买.disabled:
			_失败.append(("⑬「%s」的「购买」被置灰：原版只灰**图标**（`hasItem:56-62`），"
				+ "这枚钮从 `createChildren:140` 挂上 CLICK 起就一直可点") % 族)
		if 购买.pressed.get_connections().is_empty():
			_失败.append("⑬「%s」的「购买」没接线（点了不发 1086 ⇒ 玩家只看得到一句空响）" % 族)
			continue
		var 期望 := int(_提升表配置(表段, 起阶 + 1).get("needItemId", 0))
		if 期望 <= 0:
			_失败.append("⑬「%s」stage%d 没有 needItemId ⇒ 表读不到，这条没法量" % [族, 起阶 + 1])
			continue
		假.商城.clear()
		购买.pressed.emit()
		await process_frame
		if 假.商城 != [期望]:
			_失败.append("⑬「%s」点「购买」该发一发 1086(%d)（stage%d 的 needItemId），实发 %s"
				% [族, 期望, 起阶 + 1, str(假.商城)])
		# ── ② 满阶（`stage<阶+1>` 没有配置）⇒ **一个包都不发**，只给一句人话。
		#    ⚠ 这里本来想量"发的号跟着当前阶走"，但表里**同一族每阶 needItemId 是同一个**
		#    （只有 `needItemCnt` 变：`数据/原版杂项.json` XieLunYan 2..12 阶全 16000037），
		#    原版也是 `itemData = createSingleItem(_cfg.needItemId)`（`RouQuanTiShengWindow:230`）
		#    ⇒ 换阶在**这一族的表上看不出差别**，那条判据取不到。改成量满阶这一支：
		#    原版靠 `buyHandler:46-49` 的 `if(!itemCell.itemData) return;` 静默 no-op，
		#    本工程口径是"点了没反应＝坏了" ⇒ 换成一句提示，但仍然不发。
		var 最高 := _表最高阶(表段)
		会话.cultivation_states[族] = {"stage": 最高, "count": 0}
		var 通知: Array = []
		var 会话连接 := func(文: String) -> void: 通知.append(文)
		会话.notification_requested.connect(会话连接)
		假.商城.clear()
		购买.pressed.emit()
		await process_frame
		会话.notification_requested.disconnect(会话连接)
		if not 假.商城.is_empty():
			_失败.append("⑬「%s」已到最高阶（stage%d 没有 stageUp ⇒ 没有要消耗的材料），点「购买」还发 %s"
				% [族, 最高 + 1, str(假.商城)])
		if 通知.is_empty():
			_失败.append("⑬「%s」满阶点「购买」该有一句提示（不许静默 no-op），实测没有" % 族)
		会话.cultivation_states[族] = {"stage": 起阶, "count": 0}
		# ── ④ 连渲染三次再点：连接数仍为 1、请求仍只发一发
		for 重 in 3:
			窗.call("_refresh_current")
			for 帧 in 3:
				await process_frame
		var 现弹窗 := _族弹窗(窗, 腿)
		var 现购买: Button = null
		if 现弹窗 != null:
			现购买 = 现弹窗.find_child("购买按钮", true, false) as Button
		if 现购买 == null:
			_失败.append("⑬「%s」三次重建之后「购买按钮」取不到（弹窗没跟着重建或名字变了）" % 族)
		else:
			var 根数 := 现购买.pressed.get_connections().size()
			if 根数 != 1:
				_失败.append("⑬「%s」的「购买」挂了 %d 根 pressed（每渲染多挂一根 ⇒ 点一次发 N 发）" % [族, 根数])
			假.商城.clear()
			现购买.pressed.emit()
			await process_frame
			if 假.商城 != [期望]:
				_失败.append("⑬「%s」三次重建后点一次该**只发一发** 1086(%d)，实发 %s" % [族, 期望, str(假.商城)])

	# ── ③ 寄坏之术那两格：物品号来自 KunChong 段（门自己读磁盘，不复用 `装备打造表`）
	var 虫段: Dictionary = _读磁盘表("装备打造").get("KunChong", {}) as Dictionary
	var 保底号 := int((虫段.get("guarantee", {}) as Dictionary).get("guaranteeId", 0))
	var 帮手号 := int((虫段.get("help", {}) as Dictionary).get("helpItemId", 0))
	窗.call("_set_character_main_tab", 1)
	await process_frame
	窗.call("_set_character_sub_tab", 2)
	for 帧 in 4:
		await process_frame
	var 虫页 := _取页(窗, "寄坏之术")
	if 虫页 == null:
		_失败.append("⑬ 切不到「寄坏之术」页 ⇒ 那两格的购买没量到")
	else:
		var 虫弹 := 虫页.get_node_or_null("昆虫强化弹窗") as Control
		if 虫弹 == null:
			_失败.append("⑬ 寄坏页里没有「昆虫强化弹窗」")
		else:
			for 格: Array in [["镇灵石格", 保底号], ["寄坏玉格", 帮手号]]:
				var 钮 := 虫弹.get_node_or_null("底图/强化区底图/%s/购买按钮" % String(格[0])) as Button
				if 钮 == null:
					_失败.append("⑬ 寄坏弹窗里没有「%s/购买按钮」" % String(格[0]))
					continue
				if 钮.disabled:
					_失败.append("⑬ 寄坏「%s」的购买被置灰（原版不灰这枚钮）" % String(格[0]))
				if 钮.pressed.get_connections().is_empty():
					_失败.append("⑬ 寄坏「%s」的购买没接线（点了不发 1086）" % String(格[0]))
					continue
				if 钮.pressed.get_connections().size() != 1:
					_失败.append("⑬ 寄坏「%s」的购买挂了 %d 根 pressed"
						% [String(格[0]), 钮.pressed.get_connections().size()])
				假.商城.clear()
				钮.pressed.emit()
				await process_frame
				if 假.商城 != [int(格[1])]:
					_失败.append("⑬ 寄坏「%s」的购买该发 1086(%d)（表里配的号），实发 %s"
						% [String(格[0]), int(格[1]), str(假.商城)])

	窗.set("_backend", null)
	假.free()
	for 族 in 原态:
		会话.cultivation_states[String(族)] = 原态[族]




## ⑭ 人物信息区那十处悬停提示（原版 `CharPane.as:197-216 setToolTip()` + `:284` 推进来的意志串）。
## `[提示框节点后缀, 宿主路径(相对 `原版人物属性面板`), 正文必含片段…]`。
## 片段**逐字抄自语言表原文**（`数据/界面/人物_文案.json`，由 `开发工具/出人物文案数据.py` 抽）：
## 断"必含"不断"全等"是故意的 —— `<br/>` 折成 `\n`、`<font>` 被 BBCode 吃掉之后
## `get_parsed_text()` 只剩白字，全等会把排版改动也判成红。
const 信息提示腿: Array = [
	["罪恶值", "信息区/罪恶值格/名称",
		["通过击败与自己等级相近的其他玩家人物获得", "罪恶值越大，你被击败时，掉落的物品越多"]],
	["家族", "信息区/家族格/名称", ["加入家族后可学习到家族忍术"]],
	["羁绊", "信息区/羁绊格/名称", ["羁绊后可学习羁绊忍术"]],
	["经验名", "经验值",
		["经验获得途径", "打怪，完成任务，打坐，修行等等", "人物升级后可以穿著更强大的装备"]],
	["精华名", "精华",
		["精华获得途径", "人物通过线上打坐及离线修行都可获得精华",
			"精华可用于提升忍术层数，开通八门穴道等操作"]],
	["生命名", "当前生命", ["代表人物的生命值，当生命值为0时，人物将会死亡"]],
	["查克拉名", "当前查克拉", ["使用忍术技能进行攻击时将会消耗人物的查克拉"]],
	["经验数值", "经验数值", ["当前经验：1234", "本级所需经验：5678"]],
	["精华数值", "精华数值", ["当前精华：300", "精华上限：900"]],
	["意志值", "信息区/意志格",
		["当前意志：41", "凝神 Lv.3", "查克拉上限+200", "羁绊 Lv.1", "经验+1200"]],
]


func _验信息提示(窗, 会话, 管理) -> void:
	if 管理 == null:
		_失败.append("⑭ 拿不到窗口管理 ⇒ 信息区十处悬停提示一整串没量到")
		return
	# 这一腿动的是**真会话**里那四条数与穿戴数组 ⇒ 先备份，结尾原样还回去。
	var 原数 := {}
	for 键名 in ["exp", "max_exp", "breath", "max_breath"]:
		原数[键名] = 会话.player_stats.get(键名, null)
	var 原穿戴: Array = 会话.spirit_equipped.duplicate(true)
	会话.player_stats["exp"] = 1234
	会话.player_stats["max_exp"] = 5678
	会话.player_stats["breath"] = 300
	会话.player_stats["max_breath"] = 900
	# 两件穿戴 = 1 枚绿(201 凝神 Lv.3, exp 0) + 1 枚黄(601 羁绊 Lv.1) ⇒
	# 意志力 = `(30 + 1200) / 30` = **41**（`YiZhiData.rongHeExp:92-101`：黄帧恒 1200、
	# 其余 `common.levelUp.level1[品质] + exp`，绿 = 30）。
	# 行的正文：`凝神 Lv.3 查克拉上限+200`（`getAttrValue:66-89` 取 1..3 档最大 = 200）、
	# `羁绊 Lv.1 经验+1200`（601 那条走 `id==601` 恒 1200 特例，不是查 attrValues）。
	会话.spirit_equipped = [
		{"id": 201, "color": "2", "slot": 1, "exp": 0, "level": 3},
		{"id": 601, "color": "6", "slot": 2, "exp": 777, "level": 1}]
	管理.call("打开", "人物")
	窗.call("_set_character_main_tab", 0)
	await process_frame
	窗.call("_set_character_sub_tab", 0)
	for 帧 in 4:
		await process_frame
	var 面板 := _取子页(窗, "人物")
	if 面板 == null:
		_失败.append("⑭ 切不到「人物」页 ⇒ 十处提示没量到")
		_还(会话, 原数, 原穿戴)
		return
	var 页面 := 面板.get_parent() as Control
	# ── ⑭a 十处：宿主收得到悬停 · 原生提示让位 · 框挂页面根且默认藏 · 正文逐字对 · 悬停真开合
	for 腿: Array in 信息提示腿:
		var 名 := String(腿[0])
		var 宿主 := 面板.get_node_or_null(String(腿[1])) as Control
		if 宿主 == null:
			_失败.append("⑭「%s」的宿主节点取不到：%s" % [名, String(腿[1])])
			continue
		var 框 := 页面.get_node_or_null("文字提示_" + 名) as Control
		if 框 == null:
			_失败.append("⑭「%s」的提示框没挂到页面根 ⇒ 原版十处少一处（修前正是这样，一处都没有）" % 名)
			continue
		if 宿主.mouse_filter != Control.MOUSE_FILTER_PASS:
			_失败.append(("⑭「%s」的宿主 mouse_filter=%d ⇒ Label 收不到悬停"
					+ "（原版 `CharPane.as:199-204` 是先 `mouseEnabled = true` 才挂提示的）")
					% [名, 宿主.mouse_filter])
		if 宿主.tooltip_text != "":
			_失败.append("⑭「%s」还挂着原生 tooltip（%s）⇒ 原版提示框与原生框只留一个" % [名, 宿主.tooltip_text])
		if 框.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			_失败.append("⑭「%s」的提示框 mouse_filter=%d ⇒ 悬停框会吃掉底下格子的点击"
				% [名, 框.mouse_filter])
		var 字 := 框.get_node_or_null("文字") as RichTextLabel
		if 字 == null:
			_失败.append("⑭「%s」的提示框里没有「文字」RichTextLabel" % 名)
			continue
		var 正文 := 字.get_parsed_text()
		for 片 in (腿[2] as Array):
			if not 正文.contains(String(片)):
				_失败.append("⑭「%s」的正文缺语言表原文「%s」（实读：%s）"
					% [名, String(片), 正文.replace("\n", "⏎")])
		if 框.visible:
			_失败.append("⑭「%s」没人悬停就亮着（原版 `MToolTip:37-47` ROLL_OUT 就 removeChild）" % 名)
		宿主.mouse_entered.emit()
		await process_frame
		if not 框.visible:
			_失败.append("⑭「%s」悬停后没显示 ⇒ mouse_entered 没接到这枚框" % 名)
		宿主.mouse_exited.emit()
		await process_frame
		if 框.visible:
			_失败.append("⑭「%s」移开后还亮着 ⇒ mouse_exited 那条没接" % 名)
		if 宿主.mouse_entered.get_connections().size() != 1:
			_失败.append("⑭「%s」的宿主挂了 %d 根 mouse_entered ⇒ 一页里这一处只许一根悬停线"
					% [名, 宿主.mouse_entered.get_connections().size()])

	# ── ⑭b 三条动态串跟数走（整页重建之后）：防"只在首次建框时填一次文案"。
	会话.player_stats["exp"] = 2026
	会话.player_stats["max_exp"] = 9999
	会话.player_stats["breath"] = 555
	会话.player_stats["max_breath"] = 666
	(会话.spirit_equipped[0] as Dictionary)["exp"] = 60
	(会话.spirit_equipped[0] as Dictionary)["level"] = 5
	# ⇒ 意志力 `(30+60+1200)/30` = **43**；201 绿 Lv.5 ⇒ `attrValues` 1..5 最大 = **300**
	窗.call("_set_character_sub_tab", 1)
	await process_frame
	窗.call("_set_character_sub_tab", 0)
	for 帧 in 4:
		await process_frame
	var 面板2 := _取子页(窗, "人物")
	if 面板2 == null:
		_失败.append("⑭b 重建后取不到「人物」页 ⇒ 动态那三条没量到")
	else:
		var 页面2 := 面板2.get_parent() as Control
		for 腿: Array in [["经验数值", ["当前经验：2026", "本级所需经验：9999"], "当前经验：1234"],
				["精华数值", ["当前精华：555", "精华上限：666"], "当前精华：300"],
				["意志值", ["当前意志：43", "凝神 Lv.5", "查克拉上限+300"], "当前意志：41"]]:
			var 框2 := 页面2.get_node_or_null("文字提示_" + String(腿[0])) as Control
			if 框2 == null:
				_失败.append("⑭b 整页重建后「%s」的提示框没了 ⇒ 页面重建把框带走了、没人补建" % String(腿[0]))
				continue
			var 正文2 := _提示正文(框2)
			for 片 in (腿[1] as Array):
				if not 正文2.contains(String(片)):
					_失败.append("⑭b「%s」没跟着新数跳：缺「%s」（实读：%s）"
						% [String(腿[0]), String(片), 正文2.replace("\n", "⏎")])
			if 正文2.contains(String(腿[2])):
				_失败.append("⑭b「%s」还留着旧数「%s」⇒ 文案是烘的、不是每次重画现填"
					% [String(腿[0]), String(腿[2])])
		# ── ⑭c **同一张页原地重画三次**之后：页面根上仍然只有十枚框、每枚宿主仍然恰好一根
		#     `mouse_entered`（钉"框不重复建"与"连接不丢"两件事）。
		#     ⚠️ 反向对照记录（2026-10-21）：把 `connect` 从 `if 新建` 里挪出去**不会红** ——
		#     Godot 对"同一对象 + 同一方法 + 同一 bind"的 connect 去重 ⇒ 这一条不是防叠连接的闸，
		#     别把它当那条用。真正钉得住的是 ⑭b（文案烘死 ⇒ 三条全红）。
		#     现在人物页每次都是整页重建 ⇒ 这一支走不到；但 §3.233 已经给族页开了
		#     `原地刷新族页` 这条路，同一套写法迟早挪到人物页 ⇒ 先把规矩钉在这儿。
		#     先拿一个新数证实「这句静态渲染真的跑起来了」，再连跑第二次数框和连接。
		# ⚠️ 静态函数**不能** `窗.call("渲染人物页", …)`（实测报
		#    `Invalid call. Nonexistent function '渲染人物页 (via call)'`，而且它只把函数打断、
		#    不记失败 ⇒ 整条 ⑭c 静默没跑、门照样绿）。要调就调脚本本身。
		会话.player_stats["exp"] = 777
		var 人脚本 = load("res://脚本/界面/窗口/人物窗口.gd")
		人脚本.渲染人物页(窗, 面板2, 会话.player_stats, 会话, false)
		var 验框 := 页面2.get_node_or_null("文字提示_经验数值") as Control
		if 验框 == null:
			_失败.append("⑭c 「文字提示_经验数值」不见了 ⇒ 这一腿没地方量")
		elif not _提示正文(验框).contains("当前经验：777"):
			_失败.append("⑭c 直接调 `渲染人物页` 没跑起来（正文里没有「当前经验：777」）"
					+ " ⇒ 下面那两条计数是假绿，不是「原地重画也不叠连接」")
		人脚本.渲染人物页(窗, 面板2, 会话.player_stats, 会话, false)
		人脚本.渲染人物页(窗, 面板2, 会话.player_stats, 会话, false)
		var 框数 := 0
		for 子 in 页面2.get_children():
			if String(子.name).begins_with("文字提示_"):
				框数 += 1
		if 框数 != 信息提示腿.size():
			_失败.append("⑭c 三次重画之后页面根上有 %d 枚「文字提示_*」（应为 %d）"
					% [框数, 信息提示腿.size()]
					+ " ⇒ 框被重复建出来，或十处里少了哪一处")
		for 腿: Array in 信息提示腿:
			var 宿2 := 面板2.get_node_or_null(String(腿[1])) as Control
			if 宿2 == null:
				continue
			var 根数 := 宿2.mouse_entered.get_connections().size()
			if 根数 != 1:
				_失败.append("⑭c「%s」原地重画三次后挂了 %d 根 mouse_entered ⇒ 悬停线被重复建/被别处抢挂"
						% [String(腿[0]), 根数])

	# ── ⑭d 源码两扫：自造串与「两份意志文案」不许长回来。
	# ⚠️ 只扫**非注释行**：修前那两句现在作为"当初写错了什么"的出处记录留在注释里，
	#    那是写给下一个人的，不该被自己的说明文字判红（2026-10-21 首跑就被自己绊了一次）。
	var 人物源 := _去注释("res://脚本/界面/窗口/人物窗口.gd")
	if 人物源.contains("升级所需经验"):
		_失败.append("⑭d `人物窗口.gd` 里又出现自造串「升级所需经验」⇒ 那是修前那三条原生 tooltip 的话，"
			+ "原版用的是语言表 `CHARACTOR_EXP_TIP2`")
	if 人物源.contains("static func 意志力提示文案"):
		_失败.append("⑭d `人物窗口.gd` 自己抄了一份 `意志力提示文案` ⇒ 这串只许有一份（在 `意志提示框.gd`，"
			+ "两处宿主共用）")
	var 意志源 := _去注释("res://脚本/界面/窗口/意志窗口.gd")
	if 意志源.contains("\"穿戴数组\""):
		_失败.append("⑭d `意志窗口.gd` 又去读 meta「穿戴数组」⇒ 全工程没人写这个 meta，"
			+ "提示会退回「当前意志：0」；真值源只有 `session.spirit_equipped`")
	_还(会话, 原数, 原穿戴)
	_信息提示跑完 = true


## 还回 ⑭ 借用的那四条数与穿戴数组（`spirit_equipped` 是整串换掉的，必须按原引用还）。
func _还(会话, 原数: Dictionary, 原穿戴: Array) -> void:
	for 键名 in 原数:
		if 原数[键名] == null:
			会话.player_stats.erase(String(键名))
		else:
			会话.player_stats[String(键名)] = 原数[键名]
	会话.spirit_equipped = 原穿戴


## 读源码并丢掉注释行（strip 后以 `#` 开头的那些）⇒ 判据只作用在**代码**上。
func _去注释(路径: String) -> String:
	var 出: Array[String] = []
	for 行 in FileAccess.get_file_as_string(路径).split("
"):
		var 一 := String(行).strip_edges()
		if 一.begins_with("#"):
			continue
		出.append(String(行))
	return "
".join(出)


## 提示框正文（`文字提示框.tscn` 里那枚 `文字` RichTextLabel 的**解析后**纯文本）。
## 缺 `文字` 时返回一句显眼的假文本 ⇒ 后面所有「必含」判据都红，而不是把门炸成 Nil。
func _提示正文(框: Control) -> String:
	var 字 := 框.get_node_or_null("文字") as RichTextLabel
	return "＜没有「文字」节点＞" if 字 == null else 字.get_parsed_text()


## **格子**提示框（`装备提示框` / `物品提示框`）的全文 —— 与上面那条不是一个组件，别混用：
## 这两套里没有「文字」，物品名在 `标题`（Label，带 BBCode）、正文散在 `描述`/`信息`/`明细`/
## `等级`/`价格`/`绑定` 好几枚里 ⇒ 逐节点拼起来判「必含」，缺哪枚都不影响其余判据。
## （`_提示正文` 那份是 `文字提示框.tscn` 的单节点口径，报修② 那八格用的是组件版，
##   2026-10-27 反向对照第一次跑到底才现形：读「文字」恒返假文本 ⇒ 五条判据全红。）
## 有效绘制层序 = 自己与整条祖先链的 `z_index` 之和（Godot 的子节点 z 是相对父节点的）。
## 提示框与页内弹窗共用同一个窗口根，比较两个和就等于比较实际遮挡顺序。
func _层序(件: CanvasItem) -> int:
	var 和 := 0
	var 上: Node = 件
	while 上 != null:
		if 上 is CanvasItem:
			和 += (上 as CanvasItem).z_index
		上 = 上.get_parent()
	return 和


func _格子提示全文(框: Control) -> String:
	var 出 := ""
	for 名 in ["标题", "文字", "信息", "描述", "明细", "稀有明细", "等级", "价格", "绑定", "过期", "职业行"]:
		var 件 := 框.get_node_or_null(名)
		if 件 == null:
			continue
		if 件 is RichTextLabel:
			出 += (件 as RichTextLabel).get_parsed_text() + "\n"
		elif 件 is Label:
			出 += String((件 as Label).text) + "\n"
	return 出


## 「强化目标」是哪只虫 —— 与 `人物窗口.初始化寄坏之术页:2937-2958` 同一条选取规则：
## 携入（背包菜单「强化」带进来的）→ 身上第一只 → 背包第一只。**只用来算期望名**，
## 不参与被测路径（被测页面自己算的是它那份）。
func _强化目标虫名(窗, 会话) -> String:
	var 携入: Variant = 窗.get("_角色携入虫")
	if 携入 is Dictionary and not (携入 as Dictionary).is_empty():
		return _虫名(携入 as Dictionary)
	for 槽 in [装备部位表.昆虫一, 装备部位表.昆虫二, 装备部位表.昆虫三, 装备部位表.昆虫四]:
		var 件: Variant = (会话.equipped_items as Dictionary).get(槽, {})
		if 件 is Dictionary and not (件 as Dictionary).is_empty():
			return _虫名(件 as Dictionary)
	for 条 in 会话.inventory:
		if 条 is Dictionary and 昆虫放入格脚本.可收(str((条 as Dictionary).get("id", ""))):
			return _虫名(条 as Dictionary)
	return ""


## 物品表原文名；表里没有（测试造件 1310001 那种）退回负载里的 name，再没有才退回 id。
func _虫名(件: Dictionary) -> String:
	var 号 := str(件.get("id", ""))
	var 名 := String(游戏数据表.item(号).get("name", ""))
	if 名.is_empty():
		名 = String(件.get("name", ""))
	return 名 if not 名.is_empty() else 号


## —— 真输入三件套（报修③那条拖动腿用；口径抄 `他人人物窗回归测试` 那份实测过的）——
## ⚠ 无头四条坑（2026-10-27 `测试/_探针无头拾取.gd` 逐条量过）：
##  ① `root.size` **过一帧就被 headless 显示服务打回 64×64** ⇒ 钉完必须**同帧**立刻 push；
##  ② 视口外的坐标不参与拾取 ⇒ 被拖的件得先挪进 960×560 里（弹窗烘在页里、页面在无头布局里是
##     **负坐标**，直接量必假红）；
##  ③ **button 事件用的是事件自己的坐标**，不依赖视口存的鼠标位 —— 探针里只推一次 `按下`
##     就正常进线（`root.get_mouse_position()` 全程恒 (0,0)）。⇒ 处理函数**不许**读
##     `get_global_mouse_position()`（无头永远 0），只能读 `事件.global_position`；
##  ④ 拾取落在**最深的非 IGNORE 件**上，父链只在祖先 `PASS` 时才收得到 ⇒ 弹窗底下那枚铺满的
##     装饰 Panel 若是 STOP，`弹窗.gui_input` 一条都不进（就是报修③"拖不动"的真病根，
##     修在 `人物窗口.初始化寄坏之术页` 的接线里）。祖先有任何一层 `clip_contents` 开着，
##     越出它矩形的弹窗**整个不参与拾取**（探针 S3：同结构只开裁 ⇒ 命中清空）。
func _钉() -> void:
	root.size = Vector2i(960, 560)


func _移全局(点: Vector2, 按住: bool = true) -> void:
	var 移 := InputEventMouseMotion.new()
	移.position = 点
	移.global_position = 点
	移.button_mask = MOUSE_BUTTON_MASK_LEFT if 按住 else 0
	_钉()
	root.push_input(移)


func _按全局(点: Vector2, 按下: bool) -> void:
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = 按下
	按.button_mask = MOUSE_BUTTON_MASK_LEFT if 按下 else 0
	按.position = 点
	按.global_position = 点
	_钉()
	root.push_input(按)


## 这一下按下**送不送得到 `弹`** —— 照 Godot 的拾取+冒泡规则真算一遍，不猜坐标也不猜「悬」：
##  ① 悬停仲裁直接用 `Viewport::gui_get_hovered_control()`（走的就是引擎自己的 `_find_control`：
##     祖先可见链、`clip_contents` 越界、跨分支 z 序全都算进去了。2026-10-27 探针实测：把弹窗摆到
##     (120,60) 后它报的是 HUD 那枚 `头像面板/角色状态/AutoCombatSettings/HangLabel` ⇒ 按下整个被
##     吞，看着像「拖拽没接线」，其实是根本没送到 —— 先前几条红全是这么来的。）
##  ② 事件先给**悬停件自己**，再往父链传，**碰到 STOP 就断** ⇒ 要送到 `弹`，`弹` 得在这条父链上，
##     且从悬停件到 `弹`（不含 `弹`）每一层都是 PASS。`弹` 自己是 STOP 无所谓，它那份照样收。
## ⚠ 拿「悬停件 == 弹」当判据是错的：铺在弹窗底下的装饰板合法地接管那一点，事件仍然冒得上来。
func _送达(弹: Control, 点: Vector2) -> bool:
	_移全局(点, false)
	var 悬 := root.gui_get_hovered_control() as Control
	if 悬 == null:
		return false
	var 上: Node = 悬
	while 上 != null and 上 != 弹:
		var 控 := 上 as Control
		if 控 == null:
			return false		# 悬停在非 Control 分支（HUD 之类）⇒ 跟这扇弹窗不是一条链
		if 控.mouse_filter == Control.MOUSE_FILTER_STOP:
			return false		# 这一层收了就断，`弹` 一辈子见不到这一下
		上 = 上.get_parent()
	return 上 == 弹


## 把弹窗依次摆到候选全局点，在标题条的候选偏移里挑第一处「按下真能送进 `弹.gui_input`」的落点，
## 返回 `[全局落点, 抓=局部偏移]`；一处都挑不出 ⇒ 空数组（腿红在「无从量」，不红在假坐标上）。
## ⚠ 落点**不写死**：弹窗烘在页里、页面在无头布局里是负坐标；挪进 960×560 又可能正压着 HUD。
## ⚠ 顺序要紧：**先 `_钉()` 撑视口、再摆位置**（`_送达` 里的 `_移全局` 还会再 `_钉()` 一次，
##   尺寸没变就是幂等）；先摆后撑的话第一次 push 触发的重排会按锚点把弹窗弹回烘死位。
func _挑拖点(弹: Control, 候选列: Array, 局部列: Array) -> Array:
	for 候 in 候选列:
		for 局 in 局部列:
			var 全 := 候 as Vector2
			_钉()
			弹.global_position = 全
			if _送达(弹, 全 + (局 as Vector2)):
				return [全, 局 as Vector2]
	return []
## ── ⑮ 写轮眼 / 轮回六道两页的逐件落位 + 那列阶段钮真能滚 + 同档帧不许跳页签 ──
## 每个期望值都是 §① §② 那张表里的**字面数**（AS3 行号跟着写了），
## ⚠️ 不许"读到什么就钉什么" —— 那等于把 bug 当基线（2026-10-25 第一条打回就是这么来的：
##    内容框 `custom_minimum_size` 停在视口高 200 ⇒ 行程 0 ⇒ 滚不动，而画面看着是对的）。
const 写轮眼钮表 := ["单勾玉", "双勾玉", "三勾玉", "月读", "天照", "须佐之男",
	"伊邪那歧", "永恒万花筒", "轮回眼", "六勾玉轮回眼", "轮回写轮眼", "净眼"]
## `TongshuWindow.as:203-233` `_btnBox` 90×200 @(5,5)、`verticalGap=4`、钮天然高 = 皮肤高 22
## （`MButton3.as:274-275`）⇒ 内容高 = 11×26+22 = **308**；条宽 19（`Box.as:127`）⇒ 内容宽 **71**（`:255`）。
const 左列标题x := 11.0
const 左列条x := 51.0          # :430-439 setPositionBar（widthBar=40 ⇒ 11+40）
const 右列标题x := 192.0        # :260-279 x = bar1.x + bar1.width + 20
const 右列条x := 257.0          # 192 + (widthBar+25 = 65)
const 左列行y := [221.0, 243.0, 265.0, 287.0]
const 右列行y := [221.0, 239.0, 257.0, 275.0, 293.0]
const 每档总行数 := [4, 4, 4, 4, 6, 7, 8, 9, 9, 9, 9, 9]   # :45 barVisibleArr

var _几何跑完 := false


func _验秘术页几何(窗) -> void:
	var 会话: Node = root.get_node_or_null("/root/GameSession")
	# ── 写轮眼 ──
	会话.cultivation_states["写轮眼"] = {"stage": 3, "count": 1, "blessing": 0}
	窗.call("_set_character_main_tab", 2)
	await process_frame
	窗.call("_set_character_sub_tab", 0)
	for _帧 in 3:
		await process_frame
	var 页 := _取页(窗, "写轮眼")
	if 页 == null:
		_失败.append("⑮ 写轮眼页没建出来 ⇒ 这一页一条都没量到")
		return
	var 滚 := 页.get_node_or_null("滚动按钮列表") as ScrollContainer
	if 滚 == null:
		_失败.append("⑮ 写轮眼页找不到「滚动按钮列表」")
		return
	_矩形(页, 滚, Vector2(5, 5), Vector2(90, 200), "滚动按钮列表（_btnBox）")
	if 滚.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO:
		# 一条字面量写完再接 %：GDScript **没有**相邻字面量自动拼接（Python 有），
		# 分成两行会被解析成"少一个 )"的调用参数。
		_失败.append("滚动按钮列表竖向模式 = %d，期望 1=AUTO。原版 overShowScrollBar=false 的含义是条常驻（Box.as:68-74/102-108 那两个悬停处理器只在 =true 时才动，显隐由 :246-249 按溢出决定）"
			% 滚.vertical_scroll_mode)
	if 滚.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_失败.append("滚动按钮列表横向该 0=OFF（`TongshuWindow.as:203-208` horizontalScrollPolicy=OFF）")
	var 内 := 滚.get_node_or_null("阶段列表") as Control
	if 内 == null:
		_失败.append("⑮ 滚动按钮列表里没有「阶段列表」")
		return
	if 内.get_combined_minimum_size() != Vector2(71, 308):
		_失败.append("阶段列表最小尺寸 %s ≠ (71,308)。ScrollContainer 只按子节点的最小尺寸算行程，写回 200 就等于行程 0 ⇒ 滚轮与 scroll_vertical 全部无效" % str(内.get_combined_minimum_size()))
	var 条 := 滚.get_v_scroll_bar() as VScrollBar
	if 条 == null:
		_失败.append("⑮ 拿不到竖向滚动条")
		return
	if not 条.visible:
		_失败.append("溢出时滚动条该可见（原版 308>200 ⇒ `_vScrollBarVisible=true` ⇒ `Box.as:249` 直接置可见）")
	if absf(条.max_value - 308.0) > 0.01 or absf(条.page - 200.0) > 0.01:
		_失败.append("滚动条 max/page = %s/%s，期望 308/200" % [str(条.max_value), str(条.page)])
	# 真能滚（不是"模式写着对"就算对）：设 60 ⇒ 内容上移 60；设过头 ⇒ 停在行程末端 108
	滚.scroll_vertical = 60
	await process_frame
	if absf(内.position.y + 60.0) > 0.01:
		_失败.append("scroll_vertical=60 之后内容在 y=%s（期望 −60）⇒ 这一列实际滚不动" % str(内.position.y))
	滚.scroll_vertical = 999
	await process_frame
	if absf(滚.scroll_vertical - 108.0) > 0.01:
		_失败.append("滚到底该停在 108（308−200），实测 %s" % str(滚.scroll_vertical))
	滚.scroll_vertical = 0
	await process_frame
	# 12 枚钮：树序与名字、y=26i、高 22、宽 ≥70（长文自己撑宽 = `MButton3.as:654`）
	var 钮列 := 内.get_children()
	if 钮列.size() != 12:
		_失败.append("阶段列表里 %d 枚钮，期望 12 枚（`TongshuWindow.as:210-233`）" % 钮列.size())
	for 序 in mini(12, 钮列.size()):
		var 钮 := 钮列[序] as Button
		if 钮 == null or String(钮.name) != String(写轮眼钮表[序]):
			_失败.append("阶段列表第 %d 枚不是「%s」（实测 %s）" % [序, String(写轮眼钮表[序]), str(钮列[序])])
			continue
		if absf(钮.position.y - 26.0 * 序) > 0.01 or absf(钮.size.y - 22.0) > 0.01:
			_失败.append("「%s」y=%s 高=%s，期望 y=%s 高=22（步距 22+verticalGap4）"
				% [钮.name, str(钮.position.y), str(钮.size.y), str(26.0 * 序)])
		if 钮.size.x < 70.0:
			_失败.append("「%s」宽 %s < 70（widthBtnFour..seven 里的 70 = widthBtn five）" % [钮.name, str(钮.size.x)])
		## 手型：`MButton3.init():135` `buttonMode = useHandCursor = true`
		if 钮.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
			_失败.append("「%s」不是手型光标（原版每颗 MButton3 都是 buttonMode）" % 钮.name)
	# 页内直接子件一律不许出页（用户报的头一条「按钮超出边界」）
	var 越: Array[String] = []
	for 子 in 页.get_children():
		if not (子 is Control) or String(子.name) == "提升写轮眼阶数弹窗":
			continue   # 弹窗自己有裁剪框，里面那条另算（见 §⑥ 未收口）
		var 件 := 子 as Control
		if 件.position.x < 0 or 件.position.y < 0 \
				or 件.position.x + 件.size.x > 页.size.x + 0.01 or 件.position.y + 件.size.y > 页.size.y + 0.01:
			越.append("%s %sx%s @(+%s,+%s)" % [件.name, str(件.size.x), str(件.size.y),
				str(件.position.x), str(件.position.y)])
	if not 越.is_empty():
		_失败.append("写轮眼页有 %d 件出页：\n    %s" % [越.size(), "\n    ".join(越)])
	# 底板与那一行的落位（:234-243 / :313-320 / :324-329）
	_矩形(页, 页.get_node_or_null("属性面板") as Control, Vector2(5, 205), Vector2(411, 155), "属性面板(_detailInfoSkin)")
	var 提升 := 页.get_node_or_null("提升写轮眼阶数") as Button
	if 提升 == null:
		_失败.append("⑮ 找不到「提升写轮眼阶数」")
	else:
		_矩形(页, 提升, Vector2(305, 310), Vector2(94, 22), "提升写轮眼阶数(btn_width_seven)", true)
	var 下页 := 页.get_node_or_null("下一页") as Control
	if 下页 == null:
		_失败.append("⑮ 找不到翻页条那枚「下一页」")
	elif 下页.position.x + 下页.size.x > 421.0:
		_失败.append("翻页条右缘 %s 出页（原版组 (293,332) 总宽 124 ⇒ 右缘 417）" % str(下页.position.x + 下页.size.x))
	else:
		_矩形(页, 下页, Vector2(382, 332), Vector2(15, 13), "下一页（PageComponent 末枚 18 宽槽里的图 15）")
	# 逐档行件：每档 4 行左列 + (barVisibleArr[i]−4) 行右列，标题/条/值三件套的落位与顶对齐
	var 区 := 页.get_node_or_null("属性面板/阶段，数值名称切换区") as Control
	if 区 == null:
		_失败.append("⑮ 找不到「属性面板/阶段，数值名称切换区」")
		return
	var 判档 := 0
	for 档序 in 区.get_child_count():
		var 档名 := String((区.get_child(档序) as Node).name)
		var 容 := 区.get_child(档序) as Control
		if 容 == null or not 档名.ends_with("阶段"):
			continue
		判档 += 1
		var 标题列: Array[Label] = []
		var 右列数 := int(每档总行数[档序]) - 4
		for 件 in 容.get_children():
			var 标 := 件 as Label
			if 标 == null or not String(标.name).ends_with("标题"):
				continue
			标题列.append(标)
			var 标位 := _页内(页, 标)
			var 在右 := 标位.x > 100.0
			var 期望x := 右列标题x if 在右 else 左列标题x
			if absf(标位.x - 期望x) > 0.01:
				_失败.append("「%s/%s」页内 x=%s，期望 %s（左列 widthBar=40 / 右列 x=bar1.x+宽+20）"
					% [档名, 标.name, str(标位.x), str(期望x)])
			var 行表 := 右列行y if 在右 else 左列行y
			if not 行表.has(标位.y):
				_失败.append("「%s/%s」y=%s 不在 %s 这张行距表里（左列每行 +22=18高+4距，右列每行只 +18）"
					% [档名, 标.name, str(标位.y), str(行表)])
			## `setPositionTextField:420-428` 把标签**钉死**成 widthBar(40) / widthBar+25(65)、
			## `adjustContent=false` ⇒ 标题盒不许被文字顶宽（顶宽就会压到 x=51/257 那根条上，
			## = 用户报的第 4 条「数值容器把文字挡住」在 手里剑几率 那一行的真因：原文案写成了
			## 七字的「手里剑触发几率」，语言表其实是五字的「手里剑几率」）。
			var 期宽 := 65.0 if 在右 else 40.0
			if absf(标.size.x - 期宽) > 0.01:
				# ⚠ GDScript 没有 `%r` 这个转换符：写了它整条 `%` 直接原样返回
				#   （变异实测第一次跑就打出了字面量 `%s/%s`）⇒ 一律 `%s` + `str()`。
				_失败.append("「%s/%s」宽 %s ≠ %s（setPositionTextField 钉死的盒宽）；文案=%s"
					% [档名, 标.name, str(标.size.x), str(期宽), 标.text])
			if 标.vertical_alignment != VerticalAlignment.VERTICAL_ALIGNMENT_TOP:
				_失败.append("「%s/%s」没顶对齐（原版 MLabel 从框顶往下画；居中会把字压到下一行那根条上）"
					% [档名, 标.name])
			var 条名 := String(标.name).trim_suffix("标题")
			var 本条 := 容.get_node_or_null(条名) as Control
			var 期条x := 右列条x if 在右 else 左列条x
			if 本条 == null:
				_失败.append("「%s」有标题却没有同名那根条（%s）" % [档名, 条名])
			else:
				var 条位 := _页内(页, 本条)
				if absf(条位.x - 期条x) > 0.01 or absf(条位.y - (标位.y + 2.0)) > 0.01:
					_失败.append("「%s/%s」页内@(%s,%s)，期望 (%s,%s)（setPositionBar：y=标题+2）"
						% [档名, 条名, str(条位.x), str(条位.y), str(期条x), str(标位.y + 2.0)])
				if absf(本条.size.x - 121.0) > 0.01:
					_失败.append("「%s/%s」宽 %s ≠ 121（setPositionBar width=121）" % [档名, 条名, str(本条.size.x)])
				var 值 := 容.get_node_or_null(条名 + "值") as Label
				if 值 == null:
					_失败.append("「%s/%s」没有同名「值」那枚数字" % [档名, 条名])
				else:
					## 用户 2026-10-30 报「写轮眼的数值偏上，不在数值轴正中间」：数字盒必须与
					## 它那根条**同心**（盒高 = 条高 + 上下各 5，居中后字心 = 条心）。顶对齐只对
					## `*标题` 成立（MLabel 从框顶往下画）；把数字也顶对齐会把字抬到条上沿以上。
					var 值位 := _页内(页, 值)
					var 条心 := 条位.y + 本条.size.y * 0.5
					var 值心 := 值位.y + 值.size.y * 0.5
					if absf(值位.x - 期条x) > 0.01:
						_失败.append("「%s/%s值」页内 x=%s ≠ 条起点 %s" % [档名, 条名, str(值位.x), str(期条x)])
					elif absf(值心 - 条心) > 0.01:
						_失败.append("「%s/%s值」竖直中心 %s ≠ 条中心 %s ⇒ 数字不骑在数值轴正中间"
							% [档名, 条名, str(值心), str(条心)])
					elif 值.vertical_alignment != VerticalAlignment.VERTICAL_ALIGNMENT_CENTER:
						_失败.append("「%s/%s值」不是竖直居中（实测 %s）⇒ 数字不骑在数值轴正中间"
							% [档名, 条名, str(值.vertical_alignment)])
			var 标题右缘 := 标位.x + 标.size.x
			if 本条 != null and _页内(页, 本条).x < 标位.x + 40.0:
				_失败.append("「%s/%s」的条从 x=%s 起，压在标题那一列（40 宽）里面 ⇒ 数值容器挡字"
					% [档名, 条名, str(_页内(页, 本条).x)])
			elif 标题右缘 > 期条x + 2.0:
				_失败.append("「%s/%s」宽到 x=%s，越过条起点 %s ⇒ 标题与条叠了" % [档名, 标.name, str(标题右缘), str(期条x)])
		var 期数 := 4 + 右列数
		if 标题列.size() != 期数:
			_失败.append("「%s」画了 %d 行标题，期望 %d 行（barVisibleArr=%s：左 4 行 + 右 %d 行）"
				% [档名, 标题列.size(), 期数, str(每档总行数[档序]), 右列数])
		var 说明 := 容.get_node_or_null("提升说明1") as Control
		if 说明 != null:
			_矩形(页, 说明, Vector2(11, 310), Vector2(298, 18), "%s/提升说明1(_sayField 第一行)" % 档名)
		var 第二行 := 容.get_node_or_null("(按两下使用)来强化写轮眼") as Control
		if 第二行 != null:
			_矩形(页, 第二行, Vector2(83, 328), Vector2(170, 18), "%s/第二行" % 档名)
		var 当前 := 容.get_node_or_null("当前阶段") as Control
		if 当前 != null:
			_矩形(页, 当前, Vector2(11, 205), Vector2(405, 18), "%s/当前阶段" % 档名)
			var 字 := 当前 as RichTextLabel
			if 字 != null and 字.scroll_active:
				_失败.append("「%s/当前阶段」的 scroll_active 还开着 ⇒ 会自己加一条原版没有的滚动条" % 档名)
	if 判档 != 12:
		_失败.append("只量到 %d 个阶段容器，期望 12 个" % 判档)
	# 同档帧不许把页签打回第一档（用户第二条）。走的是**运行期真的来一帧**那条路：
	# `原地刷新族页` 就是 1821 帧落到界面上的入口（`游戏会话.应用修行 → 后端连接 → 窗口`）。
	var 会话2: Node = root.get_node_or_null("/root/GameSession")
	## `切写轮眼阶段` / `原地刷新族页` 都是 人物窗口.gd 里的 **static func** ⇒ 只能经
	## 脚本对象调（`窗.call(...)` 会报 Nonexistent function，而这个报错只打断本函数、
	## 末行照样能打「通过」—— 所以后面有 `_几何跑完` 那道哨兵）。
	var 人物脚本 = load("res://脚本/界面/窗口/人物窗口.gd")
	人物脚本.切写轮眼阶段(页, 10)          # 玩家自己翻到第 10 档（净眼那一页之前）
	for _帧 in 3:
		await process_frame
	页 = _取页(窗, "写轮眼")
	var 停在 := int(页.get("_当前阶段"))
	if 停在 != 9:
		_失败.append("翻到第 10 档之后界面却是 _当前阶段=%s（他那边 0 起算，期望 9）⇒ 这一腿后面没法判" % str(停在))
	会话2.cultivation_states["写轮眼"] = {"stage": 3, "count": 1, "blessing": 0}   # 与开窗时**同一档**
	人物脚本.原地刷新族页(窗, "写轮眼")
	for _帧 in 3:
		await process_frame
	if int(页.get("_当前阶段")) != 9:
		_失败.append("服务端来的还是档 3（没变），页签却从第 10 档被打回 _当前阶段=%s ⇒ 又犯了「自动回到最初阶段」"
			% str(页.get("_当前阶段")))
	会话2.cultivation_states["写轮眼"] = {"stage": 5, "count": 1, "blessing": 0}   # 真推进了一档
	人物脚本.原地刷新族页(窗, "写轮眼")
	for _帧 in 3:
		await process_frame
	if int(页.get("_当前阶段")) != 4:
		_失败.append("服务端推到 5 阶后界面还停在 _当前阶段=%s ⇒ 「只有阶段真变了才跳」写过头了（原版喂数据那趟是要跳的）"
			% str(页.get("_当前阶段")))
	# ── 轮回六道 ──
	窗.call("_set_character_sub_tab", 1)
	for _帧 in 3:
		await process_frame
	var 轮 := _取页(窗, "轮回六道")
	if 轮 == null:
		_失败.append("⑮ 轮回六道页没建出来")
		return
	_矩形(轮, 轮.get_node_or_null("说明") as Control, Vector2(20, 7), Vector2(150, 160), "说明(_descField)")
	# §3.296 起这两枚是 **TextureButton**（原版 ProgramButton 只铺 upSkin）；`as Button`
	# 对 TextureButton **恒为 null** ⇒ 这一段曾整条假红（2026-10-30 合并跑全量才现形）。
	var 左 := 轮.get_node_or_null("上一页") as TextureButton
	var 右钮 := 轮.get_node_or_null("下一页") as TextureButton
	if 左 == null or 右钮 == null:
		_失败.append("⑮ 轮回六道那两枚翻页钮查无（应是 TextureButton）")
	else:
		_矩形(轮, 左, Vector2(22, 169), Vector2(20, 23), "上一页(ProgramButton upSkin 天然 20×23)")
		_矩形(轮, 右钮, Vector2(147, 169), Vector2(20, 23), "下一页(同上)")
		# §3.296 起是 TextureButton：不再有 `Button` 那条 57 最小宽的毛病，`custom_minimum_size`
		# 这条判据随之作废（留着会拿 (0,0) 判红 = 假红）。手型光标仍是原版 `ProgramButton`
		# 的 `buttonMode/useHandCursor`，照旧判。
		for 枚 in [左, 右钮]:
			if 枚.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
				_失败.append("「%s」不是手型光标（ProgramButton 走 buttonMode）" % 枚.name)
		## 用户报的「右按钮有问题」根因：同一枚钮上 `icon` 与 `normal` 样式框**各画了一遍箭头**。
		var 皮 := 右钮.get_theme_stylebox("normal") as StyleBoxTexture
		if 皮 != null and 皮.texture != null:
			_失败.append("下一页的 normal 样式框还挂着图（%s）⇒ 与 icon 叠成两遍箭头" % str(皮.texture.resource_path))
	_矩形(轮, 轮.get_node_or_null("输入框") as Control, Vector2(45, 169), Vector2(100, 22), "阶段名框(MTextInput2)")
	var 提 := 轮.get_node_or_null("提升轮回六道") as Button
	if 提 == null:
		_失败.append("⑮ 找不到「提升轮回六道」")
	else:
		_矩形(轮, 提, Vector2(53, 191), Vector2(82, 22), "提升轮回六道(btn_width_six)")
	_矩形(轮, 轮.get_node_or_null("阶段资源/底图") as Control, Vector2(178, 5), Vector2(240, 208), "画板(MPane_background)")
	var 画 := 轮.get_node_or_null("阶段资源") as Control
	if 画 != null:
		var 图数 := 0
		for 件 in 画.get_children():
			var 张 := 件 as TextureRect
			if 张 == null or String(张.name) == "底图":
				continue
			图数 += 1
			_矩形(轮, 张, Vector2(181, 8), Vector2(233, 201), "阶段图 %s（createLunHuiYanBtn 每张 x=3 y=3 于画板内）" % 张.name)
		if 图数 != 8:
			_失败.append("阶段资源里只有 %d 张阶段图，期望 8 张" % 图数)
	_矩形(轮, 轮.get_node_or_null("属性面板") as Control, Vector2(3, 213), Vector2(416, 149), "下面板(_downPanel)")
	## 进度条：`LunHuiYanPanel.as:412-415` ⇒ 画板内 (20,185) = 页内 (198,190)，宽 200；
	## **条上那行数字原版是有的**（2026-10-30 用户报「数值轴不显示数值」后重读真值）：
	## `createBar(...,"",200)` 的 `""` 是 `labelText`=左侧标题（`MBar.as:63-69`），与值文本是两回事；
	## `MBar.setData` 末尾 `this.tf.text = param1 + "/" + param2`（`MBar.as:150-178`，没设 showPercent
	## 也走这条）⇒ 8 枚 `进度值` 必须显，且与条同心；数字由 `轮回六道切换.gd::_update_ui` 写。
	var 数区 := 轮.get_node_or_null("属性面板/阶段数值容器") as Control
	if 数区 == null:
		_失败.append("⑮ 找不到「属性面板/阶段数值容器」")
	else:
		var 条数 := 0
		for 组 in 数区.get_children():
			var 本 := 组.get_node_or_null("进度") as ProgressBar
			if 本 == null:
				continue
			条数 += 1
			_矩形(轮, 本, Vector2(198, 190), Vector2(200, 11), "%s/进度(_jinDuBar 轨道原生高 11，见 真值/窗口/宠物.md §10 tag158=122×11)" % String(组.name))
			## 阶段名：原版是 `MTextInput2`（100×22，见 `真值/窗口/人物窗秘术页.md` §②），
			## 文字框在框内 x=3、宽 100−2×3=94 ⇒ 页内 (48,169) 94×22，水平/竖直都居中。
			## 用户 2026-10-30 报「境界的文字偏上，不在框内正中间」= 合并后框从 93×20 换成 100×22，
			## 而这枚 Label 还是旧偏移（68,−46..112,−31，顶对齐）⇒ 卡在框上沿。
			var 名 := 组.get_node_or_null("阶段名称") as Label
			if 名 == null:
				_失败.append("「%s」少了阶段名那枚 Label" % String(组.name))
			else:
				_矩形(轮, 名, Vector2(48, 169), Vector2(94, 22), "%s/阶段名称(MTextInput2 文本框 100−2×3 宽)" % String(组.name))
				if 名.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER or 名.vertical_alignment != VerticalAlignment.VERTICAL_ALIGNMENT_CENTER:
					_失败.append("「%s/阶段名称」没在框内居中（水平=%s 竖直=%s）⇒ 字会贴边/偏上"
						% [String(组.name), str(名.horizontal_alignment), str(名.vertical_alignment)])
			var 字 := 组.get_node_or_null("进度值") as Label
			if 字 == null:
				_失败.append("「%s」少了条上那枚数字「进度值」" % String(组.name))
			else:
				var 字位 := _页内(轮, 字)
				var 字心 := 字位.y + 字.size.y * 0.5
				var 条心 := 190.0 + 本.size.y * 0.5
				if not 字.visible:
					_失败.append("「%s/进度值」被藏了（原版 MBar.setData 把 cur/max 写进 tf，条上本来就有数字）" % String(组.name))
				elif absf(字位.x - 198.0) > 0.01 or absf(字.size.x - 200.0) > 0.01 or absf(字心 - 条心) > 0.01:
					_失败.append("「%s/进度值」页内@(%s,%s) %sx%s，应与进度条同框同心（字心 %s / 条心 %s）"
						% [String(组.name), str(字位.x), str(字位.y), str(字.size.x), str(字.size.y), str(字心), str(条心)])
				elif 字.vertical_alignment != VerticalAlignment.VERTICAL_ALIGNMENT_CENTER:
					_失败.append("「%s/进度值」不是竖直居中⇒数字不骑在数值轴正中间" % String(组.name))
		if 条数 != 8:
			_失败.append("只有 %d 档有进度条，期望 8" % 条数)
	## ── 分母必须由**真初始化链**推进页里（2026-10-30 实机截图逮到「52/0」）──
	## `初始化轮回六道页` 算好 `上限们` 却漏了 `页面.set("各阶上限", …)` ⇒ 页面 `上限()` 恒 0、
	## 条 max=0 整条满格、条上写「52/0」。这里**走真入口**重初始化（`原地刷新族页`，与修炼回帧
	## 同一条路），不看源码串（假绿 #24）：
	##   · Etc 真值 60/75/90/105/120/135/150/0（`数据/原版杂项.json` `LunHuiYan`）；
	##   · 会话里 4 阶、精魂 2 ⇒ 条上「2/105」（`LunHuiYanPanel.as:151-155` 当前阶分支）；
	##   · 对照 `对比图/原轮回六道.png`：1 阶翻看天道应「0/135」= 0/(60+75)
	##     （`:157-166` 累加分支 —— 不是数据表里 stage2 有 135，别把累加结果写回表）。
	# 前面的提升弹窗腿会改 `cultivation_states`（跑到这里它已被复位成 stage 0），这里显式摆回
	# 本腿要的档位再走真入口 —— 否则量到的是「1 阶看 4 阶」，不是当前阶那条分支。
	会话.cultivation_states["轮回六道"] = {"stage": 4, "count": 2}
	if not bool(人物脚本.原地刷新族页(窗, "轮回六道")):
		_失败.append("⑳ 轮回六道页开着却没能原地重初始化 ⇒ 这条分母腿没验到真链")
	else:
		var 真上限: Array = 轮.get("各阶上限") as Array
		var 期上限: Array = [60.0, 75.0, 90.0, 105.0, 120.0, 135.0, 150.0, 0.0]
		if 真上限.size() != 8:
			_失败.append("⑳ 初始化后 `各阶上限` 只有 %d 项（期望 8 项 Etc 真值）⇒ 分母表没推进页里"
				% 真上限.size())
		else:
			for _i in 8:
				if absf(float(真上限[_i]) - float(期上限[_i])) > 0.01:
					_失败.append("⑳ `各阶上限[%d]` = %s，Etc 真值 %s"
						% [_i, str(真上限[_i]), str(期上限[_i])])
		if 数区 != null:
			var 组4 := 数区.get_child(3) as Control
			var 条4 := 组4.get_node_or_null("进度") as ProgressBar if 组4 != null else null
			var 字4 := 组4.get_node_or_null("进度值") as Label if 组4 != null else null
			if 条4 == null or 字4 == null:
				_失败.append("⑳ 4 阶组缺「进度」或「进度值」")
			elif String(字4.text) != "2/105" or absf(条4.value - 2.0) > 0.01 or absf(条4.max_value - 105.0) > 0.01:
				_失败.append("⑳ 当前 4 阶、精魂 2 时条上该「2/105」（漏接上限表时是「2/0」+整条满格），实测「%s」%s/%s"
					% [String(字4.text), str(条4.value), str(条4.max_value)])
			# 原版截图那条：1 阶(六道开启)时翻到天道 ⇒ 看的是**未到的阶**，走累加分支
			轮.set("已开阶", 1)
			轮.set("精魂数", 0)
			轮.set("current_index", 1)
			轮.call("_update_ui")
			var 组2 := 数区.get_child(1) as Control
			var 字2b := 组2.get_node_or_null("进度值") as Label if 组2 != null else null
			if 字2b == null or String(字2b.text) != "0/135":
				_失败.append("⑳ 1 阶时翻看天道应「0/135」（`对比图/原轮回六道.png`；累加 0/(60+75)），实测「%s」"
					% ("缺节点" if 字2b == null else String(字2b.text)))
	# 进度三分支：参照值由**门自己**按 §② 那条算式算，不许问被测脚本要
	var 上限们: Array = [60.0, 135.0, 200.0, 300.0, 420.0, 560.0, 720.0, 900.0]
	轮.set("各阶上限", 上限们)
	轮.set("已开阶", 4)
	轮.set("精魂数", 7)
	var 期望腿: Array = [
		[2, 135.0, 135.0],          # 看第 2 阶（已过去）⇒ 满
		[4, 7.0, 300.0],            # 看当前那阶 ⇒ (精魂数, 本阶上限)
		# 看第 6 阶（还没到）：分子 = 第 1..已开−1 阶上限之和 + 精魂数（**不含已开那一阶**，
		# `while(_loc5_ < currIndex)` 从 1 走到 3），分母 = 第 1..6 阶之和。
		[6, 60.0 + 135.0 + 200.0 + 7.0, 60.0 + 135.0 + 200.0 + 300.0 + 420.0 + 560.0],
	]
	for 腿: Array in 期望腿:
		var 得: Vector2 = 轮.call("进度对", int(腿[0]))
		if absf(得.x - float(腿[1])) > 0.01 or absf(得.y - float(腿[2])) > 0.01:
			_失败.append("已开 4 阶、精魂 7 时看第 %d 阶，进度该 (%s,%s)，实测 (%s,%s)"
				% [腿[0], str(腿[1]), str(腿[2]), str(得.x), str(得.y)])
	## 条上的数字**跑真入口**：改 `current_index` 后调页面自己的 `_update_ui()`（翻页/刷新都走它），
	## 看条和数字是否真跟着换成 (分子,分母)。⚠ 不能只 grep 源码里有没有 `进度值.text`（假绿 #24）。
	if 数区 != null:
		for 腿2: Array in [[0, 60.0, 60.0], [3, 7.0, 300.0], [5, 402.0, 1675.0]]:
			轮.set("current_index", int(腿2[0]))
			轮.call("_update_ui")
			var 组2 := 数区.get_child(int(腿2[0])) as Control
			var 条2: ProgressBar = null
			var 字2: Label = null
			if 组2 != null:
				条2 = 组2.get_node_or_null("进度") as ProgressBar
				字2 = 组2.get_node_or_null("进度值") as Label
			var 息 := "%d/%d" % [int(腿2[1]), int(腿2[2])]
			if 字2 == null or not 字2.visible or String(字2.text) != 息:
				_失败.append("看第 %d 阶时条上该写「%s」（MBar.setData：cur/max），实测「%s」（显隐=%s）"
					% [int(腿2[0]) + 1, 息,
						"缺节点" if 字2 == null else String(字2.text),
						"缺节点" if 字2 == null else str(字2.visible)])
			if 条2 == null or absf(条2.value - float(腿2[1])) > 0.01 or absf(条2.max_value - float(腿2[2])) > 0.01:
				_失败.append("看第 %d 阶时条该是 %s/%s，实测 %s"
					% [int(腿2[0]) + 1, str(腿2[1]), str(腿2[2]),
						"缺节点" if 条2 == null else "%s/%s" % [str(条2.value), str(条2.max_value)]])
	几何跑完到底()


## 哨兵：函数最后一句才置真 ⇒ 中途报错退出时调用点能看出来这一腿没判满
## （同 ⑭ `_信息提示跑完` 那条口径：`SceneTree` 脚本里一次 SCRIPT ERROR 只带走当前这个函数，
##   调用方照样跑完、末行照样打「通过」）。
func 几何跑完到底() -> void:
	_几何跑完 = true


## 逐件矩形核对：位置**必须等值**，宽度可以按 `MButton3.as:654`（长文自己撑宽）放开。
## ⚠ 一律换算成**页内坐标**：`Control.position` 是相对**父节点**的，而那些行件的父亲是
##   `属性面板`（页内 (5,205)）/ `阶段数值容器/<阶>` —— 直接拿 position 去比 AS3 的页内数，
##   每一行都差一个父偏移（10-25 第一版就这么误判了 372 条红，场景其实是对的）。
func _页内(页: Control, 件: Control) -> Vector2:
	return 件.global_position - 页.global_position


func _矩形(页: Control, 件: Control, 期位: Vector2, 期尺: Vector2, 话: String, 宽可撑宽 := false) -> void:
	if 件 == null:
		_失败.append("⑮ 找不到「%s」" % 话)
		return
	var 位 := _页内(页, 件)
	if 位.distance_to(期位) > 0.01:
		_失败.append("「%s」页内@(%s,%s)，期望 (%s,%s)" % [话, str(位.x), str(位.y), str(期位.x), str(期位.y)])
	if 件.size.y != 期尺.y or (not 宽可撑宽 and 件.size.x != 期尺.x):
		_失败.append("「%s」%sx%s，期望 %sx%s" % [话, str(件.size.x), str(件.size.y), str(期尺.x), str(期尺.y)])
