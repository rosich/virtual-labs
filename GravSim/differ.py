#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ús:
  python resta_xy_dos_logs.py fitxerA.tsv fitxerB.tsv [sortida.tsv]

- Llegeix dos TSV amb capçalera: t, x0, y0, x1, y1, ...
- Alinia per t (inner join) i escriu un TSV amb: t, dx0, dy0, dx1, dy1, ...
  on dxk = xk(A) - xk(B) i dyk = yk(A) - yk(B).
- Si no dones sortida, crea <A_stem>_minus_<B_stem>.tsv a la mateixa carpeta de A.
"""

import sys
import csv
import re
from pathlib import Path

def parse_header_cols(fieldnames):
    """Retorna dos dicts: mapX[idx] = 'x{idx}', mapY[idx] = 'y{idx}'."""
    rx = re.compile(r'^x(\d+)$', re.IGNORECASE)
    ry = re.compile(r'^y(\d+)$', re.IGNORECASE)
    mapX, mapY = {}, {}
    for name in fieldnames or []:
        m = rx.match(name.strip())
        if m:
            mapX[int(m.group(1))] = name
        m = ry.match(name.strip())
        if m:
            mapY[int(m.group(1))] = name
    return mapX, mapY

def read_tsv_by_time(path: Path):
    """Llegeix TSV amb DictReader (tab) i torna: dict_t -> fila(dict), + (mapX,mapY)."""
    with path.open('r', newline='') as f:
        reader = csv.DictReader(f, delimiter='\t')
        if reader.fieldnames is None:
            raise ValueError(f"{path}: falta capçalera TSV.")
        mapX, mapY = parse_header_cols(reader.fieldnames)
        rows_by_t = {}
        for row in reader:
            t = row.get('t')
            if t is None or t == '':
                # ignora files sense t
                continue
            rows_by_t[t] = row
        return rows_by_t, mapX, mapY

def main():
    if len(sys.argv) < 3:
        print("Ús: python resta_xy_dos_logs.py fitxerA.tsv fitxerB.tsv [sortida.tsv]", file=sys.stderr)
        sys.exit(1)

    inA = Path(sys.argv[1])
    inB = Path(sys.argv[2])
    if not inA.exists() or not inB.exists():
        print("Error: algun fitxer d'entrada no existeix.", file=sys.stderr)
        sys.exit(1)

    # Sortida
    if len(sys.argv) >= 4:
        out_path = Path(sys.argv[3])
    else:
        out_path = inA.with_name(f"{inA.stem}_minus_{inB.stem}.tsv")

    # Llegeix
    rowsA, mapXA, mapYA = read_tsv_by_time(inA)
    rowsB, mapXB, mapYB = read_tsv_by_time(inB)

    # Índexs de partícula comuns (present tant a A com a B i amb x i y disponibles)
    idxs = sorted(set(mapXA.keys()) & set(mapXB.keys()) & set(mapYA.keys()) & set(mapYB.keys()))
    if not idxs:
        print("Error: no hi ha cap parella de columnes xk/yk comuna als dos fitxers.", file=sys.stderr)
        sys.exit(1)

    # Clau d'unió: t (intersecció)
    common_t = sorted(set(rowsA.keys()) & set(rowsB.keys()),
                      key=lambda s: float(s))  # s ja és '%.6f' al teu logger, però fem ordre numèric

    # Escriu TSV de sortida
    with out_path.open('w', newline='') as f_out:
        writer = csv.writer(f_out, delimiter='\t')
        # Capçalera: t, dx0, dy0, dx1, dy1, ...
        header = ['t']
        for k in idxs:
            header += [f"dx{k}", f"dy{k}"]
        writer.writerow(header)

        # Files
        for t in common_t:
            rowA = rowsA[t]
            rowB = rowsB[t]
            out_row = [t]
            ok = True
            for k in idxs:
                try:
                    xa = float(rowA[mapXA[k]]); ya = float(rowA[mapYA[k]])
                    xb = float(rowB[mapXB[k]]); yb = float(rowB[mapYB[k]])
                    dx = xa - xb
                    dy = ya - yb
                    out_row += [f"{dx:.6f}", f"{dy:.6f}"]
                except Exception:
                    ok = False
                    break
            if ok:
                writer.writerow(out_row)

    print(f"[OK] Escrit: {out_path}")

if __name__ == "__main__":
    main()
