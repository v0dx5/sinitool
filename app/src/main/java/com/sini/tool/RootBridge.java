package com.sini.tool;

import android.content.Context;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

public class RootBridge {
    private static final String ENGINE = "sini_core.sh";
    private static final String REMOTE_DIR = "/data/local/tmp/sinitool";
    private static final String REMOTE_BIN = REMOTE_DIR + "/" + ENGINE;

    public static boolean hasRoot() {
        String out = su("id");
        return out != null && out.contains("uid=0");
    }

    public static void ensureEngineDeployed(Context ctx) {
        try {
            su("mkdir -p " + REMOTE_DIR);
            File local = new File(ctx.getFilesDir(), ENGINE);
            try (InputStream in = ctx.getAssets().open(ENGINE);
                 OutputStream out = new FileOutputStream(local)) {
                byte[] buf = new byte[8192];
                int n;
                while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
            } catch (Exception e) {
                try (FileOutputStream fos = new FileOutputStream(local)) {
                    fos.write("#!/system/bin/sh\necho missing\n".getBytes());
                }
            }
            local.setExecutable(true);
            su("cp " + local.getAbsolutePath() + " " + REMOTE_BIN);
            su("chmod 755 " + REMOTE_BIN);
        } catch (Exception ignored) {}
    }

    public static String exec(String args) {
        return su("sh " + REMOTE_BIN + " " + args);
    }

    public static List<String> listApps() {
        List<String> list = new ArrayList<>();
        String out = exec("apps");
        if (out == null) return list;
        for (String line : out.split("\n")) {
            line = line.trim();
            if (line.isEmpty() || line.startsWith("=")) continue;
            list.add(line);
        }
        return list;
    }

    public static String attach(String t) { return exec("attach " + q(t)); }
    public static String scan(String type, String value) { return exec("scan " + type + " " + q(value)); }
    public static String filter(String mode, String value) {
        if (value == null || value.isEmpty()) return exec("filter " + mode);
        return exec("filter " + mode + " " + q(value));
    }
    public static String listResults(int max) { return exec("list " + max); }
    public static String writeAll(String type, String value) { return exec("writeall " + type + " " + q(value)); }
    public static String status() { return exec("status"); }

    private static String q(String s) {
        if (s == null) return "''";
        return "'" + s.replace("'", "'\\''") + "'";
    }

    public static String su(String cmd) {
        Process p = null;
        try {
            p = Runtime.getRuntime().exec(new String[]{"su", "-c", cmd});
            if (BuildVersion.wait(p, 60)) {
                /* ok */
            } else {
                p.destroy();
                return "ERROR: timeout";
            }
            StringBuilder sb = new StringBuilder();
            BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream()));
            String line;
            while ((line = br.readLine()) != null) sb.append(line).append('\n');
            BufferedReader er = new BufferedReader(new InputStreamReader(p.getErrorStream()));
            while ((line = er.readLine()) != null) sb.append(line).append('\n');
            return sb.toString().trim();
        } catch (Exception e) {
            return "ERROR: " + e.getMessage();
        } finally {
            if (p != null) p.destroy();
        }
    }

    private static class BuildVersion {
        static boolean wait(Process p, int sec) throws InterruptedException {
            if (android.os.Build.VERSION.SDK_INT >= 26)
                return p.waitFor(sec, TimeUnit.SECONDS);
            p.waitFor();
            return true;
        }
    }
}
