# SiniTool
### Root memory engine · Floating overlay · Stronger than basic GG workflows

**SiniTool** is a root-powered game memory toolkit for Android / virtual phones  
(VMOS, VPhoneOS, F1 VM, real rooted devices).

```
  ███████╗██╗███╗   ██╗██╗████████╗ ██████╗  ██████╗ ██╗     
  ██╔════╝██║████╗  ██║██║╚══██╔══╝██╔═══██╗██╔═══██╗██║     
  ███████╗██║██╔██╗ ██║██║   ██║   ██║   ██║██║   ██║██║     
  ╚════██║██║██║╚██╗██║██║   ██║   ██║   ██║██║   ██║██║     
  ███████║██║██║ ╚████║██║   ██║   ╚██████╔╝╚██████╔╝███████╗
  ╚══════╝╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝
```

## Why SiniTool
| Feature | SiniTool |
|---------|----------|
| Floating bubble overlay | Yes |
| Attach by package / PID | Yes |
| Multi-type scan (byte→double) | Yes |
| Exact / changed / unchanged / bigger / smaller | Yes |
| Batch write + freeze | Yes |
| Group / range edit | Yes |
| Hex browser (read region) | Yes |
| Auto-filter workflow scripts | Yes |
| Works in rooted VMs | Yes |
| Termux engine (no APK needed) | Yes |
| Cloud APK build (no Android Studio) | Yes (GitHub Actions) |

## You only have laptop + Termux?
You have **two paths**:

1. **Termux-only engine (today)** — full scan/edit from terminal inside the rooted VM  
2. **APK via free GitHub Actions** — push this project, download APK, install — **no Android Studio**

See `docs/NO_STUDIO_BUILD.md` and `docs/TERMUX.md`.

## Folders
- `scripts/sini_core.sh` — OP root engine  
- `app/` — Android UI (floating Sini bubble)  
- `docs/` — build guides  
- `logo/` — SiniTool logo assets  
