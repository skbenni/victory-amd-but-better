# VIctory AMD + XCL Fusion

A unified Windows Direct3D 12 fork built around CGBJ's AMD renderer, with
selected performance work from Belobug and fixes from the VIctory and XCL
lines. Its fast profile prioritizes frame rate and uses the Series S title
profile by default. XCL's allocator source is not included.

The published performance figures below are from an RX 7900 XTX system; this
fusion has not been benchmarked on the RX 6800. Treat the Series S and residency
settings as informed performance choices, not proven RX 6800 gains.

This is a fork of [VIctory](https://github.com/Marvisak/VIctory), a compatibility
layer that runs an Xbox Series title natively on Windows from files the user
supplies.

**This repository contains no game files, code or assets.** You need your own
copy of the game. It is not affiliated with or endorsed by the game's developer
or publisher.

## Upstream benchmark baseline (2026-11-25)

Tested on one machine only: Windows 11, Intel i9-12900K, 64 GB RAM, Radeon
RX 7900 XTX, 1440p, the Series X profile.

| | |
|---|---|
| Menus, videos, loading screens | 30 fps |
| Prologue, indoors | 50-75 ms a frame (13-20 fps) |
| First mission with the boat | 46-53 ms (19-22 fps) |
| Street chase with many cars and people | 100-165 ms (6-10 fps), single frames far longer |
| Outdoors on foot, the camp | 60-90 ms |
| Flying | 42-57 ms |
| Longest session so far | 41 minutes, no crash |
| Memory | 40-46 GB of private memory: **64 GB of RAM recommended** |

It started at 280 ms a frame in the same scenes two days earlier.

What is known to be wrong:

- Trees, plants and far buildings flicker outdoors in some places.
- Rooms with little direct light are too dark without `-RayTracing`.
- Textures of what just came into view appear late while the title streams.
- The first run with a new driver or a new build stutters while the driver makes
  pipelines (`victory warm` makes them ahead). The slow-pipeline queue now
  tracks actual driver compiles, not cache loads; a quick compile removes a
  stale slow entry. This improves warmup scheduling, not steady-state frame
  time.
- Recording a frame in the world makes the title's own watchdog end it.

## How to run it

You need Windows 10/11 x64, a CPU with AVX2, a Direct3D 12 GPU with shader
model 6.6 and mesh shaders, Rust (the toolchain is pinned), the MSVC build
tools, and your own dump of the title.

```powershell
git clone https://github.com/skbenni/victory-xcl-Fusion-AMD
cd victory-xcl-Fusion-AMD
copy victory.example.toml victory.toml      # then set your paths, outside this folder
cargo build --release --locked -p victory
scripts\play.ps1 -Exe <path of your copy's executable>
```

`scripts\play.ps1 -Safe` leaves out the newest, faster ways; try it first when
something is wrong. On the fast path, the launcher chooses up to eight list
workers from the physical CPU core count; `-More @{VICTORY_THIN_THREADS='8'}`
overrides that choice. It runs the release build by default; `-Build diag` selects
a diagnostics build. The fast path defaults to `-Console series-s` for speed;
`-Console series-x` selects the sharper profile. Belobug reported about 5 ms
shorter frames with Series S at 1080p on an RX 7900 XTX, but this has not been
measured on an RX 6800. `-RayTracing` turns the title's ray-traced indirect
light on. The fast path asks the title for a 1920x1080 output; override it with
`-More @{VICTORY_OUTPUT='2560x1440'}`. Belobug reported about 16 ms less GPU
time at 1080p on an RX 7900 XTX; this has not been measured on an RX 6800. It
also requests 60 fps (`VICTORY_FRAME_INTERVAL_MS=16.667`); the actual rate still
depends on the scene and hardware.

The fast path also enables Belobug renderer ports 1 and 5: title graphics memory
can be read in place, and translated constant-buffer reads avoid per-draw CPU
fills. Belobug measured these on an RX 7900 XTX, not this RX 6800. `-Safe` leaves
both off; disable or override either with `-More @{VICTORY_PORT_CONSTANTS='0'}`
or `-More @{VICTORY_PORT_CBV='0'}` if the driver or game behaves incorrectly.
It enables renderer port 6 as well. That shares the title-memory write-guard
lock between faults and refreshes and parallelizes refresh planning; Belobug's
README reports about 2 ms less per frame on its RX 7900 XTX. That result is not
measured on an RX 6800. `-Safe` leaves it off; override it with
`-More @{VICTORY_PORT_GUARD='0'}` if needed.
Renderer port 7 splits write-journal locking and asks for descriptor-heap
snapshots earlier. Belobug reports roughly 1–3 ms less per frame on its RX 7900
XTX; this also remains unmeasured on an RX 6800. `-Safe` leaves it off; override
it with `-More @{VICTORY_PORT_JOURNAL='0'}` if needed.
The fast path also orders and batches renderer-port indirect arguments
(`VICTORY_PORT_CONSTANTS_ORDER=1`, `VICTORY_PORT_CONSTANTS_ORDER_BATCH=48`).
AvatarManz's PR #438 reports 2,500–3,000 such executions in heavy scenes and
31–35 ms/frame of GPU waiting before batching; its batch-size measurements are
from an RX 7900 XTX and have not been verified on an RX 6800. The batch ends at
draws or dispatches that can write buffers, copies, clears, resolves, barriers,
value writes, and waits. Disable it with
`-More @{VICTORY_PORT_CONSTANTS_ORDER='0'}` or
`-More @{VICTORY_PORT_CONSTANTS_ORDER_BATCH='0'}` if the game or driver behaves
incorrectly.
Renderer port 2 patches six byte-checked title routines so descriptor-table
writes mark the slots they change; it also tracks slots copied through
`memcpy`/`memmove` and keeps a periodic page scan as a fallback. Belobug reports
that this replaces scanning roughly 600,000 slots per frame on its RX 7900 XTX.
The six expected code windows were confirmed in the local game executable; a
different build is left unpatched site by site. This result is not an RX 6800
benchmark. `-Safe` leaves the port off; override it with
`-More @{VICTORY_PORT_DESCRIPTORS='0'}` if needed.

The fast path also takes CGBJ's two residency settings: texture mip levels are
allocated on demand when the GPU supports tiled resources, and shader-written
buffers as small as 64 KiB are eligible for GPU-local copies. The first can
lower texture memory held at once; the second can reduce host-memory traffic
but uses some of the GPU's memory budget. Both are omitted by `-Safe` and can
be overridden through `-More`. Their FPS effect has not been measured on the
RX 6800.

For streaming bursts, the fast path starts four DirectStorage workers below
normal priority, following the worker controls proposed in Belobug PR #402.
This gives frame work more CPU priority at the possible cost of slower texture
streaming. `-Safe` uses the default worker count and priority; override them
with `-More @{VICTORY_DSTORAGE_WORKERS='6'; VICTORY_DSTORAGE_PRIORITY='normal'}`.

Before the first run, ahead of time (both can be stopped and go on later):

```powershell
target\release\victory.exe shaders <the shader archives>   # every shader translated, minutes
target\release\victory.exe warm --used                     # pipelines earlier runs drew with, for a new driver or build
```

Commands, debugging switches and upstream's own description:
[docs/README-fxceless.md](docs/README-fxceless.md). Every `VICTORY_...` switch is
described in a comment where it is read.

## What is different here

In short; the reasons and the measurements are in [docs/findings.md](docs/findings.md).

- **List calls are written down, not carried out, on the title's threads**
  (`VICTORY_THIN`): eight threads of ours translate them.
- **Submissions are prepared by a thread of ours and joined**
  (`VICTORY_ASYNC_SUBMIT`, `VICTORY_JOIN_PARTS`), with what can be spread over
  threads spread: refreshes, compares (AVX2), descriptor records, landings.
- **What shaders wrote comes back beside the write guards**, by the dwords that
  changed, on a thread of its own (`VICTORY_RELAY`, `VICTORY_LAND`).
- **Buffer fills that need bytes still on the card are done on the card**
  (`VICTORY_CARD_STEPS`) instead of waiting for it.
- **The title's writes are caught more cheaply**: one view opened at a fault,
  blocks that rest, places in the title's code that look before they write.
- **Textures go up on a copy queue of their own** and a slot shows one only after
  its upload ran, which also ended a device loss that came every 15 minutes or so.
- **Boats float**: textures that shaders write and the title's CPU reads go back
  to title memory (from fxceless and Geckomacabre, on by default here).
- **Frame record and replay** with per-pass times and shader variants compared
  turn by turn ([docs/replay.md](docs/replay.md)).

## Credits

This is a tree of other people's work with more on top. The history is kept, and
commits taken from elsewhere name the commit and its author.

- **[VIctory](https://github.com/Marvisak/VIctory)** by Marvisak and its
  contributors: the loader, the runtime services, the Direct3D 12 back end and
  the shader recompiler.
- **[fxceless/victory-fork](https://github.com/fxceless/victory-fork)**: the fork
  this one started from, and the people whose pull requests it carries.
- **[DexNom/VIctory](https://github.com/DexNom/VIctory)**: ray tracing fixes,
  cube gradients, sparse textures.
- **[Belobug/VIctory-Belobug-AMD](https://github.com/Belobug/VIctory-Belobug-AMD)**:
  renderer ports 1, 2, 5, 6 and 7, the resolution and frame-rate patches,
  pipeline workers, the ambient light idea, and work by romainhedouin. The
  allocation-free shader control-flow walk follows [PR #75](https://github.com/Belobug/VIctory-Belobug-AMD/pull/75).
- **[cputroll/cgbj-reupload](https://github.com/cputroll/cgbj-reupload)**:
  the CGBJ AMD renderer and the performance baseline this fusion builds on.
- **[avatarmanz/VIctory-7900XTX](https://github.com/avatarmanz/VIctory-7900XTX)**:
  the release and launcher lineage used by this checkout.
- **[FQY55kai/ZJOU-VICTORY](https://github.com/FQY55kai/ZJOU-VICTORY)**.
- **[myokex/victory-amd](https://github.com/myokex/victory-amd)**: the guard over
  every view of a page (with Spexivus, joroyt and tightfall), and Joshua Odom's
  reads into title memory.
- **Geckomacabre** and **cxy0072019-sketch**: the texture read-back.
- **[XCL](https://github.com/xcl-dev/xcl)** (GPL-3.0) was read for how the same
  title behaves under another layer. Its free-RAM-based compile admission idea
  was independently implemented for Victory's pipeline workers; no XCL source
  code or allocator code is included.
- This fork's changes were made with [Claude Code](https://claude.com/claude-code).

## License

GPL-3.0-or-later, as VIctory. See [LICENSE](LICENSE); the one file that is not
covered is named in [docs/asset-policy.md](docs/asset-policy.md).
