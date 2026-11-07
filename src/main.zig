//! STM32L031 + FreeRTOS Static Firmware Template in Zig 0.17
//!
//! Features:
//! - Freestanding ARM Cortex-M0+ targeting STM32L031G6U6 (32 KB Flash, 8 KB SRAM).
//! - 100% Static FreeRTOS task, queue, and mutex allocation (zero heap runtime).
//! - Clean hardware abstraction (HAL) with type-safe MMIO register control.
//! - Dual-task cooperative architecture:
//!     1. Heartbeat task: pulses indicator pin and enqueues periodic telemetry.
//!     2. Telemetry task: consumes messages from FreeRTOS static queue and prints to LPUART1.
//! - 100% testable on host platforms via `zig build test` without hardware.

const std = @import("std");
const builtin = @import("builtin");
const hal = @import("hal");
const rtos = @import("rtos");

// ============================================================================
// Board Pin Configuration
// ============================================================================

pub const PIN_HEARTBEAT = 15; // PA15 as indicator output
pub const PIN_UART_TX = 2; // PA2 as LPUART1 TX (AF6)
pub const PIN_UART_RX = 3; // PA3 as LPUART1 RX (AF6)

// ============================================================================
// Static Data Structures & FreeRTOS Allocations
// ============================================================================

pub const HeartbeatMsg = extern struct {
    count: u32,
    tick: u32,
};

pub const QUEUE_CAPACITY = 8;
var g_telemetry_queue = rtos.StaticQueue(HeartbeatMsg, QUEUE_CAPACITY){};

// Heartbeat Task (Priority 1)
pub const HEARTBEAT_STACK_WORDS = 128;
var g_heartbeat_stack: [HEARTBEAT_STACK_WORDS]rtos.StackType_t = undefined;
var g_heartbeat_tcb: rtos.StaticTask_t = undefined;

// Telemetry Task (Priority 2)
pub const TELEMETRY_STACK_WORDS = 192;
var g_telemetry_stack: [TELEMETRY_STACK_WORDS]rtos.StackType_t = undefined;
var g_telemetry_tcb: rtos.StaticTask_t = undefined;

// FreeRTOS Idle Task Memory
var g_idle_task_stack: [rtos.MINIMAL_STACK_SIZE]rtos.StackType_t = undefined;
var g_idle_task_tcb: rtos.StaticTask_t = undefined;

// ============================================================================
// FreeRTOS Required Static Hooks & Callbacks
// ============================================================================

fn vApplicationGetIdleTaskMemory(
    ppxIdleTaskTCBBuffer: *?*rtos.StaticTask_t,
    ppxIdleTaskStackBuffer: *?[*]rtos.StackType_t,
    pulIdleTaskStackSize: *u32,
) callconv(.c) void {
    ppxIdleTaskTCBBuffer.* = &g_idle_task_tcb;
    ppxIdleTaskStackBuffer.* = &g_idle_task_stack;
    pulIdleTaskStackSize.* = rtos.MINIMAL_STACK_SIZE;
}

fn vApplicationStackOverflowHook(xTask: rtos.TaskHandle_t, pcTaskName: ?[*:0]const u8) callconv(.c) void {
    _ = xTask;
    hal.uart.Lpuart.writeString("\r\n[PANIC] FreeRTOS stack overflow in task: ");
    if (pcTaskName) |name| {
        hal.uart.Lpuart.writeString(std.mem.span(name));
    }
    hal.uart.Lpuart.writeString("\r\n");
    while (true) {}
}

fn vApplicationTickHook() callconv(.c) void {
    if (!builtin.is_test) {
        const C = struct {
            extern fn HAL_IncTick() callconv(.c) void;
        };
        C.HAL_IncTick();
    }
}

fn vApplicationPreSleepProcessing(pxExpectedIdleTime: *u32) callconv(.c) void {
    _ = pxExpectedIdleTime;
}

fn vApplicationPostSleepProcessing(xExpectedIdleTime: u32) callconv(.c) void {
    _ = xExpectedIdleTime;
}

fn sleep_mgr_get_mode() callconv(.c) u8 {
    return 0; // Default active/run mode
}

fn HAL_InitTick(TickPriority: u32) callconv(.c) c_int {
    _ = TickPriority;
    return 0; // HAL_OK
}

fn vAssertCalled(file: ?[*:0]const u8, line: c_int) callconv(.c) void {
    _ = file;
    _ = line;
    hal.uart.Lpuart.writeString("\r\n[PANIC] FreeRTOS configASSERT failed!\r\n");
    while (true) {}
}

comptime {
    if (!builtin.is_test) {
        @export(&vApplicationGetIdleTaskMemory, .{ .name = "vApplicationGetIdleTaskMemory" });
        @export(&vApplicationStackOverflowHook, .{ .name = "vApplicationStackOverflowHook" });
        @export(&vApplicationTickHook, .{ .name = "vApplicationTickHook" });
        @export(&vApplicationPreSleepProcessing, .{ .name = "vApplicationPreSleepProcessing" });
        @export(&vApplicationPostSleepProcessing, .{ .name = "vApplicationPostSleepProcessing" });
        @export(&sleep_mgr_get_mode, .{ .name = "sleep_mgr_get_mode" });
        @export(&HAL_InitTick, .{ .name = "HAL_InitTick" });
        @export(&vAssertCalled, .{ .name = "vAssertCalled" });
        @export(&app_main, .{ .name = "main" });
    }
}

// ============================================================================
// FreeRTOS Task Runners
// ============================================================================

fn heartbeatTaskRunner(param: ?*anyopaque) callconv(.c) void {
    _ = param;
    const ind = hal.Pin.init(.A, PIN_HEARTBEAT);
    var count: u32 = 0;

    while (true) {
        rtos.delayMs(500);
        ind.toggle();
        count +%= 1;

        const msg: HeartbeatMsg = .{
            .count = count,
            .tick = rtos.getTickCount(),
        };
        _ = g_telemetry_queue.send(&msg, 0);
    }
}

fn telemetryTaskRunner(param: ?*anyopaque) callconv(.c) void {
    _ = param;

    while (true) {
        var msg: HeartbeatMsg = undefined;
        if (g_telemetry_queue.receive(&msg, rtos.portMAX_DELAY)) {
            hal.uart.Lpuart.writeString("[Tick ");
            hal.uart.Lpuart.writeU32(msg.tick);
            hal.uart.Lpuart.writeString("] Heartbeat #");
            hal.uart.Lpuart.writeU32(msg.count);
            hal.uart.Lpuart.writeString(" | FreeRTOS Static Task running\r\n");
        }
    }
}

// ============================================================================
// Application Entry Point
// ============================================================================

extern fn HAL_Init() callconv(.c) c_int;

pub fn app_main() callconv(.c) c_int {
    // 1. Core clock: 16 MHz HSI16
    _ = hal.rcc.setClock16MHzHsi();
    hal.rcc.enableGpio(.A);
    hal.rcc.enableLpuart1();

    // 2. Configure Heartbeat indicator GPIO
    const ind = hal.Pin.init(.A, PIN_HEARTBEAT);
    ind.setMode(.output);
    ind.setLow();

    // 3. Configure PA2 (TX) and PA3 (RX) as AF6 (LPUART1)
    const tx = hal.Pin.init(.A, PIN_UART_TX);
    const rx = hal.Pin.init(.A, PIN_UART_RX);
    tx.setMode(.alternate);
    rx.setMode(.alternate);
    tx.setSpeed(.high);
    rx.setPull(.up);
    tx.setAlternateFunction(6);
    rx.setAlternateFunction(6);

    // 4. Initialize LPUART1 (115200 baud, 16 MHz input clock)
    hal.uart.Lpuart.init(115200, 16_000_000);

    // 5. Output boot banner
    hal.uart.Lpuart.writeString("\r\n========================================\r\n");
    hal.uart.Lpuart.writeString(" STM32L031 + Zig 0.17 + FreeRTOS Static\r\n");
    hal.uart.Lpuart.writeString(" Core: ARM Cortex-M0+ @ 16 MHz HSI16\r\n");
    hal.uart.Lpuart.writeString(" FreeRTOS: Static Only (Zero Heap Alloc)\r\n");
    hal.uart.Lpuart.writeString("========================================\r\n\r\n");

    // 6. Initialize static queues
    g_telemetry_queue.init();

    // 7. Spawn FreeRTOS static tasks
    _ = rtos.Task.createStatic(
        HEARTBEAT_STACK_WORDS,
        "heartbeat",
        1,
        heartbeatTaskRunner,
        null,
        &g_heartbeat_stack,
        &g_heartbeat_tcb,
    );

    _ = rtos.Task.createStatic(
        TELEMETRY_STACK_WORDS,
        "telemetry",
        2,
        telemetryTaskRunner,
        null,
        &g_telemetry_stack,
        &g_telemetry_tcb,
    );

    // 8. Start FreeRTOS scheduler (does not return)
    rtos.startScheduler();

    while (true) {}
}

// ============================================================================
// Host Unit Tests
// ============================================================================

test "heartbeat message size and alignment" {
    try std.testing.expectEqual(@sizeOf(HeartbeatMsg), 8);
    try std.testing.expectEqual(@alignOf(HeartbeatMsg), 4);
}

test "static queue send and receive mock" {
    var test_queue = rtos.StaticQueue(HeartbeatMsg, 4){};
    test_queue.init();

    const msg_in = HeartbeatMsg{ .count = 42, .tick = 1000 };
    try std.testing.expect(test_queue.send(&msg_in, 0));

    var msg_out: HeartbeatMsg = undefined;
    try std.testing.expect(test_queue.receive(&msg_out, 0));
    try std.testing.expectEqual(msg_out.count, 42);
    try std.testing.expectEqual(msg_out.tick, 1000);
}
