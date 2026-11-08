extends RefCounted
## 宠物主窗渲染 —— 1:1 对 `PetWindow.as`（444×408「我的通灵兽」）。
## 几何全部来自 §3.62.1 的逐行搬运；数值全部走 `脚本/角色/宠物数值.gd`（原版 PetAddValue 公式）。
## 页坐标 = AS3 窗口坐标 − (10, 41)：`列表底板` 在 AS3 (13,41) → 页 (3,0)。
##
## 旧版这页是**自造物**（假 6 行属性 `暴击=stage*2`、捕捉/融魂按钮、自造技能面板），
## §3.61.4 B6 那类。本版把这些全删了：原版主窗没有捕捉按钮（捕捉在世界里打野宠）、
## 没有融魂按钮（融魂在右侧「通灵驯养」页签，第 3 批做）、驯养按钮**原版只刷新不发协议**
## （`PetWindow.as:185-187` 的 `onClickHand` 里 `_btnGive` 走 `selectedPet`）。

const 宠物场景 := preload("res://场景/界面/窗口/宠物/宠物窗口.tscn")
const 宠物数值 := preload("res://脚本/角色/宠物数值.gd")
const 扩容需求 := preload("res://脚本/界面/扩容需求.gd")
const 数据 := preload("res://脚本/单例/游戏数据.gd")
const 格子提示框 := preload("res://脚本/界面/组件/格子提示框.gd")
## 六根滑条（经验/攻/防/敏/体/梦幻）的 0.5s 补间与早退口径（真值 `真值/窗口/进度条补间.md`）。
const 进度条补间 := preload("res://脚本/单例/进度条补间.gd")
const 内容面板 := "res://素材/界面/原版窗口/通用控件/内容面板.png"
const 状态附 := "res://素材/界面/原版窗口/宠物/状态_附.png"
const 状态战斗 := "res://素材/界面/原版窗口/宠物/状态_战斗.png"

## 原版各处的悬停提示（`PetWindow.as:830-916` 的 `TextTip` 第 2 参 = 语言表键）。
## ⚠️ 原版的说明是**富文本**（`MToolTipText` 渲染 `<br/>` 与 `<font color>`），
## 我们这边只有纯文本 tooltip（全工程同此），所以把标签**剥掉、内容照留**，
## 不改写文案。要还原颜色得先有富文本提示框（登记在 §3.62 待办）。
const 提示 := {
	# PETWINDOW_LEVEL_DESC / PETWINDOW_WU_XING_DESC / PETWINDOW_PRICE_DESC
	"等级": "通灵兽的等级越高则将为你带来的属性加成也将越多",
	"悟性": "悟性值(0-100之间)越高，则通灵兽升级时领悟新技能的几率越大",
	"价值": "通灵兽身价",
	# PETWINDOW_EXP_DESC
	"经验": "达到升级所需的经验时，通灵兽将会自动提升等级。在与主人共同打怪战斗过程中将会获得经验",
	# PETWINDOW_GONGJIQIANLI_TIP / FANGYUQIANLI_TIP / LINGQIAOQIANLI_TIP / JIANSHENQIANLI_TIP
	"攻击潜力": "攻击潜力越高则给主人带来的攻击加成也会越高",
	"防御潜力": "防御潜力越高则给主人带来的防御加成也会越高",
	"灵巧潜力": "灵巧潜力越高则给主人带来的轻身加成也会越高",
	"健体潜力": "健体潜力越高则给主人带来的健体加成也会越高",
	# PETWINDOW_FUSHEN_TIP / XUNYANG_TIP / CHUZHAN_TIP / FANGSHENG_TIP
	"附身": "通灵兽附身到人物身上（附身之后人物将会获得该通灵兽带来的属性加成）",
	"驯养": "通过驯养操作可以让通灵兽变得更加强大",
	"出战": "选择让该通灵兽出战（出战后的通灵兽将会与你共同作战）",
	"放生": "放生该通灵兽，放生后的通灵兽将会消失（选择放生通灵兽后将空出一个兽栏）",
}

## 五个装备位的**部位号**（PetWindow.as:482-508 的摆位 → 节点名）。
## ⚠️ 节点名现在**直接等于部位号**（`装备槽_1..5`）；场景里那些格的屏幕摆位是
## 兽铠左上 / 兽盔左下 / 变身中间 / 兽符右上 / 兽爪右下 —— 摆位与编号不等，
## 别再按"第几个格子"推部位（上一版就是那样，`装备槽_2` 被塞了变身的语义）。
const 装备部位 := [1, 2, 3, 4, 5]
const 槽位高亮 := ["攻击潜力条", "防御潜力条", "灵巧潜力条", "健体潜力条"]


## 原版 `PetWindow.updatePetStatus:329-358` 的**三态钮矩阵**（AS3 原样）：
## | 状态   | 附身            | 出战            | 放生     |
## | NORMAL | 「附身」enabled | 「出战」enabled | enabled  |
## | SUMMON | 「回收」enabled | 「出战」disabled| disabled |
## | ATTACK | 「附身」disabled| 「回收」enabled | disabled |
## 现行版本只按 attached/deployed 改**文案**、enabled 一律 `not 有宠` ——
## 结果是「出战中还能点附身」「附身中还能点出战/放生」，全靠服务端兜（服务端那些拒绝是
## `CHAT_MESSAGE` 的 `CHAR_NOTICE(512)` 位，见 `后端连接._handle_chat_text`）。
## 这条做成纯函数是为了让离线门能钉。
static func 按钮状态(附身中: bool, 出战中: bool) -> Dictionary:
	return {
		"附身文本": "回收" if 附身中 else "附身",
		"出战文本": "回收" if 出战中 else "出战",
		"附身禁用": 出战中,
		"出战禁用": 附身中,
		"放生禁用": 附身中 or 出战中,
	}


## 原版各处的悬停提示（`PetWindow.as:830-916` 的 `TextTip` 第 2 参 = 语言表键）。
## ⚠️ 原版的说明是**富文本**（`MToolTipText` 渲染 `<br/>` 与 `<font color>`），
## 我们这边只有纯文本 tooltip（全工程同此），所以把标签**剥掉、内容照留**，
## 不改写文案。要还原颜色得先有富文本提示框（登记在 §3.62 待办）。


## ── 只读那一扇的**逐件摆位**（原版 `SimplePetWindow` 不是把 `PetWindow` 平移一份）──────
## 换算：`.tscn` 里的坐标是按 `PetWindow` 烘的，而 `PetWindow` 的窗口坐标 =
## `SimplePetWindow` 的 pane 坐标 + `(5,8)`（锚点 `_leftUpSkin`：Pet `(13,40)` `:447-455`
## vs Simple `(8,32)` `:217-225`），本页场景坐标 = 窗口坐标 − `(8,38)`
## ⇒ **场景 = pane − (3,30)** ⇒ 整页摆在 `人物扩展页` 的 `(3,30)` 就对上 pane 了。
## 下面列的是**在这个换算之外还各自不同的那批**，值一律取 Simple 那一侧的字面坐标
## （括号里是 `SimplePetWindow.as` 的行号），换成场景坐标后写死。
## ⚠ 两处已知没跟上的（都 ≤1 像素级，见 `真值/窗口/人物属性_看别人.md §⑬·1`）：
##   底排八格 `SkillCellF` 的步距 Pet 用 `CONTENT_GAP=8`、Simple 写死 `7`；
##   本表按 pane 摆第一格，后面七格沿用场景里的 8 步距 ⇒ 最右那格偏 7。
const 只读摆位 := {
	"携带数量": [9.0, 6.0],					# `:406-408` x=12、y=leftUpSkin.y+5−1=36
	"携带分隔线": [7.0, 25.0, 180.0, 27.0],	# `:287-290` x=leftUpSkin.x+2=10、y=55、宽 177−4
	"列表滚动": [7.0, 25.0],				# `:412-419` x=leftUpSkin.x+2=10、y=txtNum.y+h−1=55
	"装备面板": [185.0, 2.0, 421.0, 110.0],	# `:241-244` x=leftUpSkin.x+180=188、y=32、236×108
	## ⚠ 这五格的**编号 ≠ 屏幕位**：AS3 里 `equip1..5` 是按 `PetA/D/C/B/E` 绑的
	## （`:270-274`），映射到部位号就是 1/4/3/2/5，而摆位是
	## 左上(196,42)｜左下(196,86)｜右上(376,42)｜右下(376,86)｜中下(241,86)。
	## 上一版按"第几格"抄，把 _2/_3/_5 三个写串了位 —— 改这里要回到 `:251-259` 逐行算。
	"装备槽_1": [193.0, 12.0],				# `:251-252` equip1=PetA：x=equipPanlSkin.x+8=196、y=+10=42
	"装备槽_2": [373.0, 56.0],				# `:257-258` equip4=PetB：x=equip3.x=376、y=equip2.y=86
	"装备槽_3": [373.0, 12.0],				# `:255-256` equip3=PetC：x=equip1.x+180=376、y=equip1.y=42
	"装备槽_4": [193.0, 56.0],				# `:253-254` equip2=PetD：x=equip1.x、y=+height(40)+4=86
	"装备槽_5": [238.0, 56.0],				# `:259` equip5=PetE：x=equip2.x+width(40)+5=241、y=86
	"模型观赏": [295.0, 82.0],				# 跟着装备面板 −2（面板中心 306 vs 308）
	"梦幻条": [202.0, 95.0],					# `:426-428` x=250−45=205、y=125（Pet 是 130）
	"名称标题": [190.0, 112.0],				# `:441` _labName.x=193（Pet 200）
	"名称": [225.0, 110.0],					# `:463` labName.x+width+5=228
	"等级标题": [345.0, 112.0],				# `:445` _labLevel.x=348（Pet 355）
	"等级": [380.0, 112.0],					# `:465` 348+30+5=383
	"品级标题": [190.0, 128.0],				# `:442-443` = 名称标题 x
	"品级": [225.0, 128.0],					# `:467`
	"悟性标题": [270.0, 128.0],				# `:450` _labSavvy.x=273（Pet 280）
	"悟性": [305.0, 128.0],					# `:469` 273+30+5=308
	"价值标题": [345.0, 128.0],				# `:447` = 等级标题 x
	"价值": [380.0, 128.0],					# `:471`
	"附身": [211.0, 152.0],					# `:492-495` _btnHide.x=214、y=182（Pet 200/190）
	"驯养": [260.0, 152.0],					# `:493` +width(37)+**12**=263（Pet 的间隔是 20）
	"出战": [309.0, 152.0],					# `:494` 263+49=312
	"放生": [358.0, 152.0],					# `:495` 312+49=361
	"分隔线一": [185.0, 180.0, 421.0, 182.0],	# `:278-283` x=equipPanlSkin.x、y=210、宽 236
	"分隔线二": [185.0, 220.0, 421.0, 222.0],	# `:284` y=250
	"分隔线三": [185.0, 312.0, 421.0, 314.0],	# `:285` y=342
	"经验标题": [195.0, 192.0],				# `:523-524` _labExp.x=198、y=222（Pet 198/224）
	"经验条": [207.0, 192.0, 375.0, 208.0],	# `:531-533` _barExp.x=210、y=labExp.y、宽 168
	"总值标题": [193.0, 222.0],				# `:538-539` _bmpMax.x=196、y=252（Pet 196/257）
	"总值": [283.0, 221.0],					# `:544-545` _txtMax.x=286、y=251
	"攻击潜力标题": [195.0, 237.0],			# `:526` _labApAtk.y=267（Pet 272）
	"防御潜力标题": [195.0, 255.0],			# `:527` +height(18)
	"灵巧潜力标题": [195.0, 273.0],			# `:528`
	"健体潜力标题": [195.0, 291.0],			# `:529`
	"攻击潜力条": [207.0, 237.0, 375.0, 253.0],	# `:532-534` _barApAtk.x=210
	"防御潜力条": [207.0, 255.0, 375.0, 271.0],
	"灵巧潜力条": [207.0, 273.0, 375.0, 289.0],
	"健体潜力条": [207.0, 291.0, 375.0, 307.0],
}


## 自己那扇：整页现建现挂（原版 `PetWindow` 每次 `_render_page` 重建内容）。
static func 渲染(窗口) -> void:
	var 页面 := 宠物场景.instantiate() as Control
	窗口._apply_common_control_skins(页面)
	窗口._content.add_child(页面)
	渲染进(窗口, 页面)


## 宠物页的**填法**单独拆出来，是为了让「看别人」那一扇能把自己那份
## 现成的页面（`场景/界面/窗口/人物/页面/宠物页.tscn` 里实例化的同一套件）喂进来画。
## 原版那两扇本来就是两套实现：`PetWindow`（自己的）与 `SimplePetWindow`（看别人的，
## `CharOtherWindow2.as:353-360` 建它并把 `petPane` 摆在 `(-5,-27)`、喂 `setPetData(petList, petLimit)`）
## —— 元素与摆位一致，差在**只读那一扇不挂任何操作监听**
## （`SimplePetWindow` 整份 AS3 里 `addEventListener` 只有列表 ITEM_CLICK 一条，见 `:143`；
## 四颗钮 `_btnHide/_btnGive/_btnShow/_btnDel` 画出来了却一颗都没接，`:486-495`）。
static func 渲染进(窗口, 页面: Control, 只读档: Dictionary = {}) -> void:
	var 只读 := not 只读档.is_empty()
	## ⚠ 只读时**一份都不碰我自己的镜像**：清单与上限都来自对方那发 `58:0`
	##（段 32 宠物串 + 段 14 宠物上限，由 `人物窗口.他人宠物()` 解好塞进 `只读档`）。
	var 清单: Array = 只读档.get("宠物清单", []) if 只读 else 窗口._session.pets
	var 上限: int = int(只读档.get("宠物上限", 10)) if 只读 else int(窗口._session.pet_capacity)
	窗口._apply_common_control_skins(页面)

	(页面.get_node("内容底") as Panel).add_theme_stylebox_override("panel", 窗口._texture_style(内容面板))
	for 底板名 in ["列表底板", "属性底板"]:
		(页面.get_node(底板名) as Panel).add_theme_stylebox_override("panel", 窗口._sub_panel_style())
	if 只读:
		## 只读那一扇**没有自己的大底板**：`SimplePetWindow` 一共只画三块皮
		## （`_leftUpSkin/_leftdownSkin/_equipPanlSkin`，`:217-245`），整页背景是宿主窗
		## 那块 422×366 的底板（`CharOtherWindow2.as:347-363`）⇒ `内容底` 藏掉，
		## 否则两层底板叠在一起，比对方窗里别的那几页明显深一档。
		(页面.get_node("内容底") as Panel).visible = false
		for 节点名 in 只读摆位:
			var 件 := 页面.get_node_or_null(String(节点名)) as Control
			if 件 == null:
				push_error("宠物只读页摆位查无节点：%s（场景改了名要同步这张表）" % 节点名)
				continue
			var 值: Array = 只读摆位[节点名]
			件.offset_left = float(值[0])
			件.offset_top = float(值[1])
			if 值.size() > 2:
				件.offset_right = float(值[2])
				件.offset_bottom = float(值[3])

	# —— 携带数量（PetWindow.as:1002：`n + "/" + curSoltNum`，无空格）
	(页面.get_node("携带数量") as Label).text = "携带数量%d/%d" % [清单.size(), 上限]

	# —— 列表（updateShouLanList:994-1043：宠物行 → 空闲兽栏行 → 一条红字扩展兽栏后 break）
	var 列表 := 页面.get_node("列表滚动/宠物列表") as VBoxContainer
	if 只读:
		## 原版 `setPetData:549-563` 每喂一份**新档案**就把 `_curPet` 归 0（不是"记住上一次选的"），
		## 而同一份档案里点行是 `onListHand → selectedPet(index)`。⇒ 判据取"这一份清单里有没有它"：
		## 换人 ⇒ 不命中 ⇒ 回到第一只；同一个人重复渲染 ⇒ 命中 ⇒ 保留。
		## ⚠ 光比 unique_id 还不够：夹具给两个号造的宠物 `unique_id` 是同一串（`910_000 + index`），
		##   所以还要看这份档案是谁的（`_他人宠物归属号`）—— 本地夹具正好会撞。
		var 旧选 := str(窗口.get("_他人宠物选中号"))
		var 换了人 := int(窗口.get("_他人宠物归属号")) != int(只读档.get("归属号", -1))
		if 换了人 or (not 清单.is_empty() and 查宠(清单, 旧选).is_empty()):
			窗口.set("_他人宠物选中号", 行号(清单[0] as Dictionary, true) if not 清单.is_empty() else "")
		窗口.set("_他人宠物归属号", int(只读档.get("归属号", -1)))
	elif 窗口._selected_pet_id.is_empty() and not 清单.is_empty():
		窗口._selected_pet_id = String((清单[0] as Dictionary).get("id", ""))
	## ⚠ 只读那一扇的游标存在 `_他人宠物选中号`，**不写 `_selected_pet_id`**：原版两扇各带一个游标
	## （`PetWindow.selectedPet` / `SimplePetWindow._curPet`，后者整份 AS3 里没有第二个游标字段），
	## 而 `_selected_pet_id` 是**我这扇**的（改名、交易带宠那些读取者都在读它）。
	## 现在两扇是不同实例 ⇒ 串不到画面，但让只读页去改自己那扇的游标语义上就是错的，
	## 留着它等于给"以后复用同一实例"埋雷。（这条**没有**实测到的用户可见症状，属状态归属修正。）
	## 取值要放在上面那段**之后**，否则"换人回第一只"这一轮还是旧号。
	var 选中号 := str(窗口.get("_他人宠物选中号")) if 只读 else str(窗口._selected_pet_id)
	# 原版列表行数 = max(10, 宠物数)（MaxSolt=10 只是空行循环上限，宠物行不限）
	# ⚠ 只读那一扇只补到**他有几行**（原版 `SimplePetWindow.updateShouLanList:570-604` 的
	#   DataProvider 只 push `_petDatas.length` 条 ⇒ 没有「空闲兽栏」空行、也没有「扩展兽栏」行；
	#   那两样是 `PetWindow` 才有的）。
	var 行数 := 清单.size() if 只读 else maxi(10, 清单.size())
	while 列表.get_child_count() - 1 < 行数:
		var 补 := (load("res://场景/界面/组件/宠物条目.tscn") as PackedScene).instantiate() as Button
		补.name = "宠物条目_%d" % (列表.get_child_count() - 1)
		列表.add_child(补)
		列表.move_child(补, 列表.get_child_count() - 2)   # 保持在「扩展兽栏」之前
	# 原版 updateShouLanList:1006-1040 精确复刻：
	#   宠物行全出（不封顶）→ 从 pets.size() 起补「空闲兽栏」到 curSoltNum →
	#   第一条 >= curSoltNum 的行放「扩展兽栏」然后 **break**（它后面的行根本不存在）。
	#   ⚠️ 整个补行循环被 `MaxSolt=10` 封顶：**curSoltNum ≥ 10 时连扩展兽栏行都不出**
	#   （夹具容量就是 10 —— 别把这条当 bug 修）。
	# ⚠️ **只读那一扇不补空行、也没有「扩展兽栏」行** —— 原版 `SimplePetWindow.updateShouLanList:570-604`
	#   的 DataProvider 只 push `_petDatas.length` 条（他自己有几只就几行），
	#   空闲兽栏与扩容那一行是 `PetWindow` 才有的东西。
	var 扩展行号 := maxi(清单.size(), 上限)
	for 序号 in 行数:
		var 条目 := 列表.get_node("宠物条目_%d" % 序号) as Button
		条目.visible = true
		(条目.get_node("选中条") as Control).visible = false
		(条目.get_node("状态") as Control).visible = false
		条目.disabled = false
		var 已选 := false
		if 序号 < 清单.size():
			已选 = _填宠物行(窗口, 条目, 清单[序号], 选中号, 只读)
		elif 序号 < 上限:
			_填占位行(条目, "空闲兽栏", Color.WHITE)
		else:
			条目.visible = false
			continue
		# 悬停亮黄框（原版 `PetItemRenderer.overHandler:124-128` / `outHandler:134-141`）：
		# **空行也要接** —— 原版空行是 `disabled=false` + `onListHand` 里 `if(id==0) return`
		# 拦点击；我们上一版给空行设 `disabled=true`，而禁用的 Control 根本不吃鼠标 ⇒
		# 悬停事件永远不发，黄框只在"选中的那只"上亮（真值 §15A）。
		_接悬停(条目, 已选)
	## ⚠ **这一轮没填到的行要显式藏掉**：场景里那十行 `宠物条目_*` 本来就 `visible = true`，
	## 而自己那扇的 `行数 = max(10, 宠物数)` 恰好把十行全过一遍 ⇒ 看不出这个问题。
	## 只读那一扇只填**他有的那几只**，后面那几行若不管，就带着场景默认值留在列表里
	## （10-16 现查：他有 3 只却露 10 行，`⑲ 他有几只就几行` 那条就是为这一条写的）。
	for 序 in range(行数, 列表.get_child_count()):
		var 剩 := 列表.get_child(序) as Button
		if 剩 != null and String(剩.name) != "扩展兽栏":
			剩.visible = false
	var 扩展 := 列表.get_node("扩展兽栏") as Button
	_填扩展行(扩展)
	_接悬停(扩展, false)
	扩展.visible = (not 只读) and 扩展行号 < 10
	if 扩展.visible:
		列表.move_child(扩展, 扩展行号)
	# —— 扩展兽栏：点开「格数扩展」窗（原版 `PetWindow.as:366-370`
	#    `showEnlargeWindow()` + `enlargeWindow.setData(curSoltNum − 3, 2)`，归属号 2 = 兽栏）。
	#    §3.93 并包时 `扩容窗口` 加了兽栏分支、说明里写着"调用方要同步"，但**这一处没同步**：
	#    行是可见可点的空壳（`功能入口回归测试` ④ 只验了 `not disabled` ⇒ 假绿）。
	#    2026-10-11 接上：开窗 → 确定 → `PET_ACTION` 19（扩兽栏）。
	var 扩容 := 页面.get_node_or_null("扩容窗口")
	## ⚠ 只读那一扇**整条扩容链都不接**：`SimplePetWindow.updateShouLanList:570-604` 的
	## DataProvider 只 push 他有的那几只 ⇒ 连「扩展兽栏」那一行都没有（上面 `扩展.visible`）。
	if not 只读 and 扩容 != null:
		for 连 in 扩展.pressed.get_connections():
			扩展.pressed.disconnect(连["callable"])
		扩展.pressed.connect(_开兽栏扩容窗.bind(窗口, 页面))
		for 连 in 扩容.get_signal_connection_list("确认扩充"):
			扩容.disconnect("确认扩充", 连["callable"])
		扩容.connect("确认扩充", func(_归属: String) -> void:
			var 后端 = 窗口._backend
			if 后端 == null or not 后端.has_method("request_extend_pet_limit"):
				窗口._show_hint("扩展兽栏：未连接服务端")
			elif not 后端.request_extend_pet_limit():
				窗口._show_hint("扩展兽栏请求发送失败")
			# 发成功不提示：兽栏数等回帧重绘（同背包/仓库那两条）。
		)
		for 连 in 扩容.get_signal_connection_list("请求购买"):
			扩容.disconnect("请求购买", 连["callable"])
		# 同背包那扇：原版 `EnlargeWindow.onClickBuy` 只 dispatch `REQUEST_CASH_ITEM_INFO`。
		扩容.connect("请求购买", func(密卷id: String) -> void:
			窗口.请求商城商品(密卷id))

	# —— 选中宠物（⚠ 只读时**不许**用 `窗口._pet_by_id` —— 那是查我自己的镜像）
	var 宠物: Dictionary = 查宠(清单, 选中号) if 只读 else 窗口._pet_by_id(窗口._selected_pet_id)
	var 有宠 := not 宠物.is_empty()
	(页面.get_node("属性底板/空提示") as Control).visible = not 有宠
	(页面.get_node("属性底板/属性") as Control).visible = 有宠
	for 节点名 in ["模型观赏", "名称", "等级", "品级", "悟性", "价值", "改名", "梦幻条", "技能栏"] + 装备部位.map(func(号): return "装备槽_%d" % 号):
		## 「改名」(`_labChangeName`) 是 `PetWindow.as:841-842` **自己建的那枚**，
		## `SimplePetWindow` 整份里没有它 ⇒ 只读那一扇就算选到宠也不许出现。
		(页面.get_node(节点名) as CanvasItem).visible = 有宠 and not (只读 and 节点名 == "改名")
	for 按钮名 in ["附身", "驯养", "出战", "放生"]:
		var 按钮 := 页面.get_node(按钮名) as Button
		窗口._configure_standard_button(按钮)
		# ⚠️ `_configure_standard_button` 把宽度钉成 **57**（按钮.png 的原始尺寸，全工程通用），
		#    但原版宠物窗这四颗是 `UIConfig.btn_width_two = 37`（`PetWindow.as:892`）。
		#    实测对照图：文字中心 218/275/332/389、间距 57 —— 按 37 宽算中心正是 218.5/275.5/332.5/389.5，
		#    按 57 算会偏到 228.5…，所以这里必须覆盖回 37。
		按钮.custom_minimum_size = Vector2(37.0, 22.0)
		## ⚠ 只读那一扇四颗**永远是灰的**：`SimplePetWindow.as:485` 建的时候就 `enabled = false`，
		## 全文件再没有第二处 `enabled`（自己那扇靠 `onClickHand` 之后的 `updateBtn` 解禁，
		## 只读那扇连监听都没挂 ⇒ 没有解禁的入口）。选没选到宠都一样。
		按钮.disabled = true if 只读 else not 有宠
	if not 有宠:
		# 原版 destroy()：全 0 条 + 按钮灰 + 说明占位（PetWindow.as:269-327）。
		# ⚠️ 六根条**不跟着藏**（`:272-277` 只 `setData(0,0)` ⇒ 屏上是「0/0」，不是空白），
		#    传 (0,1)/(0,100) 会写成 0/1、0/100 ⇒ 文案与原版不一致。
		_设条(页面, "经验条", 0, 0)
		_设条(页面, "梦幻条", 0, 0)
		for 号 in 4:
			_设条(页面, 槽位高亮[号], 0, 0)
		# 四潜力那几枚标签**不置灰**：原版 `destroy():269-327` 只把四颗按钮置灰（`:291`），
		# 标签是 `addChild(this)` 挂在窗口上的（不属于被清空的 `_attribute`），从不禁用；
		# "点了没反应"由 `_标签被点` 现取现判保证。
		(页面.get_node("总值") as Label).text = "0"
		return

	var 算: Dictionary = 宠物数值.计算(宠物)

	# —— 8 行属性（TextThree：名 90 橙红 / 值 36 橙 / 绿 +N）
	# 每行 tooltip 的关联潜力名是原版逐行硬编码（PetWindow.as:604-611），别从行名里抠：
	# 生命/查克拉→健体潜力、攻→攻击、防→防御、暴击/闪避→灵巧、攻速/移速→品阶
	const 行关联 := ["健体潜力", "健体潜力", "攻击潜力", "防御潜力", "灵巧潜力", "灵巧潜力", "品阶", "品阶"]
	for 号 in 8:
		var 行 := 页面.get_node("属性底板/属性/行_%d" % 号) as Control
		var 项: Dictionary = (算["属性行"] as Array)[号]
		(行.get_node("值") as Label).text = str(项["值"])
		(行.get_node("绿") as Label).text = "+%d" % int(项["梦幻加成"])
		行.tooltip_text = "与通灵兽的%s相关，该值越大则加成越多" % 行关联[号]

	# —— 信息行
	(页面.get_node("名称") as Label).text = String(算["名字"])
	(页面.get_node("名称") as Label).add_theme_color_override("font_color", 算["名字色"])
	(页面.get_node("等级") as Label).text = str(int(宠物.get("level", 0)))   # JSON 数字是 float，直接用会显示 "1.0"
	(页面.get_node("品级") as Label).text = String(算["资质名"])
	(页面.get_node("悟性") as Label).text = str(int(宠物.get("savvy", 0)))
	(页面.get_node("价值") as Label).text = str(算["价值"])
	# 六颗标签与「改名」的监听：原版是**构造期**挂监听（`PetWindow.as:835-838/841-842/917-921`
	# 全是 `addEventListener(MouseEvent.CLICK, onOpenStudyWindow)`），点下去那一刻才取当前宠，
	# 取不到就什么都不发生（`onOpenStudyWindow:646-650`）。
	# ⚠ 只读那一扇**六颗标签与「改名」都不接**：`SimplePetWindow` 建 `TextTip` 时给了
	## `buttonMode = true`（`:433/438`，手型光标照旧）却一条 `addEventListener` 都没挂。
	# ⚠ 也不许在闭包里捕获本轮的 `宠物` 字典：整页每次渲染都整个重建，捕获到的会是**上一次那一只**
	# ⇒ 一律进 `_标签被点` / `_改名被点` 现取。
	const 标签模式 := {"品级标题": 0, "悟性标题": 1, "攻击潜力标题": 2,
			"防御潜力标题": 3, "灵巧潜力标题": 4, "健体潜力标题": 5}
	if not 只读:
		var 改钮 := 页面.get_node_or_null("改名") as BaseButton
		if 改钮 != null:
			for 连 in 改钮.pressed.get_connections():
				改钮.pressed.disconnect(连["callable"])
			改钮.pressed.connect(_改名被点.bind(窗口))
		for 标签 in 标签模式:
			var 钮 := 页面.get_node_or_null(String(标签)) as BaseButton
			if 钮 == null:
				continue
			for 连 in 钮.pressed.get_connections():
				钮.pressed.disconnect(连["callable"])
			钮.pressed.connect(_标签被点.bind(窗口, int(标签模式[标签])))

	# —— 按钮组（updatePetStatus:329-358 + onClickHand）
	var 附身 := 页面.get_node("附身") as Button
	var 出战 := 页面.get_node("出战") as Button
	var 放生 := 页面.get_node("放生") as Button
	if 只读:
		## 原版看别人那一扇：四颗钮**画出来但一颗都没挂监听**
		## （`SimplePetWindow.as:486-495` 只有 addChild，全文件 `addEventListener` 只有 `:143` 列表那条）
		## ⇒ 这里同样**只画不接**：保持可点的外观（原版 MButtonF 自己会响应悬停/按下），
		##    点下去什么都不发生。**不要**为了"看着像坏了"去接成我自己的宠物操作。
		## 文案也**不跟着他的状态换「回收」**：那是 `PetWindow.updatePetStatus` 那一段，只读那扇没有它。
		附身.text = "附身"
		出战.text = "出战"
	else:
		var 态 := 按钮状态(bool(宠物.get("attached", false)), bool(宠物.get("deployed", false)))
		附身.text = String(态["附身文本"])
		出战.text = String(态["出战文本"])
		附身.disabled = bool(态["附身禁用"])
		出战.disabled = bool(态["出战禁用"])
		放生.disabled = bool(态["放生禁用"])
		for 连 in 附身.pressed.get_connections():
			附身.pressed.disconnect(连["callable"])
		for 连 in 出战.pressed.get_connections():
			出战.pressed.disconnect(连["callable"])
		for 连 in 页面.get_node("驯养").pressed.get_connections():
			页面.get_node("驯养").pressed.disconnect(连["callable"])
		for 连 in 放生.pressed.get_connections():
			放生.pressed.disconnect(连["callable"])
		附身.pressed.connect(func(): 窗口._attach_pet(String(宠物.get("id", ""))))
		出战.pressed.connect(func(): 窗口._toggle_pet(String(宠物.get("id", "")), not bool(宠物.get("deployed", false))))
		# 驯养 = 纯刷新，但原版三颗钮都挂了 `isDelay` 1000ms（`PetWindow.as:897`）
		页面.get_node("驯养").pressed.connect(func() -> void:
			if 窗口._宠物按钮节流("驯养"):
				窗口._render_page())
		放生.pressed.connect(func(): 窗口._release_pet(String(宠物.get("id", ""))))

	# —— 悬停提示（原版每个 TextTip 都带第 2 参；按钮那 4 条是 MButtonF 的 MToolTipText）
	(页面.get_node("等级标题") as Label).tooltip_text = 提示["等级"]
	(页面.get_node("等级") as Label).tooltip_text = 提示["等级"]
	# ⚠️ 品级/悟性/四潜力这几个标题是 **LinkButton**（原版 TextTip 带下划线且可点），
	#    强转 `as Label` 会得到 null、赋值静默失败 —— 统一用 `as Control`。
	(页面.get_node("悟性标题") as Control).tooltip_text = 提示["悟性"]
	(页面.get_node("价值标题") as Label).tooltip_text = 提示["价值"]
	(页面.get_node("经验标题") as Label).tooltip_text = 提示["经验"]
	for 号 in 4:
		var 潜力名: String = ["攻击", "防御", "灵巧", "健体"][号]
		(页面.get_node("%s潜力标题" % 潜力名) as LinkButton).tooltip_text = 提示["%s潜力" % 潜力名]
	for 按钮名 in ["附身", "驯养", "出战", "放生"]:
		(页面.get_node(按钮名) as Button).tooltip_text = 提示[按钮名]
	# 梦幻度条：原版 `PETWINDOW_MENG_HUAN_DU_TIP` 里 Z/W/Q/J/K 五处现场替换
	# （`updatePetProps:593-598`），我们照同样的五个数填。
	var 分量: Dictionary = 算["梦幻分量"]
	(页面.get_node("梦幻条") as Control).tooltip_text = (
		"总梦幻度越高，则通灵兽为你加成的额外附加属性就会越高，最大可翻倍加成\n"
		+ "总梦幻度:%d%% \n　　总梦幻度=悟性梦幻度+四项潜力梦幻度+技能梦幻度+梦幻灵珠梦幻度\n" % int(算["梦幻度"])
		+ "通灵兽悟性梦幻度:%d%% \n　　（当前悟性/悟性最大值）/10*100%%\n" % int(分量["wu_xing"])
		+ "四项潜力梦幻度:%d%% \n　　（4项潜力当前值之和/4项潜力最大值之和）/3*100%%\n" % int(分量["qian_li"])
		+ "通灵兽技能梦幻度:%d%% \n　　（技能数量/最大技能数量）/10*100%%\n" % int(分量["skill"])
		+ "梦幻灵珠提升梦幻度:%d%% \n　　使用梦幻灵珠数量/100*100%%" % int(分量["ling_zhu"])
	)

	# —— 六条进度（经验 + 四潜力 W=168、梦幻 W=114；`PetWindow.as:826`、`:932`，条几何见 `_设条`）
	_设条(页面, "经验条", int(宠物.get("experience", 0)), int(算["经验上限"]))
	for 号 in 4:
		var 条: Dictionary = (算["潜力条"] as Array)[号]
		_设条(页面, 槽位高亮[号], int(条["实"]), int(条["总"]))
	_设条(页面, "梦幻条", int(算["梦幻度"]), 100)   # totalMengHuanDu 恒 100（PetAddValue:31）
	(页面.get_node("总值") as Label).text = str(算["潜力总值"])

	# —— 5 装备格（原版 `SimpleItemCell` 三件事：拖进来穿上、点一下卸下、悬停出提示框）
	var 装备列表: Array = 宠物.get("equipment", [])
	for 槽位 in 装备部位:
		var 格 := 页面.get_node("装备槽_%d" % 槽位) as Button
		var 已装: Dictionary = {}
		for 装 in 装备列表:
			if int(装.get("equipment_slot", 装.get("slot_index", 0))) == 槽位:
				已装 = 装
		var 图标 := 格.get_node("图标") as TextureRect
		var 槽名 := 格.get_node("槽名") as Label
		# 拖放（原版 SimpleItemCell.dropItemFun = petPutOnEquip）：这一格是背包物品的落点。
		# ⚠️ 反复 connect 会刷一屏告警，每次渲染前先断开（§API 陷阱 三）。
		if 只读:
			格.set("格子归属", "")	# 空归属 = `_can_drop_data` 直接挡掉（交易窗同一口径）：他的格不是落点
		elif 格.has_signal("拖放"):
			格.set("格子归属", "宠物装备")
			格.set("槽位号", 槽位)   # 部位判据走公共表 装备部位.gd（宠物一..五 = 1..5）
			var 拖放信号: Signal = 格.get("拖放")
			for 连接 in 拖放信号.get_connections():
				拖放信号.disconnect(连接["callable"])
			拖放信号.connect(_处理装备格拖放.bind(窗口, String(宠物.get("id", ""))))
		# 点击卸下同理**先断再连**：原来这里只清了 `拖放`，`pressed` 每次渲染叠一条，
		# 于是看几页宠物再点一下＝发 N 发 16 号包 + 一屏 already-connected 告警。
		for 连接 in 格.pressed.get_connections():
			格.pressed.disconnect(连接["callable"])
		if 已装.is_empty():
			图标.texture = null
			槽名.visible = true
			格.disabled = true
		else:
			图标.texture = 数据.item_icon(int(已装.get("id", 已装.get("item_id", 0))))
			槽名.visible = false
			格.disabled = false
			if not 只读:
				格.pressed.connect(func() -> void: 窗口._take_off_pet_equipment(String(宠物.get("id", "")), 槽位))
		# —— 悬停提示框。原版在 `SimpleItemCell.setItemData` 末尾给每一格挂
		#    `MToolTipItem.createToolTip(stage, this, itemData)`（`SimpleItemCell.as:220`），
		#    宠物五槽与背包格**共用同一套提示框**；这里以前只给原生 `tooltip_text`
		#    （一行物品名），所以用户看到的是「鼠标放上去没有装备提示框」。
		#    helper 会自己清掉原生 tooltip_text 并按部位分发（宠物件 → 装备提示框）。
		# ⚠️ 第二个参数必须是**页面根**（提示框节点挂在它下面、且不能被父级裁掉），
		#    与 `人物窗口` 那条同口径。
		格子提示框.接线(窗口, 页面, 格, 已装)

	# —— 8 技能格（SkillCellF：图标 + tooltip；无点击行为，原版如此）
	var 技能: Array = 宠物.get("skills", [])
	for 号 in 8:
		var 格 := 页面.get_node("技能栏/技能格_%d" % 号) as Button
		var 图标 := 格.get_node("图标") as TextureRect
		图标.texture = null
		格.tooltip_text = ""
		if 号 < 技能.size():
			var 技: Dictionary = 技能[号]
			var 技号 := int(技.get("id", 0))
			var 记录 := 数据.pet_skill(技号)
			图标.texture = _技能图标(技号)
			格.tooltip_text = "%s Lv.%d\n%s" % [String(记录.get("name", "宠物技能 %d" % 技号)), int(技.get("level", 0)), String(记录.get("desc", ""))]

	# —— 模型观赏（PetSprite stand0，尾兽 0.5 倍，PetWindow.as:1045-1072）
	var 观赏 := 页面.get_node("模型观赏") as Control
	for 旧 in 观赏.get_children():
		观赏.remove_child(旧)
		旧.queue_free()
	var 精灵 := preload("res://脚本/角色/原始动画精灵.gd").new()
	var 形象号 := int(宠物.get("face", 0))
	if 形象号 <= 0:
		形象号 = int(宠物.get("item_id", 0))
	if 精灵.configure("pet", str(形象号).pad_zeros(8), "stand"):
		观赏.add_child(精灵)
		if 宠物数值.是尾兽(int(宠物.get("item_id", 0))):
			精灵.scale = Vector2(0.5, 0.5)

	# —— 右侧「通灵驯养」窗一起出（原版 `PetWindow.selectedPet:720-727` → `createStudyWindow`）。
	#    `call_deferred`：`_render_page()` 正在清空/重建 `_content`，此刻开另一扇窗会把
	#    本页的节点树搅乱（同一类坑见 `_refresh_current` 的 call_deferred）。
	if not 只读:
		窗口.call_deferred("_随选中开驯养窗")


## 只读那一扇的"当前选中的是哪一只"：在**他的**清单里按 `unique_id` 找。
## 与 `功能窗口._pet_by_id` 同语义，但那份查的是 `窗口._session.pets`（我自己的镜像）——
## 拿它查他的宠物号要么查不到（画成空态）、要么撞号查到**我**那只（把他的窗画成我的数）。
## ⚠ key 用 `unique_id` 而不是 `_parse_pet_fields` 那个 `id`（= item_id 补零）：
##   原版往行数据里塞的就是 `"id":_loc3_.uniqueId`（`updateShouLanList:596`）。用 item_id 的话，
##   他只要有**两隻同种**宠物就两行同时亮、点第二行画的还是第一只。
static func 查宠(清单: Array, 号: String) -> Dictionary:
	for 宠 in 清单:
		if str((宠 as Dictionary).get("unique_id", "")) == 号:
			return 宠 as Dictionary
	return {}


## 列表行的 key。⚠ **别顺手把两扇统一成同一个**：自己那扇沿用移植既有的 `id`（= item_id 补零），
## 而 `_pet_by_id`、改名、交易带宠那些读取者都在用 `id`，要改得连着那几道门一起过。
## 只读那扇按原版用 `unique_id`（`updateShouLanList:596` 塞进行数据的就是 `"id":_loc3_.uniqueId`）
## ⇒ 他有两隻**同种**宠物时不会两行同时亮、点第二行也不会画成第一只。
static func 行号(宠物: Dictionary, 只读: bool) -> String:
	## ⚠ 一律 `str()`：解码出来的 `unique_id` 是 **int**，而 GDScript 没有 `String(int)` 这个构造器
	## （写了就是运行期 `Nonexistent 'String' constructor`，`--check-only` 抓不到）。
	return str(宠物.get("unique_id", "")) if 只读 else str(宠物.get("id", ""))


## 六颗标签被点（品级/悟性/四潜力）。原版 `PetWindow.as:643-691 onOpenStudyWindow`：
## **点击这一刻**才 `getPetData(currentPet)`，拿不到就直接 `return`（`:646-650`，什么都不发生）；
## 拿到了就开右侧「通灵驯养」窗的 `TYPE_STRONG` 页，`模式` 决定 `PetStrongTab.setType` 的子类型
## （`PetStrongTab.as:40-50`：TYPE_APT 0 / SAV 1 / APA 2 / APD 3 / APDEX 4 / APSTR 5）。
static func _标签被点(窗口, 模式: int) -> void:
	var 现: Dictionary = 窗口._pet_by_id(窗口._selected_pet_id)
	if 现.is_empty():
		return
	窗口._打开驯养窗(String(现.get("id", "")), 1, 模式)


## 「改名」标签：与六颗标签**同一个处理器**（原版 `_labChangeName` 也 addEventListener 到
## `onOpenStudyWindow`，`:837-838`），走的是 `CN.PETWINDOW_CHANGE_NAME` 那一档 ⇒ 输入型确认弹。
## 同样要先有当前宠（`:646-650`），没选到就什么都不发生。
static func _改名被点(窗口) -> void:
	var 现: Dictionary = 窗口._pet_by_id(窗口._selected_pet_id)
	if 现.is_empty():
		return
	窗口._rename_pet_request(String(现.get("name", "")))


## 只读那一扇点行：只换**他那一扇的**游标，然后重画（原版 `SimplePetWindow.as:143` 全文唯一
## 一条监听就是列表 ITEM_CLICK ⇒ 可以换显示，但一条请求都不许发）。
static func _只读选宠(窗口, 号: String) -> void:
	窗口.set("_他人宠物选中号", 号)
	窗口.call("_render_page")


## 宠物行。返回「是否当前选中那只」—— 悬停黄框的收起规则要用（见 `_接悬停`）。
static func _填宠物行(窗口, 条目: Button, 宠物: Dictionary, 选中号: String = "", 只读: bool = false) -> bool:
	var 名字 := 条目.get_node("名字") as Label
	var 等级 := 条目.get_node("等级") as Label
	名字.text = 宠物数值.显示名(宠物)
	名字.add_theme_color_override("font_color", 宠物数值.品质色_of(
		int(宠物.get("aptitude", 1)), 宠物数值.是尾兽(int(宠物.get("item_id", 0)))))
	# JSON 里的等级可能是 float，直接 str() 会显示 "1.0"（主窗那一份已经踩过一次）
	等级.text = str(int(宠物.get("level", 0)))
	var 状态 := 条目.get_node("状态") as TextureRect
	if bool(宠物.get("attached", false)):
		状态.visible = true
		状态.texture = load(状态附)
	elif bool(宠物.get("deployed", false)):
		状态.visible = true
		状态.texture = load(状态战斗)
	## 这一句**不能省**：`宠物条目.tscn` 里那格默认就是 `visible = true` ⇒ 只有"亮着的那一档"被
	## 显式点亮、其余行**不管**的话，同一批节点被重画时上一轮亮着的会一直亮着。
	else:
		状态.visible = false
	var 号 := 行号(宠物, 只读)
	(条目.get_node("选中条") as Control).visible = 号 == 选中号
	## ⚠ **先断开再接**：`渲染进` 被同一批节点反复调用时，不先断开就每轮多挂一条 `pressed`
	## ⇒ 点一次渲染 N 次。自己那扇走 `_render_page` 整页重建 ⇒ 看不出这一条。
	for 连 in 条目.pressed.get_connections():
		条目.pressed.disconnect(连["callable"])
	条目.pressed.connect(_只读选宠.bind(窗口, 号) if 只读 else 窗口._select_pet.bind(号))
	return 号 == 选中号


## 行悬停：亮/收 `选中条`（原版 `PetItemRenderer` 的 `overHandler` / `outHandler`）。
##
## ⚠️ 三条都是真值（§15A）：
##   ① 悬停**无条件**点亮（选中与不选中都亮）；
##   ② 移出时**只有未选中的行**才收起 —— 选中的那只移出后黄框留着；
##   ③ 靠的是 `mouse_entered/mouse_exited`，所以行**必须是可接收鼠标的**（disabled 不行）。
static func _接悬停(条目: Button, 已选: bool) -> void:
	var 条 := 条目.get_node_or_null("选中条") as Control
	if 条 == null:
		return
	条.visible = 已选
	## 同 `pressed`：`渲染进` 会被同一批节点反复调，不先断就每轮多挂一对。
	for 连 in 条目.mouse_entered.get_connections():
		条目.mouse_entered.disconnect(连["callable"])
	for 连 in 条目.mouse_exited.get_connections():
		条目.mouse_exited.disconnect(连["callable"])
	条目.mouse_entered.connect(func() -> void: 条.visible = true)
	条目.mouse_exited.connect(func() -> void: 条.visible = 已选)


## 空闲兽栏行：原版 id=0 点了不动（`onListHand:374` 直接 return）→
## **不能置 `disabled=true`**，否则 Control 不吃鼠标、悬停黄框永远不亮（§15A）。
## 挡点击靠"不连 pressed"。
static func _填占位行(条目: Button, 文本: String, 颜色: Color) -> void:
	(条目.get_node("名字") as Label).text = 文本
	(条目.get_node("名字") as Label).add_theme_color_override("font_color", 颜色)
	(条目.get_node("等级") as Label).text = ""
	条目.disabled = false
	条目.tooltip_text = ""


## 打开「格数扩展」窗的**兽栏那条**（`EnlargeWindow` 归属号 2）。
##   需要数量 = `max(1, 当前容量 − 3)` —— 两边同源：原版 `PetWindow.as:366` 传 `curSoltNum − 3`，
##   服务端 `_extend_pet_capacity:26221` 收的也是 `max(1, current − 3)`。
##   密卷走**背包那一条** `Etc.BeibaoKuozhan`（服务端 `capacity_expansion_config(storage=False)`
##   读的就是它 ⇒ 别再往表里加一行假的「兽栏」，见 `扩容需求.密卷id` 的头注）。
##   兽栏那条的询问文案**没有** `%1` 占位 ⇒ 页号传 0（`EnlargeWindow` 只对背包/仓库读 `_row`）。
static func _开兽栏扩容窗(窗口, 页面: Control) -> void:
	var 窗 := 页面.get_node_or_null("扩容窗口") as Control
	if 窗 == null:
		return
	var 密卷id := 扩容需求.密卷id("背包")
	var 需要数 := maxi(1, int(窗口._session.pet_capacity) - 3)
	窗.call("打开", "兽栏", 0, 需要数, 密卷id, 扩容需求.拥有数(窗口._session, 密卷id))
	# 物品格 = 原版 `ItemWindowCell`（`EnlargeWindow.as:239`，悬停 `:309-314` 挂 MToolTipItem）。
	# 宠物页场景只烘了 `装备提示框`（五槽用），密卷是道具 ⇒ 先把 `物品提示框` 补挂上。
	窗口._给页挂提示框(页面)
	窗口._接打造提示(页面, 窗.get_node_or_null("物品格") as Control,
			int(密卷id), 扩容需求.拥有数(窗口._session, 密卷id))


## 扩展兽栏行（红字）：原版点开 `EnlargeWindow`（归属号 2 = 兽栏），**不是空壳**。
## ⚠️ 这行的 `pressed` 接线在 `渲染()` 里（同一次渲染内 `_开兽栏扩容窗`）——写在上面的
## `渲染()` 尾巴上，别搬到这里（静态函数拿不到页面上的「扩容窗口」节点引用）。
static func _填扩展行(扩展: Button) -> void:
	(扩展.get_node("名字") as Label).text = "扩展兽栏"
	(扩展.get_node("名字") as Label).add_theme_color_override("font_color", Color("#ff0000"))
	(扩展.get_node("等级") as Label).text = ""
	扩展.disabled = false


## `MBarExpF`（tag167）按真值 §10 重建后的驱动：`底 / 裁剪(clip) / 裁剪/填充 / 值`。
## 进度**不是压扁**：`set width` 只拉 `barBg`（原生 122×11）到 W，`bar` 跟着拉到 W，
## `setData:149` 让 `bar.x = 静止位 − int(bar.宽·(1−r))` ⇒ **整条往左滑、mask 不动**
## （看到的是条芯的左半截原尺寸）；`:170` 是 0.5s 补间。静止位 = `barBg.x + (W − W)/2`
## = 轨道左沿，`裁剪` 比轨道缩 3px ⇒ 满条时 `填充.position.x = −3`、空条 `= −3 − W`。
## 同一条链的另一份实现见 `通灵驯养窗口._设条`（进阶页祝福条），六根条与它共用几何口径。
static func _设条(页面: Control, 条名: String, 数值: int, 最大值: int) -> void:
	var 条 := 页面.get_node(条名) as Control
	var 填充 := 条.get_node("裁剪/填充") as TextureRect
	var 值 := 条.get_node("值") as Label
	# 终位走件（同一条口径：比例 → `静止位 − int(槽宽×(1−比例))` → 0.5s 补间 + 同数据早退 + 换数据杀旧补间）。
	# 以前这里每次渲染都 `create_tween()` ⇒ **两支抢同一个 x**（重绘一次多一支，条来回抖）。
	# ⚠ `上限零当满 = false` 是**有意的偏离**：原版 `MBar` 在 `setData(0,0)` 时画**满条**
	#   （`MBar.as:19` 的 `_isShowBar` 缺省 true、`:143` 那支 `param2 > 0 ? … : 1`），
	#   而"没选宠物"那一档 `PetWindow.as:269-277` 正是六根 `setData(0,0)` ⇒ 原版会把六根画满。
	#   实机对照图没拍到那一档，本工程维持**空条**（画满会被当成"0/0 却满格"的新报修）。
	进度条补间.补间(填充, "position:x", 进度条补间.滑条终位(条.size.x,
		进度条补间.比例(float(数值), float(最大值), false), -3.0), [数值, 最大值])
	值.text = "%d/%d" % [数值, 最大值]


## 拖拽穿宠物装备（原版 `PetWindow.petPutOnEquip` → `API.petHandler.petPutOnEquip`）。
## 走 `游戏会话.equip_pet_item_by_id`：按拖来的**那件** id 穿，服务端再复核部位/等级。
## 与人物面板同一套口径（`人物窗口._处理装备格拖放`）：只认背包来的、只认自己对得上的部位。
static func _处理装备格拖放(来源格: Button, 目标格: Button, 物品id: String, 窗口, 宠物id: String) -> void:
	if str(来源格.get("格子归属")) != "背包" or str(目标格.get("格子归属")) != "宠物装备":
		return
	var 部位 := int(目标格.get("槽位号"))
	if 部位 < 1 or 部位 > 5:
		return
	窗口._session.equip_pet_item_by_id(宠物id, 部位, 物品id)


static func _技能图标(技号: int) -> Texture2D:
	var 路径 := 数据.skill_icon_path({"icon_class": "Skill_PetSkill_%d_icon" % 技号})
	if 路径.is_empty() or not ResourceLoader.exists(路径):
		return null
	return load(路径) as Texture2D
