"""GM 网页控制台 —— 把 2.2.3 本地登录器那套 GM 后台接进本项目的服务端。

路由（口令头 `X-Naruto-GM-Password`，只绑 127.0.0.1）：
    GET  /api/gm/overview          → gm_admin.overview()          （新控制台首屏）
    GET  /api/gm/player?id=        → gm_admin.player_detail(id)   （角色详情）
    POST /api/gm/batch             → 同一动作批量打到多个角色
    GET  /api/gm/audit?limit=      → 本次进程内的操作日志
    GET  /api/gm/status            → gm_admin.status()            （老页面用，原样保留）
    GET  /api/gm/items?q=&limit=   → gm_admin.item_rows(q, limit)
    POST /api/gm/action            → gm_admin.run_action(action, payload)

页面：
    `/`、`/gm/`、`/gm/console.html` → `www/gm/console.html`（2026-11-05 新控制台）
    `/gm/index.html`、`/gm/classic.html` → `www/gm/index.html`（HYSJ 原版，逐字节保留）

⚠ 必须**跑在服务端同一个进程里**（由 `本地服务端夹具.py --gm-http <口>` 起线程）：
   `gm_admin.grant_item` 走的是 `gm._store(角色)` 拿到的**内存里的** store 与在线 session，
   另起一个进程去写档会被跑着的服务端下一次 save 顶掉。
"""
from __future__ import annotations

import hmac
import json
import os
import threading
import time
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlsplit

页面目录 = Path(__file__).resolve().parent.parent / "服务端" / "runtime" / "www" / "gm"
原版页面 = 页面目录 / "index.html"
新页面 = 页面目录 / "console.html"
默认口令 = "123456"

# 操作日志只留在进程内（最多 500 条）：控制台重启即清空，够用来回答"刚才谁点错了什么"。
# 不落盘是有意的 —— 写档日志会和存档抢目录，而且这里不需要长期审计。
_日志锁 = threading.Lock()
_操作日志: deque[dict] = deque(maxlen=500)


def _记日志(action: str, targets: Any, ok: bool, cost_ms: int, error: str = "") -> None:
    with _日志锁:
        _操作日志.append(
            {
                "time": time.strftime("%Y-%m-%d %H:%M:%S"),
                "action": action,
                "targets": targets,
                "ok": bool(ok),
                "ms": int(cost_ms),
                "error": error,
            }
        )


def _日志副本(limit: int = 100) -> list[dict]:
    with _日志锁:
        return list(_操作日志)[-max(1, min(500, int(limit))):]


def 口令() -> str:
    return os.environ.get("NARUTO_GM_PASSWORD", 默认口令)


def _查询(路径: str) -> dict:
    out = {}
    串 = urlsplit(路径).query
    for 对 in 串.split("&") if 串 else ():
        键, 分, 值 = 对.partition("=")
        if 分:
            out[unquote(键)] = unquote(值.replace("+", " "))
    return out


def 起服务(端口: int, gm, 日志=print, 服务端=None) -> ThreadingHTTPServer:
    """在 127.0.0.1:端口 上起 GM 控制台，返回服务器对象（线程已跑起来，daemon）。

    `服务端` 传进来是为了 **注册账号**：原版注册从来不走游戏 TCP，走的是网页
    （`HYSJ/www/register.php` + `static_flash_http.py:557 /api/account/register`
    → `ACCOUNT_SERVICE.register`）。本工程没有 php，就把这一条挂在同一个本地口上。
    """
    密 = 口令()

    class 处理(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"
        server_version = "NarutoGM/1"

        def log_message(self, 格式, *参数):  # 别把 HTTP 访问日志混进服务端日志
            pass

        def _发(self, 状态, 正文, 类型="application/json; charset=utf-8"):
            数 = 正文 if isinstance(正文, bytes) else json.dumps(
                正文, ensure_ascii=False
            ).encode("utf-8")
            self.send_response(状态)
            self.send_header("Content-Type", 类型)
            self.send_header("Content-Length", str(len(数)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(数)

        def _错(self, 消息, 状态=400):
            self._发(状态, {"ok": False, "error": 消息 or "请求失败"})

        def _过口令(self) -> bool:
            交 = self.headers.get("X-Naruto-GM-Password", "")
            if 交 and hmac.compare_digest(str(交), 密):
                return True
            self._发(401, {"ok": False, "error": "GM 口令错误"})
            return False

        def _发页面(self, 路径: Path) -> None:
            if not 路径.exists():
                self._错("GM 页缺失：%s" % 路径, 500)
                return
            self._发(200, 路径.read_bytes(), "text/html; charset=utf-8")

        def do_GET(self):
            路 = urlsplit(self.path).path
            # 页本身不校验口令，口令管的是每一条 /api/gm/* —— 与 2.2.3 那份一致
            if 路 in ("/", "/gm", "/gm/", "/gm/console", "/gm/console.html"):
                self._发页面(新页面)
                return
            if 路 in ("/gm/index.html", "/gm/classic.html"):
                self._发页面(原版页面)
                return
            if not 路.startswith("/api/gm/"):
                self._错("查无此接口", 404)
                return
            if not self._过口令():
                return
            try:
                值 = _查询(self.path)
                if 路 == "/api/gm/overview":
                    self._发(200, {"ok": True, **gm.overview()})
                elif 路 == "/api/gm/player":
                    self._发(200, {"ok": True, "detail": gm.player_detail(int(值.get("id", 0)))})
                elif 路 == "/api/gm/audit":
                    self._发(200, {"ok": True, "entries": _日志副本(int(值.get("limit", 100)))})
                elif 路 == "/api/gm/status":
                    self._发(200, {"ok": True, **gm.status()})
                elif 路 == "/api/gm/items":
                    self._发(200, {"ok": True, "items": gm.item_rows(
                        值.get("q", ""), int(值.get("limit", 120)))})
                else:
                    self._错("查无此接口", 404)
            except (ImportError, AttributeError, OSError, TypeError, ValueError) as 异:
                self._错(str(异) or "GM 读取失败")

        def do_POST(self):
            路 = urlsplit(self.path).path
            if 路 == "/api/account/register":
                # 注册**不要 GM 口令**：原版的注册就是网页上游客点的一跳
                # （`static_flash_http.py:557`），口令只管 `/api/gm/*` 那三条。
                if 服务端 is None:
                    self._错("这个服务端实例没带账号服务，注册不可用", 501)
                    return
                try:
                    包 = self._读体()
                    号 = 服务端.ACCOUNT_SERVICE.register(
                        str(包.get("username", "")), str(包.get("password", "")))
                    self._发(200, {"ok": True,
                                   "account": 服务端.ACCOUNT_SERVICE.public_account(号)})
                except ValueError as 异:      # 账号已存在 / 格式不对 / 密码太短
                    self._错(str(异) or "注册失败")
                except (UnicodeError, json.JSONDecodeError, TypeError) as 异:
                    self._错(str(异) or "请求内容无效")
                return
            if 路 not in ("/api/gm/action", "/api/gm/batch"):
                self._错("查无此接口", 404)
                return
            if not self._过口令():
                return
            名 = ""
            目标: Any = None
            开始 = time.perf_counter()
            try:
                包 = self._读体()
                名 = str(包.pop("action", ""))
                if 路 == "/api/gm/batch":
                    目标 = [int(值) for 值 in (包.pop("characterIds", []) or [])]
                    if not 目标:
                        raise ValueError("characterIds 必填")
                    if len(目标) > 50:
                        raise ValueError("一次最多 50 个角色")
                    结果 = []
                    for 角色 in 目标:
                        子包 = dict(包, characterId=角色)
                        try:
                            结果.append(
                                {"characterId": 角色, "ok": True,
                                 "result": gm.run_action(名, 子包)}
                            )
                        except (ValueError, OSError, AttributeError, ImportError) as 异:
                            结果.append(
                                {"characterId": 角色, "ok": False,
                                 "error": str(异) or "操作失败"}
                            )
                    self._发(200, {"ok": True, "results": 结果})
                else:
                    目标 = 包.get("characterId")
                    self._发(200, {"ok": True, "result": gm.run_action(名, 包)})
                _记日志(名, 目标, True, int((time.perf_counter() - 开始) * 1000))
            except (UnicodeError, json.JSONDecodeError, TypeError, ValueError) as 异:
                _记日志(名 or "?", 目标, False, int((time.perf_counter() - 开始) * 1000), str(异))
                self._错(str(异) or "GM 操作失败")
            except (ImportError, AttributeError, OSError) as 异:
                _记日志(名 or "?", 目标, False, int((time.perf_counter() - 开始) * 1000), str(异))
                self._错(str(异) or "GM 操作失败")

        def _读体(self) -> dict:
            长 = int(self.headers.get("Content-Length", "0"))
            if 长 <= 0 or 长 > 256 * 1024:
                raise ValueError("请求内容无效")
            包 = json.loads(self.rfile.read(长).decode("utf-8"))
            if not isinstance(包, dict):
                raise ValueError("请求内容无效")
            return 包

    服务 = ThreadingHTTPServer(("127.0.0.1", int(端口)), 处理)
    threading.Thread(target=服务.serve_forever, daemon=True).start()
    日志("GM 控制台已监听 http://127.0.0.1:%d/gm/index.html （口令 %s）" % (int(端口), 密))
    return 服务


if __name__ == "__main__":
    raise SystemExit(
        "这个模块由 开发工具/本地服务端夹具.py --gm-http <口> 起线程用，"
        "不要单独跑（单独跑就没有服务端进程共享存档对象）。"
    )
