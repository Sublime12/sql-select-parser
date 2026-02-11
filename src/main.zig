const std = @import("std");
const expression_pkg = @import("expression.zig");
const parser_pkg = @import("parser.zig");

const Expr = expression_pkg.Expr;
const FromClause = expression_pkg.FromClause;
const SelectClause = expression_pkg.SelectClause;
const Lexer = parser_pkg.Lexer;
const Parser = parser_pkg.Parser;

pub fn main() !void {
    // const query =
    //     \\ select ab, cd,
    //     \\ from  table
    //     \\ where condition
    //     \\
    // ;

    const query1 =
        \\ select (select 15),     ab, sddd,
        \\ xxcddjdf, 
        \\          from table111
        \\ where 10202020
    ;

    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();
    var lexer = Lexer.init(allocator, query1, query1.len, "select.sql");

    _ = try lexer.next();
    while (true) {
        const token = lexer.token;
        std.debug.print("{} -> v: {s}\n", .{ token, lexer.name.items });
        if (!try lexer.next() or lexer.token == .TokenEnd) {
            break;
        }
    }

    // var parser = Parser.init(allocator, &lexer);
    // var expr = try parser.parse();
    // defer expr.deinit(allocator);

    // rows = db.execute(expr);
    // std.debug.print("expr: {f}\n", .{expr});
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
