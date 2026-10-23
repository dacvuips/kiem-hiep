package com.godot.game;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.content.pm.SigningInfo;
import android.os.Build;
import android.os.Debug;
import android.os.Process;
import android.util.Log;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.security.MessageDigest;
import java.util.Locale;

/**
 * SecurityGuard — Hệ thống phòng thủ chống dịch ngược (Anti-Reverse Engineering),
 * chống hook (Anti-Frida / Anti-Xposed), chống debug (Anti-Debugging) và kiểm tra
 * tính toàn vẹn chữ ký APK (Anti-Repack).
 */
public final class SecurityGuard {
    private static final String TAG = "SecurityGuard";

    // Danh sách đường dẫn binary su phổ biến trên Android đã Root
    private static final String[] SU_PATHS = {
        "/system/app/Superuser.apk",
        "/sbin/su",
        "/system/bin/su",
        "/system/xbin/su",
        "/data/local/xbin/su",
        "/data/local/bin/su",
        "/system/sd/xbin/su",
        "/system/bin/failsafe/su",
        "/data/local/su"
    };

    // Các từ khóa thư viện hook / dynamic binary instrumentation nguy hiểm trong /proc/self/maps
    private static final String[] HOOK_KEYWORDS = {
        "frida-gadget",
        "frida-agent",
        "gum-js-loop",
        "libxposed",
        "edxposed",
        "lsposed",
        "libsubstrate",
        "cydiasubstrate"
    };

    private SecurityGuard() {}

    /**
     * Kiểm tra tổng hợp các công cụ dịch ngược / can thiệp bộ nhớ.
     * Trả về true nếu phát hiện môi trường bị can thiệp.
     */
    public static boolean isTampered(Context context) {
        if (isDebuggerAttached()) {
            Log.w(TAG, "Phát hiện Debugger đang kết nối");
            return true;
        }
        if (isFridaOrHookingDetected()) {
            Log.w(TAG, "Phát hiện công cụ Hooking/Frida đang can thiệp");
            return true;
        }
        if (isHookFrameworkLoaded()) {
            Log.w(TAG, "Phát hiện framework Xposed/Hook trong ClassLoader");
            return true;
        }
        return false;
    }

    /**
     * Kiểm tra có Debugger / Tracer đính kèm tiến trình không (ptrace / gdb / lldb).
     */
    public static boolean isDebuggerAttached() {
        if (Debug.isDebuggerConnected() || Debug.waitingForDebugger()) {
            return true;
        }
        // Kiểm tra TracerPid trong /proc/self/status
        File statusFile = new File("/proc/self/status");
        if (statusFile.canRead()) {
            try (BufferedReader reader = new BufferedReader(new FileReader(statusFile))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.startsWith("TracerPid:")) {
                        String pidStr = line.substring("TracerPid:".length()).trim();
                        try {
                            int tracerPid = Integer.parseInt(pidStr);
                            if (tracerPid > 0) {
                                return true;
                            }
                        } catch (NumberFormatException ignored) {}
                        break;
                    }
                }
            } catch (Exception ignored) {}
        }
        return false;
    }

    /**
     * Kiểm tra Frida server port và các thư viện hook được nạp vào /proc/self/maps.
     */
    public static boolean isFridaOrHookingDetected() {
        // 1. Kiểm tra /proc/self/maps xem có thư viện frida/xposed được nạp không
        File mapsFile = new File("/proc/self/maps");
        if (mapsFile.canRead()) {
            try (BufferedReader reader = new BufferedReader(new FileReader(mapsFile))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    String lower = line.toLowerCase(Locale.ROOT);
                    for (String keyword : HOOK_KEYWORDS) {
                        if (lower.contains(keyword)) {
                            return true;
                        }
                    }
                }
            } catch (Exception ignored) {}
        }

        // 2. Kiểm tra Frida default server port (27042)
        try (Socket socket = new Socket()) {
            socket.connect(new InetSocketAddress("127.0.0.1", 27042), 30);
            return true;
        } catch (Exception ignored) {}

        return false;
    }

    /**
     * Kiểm tra sự tồn tại của các lớp Xposed hoặc Hook framework trong ClassLoader.
     */
    public static boolean isHookFrameworkLoaded() {
        try {
            Class.forName("de.robv.android.xposed.XposedBridge");
            return true;
        } catch (ClassNotFoundException ignored) {}
        return false;
    }

    /**
     * Kiểm tra thiết bị có quyền root không.
     */
    public static boolean isDeviceRooted() {
        // Kiểm tra test-keys trên Build.TAGS
        String buildTags = Build.TAGS;
        if (buildTags != null && buildTags.contains("test-keys")) {
            return true;
        }
        // Kiểm tra binary su
        for (String path : SU_PATHS) {
            if (new File(path).exists()) {
                return true;
            }
        }
        return false;
    }

    /**
     * Kiểm tra chữ ký APK runtime (chống decompile repack lại APK).
     * @param expectedCertSha256 Mã băm SHA-256 viết hoa/thường không dấu cách của Certificate Keystore Release.
     */
    public static boolean verifyAppSignature(Context context, String expectedCertSha256) {
        if (expectedCertSha256 == null || expectedCertSha256.trim().isEmpty()) {
            return true; // Bỏ qua nếu chưa cấu hình
        }
        try {
            PackageInfo packageInfo;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo = context.getPackageManager().getPackageInfo(
                    context.getPackageName(),
                    PackageManager.GET_SIGNING_CERTIFICATES
                );
                SigningInfo signingInfo = packageInfo.signingInfo;
                Signature[] signatures = signingInfo.hasMultipleSigners()
                    ? signingInfo.getApkContentsSigners()
                    : signingInfo.getSigningCertificateHistory();
                for (Signature sig : signatures) {
                    String sha256 = getSha256(sig.toByteArray());
                    if (sha256.equalsIgnoreCase(expectedCertSha256)) return true;
                }
            } else {
                packageInfo = context.getPackageManager().getPackageInfo(
                    context.getPackageName(),
                    PackageManager.GET_SIGNATURES
                );
                for (Signature sig : packageInfo.signatures) {
                    String sha256 = getSha256(sig.toByteArray());
                    if (sha256.equalsIgnoreCase(expectedCertSha256)) return true;
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Lỗi kiểm tra chữ ký APK", e);
            return false;
        }
        return false;
    }

    private static String getSha256(byte[] data) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(data);
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) {
                sb.append(String.format(Locale.ROOT, "%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            return "";
        }
    }

    /**
     * Thực thi kiểm tra bảo mật trong Release build. Tự động thoát ứng dụng nếu phát hiện can thiệp.
     */
    public static void checkAndEnforce(Context context) {
        if (isTampered(context)) {
            Log.e(TAG, "Vi phạm chính sách an toàn: phát hiện công cụ dịch ngược hoặc debugger. Đang đóng ứng dụng.");
            Process.killProcess(Process.myPid());
            System.exit(1);
        }
    }
}
