extends RefCounted

## 原版 UI 皮肤数据表。
##
## 这是生成 素材/界面/原版主题.tres 的唯一事实来源，由
## 开发工具/生成界面主题.gd 读取。本文件只放数据，不调用任何 Control API。
##
## 所有数值取自反编译 AS3：
##   Config.as:152/192          舞台 960x560
##   UIConfig.as                CONTENT_GAP=8 BORDER_GAP=5 BUTTON_GAP=4 TEXT_GAP=2
##   MWindow.as                 标题 粗体12px 色15725823 标题Y=5/3 拖动起始Y=29
##   MButton3.as                按钮四态文字色
##   MToolTip.as / MToolTipText 提示框 PADDING=8 文本偏移7 行距5 最大宽354
##   BaseUtil.as:111            getGlowFilter → 约2px 黑色描边

const 素材根 := "res://素材/界面/原版窗口/"
const 通用 := 素材根 + "通用控件/"

# ── 美术路径 ───────────────────────────────────────────────
const 按钮 := 通用 + "按钮.png"
const 按钮按下 := 通用 + "按钮按下.png"
## 悬停/按下档 = `按钮.png` 逐通道 +30 / −40 预烘（`StyleUtil.as:7-12` skinFilters，
## `MButtonF.as:6` = `extends MButton3` **只有构造函数** ⇒ 一族一张 upSkin，态是滤镜不是新图）。
## 由 `开发工具/生成标准钮态图.py` 烘。上面那张 `按钮按下.png` 是元件 tag15 `MButton_selectedUp`
## = **选中皮**（`MButton3` 的 `selectedUpSkin`），原来被接在 `pressed` 槽上占了错位置。
const 按钮悬停 := 通用 + "按钮_悬停.png"
const 按钮按下态 := 通用 + "按钮_按下.png"
const 分页未选 := 通用 + "分页按钮未选.png"
const 分页选中 := 通用 + "分页按钮选中.png"
## 悬停/按下档 = 未选皮逐通道 +30 / -40 预烘（`StyleUtil.as:7-12` 的 skinFilters）。
const 分页未选悬停 := 通用 + "分页按钮未选_悬停.png"
const 分页未选按下 := 通用 + "分页按钮未选_按下.png"
const 方向箭头 := 通用 + "方向箭头.png"
const 物品格 := 通用 + "物品格.png"
const 内容面板 := 通用 + "内容面板.png"
const 窗口边框 := 通用 + "窗口边框.png"
const 小窗口边框 := 通用 + "小窗口边框.png"
const 窗口内底 := 通用 + "窗口内底.png"
const 子面板 := 通用 + "子面板.png"
const 浅色面板 := 通用 + "浅色面板.png"
const 输入框 := 通用 + "输入框.png"
const 选中条 := 通用 + "选中条.png"
const 复选框选中 := 通用 + "复选框选中.png"
const 复选框未选 := 通用 + "复选框未选.png"
const 进度槽 := 通用 + "进度槽.png"
const 进度填充 := 通用 + "进度填充.png"
const 下拉箭头 := 通用 + "下拉箭头.png"
const 关闭按钮 := 通用 + "关闭按钮.png"
const 提示框 := 通用 + "提示框.png"
## 任务提示条底板 = 原版元件 `MessageTipPane2_background`（符号 **175**，原生 **263×252**）。
## ⚠ 与上面那张 `提示框.png`(218×294 = MToolTip 一族) **不是同一张**，别拿它顶。
const 提示条底板 := 通用 + "提示条底板.png"
const 列表分隔 := 通用 + "列表分隔.png"
const 横向分隔线 := 通用 + "横向分隔线.png"
const 滚动槽 := 通用 + "滚动槽.png"
const 滚动滑块 := 通用 + "滚动滑块.png"
const 滚动向上 := 通用 + "滚动向上.png"
const 滚动向下 := 通用 + "滚动向下.png"
const 增加按钮 := 通用 + "增加按钮.png"
const 减少按钮 := 通用 + "减少按钮.png"

## ── 商城独占 ───────────────────────────────────────────────
## 这四处原版都在**运行时素材包** `UISwf_Text.swf` 里（不是 MainLib），
## 且都是 `BaseUtil.getImageText(CN.XXX)` 按**符号名**取的图：
##   `CN.CHONG_ZHI_BUTTON_UPSKIN`="ChongZhiButtonUpSkin"（充值按钮，符号 #72，65x28）
##   `CN.QUAN_ICON`="QuanIcon"（券/礼金角标，符号 #102，19x13）
##   `CN.ICON_HOT`="IconHot"（热卖角标，符号 #75，43x28）
##   `CN.ICON_SALE`="IconSale"（打折角标，符号 #84，44x27）
## 路径见 `com/mxw/common/gameCommon/language/CN.as:19-25`；符号 id 与边界由
## `开发工具/读符号时间轴.py --源 UISwf_Text --边界 <id>` 读出（2026-09-26）。
const 商城素材 := 素材根 + "商城/"
const 充值按钮 := 商城素材 + "充值按钮.png"
const 券图标 := 商城素材 + "券.png"
const 热卖角标 := 商城素材 + "热卖.png"
const 打折角标 := 商城素材 + "打折.png"

## 复选框.png(78x19) 是「框+文字」合成图，硬编码了标签宽度，故意不引用。

# ── 九宫格边距 [左, 右, 上, 下] ─────────────────────────────
## 前 15 项从 界面皮肤.gd 的 NINE_SLICE 原样迁入，已在现有窗口上验证。
##
## **哪些图"有九宫格"这件事，判定标准是元件的基类**。2026-10-01 **20 项全部逐个核过**
## （`2.2.3/map_extract/out/mainlib_as/scripts` 下 grep `class X extends`；
##  元件与 PNG 按**包围盒尺寸完全相等**对上，id 是 `读符号时间轴.py --边界` 量的）：
##
## | 我们这张表 | 元件(id) | 基类 | 九宫格 |
## |---|---|---|---|
## | 窗口边框 | `MWindow_background`(3) | `ScaleSprite` | 有效 |
## | 小窗口边框 | `MWindowSmall_background`(767) | `ScaleSprite` | 有效 |
## | 窗口内底 | `SkillWindowMWindow_background1`(443) | `ScaleSprite` | 有效 |
## | 子面板 | `MPane_background`(97) | `ScaleSprite` | 有效 |
## | 浅色面板 | `Condition_backgroundSkin`(830) | `ScaleSprite` | 有效 |
## | 内容面板 | `MYellow_background`(10) | `ScaleSprite` | 有效 |
## | 按钮 / 按钮按下 | `MButton_up`(18) / `MButton_selectedUp`(15) | `ScaleSprite` | 有效 |
## | 分页未选 | `MTabButton_up`(121) | `ScaleSprite` | 有效 |
## | 分页选中 | `MTabButtonF`(123) ⚠️ 见下 | `MTabButton`→`MButton3`→`Sprite` | 见下 |
## | 物品格 | `MGrid_background`(172) | `ScaleSprite` | 有效 |
## | 输入框 | `MTextInput_background`(437) | `ScaleSprite` | 有效 |
## | 选中条 | `MSelected_background`(1144) | `ScaleSprite` | 有效 |
## | 进度槽 / 进度填充 | `BaseMBarExp_background`(158) / `BaseMBarExpBg`(164) | `ScaleSprite` | 有效 |
## | 提示框（与提示框底同一张） | `ToolTip_background`(699) | `ScaleSprite` | 有效 |
## | 列表分隔 | `RankWindowListSeparator_background`(476) | `ScaleSprite` | 有效 |
## | **横向分隔线** | `LineHPicF`(133) | **`Sprite`** | **无效，必须全 0** |
## | 滚动槽 / 滚动滑块 | `ScrollTrack_skin`(29) / `ScrollThumb_upSkin`(52) | `MNoResizeWidth9ScaleSprite` | 左右是死值 |
##
## ⚠️ **`MGrid_background`（物品格）是 `ScaleSprite`，九宫格有效** —— 别照 §3.60.2 那句旧结论
##    把它改成全 0（那句把 `MGrid_background` 和 `BaowuBtn1~3` 说成"普通 Sprite"，
##    复核：前者是 `ScaleSprite`、后者是 `MButton3`；那句里**只有 `LineHPicF` 是对的**）。
##
## ⚠️ `MNoResizeWidth9ScaleSprite` 把 `width` setter **整个覆盖成空**
##    （`MNoResizeWidth9ScaleSprite.as:12-14`）⇒ 这类图的宽度**永远不变**，
##    **左右边距是死值**（写多少都一样），只有上下起作用。
##
## ⚠️ **分页选中**那格对上的是 `MTabButtonF`(123)，而它 `extends MTabButton`→`MButton3`→`Sprite`
##    —— 但它是**按钮本体**、不是皮肤（同尺寸的皮肤候选里 `MTabButton_up`(121) 才是 Skin）。
##    它的九宫格保留现状（[9,8,9,4] 是当年在窗口上看着调过的），**这条判据对按钮本体不适用**。
##
## ⚠️ **两条自我更正**，都记在这儿免得再犯：
##    ① §3.61.4 曾把"原版隐藏按钮、靠点条目走过去接"当成真值 —— 那是**死分支**（见 §3.74.6）；
##    ② 我一度写"`列表分隔.png` 找不到元件、没有真值可依" —— **错的**：按 304px 扫 shape 扫不到，
##       是因为**该元件的包围盒来自多个 shape 的组合**，单个 shape 都不是 304 宽。它其实就是
##       `RankWindowListSeparator_background`(476)。**"我这次没扫到" ≠ "它不存在"**。
##
## ⚠️ **烘进 `.tscn` 之前必须取整**（§3.228）：下面这些值允许是**分数**（`40.25`/`7.25`/`12.05` 都是
##    twips÷20 换算的残留，不是刻意的亚像素设计），但 `NinePatchRect` 的 `patch_margin_*` 只收 **int**
##    （探针实测 hint `0..16384px`），而且 `.tscn` 里写分数会被**向零截断**（`29.25` 落地 `29`）
##    ⇒ 文件字面 ≠ 运行期值。四个生成器（`原版服务窗.py`/`生成NPC对话场景.py`/`生成好友场景.py`/
##    `生成家族子窗.py`）统一按**四舍五入、.5 远离 0** 取整，`测试/场景资源回归测试.gd` 腿④ 钉住这件事。
##    ⚠️ 顺序是 **[左, 右, 上, 下]**（跟 `.tscn` 里 left/right/top/bottom 的书写顺序一致），别当 [左,上,右,下]。

const 九宫格 := {
	窗口边框: [48, 48, 29, 13],
	小窗口边框: [50, 52, 26, 18],
	窗口内底: [11, 10, 10, 12],
	子面板: [8, 7, 7, 7],
	浅色面板: [24, 21, 18, 17],
	内容面板: [11, 10, 10, 11],	# 2026-10-02 度量表：下边距 20→11（原为拟合值）
	按钮: [7, 7, 7, 7],
	按钮按下: [7, 7, 7, 7],
	按钮悬停: [7, 7, 7, 7],		# 与常态同一张美术（tag18）的 ±30 派生 ⇒ 边距必然同值
	按钮按下态: [7, 7, 7, 7],	# 同上，−40
	分页未选: [7.25, 7, 7.5, 4.75],	# 2026-10-05 度量表 §4.2（MTabButton_up tag121）
	分页未选悬停: [7.25, 7, 7.5, 4.75],
	分页未选按下: [7.25, 7, 7.5, 4.75],
	分页选中: [9, 8, 9, 4],
	方向箭头: [4.25, 4.25, 1, 9.25],
	物品格: [9, 6, 9, 6],
	输入框: [6, 7, 5, 6],
	选中条: [9, 8, 5, 5],
	进度槽: [6, 6, 4, 4],
	进度填充: [4, 4, 3, 3],
	# 新增（提案值）
	提示框: [10, 10, 10, 10],
	## 提示条底板：**现场从 MainLib 的 DefineScalingGridTag 解出来的**，不是拟合值。
	## 符号 175 的 splitter(twips) Xmin=805 Xmax=5019 Ymin=585 Ymax=4630，÷20 得像素，
	## 再按原生 263×252 换算四条边：左 40.25 / 右 263−250.95=12.05 / 上 29.25 / 下 252−231.5=20.5。
	## （`MessageTipPane2.as:156-204` 的 `draw()` 会改 background 的宽和高 ⇒ 必须走九宫格，
	##   整拉会把左上角那朵云纹一起拉长。）
	提示条底板: [40.25, 12.05, 29.25, 20.5],
	列表分隔: [12, 12, 0, 0],
	# ⚠️ **必须全 0**：`横向分隔线` 对应原版 `LineHPicF`，而它是 `extends Sprite`
	#    （**不是** `ScaleSprite`，见 `2.2.3/.../LineHPicF.as:6`）——
	#    普通 Sprite 的 `width=` 是**整帧非等比缩放**，九宫格那条 8px 端帽根本不生效，
	#    只会把两端的渐隐拉长。原件的渐隐本来就是**跟着宽度一起缩**的。
	#    （对照：`MWindow_background`/`MYellow_background`/`MPane_background` 才是
	#      `ScaleSprite`，那几张的九宫格边距是有效的。）
	横向分隔线: [0, 0, 0, 0],
	滚动槽: [0, 0, 4, 4],
	滚动滑块: [0, 0, 14, 14],
}

# ── 文字色（MButton3._textColors，十进制→十六进制） ──────────
const 按钮色 := "#fcf49c"        # 16577692
const 按钮色悬停 := "#ffffc3"    # 16777155
const 按钮色按下 := "#acadb2"    # 11316658
const 色禁用 := "#939393"        # 9671571
## 按钮文字描边：AS3 里是棕色 `#682300`，但**用户 2026-09-26 定了全局硬规则**
## 「游戏内所有文字：Font Outline 开启、颜色 000000、描边 3；Font Shadow 开启、颜色 00000000」，
## 所以按钮也走黑色描边。这条常量留着只为记录原值，实际不再使用。
const 按钮描边色_原版 : String = "#682300"

# ── 文字硬规则（用户 2026-09-26）────────────────────────────
## **游戏内所有文字**：
##   Font Outline **开启**、颜色 `000000`、描边数值 **3**
##   Font Shadow  **开启**、颜色 `00000000`（全透明 —— 视觉上就是不投影）
##
## 由 `开发工具/生成界面主题.gd` 套到**每一个带文字的类型**上（规格里没显式写就补上），
## 而不是在 类型规格 里逐条抄 —— 因为**变体在运行期拿不到基类的颜色**：
## 实测 `Theme.has_color("font_shadow_color", &"OrigListItem")` 是 **false**（基类 Button 有），
## `get_color` 直接返回不透明的 `Color()`。所以变体必须自己写一份。
## 取值改这里一处即可；`测试/界面主题回归测试.gd` 会核对生成结果、
## 场景里写死的 override（.tscn）与代码里 `add_theme_*_override` 设的那份。
## ⚠️ 2026-09-27 从 3 改回 **2**：
##   用户 09-26 定的规则写的是 3，但 09-27 实机反馈"文字暗淡不清晰"——
##   3px 黑描边压在 11~12px 的宋体上会把笔画糊在一起，正是那个观感。
##   AS3 真值是 `BaseUtil.getGlowFilter()` ≈ **2px**（`BaseUtil.as:111`），故回到 2。
##   要回退只改这一个数，然后重跑 `开发工具/生成界面主题.gd`。
const 文字规则_描边数值 := 2
const 文字规则_描边色 := Color(0, 0, 0, 1)
const 文字规则_阴影色 := Color(0, 0, 0, 0)
const 标题色 := "#efefff"        # 15725823，MWindow._titleTextFormat.color
const 提亮 := "#fff4d8"          # StyleUtil.getLightFilter 的等效 modulate
const 按下暗 := "#e8dcc0"
const 列表项色 := "#ead8bd"
const 列表项按下色 := "#fff0bd"

# ── UIConfig 常量 ─────────────────────────────────────────
const CONTENT_GAP := 8
const BORDER_GAP := 5
const BUTTON_GAP := 4
const TEXT_GAP := 2
## UIConfig.btn_width_one..seven。Theme 无 custom_minimum_size 项，
## 故不做变体，由调用点显式设 custom_minimum_size.x。
const 按钮宽度 := [15, 37, 49, 61, 70, 82, 94]

# ── 字体 ──────────────────────────────────────────────────
## 字体：⚠️ 2026-10-02 从"系统 SimSun（原版字体.tres SystemFont）"换成
## **原版游戏自带的 `www/fonts/simsun.ttf`**（拷成 `simsun_原版.ttf`）。
## 原因：用户并排图指出堆叠数量/货币/标题里的**数字比原版细、还矮一截**。
## 系统 simsun.ttc 的拉丁字形和这份"给 Ruffle 的确定性 SimSun"不一样；
## 原版（含汉字）整份 UI 用的就是它 —— 用它才是"复原原版"，之前拿黑体/Arial Black 只是凑。
## 光栅口径已在 `simsun_原版.ttf.import` 里对齐旧 `原版字体.tres`
## （hinting=2 / subpixel=0 / antialiasing=1 / disable_embedded_bitmaps=false，宋体点阵才清晰）。
## ⚠️ 改这里后必须重跑 `开发工具/生成界面主题.gd`（default_font 烘在 原版主题.tres 里）。
const 字体路径 := "res://素材/界面/simsun_原版.ttf"

## **窗口标题**的合成加粗量（烘进主题变体 `OrigWindowTitle` 的 `FontVariation`）。
## 真值：`MWindow.as:69-74` 的 `_titleTextFormat.bold = true`、`size = 12` ⇒ 只有标题是粗体。
##
## ⚠ 2026-10-25 晚**回滚**了 §3.275 的全局加粗（那一版把这一层套进 `default_font`，
##   全 UI 的 ASCII 都加粗）。用户实机报：「数值方面，数字、字母之类的都模糊了」——
##   合成加粗是把轮廓往外抹，12px 的 ASCII 本来就走轮廓 + 灰度（宋体点阵只覆盖汉字），
##   一加粗整圈边缘全是中间灰 ⇒ 数字、字母发糊。汉字走 12~17ppem 的 EBLC 点阵，不吃这一层。
##   逐条对 AS3 也站不住：`ItemWindowCell.as:60-62` 的数量字**没有** `bold`（只有 size=12 + glow），
##   全库 `bold` 是逐处设的，不是全局口径 ⇒ 正文/数量字必须回到裸 `FontFile`。
## 现在只给窗口标题这一处按 `MWindow` 加粗。要关掉标题加粗：改 0.0 后重跑
## `开发工具/生成界面主题.gd`。
const 标题加粗量 := 1.5


## 取一个 Font 实际落在磁盘上的那份字体文件路径。
## 窗口标题的字体是 `FontVariation`（合成加粗，见 `标题加粗量`），它自己没有
## `resource_path` ⇒ **钉字体的回归门一律走这个函数**，别直接读 `resource_path`
## （否则遇到包了壳的标题字，门会把"字体被换成 Godot 默认"误判成红）。
## 正文/稀疏页面主题是裸 `FontFile`，这个函数原样返回它的路径。
static func 字体落点(字: Font) -> String:
	if 字 == null:
		return "<无>"
	if 字 is FontVariation:
		var 底 := (字 as FontVariation).base_font as Font
		return "<空>" if 底 == null else String(底.resource_path)
	return String(字.resource_path)

## 滚动条宽：原版 `ScrollBar.as:13` WIDTH = 15。
const 滚动条宽 := 15.0

## 按原版口径配滚动区：条宽压到 15，再从区宽里**减去实测**的条宽
## （Godot 的 ScrollBar 最小宽还并着主题样式边距，本工程实测 19 ⇒ 只按常量减会让容器自己变宽、条掉到框外）。
##
## ⚠ 2026-10-14：共用件「原版滚动条」**没有**接在这里。试过 —— 商城那页的滑块直接甩到列表中间
## （见用户实机图）：这个件假设"滚动区的位置与尺寸在调用这一刻已经定死"，而商城的列表区是
## 运行期再定位的 ⇒ 目前**只有心法窗**挂它（`心法窗.配滚动区` → `原版滚动条.挂到`）。
## 要再铺开，先解决"件跟着滚动区的位置/尺寸走"这一条。
static func 配原版滚动区(滚动: ScrollContainer, 内容: Control, 区宽: float, 可视高: float, 内容高: float) -> void:
	var 条 := 滚动.get_v_scroll_bar() as Control
	条.custom_minimum_size = Vector2(滚动条宽, 0.0)
	var 实条: float = maxf(滚动条宽, 条.get_combined_minimum_size().x)
	内容.custom_minimum_size = Vector2(区宽 - 实条, maxf(可视高, 内容高))
## ⚠️ 2026-09-27 从 11 改成 **12**。两条理由：
## 1. **正确性**：原版 `MLabel` 在 `defaultTextFormat` 为空时**写死 12**
##    （`MLabel.as:218-219`）。11 只是 `UIConfig` 的另一个基准，MLabel 压根不用它。
## 2. **清晰度**：宋体的**内嵌点阵只有 12~17px 有 strike**（EBLC v2.0 逐字节读出来的，
##    真值表在 `测试/字体清晰回归测试.gd` 的 `点阵字号真值表`）。11px 及以下、18px 及以上都
##    退回"轮廓+灰度抗锯齿"→ 发虚。实测图见 `开发工具/字号点阵探针.gd`
##    与 `开发工具/_探_点阵与描边实测.gd`（后者还量了描边宽度会不会吃掉点阵）。
##    用户 2026-09-27 报的"字体比原版模糊"就是这个。
const 默认字号 := 12

# ── 主题变体名 ─────────────────────────────────────────────
## Godot 引擎限制：Theme::is_valid_type_name 只接受 ASCII 标识符字符，
## 中文变体名会被 set_type_variation / set_stylebox 拒绝（报 Invalid type name）。
## 故变体名用 ASCII，中文含义在此对照。调用点用这些常量而非裸字符串。
const 变体_窗口标题 := &"OrigWindowTitle"      # 原版窗口标题
const 变体_提示文字 := &"OrigTooltipText"      # 原版提示文字
const 变体_分页 := &"OrigTab"                  # 原版分页
const 变体_列表项 := &"OrigListItem"           # 原版列表项
const 变体_浮层按钮 := &"OrigOverlayButton"    # 原版浮层按钮
const 变体_浅色面板 := &"OrigLightPanel"       # 原版浅色面板
const 变体_窗口边框 := &"OrigWindowFrame"      # 原版窗口边框
const 变体_小窗口边框 := &"OrigSmallWindowFrame"  # 原版小窗口边框
const 变体_内容面板 := &"OrigContentPanel"     # 原版内容面板
const 变体_窗口内底 := &"OrigWindowInner"      # 原版窗口内底
const 变体_物品格 := &"OrigItemSlot"           # 原版物品格（Panel，纯展示）
const 变体_物品格按钮 := &"OrigItemSlotButton"  # 原版物品格（Button，可点击）
const 变体_列表分隔 := &"OrigListDivider"      # 原版列表分隔
## 输入框底（`MTextInput_background`，符号 #437，自然尺寸 125x21）。
## 原版大量把它当**纯展示的底条**用，不是输入框 —— 商城底部货币栏那两条、
## 买卖数量窗的三条价格底、`ShopWindowCell` 的价格底都是它。
## Godot 的 `LineEdit` 自带这条底，但只读的地方用 LineEdit 会带上光标/可选中，
## 所以单给一个 Panel 变体。（2026-09-26 做商城时补的，此前场景里只能拿
## `LineEdit` 或裸 `TextureRect` 顶替 —— 后者会把九宫格拉变形。）
const 变体_输入框底 := &"OrigInputBox"         # 原版输入框底（Panel，纯展示）
## 商城的「充值」按钮。原版是 `ProgramButton` 挂**单张** upSkin
## （`CashMoneyPane.as:74-77`），四态同图，故这里也四态同图。
const 变体_充值按钮 := &"OrigPayButton"        # 原版充值按钮（商城底部）

## 纯布局用的透明 Panel。Panel 类型现在有实底（子面板.png），
## 这些只当定位容器用的节点要显式还原成无底，否则会多出一层背景。
const 变体_透明面板 := &"OrigBlankPanel"       # 原版透明面板
const 变体_透明按钮 := &"OrigBlankButton"      # 原版无外观可点区（MSprite 那类）

# ── 类型规格 ───────────────────────────────────────────────
## 生成器与 测试/界面主题回归测试.gd 共读此表。
##
## 每个条目的键是 Theme 类型名（变体名同样放这里，用 继承 字段标出基类）。
## 样式 项的值：
##   [路径]                       → 九宫格纹理，content 全 0
##   [路径, tint]                 → 同上并 modulate
##   [路径, tint, [左,右,上,下]]  → 同上并指定 content_margin
##   null                         → StyleBoxEmpty
const 类型规格 := {
	"Label": {
		# 用户 2026-09-25 复述的硬规则：**所有文字黑描边 3、阴影关掉**。
		# 原来这里是 Godot 默认那套（描边 0 + 影子 α0.8 + 偏移 1/1），
		# 与规则正好相反 —— 场景里没写 override 的 Label 都会带上原版没有的投影。
		# 2026-09-26 把规则落进皮肤表（此前是手改 .tres，生成器一跑就丢，门也一直红）。
		"颜色": {
			"font_color": "#ffffff",
			"font_shadow_color": Color(0, 0, 0, 0),
			"font_outline_color": "#000000",
		},
		"常量": {"shadow_offset_x": 0, "shadow_offset_y": 0, "outline_size": 文字规则_描边数值, "line_spacing": 0},
	},
	变体_窗口标题: {
		"继承": "Label",
		"颜色": {
			"font_color": 标题色,
			"font_outline_color": "#000000",
			"font_shadow_color": Color(0, 0, 0, 0),
		},
		# 原按 AS3 `getGlowFilter(0,2,2)` 取 2（注释当时写着"与 Ruffle 抓图对比后可能改 3"）。
		# 2026-09-26 用户定下全局硬规则「所有文字描边 3」，这里统一成 3。
		"常量": {"outline_size": 文字规则_描边数值, "shadow_offset_x": 0, "shadow_offset_y": 0},
		"字号": 12,
	},
	变体_提示文字: {
		"继承": "Label",
		"颜色": {
			"font_color": "#ffffff",
			"font_outline_color": "#000000",
			"font_shadow_color": Color(0, 0, 0, 0),
		},
		"常量": {"outline_size": 文字规则_描边数值, "shadow_offset_x": 0, "shadow_offset_y": 0, "line_spacing": 5},
		"字号": 12,
	},
	"Button": {
		# ── 这一族的原版是 `MButtonF`(元件 21) `extends MButton3`：**一组只有一张 upSkin**，
		# 悬停/按下是运行时 `StyleUtil.getLightFilter(+30/−40)`（`StyleUtil.as:7-12`）加在皮肤上。
		#   * `hover` 原来是 `按钮.png × modulate #fff4d8` —— **乘性**，(146,79,28)×#fff4d8
		#     = (146,76,38)，比原版的 +30（176,109,58）几乎看不出来 ⇒ 换成预烘的 +30 那张。
		#   * `按钮按下.png` = 元件 tag15 `MButton_selectedUp` = **选中皮**，不该占 `pressed`；
		#     瞬时按下按原公式该是 upSkin 的 −40 ⇒ 用预烘的 `按钮_按下.png`。
		# ⚠ `Button` **不给 `hover_pressed` 补槽**（10-20 试过，被全量门当场逮回）：按下瞬间引擎走
		#   `DRAW_HOVER_PRESSED` 档，补了槽 = 按下闪一张别的皮 ⇒ 这一族的"按下变暗"只能
		#   **逐颗挂 `脚本/界面/组件/原版三态钮.gd`**（它把五槽并成实例私有的一张再换图，且顺带解决
		#   主题表达不了的"松手回 STATE_UP"`MButton3.as:103-108`）。
		#   ⚠ 原来这里写的是"补槽会让裸 CheckBox 最小高从 27 掉到 19、每一枚勾往上挪 4 ⇒ 别动" ——
		#   **那个 27 不是不能动的死数，是漏声明槽撑出来的几何 bug**（探针当场量出来的，机制见
		#   本表 `CheckBox` 段）；10-25 已在 **CheckBox 自己**这一档补上空盒把地板收回 19，
		#   Button 这一档仍不补（它自己的 min 由皮和文字撑，兜底盒那 8 像素压根不绑）。
		"样式": {
			"normal": [按钮],
			"hover": [按钮悬停],
			"pressed": [按钮按下态],
			"disabled": [按钮, Color(0.5, 0.5, 0.5, 0.75)],
			"focus": null,
		},
		"颜色": {
			"font_color": 按钮色,
			"font_hover_color": 按钮色悬停,
			"font_pressed_color": 按钮色按下,
			# 鼠标压着钮按下时引擎用的是这一档（`DRAW_HOVER_PRESSED`），不写就漏到 Godot
			# 自带主题的白字上 ⇒ 按下瞬间皮是暗的、字却是白的。同 down 档 `#acadb2`。
			"font_hover_pressed_color": 按钮色按下,
			"font_disabled_color": 色禁用,
			# 2026-09-26 硬规则：所有文字描边 #000000（原为 AS3 的棕色 按钮描边色_原版）。
			"font_outline_color": "#000000",
			"font_shadow_color": Color(0, 0, 0, 0),
		},
		"常量": {"outline_size": 文字规则_描边数值, "shadow_offset_x": 0, "shadow_offset_y": 0,
			"h_separation": TEXT_GAP},
		"字号": 12,
	},
	变体_分页: {
		"继承": "Button",
		"样式": {
			"normal": [分页未选],
			"hover": [分页未选悬停],
			# ⚠️ **瞬时按下**走的是 −40 暗态那张（`StyleUtil.as:8-12` `skinFilters={up:0, over:+30, down:−40}`
			# 是**加性逐通道 clamp**、modulate 是乘性 ⇒ 只能预烘一张）。
			# ⚠️ **选中不在这儿** —— 原版 `MTabButton.as:38` `set enabled(v){selected=!v}`：
			# 选中那枚走的是 **disabled 槽**（符号 `MTabButton_disabled` tag118 = `分页按钮选中.png`，
			# **不是禁用皮**），且 `:16-33` 对 DISABLED 档推 `skinFilters[STATE_UP]=0`
			# ⇒ 选中态**不变亮、不变灰**。所以调用点**必须同时置 `disabled`**（§3.139）。
			# 旧账：`分页未选按下` 这个常量早就声明、边距也量过，却一直没接进来。
			"pressed": [分页未选按下],
			"hover_pressed": [分页未选按下],
			"disabled": [分页选中],
			"focus": null,
		},
		# 四态字色同一个（`:12`）⇒ 只有皮肤动、文字不动。
		# ⚠ `font_hover_pressed_color` 必须在这儿**也**写一遍：它上面 `Button` 族刚把这一档
		#   设成 down 的 `#acadb2`，页签是 `继承 Button` ⇒ 不覆盖就会被继承下去，选中/按下那枚
		#   的字会变成灰的（`MTabButton.as:12` 四档同色 ⇒ 只有皮动、字不动）。
		"颜色": {"font_pressed_color": 按钮色, "font_hover_pressed_color": 按钮色,
			"font_disabled_color": 按钮色},
	},
	变体_列表项: {
		"继承": "Button",
		"样式": {
			"normal": null,
			"hover": [选中条, 提亮],
			"pressed": [选中条],
			"focus": null,
		},
		"颜色": {
			"font_color": 列表项色,
			"font_hover_color": "#ffffff",
			"font_pressed_color": 列表项按下色,
		},
	},
	变体_浮层按钮: {
		"继承": "Button",
		"颜色": {"font_focus_color": 按钮色},
	},
	"Panel": {"样式": {"panel": [子面板, Color.WHITE, [10, 10, 7, 7]]}},
	变体_浅色面板: {"继承": "Panel", "样式": {"panel": [浅色面板, Color.WHITE, [10, 10, 7, 7]]}},
	变体_窗口边框: {"继承": "Panel", "样式": {"panel": [窗口边框]}},
	变体_小窗口边框: {"继承": "Panel", "样式": {"panel": [小窗口边框]}},
	变体_内容面板: {"继承": "Panel", "样式": {"panel": [内容面板, Color.WHITE, [2, 2, 2, 2]]}},
	# 窗口内底服务 UIWindow(drawContentBg)，此变体是该美术的首个消费者
	变体_窗口内底: {"继承": "Panel", "样式": {"panel": [窗口内底]}},
	变体_物品格: {"继承": "Panel", "样式": {"panel": [物品格]}},
	# content_margin 与 LineEdit 的 normal 态保持一致（[5,5,2,2]），
	# 这样"同一个底条，编辑态与展示态"看起来是同一个东西。
	变体_输入框底: {"继承": "Panel", "样式": {"panel": [输入框, Color.WHITE, [5, 5, 2, 2]]}},
	# 充值按钮四态同图（原版 ProgramButton 只有一个 upSkin）。65x28 原尺寸使用，
	# 不做九宫格 —— 皮肤表 九宫格 里没有 充值按钮 这一项，生成器会留 0 边距。
	变体_充值按钮: {
		"继承": "Button",
		"样式": {
			"normal": [充值按钮],
			"hover": [充值按钮, 提亮],
			"pressed": [充值按钮],
			"focus": null,
		},
	},
	# 可点击的物品格（背包/仓库格子）。空格子用 disabled 态，与 normal 同图不灰化——
	# 原版空格与有物品的格底图一致，只靠图标区分。
	变体_物品格按钮: {
		"继承": "Button",
		"样式": {
			"normal": [物品格],
			"hover": [物品格, 提亮],
			"pressed": [物品格, 提亮],
			"disabled": [物品格],
			"focus": null,
		},
	},
	变体_列表分隔: {"继承": "Panel", "样式": {"panel": [列表分隔]}},
	变体_透明面板: {"继承": "Panel", "样式": {"panel": null}},
	# 无外观的可点区域。原版 `MSprite` 的 `buttonMode = true` 只换手型光标、不带任何态美术
	# （NPC 商店的商品格就是它）。用 Button 而不是 Panel+gui_input：手型光标与「可点」语义
	# 都白拿，四态全空所以画出来和 Panel 一样。
	变体_透明按钮: {
		"继承": "Button",
		"样式": {"normal": null, "hover": null, "pressed": null, "disabled": null, "focus": null},
	},
	"PanelContainer": {"样式": {"panel": [子面板, Color.WHITE, [10, 10, 7, 7]]}},
	"LineEdit": {
		"样式": {
			"normal": [输入框, Color.WHITE, [5, 5, 2, 2]],
			# 只读态**不许压暗**：原版那张 `MTextInput_background`(元件 437) 就是一个底，
			# 没有"只读就变暗"这一说（`BiGuanWindow.as:146-160` 的 `hourBg/minuteBg` 与
			# `ShouyiWindow.as:69-75` 的 `experienceBg/zhenQiBg` 全是同一张底、同一亮度）。
			# 原来是 `Color(0.8,0.8,0.8)` ⇒ 数字那一格整块比可编辑框暗一档。
			"read_only": [输入框, Color.WHITE, [5, 5, 2, 2]],
			"focus": null,
		},
		"颜色": {
			"font_color": "#ffffff",
			## ⚠ 只读框的字色是**另一个主题项**，而它的真名是 `font_uneditable_color`
			## （`开发工具/查只读字色项名.gd` 现查默认主题 LineEdit 的字色项 =
			##  font_color / font_selected_color / **font_uneditable_color** / font_placeholder_color / …）。
			## 第一版写成 `font_read_only` —— **这种错不报错**：`get_color("错名")` 照样返回自己塞进去的值，
			## 于是门全绿、屏幕上数字最高仍只有 (107,107,107) 的灰（10-20 实测假绿一次）。
			## 原版的数字件是 `BaseUtil.getLabel` = TextField，`ShouyiWindow.as:129`
			## `textColor = #FFFFFF`，**没有可编辑/只读之分**。
			"font_uneditable_color": "#ffffff",
			"font_outline_color": "#000000",
			"font_shadow_color": Color(0, 0, 0, 0),
			"font_placeholder_color": Color(1, 1, 1, 0.45),
			"caret_color": "#ffffff",
			"selection_color": "#4a5a8c",
		},
		"常量": {"outline_size": 文字规则_描边数值, "shadow_offset_x": 0, "shadow_offset_y": 0,
			"minimum_character_width": 4},
		## 10-20 用户报「左页的数字有点小，和原版本不一致」：原版这几处的数字件是
		## `BaseUtil.getLabel("",16777215)`（`BiGuanWindow.as:60-63`、`ShouyiWindow.as:80-85`）
		## = `MLabel`/`MGlowLabel`，而 `MLabel.as:218-219` 的默认 `TextFormat.size = 12`。
		## 原来这里是 10 ⇒ 数字比同一页 12 号的标题小一档，且与本表自己的 `默认字号 = 12` 矛盾。
		"字号": 12,
	},
	"CheckBox": {
		# ⚠ `hover_pressed` **必须显式声明成空盒**（2026-10-25 补，探针 `开发工具/_探_地板来源.gd`）：
		#   这一槽原来谁都没写 ⇒ `CheckBox::_get_minimum_size()` 逐个取六态样式盒的最大时，
		#   沿主题回拿到一块**不画任何东西、但 content_margin 上下各 4** 的兜底盒
		#   ⇒ 最小高从皮肤真实的 **19** 被顶到 **27**（`MCheckBox.as:81-82` 的 `_height = upSkin.height`）。
		#   多出来的 8 有两个后果：① 皮肤在 27 的盒子里**居中** ⇒ 每一枚勾都比烘的 y 低 4 像素画；
		#   ② 原版行距只有 20/21/22（`SuccessWindow.as:126-135`、`KunChongStrengthWindow.as:298-304`）
		#   ⇒ 上下两枚的**点击矩形互相重叠 5~6 像素**（点上一行的下沿会打到下一行）。
		#   补上空盒后最小高 = 19 = 皮肤高 ⇒ 控制矩形就是皮肤矩形，上面两条一起消失。
		#   （只补 CheckBox，不补 `Button`/`OptionButton`：那两族的 min 高由自己的皮和文字撑，
		#     13/12 都远小于兜底盒，补了也不动 ⇒ `Button` 的三态仍走 `原版三态钮.gd` 逐颗挂。）
		"样式": {
			"normal": null, "hover": null, "pressed": null, "focus": null, "disabled": null,
			"hover_pressed": null,
		},
		"图标": {
			"checked": 复选框选中,
			"unchecked": 复选框未选,
			"checked_disabled": 复选框选中,
			"unchecked_disabled": 复选框未选,
		},
		"颜色": {
			"font_color": "#ffffff",
			"font_hover_color": 提亮,
			"font_pressed_color": "#ffffff",
			"font_disabled_color": 色禁用,
			"font_outline_color": "#000000",
			"font_shadow_color": Color(0, 0, 0, 0),
		},
		"常量": {"outline_size": 文字规则_描边数值, "shadow_offset_x": 0, "shadow_offset_y": 0,
			"h_separation": BUTTON_GAP},
		# `MCheckBox extends MButton3`，正文 TextFormat 就是 12（`MButton3.as:130`）⇒ 勾选框的字
		# 跟按钮的字**同一档**，原来的 11 没有出处。
		"字号": 12,
	},
	"OptionButton": {
		"样式": {
			"normal": [输入框, Color.WHITE, [7, 18, 2, 2]],
			"hover": [输入框, 提亮, [7, 18, 2, 2]],
			"pressed": [输入框, 提亮, [7, 18, 2, 2]],
			"disabled": [输入框, Color(0.65, 0.65, 0.65, 1.0), [7, 18, 2, 2]],
			"focus": null,
		},
		"图标": {"arrow": 下拉箭头},
		"颜色": {
			"font_color": "#ffffff",
			"font_hover_color": 提亮,
			"font_pressed_color": "#ffffff",
			"font_disabled_color": 色禁用,
			"font_outline_color": "#000000",
			"font_shadow_color": Color(0, 0, 0, 0),
		},
		"常量": {"outline_size": 文字规则_描边数值, "shadow_offset_x": 0, "shadow_offset_y": 0,
			"arrow_margin": 4},
		# 下拉正文 12：`MComboBox.as:22` 的 `_inputTextFormat = new TextFormat(COMMON_FONT, 12, …)`。
		"字号": 12,
	},
	"PopupMenu": {
		"样式": {
			"panel": [提示框, Color.WHITE, [7, 7, 7, 7]],
			"hover": [选中条],
			"separator": [横向分隔线],
		},
		"图标": {"checked": 复选框选中, "unchecked": 复选框未选},
		"颜色": {
			"font_color": "#ffffff",
			"font_hover_color": 提亮,
			"font_disabled_color": 色禁用,
			"font_outline_color": "#000000",
			"font_shadow_color": Color(0, 0, 0, 0),
		},
		"常量": {
			"outline_size": 文字规则_描边数值,
			"shadow_offset_x": 0,
			"shadow_offset_y": 0,
			"v_separation": TEXT_GAP,
			"h_separation": BUTTON_GAP,
			"item_start_padding": 4,
			"item_end_padding": 4,
		},
		"字号": 12,
	},
	"VScrollBar": {
		"样式": {
			"scroll": [滚动槽],
			"scroll_focus": [滚动槽],
			"grabber": [滚动滑块],
			"grabber_highlight": [滚动滑块, 提亮],
			"grabber_pressed": [滚动滑块, 按下暗],
		},
		"图标": {
			"decrement": 滚动向上,
			"decrement_highlight": 滚动向上,
			"decrement_pressed": 滚动向上,
			"increment": 滚动向下,
			"increment_highlight": 滚动向下,
			"increment_pressed": 滚动向下,
		},
	},
	# 项目当前无横向滚动条；箭头需要旋转后的美术，是这组唯一真缺的资源。
	# 先以空样式占位，待 P7 补图。
	"HScrollBar": {
		"样式": {
			"scroll": [滚动槽, Color.WHITE, [], true],
			"scroll_focus": [滚动槽, Color.WHITE, [], true],
			"grabber": [滚动滑块, Color.WHITE, [], true],
			"grabber_highlight": [滚动滑块, 提亮, [], true],
			"grabber_pressed": [滚动滑块, 按下暗, [], true],
		},
	},
	"HSeparator": {"样式": {"separator": [横向分隔线]}, "常量": {"separation": TEXT_GAP}},
	"ProgressBar": {
		"样式": {"background": [进度槽], "fill": [进度填充]},
		"颜色": {
			"font_color": "#ffffff",
			"font_outline_color": "#000000",
			"font_shadow_color": Color(0, 0, 0, 0),
		},
		# 2026-09-26 硬规则：所有文字描边 3（原来条上数字是 1）。
		"常量": {"outline_size": 文字规则_描边数值, "shadow_offset_x": 0, "shadow_offset_y": 0},
		"字号": 9,
	},
	"SpinBox": {
		"图标": {
			"up": 增加按钮,
			"up_hover": 增加按钮,
			"up_pressed": 增加按钮,
			"up_disabled": 增加按钮,
			"down": 减少按钮,
			"down_hover": 减少按钮,
			"down_pressed": 减少按钮,
			"down_disabled": 减少按钮,
		},
	},
	## HSlider 是唯一没有已验证原版美术的条目：原版设置音量滑块美术不在
	## 通用控件，UISwf 里也未定位到。此处为刻意的近似，P7 从设置 SWF 提取。
	## 测试/UI资源回归测试.gd 断言「占位仍是占位」，防止它因疏忽变成永久实现。
	"HSlider": {
		"占位": true,
		"样式": {"slider": [进度槽], "grabber_area": [进度填充]},
		"图标": {"grabber": 滚动滑块, "grabber_highlight": 滚动滑块, "grabber_disabled": 滚动滑块},
		"常量": {"center_grabber": 0, "grabber_offset": 0},
	},
	"RichTextLabel": {
		# 同 Label 的硬规则：黑描边 3、阴影关掉（原来 0.8 + 偏移 1/1）。
		# ⚠️ `outline_size` / `font_outline_color` 这两项**必须显式写在这里**：
		# 旧 .tres 是手改加上的，皮肤表里没有 —— 一跑生成器就被悄悄删掉（2026-09-26 实测）。
		# `shadow_outline_size` 是另一个键（阴影的描边），原版就是 0，不动。
		"颜色": {
			"default_color": "#ffffff",
			"font_outline_color": "#000000",
			"font_shadow_color": Color(0, 0, 0, 0),
		},
		"常量": {
			"outline_size": 文字规则_描边数值,
			"shadow_offset_x": 0,
			"shadow_offset_y": 0,
			"shadow_outline_size": 0,
			"line_separation": 0,
			"table_h_separation": TEXT_GAP,
			"table_v_separation": TEXT_GAP,
		},
		"字号": 12,
		"字号项": "normal_font_size",
	},
	## MToolTip.PADDING=8，MToolTipText.setValue 设 tf.x=tf.y=7。
	## MToolTipText.draw 里 width-5 / height-(7或3) 是 Flash TextField 2px 边槽与
	## textHeight 不含行距的补偿，Godot 无此怪癖 —— 照搬会让提示框窄 5px，故丢掉。
	"TooltipPanel": {"样式": {"panel": [提示框, Color.WHITE, [7, 7, 7, 7]]}},
	"TooltipLabel": {
		"颜色": {
			"font_color": "#ffffff",
			"font_outline_color": "#000000",
			"font_shadow_color": Color(0, 0, 0, 0),
		},
		"常量": {"outline_size": 文字规则_描边数值, "shadow_offset_x": 0, "shadow_offset_y": 0, "line_spacing": 5},
		"字号": 12,
	},
	"ScrollContainer": {"样式": {"panel": null}},
	## 容器间距刻意全局归零：原版全程绝对定位，CONTENT_GAP/BORDER_GAP/BUTTON_GAP/
	## TEXT_GAP 是在特定位置手工套用的，不是布局引擎默认值。Godot 默认 separation=4
	## 会在每个容器上注入原版从未有过的间距。归零把间距变成显式选择。
	"BoxContainer": {"常量": {"separation": 0}},
	"HBoxContainer": {"常量": {"separation": 0}},
	"VBoxContainer": {"常量": {"separation": 0}},
	"GridContainer": {"常量": {"h_separation": 0, "v_separation": 0}},
	"FlowContainer": {"常量": {"h_separation": 0, "v_separation": 0}},
	"MarginContainer": {
		"常量": {"margin_left": 0, "margin_right": 0, "margin_top": 0, "margin_bottom": 0},
	},
}

