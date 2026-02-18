const std = @import("std");
const Allocator = std.mem.Allocator;
const expression_pkg = @import("expression.zig");

const Expr = expression_pkg.Expr;
const SelectClause = expression_pkg.SelectClause;

pub const Row = std.ArrayList(i32);

pub const Table = struct {
    pub const empty: Table = .{
        .columns = .empty,
        .rows = .empty,
        .name = "",
    };
    columns: std.ArrayList([]const u8),
    rows: std.ArrayList(Row),
    name: []const u8,

    pub fn init(
        columns: std.ArrayList([]const u8),
        name: []const u8,
    ) Table {
        return .{
            .columns = columns,
            .rows = .empty,
            .name = name,
        };
    }

    pub fn deinit(self: *Table, allocator: Allocator) void {
        self.columns.deinit(allocator);
        self.rows.deinit(allocator);
    }
};

pub fn execute(
    alloc: Allocator,
    result: *Table,
    table: *const Table,
    expr: *const Expr,
) !void {
    if (expr.from) |from| {
        // table does not exist
        std.debug.assert(std.mem.eql(u8, from.name, table.name));
        for (table.rows.items) |*row| {
            switch (expr.where.?.cond) {
                .equal => |eqlCond| {
                    if (findIdx(eqlCond.id, table.columns)) |i| {
                        // the filter clause with eql
                        if (row.items[i] == eqlCond.val) {
                            try getRow(alloc, result, &expr.select, row, table);
                        }
                    } else {
                        @panic("column not found");
                    }
                },
                .gt => |gtCond| {
                    if (findIdx(gtCond.id, table.columns)) |i| {
                        if (row.items[i] > gtCond.val) {
                            try getRow(alloc, result, &expr.select, row, table);
                        }
                    } else {
                        @panic("column not found");
                    }
                },
                .lt => |gtCond| {
                    if (findIdx(gtCond.id, table.columns)) |i| {
                        if (row.items[i] < gtCond.val) {
                            try getRow(alloc, result, &expr.select, row, table);
                        }
                    } else {
                        @panic("column not found");
                    }
                },
                else => @panic("expr cond not found"),
            }
        }
    }
    // _ = result;
    // _ = table;
    // _ = expr;
    // unreachable;
}

fn findIdx(needle: []const u8, list: std.ArrayList([]const u8)) ?usize {
    for (list.items, 0..) |el, i| {
        if (std.mem.eql(u8, needle, el)) {
            return i;
        }
    }
    return null;
}

pub fn getRow(
    alloc: Allocator,
    result: *Table,
    select: *const SelectClause,
    row: *const Row,
    table: *const Table,
) !void {
    // _ = result;
    // _ = select;
    // _ = row;

    var resultRow: Row = .empty;
    for (select.columns.items) |col| {
        switch (col) {
            .id => |idCol| {
                for (table.columns.items, 0..) |tcol, i| {
                    if (std.mem.eql(u8, tcol, idCol)) {
                        // std.debug.print("val: {}\n", .{row.items[i]});
                        try resultRow.append(alloc, row.items[i]);
                        // return;
                    }
                }
            },
            .expr => {
                unreachable;
            },
        }
    }

    try result.rows.append(alloc, resultRow);
}
