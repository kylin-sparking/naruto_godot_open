extends SceneTree

## 紫/橙装的**流光必须一直在转**：进场段（非循环）走完要接上「默认」循环段。
##
## ⚠️ 用户 2026-10-01 报"转几下就停了卡住"。根因：**本工程里非循环动画播到末帧后
##   `animation_finished` 根本不发**（最小复现验过）——只挂信号的旧实现永远停在进场最后一帧。
##   现在 `_process` 轮询兜底。这条门用**占位纹理**搭同款两段帧集，不依赖素材。
const 流光类 := preload("res://脚本/界面/组件/品质流光.gd")
const 品质 := preload("res://脚本/单例/装备品质.gd")

var _失败: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _帧集() -> SpriteFrames:
	var 帧 := SpriteFrames.new()
	帧.remove_animation("default")
	帧.add_animation("进场"); 帧.set_animation_loop("进场", false); 帧.set_animation_speed("进场", 14.0)
	帧.add_animation("默认"); 帧.set_animation_loop("默认", true); 帧.set_animation_speed("默认", 14.0)
	for i in 6:
		帧.add_frame("进场", PlaceholderTexture2D.new())
	for i in 12:
		帧.add_frame("默认", PlaceholderTexture2D.new())
	return 帧

func _run() -> void:
	# ⚠️ 帧集要**同一份实例**反复喂——运行时走的是 `装备品质.流光帧集()` 的全局缓存，
	# 幂等判断比的就是"同一份 SpriteFrames"。这里自造两份会误判成"换了动画"。
	var 帧集 := _帧集()
	var 节点 := 流光类.new() as AnimatedSprite2D
	root.add_child(节点)
	节点.call("播", 帧集)
	_check(节点.visible and String(节点.animation) == "进场", "起播应在进场段")
	# 等轮询兜底把段切过去：帧率未知，按**真实时间**等（最多 3 秒），不按帧数赌
	var 到 := 0.0
	while String(节点.animation) != "默认" and 到 < 3.0:
		await process_frame
		到 += float(节点.get_process_delta_time())
	_check(String(节点.animation) == "默认", "进场播完必须接上默认段（卡在 %s）" % 节点.animation)
	await process_frame
	_check(节点.is_playing(), "默认段应在持续播放（不卡死）")
	# 幂等：重渲染会再调 `播`——**已在默认段播着就不许回头重播**（用户"不连贯"的根因之二）
	var 切段前帧 := 节点.frame
	节点.call("播", 帧集)
	await process_frame
	_check(String(节点.animation) == "默认", "播 重入不该把已进默认段的流光打回进场")
	节点.call("停")
	_check(not 节点.visible, "停 之后要不可见")
	# —— ② 经 `挂覆盖层` 的真实链路：**同一件物品重渲染不许回头；换物品才重播**。
	# （用户 2026-10-01："转一半就跳回开头"——根因是调用方"先清再设"+上一轮幂等放错了层，
	#  去重必须做在 `挂流光` 的身份判断上。）
	var 宿主 := Control.new()
	root.add_child(宿主)
	var 紫装 := {"id": "01010099", "aptitude": 4}
	品质.挂覆盖层(宿主, 紫装)
	await process_frame
	var 灯 := 宿主.get_node_or_null("流光") as AnimatedSprite2D
	_check(灯 != null and 灯.visible and 灯.is_playing(), "紫装挂上后流光应在播")
	# 先等它真的转进"默认"段（headless 的 delta 很小，按真实时间等，别按帧数赌）
	var 到2 := 0.0
	while String(灯.animation) != "默认" and 到2 < 3.0:
		await process_frame
		到2 += float(灯.get_process_delta_time())
	var 已转帧 := 灯.frame
	品质.挂覆盖层(宿主, 紫装)        # 同一件物品再渲染一遍
	await process_frame
	_check(灯.frame >= 已转帧 and String(灯.animation) == "默认",
			"同物品重挂不应回头（前 %d 帧、后 %d 帧、%s）" % [已转帧, 灯.frame, 灯.animation])
	品质.挂覆盖层(宿主, {"id": "01010088", "aptitude": 4})   # 换一件
	await process_frame
	_check(String(灯.animation) == "进场", "换物品应重播（原版 showIcon 就是重建一条）")
	品质.挂覆盖层(宿主, {})          # 清空
	await process_frame
	_check(not 灯.visible, "清空后流光要停")
	宿主.queue_free()
	await process_frame

	if _失败.is_empty():
		print("品质流光回归测试：通过（两段：段切换 + 咽喉幂等）")
		quit(0)
		return
	for 项 in _失败:
		printerr("品质流光回归测试：" + 项)
	quit(1)

func _check(ok: bool, 话: String) -> void:
	if not ok:
		_失败.append(话)
