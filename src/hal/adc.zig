//! STM32L031 ADC1 Hardware Abstraction Layer
//!
//! Provides 12-bit analog-to-digital conversion for battery voltage and VREFINT.

const std = @import("std");
const builtin = @import("builtin");
const registers = @import("registers.zig");

pub const Adc = struct {
    pub const CHANNEL_VREFINT: u5 = 17;
    pub const CHANNEL_TEMP_SENSOR: u5 = 18;

    pub inline fn regs() *volatile registers.AdcRegs {
        return registers.getAdc1();
    }

    pub inline fn commonRegs() *volatile registers.AdcCommonRegs {
        return registers.getAdcCommon();
    }

    /// Enable the internal VREFINT bandgap buffer and route it to ADC Channel 17
    pub inline fn enableVrefInt() void {
        registers.getSyscfg().CFGR3 |= registers.SYSCFG_CFGR3_ENBUF_VREFINT_ADC | registers.SYSCFG_CFGR3_EN_BGAP;
        commonRegs().CCR |= registers.ADC_CCR_VREFEN | registers.ADC_CCR_PRESC_DIV16;
    }

    /// Wait for the VREFINT internal reference voltage to stabilize (`PWR_CSR.VREFINTRDYF`)
    pub fn waitVrefIntReady(timeout: u32) bool {
        if (builtin.is_test) return true;
        const pwr = registers.getPwr();
        var to = timeout;
        while ((pwr.CSR & registers.PWR_CSR_VREFINTRDYF) == 0 and to > 0) : (to -= 1) {}
        return to > 0;
    }

    /// Enable or disable the internal die temperature sensor buffer on ADC Channel 18
    pub inline fn setTempSensorEnabled(enabled: bool) void {
        if (enabled) {
            registers.getSyscfg().CFGR3 |= registers.SYSCFG_CFGR3_ENBUF_SENSOR_ADC;
            commonRegs().CCR |= registers.ADC_CCR_TSEN;
        } else {
            commonRegs().CCR &= ~registers.ADC_CCR_TSEN;
            registers.getSyscfg().CFGR3 &= ~registers.SYSCFG_CFGR3_ENBUF_SENSOR_ADC;
        }
    }

    /// Ensure no conversion is in progress, stopping any stuck conversion if timed out
    pub fn waitIdle(timeout: u32) bool {
        var to = timeout;
        const r = regs();
        while ((r.CR & registers.ADC_CR_ADSTART) != 0) {
            if (to == 0) {
                r.CR |= registers.ADC_CR_ADSTP;
                var stp_to: u32 = 10_000;
                while ((r.CR & (registers.ADC_CR_ADSTART | registers.ADC_CR_ADSTP)) != 0 and stp_to > 0) : (stp_to -= 1) {}
                return false;
            }
            to -= 1;
        }
        return true;
    }

    /// Select active ADC channel (0..18) after ensuring the converter is idle
    pub fn selectChannel(channel: u5) bool {
        if (!waitIdle(20_000)) return false;
        const r = regs();
        r.ISR = registers.ADC_ISR_EOC | registers.ADC_ISR_EOS | registers.ADC_ISR_OVR;
        r.CHSELR = @as(u32, 1) << channel;
        return true;
    }

    /// Perform a single polled 12-bit conversion on the currently selected channel
    pub fn readSamplePolling() ?u16 {
        if (!waitIdle(20_000)) return null;
        const r = regs();
        r.ISR = registers.ADC_ISR_EOC | registers.ADC_ISR_EOS | registers.ADC_ISR_OVR;
        r.CR |= registers.ADC_CR_ADSTART;
        if (builtin.is_test) {
            r.CR &= ~registers.ADC_CR_ADSTART;
            r.ISR |= registers.ADC_ISR_EOC;
        }

        var timeout: u32 = 30_000;
        while ((r.ISR & registers.ADC_ISR_EOC) == 0 and timeout > 0) : (timeout -= 1) {}
        if (timeout == 0) return null;

        const val: u16 = @intCast(r.DR & 0x0FFF);
        r.ISR = registers.ADC_ISR_EOC | registers.ADC_ISR_EOS | registers.ADC_ISR_OVR;
        _ = waitIdle(10_000);
        return val;
    }

    /// Initialize ADC1 for 12-bit single-conversion software-triggered operation (160.5 cycle sampling)
    pub fn init() bool {
        const r = regs();

        // 1. Enable VREFINT bandgap buffer and ADC prescaler
        enableVrefInt();

        // 2. Disable ADC before configuring (if active)
        if ((r.CR & registers.ADC_CR_ADEN) != 0) {
            r.CR |= registers.ADC_CR_ADDIS;
            var timeout: u32 = 10_000;
            while ((r.CR & registers.ADC_CR_ADEN) != 0 and timeout > 0) : (timeout -= 1) {}
        }

        // 3. Configure 12-bit single conversion, async clock, 160.5 sampling cycles
        r.CFGR1 = 0;
        r.CFGR2 = 0;
        r.SMPR = 0b111;

        // 4. Enable internal ADC voltage regulator (ADVREGEN) and allow settling
        r.CR |= registers.ADC_CR_ADVREGEN;
        var d: u32 = 0;
        while (d < 1000) : (d += 1) {
            asm volatile ("nop");
        }

        // 5. Run self-calibration (ADCAL)
        if (!calibrate()) return false;

        d = 0;
        while (d < 100) : (d += 1) {
            asm volatile ("nop");
        }

        // 6. Enable ADC (ADEN)
        return enable();
    }

    pub fn calibrate() bool {
        const r = regs();
        if ((r.CR & registers.ADC_CR_ADEN) != 0) {
            r.CR |= registers.ADC_CR_ADDIS;
            while ((r.CR & registers.ADC_CR_ADEN) != 0) {}
        }
        r.CR |= registers.ADC_CR_ADVREGEN;
        r.CR |= registers.ADC_CR_ADCAL;
        var timeout: u32 = 100_000;
        while ((r.CR & registers.ADC_CR_ADCAL) != 0 and timeout > 0) : (timeout -= 1) {
            if (builtin.is_test) {
                r.CR &= ~registers.ADC_CR_ADCAL;
                break;
            }
        }
        return timeout > 0;
    }

    pub fn enable() bool {
        const r = regs();
        r.ISR |= registers.ADC_ISR_ADRDY; // Clear ADRDY
        r.CR |= registers.ADC_CR_ADEN;
        var timeout: u32 = 100_000;
        while ((r.ISR & registers.ADC_ISR_ADRDY) == 0 and timeout > 0) : (timeout -= 1) {
            if (builtin.is_test) {
                r.ISR |= registers.ADC_ISR_ADRDY;
                break;
            }
        }
        return timeout > 0;
    }

    pub inline fn isEnabled() bool {
        return (regs().CR & registers.ADC_CR_ADEN) != 0;
    }

    pub inline fn disable() void {
        const r = regs();
        if ((r.CR & registers.ADC_CR_ADSTART) != 0) {
            r.CR |= registers.ADC_CR_ADSTP;
            while ((r.CR & registers.ADC_CR_ADSTART) != 0) {}
        }
        r.CR |= registers.ADC_CR_ADDIS;
        while ((r.CR & registers.ADC_CR_ADEN) != 0) {}
    }

    pub fn readChannel(channel: u5) u16 {
        _ = selectChannel(channel);
        return readSamplePolling() orelse 0;
    }

    /// Read factory calibrated VREFINT word at 0x1FF80078 (with fallback to 1680)
    pub fn readFactoryVrefIntCal() u32 {
        const cal_ptr: *const volatile u16 = if (builtin.is_test)
            &mock_vrefint_cal
        else
            @ptrFromInt(registers.VREFINT_CAL_ADDR);
        const raw = @as(u32, cal_ptr.*);
        return if (raw >= 1000 and raw <= 2500) raw else 1680;
    }

    /// Read factory calibrated VREFINT voltage and calculate actual VDDA rail
    pub fn calculateVdda(vrefint_raw: u16) u32 {
        if (vrefint_raw == 0) return 3300;
        const cal_val = readFactoryVrefIntCal();
        // VDDA = 3000 mV * VREFINT_CAL / VREFINT_DATA
        return (3000 * cal_val) / @as(u32, vrefint_raw);
    }
};

pub var mock_vrefint_cal: u16 = 1660;

// ============================================================================
// Unit Tests
// ============================================================================

test "ADC VDDA calculation" {
    mock_vrefint_cal = 1660; // 3.0V factory cal
    // If raw reading is 1660, VDDA should be 3000 mV
    try std.testing.expectEqual(@as(u32, 3000), Adc.calculateVdda(1660));
    // If raw reading is 1509, VDDA should be ~3300 mV
    try std.testing.expectEqual(@as(u32, 3300), Adc.calculateVdda(1509));
}

test "ADC init, channel select, and polling sample read" {
    registers.mock_adc1 = std.mem.zeroes(registers.AdcRegs);
    registers.mock_adc_common = std.mem.zeroes(registers.AdcCommonRegs);
    registers.mock_syscfg = std.mem.zeroes(registers.SyscfgRegs);

    try std.testing.expect(Adc.init());
    try std.testing.expect(Adc.isEnabled());
    try std.testing.expect((registers.mock_adc_common.CCR & registers.ADC_CCR_VREFEN) != 0);

    try std.testing.expect(Adc.selectChannel(Adc.CHANNEL_VREFINT));
    try std.testing.expectEqual(@as(u32, 1) << 17, registers.mock_adc1.CHSELR);

    registers.mock_adc1.DR = 1650;
    try std.testing.expectEqual(@as(?u16, 1650), Adc.readSamplePolling());
}
