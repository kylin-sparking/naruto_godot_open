extends RefCounted
## 族中**职务**：服务端的 `rank` → 名字 + 颜色。全工程**只此一份**。
##
## 真值：`FamillyManager.getRankName`（`.\火影世界单机端2.2.3\...\familly\FamillyManager.as:689-717`），
## 逐条照抄 —— 三个 UI 都用它、而且都是用 **htmlText**（颜色是原版渲染的一部分）：
##   * `FamillyItemRenderer.as:30`（家族主窗成员行「职位」列）
##   * `FamillyMemberItemRender.as:80`（成员窗「职务」列）
##   * `FamillyGongXianItemRenderer.as:38`（贡献窗「族中职务」列）
##
## ⚠️⚠️ 2026-10-09 之前这里（在三个文件里各抄了一份）**整个是反的**：
##     写成 `{5:族长, 4:副族长, 3:长老, 2:精英, 1:成员}` —— 把 rank 5 当族长、rank 1 当成员。
##     而服务端给**族长**存的就是 **rank 1**（`.fixture/multiplayer/accounts.json` 里
##     族长账号的 `ranks` 是 `{"<账号id>": 1}`），于是**自己创建家族的人**在成员窗里
##     显示成「成员」。用户 2026-10-09 报的"角色身份为成员"就是这个。
##     ⇒ 改动这张表之前，先去 `FM.as:689-717` 核对一遍 rank 的方向，别凭直觉排。
##
## 服务端的另两处呼应：`handle_map_flag_action` 判"能不能操作族旗"用的是
## `leaderAccountId == account_id`，跟 rank 无关；rank 只管显示。

## rank → 职务名（`default` = 族员 `FAMILLY_MANAGER_ZUYUAN`）
const 名 := {1: "族长", 2: "副族长", 3: "长老", 4: "顾问", 5: "精英"}
## rank → 职务名颜色（原版 `<font color=...>` 那几档；其余一律白）
const 色 := {1: "#a800ff", 2: "#1e90ff", 3: "#00ff00", 4: "#ffffff", 5: "#ffffff"}


static func 职务名(rank: int) -> String:
	return String(名.get(rank, "族员"))


static func 职务色(rank: int) -> Color:
	return Color(String(色.get(rank, "#ffffff")))
