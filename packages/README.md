# Package profiles

These manifests keep session, power, machine-type, and GPU packages separate.
Blank lines and lines beginning with `#` are ignored. Packages are installed
with `pacman --needed`, so applying a profile repeatedly is safe.

## Recommended profiles

- Every machine: `common/official.txt`
- Desktop/PC: `pc/official.txt` (currently no additions)
- Laptop: `laptop/official.txt`
- Optional laptop measurement: `laptop/optional-diagnostics.txt`
- Detected AMD/Intel/NVIDIA userspace stack: the matching directory in `gpu/`

On current Arch and CachyOS, `mesa` itself provides the AMD VA-API driver;
there is no separate `libva-mesa-driver` package to install.

`power-profiles-daemon` is the only enabled power manager. The installer checks
`common/remove.txt` and asks before removing installed conflicts. It disables
their services first and never removes unrelated packages to force cleanup.
It also checks `obsolete/remove.txt` and offers to remove packages that this
repository used previously but no longer starts or installs.

The laptop diagnostic profile installs `powertop` but does not enable
`powertop --auto-tune`; blanket tuning can regress USB, PCIe, audio, networking,
or discrete-GPU resume. `thermald`, `irqbalance`, kernel parameters, and GPU
power rules are not installed globally because their benefit is hardware
specific.

Each GPU directory separates native packages from optional 32-bit libraries.
The latter are installed only when the `multilib` repository is enabled.

NVIDIA kernel drivers are intentionally excluded from automatic installation.
Driver choice depends on GPU generation and the installed Arch or CachyOS
kernel. The NVIDIA userspace profile is applied only when a kernel-driver
package is already installed; otherwise the installer explains why it skipped
the device.
