import io, os, json
from PIL import Image

根 = r"."
路 = os.path.join(根, "数据", "界面", "打坐光环.json")
d = json.load(io.open(路, encoding="utf-8"))
出 = ["帧  高 原点y 环底距 | 最宽行(绝对行) 最宽行离锚点 该行宽 | 环底离锚点"]
for i, f in enumerate(d["帧"]):
    p = os.path.join(根, "素材", "特效", "打坐光环", "打坐光环_%d.png" % i)
    a = Image.open(p).convert("RGBA").getchannel("A")
    W, H = a.size
    oy = f["原点y"]
    最 = (0, -1)
    for y in range(max(0, oy - 45), min(H, oy + 46)):
        xs = [x for x in range(W) if a.getpixel((x, y)) > 30]
        if xs and xs[-1] - xs[0] > 最[0]:
            最 = (xs[-1] - xs[0] + 1, y)
    底 = f.get("环底距", 0)
    f["环心行"] = 最[1] - oy			# 椭圆最宽行相对锚点（= 环的中心行）
    f["环宽"] = 最[0]
    出.append("%d %4d %4d %5d | %5d %+5d %5d | %+d" % (i, H, oy, 底, 最[1], 最[1] - oy, 最[0], 底))
心 = [f["环心行"] for f in d["帧"]]
宽 = [f["环宽"] for f in d["帧"]]
出.append("")
出.append("环心行离锚点 = %s（极差 %d）" % (心, max(心) - min(心)))
出.append("环宽        = %s（%.2f 倍）" % (宽, max(宽) / min(宽)))
d["环心行出处"] = ("逐张量 `素材/特效/打坐光环/*.png` 的 alpha：在锚点上下 ±45 行里找**水平最宽的那一行**，"
                 "它就是这条椭圆环的**中心行**（长轴所在行）。用途：把九帧的环中心钉在同一行 ⇒ "
                 "爆气时环只能对称胀缩、中心不许挪。依据：原版录像实测爆气那 1.2 秒里"
                 "脚底圈所在的行始终不变（带内青像素 820→1287=1.57 倍、带以上 460→7552=16.4 倍），"
                 "而素材自身带内 3361→5134=1.53 倍 ⇒ 素材与帧序都对，差的只是'整条带在往下沉'。")
io.open(路, "w", encoding="utf-8").write(json.dumps(d, ensure_ascii=False, indent=1))
io.open("环心.txt", "w", encoding="utf-8").write("\n".join(出) + "\n")
print("ok")
