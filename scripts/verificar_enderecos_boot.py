"""Confere cargas explicitas de um script de boot contra as regioes reservadas do DTB.

Uso:
    python verificar_enderecos_boot.py PASTA SCRIPT.cmd [SCRIPT.cmd ...]

PASTA   pasta com aquaman.dtb, Image, initramfs.gz e os demais arquivos que os
        scripts carregam (os tamanhos sao lidos daqui).
SCRIPT  um ou mais scripts de boot do U-Boot, em texto, com linhas do tipo
        "fatload usb 0:1 0xENDERECO arquivo".

Requer o programa dtc (device tree compiler) no PATH.

Limite: nao executa o U-Boot; nao valida a realocacao feita pelo booti nem o
boot real. Os arquivos de entrada nao fazem parte deste repositorio.
"""
import re
import struct
import subprocess
import sys
from pathlib import Path


def main(argv):
    if len(argv) < 3:
        sys.exit(__doc__)
    pasta = Path(argv[1])
    scripts = [Path(p) for p in argv[2:]]

    dts = subprocess.run(
        ["dtc", "-I", "dtb", "-O", "dts", str(pasta / "aquaman.dtb")],
        check=True, capture_output=True, text=True,
    ).stdout
    reserved = dts.split("reserved-memory {", 1)[1].split("\n\tchosen {", 1)[0]
    regions = []
    for name, cells in re.findall(r"([\w,-]+@[\da-f]+)\s*\{\s*reg\s*=\s*<([^>]+)>", reserved):
        values = [int(cell, 16) for cell in cells.split()]
        start = (values[0] << 32) | values[1]
        size = (values[2] << 32) | values[3]
        regions.append((name, start, start + size))
    assert len(regions) >= 4, "Regioes reservadas nao extraidas do DTB"

    kernel = (pasta / "Image").read_bytes()[:64]
    image_size = struct.unpack_from("<Q", kernel, 16)[0]
    print("text_offset do kernel:", hex(struct.unpack_from("<Q", kernel, 8)[0]))
    for script in scripts:
        name = script.name
        source = script.read_text()
        loads = re.findall(r"fatload usb 0:1 (0x[\da-f]+) ([\w.-]+)", source)
        assert sum(filename in ("Image", "initramfs.gz", "aquaman.dtb") for _, filename in loads) == 3, name
        intervals = []
        for address, filename in loads:
            start = int(address, 16)
            size = max((pasta / filename).stat().st_size, image_size) if filename == "Image" else (pasta / filename).stat().st_size
            end = start + size
            assert end <= 0x40000000, (name, filename, "fora da RAM")
            for region_name, low, high in regions:
                assert not (start < high and low < end), (name, filename, region_name)
            for other_name, low, high in intervals:
                if filename.endswith((".bmp", ".bin")) and other_name.endswith((".bmp", ".bin")) and start == low:
                    continue  # Marcadores sequenciais reutilizam a mesma area.
                assert not (start < high and low < end), (filename, other_name)
            intervals.append((filename, start, end))
        print(name, "cargas explicitas fora das regioes reservadas")
    print("Limite: nao executa U-Boot; nao valida relocacao do booti nem boot real.")


if __name__ == "__main__":
    main(sys.argv)
