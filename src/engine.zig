const std = @import("std");
const Allocator = std.mem.Allocator;
const expression_pkg = @import("expression.zig");

const panic = std.debug.panic;

const Expr = expression_pkg.Expr;
const CondExpr = expression_pkg.CondExpr;
const SelectClause = expression_pkg.SelectClause;
const OrderByClause = expression_pkg.OrderByClause;
const Order = expression_pkg.Order;

pub const Row = std.ArrayList(i32);

// The struct owns the slices it contains
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
    var tmpResult: Table = .empty;
    try tmpResult.columns.appendSlice(alloc, table.columns.items);
    defer tmpResult.deinit(alloc);
    if (expr.from) |from| {
        // assert table does exist
        std.debug.assert(std.mem.eql(u8, from.name, table.name));

        for (table.rows.items) |*row| {
            if (expr.where) |where| {
                // TODO: si form pk == thing
                // fait la recherche binaire
                // si  a < pk < b
                // recherche pk = a recherche binaire < b
                if (evalCondExpr(&where.cond, row, table)) {
                    try tmpResult.rows.append(alloc, try row.clone(alloc));
                }
            } else {
                try tmpResult.rows.append(alloc, try row.clone(alloc));
            }
        }
    }

    if (expr.orderby) |*orderby| {
        std.debug.assert(expr.from != null);
        try sortTable(alloc, &tmpResult, orderby, table);
    }

    for (tmpResult.rows.items) |*row| {
        try getRow(alloc, result, &expr.select, row, &tmpResult);
    }
}

pub fn sortTable(
    allocator: Allocator,
    result: *Table,
    orderby: *const OrderByClause,
    table: *const Table,
) !void {
    // for now, we just sort by the first element
    // std.debug.assert(orderby.columns.items.len == 1);
    // const col = orderby.columns.items[0];
    // const idx = findIdx(col.id, table.columns) orelse {
    //     panic("orderby col not found: {s} {}\n", .{ col.id, col.order });
    // };
    var ids: std.ArrayList(struct {usize, Order}) = .empty;
    defer ids.deinit(allocator);

    for (orderby.columns.items) |col| {
        const id = findIdx(col.id, table.columns) orelse {
            panic("orderby col not found: {s} {}\n", .{ col.id, col.order });
        };
        try ids.append(allocator, .{id, col.order});
    }

    const ctx = .{ ids };
    const rowCmp = struct {
        fn func(context: @TypeOf(ctx), r1: Row, r2: Row) bool {
            const ids_ctx = context[0];
            for (ids_ctx.items) |col| {
                if (r1.items[col[0]] != r2.items[col[0]]) {
                    if (col[1] == .Asc) {
                        return r1.items[col[0]] < r2.items[col[0]];
                    } else if (col[1] == .Desc) {
                            return r1.items[col[0]] > r2.items[col[0]];
                    } else unreachable;
                }
            }

            return false;
            // default return if all columns are equals
            // return if (ids_ctx.getLast().@"1" == .Asc) 
            //     r1.items[ids_ctx.getLast().@"0"] < r2.items[ids_ctx.getLast().@"0"]
            // else 
            //     r1.items[ids_ctx.getLast().@"0"] > r2.items[ids_ctx.getLast().@"0"];
        }
    }.func;

    std.mem.sort(Row, result.rows.items, ctx, rowCmp);
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
