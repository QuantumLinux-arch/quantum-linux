"""Qué tarjetas gráficas hay, qué driver usan y cuál conviene (solo NVIDIA necesita uno aparte:
AMD e Intel ya vienen con el suyo en Linux).

Generación de NVIDIA según el id del dispositivo (PCI):
  0x1E00 en adelante: Turing o más nueva (GTX 16, RTX 20+)  → nvidia-open-dkms (repos de Arch)
  0x1340–0x1DFF:      Maxwell, Pascal y Volta (GTX 900/1000) → nvidia-580xx-dkms (AUR)
  0x0FC0–0x133F:      Kepler (GTX 600/700)                   → nvidia-470xx-dkms (AUR)
  antes:              Fermi y anteriores                     → nvidia-390xx-dkms (AUR)
"""
import json
import os
import re
import subprocess
import sys

VARIANTS = {
    "open": {"name": "el oficial de código abierto", "aur": False,
             "pkgs": ["nvidia-open-dkms", "nvidia-utils", "lib32-nvidia-utils", "nvidia-settings"]},
    "580xx": {"name": "versión 580, para GTX 900 y 1000", "aur": True,
              "pkgs": ["nvidia-580xx-dkms", "nvidia-580xx-utils", "lib32-nvidia-580xx-utils"]},
    "470xx": {"name": "versión 470, para GTX 600 y 700", "aur": True,
              "pkgs": ["nvidia-470xx-dkms", "nvidia-470xx-utils", "lib32-nvidia-470xx-utils"]},
    "390xx": {"name": "versión 390, para tarjetas muy antiguas", "aur": True,
              "pkgs": ["nvidia-390xx-dkms", "nvidia-390xx-utils", "lib32-nvidia-390xx-utils"]},
}


def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=10).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def nvidia_variant(dev):
    if dev >= 0x1E00:
        return "open"
    if dev >= 0x1340:
        return "580xx"
    if dev >= 0x0FC0:
        return "470xx"
    return "390xx"


def gpus():
    demo = os.environ.get("QUANTUM_DRIVERS_DEMO")          # «10de:2484 nouveau» para probar sin NVIDIA
    out = []
    if demo:
        vid, dev = demo.split()[0].split(":")
        out.append({"vendor": vid, "device": dev, "name": "NVIDIA GeForce RTX 3070 (demostración)",
                    "driver": demo.split()[1] if " " in demo else "nouveau"})
    else:
        block = None
        for line in run(["lspci", "-nnk"]).splitlines():
            m = re.match(r"^\S+ (VGA compatible controller|3D controller|Display controller) \[03..\]: (.+) \[([0-9a-f]{4}):([0-9a-f]{4})\]", line)
            if m:
                block = {"vendor": m.group(3), "device": m.group(4), "driver": "",
                         "name": re.sub(r"\s*\(rev \w+\)$", "", m.group(2))}
                out.append(block)
            elif block is not None and "Kernel driver in use:" in line:
                block["driver"] = line.split(":", 1)[1].strip()
            elif line and not line.startswith(("\t", " ")):
                block = None
    res = []
    for g in out:
        brand = {"10de": "nvidia", "1002": "amd", "8086": "intel"}.get(g["vendor"], "otra")
        name = re.sub(r"^(NVIDIA Corporation|Advanced Micro Devices, Inc\. \[AMD/ATI\]|Intel Corporation)\s*", "", g["name"])
        item = {"brand": brand, "name": name, "driver": g["driver"] or "ninguno", "needs": False, "variant": ""}
        if brand == "nvidia":
            v = nvidia_variant(int(g["device"], 16))
            item.update(variant=v, variantName=VARIANTS[v]["name"], aur=VARIANTS[v]["aur"],
                        pkgs=VARIANTS[v]["pkgs"], needs=g["driver"] != "nvidia")
        res.append(item)
    virt = run(["systemd-detect-virt"]).strip()
    return {"gpus": res, "vm": bool(virt) and virt != "none" and not os.environ.get("QUANTUM_DRIVERS_DEMO"),
            "needs": any(x["needs"] for x in res)}


if __name__ == "__main__":
    print(json.dumps(gpus(), ensure_ascii=False))
    sys.exit(0)
