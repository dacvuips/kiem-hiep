// Ghidra headless post-script: tìm mọi hàm có tên khớp danh sách từ khóa combat (Damage, Attack,
// Defense, Combat, Hit, Crit...) trong Coreserver.dll, decompile, và ghi toàn bộ ra 1 file text
// duy nhất để đọc offline — dùng vì không thể thao tác GUI Ghidra trực tiếp trên máy người dùng.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;
import ghidra.util.task.ConsoleTaskMonitor;

import java.io.File;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.List;

public class DecompileCombatFunctions extends GhidraScript {

	// Từ khóa (không phân biệt hoa/thường) để lọc tên hàm liên quan combat — khớp với các chuỗi
	// đã tìm thấy trước đó qua string scan (damage, attack, defense, combat, hit, crit...).
	private static final String[] KEYWORDS = {
		"damage", "attack", "defense", "combat", "battle",
		"hit", "crit", "dodge", "evade", "miss", "kill", "hurt"
	};

	@Override
	protected void run() throws Exception {
		String outPath = getScriptArgs().length > 0 ? getScriptArgs()[0]
				: "D:/game/lam-game/kiem-hiep/tools/ghidra_output/combat_functions_decompiled.txt";
		File outFile = new File(outPath);
		outFile.getParentFile().mkdirs();

		DecompInterface decomp = new DecompInterface();
		decomp.openProgram(currentProgram);

		FunctionManager fm = currentProgram.getFunctionManager();
		List<Function> matched = new ArrayList<>();
		for (Function f : fm.getFunctions(true)) {
			String name = f.getName();
			String lower = name.toLowerCase();
			for (String kw : KEYWORDS) {
				if (lower.contains(kw)) {
					matched.add(f);
					break;
				}
			}
		}

		println("Tim thay " + matched.size() + " ham khop tu khoa combat.");

		try (PrintWriter pw = new PrintWriter(outFile, "UTF-8")) {
			pw.println("Tong so ham khop: " + matched.size());
			pw.println("========================================");
			for (Function f : matched) {
				pw.println();
				pw.println("---- FUNCTION: " + f.getName() + " @ " + f.getEntryPoint() + " ----");
				DecompileResults res = decomp.decompileFunction(f, 60, new ConsoleTaskMonitor());
				if (res != null && res.decompileCompleted()) {
					pw.println(res.getDecompiledFunction().getC());
				}
				else {
					pw.println("[decompile that bai hoac timeout cho ham nay]");
				}
			}
		}

		println("Da ghi ket qua vao: " + outFile.getAbsolutePath());
	}
}
