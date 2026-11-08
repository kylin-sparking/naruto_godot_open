extends RefCounted
## 双修邀请窗（原版 `YaoqingShuangxiuWindow`）控制器。逐件真值：`真值/窗口/双修邀请窗.md`。
##
## 触发不是"点某颗钮开窗"，而是**服务端推的一帧**：邀请者点目标信息条菜单「双修」⇒
## 服务端 `DOUBLE_INVITE` 给对方发 `1288:2:<邀请者角色号>` ⇒
## `后端连接._handle_heal_text:3826-3828` 存进 `authoritative_heal.pending_inviter_id`
## 并发 `heal_state_received` ⇒ `窗口管理` 那侧开这一页。
##
## ⚠ 那一帧**只带角色号**，四行字要的名字/等级/家族/职业/头像得自己取 ——
## 原版是从 `dataCenter` 里那个人的 `CharacterInfo` 拿（`setData:200-211`），
## 本工程对应的就是同屏表 `map_players`（服务端下发的，带 name/level/face/job）。
## 查不到人 ⇒ 整页不建（宁可什么都不出现，也不要弹一扇「昵称：」后面空白的窗）。

## 六条文案的语言键与原文（`原版数据.语言(键)` 现查，2.2.3优化版 message 包）。
## 运行期直接用字面量：本工程没有语言表可读，且**键与原文都记在这儿**，改文案时能对上出处。
const 标题 := "双修打坐"					# YAOQING_SHUANGXIU_WINDOW_TITLE
const 说明原文 := "<font color=\"#ff9100\">该玩家希望与你开始打坐双修</font><br/><font color=\"#00ff00\">开始双修后，打坐的双方在精华和经验<br/>获得速度上将比单独打坐加快20%</font><br/><font color=\"#1e90ff\">请问你同意开始双修吗？"	# YAOQING_SHUANGXIU_WINDOW_SAY
const 昵称前 := "昵称："					# NICKNAME（值自带冒号）
const 等级前 := "等级"					# CHARACTOR_LEVEL（不带冒号，代码里补）
const 家族前 := "家族"					# CHARACTOR_FAMILY
const 职业前 := "职业"					# CHARACTOR_JOB
const 职业表 := preload("res://脚本/单例/职业.gd")

## `setData():206-209` 四行的拼法。⚠ `NICKNAME` 的语言值**自带冒号**（`昵称：`），
## 而 `等级/家族/职业` 那三个不带 ⇒ 代码里再补 `"："`（原版就是这么写的，别统一）。
static func 四行(态: Dictionary) -> Dictionary:
	return {
		"昵称": 昵称前 + String(态.get("name", "")),
		"等级": 等级前 + "：" + str(int(态.get("level", 0))),
		"家族": 家族前 + "：" + _家族名(态),
		"职业": 职业前 + "：" + 职业表.取(int(态.get("job", 0))),
	}

static func _家族名(态: Dictionary) -> String:
	## ⚠ 键名只有一个：`family_name` —— 它是**出生帧 162 第 24 段**解出来的那一份
	## （`后端连接._handle_spawn_player_text`，出处 `fake_flash_server._foreign_player_payload:15188-15230`）。
	## 这里原来轮着找 `guildName`/`guild`/`familyName`/`bangName` **四个我自己起的名字**，
	## 而喂进来的 `map_players` 那份里一个都没有 ⇒ 这行永远印成「家族：」后面空白，
	## 而离线门的夹具字典照抄了同一套自造键 ⇒ 门与代码一起错（10-17 同一条坑第三次，见对戒那一处）。
	## 没家族服务端发的是字面 `-` ⇒ 当"没有"，屏幕上就是「家族：」后面空着（原版也没家族时不编名字）。
	var 值 := String(态.get("family_name", ""))
	return "" if 值 == "-" else 值

## `sayTf.htmlText = CN.YAOQING_SHUANGXIU_WINDOW_SAY`（`:117`）—— 三段不同颜色的
## `<font>` + `<br/>`，Godot 侧走 BBCode（`<font>` 要转 `[color]`，口径同全工程其它富文本）。
static func 说明文() -> String:
	var 原文 := 说明原文
	return 原文.replace("<br/>", "\n").replace("<br>", "\n") \
			.replace("<font color=\"#ff9100\">", "[color=#ff9100]") \
			.replace("<font color=\"#00ff00\">", "[color=#00ff00]") \
			.replace("<font color=\"#1e90ff\">", "[color=#1e90ff]") \
			.replace("</font>", "[/color]")

## 建页 + 填数据 + 接三颗钮。`宿主` = 一个 `功能窗口` 实例（页壳）。
static func 渲染(宿主: Node, 场景: PackedScene, 号: int, 态: Dictionary) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	var 行 := 四行(态)
	(页.get_node("昵称") as Label).text = String(行["昵称"])
	(页.get_node("等级") as Label).text = String(行["等级"])
	(页.get_node("家族") as Label).text = String(行["家族"])
	(页.get_node("职业") as Label).text = String(行["职业"])
	(页.get_node("说明") as RichTextLabel).text = 说明文()
	## `setPic():75-90` = `PortraitHead(true,42,42,TYPE_CHAR)`，`skin = face` ⇒ 按 face 取头像，
	## 等比塞进 42×42 的格子里居中（`TextureRect.stretch_mode = 4` 就是 `min(w/bmp.w, h/bmp.h)`）。
	var 脸 := str(int(态.get("face", 1))).pad_zeros(8)
	(页.get_node("头像格/头像") as TextureRect).texture = \
			OriginalSprite.portrait("character", 脸)
	(页.get_node("同意钮") as Button).pressed.connect(_点同意.bind(宿主, 号))
	(页.get_node("取消钮") as Button).pressed.connect(_点取消.bind(宿主, 号))
	(页.get_node("查看资料钮") as Button).pressed.connect(_点查资料.bind(号))
	return 页

## `onClickAccedeBtn():53-62`：发 `TONGYI_SHUANGXIU`（= `86:4:<邀请者号>`）然后**自己从父节点摘掉**。
static func _点同意(宿主: Node, 号: int) -> void:
	var 后 := _后端(宿主)
	if 后 != null:
		后.call("request_double_heal_accept", 号)
	宿主.call("关掉双修邀请")

## `onClickCancelBtn():124-127` 只是转调 `onCloseBtnClick():64-73` ⇒ 右上角那颗叉与「取消」同一发
## （`86:5:<邀请者号>`；服务端 `DOUBLE_DENY` 会给邀请者回 `1288:4:<我的号>`）。
static func _点取消(宿主: Node, 号: int) -> void:
	var 后 := _后端(宿主)
	if 后 != null:
		后.call("request_double_heal_deny", 号)
	宿主.call("关掉双修邀请")

## `onClickDatumBtn():188-191` = `API.ui.clickCharacter(id)` = `94:4:<id>`。
## ⚠ "别人的人物窗"这一扇本工程还没移植（见 `真值/窗口/目标信息条.md` §⑪）⇒ 这里只发得出请求。
static func _点查资料(号: int) -> void:
	var 后 := _后端(null)
	if 后 != null and bool(后.call("get", "in_game")):
		后.call("request_character_info", 号)

## ⚠ 必须写 `var 后: Node = ...` 这种**带类型**的接法：`Engine.get_main_loop()` 回来的是
## MainLoop，链式 `.root` 是 Variant ⇒ `:=` 推不出类型直接 parse 失败，
## 而这份脚本是 功能窗口.gd preload 进来的 ⇒ 一坏就把整个功能窗口拖死（实测）。
static func _后端(_宿主: Node) -> Node:
	var 树 := Engine.get_main_loop() as SceneTree
	return 树.root.get_node_or_null("BackendConnection") if 树 != null else null
