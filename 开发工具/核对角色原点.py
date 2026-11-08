# -*- coding: utf-8 -*-
"""把客户端 `数据/角色/动画元数据.json` 的角色帧 origin 与 2.2.3 GameData 的 M_Char 对照。

为什么要做：客户端角色数据是 `导出原版角色动画.mjs` 从**第三方服务端包**
（..\\..\\code\\火影世界服务端\\GameData.dat.json）导的，不是 2.2.3。
而 `origin` 决定角色贴图相对角色坐标的落点 —— 原点偏多少，角色就陷进地面多少。

用法: python 开发工具/核对角色原点.py [角色id ...]
"""
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

GC = r"."
NYA = r"2.2.3"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # 服务端目录在本目录
import 服务端目录  # noqa: E402
fs = 服务端目录.加载()  # 项目内那份 fake_flash_server

META = os.path.join(GC, "数据", "角色", "动画元数据.json")
IMG_ROOT = os.path.join(GC, "素材", "角色动画", "玩家", "木叶忍者_00000001")


def main():
    ids = sys.argv[1:] or ["00000001"]
    root = fs.Amf3Reader(
        (os.path.join(NYA, "www", "act_web_nya_208_isolated", "dat", "GameData.dat")).encode()
        if False else
        open(os.path.join(NYA, "www", "act_web_nya_208_isolated", "dat", "GameData.dat"), "rb").read()
    ).read_value()
    print("2.2.3 GameData 顶层段数=%d" % len(root))
    for k in ("M_Char", "Char", "M_Char_", "CharAction"):
        if k in root:
            node = root[k]
            print("  有段 %s：%s" % (k, list(node)[:8] if isinstance(node, dict) else type(node)))
    mchar_raw = root.get("M_Char") or {}

    def dec(blob):
        # 段里的载荷可能是 zlib 压的 AMF3（和 Skill 段一样），要一层层解
        cat = fs.GAME_DATA_CATALOG
        while isinstance(blob, (bytes, bytearray)):
            blob = cat._decode_section(blob)
        return blob

    mchar = {}
    for k, v in mchar_raw.items():
        mchar[str(k)] = dec(v)
    with open(META, encoding="utf-8-sig") as f:
        meta = json.load(f)
    for cid in ids:
        o = mchar.get(cid)
        c = meta["character"].get(cid)
        print("\n=== 角色 %s" % cid)
        print("  2.2.3 M_Char 有: %s   客户端有: %s" % (o is not None, c is not None))
        if o is None or c is None:
            continue
        for act in ("stand", "walk", "jump", "rope", "ladder"):
            oa, ca = o.get(act), c.get(act)
            if not oa or not ca:
                print("  %-6s 2.2.3=%s 客户端=%s" % (act, bool(oa), bool(ca)))
                continue
            diff = []
            for k in sorted(set(oa) | set(ca), key=lambda s: int(s) if s.isdigit() else 0):
                of = (oa.get(k) or {}).get("body") or {}
                cf = (ca.get(k) or {}).get("body") or {}
                oo, co = of.get("origin"), cf.get("origin")
                if oo != co:
                    diff.append("帧%s 原版=%s 客户端=%s" % (k, oo, co))
            print("  %-6s 帧数 原版=%d 客户端=%d  origin 差异=%d %s" % (
                act, len(oa), len(ca), len(diff), diff[:3]))
    # 贴图尺寸参考
    import glob
    from PIL import Image
    for p in sorted(glob.glob(os.path.join(IMG_ROOT, "*stand_0_body*"))):
        im = Image.open(p)
        print("\n贴图 %s 尺寸=%s" % (os.path.basename(p), im.size))


if __name__ == "__main__":
    main()
