# Working with References

This guide explains how to use {ruby Protocol::URL::Reference} for managing URLs with query parameters and fragments.

## Overview

{ruby Protocol::URL::Reference} extends {ruby Protocol::URL::Relative} with support for query strings and fragments. References are ideal when you need to work with URLs that include query parameters (like `?page=2&sort=name`) or fragments (like `#section-3`).

## Creating References

You can create references in several ways:

### Constructing from Components

~~~ ruby
require 'protocol/url'

# Reference with path only:
reference = Protocol::URL::Reference.new("/api/users")
reference.to_s  # => "/api/users"

# Reference with query string:
reference = Protocol::URL::Reference.new("/search", "q=ruby&page=2")
reference.to_s  # => "/search?q=ruby&page=2"

# Reference with fragment:
reference = Protocol::URL::Reference.new("/docs", nil, "section-3")
reference.to_s  # => "/docs#section-3"

# Reference with all components:
reference = Protocol::URL::Reference.new("/api/users", "status=active", "results")
reference.to_s  # => "/api/users?status=active#results"
~~~

### Parsing from Strings

Use {ruby Protocol::URL.[]} to parse complete URL strings:

~~~ ruby
# Parse a reference with query and fragment:
reference = Protocol::URL["/api/users?active=true&role=admin#list"]
reference.path      # => "/api/users"
reference.query     # => "active=true&role=admin"
reference.fragment  # => "list"
~~~

## Accessing Components

References provide accessors for all URL components:

~~~ ruby
reference = Protocol::URL["/api/v1/users?page=2&limit=50#results"]

# Path component:
reference.path      # => "/api/v1/users"

# Query string (unparsed):
reference.query     # => "page=2&limit=50"

# Fragment (decoded):
reference.fragment  # => "results"
~~~

## Updating References

The {ruby Protocol::URL::Reference#with} method creates a new reference with modified components. This follows an immutable pattern - the original reference is unchanged.

### Modifying the Path

~~~ ruby
base = Protocol::URL::Reference.new("/api/v1/users")

# Append to path with relative reference:
detail = base.with(path: "123")
detail.to_s  # => "/api/v1/users/123"

# Navigate with relative paths:
sibling = detail.with(path: "../groups")
sibling.to_s  # => "/api/v1/groups"

# Replace with absolute path:
root = base.with(path: "/status")
root.to_s  # => "/status"
~~~

The path resolution follows RFC 3986 rules, using {ruby Protocol::URL::Path.expand} internally.

### Updating Query Parameters

~~~ ruby
base = Protocol::URL::Reference.new("/search", "q=ruby")

# Replace query string:
filtered = base.with(query: "q=ruby&lang=en")
filtered.to_s  # => "/search?q=ruby&lang=en"

# Remove query string:
no_query = base.with(query: nil)
no_query.to_s  # => "/search"
~~~

### Updating Fragments

~~~ ruby
doc = Protocol::URL::Reference.new("/docs/guide")

# Add fragment:
section = doc.with(fragment: "installation")
section.to_s  # => "/docs/guide#installation"

# Change fragment:
different = section.with(fragment: "usage")
different.to_s  # => "/docs/guide#usage"

# Remove fragment:
no_fragment = section.with(fragment: nil)
no_fragment.to_s  # => "/docs/guide"
~~~

### Updating Multiple Components

You can update multiple components at once:

~~~ ruby
base = Protocol::URL::Reference.new("/api/users")

modified = base.with(
  path: "posts",
  query: "author=john&status=published",
  fragment: "top"
)
modified.to_s  # => "/api/posts?author=john&status=published#top"
~~~

## Combining with Absolute URLs

References can be combined with absolute URLs to create complete URLs:

~~~ ruby
# Base absolute URL:
base = Protocol::URL["https://api.example.com/v1"]

# Relative reference:
reference = Protocol::URL::Reference.new("users", "active=true", "list")

# Combine them:
result = base + reference
result.to_s  # => "https://api.example.com/v1/users?active=true#list"
~~~

## Fragment Encoding

Fragments are automatically decoded when parsing and encoded when converting to strings:

~~~ ruby
# Parsing decodes percent-encoded fragments:
reference = Protocol::URL["/docs#hello%20world"]
reference.fragment  # => "hello world" (decoded)
reference.to_s      # => "/docs#hello%20world" (re-encoded)

# Special characters are preserved:
reference = Protocol::URL["/page#section/1.2?note"]
reference.fragment  # => "section/1.2?note"
# Characters like / and ? are allowed in fragments per RFC 3986
~~~

## Practical Examples

### Building Paginated API Requests

~~~ ruby
# Start with base endpoint:
endpoint = Protocol::URL::Reference.new("/api/users", "page=1&limit=20")

# Parse query string into parameters:
endpoint.parse_query!
endpoint.parameters  # => {"page" => "1", "limit" => "20"}

# Update page number:
next_page = endpoint.with(parameters: {"page" => "2"})
next_page.to_s  # => "/api/users?page=2&limit=20"

# Add filtering (merge with existing parameters):
filtered = endpoint.with(parameters: {"status" => "active"})
filtered.to_s  # => "/api/users?page=1&limit=20&status=active"
~~~

### Documentation Links with Anchors

~~~ ruby
# Base documentation path:
doc = Protocol::URL::Reference.new("/docs/api")

# Link to specific section:
intro = doc.with(fragment: "introduction")
intro.to_s  # => "/docs/api#introduction"

# Different section in same document:
methods = doc.with(fragment: "methods")
methods.to_s  # => "/docs/api#methods"

# Navigate to related document:
tutorial = doc.with(path: "/docs/tutorial", fragment: "step-1")
tutorial.to_s  # => "/docs/tutorial#step-1"
~~~

### Search Results with Filters

~~~ ruby
# Initial search:
search = Protocol::URL::Reference.new("/search", "q=ruby")

# Add language filter:
filtered = search.with(query: "q=ruby&lang=en")
filtered.to_s  # => "/search?q=ruby&lang=en"

# Jump to specific result:
result = filtered.with(fragment: "result-5")
result.to_s  # => "/search?q=ruby&lang=en#result-5"
~~~

## Best Practices

### When to Use References

- Use {ruby Protocol::URL::Reference} when working with query parameters or fragments
- Use {ruby Protocol::URL::Relative} for simple path-only URLs
- Use {ruby Protocol::URL::Absolute} for complete URLs with scheme and host

### Query String Management

The library provides built-in parameter handling through the `parameters` attribute:

~~~ ruby
# Create reference with query string:
reference = Protocol::URL::Reference.new("/search", "q=ruby&page=2")

# Parse query string into parameters hash:
reference.parse_query!
reference.parameters  # => {"q" => "ruby", "page" => "2"}
reference.query       # => nil (cleared after parsing)

# Update with new parameters (merged):
updated = reference.with(parameters: {"lang" => "en"})
updated.to_s  # => "/search?q=ruby&page=2&lang=en"

# Replace parameters completely (merge: false):
replaced = reference.with(parameters: {"q" => "python"}, merge: false)
replaced.to_s  # => "/search?q=python"
~~~

Alternatively, you can provide parameters directly when creating a reference:

~~~ ruby
# Create with parameters directly:
reference = Protocol::URL::Reference.new("/search", nil, nil, {"q" => "ruby", "page" => "2"})
reference.to_s  # => "/search?q=ruby&page=2"
~~~

### Immutability

References are immutable - `with` always returns a new instance:

~~~ ruby
original = Protocol::URL::Reference.new("/api/users")
modified = original.with(query: "active=true")

original.to_s  # => "/api/users" (unchanged)
modified.to_s  # => "/api/users?active=true" (new instance)
~~~

## Common Pitfalls

### Empty Path Updates

Empty paths are treated as "no change" in `with`:

~~~ ruby
base = Protocol::URL::Reference.new("/api/users")
same = base.with(path: "")
same.to_s  # => "/api/users" (unchanged)
~~~

To clear the path completely, use an absolute empty path:

~~~ ruby
root = base.with(path: "/")
root.to_s  # => "/"
~~~

### Fragment vs Query Order

Fragments always come after query strings in URLs:

~~~ ruby
# Correct order: path?query#fragment
reference = Protocol::URL::Reference.new("/page", "q=test", "section")
reference.to_s  # => "/page?q=test#section"
~~~
