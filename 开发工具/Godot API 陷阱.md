# 本机 Godot 的 API 陷阱（照文档写会炸的那些）

**只对本机这个 build 有效。** 换引擎版本或换机器之后，重跑一次探针就作废重来。

```
Godot --headless --path . --script res://开发工具/Godot_API陷阱探针.gd
```

- 本机引擎：`Godot_v4.7.x-stable_win64_console.exe`
  （`4.7.1.stable.official`）
- **「表里没写」≠「存在」，「表里写了」也要复验。**

> 来源：另一位开发者交来的技能包 `其他开发者提供/Qoder技能合集_火影Flash转Godot/skills/
> godot-cli-verify-harness/references/api-deltas-4.7.2.md`。那张表标的是 **4.7.2**、
> 而且是对着**他们那份分叉副本**测的，所以**没有照抄** —— 下面每一条都是
> **在本机 4.7.1 上重打一遍**确认过的（2026-09-27）。

## 一、名字不对（照文档写必炸）

| 类 | 文档里常这么写 | 本机 4.7.1 实测 |
|---|---|---|
| `AnimatedTexture` | `fps` / `loop` | **都没有**。有 `frames` / `speed_scale`，逐帧用 **`frame_<i>/duration`（单位是秒）**，写 `fps` 报 `Invalid access to property or key 'fps'` |
| `TextureRect` | `region_enabled` / `region_rect` | **都没有**（这两个属性**只在 `Sprite2D` / `Sprite3D` 上**；`TextureButton`、`NinePatchRect` 也没有）。裁一段的替代：`AtlasTexture`（裁源图）+ 收窄节点矩形 |
| `Button` | `vertical_alignment` / `icon_display_policy` | **都没有**。文字竖直位置只能靠皮肤的 `content_margin` 抬 |
| `Label` | `font_flags` | **没有**（想加粗走 `FontVariation.variation_embolden`；⚠️ 它会强制轮廓渲染、毁掉宋体点阵的清晰度） |
| `LineEdit` | `grab_release_focus()` / `clip_text` | **都没有**（释放焦点用 `release_focus()`） |
| `PopupMenu` | `popup_at_position(pos)` | **没有**；只有 `popup(rect: Rect2i)` |
| `RegEx` | `match()` | **没有**；只有 `search()` / `search_all()` |
| `StyleBoxFlat` | `gradient` / `Gradient.from_colors()` | **都没有**。要渐变：`StyleBoxTexture` + 运行时构造的 `GradientTexture2D` |
| `CompressedTexture2D` | `get_resource_path()` | **没有**；用 `String(tex.resource_path)` |
| `VideoStreamPlayer` | `get_video_size()` / `get_playback_position()` / `centered` | **三个都没有**（用 `get_video_texture().get_size()` / `get_stream_position()`；`centered` 写进 `.tscn` 会变成 unknown property） |
| `DirAccess` | `make_dir_exists_absolute()` 当静态调 | 静态那个叫 **`make_dir_recursive_absolute()`**；按静态调 `make_dir_exists_absolute` 是**解析期**错误，整个脚本在 `_initialize()` 之前就死 |

## 二、存在但语义反直觉

| 现象 | 真相（本机实测） |
|---|---|
| `ClassDB.class_get_property_list("Button", true)` 只回 16 条 | 第二参是 **`no_inheritance`**（不是 `inherited`）：`true` = 只要本类，`false` = 含继承（143 条）。要全量就传 `false`，或实例化后调 `get_property_list()` |
| `CheckBox` 会被 `Button` 的主题污染 | **`CheckBox is Button` = true**（实测）。给 `Button` 设样式/字色会漏进每个 CheckBox |
| `GDScript` 里 `var x := <返回 Variant 的表达式>` | 本 build **拒绝类型推断**（parse error）。`var x: float = <Variant 表达式>` 或先 `:=` 到一个明确类型的中间量 |
| `Object.set()` 的返回值 | 返回 **void**，`x = obj.set(...)` 是解析错误；取值一律 `get()` |
| `--check-only --script` 报 `Identifier "AccountStore" not found` | **假错**：`--check-only` 在**自动加载注册之前**编译，场景脚本里能解析 |
| `PopupMenu` 在视口截图里永远没有 | 它渲染成**独立 OS 窗口**，`get_texture().get_image()` 必然不含它；只能打 `item_count` / `get_item_text(i)` 作证 |
| `--headless` 下录音必"静音" | dummy 音频驱动；且 `AudioEffectRecord` 是 **Resource** 不是节点 |
| 编辑器里 F6 跑出来"四周一圈暗色、固定矩形" | 那是**编辑器的嵌入运行**（`run/window_placement/game_embed_mode`），`window/stretch/*` 永远不会生效 |

## 三、写断言时踩过的（本项目自己的）

| 坑 | 后果 |
|---|---|
| `queue_free()` 是**延迟**的 | 当帧 `is_instance_valid()` 仍为真 → 判"已移除"要判**从容器里摘掉了**，不是判 `is_instance_valid` |
| 夹着 `await process_frame` 时测位置 | `_process` 会先推一两帧（实测差 ~5px）→ 判"在起点附近"，别判"正好等于起点" |
| `set_meta` 的键 | **必须是 ASCII 标识符**！写中文键会被拒（`Invalid metadata identifier`），`get_meta` 于是每次都拿到默认值 |
| `get_meta(名)` 键不存在时 | 返回 `null`；`var x: float = get_meta(名)` 会报 `Trying to assign value of type 'Nil'` → 用 `get_meta(名, 默认值)` |
| 同一个按钮反复 `connect` | 先 `for 连 in 钮.pressed.get_connections(): 钮.pressed.disconnect(连["callable"])` 再连；否则刷一屏 "Signal 'pressed' is already connected" |
| **`find_child("装备槽_")` 当前缀用** | **是精确名匹配**，永远找不到 `装备槽_1`。2026-09-28 宠物页断言用它当"存在性判断"→ `break` 掉整组装备槽检查，**反向对照不红**（§3.61.5 同型）。前缀筛选用 `find_children("装备槽_*", "", true, false)` 或直接 `get_node_or_null` 逐个取 |

## 四、`.tscn` 文本格式的坑（本机 4.7.1 实测，2026-09-28）

| 坑 | 后果 |
|---|---|
| **`add_theme_stylebox_override("normal", SubResource("x"))` 这种函数式行** | **紧跟其后的第一个 `[node]` 块会被解析器吞掉** —— 节点**静默消失**（`PackedScene.get_state().get_node_count()` 少一个，`instantiate()` 后 `get_node("那个名字")` 返回 null）。宠物条目里「选中条」就这么没的，查了半天是格式问题。**改写成属性式**：`theme_override_styles/normal = SubResource("x")`（编辑器自己存盘就是这个写法）。同类函数式行（`add_theme_color_override` 等）同理，别手写进 `.tscn` |
| 排查手法 | `PackedScene.get_state().get_node_count()` + 逐个 `get_node_name(i)` 对照磁盘上的 `[node name=...]` 列表 —— 磁盘有几行、state 少几个，一眼看出被吞的是哪个 |
| **`String(x)` 构造器不吃 int** | `String(5)` 报 `Invalid call 'String' constructor: 5`。要 `str(x)`。⚠️ 报错信息里那个参数**看着像节点路径**（它显示的是调用处的上下文），别被带偏 —— 当时我以为是 `get_node` 坏了。**float 同样不吃**（2026-10-02 实测）：`数据/*.json` 里**所有数值进 GDScript 都变 float**，`contents` 那种 `[[11000242,1]]` 拿 `String(行[0])` 直接炸 → 一律先 `int()` 再 `str()`；同族：拿 JSON 数字当字典键查八位 id 的，也都要先转 |
| 素材 UID 重复 | 同一张图在仓库里有两份**逐字节相同**的拷贝（合并别人包时整目录 cp 进来的），两份 `.import` 的 `uid=` 相同 → 每次 import 刷 `WARNING: UID duplicate detected`。**非阻塞**（按路径回落），但会让 `.godot/uid_cache` 不稳定。本机现存 ~60 条（虫槽/手里剑/通用控件等），待统一清 |

## 无头（headless）下点不动控件 —— 2026-10-01 实测（`装备格点击回归测试`）

1. **`Viewport.push_input(鼠标事件)` 不会驱动 Control 拾取**：事件被收下，但按钮不 pressed、
   无报错无警告——门会安静地"什么都没发生"。
2. **`inject_event` 在 `Window` 上根本不存在**（`Invalid call. Nonexistent function 'inject_event' in base 'Window'`）——
   它是 `SubViewport` 那一侧的名字，root 视口是 `Window`。
3. ⇒ **无头门只能 `pressed.emit()`**。两个已知副作用都要在门里显式处理：
   · `disabled` 的 Button **emit 照样跑**（emit 绕过 `_can_click`）——想测"空格子点不动"，
     就分两层：断言 `disabled == true`（运行时真点击被它挡）+ 断言处理器的空值 guard；
   · 点击语义若带"按状态分支"（如 有货/空货），记得 emit 直达 handler，**测的是 handler**，
     不是按钮的输入过滤。
