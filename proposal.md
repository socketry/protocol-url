# Rooted Local Paths.

## Objective.

Make `Protocol::URL::Path#local_path` safe against lexical path traversal by requiring a filesystem root and returning only paths contained beneath that root.

The method maps URL path segments to filesystem components. It does not make arbitrary filesystem access safe or establish a symlink policy.

## Interface.

The root is required:

```ruby
path.local_path(root)
```

For example:

```ruby
path = Protocol::URL::Path["/images/logo.png"]
path.local_path("/srv/public")
# => "/srv/public/images/logo.png"
```

Calling `local_path` without a root is not supported. A URL path beginning with `/` is interpreted relative to the supplied root, not relative to the filesystem root.

## Resolution.

1. Expand the supplied root to an absolute filesystem path.
2. Decode each URL segment exactly once using `Protocol::URL::Encoding::System`.
3. Reject decoded NUL characters and filesystem separators, as `Encoding::System` does currently.
4. Remove the first empty component from an absolute URL path. This component represents the URL root and must not become the filesystem root.
5. Join the root and remaining components, then expand the resulting absolute path.
6. Return the expanded path only when it is the root itself or is contained beneath the root.
7. Otherwise, raise `ArgumentError`.

Containment uses a root prefix ending with `File::SEPARATOR`. The trailing separator prevents a root such as `/srv/public` from incorrectly matching `/srv/publicity`.

```ruby
def local_path(root)
	root = File.expand_path(root)
	root_prefix = root.end_with?(File::SEPARATOR) ? root : root + File::SEPARATOR
	
	components = self.components(Encoding::System)
	components.shift if components.first == ""
	
	path = File.expand_path(File.join(root, *components))
	
	if path == root || path.start_with?(root_prefix)
		return path
	end
	
	raise ArgumentError, "Path escapes the specified root!"
end
```

## Security Boundary.

This design prevents lexical traversal through literal or percent-encoded parent components, including paths such as:

```text
/../../etc/passwd
/%2E%2E/%2E%2E/etc/passwd
```

It also preserves the existing rejection of encoded separators such as `%2F` when one URL segment would otherwise become multiple filesystem components.

`File.expand_path` does not resolve symbolic links. A symlink beneath the root may therefore refer to a target outside the root while the returned pathname remains lexically contained. This is acceptable only when the filesystem tree beneath the root is trusted against modification by an attacker.

Applications serving attacker-writable trees need an operation-oriented interface which opens the file beneath a directory descriptor and enforces an explicit symlink policy. Returning a pathname cannot eliminate the race between validation and opening the file.

## Tests.

Coverage should include:

- Absolute URL paths resolved beneath the supplied root.
- Relative URL paths resolved beneath the supplied root.
- The root path itself.
- Literal `..` traversal beyond the root.
- Percent-encoded `..` traversal beyond the root.
- Parent components which remain within the root after expansion.
- Roots whose names are prefixes of sibling paths.
- Encoded NUL and filesystem separators.
- Roots supplied as relative paths.
- Trailing separators on roots and URL paths.
- Repeated leading separators in URL paths.
- Literal `~` and `~user` components.
