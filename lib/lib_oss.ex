defmodule LibOss do
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  @external_resource "README.md"
  defmacro __using__(opts) do
    quote do
      alias LibOss.Core
      alias LibOss.Typespecs

      @type ok_t(ret) :: {:ok, ret}
      @type err_t() :: {:error, LibOss.Exception.t()}

      def init(config) do
        {:ok, config}
      end

      defoverridable init: 1

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      def start_link(config \\ []) do
        otp_app = unquote(opts[:otp_app])

        {:ok, cfg} =
          otp_app
          |> Application.get_env(__MODULE__, config)
          |> init()

        LibOss.Supervisor.start_link(__MODULE__, cfg)
      end

      defp delegate(method, args), do: apply(Core, method, [__MODULE__ | args])

      @doc """
      function description
      通过Web端直传文件（Object）到OSS的签名生成

      Doc: https://help.aliyun.com/document_detail/31926.html

      ## Example

          iex> LibOss.get_token(cli, bucket, "/test/test.txt")
          {:ok, "{\"accessid\":\"LTAI1k8kxWG8JpUF\",\"callback\":\"=\",\"dir\":\"/test/test.txt\",\".........ePNPyWQo=\"}"}
      """
      @spec get_token(Typespecs.bucket(), Typespecs.object(), non_neg_integer(), binary()) ::
              {:ok, binary()} | err_t()
      def get_token(bucket, object, expire_sec \\ 3600, callback \\ "")

      def get_token(bucket, object, expire_sec, callback) do
        delegate(:get_token, [bucket, object, expire_sec, callback])
      end

      #### object operations: https://help.aliyun.com/document_detail/31977.html

      @doc """
      调用PutObject接口上传文件（Object）。

      Doc: https://help.aliyun.com/document_detail/31978.html

      ## Examples

          iex> put_object(bucket, "/test/test.txt", "hello world")
          :ok
      """
      @spec put_object(Typespecs.bucket(), Typespecs.object(), iodata(), Typespecs.headers()) :: :ok | err_t()
      def put_object(bucket, object, data, headers \\ []) do
        delegate(:put_object, [bucket, object, data, headers])
      end

      @doc """
      GetObject接口用于获取某个文件（Object）。此操作需要对此Object具有读权限。

      Doc: https://help.aliyun.com/document_detail/31980.html

      req_headers的具体参数可参考文档中”请求头“部分说明

      ## Examples

          iex> get_object(bucket, "/test/test.txt")
          {:ok, "hello world"}
      """
      @spec get_object(Typespecs.bucket(), Typespecs.object(), Typespecs.headers()) :: {:ok, binary()} | err_t()
      def get_object(bucket, object, req_headers \\ []) do
        delegate(:get_object, [bucket, object, req_headers])
      end

      @doc """
      调用CopyObject接口拷贝同一地域下相同或不同存储空间（Bucket）之间的文件（Object）。

      Doc: https://help.aliyun.com/document_detail/31979.html

      ## Examples

          iex> copy_object(target_bucket, "object_copy.txt", source_bucket, "object.txt")
          :ok
      """
      @spec copy_object(
              Typespecs.bucket(),
              Typespecs.object(),
              Typespecs.bucket(),
              Typespecs.object(),
              Typespecs.headers()
            ) :: :ok | err_t()
      def copy_object(bucket, object, source_bucket, source_object, headers \\ []) do
        delegate(:copy_object, [bucket, object, source_bucket, source_object, headers])
      end

      @doc """
      调用DeleteObject删除某个文件（Object）。

      Doc: https://help.aliyun.com/document_detail/31982.html

      ## Examples

          iex> delete_object(bucket, "/test/test.txt")
          :ok
      """
      @spec delete_object(Typespecs.bucket(), Typespecs.object()) :: :ok | err_t()
      def delete_object(bucket, object) do
        delegate(:delete_object, [bucket, object])
      end

      @doc """
      DeleteMultipleObjects接口用于删除同一个存储空间（Bucket）中的多个文件（Object）。

      Doc: https://help.aliyun.com/document_detail/31983.html

      ## Examples

          iex> delete_multiple_objects(bucket, ["/test/test_1.txt", "/test/test_2.txt"]])
          :ok
      """

      @spec delete_multiple_objects(Typespecs.bucket(), [Typespecs.object()]) :: :ok | err_t()
      def delete_multiple_objects(bucket, objects) do
        delegate(:delete_multiple_objects, [bucket, objects])
      end

      @doc """
      调用AppendObject接口用于以追加写的方式上传文件（Object）。

      Doc: https://help.aliyun.com/document_detail/31981.html

      ## Examples

          iex> append_object(bucket, "/test/test.txt", 0, "hello ")
          :ok
          iex> append_object(bucket, "/test/test.txt", 6, "world")
          :ok
      """
      @spec append_object(
              Typespecs.bucket(),
              Typespecs.object(),
              non_neg_integer(),
              binary(),
              Typespecs.headers()
            ) ::
              :ok | err_t()
      def append_object(bucket, object, since, data, headers \\ []) do
        delegate(:append_object, [bucket, object, since, data, headers])
      end

      @doc """
      HeadObject接口用于获取某个文件（Object）的元信息。使用此接口不会返回文件内容。

      Doc: https://help.aliyun.com/document_detail/31984.html

      ## Examples

          iex> head_object(bucket, "/test/test.txt")
          {:ok,
           %{
             "accept-ranges" => "bytes",
             "connection" => "keep-alive",
             "content-length" => "11",
             "content-md5" => "XrY7u+Ae7tCTyyK7j1rNww==",
             "content-type" => "text/plain",
             "date" => "Tue, 18 Jul 2023 06:27:36 GMT",
             "etag" => "\"5EB63BBBE01EEED093CB22BB8F5ACDC3\"",
             "last-modified" => "Tue, 18 Jul 2023 06:27:33 GMT",
             "server" => "AliyunOSS",
             "x-oss-hash-crc64ecma" => "5981764153023615706",
             "x-oss-object-type" => "Normal",
             "x-oss-request-id" => "64B630D8E0DCB93335001974",
             "x-oss-server-time" => "1",
             "x-oss-storage-class" => "Standard"
           }}
      """
      @spec head_object(Typespecs.bucket(), Typespecs.object(), Typespecs.headers()) ::
              {:ok, Typespecs.dict()} | err_t()
      def head_object(bucket, object, headers \\ []) do
        delegate(:head_object, [bucket, object, headers])
      end

      @doc """
      调用GetObjectMeta接口获取一个文件（Object）的元数据信息，包括该Object的ETag、Size、LastModified信息，并且不返回该Object的内容。

      Doc: https://help.aliyun.com/document_detail/31985.html

      ## Examples

          iex> get_object_meta(bucket, "/test/test.txt")
          {:ok,
           %{
             "accept-ranges" => "bytes",
             "connection" => "keep-alive",
             "content-length" => "11",
             "content-md5" => "XrY7u+Ae7tCTyyK7j1rNww==",
             "content-type" => "text/plain",
             "date" => "Tue, 18 Jul 2023 06:29:10 GMT",
             "etag" => "\"5EB63BBBE01EEED093CB22BB8F5ACDC3\"",
             "last-modified" => "Tue, 18 Jul 2023 06:27:33 GMT",
             "server" => "AliyunOSS",
             "x-oss-hash-crc64ecma" => "5981764153023615706",
             "x-oss-object-type" => "Normal",
             "x-oss-request-id" => "64B631365A8AEE32306C9D64",
             "x-oss-server-time" => "2",
             "x-oss-storage-class" => "Standard"
           }}
      """
      @spec get_object_meta(Typespecs.bucket(), Typespecs.object()) ::
              {:ok, Typespecs.dict()} | err_t()
      def get_object_meta(bucket, object) do
        delegate(:get_object_meta, [bucket, object])
      end

      @doc """
      调用PutObjectACL接口修改文件（Object）的访问权限（ACL）

      Doc: https://help.aliyun.com/document_detail/31986.html

      ## Examples

          iex> put_object_acl(bucket, "/test/test.txt", "public-read")
      """
      @spec put_object_acl(Typespecs.bucket(), Typespecs.object(), String.t()) :: :ok | err_t()
      def put_object_acl(bucket, object, acl) do
        delegate(:put_object_acl, [bucket, object, acl])
      end

      @doc """
      调用GetObjectACL接口获取存储空间（Bucket）下某个文件（Object）的访问权限（ACL）。

      Doc: https://help.aliyun.com/document_detail/31987.html

      ## Examples

          iex> get_object_acl(bucket, "/test/test.txt")
          {:ok, "public-read"}
      """
      @spec get_object_acl(Typespecs.bucket(), Typespecs.object()) ::
              {:ok, binary()} | err_t()
      def get_object_acl(bucket, object) do
        delegate(:get_object_acl, [bucket, object])
      end

      # ~~~~~~~~~~~~~~~~~~~~~~~~ bucket operations: https://help.aliyun.com/document_detail/31959.html ~~~~~~~~~~~~~~~~~~~~~~~~

      @doc """
      调用PutBucket接口创建存储空间（Bucket）。

      Doc: https://help.aliyun.com/document_detail/31959.html

      ## Examples

          iex> put_bucket(your-new-bucket)
          :ok
      """
      @spec put_bucket(Typespecs.bucket(), String.t(), String.t(), Typespecs.headers()) :: :ok | err_t()
      def put_bucket(bucket, storage_class \\ "Standard", data_redundancy_type \\ "LRS", headers \\ [])

      def put_bucket(bucket, storage_class, data_redundancy_type, headers) do
        delegate(:put_bucket, [bucket, storage_class, data_redundancy_type, headers])
      end

      @doc """
      调用DeleteBucket删除某个存储空间（Bucket）。

      Doc: https://help.aliyun.com/document_detail/31973.html

      ## Examples

          iex> delete_bucket(to-delete-bucket)
          :ok
      """
      @spec delete_bucket(Typespecs.bucket()) :: :ok | err_t()
      def delete_bucket(bucket) do
        delegate(:delete_bucket, [bucket])
      end
    end
  end

  # @doc """
  # 调用PutSymlink接口用于为OSS的目标文件（TargetObject）创建软链接（Symlink）

  # Doc: https://help.aliyun.com/document_detail/45126.html

  # ## Examples

  #     iex> LibOss.put_symlink(cli, bucket, "/test/test.txt", "/test/test_symlink.txt")
  # """
  # @spec put_symlink(
  #         t(),
  #         Typespecs.bucket(),
  #         Typespecs.object(),
  #         Typespecs.object(),
  #         Typespecs.headers()
  #       ) :: {:ok, any()} | {:error, Exception.t()}
  # def put_symlink(client, bucket, object, target_object, headers \\ []) do
  #   req =
  #     LibOss.Request.new(
  #       method: :put,
  #       object: object,
  #       resource: Path.join(["/", bucket, object]),
  #       sub_resources: [{"symlink", nil}],
  #       bucket: bucket,
  #       headers: [{"x-oss-symlink-target", target_object} | headers]
  #     )

  #   request(client, req)
  # end

  # @doc """
  # 调用GetSymlink接口获取软链接。

  # Doc: https://help.aliyun.com/document_detail/45146.html

  # ## Examples

  #     iex> LibOss.get_symlink(cli, bucket, "/test/test.txt")
  #     {:ok, "/test/test_symlink.txt"}
  # """
  # @spec get_symlink(t(), Typespecs.bucket(), Typespecs.object()) ::
  #         {:ok, bitstring()} | {:error, Exception.t()}
  # def get_symlink(client, bucket, object) do
  #   req =
  #     LibOss.Request.new(
  #       method: :get,
  #       object: object,
  #       resource: Path.join(["/", bucket, object]),
  #       bucket: bucket,
  #       sub_resources: [{"symlink", nil}]
  #     )

  #   client
  #   |> request(req)
  #   |> case do
  #     {:ok, %Http.Response{headers: headers}} ->
  #       headers
  #       |> Enum.find(fn {k, _} -> k == "x-oss-symlink-target" end)
  #       |> then(fn
  #         {_, v} -> {:ok, URI.decode(v)}
  #         nil -> Exception.new("x-oss-symlink-target not found")
  #       end)

  #     err ->
  #       err
  #   end
  # end

  # @doc """
  # 调用PutObjectTagging接口设置或更新对象（Object）的标签（Tagging）信息。

  # Doc: https://help.aliyun.com/document_detail/114855.html

  # ## Examples

  #     iex> LibOss.put_object_tagging(cli, bucket, "/test/test.txt", %{"key1" => "value1", "key2" => "value2"})
  # """
  # @spec put_object_tagging(
  #         t(),
  #         Typespecs.bucket(),
  #         Typespecs.object(),
  #         Typespecs.string_dict()
  #       ) :: {:ok, any()} | {:error, Exception.t()}
  # def put_object_tagging(client, bucket, object, tags) do
  #   tagging =
  #     Enum.map(tags, fn {k, v} -> "<Tag><Key>#{k}</Key><Value>#{v}</Value></Tag>" end)

  #   req =
  #     LibOss.Request.new(
  #       method: :put,
  #       object: object,
  #       resource: Path.join(["/", bucket, object]),
  #       sub_resources: [{"tagging", nil}],
  #       bucket: bucket,
  #       body: "<Tagging><TagSet>#{tagging}</TagSet></Tagging>"
  #     )

  #   request(client, req)
  # end

  # @doc """
  # 调用GetObjectTagging接口获取对象（Object）的标签（Tagging）信息。

  # Doc: https://help.aliyun.com/document_detail/114878.html

  # ## Examples

  #     iex> LibOss.get_object_tagging(cli, bucket, "/test/test.txt")
  #     {:ok,
  #      [
  #        %{"Key" => "key1", "Value" => "value1"},
  #        %{"Key" => "key2", "Value" => "value2"}
  #      ]}
  # """
  # @spec get_object_tagging(t(), Typespecs.bucket(), Typespecs.object()) ::
  #         {:ok, [Typespecs.string_dict()]} | {:error, Exception.t()}
  # def get_object_tagging(client, bucket, object) do
  #   req =
  #     LibOss.Request.new(
  #       method: :get,
  #       object: object,
  #       resource: Path.join(["/", bucket, object]),
  #       bucket: bucket,
  #       sub_resources: [{"tagging", nil}]
  #     )

  #   client
  #   |> request(req)
  #   |> case do
  #     {:ok, %Http.Response{body: body}} ->
  #       body
  #       |> XmlToMap.naive_map()
  #       |> case do
  #         %{"Tagging" => %{"TagSet" => %{"Tag" => tags}}} ->
  #           {:ok, tags}

  #         _ ->
  #           {:error, Exception.new("invalid response", body)}
  #       end

  #     err ->
  #       err
  #   end
  # end

  # @doc """
  # 删除Object当前版本的标签信息。

  # Doc: https://help.aliyun.com/document_detail/114879.html

  # ## Examples

  #     iex> LibOss.delete_object_tagging(cli, bucket, "/test/test.txt")
  # """
  # @spec delete_object_tagging(t(), Typespecs.bucket(), Typespecs.object()) ::
  #         {:ok, any()} | {:error, Exception.t()}
  # def delete_object_tagging(client, bucket, object) do
  #   req =
  #     LibOss.Request.new(
  #       method: :delete,
  #       object: object,
  #       resource: Path.join(["/", bucket, object]),
  #       bucket: bucket,
  #       sub_resources: [{"tagging", nil}]
  #     )

  #   request(client, req)
  # end

  # #### multipart operations: https://help.aliyun.com/document_detail/155825.html

  # @doc """
  # 使用Multipart Upload模式传输数据前，您必须先调用InitiateMultipartUpload接口来通知OSS初始化一个Multipart Upload事件。

  # Doc: https://help.aliyun.com/document_detail/31992.html

  # ## Examples

  #     iex> init_multi_uploads(client, bucket, "test.txt")
  #     {:ok, "upload_id"}
  # """
  # @spec init_multi_upload(
  #         t(),
  #         Typespecs.bucket(),
  #         Typespecs.object(),
  #         Typespecs.headers()
  #       ) :: {:ok, String.t()} | {:error, Exception.t()}
  # def init_multi_upload(client, bucket, object, req_headers \\ []) do
  #   req =
  #     LibOss.Request.new(
  #       method: :post,
  #       object: object,
  #       resource: Path.join(["/", bucket, object]),
  #       bucket: bucket,
  #       headers: req_headers,
  #       sub_resources: [{"uploads", nil}]
  #     )

  #   client
  #   |> request(req)
  #   |> case do
  #     {:ok, %Http.Response{body: body}} ->
  #       body
  #       |> XmlToMap.naive_map()
  #       |> case do
  #         %{"InitiateMultipartUploadResult" => %{"UploadId" => upload_id}} ->
  #           {:ok, upload_id}

  #         _ ->
  #           {:error, Exception.new("invalid response", body)}
  #       end

  #     err ->
  #       err
  #   end
  # end

  # @doc """
  # 初始化一个MultipartUpload后，调用UploadPart接口根据指定的Object名和uploadId来分块（Part）上传数据。

  # Doc: https://help.aliyun.com/document_detail/31993.html

  # ## Examples

  #     iex> upload_part(client, bucket, "test.txt", "upload_id", 1, "hello world")
  #     {:ok, "etag"}
  # """
  # @spec upload_part(
  #         t(),
  #         Typespecs.bucket(),
  #         Typespecs.object(),
  #         String.t(),
  #         non_neg_integer(),
  #         binary()
  #       ) :: {:ok, bitstring()} | {:error, Exception.t()}
  # def upload_part(client, bucket, object, upload_id, partNumber, data) do
  #   req =
  #     LibOss.Request.new(
  #       method: :put,
  #       object: object,
  #       resource: Path.join(["/", bucket, object]),
  #       sub_resources: [{"partNumber", "#{partNumber}"}, {"uploadId", upload_id}],
  #       bucket: bucket,
  #       body: data
  #     )

  #   client
  #   |> request(req)
  #   |> case do
  #     {:ok, %Http.Response{headers: headers}} ->
  #       headers
  #       |> Enum.find(fn {k, _} -> k == "etag" end)
  #       |> then(fn
  #         {_, v} -> {:ok, v}
  #         nil -> {:error, Exception.new("etag not found")}
  #       end)
  #   end
  # end

  # @doc """
  # 调用ListMultipartUploads接口列举所有执行中的Multipart Upload事件，即已经初始化但还未完成（Complete）或者还未中止（Abort）的Multipart Upload事件。

  # Doc: https://help.aliyun.com/document_detail/31997.html

  # ## Examples

  #     iex> list_multipart_uploads(client, bucket, %{"delimiter"=>"/", "max-uploads" => 10, "prefix"=>"test/"})
  #     {:ok,
  #      [
  #        %{
  #          "ETag" => "\"1334928900AEB317206CC7EB950540EF-3\"",
  #          "Key" => "test/multi-test.txt",
  #          "LastModified" => "2023-07-18T11:16:45.000Z",
  #          "Owner" => %{
  #            "DisplayName" => "1074124462684153",
  #            "ID" => "1074124462684153"
  #          },
  #          "Size" => "409608",
  #          "StorageClass" => "Standard",
  #          "Type" => "Multipart"
  #        },
  #        %{
  #          "ETag" => "\"5EB63BBBE01EEED093CB22BB8F5ACDC3\"",
  #          "Key" => "test/test.txt",
  #          "LastModified" => "2023-07-18T11:19:19.000Z",
  #          "Owner" => %{
  #            "DisplayName" => "1074124462684153",
  #            "ID" => "1074124462684153"
  #          },
  #          "Size" => "11",
  #          "StorageClass" => "Standard",
  #          "Type" => "Normal"
  #        }
  #      ]}
  # """
  # @spec list_multipart_uploads(
  #         t(),
  #         Typespecs.bucket(),
  #         Typespecs.params()
  #       ) :: {:ok, [Typespecs.string_dict()]} | {:error, Exception.t()}
  # def list_multipart_uploads(client, bucket, query_params) do
  #   req =
  #     LibOss.Request.new(
  #       method: :get,
  #       object: "?uploads",
  #       resource: Path.join(["/", bucket]) <> "/",
  #       bucket: bucket,
  #       params: query_params
  #     )

  #   client
  #   |> request(req)
  #   |> case do
  #     {:ok, %Http.Response{body: body}} ->
  #       body
  #       |> XmlToMap.naive_map()
  #       |> case do
  #         %{"ListBucketResult" => %{"Contents" => ret}} ->
  #           {:ok, ret}

  #         _ ->
  #           {:error, Exception.new("invalid response", body)}
  #       end

  #     err ->
  #       err
  #   end
  # end

  # @doc """
  # AbortMultipartUpload接口用于取消MultipartUpload事件并删除对应的Part数据。

  # Doc: https://help.aliyun.com/document_detail/31996.html

  # ## Examples

  #     {:ok, return_value} = function_name()
  # """
  # @spec abort_multipart_upload(
  #         t(),
  #         Typespecs.bucket(),
  #         Typespecs.object(),
  #         String.t()
  #       ) :: {:ok, any()} | {:error, Exception.t()}
  # def abort_multipart_upload(client, bucket, object, upload_id) do
  #   req =
  #     LibOss.Request.new(
  #       method: :delete,
  #       object: object,
  #       resource: Path.join(["/", bucket, object]),
  #       sub_resources: [{"uploadId", upload_id}],
  #       bucket: bucket
  #     )

  #   request(client, req)
  # end

  # @doc """
  # 所有数据Part都上传完成后，您必须调用CompleteMultipartUpload接口来完成整个文件的分片上传。

  # Doc: https://help.aliyun.com/document_detail/31995.html

  # ## Examples

  #     iex> {:ok, etag1} = upload_part(client, bucket, "test.txt", "upload_id", 1, part1)
  #     iex> {:ok, etag2} = upload_part(client, bucket, "test.txt", "upload_id", 2, part2)
  #     iex> {:ok, etag3} = upload_part(client, bucket, "test.txt", "upload_id", 3, part3)
  #     iex> complete_multipart_upload(client, bucket, "test.txt", "upload_id", [{1, etag1}, {2, etag2}, {3, etag3}])
  #     {:ok, _}
  # """
  # @spec complete_multipart_upload(
  #         t(),
  #         Typespecs.bucket(),
  #         Typespecs.object(),
  #         String.t(),
  #         [{non_neg_integer(), bitstring()}],
  #         Typespecs.headers()
  #       ) :: {:ok, any()} | {:error, Exception.t()}
  # def complete_multipart_upload(client, bucket, object, upload_id, parts, headers \\ []) do
  #   # format parts
  #   body =
  #     Enum.map_join(parts, "", fn {part_number, etag} ->
  #       "<Part><PartNumber>#{part_number}</PartNumber><ETag>#{etag}</ETag></Part>"
  #     end)

  #   req =
  #     LibOss.Request.new(
  #       method: :post,
  #       object: object,
  #       resource: Path.join(["/", bucket, object]),
  #       sub_resources: [{"uploadId", upload_id}],
  #       bucket: bucket,
  #       body: "<CompleteMultipartUpload>#{body}</CompleteMultipartUpload>",
  #       headers: headers
  #     )

  #   request(client, req)
  # end

  # @doc """
  # ListParts接口用于列举指定Upload ID所属的所有已经上传成功Part。

  # Doc: https://help.aliyun.com/document_detail/31998.html

  # ## Examples

  #     {:ok, return_value} = function_name()
  #     iex> LibOss.list_parts(cli, bucket, "test.txt", "upload_id")
  #     {:ok,
  #      %{
  #       "ListPartsResult" => %{
  #         "Bucket" => "hope-data",
  #         "IsTruncated" => "false",
  #         "Key" => "test/multi-test.txt",
  #         "MaxParts" => "1000",
  #         "NextPartNumberMarker" => "3",
  #         "Part" => [
  #           %{
  #             "ETag" => "\"3170FC594DACE56C506E0196B5DEA1D1\"",
  #             "HashCrc64ecma" => "10873275732915280589",
  #             "LastModified" => "2023-07-19T02:58:16.000Z",
  #             "PartNumber" => "1",
  #             "Size" => "136536"
  #           },
  #           %{
  #             "ETag" => "\"5539D60A05FD504B8210A662D7D15C1E\"",
  #             "HashCrc64ecma" => "4592881501542342075",
  #             "LastModified" => "2023-07-19T02:58:17.000Z",
  #             "PartNumber" => "2",
  #             "Size" => "136536"
  #           },
  #           %{
  #             "ETag" => "\"5C7D509F5744115EE3B2D55F4893FE3F\"",
  #             "HashCrc64ecma" => "9048307046109329978",
  #             "LastModified" => "2023-07-19T02:58:17.000Z",
  #             "PartNumber" => "3",
  #             "Size" => "136536"
  #           }
  #         ],
  #         "PartNumberMarker" => "0",
  #         "StorageClass" => "Standard",
  #         "UploadId" => "39663F02E9384C87BFC9E9B0E8B1100E"
  #       }
  #     }}
  # """
  # @spec list_parts(
  #         t(),
  #         Typespecs.bucket(),
  #         Typespecs.object(),
  #         String.t(),
  #         Typespecs.params()
  #       ) :: {:ok, Typespecs.string_dict()} | {:error, Exception.t()}
  # def list_parts(client, bucket, object, upload_id, query_params \\ %{}) do
  #   req =
  #     LibOss.Request.new(
  #       method: :get,
  #       object: object,
  #       resource: Path.join(["/", bucket, object]),
  #       sub_resources: [{"uploadId", upload_id}],
  #       bucket: bucket,
  #       params: query_params
  #     )

  #   client
  #   |> request(req)
  #   |> case do
  #     {:ok, %Http.Response{body: body}} ->
  #       {:ok, XmlToMap.naive_map(body)}

  #     err ->
  #       err
  #   end
  # end

  # @doc """
  # GetBucket (ListObjects)接口用于列举存储空间（Bucket）中所有文件（Object）的信息。

  # Doc: https://help.aliyun.com/document_detail/31965.html

  # 其中query_params具体细节参考上面链接中`请求参数`部分

  # ## Examples

  #     iex> LibOss.get_bucket(cli, bucket, %{"prefix" => "test/test"})
  #     {:ok, [
  #       %{
  #        "ETag" => "\"A5D2B2E40EF7EBA1C788697D31C27A78-3\"",
  #        "Key" => "test/test.txt",
  #        "LastModified" => "2023-07-09T14:41:08.000Z",
  #        "Owner" => %{
  #          "DisplayName" => "1074124462684153",
  #          "ID" => "1074124462684153"
  #        },
  #        "Size" => "409608",
  #        "StorageClass" => "Standard",
  #        "Type" => "Multipart"
  #      },
  #      %{
  #        "ETag" => "\"5EB63BBBE01EEED093CB22BB8F5ACDC3\"",
  #        "Key" => "test/test_1.txt",
  #        "LastModified" => "2023-07-09T14:41:08.000Z",
  #        "Owner" => %{
  #          "DisplayName" => "1074124462684153",
  #          "ID" => "1074124462684153"
  #        },
  #        "Size" => "11",
  #        "StorageClass" => "Standard",
  #        "Type" => "Normal"
  #      }
  #     ]}
  # """
  # @spec get_bucket(t(), Typespecs.bucket(), Typespecs.params()) ::
  #         {:ok, [any()]} | {:error, Exception.t()}
  # def get_bucket(client, bucket, query_params) do
  #   [method: :get, bucket: bucket, resource: "/" <> bucket <> "/", params: query_params]
  #   |> LibOss.Request.new()
  #   |> then(&request(client, &1))
  #   |> case do
  #     {:ok, %Http.Response{body: body}} ->
  #       body
  #       |> XmlToMap.naive_map()
  #       |> case do
  #         %{"ListBucketResult" => %{"Contents" => ret}} ->
  #           {:ok, ret}

  #         _ ->
  #           {:error, Exception.new("invalid response", body)}
  #       end

  #     err ->
  #       err
  #   end
  # end

  # @doc """
  # ListObjectsV2（GetBucketV2）接口用于列举存储空间（Bucket）中所有文件（Object）的信息。

  # Doc: https://help.aliyun.com/document_detail/187544.html

  # ## Examples

  #     iex> LibOss.list_object_v2(cli, bucket, %{"prefix" => "test/test"})
  #     {:ok,
  #      [
  #        %{
  #          "ETag" => "\"A5D2B2E40EF7EBA1C788697D31C27A78-3\"",
  #          "Key" => "test/test.txt",
  #          "LastModified" => "2023-07-09T14:41:08.000Z",
  #          "Owner" => %{
  #            "DisplayName" => "1074124462684153",
  #            "ID" => "1074124462684153"
  #          },
  #          "Size" => "409608",
  #          "StorageClass" => "Standard",
  #          "Type" => "Multipart"
  #        },
  #        %{
  #          "ETag" => "\"5EB63BBBE01EEED093CB22BB8F5ACDC3\"",
  #          "Key" => "test/test_1.txt",
  #          "LastModified" => "2023-07-09T14:41:08.000Z",
  #          "Owner" => %{
  #            "DisplayName" => "1074124462684153",
  #            "ID" => "1074124462684153"
  #          },
  #          "Size" => "11",
  #          "StorageClass" => "Standard",
  #          "Type" => "Normal"
  #        }
  #      ]}
  # """
  # @spec list_object_v2(t(), Typespecs.bucket(), Typespecs.params()) ::
  #         {:ok, [any()]} | {:error, Exception.t()}
  # def list_object_v2(client, bucket, query_params) do
  #   [method: :get, bucket: bucket, resource: "/" <> bucket <> "/", params: Map.put(query_params, "list-type", "2")]
  #   |> LibOss.Request.new()
  #   |> then(&request(client, &1))
  #   |> case do
  #     {:ok, %Http.Response{body: body}} ->
  #       ret =
  #         body
  #         |> XmlToMap.naive_map()
  #         |> case do
  #           %{"ListBucketResult" => %{"Contents" => ret}} -> {:ok, ret}
  #           _ -> {:error, Exception.new("invalid response", body)}
  #         end

  #       {:ok, ret}

  #     err ->
  #       err
  #   end
  # end

  # @doc """
  # 调用GetBucketInfo接口查看存储空间（Bucket）的相关信息。

  # Doc: https://help.aliyun.com/document_detail/31968.html

  # ## Examples

  #     iex> LibOss.get_bucket_info(cli, bucket)
  #     {:ok,
  #      %{
  #        "Bucket" => %{
  #          "AccessControlList" => %{"Grant" => "public-read"},
  #          "AccessMonitor" => "Disabled",
  #          "BucketPolicy" => %{"LogBucket" => nil, "LogPrefix" => nil},
  #          "Comment" => nil,
  #          "CreationDate" => "2022-08-02T14:59:56.000Z",
  #          "CrossRegionReplication" => "Disabled",
  #          "DataRedundancyType" => "LRS",
  #          "ExtranetEndpoint" => "oss-cn-shenzhen.aliyuncs.com",
  #          "IntranetEndpoint" => "oss-cn-shenzhen-internal.aliyuncs.com",
  #          "Location" => "oss-cn-shenzhen",
  #          "Name" => "xxxx-data",
  #          "Owner" => %{
  #            "DisplayName" => "1074124462684153",
  #            "ID" => "1074124462684153"
  #          },
  #          "ResourceGroupId" => "rg-acfmv47nudzpp6i",
  #          "ServerSideEncryptionRule" => %{"SSEAlgorithm" => "None"},
  #          "StorageClass" => "Standard",
  #          "TransferAcceleration" => "Enabled"
  #        }
  #      }}
  # """
  # @spec get_bucket_info(t(), Typespecs.bucket()) :: {:ok, any()} | {:error, Exception.t()}
  # def get_bucket_info(client, bucket) do
  #   [method: :get, bucket: bucket, resource: "/" <> bucket <> "/", sub_resources: [{"bucketInfo", nil}]]
  #   |> LibOss.Request.new()
  #   |> then(&request(client, &1))
  #   |> case do
  #     {:ok, %Http.Response{body: body}} ->
  #       body
  #       |> XmlToMap.naive_map()
  #       |> case do
  #         %{"BucketInfo" => ret} -> {:ok, ret}
  #         _ -> {:error, Exception.new("invalid response", body)}
  #       end

  #     err ->
  #       err
  #   end
  # end

  # @doc """
  # GetBucketLocation接口用于查看存储空间（Bucket）的位置信息。

  # Doc: https://help.aliyun.com/document_detail/31967.html

  # ## Examples

  #     iex> LibOss.get_bucket_location(cli, bucket)
  #     {:ok, "oss-cn-shenzhen"}
  # """
  # @spec get_bucket_location(t(), Typespecs.bucket()) ::
  #         {:ok, Typespecs.bucket()} | {:error, Exception.t()}
  # def get_bucket_location(client, bucket) do
  #   [method: :get, bucket: bucket, resource: "/" <> bucket <> "/", sub_resources: [{"location", nil}]]
  #   |> LibOss.Request.new()
  #   |> then(&request(client, &1))
  #   |> case do
  #     {:ok, %Http.Response{body: body}} ->
  #       body
  #       |> XmlToMap.naive_map()
  #       |> case do
  #         %{"LocationConstraint" => ret} -> {:ok, ret}
  #         _ -> {:error, Exception.new("invalid response", body)}
  #       end

  #     err ->
  #       err
  #   end
  # end

  # @doc """
  # 调用GetBucketStat接口获取指定存储空间（Bucket）的存储容量以及文件（Object）数量。

  # Doc: https://help.aliyun.com/document_detail/426056.html

  # ## Examples

  #     iex> LibOss.get_bucket_stat(cli, bucket)
  #     {:ok, {:ok,
  #      %{
  #        "ArchiveObjectCount" => "0",
  #        "ArchiveRealStorage" => "0",
  #        "ArchiveStorage" => "0",
  #        "ColdArchiveObjectCount" => "0",
  #        "ColdArchiveRealStorage" => "0",
  #        "ColdArchiveStorage" => "0",
  #        "DeepColdArchiveObjectCount" => "0",
  #        "DeepColdArchiveRealStorage" => "0",
  #        "DeepColdArchiveStorage" => "0",
  #        "DeleteMarkerCount" => "0",
  #        "InfrequentAccessObjectCount" => "0",
  #        "InfrequentAccessRealStorage" => "0",
  #        "InfrequentAccessStorage" => "0",
  #        "LastModifiedTime" => "1690118142",
  #        "LiveChannelCount" => "0",
  #        "MultipartPartCount" => "59",
  #        "MultipartUploadCount" => "30",
  #        "ObjectCount" => "5413",
  #        "ReservedCapacityObjectCount" => "0",
  #        "ReservedCapacityStorage" => "0",
  #        "StandardObjectCount" => "5413",
  #        "StandardStorage" => "9619258561",
  #        "Storage" => "9619258561"
  #      }}
  # """
  # @spec get_bucket_stat(t(), Typespecs.bucket()) ::
  #         {:ok, Typespecs.string_dict()} | {:error, Exception.t()}
  # def get_bucket_stat(client, bucket) do
  #   [method: :get, bucket: bucket, resource: "/" <> bucket <> "/", sub_resources: [{"stat", nil}]]
  #   |> LibOss.Request.new()
  #   |> then(&request(client, &1))
  #   |> case do
  #     {:ok, %Http.Response{body: body}} ->
  #       body
  #       |> XmlToMap.naive_map()
  #       |> case do
  #         %{"BucketStat" => ret} -> {:ok, ret}
  #         _ -> {:error, Exception.new("invalid response", body)}
  #       end

  #     err ->
  #       err
  #   end
  # end

  # @doc """
  # PutBucketAcl接口用于设置或修改存储空间（Bucket）的访问权限（ACL）。

  # Doc: https://help.aliyun.com/document_detail/31960.html

  # ## Examples

  #     iex> LibOss.put_bucket_acl(cli, bucket, "public-read")
  # """
  # @spec put_bucket_acl(t(), Typespecs.bucket(), Typespecs.acl()) ::
  #         {:ok, any()} | {:error, Exception.t()}
  # def put_bucket_acl(client, bucket, acl) do
  #   unless acl in ["private", "public-read", "public-read-write"] do
  #     raise ArgumentError, "invalid acl: #{acl}"
  #   end

  #   [
  #     method: :put,
  #     bucket: bucket,
  #     resource: "/" <> bucket <> "/",
  #     sub_resources: [{"acl", nil}],
  #     headers: [{"x-oss-acl", acl}]
  #   ]
  #   |> LibOss.Request.new()
  #   |> then(&request(client, &1))
  # end

  # @doc """
  # GetBucketAcl接口用于获取某个存储空间（Bucket）的访问权限（ACL）。

  # Doc: https://help.aliyun.com/document_detail/31966.html

  # ## Examples

  #     iex> LibOss.get_bucket_acl(cli, bucket)
  #     {:ok,
  #     %{
  #        "AccessControlList" => %{"Grant" => "public-read"},
  #        "Owner" => %{"DisplayName" => "107412446268415", "ID" => "107412446264153"}
  #      }}
  # """
  # @spec get_bucket_acl(t(), Typespecs.bucket()) ::
  #         {:ok, Typespecs.string_dict()} | {:error, Exception.t()}
  # def get_bucket_acl(client, bucket) do
  #   [method: :get, bucket: bucket, resource: "/" <> bucket <> "/", sub_resources: [{"acl", nil}]]
  #   |> LibOss.Request.new()
  #   |> then(&request(client, &1))
  #   |> case do
  #     {:ok, %Http.Response{body: body}} ->
  #       body
  #       |> XmlToMap.naive_map()
  #       |> case do
  #         %{"AccessControlPolicy" => ret} -> {:ok, ret}
  #         _ -> {:error, Exception.new("invalid response", body)}
  #       end

  #     err ->
  #       err
  #   end
  # end
end
