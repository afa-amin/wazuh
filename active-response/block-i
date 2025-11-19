#!/usr/bin/python3
import os
import sys
import json
import subprocess
from datetime import datetime

ADD = "add"
DELETE = "delete"
LOG_FILE = "/var/ossec/logs/block-ip.log"


def log(msg):
    try:
        with open(LOG_FILE, "a") as f:
            f.write(f"[{datetime.now()}] {msg}\n")
    except:
        pass


def run_cmd(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    log(f"CMD: {' '.join(cmd)}")
    log(f"OUT: {result.stdout.strip()}")
    log(f"ERR: {result.stderr.strip()}")
    return result.returncode


def iptables_exists(ip):
    chk = subprocess.run(
        ["iptables", "-C", "INPUT", "-s", ip, "-j", "DROP"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return chk.returncode == 0


def block_ip(ip):
    log(f"[+] Blocking IP: {ip}")

    if iptables_exists(ip):
        log("[=] Already exists.")
        return

    run_cmd(["iptables", "-I", "INPUT", "-s", ip, "-j", "DROP"])
    log(f"[OK] Blocked {ip}")


def unblock_ip(ip):
    log(f"[+] Unblocking IP: {ip}")

    if not iptables_exists(ip):
        log("[=] Not found, skip.")
        return

    run_cmd(["iptables", "-D", "INPUT", "-s", ip, "-j", "DROP"])
    log(f"[OK] Unblocked {ip}")


def extract_ip(data):
    params = data.get("parameters", {})

    if "srcip" in params:  # DELETE case
        return params["srcip"]

    alert = params.get("alert", {})
    return alert.get("data", {}).get("srcip")


def main():
    raw = sys.stdin.readline().strip()

    try:
        data = json.loads(raw)
    except Exception as e:
        log(f"[ERROR] JSON error: {e}")
        sys.exit(1)

    command = data.get("command")
    ip = extract_ip(data)

    log(f"[+] Received command={command}, ip={ip}")

    if not ip:
        log("[!] No IP found.")
        sys.exit(0)

    # Only for ADD we perform handshake
    if command == ADD:
        msg = {
            "version": 1,
            "origin": {"name": "block-ip", "module": "active-response"},
            "command": "check_keys",
            "parameters": {"keys": [ip]},
        }
        print(json.dumps(msg))
        sys.stdout.flush()

        response = sys.stdin.readline().strip()
        log(f"[+] Wazuh responded: {response}")

        try:
            resp_json = json.loads(response)
            if resp_json.get("command") != "continue":
                log("[!] Wazuh aborted.")
                sys.exit(0)
        except:
            log("[!] Invalid handshake response.")
            sys.exit(0)

    # Perform action
    if command == ADD:
        block_ip(ip)
    elif command == DELETE:
        unblock_ip(ip)

    log(f"[OK] Finished command {command} for IP={ip}")


if __name__ == "__main__":
    main()
