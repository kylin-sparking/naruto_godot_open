extends RefCounted
## 跳跃抛物线的两条物理常数 —— **本地那具身体与旁观端那具身体必须用同一组数**。
##
## 为什么单独一个文件：原版两边跑的是同一条 `AbstractPhysicObject.applyVelocity` + 同一个
## 重力，所以收端那具身体自己积分出来的抛物线，必须和真身算的是同一条 —— 原版敢在跳跃
## 中途**一个包都不发**（`Sampler.as:87-90` 明确把"只有 VELOCITY 变脏"那一格排除掉）就是
## 建立在这个前提上。要同源就得让 `玩家.gd` 和 `地图实体.gd` 都能取到，而 `玩家.gd` 里
## 有 autoload 标识符（`GameSession`），被 `地图实体.gd` preload 会在编译期报
## `Identifier not found: GameSession`（10-15 实测：本地玩家直接建不出来）。
## ⇒ 常数放这一份谁都能 preload 的干净文件，**别在别处再抄第二份数值**。
const 重力 := 2000.0
const 末速上限 := 670.0

## ── 走路 / 攀爬 / 起跳速度：**必须跟着服务端的"移动速度"属性走**（10-15 逐行查实）──
## 原版一条链（行号全在 `as3_MainLib/scripts/com/mxw/`）：
##   `DataCenter.as:2771-2784` 收到 **field 21（移动速度属性）** ⇒ 存进 `stats.sec_wlkSpeed`
##     并当场 `player.walkSpeedFactor = SkillHandler.getWalkSpeedFactor()`
##   `SkillHandler.as:425-441` `getWalkSpeedFactor() = FightValue.walkSpeedFactor × 最狠的那档减速`
##   `FightValue.as:123-125` → `NumValue.as:25-28` `walkSpeedFactor = 1.4 × sec_wlkSpeed / 100`
##   `AbstractPhysicObject.as:922 / 600` `walkSpeed = 125 × walkSpeedFactor`、
##                                  **`climbSpeed = 125 × walkSpeedFactor`（攀爬吃的是同一个系数！）**
##   `AbstractPhysicObject.as:48` 初值数组 `[1.4, 1.2, 1, ...]` ⇒ 属性 100 时走路 **175**、
##   `:741` `jumpSpeed = 555 × jumpSpeedFactor(1.2) = 666`（`jumpSpeedFactor` **全树无赋值点**，恒 1.2）
## ⇒ 我们原来 `玩家.gd` 写死 `move_speed=175 / climb_speed=125`：**走路恰好等于"属性 100"那个点
##   所以看不出错，攀爬少了那个 1.4 ⇒ 比原版慢 28.6%**（用户 10-15 报"攀爬不对劲"的一半原因），
##   而**任何加移动速度的装备/心法/宠物都不生效**（面板数字会变、人不变快）。
## ⚠ 别在别处再抄第二份 125/1.4/555/1.2。
const 走路基速 := 125.0			## `Physics.WALK_SPEED`
const 攀爬基速 := 125.0			## `Physics.CLIMB_SPEED`
const 起跳基速 := 555.0			## `Physics.JUMP_SPEED`
const 系数基值 := 1.4			## 属性 100 时的 `walkSpeedFactor`
const 起跳系数 := 1.2			## `jumpSpeedFactor` 的初值，原版没有任何地方改它

## `NumValue.as:27` + `SkillHandler.as:440`。减速系数 = 身上最狠的那档减速（原版 `<=100` 才取，
## 否则按 1 算），没有减速就传 1.0。
static func 走路系数(移动速度属性: float, 减速系数: float = 1.0) -> float:
	return 系数基值 * 移动速度属性 / 100.0 * 减速系数

static func 走路速度(移动速度属性: float, 减速系数: float = 1.0) -> float:
	return 走路基速 * 走路系数(移动速度属性, 减速系数)

## ⚠ 攀爬**不是**另一个基值：`AbstractPhysicObject.as:600-602` 用的就是 `walkSpeedFactor`。
static func 攀爬速度(移动速度属性: float, 减速系数: float = 1.0) -> float:
	return 攀爬基速 * 走路系数(移动速度属性, 减速系数)

static func 起跳速度() -> float:
	return 起跳基速 * 起跳系数		## = 666，与原版本默认值逐位相同

## 爬到顶脱开那一下的竖直速度（用户 2026-10-31 口径）：「普通起跳 105 px +
## 基础速度爬顶跳起的高度」。同一重力下高度 ∝ v² ⇒ 两段高度相加就是**速度平方**相加：
##   v = √(666² + 175²) ≈ 688.608，175 = 攀爬基速 125 × 系数基值 1.4（属性 100 的原版口径）。
## ⚠ 基础爬顶速度按**常量**算，不读 live `climb_speed` —— 那玩意儿带移动速度属性
## （`AbstractPhysicObject.as:600`），照搬会让高度随移速涨（用户已明确否掉）。
const 基础爬顶速度 := 攀爬基速 * 系数基值	## = 175
static func 爬顶跳离速(起跳速度值: float) -> float:
	return sqrt(起跳速度值 * 起跳速度值 + 基础爬顶速度 * 基础爬顶速度)

## 位移包这一帧该不该发 = 原版 `Sampler.tick()` 那两条脏标记闸门（逐条理由写在
## `玩家.gd:_sync_backend_movement()` 的注里）。抽成纯函数是为了让门能**直接喂真值表**判：
## 真包要跑完整条"客户端→服务端→广播"链才能数，那种夹具反而更不可信（10-15 #232）。
## ⚠ 这一族最容易悄悄退化：把"变脏即发"改回"每 0.1 秒一发"，画面只是迟钝一点，
## 没有任何一条像素门会红 ⇒ 只能靠这三条真值表钉住。
static func 该发位移包(动作翻了: bool, 速度翻了: bool, 位置没变: bool, 距上次秒: float, 节流秒: float) -> bool:
	if not 动作翻了 and not 速度翻了 and 距上次秒 < 节流秒:
		return false
	return not (位置没变 and not 动作翻了 and not 速度翻了)
