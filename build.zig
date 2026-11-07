const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });

    // ------------------------------------------------------------------------
    // Target: STM32L031 (ARM Cortex-M0+ Thumb Freestanding)
    // ------------------------------------------------------------------------
    const stm32_target = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m0plus },
        .os_tag = .freestanding,
        .abi = .eabi,
    });

    const hal_mod = b.createModule(.{
        .root_source_file = b.path("src/hal/root.zig"),
        .target = stm32_target,
        .optimize = .ReleaseSmall,
    });

    const rtos_mod = b.createModule(.{
        .root_source_file = b.path("src/rtos/root.zig"),
        .target = stm32_target,
        .optimize = .ReleaseSmall,
    });

    const app_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = stm32_target,
        .optimize = .ReleaseSmall,
        .strip = false,
        .imports = &.{
            .{ .name = "hal", .module = hal_mod },
            .{ .name = "rtos", .module = rtos_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "stm32_freertos.elf",
        .root_module = app_mod,
    });

    exe.entry = .{ .symbol_name = "Reset_Handler" };

    const c_flags: []const []const u8 = &.{
        "-Os",
        "-mcpu=cortex-m0plus",
        "-mthumb",
        "-ffunction-sections",
        "-fdata-sections",
        "-DSTM32L031xx",
        "-DUSE_HAL_DRIVER",
    };

    exe.root_module.addSystemIncludePath(b.path("include/libc_compat"));

    const stm32_includes: []const []const u8 = &.{
        "include",
        "vendor/config",
        "vendor/freertos/include",
        "vendor/freertos/portable",
        "vendor/hal",
        "vendor/cmsis",
    };
    for (stm32_includes) |inc| {
        exe.root_module.addIncludePath(b.path(inc));
    }

    const stm32_base_c_sources: []const []const u8 = &.{
        "vendor/startup/startup_stm32l031xx.c",
        "vendor/startup/system_stm32l0xx.c",
        "vendor/hal/stm32l0xx_hal.c",
        "vendor/hal/stm32l0xx_hal_cortex.c",
        "vendor/hal/stm32l0xx_hal_gpio.c",
    };

    const stm32_freertos_c_sources: []const []const u8 = &.{
        "vendor/freertos/list.c",
        "vendor/freertos/queue.c",
        "vendor/freertos/tasks.c",
        "vendor/freertos/portable/port.c",
        "vendor/freertos/portable/portasm.c",
        "vendor/lptim/lptimTick.c",
    };

    for (stm32_base_c_sources) |src| {
        exe.root_module.addCSourceFile(.{
            .file = b.path(src),
            .flags = c_flags,
        });
    }

    for (stm32_freertos_c_sources) |src| {
        exe.root_module.addCSourceFile(.{
            .file = b.path(src),
            .flags = c_flags,
        });
    }

    exe.setLinkerScript(b.path("linker/stm32l031g6u6.ld"));

    b.installArtifact(exe);

    const bin = exe.addObjCopy(.{ .format = .binary });
    const install_bin = b.addInstallFile(bin.getOutput(), "bin/stm32_freertos.bin");
    b.getInstallStep().dependOn(&install_bin.step);

    // ------------------------------------------------------------------------
    // Host Unit Tests (`zig build test --summary all`)
    // ------------------------------------------------------------------------
    const host_target = b.graph.host;

    const host_hal_mod = b.createModule(.{
        .root_source_file = b.path("src/hal/root.zig"),
        .target = host_target,
        .optimize = optimize,
    });

    const host_rtos_mod = b.createModule(.{
        .root_source_file = b.path("src/rtos/root.zig"),
        .target = host_target,
        .optimize = optimize,
    });

    const host_app_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = host_target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "hal", .module = host_hal_mod },
            .{ .name = "rtos", .module = host_rtos_mod },
        },
    });

    const test_hal = b.addTest(.{ .root_module = host_hal_mod });
    const test_rtos = b.addTest(.{ .root_module = host_rtos_mod });
    const test_main = b.addTest(.{ .root_module = host_app_mod });

    const run_test_hal = b.addRunArtifact(test_hal);
    const run_test_rtos = b.addRunArtifact(test_rtos);
    const run_test_main = b.addRunArtifact(test_main);

    const test_step = b.step("test", "Run unit tests on host platform");
    test_step.dependOn(&run_test_hal.step);
    test_step.dependOn(&run_test_rtos.step);
    test_step.dependOn(&run_test_main.step);

    // ------------------------------------------------------------------------
    // Flash Step (`zig build flash`)
    // ------------------------------------------------------------------------
    const flash_step = b.step("flash", "Flash firmware to STM32 target (auto-detects openocd, st-flash, or probe-rs)");
    const run_flash = b.addSystemCommand(&.{
        "bash", "-c",
        \\BIN="zig-out/bin/stm32_freertos.bin"
        \\ELF="zig-out/bin/stm32_freertos.elf"
        \\if command -v openocd >/dev/null 2>&1; then
        \\  echo "Flashing via OpenOCD..."
        \\  exec openocd -f interface/stlink.cfg -f target/stm32l0.cfg -c "program $BIN 0x08000000 verify reset exit"
        \\elif command -v st-flash >/dev/null 2>&1; then
        \\  echo "Flashing via st-flash..."
        \\  exec st-flash write "$BIN" 0x08000000
        \\elif command -v probe-rs >/dev/null 2>&1; then
        \\  echo "Flashing via probe-rs..."
        \\  exec probe-rs run --chip STM32L031G6Ux "$ELF"
        \\else
        \\  echo "Error: No supported flasher found (install openocd, stlink, or probe-rs)." >&2
        \\  exit 1
        \\fi
    });
    run_flash.step.dependOn(&install_bin.step);
    flash_step.dependOn(&run_flash.step);

    // ------------------------------------------------------------------------
    // Clean Step (`zig build clean`)
    // ------------------------------------------------------------------------
    const clean_step = b.step("clean", "Remove build output and cache directories");
    const run_clean = b.addSystemCommand(&.{ "rm", "-rf", "zig-out", ".zig-cache" });
    clean_step.dependOn(&run_clean.step);
}
