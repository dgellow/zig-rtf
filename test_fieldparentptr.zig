const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    const Parent = struct {
        x: u32,
        y: u32,
    };
    
    const Child = struct {
        parent: Parent,
        value: u32,
    };
    
    var child = Child{
        .parent = .{
            .x = 10,
            .y = 20,
        },
        .value = 30,
    };
    
    // Get a pointer to the parent field
    const parent_ptr = &child.parent;
    
    // Based on error message, try with @as
    const recovered_child_ptr = @fieldParentPtr(@as(*Child, undefined), parent_ptr);
    
    try stdout.print("Child value: {}\n", .{recovered_child_ptr.value});
}