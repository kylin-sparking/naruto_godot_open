# 服务端（沿用上游 2.2.3 Flash 版）

> 来源与致谢见根目录 [`NOTICE.md`](../NOTICE.md)。

## 为什么在这里
本项目"启动游戏 / 在线回归门 / 借 catalog 的导出器"需要一个本地火影世界服务端。
以前它**运行时 import 上游 `2.2.3/tools/fake_flash_server.py`** —— 而 2.2.3 是上游 Flash 版的参考目录，
运行时不该依赖它的代码。2026-10-03 把整套服务端**原样复制**进项目，运行期从此只认这里。

## 目录形状（为什么多一层 `runtime`）
```
服务端/
├── README.md                         ← 本文件
└── runtime/                          ← 服务端眼里的 PROJECT_ROOT（见下）
	├── tools/                        ← 6 个 .py + 2 个商城 catalog.json
	│   ├── fake_flash_server.py      ← 主服务端（唯一有本地改动，见"改了哪"）
	│   ├── multiplayer_backend.py    ├── editor_runtime_config.py
	│   ├── gm_state.py               ├── gm_admin.py
	│   ├── storage_backend.py        ├── nya_208_runtime_catalogs.json   nya_208_cash_catalog.json
	└── www/
		├── act_web_nya_208_isolated/dat/GameData.dat        ← 2.6MB，进仓（数值权威源）
		└── act_web_tiyan/localization/t2s.txt               ← 繁→简映射（缺了只降级不崩）
```
四个 .py 都用 `PROJECT_ROOT = Path(__file__).resolve().parents[1]` 找根，并在根下按
`tools/`、`www/...` 定位数据 —— 所以**必须保持 `runtime/tools/x.py` 这层深度**，
拷进来时零改动即可自洽（`runtime` 这层名是被 `parents[1]` 逼出来的，不是随意起）。

## 改了哪（相对上游 2.2.3 的**唯一**差异）
只有 `fake_flash_server.py` 的 `_broadcast_server_monster_attack` 一处（+26 行）：
上游这段只把"怪出手帧"（`MOVE_MONSTER` cmd=1）发给 `wire_mode=="original"` 的二进制客户端，
**text 模式的我们收不到** → 在线怪打人没有出手动画（§3.88.2）。补了一条 text 帧广播，
字段序对齐 `后端连接._handle_monster_attack_text`（direction 从 binary 的 0/1 翻成 handler 要的 ±1）。
验证（应只剩这一个 hunk）：
```bash
diff "<上游 2.2.3>/tools/fake_flash_server.py" "服务端/runtime/tools/fake_flash_server.py"
```
（上游 2.2.3 那份保持原样作参考；本仓库这份才是运行期用的。）

## 谁在用这里
- `开发工具/本地服务端夹具.py`：起服务端、造测试账号/物品/属性；在线门（`跑在线用例.ps1`）每条一个全新隔离夹具。
- 各 `开发工具/导出*.py` / `原版数据.py` 等：借 `GAME_DATA_CATALOG` 把数值导进 `数据/*.json`，口径与服务端一致。
- 寻径统一走 `开发工具/服务端目录.py`（唯一真源；它会 `sys.path.insert(0, 本目录)` 并断言加载文件在项目内，
  防止误 import 到 2.2.3）。

## 解释器（不进仓）
`运行时/python`（官方 embeddable 3.13，纯 stdlib —— 服务端不依赖第三方包）。
`.gitignore` 掉了（21MB，不随开源仓库分发）。新机器/干净克隆：从上游 2.2.3 包的 `runtime/python` 拷一份到
`运行时/python`，**并删掉 `运行时/python/python313._pth` 里的 `..\..\tools` 一行**（否则会把上游 `tools`
自动挂进 sys.path，正是要杜绝的隐式依赖）。`启动游戏.bat` 用的就是这个项目内解释器。

## 行号会漂
本文档、`测试/*.gd`、`脚本/**` 里 `fake_flash_server.py:NNNNN` 的引用**一律以本仓库这份为准**。
bug② 那处补丁在 36601 行附近插入，使其后所有行号 +24；改过服务端后跑
`开发工具/校对服务端引用.py` 体检，新引用优先写**函数名**（行号只当辅助注）。

## GM 网页控制台（2026-10-08 夜新接）

形状照 `HYSJ/tools/local_package_server.ps1` + `static_flash_http.py` 里 GM 那三段：**一个进程同时跑游戏服与 GM 站**。

- `开发工具/GM控制台服务.py`（新）：只三条路由 —— `GET /api/gm/status`、`GET /api/gm/items?q=&limit=`、
  `POST /api/gm/action`。口令走请求头 `X-Naruto-GM-Password`（环境变量 `NARUTO_GM_PASSWORD`，默认 `123456`），
  只绑 `127.0.0.1`。
- `服务端/runtime/www/gm/index.html`：从 HYSJ 那份**逐字节原样**拷来（111,860 B，md5 前缀 `25ed69889e15`，
  自包含、无外部引用）。页面上那 60 项动作全部落在 `tools/gm_admin.py` 的 `ACTIONS` —— **那份与 HYSJ 逐字节一致，本工程一行没改**。
- `开发工具/本地服务端夹具.py` 多一个 `--gm-http <口>`（**默认 0 = 不起**，所以在线门一条都不受影响）。
- ⚠ 必须起在夹具**同一个进程**里：`gm_admin._store()` 拿的是内存中的 store 与在线 session，
  另起一个进程去写档会被跑着的服务端下一次 `save()` 顶掉。
- `启动游戏.bat` 现在带 `--gm-http %GMPORT%`（18680），双击后 GM 在 <http://127.0.0.1:18680/gm/index.html>。

实测（发物品给主角色，全新隔离夹具）：`item ×7` → 回包 `slot 35 / quantity 7`，盘上
`<夹具根>/multiplayer/characters/1.json` 同格 `quantity 7`；再 `item ×3` → **同一格 10**（堆叠，不新建格）。
反向对照四条全响：不带口令 401、错口令 401、未知 action 400、道具不存在 400（且**回滚** ——
`the character save was restored: 道具不存在`）。角色在线时直接收 `ITEM_CHANGE` 加格 + 一条「GM道具发放」通知，不用重登。
