extends Control

# ============================================================
# 提升柔拳阶数弹窗 · 上下滑动
# ------------------------------------------------------------
# 与 写轮眼页 / 轮回六道页 的同源脚本对齐（那边注释里的两条坑这边同样成立）：
#   ① 场景里弹窗根 `visible = false` → 打开前必须先亮起来，
#      否则动画在跑、但根本看不见（2026-10-17 巡检抓到：点「提升柔拳阶数」没反应就是这个）
#   ② 「滑出」播完再隐藏，否则弹窗会停在动画终点被画到面板外面
#
# 接线：「提升柔拳阶数」按钮.pressed → open_popup()（场景 [connection]）
#       「关闭按钮」.pressed         → _on_close_button_pressed()
# ============================================================

@onready var anim_player: AnimationPlayer = $滑出动画


func _ready() -> void:
	if anim_player != null and not anim_player.animation_finished.is_connected(_滑动结束):
		anim_player.animation_finished.connect(_滑动结束)


func open_popup() -> void:
	visible = true
	if anim_player != null:
		anim_player.play("滑入")


func _on_close_button_pressed() -> void:
	if anim_player != null:
		anim_player.play("滑出")


func _滑动结束(名称: StringName) -> void:
	if String(名称) == "滑出":
		visible = false
