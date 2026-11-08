#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""天气池的常驻门（2026-10-27 用户改需求）。

用户原话：**「地图天气目前看似乎是所有地图相同天气，随机刷新。希望改成每个大地图和其对应的
子地图同一个天气池，每个大地图的天气池做一定差别，例如木叶村晴天概率更大，波之国下雨和有雾
天气概率更大，其他类似做一定差别，但差别不能过大。如果没有对应大地图，就单独一个天气池，
大部分副本地图统一为晴天。」**

⚠ 这是一条**有意偏离原版**的需求：原版全服只有一条天气 —— `Buff.Weather` 的 ratio
是「晴 34、其余九档各 11」（合计 133），服务端每 5 分钟摇**一个全局值**、`1570` 广播
（`Client.as:3790 onWeatherChange` 也只收一个类型号，画什么全是客户端定的，见
`真值/地图/天气特效.md`）。所以本门钉的是**我们自造的池**，别再"改回全局一条"。

为什么门在服务端：天气类型号只有服务端会摇（客户端只消费），概率、池归属、换图重发
全在夹具里 —— 客户端那条视觉门（`测试/天气特效回归测试.gd`）钉的是 AS3 的三张名单和
浓度，跟池无关，改池子不该动它。

跑法（仓库根）：
    python -X utf8 开发工具/服务端天气池体检.py
退出码：红 > 0 ⇒ 非 0。判决只看最后一行 `汇：判 N 条 / 红 M 条`。
"""
from __future__ import annotations

import inspect
import sys
import time
from pathlib import Path

根 = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(根 / "开发工具"))

红: list[str] = []
判 = 0


def 查(条件: bool, 说明: str) -> None:
    global 判
    判 += 1
    if not 条件:
        红.append(说明)


class _假GM:
    """只够 `_refresh_weather` 用：天气覆盖由测试说了算（免得吃到磁盘上残留的 GM 指定天气）。"""

    def __init__(self) -> None:
        self.覆盖: int | None = None

    def weather_override(self, now: int | None = None) -> int | None:
        return self.覆盖


def 主() -> None:
    import 服务端目录

    夹具 = 服务端目录.加载()
    目录 = 夹具.GAME_DATA_CATALOG
    类型名 = {0: "晴", 1: "小雨", 2: "中雨", 3: "大雨", 4: "小雪", 5: "中雪",
             6: "大雪", 7: "薄雾", 8: "大雾", 9: "浓雾"}

    def 晴概率(权重: tuple[int, int, int, int]) -> float:
        return 权重[0] / sum(权重)

    def 族概率(权重: tuple[int, int, int, int], 族: int) -> float:
        return 权重[族] / sum(权重)

    # ── ① 量纲：默认池必须**等于原版 `Buff.Weather` 的 ratio**，点名池必须合计 133 ──────
    原 = {int(k): 夹具.GameDataCatalog._as_int(v.get("ratio", 0), 0)
          for k, v in 目录.weather_definitions.items() if isinstance(v, dict)}
    查(len(原) == 10 and set(原) == set(range(10)),
      f"① 原版 Weather 表应正好 0..9 十档，实得 {sorted(原)}（缺档 ⇒ 下面全假绿）")
    查(原.get(0) == 34 and all(原.get(t) == 11 for t in range(1, 10)),
       f"① 原版 ratio 应是晴 34 / 其余各 11，实得 {原}（量纲变了就是池表全部失真）")
    默认 = 夹具.GameDataCatalog.WEATHER_POOL_DEFAULT
    查(sum(默认) == 133 and sum(原.values()) == 133,
       f"① 默认池合计 {sum(默认)} 应 = 原版 ratio 合计 {sum(原.values())} = 133")
    查(默认 == (原[0], 原[1] + 原[2] + 原[3], 原[4] + 原[5] + 原[6], 原[7] + 原[8] + 原[9]),
       f"① 默认池 (晴,雨,雪,雾) 应 = 原版逐档之和，实得 {默认}（默认池不等于原版就是"
       f"「顺手改了基准概率」）")
    for 名, 表 in (("按区域", 夹具.GameDataCatalog.WEATHER_POOL_BY_AREA),
                   ("按大地图", 夹具.GameDataCatalog.WEATHER_POOL_BY_BIG_MAP),
                   ("副本底色", {"-": 夹具.GameDataCatalog.WEATHER_POOL_DUNGEON})):
        for 键, 权重 in 表.items():
            查(len(权重) == 4 and all(int(w) >= 0 for w in 权重),
               f"① {名}[{键}] 应是 4 个非负整数（晴/雨/雪/雾），实得 {权重}")
            查(sum(权重) == 133,
               f"① {名}[{键}] 合计 {sum(权重)} 应 = 133 —— 与原版同量纲，概率才能直接比")

    # ── ② 键的合法性 ─────────────────────────────────────────────────────────
    for 区 in 夹具.GameDataCatalog.WEATHER_POOL_BY_AREA:
        查(100 <= 区 < 1000, f"② 区域键 {区} 应是图号前 3 位（100..999）")
    for 大 in 夹具.GameDataCatalog.WEATHER_POOL_BY_BIG_MAP:
        查(大 % 10000 == 0, f"② 大地图点名键 {大} 必须是「子图号清零」的图号（% 10000 == 0）")
        查(大 in 目录.raw_maps,
           f"② 大地图点名键 {大} 在本地地图表里不存在 ⇒ 这条点名永远轮不到（写了个死键）")

    # ── ③ 族内均分：单调、保和、不出现"中雨比小雨常来" ─────────────────────────
    拆 = 目录.weather_family_split
    查(拆(33) == (11, 11, 11), f"③ 族权重 33 应均分成 (11,11,11) = 原版三档，实得 {拆(33)}")
    for 族 in range(0, 134, 7):
        得 = 拆(族)
        查(sum(得) == 族, f"③ 族权重 {族} 拆完应保和，实得 {得}（合计 {sum(得)}）")
        查(得[0] >= 得[1] >= 得[2], f"③ 族权重 {族} 应「轻档 ≥ 中档 ≥ 重档」，实得 {得}")
    查(拆(0) == (0, 0, 0), f"③ 族权重 0 应整族不下发（晴=唯一的非零档），实得 {拆(0)}")

    # ── ④ 池归属：子图跟大地图、散图自己一池 ────────────────────────────────────
    查(目录.weather_pool_key(104_010_000) == 104_010_000,
       "④ 波之国本岛的池号就是它自己")
    for 子 in (104_010_001, 104_010_002, 104_010_999):
        查(目录.weather_pool_key(子) == 104_010_000,
           f"④ 子图 {子} 应跟大地图 104010000 同一个池（用户点名要的「大地图+子地图同池」）")
    查(目录.weather_pool_key(112_040_002) == 112_040_000,
       f"④ 真实子图 112040002 应并到 112040000，实得 {目录.weather_pool_key(112_040_002)}")
    散图 = [图 for 图 in 目录.raw_maps if 图 % 10000 != 0 and 图 // 10000 * 10000 not in 目录.raw_maps]
    查(bool(散图), "④ 本地表里应至少有一张「没有对应大地图」的散图（用户要它单独一池，没有就得复核规则）")
    for 图 in 散图[:8]:
        查(目录.weather_pool_key(图) == 图,
           f"④ 散图 {图} 没有对应大地图 ⇒ 应「自己就是一个池」（池号 = 自己的图号），实得 {目录.weather_pool_key(图)}")
    查(目录.weather_pool_key(999_999_999) == 999_999_999,
       "④ 规则兜底：凭空一张没有大地图的图，池号就是它自己（不许悄悄并给别人）")

    # ── ⑤ 概率差别：有名字的事实 + 「差别不能过大」的硬界 ─────────────────────
    木叶 = 目录.weather_pool_weights(100_000_000)
    波 = 目录.weather_pool_weights(104_010_000)
    雨隐 = 目录.weather_pool_weights(109_010_000)
    雷 = 目录.weather_pool_weights(111_010_000)
    砂 = 目录.weather_pool_weights(106_010_000)
    副本 = 目录.weather_pool_weights(462_010_000)
    查(晴概率(木叶) > 晴概率(默认),
      f"⑤ 用户点名「木叶村晴天概率更大」：木叶 晴 {晴概率(木叶):.1%} 应 > 原版 {晴概率(默认):.1%}")
    查(族概率(波, 1) + 族概率(波, 3) > 族概率(默认, 1) + 族概率(默认, 3),
      f"⑤ 用户点名「波之国下雨和有雾概率更大」：波之国 雨+雾 "
      f"{族概率(波, 1) + 族概率(波, 3):.1%} 应 > 原版 {族概率(默认, 1) + 族概率(默认, 3):.1%}")
    查(族概率(波, 1) + 族概率(波, 3) > 族概率(木叶, 1) + 族概率(木叶, 3),
       "⑤ 波之国的雨+雾应**明显高于**木叶村（两张图得能看出来不一样）")
    查(族概率(雨隐, 1) > 族概率(波, 1),
       f"⑤ 雨隐村（设定终年下雨）雨族 {族概率(雨隐, 1):.1%} 应 > 波之国 {族概率(波, 1):.1%}")
    查(族概率(雷, 2) > 族概率(默认, 2),
       f"⑤ 雷之国的雪族应高于原版，实得 {族概率(雷, 2):.1%} vs {族概率(默认, 2):.1%}")
    查(晴概率(砂) > 晴概率(默认),
       f"⑤ 砂之国（沙漠）晴应高于原版，实得 {晴概率(砂):.1%}")
    查(晴概率(副本) >= 0.85,
       f"⑤ 用户口径「大部分副本地图统一为晴天」：副本底色晴应 ≥ 85%，实得 {晴概率(副本):.1%}")
    查(族概率(目录.weather_pool_weights(462_030_000), 3) > 族概率(副本, 3),
       "⑤ 迷雾水岸是点名例外（雾应明显高于副本底色），否则这条例外白写")
    for 图 in sorted(目录.raw_maps):
        权重 = 目录.weather_pool_weights(图)
        池 = 目录.weather_pool_key(图)
        是副本 = 池 // 1_000_000 >= 400 or 池 in 夹具.GameDataCatalog.WEATHER_POOL_DUNGEON_BIG_MAPS
        查(0.07 <= 晴概率(权重) <= 0.95,
           f"⑤ 图 {图} 的晴概率 {晴概率(权重):.1%} 越界 [7%, 95%] ⇒「差别过大」或这张图永不下雨")
        for 族 in (1, 2, 3):
            查(族概率(权重, 族) <= 0.62,
               f"⑤ 图 {图} 的族 {族} 概率 {族概率(权重, 族):.1%} > 62% ⇒ 一整族压过晴，天气观感失衡")
        ## 「差别不能过大」这条**只管野外观景图**：副本按用户口径「统一为晴天」（晴 90%），
        ## 豁免按**实际吃到的池**判，不按图号段判 —— 跨服战场/竞技场挂在区域 100 下面，
        ## 只按 `图 >= 400_000_000` 豁免就漏了它们，按号段判它们却又会被当成野外观景图。
        查(是副本 or abs(晴概率(权重) - 晴概率(默认)) <= 0.30,
           f"⑤ 野外图 {图} 的晴概率与原版差 {abs(晴概率(权重) - 晴概率(默认)):.1%} > 30 个百分点"
           f"（用户要求「差别不能过大」；只有吃副本底色那批豁免，这张图池={池} 权重={权重}）")

    # ── ⑤b 副本点名集合与两张表不能互相打脸 ────────────────────────────────
    副本底 = 夹具.GameDataCatalog.WEATHER_POOL_DUNGEON
    for 大 in 夹具.GameDataCatalog.WEATHER_POOL_DUNGEON_BIG_MAPS:
        查(大 % 10000 == 0 and 大 in 目录.raw_maps,
           f"⑤b 副本点名大地图 {大} 必须是「子图号清零」且真存在的图")
        查(目录.weather_pool_weights(大) == 副本底,
           f"⑤b {大} 在 `WEATHER_POOL_DUNGEON_BIG_MAPS` 里，池权重却不是副本底色（实得 "
           f"{目录.weather_pool_weights(大)}）⇒ 那条「晴 90%」的口径没落到它身上")
        查(大 not in 夹具.GameDataCatalog.WEATHER_POOL_BY_BIG_MAP,
           f"⑤b {大} 两处都写了：点名表那条会被副本底色盖掉 = 死代码，只能留一处")

    # ── ⑤c 三层表的**优先序**：点名 > 区域 > 默认（点名写了却不生效 = 那张表是装饰） ──
    ## ⚠ ⑤ 那一串比的是概率关系（木叶晴多、波之国雨多…），**换到区域表上这些关系多半还成立**
    ## ⇒ 单靠 ⑤ 抓不住「点名表被无视」这种变异（2026-10-27 反向对照第一版就是这么漏的）。
    ## 所以这里逐条钉「这张图吃到的权重 == 表里写的那条」，并且钉**它跟上一层确实不同** ——
    ## 两条一起才不是同义反复。
    域表 = 夹具.GameDataCatalog.WEATHER_POOL_BY_AREA
    名表 = 夹具.GameDataCatalog.WEATHER_POOL_BY_BIG_MAP
    副本集合 = 夹具.GameDataCatalog.WEATHER_POOL_DUNGEON_BIG_MAPS
    for 大, 权重 in 名表.items():
        查(目录.weather_pool_weights(大) == 权重,
           f"⑤c 点名表写了 {大}={权重}，实际吃到 {目录.weather_pool_weights(大)} ⇒ 点名没压过区域，这条白写")
        区 = 大 // 1_000_000
        区域权重 = 域表.get(区)
        查(区域权重 is None or 权重 != 区域权重,
           f"⑤c {大} 点名的权重和它所在区域 {区} 一模一样 ⇒ 空写一条，判不出优先序")
    for 区, 权重 in 域表.items():
        活 = [图 for 图 in sorted(目录.raw_maps)
               if 图 // 1_000_000 == 区
               and 目录.weather_pool_key(图) not in 名表 and 目录.weather_pool_key(图) not in 副本集合]
        ## 区域层是「这个家族里没被点名的那些图」的默认。**当前可能整族都点完了**
        ## （木叶 100 就是这样：本村/学校两个点名 + 战场/竞技场两个副本点名，没有余图）
        ## ⇒ 拿"活图"当判据会假红，拿**规则**当判据：造一张同区域、没点名的图号，必须吃到这条。
        测 = 区 * 1_000_000 + 990_000
        查(目录.weather_pool_key(测) == 测 and 测 not in 名表 and 测 not in 副本集合,
           f"⑤c 给区域 {区} 造的探针图 {测} 本身就不干净（撞上点名/副本），这条判据无从谈起")
        查(目录.weather_pool_weights(测) == 权重,
           f"⑤c 区域 {区} 写了 {权重}，同区域没点名的图 {测} 实际吃到 {目录.weather_pool_weights(测)}"
           f" ⇒ 区域层没接上（当前该区域被活图吃到的是 {len(活)} 张）")
    ## 默认层（= 原版 ratio）同理：本地表里区域 100..112 点全了，**没有**一张活图回落到它，
    ## 但规则上「查无此区的图」就该按原版 ⇒ 用 20x 这种没登记的区当探针（≥400 会被副本层截走）。
    探默认 = 200_990_000
    查(目录.weather_pool_weights(探默认) == 默认,
       f"⑤c 三层都不沾的图 {探默认} 应回原版默认 {默认}，实得 {目录.weather_pool_weights(探默认)}")
    查(目录.weather_pool_weights(400_990_000) == 副本底
       or 400_990_000 in 名表,
       "⑤c 区域 ≥400 的图应吃副本底色（用户口径「大部分副本统一为晴天」那条规则的钉）")

    # ── ⑥ 确定性（同池同刻恒等）与「还在随机刷新」 ───────────────────────────
    期 = 1_700_000_000 // 300
    for 图 in (104_010_000, 104_010_007, 400_000_900):
        值 = {目录.weather_for_map(图, 期 + k)[0] for k in range(300)}
        查(len(值) >= 2,
           f"⑥ 图 {图} 连摇 300 期只出 {sorted(值)} 一种类型 ⇒「随机刷新」这条没了")
    查(目录.weather_for_map(104_010_000, 期) == 目录.weather_for_map(104_010_000, 期),
       "⑥ 同池同期必须**恒等**（否则同一张图两个人看见两种天气）")
    同 = all(目录.weather_for_map(104_010_000, 期 + k)[0] == 目录.weather_for_map(104_010_009, 期 + k)[0]
             for k in range(300))
    查(同, "⑥ 大地图与它的子图 300 期**逐期相等**才算同一个池（用户核心诉求）")
    不同 = sum(1 for k in range(300)
               if 目录.weather_for_map(100_000_000, 期 + k)[0] != 目录.weather_for_map(104_010_000, 期 + k)[0])
    查(不同 >= 60,
       f"⑥ 木叶村 vs 波之国 300 期只有 {不同} 期不同 ⇒ 两个池其实没分开（应远多于 60）")
    独 = sum(1 for k in range(300)
             if 目录.weather_for_map(400_000_900, 期 + k)[0] != 目录.weather_for_map(401_000_000, 期 + k)[0])
    查(独 >= 20,
       f"⑥ 散图 400000900 应有自己的池（和 401000000 300 期只差了 {独} 期 ⇒ 池没分开）")

    # ── ⑦ 实测频率与权重吻合（池子真的在起作用，不是查表好看） ────────────────
    for 图, 权重 in ((100_000_000, 木叶), (104_010_000, 波), (109_010_000, 雨隐)):
        计 = {t: 0 for t in range(10)}
        总 = 4000
        for k in range(总):
            计[目录.weather_for_map(图, 期 + k)[0]] += 1
        实测晴 = 计[0] / 总
        查(abs(实测晴 - 晴概率(权重)) <= 0.03,
           f"⑦ 图 {图} 4000 期实测晴 {实测晴:.1%}，权重说 {晴概率(权重):.1%} ⇒ 偏差 > 3 个百分点"
           f"（种子或摊档写错了）")
        实测雨雪雾 = [sum(计[t] for t in range(1, 4)) / 总, sum(计[t] for t in range(4, 7)) / 总,
                      sum(计[t] for t in range(7, 10)) / 总]
        for 族 in (1, 2, 3):
            查(abs(实测雨雪雾[族 - 1] - 族概率(权重, 族)) <= 0.03,
               f"⑦ 图 {图} 第 {族} 族实测 {实测雨雪雾[族 - 1]:.1%} vs 权重 {族概率(权重, 族):.1%}")

    # ── ⑧ 边界：原版 Weather 表没加载 ⇒ 永远晴（与旧写法的同一条兜底口径） ─────
    原表 = 目录.weather_definitions
    try:
        目录.weather_definitions = {}
        查(目录.weather_for_map(109_010_000, 期) == (0, ""),
           f"⑧ 没有原版天气表时应回 (0, \"\")（表没加载就摇雨 = 自造数据），实得 {目录.weather_for_map(109_010_000, 期)}")
    finally:
        目录.weather_definitions = 原表
    查(目录.weather_definitions is 原表, "⑧ 临时换掉的表必须还原（体检不许留脏 catalog）")
    for 图 in (100_000_000, 104_010_000, 400_000_900):
        类型, 公告 = 目录.weather_for_map(图, 期)
        查(0 <= 类型 <= 9, f"⑧ 图 {图} 摇出类型 {类型} 越界 0..9")
        if 类型 != 0:
            查(bool(公告.strip()),
               f"⑧ 图 {图} 摇出 {类型名[类型]} 却带不出公告文案 ⇒ 1570 之后那句「天气有变」会发空串")

    # ── ⑨ 会话那条腿：换图重发、换期才公告、GM 压过池 ─────────────────────────
    会话类 = 夹具.FakeFlashSession
    存 = {}
    统 = {}
    告 = []

    def _记属性包() -> None:
        统["属性"] = 统.get("属性", 0) + 1

    会话 = object.__new__(会话类)
    会话.entered_game = True
    会话.weather_period = -1
    会话.weather_type = -1
    ## `character` 是**只读属性**（`return self.store.state.character`，:11916）⇒ 直接赋值会
    ## `AttributeError: property 'character' has no setter`。造一条最浅的 store 链喂给它。
    角色 = type("C", (), {"map_id": 104_010_000})()
    会话.store = type("S", (), {"state": type("St", (), {"character": 角色})()})()
    会话.send_text = lambda 文: 存.update(包=文)
    会话._send_all_stats = _记属性包
    会话._send_dynamic_info = lambda 文: 告.append(文)
    假GM = _假GM()
    真GM = 夹具.GM_STATE
    真间隔 = 会话类.WEATHER_INTERVAL_SECONDS
    ## 把这条腿的钟**冻住**：`_refresh_weather` 里 `period = int(time.time()) // 间隔`，
    ## 四次调用只要跨过一次 300s 期界，`period_changed` 就替"换了张图"多弹一条公告 ⇒
    ## 红的是时钟脸，不是代码（2026-10-27 首跑就撞在边界上）。
    真现在 = time.time()
    假时钟 = type("T", (), {"time": staticmethod(lambda: 真现在),
                            "monotonic": staticmethod(time.monotonic)})()
    真time = 夹具.time
    try:
        夹具.GM_STATE = 假GM
        夹具.time = 假时钟
        当前期 = int(真现在) // 真间隔
        # 首登：摇一个、发一包、出一条公告（本期摇出结果 ⇒ 该告诉玩家）
        会话._refresh_weather(force=False)
        期望 = 目录.weather_for_map(104_010_000, 当前期)[0]
        查(存.get("包") == f"{夹具.op(夹具.ServerOpcode.CHANGE_WEATHER)}:{期望}",
           f"⑨ 首登应发本图池摇出的 {类型名[期望]}，实发 {存.get('包')}")
        查(len(告) == 1, f"⑨ 首登该出一条「天气有变」公告，实得 {len(告)} 条")
        # 原地再刷：没变 ⇒ 一个包都不发
        存.clear()
        会话._refresh_weather(force=False)
        查(not 存, f"⑨ 同池同期原地再刷不该重复发包，实发 {存.get('包')}")
        # 走进另一张池：类型变了要重发 1570，但**不该**弹公告（那是"换了张图"不是"天气变了"）
        换图期望 = 目录.weather_for_map(100_000_000, 当前期)[0]
        会话.character.map_id = 100_000_000
        ## 上一档留的类型**故意挑成本期这张池摇不出的那一个**：写死 6 的话，木叶本期正好摇出
        ## 大雪时 `weather_changed` 就是 False ⇒ 属性包那条整步没跑（变异「摘掉 _send_all_stats」
        ## 照样绿）。留 `if 换图期望 != 6` 那种"这步跳过"的写法同罪。
        前类型 = (换图期望 + 1) % 10
        会话.weather_type = 前类型
        存.clear()
        统.clear()
        ## ⚠ 公告必须在这儿清：`告` 里还躺着**首登**那条（上一句刚查过它恰有一条），
        ## 不清就直接 `查(not 告)` ⇒ 这条判据永远红在首登那条上（2026-10-27 首跑就是这么红的，
        ## 与换图弹不弹毫无关系）。
        告.clear()
        会话._refresh_weather(force=False)
        查(存.get("包") == f"{夹具.op(夹具.ServerOpcode.CHANGE_WEATHER)}:{换图期望}",
           f"⑨ 换图后应重发本图池摇出的 {类型名[换图期望]}，实发 {存.get('包')}")
        查(not 告, f"⑨ 换图不该弹「天气有变」公告，实弹 {告}")
        查(统.get("属性", 0) == 1,
           f"⑨ 换图把类型从 {类型名[前类型]} 改成 {类型名[换图期望]} ⇒ 属性包应恰好重发一次，实得 {统}")
        # 换期：同池再摇 ⇒ 该弹公告
        告.clear()
        会话.weather_period = 当前期 - 1
        会话.weather_type = 目录.weather_for_map(100_000_000, 当前期 - 1)[0]
        跨期 = 目录.weather_for_map(100_000_000, 当前期)
        会话._refresh_weather(force=False)
        ## 摇出晴时原版 `Buff.Weather` 那条 notice 本就是空串 ⇒ 「发没发公告」得跟着**文案**判，
        ## 写死 `>= 1` 会在木叶摇到晴的那一期假红（每 300s 换个脸的门不能这么脆）。
        查(bool(跨期[1].strip()) == (len(告) >= 1),
           f"⑨ 跨期重摇：本期摇出 {类型名[跨期[0]]}、文案{'有' if 跨期[1].strip() else '空'}，"
           f"公告实得 {len(告)} 条 ⇒ 公告链路和文案对不上（断了或是给晴硬发了一条空公告）")
        # GM 指定天气压过池（运营造场面不该被某张图的概率盖掉）
        ## 覆盖值挑成**本期这张池摇不出来的那一个**：写死 3 的话，池子本期恰好也摇出大雨时
        ## 「压过池」和「没压过池」发的包一模一样 ⇒ 变异（`if forced_weather is None:` 恒真）逃得干净。
        池值 = 目录.weather_for_map(100_000_000, 当前期)[0]
        假GM.覆盖 = (池值 + 5) % 10
        存.clear()
        会话.weather_type = 池值
        会话.weather_period = 当前期
        会话._refresh_weather(force=False)
        查(存.get("包") == f"{夹具.op(夹具.ServerOpcode.CHANGE_WEATHER)}:{假GM.覆盖}",
           f"⑨ GM 指定 {类型名[假GM.覆盖]} 应压过本池摇出的 {类型名[池值]}，实发 {存.get('包')}")
        # 没进游戏：一个包都不该发
        存.clear()
        会话.entered_game = False
        会话._refresh_weather(force=True)
        查(not 存, f"⑨ 没进游戏时不该发天气包，实发 {存.get('包')}")
    finally:
        夹具.GM_STATE = 真GM
        夹具.time = 真time
    查(夹具.time is 真time and 夹具.GM_STATE is 真GM, "⑨ 冻过的钟和 GM 必须还原（体检不许留脏夹具）")

    # ── ⑩ 源码钉：别再退回「全服一条」，也别把池号写成乘法撞流 ───────────────
    源 = inspect.getsource(会话类._refresh_weather)
    查("weather_for_map(" in 源 and "map_id" in 源,
       "⑩ `_refresh_weather` 必须按**当前图**查池（`weather_for_map(地图号, period)`），退回全局就是本次改需求白做")
    查("self.character.map_id" in 源,
       "⑩ 图号必须取自 `self.character.map_id`：写成常量 `DEFAULT_MAP_ID` 等于全服共用一张图的池"
       "（行为腿只在两图恰好摇出同一种天气时才不红，靠不住 ⇒ 这条钉源码）")
    查("weather_for_period" not in 源,
       "⑩ 全局摇法 `weather_for_period` 已从夹具摘掉 ⇒ 源码里再出现说明有人把它接回去了")
    目录源 = inspect.getsource(夹具.GameDataCatalog.weather_for_map)
    查('"%d:%d" %' in 目录源,
       "⑩ 池的种子必须是「池号:期号」字符串；写成两个整数相乘会让不同池撞成同一个随机流")
    查("weather_pool_key(map_id)" in 目录源,
       "⑩ 种子里必须真的带**池号**：`Random(0:期)` 这种写法所有池共用一条随机流，"
       "概率表再区分也只是各自在同一序列上取不同的档 ⇒ 行为腿照样能绿")

    print(f"汇：判 {判} 条 / 红 {len(红)} 条")
    for 条 in 红:
        print(f"!! {条}")
    sys.exit(1 if 红 else 0)


if __name__ == "__main__":
    主()
