extends AnimatedSprite2D
## 紫/橙两档装备（还有背包里的灵气装）图标上那圈呼吸流光。
##
## 原版是 `new EquipAnimationF()` 直接 addChild 到格子上
## （`ItemWindowCell.showIcon` :259-265 / `EquipmentWindowCell.showIcon` :138-143），
## 符号时间轴走到第 49 帧用 `gotoAndPlay(17)` 跳回循环段。
## Godot 这边把同一条时间轴切成两段动画：「进场」1..16 不循环，
## 播完接「默认」17..49 循环 —— 帧数据和跳转都照原轴，见 `数据/装备品质.json` 的「流光」。
##
## 谁挂它：`脚本/单例/装备品质.gd` 的 `挂覆盖层`（格子、列表行、提示框共用一条路）。
## 场景里的两个格子（`物品格.tscn` / `装备格.tscn`）默认 `visible = false`：
## 空格子任何时候都不该有流光，编辑器里看到的就和运行时的空格子一致。
##
## ⚠️ **段切换不能只靠 `animation_finished`** —— 2026-10-01 实测（最小复现）：
##    非循环动画走到末帧时 `animation_finished` 触发的是**零参信号**，而 `_段播完` 声明了
##    1 个参数 → 每次触发都报 `Method expected 1 argument(s), but called with 0`，段切换从未发生
##    ——流光永远停在进场段最后一帧（用户报的"转几下就卡住"）。
##    ⚠️ 这类"信号在发、桥接报错被吞"的事故**只有把 stderr 原样看全才会现形**——
##    第一次排查时我把错误行 grep 掉了，误判成"信号根本没发"。
##    所以 `_process` 里轮询兜底：进场到达最后一帧且还没切段 ⇒ 立刻接「默认」。
##    信号那路保留（哪天引擎修好了它先到，轮询的 `动画名=="进场"` 守卫自然失效，无害）。

## 帧图集由调用方给（全项目共享一份，见 `装备品质.流光帧集()`）。
## `强制=true`：无视幂等直接重播（换物品的 `showIcon` 语义，由 `装备品质.挂流光` 传）。
## ⚠️ 幂等比较的**绝不能是"同一套共享帧集"**——帧集是全局缓存、所有紫装共用一份！
##    上一版把它当身份用，害得"换一件装也不重播"。身份判断在 `挂流光`，这里只管帧集级幂等。
func 播(帧集: SpriteFrames, 强制 := false) -> void:
	if 帧集 == null:
		停()
		return
	# ⚠️ 幂等：**同一套帧集在播着就绝不重播**。调用方（渲染循环）每次重渲染都会到这里，
	#    不幂等就"每刷新一次闪回开头"（用户 2026-10-01"不连贯"根因之一）。
	if not 强制 and sprite_frames == 帧集 and visible and (is_playing() or animation == "默认"):
		return
	sprite_frames = 帧集
	if not animation_finished.is_connected(_段播完):
		animation_finished.connect(_段播完)
	visible = true
	set_process(true)
	# 每次重新起播都从头走一遍进场段 —— 原版 `showIcon` 每次重建 MovieClip，效果一样。
	play("进场")


func 停() -> void:
	stop()
	visible = false


## Godot 4 的 `animation_finished` 是**零参**信号（3.x 才带动画名）——签名别照 3.x 抄。
func _段播完() -> void:
	_切默认段()

## 幂等：切过之后动画名不再是"进场"，`_process` 每帧再调也直接返回。
func _切默认段() -> void:
	if animation == "进场" and sprite_frames != null:
		play("默认")

func _process(_delta: float) -> void:
	if not visible or sprite_frames == null or animation != "进场":
		return
	if frame >= sprite_frames.get_frame_count("进场") - 1 and not is_playing():
		_切默认段()
