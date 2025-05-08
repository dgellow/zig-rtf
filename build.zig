const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // This creates a "module", which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Every executable or library we compile will be based on one or more modules.
    
    const lib_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // We will also create a module for our other entry point, 'main.zig'.
    const exe_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Modules can depend on one another using the `std.Build.Module.addImport` function.
    // This is what allows Zig source code to use `@import("foo")` where 'foo' is not a
    // file path. In this case, we set up `exe_mod` to import `lib_mod`.
    exe_mod.addImport("zig_rtf_lib", lib_mod);

    // Static library
    const static_lib = b.addStaticLibrary(.{
        .name = "zig_rtf",
        .root_module = lib_mod,
        .link_libc = true, // Link against libc
    });
    b.installArtifact(static_lib);

    // Shared library for C API
    const shared_lib = b.addSharedLibrary(.{
        .name = "zig_rtf",
        .root_module = lib_mod,
        .link_libc = true, // Link against libc for C API
    });
    b.installArtifact(shared_lib);

    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a library.
    const exe = b.addExecutable(.{
        .name = "zig_rtf",
        .root_module = exe_mod,
        .link_libc = true, // Link against libc
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
        .link_libc = true, // Link against libc
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
        .link_libc = true, // Link against libc
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
    
    // Create steps for installing the C API headers
    const install_header = b.addInstallFileWithDir(
        b.path("examples/c_bindings/zigrtf.h"),
        .header,
        "zigrtf.h"
    );
    
    // Install the improved C API header
    const install_improved_header = b.addInstallFileWithDir(
        b.path("examples/c_bindings/zigrtf_improved.h"),
        .header,
        "zigrtf_improved.h"
    );
    
    b.getInstallStep().dependOn(&install_header.step);
    b.getInstallStep().dependOn(&install_improved_header.step);
    
    // Create a step for building the C example
    const build_c_example_step = b.step("c-example", "Build the C example");
    
    const c_example_cmd = b.addSystemCommand(&[_][]const u8{
        "make",
        "-C",
        "examples/c_bindings",
    });
    c_example_cmd.step.dependOn(b.getInstallStep());
    
    build_c_example_step.dependOn(&c_example_cmd.step);
    
    // Create a step for building the improved C example
    const build_improved_c_example_step = b.step("c-example-improved", "Build the improved C example");
    
    const improved_c_example_cmd = b.addSystemCommand(&[_][]const u8{
        "gcc", 
        "-Wall", 
        "-Wextra", 
        "-std=c99", 
        "-I./zig-out/include", 
        "-o", 
        "examples/c_bindings/rtf_example_improved", 
        "examples/c_bindings/rtf_example_improved.c", 
        "-L./zig-out/lib", 
        "-Wl,-rpath,./zig-out/lib", 
        "-lzig_rtf"
    });
    improved_c_example_cmd.step.dependOn(b.getInstallStep());
    
    build_improved_c_example_step.dependOn(&improved_c_example_cmd.step);
    
    
    // Benchmark executables with different optimization levels
    // Debug build for normal benchmarks
    const benchmark_exe = b.addExecutable(.{
        .name = "benchmark",
        .root_source_file = b.path("benchmark/benchmark.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    
    // Fast build (maximum optimization) for benchmarks
    const benchmark_fast_exe = b.addExecutable(.{
        .name = "benchmark-fast",
        .root_source_file = b.path("benchmark/benchmark.zig"),
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = true,
    });
    
    // Small size build for benchmarks
    const benchmark_small_exe = b.addExecutable(.{
        .name = "benchmark-small",
        .root_source_file = b.path("benchmark/benchmark.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
        .link_libc = true,
    });
    
    // Safe build for benchmarks
    const benchmark_safe_exe = b.addExecutable(.{
        .name = "benchmark-safe",
        .root_source_file = b.path("benchmark/benchmark.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
        .link_libc = true,
    });
    
    // Add dependency on the library module for all benchmark executables
    benchmark_exe.root_module.addImport("zig_rtf_lib", lib_mod);
    benchmark_fast_exe.root_module.addImport("zig_rtf_lib", lib_mod);
    benchmark_small_exe.root_module.addImport("zig_rtf_lib", lib_mod);
    benchmark_safe_exe.root_module.addImport("zig_rtf_lib", lib_mod);
    
    // Install the benchmark executables
    b.installArtifact(benchmark_exe);
    b.installArtifact(benchmark_fast_exe);
    b.installArtifact(benchmark_small_exe);
    b.installArtifact(benchmark_safe_exe);
    
    // Create run steps for each benchmark executable with appropriate parameters
    const run_benchmark_cmd = b.addRunArtifact(benchmark_exe);
    run_benchmark_cmd.step.dependOn(b.getInstallStep());
    run_benchmark_cmd.addArgs(&[_][]const u8{"Debug"});
    
    const run_benchmark_fast_cmd = b.addRunArtifact(benchmark_fast_exe);
    run_benchmark_fast_cmd.step.dependOn(b.getInstallStep());
    run_benchmark_fast_cmd.addArgs(&[_][]const u8{"ReleaseFast"});
    
    const run_benchmark_small_cmd = b.addRunArtifact(benchmark_small_exe);
    run_benchmark_small_cmd.step.dependOn(b.getInstallStep());
    run_benchmark_small_cmd.addArgs(&[_][]const u8{"ReleaseSmall"});
    
    const run_benchmark_safe_cmd = b.addRunArtifact(benchmark_safe_exe);
    run_benchmark_safe_cmd.step.dependOn(b.getInstallStep());
    run_benchmark_safe_cmd.addArgs(&[_][]const u8{"ReleaseSafe"});
    
    // Add individual benchmark steps for each optimization mode
    const benchmark_step = b.step("benchmark", "Run performance benchmarks (default optimization)");
    benchmark_step.dependOn(&run_benchmark_cmd.step);
    
    const benchmark_fast_step = b.step("benchmark-fast", "Run performance benchmarks (ReleaseFast optimization)");
    benchmark_fast_step.dependOn(&run_benchmark_fast_cmd.step);
    
    const benchmark_small_step = b.step("benchmark-small", "Run performance benchmarks (ReleaseSmall optimization)");
    benchmark_small_step.dependOn(&run_benchmark_small_cmd.step);
    
    const benchmark_safe_step = b.step("benchmark-safe", "Run performance benchmarks (ReleaseSafe optimization)");
    benchmark_safe_step.dependOn(&run_benchmark_safe_cmd.step);
    
    // Create a comprehensive benchmark step that runs all variants
    const benchmark_all_step = b.step("benchmark-all", "Run all benchmarks with different optimization levels");
    // Order matters here to ensure sequential execution
    run_benchmark_fast_cmd.step.dependOn(&run_benchmark_cmd.step);
    run_benchmark_small_cmd.step.dependOn(&run_benchmark_fast_cmd.step);
    run_benchmark_safe_cmd.step.dependOn(&run_benchmark_small_cmd.step);
    
    // The benchmark-all step depends on the entire chain
    benchmark_all_step.dependOn(&run_benchmark_safe_cmd.step);
    
    // Create a comprehensive step that builds everything, runs tests, and runs benchmarks
    // This provides a single command to validate everything
    const all_step = b.step("all", "Build, test, and benchmark everything");
    
    // First build and test
    all_step.dependOn(b.getInstallStep());
    all_step.dependOn(test_step);
    
    // Add C example build - both versions
    all_step.dependOn(build_c_example_step);
    all_step.dependOn(build_improved_c_example_step);
    
    // Run the fast benchmark (best for quick validation)
    all_step.dependOn(benchmark_fast_step);
    
    // Create a bash script that runs everything
    const create_script_cmd = b.addSystemCommand(&[_][]const u8{
        "sh", "-c", 
        \\cat > zig-out/bin/run_all.sh << 'EOF'
        \\#!/bin/bash
        \\
        \\# Stop on any error
        \\set -e
        \\
        \\echo "===== ZigRTF: Building, testing, and benchmarking everything ====="
        \\echo ""
        \\
        \\# Ensure test data files exist and fix paths
        \\echo "Checking test data files..."
        \\if [ ! -d "test/data" ]; then
        \\    mkdir -p test/data
        \\fi
        \\
        \\# Create symlinks to actual test files if they don't exist
        \\if [ ! -f "test/data/simple.rtf" ]; then
        \\    echo "Creating test data files..."
        \\    # Create a simple RTF file
        \\    cat > test/data/simple.rtf << 'RTFEOF'
        \\{\rtf1\ansi\deff0{\fonttbl{\f0 Times New Roman;}}\f0\fs48 This is \b bold\b0 and \i italic\i0 text.\par\cf2 This text is blue.\cf0\par}
        \\RTFEOF
        \\fi
        \\
        \\# Build everything
        \\echo "Building ZigRTF..."
        \\zig build
        \\
        \\# Run tests
        \\echo ""
        \\echo "Running tests..."
        \\zig build test
        \\
        \\# Build C examples
        \\echo ""
        \\echo "Building C examples..."
        \\zig build c-example
        \\zig build c-example-improved
        \\
        \\# Run C examples
        \\echo ""
        \\echo "Running C examples..."
        \\cd examples/c_bindings
        \\./rtf_example ../../test/data/simple.rtf
        \\cd ../..
        \\
        \\# Run benchmarks
        \\echo ""
        \\echo "Running benchmarks (ReleaseFast)..."
        \\zig build -Doptimize=ReleaseFast benchmark-fast
        \\
        \\echo ""
        \\echo "===== All done! Everything is working! ====="
        \\EOF
        \\chmod +x zig-out/bin/run_all.sh
    });
    
    create_script_cmd.step.dependOn(b.getInstallStep());
    all_step.dependOn(&create_script_cmd.step);
    
    // Add a message about using the script
    const all_message = b.step("help-all", "Print information about running all tests and benchmarks");
    const print_cmd = b.addSystemCommand(&[_][]const u8{
        "echo", 
        \\To build, test, and benchmark everything in one go:
        \\  zig build all       # Just builds everything and sets up the script
        \\  ./zig-out/bin/run_all.sh  # Runs everything with proper paths
    });
    all_message.dependOn(&print_cmd.step);
}
