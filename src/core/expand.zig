// SPDX-License-Identifier: Apache-2.0
//
// Growing a hunk's context out of the buffers.
//
// Git emits three lines either side of a change and forgets the rest. The
// buffers hold the whole file, which is the reason `core/source.zig` exists,
// so the lines around a hunk are already in memory: showing them is an
// insertion into `DiffLines`, not another subprocess and not a re-diff.
//
// Growing rather than re-rendering is what keeps this off the keystroke
// budget. One press adds a few lines to one hunk, so the work is a single pass
// over that file's lines; nothing re-lexes and no id is reassigned. The change
// ids survive because `hashHunk` hashes added and removed lines only, and
// context is exactly what it ignores.
//
// The clamps are what stop two hunks from being drawn over the same lines. A
// hunk never grows past the file, and never past the hunk next door - which
// may itself have grown towards this one, so the two ranges meet and stop.
//
// A hunk with no lines on one side sits *between* two lines of that file
// rather than on any of them: `@@ -4,3 +3,0 @@` deletes after new line 3. That
// is what `before` and `after` are for, and why neither is `start - 1` and
// `start + count`.

const std = @import("std");
const Allocator = std.mem.Allocator;
const diff = @import("diff.zig");
const hunk = @import("hunk.zig");
const Hunk = hunk.Hunk;
const Buffer = @import("../text/buffer.zig").Buffer;

pub const Dir = enum { up, down };

/// Last new-file line before the hunk. Zero when it starts at the file's head.
fn newBefore(h: Hunk) u32 {
    return if (h.new_count == 0) h.new_start else h.new_start -| 1;
}

/// First new-file line after the hunk.
fn newAfter(h: Hunk) u32 {
    return if (h.new_count == 0) h.new_start + 1 else h.new_start + h.new_count;
}

fn oldBefore(h: Hunk) u32 {
    return if (h.old_count == 0) h.old_start else h.old_start -| 1;
}

fn oldAfter(h: Hunk) u32 {
    return if (h.old_count == 0) h.old_start + 1 else h.old_start + h.old_count;
}

/// How many lines hunk `hi` can still grow in `dir`. Zero means the reader has
/// reached the top of the file, the bottom of it, or the hunk next door.
pub fn room(f: *const diff.FileDiff, work: Buffer, hi: u32, dir: Dir) u32 {
    if (hi >= f.hunks.len) return 0;
    const h = f.hunks[hi];
    return switch (dir) {
        .up => {
            const floor: u32 = if (hi == 0) 1 else newAfter(f.hunks[hi - 1]);
            return (newBefore(h) + 1) -| floor;
        },
        .down => {
            const ceil: u32 = if (hi + 1 < f.hunks.len)
                newBefore(f.hunks[hi + 1])
            else
                work.lineCount();
            return (ceil + 1) -| newAfter(h);
        },
    };
}

/// Adds up to `want` context lines to one side of hunk `hi`, taking their text
/// from the working-tree buffer. Returns how many were added.
///
/// The buffer is the source of truth, so the text is the buffer's own slice -
/// the same one `source.attach` hands every other line, with the same lifetime.
///
/// `gpa` is the diff arena: the old line arrays are abandoned rather than
/// freed, which is what an arena is for and what every other builder here
/// does.
pub fn grow(
    gpa: Allocator,
    f: *diff.FileDiff,
    work: Buffer,
    hi: u32,
    dir: Dir,
    want: u32,
) Allocator.Error!u32 {
    if (want == 0 or f.summarised or hi >= f.hunks.len) return 0;
    const add = @min(want, room(f, work, hi, dir));
    if (add == 0) return 0;

    const h = &f.hunks[hi];
    // Where the block lands: the row in `lines`, and its first line in each
    // file. Old-file numbering runs a fixed distance from new-file numbering
    // outside the change, and the two ends of a hunk keep different distances.
    const at: u32 = switch (dir) {
        .up => h.lo,
        .down => h.hi,
    };
    const first_new: u32 = switch (dir) {
        .up => newBefore(h.*) + 1 - add,
        .down => newAfter(h.*),
    };
    const first_old: u32 = switch (dir) {
        .up => oldBefore(h.*) + 1 - add,
        .down => oldAfter(h.*),
    };

    const old_len: u32 = @intCast(f.lines.len());
    var out: hunk.DiffLines = .{
        .kind = try gpa.alloc(hunk.LineKind, old_len + add),
        .old_no = try gpa.alloc(u32, old_len + add),
        .new_no = try gpa.alloc(u32, old_len + add),
        .text = try gpa.alloc([]const u8, old_len + add),
    };

    copyLines(&out, 0, f.lines, 0, at);
    for (0..add) |k| {
        const i = at + k;
        out.kind[i] = .context;
        out.new_no[i] = first_new + @as(u32, @intCast(k));
        out.old_no[i] = first_old + @as(u32, @intCast(k));
        out.text[i] = work.line(out.new_no[i] - 1) orelse "";
    }
    copyLines(&out, at + add, f.lines, at, old_len);
    f.lines = out;

    // The block is inside the hunk either way, so `lo` does not move and `hi`
    // grows by what was added. Every later hunk sits that far down the list.
    h.new_start = switch (dir) {
        .up => first_new,
        .down => if (h.new_count == 0) first_new else h.new_start,
    };
    h.old_start = switch (dir) {
        .up => first_old,
        .down => if (h.old_count == 0) first_old else h.old_start,
    };
    h.new_count += add;
    h.old_count += add;
    h.hi += add;
    for (f.hunks[hi + 1 ..]) |*later| {
        later.lo += add;
        later.hi += add;
    }
    return add;
}

fn copyLines(out: *hunk.DiffLines, at: u32, from: hunk.DiffLines, lo: u32, hi: u32) void {
    const n = hi - lo;
    if (n == 0) return;
    @memcpy(out.kind[at .. at + n], from.kind[lo..hi]);
    @memcpy(out.old_no[at .. at + n], from.old_no[lo..hi]);
    @memcpy(out.new_no[at .. at + n], from.new_no[lo..hi]);
    @memcpy(out.text[at .. at + n], from.text[lo..hi]);
}

const testing = std.testing;

/// The eight-line file two of the fixtures below diff, so the buffer and the
/// patch cannot drift apart.
const eight = "one\ntwo\nthree\nfour\nFIVE\nsix\nseven\neight\n";

fn parseOne(gpa: Allocator, text: []const u8) !diff.Diff {
    return diff.parse(gpa, text);
}

test "growing up and down takes its text and numbering from the buffer" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var d = try parseOne(a,
        \\diff --git a/f.txt b/f.txt
        \\--- a/f.txt
        \\+++ b/f.txt
        \\@@ -5 +5 @@
        \\-five
        \\+FIVE
        \\
    );
    const work: Buffer = try .initOwned(a, try a.dupe(u8, eight));
    const f = &d.files[0];

    try testing.expectEqual(@as(u32, 2), try grow(a, f, work, 0, .up, 2));
    try testing.expectEqual(@as(u32, 3), f.hunks[0].new_start);
    try testing.expectEqual(@as(u32, 3), f.hunks[0].new_count);
    try testing.expectEqualStrings("three", f.lines.text[0]);
    try testing.expectEqualStrings("four", f.lines.text[1]);
    try testing.expectEqual(@as(u32, 3), f.lines.new_no[0]);
    // Context lines carry both numberings, and here the two files agree.
    try testing.expectEqual(@as(u32, 3), f.lines.old_no[0]);
    try testing.expectEqual(hunk.LineKind.context, f.lines.kind[0]);

    try testing.expectEqual(@as(u32, 3), try grow(a, f, work, 0, .down, 3));
    try testing.expectEqual(@as(u32, 6), f.hunks[0].new_count);
    // Two lines of change plus five of context, the deleted line among them.
    try testing.expectEqual(@as(usize, 7), f.lines.len());
    try testing.expectEqualStrings("six", f.lines.text[4]);
    try testing.expectEqualStrings("eight", f.lines.text[6]);
    // The hunk still covers every line of the file's list, in order.
    try testing.expectEqual(@as(u32, 0), f.hunks[0].lo);
    try testing.expectEqual(@as(u32, 7), f.hunks[0].hi);
}

test "a hunk never grows past the file it is in" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var d = try parseOne(a,
        \\diff --git a/f.txt b/f.txt
        \\--- a/f.txt
        \\+++ b/f.txt
        \\@@ -5 +5 @@
        \\-five
        \\+FIVE
        \\
    );
    const work: Buffer = try .initOwned(a, try a.dupe(u8, eight));
    const f = &d.files[0];

    // Four above and three below is the whole file; asking for a hundred
    // gets exactly that and then nothing.
    try testing.expectEqual(@as(u32, 4), try grow(a, f, work, 0, .up, 100));
    try testing.expectEqual(@as(u32, 3), try grow(a, f, work, 0, .down, 100));
    try testing.expectEqual(@as(usize, 9), f.lines.len());
    try testing.expectEqual(@as(u32, 0), room(f, work, 0, .up));
    try testing.expectEqual(@as(u32, 0), room(f, work, 0, .down));
    try testing.expectEqual(@as(u32, 0), try grow(a, f, work, 0, .up, 1));
}

test "two hunks growing towards each other meet and stop" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    // Twenty lines, changed at 3 and at 17.
    var text: std.ArrayList(u8) = .empty;
    for (1..21) |i| try text.print(a, "line{d}\n", .{i});
    const body = try text.toOwnedSlice(a);
    const work: Buffer = try .initOwned(a, body);

    var d = try parseOne(a,
        \\diff --git a/f.txt b/f.txt
        \\--- a/f.txt
        \\+++ b/f.txt
        \\@@ -3 +3 @@
        \\-old3
        \\+line3
        \\@@ -17 +17 @@
        \\-old17
        \\+line17
        \\
    );
    const f = &d.files[0];

    // The first hunk takes everything down to the second one and no further.
    try testing.expectEqual(@as(u32, 13), try grow(a, f, work, 0, .down, 100));
    try testing.expectEqual(@as(u32, 16), f.hunks[0].new_start + f.hunks[0].new_count - 1);
    // Which leaves the second nothing above it to take.
    try testing.expectEqual(@as(u32, 0), room(f, work, 1, .up));
    try testing.expectEqual(@as(u32, 0), try grow(a, f, work, 1, .up, 5));

    // The second hunk's range into the line list moved by what the first grew.
    try testing.expectEqual(f.hunks[0].hi, f.hunks[1].lo);
    try testing.expectEqual(@as(u32, 3), try grow(a, f, work, 1, .down, 3));
    try testing.expectEqual(@as(u32, 20), f.hunks[1].new_start + f.hunks[1].new_count - 1);
}

test "a pure deletion grows on the lines either side of where it was" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    // `gone` was line 4 of the old file; the new file has seven lines.
    var d = try parseOne(a,
        \\diff --git a/f.txt b/f.txt
        \\--- a/f.txt
        \\+++ b/f.txt
        \\@@ -4 +3,0 @@
        \\-gone
        \\
    );
    const work: Buffer = try .initOwned(a, try a.dupe(u8, "one\ntwo\nthree\nfour\nfive\nsix\nseven\n"));
    const f = &d.files[0];
    try testing.expectEqual(@as(u32, 0), f.hunks[0].new_count);

    // Up takes line 3, the last one before the deletion.
    try testing.expectEqual(@as(u32, 1), try grow(a, f, work, 0, .up, 1));
    try testing.expectEqualStrings("three", f.lines.text[0]);
    try testing.expectEqual(@as(u32, 3), f.lines.new_no[0]);
    try testing.expectEqual(@as(u32, 3), f.lines.old_no[0]);
    try testing.expectEqual(@as(u32, 3), f.hunks[0].new_start);
    try testing.expectEqual(@as(u32, 1), f.hunks[0].new_count);

    // Down takes line 4, the first one after it - which was line 5 of the old
    // file, the deleted line having been 4.
    try testing.expectEqual(@as(u32, 1), try grow(a, f, work, 0, .down, 1));
    try testing.expectEqualStrings("four", f.lines.text[2]);
    try testing.expectEqual(@as(u32, 4), f.lines.new_no[2]);
    try testing.expectEqual(@as(u32, 5), f.lines.old_no[2]);
}

test "growing a summarised file does nothing" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var d = try parseOne(a,
        \\diff --git a/f.txt b/f.txt
        \\--- a/f.txt
        \\+++ b/f.txt
        \\@@ -5 +5 @@
        \\-five
        \\+FIVE
        \\
    );
    const work: Buffer = try .initOwned(a, try a.dupe(u8, eight));
    const f = &d.files[0];
    f.summarised = true;
    try testing.expectEqual(@as(u32, 0), try grow(a, f, work, 0, .up, 3));
}

test "a re-parse puts a grown file back to what git said" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const raw =
        \\diff --git a/f.txt b/f.txt
        \\--- a/f.txt
        \\+++ b/f.txt
        \\@@ -5 +5 @@
        \\-five
        \\+FIVE
        \\
    ;
    var d = try parseOne(a, raw);
    const work: Buffer = try .initOwned(a, try a.dupe(u8, eight));
    const f = &d.files[0];
    const was = f.lines.len();

    _ = try grow(a, f, work, 0, .up, 3);
    try testing.expect(f.lines.len() > was);

    // What folding context back is built on: git's own answer, out of the
    // output already in hand, with no second subprocess.
    try testing.expect(try diff.reparse(a, f, raw));
    try testing.expectEqual(was, f.lines.len());
    try testing.expectEqual(@as(u32, 5), f.hunks[0].new_start);
    try testing.expectEqual(@as(u32, 1), f.hunks[0].new_count);
    try testing.expectEqual(@as(u32, 0), f.hunks[0].lo);
    try testing.expectEqual(@as(u32, 2), f.hunks[0].hi);
}
