//! STM32L031 GPIO Hardware Abstraction Layer
//!
//! Provides zero-overhead, type-safe pin configuration and control.

const std = @import("std");
const registers = @import("registers.zig");

pub const Port = enum(u2) {
    A = 0,
    B = 1,
    C = 2,

    pub inline fn regs(self: Port) *volatile registers.GpioRegs {
        return switch (self) {
            .A => registers.getGpioA(),
            .B => registers.getGpioB(),
            .C => registers.getGpioC(),
        };
    }
};

pub const PinMode = enum(u2) {
    input = 0b00,
    output = 0b01,
    alternate = 0b10,
    analog = 0b11,
};

pub const OutputType = enum(u1) {
    push_pull = 0,
    open_drain = 1,
};

pub const Speed = enum(u2) {
    very_low = 0b00,
    low = 0b01,
    medium = 0b10,
    high = 0b11,
};

pub const Pull = enum(u2) {
    none = 0b00,
    up = 0b01,
    down = 0b10,
};

pub const Pin = struct {
    port: Port,
    pin: u4,

    pub inline fn init(port: Port, pin: u4) Pin {
        return .{ .port = port, .pin = pin };
    }

    pub inline fn configure(
        self: Pin,
        mode: PinMode,
        out_type: OutputType,
        speed: Speed,
        pull: Pull,
    ) void {
        const r = self.port.regs();
        const p: u5 = self.pin;
        const shift2: u5 = @intCast(p * 2);
        const shift1: u5 = p;

        // MODER (2 bits per pin)
        r.MODER = (r.MODER & ~(@as(u32, 0b11) << shift2)) | (@as(u32, @intFromEnum(mode)) << shift2);

        // OTYPER (1 bit per pin)
        r.OTYPER = (r.OTYPER & ~(@as(u32, 1) << shift1)) | (@as(u32, @intFromEnum(out_type)) << shift1);

        // OSPEEDR (2 bits per pin)
        r.OSPEEDR = (r.OSPEEDR & ~(@as(u32, 0b11) << shift2)) | (@as(u32, @intFromEnum(speed)) << shift2);

        // PUPDR (2 bits per pin)
        r.PUPDR = (r.PUPDR & ~(@as(u32, 0b11) << shift2)) | (@as(u32, @intFromEnum(pull)) << shift2);
    }

    pub inline fn setMode(self: Pin, mode: PinMode) void {
        const p: u5 = self.pin;
        const shift2: u5 = @intCast(p * 2);
        const r = self.port.regs();
        r.MODER = (r.MODER & ~(@as(u32, 0b11) << shift2)) | (@as(u32, @intFromEnum(mode)) << shift2);
    }

    pub inline fn setOutputType(self: Pin, out_type: OutputType) void {
        const p: u5 = self.pin;
        const shift1: u5 = p;
        const r = self.port.regs();
        r.OTYPER = (r.OTYPER & ~(@as(u32, 1) << shift1)) | (@as(u32, @intFromEnum(out_type)) << shift1);
    }

    pub inline fn setSpeed(self: Pin, speed: Speed) void {
        const p: u5 = self.pin;
        const shift2: u5 = @intCast(p * 2);
        const r = self.port.regs();
        r.OSPEEDR = (r.OSPEEDR & ~(@as(u32, 0b11) << shift2)) | (@as(u32, @intFromEnum(speed)) << shift2);
    }

    pub inline fn setPull(self: Pin, pull: Pull) void {
        const p: u5 = self.pin;
        const shift2: u5 = @intCast(p * 2);
        const r = self.port.regs();
        r.PUPDR = (r.PUPDR & ~(@as(u32, 0b11) << shift2)) | (@as(u32, @intFromEnum(pull)) << shift2);
    }

    pub inline fn setAlternateFunction(self: Pin, af: u4) void {
        const r = self.port.regs();
        const p: u5 = self.pin;
        const afr_idx: usize = if (p < 8) 0 else 1;
        const shift: u5 = @intCast((p % 8) * 4);

        r.AFR[afr_idx] = (r.AFR[afr_idx] & ~(@as(u32, 0xF) << shift)) | (@as(u32, af) << shift);
    }

    pub inline fn setHigh(self: Pin) void {
        const shift: u5 = self.pin;
        self.port.regs().BSRR = @as(u32, 1) << shift;
    }

    pub inline fn setLow(self: Pin) void {
        const shift: u5 = self.pin;
        self.port.regs().BRR = @as(u32, 1) << shift;
    }

    pub inline fn write(self: Pin, val: bool) void {
        if (val) self.setHigh() else self.setLow();
    }

    pub inline fn toggle(self: Pin) void {
        const shift: u5 = self.pin;
        const mask = @as(u32, 1) << shift;
        const r = self.port.regs();
        if ((r.ODR & mask) != 0) {
            r.BRR = mask;
        } else {
            r.BSRR = mask;
        }
    }

    pub inline fn read(self: Pin) bool {
        const shift: u5 = self.pin;
        return (self.port.regs().IDR & (@as(u32, 1) << shift)) != 0;
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

test "Pin configuration and state control" {
    registers.mock_gpioa = std.mem.zeroes(registers.GpioRegs);
    const pa5 = Pin.init(.A, 5);

    pa5.configure(.output, .push_pull, .high, .none);
    try std.testing.expectEqual(@as(u32, 0b01) << 10, registers.mock_gpioa.MODER);
    try std.testing.expectEqual(@as(u32, 0b11) << 10, registers.mock_gpioa.OSPEEDR);

    pa5.setAlternateFunction(6);
    try std.testing.expectEqual(@as(u32, 6) << 20, registers.mock_gpioa.AFR[0]);

    pa5.setHigh();
    try std.testing.expectEqual(@as(u32, 1) << 5, registers.mock_gpioa.BSRR);

    pa5.setLow();
    try std.testing.expectEqual(@as(u32, 1) << 5, registers.mock_gpioa.BRR);
}
