#!/usr/bin/env python3
"""给夹具里的测试角色发**全部职业忍术**并设等级 —— 走服务端自带的 `gm_admin`，不自己拼存档。

为什么单独有这个脚本
--------------------
`本地服务端夹具.py --reset` 是**先清空整个存档根再建**（脚本里那句
`if args.reset and root.exists(): shutil.rmtree(...)`）。造号动作只给钱/容量/宠物，
**不给角色技能** —— 所以只要 reset 过一次，测试角色学过的忍术就没了。
这个脚本把"技能 + 等级"这两样补回来，且**不需要 reset**。

用法（必须先停掉正在跑的夹具，否则内存里那份状态会把改动盖回去）
--------------------------------------------------------------
    # 1) 停夹具（占着 18684 的那个 python）
    # 2) python 开发工具/发职业忍术与等级.py --root <工程>/.fixture-play --level 50
    # 3) 不带 --reset 重新起夹具

`--character-id` 不给就取 `state.json` 里那个（夹具启动时写下的主角色编号）。
"""

import argparse
import json
import os
import sys
from pathlib import Path

项目根 = Path(__file__).resolve().parent.parent
# 服务端/GM 工具已进项目（见 服务端/README.md、§3.89），寻径统一走 开发工具/服务端目录.py。


def 指向隔离存档(root: Path, port: int = 18684) -> None:
    """与 `本地服务端夹具.py::prepare_environment()` 同一套环境变量。

    ⚠️ 必须四个都设且**在建服务端模块之前**设：`storage_backend` 是在 import 时读这些变量的，
    晚一步它就会去开服务端默认的存档（`服务端/runtime/save`），而不是隔离存档。
    """
    os.environ["NARUTO_MULTIPLAYER_ROOT"] = str(root / "multiplayer")
    os.environ["NARUTO_SAVE_PATH"] = str(root / "save.json")
    os.environ["NARUTO_SERVER_PORT"] = str(port)
    os.environ["NARUTO_NATIVE_LOGIN_PORT"] = str(port)
    os.environ["NARUTO_CHANNEL_PORT"] = str(port)


def 读角色编号(root: Path) -> int:
    状态 = root / "state.json"
    if 状态.is_file():
        try:
            数据 = json.loads(状态.read_text(encoding="utf-8"))
        except Exception:
            return 0
        for 键 in ("character_id", "characterId", "main_character_id"):
            if 数据.get(键):
                return int(数据[键])
    return 0


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    解析 = argparse.ArgumentParser()
    解析.add_argument("--root", required=True, help="夹具存档根，例：<工程>/.fixture-play")
    解析.add_argument("--character-id", type=int, default=0)
    解析.add_argument("--level", type=int, default=50)
    解析.add_argument("--skill-level", type=int, default=0, help="技能等级，不给就跟 --level 一样")
    参数 = 解析.parse_args()

    root = Path(参数.root)
    if not (root / "save.json").is_file():
        print("存档不存在：%s —— 先起一次夹具" % (root / "save.json"))
        return 1
    指向隔离存档(root)
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import 服务端目录
    gm = 服务端目录.加载模块("gm_admin")  # noqa: PLC0415 项目内那份

    角色编号 = 参数.character_id or 读角色编号(root)
    if 角色编号 <= 0:
        print("拿不到角色编号：用 --character-id 指定")
        return 1

    print("角色 %d：设等级 %d" % (角色编号, 参数.level))
    print(json.dumps(gm.change_level({
        "characterId": 角色编号, "operation": "set", "amount": 参数.level,
    }), ensure_ascii=False))

    技能等级 = 参数.skill_level or 参数.level
    print("角色 %d：发全部职业忍术（等级 %d）" % (角色编号, 技能等级))
    结果 = gm.grant_all_skills({"characterId": 角色编号, "level": 技能等级})
    print(json.dumps(结果, ensure_ascii=False))
    print("技能数 %d（新增 %d）" % (结果["skillCount"], 结果["added"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
