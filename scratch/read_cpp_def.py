import os

cpp_root = r'D:\game\source_vo-lam-truyen-ky\VS2022\Source-VS2022-20260926T022613Z-1-002\Source-VS2022'

def find_file(name):
    for root, dirs, files in os.walk(cpp_root):
        if name in files:
            return os.path.join(root, name)
    return None

npc_attrib_path = find_file('KNpcAttribModify.cpp')
with open(npc_attrib_path, 'r', encoding='gb18030', errors='ignore') as f:
    content = f.read()

for method in ['void KNpcAttribModify::AutoReplySkill', 'void KNpcAttribModify::Damage2AddManaP']:
    pos = content.find(method)
    if pos != -1:
        print(f"=== {method} ===")
        print(content[pos:pos+1500])
