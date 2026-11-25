import os

for root, dirs, files in os.walk(r'D:\game'):
    for f in files:
        if f.endswith('.lua') or f.endswith('.txt'):
            p = os.path.join(root, f)
            try:
                with open(p, 'rb') as fp:
                    content = fp.read()
                    if b'icon_jj_wu_150' in content or b'1238' in content:
                        print("Found in:", p)
            except:
                pass
