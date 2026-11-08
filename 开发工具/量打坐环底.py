import io, os, json
from PIL import Image

根 = r"."
路 = os.path.join(根, "数据", "界面", "打坐光环.json")
表 = json.load(io.open(路, encoding="utf-8"))
出 = []
for i, f in enumerate(表["帧"]):
    p = os.path.join(根, f["文件"].replace("res://", "").replace("/", os.sep))
    a = Image.open(p).convert("RGBA").getchannel("A")
    W, H = a.size
    底 = -1
    for y in range(H - 1, -1, -1):
        if any(a.getpixel((x, y)) > 30 for x in range(W)):
            底 = y; break
    f["环底距"] = 底 - f["原点y"]          # 图里最后一个不透明像素在注册点下方多少
    f["画布下沿距"] = H - f["原点y"]
    出.append("帧%d 环底距=%d 画布下沿距=%d 差=%d" % (i, f["环底距"], f["画布下沿距"],
											   f["画布下沿距"] - f["环底距"]))
表["环底距出处"] = ("逐张量 `素材/特效/打坐光环/打坐光环_N.png` 的 alpha：最后一个不透明像素(alpha>30)"
                 "所在行到 GameData 注册点的距离。画布下沿比它低 17~20 像素（那几条全透）⇒ 顺带证明"
                 "ffdec 出的画布**没有裁过边**、GameData 的 origin 就是这张画布的坐标。"
                 "用途：把九帧的环近边钉在同一行（原版实机录像逐帧量到环近边恒在第 180 行、"
                 "只有上沿从 75 涨到 2 再回落），见 脚本/角色/打坐光环.gd。")
io.open(路, "w", encoding="utf-8").write(json.dumps(表, ensure_ascii=False, indent=1))
io.open("环底距.txt", "w", encoding="utf-8").write("\n".join(出) + "\n")
print("ok")
