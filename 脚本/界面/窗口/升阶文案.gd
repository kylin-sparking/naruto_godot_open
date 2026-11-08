extends RefCounted
## 写轮眼 / 柔拳 / 轮回六道三族「提升阶数弹窗」的文案 —— 逐字取自 Flash 原版语言表，不要改写。
##
## 出处（可复查）：`2.2.3/map_extract/out/mainlib_as/scripts/en_US$message_properties.as`
##   · `ROUQUAN_AUTO_TISHENG_PROMPT`:528 —— 柔拳自动提升的二次确认正文
##     （`RouQuanTiShengWindow.autoTiShengHandler:90`，`FamillyPopUpWindow.popUpWindow(...)`）；
##   · `LUNHUIYAN_AUTO_TISHENG_PROMPT`:994 —— 轮回六道那一段（`LunHuiYanTiShengWindow.autoTiShengHandler:248`）；
##   · `TISHENG_TONGSHU_WINDOW_ZIDONGTISHENG_SAY`:2129 —— 写轮眼那一段（`TishengTongshuPanel.onClickZidongBtn:262-263`，
##     原版只给一枚「确定」`COMMON_OK`，我们这边弹的是通用消息型确认 ⇒ 多一枚取消，按"取消＝什么都不做"处理）；
##   · `TISHENG_TONGSHU_WINDOW_ZIDONGTISHENG`:102 / `ROUQUAN_STOP_TISHENG`:2006 —— 自动钮的两态文字（四族共用这两条）。
##
## ⚠️ 运行期不能 import 2.2.3（§3.89），所以原文烘在这里。
## ⚠️ 原文里的 `\r` 与 `<br/>` 都是换行，这里统一写成 `\n`；`<font color>` **留着别剥** ——
##   `输入确认弹.弹消息` 会把它折成 BBCode，弹出来才与原版配色一致（剥了就只剩白字）。
##   正文占几行由 `弹消息` 按真实折行量（结印那次的教训：写死一行 ⇒ 按钮压在文字上）。

## 段数按原文：红字第一行 + 黄字三条停止条件 + 蓝字「神符优先」那句。
## ⚠️ 柔拳/轮回原文的 1/2/3 各带 `\r`（各自一行），写轮眼原文的「操作：」与「1 …」之间**没有**分隔符
##   ⇒ 那两半在同一行里（照抄，不替原版补换行）。
const 确认正文 := {
	"柔拳": "<font color='#ff0000'>你确定自动使用背包中的柔拳灵符提升瞳术境界？\n</font><font color='#fff000'>当遇到以下情况时，系统会停止自动提升操作：\n1 背包内剩余的提升道具已使用完毕\n2 柔拳阶段成功的提升到了下一层\n3 尝试手动提升操作或点击停止提升按钮</font>\n<font color='#1e90ff'>在柔拳4阶以后，若背包中有柔拳神符，则每次自动提升时优先使用柔拳神符。</font>",
	"轮回六道": "<font color='#ff0000'>你确定自动使用背包中的轮回灵符提升轮回六道境界？\n</font><font color='#fff000'>当遇到以下情况时，系统会停止自动提升操作：\n1 背包内剩余的提升道具已使用完毕\n2 轮回六道成功提升到下一阶段\n3 尝试手动提升操作或点击停止提升按钮</font>\n<font color='#1e90ff'>在轮回六道4阶以后，若背包中有轮回神符，则每次自动提升时优先使用轮回神符。</font>",
	"写轮眼": "<font color='#ff0000'>你确定自动使用背包中的写轮眼灵符提升写轮眼境界？</font>\n<font color='#fff000'>当遇到以下情况时，系统会停止自动提升操作：</font><font color='#fff000'>1 背包内剩余的提升道具已使用完毕</font>\n<font color='#fff000'>2 写轮眼阶段成功的提升到了下一层</font>\n<font color='#fff000'>3 尝试手动提升操作或点击停止提升按钮</font>\n<font color='#1e90ff'>在写轮眼4阶以后，若背包中有写轮眼神符，则每次自动提升时优先使用写轮眼神符。</font>",
}

## `%1`（写轮眼那条是 `%1` 与 `%2`，原版两处传的是**同一个**物品名 ——
## `TishengTongshuPanel.requestXinLunyan:319` 把 `getItemString(needItemId)` 填了两遍）。
## 自动那一跳中途不够 ⇒ 这句 + **停掉自动**（`RouQuanTiShengWindow:136-137`、
## `LunHuiYanTiShengWindow:183-184`、`TishengTongshuPanel:318-319`）。
## ⚠️ 柔拳与轮回六道**共用** `ROUQUAN_TISHENG_PROMPT`:2416 那一句（原版如此，不"纠正"成轮回专用文案）。
const 自动不够 := {
	"柔拳": "您的背包内没有足够数量的【%1】，已停止自动提升",
	"轮回六道": "您的背包内没有足够数量的【%1】，已停止自动提升",
	"写轮眼": "背包内%1数量不足：你的背包内没有足够数量的【%2】，已停止自动提升。",
}

## 手动那一跳不够 / **点「自动提升」时就不够** ⇒ 这两处原版是**同一句**、都不弹确认、都不动定时器：
## `RouQuanTiShengWindow:95`（点自动）与 `:141`（手动）、`LunHuiYanTiShengWindow:188/253`、
## `TishengTongshuPanel:145/267`（写轮眼换的是 `CHONG_MAI_WINDOW_SORRY_WUPIN_BUGOU`:3034）。
const 手动不够 := {
	"柔拳": "很抱歉，你的%1不够",
	"轮回六道": "很抱歉，你的%1不够",
	"写轮眼": "很抱歉，你的背包中没有足够的%1！",
}

const 按钮自动 := "自动提升"	# TISHENG_TONGSHU_WINDOW_ZIDONGTISHENG:102
const 按钮停止 := "停止提升"	# ROUQUAN_STOP_TISHENG:2006
