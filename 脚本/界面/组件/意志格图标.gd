extends TextureRect

## 格图标自转 —— 照 `RotateComponent.tick:97-101`：
##   `_rotate = (_rotate + _speed) % 360; rotation = _rotate`
## 速度 = 图鉴项的 `speed`（`YiZhiData.setTextColor:204-239`：灰0/绿1/蓝3/黄3/粉5/紫5/红7/淡粉7；
## 数据在 `数据/意志图鉴.json` 的每项 `speed` 字段，由 `开发工具/导出意志图鉴.py` 出）。
## 用在三处：学习格（`_填学习格`）、背包/穿戴格（`_填一格层`）、升级槽（`_填升级格`）。
## 原版 tick 挂 stage 帧（`API.customHander.addTick`），**该帧率未证** ⇒ 取 24fps，
## 与 `意志提示框` 的 `节拍秒` 同口径；它只影响转速快慢，不影响任何可量几何。
## `RotateComponent.set x/y`（`:90-102`）把 sprite 原点推到 +(w/2,h/2)，`start()`（`:59-68`）
## 又把源图摆到 (−w/2,−h/2) ⇒ 绕**自身中心**转 ⇒ 工程 `pivot_offset = size/2` 等价。
const 节拍秒 := 1.0 / 24.0

var 转速 := 0.0
var _角 := 0.0
var _累计 := 0.0


func _process(秒: float) -> void:
	if 转速 == 0.0 or texture == null:
		return
	_累计 += 秒
	while _累计 >= 节拍秒:
		_累计 -= 节拍秒
		_角 = fmod(_角 + 转速, 360.0)
	rotation_degrees = _角
