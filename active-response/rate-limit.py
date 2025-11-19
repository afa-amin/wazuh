#!/usr/bin/python3
import os
import sys
import json
import subprocess
from datetime import datetime

LOG_FILE = "/var/ossec/logs/rate-limit.log"

ADD = "add"
DELETE = "delete"

LIMIT = "5/second"
BURST = "10"


def log(msg):
    try:
        with open(LOG_FILE, "a") as f:
            f.write(f"[{datetime.now()}] {msg}\n")
    except:
        pass


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    log(f"CMD: {' '.join(cmd)}")
    log(f"OUT: {result.stdout.strip()}")
    log(f"ERR: {result.stderr.strip()}")
    return result.returncode


def exists_limit(ip):
    chk = subprocess.run(
        ["iptables", "-C", "INPUT", "-s", ip,
         "-m", "limit", "--limit", LIMIT,
         "--limit-burst", BURST, "-j", "ACCEPT"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    return chk.returncode == 0


def exists_drop(ip):
    chk = subprocess.run(
        ["iptables", "-C", "INPUT", "-s", ip, "-j", "DROP"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    return chk.returncode == 0


def apply_limit(ip):
    log(f"[+] Applying rate-limit to {ip}")

    # Remove existing rules (cleanup)
    remove_limit(ip)

    # Add ACCEPT with rate-limit at top
    run(["iptables", "-I", "INPUT", "-s", ip,
    "-m", "limit", "--limit", LIMIT,
    "--limit-burst", BURST, "-j", "ACCEPT"])

    # Add DROP at bottom (append)
    run(["iptables", "-A", "INPUT", "-s", ip, "-j", "DROP"])

    log(f"[OK] Rate-limit applied to {ip}")


def remove_limit(ip):
    log(f"[+] Removing rate-limit for {ip}")

    if exists_limit(ip):
        run(["iptables", "-D", "INPUT", "-s", ip,
             "-m", "limit", "--limit", LIMIT,
             "--limit-burst", BURST, "-j", "ACCEPT"])

    if exists_drop(ip):
        run(["iptables", "-D", "INPUT", "-s", ip, "-j", "DROP"])

    log(f"[OK] Rate-limit removed for {ip}")


def extract_ip(data):
    params = data.get("parameters", {})

    # DELETE case (timeout): ip is here
    if "srcip" in params:
        return params["srcip"]

    # ADD case: normal alert
    alert = params.get("alert", {})
    return alert.get("data", {}).get("srcip")


def main():
    raw = sys.stdin.readline().strip()

    try:
        data = json.loads(raw)
    except Exception as e:
        log(f"[ERROR] JSON parse failure: {e}")
        sys.exit(1)

    command = data.get("command")
    ip = extract_ip(data)

    log(f"[+] Received AR command: {command}, IP={ip}")

    if not ip:
        log("[!] No IP found. Abort.")
        sys.exit(0)

    # ❗ handshake ONLY during ADD
    if command == ADD:
        msg = {
            "version": 1,
            "origin": {"name": "rate-limit", "module": "active-response"},
            "command": "check_keys",
            "parameters": {"keys": [ip]}
        }

        print(json.dumps(msg))
        sys.stdout.flush()

        response = sys.stdin.readline().strip()
        log(f"[+] Wazuh responded: {response}")

        try:
            resp_json = json.loads(response)
            if resp_json.get("command") != "continue":
                log("[!] Wazuh aborted action.")
                sys.exit(0)
        except:
            log("[!] Invalid handshake.")
            sys.exit(0)

    # Execute
    if command == ADD:
        apply_limit(ip)
    elif command == DELETE:
        remove_limit(ip)

    log(f"[DONE] Completed command {command} for {ip}")


if __name__ == "__main__":
    main()
