# Contributing

Thank you for your interest in the SRCI PLC library (TwinCAT and CODESYS).

## How this repository is maintained

The library is developed together with a Python client that is generated from it, and it is tested against a simulated robot controller in a separate test project. Fixes are marked in the code with `// ST-FIX` and listed in `CHANGELOG.md`.

## Reporting bugs and ideas

Please open an [issue](https://github.com/ThorstenBrach/SRCI_CLIENT_PLC/issues/new/choose) and use one of the
forms. Helpful in every report: the version, the robot controller (manufacturer, firmware, SRCI
version and profile), what you did, what you expected and what happened, and the log if you have
one. Results with a robot are very welcome with the form *Experience with a robot* of the client
repositories.

Security problems (for example a robot that moves unexpectedly) please report privately via
*Report a security problem* on the issue page, not as a public issue.

## Pull requests

Pull requests are welcome, also for examples and documentation. Please describe what and why,
refer to the issue and, for a change of behavior, to the SRCI specification (chapter / table).
Every change is reviewed and tested by the maintainer before it is merged or carried over into the
next release.

## Code of conduct

Please follow the [code of conduct](CODE_OF_CONDUCT.md).
