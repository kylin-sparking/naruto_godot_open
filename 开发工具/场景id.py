# -*- coding: utf-8 -*-
"""场景 **sub_resource** id 的 ASCII 化（生成器共用）。

**为什么必须做**：Godot 把 `[sub_resource ... id="X"]` 的 `X` 当 **scene unique ID** 校验
（`Resource::set_scene_unique_id` → `String::is_valid_identifier`），只许 `[A-Za-z0-9_]`
**且不能以数字开头**。中文 id（`id="sb_内容面板"`）或数字开头（`id="10tuq"`）每加载一次就吐一行

    ERROR: The scene unique ID must contain only letters, numbers, and underscores.

—— 全量跑一轮 77 道门一共 720 行这种 ERROR，把日志里真正的错误淹掉
（§3.109 那两条 `Node not found` 就是从门日志那堆行里挖出来的）。

⚠️ **只管 `sub_resource`，别碰 `ext_resource`**：`[ext_resource ... id="1_krnc2"]` 那种
   数字开头的 id 是 **Godot 编辑器自己的标准写法，从来不报错**（全工程 260+ 个场景都这么写）。
   2026-10-11 第一版按"所有 `id=`"改，把小地图面板那 20 条 `ExtResource("1_xxx")` 一起改了
   —— 白改，还把 diff 撑大（已回退重做）。

⚠️ 实测（Godot 4.7.1）：`SubResource("sb_内容面板")` 的引用**仍然解析得出来**、皮不会丢，
   所以这是**噪声级**缺陷（不是"静默丢引用"）；但噪声本身就是下一条真 bug 的藏身处。

命名：按**首次出现顺序**给 `r0/r1/r2…` —— 同一份生成器输出 → 同一批 id（可复现）。
"""
import re

_合法 = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
_子资源头 = "[sub_resource"
_子资源id = re.compile(r'(?<![A-Za-z_])id="([^"]*)"')


def 非法id(文本: str) -> list:
    """列出所有不合法的 `[sub_resource]` id，按首次出现顺序去重。
    （`ext_resource` 的 `1_xxx` 形 id 合法，不在此列 —— 见文件头。）"""
    出 = []
    for 行 in 文本.splitlines():
        if not 行.startswith(_子资源头):
            continue
        命中 = _子资源id.search(行)
        if 命中 and 命中.group(1) and not _合法.match(命中.group(1)) and 命中.group(1) not in 出:
            出.append(命中.group(1))
    return 出


def ascii化(文本: str) -> str:
    """把非法的 sub_resource id 换成 ASCII，并同步改它的 `SubResource("…")` 引用。
    `ExtResource("…")` 一律不动。"""
    映射 = {}
    for 原 in 非法id(文本):
        映射[原] = "r%d" % len(映射)
    if not 映射:
        return 文本
    行们 = 文本.splitlines(keepends=True)
    for i, 行 in enumerate(行们):
        if not 行.startswith(_子资源头):
            continue
        行们[i] = _子资源id.sub(
            lambda m: 'id="%s"' % 映射.get(m.group(1), m.group(1)), 行)
    文本 = "".join(行们)
    for 原, 新 in 映射.items():
        文本 = 文本.replace('SubResource("%s")' % 原, 'SubResource("%s")' % 新)
    return 文本


if __name__ == "__main__":
    import io
    import os
    import sys

    sys.stdout.reconfigure(encoding="utf-8")
    for 路 in sys.argv[1:]:
        # newline=""：原样读写 ⇒ 保住 .tscn 的 CRLF，不让 id 改名顺手把整份行尾换掉。
        文 = io.open(路, encoding="utf-8", newline="").read()
        坏 = 非法id(文)
        if not 坏:
            print("干净 %s" % os.path.relpath(路))
            continue
        io.open(路, "w", encoding="utf-8", newline="").write(ascii化(文))
        print("修好 %s：%d 个非法 sub_resource id -> %s" % (os.path.relpath(路), len(坏), 坏))
