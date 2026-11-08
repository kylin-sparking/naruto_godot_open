# -*- coding: utf-8 -*-
"""把新道门登记进 `开发工具/验证全部.ps1` 里那份 **base64 清单**（全量唯一事实源）。

做法是**在解出来的 JSON 原文上做字符串插入**，不是 `json.loads` 再 `dumps` ——
后者会被工具整份重排（键序/空格全变），记忆里为此专门留过一条：共享门清单要"取上游格式、只插自己那条"。

用法：`python 开发工具/登记全量门.py 换皮件三态回归测试.gd`
"""
import base64
import io
import json
import os
import re
import sys

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
路径 = os.path.join(工程, "开发工具", "验证全部.ps1")


def 换行读(路):
    return io.open(路, encoding="utf-8", newline="").read()


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    新 = sys.argv[1] if len(sys.argv) > 1 else "换皮件三态回归测试.gd"
    文 = 换行读(路径)
    m = re.search(r'\$testsBase64 = "([A-Za-z0-9+/=]+)"', 文)
    if m is None:
        raise SystemExit("验证全部.ps1 里找不到 $testsBase64 那一行")
    原文 = base64.b64decode(m.group(1)).decode("utf-8")
    try:
        表 = json.loads(原文)
    except Exception as e:
        raise SystemExit("清单 base64 解出来不是合法 JSON（%s）⇒ 先还原 `验证全部.ps1` 再来登记" % e)
    print("清单现有 %d 条；末三条：%s" % (len(表), 表[-3:]))
    if 新 in 表:
        print("已经登记过了 ⇒ 什么都不做（幂等）")
        sys.exit(0)
    if not 原文.rstrip().endswith("]"):
        raise SystemExit("清单原文不是以 ] 结尾，形状和预期不同，先人工看")
    体 = 原文.rstrip()
    身 = 体[:-1]
    新原文 = 身 + ("," if 身.endswith('"') else "") + '"%s"' % 新 + "]"
    try:
        解回 = json.loads(新原文)
    except Exception as e:
        raise SystemExit("插完之后 JSON 解不开（%s）⇒ 别写坏全量清单" % e)
    if 解回 != 表 + [新]:
        raise SystemExit("复查不符：必须是原 %d 条逐字不变 + 新的一条在末尾（实得 %d 条）" % (len(表), len(解回)))
    码 = base64.b64encode(新原文.encode("utf-8")).decode("ascii")
    出 = 文.replace(m.group(1), 码, 1)
    if 出 == 文:
        raise SystemExit("base64 没替换成功")
    tmp = 路径 + ".tmp"
    with io.open(tmp, "w", encoding="utf-8", newline="") as f:
        f.write(出)
    回 = 换行读(tmp)
    二 = re.search(r'\$testsBase64 = "([A-Za-z0-9+/=]+)"', 回)
    if 二 is None or 二.group(1) != 码:
        os.remove(tmp)
        raise SystemExit("回读校验失败")
    os.replace(tmp, 路径)
    print("已登记：%s ⇒ 共 %d 条（原样只多这一条，其余 %d 条逐字未动）" % (新, len(解回), len(表)))
