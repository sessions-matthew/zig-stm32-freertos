//! STM32L031 EXTI & SYSCFG Hardware Abstraction Layer
//!
//! Provides external interrupt configuration and event trigger control.

const std = @import("std");
const registers = @import("registers.zig");
const gpio = @import("gpio.zig");

pub const TriggerEdge = enum {
    rising,
    falling,
    both,
};

pub const Exti = struct {
    pub inline fn regs() *volatile registers.ExtiRegs {
        return registers.getExti();
    }

    pub inline fn syscfgRegs() *volatile registers.SyscfgRegs {
        return registers.getSyscfg();
    }

    /// Map GPIO pin to EXTI line in SYSCFG_EXTICR and configure edge triggers
    pub fn configureLine(line: u4, port: gpio.Port, edge: TriggerEdge) void {
        const sc = syscfgRegs();
        const cr_idx: usize = line / 4;
        const shift: u5 = @intCast((line % 4) * 4);

        // 1. Map GPIO port to EXTI line in SYSCFG_EXTICR
        sc.EXTICR[cr_idx] = (sc.EXTICR[cr_idx] & ~(@as(u32, 0xF) << shift)) | (@as(u32, @intFromEnum(port)) << shift);

        // 2. Configure edge triggers in RTSR and FTSR
        const mask = @as(u32, 1) << line;
        const ex = regs();
        switch (edge) {
            .rising => {
                ex.RTSR |= mask;
                ex.FTSR &= ~mask;
            },
            .falling => {
                ex.FTSR |= mask;
                ex.RTSR &= ~mask;
            },
            .both => {
                ex.RTSR |= mask;
                ex.FTSR |= mask;
            },
        }
    }

    pub inline fn enableInterrupt(line: u4) void {
        regs().IMR |= @as(u32, 1) << line;
    }

    pub inline fn disableInterrupt(line: u4) void {
        regs().IMR &= ~(@as(u32, 1) << line);
    }

    pub inline fn isPending(line: u4) bool {
        return (regs().PR & (@as(u32, 1) << line)) != 0;
    }

    pub inline fn clearPending(line: u4) void {
        regs().PR = @as(u32, 1) << line;
    }

    pub inline fn triggerSoftwareInterrupt(line: u4) void {
        regs().SWIER = @as(u32, 1) << line;
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

test "EXTI line configuration" {
    registers.mock_syscfg = std.mem.zeroes(registers.SyscfgRegs);
    registers.mock_exti = std.mem.zeroes(registers.ExtiRegs);

    Exti.configureLine(10, .A, .rising);
    Exti.enableInterrupt(10);

    // Line 10: CR index 2 (10/4), shift 8 ((10%4)*4)
    try std.testing.expectEqual(@as(u32, 0), (registers.mock_syscfg.EXTICR[2] >> 8) & 0xF);
    try std.testing.expect((registers.mock_exti.RTSR & (1 << 10)) != 0);
    try std.testing.expect((registers.mock_exti.IMR & (1 << 10)) != 0);
}
