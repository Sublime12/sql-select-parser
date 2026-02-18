const std = @import("std");
const expression_pkg = @import("expression.zig");

const Expr = expression_pkg.Expr;
const Column = expression_pkg.Column;
const SelectClause = expression_pkg.SelectClause;
const FromClause = expression_pkg.FromClause;
const WhereClause = expression_pkg.WhereClause;
const BinaryLogicClause = expression_pkg.BinaryLogicClause;
const CondExpr = expression_pkg.CondExpr;

const Allocator = std.mem.Allocator;

const eql = std.ascii.eqlIgnoreCase;

const Cursor = struct {
    pub const empty: Cursor = .{
        .pos = 0,
        .bol = 0,
        .row = 0,
        .col = 0,
    };

    pos: usize,
    bol: usize,
    col: usize,
    row: usize,
};

const TokenKind = enum {
    TokenSelect,
    TokenId,
    TokenFrom,
    TokenWhere,
    TokenComma,
    TokenEnd,
    TokenOParent,
    TokenCParent,
    TokenEq,
    TokenLt,
    TokenGt,
    TokenOr,
    TokenAnd,
    // TokenLe,
    // TokenGe,
    // TokenValue,
    TokenNone,
};

pub const Lexer = struct {
    const Self = @This();

    content: []const u8,
    count: usize,
    filepath: []const u8,
    alloc: Allocator,

    name: std.ArrayList(u8),
    token: TokenKind,
    cursor: Cursor,

    pub fn init(
        allocator: Allocator,
        content: []const u8,
        count: usize,
        filepath: []const u8,
    ) Lexer {
        return .{
            .alloc = allocator,
            .content = content,
            .count = count,
            .filepath = filepath,
            .name = .empty,
            .cursor = .empty,
            .token = .TokenNone,
        };
    }

    pub fn token_display(l: Self) void {
        switch (l.token) {
            .TokenSelect => {
                std.debug.print("{}\n", .{l.token});
            },
            .TokenId => {
                std.debug.print("{} |{s}|,\n", .{ l.token, l.name.items });
            },
            else => {
                std.debug.print("{}\n", .{l.token});
            },
        }
    }

    pub fn current_char(l: Self) u8 {
        if (l.cursor.pos >= l.count) return 0;
        return l.content[l.cursor.pos];
    }

    pub fn next_char(l: *Self) ?u8 {
        if (l.cursor.pos > l.count) return null;
        const x = if (l.cursor.pos == l.count)
            '#'
        else
            l.content[l.cursor.pos];

        l.cursor.pos += 1;
        l.cursor.col += 1;
        if (x == '\n') {
            l.cursor.row += 1;
            l.cursor.bol = l.cursor.pos;
            l.cursor.col = 0;
        }
        return x;
    }

    pub fn trim_left(l: *Self) void {
        while (std.ascii.isWhitespace(l.current_char())) {
            _ = l.next_char();
        }
    }

    fn isSymbol(c: u8) bool {
        return std.ascii.isAlphanumeric(c) or c == '_';
    }

    pub fn next(l: *Self) error{OutOfMemory}!bool {
        // std.debug.print("token: {}\n", .{l.token});
        l.trim_left();

        const x_opt = l.next_char();
        if (x_opt == null) {
            l.token = .TokenEnd;
            return true;
        }
        var x = x_opt.?;

        switch (x) {
            ',' => {
                l.name.clearRetainingCapacity();
                try l.name.append(l.alloc, x);
                l.token = .TokenComma;
                return true;
            },
            '(' => {
                l.name.clearRetainingCapacity();
                try l.name.append(l.alloc, x);
                l.token = .TokenOParent;
                return true;
            },
            ')' => {
                l.name.clearRetainingCapacity();
                try l.name.append(l.alloc, x);
                l.token = .TokenCParent;
                return true;
            },
            '=' => {
                l.name.clearRetainingCapacity();
                try l.name.append(l.alloc, x);
                l.token = .TokenEq;
                return true;
            },
            '>' => {
                l.name.clearRetainingCapacity();
                try l.name.append(l.alloc, x);
                l.token = .TokenGt;
                return true;
            },
            '<' => {
                l.name.clearRetainingCapacity();
                try l.name.append(l.alloc, x);
                l.token = .TokenLt;
                return true;
            },
            else => {},
        }

        if (isSymbol(x)) {
            l.name.clearRetainingCapacity();
            try l.name.append(l.alloc, x);

            while (isSymbol(l.current_char())) {
                if (l.next_char()) |c| {
                    x = c;
                }
                try l.name.append(l.alloc, x);
            }

            if (eql("select", l.name.items)) {
                l.token = .TokenSelect;
                return true;
            } else if (eql("from", l.name.items)) {
                l.token = .TokenFrom;
                return true;
            } else if (eql("where", l.name.items)) {
                l.token = .TokenWhere;
                return true;
            } else if (eql("and", l.name.items)) {
                l.token = .TokenAnd;
                return true;
            } else if (eql("or", l.name.items)) {
                l.token = .TokenOr;
                return true;
            } else {
                l.token = .TokenId;
                return true;
            }
        }
        return false;
    }

    pub fn expect(l: Self, token: TokenKind) void {
        if (l.token != token) {
            std.debug.print("{s}:{},{}\n", .{
                l.filepath,
                l.cursor.row,
                l.cursor.col,
            });
            std.debug.print("expected {}, found this: {} - {s}\n", .{
                token,
                l.token,
                l.name.items,
            });
        }
        std.debug.assert(l.token == token);
    }
};

const ParseErr = error{
    UnexpectedToken,
};

pub const Parser = struct {
    const Self = @This();

    lexer: *Lexer,
    allocator: Allocator,

    pub fn init(allocator: Allocator, l: *Lexer) Parser {
        return .{
            .allocator = allocator,
            .lexer = l,
        };
    }

    pub fn parse(self: *Self) !Expr {
        self.lexer.cursor = .empty;
        _ = try self.lexer.next();
        return parseExpr(self.allocator, self.lexer);
    }

    fn parseExpr(allocator: Allocator, l: *Lexer) error{OutOfMemory}!Expr {
        var expr = Expr.initEmpty();

        // _ = try l.next();
        if (l.token == .TokenSelect) {
            expr.select = try parseSelect(allocator, l);
        }

        if (l.token == .TokenFrom) {
            expr.from = try parseFrom(allocator, l);
        }
        if (l.token == .TokenWhere) {
            expr.where = try parseWhere(allocator, l);
        }
        return expr;
    }

    fn parseSelect(alloc: Allocator, l: *Lexer) !SelectClause {
        // going simple just identifiers
        // at least one identifier
        l.expect(.TokenSelect);
        _ = try l.next();
        // l.expect(.TokenId);

        var columns = std.ArrayList(Column).empty;
        while (true) {
            // std.debug.print("xx{} {s}\n", .{ l.token, l.name.items });
            if (l.token == .TokenId) {
                try columns.append(alloc, .{ .id = try alloc.dupe(u8, l.name.items) });
                _ = try l.next();
                l.expect(.TokenComma);
                _ = try l.next();
            } else if (l.token == .TokenOParent) {
                // pass oparen
                l.expect(.TokenOParent);
                _ = try l.next();
                const expr = try parseExpr(alloc, l);
                try columns.append(alloc, .{ .expr = expr });
                l.expect(.TokenCParent);
                _ = try l.next();
                // consume the comma after
                l.expect(.TokenComma);
                _ = try l.next();
            } else {
                break;
            }

            // std.debug.print("token2 : {}\n", .{ l.token });
        }

        return SelectClause.init(columns);
    }

    fn parseFrom(alloc: Allocator, l: *Lexer) !FromClause {
        l.expect(.TokenFrom);
        _ = try l.next();
        l.expect(.TokenId);

        const from = FromClause.init(try alloc.dupe(u8, l.name.items));
        _ = try l.next();
        return from;
    }

    // unfinished
    fn parseWhere(alloc: Allocator, l: *Lexer) !WhereClause {
        l.expect(.TokenWhere);
        _ = try l.next();
        // l.expect(.TokenId);
        // const where = WhereClause.init(try alloc.dupe(u8, l.name.items));
        const cond = try parseCond(alloc, l);
        const where = WhereClause.init(cond);
        return where;
    }

    fn parseCond(alloc: Allocator, l: *Lexer) !CondExpr {
        // const query1 = "select col2, col1, from table1 where col3 = 2";
        // (expr1) and (expr2)
        // (expr1) or (expr2)
        // ((expr1) or (expr2)) and (expr3)
        if (l.token == .TokenOParent) {
            _ = try l.next();
            const expr = try parseCond(alloc, l);
            l.expect(.TokenCParent);
            _ = try l.next();
            // checks if there is an or/and expr before returning
            if (l.token == .TokenOr) {
                _ = try l.next();
                l.expect(.TokenOParent);
                _ = try l.next();
                const orExpr = try parseCond(alloc, l);
                l.expect(.TokenCParent);
                _ = try l.next();
                const orClause = try alloc.create(BinaryLogicClause);
                orClause.* = .{ .cond1 = expr, .cond2 = orExpr };
                return .{ .or_ = orClause };
            } else if (l.token == .TokenAnd) {
                _ = try l.next();
                l.expect(.TokenOParent);
                _ = try l.next();
                const andExpr = try parseCond(alloc, l);
                l.expect(.TokenCParent);
                _ = try l.next();
                const andClause = try alloc.create(BinaryLogicClause);
                andClause.* = .{ .cond1 = expr, .cond2 = andExpr };
                return .{ .and_ = andClause };
            }
            return expr;
        }

        if (l.token == .TokenId) {
            const name = try alloc.dupe(u8, l.name.items);
            _ = try l.next();

            switch (l.token) {
                .TokenEq => {
                    _ = try l.next();
                    l.expect(.TokenId);
                    const value = std.fmt.parseInt(i32, l.name.items, 10) catch unreachable;
                    const eqlExpr: CondExpr = .{ .equal = .{ .id = name, .val = value } };
                    _ = try l.next();
                    return eqlExpr;
                },
                .TokenGt => {
                    _ = try l.next();
                    l.expect(.TokenId);
                    const value = std.fmt.parseInt(i32, l.name.items, 10) catch unreachable;
                    const gtExpr: CondExpr = .{ .gt = .{ .id = name, .val = value } };
                    _ = try l.next();
                    return gtExpr;
                },
                .TokenLt => {
                    _ = try l.next();
                    l.expect(.TokenId);
                    const value = std.fmt.parseInt(i32, l.name.items, 10) catch unreachable;
                    const ltExpr: CondExpr = .{ .lt = .{ .id = name, .val = value } };
                    _ = try l.next();
                    return ltExpr;
                },
                else => unreachable,
            }
        }
        unreachable;
    }
};
