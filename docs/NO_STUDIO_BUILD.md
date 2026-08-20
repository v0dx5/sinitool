[NO_STUDIO_BUILD.md](https://github.com/user-attachments/files/31248165/NO_STUDIO_BUILD.md)
# Build SiniTool APK **without** Android Studio

You only have a laptop + phone/Termux. Use **free GitHub Actions** to compile the APK in the cloud.

---

## Path A — GitHub Actions (recommended, free)

### Step 1 — Create a GitHub account
https://github.com/join

### Step 2 — New repository
- Click **New repository**
- Name: `sinitool`
- Public
- Create

### Step 3 — Upload this project
**Option easy (web):**
1. On the repo page → **uploading an existing file**
2. Drag the whole `sinitool` folder contents  
   (must include `app/`, `scripts/`, `.github/`, `settings.gradle`, etc.)
3. Commit

**Option with Git on laptop:**
```bash
cd sinitool
git init
git add .
git commit -m "SiniTool"
git branch -M main
git remote add origin https://github.com/YOURUSER/sinitool.git
git push -u origin main
```

### Step 4 — Wait for build
1. Repo → **Actions** tab
2. Workflow **Build SiniTool APK** runs automatically
3. Wait 3–8 minutes until green check

### Step 5 — Download APK
1. Open the finished workflow run
2. **Artifacts** → download `sinitool-apk`
3. Unzip → `app-debug.apk`

### Step 6 — Install on virtual phone
1. Copy APK into the VM (shared folder / telegram / drive)
2. Enable **Install unknown apps**
3. Install SiniTool
4. Grant **overlay** + **root**
5. Start bubble

---

## Path B — Termux only (no APK)
Follow `TERMUX.md` — full power from command line, no GUI bubble.

---

## Path C — Online IDE (optional)
Some sites (Gitpod / Codespaces) can run Android builds if you connect the repo — same project files.

---

## After install — UI usage
1. Open **SiniTool**
2. Grant overlay
3. Test root
4. Open game
5. Start bubble → tap floating **S**
6. Refresh → select game → Attach  
7. Scan → change in-game → Changed → Write ALL
