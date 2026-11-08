#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""宠物等级上限的常驻门（2026-10-29，§3.314）。

用户规则三条：
  1. 宠物等级不能超过人物等级；
  2. 宠物面板里的宠物都收口到人物等级（老档里高于人物等级的那批压下来）；
  3. 宠物已经达到当前最高等级时，不再获取经验。

为什么这是一条**服务端**门：宠物升级只在 `_grant_pet_experience` 里发生
（客户端没有一行加经验/升级的代码），面板上的等级/经验条读的就是服务端发来的字段。
所以"宠物涨到 120 级、经验还在涨"只能在夹具里修、也只能在夹具里验。

真值口径（本轮定，见编年史 §3.314）：
  * 上限 = `min(120, 人物等级)`，最低 1（人物等级 0 这种脏档兜到 1）；
  * 到上限的宠物：`_grant_pet_experience` **一点经验都不加**（不是加了再清零 ——
    老档残留的经验在第一次"本该获得经验"时清一次）；
  * 上线/请求宠物列表（`_send_pet_list`）时把高于人物等级的宠物**压到人物等级**并清经验。

跑法（仓库根）：
    python -X utf8 开发工具/服务端宠物等级体检.py
退出码：红 > 0 ⇒ 非 0。判决只看最后一行 `汇：判 N 条 / 红 M 条`。
"""
from __future__ import annotations

import inspect
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
    PetState = 夹具.PetState
    CharacterState = 夹具.CharacterState
    ServerOpcode = 夹具.ServerOpcode
    PetResponseAction = 夹具.PetResponseAction
    级包 = 夹具.op(ServerOpcode.PET_ACTION)
    动作 = 夹具.op(PetResponseAction.LEVEL_UP)
    更新 = 夹具.op(PetResponseAction.UPDATE)
    初始 = 夹具.op(PetResponseAction.INITIAL_LIST)

    class _假袋:
        def __init__(self, 值):
            self.值 = 值

        def values(self):
            return list(self.值.values())

    class _假state:
        pass

    class _假store:
        def __init__(self, 人物等级: int, 宠物: dict[int, object], 容量: int = 10):
            self.state = _假state()
            self.state.character = CharacterState(level=人物等级)
            self.state.pets = 宠物
            self.state.pet_capacity = 容量
            self.saved = 0

        def save(self):
            self.saved += 1

    def 造会话(人物等级: int, 宠物: dict[int, object], 容量: int = 10) -> tuple[object, list[str], _假store]:
        会话 = object.__new__(会话类)
        会话.store = _假store(人物等级, 宠物, 容量)
        发 = []
        会话.send_text = lambda 文: 发.append(文)
        # 这几条编码/自动学技能不在本轮改动面上：给按调用方接口造的最小替身
        #（§3.278 腿⑥ 的教训：替身缺方法 = 整条腿不跑）。
        会话._encode_pet_update = lambda pet: f"U{pet.level}/{pet.experience}"
        会话._encode_pet = lambda pet: f"L{pet.level}E{pet.experience}"
        会话._auto_learn_pet_skills = lambda pet: []
        会话._send_pet_skill_list = lambda pet: None
        会话._schedule_combat_save = lambda: None
        return 会话, 发, 会话.store

    # ① 上限规则：min(120, 人物等级)，最低 1。
    期望 = {1: 1, 2: 2, 50: 50, 119: 119, 120: 120, 121: 120, 200: 120, 0: 1}
    for 人物级, 该 in 期望.items():
        会话, _, _ = 造会话(人物级, {})
        got = 会话._pet_level_cap()
        查(got == 该, f"① 人物 {人物级} 级 ⇒ 宠物上限应 = {该}，实得 {got}")

    # ② 已达上限：一点经验都不加（连经验字段都不许动），一个包都不发。
    会话, 发, store = 造会话(50, {})
    宠 = PetState(unique_id=1, level=50, experience=0)
    会话._grant_pet_experience(宠, 99999)
    查(宠.level == 50 and 宠.experience == 0,
       f"② 满级（50/50）再加 99999 经验：应仍是 50 级 0 经验，实得 {宠.level} 级 {宠.experience} 经验")
    查(发 == [], f"② 满级没变化时不该发任何包（实发 {发}）")
    查(store.saved == 0, f"② 满级没变化时不该落盘（实落 {store.saved} 次）")

    # ③ 满级老档残留经验：清一次并落盘 + 发 UPDATE，但不发 LEVEL_UP。
    会话, 发, store = 造会话(120, {})
    宠 = PetState(unique_id=1, level=120, experience=38381)
    会话._grant_pet_experience(宠, 100)
    查(宠.level == 120 and 宠.experience == 0,
       f"③ 120 级宠物带着 38381 残留经验：应清成 0，实得 {宠.experience}")
    查(store.saved == 1, f"③ 清了经验必须落盘（实落 {store.saved} 次）")
    查(len(发) == 1 and f"{级包}:{更新}:" in 发[0] and f":{动作}:" not in 发[0],
       f"③ 清经验只发 UPDATE、不发 LEVEL_UP（实发 {发}）")

    # ④ 未满级：照旧 `level*100` 升级；**正好升到上限就停**，多出来的经验不跨上限累计。
    会话, 发, store = 造会话(50, {})
    宠 = PetState(unique_id=1, level=10, experience=0)
    会话._grant_pet_experience(宠, 1000)   # 10 级需要 1000
    查(宠.level == 11 and 宠.experience == 0,
       f"④ 10 级给 1000 经验应升到 11 级 0 经验，实得 {宠.level} 级 {宠.experience} 经验")
    查(any(f":{动作}:" in 文 for 文 in 发), f"④ 升级必须发 LEVEL_UP（实发 {发}）")
    会话, 发, store = 造会话(50, {})
    宠 = PetState(unique_id=1, level=49, experience=0)
    会话._grant_pet_experience(宠, 999999)  # 够升好几级，但只能到 50
    查(宠.level == 50 and 宠.experience == 0,
       f"④ 49 级给巨量经验：应停在人物等级 50 且经验 0，实得 {宠.level} 级 {宠.experience} 经验")
    升级包 = [文 for 文 in 发 if f":{动作}:" in 文]
    查(len(升级包) == 1,
       f"④ 一次收口只发一条 LEVEL_UP，实发 {len(升级包)} 条（{发}）")

    # ⑤ 上线收口：高于人物等级的压到人物等级并清经验；低于上限的原样（不许顺手抬）。
    会话, 发, store = 造会话(50, {})
    高 = PetState(unique_id=1, level=120, experience=38381)
    低 = PetState(unique_id=2, level=30, experience=5)
    会话.store.state.pets = {1: 高, 2: 低}
    会话._normalize_pet_levels()
    查(高.level == 50 and 高.experience == 0,
       f"⑤ 120 级宠物在 50 级人物下应收口到 50/0，实得 {高.level}/{高.experience}")
    查(低.level == 30 and 低.experience == 5,
       f"⑤ 低于上限的宠物不许动，实得 {低.level}/{低.experience}")
    查(store.saved >= 1, "⑤ 收口了老档必须落盘（store.save 要跑到）")
    会话, 发, store = 造会话(50, {})
    无变化 = PetState(unique_id=1, level=40, experience=9)
    会话.store.state.pets = {1: 无变化}
    会话._normalize_pet_levels()
    查(store.saved == 0, f"⑤ 没有越级宠物时不该写盘（实落 {store.saved} 次）")

    # ⑥ 真走 `_send_pet_list`：列表包里带出去的必须是收口后的等级/经验（不是只改内存）。
    会话, 发, store = 造会话(50, {}, 容量=4)
    会话.store.state.pets = {
        1: PetState(unique_id=1, level=120, experience=38381),
        2: PetState(unique_id=2, level=30, experience=5),
    }
    会话._send_pet_list()
    查(len(发) == 1 and f"{级包}:{初始}:4:" in 发[0],
       f"⑥ 宠物列表包形状应是 {级包}:{初始}:容量:…，实发 {发}")
    查("L50E0@L30E5" in 发[0],
       f"⑥ 列表包必须带收口后的 L50E0 与未动的 L30E5，实发 {发}")

    # ⑥+ 源码钉：两处写入点都走统一规则（防"改了一处漏一处"）。
    源升 = inspect.getsource(会话类._grant_pet_experience)
    查("_pet_level_cap" in 源升 and "pet.level < cap" in 源升,
       "⑥+ _grant_pet_experience 必须用 _pet_level_cap 当循环上限（不许再写死 120）")
    查("pet.experience = 0" in 源升, "⑥+ 满级/触顶必须把经验清零")
    源列 = inspect.getsource(会话类._send_pet_list)
    查("_normalize_pet_levels" in 源列,
       "⑥+ _send_pet_list 必须调 _normalize_pet_levels（上线/请求列表都要收口）")

    print(f"汇：判 {判} 条 / 红 {len(红)} 条")
    for 条 in 红:
        print(f"!! {条}")
    sys.exit(1 if 红 else 0)


if __name__ == "__main__":
    主()
