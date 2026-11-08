#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""烘「创建角色」窗的场景（原版在**独立素材包** MainCreateChar.swf 里，窗体 249×410）。

为什么必须生成器烘、不许手改 .tscn：这一页每一件的位置都是 AS3 现算的
（`CreateCharWindow3.as createView():227-322`），手改一次就对不回算式；而几何门要拿
「场景烘值 == 算式」当判据 ⇒ 只有生成器能同时满足两边。
同时把每件真值导成 `数据/界面/创建角色_尺寸.json`，门读它，不另立第二份常数。

逐件真值（全部现算，不抄）：
  窗口 249×410                        `_windowWidth :72` / `_windowHeight :48`
  背景 GameBack1 拉满舞台              :190-193（原生 100×100，是一张竖向渐变）
  窗口底 15 九宫格                     ScalingGrid twips X[960,4539] Y[585,6140] ÷20
  标题 25   x=(249-72)/2  y=5          :237-240
  面板底 22 x=8 y=32 w=249-16 h=410-80 :241-246
  四格 111×136 格1=(8+5,32+5) 格2=(格1.x+w+1,格1.y) 格3=(格1.x,格1.y+h+1) 格4=(格2.x,格3.y)  :247-282
  名标签 x=56 y=格4.y+格4.h+4           :283-287
  输入底 18 x=46 y=名标签.y+名标签.h+2   :288-291   ← 这块真皮挂在线编辑框自己身上（见下）
  输入框 = 无边框 TextField，x=底.x+6 y=底.y+1 w=底.w-12  :292-305
       ⇒ Godot 的 LineEdit 必画自己的 normal/focus 皮，兄弟底会被它盖住 ⇒ 合成一件：
         节点矩形取底的矩形，底当 stylebox，6/1/6/1 的内缩写进 content_margin。
  随机钮 x=底.x+底.w+2 y=底.y 高22 宽=文字宽+10  :310-314 + CreateCharButton 内联 ButtonState
  进入钮 x=(249-w)/2 y=410-h-8          :315-321
  转圈 x=进入钮.x+80 y=进入钮.y+18       :220-224（70 帧，SWF frameRate=24）

⚠ 本文件拼 .tscn 时**字符串里不出现反斜杠**：引号一律 `chr(34)`、换行一律列表 + join。
   往 .gd/.tscn 写带 `"` 的行时，转义只要多过一层工具就会被吃掉一层（本轮实测写坏过一次）。

用法：python 开发工具/生成创建角色场景.py
"""
import io
import json
import os
import re
import sys

Q = chr(34)
T = chr(9)
根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
皮目录 = "res://素材/界面/原版窗口/创建角色"
场景出 = os.path.join(根, "场景", "界面", "窗口", "创建角色", "创建角色窗.tscn")
尺寸出 = os.path.join(根, "数据", "界面", "创建角色_尺寸.json")
脚本路 = "res://脚本/界面/窗口/创建角色窗.gd"
XML路 = os.environ.get(
    "NARUTO_CREATECHAR_XML",
    r"2.2.3\www\act_web_nya_208_isolated\asset\MainCreateChar.swf.ffdec.xml",
)

窗宽 = 249.0
窗高 = 410.0
格宽 = 111.0
格高 = 136.0
名标签高 = 19.0          # GradientTextField.updateDisplayList：h = textHeight + 4（宋体 12px 量得 15）
输入底宽 = 125.0
输入底高 = 21.0
进入钮宽 = 115.0
进入钮高 = 34.0
随机钮高 = 22.0
转圈帧率 = 24.0          # MainCreateChar.swf 头里的 frameRate
## ⚠ 符号 36（CreateButtonMovie）的**注册点**在导出画布（183×48）里的像素位置 —— **不是画布正中**。
## 2026-10-10 用户报「进入游戏按钮的特效偏移了」：旧写法按 `183/2, 48/2` 摆 ⇒ 整颗往右 21.55px、
## 往下 4.05px，光扫跑到钮的右边外面。注册点由符号自己的子件包围盒算（不是量图猜的）：
##   光条 #28/#35 自身 x∈[−23.35, 23.3]、y∈[−23.75, 23.75]，时间轴里最左放在 x=−89.7、最右 x=+46.6
##     ⇒ 符号坐标 minX = −113.05、maxX = +69.95 ⇒ 宽 183.0 **正好等于画布宽** ⇒ 注册点 x = 113.05
##   y：光条放在 y=−4.3 ⇒ minY = −28.05、maxY = +19.45 ⇒ 高 47.5 ≈ 画布 48 ⇒ 注册点 y = 28.05
## 反向校验（摆对了才会成立）：钮形高光 #27（自身 x∈[−78.15,30.45] y∈[−21.05,10.45] 放在 (0.65,3)）
##   ⇒ 画布 x 35.55..144.15、y 10..41.5 ⇒ 换到窗口 = 69.5..178.1 × 367.95..399.45
##   与钮矩形 67..182 × 368..402 四边各内缩 2.5~4px —— 光扫本来就该盖在钮身上。
转圈注册x = 113.05
转圈注册y = 28.05

格 = [
    {"名": "职业格1", "job": 100, "gender": 1, "图": "格_火男", "音": "选中火", "说明": "ZHIYE_DESC_1"},
    {"名": "职业格2", "job": 200, "gender": 2, "图": "格_水女", "音": "选中水", "说明": "ZHIYI_DESC_2"},
    {"名": "职业格3", "job": 400, "gender": 2, "图": "格_风女", "音": "选中风", "说明": "ZHIYI_DESC_3"},
    {"名": "职业格4", "job": 300, "gender": 1, "图": "格_雷男", "音": "选中雷", "说明": "ZHIYI_DESC_4"},
]

钮态 = [("常态", "随机钮_常态", 74, "normal"),
        ("悬停", "随机钮_悬停皮", 77, "hover"),
        ("按下", "随机钮_按下皮", 80, "pressed"),
        ("禁用", "随机钮_禁用皮", 83, "disabled")]
字色 = {"normal": "Color(0.988235, 0.956863, 0.611765, 1)",
        "hover": "Color(1, 1, 0.764706, 1)",
        "pressed": "Color(0.701961, 0.678431, 0.698039, 1)",
        "disabled": "Color(0.576471, 0.576471, 0.576471, 1)"}

渐变代码 = chr(10).join([
    "shader_type canvas_item;",
    # 顶色 / 底色 / 盒高 —— GLSL 不认中文标识符，变量名一律 ASCII，中文只留在注释里
    "uniform vec4 top_color : source_color = vec4(0.9921569, 0.5764706, 0.1882353, 1.0);",
    "uniform vec4 bottom_color : source_color = vec4(1.0, 0.7058824, 0.2627451, 1.0);",
    "uniform float box_height : hint_range(1.0, 200.0) = 19.0;",
    "void fragment() {",
    T + "float a = texture(TEXTURE, UV).a;",
    T + "float t = clamp(VERTEX.y / box_height, 0.0, 1.0);",
    T + "COLOR = vec4(mix(top_color.rgb, bottom_color.rgb, t), top_color.a) * a;",
    "}",
])


def _f(v):
    v = float(v)
    return str(int(v)) if abs(v - round(v)) < 1e-9 else ("%.6f" % v).rstrip("0").rstrip(".")


def 引(s):
    return Q + s + Q


def 图尺寸(相对res路):
    from PIL import Image
    with Image.open(os.path.join(根, 相对res路.replace("res://", "").replace("/", os.sep))) as im:
        return im.size


def 九宫格(符号, 皮名):
    """DefineScalingGridTag 的 splitter(twips) → Godot 四条边距(像素)。

    边距**现场从 XML 解**，不在本文件抄第二份表：抄了就会与素材漂移。
    ⚠️ 四个数**按属性名逐个取**，不许写一条按顺序的正则：ffdec 把 RECT 写成
       `Xmax Xmin Ymax Ymin`（不是 Xmin 在前），而 `.*?` 会跨过行去下一个 tag 里凑 ——
       实测这一页七块九宫格全被抓坏（「上」恒 0、「右/下」负到 −128）。负边距不报错，
       在 Godot 里等于**整幅拉伸**，看起来就是"自己拿一块板盖在原版皮上"。
    """
    if not os.path.isfile(XML路):
        raise SystemExit("读不到 MainCreateChar 的 XML：%s" % XML路)
    t = io.open(XML路, encoding="utf-8", errors="replace").read()
    i = t.find('<item type="DefineScalingGridTag" characterId="%d"' % 符号)
    if i < 0:
        raise SystemExit("符号 %d 没有 DefineScalingGridTag ⇒ 它是整帧拉伸，不该走九宫格这条" % 符号)
    块 = t[i:t.find("</item>", i)]
    行 = re.search(r"<splitter[^>]*>", 块)
    if not 行:
        raise SystemExit("符号 %d 的 DefineScalingGridTag 里没有 splitter 行" % 符号)

    def 取(键):
        m = re.search(键 + r'="(\d+)"', 行.group(0))
        if not m:
            raise SystemExit("符号 %d 的 splitter 里没解出 %s（%s）" % (符号, 键, 皮名))
        return float(int(m.group(1))) / 20.0

    xmin, xmax, ymin, ymax = 取("Xmin"), 取("Xmax"), 取("Ymin"), 取("Ymax")
    ow, oh = 图尺寸("%s/%s.png" % (皮目录, 皮名))
    左, 上, 右, 下 = xmin, ymin, ow - xmax, oh - ymax
    if min(左, 上, 右, 下) < 0.0 or 左 + 右 > ow or 上 + 下 > oh:
        raise SystemExit("符号 %d(%s) 边距不成立：左%.2f 上%.2f 右%.2f 下%.2f 原生 %dx%d "
                         "⇒ splitter 与这张图不是同一个符号，或图尺寸导错了" % (
                             符号, 皮名, 左, 上, 右, 下, ow, oh))
    return {"左": 左, "上": 上, "右": 右, "下": 下, "原生宽": ow, "原生高": oh,
            "splitter_像素": [xmin, ymin, xmax, ymax]}


def 九宫格块(资id, 皮id, 边, 内容=(0.0, 0.0, 0.0, 0.0)):
    """一块 StyleBoxTexture。content_margin 必须显式写：
    不写就取 texture_margin ⇒ Button/Panel 的最小尺寸被四条边距顶宽，真值失真（踩过两次）。
    唯一的例外是挂在 LineEdit 上的那块 —— 原版输入框的文字位置本身就是「底.x+6 / 底.y+1 /
    宽−12」（`CreateCharWindow3.as:300-304`），那四个内缩只能靠 content_margin 表达。"""
    左, 上, 右, 下 = 内容
    return ["[sub_resource type=" + 引("StyleBoxTexture") + " id=" + 引(资id) + "]",
            "texture = ExtResource(" + 引(皮id) + ")",
            "texture_margin_left = " + _f(边["左"]),
            "texture_margin_top = " + _f(边["上"]),
            "texture_margin_right = " + _f(边["右"]),
            "texture_margin_bottom = " + _f(边["下"]),
            "content_margin_left = " + _f(左),
            "content_margin_top = " + _f(上),
            "content_margin_right = " + _f(右),
            "content_margin_bottom = " + _f(下),
            ""]


class 场:
    def __init__(self):
        self.资源 = []
        self.号 = {}
        self.子资源 = []
        self.节点 = []

    def 引(self, 类, 路):
        if 路 not in self.号:
            self.号[路] = "1_%d" % (len(self.号) + 1)
            self.资源.append((self.号[路], 类, 路))
        return self.号[路]

    def 皮(self, 名):
        return self.引("Texture2D", "%s/%s.png" % (皮目录, 名))

    def 节点加(self, 名, 父, 类, 属性):
        self.节点.append([名, 父, 类, 属性])


def 生成():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    s = 场()
    尺寸 = {"说明": "创建角色窗逐件真值。生成 = 开发工具/生成创建角色场景.py；"
                   "算式与 AS3 行号见 真值/窗口/创建角色.md 与生成器 docstring。",
            "窗宽": 窗宽, "窗高": 窗高, "件": {}}

    底 = {}
    # ⚠ 资源 id 只许 ASCII：Godot 4.7 把 `id=` 直接喂给 `Resource::set_scene_unique_id`，
    #    中文 id 在 load 时每条报一次 `The scene unique ID must contain only letters, numbers,
    #    and underscores`（实测这一份报了 10 条）。名照样用中文，只在写 id 时换英文代号。
    英名 = {"窗口底": "win", "面板底": "panel", "输入底": "input"}
    # 只有输入框那块要写文字内缩（= 原版 TextField 相对底的 6/1/6/1），其余六块一律 0。
    内容表 = {"输入底": (6.0, 1.0, 6.0, 1.0)}
    for 名, 符号, 皮名, x, y, w, h in [
            ("窗口底", 15, "创角窗口底", 0.0, 0.0, 窗宽, 窗高),
            ("面板底", 22, "创角面板底", 8.0, 32.0, 窗宽 - 16.0, 窗高 - 80.0),
            ("输入底", 18, "创角输入框底", 46.0, 0.0, 输入底宽, 输入底高)]:
        边 = 九宫格(符号, 皮名)
        资 = "sb_" + 英名[名]
        s.子资源.append(九宫格块(资, s.皮(皮名), 边, 内容表.get(名, (0.0, 0.0, 0.0, 0.0))))
        底[名] = dict(资=资, x=x, y=y, w=w, h=h, 边=边, 皮名=皮名, 符号=符号)
        尺寸["件"][名] = dict(x=x, y=y, w=w, h=h, 皮=皮名, 符号=符号, **边)

    格x = 8.0 + 5.0
    格y = 32.0 + 5.0
    名标签y = 格y + 格高 + 1 + 格高 + 4
    输入底y = 名标签y + 名标签高 + 2
    底["输入底"]["y"] = 输入底y
    尺寸["件"]["输入底"]["y"] = 输入底y
    尺寸["件"]["名标签"] = dict(x=56.0, y=名标签y, w=78.0, h=名标签高,
                          渐变=dict(顶色="#FD9330", 底色="#FFB443", 角度="竖向(rotate 90deg)",
                                来源="GradientTextField.as _colors=[16643440,16751683] ratios=[0,255]"),
                          未做的="原版整件另带 GlowFilter(0,1,2,2,10,1) 黑色外发光；Godot 无文字外发光原语，这里没做")
    尺寸["件"]["输入框"] = dict(x=46.0, y=输入底y, w=输入底宽, h=输入底高,
                            皮="创角输入框底", 符号=18,
                            文字内缩=dict(左=6.0, 上=1.0, 右=6.0, 下=1.0),
                            文字色="#ffffff", 字高=12, 截断=12, 居中=False,
                            说明="原版是两个兄弟：CTextInput_background(:288-291) + 无边框无底色的 "
                                  "TextField(:292-304，x=底.x+6、y=底.y+1、宽=底.宽-12)。"
                                  "Godot 的 LineEdit 一定要画自己的 normal/focus 皮 ⇒ 摆兄弟 Panel 必然"
                                  "互相盖（这就是被打回的那次），所以合成一件：节点吃底的整块矩形，"
                                  "真皮当 stylebox，文字位置靠 content_margin 6/1/6/1 复现那两个偏移。"
                                  "对齐：TextFormat 只给了 color/size(:295-298)，没给 align ⇒ 左对齐。"
                                  "未做的：TextField 自带 GlowFilter(0,1,3,3,6) 黑色外发光(:299)，"
                                  "Godot 没有文字外发光原语；restrict 字符白名单(:302) 由控制器的校验承担。")
    进x = (窗宽 - 进入钮宽) / 2.0
    进y = 窗高 - 进入钮高 - 8.0
    尺寸["件"]["随机钮"] = dict(x=46.0 + 输入底宽 + 2.0, y=输入底y, h=随机钮高)
    尺寸["件"]["进入游戏"] = dict(x=进x, y=进y, w=进入钮宽, h=进入钮高)
    尺寸["件"]["提交转圈"] = dict(锚x=进x + 80.0, 锚y=进y + 18.0,
                                  x=进x + 80.0 - 转圈注册x, y=进y + 18.0 - 转圈注册y,
                                  注册x=转圈注册x, 注册y=转圈注册y,
                                  w=183.0, h=48.0, 帧数=70, 每秒帧=转圈帧率,
                                  每帧秒=1.0 / 转圈帧率,
                                  说明="锚x/锚y = 原版 _movie.x/.y = **符号注册点**（不是帧中心，见文件头 转圈注册x/y 那段算式）；"
                                        "x/y = Godot 节点左上角 = 锚 − 注册点像素。"
                                        "每帧秒 = AnimatedTexture 的 frame_N/duration（单位是秒！），"
                                        "原版 SWF 头 frameRate=24.0 ⇒ 1/24 秒一帧、一圈 70/24≈2.917 秒。"
                                        "Godot 4.7 没有 fps/loop 这两个属性，写进去会被静默丢掉。")

    # 转圈 70 帧
    帧目录 = os.path.join(根, "素材", "界面", "原版窗口", "创建角色", "提交转圈")
    帧档 = sorted(f for f in os.listdir(帧目录) if f.endswith(".png"))
    if len(帧档) != 70:
        raise SystemExit("转圈帧数应为 70（CreateButtonMovie 的 frameCount），实际 %d" % len(帧档))
    # ⚠ 皮() 会自己补 .png ⇒ 这里必须先把扩展名削掉，不然出来 `xxx.png.png` 打不开
    帧id = [s.皮("提交转圈/" + f[:-4]) for f in 帧档]
    # 转圈用 **AnimatedTexture**（不是 SpriteFrames）：后者要 `animations` 数组 +
    # 每动画一个 sub_resource，手写极易错成 `Animation '待机' doesn't exist`（实测踩过）；
    # AnimatedTexture 一个资源就够，且 TextureRect 直接吃它、自动播。
    # ⚠️⚠️ Godot 4.7 的 AnimatedTexture **没有 `fps`、也没有 `loop`** 这两个属性
    #   （现查 get_property_list() 只有 frames / current_frame / pause / one_shot / speed_scale /
    #    frame_N/texture / frame_N/duration）。以前这里写 `fps = 24` + 每帧 `duration = 1.0`：
    #    `fps` 那行被**静默丢掉**（运行期 get("fps") 回 null），于是每帧时长就是字面的 **1 秒**
    #    ⇒ 整圈 70 秒，用户看到的就是「这个特效帧率很低很低」（2026-10-10 有头量具实测：
    #    连拍 36 个引擎帧，画面变化 0 次）。`duration` 的单位是**秒** ⇒ 24 fps 要写 1/24。
    #    循环不用声明：`one_shot` 默认 false。
    每帧秒 = 1.0 / 转圈帧率
    块 = ["[sub_resource type=" + 引("AnimatedTexture") + " id=" + 引("at_spin") + "]",
          "frames = %d" % len(帧id)]
    for n, i in enumerate(帧id):
        块.append("frame_%d/duration = " % n + _f(每帧秒))
    for n, i in enumerate(帧id):
        块.append("frame_%d/texture = ExtResource(%s)" % (n, 引(i)))
    块.append("")
    s.子资源.append(块)

    # 随机钮四态：每态一张**真皮**（SuiJiButton_up/over/down/disabled，都是九宫格）。
    # ⚠ 不是 MButton3 那种"一张皮 + ±30 滤镜"：ButtonState 每个态 new 的是不同符号。
    #    原版在该皮上**另外**叠 skinFilters(+30/-40)、禁用再叠 getGrayFilter —— 那一步这里没做，如实登记。
    for 态, 皮名, 符号, 槽 in 钮态:
        边 = 九宫格(符号, 皮名)
        s.子资源.append(九宫格块("sb_rand_" + 槽, s.皮(皮名), 边))
        d = dict(皮=皮名, 符号=符号, 槽=槽, 字色=字色[槽])
        d.update(边)
        d["未做的"] = "原版在该皮上再叠 getLightFilter(+30/-40)，禁用态叠 getGrayFilter —— 本工程未做"
        尺寸["件"].setdefault("随机钮皮", {})[态] = d

    s.子资源.append(["[sub_resource type=" + 引("Shader") + " id=" + 引("sh_grad") + "]",
                    "code = " + json.dumps(渐变代码, ensure_ascii=False), ""])
    s.子资源.append(["[sub_resource type=" + 引("ShaderMaterial") + " id=" + 引("sm_grad") + "]",
                    "render_priority = 0",
                    "shader = SubResource(" + 引("sh_grad") + ")",
                    "shader_parameter/top_color = Vector4(0.992156863, 0.576470613, 0.188235298, 1)",
                    "shader_parameter/bottom_color = Vector4(1, 0.705882373, 0.262745112, 1)",
                    "shader_parameter/box_height = 19.0", ""])

    s.节点加("创建角色", "", "Control", {
        "custom_minimum_size": "Vector2(%s, %s)" % (_f(窗宽), _f(窗高)),
        "offset_right": _f(窗宽), "offset_bottom": _f(窗高),
        "script": "ExtResource(" + 引("90_script") + ")"})
    s.节点加("背景", "根", "TextureRect", {
        # 锚点写死在场景里：铺满父节点；expand_mode=0(KEEP_SIZE) 才是"尺寸听锚点的"，
        # 填 1 是 FIT_WIDTH（尺寸听纹理的）⇒ 背景只剩左上角一小块（本轮实测踩过）。
        "anchor_right": "1.0", "anchor_bottom": "1.0",
        "grow_horizontal": "2", "grow_vertical": "2",
        "texture": "ExtResource(" + 引(s.皮("创角背景")) + ")",
        "expand_mode": "0", "stretch_mode": "0", "mouse_filter": "2"})
    s.节点加("窗口", "根", "Control", {
        "anchor_left": "0.5", "anchor_top": "0.5", "anchor_right": "0.5", "anchor_bottom": "0.5",
        "offset_left": _f(-窗宽 / 2.0), "offset_top": _f(-窗高 / 2.0),
        "offset_right": _f(窗宽 / 2.0), "offset_bottom": _f(窗高 / 2.0),
        "mouse_filter": "2"})
    s.节点加("窗口底", "窗口", "Panel", {
        "offset_right": _f(窗宽), "offset_bottom": _f(窗高),
        "theme_override_styles/panel": "SubResource(" + 引(底["窗口底"]["资"]) + ")",
        "mouse_filter": "2"})
    s.节点加("标题", "窗口", "TextureRect", {
        "offset_left": _f((窗宽 - 72.0) / 2.0), "offset_top": "5.0",
        "offset_right": _f((窗宽 - 72.0) / 2.0 + 72.0), "offset_bottom": "24.0",
        "texture": "ExtResource(" + 引(s.皮("创角标题")) + ")", "mouse_filter": "2"})
    s.节点加("面板底", "窗口", "Panel", {
        "offset_left": "8.0", "offset_top": "32.0",
        "offset_right": _f(8.0 + 窗宽 - 16.0), "offset_bottom": _f(32.0 + 窗高 - 80.0),
        "theme_override_styles/panel": "SubResource(" + 引(底["面板底"]["资"]) + ")",
        "mouse_filter": "2"})
    for i, g in enumerate(格):
        gx = 格x + (i % 2) * (格宽 + 1.0)
        gy = 格y + (i // 2) * (格高 + 1.0)
        s.节点加(g["名"], "窗口", "TextureButton", {
            "offset_left": _f(gx), "offset_top": _f(gy),
            "offset_right": _f(gx + 格宽), "offset_bottom": _f(gy + 格高),
            "texture_normal": "ExtResource(" + 引(s.皮(g["图"] + "_未选")) + ")",
            "texture_hover": "ExtResource(" + 引(s.皮(g["图"] + "_悬停")) + ")",
            "mouse_default_cursor_shape": "2"})
        尺寸["件"][g["名"]] = dict(x=gx, y=gy, w=格宽, h=格高, job=g["job"], gender=g["gender"],
                                未选=g["图"] + "_未选.png", 悬停=g["图"] + "_悬停.png",
                                选中=g["图"] + "_选中.png", 音=g["音"], 说明键=g["说明"])
    s.节点加("名标签", "窗口", "Label", {
        "material": "SubResource(" + 引("sm_grad") + ")",
        "offset_left": "56.0", "offset_top": _f(名标签y),
        "offset_right": "134.0", "offset_bottom": _f(名标签y + 名标签高),
        "theme_override_font_sizes/font_size": "12",
        "text": 引("请输入角色名"), "mouse_filter": "2"})
    # 输入栏：**不摆兄弟 Panel**。原版是 CTextInput_background + 无边框 TextField 两个兄弟
    # （:288-304），但 Godot 的 LineEdit 永远要画自己那份 normal/focus 皮 —— 兄弟底要么被它盖住、
    # 要么盖住它，出来就是"自己做了个栏压在原版皮上"。⇒ 把那张真皮直接挂成 LineEdit 的 stylebox，
    # 节点矩形 = 底的矩形，文字内缩 6/1/6/1 由 sb_input 的 content_margin 承担。
    s.节点加("角色名输入", "窗口", "LineEdit", {
        "offset_left": "46.0", "offset_top": _f(输入底y),
        "offset_right": _f(46.0 + 输入底宽), "offset_bottom": _f(输入底y + 输入底高),
        "theme_override_styles/normal": "SubResource(" + 引(底["输入底"]["资"]) + ")",
        "theme_override_styles/focus": "SubResource(" + 引(底["输入底"]["资"]) + ")",
        # 原版 defaultTextFormat.color = 16777215（:296）
        "theme_override_colors/font_color": "Color(1, 1, 1, 1)",
        "max_length": "12", "alignment": "0",
        "theme_override_font_sizes/font_size": "12"})
    s.节点加("随机钮", "窗口", "Button", {
        "offset_left": _f(46.0 + 输入底宽 + 2.0), "offset_top": _f(输入底y),
        "offset_right": _f(46.0 + 输入底宽 + 2.0 + 34.0), "offset_bottom": _f(输入底y + 随机钮高),
        "theme_override_styles/normal": "SubResource(" + 引("sb_rand_normal") + ")",
        "theme_override_styles/hover": "SubResource(" + 引("sb_rand_hover") + ")",
        "theme_override_styles/pressed": "SubResource(" + 引("sb_rand_pressed") + ")",
        "theme_override_styles/disabled": "SubResource(" + 引("sb_rand_disabled") + ")",
        "theme_override_colors/font_color": 字色["normal"],
        "theme_override_colors/font_hover_color": 字色["hover"],
        "theme_override_colors/font_pressed_color": 字色["pressed"],
        "theme_override_colors/font_disabled_color": 字色["disabled"],
        "theme_override_font_sizes/font_size": "12",
        "text": 引("随机"), "clip_text": "true",
        "mouse_default_cursor_shape": "2"})
    s.节点加("进入游戏", "窗口", "TextureButton", {
        "offset_left": _f(进x), "offset_top": _f(进y),
        "offset_right": _f(进x + 进入钮宽), "offset_bottom": _f(进y + 进入钮高),
        "texture_normal": "ExtResource(" + 引(s.皮("进入游戏_常态")) + ")",
        "texture_hover": "ExtResource(" + 引(s.皮("进入游戏_悬停")) + ")",
        "texture_pressed": "ExtResource(" + 引(s.皮("进入游戏_按下")) + ")",
        "mouse_default_cursor_shape": "2"})
    ## ⚠ 原版 `CreateButtonMovie` 的**注册点在帧中心**（帧 183×48，可见内容 bbox 约
    ## (37..143, 14..39) = 居中），而 `:221-222` 写的是 `_movie.x = 按钮.x + 80`、`y = 按钮.y + 18`
    ## —— 那是把**中心**放到那儿。Godot 的 TextureRect 从**左上角**画，照抄这两个数就会
    ## 整个跑到按钮右下方（用户 2026-10-10 报「特效偏移」）。所以要各减半个帧。
    转圈帧宽 = 183.0
    转圈帧高 = 48.0
    转圈锚x = 进x + 80.0		# 原版 `_movie.x` = **符号注册点**落在哪儿（不是帧中心！见文件头 转圈注册x/y）
    转圈锚y = 进y + 18.0
    s.节点加("提交转圈", "窗口", "TextureRect", {
        "offset_left": _f(转圈锚x - 转圈注册x), "offset_top": _f(转圈锚y - 转圈注册y),
        "offset_right": _f(转圈锚x - 转圈注册x + 转圈帧宽),
        "offset_bottom": _f(转圈锚y - 转圈注册y + 转圈帧高),
        "texture": "SubResource(" + 引("at_spin") + ")",
        "mouse_filter": "2"})
    尺寸["件"]["转圈帧数"] = 70
    尺寸["件"]["转圈帧率"] = 转圈帧率

    头 = ["[gd_scene load_steps=%d format=3]" % (len(s.资源) + 1 + len(s.子资源) + 1), ""]
    for rid, 类, 路 in s.资源:
        头.append("[ext_resource type=" + 引(类) + " path=" + 引(路) + " id=" + 引(rid) + "]")
    头.append("[ext_resource type=" + 引("Script") + " path=" + 引(脚本路) + " id=" + 引("90_script") + "]")
    头.append("")
    for 子 in s.子资源:
        头 += 子
    for 名, 父, 类, 属 in s.节点:
        # ⚠ 根的直接子节点必须写 parent="."（哨兵 "根"），只省 parent= 会让整份场景 load 成 null；
        #    孙子节点写各自的父节点名，别一起塌成 "."。
        父串 = "" if 父 == "" else (" parent=" + 引("." if 父 == "根" else 父))
        行 = ["[node name=" + 引(名) + " type=" + 引(类) + 父串 + "]"]
        for k, v in 属.items():
            行.append(k + " = " + v)
        头.append(chr(10).join(行))
        头.append("")
    os.makedirs(os.path.dirname(场景出), exist_ok=True)
    with io.open(场景出, "w", encoding="utf-8", newline=chr(10)) as f:
        f.write(chr(10).join(头))
        f.flush(); os.fsync(f.fileno())
    os.makedirs(os.path.dirname(尺寸出), exist_ok=True)
    with io.open(尺寸出, "w", encoding="utf-8") as f:
        json.dump(尺寸, f, ensure_ascii=False, indent=1)
        f.flush(); os.fsync(f.fileno())
    print("场景 %d 行 / 外部资源 %d / 子资源块 %d / 节点 %d -> %s" % (
        len(头), len(s.资源) + 1, len(s.子资源), len(s.节点), os.path.relpath(场景出, 根)))
    print("尺寸表 -> %s" % os.path.relpath(尺寸出, 根))
    print("y 链：格顶 %.0f → 名标签 %.0f → 输入底 %.0f → 输入框 %.0f；进入钮 (%.1f, %.0f)；转圈 (%.0f, %.0f)" % (
        格y, 名标签y, 输入底y, 输入底y + 1, 进x, 进y, 进x + 80.0, 进y + 18.0))


if __name__ == "__main__":
    生成()
