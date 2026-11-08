import io, os, json
from PIL import Image

根 = r"."
路 = os.path.join(根, "数据", "界面", "打坐光环.json")
d = json.load(io.open(路, encoding="utf-8"))
出 = ["帧  原点y 环底距 | 从底往上找到的'环最宽行' 该行宽 离锚点 | 再往上的'收窄谷底'行 离锚点"]
for i, f in enumerate(d["帧"]):
    p = os.path.join(根, "素材", "特效", "打坐光环", "打坐光环_%d.png" % i)
    a = Image.open(p).convert("RGBA").getchannel("A")
    W, H = a.size
    oy = f["原点y"]
    宽 = {}
    for y in range(H):
        xs = [x for x in range(W) if a.getpixel((x, y)) > 30]
        宽[y] = (xs[-1] - xs[0] + 1) if xs else 0
    底 = oy + f["环底距"]
    # ① 从底往上走到第一个"连续 3 行都比当前窄"的地方 = 环的长轴行（中心）
    中 = 底
    y = 底
    while y > 0:
        if 宽[y - 1] > 宽[中]:
            中 = y - 1
        if all(宽[max(0, y - k)] < 宽[中] for k in (1, 2, 3)) and 中 < 底 - 3:
            break
        y -= 1
    # ② 从长轴继续往上，找到宽度收缩到谷底的那一行 = 环的上沿
    谷 = 中
    for y2 in range(中, -1, -1):
        if 宽[y2] < 宽[中] * 0.55:
            谷 = y2
            break
    f["环中心行"] = 中 - oy
    f["环上沿行"] = 谷 - oy
    出.append("%d %4d %5d | %5d %5d %+5d | %5d %+5d" % (
        i, oy, f["环底距"], 中, 宽[中], 中 - oy, 谷, 谷 - oy))
中列 = [f["环中心行"] for f in d["帧"]]
出.append("")
出.append("环中心行离锚点 = %s（极差 %d）" % (中列, max(中列) - min(中列)))
出.append("⇒ 若极差小 = 原版本来就钉在中心，我们照它钉；若极差大 = 中心也在动，钉中心也救不了")
io.open("环中心2.txt", "w", encoding="utf-8").write("\n".join(出) + "\n")
print("ok")
