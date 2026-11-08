extends RefCounted
## 家族家徽图（34×34）——原版 `PicTool.getJiaHuiPic(flagStyle)` 的那张图标。
##
## 图源：**不是运行时下发的那份**，是从客户端自带的图形包里现解的
## `swf/BangHui/BangHui_flagStyle_<样式>.swf`（里面那张位图的类名就叫
## `BangHui_flagStyle_<样式>_icon`，34×34，与 `PicTool.as:509` 的 `drawRect(0,0,34,34)`
## 严丝合缝）。批量导出见 `开发工具/导出家族家徽.py`。
##
## ⚠️ **不要染色 —— 直接用素材原色**（2026-10-15 用户拍板，纠 `2026-09-30` 的旧结论）：
##   `PicTool.as:528-558 tintJiaHuiPicWhiteToGold` 那段"RGB ≥ 0xE0E0E0 换成 0xFFFF8C00"
##   在**单机版实机上看不出效果** —— 实机那颗与 swf 原图逐色一致：
##     方底浅蓝 `(207,215,244)` + 圆盘**白** `(255,255,255)` + 卷纹深灰 `(80,70,68)`；
##   而 2026-09-30 ~ 2026-10-15 我们这边的图是照 AS3 染过的"圆盘橘金 `(255,140,0)`"
##   （用户并排图一眼看出：单机版白、我们橘）。用户原话：**"所有使用到族徽你都不应该染色，
##   而是直接使用素材"**。⇒ 本文件只管取图，**任何调用点都不许再 modulate/覆色**
##   （7 个使用点已逐个核过：家族页家徽格 / 创建窗预览 / 家族列表行 / 旗帜窗预览 /
##   HUD 永久徽条 / 角色头顶标示 / 地图族旗，全是 `TextureRect|Sprite2D.texture = 取(...)`
##   后不再动颜色）。门钉在 `测试/家徽显示回归测试.gd` 的「素材本体不染色」一节。
##   ⚠️ 若哪天要复现当年那批橘金做对照：`python 开发工具/导出家族家徽.py --染色`，
##      跑完记得**再跑一次不带开关的**把素材还原（否则门会红）。

const 目录 := "res://素材/界面/原版窗口/家族/"
## `FamillyListItemRenderer.as:86`：`_jiaHuiIcon.scaleX = scaleY = 20 / 42`
const 列表缩放 := 20.0 / 42.0
## 原图边长（`PicTool.as:509` 的 `drawRect(0,0,34,34)`）
const 边长 := 34.0

## 取某个家徽样式的图；没有这张样式就返回 null（宁可不画也不编）。
static func 取(样式号: int) -> Texture2D:
	if 样式号 < 0:
		return null
	var 路 := "%s家徽_%d.png" % [目录, 样式号]
	if not ResourceLoader.exists(路):
		return null
	return load(路) as Texture2D


## ── 族徽**底框**（`Effect_CharStatus_Kuang`，20×20）─────────────────────────
## 原版族徽块都是两层：**框 20×20 + 家徽 18×18 摆在内缩 1px 处**（`(1,1)`）——
##   `Character.as:1447-1451`（角色头顶）与 `Flag.as:413-427`（地图族旗）两处同款。
## 素材出处：`www/act_web_nya_208_isolated/asset/effect.fws.swf` 的 SymbolClass 第 4 号
## （`DefineSprite 4 → DefineShape 3`，单位阵、bounds 0..6000 twip = 20×20 px）；
## 导出见 `开发工具/导出族徽底框.py`。2026-10-14 那轮记成"素材库里没有"是**查错了库**
## （MainLib 的导出表里确实没有它 —— 它在运行时加载的 effect 库里）。
## ⚠️ 素材不在就返回 null：调用方照旧只画家徽（`宁可不画也不编` 的老口径）。
const 底框目录 := 目录
const 底框文件 := 底框目录 + "族徽底框.png"
const 底框边长 := 20.0
## 家徽在底框里内缩几像素（`Flag.as:417` / `Character.as:1449` 的 `_loc3_.x = _loc3_.y = 1`）
const 底框内缩 := 1.0

static func 取底框() -> Texture2D:
	if not ResourceLoader.exists(底框文件):
		return null
	return load(底框文件) as Texture2D

