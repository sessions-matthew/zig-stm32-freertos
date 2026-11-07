//! Skore STM32L031 Hardware Abstraction Layer (HAL)
//!
//! Silicon-level abstraction for the ARM Cortex-M0+ coprocessor.
//! Completely decouples board layout from bare-metal peripheral register manipulation.
//!
//! Modules:
//! - registers: Type-safe memory-mapped register definitions
//! - gpio: Output, Input, Alternate Function, and Open-Drain pin abstractions
//! - rcc: Clock generation (HSI, PLL 32MHz, MSI) and peripheral clock gates
//! - uart: Low-power UART (LPUART1) driver
//! - spi: Serial Peripheral Interface (SPI1) driver
//! - dma: Direct Memory Access (DMA1) driver
//! - exti: External Interrupt & SYSCFG routing
//! - adc: 12-bit ADC and VREFINT measurement
//! - pwr: Power modes (Stop/Sleep) and persistent RTC backup domain

pub const registers = @import("registers.zig");
pub const gpio = @import("gpio.zig");
pub const rcc = @import("rcc.zig");
pub const uart = @import("uart.zig");
pub const spi = @import("spi.zig");
pub const dma = @import("dma.zig");
pub const exti = @import("exti.zig");
pub const adc = @import("adc.zig");
pub const pwr = @import("pwr.zig");

// Direct Type Re-exports
pub const Pin = gpio.Pin;
pub const Port = gpio.Port;
pub const PinMode = gpio.PinMode;
pub const OutputType = gpio.OutputType;
pub const Speed = gpio.Speed;
pub const Pull = gpio.Pull;

pub const Lpuart = uart.Lpuart;
pub const Spi = spi.Spi;
pub const Dma = dma.Dma;
pub const Exti = exti.Exti;
pub const Adc = adc.Adc;
pub const Pwr = pwr.Pwr;

test {
    _ = registers;
    _ = gpio;
    _ = rcc;
    _ = uart;
    _ = spi;
    _ = dma;
    _ = exti;
    _ = adc;
    _ = pwr;
}
