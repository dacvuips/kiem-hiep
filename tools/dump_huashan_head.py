import sys
sys.stdout.reconfigure(encoding="utf-8")
lua_path = r"E:\jx15_src\script\skill\huashan.lua"
content = open(lua_path, "r", encoding="gbk", errors="ignore").read()
print(content[:2500])
