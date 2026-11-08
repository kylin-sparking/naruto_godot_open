extends SceneTree

## 「这具身体到底用哪套动画」的门（#183，2026-10-11）。
##
## 一句话症状：`玩家.gd` 以前把造型号**写死成 `00000001`**，而服务端早就按
## 「裸体分男女 → 穿上装备按职业 → 需求等级≥40 再 +3」算好了 `face` —— 客户端不读，
## 于是女角色进游戏也是金发男（用户实机报的第 4 条）。
##
## 原版口径（`脚本/角色/角色造型.gd` 文件头有行号版）：**造型只有一个入口 = 服务端下发的 `face`**
## （`CharacterSprite.as:1662-1666` ⇒ `ImgUtil.getImg(M_Char, face)`，键是 `lpad(face,8)`）。
##
## 七条腿：
##  ① 纯函数：face 有值就补零、没值才按性别兜底。
##  ② 素材记录真在（表里点到的每个号都能在 `M_Char` 元数据里查到、且有 stand）。
##  ③ 运行期真加载（`configure()` 真返回 true，画出来的纹理路径带着对应造型号）。
##  ④ 客户端接线：不再写死、本地玩家与远程玩家用同一条 face 口径。
##  ⑧ 头像 / 人物窗口立绘与身体**同一个 face**（#191），且四处共用 `游戏会话.自身外观()` 一个口。
##  ⑤ 服务端形状：三档算式还在、那条**性别反义**（曾把男判成女）钉死不许回退。
##  ⑥ 数据现查：基础十套（裸体 2 + 四职业装束 8）齐；`M_Char` 总数只报数。
##  ⑦ 反向：**客户端不许自己按职业挑身体** —— 我上一版就是这么错的（拿创角格图当成初始身体）。

const 角色造型 := preload("res://脚本/角色/角色造型.gd")
const 精灵类 := preload("res://脚本/角色/原始动画精灵.gd")
const 元数据路 := "res://数据/角色/动画元数据.json"
const 玩家路 := "res://脚本/角色/玩家.gd"
const 实体路 := "res://脚本/地图/地图实体.gd"
const 造型脚本路 := "res://脚本/角色/角色造型.gd"
const 服务端路 := "res://服务端/runtime/tools/fake_flash_server.py"
const 会话路 := "res://脚本/单例/游戏会话.gd"
const 头像路 := "res://脚本/界面/头像面板.gd"
const 人物路 := "res://脚本/界面/窗口/人物窗口.gd"
const 精灵路 := "res://脚本/角色/原始动画精灵.gd"
const 索引路 := "res://数据/角色/动画素材索引.json"

var _失败: Array[String] = []
var _条数 := 0


func _initialize() -> void:
	call_deferred("_run")


func _判(条件: bool, 说明: String) -> void:
	_条数 += 1
	if not 条件:
		_失败.append(说明)


func _等(实: String, 期: String, 说明: String) -> void:
	_判(实 == 期, "%s：期望「%s」实得「%s」" % [说明, 期, 实])


func _截段(文: String, 头: String, 下一个 := "\nfunc ") -> String:
	var i := 文.find(头)
	if i < 0:
		return ""
	var 尾 := 文.find(下一个, i + 头.length())
	return 文.substr(i, 尾 - i) if 尾 > i else 文.substr(i)


func _run() -> void:
	# ================= ① 纯函数 =================
	_等(角色造型.造型号(1, 0), "00000001", "face=1（裸男）")
	_等(角色造型.造型号(2, 0), "00000002", "face=2（裸女）")
	_等(角色造型.造型号(303, 0), "00000303", "face=303（雷装束·40 级以上那一档）")
	_等(角色造型.造型号(400, 0), "00000400", "face=400（风装束·低档）")
	_等(角色造型.造型号(10000001, 0), "10000001", "face=10000001（更具体的装备造型，八位以上原样）")
	# face 缺位（离线数据、老包）才轮到性别
	_等(角色造型.造型号(0, 2), "00000002", "face 缺位 + 女")
	_等(角色造型.造型号(0, 1), "00000001", "face 缺位 + 男")
	_等(角色造型.造型号(0, 0), "00000001", "face 与性别都缺位 ⇒ 男（与创角窗默认第一格一致）")
	_等(角色造型.兜底造型号(2), "00000002", "兜底函数单独叫也得是女")

	# ================= ② 素材记录真在 =================
	var 元 = JSON.parse_string(FileAccess.get_file_as_string(元数据路))
	_判(元 is Dictionary, "动画元数据读不出来")
	var 角色段: Dictionary = (元 as Dictionary).get("character", {}) as Dictionary if 元 is Dictionary else {}
	var 基础十套 := ["00000001", "00000002", "00000100", "00000103", "00000200",
			"00000203", "00000300", "00000303", "00000400", "00000403"]
	for 号 in 基础十套:
		var 套: Dictionary = 角色段.get(号, {}) as Dictionary
		_判(not 套.is_empty(), "基础造型 %s 在 M_Char 元数据里查不到" % 号)
		_判((套.get("stand", {}) as Dictionary).has("0"), "基础造型 %s 没有 stand 动作" % 号)
	print("⑥ M_Char 的 character 段共 %d 条" % 角色段.size())

	# ================= ③ 运行期真加载 =================
	for 号 in ["00000001", "00000002", "00000303", "00000400"]:
		var 精灵 = 精灵类.new()
		root.add_child(精灵)
		var 成: bool = 精灵.configure("character", 号, "stand")
		var 路径 := ""
		if 精灵.sprite != null and 精灵.sprite.texture != null:
			路径 = String(精灵.sprite.texture.resource_path).get_file().get_basename()
		## ⚠ 纹理文件名是直解包那套 `<swf>_<tag>_<类名>`（例：
		##   `Char_00000001.swf_12_Char_00000001_stand_0_body`）⇒ 只能 `contains`，
		##   第一版写成 `begins_with("Char_号_")` 把四条全判红（量具坏，图其实都加载出来了）。
		_判(成 and 路径.contains("Char_%s_stand_0_body" % 号),
				"造型 %s 运行期应画出 Char_%s_stand_0_body，configure=%s 实得「%s」" % [号, 号, str(成), 路径])
		精灵.get_parent().remove_child(精灵)
		精灵.free()

	# ================= ④ 客户端接线 =================
	var 玩 := FileAccess.get_file_as_string(玩家路)
	_判(not 玩.contains('configure("character", "00000001"'),
			"玩家.gd 里又出现写死的 00000001 ⇒ 服务端的 face 又被绕过，女角色会重新变成金发男")
	var 建 := _截段(玩, "func setup_player_sprite(")
	_判(建.contains("角色造型.造型号"), "setup_player_sprite 没走 角色造型.造型号")
	_判(建.contains('"face"'), "setup_player_sprite 没把 face 传进去（只传性别 = 装备换装永远不会生效）")
	## ⚠ 2026-10-11（#191）取值口挪进 `游戏会话.自身外观()`（头像/立绘/身体三处共用一个口），
	##   所以这三条判据跟着改到第 ⑧ 腿去判会话那一段；这里只留「玩家真的调了它」。
	##   （原来这三条判的是 玩家.gd 里自己那份 —— 变异实测 N3 抓到过"字在但不生效"，
	##    所以 ⑧ 里那两条仍然钉的是**真 return face** 与**真走 _online_backend 判定**。）
	_判(建.contains("GameSession.自身外观()"),
			"setup_player_sprite 没从会话那个唯一取值口拿 face ⇒ 又要变成各读各的")
	var 实 := FileAccess.get_file_as_string(实体路)
	## 同样要**截段再判**：`pad_zeros(8)` + `get("face"` 在 地图实体.gd 里出现两处
	## （远程玩家生成 :269、角色头像 :1196），全文搜会被另一处喂饱 —— 变异实测 N10 就是这么漏的。
	var 远程段 := _截段(实, "func _on_server_player_spawned(")
	_判(not 远程段.is_empty(), "找不到 _on_server_player_spawned（远程玩家生成改名了 ⇒ 本条要跟着改）")
	_判(远程段.contains('str(int(state.get("face"') and 远程段.contains("pad_zeros(8)"),
			"远程玩家那头不再用 face ⇒ 本地与远程两套口径分家（这次就是把本地接到远程那条上）")

	# ================= ⑤ 服务端形状 =================
	var 服 := FileAccess.get_file_as_string(服务端路)
	if 服.is_empty():
		_判(false, "读不到服务端源码 %s ⇒ 第⑤⑥腿没判" % 服务端路)
	else:
		var 裸 := _截段(服, "    def _base_character_face(self)", "\n    def ")
		_判(裸.contains("CharacterFaceId.NAKED_FEMALE if self.character.gender == 2 else CharacterFaceId.NAKED_MALE"),
				"裸体兜底那一档的性别又反了（`gender == 1` 给女身 = 男角色穿女装）。"
				+ "口径：MAIL=1 男 / FAMAIL=2 女，0（没写过）按男")
		_判(裸.contains("if not body_equipment:") and 裸.contains("job_base"),
				"「没穿身体装备 ⇒ 裸体 / 穿了 ⇒ 职业 + 40 级那一档」这两支少了一支")
		_判(裸.contains("+ (3 if high_level_body else 0)"),
				"40 级以上换最终样子那一支（`职业 + 3`）不在了")
		_判(服.contains("def _current_character_face(") and 服.contains("EquipmentPosition.TRANSFORM"),
				"变身卡/变身装备位优先于常规造型那一层不在了")

	# ================= ⑦ 反向：客户端不许自己按职业挑身体 =================
	var 本 := FileAccess.get_file_as_string(造型脚本路)
	_判(not 本.contains("100:") and not 本.contains("400:"),
			"角色造型.gd 里又出现了 job→造型 的表 —— 那是 ② 那一档（穿上装备）的事，"
			+ "初始身体只分男女；这条错我上一版犯过（拿创角格图当初始身体）")
	for 号 in ["00000100", "00000103", "00000200", "00000303", "00000400"]:
		_判(not 玩.contains(号), "玩家.gd 里不该出现职业装束号 %s（该由服务端 face 下发）" % 号)

	# ================= ⑧ 头像 / 立绘与身体同一个 face（#191） =================
	var 会 := FileAccess.get_file_as_string(会话路)
	var 取口 := _截段(会, "func 自身外观(")
	_判(not 取口.is_empty(), "游戏会话.自身外观() 不在了 —— 它是 face 的**唯一取值口**")
	_判(取口.contains("authoritative_stats") and 取口.contains("_online_backend()"),
			"自身外观 没走 `_online_backend()` 那条判定（不判 in_game 会把离线残留的旧包当成服务端算的结果）")
	## ⚠ 只搜"字在不在"不够（变异实测 N3 抓到）：把在线那一支改成 `if false:` 之后
	##   `authoritative_stats` 那行字还在、门照样绿。要钉的是**那一支真的把 face return 出来**。
	## 钉的是**两行连着**：`if 权 … is_empty():` 紧跟 `return {"face": …}`。
	## 只搜 return 那一行不够 —— 变异实测 N3：把守卫改成 `if false:` 之后
	## 那行字原封不动还在，门照样绿（"字在不在"测不出"这一支还走得通吗"）。
	_判(取口.contains('if 权 is Dictionary and not (权 as Dictionary).is_empty():'
			+ '
			return {"face": int((权 as Dictionary).get("face", 0))'),
			"自身外观 的在线那一支不再由「服务端包非空」这个守卫带着 ⇒ 要么白读、要么被改死")
	_判(not 玩.contains("func _自身外观"),
			"玩家.gd 又自己抄了一份取值口 ⇒ 三处会各读各的（这次就是把四处收成一个口）")
	var 头 := FileAccess.get_file_as_string(头像路)
	_判(头.contains('get_node("角色状态/Portrait")'),
			"头像面板没拿到自己那枚头像节点")
	_判(头.contains('OriginalSprite.portrait("character"') and 头.contains('call("自身外观")'),
			"左上角头像还是烤死的那一张 ⇒ 女角色会配男头像（#191 就是这条）")
	_判(头.contains("if 图 != null:"),
			"头像查不到图时必须**留着原图**，不许刷成空白（空白比错更难查）")
	var 人 := FileAccess.get_file_as_string(人物路)
	_判(人.contains("角色站立图") and 人.contains("OriginalSprite.角色立绘"),
			"人物窗口那具立绘还是烤死的 ⇒ 与身体/头像三处不同口径")
	var 精 := FileAccess.get_file_as_string(精灵路)
	_判(精.contains("static func 角色立绘("), "原始动画精灵.角色立绘() 这个口子没了")
	## 素材侧：两套裸体的头像与立绘类名都真在索引里（否则运行期永远走"保留原图"那一支而没人发现）
	var 索 = JSON.parse_string(FileAccess.get_file_as_string(索引路))
	var 索引: Dictionary = 索 if 索 is Dictionary else {}
	for 号 in ["00000001", "00000002", "00000303", "00000400"]:
		_判(索引.has("Char_%s_info_portrait" % 号), "缺 Char_%s_info_portrait（头像）⇒ 那一档头像换不了" % 号)
		_判(索引.has("Char_%s_stand_0_body" % 号), "缺 Char_%s_stand_0_body（立绘）⇒ 人物窗口换不了" % 号)

	_收尾()


func _收尾() -> void:
	print("汇：共 %d 条，红 %d 条%s" % [_条数, _失败.size(),
			"" if _失败.is_empty() else " —— " + " | ".join(_失败)])
	quit(0 if _失败.is_empty() else 1)
