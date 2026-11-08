extends RefCounted

const 人物场景 := preload("res://场景/界面/窗口/人物/人物窗口.tscn")
## 「看别人」那一扇的**宠物页**没有自己的场景：原版 `SimplePetWindow` 与自己那扇 `PetWindow`
## 是两套实现、但元素同一批 ⇒ 这里把 `宠物窗口.tscn` 那一页实例化进来，交给
## `宠物窗口.渲染进(窗口, 页面, 只读档)` 画。只读差异（摆位表、四颗永远灰、
## 一条请求都不接）全在那份里，本文件只管把**他的**清单与上限解出来喂过去。
## ⚠ 别的只读子页都是"同一份 .tscn + `设只读()`"，宠物这一页是"同一份填法 + 换数据源"，
##   别把它当成能并进 `初始化XX页` 那一族。
const 宠物页 := preload("res://脚本/界面/窗口/宠物窗口.gd")
const 装备部位表 := preload("res://脚本/单例/装备部位.gd")
## 悬停出原版提示框（`MToolTipItem` 挂 MOUSE_OVER）——与背包/仓库**同一份**接线。
const 格子提示框 := preload("res://脚本/界面/组件/格子提示框.gd")
const 装备提示框 := preload("res://脚本/界面/组件/装备提示框.gd")
const 物品菜单组件 := preload("res://脚本/界面/组件/物品菜单.gd")
const 灵器外观选择窗 := preload("res://脚本/界面/窗口/灵器外观选择窗.gd")
const 套装提示 := preload("res://脚本/单例/套装提示.gd")
## 六根条的 0.5s 补间走这一道口子（`MBar.setData:170`，真值 `真值/窗口/进度条补间.md`）。
const 进度条补间 := preload("res://脚本/单例/进度条补间.gd")
## 原版 `StyleUtil.getGrayFilter()` 的逐字复刻（系数 0.3086/0.6094/0.082，见着色器头注释）。
## 柔拳未突破的境界钮要用它 —— 那位开发者的 `去饱和.gdshader` 是 Rec.601，灰出来的亮度不同。
const 禁用灰度着色器 := preload("res://脚本/界面/组件/禁用灰度.gdshader")
const 角色造型 := preload("res://脚本/角色/角色造型.gd")
const 八门文案 := preload("res://脚本/界面/窗口/八门文案.gd")
const 结印文案 := preload("res://脚本/界面/窗口/结印文案.gd")
const 升阶文案 := preload("res://脚本/界面/窗口/升阶文案.gd")
const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
## 信息区/两条进度框的悬停提示 = 原版 `MToolTipText`（`CharPane.as:197-216 setToolTip()`）。
## 与意志背包窗**同一个组件**，只是宿主换成 Label ⇒ 见下面 `_挂文字提示`。
const 文字提示场景 := preload("res://场景/界面/组件/文字提示框.tscn")
## 轮回技能格的悬停提示 = 原版 `MToolTipLunHuiYanSkill`（宽 236 + 居中大标题 + 正文），
## 版式与 Buff 那份 `MToolTipTextWithTitle` 同族 ⇒ 复用 `标题文字提示框.tscn`（标题色传 #ffff00）。
const 标题提示场景 := preload("res://场景/界面/组件/标题文字提示框.tscn")
## 「意志格」那格的提示与意志背包窗「意志值框」**同一份串**（都出自
## `YiZhiManager.getYiZhiPropToopTioInfo:392-405`）⇒ 直接调组件里的静态构建，不抄第二遍。
const 意志提示框 := preload("res://脚本/界面/组件/意志提示框.gd")
const 人物文案路径 := "res://数据/界面/人物_文案.json"
const 职业表 := preload("res://脚本/单例/职业.gd")
const 装备打造表 := preload("res://脚本/界面/装备打造表.gd")
const 游戏数据表 := preload("res://脚本/单例/游戏数据.gd")
## 虫槽落点件（运行期 `set_script` 挂 `寄坏槽一..四`，场景不许手改 —— 同族 `勾玉放入格`）。
const 昆虫放入格 := preload("res://脚本/界面/组件/昆虫放入格.gd")
## 强化弹窗「放置格」的落点件（报修①：拖背包虫进格子选强化目标，同族上一条）。
const 昆虫强化落格 := preload("res://脚本/界面/组件/昆虫强化落格.gd")
## 手里剑七阶数值表（解自 GameData 的 `Etc.AnQi`）——「开始突破瓶颈」那四道客户端预检读的就是
## 这张表：原版比的是 `_configure.stageUp`，而 `_configure = getShouLiJianConfigure(stage + 1)`
## （`ThroughShouLiJianWindow.as:134` 与 `:190`），与这里的 `取阶(阶 + 1)["up"]` 同一份数。
const 手里剑数据 := preload("res://素材/界面/原版窗口/人物/手里剑/脚本/手里剑数据.gd")
## 「其他属性」浮板**整块烘在 `场景/界面/窗口/人物/人物窗口.tscn`**（`其他属性面板` + 底板/顶图/标题 + 九行题值），
## 这里只填数与管显隐 —— 工程有条架构闸钉着「页面脚本不许运行时创建固定控件」（`功能入口回归测试`）。
## 顶图为什么能直接复用「战斗属性」那张烘焙图：原版这几条深色横带烘在
## `CharSecondAttributePaneF` 的时间轴上，而 `combatExtraAttrPane` 就是**同一个符号的第二个实例**
## （`CharPane.as:176`）⇒ 带子一模一样；`CharInfoCellF` 本身是透明的（实测 `2.2.3/…/cache/ui_symbols/
## DefineSprite_945_CharInfoCellF_CharInfoCellF/1.png` 里只有一个 Label）。

const 主分页名称 := ["角色", "秘术", "血继界限"]
const 子分页组 := [
	["人物", "手里剑", "结印"],
	["八门", "柔拳", "寄坏之术"],
	["写轮眼", "轮回六道"],
]
## ── 「看别人」那一扇的子分页表（原版 `CharOtherWindow2.as:213-268 createButtons()`）──────
## 每项 `[页名, 等级闸]`。⚠ **两套语义与自己那扇不同**：原版对**别人**是
## 「那个人不够级就根本不建这一枚页签」（`:222`/`:226`/`:236`/`:246`），
## 而自己那扇是"建出来置灰 + 提示 XX 级开放"（上面 `页面开放等级` 那一套）。
## 闸值逐条现查：手里剑 `JingMaiSource.as:30`=15、结印 `JieYinManager.as:19`=70、
## 昆虫 `KunChongManager.as:14`=40、轮眼 `LunHuiYanManager.as:15`=65；
## 两个开关 `SwitchController.as:18,20` 都是 false ⇒ 写轮眼/手里剑不因开关被摘。
## 主分页只有 3 枚（第 4 枚「藏品图鉴」用户 10-16 令**取消，不做**）。
## 秘术那一排**没有八门** —— 八门只在自己那扇出现（原版 `case 1` 只 push 柔拳/昆虫）。
## ⚠ 「人物」这一排的**宠物**那一枚原版是**恒有**的（`CharOtherWindow2.as:222-224`，
##   没有等级闸、没有开关），顺序也钉死在第二枚：人物 → 宠物 → 手里剑 → 结印。
##   它的只读页 = `SimplePetWindow`（数据面 = 段 32 宠物串 + 段 14 上限，
##   解法见 `他人宠物()`，摆位与"一颗都不接"见 `宠物窗口.渲染进()`）。
##   已落地的只读页：手里剑（段 34..37）、结印（段 44/45，10-16）、
##   柔拳（段 39/40）、寄坏之术（段 29 里的 −200..−203 四格，10-16）、
##   写轮眼（段 46/47）、轮回六道（段 41/42；**段 43 技能服务端写死 `-`** ⇒ 他的技能格是空的，
##   这条不是客户端漏接，见 `后端连接.gd:3483` 的注）。
const 他人子分页组 := [
	[["人物", 0], ["宠物", 0], ["手里剑", 15], ["结印", 70]],
	[["柔拳", 0], ["寄坏之术", 40]],
	[["写轮眼", 0], ["轮回六道", 65]],
]

## 按**被看那个人**的等级筛出这一排该建的页签名。
static func 他人子分页表(主分页序号: int, 等级: int) -> Array:
	var 组: Array = 他人子分页组[clampi(主分页序号, 0, 他人子分页组.size() - 1)]
	var 出: Array = []
	for 项 in 组:
		if 等级 >= int((项 as Array)[1]):
			出.append(String((项 as Array)[0]))
	return 出

const 页面开放等级 := {"手里剑": 15, "寄坏之术": 40, "轮回六道": 65, "结印": 70}
# 原版分区标题色：AS3 `CharPane.init` 传的 `16565145` = RGB(252,195,153)，
# 与原版基线逐像素实测一致（字号 12 时墨迹高 12px）。
const 信息标题色 := Color("#fcc399")
## 「人物」页的**数值**字号（用户 2026-10-25 喜欢背包数量 14px 的效果，要求这里也试试）。
## 只放大**值**，标题/装备名/按钮字仍 12；14 落在宋体点阵档 12~17 内，字体又是
## 单色光栅（§3.282）⇒ 数字/字母是实心 255，不会发糊。原版真值仍是 12，这是有意偏离。
const 数值字号 := 14
# 人物面板上的装备格：**位置(int) → 场景节点名**。
# 依据 2.2.3 `EquipPane.as:218-242` 的建格顺序与 `EquipmentPosition`：
#   cell0..cell11 = EquipA..L（武器…斗篷）、cell12/13 = EquipSZ/S1（变身/勾玉）、
#   huizhangCell = 徽章、createShenQiCell → 神器剑/镜、createLingQiCell → 灵器、
#   createRenJuCell → 忍具、createHunjieCell → 羁绊。
# 节点名与显示名分开，是因为 `ShenQiCell` 里 `equipNameText.visible = false` ——
# 原版**不给这两格画名字**，所以它们只有节点名、没有标签节点。
# ⚠️ 上一版这里写的是 18 项中文名数组，其中「项鍊」「忍具」两名与 `.tscn` 节点名绑死，
#    且缺神器两格。位置才是身份、名字只是显示层，这个方向已经反了，故改成现在这样。
const 装备格节点 := {
	装备部位表.武器: "武器格", 装备部位表.手套: "手套格", 装备部位表.衣服: "衣服格",
	装备部位表.护额: "护额格", 装备部位表.护腰: "护腰格", 装备部位表.忍鞋: "忍鞋格",
	装备部位表.斗笠: "斗笠格", 装备部位表.项链: "项链格", 装备部位表.戒指: "戒指格",
	装备部位表.手环: "手环格", 装备部位表.忍包: "忍包格", 装备部位表.斗篷: "斗篷格",
	装备部位表.变身: "变身格", 装备部位表.勾玉: "勾玉格",
	# `神器镜` 这一格在场景里的节点名是 `真神器`（画面上写的也是"真·神器"）——
	# 同 `unique_id=1048009078`，就是原来那格被改了名。表里必须跟场景一致，
	# 否则 `get_node` 返回 null，下面 `装备格.visible = ...` 会炸成一片空引用。
	装备部位表.神器剑: "神器剑格", 装备部位表.神器镜: "真神器",
	装备部位表.灵器: "灵器格", 装备部位表.忍具: "忍具格",
	装备部位表.徽章: "徽章格", 装备部位表.羁绊: "羁绊格",
}
# 原版 `EquipPane.removeShenqiCellData` 会把神器两格 `visible = false`（没装备就不显形，
# 空格子都不留）；用户 2026-09-21 确认按这个来。其余 18 格恒可见。
const 无装备即隐藏 := [装备部位表.神器剑, 装备部位表.神器镜]
const 八门名称 := ["开门", "休门", "生门", "伤门", "杜门", "景门", "惊门", "死门"]
const 轮回六道阶段 := ["人间道", "饿鬼道", "修罗道", "天道", "畜生道", "地狱道", "轮回眼", "外道"]

const 八门穴位图 := {
	"开门": "res://素材/界面/原版窗口/人物/八门/开门穴位图.png",
	"休门": "res://素材/界面/原版窗口/人物/八门/休门穴位图.png",
	"生门": "res://素材/界面/原版窗口/人物/八门/生门穴位图.png",
	"伤门": "res://素材/界面/原版窗口/人物/八门/伤门穴位图.png",
	"杜门": "res://素材/界面/原版窗口/人物/八门/杜门穴位图.png",
	"景门": "res://素材/界面/原版窗口/人物/八门/景门穴位图.png",
	"惊门": "res://素材/界面/原版窗口/人物/八门/惊门穴位图.png",
	"死门": "res://素材/界面/原版窗口/人物/八门/死门穴位图.png",
}

const 八门说明 := {
	"开门": ["开门强化生命，五行属金，乾宫门。", "开门喻万物开始之意。", "生命 +154"],
	"休门": ["休门强化生命，五行属水，坎宫门。", "休门乃修养生息之地。", "生命 +128"],
	"生门": ["生门强化防御，五行属土，艮宫门。", "生门为万物复苏之始。", "防御 +38"],
	"伤门": ["伤门强化攻击，五行属木，震宫门。", "伤门属凶门，动则易伤。", "攻击 +38"],
	"杜门": ["杜门强化闪避，五行属木，巽宫门。", "杜门为藏形避难之方。", "闪避 +38"],
	"景门": ["景门强化攻击，五行属火，离宫门。", "景门当日升中天之时。", "攻击 +38"],
	"惊门": ["惊门强化查克拉，五行属金，兑宫门。", "惊门行寒气肃杀之应。", "查克拉 +51"],
	"死门": ["死门强化暴击，五行属土，坤宫门。", "死门主刑戮征战之宜。", "暴击 +13"],
}

## 写轮眼阶段表 —— **12 个**，逐字照抄**他那一版场景**的节点名
## （`写轮眼页.tscn` 的 `滚动按钮列表/阶段列表` 子节点）。
## ⚠️ 旧的表只有 8 个（到「永恒万花筒」为止），他新增了
## 「六勾玉轮回眼 / 轮回写轮眼 / 净眼」三个阶段 —— 别再照旧表写。
## 他的脚本 `写轮眼切换_修正版.gd` 就是**按节点名**把按钮、立绘、右侧数值面板三组配起来的，
## 所以这张表的次序 = 按钮次序 = 服务端 `stage` 的次序。
const 写轮眼阶段 := [
	"单勾玉", "双勾玉", "三勾玉", "月读", "天照", "须佐之男", "伊邪那歧", "永恒万花筒",
	"轮回眼", "六勾玉轮回眼", "轮回写轮眼", "净眼",
]
const 柔拳角色图 := {
	1: "res://素材/界面/原版窗口/人物/柔拳/角色/柔拳角色阶段1.png",
	2: "res://素材/界面/原版窗口/人物/柔拳/角色/柔拳角色阶段2.png",
	3: "res://素材/界面/原版窗口/人物/柔拳/角色/柔拳角色阶段3.png",
	5: "res://素材/界面/原版窗口/人物/柔拳/角色/柔拳角色阶段5.png",
	7: "res://素材/界面/原版窗口/人物/柔拳/角色/柔拳角色阶段7.png",
	8: "res://素材/界面/原版窗口/人物/柔拳/角色/柔拳角色阶段8.png",
}

static func 渲染(窗口, 别人档: Dictionary = {}) -> void:
	var 会话 = 窗口._session
	# 「看别人」= 原版 `CharOtherWindow2`：**同一份页面**，只把数据源换成 `58:4` 解出来的档
	# （真值 `真值/窗口/人物属性_看别人.md`）。传空档 = 看自己，走原来的路。
	# ⚠ 判「是不是别人的那扇」用**页名**、不用"档空不空"（第 13 条：同一扇窗两种形态，
	#   用页名分比用状态位稳）。理由很实在：布局体检与异常路径下**档就是空的**，
	#   那时也必须把**这扇窗的真版式**建出来，否则量到的是一句提示、判「空白」（10-15 实测）。
	#   两种开窗口径都要认：多窗口走 `_固定页`，老的换页用法走 `_current_page`。
	# ⚠ 变量名别叫 `页名` —— 本函数后面本来就有一个 `页名`（子分页名），撞了直接 parse error（门当场点名）。
	# ⚠ 取法必须是 `str(X.get("键"))` —— 全工程守卫禁无默认值的 `String(X.get("键"))`
	#   （`点角色不崩回归测试` 逐行扫，10-15 当场点名）。
	var 本窗页名 := str(窗口.get("_固定页"))
	if 本窗页名.is_empty():
		本窗页名 = str(窗口.get("_current_page"))
	var 是别人 := 本窗页名 == "人物属性看别人"
	var 属性: Dictionary = 别人档转属性(别人档) if 是别人 else 会话.player_stats
	# 装备格的**数据源**：原版 `CharOtherWindow2.as:200-205` 把 `otherEquipData/otherShenqiData/
	# otherHunjieData/otherLingQiData` 喂给 equipPane，与自己那扇读的 `API.dataCenter.equippedItems`
	# 是两套数；本工程把它们按 `装备位置` 合成一张 dict（`后端连接._他人装备表`）。
	# ⚠ 以前这里**没有分支** ⇒ 他那扇画的是**我的**装备（10-22 用户报修「看别人装备格缺角标」，
	#   逮到的其实是更大的：整格数据源串窗 + 点他的格子会卸下**我的**件）。
	var 装备源: Dictionary = (别人档.get("装备", {}) as Dictionary) if 是别人 else 会话.equipped_items
	var 页面 := 人物场景.instantiate() as Control
	# 立绘 = 身体 = 头像，三处共用服务端那一个 `face`（#191；原版 `CharacterHandler.as:303`
	# 的 `setMyImgChar` 与 `:305-307` 的 PortraitHead 取的是同一个号）。
	# ⚠ 看别人时**必须换成他的脸**：原版 `EquipPane.setOtherImgChar(face)`（`:158-167`，
	#    由 `CharPane.as:244-252 setData` 在 `!isMyself` 那支调用）用的就是 `58:4` 下标 6 那个号。
	#    `角色造型.造型号` 在 脸>0 时**不看性别**（同文件 :38-46）⇒ 他那帧只给脸号就够。
	var 站立 := (页面 as Control).get_node_or_null("原版人物属性面板/角色站立图") as TextureRect
	if 站立 != null:
		var 脸 := int(别人档.get("头像", 0)) if 是别人 else 0
		var 造型 := ""
		if 是别人 and 脸 <= 0:
			# 他的帧没带脸号（老帧/异常路径）⇒ **不画**，也不拿我的脸冒充他的。
			站立.texture = null
		else:
			var 身: Dictionary = 会话.call("自身外观")
			造型 = 角色造型.造型号(脸, 0) if 是别人 else 角色造型.造型号(int(身["face"]), int(身["gender"]))
			## ⭐ 原版这一格不是"一张站姿截图"，是**一具会播待机的角色精灵**：
			##   `EquipPane.as:376-390 setMyImgChar` → `getCharAliveLookJustFace(face)` 建 CharacterSprite，
			##   紧接 `setAction(Action.stand) / render() / play()`，再 `:622-625 onAddStageHand`
			##   把它挂进 `customHander.addTick` ⇒ 上屏之后每拍都在走帧。
			##   `:158-166 setOtherImgChar`（看别人）走的是同一个 CharacterSprite，同样进 tick。
			##   摆位 `PREVIEW_CHAR_X = 146>>1 = 73`（水平居中）、`PREVIEW_CHAR_Y = 208−35 = 173`（脚点）。
			## 之前我们只 `站立.texture = OriginalSprite.角色立绘(造型)` 取**一帧** ⇒ 窗里那具是死的（用户 10-25 报）。
			## 这里换成真播放器：动画精灵挂在 `角色站立图` **里面**、只清掉它自己的贴图。
			## ⚠ 两个"人物直接没了"的写法都踩过：
			##   ① 挂成兄弟 + `z_index − 1` ⇒ 掉到那块底板后面（量具照样数出像素在变，因为框里还有别的东西在动）；
			##   ② 挂成子节点但 `站立.visible = false` ⇒ 子树一起被藏。
			##   ⇒ 保持父节点可见、只把父的 texture 清空，绘制顺序就沿用静态图原来那一层。
			var 播 := 站立.get_node_or_null("角色待机") as OriginalSprite
			if 播 == null:
				播 = OriginalSprite.new()
				播.name = "角色待机"
				站立.add_child(播)
			播.position = Vector2(float(站立.size.x) * 0.5, float(站立.size.y))
			站立.texture = null
			站立.visible = true
			if 播.configure("character", 造型, "stand"):
				播.play("stand")
			else:
				# 查不到他的美术（缺帧）⇒ 退回原来那张静图；静图也没有就是空着，不拿我的冒充。
				播.queue_free()
				var 图 := OriginalSprite.角色立绘(造型)
				if 图 != null:
					站立.texture = 图
				elif 是别人:
					push_warning("人物窗口：他的脸号 %s（造型 %s）在本工程美术里查不到 ⇒ 立绘留空，不拿我的身体冒充"
						% [脸, 造型])
					站立.texture = null
	窗口._apply_common_control_skins(页面)
	窗口._content.add_child(页面)
	(页面.get_node("内容背景") as Panel).add_theme_stylebox_override("panel", 窗口._original_content_panel())
	# 装备格菜单（单击弹的那个）：每开一次页都是新页面新菜单节点，连一次就够
	# （同 `背包窗口` 的做法——它连在 渲染 里，不连在格子上，否则二十个格子连二十份）。
	var 装备菜单 := (页面 as Control).get_node_or_null("物品菜单") as Control
	if 装备菜单 != null:
		装备菜单.connect("选择了", func(项名: String): 装备菜单选择(窗口, 项名))

	# 同下面的子分页：页签身份是**序号**，不按节点名寻址，改名不会把窗口点崩。
	var 主分页按钮: Array[Button] = []
	for 子在 in (页面.get_node("主分页") as Node).get_children():
		if 子在 is Button:
			主分页按钮.append(子在 as Button)
	for 序号 in 主分页名称.size():
		if 序号 >= 主分页按钮.size():
			push_error("人物窗口.tscn 的 主分页 只有 %d 枚按钮，少于页签数 %d" % [主分页按钮.size(), 主分页名称.size()])
			break
		var 主分页 := 主分页按钮[序号]
		# 原版 `ButtonContainer` 的页签是**按文字自适应**的（左右各 7px 内边距），
		# 不是一律 40。基线实测：角色 10..48、秘术 48..86、血继界限 86..148 —— 38/38/62。
		# 以前这里硬传 (40,22)，四字页签被挤到只剩 48（文字 48 + 零内边距），明显偏窄。
		var 页签宽 := float(主分页.text.length() * 12 + 14)
		窗口._configure_overlay_button(主分页, Vector2(页签宽, 22.0))
		主分页.button_pressed = 序号 == 窗口._character_main_tab
		# 2026-10-19：看别人时这三页**都有只读内容了**（手里剑/结印/柔拳/写轮眼/轮回六道五页
		# 照原版 `_isMy…=false` 那几条改数据源 + 摁住动作钮），所以不再整枚禁掉。
		# 原版别人那扇还有第四枚「藏品图鉴」（`CharOtherWindow2.as:411`），本工程场景里
		# 主分页只有三枚钮，而且夹具在那四个下标（48..51）发的是**计数**、不是卡片清单
		# ⇒ 服务端没有可画的数据源（真值 §⑧-1）；**用户 2026-10-20 明确决定完全不做**。
		主分页.pressed.connect(窗口._set_character_main_tab.bind(序号))

	## 看别人：原版是**按对方的等级筛选该建哪几枚**（不够级根本不建），
	## 与自己那扇"建出来置灰"是两套语义。
	var 子分页名称: Array = (他人子分页表(窗口._character_main_tab, int(别人档.get("等级", 1)))
		if 是别人 else 子分页组[窗口._character_main_tab])
	# **按子节点顺序取，不按节点名取**：原来写死 `子分页/第%d项`，而场景里这三枚按钮
	# 已经被改名成 `第1项 / 手里剑页 / 结印页`（`unique_id` 可证是同一批节点），
	# `get_node` 取不到就返回 null，`子分页.visible = ...` 直接炸出
	# "Invalid assignment of property or key 'visible' ... on a base object of type 'null instance'"。
	# 页签身份是**序号**（`_set_character_sub_tab` 收的就是序号），节点名只是编辑器里的可读标签，
	# 不该参与寻址 —— 这样以后在编辑器里随便改名都不会把窗口点崩。
	var 子分页按钮: Array[Button] = []
	for 子在 in (页面.get_node("子分页") as Node).get_children():
		if 子在 is Button:
			子分页按钮.append(子在 as Button)
	for 序号 in 子分页按钮.size():
		var 子分页 := 子分页按钮[序号]
		子分页.visible = 序号 < 子分页名称.size()
		if not 子分页.visible:
			continue
		子分页.text = String(子分页名称[序号])
		子分页.tooltip_text = 子分页.text
		var 开放等级 := int(页面开放等级.get(子分页.text, 0))
		子分页.disabled = int(属性.get("level", 1)) < 开放等级
		if 子分页.disabled:
			子分页.tooltip_text = "%s（%d级开放）" % [子分页.text, 开放等级]
		# ⚠️ 旧代码这里还有一句 `是别人 and 序号 > 0 ⇒ 一律置灰（看别人时本轮未移植）`——
		#    那是 ⑩ 只读五页落地（§3.220，10-19）**之前**的临时闸；现在五个只读页都已接
		#    （手里剑/结印/柔拳/寄坏之术/写轮眼/轮回六道，见上面 `他人子分页组` 的注），
		#    原版对别人**根本不建**不够级的页签（`CharOtherWindow2.as:222-246`）而不是建出来置灰
		#    ⇒ 那句整段删除。门：`看别人属性窗回归测试` ⑨「寄坏之术这枚该可点」。
		子分页.button_pressed = 序号 == 窗口._character_sub_tab
		窗口._configure_standard_button(子分页)
		子分页.pressed.connect(窗口._set_character_sub_tab.bind(序号))

	var 页名 := String(子分页名称[窗口._character_sub_tab])
	var 人物面板 := 页面.get_node("原版人物属性面板") as Control
	var 扩展面板 := 页面.get_node("人物扩展页") as Panel
	人物面板.visible = 页名 == "人物"
	扩展面板.visible = 页名 != "人物"
	if 人物面板.visible:
		渲染人物页(窗口, 人物面板, 属性, 会话, 是别人, 装备源)
	else:
		渲染扩展页(窗口, 扩展面板, 属性, 页名, 是别人, 别人档)
	# 看别人：把「加点面板」整块换成「他人信息面板」
	# （原版 `CharPane.as:255-270 set isMyself`：`addPointPane.visible = v; pointInfoPane.visible = !v;`）
	if 是别人 and 人物面板.visible:
		切到他人信息面板(窗口, 人物面板, 属性, 别人档)

## 页入口：`窗口管理` 收到 `58:0` 那一帧时先灌 `窗口._他人档案`，再 `打开("人物属性看别人")`。
## 原版 `Client.as:3022-3034`：窗已存在就逐段 setData ⇒ 本工程同一实例重渲染（`打开` 对已开窗是幂等的）。
static func 渲染他人(窗口) -> void:
	var 档: Dictionary = 窗口.get("_他人档案")
	if 档.is_empty():
		# 没有档案就不要开一扇全 0 的窗 —— 那是把"没数据"演成"这个人什么都没有"。
		窗口._通知("还没有拿到对方的资料")
		return
	渲染(窗口, 档)


## ── 宠物页的数据源：段 32 那串宠物 + 段 14 的上限 ─────────────────────────────
## ⚠ **不另写一份解码**：段 32 的形状与宠物列表帧（`后端连接._handle_pet_action_text:3721-3729`
##   的 `action 0`）**逐字段同一套** —— `@` 分宠、每只 `&` 分 31 个位置字段、
##   skills/equipment 内部 `!` 分行 `#` 分列 ⇒ 直接调 `后端连接._parse_pet_fields(条.split("&"), 0, "!", "#")`。
##   服务端拼它的是 `_encode_pet`（`fake_flash_server.py` 的 full-info 那一段），
##   自己造一条=猜协议，所以这一页的夹具必须由在线门实收导出（见 `_重导查看信息夹具.py` 的那道拒绝）。
## 上限取段 14（`petLimit`，服务端恒 10）—— 原版 `setPetData(petList, petLimit)` 的第二个实参，
## 只用来写「携带数量 n/N」那一行；**只读那一扇不补空行、也没有「扩展兽栏」行**
## （`SimplePetWindow.updateShouLanList:570-604` 的 DataProvider 只 push 他有的那几只）。
static func 他人宠物(窗口, 档: Dictionary) -> Dictionary:
	var 清单: Array = []
	var 串 := String(档.get("宠物串", "-"))
	var 后 = 窗口.get("_backend")
	if 后 != null and 串 != "" and 串 != "-":
		for 条 in 串.split("@", false):
			var 解: Dictionary = 后.call("_parse_pet_fields", String(条).split("&", true), 0, "!", "#")
			if not 解.is_empty():
				清单.append(解)
	return {"宠物清单": 清单, "宠物上限": int(档.get("宠物上限", 10)), "归属号": int(档.get("cid", -1))}


## 名字右边那颗「改」（原版 `CharPane.as:321-331 onRenameClick`，按 `_isMyself` 分两条路）。
## · 自己 ⇒ 开「角色改名」窗 + 发 `2330:10`（原版 `show():59-69` 里 `refreshData():251-256`
##   干的就是这两件事：先把窗摆出来、顺手要一发历史名）。
## · 别人 ⇒ **只**发 `2330:12:<名字>`，开窗的是那一发回帧（`窗口管理._on_改名回帧`）——
##   与「查看信息」同一套路子：没拿到名单之前不摆一扇空窗。
## ⚠ 模式状态要设在**改名窗那个宿主实例**上（同 `_打开驯养窗` 那条 §3.62 的教训：
##   页面读的是它自己的 `_改名别人名 / _改名名单`，设在人物窗上等于没设）。
static func _改名钮被点(窗口, 只读: bool) -> void:
	var 后: Node = 窗口._backend
	if 后 == null or not bool(后.get("in_game")):
		窗口._通知("查历史名要在线")
		return
	if 只读:
		var 名 := String(窗口.get("_他人档案").get("名", ""))
		if 名.is_empty():
			窗口._通知("还没拿到对方的资料")
			return
		if not bool(后.call("request_other_history_names", 名)):
			窗口._通知("查历史名请求发送失败")
		return
	var 管理: Node = 窗口.get_parent()
	if 管理 == null or not 管理.has_method("取或建窗口"):
		窗口._通知("打不开改名窗")
		return
	var 改窗: Node = 管理.call("取或建窗口", "角色改名")
	改窗.set("_改名别人名", "")
	改窗.set("_改名名单", PackedStringArray())
	管理.call("打开", "角色改名")
	if not bool(后.call("request_history_names")):
		窗口._通知("历史名请求发送失败")


static func 渲染人物页(窗口, 面板: Control, 属性: Dictionary, 会话, 是别人 := false, 装备源: Dictionary = {}) -> void:
	# 原版 `CharPane.init` 里这七格都是 `CharInfoCell`：**标题和数值是两个独立的文本框**
	# （`mInfoLabel` / `mInfoText`），数值的 x 恒等于标题宽度
	# （`mInfoText.x = mInfoLabel.width`，:107）。所以标题和数值之间那点空隙是**排出来的**，
	# 不是往字符串里塞空格 —— 原先一格一个 Label 的写法既对不上原版配色
	# （标题 #fcc399、数值白，名字数值是 UI_GREEN），也没法单独取 tooltip。
	设置信息格(窗口, 面板, "姓名格", "名字：", String(属性.get("name", "忍者")), Color("#00ff00"))
	# 职业名由**职号查表**得出（`脚本/单例/职业.gd`，唯一真值）。
	# ⚠️ 原来读的是 `job_name` 这个字符串字段 —— 但**只有离线示例数据会设它**，
	# 真服务端只发 `job`（int）。于是离线显示自造的"体术流"、连上后又掉到默认值"忍者"。
	设置信息格(窗口, 面板, "等级格", "等级：", str(int(属性.get("level", 1))), Color.WHITE)
	设置信息格(窗口, 面板, "职业格", "职业：", 职业表.取(int(属性.get("job", 0))), Color.WHITE)
	# 原版 `CharPane.as:228` `familyCell.text = param1.family ? param1.family : "-"`：
	# 空串按 falsy 落成 `-`（自己那扇的 `family` 来自 `player_stats`，见
	# `后端连接._同步家族到人物属性`；看别人那扇来自 `58:4` 段 7）。
	var 家族名 := str(属性.get("family", ""))
	设置信息格(窗口, 面板, "家族格", "家族：", 家族名 if not 家族名.is_empty() else "-", Color.WHITE)
	# 第二三行的文案按 AS3 `CharPane.init` 与原文语言表更正（原来是自造的）：
	#   fameCell     = CHARACTOR_POPULAR = **罪恶值**（原写"声望"）
	#   spouseCell   = CHARACTOR_SPOUSE  = **羁绊**  （原写"意志"）
	#   expBar       = CHARACTOR_EXP     = **经验值**
	#   breathBar    = CHARACTOR_BREATH  = **精华**  （原写"精气"）
	#   意志在第三行第三格（`yizhiCell.y = expBar.y - 2`、x 同 spouseCell）
	# ⚠️ 2026-10-09 修：读的是 **`crime`（服务端字段 33）**，不是 `fame`（字段 26）。
	# 原版 `DataCenter.getDataForCharacterInfoWindow` 这句就是 `_loc1_.fame = this.stats.crime`
	# （`:1464`，`updateOtherPlayerStats` 的 `:2359` 同），**真 fame 从不显示**；
	# 而服务端 `_send_all_stats` 只发 33、**从不发 26** ⇒ 原来这行永远是登录时的旧数/0。
	设置信息格(窗口, 面板, "罪恶值格", "罪恶值：", str(int(属性.get("crime", 0))), Color.WHITE)
	设置信息格(窗口, 面板, "羁绊格", "羁绊：", String(属性.get("spouse", "-")), Color.WHITE)
	# 意志：原版 `YiZhiManager.updateYiZhiLi:284` 把这枚 `yiZhiLi`
	# （= **已穿戴**意志的 `Σ rongHeExp ÷ 30`，`caculateYiZhiLi:168-181`）推给人物面板这一格。
	# ⚠️ 2026-10-13 修：原来读的是 `属性.will` —— **全工程没有任何地方写这个键**（脚本/素材/测试/
	#    服务端/数据 全 grep 过，只此一处读）⇒ 这格永远是 0，练了意志也不动。
	#    真值本工程早就有：`游戏会话.意志力()`（= 同一句 `caculateYiZhiLi`），意志窗口正在用。
	#    （2026-10-20 那一轮把它里面缺的 `level1` 加数与黄帧 1200 补上了 ⇒ 这一格才真的跟着练度动。）
	# （原版同一句还把这个值当 tooltip 正文传给那一格：`setYiZhiData:290-299` 把
	#  `getYiZhiPropToopTioInfo` 整串挂到 `yizhiCell` 上 ⇒ 见下面 `_接信息提示` 最后一条。）
	# 看别人时这一格原版没有（`CharPane` 的意志力只看自己算）⇒ 不拿我的数冒充他的。
	设置信息格(窗口, 面板, "意志格", "意志：",
		"-" if 是别人 else str(int(窗口._session.意志力())), Color.WHITE)
	# 「改」按钮：原版 `CharPane.as:132-140` 建的 `MButtonF`（`text="改"`、20×20、
	# `x = nameCell.x + 138`、`y = nameCell.y`、`isScale9Grid`），`onClick` 走 `:321-331 onRenameClick`。
	# ⚠ 早先这里写的是 `:370-378` —— 那一段是 `getCombatExtraEquipList` 的战外装备循环，
	#   与这颗钮无关（10-25 对着 `2.2.3/.../char/CharPane.as` 逐行核过）。
	# · 自己 ⇒ `ChangeNameWindow.show()`（改名窗，顺手发 `2330:10` 要历史名）；
	# · 别人 ⇒ **查历史名**（`CharPane.as:321-331` → `requestOtherHistoryNamesByName`），
	#   不是改名。⚠ 上一版这里一律写"修改角色名字"+ 一句占位提示 ⇒ 在看别人的窗上点它，
	#   弹的是一句不相干的话，而且这枚钮还被整枚藏掉了（§⑧-2）。
	var 改名 := 面板.get_node("改名按钮") as Button
	改名.visible = true
	改名.tooltip_text = "查看这个玩家用过的名字" if 是别人 else "修改角色名字"
	for 连 in 改名.pressed.get_connections():
		改名.pressed.disconnect(连["callable"])
	改名.pressed.connect(_改名钮被点.bind(窗口, 是别人))

	# 经验/精华是**动态条**，不是文字：原版用 MBar（槽 158 + 绿色填充 164）。
	# 位置按真机截图量：经验槽 x57..123、精华槽 x199..267，y45..56。
	设置标签(窗口, 面板, "经验值", "经验值", Color("#f5e9d2"), 12)
	设置标签(窗口, 面板, "精华", "精华", Color("#f5e9d2"), 12)
	var 经验条 := 面板.get_node("经验条") as ProgressBar
	var 精华条 := 面板.get_node("精华条") as ProgressBar
	var 经验数 := float(属性.get("exp", 0))
	var 经验上限 := maxf(1.0, float(属性.get("max_exp", 100)))
	var 精华数 := float(属性.get("breath", 0))
	var 精华上限 := maxf(1.0, float(属性.get("max_breath", 100)))
	# 填充走件：0.5s 二次缓出 + 同数据早退 + 换数据杀旧补间（`MBar.as:130/133/170`）。
	# ⚠ 下面两行文案**按灌进去的数据算**，不许读 `条.value` —— 读了数字就跟着条爬（真值 §⑤b）。
	进度条补间.灌值(经验条, 经验数, 经验上限, [经验数, 经验上限])
	进度条补间.灌值(精华条, 精华数, 精华上限, [精华数, 精华上限])
	var 经验数值 := 面板.get_node("经验数值") as Label
	var 精华数值 := 面板.get_node("精华数值") as Label
	经验数值.text = "%d%%" % int(round(100.0 * 进度条补间.比例(经验数, 经验上限)))
	精华数值.text = "%d%%" % int(round(100.0 * 进度条补间.比例(精华数, 精华上限)))
	窗口._configure_label(经验数值, 数值字号, Color.WHITE)
	窗口._configure_label(精华数值, 数值字号, Color.WHITE)
	# ⚠️ 这里原来给的是三行**自造**的原生 `tooltip_text`（"当前经验 %d，升级所需经验 %d" /
	#   "当前精华 %d/%d" / "家族：%s\n配偶：%s"）。原版这三处都有、但用的**不是这两句话**：
	#   `CharPane.as:212-213` 给的是语言表 `CHARACTOR_EXP_TIP2` / `CHARACTOR_BREATH_TIP2`
	#   （带获得途径与提示两段、红黄绿配色），家族那处给的是 `CHARACTOR_FAMILY_TIP`。
	#   ⇒ 整块挪到下面的 `_接信息提示`，一处一份、串全部出自 `数据/界面/人物_文案.json`。

	# 格子名是 AS3 运行时写进去的动态文字（`cell.equipNameText.text = EQUIP_NAMES[i]`），
	# 底板与装备槽布局图里都没有，所以客户端要自己画。原版实测：色 #ff9100（UI_ORANGE）、
	# 字号 12，文字框 23×12，落在格子左上角 +6、竖直居中。
	# 现在名称 Label 就是**各自格子的子节点**（`装备格子容器/武器格/名称`），
	# 和原版 `MCell.equipNameText` 的归属一致，不再单开一个平铺容器。
	var 装备格容器 := 面板.get_node("装备栏/装备格子容器") as Control
	# 数据源**只看 `是别人`**，不看 `装备源` 空不空：他那扇即使一件装备都没解出来，也必须停在
	# 空格子（原版 `CharOtherWindow2` 没装就是空格），绝不能回落到 `会话.equipped_items`
	# —— 回落就是"拿我的装备冒充他的"（10-22 这条门的判据腿）。
	var 装备表: Dictionary = 装备源 if 是别人 else 会话.equipped_items
	for 位置 in 装备部位表.人物面板槽:
		var 节点名 := String(装备格节点[位置])
		var 显示名 := 装备部位表.显示名(位置)
		var 物品: Dictionary = 装备表.get(位置, {})
		var 有装备 := not 物品.is_empty()
		var 装备格 := 装备格容器.get_node_or_null(节点名) as Button
		if 装备格 == null:
			# 取不到就报一条**说得清是哪格**的错然后跳过。以前这里用 `get_node`，
			# 返回 null 之后紧接着 `.visible =`，用户看到的就是十几行
			# "Invalid assignment of property or key 'visible' ... on a base object of type 'null instance'"，
			# 而真正的因（场景里格子节点名和表对不上）被埋在最后一行 `Node not found` 里。
			push_error("人物窗口.tscn 缺少装备格节点：装备格子容器/%s（部位 %d）" % [节点名, 位置])
			continue
		var 配套标签 := 装备格.get_node_or_null("名称") as Label
		if 配套标签 != null:
			窗口._configure_label(配套标签, 12, Color("#ff9100"))
		# 拖放：这一格是**背包物品的落点**（见 `装备格.gd` 的 `_can_drop_data`）。
		# `装备格` 静态类型是 Button，而归属/槽位号是 `可拖拽格.gd` 上的成员，
		# 直接写 `装备格.格子归属` 会**编译期**报"Button 上没有这个属性"，
		# 所以跟上面那几个覆盖层一样走 `set()`（本文件既有的写法）。
		# 槽位号填**装备位置 int**（负数），不是背包那种 1 基下标 —— 协议里就是这个数。
		装备格.set("格子归属", "装备")
		装备格.set("槽位号", 位置)
		装备格.set("物品id", String(物品.get("id", "")) if 有装备 else "")
		# 装备格**只当落点、不当拖拽源**：原版从装备格起拖是死代码（`可拖拽格.gd` 有出处）。
		装备格.set("可拖拽", false)
		var 拖放信号: Signal = 装备格.get("拖放")
		for 连接 in 拖放信号.get_connections():
			拖放信号.disconnect(连接["callable"])
		# 看别人 = **只读**：原版 `EquipPane.as:1114-1130 removeMouseEvents()`（由 `:747-757`
		# `set isMyself(false)` 调）把 MSPRITE_CLICK/UP/OUT/DOUBLE_CLICK 全部摘掉、
		# `doubleClickEnabled=false`，**只留悬停提示**。本工程对应的两条动作腿是
		# 「拖放落点」与「单击弹菜单/双击卸下」⇒ 都不接（接了就是点他的格子卸下**我的**件）。
		if not 是别人:
			拖放信号.connect(_处理装备格拖放.bind(窗口))
		# 神器剑/镜两格：原版 `EquipPane.removeShenqiCellData` 没装备就 `visible = false`
		# （连名字都不留）。用户 2026-09-21 确认照这个来。其余 18 格恒可见。
		if 位置 in 无装备即隐藏:
			装备格.visible = 有装备
		else:
			装备格.visible = true
		# 有图标就**不显示格子名** —— 原版 `EquipmentWindowCell.as:124`
		# （`showIcon()` 里 `equipNameText.visible = false`），卸空后 `:84` 再变回 true。
		# 名字是叠在装备格**上层**的，常显就会盖住图标（用户 2026-09-21 报的）。
		if 配套标签 != null:
			配套标签.visible = not 有装备
		# 三个覆盖层都交给 `装备格.gd`（条件的出处都在那个文件里）：
		#   资质框 —— EquipmentWindowCell.as:130-136，资质 1(白) 不显示
		#   破碎角标 —— 同文件 :144-151，crashTime > 0
		#   耐久红框 —— 同文件 :171，endure == 0
		#   强化/镶嵌角标 —— 同文件 :152-168
		# ⚠️ 灵器格/忍具格**不是** `EquipmentWindowCell`：原版这两格各有一个专用类，
		#    装备上之后无条件叠 `EquipAptitudePinkF` + `EquipAnimationF`（不看资质）——
		#    灵器 `LingQiCell.as:85-92`、忍具 `RenJuCell.as:85-92`。
		#    本工程两格都用通用 `装备格` 顶，粉框要靠这两个开关打开（2026-10-31 用户报
		#    「十拳剑/八咫镜装备后格子上没有流光外框」就是这个：以前一律按 aptitude 查，
		#    这两族没有 aptitude ⇒ 整格什么都不叠）。
		if 有装备:
			装备格.call("设置品质", 物品, 位置 == 装备部位表.灵器, 位置 == 装备部位表.忍具)
			装备格.call("设置破碎", int(物品.get("crash_time", 0)) > 0)
			装备格.call("设置耐久归零", int(物品.get("endure", -1)) == 0)
			装备格.call("设置强化", int(物品.get("strengthen", 0)))
			装备格.call("设置镶嵌", 物品.get("inlays", []) as Array)
		else:
			装备格.call("清空覆盖层")
		装备格.disabled = not 有装备
		装备格.icon = null
		# ⚠️ 原来这里给的是**原生 `tooltip_text`**（一行"武器：竹制忍杖"）。
		#    原版装备格悬停出的是 `MToolTipItem` 全套提示框（`EquipmentWindowCell.as:173`
		#    `showToolTip()`，按 EqpData 分发到 `MToolTipZhuangBei`）——
		#    接**与背包/仓库同一份** `格子提示框.接线`（helper 会清掉原生 tooltip_text）。
		# ⚠️ 提示框要传**页面根**而不是 `面板`：`原版人物属性面板` 自带 `clip_contents`
		#    （装备格不该画到面板外，这个裁剪是对的），提示框挂它里面就会被下缘切掉。
		#    原版 `MToolTipItem.createToolTip(API.stage, …)` 本来就挂在 stage、永不裁剪。
		#    看别人时**照样接**：`removeMouseEvents` 摘的是点击系四条，悬停提示留着。
		#    对比列按原版的 `!_isMyself` 分流（`EquipmentWindowCell.as:226-232`）——
		#    注意那句取的是 `API.dataCenter.getEquipedItemById(value.id)`，`dataCenter` 是**本机**，
		#    所以看别人时右侧那一列是**我身上同槽位那件**（拿他的武器跟我的武器比），不是他的第二件。
		#    自己的装备格 ⇒ 恒不比对（自己跟自己比没有意义）。
		格子提示框.接线(窗口, 面板.get_parent() as Control, 装备格,
			物品 if 有装备 else {}, 是别人)
		if not 是别人:
			_接装备格点击(窗口, 面板.get_parent() as Control, 装备格, 位置, 物品 if 有装备 else {})
		if not 有装备:
			continue
		# ⚠️ 不能把 `物品.get("icon")` 直接赋给 icon —— 物品没有该字段时拿到的是空串，
		# 会被当成路径去 load 并报错（2026-09-25 写套装用例时撞到）。
		var 图路径 := String(物品.get("icon", ""))
		装备格.icon = (load(图路径) as Texture2D) if not 图路径.is_empty() else null
		# ⚠️ 这里原来还有一句 `装备格.pressed.connect(窗口._unequip.bind(位置))`（单击即卸）。
		#    它既没"先断再连"（每次重渲染都会撞 already connected），点击语义也比原版快一步；
		#    2026-10-01 点击语义整体换成上面的 `_接装备格点击`（单击弹菜单、双击才卸）。
	_更新套装图标(面板, 会话, 装备表)
	# 战斗属性六行：节点名与可见文字一一对应，标题文案就在场景里，不再运行时改名。
	# 攻击速度/移动速度整行走 UI_GREEN，且服务端下发浮点、原版取整显示。
	var 战斗属性 := {
		"攻击": ["attack", false],
		"防御": ["defense", false],
		"暴击": ["critical", false],
		"闪避": ["dodge", false],
		"攻击速度": ["attack_speed", true],
		"移动速度": ["move_speed", true],
	}
	var 战斗属性区 := 面板.get_node("战斗属性") as Control
	for 名称 in 战斗属性:
		var 字段 := String(战斗属性[名称][0])
		var 是速度 := bool(战斗属性[名称][1])
		窗口._configure_label(战斗属性区.get_node("%s标题" % 名称) as Label, 12,
			Color("#00ff00") if 是速度 else Color("#ff9100"))
		var 数值 := 战斗属性区.get_node(名称) as Label
		数值.text = str(int(round(float(属性.get(字段, 0))))) if 是速度 else str(属性.get(字段, 0))
		窗口._configure_label(数值, 数值字号, Color("#00ff00") if 是速度 else Color("#ffffff"))
	窗口._configure_label(面板.get_node("战斗属性标题") as Label, 12, Color("#fff000"))
	# 「战斗属性」右边那枚箭头 = 原版挂在 `secondAttributePane.extraAttrBtn` 上的
	# `onToggleCombatExtraAttr`（`CharPane.as:193` 接线、`:333-339` 开关）：它开关的是**另一块**
	# 「其他属性」浮板（`combatExtraAttrBg` + `combatExtraAttrPane` + `combatExtraAttrExtendPane`，
	# `CharPane.as:167-191` 建、`:341-352` 填、`:474-516` 排扩展行与长高）。
	_接其他属性(窗口, 面板, 属性, 会话, 是别人)

	var 临时点: Dictionary = 窗口._character_pending_ap
	var 临时总数 := 0
	for 临时值 in 临时点.values():
		临时总数 += int(临时值)
	var 可用点 := maxi(0, int(属性.get("remaining_ap", 0)) - 临时总数)
	# 标题文案与颜色依据 2.2.3 `en_US$message_properties.as`（UI_28=加点属性）与
	# `CharAddPointPane` 构造函数：BaseUtil.getLabel2(...,56) 默认色 UIConfig.UI_YELLOW。
	var 标题 := 面板.get_node("加点属性标题") as Label
	标题.text = "加点属性"
	窗口._configure_label(标题, 12, Color("#fff000"))
	# 四行文案依据 `en_US$message_properties.as`：
	#   CHAR_FIRST_ATTR_ATTACK=攻击型 / _DEFENCE=防御型 / _DEXTERITY=灵巧型 / _STRENGTH=健体型
	# 绑定关系依据 `CharAddPointPane` 构造函数与 `setCellPoints` 的参数序：
	#   strengthCell(ap_atk) / dexterityCell(ap_def) / intelligenceCell(ap_dex) / luckCell(ap_phy)
	var 基础属性 := {"攻击": "ap_atk", "防御": "ap_def", "灵巧": "ap_dex", "健体": "ap_phy"}
	var 基础属性区 := 面板.get_node("基础属性") as Control
	for 名称 in 基础属性:
		var 属性键 := String(基础属性[名称])
		var 已分配 := int(临时点.get(属性键, 0))
		# 标签与数值分局两格，依据 CharInfoCell.init(label, 82, 42, ...)：
		# 标签宽 42、数值起点 42、数值宽 40 且居中（setInputTextWidth）。
		var 属性标签 := 基础属性区.get_node(名称) as Label
		属性标签.text = "%s型" % 名称
		窗口._configure_label(属性标签, 12, Color("#ff9100"))
		var 属性值 := 基础属性区.get_node("%s值" % 名称) as Label
		属性值.text = str(int(属性.get(属性键, 0)) + 已分配)
		窗口._configure_label(属性值, 数值字号, Color("#ff9100"))
		var 全加 := 基础属性区.get_node("%s全加" % 名称) as Button
		全加.tooltip_text = "把剩余属性点全部分配到%s" % 名称
		全加.disabled = 可用点 <= 0
		全加.pressed.connect(调整临时加点.bind(窗口, 属性键, 可用点))
		var 加点 := 基础属性区.get_node("%s加点" % 名称) as Button
		加点.tooltip_text = "分配 1 点%s" % 名称
		加点.disabled = 可用点 <= 0
		加点.pressed.connect(调整临时加点.bind(窗口, 属性键, 1))
		var 减点 := 基础属性区.get_node("%s减点" % 名称) as Button
		减点.tooltip_text = "减少 1 点临时分配"
		减点.disabled = 已分配 <= 0
		减点.pressed.connect(调整临时加点.bind(窗口, 属性键, -1))
		var 全减 := 基础属性区.get_node("%s全减" % 名称) as Button
		全减.tooltip_text = "撤回该项临时分配"
		全减.disabled = 已分配 <= 0
		全减.pressed.connect(调整临时加点.bind(窗口, 属性键, -已分配))

		# 潜能点行：文案 CHARACTOR_POTENTIAL=潜能点，值即剩余可用潜能点（AS3 的 pointText）
		var 潜能点 := 面板.get_node("潜能点") as Label
		潜能点.text = "潜能点"
		窗口._configure_label(潜能点, 12, Color("#ff9100"))
		var 潜能点值 := 面板.get_node("潜能点值") as Label
		潜能点值.text = str(可用点)
		窗口._configure_label(潜能点值, 数值字号, Color("#ff9100"))

	# 确定/推荐是 34×21 的小按钮（依据 CharAddPointPane：okBtn/recommendBtn 宽度都设成 34）。
	# 字号必须是 12：原版的「确定」是宋体 12 号点阵、逐像素实心，10 号没有点阵会发虚。
	# 按钮矩形在场景里写死 34 宽，字号变大不会把它撑宽（实测节点矩形不变）。
	var 确认 := 面板.get_node("确认加点") as Button
	确认.disabled = 临时总数 <= 0
	确认.tooltip_text = "确认后一次提交本次临时分配"
	确认.pressed.connect(确认临时加点.bind(窗口))
	var 推荐 := 面板.get_node("推荐加点") as Button
	推荐.disabled = int(属性.get("remaining_ap", 0)) <= 0
	推荐.pressed.connect(推荐加点.bind(窗口))

	# ⚠️ 字号与颜色都是从原版基线量出来的：标签字形高 **12px**、颜色 **(252,195,153)** = `#fcc399`。
	# 逐号实测过：11 号→11px、**12 号→12px（与原版一致）**、13 号→13px。见 §3.23.5。
	设置标签(窗口, 面板, "当前生命", "生命值", Color("#fcc399"), 12)
	设置标签(窗口, 面板, "当前查克拉", "查克拉", Color("#fcc399"), 12)
	设置状态条(窗口, 面板, "生命", int(属性.get("hp", 0)), int(属性.get("max_hp", 1)))
	设置状态条(窗口, 面板, "查克拉", int(属性.get("mp", 0)), int(属性.get("max_mp", 1)))
	# 悬停提示放在**最后**：宿主 Label 得先被上面那些 `设置标签/设置信息格/设置状态条` 填好，
	# 原版同一条顺序（`CharPane.as:194` 的 `setToolTip()` 就是 `init` 的最后一句）。
	_接信息提示(窗口, 面板, 属性, 是别人)


## 原版 `CharPane.as:197-216 setToolTip()` 一共十处悬停提示：信息区三格标题（罪恶值 / 家族 /
## 羁绊）、四条进度框的**名**（经验 / 精华 / 生命 / 查克拉）、经验与精华进度框的**数值**
## （ `%1/%2` 动态串）、外加「意志格」整格（`:284` 由 `YiZhiManager` 推串进来）。
## ⚠️ 只这三格有标题提示：`姓名 / 等级 / 职业` 原版**没有** `createToolTip` —— 别按"每格都该有"外推。
## ⚠️ 进度框那两处用的是 `mLabel`（名字）与 `tf`（数值）**两个不同文本框**，本工程一一对应：
##   `经验值`/`精华`/`当前生命`/`当前查克拉` = mLabel，`经验数值`/`精华数值` = tf。
static func _接信息提示(窗口, 面板: Control, 属性: Dictionary, 是别人: bool) -> void:
	# 提示框挂**页面根**，不挂 `面板`：`原版人物属性面板` 带 `clip_contents`（装备格不该画到
	# 面板外，这个裁剪是对的），挂它里面提示框会被下缘切掉 —— 与装备格那条同一个坑（:358-361）。
	var 页面 := 面板.get_parent() as Control
	if 页面 == null:
		return
	_挂文字提示(页面, 面板, "信息区/罪恶值格/名称", 键("CHARACTOR_POPULAR_TIP"), "罪恶值")
	_挂文字提示(页面, 面板, "信息区/家族格/名称", 键("CHARACTOR_FAMILY_TIP"), "家族")
	_挂文字提示(页面, 面板, "信息区/羁绊格/名称", 键("CHARACTOR_SPOUSE_TIP"), "羁绊")
	_挂文字提示(页面, 面板, "经验值", 键("CHARACTOR_EXP_TIP"), "经验名")
	_挂文字提示(页面, 面板, "精华", 键("CHARACTOR_BREATH_TIP"), "精华名")
	_挂文字提示(页面, 面板, "当前生命", 键("CHARACTOR_HP_TIP"), "生命名")
	_挂文字提示(页面, 面板, "当前查克拉", 键("CHARACTOR_MP_TIP"), "查克拉名")
	# 动态两处：`updateExpBarToolTip:79-90` / `updateBreathBarToolTip:272-283` =
	# `CN.replaceString(TIP2, bar.current, bar.total)`。原版挂在 MOUSE_OVER 上现算，本工程
	# 每次数据变化整页重画 ⇒ 串在重画时刷新，等价且更早一步（同一条数就是那两根条用的数）。
	_挂文字提示(页面, 面板, "经验数值", 填(键("CHARACTOR_EXP_TIP2"),
			[int(属性.get("exp", 0)), int(属性.get("max_exp", 0))]), "经验数值")
	_挂文字提示(页面, 面板, "精华数值", 填(键("CHARACTOR_BREATH_TIP2"),
			[int(属性.get("breath", 0)), int(属性.get("max_breath", 0))]), "精华数值")
	# 意志格：`yizhiCell` **整格**是宿主（`:298` 传的是 cell，不是它的 mInfoLabel）。
	# 看别人时不挂 —— 那串的正文是「当前意志 + 我穿戴的每一件」，拿我的账画他的格是假的。
	if not 是别人:
		var 会 = 窗口._session
		if 会 != null:
			_挂文字提示(页面, 面板, "信息区/意志格",
					意志提示框.意志力提示文案(会.spirit_equipped, int(会.意志力())), "意志值")


## ── 「其他属性」浮板 ──────────────────────────────────────────────────────────
##
## 原版三件套（`CharPane.as`）：`combatExtraAttrBg` = `MYellow_background`（`:167-175`）、
## `combatExtraAttrPane` = 又一个 `CharSecondAttributePaneF`（`:176-183`）、
## `combatExtraAttrExtendPane` = 再一个（`:184-191`，标题空串、只画装备附加行）。
## 开关 `:333-339`、填值 `:341-352`、扩展行排布与底板长高 `:474-516`、单行样式 `:523-532`。
##
## **位置是关系式、不是绝对像素**：`:168` `bg.x = secondAttributePane.x + width + 8`、
## `bg.y = secondAttributePane.y`、宽高同 `secondAttributePane`。本工程场景里
## `战斗属性面板` = (243, 64, 173×150) ⇒ 浮板落在面板坐标 (424, 64)、页面根坐标 (493, 84)
## （`原版人物属性面板` 在根里的原点是 69,20）。
## ⚠️ 必须挂**页面根**、不能挂 `原版人物属性面板` 里：那块 `clip_contents = true`，
## 而按原版这个关系式浮板本来就**出窗**（435 宽的属性面板右边只剩 11px）。原版 Flash
## 不裁剪 ⇒ 它就悬在窗外的场景上，而且 `:173-174` 专门把底板 `mouseEnabled/mouseChildren`
## 关掉 —— 纯装饰、不吃点击。本工程 `遮罩/主窗口/页面容器` 那条链上没有 `clip_contents`
## （实测 `功能窗口.tscn` 一处都没有）⇒ 同样能画到窗外，不需要自造"往窗内挪"的版式。
const 其他属性宽 := 173.0
const 其他属性基准高 := 150.0
const 其他属性行距 := 22.0
## 首行 y（浮板内）：场景里 `战斗属性` 那六行的行标题在 -1/21/43/65/87/109，
## 而它们所在 `Control` 的 y=86、底板 y=64 ⇒ 第一行相对底板 = 86-1-64 = **21**，行距 **22**。
const 其他属性首行 := 21.0
## 标题 x = **62**：原版 `CharSecondAttributePane.init` 写死 `_zhanDouShuXing.x = 62`，
## `setTitleText()` 只重排箭头、**不重新居中**（`:82-86`）⇒ 这一板的标题跟「战斗属性」那板的
## 场景位（305 - 243 = 62）完全一致。单行样式照 `setupCombatExtraAttrCell:525-531`：
## 标签 x=37 宽 **78**、数值紧跟其後 x=115 宽 **56**、色 `UI_ORANGE` 标签 / `UI_GREEN` 数值。
## 这四个数如今**烘在场景里**（`其他属性面板/第N行题|值`），脚本不再算坐标，
## 但 `人物秘术页回归测试` ⑫ 逐格量它们 —— 改了场景不改断言会红。
const 其他属性行高 := 18.0
## 附加行池的行数：`其他属性加成序` 一共六类 ⇒ 最多六行，池按最大备足。
const 其他属性附加行池 := 6
## 三格固定行：文案**逐字**照 `:344-346`（全角空格是原版写死的）。
## 键名是 `player_stats` 那侧的蛇形名（`服务端会话同步.应用人物` 把 41/42/43 映射成它们）。
const 其他属性固定行 := [
	["伤 害 减 免", "damage_reduce"],
	["伤 害 反 弹", "damage_reflect"],
	["无 视 防 御", "ignore_def"],
]
## 装备附加行：类型号、顺序、文案照 `:389-407`（`查克拉加成` 那格原版就是**不带**空格的）。
const 其他属性加成序 := [
	[4, "攻 击 加 成"], [5, "防 御 加 成"], [1, "生 命 加 成"],
	[2, "查克拉加成"], [6, "暴 击 加 成"], [7, "闪 避 加 成"],
]


static func _接其他属性(窗口, 面板: Control, 属性: Dictionary, 会话, 是别人: bool) -> void:
	var 展开 := 面板.get_node("战斗属性展开") as Button
	展开.tooltip_text = "打开「其他属性」（伤害减免 / 伤害反弹 / 无视防御 + 装备加成）"
	var 板 := _取其他属性板(面板)
	# 看别人：原版这一板的数据来自 stats（`DataCenter.as:1476-1478`），而 `58:4` 那一帧
	# **没有**这三条率的段（伤害减免/伤害反弹/无视防御只在服务端给自己那帧里算，
	# 档案尾巴 30..51 装的是手里剑/柔拳/结印/写轮眼/轮回六道与卡片计数）⇒ 藏掉箭头，
	# 不画一板 0 冒充他的（同「改名」那格"原版有、本工程没接 ⇒ 藏掉"的口径）。
	# ⚠ 他的**装备附加行**（攻/防/生/暴/闪/查克拉加成）现在**是**解出来的
	# （`后端连接._他人装备表` 走同一个 `_parse_item_entry`），但这一板是"三率 + 附加行"**一整块**，
	# 三率缺 ⇒ 整块不画，不画半板。
	展开.visible = not 是别人
	if 是别人:
		if 板 != null:
			板.visible = false
		return
	if 展开.pressed.get_connections().is_empty():
		展开.pressed.connect(切换其他属性.bind(窗口))
	if 板 == null:
		## 场景里没烘出这块板 ⇒ `push_error` 已经在 `_取其他属性板` 里报过了。
		## 箭头**照旧接线**：把钮拆了只会多一条"死钮"红，把真正的缺件盖住。
		return
	板.visible = bool(窗口._其他属性开着)
	if 板.visible:
		_画其他属性面板(窗口, 板, 属性, 会话)


## 浮板烘在场景里（`其他属性面板`），页面根就是它爹 —— 挂在这而不是挂「战斗属性面板」里，
## 是因为原版那块**出窗**：`(493,84)` 相对页面根，比 `原版人物属性面板` 的右边界还往右，
## 而那一层带 `clip_contents = true`（挂进去会被裁掉）。
static func _取其他属性板(面板: Control) -> Control:
	var 页面根 := 面板.get_parent() as Control
	if 页面根 == null:
		push_error("人物窗口：取不到页面根 ⇒「其他属性」浮板没处挂")
		return null
	var 板 := 页面根.get_node_or_null("其他属性面板") as Control
	if 板 == null:
		push_error("人物窗口：场景里没烘出「其他属性面板」⇒ 这枚箭头点了不会有板")
	return 板


## 点箭头：原版只翻三件的 `visible`（`:333-339`），不重发任何包。本工程整页每轮回包重建
## ⇒ 态记在窗口上（`_其他属性开着`），重建时按它补画（同 §3.206 提升弹窗那一笔）。
static func 切换其他属性(窗口) -> void:
	窗口._其他属性开着 = not bool(窗口._其他属性开着)
	窗口._render_page()


static func _画其他属性面板(窗口, 板: Control, 属性: Dictionary, 会话) -> void:
	var 加成 := 其他属性加成行(会话.equipped_items.values())
	var 高 := 其他属性板高(加成.size())
	板.size = Vector2(其他属性宽, 高)
	# 底板：`MYellow_background` = 主题里 Panel 那一档（`界面皮肤.configure_panel` 的
	# `outer=false` 支路只置 mouse_filter，样式来自 Theme）。**只在有附加行时才垫**——
	# 没有附加行时 173×150 这块跟「战斗属性」那一块同尺寸，顶上的烘焙图本身就是完整底板，
	# 再垫一层 Panel 只会把 9 宫格的边框叠到图框上。
	var 底 := 板.get_node("底板") as Panel
	底.visible = 高 > 其他属性基准高
	底.size = Vector2(其他属性宽, 高)
	窗口._configure_original_panel(底)
	窗口._configure_label(板.get_node("标题") as Label, 12, Color("#fff000"))
	for 序号 in 其他属性固定行.size():
		var 条目: Array = 其他属性固定行[序号]
		_其他属性行(窗口, 板, 序号, String(条目[0]),
			其他属性值文案(int(属性.get(String(条目[1]), 0))), true)
	for 序号 in 其他属性附加行池:
		var 用 := 序号 < 加成.size()
		_其他属性行(窗口, 板, 其他属性固定行.size() + 序号,
			String(加成[序号][0]) if 用 else "",
			其他属性值文案(int(加成[序号][1])) if 用 else "", 用)


## 行号 **0 起算**：0-2 是三条固定率，3.. 是装备加成（池共 `其他属性附加行池` 行）。
## 坐标烘在场景里（题 x=37 宽 78、值 x=115 宽 56，行距 22、数值比标题低 1px，
## 与 `战斗属性` 那六格同一对偏移），这里只管文案、字号颜色与显隐。
static func _其他属性行(窗口, 板: Control, 行号: int, 题: String, 值: String, 显示: bool) -> void:
	var 标签 := 板.get_node("第%d行题" % 行号) as Label
	标签.text = 题
	标签.visible = 显示
	窗口._configure_label(标签, 12, Color("#ff9100"))
	var 数值 := 板.get_node("第%d行值" % 行号) as Label
	数值.text = 值
	数值.visible = 显示
	窗口._configure_label(数值, 数值字号, Color("#00ff00"))


## `resizeCombatExtraAttrBg:508-515`：基准 = `secondAttributePane.height`（本工程 150）；
## 有附加行时 = 扩展板顶（= 第 3 行 y + 行距 = `首行 + 3×行距` = 87）
## + `scrollRect.height`（`:499` = 行距×行数 + 行高 + 4）+ 12。
static func 其他属性板高(附加行数: int) -> float:
	if 附加行数 <= 0:
		return 其他属性基准高
	return maxf(其他属性基准高, 其他属性首行 + 3.0 * 其他属性行距
		+ (其他属性行距 * float(附加行数) + 其他属性行高 + 4.0) + 12.0)


## `setupCombatExtraAttrCell:531` 那句 `"+ " + rate + " %"`。
## ⚠️ 字面 `%` 在 GDScript 的 `%` 运算符里必须写成 `%%`（§3.207 踩过一次）。
static func 其他属性值文案(数值: int) -> String:
	return "+ %d %%" % 数值


## 装备附加行 —— `collectCombatExtraAttrRows:354-418` 的搬运：
## 六类特性按 `4,5,1,2,6,7` 的**固定顺序**累加、只出 >0 的那几行，
## 每件最多 3 条（变身卡 4 条），且只算 `isCombatExtraRoleEquip:540-544` 认的部位。
static func 其他属性加成行(装备列表: Array) -> Array:
	var 合计 := {4: 0, 5: 0, 1: 0, 2: 0, 6: 0, 7: 0}
	for 一件 in 装备列表:
		if not (一件 is Dictionary):
			continue
		var 物品 := 一件 as Dictionary
		var 特性: Array = 物品.get("special_attributes", []) as Array
		if 特性.is_empty() or not 其他属性算这件(int(物品.get("equip_position", 0))):
			continue
		# `:376` `_loc5_ = isCombatExtraTransformCard(...) ? 4 : 3` —— **只取前几条**，
		# 第 4 条往后即使是这六类也不进账（原版特性栏最多 4 格，多的算"未生效"）。
		var 上限 := 4 if 其他属性是变身卡(String(物品.get("id", ""))) else 3
		for 序号 in mini(特性.size(), 上限):
			var 一条 = 特性[序号]
			if not (一条 is Dictionary):
				continue
			var 型 := int((一条 as Dictionary).get("attribute_type", 0))
			var 值 := int(float((一条 as Dictionary).get("attribute_value", 0)))
			if 合计.has(型) and 值 > 0:
				合计[型] += 值
	var 出: Array = []
	for 一条 in 其他属性加成序:
		var 累计 := int(合计[int(一条[0])])
		if 累计 > 0:
			出.append([String(一条[1]), 累计])
	return 出


## `isCombatExtraRoleEquip:540-544`：徽章(-22)…武器(-1) 这一段、宠物五槽(1..5)、羁绊(-50)。
## ⚠️ **不含**灵器(-23)/忍具(-24)/神器剑镜(-100/-101)/昆虫(-200..) —— 它们身上的特性不进这一板。
static func 其他属性算这件(位置: int) -> bool:
	return (位置 >= -22 and 位置 <= -1) or (位置 >= 1 and 位置 <= 5) or 位置 == -50


## `isCombatExtraTransformCard:534-538`：`int(id / 10000)` 是 121（人物变身位）或 205（宠物变身槽）。
## 物品 id 是**八位补零**，所以这个除数取到的是**前四位**：`01210441`（终极角都变身卡）→ 121 ✓，
## 而 `12100001`（千手柱间卡，材料）→ 1210 ✗ —— 原版认的就是穿在身上的那张卡，不是材料卡。
static func 其他属性是变身卡(id文本: String) -> bool:
	if not id文本.is_valid_int():
		return false
	var 前缀 := int(int(id文本) / 10000)
	return 前缀 == 121 or 前缀 == 205

## 7 个扩展子页**按需建**，不在 `人物窗口.tscn` 里预实例化。
##
## 为什么：这 7 个 .tscn 合计 **2.6 万行**（八门页 9121、写轮眼页 4789、柔拳页 2838、
## 结印页 2102、轮回六道页 1653…），而同一时刻只有一个可见。
## 原来它们在场景里是 7 个 `instance=ExtResource`，于是**一进游戏就把 7 页全解析 + 全实例化** ——
## 实测 `load(人物窗口.tscn)` 单项 **388 ms**，是启动总耗时（约 2.1 s）里最大的一笔。
## 挪到这里之后代价推迟到点开页签时；再改成**一页一建**（见 `确保子页`），
## 冷页的解析/实例化只在该页第一次被点开时付，角色页永远不付。
##
## ⚠️ 子页场景的**根节点名就已经是** `八门内容 / 手里剑内容 / …`（见各 .tscn），
##    所以 `instantiate()` 出来直接 `add_child` 即可，不用改名 —— 下面
##    `确保子页` 就是按这个名字取/建的。
## ⚠️ 场景里 3 个页有**位置覆盖**（`结印内容`/`寄坏之术内容`/`轮回六道内容` 都是
##    `offset_right = 421 / offset_bottom = 367`），预实例化时是写在实例节点上的，
##    改按需建以后要在这里补回来，否则那三页的尺寸会退回各自 .tscn 根节点的原值。
const 扩展子页表 := [
	["八门", "res://场景/界面/窗口/人物/页面/八门页.tscn", Vector2.ZERO],
	["手里剑", "res://场景/界面/窗口/人物/页面/手里剑页.tscn", Vector2.ZERO],
	["写轮眼", "res://场景/界面/窗口/人物/页面/写轮眼页.tscn", Vector2.ZERO],
	["结印", "res://场景/界面/窗口/人物/页面/结印页.tscn", Vector2(421.0, 367.0)],
	["柔拳", "res://场景/界面/窗口/人物/页面/柔拳页.tscn", Vector2.ZERO],
	["寄坏之术", "res://场景/界面/窗口/人物/页面/寄坏之术页.tscn", Vector2(421.0, 367.0)],
	["轮回六道", "res://场景/界面/窗口/人物/页面/轮回六道页.tscn", Vector2(421.0, 367.0)],
	## 宠物这一页**没有自己的 .tscn**：喂进来的是自己那扇的整页（`宠物窗口.tscn`，
	## 根节点叫 `原版宠物窗口内容`），所以这里要多带两栏 —— 第 4 栏 = 实例化之后改的名，
	## 第 5 栏 = 它在 `人物扩展页` 里的摆位。
	## ⚠ 那个摆位 `(−2, +3)` 是**两段换算叠出来的**，别当成"顺手挪一下"：
	##   ① `CharOtherWindow2.as:347-356` 给宠物页单独做了一块 422×366 的 `MPane_background`
	##      （就是 `人物扩展页` 这块面板），再把 `SimplePetWindow` 摆在 **`(-5,-27)`**；
	##   ② `SimplePetWindow` 的 pane 坐标 = 我这页的场景坐标 + `(3,30)`
	##      （推导与逐件摆位都在 `宠物窗口.gd` 的 `只读摆位` 上面那段注释里）。
	##   两段合起来 = 场景 + (3−5, 30−27) = **场景 + (−2,+3)**。
	["宠物", "res://场景/界面/窗口/宠物/宠物窗口.tscn", Vector2(421.0, 367.0), "宠物内容", Vector2(-2.0, 3.0)],
]

## ⚠️ 只建**当前要看的这一页**，不是 7 页一起建。
##
## 原来这里是 `if 面板.get_child_count() > 0: return` + 循环实例化 7 个 .tscn，
## 于是第一次切到「秘术」就一次性付掉 2.6 万行的解析/实例化（约 1.5 s 主线程卡顿）。
## 按页建之后，每个冷页的代价只在**第一次点开它**时付，已建过的页留着复用 ——
## 页面实例上有 `*_wired` / `kq_un` 这些「只接一次」的 meta 守卫，free 掉再重建会重复
## 接线，所以这里**不 free**，只把非当前页 `visible = false`。
static func 确保子页(面板: Panel, 页名: String) -> Control:
	var 实例名 := 子页实例名(页名)
	var 已有 := 面板.get_node_or_null(实例名) as Control
	if 已有 != null:
		return 已有
	for 项 in 扩展子页表:
		if String(项[0]) != 页名:
			continue
		var 包 := load(String(项[1])) as PackedScene
		if 包 == null:
			push_error("人物扩展子页加载失败：%s" % 项[1])
			return null
		var 子页 := 包.instantiate() as Control
		var 尺寸: Vector2 = 项[2]
		if 尺寸 != Vector2.ZERO:
			子页.offset_right = 尺寸.x
			子页.offset_bottom = 尺寸.y
		## 名字：其余 7 页的场景根节点本来就叫 `<页名>内容`，宠物那页的根叫
		## `原版宠物窗口内容` ⇒ 一律按第 4 栏（缺省 = `<页名>内容`）改名后**按普通子节点名**取，
		## 不再用 `%`（`%` 要求 `unique_name_in_owner` + owner，运行期 `add_child` 进来的不一定认）。
		子页.name = 实例名
		if 项.size() > 4:
			子页.position = 项[4]
		面板.add_child(子页)
		return 子页
	push_error("人物扩展子页表里没有「%s」" % 页名)
	return null


## 页名 → 实例化之后那个子节点的名字。其余 7 页 = `<页名>内容`（场景根节点本来就叫这个），
## 宠物页的根叫 `原版宠物窗口内容`，靠 `扩展子页表` 第 4 栏改名。
## ⚠ 取节点一律用这个普通名字，**别改回 `%`**：`%` 认的是 `unique_name_in_owner`，
##   运行期 `add_child` 进来的节点没登记进 owner 的唯一名表，`get_node("%X")` 直接报节点找不到。
static func 子页实例名(页名: String) -> String:
	for 项 in 扩展子页表:
		if String(项[0]) == 页名:
			return String(项[3]) if 项.size() > 3 else String(项[0]) + "内容"
	return 页名 + "内容"


static func 渲染扩展页(窗口, 面板: Panel, 属性: Dictionary, 页名: String,
		是别人 := false, 档: Dictionary = {}) -> void:
	## 「看别人」的只读档：非空 ⇒ 这一扇画的是对方那份档案（八门/寄坏两页仍吃这份形状）。
	var 只读档: Dictionary = 档 if 是别人 else {}
	面板.add_theme_stylebox_override("panel", 窗口._sub_panel_style())
	## 只有「寄坏之术」这一页放开裁剪（2026-10-27 用户报修③「昆虫强化的面板卡在人物属性面板里，
	## 下方的信息被遮挡」）：`人物扩展页` 是 `clip_contents = true` 的 Panel（`人物窗口.tscn:1955`），
	## 而强化弹窗 358×393 摆在 422×366 的面板里 ⇒ 底下 27 像素被裁，「开始强化」「自动强化到10并停止」
	## 两枚正好在那一条里（`开发工具/_探_寄坏强化面板.gd` 量的：扩展页下沿 236 / 弹窗下沿 263）。
	## 其余 6 页的控件都在框内 ⇒ 保持裁，别给以后的越界改动留后门。
	## （§3.298 把轮回技能提示框改挂 `遮罩` 层是另一条路：那是"框不能被裁"，这里是"页里的窗不能被裁"。
	## 这一页的**提示框**挂在祖先层 `原版人物窗口内容`，本来就不在本面板的裁层里，放不放开都盖得住弹窗。）
	面板.clip_contents = 页名 != "寄坏之术"
	# 先把已建出来的其它页收起来，再建当前页（get_children 只遍历实际存在的，不用 7 个名字硬取）
	for 子 in 面板.get_children():
		if 子 is Control:
			(子 as Control).visible = 子.name == String("%s内容" % 页名)
	var 页面 := 确保子页(面板, 页名)
	if 页面 == null:
		return
	## ⚠ 宠物这一页**不套 `统一页面字号`**：那套是给 7 页"为对方窗画的"页面兜底色用的，
	## 而这一页是从自己那扇的 `宠物窗口.tscn` 直接喂进来的，配色/字号已经按 `PetWindow.as`
	## 逐件烘进场景并过像素门 ⇒ 再套一层会把"场景没显式设过色"的那几枚冲成米白。
	if 页名 != "宠物":
		统一页面字号(窗口, 页面)
	match 页名:
		"宠物":
			## 这一页只给「看别人」那一扇用：空只读档说明调用方喂错了（比如拿自己的
			## `_session` 顶上来）⇒ 当场喊、不画，免得把"我的十只"演成"他的"。
			if 只读档.is_empty():
				push_error("宠物扩展页拿到空只读档：这一页只给「看别人」那一扇用")
			else:
				宠物页.渲染进(窗口, 页面, 他人宠物(窗口, 只读档))
		"八门":
			初始化八门页(窗口, 页面, 只读档)
		"手里剑":
			初始化手里剑页(窗口, 页面, 是别人, 档)
		"写轮眼":
			初始化写轮眼页(窗口, 页面, 是别人, 档)
		"结印":
			初始化结印页(窗口, 页面, 是别人, 档)
		"柔拳":
			初始化柔拳页(窗口, 页面, 是别人, 档)
		"寄坏之术":
			初始化寄坏之术页(窗口, 页面, 只读档)
		"轮回六道":
			初始化轮回六道页(窗口, 页面, 是别人, 档)


## 修炼回帧的**原地刷新**：只重跑那一族的 `初始化X页`，不重建页面、**不碰弹窗**。
##
## 原版就是这条口径 —— 每一族的管理器收到状态/结果帧后只调**那一个面板**的
## `updateView`：最直白的一条是 `JingMaiSource.as:429-437 onAnQi_updateZhuFu`，
## 收 `1817:1` 后直接 `windowMap[UIConfig.THROUGH_SHOU_LI_JIAN_WINDOW].updateXingYunValue(值)`，
## 窗口与弹窗都留着。而本工程原来把 `cultivation_changed` 挂在
## `功能窗口._refresh_current` 上 ⇒ 每来一帧就 `_render_page()` 把 `_content` 整棵
## free 重建（连 `手里剑页._exit_tree` 都会把搬到屏幕弹窗层的弹窗收掉）⇒
## 玩家点「突破瓶颈 / 开始提升」后**弹窗一闪就没**、幸运值/祝福条永远看不到涨
## （用户 2026-10-20 报修 2.1）。
##
## 返回 false = 现在没开着这一族页（不在人物页 / 不在那一子页 / 页还没建）⇒ 调用方走整页重绘。
static func 原地刷新族页(窗口, 族: String) -> bool:
	var 内容 := 窗口.get("_content") as Control
	if 内容 == null:
		return false
	var 页面 := 内容.get_node_or_null("原版人物窗口内容") as Control
	if 页面 == null:
		return false
	var 扩展 := 页面.get_node_or_null("人物扩展页") as Panel
	if 扩展 == null or not 扩展.visible:
		return false
	var 子页 := 扩展.get_node_or_null("%s内容" % 族) as Control
	if 子页 == null or not 子页.visible:
		return false
	# 只走自己那一扇（看别人不接实时帧，也不会走到这里，但参数照旧传 false/{}）
	match 族:
		"八门":
			初始化八门页(窗口, 子页)
		"手里剑":
			初始化手里剑页(窗口, 子页)
		"写轮眼":
			初始化写轮眼页(窗口, 子页)
		"结印":
			初始化结印页(窗口, 子页)
		"柔拳":
			初始化柔拳页(窗口, 子页)
		"寄坏之术":
			初始化寄坏之术页(窗口, 子页)
		"轮回六道":
			初始化轮回六道页(窗口, 子页)
		_:
			return false
	return true


## 这一页的数据源 —— 看自己 = 服务端推来的 `cultivation_states[族]`；
## 看别人 = 从 `58:4` 那一帧现拼的**同形状**字典。
## 原版干的就是这件事：`CharOtherWindow2.as:108/144/158/377/392` 把 `_data.rouquanState`、
## `_data.xielunyanStage/Count`、`_data.jieYinState/EatCount`、`_data.anqi*` 直接喂进
## `resetView/showInfo/updateView`，页面类**一模一样**、只是构造时传 `false`（`_isMy…`）。
## ⚠ 返回**空字典 = 那一帧还没到**（布局体检、以及开窗早于回帧两条路都会撞上）：
##   调用方据此**跳过推数**，让页面停在 `.tscn` 烘的默认态 —— 而不是拿「1 阶 / 0 熟练」
##   冒充一个还没看清的人（同 `渲染` 开头那条判据：页名分形态、不拿状态位凑）。
static func 页状态(窗口, 族: String, 是别人: bool, 档: Dictionary) -> Dictionary:
	if not 是别人:
		return 窗口._session.cultivation_states.get(族, {}) as Dictionary
	if 档.is_empty():
		return {}
	return 他人修练态(族, 档)


## 拼成与 `cultivation_states[族]` **逐键同形状**（`stage/level/master/ratio/count/open`）：
## 这五页的显示层只认这几个键，形状一错就是整页空白，所以照键名表拼、不猜。
## 键来自 `后端连接._他人尾巴入档`（下标 34..47 那几格，**本工程服务端排布**，
## 与 `CharacterFullInfo.as` 的原版序不同 —— 那张差异表就写在那张表的注释里）。
static func 他人修练态(族: String, 档: Dictionary) -> Dictionary:
	match 族:
		"手里剑":
			if not 档.has("手里剑阶"):
				return {}
			# `level` 是**本阶等级 1..4**（与服务端同族状态帧同口径，见 `手里剑页.应用状态` 那段）；
			# `open`（启用没启用）帧里**没有** ⇒ 按没启用画，checkbox 随后被 `只读闸` 摁死。
			return {"stage": int(档["手里剑阶"]), "level": int(档.get("手里剑级", 1)),
				"master": int(档.get("手里剑熟练", 0)), "ratio": int(档.get("手里剑触发", 0)),
				"open": false}
		"结印", "柔拳", "写轮眼", "轮回六道":
			var 阶键 := String("%s阶" % 族)
			if not 档.has(阶键):
				return {}
			return {"stage": int(档[阶键]), "count": int(档.get(String("%s进度" % 族), 0))}
	return {}


## 看别人时把这一页的**动作**全部摁住 —— 原版每块只读面板改的正是这一行：
##   柔拳 `RouQuanPanel.as:433-436`、结印 `JieYinPanel.as:356-359`、轮回 `LunHuiYanPanel.as:546-549`
##   三处都是 `if(!_isMy…) { _tiShengBtn.enabled = false; }`（钮留着、只是点不动）；
##   写轮眼 `TongshuWindow.as:491-496` 更狠，`exaltBtn.visible = false` **整枚藏掉**；
##   手里剑 `ShouLiJianPanel.as:140` + `:416-419` 关「启用」checkbox、`:383` 把「突破/提速」一起摁死。
## 阶段翻页那两枚**不摁**：原版只读面板照样让人翻着看每一阶的属性
## （`RouQuanPanel.as:365` 那份 `getRouQuanProps(_stage,_count)` 就是给"看别人"算的）。
## 路径相对**页面根**，与本工程 `.tscn` 里的节点名一致。
static func 只读闸(页面: Control, 摁住: Array, 藏起: Array = []) -> void:
	for 路径 in 摁住:
		var 钮 := 页面.get_node_or_null(String(路径)) as BaseButton
		if 钮 != null:
			钮.disabled = true
	for 路径 in 藏起:
		var 件 := 页面.get_node_or_null(String(路径)) as CanvasItem
		if 件 != null:
			件.visible = false

## ⚠️ **场景优先**：作者在 `.tscn` 里设好的 `font_color` / `font_size` /
## `custom_minimum_size` 一律让路，这里只补"场景没设过"的。
##
## 为什么：这个函数由 `渲染扩展页()` 调用，7 个扩展页（八门 / 手里剑 / 写轮眼 / 结印 /
## 柔拳 / 寄坏之术 / 轮回六道）**共用这一处**。一刀切版会把作者调好的配色全冲成
## 米白 `#f5ead6`、把 40x40 的小方钮撑成 57x22 顶出面板。
## 实测影响面很大：写轮眼 191 处、柔拳 105 处、寄坏 15 处、轮回六道 58 处 `font_color`
## **全是非白色**，也就是这四页的配色 100% 依赖"场景优先"这条。
##
## 覆盖发生在**宿主脚本**里，页面侧无法自救 —— 所以没有"只改 .tscn 就行"的解法。
## 反过来，它的作用域就只有那 7 个扩展页的子树，**不碰人物窗口自身任何节点**。
##
## ⚠️ 补的字号一律 **12**，不是 11（2026-10-17 巡检 #23）。原版这几页**没有任何一处小于 12**：
## `MLabel.initUI:218-223`、`TextArea2.createTf:77-82`、`MButton.init:148-155`、`MButton3:123-131` 全是
## `size=12 + font=COMMON_FONT(宋体)`，`MBar.labelFormat` 那几处**根本不设 size** ⇒ 吃 Flash 默认 12。
## 而 11 打不中宋体内嵌点阵 ⇒ 退回轮廓灰度抗锯齿 = **又小又虚又暗**（§3.184 第 1 条同族）。
static func 统一页面字号(窗口, 节点: Node) -> void:
	for 子节点 in 节点.get_children():
		if 子节点 is Label:
			var 标签 := 子节点 as Label
			# 场景里明确设过颜色/字号的（总览页那些黄/橙/绿、门说明的白），以场景为准。
			var 有色: Variant = 标签.get("theme_override_colors/font_color")
			var 有字: Variant = 标签.get("theme_override_font_sizes/font_size")
			if 有色 == null and 有字 == null:
				窗口._configure_label(标签, 12, Color("#f5ead6"))
			else:
				if 有色 == null:
					标签.add_theme_color_override("font_color", Color("#f5ead6"))
				if 有字 == null:
					标签.add_theme_font_size_override("font_size", 12)
		elif 子节点 is RichTextLabel:
			var 富文本 := 子节点 as RichTextLabel
			# 只补字号，不碰 default_color（正文颜色归场景/文案自己管）
			if 富文本.get("theme_override_font_sizes/normal_font_size") == null:
				富文本.add_theme_font_size_override("normal_font_size", 12)
		elif 子节点 is Button:
			var 按钮 := 子节点 as Button
			# 场景里写了 custom_minimum_size 的按钮（如弹窗里的 40x40 小方钮）以场景为准，
			# 不被统一成 57x22 —— 否则会变宽、顶出所在面板。
			var 有尺寸: Variant = 按钮.get("custom_minimum_size")
			if not 按钮.flat and (有尺寸 == null or (有尺寸 as Vector2) == Vector2.ZERO):
				窗口._configure_standard_button(按钮)
			elif 按钮.get("theme_override_font_sizes/font_size") == null:
				按钮.add_theme_font_size_override("font_size", 12)
		统一页面字号(窗口, 子节点)

## 八门页。页面本身（`场景/.../页面/八门页.tscn`）由**另一位开发者**重做过：
## 门按钮在 `门列表/按钮列` 下，每门各有一套 `穴位连线_<门>`、`八门人体图/门标_<门>/暗|亮`、
## `穴位面板/穴位图/穴位点层_<门>`。文案走 `脚本/界面/窗口/八门文案.gd`（取自 Flash 原版）。
static func 初始化八门页(窗口, 页面: Control, 只读档: Dictionary = {}) -> void:
	if 只读未接(只读档, "八门"):
		return
	# 页面自带的预览脚本在游戏内不生效（只在 F6 独立运行时接线），所以这里必须自己接。
	for 门名 in 八门名称:
		var 按钮 := 页面.get_node_or_null("门列表/按钮列/%s" % 门名) as Button
		if 按钮 == null:
			continue
		按钮.toggle_mode = true
		按钮.pressed.connect(更新八门页.bind(窗口, 页面, 门名))
	var 总览 := 页面.get_node_or_null("门列表/按钮列/总览") as Button
	if 总览 != null:
		总览.toggle_mode = true
		# 「总览」= 主页；它被按下时把记住的门清掉，否则回帧重建又会回到刚才那一门。
		# （原版 tabBar 的选中态常驻，见 `_八门选中门` 的注释。）
		总览.pressed.connect(func() -> void:
			窗口.set("_八门选中门", "")
			总览八门页(窗口, 页面, true))
	var 状态: Dictionary = 窗口._session.cultivation_states.get("八门", {})
	# ⚠️ 入口钮**只负责把弹窗打开**（原版 `JingMaiPanel.as:349-351` `throughHandler`
	#    → `JingMaiSource.showThroughWindow()`），开弹窗/搬到屏幕层/铺暗幕都在
	#    `突破瓶颈按钮.gd` 里，这里不能再接第二遍。
	#    2026-10-17 巡检 #8：原来这一行是 `突破.pressed.connect(发送修炼请求(…,"八门突破"))`
	#    ⇒ **点开弹窗的那一刻就把 1290:3 真发出去了**（玩家还没看数、还没点「突破瓶颈」，
	#    服务端就已经扣了 9 张神符 + 10000 精华），而弹窗里那颗钮反倒谁都没接。
	#    显隐**不在这里写** —— 见 `_刷突破入口钮`（唯一写手，本函数末尾切视图时统一算）。
	_接突破弹窗(窗口, 页面)
	填突破弹窗(窗口, 页面, 状态)
	# ⚠️⚠️ **这里绝对不能发包**：本函数每次渲染都会跑，而 `功能窗口._refresh_current` 挂在
	#    `会话.cultivation_changed` 上 ⇒ 发包 → 回帧 → 又渲染 → 又发包，**无限循环**，
	#    表现是提示刷屏（"八门统计请求已发送…"）＋**整页点不动**（2026-10-17 用户实测）。
	#    "进页拉一次数据"改挂在 `功能窗口._进页后拉数据()`（只在**切页**那一跳调）。
	_接八门穴位(窗口, 页面)
	刷八门穴位(窗口, 页面)
	# ⚠️ 默认停在**总览**（原版 `JingMaiPanel.initView:358` `tabBar.selectedIndex = 0`）。
	#    再往前一版是 `八门名称[clamp(状态.list_id,1,8) - 1]` —— 把统计帧的 `list_id`
	#    （**脉/阶** 0..4，见 `_current_mai_list_id`）当门序号用了；后来改成常量「开门」，
	#    2026-10-17 巡检 #11 把总览页的烘值换成真值之后，才敢跟原版对齐。
	#    选门仍然是玩家点门按钮的事（`更新八门页`）。
	# ⚠️ **但重建时要回到玩家刚才看的那一面**（2026-10-20 报修）：这一函数每次回帧都跑一遍，
	#    原来无条件 `总览` ⇒ 开通失败的结果帧一到，玩家从正在看的门被弹回总览（"返回主页"）。
	#    原版 tabBar 是常驻对象、选中门不会因为一次数据回包而复位。
	var 记住的门 := str(窗口.get("_八门选中门"))
	if 记住的门.is_empty() or not 八门名称.has(记住的门):
		总览八门页(窗口, 页面, true)
	else:
		更新八门页(窗口, 页面, 记住的门)
	# 开通穴道弹窗：原版是独立窗，数据回包不关它（失败时 `JingMaiSource.chongMaiFailHandler`
	# 还会 `ChongMaiWindow.update()` 重新 `showWindow`）。这里按窗口上记的开合态/选中点位复原。
	_恢复八门穴位弹窗(窗口, 页面)


## 页面重建后把「开通穴道」弹窗按窗口上记着的开合态与选中点位开回来。
static func _恢复八门穴位弹窗(窗口, 页面: Control) -> void:
	if not bool(窗口.get("_八门穴位弹窗开")):
		return
	var 选: Array = 窗口.get("_八门选中穴位") as Array
	if 选.size() < 3:
		return
	var 门序 := int(选[0])
	var 穴名 := String(选[2])
	if 门序 < 0 or 门序 >= 八门名称.size():
		return
	页面.set_meta("bamen_pick", 选.duplicate())
	var 层 := 页面.get_node_or_null("穴位面板/穴位图/穴位点层_%s" % 八门名称[门序])
	var 点: Node = 层.get_node_or_null("点_%s" % 穴名) if 层 != null else null
	if 点 != null and 点.has_method("打开弹窗"):
		点.call("打开弹窗")
	else:
		return
	填开通弹窗(窗口, 页面, 门序, 穴名)


## 入口钮「突破瓶颈」该不该亮 —— 原版 `JingMaiPanel.updateZongLanView:266`：
## `listId < JingMaiSource.MAX_MAI && totalExplodedPointCount >= totalPointCount && _isMyBaMen`。
## 第三条在本工程**恒真**：看别人时秘术/血继那几页整个禁掉（本文件 175-177 行），到不了八门页。
## ⚠️ 没收到统计帧时（`total_points` = 0）**不亮** —— 原版那一刻 `maiData` 也还是空。
static func 可突破(状态: Dictionary) -> bool:
	var 总穴位数 := int(状态.get("total_points", 0))
	var 已开穴位数 := int(状态.get("exploded_total", 0))
	return int(状态.get("list_id", 0)) < 八门文案.最大脉 and 总穴位数 > 0 and 已开穴位数 >= 总穴位数


## `Mai/info/levelup[<当前脉 + 1>]`（原版 `JingMaiSource.getTroughConfig:472-476`）
## = `{zq, prob, item:{id,count}}`。本工程那份表在 `数据/经脉.json`。满脉时越界 ⇒ 空字典。
static func 突破配置(状态: Dictionary) -> Dictionary:
	var 信息: Dictionary = (游戏数据表.取表("经脉").get("info", {}) as Dictionary)
	var 表: Dictionary = (信息.get("levelup", {}) as Dictionary)
	return (表.get(str(int(状态.get("list_id", 0)) + 1), {}) as Dictionary)


## 下一脉**整脉**的属性合计 —— 原版 `JingMaiSource.getTroughMaiString:356-391`：
## 把 `Mai/<脉+1>` 里**每一门的 `attr`/`value`** 和**该门每一个穴位的 `attr`/`value`**
## 按属性名累加（`for each` 两层，同名相加）。
static func 下一脉属性合计(脉: int) -> Dictionary:
	var 合计: Dictionary = {}
	var 条: Dictionary = (游戏数据表.取表("经脉").get(str(脉), {}) as Dictionary)
	for 门 in (条.get("mai", {}) as Dictionary).values():
		var 门条 := 门 as Dictionary
		_累加属性(合计, String(门条.get("attr", "")), int(门条.get("value", 0)))
		for 穴 in (门条.get("pts", {}) as Dictionary).values():
			var 穴条 := 穴 as Dictionary
			_累加属性(合计, String(穴条.get("attr", "")), int(穴条.get("value", 0)))
	return 合计


static func _累加属性(合计: Dictionary, 属性名: String, 值: int) -> void:
	if 属性名.is_empty():
		return
	合计[属性名] = int(合计.get(属性名, 0)) + 值


## ⚠️ 弹窗**打开后会被 `突破瓶颈按钮.gd` 搬到「屏幕弹窗层」**（原版它是屏幕级窗，搬完还居中＋铺暗幕），
## 之后 `页面.get_node("突破瓶颈弹窗")` 就取不到了 ⇒ 只能拿入口钮那个 `@export popup` 引用。
## 取不到时回退到页面里的原路径（还没开过时它就在家）。
static func _突破弹窗(页面: Control) -> Control:
	var 钮 := 页面.get_node_or_null("门列表/按钮列/突破瓶颈") as Button
	var 弹窗 := (钮.get("popup") as Control) if 钮 != null else null
	return 弹窗 if 弹窗 != null else 页面.get_node_or_null("突破瓶颈弹窗")


## 只接**弹窗里那颗「突破瓶颈按钮」**（原版发 1290:3 的唯一入口）。
## 同 `_接八门穴位`：页面实例复用 ⇒ meta 挡重复连接（键**必须 ASCII**）。
static func _接突破弹窗(窗口, 页面: Control) -> void:
	var 弹窗 := _突破弹窗(页面)
	if 弹窗 == null or 弹窗.has_meta("tupo_wired"):
		return
	弹窗.set_meta("tupo_wired", true)
	var 钮 := 弹窗.find_child("突破瓶颈按钮", true, false) as Button
	if 钮 == null:
		push_warning("突破瓶颈弹窗里找不到「突破瓶颈按钮」，突破发不出去")
		return
	钮.pressed.connect(突破瓶颈确认.bind(窗口, 弹窗))


## 原版 `ThroughAllMaiWindow.throughHandler:195-214` 就三支：
## ① 精华不够 ⇒ `CHONG_MAI_WINDOW_SORRY_JINGHUA_BUGOU`「很抱歉，你的精华不够！」；
## ② 神符不够 ⇒ `FAMILLY_MANAGER_SORRY_BUGOU`「很抱歉，您的%1不够！」（%1 = 道具名）；
## ③ 都够才 `requestMaiLevelUp()`（1290:3）**并立刻关窗**（`onCloseBtnClick(null)`）。
## ⚠️ 原版这里**没有**"穴位没开全"那道校验 —— 那条判据在入口钮的**显隐**上（`可突破`），
##   别在此补一遍（服务端 `_level_up_mai` 另有兜底，两边口径不同是有意的）。
static func 突破瓶颈确认(窗口, 弹窗: Control) -> void:
	var 状态: Dictionary = 窗口._session.cultivation_states.get("八门", {})
	var 配置 := 突破配置(状态)
	if 配置.is_empty():
		显示修炼说明(窗口, "八门已经达到最高境界。")
		return
	if int(窗口._session.player_stats.get("zq", 0)) < int(配置.get("zq", 0)):
		显示修炼说明(窗口, "很抱歉，你的精华不够！")
		return
	var 道具: Dictionary = 配置.get("item", {}) as Dictionary
	var 物品号 := int(道具.get("id", 0))
	if int(窗口._背包数量(物品号)) < int(道具.get("count", 0)):
		显示修炼说明(窗口, "很抱歉，您的%s不够！" % 游戏数据表.item_name(物品号))
		return
	发送修炼请求(窗口, "八门突破", [])
	if 弹窗.has_method("收起"):
		弹窗.call("收起")


## 突破弹窗整片文字/道具格刷成真值 —— 原版 `initView:160-193` + `updateView:216-228`。
## ⚠️ 场景里那"8张 / 10000 / 100% / 攻击：1040 防御：522…"是美术按**表八门**抄的示例值
##   （真值第一脉要 **9 张**），运行期整条覆盖（第二十二条）。
static func 填突破弹窗(窗口, 页面: Control, 状态: Dictionary) -> void:
	var 弹窗 := _突破弹窗(页面)
	if 弹窗 == null:
		return
	var 脉 := clampi(int(状态.get("list_id", 0)), 0, 八门文案.最大脉 - 1)
	var 配置 := 突破配置(状态)
	var 道具: Dictionary = 配置.get("item", {}) as Dictionary
	var 物品号 := int(道具.get("id", 0))
	var 需要数 := int(道具.get("count", 0))
	var 脉名 := String(八门文案.突破脉名[脉])
	_写文本(弹窗, "突破标题", String(八门文案.突破标题[脉]))
	# ① 块1：当前**已**提升的属性 = 统计帧的 `totalAttrGain`（后端 fields[4] 解析来的 `attrs`）。
	#   原版 `getCurrentMaiProps(maiData)`；没收到统计帧就按全 0，不拿示例数糊弄。
	var 当前行: Array = 八门文案.属性两行(状态.get("attrs", {}) as Dictionary)
	_写文本(弹窗, "总块/块1/介绍栏", 八门文案.已提升说明)
	_写文本(弹窗, "总块/块1/属性栏1", String(当前行[0]))
	_写文本(弹窗, "总块/块1/属性栏2", String(当前行[1]))
	# ② 块3：**下一脉**整脉合计（`getTroughMaiString(脉+1)`）＋ 该脉的层数奖励那段绿字。
	var 下一行: Array = 八门文案.属性两行(下一脉属性合计(脉 + 1))
	_写文本(弹窗, "总块/块3/滚动区/VBoxContainer/介绍栏", String(八门文案.突破开通说明[脉]))
	_写文本(弹窗, "总块/块3/滚动区/VBoxContainer/属性栏", "%s\n%s" % [String(下一行[0]), String(下一行[1])])
	var 奖励 := 弹窗.get_node_or_null("总块/块3/滚动区/VBoxContainer/说明栏") as Label
	if 奖励 != null:
		奖励.text = String(八门文案.突破打通奖励[脉])
		奖励.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART	# 原版那句 30 字一行，比这块（342px）宽，不折行会裁尾
	# ③ 消耗那两行 + 道具格（`SAY` 的 %2/%3/%5 全来自 `info.levelup[脉+1]`）。
	_写文本(弹窗, "总块/神符说明", 八门文案.突破消耗模板 % [
		脉名, 需要数, int(配置.get("zq", 0)), 脉名, int(配置.get("prob", 0))])
	# 道具名/图标查得到才覆盖（`item_name` 查不到会回落到 id，把"八门神符"写成 16000027 反而更糟）。
	if 物品号 > 0 and not 游戏数据表.item(物品号).is_empty():
		_写文本(弹窗, "总块/道具名称", 游戏数据表.item_name(物品号))
	var 框 := 弹窗.get_node_or_null("总块/道具框") as Control
	if 框 != null:
		var 持有 := int(窗口._背包数量(物品号)) if 物品号 > 0 else 0
		# 原版 `updateView:216-228`：持有 < 需要 ⇒ `applyGrayFilter()`（整格压灰）。
		框.modulate = Color(1, 1, 1) if 持有 >= 需要数 else Color(0.45, 0.45, 0.45)
		_写文本(框, "数量", str(持有))
		var 图 := 游戏数据表.item_icon(物品号) if 物品号 > 0 else null
		if 图 != null:
			for 子 in 框.get_children():
				if 子 is TextureRect:
					(子 as TextureRect).texture = 图
					break


static func _写文本(节点: Node, 路径: String, 文: String) -> void:
	var 标签 := 节点.get_node_or_null(路径) as Label
	if 标签 != null:
		标签.text = 文



## 当前停在哪个**扩展子页**（按两个页签下标算出来，不靠节点名）。
## 用途：`功能窗口._进页后拉数据()` 判断"现在是不是八门页"⇒ 决定要不要发那一发统计。
static func 当前子页名(窗口) -> String:
	var 组: Array = 子分页组[clampi(int(窗口._character_main_tab), 0, 子分页组.size() - 1)] as Array
	return String(组[clampi(int(窗口._character_sub_tab), 0, 组.size() - 1)])


## 穴位名 → **客户端点序下标**（= 发给服务端的 `point_id`）。
##
## 真值（2026-10-17 更正，§3.183）：**配置键序** —— 原版 `JingMaiSource.getMaiPointSource` 用
## `for each` 遍历 `pts`，AS3 对象的**数值键按升序**枚举 ⇒ `pointId` 就是配置键号，
## **开门第一枚 = `pts[0]` = 头维**（用户实机确认）。当年在 Ruffle 里实测到的是动态属性哈希序
## （第 0 枚＝攒竹）——那是**引擎实现细节**、不是原版真值，拿它当真值错了三天（第二十二条第 64 条）。
## 服务端那张 `MAI_POINT_ORDER_BY_COUNT` 已停用、`_mai_client_ordered_points` 走兜底 `sorted`（键升序）；
## 我们这张表由 `开发工具/导出八门点序.py` 按数值键序导进 `数据/经脉.json` 的 `_客户端点序`（两端同源）。
## 查不到返回 **-1** —— 调用方别把 -1 当 0 发出去（那会开通**别的**穴位，而服务端还会当成合法请求）。
static func 八门穴位下标(门名: String, 穴名: String) -> int:
	var 序: Array = (游戏数据表.取表("经脉").get("_客户端点序", {}) as Dictionary).get(门名, []) as Array
	return 序.find(穴名)


## 八门「开通穴道」那条链（2026-10-14 §3.162）：穴位点 → 弹窗 → 确认钮 → 协议。
## 原版 `ChongMaiWindow.as:272`：`requestMaiExplode(maiId, pointId, 勾选 ? 下拉.selectedIndex+1 : 0)`。
## ⚠️ **只接一次**：`初始化八门页` 每次切到这一页都跑一遍，而页面实例是复用的（同 手里剑页 那条注释）
##    ⇒ 不挡就会点一下发好几个包（meta 键**必须 ASCII**）。
static func _接八门穴位(窗口, 页面: Control) -> void:
	if 页面.has_meta("bamen_wired"):
		return
	页面.set_meta("bamen_wired", true)
	for 门序 in 八门名称.size():
		var 层 := 页面.get_node_or_null("穴位面板/穴位图/穴位点层_%s" % 八门名称[门序]) as Control
		if 层 == null:
			continue
		for 点 in 层.get_children():
			if not String(点.name).begins_with("点_"):
				continue
			var 穴位名 := String(点.name).trim_prefix("点_")
			# 悬停详情（原版 `PointItem.overHandler:112-117` → `updatePoint:284-293`；
			# 移开 `outHandler` → `clearPoint:245-250`）。纯显示、不发包 ⇒ 放在点序闸之前：
			# 就算这一枚跟点序表对不上，悬停也该看得到它自己的配置。
			点.mouse_entered.connect(func() -> void: 刷八门穴位详情(窗口, 页面, 门序, 穴位名))
			点.mouse_exited.connect(func() -> void: 清八门穴位详情(页面))
			var 下标 := 八门穴位下标(八门名称[门序], 穴位名)
			if 下标 < 0:
				continue		# 名字跟点序表对不上（改过美术/数据）⇒ 这一枚不接，宁可不发也不发错
			if 点.has_signal("点击"):
				# 穴位点自己会开弹窗、填穴名（`穴位点.gd:打开弹窗`）；我们只记"当前选的是哪一枚"。
					# ⚠️ meta 键**必须 ASCII**：写 `"八门选中"` 会被 `set_meta` 直接拒掉
				#    （`Invalid metadata identifier`），后续 `has_meta` 恒 false ⇒ 点了穴位也白点。
				#    本轮第三次撞见这条（§3.143 进度条、§3.64.4 清单）。
				点.connect("点击", func(名: String) -> void:
					# 记三样：门序 / 客户端点序下标 / **穴名**（穴名要留着，
					# 因为勾选与下拉一变就要按它重算「消耗与几率」）
					var 选 := [门序, 下标, String(名).trim_prefix("点_")]
					页面.set_meta("bamen_pick", 选)
					# 同一份记到窗口上：页面每次回包都重建，弹窗的开合与选中点位必须跨重建
					窗口.set("_八门穴位弹窗开", true)
					窗口.set("_八门选中穴位", 选)
					# 组件自己只填「穴名」；其余数值在这里填（弹窗里那些是**设计师烘的示例值**）
					填开通弹窗(窗口, 页面, 门序, String(名).trim_prefix("点_")))
	var 弹窗 := 页面.get_node_or_null("开通穴道弹窗") as Control
	if 弹窗 == null:
		return
	var 确认 := 弹窗.get_node_or_null("开通穴道按钮") as Button
	if 确认 == null:
		return
	# 关闭 = 玩家自己收起 ⇒ 跨重建的"开着"标记跟着清掉（弹窗脚本自己也会 visible=false）。
	var 关 := 弹窗.get_node_or_null("关闭按钮") as Button
	if 关 != null:
		关.pressed.connect(func() -> void:
			窗口.set("_八门穴位弹窗开", false)
			窗口.set("_八门选中穴位", []))
	# 勾选 / 下拉一变，消耗与几率那行要跟着重算（原版 `selectedTongRenHandler` 是两者的回调）
	var 勾 := 弹窗.get_node_or_null("使用八门灵符") as CheckBox
	var 拉 := 弹窗.get_node_or_null("数量下拉") as OptionButton
	if 勾 != null:
		勾.toggled.connect(func(_开: bool) -> void: _按选中重填(窗口, 页面))
	if 拉 != null:
		拉.item_selected.connect(func(_i: int) -> void: _按选中重填(窗口, 页面))
	确认.pressed.connect(func() -> void:
		if not 页面.has_meta("bamen_pick"):
			显示修炼说明(窗口, "请先点一下要开通的穴位")
			return
		var 选: Array = 页面.get_meta("bamen_pick") as Array
		# ⚠️ **越级拦截**（**按原版的口径，不是"严格按序"**）：
		#    原版 `ChongMaiWindow.chongMaiHandler:249-262` 判的是
		#    `pointId > getMaiSuccessPoint(maiId) + 1`，而 `getMaiSuccessPoint` 返回
		#    `explodedPointMap[maiId] - 1`（= **已开最后一枚的下标**，没开过是 -1）
		#    ⇒ 等价于 **`pointId > 已开数` 才拦**。
		#    ⇒ **已经开过的那几枚（`< 已开数`）不拦**（原版照样发出去，由服务端回话）；
		#      只有"跳过前面没开的、直接点后面的"才拦。
		#    我在 2026-10-17 第一版写成 `!= 已开数`，偏严 ⇒ 点**已开过**的也报"越级"（用户实测打回）。
		var 已开数 := int(((窗口._session.cultivation_states.get("八门", {}) as Dictionary)
			.get("exploded", {}) as Dictionary).get(int(选[0]), 0))
		if int(选[1]) > 已开数:
			显示修炼说明(窗口, "不能越级学习穴位！")
			return
		var 勾选 := 弹窗.get_node_or_null("使用八门灵符") as CheckBox
		var 下拉 := 弹窗.get_node_or_null("数量下拉") as OptionButton
		var 铜人 := 0
		if 勾选 != null and 勾选.button_pressed and 下拉 != null:
			铜人 = 下拉.selected + 1		# 原版 `_comboBox.selectedIndex + 1`（下拉项文字就是 1..9）
		发送修炼请求(窗口, "八门开通", [int(选[0]), int(选[1]), 铜人]))
	# 灵符格那枚「购买」= `ItemCaiLiaoBox.buyHandler:45-54`：不是买东西，是问服务端要
	# **这件材料的商城条目**（`REQUEST_CASH_ITEM_INFO`，回 1079 才弹购买窗）⇒ 走统一出口
	# `窗口.请求商城商品`（与扩容窗/提升材料格/手里剑同一跳）。
	# ⚠️ 页面实例复用（`_接八门穴位` 有 meta 闸），但弹窗里的按钮**只接一次**；这里再挡一层
	#    "已有连接就不接"，防止以后有人把 meta 闸挪走时点一下发两发。
	var 购 := 弹窗.get_node_or_null("购买") as Button
	if 购 != null:
		var 灵符号 := str(int((游戏数据表.取表("经脉").get("info", {}) as Dictionary).get("itemid", 0)))
		for 连接 in 购.pressed.get_connections():
			购.pressed.disconnect(连接["callable"])
		购.pressed.connect(func() -> void: 窗口.请求商城商品(灵符号))


## 取某个穴位的**配置**（原版 `JingMaiInfoData`：name / attr / value / zq / prob）。
## ⚠️ **按名字找**，不按下标 —— `八门穴位下标()` 给的是"客户端点序"，与配置里的 `pts` 键序
##    不是一回事（§3.162：配置里头维是第 0 个，点序表里第 0 个是攒竹）。
static func 取穴数据(窗口, 门序: int, 穴名: String) -> Dictionary:
	var 阶 := 0
	if 窗口._session != null:
		阶 = int((窗口._session.cultivation_states.get("八门", {}) as Dictionary).get("list_id", 0))
	var 阶条: Dictionary = (游戏数据表.取表("经脉").get(str(阶), {}) as Dictionary)
	var 门条: Dictionary = (阶条.get("mai", {}) as Dictionary).get(str(门序), {}) as Dictionary
	for _键 in (门条.get("pts", {}) as Dictionary):
		var 穴: Dictionary = (门条["pts"][_键] as Dictionary)
		if String(穴.get("name", "")) == 穴名:
			return 穴
	return {}


## 悬停某枚穴位 ⇒ 右下角三格写**这一枚**的配置（原版 `JingMaiPanel.updatePoint:284-293`：
## `_pointNameItem` = name、`_propItem` = getPropString(strengthProp, strengthValue)、
## `_zhenqiItem` = zhenqi）。⚠️ 三格都是**穴位级**（`pts/<穴>/attr|value|zq`），
## 门级 `mai/<门>/value` 只属于「修炼提示」那一行（`updateMai:314`）。
static func 刷八门穴位详情(窗口, 页面: Control, 门序: int, 穴名: String) -> void:
	var 穴 := 取穴数据(窗口, 门序, 穴名)
	if 穴.is_empty():
		return
	_写格子(页面, "穴位名称/值", 穴名)
	_写格子(页面, "提升属性/值", 八门文案.穴位加成(String(穴.get("attr", "")), int(穴.get("value", 0))))
	_写格子(页面, "所需精华/值", str(int(穴.get("zq", 0))))


## 鼠标离开穴位 / 切门 ⇒ 三格清成 " "（原版 `JingMaiPanel.clearPoint:245-250`）。
static func 清八门穴位详情(页面: Control) -> void:
	for 路 in ["穴位名称/值", "提升属性/值", "所需精华/值"]:
		_写格子(页面, 路, " ")


static func _写格子(页面: Control, 路: String, 文: String) -> void:
	var 标 := 页面.get_node_or_null(路) as Label
	if 标 != null:
		标.text = 文


## 勾选 / 下拉一变就按**当前选中的那个穴位**重算整张弹窗（原版 `selectedTongRenHandler` 是两者的回调）。
static func _按选中重填(窗口, 页面: Control) -> void:
	if not 页面.has_meta("bamen_pick"):
		return
	var 选: Array = 页面.get_meta("bamen_pick") as Array
	if 选.size() >= 3:
		填开通弹窗(窗口, 页面, int(选[0]), String(选[2]))


static func _写值(弹窗: Control, 行: String, 文: String) -> void:
	var 值 := 弹窗.get_node_or_null("%s/值框/值" % 行) as Label
	if 值 != null:
		值.text = 文


## 填「开通穴道」弹窗 —— 原版 `ChongMaiWindow.showWindow:76-114` + `selectedTongRenHandler:228-247`。
##
## ⚠️ 场景里那三行值 + 灵符数量是**设计师烘的示例**（"头维 / 生命+15 / 399746 / 999"），
##    运行时**没人填** ⇒ 玩家看到的全是死数。2026-10-16 用户报的"八门开通还没实装"就是它：
##    弹窗能开、确认也接线了（§3.162），但**里面的数一动不动**。
## 数据全来自 `数据/经脉.json`（`mai/<门>/pts/<穴位>` = name/attr/value/zq/prob；
## 顶层 `info.itemprob` = 每个八门灵符加的成功率）+ 会话当前的 `zq`。
static func 填开通弹窗(窗口, 页面: Control, 门序: int, 穴名: String) -> void:
	var 弹窗 := 页面.get_node_or_null("开通穴道弹窗") as Control
	if 弹窗 == null:
		return
	var 穴 := 取穴数据(窗口, 门序, 穴名)
	if 穴.is_empty():
		push_warning("八门：经脉表里找不到穴位「%s」（门序 %d）" % [穴名, 门序])
		return
	_写值(弹窗, "行1", 穴名)		# `_pointItem` = param1.name
	_写值(弹窗, "行2", 八门文案.穴位加成(String(穴.get("attr", "")), int(穴.get("value", 0))))	# `_gainItem`
	var 精华 := int(窗口._session.player_stats.get("zq", 0)) if 窗口._session != null else 0
	_写值(弹窗, "行3", str(精华))		# `_zhenQiItem` = stats.zq
	var 阶 := 0
	if 窗口._session != null:
		阶 = int((窗口._session.cultivation_states.get("八门", {}) as Dictionary).get("list_id", 0))
	var 提示 := 弹窗.get_node_or_null("提示文字") as RichTextLabel
	if 提示 != null:
		# `showWindow:102`：普通阶只 PROMPT_1；里•八门（1）追加 PROMPT_2；其余追加 PROMPT_3
		var 文: String = 八门文案.开通提示[0]
		if 阶 == 1:
			文 += "
" + 八门文案.开通提示[1]
		elif 阶 > 1:
			文 += "
" + 八门文案.开通提示[2]
		提示.text = "[color=#ff9100]%s[/color]" % 文
	# `selectedTongRenHandler:228-247`：勾了灵符 ⇒ 几率 = **本穴基础几率** + 个数 × 每个的加成
	var 消耗 := int(穴.get("zq", 0))
	var 几率 := int(穴.get("prob", 0))
	var 勾选 := 弹窗.get_node_or_null("使用八门灵符") as CheckBox
	var 下拉 := 弹窗.get_node_or_null("数量下拉") as OptionButton
	if 勾选 != null and 勾选.button_pressed and 下拉 != null:
		几率 += (下拉.selected + 1) * 每个灵符加成()
	var 区 := 弹窗.get_node_or_null("消耗与几率") as RichTextLabel
	if 区 != null:
		区.text = 八门文案.消耗与几率模板.replace("A", "#ff0000" if 精华 < 消耗 else "#00ff00")			.replace("B", str(消耗)).replace("C", str(几率))
	_填灵符格(窗口, 弹窗)


## `JingMaiSource.getJingMaiTongRenRatio()` —— 每个八门灵符加的成功率（%）。
## 真值 = 经脉表顶层 `info.itemprob`（**别写死 5**）。
static func 每个灵符加成() -> int:
	return int((游戏数据表.取表("经脉").get("info", {}) as Dictionary).get("itemprob", 0))


## `showWindow:88-90`：灵符格显示八门铜人的图与**背包里的数量**（`getJingMaiTongRen()` + `updateCell`）。
static func _填灵符格(窗口, 弹窗: Control) -> void:
	var 格 := 弹窗.get_node_or_null("灵符格") as Control
	if 格 == null or 窗口._session == null:
		return
	var 表: Dictionary = 游戏数据表.取表("经脉").get("info", {}) as Dictionary
	var 物 := str(int(表.get("itemid", 0)))
	if 物.is_empty() or 物 == "0":
		return
	var 图 := 格.get_node_or_null("格/灵符图标") as TextureRect
	if 图 != null:
		图.texture = 游戏数据表.item_icon(物)
	var 名 := 格.get_node_or_null("名") as Label
	if 名 != null:
		var 物名 := 游戏数据表.item_name(物)
		if not 物名.is_empty():
			名.text = 物名
	var 数 := 格.get_node_or_null("格/数量") as Label
	if 数 != null:
		var 有 := 0
		for 物品 in 窗口._session.inventory:
			if String((物品 as Dictionary).get("id", "")) == 物:
				有 = int((物品 as Dictionary).get("quantity", 0))
				break
		数.text = str(有) if 有 > 0 else ""


## 按服务端统计帧的 `exploded`（每门已开穴位数）点亮穴位：**按客户端点序的前 N 枚**。
## 服务端就是"必须按顺序开通"（`_attempt_mai_point`：`point_id != 已开数` 直接拒并提示），
## 所以"点亮的必是前 N 枚"这条与它一致。
static func 刷八门穴位(窗口, 页面: Control) -> void:
	var 状态: Dictionary = 窗口._session.cultivation_states.get("八门", {})
	var 已开: Dictionary = 状态.get("exploded", {}) as Dictionary
	for 门序 in 八门名称.size():
		var 层 := 页面.get_node_or_null("穴位面板/穴位图/穴位点层_%s" % 八门名称[门序]) as Control
		if 层 == null:
			continue
		var 本门已开 := int(已开.get(门序, 0))
		for 点 in 层.get_children():
			if not String(点.name).begins_with("点_") or not 点.has_method("刷新"):
				continue		# `刷新()` 是 `穴位点.gd` 的记号（它才有 `已开启` 那个属性）
			var 下标 := 八门穴位下标(八门名称[门序], String(点.name).trim_prefix("点_"))
			点.set("已开启", 下标 >= 0 and 下标 < 本门已开)


## 穴位名 → **客户端点序下标**（= 发给服务端的 `point_id`）。
##
## 真值：服务端 `_mai_client_ordered_points` 按穴位数查 `MAI_POINT_ORDER_BY_COUNT`
## （原版 Ruffle 按 AS3 对象属性序**实测**出来的顺序，**与配置里的键序不同**；查不到才退回按键排序）。
## 我们这张表是由 `开发工具/导出八门点序.py` 从服务端源码导进 `数据/经脉.json` 的 `_客户端点序`。
## 查不到返回 **-1** —— 调用方别把 -1 当 0 发出去（那会开通**别的**穴位，而服务端还会当成合法请求）。


## 按服务端统计帧的 `exploded`（每门已开穴位数）点亮穴位：**按客户端点序的前 N 枚**。
## 服务端就是"必须按顺序开通"（`_attempt_mai_point`：`point_id != 已开数` 直接拒并提示），
## 所以"点亮的必是前 N 枚"这条与它一致。


## 切到总览视图（原版 `JingMaiPanel.showZongLanView()`，页面里的 `设置总览视图` 负责具体显隐）。
## 原版在 `showZongLanView(true)` 里紧跟着就调 `updateZongLanView()`（:114）⇒ 填数也挂这里。
static func 总览八门页(窗口, 页面: Control, 总览: bool) -> void:
	if 页面.has_method("设置总览视图"):
		页面.call("设置总览视图", 总览)
	_刷突破入口钮(窗口, 页面, 总览)
	if 总览:
		# 原版是同一个 `tabBar`：选中「总览」那一格，8 个门按钮自然全弹起来。
		# 咱这边门按钮是 8 枚独立 toggle，`设置总览视图` 只管显隐、不管它们，
		# 不弹就会「总览页和按住的门同时亮」。
		for 名称 in 八门名称:
			var 门钮 := 页面.get_node_or_null("门列表/按钮列/%s" % 名称) as Button
			if 门钮 != null:
				门钮.button_pressed = false
		填总览页(窗口, 页面)


## 总览页那四块的内容 —— 原版 `JingMaiPanel.updateZongLanView:252-282` +
## `JingMaiSource.getZongLanString:299-315`，数据全是统计帧（`1290:3`）存进会话的那几项。
##
## ⚠️ 场景里这九处**都烘了值**（进度 `0/181`、属性 `攻击：1299 防御：653…`、
##   说明文字还是抄表时手打的），看着像已经接好了 —— 承第二十二条，运行期必须整条覆盖。
##   2026-10-17 巡检 #11：没这一函数 ⇒ 总览永远显示设计师的示例数，玩家穴位开满了进度条还是 0/181。
static func 填总览页(窗口, 页面: Control) -> void:
	var 状态: Dictionary = 窗口._session.cultivation_states.get("八门", {})
	var 总穴位数 := int(状态.get("total_points", 0))
	var 已开穴位数 := int(状态.get("exploded_total", 0))
	var 条 := 页面.get_node_or_null("总览页/内容面板/块1/进度条") as ProgressBar
	if 条 != null:
		# `JingMaiPanel.as:31` 的 `_zongLanProgress` 是 MBar ⇒ 0.5s 补间；`0/0` 按 `_isShowBar`
		# 画**满条**（原版"还没数据"不画空条），文案仍然照实写 `0/0`。
		进度条补间.灌值(条, float(已开穴位数), float(总穴位数), [已开穴位数, 总穴位数])
	var 数值 := 页面.get_node_or_null("总览页/内容面板/块1/进度条/进度数值") as Label
	if 数值 != null:
		数值.text = "%d/%d" % [已开穴位数, 总穴位数]
	var 行: Array = 八门文案.属性两行(状态.get("attrs", {}) as Dictionary)
	_写文本(页面, "总览页/内容面板/块1/说明行", 八门文案.已提升说明)
	_写文本(页面, "总览页/内容面板/块1/属性行1", String(行[0]))
	_写文本(页面, "总览页/内容面板/块1/属性行2", String(行[1]))
	_写文本(页面, "总览页/内容面板/块2/说明1", 八门文案.总览说明一)
	_写文本(页面, "总览页/内容面板/块2/说明2", 八门文案.总览说明二)
	_写文本(页面, "总览页/内容面板/块3/说明1", "\n".join(八门文案.总览散开))
	_写文本(页面, "总览页/内容面板/块3/说明2",
		八门文案.总览分享模板 % int(状态.get("shared_exp_count", 0))
		+ "\n" + (八门文案.总览经验模板 % int(状态.get("shared_exp", 0))))
	var 图 := 页面.get_node_or_null("总览页/内容面板/块4/八卦图") as TextureRect
	if 图 != null:
		图.texture = load(八门文案.八卦图路径(int(状态.get("list_id", 0)))) as Texture2D


## 入口钮「突破瓶颈」的**唯一写手**（原版把它拆成两件事）：
## · `showZongLanView:110-120`：这颗钮**只挂在总览视图**上（`addChild` / `removeChild`）；
## · `updateZongLanView:266`：挂上之后再按 `listId < MAX_MAI && 已开穴位 >= 总穴位` 决定亮不亮。
## 页面脚本 `设置总览视图` 只会无脑 `visible = 总览`（它还得服务 F6 预览，拿不到会话），
## 所以判据必须在**它之后**补这一刀。2026-10-17 巡检 #8 实测：写在 `初始化八门页` 里
## （切视图**之前**）会被末尾那次 `更新八门页(… "开门")` 冲掉 ⇒ 62/62 满穴位钮还是不亮。
static func _刷突破入口钮(窗口, 页面: Control, 总览: bool) -> void:
	var 钮 := 页面.get_node_or_null("门列表/按钮列/突破瓶颈") as Button
	if 钮 == null or 窗口._session == null:
		return
	var 状态: Dictionary = 窗口._session.cultivation_states.get("八门", {})
	钮.visible = 总览 and 可突破(状态)


## 切门。节点路径按重做后的页面；文案统一走 `八门文案.gd`（别再各写一套）。
static func 更新八门页(窗口, 页面: Control, 门名: String) -> void:
	窗口.set("_八门选中门", 门名)		# 跨重建记住（见 `_八门选中门`）
	for 名称 in 八门名称:
		var 钮 := 页面.get_node_or_null("门列表/按钮列/%s" % 名称) as Button
		if 钮 != null:
			钮.button_pressed = 名称 == 门名
		var 线 := 页面.get_node_or_null("穴位面板/穴位连线_%s" % 名称) as Line2D
		if 线 != null:
			线.visible = 名称 == 门名
		var 点层 := 页面.get_node_or_null("穴位面板/穴位图/穴位点层_%s" % 名称)
		if 点层 != null:
			(点层 as CanvasItem).visible = 名称 == 门名
		var 标 := 页面.get_node_or_null("八门人体图/门标_%s" % 名称)
		if 标 != null:
			var 暗 := 标.get_node_or_null("暗") as CanvasItem
			var 亮 := 标.get_node_or_null("亮") as CanvasItem
			if 暗 != null:
				暗.visible = 名称 != 门名
			if 亮 != null:
				亮.visible = 名称 == 门名
	var 图 := 页面.get_node_or_null("穴位面板/穴位图") as TextureRect
	if 图 != null and 八门穴位图.has(门名):
		图.texture = load(String(八门穴位图[门名])) as Texture2D
	# 文案（两处与「总览页」互斥，先切回门内容视图）
	总览八门页(窗口, 页面, false)
	var 说明 := 页面.get_node_or_null("门说明面板/门说明") as Label
	if 说明 != null:
		说明.text = 八门文案.门说明(门名)
	var 阶 := 0
	if 窗口._session != null:
		阶 = int((窗口._session.cultivation_states.get("八门", {}) as Dictionary).get("list_id", 0))
	var 提示 := 页面.get_node_or_null("修炼提示面板/修炼提示")
	if 提示 != null:
		提示.set("text", 八门文案.修炼提示(门名, 阶))
	# 右下角三格是**穴位级**详情（悬停才有值，`updatePoint`）——
	# 门级 `mai/<门>/value` 只属于上面「修炼提示」那一行，别再写进「提升属性」。
	清八门穴位详情(页面)

## 手里剑页 —— **页面、交互、数值表都由另一位开发者完成**（2026-09-25 接入）。
## 五个脚本在 `素材/界面/原版窗口/人物/手里剑/脚本/`：
##   `手里剑页.gd`（本体：7 阶翻页预览、当前信息、把两个弹窗搬到屏幕层）、
##   `手里剑数据.gd`（7 阶数值表，解自 GameData 的 `Etc.AnQi`）、
##   `箭头按钮交互.gd`（与写轮眼页同一套）、`修炼提速弹窗.gd` / `手里剑突破瓶颈弹窗.gd`。
##
## ⚠️ **他的脚本自己接线** —— 翻页箭头、提升/突破按钮、启用复选框、两个弹窗的
##    `提速请求`/`突破请求`，全在 `手里剑页.gd:_ready()` 里接了。
##    宿主**只做三件事**：① 把服务端状态推给 `应用状态()`；② 把他那五条信号接成协议请求；
##    ③ 把「失败后自动继续」的勾选态回灌给弹窗（真值在 `功能窗口` 上，见下面那节）。
##    ⚠️ 旧代码那样去 `get_node("当前信息/勾选标记")`、`get_node("详情面板/修炼进度")`
##    **会直接报错** —— 那些是**旧页面**的节点名，新页面里没有（§3.24 结印页同款坑）。
##
## 协议（对着真值核过，**不是自造**）：`CultivationRequestAction` 在服务端
## `fake_flash_server.py:1620` 是 `STATUS_OR_TRAIN=0 / STAGE_UP_OR_AUTO=1 / SPEED_UP=2`，
## 原版 `AnQiProcessor.as` 发的也是 `0 / 2 / 1` —— 与 `发送修炼请求` 里那三条一致。
static func 初始化手里剑页(窗口, 页面: Control, 是别人 := false, 档: Dictionary = {}) -> void:
	var 状态: Dictionary = 页状态(窗口, "手里剑", 是别人, 档)
	# 攻击力只用于「攻击能力」那一行的换算（原版按人物攻击力的百分比算）。
	# 看别人时传的是**他的** atk —— 原版 `CharOtherWindow2.as:376` 那句
	# `shouLiJianPane.otherAtk = this._data.atk`，页里 `:492` 再 `_isMy ? FightValue.atk : otherAtk`。
	var 攻击力 := int(档.get("攻击", 0)) if 是别人 else int(窗口._session.player_stats.get("attack", 0))
	if not 状态.is_empty():
		页面.call("应用状态", 状态, 攻击力)
	# 特殊能力图标的悬停提示：原版对**别人**的手里剑也挂（`SkillCell.as:222-228` 不分敌我，
	# 载荷就是面板自己 `attack.skills` 那几枚 id）⇒ 放在只读 return 之前，跟轮回那条同位置。
	接手里剑技能提示(窗口, 页面)
	if 是别人:
		# 一条信号都不接：接了就是**点他的页、发我的包**（启用/提速/突破/购买全是我这条命）。
		只读闸(页面, ["当前信息/启用复选框", "详情面板/提升速度", "详情面板/突破瓶颈"])
		return
	# ⚠️ **只能接一次**：`渲染扩展页()` 是拿 `面板.get_node("手里剑内容")` 取页面的，
	#    页面实例**复用**，而本函数每次切到这个页都会再调一遍 —— 不挡住就会**重复 connect**，
	#    点一下发好几个包。（旧代码是直接 `button.pressed.connect(...)`，本来就有这个隐患。）
	# ⚠️ meta 键**必须 ASCII**（Godot 的 `set_meta` 不收中文名，见 memory）。
	# 勾选态**每次渲染都回灌**（所以在 `shuriken_wired` 那道 guard 之前）：真值存在
	# `功能窗口._手里剑失败继续` 上，页面重绘制换新弹窗件，不回灌就一帧一丢。
	页面.call("设置失败继续", 窗口._手里剑失败继续)
	if 页面.has_meta("shuriken_wired"):
		return
	页面.set_meta("shuriken_wired", true)
	页面.connect("启用切换", func(新值: bool): 发送修炼请求(窗口, "手里剑启用", [新值]))
	页面.connect("提速请求", func(全部: bool): 发送修炼请求(窗口, "手里剑提速", [全部]))
	# 突破那一跳走 `手里剑点突破`（`toPoHandler` 四道预检 + 发包），
	# 不是裸 `发送修炼请求` —— 少了预检，「失败后自动继续」就成了无界循环（见上面那节）。
	页面.connect("突破请求", func(): 手里剑点突破(窗口))
	# 「购买升阶物品」原版不买东西，只发一条 `REQUEST_CASH_ITEM_INFO`（`ThroughShouLiJianWindow.as:372-381`）
	# ⇒ 走 `请求商城商品` 这条**统一出口**（与扩容窗/材料格/改名同一跳，回包 1079 才弹购买窗）。
	页面.connect("购买请求", func(物品id: String): 窗口.请求商城商品(物品id))
	页面.connect("失败继续切换", func(已勾: bool): 窗口.手里剑失败继续切换(已勾))


## ── 手里剑「开始突破瓶颈」——————————————————————————————————————————
## 原版语言表里那五句（`en_US$message_properties.as`，逐字烘在这里，运行期不许 import 2.2.3）：
## · `THROUGH_SHOULIJIAN_NOTICE_2` → 下一阶配置**不存在**（`toPoHandler:221`）；
## · `THROUGH_SHOULIJIAN_NOTICE_1` → `isShouLiJianFull == false`（`:195`）；
## · `UNION_QUITE_SORRY_NOT_COIN_YOU` → 金币不够（`:200`）；
## · `EQUIP_STRENGTH_FAIL_PROMPT_2[0]` 填 `[2]`「查克拉精华」→ 精华不够（`:205`）；
## · `CHONG_MAI_WINDOW_SORRY_WUPIN_BUGOU` 填物品名 → 材料不够（`:212`）。
## `%1` 是原版语言表的占位符 ⇒ 一律 `.replace`（GDScript 的 `%` 只认格式符，§3.205）。
const 手里剑文案 := {
	"满阶": "该手里剑已达到最高阶，无需进行突破操作！",
	"未到瓶颈": "尚未达到修炼瓶颈的手里剑，无法进行突破操作！",
	"金币不足": "对不起，你的金币不足",
	"精华不足": "很抱歉，你的查克拉精华不够",
	"材料不足": "很抱歉，你的背包中没有足够的%1！",
}


## 跳一发突破 = 原版 `toPoHandler:185-223`：**四道客户端预检全过才发** `requestAnQi_StageUp()`，
## 每道不过就一句 `addNotice` + `return`。顺序逐字照 AS3（`:193` 瓶颈 → `:198` 金币 →
## `:203` 精华 → `:208` 材料）；外层两支也照：下一阶配置**没有** ⇒ `:221` 那句「已达到最高阶」，
## 配置有但 `stageUp` 空 ⇒ 原版**静默不发包、连提示都没有**（`:191` 那个 if 没有 else）。
##
## ⚠️ 这四道预检是 #85「失败后自动继续」的**前提**，不是顺手补的：不预检就重试，
##   材料耗尽后服务端仍会回 `1817:3:0` 失败帧 ⇒ 客户端 900ms 后再发一发，**无限循环**、
##   每发刷一句「很抱歉，进阶失败！」。原版的循环之所以自然停，就是因为缺材料那一发
##   **根本不发出去**，也就没有下一帧。
static func 手里剑突破一跳(窗口) -> void:
	var 状态: Dictionary = 窗口._session.cultivation_states.get("手里剑", {})
	var 阶 := clampi(int(状态.get("stage", 1)), 1, 7)
	var 下 := 手里剑数据.取阶(阶 + 1)
	if 下.is_empty():
		显示修炼说明(窗口, String(手里剑文案.满阶))
		return
	var 上: Dictionary = 下.get("up", {})
	if 上.is_empty():
		return
	# 预检 1 = `JingMaiSource.isShouLiJianFull:153-156` → `isFull:492-509`：
	# **本阶**等级 `>= 4` 且熟练度 `>= levels[4].master_max`。
	# ⚠️ 等级取回帧里那一位**本阶等级 1..4**（原版 `shouLiJianLevel` 存的就是 `onAnQi_updateStatus:412`
	#   的 `param2`），不是页面上显示的累计等级（`shouLiJianRealLevel = 4*(stage-1)+level`）。
	#   `master_max` 原版从表里取，服务端 `1817:0` 第 8 位就是同一个数 ⇒ 优先读帧、没帧回退表值。
	var 本级 := int(状态.get("level", 1)) >= 手里剑数据.每阶最大等级
	var 熟练够 := int(状态.get("master", 0)) >= int(状态.get("master_max", 手里剑数据.熟练度上限))
	if not 本级 or not 熟练够:
		显示修炼说明(窗口, String(手里剑文案.未到瓶颈))
		return
	if int(上["金币"]) > 窗口._金币():
		显示修炼说明(窗口, String(手里剑文案.金币不足))
		return
	if int(上["精华"]) > int(窗口._session.player_stats.get("zq", 0)):
		显示修炼说明(窗口, String(手里剑文案.精华不足))
		return
	if int(上["数量"]) > 窗口._背包数量(int(上["物品id"])):
		# 原版 `:210`：`!hasOwnProperty("fakeItemId") || isBagExistItem(fakeItemId) < 1`
		# ⇒ 背包里有「替身」（手里剑神符）就顶得上；表里 4 阶起才有 `替身id`，1..3 阶那个键是 0 = 没有。
		var 替身 := int(上.get("替身id", 0))
		if 替身 <= 0 or 窗口._背包数量(替身) < 1:
			显示修炼说明(窗口, String(手里剑文案.材料不足).replace("%1", String(上["物品名"])))
			return
	发送修炼请求(窗口, "手里剑突破", [])


## 点「开始突破瓶颈」= 原版 `toPoHandler:185-223` 那四道预检 + 发包。
##
## ⚠️ **有意偏离**：原版这枚钮挂 `isDelay = true`（`ThroughShouLiJianWindow.as:343`；
##   `MButton3.as:625-636` 在 capture 优先级 1000 上挂 `delayClickHandler`，`:568-579` 把
##   1000ms 内的第二次点击 `stopImmediatePropagation` 吃掉）。本工程原先照搬成
##   `_宠物按钮节流("手里剑突破")`，用户 2026-10-31 报「连续点没有用，点击 cd 停顿太长，
##   应该跟其他突破境界一样丝滑」⇒ 撤掉。原版写轮眼/柔拳/轮回六道/结印/八门那几颗突破钮
##   本来都**没有** isDelay，本工程也是直接发 ⇒ 撤掉后本页与其他突破流程一致。
##   连续发的多包由服务端按阶处理，客户端预检仍是花钱的唯一闸口（见 `手里剑突破一跳`）。
static func 手里剑点突破(窗口) -> void:
	手里剑突破一跳(窗口)


## 那扇突破弹窗**还在屏幕上亮着吗** —— 「失败后自动继续」那一发重试的落点前置。
## 原版它是 `windowMap` 里缓存的独立顶层窗：只要没关就一直亮着，循环自然活着。
## 我们这边页面重绘会把它一起 `queue_free`（`手里剑页._exit_tree`）⇒ 玩家看不见这扇窗了，
## 那种情况下不再往下烧钱（**有意偏离** `onCloseBtnClick:94-98` 的"关窗不 clearTimeout"，§3.264）。
static func 手里剑弹窗还亮着(窗口) -> bool:
	var 层 := (窗口.get_tree().root as Node).get_node_or_null("屏幕弹窗层") as CanvasLayer
	if 层 == null:
		return false
	var 弹 := 层.get_node_or_null("手里剑突破瓶颈弹窗") as Control
	return 弹 != null and 弹.visible


## 结印页 —— **页面与动画由另一位开发者完成**，脚本三个都在
## `素材/界面/原版窗口/人物/结印/脚本/`：
##   `结印切换.gd`（12 个印的点击切换、选中框/默认框/数值面板显隐）、
##   `提升结印阶数弹窗滑动动画.gd`（弹窗滑入滑出 + 12 阶熟练度上限表 + `刷新熟练度()`）、
##   `结印指针跟随.gd`（指针按现实时间指向对应的印）。
## 交接说明见素材目录内的同页开发文档。
##
## ⚠️ **他的脚本自己接线** —— 弹窗的两条触发写在**场景的 `[connection]`** 里
##    （`提升结印 → open_popup`、`关闭按钮 → _on_close_button_pressed`），
##    12 个印的点击也由 `结印切换.gd` 自己在 `_ready()` 里接。
##    所以这里**不抢他那两条**，只在同一条 `pressed` 上**加记开合状态**的一笔。
##
## 宿主做的四件事：
##   ① 服务端状态推给 `刷新熟练度(阶段, 当前值)`、`指向阶段(阶段)`；
##   ② 弹窗的**开合跨重建保留**（见下面的 ⚠️）；
##   ③ 「开始提升 / 自动提升」按原版接（`结印手动一跳` / `结印点自动`）；
##   ④ 自动态的钮文字跟着 `窗口._结印自动提升` 走（自动提升 ↔ 停止提升）。
##
## ⚠️ 旧版本这里引用的是**旧页面**的节点名（`印式按钮/印式NN`、`阶段说明`、
##    顶层 `生命`/`攻击`、`帮助`），新页面里**全都不存在**——照旧写会直接报错（§3.24）。
##
## ⚠️ **每发一帧就是一次整页重建**：`功能窗口._render_page()` free 掉 `_content` 的子树，
##    他的 `_ready()` 起手又把弹窗写成「收起 + 隐藏」。而自动提升**每一跳都回来一帧状态**
##    ⇒ 不接回来的话弹窗每 0.8 秒闪没一次，练到升阶为止一直在闪（2026-10-17 巡检 #12）。
##    开合记在**窗口**上（页面实例上的东西活不过一次刷新），重建时按它直接落位、**不重播滑入**。
static func 初始化结印页(窗口, 页面: Control, 是别人 := false, 档: Dictionary = {}) -> void:
	var 状态: Dictionary = 页状态(窗口, "结印", 是别人, 档)
	if 是别人 and 状态.is_empty():
		# 空 = 那一帧还没到（看别人且档为空）：不推数、不接线，只把动作钮摁住。
		# ⚠ 这个早退**只对别人那扇成立** —— 自己那扇在首帧 2318 之前也得把入口接上，
		#   否则「提升结印」点不开（原版没这问题：它的弹窗本来就归管理器常驻）。
		只读闸(页面, ["提升结印"])
		return
	var 当前阶段 := clampi(int(状态.get("stage", 1)), 1, 12)
	var 数量 := int(状态.get("count", 0))
	页面.set_meta("stage", 当前阶段)
	## 上下文挂在**页面**上（ASCII meta 键）而不是闭包里：`渲染扩展页()` 每次切页都会重跑，
	## 页面实例**复用**，闭包会带着上一个人的数字不放（同 `shuriken_wired` 那条口径）。
	页面.set_meta("jy_stage", 当前阶段)
	页面.set_meta("jy_count", 数量)
	页面.set_meta("jy_readonly", 是别人)
	_刷新结印熟练度(页面, 当前阶段, 数量)
	_刷结印置灰(窗口, 页面, 当前阶段)
	## 亮**他那一阶**的那枚印 + 显示对应的数值面板（`resetView` → `onJieYin_updateStatus`）。
	## ⚠ 先把上面几条 meta 写好再调 `选印`：它会当场发 `选中变了`，那条处理要读 meta 算数值。
	_接结印选中信号(页面)
	if 页面.has_method("选印"):
		页面.call("选印", 当前阶段)
	_刷结印数值(页面, 当前阶段, 数量, 当前阶段)
	## ⚠ 指针例外：原版只读窗的指针用的仍是**我自己**的阶段（`JieYinPanel.onComplete:287`），
	##   照抄 AS3 —— 只读档也一样指向自己的当前阶段。
	_指向结印阶段(页面, clampi(int(窗口._session.cultivation_states
			.get("结印", {}).get("stage", 1)), 1, 12))
	if 是别人:
		# 原版 `JieYinPanel.as:356-359`：只读时只摁住 `_tiShengBtn` 这一枚，
		# 十二个印的点击照旧（那只是切选中框、不发请求）。
		只读闸(页面, ["提升结印"])
		return
	var 弹窗 := 页面.get_node_or_null("提升结印阶数弹窗") as Control
	if 弹窗 == null:
		return
	if 窗口._结印弹窗开着 and 弹窗.has_method("直接展开"):
		弹窗.call("直接展开")
	# 开合状态由他场景里那两条触发**之外**再记一笔（两条都留着，各干各的）
	var 入口 := 页面.get_node_or_null("提升结印") as Button
	if 入口 != null:
		入口.pressed.connect(func() -> void: 窗口._结印弹窗开着 = true)
	var 关闭 := 弹窗.get_node_or_null("关闭按钮") as Button
	if 关闭 != null:
		关闭.pressed.connect(func() -> void: 窗口._结印弹窗开着 = false)
	# 每次都是**新页面新按钮**（`渲染` 里 `人物场景.instantiate()`），所以连一次就够，
	# 不需要 dis/connect 那套防重复。
	var 开始 := 弹窗.get_node_or_null("开始提升按钮") as Button
	if 开始 != null:
		开始.pressed.connect(func() -> void: 结印手动一跳(窗口))
	var 自动 := 弹窗.get_node_or_null("自动提升按钮") as Button
	if 自动 != null:
		自动.text = 结印文案.按钮停止 if 窗口._结印自动提升 else 结印文案.按钮自动
		自动.pressed.connect(func() -> void: 结印点自动(窗口))


## 跳一次结印训练 = 原版 `JieYinTiShengWindow.tiShengJieYin(是否自动)`（`:89-108`），三条出口逐字对齐：
##   · 满阶 / 阶段号不在 1..12 ⇒ **直接 return**（`!_cfg || !JieYinManager.canTiSheng`）；
##   · 精华够 ⇒ 发 **byte 0**（`requestJieYin_EatUp`）。
##     ⚠️ 自动提升**不是**"服务端一次吞光精华"：byte 1 那条 `eatUpAutoConsumeAllZq` 在原版
##     全工程没有一处 UI 调用（`Client.as:8558`），自动 = 客户端每 0.8 秒**再发一发 byte 0**。
##   · 精华不够 ⇒ 自动态发 `ROUQUAN_TISHENG_PROMPT`（带物品名）**并停掉自动**；
##     手动态只发 `EQUIP_STRENGTH_FAIL_PROMPT_2_1`（`param1=false` 那一支，没有 clearTimeOut）。
static func 结印一跳(窗口, 自动: bool) -> void:
	var 状态: Dictionary = 窗口._session.cultivation_states.get("结印", {})
	if not 结印可提升(int(状态.get("stage", 1)), int(状态.get("count", 0))):
		return
	if 结印精华够(窗口, 状态):
		发送修炼请求(窗口, "结印提升", [])
		return
	# 占位符是原版语言表的 `%1`，而 GDScript 的 `%` 只认格式符（`"…%1不够" % "精华"` 直接报
	# `String formatting error: unsupported format character`）⇒ 一律 `.replace`，全工程同一条口径。
	显示修炼说明(窗口, (结印文案.自动不够 if 自动 else 结印文案.手动不够).replace("%1", 结印文案.精华名))
	if 自动:
		窗口.停结印自动()


## 「开始提升」= 原版 `tiShengHandler:213-217`：**先 `clearTimeOut()`**（把自动停掉）再手动跳一次。
## 这正是确认正文里那条停止条件 3「尝试手动提升操作」。
static func 结印手动一跳(窗口) -> void:
	窗口.停结印自动()
	结印一跳(窗口, false)


## 「自动提升 / 停止提升」= 原版 `autoTiShengHandler:68-87` 的三岔：
##   · 已经在自动（`_autoTiShengBtn.selected`）⇒ `clearTimeOut()` 停；
##   · 没在自动、但**精华不够** ⇒ 只发一句 `JIEYIN_TISHENG_PROMPT`，**连确认都不弹**；
##   · 否则弹 `FamillyPopUpWindow`（`JIEYIN_AUTO_TISHENG_PROMPT`）二次确认，
##     确认了才走 `sureToAutoTiSheng:205-211`（换钮文字 + 立刻跳第一下）。
static func 结印点自动(窗口) -> void:
	if 窗口._结印自动提升:
		窗口.停结印自动()
		return
	var 状态: Dictionary = 窗口._session.cultivation_states.get("结印", {})
	if not 结印精华够(窗口, 状态):
		显示修炼说明(窗口, 结印文案.点自动时不够)
		return
	var 遮罩 := 窗口._overlay as Control
	if 遮罩 == null:
		窗口.起结印自动()		# 拿不到遮罩也别为了"确认"把功能吞掉（同快捷键窗的口径）
		return
	确认弹.弹消息(遮罩, 结印文案.自动确认正文, func(码: int) -> void:
		if 码 == 1:
			窗口.起结印自动())


## 原版 `JieYinManager.getJieYinProps(…, canTiSheng=true)` 收尾那两句（`:113-158`）：
## 阶段不在 1..12 ⇒ 没得练；**12 阶且熟练度已到本阶上限** ⇒ 满阶，也没得练。


## 原版 `canTiSheng():61` 比的是 `API.dataCenter.stats.zq >= _cfg.needZq`，
## 而 `_cfg` = `updateView:198` 取的 **当前阶段**那一档（`stage + jieYinStage`，**不是**下一阶 ——
## 与写轮眼/柔拳那三族 `stage<当前阶+1>` 的口径不一样，别抄串了）。
static func 结印精华够(窗口, 状态: Dictionary) -> bool:
	var 需 := int(结印阶段配置(int(状态.get("stage", 1))).get("needZq", 0))
	return int(窗口._session.player_stats.get("zq", 0)) >= 需


## `Etc.JieYin.stages.stage<阶>.stageUp`（`数据/原版杂项.json`）；缺段 ⇒ 空字典。
static func 结印阶段配置(阶: int) -> Dictionary:
	var 族: Dictionary = 游戏数据表.取表("原版杂项").get("JieYin", {}) as Dictionary
	var 阶段表: Dictionary = 族.get("stages", {}) as Dictionary
	return (阶段表.get("stage%d" % 阶, {}) as Dictionary).get("stageUp", {}) as Dictionary


## ── 结印数值表（`数据/原版杂项.json` 的 `JieYin` 段 = GameData `Etc.JieYin`）──────────
## AS3 每次 `updateProp()` 现场从 `ImgUtil.getImg(ImgType.Etc,"JieYin")` 取
## （`JieYinPanel.as:307`、`JieYinManager.as:128`），本工程对应这张导出表。
## ⚠ **自己读文件、不走 `GAME_DATA` 自动加载**：离线门是 `extends SceneTree` 脚本，
##    自动加载在那种模式下**根本不实例化** ⇒ 走单例会在门里当场 `Null` 崩，
##    而崩在只读分支上正是最难发现的那种红（`测试/他人人物窗回归测试.gd` 就跑在这条路上）。
static var _结印表缓存: Dictionary = {}


static func 结印表() -> Dictionary:
	if _结印表缓存.is_empty():
		var 文 := FileAccess.get_file_as_string("res://数据/原版杂项.json")
		var 全: Variant = JSON.parse_string(文)
		if 全 == null:
			push_error("读不到 res://数据/原版杂项.json 的 JieYin 段 ⇒ 结印数值面板只能留烘焙的 0/上限")
			return {}
		_结印表缓存 = (全 as Dictionary).get("JieYin", {}) as Dictionary
	return _结印表缓存


static func 结印阶段(阶: int) -> Dictionary:
	return (结印表().get("stages", {}) as Dictionary).get("stage%d" % 阶, {}) as Dictionary


static func 结印阶段上限(阶: int) -> int:
	return int(((结印阶段(阶).get("stageUp", {}) as Dictionary)).get("needPointCnt", 0))


static func _结印属性(阶: int, 类型: String) -> int:
	for 项 in (结印阶段(阶).get("attrs", {}) as Dictionary).values():
		if String((项 as Dictionary).get("type", "")) == 类型:
			return int((项 as Dictionary).get("value", 0))
	return 0


## 原版 `JieYinManager.getJieYinProps:145` 那条插值（逐字）：
##   `value = 上一阶值 + (本阶值 − 上一阶值) × 进度 / 本阶上限`
## 上一阶（`stage{阶-1}`）取不到 ⇒ `prev = 0`（`:140-143` 那个 if）。
static func 结印插值(阶: int, 进度: int, 类型: String) -> float:
	if 阶 < 1 or 阶 > 12:
		return 0.0
	var 上限 := maxi(1, 结印阶段上限(阶))
	var 本 := float(_结印属性(阶, 类型))
	var 上 := float(_结印属性(阶 - 1, 类型))
	return 上 + (本 - 上) * float(进度) / float(上限)


## 原版 `JieYinManager.getJieYinProps:149-156` 那条「可提升」：
## **不查熟练度够不够**，只有「阶越界」和「已到 12 阶且进度正好等于上限」两种假。
## （`canTiSheng` 是普通 var，全文件只有这三处赋值 ⇒ 别照直觉加条件。）
static func 结印可提升(阶: int, 进度: int) -> bool:
	if 阶 < 1 or 阶 > 12:
		return false
	return not (阶 == 12 and 进度 == 结印阶段上限(12))


## 类型名 → `[进度条节点名, 数值标签节点名, 标签前缀]`。
## 前缀与节点名都照 `.tscn` 里作者烘焙的那份（`结印页.tscn:171-250`：
## `生命 / 生命值 / "生命 0/900"`），**不是自造**；四类属性名 `maxhp/maxmp/atk/def`
## 出自同一张配置表的 `attrs[*].type`。
const 结印条位 := {
	"maxhp": ["生命", "生命值", "生命"],
	"maxmp": ["查克拉", "查克拉值", "查克拉"],
	"atk": ["攻击", "攻击值", "攻击"],
	"def": ["防御", "防御值", "防御"],
}


## 原版 `JieYinPanel.updateProp:302-340`：按**选中那一阶**的配置逐条画四根条，
## 「达成」= 他的插值（且要 `他的阶 >= 选中阶`，`:321`），「上限」= 该阶配置值。
static func _刷结印数值(页面: Control, 他的阶: int, 他的进度: int, 选中阶: int) -> void:
	var 容器 := 页面.get_node_or_null("印式按钮/印%d/数值容器" % 选中阶) as Control
	if 容器 == null:
		push_error("结印页缺 印式按钮/印%d/数值容器 ⇒ 数值面板刷不动" % 选中阶)
		return
	## **换面板 = 直落**：原版四根条是常驻 MBar（`JieYinPanel.as:156-168 createBar`），
	## 换选中阶只是给同一根条 `setData`，从不从 0 起算；本工程按印拆成各自一套条
	## （`结印页.tscn` 里 12 个 `数值容器`），换印换的是**一根从没写过的条**（烘的 0）
	## ⇒ 第一次露脸必须当帧坐到真值，否则从 0 扫过去（用户 2026-11-01 报修）。
	## 同一个面板里数值真的变了，才走原来的 0.5s 补间（`当前 → 新值`）。
	var 换面板 := int(页面.get_meta("jy_shown_stage", 0)) != 选中阶
	页面.set_meta("jy_shown_stage", 选中阶)
	for 项 in (结印阶段(选中阶).get("attrs", {}) as Dictionary).values():
		var 类型 := String((项 as Dictionary).get("type", ""))
		var 条名: Array = 结印条位.get(类型, []) as Array
		if 条名.is_empty():
			continue
		var 条 := 容器.get_node_or_null(String(条名[0])) as ProgressBar
		var 标 := 容器.get_node_or_null(String(条名[1])) as Label
		var 上限 := int((项 as Dictionary).get("value", 0))
		var 达成 := 0
		if 他的阶 >= 选中阶:
			达成 = int(round(结印插值(他的阶, 他的进度, 类型)))
		if 条 != null:
			条.min_value = 0.0
			# 原版这四根是 MBar（`JieYinPanel.createBar:502-514` → `updateProp:302-340` 的 `setData`）
			# ⇒ 0.5s 补间、同数据早退（§3.243）；直写会和同页别的条"一个在爬一个在跳"。
			if 换面板:
				进度条补间.直灌(条, float(clampi(达成, 0, 上限)), float(maxi(1, 上限)), [达成, 上限])
			else:
				进度条补间.灌值(条, float(clampi(达成, 0, 上限)), float(maxi(1, 上限)), [达成, 上限])
		if 标 != null:
			标.text = "%s %d/%d" % [String(条名[2]), 达成, 上限]


## 原版 `updateProp:341-359` 那颗「提升」钮的三档 + 只读那条。
## 文案两个键都在语言表里，逐字抄：`JIEYIN_TISHENGBTN_NAME`「结印训练」/
## `ACTIVITY_COMPELETE_TEXT`「已完成」。⚠ 场景里烘焙的是「提升结印」——
## **原版画面上没有这四个字**，运行期由这里覆盖成语言表原文（门 ⑳ 钉住）。
static func _刷结印提升钮(页面: Control, 他的阶: int, 选中阶: int, 只读: bool) -> void:
	var 钮 := 页面.get_node_or_null("提升结印") as Button
	if 钮 == null:
		push_error("结印页缺「提升结印」那颗钮 ⇒ 三档文案/可用态没处落")
		return
	钮.text = "已完成" if 选中阶 < 他的阶 else "结印训练"
	钮.disabled = 只读 or 选中阶 != 他的阶 or not 结印可提升(他的阶,
			int(页面.get_meta("jy_count", 0)))


## 十二枚印点下去只换显示（原版 `clickJieYinBtnHandler:113-124` → `setStage` → `updateProp`），
## **不发任何请求**；数值面板与那颗钮跟着选中那一阶重算。
static func _接结印选中信号(页面: Control) -> void:
	if not 页面.has_signal("选中变了") or 页面.has_meta("jieyin_wired"):
		return
	页面.set_meta("jieyin_wired", true)
	页面.connect("选中变了", func(选中阶: int):
		_刷结印数值(页面, int(页面.get_meta("jy_stage", 1)), int(页面.get_meta("jy_count", 0)), 选中阶)
		_刷结印提升钮(页面, int(页面.get_meta("jy_stage", 1)), 选中阶, bool(页面.get_meta("jy_readonly", false))))



## 让指针指向**当前阶段**。
##
## ⚠️ 他的 `结印指针跟随.gd` 原本让指针跟**现实时钟**走（12 点→印1、11 点→印12），
##    那是**原版没有的行为**。原版只有一种驱动：`JieYinPanel.as:460`
##    `zhizhen.rotation = (阶段 - 1) * 30 + 90`，由服务端推的结印 buff 触发
##    （`JieYinManager.onJieYin_showBuffEffect → onJieYin_updateZhiZhen`）。
##    页面上点某个印（`setStage()`）**只换选中框与属性面板，不动指针**。
static func _指向结印阶段(页面: Control, 阶段: int) -> void:
	var 针 := 页面.get_node_or_null("结印阵/时间指针/结印指针")
	if 针 != null and 针.has_method("指向阶段"):
		针.call("指向阶段", 阶段)


## 把服务端推来的结印阶段/熟练度交给他的弹窗脚本去画（上限表在他那边）。
static func _刷新结印熟练度(页面: Control, 阶段: int, 当前值: int) -> void:
	var 弹窗 := 页面.get_node_or_null("提升结印阶数弹窗")
	if 弹窗 != null and 弹窗.has_method("刷新熟练度"):
		弹窗.call("刷新熟练度", 阶段, 当前值)


## 未完成的印置灰（用户 2026-10-27 报修「把角色面板里的结印，也改成未完成的印是灰色」）。
## 真值 `JieYinPanel.as:475-500 updateButtonState`：逐枚 `index < _stage ⇒ filters = []`、
##   否则 `filters = [StyleUtil.getGrayFilter()]` —— **印号 > 当前阶的灰；当前阶那枚不灰**
##   （`_loc2_ < this._stage` 把 `== 阶` 留在彩色侧，原版靠 `bg.glow` 亮着它表达"正在这一阶"）。
## 滤镜套在**整个 btn MC** 上 = 这侧格子的「默认手势框 / 选中手势框 / 印式NN」三件可视件；
##   **数值容器不灰** —— 原版底部四根 MBar（`createBar:502-514`，这侧对应数值容器）本就不在
##   按钮里，从没被 filter 过。`StyleUtil.as:25-29` 的矩阵与 `禁用灰度.gdshader` 逐系数相同。
## 看别人同一条：`CharOtherWindow2.as:392 resetView → onJieYin_updateStatus:217-236 →
##   updateButtonState`；只读那扇只摁「提升」钮（`JieYinPanel.as:356-359`），**格子的灰跟着
##   他的阶走**。自己这扇 `页状态` 恒有值（缺省 stage 1 ⇒ 印2..12 灰）。
## ⚠ 数据没到**一格都不灰** —— 原版 `:479` 的守卫 `if (buttons[_stage - 1])`：初值 `_stage = 0`
##   时 `buttons[-1] = null` ⇒ 整段跳过。移植侧对应「别人的档为空 ⇒ `初始化结印页` 已早退」。
static func _刷结印置灰(窗口, 页面: Control, 阶段: int) -> void:
	var 区 := 页面.get_node_or_null("印式按钮") as Control
	if 区 == null:
		push_error("结印页缺「印式按钮」区 ⇒ 置灰没处落")
		return
	# 无类型 `窗口` ⇒ 返回值必须写死类型（同 :3043 昆虫材料格那次 parse error）
	var 灰: ShaderMaterial = 窗口.禁用灰度材质()
	for 印号 in 区.get_child_count():
		var 格 := 区.get_child(印号) as Control
		if 格 == null:
			continue
		var 该灰 := (印号 + 1) > 阶段
		for 子 in 格.get_children():
			# 只灰贴图件；数值容器（Control）与别的下挂物不动（原版 bars 不灰）
			if not (子 is TextureRect or 子 is TextureButton):
				continue
			(子 as CanvasItem).material = 灰 if 该灰 else null


## 写轮眼页 —— **页面与动画由另一位开发者完成**（`写轮眼切换_修正版.gd`：11 只瞳孔、
## RotateFade 切换、轮回眼圆形裁切 shader），交接文档在
## 素材目录内的同页开发文档。
##
## ⚠️ **他的脚本在 `_ready()` 里自己接线**（按钮 / 翻页 / 页码 / 提升弹窗 / 轴心校正），
## 末尾还写死一句 `_切换阶段(0)`。所以这边**不要**再去接那些按钮（重复接会触发两次动画，
## 他自己在 `_接线提升阶数弹窗()` 里也专门防了这件事）。我们只做两件他做不了的：
##  ① 把**服务端**的阶段推给他（`_切换阶段`）；
##  ② 把「开始提升」按钮接到**协议**上。
static func 初始化写轮眼页(窗口, 页面: Control, 是别人 := false, 档: Dictionary = {}) -> void:
	var 状态: Dictionary = 页状态(窗口, "写轮眼", 是别人, 档)
	if 是别人 and 状态.is_empty():
		只读闸(页面, [], ["提升写轮眼阶数"])
		return
	# 服务端的 `stage` 是 1 起算，他的 `_切换阶段` 收 0 起算的下标。
	var 阶 := clampi(int(状态.get("stage", 1)), 1, 写轮眼阶段.size())
	## ⚠ **只在服务端那一档真的变了、或这一页刚被藏起来过**才把页签跳过去。
	##   以前这里每来一帧就无条件 `_切换阶段` ⇒ 玩家翻到「六勾玉轮回眼」看两眼，
	##   后台一条 1821 祝福值帧就把他拽回第 1 档（用户 10-25 报"切换到其他阶段待会会自动回到最初阶段"）。
	##   原版不会这样：`TongshuWindow.updateView:180-183` 那句 `if (btnArr[stage-1] != curBtn) setTab(...)`
	##   只在**开窗/喂数据**那一趟走，帧的实时入口是 `setBarData/setCurrentStage`，不动页签。
	var 上次: int = int(页面.get_meta("xy_pushed_stage", -1))
	if 上次 != 阶:
		切写轮眼阶段(页面, 阶)
		页面.set_meta("xy_pushed_stage", 阶)
	if not bool(页面.get_meta("xy_hide_hooked", false)):
		页面.set_meta("xy_hide_hooked", true)
		# 藏起来（切走页签 / 关窗）⇒ 抹掉这个记忆，下次进来重新对齐到服务端那一档
		页面.visibility_changed.connect(func() -> void:
			if not 页面.visible:
				页面.set_meta("xy_pushed_stage", -1))
	# 每阶那几根属性条（用户 2026-10-21 报修 2.1：用了精魄、属性涨了，条子一动不动 ——
	# 这条链以前**压根没接**，场景里 `0/200` 那种烘死的示例字从来没人覆盖过）。
	填修炼进度条(页面, "阶段，数值名称切换区", "XieLunYan", 写轮眼阶段.size(), 状态)
	if 是别人:
		# 原版这枚不是"摁住"而是**整枚藏**（`TongshuWindow.as:491-496 setExaltBtnEnbled`：
		# `exaltBtn.visible = false` 且顺带把 `fulfillTextField` 也关掉）。
		# 怪名那颗**照接**：原版 readOnly 只管这枚提升钮，说明文字里的【怪名】链接没动过。
		只读闸(页面, [], ["提升写轮眼阶数"])
	else:
		接提升弹窗(窗口, 页面, "提升写轮眼阶数弹窗", "提升写轮眼阶数", "写轮眼提升", 状态, "XieLunYan")
	_接写轮眼怪名(窗口, 页面)


## 每阶「提升说明」里那枚**绿字【怪名】按钮**在原版是可点的：
## `StructuredText.as:465` ⇒ `UI.as:760-776 qusetClickText(2, mobid, mapid)`
## （停托管、`lockAutoMobId/MapId`、`CharacterHandler.as:849 MovePlayerToMob`：
## 怪在本图 ⇒ `pathFind` 到最近那只；不在本图 ⇒ 先 `MovePlayerToMap` 再寻）。
##
## 数据出处不是 `BossWang` —— 那是 `getOneMobPostion` 取不到 MapObject 时的**兜底**、
## 而且只给 mapid。写轮眼页的 mobid/mapid 由 `TongshuWindow.as:589` 直接取
## `StringTool.getXielunyanFromType` 即 `Etc.XieLunYan.stageN.levelUp.mobid/mapid`，
## 这张表已在 `数据/原版杂项.json`（`stage1..12`）。⚠ 旧注释那条"缺 BossWang 刷新点表"
## 是**假前提**（§3.212）。
##
## 阶段号按 `阶段，数值名称切换区` 的**容器次序**取（1 起算，与数据表 / 服务端 stage 同序）——
## 不按节点名匹配：第 11 个容器叫「轮回血轮眼」，数据里叫「轮回写轮眼」。
## ⚠ **只接一次**：这一页的实例是复用的，每次切页都会重跑 `初始化写轮眼页`。
static func _接写轮眼怪名(窗口, 页面: Control) -> void:
	var 区 := 页面.get_node_or_null("属性面板/阶段，数值名称切换区") as Control
	if 区 == null:
		return
	var 杂项 := 游戏数据表.取表("原版杂项") as Dictionary
	var 眼表 := 杂项.get("XieLunYan", {}) as Dictionary
	for 钮 in 页面.find_children("【叛忍喽啰】", "Button", true, false):
		var 按钮 := 钮 as Button
		# 文案烘在场景里（逐阶不同，由 `人物秘术页回归测试` 第⑨条回表核对），这里只照抄。
		按钮.tooltip_text = "原版点这里会自动寻路到 %s" % 按钮.text
		if not 按钮.pressed.get_connections().is_empty():
			continue
		var 层 := 按钮.get_parent()
		while 层 != null and 层.get_parent() != 区:
			层 = 层.get_parent()
		var 阶 := (区.get_children().find(层) if 层 != null else -1) + 1
		var 升级: Dictionary = ((眼表.get("stage%d" % 阶, {}) as Dictionary).get("levelUp", {}) as Dictionary) if 阶 > 0 else {}
		var 怪号 := int(升级.get("mobid", 0))
		var 图号 := int(升级.get("mapid", 0))
		if 怪号 > 0 and 图号 > 0:
			# 点的那一刻再找小地图：页面可能先于地图/宿主存在（无头门、异常路径）。
			按钮.pressed.connect(_寻路到怪.bind(窗口, 图号, 怪号, 按钮.text))
		else:
			按钮.pressed.connect(显示修炼说明.bind(窗口, "%s：没有这一阶的怪物数据" % 按钮.text))


## 绿字怪名的唯一出口。原版 `qusetClickText(2, …)`：停挂机 + `MovePlayerToMob(mapid, mobid)`；
## 本工程落到 `小地图面板.走向怪`（同图取最近活口、异图走传送门，与追踪栏「击败：X」同一套）。
static func _寻路到怪(窗口, 图号: int, 怪号: int, 名: String) -> void:
	var 树: SceneTree = 窗口.get_tree()
	var 地图: Node = 树.current_scene if 树 != null else null
	var 小地图: Node = 地图.get_node_or_null("小地图面板") if 地图 != null else null
	if 小地图 != null and 小地图.has_method("走向怪"):
		小地图.call("走向怪", 图号, 怪号)
		return
	显示修炼说明(窗口, "找不到世界（不在图里？）—— 没法寻路到 %s" % 名)


## ── 只读档（「看别人」那一扇）要关掉的交互入口 ─────────────────────────────────
## 原版是**页面自己**按 `readOnly` / `isMyShouLiJian` 关（`ShouLiJianPanel.as:140,148`、
## `CharOtherWindow2.as:137` 建 `TongshuWindow` 时 `readOnly=true`）。本工程这几页当初
## 只做自己那扇、没有这个开关 ⇒ 由宿主按**钮名**关。钮名不许编：
##   写轮眼 = `写轮眼切换_修正版.gd:392` 的 `弹窗按钮名 = "提升写轮眼阶数"`（场景 `[connection]`
##            里那颗钮 → `open_popup`，见同文件 `:408` 的注）；
##   柔拳   = 同一套模式的「提升柔拳阶数」（`接提升弹窗` 那边用的弹窗叫 `提升柔拳阶数弹窗`）。
## ⚠ 只 `disabled`、**不 `visible = false`** —— 实测原版那一颗是灰着还在
##   （本地原版实拍图里右下那颗"提升柔拳阶数"）。
const 只读要关的钮 := {
	"写轮眼": ["提升写轮眼阶数"],
	"柔拳": ["提升柔拳阶数"],
	## 结印 = `JieYinPanel.updateProp:356-359`「`if(!_isMyJieYin) _tiShengBtn.enabled = false`」，
	## 页面上那颗钮在场景里叫 `提升结印`（`结印页.tscn:1550`，`:2101` 接 `open_popup`）。
	## ⚠ 只关这一颗就够：弹窗里的「开始提升/自动提升」是我方宿主接的协议，
	##    只读分支**根本不接**（见 `初始化结印页` 里 `return` 的位置），而弹窗唯一的入口
	##    就是这颗被关掉的钮 ⇒ 那两条请求在只读窗里没有任何触发路径。
	"结印": ["提升结印"],
	## 轮眼 = `LunHuiYanPanel.changeTiShengBtnState:546-549`「`!_isMyLunHuiYan` ⇒ 提升钮 disabled」，
	## 场景里那颗叫 `提升轮回六道`（`轮回六道页.tscn:244`，`:1652` 接 `open_popup`）。
	"轮回六道": ["提升轮回六道"],
}

static func 关只读钮(页面: Control, 页名: String) -> void:
	for 钮名 in (只读要关的钮.get(页名, []) as Array):
		var 钮 := 页面.find_child(String(钮名), true, false) as Button
		if 钮 == null:
			# 找不到就是**页签名改了而这里没跟着改** ⇒ 必须说话：只读没关住 = 点它会去改对方的数据。
			push_error("只读档没找到要关的钮「%s」（页 %s）⇒ 那颗钮还点得动，会发请求" % [钮名, 页名])
			continue
		钮.disabled = true

## 这一块子页**还没接只读数据源**时的护栏：宁可什么都不画并喊一声，
## 也绝不能拿 `窗口._session`（我自己的镜像）去填他的窗 ——
## 装备格那一整轮就是栽在"把别人的窗画成我的数"上（`他人装备` 里那条注）。
static func 只读未接(只读档: Dictionary, 页名: String) -> bool:
	if 只读档.is_empty():
		return false
	push_error("子页「%s」还没接「看别人」的数据源 ⇒ 这一页不许摆页签（见 他人子分页组 的注）" % 页名)
	return true


## 切到第 `阶`（**1 起算**，与服务端的 `stage` 同一个口径）。
##
## ⚠️ **开页那一下要把补间直接走完**（用户 2026-09-24 报「写轮眼有时候会回到单勾玉」）。
## 成因：他的 `_ready()` 末尾写死 `_切换阶段(0)`（单勾玉），而我们随后才把服务端的阶段推上去，
## 于是**每次打开/刷新这一页都会从单勾玉转过去** —— 练过的角色一眼就看见"又回单勾玉了"。
## 这里调完他的 `_切换阶段`（它已经把立绘/面板/按钮都摆到目标阶段）之后，
## 把那条刚起的补间 `custom_step` 走到头：只剩 alpha/rotation 在半路，走完即落定，
## 视觉上就是从目标阶段直接出现，没有那一下旋转。
## （只在**进页面**这条路上这么做；用户手动点阶段按钮走的是他自己的 `_切换阶段`，动画照旧。）
static func 切写轮眼阶段(页面: Control, 阶: int) -> void:
	if not 页面.has_method("_切换阶段"):
		return
	页面.call("_切换阶段", clampi(阶 - 1, 0, 写轮眼阶段.size() - 1))
	var 补间: Variant = 页面.get("_tween")
	if 补间 is Tween and (补间 as Tween).is_valid():
		(补间 as Tween).custom_step(999.0)


## 翻页交给他的脚本 —— 这里只为兼容旧调用点保留，别再自己算页码。
static func 翻写轮眼页(页面: Control, 增量: int) -> void:
	var 当前: int = int(页面.get_meta("写轮眼阶", 1))
	切写轮眼阶段(页面, clampi(当前 + 增量, 1, 写轮眼阶段.size()))


static func 更新写轮眼页(页面: Control, 序号: int) -> void:
	页面.set_meta("写轮眼阶", 序号 + 1)
	切写轮眼阶段(页面, 序号 + 1)


## 每阶属性进度条的**唯一填法**（写轮眼 / 柔拳两页共用）。
##
## 原版口径两条腿：`TongshuWindow.as:533-580 setBarData` + `MBar.as:129-166 setData`，
## 柔拳那一页是同一式子的另一份实现 `RouQuanManager.as:128-167 getRouQuanProps` +
## `RouQuanPanel.as:580-645 updateProp`。三档：
##   查看阶 **<** 真阶 ⇒ 画**查看阶自己**的满值（`练过的阶当然已经满`）；
##   查看阶 **==** 真阶 ⇒ 上阶值 + `floor(进度 ×（本阶值 − 上阶值）/ 本阶 `levelUp` 需求)`；
##   查看阶 **>** 真阶 ⇒ 0（还没练到）。
## 分母取**本阶** `levelUp.maxItemCnt`（`TongshuWindow.as:543` 用的就是 `_curSageData` = 查看阶那份），
## 与服务端 `cultivation_progress_requirement` 同一口径 ⇒ 条子永远和实际属性对得上。
##
## ⚠️ **按类型对号、不按 `attrs` 下标**：`XieLunYan.stage6` 的 `anqi_trigger` 排在**最后一位**
## （下标 8），而场景第 7 根条烘的名字叫「手里剑触发几率」。原版那条 `barArr[i].setData(…attrs[i])`
## 会把**反弹伤害**的数画进**手里剑触发几率**的条（`TongshuWindow.as:577` 按下标、标签却写死在 `:268`），
## 柔拳那页自己反而是 `switch (type)`（`RouQuanPanel.as:600-644`）⇒ 这里跟柔拳那页的口径，
## 不跟写轮眼页的下标写法（有意偏离，登记在编年史 §3.237）。
##
## ⚠️ 场景里那些 `0/200`、`0/15` 是**烘死的示例字**（第二十二条：场景示例值会骗人），
## 这里连条子带字一起覆盖。
const 修炼属性条名 := {
	"maxhp": ["生命"], "maxmp": ["查克拉"], "atk": ["攻击"], "def": ["防御"],
	"atkspeed": ["攻击速度"], "wlkspeed": ["移动速度"], "anqi_trigger": ["手里剑触发几率"],
	"damage_reflect": ["反弹伤害"],
	## 同一类型在两页节点名不同：写轮眼页第 9 根叫「伤害免疫」、柔拳页第 8 根叫「伤害减免」。
	## 原版这槽的文案是同一个串（`en_US$message_properties.as:2550` SHANGHAI_JIANMIAN「伤 害 减免」，
	## 挂在 `TongshuWindow.as:276` 的第 9 根条上）⇒ 两个名字都认，按场景实际节点名填。
	"damage_reduce": ["伤害免疫", "伤害减免"],
}

static func 填修炼进度条(页面: Control, 区名: String, 表名: String, 阶数: int, 状态: Dictionary) -> void:
	var 区 := 页面.find_child(区名, true, false) as Control
	if 区 == null:
		push_warning("修炼页找不到「%s」，进度条填不了" % 区名)
		return
	var 族表: Dictionary = (游戏数据表.取表("原版杂项") as Dictionary).get(表名, {}) as Dictionary
	var 真阶 := clampi(int(状态.get("stage", 1)), 1, 阶数)
	var 进度 := maxi(0, int(状态.get("count", 0)))
	var 子节点: Array[Node] = 区.get_children()
	for 下标 in mini(阶数, 子节点.size()):
		var 组 := 子节点[下标] as Control
		if 组 == null:
			continue
		var 阶 := 下标 + 1
		var 本阶 := 修炼阶属性(族表, 阶)
		var 上阶 := 修炼阶属性(族表, 阶 - 1)
		var 需求 := 修炼阶需求(族表, 阶)
		for 类型 in 本阶:
			var 上限 := maxi(0, int(本阶[类型]))
			var 现值 := 0
			if 阶 < 真阶:
				现值 = 上限
			elif 阶 == 真阶:
				var 底 := int(上阶.get(类型, 0))
				现值 = 上限 if 需求 <= 0 else 底 + int(floor(float(进度) * float(上限 - 底) / float(需求)))
			for 条名 in (修炼属性条名.get(类型, []) as Array):
				var 条 := 组.get_node_or_null(条名) as ProgressBar
				if 条 == null:
					continue
				var 定稿 := clampi(现值, 0, 上限)
				条.min_value = 0.0
				进度条补间.灌值(条, float(定稿), float(上限), [定稿, 上限])
				var 字 := 组.get_node_or_null("%s值" % 条名) as Label
				if 字 != null:
					字.text = "%d/%d" % [定稿, 上限]


## `stageN.attrs` 摊平成 `类型 → 值`（数据里 attrs 的键是 "0".."8" 的字符串下标）。
static func 修炼阶属性(族表: Dictionary, 阶: int) -> Dictionary:
	var 出 := {}
	var attrs: Dictionary = ((族表.get("stage%d" % 阶, {}) as Dictionary).get("attrs", {}) as Dictionary)
	for 键 in attrs:
		var 条 := attrs[键] as Dictionary
		出[String(条.get("type", ""))] = int(条.get("value", 0))
	return 出


## 本阶练满要多少件：`levelUp.maxItemCnt`，轮回那一族没配它、退 `maxJingHun`
## （与服务端 `cultivation_progress_requirement` 同一条回退链）。
static func 修炼阶需求(族表: Dictionary, 阶: int) -> int:
	var 升级: Dictionary = ((族表.get("stage%d" % 阶, {}) as Dictionary).get("levelUp", {}) as Dictionary)
	for 键 in ["maxItemCnt", "maxJingHun"]:
		var 值 := int(升级.get(键, 0))
		if 值 > 0:
			return 值
	return 0


## 提升弹窗的**公共接线**（三个页面的弹窗结构是同一套：写轮眼 / 柔拳 / 轮回六道）。
##
## 真值出处（2026-10-17 巡检）：原版三个弹窗类**全部读客户端 Etc 配置表**，
## 服务端**从不下发**成功率/消耗/祝福上限这些字段 ——
## `RouQuanTiShengWindow.as:222-242`、`TishengTongshuPanel.as:97-127`、
## `LunHuiYanTiShengWindow.as:92-111`。本工程那份表已导出到
## `数据/原版杂项.json` 的 `RouQuan / XieLunYan / LunHuiYan` 段，
## 取 `stage<当前阶 + 1>` 的 `stageUp`（`stageN` 描述的是"**升到** N 阶"要什么，
## `stage1` 是全零占位）：`needItemId / needItemCnt / fakeItemId / zhufu_show / zhufu_min / zhufu_max / prob`。
## ⚠️ 场景里"成功率 50%""0/1000""失败增加…0-6"是美术按 **stage2** 抄的**示例值**，
##   运行期整条覆盖（第二十二条：场景示例值会骗人）。原 `祝福值上限 = 100` 那个写死也一并作废
##   （真值是每阶的 `zhufu_show`，柔拳/轮回 1000、写轮眼 9 阶起 3000）。
##
## ⚠️ 「提升X阶数」那枚入口钮**不抢接线** —— 打开弹窗是场景里已经接好的
## （`[connection]` 把它连到弹窗的 `open_popup()`），再自己接一遍会让一次点击触发两次滑入
## （他自己在 `_接线提升阶数弹窗()` 里也防了这个）。这里只在同一条 `pressed` 上**补记一笔开合**。

## 有「自动提升」的三族（结印不算：它那套在 `结印文案` / `功能窗口.起结印自动`，走 2318 独立 opcode）。
const 自动提升族 := ["写轮眼", "柔拳", "轮回六道"]
## 族名 → `数据/原版杂项.json` 里那一段（`提升配置(族表, 下一阶)` 的键）。
const 族表名 := {"写轮眼": "XieLunYan", "柔拳": "RouQuan", "轮回六道": "LunHuiYan"}


static func 接提升弹窗(窗口, 页面: Control, 弹窗名: String, 入口名: String,
		动作: String, 状态: Dictionary, 族表: String) -> void:
	var 族 := String(动作).trim_suffix("提升")		# "写轮眼提升" → "写轮眼"（与服务端 kind 同串）
	var 弹窗 := 页面.find_child(弹窗名, true, false) as Control
	if 弹窗 == null:
		push_warning("没找到「%s」，提升弹窗接不上" % 弹窗名)
		return
	# **开合跨整页重建保留**（与结印同一坑）：每一发结果帧都重画整页，新场景里的弹窗根
	# 是 `visible = false` ⇒ 不记不补的话，自动提升每 0.8 秒（写轮眼 1 秒）闪没一次。
	# 这三族的动画在 `滑出动画` 里，新实例烘在展开位 y=228、动画没播 ⇒ 只补 `visible`
	# 就正好落在展开态、**不重播滑入**（不必请那位开发者的脚本加 `直接展开`）。
	if bool(窗口._族弹窗开着.get(族, false)):
		弹窗.visible = true
	var 入口 := 页面.get_node_or_null(入口名) as Button
	if 入口 != null:
		入口.pressed.connect(func() -> void: 窗口._族弹窗开着[族] = true)
	var 关 := 弹窗.get_node_or_null("关闭按钮") as Button
	if 关 != null:
		关.pressed.connect(func() -> void: 窗口._族弹窗开着[族] = false)
	var 开始 := 弹窗.find_child("开始提升按钮", true, false) as Button
	if 开始 != null:
		for 连接 in 开始.pressed.get_connections():
			开始.pressed.disconnect(连接["callable"])
		# 手动那一跳**先停自动**（`tiShengHandler:267-271`、`LunHuiYan:235-239`、
		# 写轮眼 `onClickStartBtn:140` 那句 `_isZidong = false`）—— 就是确认正文里的停止条件 3。
		开始.pressed.connect(func() -> void: 族手动一跳(窗口, 族))
	var 购买 := 弹窗.find_child("购买按钮", true, false) as Button
	if 购买 != null:
		# 这枚「购买」不是买东西，是**问服务端要这件材料的商城条目**：
		# `ItemCaiLiaoBox.buyHandler:45-54` ⇒ `CashShopWindowEvent.REQUEST_CASH_ITEM_INFO(id = itemData.id)`
		# ⇒ 回包 1079 弹那扇购买窗（§3.125 那条链，工程里的统一出口 `请求商城商品`）。
		# 原来这里写 `disabled = true` 配一句"原版跳商城，本轮未做"—— 但那句**前提是假的**：
		# 出口一直有（驯养材料格 `通灵驯养窗口.gd:242`、扩容窗、秘笈合成、手里剑突破都在用）
		# ⇒ 灰掉就是把一条现成的路堵成死路（体检报告 P1-3）。
		# ⚠ 拆旧连接是**幂等保险**，不是"修好了一处堆叠"：`功能窗口._render_page:1106-1108`
		#   每次重绘把 `_content` 整片 free 掉重烘，这五枚钮每次都是**新节点** ⇒ 老代码那句
		#   没守卫的 `connect` 今天也不会堆（实测：删掉这一圈，`人物秘术页回归测试` ⑬ 仍绿）。
		#   留着是因为上面 `开始`/`自动` 同一圈规矩，而哪天这页改成跨重绘缓存（`确保子页`
		#   在同一棵子树里已经是那副德性），没守卫就当场多挂一根。
		for 连接 in 购买.pressed.get_connections():
			购买.pressed.disconnect(连接["callable"])
		# 号取**点击那一刻的当前阶**（原版 `updateView:227-231` 每次开窗现取 `_cfg`）。
		# ⚠ 同一族每阶的 `needItemId` 其实**是同一个**（只有 `needItemCnt` 变，实测表：
		#   XieLunYan 2..12 阶全 16000037）⇒ 这条今天量不出差别，门里改量"满阶不发"那一支。
		购买.pressed.connect(func() -> void:
			var 现态: Dictionary = 窗口._session.cultivation_states.get(族, {})
			var 号 := int(提升配置(族表, maxi(1, int(现态.get("stage", 1))) + 1).get("needItemId", 0))
			if 号 <= 0:
				# 满阶/表里没配材料：原版 `if(!itemCell.itemData) return;`（`buyHandler:46-49`）
				# 是**静默 no-op**，这里给一句人话（本工程口径：点了没反应会被当成坏了）。
				窗口._通知("这一阶没有要消耗的材料，没有可买的东西")
				return
			窗口.请求商城商品(str(号)))
	var 自动 := 弹窗.find_child("自动提升按钮", true, false) as Button
	if 自动 != null:
		for 连接 in 自动.pressed.get_connections():
			自动.pressed.disconnect(连接["callable"])
		自动.text = 升阶文案.按钮停止 if 窗口.族自动中(族) else 升阶文案.按钮自动
		自动.pressed.connect(func() -> void: 族点自动(窗口, 族))
	填提升弹窗(窗口, 弹窗, 状态, 族表)


## 自动提升的重发间隔 = 各族 `setTimeout` 那个字面：
## `RouQuanTiShengWindow:66` / `LunHuiYanTiShengWindow:201` 是 **800**，
## 写轮眼那族在 `TongshuSource:71`（循环挂在管理器而不是弹窗上）是 **1000**。
static func 族自动间隔(族: String) -> float:
	return 1.0 if 族 == "写轮眼" else 0.8


## `stage<当前阶 + 1>.stageUp`；**空字典 = 已经满阶**（与 `填提升弹窗` 置灰钮用的是同一判据）。
static func 族下一阶配置(窗口, 族: String) -> Dictionary:
	var 状态: Dictionary = 窗口._session.cultivation_states.get(族, {})
	return 提升配置(String(族表名.get(族, "")), maxi(1, int(状态.get("stage", 1))) + 1)


## 够不够 = 三族**同一式子**（`RouQuanTiShengWindow.canTiSheng:109-122`、
## `LunHuiYanTiShengWindow.canTiSheng:76-90`、`TishengTongshuPanel.setStartBtnEnbled:283-297`）：
## `背包(灵符) >= needItemCnt` **或** `背包(神符) > 0`。
## 神符那条就是确认正文末尾那句「4 阶以后若背包中有神符则优先使用」的落点 ——
## 表里 `fakeItemId` 也确实只从 `stage5` 起才有（`数据/原版杂项.json`）。
static func 族道具够(窗口, 配置: Dictionary) -> bool:
	var 神符 := int(配置.get("fakeItemId", 0))
	if 神符 > 0 and 窗口._背包数量(神符) > 0:
		return true
	return 窗口._背包数量(int(配置.get("needItemId", 0))) >= int(配置.get("needItemCnt", 0))


## 跳一次 = 原版各族 `tiShengRouQuan(是否自动)` / `tiShengLunHuiYan` / `requestXinLunyan`，
## 三条出口逐字对齐：
##   · 满阶（下一级没配置）⇒ **直接 return**（`RouQuanTiShengWindow:126-129` 那句
##     `!_cfg || !Manager.canTiSheng`；写轮眼/轮回靠钮置灰，同一处理）；
##   · 够 ⇒ 发那一族的升阶包（**自动 = 客户端隔 0.8/1.0 秒重发同一发**，不是服务端一次吞光）；
##   · 不够 ⇒ 自动态发 `*_TISHENG_PROMPT`（写轮眼是 `TISHENG_TONGSHU_WINDOW_NOTICE_1`）
##     **并停掉自动**；手动态只发「不够」那一句、定时器不动。
static func 族一跳(窗口, 族: String, 自动: bool) -> void:
	var 配置 := 族下一阶配置(窗口, 族)
	if 配置.is_empty():
		return
	if 族道具够(窗口, 配置):
		发送修炼请求(窗口, 族 + "提升", [])
		return
	# 占位符是原版语言表的 `%1`（写轮眼那条两个都填同一个物品名）⇒ 一律 `.replace`，
	# GDScript 的 `%` 只认格式符（§3.205：`"…%1不够" % 名` 直接报错）。
	var 物品名 := 游戏数据表.item_name(int(配置.get("needItemId", 0)))
	var 模板 := String(升阶文案.自动不够.get(族, "")) if 自动 else String(升阶文案.手动不够.get(族, ""))
	显示修炼说明(窗口, 模板.replace("%1", 物品名).replace("%2", 物品名))
	if 自动:
		窗口.停族自动(族)


static func 族手动一跳(窗口, 族: String) -> void:
	窗口.停族自动(族)
	族一跳(窗口, 族, false)


## 「自动提升 / 停止提升」的三岔（`autoTiShengHandler:83-102` / `onClickZidongBtn:255-276`）：
##   · 已经在自动 ⇒ 停（原版靠 `_autoTiShengBtn.selected` 判态，这边记在窗口上）；
##   · 没在自动、但**灵符与神符都不够** ⇒ 只发一句「不够」，**连确认都不弹**；
##   · 否则弹二次确认（`*_AUTO_TISHENG_PROMPT`），确认了才 `sureToAutoTiSheng`（换钮文字 + 立刻跳第一下）。
static func 族点自动(窗口, 族: String) -> void:
	if 窗口.族自动中(族):
		窗口.停族自动(族)
		return
	var 配置 := 族下一阶配置(窗口, 族)
	if 配置.is_empty():
		return
	if not 族道具够(窗口, 配置):
		显示修炼说明(窗口, String(升阶文案.手动不够.get(族, "")).replace("%1",
			游戏数据表.item_name(int(配置.get("needItemId", 0)))))
		return
	var 遮罩 := 窗口._overlay as Control
	if 遮罩 == null:
		窗口.起族自动(族)		# 拿不到遮罩也别为了"确认"把功能吞掉（同结印那一条）
		return
	确认弹.弹消息(遮罩, String(升阶文案.确认正文.get(族, "")), func(码: int) -> void:
		if 码 == 1:
			窗口.起族自动(族))

## `stage<当前阶 + 1>.stageUp`（Etc 表；越界/缺段 ⇒ 空字典 = 已经满阶）。
static func 提升配置(族表: String, 下一阶: int) -> Dictionary:
	var 族: Dictionary = 游戏数据表.取表("原版杂项").get(族表, {}) as Dictionary
	var 阶配置: Dictionary = 族.get("stage%d" % 下一阶, {}) as Dictionary
	return 阶配置.get("stageUp", {}) as Dictionary

## 把弹窗那一整片文字/条子按**当前阶的下一级配置**刷成真值。
static func 填提升弹窗(窗口, 弹窗: Control, 状态: Dictionary, 族表: String) -> void:
	var 当前阶: int = maxi(1, int(状态.get("stage", 1)))
	var 配置 := 提升配置(族表, 当前阶 + 1)
	var 物品号: int = int(配置.get("needItemId", 0))
	var 需要数: int = int(配置.get("needItemCnt", 0))
	var 成功率: int = int(配置.get("prob", 0))
	var 祝福上限: int = int(配置.get("zhufu_show", 0))
	# ① 道具格：图标 + 名字 + 背包持有数 + 不够时灰显
	#   （原版 `_itemCell.itemCell.itemData = ItemFactory.createSingleItem(needItemId)`、
	#    `label = StringTool.getItemString(...)`、`validateItem():145-161` 灰显）。
	var 框 := 弹窗.find_child("道具框", true, false) as Control
	var 持有 := int(窗口._背包数量(物品号)) if 物品号 > 0 else 0
	if 框 != null:
		框.modulate = Color(1, 1, 1) if (需要数 <= 0 or 持有 >= 需要数) else Color(0.45, 0.45, 0.45)
		var 数值 := 框.find_child("数量数值", true, false) as Label
		if 数值 != null:
			数值.text = str(持有)
		for 子 in 框.get_children():
			if 子 is TextureRect:
				(子 as TextureRect).texture = 游戏数据表.item_icon(物品号) if 物品号 > 0 else null
				break
	# ② 道具名标签：弹窗直属那个叫「写轮眼灵符 / 柔拳灵符 / 轮回灵符」的 Label。
	#    ⚠️ **不能按名字 find_child** —— 道具框里那张图标 TextureRect 和它**同名**，
	#    深搜会先撞到 TextureRect。所以遍历直属子节点、按「类型 + 名字尾缀」挑。
	if 物品号 > 0:
		var 名称 := 游戏数据表.item_name(物品号)
		for 子 in 弹窗.get_children():
			if 子 is Label and String(子.name).ends_with("灵符"):
				(子 as Label).text = 名称
	# ③ 三行文案（逐字取原版语言表，只把 %1/%2/%3 换成真值）：
	#    `TISHITONGSHU_PANEL_TISHI_TEXT`(:23) / `TISHENGTONGSHU_ZHUFUZHI`(:3334) /
	#    `TISHENG_TONGSHU_WINDOW_NOTICE_2`(:3019)。原版 NOTICE_2 把"需要"和"成功率"写在
	#    同一个富文本里，我们的场景拆成两个节点 ⇒ 各填一半，内容一字不差。
	var 祝福说明 := 弹窗.find_child("说明文字1", true, false) as RichTextLabel
	if 祝福说明 != null:
		祝福说明.text = "失败增加1-3点祝福值，本次升阶成功祝福\n值为%d-%d，[color=#ff0000]超过%d必成！[/color]" % [
			int(配置.get("zhufu_min", 0)), int(配置.get("zhufu_max", 0)), int(配置.get("zhufu_max", 0))]
	var 重置说明 := 弹窗.find_child("说明文字2", true, false) as RichTextLabel
	if 重置说明 != null:
		重置说明.text = "[color=#ff0000]每提升1次，祝福值保留时间重置为12小时[/color]"
	var 消耗 := 弹窗.find_child("消耗说明文字", true, false) as RichTextLabel
	if 消耗 != null:
		消耗.text = "本次提升需要：\n[color=#ff0000]%s%d张[/color]" % [
			游戏数据表.item_name(物品号) if 物品号 > 0 else "", 需要数]
	var 比率 := 弹窗.find_child("成功率说明文字", true, false) as Label
	if 比率 != null:
		比率.text = "本次提升成功率：%d%%" % 成功率
	# ④ 祝福条：`_zhuFuBar.setData(zhuFu, zhufu_show)`（上限是**表里的 zhufu_show**，不是 100）。
	var 祝福条 := 弹窗.find_child("祝福值进度条", true, false) as ProgressBar
	if 祝福条 != null:
		var 祝福 := clampi(int(状态.get("blessing", 0)), 0, maxi(祝福上限, 1))
		进度条补间.灌值(祝福条, float(祝福), float(祝福上限), [祝福, 祝福上限])
		var 条数值 := 祝福条.find_child("祝福值数值", true, false) as Label
		if 条数值 != null:
			# 文案按**数据**算（`TishengTongshuPanel.as:306` 先写 tf、`:170` 才挂补间）；
			# 读 `祝福条.value` 的话数字会跟着条爬，那是 §②第 5 步的反面。
			条数值.text = "%d/%d" % [祝福, 祝福上限]
	# ⑤ 满阶（下一级没有配置）⇒ 按钮点不动。原版同一处理：
	#   `RouQuanManager.as:167-170`（8 阶 canTiSheng=false）、`RouQuanPanel.as:420-421`（按钮置灰）。
	var 开始 := 弹窗.find_child("开始提升按钮", true, false) as Button
	if 开始 != null:
		开始.disabled = 配置.is_empty()
	# 满阶时**自动提升也点不动**（原版这里只有写轮眼那族靠钮置灰挡得住：柔拳 `tiShengRouQuan:126`
	# 有 `!_cfg` 兜底，轮回 `tiShengLunHuiYan:175-189` 连这道都没有、`canTiSheng()` 会在
	# `allData["stage0"]` 上直接炸 —— 那是 AS3 自己的洞，这边取最严的口径，两枚一起灰）。
	var 自动钮 := 弹窗.find_child("自动提升按钮", true, false) as Button
	if 自动钮 != null:
		自动钮.disabled = 配置.is_empty()


## 柔拳页 —— 页面与动画由**另一位开发者**完成（`柔拳切换阶段.gd`）。
## 与写轮眼同一套模式：他的脚本在 `_ready()` 里自己接按钮/翻页，我们只推服务端阶段 + 接协议。
## 他的 `_切换阶段(阶段号)` 收的是 **1 起算**的 `当前阶段`，和服务端 `stage` 同一口径。
static func 初始化柔拳页(窗口, 页面: Control, 是别人 := false, 档: Dictionary = {}) -> void:
	var 状态: Dictionary = 页状态(窗口, "柔拳", 是别人, 档)
	if 是别人 and 状态.is_empty():
		只读闸(页面, ["提升柔拳阶数"])
		return
	var 阶 := clampi(int(状态.get("stage", 1)), 1, 8)
	切柔拳阶段(页面, 阶)
	柔拳阶段解锁(页面, 阶)
	# 柔拳那页的进度条以前同样没接（`RouQuanPanel.as:580-645` 的 `updateProp` 就是这段）。
	填修炼进度条(页面, "数值，阶段名称切换区", "RouQuan", 8, 状态)
	if 是别人:
		# 原版 `RouQuanPanel.as:433-436`：`_isMyRouQuan` 为假就只摁住那一枚提升钮，
		# 阶段翻页照旧（他那份属性表按 `_stage/_count` 现算，正是给"看别人"用的）。
		只读闸(页面, ["提升柔拳阶数"])
		return
	接提升弹窗(窗口, 页面, "提升柔拳阶数弹窗", "提升柔拳阶数", "柔拳提升", 状态, "RouQuan")


## 未突破的境界钮灰化 —— 原版 `RouQuanPanel.as:464-480 updateButtonState()`：
##   第 n 枚钮（n = 1..8）**n > 当前阶** ⇒ `filters = [StyleUtil.getGrayFilter()]`，
##   其余 `filters = null`。判据是 `按钮下标 < _stage`，所以**当前阶自己也是亮的**；
##   服务端给 0 时原版先改写成 1（`:327-328`）⇒ 这里同样夹到 1..8。
##
## 页面脚本（另一位开发者）在每个阶段钮上留了 `是否解锁` 这个口子：置假 ⇒ 套灰度材质，
## 而且悬停/按下也不再提亮（`阶段按钮交互.gd`）。灰了**仍然能点**，与原版
## `ProgramButton.filters` 一样只是滤镜 —— 阶段页照旧翻着看各阶属性。
##
## ⚠ 他的 `去饱和.gdshader` 是 Rec.601（0.299/0.587/0.114），原版
##   `StyleUtil.getGrayFilter()` 是 0.3086/0.6094/0.082 ⇒ 锁上后把着色器换成工程里
##   逐字照抄的那份，保证灰度亮度与原版一致。解锁时他的 setter 会 `material = null`。
static func 柔拳阶段解锁(页面: Control, 阶: int) -> void:
	var 区 := 页面.get_node_or_null("阵法面板/阶段图标切换区")
	if 区 == null:
		return
	阶 = clampi(阶, 1, 8)
	for i in range(1, 9):
		var 钮 := 区.get_node_or_null("阶段%d" % i)
		if 钮 == null or not ("是否解锁" in 钮):
			continue
		var 解锁 := i <= 阶
		if bool(钮.get("是否解锁")) != 解锁:
			钮.set("是否解锁", 解锁)
		if 解锁:
			continue
		var 材 := 钮.material as ShaderMaterial
		if 材 != null:
			材.shader = 禁用灰度着色器


static func 切柔拳阶段(页面: Control, 阶: int) -> void:
	if 页面.has_method("_切换阶段"):
		页面.call("_切换阶段", clampi(阶, 1, 8))


static func 翻柔拳页(页面: Control, 增量: int) -> void:
	var 当前: int = int(页面.get_meta("柔拳阶", 1))
	切柔拳阶段(页面, clampi(当前 + 增量, 1, 8))

## 从背包拖一件装备、落在装备格上 —— 原版 `EquipPane.onItemUp`
## （`com/mxw/uifl/controls/char/EquipPane.as:968-996`）的三条分支：
##   ① 目标格已经是**同一件**（category 与 id 都相同）→ 什么都不做（`:979-983`）；
##   ② `getItemEquipPosition(拖来的 id) == 目标格的 part` → 当作"使用这件物品"
##      （派发 `ItemEvent.USE`，经 `CharWindow2` → `UI.useItem` → `requestEquipItem`）；
##   ③ 不匹配 → **静默丢下，没有提示**（`:990`）。
##
## ① 和 ③ 都已经在 `装备格._can_drop_data` 里拦成 `false` 了（Godot 不画落点高亮、
## 也不调 `_drop_data`），所以这里再判一次只是防"载荷被别处复用"。
## 走 `游戏会话.equip_item` 而不是直接发协议：在线时它发的正是
## `ITEM_MOVE(0, 背包格位, 装备位置, 0)`（与 `InventoryProcessor.requestEquipItem`
## 同一条报文，见 `InventoryProcessor.as:57-60`），离线时走本地那份，
## 两条路的界面刷新都由 `equipment_changed` 带出来。
static func _处理装备格拖放(来源格: Button, 目标格: Button, 物品id: String, 窗口) -> void:
	if str(来源格.get("格子归属")) != "背包" or str(目标格.get("格子归属")) != "装备":
		return
	if 装备部位表.位置(物品id) != int(目标格.get("槽位号")):
		return
	窗口._session.equip_item(物品id)


static func 更新柔拳页(页面: Control, 阶段: int) -> void:
	页面.set_meta("柔拳阶", 阶段)
	切柔拳阶段(页面, 阶段)
	柔拳阶段解锁(页面, 阶段)

## 昆虫四格的数据源：段 29 那一串里 `slot_index ∈ −200..−203` 的件。
## ⚠ **不能复用他人装备那份**：它按 `equip_position` 归槽，而 `装备部位.位置("131xxxx")`
##   对四只虫都算出**同一个** −205 ⇒ 四格挤成一格、还落在人物面板 20 格之外。
##   原版四格按虫槽位置建格（`KunChongPanel.createCell:123-126` 传
##   `EquipmentPosition.KunChongA..D`），协议里就是 `slot_index`
##   （服务端 `KUN_CHONG_EQUIPPED_POSITIONS = (−200,−201,−202,−203)`）。
static func 他人昆虫(窗口, 档: Dictionary) -> Dictionary:
	var 出 := {}
	var 后 = 窗口.get("_backend")
	if 后 == null:
		return 出
	var 串 := String(档.get("装备串", "-"))
	if 串 == "" or 串 == "-":
		return 出
	for 件 in 串.split("@", false):
		var 解: Dictionary = 后.call("_parse_item_entry", String(件))
		if 解.is_empty():
			continue
		var 槽 := int(解.get("slot_index", 0))
		if 装备部位表.是昆虫槽(槽):
			出[槽] = 解
	return 出


## 原版 `KunChongPanel.updatePropDesc` 的「加成属性」整段：头 + 逐类合计 + 注意尾。
const 昆虫加成头 := "[color=#ff9100]加成属性\n[/color]"
const 昆虫注意尾 := "[color=#1e90ff]注意：\n每个角色最多可同时装备四隻昆虫，强化昆虫可有效提高追加属性[/color]"


## 四只虫按**基础属性类型**合计（基础值 + 强化值），类型顺序按首次出现。
static func 昆虫属性文本(虫: Array) -> String:
	var 合计 := {}
	var 顺序: Array = []
	for 件 in 虫:
		var 类型: int = int((件 as Dictionary).get("base_attr_type", -1))
		if not 顺序.has(类型):
			顺序.append(类型)
			合计[类型] = 0
		合计[类型] = int(合计[类型]) + int((件 as Dictionary).get("base_attr_value", 0)) \
				+ int((件 as Dictionary).get("strength_value", 0))
	var 串 := ""
	for 类型 in 顺序:
		串 += "%s +%d\n" % [String(装备提示框.属性名.get(类型, "属性%d" % 类型)), int(合计[类型])]
	if 串 == "":
		return 昆虫注意尾
	return 昆虫加成头 + 串 + 昆虫注意尾


## 提示框宿主层：`物品提示框` / `装备提示框` 是 `原版人物窗口内容` 的直接子节点
## （`人物窗口.tscn:1967/1970`），而**子页都在 `人物扩展页` 里面** ⇒ 从子页往上走到第一层
## 带提示框的祖先就是它。为什么不能用子页自己：① `人物扩展页.clip_contents = true`
## 会把框裁掉（§3.298 那批轮回技能框就是栽在这一条上、改挂 `遮罩` 层的）；② 框与格子
## 得在**同一个坐标系**里摆（`格子提示框` 用 `框.get_parent().get_local_mouse_position()`
## + `窗口._舞台尺寸()` 钳位）。装备格那条先例走的就是 `面板.get_parent()`（:516），
## 这里同一层、只是从页面往上找，省得"哪一层"在多处各写一遍。
static func 提示宿主(页面: Control) -> Control:
	var 层: Control = 页面
	while 层 != null:
		if 层.get_node_or_null("装备提示框") != null or 层.get_node_or_null("物品提示框") != null:
			return 层
		层 = 层.get_parent() as Control
	return null


static func 初始化寄坏之术页(窗口, 页面: Control, 只读档: Dictionary = {}) -> void:
	var 只读 := not 只读档.is_empty()
	# 寄坏槽在原版是 **昆虫窗**（`KunChongPanel.as:123` 建格）的四格，位置 -200..-203，
	# 不在人物面板的 20 格之列。位置用公共表的常量，节点名沿用这一页自己的 `.tscn`。
	var 寄坏槽位 := [
		[装备部位表.昆虫一, "寄坏槽一"], [装备部位表.昆虫二, "寄坏槽二"],
		[装备部位表.昆虫三, "寄坏槽三"], [装备部位表.昆虫四, "寄坏槽四"],
	]
	## 格子里摆哪一份虫：只读 ⇒ **他的**（原版 `updateView(this._data.kunChongItems)`，
	## `CharOtherWindow2.as:122`）；自己 ⇒ 我的装备镜像。
	var 来源: Dictionary = 他人昆虫(窗口, 只读档) if 只读 else 窗口._session.equipped_items
	var 露了头的: Array = []		# 给 `updatePropDesc` 汇总用（原版按 `_kunChongItems` 那一份算）
	var 首个物品: Dictionary = {}		# 四格里的第一只有虫的（属性面板/强化目标的兜底）
	## ⚠ 强化目标**永远取我自己的那只**，与格子里摆的是谁的那份**无关**：
	## 原版那颗「昆虫强化」按钮**没有** `isMyself` 判断（`kunChongStrengthHandler:129-132`
	## → `KunChongManager.showStrengthView(null)`），点它开的是**我自己的**强化窗
	## （原版连背包一起开：`centerTwoWindow(KUNCHONG_STRENGTH_WINDOW, ITEM_WINDOW2_F)`），
	## 提交走 `requestStrengthKunChong(我的件.position)` ⇒ 强化的是我的虫。
	## 拿他的虫当目标 = 把他的 `unique_id`/槽位发去强化**我的**背包里那个格子，
	## 服务端 `inventory.get(槽)` 会取到完全另一件（2026-10-16 现查，同一版还顺手抓到
	## 下面那条 `equip_position` 的错，两个叠在一起点谁都看不出来）。
	var 我的首虫: Dictionary = {}
	var 我的首虫位置 := 0
	# 悬停提示框挂在哪一层（见 `提示宿主`）——这一页的格子都在 `人物扩展页` 里，提示框不能也挂进去。
	var 提示层 := 提示宿主(页面)
	for 序号 in 4:
		var 位置: int = 寄坏槽位[序号][0]
		var 槽名: String = 寄坏槽位[序号][1]
		var 按钮 := 页面.get_node("虫槽区域/%s" % 槽名) as TextureButton
		var 物品: Dictionary = 来源.get(位置, {})
		var 我的件: Dictionary = 窗口._session.equipped_items.get(位置, {})
		if 我的首虫.is_empty() and not 我的件.is_empty():
			我的首虫 = 我的件
			我的首虫位置 = 位置
		# 悬停提示（2026-10-27 用户报修②「格子里鼠标放上去也不显示昆虫信息」）：
		# 原版 `KunChongCell.as:122` 在 `showIcon` 末尾 `MToolTipItem.createToolTip(stage, _bgSkin, _itemData)`
		# —— **三参**调用 ⇒ 没有"跟身上穿的那件比"那一列（对比列只有背包格/看别人装备格才有，
		# 见 `格子提示框.gd` 头注释的分流表）；空格子走 `hideIcon` ⇒ 不挂提示。
		# 原生 `tooltip_text` 由 `接线` 清空让位，这里不再写"槽名：虫名"那一行。
		if 提示层 != null:
			格子提示框.接线(窗口, 提示层, 按钮, 物品)
		# ⚠️ 图标/名称是**烘在场景里的**子节点（`昆虫图标` / `昆虫名称`，起始 `visible = false`）——
		#   页面脚本不许运行期 `.new()` 固定控件（`功能入口回归测试` 有明文守卫）。
		#   2026-10-17 巡检 #9：修前这一格只写了 tooltip ⇒ 穿上寄坏虫**页面上什么都不会变**，
		#   因为回显来源 2054 整包被丢；就算不丢，这一格也只有一行悬浮字。
		var 图 := 按钮.get_node_or_null("昆虫图标") as TextureRect
		var 名 := 按钮.get_node_or_null("昆虫名称") as Label
		var 有虫 := not 物品.is_empty()
		if 图 != null:
			图.visible = 有虫
			图.texture = 游戏数据表.item_icon(物品.get("id", "")) if 有虫 else null
		if 名 != null:
			名.visible = 有虫
			# 原版 `KunChongCell.updateView:108` = `物品名 + "+" + strengthLevel`。
			# 强化等级这个字段在咱这边的名字是 `strengthen`（`_parse_item_entry` 里 EQUIPMENT
			# 家族 values[22] = 服务端 `item.strength_level`；昆虫 section 就是 ZhuangBei，
			# 走的是 EQUIPMENT 编码 ⇒ 写 `strength` 会恒为 0）。
			名.text = "%s+%d" % [String(物品.get("name", "寄坏虫")), int(物品.get("strengthen", 0))] if 有虫 else ""
		if 有虫 and 首个物品.is_empty():
			首个物品 = 物品
		if 有虫:
			露了头的.append(物品)
		# ⚠ 只读 ⇒ 原版 `KunChongPanel.as:createCell:241-245` 只给 `_isMyself` 挂 CLICK
		#   （点一下卸下）与 MOUSE_UP（从背包拖进来）⇒ 看别人时这两条**根本没有**。
		#   页面实例复用，切页/换人会重跑本函数 ⇒ 连上一次留下的连接一起清掉。
		for 旧 in 按钮.pressed.get_connections():
			按钮.pressed.disconnect(旧["callable"])
		# 穿虫的**落点**（从背包拖进来）：运行期 `set_script` 挂 `昆虫放入格.gd` ——
		# 场景是 SPEC 生成物、不许手改 `.tscn`（同族先例 `勾玉放入格` / `徽章放入格` /
		# `修复放入格`）。挂同一份脚本时 `set_script` 是 **no-op**（变量留着、实例不重建，
		# 见下面只读分支的实测注）⇒ `槽位号` 每轮**显式**重填；`请求放入` 的连接挂在节点上
		# ⇒ 每轮先拆再接（防复用页面堆连线）。
		按钮.set_script(昆虫放入格)
		var 落虫信号: Signal = 按钮.get("请求放入")
		for 旧落 in 落虫信号.get_connections():
			落虫信号.disconnect(旧落["callable"])
		if 只读:
			# 原版 `createCell:241-245` 只给 `_isMyself` 的格挂 MOUSE_UP ⇒ 看别人时落点**不存在**。
			# ⚠ `set_script` 挂**同一份脚本**时 Godot 直接 no-op（2026-10-27 门 ⑦ 实测：
			#   `槽位号` 留着上一轮"自己"的 -200 ⇒ 看别人照样能落虫）⇒ 必须自己归零：
			#   0 = 不认领落点（`昆虫放入格._can_drop_data` 的第一道守卫）。
			按钮.set("槽位号", 0)
			continue
		按钮.set("槽位号", 位置)
		按钮.mouse_filter = Control.MOUSE_FILTER_STOP
		# ⚠️ 先拆再接：本函数每次渲染都跑，页面实例是复用的。
		按钮.pressed.connect(窗口._unequip.bind(位置))
		# ⚠ bind 参数追加在信号参数**之后** ⇒ 处理函数签名是 `(背包格, 窗口, 槽)`。
		落虫信号.connect(_处理虫槽落点.bind(窗口, 位置))
	var 属性文本 := 页面.get_node("属性面板/属性") as RichTextLabel
	属性文本.text = 昆虫属性文本(露了头的)
	# ── 「携入的虫」优先 ────────────────────────────────────────────────
	# 背包物品菜单那枚「强化」走的是原版 `KunChongManager.showStrengthView(curCellData)`
	# （`ItemWindow2.as:808-811`）—— 带的可以是**背包里**任何一只，不一定是已装备的。
	# 状态记在**宿主**上（§3.62 跨窗状态那条规矩），由 `背包窗口._开寄坏之术带虫` 设。
	var 携入: Dictionary = {}
	var 携入位置 := 0
	if 窗口 != null and 窗口.get("_角色携入虫") is Dictionary:
		携入 = 窗口.get("_角色携入虫")
		携入位置 = int(窗口.get("_角色携入位置"))
	## 强化成功/失败后服务端会重下发那一格（`_strengthen_kun_chong` 末尾
	## `_send_inventory_update` / `_send_equipped_kun_chong`），`apply_backend_inventory`
	## 是**整份换新字典** ⇒ 宿主上这份携入快照仍是发起前的星级，弹窗的「成功几率」和
	## 悬停详情框就都停在旧值（2026-10-31 用户报修③）。原版 `itemDatachanged:382-398` 正是
	## 按 `_itemData.position` 重新 `getItemBySlot` 取件：取得到就继续摆（星级跟着新件走），
	## 件没了 / 换了 id 才 `backItemToEquip()`（清目标、格子回到"没放虫"）。
	if not 携入.is_empty() and 携入位置 > 0:
		var 现件: Dictionary = 窗口._session._占用条(窗口._session.inventory, 携入位置)
		if 现件.is_empty() or String(现件.get("id", "")) != String(携入.get("id", "")):
			窗口._角色携入虫 = {}
			窗口._角色携入位置 = 0
			窗口._昆虫强化态["放"] = false
			携入 = {}
			携入位置 = 0
		else:
			携入 = 现件
			窗口._角色携入虫 = 现件
	## ⚠ 强化目标**永远取我自己的那只**，与格子里摆的是谁的那份**无关**：原版那颗钮开的是
	## **我自己的**强化窗，提交走 `requestStrengthKunChong(我的件.position)`（详见分支同名注释）。
	var 强化目标: Dictionary = 携入 if not 携入.is_empty() else 我的首虫
	# ⚠️ 这一参是**发给服务端的位置**：服务端 `_strengthen_kun_chong` 拿它 `inventory.get(slot)`
	#    取件 ⇒ 已装备的虫传装备位（-200..-203），背包里的虫要传它那一格的背包格号。
	# ⚠️ 不能取 `物品.equip_position`：那个字段按 id 前四位算，四只虫全都算成 −205。
	var 强化位置 := 携入位置 if not 携入.is_empty() else 我的首虫位置
	# ⚠️ 2026-10-27 用户报「昆虫强化按键不能点击」：虫**全在背包里**（一只没穿）⇒
	# 携入/我的首虫两支都空 ⇒ 旧句 `disabled = 强化目标.is_empty()` 把钮置灰。
	# 原版 `_strengthBtn`（`KunChongPanel.as:205-211`）**整文件没有一处 enabled/disabled
	# 赋值**（grep 过）⇒ 钮**永远可点**；点了就开窗（`showStrengthView(null)`），
	# 格里没虫时提交被"请放入昆虫"原文拦（`_昆虫强化提交` 的 位置==0 一支已接好）。
	# 选虫光标 `UpShelfCursor` 未移植 ⇒ 身上没虫时目标兜到**背包第一只虫**（与
	# 「携入」同一口径：发的是**背包格号**，服务端 `inventory.get(slot)` 按它取件）。
	if 强化目标.is_empty():
		for 序 in 窗口._session.inventory.size():
			var 条: Dictionary = 窗口._session.inventory[序]
			var 条号 := String(条.get("id", ""))
			if 昆虫放入格.可收(条号) and String(游戏数据表.item(条号).get("category", "")) == "装备":
				强化目标 = 条
				强化位置 = 序 + 1
				break

	var 强化 := 页面.get_node("强化寄坏虫") as Button
	强化.disabled = false
	# ⚠️ 这里**不发协议**：原版 `KunChongPanel.as:131` 是 `showStrengthView(null)` = **开这扇窗**
	#    （场景里的 `[connection]` 已经接到 `_on_insect_btn_pressed` 做显隐）。
	#    2026-10-11 之前这里还挂着一句 `发送修炼请求("寄坏强化", …)` ⇒ **点开窗的同时就把第一个
	#    寄坏虫强化了**（玩家没点过"开始强化"、也没看过消耗）。已删。
	# ⚠️ 位置不是 unique_id —— 原版 `requestStrengthKunChong(this._itemData.position, …)`，
	#    而 `position` 对**已装备**的件就是装备位、对**背包件**就是它那一格（见上面那条注释）。
	_接昆虫弹窗(窗口, 页面, 强化目标, 强化位置)
	# 介绍钮是**普通 Button、没人给它 set_script** ⇒ 连接挂在节点上跨重渲染留着；
	# 同一份静态 callable + 同样的 bind 参数 ⇒ 第二次 `connect` 被引擎自拒并在 ERROR 日志
	# 刷 `already connected`（假绿#19 的"症状只在日志"形状）。⚠ **不能拆光重接**：场景里还有一根
	# `[connection] 类别介绍.pressed → 昆虫介绍弹窗.open_popup`（`.tscn:833`，建实例时只接一次）
	# ⇒ 拆光会把开窗那半边拆没。已连着自己的就不重复接。
	var 介绍钮 := (页面.get_node("类别介绍") as Button)
	var 落介绍 := 显示修炼说明.bind(窗口, "寄坏虫分为四个独立装备类别，每类只能装备在对应虫槽。")
	var 已连介绍 := false
	for 旧介 in 介绍钮.pressed.get_connections():
		if 旧介["callable"] == 落介绍:
			已连介绍 = true
			break
	if not 已连介绍:
		介绍钮.pressed.connect(落介绍)


## 背包把虫拖上虫槽 ⇒ 穿（原版 `KunChongPanel.as:152-164 cellMouseUpHandler` 发
## `requestMoveItem(背包格, 虫槽 -200..-203)`；走 `游戏会话.equip_item` = 在线同一条
## ITEM_MOVE、离线那份交换镜像）。**类型闸两道都要**：
##   · 客户端半道（`ItemType.as:285-288` 前三位 131）在落点组件里；
##   · 服务端半道（运行时夹具 `_can_equip`:48064 —— 认 `GAME_DATA_CATALOG` 的装备定义，
##     勾玉 `13100xxx` 前缀也是 131、但**没有装备定义 ⇒ 拒**）在这里用**物品表分类**
##     镜像：`01310001..06` 分类是「装备」、勾玉分类是「宝石」。离线没有服务端兜底，
##     不拦就会把宝石穿进虫槽（幽灵数据）。
## 不绑"哪只虫进哪格"：原版 `_can_equip` 对四格放行**任何**虫（页面文案那句"每类只能
## 装备在对应虫槽"与实现不符 —— 照实现走，文案保持原版）。
## ⚠ 信号参数在前、bind 参数追加在后 ⇒ `(背包格, 窗口, 槽)`。
static func _处理虫槽落点(背包格: int, 窗口, 槽: int) -> void:
	var 物品: Dictionary = 窗口._session._占用条(窗口._session.inventory, 背包格)
	if 物品.is_empty():
		return
	var 物品号 := String(物品.get("id", ""))
	if String(游戏数据表.item(物品号).get("category", "")) != "装备":
		return
	窗口._session.equip_item(物品号, 槽, 背包格)


## 昆虫强化弹窗（原版 `KunChongStrengthWindow`，映射真值见下面各条注释）。
##
## ⚠️ **2026-10-11 重接（§3.112）** —— 这里原来走通用 `接提升弹窗(...)`，而它靠
##    `find_child("开始提升按钮")` 找提交钮；这一页里**有两枚同名节点**：
##    `底图/放置区底图/开始提升按钮`（文案「放入昆虫」，其实是原版的 `_itemBox.dropBtn`）
##    在树里排在前面 ⇒ **被接到提交上**：玩家点「放入昆虫」当场就发强化请求；
##    而真正的「开始强化」（`昆虫强化弹窗/开始提升按钮`）**一枚接线都没有**（点了没反应）。
##    门也没照到：`人物秘术页回归测试` ③ 用的**同样是** `find_child("开始提升按钮")` ——
##    命中的正是那枚"放入"，于是"提升按钮接得上"恒为真（又一次**判据取错节点**的假绿）。
##
## 原版真值：
##   · 页面的「昆虫强化」= 开/关这扇窗（`KunChongPanel.as:131` → `showStrengthView:41-53`），不发协议；
##   · 「放入昆虫 / 取出昆虫」是**选虫**那一跳（`_itemBox.dropBtn`，原版走 `UpShelfCursor`
##     从背包/装备里挑）—— 未移植 ⇒ 本端口取**第一个已装备的寄坏虫**当目标
##     （与页面原来那句 `首个物品` 同一口径），按钮语义保留"放入/取出"的开关；
##   · 「开始强化」才是提交：`strengthEquip():348-378` → `requestStrengthKunChong(position, 用镇灵石, 张数)`
##     = `ITEM_CHANGE` 动作 **25**；服务端 `_strengthen_kun_chong` 读 `fields[2]=use_guarantee` /
##     `fields[3]=help_count`（`fake_flash_server.py:53487-53494`）。
##   · 两道客户端前置与**原文**：`KUNCHONG_TIP1`「你没有足够的镇灵石」/ `KUNCHONG_TIP2`
##     「你没有足够的**寄环**玉」（语言表原文就写"寄环玉"，照抄不改字）。
##   · 镇灵石**只有下一阶 ≥ `guarantee.levelCanUse` 才可用**（`updateView:109-121` 写的是
##     `strengthLevel >= 10`；配置 `levelCanUse = 11` 针对的是**下一阶**，两者等价）；
##     不可用时强制取消勾选。张数下拉 = `1..help.maxHelpCnt`（配置 9），每张 +`help.probUp`（3%）。
static func _接昆虫弹窗(窗口, 页面: Control, 昆虫: Dictionary, 位置: int) -> void:
	var 弹窗 := 页面.find_child("昆虫强化弹窗", true, false) as Control
	if 弹窗 == null:
		push_warning("没找到「昆虫强化弹窗」，昆虫强化接不上")
		return
	var 段 := 装备打造表.取段("KunChong")
	var 保底: Dictionary = 段.get("guarantee", {}) if 段.get("guarantee") is Dictionary else {}
	var 帮手: Dictionary = 段.get("help", {}) if 段.get("help") is Dictionary else {}
	var 放入钮 := 弹窗.get_node_or_null("底图/放置区底图/开始提升按钮") as Button
	var 提交钮 := 弹窗.get_node_or_null("开始提升按钮") as Button
	var 镇勾 := 弹窗.get_node_or_null("底图/强化区底图/使用镇灵石") as CheckBox
	var 玉勾 := 弹窗.get_node_or_null("底图/强化区底图/使用寄坏玉") as CheckBox
	var 下拉 := 弹窗.get_node_or_null("底图/强化区底图/数量下拉") as OptionButton
	var 自动勾 := 弹窗.get_node_or_null("使用寄坏玉") as CheckBox   # 节点名沿用他的场景（其实是「自动强化到10并停止」）
	var 有虫 := not 昆虫.is_empty() and 位置 != 0
	## 「放进格子里了」≠「有一只可强化的目标」：目标在没点放入时也会兜到已装备/背包首虫
	## （本函数上面那条 `强化目标` 的兜底），而原版 `_itemData` 在有件落进 `_itemBox` 之前是
	## **空的** ⇒ 产物格空、两行都写 0（`getNextLevelData:530` 与 `updateXingYunRatio:452`
	## 都以 `_itemData` 为前提）。所以面板一切"有件"的显示都认这个 meta，不认目标在不在
	## （2026-10-31 用户报修①：没放虫，结果格里却有昆虫图标）。
	var 已放 := bool(窗口._昆虫强化态.get("放", false)) and 有虫
	弹窗.set_meta("kunchong_slot", 位置)   # ⚠️ meta 键必须 ASCII（中文键 Godot 直接拒收，见 memory）
	弹窗.set_meta("kunchong_in", 已放)   # 开场是空的（原版 `init` 也不预置）——点「放入昆虫」才进格
	# 强化目标这件也抄一份到宿主上 ⇒ 自动循环那一跳（500ms 后跑，那时手里那枚钮早被重绘换掉了）
	# 用的就是这一份；每发回帧页面重建都会重写它，所以星级永远是回帧后的新值。
	窗口._昆虫强化态["虫"] = 昆虫
	窗口._昆虫强化态["位"] = 位置
	# **开合与"格里有虫"跨整页重建保留**（与柔拳/写轮眼/轮回那三族、手里剑瓶颈弹窗同一坑）：
	# 每一发 2066 回帧都把整页重画一遍 ⇒ 新场景里的弹窗根是 `visible = false`、放置格是空的，
	# 不记不补的话玩家点一次「开始强化」就看一次闪没（报修 2.1 里"面板没实装"的一条表现）。
	if bool(窗口._昆虫强化态.get("开", false)):
		弹窗.visible = true
		弹窗.z_index = 100			# 与场景脚本 `_on_insect_btn_pressed` 同一档
	var 入口 := 页面.get_node_or_null("强化寄坏虫") as Button
	if 入口 != null:
		# 这枚钮的开合由**场景里的 `[connection]`** 负责（接的是弹窗脚本的 `_on_insect_btn_pressed`），
		# 这里只补记一份状态 ⇒ 不动它已有的连接（拆了就把开窗的那半边拆没了）。
		入口.pressed.connect(func() -> void: 窗口._昆虫强化态["开"] = true)
	var 关钮 := 弹窗.get_node_or_null("关闭按钮") as Button
	if 关钮 != null:
		关钮.pressed.connect(func() -> void: 窗口._昆虫强化态["开"] = false)
	# 拖标题条挪窗（2026-10-27 用户报修③「卡在人物属性面板里，不能拖拽移动」）。
	# 位置记在宿主 `"置"`：整页重绘（`_render_page` 把 `_content` free 重建）后页是新实例，
	# 不记就弹回烘死位 —— 原版 `MWindow` 记住上次位置，`窗口管理._记住的位置` 同一处置。
	# 只接一次（`connect` 对同一 目标+方法+bind 参数会拒重，拒了还刷一条 already connected）。
	if not 弹窗.has_meta("drag_wired"):
		弹窗.set_meta("drag_wired", true)
		弹窗.gui_input.connect(_昆虫弹窗拖拽.bind(弹窗, 窗口))
		## 标题条那 29px 上头**没有** STOP 装饰板压着（`昆虫强化弹窗/底图` 烘的 y 从 55 起），
		## 所以不往子层放开 PASS —— 2026-10-28 反向 M26 把那段摘掉**门照样全绿** ⇒ 它没有作用面
		## （§3.301 坑 4 那条口径：摘掉仍绿 = 该向量下冗余）。真哪天重烘场景把标题条盖住了，
		## 门里 `_挑拖点`「四个候选落点没有一处送得进弹窗」那条会先红。
	var 记位: Variant = 窗口._昆虫强化态.get("置", null)
	if 记位 is Vector2:
		弹窗.position = 记位 as Vector2
	# 张数下拉：1..maxHelpCnt
	if 下拉 != null:
		下拉.clear()
		for 张 in maxi(1, int(帮手.get("maxHelpCnt", 1))):
			下拉.add_item(str(张 + 1), 张)
		下拉.disabled = true
	if 放入钮 != null:
		for 连接 in 放入钮.pressed.get_connections():
			放入钮.pressed.disconnect(连接["callable"])     # 拆掉"点开即强化"那条错接线
		放入钮.pressed.connect(_昆虫放入切换.bind(窗口, 弹窗, 昆虫, 位置))
		放入钮.text = "放入昆虫"
	# 拖背包虫进**放置格** = 直接选强化目标（2026-10-27 用户报修①）。落点件运行期挂
	# （同 `寄坏槽一..四` 的 `昆虫放入格`，场景不改）；`请求选虫` 的连接挂在节点上、
	# 页面实例复用 ⇒ 每轮先拆再接（挂同一份脚本时 `set_script` 是 no-op，节点不会被重建）。
	var 放置格 := 弹窗.get_node_or_null("底图/放置区底图/放置格") as Control
	if 放置格 != null:
		放置格.set_script(昆虫强化落格)
		放置格.mouse_filter = Control.MOUSE_FILTER_STOP
		var 落虫信号: Signal = 放置格.get("请求选虫")
		for 旧落 in 落虫信号.get_connections():
			落虫信号.disconnect(旧落["callable"])
		落虫信号.connect(_处理强化落虫.bind(窗口))
	# 悬停提示（2026-10-27 用户报修②「格子里鼠标放上去也不显示昆虫信息」）。
	# 原版这四格全是 `SimpleItemCell`（放置格 = `_itemBox.itemCell`、成功格 = `_itemBox.resultCell`、
	# 两格材料 = `ItemCaiLiaoBox.itemCell`），`showIcon:220` 末尾统一挂 `MToolTipItem.createToolTip`
	# ⇒ 与背包/人物装备格**同一份接线**；同样三参（不对比穿戴件，见 `格子提示框.gd` 分流表）。
	var 提示层 := 提示宿主(页面)
	if 提示层 != null:
		# 放置格/成功格的提示只看**格子里有没有件**：没放入时原版 `_itemData` 为空，
		# `showIcon` 走 `hideIcon`（不挂提示）⇒ 悬停空格既不能弹目标虫、也不能弹产物预览。
		_接昆虫两格提示(窗口, 弹窗, 昆虫)
		# 材料两格：原版 `updateView:137` 是 `itemCell.itemData = createSingleItem(helpItemId)`
		# —— **不看拥有数**，拥有 0 也摆出那一格 ⇒ 提示恒有（灰只是 `applyGrayFilter` 的皮）。
		for 料: Array in [["镇灵石格", int(保底.get("guaranteeId", 0))],
				["寄坏玉格", int(帮手.get("helpItemId", 0))]]:
			var 料格 := 弹窗.get_node_or_null("底图/强化区底图/%s" % String(料[0])) as Control
			var 料号 := int(料[1])
			if 料格 == null or 料号 <= 0:
				continue
			格子提示框.接线(窗口, 提示层, 料格, {"id": str(料号),
				"quantity": 装备打造表.拥有数(窗口._session, 料号)})
	# 上一发回帧之前格里有虫 ⇒ 补回去（原版 `itemDatachanged:382-398` 那一支已在上游按槽位重取件，
	# 这里只负责"拿到虫就把格子摆出来"）。
	if 已放:
		if 放入钮 != null:
			放入钮.text = "取出昆虫"
		var 格图 := 弹窗.get_node_or_null("底图/放置区底图/放置格/昆虫图标") as TextureRect
		if 格图 != null:
			格图.visible = true
			格图.texture = 游戏数据表.item_icon(昆虫.get("id"))
	if 镇勾 != null:
		# 可用性（下一阶够不够 `guarantee.levelCanUse`、格子里有没有虫）走 `_刷新昆虫弹窗`：
		# 「放入/取出」也要当场变灰/变亮，而那条路不重建整页、只调刷新。
		镇勾.toggled.connect(func(开: bool) -> void: 窗口._昆虫强化态["镇"] = 开)
	if 玉勾 != null and 下拉 != null:
		# 原版 `_jhyCheckBox`/`_jhyComboBox` 一变就 `updateXingYunHankdler:441-449` ⇒ 重算那两行
		# （成功几率里要加张数 × `help.probUp`），顺手把下拉的可用性跟着勾选走。
		# ⚠️ 勾选与张数**也记在窗口上**（与上面「开/放」同一处置）：每发回帧整页重建，
		#   不记的话玩家刚勾完就被弹回未勾，而下面的自动循环更要靠它把"这一跳用几张玉"带到下一发。
		玉勾.toggled.connect(func(开: bool) -> void:
			窗口._昆虫强化态["玉"] = 开
			下拉.disabled = not 开
			_刷新昆虫弹窗(窗口, 弹窗, 昆虫, 位置))
		下拉.item_selected.connect(func(序: int) -> void:
			窗口._昆虫强化态["张"] = 序 + 1
			_刷新昆虫弹窗(窗口, 弹窗, 昆虫, 位置))
		玉勾.set_pressed_no_signal(bool(窗口._昆虫强化态.get("玉", false)))
		下拉.disabled = not bool(窗口._昆虫强化态.get("玉", false))
		if 下拉.item_count > 0:
			# `select()` 不发 `item_selected` ⇒ 回灌不会反过来把状态再写一遍
			下拉.select(clampi(int(窗口._昆虫强化态.get("张", 1)) - 1, 0, 下拉.item_count - 1))
	if 提交钮 != null:
		for 连接 in 提交钮.pressed.get_connections():
			提交钮.pressed.disconnect(连接["callable"])
		提交钮.pressed.connect(_昆虫强化提交.bind(窗口, 弹窗, 昆虫, 位置))
	if 自动勾 != null:
		# 「自动强化到10并停止」（原版 `_autoCheckBox`）：勾上 ⇒ 每发回帧后由客户端**自己再发一跳**
		# （`onStengthResult:580-590` 的 `setTimeout(strengthHandler, 500)`），成功且已到 10 星就停；
		# 勾的时候已经 >9 星 ⇒ 立刻停并提示 `KUNCHONG_QIANGHUA_ENOUGH_LEVEL10`
		# （`autoQiangHuaHankdler:548-559`）；任何前置没过也停（`strengthHandler:517-521`）。
		# 可用性 = "格里有没有虫"（`updateView` 的 `_autoCheckBox.enabled = _itemData`、
		# `backItemToEquip:604`）。
		自动勾.disabled = not 已放
		for 连接 in 自动勾.toggled.get_connections():
			自动勾.toggled.disconnect(连接["callable"])
		自动勾.toggled.connect(_昆虫自动开关.bind(窗口, 昆虫))
	# 两格各自的「购买」：与上面三族同一语义（`ItemCaiLiaoBox.buyHandler:45-54` ⇒
	# `REQUEST_CASH_ITEM_INFO` = 工程的 `请求商城商品`，§3.125 那条链）。物品号取 KunChong 段：
	# 镇灵石 = `guarantee.guaranteeId`(16000136)、寄坏玉 = `help.helpItemId`(16000137)。
	# 修前这里接的是 `find_children("购买按钮")` + 一句"购买：原版跳商城（本轮未做）"的占位提示，
	# 而那条前提是假的（出口早有 ~10 处在用）⇒ 现改成发 1086。拆连接那一圈同上面：幂等保险，
	# 不是"修好了一处堆叠"（整页每次重绘都是新节点，实测删了它门 ⑬ 仍绿）。
	for 格名 in ["镇灵石格", "寄坏玉格"]:
		var 购买钮 := 弹窗.get_node_or_null("底图/强化区底图/%s/购买按钮" % 格名) as Button
		if 购买钮 == null:
			continue
		var 物品号 := int(保底.get("guaranteeId", 0)) if 格名 == "镇灵石格" else int(帮手.get("helpItemId", 0))
		for 连接 in 购买钮.pressed.get_connections():
			购买钮.pressed.disconnect(连接["callable"])
		if 物品号 <= 0:
			continue		# 表里没配物品号 ⇒ 不接（原版 `itemData` 为空时本来就没反应）
		购买钮.pressed.connect(窗口.请求商城商品.bind(str(物品号)))
	# 摆数值：两格材料的拥有数与灰、下一级产物、消耗金币与成功几率 —— 报修 2.1 说的
	# 「面板没实装」，缺的就是这一块（弹窗开着却满屏是烘死的 0）。
	_刷新昆虫弹窗(窗口, 弹窗, 昆虫, 位置)


## 放置格 / 成功格的悬停提示，按弹窗**当前** `kunchong_in` 现接：没放入时两格都收掉。
## 原版这两格是 `_itemBox.itemCell/resultCell`，`itemData` 一变 `SimpleItemCell.showIcon` 就重挂
## 一次提示（`showIcon:220`）⇒ 「放入/取出」也得跟着重接，不然取出后悬停成功格还弹着产物预览。
static func _接昆虫两格提示(窗口, 弹窗: Control, 昆虫: Dictionary) -> void:
	var 提示层 := 提示宿主(弹窗)
	if 提示层 == null:
		return
	var 已放 := bool(弹窗.get_meta("kunchong_in", false))
	var 放置格 := 弹窗.get_node_or_null("底图/放置区底图/放置格") as Control
	if 放置格 != null:
		格子提示框.接线(窗口, 提示层, 放置格, 昆虫 if 已放 else {})
	var 成功格 := 弹窗.get_node_or_null("底图/放置区底图/成功格") as Control
	if 成功格 != null:
		var 下一阶 := 昆虫下一阶(装备打造表.取段("KunChong"), int(昆虫.get("strengthen", 0)))
		格子提示框.接线(窗口, 提示层, 成功格, 昆虫下一阶预览(昆虫, 下一阶) if 已放 else {})


## 弹窗的数值填充，逐条照原版三个函数：
##   · `updateFilter:180-219` —— 角标 = `isBagExistItem(id)`（**同 id 各摞累加**），
##     镇灵石 `拥有 < 1` 灰、寄坏玉 `拥有 <= 0` 灰（`ItemCaiLiaoBox.hasItem:64-70`）。
##   · `updateView:127` —— 产物格 = `getNextLevelData():530-546`：同 id、等级 +1 的那一件，
##     **没有下一阶配置（满级）就是空格** ⇒ 这里用烘好的 `成功格/昆虫图标` 的显隐表达。
##   · `updateXingYunRatio:452-487` —— 两行文本套 `EQUIP_STRENGTH_DESC_TEMPLATE_0`：
##     金币 = `strength[下一级].needMoney × needMoneyFactor[资质-1] ÷ 100`，
##     **金币 ≥ 那一行就变红**（`_loc4_ < cocoNuts ? 原样 : <font color='#ff0000'>`）；
##     几率 = 勾了寄坏玉才 `min(100, 张数×probUp + ratio)`，否则直接 `ratio`；
##     没放虫或没下一阶配置 ⇒ 两行都写 0（不红）。
static func _刷新昆虫弹窗(窗口, 弹窗: Control, 昆虫: Dictionary, 位置: int) -> void:
	var 段 := 装备打造表.取段("KunChong")
	var 保底: Dictionary = 段.get("guarantee", {}) if 段.get("guarantee") is Dictionary else {}
	var 帮手: Dictionary = 段.get("help", {}) if 段.get("help") is Dictionary else {}
	# 「格子里已放入」是原版 `_itemData` 的等价物 —— 目标存在 ≠ 已放入：没点「放入昆虫」
	# 时也会兜底到已装备/背包首虫，拿那件当已放入就会在空格旁亮出产物格和两行数字
	# （2026-10-31 用户报修①）。
	var 有虫 := bool(弹窗.get_meta("kunchong_in", false)) and not 昆虫.is_empty() and 位置 != 0
	var 下一阶 := 昆虫下一阶(段, int(昆虫.get("strengthen", 0))) if 有虫 else {}
	# 两枚勾的可用性也认 `_itemData`（原版 `updateView` 同一处赋值）：这条放在刷新里而不是
	# 只在整页构建时摆一次 —— 「放入/取出」不重建整页，勾的灰与勾选得当场跟着变。
	var 镇勾 := 弹窗.get_node_or_null("底图/强化区底图/使用镇灵石") as CheckBox
	if 镇勾 != null:
		var 可用 := 有虫 and int(昆虫.get("strengthen", 0)) + 1 >= int(保底.get("levelCanUse", 11))
		镇勾.disabled = not 可用
		# 不可用 ⇒ 宿主那份也必须抹掉，否则 `_昆虫强化提交` 会带着上一轮的勾选继续发 `use_guarantee`
		# （原版读的是控件本身，控件被强制取消 ⇒ 我们只看宿主，宿主就得跟它一致）。
		if not 可用:
			镇勾.button_pressed = false
			窗口._昆虫强化态["镇"] = false
		else:
			镇勾.set_pressed_no_signal(bool(窗口._昆虫强化态.get("镇", false)))
	var 自动勾 := 弹窗.get_node_or_null("使用寄坏玉") as CheckBox
	if 自动勾 != null:
		自动勾.disabled = not 有虫
		# `backItemToEquip:604` 取出时顺手 `clearAutoQiangHua()` ⇒ 没虫时自动态一并清掉。
		var 要自动 := bool(窗口._昆虫强化态.get("自动", false)) and 有虫
		窗口._昆虫强化态["自动"] = 要自动
		自动勾.set_pressed_no_signal(要自动)
	_刷新昆虫材料格(窗口, 弹窗, "镇灵石格", int(保底.get("guaranteeId", 0)))
	_刷新昆虫材料格(窗口, 弹窗, "寄坏玉格", int(帮手.get("helpItemId", 0)))
	var 产物 := 弹窗.get_node_or_null("底图/放置区底图/成功格/昆虫图标") as TextureRect
	if 产物 != null:
		var 露 := 有虫 and not 下一阶.is_empty()
		产物.visible = 露
		产物.texture = 游戏数据表.item_icon(昆虫.get("id")) if 露 else null
	var 富 := 弹窗.get_node_or_null("底图/强化区底图/强化消耗与几率") as RichTextLabel
	if 富 == null:
		return
	var 花 := 0
	var 几率 := 0
	var 金币文本 := "0"
	if 有虫 and not 下一阶.is_empty():
		var 因子表: Dictionary = 段.get("needMoneyFactor", {}) if 段.get("needMoneyFactor") is Dictionary else {}
		var 资质 := int(昆虫.get("aptitude", 1))
		var 因子 := int(因子表.get(str(maxi(0, 资质 - 1)), 100))
		花 = int(int(下一阶.get("needMoney", 0)) * 因子 / 100)
		几率 = int(下一阶.get("ratio", 0))
		# 勾选读**控件**（原版 `updateXingYunRatio` 也是现读 `_jhyCheckBox.selected` /
		# `_jhyComboBox.selectedIndex`）；宿主那份只在整页重绘时回灌控件 ⇒ 两边不会各说各话。
		var 玉 := 弹窗.get_node_or_null("底图/强化区底图/使用寄坏玉") as CheckBox
		var 档 := 弹窗.get_node_or_null("底图/强化区底图/数量下拉") as OptionButton
		if 玉 != null and 玉.button_pressed and 档 != null and 档.selected >= 0:
			几率 = mini(100, (档.selected + 1) * int(帮手.get("probUp", 0)) + 几率)
		# 红只在**有虫这一支**里判（原版 else 分支直接 `replace("￥", 0)`，永远不红）。
		金币文本 = "[color=#ff0000]%d[/color]" % 花 if 花 >= int(窗口._金币()) else str(花)
	富.text = "[color=#ffffff]本次操作消耗金币：%s\n本次操作成功几率：%d%%[/color]" % [金币文本, 几率]


## `strength` 表按**下一阶**建档（键 0..19），19 阶再往上没有键 ⇒ 空字典 = 满级。
static func 昆虫下一阶(段: Dictionary, 当前阶: int) -> Dictionary:
	var 表: Variant = 段.get("strength", {})
	if typeof(表) != TYPE_DICTIONARY:
		return {}
	var 条: Variant = (表 as Dictionary).get(str(当前阶 + 1), null)
	return 条 as Dictionary if typeof(条) == TYPE_DICTIONARY else {}


## 成功格悬停那件 = 原版 `getNextLevelData():530-546` 逐字：同 id、`strengthLevel + 1`、
## `strengthValue = _configInfo.addRatio × baseAttrValue / 100`（**这一档的加值**，不是累计），
## 资质/基础属性/价照搬当前件。没有下一阶配置（满级）⇒ 空字典 = 这一格里没件 ⇒ 悬停不弹
## （与 `_刷新昆虫弹窗` 里产物格 `visible = false` 同一判据，两条不会各说各话）。
## ⚠ 端口这边把 `strengthValue` 写成 `strength_value` —— `装备提示框` 读的就是这个键
##   （服务端 2054 回帧里的昆虫件同名）。
static func 昆虫下一阶预览(昆虫: Dictionary, 下一阶: Dictionary) -> Dictionary:
	if 昆虫.is_empty() or 下一阶.is_empty():
		return {}
	var 出 := 昆虫.duplicate(true)
	出["strengthen"] = int(昆虫.get("strengthen", 0)) + 1
	出["strength_value"] = int(int(下一阶.get("addRatio", 0)) * int(昆虫.get("base_attr_value", 0)) / 100)
	return 出


## 一格材料（镇灵石/寄坏玉）：角标写拥有数、不够就把**图标和角标**灰掉。
## ⚠ 原版 `ItemCaiLiaoBox.applyGrayFilter:44-47` 只灰 `itemCell` —— 那枚「购买」钮**不跟着灰**
##   （它随时能点、点了开商城），所以这里只挑 `TextureRect`/`Label` 下手，不整格套皮。
static func _刷新昆虫材料格(窗口, 弹窗: Control, 格名: String, 物品号: int) -> void:
	var 格 := 弹窗.get_node_or_null("底图/强化区底图/%s" % 格名) as Control
	if 格 == null or 物品号 <= 0:
		return
	var 拥有 := 装备打造表.拥有数(窗口._session, 物品号)
	var 数 := 格.get_node_or_null("数量") as Label
	if 数 != null:
		数.text = str(拥有)
	var 灰 := 拥有 < 1
	# `窗口` 是无类型参数 ⇒ `禁用灰度材质()` 的返回在这里退化成 Variant，
	# 三元式另一支又是 null ⇒ `:=` 推不出类型（parse error），必须写死。
	var 皮: ShaderMaterial = 窗口.禁用灰度材质() if 灰 else null
	for 子 in 格.get_children():
		if 子 is TextureRect or 子 is Label:
			(子 as CanvasItem).material = 皮


## 「放入昆虫 / 取出昆虫」的开关（原版 `clickDropBtnHandler:333-346`：放入 ⇒ 起选虫光标、
## 取出 ⇒ `backItemToEquip` + `showView()`）。选虫光标未移植 ⇒ 这里用**第一个已装备的寄坏虫**
## 当目标：放入 = 亮图标换文案，取出 = 清空。**不发任何协议**。
static func _昆虫放入切换(窗口, 弹窗: Control, 昆虫: Dictionary, 位置: int) -> void:
	var 放入钮 := 弹窗.get_node_or_null("底图/放置区底图/开始提升按钮") as Button
	# ⚠️ 图标是**场景里烘好的** `昆虫图标`（`放置格` 之子）—— 页面脚本**不许**运行期 `.new()` 固定控件
	#    （`功能入口回归测试` 有明文守卫，第一版就是被它点出来的）。
	var 图标 := 弹窗.get_node_or_null("底图/放置区底图/放置格/昆虫图标") as TextureRect
	var 有虫 := not 昆虫.is_empty() and 位置 != 0
	var 已放 := not bool(弹窗.get_meta("kunchong_in", false))
	if not 有虫:
		已放 = false
	弹窗.set_meta("kunchong_in", 已放)
	窗口._昆虫强化态["放"] = 已放
	if 放入钮 != null:
		放入钮.text = "取出昆虫" if 已放 else "放入昆虫"
	if 图标 != null:
		图标.visible = 已放
		图标.texture = 游戏数据表.item_icon(昆虫.get("id")) if 已放 else null
	# 取出 ⇒ 成功格里的产物 + 那两行数字一起清掉（原版 `backItemToEquip` 把
	# `resultCell.itemData` 置空、`updateXingYunRatio` 写 0）；两格的悬停提示也跟着换。
	_接昆虫两格提示(窗口, 弹窗, 昆虫)
	_刷新昆虫弹窗(窗口, 弹窗, 昆虫, 位置)


## 拖进放置格 ⇒ **换强化目标**（原版 `KunChongStrengthWindow.as:415-418 dropItemHandler`
## → `:420-439 validateItem`：`isItemAKunChong` 过 ⇒ 这件就是目标、`_itemBox.dropBtn.text`
## 换「取出昆虫」；不过 ⇒ 弹语言表原文「很抱歉，该物品不是昆虫不能强化！」**且目标不动**）。
## 走的是背包菜单「强化」那条**同一个宿主通道**（`_角色携入虫` / `_角色携入位置`）⇒
## 刷新后 `初始化寄坏之术页` 按新目标重填整扇（图标 / 文案 / 消耗两行 / 两枚勾的可用性），
## 这里只负责"换目标 + 让页重画一遍"，不自己摆控件。
## ⚠ 发出去的位置是**背包格号**（原版 `requestStrengthKunChong(this._itemData.position)`，
##   背包件的 `position` 就是它那一格；服务端 `inventory.get(slot)` 按它取件）。
## ⚠ 类型闸只有 131 前缀这一道（客户端 `ItemType.as:285-288` 与服务端 `:54613` 同一口径），
##   **不补物品表分类闸** —— 与虫槽那一头不同（那一头服务端比的是装备定义，勾玉会被拒）。
## ⚠ bind 参数追加在信号参数**之后** ⇒ 处理函数签名是 `(背包格, 物品号, 窗口)`。
static func _处理强化落虫(背包格: int, 物品号: String, 窗口) -> void:
	if not 昆虫放入格.可收(物品号):
		显示修炼说明(窗口, "很抱歉，该物品不是昆虫不能强化！")
		return
	var 条: Dictionary = 窗口._session._占用条(窗口._session.inventory, 背包格)
	if 条.is_empty():
		return
	窗口._角色携入虫 = 条
	窗口._角色携入位置 = 背包格
	窗口._昆虫强化态["开"] = true		# 能拖进格子 ⇒ 这扇本来就是开着的，重画后别自己闪没
	窗口._昆虫强化态["放"] = true
	## 只落宿主状态、不碰控件：`原地刷新族页` 走不动（比如这一族页被换掉了）⇒ 退回整页重绘，
	## 两条路径最后都是重跑 `初始化寄坏之术页`，不会有"目标换了、画面没换"的中间态。
	if not 原地刷新族页(窗口, "寄坏之术"):
		窗口._render_page()


## 拖动强化弹窗（2026-10-27 用户报修③「不能拖拽移动，下方的信息被遮挡」）。
## 真值 `MWindow.as:333-340`：`MOUSE_DOWN` 且 `mouseY < _startDragY`（默认 29，即只有顶部
## 29 像素那条标题区）⇒ `startDrag(false, new Rectangle(0,0,STAGE_WIDTH-width, STAGE_HEIGHT-30))`
## ⇒ 落点钳 **舞台** 坐标 `[0, 舞台宽-窗宽] × [0, 舞台高-30]`（那 30 是给底部留给别的东西的余量，
## 与 `MToolTip` 的边缘钳同一档）。本工程这扇不是独立窗口、是页里的孩子 ⇒ `弹窗.position`
## 是页局部，钳的时候一律走 `global_position` 与 `窗口._舞台尺寸()`（视口 = 舞台，见 :5880 那条），
## 换算与 `文字提示框._舞台矩形()` 同一口径。
## ⚠ 形参顺序 `(事件, 弹窗, 窗口)`：`bind()` 追加在信号参数**之后**，`gui_input` 先发事件
##   （写反会报 `Cannot convert argument 1 from Object to Object`，表现是根本拖不动，§3.64.4）。
## ⚠ meta 键必须 ASCII（`drag_grab`）：中文键被 `set_meta` 静默拒收 ⇒ 每回合都拿默认值。
static func _昆虫弹窗拖拽(事件: InputEvent, 弹窗: Control, 窗口) -> void:
	if 事件 is InputEventMouseButton:
		var 按 := 事件 as InputEventMouseButton
		if 按.button_index != MOUSE_BUTTON_LEFT:
			return
		if 按.pressed and 按.position.y < 29.0:
			# 抓手记**全局差**（`功能窗口._on_title_input:5967` 同一口径）：只记局部坐标的话，
			# 父链一有偏移（这扇挂在页里、页挂在开了裁剪的扩展页里）拖完就会整体错位。
			弹窗.set_meta("drag_grab", 按.global_position - 弹窗.get_global_position())
			弹窗.z_index = 100		# 与 `_on_insect_btn_pressed` 同一档：拖起来别被邻格盖住
		else:
			弹窗.set_meta("drag_grab", Vector2.INF)
		return
	if not (事件 is InputEventMouseMotion):
		return
	var 抓: Vector2 = 弹窗.get_meta("drag_grab", Vector2.INF)
	if 抓 == Vector2.INF:
		return
	var 舞台: Vector2 = 窗口._舞台尺寸()
	# 用**事件里的**全局坐标，不用 `get_global_mouse_position()`：后者读的是显示服务那份光标，
	# `push_input` 合成的输入不喂它 ⇒ 无头门里拖到哪全凭真鼠标停在哪儿（假红/假绿双向）。
	var 新位: Vector2 = ((事件 as InputEventMouseMotion).global_position - 抓).round()
	新位.x = clampf(新位.x, 0.0, maxf(0.0, 舞台.x - 弹窗.size.x))
	新位.y = clampf(新位.y, 0.0, maxf(0.0, 舞台.y - 30.0))
	弹窗.global_position = 新位
	## 记的是**页局部**那份（重建后同层回灌才对得上）；`global_position` 的 setter 已经把
	## 父链的偏移算进去了，这里读回来的 `position` 就是页里那一份。
	窗口._昆虫强化态["置"] = 弹窗.position


## 「开始强化」—— 五道闸**逐条照原版的顺序**：`strengthHandler:515-528` 先过
## `canStrngthKunChong:489-507` 的三道（没放虫 / 满级 / 金币不够），全过才进
## `strengthEquip:341-380` 那两道拥有数前置（镇灵石、寄环玉），最后 `requestStrengthKunChong`。
## ⚠ 金币那道比的是**原价 `needMoney`**（`:501`），不是弹窗里那行乘了资质的数 ——
##   原版就是这么不一致（显示乘 `needMoneyFactor`、拦截用原价），照抄不改（乘完更大，
##   所以"显示贵、拦得松"不会让玩家白挨一发）。
## 勾选与张数**现读控件**（原版 `strengthEquip` 读的就是 `_zlsCheckBox.selected` /
## `_jhyComboBox.selectedIndex`）；宿主状态只在整页重绘时回灌控件，两边不会各说各话。
## 自动循环那一跳传的也是**当时那扇活弹窗**（`昆虫强化自动一跳`）⇒ 手动点与自动跑同一条码。
static func _昆虫强化提交(窗口, 弹窗: Control, 昆虫: Dictionary, 位置: int) -> void:
	if bool(弹窗.get_meta("kunchong_in", false)) == false or 位置 == 0 or 昆虫.is_empty():
		# 文案取自语言表 `KUNCHONG_STRENGTH_PROMPT`（服务端同一条，见 §3.99）
		显示修炼说明(窗口, "请放入昆虫")
		昆虫自动停(窗口)		# `strengthHandler:517-521`：前置没过 ⇒ `clearAutoQiangHua()`
		return
	var 用镇灵石 := 弹窗.get_node_or_null("底图/强化区底图/使用镇灵石") as CheckBox
	var 玉勾 := 弹窗.get_node_or_null("底图/强化区底图/使用寄坏玉") as CheckBox
	var 下拉 := 弹窗.get_node_or_null("底图/强化区底图/数量下拉") as OptionButton
	var 段 := 装备打造表.取段("KunChong")
	var 保底: Dictionary = 段.get("guarantee", {}) if 段.get("guarantee") is Dictionary else {}
	var 帮手: Dictionary = 段.get("help", {}) if 段.get("help") is Dictionary else {}
	# ② 满级（`KUNCHONG_STRENGTH_TOP_PROMPT`「已经强化到最顶级」）：表里 `strength[当前阶+1]`
	#    没有键就是满级 —— 与 `_刷新昆虫弹窗` 里"产物格是空的"用的是同一判据。
	var 下一阶 := 昆虫下一阶(段, int(昆虫.get("strengthen", 0)))
	if 下一阶.is_empty():
		显示修炼说明(窗口, "已经强化到最顶级")
		昆虫自动停(窗口)
		return
	# ③ 金币不够（`EQUIP_STRENGTH_FAIL_PROMPT_2`「很抱歉，你的金币不够」）
	if int(下一阶.get("needMoney", 0)) > int(窗口._金币()):
		显示修炼说明(窗口, "很抱歉，你的金币不够")
		昆虫自动停(窗口)
		return
	var 要保底 := 用镇灵石 != null and 用镇灵石.button_pressed
	var 张数 := 0
	if 玉勾 != null and 玉勾.button_pressed and 下拉 != null and 下拉.item_count > 0 and 下拉.selected >= 0:
		张数 = int(下拉.get_item_text(下拉.selected))
	# ④ 镇灵石不够（`KUNCHONG_TIP1`）
	if 要保底 and 装备打造表.拥有数(窗口._session, int(保底.get("guaranteeId", 0))) < 1:
		显示修炼说明(窗口, "你没有足够的镇灵石")
		昆虫自动停(窗口)
		return
	# ⑤ 寄坏玉不够（`KUNCHONG_TIP2`，原文是"寄环玉"）
	if 张数 > 0 and 装备打造表.拥有数(窗口._session, int(帮手.get("helpItemId", 0))) < 张数:
		显示修炼说明(窗口, "你没有足够的寄环玉")
		昆虫自动停(窗口)
		return
	# 发出去之前把**这一跳的快照**记在窗口上：回帧到了以后整页已经按新等级重画，
	# 那三句提示要的是**发起前**的星级（原版 `_lastLevel`，`strengthEquip:351`）。
	窗口._昆虫强化发起 = {"位置": 位置, "等级": int(昆虫.get("strengthen", 0))}
	发送修炼请求(窗口, "寄坏强化", [位置, 要保底, 张数])


## 「自动强化到10并停止」那一勾翻了（原版 `autoQiangHuaHankdler:548-559`）。
## 取消 ⇒ 停表；勾上但已经 >9 星 ⇒ 停表 + 原文那句提示（`_autoCheckBox.selected` 会被
## `clearAutoQiangHua:174-178` 按回去，所以宿主状态也要跟着落 false，不然下次重绘又勾上）。
## ⚠️ **信号参数排在最前**：Godot 4 的 `Callable.bind(...)` 是把绑定参数**追加到信号参数之后**
##   （不是插在前面），写成 `(窗口, 昆虫, 已勾)` 会收到 `[已勾, 窗口, 昆虫]` ⇒
##   报 `Cannot convert argument 2 from Object to Dictionary`、**这一勾整个静默失效**
##   （2026-10-25 门 ⑪ 抓到的就是这个）。工程里其余 bind 到 `toggled`/`item_selected` 的
##   都是这个顺序（`功能窗口._set_check`、`意志窗口._锁定勾选变了`、`传承窗口._选择卡牌等级`）。
static func _昆虫自动开关(已勾: bool, 窗口, 昆虫: Dictionary) -> void:
	窗口._昆虫强化态["自动"] = 已勾
	if not 已勾:
		昆虫自动停(窗口)
		return
	if not 昆虫.is_empty() and int(昆虫.get("strengthen", 0)) > 9:
		昆虫自动停(窗口)
		显示修炼说明(窗口, "这只昆虫已经强化到10星了！")


## 停表并取消勾选（= 原版 `clearAutoQiangHua:174-178` 的 `clearTimeout` + `selected = false`）。
## 页面此刻可能已经换成新节点 ⇒ 按路径现找，找不到就算了（下一次重绘会照宿主状态摆）。
static func 昆虫自动停(窗口) -> void:
	窗口._昆虫强化自动计时 = null
	窗口._昆虫强化态["自动"] = false
	var 弹窗 := 昆虫强化弹窗节点(窗口)
	if 弹窗 == null:
		return
	var 勾 := 弹窗.get_node_or_null("使用寄坏玉") as CheckBox
	if 勾 != null:
		勾.set_pressed_no_signal(false)


## 这扇强化弹窗（当前页里的那一枚），拿不到 = 人物窗没开在寄坏之术页 / 页面已重绘。
static func 昆虫强化弹窗节点(窗口) -> Control:
	var 内容 := 窗口._content as Node
	if 内容 == null or 内容.get_child_count() == 0:
		return null
	var 页 := (内容.get_child(0) as Node).get_node_or_null("昆虫强化弹窗") as Control
	if 页 != null:
		return 页
	return (内容.get_child(0) as Node).find_child("昆虫强化弹窗", true, false) as Control


## 弹窗**还亮着吗** —— 自动循环落点的第二道前置。与手里剑那条同一口径（§3.264）：
## 原版它是常驻顶层窗，关不掉也一直在；我们这边换页/重绘会把它收掉 ⇒
## 玩家看不见这扇窗时不再往下自动扣钱（**有意偏离**，登记在交接文档）。
static func 昆虫强化弹窗还亮着(窗口) -> bool:
	var 弹窗 := 昆虫强化弹窗节点(窗口)
	return 弹窗 != null and 弹窗.visible


## 自动循环自己再发一跳（原版 `onStengthResult:588` 排的那发 `strengthHandler`）。
## 走的是与手动点钮**完全同一条** `_昆虫强化提交` ⇒ 五道闸、停表条件一并复用；
## 弹窗取的是**当下这扇活的**（每发回帧页面重绘 ⇒ 旧引用早失效，每次现找）。
static func 昆虫强化自动一跳(窗口) -> void:
	var 弹窗 := 昆虫强化弹窗节点(窗口)
	if 弹窗 == null:
		昆虫自动停(窗口)
		return
	var 昆虫: Dictionary = 窗口._昆虫强化态.get("虫", {})
	_昆虫强化提交(窗口, 弹窗, 昆虫, int(窗口._昆虫强化态.get("位", 0)))


## 2066 昆虫强化回帧那一句（原版 `onStengthResult:561-592`，三句文案逐字取语言表）。
## ⚠ 件不在了或槽位对不上 ⇒ `backItemToEquip()` 默默把虫放回背包，**一句提示都不发**
##   （`_itemData` 与 `param1 != position` 同一支），我们原来那行通用的
##   「昆虫强化结果：成功」是原版没有的噪音 ⇒ 这一支在 `功能窗口._on_item_change_result`
##   里就分流掉，不再落到通用提示（与灵器炼制 2081/2082 同法，§3.270）。
static func 收昆虫强化回帧(窗口, 帧: Dictionary) -> void:
	var 发起: Dictionary = 窗口._昆虫强化发起
	窗口._昆虫强化发起 = {}
	if 发起.is_empty() or int(发起.get("位置", 0)) != int(帧.get("equipment_position", 0)):
		return
	var 旧阶 := int(发起.get("等级", 0))
	var 成功 := int(帧.get("result", 0)) == 1
	if 成功:
		显示修炼说明(窗口, "强化%d星成功" % (旧阶 + 1))		# `KUNCHONG_QIANGHUA_SUCCESS`
	elif 旧阶 > 7:
		# `KUNCHONG_QIANGHUA_FAIL_LEVEL10`「%1！真遗憾，还差一点点就成功了！」，`%1` = 玩家名
		显示修炼说明(窗口, "%s！真遗憾，还差一点点就成功了！" % str(窗口._session.player_stats.get("name", "")))
	else:
		显示修炼说明(窗口, "强化失败")						# `KUNCHONG_QIANGHUA_FAIL`
	# 「自动强化到10并停止」的续跳（`onStengthResult:580-590`）：成功且旧阶已到 9 ⇒ 这只满 10 了，停；
	# 旧阶 < 10 ⇒ 500ms 后再发一跳（**失败也继续跳**，原版只看星级不看这一发成没成）。
	if bool(窗口._昆虫强化态.get("自动", false)):
		if 成功 and 旧阶 >= 9:
			昆虫自动停(窗口)
		elif 旧阶 < 10:
			窗口._排一次昆虫强化重试()


static func _寄坏装备数量(窗口) -> int:
	var 数量 := 0
	for 位置 in [装备部位表.昆虫一, 装备部位表.昆虫二, 装备部位表.昆虫三, 装备部位表.昆虫四]:
		var 物品: Dictionary = 窗口._session.equipped_items.get(位置, {})
		if not 物品.is_empty():
			数量 += 1
	return 数量

## 轮回六道页 —— 页面与切换动画由**另一位开发者**完成（`轮回六道切换.gd`：
## `current_index` + `_update_ui()`，红边材质走 `red_outline_material`）。
## 与写轮眼/柔拳同一套模式：他的脚本自己接线，我们只推服务端阶段 + 接协议。
##
## ⚠️ 旧的这一版是照**上一版自建场景**写的，节点是 `阶段图` / `阶段名称` / `进度` /
## `属性面板/属性值` —— **他那一版里一个都没有**（他的是 `阶段资源/阶段1天道..阶段7外道`、
## `属性面板/阶段数值容器`、`属性面板/技能格区`）。照旧路径 get_node 会直接报错，故整段重写。
static func 初始化轮回六道页(窗口, 页面: Control, 是别人 := false, 档: Dictionary = {}) -> void:
	var 状态: Dictionary = 页状态(窗口, "轮回六道", 是别人, 档)
	if 是别人 and 状态.is_empty():
		只读闸(页面, ["提升轮回六道"])
		return
	# 真实境界先推给他（`real_stage` 是 1 起算、与 `current_index` 的 0 起算差一），
	# 再翻页 —— 否则 `_update_ui()` 第一遍就按"全达成"画、没提升的道不灰（§3.296）。
	var 阶号: int = clampi(int(状态.get("stage", 1)), 1, 8)
	页面.set("real_stage", 阶号)
	## ⭐ 进度条的两个数也只能来自服务端 + 本地 Etc 表：原版那一条 `_jinDuBar`
	##   是 `setData(currJingHunCount, allData["stage"+n].maxJingHun)`
	##   （`LunHuiYanPanel.as:412-415 / :136-167`），`count` 就是 2313 帧里的
	##   「轮回六道进度」（属性名见 `后端连接.gd:4858`），而**上限服务端从不下发**，
	##   读本地表 `stageN.levelUp.maxJingHun`。原版这条**条上有数字**：
	##   `createBar(...,"",200)` 的 `""` 传的是 `labelText`=左侧标题（`MBar.as:63-69`），
	##   跟条上的值文本是两回事；`setData` 末尾 `this.tf.text = param1 + "/" + param2`
	##   （`MBar.as:150-178`）。场景里那 8 枚 `进度值` 由 `轮回六道切换.gd::_update_ui`
	##   按当前所看阶写入（`进度对()`）。
	var 族表: Dictionary = (游戏数据表.取表("原版杂项") as Dictionary).get("LunHuiYan", {}) as Dictionary
	var 上限们: Array = []
	for 阶 in range(1, 9):
		上限们.append(修炼阶需求(族表, 阶))
	页面.set("精魂数", maxi(0, int(状态.get("count", 0))))
	页面.set("已开阶", clampi(int(状态.get("stage", 1)), 1, 8))
	## ⚠️ 上限表必须**推给页面**：`轮回六道切换.gd::上限()` 读的是它自己的 `各阶上限`，
	##    漏这一句时它是 `[]`、`上限()` 恒 0 ⇒ 条 max=0（整条满格）、条上写「52/0」——
	##    2026-10-30 实机截图核对逮到（人间道「52/0」）。原版这 8 个分母就是 `maxJingHun`：
	##    60/75/90/105/120/135/150/0（`数据/原版杂项.json` `LunHuiYan.stage*.levelUp.maxJingHun`，
	##    与客户端 `Etc/LunHuiYan` 同源）。对照 `对比图/原轮回六道.png`：原版在 1 阶时翻看天道
	##    显示「0/135」= 0 / (60+75)，正是 `LunHuiYanPanel.as:157-166` 那条**累加**分支 ⇒
	##    不是数据表里 stage2 有 135，别把累加结果写回本表。
	页面.set("各阶上限", 上限们)
	切轮回六道阶段(页面, 阶号)
	# 技能格悬停提示：原版对**别人**也挂（`SkillCell.as:222-228` 不分敌我），所以放在只读 return 之前。
	# 但**图标置灰只跟自己**：原版看别人用的是**他**的 `lunhuiSkills`
	# （`CharOtherWindow2.as:158` ⇒ `showInfo` 的 param3），移植侧还没解那个字段
	# （协议位次见 `后端连接.gd:4573` 注释）⇒ 拿自己的已学集去涂他的格必涂错。
	接轮回技能提示(窗口, 页面, not 是别人)
	if 是别人:
		只读闸(页面, ["提升轮回六道"])		# `LunHuiYanPanel.as:546-549` 同柔拳那一条
		return
	接提升弹窗(窗口, 页面, "提升轮回阶数弹窗", "提升轮回六道", "轮回六道提升", 状态, "LunHuiYan")


## 切到第 `阶`（**1 起算**，与服务端 `stage` 同口径）。
## 他的 `轮回六道切换.gd` 用 `current_index`（**0 起算**）+ `_update_ui()` 驱动，
## 所以这里减一后调他的刷新，界面上的阶段图/数值/技能格由他自己铺。
static func 切轮回六道阶段(页面: Control, 阶: int) -> void:
	页面.set("current_index", clampi(阶 - 1, 0, 7))
	if 页面.has_method("_update_ui"):
		页面.call("_update_ui")


static func 翻轮回六道页(页面: Control, 增量: int) -> void:
	var 当前: int = int(页面.get_meta("轮回六道阶", 1))
	切轮回六道阶段(页面, clampi(当前 + 增量, 1, 8))


static func 更新轮回六道页(页面: Control, 阶段: int, _状态: Dictionary) -> void:
	页面.set_meta("轮回六道阶", 阶段)
	页面.set("real_stage", clampi(阶段, 1, 8))		# 服务端回帧把灰显范围一起推进
	切轮回六道阶段(页面, 阶段)


## ── 轮回六道·技能格悬停提示 ────────────────────────────────────────────────
## 格 ↔ 技能 ↔ 道名的出处（都不是猜的）：
##   · `MToolTipLunHuiYanSkill.as:31-33`：`lunHuiYanSkill = [1,2,3,2020,2021,2022,2023,2024]`
##     与 `LUNHUIYAN_JIEDUAN_NAMES`（"六道开启#天道#畜生道#人间道#修罗道#饿鬼道#地狱道#外道"）
##     **按下标一一对应**（`:161-168 skillDuiYingJieDuan`）⇒ 2020=人间道、2021=修罗道、
##     2022=饿鬼道、2023=地狱道、2024=外道；id 1/2/3（六道开启/天道/畜生道）**原版就没有图标**
##     （`LunHuiYanPanel.as:628-660` 那三格的 skills 为空 ⇒ `SkillCell` 没 value、不挂提示），
##     对应场景里 `空技能格/空技能格2` 两格同样不接。
const 轮回技能格 := {
	"轮回·灵魂吞噬": [2020, "人间道"],
	"轮回·阿修罗形态": [2021, "修罗道"],
	"轮回·吞噬": [2022, "饿鬼道"],
	"轮回·判决": [2023, "地狱道"],
	"轮回·万象天引": [2024, "外道"],
}

## 挂提示框 —— 文案**每次悬停现算**（原版 `SkillCell.as:191-228` 每次 ROLL_OVER
## `createToolTip` 重建一份，学会与否跟着服务端回帧当场变，烘死就错）。
## ⚠️ 但框**挂窗口的 `遮罩` 层、不挂页面**（2026-10-26 用户报修「提示框只显示在轮回六道
## 面板里，下面的信息完全看不到」）：秘术子页由 `确保子页` 一律挂进 `人物扩展页`
## （Panel，`clip_contents = true`，复现面板九宫边界），提示框高 ~302px、技能格又贴在
## 页面底缘 ⇒ 框挂页面根下越出面板的下半截被**整刀裁掉**（探针实测祖先链 clip=true）。
## 原版 `MToolTip.showTip:98-103` 是 `PopUpMananger.stage.addChild(this)`，而
## `PopUpMananger.as:17` 的 stage = **flash.display.Stage**（整屏顶层弹层），
## `setLocation:123-146` 钳到 STAGE_WIDTH/HEIGHT、从不钳面板 ⇒ 等价物 = `遮罩`
## （窗口直属、global=(0,0)、链上无裁）。框常驻遮罩层，换页拆 `_content` 不丢；
## 宿主随页重建 ⇒ 接线守卫用 `is_connected`（不是框的"新建"标志，否则换页回来新宿主断线；
## 也不能用中文 `set_meta` —— 元数据名必须 ASCII，见下方接线处）。
static func 接轮回技能提示(窗口, 页面: Control, 置灰 := true) -> void:
	var 层 := _窗口提示层(窗口)
	if 层 == null:
		return
	for 格名 in 轮回技能格:
		var 宿主 := 页面.get_node_or_null("属性面板/技能格区/%s" % 格名) as Control
		if 宿主 == null:
			push_error("轮回六道页缺少技能格：%s" % 格名)
			continue
		# 未学习 ⇒ **图标**置灰（用户报修 2026-10-26；原版 `LunHuiYanPanel.as:650-655`
		# createSkillBtn：`isStudied` ⇒ dragEnabled，否则 `_loc4_.icon.filters =
		# Style.getDisableFilter()` —— 灰**只打在 icon 上**，格框与 floorText 不动，
		# 且格自己先被 `_loc4_.filters = null`(`:635`) 摘干净）。矩阵 `Style.as:63-67`
		# = 0.3086/0.6094/0.082、偏移 0 ⇒ 与工程 `禁用灰度.gdshader`（§3.296 道按钮那颗）
		# 逐系数相同，直接复用。图标是格下唯一的 TextureRect（tscn 烘的静态图；
		# `轮回六道切换.gd` 只管箭头/壁画，不碰技能格，重绘不覆盖这里）。
		# 已学分支显式清回 null：页面若是跨渲染缓存的那条路，学会后要把灰摘掉。
		if 置灰:
			var 图标: TextureRect = null
			for 子 in 宿主.get_children():
				if 子 is TextureRect:
					图标 = 子 as TextureRect
					break
			if 图标 == null:
				push_error("轮回技能格「%s」下没有图标 TextureRect（灰没有落点）" % 格名)
			else:
				var 技 := int(((轮回技能格[格名]) as Array)[0])
				# 无类型 `窗口` ⇒ 三元式必须写死返回类型（同 :3043 昆虫材料格那次 parse error）
				var 皮: ShaderMaterial = null if _技能已学(窗口, 技) else 窗口.禁用灰度材质()
				图标.material = 皮
		var 节点名 := "轮回技能提示_" + String(格名)
		var 框 := 层.get_node_or_null(节点名) as Control
		if 框 == null:
			框 = 标题提示场景.instantiate() as Control
			框.name = 节点名
			框.mouse_filter = Control.MOUSE_FILTER_IGNORE
			层.add_child(框)
		框.visible = false
		# 面板默认 PASS 收得到悬停，但格子中间的 TextureRect 与原生 tooltip 都要让位
		宿主.mouse_filter = Control.MOUSE_FILTER_PASS
		宿主.tooltip_text = ""
		# ⚠️ 别用 `set_meta("中文键")` 防重 —— Godot 元数据名必须是 ASCII 合法标识符，
		# 中文名 `set_meta` 直接报 `Invalid metadata identifier`、`has_meta` 恒 false
		# （2026-10-26 截图反向趟逮到）。改用 `is_connected`：bind 实参逐份相同 ⇒ Callable
		# 相等 ⇒ 同一宿主重复初始化不叠线，换页重建的新宿主（零连接）照接。
		var 进 := 显轮回技能提示.bind(窗口, 页面, 层, 节点名, String(格名))
		if not 宿主.mouse_entered.is_connected(进):
			宿主.mouse_entered.connect(进)
		var 出 := _藏提示.bind(层, 节点名)
		if not 宿主.mouse_exited.is_connected(出):
			宿主.mouse_exited.connect(出)


## 原版 `PopUpMananger.stage`（整屏弹层）的等价层。取不到就是窗口结构变了，
## 宁可 push_error 也别静默挂回页面里 —— 那正是被裁那一刀的病根。
## 轮回/手里剑两族的技能格提示都挂这一层（`人物扩展页` 是 clip=true 的 Panel）。
static func _窗口提示层(窗口) -> Control:
	var 层 := 窗口.get_node_or_null("遮罩") as Control
	if 层 == null:
		push_error("技能提示：窗口没有 `遮罩` 层（原版 stage 弹层等价物）")
	return 层


static func 显轮回技能提示(窗口, 页面: Control, 层: Control, 框名: String, 格名: String) -> void:
	var 框 := 层.get_node_or_null(框名) as Control
	if 框 == null:
		return
	框.设置.callv(_轮回技能提示参数(窗口, 页面, 格名))
	# 原版每次 rollOver 都 `addChild` 到 stage 末尾 = 出现即最顶（`MToolTip.showTip:103`）
	层.move_child(框, 层.get_child_count() - 1)
	框.visible = true


static func _藏提示(层: Control, 框名: String) -> void:
	var 框 := 层.get_node_or_null(框名) as Control
	if 框 != null:
		框.visible = false


## 逐行照 `MToolTipLunHuiYanSkill.formatLunHuiSkillInfo:41-83`（串取自
## `en_US$message_properties.as:148-157/296/759/2226/2482`，色号照原码字面）。
## 数组 = 标题 / 正文 / 舞台尺寸 / 标题色，直接 `设置(*参数)` 展开。
static func _轮回技能提示参数(窗口, 页面: Control, 格名: String) -> Array:
	var 项: Array = 轮回技能格[格名]
	var 技 := int(项[0])
	var 道 := String(项[1])
	var 技数 := 游戏数据表.skill(技)
	var 文案 := 游戏数据表.skill_text(技)
	var 名 := String(文案.get("name", 技数.get("name", 格名)))
	var 已学 := _技能已学(窗口, 技)
	var 描述 := ""
	if 已学:
		# 原码 `:54-55`：冷却/消耗两行绿；coolDownSecond = `DataCenter.as:529` 的
		# `seconds2DayHourMinute(FightValue.getSkillCooltime/1000)`，reqMp = `getSkillMp(id,等级)`。
		描述 = "<font color=\"#66ff00\">冷却时间：\t%s" % _秒成文(float(技数.get("cooldown", 0)))
		描述 += "<br/>消耗查克拉：\t%d</font>" % int(游戏数据表.skill_cost(技, 1).get("mp", 0))
	else:
		描述 = "<font color=\"#ff0000\">【尚未学会】</font>"	# `CN.SKILL_TOOLTIP_NOT_STUDY:759`
	描述 += "<br/><br/><font color=\"#ffffff\">描述资讯</font>"	# `CN.SKILL_TOOLTIP_DESC:296`
	if int(技数.get("skill_type", 0)) == 0:
		描述 += "<br/><font color=\"#FF9203\">【主动技能】"	# `LUNHUIYAN_SKILL_DESC_2`
	else:
		描述 += "<br/><font color=\"#FF9203\">被动加成，无需使用"	# `CN.SKILL_TOOLTIP_PASSIVIZE`
	# 原码这两行**故意不闭合 `</font>`**（`MToolTipLunHuiYanSkill:66-70`，Flash 自动补），
	# 效果就是下面"突破道名 + 技能效果"两行一路橙到底 ⇒ 这里同样留到 效果 行才闭。
	描述 += "<br/>【轮回六道突破%s后通过秘笈书学习】" % 道	# `LUNHUIYAN_SKILL_DESC_3`（%1=道名）
	描述 += "<br/>技能效果：%s</font>" % String(文案.get("desc", ""))	# `LUNHUIYAN_SKILL_DESC_4` + effectInstruction
	if not 已学:
		描述 += "<br/><br/><font color=\"#ffffff\">学习条件：</font>"	# `LUNHUIYAN_SKILL_DESC_5`
		描述 += "<br/><font color=\"#66ff00\">轮回六道需求：%s<br/>秘笈需求：《%s》" % [道, 名]	# `LUNHUIYAN_SKILL_DESC_6`（%1/%2）
		描述 += "<br/><font color=\"#FF9203\">击杀野外Boss有几率获得轮回秘笈</font>"	# `LUNHUIYAN_SKILL_DESC_7`
	return [名, 描述, 页面.get_viewport_rect().size, "ffff00"]


## `TimeAD.seconds2DayHourMinute:31-47` 逐字翻译：时分两段**只在 >0 时出现**，
## 秒恒 `toFixed(2)`；单位字 = COMMON_SHI/FEN/MIAO（"时/分/秒"，`en_US:1370/1514/1702`）。
static func _秒成文(秒: float) -> String:
	var 时 := int(秒 / 3600.0)
	var 分 := int((秒 - float(时) * 3600.0) / 60.0)
	var 余 := 秒 - float(时) * 3600.0 - float(分) * 60.0
	var 出 := "%.2f秒" % 余
	if 分 > 0:
		出 = "%d分%s" % [分, 出]
	if 时 > 0:
		出 = "%d时%s" % [时, 出]
	return 出


static func _技能已学(窗口, 技: int) -> bool:
	# `learned_skills` 里的 id 是**补零到 7 位**的字符串（`服务端会话同步.应用技能:77-79`），
	# 离线默认那份同样按这个口径比，查不到就是没学。
	var 编号 := str(技).pad_zeros(7)
	for 已 in 窗口._session.learned_skills:
		if String((已 as Dictionary).get("id", "")) == 编号:
			return true
	return false


## ── 手里剑·特殊能力图标悬停提示 ────────────────────────────────────────────
## 用户 2026-10-29 报修「角色手里剑，特殊能力，鼠标放上去没有详情框」。
## 原版整条链（`ShouLiJianPanel.as:503-543`）：`attack.skills` 里每个 id 建一枚 `SkillCellF`，
## `SkillCell.setCellValue:266-296` 里挂 `MToolTipSkill.createToolTip(stage,this,value,
## SKILL_TYPE_PLAYER)`；画布面板另补两颗给这份载荷（`:535-536`）：
##   `coolTime = SkillDataTool.getSkillCooltime(0,1)` —— **技能 id 传的是 0**，不是图标那枚
##   （`SkillDataTool.as:844-877`：0 号表 `info.cool_down = {cdBase:1.12}`、无 cdLevel ⇒ 1120ms）；
##   `isShouLiJianSkill = true`。
## 于是 `SkillUtil.formatSkillInfo:89-92` 只走那一支，正文三行：
##   绿「冷却时间：X秒」→ 白「描述资讯」→ 橙 `effectInstruction`（= `getSkillDesc`，`技能文案.desc`）。
## 后面 `:98-121` 的学习条件段要 `isStudied && teshuSkill`、或 `studyReqSkillId` 查得到技能书 ——
## 手里剑六条 `reqBook` 全空（`数据/技能文案.json` 0009100..0009105）⇒ 原版这里一个字都不加。
## 标题色 #ffff00 / 居中（`MToolTipSkill:56-58` `_loc4_.color = 16776960`）。
##
## ⚠️ 技能 id **每次悬停现算**：图标跟着预览阶换（4 阶 1 枚、5 阶 2 枚、6/7 阶 3 枚），
##    烘死在接线上就会拿上一阶的 id 报这一阶的名（原版每枚格自带载荷，不存在这问题）。
## ⚠️ 原版 `MToolTipSkill` 还会在框里画技能图标（`:79-87` 的 `MGrid_background` + `getSkillPic`）——
##    本工程 `标题文字提示框` 没有图位，轮回那条同样没画（既有偏离，不在本轮扩）。
## 框挂 `遮罩`（同轮回那套的裁剪理由，见 `_窗口提示层`）。
static func 接手里剑技能提示(窗口, 页面: Control) -> void:
	var 层 := _窗口提示层(窗口)
	if 层 == null:
		return
	for 位 in 3:
		var 宿主 := 页面.get_node_or_null("详情面板/技能图标%d" % (位 + 1)) as Control
		if 宿主 == null:
			continue
		var 节点名 := "手里剑技能提示_%d" % (位 + 1)
		var 框 := 层.get_node_or_null(节点名) as Control
		if 框 == null:
			框 = 标题提示场景.instantiate() as Control
			框.name = 节点名
			框.mouse_filter = Control.MOUSE_FILTER_IGNORE
			层.add_child(框)
		框.visible = false
		# tscn 里三枚图标都是 `mouse_filter = 2`（忽略），不收鼠标就永远等不到悬停
		宿主.mouse_filter = Control.MOUSE_FILTER_PASS
		宿主.tooltip_text = ""
		var 进 := 显手里剑技能提示.bind(窗口, 页面, 层, 节点名, 位)
		if not 宿主.mouse_entered.is_connected(进):
			宿主.mouse_entered.connect(进)
		var 出 := _藏提示.bind(层, 节点名)
		if not 宿主.mouse_exited.is_connected(出):
			宿主.mouse_exited.connect(出)


static func 显手里剑技能提示(窗口, 页面: Control, 层: Control, 框名: String, 位: int) -> void:
	var 框 := 层.get_node_or_null(框名) as Control
	if 框 == null:
		return
	var 技 := int(页面.call("预览技能id", 位))
	if 技 <= 0:
		框.visible = false		# 这一阶这几格本来就没铺（图也藏着），别亮个空框
		return
	框.设置.callv(_手里剑技能提示参数(技, 页面))
	层.move_child(框, 层.get_child_count() - 1)
	框.visible = true


## 逐行照 `SkillUtil.formatSkillInfo:89-97`（串取自 `en_US$message_properties.as:2482/296`，
## 色号照原码字面）。数组 = 标题 / 正文 / 舞台尺寸 / 标题色，直接 `设置(*参数)` 展开。
static func _手里剑技能提示参数(技: int, 页面: Control) -> Array:
	var 文案 := 游戏数据表.skill_text(技)
	# 原版这行取的是 **0 号技能**的冷却（`ShouLiJianPanel.as:535` 传死 0），不是图标那枚 ——
	# 六个手里剑技能的 `info.cool_down` 根本不会被读到。照抄，别"顺手改成技"。
	var 冷却毫秒 := float(游戏数据表.skill(0).get("cooldown", 0.0)) * 1000.0
	var 描述 := "<font color=\"#00ff00\">冷却时间：%s秒</font><br/><br/><br/>" % _毫秒成秒(冷却毫秒)
	描述 += "<br/><font color=\"#ffffff\">描述资讯</font>"
	描述 += "<br/><font color=\"#FF9203\">%s</font>" % String(文案.get("desc", ""))
	return [String(文案.get("name", "")), 描述, 页面.get_viewport_rect().size, "ffff00"]


## AS3 的 `Number` 落成字符串是"最短可逆"写法：`1120/1000` → `"1.12"`、`2000/1000` → `"2"`。
## GDScript 的 `str(2.0)` 会给 `"2.0"` ⇒ 整数秒要去掉尾巴，否则和原版逐字对不上。
static func _毫秒成秒(毫秒: float) -> String:
	var 秒 := 毫秒 / 1000.0
	if is_equal_approx(秒, roundf(秒)):
		return str(int(roundf(秒)))
	return String.num(秒, 3)


static func 发送修炼请求(窗口, 动作: String, 参数: Array) -> void:
	var 后端 = 窗口._backend
	if 后端 == null or not bool(后端.in_game):
		窗口._session.notification_requested.emit("尚未连接原版游戏服务器")
		return
	var 已发送 := false
	match 动作:
		"手里剑启用": 已发送 = 后端.request_shuriken(0, bool(参数[0]))
		"手里剑突破": 已发送 = 后端.request_shuriken(1)
		"手里剑提速": 已发送 = 后端.request_shuriken(2, bool(参数[0]))
		"八门统计": 已发送 = 后端.request_bamen(1)
		"八门突破": 已发送 = 后端.request_bamen(3)
		# 开通穴道：`MAI 动作 2 + (门序号, 该门穴位下标, 用几个八门铜人)`（§3.162）
		"八门开通": 已发送 = 后端.request_bamen(2, int(参数[0]), int(参数[1]),
			int(参数[2]) if 参数.size() > 2 else 0)
		# 结印只有**一跳**这一个动作（byte 0 = `requestJieYin_EatUp`）；自动提升是客户端
		# 每 0.8 秒重发这一发，不是第二个动作（byte 1 `eatUpAutoConsumeAllZq` 原版无人调用）。
		"结印提升": 已发送 = 后端.request_jieyin()
		"柔拳提升": 已发送 = 后端.request_rouquan_stage_up()
		"写轮眼提升": 已发送 = 后端.request_xielunyan_stage_up()
		"轮回六道提升": 已发送 = 后端.request_lunhuiyan_stage_up()
		# 三个字段（原版 `requestStrengthKunChong(position, 用镇灵石, 寄坏玉张数)` →
		# `ITEM_CHANGE` 25）：少了后两个 ⇒ 镇灵石"保护"与寄坏玉加成**都不会生效**。
		"寄坏强化": 已发送 = 后端.request_kunchong_strength(
			int(参数[0]), bool(参数[1]) if 参数.size() > 1 else false,
			int(参数[2]) if 参数.size() > 2 else 0)
	if not 已发送:
		窗口._session.notification_requested.emit("请求发送失败，请检查原版服务器连接")
		return
	# 发成功**不提示**（用户 2026-10-18 报修：每点一次刷一句「已发送，等待服务器确认」，
	# 呆板又不流畅；结印那条还有客户端 0.8 秒自动重发，更是刷屏）。
	# 原版这一跳一个 `addNotice` 都没有：`ShouLiJianTiShengWindow.as:160/171` 的提速、
	# `ThroughShouLiJianWindow.toPoHandler:193-218` 的突破（那四条 `addNotice` 全是**客户端预检失败**），
	# 点下去只发包，结果由服务端回帧把画面刷出来 —— 玩家看的本来就是画面。

static func 显示修炼说明(窗口, 文本: String) -> void:
	窗口._session.notification_requested.emit(文本)

static func 设置标签(窗口, 面板: Control, 路径: String, 文本: String, 颜色: Color, 字号: int = 12) -> void:
	var 标签 := 面板.get_node(路径) as Label
	标签.text = 文本
	窗口._configure_label(标签, 字号, 颜色)

## 顶部信息格（原版 `CharInfoCell`）：标题 #fcc399 + 数值各自一个 Label。
## 标题色和 12 号都是从原版基线逐像素量出来的（字形墨迹高 12px、RGB 252,195,153）。
static func 设置信息格(窗口, 面板: Control, 格名: String, 标题: String, 值: String, 值色: Color) -> void:
	设置标签(窗口, 面板, "信息区/%s/名称" % 格名, 标题, 信息标题色, 12)
	设置标签(窗口, 面板, "信息区/%s/数值" % 格名, 值, 值色, 数值字号)


static var _人物文案: Dictionary = {}


## 语言表原文（`数据/界面/人物_文案.json`，由 `开发工具/出人物文案数据.py` 抽）。
## 键名照抄原版 ⇒ 想核原文就 `grep CHARACTOR_ 2.2.3/…/en_US$message_properties.as`。
## **取不到键不返回空串、返回键名**：空串画出来是"提示框一片白"，查起来没有线索。
static func 键(名: String) -> String:
	if _人物文案.is_empty():
		_人物文案 = JSON.parse_string(FileAccess.get_file_as_string(人物文案路径))
	var 值 = _人物文案.get(名, null)
	if 值 == null:
		push_error("人物_文案.json 缺键：%s（跑 python 开发工具/出人物文案数据.py 重出）" % 名)
		return 名
	return String(值)


## `CN.replaceString(模板, a, b)`：占位符是 `%1/%2`（`CN.as:5392-5404`），不是 `%s`。
static func 填(模板: String, 参数: Array) -> String:
	var 出 := 模板
	for i in 参数.size():
		出 = 出.replace("%%%d" % (i + 1), str(参数[i]))
	return 出


## 挂 / 刷新一枚 `MToolTipText`（`场景/界面/组件/文字提示框.tscn`）。
## 与意志页那份同法，两条要紧处都别改：
##   · **节点常驻页面根**、文案每次重画现填 ⇒ 数据一跳就跟着跳（烘死会红：门 ⑭b）；
##   · 悬停连接只在**首次建**时连一次。⚠️ 这一条**不是**性能闸：Godot 对"同一对象 + 同一方法
##   + 同一 bind"的 `connect` 去重，把它挪出 `if 新建` 也叠不出第二根线（2026-10-21 反向对照
##   实测，门 ⑭c 照样绿）。留着它只为读起来跟原版 `addMouseListener` 的一次性一致。
static func _挂文字提示(页面: Control, 面板: Control, 路: String, 文案: String, 名: String) -> void:
	var 宿主 := 面板.get_node_or_null(路) as Control
	if 宿主 == null:
		push_error("人物窗口.tscn 缺少提示宿主节点：%s" % 路)
		return
	var 节点名 := "文字提示_" + 名
	var 框 := 页面.get_node_or_null(节点名) as Control
	var 新建 := 框 == null
	if 新建:
		框 = 文字提示场景.instantiate() as Control
		框.name = 节点名
		框.mouse_filter = Control.MOUSE_FILTER_IGNORE
		页面.add_child(框)
	框.设置(确认弹.文案转BBCode(文案), 页面.get_viewport_rect().size)
	框.visible = false
	# 原版 `CharPane.as:199-204` 先把这些文本框 `mouseEnabled = true` 才挂得上提示；
	# Godot 的 Label 默认 `MOUSE_FILTER_IGNORE`（收不到悬停）⇒ 同一步在这儿补。
	宿主.mouse_filter = Control.MOUSE_FILTER_PASS
	宿主.tooltip_text = ""		# 原生提示一律让位给原版提示框
	if 新建:
		宿主.mouse_entered.connect(_显提示.bind(节点名, 页面, true))
		宿主.mouse_exited.connect(_显提示.bind(节点名, 页面, false))


## 用**节点名**现取现显（不捕获对象引用 ⇒ 页面拆了也不会打到 Nil）。
static func _显提示(节点名: String, 页面: Control, 显: bool) -> void:
	var 框 := 页面.get_node_or_null(节点名) as CanvasItem
	if 框 != null:
		框.visible = 显

static func 设置状态条(窗口, 面板: Control, 名称: String, 当前值: int, 最大值: int) -> void:
	var 状态条 := 面板.get_node("%s条" % 名称) as ProgressBar
	# `CharPane.as:55/59` 的 hpBar/mpBar 是 MBar ⇒ 填充 0.5s 爬、文案立刻写（`MBar.as:151-168` 在前、
	# `:170` 在后）。以前这里 `状态条.value = 当前值` 不夹 ⇒ 服务端多给一点就画到槽外。
	进度条补间.灌值(状态条, float(当前值), float(最大值), [当前值, 最大值])
	var 数值 := 面板.get_node("%s数值" % 名称) as Label
	数值.text = "%d/%d" % [当前值, 最大值]
	窗口._configure_label(数值, 数值字号, Color.WHITE)

## ⚠️ 意志格的悬停提示**不再**有专门的 `_接意志格悬停()`：合并 `意志模块` 时分支带进来一份，
##    与主线 §3.234 的十处悬停框架（上面 `_挂文字提示(..., "信息区/意志格", ...)`）争同一个格
##    ——同一枚信号挂两条通路，后建的会把先建的 disconnect 掉。现只留 §3.234 那条（`文字提示框`），
##    原版对位仍是 `CharPane.setYiZhiData:290-299` 的 `MToolTipText`，正文同一个
##    `意志提示框.意志力提示文案()`。

static func 调整临时加点(窗口, 属性键: String, 增量: int) -> void:
	var 当前 := int(窗口._character_pending_ap.get(属性键, 0))
	窗口._character_pending_ap[属性键] = maxi(0, 当前 + 增量)
	窗口._render_page()

static func 取消临时加点(窗口) -> void:
	窗口._character_pending_ap = {"ap_atk": 0, "ap_def": 0, "ap_dex": 0, "ap_phy": 0}
	窗口._render_page()

static func 推荐加点(窗口) -> void:
	var 剩余 := int(窗口._session.player_stats.get("remaining_ap", 0))
	var 分配 := [floori(剩余 * 2.0 / 5.0), floori(剩余 / 5.0), floori(剩余 / 5.0), floori(剩余 / 5.0)]
	var 未分配: int = 剩余 - int(分配[0]) - int(分配[1]) - int(分配[2]) - int(分配[3])
	for 序号 in mini(未分配, 4):
		分配[序号] += 1
	窗口._character_pending_ap = {"ap_atk": 分配[0], "ap_def": 分配[1], "ap_dex": 分配[2], "ap_phy": 分配[3]}
	窗口._render_page()

static func 确认临时加点(窗口) -> void:
	var 分配: Dictionary = 窗口._character_pending_ap
	var 后端 = 窗口._backend
	var 成功 := false
	if 后端 != null and bool(后端.in_game):
		成功 = 后端.request_distribute_ap(int(分配.ap_atk), int(分配.ap_def), int(分配.ap_dex), int(分配.ap_phy))
	else:
		成功 = true
		for 属性键 in ["ap_atk", "ap_def", "ap_dex", "ap_phy"]:
			for _序号 in int(分配[属性键]):
				if not 窗口._session.allocate_attribute(属性键):
					成功 = false
					break
	if 成功:
		窗口._character_pending_ap = {"ap_atk": 0, "ap_def": 0, "ap_dex": 0, "ap_phy": 0}
	窗口._render_page()


## 人物面板下方的**套装四图标**（等阶 / 全紫 / 满星 / 六级满融）。
##
## 出处 `EquipPane.as:918-927` 的 `setSeriesIcon()`：
##   `isSameStage / isAllPurple / isFullStar / isFullStone`
##   （`ItemFactory.as:491 / 510 / 676 / 255`）。
## ⚠️ 原版**不是用 visible 开关**，而是 `filters`：
##   条件为真 `filters = null`（点亮），为假套 `Style.getDisableFilter()`（灰化）——
##   四个图标**恒可见**，只是灰或亮。这里用项目已有的 `禁用灰度材质()` 对应。
##
## ⚠️ 阈值**全是硬编码**，既不来自配置也不来自服务端：
##   * 同阶 = **12 件**且 `stage` 全相同（`TOTAL_EQUIP_COUNT = 12`，`ItemFactory.as:47`）
##   * 全紫 = 每件品质是 **4(紫) 或 5(橙)**（`CocoEquip.as:16/18`）
##   * 满星 = 每件 `strengthenLevel **>= 10**`（`ItemFactory.as:389-396`）
##   * 满融 = 每件镶嵌槽 **>= 5** 且宝石等级 **>= 6**（`ItemFactory.as:875-904`）
## ⚠️ 参与判定的只有**标准 12 槽**（`EquipPane.as:884` 把时装/玉炼/徽章滤掉了），
##   而且件数 **<= 11** 时列表为空 —— **四灯一律全灰**。
## —— 装备格的点击语义（原版 `char/EquipPane.as`）——
## 真值：单击有货格 ⇒ `MPopupMenu([卸下, 发到聊天框])`（`:254-289`，位置 `cell.x+20, cell.y+20`）；
##   Ctrl+单击 ⇒ 直接 `chatPane.insertShowItem`（`:239-243`）；**双击才 `unequip`**（`:440-450`）。
##   两格多档：灵器格里的开光十拳剑（20200001）多一档「改变外观」
##   （`:258-264` → `:469-471` 发 `2081:4`，回帧才开窗）；忍具格里的八咫镜
##   （65000001 未开光 / 65000002 已开光）多四档「切换为火/水/雷/风抗」
##   （`:269-275` → `:472-483` 发 `2082:4:1..4`），而且**双击这一格不是卸下**：
##   `:394-402` 先 `requestRenJuResistance(0)` 再 `return` ⇒ 让服务端轮下一档，`unequip` 走不到。
## 我们原来**单击即卸**，比原版快一步、也丢了聊天入口 —— 本轮改正。
## `卸下` = `CN.XIE_XIA`（`en_US$message_properties.as:3260`，"卸下"不是"卸除"）。
const 双击间隔毫秒 := 300
const 卸下 := "卸下"
## 灵器格里**只有这一件**多一档菜单（`EquipPane.as:258-264`：`id == 20200001`）。
## 文案出处同文件 `:50 MENU_CHANGE_LINGQI_FACE = "改变外观"`。
const 改变外观 := "改变外观"
const 开光十拳剑 := 20200001
## 忍具格里的八咫镜多四档（`EquipPane.as:269-275`：id 是 **65000001（未开光）/ 65000002（已开光）**
## 才出这四行；同文件 `:394-402` 的双击用的是**同一个条件**，所以判定只写一处 `忍具可切抗`）。
## 文案逐字抄 `:52-58` 那四条常量；顺序照 `:274` 的数组顺序，别按拼音排。
const 八咫镜档 := [65000001, 65000002]
const 切换为火抗 := "切换为火抗"
const 切换为水抗 := "切换为水抗"
const 切换为雷抗 := "切换为雷抗"
const 切换为风抗 := "切换为风抗"
## 菜单项 → 上行的元素号（`:472-483` 四发 `requestRenJuResistance(1/2/3/4)`）。
## ⚠ 这张表**同时是菜单顺序**（`装备菜单项` 直接 `keys()`）⇒ GDScript Dictionary 保序，
##   改这里的行序 = 改屏上的菜单序，门里 ① 那条会盯着。
## 号与名和服务端同一份：`YATA_RESISTANCE_NAMES = {1:火, 2:水, 3:雷, 4:风}`。
const 忍具抗性档 := {切换为火抗: 1, 切换为水抗: 2, 切换为雷抗: 3, 切换为风抗: 4}
## 双击那一发的"轮下一档"（`:398` 写死 0，服务端按 `YATA_RESISTANCE_CYCLE` 取下一档）。
const 抗性轮档 := 0
static var _上次装备格 := ""
static var _上次装备时刻 := 0
static var _当前菜单格 := {}      ## {"位置": int, "物品": Dictionary}

## 单击/双击/Ctrl 三态接线。**先断再连**：每次重渲染都新建闭包，不断会撞
## "already connected"（背包同款的坑，注释在 `背包窗口._选中格子`）。
static func _接装备格点击(窗口, 页面: Control, 装备格: Button, 位置: int, 物品: Dictionary) -> void:
	for 连 in 装备格.pressed.get_connections():
		装备格.pressed.disconnect(连["callable"])
	装备格.pressed.connect(_装备格按下.bind(窗口, 页面, 装备格, 位置, 物品))
static func _装备格按下(窗口, 页面: Control, 装备格: Button, 位置: int, 物品: Dictionary) -> void:
	if 物品.is_empty():
		return
	if Input.is_key_pressed(KEY_CTRL):
		_装备格发聊天(窗口, 物品)
		return
	var 本刻 := Time.get_ticks_msec()
	var 键 := str(位置)
	if 键 == _上次装备格 and 本刻 - _上次装备时刻 <= 双击间隔毫秒:
		_上次装备时刻 = 0
		var 收 := 页面.get_node_or_null("物品菜单") as Control
		if 收 != null:
			收.call("收起")
		# 八咫镜双击**不卸下**：原版 `EquipPane.as:394-402` 先拦一手 `requestRenJuResistance(0)`
		# （0 = 让服务端按 `YATA_RESISTANCE_CYCLE` 轮下一档）就 `return`，`unequip` 那行走不到。
		if 忍具可切抗(位置, 物品):
			_发忍具抗性(窗口, 抗性轮档)
			return
		窗口._unequip(位置)
		return
	_上次装备格 = 键
	_上次装备时刻 = 本刻
	var 菜单 := 页面.get_node_or_null("物品菜单") as Control
	if 菜单 == null:
		return
	_当前菜单格 = {"位置": 位置, "物品": 物品}
	var 项表 := 装备菜单项(位置, 物品)
	# 弹点是原版口径：格的 (x+20, y+20)。菜单挂在**页面根**，所以把格子的全局点换回页面局部
	# （我们的格子嵌套在 `装备栏/装备格子容器` 下，原版 cell 直接挂 EquipPane —— 换算不假设层级）。
	var 局部 := 页面.get_global_transform().affine_inverse() * (装备格.global_position + Vector2(20.0, 20.0))
	菜单.call("弹出", 项表, 局部, 窗口._舞台尺寸())

## 装备格右键/单击菜单的项表（`EquipPane.as:250-270`）。
## 基础两档所有人都有；`改变外观` 只给**灵器格里的开光十拳剑（20200001）**——
## 未开光那件 id 是 20100001，原版**不出**这一项（服务端也不给脸表解锁）；
## `切换为×抗` 只给**忍具格里的八咫镜**（`忍具可切抗`），四档一起出、不分当前是哪档
## （原版四行恒在，点了才换 —— `:274` 那条数组没有条件过滤）。
static func 装备菜单项(位置: int, 物品: Dictionary) -> Array:
	var 项表 := [卸下, 物品菜单组件.发到聊天框]
	if 位置 == 装备部位表.灵器 and int(str(物品.get("id", "0"))) == 开光十拳剑:
		项表.append(改变外观)
	elif 忍具可切抗(位置, 物品):
		项表.append_array(忍具抗性档.keys())
	return 项表

## 这一格是不是"能换属性抗性的八咫镜"：位置 = 忍具格 **且** id 在 `八咫镜档` 里。
## 原版菜单（`:272`）与双击（`:396`）两条支路共用同一个条件 ⇒ 判定只写这一处。
static func 忍具可切抗(位置: int, 物品: Dictionary) -> bool:
	return 位置 == 装备部位表.忍具 and 八咫镜档.has(int(str(物品.get("id", "0"))))

## 发一档八咫镜抗性（`元素` = `忍具抗性档` 里的号，或 `抗性轮档` 0 = 轮下一档）。
## 原版两处调用点都**只发包、不等回帧、不给本地提示**（`RenJuProcessor` 收端没有 4 这一档，
## 见 `后端连接.request_renju_resistance` 的注释）⇒ 这里也不许加"已发送"之类的话。
## 单拿一个函数出来是因为菜单与双击两个入口都要它，且离线门要拿替身后端验那条包。
static func _发忍具抗性(窗口, 元素: int) -> void:
	var 后端: Node = 窗口.get_node_or_null("/root/BackendConnection")
	if 后端 == null or not 后端.has_method("request_renju_resistance"):
		return
	后端.call("request_renju_resistance", 元素)

static func 装备菜单选择(窗口, 项名: String) -> void:
	var 那 := _当前菜单格
	if 那.is_empty():
		return
	match 项名:
		卸下:
			窗口._unequip(int(那["位置"]))
		物品菜单组件.发到聊天框:
			_装备格发聊天(窗口, 那["物品"] as Dictionary)
		改变外观:
			# 原版 `onClickPopupMenu:469-470` 只发 `requestLingQiFaceList()`，
			# 回帧才 `showWindow(脸表, 色表)` ⇒ 本窗也是"先发后建"。
			var 遮罩 = 窗口.get("_overlay")
			if not (遮罩 is Control):
				return
			var 后端: Node = 窗口.get_node_or_null("/root/BackendConnection")
			灵器外观选择窗.弹出(遮罩 as Control, 后端)
		切换为火抗, 切换为水抗, 切换为雷抗, 切换为风抗:
			# 原版 `:472-483` 四发 `requestRenJuResistance(1..4)`，一句本地提示都没有。
			# 号码从 `忍具抗性档` 取，别在这里手写数字 —— 那是第二份口径。
			_发忍具抗性(窗口, int(忍具抗性档[项名]))

static func _装备格发聊天(窗口, 物品: Dictionary) -> void:
	# 按 group 找聊天面板：多窗化（窗口管理）之后父链 `窗口.get_parent()` 指的是窗口管理，
	# 拿不到与它平级的聊天面板（背包菜单那条同病，2026-10-02 一并改）。
	var 聊天: Node = 窗口.get_tree().get_first_node_in_group("chat_panel")
	if 聊天 != null and 聊天.has_method("insert_show_item"):
		聊天.insert_show_item(String(物品.get("id", "")), String(物品.get("name", "")))

const 套装图标名 := ["等阶套装", "全紫套装", "满星套装", "六级满融套装"]
const 计数角标名 := ["紫件数", "满星件数", "满融件数"]

## 判定 / 计数 / 拼串的**一处口径**在 `脚本/单例/套装提示.gd`。
## 原来这里内联着五个谓词，且满融读 `"level"` 键——服务端镶嵌条目是 `stone_level`，
## ⇒ **在线满融灯永远不亮**（离线门读不到，因为测试字典里就是 "level"）。2026-10-01 合并修正。
## `装备表` 传了（Dictionary，含**空表**）就按它判：看别人 = 原版 `setSeriesIcon(param1)`
## 用**他的**数组那条支（`EquipPane.as:872-877`）；不传（null）才读 `会话.equipped_items`。
## 上面 `渲染人物页` 传进来的永远是**这一页真正在画的那张表**，所以两条支不会串。
static func _更新套装图标(面板: Control, 会话, 装备表: Variant = null) -> void:
	var 栏 := 面板.get_node_or_null("装备栏")
	if 栏 == null:
		return
	var 亮 := 套装提示.四灯(会话, 装备表)
	for i in 套装图标名.size():
		var 图 := 栏.get_node_or_null("套装图标/%s" % 套装图标名[i]) as TextureRect
		if 图 == null:
			push_error("人物窗口.tscn 缺少套装图标节点：装备栏/套装图标/%s" % 套装图标名[i])
			continue
		# 用**预烘焙灰版贴图**换图（原版是滤镜；本项目那个着色器在此路径不生效，
		# 灰版按 `StyleUtil.getGrayFilter()` 同系数离线算的，值一致）。
		图.texture = load("res://素材/界面/原版窗口/人物/角色/套装_%s%s.png" % [
			套装图标名[i], "" if bool(亮[i]) else "_灰"]) as Texture2D
		_接套装灯悬停(面板.get_parent() as Control, 会话, 图, i, 装备表)
	_更新计数角标(栏, 套装提示.计数(会话, 装备表))

## 四灯的悬停 = 原版 `seriesEquipTooltips`（`EquipPane.as:942` 给每枚灯挂 `MToolTipText`）。
## ⚠️ **计数角标原版没有悬停**，我们也不发明。
static func _接套装灯悬停(页面: Control, 会话, 图: TextureRect, 灯: int, 装备表: Variant = null) -> void:
	if 页面 == null or 图 == null:
		return
	图.mouse_filter = Control.MOUSE_FILTER_STOP   # 场景里默认 IGNORE，收不到悬停
	for 连 in 图.mouse_entered.get_connections():
		图.mouse_entered.disconnect(连["callable"])
	for 连 in 图.mouse_exited.get_connections():
		图.mouse_exited.disconnect(连["callable"])
	图.mouse_entered.connect(func() -> void:
		var 框 := 页面.get_node_or_null("套装提示框") as Control
		if 框 == null:
			return
		框.call("显示提示", 套装提示.提示html(灯, 会话, 装备表), 页面.get_local_mouse_position()))
	图.mouse_exited.connect(func() -> void:
		var 框 := 页面.get_node_or_null("套装提示框") as Control
		if 框 != null:
			框.call("收起"))

static func _更新计数角标(栏: Control, 数: Dictionary) -> void:
	var 值 := [int(数.get("紫", 0)), int(数.get("星", 0)), int(数.get("融", 0))]
	for i in 计数角标名.size():
		var 根 := 栏.get_node_or_null("强化计数/%s" % 计数角标名[i]) as Control
		if 根 == null:
			push_error("人物窗口.tscn 缺少计数角标节点：装备栏/强化计数/%s" % 计数角标名[i])
			continue
		根.visible = 值[i] > 0
		var 字 := 根.get_node_or_null("数字") as Label
		if 字 != null:
			字.text = str(值[i])

## 四灯的悬停 = 原版 `seriesEquipTooltips`（`EquipPane.as:942` 给每枚灯挂 `MToolTipText`）。
## ⚠️ **计数角标原版没有悬停**，我们也不发明。

# ── 「人物属性（看别人）」= 原版 `CharOtherWindow2` ──────────────────────────────
# 真值：`真值/窗口/人物属性_看别人.md`（入口链 / 逐件矩形 / 52 段字段表 / 四颗钮协议）。
# 与「看自己」共用同一个场景与 `渲染`，差别只有两处：数据源换成 `58:4` 那一帧、
# 以及把「加点面板」换成「他人信息面板」（`CharPane.as:255-270 set isMyself`）。

## `58:4` 解出来的档 → 喂 `渲染人物页` 的**属性字典**。
## 键名按那一帧的下标对位（表见真值 §⑥），**不按名字猜**：服务端那两个函数叫
## `_current_critical/_current_evasion`，原版字段却叫 `bsk`/`avd`。
static func 别人档转属性(档: Dictionary) -> Dictionary:
	return {
		"name": String(档.get("名", "忍者")),
		"level": int(档.get("等级", 1)),
		"job": int(档.get("职业", 0)),
		"family": String(档.get("家族", "-")),
		"crime": int(档.get("罪恶值", 0)),
		"spouse": String(档.get("配偶", "-")),
		"exp": int(档.get("经验", 0)),
		"max_exp": maxi(1, int(档.get("经验上限", 1))),
		# 精华分母是**写死的常数**，与本帧那个数无关：`CharPane.as:241` 用的就是
		# `UIConfig.ZQ_MAX`（本机 2.2.3 `UIConfig.as:910` = 500000，同 `技能面板.gd:143`）。
		"breath": int(档.get("精华", 0)),
		"max_breath": 500000,
		# 血/蓝四条：帧里叫「血 / 血上限 / 蓝 / 蓝上限」，`渲染人物页` 读的是 hp/max_hp/mp/max_mp。
		# 漏了这四条 ⇒ 看别人那扇生命/查克拉两行永远写 `0/1`（分支门 ④ 当场红）。
		"hp": int(档.get("血", 0)), "max_hp": maxi(1, int(档.get("血上限", 1))),
		"mp": int(档.get("蓝", 0)), "max_mp": maxi(1, int(档.get("蓝上限", 1))),
		# 加点那一块在只读档里根本不显示，但 `渲染人物页` 还是会读这四个键 ⇒ 给 0，不给假值。
		"ap_atk": 0, "ap_def": 0, "ap_dex": 0, "ap_phy": 0, "remaining_ap": 0,
		"attack": int(档.get("攻击", 0)),
		"defense": int(档.get("防御", 0)),
		"critical": int(档.get("暴击", 0)),
		"dodge": int(档.get("闪避", 0)),
		"attack_speed": int(档.get("攻击速度", 0)),
		"move_speed": int(档.get("移动速度", 0)),
	}

## 四颗钮的悬停/按下两档皮。基名那张（`窗内按钮.png`）烤在 .tscn 的 `texture_normal` 上，
## 这里只列派生两档 —— 三档一律换 `texture_normal`，不用 `texture_hover/pressed`
## （原版 `MButton3.as:103-108` 松手回 `STATE_UP`，Godot 的 hover 槽松手后只要鼠标还悬着会停在悬停档）。
const 他人钮派生皮 := {
	"密语钮": ["res://素材/界面/原版窗口/人物/角色/窗内按钮_悬停.png",
			"res://素材/界面/原版窗口/人物/角色/窗内按钮_按下.png"],
	"交易钮": ["res://素材/界面/原版窗口/人物/角色/窗内按钮_悬停.png",
			"res://素材/界面/原版窗口/人物/角色/窗内按钮_按下.png"],
	"加友钮": ["res://素材/界面/原版窗口/人物/角色/窗内按钮_悬停.png",
			"res://素材/界面/原版窗口/人物/角色/窗内按钮_按下.png"],
	"组队钮": ["res://素材/界面/原版窗口/人物/角色/窗内按钮_悬停.png",
			"res://素材/界面/原版窗口/人物/角色/窗内按钮_按下.png"],
}
## 提示文案 = 顶栏那排钮同一批语言键（`DetailsWindow.as:113`）。
const 他人钮提示 := {"密语钮": "私聊", "交易钮": "邀请交易", "加友钮": "加为好友", "组队钮": "组队邀请"}
## 钮上的文字色：`MButton3._textColors[STATE_UP]` = `#fcf49c`。
const 他人钮文字色 := Color("#fcf49c")


## 看别人：藏掉「加点面板」整套、亮出「他人信息面板」，填三根条、接四颗钮。
## 件名与矩形已烘在场景里（分支那条线摆好的），这里只喂值与接线。
static func 切到他人信息面板(窗口, 面板: Control, _属性: Dictionary, 档: Dictionary) -> void:
	# 加点那一整套只在"看自己"时存在（`CharPane.as:255-270`）
	# ⚠ 三件的**真名**：底板 `加点属性底板`、标题 `加点属性标题`、内容 `基础属性`
	#   （原来写成 `加点属性区`，`get_node_or_null` 返回 null ⇒ 那一块**没被藏掉**、和他人信息面板叠在一起）。
	# ⚠ 七件**一起隐**：底板只是背景，其余六件是它的兄弟节点 —— 藏背景带不走文字与钮
	#   （原版 `CharPane.as:255-270` 是两个整实例二选一，`addPointPane.visible = isMyself`）。
	for 名 in ["加点属性底板", "加点属性标题", "基础属性", "潜能点", "潜能点值", "确认加点", "推荐加点"]:
		var 件 := 面板.get_node_or_null(名) as CanvasItem
		if 件 != null:
			件.visible = false
	var 块 := 面板.get_node_or_null("他人信息面板") as Control
	if 块 == null:
		push_error("人物窗口.tscn 缺少 原版人物属性面板/他人信息面板")
		return
	块.visible = true
	# 三根条的分母都是**原版定值**（本机 2.2.3 `UIConfig.as` 行号：`:978 SKILL_MAX_POINTS = 5400`、
	# `:982 CHENG_JIU_MAX_POINTS = 503`）—— 不是从帧里拿的，别拿帧里的数当分母。
	看别人条(窗口, 块, "忍术境界", int(档.get("忍术境界", 0)), 5400)
	# ⚠ 这一根按真值 §⑥ 的注：帧里下标 26 = `jingmaiLevel`（`经脉等级`）、27 = `jinmaiTotalLevel`
	#   （`八门进度`），**条上写的是 26/27** ⇒ 当前取 26、上限取 27。别按条的名字反过来取。
	看别人条(窗口, 块, "八门进度", int(档.get("经脉等级", 0)), int(档.get("八门进度", 0)))
	看别人条(窗口, 块, "成就进度", int(档.get("成就点", 0)), 503)
	# 四颗钮：三态换皮 + 手型 + 各发各的协议（原版 `CharPointInfoPane.as:110-209`）。
	_接他人钮(窗口, 块)

## 一根条：`MBar.as:129-170` 的口径 —— `cur > total` 先夹到 total；`total == 0` 时比例按 1 画满
## （实机图里八门进度 `0/0` 就是一根满条）；文字 = `cur + "/" + total`（`showPercent` 没开）。
static func 看别人条(窗口, 块: Control, 条名: String, 当前: int, 上限: int) -> void:
	var 槽 := 块.get_node_or_null("%s槽" % 条名) as ProgressBar
	if 槽 == null:
		push_error("他人信息面板 缺少 %s槽" % 条名)
		return
	# 三条都在 `灌值` 里按 `上限 <= 0 ⇒ 满条` 画（`MBar.as:140-149`，注释以前也是这么写的，
	# 但代码里 `maxi(1, 上限)` + `clampi(当前, 0, 上限)` 恰好把它画成了**空条**）。
	进度条补间.灌值(槽, float(当前), float(上限), [当前, 上限])
	var 值 := 块.get_node_or_null("%s值" % 条名) as Label
	if 值 != null:
		窗口._configure_label(值, 数值字号, Color.WHITE)
		值.text = "%d/%d" % [当前, 上限]

## 四颗钮：三态换皮 + 手型 + 各发各的协议。**每开一次页都是新页面新节点 ⇒ 先断再连**
## （同 `头像面板._接目标钮` 的写法，重渲染撞 already-connected 是工程老坑）。
static func _接他人钮(窗口, 块: Control) -> void:
	var 后 = 窗口.get("_backend")
	var 号 := int(窗口.get("_他人档案").get("cid", 0))
	var 名 := String(窗口.get("_他人档案").get("名", ""))
	for 钮名 in 他人钮派生皮:
		var 钮 := 块.get_node(钮名) as TextureButton
		var 皮: Array = [钮.texture_normal]
		for 路 in 他人钮派生皮[钮名]:
			皮.append(load(路) as Texture2D)
		钮.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		钮.tooltip_text = String(他人钮提示[钮名])
		for 信 in [钮.mouse_entered, 钮.mouse_exited, 钮.button_down, 钮.button_up]:
			for 连 in 信.get_connections():
				信.disconnect(连["callable"])
		钮.mouse_entered.connect(_设他人钮态.bind(钮, 皮, 1))
		钮.mouse_exited.connect(_设他人钮态.bind(钮, 皮, 0))
		钮.button_down.connect(_设他人钮态.bind(钮, 皮, 2))
		钮.button_up.connect(_设他人钮态.bind(钮, 皮, 0))
		窗口._configure_label(钮.get_node("文字") as Label, 12, 他人钮文字色)
	## 原版 `CharPointInfoPane.as:238-239`：`tradeBtn.enabled = true`、
	## `troopBtn.enabled = !isInTroop(id)` —— 已在队的人**那颗钮是灰的**（不是点了报错）。
	var 交易 := 块.get_node("交易钮") as TextureButton
	var 组队 := 块.get_node("组队钮") as TextureButton
	交易.disabled = false
	组队.disabled = bool(窗口.get("_他人已在队"))
	var 动作表 := [
		["密语钮", _他人密语.bind(窗口, 名)],
		["交易钮", _他人交易.bind(窗口, 号, 交易)],
		["加友钮", _他人加好友.bind(窗口, 号, 名)],
		["组队钮", _他人组队.bind(窗口, 名)],
	]
	for 对 in 动作表:
		var 钮 := 块.get_node(String(对[0])) as BaseButton
		var 动作: Callable = 对[1] as Callable
		if 钮.pressed.is_connected(动作):
			钮.pressed.disconnect(动作)
		钮.pressed.connect(动作)


## 三档一律换 `texture_normal`（0 up / 1 悬停 +30 / 2 按下 −40），**松手回 up**。
static func _设他人钮态(钮: TextureButton, 皮: Array, 态: int) -> void:
	if 皮.is_empty() or 态 >= 皮.size() or 皮[态] == null:
		return
	钮.texture_normal = 皮[态] as Texture2D


## 密　语 —— `CharPointInfoPane.as:180-185` `ChatEvent.CHECK_ONLINE`：**不发包**，
## 把聊天框切到私聊、预填 `/名字 `（与顶栏那颗同一套做法，见 `头像面板._目标私聊`）。
static func _他人密语(窗口, 名: String) -> void:
	if 名.is_empty():
		return
	for 节 in 窗口.get_tree().get_nodes_in_group("chat_panel"):
		if 节.has_method("开始私聊"):
			节.call("开始私聊", 名)
			return
	窗口._通知("请在聊天框输入 /%s 消息" % 名)


## 交　易 —— ① 点下去当场 `enabled=false` 防连点（`CharPointInfoPane.as:110-113`）；
## ② 转发出去之后关掉本窗（`CharOtherWindow2.as:80-86`）。
static func _他人交易(窗口, 号: int, 钮: TextureButton) -> void:
	var 后 = 窗口.get("_backend")
	if 号 <= 0 or 后 == null or not bool(后.get("in_game")):
		窗口._通知("邀请交易需要在线")
		return
	钮.disabled = true
	if not bool(后.call("request_trade_invite", 号)):
		钮.disabled = false
		窗口._通知("邀请交易发送失败")
		return
	窗口.close()


## 加　友 —— 已经是好友**不发包**，只提示（`CharPointInfoPane.as:194-200`）。
static func _他人加好友(窗口, 号: int, 名: String) -> void:
	var 后 = 窗口.get("_backend")
	if 号 <= 0 or 后 == null or not bool(后.get("in_game")):
		窗口._通知("加好友需要在线")
		return
	if bool(后.call("is_friend", 号)):
		窗口._通知("该玩家已经是你的好友")
		return
	if not bool(后.call("request_friend_add", 号)):
		窗口._通知("加好友请求发送失败")


## 组　队 —— 按**名字**发 `120:4`；转发后同样关掉本窗（`CharOtherWindow2.as:173-179`）。
static func _他人组队(窗口, 名: String) -> void:
	var 后 = 窗口.get("_backend")
	if 名.is_empty() or 后 == null or not bool(后.get("in_game")):
		窗口._通知("邀请组队需要在线")
		return
	if not bool(后.call("request_party_invite", 名)):
		窗口._通知("邀请组队发送失败")
		return
	窗口.close()
