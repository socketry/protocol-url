# Getting Started

This guide explains how to get started with `protocol-url` for parsing, manipulating, and constructing URLs in Ruby.

## Installation

Add the gem to your project:

``` shell
$ bundle add protocol-url
```

## Core Concepts

`protocol-url` provides a clean, standards-compliant API for working with URLs according to RFC 3986. The library is organized around three main classes:

- {ruby Protocol::URL::Absolute} represents complete URLs with scheme and authority (e.g., `https://example.com/path`)
- {ruby Protocol::URL::Relative} represents relative URLs without scheme or authority (e.g., `/path` or `path/to/file`)
- {ruby Protocol::URL::Reference} extends relative URLs with query parameters and fragments

Additionally, the {ruby Protocol::URL::Path} class preserves encoded path structure while exposing decoded components, and provides utilities for path manipulation according to RFC 3986 rules.

## Usage

Parse complete URLs with scheme and authority:

``` ruby
require "protocol/url"

# Parse an absolute URL:
url = Protocol::URL["https://api.example.com:8080/v1/users?page=2#results"]
url.scheme      # => "https"
url.authority   # => "api.example.com:8080"
url.path.to_s   # => "/v1/users"
url.query       # => "page=2"
url.fragment    # => "results"
```

Parse relative URLs and references:

``` ruby
# Parse a relative URL:
relative = Protocol::URL["/api/v1/users"]
relative.path.to_s  # => "/api/v1/users"

# Parse a reference with query and fragment:
reference = Protocol::URL["/search?q=ruby#top"]
reference.path.to_s # => "/search"
reference.query     # => "q=ruby"
reference.fragment  # => "top"
```

### Constructing URLs

Build URLs programmatically:

``` ruby
# Create an absolute URL:
url = Protocol::URL::Absolute.new("https", "example.com", "/api/users")
url.to_s  # => "https://example.com/api/users"

# The authority can include port and userinfo:
url = Protocol::URL::Absolute.new("https", "user:pass@api.example.com:8080", "/v1")
url.to_s  # => "https://user:pass@api.example.com:8080/v1"

# Create a reference with components:
reference = Protocol::URL::Reference.new("/api/search", "q=ruby&limit=10", "results")
reference.to_s  # => "/api/search?q=ruby&limit=10#results"
```

### Combining URLs

URLs can be combined following RFC 3986 resolution rules:

``` ruby
# Combine absolute URL with relative path:
base = Protocol::URL["https://example.com/docs/guide/"]
relative = Protocol::URL::Relative.new("../api/reference.html")

result = base + relative
result.to_s  # => "https://example.com/docs/api/reference.html"

# Absolute paths replace the base path:
absolute_path = Protocol::URL::Relative.new("/completely/different/path")
result = base + absolute_path
result.to_s  # => "https://example.com/completely/different/path"
```

## Path Manipulation

The {ruby Protocol::URL::Path} class provides powerful utilities for working with URL paths:

### Encoded Paths, Segments, and Components

``` ruby
# Preserve the encoded path and its encoded segments:
path = Protocol::URL::Path["/a/b%2Fc"]
path.segments    # => ["", "a", "b%2Fc"]

# Decode components explicitly (using Protocol::URL::Encoding by default):
path.components  # => ["", "a", "b/c"]

# An array passed to Path[] contains encoded segments:
path = Protocol::URL::Path[["", "a", "b%2Fc"]]
path.to_s  # => "/a/b%2Fc"

# Construct a path from decoded components without losing their boundaries:
path = Protocol::URL::Path.for(["", "a", "b/c"])
path.to_s  # => "/a/b%2Fc"
```

Strings and arrays passed to `Path[]` are encoded URL syntax. `segments` exposes
that lossless representation for structural operations, while `components`
crosses the decoding boundary and may depend on the selected encoding. Use
`Path.for` when inserting decoded application values into a URL.

### Inspecting Paths

``` ruby
path = Protocol::URL::Path["/releases/archive.tar.gz"]

path.basename                    # => "archive.tar.gz"
path.basename(extension: false)  # => "archive.tar"
path.parent.to_s                 # => "/releases"
path.parent(2).to_s              # => "/"
```

### Simplifying Paths

Remove literal or percent-encoded dot segments (`.`, `..`, `%2E`, and equivalent
mixed spellings) from paths without decoding retained segments:

``` ruby
# Simplify a path:
path = Protocol::URL::Path[["a", "b", "..", "c", ".", "d"]]
path.simplify.components
# => ["a", "c", "d"]

# Works with absolute paths:
path = Protocol::URL::Path[["", "a", "b", "..", "..", "c"]]
path.simplify.components
# => ["", "c"]
```

### Joining Paths

Merge two paths according to RFC 3986 rules:

``` ruby
# Join a relative path against a base:
result = Protocol::URL::Path["/a/b/c"].join("../d").to_s
# => "/a/d"

# Handle complex relative paths:
result = Protocol::URL::Path["/a/b/c/d"].join("../../e/f").to_s
# => "/a/b/e/f"

# Absolute relative paths replace the base:
result = Protocol::URL::Path["/a/b/c"].join("/x/y/z").to_s
# => "/x/y/z"
```

The `join` method has an optional `pop` parameter (default: `true`) that controls whether the last component of the base path is removed before merging:

``` ruby
# With pop=true (default), behaves like URI resolution:
Protocol::URL::Path["/a/b/file.html"].join("other.html").to_s
# => "/a/b/other.html"

# With pop=false, treats base as a directory:
Protocol::URL::Path["/a/b/file.html"].join("other.html", pop: false).to_s
# => "/a/b/file.html/other.html"
```

### Converting to Local File System Paths

Convert URL paths to local file system paths safely:

``` ruby
# Convert URL path to local file system path:
Protocol::URL::Path["/documents/report.pdf"].local_path
# => "/documents/report.pdf"

# Handles percent-encoded characters:
Protocol::URL::Path["/files/My%20Document.txt"].local_path
# => "/files/My Document.txt"

# Encoded separators which cannot map to one local component are rejected:
Protocol::URL::Path["/folder/safe%2Fname/file.txt"].local_path
# Raises ArgumentError.
```

`local_path` decodes with `Protocol::URL::Encoding::System` by default. It
enforces a one-to-one mapping between URL components and file-system components:
an encoded separator such as `%2F` cannot become an extra file-system boundary.
It deliberately does not simplify `.` or `..`, because leading parent
components are meaningful in relative paths. For paths from an untrusted
source, establish the URL-path policy before conversion:

``` ruby
path = Protocol::URL::Path[encoded_request_path]
path = path.simplify
system_path = path.local_path
```

For absolute URL paths, `simplify` resolves dot segments and prevents navigation above the URL root. For relative paths, unresolved leading `..` components are retained. `local_path` does not by itself guarantee containment beneath an application directory; the caller must enforce that trust boundary when resolving the resulting system path.

## Working with References

{ruby Protocol::URL::Reference} extends relative URLs with query parameters and fragments. For detailed information on working with references, see the [Working with References](../working-with-references/) guide.

Quick example:

``` ruby
# Create a reference with query and fragment:
reference = Protocol::URL::Reference.new("/api/users", "status=active", "results")
reference.to_s  # => "/api/users?status=active#results"

# Update components immutably:
updated = reference.with(query: "status=inactive")
updated.to_s  # => "/api/users?status=inactive#results"
```

## URL Encoding

The library handles URL encoding automatically for path components:

``` ruby
require "protocol/url/encoding"

# Encode decoded components without losing separator boundaries:
escaped = Protocol::URL::Path.for(["", "path", "with spaces", "file.html"]).to_s
# => "/path/with%20spaces/file.html"

# Escape query parameters:
escaped = Protocol::URL::Encoding.escape("hello world!")
# => "hello%20world%21"

# Unescape percent-encoded strings:
unescaped = Protocol::URL::Encoding.unescape("hello%20world%21")
# => "hello world!"
```

## Practical Examples

### Building API URLs

``` ruby
# Build a base API URL:
base = Protocol::URL::Absolute.new("https", "api.example.com", "/v2")

# Add resource paths:
users_endpoint = base + Protocol::URL::Relative.new("users")
users_endpoint.to_s  # => "https://api.example.com/v2/users"

# Add specific resource ID:
user_detail = users_endpoint + Protocol::URL::Relative.new("123")
user_detail.to_s  # => "https://api.example.com/v2/users/123"
```

### Resolving Relative Links

When parsing HTML or processing links, you often need to resolve relative URLs:

``` ruby
# Page URL:
page = Protocol::URL["https://example.com/docs/guide/intro.html"]

# Resolve relative link found in page:
link = Protocol::URL::Relative.new("../api/reference.html")
resolved = page + link
resolved.to_s  # => "https://example.com/docs/api/reference.html"

# Resolve same-directory link:
link = Protocol::URL::Relative.new("getting-started.html")
resolved = page + link
resolved.to_s  # => "https://example.com/docs/guide/getting-started.html"
```

### URL Normalization

Clean up URLs by simplifying paths:

``` ruby
# URL with redundant path segments:
messy = Protocol::URL["https://example.com/a/b/../c/./d"]

# Parsing preserves the original path until simplification is requested:
messy.path.to_s  # => "/a/b/../c/./d"

messy.normalize!
messy.path.to_s  # => "/a/c/d"
messy.to_s  # => "https://example.com/a/c/d"
```

## Best Practices

### Choose the Right Class

- Use {ruby Protocol::URL::Absolute} for complete URLs with scheme and host
- Use {ruby Protocol::URL::Relative} for paths without scheme or authority  
- Use {ruby Protocol::URL::Reference} when you need query parameter or fragment support

### Path Manipulation

When manipulating paths:
- Use {ruby Protocol::URL::Path#join} for combining paths
- Use {ruby Protocol::URL::Path#simplify} to remove dot segments
- Remember that `join` pops the last component by default (RFC 3986 behavior)

### Encoding

- The library handles encoding automatically for path components
- Use {ruby Protocol::URL::Encoding} methods directly when you need explicit control
- Remember that spaces become `%20` in paths and `+` or `%20` in query strings

## Common Pitfalls

### Pop Behavior When Joining Paths

The `join` method pops the last path component by default to match RFC 3986 URI resolution:

``` ruby
# This might be surprising:
Protocol::URL::Path["/api/users"].join("groups").to_s
# => "/api/groups" (not "/api/users/groups")

# To prevent popping, use pop=false:
Protocol::URL::Path["/api/users"].join("groups", pop: false).to_s
# => "/api/users/groups"
```

### Empty Paths

Empty relative paths return the base unchanged:

``` ruby
base = Protocol::URL::Reference.new("/api/users")
same = base.with(path: "")
same.to_s  # => "/api/users" (unchanged)
```

### Trailing Slashes

Trailing slashes are preserved and have semantic meaning:

``` ruby
# Directory (trailing slash):
Protocol::URL::Path["/docs/"].join("page.html").to_s
# => "/docs/page.html"

# File (no trailing slash):
Protocol::URL::Path["/docs"].join("page.html").to_s
# => "/page.html" (pops "docs")
```
