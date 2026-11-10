#!/usr/bin/env python3
"""Wait for SYNC (user presses CPU RESET), upload main.bin, run Lab menu tests
then TFLM inference, capture raw UART to LOG.  usage: board_run_lab4.py LOG [labkeys]"""
import re, sys, time, contextlib, io
import serial
ROOT = "/home/kuotzuwei15/NNchip/TinyRISC-V-SoC-Platform/Platform"
sys.path.insert(0, ROOT + "/sw")
import upload
log = sys.argv[1]
keys = sys.argv[2] if len(sys.argv) > 2 else "labcdet"
keys = sys.argv[2] if len(sys.argv) > 2 else "lacbde"
logf = open(log, "w"); buf = ""
def pump(ser):
    global buf
    d = ser.read(4096)
    if d:
        t = d.decode("utf-8", "replace").replace("\r", "")
        buf += t; logf.write(t); logf.flush()
def wait_for(ser, pat, start, timeout):
    t0 = time.time()
    while time.time() - t0 < timeout:
        pump(ser)
        if re.search(pat, buf[start:]): return True
        time.sleep(0.05)
    return False
port = upload.find_port()
ser = serial.Serial(port, 115200, timeout=0.05)
upload.start_vivado_server()
print("Listening on", port, flush=True)
if not wait_for(ser, "SYNC", 0, 900): print("NO SYNC"); sys.exit(3)
print("SYNC", flush=True)
with contextlib.redirect_stdout(io.StringIO()):
    ok = upload.do_upload(ROOT + "/build/sw/main.bin")
if not ok: print("upload failed"); sys.exit(4)
ser.write(upload.BOOT_DONE); ser.flush()
print("uploaded", flush=True)
if not wait_for(ser, r"main> ", 0, 60): print("no main menu"); sys.exit(5)
def send(k): ser.write(k.encode()); ser.flush()
pos = len(buf); send("l"); wait_for(ser, r"lab> ", pos, 30)
for k in keys:
    pos = len(buf); send(k)
    if not wait_for(ser, r"lab> ", pos + 1, 600): print("timeout on lab key", k)
    print("lab key", k, "done", flush=True)
pos = len(buf); send("x"); wait_for(ser, r"main> ", pos, 30)
pos = len(buf); send("t")
if not wait_for(ser, r"Cycles: \d+", pos, 3600): print("timeout on inference")
time.sleep(2); pump(ser)
print("finished", flush=True)
