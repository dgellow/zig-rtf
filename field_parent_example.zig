const std = @import("std");

const Child = struct {
    value: u32,
};

const Parent = struct {
    child: Child,
    other_value: u32,
};

pub fn main() !void {
    var parent = Parent{
        .child = Child{ .value = 42 },
        .other_value = 100,
    };
    
    const child_ptr = &parent.child;
    
    // Try to get the parent from the child
    const recovered_parent = getParent(child_ptr);
    
    std.debug.print("Parent.other_value = {}\n", .{recovered_parent.other_value});
}

fn getParent(child: *Child) *Parent {
    _ = child;
    return undefined;
}