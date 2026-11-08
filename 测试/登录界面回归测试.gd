extends SceneTree

## 登录界面（另一位开发者做的那个登录器）回归。
##
## 为什么单开一条：**他的脚本只发信号、不碰协议**，协议那一半是融合方补的
## （`脚本/界面/登录界面.gd` 末尾「融合方补」那一段）。而现有的
## `默认账号登录回归测试` 驱动的是 `BackendConnection`、**根本不碰这个场景** ——
## 也就是说"登录按钮接没接上后端"没人守。这条补的就是那个盲区。
##
## 查四件事：
##   ① 页面装得起来、`_ready` 不报错
##   ② **注册按钮是显出来的**，且点击真的走 HTTP 注册（2026-10-09 起本地服务端有这一口）
##   ③ **页脚显示的是本项目实际的后端地址**，不是他原来写死的 `http://127.0.0.1:19280`
##   ④ **登录按钮真的接上了后端**：填好账号密码点一下，`BackendConnection` 会进入"连接中"
##      （不发真连接也行 —— 这里只验"接线通不通"，真登录由在线用例管）
##   ⑤ **选角覆盖层**：收到角色列表时，选角窗显示、登录卡片收起、
##      选角窗自带的 背景/遮罩/标题 让路（他的登录器自带视频背景）
##
## 运行：Godot --headless --path . --script res://测试/登录界面回归测试.gd

const 登录场景 := "res://场景/界面/登录界面.tscn"
## `AccountStore` 的存档（`user://launcher.json`）—— **用户的账号记忆**，用例不许动它。
const 存档路径 := "user://launcher.json"

var _失败: Array[String] = []
## 跑之前的**文件字节** + 文件本来在不在。用例结束**原样还原**。
##
## ⚠️ 为什么不用"取消记住密码"来避免写盘：那只防住一条路 ——
##    万一「记住密码」那个节点被改名/删掉，`get_node_or_null` 拿不到，
##    勾选状态就还是原样，`_on_login_pressed` 会 `remember()` 把**测试用的假账号
##    追加进用户的账号列表**。快照+还原是从机制上兜住，不依赖 UI 长什么样。
##
## ⚠️⚠️ **必须快照"文件字节"，不能快照 `AccountStore.accounts` 这个内存数组** ——
##    实测栽过：`_initialize()` 跑在 **autoload 的 `_ready()` 之前**，
##    那一刻 `AccountStore.accounts` 还是初始的空数组（读盘发生在它自己的 `_ready` 里），
##    于是"快照"记下的是空的，还回去就把**用户存好的账号整个抹了**。
##    文件字节没有加载顺序问题。
var _存档原样 := PackedByteArray()
var _存档原本存在 := false


func _initialize() -> void:
	_记账()
	call_deferred("_跑")


## 记下用户账号存档的**字节**。纯文件 I/O，不碰任何单例 —— 也就没有加载顺序问题。
func _记账() -> void:
	_存档原本存在 = FileAccess.file_exists(存档路径)
	if not _存档原本存在:
		return
	var f := FileAccess.open(存档路径, FileAccess.READ)
	if f != null:
		_存档原样 = f.get_buffer(f.get_length())


## 原样还原：存过就**逐字节写回**，本来没有就把文件删掉。
func _还原() -> void:
	if _存档原本存在:
		var f := FileAccess.open(存档路径, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_存档原样)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(存档路径))


func _跑() -> void:
	var 包 := load(登录场景) as PackedScene
	if 包 == null:
		_失败.append("登录场景加载不出来：%s" % 登录场景)
		_收尾()
		return
	var 页 := 包.instantiate()
	root.add_child(页)
	await process_frame
	await process_frame

	_查静态外观(页)
	_查登录按钮接了后端(页)
	await _查选角覆盖层(页)

	页.queue_free()
	await process_frame
	_收尾()


func _查静态外观(页: Node) -> void:
	var 注册 := 页.get_node_or_null("登录卡片/注册按钮") as Button
	if 注册 == null:
		_失败.append("找不到 登录卡片/注册按钮")
	elif not 注册.visible:
		_失败.append("注册按钮是隐藏的 —— 2026-10-09 起本地服务端有注册口"
			+ "（开发工具/GM控制台服务.py 的 /api/account/register），应当显出来")
	# 光"按钮可见"不算数（那是自证）：钉住**点击真的走 HTTP 注册**这条链还在。
	var 源 := FileAccess.get_file_as_string("res://脚本/界面/登录界面.gd")
	for 关键 in ["func _on_register_requested", "/api/account/register", "HTTPClient.METHOD_POST"]:
		if not 源.contains(关键):
			_失败.append("登录界面里找不到 `%s` —— 注册那条链被拆了" % 关键)

	var 页脚 := 页.get_node_or_null("页脚") as Label
	if 页脚 == null:
		_失败.append("找不到 页脚")
	else:
		if 页脚.text.contains("19280"):
			_失败.append("页脚还写着他那个 `19280`（Nya 2.0.8 的 HTTP 口，与本项目无关）：%s" % 页脚.text)
		if not 页脚.text.contains("18684"):
			_失败.append("页脚没显示本项目实际的后端端口 18684：%s" % 页脚.text)

	# 开局账号框**必须有内容**：用户按旧登录界面的习惯用（开箱即用）。
	# 存过账号 → 用第一条预填；没存过 → 用 settings 里的默认账号兜底。
	# ⚠️ 实测栽过一版：只在"没存过账号"时预填，于是**存过之后反而是空的**，
	#    用户看到的就是"账号丢了、要重新输入"。
	var 账号框 := 页.get_node_or_null("登录卡片/账号输入") as LineEdit
	var 密码框 := 页.get_node_or_null("登录卡片/密码输入") as LineEdit
	if 账号框 == null or 密码框 == null:
		_失败.append("找不到 登录卡片/账号输入 或 密码输入")
	elif 账号框.text.strip_edges().is_empty() or 密码框.text.is_empty():
		_失败.append("登录卡片开局是空的（账号=%s）—— 用户会以为账号丢了、要从头输" % 账号框.text)
	else:
		# ⚠ 期望值**必须现查**，不能写死某个邮箱：user:// 是按工程名分的，
		#    两份同名工程共用一份 launcher.json，谁存过什么完全看这台机器今天跑过什么
		#    （2026-10-09 实测：这条写死 `a33047518511@gmail.com`，被本机存过的 `222` 顶红）。
		# ⚠ **不能写 `get("accounts") or []`**：GDScript 的 `or` **返回 bool**（不是 Python 那种"取右值兜底"），
		#   非空数组 ⇒ `true` ⇒ `true as Array` 抛 `Invalid cast: could not convert value to 'Array'`
		#   ⇒ **这条腿连同下面的选角窗判据从来没有执行过**，而门照样绿
		#   （§3.244：收口那一趟 grep 日志里的 SCRIPT ERROR 才逮到）。
		var 存过: Array = []
		var 档 := root.get_node_or_null("AccountStore")
		if 档 != null and 档.get("accounts") is Array:
			存过 = 档.get("accounts")
		var 期望 := String((存过[0] as Dictionary).get("username", "")) if not 存过.is_empty() \
				else String(root.get_node_or_null("GameSession").get("game_settings").get("backend_account", ""))
		if 期望 != "" and 账号框.text.strip_edges() != 期望:
			_失败.append("账号框预填成 %s —— 应当预填 launcher.json 的第一条 %s" % [账号框.text, 期望])

	var 选角窗 := 页.get_node_or_null("选角窗") as Control
	if 选角窗 == null:
		_失败.append("找不到 选角窗（选角/创建角色那一步没搬进来）")
	elif 选角窗.visible:
		_失败.append("选角窗开局就该是隐藏的")
	else:
		print("  静态外观：注册按钮已隐藏、页脚=%s、选角窗已在（隐藏）" % 页脚.text)


## 真填真点 —— 只验"接线通不通"（点一下后端会进"连接中"），不等真登录。
func _查登录按钮接了后端(页: Node) -> void:
	var 后端 := root.get_node_or_null("BackendConnection")
	var 账号 := 页.get_node_or_null("登录卡片/账号输入") as LineEdit
	var 密码 := 页.get_node_or_null("登录卡片/密码输入") as LineEdit
	var 登录 := 页.get_node_or_null("登录卡片/登录按钮") as Button
	var 状态 := 页.get_node_or_null("登录卡片/状态文字") as Label
	if 后端 == null or 账号 == null or 密码 == null or 登录 == null or 状态 == null:
		_失败.append("登录卡片里的账号/密码/登录/状态节点不齐")
		return

	# ① 空表单：走他自己的校验，必须给提示、且**不发请求**
	账号.text = ""
	密码.text = ""
	登录.pressed.emit()
	if not 状态.text.contains("请输入"):
		_失败.append("空表单点登录应提示「请输入账号和密码」，实际：%s" % 状态.text)

	# ② 填好再点：后端应进入"连接中" —— 这就证明 login_requested 真的接上了 connect_backend
	后端.disconnect_backend()
	账号.text = "test_ui_only"
	密码.text = "test_ui_only"
	# ⚠️ **先取消「记住密码」** —— 勾着的话 `_on_login_pressed` 会调 `AccountStore.remember()`，
	#    把测试用的假账号**写进用户的 `user://launcher.json`**。
	#    实测踩过：第一次跑完，那个文件里就多了一条 `test_ui_only`，还会让
	#    「本机没存过账号才预填默认账号」这条兜底被跳过（`UI资源回归测试` 因此红了一次）。
	#    用例不该改用户的存档。
	var 记住 := 页.get_node_or_null("登录卡片/记住密码") as CheckBox
	if 记住 != null:
		记住.set_pressed_no_signal(false)
	登录.pressed.emit()
	if String(后端.status) != "连接中":
		_失败.append("点了登录但后端没进入「连接中」（status=%s）—— login_requested 没接到 connect_backend？"
			% 后端.status)
	else:
		print("  登录按钮：空表单给了提示、填好后端进入「连接中」 ✓")
	后端.disconnect_backend()


func _查选角覆盖层(页: Node) -> void:
	var 选角窗 := 页.get_node_or_null("选角窗") as Control
	var 卡片 := 页.get_node_or_null("登录卡片") as Control
	if 选角窗 == null or 卡片 == null:
		return
	# 直接喂一份角色列表（等价于服务端 character_list_received 到达）
	页.call("_on_character_list", [{"id": 1, "name": "测试忍者", "level": 100}], 3)
	await process_frame
	if not 选角窗.visible:
		_失败.append("收到角色列表后选角窗没显示")
	if 卡片.visible:
		_失败.append("选角时登录卡片没收起（两层表单会叠在一起）")
	for 名 in ["背景", "遮罩", "标题"]:
		var 节点 := 选角窗.get_node_or_null(名) as CanvasItem
		if 节点 != null and 节点.visible:
			_失败.append("选角窗自带的「%s」没让路 —— 它会盖住登录器的视频背景" % 名)
	print("  选角覆盖层：角色列表到达后选角窗显示、登录卡片收起、自带背景已让路 ✓")


func _收尾() -> void:
	_还原()   # 先还原用户存档，再报结果 —— 用例失败也不能留下脏数据
	if _失败.is_empty():
		print("登录界面回归测试：通过（注册按钮隐藏 / 页脚地址 / 登录接后端 / 选角覆盖层）")
		quit(0)
		return
	for 项 in _失败:
		push_error("登录界面回归测试：失败 - %s" % 项)
	print("登录界面回归测试：失败 %d 条" % _失败.size())
	quit(1)
