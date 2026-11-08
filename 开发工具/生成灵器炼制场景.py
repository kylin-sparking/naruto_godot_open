# -*- coding: utf-8 -*-
"""生成 `场景/界面/窗口/灵器炼制/灵器炼制窗.tscn`。

**改真值改这里，别手改 .tscn**。

原版是**三扇类**：`XiLianWindow`（洗炼）/ `LingHuaWindow`（灵化）/ `KaiGuangWindow`（开光），
都在 `com/mxw/uifl/controls/lingQi/`（开光那条人具分支 `RenJuKaiGuangWindow` 另说）。
三扇 `super(520,345,true)`、`createChildren` 里 `_contentBg.width/height = 505/300`，
**版式逐行相同**，只有两处不同：
  · **材料格个数**：洗炼/灵化 各 1 枚（`ItemCaiLiaoBox(true)`）、开光 **2 枚**
    （`kgChuiCell=false` 开光锤 + `kgShiCell=true` 开光石）；
  · 文案与提交的动作号（见下）。
⇒ 本工程**一个场景 + 模式位**（同 `镶嵌勾玉` 那条口径：版式逐字相同就不复制场景）。

坐标（窗口局部 1:1，尺寸表口径 `整框: true`、`原点: [0,0]`；常量 BORDER_GAP=5、CONTENT_GAP=8）：
  `_contentBg`（MYellow）   = (CONTENT_GAP, 38) = (8,38)，尺寸 (505,300)   ← `createChildren` 里改过
  说明底（MPane 495×63）    = contentBg + (BORDER_GAP, BORDER_GAP) = (13,43)
    说明（TextArea2 495×63）= 说明底 + (BORDER_GAP, BORDER_GAP) = (18,48)
  内容底（MPane 495×226）   = (13, 43+63+1 = 107)
    文案（TextArea2 345×226）= 内容底 + (BORDER_GAP, 10) = (18,117)
    材料格（ItemCaiLiaoBox 60 宽）：
        洗炼/灵化 = 内容底 + (文案.x+文案宽, 80) = (13+350, 187) = (363,187)
        开光     = 第一枚 (13+340,187) = (353,187)、第二枚 = 第一枚 +(60+10, 0) = (423,187)
                  ⚠️ 只有第二枚是 `ItemCaiLiaoBox(true)` ⇒ **只有它带「购买」钮**
                  （`KaiGuangWindow.as:76/80`：锤 `false`、石 `true`）
    开始钮（MButtonF 61×22） = 内容底 + `文案.x + 文案宽 [± 20]` @175：
        洗炼/灵化 = 13+350      = (363,282)
        开光     = 13+350+**20** = (383,282)   ← 比第一枚材料格（353）**右 30**，不是右 20

⚠️ 本页**没有原版基线图**，像素对证做不了（同「幸运合成面板」/「装备修复」那条口径）：
版式按上面这些算式生成，`测试/灵器炼制页回归测试.gd` 钉的是**算式与模式分派**。
"""
import io
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
出 = os.path.join(工程, "场景", "界面", "窗口", "灵器炼制", "灵器炼制窗.tscn")


def 材料组(名: str, x: float, y: float) -> str:
    """一枚材料格（原版 `ItemCaiLiaoBox`：名字 + 格 + 数量角标）。

    ⚠️ 2026-10-13：偏移一律用 `{v:.1f}` 格式化 —— 原来写的是 `{x}.0`，
    而传进来的 `x` **本来就是 float**（`350.0`）⇒ 拼出 `350.0.0` 这种**非法浮点**，
    Godot 解析后材料格整体落不到位（§3.149 逮到的）。
    """
    return f'''
[node name="{名}" type="TextureRect" parent="内容底"]
offset_left = {x:.1f}
offset_top = {y:.1f}
offset_right = {x + 40.0:.1f}
offset_bottom = {y + 40.0:.1f}
texture = ExtResource("1_slot")
mouse_filter = 2

[node name="材料图标" type="TextureRect" parent="内容底/{名}"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 2.0
offset_top = 2.0
offset_right = -2.0
offset_bottom = -2.0
grow_horizontal = 2
grow_vertical = 2
expand_mode = 1
stretch_mode = 5
mouse_filter = 2

[node name="材料数量" type="Label" parent="内容底/{名}"]
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -30.0
offset_top = -18.0
offset_right = -2.0
offset_bottom = -2.0
grow_horizontal = 0
grow_vertical = 0
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_font_sizes/font_size = 12
horizontal_alignment = 2
vertical_alignment = 2
mouse_filter = 2

; 购买钮（原版 `ItemCaiLiaoBox.updateDisplayList`：`buyBtn.y = itemCell.y + itemCell.height + 3`、
; `x = (_width − buyBtn.width) / 2` ⇒ 格正下方、按 60 宽盒居中。`true` 那参就是 showBuyBtn。）
[node name="{名}购买" type="Button" parent="内容底"]
offset_left = {x - 3.0:.1f}
offset_top = {y + 43.0:.1f}
offset_right = {x + 47.0:.1f}
offset_bottom = {y + 65.0:.1f}
focus_mode = 0
text = "购买"

[node name="{名}名" type="Label" parent="内容底"]
offset_left = {x - 6.0:.1f}
offset_top = {y - 20.0:.1f}
offset_right = {x + 52.0:.1f}
offset_bottom = {y:.1f}
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_font_sizes/font_size = 12
horizontal_alignment = 1
mouse_filter = 2
'''


头 = '''[gd_scene load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://素材/界面/原版窗口/通用控件/物品格.png" id="1_slot"]

; 原版「灵器炼制」三扇（洗炼 `XiLianWindow` / 灵化 `LingHuaWindow` / 开光 `KaiGuangWindow`，
; 都在 `com/mxw/uifl/controls/lingQi/`），三扇 `super(520,345,true)`、版式**逐行相同**。
; 由 `onClickPopupMenu` 的「洗练 / 灵化 / 开光」三项打开（带 `curCellData`）。
;
; 提交各自走 `LING = 2081` 的不同子命令（`LingEquipProcessor.as:107/116/125`）：
;   灵化 `writeByte(1)` / 开光 `writeByte(0)` / 洗炼 `writeByte(2)`，都带 (itemId, itemPos)。
;
; 坐标出处与算式见生成器 `开发工具/生成灵器炼制场景.py` 的头注。**别手改本文件。**
[node name="原版灵器炼制内容" type="Control"]
custom_minimum_size = Vector2(520, 345)
mouse_filter = 2

[node name="外框" type="Panel" parent="."]
offset_right = 520.0
offset_bottom = 345.0
mouse_filter = 2

; `_contentBg`（MYellow）：位置 (CONTENT_GAP, 38)，`createChildren` 里改成 505×300。
[node name="内容背景" type="Panel" parent="."]
offset_left = 8.0
offset_top = 38.0
offset_right = 513.0
offset_bottom = 338.0

; 说明底（MPane 495×63）
[node name="说明底" type="Panel" parent="."]
offset_left = 13.0
offset_top = 43.0
offset_right = 508.0
offset_bottom = 106.0

[node name="说明" type="RichTextLabel" parent="."]
offset_left = 18.0
offset_top = 48.0
offset_right = 513.0
offset_bottom = 111.0
bbcode_enabled = true
mouse_filter = 2

; 内容底（MPane 495×226）
[node name="内容底" type="Panel" parent="."]
offset_left = 13.0
offset_top = 107.0
offset_right = 508.0
offset_bottom = 333.0

; 文案（TextArea2 345×226）
[node name="文案" type="RichTextLabel" parent="内容底"]
offset_left = 5.0
offset_top = 10.0
offset_right = 350.0
offset_bottom = 236.0
bbcode_enabled = true
mouse_filter = 2
'''

尾 = '''
; 开始钮（MButtonF 61×22）：洗炼/灵化在材料格正下方；开光在三枚件右侧（渲染时按模式挪）。
[node name="开始" type="Button" parent="内容底"]
offset_left = 350.0
offset_top = 175.0
offset_right = 411.0
offset_bottom = 197.0
text = "洗炼"
'''

正文 = 头 + 材料组("材料格一", 350.0, 80.0) + 材料组("材料格二", 410.0, 80.0) + 尾
os.makedirs(os.path.dirname(出), exist_ok=True)
io.open(出, "w", encoding="utf-8", newline="\n").write(正文)
print("生成 %s：%d 行" % (os.path.relpath(出, 工程), 正文.count("\n")))
