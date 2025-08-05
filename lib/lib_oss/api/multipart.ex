defmodule LibOss.Api.Multipart do
  @moduledoc """
  OSS多部分上传相关API

  提供多部分上传的初始化、上传分片、完成上传、中止上传等功能。
  """

  alias LibOss.Core
  alias LibOss.Typespecs

  @doc """
  使用Multipart Upload模式传输数据前，您必须先调用InitiateMultipartUpload接口来通知OSS初始化一个Multipart Upload事件。

  Doc: https://help.aliyun.com/document_detail/31992.html

  ## Examples

      iex> init_multi_upload(bucket, "test.txt")
      {:ok, "upload_id"}
  """
  @spec init_multi_upload(module(), Typespecs.bucket(), Typespecs.object(), Typespecs.headers()) ::
          {:ok, Typespecs.upload_id()} | {:error, LibOss.Exception.t()}
  def init_multi_upload(client, bucket, object, req_headers \\ []) do
    Core.init_multi_upload(client, bucket, object, req_headers)
  end

  @doc """
  初始化一个MultipartUpload后，调用UploadPart接口根据指定的Object名和uploadId来分块（Part）上传数据。

  Doc: https://help.aliyun.com/document_detail/31993.html

  ## Examples

      iex> upload_part(bucket, "test.txt", "upload_id", 1, "hello world")
      {:ok, "etag"}
  """
  @spec upload_part(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.upload_id(),
          Typespecs.part_num(),
          binary()
        ) :: {:ok, Typespecs.etag()} | {:error, LibOss.Exception.t()}
  def upload_part(client, bucket, object, upload_id, part_number, data) do
    Core.upload_part(client, bucket, object, upload_id, part_number, data)
  end

  @doc """
  调用ListMultipartUploads接口列举所有执行中的Multipart Upload事件，即已经初始化但还未完成（Complete）或者还未中止（Abort）的Multipart Upload事件。

  Doc: https://help.aliyun.com/document_detail/31997.html

  ## Examples

      iex> list_multipart_uploads(bucket, %{"delimiter"=>"/", "max-uploads" => 10, "prefix"=>"test/"})
      {:ok,
       [
         %{
           "ETag" => "\"1334928900AEB317206CC7EB950540EF-3\"",
           "Key" => "test/multi-test.txt",
           "LastModified" => "2023-07-18T11:16:45.000Z",
           "Owner" => %{
             "DisplayName" => "1074124462684153",
             "ID" => "1074124462684153"
           },
           "Size" => "409608",
           "StorageClass" => "Standard",
           "Type" => "Multipart"
         },
         %{
           "ETag" => "\"5EB63BBBE01EEED093CB22BB8F5ACDC3\"",
           "Key" => "test/test.txt",
           "LastModified" => "2023-07-18T11:19:19.000Z",
           "Owner" => %{
             "DisplayName" => "1074124462684153",
             "ID" => "1074124462684153"
           },
           "Size" => "11",
           "StorageClass" => "Standard",
           "Type" => "Normal"
         }
       ]}
  """
  @spec list_multipart_uploads(module(), Typespecs.bucket(), Typespecs.params()) ::
          {:ok, list(Typespecs.dict())} | {:error, LibOss.Exception.t()}
  def list_multipart_uploads(client, bucket, query_params) do
    Core.list_multipart_uploads(client, bucket, query_params)
  end

  @doc """
  所有数据Part都上传完成后，您必须调用CompleteMultipartUpload接口来完成整个文件的分片上传。

  Doc: https://help.aliyun.com/document_detail/31995.html

  ## Examples

      iex> {:ok, etag1} = upload_part(bucket, "test.txt", "upload_id", 1, part1)
      iex> {:ok, etag2} = upload_part(bucket, "test.txt", "upload_id", 2, part2)
      iex> {:ok, etag3} = upload_part(bucket, "test.txt", "upload_id", 3, part3)
      iex> complete_multipart_upload(bucket, "test.txt", "upload_id", [{1, etag1}, {2, etag2}, {3, etag3}])
      :ok
  """
  @spec complete_multipart_upload(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.upload_id(),
          [{Typespecs.part_num(), Typespecs.etag()}],
          Typespecs.headers()
        ) :: :ok | {:error, LibOss.Exception.t()}
  def complete_multipart_upload(client, bucket, object, upload_id, parts, headers \\ []) do
    Core.complete_multipart_upload(client, bucket, object, upload_id, parts, headers)
  end

  @doc """
  AbortMultipartUpload接口用于取消MultipartUpload事件并删除对应的Part数据。

  Doc: https://help.aliyun.com/document_detail/31996.html

  ## Examples

      iex> abort_multipart_upload(bucket, "test.txt", "upload_id")
      :ok
  """
  @spec abort_multipart_upload(module(), Typespecs.bucket(), Typespecs.object(), Typespecs.upload_id()) ::
          :ok | {:error, LibOss.Exception.t()}
  def abort_multipart_upload(client, bucket, object, upload_id) do
    Core.abort_multipart_upload(client, bucket, object, upload_id)
  end

  @doc """
  ListParts接口用于列举指定Upload ID所属的所有已经上传成功Part。

  Doc: https://help.aliyun.com/document_detail/31998.html

  ## Examples

      iex> list_parts(bucket, "test.txt", "upload_id")
      {:ok,
       %{
        "ListPartsResult" => %{
          "Bucket" => "hope-data",
          "IsTruncated" => "false",
          "Key" => "test/multi-test.txt",
          "MaxParts" => "1000",
          "NextPartNumberMarker" => "3",
          "Part" => [
            %{
              "ETag" => "\"3170FC594DACE56C506E0196B5DEA1D1\"",
              "HashCrc64ecma" => "10873275732915280589",
              "LastModified" => "2023-07-19T02:58:16.000Z",
              "PartNumber" => "1",
              "Size" => "136536"
            },
            %{
              "ETag" => "\"5539D60A05FD504B8210A662D7D15C1E\"",
              "HashCrc64ecma" => "4592881501542342075",
              "LastModified" => "2023-07-19T02:58:17.000Z",
              "PartNumber" => "2",
              "Size" => "136536"
            },
            %{
              "ETag" => "\"5C7D509F5744115EE3B2D55F4893FE3F\"",
              "HashCrc64ecma" => "9048307046109329978",
              "LastModified" => "2023-07-19T02:58:17.000Z",
              "PartNumber" => "3",
              "Size" => "136536"
            }
          ],
          "PartNumberMarker" => "0",
          "StorageClass" => "Standard",
          "UploadId" => "39663F02E9384C87BFC9E9B0E8B1100E"
        }
      }}
  """
  @spec list_parts(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.upload_id(),
          Typespecs.params()
        ) :: {:ok, list(Typespecs.dict())} | {:error, LibOss.Exception.t()}
  def list_parts(client, bucket, object, upload_id, query_params \\ %{}) do
    Core.list_parts(client, bucket, object, upload_id, query_params)
  end

  @doc """
  创建宏，用于在客户端模块中导入所有多部分上传函数
  """
  defmacro __using__(_opts) do
    quote do
      alias LibOss.Api.Multipart

      # 定义委托函数，自动传入客户端模块名
      def init_multi_upload(bucket, object, req_headers \\ []) do
        Multipart.init_multi_upload(__MODULE__, bucket, object, req_headers)
      end

      def upload_part(bucket, object, upload_id, part_number, data) do
        Multipart.upload_part(__MODULE__, bucket, object, upload_id, part_number, data)
      end

      def list_multipart_uploads(bucket, query_params) do
        Multipart.list_multipart_uploads(__MODULE__, bucket, query_params)
      end

      def complete_multipart_upload(bucket, object, upload_id, parts, headers \\ []) do
        Multipart.complete_multipart_upload(__MODULE__, bucket, object, upload_id, parts, headers)
      end

      def abort_multipart_upload(bucket, object, upload_id) do
        Multipart.abort_multipart_upload(__MODULE__, bucket, object, upload_id)
      end

      def list_parts(bucket, object, upload_id, query_params \\ %{}) do
        Multipart.list_parts(__MODULE__, bucket, object, upload_id, query_params)
      end
    end
  end
end
