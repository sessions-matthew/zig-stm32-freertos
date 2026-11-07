# Zig + FreeRTOS + STM32 Starter Template (`zig-stm32-freertos`)

[![Discord - Zig LLM Group](https://img.shields.io/badge/Discord-Zig%20LLM%20Group-5865F2?logo=discord&logoColor=white)](https://discord.gg/qs5gbtg28H)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A clean, standalone project template pairing **Zig 0.17.0** with **FreeRTOS Static** on the **STM32L031** ARM Cortex-M0+.

> **Community**: Join the [**Zig LLM Group** Discord server](https://discord.gg/qs5gbtg28H) to discuss Zig on microcontrollers, FreeRTOS integration, and AI agent workflows.

---

## Architecture Overview

```
zig-stm32/
├── build.zig                   # Zig 0.17 build & cross-compilation orchestration
├── build.zig.zon               # Zig package manifest
├── linker/
│   └── stm32l031g6u6.ld        # Linker script (32 KB Flash, 8 KB SRAM, zero heap)
├── include/
│   └── libc_compat/            # Freestanding C standard library shims
├── vendor/
│   ├── cmsis/                  # ARM Cortex-M0+ CMSIS core & device definitions
│   ├── config/                 # FreeRTOSConfig.h (static-only allocation, tickless idle)
│   ├── freertos/               # FreeRTOS kernel source files & Cortex-M0+ port
│   ├── hal/                    # STM32L0xx HAL drivers
│   ├── lptim/                  # No-drift LPTIM tickless idle implementation
│   └── startup/                # Vector table and Reset_Handler startup code
├── src/
│   ├── main.zig                # Clean application entry point, dual tasks & static queue
│   ├── rtos/                   # Zero-overhead FreeRTOS abstractions & static bindings
│   │   ├── root.zig            # Re-exports types, task, queue, mutex, critical
│   │   ├── types.zig           # Handles, base types, ticks/ms conversions, errors
│   │   ├── task.zig            # Task.createStatic, delay, stack watermarks
│   │   ├── queue.zig           # Zero-allocation StaticQueue(T, N)
│   │   ├── mutex.zig           # Mutex & Semaphore with RAII lock guards
│   │   └── critical.zig        # Critical sections & CriticalGuard
│   └── hal/                    # Silicon Hardware Abstraction Layer (RM0377)
│       ├── root.zig            # Re-exports registers, gpio, rcc, uart, spi, dma, exti, adc, pwr
│       ├── registers.zig       # Type-safe MMIO register maps with host simulation mocks
│       ├── gpio.zig            # Pin, Port, alternate function, and speed controls
│       ├── rcc.zig             # HSI16, PLL, MSI clock tree, and peripheral clock gating
│       ├── uart.zig            # LPUART1 driver (115200 8N1, baud calculation, string formatting)
│       ├── spi.zig             # SPI1 master driver
│       ├── dma.zig             # DMA1 channel routing and configuration
│       ├── exti.zig            # External interrupt and SYSCFG line management
│       ├── adc.zig             # 12-bit ADC1 and VREFINT internal reference sensing
│       └── pwr.zig             # Low-power stop/sleep modes & RTC backup domain
└── README.md
```

---

## Memory Map & Constraints

Target: **STM32L031G6U6** (ARM Cortex-M0+ @ 16 MHz HSI16)

| Region | Base Address | Size | Allocation |
| :--- | :--- | :--- | :--- |
| **FLASH** | `0x08000000` | **32 KB** | Vector table, firmware text, constants (`.rodata`) |
| **SRAM** | `0x20000000` | **8 KB** | Static task TCBs, static task stacks, static queues, ISR stack (384 B) |
| **Heap** | — | **0 B** | **Zero dynamic allocation** (`configSUPPORT_DYNAMIC_ALLOCATION=0`) |

---

## Commands

| Command | Action |
| :--- | :--- |
| `zig build` | Compiles ARM Cortex-M0+ firmware binary (`zig-out/bin/stm32_freertos.bin`) |
| `zig build test --summary all` | Runs all 23 host unit tests natively (sub-second, 0 hardware required) |
| `zig build flash` | Flashes firmware to STM32 (auto-detects OpenOCD, st-flash, or probe-rs) |
| `zig build clean` | Cleans all build artifacts and caches |

---

## Silicon Errata Reference & Mitigations (ST ES0322)

The STM32L031 has known silicon errata documented in ST Errata Sheet **ES0322**. Rather than relying on heavyweight C libraries, this template mitigates each erratum directly in the zero-cost HAL:

| Erratum | Description | Hardware Risk | Mitigation in `src/hal/` |
| :--- | :--- | :--- | :--- |
| **2.1.1** | RCC peripheral clock enable delay | Setting `RCC_APBxENR` bits requires APB bus synchronization; immediate access causes dropped writes or hard faults. | `hal.rcc.rccSync()` reads back `RCC_CR` as a synchronization barrier immediately following clock gate assertions. |
| **2.1.2** | Flash `RUN_PD` bit in Stop mode | If `RUN_PD` is set when entering Stop mode, the Flash controller can lock up or corrupt wakeup vectors. | `hal.pwr.enterStopMode()` clears `FLASH_ACR_RUN_PD` prior to issuing `WFI`. |
| **2.1.3 & 2.1.4** | Voltage Regulator & POR reset on HSI wakeup | Entering Stop mode with Low-Power Regulator (`LPSDSR=1`) causes POR reset upon fast HSI16/LPUART wakeup or when $V_{DD} < 2.7\text{ V}$. | `hal.pwr.enterStopMode(use_low_power_regulator: bool)` keeps Main Regulator active (`LPSDSR=0`) when waking via HSI16/UART. |
| **2.12.1** | LPUART truncation in Stop mode | Entering Stop mode while a byte is in the transmit shift register truncates characters on the wire (`TXE` only checks the buffer). | `hal.uart.Lpuart.waitTxComplete()` clears `TCCF` and polls for `TC == 1` before low-power transitions. |
| **2.12.2** | LPUART BRR modification | Changing baud rate while `UE=1` corrupts baud rate generation. | `hal.uart.Lpuart.init()` disables `CR1.UE` before writing `BRR`. |
| **2.12.5** | LPUART minimum clock ratio | Hardware minimum BRR is `0x300` (clock must be $\ge 3\times$ baud rate). | Checked at configuration time to prevent clock ratio violations. |
| **LPTIM Tick** | FreeRTOS tickless idle drift | ST reference LPTIM drivers suffer cumulative timer drift across Stop mode sleep cycles. | Uses Jeff Tenney's no-drift LPTIM driver (`vendor/lptim/lptimTick.c`). |

---

## Static FreeRTOS Usage

### 1. Static Task Creation

```zig
const rtos = @import("rtos");

pub const TASK_STACK_WORDS = 128;
var g_task_stack: [TASK_STACK_WORDS]rtos.StackType_t = undefined;
var g_task_tcb: rtos.StaticTask_t = undefined;

fn taskRunner(param: ?*anyopaque) callconv(.c) void {
    _ = param;
    while (true) {
        rtos.delayMs(500);
        // Do work
    }
}

// In main():
_ = rtos.Task.createStatic(
    TASK_STACK_WORDS,
    "worker",
    1, // Priority
    taskRunner,
    null,
    &g_task_stack,
    &g_task_tcb,
);
```

### 2. Type-Safe Zero-Allocation Queue

```zig
pub const SensorMsg = extern struct {
    id: u16,
    value: i32,
};

var g_queue = rtos.StaticQueue(SensorMsg, 8){};

// Initialize before starting scheduler:
g_queue.init();

// Sender:
const msg = SensorMsg{ .id = 1, .value = 1234 };
_ = g_queue.send(&msg, 0);

// Receiver:
var received: SensorMsg = undefined;
if (g_queue.receive(&received, rtos.portMAX_DELAY)) {
    // Process message
}
```

---

## Host Unit Testing

Every module (`hal`, `rtos`, and application logic) includes host-side tests that execute in native mock mode on macOS/Linux without requiring hardware or a cross-compiler:

```bash
zig build test --summary all
```

Output:
```
Build Summary: 7/7 steps succeeded; 23/23 tests passed
test success
+- run test 11 pass (11 total)
+- run test 10 pass (10 total)
+- run test 2 pass (2 total)
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

Built with **Gemini** in **Google Antigravity**.
