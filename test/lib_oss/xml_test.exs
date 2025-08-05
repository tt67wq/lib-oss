defmodule LibOss.XmlTest do
  use ExUnit.Case, async: true

  alias LibOss.Xml

  doctest LibOss.Xml

  describe "naive_map/1" do
    test "parses simple XML with single element" do
      xml = "<root><item>value</item></root>"
      result = Xml.naive_map(xml)
      expected = %{"root" => %{"item" => "value"}}

      assert result == expected
    end

    test "parses nested XML structures" do
      xml = "<root><parent><child>nested_value</child></parent></root>"
      result = Xml.naive_map(xml)
      expected = %{"root" => %{"parent" => %{"child" => "nested_value"}}}

      assert result == expected
    end

    test "handles deeply nested XML" do
      xml = "<root><level1><level2><level3>deep_value</level3></level2></level1></root>"
      result = Xml.naive_map(xml)
      expected = %{"root" => %{"level1" => %{"level2" => %{"level3" => "deep_value"}}}}

      assert result == expected
    end

    test "handles empty elements" do
      xml = "<root><empty></empty></root>"
      result = Xml.naive_map(xml)
      expected = %{"root" => %{"empty" => ""}}

      assert result == expected
    end

    test "handles self-closing tags" do
      xml = "<root><self_closing/></root>"
      result = Xml.naive_map(xml)
      expected = %{"root" => %{"self_closing" => ""}}

      assert result == expected
    end

    test "handles multiple empty elements" do
      xml = "<root><empty1></empty1><empty2/></root>"
      result = Xml.naive_map(xml)
      expected = %{"root" => %{"empty1" => "", "empty2" => ""}}

      assert result == expected
    end

    test "handles XML with only text content" do
      xml = "<root>simple text</root>"
      result = Xml.naive_map(xml)
      expected = %{"root" => "simple text"}

      assert result == expected
    end

    test "handles multiple elements with same tag name" do
      xml = "<root><item>1</item><item>2</item><item>3</item></root>"
      result = Xml.naive_map(xml)
      expected = %{"root" => %{"item" => ["1", "2", "3"]}}

      assert result == expected
    end

    test "handles mixed single and multiple elements" do
      xml = "<root><single>alone</single><multi>first</multi><multi>second</multi></root>"
      result = Xml.naive_map(xml)
      expected = %{"root" => %{"single" => "alone", "multi" => ["first", "second"]}}

      assert result == expected
    end

    test "handles XML with attributes" do
      xml = ~s|<root id="123"><item type="text">value</item></root>|
      result = Xml.naive_map(xml)

      assert result["root"]["id"] == "123"
      assert result["root"]["item"]["type"] == "text"
      assert result["root"]["item"]["#content"] == "value"
    end

    test "handles XML with multiple attributes" do
      xml = ~s|<element id="1" name="test" active="true">content</element>|
      result = Xml.naive_map(xml)

      assert result["element"]["id"] == "1"
      assert result["element"]["name"] == "test"
      assert result["element"]["active"] == "true"
      assert result["element"]["#content"] == "content"
    end

    test "handles XML with attributes on empty elements" do
      xml = ~s|<root><empty id="123"/></root>|
      result = Xml.naive_map(xml)
      expected = %{"root" => %{"empty" => %{"id" => "123", "#content" => ""}}}

      assert result == expected
    end

    test "handles XML with nested elements having attributes" do
      xml = ~s|<root><parent id="p1"><child name="c1">value</child></parent></root>|
      result = Xml.naive_map(xml)

      assert result["root"]["parent"]["id"] == "p1"
      assert result["root"]["parent"]["child"]["name"] == "c1"
      assert result["root"]["parent"]["child"]["#content"] == "value"
    end

    test "handles whitespace correctly" do
      xml = """
      <root>
        <item>  spaced value  </item>
        <empty>   </empty>
      </root>
      """

      result = Xml.naive_map(xml)

      assert result["root"]["item"] == "spaced value"
      assert result["root"]["empty"] == ""
    end

    test "handles CDATA sections" do
      xml = "<root><![CDATA[Special characters: <>&\"']]></root>"
      result = Xml.naive_map(xml)
      expected = %{"root" => "Special characters: <>&\"'"}

      assert result == expected
    end

    test "handles XML with mixed content and elements" do
      xml = "<root>Text before<child>child_value</child>Text after</root>"
      result = Xml.naive_map(xml)

      # Should contain the child element
      assert result["root"]["child"] == "child_value"
    end
  end

  describe "OSS response examples" do
    test "parses OSS GetObjectACL response" do
      xml = """
      <AccessControlPolicy>
        <Owner>
          <ID>00220120222</ID>
          <DisplayName>00220120222</DisplayName>
        </Owner>
        <AccessControlList>
          <Grant>public-read</Grant>
        </AccessControlList>
      </AccessControlPolicy>
      """

      result = Xml.naive_map(xml)

      assert result["AccessControlPolicy"]["Owner"]["ID"] == "00220120222"
      assert result["AccessControlPolicy"]["Owner"]["DisplayName"] == "00220120222"
      assert result["AccessControlPolicy"]["AccessControlList"]["Grant"] == "public-read"
    end

    test "parses OSS ListBucket response with single object" do
      xml = """
      <ListBucketResult>
        <Name>mybucket</Name>
        <Prefix></Prefix>
        <Contents>
          <Key>file1.txt</Key>
          <Size>1024</Size>
          <LastModified>2023-01-01T10:00:00.000Z</LastModified>
        </Contents>
      </ListBucketResult>
      """

      result = Xml.naive_map(xml)

      assert result["ListBucketResult"]["Name"] == "mybucket"
      assert result["ListBucketResult"]["Prefix"] == ""
      assert result["ListBucketResult"]["Contents"]["Key"] == "file1.txt"
      assert result["ListBucketResult"]["Contents"]["Size"] == "1024"
    end

    test "parses OSS ListBucket response with multiple objects" do
      xml = """
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
      """

      result = Xml.naive_map(xml)

      assert result["ListBucketResult"]["Name"] == "mybucket"
      contents = result["ListBucketResult"]["Contents"]
      assert is_list(contents)
      assert length(contents) == 2
      assert Enum.at(contents, 0)["Key"] == "file1.txt"
      assert Enum.at(contents, 1)["Key"] == "file2.txt"
    end

    test "parses OSS InitiateMultipartUpload response" do
      xml = """
      <InitiateMultipartUploadResult>
        <Bucket>mybucket</Bucket>
        <Key>myobject</Key>
        <UploadId>0004B9895DBBB6EC98E36</UploadId>
      </InitiateMultipartUploadResult>
      """

      result = Xml.naive_map(xml)

      assert result["InitiateMultipartUploadResult"]["Bucket"] == "mybucket"
      assert result["InitiateMultipartUploadResult"]["Key"] == "myobject"
      assert result["InitiateMultipartUploadResult"]["UploadId"] == "0004B9895DBBB6EC98E36"
    end

    test "parses OSS GetObjectTagging response" do
      xml = """
      <Tagging>
        <TagSet>
          <Tag>
            <Key>category</Key>
            <Value>document</Value>
          </Tag>
          <Tag>
            <Key>priority</Key>
            <Value>high</Value>
          </Tag>
        </TagSet>
      </Tagging>
      """

      result = Xml.naive_map(xml)

      tags = result["Tagging"]["TagSet"]["Tag"]
      assert is_list(tags)
      assert length(tags) == 2

      first_tag = Enum.at(tags, 0)
      assert first_tag["Key"] == "category"
      assert first_tag["Value"] == "document"

      second_tag = Enum.at(tags, 1)
      assert second_tag["Key"] == "priority"
      assert second_tag["Value"] == "high"
    end

    test "parses OSS BucketInfo response" do
      xml = """
      <BucketInfo>
        <Bucket>
          <CreationDate>2023-01-01T00:00:00.000Z</CreationDate>
          <ExtranetEndpoint>oss-cn-beijing.aliyuncs.com</ExtranetEndpoint>
          <IntranetEndpoint>oss-cn-beijing-internal.aliyuncs.com</IntranetEndpoint>
          <Location>oss-cn-beijing</Location>
          <Name>mybucket</Name>
          <StorageClass>Standard</StorageClass>
        </Bucket>
      </BucketInfo>
      """

      result = Xml.naive_map(xml)
      bucket = result["BucketInfo"]["Bucket"]

      assert bucket["Name"] == "mybucket"
      assert bucket["Location"] == "oss-cn-beijing"
      assert bucket["StorageClass"] == "Standard"
      assert bucket["CreationDate"] == "2023-01-01T00:00:00.000Z"
    end
  end

  describe "error handling" do
    test "raises error for invalid XML" do
      invalid_xml = "<root><unclosed>"

      assert catch_exit(Xml.naive_map(invalid_xml))
    end

    test "raises error for malformed XML" do
      malformed_xml = "<root><item>value</root></item>"

      assert catch_exit(Xml.naive_map(malformed_xml))
    end

    test "handles XML with special characters in content" do
      xml = "<root><item>&lt;special&gt; &amp; characters</item></root>"
      result = Xml.naive_map(xml)

      assert result["root"]["item"] == "<special> & characters"
    end
  end

  describe "edge cases" do
    test "handles XML with numeric content" do
      xml = "<root><number>12345</number></root>"
      result = Xml.naive_map(xml)

      # XML parsing returns strings, not numbers
      assert result["root"]["number"] == "12345"
    end

    test "handles XML with boolean-like content" do
      xml = "<root><flag>true</flag><other>false</other></root>"
      result = Xml.naive_map(xml)

      # XML parsing returns strings, not booleans
      assert result["root"]["flag"] == "true"
      assert result["root"]["other"] == "false"
    end

    test "handles XML with namespace declarations" do
      xml = ~s|<root xmlns:ns="http://example.com"><ns:item>value</ns:item></root>|
      result = Xml.naive_map(xml)

      # Should handle namespaced elements
      assert is_map(result["root"])
    end

    test "handles very simple XML" do
      xml = "<root/>"
      result = Xml.naive_map(xml)
      expected = %{"root" => ""}

      assert result == expected
    end

    test "handles XML with only root element and text" do
      xml = "<message>Hello World</message>"
      result = Xml.naive_map(xml)
      expected = %{"message" => "Hello World"}

      assert result == expected
    end
  end

  describe "performance characteristics" do
    test "handles moderately complex XML efficiently" do
      # Create XML with multiple levels and repeated elements
      xml = """
      <root>
        #{for i <- 1..10 do
        "<group id=\"#{i}\">#{for j <- 1..5 do
          "<item>value_#{i}_#{j}</item>"
        end}</group>"
      end}
      </root>
      """

      result = Xml.naive_map(xml)

      # Should complete without timeout and return correct structure
      assert is_map(result)
      assert Map.has_key?(result, "root")
      groups = result["root"]["group"]
      assert is_list(groups)
      assert length(groups) == 10
    end
  end
end
