extends RefCounted

## 这具身体该用哪一套动画 —— **原版只有一个入口：服务端下发的 `face`**。
##
## 真值（2.2.3优化版，逐条到行号）：
##   * `com/mxw/roles/avatar/CharacterSprite.as:1662-1666`
##       ```as3
##       public function set face(param1:int) : void {
##          this._face = param1;
##          this.skinObj = ImgUtil.getImg(ImgType.M_Char, this._face);   // ← 整具身体就这一行
##       ```
##     同文件 `:1538-1568 render()` 只从 `skinObj` 里按动作名/帧号取 `value.className` 画；
##     `:1711-1714 clearEquip()` 把 15 个装备位连同 `skin/face` 一起清成 `-1`。
##   * `com/mxw/common/ImgUtil.as:41` + `:332-341`：`M_Char` 的键 = **`lpad(face, 8)`**
##     ⇒ 造型号就是"八位补零的 face"，本工程 `数据/角色/动画元数据.json` 的 `character` 段与
##        `素材/角色动画/玩家/原版角色_<八位号>/` 沿用同一个口径（现查共 128 条，基础十套见下）。
##   * `com/mxw/game/world/handlers/CharacterHandler.as:339-350`：换装回帧时
##     `clearEquip()` → `face = charLook.face` → 再逐件挂装备 ⇒ **face 由服务端算，客户端不参与**。
##   * `com/mxw/roles/DafautlLook.as:8-12`：创角默认穿 `coat=1040002 / pants=1060002 / weapon=1302000`。
##
## `face` 那一头怎么算（用户 2026-10-11 的口径 + 本工程服务端已实现，逐条见
## `服务端/runtime/tools/fake_flash_server.py:17499 _current_character_face`、`:17546 _base_character_face`）：
##   ① **身上没穿任何身体装备 ⇒ 裸体两套，只分男女**：`1`=男（金发短发绿衣）、`2`=女（粉发双马尾裙子）；
##   ② 穿了 ⇒ `职业 + (最高需求等级 ≥ 40 ? 3 : 0)` —— 即 `100/103`、`200/203`、`300/303`、`400/403`；
##   ③ 变身卡 / 变身装备位优先于以上两条。
## ⇒ 基础十套 = `00000001 00000002` + 上面那八个；再往上的 `100000XX` 那些是更具体的装备造型。
##
## ⚠ 我在这条上翻过一次车，写下来免得下次再犯：第一版我拿创角窗那四格元件图
##   （`格_火男/水女/风女/雷男`）去跟八套职业装束逐特征对（发型/头带/墨镜/脸颊红印/扇子），
##   对上了就把"职业→造型"当成**初始身体**的规则写进客户端 —— **错**：那四套是 ② 那一档
##   （穿上装备之后），不是刚进游戏的样子。配对图留在 `测试/截图/角色造型/_职业格与造型配对.png`，
##   它对 ② 仍然有效。取证文件别删。

const 裸男 := 1
const 裸女 := 2

## 服务端下发的 face ⇒ 造型号。`face <= 0`（离线数据、老包没这一位）时按性别兜底成裸体两套。
static func 造型号(脸: int, 性别: int) -> String:
	if 脸 > 0:
		return str(脸).pad_zeros(8)
	return 兜底造型号(性别)


## 兜底那一档也**只分男女**（口径同 ①）。性别 0（服务端默认角色、老存档没写过）按男。
static func 兜底造型号(性别: int) -> String:
	return str(裸女 if 性别 == 2 else 裸男).pad_zeros(8)
