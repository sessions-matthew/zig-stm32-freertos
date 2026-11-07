//! STM32L031 LPUART1 Hardware Abstraction Layer
//!
//! Provides low-power UART transmission, reception, and interrupt status management.

const std = @import("std");
const registers = @import("registers.zig");

pub const Lpuart = struct {
    pub inline fn regs() *volatile registers.LpuartRegs {
        return registers.getLpuart1();
    }

    /// Initialize LPUART1 with specified baud rate and input clock frequency
    pub fn init(baud: u32, clock_hz: u32) void {
        const r = regs();

        // 1. Errata 2.12.2: Disable UE before modifying baud rate / configuration
        r.CR1 = 0;
        r.CR2 = 0;
        r.CR3 = 0;

        // 2. Calculate BRR for LPUART:
        // LPUARTDIV = 256 * fCK / baud
        // Errata 2.12.5: Hardware minimum BRR is 0x300 (ratio clock/baud >= 3.00)
        const brr_val: u32 = @intCast((@as(u64, clock_hz) * 256 + (baud / 2)) / baud);
        r.BRR = brr_val & 0x000FFFFF;
        r.ICR = 0xFFFFFFFF;
        if ((r.ISR & registers.LPUART_ISR_RXNE) != 0) {
            _ = r.RDR;
        }

        // 3. Enable Transmitter, Receiver, RXNE interrupt, and UART Enable
        r.CR1 = registers.LPUART_CR1_TE | registers.LPUART_CR1_RE | registers.LPUART_CR1_RXNEIE | registers.LPUART_CR1_UE;
    }

    /// Errata 2.12.1: Wait until transmission is completely finished on the physical wire
    /// (checking TC = Transmission Complete, rather than just TXE) before entering Stop mode.
    pub fn waitTxComplete() void {
        const r = regs();
        while ((r.ISR & registers.LPUART_ISR_TXE) == 0) {}
        r.ICR = registers.LPUART_ICR_TCCF;
        while ((r.ISR & registers.LPUART_ISR_TC) == 0) {}
    }

    pub inline fn hasByte() bool {
        const isr = regs().ISR;
        if ((isr & registers.LPUART_ISR_ORE) != 0) {
            regs().ICR = registers.LPUART_ISR_ORE;
        }
        return (isr & registers.LPUART_ISR_RXNE) != 0;
    }

    pub inline fn readByte() u8 {
        return @intCast(regs().RDR & 0xFF);
    }

    pub inline fn isTxEmpty() bool {
        return (regs().ISR & registers.LPUART_ISR_TXE) != 0;
    }

    pub inline fn isTxComplete() bool {
        return (regs().ISR & registers.LPUART_ISR_TC) != 0;
    }

    pub fn writeByte(byte: u8) void {
        const r = regs();
        while ((r.ISR & registers.LPUART_ISR_TXE) == 0) {}
        r.TDR = byte;
    }

    pub fn writeString(str: []const u8) void {
        for (str) |c| {
            writeByte(c);
        }
    }

    pub fn writeU32(val: u32) void {
        var buf: [10]u8 = undefined;
        var v = val;
        var i: usize = 0;
        if (v == 0) {
            writeByte('0');
            return;
        }
        while (v > 0) : (i += 1) {
            buf[i] = @intCast('0' + (v % 10));
            v /= 10;
        }
        while (i > 0) {
            i -= 1;
            writeByte(buf[i]);
        }
    }

    pub fn writeI32(val: i32) void {
        if (val < 0) {
            writeByte('-');
            const mag: u32 = @intCast(-%val);
            writeU32(mag);
        } else {
            writeU32(@intCast(val));
        }
    }

    pub fn writeHex(val: u32) void {
        const hex_chars = "0123456789ABCDEF";
        writeString("0x");
        var shift: u5 = 28;
        while (true) {
            const nibble = (val >> shift) & 0xF;
            writeByte(hex_chars[nibble]);
            if (shift == 0) break;
            shift -= 4;
        }
    }

    pub inline fn clearErrors() void {
        regs().ICR = registers.LPUART_ISR_ORE | registers.LPUART_ISR_NE | registers.LPUART_ISR_FE | registers.LPUART_ISR_PE;
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

test "LPUART initialization and BRR calculation" {
    registers.mock_lpuart1 = std.mem.zeroes(registers.LpuartRegs);
    Lpuart.init(115200, 16_000_000);

    // 256 * 16,000,000 / 115200 = 35555.55 -> ~35556 (0x8AE4)
    try std.testing.expectEqual(@as(u32, 0x8AE4), registers.mock_lpuart1.BRR);
    try std.testing.expect((registers.mock_lpuart1.CR1 & registers.LPUART_CR1_UE) != 0);
    try std.testing.expect((registers.mock_lpuart1.CR1 & registers.LPUART_CR1_TE) != 0);
}
