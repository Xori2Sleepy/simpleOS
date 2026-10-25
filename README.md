# (Not So) Quick and Dirty Bootloader (QADB)
A custom semi-general purpose bootloader written in assembly for x86 little-endian systems, responsible for loading a kernel from disk, preparing the processor and memory environment, and transferring control to the kernel. The bootloader itself is assemble using NASM and the image is build using Makefile as a flat assembly format for simplicity, it and have it own custom kernel header format to pass metadata and information to the bootloader. It is build with a goal to support any kernel that can make use of the available boot service, though the kernel might need to be modify in order to read the boot infomration that passed by the bootloader hence it is semi-general purpose. Notes that the detail provided above may change as the project are being continuously update, especially the point about how it is build and assemble. 

WARNING: Run this bootloader and the kernel at YOUR OWN RISK. Although the bootloader lack disk-writing functions (for now) and the most damage it can do is soft-bricking your computers, various factor can potentially harm or lead to unwanted behaviors in the machine. I take no responsibility if the user's machine got damage in running my program.

## Table of Content
- [Why build this?](#why-build-this?)
- [How is it build?](#how-is-it-build?)
- [Architecture and Boot sequence](#architecture-and-boot-sequence)
  - [Ram Layout](#ram-layout)
  - [Kernel Header](#kernel-header)
  - [Boot sequence](#boot-sequence)
- [Key Features](#key-features)
- [Project Layout](#project-layout)
- [Build requirement](#build-requirement)
- [Contact](#contact)

## Why build this?
Honestly, curiosity was probably the biggest reason I started this project. I mean who wound't want to know what happen underneath your programs?

There was another reason, though. I'd spent the past seven months learning assembly (as of July 2026 when I started the project), and I wanted to put that knowledge to use. Assembly is a powerful skill to have, but outside areas like low-level systems programming, firmware, and reverse engineering, opportunities to use it directly can be pretty limited. Building my own bootloader gave me an excuse to do something practical with it.

More importantly, why not?



## How is it build?
This section gives a little insight into how the project started, how I build it, and some of the things I've learned along the way. It's not meant to be too technical.

Long story short, I originally planned to write the kernel and give it a tiny bootloader to get it running (hence the name *Quick and Dirty Bootloader*). But after actually getting into bootloader programming, I got distracted by how fun it was and I somehow ended up with around 8,000 lines of assembly.

One of the biggest challenges has been debugging, closely followed by the *"What does this even mean?"*. The [OSDev Wiki](https://wiki.osdev.org/) has been one of my main starting points. It provides a pretty comprehensive list of things to implement, although I did find that a lot the explaination on here quite confusing so I also consult other resources.

Debugging has been its own adventure. I use GDB alongside QEMU, which means connecting to a debugging port and occasionally doing some address arithmetic just to get a breakpoint in the right place. For example, I have to take an instruction's offset from the NASM listing, account for where the code is loaded in memory, and then set a breakpoint at the resulting address. After that, it's a matter of examining memory with commands like `x/gx` and figuring out what on earth the machine is doing. Don't even get me started on memory corruption that seem to happen every few days and take hours to find.

### Some Things I Used Along the Way
A few resources I used. There is more but I only used it briefly so I did not bookmark it.

- [OSDev Wiki](https://wiki.osdev.org/) — My general starting point for operating system development.
- [Operating System Design: The X-Boot Project](https://www.fysnet.net/osdesign_book_series.htm) — A series of articles about designing an operating system from scratch.
- [Operating Systems: From 0 to 1](https://github.com/tuhdo/os01/blob/master/Operating_Systems_From_0_to_1.pdf) — A book on building an operating system from the ground up.
- [A20 Line — OSDev Wiki](https://wiki.osdev.org/A20_Line) — Useful for understanding one of the many little quirks of x86 booting.
- [FreeVGA](http://www.osdever.net/FreeVGA/vga/crtcreg.htm) — Documentation on VGA hardware and its registers.
- [Ralf Brown's Interrupt List](https://www.ctyme.com/intr/alpha.htm) — A reference for old PC BIOS interrupts and low-level system interfaces.



## Architecture and Boot sequence

### RAM layout
The bootloader mainly operate inside the low-memory (under 1mb) (with the exception of VBE’s framebuffer) as it is more predictable than high-memory. The memory layout is as follow:

| Address Range | Size | Purpose and Bootloader Usage |
|:---|---:|:---|
| `0x00000–0x003FF` | 1 KiB | **Interrupt Vector Table (IVT).** Contains real-mode interrupt vectors used by BIOS services. |
| `0x00400–0x004FF` | 256 B | **BIOS Data Area (BDA).** Contains BIOS-maintained system and hardware information. |
| `0x00500–0x00FFF` | 2.75 KiB | **Low-memory workspace.** Available space depends on the boot environment and any additional reservations. |
| `0x01000–0x05EFF` | ~19.75 KiB | **Scratch Pad.** Temporary workspace for bootloader routines, buffers, and intermediate data. Usable space is bounded by the next reserved region and any other allocations. |
| `0x05F000–0x05FFFF` | 4 KiB | **Higher-Half Paging Structure.** Reserved for the higher-half paging structure beginning at `0x5F000`. |
| `0x060000–0x07BFF` | ~7.0 KiB | **Low-memory workspace.** Additional space below the bootloader's Stage 1 load address, subject to other reservations. |
| `0x07C00–0x07DFF` | 512 B | **Stage 1 Bootloader.** Conventional BIOS boot-sector loading address. |
| `0x07E00–0x7FFFF` | ~481.5 KiB | **Stage 2 and Temporary Workspace.** Stage 2 begins at `0x7E00`; further use depends on its actual size and other reserved memory. |
| `0x80000–0x84FFF` | 20 KiB | **Boot-Time Paging Structures.** Reserved starting at `0x80000` for page tables used during the initial paging setup. |
| `0x85000–0x09FBFF` | ~622.75 KiB | **Remaining Conventional Memory.** Potential workspace, subject to the system memory map and other reservations. |
| `0x09FC00–0x09FFFF` | 1 KiB | **Extended BIOS Data Area (EBDA).** Reserved for firmware use; the actual EBDA location should be obtained from the BIOS Data Area. |
| `0x0A0000–0x0BFFFF` | 128 KiB | **Video Memory.** Memory-mapped video regions; availability depends on the active display mode and hardware. |
| `0x0C0000–0x0FFFFF` | 256 KiB | **Video ROM and System Firmware.** Memory-mapped option ROM and system BIOS regions. |


#### Higher-Half Paging

The higher-half paging structures begin at physical address `0x5F000`. This region is reserved for constructing the mappings required to access the kernel at its higher-half virtual address.

#### Boot-Time Paging

The initial paging structures begin at physical address `0x80000`. They are used to establish the mappings required for the transition into 64-bit mode and the initial kernel environment, covering the intended physical address range of approximately 1–4 GiB depending.

The actual coverage depends on the paging levels and entries configured by the bootloader, main variable include the VBE's framebuffer location.

#### Scratch Pad

The scratch pad begins at physical address `0x1000`. It provides temporary storage for bootloader routines and intermediate data.

The available space is bounded by reserved memory regions and any additional allocations made during boot. Individual routines must ensure that their buffers do not overlap the bootloader, paging structures, or other live data.

#### Notes

- All addresses in this section above refer to **physical addresses**, unless explicitly stated otherwise.
- The memory map describes the bootloader's intended reservations, not a guarantee that every unreserved address is available RAM.
- The memory layout above only describe the first 1mb of the RAM space, any memory above that is mapped by the BIOS e820 function in the bootloader.

### Kernel Header

The kernel image begins with a custom header identified by the four-byte magic value `QADB`. The header describes the kernel image, its loading requirements, its entry points, and optional hardware or memory configuration requirements.

The bootloader uses this metadata to determine how the kernel should be loaded and initialized.

#### Header Structure

| Field | Size | Description |
|:---|---:|:---|
| `magic` | 4 bytes | Identifies the image format. Expected value: `QADB`. |
| `header_version` | 4 bytes | Version of the header format. Currently `0`, reserved for future use. |
| `header_size` | 2 bytes | Total size of the header in bytes, calculated from the start and end labels. |
| `check_sum` | 4 bytes | Image checksum. Initialized to zero and populated by the finalization script (when calculating check it is a good idea to zeroed out the check sum field to avoid a "catch 22" situation). |
| `kernel_version` | 2 bytes | Kernel version field. Currently `0`. |
| `kernel_name` | 4 bytes | Kernel name field. Currently `0`; intended representation and encoding are not yet specified. |
| `load_address` | 8 bytes | Preferred physical load address. Currently `0x100000`. |
| `image_size` | 8 bytes | Image size field, if the kernel is build on flat binary (which is not recommended) you can populate it easily with a start and end label, else if you are using linker script you can populate it later with either a python script or the linker script iself. The exact meaning of the size should match the loader's validation rules. |
| `alignment` | 4 bytes | Alignment requirement. Currently `0`, unused. |
| `entry32` | 4 bytes | 32-bit entry-point offset relative to the start of the image. Leave as `0` if not use. |
| `entry64` | 4 bytes | 64-bit entry-point offset relative to the start of the image, Leave as `0` if not use. |
| `stack_size` | 4 bytes | Requested stack size.|
| `stack_top` | 4 bytes | Preferred stack-top address. This can be reallocated by the bootloader depending on the situation|
| `required_cpu` | 4 bytes | CPU feature requirements. Bit 0 represents NX and bit 1 represents SSE4.2 in the current comment; confirm the actual encoding before relying on it. |
| `flags` | 4 bytes | Kernel image flags describing optional features and requirements. [See more detail](#image-flags) |
| `minimum_memory` | 8 bytes | Minimum memory requirement, intended for video-related configuration. Currently `0`. [See more detail](#cpu-requirment)|
| `preferred_bpp` | 4 bytes | Preferred framebuffer color depth in bits per pixel. Currently only support bpp of `32`. |
| `preferred_width` | 4 bytes | Preferred display width in pixels. |
| `preferred_height` | 4 bytes | Preferred display height in pixels.  |

#### Image Flags

The `flags` field describes the requested execution environment and optional kernel capabilities.

| Bit | Name | Description |
|---:|---|---|
| 0 | `VBE_GRAPHIC` | Requests graphics-mode to be on before jumping to kernel. |
| 1 | `LONG_MODE` | Indicates that the kernel requires 64-bit long mode before jumping to kernel, this also imply a require boot-time page tables. |
| 2 | `FRAMEBUFFER_REQUIRE` | Indicates that graphic need to be available but do not need to on before jumping to kernel. |
| 3 | `CHECK_SUM` | Indicates that checksum validation is requested. |
| 4 | `HIGHER_HALF` | Indicates that the kernel uses a higher-half virtual address layout. |
| 5 | `KERNEL_REALLOCATABLE` | Indicates that the kernel may be loaded at a different physical address. |

#### CPU Requirements

The `required_cpu` field identifies processor capabilities needed by the kernel.

| Bit | Feature |
|---:|---|
| 0 | NX |
| 1 | SYSCALL |
| 2 | RDTSCP |
| 3 | SSE4.2 |
| 4 | POPCNT |
| 5 | AES |
| 6 | APIC |

#### Boot Handoff

The current design follow the following register convention:

| Execution mode | Boot information pointer | Data segment register |
|:---|:---|:---|
| 64-bit | `RAX` | `DI` |
| 32-bit | `EAX` | `DI` |

These are the intended conventions in the current source. May change in the future

#### Header Size and Finalization

The `header_size` field can be calculated from the distance between `kernel_header` and `kernel_header_end`.

The `image_size` and `check_sum` fields can finalized by the build-time Python script. The finalization procedure must define precisely which bytes contribute to the image size and checksum, including whether sector padding is included.

#### Current Limitations

Several fields are reserved or not yet fully specified, including `header_version`, `kernel_version`, `kernel_name`, `alignment`, and `entry32`.

Though the Quick And Dirty (QAD) bootloader is intended to be general purpose, the current kernel header may still lack some needed boot service. But for a basic toy-kernel, the boot service already provided should more than sufficient.

### Boot sequence
The following is the intended boot sequence. Notes that this is not intended to be a detail technical documentation, it is only a brief overview of what is actually happening in the bootloader.

#### Stage 1
The legacy bios load stage 1 (512 bytes at the start of the image) that end in the 2 bytes boot signature into `0x0000:0x7c00`. First stage main jobs is to load stage 2 from disk (located exactly 512 bytes from starting address) to `0x0000:0x7e00`. It can use either older CHS or the newer logical block addressing (LBA) to perform it intended purpose, if it failed it will attempt to reload the disk and perform the operation for a few more time before halting the CPU.

#### Stage 2
Stage 2 is split in 3 main subsection: 16 bits, 32 bits, and 64 bits.

##### 16 bits
| Order | Function | Description and failure handling |
|---:|---|---|
| 1 | `get_cpuid` | Checks whether the processor supports the `CPUID` instruction before attempting to query processor capabilities. It then collects information needed by later stages, including information about the available CPU features. If `CPUID` is unavailable, the boot process pauses rather than proceeding as though the required processor information had been obtained. If important leaves return missing or unexpected information, the function records the problem in `boot_report` for later inspection. |
| 2 | `enable_a20` | Enables the A20 address line, allowing the processor to address memory above the first megabyte without the address wrapping around at the 1 MiB boundary. This is necessary for the subsequent memory operations and loading the kernel into higher physical addresses. The implementation uses fallback methods to improve compatibility with different BIOS and hardware environments. It also retains commented-out, less common techniques for unusual systems. These are intentionally not enabled by default because their behavior may depend on the specific hardware or platform; users familiar with the relevant systems can investigate and enable them when appropriate. |
| 3 | `detect_memory_e820` | Queries the BIOS for the system memory map using the E820 interface. The returned entries describe memory regions and their types, providing the information needed to determine which physical memory ranges are usable. The function also performs some initial cleanup of the collected entries. If E820 fails, the implementation has an E801 fallback path. When that fallback is used, the boot report records that the memory map came from E801, allowing later stages or the kernel to distinguish it from a successful E820 result. If both methods fail, the bootloader halts. |
| 4 | `memory_map_sanitation` | Processes the collected memory map before it is used for memory allocation. Since the E820 collection routine already performs some basic cleanup, this function focuses primarily on organizing and consolidating the entries. It sorts the entries using a variation of insertion sort and merges compatible adjacent or overlapping regions where appropriate. This produces a more consistent memory map for subsequent address-selection and allocation decisions. |
| 5 | `kernel_header_load` | Reads the kernel header from disk into temporary scratch space before copying its fields into the bootloader's designated data structure. The header provides information needed to decide how to load and enter the kernel. This routine supports both CHS and LBA disk-reading methods. If the header cannot be loaded successfully, the bootloader halts. |
| 6 | `kernel_header_read` | Examines the loaded header and checks that it is valid enough to be used by the bootloader. This includes checking the header's magic value (`QADB`) and rejecting a header whose magic does not match. Invalid header data causes the bootloader to halt instead of continuing with an unrecognized kernel image. |
| 7 | `kernel_load_16` | Loads the kernel image into its selected physical memory location. Rather than loading the entire image directly into its final destination in one operation, the routine reads chunks into a temporary low-memory scratch area and then copies them to the destination. It uses unreal mode to access memory beyond the ordinary real-mode addressing limit while retaining the ability to use BIOS disk services. Before loading, it checks whether the requested physical address and image size can be accommodated. If the preferred location is unavailable, the `KERNEL_REALLOCATABLE` header flag determines whether the loader is allowed to search for another suitable memory region. If relocation is not permitted, or no suitable region can be found, the bootloader halts. |
| 8 | `get_bios_cursor` | Saves the current BIOS text-mode cursor position before leaving real mode. It converts the row and column into a flat text-cell index using `(row × 80) + column` and stores the result in scratch memory. This allows later code to preserve the cursor position when transitioning to a graphics or protected-mode environment, rather than unnecessarily clearing or restarting the text display. |
| 9 | `lgdt` and protected-mode preparation | Disables interrupts, masks non-maskable interrupts through the CMOS/NMI control port, and loads the Global Descriptor Table (GDT) descriptor into the processor's GDTR register. It then prepares the value of `CR0` with the Protection Enable (`PE`) bit set. The bootloader also performs its final pre-transition display handling. |
| 10 | Protected-mode transition | Writes the prepared value to `CR0`, enabling protected mode, and performs a far jump through the 32-bit code-segment descriptor to `protected32_entry`. Execution then continues in the 32-bit portion of Stage 2. |

The CPUID, A20, memory-detection, memory-map processing, header-loading, header-validation, and kernel-loading routines run in that order. The later display handling and GDT setup prepare the processor to leave real mode.

**Failure policy:** The bootloader distinguishes between recoverable compatibility fallbacks and conditions that make it unsafe to continue. For example, it can try another disk-addressing method or memory-detection interface, but it stops when required processor information is unavailable, memory detection fails entirely, the kernel header is invalid, or the kernel cannot be loaded into a suitable region.

#### Notes on compatibility and fallback behavior

Some hardware initialization routines contain additional fallback methods beyond the common paths. The A20 routine is one example: the default path covers the primary methods, while less common techniques remain commented out for users who have a specific reason to test them. These methods should not be treated as universally safe or reliable across all machines.

Likewise, the E801 memory-detection fallback is not equivalent to a successful E820 memory map. The boot report records the fallback so that later code can identify the source of the memory information and decide whether it meets the system's requirements.

The boot report is intended to preserve diagnostic information about these decisions rather than silently treating every fallback as an ordinary success.

##### 32 bits - protected mode

The 32-bit portion of Stage 2 runs after the processor has entered protected mode. At this point, the bootloader can use its protected-mode terminal and graphics routines, perform the final kernel compatibility checks, and prepare the environment required to transfer control to the kernel.

The bootloader supports two possible handoff paths: launching a 32-bit kernel directly, or enabling long mode and transferring execution to the 64-bit portion of Stage 2 first.

| Order | Function or operation | Description and failure handling |
|---:|---|---|
| 1 | `protected32_entry` | Entry point for the 32-bit protected-mode portion of Stage 2. Interrupts are disabled, and the data-segment registers (`DS`, `SS`, `ES`, `FS`, and `GS`) are initialized using the 32-bit kernel data-segment descriptor. The stack pointer is set to physical address `0x7C00`, establishing a known stack location before further initialization. |
| 2 | `terminal_initialize` | Initializes the bootloader's terminal interface. This provides a consistent way for subsequent routines to display status messages and diagnostic information in protected mode. |
| 3 | `terminal_print_string32` | Displays a welcome message indicating that execution has reached the 32-bit portion of the bootloader. The call uses the bootloader's terminal interface, passing the message address, starting position, and display attribute through registers. |
| 4 | `kernel_stack_compute` | Computes the stack configuration to be used by the kernel. This prepares the stack information required for the eventual handoff, based on the kernel's configured stack parameters and the bootloader's allocation logic. |
| 5 | `kernel_check_required_cpu` | Checks the CPU features required by the kernel, using the requirements stored in `kernel_info.required_cpu`. The function receives the address of the requirement data. If the required CPU features are unavailable, it returns with the carry flag set and the bootloader stops the launch sequence. |
| 6 | `kernel_check_required_flags` | Checks whether the kernel's required execution or boot features can be satisfied by the current bootloader environment. If a required condition cannot be met, the function signals failure through the carry flag, and the bootloader displays a requirement-failure message before halting. |
| 7 | `check_long_mode_paging` | Determines whether the kernel's configuration requires the long-mode execution path and the associated paging setup. If long mode is required, the function returns with the carry flag set and execution branches to `jmp_long_mode`. Otherwise, the bootloader proceeds with the direct 32-bit kernel handoff. |
| 8A | Direct 32-bit kernel handoff | If long mode is not required, the bootloader prepares the handoff registers: `EAX` receives the address of `boot_info`, and `DI` receives the kernel data-segment selector. It calculates the kernel's physical entry address by adding `kernel_info.entry32` to `boot_info.effective_load_address`. The resulting address and the 32-bit code-segment selector are stored in a far pointer, and execution transfers to the kernel using a far indirect jump. If execution unexpectedly continues past the jump, the CPU is halted. |
| 8B | `jmp_long_mode` | If long mode is required, the bootloader enables the CPU's long-mode feature by setting the Long Mode Enable (`LME`) bit in the Extended Feature Enable Register (`EFER`), accessed through the `IA32_EFER` model-specific register. It then sets the Paging (`PG`) bit in `CR0` and performs a far jump through the 64-bit code-segment descriptor to `long64_entry`. This transfers execution to the 64-bit portion of Stage 2, which continues the transition into 64-bit operation. |
| 9 | `halt32` | Provides a protected-mode halt routine. It prints a CPU-halted message, disables interrupts, and enters a permanent `HLT` loop. This prevents the bootloader from continuing when execution cannot safely proceed. |

The CPU and kernel compatibility checks occur before either handoff path. This prevents the bootloader from knowingly launching a kernel when its declared CPU or execution requirements are not satisfied.

**Direct 32-bit handoff.** When the kernel does not require long mode, the bootloader calculates the entry address from the kernel's actual physical load address and its image-relative entry offset. It then performs a far indirect jump using the kernel code-segment selector. This allows the kernel to be loaded at a different physical address without requiring the entry point to be hardcoded.

**64-bit handoff.** When the kernel requires long mode, Stage 2 enables the CPU's long-mode and paging controls, then transfers to the 64-bit entry point. The 64-bit portion is responsible for continuing the transition and preparing the final execution environment for a 64-bit kernel.

##### 64 bits — Long-mode

The 64-bit portion of Stage 2 executes after the processor has transitioned into long mode.

| Order | Function or operation | Description |
|---:|---|---|
| 1 | `long64_entry` | Entry point for the 64-bit portion of Stage 2. The segment registers are initialized to selector `0`, and the stack pointer is set to `0x7C00`. This establishes the initial execution environment before the remaining setup. |
| 2 | `terminal_initialize_64` | Initializes the 64-bit terminal interface so that the bootloader can continue displaying status messages after entering long mode. |
| 3 | Update `boot_report` | Sets bit 6 of `boot_report` to record that the processor has successfully reached long mode. This provides diagnostic information for later stages and the kernel. |
| 4 | `terminal_print_string64` | Prints confirmation that long mode has been entered successfully, followed by a message indicating that control is about to be transferred to the kernel. |
| 5 | Kernel handoff | Places the address of `boot_info` in `RAX` and the data-segment selector in `DI`. It calculates the kernel's physical entry address by adding `kernel_info.entry64` to `boot_info.effective_load_address`, then jumps directly to the resulting address. Because the processor is already executing in 64-bit mode, the handoff uses a normal indirect jump rather than another far jump. |
| 6 | `halt64` | Provides a permanent halt routine that prints a diagnostic message, disables interrupts, and repeatedly executes `HLT`. It is intended for situations where execution cannot safely continue. |

At this point, the bootloader has completed its transition into long mode and is ready to transfer execution to the kernel. The kernel entry address is calculated at runtime using the effective physical load address and the image-relative entry offset, allowing the entry point to follow the kernel's actual load location.



## Key Features

Several important routines have already been explained in the [Boot Sequence](#boot-sequence). This section provides an overview of the main features and links to their implementations or explanations where appropriate.

- **Memory Map Processing** — Collects the BIOS memory map, sorts entries, and merges compatible regions to prepare the map for later memory allocation. See [16-bit Mode](#16-bits).
- **Kernel Loading and Relocation** — Loads the kernel in chunks using a temporary low-memory buffer, checks whether the requested memory region is suitable, and searches for another region when relocation is allowed. See [16-bit Mode](#16-bits).
- **Kernel Header Validation** — Reads the `QADB` kernel header and checks its magic value before using the header information to load and launch the kernel. See [16-bit Mode](#16-bits).
- **Kernel Memory and Stack Setup** — Checks kernel memory requirements and computes the kernel stack configuration from the header's settings. See [16-bit Mode](#16-bits) and [32-bit Protected Mode](#32-bits---protected-mode).
- **CPU and Feature Compatibility** — Checks processor capabilities and verifies the kernel's declared CPU and execution requirements before handing over control. See [16-bit Mode](#16-bits) and [32-bit Protected Mode](#32-bits---protected-mode).
- **Real Mode and Protected Mode Transition** — Prepares the GDT, configures the processor, and transfers execution from 16-bit real mode into 32-bit protected mode. See [16-bit Mode](#16-bits).
- **32-bit and 64-bit Kernel Handoff** — Supports both direct handoff to a 32-bit kernel and a transition into long mode for a 64-bit kernel. The kernel entry address is calculated using the actual load address and the entry offset from the header. See [32-bit Protected Mode](#32-bits---protected-mode) and [64-bit Long Mode](#64-bits--long-mode).
- **Boot Information and Diagnostics** — Maintains boot information and diagnostic flags, including the effective kernel load address, memory map, and recorded boot-stage status, for later stages to inspect.
- **Terminal Abstraction** — Provides a shared interface for printing strings and characters, changing colors, clearing the screen, and moving the cursor through VGA text mode or VBE framebuffer output. See [Terminal Abstraction](#terminal-abstraction).
- **Framebuffer Drawing** — Includes lower-level routines for drawing pixels and bitmap-font characters, rendering strings, and clearing the framebuffer. See [Terminal Abstraction](#terminal-abstraction).
- **Failure Handling** — Stops the boot process when essential operations fail, such as memory detection, kernel-header validation, kernel loading, or required CPU-feature checks. Certain operations also support fallback methods, with selected fallback decisions recorded for diagnostics.

### Terminal Abstraction
The terminal abstraction is implemented in both 32-bit and 64-bit modes. Although their implementations differ, both provide a similar interface for displaying text without requiring the caller to manage the underlying display hardware directly.
The terminal selects between **VGA text output** and **VBE framebuffer output** using bit 3 of `boot_report`. This allows the same general printing interface to work with either display path.

The main functions are:

| Function | Purpose |
|---|---|
| `terminal_print_char64` | Prints a single character using the selected display backend. |
| `terminal_print_string64` | Prints a null-terminated string, with support for newline and carriage-return handling. It also supports simple escape sequences for changing colors. |
| `terminal_clear_screen_64` | Clears the screen using the requested background color. This operation does not move the cursor, so cursor positioning must be handled separately. |
| `terminal_move_cursor_64` | Moves the cursor by a relative row and column offset. The VBE implementation normalizes positions that exceed the available grid. |

For `terminal_print_string64`, the calling convention is:

| Register | Input |
|---|---|
| `EDI` | Pointer to a null-terminated string |
| `ESI` | Background color index (`0`–`F`) |
| `EDX` | Foreground color index (`0`–`F`) |

The color arguments use hexadecimal color indices rather than requiring callers to provide raw framebuffer color values. In VBE mode, the terminal translates these indices through a color preset table. In VGA mode, the indices are combined into the conventional text attribute byte.

The VBE string renderer also supports a small set of escape sequences when enabled:

| Sequence | Effect |
|---|---|
| `\\` | Prints a literal backslash. |
| `\aX` | Changes the background color to preset `X`. |
| `\bX` | Changes the foreground color to preset `X`. |

Here, `X` represents a hexadecimal color digit. The renderer also handles line feed (`LF`) and carriage return (`CR`) characters, allowing messages to span multiple lines.

The main advantage of this design is that code displaying boot messages does not need to know how characters are drawn, how framebuffer pixels are addressed, or how VGA text attributes are encoded. Those details remain inside the terminal and its underlying display drivers.



## Project Layout
This section will talk about the project layout of both the bootloader and the Kernel

- `src/boot/` — Contains the bootloader, divided into Stage 1 and Stage 2. Stage 1 handles the initial boot, while Stage 2 contains the main bootloader logic and is organized by CPU execution mode.
  - `stage1/` — Stage 1 bootloader.
  - `stage2/16bits/` — Real-mode code for early initialization, BIOS services, hardware detection, memory-map discovery, and kernel loading.
  - `stage2/32bits/` — Protected-mode code for system setup, paging, graphics, terminal interfaces, and preparation for entering the kernel.
  - `stage2/64bits/` — Long-mode code and supporting graphics and terminal components.

- `src/kernel/` — Contains the kernel and its supporting build files. UNDER DEVELOPMENT
  - `arch/x86_64/` — Architecture-specific kernel setup and interrupt handling.
  - `drivers/` — Kernel driver components.
  - `include/` — Shared data structures and definitions used across the kernel's assembly and C code.
  - The kernel's root directory also contains the kernel entry point, main C source, linker script, and binary finalization script.

- `target/` — Contains generated build artifacts, organized by purpose. This folder should be generated when running the makefile.
  - `bin/` — Compiled bootloader stages.
  - `lst/` — Assembly listing files for debugging and inspection.
  - `kernel/` — Kernel build outputs, including object files, the linked ELF image, and the finalized kernel binary.
  - `debug/` — Debug-related build artifacts.
  - `boot.bin` — The combined bootable image.

- `Makefile` — Defines the build process for assembling the bootloader, compiling and linking the kernel, finalizing the kernel image, and combining the components.
- `CRC32.py` — Provides checksum calculation support for binary images. Currently unused



## Build Requirements
The following tools are required or recommended to build, test, and develop the operating system.

### Required
- **GNU Make** — Automates the build process using the `Makefile`.
- **NASM** — Assembles the bootloader and kernel assembly source files.
- **GNU Binutils** — Provides `ld` for linking and `objcopy` for converting the kernel ELF into a flat binary.
- **Python 3** — Runs scripts for kernel image finalization and CRC32 checksum calculation.
- **GNU Coreutils** — Provides utilities such as `cat`, `mkdir`, and `rm`.
- **GNU Findutils** — Provides `find` for automatic kernel source discovery.
- **GNU/Linux environment** — Recommended development environment for the current build setup.
- **GCC** — A C compiler for developing the kernel in C alongside assembly.
- **x86_64-elf cross-compilation toolchain** — Provides a compiler and associated tools targeting the x86-64 bare-metal environment, avoiding reliance on the host system's default compilation target.

### Testing and Debugging
- **QEMU (`qemu-system-x86_64`)** — Runs the bootable image in an emulated x86-64 machine.
- **GDB** — Enables debugging of the bootloader and kernel through QEMU's GDB interface.

---

## Contact

- **Email:** PA25510289@gmail.com - It might take a few days for me to reply, I don't usually read gmail 😅😅
- **Issues:** Use [GitHub Issues](../../issues) for bug reports and technical questions.
