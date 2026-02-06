const std = @import("std");
const expression_pkg = @import("expression.zig");
const parser_pkg = @import("parser.zig");

const Expr = expression_pkg.Expr;
const FromClause = expression_pkg.FromClause;
const SelectClause = expression_pkg.SelectClause;
const Lexer = parser_pkg.Lexer;

pub fn main() !void {
    const query =
        \\ select c1, c2
        \\ from  table
        \\ where condition
        \\ 
    ;

    var lexer = Lexer.init(query, query.len, "select.sql");

    while (lexer.next_char()) |n| {
        std.debug.print("{c}", .{ n });
    }
}

test "create simple sql ast" {
    const from = FromClause.init("table");

    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var columns = SelectClause.Columns.empty;
    defer columns.deinit(allocator);

    try columns.append(allocator, "c1");
    try columns.append(allocator, "c2");

    const select = SelectClause.init(columns);

    const expr = Expr.init(select, from, null);

    std.debug.print("expr: {f}\n", .{expr});
}
