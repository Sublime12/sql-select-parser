const std = @import("std");
const expression_pkg = @import("expression.zig");
const parser_pkg = @import("parser.zig");

const Expr = expression_pkg.Expr;
const FromClause = expression_pkg.FromClause;
const SelectClause = expression_pkg.SelectClause;
const Lexer = parser_pkg.Lexer;
const Parser = parser_pkg.Parser;

pub fn main() !void {
    const query =
        \\ select ab, cd,
        \\ from  table
        \\ where condition
        \\ 
    ;

    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();
    var lexer = Lexer.init(allocator, query, query.len, "select.sql");

    var parser = Parser.init(allocator, &lexer);
    var expr = try parser.parse();
    defer expr.deinit(allocator);

    std.debug.print("expr: {f}\n", .{expr});
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
