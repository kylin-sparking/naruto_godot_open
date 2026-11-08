# -*- coding: utf-8 -*-
"""生成 `场景/角色/打坐光环.tscn` —— 把 healNew 那九帧做成**编辑器里看得见、能拖**的九个 Sprite2D。

为什么要它（2026-10-13 用户原话）：**"如果我能直接在编辑器场景中看到这 9 帧我倒是可以手动调整，
但是我看不到我没法调整啊"** ⇒ 之前这圈特效是运行时用代码 `new()` 出来的，编辑器里根本没有它，
用户只能靠实机截图来回反馈，一个问题卡了一下午。

做法：一帧一个 `Sprite2D`，`centered = false`、
`position = (−原点x + 补x, −原点y + 补y)` —— 前半是 AS3 `CharacterItem.setOrigin():53-60` 的
字面公式（把注册点落到角色原点），后半 `补x/补y` 是**按第 0 帧那块八卦阵对齐所需的修正**
（2026-10-13 用户点头采纳：原版素材里第 6、7 两帧的阵自己就画偏了 2~3 像素 ⇒ 起气时看着在跳）。
补量只来自 `数据/界面/打坐光环.json` 那一条路，脚本里不许再有第二种补偿。
⇒ 编辑器里打开这张场景，九张图就按游戏里的样子叠在同一个原点上；
   顶上把 `全显` 勾上 ⇒ 九帧同时显示，盘没对齐就看得见"重影"，点那一帧直接拖，存盘即生效。

数据源：`数据/界面/打坐光环.json`（帧表来自 GameData `Etc.effects.healNew`，逐帧 origin 已在里面）。
幂等：重跑覆盖同一个文件。**⚠ 会覆盖用户在编辑器里的手拖 ⇒ 跑前先 `读回打坐九帧位.py` 把差量读出来。**
另一条保护：重跑时**沿用现有 `.tscn` 头行里的 `uid`**（编辑器存盘补进去的），别让它退回无 uid 版本。

用法：python 开发工具/生成打坐九帧场景.py
"""
import io
import json
import os
import re

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
表路 = os.path.join(工程, "数据", "界面", "打坐光环.json")
出 = os.path.join(工程, "场景", "角色", "打坐光环.tscn")


def 现有uid():
    """从磁盘上那份 .tscn 的头行里把 uid 抠出来沿用（编辑器会补，我们重跑时不该弄丢）。"""
    if not os.path.exists(出):
        return ""
    头 = io.open(出, encoding="utf-8").readline()
    m = re.search(r'uid="(uid://[^"]+)"', 头)
    return m.group(1) if m else ""


def main():
    表 = json.load(io.open(表路, encoding="utf-8"))
    帧表 = 表["帧"]
    外 = ['[ext_resource type="Script" path="res://脚本/角色/打坐光环.gd" id="1_脚本"]']
    for i, 帧 in enumerate(帧表):
        外.append('[ext_resource type="Texture2D" path="%s" id="2_帧%d"]' % (帧["文件"], i))
    # ⚠ 根节点上**不要写不认识的属性**（Godot 存盘会静默丢掉，读的人以为它在）
    #   ⇒ 说明只放在 脚本/角色/打坐光环.gd 的文件头与本生成器的 docstring 里。
    节 = ['[node name="打坐光环" type="Node2D"]',
          'script = ExtResource("1_脚本")',
          '']
    for i, 帧 in enumerate(帧表):
        位 = (-int(帧["原点x"]) + int(帧.get("补x", 0)),
              -int(帧["原点y"]) + int(帧.get("补y", 0)))
        节 += [
            '[node name="第%d帧" type="Sprite2D" parent="."]' % i,
            'position = Vector2(%d, %d)' % 位,
            'texture = ExtResource("2_帧%d")' % i,
            'centered = false',
            'visible = %s' % ('true' if i == 0 else 'false'),
            '',
        ]
    头 = '[gd_scene load_steps=%d format=3]' % (1 + len(外))
    uid = 现有uid()
    if uid:
        头 = 头[:-1] + ' uid="%s"]' % uid
    os.makedirs(os.path.dirname(出), exist_ok=True)
    io.open(出, "w", encoding="utf-8", newline="\n").write(
        "\n\n".join([头] + 外 + 节).rstrip() + "\n")
    print("生成 %s：%d 帧、%d 条 ext_resource、头行 %s" % (出, len(帧表), len(外), 头))
    for i, 帧 in enumerate(帧表):
        print("  第%d帧 position = (%d, %d) = −原点(%d,%d) + 补(%d,%d)  贴图 %s"
              % (i, -int(帧["原点x"]) + int(帧.get("补x", 0)),
                 -int(帧["原点y"]) + int(帧.get("补y", 0)),
                 int(帧["原点x"]), int(帧["原点y"]),
                 int(帧.get("补x", 0)), int(帧.get("补y", 0)),
                 os.path.basename(帧["文件"])))


if __name__ == "__main__":
    import sys
    sys.stdout.reconfigure(encoding="utf-8")
    main()
