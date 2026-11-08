extends Control

# 打开弹窗（供外部按钮调用）
func open_popup():
	show()
	# 如果以后做好了滑入动画，把下面这行的注释去掉：
	# $AnimationPlayer.play("滑入")

# 关闭按钮按下的回调函数（信号已经连上了）
func _on_close_button_pressed():
	# 如果以后做好了滑出动画，把下面这两行的注释去掉：
	# $AnimationPlayer.play("滑出")
	# await $AnimationPlayer.animation_finished
	
	hide()


func _on_关闭按钮_pressed() -> void:
	pass # Replace with function body.
