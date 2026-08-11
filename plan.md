# Generic Path Representation Plan

## Objective

Make `Protocol::URL::Path` a lossless representation of the path portion of a URL. Generic path operations must preserve encoded syntax without assuming how an application interprets decoded segment data.

This addresses cases such as:

```text
a%3Ab/c -> join("d") -> a%3Ab/d
```

The operation must not produce `a:b/d`, which would be reparsed as a URI with scheme `a`.

## Core representation

`Path` will retain two lazy representations:

```ruby
@encoded  # The complete encoded path String.
@segments # Array(String), split from @encoded on literal "/".
```

- Segment strings remain percent-encoded.
- Splitting on literal `/` is the only generic structural interpretation performed by `Path`.
- `%2F` remains data inside one segment.
- Leading, trailing, and repeated `/` characters remain represented by empty segments.
- Both the encoded string and segment array are immutable once materialized.
- A transformed path can share unchanged encoded segment strings with its source path.
- `Path#encoded` joins encoded segments with literal `/` when the complete string is not already cached.

## Decoding interface

Decoding is supplied by an encoding object rather than being intrinsic to `Path`:

```ruby
def components(encoding = Encoding)
	segments.map {|segment| encoding.unescape(segment)}
end
```

- `Path#components` returns `Array(String)`.
- Components are computed for each call and are not cached because the result depends on `encoding`.
- `Protocol::URL::Encoding` is the default encoding implementation.
- The extension interface consists of `escape` and `unescape`:

```ruby
encoding.escape(decoded_component) # -> one encoded segment
encoding.unescape(encoded_segment) # -> one decoded component
```

- `escape` must never return a literal `/`, because one encoded result must represent exactly one path segment.
- `unescape` may return `/`; it remains data inside its component Array entry.

## Constructing paths from decoded components

Provide an explicit constructor for decoded application data:

```ruby
Path.for(components, encoding: Encoding)
```

It escapes each component independently and constructs a path from the resulting encoded segments. This makes the encoded/decoded trust boundary explicit.

`Path[Array(String)]` accepts already-encoded segments. As with string input, it
stays entirely within the encoded domain. A segment cannot contain a literal
`/`; callers with decoded component values must use `Path.for`.

## Path operations

Structural operations must work with encoded segments rather than decoded components:

- `parent`
- `join`
- `relative`
- `simplify` and `simplify!`

Unchanged segments must retain their original encoded spelling. In particular, operations must not decode and then reconstruct retained segments.

Generic simplification identifies empty segments and both literal and
percent-encoded spellings of `.` and `..`. Dot is an RFC 3986 unreserved
character, so `%2E`, `.%2e`, and `%2e%2E` have the same traversal meaning as
their literal forms. Other segments retain their exact encoded spelling.

## Reserved characters and parameters

RFC 3986 treats each path segment as opaque `pchar` data. It does not define the legacy RFC 2396 `name;parameter` structure.

Therefore the generic implementation will not split segments on `;` or introduce `Path::Component`/`Path::Segment` parameter interpretation at this stage.

Applications that implement matrix/path parameters can inspect an encoded segment, split it on literal `;`, and then unescape the resulting fields. This preserves the distinction between:

```text
g;x   # A literal semicolon that an application may interpret as syntax.
g%3Bx # An encoded semicolon that remains segment data.
```

## Filesystem conversion

Retain filesystem conversion as an instance operation with an explicit system
encoding policy:

```ruby
path.local_path(encoding: Encoding::System)
```

Conceptually, this is layered on decoded components:

1. Obtain components using the selected URL encoding.
2. Reject invalid byte or character encoding.
3. Reject NUL and decoded platform path separators.
4. Convert each component to the filesystem character encoding.
5. Join the resulting local components with the platform separator.

`Encoding::System` implements the same `escape`/`unescape` interface as other
path encodings, but its `unescape` operation additionally enforces the
one-URL-segment-to-one-local-component boundary and performs filesystem
transcoding. It is a module representing the current platform rather than an
instantiable encoding policy.

`local_path` does not resolve `.` or `..` and does not establish containment.
Callers must simplify and enforce their filesystem root policy separately.

## Equality and ordering

Equality is based on the exact encoded representation:

```ruby
def eql?(other)
	other.is_a?(Path) && encoded.eql?(other.encoded)
end

def hash
	encoded.hash
end
```

Use the `encoded` accessor here if `@encoded` remains lazy; it materializes the
same canonical stored representation before comparison or hashing.

`==` should use the same exact encoded comparison. Consequently, paths such as
`/a/%62` and `/a/b` remain distinct even if a particular decoder produces the
same components for both. Any normalized or encoding-dependent comparison must
be explicit rather than hidden behind ordinary equality.

Ordering should likewise compare encoded representations so that `<=> == 0`
is consistent with `==` and `eql?`.

## Documentation

Document the trust boundaries explicitly:

- String input is encoded URL syntax.
- Array input contains encoded URL segments.
- `segments` are encoded strings and safe to rearrange without reinterpretation.
- `components(encoding)` are decoded application values and may be lossy.
- Decoded values must be escaped before being inserted as URL segments.
- Filesystem conversion is platform- and application-policy dependent.

## Test coverage

Add public-contract tests covering:

- Exact preservation of encoded segments through `parent`, `join`, `relative`, and simplification.
- `a%3Ab/c` remaining a relative path after manipulation.
- `/a%2Fb` remaining distinct from `/a/b`.
- Raw reserved characters remaining distinct from their percent-encoded spellings in the encoded representation.
- Different encoding objects producing different `components` results without cache contamination.
- `Path.for` escaping each decoded component independently.
- Literal and percent-encoded dot-segment behavior.
- Filesystem rejection of decoded separators and NUL.
- Full test and documentation coverage.
