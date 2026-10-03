# VLTK — Tài liệu tham khảo ĐẦY ĐỦ: Hệ thống Skill mọi Môn Phái

> Trích xuất từ mã nguồn C++ thật (`Sources/Core/Src/`) + dữ liệu server (`settings/Skills.txt`,
> `script/skill/*.lua`) của bộ "Server + client full-001" — dữ liệu hợp pháp người dùng sở hữu.
>
> **Nguyên tắc:** mọi số liệu/công thức dẫn nguồn file + số dòng cụ thể. Không suy đoán khi thiếu
> căn cứ — ghi rõ "không tìm thấy" thay vì bịa.

## Ánh xạ file .lua ↔ Môn phái (xác nhận từ settings/Skills.txt cột LvlSetScript)

| File .lua | Môn phái |
|---|---|
| `shaolin.lua` | Thiếu Lâm |
| `wudang.lua` | Võ Đang |
| `emei.lua` | Nga Mi |
| `gaibang.lua` | Cái Bang |
| `kunlun.lua` | Côn Lôn |
| `tangmen.lua` | Đường Môn |
| `wudu.lua` | Ngũ Độc |
| `tianwang.lua` | Thiên Vương (Thiên Vương Phủ?) |
| `tianren.lua` | Thiên Nhẫn |
| `cuiyan.lua` | Thúy Yên |
| `huashan.lua` | Hoa Sơn (nếu có, cần xác nhận thêm) |

File dùng CHUNG (không riêng môn phái nào): `head.lua` (hàm nội suy Line/Conic/Extrac/Link),
`skill.lua`, `sjbattle_state.lua` (buff trạng thái chiến đấu tạm thời), `advancedskill.lua`,
`param2string.lua`, `wuxinggongji.lua` (Ngũ Hành Công Kích — có thể là skill chung/đặc biệt),
`gmskills.lua` (GM/admin), `double_restore.lua`, `jingangbuhuaishendan.lua`, `xueyingshenxingdan.lua`,
`towerdefence.lua`, `phodo_chungsinh.lua`, `dtn.lua`, `vongsang1.lua`, `nhiephon_loantam.lua`,
`doancan_hucot.lua`, `tuytien_tacot.lua`, `wuzhuanjineng.lua`, `newsj.lua`, `loan_hoankich.lua` —
đây phần lớn là skill ĐẶC BIỆT/sự kiện/chuyển sinh dùng chéo nhiều môn phái, không phải "1 file = 1
phái" như 10 file ở bảng trên.

---

## PHẦN A — Cơ chế CHUNG cho mọi môn phái (đọc trước khi vào từng phái)

### A.1. Cách cộng điểm/lên cấp skill — `KSkillList` (KSkillList.cpp)

> Nguồn: `KSkillList.cpp` (đường dẫn gốc `Sources/Core/Src/KSkillList.cpp`). Mọi trích dẫn kèm số dòng đọc trực tiếp từ file.

**`KSkillList::Add(int nSkillID, int nSkillLevel, int nSkillExp, BOOL bTempSkill, int nMaxTimes, int RemainTimes)`** — dòng 385-… (khối khởi tạo chính dòng 416-439):
```cpp
i = FindFree();
if (i)
{
	m_Skills[i].SkillId = nSkillID;
	m_Skills[i].SkillLevel = nSkillLevel;
	m_Skills[i].AddLevel = m_nAllSkillV;
	m_Skills[i].CurrentSkillLevel = m_Skills[i].SkillLevel + m_Skills[i].AddLevel;
	m_Skills[i].SkillExp = nSkillExp;
	m_Skills[i].NextSkillExp = PlayerSet.m_cMagicLevelExp.GetNextExp(nSkillID, nSkillLevel);
	m_Skills[i].TempSkill = bTempSkill;
	m_Skills[i].MaxTimes = 0;
	m_Skills[i].RemainTimes = 0;
	m_Skills[i].NextCastTime = 0;
	m_Skills[i].WaitCastTime = 0;
	...
```
Nếu skill đã tồn tại trong list (`FindSame(nSkillID)` trả về khác 0, dòng 390-414) và `nSkillLevel` mới lớn hơn level hiện có, `Add()` chỉ gọi `IncreaseLevel(i, nInc)` với `nInc = nSkillLevel - m_Skills[i].SkillLevel` — tức là **học lần đầu và "học lại/nâng level qua GM-command" dùng chung 1 hàm**, `Add` chỉ là lớp bọc ngoài xử lý case "chưa có" (tạo slot mới) vs "đã có" (delta lên `IncreaseLevel`).

Nếu skill mới có style `SKILL_SS_PassivityNpcState` (võ công bị động/passive aura, dòng 431-439), nó được `Cast()` ngay lập tức để áp buff — nghĩa là **skill bị động không cần "cast thủ công", chỉ cần học/lên cấp là hiệu lực áp dụng liền**.

**`KSkillList::IncreaseLevel(int nIdx, int nLvl)`** — dòng 317-341, TOÀN VĂN phần logic:
```cpp
BOOL KSkillList::IncreaseLevel(int nIdx, int nLvl)
{
	if (nIdx <= 0 || nIdx >= MAX_NPCSKILL)
		return FALSE;
	if (nLvl <= 0)
		return FALSE;
	if (m_Skills[nIdx].TempSkill)
		return FALSE;

	m_Skills[nIdx].SkillLevel += nLvl;
	m_Skills[nIdx].CurrentSkillLevel += nLvl;
	m_Skills[nIdx].SkillExp = 0;
	m_Skills[nIdx].NextSkillExp = PlayerSet.m_cMagicLevelExp.GetNextExp(m_Skills[nIdx].SkillId, m_Skills[nIdx].SkillLevel);
	m_Skills[nIdx].TempSkill = FALSE;

	KSkill * pOrdinSkill = (KSkill *)g_SkillManager.GetSkill(m_Skills[nIdx].SkillId, m_Skills[nIdx].CurrentSkillLevel);
	if (!pOrdinSkill) 
        return FALSE;

	if (pOrdinSkill->GetSkillStyle() == SKILL_SS_PassivityNpcState)
	{
		pOrdinSkill->Cast(m_nNpcIndex, -1, m_nNpcIndex);
	}
	return TRUE;
}
```
**Xác nhận: mỗi lần lên cấp, `SkillExp` (skill exp) LUÔN reset về 0** và `NextSkillExp` được đọc lại từ `PlayerSet.m_cMagicLevelExp.GetNextExp(SkillId, SkillLevel)` — đây là **skill exp RIÊNG BIỆT hoàn toàn với EXP nhân vật** (character EXP dùng `level_exp.txt`, skill EXP dùng file khác — xem dưới). Skill tạm thời (`TempSkill == TRUE`, ví dụ buff GM/event) KHÔNG thể `IncreaseLevel` qua đường này (return FALSE ngay).

**`KSkillList::IncreaseExp(int nIdx, int nExp)`** — dòng 343-361, TOÀN VĂN:
```cpp
BOOL KSkillList::IncreaseExp(int nIdx, int nExp)
{
	if (nIdx <= 0 || nIdx >= MAX_NPCSKILL)
		return FALSE;
	if (m_Skills[nIdx].SkillLevel <= 0)
		return FALSE;
	if (m_Skills[nIdx].TempSkill)
		return FALSE;
	if (m_Skills[nIdx].NextSkillExp <= 0)
		return FALSE;

	m_Skills[nIdx].SkillExp += nExp;

	if (m_Skills[nIdx].SkillExp >= m_Skills[nIdx].NextSkillExp)
	{
		return IncreaseLevel(nIdx, 1);
	}
	return FALSE;
}
```
**Cơ chế: cộng dồn skill exp mỗi lần dùng skill (nExp truyền vào từ nơi khác, ngoài phạm vi 2 file này), khi đạt/vượt `NextSkillExp` thì tự động gọi `IncreaseLevel(nIdx, 1)` — LÊN ĐÚNG 1 CẤP mỗi lần đủ exp (không cộng dồn nhiều cấp cùng lúc dù dư thừa exp nhiều)`.** Phần exp dư ra (`SkillExp - NextSkillExp`) KHÔNG được carry-over — sau `IncreaseLevel`, `SkillExp` bị reset cứng về 0 (xem trên), nghĩa là **exp dư bị mất, không cộng dồn sang cấp kế tiếp**.

**Công thức EXP cần cho mỗi cấp — ĐỌC TỪ FILE, không phải hằng số code.** Hàm thực thi nằm ở `KPlayerSet.cpp:670-685`, TOÀN VĂN:
```cpp
int		KMagicLevelExp::GetNextExp(int nSkillId, int nLevel)
{
	if (nSkillId <= 0 && nSkillId > MAX_SKILL)
		return 0;
	if (nLevel <= 0 && nLevel > MAX_TRAIN_SKILLEXPLEVEL)
		return 0;	
		
	int nExp = 0;
	char nRow[16];
	char nCol[8];
	itoa(nSkillId, nRow, 10);
	sprintf(nCol, "LEVEL%d", nLevel);
	m_MagicLevelExpFile.GetInteger(nRow, nCol, 0, &nExp);
	
	return nExp;
}
```
Và `Init()` (dòng 662-668): `m_MagicLevelExpFile.Load(PLAYER_MAGIC_LEVEL_EXP_FILE)` — tức load đúng file `settings\npc\player\magic_level_exp.txt` đã biết từ phiên trước (mục 8 của `vltk_player_stats_reference.md`). **Xác nhận: dòng = `SkillId` (dùng trực tiếp làm row-key qua `itoa`), cột = `LEVELn` (n = level SAU khi tăng, tức exp cần để đạt `SkillLevel` hiện tại lên tiếp) — bảng lookup thô, không có công thức toán học nào trong code, toàn bộ số liệu nằm trong file text.** Không có hằng số/hệ số nhân nào áp dụng thêm trong `GetNextExp` — trả thẳng giá trị đọc từ file.

**`KSkillList::GetAddSkillDamage(int nSkillID)`** — dòng 895-923, TOÀN VĂN:
```cpp
int KSkillList::GetAddSkillDamage(int nSkillID) 
{ 
    int nAddP = 0; 

    if (nSkillID <= 0 || nSkillID >= MAX_SKILL) 
        return nAddP; 
     
    for (int i = 1; i < MAX_NPCSKILL; i++) 
    { 
		if (m_Skills[i].SkillLevel)
		{
			KSkill * pSkill = (KSkill *) g_SkillManager.GetSkill(m_Skills[i].SkillId, m_Skills[i].CurrentSkillLevel); 
			if (pSkill)  
			{ 
				KMagicAttrib* pMagicData = NULL; 
				pMagicData = pSkill->GetAddSkillDamage();     
				for (int j =0 ; j < MAX_ADDSKILLDAMAGE ; j ++) 
				{ 
					if (!pMagicData[j].nAttribType) continue; 
					if ( pMagicData[j].nValue[0] == nSkillID) 
					{ 
						nAddP += pMagicData[j].nValue[2]; 
					} 
				} 
			}
		}
    } 
    return nAddP; 
}  
```
**Cơ chế: duyệt QUA TẤT CẢ skill khác đang có trong list (không chỉ chính skill đang cast), tìm những skill có field `magic_addskilldamage1..9` (dòng enum 277-285, KMagicAttrib.h) mà `nValue[0]` (skill ID mục tiêu ghi trong field đó) TRÙNG với `nSkillID` đang hỏi, rồi cộng dồn `nValue[2]` (% enhance) từ TẤT CẢ những skill "phụ trợ" đó.** Đây chính là cơ chế **"skill A buff riêng cho skill B cụ thể"** (không phải buff chung all-skill) — dùng trong `AppendSkillEffect` làm `nAddDamageP` (đã dùng ở tài liệu trước, mục 12 của `vltk_player_stats_reference.md`). Field `nValue[0]` = SkillID mục tiêu được buff, `nValue[2]` = % damage cộng thêm cho skill đó.

**`KSkillList::SetAddLevel(int nId, int nAdd)`** (dòng 824-832) và **`SetCurLevel(int nId, int nLevel)`** (dòng 834-842) — TOÀN VĂN:
```cpp
void KSkillList::SetAddLevel(int nId, int nAdd)
{
	int i = FindSame(nId);
	if (i > 0 && i < MAX_NPCSKILL)
	{
		m_Skills[i].AddLevel = nAdd;
	}
}

void KSkillList::SetCurLevel(int nId, int nLevel)
{
	int i = FindSame(nId);
	if (i > 0 && i < MAX_NPCSKILL)
	{
		m_Skills[i].CurrentSkillLevel = nLevel;
	}
}
```
**Phân biệt rõ 3 field:**
- `SkillLevel` = cấp THẬT đã học (persist trong DB, tăng qua `IncreaseLevel`/`IncreaseExp`).
- `AddLevel` = cấp CỘNG THÊM tạm thời (buff toàn cục qua `AllSkillV`/`SeriesSkillV` — dòng 201-315, ví dụ buff "tất cả skill +N level" hoặc "skill hệ X +N level" theo sự kiện/GM, hoặc field `m_nAllSkillV` toàn cục).
- `CurrentSkillLevel` = **`SkillLevel + AddLevel`** — cấp HIỆU DỤNG thật sự dùng để tra `GetSkill(SkillId, CurrentSkillLevel)` khi tính toán combat/hiển thị. Đây chính là cấp mà toàn bộ hệ thống magic attrib (mục A.2) tra cứu.

`SetAddLevel`/`SetCurLevel` là 2 hàm ghi TRỰC TIẾP (override) — không cộng dồn như logic trong `AllSkillV`/`IncreaseLevel`, dùng cho các trường hợp set thẳng từ ngoài (ví dụ đồng bộ dữ liệu, cheat/GM debug, hoặc client hiển thị preview).

**`KSkillList::CanCast(int nSkillID, DWORD dwTime)`** — dòng 531-550, TOÀN VĂN:
```cpp
BOOL KSkillList::CanCast(int nSkillID, DWORD dwTime)
{
	if (!nSkillID)
		return FALSE;
	
	int i = FindSame(nSkillID);
	if (!i)
	{
		return FALSE;
	}

	if (m_Skills[i].NextCastTime > dwTime)
		return FALSE;


	if (m_Skills[i].SkillLevel <= 0)
		return FALSE;
	
	return TRUE;
}
```
**Xác nhận: cooldown đơn giản là so sánh mốc thời gian tuyệt đối `NextCastTime` (đã set từ lần cast trước qua `SetNextCastTime`, dòng 552-566: `NextCastTime = dwCurrentTime + dwCastTime`) với `dwTime` hiện tại truyền vào — KHÔNG có công thức phức tạp, chỉ là hiệu số thời gian dạng "so sánh mốc", không phải "đếm ngược" hay tính lại mỗi tick.** Điều kiện thứ 2 (`SkillLevel <= 0` → không cast được) xác nhận: **skill CHƯA HỌC (SkillLevel = 0, dù có thể đã có AddLevel/CurrentSkillLevel > 0 do buff tạm) KHÔNG được phép cast** — buff level tạm thời (AddLevel) không thể "mở khóa" 1 skill chưa học, chỉ tăng sức mạnh của skill ĐÃ học.

**`KSkillList::IsBaseSkill(int nSkillId)`** — dòng 185-199, TOÀN VĂN:
```cpp
BOOL KSkillList::IsBaseSkill(int nSkillId)
{
	if (nSkillId < 0)
		return FALSE;

	if (nSkillId > 0)
	{
		KSkill * pOrdinSkill = (KSkill *)g_SkillManager.GetSkill(nSkillId, 1);
		if (!pOrdinSkill) 
			return FALSE;
		
		return pOrdinSkill->IsBase();
	}
	return FALSE;
}
```
`IsBase()` định nghĩa tại `KSkills.h:199`: `BOOL IsBase(){return m_nAttrib <= 1;};` — tức phụ thuộc cột `Attrib` đọc từ `Skills.txt` (không phải cột `BaseSkill` như tên gợi ý!). **"Skill cơ bản" = skill có `Attrib <= 1` trong Skills.txt** (ý nghĩa cụ thể của giá trị 0/1 cho `Attrib` không xác định được từ 2 file đã đọc — cần xem thêm enum/tài liệu cột `Attrib` nếu muốn biết chính xác 0 vs 1 khác nhau thế nào). Lưu ý: cột `BaseSkill` (`m_bBaseSkill`, `GetInfoFromTabFile` dòng 2121) là 1 field RIÊNG BIỆT dùng ở chỗ khác (`AllSkillV`, dòng 285: `if (!IsBaseSkill(...))`) — 2 khái niệm cùng tên nhưng đọc từ 2 cột khác nhau của Skills.txt, cần cẩn thận khi tra cứu.

Skill cơ bản (`IsBase() == TRUE`) được loại trừ khỏi các cơ chế buff toàn cục theo level như `AllSkillV`/`SeriesSkillV` (không bị cộng `AddLevel` khi buff "tất cả skill +N cấp") và khỏi `RollBackSkills` (dòng 870-892, hoàn điểm skill — skill cơ bản không hoàn điểm vì không tốn điểm học từ đầu) — gợi ý mạnh: **"skill cơ bản" = skill tự động có sẵn theo môn phái/level nhân vật, không tốn skill-point để học, không nằm trong ngân sách "điểm kỹ năng" mà người chơi phân bổ.**

### A.2. Cách parse dữ liệu skill từ Skills.txt/lua thành runtime — `KSkill::LoadSkillLevelData`,
`KSkill::ParseString2MagicAttrib`, `KSkill::GetInfoFromTabFile` (KSkills.cpp)

> Nguồn: `KSkills.cpp` (đường dẫn gốc `Sources/Core/Src/KSkills.cpp`, file ~3300+ dòng).

**`KSkill::GetInfoFromTabFile(KITabFile *pSkillsSettingFile, int nRow)`** — dòng 2091-2203. Đọc TRỰC TIẾP từng cột của 1 dòng trong `Skills.txt` (qua `g_OrdinSkillsSetting`, 1 `KITabFile`) vào field thành viên tương ứng của `KSkill`, ví dụ (trích 1 đoạn, dòng 2095-2138):
```cpp
pSkillsSettingFile->GetString(nRow, "SkillName",		"", m_szName, sizeof(m_szName) ,TRUE);
pSkillsSettingFile->GetInteger(nRow, "SkillId",			0, (int *)&m_nId,TRUE);
pSkillsSettingFile->GetInteger(nRow, "Attrib",			0, (int *)&m_nAttrib,TRUE);
...
pSkillsSettingFile->GetInteger(nRow, "ReqLevel",		0, (int *)&nReqLevel, TRUE);
...
pSkillsSettingFile->GetInteger(nRow, "BaseSkill",		0, &m_bBaseSkill, TRUE);
...
pSkillsSettingFile->GetInteger(nRow, "SkillCostType",	0, (int *)&m_nSkillCostType, TRUE);
pSkillsSettingFile->GetInteger(nRow, "CostValue",		0, &m_nCost, TRUE);
pSkillsSettingFile->GetInteger(nRow, "TimePerCast",		0, &m_nMinTimePerCast, TRUE);
pSkillsSettingFile->GetInteger(nRow, "Param1",			0, &m_nValue1, TRUE);
pSkillsSettingFile->GetInteger(nRow, "Param2",			0, &m_nValue2, TRUE);
```
Đây là **mọi field TĨNH của 1 skill** (không đổi theo cấp): tên, ID, loại tấn công (melee/missile/aura/thief...), yêu cầu trang bị (`EqtLimit`), yêu cầu ngựa (`HorseLimit`), có phải base skill không, các skill con/skill sự kiện liên quan (child/start/fly/collide/vanish skill), bán kính tấn công mặc định, v.v.

**QUAN TRỌNG — dòng 2183-2200 (chỉ biên dịch khi `#else` tức KHÔNG PHẢI client, tức build `_SERVER`):**
```cpp
char szLevelScript[MAX_PATH];

//读取设定脚本1，记录每一个技能的属性变化数值设定表
pSkillsSettingFile->GetString(nRow, "LvlSetScript", "", szLevelScript, MAX_PATH);
if (szLevelScript[0])
{
	strlwr(szLevelScript);
	m_dwSkillLevelDataScriptId = g_FileName2Id(szLevelScript);
}

//读取设定脚本2，记录附加技能信息
pSkillsSettingFile->GetString(nRow, "LevelUpScript","",szLevelScript, MAX_PATH);
if (szLevelScript[0])
{
	strlwr(szLevelScript);
	m_dwSkillLevelUpScriptID = g_FileName2Id(szLevelScript);
}
```
(Comment gốc tiếng Trung dịch: "đọc script thiết lập 1, ghi bảng thiết lập giá trị biến đổi thuộc tính của mỗi kỹ năng" / "đọc script thiết lập 2, ghi thông tin kỹ năng phụ thêm"). Đây là bước server LOAD SẴN (cache) ID của file `.lua` tương ứng cột `LvlSetScript` trong Skills.txt (ví dụ `tangmen.lua`) — KHÔNG load lại mỗi lần cần dữ liệu, chỉ resolve tên file → ID script 1 lần khi load `Skills.txt`.

**`KSkill::LoadSkillLevelData(unsigned long nLevel, int nParam)`** — dòng 2213-2306, đây là hàm CỐT LÕI của toàn bộ cơ chế parse dữ liệu skill theo cấp. TOÀN VĂN đoạn quan trọng nhất (dòng 2259-2305):
```cpp
int nSafeIndex = 1;
pScript->SafeCallBegin(&nSafeIndex);

for(int i = 0 ;  i  < MAXSKILLLEVELSETTINGNUM ; i ++)
{
	char szSettingName[40];
	char szSettingData[40];
	sprintf(szSettingName, "LvlSetting%d", i + 1);
	sprintf(szSettingData, "LvlData%d", i + 1);
	
	g_OrdinSkillsSetting.GetString(nRowId, szSettingName, "", szSettingNameValue, 100);
	g_OrdinSkillsSetting.GetString(nRowId, szSettingData, "", szSettingDataValue, 100);
	if (szSettingNameValue[0] == 0 	|| szSettingDataValue[0] == '0'	)
	{
		continue;
	}
	
	pScript->CallFunction("GetSkillLevelData", 1, "ssd", szSettingNameValue, szSettingDataValue, nLevel);
	const char * szType = lua_typename(pScript->m_LuaState, Lua_GetTopIndex(pScript->m_LuaState));
	if (Lua_IsNumber(pScript->m_LuaState, Lua_GetTopIndex(pScript->m_LuaState)) == 1)
	{
		int nResult = (int)Lua_ValueToNumber(pScript->m_LuaState, Lua_GetTopIndex(pScript->m_LuaState));
		sprintf(szResult, "%d", nResult);
	}
	else if (Lua_IsString(pScript->m_LuaState, Lua_GetTopIndex(pScript->m_LuaState)) == 1)
	{
		if(strcmp(szSettingNameValue, "skill_desc") == 0)
		{
			continue;
		}
		else
		strcpy(szResult , (char *)Lua_ValueToString(pScript->m_LuaState, Lua_GetTopIndex(pScript->m_LuaState)));
	}
	...
	ParseString2MagicAttrib(nLevel, szSettingNameValue, szResult);
	
}
pScript->SafeCallEnd(nSafeIndex);
```
**PHÁT HIỆN QUAN TRỌNG NHẤT (khác với giả thuyết "Lua chỉ đọc data, C++ mới tính"): `LoadSkillLevelData` KHÔNG tự tính công thức nội suy theo cấp bằng C++. Nó GỌI THẲNG hàm Lua `GetSkillLevelData(levelname, data, level)` (định nghĩa trong `head.lua`, xem A.3) qua `pScript->CallFunction(...)`, lấy kết quả trả về (dạng chuỗi `"p1,p2,p3"` hoặc số/chuỗi khác), rồi đưa chuỗi đó vào `ParseString2MagicAttrib` để lưu vào struct C++ runtime.** Tức là: **CHÍNH LUA THỰC HIỆN PHÉP TOÁN NỘI SUY (Line/Conic/Extrac/Link)**, C++ chỉ đóng vai trò orchestration (vòng lặp qua các cột `LvlSetting1..N`/`LvlData1..N` trong Skills.txt, gọi Lua, parse chuỗi kết quả). Đây LÀ 1 hệ thống DUY NHẤT tích hợp chặt, không phải "2 hệ thống độc lập" — Lua và C++ hoạt động cùng nhau trong 1 lần gọi `LoadSkillLevelData`.

Cột `LvlSettingN`/`LvlDataN` (N=1..`MAXSKILLLEVELSETTINGNUM`) trong Skills.txt: `LvlSettingN` = TÊN biến magic attrib (ví dụ `"physicsenhance_p"`), `LvlDataN` = TÊN bảng dữ liệu trong file lua môn phái tương ứng (ví dụ `"wgz"` trỏ tới `SKILLS["wgz"]` trong `tangmen.lua`) — đây chính là cầu nối giữa Skills.txt (định nghĩa tên biến nào áp dụng cho skill nào) và file `.lua` môn phái (định nghĩa bảng giá trị theo mốc cấp cho từng biến đó).

**`KSkill::ParseString2MagicAttrib(unsigned long ulLevel, char * szMagicAttribName, char * szValue)`** — dòng 2514-2804. Đây là hàm ĐỌC TÊN BIẾN + giá trị text, chuyển thành `enum magic_xxx` + lưu vào đúng mảng runtime tương ứng. Cơ chế nhận diện tên (dòng 2523-2527):
```cpp
for (int i  = 0 ; i <= magic_normal_end; i ++)
{

	if (!strcmp(szMagicAttribName, MagicAttrib2String(i)))
	{
		pcszTemp = szValue;
		nValue1 = KSG_StringGetInt(&pcszTemp, 0);
		KSG_StringSkipSymbol(&pcszTemp, ',');
		nValue2 = KSG_StringGetInt(&pcszTemp, 0);
		KSG_StringSkipSymbol(&pcszTemp, ',');
		nValue3 = KSG_StringGetInt(&pcszTemp, 0);
```
**Quan trọng: hàm này KHÔNG hardcode danh sách string trong chính nó — nó LOOP qua toàn bộ enum `MAGIC_ATTRIB` (0 → `magic_normal_end` = 303) và so sánh với mảng `MAGIC_ATTRIB_STRING[]` (định nghĩa tại `KMagicDesc.cpp:11-317`, xem đầy đủ ở mục A.4) thông qua hàm `MagicAttrib2String(i)` → `g_MagicID2String(i)` → trả `MAGIC_ATTRIB_STRING[i]`.** Giá trị text (`szValue`, dạng `"v1,v2,v3"` do Lua trả về từ `Param2String`) được parse thành 3 số nguyên `nValue1/2/3` bằng `KSG_StringGetInt` (đọc số, bỏ qua dấu phẩy).

Sau khi nhận diện được `i` (attrib type), hàm phân loại và lưu vào 1 trong nhiều mảng khác nhau tùy thuộc range của `i`:
- `i` trong range `magic_missle_begin < i < magic_missle_end` HOẶC `magic_missle_exp_begin < i < magic_missle_exp_end` (dòng 2534-2543) → lưu vào `m_MissleAttribs[]` (thuộc tính đạn/projectile — tốc độ, tầm bắn, số lần trúng...).
- `i` trong range `magic_addskilldamage1 <= i <= magic_addskilldamage9` (dòng 2544-2552) → lưu vào `m_AddSkillDamage[]` (cơ chế "skill A buff riêng cho skill B", dùng bởi `GetAddSkillDamage` ở mục A.1).
- `i` trong range `magic_skill_begin < i < magic_skill_end` (dòng 2553-2620) → xử lý bằng `switch` riêng, SET TRỰC TIẾP vào field khác của `KSkill` (VD `magic_skill_cost_v` → `m_nCost = nValue1`, `magic_skill_mintimepercast_v` → `m_nMinTimePerCast = nValue1`) — đây là **field tĩnh có thể ĐỔI THEO CẤP** (VD giá skill/cooldown giảm dần theo cấp), không lưu vào mảng magic-attrib chung.
- `i` trong range `magic_damage_begin < i < magic_damage_end` (dòng 2622-2742) → lưu vào mảng `m_DamageAttribs[]` theo SLOT CỐ ĐỊNH (không phải theo thứ tự đọc): slot 0 = `attackrating_v/p`, slot 1 = `ignoredefense_p`, slot 2 = `magicdamage_v`, slot 3 = `seriesdamage_p`, slot 4 = `deadlystrike_p`, slot 5 = `fatallystrike_p`, slot 6 = `steallife_p`, slot 7 = `stealmana_p`, slot 8 = `stealstamina_p`, slot 9 = `physicsdamage_v/physicsenhance_p` (2 attrib DÙNG CHUNG 1 SLOT!), slot 10 = `colddamage_v`, slot 11 = `firedamage_v`, slot 12 = `lightingdamage_v`, slot 13 = `poisondamage_v`, slot 14 = `stun_p`, slot 15 = `randmove`. **Đây chính là mảng dùng trong `KNpc::AppendSkillEffect` đã trích dẫn ở tài liệu trước (`vltk_player_stats_reference.md` mục 12).**
- Còn lại (default, dòng 2743-2799): nếu `i` là 1 trong các attrib đặc biệt có tác dụng phụ khác (`magic_physicsres_p` → set cờ `m_bSkillReduceResist = TRUE`, `magic_lifereplenish_v` → cờ `m_bSkillLifeReplenish = TRUE`, `magic_skill_collideevent/vanishedevent/startevent/flyevent` → set field event tương ứng), rồi **PHÂN LOẠI CUỐI CÙNG dựa trên `nValue2`** (dòng 2782-2799):
  ```cpp
  if (nValue2 == 0 || i == magic_skill_flyevent) 
  {
  	m_ImmediateAttribs[m_nImmediateAttribsNum].nAttribType = i;
  	...
  	return TRUE;
  }
  else
  {
  	m_StateAttribs[m_nStateAttribsNum].nAttribType = i;
  	...
  	return TRUE;
  }
  ```
  **Comment gốc dòng 2521-2522 giải thích rõ: `nValue2` (tham số thứ 2 trong chuỗi `"v1,v2,v3"`) mang Ý NGHĨA ĐẶC BIỆT — bằng -1 nghĩa là hiệu ứng VĨNH VIỄN (permanent state), bằng 0 nghĩa là hiệu ứng TỨC THỜI (instant), giá trị dương khác là THỜI GIAN hiệu lực tạm thời (temporary state với duration = nValue2).** Do đó `nValue2 == 0` → lưu vào `m_ImmediateAttribs[]` (hiệu ứng tức thời, áp 1 lần khi trúng đòn), khác 0 (kể cả -1 hay số dương) → lưu vào `m_StateAttribs[]` (hiệu ứng trạng thái/buff-debuff có thời hạn hoặc vĩnh viễn, gắn vào đối tượng bị ảnh hưởng).

Cuối hàm, `MagicAttrib2String`/`g_MagicID2String` (dòng 2806-2809, và `KMagicDesc.cpp:548-552`):
```cpp
const char * g_MagicID2String(int nAttrib)
{
	if ((nAttrib < 0) || nAttrib >= magic_normal_end) return MAGIC_ATTRIB_STRING[magic_normal_end];
	return 	MAGIC_ATTRIB_STRING[nAttrib];
}
```

**`KSkill::CanCastSkill(int nLauncher, int &nParam1, int &nParam2)`** — dòng 133-… (hàm dài, kiểm tra điều kiện THI TRIỂN thực tế, khác với `KSkillList::CanCast` ở mục A.1). Các điều kiện kiểm tra theo thứ tự:
1. Xác định quan hệ mục tiêu hợp lệ (`m_bTargetSelf`/`m_bTargetOnly`/`m_bTargetEnemy`/`m_bTargetAlly` so với `NpcSet.GetRelation(nLauncher, nParam2)`, dòng 136-168) — nếu không khớp quan hệ mục tiêu yêu cầu, return 0.
2. Nếu launcher là Player: kiểm tra `m_SilentState.nTime > 0` (đang bị "câm"/silence, không thể dùng skill, dòng 178-190).
3. Kiểm tra yêu cầu vũ khí (`m_nEquiptLimited != -2`, dòng 191-231) — so khớp loại vũ khí đang trang bị (`nDetailType`/`nParticularType` từ `Player.m_ItemList`) với yêu cầu của skill.
4. Kiểm tra fight-mode giữa 2 player phải khớp (dòng 233-241, PK mode).
5. Kiểm tra ràng buộc cưỡi ngựa (`m_nHorseLimited`: 1 = không được dùng khi cưỡi ngựa, 2 = BẮT BUỘC phải cưỡi ngựa mới dùng được, dòng 245-284).
6. Kiểm tra khoảng cách tới mục tiêu so với `GetAttackRadius()` (dòng 285-…).

**Quan hệ giữa `KSkillList::CanCast` và `KSkill::CanCastSkill`:** đây là **2 lớp kiểm tra ĐỘC LẬP, BỔ SUNG cho nhau, cả 2 đều phải pass thì mới thực sự cast được**. `KSkillList::CanCast` (thuộc về DANH SÁCH skill của 1 NPC/Player cụ thể) chỉ kiểm tra 2 điều kiện đơn giản và RẺ (cheap check): (a) skill đã học chưa (`SkillLevel > 0`) và (b) đã hết cooldown chưa (so `NextCastTime` với `dwTime` hiện tại) — đây là bộ lọc nhanh, không cần biết chi tiết skill là gì. `KSkill::CanCastSkill` (thuộc về CHÍNH đối tượng skill, không phụ thuộc người dùng cụ thể ngoài `nLauncher`) kiểm tra các điều kiện NGỮ CẢNH phức tạp hơn nhiều: quan hệ địch/ta với mục tiêu, trạng thái câm lặng, yêu cầu vũ khí, ràng buộc ngựa, khoảng cách. **Thứ tự gọi thực tế (không thấy trực tiếp trong 2 file này, suy luận hợp lý từ tên và vị trí tham số) nhiều khả năng là: gọi `CanCast` trước (rẻ, loại nhanh trường hợp chưa học/còn cooldown) rồi mới gọi `CanCastSkill` (đắt hơn, cần tính khoảng cách/quan hệ) — không có bằng chứng trực tiếp thứ tự gọi trong 2 file đã đọc, đây là suy luận kiến trúc hợp lý, không phải trích dẫn.**

### A.3. Cơ chế nội suy giá trị theo cấp — `Line/Conic/Extrac/Link` (head.lua đối chiếu C++ nếu có)

> Nguồn Lua: `script\skill\head.lua` (đọc từ `D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\Patch full data\script\skill\head.lua` — lưu ý: đường dẫn user cung cấp ban đầu, `...\server\script\skill\head.lua`, KHÔNG TỒN TẠI trong cây thư mục hiện có; file thực tế nằm dưới `server\Patch full data\script\skill\head.lua`, nội dung xác nhận đúng là file cần tìm dựa trên tên hàm khớp 100% với mô tả yêu cầu).

**`Line(x,x1,y1,x2,y2)`** — nội suy TUYẾN TÍNH (bậc 1), TOÀN VĂN:
```lua
function Line(x,x1,y1,x2,y2)
	if(x2==x1) then
		return y2
	end
	return (y2-y1)*(x-x1)/(x2-x1)+y1
end
```
Công thức toán học chuẩn `y = (y2-y1)/(x2-x1) × (x-x1) + y1` (đường thẳng qua 2 điểm `(x1,y1)` và `(x2,y2)`), có guard tránh chia 0 khi `x1==x2`.

**`Conic(x,x1,y1,x2,y2)`** — nội suy BẬC 2 (parabol qua gốc dạng `f(x)=a·x²+c`), TOÀN VĂN:
```lua
function Conic(x,x1,y1,x2,y2)
	if((x1 < 0) or (x2<0))then 
		return 0
	end
	if(x2==x1) then
		return y2
	end
	return (y2-y1)*x*x/(x2*x2-x1*x1)-(y2-y1)*x1*x1/(x2*x2-x1*x1)+y1
end
```

**`Extrac(x,x1,y1,x2,y2)`** — theo comment gốc (dòng 40-47) mô tả là nội suy dạng CĂN BẬC 2 (`f(x)=a·sqrt(x2)+c`), NHƯNG code thực thi (dòng 48-56) **GIỐNG HỆT `Line()`** (công thức tuyến tính `(y2-y1)*(x-x1)/(x2-x1)+y1`), chỉ khác điều kiện guard đầu (`x1<0 or x2<0` → return 0, giống `Conic`). **Đây là điểm KHÔNG KHỚP giữa comment và code thật — comment mô tả công thức căn bậc 2 nhưng code hiện tại (bản build này) implement y hệt tuyến tính. Ghi nhận nguyên văn, không suy đoán thêm lý do (có thể là bug/chưa hoàn thiện của bản gốc, hoặc code đã bị đơn giản hóa nhưng quên sửa comment).**

**`Link(x, points)`** — nội suy qua NHIỀU MỐC ĐIỂM (không chỉ 2 điểm), TOÀN VĂN:
```lua
function Link(x,points)
	num = getn(points)
	if(num<2) then
		return -1
	end
	for i=1,num do
		if(points[i][3]==nil) then
			points[i][3]=Line
		end
	end
	if(x < points[1][1]) then
		return points[1][3](x,points[1][1],points[1][2],points[2][1],points[2][2])
	end
	if(x > points[num][1]) then
		return points[num][3](x,points[num-1][1],points[num-1][2],points[num][1],points[num][2])
	end
	
	c = 2
	for i=2,num do
		if((x >= points[i-1][1]) and (x <= points[i][1])) then
			c = i
			break
		end
	end
	return points[c][3](x,points[c-1][1],points[c-1][2],points[c][1],points[c][2])
end
```
Mỗi điểm trong `points` có dạng `{x_i, y_i, func}` (`func` mặc định = `Line` nếu không chỉ định — dòng 71-74). Với `x` (level hiện tại) nằm ngoài khoảng đầu/cuối, `Link` NGOẠI SUY (extrapolate) bằng đúng hàm nội suy của đoạn biên gần nhất (không cap cứng giá trị). Với `x` nằm giữa 2 mốc `points[i-1]` và `points[i]`, dùng hàm nội suy riêng của ĐOẠN ĐÓ (`points[c][3]`, cho phép mỗi đoạn dùng công thức khác nhau — tuyến tính hoặc bậc 2 — trong CÙNG 1 skill, ví dụ cấp 1-20 tuyến tính rồi cấp 20-40 bậc 2).

**`GetSkillLevelData(levelname, data, level)`** — TOÀN VĂN:
```lua
function GetSkillLevelData(levelname, data, level)
	if(data==nil) then
		return ""
	end
	if(data == "") then
		return ""
	end
	if(SKILLS[data]==nil) then
		return ""
	end
	if(SKILLS[data][levelname]==nil) then
		return ""
	end
	if(type(SKILLS[data][levelname]) == "function") then
		return SKILLS[data][levelname](level)
	end
	if(SKILLS[data][levelname][1]==nil) then
		SKILLS[data][levelname][1]={{0,0},{20,0}}
	end
	if(SKILLS[data][levelname][2]==nil) then
		SKILLS[data][levelname][2]={{0,0},{20,0}}
	end
	if(SKILLS[data][levelname][3]==nil) then
		SKILLS[data][levelname][3]={{0,0},{20,0}}
	end
	p1=floor(Link(level,SKILLS[data][levelname][1]))
	p2=floor(Link(level,SKILLS[data][levelname][2]))
	p3=floor(Link(level,SKILLS[data][levelname][3]))
	return Param2String(p1,p2,p3)
end;
```
Đây là hàm ENTRY POINT được gọi TRỰC TIẾP từ C++ (`KSkill::LoadSkillLevelData`, mục A.2, qua `pScript->CallFunction("GetSkillLevelData", 1, "ssd", szSettingNameValue, szSettingDataValue, nLevel)`). Cơ chế: `data` = tên bảng skill trong `SKILLS[...]` (ví dụ `"wgz"`), `levelname` = tên biến magic attrib (ví dụ `"physicsenhance_p"`), `level` = cấp skill hiện tại truyền từ C++. Với mỗi biến, `SKILLS[data][levelname]` có thể là 1 trong 2 dạng:
- **1 hàm Lua tùy chỉnh** (`type(...) == "function"`) — cho phép môn phái viết công thức RIÊNG, KHÔNG bắt buộc dùng `Link`/`Line`/`Conic` (linh hoạt tối đa, không phải mọi skill đều dùng nội suy điểm mốc).
- **1 bảng gồm tối đa 3 nhóm điểm mốc** (`[1]`, `[2]`, `[3]` — tương ứng `nValue1/nValue2/nValue3` sẽ được `ParseString2MagicAttrib` đọc lại ở phía C++) — mỗi nhóm nội suy ĐỘC LẬP qua `Link()`, kết quả làm tròn xuống (`floor`) rồi ghép thành chuỗi `"p1,p2,p3"` qua `Param2String` (dòng 92-94: `Param1..","..Param2..","..Param3`) để trả về cho C++.

**Kết luận đối chiếu C++ ↔ Lua (trả lời trực tiếp câu hỏi "2 hệ thống độc lập hay không"):** **ĐÂY LÀ 1 HỆ THỐNG DUY NHẤT, TÍCH HỢP CHẶT — KHÔNG phải 2 hệ thống độc lập.** C++ (`KSkill::LoadSkillLevelData`) gọi TRỰC TIẾP hàm Lua `GetSkillLevelData` mỗi khi cần biết giá trị 1 magic-attrib tại 1 cấp cụ thể (không có công thức nội suy nào viết lại bằng C++ song song — không có "2 công thức làm cùng 1 việc"). Lua đảm nhiệm TOÀN BỘ phép tính nội suy theo cấp (Line/Conic/Extrac/Link + khả năng viết hàm tùy chỉnh); C++ chỉ điều phối (đọc cột nào từ Skills.txt cần gọi, gọi Lua, parse chuỗi kết quả trả về thành enum + giá trị runtime qua `ParseString2MagicAttrib`). **Combat runtime thực tế (CalcDamage, AppendSkillEffect — đã ghi ở `vltk_player_stats_reference.md` mục 11-12) hoàn toàn bằng C++ và KHÔNG gọi lại Lua** — Lua chỉ tham gia ở giai đoạn NẠP DỮ LIỆU (load skill level data lúc server khởi động / khi skill lên cấp), không tham gia vào vòng lặp combat runtime (mỗi lần đánh không gọi lại Lua, giá trị đã được cache sẵn vào struct `KSkill` qua `ParseString2MagicAttrib`).

### A.4. Danh sách ĐẦY ĐỦ các "magic attrib type" (magic_attackrating_p, magic_physicsenhance_p,
magic_seriesdamage_p, magic_deadlystrike_p, magic_fatallystrike_p, magic_steallife_p,
magic_stealmana_p, magic_stealstamina_p, magic_colddamage_v, magic_firedamage_v,
magic_lightingdamage_v, magic_poisondamage_v, magic_stun_p, magic_ignorenegativestate_p,
magic_ignoredefense_p, magic_magicdamage_v, ...) — ý nghĩa từng field, tìm trong `KMagicAttrib.h`
hoặc enum liên quan.

> Nguồn enum: `KMagicAttrib.h` (toàn văn, dòng 6-311). Nguồn tên string tương ứng (dùng để so khớp với text trong Skills.txt/lua, KHÔNG có prefix `magic_`): `KMagicDesc.cpp:11-317`, mảng `const char MAGIC_ATTRIB_STRING[][100]`. Tổng cộng **304 giá trị enum** (từ `magic_skill_begin` = 0 đến `magic_normal_end` = 303, bao gồm cả các mốc `_begin`/`_end`/`_reserve` dùng làm ranh giới nhóm chứ không phải attrib thật). File không có comment tiếng Trung/Anh giải thích ý nghĩa từng dòng (khác kỳ vọng ban đầu) — tên biến TỰ MÔ TẢ theo quy ước rõ ràng, được nêu dưới đây.

**Quy ước hậu tố:** `_v` = giá trị tuyệt đối (value, cộng thẳng vào stat), `_p` = phần trăm (percent), `_b` = boolean/cờ bật-tắt, `_yan_p` = biến thể "diễn" — dùng cho state buff hiển thị/tính riêng biệt với biến gốc không có `_yan` (nghi vấn: có thể là 1 lớp buff khác nguồn/khác cách cộng dồn với biến gốc, KHÔNG xác nhận được ý nghĩa chính xác của hậu tố "_yan" từ 2 file đã đọc — ghi nhận pattern, không suy đoán thêm). `anti_` = kháng lại/giảm hiệu ứng tương ứng từ đối phương. `me2xxxdamage_p` = % damage đặc biệt liên quan tới hệ ngũ hành cụ thể (kim/mộc/thủy/hỏa/thổ) tác động lên bản thân người cast.

**Nhóm theo range (đúng theo ranh giới `_begin`/`_end` trong enum gốc):**

| Range (index) | Tên nhóm | Mô tả (suy từ context sử dụng ở `ParseString2MagicAttrib`, mục A.2) |
|---|---|---|
| 0-13 (`magic_skill_begin`..`magic_skill_end`) | Skill meta | Các thuộc tính TĨNH của skill: cost mana (`skill_cost_v`), loại resource tiêu hao (`skill_costtype_v`), cooldown (`skill_mintimepercast_v`), số lượng đạn (`skill_misslenum_v`), hình dạng đạn (`skill_misslesform_v`), 2 tham số tự do (`skill_param1_v`/`skill_param2_v`), bán kính tấn công, cấp kích hoạt skill sự kiện, skill phụ trợ liên kết (`skill_appendskill`) |
| 14-26 (`magic_missle_begin`..`magic_missle_end`) | Thuộc tính đạn/projectile | Kiểu di chuyển, tốc độ, thời gian sống, độ cao, phạm vi gây damage, bán kính, tỷ lệ trượt, số lần trúng đích của đạn |
| 27-54 (`magic_item_begin`..`magic_item_end`) | Yêu cầu/thuộc tính TRANG BỊ (không phải skill thuần) | Damage vũ khí min/max, phòng thủ giáp, độ bền, yêu cầu Str/Dex/Vit/Eng/Level/hệ/giới tính/môn phái để trang bị, % tăng damage vũ khí/phòng thủ giáp, giảm % yêu cầu, chống phá hủy, đã kết hôn (item cưới?), giảm % thời gian cast, yêu cầu chuyển sinh, yêu cầu điểm may mắn, item "tím" (item_purple — có thể là rank/chất lượng đặc biệt), % cộng damage chung, % không cộng điểm PK khi dùng, % cộng damage lên boss |
| 55-83 (`magic_damage_begin`..`magic_damage_end`) | **Damage/Combat modifier của SKILL — nhóm quan trọng nhất cho combat** | `attackrating_v/p` (cộng AR tuyệt đối/%), `ignoredefense_p` (bỏ qua % defense mục tiêu), `magicdamage_v` (damage phép tuyệt đối), `seriesdamage_p` (% damage theo hệ ngũ hành), `physicsdamage_v`/`physicsenhance_p` (damage vật lý tuyệt đối / % tăng damage vật lý — **dùng chung 1 slot lưu trữ**, xem A.2), `colddamage_v`/`firedamage_v`/`lightingdamage_v`/`poisondamage_v` (damage tuyệt đối theo từng nguyên tố), `steallife_p`/`stealmana_p`/`stealstamina_p` (% hút máu/nội/thể lực), `knockback_p` (% đẩy lùi), `deadlystrike_p`/`fatallystrike_p` (% tỷ lệ chí mạng thường/chí mạng cực đại — 2 CƠ CHẾ CRIT TÁCH BIỆT, khớp với `MAX_DEATLY_STRIKE_ENHANCEP`/`MIN,MAX_FATALLY_STRIKE_ENHANCEP` đã ghi ở `vltk_player_stats_reference.md` mục 11.7), `stun_p` (% choáng), `randmove` (di chuyển ngẫu nhiên — có thể hiệu ứng đẩy lùi/xoay hướng) |
| 84-303 (`magic_normal_begin`..`magic_normal_end`) | **Buff/Debuff trạng thái chung (áp dụng ngoài combat trực tiếp — HP/Mana/Stamina/stat gốc/kháng/tốc độ/hiệu ứng đặc biệt)** | Nhóm LỚN NHẤT (220 giá trị) — xem danh sách đầy đủ bên dưới |

**Danh sách ĐẦY ĐỦ 304 giá trị enum (index : tên, không prefix `magic_` theo đúng mảng string gốc `KMagicDesc.cpp:11-317`; áp dụng prefix `magic_` khi tra cứu enum C++ tương ứng trong `KMagicAttrib.h:6-311`):**

```
0   skill_begin                    14  missle_begin                27  item_begin
1   skill_cost_v                   15  missle_movekind_v           28  weapondamagemin_v
2   skill_costtype_v                16  missle_speed_v              29  weapondamagemax_v
3   skill_mintimepercast_v          17  missle_lifetime_v           30  armordefense_v
4   skill_misslenum_v               18  missle_height_v             31  durability_v
5   skill_misslesform_v             19  missle_damagerange_v        32  requirestr
6   skill_param1_v                  20  missle_radius_v             33  requiredex
7   skill_param2_v                  21  missle_missrate             34  requirevit
8   skill_attackradius              22  missle_hitcount             35  requireeng
9   skill_eventskilllevel           23  missle_reserve3             36  requirelevel
10  skill_showevent                 24  missle_reserve4             37  requireseries
11  skill_appendskill                25  missle_reserve5             38  requiresex
12  skill_reserve3                  26  missle_end                  39  requiremenpai
13  skill_end                                                       40  weapondamageenhance_p
                                                                     41  armordefenseenhance_p
                                                                     42  requirementreduce_p
                                                                     43  indestructible_b
                                                                     44  married
                                                                     45  dec_percasttime
                                                                     46  require_translife
                                                                     47  require_fortune_value
                                                                     48  item_reserve2
                                                                     49  item_reserve3
                                                                     50  item_purple
                                                                     51  add_damage_p
                                                                     52  not_add_pkvalue_p
                                                                     53  add_boss_damage
                                                                     54  item_end

55  damage_begin                    84  normal_begin                 168 metalskill_v
56  attackrating_v                  85  lifemax_v                    169 woodskill_v
57  attackrating_p                  86  lifemax_p                    170 waterskill_v
58  ignoredefense_p                 87  life_v                        171 fireskill_v
59  magicdamage_v                   88  lifereplenish_v               172 earthskill_v
60  seriesdamage_p                  89  manamax_v                     173 fatallystrikeres_p
61  physicsdamage_v                 90  manamax_p                     174 dynamicmagicshield_v
62  colddamage_v                    91  mana_v                        175 staticmagicshield_p
63  firedamage_v                    92  manareplenish_v               176 expenhance_p
64  lightingdamage_v                93  staminamax_v                 177 ignoreskill_p
65  poisondamage_v                  94  staminamax_p                 178 poisondamagereturn_v
66  physicsenhance_p                95  stamina_v                    179 poisondamagereturn_p
67  steallife_p                     96  staminareplenish_v            180 returnskill_p
68  stealmana_p                     97  strength_v                    181 skill_mintimepercastonhorse_v
69  stealstamina_p                  98  dexterity_v                   182 poison2decmana_p
70  knockback_p                     99  vitality_v                    183 hide
71  deadlystrike_p                  100 energy_v                      184 autodeathskill
72  fatallystrike_p                 101 poisonres_p                   185 clearnegativestate
73  stun_p                          102 fireres_p                     186 returnres_p
74  trong (dự phòng, không dùng)    103 lightingres_p                 187 autoattackskill
75  randmove                        104 physicsres_p                  188 dec_percasttimehorse
76  damage_reserve2                 105 coldres_p                     189 normal_reserve4
77  damage_reserve3                 106 freezetimereduce_p            190 lifereplenish_p
78  damage_reserve4                 107 burntimereduce_p              191 frozen_action
79  damage_reserve5                 108 poisontimereduce_p            192 normal_reserve5
80  damage_reserve6                 109 poisondamagereduce_v          193 sorbdamage_p
81  damage_reserve7                 110 stuntimereduce_p              194 autorescueskill
82  damage_reserve8                 111 fastwalkrun_p                 195 autoreplyskill
83  damage_end                      112 visionradius_p                196 anti_hitrecover
                                    113 fasthitrecover_v              197 magicdamage_p
                                    114 allres_p                      198 anti_poisonres_p
                                    115 attackspeed_v                 199 anti_fireres_p
                                    116 castspeed_v                   200 anti_lightingres_p
                                    117 meleedamagereturn_v           201 anti_physicsres_p
                                    118 meleedamagereturn_p           202 anti_coldres_p
                                    119 rangedamagereturn_v           203 fastwalkrun_yan_p
                                    120 rangedamagereturn_p           204 anti_poisontimereduce_p
                                    121 addphysicsdamage_v            205 do_hurt_p
                                    122 addfiredamage_v               206 me2wooddamage_p
                                    123 addcolddamage_v               207 skill_desc
                                    124 addlightingdamage_v           208 skill_collideevent
                                    125 addpoisondamage_v             209 skill_vanishedevent
                                    126 addphysicsdamage_p            210 skill_startevent
                                    127 slowmissle_b                  211 skill_flyevent
                                    128 changecamp_b                  212 skill_dohurt
                                    129 physicsarmor_v                213 skill_bymissle
                                    130 coldarmor_v                   214 candetonate1
                                    131 firearmor_v                   215 candetonate2
                                    132 poisonarmor_v                 216 candetonate3
                                    133 lightingarmor_v               217 anti_fireres_yan_p
                                    134 damage2addmana_p              218 anti_maxres_p
                                    135 lucky_v                       219 anti_do_stun_p
                                    136 steallifeenhance_p            220 anti_stuntimereduce_p
                                    137 stealmanaenhance_p            221 anti_poisonres_yan_p
                                    138 stealstaminaenhance_p         222 anti_coldres_yan_p
                                    139 allskill_v                    223 anti_do_hurt_p
                                    140 addphysicsmagic_v             224 anti_allres_yan_p
                                    141 addcoldmagic_v                225 pk_punish_weaken
                                    142 addfiremagic_v                226 block_rate
                                    143 addlightingmagic_v            227 enhancehit_rate
                                    144 addpoisonmagic_v              228 poisonres_yan_p
                                    145 knockbackenhance_p            229 lightingres_yan_p
                                    146 deadlystrikeenhance_p         230 fireres_yan_p
                                    147 stunenhance_p                 231 physicsres_yan_p
                                    148 badstatustimereduce_v         232 coldres_yan_p
                                    149 manashield_p                  233 lifemax_yan_v
                                    150 adddefense_v                  234 lifemax_yan_p
                                    151 adddefense_p                  235 manamax_yan_v
                                    152 fatallystrikeenhance_p        236 manamax_yan_p
                                    153 lifepotion_v                  237 sorbdamage_yan_p
                                    154 manapotion_v                  238 pk_punish_enhance
                                    155 physicsresmax_p               239 attackspeed_yan_v
                                    156 coldresmax_p                  240 castspeed_yan_v
                                    157 fireresmax_p                  241 allres_yan_p
                                    158 lightingresmax_p              242 me2earthdamage_p
                                    159 poisonresmax_p                243 skill_enhance
                                    160 allresmax_p                   244 anti_physicsres_yan_p
                                    161 coldenhance_p                 245 fasthitrecover_yan_v
                                    162 fireenhance_p                 246 five_elements_enhance_v
                                    163 lightingenhance_p             247 five_elements_resist_v
                                    164 poisonenhance_p               248 anti_lightingres_yan_p
                                    165 magicenhance_p                249 metal2medamage_p
                                    166 attackratingenhance_v         250 reduceskillcd3
                                    167 attackratingenhance_p         251 clearallcd
                                                                      252 anti_enhancehit_rate
                                                                      253 me2metaldamage_p
                                                                      254 normal_reserve6
                                                                      255 normal_reserve7
                                                                      256 wood2medamage_p
                                                                      257 me2waterdamage_p
                                                                      258 water2medamage_p
                                                                      259 me2firedamage_p
                                                                      260 fire2medamage_p
                                                                      261 do_stun_p
                                                                      262 earth2medamage_p
                                                                      263 normal_reserve8
                                                                      264 enhancehiteffect_rate
                                                                      265 meleedamagereturnmana_p
                                                                      266 rangedamagereturnmana_p
                                                                      267 reduceskillcd1
                                                                      268 reduceskillcd2
                                                                      269 anti_sorbdamage_yan_p
                                                                      270 anti_block_rate
                                                                      271 addblockrate
                                                                      272 walkrunshadow
                                                                      273 returnskill2enemy
                                                                      274 manatoskill_enhance
                                                                      275 melee_returnres_p
                                                                      276 range_returnres_p
                                                                      277 addskilldamage1
                                                                      278 addskilldamage2
                                                                      279 addskilldamage3
                                                                      280 addskilldamage4
                                                                      281 addskilldamage5
                                                                      282 addskilldamage6
                                                                      283 addskilldamage7
                                                                      284 addskilldamage8
                                                                      285 addskilldamage9
                                                                      286 missle_exp_begin
                                                                      287 missle_range
                                                                      288 missle_dmginterval
                                                                      289 missle_zspeed
                                                                      290 missle_ablility
                                                                      291 missle_param
                                                                      292 missle_wait
                                                                      293 missle_fly
                                                                      294 missle_collide
                                                                      295 missle_vanish
                                                                      296 missle_exp_rev1
                                                                      297 missle_exp_rev2
                                                                      298 missle_exp_rev3
                                                                      299 missle_exp_rev4
                                                                      300 missle_exp_rev5
                                                                      301 missle_exp_end
                                                                      302 ignorenegativestate_p
                                                                      303 normal_end
```

**Chú ý cho các agent làm phần môn phái riêng (PHẦN B):** khi gặp 1 tên biến trong file `.lua` môn phái (VD `tangmen.lua`) hoặc cột `Param1Memo`/`LvlSettingN` trong `Skills.txt` mà KHÔNG match với bất kỳ tên nào trong bảng trên (bỏ prefix `magic_`), đó là dấu hiệu: (a) bản build/version Skills.txt của bộ dữ liệu khác với bản `.h`/`.cpp` đang đọc (có thể lệch version), hoặc (b) tên biến đó chỉ là biến LUA NỘI BỘ (không phải magic attrib thật, ví dụ biến tạm trong công thức riêng của môn phái) — KHÔNG suy đoán ý nghĩa, cần đối chiếu lại `ParseString2MagicAttrib` (mục A.2) hoặc ghi "không xác định" nếu không tìm thấy khớp.

---

## PHẦN B — Từng môn phái (mỗi mục: toàn bộ skill đánh + bổ trợ, công thức riêng nếu có)

### B.1. Thiếu Lâm (shaolin.lua)

> Đối chiếu tên từ `settings/Skills.txt` (cột `SkillName`, lọc `LvlSetScript` chứa `shaolin.lua`).
> File Skills.txt gốc là encoding **TCVN3/TCVN5712-1** (không phải UTF-8/cp936) — đã convert bằng
> `iconv -f TCVN5712-1 -t UTF-8` để đọc đúng tiếng Việt có dấu. Giá trị field ghi dạng
> `level1 → levelMax` (levelMax = cấp cao nhất xuất hiện trong mảng, thường 20, một số skill 150 lên
> tới 26+). Nếu field dùng nội suy `Conic` thay vì `Line` mặc định, có ghi chú.

Tổng cộng **20 block skill** định nghĩa trong `shaolin.lua` (không tính hàm `SkillExpFunc`/`Line`/
`Conic`/`Extrac`/`Link`/`GetSkillLevelData`/`Param2String` ở cuối file — đây là hàm dùng chung).

| Biến lua | Tên tiếng Việt (Skills.txt) | Loại | Field số liệu (lv1 → lvMax) |
|---|---|---|---|
| `jingang_fumo` | Kim Cang Phục Ma | Đánh (phi tiêu) | `physicsenhance_p` 15→55 (lv20); `seriesdamage_p` 1→10; `addskilldamage1` (id321→id321, hệ số 1→61); `addskilldamage2` (id319→319, hệ số 1→64); `addskilldamage3` (id11→11, hệ số 1→35); `addskilldamage4` (id19→19, hệ số 1→35); `addskilldamage5` (id1056, +150, hệ số 1→54); `addskilldamage6` (id1057, +150, hệ số 1→51); `missle_speed_v` 18→18; `missle_lifetime_v` 4→4; `skill_attackradius` 54→54; `skill_cost_v` 2→6 |
| `shaolin_gunfa` | Thiếu Lâm Côn pháp (hỗ trợ bị động — buff cận chiến khi dùng côn) | Bổ trợ | `addphysicsdamage_p` 25→100 (lv20); `attackratingenhance_p` 35→275; `deadlystrikeenhance_p` 6→45 (nội suy `Conic`) |
| `shaolin_daofa` | Thiếu Lâm Đao pháp | Bổ trợ | `addphysicsdamage_p` 25→215; `deadlystrikeenhance_p` 5→15 (`Conic`) |
| `shaolin_quanfa` | Thiếu Lâm Quyền Pháp | Bổ trợ | `addphysicsdamage_p` 25→415; `attackratingenhance_p` 35→275; `deadlystrikeenhance_p` 6→45 (`Conic`) |
| `xinglong_buyu` | Hàng Long Bất Vũ | Đánh | `physicsenhance_p` 60→445; `seriesdamage_p` 1→10; `addskilldamage1` (id318, hệ số 1→150); `addskilldamage2` (id317, 1→150); `addskilldamage3` (id271, 1→35); `addskilldamage4` (id272, 1→35); `addskilldamage5` (id1083 +150, 1→125); `addskilldamage6` (id1055 +150, 1→125); `skill_cost_v` 2→10 |
| `longzhao_huzhua` | Long Trảo Hổ Trảo | Đánh | `physicsenhance_p` 120→1242 (lv20); `seriesdamage_p` 10→50 (lv20), 52 (lv21); `ignoredefense_p` 9→85 (lv20), 86 (lv21); `stun_p` 1→5 (2 mảng giống nhau — chưa rõ tại sao lặp, có thể 1 mảng là % và 1 mảng là thời gian, "cần xem lại"); `deadlystrike_p` 5→40; `colddamage_v` 10→56; `addskilldamage1` (id318, 1→110); `addskilldamage2` (id317, 1→110); `addskilldamage3` (id1083 +150, 1→110, mở rộng 125 lv25, 133 lv27); `addskilldamage4` (id1055 +150, tương tự); `missle_speed_v` 26→26; `missle_lifetime_v` 4→4; `skill_attackradius` 78→78; `skill_cost_v` 1→16 |
| `luohan_zhen` | La Hán Trận | Bổ trợ (phòng ngự + phản đòn) | `addphysicsdamage_p` 11→135 (mảng 2: hằng 18; mảng 3: hằng 6 — chưa rõ nghĩa 2 mảng phụ, có thể là điều kiện kích hoạt); `meleedamagereturn_p` 1→45 (lv20), 46 (lv21) — % phản sát thương cận chiến; `rangedamagereturn_p` 1→45/46 — % phản sát thương tầm xa; `adddefense_v` 40→800 |
| `budong_mingwang` | Bất Động Minh Vương | Bổ trợ | `attackratingenhance_p` 28→275; `adddefense_v` 15→250 (mảng 2 dùng hằng số lớn `18*120`→`18*180`, khả năng là đơn vị thời gian tick — "chưa rõ nghĩa"); `skill_cost_v` 10→40 |
| `shizi_hou` | Sư Tử Hống | Đánh (choáng) | `stun_p` 15→65 (lv20)/66(lv21) mảng 1; mảng 2 riêng 5→27/28 (có thể là % và thời lượng); `physicsdamage_v` 45→140; `skill_cost_v` 10→60; `skill_eventskilllevel` 1→20 (cờ đánh dấu skill sự kiện, không phải số liệu combat) |
| `mohe_wuliang` | Ma Ha Vô Lượng | Đánh | `physicsenhance_p` 52→372; `seriesdamage_p` 10→50/52; `addskilldamage1` (id321, 1→46 [92/2]); `addskilldamage2` (id1057 +150, 1→38); `colddamage_v` 10→56; `missle_speed_v` 28→32; `skill_attackradius` 448→512; `skill_cost_v` 15→35 |
| `hengsao_liuhe` | Hoành Tảo Lục Hợp | Đánh | `physicsenhance_p` 71→417; `seriesdamage_p` 10→50/52; `attackrating_p` 12→50; `colddamage_v` 10→56; `deadlystrike_p` 10→30; `addskilldamage1` (id319, 1→48 [96/2]); `addskilldamage2` (id1056 +150, 1→40); `skill_attackradius` 96→96; `skill_cost_v` 8→8 |
| `yijin_jing` | Dịch Cân Kinh | Bổ trợ (passive tăng kháng) | `allres_p` 1→20 (lv20; mảng 2 hằng -1 → -1, đánh dấu "vô hạn cấp"/luôn active — quy ước chung, xem Phần A) |
| `rulai_qianye` | Như Lai Thiên Diệp | Bổ trợ | `addphysicsdamage_p` 65→215 (lv30); `lifemax_p` 3→100 (lv30); `addcolddamage_v` 10→215; `deadlystrikeenhance_p` 5→15; `attackspeed_v` 35→65; `skill_cost_v` 15→45 |
| `damo_dujiang` | Đạt Ma Độ Giang (= Kim Phật Xuất Kích, 2 dòng Skills.txt trỏ cùng biến — 1 là bản gốc, 1 có thể bản NPC/biến thể) | Đánh | `physicsenhance_p` 55→615 (lv20, mốc giữa lv15=345); `seriesdamage_p` 20→60/62; `ignoredefense_p` 9→90 (lv20)…99 (lv24); `skill_cost_v` 15→35; `colddamage_v` 10→155; `deadlystrike_p` 5→40; `addskillexp1`/`skill_skillexp_v` = công thức exp lên cấp skill (dùng `SkillExpFunc`, không phải combat stat); `missle_speed_v` 30→30; `skill_attackradius` 90→90; `addskilldamage1` (id1083 +150, 10→50); `addskilldamage2` (id1055 +150, 10→50) |
| `hengsao_qianjun` | Hoành Tảo Thiên Quân | Đánh | `physicsenhance_p` 10→353 (lv20, mốc lv15=150); `seriesdamage_p` 20→60/62; `skill_cost_v` 15→20; `attackrating_p` 45→412; `deadlystrike_p` 10→30; `colddamage_v` 10→114; `addskilldamage1` (id1056 +150, 1→20); `skill_attackradius` 128→128; `skill_skillexp_v` = bảng exp lên cấp riêng |
| `wuxiang_zhan` | Vô Tướng Trảm | Đánh | `physicsenhance_p` 45→333 (mốc lv15=150); `seriesdamage_p` 20→60/62; `colddamage_v` 10→111; `addskilldamage1` (id1057 +150, 1→18); `skill_cost_v` 15→45; `missle_speed_v` 28→32; `skill_attackradius` 448→512 |
| `dachengrulaizhou` | Đại Thừa Như Lai Chú (skill 120, phản đòn) | Bổ trợ | `poisondamagereturn_p` 5→45 (lv20)/45(lv21) — % phản độc; `returnskill_p` 5→56/57 — % tự động phản kích; `autoreplyskill` = mã hoá id+level skill phản kích tự động (cấu trúc `20*256+lvl` — encoding id*256+level, "cấu trúc phức tạp, cần xem lại" nếu cần giải mã chính xác); `skill_skillexp_v` = bảng exp cố định 20 cấp |
| `quanshaolin150` | Đại Lực Kim Cang Chưởng (150) — cũng = Long Thừa Bát Nhã Thủ (dòng khác trong Skills.txt trỏ cùng biến) | Đánh | `physicsenhance_p` 65→1325 (lv26, mốc lv15=415, lv20=740, lv23=1130); `seriesdamage_p` 40→80/82; `ignoredefense_p` 9→99 (lv23-24); `skill_cost_v` 18→49 (lv23); `colddamage_v` 12→266 (lv26); `stun_p` 1→10 (lv21-22) mảng1, mảng2 5→6; `deadlystrike_p` 6→63 (lv26); `missle_speed_v` 30→32; `missle_lifetime_v` 6→6; `skill_attackradius` 180→180; `skill_skillexp_v` = bảng exp riêng lên tới lv25 |
| `gunshaolin150` | Vi Đà Hiến Xử (150) | Đánh | `physicsenhance_p` 12→866 (lv26); `seriesdamage_p` 40→80/82; `skill_cost_v` 18→27 (lv23); `attackrating_p` 65→846 (lv26); `deadlystrike_p` 20→56 (lv26); `colddamage_v` 12→197 (lv26); `skill_attackradius` 128→128; `skill_skillexp_v` = bảng exp riêng |
| `daoshaolin150` | Tam Giới Quy Thiền (150) | Đánh | `physicsenhance_p` 55→796 (lv26); `seriesdamage_p` 40→80/82; `colddamage_v` 12→193 (lv26); `skill_eventskilllevel`/`skill_startevent` = cờ sự kiện (kích hoạt hiệu ứng nhân đôi "double x daoshaolin150", không phải damage stat); `skill_cost_v` 18→72 (lv26); `missle_speed_v` 32→38; `skill_attackradius` 448→512; `skill_skillexp_v` = bảng exp riêng |

**Skill KHÔNG có block riêng trong lua** (theo Skills.txt nhưng `LvlSetting` rỗng hoặc chỉ tham chiếu
field không phải combat — VD `Thiếu Lâm thương pháp (##)`, `Thiếu Lâm Chùy pháp (##)`, `Hỗn Nguyên
Nhất Khí công` [chỉ `staminamax_p`, không tìm thấy block số liệu tương ứng trong file — có thể field
này lấy giá trị mặc định/hardcode nơi khác], `Kim Cang Hộ Thể` [`adddefense_v` không rõ block],
`Lập Địa Thành Phật` [`badstatustimereduce_v`+`skill_cost_v`, không rõ block], `Huệ Nhãn chú`): các
kỹ năng này KHÔNG map được sang 1 block SKILLS{} cụ thể trong `shaolin.lua` — nghi ngờ dữ liệu nằm ở
file khác hoặc field lấy default cứng. Ghi chú "chưa xác định block" thay vì đoán.

---

### B.2. Võ Đang (wudang.lua)

Tổng cộng **26 block skill** trong `wudang.lua`.

| Biến lua | Tên tiếng Việt | Loại | Field số liệu (lv1 → lvMax) |
|---|---|---|---|
| `nulei_zhi` | Nộ Lôi Chỉ | Đánh (sét) | `lightingdamage_v` mảng1 1→5, mảng2 1→75; `seriesdamage_p` 1→10; `addskilldamage1` (id365, hệ số 1→110); `addskilldamage2` (id165, 1→35); `addskilldamage3` (id1078 +150, 1→92); `missle_speed_v` 20→24; `skill_attackradius` 320→384; `skill_cost_v` 15→20 |
| `wudang_jianfa` | Võ Đang Kiếm pháp | Bổ trợ | `addphysicsdamage_p` 25→215; `attackratingenhance_p` 15→72; `deadlystrikeenhance_p` 6→25 (`Conic`) |
| `wudang_quanfa` | Võ Đang Quyền Pháp | Bổ trợ | `manashield_p` -5→-5 (khiên mana không đổi theo cấp, "chưa rõ nghĩa dấu âm — có thể là % giảm mana khi bị hút"); `addlightingmagic_v` 20→915 (lv20) |
| `canghai_mingyue` | Thương Hải Minh Nguyệt | Đánh | `physicsenhance_p` 5→75; `seriesdamage_p` 1→10; `lightingdamage_v` mảng1 6→12, mảng2 6→115; `addskilldamage1` (id368, 1→60); `addskilldamage2` (id267, 1→35); `addskilldamage3` (id1079 +150, 1→52); `missle_speed_v` 20→24; `skill_attackradius` 320→384; `skill_cost_v` 10→15 |
| `zuowang_wuwo` | Tọa Vọng Vô Ngã | Bổ trợ | `manashield_p` 25→80 (lv20)…85 (lv27, mảng2 hằng lớn `18*120`→`18*180` chưa rõ nghĩa — có comment cũ bị disable cho thấy giá trị đã chỉnh sửa qua nhiều bản); `skill_cost_v` 60→160 |
| `jianfei_jingtian` | Kiếm Phi Kinh Thiên | Đánh | `seriesdamage_p` 5→30; `physicsenhance_p` 20→115; `lightingdamage_v` mảng1 10→24, mảng2 10→225; `addskilldamage1` (id162, hệ số 3→268); `addskilldamage2` (id1107 +150, 1→220); `skill_attackradius` 384→416; `skill_cost_v` 10→25 |
| `qingxing_zhen` | Thất Tinh Trận | Bổ trợ | `attackratingenhance_p` 24→450; `adddefense_v` 97→800 |
| `tiyun_zong` | Thế Vân Tung | Bổ trợ (tốc độ di chuyển) | `fastwalkrun_p` 18→60 |
| `boji_erfu` | Bác Cấp Nhi Phục | Đánh (choáng) | `seriesdamage_p` 5→30; `lightingdamage_v` mảng1 5→8, mảng2 5→175; `stun_p` 20→55 (mảng1), mảng2 1→20; `addskilldamage1` (id365, 1→120); `addskilldamage2` (id1078 +150, 1→100); `skill_attackradius` 384→416; `skill_cost_v` 60→70 |
| `wuwo_wujian` | Vô Ngã Vô Kiếm | Đánh (đa phi tiêu) | `lightingdamage_v` mảng1 1→5, mảng2 5→752; `seriesdamage_p` 10→50/52; `addskilldamage1` (id365, hệ số 3→130); `addskilldamage2` (id1078 +150, 1→108); `stun_p` 5→20 (mảng1), mảng2 1→10; `skill_misslenum_v` 1→8 (số lượng phi tiêu); `missle_speed_v` 28→32; `skill_attackradius` 448→512; `skill_cost_v` 70→130 |
| `taiji_shengong` | Thái Cực Thần Công | Bổ trợ (nội công tổng hợp) | `attackspeed_v` 21→65 (lv30); `castspeed_v` 21→65; `addlightingdamage_v` 20→275; `manamax_p` 35→245; `manareplenish_v` 1→12; `lightingenhance_p` 16→100 |
| `sanhuan_taoyue` | Tam Hoàn Thao Nguyệt | Đánh | `seriesdamage_p` 10→50/52; `physicsenhance_p` 20→231; `attackrating_p` 65→345; `deadlystrike_p` 16→25; `stun_p` 1→10; `lightingdamage_v` mảng1 6→20, mảng2 6→386; `addskilldamage1` (id368, 1→125); `addskilldamage2` (id1079 +150, 1→105); `missle_speed_v` 26→26; `missle_lifetime_v` 4→4; `skill_attackradius` 78→78; `skill_cost_v` 15→40 |
| `tiandi_wuji` | Thiên Địa Vô Cực | Đánh | `seriesdamage_p` 20→60/62; `lightingdamage_v` mảng1 5→8, mảng2 5→350 (mốc lv15=150); `addskilldamage1` (id1078 +150, 1→60); `skill_attackradius` 448→512; `missle_lifetime_v` 8→20; `stun_p` 10→20; `skill_cost_v` 60→150; `skill_skillexp_v` = bảng exp riêng (SkillExpFunc) |
| `jianqi_zongheng` | Kiếm Khí Tung Hoành ("ko su dung" — comment lua, KHÔNG dùng trong game live) | Đánh (dữ liệu tồn tại nhưng không active) | `seriesdamage_p` 20→60; `lightingdamage_v` mảng1 12→60, mảng2 58→610 |
| `taiji_wuyi` | Thái Cực Vô Ý ("ko su dung") | Bổ trợ (không active) | `seriesdamage_p` 20→60; `stun_p` 10→20 |
| `nulei_lianhuanji` | Nộ Lôi Liên Hoàn Kích ("ko su dung") | Đánh (không active) | `seriesdamage_p` 20→60; `lightingdamage_v` mảng1 12→60, mảng2 58→610 |
| `renjian_heyi` | Nhân Kiếm Hợp Nhất | Đánh | `physicsenhance_p` 8→194 (mốc lv15=80); `seriesdamage_p` 20→60/62; `lightingdamage_v` mảng1 12→35, mảng2 12→268 (mốc lv15=100); `attackrating_p` 65→345; `stealmana_p` 1→5 (hút nội lực); `deadlystrike_p` 16→25; `missle_speed_v` 30→30; `skill_attackradius` 90→90; `skill_cost_v` 35→60; `addskilldamage1` (id1079 +150, 1→35); `skill_skillexp_v` = bảng exp riêng |
| `xuanyi_wuxiang` | Huyền Nhất Vô Tượng (tăng 3 kiếm — chiêu phụ) | Đánh | `seriesdamage_p` 20→60/62; `lightingdamage_v` mảng1 1→10, mảng2 10→100 |
| `taiji_jianyi` | Thái Cực Kiếm Ý (tăng 2 kiếm — chiêu phụ) | Bổ trợ (choáng) | `stun_p` 1→20 (mảng1), mảng2 1→10 (lv19=9) |
| `wudang120` + `wudang120_child` | Xuất Ứ Bất Nhiễm (120) | Bổ trợ (giảm hồi chiêu, miễn debuff cho đồng đội) | `skill_cost_v` 15→50; `missle_missrate` 85→15 (giảm dần = % né?); `ignorenegativestate_p` (child) 100→100 với mảng2 thời lượng `1*18`→`3*18`; `skill_mintimepercastonhorse_v`/`skill_mintimepercast_v` = thời gian hồi chiêu (đơn vị `*18` = tick/giây, xem `skill_desc` hàm mô tả trong file chia cho 18 ra giây); có hàm `skill_desc(level)` custom mô tả bằng tiếng Việt ngay trong lua |
| `qiwudang150` | Tạo Hóa Thái Thanh (150) | Đánh | `seriesdamage_p` 40→80/82; `lightingdamage_v` mảng1 6→11 (lv23), mảng2 6→852 (lv26); `skill_attackradius` 448→512; `missle_lifetime_v` 20→30; `stun_p` 10→36 (lv23-26); `skill_cost_v` 72→231 (lv26); `skill_skillexp_v` = bảng exp riêng dài (tới lv20=2,730,112) |
| `jianwudang150` | Kiếm Thùy Tinh Hà (150) | Đánh | `physicsenhance_p` 12→577 (lv26); `seriesdamage_p` 40→80/82; `lightingdamage_v` mảng1 15→54, mảng2 15→682 (lv26); `attackrating_p` 78→574; `stealmana_p` 1→6; `deadlystrike_p` 20→34; `missle_speed_v` 0→0 (không đổi — có thể phép cận chiến không cần missile speed); `missle_lifetime_v` 9→9; `skill_attackradius` 90→90; `skill_cost_v` 40→87; `skill_skillexp_v` = bảng exp riêng |
| `jianwudang150_2` | Kiếm Minh Thương Khung (150, tăng 2) | Đánh | `seriesdamage_p` 40→80/82; `stun_p` 1→24 (lv23-26); `lightingdamage_v` mảng1 1→15, mảng2 12→171 |
| `jianwudang150_3` | Kiếm Vũ Diệu Nguyệt (150, tăng 3) | Đánh | `lightingdamage_v` mảng1 20→78, mảng2 60→796; `physicsenhance_p` 12→577; `seriesdamage_p` 40→80/82; `stealmana_p` 1→6; `deadlystrike_p` 20→34 |
| `zaohuataiqing_2` | (phụ trợ hiệu ứng va chạm của Tạo Hóa Thái Thanh — không có dòng Skills.txt riêng tên tiếng Việt, chỉ xuất hiện lồng trong field khác) | Đánh (skill con) | `lightingdamage_v`, `seriesdamage_p` — không tìm thấy định nghĩa số liệu trực tiếp trong file (chỉ có `skill_eventskilllevel`/`skill_collideevent`/`skill_showevent` là cờ sự kiện); "cấu trúc phức tạp, cần xem lại" |

---

### B.3. Nga Mi (emei.lua)

Tổng cộng **27 block skill** trong `emei.lua`.

| Biến lua | Tên tiếng Việt | Loại | Field số liệu (lv1 → lvMax) |
|---|---|---|---|
| `piaoyun_chuanxue` | Phiêu Tuyết Xuyên Vân | Đánh | `seriesdamage_p` 1→10; `colddamage_v` mảng1 15→275, mảng2 25→415; `addskilldamage2` (id380, hệ số 1→75); `addskilldamage1` (id91, 1→35); `addskilldamage3` (id1062 +150, 1→63); `missle_speed_v` 20→24; `skill_attackradius` 320→384; `skill_cost_v` 10→10 |
| `emei_jianfa` | Nga Mi Kiếm Phap | Bổ trợ | `addphysicsdamage_p` 15→215; `deadlystrikeenhance_p` 6→36 |
| `emei_zhangfa` | Nga Mi Chưởng pháp | Bổ trợ | `addcoldmagic_v` 15→515 |
| `sixiang_tonggui` | Tứ Tượng Đồng Quy | Đánh | `seriesdamage_p` 5→30; `colddamage_v` mảng1 35→315, mảng2 45→450; `addskilldamage1` (id331, hệ số 1→76); `addskilldamage2` (id1062 +150, 1→20); `skill_attackradius` 384→416; `skill_cost_v` 25→35 |
| `yiye_zhiqiu` | Nhất Diệp Tri Thu | Đánh | `seriesdamage_p` 1→10; `physicsenhance_p` 30→75; `colddamage_v` 10→80; `deadlystrike_p` 10→20; `addskilldamage1` (id328, 1→60); `addskilldamage2` (id88, 1→35); `addskilldamage3` (id1061 +150, 1→50); `addskilldamage4` (id1091 +150, hằng 50→50); `missle_speed_v` 20→24; `skill_attackradius` 320→384; `skill_cost_v` 25→25 |
| `liushui` | Lưu Thủy | Bổ trợ (tốc độ di chuyển đồng đội) | `fastwalkrun_p` 9→66 (mảng2 hằng 18→18) |
| `bumie_bujue` | Bất Diệt Bất Tuyệt | Đánh | `physicsenhance_p` 80→385; `seriesdamage_p` 10→50/52; `colddamage_v` 10→282; `deadlystrike_p` 15→54; `addskilldamage1` (id328, 1→70); `addskilldamage2` (id1061 +150, 1→60); `missle_speed_v` 28→32; `skill_attackradius` 448→512; `skill_cost_v` 30→35 |
| `mengdie` | Mộng Điệp | Bổ trợ (hồi máu/nội lực đồng đội) | `lifereplenish_v` 1→15; `manareplenish_v` 1→10 (mảng2 hằng 18→18) |
| `foguang_puzhao` | Phật Quang Phổ Chiếu | Đánh | `colddamage_v` mảng1 70→787, mảng2 80→1287; `seriesdamage_p` 10→50/52; `addskilldamage2` (id380, hệ số 1→80); `addskilldamage3` (id1062 +150, 1→65); `skill_cost_v` 30→60 |
| `cihang_pudu` | Từ Hàng Phổ Độ (cũng gán cho "Minh Tâm Kiến Tính" — 1 dòng Skills.txt khác trỏ cùng biến, có thể là skill phái sinh dùng chung số liệu) | Bổ trợ (hồi máu mạnh) | `lifereplenish_v` 275→750 (mảng2 hằng 36→36); `skill_cost_v` 100→100 |
| `fofa_wubian` | Phật Pháp Vô Biên | Bổ trợ | `addcoldmagic_v` 30→315 (lv30); `addcolddamage_v` 70→315; `attackspeed_v` 12→65; `castspeed_v` 12→65; `coldenhance_p` 8→37 |
| `foxin_ciyou` | Phật Tâm Từ Hữu | Bổ trợ | `lifemax_p` 30→125 (mảng2 hằng `18*8`→`18*8`) |
| `tuichuang_wangyue` | Thôi Song Vọng Nguyệt | Đánh | `physicsenhance_p` 40→175; `seriesdamage_p` 5→30; `colddamage_v` 10→120; `deadlystrike_p` 10→30; `addskilldamage1` (id329, 1→49); `addskilldamage2` (id1091 +150, 1→40); `missle_speed_v` 24→28; `skill_attackradius` 384→448; `skill_cost_v` 20→20 |
| `qingyin_fanchang` | Thanh Âm Phạn Xướng | Bổ trợ (giảm hiệu ứng khống chế) | `fasthitrecover_v` 1→20; `fatallystrikeres_p` 1→20 (kháng chí mạng); `freezetimereduce_p` 1→30 (giảm thời gian đóng băng); `poisontimereduce_p` 1→30 (giảm thời gian trúng độc); `stuntimereduce_p` 1→30 (giảm thời gian choáng) |
| `pudu_zhongsheng` | Phổ Độ Chúng Sinh | Bổ trợ (hồi máu/nội lực + kháng ngũ hành đồng đội) | `lifereplenish_v` 1→15; `manareplenish_v` 1→10; `allres_p` 1→40 |
| `sane_jixue` | Tam Nga Tề Tuyết (cũng gồm biến thể "trực tuyến băng lăng"/"直线冰棱") | Đánh | `physicsenhance_p` 10→237 (mốc lv15=100); `seriesdamage_p` 20→60/62; `colddamage_v` 10→111; `deadlystrike_p` 10→54; `missle_speed_v` 28→32; `skill_attackradius` 448→512; `skill_cost_v` 35→35; `addskilldamage1` (id1061 +150, 1→25); `skill_skillexp_v` = bảng exp riêng |
| `yuquan_xichen` | Ngọc Tuyền Tẩy Trần | Đánh | `physicsenhance_p` 30→148; `seriesdamage_p` 20→60/62; `deadlystrike_p` 10→20 |
| `qianfo_qianye` | Thiên Phật Thiên Diệp ("ko su dung" — không active) | Đánh (không active) | `colddamage_v` 45→100; `seriesdamage_p` 20→60/62; `skill_attackradius` 448→512; `skill_cost_v` 30→65 |
| `fengshuang_suiying` | Phong Sương Toái Ảnh | Đánh | `seriesdamage_p` 20→60/62; `colddamage_v` mảng1 20→770 (lv20, mốc lv15=350), mảng2 30→1000; `skill_cost_v` 30→65; `addskilldamage1` (id1062 +150, 1→25); `skill_skillexp_v` = bảng exp riêng |
| `jinding_foguang` | Kim Đỉnh Phật Quang | Đánh | `colddamage_v` 10→585 (lv20)/600(lv21); `seriesdamage_p` 20→60/62; `missle_speed_v` 24→28; `skill_misslenum_v` 1→3 (lv20-21, số phi tiêu) |
| `emei120` (+ `emei120_1..4`) | Bế Nguyệt Phất Trần (120) | Bổ trợ (skill tổng hợp gộp 4 kỹ năng con qua `skill_appendskill`) | `skill_appendskill` = liên kết tới id skill con (Lưu Thủy=89, Phật Tâm Từ Hữu=92, Thanh Âm Phạn Xướng=282, Phổ Độ Chúng Sinh=332) — bản thân KHÔNG có field damage/buff riêng, chỉ đóng vai trò "gộp cấp" (đọc `skill_desc` trong lua: "cấp độ kỹ năng này sẽ lấy theo kỹ năng hỗ trợ cấp thấp nhất"); `skill_skillexp_v` = bảng exp lên cấp |
| `jianemei150` | Kiếm Hoa Vãn Tinh (150) | Đánh | `physicsenhance_p` 12→582 (lv26); `seriesdamage_p` 40→80/82; `colddamage_v` 20→277 (lv26); `deadlystrike_p` 12→90 (lv26); `missle_speed_v` 36→36; `skill_attackradius` 448→512; `skill_cost_v` 45→45; `skill_skillexp_v` = bảng exp riêng |
| `jianemei150_2` | Kiếm Tâm Tĩnh Điển (150, tăng 2) | Đánh | `physicsenhance_p` 36→240 (lv26); `seriesdamage_p` 40→80/82; `deadlystrike_p` 12→27 (lv23); `colddamage_v` 10→157 (lv26) |
| `zhangemei150` | Băng Vũ Lạc Tinh (150 — file lua có ghi chú "hồi yếu, cần xem lại") | Đánh | `seriesdamage_p` 40→80/82; `colddamage_v` mảng1 24→1848 (lv26), mảng2 36→2496 (lv26); `skill_cost_v` 36→91 (lv23); `skill_skillexp_v` = bảng exp riêng |
| `zhangemei150_2` | ("tăng 2 — ko su dung") | Đánh (không active) | `colddamage_v` 10→585/600; `missle_speed_v` 24→28; `seriesdamage_p` 20→60/62; `skill_misslenum_v` 1→3 |
| `fuzhuemei150` | Ngọc Tuyền Tâm Kinh (150) | Đánh | `seriesdamage_p`, `colddamage_v` — KHÔNG tìm thấy block `fuzhuemei150={...}` riêng trong `emei.lua` dù Skills.txt tham chiếu tới; "chưa xác định block, cần xem lại" (có thể nằm ở phiên bản lua khác hoặc data đã bị xoá khỏi file cấp cho agent) |

**Ghi chú đối chiếu tên khó khăn:** một số skill 150 (NPC-variant) trong Skills.txt bị lỗi encoding
thành ký tự Trung/Việt lẫn lộn ngay cả sau khi convert TCVN3→UTF-8 (VD dòng biến thể "…npc" của
`quanshaolin150`, `sane_jixue`...) — đây là do các dòng đó gốc đã được nhập bằng bảng mã Trung Quốc
(GBK) trực tiếp trong file TCVN3, không phải lỗi convert. Tên các dòng này suy ra được từ context
(cùng `LvlSetScript`+biến lua với dòng đã có tên rõ ràng ở trên), không suy đoán số liệu.

### B.4. Cái Bang (gaibang.lua)

> Nguồn: `server\script\skill\gaibang.lua` (575 dòng, đọc toàn bộ) đối chiếu `server\settings\Skills.txt`
> (cột `SkillName`/`SkillId`/`LvlSetScript`, file gốc ISO-8859/TCVN — đã convert UTF-8 bằng
> `iconv -f TCVN -t UTF-8`). File .lua định nghĩa 22 block skill (`SKILLS={...}`), khớp 1-1 với các
> dòng Skills.txt trỏ `LvlSetScript=...gaibang.lua`. Giá trị ghi dạng `level1 → levelMax` (levelMax =
> mốc cao nhất khai báo trong bảng, không phải luôn là 20 — nhiều skill có thêm mốc phụ 21/23/26/30
> cho "đột phá"/tăng cấp sau 120/150).
>
> Field `addskilldamageN` = liên kết buff cho skill con (N-th) theo dạng `[1]={{1,<SkillId>},...}`
> (SkillId của skill được buff — tra ngược Skills.txt để ra tên) và `[3]={{1,<lvl1>},{20,<lvlmax>}}`
> (giá trị % buff theo cấp của CHÍNH skill này). Field `firedamage_v`/`lightingdamage_v`/... dùng
> `[1]`=sát thương min, `[3]`=sát thương max (không có `[2]` → mặc định 0, theo comment cuối file).

| # | Tên biến lua | Tên tiếng Việt (Skills.txt) | Loại | Field số liệu (lv1 → lvMax) |
|---|---|---|---|---|
| 1 | `gaibang_bangfa` | Cái Bang Bổng pháp | Bổ trợ (passive, tăng dùng côn/gậy) | `addphysicsdamage_p`: 10→150 (lv1-20); `deadlystrikeenhance_p`: 2→25 (nội suy `Conic`, lv1-20) |
| 2 | `gaibang_zhangfa` | Cái Bang Chưởng Pháp | Bổ trợ (passive, tăng công kích tay không) | `addfiremagic_v`: 25→275 (lv1-20) — "tăng hiệu quả công kích tay không" theo `SkillDesc` gốc |
| 3 | `yanmen_tuobo` | Diên Môn Thác Bát | Đánh (missile, hệ Hỏa) | `seriesdamage_p`: 1→10; `physicsenhance_p`: 10→55; `firedamage_v` min/max: 10→100 / 10→150; `addskilldamage1` (buff skill id 357="Phi Long Tại Thiên"): 1→40%; `addskilldamage2` (id 125="Bổng Đả ác Cẩu"): 1→35%; `addskilldamage3` (id 1074="Bổng Huýnh Lược Địa"): 1→32%; `missle_speed_v`: 20→24; `skill_attackradius`: 320→384; `skill_cost_v`: 10→10 |
| 4 | `jianren_shenshou` | Kiến Nhân Thần Thủ | Đánh (missile, hệ Hỏa) | `seriesdamage_p`: 1→10; `firedamage_v`: 15→75 / 15→215; `addskilldamage1` (id357): 1→50%; `addskilldamage2` (id128="Kháng Long Hữu Hối"): 1→35%; `addskilldamage3` (id1073="Thời Thừa Lục Long"): 1→40%; `addskilldamage4` (id1101): 1→40%; `missle_speed_v`: 20→24; `skill_attackradius`: 320→384; `skill_cost_v`: 25→25 |
| 5 | `huabu_liushou` | Hoạt Bất Lưu Thủ 11 | Bổ trợ (buff tốc độ) | `fastwalkrun_p` (+% tốc chạy): 9→66, thời lượng hiệu ứng 18\*120→18\*180 (đơn vị "tick", 18 tick≈1s → 120-180s); `skill_cost_v`: 24→50 |
| 6 | `dagou_zhen` | Đả Cẩu Bổng Pháp | Bổ trợ (passive) | `addphysicsdamage_p`: 10→175 (lv1-30) |
| 7 | `xianglong_zhang` | Giáng Long Chưởng | Bổ trợ (debuff bản thân đổi máu lấy nội lực?) | `lifemax_p`: -1→-25 (giảm % Sinh lực tối đa); `manamax_p`: +12→+50 (tăng % Nội lực tối đa); `addfiremagic_v`: 35→750 (mốc phụ lv15=250) |
| 8 | `bangda_egou` | Bổng Đả ác Cẩu | Đánh (missile, hệ Hỏa) | `physicsenhance_p`: 10→179; `seriesdamage_p`: 10→50 (mốc phụ lv21=52); `firedamage_v`: 70→360 / 70→420; `addskilldamage1` (id357): 1→60%; `addskilldamage2` (id1074): 1→50%; `missle_speed_v`: 28→32; `skill_attackradius`: 448→512; `skill_cost_v`: 28→48 |
| 9 | `zuidie_kuangwu` | Túy Điệp Cuồng Vũ | Bổ trợ (buff toàn diện + tăng sát thương tay không) | `allres_p` (+% kháng toàn bộ nguyên tố): 1→30 (lv1-30); `addfiremagic_v`: 10→215; `addfiredamage_v`: 10→175; `deadlystrikeenhance_p`: 5→30 (`Conic`); `skill_cost_v`: 50→100 |
| 10 | `kanglong_youhui` | Kháng Long Hữu Hối | Đánh (missile 2 tia, hệ Hỏa) | `seriesdamage_p`: 10→50 (lv21=52); `firedamage_v`: 10→536 / 10→536; `addskilldamage1` (id357): 1→55%; `addskilldamage2` (id1073): 1→45%; `addskilldamage3` (id1101): 1→45%; `skill_misslesform_v`="dạng đạn +" (đổi từ 1→2 tại lv10); `skill_misslenum_v` (số tia đạn): 1→15 (lv20), →18 (lv25-26); `skill_param1_v` = khoảng cách 2 tia: 0→2; `missle_speed_v`: 28→32; `skill_attackradius`: 448→512; `skill_cost_v`: 10→50 |
| 11 | `huaxian_weiyi` | Hóa Hiểm Vi Di | Bổ trợ (phản đòn cận chiến + tăng phòng) | `meleedamagereturn_p` (% phản sát thương cận chiến): 4→46; `adddefense_v` (+phòng thủ tuyệt đối): 48→800 |
| 12 | `xiaoyao_gong` | Tiêu Diêu Công | Bổ trợ (tăng tốc) | `attackspeed_v`: 6→65; `castspeed_v`: 6→65 |
| 13 | `feilong_zaitian` | Phi Long Tại Thiên | Đánh (missile nhiều tia, hệ Hỏa, có exp riêng theo skill — "tuyệt kỹ") | `seriesdamage_p`: 20→60 (lv21=62, mốc phụ lv15=20); `firedamage_v`: 10→750 / 10→750 (mốc phụ lv15=300); `addskilldamage1` (id1073): 1→25%; `addskilldamage2` (id1101): 1→25%; `missle_speed_v`: 20→24; `skill_misslesform_v`: đổi dạng đạn tại lv11 (1→0); `skill_misslenum_v` (số tia): 1→4 (tăng dần lv11-21); `skill_attackradius`: 448→512; `skill_cost_v`: 10→65; `skill_param1_v` (khoảng cách 2 tia "plus"): 0→32 (từ lv11); có `skill_collideevent` (id389="Long Chiến Ư Dã" — skill con khi va chạm), `skill_showevent` |
| 14 | `longzhan_yuye` | Long Chiến Ư Dã | Đánh (skill con, kích hoạt qua `skill_collideevent` của Phi Long Tại Thiên) | `seriesdamage_p`: 20→60 (lv21=62); `firedamage_v`: 17→371 / 17→371 |
| 15 | `tianxia_wugou` | Thiên Hạ Vô Cẩu | Đánh (missile 3 tia, hệ Hỏa, "tuyệt kỹ" có exp riêng) | `seriesdamage_p`: 20→60 (lv21=62); `skill_misslenum_v`: 1→3; `physicsenhance_p`: 12→450 (mốc phụ lv15=300 — dòng cũ bị comment `--` để lại giá trị 12→206 cũ, dùng bản mới 12→450); `firedamage_v`: 70→285 / 70→432 (mốc phụ lv15=150/200); `addskilldamage1` (id1074): 1→25%; `missle_speed_v`: 20→24; `skill_attackradius`: 448→512; `skill_cost_v`: 20→50 |
| 16 | `gaibang120` | Hỗn Thiên Khí Công (120, "quyết chú" chính) | Bổ trợ (passive kích hoạt tự động khi bị đánh) | `autoattackskill` (id 720 = skill con "Quyết Chú"): kích hoạt cấp độ tương ứng; `autoattackskillplus` = % xác suất phát chiêu: 1→6 (lv1-20/21) + thời gian chờ hồi 12\*18 tick (~12s cố định). Mô tả gốc trong `skill_desc`: "Xác suất X% gây hoại thương" |
| 17 | `gaibang120zuzhou` | Hỗn Thiên Khí Công_Quyết Chú (id 720) | Bổ trợ (debuff địch khi bị Hỗn Thiên Khí Công kích hoạt) | `physicsres_p` (giảm % kháng vật lý địch): -2→-10 (lv21=-10), thời lượng 3\*18→9\*18 tick; `fireres_p` (giảm % kháng hỏa): -3→-15; `physicsresmax_p` (giảm % phòng vật lý max): -1→-6; `fireresmax_p` (giảm % phòng hỏa max): -1→-12; `rangedamagereturn_p` (giảm % phản đòn tầm xa của địch): -4→-30 |
| 18 | `zhanggaibang150` | Ngũ Diệu Càn Khôn (150) | Đánh (missile, hệ Hỏa, "tuyệt kỹ" — tăng cấp đến 25/26 với mốc phụ) | `seriesdamage_p`: 40→80 (lv21=82); `firedamage_v`: 24→1800 (mốc phụ lv15=720, lv23=3096, lv26=3744); `missle_speed_v`: 24→40; `skill_attackradius`: 448→512; `skill_cost_v`: 12→78 (lv23=98); có `skill_collideevent` gọi skill con id1072 |
| 19 | `zhanggaibang150_2` | Thời Thừa Lục Long (150, tầng 2 — skill con ẩn của Ngũ Diệu Càn Khôn) | Đánh | `seriesdamage_p`: 40→80 (lv21=82); `firedamage_v`: 20→450 (lv23=585, lv26=653) |
| 20 | `gungaibang150` | Bổng Huýnh Lược Địa (150) | Đánh (missile 5 tia, hệ Hỏa) | `seriesdamage_p`: 40→80 (lv21=82); `skill_misslenum_v`: 1→5; `physicsenhance_p`: 10→165 (mốc phụ lv15=80, lv23=267, lv26=318); `firedamage_v`: 60→230 / 60→345 (mốc phụ lv15=120/160, lv23=362/567, lv26=428/678); `missle_speed_v`: 24→24; `skill_attackradius`: 448→512; `skill_cost_v`: 20→50 (lv23=59) |

**Ghi chú field lạ/chưa chắc nghĩa:**
- `addskilldamageN` (N=1..9 tùy skill): tên gợi ý "% tăng sát thương cho skill con", cặp `[1]`=SkillId
  mục tiêu, `[3]`=giá trị %. Đã suy ra khá chắc từ ngữ cảnh (khớp comment trong code + Skills.txt) nhưng
  **không tìm thấy nơi field này được ĐỌC trong C++** để xác nhận 100% cách áp dụng — ghi "khá chắc,
  chưa xác nhận 100% qua C++".
- `skill_eventskilllevel`, `skill_collideevent`, `skill_showevent`, `skill_flyevent`: cơ chế kích hoạt
  skill con khi xảy ra sự kiện va chạm/hiển thị — chưa rõ nghĩa chi tiết runtime, chỉ biết trỏ
  tới SkillId khác.
- `addskillexp1`, `skill_skillexp_v`: bảng kinh nghiệm cần để lên cấp skill (không phải combat stat).

### B.5. Côn Lôn (kunlun.lua)

> Nguồn: `server\script\skill\kunlun.lua` (629 dòng, đọc toàn bộ), đối chiếu Skills.txt tương tự B.4.
> Côn Lôn thiên về hệ **Lôi/Băng** (lightingdamage_v, coldres_p...) — tương phản Cái Bang thiên Hỏa.

| # | Tên biến lua | Tên tiếng Việt | Loại | Field số liệu (lv1 → lvMax) |
|---|---|---|---|---|
| 1 | `hufeng_fa` | Hô Phong Pháp | Đánh (missile, hệ Lôi) | `physicsenhance_p`: 5→75; `seriesdamage_p`: 1→10; `lightingdamage_v`: 15→180 / 15→180; `addskilldamage1` (id372="Ngạo Tuyết Tiêu Phong"): 1→100%; `addskilldamage2` (id176="Cuồng Phong Sậu Điện"): 1→35%; `addskilldamage3` (id1080="Cửu Thiên Cương Phong"): 1→83%; `missle_speed_v`: 20→24; `skill_attackradius`: 320→384; `skill_cost_v`: 15→15 |
| 2 | `kunlun_daofa` | Côn Lôn Đao pháp | Bổ trợ (passive dùng đao) | `addphysicsdamage_p`: 35→215; `deadlystrikeenhance_p`: 6→50 (`Conic`) |
| 3 | `kunlun_jianfa` | Côn Lôn Kiếm pháp | Bổ trợ (passive dùng kiếm) | `addlightingmagic_v`: 19→215 |
| 4 | `qingfeng_fu` | Thanh Phong phù | Bổ trợ (buff tốc chạy) | `fastwalkrun_p`: 22→60, thời lượng 18\*120 tick cố định; `skill_cost_v`: 40→40 |
| 5 | `jiban_fu` | Ki Bán phù | Bổ trợ (debuff giảm tốc địch) | `fastwalkrun_p`: -22→-52, thời lượng 18\*20→18\*90; `skill_cost_v`: 60→60 |
| 6 | `baichuan_nahai` | Bách Xuyên Nạp Hải | Bổ trợ (buff kháng, comment "ko su dung" = không dùng trong build này) | `coldres_p`: 13→32; `physicsres_p`: 9→28; `skill_cost_v`: 12→50 |
| 7 | `yiqi_sanqing` | Nhất Khí Tam Thanh | Bổ trợ (passive + buff crit) | `addphysicsdamage_p`: 35→215; `deadlystrikeenhance_p`: 16→35 (`Conic`); `skill_cost_v`: 80→80 |
| 8 | `kuanglei_zhendi` | Cuồng Lôi Chấn Địa | Đánh (missile, hệ Lôi) | `lightingdamage_v`: 27→315 / 27→315; `seriesdamage_p`: 1→10; `addskilldamage1` (id375="Lôi động Cửu Thiên"): 1→60%; `addskilldamage2` (id182="Ngũ Lôi Chánh Pháp"): 1→35%; `addskilldamage3` (id1109="Lôi Động Càn Khôn"): 1→50%; `skill_attackradius`: 320→352; `skill_cost_v`: 15→15 |
| 9 | `tianqing_dizhuo` | Thiên Thanh Địa Trọc | Bổ trợ (buff kháng toàn diện) | `lightingres_p`: 13→32; `fireres_p`: 9→28; `coldres_p`: 13→32; `physicsres_p`: 9→28; `skill_cost_v`: 12→90 |
| 10 | `qixin_fu` | Khí Tâm phù | Bổ trợ (debuff choáng địch) | `stun_p` (% gây choáng): 16→35, tham số phụ 5→36; `skill_cost_v`: 100→100 |
| 11 | `tianji_xunlei` | Thiên Tế Tấn Lôi | Đánh (missile, hệ Lôi) | `lightingdamage_v`: 25→550 / 25→550; `addskilldamage1` (id375): 1→65%; `addskilldamage2` (id1109): 1→54%; `seriesdamage_p`: 1→30; `missle_speed_v`: 24→28; `skill_attackradius`: 384→448; `skill_cost_v`: 15→35 |
| 12 | `kuangfeng_zhoudian` | Cuồng Phong Sậu Điện | Đánh (missile, hệ Lôi, gây choáng) | `seriesdamage_p`: 10→50 (lv21=52); `physicsenhance_p`: 55→386; `lightingdamage_v`: 45→532 / 45→532; `stun_p`: 5→15 (lv21=15), tham số phụ 1→20; `addskilldamage1` (id373="Khiếu Phong Tam Liên Kích"): 1→126%; `addskilldamage2` (id1108="Phong Minh Ngọc Toái"): 1→110%; `missle_speed_v`: 28→32; `skill_attackradius`: 448→512; `skill_cost_v`: 25→25 |
| 13 | `wulei_zhengfa` | Ngũ Lôi Chánh Pháp | Đánh (missile, hệ Lôi) | `seriesdamage_p`: 10→50 (lv21=52); `lightingdamage_v`: 25→937 / 25→937; `addskilldamage1` (id375): 1→70%; `addskilldamage2` (id1109): 1→58%; `skill_attackradius`: 448→480; `skill_cost_v`: 50→90 |
| 14 | `shuangao_kunlun` | Sương Ngạo Côn Lôn | Bổ trợ (buff tổng hợp crit + tốc + công lôi) | `deadlystrikeenhance_p`: 6→15 (lv1-30, `Conic`); `castspeed_v`: 25→65; `attackspeed_v`: 25→65; `addlightingmagic_v`: 30→315 (`Conic`); `addlightingdamage_v`: 45→315 (`Conic`) |
| 15 | `shufu_zhou` | Thúc Phược Chú | Bổ trợ (debuff giảm phản đòn tầm xa địch) | `rangedamagereturn_p`: -5→-35, thời lượng 18\*45→18\*120; `skill_cost_v`: 30→40 |
| 16 | `beiming_daohai` | Bắc Minh Đáo Hải | Bổ trợ (hồi máu/nội lực theo thời gian, giá trị âm = %/tick hồi) | `lifereplenish_v`: -1→-15; `manareplenish_v`: -1→-20; thời lượng 18\*45→18\*120; `skill_cost_v`: 30→40 |
| 17 | `qihan_aoxue` | Khí Hàn Ngạo Tuyết | Bổ trợ (debuff giảm tốc thi triển địch) | `castspeed_v`: -6→-50 (lv30-31); thời lượng 18\*45→18\*120; `skill_cost_v`: 30→40 |
| 18 | `mizhong_huanying` | Mê Tung ảo ảnh | Bổ trợ (giảm thời gian đóng băng/choáng bản thân) | `freezetimereduce_p`: -5→-50; `stuntimereduce_p`: -5→-50; thời lượng 18\*45→18\*120; `skill_cost_v`: 30→40 |
| 19 | `zuixian_cuogu` | Túy Tiên Tá Cốt | Bổ trợ (buff tổng hợp: giảm choáng/đóng băng + hồi máu/nội lực + giảm phản đòn địch) | `freezetimereduce_p`: -5→-50; `stuntimereduce_p`: -5→-50; `lifereplenish_v`: -1→-15; `manareplenish_v`: -1→-20; `rangedamagereturn_p`: -5→-35; `skill_cost_v`: 100→160 |
| 20 | `wusuo_kunlun` | Vụ Tỏa Côn Lôn ("ko su dung") | Đánh (missile, hệ Lôi) | `seriesdamage_p`: 20→60; `lightingdamage_v`: 10→256 / 10→256; `skill_attackradius`: 448→480; `skill_cost_v`: 60→85 |
| 21 | `leidong_jiutian` | Lôi động Cửu Thiên | Đánh (missile, hệ Lôi, "tuyệt kỹ") | `seriesdamage_p`: 20→60 (lv21=62, mốc phụ lv15=20); `lightingdamage_v`: 80→470 / 80→470 (mốc phụ lv15=260); `skill_cost_v`: 40→95 (mốc phụ lv15=60); `addskilldamage1` (id1109): 1→35%; kích hoạt skill con id387 qua `skill_collideevent` |
| 22 | `pingdi_hanlei` | Bình Địa Hám Lôi | Đánh (skill con của Lôi động Cửu Thiên) | `seriesdamage_p`: 20→60 (lv21=62); `lightingdamage_v`: 25→250 / 25→250 |
| 23 | `aoxue_xiaofeng` | Ngạo Tuyết Tiêu Phong | Đánh (missile, hệ Lôi, gây choáng, "tuyệt kỹ") | `physicsenhance_p`: 5→280 (mốc phụ lv15=100); `seriesdamage_p`: 20→60 (lv21=62, mốc phụ lv15=20); `lightingdamage_v`: 39→673 / 39→673 (mốc phụ lv15=200); `stun_p`: 5→25 (lv21=25), tham số phụ 1→12; `missle_speed_v`: 28→32; `skill_attackradius`: 448→512; `skill_cost_v`: 25→45; `addskilldamage1` (id1080): 1→35%; kích hoạt skill con id373 qua `skill_collideevent` |
| 24 | `yufeng_shu` | Ngự Phong thuật ("ko su dung") | Đánh (buff, không có damage field ngoài passive) | `seriesdamage_p`: 20→60 (lv21=62); `physicsenhance_p`: 28→282 |
| 25 | `xiaofeng_sanlianji` | Khiếu Phong Tam Liên Kích | Đánh (missile) | `seriesdamage_p`: 20→60 (lv21=62); `missle_lifetime_v` (thời gian tồn tại đạn): 6→24; `lightingdamage_v`: 85→330 / 115→550 |
| 26 | `xuantianwuji` | Huyền Thiên Vô Cực | Bổ trợ (khiên phép động + phản sát thương) | `dynamicmagicshield_v` (giá trị khiên chắn phép): 50→550 (mốc phụ lv10=230, lv15=370); `returnres_p` (% phản kháng): 5→30 |
| 27 | `kunlun120` | Lưỡng Nghi Chân Khí (120, quyết chú chính) | Bổ trợ (passive tự cứu khi máu thấp) | `autorescueskill` (kích hoạt skill con id721 khi HP<25%): xác suất theo `Link`; mô tả gốc: "Khi sinh lực thấp hơn 25% có xác suất X% phát chiêu Lưỡng Nghi Chân Khí" |
| 28 | `kunlun120mofadun` | Lưỡng Nghi Chân Khí_Ma Pháp Độn (id721) | Bổ trợ (khiên chắn phép tĩnh) | `staticmagicshield_p` (% giảm sát thương phép, dạng nhân "mấy lần mức nội lực hiện tại" theo mô tả gốc): 1800→10000 (/100 = 18→100 lần), thời lượng 5\*18→10\*18 tick |
| 29 | `kunlun120jiasu` | Lưỡng Nghi Chân Khí_Gia Tốc (id722) | Bổ trợ (buff tốc chạy) | `fastwalkrun_p`: 5→35, thời lượng 3\*18→10\*18 |
| 30 | `jiankunlun150fu` | Thiên Lôi Chấn Nhạc (150) | Đánh (missile, hệ Lôi, gây choáng) | `seriesdamage_p`: 40→80 (lv21=82); `stun_p`: 16→35 (lv23=41, lv26=44), tham số phụ 1→20; `lightingdamage_v`: 25→250 / 25→250 (lv23=321, lv26=356); `skill_cost_v`: 48→115 (lv23=166, lv26=192); kích hoạt skill con id1109 qua `skill_vanishedevent` |
| 31 | `jiankunlun150` | Lôi Động Càn Khôn (150, tầng 2) | Đánh | `seriesdamage_p`: 40→80 (lv21=82); `lightingdamage_v`: 192→1130 / 192→1130 (mốc phụ lv15=624, lv23=1737, lv26=2040) |
| 32 | `daokunlun150` | Cửu Thiên Cương Phong (150) | Đánh (missile, hệ Lôi, gây choáng) | `physicsenhance_p`: 6→335 (lv23=593, lv26=722); `seriesdamage_p`: 40→80 (lv21=82); `lightingdamage_v`: 48→806 / 48→806 (lv23=1485, lv26=1824); `stun_p`: 6→30, tham số phụ 1→12; `missle_speed_v`: 28→32; `skill_attackradius`: 448→512; `skill_cost_v`: 30→55 (lv23=62); kích hoạt skill con id1108 qua `skill_collideevent` |
| 33 | `daokunlun150_2` | Phong Minh Ngọc Toái (150, tầng 2) | Đánh | `seriesdamage_p`: 40→80 (lv21=82); `missle_lifetime_v`: 6→24; `lightingdamage_v`: 105→395 / 135→660 (lv23=486/825, lv26=532/908) |

**Ghi chú field lạ:** `dynamicmagicshield_v`, `staticmagicshield_p`, `autorescueskill`,
`autoattackskill` (xem B.4): cơ chế "kích hoạt tự động skill con theo điều kiện" — tên field gợi ý rõ
nhưng KHÔNG xác nhận qua C++ trong phạm vi task này (chỉ đọc lua/Skills.txt theo yêu cầu).

### B.6. Đường Môn (tangmen.lua)

> Đã có phần phân tích trước ở `docs/vltk_player_stats_reference.md` mục 10.3 (chỉ vài skill mẫu:
> `physicsenhance_p`, `addphysicsdamage_p`, `deadlystrike_p`, `deadlystrikeenhance_p`). Bảng dưới đây
> là **ĐẦY ĐỦ mọi skill** trong `tangmen.lua` (757 dòng, đọc toàn bộ), đối chiếu Skills.txt.
> Đường Môn thiên về **ám khí/độc** (`poisondamage_v`, `poisonenhance_p`, `deadlystrike_p` xuất hiện
> ở hầu hết skill đánh — đặc trưng "chí mạng" + độc của phái này).

| # | Tên biến lua | Tên tiếng Việt | Loại | Field số liệu (lv1 → lvMax) |
|---|---|---|---|---|
| 1 | `pili_dan` | Phích Lịch đơn | Đánh (missile, đa hiệu ứng buff skill con) | `physicsenhance_p`: 20→80; `seriesdamage_p`: 1→10; `poisondamage_v`: 1→5 (tham số phụ 60/60, 10/10 — có thể là số tick độc/chu kỳ); `deadlystrike_p`: 1→8; `addskilldamage1..9` buff cho 9 skill con khác nhau (id339="Nhiếp Hồn Nguyệt ảnh": 1→45%; id302="Bạo Vũ Lê Hoa": 1→35%; id342="Cửu Cung Phi Tinh": 1→40%; id341="Tán Hoa Tiêu": 1→35%; id249="Tiểu Lý Phi Đao": 1→35%; id58="Thiên La Địa Võng": 1→35%; id1069="Vô ảnh Xuyên": 1→38%; id1070="Thiết Liên Tứ Sát": 1→30%; id1071="Càn Khôn Nhất Trịch": 1→35%); `skill_cost_v`: 12→12 |
| 2 | `tangmen_anqi` | Đường Môn Ám khí | Bổ trợ (passive tăng sát thương ám khí) | `addphysicsdamage_p`: 25→215 (tham số phụ cố định 7) |
| 3 | `duohun_biao` | Đoạt Hồn Tiêu | Đánh (missile độc) | `physicsenhance_p`: 25→115; `seriesdamage_p`: 5→30; `deadlystrike_p`: 2→12; `addskilldamage1` (id342): 1→45%; `addskilldamage2` (id1071): 1→38%; `addskilldamage3` (id1099): 1→38%; `addskilldamage4` (id1100): 1→38%; `poisondamage_v`: 3→8; `missle_speed_v`: 24→28; `skill_attackradius`: 384→448; `skill_cost_v`: 5→16 |
| 4 | `xinyan` | Tâm Nhãn | Bổ trợ (passive tổng hợp — buff mạnh nhất phái, MaxLevel=30) | `addcolddamage_v`: 10→110 (lv1-30); `addpoisondamage_v`: 1→10 (lv1-30, tham số phụ 10); `addphysicsdamage_p`: 15→115 (tham số phụ 7); `poisonenhance_p` (% tăng hiệu quả độc): 3→33; `deadlystrikeenhance_p`: 8→26; `attackspeed_v`: 29→106 |
| 5 | `zhuixin_jian` | Truy Tâm Tiễn | Đánh (missile độc) | `physicsenhance_p`: 20→185; `seriesdamage_p`: 5→30; `poisondamage_v`: 3→8; `deadlystrike_p`: 5→15; `addskilldamage1` (id339): 1→50%; `addskilldamage2` (id1069): 1→42%; `missle_speed_v`: 24→28; `skill_attackradius`: 384→448; `skill_cost_v`: 20→20 |
| 6 | `mantian_huayu` | Mạn Thiên Hoa Vũ | Đánh (missile độc) | `physicsenhance_p`: 30→185; `seriesdamage_p`: 5→30; `poisondamage_v`: 3→8; `deadlystrike_p`: 1→8; `addskilldamage1` (id302): 1→45%; `addskilldamage2` (id1070): 1→38%; `skill_attackradius`: 384→416; `skill_cost_v`: 40→40 |
| 7 | `tianluo_diwang` | Thiên La Địa Võng | Đánh (missile độc, "tuyệt kỹ" bậc thấp) | `seriesdamage_p`: 10→50 (lv21=52); `physicsenhance_p`: 80→344; `poisondamage_v`: 5→24; `deadlystrike_p`: 5→14; `addskilldamage1` (id302): 1→55%; `addskilldamage2` (id1070): 1→46%; `missle_speed_v`: 26→28 (lv21=28); `skill_attackradius`: 448→512 (lv21=512); `skill_cost_v`: 45→65 |
| 8 | `tianluo_diwang1` | Thiên La Địa Võng — skill con "event collide" (không có tên riêng trong Skills.txt, chỉ hiện qua event) | Đánh | `seriesdamage_p`: 10→50 (lv21=52); `physicsenhance_p`: 40→120 (bằng 1/2 giá trị bản chính); `missle_speed_v`: 26→28 |
| 9 | `xiaoli_feidao` | Tiểu Lý Phi Đao | Đánh (missile độc, không cần event) | `seriesdamage_p`: 10→50 (lv21=52); `physicsenhance_p`: 50→344; `poisondamage_v`: 5→24; `deadlystrike_p`: 10→59; `skill_dohurt` (? có thể = số lần gây sát thương hoặc hurt-flag): 10→60 (lv21=62); `addskilldamage1` (id340="Ngân Đao Xạ Nguyệt"): 1→82%; `addskilldamage2` (id1097="Truy Tâm Tỏa Mệnh"): 1→68%; `skill_cost_v`: 50→50 |
| 10 | `diyan_huo` | Địa Diệm Hỏa (skill "event", cơ quan lửa) | Đánh (hệ Hỏa) | `firedamage_v`: 60→400 / 60→400; `seriesdamage_p`: 1→10; `skill_cost_v`: 20→60 |
| 11 | `duci_gu` | Độc Thích Cốt | Đánh (độc thuần) | `poisondamage_v`: 8→40 (tham số phụ [2]=100 cố định, [3]=10 cố định); `seriesdamage_p`: 1→10; `skill_cost_v`: 20→60 |
| 12 | `chuanxin_ci` | Xuyên Tâm Thích | Đánh (vật lý thuần) | `seriesdamage_p`: 5→30; `physicsdamage_v`: 60→400 / 60→400; `skill_cost_v`: 20→60 |
| 13 | `hanbing_ci` | Hàn Băng Thích | Đánh (hệ Băng) | `seriesdamage_p`: 5→30; `colddamage_v`: 60→400 / 60→400 (tham số phụ [2]: 1→18); `skill_cost_v`: 20→60 |
| 14 | `leiji_shu` | Lôi Kích Thuật | Đánh (hệ Lôi, gây choáng) | `seriesdamage_p`: 10→50 (lv21=52); `lightingdamage_v`: 60→400 / 60→400; `stun_p`: 1→20 (cả 2 tham số); `skill_cost_v`: 20→60 |
| 15 | `luanhuan_ji` | Loạn Hoàn Kích ("cơ quan" tổng hợp ngũ hành, gây choáng) | Đánh (đa hệ: Hỏa+Độc+Vật lý+Băng+Lôi cùng lúc) | `firedamage_v`: 100→400/100→400; `poisondamage_v`: 20→80 (tham số phụ [2]=50, [3]=10); `physicsdamage_v`: 100→400/100→400; `colddamage_v`: 100→400/100→400 (tham số [2]: 1→18); `lightingdamage_v`: 100→400/100→400; `stun_p`: 1→20 (cả 2 tham số); `skill_cost_v`: 60→120 |
| 16 | `nomovespeedatt` | (không tên hiển thị rõ — comment gốc "what is this?" ngay trong code, tác giả gốc cũng không chắc) | Chưa rõ (debuff đứng yên?) | `nomovespeed`: [1]=100→0 (lv1-10), [2]=5\*18→20\*18 (thời lượng), [3]=10→10 cố định; `skill_cost_v`: 1→20 — **chưa rõ nghĩa, giữ nguyên như comment gốc trong file** |
| 17 | `shehun_yueying` | Nhiếp Hồn Nguyệt ảnh | Đánh (missile độc, "tuyệt kỹ") | `physicsenhance_p`: 25→301 (mốc phụ lv15=150); `seriesdamage_p`: 20→60 (lv21=62, mốc phụ lv15=20); `poisondamage_v`: 5→31; `deadlystrike_p`: 10→59; `skill_cost_v`: 30→60; `addskilldamage1` (id1069): 1→42%; `missle_speed_v`: 28→32; `skill_attackradius`: 448→512; kích hoạt skill con id340 qua `skill_collideevent` |
| 18 | `yindao_sheyue` | Ngân Đao Xạ Nguyệt (skill con của Nhiếp Hồn Nguyệt ảnh) | Đánh | `seriesdamage_p`: 20→60 (lv21=62); `physicsenhance_p`: 25→116 |
| 19 | `baoyu_lihua` | Bạo Vũ Lê Hoa | Đánh (missile độc, "tuyệt kỹ") | `seriesdamage_p`: 20→60 (lv21=62, mốc phụ lv15=20); `physicsenhance_p`: 15→434 (mốc phụ lv15=200); `skill_cost_v`: 25→80; `skill_attackradius`: 448→480 (lv21=480); `poisondamage_v`: 1→19; `missle_lifetime_v`: 18→36; `addskilldamage1` (id1070): 1→52%; kích hoạt skill con id301 qua `skill_flyevent` |
| 20 | `zhuixing_zhudian` | Truy Tinh Trục Điện (skill con của Bạo Vũ Lê Hoa) | Đánh | `seriesdamage_p`: 20→60 (lv21=62); `poisondamage_v`: 1→10 |
| 21 | `jiugong_feixing` | Cửu Cung Phi Tinh | Đánh (missile độc, "tuyệt kỹ") | `seriesdamage_p`: 20→60 (lv21=62, mốc phụ lv15=20); `physicsenhance_p`: 10→294 (mốc phụ lv15=100); `deadlystrike_p`: 10→39; `poisondamage_v`: 1→30; `missle_speed_v`: 28→32; `skill_attackradius`: 448→512; `skill_cost_v`: 30→75; `addskilldamage1` (id1071): 1→80%; `addskilldamage2` (id1099): 1→60%; `addskilldamage3` (id1100): 1→60% |
| 22 | `sanhua_biao` | Tán Hoa Tiêu | Đánh (missile độc) | `seriesdamage_p`: 10→50 (lv21=52); `physicsenhance_p`: 20→274; `deadlystrike_p`: 10→39; `addskilldamage1` (id342): 1→50%; `addskilldamage2` (id1071): 1→42%; `addskilldamage3` (id1099): 1→42%; `addskilldamage4` (id1100): 1→42%; `poisondamage_v`: 5→24; `skill_cost_v`: 25→50; `missle_speed_v`: 28→32; `skill_attackradius`: 448→512 |
| 23 | `tangmen120` | Mê ảnh Tung (120, quyết chú — kỹ năng né/dịch chuyển) | Bổ trợ (giảm hồi chiêu + tăng tầm dịch chuyển) | `skill_cost_v`: 25→60; `skill_mintimepercast_v` (thời gian hồi chiêu, giảm dần): 15\*18→5\*18 tick (~15s→5s); `skill_mintimepercastonhorse_v` (hồi chiêu khi cưỡi ngựa): 20\*18→8\*18; `skill_param1_v` (khoảng cách dịch chuyển tối đa): 120→400 |
| 24 | `feidaotang150` | Vô ảnh Xuyên (150) | Đánh (missile độc, "tuyệt kỹ") | `physicsenhance_p`: 30→360 (lv23=576, lv26=684, mốc phụ lv15=180); `seriesdamage_p`: 40→80 (lv21=82); `poisondamage_v`: 6→38 (lv23=48, lv26=53); `deadlystrike_p`: 12→72 (lv23=90, lv26=100); `skill_cost_v`: 40→80 (lv23=92); `missle_speed_v`: 32→40; `skill_attackradius`: 448→512; kích hoạt skill con id1097 qua `skill_collideevent` |
| 25 | `feidaotang150_2` | Truy Tâm Tỏa Mệnh (150, tầng 2) | Đánh | `seriesdamage_p`: 40→80 (lv21=82); `physicsenhance_p`: 30→140 (lv23=174, lv26=192) |
| 26 | `nutang150` | Thiết Liên Tứ Sát (150) | Đánh (missile độc) | `seriesdamage_p`: 40→80 (lv21=82, mốc phụ lv15=40); `physicsenhance_p`: 18→520 (lv23=856, lv26=1024, mốc phụ lv15=240); `skill_cost_v`: 35→100 (lv23=120); `skill_attackradius`: 448→512; `poisondamage_v`: 1→25 (lv23=32, lv26=36); `missle_lifetime_v`: 18→36; kích hoạt skill con id1098 qua `skill_flyevent` |
| 27 | `nutang150_2` | Thiết Sa Xạ Tinh (150, tầng 2) | Đánh | `seriesdamage_p`: 40→80 (lv21=82); `physicsenhance_p`: 18→180 (lv23=252, lv26=288); `poisondamage_v`: 10→20 (lv23=23) |
| 28 | `biaotang150` | Càn Khôn Nhất Trịch (150) | Đánh (missile độc) | `seriesdamage_p`: 40→80 (lv21=82, mốc phụ lv15=40); `physicsenhance_p`: 12→355 (lv23=637, lv26=778, mốc phụ lv15=120); `deadlystrike_p`: 12→45 (lv23=55, lv26=60); `poisondamage_v`: 1→36 (lv23=47, lv26=52); `missle_speed_v`: 32→32; `skill_attackradius`: 448→512; `skill_cost_v`: 36→90 (lv23=107) |
| 29 | `biaotang150_2` | (bản dự phòng "tầng 2", comment "ko su dung" — không có tên hiển thị riêng đang hoạt động) | Đánh (bản sao rút gọn của #28, thiếu mốc 23/26) | `seriesdamage_p`: 40→80; `physicsenhance_p`: 12→355; `deadlystrike_p`: 12→45; `poisondamage_v`: 1→36; `skill_cost_v`: 36→90 |
| 30 | `biaotang150_3` | (tương tự #29, "ko su dung") | Đánh | Giống hệt #29 (bản dự phòng thứ 2 không dùng) |

**Ghi chú field lạ/chưa chắc nghĩa:**
- `skill_dohurt` (skill #9 `xiaoli_feidao`): không rõ có phải cờ bật/tắt gây sát thương hay một hệ số
  nhân riêng — Skills.txt cũng có cột `DoHurt` (0/1) cùng tên gợi ý liên quan nhưng chưa xác nhận field
  runtime này ánh xạ chính xác thế nào tới cột đó.
- `nomovespeed`/`nomovespeedatt`: giữ nguyên comment gốc của tác giả file (`--what is this?`) — không
  suy đoán thêm, đánh dấu "chưa rõ nghĩa".
- Xác nhận lại 4 field đã nêu ở `vltk_player_stats_reference.md` 10.3 (`physicsenhance_p`,
  `addphysicsdamage_p`, `deadlystrike_p`, `deadlystrikeenhance_p`): đúng và khớp, đã áp dụng nhất quán
  cho toàn bộ bảng trên.

### B.7. Ngũ Độc (wudu.lua)

> Đối chiếu tên tiếng Việt từ `settings/Skills.txt` (cột `SkillName`, mã hoá TCVN3 — đã giải mã
> đúng qua bảng chuyển đổi TCVN3→Unicode chuẩn, xác nhận khớp với tên trong comment `-- Ngu doc...`
> ở lua). Cột SkillId dùng để dò các skill được cộng dồn qua `addskilldamage#` (skill chính buff
> cho skill phụ theo ID). File có 20 block skill chính + phụ. Tất cả field `{{{1,X},{20,Y}}}` đọc
> là "cấp 1: X, cấp 20: Y" (nội suy Line, trừ khi ghi rõ hàm khác như `Conic`).

| # | Biến lua | Tên tiếng Việt (SkillId) | Loại | Field số liệu (lv1 → lv max) |
|---|---|---|---|---|
| 1 | `dusha_zhang` | Độc Sa chưởng (63) | Đánh | `poisondamage_v`: {1:2→20:26} \| {60,60} \| {10,10} (3 sub-field: min/max dmg? + 2 hằng số chưa rõ nghĩa); `seriesdamage_p`: 1→10 (%); `missle_speed_v`: 20→24; `skill_attackradius`: 320→384; `skill_cost_v` (mana cost): 10→10 (không đổi); `addskilldamage1..5`: cộng dồn sát thương cho skill phụ 353 (0→65), 71 (0→35), 1066 (0→54), 1094 (0→54), 1096 (0→54) — dạng `[1]=level bật, [3]=giá trị` |
| 2 | `wudu_daofa` | Ngũ Độc Đao pháp (60) | Bổ trợ (passive vũ khí Đao) | `addphysicsdamage_p`: 20→180 (%), field 2 = -1 (không dùng/mặc định), field 3 = 1→1 (hằng, chưa rõ nghĩa — có thể "loại cộng"); `deadlystrikeenhance_p`: 6→25 (%) |
| 3 | `wudu_zhangfa` | Ngũ Độc Chưởng Pháp (62) | Bổ trợ (passive vũ khí Chưởng) | `addpoisonmagic_v`: 15→45 (cộng công độc), field2 -1 cố định, field3 10 cố định (chưa rõ nghĩa, có vẻ % hoặc flag) |
| 4 | `binglan_xuanjing` | Băng Lam Huyền Tinh (64) | Bổ trợ (kháng) | `coldres_p`: -9→-49 (kháng lạnh, số âm = giảm kháng lạnh ĐỊCH khi trúng?); field2 thời gian hiệu lực 18*20→18*90 tick; `skill_cost_v`: 10→60 |
| 5 | `xuedao_dusha` | Huyết Đao Độc Sát (65) | Đánh | `physicsenhance_p`: 15→65; `seriesdamage_p`: 1→10; `poisondamage_v`: 4→11 \|60,60\|10,10; `addskilldamage1-3`: buff skill 355 (0→60), 74 (0→35), 1067 (0→50); `missle_speed_v`: 20→24; `skill_attackradius`: 320→384; `skill_cost_v`: 20→20 |
| 6 | `zanan_yaojing` | Tạp Nan Dược Kinh (66) | Bổ trợ (kháng độc) | `poisonres_p`: 9→39 (%), field2 -1→-1 cố định |
| 7 | `jiutian_kuanglei` | Cửu Thiên Cuồng Lôi (67) | Bổ trợ (kháng) | `lightingres_p`: -9→-49; thời gian 18*20→18*90; `skill_cost_v`: 10→60 |
| 8 | `youming_kulou` | U Minh Khô Lâu (68) | Đánh | `poisondamage_v`: 11→40 \|60,60\|10,10; `seriesdamage_p`: 5→30; `addskilldamage1-4`: buff 353 (2→85), 1066 (1→70), 1094 (1→70), 1096 (1→70); `missle_speed_v`: 24→28; `skill_attackradius`: 384→448; `skill_cost_v`: 40→40 |
| 9 | `wuxing_gu` (comment: "Vo hinh doc — tạm thời không dùng") | — | Không dùng (disabled) | `poisondamage_v`: 5→25 (3 sub, field2=20 cố định, field3=25 cố định — nhánh `[3]` khác cấu trúc thường, chưa rõ hết nghĩa) |
| 10 | `chiyan_shitian` | Xích Diệm Thực Thiên (70) | Bổ trợ (kháng) | `fireres_p`: -9→-49; thời gian 18*20→18*90; `skill_cost_v`: 10→60 |
| 11 | `chuanxin_duci` | Xuyên Tâm Độc Thích (72) | Bổ trợ (kháng độc, khác zanan_yaojing) | `poisonres_p`: -29→-49 (âm nặng hơn — có thể tự giảm kháng độc bản thân đổi lấy hiệu ứng khác); thời gian 18*20→18*90; `skill_cost_v`: 10→60 |
| 12 | `wangu_shixin` | Vạn Độc Thực Tâm (73) | Bổ trợ | `poisontimereduce_p`: -100→-200 (giảm thời gian hồi độc?/giảm % gì đó, đơn vị chưa rõ — có thể phần nghìn); thời gian 18*45→18*120; `skill_cost_v`: 40→40 |
| 13 | `tiangang_disha` | Thiên Cương Địa Sát (71, cũng dùng lại ID 195 ở bản khác) | Đánh | `seriesdamage_p`: 10→50→52(lv21); `poisondamage_v`: 50→135 \|60,60\|10,10; `addskilldamage1-4`: buff 354 (2→181), 1066 (1→20), 1094 (1→20), 1096 (1→140); `skill_attackradius`: 448→480; `skill_cost_v`: 60→60 |
| 14 | `zhuha_qingming` | Chu Cáp Thanh Minh (74) | Đánh | `seriesdamage_p`: 10→50→52; `physicsenhance_p`: 30→392; `poisondamage_v`: 16→53\|60,60\|10,10; `addskilldamage1-2`: buff 355 (1→60), 1067 (1→50); `missle_speed_v`: 28→32→32; `skill_attackradius`: 448→512→512; `skill_cost_v`: 17→55 |
| 15 | `wudu_qijing` | Ngũ Độc Kỳ Kinh (75) | Bổ trợ (passive tăng công độc + chí mạng) | `addpoisonmagic_v`: 5→100 (từ lv1→lv30, mốc khác 20); `addpoisondamage_v`: 5→45; `poisonenhance_p`: 12→50 (%); `deadlystrikeenhance_p`: 4→45 (%) — đây là skill max lv 30 (khác đa số max 20) |
| 16 | `baidu_chuanxin` | Bách Độc Xuyên Tâm (384) | Đánh | `physicsenhance_p`: 10→95; `seriesdamage_p`: 5→30; `poisondamage_v`: 4→20\|60,60\|10,10; `addskilldamage1-2`: buff 383 (1→70), 1095 (1→58); `missle_speed_v`: 24→28; `skill_attackradius`: 384→448; `skill_cost_v`: 10→32 |
| 17 | `yinfeng_shigu` | Âm Phong Thực Cốt (353) | Đánh (skill 80, có flyevent/collideevent) | `seriesdamage_p`: 20→60→62(lv21), mốc phụ lv15=20; `poisondamage_v`: 20→121 (mốc lv15=50)\|60,60\|10,10; `skill_attackradius`: 448→480→480; `skill_cost_v`: 30→80; `skill_vanishedevent`: kích hoạt skill con 354 khi tan biến; `addskilldamage1-3`: buff 1066/1094/1096 (1→60 mỗi cái); có `skill_skillexp_v` dùng `SkillExpFunc(3540,...)` — công thức exp lên cấp riêng, hệ số a biến thiên 1.15→1.24→1.15 theo cấp (parabol) |
| 18 | `zhuifeng_duji` | Truy Phong Độc Cát (388, comment "ko su dung" = không dùng) | Đánh (disabled) | `seriesdamage_p`: 20→60→62; `poisondamage_v`: 1→15\|60,60\|10,10 |
| 19 | `tiangang_dushou` | Thiên Cương Độc Thủ (354) | Đánh | `seriesdamage_p`: 20→60→62; `poisondamage_v`: 1→15 (chú ý field2 ghi `{1,80}` khác các skill khác thường là 60 — TCVN3 gốc: có thể lỗi data gốc)\|10,10 |
| 20 | `xuanyin_zhan` | Huyền Âm Trảm (355) | Đánh (skill 80) | `seriesdamage_p`: 20→60→62 (mốc lv15=20); `physicsenhance_p`: 15→173 (mốc lv15=80); `poisondamage_v`: 20→60 (mốc lv15=30)\|60,60\|10,10; `missle_speed_v`: 28→32→40; `skill_attackradius`: 448→512→512; `skill_cost_v`: 30→60; `addskillexp1`+`skill_skillexp_v` dùng `SkillExpFunc(5000,...)`; `addskilldamage1`: buff 1067 (1→32); có `skill_collideevent` kích hoạt skill con 383 |
| 21 | `xingkong_po` | Tinh Không Phá (383) | Đánh | `seriesdamage_p`: 20→60→62; `poisondamage_v`: 1→10\|60,60\|10,10 |
| 22 | `duanjin_fugu` | Đoạn Cân Hủ Cốt (390) | Bổ trợ (giảm toàn kháng địch) | `allres_p`: -1→-40 (giảm toàn bộ kháng); thời gian 18*20→18*90; `skill_cost_v`: 60→120 |
| 23 | `chuanyi_pojia` | Xuyên Y Phá Giáp (356) | Bổ trợ (giảm kháng vật lý địch) | `physicsres_p`: -9→-49; thời gian 18*20→18*90; `skill_cost_v`: 10→60 |
| 24 | `wudu120` | Hấp Tinh Yểm (711, skill 120) | Bổ trợ (passive proc tự động) | `autoattackskill`: xác suất/level kích hoạt skill con 719 khi đánh thường (mức 1→20→21); `autoattackskillplus`: % xác suất 1→15(lv15)→15 và thời gian chờ `10*18` tick (~10s); có `skill_desc` hàm mô tả bằng tiếng Việt bị lỗi font (garbled do double-encode gốc, nội dung: "Xác suất X% khiến cho đối thủ trúng độc, đồng thời làm giảm X% nội lực đối phương trong X giây, X giây sau mỗi lượt tiếp tục thi triển tiếp" — diễn giải từ ngữ cảnh, KHÔNG phải bản dịch chính xác 100% vì bytes gốc lỗi) |
| 25 | `wudu120zuzhou` | Hấp Tinh Yểm_Quyết Chú (719 — skill phụ do 711 kích hoạt) | Bổ trợ (debuff) | `poison2decmana_p`: xác suất 30→80→85→85 (%), thời gian hiệu lực 3*18→5*18→6*18→6*18 tick (giây×18) — giảm nội lực (mana) đối phương theo % |
| 26 | `zhangwudu150` | Hình Tiêu Cốt Lập (1066, skill 150) | Đánh | `seriesdamage_p`: 40→80→82 (mốc lv15=40); `poisondamage_v`: 25→215 (mốc lv15=100, lv23=353, lv26=422)\|60,60\|10,10; `skill_attackradius`: 448→480→480; `skill_cost_v`: 35→100→120(lv23); `skill_eventskilllevel` — comment ghi "startevent: 1094" (liên kết tới skill 1094 khi bắt đầu) |
| 27 | `zhangwudu150_2` | (skill phụ "chuong 150 tang 2" — không có tên riêng trong Skills.txt tách biệt, là tầng 2 của Hình Tiêu Cốt Lập) | Đánh | `seriesdamage_p`: 40→80→82; `poisondamage_v`: 1→25\|60,60\|10,10 |
| 28 | `daowudu150` | U Hồn Phệ ảnh (1067, skill 150) | Đánh | `seriesdamage_p`: 40→80→82 (lv15=40); `physicsenhance_p`: 18→208 (lv15=95, lv23=343, lv26=411); `poisondamage_v`: 24→144 (lv15=72, lv23=230, lv26=273)\|60,60\|10,10; `missle_speed_v`: 28→30→30; `skill_attackradius`: 448→512→512; `skill_cost_v`: 36→72→83(lv23); `skill_collideevent` kích hoạt skill con 1095 |
| 29 | `daowudu150_2` | Hồn ảnh Tùng Sanh (1095/1232 — tầng 2 của U Hồn Phệ ảnh) | Đánh | `seriesdamage_p`: 40→80→82; `poisondamage_v`: 1→12(lv20)→15(lv23)\|60,60\|10,10 |

**Field mới xuất hiện chỉ ở Ngũ Độc (so với môn phái khác đã ghi ở A.4):**
- `poisondamage_v`, `poisonres_p`, `poisontimereduce_p`, `addpoisonmagic_v`, `addpoisondamage_v`,
  `poisonenhance_p`, `poison2decmana_p` — nhóm "độc" (poison) chuyên biệt của Ngũ Độc. Cấu trúc
  `poisondamage_v` luôn có 3 sub-array: sub1 = damage min→max theo cấp, sub2 = hằng số 60 (chưa rõ
  nghĩa, có thể % thời gian tick hoặc số tick cố định), sub3 = hằng số 10 (chưa rõ nghĩa, nghi là số
  lần tick hoặc mili-giây/tick).
- `poison2decmana_p`: giảm mana đối phương dạng % theo xác suất trúng độc — field1 = % xác suất,
  field2 = thời gian (đơn vị tick, 18 tick = 1 giây theo quy ước toàn file — xem `*18` lặp lại khắp
  nơi).

### B.8. Thiên Vương (tianwang.lua)

> Môn phái dùng vũ khí Thương/Đao/Chùy, thiên về vật lý thuần (`physicsenhance_p`,
> `attackrating_p`, `deadlystrike_p`, `ignoredefense_p`) — KHÔNG có field nguyên tố (fire/cold/
> lighting/poison) nào xuất hiện trong toàn bộ file (khác Ngũ Độc/Thiên Nhẫn/Thúy Yên).

| # | Biến lua | Tên tiếng Việt (SkillId) | Loại | Field số liệu (lv1 → lv max) |
|---|---|---|---|---|
| 1 | `zhanlong_jue` | Trảm Long quyết (29) | Đánh | `physicsenhance_p`: 80→185; `ignoredefense_p`: 5→20 (% xuyên giáp); `seriesdamage_p`: 1→10; `deadlystrike_p`: 6→10; `addskilldamage1-6`: buff skill 325 (1→50), 408 (1→50), 324 (1→35), 407 (1→35), 1059 (1→41), 1087 (1→41); `missle_speed_v`: 18→18 (không đổi); `missle_lifetime_v`: 4→4; `skill_attackradius`: 54→54; `skill_cost_v`: 2→6 |
| 2 | `tianwang_qiangfa` | Thiên Vương Thương pháp (23) | Bổ trợ (passive vũ khí Thương) | `addphysicsdamage_p`: 25→315, field3=3→3; `attackratingenhance_p`: 75→270; `deadlystrikeenhance_p`: 2→15 |
| 3 | `tianwang_daofa` | Thiên Vương Đao pháp (24) | Bổ trợ (passive vũ khí Đao) | `addphysicsdamage_p`: 50→300, field3=1→1; `attackratingenhance_p`: 15→72; `deadlystrikeenhance_p`: 2→15 |
| 4 | `tianwang_chuifa` | Thiên Vương Chùy Pháp (26) | Bổ trợ (passive vũ khí Chùy) | `addphysicsdamage_p`: 25→275, field3=4→4; `attackratingenhance_p`: 15→72; `deadlystrikeenhance_p`: 2→15 |
| 5 | `huifeng_luoyan` | Hồi Phong Lạc Nhạn (30) | Đánh | `seriesdamage_p`: 1→10; `physicsenhance_p`: 80→215; `attackrating_p`: 10→147; `addskilldamage1-6`: buff 323 (1→60), 327 (1→60), 41 (1→15), 225 (1→35), 1060 (1→50), 1088 (1→50); `missle_speed_v`: 18→18; `skill_attackradius`: 54→54; `skill_cost_v`: 4→10 |
| 6 | `xingyun_jue` | Hàng Vân Quyết (31) | Đánh | `physicsenhance_p`: 30→255; `ignoredefense_p`: 10→35; `seriesdamage_p`: 5→30; `deadlystrike_p`: 8→20; `addskilldamage1-4`: buff 325 (1→55), 408 (1→55), 1059 (1→45, lv25=78, lv29=96), 1087 (tương tự); `missle_speed_v`: 22→22; `skill_attackradius`: 66→66; `skill_cost_v`: 3→7 |
| 7 | `wuxin_zhan` | Vô Tâm Trảm (32) | Đánh (skill 60) | `physicsenhance_p`: 65→453; `seriesdamage_p`: 10→50→52; `deadlystrike_p`: 4→25; `addskilldamage1-5`: buff 322 (1→80), 326 (1→80), 1058 (1→67), 1086 (1→67), 1084 (1→67); `missle_speed_v`: 26→26; `skill_attackradius`: 78→78; `skill_cost_v`: 10→20 |
| 8 | `jingxin_jue` | Tĩnh Tâm Quyết (33) | Bổ trợ | `attackratingenhance_p`: 45→400; thời gian 18*120→18*180; `skill_cost_v`: 5→20 |
| 9 | `jinglei_zhan` | Kinh Lôi Trảm (34) | Đánh | `physicsenhance_p`: 40→200; `seriesdamage_p`: 1→10; `addskilldamage1-7`: buff 322 (1→60), 326 (1→60), 32 (1→35), 220 (1→35), 1058 (1→50), 1086 (1→50), 1084 (1→50); `missle_speed_v`: 18→18; `skill_attackradius`: 54→54; `skill_cost_v`: 5→10 |
| 10 | `yangguan_sandie` | Dương Quan Tam Điệp (35) | Đánh | `physicsenhance_p`: 130→375; `seriesdamage_p`: 5→30; `attackrating_p`: 10→180; `addskilldamage1-4`: buff 323 (1→65), 327 (1→65), 1060 (1→54, lv25=88, lv29=98), 1088 (tương tự); `missle_speed_v`: 22→22; `skill_attackradius`: 66→66; `skill_cost_v`: 9→16 |
| 11 | `tianwang_zhanyi` | Thiên Vương Chiến ý (36, max lv 30) | Bổ trợ (passive HP + chí mạng) | `lifemax_p`: 21→185 (% HP tối đa, lv max=30); `deadlystrikeenhance_p`: 5→45; (2 dòng `attackspeed_v`/`skill_cost_v` bị comment-out — không active) |
| 12 | `pofeng_zhan` | Bát Phong Trảm (37) | Đánh | `physicsenhance_p`: 120→275; `seriesdamage_p`: 5→30; `addskilldamage1-5`: buff 322 (1→70), 326 (1→70), 1058 (1→58, lv25=92, lv27=98), 1086 (tương tự), 1084 (tương tự); `missle_speed_v`: 22→22; `skill_attackradius`: 66→66; `skill_cost_v`: 8→12 |
| 13 | `duanhun_ci` | Đoạn Hồn Thích (40) | Đánh (có hiệu ứng khống chế) | `physicsenhance_p`: 25→215; `seriesdamage_p`: 1→50 (comment "plus"); `stun_p`: 16→35 (% choáng), field2=5→18 (thời gian choáng?); `skill_param1_v`: cố định 31 mọi cấp (chưa rõ nghĩa — có thể ID hiệu ứng trạng thái); `skill_param2_v`: cố định 1 (chưa rõ nghĩa); `deadlystrike_p`: 4→80; `missle_speed_v`: 22→30→30; `skill_attackradius`: 22*16→30*16→30*16 (352→480→480); `skill_cost_v`: 10→20 |
| 14 | `xuezhan_bafang` | Huyết Chiến Bát Phương (41) | Đánh (skill 60) | `physicsenhance_p`: 60→723; `seriesdamage_p`: 10→50→52; `attackrating_p`: 75→320; `deadlystrike_p`: 4→25; `addskilldamage1-4`: buff 323 (1→70), 327 (1→70), 1060 (1→58), 1088 (1→58); `missle_speed_v`: 26→26; `skill_attackradius`: 78→78; `skill_cost_v`: 11→45 |
| 15 | `jinzhong_zhao` | Kim Chung Tráo (42) | Bổ trợ (kháng đa nguyên tố) | `physicsres_p`: 12→50; `coldres_p`: 7→45; `fireres_p`: -5→-15 (âm — GIẢM kháng lửa, khác 2 field trên); thời gian 18*120→18*180 (riêng fireres cùng thời gian); `skill_cost_v`: 12→40 |
| 16 | `chenglong_jue` | Thừa Long Quyết (324/407) | Đánh (skill 60) | `physicsenhance_p`: 40→495; `ignoredefense_p`: 38→80→82; `seriesdamage_p`: 10→50→52; `deadlystrike_p`: 5→40; `addskilldamage1-4`: buff 325 (1→60), 408 (1→60), 1059 (1→50), 1087 (1→50); `missle_speed_v`: 26→26; `skill_attackradius`: 78→78; `skill_cost_v`: 10→16 |
| 17 | `potian_zhan` | Phá Thiên Trảm (322/326, skill 80 — có bản max lv60 riêng ID 1536) | Đánh | `physicsenhance_p`: 35→338 (lv15=150); `seriesdamage_p`: 20→60→62 (lv15=20); `deadlystrike_p`: 4→25; `attackrating_p`: 35→215; `missle_speed_v`: 30→30; `skill_attackradius`: 90→90; `skill_cost_v`: 15→30; `addskillexp1`+`skill_skillexp_v` dùng `SkillExpFunc(7280,1.25,...)`; `addskilldamage1-3`: buff 1058 (1→35), 1086 (1→35), 1084 (1→35) |
| 18 | `zhuixing_zhuyue` | Truy Tinh Trục Nguyệt (323/327) | Đánh | `physicsenhance_p`: 50→381 (lv15=200); `seriesdamage_p`: 20→60→62 (lv15=20); `attackrating_p`: 95→360; `deadlystrike_p`: 4→25; `missle_speed_v`: 30→30; `skill_attackradius`: 90→90; `skill_cost_v`: 10→65; `skill_skillexp_v` dùng `SkillExpFunc(6550,1.25,...)`; `addskilldamage1-2`: buff 1060 (1→45), 1088 (1→45) |
| 19 | `zhuifeng_jue` | Truy Phong Quyết (325/408) | Đánh | `physicsenhance_p`: 25→200 (lv15=140, dòng comment cũ ghi 380 nhưng đã sửa còn 200); `seriesdamage_p`: 20→60→62 (lv15=20); `ignoredefense_p`: 12→90 (lv21=94, lv22=98, lv23=99, lv24=99 — bão hoà dần); `deadlystrike_p`: 5→40; `missle_speed_v`: 30→30; `skill_attackradius`: 90→90; `skill_cost_v`: 10→30; `skill_skillexp_v` dùng `SkillExpFunc(7750,1.25,...)`; `addskilldamage1-2`: buff 1059 (1→42), 1087 (1→42) |
| 20 | `daoxutian` | Đảo Hư Thiên (708, skill 120) | Bổ trợ (buff toàn diện) | `allres_p`: 1→10→10(lv21), field2=-1 cố định; `allresmax_p`: 1→5→5; `lifereplenish_p`: 1→35(lv15=30)→36 (hồi máu %); `ignoreskill_p`: 5→89 (lv15=79) — có thể "kháng hiệu ứng skill địch"; `skill_skillexp_v` dùng bảng số cố định lớn (không qua SkillExpFunc) |
| 21 | `daotianwang150` | Hào Hùng Trảm (1058/1086/1084, skill 150) | Đánh | `physicsenhance_p`: 45→405 (lv15=180, lv23=675, lv26=810); `seriesdamage_p`: 40→80→82 (lv15=40); `deadlystrike_p`: 5→30 (lv23=37, lv26=41); `attackrating_p`: 35→215 (lv23=271, lv26=300); `missle_speed_v`: 36→36; `missle_lifetime_v`: 8→8; `skill_attackradius`: 280→280; `skill_cost_v`: 20→35→39(lv23); `skill_collideevent` kích hoạt skill con 1086 |
| 22 | `qiangtianwang150` | Bá Vương Tạm Kim (1060/1088, skill 150) | Đánh | `physicsenhance_p`: 60→460 (lv15=240, lv23=724, lv26=856); `seriesdamage_p`: 40→80→82; `attackrating_p`: 95→360 (lv23=443, lv26=485); `deadlystrike_p`: 5→30 (lv23=37, lv26=41); `missle_speed_v`: 36→36; `missle_lifetime_v`: 3→3; `skill_attackradius`: 108→108; `skill_cost_v`: 12→80→101(lv23) |
| 23 | `chuitianwang150` | Tung Hoành Bát Hoang (1059/1087, skill 150) | Đánh | `physicsenhance_p`: 30→455 (lv15=210, lv23=749, lv26=896); `seriesdamage_p`: 40→80→82; `ignoredefense_p`: 12→90 (lv21=94...lv24=99, bão hoà); `deadlystrike_p`: 5→50 (lv23=64, lv26=71); `missle_speed_v`: 32→32; `skill_attackradius`: 108→108; `skill_cost_v`: 12→36→43(lv23) |

**Ghi chú riêng Thiên Vương:** đây là môn phái vật lý thuần, không dùng field nguyên tố nào —
khác hẳn Ngũ Độc (poison), Thiên Nhẫn (fire), Thúy Yên (cold). Skill 1536 "Phá Thiên Trảm" (max lv
60, req lv 1 theo Skills.txt) không xuất hiện trực tiếp trong lua với tên biến riêng — có thể dùng
chung block `potian_zhan` qua cơ chế nội suy mở rộng ở C++ (không xác nhận được từ lua thuần).

### B.9. Thiên Nhẫn (tianren.lua)

> Môn phái dùng Đao/Mâu/Chùy, thiên về Hỏa (`firedamage_v`, `addfiremagic_v`, `addfiredamage_v`,
> `fireenhance_p`) kết hợp vật lý. Có 2 skill đặc thù hút máu/hút mana (`steallife_p`,
> `stealmana_p`) không thấy ở 3 môn phái kia trong tài liệu này.

| # | Biến lua | Tên tiếng Việt (SkillId) | Loại | Field số liệu (lv1 → lv max) |
|---|---|---|---|---|
| 1 | `canyang_ruxue` | Tàn Dương Như Huyết (135) | Đánh | `seriesdamage_p`: 1→10; `physicsenhance_p`: 5→55; `firedamage_v`: sub1=sub3=5→50 (2 sub giống hệt nhau — nghi field1=min, field3=max cùng giá trị vì đây damage cố định không phải khoảng); `addskilldamage1-3`: buff 361 (1→45), 142 (1→35), 1075 (1→38); `missle_speed_v`: 20→24; `skill_attackradius`: 320→384; `skill_cost_v`: 8→8 (không đổi) |
| 2 | `tianren_daofa` | Thiên Nhẫn Đao pháp (131) | Bổ trợ (passive vũ khí Đao) | `addfiremagic_v`: 15→215 (cộng công hỏa), field2=-1 cố định |
| 3 | `tianren_maofa` | Thiên Nhẫn Mâu pháp (132) | Bổ trợ (passive vũ khí Mâu) | `addphysicsdamage_p`: 15→215, field3=3→3; `attackratingenhance_p`: 35→272; `deadlystrikeenhance_p`: 6→35 |
| 4 | `huolian_fenhua` | Hỏa Liên Phần Hoa (136) | Bổ trợ (phản đòn cận chiến) | `meleedamagereturn_p`: -5→-35 (số âm — % phản lại/giảm sát thương nhận từ cận chiến); thời gian 18*40→18*120; `skill_cost_v`: 12→12 |
| 5 | `huanying_feihu` | ảo ảnh Phi Hồ (137) | Bổ trợ (debuff né/giảm chính xác địch) | `attackratingenhance_p`: -15→-132 (âm — giảm attack rating, có thể của bản thân đổi lấy né hoặc debuff mục tiêu); thời gian 18*40→18*120; `skill_cost_v`: 20→20 |
| 6 | `tuishan_tianhai` | Thôi sơn Điền Hải (138) | Đánh | `seriesdamage_p`: 5→30; `firedamage_v`: 5→45 (cả 2 sub); `addskilldamage1-2`: buff 362 (1→115), 1076 (1→95); `skill_cost_v`: 32→50 |
| 7 | `feihong_wuji` | Phi Hồng Vô Tích (140) | Bổ trợ (giảm phòng thủ địch, số âm lớn) | `adddefense_v`: -150→-1100; thời gian 18*40→18*120; `skill_cost_v`: 25→25 |
| 8 | `liehuo_qingtian` | Liệt Hỏa Tình Thiên (141) | Đánh | `seriesdamage_p`: 5→30; `physicsenhance_p`: 15→75; `firedamage_v`: 8→150 (cả 2 sub); `addskilldamage1-2`: buff 361 (1→55), 1075 (1→45); `missle_speed_v`: 24→28; `skill_attackradius`: 384→448; `skill_cost_v`: 25→25 |
| 9 | `toutian_huanri` | Thâu Thiên Hoán Nhật (142, skill 60) | Đánh (có hút máu/mana) | `seriesdamage_p`: 10→50→52; `physicsenhance_p`: 25→231; `deadlystrike_p`: 4→55; `firedamage_v`: 10→482 (cả 2 sub); `addskilldamage1-2`: buff 361 (1→65), 1075 (1→54); `steallife_p`: 1→8 (% hút máu); `stealmana_p`: 1→6 (% hút mana); `missle_speed_v`: 26→26; `missle_lifetime_v`: 4→4; `skill_attackradius`: 78→78; `skill_cost_v`: 12→20 |
| 10 | `limo_duopo` | Lịch Ma Đoạt Hồn (143) | Bổ trợ (giảm vật lý địch, số âm) | `addphysicsdamage_p`: -25→-215, field3=6→6; thời gian 18*40→18*120; `skill_cost_v`: 30→30 |
| 11 | `tanzhi_lieyan` | Đơn Chỉ Liệt Diệm (145) | Đánh | `firedamage_v`: 30→225 (cả 2 sub); `seriesdamage_p`: 1→10; `addskilldamage1-3`: buff 362 (1→100), 148 (1→35), 1076 (1→83); `missle_speed_v`: 20→24; `skill_attackradius`: 320→384; `skill_cost_v`: 20→30 |
| 12 | `wuxing_zhen` | Ngũ hành trận (146/226, comment "khong su dung" = không dùng) | Bổ trợ (disabled) | `adddefense_v`: 75→550, field2=18→18 (cố định, chưa rõ nghĩa — có lẽ hằng thời gian tính theo tick nhưng không nhân theo cấp) |
| 13 | `moyan_qisha` | Ma Diệm Thất Sát (148, skill 60) | Đánh | `seriesdamage_p`: 10→50→52; `firedamage_v`: 35→637 (cả 2 sub); `addskilldamage1-2`: buff 363 (1→87), 1076 (1→72); `fatallystrike_p`: 12→50 (% chí mạng/tử thương); `missle_speed_v`: 20→24→24; `skill_attackradius`: 320→384; `skill_cost_v`: 20→30 |
| 14 | `tianmo_jieti` | Thiên Ma Giải Thể (150, max lv 30) | Bổ trợ (buff toàn diện lớn) | `adddefense_v`: 75→850; `attackratingenhance_p`: 65→500; `fasthitrecover_v`: 5→40 (hồi chiêu nhanh hơn — % giảm cooldown?); `addfiremagic_v`: 20→315; `addfiredamage_v`: 20→315; `fireenhance_p`: 31→100 (%); `attackspeed_v`: 26→102; `castspeed_v`: 26→81; tất cả thời gian hiệu lực 18*120→18*360; `skill_cost_v`: 100→100 (dòng `lifemax_p` bị comment-out, không active) |
| 15 | `beisu_qingfeng` | Bi Tô Thanh Phong (364) | Bổ trợ (giảm hồi chiêu địch, số âm) | `fasthitrecover_v`: -6→-30; thời gian 18*40→18*120; `skill_cost_v`: 20→20 |
| 16 | `yunlong_ji` | Vân Long Kích (361, skill 80) | Đánh (hút máu/mana, có skill exp riêng) | `physicsenhance_p`: 45→445; `seriesdamage_p`: 20→60→62 (lv15=20); `deadlystrike_p`: 4→65; `firedamage_v`: 6→378 (lv15=100, cả 2 sub); `addskilldamage1`: buff 1075 (1→30); `steallife_p`: 1→16; `stealmana_p`: 1→16; `missle_speed_v`: 30→30; `skill_attackradius`: 90→90; `skill_cost_v`: 30→30; `skill_skillexp_v` dùng `SkillExpFunc(11600,1.15,...)` |
| 17 | `fenghuo_liantian` | Phong Hỏa Liên Thiên (378, comment "khong su dung") | Đánh (disabled) | `seriesdamage_p`: 20→60; `firedamage_v`: 5→40 (cả 2 sub) |
| 18 | `tianwai_liuxing` | Thiên Ngoại Lưu Tinh (362, skill 80) | Đánh | `seriesdamage_p`: 20→60→62 (lv15=20); `firedamage_v`: 11→462 (lv15=200, cả 2 sub); `skill_attackradius`: 448→480→480; `skill_cost_v`: 20→50; `skill_vanishedevent` kích hoạt skill con 363; `addskilldamage1`: buff 1076 (1→55); `skill_skillexp_v` dùng `SkillExpFunc(4085,1.15,...)` |
| 19 | `yehuo_fencheng` | Nghiệp Hỏa Phần Thành (363) | Đánh | `seriesdamage_p`: 20→60→62 (comment "plus"); `firedamage_v`: 21→320 (cả 2 sub) |
| 20 | *(block `moyan_zaitian` bị comment-out toàn bộ trong file — Ma Diệm Tại Thiên (379) không có dữ liệu active, chỉ còn trong Skills.txt)* | Ma Viêm Tại Thiên (379) | — | Không tìm thấy dữ liệu active trong lua (toàn bộ block bị `--` comment) |
| 21 | `shehun_luanxin` | Nhiếp Hồn Loạn Tâm (391) | Bổ trợ (debuff đa hiệu ứng, toàn số âm) | `attackratingenhance_p`: -12→-128; `adddefense_v`: -80→-800; `addphysicsdamage_p`: -15→-215, field3=6→6; `fasthitrecover_v`: -6→-30; `lifereplenish_v`: -1→-15; `deadlystrikeenhance_p`: -6→-35; thời gian chung 18*40→18*120; `skill_cost_v`: 60→120 |
| 22 | `tianren120` | Ma Âm Phệ Phách (715, skill 120) | Bổ trợ (passive proc gây hoảng loạn) | `skill_cost_v`: 25→80→80; `skill_mintimepercastonhorse_v`/`skill_mintimepercast_v`: cooldown 45*18→20*18→20*18 tick (giảm dần theo cấp = hồi chiêu nhanh hơn); `autodeathskill`: kích hoạt skill con 723 khi bị đánh chết (41→60→60 = % xác suất?); `skill_desc` mô tả (dịch từ nội dung, có lỗi font gốc): "Thời gian khôi phục chiêu thức: X giây; Thời gian khôi phục chiêu thức trên ngựa: X giây; Xác suất X% khiến cho tối đa N mục tiêu gần bị hoảng loạn trong X giây; Sau khi chết có xác suất 100% khiến tối đa N mục tiêu gần bị hoảng loạn trong X giây; Trong lúc hoảng loạn không thể tấn công và di chuyển" |
| 23 | `quntisuijizoudong` | Quyết Chú Hoảng Loạn (723 — skill phụ do 715 kích hoạt) | Bổ trợ (CC — khống chế) | `randmove`: field1 cố định 1, field2 thời gian di chuyển ngẫu nhiên 1*18→4*18→4*18 tick (có breakpoint lv40/41/55/60/61 riêng); `missle_missrate`: 65→15→15 (tỷ lệ trượt giảm dần = dễ trúng hơn theo cấp, có breakpoint lv40=15, lv41=0, lv60=0); `missle_hitcount`: cố định 6 (số mục tiêu trúng đòn) |
| 24 | `zhanren150` | Giang Hải Nộ Lan (1075, skill 150, hút máu/mana) | Đánh | `physicsenhance_p`: 55→535 (lv23=686, lv26=762); `seriesdamage_p`: 40→80→82 (lv15=40); `deadlystrike_p`: 6→80 (lv23=103, lv26=115); `firedamage_v`: 10→455 (lv15=120, lv23=857, lv26=1058, cả 2 sub); `steallife_p`/`stealmana_p`: 1→16 (lv23=20, lv26=23); `missle_speed_v`: 40→40; `missle_lifetime_v`: 12→12; `skill_attackradius`: 198→198; `skill_cost_v`: 36→36 (không đổi); `randmove`+`missle_missrate`: cơ chế phụ (xem `skill_desc`: "Tăng thêm hình thức thứ hai Ma Âm Kích với X% tỷ lệ khiến đối phương khiếp sợ X giây"); `skill_startevent` kích hoạt skill con 1131 (Ma Âm Kích) |
| 25 | `moren150` | Tật Hỏa Liệu Nguyên (1076, skill 150) | Đánh | `seriesdamage_p`: 40→80→82 (lv15=40); `firedamage_v`: 45→760 (lv23=985, lv26=1098, cả 2 sub); `fatallystrike_p`: 10→30; `missle_speed_v`: 0→0 (không di chuyển — có thể là AoE tại chỗ); `skill_attackradius`: 448→480; `skill_cost_v`: 25→36→39(lv23) |

### B.10. Thúy Yên (cuiyan.lua)

> Môn phái dùng Đao/Kiếm, thiên về Băng/Lạnh (`colddamage_v`, `addcoldmagic_v`, `addcolddamage_v`,
> `coldenhance_p`). Có skill hồi máu (`lifereplenish_v`) và skill tốc độ di chuyển/đánh
> (`attackspeed_v`, `castspeed_v`, `fastwalkrun_p`) — không thấy ở 3 môn phái kia trong tài liệu này.

| # | Biến lua | Tên tiếng Việt (SkillId) | Loại | Field số liệu (lv1 → lv max) |
|---|---|---|---|---|
| 1 | `fenghua_xueyue` | Phong Hoa Tuyết Nguyệt (99) | Đánh | `physicsenhance_p`: 5→85; `seriesdamage_p`: 1→10; `addskilldamage1-4`: buff 336 (1→55), 108 (1→35), 1063 (1→45), 1064 (1→45); `colddamage_v`: sub1=5→80, sub3=5→150 (khác nhau — có thể sub1=phòng thủ vật thường, sub3=phòng thủ pháp/skill, hoặc min/max thật sự khác biệt); `missle_speed_v`: 20→24; `skill_attackradius`: 320→384; `skill_cost_v`: 10→10 |
| 2 | `cuiyan_daofa` | Thúy Yên Đao pháp (95) | Bổ trợ (passive vũ khí Đao) | `addphysicsdamage_p`: 45→215, field3=1→1; `deadlystrikeenhance_p`: 6→35 — **dùng hàm nội suy `Conic` thay vì `Line` mặc định** (field3 = `Conic` literal trong mảng thứ 2 của point cuối) — parabol thay vì tuyến tính |
| 3 | `cuiyan_shuangdao` | Thúy Yên Song đao (97) | Bổ trợ (passive) | `addcoldmagic_v`: 20→215 (cộng công lạnh) |
| 4 | `huti_hanbing` | Hộ Thể Hàn Băng (100) | Bổ trợ (phản đòn cả cận chiến+tầm xa) | `meleedamagereturn_p`: 5→20; `rangedamagereturn_p`: 5→20; thời gian cùng 18*120→18*120 (không đổi theo cấp); `skill_cost_v`: 40→60 |
| 5 | `fengjuan_canxue` | Phong Quyển Tàn Tuyết (102) | Đánh | `seriesdamage_p`: 1→10; `colddamage_v`: sub1=10→75(comment "plus"), sub3=10→125(comment "plus"); `physicsdamage_v`: sub1=25→235, sub3=25→375; `addskilldamage1-4`: buff 337 (1→115), 111 (1→35), 1065 (1→95), 1093 (1→95); `missle_speed_v`: 20→24; `skill_attackradius`: 320→384; `skill_cost_v`: 20→20 |
| 6 | `bingxin_qianying` | Băng Tâm Trái ảnh (269) | Bổ trợ (hồi máu) | `lifereplenish_v`: 130→700 (hồi máu theo giá trị tuyệt đối, không phải %); field2=8→8 cố định (chưa rõ nghĩa — có thể chu kỳ tick giây); `skill_cost_v`: 21→40 |
| 7 | `yuda_lihua` | Vũ Đả Lê Hoa (105/189) | Đánh | `physicsenhance_p`: 10→140; `seriesdamage_p`: 5→30; `addskilldamage1-2`: buff 382 (15→50 — chú ý field1 khởi điểm 15, không phải 1), 1064 (1→42); `colddamage_v`: sub1=10→100, sub3=10→250; `skill_attackradius`: 384→448; `skill_cost_v`: 20→30 |
| 8 | `xueying` | Tuyết ảnh (109) | Bổ trợ (tốc độ) | `attackspeed_v`: 12→65; `castspeed_v`: 12→65; `fastwalkrun_p`: 17→55 (% tăng tốc chạy); thời gian chung 18*120→18*180; `skill_cost_v`: 40→140 |
| 9 | `taxue_wuhen` | Đạp Tuyết Vô Ngân (270, comment "ko su dung" = không dùng) | Bổ trợ (disabled — toàn bộ nội dung bị comment) | Không có field active |
| 10 | `muye_liuxing` | Mục Dã Lưu Tinh (108/190, skill 60) | Đánh | `seriesdamage_p`: 10→50→52; `physicsenhance_p`: 30→271; `colddamage_v`: sub1=20→246, sub3=20→426; `addskilldamage1-3`: buff 336 (1→60), 1063 (1→50), 1064 (1→50); `skill_attackradius`: 448→480→480; `skill_cost_v`: 30→40 |
| 11 | `fuyun_sanxue` | Phù Vân Tán Tuyết (113) | Đánh | `colddamage_v`: sub1=40→375, sub3=40→575; `physicsdamage_v`: sub1=sub3=10→135 (comment "plus" cả 2); `seriesdamage_p`: 5→30; `addskilldamage1-3`: buff 338 (1→100), 1065 (1→83), 1093 (1→83); `skill_attackradius`: 384→416; `skill_cost_v`: 50→50 (không đổi) |
| 12 | `bihai_chaosheng` | Bích Hải Triều Sinh (111, skill 60) | Đánh | `seriesdamage_p`: 10→50→52; `physicsdamage_v`: sub1=sub3=20→200; `colddamage_v`: sub1=43→704, sub3=43→1214; `addskilldamage1`: buff 337 (2→70); `addskilldamage3-4`: buff 1065 (1→58), 1093 (1→58) (chú ý `addskilldamage2` bị comment-out — không active); `skill_cost_v`: 65→65 (không đổi) |
| 13 | `binggu_xuexin` | Băng Cốt Tuyết Tâm (114, max lv 30) | Bổ trợ (passive tổng hợp công lạnh + chí mạng + hồi chiêu) | `addcoldmagic_v`: 60→315; `addcolddamage_v`: 30→275; `addphysicsmagic_v`: 30→275; `fasthitrecover_v`: 3→49; `deadlystrikeenhance_p`: 5→45 (dùng hàm `Conic` ở điểm cuối, giống `cuiyan_daofa`); `coldenhance_p`: 8→80 (%) |
| 14 | `bingzong_wuying` | Băng Tung Vô ảnh (336, skill 80, có skill exp riêng) | Đánh | `physicsenhance_p`: 15→524 (lv15=350, dòng cũ bị comment ghi 146 — đã tăng lên 524); `seriesdamage_p`: 20→60→62 (lv15=20); `colddamage_v`: sub1=10→173 (lv15=140), sub3=50→276 (lv15=200); `missle_speed_v`: 20→24→24; `skill_attackradius`: 448→512→512; `skill_cost_v`: 40→60; `skill_misslenum_v`: số đạn 1→5→5 (lv5=1); `addskilldamage1-2`: buff 1063 (1→120), 1064 (1→120); `skill_collideevent` kích hoạt skill con 382; `skill_skillexp_v` dùng `SkillExpFunc(8000,...)` với hệ số Time/Range biến thiên theo mốc cấp (1→1.5→2→3→4) |
| 15 | `bingxin_yuling` | Băng Tâm Ngọc Lăng (381/189, comment "ko su dung" = không dùng) | Đánh (disabled) | `seriesdamage_p`: 20→60→62; `physicsenhance_p`: 15→115; `colddamage_v`: sub1=sub3=10→440; `skill_collideevent` kích hoạt skill con 382 (vẫn còn định nghĩa dù skill chính không dùng) |
| 16 | `bingxin_xuelian` | Băng Tâm Tuyết Liên (382/190) | Đánh | `seriesdamage_p`: 20→60→62; `colddamage_v`: sub1=sub3=10→220 (dòng `physicsenhance_p` bị comment-out) |
| 17 | `bingxin_xianzi` | Băng Tâm Tiên Tử (337, skill 80, có skill exp riêng) | Đánh | `seriesdamage_p`: 20→60→62 (lv15=20); `physicsdamage_v`: sub1=sub3=5→558 (lv15=100); `colddamage_v`: sub1=sub3=15→581 (lv15=240); `missle_speed_v`: 28→32→32; `skill_attackradius`: 448→512→512; `skill_cost_v`: 45→75; `skill_flyevent` kích hoạt skill con 338 khi bay; `addskilldamage1-2`: buff 1065 (1→45), 1093 (1→45); `skill_skillexp_v` dùng `SkillExpFunc(13000,...)` |
| 18 | `fengxue_bingtian` | Phong Tuyết Băng Thiên (338) | Đánh | `seriesdamage_p`: 20→60→62; `colddamage_v`: sub1=sub3=45→400 (không đổi giữa 2 sub) |
| 19 | `cuiyan120` | Ngự Tuyết ẩn (713, skill 120) | Bổ trợ (ẩn thân/tàng hình) | `skill_cost_v`: 35→80→80; `hide`: field1 cố định 1 (bật ẩn thân), field2 thời gian ẩn 5*18→30*18→30*18 tick; `skill_mintimepercast_v`/`skill_mintimepercastonhorse_v`: cooldown 60*18→40*18→40*18 (giảm dần); `skill_desc`: "Thời gian khôi phục chiêu thức: X giây" |
| 20 | `daocuiyan150` | Băng Tước Hoạt Kỳ (1063, skill 150) | Đánh | `physicsenhance_p`: 90→900 (lv15=600, lv23=1260, lv26=1440); `seriesdamage_p`: 40→80→82 (lv15=40); `colddamage_v`: sub1=60→1050 (lv15=850, lv23=1290, lv26=1410), sub3=300→1655 (lv15=1200, lv23=2201, lv26=2474); `missle_speed_v`: 24→24→24 (không đổi); `skill_attackradius`: 448→512→512; `skill_cost_v`: 48→72→79(lv23); `skill_collideevent` kích hoạt skill con 1064 |
| 21 | `daocuiyan150_2` | Băng Ngưng Hàn Yên (1064, tầng 2 của Băng Tước Hoạt Kỳ) | Đánh | `physicsenhance_p`: 18→175 (lv15=120, lv23=241, lv26=274); `seriesdamage_p`: 40→80→82; `colddamage_v`: sub1=12→210 (lv15=168, lv23=260, lv26=285), sub3=60→331 (lv15=240, lv23=440, lv26=494); `missle_speed_v`: 28→32→32; `skill_misslenum_v`: 1→5→5 |
| 22 | `neicuiyan150` | Thủy Anh Man Tú (1065, skill 150, nội công) | Đánh | `seriesdamage_p`: 40→80→82 (lv15=40); `physicsdamage_v`: sub1=sub3=6→430 (lv15=120, lv23=802, lv26=988); `colddamage_v`: sub1=sub3=18→700 (lv15=290, lv23=1192, lv26=1438); `missle_speed_v`: 20→24→24; `skill_attackradius`: 448→512→512; `skill_cost_v`: 55→90→101(lv23); `skill_flyevent` kích hoạt skill con 1093 khi bay |
| 23 | `neicuiyan150_2` | Khinh Sa Phù Thủy (1093, tầng 2 của Thủy Anh Man Tú) | Đánh | `seriesdamage_p`: 40→80→82; `colddamage_v`: sub1=sub3=55→720 (lv23=930, lv26=1035) |

**Field mới xuất hiện chỉ ở Thúy Yên (so với A.4):** `colddamage_v` luôn có cấu trúc 2-sub (không
có sub2 giữa như `poisondamage_v` của Ngũ Độc — nghi 2 môn phái dùng schema field số lượng khác
nhau tùy loại nguyên tố); `coldenhance_p`, `addcoldmagic_v`, `addcolddamage_v`, `lifereplenish_v`
(hồi máu tuyệt đối, khác `lifereplenish_p` dạng % thấy ở Thiên Vương/Thiên Nhẫn), `hide` (skill ẩn
thân — field cấu trúc giống proc/toggle, chưa thấy ở 3 môn phái kia), `fastwalkrun_p`,
`meleedamagereturn_p`/`rangedamagereturn_p` (Thúy Yên có cả 2 loại phản đòn cùng lúc, Thiên Nhẫn
chỉ có `meleedamagereturn_p`).

---

## PHẦN C — Tổng hợp: Ngũ Hành tương khắc áp dụng cho Skill

**Kết luận: KHÔNG có cơ chế riêng cho skill — mọi skill dùng CHUNG pipeline `CalcDamage` đã ghi ở
`docs/vltk_player_stats_reference.md` mục 11.5 (tương khắc Ngũ Hành áp dụng như nhau cho đòn tay
không lẫn skill).**

Bằng chứng: field `seriesdamage_p` xuất hiện lặp lại ở HẦU HẾT skill của MỌI môn phái (xem PHẦN B —
Thiếu Lâm, Võ Đang, Nga Mi, Cái Bang, Côn Lôn, Đường Môn, Ngũ Độc, Thiên Vương, Thiên Nhẫn, Thúy Yên
đều có), và đây chính là tham số `nFiveElementsDamageP` được `KNpc::ReceiveDamage` (KNpc.cpp:2901,
xem PHẦN A.2 và `vltk_player_stats_reference.md` mục 11.5) đọc ra rồi truyền THẲNG vào
`CalcDamage(..., nFiveElementsDamageP, ...)` — không có công thức tương khắc RIÊNG cho skill, không
có bảng tương khắc khác bảng 5 cặp `series_metal/wood/water/fire/earth` đã xác nhận trước đó.

**Ý nghĩa thực tế:** mỗi skill chỉ khai báo 1 con số `seriesdamage_p` theo cấp (VD Đường Môn
"Phích Lịch Đơn" seriesdamage_p 1→10 — xem B.6) — con số này CHÍNH LÀ mức độ khuếch đại/giảm
tương khắc khi trúng đòn, dùng chung công thức `nRes -= nFiveElements_DamageP` /
`nDamage -= (AttackerEnhance - DefenderResist)` đã trích dẫn nguyên văn ở tài liệu kia. Skill cấp
càng cao, `seriesdamage_p` càng lớn → hiệu ứng tương khắc càng mạnh khi đánh đúng hệ khắc chế.
