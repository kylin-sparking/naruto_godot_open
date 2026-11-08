#!/usr/bin/env python3
"""给**玩档**（`.fixture-play`）发放各条流程要用的实测道具（两套计划，`--计划` 选）。

和 `发职业忍术与等级.py` 一样：**走服务端自带的 `gm_admin`，不自己拼存档**。

三条硬规矩（都是踩过的坑，写在代码里而不是注释里）
--------------------------------------------------
1. **夹具必须在跑之前停掉**。玩档的存档根是 `--root .fixture-play`，夹具进程内存里那份状态
   会在下次 `store.save()` 时把改动整份盖回去 —— 所以启动脚本先探 18684，探得通就直接退出。
2. **发放前带时间戳逐字节备份**被改的角色档（用户唯一在玩的号，出错没法复原）。
3. **物品 id 一律按名字从 `数据/物品.json` 查**，且要求全表只命中一次。手抄 id 会错一位，
   而 `grant_item` 对不存在的 id 才报错、对错 id 是照发不误的（§3.242 那两件脏装备就是这么进档的）。
   ⇒ 同名多命中（勾玉 1~15 级在 `13100/13101/13102` 三族里各有一条同名的）时**必须点名 id**，
     且点名的那个 id 必须真在该名称的命中里，否则照样中止 —— 不许把歧义糊过去。

用法
----
    # 1) 关掉正在跑的夹具/Godot
    # 2) python 开发工具/发放实测道具.py --root <工程>/.fixture-play
    #    勾玉炼制那套：加 `--计划 玉链勾玉`；先看清单：再加 `--dry-run`
    # 3) 不带 --reset 重新起夹具（`启动游戏.bat`）

报告写到 `.scratch/_out/发放实测道具.txt`（控制台是 GBK，中文会糊）。
"""

import argparse
import json
import shutil
import socket
import sys
import time
from pathlib import Path

项目根 = Path(__file__).resolve().parent.parent

# 名称 → 数量。名称是 `数据/物品.json` 里的 `name`，数量受该表 `stack_max` 限制
# （一次 `grant_item` 不能超过堆叠上限，超了服务端整笔拒发）。
# 同名的第二笔（开光石/灵化石各发 2×999）是因为 100 个一开、999 不够连着试几轮。
发放计划 = [
    # 柔拳：进阶要 灵符(1/2/4/7/10/15/20 张，见 数据/原版杂项.json RouQuan.stageUp)，
    #       祝福要 神符；升级要 秘笈；强化垫子要 柔拳幸运符。
    ("柔拳灵符", 999, "柔拳 stage2→8 全程共需 59 张，一次给满"),
    ("柔拳神符", 99, "柔拳祝福 zhufu_show=1000"),
    ("柔拳幸运符", 99, "⚠ 三处 grep（服务端/AS3/客户端）都没消费点，只作道具名对照"),
    ("白胧天舞秘笈", 99, "柔拳技能升级"),
    ("八卦宗掌波秘笈", 99, "柔拳技能升级"),
    ("八卦合气掌秘笈", 99, "柔拳技能升级"),
    ("八卦三十二掌秘笈", 99, "柔拳技能升级"),
    ("八卦六十四掌秘笈", 99, "柔拳技能升级"),
    ("回天秘笈", 99, "柔拳技能升级"),
    ("空天秘笈", 99, "柔拳技能升级"),
    # 寄坏之术：昆虫本体 + 强化两件（服务端 `_strengthen_kun_chong` 收 needMoney +
    # `KunChong.help.helpItemId` + `KunChong.guarantee.guaranteeId`，见 数据/装备打造.json）。
    ("蝉", 1, "昆虫强化样本"),
    ("蝴蝶", 1, "昆虫强化样本"),
    ("蜻蜓", 1, "昆虫强化样本"),
    ("蜜蜂", 1, "昆虫强化样本"),
    ("甲虫", 1, "昆虫强化样本"),
    ("寄坏虫", 1, "寄坏之术本体"),
    ("镇灵石", 99, "昆虫强化保底符（guaranteeId，levelCanUse=11）"),
    ("寄坏玉", 99, "昆虫强化帮助道具（helpItemId，最多垫 9 个、每个 +3%）"),
    ("幸运符", 99, "秘笈合成/宠物潜力/装备打造的加成道具（昆虫强化用的不是它）"),

    # 十拳剑开光·灵化：开光 = 1 锤 + 100 石（`_open_ling_qi`），
    # 灵化 = 100 石（`_spiritualize_ling_qi`），洗练 = 1 石（`_wash_ling_qi`）。
    ("开光锤", 5, "开光每次吃 1 把"),
    ("开光石", 999, "开光每次吃 100"),
    ("开光石", 999, "第二堆：999 是上限，多来一轮"),
    ("灵化石", 999, "灵化每次吃 100"),
    ("灵化石", 999, "第二堆"),
    ("洗炼石", 99, "灵器洗练每次吃 1"),
    # 尾兽徽章：打造石（`数据/物品.json` 13200000..），再给一件成品做对照。
    ("一尾徽章打造石", 99, "尾兽徽章打造"),
    ("二尾徽章打造石", 99, "尾兽徽章打造"),
    ("三尾徽章打造石", 99, "尾兽徽章打造"),
    ("四尾徽章打造石", 99, "尾兽徽章打造"),
    ("五尾徽章打造石", 99, "尾兽徽章打造"),
    ("九尾徽章打造石", 99, "尾兽徽章打造"),
    ("一尾徽章", 1, "成品对照"),
]

# 勾玉炼制（`YuLianJinJieWindow`）三页 —— 玉链升阶 / 勾玉合成 / 勾玉重置。
# 每页都留一枚**该被拒收**的：满级玉链、满级勾玉、拆开才让用的 ×2 勾玉，
# 这样三句原版拒收话（「该玉链已经是最高阶！」「该勾玉已经是最高等级！」
# 「请将物品拆开成1个再进行该操作！」）在实机上一拖就能各验一次。
# ⚠ 勾玉 1~15 级**同名有三族**（`13100xxxx` / `13101xxxx` / `13102xxxx`）⇒ 一律点名 id。
玉链勾玉计划 = [
    ("稻荷玉链", 1, "1 阶：升阶正腿（吃 stage2 的 10 万金币）", "01200010"),
    ("伊势玉链", 1, "2 阶：升到 3 阶（100 万）", "01200020"),
    ("神武玉链", 1, "3 阶：升到 4 阶（1000 万）", "01200030"),
    ("神世玉链", 1, "4 阶：升到 5 阶（1 亿）", "01200040"),
    ("高天原玉链", 1, "5 阶：升到 6 阶（10 亿）", "01200050"),
    ("八尺琼玉链", 1, "6 阶 = 满级 ⇒ 拖上去该弹「该玉链已经是最高阶！」", "01200060"),
    ("勾玉（1级）", 100, "合成正腿：一次吃 2 个同级 ⇒ 100 个够连掷 50 次", "13100000"),
    ("勾玉（2级）", 2, "×2 摞专门给「勾玉重置」验拆开那句拒收话", "13100001"),
    ("勾玉（3级）", 1, "重置正腿（quantity==1 才收）", "13100002"),
    ("勾玉（15级）", 10, "满级 ⇒ 拖上合成格该弹「该勾玉已经是最高等级！」", "13100014"),
    ("精玉灵珠", 999, "勾玉合成的 `needItemId`（`jade.merge.levelN`），单次上限 9999", "16000031"),
]

# 玉链一路升到六阶要吃 `100000+1000000+10000000+100000000+1000000000` = **11.11 亿**，
# 玩档原来只有 4000 万 ⇒ 连 stage4 都不够。GM 上限 21 亿，设到 20 亿留一倍余量
# （勾玉重置每枚只吃 1000，`jade.change.levelN.needMoney`）。
玉链勾玉货币 = [("money", "set", 2_000_000_000, "玉链五档进阶全程 + 余量")]

# 2026-11-03 用户点名要的三样：传说装备打造石 / 一套紫色昆虫 / 一套料理素材。
# 昆虫经 gm 发放是 `InventoryItem` 默认 `aptitude=2`（绿）⇒ 发放后按 `EqpData.as:31`
# `APTITUDE_COLORS` 下标 4 = 紫逐件改品质；料理材料 = `ItemType.LiaoLiCaiLiao` 的 1601 族
# （`料理放入格.可收` 判的就是八位号前四位 1601）。
传说昆虫料理计划 = [
    ("传说装备打造石", 99, "传说装备打造（用户点名）"),
    ("蝉", 1, "紫昆虫一套：生命"),
    ("蝴蝶", 1, "紫昆虫一套：查克拉"),
    ("蜻蜓", 1, "紫昆虫一套：闪避"),
    ("蜜蜂", 1, "紫昆虫一套：暴击"),
    ("甲虫", 1, "紫昆虫一套：防御"),
]
for _名 in ("香蕉", "鲜虾", "鸡蛋", "柳丁", "胡萝卜", "青菜",
            "坚果", "南瓜", "鲜鱼", "麦子", "蜂蜜", "肉类"):
    传说昆虫料理计划.append((_名, 20, "料理材料一套（1601 族 12 种）"))

紫昆虫 = {"01310001", "01310002", "01310003", "01310004", "01310005"}


def 指向隔离存档(root: Path, port: int = 18684) -> None:
    """与 `本地服务端夹具.py::prepare_environment()` 同一套环境变量。

    ⚠️ 必须五个都设且**在建服务端模块之前**设：`storage_backend` 是在 import 时读这些变量的，
    晚一步就会去开服务端默认的存档而不是玩档。
    """
    import os
    os.environ["NARUTO_MULTIPLAYER_ROOT"] = str(root / "multiplayer")
    os.environ["NARUTO_SAVE_PATH"] = str(root / "save.json")
    os.environ["NARUTO_SERVER_PORT"] = str(port)
    os.environ["NARUTO_NATIVE_LOGIN_PORT"] = str(port)
    os.environ["NARUTO_CHANNEL_PORT"] = str(port)


def 端口被占(port: int) -> bool:
    with socket.socket() as 探测:
        探测.settimeout(0.5)
        return 探测.connect_ex(("127.0.0.1", port)) == 0


def 名称查表() -> dict:
    表 = {}
    for 编号, 定义 in json.loads(
        (项目根 / "数据" / "物品.json").read_text(encoding="utf-8")
    ).items():
        表.setdefault(定义.get("name", ""), []).append(编号)
    return 表


def 归一(计划: list) -> list:
    """三条 = 按名唯一命中；四条 = 名称 + **点名 id**（同名多族时唯一合法的写法）。"""
    出 = []
    for 项 in 计划:
        名称, 数量, 原因 = 项[0], 项[1], 项[2]
        出.append((名称, 数量, 原因, str(项[3]) if len(项) > 3 else ""))
    return 出


def 查id(计划: list, 名称表: dict) -> tuple:
    """名称（+点名的 id）→ `(序号表, 错)`；`错` 非空 = 有歧义，调用方**必须中止**，不许猜。"""
    序号表: dict = {}
    错 = []
    for 名称, _数量, _原因, 点名 in 计划:
        命中 = 名称表.get(名称, [])
        if 点名:
            if 点名 not in 命中:
                错.append("名称 %r 的命中是 %s，**不含点名的 %s**" % (名称, 命中, 点名))
                continue
            序号表[(名称, 点名)] = 点名
            continue
        if len(命中) != 1:
            错.append("名称 %r 命中 %d 个（%s）—— 名称有歧义或不存在" % (名称, len(命中), 命中))
            continue
        序号表[(名称, "")] = 命中[0]
    return 序号表, 错


def 玉链定值词条(服务端, 物品表: dict) -> dict:
    """八位 id → 这一阶玉链该带的**定值**附加词条（`plus.stage<阶>.EquipS1`）。

    判据逐字复算服务端 `_定值部位逐条:62382`：该阶候选**全是定值**（`valueFrom == valueTo`）
    ⇒ 有几条给几条、不掷、不看 `count`。认玉链用的是**装备定义的 `type_name`**，
    不写死 id 区间（与服务端 `_special_stage_up` 那两道闸同一个口径）。
    """
    表 = {}
    属性 = 服务端.EQUIPMENT_ATTRIBUTE_BY_NAME
    plus = 服务端.GAME_DATA_CATALOG.get_equipment_system_config("plus")
    for 编号 in 物品表:
        定义 = 服务端.GAME_DATA_CATALOG.get_equipment_definition(int(编号))
        if 定义 is None or getattr(定义, "type_name", "") != "EquipS1":
            continue
        阶段 = (plus.get("stage%d" % int(定义.stage)) or {}) if isinstance(plus, dict) else {}
        候选 = (阶段.get("EquipS1") or {}) if isinstance(阶段, dict) else {}
        条 = [v for _, v in sorted(候选.items()) if isinstance(v, dict)]
        if not 条 or not all(v.get("valueFrom") == v.get("valueTo") for v in 条):
            continue
        行 = [[int(属性[str(v.get("type") or "").lower()]), int(v.get("valueFrom"))]
               for v in 条 if str(v.get("type") or "").lower() in 属性]
        if 行:
            表[str(编号)] = 行
    return 表


def 补玉链定值词条(服务端, gm, 角色编号: int, 说) -> None:
    """gm 的发放通路只给忍具/徽章补 `plus_attributes` ⇒ **发出来的玉链是 0 条词条**
    （§3.96 点名的"两条都错"里另一条：掉落那支修了，gm 这支没修）。
    词条空 = 投料格与背包格的悬停详情框**看着像坏了**（其实是这件没词条）⇒ 会把 UI 排查带偏，
    所以实测道具先按同一张定值表补齐。
    ⚠ 治的是**道具数据**，不是 gm 通路本身 —— 要不要连 `_add_offline_item` 一起修是另一轮的事。
    """
    表 = 玉链定值词条(服务端, json.loads(
        (项目根 / "数据" / "物品.json").read_text(encoding="utf-8")))
    if not 表:
        说("!! `plus.stageN.EquipS1` 一条定值都没读到 ⇒ 玉链词条这一腿跳过（别当成已经补好）")
        return
    商店, _, _会话 = gm._store(角色编号)
    改 = 0
    with 商店.lock:
        for 件 in 商店.state.inventory.values():
            行 = 表.get("%08d" % int(件.item_id))
            if 行 is not None and [list(x) for x in (件.plus_attributes or [])] != 行:
                件.plus_attributes = 行
                改 += 1
        商店.save()
    说("玉链定值词条补齐 %d 件（阶1 1 条 … 阶6 5 条，与服务端掉落同一张表）。" % 改)


def 补紫昆虫品质(gm, 角色编号: int, 说) -> None:
    """gm 发放走 `InventoryItem` 默认 `aptitude=2`（绿）⇒ 点名的紫昆虫逐件改成 4。

    `EqpData.as:31` 的 `APTITUDE_COLORS[4]` 才是紫；只改发放计划里这五件，别的昆虫不动。
    """
    商店, _, _会话 = gm._store(角色编号)
    改 = 0
    with 商店.lock:
        for 件 in 商店.state.inventory.values():
            if "%08d" % int(件.item_id) in 紫昆虫 and int(件.aptitude) != 4:
                件.aptitude = 4
                改 += 1
        商店.save()
    说("紫昆虫品质改成 4（紫）共 %d 件。" % 改)


def 读角色编号(root: Path) -> int:
    状态 = root / "state.json"
    if 状态.is_file():
        数据 = json.loads(状态.read_text(encoding="utf-8"))
        for 键 in ("character_id", "characterId", "main_character_id"):
            if 数据.get(键):
                return int(数据[键])
    return 0


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    解析 = argparse.ArgumentParser()
    解析.add_argument("--root", required=True, help="玩档存档根，例：<工程>/.fixture-play")
    解析.add_argument("--character-id", type=int, default=0)
    解析.add_argument("--port", type=int, default=18684)
    解析.add_argument("--计划", choices=["柔拳寄坏", "玉链勾玉", "传说昆虫料理"], default="柔拳寄坏",
                      help="发哪一套实测道具（默认 = 原有那套，行为与从前逐字相同）")
    解析.add_argument("--dry-run", action="store_true", help="只列清单和落位，不写存档")
    参数 = 解析.parse_args()

    是玉链勾玉 = 参数.计划 == "玉链勾玉"
    是传说昆虫料理 = 参数.计划 == "传说昆虫料理"
    if 是传说昆虫料理:
        条目 = 归一(传说昆虫料理计划)
    elif 是玉链勾玉:
        条目 = 归一(玉链勾玉计划)
    else:
        条目 = 归一(发放计划)
    货币 = 玉链勾玉货币 if 是玉链勾玉 else []

    root = Path(参数.root)
    报告 = []

    def 落盘() -> None:
        (项目根 / ".scratch" / "_out" / "发放实测道具.txt").write_text(
            "\n".join(报告) + "\n", encoding="utf-8")

    def 说(文本: str) -> None:
        报告.append(文本)
        print(文本)

    if 端口被占(参数.port):
        说("中止：%d 端口有人听 —— 夹具（或正在玩客户端）还活着，" % (参数.port,))
        说("      此刻改存档会被它内存里那份盖回去。先停干净再跑。")
        落盘()
        return 1

    角色编号 = 参数.character_id or 读角色编号(root)
    if 角色编号 <= 0:
        说("拿不到角色编号：用 --character-id 指定")
        落盘()
        return 1
    角色档 = root / "multiplayer" / "characters" / ("%d.json" % 角色编号)
    if not 角色档.is_file():
        说("角色档不存在：%s —— 先起一次夹具" % 角色档)
        落盘()
        return 1

    名称表 = 名称查表()
    序号表, 歧义 = 查id(条目, 名称表)
    if 歧义:
        说("中止：`数据/物品.json` 里以下名称有歧义或不存在，不猜 id：")
        for 行 in 歧义:
            说("  !! " + 行)
        落盘()
        return 1
    说("角色 %d，计划「%s」%d 条全部在 `数据/物品.json` 对得上（%d 条点名 id）。"
      % (角色编号, 参数.计划, len(条目), sum(1 for _, _, _, 点名 in 条目 if 点名)))

    原档 = json.loads(角色档.read_text(encoding="utf-8"))
    背包 = {int(格) for 格 in 原档.get("inventory", {}) if int(格) > 0}
    容量 = int(原档.get("bag_capacity", 0))
    说("背包占用 %d / %d，空闲 %d 格" % (len(背包), 容量, 容量 - len(背包)))

    if 参数.dry_run:
        for 名称, 数量, 原因, 点名 in 条目:
            编号 = int(序号表[(名称, 点名)])
            现有 = sum(int(件.get("quantity", 0)) for 件 in 原档["inventory"].values()
                       if int(件.get("item_id", 0)) == 编号)
            说("  %s ×%-4d（现 %s，id %s）← %s" % (名称, 数量, 现有, 编号, 原因))
        for 币种, 操作, 数额, 原因 in 货币:
            说("  %s %s %s（现 %s）← %s" % (币种, 操作, 数额, 原档.get(币种), 原因))
        说("dry-run：未读改存档，也没留备份。")
        落盘()
        return 0

    备份 = 角色档.with_name("%s.bak-%s" % (角色档.name, time.strftime("%Y%m%d-%H%M%S")))
    shutil.copyfile(角色档, 备份)
    说("备份 %s（%d 字节）" % (备份.name, 备份.stat().st_size))

    指向隔离存档(root, 参数.port)
    sys.path.insert(0, str(项目根 / "开发工具"))
    import 服务端目录
    gm = 服务端目录.加载模块("gm_admin")
    服务端 = 服务端目录.加载模块("fake_flash_server")

    成功 = 0
    for 名称, 数量, 原因, 点名 in 条目:
        try:
            结果 = gm.grant_item({
                "characterId": 角色编号, "itemId": int(序号表[(名称, 点名)]), "quantity": 数量,
            })
            成功 += 1
            说("  %-16s ×%-4d → 槽 %s，该格现有 %s（id %s）" % (
                名称, 数量, 结果["slot"], 结果["quantity"], 结果["itemId"]))
        except Exception as 错:
            说("  !! %-16s ×%d 发放失败：%s" % (名称, 数量, 错))
    说("发放 %d/%d 笔成功。" % (成功, len(条目)))

    for 币种, 操作, 数额, 原因 in 货币:
        try:
            结果 = gm.change_currency({
                "characterId": 角色编号, "currency": 币种, "operation": 操作, "amount": 数额,
            })
            说("  %-16s %s %s → 现 %s（%s）" % (币种, 操作, 数额, 结果["value"], 原因))
        except Exception as 错:
            说("  !! %-16s %s %s 失败：%s" % (币种, 操作, 数额, 错))

    if 是玉链勾玉:
        补玉链定值词条(服务端, gm, 角色编号, 说)
    if 是传说昆虫料理:
        补紫昆虫品质(gm, 角色编号, 说)

    新档 = json.loads(角色档.read_text(encoding="utf-8"))
    汇总 = {}
    for 件 in 新档["inventory"].values():
        汇总[int(件["item_id"])] = 汇总.get(int(件["item_id"]), 0) + int(件.get("quantity", 0))
    说("落档核对：")
    for 名称, _数量, _原因, 点名 in 条目:
        编号 = int(序号表[(名称, 点名)])
        件 = next((v for v in 新档["inventory"].values() if int(v.get("item_id", 0)) == 编号), {})
        条数 = len(件.get("plus_attributes") or [])
        说("  %-16s 共 %-6s 槽 %-4s 附加词条 %s 条"
          % (名称, 汇总.get(编号, 0), 件.get("slot", "-"), 条数))
    for 币种, _操作, _数额, _原因 in 货币:
        说("  %-16s 共 %s" % (币种, 新档.get(币种)))
    正格 = {int(格) for 格 in 新档["inventory"] if int(格) > 0}
    说("背包占用 %d / %d" % (len(正格), 容量))

    落盘()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
