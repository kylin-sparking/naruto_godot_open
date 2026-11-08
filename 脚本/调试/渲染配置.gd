class_name RenderProfile
extends RefCounted

## 原版界面的设计分辨率。游戏逻辑和场景资源继续使用这套坐标。
## 960x560 来自反编译 AS3 的 Config.as:152/192（Flash 舞台尺寸），
## MWindow 居中、拖动钳制、MToolTip 边缘钳制都把这两个数当常量读。
const DESIGN_SIZE := Vector2i(960, 560)
## 世界画面的缩放。原版是 1.0（舞台 960x560 一比一），
## 这里按用户要求**有意放大镜头**（世界看起来更大、屏幕里看到的地图范围更小）。
## 只影响世界层；HUD 走 `UI_CANVAS_SCALE`，不受它影响。
## 改这个数就是"镜头拉近/拉远"：数值越大，屏幕里看到的世界范围越小。
const WORLD_SCALE := 1.0
## 默认视口直接按设计分辨率渲染，避免超采样造成四倍填充率和场景节点开销。
const RENDER_SIZE := DESIGN_SIZE
const WORLD_CAMERA_ZOOM := Vector2(WORLD_SCALE, WORLD_SCALE)
## HUD 始终使用原始设计坐标和单位画布变换。
const UI_CANVAS_SCALE := 1.0
## 底部技能栏高度。原版 MenuPane 是 101px，这是唯一同时有美术支撑
## （技能面板.tscn 的 offset_top）和测试断言的值。聊天面板与相机都从这里读，
## 避免同一根条在三处各写一个数。
const 底栏高度 := 101.0

## ── 世界内容的 z 分层 ────────────────────────────────────────────────
##
## 原版的规则（`AbstractPhysicObject.tikcLayer` + `ALayerManager.addChildWithOutRemove`）：
##   1. 世界内容按 foothold 的**顶层键**（`MapData.as:360` 的 `index1`，取值 0..7）分成
##      ALayer 0..7，层与层之间整体前后有序；
##   2. 层**内**先放全部 BOTTOM 项（该层的瓦片与物件），再放角色 —— 角色之间按
##      `foothodY`（= 所站脚点的 y1）排序。
## 客户端没有 ALayer 结构，用 `z_index` 模拟它，所以两条都要在 z 上体现出来。
##
## ⚠️ 这里踩过一个坑：Godot 的 `z_index` 只有 ±4096
## （`RenderingServer.CANVAS_ITEM_Z_MIN/MAX`），旧口径 `层号 * 2000 + 偏移` 在 8 层下
## 直接溢出（层 2 = 4001、层 7 = 14001 被 clamp），而角色用的是 `100 + y` —— 落在
## **层 0 的带里**。于是角色站在哪一层的地面上，就被那一层的瓦片盖住：看起来就是
## "人物走上去陷进地面"。层带改成 512，8 × 512 = 4096 正好塞得下。
const 世界层带 := 512
## 层内三段。**装饰物在地面之下**：原版 `MapRender.drawGroup()` 每层都是
## "先把物件按 mapZ 加进 ALayer，再把瓦片按 mapZ 加进去"，后加的在上，
## 所以**瓦片压着物件**；角色最后加，压着两者。层内顺序 = 物件 → 瓦片 → 角色。
const 层内物件槽 := 128
const 层内瓦片槽 := 128
const 层内地形零点 := 64   ## mapZ 的取值范围按 -63..63 折算进来

## 装饰物（MapObject）的 z。`mapZ` = 数据里的 z 字段。
static func 物件z(层号: int, mapZ: int = 0) -> int:
	return 层号 * 世界层带 + clampi(mapZ, -层内地形零点 + 1, 层内地形零点 - 1) + 层内地形零点

## 地面/平台（MapTile）的 z。`mapZ` = 瓦片描述符里的 z；层内恒高于同层物件。
static func 瓦片z(层号: int, mapZ: int = 0) -> int:
	return (层号 * 世界层带 + 层内物件槽
		+ clampi(mapZ, -层内地形零点 + 1, 层内地形零点 - 1) + 层内地形零点)

## 角色的 z。`层内序` 见 `地表.gd` 的 角色z()，由 foothodY 压到 0..255。
static func 角色z(层号: int, 层内序: int) -> int:
	return (层号 * 世界层带 + 层内物件槽 + 层内瓦片槽
		+ clampi(层内序, 0, 世界层带 - 层内物件槽 - 层内瓦片槽 - 1))
