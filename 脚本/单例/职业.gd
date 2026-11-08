extends RefCounted

## 职业：**职号 → 显示名**。全项目**唯一一份**。
##
## 真值出处（三条合起来才是完整的）：
##   * 职号常量 `CocoJob.as:6-14` —— `NINJA_FIRE=100 / WATER=200 / LIGHTING=300 /
##     WIND=400 / EARTH=500`；
##   * 映射函数 `JobTool.getJobName`（`com/mxw/common/tools/JobTool.as:25-42`）——
##     是个 **switch 分派**，不是数组、也不是语言表直查；
##   * 中文名在语言表 `en_US$message_properties.as:3301/1484/1578/1691/2792`
##     （`JOB_FIRE_NAME` / `JOB_WATER_NAME` / `JOB_LIGHTING_NAME` / `JOB_WIND_NAME` /
##     `JOB_EARTHE_NAME`）。
##
## ⚠️ **是五个，不是四个** —— 除了火 / 水 / 雷 / 风，还有 **土遁流(500)**。
## 之前这里被三处各写各的：`装备提示框.gd` 那份是对的，而离线示例数据写成了
## "体术流"、登录页写成了"体术流 / 忍术流 / 幻术流" —— 全是自造的
## （`体术流` 在原版 AS3 全量 grep **零命中**；`体术` 只出现在装备属性的
## "体术命中率/体术闪避率/体术防御力"里，跟职业无关）。
##
## ⚠️ 转职细分值（`getAllJobs` 里还有 110/111/112… 那种十位个位带转职层的）：
## 原版 `getJobName` **只精确匹配这五个**，其余一律落到 `default` 返回**空串**。照做。
const 表 := {
	100: "火遁流",
	200: "水遁流",
	300: "雷遁流",
	400: "风遁流",
	500: "土遁流",
}


## 职号 → 职业名。查不到返回空串（与原版 default 分支一致，**不要**自己编一个）。
static func 取(职号: int) -> String:
	return String(表.get(职号, ""))


## 选择列表用的全部职业（按职号升序）。
static func 全部() -> Array:
	var 键 := 表.keys()
	键.sort()
	var 出: Array = []
	for k in 键:
		出.append({"值": k, "名": 表[k]})
	return 出
