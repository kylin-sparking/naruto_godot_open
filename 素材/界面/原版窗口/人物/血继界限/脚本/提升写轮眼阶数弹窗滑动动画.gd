extends Control

# ============================================================
# 提升写轮眼阶数弹窗 · 上下滑动
# ------------------------------------------------------------
# 与 柔拳页 的「提升柔拳阶数弹窗滑动动画.gd」**同源**，只多了两件事：
#   ① 本页的弹窗默认 `visible = false`（三页统一：场景根上都要写 visible=false，运行时靠本脚本亮/灭）
#      → 打开前必须先亮起来，否则动画在跑、但根本看不见
#   ② 「滑出」播完再隐藏，否则弹窗会停在动画终点（y = 700）
#      被画到面板外面去
#
# ★ 为什么这份单独放在 血继界限/脚本/ 下：
#     这个写轮眼页是**要单独打包发走**的，不能依赖 柔拳/ 目录里的文件。
#     场景里「提升写轮眼阶数弹窗」节点的 script 必须指向 **本文件**。
#
# 接线（与柔拳页一致，写在场景的 [connection] 里）：
#     「提升写轮眼阶数」按钮.pressed → 本脚本 open_popup()
#     「关闭按钮」.pressed           → 本脚本 _on_close_button_pressed()
#   ★ 另外 `写轮眼切换_修正版.gd::_接线提升阶数弹窗()` 还有一层运行时兜底，
#     万一场景里的连接丢了也能用（它会先判断有没有重复连接）。
# ============================================================

@onready var 滑出动画: AnimationPlayer = $滑出动画


func _ready() -> void:
	if 滑出动画 != null and not 滑出动画.animation_finished.is_connected(_滑动结束):
		滑出动画.animation_finished.connect(_滑动结束)


func open_popup() -> void:
	visible = true                     # 本页弹窗默认隐藏，先亮起来动画才看得见
	if 滑出动画 != null:
		滑出动画.play("滑入")


func _on_close_button_pressed() -> void:
	if 滑出动画 != null:
		滑出动画.play("滑出")


func _滑动结束(名称: StringName) -> void:
	# 「滑出」跳完才真正隐藏 —— 否则它会停在动画终点被画到面板外面
	if String(名称) == "滑出":
		visible = false
