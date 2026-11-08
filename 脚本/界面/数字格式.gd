extends RefCounted

## 数字显示口径，逐条照原版 `com/mxw/uifl/base/utils/BaseUtil.as`。

## `BaseUtil.formatNumber`（as:150）：**大于 999 才加千分位**，否则原样输出。
##
## 原文的算法是"反转字符串、从末尾每 3 位插一个逗号"，对整数就是标准千分位；
## 对负数/小数原版会插错位（`-1234` → `-,1,234` 这种），但原版调用点喂的都是
## 正整数的金额/数量，所以这里只保证整数行为一致，并在负数上走同一条算法。
static func 千分位(值: int) -> String:
	if absi(值) <= 999:
		return str(值)
	var 负 := 值 < 0
	var 数字 := str(absi(值))
	var 出 := ""
	var 计 := 0
	for i in range(数字.length() - 1, -1, -1):
		if 计 > 0 and 计 % 3 == 0:
			出 = "," + 出
		出 = 数字[i] + 出
		计 += 1
	return ("-" if 负 else "") + 出
