extends RefCounted

## 「原版服务窗」通用控制器 —— 忍具兑换 / 十拳剑兑换 / 洗点 / 生命料理 … 这一族小窗。
##
## 为什么可以共用一个控制器：这批窗的**版式与文案全在 `.tscn` 里**（由 `开发工具/原版服务窗.py`
## 从 SPEC 生成，SPEC 里每条都带 AS3 行号），运行期只剩两件事：
##   ① 钮的三档皮已在场景里（`theme_override_styles/normal|hover|pressed`）⇒ 不许再用
##      `texture_hover` / `modulate`（`StyleUtil.as:8-12` 是**加性** ±30/−40，乘性模拟不出来）；
##   ② 点钮要发的协议本工程**一条都没接** ⇒ 只照原版给一句状态行（口径同 精英副本页）。
##
## 用法（宿主 = `功能窗口`）：`原版服务窗.渲染(self, 场景, {"兑换钮": "兑换要 …"})`

## 点钮的提示：原版这些动作都走**服务端**（`ITEM_DATAS_CHANGED` / 各自的操作码），
## 本工程没接 ⇒ 只回显，不改状态。表由调用方给（每扇窗的动作不同，别在这儿写死）。
## `动作` 是**按钮名给真处理器**的可选表（`{"兑换钮": 某个 Callable}`）——
## 有真协议的那几枚走它，其余的照旧只回显状态行。第一版全接回显，于是
## 「兑换忍具/兑换十拳剑」这两枚明明服务端有（`RENJU 2082` 动作 3），却被写成"未接（待点头）"。
static func 渲染(宿主: Node, 场景: PackedScene, 提示: Dictionary = {}, 动作: Dictionary = {}) -> Control:
	var 页: Control = 场景.instantiate() as Control
	宿主._content.add_child(页)
	_接钮(宿主, 页, 提示, 动作)
	return 页


## 递归找所有 Button：只**核对**交互面（手型、三档皮都在），点击接到状态行或真处理器。
static func _接钮(宿主: Node, 节: Node, 提示: Dictionary, 动作: Dictionary = {}) -> void:
	for c in 节.get_children():
		if c is Button:
			var 钮 := c as Button
			# 原版 `MButton3.init():135` = `buttonMode = useHandCursor = true`
			if 钮.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
				宿主._show_hint("内部错误：%s 没设手型（量具应该已经把它钉住了）" % 钮.name)
			if 动作.has(钮.name):
				钮.pressed.connect(动作[钮.name] as Callable)
			else:
				钮.pressed.connect(_点钮.bind(宿主, 提示.get(钮.name, "")))
		_接钮(宿主, c, 提示, 动作)


static func _点钮(宿主: Node, 文本: String) -> void:
	宿主._show_hint(文本 if not 文本.is_empty() else "该动作的协议未接（待点头）")
