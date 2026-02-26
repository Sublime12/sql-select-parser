const std = @import("std");
const Allocator = std.mem.Allocator;
const panic = std.debug.panic;

pub const Expr = struct {
    const Self = @This();
    select: SelectClause,
    from: ?FromClause,
    where: ?WhereClause,
    orderby: ?OrderByClause,

    pub fn init(
        columns: SelectClause,
        table: FromClause,
        where: ?WhereClause,
        orderby: ?OrderByClause,
    ) Expr {
        return .{
            .select = columns,
            .from = table,
            .where = where,
            .orderby = orderby,
        };
    }

    pub fn initEmpty() Expr {
        return std.mem.zeroInit(Expr, .{});
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        defer self.select.deinit(allocator);
        if (self.from) |*from| {
            from.deinit(allocator);
        }
        if (self.where) |*where| {
            where.deinit(allocator);
        }
        if (self.orderby) |*orderby| {
            orderby.deinit(allocator);
        }
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
        defer self.columns.deinit(allocator);
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
    const Self = @This();

    name: []const u8,
    pub fn init(name: []const u8) FromClause {
        return .{ .name = name };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.free(self.name);
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
    lt,
    and_,
    or_,
    // not,
};

pub const CondExpr = union(CondTag) {
    const Self = @This();
    bool_: Bool,
    equal: CompareClause,
    gt: CompareClause,
    lt: CompareClause,
    and_: *BinaryLogicClause,
    or_: *BinaryLogicClause,

    pub fn deinit(self: *Self, allocator: Allocator) void {
        switch (self.*) {
            .and_, .or_ => |binaryClause| {
                binaryClause.deinit(allocator);
            },
            // .or_ => |or_| {
            //     or_.deinit(allocator);
            // },
            .gt, .lt, .equal => |cmpClause| {
                allocator.free(cmpClause.id);
            },
            else => {},
        }
    }
    // not: *UnaryLogicClause,
};

const CompareClause = struct {
    id: []const u8,
    val: i32,
};

pub const BinaryLogicClause = struct {
    cond1: CondExpr,
    cond2: CondExpr,

    pub fn deinit(self: *BinaryLogicClause, allocator: Allocator) void {
        self.cond1.deinit(allocator);
        self.cond2.deinit(allocator);
        allocator.destroy(self);
    }
};

const NotClause = struct {
    cond: CondExpr,
};

pub const WhereClause = struct {
    cond: CondExpr,

    pub fn init(cond: CondExpr) WhereClause {
        return .{ .cond = cond };
    }

    pub fn deinit(self: *WhereClause, allocator: Allocator) void {
        var cond = &self.cond;
        cond.deinit(allocator);
    }

    pub fn format(
        self: WhereClause,
        writer: *std.io.Writer,
    ) !void {
        try writer.print("{any}", .{self.cond});
    }
};

pub const OrderByClause = struct {
    const Self = @This();
    pub const Columns = std.ArrayList(Column);
    columns: Columns,

    pub fn init(columns: Columns) Self {
        return .{
            .columns = columns,
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        for (self.columns.items) |column| {
            switch (column) {
                .id => |id| {
                    allocator.free(id);
                },
                else => {
                    panic("unreconized expr in order by clause\n", .{});
                },
            }
        }
        self.columns.deinit(allocator);
    }
};
