// SPDX-License-Identifier: Apache-2.0
//
// C++, which adds to C rather than restating it - the arrangement TypeScript
// has with JavaScript, and for the same reason: the two share a scanner's
// whole vocabulary except for what one of them adds.
//
// `class` and `namespace` open spans; `struct` still does not. In C the
// argument against it was `struct stat st;`, which is ordinary code and would
// take the enclosing function's name from every line under it. C++ writes
// `Foo f;` instead, so the elaborated form is rare enough that `class Foo {`
// is safe - and `struct` is left out anyway, because C++ that calls POSIX
// still writes the C line, and a struct's methods are named by their own
// shape regardless.
//
// Two things are not modelled, both bounded. Raw string literals - `R"(...)"`
// - lex as an identifier and an ordinary string, so a raw literal containing a
// quote paints to the end of the line; the `hashed` machinery Rust and Swift
// use counts '#' and this counts an arbitrary delimiter, which is a different
// shape. And `<...>` is angle brackets to this scanner, never a template
// argument list, so `vector<int>` is three tokens - which is what it looks
// like anyway.
//
// `.h` stays with C. It is ambiguous and always will be, and the wrong guess
// is cheaper that way: a C++ header read as C loses `class` and `template`,
// while a C header read as C++ miscolours `new` and `delete`, which are
// perfectly ordinary C identifiers.

const langdef = @import("../langdef.zig");
const c = @import("c.zig");

/// C's, plus what C++ adds. Nothing is repeated: `constexpr`, `nullptr`,
/// `static_assert`, `thread_local`, `alignas` and `alignof` are C23 keywords
/// and are already in the list this extends.
pub const keywords = c.keywords ++ [_][]const u8{
    "and",              "and_eq",   "asm",          "bitand",    "bitor",
    "catch",            "class",    "co_await",     "co_return", "co_yield",
    "compl",            "concept",  "const_cast",   "consteval", "constinit",
    "decltype",         "delete",   "dynamic_cast", "explicit",  "export",
    "final",            "friend",   "mutable",      "namespace", "new",
    "noexcept",         "not",      "not_eq",       "operator",  "or",
    "or_eq",            "override", "private",      "protected", "public",
    "reinterpret_cast", "requires", "static_cast",  "template",  "this",
    "throw",            "try",      "typeid",       "typename",  "using",
    "virtual",          "xor",      "xor_eq",
};

/// C's, plus the standard library a reader recognises on sight.
pub const types = c.types ++ [_][]const u8{
    "std",          "string",        "string_view",   "vector",    "array",
    "deque",        "list",          "map",           "multimap",  "set",
    "multiset",     "unordered_map", "unordered_set", "pair",      "tuple",
    "optional",     "variant",       "any",           "span",      "bitset",
    "unique_ptr",   "shared_ptr",    "weak_ptr",      "function",  "thread",
    "mutex",        "atomic",        "future",        "ostream",   "istream",
    "stringstream", "exception",     "runtime_error", "nullptr_t", "wstring",
};

pub const def = langdef.define(.{
    .name = "cpp",
    .extensions = &.{ "cpp", "cc", "cxx", "hpp", "hh", "hxx", "ipp", "tpp" },
    .line_comment = &.{"//"},
    .block_comment = .{ .open = "/*", .close = "*/" },
    .strings = &.{
        .{ .open = "\"", .close = "\"" },
        .{ .open = "'", .close = "'", .max_bytes = 12 },
    },
    .keywords = &keywords,
    .types = &types,
    // For the reason Java's and Python's `class` is in theirs: a method wins
    // as the innermost span, and a line between two methods still reports the
    // type it sits in rather than nothing.
    .fn_decl = &.{ "class", "namespace" },
    // Google Test and its relatives, then Catch2 and doctest. The overlaps -
    // `TYPED_TEST(` contains `TEST(` - cost nothing, because a declaration is
    // counted once per line however many patterns match it.
    .test_decl = &.{
        "TEST(",       "TEST_F(",    "TEST_P(",
        "TYPED_TEST(", "TEST_CASE(", "SCENARIO(",
    },
    // Assertions *are* counted per occurrence, so these must not overlap:
    // `ASSERT` covers `ASSERT_EQ` and `ASSERT_TRUE` without `ASSERT_` counting
    // them again, and lower-case `assert` is the C one underneath.
    .assert_names = &.{ "EXPECT_", "ASSERT", "REQUIRE", "assert" },
    .skip_names = &.{ "GTEST_SKIP(", "DISABLED_", "SKIP(" },
    .fn_decl_paren = true,
    .fn_block_own_line = true,
    .ident_extra = "#",
});
