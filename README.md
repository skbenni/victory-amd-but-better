# VIctory AMD But Better

A Windows Direct3D 12 compatibility layer for running a user-supplied Xbox
Series game dump. This repository is an AMD-focused VIctory fork that combines
selected work from CGBJ, Belobug, VIctory, and XCL. It is an experimental
compatibility project, not a game, mod, or official product.

The project targets AMD GPUs and currently includes a fast Series S profile.
Its performance changes have not been benchmarked on every supported GPU. In
particular, upstream measurements from an RX 7900 XTX are not RX 6800 results.

## Current status

- Windows x64, Direct3D 12, AVX2, shader model 6.6, and mesh-shader support are
  required.
- The test system for this fork is Windows 11, Ryzen 5 5600G, Radeon RX 6800,
  and 16 GB RAM. The game can use substantially more memory than physical RAM;
  a pagefile may prevent commit-limit failures but does not replace RAM or VRAM.
- The fast profile uses a 1920x1080 output with the Series S 2/3 render scale
  (1280x720 internal rendering), and requests an 8.333 ms frame interval.
- **FSR4 constraint:** the title's shipped Quality shader tables require a
  1920x1080 maximum upscale output. Setting `VICTORY_OUTPUT=1280x720` causes a
  title-side FSR configuration error and was followed by a divide-by-zero
  crash. The fast launcher now keeps the output at 1920x1080.
- Earlier logs also recorded a D3D12 command-list close failure
  (`0x8007000E`). The latest crash log instead identifies the FSR4 resolution
  mismatch; those are separate failures and this resolution change only
  addresses the latter.

## Build

Install the pinned Rust toolchain, Visual Studio C++ build tools, and a Windows
SDK. Then build the release executable:

```powershell
cargo build --release --locked -p victory
```

## Configure and run

Copy `victory.example.toml` to `victory.toml` and set the paths to your own
game files. Keep the game dump outside this repository. From a normal, non-
administrator PowerShell window, run:

```powershell
scripts\play.ps1 -Exe 'D:\Games\YourDump\game_scarlett_master.exe'
```

The default launcher profile selects Series S and applies the fast-path
settings. `-Console series-x` selects the Series X profile. Use `-Safe` to omit
newer experimental renderer paths when diagnosing a failure, or
`-Build diag` for a diagnostics build. `-More` overrides individual settings;
for example:

```powershell
scripts\play.ps1 -Exe 'D:\Games\YourDump\game_scarlett_master.exe' `
  -More @{ VICTORY_FRAME_INTERVAL_MS = '16.667' }
```

The 120 fps request is a frame interval target, not a promise that the game
will reach 120 fps. Actual performance depends on the scene, GPU, CPU, memory,
driver, and compatibility. If the game crashes, retry with `-Safe` and retain
the generated crash log under `%LOCALAPPDATA%\victory\data\<title>\`.

## Performance notes

The launcher enables the selected renderer ports and scheduling paths that
were reported to help on other AMD systems. They remain experimental on the
RX 6800. The Series S output/render scale reduces pixel work; it may improve
GPU-limited scenes while changing image sharpness. Do not compare results
across different scenes or cache warmup states.

## Repository branches

The maintained fusion work is on `codex/cgbj-xcl-fusion`. Other local branches
are separate experiments and are not automatically included in this branch.
The project includes selected source changes; it does not bundle XCL's
allocator or third-party game files.

## Legal and attribution

This project is licensed under GPL-3.0-or-later; see [LICENSE](LICENSE).
This repository builds on work by the following projects and communities:

- [VIctory](https://github.com/Marvisak/VIctory): compatibility layer,
  loader, runtime, D3D12 backend, and shader recompiler.
- [CGBJ reupload](https://github.com/cputroll/cgbj-reupload): AMD renderer
  baseline and residency work.
- [Belobug AMD](https://github.com/Belobug/VIctory-Belobug-AMD): selected
  renderer ports and performance work.
- [AvatarManz VIctory 7900XTX](https://github.com/avatarmanz/VIctory-7900XTX):
  launcher and release lineage.
- [XCL](https://github.com/xcl-dev/xcl): researched for compatibility and
  allocator behavior; XCL allocator source is not included here.

Other upstream contributors are credited in the commit history and relevant
source files. This repository contains no game code, assets, or dumps and is
not affiliated with or endorsed by the game's developer or publisher. You
must supply files you are legally entitled to use.
