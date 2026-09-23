# Linux on Artix-7: First Steps

This is a where-to-begin guide for the three groups on the project. It is not
a plan or a task list. Each group gets a handful of concrete first actions
and a point at which its first steps are done.

Read [ARCHITECTURE.md](ARCHITECTURE.md) first, at least sections 1–3 and the
block diagram. The sections most relevant to each group are listed below.

## Everyone

* **Agree on one shared list of on-board devices:** every sensor and device
  the board-health application must talk to, with its bus (UART, SPI, I²C),
  address and, where one exists, its Linux driver (e.g. `lm75`, `ina2xx`).
  The board designers, FPGA developers and software developers all need it.
* **Set up a lab network** (a separate switch or VLAN) with a boot server
  running DHCP, TFTP and NFS, e.g. `dnsmasq` plus an NFS export. The FPGA
  developers need it for network boot, and the software developers use it for
  the NFS root filesystem. The production boot server will later be built the
  same way.

## Hardware designers (custom board)

Most relevant: ARCHITECTURE.md sections 6 and 8.

The shell in the flash is frozen for the product's life, and only pins the
shell exposes can ever be used. Decisions made on the board therefore stick
for 10+ years. The first steps are about the choices that can't be undone
later.

1. **Draft the FPGA pin plan in Vivado** (an I/O planning project for the
   XC7A100T-FGG484). Assign banks and voltages early and share the result
   with the FPGA developers. It will be the input to the shell design.
2. **Memory-module connector:**
   * room for 2 × 64 MB HyperRAM on a shared bus with two chip selects
     (~14 signals), on a **1.8 V bank**;
   * a few spare signals on the connector, so a different memory type
     (e.g. Octal PSRAM) can be fitted later;
   * a **module ID** on the module (a small I²C EEPROM or ID resistors).
3. **Configuration flash:**
   * choose a SPI flash with a **permanent lock** of its write-protection
     bits (large enough for the ~3.8 MB shell; 16 MB leaves plenty of room);
   * plan for x1 or x2 SPI configuration, because WP# can't be used for
     protection in quad mode;
   * make sure no FPGA pin can remove the write protection.
4. **Ethernet PHY:** the simplest option is the Nexys4DDR's LAN8720A (RMII,
   10/100), because everything proven on the Nexys then carries over. If you
   want gigabit, decide now (RGMII, or SGMII through a GTP), because the
   shell has to support it.
5. **GTP transceivers:** decide whether the 4 GTPs are routed to a connector
   or SFP, including reference clocks. If they aren't routed now, no future
   role can use them.
6. **Route spare FPGA pins** to test points or an expansion connector. The
   shell exposes every pin, so they stay usable for debugging and later
   extensions.
7. **Debug access:** a USB-JTAG + UART bridge like the Nexys4DDR's (FT2232H).
   Vivado, OpenOCD and the serial console then all work over one cable, and
   the FPGA developers' Nexys setup works unchanged.
8. **Board health:** route board supply rails to the XADC auxiliary inputs
   (with suitable dividers), and consider I²C power monitors (e.g. INA2xx)
   and temperature sensors that have mainline Linux drivers.

**First steps done when:** a draft pin plan and the decisions on memory
connector, flash device, Ethernet PHY and GTP routing have been reviewed with
the FPGA developers.

## FPGA developers (Nexys4DDR)

Most relevant: ARCHITECTURE.md sections 4, 6, 7 and 13.

1. **Install the tools:**
   * a Vivado version you're prepared to archive for the product's life;
   * LiteX (see the LiteX README for the current setup script);
   * a RISC-V GCC toolchain;
   * OpenOCD.
2. **Boot Linux on the Nexys4DDR the proven way:** build and load
   [linux-on-litex-vexriscv](https://github.com/litex-hub/linux-on-litex-vexriscv)
   for the Nexys4DDR (VexRiscv RV32, DDR2) and get a Linux shell prompt on the
   UART. This validates the tool installation and the board before anything
   project-specific.
3. **Resource experiment:** build a LiteX SoC for the Nexys4DDR with
   **VexiiRiscv RV64** (FPU, MMU, caches) and record LUT, FF and BRAM usage
   and Fmax. Leave headroom for the shell and peripherals. This answers the
   RV64-versus-RV32 question in ARCHITECTURE.md section 4.
4. **Network boot:** load the kernel over TFTP from the lab boot server and
   mount the root filesystem over NFS. Write the bitstream to the QSPI flash
   so the board boots on its own.
5. **Hand over to the software developers:** a Nexys4DDR that boots into Linux
   with SSH and gdbserver, plus a short README telling a non-FPGA person how
   to power it on, find it on the network and deploy a program.
6. **JTAG debugging:** attach OpenOCD + GDB to the CPU through the same USB
   cable (via BSCANE2) and halt it in the BIOS. This is the bring-up tool for
   everything that follows.
7. **Learn the DFX flow on something trivial:** a static region plus a
   reconfigurable partition with two versions of a blinking LED, using
   Vivado's non-project Tcl flow (UG909). Load the partial bitstream over
   JTAG first, then through ICAPE2 from logic in the static region. Record
   the 7-series restrictions you hit.
8. **Order or build a HyperRAM Pmod adapter** for the later HyperRAM
   experiment, and check which Nexys4DDR Pmod ports have series resistors.

Not yet: designing the real shell/role boundary or the loader. Those belong in
phase 2, once steps 3 and 7 have shown what fits and how the DFX flow behaves.

**First steps done when:** the software developers have a network-booting
Nexys4DDR, the RV64 resource numbers are known, and a trivial partial
reconfiguration through ICAPE2 works.

## Software developers

Most relevant: ARCHITECTURE.md sections 10 and 11.

None of these steps needs FPGA hardware. By the time a Nexys4DDR is available
(see step 5 of the FPGA list), the code should already run on the PC and in
QEMU.

1. **Create the C++ project skeleton** (CMake):
   * a thin hardware-access layer over the standard Linux interfaces
     (`/dev/i2c-N`, `/dev/spidevX.Y`, `/dev/ttyS*`, `/sys/class/hwmon`,
     IIO), so everything above it is plain, portable C++;
   * unit tests (e.g. GoogleTest or Catch2) with mocked hardware access.
2. **Build and test natively on the PC** with AddressSanitizer, UBSan,
   Valgrind and clang-tidy. This is where most bugs should be found; the
   target has little RAM for these tools.
3. **Cross-compile and run without hardware:**
   * install a riscv64 Linux cross compiler (e.g. `g++-riscv64-linux-gnu` on
     Debian/Ubuntu) and user-mode QEMU;
   * run the cross-compiled tests with `qemu-riscv64`.

   Keep the build system architecture-neutral, since the CPU may end up RV32
   (see the FPGA resource experiment). Later, switch to the SDK produced by
   the Buildroot/Yocto build, so compiler and libraries match the target
   exactly.
4. **Boot a full RISC-V Linux in QEMU** (e.g. Buildroot's
   `qemu_riscv64_virt_defconfig`) and practise the target workflow:
   * copy the program over SSH;
   * start it under `gdbserver`;
   * debug it from VS Code on the PC (`cppdbg` with
     `miDebuggerServerAddress`, using `gdb-multiarch`).

   The Nexys4DDR will work the same way.
5. **Talk to real sensors from the PC:** use a USB-to-I²C/SPI adapter that
   has a mainline Linux driver (e.g. CP2112 for I²C), so the sensor shows up
   as `/dev/i2c-N` exactly as on the target. Where a kernel driver exists
   (`lm75`, `ina2xx`, …), read through `hwmon` rather than raw registers.
6. **Logging:** decide the log format and send logs through syslog from the
   start (remote syslog or NFS, per ARCHITECTURE.md section 11), with a RAM
   buffer for network outages.
7. **Package it all as a devcontainer or Docker image** (compiler, QEMU,
   gdb-multiarch, test tools), so onboarding and CI use the same environment.

**First steps done when:** the application skeleton reads at least one real
sensor from a PC, its tests pass natively and under QEMU, and a developer can
set breakpoints in it in QEMU from the IDE.
