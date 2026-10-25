# (Not So) Quick and Dirty Bootloader (QADB)
A custom semi-general purpose bootloader written in assembly for x86 little-endian systems, responsible for loading a kernel from disk, preparing the processor and memory environment, and transferring control to the kernel. The bootloader itself is assemble using NASM and the image is build using Makefile as a flat assembly format for simplicity, it and have it own custom kernel header format to pass metadata and information to the bootloader. It is build with a goal to support any kernel that can make use of the available boot service, though the kernel might need to be modify in order to read the boot infomration that passed by the bootloader hence it is semi-general purpose. Notes that the detail provided above may change as the project are being continuously update, especially the point about how it is build and assemble. 

WARNING: Run this bootloader and the kernel at YOUR OWN RISK. Although the bootloader lack disk-writing functions (for now) and the most damage it can do is soft-bricking your computers, various factor can potentially harm or lead to unwanted behaviors in the machine. I take no responsibility if the user's machine got damage in running my program.

## Table of Content
- [Why build this?](#why-build-this?)
- [Architecture and Boot sequence](#architecture-and-boot-sequence)

## Why build this?
Honestly, curiosity was probably the biggest reason I started this project. I mean who wound't want to know what happen underneath your programs?

There was another reason, though. I'd spent the past seven months learning assembly (as of July 2026 when I started the project), and I wanted to put that knowledge to use. Assembly is a powerful skill to have, but outside areas like low-level systems programming, firmware, and reverse engineering, opportunities to use it directly can be pretty limited. Building my own bootloader gave me an excuse to do something practical with it.

More importantly, why not?

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
