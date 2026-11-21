import re
import sys


def strip_lua(src: str) -> str:
    out = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        # 长括号 [[ ]] / [=[ ]=]
        m = re.match(r'\[(=*)\[', src[i:])
        if m and c == '[':
            eq = m.group(1)
            close = ']' + eq + ']'
            j = src.find(close, i + len(m.group(0)))
            if j == -1:
                i = n
            else:
                out.append(' ' * (j + len(close) - i))
                i = j + len(close)
            continue
        if c == '-' and i + 1 < n and src[i + 1] == '-':
            j = src.find('\n', i)
            if j == -1:
                i = n
            else:
                i = j
            continue
        if c in ('"', "'"):
            j = i + 1
            while j < n:
                if src[j] == '\\':
                    j += 2
                    continue
                if src[j] == c or src[j] == '\n':
                    break
                j += 1
            out.append(' ' * (j + 1 - i))
            i = j + 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)


KEYWORDS = {
    'function': 1,
    'if': 1,
    'for': 1,
    'while': 1,
    'repeat': 1,
    'do': 1,
    'end': -1,
    'until': -1,
}

TOKEN = re.compile(r'\b(function|if|for|while|repeat|do|end|until|then|else|elseif)\b')


def check(path: str):
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        raw = f.read()
    src = strip_lua(raw)
    depth = 0
    stack = []
    pending_loop = 0
    issues = []
    for m in TOKEN.finditer(src):
        line = src.count('\n', 0, m.start()) + 1
        w = m.group(1)
        if w in ('for', 'while'):
            pending_loop += 1
            depth += 1
            stack.append((w, line))
        elif w == 'do':
            # for/while 自带的 do 不额外开块
            if pending_loop > 0:
                pending_loop -= 1
            else:
                depth += 1
                stack.append((w, line))
        elif w in ('function', 'if', 'repeat'):
            depth += 1
            stack.append((w, line))
        elif w in ('end', 'until'):
            depth -= 1
            if stack:
                stack.pop()
            if depth < 0:
                issues.append(f'  多余的 {w} @ line {line}')
                depth = 0
    if depth != 0:
        tail = ', '.join(f'{w}@{l}' for w, l in stack[-5:])
        issues.append(f'  块不配平，剩余深度 {depth}；未闭合: {tail}')

    # 冒号后面必须紧跟 `名字(` —— 否则 `obj:Method ~= nil` 这种写法
    # 会被 Lua 解析器当成方法调用去要参数列表，报
    # "function arguments expected near '~='"。块配平和括号检查都抓不到这一类。
    for m in re.finditer(r':\s*([A-Za-z_]\w*)', src):
        rest = src[m.end():]
        k = 0
        while k < len(rest) and rest[k] in ' \t\r\n':
            k += 1
        nxt = rest[k] if k < len(rest) else ''
        # 合法的后续：方法调用 ( " ' {
        if nxt in ('(', '"', "'", '{'):
            continue
        line = src.count('\n', 0, m.start()) + 1
        issues.append(
            f"  冒号后不是方法调用: ':{m.group(1)}' 后面是 '{nxt}' @ line {line}")

    if issues:
        print(f'[FAIL] {path}')
        for s in issues:
            print(s)
        return False
    print(f'[ok]   {path}  块配平正常')
    return True


if __name__ == '__main__':
    ok = True
    for p in sys.argv[1:]:
        ok = check(p) and ok
    sys.exit(0 if ok else 1)
