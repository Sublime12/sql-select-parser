const std = @import("std");

pub fn main() !void {
    const query =
        \\\ select c1, c2
        \\\ from  table
        \\\ where condition
    ;
    _ = query;

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

    std.debug.print("expr: {f}", .{expr});
}

const Expr = struct {
    columns: SelectClause,
    table: FromClause,
    where: ?FilterClause,

    pub fn init(
        columns: SelectClause,
        table: FromClause,
        where: ?FilterClause,
    ) Expr {
        return .{
            .columns = columns,
            .table = table,
            .where = where,
        };
    }

    pub fn format(
        self: Expr,
        writer: *std.io.Writer,
    ) !void {
        try writer.print("SELECT {f} FROM {f}", .{ self.columns, self.table });

        if (self.where) |w| {
            try writer.print(" WHERE {any}", .{w});
        }
        try writer.print("\n", .{});
    }
};

const SelectClause = struct {
    const Columns = std.ArrayList([]const u8);
    columns: Columns,

    pub fn init(columns: Columns) SelectClause {
        return .{
            .columns = columns,
        };
    }

    pub fn format(
        self: SelectClause,
        writer: *std.io.Writer,
    ) !void {
        for (self.columns.items) |col| {
            try writer.print("{s}, ", .{col});
        }
    }
};

const FromClause = struct {
    name: []const u8,
    pub fn init(name: []const u8) FromClause {
        return .{ .name = name };
    }

    pub fn format(
        self: FromClause,
        writer: *std.io.Writer,
    ) !void {
        try writer.print("{s}", .{self.name});
    }
};

const FilterClause = union(enum) {
    a: i32,
};
