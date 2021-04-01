packageName = "quic"
version = "0.1.0"
author = "Status Research & Development GmbH"
description = "QUIC protocol implementation"
license = "MIT"

requires "nim >= 1.2.6"
requires "stew >= 0.1.0 & < 0.2.0"
requires "chronos >= 3.0.0 & < 4.0.0"
requires "ngtcp2 >= 0.32.0 & < 0.33.0"
requires "sysrandom >= 1.1.0 & < 2.0.0"
requires "upraises >= 0.1.0 & < 0.2.0"
requires "asynctest >= 0.2.1 & < 0.3.0"

task lint, "format source files according to the official style guide":
  exec "./lint.nims"
