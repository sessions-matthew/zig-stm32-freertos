//! STM32L031 DMA1 Hardware Abstraction Layer
//!
//! Provides hardware-accelerated memory-to-peripheral transfers.

const std = @import("std");
const registers = @import("registers.zig");

pub const Dma = struct {
    pub inline fn regs() *volatile registers.DmaRegs {
        return registers.getDma1();
    }

    /// Select hardware peripheral request mapping in DMA1_CSELR (RM0377 Section 10.4)
    pub inline fn selectRequest(channel: u3, request_id: u4) void {
        const shift: u5 = @intCast(@as(u5, channel - 1) * 4);
        regs().CSELR = (regs().CSELR & ~(@as(u32, 0xF) << shift)) | (@as(u32, request_id) << shift);
    }

    /// Configure DMA channel with base pointers, transfer size, and mode
    pub fn configChannel(
        channel: u3,
        periph_addr: usize,
        mem_addr: usize,
        count: u16,
        ccr_flags: u32,
    ) void {
        const ch_idx: usize = channel - 1;
        const ch = &regs().channels[ch_idx];

        // 1. Disable channel before configuring
        ch.CCR = 0;

        // 2. Set peripheral and memory addresses
        ch.CPAR = @intCast(periph_addr);
        ch.CMAR = @intCast(mem_addr);
        ch.CNDTR = count;

        // 3. Clear existing interrupt flags for this channel
        clearInterrupts(channel);

        // 4. Set configuration flags
        ch.CCR = ccr_flags;
    }

    pub inline fn enableChannel(channel: u3) void {
        regs().channels[channel - 1].CCR |= registers.DMA_CCR_EN;
    }

    pub inline fn disableChannel(channel: u3) void {
        regs().channels[channel - 1].CCR &= ~registers.DMA_CCR_EN;
    }

    pub inline fn setCount(channel: u3, count: u16) void {
        regs().channels[channel - 1].CNDTR = count;
    }

    pub inline fn clearInterrupts(channel: u3) void {
        const shift: u5 = @intCast(@as(u5, channel - 1) * 4);
        regs().IFCR = @as(u32, 0xF) << shift;
    }

    pub inline fn isTransferComplete(channel: u3) bool {
        const shift: u5 = @intCast(@as(u5, channel - 1) * 4 + 1);
        return (regs().ISR & (@as(u32, 1) << shift)) != 0;
    }

    pub inline fn getRemainingCount(channel: u3) u16 {
        return @intCast(regs().channels[channel - 1].CNDTR);
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

test "DMA1 channel configuration" {
    registers.mock_dma1 = std.mem.zeroes(registers.DmaRegs);
    Dma.configChannel(2, 0x4001300C, 0x20000100, 18, registers.DMA_CCR_MINC | registers.DMA_CCR_TCIE);

    try std.testing.expectEqual(@as(u32, 0x4001300C), registers.mock_dma1.channels[1].CPAR);
    try std.testing.expectEqual(@as(u32, 0x20000100), registers.mock_dma1.channels[1].CMAR);
    try std.testing.expectEqual(@as(u32, 18), registers.mock_dma1.channels[1].CNDTR);
    try std.testing.expect((registers.mock_dma1.channels[1].CCR & registers.DMA_CCR_MINC) != 0);
}
