# -*- coding: utf-8 -*-
"""往 开发工具/验证全部.ps1 的离线门清单里追加一条（幂等）。

清单是 base64(JSON 数组) 写死在 .ps1 里的 ⇒ 只能整串重编码，别手抄。
用法：python 开发工具/登记离线门.py 意志页回归测试.gd
"""
import base64
import io
import json
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
if len(sys.argv) < 2:
    print(__doc__)
    raise SystemExit(2)
名 = sys.argv[1] if sys.argv[1].endswith(".gd") else sys.argv[1] + ".gd"
路 = "开发工具/验证全部.ps1"
原文 = io.open(路, encoding="utf-8-sig", newline="").read()
m = re.search(r'\$testsBase64 = "([^"]+)"', 原文)
if m is None:
    print("!! 找不到 $testsBase64 那一行")
    raise SystemExit(1)
清单 = json.loads(base64.b64decode(m.group(1)).decode("utf-8"))
if not isinstance(清单, list):
    print("!! 清单不是数组")
    raise SystemExit(1)
if 名 in 清单:
    print("已在册：%s（共 %d 条）" % (名, len(清单)))
    raise SystemExit(0)
import os
if not os.path.exists(os.path.join("测试", 名)):
    print("!! 测试/%s 不存在，先别登记" % 名)
    raise SystemExit(1)
清单.append(名)
新串 = base64.b64encode(json.dumps(清单, ensure_ascii=False).encode("utf-8")).decode("ascii")
出 = 原文.replace(m.group(1), 新串)
io.open(路, "w", encoding="utf-8-sig", newline="").write(出)
print("已登记 %s ⇒ 共 %d 条（+1 条布局体检 = %d 个门）" % (名, len(清单), len(清单) + 1))
