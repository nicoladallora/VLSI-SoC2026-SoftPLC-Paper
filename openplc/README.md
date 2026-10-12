# OpenPLC projects

There are four projects, each opened as a folder in the OpenPLC Editor. In every
project:

- `project.json` holds the data types (user `STRUCT`/`ENUM`), the task
  configuration, and the program instance.
- `pous/` holds the ST source of the POUs.
- `devices/configuration.json` holds the target board (`OpenPLC Simulator`).

All four projects use a single cyclic task, `task0`, with a **20 ms** interval.

## IEC 61131-3 compliance campaign (paper Sec. V-A, Table II)

Each test collects its checks into boolean flags that you can watch at runtime.
In the paper, the passing checks were verified on both the desktop runtime and
the Raspberry Pi runtime.

### Test A — syntax and type system: [`test_A_syntax_types/`](test_A_syntax_types/)

| Flag | Check |
| --- | --- |
| `ok_scalar` | `BOOL`, `INT`, `DINT`, `REAL` (with tolerance), constant `K` |
| `ok_array` | `ARRAY[1..3] OF INT`, sum = 6 |
| `ok_struct` | user `STRUCT TPOINT (x, y : DINT)`, `x*y = 10` |
| `ok_enum` | symbolic enum `COLOR (red, green, blue)`, `c1 = blue` |
| `ok_time` | `TIME` literal `T#150ms` |
| **`ok_all`** | AND of the above |

`TPOINT` and `COLOR` are defined in `project.json` (`dataTypes`).

### Test B — control flow and standard library: [`test_B_control_flow_stdlib/`](test_B_control_flow_stdlib/)

| Flag | Check |
| --- | --- |
| `ok_for`, `ok_while`, `ok_if`, `ok_case` | `FOR` (1+2+3 = 6), `WHILE`, `IF/ELSE`, numeric `CASE` |
| `ok_ton` | `TON` output TRUE after 150 ms |
| `ok_tp` | `TP` 200 ms pulse observed rising and falling |
| `ok_tof` | `TOF` holds its output ~100 ms after the TP pulse ends |
| **`ok_B`** | AND of the above |

### Test C — modularity: [`test_C_modularity/`](test_C_modularity/)

| Flag | Check |
| --- | --- |
| `ok_func` | `FUNCTION ClampInt` (saturation): `ClampInt(-3,0,10) = 0`, `ClampInt(5,0,10) = 5` |
| `ok_fb` | `FUNCTION_BLOCK EdgeCounter` with internal state and a `VAR_IN_OUT` counter, incremented on the rising edge of a `TP` pulse |
| **`ok_C`** | `ok_func AND ok_fb` |

### Restrictions found (paper Table II)

These three restrictions are in the toolchain's front-end. Code that compiled
behaved the same on the desktop and the ARM runtime. Each restriction has a
mechanical workaround, which the test programs already apply:

| Construct | Outcome | Workaround used here |
| --- | --- | --- |
| `ENUM` with explicit ordinals (`red := 5`) | rejected | symbolic elements only; map to integers with a helper function if needed |
| Aggregate `ARRAY` initializer in the declaration | rejected | `IF NOT initDone THEN ... END_IF` first-scan block (Test A) |
| Generic `TO_*` conversions | not compiled | use typed `<type>_TO_<type>` conversions |

### Toolchain

The campaign used **OpenPLC Editor v4.5 (beta)** with **OpenPLC Runtime v3**.
Compiled `build/` folders are not versioned; the editor regenerates them.

## Quality-control cell: [`qc_cell_factoryio/`](qc_cell_factoryio/)

This is the virtual-commissioning case study (paper Sec. V-B); see its own
[README](qc_cell_factoryio/README.md).
