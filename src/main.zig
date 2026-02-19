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

pub fn main() !void {}

test "create simple sql ast" {
    const from = FromClause.init("table");
    const allocator = std.testing.allocator;

    var columns = SelectClause.Columns.empty;
    defer columns.deinit(allocator);

    try columns.append(allocator, .{ .id = "c1" });
    try columns.append(allocator, .{ .id = "c2" });

    const select = SelectClause.init(columns);

    const expr = Expr.init(select, from, null);

    std.debug.print("expr: {f}\n", .{expr});
}

fn createTestTable(allocator: Allocator) !Table {
    var columns = std.ArrayList([]const u8).empty;
    inline for (0..5) |i| {
        try columns.append(allocator, std.fmt.comptimePrint("col{}", .{i}));
    }
    var table = Table.init(columns, "table1");

    var n: i32 = 0;

    for (0..20) |_| {
        var row: Row = .empty;
        for (0..5) |_| {
            try row.append(allocator, n);
            n += 1;
        }
        try table.rows.append(allocator, row);
    }

    return table;
}

test "run simple select from table" {
    const query =
        \\ select col2, col1, from table1 
    ;

    var buffer: [1024]u8 = undefined;
    var errwriter = std.fs.File.stderr().writer(&buffer);
    const stderr = &errwriter.interface;

    const allocator = std.testing.allocator;
    var lexer = Lexer.init(allocator, query, query.len, "select.sql");
    defer lexer.deinit();

    var parser = Parser.init(allocator, &lexer);
    var expr = try parser.parse();
    defer expr.deinit(allocator);

    var table = try createTestTable(allocator);
    defer table.deinit(allocator);
    // try table.print(stderr);
    try stderr.flush();

    var result: Table = .empty;
    defer result.deinit(allocator);
    try execute(allocator, &result, &table, &expr);
    try std.testing.expect(result.rows.items.len == 20);
}

test "run simple select from table with where = id" {
    const query =
        \\ select col2, col1, from table1 where col1 = 6 
    ;

    var buffer: [1024]u8 = undefined;
    var errwriter = std.fs.File.stderr().writer(&buffer);
    const stderr = &errwriter.interface;

    const allocator = std.testing.allocator;
    var lexer = Lexer.init(allocator, query, query.len, "select.sql");
    defer lexer.deinit();

    var parser = Parser.init(allocator, &lexer);
    var expr = try parser.parse();
    defer expr.deinit(allocator);

    var table = try createTestTable(allocator);
    defer table.deinit(allocator);

    var result: Table = .empty;
    defer result.deinit(allocator);

    try execute(allocator, &result, &table, &expr);
    try result.print(stderr);
    try std.testing.expect(result.rows.items.len == 1);
    const row = result.rows.items[0];
    try std.testing.expect(row.items.len == 2);
    try std.testing.expect(row.items[0] == 7);
    try std.testing.expect(row.items[1] == 6);

    try stderr.flush();
}
