const std = @import("std");

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

    name: std.ArrayList(u8),
    token: enum {
        SelectToken,
        Id,
        FromToken,
        WhereToken,
        CommaToken,
        TokenEnd,
        TokenNone,
    },
    cursor: Cursor,

    pub fn init(
        content: []const u8,
        count: usize,
        filepath: []const u8,
    ) Lexer {
        return .{
            .content = content,
            .count = count,
            .filepath = filepath,
            .name = .empty,
            .cursor = .empty,
            .token = .TokenNone,
        };
    }

    pub fn curr_char(l: Self) u8 {
        if (l.cursor.pos >= l.count) return 0;
        return l.content[l.cur.pos];
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
};
