const std = @import("std");

const Allocator = std.mem.Allocator;

const eql = std.ascii.eqlIgnoreCase;

const Cursor = struct {
    pub const empty: Cursor = .{
        .pos = 0,
        .bol = 0,
        .row = 0,
    };

    pos: usize,
    bol: usize,
    row: usize,
};

pub const Lexer = struct {
    const Self = @This();

    content: []const u8,
    count: usize,
    filepath: []const u8,
    alloc: Allocator,

    name: std.ArrayList(u8),
    token: enum {
        TokenSelect,
        TokenId,
        TokenFrom,
        TokenWhere,
        TokenComma,
        TokenEnd,
        TokenNone,
    },
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
        if (l.cursor.pos >= l.count) return null;
        const x = l.content[l.cursor.pos];
        l.cursor.pos += 1;
        if (x == '\n') {
            l.cursor.row += 1;
            l.cursor.bol = l.cursor.pos;
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

    pub fn next(l: *Self) !bool {
        l.trim_left();

        const x_opt = l.next_char();
        if (x_opt == 0 or x_opt == null) {
            l.token = .TokenEnd;
            return true;
        }
        var x = x_opt.?;

        switch (x) {
            ',' => {
                l.token = .TokenComma;
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
            } else {
                l.token = .TokenId;
                return true;
            }
        }
        return false;
    }
};
