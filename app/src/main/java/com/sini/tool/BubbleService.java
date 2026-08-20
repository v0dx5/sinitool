package com.sini.tool;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.graphics.PixelFormat;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;
import androidx.core.app.NotificationCompat;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class BubbleService extends Service {
    private WindowManager wm;
    private View bubble, panel;
    private WindowManager.LayoutParams bp, pp;
    private boolean open;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private TextView logView;
    private Spinner appSpinner, typeSpinner;
    private EditText valueInput, editInput;
    private List<String> appLines = new ArrayList<>();

    @Override public void onCreate() {
        super.onCreate();
        startForeground(7, notif());
        wm = (WindowManager) getSystemService(WINDOW_SERVICE);
        addBubble();
    }

    @Override public int onStartCommand(Intent i, int f, int id) { return START_STICKY; }
    @Override public IBinder onBind(Intent i) { return null; }
    @Override public void onDestroy() {
        remove(bubble); remove(panel); io.shutdownNow(); super.onDestroy();
    }

    private Notification notif() {
        String ch = "sini";
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel c = new NotificationChannel(ch, "SiniTool", NotificationManager.IMPORTANCE_LOW);
            ((NotificationManager) getSystemService(NOTIFICATION_SERVICE)).createNotificationChannel(c);
        }
        PendingIntent pi = PendingIntent.getActivity(this, 0,
                new Intent(this, MainActivity.class), PendingIntent.FLAG_IMMUTABLE);
        return new NotificationCompat.Builder(this, ch)
                .setContentTitle("SiniTool")
                .setContentText("Floating scanner active")
                .setSmallIcon(R.drawable.ic_sini)
                .setContentIntent(pi)
                .setOngoing(true).build();
    }

    private int type() {
        return Build.VERSION.SDK_INT >= 26
                ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                : WindowManager.LayoutParams.TYPE_PHONE;
    }

    private void addBubble() {
        bubble = LayoutInflater.from(this).inflate(R.layout.overlay_bubble, null);
        bp = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                type(),
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT);
        bp.gravity = Gravity.TOP | Gravity.START;
        bp.x = 48; bp.y = 220;
        bubble.setOnTouchListener(new Drag(bp, this::toggle));
        wm.addView(bubble, bp);
    }

    private void toggle() {
        if (open) { remove(panel); panel = null; open = false; }
        else { showPanel(); open = true; }
    }

    private void showPanel() {
        panel = LayoutInflater.from(this).inflate(R.layout.overlay_panel, null);
        pp = new WindowManager.LayoutParams(dp(330), WindowManager.LayoutParams.WRAP_CONTENT,
                type(), WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL, PixelFormat.TRANSLUCENT);
        pp.gravity = Gravity.TOP | Gravity.START;
        pp.x = bp.x; pp.y = bp.y + dp(66);
        pp.softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE;

        logView = panel.findViewById(R.id.panelLog);
        appSpinner = panel.findViewById(R.id.spinnerApps);
        typeSpinner = panel.findViewById(R.id.spinnerType);
        valueInput = panel.findViewById(R.id.inputValue);
        editInput = panel.findViewById(R.id.inputEditValue);
        typeSpinner.setAdapter(new ArrayAdapter<>(this,
                android.R.layout.simple_spinner_dropdown_item,
                new String[]{"dword", "qword", "float", "double", "word", "byte"}));

        panel.findViewById(R.id.btnRefreshApps).setOnClickListener(v -> refreshApps());
        panel.findViewById(R.id.btnAttach).setOnClickListener(v -> attach());
        panel.findViewById(R.id.btnScan).setOnClickListener(v -> scan());
        panel.findViewById(R.id.btnFilterChanged).setOnClickListener(v -> filter("changed", null));
        panel.findViewById(R.id.btnFilterUnchanged).setOnClickListener(v -> filter("unchanged", null));
        panel.findViewById(R.id.btnFilterExact).setOnClickListener(v ->
                filter("exact", valueInput.getText().toString().trim()));
        panel.findViewById(R.id.btnList).setOnClickListener(v -> list());
        panel.findViewById(R.id.btnWriteAll).setOnClickListener(v -> writeAll());
        panel.findViewById(R.id.btnClosePanel).setOnClickListener(v -> toggle());

        wm.addView(panel, pp);
        refreshApps();
        log("Sini panel online. Open game → Refresh → Attach → Scan.");
    }

    private void refreshApps() {
        log("Loading apps…");
        io.execute(() -> {
            List<String> lines = RootBridge.listApps();
            main.post(() -> {
                appLines = lines;
                List<String> labels = new ArrayList<>();
                for (String l : lines) labels.add(l.length() > 46 ? l.substring(0, 46) + "…" : l);
                if (labels.isEmpty()) labels.add("(open a game first)");
                appSpinner.setAdapter(new ArrayAdapter<>(this,
                        android.R.layout.simple_spinner_dropdown_item, labels));
                log("Apps found: " + lines.size());
            });
        });
    }

    private void attach() {
        int i = appSpinner.getSelectedItemPosition();
        if (i < 0 || i >= appLines.size()) { toast("Pick app"); return; }
        String target = appLines.get(i).split("\\s+")[0];
        log("Attach " + target);
        io.execute(() -> main.post(() -> log(RootBridge.attach(target))));
    }

    private void scan() {
        String type = String.valueOf(typeSpinner.getSelectedItem());
        String val = valueInput.getText().toString().trim();
        if (val.isEmpty()) { toast("Enter value"); return; }
        log("Scan " + type + "=" + val);
        io.execute(() -> main.post(() -> log(RootBridge.scan(type, val))));
    }

    private void filter(String mode, String value) {
        log("Filter " + mode);
        io.execute(() -> main.post(() -> log(RootBridge.filter(mode, value))));
    }

    private void list() {
        io.execute(() -> main.post(() -> log(RootBridge.listResults(40))));
    }

    private void writeAll() {
        String type = String.valueOf(typeSpinner.getSelectedItem());
        String val = editInput.getText().toString().trim();
        if (val.isEmpty()) val = valueInput.getText().toString().trim();
        if (val.isEmpty()) { toast("Enter new value"); return; }
        String v = val;
        log("WriteAll → " + v);
        io.execute(() -> main.post(() -> log(RootBridge.writeAll(type, v))));
    }

    private void log(String s) {
        if (logView == null) return;
        String cur = logView.getText().toString();
        logView.setText(((cur.length() > 3500) ? cur.substring(cur.length() - 2800) : cur) + "\n" + s);
    }

    private void toast(String s) { Toast.makeText(this, s, Toast.LENGTH_SHORT).show(); }
    private void remove(View v) { if (v != null) try { wm.removeView(v); } catch (Exception ignored) {} }
    private int dp(int d) { return Math.round(d * getResources().getDisplayMetrics().density); }

    private class Drag implements View.OnTouchListener {
        final WindowManager.LayoutParams lp; final Runnable tap;
        int sx, sy; float tx, ty; boolean moved;
        Drag(WindowManager.LayoutParams lp, Runnable tap) { this.lp = lp; this.tap = tap; }
        @Override public boolean onTouch(View v, MotionEvent e) {
            switch (e.getAction()) {
                case MotionEvent.ACTION_DOWN:
                    sx = lp.x; sy = lp.y; tx = e.getRawX(); ty = e.getRawY(); moved = false; return true;
                case MotionEvent.ACTION_MOVE:
                    int dx = (int) (e.getRawX() - tx), dy = (int) (e.getRawY() - ty);
                    if (Math.abs(dx) > 8 || Math.abs(dy) > 8) moved = true;
                    lp.x = sx + dx; lp.y = sy + dy; wm.updateViewLayout(bubble, lp); return true;
                case MotionEvent.ACTION_UP:
                    if (!moved) tap.run(); return true;
            }
            return false;
        }
    }
}
