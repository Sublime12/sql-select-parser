const std = @import("std");

const Allocator = std.mem.Allocator;
const expression_pkg = @import("expression.zig");
const parser_pkg = @import("parser.zig");
const engine_pkg = @import("engine.zig");

const Expr = expression_pkg.Expr;
const FromClause = expression_pkg.FromClause;
const SelectClause = expression_pkg.SelectClause;
const Lexer = parser_pkg.Lexer;
const Parser = parser_pkg.Parser;
const execute = engine_pkg.execute;
const Table = engine_pkg.Table;
const Row = engine_pkg.Row;

pub fn main() !void {
    // const query =
    //     \\ select ab, cd,
    //     \\ from  table
    //     \\ where condition
    //     \\
    // ;

    // const query1 =
    //     \\ select (select 15, (select bonjour, from salut),),     ab, sddd,
    //     \\ xxcddjdf,
    //     \\          from table1
    //     \\ where 10202020
    // ;
    const query1 = "select col2, col1, from table1";

    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();
    var lexer = Lexer.init(allocator, query1, query1.len, "select.sql");

    // _ = try lexer.next();
    // while (true) {
    //     const token = lexer.token;
    //     std.debug.print("{} -> v: {s}\n", .{ token, lexer.name.items });
    //     if (!try lexer.next() or lexer.token == .TokenEnd) {
    //         break;
    //     }
    // }

    var parser = Parser.init(allocator, &lexer);
    var expr = try parser.parse();
    defer expr.deinit(allocator);

    // rows = db.execute(expr);
    std.debug.print("expr: {f}\n", .{expr});

    var columns = std.ArrayList([]const u8).empty;
    inline for (0..5) |i| {
        try columns.append(allocator, std.fmt.comptimePrint("col{}", .{i}));
    }
    var table = Table.init(columns, "table1");
    defer table.deinit(allocator);

    var n: i32 = 0;

    for (0..20) |_| {
        var row: Row = .empty;
        for (0..5) |_| {
            try row.append(allocator, n);
            n += 1;
        }
        try table.rows.append(allocator, row);
    }

    for (table.columns.items) |col| {
        std.debug.print("{s}\t", .{col});
    }
    std.debug.print("\n", .{});
    for (table.rows.items) |row| {
        for (row.items) |el| {
            std.debug.print("{}\t", .{el});
        }
        std.debug.print("\n", .{});
    }

    var result: Table = .empty;
    try execute(allocator, &result, &table, &expr);

    std.debug.print("Result: \n", .{});
    for (result.columns.items) |col| {
        std.debug.print("{s}\t", .{col});
    }
    std.debug.print("\n", .{});
    for (result.rows.items) |row| {
        for (row.items) |el| {
            std.debug.print("{}\t", .{el});
        }
        std.debug.print("\n", .{});
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
