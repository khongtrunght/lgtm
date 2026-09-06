// SPDX-License-Identifier: Apache-2.0
//
// C#. Java's shape with C's brace style: no keyword introduces a method, so
// `fn_decl_paren` names one, and the convention Microsoft publishes puts the
// body's brace on its own line, so `fn_block_own_line` is on. Both mechanisms
// already existed; this file is vocabulary and two decisions.
//
// `struct` is in `fn_decl` here, where C and C++ deliberately leave it out.
// The argument against it there was `struct stat st;` - an elaborated type
// reference that would open a span and take the enclosing function's name from
// every line under it. C# has no such syntax: after `struct` comes a
// declaration or nothing, so the risk the other two carry does not exist.
//
// Contextual keywords are included only where the word is not also an ordinary
// identifier. `record`, `async`, `await`, `nameof` and the pattern operators
// are in; `value`, `file`, `from` and `select` are out, because `var value =`
// and `var file =` are lines people write every day and coloured wrongly they
// would be noticed. `record` is the one kept against that rule, for Java's
// reason: it is common in code written since C# 9 and the declaration path is
// safe either way.
//
// Verbatim strings are modelled as raw and multiline, which is right except
// for `""` - the way a verbatim literal escapes a quote. `@"say ""hi"""` ends
// at the first of the pair and the rest of the line lexes as code. The
// alternative is a doubling rule that no other language here needs; the cost
// is one uncommon literal, bounded by the line.

const langdef = @import("../langdef.zig");

pub const def = langdef.define(.{
    .name = "csharp",
    .extensions = &.{ "cs", "csx" },
    // `///` doc comments are the prefix match taking the whole line.
    .line_comment = &.{"//"},
    .block_comment = .{ .open = "/*", .close = "*/" },
    .strings = &.{
        // Raw literals before plain, or `"""` opens and closes an empty "".
        .{ .open = "\"\"\"", .close = "\"\"\"", .multiline = true },
        // Verbatim: backslashes are ordinary and the literal crosses lines.
        // `$@"` and `@$"` reach this through the '@', the '$' having lexed as
        // punctuation - an interpolated literal needs no spec of its own.
        .{ .open = "@\"", .close = "\"", .escape = null, .multiline = true },
        .{ .open = "\"", .close = "\"" },
        .{ .open = "'", .close = "'", .max_bytes = 12 },
    },
    .keywords = &.{
        "abstract",   "and",      "as",        "async",     "await",
        "base",       "break",    "case",      "catch",     "checked",
        "class",      "const",    "continue",  "default",   "delegate",
        "do",         "else",     "enum",      "event",     "explicit",
        "extern",     "false",    "finally",   "fixed",     "for",
        "foreach",    "get",      "global",    "goto",      "if",
        "implicit",   "in",       "init",      "interface", "internal",
        "is",         "lock",     "namespace", "nameof",    "new",
        "not",        "null",     "operator",  "or",        "out",
        "override",   "params",   "partial",   "private",   "protected",
        "public",     "readonly", "record",    "ref",       "required",
        "return",     "scoped",   "sealed",    "set",       "sizeof",
        "stackalloc", "static",   "struct",    "switch",    "this",
        "throw",      "true",     "try",       "typeof",    "unchecked",
        "unsafe",     "using",    "virtual",   "volatile",  "when",
        "where",      "while",    "with",      "yield",
        // Directives, one word each - the '#' in `ident_extra` is what makes
        // them tokens rather than punctuation and a name.
            "#if",
        "#else",      "#elif",    "#endif",    "#define",   "#undef",
        "#warning",   "#error",   "#line",     "#region",   "#endregion",
        "#nullable",  "#pragma",
    },
    .types = &.{
        "bool",     "byte",        "char",        "decimal",       "double",
        "dynamic",  "float",       "int",         "long",          "nint",
        "nuint",    "object",      "sbyte",       "short",         "string",
        "uint",     "ulong",       "ushort",      "var",           "void",
        // The library a reader recognises without being told.
        "Action",   "Array",       "Boolean",     "Byte",          "CancellationToken",
        "Char",     "Console",     "DateTime",    "Decimal",       "Dictionary",
        "Double",   "Enum",        "Exception",   "Func",          "Guid",
        "HashSet",  "IDisposable", "IEnumerable", "IList",         "Int32",
        "Int64",    "List",        "Math",        "Nullable",      "Object",
        "Span",     "Stream",      "String",      "StringBuilder", "Task",
        "TimeSpan", "Type",        "Uri",
    },
    // For the reason Java's and Python's `class` is in theirs: a method wins
    // as the innermost span, and a line between two methods still reports the
    // type it sits in. `namespace` is last resort and covers the file-scoped
    // form, which declares a span with no block at all.
    .fn_decl = &.{ "class", "interface", "struct", "record", "enum", "namespace" },
    // xUnit, NUnit and MSTest, which agree on nothing. `[TestCase` has no
    // closing bracket because it always carries arguments.
    .test_decl = &.{ "[Fact]", "[Theory]", "[Test]", "[TestCase", "[TestMethod]" },
    // `Assert` covers `Assert.Equal`, `Assert.That` and NUnit's
    // `ClassicAssert`; `.Should()` is FluentAssertions, which writes no
    // assertion the first pattern would catch.
    .assert_names = &.{ "Assert", ".Should()" },
    // `[Ignore]` is NUnit and MSTest, `Skip =` is xUnit's `[Fact(Skip = ..)]`,
    // and the unspaced spelling is the same attribute written by someone
    // else's formatter.
    .skip_names = &.{ "[Ignore", "Skip =", "Skip=", "Assert.Ignore(" },
    .fn_decl_paren = true,
    .fn_block_own_line = true,
    .ident_extra = "#",
});
