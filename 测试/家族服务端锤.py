# -*- coding: utf-8 -*-
"""家族入族审批 / 成员管理服务端门（2026-11-08，B）——进程内锤。

客户端两扇门（`家族成员管理回归测试.gd`／`家族入族审批与成员动作回归测试.gd`）钉的是
「帧怎么解、钮怎么发包」；本锤钉**服务端收到那几发之后到底做了什么**，纯进程内驱动
`fake_flash_server.FakeFlashSession.handle_banghui`（socket/hub 全假，不连夹具）：

  A  action 2 + `autoAccept=false` ⇒ 族长在线收 `1552:8:名:角色号:脸:等级`；
     族长 `_send_family_info` 会把**还没处理**的申请重推一遍（离线时也不丢）。
  B  action 14 批准 ⇒ 申请人进族、收 `1552:15`（第 8 字段 = 自动同意 0），
     全族在线收 `1552:7:<申请人号>`。
  C  action 13 拒绝 ⇒ 申请人收 `1552:9:<族长名>`，且**不进族**。
  D  action 19 邀请 / action 4 开除的 manager 闸：副族长（rank 2）能过，普通族员不能。
  E  action 17 职务：只认 2/3/4/5/9999，表外的 7 落成 9999；全族收 `1552:7:<目标号>`。
  F  action 18 禅让：族长换人、老族长回 9999、新族长 1；`1552:15` 第 7 字段 = 新族长角色号。
  G  action 20 自动同意：摘要第 8 字段翻转；打开时**把挂着的申请全部自动批准**。
  H  action 22 弹劾：无弹劾令只提示；有弹劾令消耗 15019001、本人当族长、全族收 `1552:7`。
  I  action 105 成员详细行 = 17 字段，在线 line_id、离线 -1，缺职务按 9999。

用法（被 `测试/家族成员管理服务端回归测试.gd` 调，也可手跑）：
    python 测试/家族服务端锤.py
退出码：0 = 全绿；1 = 有断言不符。
"""
from __future__ import annotations

import random
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "服务端" / "runtime" / "tools"))

import fake_flash_server as ffs  # noqa: E402

码家族 = 1552
弹劾令 = 15_019_001

失败: list[str] = []


def 查(条件: bool, 说明: str) -> None:
    if not 条件:
        失败.append(说明)


def _帧里(帧: list[str], 前缀: str) -> list[str]:
    return [值 for 值 in 帧 if 值.startswith(前缀)]


def _建会话(
    根: Path,
    accounts: ffs.AccountService,
    hub: ffs.MultiplayerHub,
    账号: dict,
    角色: dict,
    *,
    在线: bool,
) -> ffs.FakeFlashSession:
    会话 = ffs.FakeFlashSession.__new__(ffs.FakeFlashSession)
    会话.store = ffs.SinglePlayerStore(accounts.character_path(角色))
    会话.store.state.character.character_id = int(角色["id"])
    会话.store.state.character.name = str(角色["name"])
    会话.store.save()
    会话.accounts = accounts
    会话.hub = hub
    会话.account_id = int(账号["id"])
    会话.random = random.Random(20261108)
    会话.wire_mode = "text"
    会话.line_id = 1
    会话.发出的帧 = []
    会话.send_text = lambda payload, _我=会话: _我.发出的帧.append(str(payload))
    # 这些分支碰的是旗子/背包/统计的旁路，与家族行无关；桩掉只留我们要比的那几帧。
    for 名 in (
        "_send_family_flag_identity",
        "_send_family_flag_clear",
        "_send_all_stats",
        "_send_stats",
        "_send_inventory_clear",
        "_send_inventory_update",
        "_send_visible",
    ):
        setattr(会话, 名, lambda *a, **k: None)
    if 在线:
        hub.sessions_by_character[int(角色["id"])] = 会话
        hub.sessions_by_account[int(账号["id"])] = 会话
    return 会话


def _发(会话: ffs.FakeFlashSession, 载荷: str) -> None:
    会话.发出的帧.clear()
    会话.handle_banghui(f"{码家族}:{载荷}")


def _场(根: Path):
    accounts = ffs.AccountService(
        path=根 / "accounts.json",
        character_root=根 / "characters",
        legacy_save_path=根 / "legacy.json",
    )
    hub = ffs.MultiplayerHub(accounts)
    甲 = accounts.register("leader01", "secret1")
    乙 = accounts.register("deputy01", "secret1")
    丙 = accounts.register("member01", "secret1")
    丁 = accounts.register("apply01", "secret1")
    甲角 = accounts.create_character(accounts.account_by_id(甲["id"]), "族长甲")
    乙角 = accounts.create_character(accounts.account_by_id(乙["id"]), "副族长")
    丙角 = accounts.create_character(accounts.account_by_id(丙["id"]), "族员丙")
    丁角 = accounts.create_character(accounts.account_by_id(丁["id"]), "申请人丁")
    甲会 = _建会话(根, accounts, hub, accounts.account_by_id(甲["id"]), 甲角, 在线=True)
    乙会 = _建会话(根, accounts, hub, accounts.account_by_id(乙["id"]), 乙角, 在线=True)
    丙会 = _建会话(根, accounts, hub, accounts.account_by_id(丙["id"]), 丙角, 在线=True)
    丁会 = _建会话(根, accounts, hub, accounts.account_by_id(丁["id"]), 丁角, 在线=False)
    # 建族要 1000 金币；给够，免得先被钱挡住。
    甲会.store.state.money = 100_000
    甲会.store.save()
    _发(甲会, "1:1000:暗部:木叶:欢迎回家:0")
    查(
        any(帧 == f"{码家族}:2:1:1" for 帧 in 甲会.发出的帧),
        f"A 建族回包 = 1552:2:1:1（实得 {甲会.发出的帧}）",
    )
    族 = accounts.family_by_id(1)
    查(族 is not None, "A 家族落库")
    return accounts, hub, (甲, 甲角, 甲会), (乙, 乙角, 乙会), (丙, 丙角, 丙会), (丁, 丁角, 丁会), 族


def 跑() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        根 = Path(tmp)
        accounts, hub, 甲三, 乙三, 丙三, 丁三, 族 = _场(根)
        (甲, 甲角, 甲会) = 甲三
        (乙, 乙角, 乙会) = 乙三
        (丙, 丙角, 丙会) = 丙三
        (丁, 丁角, 丁会) = 丁三
        assert 族 is not None
        族号 = int(族["id"])
        # 副族长 rank 2、族员 rank 9999（直接落库；action 17 的路径另测）。
        accounts.join_family(int(乙["id"]), 族号)
        accounts.join_family(int(丙["id"]), 族号)
        accounts.update_family(
            族号, ranks={str(甲["id"]): 1, str(乙["id"]): 2, str(丙["id"]): 9999}
        )

        # ── A 申请：自动同意关掉 ⇒ 族长收 1552:8，摘要时还会重推 ─────────────
        accounts.update_family(族号, autoAccept=False)
        # 固定等级：即时推送读会话存档、重推读账号摘要，两边都钉到 33。
        丁会.store.state.character.level = 33
        丁会.store.save()
        accounts.update_character_summary(int(丁角["id"]), level=33)
        # 即时推送的脸 = 裸体脸（job 300 ⇒ 男身 1），不是摘要里的 face 字段。
        即时帧 = f"{码家族}:8:申请人丁:{丁角['id']}:1:33"
        _发(丁会, f"2:{族号}")
        查(
            即时帧 in 甲会.发出的帧,
            f"A 申请帧推给族长（期望 {即时帧}，实得 {甲会.发出的帧}）",
        )
        查(
            int(accounts.account_by_id(丁["id"]).get("familyId", 0)) == 0,
            "A 自动同意关 ⇒ 申请人不进族",
        )
        甲会.发出的帧.clear()
        甲会._send_family_info()
        重推 = _帧里(甲会.发出的帧, f"{码家族}:8:申请人丁:{丁角['id']}:")
        查(
            重推 and 重推[-1].endswith(":33"),
            f"A 族长重登重推挂起申请（实得 {甲会.发出的帧}）",
        )

        # ── B 批准：1552:14 ⇒ 进族 + 摘要 8 字段 + 全族 1552:7 ───────────────
        hub.sessions_by_character[int(丁角["id"])] = 丁会
        hub.sessions_by_account[int(丁["id"])] = 丁会
        丁会.发出的帧.clear()
        乙会.发出的帧.clear()
        甲会.发出的帧.clear()
        _发(甲会, f"14:{丁角['id']}")
        查(
            int(accounts.account_by_id(丁["id"]).get("familyId", 0)) == 族号,
            "B action 14 批准后申请人进族",
        )
        摘要 = _帧里(丁会.发出的帧, f"{码家族}:15:")
        查(摘要 and 摘要[-1].endswith(":0"), f"B 批准后摘要第 8 字段 = 0（实得 {摘要}）")
        查(
            f"{码家族}:7:{丁角['id']}" in 乙会.发出的帧,
            f"B 批准后全族收 1552:7（实得 {乙会.发出的帧}）",
        )

        # ── C 拒绝：1552:13 ⇒ 申请人收 1552:9、不进族 ────────────────────────
        戊 = accounts.register("apply02", "secret1")
        戊角 = accounts.create_character(accounts.account_by_id(戊["id"]), "申请人戊")
        戊会 = _建会话(根, accounts, hub, accounts.account_by_id(戊["id"]), 戊角, 在线=True)
        _发(戊会, f"2:{族号}")
        甲会.发出的帧.clear()
        _发(甲会, f"13:{戊角['id']}")
        查(
            f"{码家族}:9:族长甲" in 戊会.发出的帧,
            f"C 拒绝回 1552:9:<族长名>（实得 {戊会.发出的帧}）",
        )
        查(
            int(accounts.account_by_id(戊["id"]).get("familyId", 0)) == 0,
            "C 拒绝后申请人仍在族外",
        )

        # ── D manager 闸：邀请 19 / 开除 4 = 族长或副族长 ────────────────────
        己 = accounts.register("outsider", "secret1")
        己角 = accounts.create_character(accounts.account_by_id(己["id"]), "路人己")
        己会 = _建会话(根, accounts, hub, accounts.account_by_id(己["id"]), 己角, 在线=True)
        己会.发出的帧.clear()
        _发(丙会, f"19:{己角['id']}")
        查(
            not _帧里(己会.发出的帧, f"{码家族}:16:"),
            f"D 普通族员邀请被拒（实得 {己会.发出的帧}）",
        )
        己会.发出的帧.clear()
        _发(乙会, f"19:{己角['id']}")
        查(
            _帧里(己会.发出的帧, f"{码家族}:16:"),
            f"D 副族长可以邀请（实得 {己会.发出的帧}）",
        )
        丙会.发出的帧.clear()
        _发(丙会, f"4:{乙角['id']}")
        查(
            not _帧里(丙会.发出的帧, f"{码家族}:12:"),
            f"D 普通族员开除被拒（实得 {丙会.发出的帧}）",
        )
        _发(乙会, f"4:{丙角['id']}")
        查(
            int(accounts.account_by_id(丙["id"]).get("familyId", 0)) == 0,
            "D 副族长开除生效",
        )

        # ── E 职务：表外值落 9999 + 1552:7 广播 ──────────────────────────────
        丁会.发出的帧.clear()
        _发(甲会, f"17:{乙角['id']}:7")
        族 = accounts.family_by_id(族号) or {}
        查(
            int(dict(族.get("ranks", {})).get(str(乙["id"]), 0)) == 9999,
            f"E 表外职务 7 落 9999（实得 {dict(族.get('ranks', {}))}）",
        )
        查(
            f"{码家族}:7:{乙角['id']}" in 丁会.发出的帧,
            f"E 改职务全族收 1552:7（实得 {丁会.发出的帧}）",
        )
        甲会.发出的帧.clear()
        _发(甲会, f"17:{乙角['id']}:3")
        族 = accounts.family_by_id(族号) or {}
        查(
            int(dict(族.get("ranks", {})).get(str(乙["id"]), 0)) == 3,
            "E 表内职务 3 保留（长老）",
        )

        # ── F 禅让：18 ⇒ 换族长 + 摘要第 7 字段 + 1552:7 ─────────────────────
        甲会.发出的帧.clear()
        乙会.发出的帧.clear()
        _发(甲会, f"18:{乙角['id']}")
        族 = accounts.family_by_id(族号) or {}
        查(int(族.get("leaderAccountId", 0)) == int(乙["id"]), "F 禅让后族长换成乙")
        职务表 = dict(族.get("ranks", {}))
        查(int(职务表.get(str(甲["id"]), 0)) == 9999, "F 老族长回 9999")
        查(int(职务表.get(str(乙["id"]), 0)) == 1, "F 新族长 1")
        摘要 = _帧里(乙会.发出的帧, f"{码家族}:15:")
        查(
            摘要 and 摘要[-1].split(":")[6] == str(乙角["id"]),
            f"F 摘要第 7 字段 = 新族长角色号（实得 {摘要}）",
        )
        查(
            f"{码家族}:7:0" in 甲会.发出的帧 or f"{码家族}:7:0" in 乙会.发出的帧,
            "F 禅让广播 1552:7:0",
        )

        # ── G 自动同意：20 ⇒ 摘要第 8 字段翻转 + 挂着的一律批准 ──────────────
        辛 = accounts.register("apply03", "secret1")
        辛角 = accounts.create_character(accounts.account_by_id(辛["id"]), "申请人辛")
        辛会 = _建会话(根, accounts, hub, accounts.account_by_id(辛["id"]), 辛角, 在线=False)
        _发(辛会, f"2:{族号}")
        查(int(accounts.account_by_id(辛["id"]).get("familyId", 0)) == 0, "G 申请挂起")
        乙会.发出的帧.clear()
        _发(乙会, "20:1")
        族 = accounts.family_by_id(族号) or {}
        查(bool(族.get("autoAccept", False)), "G 自动同意已打开")
        查(
            int(accounts.account_by_id(辛["id"]).get("familyId", 0)) == 族号,
            "G 打开自动同意后挂起申请被批准",
        )
        摘要 = _帧里(乙会.发出的帧, f"{码家族}:15:")
        查(摘要 and 摘要[-1].endswith(":1"), f"G 摘要第 8 字段 = 1（实得 {摘要}）")

        # ── H 弹劾：22 ⇒ 无令提示；有令消耗 + 本人当族长 ─────────────────────
        甲会.发出的帧.clear()
        _发(甲会, "22")
        查(
            any("弹劾令" in 帧 for 帧 in 甲会.发出的帧),
            f"H 无弹劾令只提示（实得 {甲会.发出的帧}）",
        )
        查(
            int((accounts.family_by_id(族号) or {}).get("leaderAccountId", 0))
            == int(乙["id"]),
            "H 无令时族长不变",
        )
        甲会.store.state.inventory[1] = ffs.InventoryItem(
            item_id=弹劾令,
            slot=1,
            quantity=1,
        )
        甲会.store.save()
        乙会.发出的帧.clear()
        _发(甲会, "22")
        族 = accounts.family_by_id(族号) or {}
        查(int(族.get("leaderAccountId", 0)) == int(甲["id"]), "H 弹劾后甲当族长")
        查(
            1 not in 甲会.store.state.inventory,
            "H 弹劾令被消耗（quantity=1 ⇒ 整摞消失）",
        )
        查(
            f"{码家族}:7:{甲角['id']}" in 乙会.发出的帧,
            f"H 弹劾广播 1552:7（实得 {乙会.发出的帧}）",
        )

        # ── I 105 详细行：17 字段 / line_id / rank 兜底 ─────────────────────
        甲会.发出的帧.clear()
        _发(甲会, "105:0")
        行帧 = _帧里(甲会.发出的帧, f"{码家族}:6:")
        查(行帧, f"I 成员详细行有回帧（实得 {甲会.发出的帧}）")
        行们 = {}
        if 行帧:
            # 帧形如 `1552:6:<行1>@<行2>…`，行内用 `&` 分字段。
            for 条 in 行帧[-1].split(":", 2)[2].split("@"):
                件 = 条.split("&")
                查(len(件) == 17, f"I 成员行 17 字段（实得 {len(件)}：{条}）")
                行们[int(件[0])] = 件
        离线行 = 行们.get(int(辛角["id"]))
        在线行 = 行们.get(int(乙角["id"]))
        查(离线行 is not None and 离线行[10] == "-1", f"I 离线成员 line_id = -1（实得 {离线行}）")
        查(在线行 is not None and 在线行[10] == "1", f"I 在线成员 line_id = 1（实得 {在线行}）")
        查(
            离线行 is not None and 离线行[3] == "9999",
            f"I 没职务记录的成员按 9999（实得 {离线行}）",
        )


def main() -> int:
    跑()
    if 失败:
        for 条 in 失败:
            print("  !! " + 条)
        print(f"家族服务端锤：FAIL {len(失败)} 条")
        return 1
    print("家族服务端锤：通过（申请/批准/拒绝/manager闸/职务/禅让/自动同意/弹劾/105行）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
