extends SceneTree
## 家族**族徽加成**回归门（离线）。
##
## 钉的是原版 `SkillHandler.addFlagBuff`（`SkillHandler.as:641-665`）：
##   * 只有 `mapid == 当前地图` 才加 ⇒ **本图得有本族的旗**（文案也写"您附近存在本族的家族旗帜"）；
##   * 文案取 `增益状态.json` 的 `flag[家徽等级]` 的 `buffName` / `buffDesc`
##     （`ImgUtil.getImg(ImgType.Buff,"flag")`）；
##   * 图标 = 家徽图（`PicTool.getJiaHuiPic(flag_style)`）、`remainTime = 21000000001`（**永久不倒数**）。
## ⚠️ 本机服务端**从不发** `1815` 动作 6（`startFlagBuff`），所以这条是客户端按同一口径自造的
##    —— 门就钉"自造得对不对"。
##
## 用法：Godot --headless --path . --script res://测试/族徽加成回归测试.gd

var _失败: Array[String] = []
var _会话: Node
var _后端: Node
var _原家族 := {}
var _原旗 := {}


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	_会话 = root.get_node_or_null("GameSession")
	_后端 = root.get_node_or_null("BackendConnection")
	if _会话 == null or _后端 == null:
		_失败.append("缺 GameSession / BackendConnection")
		_收尾()
		return
	_查文案表()
	_查三条件()
	_收尾()


func _查文案表() -> void:
	# 表本身：1~10 级都要有名字与说明（文案是"经验/打坐"加成，不是攻防血）
	for 级 in range(1, 11):
		var 条: Dictionary = 游戏数据.族徽增益(级)
		if 条.is_empty():
			_失败.append("增益表缺 `flag[%d]`（数据/增益状态.json）" % 级)
			continue
		var 名 := String(条.get("buffName", ""))
		var 说明 := String(条.get("buffDesc", ""))
		if 名.is_empty() or 说明.is_empty():
			_失败.append("`flag[%d]` 缺 buffName/buffDesc" % 级)
		if not 说明.contains("家族旗帜"):
			_失败.append("`flag[%d]` 的说明不像族徽加成：%s" % [级, 说明.substr(0, 30)])
	# 抽查一档真值（3 级 = 50% 经验 / 8% 打坐）
	var 三: Dictionary = 游戏数据.族徽增益(3)
	if not String(三.get("buffName", "")).contains("三"):
		_失败.append("3 级的名字不对：%s" % 三.get("buffName"))
	if not String(三.get("buffDesc", "")).contains("50%"):
		_失败.append("3 级的说明里应含 50%（经验加成），实为：%s" % 三.get("buffDesc"))


func _查三条件() -> void:
	_原家族 = (_会话.get("guild") as Dictionary).duplicate(true)
	_原旗 = (_后端.get("authoritative_map_flag") as Dictionary).duplicate(true)

	# ① 没入族 ⇒ 没有这条加成
	_会话.set("guild", {"joined": false})
	_后端.set("authoritative_map_flag", {})
	if not (_会话.call("族徽加成条目") as Dictionary).is_empty():
		_失败.append("没入族也给了族徽加成")

	# ② 入了族、但本图没有（或不是本族的）旗 ⇒ 没有加成（原版 `mapid != 当前地图` 那条）
	_会话.set("guild", {"joined": true, "id": 9, "name": "22", "level": 3, "flag_style": 1000})
	_后端.set("authoritative_map_flag", {"map_id": 100000000, "bang_id": 4, "flag_level": 1})
	if not (_会话.call("族徽加成条目") as Dictionary).is_empty():
		_失败.append("本图是别族的旗，也给了族徽加成（原版只认本图本族）")

	# ③ 本图有本族的旗 ⇒ 出条目，文案/图标/时长都要对
	_后端.set("authoritative_map_flag", {
		"map_id": 100000000, "bang_id": 9, "flag_level": 3, "flag_style": 1000,
		"flag_name": "22", "flag_hp": 10000, "flag_maxhp": 10000,
	})
	var 条 := _会话.call("族徽加成条目") as Dictionary
	if 条.is_empty():
		_失败.append("本图有本族的旗，却没有族徽加成")
		return
	if String(条.get("name", "")) != String(游戏数据.族徽增益(3).get("buffName", "")):
		_失败.append("加成名没取 `flag[3].buffName`：%s" % 条.get("name"))
	if not String(条.get("desc", "")).contains("50%"):
		_失败.append("加成说明没取 `flag[3].buffDesc`：%s" % String(条.get("desc", "")).substr(0, 40))
	if not String(条.get("icon", "")).ends_with("家徽_1000.png"):
		_失败.append("图标不是家徽图（`PicTool.getJiaHuiPic(flag_style)` 那张）：%s" % 条.get("icon"))
	if int(条.get("remain_time", 0)) != 21000000001:
		_失败.append("`remainTime` 应为 21000000001（永久不倒数）：%s" % 条.get("remain_time"))
	if int(条.get("skill_level", 0)) != 3:
		_失败.append("`skill_level` 应带家徽等级 3：%s" % 条.get("skill_level"))


func _收尾() -> void:
	# 还原（本门是离线的，但别把合成状态留在会话里给后面的门用）
	if _会话 != null:
		_会话.set("guild", _原家族)
	if _后端 != null:
		_后端.set("authoritative_map_flag", _原旗)
	for 条 in _失败:
		print("  !! " + 条)
	if _失败.is_empty():
		print("族徽加成回归测试：通过（文案取 flag[等级] → 仅本图本族族旗才有 → 图标=家徽、永久不倒数）")
		quit(0)
	else:
		print("族徽加成回归测试：FAIL %d 条" % _失败.size())
		quit(1)


const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
