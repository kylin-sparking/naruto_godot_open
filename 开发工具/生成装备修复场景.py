# -*- coding: utf-8 -*-
"""生成 `场景/界面/窗口/装备修复/装备修复窗.tscn`（原版 `EquipRepairWindow.as`，360×407）。

**改真值改这里，别手改 .tscn**（手改会被下一次生成吃掉）。

坐标全部来自 `EquipRepairWindow.createChildren():267-340` **逐行算出来的**，不是估的：
常量 `BORDER_GAP = 5`、`CONTENT_GAP = 8`（`UIConfig.as:890/892`）。
窗口局部坐标 1:1（尺寸表口径同「装备强化」：`整框: true`、`原点: [0,0]` ⇒ 页面铺满外框、
连标题栏那 29px 也在页面里；页面根必须 `mouse_filter = 2`，否则吞掉拖动区的点击、
整窗拖不动 —— 那个坑 2026-10-01 在打造窗上撞过，见 `装备强化窗口.tscn` 的头注）。

逐项算式（都写下来，免得下一个人再推一遍）：
  contentBox  = (BORDER_GAP, tabBar.y + 20) = (5, 58)，尺寸 (360−10, 407−91) = (350, 316)
  itemBox     = contentBox + (CONTENT_GAP, CONTENT_GAP) = (13, 66)，83×175（`ItemDropBox`）
      · 放入装备  dropBtn: 盒内 x=(83−61)/2=11、y=10            ⇒ 绝对 (24,76)→(85,98)
      · 装备格    itemCell: 盒内 x=(83−40)/2=21、y=10+22+5=37   ⇒ 绝对 (34,103)→(74,143)
  descBox     = contentBox + (itemBox.x + 83 + CONTENT_GAP, CONTENT_GAP)
              = (5+99, 66) = (104,66)，244×180，verticalGap 5（VBox）
      · 说明     244×76  ⇒ (104,66)→(348,142)
      · 注意     244×94  ⇒ (104,147)→(348,241)
  _label      = contentBox + (CONTENT_GAP, itemBox底+2 = 8+175+2=185) ⇒ (13,243) 334×20
  _caiLiaoBox = contentBox + (CONTENT_GAP, label底 +6 = 185+20+6=211) ⇒ (13,269) 334×99
      · 材料格   盒内 (BORDER_GAP,BORDER_GAP)=(5,5) ⇒ (18,274) 60×64
      · 消耗几率 盒内 (75,0)                        ⇒ (88,269) 240×99
  _strengthBtn: `MButtonF`，宽 `btn_width_four` = 61、高 22（与放入装备同族）
      · x = 360 − 61 − 5 = 294；y = 407 − 22 − 6 = 379  ⇒ (294,379)→(355,401)
  页签        : `_tabBar.x = BORDER_GAP + 5 = 10`、`y = 38`；`dataProvider` **只有一项**
                「修复」（`EQUIP_STRENGTH_TAB_NAMES_5`）⇒ 宽取 2 字页签那档 `btn_width_two` = 37。

⚠️ 本页**没有原版基线图**，像素对证做不了（同「幸运合成面板」那条口径）——
版式按上面这些 AS3 算式逐条生成；`测试/装备修复页回归测试.gd` 钉的是**算式本身**。
"""
import io
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
出 = os.path.join(工程, "场景", "界面", "窗口", "装备修复", "装备修复窗.tscn")

皮_物品格 = "res://素材/界面/原版窗口/通用控件/物品格.png"

头 = '''[gd_scene load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://素材/界面/原版窗口/通用控件/物品格.png" id="1_slot"]

; 原版「破碎装备修复」窗（`EquipRepairWindow.as`，`super(360,407)`），**页面 = 整个窗口**。
; 由 `onClickPopupMenu :802 showEquipRepairWindow(0, curCellData)` 打开
; （只有**破碎**的装备菜单里才有「破碎修复」那一项）。
;
; ⚠️ 它**不是**「装备打造」窗的一页：打造窗是 `EquipStrengthWindow`（664×407、十个页签），
; 本窗是 360×407、页签**只有一枚**「修复」（`_tabBar.dataProvider = [EQUIP_STRENGTH_TAB_NAMES_5]`
; —— 语言表里那个"孤儿"键就是给它用的）。提交也不同：打造窗走 `ITEM_CHANGE` 5/4/…，
; 本窗走 **`requestRecoverEquip` = 子命令 8**（`EquipRepairWindow.strengthEquip:370-377`）。
;
; 坐标出处见生成器 `开发工具/生成装备修复场景.py` 的头注（逐条算式 + AS3 行号）。
; 常量：BORDER_GAP=5、CONTENT_GAP=8。**别手改本文件**。
[node name="原版装备修复内容" type="Control"]
custom_minimum_size = Vector2(360, 407)
mouse_filter = 2

[node name="外框" type="Panel" parent="."]
offset_right = 360.0
offset_bottom = 407.0
mouse_filter = 2

; `_tabBar`：x = BORDER_GAP + 5 = 10、y = 38；只有一枚「修复」。
[node name="分页" type="Control" parent="."]
offset_left = 10.0
offset_top = 38.0
offset_right = 47.0
offset_bottom = 58.0
mouse_filter = 2

[node name="修复" type="Button" parent="分页"]
offset_right = 37.0
offset_bottom = 20.0
toggle_mode = true
text = "修复"

; `_contentBgSkin`（MYellow_background）：x = BORDER_GAP、y = tabBar.y + 20 = 58。
[node name="内容背景" type="Panel" parent="."]
offset_left = 5.0
offset_top = 58.0
offset_right = 355.0
offset_bottom = 374.0

; `_contentBox`：位置同内容背景、尺寸 (350,316)。
[node name="内容容器" type="Control" parent="."]
offset_left = 5.0
offset_top = 58.0
offset_right = 355.0
offset_bottom = 374.0
mouse_filter = 2

; `_itemBox`（ItemDropBox，83×175）整个盒挂在 (CONTENT_GAP, CONTENT_GAP) = (13,66)；
; 下面三件是**盒内**坐标，要再加这个盒原点。
[node name="装备栏面板" type="Panel" parent="内容容器"]
offset_left = 8.0
offset_top = 8.0
offset_right = 91.0
offset_bottom = 183.0

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
texture = ExtResource("1_slot")
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

; `_descBox`（VBox 244×180、verticalGap 5）挂在 (104,66)：说明 244×76 + 注意 244×94。
[node name="说明" type="RichTextLabel" parent="内容容器"]
offset_left = 99.0
offset_top = 8.0
offset_right = 343.0
offset_bottom = 84.0
bbcode_enabled = true
mouse_filter = 2

[node name="注意" type="RichTextLabel" parent="内容容器"]
offset_left = 99.0
offset_top = 89.0
offset_right = 343.0
offset_bottom = 183.0
bbcode_enabled = true
mouse_filter = 2

; `_label`（MGlowLabel，色 16748800、居中对齐、adjustContent=false）挂在 (8,185)。
[node name="标签" type="Label" parent="内容容器"]
offset_left = 8.0
offset_top = 185.0
offset_right = 342.0
offset_bottom = 205.0
theme_override_colors/font_color = Color(1, 0.611765, 0.247059, 1)
horizontal_alignment = 1
mouse_filter = 2

; `_caiLiaoBox`（MPane 334×99）挂在 (8,211)。
[node name="材料框" type="Panel" parent="内容容器"]
offset_left = 8.0
offset_top = 211.0
offset_right = 342.0
offset_bottom = 310.0

[node name="材料格" type="TextureRect" parent="内容容器/材料框"]
offset_left = 5.0
offset_top = 5.0
offset_right = 65.0
offset_bottom = 69.0
texture = ExtResource("1_slot")
mouse_filter = 2

[node name="材料图标" type="TextureRect" parent="内容容器/材料框/材料格"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
expand_mode = 1
stretch_mode = 5
mouse_filter = 2

[node name="材料数量" type="Label" parent="内容容器/材料框/材料格"]
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
theme_override_font_sizes/font_size = 12
horizontal_alignment = 2
vertical_alignment = 2
mouse_filter = 2

; `_textField`（消耗/几率，居中、leading 4）挂在材料框内 (75,0)。
[node name="消耗几率" type="RichTextLabel" parent="内容容器/材料框"]
offset_left = 75.0
offset_right = 315.0
offset_bottom = 99.0
bbcode_enabled = true
mouse_filter = 2

; `_strengthBtn`（MButtonF，61×22）原版挂在**窗口**上（`addChild` 不在 contentBox 里）：
; x = 360−61−5 = 294、y = 407−22−5 = 380 ⇒ 换到内容容器坐标就是 (289,322)。
[node name="开始修复" type="Button" parent="内容容器"]
offset_left = 289.0
offset_top = 322.0
offset_right = 350.0
offset_bottom = 344.0
text = "开始修复"
'''

正文 = 头
os.makedirs(os.path.dirname(出), exist_ok=True)
io.open(出, "w", encoding="utf-8", newline="\n").write(正文)
print("生成 %s：%d 行" % (os.path.relpath(出, 工程), 正文.count("\n")))
