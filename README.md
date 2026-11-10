[![create release](https://github.com/ThorstenBrach/SRCI_CLIENT_PLC/actions/workflows/build.yml/badge.svg)](https://github.com/ThorstenBrach/SRCI_CLIENT_PLC/actions/workflows/build.yml)
[![Latest release](https://img.shields.io/github/v/release/ThorstenBrach/SRCI_CLIENT_PLC?include_prereleases&label=release)](https://github.com/ThorstenBrach/SRCI_CLIENT_PLC/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![SRCI V1.5.9](https://img.shields.io/badge/SRCI_specification-V1.5.9-informational)
![Platforms](https://img.shields.io/badge/platforms-TwinCAT_3_%7C_CODESYS_3.5-lightgrey)
[![Documentation: Wiki](https://img.shields.io/badge/documentation-wiki-2ea44f?logo=github)](https://github.com/ThorstenBrach/SRCI/wiki)

# Standard Robot Command Interface (SRCI) – PLC Client Library

![SRCI](https://raw.githubusercontent.com/wiki/ThorstenBrach/SRCI/images/SRCI_Logo_small.png)

**An open IEC 61131-3 implementation of the SRCI client for PLCs, based on the SRCI specification V1.5.9.**

The Standard Robot Command Interface (SRCI) is an open, manufacturer-independent standard for
controlling industrial and collaborative robots from a PLC. The PLC program uses the same function
blocks for every robot; the robot controller (RC) implements the server side. This library is the
PLC side: it handles the communication with the RC and provides the function blocks of the
specification.

> [!TIP]
> **📖 Documentation: [Project wiki](https://github.com/ThorstenBrach/SRCI/wiki)**
>
> Setup, function blocks, examples and the description of the interface – start here.

More about SRCI: [PROFIBUS & PROFINET International – Robotics / SRCI](https://www.profibus.com/technologies/robotics-srci)

---

## Features

* **119 function blocks** covering the Core, Extended and Optional profiles of the specification:
  motion (axes, direct, linear, circular, spline, pick & place, approach / depart), jogging, group
  control, tool / frame / load data, dynamics, work areas, triggers, I/O, force control, conveyor
  tracking, subprograms, server logs and more.
* **`MC_RobotTaskFB`**: telegram handling, initialization, life sign, sequences and the
  synchronization of the user data (tools, frames, loads, dynamics, software limits) with the RC.
* **135 functions and a complete set of data types** for the commands and responses of the
  specification.
* **Vendor independent:** the same PLC program for every robot with an SRCI server.
* **Delivered as source:** a not compiled library (visible source code) for TwinCAT 3 and CODESYS,
  plus PLCopen XML for other IEC 61131-3 environments.

## Quality and tests

Every function block is tested against the **SRCI SDK simulator** ("SDK in the loop"): the PLC
exchanges real telegrams with the simulated robot controller.

| Test level | Scope |
|---|---|
| TcUnit (TwinCAT) | about **3,750 tests**: methodology of every block (parameters, errors, processing modes, sequences, buffering, timeouts), validation of the robot controller and of the client per topic, synchronization, user data, telegram coding and unit tests without SDK |
| Test case catalog | every test case has a stable ID and a description; the catalog tracks the coverage |
| Real robots | the Core profile has been tested with JAKA, Yaskawa, Stäubli, KUKA and FANUC robots |

Findings of these tests are fixed in the library and marked in the code with `// ST-FIX Fnn`; the
[CHANGELOG](CHANGELOG.md) lists every fix.

## Supported platforms

| Platform | Library | System dependent part |
|---|---|---|
| Beckhoff TwinCAT 3.1 | `RobotLibrary.library` | `RobotLibrarySysDep_Tc.library` |
| CODESYS 3.5 | `RobotLibrary.library` | `RobotLibrarySysDep_3S.library` |
| Other IEC 61131-3 IDEs | `RobotLibrary.xml` (PLCopen XML) | `RobotLibrarySysDep_*.xml` |

## Getting started

1. Download the archive for your platform from the [releases](https://github.com/ThorstenBrach/SRCI_CLIENT_PLC/releases)
   (Beckhoff or Codesys: library, sources and example). For TwinCAT the library is also published
   with Twinpack.
2. Install `RobotLibrary` and the system dependent library of your platform and add both to your
   PLC project.
3. Start with the example project (`Example/Beckhoff`, `Example/Codesys`): one `MC_RobotTaskFB` for
   the communication, then the command blocks (e.g. `MC_EnableRobotFB`, `MC_MoveAxesAbsoluteFB`) on
   the same `AxesGroup`.

> [!NOTE]
> The [**wiki**](https://github.com/ThorstenBrach/SRCI/wiki) describes every block and the setup step by step.

## Repository structure

| Path | Content |
|---|---|
| `RobotLibrary/`, `RobotLibrary.library`, `RobotLibrary.xml` | the library (sources, library file, PLCopen XML) |
| `RobotLibrarySysDep_Tc/`, `RobotLibrarySysDep_3S/` | system dependent parts for TwinCAT and CODESYS |
| `Example/` | example projects for Beckhoff and CODESYS |
| `ST_Coding_Rules.md` | coding rules of the library |
| `CHANGELOG.md` | changes per release |

## Status

The library implements the SRCI specification V1.5.9. Known error of the specification (confirmed
by PI): the AxesGroupID starts at 0, not at 1. The releases are published as pre-releases; test the
library with your robot before using it in production.

## Contributing

Bug reports and feature requests are welcome: please use the
[issue templates](https://github.com/ThorstenBrach/SRCI_CLIENT_PLC/issues/new/choose). Code follows
[ST_Coding_Rules.md](ST_Coding_Rules.md).

## License

MIT, see [LICENSE](LICENSE).

## Disclaimer

This library is based on the SRCI technology of PROFIBUS and PROFINET International (PI), but it is
not an official publication of PI. It is a privately initiated project, created and maintained by
Thorsten Brach, and open to contributors. The use of PI technology only serves the interoperability
of the SRCI interface; there is no connection or partnership between this project and PI.

The software is provided without any guarantee and can be used for private and commercial purposes.
Any use is at the user's own risk and responsibility.

The official approval of PI for publishing this implementation on GitHub has been obtained.

---

[![Donate with PayPal](https://raw.githubusercontent.com/stefan-niedermann/paypal-donate-button/master/paypal-donate-button.png)](https://www.paypal.com/donate/?hosted_button_id=ERN6VH9WA95J6)
