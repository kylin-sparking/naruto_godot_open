extends Control
## 交易窗里的宠物格 = 原版 `TradeWindowPetCell`（`controls/cell/TradeWindowPetCell.as`）。
## 版式逐件出处见 `真值/窗口/交易与邀请托盘.md` §③。几何全烘在 `宠物格.tscn`。
##
## 两张图是**互斥**的（`:110-111` 空态、`:55-56` 有宠态）：
## 空着 = 露「可交易宠物」占位图、隐格底；有宠 = 反过来，再把 40×40 头像叠在格底正中。

## 点头像/格底看宠物详情。原版是那颗「查看」钮（`:122-125`），格底本身不响应单击。
signal 要看宠物(宠: Dictionary)

## `PetAptitude` 那两张表（名 / 色）不在这里抄第二份 ——
## 已在 `脚本/角色/宠物数值.gd`（尾兽档的颜色判定也在那边）。
const 数值 := preload("res://脚本/角色/宠物数值.gd")
const 原画 := preload("res://脚本/角色/原始动画精灵.gd")

@onready var _空图: TextureRect = $空宠图
@onready var _格底: TextureRect = $有宠图
@onready var _头像: TextureRect = $有宠图/头像
@onready var 名字: Label = $名字
@onready var _查看: Button = $查看钮

var 宠: Dictionary = {}


func _ready() -> void:
	_查看.pressed.connect(func() -> void: 要看宠物.emit(宠))
	_查看.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## `setCellValue`（`:47-66`）：`名(资质名)` + 资质色；空字典 = `removeData`（`:68-85`）。
func 填(件: Dictionary) -> void:
	宠 = 件
	if 件.is_empty():
		_空图.visible = true
		_格底.visible = false
		名字.text = ""
		_查看.visible = false
		return
	_空图.visible = false
	_格底.visible = true
	_头像.texture = _头像图(String(件.get("id", "")))
	# `:62-63` 文字 = `名(资质名)`、色 = `PetAptitude.getApitudeColor(aptitude)`
	名字.text = "%s(%s)" % [String(件.get("name", "")), 数值.品质名_of(int(件.get("aptitude", 1)))]
	名字.add_theme_color_override("font_color", 数值.品质色_of(int(件.get("aptitude", 1))))
	_查看.visible = true


static func 资质名(资质: int) -> String:
	## 门与别的页要拿同一个名字时用这一条，别各自拼（表只有 `宠物数值` 那一份）。
	return 数值.品质名_of(资质)


func _头像图(宠物id: String) -> Texture2D:
	return 原画.portrait("pet", 宠物id)
