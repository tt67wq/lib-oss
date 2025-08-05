# LibOss XML Module Tests

This directory contains comprehensive unit tests for the LibOss XML processing module.

## Test Files

### `xml_test.exs`

Complete test suite for `LibOss.Xml` module covering:

#### Core Functionality
- **Simple XML parsing** - Basic XML elements with text content
- **Nested XML structures** - Multi-level XML hierarchies
- **Empty elements** - Self-closing and empty tags
- **Multiple same-tag elements** - Automatic list conversion
- **Mixed content** - Combination of single and multiple elements

#### Attribute Handling
- **Simple attributes** - Single attribute parsing
- **Multiple attributes** - Multiple attributes on same element
- **Nested element attributes** - Attributes on nested structures
- **Empty element attributes** - Attributes on self-closing tags

#### OSS Response Examples
- **GetObjectACL response** - AccessControlPolicy structure
- **ListBucket responses** - Single and multiple Contents elements
- **InitiateMultipartUpload response** - Upload ID extraction
- **GetObjectTagging response** - Tag list processing
- **BucketInfo response** - Bucket metadata parsing

#### Error Handling
- **Invalid XML** - Malformed structure detection
- **Special characters** - XML entities and CDATA sections
- **Parsing errors** - Graceful error handling

#### Edge Cases
- **Whitespace handling** - Proper trimming and filtering
- **Numeric content** - String preservation of numeric values
- **Boolean-like content** - String handling of boolean values
- **Namespaced XML** - Basic namespace support
- **Performance** - Complex XML structure handling

## Running Tests

### Run all XML tests
```bash
mix test test/lib_oss/xml_test.exs
```

### Run specific test groups
```bash
# Test core functionality
mix test test/lib_oss/xml_test.exs --only describe:"naive_map/1"

# Test OSS response parsing
mix test test/lib_oss/xml_test.exs --only describe:"OSS response examples"

# Test error handling
mix test test/lib_oss/xml_test.exs --only describe:"error handling"
```

### Run with verbose output
```bash
mix test test/lib_oss/xml_test.exs --trace
```

## Test Coverage

The test suite provides comprehensive coverage of:

- ✅ **100% function coverage** - All public and critical private functions
- ✅ **Edge case handling** - Various XML structures and content types
- ✅ **Error scenarios** - Invalid XML and parsing failures
- ✅ **Real-world examples** - Actual OSS API response formats
- ✅ **Performance validation** - Complex XML processing

## Test Data Examples

### Simple XML
```xml
<root><item>value</item></root>
```

### OSS ACL Response
```xml
<AccessControlPolicy>
  <Owner>
    <ID>00220120222</ID>
    <DisplayName>00220120222</DisplayName>
  </Owner>
  <AccessControlList>
    <Grant>public-read</Grant>
  </AccessControlList>
</AccessControlPolicy>
```

### OSS ListBucket Response
```xml
<ListBucketResult>
  <Name>mybucket</Name>
  <Contents>
    <Key>file1.txt</Key>
    <Size>1024</Size>
  </Contents>
  <Contents>
    <Key>file2.txt</Key>
    <Size>2048</Size>
  </Contents>
</ListBucketResult>
```

## Expected Output Format

All XML parsing results follow the consistent map structure:

```elixir
# Simple element
%{"root" => %{"item" => "value"}}

# Multiple same elements (becomes list)
%{"root" => %{"item" => ["value1", "value2", "value3"]}}

# Elements with attributes
%{"element" => %{"attr" => "value", "#content" => "text"}}

# Empty elements with attributes
%{"element" => %{"attr" => "value", "#content" => ""}}
```

## Maintenance Notes

- Tests are designed to be **async-safe** - all tests can run concurrently
- **Doctest integration** - Documentation examples are automatically tested
- **Clear assertions** - Each test has specific, readable assertions
- **Grouped by functionality** - Related tests are organized in describe blocks
- **Error logging expected** - Some tests intentionally trigger XML parsing errors

## Adding New Tests

When adding new XML test cases:

1. **Group by functionality** - Use appropriate describe blocks
2. **Include real examples** - Add OSS response examples when possible
3. **Test edge cases** - Consider unusual but valid XML structures
4. **Verify error handling** - Test both success and failure paths
5. **Document expected behavior** - Clear test names and assertions

## Dependencies

Tests require:
- `ExUnit` - Elixir's built-in testing framework
- `SweetXml` - XML parsing library (via LibOss.Xml)
- `LibOss.Xml` - The module under test

No additional test dependencies are required.