const std = @import("std");
const Parser = @import("rtf.zig").Parser;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len < 2) {
        std.debug.print("Usage: {s} <rtf-file>\n", .{args[0]});
        std.debug.print("Extracts plain text from RTF documents\n", .{});
        return;
    }
    
    const file_path = args[1];
    
    // Open RTF file
    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        std.debug.print("Error opening file '{s}': {}\n", .{ file_path, err });
        return;
    };
    defer file.close();
    
    // Parse RTF and extract text
    var parser = Parser.init(file.reader().any(), allocator);
    defer parser.deinit();
    
    parser.parse() catch |err| {
        std.debug.print("Parse error: {}\n", .{err});
        return;
    };
    
    // Output extracted text
    const text = parser.getText();
    std.debug.print("{s}", .{text});
}