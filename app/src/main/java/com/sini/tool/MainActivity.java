package com.sini.tool;

import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;

public class MainActivity extends AppCompatActivity {
    private TextView status;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        status = findViewById(R.id.statusText);
        findViewById(R.id.btnOverlay).setOnClickListener(v -> requestOverlay());
        findViewById(R.id.btnRootTest).setOnClickListener(v -> {
            boolean ok = RootBridge.hasRoot();
            Toast.makeText(this, ok ? "Root OK — Sini ready" : "Enable root in virtual phone", Toast.LENGTH_LONG).show();
            if (ok) RootBridge.ensureEngineDeployed(this);
            refresh();
        });
        findViewById(R.id.btnStart).setOnClickListener(v -> startBubble());
        findViewById(R.id.btnStop).setOnClickListener(v -> {
            stopService(new Intent(this, BubbleService.class));
            Toast.makeText(this, "Sini bubble stopped", Toast.LENGTH_SHORT).show();
        });
        refresh();
    }

    @Override protected void onResume() { super.onResume(); refresh(); }

    private void refresh() {
        boolean overlay = Settings.canDrawOverlays(this);
        boolean root = RootBridge.hasRoot();
        status.setText(
            "SINITOOL STATUS\n\n" +
            "Overlay: " + (overlay ? "OK" : "NEED PERMISSION") + "\n" +
            "Root: " + (root ? "OK" : "NOT DETECTED") + "\n" +
            "Android " + Build.VERSION.RELEASE + " · API " + Build.VERSION.SDK_INT + "\n\n" +
            "1 Grant overlay\n2 Test root\n3 Open your game\n4 Start bubble → tap S"
        );
    }

    private void requestOverlay() {
        if (Settings.canDrawOverlays(this)) {
            Toast.makeText(this, "Already granted", Toast.LENGTH_SHORT).show();
            return;
        }
        startActivity(new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:" + getPackageName())));
    }

    private void startBubble() {
        if (!Settings.canDrawOverlays(this)) {
            Toast.makeText(this, "Grant overlay first", Toast.LENGTH_LONG).show();
            requestOverlay();
            return;
        }
        if (!RootBridge.hasRoot()) {
            Toast.makeText(this, "Root required", Toast.LENGTH_LONG).show();
            return;
        }
        RootBridge.ensureEngineDeployed(this);
        Intent i = new Intent(this, BubbleService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i);
        else startService(i);
        Toast.makeText(this, "Sini bubble live", Toast.LENGTH_SHORT).show();
        moveTaskToBack(true);
    }
}
