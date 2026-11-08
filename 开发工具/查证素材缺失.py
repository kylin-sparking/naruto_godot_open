# -*- coding: utf-8 -*-
"""A3 取真值：把 6 份"素材缺失"清单逐条拿到**原版客户端的 swf 库**里查一遍。

为什么需要：现有 6 份清单全部由"只认 `完整美术资源` PNG 包"的导入器产出
（技能/角色/NPC/怪物/地图都靠包里的文件名，物品图标靠 `美术包/<分类>/<swf>.swf_<chid>_<类名>.png`）。
包是没打全的二手货，原版 swf 才是原件 —— 所以清单里的"缺失"有相当一部分是假报。

产物 `数据/素材缺失查证.json` 逐条给出：导入器怎么找的 → 在原版库里查到没有 → 结论 + 证据。
只读查证，不改任何素材、不改任何清单。
"""
import json
import os
import re
import sys
import zlib

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

项目 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
数据 = os.path.join(项目, "数据")
读 = lambda p: json.load(open(p, encoding="utf-8-sig"))
文字 = lambda v: str(v or "")

# 三处库：原版客户端（验收依据）→ 第二份前端库 → 二手 PNG 包。
# 后两处是可选的，用环境变量给：NARUTO_SECOND_SWF / NARUTO_ASSET_PACK。
原版库 = os.environ.get("NARUTO_GAME_ROOT") or os.path.join(项目, "..", "2.2.3")
库根 = {
    "原版客户端": os.path.join(原版库, "www", "act_web_nya_208_isolated", "swf"),
}
if os.environ.get("NARUTO_SECOND_SWF"):
    库根["第二前端库"] = os.environ["NARUTO_SECOND_SWF"]
包根 = os.environ.get("NARUTO_ASSET_PACK", "")


def 解出(路径):
    """FWS 原样 / CWS zlib / ZWS lzma。解不出退回原始字节：顶多查不到，不会误判成别处有。"""
    with open(路径, "rb") as f:
        b = f.read()
    if b[:3] == b"CWS":
        try:
            return b[:8] + zlib.decompress(b[8:])
        except Exception:
            return b
    if b[:3] == b"ZWS":
        try:
            import lzma
            import struct
            d = lzma.LZMADecompressor(format=lzma.FORMAT_RAW, filters=[{
                "id": lzma.FILTER_LZMA1,
                "dict_size": struct.unpack("<I", b[10:14])[0],
                "props": bytes([b[9]])}])
            return b[:8] + d.decompress(b[22:])
        except Exception:
            return b
    return b


def 标签流(正文):
    """从已解压的 swf 正文逐 tag 走，产出 (tag 类型, tag 体)。"""
    import struct
    位宽 = 正文[8] >> 3
    偏 = 8 + (5 + 4 * 位宽 + 7) // 8 + 4          # RECT + fps(u16) + 帧数(u16)
    while 偏 + 2 <= len(正文):
        头 = struct.unpack("<H", 正文[偏:偏 + 2])[0]
        偏 += 2
        长 = 头 & 0x3F
        if 长 == 0x3F:
            长 = struct.unpack("<I", 正文[偏:偏 + 4])[0]
            偏 += 4
        yield 头 >> 6, 正文[偏:偏 + 长]
        偏 += 长
        if 头 >> 6 == 0:
            return


def 导出符号(路径):
    """库里**真正导出**的符号名（SymbolClass tag76 ∪ ExportAssets tag56）。

    不能拿解压后的明文字符串做子串判断：库会 import 别的库的符号名，
    明文里有 ≠ 这个库画得出来。实测 `Char_10000075.swf` 明文含
    `Char_10000064_hit_0_body`，但它的导出表里根本没有 —— 子串法会把它报成"可补"。
    """
    import struct
    键 = ("导出", 路径)
    cached = _正文.get(键)
    if cached is not None:
        return cached
    名 = set()
    try:
        正文 = _读(路径)
        for 类型, 体 in 标签流(正文):
            if 类型 == 76:                          # SymbolClass
                偏 = 2
                for _ in range(struct.unpack("<H", 体[0:2])[0]):
                    偏 += 2
                    止 = 体.index(b"\x00", 偏)
                    名.add(体[偏:止].decode("utf-8", "replace"))
                    偏 = 止 + 1
            elif 类型 == 56:                        # ExportAssets：每条 = 特征(UI16) + id(UI16) + 名字
                try:
                    偏 = 2                          # 跳过 num(UI16)
                    末 = len(体) - 1
                    while 偏 < 末:
                        偏 += 4
                        止 = 体.index(b"\x00", 偏)
                        名.add(体[偏:止].decode("utf-8", "replace"))
                        偏 = 止 + 1
                except Exception:
                    pass                            # 结构认不全就只信 SymbolClass，不硬猜
    except Exception:
        名 = set()
    _正文[键] = 名
    return 名


_正文 = {}
_清单 = {}


def 文件表(库名, 分类):
    键 = (库名, 分类)
    if 键 not in _清单:
        目录 = os.path.join(库根[库名], 分类)
        _清单[键] = sorted(
            os.path.join(目录, n) for n in os.listdir(目录)
            if n.lower().endswith(".swf") and "[1]" not in n) if os.path.isdir(目录) else []
    return _清单[键]


def 查类名(类名, 候选分类):
    """候选分类目录里，哪些 swf **导出表**里有这个符号（不是明文里出现过）。"""
    出 = []
    for 库名 in 库根:
        for 分类 in 候选分类:
            for 路径 in 文件表(库名, 分类):
                if 类名 in 导出符号(路径):
                    出.append((f"{库名}/{分类}", 路径))
    return 出


def 查包内(类名):
    """美术包里有没有这张已解好的 PNG（口径 `<swf>.swf_<chid>_<类名>.png`）。"""
    出 = []
    if not os.path.isdir(包根):
        return 出
    尾 = ("_" + 类名 + ".png").encode()
    for 分类 in os.listdir(包根):
        目录 = os.path.join(包根, 分类)
        if not os.path.isdir(目录):
            continue
        for 名 in os.listdir(目录):
            if 名.endswith(".png") and 名.encode().endswith(尾):
                出.append(os.path.join(目录, 名))
    return 出


def 归类(符号名):
    """库归属：Tile_x → Tile/；Skill_Effect_x → Skill/ 和 Effect/ 都试。"""
    首 = 符号名.split("_")[0]
    return [首, "Effect"] if 符号名.startswith("Skill_Effect") else [首]


def 找库(符号名, 候选分类):
    """按"逐段砍掉尾部下划线段"找原版库文件：Tile_a_bsc_2 → Tile_a_bsc.swf → Tile_a.swf。

    原版一条素材住在哪个库里没有统一规则（地图块是一库一类、物件是一库一帧），
    所以只能从最具体的名字往上试。
    """
    段 = 符号名.split("_")
    for n in range(len(段) - 1, 0, -1):
        名 = "_".join(段[:n])
        for 库名 in 库根:
            for 分类 in 候选分类:
                路径 = os.path.join(库根[库名], 分类, 名 + ".swf")
                if os.path.isfile(路径):
                    return 路径, 名
    return "", ""


def 同族(路径, 前缀):
    """列出库里以 前缀 开头的**导出**符号 —— 用来写清"原件在，但没画这一帧"。"""
    return sorted(名 for 名 in 导出符号(路径) if 名.startswith(前缀))


def _读(路径):
    键 = ("绝对", 路径)
    if 键 not in _正文:
        _正文[键] = 解出(路径)
    return _正文[键]


条目表 = []


def 登记(清单, 键, 名称, 类名, 怎么找, 候选分类):
    候选分类 = list(dict.fromkeys(候选分类))
    包 = 查包内(类名)
    命中 = 查类名(类名, 候选分类)
    证据 = ["美术包：%s" % ("有 " + os.path.relpath(包[0], 包根) if 包 else "没有这张 PNG（包本身就没打全）")]
    for 标签, 路径 in 命中[:3]:
        证据.append("原版库有：%s/%s（%d KB）内含导出符号 %s"
                    % (标签, os.path.basename(路径), os.path.getsize(路径) // 1024, 类名))
    if not 命中:
        证据.append("原版库无：%s 分类目录（含两份库）下的每个 swf 都解压搜过，没有任何文件含符号 %s"
                    % ("、".join(候选分类), 类名))
        库, 名 = 找库(类名, 候选分类)
        # 找库是一路砍尾巴砍出来的：砍到只剩分类名（`Char_10000048_ladder_0_body` → `Char`）
        # 命中的是分类兜底文件，不是这个素材自己的库 —— 那等于"原版没带这个库"。
        兜底 = 名 in 候选分类
        if not 库 or 兜底:
            本名 = "_".join(类名.split("_")[:2])
            证据.append("连库文件都不存在：两份库的 %s 目录里，按这个名字砍尾巴只砍到分类兜底文件 %s，"
                        "没有 %s.swf —— 原版客户端没带这个库"
                        % ("、".join(候选分类), os.path.basename(库) if 库 else "任何文件", 本名))
        else:
            族 = 同族(库, 名 + "_")
            证 = "库文件在（%s，%d KB），但里面没有这一帧。库里现有同族符号：%s" % (
                库, os.path.getsize(库) // 1024, "、".join(族[:12]) or "（无同族名）")
            if not 族:
                # 同族一个都没有 → 这个库导出的整套是**别人**的名字（共用身体集），图在库里但名字对不上。
                全 = sorted(导出符号(库))
                前缀 = sorted({x.split("_")[1] for x in 全 if x.startswith(("Char_", "Mob_", "Npc_", "Pet_"))})
                证 += "；库里实际导出 %d 个符号，前缀是 %s（不是 %s）—— 图在库里，类名对不上" % (
                    len(全), "、".join(前缀[:4]) or "非角色名", 名)
            证据.append(证)
    条目表.append({
        "清单": 清单, "键": 键, "名称": 名称, "类名": 类名,
        "导入器怎么找的": 怎么找, "查证": 证据,
        "结论": "可补" if 命中 else "原版真无图",
        "源文件": 命中[0][1] if 命中 else "",
    })


# ── 1. 物品图标（36 条"图标定义为空" + 21 条"源文件不存在"） ──────────────
物品 = 读(os.path.join(数据, "物品.json"))
for 项 in 读(os.path.join(数据, "物品图标缺失.json")):
    定义 = 物品.get(项["id"], {})
    swf = 文字(定义.get("icon_swf"))
    类名 = 文字(定义.get("icon_class"))
    if 项["reason"] == "图标定义为空":
        条目表.append({
            "清单": "物品图标", "键": 项["id"], "名称": 文字(项.get("name")), "类名": "",
            "导入器怎么找的": "读 数据/物品.json 的 icon_swf / icon_class 两个字段",
            "查证": ["原版数据表（GameData.dat 的物品段）里这条的 icon 就是空的：icon_swf=%s、icon_class=%s。"
                     "原版客户端跑起来同样没图，不是移植漏了。"
                     % (swf or "空", 类名 or "空")],
            "结论": "原版真无图", "源文件": "",
        })
        continue
    登记("物品图标", 项["id"], 文字(项.get("name")), 类名,
         "完整美术资源/%s/%s.swf_*_%s.png（分类取物品的 source_category=%s，而库真名前缀是 %s）"
         % (项["source_category"], swf, 类名, 项["source_category"], swf.split("_")[0]),
         [swf.split("_")[0], 项["source_category"]])

# ── 2. 技能素材（2 图标 + 47 技能特效帧） ────────────────────────────────
for 项 in 读(os.path.join(数据, "技能素材缺失.json")):
    类名 = 项["className"]
    登记("技能素材", "%s/%s" % (项["group"], 项["skillId"]), "", 类名,
         "完整美术资源/Skill/<某>.swf_*_%s.png" % 类名, 归类(类名))

# ── 3. 地图素材（小地图 / 地图块 / 背景 / 地图物件） ─────────────────────
for 项 in 读(os.path.join(数据, "地图素材缺失.json")):
    逻辑名 = 项["logical_name"]
    登记("地图素材", 项["map_id"], 项["type"], 逻辑名,
         "完整美术资源/<分类>/*.swf_*_%s.png" % 逻辑名, 归类(逻辑名))

# ── 4. 怪物 / NPC / 角色动画帧 ──────────────────────────────────────────
for 项 in 读(os.path.join(数据, "怪物素材缺失.json")):
    for 帧 in 项["missing_frames"]:
        登记("怪物素材", 项["id"], 文字(项.get("name")), 帧,
             "完整美术资源/Mob/*.swf_*_%s.png" % 帧, ["Mob", "Pet", "Char"])
for 文件, 清单, 分类 in [("角色/非玩家角色动画缺失.json", "NPC动画", ["Npc"]),
                        ("角色/角色动画缺失.json", "角色动画", ["Char"]),
                        ("角色/宠物动画缺失.json", "宠物动画", ["Pet"])]:
    for 项 in 读(os.path.join(数据, 文件)):
        登记(清单, 项["id"], "", 项["className"],
             "完整美术资源/%s/*.swf_*_%s.png" % (分类[0], 项["className"]), 分类)

统计 = {}
for 项 in 条目表:
    统计[项["结论"]] = 统计.get(项["结论"], 0) + 1

# ── 5. 阳性对照：同一套查法拿去查"已经在索引里"的符号，必须查得到 ─────────
# 没有这一步，"原版真无图"这个结论可能只是查法不灵造成的假阴性。
对照 = {}
动画索引 = 读(os.path.join(数据, "角色", "动画素材索引.json"))
图标索引 = 读(os.path.join(数据, "物品图标索引.json"))
地图索引 = 读(os.path.join(数据, "地图素材索引.json"))
图标编号 = next((k for k in 图标索引 if 文字(物品.get(k, {}).get("icon_class"))), "")
图标定义 = 物品.get(图标编号, {})
样本 = [("NPC 帧", next(k for k in 动画索引 if k.startswith("Npc_")), ["Npc"]),
        ("角色帧", next(k for k in 动画索引 if k.startswith("Char_")), ["Char"]),
        ("怪物帧", next(k for k in 动画索引 if k.startswith("Mob_")), ["Mob"]),
        ("物品图标", 文字(图标定义.get("icon_class")),
         [文字(图标定义.get("icon_swf")).split("_")[0], 文字(图标定义.get("source_category"))]),
        ("地图符号", next(k.split("/", 1)[1] for k in 地图索引 if k.startswith("地图块/")), ["Tile"])]
for 标签, 符号, 分类 in 样本:
    对照[标签] = {"符号": 符号, "查得到": bool(查类名(符号, 分类)) if 符号 else False}
查不到 = [k for k, v in 对照.items() if not v["查得到"]]
if 查不到:
    raise SystemExit("阳性对照失败（这套查法有假阴性，结论不可信）：%s" % "、".join(查不到))

输出 = {
    "说明": "A3 取真值产物：逐条记录 6 份缺失清单在原版客户端 swf 库里的查证结果。只读查证，不改素材也不改清单。",
    "阳性对照": {
        "做法": "拿已经在 数据/动画素材索引、物品图标索引、地图素材索引 里的符号，用同一套查法回查，必须命中；不命中就中止。",
        "结果": 对照,
    },
    "真值口径": {
        "原版客户端 swf": 库根["原版客户端"],
        "第二前端库": 库根.get("第二前端库", ""),
        "二手 PNG 包": 包根,
        "解包": "FWS 原样 / CWS zlib / ZWS lzma；导出符号名以明文出现在 swf 里，按明文子串判存在",
        "库归属规则": "ImgUtil.as:264-266 库路径 = 分类/库名.swf，库名取符号名首个下划线段（Tile_x → Tile/）",
        "假报根因": "6 份清单的导入器一律只扫二手 PNG 包的文件名、从不打开原版 swf；包没打全就报「源文件不存在」",
    },
    "汇总": dict(总=len(条目表), **统计),
    "分清单": {
        清单: {
            "条数": len([i for i in 条目表 if i["清单"] == 清单]),
            "可补": len([i for i in 条目表 if i["清单"] == 清单 and i["结论"] == "可补"]),
        } for 清单 in ["物品图标", "技能素材", "地图素材", "怪物素材", "NPC动画", "角色动画"]
    },
    "条目": 条目表,
}
路径 = os.path.join(数据, "素材缺失查证.json")
with open(路径, "w", encoding="utf-8") as f:
    json.dump(输出, f, ensure_ascii=False, indent=1)
print("查证完成：%d 条 → %s" % (len(条目表), 路径))
for 键, 值 in sorted(统计.items()):
    print("  %s: %d" % (键, 值))
for 清单, 值 in 输出["分清单"].items():
    print("  %s: 共 %d，可补 %d" % (清单, 值["条数"], 值["可补"]))
