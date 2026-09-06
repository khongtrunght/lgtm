// SPDX-License-Identifier: Apache-2.0
//
// Lua. Three shapes the languages before it did not need.
//
// `--[[` opens a block comment and `--` opens a line comment, so the block
// opener begins with the line opener. The scanner tries block comments first
// for exactly this reason, which costs the others nothing: none of them has a
// line comment that could swallow a block opener.
//
// Long brackets carry a level, and only the bare `[[ ]]` form is modelled.
// `[==[ ]==]` exists so a literal can hold the delimiter of the form below it,
// which is rare enough to leave until a file asks for it; the same goes for
// `--[==[`. What such a literal costs is its own colour, not the rest of the
// file, because the scanner only ever opens a literal it recognises.
//
// `function M.foo()` and `function obj:method()` are how a module is written,
// and the name is the last segment rather than the first. That is
// `fn_qualified` - without it every method in a module names its span after
// the table, and every hunk header in the file reads `M`.
//
// Blocks are `.indent`. `{` is a table constructor here, so brace depth says
// nothing about where a function ends, and `end` sits at the declaration's own
// indentation - which closes the span one line early, putting the `end` line
// in the enclosing scope. Python makes the same trade at a dedent.

const langdef = @import("../langdef.zig");

pub const def = langdef.define(.{
    .name = "lua",
    // A rockspec is a Lua table assignment and reads as one.
    .extensions = &.{ "lua", "rockspec" },
    .line_comment = &.{"--"},
    .block_comment = .{ .open = "--[[", .close = "]]" },
    .strings = &.{
        // Long strings are raw: `\n` inside `[[ ]]` is two characters.
        .{ .open = "[[", .close = "]]", .escape = null, .multiline = true },
        .{ .open = "\"", .close = "\"" },
        .{ .open = "'", .close = "'" },
    },
    .keywords = &.{
        "and",   "break", "do",       "else",  "elseif", "end",
        "false", "for",   "function", "goto",  "if",     "in",
        "local", "nil",   "not",      "or",    "repeat", "return",
        "self",  "then",  "true",     "until", "while",
    },
    // Lua has no type names, so the slot holds what a reader recognises
    // instead: the standard library and the base functions. Java's `System`
    // and `Math` are in its list for the same reason.
    .types = &.{
        "coroutine",    "debug",   "io",             "math",         "os",
        "package",      "string",  "table",          "utf8",         "_G",
        "_VERSION",     "assert",  "collectgarbage", "dofile",       "error",
        "getmetatable", "ipairs",  "load",           "next",         "pairs",
        "pcall",        "print",   "rawequal",       "rawget",       "rawlen",
        "rawset",       "require", "select",         "setmetatable", "tonumber",
        "tostring",     "type",    "unpack",         "xpcall",
    },
    .fn_decl = &.{"function"},
    // busted and plenary write `it("...", function()`; luaunit collects any
    // global whose name starts with `test`. The opening quote is part of the
    // busted patterns for the reason it is part of JavaScript's: `it(` alone
    // matches `edit(`, `submit(` and `exit(`.
    .test_decl = &.{ "it(\"", "it('", "function test", "function Test" },
    // One entry covers `assert(`, busted's `assert.are.same` and luaunit's
    // `assertEquals` alike; listing them separately would count one call
    // several times.
    .assert_names = &.{"assert"},
    // busted's `pending(` is a test that announces it does nothing. luaunit
    // aborts one with `skip`, and both of its spellings are qualified, so the
    // paren is not needed to keep them off an import line.
    .skip_names = &.{ "pending(", "lu.skip(", "luaunit.skip(" },
    .fn_qualified = true,
    .blocks = .indent,
});
