# x86 Bootloader
A custom bootloader written in NASM assembly for x86 systems, responsible for loading a kernel from disk, preparing the processor and memory environment, and transferring control to the kernel.

## Table of Content
- [Why build this?](#about-the-project)
- [Architecture and Boot sequence](#architecture-and-boot-sequence]

## Why build this?
Honestly, curiosity was probably the biggest reason I started this project. I mean who wound't want to know what happen underneath your programs?

There was another reason, though. I'd spent the past seven months learning assembly (as of July 2026 when I started the project), and I wanted to put that knowledge to use. Assembly is a powerful skill to have, but outside areas like low-level systems programming, firmware, and reverse engineering, opportunities to use it directly can be pretty limited. Building my own bootloader gave me an excuse to do something practical with it.

More importantly, why not?


## Architecture and Boot sequence

### RAM layout
The bootloader mainly operate inside the low-memory (under 1mb) with the exception of VBE’s framebuffer as it is more predictable than high-memory. The memory layout is as follow:

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

## Reserved Paging Memory

### Higher-Half Paging

The higher-half paging structures begin at physical address `0x5F000`. This region is reserved for constructing the mappings required to access the kernel at its higher-half virtual address.

### Boot-Time Paging

The initial paging structures begin at physical address `0x80000`. They are used to establish the mappings required for the transition into 64-bit mode and the initial kernel environment, covering the intended physical address range of approximately 1–4 GiB depending.

The actual coverage depends on the paging levels and entries configured by the bootloader, main variable include the VBE's framebuffer location.

## Scratch Pad

The scratch pad begins at physical address `0x1000`. It provides temporary storage for bootloader routines and intermediate data.

The available space is bounded by reserved memory regions and any additional allocations made during boot. Individual routines must ensure that their buffers do not overlap the bootloader, paging structures, or other live data.

## Notes

- All addresses in this section above refer to **physical addresses**, unless explicitly stated otherwise.
- The memory map describes the bootloader's intended reservations, not a guarantee that every unreserved address is available RAM.
- The memory layout above only describe the first 1mb of the RAM space, any memory above that is mapped by the BIOS e820 function in the bootloader.

### 
