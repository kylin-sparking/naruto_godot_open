extends RefCounted
## 原版 `PVPHandler` 那两道 PK 判定的**逐句转写**（#352/#353，2026-10-25）：
##   `canAttackPlayer:313-381`   → `可打玩家()`
##   `getNoAttackWarning:392-453` → `打不了的话()`
## 分支顺序、`switch` 各 case 的 `break`/穿透、比较方向全部照搬（`if` 链代替 `match`，
## 因为 GDScript 的 `match` 不穿透，而原版三个 case 之后那个 `PVP_ZHENYING` **没有 break**）。
##
## ⚠⚠ **真值分叉（10-25 夜发现，本文件第一版照错了份）**
## `2.2.3优化版/HYSJ/logs/swfprobe` 下有**两份** MainLib 反编译，不是同一份代码：
##
## | 目录 | 脚本数 | 来自哪个 SWF | SWF 字节 | 日期 |
## |---|---|---|---|---|
## | `as3_MainLib` ← **认这份** | 1898 | `www/act_web_nya_208_isolated/asset/MainLib.swf` | 2,151,305（md5 `3ef4ccb4…`） | 08-17 |
## | `as3_MainLib_plain` | 1830 | 同目录 `MainLib_plain.swf`（== `MainLib_pvp.swf`，md5 一样） | 4,393,375（md5 `736b6a2c…`） | 07-25 |
##
## 凭什么说玩家加载的是上面那一行：两份清单（`nya-208-isolated-manifest.json`、
## `original-client-manifest.json`）里被登记成 `asset/MainLib.swf` 的都是它，`_plain`/`_pvp`
## 只是旁边的备用副本；工程归档也是按 1898 份 `.as` 全树 diff 证明等于 2.2.3 的。
##
## 两份在这道判定上**实测差四处**（都够改变游戏行为，不是排版差异）：
## 1. `:319` 多一道**护送闸**：目标挂着护送旗、又不在护送双倍时段 ⇒ 打不了（`非活动期间，不能打劫`）。
## 2. `:355` 的 switch 多一个 `case PVP_ZHENYING` ⇒ **阵营模式会保护同阵营**（上一版我写成"没有这一档"是错的）。
## 3. 3v3 那一组多 `nowInNinja3v3`（忍者3v3 也算，且它同样保护同队）。
## 4. **复活/挂机保护的位置**：实机这份在**最后**（`:376`、`getNoAttackWarning:444/448`），
##    `_plain` 那份在最前 ⇒ 同一句"为什么打不了"两边说的不一样（例：和平模式打带复活保护的人，
##    实机说"PK模式为和平模式"，`_plain` 说"玩家复活后…"）。三句文案的字面也不同（见下面的 `话`）。
##
## 数读 `数据/PVP配置.json`（= 原版 GameData `Pvp/open`，实机这份在 `:95-111` 读的就是这几个键）：
##   `pkLevel=45`（不到这个级不能 PK）/ `configLevel=40`（`canOpenPKPanel:557-559` 用它，
##   但该函数在整份 MainLib 里**没有任何调用点**（已按实机这份复查过）⇒ 那颗钮开面板不受等级限制，照抄）/
##   `player2playerLevel=15` → `pkLevelScope`（`:110` 读进来之后**全类再无使用** ⇒ 等级差是**服务端**的闸）/
##   `defenceTime=30` → `beatBackDuration`（记仇时长，`signEnemy:542-553`）/ `protectTime=1800` /
##   `peaceMaps` 5 张（**100000000 木叶村就在第一张** ⇒ 在村里打不了人是原版规则，不是缺陷）。
## 文案是 `as3_MainLib/scripts/en_US$core_properties.as`（`LangUtilCore.get` 读的**第三个**语言包，
## 91 行）里的原文，逐字搬进来并带行号；⚠ 这份与 `_plain` 那份同键不同字，别拿 `_plain` 或
## `.\...\ffdec_mainlib` 那份对（见 真值/系统/PK判定.md 的"三份 core 包"表）。

## ⚠ `GAME_DATA` 不是 autoload（autoload 的名字叫 `GameData`），本工程每个用它的文件
## 都**自己 preload 一份**（同 `脚本/角色/战斗角色.gd:49`）—— 少这一行时
## `--check-only --script res://脚本/角色/PVP判定.gd` 直接报
## `Identifier "GAME_DATA" not declared in the current scope`，整条打人链编译不过。
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")

const 和平 := 1		# OpenPvpMode.PEACE   = NONE      （`PVPHandler.as:46`）
const 组队 := 2		# OpenPvpMode.PARTY   = PVP_TEAM  （`:48`）
const 家族 := 3		# OpenPvpMode.FAMILY  = PVP_FAMILY（`:50`）
const 全体 := 4		# OpenPvpMode.ALL     = PVP_NONE  （`:52`）
const 阵营 := 5		# OpenPvpMode.ZHENYING = PVP_ZHENYING（`:54`）—— 实机这份**有这一档**

## `Config.as:68` 是 `ENABLE_PVP:String = "1"`，而 `:315` 写的是 `if(!Config.ENABLE_PVP)`
## —— 拿字符串当布尔用，只要不是 "" 就恒真 ⇒ 原版这一支**永远不拦**。照抄，不"顺手修"。
const 允许PVP := true

## 原文逐字（`as3_MainLib/scripts/en_US$core_properties.as` 的行号在后面）
const 话 := {
	"死亡": "死亡状态无法攻击",													# :16  WARNING_DEAD_NO_ATTACK
	"护送": "非活动期间，不能打劫",												# :17  PVP_HUSONG_NO_ATTACK
	"复活保护": "玩家复活后处于系统保护状态",										# :35  PVP_REALIVE_PROTECTION_NO_ATTACK
	"安全图": "本地图禁止PK",														# :36  PVP_PEACE_MAP_NO_ATTACK
	"低于我等级差": "很抱歉，你不能攻击低于你1%级以上的玩家",						# :45  PVP_TARGET_DIFF_LOW_LEVEL_NO_ATTACK
	"和平模式": "很抱歉，您当前的PK模式为和平模式，无法对该玩家造成伤害",			# :46  PVP_PEACE_NO_ATTACK
	"对方等级低": "很抱歉，1%级以下的玩家处于新手保护中，无法PK",					# :57  PVP_TARGET_LOW_LEVEL_NO_ATTACK
	"同队": "很抱歉，您当前的PK模式为组队模式，无法对该玩家造成伤害",				# :58  PVP_SAME_TEAM_NO_ATTACK
	"高于我等级差": "很抱歉，你不能攻击高于你1%级以上的玩家",						# :59  PVP_TARGET_DIFF_HIGH_LEVEL_NO_ATTACK
	"同阵营": "很抱歉，您当前与该玩家处于同一阵营，无法对该玩家造成伤害",			# :60  PVP_SAME_ZHENYING_NO_ATTACK
	"我等级低": "很抱歉1%级之后才能PK",											# :61  PVP_LOW_LEVEL_NO_ATTACK
	"挂机保护": "玩家处于夜间挂机保护状态",										# :72  PVP_NIGHT_PROTECTION_NO_ATTACK
	"同族": "很抱歉，您当前的PK模式为家族模式，无法对该玩家造成伤害",				# :78  PVP_SAME_FAMILY_NO_ATTACK
}

## `PVPHandler.as:438/442` 是 `.replace("1%", this.minPkLevel)` —— 占位符**字面就是** `1%`。
## ⚠ 实机这份连 `PVP_LOW_LEVEL_NO_ATTACK` 也是 `1%`（`:61` "很抱歉1%级之后才能PK"）⇒ 会正常换成
## 「很抱歉45级之后才能PK」。**别照 `_plain` 那份改回 `%1`** —— 那一份是另一个 build，
## 它写的是 `%1`（replace 不到、屏幕上留原样），看着像"原版的自我不一致"，其实不是实机在跑的这份。
static func 填数(文: String, 数: int) -> String:
	return 文.replace("1%", str(数))


static func 配置() -> Dictionary:
	return GAME_DATA.取表("PVP配置")


## ⚠ `GAME_DATA.取表()` 走的是 `JSON.parse_string` ⇒ 表里的数字**全是 float**
## （实测 `数据/PVP配置.json` 的 `peaceMaps` 五项 `typeof()==TYPE_FLOAT`、`pkLevel` 也是），
## 而原版那两道图闸拿的是**整数图号** ⇒ `Array.has(100000000)` **恒假**：
## 「本地图禁止PK」整条失效、木叶村变成可以打人（服务端会拒，客户端还照发不误）。
## 所以这里按**数值**比，不改 `数据/PVP配置.json`、也不改 `脚本/单例/游戏数据.gd`。
## （GDScript 的 `==` 本来就会跨 int/float 比数 ⇒ 只有 `Array.has()` 这一种写法会栽。）
static func _表里存过(表: Array, 数: int) -> bool:
	for 项 in 表:
		if int(项) == 数:
			return true
	return false


static func 是安全图(图号: int) -> bool:
	return _表里存过(配置().get("peaceMaps", []) as Array, 图号)


static func 是无保护图(图号: int) -> bool:
	## `PVPHandler.isUnprotectedMap:303-305`（BOSS 图：无保护无惩罚）
	return _表里存过(配置().get("unprotectedMaps", []) as Array, 图号)


## `canAttackPlayer(param1:Character):313-381` —— 逐句。
## 我 = {等级:int, 图号:int, 同队:bool, 同族:bool, 同阵营:bool, 仇人:bool,
##        在3v3:bool, 在忍者3v3:bool, 在战场:bool, 在跨服:bool, 死亡:bool, 护送双倍:bool}
## 目标 = {等级:int, 死亡:bool, 复活保护:bool, 挂机保护:bool, 打架旗:bool, 护送旗:bool}
## `isProtectedInPeaceMap()`（`Character.as:1658`）= `!isFlagFighting` ⇒
## 原版 `if(!param1.isProtectedInPeaceMap()) return true`（`:360`）就是「**目标在打架态 ⇒ 直接可打**」。
## ⚠ 下面这四个输入本工程**目前拿不到**，全部按 false 传（各自带 TODO，别当成原版没有这一档）：
##   护送旗（`Character.showHuSongIcon`，由护送状态置位 `Character.as:1939`）、护送双倍
##   （`HuSongQuestManager.isDoubleTime:153`）、同阵营（`MuYeDaZhanManager.isSameZhenYing`）、
##   复活/挂机保护与打架旗（服务端 buff 推的，见 #324）。
static func 可打玩家(模式: int, 我: Dictionary, 目标: Dictionary) -> bool:
	if not 允许PVP:													# :315
		return false
	if bool(目标.get("护送旗", false)) and not bool(我.get("护送双倍", false)):
		return false												# :319
	if bool(我.get("在3v3", false)) or bool(我.get("在忍者3v3", false)) \
			or bool(我.get("在战场", false)) or bool(我.get("在跨服", false)):	# :323
		if bool(我.get("在3v3", false)) or bool(我.get("在忍者3v3", false)):	# :325
			if bool(我.get("同队", false)):							# :326 isInTroop(目标)
				return false
		return true												# :332
	if bool(我.get("仇人", false)):									# :335 isEnemy
		return true
	if 模式 == 和平:												# :342 case NONE
		return false
	if 模式 == 组队 and bool(我.get("同队", false)):					# :344-349（break）
		return false
	if 模式 == 家族 and bool(我.get("同族", false)):					# :350-354（break）
		return false
	if 模式 == 阵营 and bool(我.get("同阵营", false)):					# :355-359（最后一个 case）
		return false
	if bool(目标.get("打架旗", false)):								# :360 !isProtectedInPeaceMap()
		return true
	if 是安全图(int(我.get("图号", 0))):								# :364
		return false
	var 门槛 := int(配置().get("pkLevel", 1))
	if int(我.get("等级", 0)) < 门槛:									# :368
		return false
	if int(目标.get("等级", 0)) < 门槛:								# :372
		return false
	if bool(目标.get("复活保护", false)) or bool(目标.get("挂机保护", false)):
		return false												# :376 ← 实机这份在**最后**
	return true														# :380


## `getNoAttackWarning(param1:Character):392-453` —— 逐句。返回**空串 = 没话要说**
## （原版也是空串：目标已死、在 3v3/忍者3v3/战场/跨服 这四种情况下都回 ""）。
## ⚠ 顺序与 `可打玩家` **不同**（原版就是这样）：3v3 那段在最前（`:394`，早于目标死亡），
## 而两道保护在最后（`:444/448`）⇒ 同一组输入下"能不能打"和"说哪一句"会不一致，
## 调用方必须两个都问（门里专门钉了两条这种不一致）。
static func 打不了的话(模式: int, 我: Dictionary, 目标: Dictionary) -> String:
	if bool(我.get("在3v3", false)) or bool(我.get("在忍者3v3", false)) \
			or bool(我.get("在战场", false)) or bool(我.get("在跨服", false)):	# :394
		return ""
	if bool(目标.get("死亡", false)):									# :398 param1.isDead()
		return ""
	if bool(我.get("死亡", false)):									# :402 API.player.isDie
		return String(话["死亡"])
	if bool(目标.get("护送旗", false)) and not bool(我.get("护送双倍", false)):
		return String(话["护送"])									# :406
	if 模式 == 和平:												# :412 case NONE
		return String(话["和平模式"])
	if 模式 == 组队 and bool(我.get("同队", false)):					# :414-418
		return String(话["同队"])
	if 模式 == 家族 and bool(我.get("同族", false)):					# :420-424
		return String(话["同族"])
	if 模式 == 阵营 and bool(我.get("同阵营", false)):					# :426-430
		return String(话["同阵营"])
	## :432 `isPeaceMap(...) && param1.isProtectedInPeaceMap()`；后者 = `!打架旗`
	if 是安全图(int(我.get("图号", 0))) and not bool(目标.get("打架旗", false)):
		return String(话["安全图"])
	var 门槛 := int(配置().get("pkLevel", 1))
	if int(我.get("等级", 0)) < 门槛:
		return 填数(String(话["我等级低"]), 门槛)					# :438
	if int(目标.get("等级", 0)) < 门槛:
		return 填数(String(话["对方等级低"]), 门槛)					# :442
	if bool(目标.get("复活保护", false)):
		return String(话["复活保护"])								# :444-446
	if bool(目标.get("挂机保护", false)):
		return String(话["挂机保护"])								# :448-450
	return ""														# :452


## 给调用方的一步到位版：`{"可打": bool, "话": String}`。
## ⚠ 两条分支各判各的（原版就是两个函数），所以这里**两个都算**再返回 ——
## 只信其中一个会把"可打=false 但没话"或"有话但可打"这种不一致吞掉（门里专门钉这两条）。
static func 判定(模式: int, 我: Dictionary, 目标: Dictionary) -> Dictionary:
	var 可 := 可打玩家(模式, 我, 目标)
	return {"可打": 可, "话": 打不了的话(模式, 我, 目标)}


## 服务端那一道等级差闸（`player2playerLevel=15` → `pkLevelScope`，`:110` 读进来之后**这个类再没用过**，
## 实机这份也确认了 ⇒ 客户端两个函数里都没有它，只有服务端在拦）：
## 差超过这个数 ⇒ 不能打，话是 `高于我等级差` / `低于我等级差` 两句之一。
static func 等级差话(我等级: int, 目标等级: int) -> String:
	var 范围 := int(配置().get("player2playerLevel", 99))
	if 目标等级 > 我等级 and (目标等级 - 我等级) > 范围:
		return 填数(String(话["高于我等级差"]), 范围)
	if 目标等级 < 我等级 and (我等级 - 目标等级) > 范围:
		return 填数(String(话["低于我等级差"]), 范围)
	return ""
