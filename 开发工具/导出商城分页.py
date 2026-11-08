# -*- coding: utf-8 -*-
"""导出商城的页签真值 —— `数据/界面/商城分页.json`。

真值出处（原版 AS3，逐行核过）
------------------------------
`com/mxw/uifl/controls/cashShop/CashShopWindow2.as:171-210`：

    var _loc2_:Object = ImgUtil.getImg(ImgType.String_, "ShangCheng");
    _loc3_ = _loc2_.yuanbao;
    while(_loc4_ < 20) {
       if(!_loc3_.hasOwnProperty("tab" + _loc4_)) break;
       this.menuTexts.push(String(_loc3_["tab" + _loc4_]));
       _loc4_++;
    }
    if(this.menuTexts.indexOf(LangUtil.get("CASHSHOP_RONGYU")) == -1)
       this.menuTexts.push(LangUtil.get("CASHSHOP_RONGYU"));

即：页签文字**不是写死的**，来自 GameData 的 `String/ShangCheng` 分组里 `yuanbao.tab0..tabN`，
读满 20 个或遇到缺号为止；末尾再追加一个「荣誉类」（`CASHSHOP_RONGYU`，`en_US$message_properties.as:1627`）。

⚠️ 两条别搞错：
1. **页签下标就是分类 id**。`CashShopWindow2.as:149` `selectedSecondType = this.tabs.indexOf(param1)`，
   这个值原样进 `REQUEST_ITEM_LIST.categoryId`（`:570`）→ 发的是原版 432 包的第二个字段。
   所以「常用类」=0、「药品类」=1……**不能拿它当"我们自己的枚举"另起一套**。
2. **「荣誉类」不进商品请求**。`:129-138` 先判 `param1.text == CASHSHOP_RONGYU` → 显示 RongYuPanel，
   直接 return，不发 432。所以它是个"面板页签"，不是分类。

本地服务端的对应关系在 `2.2.3/tools/fake_flash_server.py:1333` 的 `CashShopCategory`
（COMMON=0 … ACTIVITY=6，缺 7=福利类），那是**服务端**的实现口径，不是客户端真值 ——
两者不一致时以本表为准，缺货的分类服务端返回空列表即可。

用法：
    python 开发工具/导出商城分页.py
"""

import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 原版数据 as Y  # noqa: E402

产物 = r".\数据\界面\商城分页.json"

## `CashShopWindow2.as:179` 的 `while(_loc4_ < 20)`。原版最多读 20 个 tab。
页签上限 = 20

## `en_US$message_properties.as:1627` CASHSHOP_RONGYU。
## 原版是从语言表取的，这里跟着语言表读，别写死。
荣誉类兜底 = "荣誉类"


def 主() -> int:
    段 = Y.取字符串段("ShangCheng")
    if not isinstance(段, dict):
        sys.exit("GameData 里没有 String/ShangCheng 分组（拿到 %s）" % type(段))
    yuanbao = 段.get("yuanbao")
    if not isinstance(yuanbao, dict):
        sys.exit("String/ShangCheng 里没有 yuanbao（拿到 %s）" % type(yuanbao))

    页签 = []
    for i in range(页签上限):
        键 = "tab%d" % i
        if 键 not in yuanbao:
            break
        页签.append(str(yuanbao[键]))

    荣誉 = Y.语言("CASHSHOP_RONGYU", 荣誉类兜底)
    if 荣誉 not in 页签:
        页签.append(荣誉)

    输出 = {
        "_说明": (
            "商城页签真值。原版 CashShopWindow2.as:171-191 从 GameData 的 "
            "String/ShangCheng.yuanbao.tab0..tab19 顺序读，遇到缺号停；"
            "末尾若没有「荣誉类」再追加一个（语言表 CASHSHOP_RONGYU）。"
            "**数组下标就是发给服务端 432 包的 categoryId**（CashShopWindow2.as:149/570），勿另立一套枚举。"
            "「荣誉类」是面板页签：点它显示 RongYuPanel 荣誉积分面板、**不发商品请求**（:129-138）。"
            "配套生成器：开发工具/导出商城分页.py。"
        ),
        "_来源": "GameData.dat → String/ShangCheng → yuanbao",
        "页签": 页签,
        "荣誉页签名": 荣誉,
    }

    os.makedirs(os.path.dirname(产物), exist_ok=True)
    # ⚠️ 显式 `newline="\n"`：Windows 下默认会把 \n 翻成 \r\n，与本仓 .gitattributes
    #    的 `* text=auto eol=lf` 打架，之后每次 add 都报 CRLF 并被规范化出假 diff。
    with io.open(产物, "w", encoding="utf-8", newline="\n") as 文件:
        文件.write(json.dumps(输出, ensure_ascii=False, indent=1))
        文件.write("\n")
    print("已写出 %s" % 产物)
    print("页签 %d 个：" % len(页签))
    for i, 名 in enumerate(页签):
        print("  [%d] %s%s" % (i, 名, "   ← 荣誉类（面板页签，不发 432）" if 名 == 荣誉 else ""))
    return 0


if __name__ == "__main__":
    sys.exit(主())
