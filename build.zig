const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Core RTF library (Zig)
    const lib = b.addStaticLibrary(.{
        .name = "zigrtf",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    // C API library
    const c_lib = b.addStaticLibrary(.{
        .name = "zigrtf_c",
        .root_source_file = b.path("src/c_api.zig"),
        .target = target,
        .optimize = optimize,
    });
    c_lib.linkLibC();
    b.installArtifact(c_lib);

    // Shared library for C users
    const shared_lib = b.addSharedLibrary(.{
        .name = "zigrtf",
        .root_source_file = b.path("src/c_api.zig"),
        .target = target,
        .optimize = optimize,
    });
    shared_lib.linkLibC();
    b.installArtifact(shared_lib);

    // Install C header
    const install_header = b.addInstallFileWithDir(
        b.path("src/c_api.h"),
        .header,
        "zigrtf.h",
    );
    b.getInstallStep().dependOn(&install_header.step);

    // Zig executable
    const exe = b.addExecutable(.{
        .name = "zigrtf",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    // C example
    const c_example = b.addExecutable(.{
        .name = "c_example",
        .target = target,
        .optimize = optimize,
    });
    c_example.addCSourceFile(.{
        .file = b.path("examples/c_example.c"),
        .flags = &[_][]const u8{"-std=c99"},
    });
    c_example.linkLibrary(c_lib);
    c_example.linkLibC();
    b.installArtifact(c_example);

    // Run commands
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the RTF parser");
    run_step.dependOn(&run_cmd.step);

    const run_c_example = b.addRunArtifact(c_example);
    run_c_example.step.dependOn(b.getInstallStep());
    const c_example_step = b.step("c-example", "Run C API example");
    c_example_step.dependOn(&run_c_example.step);

    // Demo applications
    const zig_reader = b.addExecutable(.{
        .name = "zig_reader",
        .root_source_file = b.path("demos/zig_reader.zig"),
        .target = target,
        .optimize = optimize,
    });
    zig_reader.root_module.addImport("rtf", lib.root_module);
    b.installArtifact(zig_reader);
    
    const c_reader = b.addExecutable(.{
        .name = "c_reader",
        .target = target,
        .optimize = optimize,
    });
    c_reader.addCSourceFile(.{
        .file = b.path("demos/c_reader.c"),
        .flags = &[_][]const u8{"-std=c99"},
    });
    c_reader.linkLibrary(c_lib);
    c_reader.linkLibC();
    b.installArtifact(c_reader);
    
    // Demo run commands
    const run_zig_reader = b.addRunArtifact(zig_reader);
    run_zig_reader.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_zig_reader.addArgs(args);
    }
    const zig_demo_step = b.step("demo-zig", "Run Zig RTF reader demo");
    zig_demo_step.dependOn(&run_zig_reader.step);
    
    const run_c_reader = b.addRunArtifact(c_reader);
    run_c_reader.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_c_reader.addArgs(args);
    }
    const c_demo_step = b.step("demo-c", "Run C RTF reader demo");
    c_demo_step.dependOn(&run_c_reader.step);

    // Tests
    const lib_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_lib_tests = b.addRunArtifact(lib_tests);

    // Add test case step
    const tests = b.addTest(.{
        .root_source_file = b.path("src/test_cases.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const run_tests = b.addRunArtifact(tests);
    run_tests.step.dependOn(&lib.step);
    
    // Add formatting tests
    const formatting_tests = b.addTest(.{
        .root_source_file = b.path("src/formatting_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const run_formatting_tests = b.addRunArtifact(formatting_tests);
    run_formatting_tests.step.dependOn(&lib.step);
    
    // Add real world tests
    const real_world_tests = b.addTest(.{
        .root_source_file = b.path("src/real_world_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const run_real_world_tests = b.addRunArtifact(real_world_tests);
    run_real_world_tests.step.dependOn(&lib.step);
    
    // Add security tests
    const security_tests = b.addTest(.{
        .root_source_file = b.path("src/security_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const run_security_tests = b.addRunArtifact(security_tests);
    run_security_tests.step.dependOn(&lib.step);
    
    // Add thread safety tests  
    const thread_safety_tests = b.addTest(.{
        .root_source_file = b.path("src/thread_safety_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const run_thread_safety_tests = b.addRunArtifact(thread_safety_tests);
    run_thread_safety_tests.step.dependOn(&lib.step);
    
    // Add complex content tests
    const complex_content_tests = b.addTest(.{
        .root_source_file = b.path("src/complex_content_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const run_complex_content_tests = b.addRunArtifact(complex_content_tests);
    run_complex_content_tests.step.dependOn(&lib.step);
    
    // Add C API security tests
    const c_api_security_tests = b.addTest(.{
        .root_source_file = b.path("src/c_api_security_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    c_api_security_tests.linkLibC();
    
    const run_c_api_security_tests = b.addRunArtifact(c_api_security_tests);
    run_c_api_security_tests.step.dependOn(&lib.step);
    
    // Add RTF generation tests
    const generation_tests = b.addTest(.{
        .root_source_file = b.path("src/generation_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    generation_tests.linkLibC();
    
    const run_generation_tests = b.addRunArtifact(generation_tests);
    run_generation_tests.step.dependOn(&lib.step);

    // Memory benchmark
    const memory_benchmark = b.addExecutable(.{
        .name = "memory_benchmark",
        .root_source_file = b.path("src/memory_benchmark.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(memory_benchmark);
    
    const run_memory_benchmark = b.addRunArtifact(memory_benchmark);
    run_memory_benchmark.step.dependOn(b.getInstallStep());
    const memory_benchmark_step = b.step("memory-benchmark", "Run memory usage benchmark");
    memory_benchmark_step.dependOn(&run_memory_benchmark.step);
    
    // Extreme benchmark
    const extreme_benchmark = b.addExecutable(.{
        .name = "extreme_benchmark",
        .root_source_file = b.path("src/extreme_benchmark.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(extreme_benchmark);
    
    const run_extreme_benchmark = b.addRunArtifact(extreme_benchmark);
    run_extreme_benchmark.step.dependOn(b.getInstallStep());
    const extreme_benchmark_step = b.step("extreme-benchmark", "Generate and test massive RTF files");
    extreme_benchmark_step.dependOn(&run_extreme_benchmark.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_tests.step);
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_formatting_tests.step);
    test_step.dependOn(&run_real_world_tests.step);
    test_step.dependOn(&run_security_tests.step);
    test_step.dependOn(&run_thread_safety_tests.step);
    test_step.dependOn(&run_complex_content_tests.step);
    test_step.dependOn(&run_c_api_security_tests.step);
    test_step.dependOn(&run_generation_tests.step);
}