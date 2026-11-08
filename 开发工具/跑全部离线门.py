# -*- coding: utf-8 -*-
"""把「离线门」**全部跑完**再汇总 —— 不 fail-fast，且**单门带超时**。

为什么不用 `验证全部.ps1`：它 `$ErrorActionPreference = "Stop"` + `throw`，第一条一红就退出，
后面的一条都不跑。交证据包要的是**完整输出**，所以这里逐条跑、逐条记退出码，
全量落到 `测试/_验证全部_全量.log`。

⚠️ **为什么必须带超时**（2026-10-15 合并那一轮付过代价）：
缺素材时 `脚本/界面/功能窗口.gd` 会整份 parse 失败（它 preload 了心法/交易/双修/摆摊四扇窗），
于是**开窗类门 `await` 一个永远不来的信号 ⇒ 永久挂住**（不是失败，是挂）。
不带超时时整批卡死在第一条挂门上，前面的结果全白跑。

用法：
    python 开发工具/跑全部离线门.py [起序号] [止序号] [--超时 秒]
    GODOT=<godot 可执行路径> python 开发工具/跑全部离线门.py     # 覆盖 Godot 路径
Godot 路径默认**从 `验证全部.ps1` 的 `$Godot` 默认值读**（那是全工程唯一一处写它，别在这儿再抄一份）。

⚠️ **`止` 是给"一趟跑不完 10 分钟预算"用的**：`起=1` 时清空日志，`起>1` 时**追加**，
所以分段跑 `[1,60]` + `[61,止]` 两段能拼成一份完整全量日志。**别并发跑两段**（会抢同一份日志、
还会互相按字节还原玩档，§3.217）。

⚠️ **每条门前快照 `user://玩家数据.json`，跑完发现被改就按字节还原并点名**（2026-10-17 血案）：
新写的「宠物面板回归测试」第一版收尾用普通 `Array` 接 `pets`（`Array[Dictionary]`）⇒ 赋值
`Invalid assignment` **报错但不中断** ⇒ 三只假宠留在会话里、被会话层下一次落盘写进**真实玩档**
（level 也被写成 1）。后果不是本门红，是**隔天三条邻居门红**（功能入口「宠物页缺按钮：附身」、
阿凯洗点徽章页的等级断言、点角色不崩），查了半天才发现红的是**存档**不是代码。
所以口径：**门自己该快照/还原**（见 `测试/那一排按钮回归测试.gd:481-498` 的模板），
跑全量这一层再兜一道 —— 谁漏了，这里当场还原并点名，别让它污染下一条门。
"""
import base64
import json
import os
import re
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ps1 = os.path.join(工程, "开发工具", "验证全部.ps1")
源 = open(ps1, encoding="utf-8").read()

# ── 真实玩档（user://玩家数据.json）：每条门前快照、跑完还原 ──
def _玩档路径():
    名 = "火影世界"
    项目 = os.path.join(工程, "project.godot")
    if os.path.exists(项目):
        m = re.search(r'^config/name="([^"]*)"', open(项目, encoding="utf-8").read(), re.M)
        if m:
            名 = m.group(1)
    return os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", 名, "玩家数据.json")


玩档 = _玩档路径()


def _读字节(路):
    try:
        with open(路, "rb") as f:
            return f.read()
    except OSError:
        return None


def _写字节(路, 数):
    with open(路, "wb") as f:
        f.write(数)

# ── Godot 路径：环境变量 > 验证全部.ps1 的 $Godot 默认值 ──
GODOT = os.environ.get("GODOT") or ""
if not GODOT:
    m = re.search(r'\$Godot\s*=\s*"([^"]+)"', 源)
    assert m, "没从 验证全部.ps1 里读到 $Godot —— Godot 路径的唯一真源在那儿"
    GODOT = m.group(1)
assert os.path.exists(GODOT), "Godot 可执行文件不存在：%s（用 GODOT=... 覆盖）" % GODOT

# ── 清单：与 验证全部.ps1 同一份 base64（照抄，不另列 —— 另列就会漂移）──
清单 = None
for 行 in 源.split("\n"):
    if "$testsBase64" in 行 and '"' in 行:
        清单 = 行.split('"')[1]
        break
assert 清单 is not None, "没从 验证全部.ps1 里抓到 testsBase64"
套件 = json.loads(base64.b64decode(清单).decode("utf-8"))
布局审计 = base64.b64decode("56qX5Y+j5biD5bGA5L2T5qOALmdk").decode("utf-8")
全部 = 套件 + [布局审计]

起 = 1
止 = len(全部)
超时 = 150.0
参数 = sys.argv[1:]
位次 = 0
i = 0
while i < len(参数):
    a = 参数[i]
    if a == "--超时":
        超时 = float(参数[i + 1]); i += 2; continue
    if not a.startswith("-"):
        位次 += 1
        if 位次 == 1:
            起 = int(a)
        elif 位次 == 2:
            止 = int(a)
    i += 1

出 = os.path.join(工程, "测试", "_验证全部_全量.log")
红, 挂, 写档 = [], [], []
with open(出, "w" if 起 == 1 else "a", encoding="utf-8") as 志:
    志.write("\n████████ 段 %d..%d（共 %d 条）████████\n" % (起, 止, len(全部)))
    for 序, t in enumerate(全部, 1):
        if 序 < 起:
            continue
        if 序 > 止:
            break
        档前 = _读字节(玩档)
        try:
            p = subprocess.run(
                [GODOT, "--headless", "--path", 工程, "--script", "res://测试/" + t],
                capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=超时)
            码, 文 = p.returncode, (p.stdout or "") + (p.stderr or "")
        except subprocess.TimeoutExpired as e:
            码 = -9
            原 = e.stdout or ""
            文 = "★ 超时 %.0f 秒未结束（多半是 `await` 在等一个永远不来的信号）\n%s" % (
                超时, 原.decode("utf-8", "replace") if isinstance(原, bytes) else 原)
        # —— 存档兜底：门漏了快照/还原时，这里按字节还原并点名 ——
        档后 = _读字节(玩档)
        写档了 = 档后 != 档前
        if 写档了:
            if 档前 is None:
                try:
                    os.remove(玩档)
                except OSError:
                    pass
            else:
                _写字节(玩档, 档前)
            写档.append(t)
            文 += "\n★ 本门改过 user://玩家数据.json，已由跑全部离线门.py 按字节还原（门自己该做这一步）\n"
        志.write("\n══════════════════ %d %s  (exit %s) ══════════════════\n" % (序, t, 码))
        志.write(文)
        if 码 == -9:
            挂.append(t); print("%-38s 挂（超时）" % t, flush=True)
        elif 码:
            红.append(t); print("%-38s exit %s" % (t, 码), flush=True)
        elif 写档了:
            print("%-38s ok  ⚠ 写存档（已还原）" % t, flush=True)
        else:
            print("%-38s ok" % t, flush=True)

跑过 = min(止, len(全部)) - 起 + 1
print("\n汇：共 %d 条（本次跑第 %d..%d，实跑 %d），绿 %d，红 %d，挂 %d" % (
    len(全部), 起, 止, 跑过, 跑过 - len(红) - len(挂), len(红), len(挂)))
for t in 红:
    print("   红:", t)
for t in 挂:
    print("   挂:", t, " ← 先看它是不是被缺素材/被另一条门的失败连带挂的")
if 写档:
    print("\n⚠ 这些门写进了真实玩档（已按字节还原，但门里该自己快照/还原）：")
    for t in 写档:
        print("   写档:", t)
print("全量日志 →", os.path.relpath(出, 工程))
