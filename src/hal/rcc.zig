//! STM32L031 RCC (Reset & Clock Control) Hardware Abstraction Layer
//!
//! Provides clock distribution and dynamic clock scaling across:
//! - 32 MHz PLL (Active sensor acquisition)
//! - 16 MHz HSI (Standard execution)
//! - 4 MHz MSI / 65 kHz MSI (Low-power idle & standby)

const std = @import("std");
const registers = @import("registers.zig");
const gpio = @import("gpio.zig");

pub var g_system_core_clock: u32 = 16_000_000;

pub inline fn getSystemCoreClock() u32 {
    return g_system_core_clock;
}

// ============================================================================
// Peripheral Clock Control
// ============================================================================

pub inline fn enableGpio(port: gpio.Port) void {
    const r = registers.getRcc();
    const mask = switch (port) {
        .A => registers.RCC_IOPENR_GPIOAEN,
        .B => registers.RCC_IOPENR_GPIOBEN,
        .C => registers.RCC_IOPENR_GPIOCEN,
    };
    r.IOPENR |= mask;
}

pub inline fn disableGpio(port: gpio.Port) void {
    const r = registers.getRcc();
    const mask = switch (port) {
        .A => registers.RCC_IOPENR_GPIOAEN,
        .B => registers.RCC_IOPENR_GPIOBEN,
        .C => registers.RCC_IOPENR_GPIOCEN,
    };
    r.IOPENR &= ~mask;
}

pub inline fn enableLpuart1() void {
    registers.getRcc().APB1ENR |= registers.RCC_APB1ENR_LPUART1EN;
}

pub inline fn disableLpuart1() void {
    registers.getRcc().APB1ENR &= ~registers.RCC_APB1ENR_LPUART1EN;
}

pub inline fn enableSpi1() void {
    registers.getRcc().APB2ENR |= registers.RCC_APB2ENR_SPI1EN;
}

pub inline fn disableSpi1() void {
    registers.getRcc().APB2ENR &= ~registers.RCC_APB2ENR_SPI1EN;
}

pub inline fn enableDma1() void {
    registers.getRcc().AHBENR |= registers.RCC_AHBENR_DMA1EN;
}

pub inline fn disableDma1() void {
    registers.getRcc().AHBENR &= ~registers.RCC_AHBENR_DMA1EN;
}

pub inline fn enableAdc() void {
    registers.getRcc().APB2ENR |= registers.RCC_APB2ENR_ADC1EN;
}

pub inline fn disableAdc() void {
    registers.getRcc().APB2ENR &= ~registers.RCC_APB2ENR_ADC1EN;
}

pub inline fn enableSyscfg() void {
    registers.getRcc().APB2ENR |= registers.RCC_APB2ENR_SYSCFGEN;
}

pub inline fn enablePwr() void {
    registers.getRcc().APB1ENR |= registers.RCC_APB1ENR_PWREN;
}

/// Pulse APB2 ADC1 reset bit to return ADC1 to its hardware reset state
pub fn resetAdc() void {
    const r = registers.getRcc();
    r.APB2RSTR |= registers.RCC_APB2ENR_ADC1EN;
    var d: u32 = 0;
    while (d < 100) : (d += 1) {
        asm volatile ("nop");
    }
    r.APB2RSTR &= ~registers.RCC_APB2ENR_ADC1EN;
}

/// Enable the 37 kHz internal low-speed oscillator (LSI) and wait until ready
pub fn enableLsi() void {
    const r = registers.getRcc();
    r.CSR |= registers.RCC_CSR_LSION;
    var timeout: u32 = 100_000;
    while ((r.CSR & registers.RCC_CSR_LSIRDY) == 0 and timeout > 0) : (timeout -= 1) {}
}

/// Configure HSI16 as the automatic wakeup oscillator when exiting Stop mode (STOPWUCK = 0)
pub inline fn setStopWakeupHsi() void {
    registers.getRcc().CFGR &= ~registers.RCC_CFGR_STOPWUCK;
}

/// Route HSI16 (16 MHz) directly as the LPUART1 kernel clock in RCC_CCIPR (bits 11:10 = 0b10)
pub inline fn selectLpuart1Hsi16() void {
    const r = registers.getRcc();
    var ccipr = r.CCIPR;
    ccipr &= ~(@as(u32, 0b11) << 10);
    ccipr |= (@as(u32, 0b10) << 10);
    r.CCIPR = ccipr;
}

// ============================================================================
// Clock Frequency Scaling
// ============================================================================

/// Configure system clock to 32 MHz via PLL (HSI16 x 4 / 2)
pub fn setClock32MHzPll() bool {
    const rcc = registers.getRcc();
    const flash = registers.getFlash();
    const pwr = registers.getPwr();

    // 1. Ensure Voltage Scaling Range 1 (1.8V) for 32 MHz
    pwr.CR = (pwr.CR & ~registers.PWR_CR_VOS_MASK) | registers.PWR_CR_VOS_RANGE1;

    // 2. 1 Flash Wait State required at 32 MHz Range 1
    flash.ACR |= registers.FLASH_ACR_LATENCY | registers.FLASH_ACR_PRFTEN;

    // 3. Ensure HSI16 is ON and ready
    rcc.CR |= registers.RCC_CR_HSION;
    var timeout: u32 = 100_000;
    while ((rcc.CR & registers.RCC_CR_HSIRDY) == 0 and timeout > 0) : (timeout -= 1) {}
    if (timeout == 0) return false;

    // 4. Configure PLL: Source HSI16, Mul 4, Div 2 -> (16 * 4) / 2 = 32 MHz
    rcc.CR &= ~registers.RCC_CR_PLLON;
    rcc.CFGR = (rcc.CFGR & ~(registers.RCC_CFGR_PLLSRC_MASK | registers.RCC_CFGR_PLLMUL_MASK | registers.RCC_CFGR_PLLDIV_MASK)) |
        registers.RCC_CFGR_PLLSRC_HSI |
        registers.RCC_CFGR_PLLMUL4 |
        registers.RCC_CFGR_PLLDIV2;

    // 5. Enable PLL and wait for lock
    rcc.CR |= registers.RCC_CR_PLLON;
    timeout = 100_000;
    while ((rcc.CR & registers.RCC_CR_PLLRDY) == 0 and timeout > 0) : (timeout -= 1) {}
    if (timeout == 0) return false;

    // 6. Switch system clock to PLL
    rcc.CFGR = (rcc.CFGR & ~registers.RCC_CFGR_SW_MASK) | registers.RCC_CFGR_SW_PLL;
    timeout = 100_000;
    while ((rcc.CFGR & registers.RCC_CFGR_SWS_MASK) != registers.RCC_CFGR_SWS_PLL and timeout > 0) : (timeout -= 1) {}
    if (timeout == 0) return false;

    g_system_core_clock = 32_000_000;
    return true;
}

/// Configure system clock to 16 MHz HSI
pub fn setClock16MHzHsi() bool {
    const rcc = registers.getRcc();
    const flash = registers.getFlash();

    rcc.CR |= registers.RCC_CR_HSION;
    var timeout: u32 = 100_000;
    while ((rcc.CR & registers.RCC_CR_HSIRDY) == 0 and timeout > 0) : (timeout -= 1) {}
    if (timeout == 0) return false;

    // Clear HSIDIVEN (bit 3) so HSI16 runs at full 16 MHz
    rcc.CR &= ~@as(u32, 1 << 3);
    timeout = 100_000;
    while ((rcc.CR & (1 << 4)) != 0 and timeout > 0) : (timeout -= 1) {}

    rcc.CFGR = (rcc.CFGR & ~registers.RCC_CFGR_SW_MASK) | registers.RCC_CFGR_SW_HSI;
    timeout = 100_000;
    while ((rcc.CFGR & registers.RCC_CFGR_SWS_MASK) != registers.RCC_CFGR_SWS_HSI and timeout > 0) : (timeout -= 1) {}
    if (timeout == 0) return false;

    // 0 Wait States safe at 16 MHz Range 1
    flash.ACR &= ~registers.FLASH_ACR_LATENCY;

    g_system_core_clock = 16_000_000;
    return true;
}

// ============================================================================
// Unit Tests
// ============================================================================

test "RCC peripheral enables" {
    registers.mock_rcc = std.mem.zeroes(registers.RccRegs);
    enableGpio(.A);
    try std.testing.expect((registers.mock_rcc.IOPENR & registers.RCC_IOPENR_GPIOAEN) != 0);

    enableSpi1();
    try std.testing.expect((registers.mock_rcc.APB2ENR & registers.RCC_APB2ENR_SPI1EN) != 0);

    enableDma1();
    try std.testing.expect((registers.mock_rcc.AHBENR & registers.RCC_AHBENR_DMA1EN) != 0);
}
