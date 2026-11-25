import os

def search_files(dir_path, keywords):
    found = []
    for root, dirs, files in os.walk(dir_path):
        for f in files:
            for kw in keywords:
                if kw.lower() in f.lower():
                    found.append(os.path.join(root, f))
    return found

res = search_files(r'D:\game', ['icon_jj_wu_150', 'icon_sk_cy_120', '1228', '1238'])
for r in res[:20]:
    print(r)
