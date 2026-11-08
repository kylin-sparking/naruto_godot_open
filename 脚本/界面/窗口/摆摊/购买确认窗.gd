extends RefCounted
## 摊位确认窗（原版 `StallUpShelfWindow`）—— **一扇窗、两档**：
## `BUY_OPERATION`（买家点「购买」，两个价栏只读）与 `WUPING_UP_OPERATION`
## （摊主点背包落一件，两个价栏可输入、钮文字换「上架」）。两档在原文里是**同一个类**
## （`_operation` 一个字段决定，`:152` 那句 `enableInput = 操作==BUY ? false : true`），
## 所以本工程也共用这一份脚本与同一张 `.tscn`，不再开第二个文件各抄一遍矩形。
## 逐件真值 = `真值/窗口/随身摊位窗.md` §⑤（166×186，页根 166×157）。
##
## 「购买」那颗钮点下去**不是直接发帧**：原版是 `buyHandler → showUpShelfWindow(选中项, BUY_OPERATION)`
## （`StallWindow.as:593-604`）⇒ 先开这一扇，在本扇里比过余额才 `requestStallBuyItem`（`:334`）并关窗。

const 摊位窗 := preload("res://脚本/界面/窗口/摆摊/摊位窗.gd")		# 只取它那两个脚本级槽（待买 / 上架单）
const 确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")		# `MDialog.showMessageDialog` 的移植件

## 文案的语言键（`原版数据.语言(键)` 现查，2.2.3优化版）。
## 标题「物品购买」(`STALL_UPSHELF_WINDOW_TITEL`, `:92`) 烘在 `数据/界面/窗口尺寸.json` 的「摊位购买」条目里，不在这里重复。
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")		# autoload 名叫 `GameData`，页面一律本地 preload 后用中文别名
const 钮文字 := "购买"						# SHOP_BUY
const 名称前 := "物品名称："					# STALL_UPSHELF_WINDOW_ITEM_NAME（值自带冒号）
const 数量前 := "数量："						# STALL_UPSHELF_WINDOW_COUNT（自带冒号）
const 总价前 := "总价："						# DIALOG_NEED_MONEY_STRING「总价」**不带**冒号 ⇒ 代码补 `"："`（`:255`）
const 币名 := ["游戏金币", "商城元宝"]			# ITMEWINDOW_MONEY / ITMEWINDOW_YUANBAO
const 金不足 := "对不起，你的金币不足"			# UNION_QUITE_SORRY_NOT_COIN_YOU
const 宝不足 := "很抱歉，你的元宝不足！"			# SORRY_DEFICIENCY_COIN

## ---------- 上架档（`WUPING_UP_OPERATION`）那四句话与上限 ----------
const 上架钮文字 := "上架"						# STALL_UPSHELF_WINDOW_UP_SHELF（`:292`）
const 价上限 := 999999999						# `MAX_MONEY`（`:29`）
const 价未填 := "请填写要出售物品的价格！"			# MDIALOG_4（`:221`）
const 金超 := "你输入的金币数量已超过最大限制！"		# MDIALOG_1（`:202`）
const 宝超 := "你输入的元宝数量已超过最大限制！"		# MDIALOG_2（`:207`）
const 太便 := "您设置的价格太便宜了！"				# MDIALOG_3（`:212`，**这一句带确定回调**）

## `矩形` = 页局部框（AS3 − 29），全按 §⑤ 的算式。门直接读这张表。
const 矩形 := {
	"内容底": [8.0, 9.0, 150.0, 118.0],			# `UIWindow.as:36-39`+`:64-65`：x=8、y=38、w=166−16、h=186−68
	"名称标签": [16.0, 11.0, 95.0, 20.0],		# `:229-233`
	"物品格": [113.0, 15.0, 40.0, 40.0],		# `:235-238` x = 8+150−40−5
	"名称框": [16.0, 33.0, 85.0, 20.0],		# `:239-244` setSize(85,20)、y = 40+20+2
	"数量行": [16.0, 56.0, 141.0, 20.0],		# `:245-250` FormItem2 = 40+4+97
	"数量标签": [0.0, 0.0, 40.0, 20.0],		# `FormItem2.as:76` titleLabel.width
	"数量文": [44.0, 0.0, 97.0, 20.0],		# `:78` x = 标题.x + 40 + gap(4)
	"总价标签": [16.0, 76.0, 40.0, 20.0],		# `:251-257`
	"价1底": [56.0, 76.0, 98.0, 21.0],		# `:258-267` x = 总价.x + 40、y = 总价.y
	"价1输入": [56.0, 76.0, 98.0, 21.0],		# 上架档才露（`:152`）；同框换件，与 `价1底` 严丝合缝
	"价1文": [77.0, 79.0, 74.0, 18.0],		# paddingLeft 21 ⇒ 56+21；textField.y = 3 ⇒ 76+3
	##   宽 = 98 − 21 − paddingRight(3) = 74、高 = 21 − 3 = 18（`ScrollTextField:122-127` 那件内层
	##   textField 铺满 MTextInput2 去掉 y 偏移的余下高度，同 `摊位行.gd:46` 那一族同一个算法）
	"金币": [59.0, 78.0, 17.0, 17.0],		# `:268-270` goldItem + (3,2)
	"价2底": [56.0, 100.0, 98.0, 21.0],		# `:282-283` y = 76 + 21 + 3
	"价2输入": [56.0, 100.0, 98.0, 21.0],
	"价2文": [77.0, 103.0, 74.0, 18.0],
	"元宝": [59.0, 103.0, 19.0, 13.0],		# `:284-286` yuanBaoItem + (3,3)
	"确定钮": [68.0, 130.0, 30.0, 22.0],		# `:290-296` y = 186−22−5；宽 = 文字(24) + 6（isScale9Grid）
}

## 把两档（货币页 / 普通页）的六个显示值一次算出来（纯函数 ⇒ 门可以拿任意挂牌直接核对，不必开窗）。
static func 显示(项: Dictionary) -> Dictionary:
	var 行: Dictionary = 项.get("行", {}) as Dictionary
	var 货币页 := bool(项.get("货币页", false))
	var 段: PackedStringArray = String(行.get("payload", "")).split("&")
	var 种 := int(行.get("kind", 0))
	var 出 := {"名称": "", "数量": "", "价1": str(int(行.get("point_price", 0))),
			"价2": str(int(行.get("cash_price", 0))), "要金币": 0, "要元宝": 0}
	if 货币页:
		## 负载 = `是否金币&金币数&元宝数`：卖金币 ⇒ 用元宝付；卖元宝 ⇒ 用金币付。
		var 是金币 := int(段[0]) if 段.size() > 0 else 0
		var 金币数 := int(段[1]) if 段.size() > 1 else 0
		var 元宝数 := int(段[2]) if 段.size() > 2 else 0
		出["名称"] = 币名[0] if 是金币 == 1 else 币名[1]
		出["数量"] = str(金币数) if 是金币 == 1 else str(元宝数)
		## `:89-90` 两格都写字：卖金币 ⇒ 金币格 "0"、元宝格 = 要付的元宝数。
		出["价1"] = "0" if 是金币 == 1 else str(金币数)
		出["价2"] = str(元宝数) if 是金币 == 1 else "0"
		出["要金币"] = 0 if 是金币 == 1 else 金币数
		出["要元宝"] = 元宝数 if 是金币 == 1 else 0
	elif 种 == 3:
		## `_encode_pet` 段序：`宠物号&位置&1&0&0&可交易&主人&0&唯一号&主人号&宠物名&等级&…`
		出["名称"] = String(段[10]) if 段.size() > 10 else ""
		出["数量"] = "1"						# `:118` `_itemData.count = 1`
	else:
		## `_encode_item_payload` 段序：`族&物品号&槽&数量&…`
		var 号 := int(段[1]) if 段.size() > 1 else 0
		出["名称"] = 游戏数据.item_name(号)
		出["数量"] = str(int(段[3])) if 段.size() > 3 else "1"
	return 出


static func 渲染(宿主: Node, 场景: PackedScene, 项: Dictionary) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	var 显 := 显示(项)
	(页.get_node("名称标签") as Label).text = 名称前
	(页.get_node("数量行/数量标签") as Label).text = 数量前
	(页.get_node("总价标签") as Label).text = 总价前
	(页.get_node("名称框/名称文") as Label).text = String(显["名称"])
	(页.get_node("数量行/数量文") as Label).text = String(显["数量"])
	(页.get_node("价1文") as Label).text = String(显["价1"])
	(页.get_node("价2文") as Label).text = String(显["价2"])
	(页.get_node("确定钮") as Button).text = 钮文字
	_格(页, 项)
	(页.get_node("确定钮") as Button).pressed.connect(_点购买.bind(宿主, 项))
	## 标题「物品购买」由 `数据/界面/窗口尺寸.json` 的「摊位购买」条目烘进外壳（= `:92`
	## `title = CN.STALL_UPSHELF_WINDOW_TITEL`），不在运行期再设一遍。
	return 页


## 格子里画什么：物品图标 / 宠物头像 / 货币（UISwf 那两枚符号本工程没导 ⇒ 空格子，见真值表 §⑨）。
static func _格(页: Control, 项: Dictionary) -> void:
	var 行: Dictionary = 项.get("行", {}) as Dictionary
	var 段: PackedStringArray = String(行.get("payload", "")).split("&")
	var 种 := int(行.get("kind", 0))
	var 图 := 页.get_node("物品格/图标") as TextureRect
	var 角标 := 页.get_node("物品格/数量角标") as Label
	图.texture = null
	角标.text = ""
	if bool(项.get("货币页", false)) or 种 == 10:
		return
	if 种 == 3:
		图.texture = OriginalSprite.portrait("pet", str(int(段[0]) if 段.size() > 0 else 0))
		图.position = Vector2(2.0, 2.0)
		图.size = Vector2(36.0, 36.0)
		角标.text = "1"						# `:121` `_icon.label` 走的是 count=1
		return
	var 号 := int(段[1]) if 段.size() > 1 else 0
	var 路 := 游戏数据.item_icon_path(号)
	if 路 != "" and ResourceLoader.exists(路):
		var 寸: Vector2 = (load(路) as Texture2D).get_size()
		图.texture = load(路)
		图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		图.stretch_mode = TextureRect.STRETCH_SCALE
		图.position = Vector2(roundf((40.0 - 寸.x) / 2.0), roundf((40.0 - 寸.y) / 2.0))
		图.size = 寸
	角标.text = str(int(段[3])) if 段.size() > 3 and int(段[3]) > 1 else ""


## `buyItem():301-337`：先比余额（比哪一对由 `ISTABBTNMONEY` 决定），过了才发 `1296:7:` 并关窗。
## 余额取不到 ⇒ **不许放行**（放行等于"没钱也能点购买"），只报"还没连上服务端"。
static func _点购买(宿主: Node, 项: Dictionary) -> void:
	## 走宿主的 `_backend`（和 `摊位窗` 同一支），不自己按节点名再找一遍 ⇒
	## 门里换假后端能同时管住"入帧"和"出帧"两条。
	var 后: Node = 宿主.get("_backend") as Node
	if 后 == null:
		后 = Engine.get_main_loop().root.get_node_or_null("BackendConnection") as Node
	if 后 == null:
		宿主._show_hint("还没连上服务端。")
		return
	var 显 := 显示(项)
	var 钱 := _余额(后, "money")
	var 宝 := _余额(后, "cash")
	if bool(项.get("货币页", false)):
		if int(显["要金币"]) > 钱:
			宿主._通知(金不足)
			return
		if int(显["要元宝"]) > 宝:
			宿主._通知(宝不足)
			return
	else:
		if int(显["价1"]) > 钱:
			宿主._通知(金不足)
			return
		if int(显["价2"]) > 宝:
			宿主._通知(宝不足)
			return
	var 行: Dictionary = 项.get("行", {}) as Dictionary
	## `requestStallBuyItem(_data.characterid, _playerName, _data.uid)`（`:334`）
	## 服务端 `handle_stall_action` action 7：**先按卖家号找人，号不中再按名字找，两个都不中 ⇒ 什么都不回**。
	if not bool(后.call("request_stall_buy", int(项.get("摊主号", 0)),
			String(项.get("摊主名", "")), int(行.get("uid", 0)))):
		宿主._show_hint("购买请求没发出去（摊位信息不完整）。")
		return
	## 关掉这扇（原版 `onCloseBtnClick → PopUpMananger.removeWindow`，`:165-168`）。
	## 顺手清掉脚本级那条"待买"记录 ⇒ 就算这扇被重新渲染一次，也不会拿旧挂牌再发一遍购买帧。
	摊位窗.待买 = {}
	宿主.call("close")


static func _余额(后: Node, 键: String) -> int:
	return int((后.get("authoritative_stats") as Dictionary).get(键, 0))


## ---------- 上架档（`WUPING_UP_OPERATION = 0`，`StallUpShelfWindow.as:130-151`）----------

## 摊主档与买家档**只差两个价栏的 `enableInput`**（`:152`）+ 钮文字（`:135`）+ 标题
## （`:136` `title = CN.STALL_UP_SHELF_BUTTON_NAME` =「物品上架」，烘在 `窗口尺寸.json` 的「摊位上架」条目）。
## 场景里两件同框叠着（`价1文` Label + `价1输入` LineEdit），这里换的是**哪一件露面** ——
## 与 `摊位窗` 摊名那一格同一个做法，别改成运行期新建控件。
##
## 宠物档（`PET_UP_OPERATION = 2`）与物品档同一扇窗，只换「格子里画什么」和发送那一条
## （`setData:130-151` 把 `_itemData` 造了个 `{id,name,count:1}` 空壳并画头像）。
static func 渲染上架(宿主: Node, 场景: PackedScene, 单: Dictionary) -> Control:
	var 页 := 场景.instantiate() as Control
	宿主._content.add_child(页)
	var 宠: Dictionary = 单.get("宠物", {}) as Dictionary
	var 物品: Dictionary = 单.get("物品", {}) as Dictionary
	var 名称 := String(物品.get("name", ""))
	var 数 := str(int(物品.get("quantity", 1)))
	if not 宠.is_empty():
		名称 = String(宠.get("name", ""))
		数 = "1"							# `setData:145` `_itemData.count = 1`
	(页.get_node("名称标签") as Label).text = 名称前
	(页.get_node("数量行/数量标签") as Label).text = 数量前
	(页.get_node("总价标签") as Label).text = 总价前
	(页.get_node("名称框/名称文") as Label).text = 名称
	(页.get_node("数量行/数量文") as Label).text = 数
	(页.get_node("价1文") as Label).visible = false
	(页.get_node("价2文") as Label).visible = false
	## 初值「0」是原文那两句（`:133-134`），**不是**占位符 —— 原版两格里确实写着 0。
	var 金 := 页.get_node("价1输入") as LineEdit
	var 宝 := 页.get_node("价2输入") as LineEdit
	金.text = "0"
	宝.text = "0"
	金.visible = true
	宝.visible = true
	## `textField.restrict = "0-9"` ⇒ 照 `拆分窗口/存取金额窗口` 那一族的数字过滤。
	## `maxChars = 9` 烘在场景的 `max_length` 上（只钳**打字**，`text =` 赋值不钳 ⇒ 门可以塞十位数进去
	## 验 `MDIALOG_1/2` 那两支）。
	金.text_changed.connect(_只留数字.bind(金))
	宝.text_changed.connect(_只留数字.bind(宝))
	(页.get_node("确定钮") as Button).text = 上架钮文字
	if 宠.is_empty():
		_格上架(页, 物品)
	else:
		_格宠(页, 宠)
	## ⚠ 把**开这一扇时那一件**绑进回调，不在点下去时回读脚本级 `上架单` ——
	## 原文是 `showUpShelfWindow` 把参数存进实例字段 `_itemData`（`:305`），
	## 判定与发包都读那个字段。回读静态槽的话，中途关掉摊位窗（`关窗清态` 会把槽清空）
	## 再按这扇的「上架」，就会拿 `type 0 / 格 0` 发出一帧垃圾。
	(页.get_node("确定钮") as Button).pressed.connect(_点上架价.bind(宿主, 页, 单))
	return 页


## `restrict "0-9"` 的移植件（同 `拆分窗口.gd:61-68`、`存取金额窗口.gd:125-138` 那一族）。
## ⚠ 这里**不做上限钳值**：原版超限那一档不是拦下来，而是点「上架」时弹「已超过最大限制」并且**不发帧**
## （`upShelf():200-209`）⇒ 数留在框里让玩家自己改。照 `存取金额窗口` 那样当场钳成 999999999，
##   那两句话就永远弹不出来（那是"更好的输入体验"，不是原版的语义）。
static func _只留数字(新文本: String, 件: LineEdit) -> void:
	var 过滤 := ""
	for 字 in 新文本:
		if 字 >= "0" and 字 <= "9":
			过滤 += 字
	if 过滤 != 新文本:
		件.text = 过滤
		件.caret_column = 过滤.length()


## 上架档的格子：画**背包里那一件**（买家档 `_格` 画的是挂牌 payload，两件数据源不同）。
## 段数/角标口径与 `:132` `_itemData = param1` 一致 —— 直接用物品字典，不反解 payload。
static func _格上架(页: Control, 物品: Dictionary) -> void:
	var 图 := 页.get_node("物品格/图标") as TextureRect
	var 角标 := 页.get_node("物品格/数量角标") as Label
	图.texture = null
	角标.text = ""
	var 路 := String(物品.get("icon", ""))
	if 路 != "" and ResourceLoader.exists(路):
		var 寸: Vector2 = (load(路) as Texture2D).get_size()
		图.texture = load(路)
		图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		图.stretch_mode = TextureRect.STRETCH_SCALE
		图.position = Vector2(roundf((40.0 - 寸.x) / 2.0), roundf((40.0 - 寸.y) / 2.0))
		图.size = 寸
	var 数 := int(物品.get("quantity", 1))
	角标.text = str(数) if 数 > 1 else ""


## 宠物档的格子：`setData:130-151` 造一个 `Count=1` 的空壳并画 `PortraitHead(TYPE_PET, itemId)`
## （`this._icon.width - 4` = 36×36）。角标恒「1」（买家档 `_格` 里同一句）。
static func _格宠(页: Control, 宠: Dictionary) -> void:
	var 图 := 页.get_node("物品格/图标") as TextureRect
	var 角标 := 页.get_node("物品格/数量角标") as Label
	## ⚠ 头像资源键是**八位补零**的 `Pet_<id>_info_portrait`（`_parse_pet_fields` 给的 `id` 就是
	## 补零串）；直接拿 `item_id`（101）去查会拿到 null ⇒ 空头像。与 `宠物格.gd:54` 同一口径。
	var 图号 := String(宠.get("id", ""))
	if 图号.is_empty():
		图号 = str(int(宠.get("item_id", 0))).pad_zeros(8)
	图.texture = OriginalSprite.portrait("pet", 图号)
	图.position = Vector2(2.0, 2.0)
	图.size = Vector2(36.0, 36.0)
	角标.text = "1"


## 「上架」（`upShelf():196-223`）四道判式，**顺序照原文**：
## 两格都是 0 → `MDIALOG_4`；金币 > 上限 → `MDIALOG_1`；元宝 > 上限 → `MDIALOG_2`；
## 有 `price` 且 金币 < `price/3` 且 元宝 == 0 → `MDIALOG_3`（**带确定回调**，点头像那句才发）；
## 其余 → 直接 `sureToUpShelf`。
static func _点上架价(宿主: Node, 页: Control, 单: Dictionary) -> void:
	var 金 := String((页.get_node("价1输入") as LineEdit).text).to_int()
	var 宝 := String((页.get_node("价2输入") as LineEdit).text).to_int()
	if 金 <= 0 and 宝 <= 0:
		_弹(宿主, 价未填)
		return
	if 金 > 价上限:
		_弹(宿主, 金超)
		return
	if 宝 > 价上限:
		_弹(宿主, 宝超)
		return
	var 物品: Dictionary = 单.get("物品", {}) as Dictionary
	## `Boolean(_itemData.hasOwnProperty("price"))`：宠物档的 `_itemData` 只造了 `{id,name,count}`
	## （`setData:145-147`）⇒ 没有 `price`，这一闸天然跳过。
	## 背包物品字典里**有**这个键就算（值 0 也算，但 `0/3 = 0`、而 `金 > 0` 已由上面第一道保证
	## ⇒ 那一支天然不会误弹）。
	if 单.has("宠物"):
		_发上架(宿主, 单, 金, 宝)
		return
	if 物品.has("price") and 金 < int(物品.get("price", 0)) / 3.0 and 宝 == 0:
		_弹(宿主, 太便, func(码: int) -> void:
			if 码 == 1:
				_发上架(宿主, 单, 金, 宝))
		return
	_发上架(宿主, 单, 金, 宝)


## `sureToUpShelf():183-194`：物品发 `4:<category>:<position>:<count>:<金>:<宝>`，
## 宠物发 `requestStallAddPetToStall(uniqueId, 金, 宝)` ⇒ `1296:5:`；发完**立刻**
## `onCloseBtnClick`（= `PopUpMananger.removeWindow`）⇒ 这一扇是自己关自己的。
static func _发上架(宿主: Node, 单: Dictionary, 金: int, 宝: int) -> void:
	var 后: Node = 宿主.get("_backend") as Node
	if 后 == null:
		宿主._show_hint("上架需要连接服务端")
		return
	var 宠: Dictionary = 单.get("宠物", {}) as Dictionary
	if not 宠.is_empty():
		if not bool(后.call("request_stall_add_pet", int(宠.get("unique_id", 0)), 金, 宝)):
			宿主._show_hint("上架请求没发出去（宠物信息不完整）")
			return
		摊位窗.上架单 = {}
		宿主.call("close")
		return
	var 物品: Dictionary = 单.get("物品", {}) as Dictionary
	## `category` 取的是**编码族号**（`ItemFactory.as:1049` `_loc6_.category = _loc11_`，
	## `_loc11_` 就是报文第 0 段那个 type）⇒ 本工程的 `物品["type"]`，不是字典里那个中文 `category`。
	if not bool(后.call("request_stall_add_item", int(物品.get("type", 0)),
			int(单.get("格", 0)), int(物品.get("quantity", 1)), 金, 宝)):
		宿主._show_hint("上架请求没发出去（物品信息不完整）")
		return
	## 清掉这一件：不关模式（原版光标还在，能连续挂），但**不许留旧单** ——
	## 留着的话下一次开窗会拿上一件的名字与格号再发一遍。
	摊位窗.上架单 = {}
	宿主.call("close")


## 四句 `MDialog.showMessageDialog` 的落点（模态弹、只有确定）。
## 没有遮罩层（门里直接 call 静态函数、宿主没建过 `_overlay`）⇒ 退化成一句 `_通知`，总之不许静默。
static func _弹(宿主: Node, 正文: String, 回调: Callable = Callable()) -> void:
	var 遮罩 := 宿主.get("_overlay") as Control
	if 遮罩 == null:
		宿主._通知(正文)
		if 回调.is_valid():
			回调.call(1)
		return
	确认弹.弹消息(遮罩, 正文, 回调 if 回调.is_valid() else func(_码: int) -> void: pass)
