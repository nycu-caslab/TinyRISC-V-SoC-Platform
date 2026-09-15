import os
import sys
import serial
import time
import threading
import subprocess
import tempfile
import socket
import serial.tools.list_ports

DDR_BASE = 0x60000000
BOOT_DONE = b"D"

WORDS_PER_TXN = 256
BYTES_PER_WORD = 4 
BYTES_PER_TXN = WORDS_PER_TXN * BYTES_PER_WORD

SERVER_PORT = 3122
SERVER_TCL_PATH = "/tmp/vivado_jtag_server.tcl"
SERVER_LOG_PATH = "/tmp/vivado_jtag_server.log"

def start_vivado_server():
    try:
        with socket.create_connection(('localhost', SERVER_PORT), timeout=0.1):
            return
    except OSError:
        pass

    print(">> [INFO] Vivado background engine not found. Initializing...")

    tcl_code = f"""
    open_hw_manager
    connect_hw_server -url localhost:3121
    open_hw_target

    set device [lindex [get_hw_devices] 0]
    current_hw_device $device
    refresh_hw_device $device

    set hw_axi_list [get_hw_axis]
    if {{[llength $hw_axi_list] == 0}} {{
        puts "ERROR: No JTAG-to-AXI Master found!"
        exit 1
    }}
    set ::hw_axi [lindex $hw_axi_list 0]
    reset_hw_axi $::hw_axi

    proc read_and_execute {{sock}} {{
        set len [gets $sock cmd]
        if {{$len < 0}} {{
            if {{[eof $sock]}} {{
                close $sock
                return
            }}
        }}
        if {{$cmd ne ""}} {{
            set ::client_sock $sock
            if {{[catch {{uplevel #0 $cmd}} err]}} {{
                puts $sock "ERROR: $err"
            }} else {{
                puts $sock "DONE"
            }}
            flush $sock
        }}
    }}

    proc handle_client {{sock addr port}} {{
        fconfigure $sock -buffering line -translation auto
        fileevent $sock readable [list read_and_execute $sock]
    }}

    socket -server handle_client {SERVER_PORT}
    puts "SERVER_READY"
    vwait forever
    """
    with open(SERVER_TCL_PATH, "w") as f:
        f.write(tcl_code)

    with open(SERVER_LOG_PATH, "w") as log_file:
        subprocess.Popen(
            ["vivado", "-mode", "tcl", "-source", SERVER_TCL_PATH, "-notrace", "-nolog", "-nojournal"],
            stdin=subprocess.DEVNULL,
            stdout=log_file,
            stderr=subprocess.STDOUT,
            start_new_session=True 
        )

    start_time = time.time()
    while True:
        try:
            with socket.create_connection(('localhost', SERVER_PORT), timeout=0.5):
                print(">> [INFO] Vivado background engine is ready! Future uploads will be instant.")
                break
        except OSError:
            if time.time() - start_time > 45:
                print("\n>> [ERROR] Vivado server failed to start within 45s. Check board connection.")
                sys.exit(1)
            time.sleep(0.5)

def find_port():
    for p in serial.tools.list_ports.comports():
        if "USB" in p.device or "Digilent" in p.description:
            return p.device
    return None

def kb_terminal(ser, stop_event):
    import tty, termios, select
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        while not stop_event.is_set():
            if select.select([sys.stdin], [], [], 0.05)[0]:
                char = sys.stdin.read(1)
                if char == "\x03":
                    stop_event.set()
                    break
                ser.write(char.encode())
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

def create_jtag_tcl(bin_path):
    with open(bin_path, "rb") as f:
        data_bytes = f.read()

    original_size = len(data_bytes)
    padding_len = (BYTES_PER_TXN - (original_size % BYTES_PER_TXN)) % BYTES_PER_TXN
    data_bytes += b"\x00" * padding_len
    padded_size = len(data_bytes)

    script = tempfile.NamedTemporaryFile(mode="w", suffix=".tcl", delete=False)
    
    sent = 0
    txn_id = 0
    while sent < padded_size:
        chunk = data_bytes[sent : sent + BYTES_PER_TXN]
        data_words = []
        for i in range(0, len(chunk), BYTES_PER_WORD):
            word = int.from_bytes(chunk[i:i + BYTES_PER_WORD], "little")
            data_words.append(f"{word:08X}")

        address = DDR_BASE + sent
        data_str = "_".join(reversed(data_words))
        
        script.write(
            f"create_hw_axi_txn -force txn_{txn_id} $::hw_axi -type WRITE -address {address:08X} -len {WORDS_PER_TXN} -data {{{data_str}}}\n"
            f"run_hw_axi [get_hw_axi_txns txn_{txn_id}]\n"
            f"delete_hw_axi_txn [get_hw_axi_txns txn_{txn_id}]\n"
            f"puts $::client_sock \"PROGRESS {sent + BYTES_PER_TXN} {padded_size}\"\n"
            f"flush $::client_sock\n"
        )
        sent += BYTES_PER_TXN
        txn_id += 1

    script.close()
    return script.name, padded_size

def do_upload(bin_path):
    script_path, padded_size = create_jtag_tcl(bin_path)
    script_path_abs = os.path.abspath(script_path).replace('\\', '/')
    
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect(('localhost', SERVER_PORT))
            s.sendall(f"source {script_path_abs}\r\n".encode('utf-8'))
            
            f = s.makefile('r')
            for line in f:
                line = line.strip()
                if line.startswith("PROGRESS "):
                    _, sent, total = line.split()
                    percent = int(sent) * 100 // int(total)
                    filled = 30 * percent // 100
                    bar = "█" * filled + " " * (30 - filled)
                    sys.stdout.write(f"\rProgress: [{bar}] {percent}% ({sent}/{total} bytes)")
                    sys.stdout.flush()
                elif line == "DONE":
                    print()
                    return True
                elif line.startswith("ERROR"):
                    print(f"\n>> [Vivado Server Log] {line}")
                    return False
            return False
    except Exception as e:
        print(f"\n>> [ERROR] Upload failed: {e}")
        return False
    finally:
        try:
            os.unlink(script_path)
        except OSError:
            pass

def main():
    if len(sys.argv) < 2:
        sys.exit(1)
    bin_path = sys.argv[1]
    port = find_port()

    if not port:
        print(">> [ERROR] No suitable USB serial port found.")
        sys.exit(1)

    start_vivado_server()

    with serial.Serial(port, 115200, timeout=0.1) as ser:
        print(f">> Listening on {port} ...")
        captured = ""

        while True:
            if ser.in_waiting:
                text = ser.read(ser.in_waiting).decode("utf-8", "replace")
                print(text, end="", flush=True)
                captured += text
                if "SYNC" in captured:
                    break
            time.sleep(0.01)

        if not do_upload(bin_path):
            sys.exit(1)

        ser.write(BOOT_DONE)
        ser.flush()
        print(">> Jump to 0x60000000")

        stop_event = threading.Event()
        threading.Thread(target=kb_terminal, args=(ser, stop_event), daemon=True).start()
        try:
            while not stop_event.is_set():
                if ser.in_waiting:
                    sys.stdout.write(ser.read(ser.in_waiting).decode("utf-8", "replace"))
                    sys.stdout.flush()
                time.sleep(0.01)
        except KeyboardInterrupt:
            subprocess.run(["killall", "vivado", "hw_server"], stderr=subprocess.DEVNULL)
            pass
        finally:
            stop_event.set()

if __name__ == "__main__":
    main()