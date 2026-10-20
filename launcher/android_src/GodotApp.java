/**************************************************************************/
/*  GodotApp.java                                                         */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

package com.godot.game;

import org.godotengine.godot.Godot;
import org.godotengine.godot.GodotActivity;

import android.os.Bundle;
import android.util.Log;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

import androidx.activity.EdgeToEdge;
import androidx.core.splashscreen.SplashScreen;

/**
 * Template activity for Godot Android builds.
 * Feel free to extend and modify this class for your custom logic.
 *
 * KIẾM HIỆP (launcher/android_src/GodotApp.java — bash launcher/setup_android.sh chép đè vào template):
 * APK chỉ chứa launcher. launcher.gd tải gói game về getFilesDir()/content/, ghi file đánh dấu "boot_game"
 * (dòng 1 = core.pck, dòng 2 = thư mục gói) rồi khởi động lại app -> lần này chạy thẳng game bằng --main-pack.
 * File đánh dấu dùng 1 lần (đọc xong xoá), nên lần mở app sau lại vào launcher kiểm tra cập nhật.
 * Phải qua file vì activity chính (exported) bỏ qua tham số dòng lệnh gửi kèm Intent.
 */
public class GodotApp extends GodotActivity {
	private static final String TAG = "KiemHiep";
	private static final String BOOT_MARKER = "boot_game";
	private static volatile GodotApp sInstance;
	private List<String> commandLine;

	static {
		// .NET libraries.
		if (BuildConfig.FLAVOR.equals("mono")) {
			try {
				Log.v("GODOT", "Loading System.Security.Cryptography.Native.Android library");
				System.loadLibrary("System.Security.Cryptography.Native.Android");
			} catch (UnsatisfiedLinkError e) {
				Log.e("GODOT", "Unable to load System.Security.Cryptography.Native.Android library");
			}
		}
	}

	private final Runnable updateWindowAppearance = () -> {
		Godot godot = getGodot();
		if (godot != null) {
			godot.enableImmersiveMode(godot.isInImmersiveMode(), true);
			godot.enableEdgeToEdge(godot.isInEdgeToEdgeMode(), true);
			godot.setSystemBarsAppearance();
		}
	};

	@Override
	public void onCreate(Bundle savedInstanceState) {
		sInstance = this;
		SplashScreen splashScreen = SplashScreen.installSplashScreen(this);
		EdgeToEdge.enable(this);
		super.onCreate(savedInstanceState);

		Godot godot = getGodot();
		if (godot != null && godot.getDisableGodotSplash()) {
			splashScreen.setKeepOnScreenCondition(() -> godot.getRunStatus() != Godot.RunStatus.STARTED);
		}
	}

	@Override
	protected void onDestroy() {
		if (sInstance == this) {
			sInstance = null;
		}
		super.onDestroy();
	}

	@Override
	public List<String> getCommandLine() {
		List<String> args = new ArrayList<>(super.getCommandLine());
		addGameBootArgs(args);
		return args;
	}

	/** Gọi từ launcher.gd (JavaClassWrapper) để khởi động lại app vào game. */
	public static void restartApp() {
		GodotApp app = sInstance;
		if (app != null) {
			app.runOnUiThread(() -> {
				Log.i(TAG, "restartApp: Khởi động lại process vào game qua ProcessPhoenix...");
				org.godotengine.godot.utils.ProcessPhoenix.triggerRebirth(app);
			});
		}
	}

	private void addGameBootArgs(List<String> args) {
		File marker = new File(getFilesDir(), BOOT_MARKER);
		if (!marker.isFile()) {
			return;
		}
		List<String> lines = new ArrayList<>();
		try (BufferedReader r = new BufferedReader(new InputStreamReader(new FileInputStream(marker), StandardCharsets.UTF_8))) {
			for (String line; (line = r.readLine()) != null && lines.size() < 2;) {
				lines.add(line.trim());
			}
		} catch (IOException e) {
			Log.e(TAG, "Không đọc được " + marker, e);
			return;
		}
		if (lines.isEmpty()) {
			marker.delete();
			return;
		}
		String pck = lines.get(0);
		String dir = lines.size() > 1 ? lines.get(1) : new File(getFilesDir(), "content").getAbsolutePath();

		File pckFile = new File(pck);
		if (!pckFile.isFile()) {
			// Thử tìm trong files/content/<pck>
			pckFile = new File(new File(getFilesDir(), "content"), pckFile.getName());
		}
		File dirFile = new File(dir);
		if (!dirFile.isDirectory()) {
			dirFile = new File(getFilesDir(), "content");
		}

		if (!pckFile.isFile()) {
			Log.e(TAG, "File gói game không tồn tại: " + pckFile.getAbsolutePath());
			marker.delete();
			return;
		}

		// Xoá marker khi đã nạp thành công vào commandline args
		if (!marker.delete()) {
			Log.w(TAG, "Không xoá được " + marker);
		}

		Log.i(TAG, "Khởi động game từ " + pckFile.getAbsolutePath());
		args.add(0, pckFile.getAbsolutePath());
		args.add(0, "--main-pack");
		args.add("++");
		args.add("--kh-content=" + dirFile.getAbsolutePath());
	}

	@Override
	public void onResume() {
		super.onResume();
		updateWindowAppearance.run();
	}

	@Override
	public void onGodotMainLoopStarted() {
		super.onGodotMainLoopStarted();
		runOnUiThread(updateWindowAppearance);
	}

	@Override
	public void onGodotForceQuit(Godot instance) {
		if (!BuildConfig.FLAVOR.equals("instrumented")) {
			// For instrumented builds, we disable force-quitting to allow the instrumented tests to complete
			// successfully, otherwise they fail when the process crashes.
			super.onGodotForceQuit(instance);
		}
	}

	@Override
	protected boolean isPiPEnabled() {
		return true;
	}
}
