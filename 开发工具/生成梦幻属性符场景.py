# -*- coding: utf-8 -*-
"""生成 `场景/界面/窗口/梦幻属性符/梦幻属性符窗.tscn`
（原版 `MengHuanPropResetWindow.as`，`super(360,432)`）。

**改真值改这里，别手改 .tscn**（手改会被下一次生成吃掉）。

坐标全部来自 `MengHuanPropResetWindow.createChildren():226-337` **逐行算出来的**：
常量 `BORDER_GAP = 5`、`CONTENT_GAP = 8`（`UIConfig.as:890/892`）。
窗口局部坐标 1:1（尺寸表 `整框: true`、`原点: [0,0]` ⇒ 页面铺满外框、连标题栏 29px 也在页面里；
页面根必须 `mouse_filter = 2`，否则吞掉拖动区的点击、整窗拖不动）。

逐项算式：
  tabBar      = (BORDER_GAP + 5, 38) = (10, 38)；只有一枚「附加属性梦幻数值重置」
                宽度 = `tf.width + 6`（`MButton3.as:381-389`）= 120 + 6 = 126
  contentBg   = (BORDER_GAP, tabBar.y + 20 = 58)，尺寸 (360−10, 432−91) = (350, 341)
  contentBox  = 同 contentBg = (5, 58)，尺寸 350×341
  itemBox     = contentBox + (CONTENT_GAP, CONTENT_GAP) = (13, 66)，83×**200**
      · 放入装备  dropBtn: 盒内 x=(83−61)/2=11、y=10                      ⇒ 内容 (19,18)→(80,40)
      · 装备格    itemCell: 盒内 x=(83−40)/2=21.5、y=10+22+5=37          ⇒ 内容 (29,45)→(69,85)
      · 箭头      arrow: 盒内 x=(83−14)/2=34.5、y=37+40=77、高=200−77−10=113
                  （本工程各打造页一律不画这条长箭头，先例：装备修复/洗附加数值页 ⇒ 不建）
  descTextField = contentBox + (itemBox.x + 83 + CONTENT_GAP, CONTENT_GAP)
                = (5+99, 66) = (104,66)，244×75                           ⇒ 内容 (99,8)→(343,83)
  descBox     = (descTextField.x, descTextField.y + 75)                    ⇒ 内容 (99,83)，行 y = i*20
  LineHPicF   = (descTextField.x, itemBox.y + itemBox.height − 2 = 206)    ⇒ 内容 (99,206)，宽 244
  _label      = contentBox + (CONTENT_GAP, itemBox底 + 2 = 210)，334×20    ⇒ 内容 (8,210)→(342,230)
  _caiLiaoBox = contentBox + (CONTENT_GAP, label底 + 6 = 236)，334×99      ⇒ 内容 (8,236)→(342,335)
      · _caiLiao1 盒内 (BORDER_GAP, BORDER_GAP) = (5,5)，70×64            ⇒ 材料框内 (5,5)
          - label    宽=70、高 16、居中对齐                                ⇒ 材料框内 (5,5)→(75,21)
          - itemCell (70−40)/2 = 15、y = 20                               ⇒ 材料框内 (20,25)→(60,65)
          - buyBtn   (70−61)/2 = 4.5、y = itemCell.y + 40 + 3 = 63        ⇒ 材料框内 (9.5,68)→(70.5,90)
      · _textField 盒内 (90,23)，240×60                                   ⇒ 材料框内 (90,23)→(330,83)
      · _previewPropItem = (_textField.x + 2, _textField.y + 32) = (92,55)
  _strengthBtn: `MButtonF` 宽 61、高 22
      · x = (360 − 61)/2 = 149.5；y = 432 − 22 − 5 = 405（挂在**窗口**上）
      ⇒ 换算到内容容器坐标 = (144.5, 347)→(205.5, 369)

⚠️ 本页没有原版基线图，像素对证做不了 —— 版式按上面这些 AS3 算式逐条生成；
`测试/梦幻属性符回归测试.gd` 钉的是**算式本身**和语言表文案。
"""
import io
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
出 = os.path.join(工程, "场景", "界面", "窗口", "梦幻属性符", "梦幻属性符窗.tscn")

正文 = '''[gd_scene load_steps=4 format=3]

[ext_resource type="Texture2D" path="res://素材/界面/原版窗口/通用控件/内容面板.png" id="1_bg"]
[ext_resource type="Texture2D" path="res://素材/界面/原版窗口/通用控件/子面板.png" id="2_pane"]
[ext_resource type="Texture2D" path="res://素材/界面/原版窗口/通用控件/物品格.png" id="3_slot"]
[ext_resource type="Texture2D" path="res://素材/界面/原版窗口/通用控件/横向分隔线.png" id="4_line"]

; 原版「梦幻属性符」窗（`MengHuanPropResetWindow.as`，`super(360,432)`），**页面 = 整个窗口**。
; 入口 = 背包双击「梦幻属性符」（`ItemWindow2.as:953-967 useItem` 的那一支）⇒
; `UIMain2.as:5651-5664 showMengHuanPropRestWindow` 先 `centerTwoWindow(梦幻窗, 背包)` 再 `showPropPanle(符)`。
; 坐标出处见生成器 `开发工具/生成梦幻属性符场景.py` 的头注（逐条算式 + AS3 行号）。
; 常量：BORDER_GAP=5、CONTENT_GAP=8。**别手改本文件**。
[node name="原版梦幻属性符内容" type="Control"]
custom_minimum_size = Vector2(360, 432)
mouse_filter = 2

; `_contentBgSkin`（MYellow_background）：x = BORDER_GAP、y = tabBar.y + 20 = 58，350×341。
; `super(360,432)` 第三参缺省 false ⇒ UIWindow **不**画内容底；黄底由本页自烘（`内容底: false`）。
[node name="内容底" type="NinePatchRect" parent="."]
texture = ExtResource("1_bg")
patch_margin_left = 11
patch_margin_right = 10
patch_margin_top = 10
patch_margin_bottom = 11
offset_left = 5.0
offset_top = 58.0
offset_right = 355.0
offset_bottom = 399.0
mouse_filter = 2

; `_tabBar`：x = BORDER_GAP + 5 = 10、y = 38；只有一枚，宽 = `tf.width + 6` = 126。
[node name="分页" type="Control" parent="."]
offset_left = 10.0
offset_top = 38.0
offset_right = 136.0
offset_bottom = 60.0
mouse_filter = 2

[node name="附加属性梦幻数值重置" type="Button" parent="分页"]
theme_type_variation = &"OrigTab"
offset_right = 126.0
offset_bottom = 22.0
toggle_mode = true
text = "附加属性梦幻数值重置"

; `_contentBox`：位置同内容背景、尺寸 (350,341)。
[node name="内容容器" type="Control" parent="."]
offset_left = 5.0
offset_top = 58.0
offset_right = 355.0
offset_bottom = 399.0
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

; `_descTextField`（EquipLineTextArea 244×75）⇒ 内容 (99,8)。
[node name="说明" type="RichTextLabel" parent="内容容器"]
offset_left = 99.0
offset_top = 8.0
offset_right = 343.0
offset_bottom = 83.0
bbcode_enabled = true
scroll_active = false
mouse_filter = 2

; `_descBox`（Sprite）⇒ 内容 (99,83)；每行 PropItem 高 20（`drawPropView:119` `y = i*20`）。
[node name="属性列表" type="Control" parent="内容容器"]
offset_left = 99.0
offset_top = 83.0
offset_right = 343.0
offset_bottom = 206.0
mouse_filter = 2

; `LineHPicF`：x = descTextField.x、y = itemBox.y + itemBox.height − 2 = 206，宽 244。
[node name="分隔线" type="TextureRect" parent="内容容器"]
offset_left = 99.0
offset_top = 206.0
offset_right = 343.0
offset_bottom = 208.0
texture = ExtResource("4_line")
expand_mode = 1
stretch_mode = 1
mouse_filter = 2

; `_label`（MGlowLabel，色 16748800、居中对齐、adjustContent=false）⇒ 内容 (8,210) 334×20。
[node name="标签" type="Label" parent="内容容器"]
offset_left = 8.0
offset_top = 210.0
offset_right = 342.0
offset_bottom = 230.0
theme_override_colors/font_color = Color(1, 0.568627, 0, 1)
horizontal_alignment = 1
mouse_filter = 2

; `_caiLiaoBox`（MPane 334×99）⇒ 内容 (8,236)。
[node name="材料框" type="NinePatchRect" parent="内容容器"]
texture = ExtResource("2_pane")
patch_margin_left = 8
patch_margin_right = 7
patch_margin_top = 7
patch_margin_bottom = 7
offset_left = 8.0
offset_top = 236.0
offset_right = 342.0
offset_bottom = 335.0
mouse_filter = 2

; `_caiLiao1`（ItemCaiLiaoBox(true) 70×64）⇒ 材料框内 (5,5)。
[node name="材料一" type="Control" parent="内容容器/材料框"]
offset_left = 5.0
offset_top = 5.0
offset_right = 75.0
offset_bottom = 69.0
mouse_filter = 2

; `_caiLiao1.label`：宽 = _width = 70、12 号、橙、粗体、居中。
[node name="材料名" type="Label" parent="内容容器/材料框/材料一"]
offset_right = 70.0
offset_bottom = 16.0
theme_override_colors/font_color = Color(1, 0.568627, 0, 1)
theme_override_font_sizes/font_size = 12
horizontal_alignment = 1
mouse_filter = 2

; `itemCell`：x = (70−40)/2 = 15、y = 20。
[node name="材料格" type="TextureRect" parent="内容容器/材料框/材料一"]
offset_left = 15.0
offset_top = 20.0
offset_right = 55.0
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

; `buyBtn`（ItemCaiLiaoBox(true) 的购买）：x = (70−61)/2 = 4.5、y = 20 + 40 + 3 = 63。
[node name="购买" type="Button" parent="内容容器/材料框/材料一"]
offset_left = 4.5
offset_top = 63.0
offset_right = 65.5
offset_bottom = 85.0
text = "购买"

; `_textField`（TextArea2 240×60，白字 leading 4）⇒ 材料框内 (90,23)。
[node name="需要文" type="RichTextLabel" parent="内容容器/材料框"]
offset_left = 90.0
offset_top = 23.0
offset_right = 330.0
offset_bottom = 83.0
bbcode_enabled = true
scroll_active = false
mouse_filter = 2

; `_previewPropItem`（PropItem(null,false)）：x = 90+2、y = 23+32 ⇒ 材料框内 (92,55)。
[node name="预览属性" type="Control" parent="内容容器/材料框"]
offset_left = 92.0
offset_top = 55.0
offset_right = 336.0
offset_bottom = 75.0
mouse_filter = 2

[node name="属性值" type="Label" parent="内容容器/材料框/预览属性"]
offset_right = 104.0
offset_bottom = 20.0
theme_override_colors/font_color = Color(0.729412, 0.003922, 0.976471, 1)
mouse_filter = 2

[node name="结果" type="Label" parent="内容容器/材料框/预览属性"]
offset_left = 105.0
offset_right = 210.0
offset_bottom = 20.0
theme_override_colors/font_color = Color(1, 0.568627, 0, 1)
mouse_filter = 2

; `_strengthBtn`（MButtonF 61×22）原版挂在**窗口**上：
; x = (360−61)/2 = 149.5、y = 432−22−5 = 405 ⇒ 内容容器坐标 (144.5,347)。
[node name="开始重置" type="Button" parent="内容容器"]
offset_left = 144.5
offset_top = 347.0
offset_right = 205.5
offset_bottom = 369.0
text = "开始重置"
'''

os.makedirs(os.path.dirname(出), exist_ok=True)
io.open(出, "w", encoding="utf-8", newline="\n").write(正文)
print("生成 %s：%d 行" % (os.path.relpath(出, 工程), 正文.count("\n")))
