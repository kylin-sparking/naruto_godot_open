extends SceneTree

## 源码健全性回归：**源码里不许留注入/模板断裂的残渣**。
##
## 为什么要有它（2026-10-09，§3.99）：
##   `服务端/runtime/tools/fake_flash_server.py` 的昆虫强化守卫里，原本写着这么一句
##   （从原始分发一路带进来的，2.2.3 那份 `:54138` 与一份 2026-08-12 的备份里都有）：
##
##       self._send_system_chat("''' + os.environ['M6'] + '''")
##
##   这是"有人把代码用**单引号断链**模板注进源码"的残留 —— 外层是**双引号**，所以它没被执行，
##   只是一段字面量；可它是**玩家看得见的**：人物窗「寄坏强化」在没有选中昆虫时会把它当提示打出来。
##   ⇒ 危害不在"执行"，在**它证明这条流水线上有人往里塞过代码**，而且**没有一道门看得见**。
##
## 本门查两件事：
##   ① **注入指纹**：`os.environ[`（下标式，服务端合法的都是 `os.environ.get`）、
##      模板断裂残留 `''' +` / `""" +`、`__import__(` —— 服务端与客户端全树扫一遍；
##   ② **修好的东西别再坏**：昆虫强化那条守卫必须是**中文原文**
##      （`请放入昆虫` / `很抱歉，该物品不是昆虫不能强化！`，取自客户端语言表
##      `KUNCHONG_STRENGTH_PROMPT` / `KUNCHONG_STRENGTH_NOT_KUNCHONG`）。
##
## 运行：Godot --headless --path . --script res://测试/源码健全性回归测试.gd

const 服务端 := "res://服务端/runtime/tools/fake_flash_server.py"
const 脚本目录 := "res://脚本"

## 指纹 → 说明。**只列确定有问题的形状**，别把合法的 `os.environ.get` 也算进来。
const 指纹 := {
	"os.environ[": "下标式读环境变量（服务端合法的写法一律是 os.environ.get）",
	"''' +": "模板断裂残留（用单引号断链注入过代码）",
	'""" +': "模板断裂残留（用三引号断链注入过代码）",
	"__import__(": "动态导入（服务端不用它；开发工具里的加载器不在本门扫描范围）",
}

var _失败: Array[String] = []


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 文件清单: Array[String] = [服务端]
	收集(脚本目录, 文件清单)
	_check(文件清单.size() > 1, "扫到的文件太少（%d）—— 路径是不是写错了" % 文件清单.size())

	for 路径 in 文件清单:
		var 文本 := FileAccess.get_file_as_string(路径)
		if 文本.is_empty():
			_失败.append("读不到 %s" % 路径)
			continue
		var 行号 := 0
		for 行 in 文本.split("\n"):
			行号 += 1
			for 标记 in 指纹:
				if 行.contains(标记):
					_失败.append("%s:%d 命中注入指纹 `%s` —— %s\n      %s"
						% [路径.get_file(), 行号, 标记, 指纹[标记], 行.strip_edges()])

	# ② 修好的那条守卫必须是中文原文（见文件头）。
	var 服务端文本 := FileAccess.get_file_as_string(服务端)
	_check(服务端文本.contains("请放入昆虫"),
		"昆虫强化那条守卫的原文没了（应当是 `请放入昆虫` / `很抱歉，该物品不是昆虫不能强化！`）")

	# ③ 秘笈合成的成功率必须**读表**，不许改回写死（§3.101）。
	#    为什么用文本钉：回帧只有成功/失败，**概率在线观测不到** —— 这条回归只能在源码层守。
	_check(服务端文本.contains("base_probability = _authored_probability"),
		"秘笈合成的成功率又写死了（应当是 `base_probability = _authored_probability`，"
		+ "读 `Etc.CanJuanHeCheng.prob`；写死会让客户端显示的几率与实掷的那套对不上）")

	# ④ **场景里没有非法浮点**（`offset_left = 350.0.0` 这种**两个小数点**的值）。
	#    §3.149 逮到的：`开发工具/生成灵器炼制场景.py` 的模板写 `{x}.0`，而传进来的 `x`
	#    **本来就是 float**（`350.0`）⇒ 拼出 `350.0.0`；Godot 解析不了 ⇒ **材料格整体落不到位**。
	#    ⚠️ 它**一路躲过了所有几何门**（那扇窗压根没有几何门），最后是靠**用户给的原版截图并排**
	#    才照出来的 ⇒ 补一条全 `场景/` 的 tripwire，别再靠人眼。
	var 场景清单: Array[String] = []
	收集("res://场景", 场景清单, ".tscn")
	_check(场景清单.size() > 10, "扫到的场景太少（%d）—— 路径是不是写错了" % 场景清单.size())
	for 路径 in 场景清单:
		var 行号 := 0
		for 行 in FileAccess.get_file_as_string(路径).split(char(10)):
			行号 += 1
			if 行.strip_edges().begins_with(";"):
				continue		# 注释行不算（里面常有 `39..255` 这种范围写法）
			var 段 := 行.split("=")
			if 段.size() != 2:
				continue
			var 值 := String(段[1]).strip_edges()
			# 非法浮点 = 像 `350.0.0`：>1 个小数点、又不带 `,`/`(`（那两个是 Vector2/Color 的正常写法）
			# 形状要**只由数字/点/负号**组成（如 350.0.0）—— 否则带编号的富文本那种会误报。
			var 裸 := 值.replace(".", "").replace("-", "").replace(" ", "")
			if 值.count(".") > 1 and 裸.is_valid_int():
				_失败.append("%s:%d 场景里有**非法浮点**（两个小数点 —— 生成器拼串拼坏的）：%s"
					% [路径.get_file(), 行号, 行.strip_edges()])


	# ⑤ **批处理必须是 CRLF 行尾**（§3.176）。
	#    ⚠️ 2026-10-16：我用 `git show` 取 `启动游戏.bat` 的旧版当模板重写路径 —— 而 **git 存的是 LF**，
	#    写回去就成了 **LF-only** ⇒ **用户双击"黑窗闪退"**（cmd.exe 对 LF-only 批处理的支持不可靠，
	#    尤其带 `( … )` 块与 `:label` / `goto` 时）。工具写文件时犯这个错太容易了 ⇒ 钉一条。
	#    判据只看**裸 LF**：只许出现 CRLF 这一种行尾，单独一个 LF 就算违规。
	var 批处理: Array[String] = []
	var 根目录 := DirAccess.open("res://")
	if 根目录 != null:
		for 名 in 根目录.get_files():
			if 名.ends_with(".bat"):
				批处理.append("res://" + 名)
	收集("res://开发工具", 批处理, ".bat")
	_check(批处理.size() > 0, "一个 .bat 都没扫到 —— 路径是不是写错了")
	for 路径 in 批处理:
		var 文 := FileAccess.open(路径, FileAccess.READ)
		if 文 == null:
			continue
		var 字节 := 文.get_buffer(文.get_length())
		文.close()
		var 裸LF := 0
		for i in 字节.size():
			if 字节[i] == 10 and (i == 0 or 字节[i - 1] != 13):
				裸LF += 1
		if 裸LF > 0:
			_失败.append("%s 有 %d 处**裸 LF** —— 批处理必须 CRLF（LF-only 双击会闪退）" % [路径, 裸LF])


	# ⑥ **"另给端口"的在线用例必须把客户端的端口也指过去**（§3.183）。
	#    ⚠️ 2026-10-17 我踩过一次：新写的在线门在跑批器的 `$夹具额外` 里拿了一对独立端口
	#    （夹具跑 18708），**却忘了把客户端的 `game_settings.backend_port` 也指到 18708** ——
	#    客户端**只认这一键**（默认 18684）⇒ 它连上了**用户自己那台服务端**，
	#    并在**用户的存档**上真开通了一枚八门穴位（`user://` 是硬规矩①不许碰的东西）。
	#    ⚠️ 为什么不是"所有在线用例都要写"：夹具**默认就跑 18684**、客户端也默认连 18684，
	#       所以**没另给端口**的用例本来就对得上，不该被这条拦。
	#    判据：跑批器里"$用例表 映射到某 .gd" **且** "$夹具额外 里给它带了 --port" 的那些，
	#    对应脚本源码里必须出现 `backend_port`。
	var 跑器 := FileAccess.get_file_as_string("res://开发工具/跑在线用例.ps1")
	_check(跑器.length() > 0, "读不到 开发工具/跑在线用例.ps1")
	var 用例表 := {}
	for 行 in 跑器.split("
"):
		var 引 := 行.split('"')
		if 引.size() >= 4 and 引[3].ends_with(".gd"):
			用例表[引[1]] = 引[3]
	var 另给端口: Array[String] = []
	for 行 in 跑器.split("
"):
		if not 行.contains("--port"):
			continue
		var 引2 := 行.split('"')
		if 引2.size() >= 2 and 用例表.has(引2[1]):
			另给端口.append(String(用例表[引2[1]]))
	_check(另给端口.size() >= 3, "只认出 %d 条'另给端口'的用例 —— 跑批器结构是不是变了" % 另给端口.size())
	for 名 in 另给端口:
		var 路 := "res://测试/" + 名
		if not FileAccess.file_exists(路):
			continue
		if not FileAccess.get_file_as_string(路).contains("backend_port"):
			_失败.append("在线用例 %s 在跑批器里**另给了端口**，却没把客户端的 `game_settings.backend_port` 指过去 —— "
				% 名 + "它会连到用户自己那台 18684，并在**用户的存档**上真做事（硬规矩①）")

	## 54 载荷契约（2026-10-26）：只许裸 id。多一层 `"54:"` 会被服务端解析成 NPC 54，
	## 把「交付 1270 给 NPC 57」变成跟三代火影说话、对话框里没有可交行（实机复现过）。
	var 后类 := load("res://脚本/单例/后端连接.gd") as GDScript
	_check(后类 != null, "后端连接.gd 能 load（54 载荷契约要跑在真代码上）")
	if 后类 != null:
		_check(后类.npc_talk_payload(57) == "57",
				"54 载荷(模板 57) 必须是裸 「57」（实得 %s）" % 后类.npc_talk_payload(57))
		_check(后类.npc_talk_payload(100011) == "100011",
				"54 载荷(object 100011) 必须是裸 「100011」")
		_check(not 后类.npc_talk_payload(57).contains(":"),
				"54 载荷里不许再带 54: 前缀")

	if _失败.is_empty():
		print("源码健全性回归：通过（扫了 %d 个文件 + %d 个场景 + %d 个 .bat，注入指纹 0 命中、非法浮点 0、裸 LF 0）"
			% [文件清单.size(), 场景清单.size(), 批处理.size()])
		quit(0)
		return
	for 项 in _失败:
		push_error("源码健全性回归：%s" % 项)
	quit(1)


func 收集(目录: String, 出: Array[String], 后缀 := ".gd") -> void:
	var 流 := DirAccess.open(目录)
	if 流 == null:
		return
	for 名 in 流.get_files():
		if 名.ends_with(后缀):
			出.append(目录.path_join(名))
	for 子 in 流.get_directories():
		收集(目录.path_join(子), 出, 后缀)


func _check(条件: bool, 说明: String) -> void:
	if not 条件:
		_失败.append(说明)
