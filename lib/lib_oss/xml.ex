defmodule LibOss.Xml do
  @moduledoc """
  Unified XML processing module for LibOss.

  This module provides a consistent interface for XML parsing operations,
  abstracting the underlying XML parsing library implementation.
  """

  import SweetXml

  @doc """
  Converts XML string to a map structure, compatible with XmlToMap.naive_map/1.

  This function parses XML and converts it to a nested map structure that
  matches the output format expected by the rest of the LibOss codebase.

  ## Examples

      iex> xml = "<root><item>value</item></root>"
      iex> LibOss.Xml.naive_map(xml)
      %{"root" => %{"item" => "value"}}

      iex> xml = "<root><items><item>1</item><item>2</item></items></root>"
      iex> LibOss.Xml.naive_map(xml)
      %{"root" => %{"items" => %{"item" => ["1", "2"]}}}

  ## Parameters

    - `xml` - XML string to parse

  ## Returns

    - `map` - Parsed XML as nested map structure

  ## Raises

    - `SweetXml.XmlParseError` - When XML parsing fails
  """
  @spec naive_map(String.t()) :: map()
  def naive_map(xml) when is_binary(xml) do
    xml
    |> parse()
    |> convert_element_to_map()
  end

  # Private functions

  defp convert_element_to_map(xml_element) when elem(xml_element, 0) == :xmlElement do
    {name, attrs, children} = extract_element_parts(xml_element)
    tag_name = Atom.to_string(name)
    content = process_children(children)

    element_map = %{tag_name => content}

    case attrs do
      [] -> element_map
      _ -> add_attributes_to_map(element_map, tag_name, attrs)
    end
  end

  defp convert_element_to_map(xml_text) when elem(xml_text, 0) == :xmlText do
    text = extract_text_content(xml_text)
    text |> to_string() |> String.trim()
  end

  defp convert_element_to_map(other), do: other

  defp process_children([]) do
    ""
  end

  defp process_children(children) do
    children
    |> filter_meaningful_children()
    |> handle_children()
  end

  defp filter_meaningful_children(children) do
    Enum.filter(children, fn
      xml_text when elem(xml_text, 0) == :xmlText ->
        text = extract_text_content(xml_text)
        text |> to_string() |> String.trim() != ""

      _ ->
        true
    end)
  end

  defp handle_children([]) do
    ""
  end

  defp handle_children([xml_text]) when elem(xml_text, 0) == :xmlText do
    text = extract_text_content(xml_text)
    text |> to_string() |> String.trim()
  end

  defp handle_children([single_element]) do
    handle_single_child(single_element)
  end

  defp handle_children(multiple_children) do
    handle_multiple_children(multiple_children)
  end

  defp handle_single_child(element) do
    case convert_element_to_map(element) do
      map when is_map(map) ->
        map

      other ->
        other
    end
  end

  defp handle_multiple_children(children) do
    children
    |> Enum.map(&convert_element_to_map/1)
    |> group_by_tag_name()
  end

  defp group_by_tag_name(elements) do
    # Group maps by their keys, handling duplicate tag names
    Enum.reduce(elements, %{}, fn
      element_map, acc when is_map(element_map) ->
        Enum.reduce(element_map, acc, fn {key, value}, inner_acc ->
          case Map.get(inner_acc, key) do
            nil ->
              Map.put(inner_acc, key, value)

            existing when is_list(existing) ->
              Map.put(inner_acc, key, existing ++ [value])

            existing ->
              Map.put(inner_acc, key, [existing, value])
          end
        end)

      _non_map, acc ->
        acc
    end)
  end

  defp extract_element_parts(
         {:xmlElement, name, _expanded_name, _nsinfo, _namespace, _parents, _pos, attrs, children, _language, _xmlbase,
          _elementdef}
       ) do
    {name, attrs, children}
  end

  defp extract_text_content({:xmlText, _parents, _pos, _language, text, _type}) do
    text
  end

  defp add_attributes_to_map(element_map, tag_name, attrs) do
    attr_map =
      Map.new(attrs, fn {:xmlAttribute, name, _, _, _, _, _, _, value, _} ->
        {Atom.to_string(name), to_string(value)}
      end)

    current_content = Map.get(element_map, tag_name)

    updated_content =
      case current_content do
        content when is_map(content) ->
          Map.merge(attr_map, content)

        other ->
          Map.put(attr_map, "#content", other)
      end

    Map.put(element_map, tag_name, updated_content)
  end
end
