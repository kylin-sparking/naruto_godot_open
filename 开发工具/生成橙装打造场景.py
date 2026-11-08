# -*- coding: utf-8 -*-
"""生成 `场景/界面/窗口/橙装打造/橙装打造窗.tscn`
（原版 `YellowEquipLianZhiWindow.as`，`super(376,407)`）。

**改真值改这里，别手改 .tscn**（手改会被下一次生成吃掉）。

坐标全部来自 `YellowEquipLianZhiWindow.createChildren():332-407` **逐行算出来的**：
常量 `BORDER_GAP = 5`、`CONTENT_GAP = 8`（`UIConfig.as:890/892`）。
窗口局部坐标 1:1（尺寸表 `整框: true`、`原点: [0,0]` ⇒ 页面铺满外框、连标题栏 29px 也在页面里；
页面根必须 `mouse_filter = 2`，否则吞掉拖动区的点击、整窗拖不动）。

逐项算式：
  tabBar      = (BORDER_GAP + 5, 38) = (10, 38)；两枚「橙装打造 / 橙装精炼」
                每枚宽 = `tf.width + 6`（`MButton3.as:381-389`）= 4 字 × 12 + 6 = 54
  contentBg   = (BORDER_GAP, tabBar.y + 20 = 58)，尺寸 (376−10, 407−91) = (366, 316)
  contentBox  = 同 contentBg = (5, 58)，尺寸 366×316
  itemBox     = contentBox + (CONTENT_GAP, CONTENT_GAP) = (13, 66)，83×**200**
      · 放入装备  dropBtn: 盒内 x=(83−61)/2=11、y=10                      ⇒ 内容 (19,18)→(80,40)
      · 装备格    itemCell: 盒内 x=(83−40)/2=21.5、y=10+22+5=37          ⇒ 内容 (29,45)→(69,85)
      · 箭头      arrow: 本工程各打造页一律不画这条长箭头（先例：装备修复/梦幻属性符）⇒ 不建
  descTextField = contentBox + (itemBox.x + 83 + CONTENT_GAP, CONTENT_GAP)
                = (5+99, 66) = (104,66)，258×76                           ⇒ 内容 (99,8)→(357,84)
  _descBox.verticalGap = 5
  attentionTextField = descTextField 底 + 5 = (99,89)，258×95              ⇒ 内容 (99,89)→(357,184)
  _label      = contentBox + (CONTENT_GAP, itemBox底 + 2 = 210)，350×20    ⇒ 内容 (8,210)→(358,230)
  _caiLiaoBox = contentBox + (CONTENT_GAP, label底 + 6 = 236)，350×99      ⇒ 内容 (8,236)→(358,335)
      · _caiLiao1 盒内 (BORDER_GAP, BORDER_GAP) = (5,5)，100×64           ⇒ 材料框内 (5,5)
          - label    宽=100、高 16、居中对齐                               ⇒ 材料框内 (5,5)→(105,21)
          - itemCell (100−40)/2 = 30、y = 20                              ⇒ 材料框内 (35,25)→(75,65)
          - buyBtn   (100−37)/2 = 31.5、y = 20 + 40 + 3 = 63              ⇒ 材料框内 (36.5,68)→(73.5,90)
                     ⚠️ 宽 37 = `UIConfig.btn_width_two`（`ItemCaiLiaoBox.as:142`）；
                        不是按钮.png 的 57。场景里写真实宽，运行期再显式传同一尺寸。
      · _textField 盒内 (75,0)，240×99                                    ⇒ 材料框内 (75,0)
  _strengthBtn: `MButtonF` 宽 61、高 22
      · x = (376 − 61)/2 = 157.5；y = 407 − 22 − 5 = 380（挂在**窗口**上）
      ⇒ 换算到内容容器坐标 = (152.5, 322)→(213.5, 344)

⚠️ 本页没有原版基线图，像素对证做不了 —— 版式按上面这些 AS3 算式逐条生成；
`测试/橙装打造回归测试.gd` 钉的是**算式本身**和语言表文案。
"""
import io
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
出 = os.path.join(工程, "场景", "界面", "窗口", "橙装打造", "橙装打造窗.tscn")

正文 = '''[gd_scene load_steps=4 format=3]

[ext_resource type="Texture2D" path="res://素材/界面/原版窗口/通用控件/内容面板.png" id="1_bg"]
[ext_resource type="Texture2D" path="res://素材/界面/原版窗口/通用控件/子面板.png" id="2_pane"]
[ext_resource type="Texture2D" path="res://素材/界面/原版窗口/通用控件/物品格.png" id="3_slot"]

; 原版「橙装打造」窗（`YellowEquipLianZhiWindow.as`，`super(376,407)`），**页面 = 整个窗口**。
; 入口 = 背包双击「传说装备打造石」/「传说精炼石」（`ItemWindow2.as:979-988`）⇒
; `UIMain2.as:3961-3981 showYellowEquipLianZhiWindow(0/1)`：先 `centerTwoWindow(本窗, 背包)`
; 再 `init(tab)`，**连背包成对开**。
; 坐标出处见生成器 `开发工具/生成橙装打造场景.py` 的头注（逐条算式 + AS3 行号）。
; 常量：BORDER_GAP=5、CONTENT_GAP=8。**别手改本文件**。
[node name="原版橙装打造内容" type="Control"]
custom_minimum_size = Vector2(376, 407)
mouse_filter = 2

; `_contentBgSkin`（MYellow_background）：x = BORDER_GAP、y = tabBar.y + 20 = 58，366×316。
; `super(376,407)` 第三参缺省 false ⇒ UIWindow **不**画内容底；黄底由本页自烘（`内容底: false`）。
[node name="内容底" type="NinePatchRect" parent="."]
texture = ExtResource("1_bg")
patch_margin_left = 11
patch_margin_right = 10
patch_margin_top = 10
patch_margin_bottom = 11
offset_left = 5.0
offset_top = 58.0
offset_right = 371.0
offset_bottom = 374.0
mouse_filter = 2

; `_tabBar`：x = BORDER_GAP + 5 = 10、y = 38；两枚各 54 宽（`YELLOWEQUIP_TABBAR_NAMES`）。
[node name="分页" type="Control" parent="."]
offset_left = 10.0
offset_top = 38.0
offset_right = 118.0
offset_bottom = 60.0
mouse_filter = 2

[node name="橙装打造" type="Button" parent="分页"]
theme_type_variation = &"OrigTab"
offset_right = 54.0
offset_bottom = 22.0
toggle_mode = true
text = "橙装打造"

[node name="橙装精炼" type="Button" parent="分页"]
theme_type_variation = &"OrigTab"
offset_left = 54.0
offset_right = 108.0
offset_bottom = 22.0
toggle_mode = true
text = "橙装精炼"

; `_contentBox`：位置同内容背景、尺寸 (366,316)。
[node name="内容容器" type="Control" parent="."]
offset_left = 5.0
offset_top = 58.0
offset_right = 371.0
offset_bottom = 374.0
mouse_filter = 2

; `_itemBox`（ItemDropBox，83×200）整个盒挂在 (CONTENT_GAP, CONTENT_GAP)；
; 下面两件是**盒内**坐标，要再加盒原点（盒原点 = 内容 (8,8)）。
[node name="装备栏面板" type="NinePatchRect" parent="内容容器"]
texture = ExtResource("2_pane")
patch_margin_left = 8
patch_margin_right = 7
patch_margin_top = 7
patch_margin_bottom = 7
offset_left = 8.0
offset_top = 8.0
offset_right = 91.0
offset_bottom = 208.0
mouse_filter = 2

[node name="放入装备" type="Button" parent="内容容器"]
offset_left = 19.0
offset_top = 18.0
offset_right = 80.0
offset_bottom = 40.0
text = "放入装备"

[node name="装备格" type="TextureRect" parent="内容容器"]
offset_left = 29.0
offset_top = 45.0
offset_right = 69.0
offset_bottom = 85.0
texture = ExtResource("3_slot")
mouse_filter = 2

[node name="装备图标" type="TextureRect" parent="内容容器/装备格"]
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

; `_descTextField`（EquipLineTextArea 258×76）⇒ 内容 (99,8)。
[node name="说明" type="RichTextLabel" parent="内容容器"]
offset_left = 99.0
offset_top = 8.0
offset_right = 357.0
offset_bottom = 84.0
bbcode_enabled = true
scroll_active = false
mouse_filter = 2

; `_attentionTextField`（258×95）：`_descBox.verticalGap = 5` ⇒ 内容 (99,89)。
[node name="注意" type="RichTextLabel" parent="内容容器"]
offset_left = 99.0
offset_top = 89.0
offset_right = 357.0
offset_bottom = 184.0
bbcode_enabled = true
scroll_active = false
mouse_filter = 2

; `_label`（MGlowLabel，色 16748800、居中对齐、adjustContent=false）⇒ 内容 (8,210) 350×20。
[node name="标签" type="Label" parent="内容容器"]
offset_left = 8.0
offset_top = 210.0
offset_right = 358.0
offset_bottom = 230.0
theme_override_colors/font_color = Color(1, 0.568627, 0, 1)
horizontal_alignment = 1
mouse_filter = 2

; `_caiLiaoBox`（MPane 350×99）⇒ 内容 (8,236)。
[node name="材料框" type="NinePatchRect" parent="内容容器"]
texture = ExtResource("2_pane")
patch_margin_left = 8
patch_margin_right = 7
patch_margin_top = 7
patch_margin_bottom = 7
offset_left = 8.0
offset_top = 236.0
offset_right = 358.0
offset_bottom = 335.0
mouse_filter = 2

; `_caiLiao1`（ItemCaiLiaoBox(true) 100×64）⇒ 材料框内 (5,5)。
; ⚠ 打造页 `y = BORDER_GAP + 10 = 15`、精炼页 `y = BORDER_GAP = 5`（`updateView` 两个 case），
;   运行期按页签挪；场景里先摆精炼页的 (5,5)。
[node name="材料一" type="Control" parent="内容容器/材料框"]
offset_left = 5.0
offset_top = 5.0
offset_right = 105.0
offset_bottom = 69.0
mouse_filter = 2

; `_caiLiao1.label`：宽 = _width = 100、12 号、橙、粗体、居中。
[node name="材料名" type="Label" parent="内容容器/材料框/材料一"]
offset_right = 100.0
offset_bottom = 16.0
theme_override_colors/font_color = Color(1, 0.568627, 0, 1)
theme_override_font_sizes/font_size = 12
horizontal_alignment = 1
mouse_filter = 2

; `itemCell`：x = (100−40)/2 = 30、y = 20。
[node name="材料格" type="TextureRect" parent="内容容器/材料框/材料一"]
offset_left = 30.0
offset_top = 20.0
offset_right = 70.0
offset_bottom = 60.0
texture = ExtResource("3_slot")
mouse_filter = 2

[node name="材料图标" type="TextureRect" parent="内容容器/材料框/材料一/材料格"]
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

[node name="材料数量" type="Label" parent="内容容器/材料框/材料一/材料格"]
layout_mode = 1
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -26.0
offset_top = -18.0
offset_right = -2.0
offset_bottom = -2.0
grow_horizontal = 0
grow_vertical = 0
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_font_sizes/font_size = 14
horizontal_alignment = 2
vertical_alignment = 2
mouse_filter = 2

; `buyBtn`（ItemCaiLiaoBox(true) 的购买）：x = (100−37)/2 = 31.5、y = 20 + 40 + 3 = 63。
; 只有精炼页显示（打造页 `_caiLiao1.buyBtn.visible = false`）。
[node name="购买" type="Button" parent="内容容器/材料框/材料一"]
offset_left = 31.5
offset_top = 63.0
offset_right = 68.5
offset_bottom = 85.0
text = "购买"

; `_textField`（TextArea2 240×99，白字居中 leading 4）⇒ 材料框内 (75,0)。
[node name="消耗文本" type="RichTextLabel" parent="内容容器/材料框"]
offset_left = 75.0
offset_right = 315.0
offset_bottom = 99.0
bbcode_enabled = true
scroll_active = false
mouse_filter = 2

; `_strengthBtn`（MButtonF 61×22）原版挂在**窗口**上：
; x = (376−61)/2 = 157.5、y = 407−22−5 = 380 ⇒ 内容容器坐标 (152.5,322)。
[node name="开始打造" type="Button" parent="内容容器"]
offset_left = 152.5
offset_top = 322.0
offset_right = 213.5
offset_bottom = 344.0
text = "开始打造"
'''

os.makedirs(os.path.dirname(出), exist_ok=True)
io.open(出, "w", encoding="utf-8", newline="\n").write(正文)
print("生成 %s：%d 行" % (os.path.relpath(出, 工程), 正文.count("\n")))
