const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Expr = struct {
    const Self = @This();
    select: SelectClause,
    from: FromClause,
    where: ?WhereClause,

    pub fn init(
        columns: SelectClause,
        table: FromClause,
        where: ?WhereClause,
    ) Expr {
        return .{
            .select = columns,
            .from = table,
            .where = where,
        };
    }

    pub fn initEmpty() Expr {
        return std.mem.zeroInit(Expr, .{});
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        defer self.select.deinit(allocator);
    }

    pub fn format(
        self: Expr,
        writer: *std.io.Writer,
    ) !void {
        try writer.print("SELECT {f} FROM {f}", .{ self.select, self.from });

        if (self.where) |w| {
            try writer.print(" WHERE {f}", .{w});
        }
    }
};

pub const SelectClause = struct {
    const Self = @This();
    pub const Columns = std.ArrayList([]const u8);
    columns: Columns,

    pub fn init(columns: Columns) SelectClause {
        return .{
            .columns = columns,
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        for (self.columns.items) |col| {
            allocator.free(col);
        }
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

pub const WhereClause = struct {
    name: []const u8,

    pub fn init(name: []const u8) WhereClause {
        return .{ .name = name };
    }

    pub fn format(
        self: WhereClause,
        writer: *std.io.Writer,
    ) !void {
        try writer.print("{s}", .{self.name});
    }
};
