# -*- coding: utf-8 -*-
"""把「开心有礼」三页从充值口径改成首日/BOSS击杀口径（就地改，逐条断言命中数）。

用法：python -X utf8 开发工具/改福利页去充值.py            # 执行
      python -X utf8 开发工具/改福利页去充值.py --dry      # 只看命中
"""
import io
import re
import sys

PATH = "场景/界面/窗口/福利/福利窗口.tscn"
DRY = "--dry" in sys.argv

# 需要新增的一枚图标（修炼灵符（小）15012001），id 接在现有 r59 之后。
NEW_EXT = (
    '[ext_resource type="Texture2D" uid="uid://d1e3vhytf03qa" '
    'path="res://素材/物品/原版/TeShuWuPin/'
    'TeShuWuPin_15012001_info.swf_1_TeShuWuPin_15012001_info_icon.png" id="r60"]'
)

# 累计档门槛：与 fake_flash_server.LIMITED_ACTIVITY_BOSS_TOTAL 一一对应。
TOTAL_GATE = {1: 1, 2: 2, 3: 3, 4: 5, 5: 8, 6: 12, 7: 20, 8: 30, 9: 50}
# 额度档门槛：与 LIMITED_ACTIVITY_BOSS_EACH 一一对应。
EACH_GATE = {1: 2, 2: 4, 3: 8, 4: 16}


def parse(lines):
    heads = [i for i, l in enumerate(lines) if l.startswith("[")]
    segs = []
    for k, h in enumerate(heads):
        e = heads[k + 1] if k + 1 < len(heads) else len(lines)
        segs.append(lines[h:e])
    return heads[0], segs


def meta(seg):
    m = re.match(r'\[node name="([^"]*)" type="([^"]*)" parent="([^"]*)"\]', seg[0])
    if not m:
        return None
    return m.group(1), m.group(2), m.group(3)


def find(segs, name, parent):
    out = []
    for i, s in enumerate(segs):
        m = meta(s)
        if m and m[0] == name and m[2] == parent:
            out.append(i)
    return out


def one(segs, name, parent):
    hits = find(segs, name, parent)
    if len(hits) != 1:
        raise SystemExit("!! 定位 %s@%s 命中 %d 处（应为 1）" % (name, parent, len(hits)))
    return hits[0]


def set_line(seg, prefix, value, label):
    for i, l in enumerate(seg):
        if l.startswith(prefix):
            seg[i] = value
            return
    raise SystemExit("!! %s：段内找不到以 %r 开头的属性行" % (label, prefix))


def set_text(seg, text, label):
    for i, l in enumerate(seg):
        if l.startswith("text = "):
            if '"""' in l:
                raise SystemExit("!! %s 是多行字符串，脚本不敢猜" % label)
            seg[i] = 'text = "%s"' % text
            return
    raise SystemExit("!! %s：段内没有 text 行" % label)


def set_offset(seg, key, value, label):
    set_line(seg, "offset_%s =" % key, "offset_%s = %s" % (key, value), label)


def rename(segs, old_name, new_name, full_parent):
    """改节点名，并把它所有子孙的 parent 路径一起换掉。"""
    old_path = "%s/%s" % (full_parent, old_name) if full_parent else old_name
    changed = 0
    for s in segs:
        m = meta(s)
        if m and m[0] == old_name and m[2] == full_parent:
            s[0] = s[0].replace('name="%s"' % old_name, 'name="%s"' % new_name, 1)
            changed += 1
        elif m and (m[2] == old_path or m[2].startswith(old_path + "/")):
            新parent = "%s/%s%s" % (full_parent, new_name, m[2][len(old_path):]) if full_parent \
                else new_name + m[2][len(old_path):]
            s[0] = s[0].replace('parent="%s"' % m[2], 'parent="%s"' % 新parent, 1)
            changed += 1
    if changed == 0:
        raise SystemExit("!! 改名 %s→%s 一处都没命中" % (old_path, new_name))
    return changed


def main():
    raw = io.open(PATH, encoding="utf-8").read()
    assert "\r\n" not in raw, "行尾不是 \\n，脚本按 \\n 切会毁文件"
    lines = raw.split("\n")
    pre_len, segs = parse(lines)
    report = []

    # ---------------- 1) 删掉充值/点券相关节点 ----------------
    删 = [
        ("累计充值", "滚动区/内容/首充礼包"),
        ("充值金额", "滚动区/内容/首充礼包"),
        ("元宝", "滚动区/内容/首充礼包"),
        ("充值按钮", "滚动区/内容/首充礼包/奖励框"),
        ("可领", "滚动区/内容/新服有礼/大奖框/每档1"),
        ("点券数", "滚动区/内容/新服有礼/大奖框/每档1"),
        ("点券", "滚动区/内容/新服有礼/大奖框/每档1"),
    ]
    drop = set()
    for name, parent in 删:
        i = one(segs, name, parent)
        drop.add(i)
        report.append("删 %s@%s（第 %d 段）" % (name, parent, i))

    # ---------------- 2) 新增 每档1 的物品格三件套 ----------------
    行 = "滚动区/内容/新服有礼/大奖框/每档1"
    排 = "滚动区/内容/新服有礼/大奖框/排行2"
    模板名 = ("物品0格", "物品0图", "物品0数量")
    新段 = []
    for 名 in 模板名:
        src = list(segs[one(segs, 名, 排)])
        src[0] = src[0].replace('parent="%s"' % 排, 'parent="%s"' % 行, 1)
        if 名 == "物品0图":
            set_line(src, "texture =", 'texture = ExtResource("r60")', "物品0图贴图")
        新段.append(src)
        report.append("克隆 %s → %s" % (名, 行))
    # 插到 每档1/领取 之后（与 排行2 的结构同序）
    插入点 = one(segs, "领取", 行) + 1
    segs[插入点:插入点] = 新段
    # 领取 之后的段号全变了，重算一次插入点后的 drop 索引
    drop = {i if i < 插入点 else i + len(新段) for i in drop}

    # ---------------- 3) 改名 ----------------
    report.append("改名 分页/首充礼包 → 首日礼包（%d 段）"
                  % rename(segs, "首充礼包", "首日礼包", "分页"))
    report.append("改名 内容/首充礼包 → 首日礼包（%d 段）"
                  % rename(segs, "首充礼包", "首日礼包", "滚动区/内容"))
    rename(segs, "充值金额", "击杀数", "滚动区/内容/限时大奖")
    report.append("改名 充值金额→击杀数、元宝→单位")
    rename(segs, "元宝", "单位", "滚动区/内容/限时大奖")

    # ---------------- 4) 文案与坐标 ----------------
    首 = "滚动区/内容/首日礼包"
    奖 = 首 + "/奖励框"
    稿 = "滚动区/内容/限时大奖"
    新 = "滚动区/内容/新服有礼/大奖框"

    改文本 = [
        ("首日礼包", "分页", "首日礼包"),   # 页签：改名在第 3 步已做，这里只换显示字
        ("奖励框标题", 奖, "首日礼包奖励"),
        ("礼包标题", 奖, "首日礼包"),
        ("开启说明", 奖, "开启首日礼包可随机获得一项以下物品："),
        ("奖励说明", 奖, "首日登录奖励"),
        ("单位", 稿, "只"),
        ("累计框标题", 稿 + "/累计框", "累计击杀奖励"),
        ("额度框标题", 稿 + "/额度框", "额度击杀奖励"),
        ("活动说明", 稿, "BOSS击杀奖励"),
        ("标题", 新 + "/每档1", "1.免费修炼灵符（小）"),
        ("说明", 新 + "/每档1", "免费修炼灵符（小）"),
    ]
    for 名, parent, 文本 in 改文本:
        set_text(segs[one(segs, 名, parent)], 文本, "%s@%s" % (名, parent))
        report.append("文案 %s@%s → %s" % (名, parent, 文本))

    活动标题 = segs[one(segs, "活动标题", 稿)]
    set_text(活动标题,
             "[right][color=#00ff00]您活动期间[color=#ffffff]（2026.07.1-2026.08.1）[/color]"
             "累计击杀BOSS数：[/color][/right]", "活动标题")
    report.append("文案 活动标题 → 累计击杀BOSS数")

    for 序, 门槛 in TOTAL_GATE.items():
        段 = segs[one(segs, "文案", "%s/累计%d" % (稿, 序))]
        set_text(段,
                 "[color=#00ff00]活动期间累计击杀[color=#ff0000]%d[/color]只BOSS，获得以下物品[/color]" % 门槛,
                 "累计%d文案" % 序)
    for 序, 门槛 in EACH_GATE.items():
        段 = segs[one(segs, "文案", "%s/额度%d" % (稿, 序))]
        set_text(段,
                 "[color=#fff000]活动期间每击杀满[color=#ff0000]%d[/color]只BOSS，可领取一次以下物品[/color]" % 门槛,
                 "额度%d文案" % 序)
    report.append("文案 累计1-9 / 额度1-4 门槛数字全部重写")

    改坐标 = [
        # 页头那一行（累计充值/充值金额/元宝）删掉了 ⇒ 线与框整体上移 24。
        (首, "顶部线", [("top", 1.0), ("bottom", 3.0)]),
        (首, "奖励框", [("top", 21.0), ("bottom", 294.0)]),
        ("滚动区/内容", "首日礼包", [("bottom", 286.0)]),
        # 每档1 多了物品格 ⇒ 行高与 排行2 对齐，排行2 整体下移 20。
        (新, "每档1", [("bottom", 96.0)]),
        (新, "排行2", [("top", 96.0), ("bottom", 184.0)]),
    ]
    for parent, 名, 键值 in 改坐标:
        段 = segs[one(segs, 名, parent)]
        for 键, 值 in 键值:
            set_offset(段, 键, 值, "%s@%s" % (名, parent))
    # 页高同时写进 custom_minimum_size（VBoxContainer 只认这个）。
    set_line(segs[one(segs, "首日礼包", "滚动区/内容")], "custom_minimum_size =",
             "custom_minimum_size = Vector2(458.0, 286.0)", "首日礼包页高")
    report.append("坐标 首日礼包页上移 24 / 每档1 加高 20 / 排行2 下移 20")

    # ---------------- 5) 落盘 ----------------
    out = lines[:pre_len]
    for i, s in enumerate(segs):
        if i in drop:
            continue
        out.extend(s)
    # r28 = 「福利/充值按钮.png」，唯一引用者就是刚删掉的那枚按钮 ⇒ 一起删。
    # （商城页那枚用的是 `素材/界面/原版窗口/商城/充值按钮.png`，两条路径不同，互不影响。）
    if any('id="r28"' in l for l in out) and 'ExtResource("r28")' not in "\n".join(out):
        out = [l for l in out if not l.startswith("[ext_resource") or 'id="r28"' not in l]
        report.append("删掉只剩声明的 ext_resource r28（福利/充值按钮.png）")
    # 新 ext_resource 插在最后一条 ext_resource 之后
    for i, l in enumerate(out):
        if l.startswith("[ext_resource"):
            last = i
    out.insert(last + 1, NEW_EXT)
    文本 = "\n".join(out)
    for 残留 in ("首充礼包", "累计充值", "充值按钮", "点券数", "元宝，获得以下物品", "首次充值", "首次捐赠"):
        if 残留 in 文本:
            raise SystemExit("!! 落盘前自检：文案里还留着 %r" % 残留)
    if DRY:
        for r in report:
            print(r)
        print("dry-run，未写入")
        return
    io.open(PATH, "w", encoding="utf-8", newline="\n").write(文本)
    for r in report:
        print(r)
    print("已写入 %s（%d 行 → %d 行）" % (PATH, len(lines), 文本.count("\n") + 1))


main()
