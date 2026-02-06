const std = @import("std");

pub const Expr = struct {
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
    }
};

pub const SelectClause = struct {
    pub const Columns = std.ArrayList([]const u8);
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

pub const FromClause = struct {
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

pub const FilterClause = union(enum) {
    a: i32,
};
