//! STM32L031 Power Control & RTC Backup Register Hardware Abstraction Layer
//!
//! Provides ultra-low-power Stop mode entry, power rail management, and RTC backup access.

const std = @import("std");
const builtin = @import("builtin");
const registers = @import("registers.zig");

pub const Pwr = struct {
    pub inline fn regs() *volatile registers.PwrRegs {
        return registers.getPwr();
    }

    pub inline fn rtcRegs() *volatile registers.RtcRegs {
        return registers.getRtc();
    }

    /// Enable write access to the RTC and backup registers (RM0377 Section 6.4.1)
    pub inline fn enableBackupAccess() void {
        regs().CR |= registers.PWR_CR_DBP;
    }

    /// Disable write access to RTC and backup registers
    pub inline fn disableBackupAccess() void {
        regs().CR &= ~registers.PWR_CR_DBP;
    }

    /// Write 32-bit value to persistent RTC backup register (BKP0..BKP4)
    pub inline fn writeBackup(index: usize, val: u32) void {
        if (index < 5) {
            rtcRegs().BKP[index] = val;
        }
    }

    /// Read 32-bit value from persistent RTC backup register (BKP0..BKP4)
    pub inline fn readBackup(index: usize) u32 {
        if (index < 5) {
            return rtcRegs().BKP[index];
        }
        return 0;
    }

    pub fn rtcTrToSeconds(tr: u32) u32 {
        const sec = (tr & 0x0F) + ((tr >> 4) & 0x07) * 10;
        const min = ((tr >> 8) & 0x0F) + ((tr >> 12) & 0x07) * 10;
        const hr = ((tr >> 16) & 0x0F) + ((tr >> 20) & 0x03) * 10;
        return hr * 3600 + min * 60 + sec;
    }

    pub const RtcSnapshot = struct {
        ssr: u32,
        tr: u32,
    };

    /// Capture an atomic snapshot of RTC sub-seconds (`SSR`) and time (`TR`), unlocking `DR`
    pub inline fn snapshotTime() RtcSnapshot {
        const r = rtcRegs();
        const ssr = r.SSR;
        const tr = r.TR;
        _ = r.DR;
        return .{ .ssr = ssr, .tr = tr };
    }

    pub inline fn getSubSeconds() u32 {
        return rtcRegs().SSR;
    }

    pub fn getTimeSeconds() u32 {
        const r = rtcRegs();
        const tr = r.TR;
        _ = r.DR; // Reading DR unlocks shadow registers
        return rtcTrToSeconds(tr);
    }

    pub fn getTimeMs() u32 {
        const r = rtcRegs();
        var ssr1 = r.SSR;
        var tr1 = r.TR;
        const ssr2 = r.SSR;
        if (ssr2 > ssr1) {
            tr1 = r.TR;
            ssr1 = ssr2;
        }
        _ = r.DR;
        const sec = rtcTrToSeconds(tr1);
        const sub_ms = ((255 - (ssr1 & 0xFF)) * 1000 + 128) / 256;
        return sec * 1000 + sub_ms;
    }

    /// Configure Cortex-M0+ and PWR controller for Stop mode
    pub fn enterStopMode() void {
        const r = regs();

        // 1. Select Stop mode (clear PDDS) and Low-Power Stop (set LPSDSR)
        r.CR = (r.CR & ~registers.PWR_CR_PDDS) | registers.PWR_CR_LPSDSR;

        // 2. Set SLEEPDEEP bit in Cortex-M0+ System Control Register (SCR)
        if (!builtin.is_test) {
            const SCR_ADDR: usize = 0xE000ED10;
            const scr: *volatile u32 = @ptrFromInt(SCR_ADDR);
            scr.* |= (1 << 2); // SLEEPDEEP

            // 3. Clear wake-up flag
            r.CR |= registers.PWR_CR_CWUF;

            // 4. Wait For Interrupt (WFI)
            asm volatile ("wfi");

            // 5. Clear SLEEPDEEP upon wake
            scr.* &= ~(@as(u32, 1) << 2);
        }
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

test "PWR backup register read and write" {
    registers.mock_pwr = std.mem.zeroes(registers.PwrRegs);
    registers.mock_rtc = std.mem.zeroes(registers.RtcRegs);

    Pwr.enableBackupAccess();
    try std.testing.expect((registers.mock_pwr.CR & registers.PWR_CR_DBP) != 0);

    Pwr.writeBackup(2, 0x12345678);
    try std.testing.expectEqual(@as(u32, 0x12345678), Pwr.readBackup(2));
}
