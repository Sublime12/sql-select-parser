const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Expr = struct {
    const Self = @This();
    select: SelectClause,
    from: ?FromClause,
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
        try writer.print("(SELECT {f}", .{self.select});

        if (self.from) |f| {
            try writer.print(" FROM {f}", .{f});
        }

        if (self.where) |w| {
            try writer.print(" WHERE {f}", .{w});
        }
        try writer.print(")", .{});
    }
};

const ColumnTag = enum {
    id,
    expr,
};

pub const Column = union(ColumnTag) {
    id: []const u8,
    expr: Expr,
};

pub const SelectClause = struct {
    const Self = @This();
    pub const Columns = std.ArrayList(Column);
    columns: Columns,

    pub fn init(columns: Columns) SelectClause {
        return .{
            .columns = columns,
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        for (self.columns.items) |col| {
            switch (col) {
                .id => |c| {
                    allocator.free(c);
                },
                else => {},
            }
            // allocator.free(col);
        }
    }

    pub fn format(
        self: SelectClause,
        writer: *std.io.Writer,
    ) !void {
        for (self.columns.items) |col| {
            switch (col) {
                .id => try writer.print("{s},", .{col.id}),
                .expr => try writer.print("{f}, ", .{col.expr}),
            }
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

const Bool = enum {
    true,
    false,
};

const CondTag = enum {
    bool_,
    equal,
    gt,
    // and_,
    // or_,
    // not,
};

pub const CondExpr = union(CondTag) {
    bool_: Bool,
    equal: CompareClause,
    gt: CompareClause,
    // and_: *AndClause,
    // or_: *OrClause,
    // not: *NotClause,
};

const CompareClause = struct {
    id: []const u8,
    val: i32,
};

const AndClause = struct {
    cond1: CondExpr,
    cond2: CondExpr,
};

const OrClause = struct {
    cond1: CondExpr,
    cond2: CondExpr,
};

const NotClause = struct {
    cond: CondExpr,
};

pub const WhereClause = struct {
    cond: CondExpr,

    pub fn init(cond: CondExpr) WhereClause {
        return .{ .cond = cond };
    }

    pub fn format(
        self: WhereClause,
        writer: *std.io.Writer,
    ) !void {
        try writer.print("{any}", .{self.cond});
    }
};
