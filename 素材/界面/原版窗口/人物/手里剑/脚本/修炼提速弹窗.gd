extends Control
## 修炼提速弹窗 —— 还原 Flash ShouLiJianTiShengWindow（340×205）的 UI。
## 只管开关窗、文案填充和「使用全部」二次确认；背包数量/请求由群主接逻辑。

signal 提速请求(全部: bool)

const 数据 := preload("res://素材/界面/原版窗口/人物/手里剑/脚本/手里剑数据.gd")


func _ready() -> void:
	visible = false
	(_取("关闭按钮") as BaseButton).pressed.connect(_收起)
	(_取("取消") as BaseButton).pressed.connect(_收起)
	(_取("开始提速") as BaseButton).pressed.connect(_点提速)
	(_取("使用全部") as BaseButton).pressed.connect(_点全部)
	(_取("全部确认/确定") as BaseButton).pressed.connect(_点确认全部)
	(_取("全部确认/取消") as BaseButton).pressed.connect(_取消确认)


func 更新显示(阶段: int, 等级: int, 熟练度: int) -> void:
	var 阶 := 数据.取阶(阶段)
	(_取("名称/值") as Label).text = String(阶.get("名", ""))
	(_取("品阶/值") as Label).text = "%d阶" % 阶段
	(_取("等级/值") as Label).text = "%d/%d级" % [等级, 数据.每阶最大等级 * 阶段]
	(_取("熟练度/值") as Label).text = "%d/%d" % [熟练度, 数据.熟练度上限]
	(_取("提示") as Label).text = "提升%d点熟练度，需要消耗一张%s" % [
		int(数据.提速["增加熟练度"]), String(数据.提速["物品名"])]
	(_取("全部确认") as CanvasItem).visible = false


func _点提速() -> void:
	提速请求.emit(false)
	_收起()


func _点全部() -> void:
	(_取("全部确认") as CanvasItem).visible = true


func _点确认全部() -> void:
	(_取("全部确认") as CanvasItem).visible = false
	提速请求.emit(true)
	_收起()


func _取消确认() -> void:
	(_取("全部确认") as CanvasItem).visible = false


func _收起() -> void:
	visible = false
	var 父 := get_parent()
	var 暗幕 := 父.get_node_or_null("手里剑弹窗暗幕") as CanvasItem
	if 暗幕 != null:
		暗幕.visible = false


func _取(路径: String) -> Node:
	return get_node(路径)
