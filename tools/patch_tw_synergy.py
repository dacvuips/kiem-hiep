import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
tres_file = ROOT / "systems" / "sect" / "data" / "thien_vuong_bang.tres"
content = tres_file.read_text(encoding="utf-8")

# Fix SubResource_95
sub95_old = """[sub_resource type="Resource" id="SubResource_95"]
script = ExtResource("3_statline")
label = "Tăng sát thương kỹ năng liên kết #1"
value_at_level_1 = 1.0
value_at_max_level = 80.0
suffix = "%" """

# Let's use regex replacement
content, n1 = re.subn(
    r'(\[sub_resource type="Resource" id="SubResource_95"\]\r?\nscript = ExtResource\("3_statline"\)\r?\nlabel = "Tăng sát thương kỹ năng liên kết #1"\r?\nvalue_at_level_1 = 1\.0\r?\nvalue_at_max_level = 80\.0\r?\nsuffix = "%")',
    r'\1\ntarget_skill_id = "thien_vuong_potian_zhan"',
    content
)

content, n2 = re.subn(
    r'(\[sub_resource type="Resource" id="SubResource_96"\]\r?\nscript = ExtResource\("3_statline"\)\r?\nlabel = "Tăng sát thương kỹ năng liên kết #2"\r?\nvalue_at_level_1 = 1\.0\r?\nvalue_at_max_level = 80\.0\r?\nsuffix = "%")',
    r'\1\ntarget_skill_id = "thien_vuong_potian_zhan"',
    content
)

content, n3 = re.subn(
    r'(\[sub_resource type="Resource" id="SubResource_116"\]\r?\nscript = ExtResource\("3_statline"\)\r?\nlabel = "Tăng sát thương kỹ năng liên kết #1"\r?\nvalue_at_level_1 = 1\.0\r?\nvalue_at_max_level = 60\.0\r?\nsuffix = "%")',
    r'\1\ntarget_skill_id = "thien_vuong_zhuifeng_jue"',
    content
)

content, n4 = re.subn(
    r'(\[sub_resource type="Resource" id="SubResource_117"\]\r?\nscript = ExtResource\("3_statline"\)\r?\nlabel = "Tăng sát thương kỹ năng liên kết #2"\r?\nvalue_at_level_1 = 1\.0\r?\nvalue_at_max_level = 60\.0\r?\nsuffix = "%")',
    r'\1\ntarget_skill_id = "thien_vuong_zhuifeng_jue"',
    content
)

print(f"Replacements: 95={n1}, 96={n2}, 116={n3}, 117={n4}")
if n1 == 1 and n2 == 1 and n3 == 1 and n4 == 1:
    tres_file.write_text(content, encoding="utf-8")
    print("SUCCESSFULLY UPDATED thien_vuong_bang.tres!")
else:
    print("FAILED TO MATCH ALL!")
