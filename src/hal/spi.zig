//! STM32L031 SPI Hardware Abstraction Layer
//!
//! Provides master mode SPI transfer with DMA handshake support.

const std = @import("std");
const registers = @import("registers.zig");

pub const Spi = struct {
    pub inline fn regs() *volatile registers.SpiRegs {
        return registers.getSpi1();
    }

    pub fn initMaster(baud_div: u3, cpol: u1, cpha: u1) void {
        const r = regs();

        // 1. Disable SPI before configuration
        r.CR1 = 0;

        // 2. Configure SPI: Master mode, Software slave management (SSM=1, SSI=1)
        var cr1: u32 = registers.SPI_CR1_MSTR | registers.SPI_CR1_SSM | registers.SPI_CR1_SSI;
        cr1 |= (@as(u32, baud_div) << 3);
        if (cpol == 1) cr1 |= registers.SPI_CR1_CPOL;
        if (cpha == 1) cr1 |= registers.SPI_CR1_CPHA;
        r.CR1 = cr1;

        // 3. Configure CR2: Enable RXDMA and TXDMA requests
        r.CR2 = registers.SPI_CR2_RXDMAEN | registers.SPI_CR2_TXDMAEN;
    }

    pub inline fn enable() void {
        regs().CR1 |= registers.SPI_CR1_SPE;
    }

    pub inline fn disable() void {
        regs().CR1 &= ~registers.SPI_CR1_SPE;
    }

    pub inline fn deinit() void {
        const r = regs();
        r.CR1 &= ~registers.SPI_CR1_SPE;
        r.CR2 = 0;
        r.CR1 = 0;
    }

    pub inline fn isBusy() bool {
        return (regs().SR & registers.SPI_SR_BSY) != 0;
    }

    pub inline fn drainRx() void {
        const r = regs();
        while ((r.SR & registers.SPI_SR_RXNE) != 0) {
            _ = r.DR;
        }
        if ((r.SR & registers.SPI_SR_OVR) != 0) {
            _ = r.DR;
            _ = r.SR;
        }
    }

    pub fn transferByte(byte: u8) u8 {
        const r = regs();
        while ((r.SR & registers.SPI_SR_TXE) == 0) {}
        r.DR = byte;
        while ((r.SR & registers.SPI_SR_RXNE) == 0) {}
        return @intCast(r.DR & 0xFF);
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

test "SPI1 master initialization" {
    registers.mock_spi1 = std.mem.zeroes(registers.SpiRegs);
    Spi.initMaster(0b010, 0, 1);

    try std.testing.expect((registers.mock_spi1.CR1 & registers.SPI_CR1_MSTR) != 0);
    try std.testing.expect((registers.mock_spi1.CR1 & registers.SPI_CR1_CPHA) != 0);
    try std.testing.expect((registers.mock_spi1.CR2 & registers.SPI_CR2_RXDMAEN) != 0);
}
