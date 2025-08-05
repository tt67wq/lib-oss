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

  defp convert_element_to_map(
         {:xmlElement, name, _expanded_name, _nsinfo, _namespace, _parents, _pos, attrs, children, _language, _xmlbase,
          _elementdef}
       ) do
    tag_name = Atom.to_string(name)
    content = process_children(children)

    element_map = %{tag_name => content}

    case attrs do
      [] -> element_map
      _ -> add_attributes_to_map(element_map, tag_name, attrs)
    end
  end

  defp convert_element_to_map({:xmlText, _parents, _pos, _language, text, _type}) do
    text |> to_string() |> String.trim()
  end

  defp convert_element_to_map(other), do: other

  defp process_children([]) do
    ""
  end

  defp process_children(children) do
    # Filter out whitespace-only text nodes
    meaningful_children =
      Enum.filter(children, fn
        {:xmlText, _, _, _, text, _} ->
          text |> to_string() |> String.trim() != ""

        _ ->
          true
      end)

    case meaningful_children do
      [] ->
        ""

      [{:xmlText, _, _, _, text, _}] ->
        text |> to_string() |> String.trim()

      [single_element] ->
        case convert_element_to_map(single_element) do
          map when is_map(map) ->
            map

          other ->
            other
        end

      multiple_children ->
        # Convert all children and group by tag name
        converted = Enum.map(multiple_children, &convert_element_to_map/1)
        group_by_tag_name(converted)
    end
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
