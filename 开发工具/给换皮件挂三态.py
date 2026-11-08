# -*- coding: utf-8 -*-
"""给全工程那些「一张皮 + 运行时 ±30/−40」却还没接状态机的换皮件，挂上 `原版三态钮.gd`。

现查（2026-10-19 夜，两轮一次性普查（本地临时脚本））：
  * 每一扇原版窗右上角那颗 X = `MWindowCloseBtnF.as`（symbol7）`extends MButton3`；
    数量框左右两颗 = `MPlusBtnF`（symbol600）/ `MMinusBtnF`（symbol604），同样 `extends MButton3`
    ⇒ 三张皮都是**一族一张图 + 运行时 `StyleUtil.getLightFilter(+30/−40)`**，
    不是 `MButton` 那种每态一张独立 skin（`MButton.as:124-131`）。
  * Godot 侧要表达这条只能**换皮**：主题 hover 档会"松手仍亮"（原版 `MButton3.as:103-108` 松手回
    STATE_UP），`modulate` 是乘性、shader 会被子节点继承连文字一起亮。
    状态机只有一份：`脚本/界面/组件/原版三态钮.gd`（三种落皮形态它自己都认，见该文件头）。

这一版普查另外逮到一条**更严重的**：`存取金额窗口` 与 `拆分窗口` 那颗 `关闭` 是
`Button` 且**既没有 icon 也没有样式覆盖** ⇒ 屏幕上根本没有 X（点得到、看不见）。
原版 `MWindow.drawWindowLayout()`（`:210-217`）无条件画 closeBtn ⇒ 这里顺手补 `icon`。

规矩：
  * 只往**磁盘**写（跑之前自己确认编辑器没开这些场景）；
  * **不就地 `open(p,"w")`** ⇒ 读进内存、写 tmp、回读逐条复查命中数、再 `os.replace`；
  * 幂等：节点块里已经有 `script = ` 就跳过并报告（不重复插、不给同一颗钮接两遍四条信号）；
  * `mouse_default_cursor_shape = 2`（手型，`MButton3.init()` `:135`）一起烘进场景 ——
    这是"编辑器里看得见、他能手调"的东西，不进代码。

用法：`python 开发工具/给换皮件挂三态.py --扫` 先看动哪几处；去掉 `--扫` 才落盘。
     落盘后必须 `Godot --path . --headless --import`，再跑 `测试/换皮件三态回归测试.gd`。
"""
import io
import os
import re
import sys

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
脚本路 = "res://脚本/界面/组件/原版三态钮.gd"
脚本id = "9_三态"
关钮皮路 = "res://素材/界面/原版窗口/通用控件/关闭按钮.png"
关钮皮id = "9_关皮"

## 场景（相对工程根）→ 要挂状态机的节点名（普查已核对：这些件都直接挂在各场景根下）
表 = {
    ## 主窗壳那颗 X：以前换皮的状态机写在 `功能窗口.gd::_关钮态`，本轮并进这一份（一处实现）。
    "场景/界面/功能窗口.tscn": ["关闭按钮"],
    "场景/界面/窗口/双修/双修简介窗.tscn": ["关钮"],
    ## ⚠ Python 的字典字面量**重复键不报错、后写的顶掉先写的**（这一版的箭头段一开始就把
    ## 上面那两行的 `关钮` 顶没了 ⇒ 铺皮器少处理两颗钮，还看不出来）。
    ## ⇒ 一张场景只能有一个键，同场景的件全列在同一个数组里。
    "场景/界面/窗口/双修/双修选人窗.tscn": ["关钮", "上一页钮", "下一页钮"],
    "场景/界面/窗口/好友/好友打探窗.tscn": ["关钮"],
    "场景/界面/窗口/好友/好友私聊窗.tscn": ["关钮"],
    "场景/界面/窗口/好友/好友选人窗.tscn": ["关钮", "上一页钮", "下一页钮"],
    "场景/界面/窗口/家族/家族Boss完成窗.tscn": ["钮关闭"],
    "场景/界面/组件/扩容窗口.tscn": ["关闭"],
    "场景/界面/组件/买卖数量窗.tscn": ["关闭", "加", "减"],
    "场景/界面/组件/商城购买窗.tscn": ["关闭", "加", "减"],
    "场景/界面/组件/存取金额窗口.tscn": ["关闭", "加", "减"],
    "场景/界面/组件/拆分窗口.tscn": ["关闭", "加", "减"],
    ## ── 翻页条那四枚箭头（`MPageFirstBtnF/MPagePreBtnF/MPageNextBtnF/MPageEndBtnF`
    ## 四颗类**全部 `extends MButton3`**，10-19 深夜现查）⇒ 与 X/加减同一族。
    ## 皮烘在 `开发工具/生成翻页钮态图.py`（`_悬停/_按下/_灰` 各 4 张；
    ## 灰皮与旧的 `专用控件/分页*_灰.png` 逐像素全等 ⇒ 已接入那几枚的禁用档外观不变）。
    ## ⚠ **这里只列原本一颗状态机都没有的 8 枚**：`首领窗口` 那 4 枚由
    ## `首领窗口.gd:217-235`（`_首领接分页三态`）自己接四条信号换 `texture_normal`，
    ## 五张 `家族*窗` 的 10 枚走 `家族子窗.gd:60-90`（按 `metadata/skin` 换皮换字色）。
    ## 在它们身上再挂一份就是两条闸互相顶掉（`测试/换皮件三态回归测试.gd` 把
    ## "某条信号有 2 条连接"当红判，10-19 深夜就是这么逮到我自己的重复挂接的）。
    ## 那 14 枚的取舍记在 `真值/窗口/挂机设置窗.md` §㉑ 未收口 —— **别顺手加回这张表**。
    "场景/界面/窗口/商城/商城窗口.tscn": ["首页", "上一页", "下一页", "末页"],
    ## ── 10-20 修行页右窗那三颗（用户报「右页的按钮点击没有反馈 没有点击效果」）。
    ## `LingquBiguanShouyi.as:131-151` 三颗全是 `MButtonF` = `extends MButton3`（`MButtonF.as:6`
    ## 只有构造函数、没有任何覆盖）⇒ **一族一张皮 + 运行时 ±30/−40 滤镜**，
    ## 而主题只能表达"各态各一张"，表达不了 `MButton3.as:103-108` 的**松手回 STATE_UP**
    ## （Godot 松手后鼠标还压着 ⇒ 停在 hover，一直亮着）。所以这三颗要挂状态机，不只是改主题。
    ## 皮：`开发工具/生成标准钮态图.py` 烘的 `按钮_悬停/_按下.png`（在 `通用控件/`，与常态同目录）。
    "场景/界面/窗口/闭关/领取修行收益.tscn": ["购买", "单倍领取", "双倍领取"],
}
## 这两扇的 X 原本根本没有皮（看不见），补一张原版那颗
补皮 = {("场景/界面/组件/存取金额窗口.tscn", "关闭"), ("场景/界面/组件/拆分窗口.tscn", "关闭")}


def 找块(行s, 名):
    """回 (块首下标, 最后一条属性行下标)。节点块到下一个 `[` 开头的行为止。"""
    for n, 行 in enumerate(行s):
        if re.match(r'\[node name="%s"[^\]]*\]' % re.escape(名), 行):
            末 = n
            i = n + 1
            while i < len(行s) and not 行s[i].startswith("["):
                if 行s[i].strip():
                    末 = i
                i += 1
            return n, 末
    raise SystemExit("查无节点：%s" % 名)


def 补节点(行s, 名, 要补皮):
    起, 末 = 找块(行s, 名)
    块 = "\n".join(行s[起:末 + 1])
    if re.search(r"^script = ", 块, re.M):
        return "跳过（已挂脚本）"
    插 = ["script = ExtResource(\"%s\")" % 脚本id]
    if 要补皮 and not re.search(r"^(icon|texture_normal) = ", 块, re.M):
        插.append("icon = ExtResource(\"%s\")" % 关钮皮id)
    if not re.search(r"^mouse_default_cursor_shape = ", 块, re.M):
        插.append("mouse_default_cursor_shape = 2")
    行s[末 + 1:末 + 1] = 插
    return "挂上"


def 处理(相对, 件表, 干跑):
    路 = os.path.join(工程, 相对.replace("/", os.sep))
    if not os.path.isfile(路):
        raise SystemExit("场景不存在：%s" % 相对)
    文 = io.open(路, encoding="utf-8", newline="").read()
    换行 = "\r\n" if "\r\n" in 文 else "\n"
    行s = 文.split(换行)
    动 = [(名, 补节点(行s, 名, (相对, 名) in 补皮)) for 名 in 件表]
    新件 = [名 for 名, v in 动 if v == "挂上"]
    if 干跑 or not 新件:
        return 动, 0
    新资源 = []
    if 脚本路 not in 文:
        新资源.append('[ext_resource type="Script" path="%s" id="%s"]' % (脚本路, 脚本id))
    if 关钮皮路 not in 文 and any((相对, 名) in 补皮 for 名 in 新件):
        新资源.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % (关钮皮路, 关钮皮id))
    if 新资源:
        ## ⚠ 这张场景**可能一条 ext_resource 都没有**（`领取修行收益.tscn` 就是这样：头行是
        ## `[gd_scene format=3]`，所有件都是裸节点、没有子资源）⇒ 旧写法 `max(...)` 直接
        ## `ValueError: max() arg is an empty sequence`，整条链在第一张场景上就崩、
        ## 后面一张都没写（实测 10-20：报"挂了 3 个件"，磁盘上却一个字没变）。
        ## 没有就先插到**头行之后**，并补一个空行，保证 section 之间仍有空行。
        有 = [n for n, 行 in enumerate(行s) if 行.startswith("[ext_resource")]
        if 有:
            行s[max(有) + 1:max(有) + 1] = 新资源
        else:
            头 = 0 if 行s[0].startswith("[gd_scene") else 1
            行s[头 + 1:头 + 1] = 新资源 + [""]
        m = re.match(r'\[gd_scene load_steps=(\d+)(.*)\]', 行s[0])
        if m:
            行s[0] = "[gd_scene load_steps=%d%s]" % (int(m.group(1)) + len(新资源), m.group(2))
    出 = 换行.join(行s)
    tmp = 路 + ".tmp"
    with io.open(tmp, "w", encoding="utf-8", newline="") as f:
        f.write(出)
    回 = io.open(tmp, encoding="utf-8", newline="").read()
    中 = 0
    for 名 in 新件:
        块 = 回.split('[node name="%s"' % 名, 1)
        中 += 1 if ('script = ExtResource("%s")' % 脚本id) in 块[1][:1500] else 0
    if 中 != len(新件):
        os.remove(tmp)
        raise SystemExit("复查不符：%s 期望 %d 个节点挂上，回读只认到 %d 个" % (相对, len(新件), 中))
    os.replace(tmp, 路)
    return 动, len(新资源)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    干跑 = "--扫" in sys.argv
    件总 = 0
    for 相对, 件表 in sorted(表.items()):
        动, 新资源 = 处理(相对, 件表, 干跑)
        件总 += sum(1 for _, v in 动 if v == "挂上")
        print("%-44s %s｜新 ext_resource %d 条" % (
                相对, "、".join("%s:%s" % t for t in 动), 新资源))
    print("换皮件挂三态%s：%d 个件 / %d 张场景" % ("（干跑，未落盘）" if 干跑 else "完成", 件总, len(表)))
