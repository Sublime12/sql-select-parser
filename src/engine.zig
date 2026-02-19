const std = @import("std");
const Allocator = std.mem.Allocator;
const expression_pkg = @import("expression.zig");

const panic = std.debug.panic;

const Expr = expression_pkg.Expr;
const CondExpr = expression_pkg.CondExpr;
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
        // for (self.columns.items) |col| {
        //     allocator.free(col);
        // }
        self.columns.deinit(allocator);
        for (self.rows.items) |*row| {
            row.deinit(allocator);
        }
        self.rows.deinit(allocator);
    }

    pub fn print(self: *const Table, writer: *std.io.Writer) !void {
        try writer.print("Result: \n", .{});
        for (self.columns.items) |col| {
            try writer.print("{s}\t", .{col});
        }
        try writer.print("\n", .{});
        for (self.rows.items) |row| {
            for (row.items) |el| {
                try writer.print("{}\t", .{el});
            }
            try writer.print("\n", .{});
        }
    }
};

pub fn execute(
    alloc: Allocator,
    result: *Table,
    table: *const Table,
    expr: *const Expr,
) !void {
    if (expr.from) |from| {
        // assert table does exist
        std.debug.assert(std.mem.eql(u8, from.name, table.name));

        for (table.rows.items) |*row| {
            if (expr.where) |where| {
                if (evalCondExpr(&where.cond, row, table)) {
                    try getRow(alloc, result, &expr.select, row, table);
                }
            } else {
                try getRow(alloc, result, &expr.select, row, table);
            }
        }
    }
    // _ = result;
    // _ = table;
    // _ = expr;
    // unreachable;
}

fn evalCondExpr(
    expr: *const CondExpr,
    row: *const Row,
    table: *const Table,
) bool {
    switch (expr.*) {
        .equal => |eqlCond| {
            if (findIdx(eqlCond.id, table.columns)) |i| {
                // the filter clause with eql
                if (row.items[i] == eqlCond.val) {
                    return true;
                }
            } else {
                panic("column {s} not found", .{eqlCond.id});
            }
        },
        .gt => |gtCond| {
            if (findIdx(gtCond.id, table.columns)) |i| {
                if (row.items[i] > gtCond.val) {
                    return true;
                }
            } else {
                panic("column {s} not found", .{gtCond.id});
            }
        },
        .lt => |ltCond| {
            if (findIdx(ltCond.id, table.columns)) |i| {
                if (row.items[i] < ltCond.val) {
                    return true;
                }
            } else {
                panic("column {s} not found", .{ltCond.id});
            }
        },
        .and_ => |andCond| {
            const eval1 = evalCondExpr(&andCond.cond1, row, table);
            if (!eval1) return false;
            return evalCondExpr(&andCond.cond2, row, table);
        },
        .or_ => |orCond| {
            const eval1 = evalCondExpr(&orCond.cond1, row, table);
            if (eval1) return true;
            return evalCondExpr(&orCond.cond2, row, table);
        },
        else => @panic("expr cond not found"),
    }
    return false;
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
