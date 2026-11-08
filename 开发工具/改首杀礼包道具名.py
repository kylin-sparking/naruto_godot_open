"""把 `11010041` 的显示名「首充礼包」改成「首杀礼包」（就地改 `数据/物品.json`）。

为什么单写一条脚本而不是手改：`数据/物品.json` 是 `开发工具/导出游戏数据.mjs`
的生成物（单行紧凑 JSON、1.3 MB），手改容易破坏转义/行尾；这里按字节做一次
定锚替换，改前改后都断言命中数，重跑幂等。

只改**这一件**的名字：
- 另一件 `11010067` 叫「回归首充礼包」（`数据/物品.json:1` 附近），**不动**；
- 服务端不在这条链路上（`_encode_item_payload` 只发数值字段，名字由客户端表查）。

用法（仓库根目录）：python -X utf8 开发工具/改首杀礼包道具名.py [--dry-run]
"""
import io
import json
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
路 = os.path.join(根, "数据", "物品.json")

锚 = '"11010041":{"id":"11010041","name":'
旧 = 锚 + '"首充礼包"'
新 = 锚 + '"首杀礼包"'


def 主() -> int:
    dry = "--dry-run" in sys.argv
    字节 = io.open(路, "rb").read()
    文 = 字节.decode("utf-8")
    if 文.count(新) == 1:
        print("已改过（11010041 已是首杀礼包），不重复施加")
        return 0
    if 文.count(旧) != 1:
        raise SystemExit("!! 定锚命中数不符：期望 1 实际 %d" % 文.count(旧))
    # 另一件「回归首充礼包」必须保持原样，改完核对它的计数不掉。
    回归前 = 文.count("回归首充礼包")
    文 = 文.replace(旧, 新)
    assert 文.count(新) == 1, "改完 11010041 名字命中数不是 1"
    assert 文.count("回归首充礼包") == 回归前, "「回归首充礼包」被误伤"
    表 = json.loads(文)
    assert 表["11010041"]["name"] == "首杀礼包", "解析回来名字不对"
    assert 表["11010067"]["name"] == "回归首充礼包", "回归礼包名字被改坏"
    if dry:
        print("--dry-run：将把 11010041 改名首杀礼包（未写入）")
        return 0
    io.open(路, "wb").write(文.encode("utf-8"))
    print("改首杀礼包道具名：11010041 「首充礼包」→「首杀礼包」（回归首充礼包 未动）")
    return 0


if __name__ == "__main__":
    raise SystemExit(主())
