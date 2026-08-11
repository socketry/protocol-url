# Follow-up Notes

## Update `low-rb/low_loop`

File a follow-up PR against [`low-rb/low_loop`](https://github.com/low-rb/low_loop). Its file server currently uses the removed `Protocol::URL::Path.to_local_path` API in `lib/servers/file_server.rb`:

```ruby
filepath = Protocol::URL::Path.to_local_path(Protocol::URL[event.request.path].path)
```

Update it to use the `Path` instance returned by `URL#path`:

```ruby
filepath = Protocol::URL[event.request.path].path.local_path(web_root)
```

This call is security-sensitive because it converts an untrusted request path into a filesystem path. Confirm that the updated code passes `web_root` directly to `local_path`, handles traversal errors, and has an explicit policy for symlinks beneath the served root.
