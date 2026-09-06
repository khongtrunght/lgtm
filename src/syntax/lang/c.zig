// SPDX-License-Identifier: Apache-2.0
//
// C. Its functions are introduced by no keyword at all, which is the shape
// Java already asked for: `fn_decl_paren` reads an identifier applied to an
// argument list as a declaration, and a block confirms it. Two differences.
//
// The block may open on the next line. `int main(void)` followed by `{` in
// column one is half of all C ever written, and Java never needed it, so it is
// `fn_block_own_line` rather than the default. One line and no further, which
// keeps a call from reaching a block underneath it.
//
// `struct`, `union` and `enum` are deliberately *not* in `fn_decl`, though
// Java's `class` and `record` are. `struct stat st;` inside a function is
// ordinary C and would open a span named `stat` - and because a span opening
// closes its siblings at the same depth, it would take the enclosing
// function's name away from every line below it. Naming a hunk inside a large
// struct definition is worth less than that, so the shape does all the work
// and the keywords do none.
//
// Preprocessor directives lex as one word each: '#' is an identifier start, so
// `#include` is a token and can be a keyword. That is the Swift treatment of
// '@' rather than the Java treatment, and it earns its place here because a C
// diff is often nothing but directives, and because `#` never continues an
// identifier - only starts one - so `x#y` is still three tokens.

const langdef = @import("../langdef.zig");

/// Exported the way JavaScript's are, so a C++ definition can extend them
/// rather than restate them.
pub const keywords = [_][]const u8{
    "alignas",       "alignof",   "auto",         "break",     "case",
    "const",         "constexpr", "continue",     "default",   "do",
    "else",          "enum",      "extern",       "false",     "for",
    "goto",          "if",        "inline",       "nullptr",   "register",
    "restrict",      "return",    "sizeof",       "static",    "static_assert",
    "struct",        "switch",    "thread_local", "true",      "typedef",
    "typeof",        "union",     "volatile",     "while",     "_Alignas",
    "_Alignof",      "_Atomic",   "_Generic",     "_Noreturn", "_Static_assert",
    "_Thread_local",
    // The preprocessor. One word each, which is what '#' in `ident_extra` buys.
    "#include",  "#define",      "#undef",    "#if",
    "#ifdef",        "#ifndef",   "#elif",        "#elifdef",  "#elifndef",
    "#else",         "#endif",    "#pragma",      "#error",    "#warning",
    "#line",         "#embed",
};

/// The built-in types and the ones from the standard headers that a reader
/// recognises on sight. `signed` and `unsigned` are here rather than in the
/// keywords because they are half of a type name and never anything else.
pub const types = [_][]const u8{
    "bool",     "char",     "double",    "float",    "int",
    "long",     "short",    "signed",    "unsigned", "void",
    "size_t",   "ssize_t",  "ptrdiff_t", "intptr_t", "uintptr_t",
    "int8_t",   "int16_t",  "int32_t",   "int64_t",  "uint8_t",
    "uint16_t", "uint32_t", "uint64_t",  "intmax_t", "uintmax_t",
    "wchar_t",  "char8_t",  "char16_t",  "char32_t", "va_list",
    "FILE",     "NULL",     "time_t",    "clock_t",  "off_t",
    "pid_t",    "mode_t",   "errno_t",   "jmp_buf",  "sig_atomic_t",
};

pub const def = langdef.define(.{
    .name = "c",
    .extensions = &.{ "c", "h" },
    .line_comment = &.{"//"},
    .block_comment = .{ .open = "/*", .close = "*/" },
    .strings = &.{
        .{ .open = "\"", .close = "\"" },
        // A char literal, with the byte limit that keeps an apostrophe in
        // prose from painting the rest of the line.
        .{ .open = "'", .close = "'", .max_bytes = 12 },
    },
    .keywords = &keywords,
    .types = &types,
    // No dominant test framework, so this is what the common ones agree on
    // rather than a guess at one of them: Check declares `START_TEST(`, Unity
    // collects `void test_`, Zephyr has `ZTEST(`. Under-detecting is the right
    // way to be wrong here.
    .test_decl = &.{ "START_TEST(", "void test_", "TEST_CASE(", "ZTEST(" },
    // Twice, because the macro families disagree on case and a substring
    // match cannot see past it: `assert(` and cmocka's `assert_int_equal` are
    // lower, Unity's `TEST_ASSERT_EQUAL` and Check's `ck_assert` are not.
    //
    // A defensive `assert()` in production C is counted too, which Java's
    // note calls harmless and here is closer to useful: an agent quietly
    // dropping a precondition check is worth the same look.
    .assert_names = &.{ "assert", "ASSERT" },
    .skip_names = &.{ "TEST_IGNORE", "skip_if(", ".disabled = true" },
    .fn_decl_paren = true,
    .fn_block_own_line = true,
    // `#include` is one word; `#` starts an identifier and never continues one.
    .ident_extra = "#",
});
