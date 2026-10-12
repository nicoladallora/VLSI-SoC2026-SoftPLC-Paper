# Sustainable SoftPLCs at the Edge

Source code and supplementary material for the paper

> G. I. Noto and N. Dall'Ora, **"Sustainable SoftPLCs at the Edge: An
> Open-Source Path to Right-Sizing and Retrofitting Industrial Automation,"**
> IFIP/IEEE International Conference on Very Large Scale Integration
> (VLSI-SoC 2026), Special Session "Sustainable Intelligence at the Edge".

The paper evaluates a fully open control chain for auxiliary industrial
automation: IEC 61131-3 Structured Text (ST) → OpenPLC → Modbus/TCP → Linux
on a Raspberry Pi 5 (ARM). The evaluation has three parts, and this repository
contains the code for each:

| Paper section | What | Folder |
| --- | --- | --- |
| V-A — IEC 61131-3 compliance campaign (Q1) | Test programs A, B, C | [`openplc/`](openplc/) |
| V-B — Virtual commissioning on the digital twin (Q2) | Quality-control cell FSM, Factory I/O over Modbus/TCP | [`openplc/qc_cell_factoryio/`](openplc/qc_cell_factoryio/), [`docs/modbus_mapping.md`](docs/modbus_mapping.md) |
| V-C — Physical actuation of a SCARA base axis (Q3) | Python axis controller (STEP/DIR/EN on GPIO, TMC2209) | [`scara_a1_axis/`](scara_a1_axis/) |

**Demo video** of the cell under edge control (figshare, CC BY 4.0):
<https://doi.org/10.6084/m9.figshare.32680734>

## Repository layout

```
openplc/
  test_A_syntax_types/          scalars, TIME, ARRAY, STRUCT, ENUM      -> ok_all
  test_B_control_flow_stdlib/   IF/CASE/FOR/WHILE, TON/TOF/TP           -> ok_B
  test_C_modularity/            FUNCTION, FUNCTION_BLOCK, VAR_IN_OUT    -> ok_C
  qc_cell_factoryio/            pick-and-place quality-control cell (FSM)
scara_a1_axis/
  a1_axis.py                    open-loop axis control with homing, ramps, soft limits
docs/
  modbus_mapping.md             Factory I/O <-> OpenPLC Modbus/TCP mapping
  img/                          cell and bench-test photos, configuration screenshots
```

## Software and hardware used

| Component | Version / model |
| --- | --- |
| OpenPLC Editor | v4.5 (beta) |
| OpenPLC Runtime | v3, installed on the Pi with `./install.sh rpi` (web UI on port 8080) |
| Edge device | Raspberry Pi 5 (Broadcom BCM2712, quad-core Cortex-A76), Linux |
| Digital twin | Factory I/O (Real Games), *Modbus TCP/IP Server* driver — commercial license |
| Stepper driver | ADI Trinamic TMC2209, classic STEP/DIR/EN mode |
| Axis control | Python 3 + [`lgpio`](https://abyz.me.uk/lg/py_lgpio.html) |

## Quick start

### Compliance tests (A, B, C)

1. Open the project folder (e.g. `openplc/test_B_control_flow_stdlib/`) in the
   OpenPLC Editor.
2. Run it in the editor's simulator, or compile and upload it to the OpenPLC
   Runtime (*Programs → Upload*, or *Transfer to PLC* from the editor) and start it.
3. Watch the aggregate flag in *Monitoring*: `ok_all` (A), `ok_B` (B), `ok_C` (C).
   All three must be `TRUE`. Each program also exposes the individual `ok_*`
   flags that make up the aggregate.

Timer checks count as passing when they fall within ±1 scan or ±5 % of the
preset, whichever is tighter (cyclic task: 20 ms). For the per-test outcomes and
the toolchain restrictions found, see [`openplc/README.md`](openplc/README.md).

### Quality-control cell on Factory I/O

See [`openplc/qc_cell_factoryio/README.md`](openplc/qc_cell_factoryio/README.md)
and [`docs/modbus_mapping.md`](docs/modbus_mapping.md). Validation followed the
paper's two steps: first an OpenPLC runtime on a PC, then the **same** project on
the Raspberry Pi runtime, both connected to Factory I/O over Modbus/TCP.

### SCARA base axis (A1)

```bash
cd scara_a1_axis
pip install -r requirements.txt     # on the Raspberry Pi
python3 a1_axis.py                  # home, then move to +90°, -90°, 0°
```

Before running, read [`scara_a1_axis/README.md`](scara_a1_axis/README.md):
the motor moves as soon as the script starts.

## Scope

This code supports the paper's claims of **functional feasibility**: standard
compliance, desktop-to-edge portability, and direct actuation. It contains no
power measurements and no life-cycle assessment (see Sec. VI of the paper). The
platform targets auxiliary, **non-safety-critical** functions. The software stop
in `a1_axis.py` and the E-Stop handling in the ST program do **not** replace a
certified safety chain.

## Background

The work comes from G. I. Noto's B.Sc. thesis in Computer Engineering,
*"Automazione industriale open source: progettazione di un sistema di controllo
intelligente con OpenPLC e Raspberry Pi"* (Università degli Studi Guglielmo
Marconi, A.Y. 2025/2026; supervisor N. Dall'Ora). Comments in the source code
are in Italian, as in the thesis.

## How to cite

If you use this code, please cite the paper (the DOI will be added once the
proceedings are published):

```bibtex
@inproceedings{noto2026softplc,
  author    = {Noto, Gioacchino Ivan and Dall'Ora, Nicola},
  title     = {Sustainable {SoftPLCs} at the Edge: An Open-Source Path to
               Right-Sizing and Retrofitting Industrial Automation},
  booktitle = {Proceedings of the IFIP/IEEE International Conference on
               Very Large Scale Integration (VLSI-SoC)},
  year      = {2026},
  note      = {to appear}
}
```

GitHub's *Cite this repository* button reads [`CITATION.cff`](CITATION.cff).

## License

The code (`openplc/`, `scara_a1_axis/`) is released under the [MIT License](LICENSE).
The images in `docs/img/` are not covered by the MIT License and are provided
for reference only. Factory I/O and OpenPLC are third-party products under their
own licenses and are not distributed here.

## Authors

- Gioacchino Ivan Noto — Università degli Studi Guglielmo Marconi
- Nicola Dall'Ora — Università degli Studi Guglielmo Marconi
