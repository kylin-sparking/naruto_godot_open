# -*- coding: utf-8 -*-
"""好友列表/私聊/打探/仇人/最近 服务端门（2026-11-08，A2）——进程内锤。

客户端那扇 `好友交互回归测试.gd` 钉的是「窗怎么拼串、回包怎么落到控件」；
本锤钉**服务端收到 127 那几发之后到底做了什么**，纯进程内驱动
`fake_flash_server.FakeFlashSession.handle_friendlist`（socket/hub 全假，不连夹具）：

  A  `127:2` 回包的**五列位次**：好友 / 仇人 / 黑名单 / 最近 / 申请
     （以前服务端把好友行重复塞进黑名单与最近两列，客户端只能靠猜位次）。
  B  好友行 11 段：`id&degree&face&gender&job&level&name&is_couple&friendly&now&line`，
     在线 line_id、离线 -1；羁绊按 `spouseAccountId` 出 1。
  C  `127:8` 私聊：在线对面收 `61:7:<发方号>:<正文>:<发方名>`（段内冒号转全角）；
     离线落离线信箱；被拉黑整条不发；双方「最近联系人」都记。
  D  `127:10` 打探：离线 `61:8:2`；没乾坤密卷 `61:8:1`（不消耗）；
     有则 `61:8:0:<线>:<图>:<x>:<y>` 且扣 1（round 取整），目标号 0 不发。
  E  `127:9` 删仇人 / `127:7` 删最近：各回 `61:4:<号>:ENEMY|RECENT`，
     只清对应那一列，**好友列不动**（7/9 不能当 3 用）。
  F  PvP 被杀：被害方把凶手记进仇人，双方互相记最近。

用法（被 `测试/好友服务端回归测试.gd` 调，也可手跑）：
    python 测试/好友服务端锤.py
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

码好友 = 127
码回 = 61
密卷 = 16_000_005

失败: list[str] = []


def 查(条件: bool, 说明: str) -> None:
    if not 条件:
        失败.append(说明)


def _帧里(帧: list[str], 前缀: str) -> list[str]:
    return [值 for 值 in 帧 if 值.startswith(前缀)]


def _建会话(
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
    会话.store.state.character.job = int(角色.get("job", 300))
    会话.store.state.character.face = int(角色.get("face", 300))
    会话.store.state.character.gender = int(角色.get("gender", 0))
    会话.store.state.character.level = int(角色.get("level", 1))
    会话.store.save()
    会话.accounts = accounts
    会话.hub = hub
    会话.account_id = int(账号["id"])
    会话.random = random.Random(20261108)
    会话.wire_mode = "text"
    会话.line_id = 1
    会话.x = 会话.character.x
    会话.y = 会话.character.y
    会话.map_id = 会话.character.map_id
    会话.发出的帧 = []
    会话.send_text = lambda payload, _我=会话: _我.发出的帧.append(str(payload))
    # 背包变化另有门，这里只关心 61:8 与 61:2 两条；桩掉免得帧里混。
    for 名 in ("_send_inventory_clear", "_send_inventory_update", "_send_visible"):
        setattr(会话, 名, lambda *a, **k: None)
    if 在线:
        hub.sessions_by_character[int(角色["id"])] = 会话
        hub.sessions_by_account[int(账号["id"])] = 会话
    return 会话


def _发(会话: ffs.FakeFlashSession, 载荷: str) -> None:
    会话.发出的帧.clear()
    会话.handle_friendlist(f"{码好友}:{载荷}")


def _列(会话: ffs.FakeFlashSession, 位: int) -> str:
    """取 `61:2:` 回包的第 位 列（0=好友 1=仇人 2=黑名单 3=最近 4=申请）。"""
    帧 = _帧里(会话.发出的帧, f"{码回}:2:")
    查(len(帧) == 1, f"应恰好一发 61:2（实得 {帧}）")
    if not 帧:
        return ""
    段 = 帧[-1].split(":")
    脚本 = 段[2 + 位] if len(段) > 2 + 位 else "<缺列>"
    return 脚本


def _行号(列: str) -> list[int]:
    if 列 in ("", "-"):
        return []
    return [int(值.split("&")[0]) for 值 in 列.split("@") if 值]


def _场(根: Path):
    accounts = ffs.AccountService(
        path=根 / "accounts.json",
        character_root=根 / "characters",
        legacy_save_path=根 / "legacy.json",
    )
    hub = ffs.MultiplayerHub(accounts)
    甲号 = accounts.register("friend01", "secret1")
    乙号 = accounts.register("friend02", "secret1")
    丙号 = accounts.register("friend03", "secret1")
    甲角 = accounts.create_character(accounts.account_by_id(甲号["id"]), "甲忍", job=300)
    乙角 = accounts.create_character(accounts.account_by_id(乙号["id"]), "乙忍", job=200)
    丙角 = accounts.create_character(accounts.account_by_id(丙号["id"]), "丙忍", job=100)
    accounts.update_character_summary(int(乙角["id"]), level=33, face=105)
    accounts.update_character_summary(int(丙角["id"]), level=27, face=103)
    甲会 = _建会话(accounts, hub, accounts.account_by_id(甲号["id"]), 甲角, 在线=True)
    乙会 = _建会话(accounts, hub, accounts.account_by_id(乙号["id"]), 乙角, 在线=True)
    丙会 = _建会话(accounts, hub, accounts.account_by_id(丙号["id"]), 丙角, 在线=False)
    return accounts, hub, (甲号, 甲角, 甲会), (乙号, 乙角, 乙会), (丙号, 丙角, 丙会)


def _甲组(组):
    return int(组[0]["id"]), int(组[1]["id"])


def 跑() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        根 = Path(tmp)
        accounts, hub, 甲三, 乙三, 丙三 = _场(根)
        甲号, 甲角, 甲会 = 甲三
        乙号, 乙角, 乙会 = 乙三
        丙号, 丙角, 丙会 = 丙三
        甲账号, 甲角色 = _甲组(甲三)
        乙账号, 乙角色 = _甲组(乙三)
        丙账号, 丙角色 = _甲组(丙三)

        # ── A 五列位次 + B 行编码 ──────────────────────────────────────────
        _发(甲会, "0")
        查(
            _帧里(甲会.发出的帧, f"{码回}:2:") == [f"{码回}:2:-:-:-:-:-"],
            f"A 空列表五列都是 -（实得 {甲会.发出的帧}）",
        )
        accounts.set_friend(甲账号, 乙账号, True)
        accounts.set_friend(乙账号, 甲账号, True)
        # 申请要在拉黑之前：request_friend 会拒"申请人已在目标黑名单里"的那种。
        accounts.request_friend(丙账号, 甲账号)
        accounts.set_blocked(甲账号, 丙账号, True)
        accounts.set_recent_contact(甲账号, 乙账号)
        # 羁绊：甲的对戒对象 = 乙。行第 8 段（is_couple）应为 1。
        with accounts.lock:
            账号 = accounts.account_by_id(甲账号)
            账号["spouseAccountId"] = 乙账号
            accounts._save_locked()
        _发(甲会, "0")
        查(_行号(_列(甲会, 0)) == [乙角色], f"A 好友列 = 乙（实得 {_列(甲会, 0)}）")
        查(_列(甲会, 1) == "-", f"A 仇人列仍空（实得 {_列(甲会, 1)}）")
        查(_行号(_列(甲会, 2)) == [丙角色], f"A 黑名单列 = 丙（实得 {_列(甲会, 2)}）")
        查(_行号(_列(甲会, 3)) == [乙角色], f"A 最近列 = 乙（实得 {_列(甲会, 3)}）")
        查(_行号(_列(甲会, 4)) == [丙角色], f"A 申请列 = 丙（实得 {_列(甲会, 4)}）")
        友行 = _列(甲会, 0).split("&")
        查(len(友行) == 11, f"B 好友行应是 11 段（实得 {len(友行)}：{_列(甲会, 0)}）")
        if len(友行) == 11:
            查(
                友行[:7] == [str(乙角色), "0", "105", "1", "200", "33", "乙忍"],
                "B 行前 7 段 = id/degree/face/gender/job/level/name"
                f"（实得 {友行[:7]}）",
            )
            查(友行[7] == "1", f"B 羁绊位（spouseAccountId）应为 1（实得 {友行[7]}）")
            查(友行[8] == "100", f"B 亲密度默认 100（实得 {友行[8]}）")
            查(友行[10] == "1", f"B 在线行 line_id=1（实得 {友行[10]}）")
        accounts.update_character_summary(int(乙角["id"]), level=33)
        # 乙离线：把乙从 hub 摘掉，行尾应变 -1。
        hub.sessions_by_character.pop(乙角色, None)
        hub.sessions_by_account.pop(乙账号, None)
        _发(甲会, "0")
        离线行 = _列(甲会, 0).split("&")
        查(len(离线行) == 11 and 离线行[10] == "-1",
            f"B 离线行 line_id=-1（实得 {_列(甲会, 0)}）")
        hub.sessions_by_character[乙角色] = 乙会
        hub.sessions_by_account[乙账号] = 乙会

        # ── C 私聊 + 最近联系人 ──────────────────────────────────────────
        乙会.发出的帧.clear()
        _发(甲会, f"8:{乙角色}:你好:世界")
        查(
            _帧里(乙会.发出的帧, f"{码回}:7:") ==
            [f"{码回}:7:{甲角色}:你好：世界:甲忍"],
            f"C 在线私聊到乙（期望段内冒号转全角，实得 {乙会.发出的帧}）",
        )
        甲账 = accounts.account_by_id(甲账号)
        乙账 = accounts.account_by_id(乙账号)
        查(
            int(甲账.get("recentContacts", [0])[0]) == 乙账号,
            f"C 发方最近联系人置顶乙（实得 {甲账.get('recentContacts')}）",
        )
        查(
            int(乙账.get("recentContacts", [0])[0]) == 甲账号,
            f"C 收方最近联系人置顶甲（实得 {乙账.get('recentContacts')}）",
        )
        _发(甲会, "0")
        查(_行号(_列(甲会, 3)) == [乙角色], f"C 重拉列表最近列 = 乙（实得 {_列(甲会, 3)}）")
        # 离线：落信箱，登录后由 _send_pending_social 补发。
        查(
            accounts.take_offline_messages(丙账号) == [],
            "C 离线目标初始没有待收私聊",
        )
        _发(甲会, f"8:{丙角色}:离线留言")
        离线信 = accounts.take_offline_messages(丙账号)
        查(
            len(离线信) == 1
            and int(离线信[0].get("fromCharacterId", 0)) == 甲角色
            and str(离线信[0].get("message", "")) == "离线留言",
            f"C 离线私聊落离线信箱（实得 {离线信}）",
        )
        # 拉黑：整条不发、也不落信箱。
        accounts.set_blocked(乙账号, 甲账号, True)
        乙会.发出的帧.clear()
        _发(甲会, f"8:{乙角色}:不该收到")
        查(乙会.发出的帧 == [], f"C 被拉黑后私聊整条不发（实得 {乙会.发出的帧}）")
        查(accounts.take_offline_messages(乙账号) == [], "C 被拉黑后也不落离线信箱")
        accounts.set_blocked(乙账号, 甲账号, False)
        # 拉黑会双向断好友 ⇒ 解除后两边都要补回来（只补一边的话甲的列表就少了乙）。
        accounts.set_friend(乙账号, 甲账号, True)
        accounts.set_friend(甲账号, 乙账号, True)

        # ── D 打探 ───────────────────────────────────────────────────────
        甲会.store.state.inventory.clear()
        甲会.store.save()
        _发(甲会, f"10:{丙角色}")
        查(
            _帧里(甲会.发出的帧, f"{码回}:8:") == [f"{码回}:8:2"],
            f"D 离线目标回 61:8:2（实得 {甲会.发出的帧}）",
        )
        _发(甲会, f"10:{乙角色}")
        查(
            _帧里(甲会.发出的帧, f"{码回}:8:") == [f"{码回}:8:1"],
            f"D 没乾坤密卷回 61:8:1（实得 {甲会.发出的帧}）",
        )
        查(
            not 甲会.store.state.inventory,
            f"D 没密卷不消耗（实得背包 {list(甲会.store.state.inventory)}）",
        )
        乙会.line_id = 2
        乙会.store.state.character.map_id = 7
        乙会.map_id = 7
        乙会.x, 乙会.y = 123.6, 456.4
        甲会.store.state.inventory[5] = ffs.InventoryItem(
            item_id=密卷, slot=5, quantity=1, unique_id=5001
        )
        甲会.store.save()
        _发(甲会, f"10:{乙角色}")
        查(
            _帧里(甲会.发出的帧, f"{码回}:8:") ==
            [f"{码回}:8:0:2:7:124:456"],
            f"D 成功回 61:8:0:<线>:<图>:<x>:<y>（round 取整，实得 {甲会.发出的帧}）",
        )
        查(
            5 not in 甲会.store.state.inventory,
            f"D 只用一枚 ⇒ 整格清掉（实得 {list(甲会.store.state.inventory)}）",
        )
        甲会.store.state.inventory[6] = ffs.InventoryItem(
            item_id=密卷, slot=6, quantity=2, unique_id=5002
        )
        甲会.store.save()
        _发(甲会, f"10:{乙角色}")
        查(
            int(甲会.store.state.inventory[6].quantity) == 1,
            f"D 叠两枚只扣一枚（实得 {甲会.store.state.inventory[6].quantity}）",
        )
        甲会.发出的帧.clear()
        甲会.handle_friendlist(f"{码好友}:10:0")
        查(甲会.发出的帧 == [], f"D 目标号 0 一帧不发（实得 {甲会.发出的帧}）")

        # ── E 删仇人(9)/删最近(7)：只清对应列 ───────────────────────────
        accounts.set_enemy(甲账号, 乙账号, True)
        accounts.set_recent_contact(甲账号, 乙账号)
        _发(甲会, f"9:{乙角色}")
        查(
            _帧里(甲会.发出的帧, f"{码回}:4:") ==
            [f"{码回}:4:{乙角色}:ENEMY"],
            f"E action 9 回 61:4:<号>:ENEMY（实得 {甲会.发出的帧}）",
        )
        查(_行号(_列(甲会, 1)) == [], f"E 仇人列清空（实得 {_列(甲会, 1)}）")
        查(_行号(_列(甲会, 0)) == [乙角色], f"E 好友列不动（实得 {_列(甲会, 0)}）")
        _发(甲会, f"7:{乙角色}")
        查(
            _帧里(甲会.发出的帧, f"{码回}:4:") ==
            [f"{码回}:4:{乙角色}:RECENT"],
            f"E action 7 回 61:4:<号>:RECENT（实得 {甲会.发出的帧}）",
        )
        查(乙角色 not in _行号(_列(甲会, 3)),
            f"E 最近列里乙被清掉（实得 {_列(甲会, 3)}）")
        查(_行号(_列(甲会, 0)) == [乙角色], f"E 删最近不动好友列（实得 {_列(甲会, 0)}）")

        # ── F PvP：被害方记凶手、双方记最近 ────────────────────────────
        with accounts.lock:
            for 号 in (甲账号, 乙账号):
                账 = accounts.account_by_id(号)
                账["enemies"] = []
                账["recentContacts"] = []
            accounts._save_locked()
        甲会._record_pvp_contacts(乙会)
        查(
            int(accounts.account_by_id(乙账号)["enemies"][0]) == 甲账号,
            f"F 被害方把凶手记进仇人（实得 {accounts.account_by_id(乙账号).get('enemies')}）",
        )
        查(
            int(accounts.account_by_id(甲账号)["recentContacts"][0]) == 乙账号
            and int(accounts.account_by_id(乙账号)["recentContacts"][0]) == 甲账号,
            "F 双方「最近联系人」互置顶"
            f"（甲 {accounts.account_by_id(甲账号).get('recentContacts')}／"
            f"乙 {accounts.account_by_id(乙账号).get('recentContacts')}）",
        )


def main() -> int:
    跑()
    if 失败:
        print(f"好友服务端锤：{len(失败)} 条不符")
        for 条 in 失败:
            print("!! " + 条)
        return 1
    print("好友服务端锤：通过（五列位次/行编码/私聊/打探/删仇人/删最近/最近联系人/PvP记仇）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
