// Ghidra headless post-script: decompile các hàm theo ĐỊA CHỈ (đối số: đường dẫn file ra, rồi các địa chỉ hex, mỗi cái 1 đối số
// hoặc cách nhau dấu phẩy). Địa chỉ lấy từ file .map của server (VD CalcDamage = 1000fa50). Tạo hàm tại địa chỉ nếu chưa có.
import ghidra.app.script.GhidraScript;
import ghidra.app.cmd.function.CreateFunctionCmd;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.util.task.ConsoleTaskMonitor;
import java.io.File;
import java.io.PrintWriter;

public class DecompileByName extends GhidraScript {
	@Override
	protected void run() throws Exception {
		String[] args = getScriptArgs();
		DecompInterface decomp = new DecompInterface();
		decomp.openProgram(currentProgram);
		try (PrintWriter pw = new PrintWriter(new File(args[0]), "UTF-8")) {
			for (int i = 1; i < args.length; i++) {
				for (String a : args[i].split(",")) {
					if (a.trim().isEmpty()) continue;
					Address addr = toAddr(a.trim());
					Function f = getFunctionAt(addr);
					if (f == null) {
						disassemble(addr);
						createFunction(addr, null);
						f = getFunctionAt(addr);
					}
					pw.println("---- FUNCTION @ " + addr + (f != null ? " name=" + f.getName() : " (none)") + " ----");
					if (f == null) continue;
					DecompileResults res = decomp.decompileFunction(f, 180, new ConsoleTaskMonitor());
					pw.println(res != null && res.decompileCompleted() ? res.getDecompiledFunction().getC() : "(decompile failed)");
				}
			}
		}
	}
}
