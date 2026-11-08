#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""报修 2.2 的常驻门：寄坏昆虫**附加属性条数**必须随品质增加（2026-10-25，§3.278）。

为什么这是一条**服务端**门：条数不是客户端算的 —— 原版 `MToolTipZhuangBei.as:457`
是 `for each(plus in value.plusAttrList)` **逐行**渲染，行数 = 服务端发了几条。
客户端只认行数，所以"恒 6 条"这种毛病只能在夹具里修、也只能在夹具里验。

真值（两条，都不是本轮新发明的）：
  * 条数规则 = `equipment_plus_attribute_count()`：**白→3 / 绿→4 / 蓝→5 / 紫→6**
    （§3.94 照 Nya V2.6 参考真实存档定的，`min(6, 品质+2)`；色名 2026-10-27 纠正、见下）。
  * 候选行 = `KUN_CHONG_SIX_BASE_ATTRIBUTES`（六只虫各自的 authored 六行）。
    §3.95 已把昆虫接进同一条品质规则，但**两个写入点各自又把整表发了一遍**，
    于是 `11401`/`14678`（上线补档）与掉落/礼包/福袋/强化四条路**恒 6 条** —— 就是用户看到的毛病。
    用户报修 2.2 之后**登录补档只处理"缺行"** ⇒ 老档里整表时代写下的 6 行绿虫原样穿透
    （2026-10-27 用户再次报"绿色 6 条"）——本轮起**多于规则值裁到前缀**（⑦ 那条腿）。

⚠️ 品级常量照原版客户端 `CocoEquip.as`：品质 1..6（**数值**档位，橙5/神话6 封顶 6 条），
   但**颜色名**按显示表走：`EqpData.as:31` 的 `APTITUDE_COLORS` 里品级 2 = `#0dff19` **绿**、
   品级 3 = `0x009cbf` **蓝**（`EquipAptitudeUtil.as:74-77` 给品级 2 发的也是
   `EquipAptitudeGreenF`）⇒ 显示顺序是 **白 < 绿 < 蓝 < 紫**。§3.94 起文档写
   "白3/蓝4/绿5/紫6" 是把品质 2/3 的**颜色名**叫反了（照抄了 CocoEquip 的常量名）——
   2026-10-27 用户报修坐实（§3.301），**条数数值一档没变**，改的只是色名。

跑法（仓库根）：
    python -X utf8 开发工具/服务端昆虫条数体检.py
退出码：红 > 0 ⇒ 非 0。判决只看最后一行 `汇：判 N 条 / 红 M 条`。
"""
from __future__ import annotations

import inspect
import random
import sys
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


def 主() -> None:
    import 服务端目录

    夹具 = 服务端目录.加载()
    会话类 = getattr(夹具, "FakeFlashSession")
    六虫 = list(夹具.KUN_CHONG_ITEM_IDS)
    表 = 夹具.KUN_CHONG_SIX_BASE_ATTRIBUTES

    查(len(六虫) == 6 and all(i in 表 for i in 六虫),
       "authored 六行表应正好覆盖六只昆虫（一条都不能缺，缺了下面全假绿）")

    # ① 规则本身：白3 / 绿4 / 蓝5 / 紫6（色名照显示表，见文件头），橙与神话封顶 6。
    期望 = {0: 2, 1: 3, 2: 4, 3: 5, 4: 6, 5: 6, 6: 6}
    for 品, 该 in 期望.items():
        got = 夹具.equipment_plus_attribute_count(品, random.Random(0))
        查(got == 该, f"① 品质 {品} 的条数规则应 = {该}，实得 {got}")

    # ② 单调性 —— 用户报修的那句正面钉子。
    序列 = [夹具.equipment_plus_attribute_count(品, random.Random(0)) for 品 in (1, 2, 3, 4)]
    查(序列 == [3, 4, 5, 6], f"② 白→紫条数应严格递增 [3,4,5,6]，实得 {序列}")

    会话 = object.__new__(会话类)
    会话.random = random.Random(0)

    # ③ 六只虫 × 品质 1..4 走真实写入点 ⇒ 条数 = 规则值，且发的是 authored 表的**前 N 行**。
    for 虫 in 六虫:
        for 品 in (1, 2, 3, 4):
            件 = 夹具.InventoryItem(item_id=虫, slot=0, unique_id=0)
            会话._apply_kun_chong_profile(件, 品, 0)
            条数 = len(件.plus_attributes)
            该 = 夹具.equipment_plus_attribute_count(min(4, max(1, 品)) , random.Random(0))
            查(条数 == 该,
               f"③ 虫 {虫} 品质 {品} 应发 {该} 条，实发 {条数} 条（报修 2.2：条数必须随品质增加）")
            authored = [[int(a), int(v)] for a, v in 表[虫]]
            查(件.plus_attributes == authored[:条数],
               f"③ 虫 {虫} 品质 {品} 发的行应是 authored 表的前 {条数} 行（不许发明新数）")
            查(件.aptitude == min(4, max(1, 品)),
               f"③ 虫 {虫} 品质应夹在 1..4，实得 {件.aptitude}")

    # ④ 只动条数：基础属性 / 强化那一族字段与整表时**完全一致**（防"顺手改了值"）。
    件低 = 夹具.InventoryItem(item_id=六虫[0], slot=0, unique_id=0)
    件高 = 夹具.InventoryItem(item_id=六虫[0], slot=0, unique_id=0)
    会话._apply_kun_chong_profile(件低, 1, 5)
    会话._apply_kun_chong_profile(件高, 4, 5)
    for 名 in ("base_attr_type", "base_attr_value", "max_endure", "endure",
               "strength_level", "strength_value", "strength_info"):
        查(getattr(件低, 名) == getattr(件高, 名),
           f"④ 品质只该改条数；字段 {名} 白虫与紫虫应相等")
    查(len(件低.plus_attributes) < len(件高.plus_attributes),
       "④ 同一只虫：白虫条数应**严格少于**紫虫（这就是报修 2.2 要的现象）")

    # ⑤ 两个写入点都必须走规则函数，不许再直发整表（源码钉，防"改了一处漏一处"同族回归）。
    for 函数名 in ("_apply_kun_chong_profile", "_normalize_kun_chong_attributes"):
        源 = inspect.getsource(getattr(会话类, 函数名))
        查("equipment_plus_attribute_count" in 源,
           f"⑤ {函数名} 里必须引用 equipment_plus_attribute_count（条数走统一规则）")
        查("for attribute_type, value in profile]" not in 源
           and "for attribute_type, value in profile)" not in 源,
           f"⑤ {函数名} 不该再把 authored 整表直发（无切片的 in profile 就是恒 6 条的老写法）")
    # ⑤+ 登录补档那条路必须带**裁剪**分支（2026-10-27 用户再报绿虫 6 条：老档只补缺行、
    #     多余行穿透 ⇒ 病因）。行为由 ⑦ 坐，这里钉源码、防"把 elif 又删回 if not"。
    源n = inspect.getsource(会话类._normalize_kun_chong_attributes)
    查("item.plus_attributes[:count]" in 源n,
       "⑤ `_normalize_kun_chong_attributes` 必须把**多于规则值**的老档裁到前缀（报修：绿虫 6 条该 4 条）")

    # ⑥ 上线补档那条路（11396/14673）：存档里**缺**附加属性的老昆虫，补出来也要按品质。
    存档 = {}
    for 品 in (1, 2, 3, 4):
        件 = 夹具.InventoryItem(item_id=六虫[1], slot=0, unique_id=0)
        件.aptitude = 品
        件.plus_attributes = []
        存档[品] = 件

    class _假袋:
        def __init__(self, 值):
            self.values_dict = 值

        def values(self):
            return list(self.values_dict.values())

    class _假store:
        def __init__(self, 值):
            import threading
            self.lock = threading.Lock()
            self.state = type("S", (), {})()
            self.state.inventory = _假袋(值)
            self.state.storage = _假袋({})
            self.saved = False

        def save(self):
            self.saved = True

    会话.store = _假store(存档)
    会话._normalize_kun_chong_attributes()
    for 品 in (1, 2, 3, 4):
        条数 = len(存档[品].plus_attributes)
        查(条数 == 夹具.equipment_plus_attribute_count(品, random.Random(0)),
           f"⑥ 老档补档：品质 {品} 应补 {夹具.equipment_plus_attribute_count(品, random.Random(0))} 条，实补 {条数}")
    查(会话.store.saved is True, "⑥ 补了档必须落盘（store.save 要跑到）")

    # ⑦ **多于规则值的老档裁到前缀**（2026-10-27 用户报"绿色品质 6 条"的正主）：
    #    绿=品质2 该 4 条、紫=品质4 该 6 条不动、**低于规则值不补**（老随机档少随的
    #    行是玩家没 roll 出来的，补齐 = 发明属性）。
    存档7 = {}
    预置 = {2: 6, 4: 6, 3: 2}		# 品质 → 预置行数（都取 authored 前缀，与原档行序一致）
    for 品, 行 in 预置.items():
        件 = 夹具.InventoryItem(item_id=六虫[2], slot=0, unique_id=0)
        件.aptitude = 品
        件.plus_attributes = [[int(a), int(v)] for a, v in 表[六虫[2]][:行]]
        存档7[品] = 件
    会话.store = _假store(存档7)
    会话._normalize_kun_chong_attributes()
    查(len(存档7[2].plus_attributes) == 夹具.equipment_plus_attribute_count(2, random.Random(0)),
       f"⑦ 绿虫（品质2）6 行应裁到 {夹具.equipment_plus_attribute_count(2, random.Random(0))} 行，实得 {len(存档7[2].plus_attributes)}")
    查(len(存档7[4].plus_attributes) == 夹具.equipment_plus_attribute_count(4, random.Random(0)),
       "⑦ 紫虫（品质4）6 行 = 规则值，**不该被误裁**")
    查(len(存档7[3].plus_attributes) == 2,
       "⑦ 低于规则值的档**不补**（不许发明属性）")
    查(存档7[2].plus_attributes == 存档7[4].plus_attributes[:夹具.equipment_plus_attribute_count(2, random.Random(0))],
       "⑦ 裁剪保留**前缀**（authored 表行序，裁完与紫虫同表的前 4 行逐值相等）")
    查(会话.store.saved is True, "⑦ 裁了档必须落盘（store.save 要跑到）")

    print(f"汇：判 {判} 条 / 红 {len(红)} 条")
    for 条 in 红:
        print(f"!! {条}")
    sys.exit(1 if 红 else 0)


if __name__ == "__main__":
    主()
