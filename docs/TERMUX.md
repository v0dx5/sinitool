# SiniTool — Termux Only (no Android Studio, no PC IDE)

Use this on a **rooted virtual phone** (VPhoneOS / VMOS / etc.) or rooted device with Termux.

## 1. Install Termux (F-Droid version recommended)
Inside the **virtual phone**:
- Install Termux
- Open Termux

## 2. Packages
```bash
pkg update -y
pkg install -y python tsu root-repo
# tsu = su helper for Termux
```

## 3. Copy Sini engine
From your laptop, push the script (USB debugging / ADB), **or** paste it:

```bash
mkdir -p ~/sinitool
# paste scripts/sini_core.sh into ~/sinitool/sini_core.sh
chmod 755 ~/sinitool/sini_core.sh
```

Or with adb from laptop:
```bash
adb push scripts/sini_core.sh /data/local/tmp/sini_core.sh
adb shell
su
chmod 755 /data/local/tmp/sini_core.sh
```

## 4. Root shell
```bash
su
# or: tsu
```

## 5. Use it (Cheat Engine workflow)
```bash
# list running games
sh /data/local/tmp/sini_core.sh apps

# attach (package name from list)
sh /data/local/tmp/sini_core.sh attach com.some.game

# scan current coins/hp (example: 150)
sh /data/local/tmp/sini_core.sh scan dword 150

# change value IN THE GAME, then:
sh /data/local/tmp/sini_core.sh filter changed

# still many? change again, filter changed again
sh /data/local/tmp/sini_core.sh filter changed

# list remaining
sh /data/local/tmp/sini_core.sh list 40

# write all hits to new value
sh /data/local/tmp/sini_core.sh writeall dword 999999

# optional freeze
sh /data/local/tmp/sini_core.sh freeze 0xADDRESS dword 999999
sh /data/local/tmp/sini_core.sh freeze_loop
```

## 6. One-shot helper
```bash
sh /data/local/tmp/sini_core.sh quick com.some.game dword 100 9999
# follow prompts
```

## Tips
- Always **open the game first** so it has a PID  
- Prefer **dword** for coins/scores, **float** for some health bars  
- If scan returns 0: wrong type, or value is encrypted/server-side  
- Virtual phone **root toggle must be ON**
