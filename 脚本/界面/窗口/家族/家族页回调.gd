extends RefCounted
## 家族各内容页往**单例信号**（后端/会话）上挂回调的公用钩子。
##
## 为什么单开一个文件：家族那几个填充脚本都被 `家族子窗壳.gd` preload 着，钩子不能
## 放回壳里 —— 那会形成循环 preload。这里不依赖任何家族脚本，谁都能 preload。
##
## 要解决的毛病：内容页是**随窗收掉就释放**的，而它挂的回调捕获了 `页`/`宿主`。
## 窗一关，单例信号每次广播都会报
##     `Lambda capture at index 0 was freed. Passed "null" instead.`
## （实测：退出家族 → 重建那一段回包能连刷十几条，全是这个）。
## 所以它顺手在 `tree_exiting` 上断开自己。

static func 挂(页: Control, 源信号: Signal, 回调: Callable) -> void:
	if 页 == null or 源信号.is_connected(回调):
		return
	源信号.connect(回调)
	页.tree_exiting.connect(func() -> void:
		if 源信号.is_connected(回调):
			源信号.disconnect(回调)
	)
