extends Node2D
## 十拳剑灵器外观（须佐能乎）的**人物叠加层**。
##
## 原版真值全在 `CharacterSprite.as`：
##   · `lingQiFace` setter（:402-408）→ `_skinLingQiObj = ImgUtil.getImg(M_Char, face)`；
##   · `reanderLingQi`（:486-528）：每帧读**身体自己的** `_action` / `_frame`，
##     从灵器那套美术取 `[动作名][帧号].body` 的贴图与自己的 origin；
##     缺这一帧时**保留上一张**；`ciAfterImage.alpha = 0.7`；
##   · `getLingQiColorTransform`：id<=0 不套颜色，否则
##     `ColorTransform(redMul, greenMul, blueMul, **1**, rOff, gOff, bOff, 0)`；
##   · 五个特效的常量在 `updateLingQiEffectMotion`（:870-1020）。
##
## ⚠ 方向：原版 `CharacterSprite` 用 `scaleX = ±1` 翻；这里把整层放进 `容器` 跟着翻，
##   灵器帧自己的 origin 与身体的 origin 可能不同（`:500` 读的是灵器帧的 origin），
##   所以不能把身体 `sprite.position` 抄给灵器 —— 只抄动作/帧/朝向。
##
## ⚠ 特效开关是**客户端静态值**（原版 `UIConfig.lingQiEffect*Enabled`），
##   不落存档、不发服务端；窗口关掉后地图上这具人物仍然按当前静态值播。

const 外观数据 := preload("res://脚本/单例/灵器外观数据.gd")
const 颜色着色器 := preload("res://脚本/角色/灵器颜色.gdshader")
const 辉光着色器 := preload("res://脚本/角色/灵器辉光.gdshader")
const 流光着色器 := preload("res://脚本/角色/灵器流光.gdshader")

const 基色透明度 := 0.7        ## `reanderLingQi` 的 `ciAfterImage.alpha = 0.7`
const 扫光速度 := 0.06         ## `lingQiSweep.x += param1 * 0.06`（param1 = 毫秒）
const 星数 := 6

var 身体: OriginalSprite = null

var 容器: Node2D = null
var 底: OriginalSprite = null
var 辉光: Sprite2D = null
var 雾: Sprite2D = null
var 流光: Sprite2D = null
var 星闪: Node2D = null
var 星: Array[Sprite2D] = []

var _脸 := -1
var _色 := -1
var _时间 := 0.0
var _扫光进度 := 0.0
var _宽 := 0.0
var _高 := 0.0
var _星尺寸 := Vector2.ZERO
var _星已初始化 := false
var _随机 := RandomNumberGenerator.new()
var _已建 := false

static var _雾纹理缓存: Texture2D = null
static var _星纹理缓存: Texture2D = null


func _ready() -> void:
	_建()


func 绑定(源: OriginalSprite) -> void:
	身体 = 源


## 从 GameSession 的权威属性取 `lingFace` / `lingQiColor`。
func 刷新() -> void:
	if not is_inside_tree():
		return
	var 会话 := get_node_or_null("/root/GameSession")
	if 会话 == null:
		return
	var 身: Dictionary = 会话.call("自身外观")
	设外观(int(身.get("lingFace", 0)), int(身.get("lingQiColor", 0)))


func 设外观(脸号: int, 颜色号: int) -> void:
	_建()
	var 脸变了 := 脸号 != _脸
	_脸 = 脸号
	_色 = 颜色号
	if 脸号 <= 0:
		visible = false
		return
	if 脸变了 or 底 == null or 底.actions.is_empty():
		var 号 := str(脸号).pad_zeros(8)
		if not OriginalSprite.has_animation("character", 号):
			# 原版 `_waitAfterimageRes = true` + 替换图等待；本工程四套 Susanoo 都在，
			# 查不到就**不拿别的美术冒充**，保持隐藏。
			visible = false
			return
		if not 底.configure("character", 号, "stand"):
			visible = false
			return
		_星已初始化 = false
	_应用颜色()
	visible = true


func _建() -> void:
	if _已建:
		return
	_已建 = true
	_随机.randomize()
	容器 = Node2D.new()
	容器.name = "朝向"
	add_child(容器)

	# 原版子层顺序（`:700-730` 的 addChildAt 推出来的最终次序）：
	#   辉光（最后插、画在最底）→ 雾 → 残影 → 流光 → 星闪（后加的在上面）。
	辉光 = Sprite2D.new()
	辉光.name = "辉光"
	辉光.centered = false
	var 辉光材 := ShaderMaterial.new()
	辉光材.shader = 辉光着色器
	辉光.material = 辉光材
	容器.add_child(辉光)

	雾 = Sprite2D.new()
	雾.name = "雾"
	雾.centered = false
	雾.texture = _雾纹理()
	容器.add_child(雾)

	底 = OriginalSprite.new()
	底.name = "残影"
	容器.add_child(底)

	流光 = Sprite2D.new()
	流光.name = "流光"
	流光.centered = false
	var 流光材 := ShaderMaterial.new()
	流光材.shader = 流光着色器
	流光.material = 流光材
	容器.add_child(流光)

	星闪 = Node2D.new()
	星闪.name = "星闪"
	容器.add_child(星闪)
	星.clear()
	for _i in 星数:
		var 点 := Sprite2D.new()
		点.centered = true
		点.texture = _星纹理()
		var 点材 := CanvasItemMaterial.new()
		点材.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		点.material = 点材
		星闪.add_child(点)
		星.append(点)
	visible = false


func _应用颜色() -> void:
	if 底 == null or 底.sprite == null:
		return
	var 变换 := 外观数据.颜色变换(_色)
	var 材 := 底.sprite.material as ShaderMaterial
	if 材 == null:
		材 = ShaderMaterial.new()
		材.shader = 颜色着色器
		底.sprite.material = 材
	材.set_shader_parameter("tint_mul", Vector3(float(变换["r"]), float(变换["g"]), float(变换["b"])))
	材.set_shader_parameter("tint_add", Vector3(float(变换["ro"]), float(变换["go"]), float(变换["bo"])))
	材.set_shader_parameter("base_alpha", 1.0)
	if 辉光 != null:
		var 辉光材 := 辉光.material as ShaderMaterial
		var 暖 := Vector3(1.0, 0.86, 0.72)
		var 乘 := Vector3(float(变换["r"]), float(变换["g"]), float(变换["b"]))
		var 加 := Vector3(float(变换["ro"]), float(变换["go"]), float(变换["bo"]))
		var 色 := 暖 * 乘 + 加
		色 = Vector3(clampf(色.x, 0.0, 1.0), clampf(色.y, 0.0, 1.0), clampf(色.z, 0.0, 1.0))
		辉光材.set_shader_parameter("glow_color", 色)


func _process(delta: float) -> void:
	if not visible or 底 == null or 底.sprite == null:
		return
	if 身体 == null or not is_instance_valid(身体) or 身体.sprite == null:
		return
	if 身体.sprite.texture == null:
		return
	# 动作/帧跟身体；灵器那套缺这一帧 ⇒ 保留上一张（原版同一语义）。
	底.显示帧(str(身体.action), int(身体.frame_index))
	容器.scale.x = -1.0 if 身体.scale.x < 0.0 else 1.0

	var 纹理 := 底.sprite.texture
	if 纹理 == null:
		return
	var 尺寸 := Vector2(纹理.get_size())
	if 尺寸 != _星尺寸:
		_星尺寸 = 尺寸
		_宽 = 尺寸.x
		_高 = 尺寸.y
		_星已初始化 = false

	var 呼吸 := 外观数据.呼吸明暗
	var 外辉 := 外观数据.外发辉光
	var 流光开 := 外观数据.斜向流光
	var 星闪开 := 外观数据.边缘星闪
	var 雾开 := 外观数据.雾化底辉
	if not 外观数据.任意启用():
		_底常态()
		_藏特效()
		return

	_时间 += delta * 1000.0 * 0.006
	var p := (sin(_时间) + 1.0) * 0.5
	var q := (cos(_时间 * 1.3) + 1.0) * 0.5
	var r := (sin(_时间 * 1.8) + 1.0) * 0.5

	# 呼吸明暗：alpha 0.54+p*0.2、scale 1+p*0.025；不开则回到 0.7 / 1。
	if 呼吸:
		底.sprite.self_modulate.a = 0.54 + p * 0.2
		底.scale = Vector2.ONE * (1.0 + p * 0.025)
	else:
		底.sprite.self_modulate.a = 基色透明度
		底.scale = Vector2.ONE

	# 外发辉光：alpha 0.12+q*0.26、scale 1.02+p*0.06。
	辉光.visible = 外辉
	if 外辉:
		辉光.texture = 纹理
		辉光.position = 底.sprite.position
		辉光.scale = Vector2.ONE * (1.02 + p * 0.06)
		var 辉光材 := 辉光.material as ShaderMaterial
		辉光材.set_shader_parameter("glow_alpha", 0.12 + q * 0.26)
		辉光材.set_shader_parameter("blur_radius", 4.0 + p * 2.0)

	# 雾化底辉：alpha 0.1+q*0.12、scale 0.96+p*0.08 / 0.92+r*0.08。
	雾.visible = 雾开
	if 雾开:
		var 雾纹理 := _雾纹理()
		# `drawLingQiMist(w,h,-originX,-originY)`：椭圆是 (x-0.06w, y+0.36h, 1.12w, 0.36h)。
		雾.position = 底.sprite.position + Vector2(-_宽 * 0.06, _高 * 0.36)
		var 基础 := Vector2(_宽 * 1.12 / float(雾纹理.get_width()), _高 * 0.36 / float(雾纹理.get_height()))
		雾.scale = Vector2(基础.x * (0.96 + p * 0.08), 基础.y * (0.92 + r * 0.08))
		雾.self_modulate.a = 0.1 + q * 0.12

	# 斜向流光：每毫秒 0.06px，区间 = 宽 + 带宽*1.65（带宽 = max(10, 宽*0.42)）。
	流光.visible = 流光开
	流光.texture = 纹理
	流光.position = 底.sprite.position
	if 流光开:
		var 带宽 := maxf(10.0, _宽 * 0.42)
		_扫光进度 += delta * 1000.0 * 扫光速度 / maxf(1.0, _宽 + 带宽 * 1.65)
		if _扫光进度 > 1.0:
			_扫光进度 -= floorf(_扫光进度)
		var 流光材 := 流光.material as ShaderMaterial
		流光材.set_shader_parameter("phase", _扫光进度)
		流光材.set_shader_parameter("sprite_size", Vector2(_宽, _高))
		流光材.set_shader_parameter("strength", 0.38 + p * 0.18)
	else:
		_扫光进度 = 0.0

	# 边缘星闪：6 枚白色十字，screen 混合；alpha *= 0.92、scale *= 0.988。
	星闪.visible = 星闪开
	if 星闪开:
		星闪.position = 底.sprite.position
		if not _星已初始化:
			for i in 星.size():
				_重置星(i, true)
			_星已初始化 = true
		for i in 星.size():
			var 点 := 星[i]
			点.self_modulate.a *= 0.92
			点.scale = 点.scale * 0.988
			if 点.scale.x < 0.6:
				点.scale = Vector2.ONE * 0.6
			if 点.self_modulate.a < 0.08 and _随机.randf() > 0.86 - r * 0.1:
				_重置星(i, false)


func _底常态() -> void:
	if 底 == null:
		return
	底.sprite.self_modulate.a = 基色透明度
	底.scale = Vector2.ONE


func _藏特效() -> void:
	if 辉光 != null:
		辉光.visible = false
	if 雾 != null:
		雾.visible = false
	if 流光 != null:
		流光.visible = false
	if 星闪 != null:
		星闪.visible = false
	_扫光进度 = 0.0


func _重置星(序号: int, 初始: bool) -> void:
	if 序号 < 0 or 序号 >= 星.size():
		return
	var 点 := 星[序号]
	var 边 := int(_随机.randf() * 4.0)
	var x := 2.0 + _随机.randf() * maxf(6.0, _宽 - 4.0)
	var y := 2.0 + _随机.randf() * maxf(6.0, _高 - 4.0)
	if 边 == 0:
		点.position = Vector2(x, 1.0 + _随机.randf() * 4.0)
	elif 边 == 1:
		点.position = Vector2(x, _高 - 1.0 - _随机.randf() * 4.0)
	elif 边 == 2:
		点.position = Vector2(1.0 + _随机.randf() * 4.0, y)
	else:
		点.position = Vector2(_宽 - 1.0 - _随机.randf() * 4.0, y)
	点.self_modulate.a = (0.1 + _随机.randf() * 0.14) if 初始 else (0.34 + _随机.randf() * 0.46)
	点.scale = Vector2.ONE * (0.7 + _随机.randf() * 0.8)
	点.rotation = _随机.randf() * 180.0


static func _雾纹理() -> Texture2D:
	if _雾纹理缓存 != null:
		return _雾纹理缓存
	var 渐变 := Gradient.new()
	渐变.offsets = PackedFloat32Array([0.0, 150.0 / 255.0, 1.0])
	渐变.colors = PackedColorArray([
		Color8(255, 247, 204, 61),      # 16775116 #FFF7CC，alpha 0.24
		Color8(255, 207, 194, 26),      # 16764866 #FFCFC2，alpha 0.10
		Color8(255, 128, 0, 0),         # 16744448 #FF8000，alpha 0
	])
	var 纹 := GradientTexture2D.new()
	纹.gradient = 渐变
	纹.fill = GradientTexture2D.FILL_RADIAL
	纹.fill_from = Vector2(0.5, 0.5)
	纹.fill_to = Vector2(1.0, 0.5)
	纹.width = 64
	纹.height = 64
	_雾纹理缓存 = 纹
	return 纹


static func _星纹理() -> Texture2D:
	if _星纹理缓存 != null:
		return _星纹理缓存
	var 图 := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	图.fill(Color(0, 0, 0, 0))
	for i in 9:
		图.set_pixel(i, 4, Color.WHITE)
		图.set_pixel(4, i, Color.WHITE)
	_星纹理缓存 = ImageTexture.create_from_image(图)
	return _星纹理缓存
