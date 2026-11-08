"""把「开心有礼 · 首日礼包」改成「首杀礼包」（就地改 `福利窗口.tscn`，逐条断言命中数）。

为什么单写一条脚本而不是手改：`.tscn` 是生成物，节点名被 30 多处 `parent=` 引用，
手改漏一处，Godot 载入时整页的父链就断了（那一页的子节点全挂到别的节点下）。
这里按「先改所有 parent 路径、再改节点名、最后改显示字」的顺序做，每步都断言命中数。

用法（仓库根目录）：python -X utf8 开发工具/改首杀礼包文案.py
"""
import io
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
路 = os.path.join(根, "场景", "界面", "窗口", "福利", "福利窗口.tscn")

旧 = "首日礼包"
新 = "首杀礼包"


def 替(文, 甲, 乙, 期望):
    实 = 文.count(甲)
    if 实 != 期望:
        raise SystemExit("!! 命中数不符：%r 期望 %d 实际 %d" % (甲, 期望, 实))
    return 文.replace(甲, 乙)


def 主() -> None:
    文 = io.open(路, encoding="utf-8", newline="").read()
    if 新 in 文:
        print("已改过（含 %s），不重复施加" % 新)
        return
    # ① 先改 parent 路径 —— 与节点声明顺序无关，一次全换。
    文 = 替(文, 'parent="滚动区/内容/%s' % 旧, 'parent="滚动区/内容/%s' % 新,
           文.count('parent="滚动区/内容/%s' % 旧))
    # ② 再改两处节点声明（页签 Button + 子页 Control）。
    文 = 替(文, '[node name="%s" type="Button" parent="分页"]' % 旧,
            '[node name="%s" type="Button" parent="分页"]' % 新, 1)
    文 = 替(文, '[node name="%s" type="Control" parent="滚动区/内容"]' % 旧,
            '[node name="%s" type="Control" parent="滚动区/内容"]' % 新, 1)
    # ③ 显示字：页签 / 框标题 / 礼包标题 / 开启说明。
    文 = 替(文, 'text = "%s"\ndisabled = false' % 旧, 'text = "%s"\ndisabled = false' % 新, 1)
    文 = 替(文, 'text = "%s奖励"' % 旧, 'text = "%s奖励"' % 新, 1)
    文 = 替(文, 'text = "%s"\nhorizontal_alignment = 0' % 旧,
            'text = "%s"\nhorizontal_alignment = 0' % 新, 1)
    文 = 替(文, 'text = "开启%s可随机获得一项以下物品："' % 旧,
            'text = "开启%s可随机获得一项以下物品："' % 新, 1)
    # ④ 条件说明：原版这行是「首日登录奖励」，现在是击杀口径。
    文 = 替(文, 'text = "首日登录奖励"', 'text = "击杀任意BOSS一只即可领取"', 1)
    if 旧 in 文:
        raise SystemExit("!! 还残留 %s，人工看一下" % 旧)
    io.open(路, "w", encoding="utf-8", newline="").write(文)
    print("改首杀礼包文案：完成（页签/子页/父链/标题/说明，共 %d 处显示字）" % 4)


if __name__ == "__main__":
    主()
