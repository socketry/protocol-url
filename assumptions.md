# Path Representation Assumptions

URL paths cross several representation and trust boundaries. A `String` does not, by itself, identify which representation it contains. Callers and APIs must make that representation explicit and must not silently reinterpret one representation as another.

## 1. Encoded URL Path String

This is the URI-syntax representation, such as an HTTP request path:

```text
/files/a%2Fb/report%20final.txt
```

The URI syntax is ASCII. Octets outside the permitted character set, and data which would otherwise be interpreted as a delimiter, are represented with percent encoding.

Only a literal `/` separates path segments. A percent-encoded slash (`%2F`, equivalently `%2f`) is data within its existing segment and is not structural at this layer. Absolute and relative paths use the same encoding rules.

This representation may be untrusted. It must be validated before canonicalization, structural simplification, or conversion to another path domain.

## 2. Decoded Components in an Array

This representation records segment boundaries structurally:

```ruby
["", "files", "a/b", "report final.txt"]
```

Because the array records the boundaries, a decoded `/` can safely occur inside one component. Dot-segments are also explicit values: `"."` and `".."`.

Decoded components are not automatically safe filesystem components. A component may contain a slash, null byte, or another value which cannot be represented as one component on the target operating system.

## 3. Decoded Path String with `/` Separators

This representation is ambiguous and generally unsuitable as an intermediate form:

```ruby
["a/b"]    # One component containing a slash.
["a", "b"] # Two components.
```

Joining either array with `/` produces `"a/b"`. The original boundary information is lost unless delimiter data is percent-encoded again. Code should not convert decoded components into a slash-delimited string and later try to recover the components by splitting it.

## 4. Operating-System Path String

This is a platform-specific mapping to a filesystem path. The mapping may be partial or lossy because operating systems have their own separators, encodings, reserved names, drive syntax, and forbidden values.

Conversion must validate every component for the target platform. A value which cannot be represented faithfully and safely as one filesystem component must be rejected rather than silently transformed into a different path.

## Current `Protocol::URL::Path` Model

`Path.split` accepts representation 1, validates it, establishes the boundaries at literal `/` characters, and returns canonical **encoded** components. It decodes percent encodings for unreserved characters but preserves encodings for reserved characters and other octets:

```ruby
Protocol::URL::Path.split("/files/a%2fb")
# => ["", "files", "a%2Fb"]
```

The return value is therefore an encoded-component intermediate, not the fully decoded representation described in category 2. Preserving `%2F` ensures that later string operations cannot confuse component data with a separator.

`Path.simplify` is a structural operation on component arrays. It resolves components which are literally `"."` or `".."`; it does not decode component data.

`Path.to_local_path` is the explicit transition to representation 4. It decodes component data while applying operating-system restrictions. In particular, it rejects encoded local separators because decoding one would change a single URL component into multiple filesystem components.

## Why `%2F` Is Not Structural in a URL Path

[RFC 3986 section 3.3](https://www.rfc-editor.org/rfc/rfc3986.html#section-3.3) defines a path as segments separated by the literal `/` character. Its grammar allows `pct-encoded` inside each `segment` via `pchar`. Consequently, `/a%2Fb` contains one non-empty segment, while `/a/b` contains two.

[RFC 3986 section 2.1](https://www.rfc-editor.org/rfc/rfc3986.html#section-2.1) defines percent encoding as a representation of an octet within a component. [Section 2.2](https://www.rfc-editor.org/rfc/rfc3986.html#section-2.2) says that a reserved character and its percent-encoded form are not equivalent, and that decoding a percent-encoded reserved character changes URI interpretation. `/` is one of those reserved characters. Consistently, [section 6.2.2.2](https://www.rfc-editor.org/rfc/rfc3986.html#section-6.2.2.2) permits percent-decoding unreserved characters during normalization, not reserved characters such as `/`.

Therefore `%2F` is not a URL path separator. It may become structural only when a later layer deliberately decodes it and interprets the result in another path domain.

## Rack Behavior

Rack 3.2.6 preserves this distinction at its general request interface, but makes a different choice at its static-file boundary:

- The [Rack specification](https://github.com/rack/rack/blob/v3.2.6/SPEC.rdoc#L31-L39) says that `PATH_INFO` may be percent-encoded.
- [`Rack::Request#path_info`](https://github.com/rack/rack/blob/v3.2.6/lib/rack/request.rb#L199) returns the `PATH_INFO` environment value without unescaping it.
- [`Rack::Utils.unescape_path`](https://github.com/rack/rack/blob/v3.2.6/lib/rack/utils.rb#L52-L53) performs full URI unescaping, so `a%2Fb` becomes `a/b`.
- [`Rack::Files`](https://github.com/rack/rack/blob/v3.2.6/lib/rack/files.rb#L45-L49) explicitly unescapes `request.path_info` before cleaning it and joining it to the filesystem root.

Thus Rack does not establish `%2F` as structural URL syntax. `Rack::Files` deliberately makes it structural during application-specific filesystem conversion. For a component-preserving conversion, the alternative is to split before decoding and reject a decoded local separator rather than allow it to introduce a new filesystem boundary.
