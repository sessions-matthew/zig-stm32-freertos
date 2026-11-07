//! STM32L031 Hardware MMIO Register Definitions (RM0377 Reference Manual)
//!
//! Provides type-safe memory-mapped register representations for bare-metal
//! execution on ARM Cortex-M0+ and simulated register structs for host unit tests.

const std = @import("std");
const builtin = @import("builtin");

// ============================================================================
// Peripheral Base Addresses (RM0377 Section 2.2 Memory Map)
// ============================================================================

pub const PERIPH_BASE: usize = 0x40000000;
pub const APB1_BASE: usize = PERIPH_BASE;
pub const APB2_BASE: usize = PERIPH_BASE + 0x00010000;
pub const AHB_BASE: usize = PERIPH_BASE + 0x00020000;
pub const IOPORT_BASE: usize = 0x50000000;

// AHB Peripherals
pub const DMA1_BASE: usize = AHB_BASE + 0x0000;
pub const RCC_BASE: usize = AHB_BASE + 0x1000;
pub const FLASH_BASE: usize = AHB_BASE + 0x2000;

// APB2 Peripherals
pub const SYSCFG_BASE: usize = APB2_BASE + 0x0000;
pub const EXTI_BASE: usize = APB2_BASE + 0x0400;
pub const ADC1_BASE: usize = APB2_BASE + 0x2400;
pub const ADC1_COMMON_BASE: usize = APB2_BASE + 0x2700;
pub const SPI1_BASE: usize = APB2_BASE + 0x3000;

// APB1 Peripherals
pub const RTC_BASE: usize = APB1_BASE + 0x2800;
pub const LPUART1_BASE: usize = APB1_BASE + 0x4800;
pub const PWR_BASE: usize = APB1_BASE + 0x7000;

// IOPORT Peripherals
pub const GPIOA_BASE: usize = IOPORT_BASE + 0x0000;
pub const GPIOB_BASE: usize = IOPORT_BASE + 0x0400;
pub const GPIOC_BASE: usize = IOPORT_BASE + 0x0800;

// System Information & Calibration ROM
pub const UID_BASE: usize = 0x1FF80050;
pub const VREFINT_CAL_ADDR: usize = 0x1FF80078;
pub const TS_CAL1_ADDR: usize = 0x1FF8007A;
pub const TS_CAL2_ADDR: usize = 0x1FF8007E;

// ============================================================================
// GPIO Registers
// ============================================================================

pub const GpioRegs = extern struct {
    MODER: u32,
    OTYPER: u32,
    OSPEEDR: u32,
    PUPDR: u32,
    IDR: u32,
    ODR: u32,
    BSRR: u32,
    LCKR: u32,
    AFR: [2]u32,
    BRR: u32,
};

// ============================================================================
// RCC Registers (Reset & Clock Control)
// ============================================================================

pub const RccRegs = extern struct {
    CR: u32, // 0x00
    ICSCR: u32, // 0x04
    _reserved0: u32, // 0x08
    CFGR: u32, // 0x0C
    CIER: u32, // 0x10
    CIFR: u32, // 0x14
    CICR: u32, // 0x18
    IOPRSTR: u32, // 0x1C
    AHBRSTR: u32, // 0x20
    APB2RSTR: u32, // 0x24
    APB1RSTR: u32, // 0x28
    IOPENR: u32, // 0x2C
    AHBENR: u32, // 0x30
    APB2ENR: u32, // 0x34
    APB1ENR: u32, // 0x38
    IOPSMENR: u32, // 0x3C
    AHBSMENR: u32, // 0x40
    APB2SMENR: u32, // 0x44
    APB1SMENR: u32, // 0x48
    CCIPR: u32, // 0x4C
    CSR: u32, // 0x50
};

// RCC Register Bit Definitions
pub const RCC_CR_HSION: u32 = 1 << 0;
pub const RCC_CR_HSIRDY: u32 = 1 << 2;
pub const RCC_CR_HSIDIVEN: u32 = 1 << 3;
pub const RCC_CR_HSIDIVF: u32 = 1 << 4;
pub const RCC_CR_MSION: u32 = 1 << 8;
pub const RCC_CR_MSIRDY: u32 = 1 << 9;
pub const RCC_CR_PLLON: u32 = 1 << 24;
pub const RCC_CR_PLLRDY: u32 = 1 << 25;

pub const RCC_CFGR_SW_MSI: u32 = 0b00 << 0;
pub const RCC_CFGR_SW_HSI: u32 = 0b01 << 0;
pub const RCC_CFGR_SW_HSE: u32 = 0b10 << 0;
pub const RCC_CFGR_SW_PLL: u32 = 0b11 << 0;
pub const RCC_CFGR_SW_MASK: u32 = 0b11 << 0;

pub const RCC_CFGR_SWS_MSI: u32 = 0b00 << 2;
pub const RCC_CFGR_SWS_HSI: u32 = 0b01 << 2;
pub const RCC_CFGR_SWS_HSE: u32 = 0b10 << 2;
pub const RCC_CFGR_SWS_PLL: u32 = 0b11 << 2;
pub const RCC_CFGR_SWS_MASK: u32 = 0b11 << 2;

pub const RCC_CFGR_STOPWUCK: u32 = 1 << 15;
pub const RCC_CFGR_PLLSRC_HSI: u32 = 0;
pub const RCC_CFGR_PLLSRC_HSE: u32 = 1 << 16;
pub const RCC_CFGR_PLLSRC_MASK: u32 = 1 << 16;
pub const RCC_CFGR_PLLMUL4: u32 = 0b0001 << 18;
pub const RCC_CFGR_PLLMUL_MASK: u32 = 0b1111 << 18;
pub const RCC_CFGR_PLLDIV2: u32 = 0b01 << 22;
pub const RCC_CFGR_PLLDIV_MASK: u32 = 0b11 << 22;

pub const RCC_IOPENR_GPIOAEN: u32 = 1 << 0;
pub const RCC_IOPENR_GPIOBEN: u32 = 1 << 1;
pub const RCC_IOPENR_GPIOCEN: u32 = 1 << 2;

pub const RCC_AHBENR_DMA1EN: u32 = 1 << 0;

pub const RCC_APB2ENR_SYSCFGEN: u32 = 1 << 0;
pub const RCC_APB2ENR_ADC1EN: u32 = 1 << 9;
pub const RCC_APB2ENR_SPI1EN: u32 = 1 << 12;

pub const RCC_APB1ENR_PWREN: u32 = 1 << 28;
pub const RCC_APB1ENR_LPUART1EN: u32 = 1 << 18;

pub const RCC_CSR_LSION: u32 = 1 << 0;
pub const RCC_CSR_LSIRDY: u32 = 1 << 1;

// ============================================================================
// PWR Registers (Power Control)
// ============================================================================

pub const PwrRegs = extern struct {
    CR: u32,
    CSR: u32,
};

pub const PWR_CR_LPSDSR: u32 = 1 << 0;
pub const PWR_CR_PDDS: u32 = 1 << 1;
pub const PWR_CR_CWUF: u32 = 1 << 2;
pub const PWR_CR_CSBF: u32 = 1 << 3;
pub const PWR_CR_PVDE: u32 = 1 << 4;
pub const PWR_CR_PLS_MASK: u32 = 0b111 << 5;
pub const PWR_CR_DBP: u32 = 1 << 8;
pub const PWR_CR_ULP: u32 = 1 << 9;
pub const PWR_CR_FWU: u32 = 1 << 10;
pub const PWR_CR_VOS_MASK: u32 = 0b11 << 11;
pub const PWR_CR_VOS_RANGE1: u32 = 0b01 << 11; // 1.8V
pub const PWR_CR_VOS_RANGE2: u32 = 0b10 << 11; // 1.5V
pub const PWR_CR_VOS_RANGE3: u32 = 0b11 << 11; // 1.2V
pub const PWR_CR_LPDS: u32 = 1 << 16;

pub const PWR_CSR_WUF: u32 = 1 << 0;
pub const PWR_CSR_SBF: u32 = 1 << 1;
pub const PWR_CSR_PVDO: u32 = 1 << 2;
pub const PWR_CSR_VREFINTRDYF: u32 = 1 << 3;
pub const PWR_CSR_VOSF: u32 = 1 << 4;
pub const PWR_CSR_EWUP1: u32 = 1 << 8;
pub const PWR_CSR_EWUP2: u32 = 1 << 9;

// ============================================================================
// Flash Registers
// ============================================================================

pub const FlashRegs = extern struct {
    ACR: u32,
    PECR: u32,
    PDKEYR: u32,
    PEKEYR: u32,
    PRGKEYR: u32,
    OPTKEYR: u32,
    SR: u32,
    OPTR: u32,
    WRPROT1: u32,
    _reserved0: [23]u32,
    WRPROT2: u32,
};

pub const FLASH_ACR_LATENCY: u32 = 1 << 0;
pub const FLASH_ACR_PRFTEN: u32 = 1 << 1;
pub const FLASH_ACR_SLEEP_PD: u32 = 1 << 3;
pub const FLASH_ACR_RUN_PD: u32 = 1 << 4;
pub const FLASH_ACR_DIS_BUF: u32 = 1 << 5;
pub const FLASH_ACR_PRE_READ: u32 = 1 << 6;

// ============================================================================
// EXTI Registers
// ============================================================================

pub const ExtiRegs = extern struct {
    IMR: u32,
    EMR: u32,
    RTSR: u32,
    FTSR: u32,
    SWIER: u32,
    PR: u32,
};

// ============================================================================
// SYSCFG Registers
// ============================================================================

pub const SyscfgRegs = extern struct {
    CFGR1: u32,
    CFGR2: u32,
    EXTICR: [4]u32,
    _reserved0: [2]u32,
    CFGR3: u32,
};

pub const SYSCFG_CFGR3_EN_BGAP: u32 = 1 << 0;
pub const SYSCFG_CFGR3_ENBUF_VREFINT_ADC: u32 = 1 << 8;
pub const SYSCFG_CFGR3_ENBUF_SENSOR_ADC: u32 = 1 << 9;

// ============================================================================
// SPI Registers
// ============================================================================

pub const SpiRegs = extern struct {
    CR1: u32,
    CR2: u32,
    SR: u32,
    DR: u32,
    CRCPR: u32,
    RXCRCR: u32,
    TXCRCR: u32,
    I2SCFGR: u32,
    I2SPR: u32,
};

pub const SPI_CR1_CPHA: u32 = 1 << 0;
pub const SPI_CR1_CPOL: u32 = 1 << 1;
pub const SPI_CR1_MSTR: u32 = 1 << 2;
pub const SPI_CR1_BR_MASK: u32 = 0b111 << 3;
pub const SPI_CR1_SPE: u32 = 1 << 6;
pub const SPI_CR1_LSBFIRST: u32 = 1 << 7;
pub const SPI_CR1_SSI: u32 = 1 << 8;
pub const SPI_CR1_SSM: u32 = 1 << 9;
pub const SPI_CR1_RXONLY: u32 = 1 << 10;
pub const SPI_CR1_DFF: u32 = 1 << 11;

pub const SPI_CR2_RXDMAEN: u32 = 1 << 0;
pub const SPI_CR2_TXDMAEN: u32 = 1 << 1;
pub const SPI_CR2_SSOE: u32 = 1 << 2;
pub const SPI_CR2_FRF: u32 = 1 << 4;
pub const SPI_CR2_ERRIE: u32 = 1 << 5;
pub const SPI_CR2_RXNEIE: u32 = 1 << 6;
pub const SPI_CR2_TXEIE: u32 = 1 << 7;

pub const SPI_SR_RXNE: u32 = 1 << 0;
pub const SPI_SR_TXE: u32 = 1 << 1;
pub const SPI_SR_OVR: u32 = 1 << 6;
pub const SPI_SR_BSY: u32 = 1 << 7;

// ============================================================================
// DMA Registers
// ============================================================================

pub const DmaChannelRegs = extern struct {
    CCR: u32,
    CNDTR: u32,
    CPAR: u32,
    CMAR: u32,
    _reserved: u32,
};

pub const DmaRegs = extern struct {
    ISR: u32,
    IFCR: u32,
    channels: [7]DmaChannelRegs,
    _reserved: [5]u32,
    CSELR: u32, // 0xA8
};

pub const DMA_CCR_EN: u32 = 1 << 0;
pub const DMA_CCR_TCIE: u32 = 1 << 1;
pub const DMA_CCR_HTIE: u32 = 1 << 2;
pub const DMA_CCR_TEIE: u32 = 1 << 3;
pub const DMA_CCR_DIR: u32 = 1 << 4; // 0: Periph -> Mem, 1: Mem -> Periph
pub const DMA_CCR_CIRC: u32 = 1 << 5;
pub const DMA_CCR_PINC: u32 = 1 << 6;
pub const DMA_CCR_MINC: u32 = 1 << 7;
pub const DMA_CCR_PSIZE_MASK: u32 = 0b11 << 8;
pub const DMA_CCR_MSIZE_MASK: u32 = 0b11 << 10;
pub const DMA_CCR_PL_MASK: u32 = 0b11 << 12;
pub const DMA_CCR_PL_LOW: u32 = 0b00 << 12;
pub const DMA_CCR_PL_MEDIUM: u32 = 0b01 << 12;
pub const DMA_CCR_PL_HIGH: u32 = 0b10 << 12;
pub const DMA_CCR_PL_VERY_HIGH: u32 = 0b11 << 12;
pub const DMA_CCR_MEM2MEM: u32 = 1 << 14;

// ============================================================================
// LPUART Registers
// ============================================================================

pub const LpuartRegs = extern struct {
    CR1: u32,
    CR2: u32,
    CR3: u32,
    BRR: u32,
    _reserved0: [2]u32,
    RQR: u32,
    ISR: u32,
    ICR: u32,
    RDR: u32,
    TDR: u32,
};

pub const LPUART_CR1_UE: u32 = 1 << 0;
pub const LPUART_CR1_RE: u32 = 1 << 2;
pub const LPUART_CR1_TE: u32 = 1 << 3;
pub const LPUART_CR1_RXNEIE: u32 = 1 << 5;
pub const LPUART_CR1_TCIE: u32 = 1 << 6;
pub const LPUART_CR1_TXEIE: u32 = 1 << 7;

pub const LPUART_ISR_PE: u32 = 1 << 0;
pub const LPUART_ISR_FE: u32 = 1 << 1;
pub const LPUART_ISR_NE: u32 = 1 << 2;
pub const LPUART_ISR_ORE: u32 = 1 << 3;
pub const LPUART_ISR_RXNE: u32 = 1 << 5;
pub const LPUART_ISR_TC: u32 = 1 << 6;
pub const LPUART_ISR_TXE: u32 = 1 << 7;
pub const LPUART_ISR_BUSY: u32 = 1 << 16;

// ============================================================================
// ADC Registers
// ============================================================================

pub const AdcRegs = extern struct {
    ISR: u32, // 0x00
    IER: u32, // 0x04
    CR: u32, // 0x08
    CFGR1: u32, // 0x0C
    CFGR2: u32, // 0x10
    SMPR: u32, // 0x14
    _reserved0: [2]u32, // 0x18, 0x1C
    TR: u32, // 0x20
    _reserved1: u32, // 0x24
    CHSELR: u32, // 0x28
    _reserved2: [5]u32, // 0x2C..0x3C
    DR: u32, // 0x40
};

pub const AdcCommonRegs = extern struct {
    _reserved0: [2]u32, // 0x00, 0x04
    CCR: u32, // 0x08 (0x40012708)
};

pub const ADC_CR_ADEN: u32 = 1 << 0;
pub const ADC_CR_ADDIS: u32 = 1 << 1;
pub const ADC_CR_ADSTART: u32 = 1 << 2;
pub const ADC_CR_ADSTP: u32 = 1 << 4;
pub const ADC_CR_ADVREGEN: u32 = 1 << 28;
pub const ADC_CR_ADCAL: u32 = 1 << 31;

pub const ADC_ISR_ADRDY: u32 = 1 << 0;
pub const ADC_ISR_EOSMP: u32 = 1 << 1;
pub const ADC_ISR_EOC: u32 = 1 << 2;
pub const ADC_ISR_EOS: u32 = 1 << 3;
pub const ADC_ISR_OVR: u32 = 1 << 4;

pub const ADC_CCR_PRESC_DIV16: u32 = 0b0111 << 18;
pub const ADC_CCR_VREFEN: u32 = 1 << 22;
pub const ADC_CCR_TSEN: u32 = 1 << 23;

// ============================================================================
// RTC Registers
// ============================================================================

pub const RtcRegs = extern struct {
    TR: u32,
    DR: u32,
    CR: u32,
    ISR: u32,
    PRER: u32,
    WUTR: u32,
    _reserved0: u32,
    ALRMAR: u32,
    ALRMBR: u32,
    WPR: u32,
    SSR: u32,
    SHIFTR: u32,
    TSTR: u32,
    TSDR: u32,
    TSSSR: u32,
    CALR: u32,
    TAMPCR: u32,
    ALRMASSR: u32,
    ALRMBSSR: u32,
    OR: u32,
    BKP: [5]u32,
};

// ============================================================================
// Memory Mapped Peripheral Pointers
// ============================================================================

pub var mock_gpioa: GpioRegs = undefined;
pub var mock_gpiob: GpioRegs = undefined;
pub var mock_gpioc: GpioRegs = undefined;
pub var mock_rcc: RccRegs = undefined;
pub var mock_pwr: PwrRegs = undefined;
pub var mock_flash: FlashRegs = undefined;
pub var mock_exti: ExtiRegs = undefined;
pub var mock_syscfg: SyscfgRegs = undefined;
pub var mock_spi1: SpiRegs = undefined;
pub var mock_dma1: DmaRegs = undefined;
pub var mock_lpuart1: LpuartRegs = undefined;
pub var mock_adc1: AdcRegs = undefined;
pub var mock_adc_common: AdcCommonRegs = undefined;
pub var mock_rtc: RtcRegs = undefined;

pub inline fn getGpioA() *volatile GpioRegs {
    return if (builtin.is_test) &mock_gpioa else @ptrFromInt(GPIOA_BASE);
}

pub inline fn getGpioB() *volatile GpioRegs {
    return if (builtin.is_test) &mock_gpiob else @ptrFromInt(GPIOB_BASE);
}

pub inline fn getGpioC() *volatile GpioRegs {
    return if (builtin.is_test) &mock_gpioc else @ptrFromInt(GPIOC_BASE);
}

pub inline fn getRcc() *volatile RccRegs {
    return if (builtin.is_test) &mock_rcc else @ptrFromInt(RCC_BASE);
}

pub inline fn getPwr() *volatile PwrRegs {
    return if (builtin.is_test) &mock_pwr else @ptrFromInt(PWR_BASE);
}

pub inline fn getFlash() *volatile FlashRegs {
    return if (builtin.is_test) &mock_flash else @ptrFromInt(FLASH_BASE);
}

pub inline fn getExti() *volatile ExtiRegs {
    return if (builtin.is_test) &mock_exti else @ptrFromInt(EXTI_BASE);
}

pub inline fn getSyscfg() *volatile SyscfgRegs {
    return if (builtin.is_test) &mock_syscfg else @ptrFromInt(SYSCFG_BASE);
}

pub inline fn getSpi1() *volatile SpiRegs {
    return if (builtin.is_test) &mock_spi1 else @ptrFromInt(SPI1_BASE);
}

pub inline fn getDma1() *volatile DmaRegs {
    return if (builtin.is_test) &mock_dma1 else @ptrFromInt(DMA1_BASE);
}

pub inline fn getLpuart1() *volatile LpuartRegs {
    return if (builtin.is_test) &mock_lpuart1 else @ptrFromInt(LPUART1_BASE);
}

pub inline fn getAdc1() *volatile AdcRegs {
    return if (builtin.is_test) &mock_adc1 else @ptrFromInt(ADC1_BASE);
}

pub inline fn getAdcCommon() *volatile AdcCommonRegs {
    return if (builtin.is_test) &mock_adc_common else @ptrFromInt(ADC1_COMMON_BASE);
}

pub inline fn getRtc() *volatile RtcRegs {
    return if (builtin.is_test) &mock_rtc else @ptrFromInt(RTC_BASE);
}

pub fn readUid() [12]u8 {
    const w0: u32 = if (builtin.is_test) 0x12345678 else @as(*const volatile u32, @ptrFromInt(UID_BASE)).*;
    const w1: u32 = if (builtin.is_test) 0x9ABCDEF0 else @as(*const volatile u32, @ptrFromInt(UID_BASE + 0x04)).*;
    const w2: u32 = if (builtin.is_test) 0x13579BDF else @as(*const volatile u32, @ptrFromInt(UID_BASE + 0x14)).*;

    var uid: [12]u8 = undefined;
    std.mem.writeInt(u32, uid[0..4], w0, .little);
    std.mem.writeInt(u32, uid[4..8], w1, .little);
    std.mem.writeInt(u32, uid[8..12], w2, .little);
    return uid;
}
