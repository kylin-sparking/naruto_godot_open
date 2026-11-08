extends RefCounted
## 结印页「提升结印阶数弹窗」的文案 —— 全部取自 Flash 原版语言表，不要改写。
##
## 出处（可复查）：`2.2.3/map_extract/out/mainlib_as/scripts/en_US$message_properties.as`
##   · `JIEYIN_AUTO_TISHENG_PROMPT` —— 自动提升的二次确认正文（`JieYinTiShengWindow.autoTiShengHandler:75`
##     用 `FamillyPopUpWindow.popUpWindow(...)` 弹出来，确认了才 `sureToAutoTiSheng`）。
##     原文三条停止条件就是下面 `自动确认正文` 的那三行，逐字照抄。
##   · `JIEYIN_TISHENG_PROMPT` / `ROUQUAN_TISHENG_PROMPT` / `EQUIP_STRENGTH_FAIL_PROMPT_2_1`
##     —— 三处"精华不够"的提示（`tiShengJieYin:89-108` 与 `autoTiShengHandler:80`）。
##   · `TISHENG_TONGSHU_WINDOW_ZIDONGTISHENG` / `ROUQUAN_STOP_TISHENG` —— 自动钮的两态文字。
## ⚠️ 运行期不能 import 2.2.3（§3.89），所以原文烘在这里。

## `%1` = 物品名（原版这里传 `CHARACTOR_BREATH` = 「精华」）。
const 手动不够 := "很抱歉，你的%1不够"	# EQUIP_STRENGTH_FAIL_PROMPT_2_1
const 自动不够 := "您的背包内没有足够数量的【%1】，已停止自动提升"	# ROUQUAN_TISHENG_PROMPT
const 点自动时不够 := "【查克拉精华】不足，已停止自动提升"	# JIEYIN_TISHENG_PROMPT

## 原版这一段是 `<font color='#ff0000'>` 第一行 + `<font color='#fff000'>` 其余四行，
## 里面的 `\r` 就是换行（Flash TextArea 认 `\r`，这里写成 `\n`）。
## **颜色标记留着**：`输入确认弹.弹消息` 会把 `<font color>` 折成 BBCode，
## 于是弹出来的配色与原版一致（别在这里提前剥掉，剥了就只剩白字）。
## ⚠️ 这一段有**五行** ⇒ `弹消息` 的高度必须按行数量（修前写死一行 23px，
##   钮会直接压在正文上）；那条已经由 `人物窗口` 这侧一并修掉。
const 自动确认正文 := """<font color='#ff0000'>你确定自动使用已有查克拉精华提升结印境界？\n</font><font color='#fff000'>当遇到以下情况时，系统会停止自动提升操作：\n1 剩余的查克拉精华小于1000\n2 结印阶段成功的提升到了下一层\n3 尝试手动提升操作或点击停止提升按钮</font>"""

const 按钮自动 := "自动提升"	# TISHENG_TONGSHU_WINDOW_ZIDONGTISHENG
const 按钮停止 := "停止提升"	# ROUQUAN_STOP_TISHENG
const 精华名 := "精华"	# CHARACTOR_BREATH
