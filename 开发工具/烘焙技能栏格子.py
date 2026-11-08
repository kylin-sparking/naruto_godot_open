# -*- coding: utf-8 -*-
"""把底栏技能格的**静态那一半**烤进 `场景/界面/技能面板.tscn`（编辑器=运行期这条规矩）。

烤进去的东西（全部有原版出处，见 `真值/窗口/技能栏.md`）：
  * 底板皮：元件 **398**（`ShortcutColumnPaneCell` 时间轴里名为 `cellBg` 的那张，40x40）
    —— 换掉我们原先用的 `hud_396.png`（与 398 有 1432/1600 个像素不一样，是另一张皮）。
  * 标号 Label：节点名统一成 `KeyLabel`，位置 (2,1)、字号 11、颜色 #FEF37D、描边 3 无阴影
    —— 出处 `KeyboardCell.as:49-58`（建 label）+ `:97-116`（底栏那一排走 #FEF37D）。

跑法：python 开发工具/烘焙技能栏格子.py
⚠ 跑之前确认这张场景**没在编辑器里开着**（`list_open_scenes`），否则编辑器一存盘就把这些盖掉。
"""
import io
import os
import re

工程 = r'.'
场景 = os.path.join(工程, '场景', '界面', '技能面板.tscn')
新皮 = 'res://素材/界面/技能面板/技能格底板.png'
旧皮 = 'res://素材/界面/技能面板/hud_396.png'
标号色 = 'Color(0.99607844, 0.9529412, 0.49019608, 1)'


def 取uid(资源路):
    """从 .import 边车里读 Godot 给这张图分配的 uid（没有就返回空串，让 Godot 按路径解）。"""
    边车 = os.path.join(工程, 资源路.replace('res://', '').replace('/', os.sep) + '.import')
    if not os.path.exists(边车):
        return ''
    with io.open(边车, encoding='utf-8', errors='replace') as f:
        for line in f:
            m = re.match(r'^uid="(uid://[^"]+)"', line.strip())
            if m:
                return m.group(1)
    return ''


def main():
    文 = io.open(场景, encoding='utf-8', newline='').read()
    行尾 = '\r\n' if '\r\n' in 文[:4000] else '\n'
    报 = []

    # 1) 新皮进 ext_resource（沿用已存在的 id 就只换 path，避免留一条没人用的引用）
    旧id = None
    for m in re.finditer(r'\[ext_resource type="Texture2D"([^\]]*)path="([^"]+)"([^\]]*)id="([^"]+)"', 文):
        if m.group(2) == 旧皮:
            旧id = m.group(4)
            报.append('找到旧底板 ext_resource id=%s' % 旧id)
            break
    if 旧id is None:
        # 已经烤过一轮（路径已是新皮）→ 沿用同一个 id，别报"找不到"
        for m in re.finditer(r'\[ext_resource type="Texture2D"([^\]]*)path="([^"]+)"([^\]]*)id="([^"]+)"', 文):
            if m.group(2) == 新皮:
                旧id = m.group(4)
                报.append('底板 ext_resource 已是新皮，id=%s（跳过换皮）' % 旧id)
                break
    if 旧id is None:
        raise SystemExit('没找到指向 %s 的 ext_resource —— 场景结构变了，先人工看' % 旧皮)
    uid = 取uid(新皮)
    头 = '[ext_resource type="Texture2D"' + (' uid="%s"' % uid if uid else '')
    文 = re.sub(r'\[ext_resource type="Texture2D"[^\]]*id="%s"\]' % re.escape(旧id),
                '%s path="%s" id="%s"]' % (头, 新皮, 旧id), 文, count=1)
    报.append('ext_resource %s -> %s (uid=%s)' % (旧皮, 新皮, uid or '无'))

    # 2) 十格的标号 Label：改名 + 按真值重写属性
    标号块 = 行尾.join([
        'layout_mode = 0',
        'offset_left = 2.0',
        'offset_top = 1.0',
        'offset_right = 20.0',
        'offset_bottom = 15.0',
        'theme_override_colors/font_color = %s' % 标号色,
        'theme_override_colors/font_outline_color = Color(0, 0, 0, 1)',
        'theme_override_constants/outline_size = 3',
        'theme_override_font_sizes/font_size = 11',
        'text = "%s"',
        'mouse_filter = 2',
    ])
    改 = 0
    for 序号 in range(10):
        键 = _slot_key_text(序号)
        段 = re.search(
            r'\[node name="[^"]+" type="Label" parent="技能栏/SkillShortcut%d"[^\]]*\][^\[]*' % 序号, 文)
        if 段 is None:
            报.append('第 %d 格没找到标号 Label（跳过）' % 序号)
            continue
        原 = 段.group(0)
        头行 = 原.split(行尾)[0]
        名 = re.search(r'\[node name="([^"]+)"', 头行).group(1)
        # unique_id 是编辑器给的，改名时**原样带过去**（禁止手写一个新 id）
        号 = re.search(r'unique_id=(\d+)', 头行)
        新头 = '[node name="KeyLabel" type="Label" parent="技能栏/SkillShortcut%d"%s]' % (
            序号, (' unique_id=' + 号.group(1)) if 号 else '')
        # 文本行原本就在里面，保留它自己的顺序：直接整段换成烤好的块
        新 = 新头 + 行尾 + 标号块.replace('"%s"', '"%s"' % 键) + 行尾 + 行尾
        文 = 文.replace(原, 新, 1)
        改 += 1
    报.append('标号 Label 烤了 %d/10 格（原名 @Label@14x -> KeyLabel，挂在 ShortcutFrame 下）' % 改)

    # 3) 十格的摆位：元件 406 `MenuPaneF` 时间轴 `shortcutColumnPane @(249,5)`，
    #    元件 405 时间轴 cell0..4 @(0,42)(41,42)(82,42)(123,42)(164,42)、
    #    cell5..9 @(287,42)(328,369… 见 格x表)。本场景 `技能栏` 的原点相对元件 406
    #    是 x−11（`menuBg` 就摆在 −11），⇒ 格子左边 = 249 − 11 + 元件内 x。
    #    烤之前是 236/276/317/359/399 · 521/563/604/646/686 ⇒ 步距 40/41/42/40 不匀，
    #    空格子的缝一眼看得出来（原版恒 41）。y 一直是对的：5 + 42 = 47。
    改格 = 0
    行 = 文.split(行尾)
    for 序号 in range(10):
        左 = 格x(序号)
        try:
            起 = next(i for i, s in enumerate(行)
                      if s.startswith('[node name="SkillShortcut%d"' % 序号) and 'parent="技能栏"' in s)
        except StopIteration:
            报.append('第 %d 格节点没找到（跳过摆位）' % 序号)
            continue
        j = 起 + 1
        while j < len(行) and 行[j].strip():
            for 键, 值 in (('offset_left', 左), ('offset_top', 47.0),
                           ('offset_right', 左 + 40), ('offset_bottom', 87.0)):
                if 行[j].startswith(键 + ' = '):
                    行[j] = '%s = %s' % (键, _f(值))
            j += 1
        改格 += 1
    文 = 行尾.join(行)
    报.append('格子摆位烤了 %d/10（步距恒 41、第五→第六格空 83 给灵气球）' % 改格)

    # 4) 标号的**粗体**：`KeyboardCell.as:50` 构造即 `setKeyTextFormat()`，默认 `true`
    #    ⇒ `keyTextField.bold = true`（`:64-67`）。simsun 没有独立粗体字面 ⇒ 合成加粗
    #    = `FontVariation.variation_embolden`（⚠ `base_font` 必须写，否则整枚不渲染）。
    #    运行期那一份由 `技能面板.取标号字体()` 给，这里烤的是**编辑器里看到的**那一份。
    #    ⚠ 粗体量**只有一个源** = 控制器里那条 const，这里现读，不许各写一份。
    控制 = io.open(os.path.join(工程, '脚本', '界面', '技能面板.gd'), encoding='utf-8').read()
    粗 = re.search(r'const 标号粗体量 := ([\d.]+)', 控制)
    if 粗 is None:
        print('读不到 `const 标号粗体量` —— 控制器改名了？烤出来的场景会与运行期不一致')
        raise SystemExit(1)
    粗量 = float(粗.group(1))
    字体路 = 'res://素材/界面/simsun_原版.ttf'
    字体uid = 取uid(字体路) or 'uid://bn03t3hn8jr3d'
    if 'path="%s"' % 字体路 not in 文:
        末ext = 文.rindex('[ext_resource')
        换 = 文.index(行尾, 末ext)
        文 = 文[:换 + len(行尾)] + (
            '[ext_resource type="FontFile" uid="%s" path="%s" id="70_simsun"]%s'
            % (字体uid, 字体路, 行尾)) + 文[换 + len(行尾):]
        报.append('新增 simsun ext_resource（uid=%s）' % 字体uid)
    else:
        报.append('simsun ext_resource 已在')
    # ⚠ 认"有没有这枚字资源"**不许认我自己起的那个 id** —— 编辑器一存盘就会把它
    #   改成自动名（实测：`FontVariation_标号粗体` → `FontVariation id="jb642"`），
    #   那时再按 id 找就找不到 ⇒ 又插一份重复字资源、十格引用还指在旧名上。
    字块 = re.search(r'\[sub_resource type="FontVariation" id="([^"]+)"\]', 文)
    字id = 字块.group(1) if 字块 else 'FontVariation_标号粗体'
    if 字块 is None:
        首sub = 文.index('[sub_resource')
        文 = 文[:首sub] + (
            '[sub_resource type="FontVariation" id="%s"]' % 字id + 行尾
            + 'base_font = ExtResource("70_simsun")' + 行尾
            + 'variation_embolden = %s' % _g(粗量) + 行尾 + 行尾) + 文[首sub:]
        报.append('新增 FontVariation %s（embolden %s）' % (字id, 粗量))
    else:
        文 = re.sub(r'variation_embolden = [-\d.]+', 'variation_embolden = %s' % _g(粗量), 文, count=1)
        报.append('FontVariation 已在（id=%s，embolden 复位成 %s）' % (字id, 粗量))
    烤字 = 0
    for 序号 in range(10):
        段 = re.search(
            r'\[node name="KeyLabel" type="Label" parent="技能栏/SkillShortcut%d"[^\]]*\]%s((?:[^\n]*%s)*?)%s'
            % (序号, 行尾, 行尾, 行尾), 文)
        if 段 is None:
            报.append('第 %d 格 KeyLabel 段没找到（跳过字体）' % 序号)
            continue
        体 = 段.group(1)
        新体 = re.sub(r'theme_override_fonts/font = SubResource\("[^"]+"\)',
                        'theme_override_fonts/font = SubResource("%s")' % 字id, 体)
        if 'theme_override_fonts/font' not in 新体:
            新体 = ('theme_override_fonts/font = SubResource("%s")' % 字id) + 行尾 + 新体
        文 = 文[:段.start(1)] + 新体 + 文[段.end(1):]
        烤字 += 1
    报.append('标号粗体烤了 %d/10 格' % 烤字)

    # 5) 底条 `menuBg`（元件 296，天然 **989×50**）的框必须等于天然尺寸。
    #    烤之前是 -11..977 = 988 宽 ⇒ 整条被 988/989 非整数缩放，1 像素宽的"格子间分隔亮线"
    #    被重采样抹成一摊（越往右偏得越多，实测右边三道缝直接变黑 = 用户看到的"细条没了、变粗"）。
    皮名 = 'res://素材/界面/技能面板/hud_294.png'
    皮宽, 皮高 = png尺寸(os.path.join(工程, 皮名.replace('res://', '').replace('/', os.sep)))
    段 = re.search(r'(\[node name="@TextureRect@111"[^\]]*parent="技能栏"[^\]]*\]\n)((?:[^\n]*\n)*?)\n', 文)
    if 段 is None:
        print('找不到底条节点 @TextureRect@111 —— 场景结构变了')
        raise SystemExit(1)
    属 = dict(re.findall(r'(offset_\w+) = ([-\d.]+)', 段.group(2)))
    新体 = 段.group(2)
    for 键, 值 in (('offset_right', float(属['offset_left']) + 皮宽),
                   ('offset_bottom', float(属['offset_top']) + 皮高)):
        新体 = re.sub(r'%s = [-\d.]+' % 键, '%s = %s' % (键, _f(值)), 新体)
    文 = 文[:段.start(2)] + 新体 + 文[段.end(2):]
    报.append('底条框烤成天然尺寸 %dx%d（右=%s 底=%s）' % (
        皮宽, 皮高, _f(float(属['offset_left']) + 皮宽), _f(float(属['offset_top']) + 皮高)))
    # 半截烤完不许装作成功：正则一坏就是"文件写了、东西没写"。
    if 改 < 10 or 改格 < 10 or 烤字 < 10:
        # 长中文走 SystemExit 在 GBK 控制台会糊，先 print 再退
        print('没烤全：标号 %d/10、摆位 %d/10、粗体 %d/10 —— 场景结构与脚本假设不符，别用'
              % (改, 改格, 烤字))
        raise SystemExit(1)

    io.open(场景, 'w', encoding='utf-8', newline='').write(文)
    with io.open('烘焙技能栏.txt', 'w', encoding='utf-8') as f:
        f.write(行尾.join(报))
    print('done')


def _slot_key_text(槽):
    return '0' if 槽 == 9 else str(槽 + 1)


# 元件 405 `ShortcutColumnPaneF` 时间轴里十枚格子的 x（现查：`读符号时间轴.py --符号 405`）
元件格x = [0, 41, 82, 123, 164, 287, 328, 369, 410, 451]
# 元件 406 `MenuPaneF` 里 `shortcutColumnPane @(249,5)`；本场景 `技能栏` 原点相对元件 406 是 x−11
格原点 = 249 - 11


def 格x(槽):
    return float(格原点 + 元件格x[槽])


def _f(v):
    return ('%g' % v) + ('' if '.' in ('%g' % v) else '.0')


def _g(v):
    """Godot 文本资源里的浮点写法（0.8 就写 0.8，不写 0.80000001）。"""
    return repr(float(v))


def png尺寸(路):
    """不依赖 PIL：PNG 的 IHDR 头里就是宽高（大端 4 字节，从第 16 字节起）。"""
    with open(路, 'rb') as f:
        头 = f.read(24)
    assert 头[:8] == b'\x89PNG\r\n\x1a\n', '不是 PNG：%s' % 路
    import struct
    w, h = struct.unpack('>II', 头[16:24])
    return float(w), float(h)


if __name__ == '__main__':
    main()
