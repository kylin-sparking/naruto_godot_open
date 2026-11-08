# -*- coding: utf-8 -*-
"""底栏精华容器上那一排（#185）+ 打坐四颗球（#203）的交互态烘焙 —— 幂等，重跑字节不变。

为什么只有这一份表（而不是每张皮单独跑）：`脚本/界面/技能面板.gd` 的 `_绑三态()` 是
**运行期按 `<主干>_悬停.png` / `_按下.png` 找皮**的，少烘一张不会报错 —— 那颗钮就静默
没有悬停/按下。这一排十件（四颗大钮 + 四枚收起小钮 + 折叠钮 + 折叠钮两态）加打坐四颗球
的皮必须一次配齐。

真值（`StyleUtil.as:7-12` / `:43-47`，skill `flash-mbutton3-state-skins`）：
  over = 逐通道 `clamp(rgb + 30)`、down = `clamp(rgb − 40)`、**alpha 原样**、只挂皮肤那一层。
  四颗大钮（元件 #322/#326/#330/#334）时间轴里**只有 `upSkin`、没有 `selectedUpSkin`**
  ⇒ 按 `MButton3.as:136-142` 的回落规则，选中组与非选中组是同一张图，只需要一组三态。

跑法：`python 开发工具/生成精华排态图.py`（自检不过直接 exit 非 0）
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from 派生钮态 import 派生

根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
皮目录 = os.path.join(根, "素材", "界面", "技能面板")
球目录 = os.path.join(根, "素材", "界面", "打坐四钮")

# (目录, 主干, 宽, 高, 这一张是谁) —— 尺寸写死是为了让"皮换错了"也能被抓到
源表 = [
	(皮目录, "hud_319", 31, 37, "打坐钮（元件 322 PractiseBtnF 的 upSkin）"),
	(皮目录, "hud_323", 31, 37, "通灵附身钮（326 PetBtn1F）"),
	(皮目录, "hud_327", 31, 37, "领取修行收益钮（330 BiGuanExpBtn）"),
	(皮目录, "hud_331", 31, 37, "挂机钮（334 GuaJiBtnF）"),
	(皮目录, "收起钮_坐", 17, 17, "收起版·打坐（UISwf_Text PractiseBtn2Skin）"),
	(皮目录, "收起钮_附", 17, 17, "收起版·通灵附身（PetBtn2Skin）"),
	(皮目录, "收起钮_修", 17, 17, "收起版·领取修行收益（BiGuanExpBtn2Skin）"),
	(皮目录, "收起钮_挂", 17, 17, "收起版·挂机（GuaJiBtn2Skin）"),
	(皮目录, "精华折叠钮", 13, 8, "容器折叠箭头（元件 382 ArrowBtnF）"),
	# 打坐时围着角色的四颗球（`ButtonsWindow` 的 `UISwf_ButtonsWindow_Btn`）—— 同一族 MButton3，
	# 只是这颗的**可见圆**在 43×37 画布里占 x 3..40（左右各 3px 是透明边）。
	(球目录, "球钮", 37, 37, "打坐四颗球（UISwf_ButtonsWindow_Btn 裁掉 ffdec 的 3px 透明边后 = 37×37，正好等于命中框）"),
]


def 主() -> int:
	落 = []
	for 目录, 主干, 宽, 高, 说明 in 源表:
		源 = os.path.join(目录, "%s.png" % 主干)
		if not os.path.isfile(源):
			raise SystemExit("缺常态皮：%s（%s）" % (源, 说明))
		尺寸 = 派生(源)[0][1]
		if 尺寸 != (宽, 高):
			raise SystemExit("%s 尺寸 %s != 元件时间轴 %s（%s）" % (主干, 尺寸, (宽, 高), 说明))
		for 后缀 in ("悬停", "按下"):
			落.append("%s/%s_%s.png" % (os.path.basename(目录), 主干, 后缀))
	print("烘了 %d 张派生态皮（每张逐字节 == clamp(常态 ±30/−40)，alpha 原样）：" % len(落))
	for 名 in 落:
		print("  %s" % 名)
	return 0


if __name__ == "__main__":
	sys.stdout.reconfigure(encoding="utf-8")
	sys.exit(主())
