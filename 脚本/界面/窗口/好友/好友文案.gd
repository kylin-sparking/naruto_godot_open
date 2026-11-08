class_name 好友文案
extends RefCounted

## 好友系窗口的文案取值口（`数据/界面/好友_文案.json`，由 `开发工具/出好友文案数据.py` 从
## AS3 语言表抽，带行号出处）。三扇子窗各自 extends 家族子窗.gd，没有共同的自定义基类，
## 所以文案表放这里用静态函数共享，避免每扇窗各读一遍文件。

const 文件 := "res://数据/界面/好友_文案.json"
static var _表: Dictionary = {}


static func 取(键: String) -> String:
	if _表.is_empty():
		var 取回: Variant = JSON.parse_string(FileAccess.get_file_as_string(文件))
		_表 = 取回 if typeof(取回) == TYPE_DICTIONARY else {}
	var 条: Dictionary = _表.get(键, {})
	if 条.is_empty():
		push_error("好友文案缺键：%s（跑 开发工具/出好友文案数据.py）" % 键)
		return ""
	return String(条["文"])
