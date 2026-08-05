# Releases

## v0.10.0

  - Rename `Protocol::URL::FormData::Parser::CONTENT_TYPE` to `MEDIA_TYPE`.

## v0.9.0

  - Add `Protocol::URL::LimitError` for configured processing limits.

## v0.8.0

  - Use consistent limit naming for form data parser constraints.

## v0.7.0

  - Allow `Protocol::URL::FormData::Parser#parse` to populate a supplied result object.

## v0.6.0

  - Add `Protocol::URL::FormData::Parser` for incremental, limited parsing of `application/x-www-form-urlencoded` form data.
  - Add `Protocol::URL::FormData::Nested` for consistently building nested form data while preserving absent and empty values.

## v0.5.0

  - Add `Protocol::URL::Encoding.decode_www_form` for decoding HTML form data where `+` represents a space.

## v0.4.0

  - Add comparison methods to `Protocol::URL::Relative` (and by inheritance to `Protocol::URL::Absolute`):
      - `#==` for structural equality comparison (compares path, query, fragment components).
      - `#===` for string equality comparison (enables case statement matching).
      - `#<=>` for ordering and sorting.
      - `#hash` for hash key support.
      - `#equal?` for component-based equality checking.
  - Add JSON serialization support to `Protocol::URL::Relative`:
      - `#as_json` returns the string representation.
      - `#to_json` returns a JSON-encoded string.

## v0.3.0

  - Add `relative(target, from)` for computing relative paths between URLs.

## v0.2.0

  - Move `Protocol::URL::PATTERN` to `protocol/url/pattern.rb` so it can be shared more easily.

## v0.1.0

  - Initial implementation.
