import io, sys

## 逐行扫 GDScript：报告「引号没闭合」的行（注释里的引号不参与）。
## 这类错 Godot 只报第一条，而且报的是**下一行**，一整篇手写文案的门最容易被它拖很久。
def scan(p):
    ls = io.open(p, encoding='utf-8-sig').read().split('\n')
    out = []
    ins = False
    started = 0
    for i, raw in enumerate(ls):
        if not ins and raw.lstrip().startswith('#'):
            continue
        esc = False
        j = 0
        code = ''
        while j < len(raw):
            c = raw[j]
            if ins:
                if esc:
                    esc = False
                elif c == '\\':
                    esc = True
                elif c == '"':
                    ins = False
            else:
                if c == '"':
                    # 三引号：跳过一整段
                    if raw.startswith('"""', j):
                        k = j + 3
                        while k < len(raw) and not raw.startswith('"""', k):
                            k += 1
                        if k < len(raw):
                            j = k + 2
                        else:
                            break
                    else:
                        ins = True
                        started = i + 1
                elif c == '#':
                    break
                elif c in ' \t':
                    pass
                else:
                    code += c
            j += 1
        if ins:
            # 跨行普通字符串 = 一定写坏了（GDScript 没有多行裸串）
            out.append((started, i + 1, raw.strip()[:100]))
    return out

for p in sys.argv[1:]:
    bad = scan(p)
    for a, b, t in bad:
        print('%s:%s 引号未闭合（起于第 %d 行）| %s' % (p.split('/')[-1], b, a, t))
    if not bad:
        print('%s:引号全闭合' % p)
