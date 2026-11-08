# Buff 状态图标（左上头像右边那一排）

> 真值来源：`…/2.2.3优化版/HYSJ/logs/swfprobe/as3_MainLib/scripts`（下称 `as3/`）、
> 元件 `symbol430`（头像面板）与 `symbol172`（格底）用 ffdec 从
> `HYSJ/www/act_web_nya_208_isolated/asset/MainLib.swf` 现导。
> 用户 10-25 给的原版实机截图：`3a62aadc-0e2e-4a93-9566-a5909aca0226.png`（304×110）。

## ① 容器与摆位

| 量 | 值 | 出处 |
|---|---|---|
| 容器类 | `BuffPane`（`extends BUI`） | `as3/com/mxw/uifl/controls/BuffPane.as:8` |
| 位置 | `x = charactorInfoPane.width`、**`y` 没设 = 0** | `as3/com/mxw/uifl/UIMain2.as:4253-4254` |
| 头像面板宽度 | **260**（`CharactorInfoPaneF` = symbol430，导出 260×73） | ffdec `-selectid 430`；AS3 类里没有改 width |
| 容器尺寸 / 遮罩 | 700×40，遮罩 700×170（红块，仅裁剪用） | `BuffPane.as:24-31` |
| 排列 | 每行 **6** 个，步距 **41**（40 格 + 1）；`n > 18` 时按 ⌈n/3⌉ 列重排 | `BuffPane.as:75-109` |
| 格尺寸 | 40×40 | `BuffCell.as:70-71` `width = height = 40` |
| 上限 | 18 格（6×3） | `BuffPane.as:81` |

⇒ 第一格左上角 = 屏幕 **(260, 0)**；第 i 格（0 基）= `(260 + i%6*41, 0 + i/6*41)`。

⚠ **本工程的坐标换算**：`状态效果` 挂在 `头像区域` 下面，而那个父节点自己带 `(1, -4)` 的整块补偿
（`选中人物信息` 靠它落到原版 y=0）。所以场景里 `状态效果` 的本地偏移必须是 **(259, 4)**，
屏幕位才是 (260, 0)。判据一律判**屏幕位**（`get_global_rect()`），别判 `position`。
⚠ 已知未决：`角色状态` 底图在本工程落在屏幕 x=5（原版 0..260）⇒ 头像面板整块偏右 5px。
本排按原版屏幕位 260 摆，第一格左边 5px 压在面板 bbox 的右尖上（视觉与原版一致，见
`测试/截图/buff排1025/buff排8x.png`）。要不要把面板整块挪回 0 是另一件事，本轮没动。

## ② 一格（BuffCell）的三层

层序（`setData():234-292` / `updateFamilyData():105-141`）：

1. **格底** `MGrid_background`（symbol172，40×40）——`addChildAt(iconBg, 0)`
   - 导出实测：外框 `#8C5430`（棕），内部 `(40,26,22,129)` **半透明**
   - ⚠ 工程里 `素材/界面/原版窗口/通用控件/物品格.png` 是同一个符号但 **alpha 被压成 255**（#39，待点头），
     Buff 格用本次现导的那张（`状态格底.png`），别拿 `物品格.png` 顶。
2. **图标**（只设 x/y，**不缩放**）：
   - `int(skillId) / 1000000 == 9` **或** `> 9` ⇒ 居中 `((40-w)>>1, (40-h)>>1)`
     （`BuffCell.as:251-261`；40×40 的 Buff 图 ⇒ (0,0)）
   - 否则若带 `pos` ⇒ **(0,0)**（`BuffCell.as:262-266`；结印专用，`JieYinManager.as:227` 写了 `pos:1`）
   - 否则 ⇒ **(3,3)**（34×34 的道具/家徽图）
3. **冷却扇形** `GirdCool(0, 0.4, 40, 10, false)`（`BuffCell.as:63-72`）
   - 黑 alpha 0.4、board 40、圆角 5；`setCoolDown(已过毫秒, 总毫秒)`（`:190`）
   - 只有 `TYPE_SKILL && total < 2100000000` 或 `TYPE_ITEM` 才建（`:279-282`、`:184`）
   - 已过的比例顺时针把黑块吃掉（`GirdCool.draw`，工程已有同源 `脚本/界面/组件/冷却扇形.gdshader`）

悬停提示：`MToolTipTextWithTitle`（`BuffCell.as:136-140/274-278`）
- `title = name`、`desc = desc`
- 技能类每秒追加 `BaseUtil.getLeftTimeText(剩余)`（`updateToolTip:168-175`；`BaseUtil.as:332-348` ⇒ `剩余时间：N天H小时M分S秒`，小时恒显示）
- 道具类追加 `剩余容量：remain/total`（`updateItemToolTip:49-61`）
- `total >= 2100000000`（永久）⇒ **不加时间**、不建扇形（`:163-167`）

## ③ 增 / 更新 / 移除 / 计时

| 行为 | 规则 | 出处 |
|---|---|---|
| 去重键 | (`type`, `skillId`)；同键只更新数据，**位置不动** | `BuffPane.as:152-176` |
| 新格 | `addChild` 到末尾 ⇒ **顺序 = 首次出现顺序**，不分类型 | `BuffPane.as:177-183` |
| `type` 缺省 | 没写 `type` ⇒ `TYPE_SKILL(0)` | `BuffPane.as:145-148` |
| 移除 | `removeBuff(skillId)` **只按 skillId 找、不看 type** | `BuffPane.as:112-139` |
| 计时 | `tick(1000)` 每秒：扇形 + 倒计时 | `SkillHandler.as:225`、`BuffPane.as:187-207` |
| 到点 | alpha 每 120ms 闪 0.5/1，共 10 次（1.2 秒）；`autoRemove` 才删格并发 OVER | `BuffCell.as:194-223` |
| autoRemove | **面板级开关**，每次 add 前设；`addSysBuff` 没设 ⇒ 沿用上一次的值（原版缺陷） | `UIMain2.as:2701/2752/4010`、`SkillHandler.as:327/810/889` |
| 切图 | `removeAllBuffs()` 全清 | `SkillHandler.as:112` |
| 单位 | 技能类 `totalTime/remainTime *= 1000`（帧里是秒）；道具类不动 | `BuffCell.as:240-246` |

## ④ 会出现在这里的全部来源

`type`：0=技能 1=家族 2=道具（`BuffPane.as:11-15`）。
**图标只有五种取法**：`ImgUtil Buff/<族>/<行>/icon`、`PicTool.getSkillPic`、`getPetSkillPic`、`getItemPic`、`getJiaHuiPic`。

| # | 来源（帧 → 函数） | type | skillId | 图标 | 名称 / 说明 | 时长 | autoRemove |
|---|---|---|---|---|---|---|---|
| 1 | 35 `GIVE_BUFF` → `SkillHandler.applyBuff:853-890` | 0 | 帧里的 skillId | skillId<1000：`getPetSkillPic`；否则 `getSkillPic` | `getPetSkillString`/`getSkillString`；描述 `getPetSkillBuffDesc`/`getSkillBuffDesc` | 帧 duration 秒；`duration<0` ⇒ 2100000001 | true |
| 2 | 1811 `SYSTEM_BUF_ACTION` cmd=0 → `SkillHandler.addSysBuff:816-841` | 0（缺省） | **10000000+type** | `Buff/System/<type>` ⇒ System/0、System/1（红封+「活动」） | Buff 行 buffName/buffDesc | 帧 time/duration 秒 | 不设（缺陷） |
| 3 | 1293 `SHUANGBEI` → `onUpateShuangbeiState:785-816` | 0（缺省） | **itemId** | `getItemPic(itemId)` | 道具名/道具 desc | remaining/total 秒 | false |
| 4 | 1294 `SHUXING` → `onUpateShuxingState:305-334` | 0（缺省） | **itemId** | `getItemPic(itemId)` | 道具名/道具 desc | remaining/total 秒 | false |
| 5 | 1292 `ZIDONG_XIAOHAO` → `UIMain2.addAutoConsumeBuff:2681-2708` | **2** | itemId | `getItemPic(itemId)` | 道具名/`buffDesc` | remaining/total 秒 | true |
| 6 | 2324 `STONE_MERGE` → `UIMain2.addStoneMergeBuff:3821-3846` | **0** | itemId | `getItemPic(itemId)` | 道具名/道具 desc | remaining/total 秒 | true |
| 7 | 1290 天气 → `HealHandler.setWeatherBuff:450-482` | 0（缺省） | **9000201+type** | `Buff/Weather/<0..9>` | Buff 行 buffName/buffDesc | int.MAX（永久） | false |
| 8 | 1288 打坐 → `HealHandler.addBuff:119-136` | 0（缺省） | **9000101**（单人）/ **9000102**（双修） | `getSkillPic(9000101/2)`（与 Buff/Heal/0-1 逐像素同图） | 技能名/技能 desc | int.MAX（永久） | — |
| 9 | 1815 动作 6 家族旗 → `SkillHandler.addFlagBuff:641-666` | 0（缺省） | 10000200+地图号+level | `getJiaHuiPic(style)`（34×34） | `Buff/flag/<level>` buffName/buffDesc | 21000000001 | — |
| 10 | 家族徽章 → `UIMain2.addFamilyFlagBuff:2734-2758` | **1** | **0** | `getJiaHuiPic(style)` | 家族名 / 家徽加成文案 | 365 天 | false |
| 11 | VIP → `UIMain2:3992-4014` | **-1** | itemId | `getItemPic(itemId)` | 道具名/desc | int.MAX | false |
| 12 | 1291 连斩 → `LianzhanHandler.applyBuff:46-66` | 0（缺省） | **9000001..9000008** | `getSkillPic(900000n)`（蓝剑；**不是** Buff/Lianzhan 那张刀光） | `Buff/Lianzhan/<阶段*100>` | 帧 remain/total 秒 | — |
| 13 | 结印 → `JieYinManager.showJieYinBuff:77-101` | **0** | 1..12 | `getJieYinIcon(n)` = `Buff/JieYin/<n>`；**`pos:1` ⇒ (0,0)** | Buff 行 buffName/buffDesc | remain / 2 小时 | true |
| 14 | PVP 保护 → `PVPHandler:255-277 / 571-594 / 651-669` | 0（缺省） | 9000300 / 9000301 / 10000150 | `getSkillPic(...)` | `Buff/PK/*` buffName/buffDesc | 21000000001 / 帧秒 | true（第一支） |
| 15 | 罪状 → `PVPHandler.checkAddCrimeBuff:740-800` | 0（缺省） | 行里的 `iconSkillId` | `getSkillPic(iconSkillId)` | `Buff/PK/crimeC..S` name/desc | 21000000001 | — |
| 16 | 决斗 → `JueDouManager:300-321` | 0（缺省） | 技能 id | `getSkillPic` | 技能名/desc | 21000000001 | — |
| 17 | 护送 → `HuSongQuestManager.addBuff:242-266` | **0** | **-9999** | `getItemPic`（旗子图） | `HUSONG_BUFF_TITLE/DESC` | 帧秒 | true |
| 18 | 轮回眼 → `LunHuiYanManager:173-193` | 0（缺省） | itemId | `getItemPic` | 道具名/desc | 帧秒 | true |
| 19 | 柔拳 → `RouQuanManager:104-124` | 0（缺省） | itemId | `getItemPic` | 道具名/desc | 帧秒 | true |
| 20 | 宠物祝福 → `PetHandler.onPetUpdateZhufuState:532-545` | 0（缺省） | itemId | `getItemPic` | 道具名/desc | 帧秒 | true |
| 21 | 木叶VS晓 → `MuVsXiaoHandler:60-85` | 0（缺省） | 技能 id | `getSkillPic` | 技能名/desc | 2100000001 | — |
| 22 | 血继限界 → `SkillHandler.addXueJiBanBuff:998-1019` | 0（缺省） | 技能 id | `getSkillPic` | 技能名/desc | 定值 | — |
| 23 | 网吧特权 → `SkillHandler.addNetbarBuff:1327-1342` | 0（缺省） | 技能 id | `getSkillPic` | 技能名/desc | 定值 | — |
| 24 | 飞雷神/分身 → `AbstractCloseAttackEffect:182-233` | 0（缺省） | 技能 id | `getSkillPic` | 技能名 + 固定描述 | 帧毫秒/1000 | true |

## ⑤ 图标总表

**Buff 数据（`数据/状态图标.json`，62 行，全景见 `<临时目录>/状态图标总览.png`）**

| 族 | 键 | 张数 | 说明 |
|---|---|---|---|
| System | `System/0`、`System/1` | 2 | 红封 +「活动」：系统双倍经验 / 双倍精华 |
| Weather | `Weather/0..9` | 10 | 晴/小中大雨/小中大雪/薄雾/大雾/浓雾（8/9 别写反） |
| flag | `flag/1..10` | 10 | 家族旗加成（1~10 级） |
| Lianzhan | `Lianzhan/100..800` | 8 | 连斩阶段（**只用于文案**；HUD 图标取技能图） |
| Heal | `Heal/0`、`Heal/1` | 2 | 单人打坐 / 双修（与 9000101/2 同图） |
| JieYin | `JieYin/1..12` | 12 | 子丑寅…亥印（图标本身要 (0,0)） |
| PK | `PK/protect`、`hangProtect`、`crimeB/A/S/C`、`warfield_enter`、`flagwar`、`PkLose1..5`、`PkWin1..5` | 18 | 保护/夜护/叛忍/神器资格/领域战/越挫越勇/知难而进 |

**非 Buff 数据图**：
- 技能图标 `素材/技能/900/skill/…`：9000001-8（连斩）、9000101-2（打坐）、9000201（网吧）、9000300/1（PVP 保护）、所有 GIVE_BUFF 的 skillId
- 宠物技能图标（skillId < 1000）
- 道具图标 `getItemPic(itemId)`：双倍/属性/自动补给/宝石合成/护送旗/轮回眼/柔拳/宠物祝福/VIP
- 家徽 `素材/界面/原版窗口/家族/家徽_<style>.png`（34×34）：家族徽章、家族旗

## ⑥ 我们当前的差距（10-25 实测）

| # | 差距 | 依据 |
|---|---|---|
| 1 | **格底缺 `MGrid_background`** ⇒ 道具/技能图标直接浮在世界上 | 用户截图；`BuffCell.as:249` |
| 2 | 容器在 **(263,4)**，原版 **(260,0)** | `UIMain2.as:4254` + symbol430 宽 260 |
| 3 | **1811 系统双倍帧没有消费者** ⇒ 原版那两个「活动」图标永远不出现 | 服务端 `_send_system_activity_buffs` 在发，客户端 `后端连接.gd` 无 1811 |
| 4 | 连斩用了 `Buff/Lianzhan` 那张刀光，原版是技能图 900000n（蓝剑） | 1600/1600 像素不同 |
| 5 | 顺序写死（天气→道具→增益），原版是**到达序** | `BuffPane.as:177-183`；原版截图顺序 = 系统0、系统1、打坐、天气 |
| 6 | 没有冷却扇形、没有到点 1.2 秒闪烁 | `BuffCell.as:63-72/194-223` |
| 7 | 图标偏移靠 `stretch_mode=5` 蒙对 40×40 与 34×34 两档，`pos` 档与「40×40 但要 (3,3)」档都不对 | `BuffCell.as:251-270` |

## ⑦ 判据（改完要钉的）

1. 18 格每格 = 格底 + 图标 + 扇形；格底贴图逐字节等于 symbol172 导出图。
2. 容器**屏幕位** `== (260,0)`（本地 (259,4)，因为父节点带 (1,-4)）；格距 41、6 列。
3. 图标偏移三档：40×40 技能/系统/天气 ⇒ (0,0)；34×34 道具/家徽 ⇒ (3,3)；`pos` ⇒ (0,0)。
4. 1811 cmd=0 建格、cmd=1 收格；图标 = `System/<type>`；标题/说明 = 表里那行；永久项无扇形。
5. 顺序 = 首次到达序（刷新帧不许把已有格挪位）。
6. 有限时长的技能/道具格：扇形 `progress = 已过/总`；到点后闪 1.2 秒再收（autoRemove 档）。

## ⑧ 本轮落地与实测（2026-10-25）

| 项 | 落地 | 证据 |
|---|---|---|
| 格底 | 新素材 `素材/界面/原版窗口/通用控件/状态格底.png`（symbol172 原图，661 字节，md5 `cbc4317…`） | 门判每格 `texture` 路径 |
| 层栈 | 18 格各加 `图标`(TextureRect) + `扇形`(ColorRect + ShaderMaterial，alpha 0.4) | 门判 18×3 层齐全 |
| 摆位 | 屏幕 (260,0)；本地 (259,4) | 门判 `get_global_rect()` |
| 图标落点 | `_图标偏移()` 三档（`BuffCell.as:251-270`） | 门 4 条 + 有头 4 条 |
| 1811 | `后端连接` 新增 `OP_SYSTEM_BUF_ACTION`/`system_buff_received`；`游戏会话._on_backend_system_buff` → `System/<type>` | 门从**文本帧** `1811:0:…` 走整条链 |
| 顺序 | `_到达时刻` 键表 + 稳定排序（首次出现序） | 门"先到甲 / 后到乙反序喂" |
| 连斩图标 | 改成技能图 900000n（原版 `LianzhanHandler:54`） | — |
| 打坐图标 | 改成技能图 9000101/2（同图，来源对齐） | — |
| 扇形/闪烁 | 有限时长画扇形；到点闪 1.2 秒再收 | 门 + `buff状态回归测试` 改判 |

- 离线门 `测试/状态图标回归测试.gd`：**335 条断言，红 0**（末行原文见 `<临时目录>/状态图标门.log`）。
- 变异实测 3/3 全抓到：A 格底换回占位图 → 1 红；B 顺序退回列表序 → 5 红；
  C 1811 不接线 → 5 红（`<临时目录>/变异状态图标门.py`，跑完已还原、复跑绿）。
- 有头量具 `开发工具/截Buff排.gd`：**29 条断言红 0**（含**真 InputEventMouseMotion** 悬停 → 原版提示框弹出、
  标题 = 系统双倍经验、剩余时间跟着走），出
  `测试/截图/buff排1025/{整屏.png, buff排.png, buff排8x.png, 悬停提示.png, 对照_原版vs我们.png}`。
- 连带门：`buff状态回归测试`（改判：格底/闪烁/槽位）、`家族页回归测试`（夹具补两层）、
  `姓名战斗挂机`、`目标信息条`、`信息条遮挡与箭头`、`脚本加载`、`人物秘术页` 全绿。
- 全量离线门（`python 开发工具/跑全部离线门.py`）末行原文：
  `汇：共 170 条（本次跑第 1..170，实跑 170），绿 162，红 8，挂 0`。
  8 条红**都不是本轮引起的**（本轮改的文件不被它们引用）：`场景资源`/`UI资源`/`家族子窗几何`
  = 缺 `素材/界面/原版窗口/家族/钮底66.png`；`地图烘焙` = 14 张烘焙产物 bake_hash 陈旧；
  `界面主题` = 竞技场窗 10 处 override + 战场倒计时/镜头节拍记录代码 override；
  `看别人属性窗` = 立绘 2 号造型没画；`家徽显示` = 家徽图被染过色（200 张）；
  `写轮眼状态图标` = 世界状态 02..12 缺图（头顶那排，不是本排）。
