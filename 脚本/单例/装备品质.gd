extends RefCounted
## 装备资质（品质）—— 格子/提示框上那圈边框、名字颜色、紫橙流光的**唯一一份**真值。
##
## 值从 `数据/装备品质.json` 读（表怎么来的见 `开发工具/导出装备品质.mjs`，
## 里面每一项都能追到 AS3 的字面量行号），**不要在本文件里再抄一遍颜色或素材名**。
##
## 为什么这里必须留一段说明，不然下次一定又被类名带偏：
##   AS3 的常量名和实际颜色是**交叉**的 —— `APTITUDE_BLUE=2` 用的是 `EquipAptitudeGreenF`
##   （绿色框、绿名字 #08ff19），`APTITUDE_GREEN=3` 用的是 `EquipAptitudeBlueF`
##   （蓝色框、蓝名字 #009cff）。出处 `ItemWindowCell.showIcon` :239-252、
##   `MToolTipZhuangBei.createEqpTipSprite` :158-168，两处一致，就是原版的写法。
##   所以：**表里的「名」跟协议（blue/green...），「颜色名」和素材文件跟实测像素**。
##
## 老素材文件名（`素材/界面/原版窗口/人物/角色/资质_蓝.png` 其实是绿框）正是被类名
## 带偏留下的，本表一律指向 `素材/界面/装备品质/` 下按真实颜色命名的那批。

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

## 流光那个动画件（只管「进场→默认」两段怎么接）。
## 覆盖层的**挂载**也归本文件管（`挂覆盖层`），这样格子、列表行、提示框走的是同一条路。
const 品质流光 := preload("res://脚本/界面/组件/品质流光.gd")

## 灵气（十拳剑）id 前缀。原版 `ItemType.getTypeFromId` = 8 位补零后的前两位 == 20。
const 灵气前缀 := "20"

## 玉链按阶推显示档要反查部位（`装备部位.gd` 是纯表、无 preload，不成环）。
const 装备部位 := preload("res://脚本/单例/装备部位.gd")

static var _缓存 := {}


static func 表() -> Dictionary:
	if _缓存.is_empty():
		_缓存 = 游戏数据.取表("装备品质")
	return _缓存


## 补齐 8 位，短 id 直接当数字传进来也能查。
static func _八位(物品id: Variant) -> String:
	return String(物品id).pad_zeros(8) if String(物品id).is_valid_int() else String(物品id)


static func 是灵气(物品id: Variant) -> bool:
	return _八位(物品id).begins_with(灵气前缀)


## 忍具（八咫镜那一族，`RenJuData`）。与灵气一样是**整族**恒粉框 + 流光，不看 aptitude：
## `ItemWindowCell.addRenJuItemFrame`（`:191-204`）、人物面板的 `RenJuCell.setCellValue`
## （`:85-92`）、`MToolTipRenJuTip`（`:93-102`）三处都是建格子/提示框时无条件 `new EquipAptitudePinkF()`。
## 判族跟 `装备部位.位置` 同一口径（id 前七位 65 ⇒ 忍具 -24），不另抄一份 id 表。
static func 是忍具(物品id: Variant) -> bool:
	return 装备部位.位置(_八位(物品id)) == 装备部位.忍具


## 某一档资质的行；1(白)/0/越界都返回空字典，调用方按"没有"处理。
static func 档(资质: int) -> Dictionary:
	var 全部: Dictionary = 表().get("品质", {})
	return 全部.get(str(资质), {}) as Dictionary


## 资质 → 边框素材路径；不画框的档返回 ""。
static func 边框路径(资质: int) -> String:
	return String(档(资质).get("边框", ""))


## 提示框标题/追加属性行的名字色。**逐档取自 `EqpData.APTITUDE_COLORS`**，
## 1(白) 与查不到的档都给白色，跟原版 `APTITUDE_COLORS[1]` 一样。
static func 名字色(资质: int) -> Color:
	var 值 := String(档(资质).get("名字色", ""))
	return Color(值) if 值.length() == 7 else Color.WHITE


## 忍具的框是**固定**的 `EquipAptitudePinkF` + 流光（`MToolTipRenJuTip.as:96-108`），
## 与资质无关；素材与「灵气」那档同一份（`数据/装备品质.json` 的 `灵气`），单独给个取法。
static func 灵气覆盖层() -> Dictionary:
	var 灵: Dictionary = 表().get("灵气", {}) as Dictionary
	return {
		"边框": String(灵.get("边框", "")),
		"流光": bool(灵.get("有流光", false)),
	}


## 一件物品要叠什么：`{边框: 路径, 流光: bool}`。
##
## 灵气（十拳剑）与忍具（八咫镜）都是**整族**恒定粉框 + 流光，不看 aptitude。
## 原版把这条写进了**某些格子/提示框类**，不是写进 `EquipAptitudeUtil`：
##   · 有 —— 背包格 `ItemWindowCell`（灵气 `addLingQiitemAnima` :169-188、
##     忍具 `addRenJuItemFrame` :191-204）、人物面板 `LingQiCell`/`RenJuCell`（`:85-92`）、
##     提示框 `MToolTipLingQiTip`（`:94-105`）/ `MToolTipRenJuTip`（`:98-109`）；
##   · 没有 —— 仓库格 `StorageWindowCell`、列表行 `SimpleItemCell`、装备格
##     `EquipmentWindowCell`、`MToolTipZhuangBei`，只按 aptitude 走 switch（`:155-181`）。
## 所以 `含灵气`/`含忍具` 由**调用方按自己是哪种格子传** —— 这两族能被宿主看见的地方
## 就是上面"有"的那几处（人物面板的灵器格/忍具格正是本工程用通用 `装备格` 顶的，
## 必须由页面把开关打开，否则粉框永远不出现）。
##
## 门槛按原版是 `value.hasOwnProperty("aptitude")`（非装备物品根本没这个属性）——
## 落在 `档(物品资质(物品))` 上：没这个键 ⇒ 档 0 ⇒ 空字典 ⇒ 不画；
## 玉链例外，它的档由阶推出来（见 `玉链资质`），不依赖下发值。
## 资质**不做归一化**：2.2.3 版没有 `normalizeAptitude`
## （那是新前端包里的 `EquipAptitudeUtil`），传 6 以上这里就是查不到、什么都不画。
static func 覆盖层(物品: Dictionary, 含灵气: bool = false, 含忍具: bool = false) -> Dictionary:
	var 号 = 物品.get("id", "")
	if (含灵气 and 是灵气(号)) or (含忍具 and 是忍具(号)):
		return 灵气覆盖层()
	var 行 := 档(物品资质(物品))
	return {
		"边框": String(行.get("边框", "")),
		"流光": bool(行.get("有流光", false)),
	}


## 玉链（`EquipS1`，部位「勾玉」-20）的**显示档** —— 2026-10-31 用户点名的偏离。
## 原版 `EquipAptitudeUtil.shouldHideAptitudeIcon:89-92` 把玉链的资质框整个藏掉
## （`isItemAYuLian`），用户要求按阶给框：45/50 白（无色）、55 绿、60 蓝、65 紫、70 橙。
## 阶就是物品 id 的十位（`数据/物品装备元数据.json` 的 `stage` 同值，门里逐件对表）；
## 显示档 = clamp(阶-1, 1, 5) —— 低两阶并到白档；白档本来就没有框素材
## （`createAptitudeIcon` 的 switch 没有 WHITE case）⇒ 用户说的「白色（无色）」。
## **纯显示推导**：服务端下发的 `aptitude` 不动、不落库，也不参与打造/洗练/一键出售
## 等玩法判断（那几处读的一直是原始 `aptitude` 字段）。
static func 玉链资质(物品id: Variant) -> int:
	var 位 := _八位(物品id)
	if 位.length() != 8 or 装备部位.位置(位) != 装备部位.勾玉:
		return 0
	return clampi(int(位.substr(6, 2)) / 10 - 1, 1, 5)


## 一件物品**显示用**的资质档：玉链按阶推导（`玉链资质`），其余照 `aptitude` 字段。
## 徽章（-22）不用在这里特判 —— 服务端 `_apply_badge_aptitude` 已把 aptitude 钉到尾数
## （2026-10-28 用户口径，见 §3.306），客户端读到的就是对的。
## 宠物时装（原版第三类藏框）本工程没有该类实例 ⇒ 未接，别当成漏项。
static func 物品资质(物品: Dictionary) -> int:
	return 显示档(物品.get("id", ""), int(物品.get("aptitude", 0)))


## 同上，但**物品 id 与 aptitude 分开给** —— 提示框 `设置(物品id, …)` 的 id 是入参、
## 实例字典不一定带 `id` 键，那条路用这个。
static func 显示档(物品id: Variant, aptitude: int) -> int:
	var 玉 := 玉链资质(物品id)
	return 玉 if 玉 > 0 else aptitude


## 边框相对格子的偏移（原版格子里加在格子上、提示框里加在图标上，两处不同）。
static func 边框偏移(位置: String) -> Vector2i:
	var 值: Array = (表().get("边框偏移", {}) as Dictionary).get(位置, [-1, -1])
	return Vector2i(int(值[0]), int(值[1]))


## 流光的动画参数：帧目录、帧数、帧率、循环段、偏移。
## 循环段用两条动画拆开做：`进场` 播完接 `默认`（默认自带循环），
## 等价于原版 `addFrameScript(48, gotoAndPlay(17))`。
static func 流光配置() -> Dictionary:
	return 表().get("流光", {}) as Dictionary


## 按目录把 49 张帧图拼成两条动画。帧图是运行时才贴的覆盖层，
## 和资质框一样不进场景（空格子在任何时候都不该显示流光）。
static var _帧缓存: SpriteFrames = null


static func 流光帧集() -> SpriteFrames:
	if _帧缓存 != null:
		return _帧缓存
	var 配置 := 流光配置()
	var 目录 := String(配置.get("目录", ""))
	var 帧数 := int(配置.get("帧数", 0))
	if 目录.is_empty() or 帧数 <= 0:
		return null
	var 循环起 := int(配置.get("循环起始帧", 1))
	var 循环止 := int(配置.get("循环结束帧", 帧数))
	var 帧列表: Array[Texture2D] = []
	for 序 in 帧数:
		var 路径 := "%s%s.png" % [目录, String.num_int64(序 + 1).pad_zeros(2)]
		if not ResourceLoader.exists(路径):
			push_warning("装备品质：流光帧图缺失 %s（重跑 开发工具/导出装备品质.mjs 前先确认素材导出了）" % 路径)
			return null
		帧列表.append(load(路径) as Texture2D)
	var 帧 := SpriteFrames.new()
	帧.remove_animation("default")
	帧.add_animation("进场")
	帧.add_animation("默认")
	帧.set_animation_loop("进场", false)
	帧.set_animation_loop("默认", true)
	帧.set_animation_speed("进场", float(配置.get("帧率", 14)))
	帧.set_animation_speed("默认", float(配置.get("帧率", 14)))
	for 序 in 帧列表.size():
		if 序 < 循环起 - 1:
			帧.add_frame("进场", 帧列表[序])
		if 序 >= 循环起 - 1 and 序 <= 循环止 - 1:
			帧.add_frame("默认", 帧列表[序])
	_帧缓存 = 帧
	return 帧


## 流光相对**格子**的偏移（提示框里是相对图标，值不一样）。
static func 流光偏移(位置: String) -> Vector2i:
	var 值: Array = (流光配置().get("偏移", {}) as Dictionary).get(位置, [3, 3])
	return Vector2i(int(值[0]), int(值[1]))


## 把资质框 + 流光挂到宿主控件上，并刷成**本次这件物品**的样子。
## 这是全项目唯一搭这两个节点的地方：
##   · 场景化的格子（`物品格.tscn` / `装备格.tscn`）里已经有同名节点，这里只改贴图/可见/几何；
##   · 运行时现搭的图标格（`功能窗口` 的列表行、提示框的图标框）没有就照表建一个。
## 传空字典 = 清空（空格子、非装备物品）。
##
## `位置` 决定用哪套偏移：原版格子里覆盖层加在**格子**上 (-1,-1)/(3,3)，
## 提示框里加在**图标**上 (-3,-3)/(1,1) —— 所以提示框还要把 `起点` 填成图标的位置，
## 因为图标在 40x40 的框里是居中的、会随图片尺寸动。
## `含灵气`/`含忍具` 见 `覆盖层` 那段：由宿主自己决定要不要认这两族。
static func 挂覆盖层(宿主: Control, 物品: Dictionary, 含灵气: bool = false,
		位置: String = "格子", 起点: Vector2 = Vector2.ZERO, 含忍具: bool = false) -> void:
	var 覆盖 := 覆盖层(物品, 含灵气, 含忍具)
	var 路径 := String(覆盖.get("边框", ""))
	var 图: Texture2D = null
	if not 路径.is_empty() and ResourceLoader.exists(路径):
		图 = load(路径) as Texture2D
	var 框 := 宿主.get_node_or_null("资质框") as TextureRect
	if 框 == null:
		框 = TextureRect.new()
		框.name = "资质框"
		宿主.add_child(框)
	var 尺: Array = 表().get("边框尺寸", [42, 42])
	var 起 := 边框偏移(位置)
	var 框尺 := Vector2(int(尺[0]), int(尺[1]))
	# 格子的框永远是「格子 + 2」并压在 (-1,-1)，表里的 42 只是 40 格那版的值。
	# 背包格 2026-10-31 回到 40x40（`物品格.tscn`）后与表同值；仍跟着宿主现算，
	# 免得以后谁再改格尺寸时 42 图套错框。提示框那条（`位置` = 图标）照表。
	if 位置 == "格子" and 宿主.size.x > 0.0:
		框尺 = 宿主.size + Vector2(2, 2)
	框.position = 起点 + Vector2(起.x, 起.y)
	框.size = 框尺
	框.mouse_filter = Control.MOUSE_FILTER_IGNORE
	框.texture = 图
	框.visible = 图 != null
	挂流光(宿主, bool(覆盖.get("流光", false)), 位置, 起点, str(物品.get("id", "")))


## 流光是原版每次 `showIcon` 现 `new` 出来的动态件，所以**不该显示时不建节点**
## （节点自己会不会出现，与格子有没有装备无关）。
## 素材已按 49 帧的 alpha 包围盒裁成 35x35，**注册点就是贴图左上角**，
## 于是原版的偏移能直接照抄（依据见 `数据/装备品质.json` 的 流光 段）。
static func 挂流光(宿主: Control, 显示: bool, 位置: String = "格子",
		起点: Vector2 = Vector2.ZERO, 身份 := "") -> void:
	var 帧动画 := 宿主.get_node_or_null("流光") as AnimatedSprite2D
	if 帧动画 == null:
		if not 显示:
			return
		帧动画 = 品质流光.new()
		帧动画.name = "流光"
		宿主.add_child(帧动画)
	if not 显示:
		帧动画.call("停")
		宿主.set_meta("flowlight_id", "")   # ⚠️ meta 键必须 ASCII，中文键**静默不写**
		return
	# ⭐ **同一件物品重渲染 ⇒ 什么都不做**。⚠️ 2026-10-01 上一轮只在 `品质流光.播` 里做了
	#    幂等，但调用方（背包/仓库渲染循环）是"先 `清空品质覆盖层` 再 `设置品质`"——
	#    清空那一下已经把流光停掉、`visible=false`，`播` 的幂等条件永远不成立，
	#    于是"每刷新一次、流光从头重转"（用户：转一半就跳回开头）。身份判断必须放在
	#    **这里（咽喉）**：清/设两条路都经过我，同身份连位置都不重设。
	if 身份 != "" and String(宿主.get_meta("flowlight_id", "")) == 身份 and 帧动画.visible:
		return
	宿主.set_meta("flowlight_id", 身份)
	var 起 := 流光偏移(位置)
	# AnimatedSprite2D 默认 centered=true，原点在世界坐标**中心**，而原版给的是左上角。
	var 尺: Array = 流光配置().get("尺寸", [35, 35])
	var 中心 := Vector2(int(起[0]) + int(尺[0]) / 2.0, int(起[1]) + int(尺[1]) / 2.0)
	# 40 格：3 + 35/2 = 20.5 = 40/2 + 0.5；36 格同一条规矩 ⇒ 18.5（见 `挂覆盖层` 里那段）。
	if 位置 == "格子" and 宿主.size.x > 0.0:
		中心 = 宿主.size * 0.5 + Vector2(0.5, 0.5)
	帧动画.position = 起点 + 中心
	帧动画.call("播", 流光帧集(), true)

