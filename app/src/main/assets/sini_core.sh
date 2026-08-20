#!/system/bin/sh
# SiniTool Core Engine v2 — OP root memory toolkit
# Android 7–15 · Virtual phones · Real root
#
# sini_core.sh apps
# sini_core.sh attach <package|pid>
# sini_core.sh scan <type> <value> [region]
# sini_core.sh filter <exact|changed|unchanged|bigger|smaller> [value]
# sini_core.sh list [max]
# sini_core.sh write <addr> <type> <value>
# sini_core.sh writeall <type> <value>
# sini_core.sh freeze <addr> <type> <value>
# sini_core.sh freeze_loop
# sini_core.sh unfreeze
# sini_core.sh hexdump <addr> <length>
# sini_core.sh watch <addr> <type>
# sini_core.sh status
# sini_core.sh quick <package> <type> <value> <newvalue>   # auto workflow

export PATH="/system/bin:/system/xbin:/sbin:/vendor/bin:$PATH"
WORKDIR="${SINI_DIR:-/data/local/tmp/sinitool}"
mkdir -p "$WORKDIR" 2>/dev/null
STATE="$WORKDIR/state"
RESULTS="$WORKDIR/results.txt"
PREV="$WORKDIR/prev.txt"
FREEZE_LIST="$WORKDIR/freeze.txt"
LOG="$WORKDIR/sini.log"

log() { echo "[$(date +%H:%M:%S)] $*" >> "$LOG"; }
need_root() {
  if [ "$(id -u)" != "0" ]; then
    echo "ERROR: root required (su)"
    exit 1
  fi
}

type_width() {
  case "$1" in byte) echo 1;; word) echo 2;; dword|float) echo 4;; qword|double) echo 8;; *) echo 4;; esac
}

py() {
  if command -v python3 >/dev/null 2>&1; then echo python3
  elif command -v python >/dev/null 2>&1; then echo python
  else echo ""; fi
}

value_to_hex() {
  TYPE="$1"; VAL="$2"; P=$(py)
  if [ -n "$P" ]; then
    $P - <<PY
import struct
t,v="$TYPE","$VAL"
try:
  if t=="byte": b=struct.pack("<B", int(v)&0xff)
  elif t=="word": b=struct.pack("<H", int(v)&0xffff)
  elif t=="dword": b=struct.pack("<I", int(v)&0xffffffff)
  elif t=="qword": b=struct.pack("<Q", int(v)&0xffffffffffffffff)
  elif t=="float": b=struct.pack("<f", float(v))
  elif t=="double": b=struct.pack("<d", float(v))
  else: b=struct.pack("<I", int(v)&0xffffffff)
  print(b.hex())
except Exception as e:
  print("ERR:"+str(e))
PY
  else
    N=$(printf "%d" "$VAL" 2>/dev/null || echo 0)
    W=$(type_width "$TYPE")
    case "$W" in
      1) printf "%02x" $((N&255));;
      2) printf "%02x%02x" $((N&255)) $(((N>>8)&255));;
      4) printf "%02x%02x%02x%02x" $((N&255)) $(((N>>8)&255)) $(((N>>16)&255)) $(((N>>24)&255));;
      8) printf "%02x%02x%02x%02x%02x%02x%02x%02x" $((N&255)) $(((N>>8)&255)) $(((N>>16)&255)) $(((N>>24)&255)) $(((N>>32)&255)) $(((N>>40)&255)) $(((N>>48)&255)) $(((N>>56)&255));;
    esac
  fi
}

hex_to_value() {
  TYPE="$1"; HEX="$2"; P=$(py)
  [ -z "$P" ] && echo "0x$HEX" && return
  $P - <<PY
import struct
t,h="$TYPE","$HEX"
b=bytes.fromhex(h)
try:
  if t=="byte": print(struct.unpack("<B",b[:1])[0])
  elif t=="word": print(struct.unpack("<H",b[:2])[0])
  elif t=="dword": print(struct.unpack("<I",b[:4])[0])
  elif t=="qword": print(struct.unpack("<Q",b[:8])[0])
  elif t=="float": print(struct.unpack("<f",b[:4])[0])
  elif t=="double": print(struct.unpack("<d",b[:8])[0])
  else: print(struct.unpack("<I",b[:4])[0])
except: print("?")
PY
}

load_state() { PID=""; PKG=""; TYPE="dword"; [ -f "$STATE" ] && . "$STATE"; }
save_state() { echo "PID=$PID" > "$STATE"; echo "PKG=$PKG" >> "$STATE"; echo "TYPE=$TYPE" >> "$STATE"; }

cmd_apps() {
  need_root
  echo "=== RUNNING USER APPS ==="
  for pkg in $(pm list packages -3 2>/dev/null | sed 's/package://'); do
    pid=$(pidof "$pkg" 2>/dev/null | awk '{print $1}')
    [ -n "$pid" ] && printf "%-42s %s\n" "$pkg" "$pid"
  done
}

cmd_attach() {
  need_root
  TARGET="$1"
  [ -z "$TARGET" ] && echo "usage: attach <package|pid>" && exit 1
  if echo "$TARGET" | grep -qE '^[0-9]+$'; then
    PID="$TARGET"
    PKG=$(tr '\0' ' ' < /proc/$PID/cmdline 2>/dev/null | awk '{print $1}')
  else
    PKG="$TARGET"
    PID=$(pidof "$PKG" 2>/dev/null | awk '{print $1}')
  fi
  [ -z "$PID" ] || [ ! -d "/proc/$PID" ] && echo "ERROR: not running: $TARGET" && exit 1
  [ ! -r "/proc/$PID/maps" ] && echo "ERROR: maps unreadable" && exit 1
  save_state
  : > "$RESULTS"; : > "$PREV"
  echo "OK attached pid=$PID pkg=$PKG"
  log "attach $PID $PKG"
}

list_regions() {
  PID="$1"; REGION="${2:-auto}"; MAPS="/proc/$PID/maps"
  case "$REGION" in
    heap) grep -E '\[heap\]|scudo|libc_malloc|jemalloc' "$MAPS" 2>/dev/null ;;
    anon) awk '$2~/^rw/ && ($0~/\[anon/ || NF<6)' "$MAPS" ;;
    all)  awk '$2~/r/' "$MAPS" ;;
    *)    awk '$2~/^rw/ {
            split($1,a,"-"); s=strtonum("0x"a[1]); e=strtonum("0x"a[2]); sz=e-s;
            if(sz>0 && sz<0x20000000) print
          }' "$MAPS" 2>/dev/null || awk '$2~/^rw/' "$MAPS" ;;
  esac
}

cmd_scan() {
  need_root; load_state
  [ -z "$PID" ] && echo "ERROR: attach first" && exit 1
  TYPE="${1:-dword}"; VALUE="$2"; REGION="${3:-auto}"
  [ -z "$VALUE" ] && echo "usage: scan <type> <value> [region]" && exit 1
  W=$(type_width "$TYPE"); HEX=$(value_to_hex "$TYPE" "$VALUE")
  echo "$HEX" | grep -q '^ERR' && echo "ERROR $HEX" && exit 1
  save_state; : > "$RESULTS"
  echo "⚡ Sini scanning pid=$PID $TYPE=$VALUE ($HEX) …"
  P=$(py)
  [ -z "$P" ] && echo "ERROR: install python for full scans (pkg install python)" && exit 1

  list_regions "$PID" "$REGION" | while read -r line; do
    RANGE=$(echo "$line" | awk '{print $1}')
    START_H=$(echo "$RANGE"|cut -d- -f1); END_H=$(echo "$RANGE"|cut -d- -f2)
    START=$(printf "%d" "0x$START_H" 2>/dev/null) || continue
    END=$(printf "%d" "0x$END_H" 2>/dev/null) || continue
    SIZE=$((END-START))
    [ "$SIZE" -le 0 ] && continue
    [ "$SIZE" -gt 67108864 ] && continue
    TMP="$WORKDIR/c.bin"
    dd if="/proc/$PID/mem" of="$TMP" bs=4096 skip=$((START/4096)) count=$(((SIZE+4095)/4096)) 2>/dev/null
    [ ! -f "$TMP" ] && continue
    $P - "$TMP" "$HEX" "$START" "$W" "$RESULTS" <<'PY'
import sys
path,needle_hex,start,width,out=sys.argv[1],sys.argv[2],int(sys.argv[3]),int(sys.argv[4]),sys.argv[5]
needle=bytes.fromhex(needle_hex)
try: data=open(path,"rb").read()
except: sys.exit(0)
idx=n=0
with open(out,"a") as f:
  while n<80000:
    p=data.find(needle,idx)
    if p<0: break
    f.write(f"{start+p:x}|{needle_hex}\n"); n+=1; idx=p+width
PY
    rm -f "$TMP"
  done
  COUNT=$(wc -l < "$RESULTS" 2>/dev/null || echo 0)
  cp "$RESULTS" "$PREV" 2>/dev/null
  echo "OK results=$COUNT"
  log "scan $COUNT"
}

cmd_filter() {
  need_root; load_state
  [ -z "$PID" ] && echo "ERROR: attach first" && exit 1
  MODE="$1"; VALUE="$2"
  [ -z "$MODE" ] && echo "usage: filter <exact|changed|unchanged|bigger|smaller> [value]" && exit 1
  [ ! -f "$RESULTS" ] && echo "ERROR: scan first" && exit 1
  P=$(py); [ -z "$P" ] && echo "ERROR: need python" && exit 1
  NEW="$WORKDIR/rnew.txt"; : > "$NEW"
  HEX=""; [ -n "$VALUE" ] && HEX=$(value_to_hex "$TYPE" "$VALUE")
  $P - "$PID" "$RESULTS" "$NEW" "$MODE" "$TYPE" "$HEX" "$VALUE" <<'PY'
import sys,struct
pid,res,out,mode,typ,hexv,val=sys.argv[1:8]
width={"byte":1,"word":2,"dword":4,"qword":8,"float":4,"double":8}.get(typ,4)
fmt={"byte":"<B","word":"<H","dword":"<I","qword":"<Q","float":"<f","double":"<d"}.get(typ,"<I")
needle=bytes.fromhex(hexv) if hexv and not str(hexv).startswith("ERR") else None
mem=open(f"/proc/{pid}/mem","rb")
count=0
with open(res) as f, open(out,"w") as o:
  for line in f:
    line=line.strip()
    if not line or "|" not in line: continue
    addr_s,oldhex=line.split("|",1)
    try: addr=int(addr_s,16)
    except: continue
    try:
      mem.seek(addr); cur=mem.read(width)
    except: continue
    if len(cur)<width: continue
    keep=False
    if mode=="exact" and needle is not None: keep=(cur==needle)
    elif mode=="changed": keep=(cur.hex()!=oldhex)
    elif mode=="unchanged": keep=(cur.hex()==oldhex)
    elif mode in ("bigger","smaller") and val:
      try:
        cv=struct.unpack(fmt,cur)[0]
        tv=float(val) if typ in ("float","double") else int(val)
        keep=(cv>tv) if mode=="bigger" else (cv<tv)
      except: pass
    elif mode=="exact" and val:
      try:
        cv=struct.unpack(fmt,cur)[0]
        tv=float(val) if typ in ("float","double") else int(val)
        keep=(cv==tv)
      except: pass
    if keep:
      o.write(f"{addr:x}|{cur.hex()}\n"); count+=1
      if count>=80000: break
mem.close(); print(f"OK results={count}")
PY
  mv "$NEW" "$RESULTS"; cp "$RESULTS" "$PREV" 2>/dev/null
  log "filter $MODE"
}

cmd_list() {
  need_root; MAX="${1:-60}"; load_state
  [ ! -f "$RESULTS" ] && echo "(empty)" && exit 0
  echo "=== Sini results (max $MAX) type=$TYPE pid=$PID ==="
  i=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    ADDR=$(echo "$line"|cut -d'|' -f1); HEX=$(echo "$line"|cut -d'|' -f2)
    VAL=$(hex_to_value "$TYPE" "$HEX")
    printf "  0x%-12s  %s\n" "$ADDR" "$VAL"
    i=$((i+1)); [ "$i" -ge "$MAX" ] && break
  done < "$RESULTS"
  echo "--- total $(wc -l < "$RESULTS") ---"
}

cmd_write() {
  need_root; load_state
  ADDR="$1"; T="$2"; VAL="$3"
  [ -z "$VAL" ] && echo "usage: write <addr> <type> <value>" && exit 1
  [ -z "$PID" ] && echo "ERROR: attach first" && exit 1
  ADDR=$(echo "$ADDR" | sed 's/0x//g;s/0X//g')
  HEX=$(value_to_hex "$T" "$VAL")
  echo "$HEX" | grep -q '^ERR' && echo "ERROR $HEX" && exit 1
  P=$(py); [ -z "$P" ] && echo "ERROR: need python" && exit 1
  $P - "$PID" "$ADDR" "$HEX" <<'PY'
import sys
pid,addr,hx=sys.argv[1],int(sys.argv[2],16),sys.argv[3]
b=bytes.fromhex(hx)
with open(f"/proc/{pid}/mem","r+b",buffering=0) as m:
  m.seek(addr); m.write(b)
print("OK wrote",hex(addr))
PY
  log "write $ADDR $VAL"
}

cmd_writeall() {
  need_root; load_state; T="$1"; VAL="$2"
  [ -z "$VAL" ] && echo "usage: writeall <type> <value>" && exit 1
  [ ! -f "$RESULTS" ] && echo "ERROR: no results" && exit 1
  N=0
  while IFS= read -r line; do
    ADDR=$(echo "$line"|cut -d'|' -f1); [ -z "$ADDR" ] && continue
    cmd_write "$ADDR" "$T" "$VAL" >/dev/null 2>&1 && N=$((N+1))
  done < "$RESULTS"
  echo "OK wrote $N addresses"
}

cmd_freeze() {
  need_root; ADDR="$1"; T="$2"; VAL="$3"
  [ -z "$VAL" ] && echo "usage: freeze <addr> <type> <value>" && exit 1
  echo "$ADDR|$T|$VAL" >> "$FREEZE_LIST"
  echo "OK freeze queued"
}

cmd_freeze_loop() {
  need_root; load_state
  [ ! -f "$FREEZE_LIST" ] && echo "no freeze list" && exit 1
  echo "Sini freeze loop on pid=$PID (Ctrl+C stop)"
  while [ -f "$FREEZE_LIST" ]; do
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      A=$(echo "$line"|cut -d'|' -f1); T=$(echo "$line"|cut -d'|' -f2); V=$(echo "$line"|cut -d'|' -f3)
      cmd_write "$A" "$T" "$V" >/dev/null 2>&1
    done < "$FREEZE_LIST"
    sleep 0.12
  done
}

cmd_unfreeze() { rm -f "$FREEZE_LIST"; echo "OK unfrozen"; }

cmd_hexdump() {
  need_root; load_state
  ADDR="$1"; LEN="${2:-64}"
  [ -z "$ADDR" ] && echo "usage: hexdump <addr> [length]" && exit 1
  ADDR=$(echo "$ADDR"|sed 's/0x//g')
  P=$(py); [ -z "$P" ] && echo "need python" && exit 1
  $P - "$PID" "$ADDR" "$LEN" <<'PY'
import sys
pid,addr,ln=sys.argv[1],int(sys.argv[2],16),int(sys.argv[3])
with open(f"/proc/{pid}/mem","rb") as m:
  m.seek(addr); data=m.read(ln)
for i in range(0,len(data),16):
  chunk=data[i:i+16]
  hx=" ".join(f"{b:02x}" for b in chunk)
  asc="".join(chr(b) if 32<=b<127 else "." for b in chunk)
  print(f"{addr+i:08x}  {hx:<48}  {asc}")
PY
}

cmd_watch() {
  need_root; load_state
  ADDR="$1"; T="${2:-dword}"
  [ -z "$ADDR" ] && echo "usage: watch <addr> [type]" && exit 1
  ADDR=$(echo "$ADDR"|sed 's/0x//g')
  W=$(type_width "$T")
  P=$(py); [ -z "$P" ] && echo "need python" && exit 1
  echo "watching 0x$ADDR ($T) — Ctrl+C stop"
  $P - "$PID" "$ADDR" "$T" "$W" <<'PY'
import sys,struct,time
pid,addr,typ,w=sys.argv[1],int(sys.argv[2],16),sys.argv[3],int(sys.argv[4])
fmt={"byte":"<B","word":"<H","dword":"<I","qword":"<Q","float":"<f","double":"<d"}.get(typ,"<I")
last=None
while True:
  try:
    with open(f"/proc/{pid}/mem","rb") as m:
      m.seek(addr); b=m.read(w)
    if len(b)==w:
      v=struct.unpack(fmt,b)[0]
      if v!=last:
        print(time.strftime("%H:%M:%S"), v); last=v
  except Exception as e:
    print("err",e); break
  time.sleep(0.2)
PY
}

cmd_quick() {
  # one-shot workflow helper
  need_root
  PKG="$1"; TYPE="$2"; VAL="$3"; NEW="$4"
  [ -z "$NEW" ] && echo "usage: quick <package> <type> <oldvalue> <newvalue>" && exit 1
  cmd_attach "$PKG" || exit 1
  cmd_scan "$TYPE" "$VAL"
  echo ">>> Change the value IN GAME now, then press Enter <<<"
  read dummy
  cmd_filter changed
  cmd_list 30
  echo "Write all to $NEW? (y/n)"
  read ans
  [ "$ans" = "y" ] && cmd_writeall "$TYPE" "$NEW"
}

cmd_status() {
  load_state
  echo "════ SiniTool ════"
  echo "dir=$WORKDIR"
  echo "pid=$PID pkg=$PKG type=$TYPE"
  echo "results=$(wc -l < "$RESULTS" 2>/dev/null || echo 0)"
  echo "uid=$(id -u)"
  echo "python=$(py)"
}

CMD="$1"; shift 2>/dev/null
case "$CMD" in
  apps) cmd_apps ;;
  attach) cmd_attach "$@" ;;
  scan) cmd_scan "$@" ;;
  filter) cmd_filter "$@" ;;
  list) cmd_list "$@" ;;
  write) cmd_write "$@" ;;
  writeall) cmd_writeall "$@" ;;
  freeze) cmd_freeze "$@" ;;
  freeze_loop) cmd_freeze_loop ;;
  unfreeze) cmd_unfreeze ;;
  hexdump) cmd_hexdump "$@" ;;
  watch) cmd_watch "$@" ;;
  quick) cmd_quick "$@" ;;
  status) cmd_status ;;
  *)
    echo "SiniTool Core — OP memory engine"
    echo "apps attach scan filter list write writeall freeze freeze_loop unfreeze hexdump watch quick status"
    ;;
esac
