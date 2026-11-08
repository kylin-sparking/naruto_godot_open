# -*- coding: utf-8 -*-
"""挂机设置窗生成器：一份链式重算同时产出 ①场景 .tscn ②门用的期望 JSON。

原版 `com/mxw/uifl/controls/guaji/GuaJiSettingWindow.as`（742 行）
`super(664,492,true)` 在 `:166` ⇒ UIWindow 带内容底（`UIWindow.as:34-40`：
contentBg = (8,38)、尺寸 648×424，由 `:64-65` 的 `窗宽−16 / 窗高−68` 算出）。

坐标口径：件表写**窗口坐标**（AS3 原值），落场景统一减内容底原点 (8,38)。
页面根尺寸 = 648 × 454（= 窗宽−16 / 窗高−38，**不是 −68**）：AS3 的
`_promptLabel/_startBtn/_stopBtn` 是 addChild 到**窗口本身**、y 按 `_height − 27` 算
（`:349-355`），落在 contentBg 下沿（462）之外 —— 与家族子窗同一条口径。

几何不是手抄的表：本文件按 `createChildren()`（`:254-363`）的链式赋值逐条重算
（`_hpInput.x = _hpLabel.x + 80` 这一类），所以改一条认知只改一处公式。

九宫格边距**现场从 `MainLib.xml` 的 `DefineScalingGridTag` 解**（《共用件度量表》§13 已不在本机
⇒ 只能现场解）。⚠ 四个数按属性名逐个取，不许写按顺序的正则（ffdec 写的是 `Xmax Xmin Ymax Ymin`）。

用法：python 开发工具/生成挂机场景.py
     然后 <godot> --headless --path . --import
"""
import io
import json
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
项目 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("NARUTO_GAME_ROOT", r"2.2.3")
import 原版数据 as 语言源  # noqa: E402

XML路 = r"2.2.3\logs\swfprobe\MainLib.xml"
场景路 = os.path.join(项目, "场景", "界面", "窗口", "挂机", "挂机窗口.tscn")
期望路 = os.path.join(项目, "数据", "界面", "挂机窗口_期望.json")
通用 = "res://素材/界面/原版窗口/通用控件/"
家族 = "res://素材/界面/原版窗口/家族/"
复选组件 = "res://场景/界面/组件/原版复选项.tscn"

# ── AS3 常量（每条带出处） ──────────────────────────────────────────────
窗宽, 窗高 = 664, 492			# :166 super(664,492,true)
原点 = (8, 38)				# UIWindow.as:37-38
内容宽 = 窗宽 - 原点[0] * 2		# UIWindow.as:64 → 648
边距 = 5					# UIConfig.as:890 BORDER_GAP
内缩 = 8					# UIConfig.as:892 CONTENT_GAP
钮宽 = 61					# UIConfig.as:968 btn_width_four（_startBtn.width 在 :352）
勾高 = 19					# MCheckBox.as:81-82 _height = upSkin.height；复选框未选.png = 19×19
下拉高 = 21				# 下拉框.png 原生 116×21，createComboBox 只压宽（:478）不压高
输入高 = 21				# 输入框.png 原生 125×21
输入宽 = 40					# :184 input.width = 40
标签高 = 20				# MLabel.as:57 setSize(0,20) / :274 textField.height = 20
钮高 = 22					# 钮底61.png 61×22
字号 = 12					# MLabel.as:219 _textFormat.size = 12
黄 = "#fff000"				# UIConfig.as:932 UI_YELLOW = 16773120
绿 = "#00ff00"				# UIConfig.as:930 UI_GREEN = 65280
白 = "#ffffff"				# createLabel 的 param5 默认 16777215（:421）
蓝 = "#1e90ff"				# createCheckBox 的 param4 默认 2003199（:719）
米 = "#ebe381"				# 15459201：体力/精华/通灵体力三枚（:292-294）
橙 = "#dd9e3f"				# 14523967：无限时长/回城打坐/避开首领/原地复活（:345-348）
浅灰 = "#aaaaaa"			# 11184810：出售提示行（:325）

语言表 = {}
for 档 in ("core", "ui", "message"):
    for 键, 值 in 语言源.读语言表(档).items():
        if isinstance(值, str):
            语言表.setdefault(键, 值)


def 文(键: str) -> str:
    """语言表取值；`=字面` 直接给 AS3 里写死的中文；查不到就 raise，别自造文案。"""
    if 键.startswith("="):
        return 键[1:]
    if 键 not in 语言表:
        raise SystemExit("语言表缺键，别自造文案：%s" % 键)
    return 语言表[键]


def 字宽(串: str) -> int:
    """MLabel.as:345 `setSize(textField.textWidth + 4, …)`；12 号全角 12px、半角 6px。"""
    return sum(12 if ord(c) > 0x2E80 else 6 for c in 串) + 4


def 原生尺寸(皮: str) -> tuple:
    from PIL import Image
    路 = os.path.join(项目, 皮.replace("res://", "").replace("/", os.sep))
    if not os.path.isfile(路):
        raise SystemExit("皮不在盘上：%s" % 路)
    with Image.open(路) as im:
        return im.size


def 整(v):
    """九宫边距定形：`NinePatchRect` 的 `patch_margin_*` 只收 **int**（§3.228）。
    分数原值留在本文件的 `盒边/输入边` 里（那是 MainLib.xml 的真值），只在烘出去时
    四舍五入（.5 远离 0）—— 与 `生成家族子窗.py:46 整()` 同一口径。
    ⚠ 2026-10-22 合支时这里还写着 `texture_margin_*`（那是 StyleBoxTexture 的属性）：
    NinePatchRect 上它**既不报错也不落地**，底图整片拉伸，`场景资源回归测试` ④ 抓到。
    """
    return int(v + 0.5) if v >= 0 else -int(-v + 0.5)


def 九宫格(符号: int, 皮: str) -> list:
    """DefineScalingGridTag 的 splitter(twips) → [左, 上, 右, 下]（像素），带自检。"""
    if not os.path.isfile(XML路):
        raise SystemExit("读不到 MainLib.xml：%s" % XML路)
    全 = io.open(XML路, encoding="utf-8", errors="replace").read()
    i = 全.find('<item type="DefineScalingGridTag" characterId="%d"' % 符号)
    if i < 0:
        raise SystemExit("符号 %d(%s) 没有 DefineScalingGridTag ⇒ 整帧拉伸，不该走九宫格" % (符号, 皮))
    行 = re.search(r"<splitter[^>]*>", 全[i:全.find("</item>", i)])
    if not 行:
        raise SystemExit("符号 %d 的 DefineScalingGridTag 里没有 splitter 行" % 符号)

    def 取(键名):
        m = re.search(键名 + r'="(\d+)"', 行.group(0))
        if not m:
            raise SystemExit("符号 %d(%s) 的 splitter 里没解出 %s" % (符号, 皮, 键名))
        return int(m.group(1)) / 20.0

    左, 上, 宽, 高 = 取("Xmin"), 取("Ymin"), *原生尺寸(皮)
    右, 下 = 宽 - 取("Xmax"), 高 - 取("Ymax")
    if min(左, 上, 右, 下) < 0 or 左 + 右 > 宽 or 上 + 下 > 高:
        raise SystemExit("符号 %d(%s) 边距不成立：左%.2f 上%.2f 右%.2f 下%.2f 原生 %dx%d"
                         % (符号, 皮, 左, 上, 右, 下, 宽, 高))
    return [左, 上, 右, 下]


盒底皮 = 家族 + "盒底.png"					# MPane_background(97)
输入皮 = 通用 + "输入框.png"					# MTextInput_background(437)
盒边 = 九宫格(97, 盒底皮)
输入边 = 九宫格(437, 输入皮)
下拉四 = [("normal", 通用 + "下拉框.png", 614), ("hover", 通用 + "下拉框悬停.png", 620),
          ("pressed", 通用 + "下拉框按下.png", 623), ("disabled", 通用 + "下拉框禁用.png", 617)]
下拉边 = {名: 九宫格(号, 路) for 名, 路, 号 in 下拉四}
# fl `ComboBox.drawLayout:651-655`：inputField @(textPadding=3,3)、宽 = W − buttonWidth(24) − 3
## 文字区 = 框宽 80 − 左帽 5 − 右帽 23 = 52 ⇒ 刚好放得下四个 12px 汉字（"从大到小"）。
## 右帽那 23px 就是皮上烙着的那枚箭头按钮（四态皮各 477 个不透明像素，实测）⇒ **箭头不许再让
## Godot 画第二枚**（见下面 无箭头.png 那一行），否则它按 13px 宽 + h_separation 把文字区压到 38、
## 框里就缺最后一两个字（10-18 用户实机图：80 的框只画得出"从大到"）。
下拉内 = (5, 23, 3, 0)

# ── 件表（窗口坐标） ────────────────────────────────────────────────────
件表 = []


def 加(名, 种, x, y, w, h, 出处, **属):
    件表.append(dict(名=名, 种=种, x=x, y=y, 宽=w, 高=h, 出处=出处, 属=属))


def 叶盒(名, x, y, w, h, 标题键, 出处):
    """LeafBorder.as:61-86：盒 + 两端帽（padding=40 ⇒ 帽 y = 8−22 = −14）+ 居中盒标题（y = −高+1）。"""
    加("盒" + 名, "盒", x, y, w, h, 出处)
    加("端帽左" + 名, "端帽左", x + 40, y - 14, 27, 22, 出处)
    加("端帽右" + 名, "端帽右", x + w - 27 - 40, y - 14, 27, 22, 出处)
    ## `LeafBorder.as:70-71`：`_label.x = (_width - _label.width) / 2`（**居中**）
    ## `_label.y = -_label.height + 1`，而 `_label` 是 `BaseUtil.getLabel` 造的 MLabel、
    ## 高 20（`MLabel.as:57` setSize(0,20) / `:274` textField.height=20）⇒ 盒顶 −19、高 20。
    ## 上一轮写成 18 高且**没居中** ⇒ 标题贴到盒子最左边（10-18 用户实机图「排版不对」）。
    加("标题" + 名, "盒标题", x, y - 19, w, 20, 出处 + "；盒标题居中", 文=文(标题键), 色=黄, 居中=1)


def 复选(名, x, y, w, 键, 色, 出处):
    加("复选" + 名, "复选", x, y, w, 勾高, 出处, 文=("" if 键 == "" else 文(键)), 色=色)


def 标签(名, x, y, w, 键, 出处, 色=白, 居中=False):
    加("标签" + 名, "标签", x, y, w, 标签高, 出处, 文=文(键), 色=色, 居中=1 if 居中 else 0)


def 输入(名, x, y, 上限, 出处):
    加("输入底" + 名, "输入底", x, y, 输入宽, 输入高, 出处 + " 输入框底(437)")
    加("输入" + 名, "输入", x, y, 输入宽, 输入高, 出处, 上限=上限)


def 下拉(名, x, y, 键表, 出处):
    """MComboBox 宽恒 80（:478）。`键表` 空 = 运行期由 技能/宠物技能 数据填。"""
    加("下拉" + 名, "下拉", x, y, 80, 下拉高, 出处, 项=[文(k) for k in 键表])


# 四块底板（:257-277 / :308-314）
吃药x, 吃药y = 原点[0] + 边距, 原点[1] + 边距 + 24			# :260-261 → (13,67)
吃药宽, 吃药高 = 352, 153						# :258-259
采集y = 吃药y + 吃药高 + 24						# :268 → 244
采集高 = 86							# :266
战斗x = 吃药x + 吃药宽 + 边距						# :274 → 370
战斗宽 = 内容宽 - 吃药宽 - 边距 * 3					# :272 → 281
战斗高 = 采集高 + 吃药高 + 24						# :273 → 263
出售y = 采集y + 采集高 + 18						# :312 → 348
出售宽 = 内容宽 - 边距 * 2						# :309 → 638
叶盒("吃药", 吃药x, 吃药y, 吃药宽, 吃药高, "=吃药保护设置", ":257-263")
叶盒("采集", 吃药x, 采集y, 吃药宽, 采集高, "=自动拾取设置", ":264-270")
叶盒("战斗", 战斗x, 吃药y, 战斗宽, 战斗高, "=自动战斗设置", ":271-277")

左x, 左y = 吃药x + 内缩, 吃药y + 内缩					# :278 → (21, 75)
复选("生命阈值", 左x, 左y, 勾高, "", 蓝, ":278")			# 文本是 " "：标签是旁边的独立 MLabel
标签("生命低于", 左x + 25, 左y, 76, "GUAJI_AUTO_REPLY_HP_LABEL", ":279")
生命输入x = 左x + 25 + 80						# :280 _hpLabel.x + 80
输入("生命阈值", 生命输入x, 左y, 100, ":280")
标签("生命时", 生命输入x + 输入宽, 左y, 64, "GUAJI_AUTO_REPLY_HP_LABEL_2", ":281-282", 居中=True)
生命下拉x = 生命输入x + 105						# :283 _hpInput.x + 105
下拉("生命药品", 生命下拉x, 左y, ["GUAJI_DRUG_COMBOX_STRS_1", "GUAJI_DRUG_COMBOX_STRS_2"], ":283")
标签("生命吃药", 生命下拉x + 80, 左y, 50, "GUAJI_AUTO_REPLY_HP_LABEL_3", ":284")
查y = 左y + 勾高 + 边距							# :285 → 99
复选("查克拉阈值", 左x, 查y, 勾高, "", 蓝, ":285")
标签("查克拉低于", 左x + 25, 查y, 76, "GUAJI_AUTO_REPLY_MP_LABEL", ":286")
查输入x = 左x + 25 + 80
输入("查克拉阈值", 查输入x, 查y, 100, ":287")
标签("查克拉时", 查输入x + 输入宽, 查y, 64, "GUAJI_AUTO_REPLY_HP_LABEL_2", ":288", 居中=True)
查下拉x = 查输入x + 105
下拉("查克拉药品", 查下拉x, 查y, ["GUAJI_DRUG_COMBOX_STRS_1", "GUAJI_DRUG_COMBOX_STRS_2"], ":290")
标签("查克拉吃药", 查下拉x + 80, 查y, 50, "GUAJI_AUTO_REPLY_HP_LABEL_3", ":291")
体力y = 查y + 勾高 + 20							# :292 → 138
复选("体力符", 左x, 体力y, 340, "GUAJI_AUTO_USE_EP_LABEL", 米, ":292")
精华y = 体力y + 勾高 + 边距						# :293 → 162
复选("精华符", 左x, 精华y, 340, "GUAJI_AUTO_USE_ZHENQI_LABEL", 米, ":293")
通灵y = 精华y + 勾高 + 边距						# :294 → 186
复选("通灵体力符", 左x, 通灵y, 340, "GUAJI_CHONGQU_AUTO_USE_EP_LABEL", 米, ":294")

采左y = 采集y + 内缩							# :295 → 252
复选("拾取总开关", 左x, 采左y, 勾高, "", 蓝, ":295")
标签("拾取", 左x + 25, 采左y, 32, "GUAJI_COLLECT_LABEL", ":296")
职x = 左x + 25 + 30							# :297 _collectCheckLabel.x + 30
职业项 = ["GUAJI_PROFESSION_COMBOX_STRS_1", "JOB_FIRE_NAME", "JOB_WATER_NAME",
          "JOB_LIGHTING_NAME", "JOB_WIND_NAME"]			# CN.as:3474-3476
等级项 = ["GUAJI_LEVEL_COMBOX_STRS_LABEL_%d" % i for i in range(1, 8)]	# CN.as:6011-6034
品质项 = ["GUAJI_QULITY_COMBOX_STRS_%d" % i for i in range(1, 6)]		# CN.as:5816-5818
下拉("拾取职业", 职x, 采左y, 职业项, ":297")
级x = 职x + 80							# :298
下拉("拾取等级", 级x, 采左y, 等级项, ":298")
品x = 级x + 80							# :299
下拉("拾取品质", 品x, 采左y, 品质项, ":299")
标签("拾取装备", 品x + 80, 采左y, 32, "EQUIP_STRENGTH_FAIL_PROMPT_6_2", ":300")
货y = 采左y + 勾高 + 边距							# :301 → 276
复选("拾取任务品", 左x, 货y, 120, "GUAJI_COLLECT_GOODS_LABELS_1", 蓝, ":301")
复选("拾取药品", 左x + 120, 货y, 120, "GUAJI_COLLECT_GOODS_LABELS_2", 蓝, ":302")
复选("拾取金币", 左x + 240, 货y, 100, "GUAJI_COLLECT_GOODS_LABELS_3", 蓝, ":303")
料y = 货y + 勾高 + 边距							# :304 → 300
复选("拾取材料", 左x, 料y, 120, "GUAJI_COLLECT_GOODS_LABELS_4", 蓝, ":304")
复选("拾取其他", 左x + 120, 料y, 120, "GUAJI_COLLECT_GOODS_LABELS_5", 蓝, ":305")
复选("自动出售装备", 左x + 240 - 12, 料y, 128, "GUAJI_AUTO_SELL_PICKED_EQUIP", 蓝, ":306")

战左x, 战左y = 战斗x + 内缩, 吃药y + 内缩				# :326 → (378, 75)
标签("人物自动使用", 战左x, 战左y, 80, "GUAJI_AUTO_SKILL_LABEL", ":326")
招x = 战斗x + 87							# :327 → 457
下拉("自动忍术", 招x, 战左y + 1, [], ":327")			# 项表运行期 = getSkills() `:383-398`
标签("攻击动物一", 招x + 80, 战左y, 110, "GUAJI_AUTO_SKILL_LABEL_1", ":328")
兽标签y = 战左y + 24							# :329 → 99
标签("通灵自动使用", 战左x, 兽标签y, 80, "GUAJI_CHONGWU_AUTO_SKILL_LABEL", ":329")
下拉("自动宠物忍术", 招x, 兽标签y + 1, [], ":330")		# 项表运行期 = getPetSkills() `:638-660`
标签("攻击动物二", 招x + 80, 兽标签y, 110, "GUAJI_AUTO_SKILL_LABEL_1", ":331")
续y = 兽标签y + 1 + 下拉高 + 4						# :332 → 125
复选("自动续用辅助", 战左x, 续y, 267, "GUAJI_AUTO_SKILL_CHECK_BOX", 蓝, ":332")
印y = 续y + 勾高 + 2							# :333 → 146
复选("天之咒印", 战左x, 印y, 101, "GUAJI_AUTO_WULIN_LABEL", 蓝, ":333")
复选("地之咒印", 战左x + 100, 印y, 167, "GUAJI_AUTO_ZHANYI_LABEL", 蓝, ":334")
掌y = 印y + 勾高 + 2							# :335 → 167
复选("掌仙术", 战左x, 掌y, 101, "GUAJI_ZHANGXIANSHU", 蓝, ":335")
复选("创造再生", 战左x + 100, 掌y, 167, "GUAJI_CHUANGZAOZAISHENG", 蓝, ":336")
守y = 掌y + 勾高 + 2							# :337 → 188
复选("不离不弃", 战左x, 守y, 101, "GUAJI_SHENGSIXIANGXUE", 蓝, ":337")
复选("自动升级技能", 战左x + 100, 守y, 167, "=自动升级技能", 黄, ":338")
范y = 守y + 勾高 + 4							# :339 → 211
标签("战斗范围", 战左x, 范y, 112, "GUAJI_AUTO_BATTLE_RANGE_LABEL", ":339")
范输入x = 战左x + 115							# :340
输入("战斗范围", 范输入x, 范y, 99, ":340")
标签("格", 范输入x + 输入宽, 范y, 字宽("格"), "GUAJIWINDOW_GE", ":341")
时y = 范y + 24								# :342 → 235
标签("战斗时间", 战左x, 时y, 84, "GUAJI_AUTO_BATTLE_TIME_LABEL", ":342")
时输入x = 战左x + 85							# :343
输入("战斗时间", 时输入x, 时y, 500, ":343")
标签("分钟", 时输入x + 输入宽, 时y, 字宽("分钟"), "BIGUAN_WINDOW_MINUTE", ":344")
复选("无限时长", 时输入x + 输入宽 + 30, 时y, 110, "GUAJI_UNLIMITED_BATTLE_TIME", 橙, ":345")
打y = 时y + 输入高 + 4							# :346 → 260
复选("回城打坐", 战左x, 打y, 267, "GUAJI_AUTO_BATTLE_LABELS_1", 橙, ":346")
避y = 打y + 勾高 + 3							# :347 → 282
复选("避开首领", 战左x, 避y, 267, "GUAJI_AUTO_BATTLE_LABELS_2", 橙, ":347")
复y = 避y + 勾高 + 3							# :348 → 304
复选("原地复活", 战左x, 复y, 267, "GUAJI_AUTO_BATTLE_LABELS_3", 橙, ":348")

# 出售盒排在 30 件之后 addChild（:313）⇒ 它的件也按 AS3 顺序放在这里
叶盒("出售", 吃药x, 出售y, 出售宽, 104, "=自动出售", ":308-314")
售左x, 售左y = 吃药x + 内缩, 出售y + 24				# :315 → (21, 372)
复选("自动出售开", 售左x, 售左y, 88, "=自动出售", 蓝, ":315")
标签("等级上限", 售左x + 95, 售左y, 64, "=等级上限", ":316")
售级x = 售左x + 162							# :317 → 183
下拉("出售等级", 售级x, 售左y, 等级项, ":317")
标签("职业", 售级x + 88, 售左y, 48, "=职业", ":318")
售职x = 售级x + 140							# :319 → 323
下拉("出售职业", 售职x, 售左y, 职业项, ":319")
标签("品质上限", 售职x + 88, 售左y, 60, "=品质≤", ":320")
售品x = 售职x + 150							# :321 → 473
品质档 = ["=不限"] + ["=≤%d阶" % i for i in range(1, 7)]	# :560-585 硬编码
下拉("出售品质", 售品x, 售左y, 品质档, ":321")
食y = 售左y + 26								# :322 → 398
复选("出售食材", 售左x, 食y, 160, "=出售烹饪食材(12种)", 蓝, ":322")
复选("出售残卷", 售左x + 170, 食y, 130, "=出售技能书残卷", 蓝, ":323")
复选("出售技能书", 售左x + 310, 食y, 110, "=出售技能书", 蓝, ":324")
标签("出售提示", 售左x, 食y + 26, 420,
     "=技能书自动排除奥义/轮回/秘籍（月读、天照、神罗天征等）", ":325", 色=浅灰)

提示y = 窗高 - 27								# :349 → 465
标签("提示", 415, 提示y, 243, "GUAJI_PROMPT", ":349", 色=绿)
开始x = (窗宽 - 163) / 2.0						# :350 → 250.5
开始y = 提示y + 2								# :350 → 467
加("钮开始", "钮", 开始x, 开始y, 钮宽, 钮高, ":350-352", 文=文("GUAJI_START_LABEL"))
加("钮停止", "钮", 开始x + 钮宽 + 40, 开始y, 钮宽, 钮高, ":353-355", 文=文("GUAJI_STOP_LABEL"))

# ── 落场景 ─────────────────────────────────────────────────────────────
页宽, 页高 = 内容宽, 窗高 - 原点[1]			# 648 × 454
资源, 序号 = [], {}


def 加皮(路: str) -> str:
    if 路 in 序号:
        return 序号[路]
    盘 = os.path.join(项目, 路.replace("res://", "").replace("/", os.sep))
    if not os.path.isfile(盘):
        raise SystemExit("皮不在盘上：%s" % 盘)
    id名 = "t%d" % (len(序号) + 1)
    序号[路] = id名
    资源.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % (路, id名))
    return id名


def 色串(十六: str) -> str:
    十 = 十六.lstrip("#")
    return "Color(%s, %s, %s, 1)" % tuple(int(十[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def 串(值) -> str:
    return '"%s"' % str(值).replace("\\", "").replace('"', '\\"')


块 = []
期望 = {"_原点": list(原点), "_页": [页宽, 页高], "_说明":
      "由 开发工具/生成挂机场景.py 从 GuaJiSettingWindow.as 的 createChildren() 链式重算；"
      "rect 是页面局部坐标（窗口坐标 − 8,38），窗口坐标另存一份。"}
for 项 in 件表:
    x, y, w, h = 项["x"], 项["y"], 项["宽"], 项["高"]
    局 = [round(x - 原点[0], 1), round(y - 原点[1], 1), w, h]
    名, 种, 属 = 项["名"], 项["种"], 项["属"]
    类型 = {"盒": "NinePatchRect", "输入底": "NinePatchRect", "端帽左": "TextureRect",
            "端帽右": "TextureRect", "盒标题": "Label", "标签": "Label", "输入": "LineEdit",
            "下拉": "OptionButton", "钮": "TextureButton", "复选": "Control"}[种]
    头 = ('[node name="%s" parent="." instance=ExtResource("k1")]' % 名) if 种 == "复选" \
        else ('[node name="%s" type="%s" parent="."]' % (名, 类型))
    行 = [头, "layout_mode = 0", "offset_left = %.1f" % 局[0], "offset_top = %.1f" % 局[1],
          "offset_right = %.1f" % (局[0] + 局[2]), "offset_bottom = %.1f" % (局[1] + 局[3])]
    if 种 == "复选":
        行.append("custom_minimum_size = Vector2(%g, %g)" % (局[2], 局[3]))
    if 种 in ("复选", "盒", "输入底", "端帽左", "端帽右", "标签", "盒标题"):
        行.append("mouse_filter = 2")
    if 种 in ("盒", "输入底"):
        边 = 输入边 if 种 == "输入底" else 盒边
        行 += ['texture = ExtResource("%s")' % 加皮(输入皮 if 种 == "输入底" else 盒底皮)]
        行 += ["patch_margin_left = %d" % 整(边[0]), "patch_margin_top = %d" % 整(边[1]),
               "patch_margin_right = %d" % 整(边[2]), "patch_margin_bottom = %d" % 整(边[3])]
    if 种 in ("端帽左", "端帽右"):
        行 += ['texture = ExtResource("%s")' % 加皮(家族 + ("端帽左.png" if 种 == "端帽左" else "端帽右.png")),
               "expand_mode = 1", "stretch_mode = 0"]
    if 种 in ("标签", "盒标题"):
        ## 原版这些标签是 `MGlowLabel`（`GuaJiSettingWindow.as:421-435` createLabel），
        ## 屏上是一圈深色描边；不描边就"字细一圈、位置看着也不对"（用户 10-18 实机图）。
        ## 口径全工程统一：描边 2、无阴影（`原版皮肤表.gd:183 文字规则_描边数值`）。
        行 += ["theme_override_colors/font_color = %s" % 色串(属["色"]),
               "theme_override_colors/font_outline_color = %s" % 色串("#000000"),
               "theme_override_constants/outline_size = 2",
               "theme_override_font_sizes/font_size = %d" % 字号,
               "horizontal_alignment = %d" % 属.get("居中", 0),
               "vertical_alignment = 1", "clip_text = true", "text = %s" % 串(属["文"])]
    if 种 == "输入":
        行 += ['theme_override_styles/normal = SubResource("sb_empty")',
               'theme_override_styles/read_only = SubResource("sb_empty")',
               'theme_override_styles/focus = SubResource("sb_empty")',
               "theme_override_colors/font_color = %s" % 色串(白),
               "theme_override_font_sizes/font_size = %d" % 字号,
               "alignment = 1", "max_length = 3", "editable = true", "text = %s" % 串(属.get("初值", "")),
               "metadata/max = %d" % 属["上限"], "metadata/as3 = %s" % 串(项["出处"])]
    if 种 == "下拉":
        行 += ['theme_override_styles/normal = SubResource("sb_combo_normal")',
               'theme_override_styles/hover = SubResource("sb_combo_hover")',
               'theme_override_styles/pressed = SubResource("sb_combo_pressed")',
               'theme_override_styles/focus = SubResource("sb_combo_normal")',
               'theme_override_styles/disabled = SubResource("sb_combo_disabled")',
               ## 箭头由皮自带 ⇒ 指一张 1×1 全透明图，把 Godot 那枚 13px 箭头连同它占的宽度一起去掉
               ## （同工程既有口径：`开通穴道弹窗.gd:31-37` 运行期换 1×1；这里烘进场景，编辑器与运行期一致）。
               'theme_override_icons/arrow = ExtResource("%s")' % 加皮(通用 + "无箭头.png"),
               "theme_override_constants/h_separation = 0",
               "theme_override_colors/font_color = %s" % 色串(白),
               "theme_override_font_sizes/font_size = %d" % 字号,
               "focus_mode = 0", "alignment = 0", "clip_text = true",
               ## OptionButton 的 get_minimum_size() 默认按**最长项**撑宽（Godot 4.3+ 的
               ## fit_to_longest_item），AS3 这边 createComboBox 是写死 80（:478）⇒ 不关掉
               ## 就会撑到 112 压住右边的「吃药 / 攻击动物」标签（用户 10-18 实机图）。
               "fit_to_longest_item = false",
               "text = %s" % 串(属["项"][0] if 属["项"] else ""),
               "metadata/as3 = %s" % 串(项["出处"])]
    if 种 == "钮":
        皮 = 家族 + "钮底%d.png" % 钮宽
        行 += ['texture_normal = ExtResource("%s")' % 加皮(皮),
               "ignore_texture_size = true", "stretch_mode = 0", "focus_mode = 0",
               "mouse_default_cursor_shape = 2",
               "metadata/skin = %s" % 串(皮[:-4]), "metadata/as3 = %s" % 串(项["出处"])]
    块.append("\n".join(行))
    期 = {"rect": 局, "窗口坐标": [x, y, w, h], "as3": 项["出处"], "种": 种}
    for 键名 in ("文", "色", "上限"):
        if 键名 in 属:
            期[键名] = 属[键名]
    if 属.get("项"):
        期["项"] = 属["项"]
    期望[名] = 期
    if 种 == "复选":
        # 组件内部三件跟着根宽走：AS3 `MCheckBox.as:85` 的 _width 就是 createCheckBox 的 param5，
        # 覆盖根宽而不覆盖内部 = 文本被 177 的旧盒裁掉、点击区压到邻件上（点错格）。
        # 那三枚"空文本"的（生命/查克拉/拾取总开关）根宽只有 19 ⇒ 文本盒夹成零宽、别倒过去。
        文右 = max(勾高 + 2, 局[2])
        块.append("\n".join(['[node name="文本" parent="%s"]' % 名,
                            "offset_left = %d" % (勾高 + 2), "offset_right = %.1f" % 文右,
                            "offset_bottom = %d" % 勾高,
                            "theme_override_colors/font_color = %s" % 色串(属["色"]),
                            "theme_override_colors/font_outline_color = %s" % 色串("#000000"),
                            "theme_override_constants/outline_size = 2",
                            "text = %s" % 串(属["文"])]))
        块.append("\n".join(['[node name="点击区域" parent="%s"]' % 名,
                            "offset_right = %.1f" % 局[2], "offset_bottom = %d" % 勾高,
                            "tooltip_text = %s" % 串(属["文"])]))
        期望[名]["文本左"] = 勾高 + 2
        期望[名]["文本右"] = 文右
        期望[名]["点击区"] = [局[2], 勾高]
    if 种 == "钮":
        块.append("\n".join(['[node name="文字" type="Label" parent="%s"]' % 名,
                            "layout_mode = 1", "anchors_preset = 15", "anchor_right = 1.0",
                            "anchor_bottom = 1.0", "grow_horizontal = 2", "grow_vertical = 2",
                            "mouse_filter = 2", "text = %s" % 串(属["文"]),
                            "horizontal_alignment = 1", "vertical_alignment = 1",
                            "theme_override_colors/font_color = %s" % 色串("#fcf49c"),
                            "theme_override_colors/font_outline_color = %s" % 色串("#000000"),
                            "theme_override_constants/outline_size = 2",
                            "theme_override_font_sizes/font_size = 12"]))
        期望[名]["文字色"] = "#fcf49c"

注释 = [
    '; 由 `开发工具/生成挂机场景.py` 从原版 `GuaJiSettingWindow.as` 的 createChildren() **链式重算**生成。',
    '; **改真值改生成器再重跑，别手改本文件**（手改会被下一次生成吃掉）。',
    '; 原版 664×492（`super(664,492,true)` 在 `:166`），标题「智能托管打怪设置」`:167`。',
    '; 页面局部坐标 = AS3 窗口坐标 − (8,38)（`UIWindow.as:37-38` 内容底原点）；根尺寸 648×454。',
    '; 同级顺序 = AS3 addChild 顺序：吃药/采集/战斗三盒最先，出售盒排在「自动出售装备」之后（`:313`）。',
    '; 「输入底」不是 AS3 的一个子件（它是 MTextInput2 自己的皮），这里垫在 LineEdit **之前**（先加者在下）。',
    '; 逐件出处与算式见 `真值/窗口/挂机设置窗.md`。']
子资 = ['[sub_resource type="StyleBoxEmpty" id="sb_empty"]']
for 态, 路, 号 in 下拉四:
    边 = 下拉边[态]
    子资.append("\n".join([
        '[sub_resource type="StyleBoxTexture" id="sb_combo_%s"]' % 态,
        'texture = ExtResource("%s")' % 加皮(路),
        "texture_margin_left = %s" % 边[0], "texture_margin_right = %s" % 边[2],
        "texture_margin_top = %s" % 边[1], "texture_margin_bottom = %s" % 边[3],
        "content_margin_left = %s" % 下拉内[0], "content_margin_right = %s" % 下拉内[1],
        "content_margin_top = %s" % 下拉内[2], "content_margin_bottom = %s" % 下拉内[3]]))
根 = "\n".join(['[node name="原版挂机设置内容" type="Control"]',
                "custom_minimum_size = Vector2(%d, %d)" % (页宽, 页高), "mouse_filter = 2"])
文本 = "\n\n".join(["[gd_scene load_steps=0 format=3]"] + ["\n".join(注释)]
                  + ['[ext_resource type="PackedScene" path="%s" id="k1"]' % 复选组件]
                  + 资源 + 子资 + [根] + 块) + "\n"
临时 = 场景路 + ".new"
with io.open(临时, "w", encoding="utf-8") as f:
    f.write(文本)
os.replace(临时, 场景路)
with io.open(期望路 + ".new", "w", encoding="utf-8") as f:
    json.dump(期望, f, ensure_ascii=False, indent=1)
os.replace(期望路 + ".new", 期望路)
print("件 %d / 场景块 %d / 期望键 %d / 皮 %d 张" % (len(件表), len(块), len(期望), len(资源)))
print("盒边 %s 输入边 %s 下拉normal %s" % (盒边, 输入边, 下拉边["normal"]))
for 项 in 件表:
    if 项["种"] in ("盒",) and 项["名"].startswith("盒"):
        print("  %s 窗口xywh=%s" % (项["名"], [项["x"], 项["y"], 项["宽"], 项["高"]]))
