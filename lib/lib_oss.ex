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

      defp delegate_token(method, args), do: apply(LibOss.Core.Token, method, [__MODULE__ | args])
      defp delegate_object(method, args), do: apply(LibOss.Core.Object, method, [__MODULE__ | args])
      defp delegate_acl(method, args), do: apply(LibOss.Core.Acl, method, [__MODULE__ | args])
      defp delegate_symlink(method, args), do: apply(LibOss.Core.Symlink, method, [__MODULE__ | args])
      defp delegate_tagging(method, args), do: apply(LibOss.Core.Tagging, method, [__MODULE__ | args])
      defp delegate_bucket(method, args), do: apply(LibOss.Core.Bucket, method, [__MODULE__ | args])
      defp delegate_multipart(method, args), do: apply(LibOss.Core.Multipart, method, [__MODULE__ | args])

      # ============================================================================
      # Web上传令牌生成API
      # ============================================================================

      @doc """
      通过Web端直传文件（Object）到OSS的签名生成

      Doc: https://help.aliyun.com/document_detail/31926.html

      ## Examples

          iex> get_token(bucket, "/test/test.txt")
          {:ok, "{\"accessid\":\"LTAI1k8kxWG8JpUF\",\"callback\":\"=\",\"dir\":\"/test/test.txt\",\".........ePNPyWQo=\"}"}
      """
      @spec get_token(Typespecs.bucket(), Typespecs.object(), non_neg_integer(), binary()) ::
              {:ok, binary()} | err_t()
      def get_token(bucket, object, expire_sec \\ 3600, callback \\ "") do
        delegate_token(:get_token, [bucket, object, expire_sec, callback])
      end

      # ============================================================================
      # 对象操作API
      # ============================================================================

      @doc """
      调用PutObject接口上传文件（Object）。

      Doc: https://help.aliyun.com/document_detail/31978.html

      ## Examples

          iex> put_object(bucket, "/test/test.txt", "hello world")
          :ok
      """
      @spec put_object(Typespecs.bucket(), Typespecs.object(), iodata(), Typespecs.headers()) :: :ok | err_t()
      def put_object(bucket, object, data, headers \\ []) do
        delegate_object(:put_object, [bucket, object, data, headers])
      end

      @doc """
      GetObject接口用于获取某个文件（Object）。此操作需要对此Object具有读权限。

      Doc: https://help.aliyun.com/document_detail/31980.html

      req_headers的具体参数可参考文档中"请求头"部分说明

      ## Examples

          iex> get_object(bucket, "/test/test.txt")
          {:ok, "hello world"}
      """
      @spec get_object(Typespecs.bucket(), Typespecs.object(), Typespecs.headers()) :: {:ok, binary()} | err_t()
      def get_object(bucket, object, req_headers \\ []) do
        delegate_object(:get_object, [bucket, object, req_headers])
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
        delegate_object(:copy_object, [bucket, object, source_bucket, source_object, headers])
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
        delegate_object(:delete_object, [bucket, object])
      end

      @doc """
      DeleteMultipleObjects接口用于删除同一个存储空间（Bucket）中的多个文件（Object）。

      Doc: https://help.aliyun.com/document_detail/31983.html

      ## Examples

          iex> delete_multiple_objects(bucket, ["/test/test_1.txt", "/test/test_2.txt"])
          :ok
      """
      @spec delete_multiple_objects(Typespecs.bucket(), [Typespecs.object()]) :: :ok | err_t()
      def delete_multiple_objects(bucket, objects) do
        delegate_object(:delete_multiple_objects, [bucket, objects])
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
            ) :: :ok | err_t()
      def append_object(bucket, object, since, data, headers \\ []) do
        delegate_object(:append_object, [bucket, object, since, data, headers])
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
        delegate_object(:head_object, [bucket, object, headers])
      end

      @doc """
      GetObjectMeta接口用于获取某个文件（Object）的基本元信息，包括该Object的ETag、Size、LastModified信息，并不返回该Object的内容。

      Doc: https://help.aliyun.com/document_detail/31985.html

      ## Examples

          iex> get_object_meta(bucket, "/test/test.txt")
          {:ok,
           %{
             "connection" => "keep-alive",
             "content-length" => "11",
             "date" => "Tue, 18 Jul 2023 06:27:36 GMT",
             "etag" => "\"5EB63BBBE01EEED093CB22BB8F5ACDC3\"",
             "last-modified" => "Tue, 18 Jul 2023 06:27:33 GMT",
             "server" => "AliyunOSS",
             "x-oss-request-id" => "64B630D8E0DCB93335001975"
           }}
      """
      @spec get_object_meta(Typespecs.bucket(), Typespecs.object()) ::
              {:ok, Typespecs.dict()} | err_t()
      def get_object_meta(bucket, object) do
        delegate_object(:get_object_meta, [bucket, object])
      end

      # ============================================================================
      # ACL管理API
      # ============================================================================

      @doc """
      调用PutObjectACL接口修改文件（Object）的访问权限（ACL）。

      Doc: https://help.aliyun.com/document_detail/31986.html

      ## Examples

          iex> put_object_acl(bucket, "/test/test.txt", "public-read")
          :ok
      """
      @spec put_object_acl(Typespecs.bucket(), Typespecs.object(), String.t()) :: :ok | err_t()
      def put_object_acl(bucket, object, acl) do
        delegate_acl(:put_object_acl, [bucket, object, acl])
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
        delegate_acl(:get_object_acl, [bucket, object])
      end

      # ============================================================================
      # 符号链接API
      # ============================================================================

      @doc """
      调用PutSymlink接口用于为OSS的目标文件（TargetObject）创建软链接（Symlink）

      Doc: https://help.aliyun.com/document_detail/45126.html

      ## Examples

          iex> put_symlink(bucket, "/test/test.txt", "/test/test_symlink.txt")
          :ok
      """
      @spec put_symlink(Typespecs.bucket(), Typespecs.object(), String.t(), Typespecs.headers()) ::
              :ok | err_t()
      def put_symlink(bucket, object, target_object, headers \\ []) do
        delegate_symlink(:put_symlink, [bucket, object, target_object, headers])
      end

      @doc """
      调用GetSymlink接口获取软链接。

      Doc: https://help.aliyun.com/document_detail/45146.html

      ## Examples

          iex> get_symlink(bucket, "/test/test.txt")
          {:ok, "/test/test_symlink.txt"}
      """
      @spec get_symlink(Typespecs.bucket(), Typespecs.object()) ::
              {:ok, binary()} | err_t()
      def get_symlink(bucket, object) do
        delegate_symlink(:get_symlink, [bucket, object])
      end

      # ============================================================================
      # 标签管理API
      # ============================================================================

      @doc """
      调用PutObjectTagging接口设置或更新对象（Object）的标签（Tagging）信息。

      Doc: https://help.aliyun.com/document_detail/114855.html

      ## Examples

          iex> put_object_tagging(bucket, "/test/test.txt", %{"key1" => "value1", "key2" => "value2"})
          :ok
      """
      @spec put_object_tagging(Typespecs.bucket(), Typespecs.object(), Typespecs.tags()) ::
              :ok | err_t()
      def put_object_tagging(bucket, object, tags) do
        delegate_tagging(:put_object_tagging, [bucket, object, tags])
      end

      @doc """
      调用GetObjectTagging接口获取对象（Object）的标签（Tagging）信息。

      Doc: https://help.aliyun.com/document_detail/114878.html

      ## Examples

          iex> get_object_tagging(bucket, "/test/test.txt")
          {:ok,
           [
             %{"Key" => "key1", "Value" => "value1"},
             %{"Key" => "key2", "Value" => "value2"}
           ]}
      """
      @spec get_object_tagging(Typespecs.bucket(), Typespecs.object()) ::
              {:ok, Typespecs.dict()} | err_t()
      def get_object_tagging(bucket, object) do
        delegate_tagging(:get_object_tagging, [bucket, object])
      end

      @doc """
      删除Object当前版本的标签信息。

      Doc: https://help.aliyun.com/document_detail/114879.html

      ## Examples

          iex> delete_object_tagging(bucket, "/test/test.txt")
          :ok
      """
      @spec delete_object_tagging(Typespecs.bucket(), Typespecs.object()) ::
              :ok | err_t()
      def delete_object_tagging(bucket, object) do
        delegate_tagging(:delete_object_tagging, [bucket, object])
      end

      # ============================================================================
      # 存储桶操作API
      # ============================================================================

      @doc """
      调用PutBucket接口创建存储空间（Bucket）。

      Doc: https://help.aliyun.com/document_detail/31959.html

      ## Examples

          iex> put_bucket(your-new-bucket)
          :ok
      """
      @spec put_bucket(Typespecs.bucket(), String.t(), String.t(), Typespecs.headers()) :: :ok | err_t()
      def put_bucket(bucket, storage_class \\ "Standard", data_redundancy_type \\ "LRS", headers \\ []) do
        delegate_bucket(:put_bucket, [bucket, storage_class, data_redundancy_type, headers])
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
        delegate_bucket(:delete_bucket, [bucket])
      end

      @doc """
      GetBucket (ListObjects)接口用于列举存储空间（Bucket）中所有文件（Object）的信息。

      Doc: https://help.aliyun.com/document_detail/31965.html

      其中query_params具体细节参考上面链接中`请求参数`部分

      ## Examples

          iex> get_bucket(bucket, %{"prefix" => "test/test"})
          {:ok, [
            %{
             "ETag" => "\"A5D2B2E40EF7EBA1C788697D31C27A78-3\"",
             "Key" => "test/test.txt",
             "LastModified" => "2023-07-09T14:41:08.000Z",
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
             "Key" => "test/test_1.txt",
             "LastModified" => "2023-07-09T14:41:08.000Z",
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
      @spec get_bucket(Typespecs.bucket(), Typespecs.params()) ::
              {:ok, list(Typespecs.dict())} | err_t()
      def get_bucket(bucket, query_params) do
        delegate_bucket(:get_bucket, [bucket, query_params])
      end

      @doc """
      ListObjectsV2（GetBucketV2）接口用于列举存储空间（Bucket）中所有文件（Object）的信息。

      Doc: https://help.aliyun.com/document_detail/187544.html

      ## Examples

          iex> list_object_v2(bucket, %{"prefix" => "test/test"})
          {:ok,
           [
             %{
               "ETag" => "\"A5D2B2E40EF7EBA1C788697D31C27A78-3\"",
               "Key" => "test/test.txt",
               "LastModified" => "2023-07-09T14:41:08.000Z",
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
               "Key" => "test/test_1.txt",
               "LastModified" => "2023-07-09T14:41:08.000Z",
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
      @spec list_object_v2(Typespecs.bucket(), Typespecs.params()) ::
              {:ok, list(Typespecs.dict())} | err_t()
      def list_object_v2(bucket, query_params) do
        delegate_bucket(:list_object_v2, [bucket, query_params])
      end

      @doc """
      调用GetBucketInfo接口获取某个存储空间（Bucket）的相关信息。

      Doc: https://help.aliyun.com/document_detail/31968.html

      ## Examples

          iex> get_bucket_info(bucket)
          {:ok,
           %{
             "BucketInfo" => %{
               "Bucket" => %{
                 "AccessControlList" => %{"Grant" => "private"},
                 "CreationDate" => "2023-07-07T12:57:30.000Z",
                 "ExtranetEndpoint" => "oss-cn-beijing.aliyuncs.com",
                 "IntranetEndpoint" => "oss-cn-beijing-internal.aliyuncs.com",
                 "Location" => "oss-cn-beijing",
                 "Name" => "test-bucket",
                 "Owner" => %{"DisplayName" => "1074124462684153", "ID" => "1074124462684153"},
                 "StorageClass" => "Standard"
               }
             }
           }}
      """
      @spec get_bucket_info(Typespecs.bucket()) :: {:ok, Typespecs.dict()} | err_t()
      def get_bucket_info(bucket) do
        delegate_bucket(:get_bucket_info, [bucket])
      end

      @doc """
      调用GetBucketLocation接口获取存储空间（Bucket）的位置信息。

      Doc: https://help.aliyun.com/document_detail/31967.html

      ## Examples

          iex> get_bucket_location(bucket)
          {:ok, "oss-cn-beijing"}
      """
      @spec get_bucket_location(Typespecs.bucket()) ::
              {:ok, binary()} | err_t()
      def get_bucket_location(bucket) do
        delegate_bucket(:get_bucket_location, [bucket])
      end

      @doc """
      调用GetBucketStat接口获取指定存储空间（Bucket）的存储容量以及文件（Object）数量。

      Doc: https://help.aliyun.com/document_detail/47572.html

      ## Examples

          iex> get_bucket_stat(bucket)
          {:ok,
           %{
             "BucketStat" => %{
               "LastModifiedTime" => "1689855033",
               "ObjectCount" => "7",
               "Storage" => "1001100",
               "StandardStorage" => "1001100"
             }
           }}
      """
      @spec get_bucket_stat(Typespecs.bucket()) ::
              {:ok, Typespecs.dict()} | err_t()
      def get_bucket_stat(bucket) do
        delegate_bucket(:get_bucket_stat, [bucket])
      end

      @doc """
      调用PutBucketAcl接口设置或修改存储空间（Bucket）的访问权限（ACL）。

      Doc: https://help.aliyun.com/document_detail/31976.html

      ## Examples

          iex> put_bucket_acl(bucket, "public-read")
          :ok
      """
      @spec put_bucket_acl(Typespecs.bucket(), String.t()) :: :ok | err_t()
      def put_bucket_acl(bucket, acl) do
        delegate_acl(:put_bucket_acl, [bucket, acl])
      end

      @doc """
      调用GetBucketAcl接口获取某个存储空间（Bucket）的访问权限（ACL）。

      Doc: https://help.aliyun.com/document_detail/31975.html

      ## Examples

          iex> get_bucket_acl(bucket)
          {:ok, "public-read"}
      """
      @spec get_bucket_acl(Typespecs.bucket()) ::
              {:ok, binary()} | err_t()
      def get_bucket_acl(bucket) do
        delegate_acl(:get_bucket_acl, [bucket])
      end

      # ============================================================================
      # 多部分上传API
      # ============================================================================

      @doc """
      使用Multipart Upload模式传输数据前，您必须先调用InitiateMultipartUpload接口来通知OSS初始化一个Multipart Upload事件。

      Doc: https://help.aliyun.com/document_detail/31992.html

      ## Examples

          iex> init_multi_upload(bucket, "test.txt")
          {:ok, "upload_id"}
      """
      @spec init_multi_upload(
              Typespecs.bucket(),
              Typespecs.object(),
              Typespecs.headers()
            ) ::
              {:ok, Typespecs.upload_id()} | err_t()
      def init_multi_upload(bucket, object, req_headers \\ []) do
        delegate_multipart(:init_multi_upload, [bucket, object, req_headers])
      end

      @doc """
      初始化一个MultipartUpload后，调用UploadPart接口根据指定的Object名和uploadId来分块（Part）上传数据。

      Doc: https://help.aliyun.com/document_detail/31993.html

      ## Examples

          iex> upload_part(bucket, "test.txt", "upload_id", 1, "hello world")
          {:ok, "etag"}
      """
      @spec upload_part(
              Typespecs.bucket(),
              Typespecs.object(),
              Typespecs.upload_id(),
              Typespecs.part_num(),
              binary()
            ) ::
              {:ok, Typespecs.etag()} | err_t()
      def upload_part(bucket, object, upload_id, part_number, data) do
        delegate_multipart(:upload_part, [bucket, object, upload_id, part_number, data])
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
      @spec list_multipart_uploads(Typespecs.bucket(), Typespecs.params()) ::
              {:ok, list(Typespecs.dict())} | err_t()
      def list_multipart_uploads(bucket, query_params) do
        delegate_multipart(:list_multipart_uploads, [bucket, query_params])
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
              Typespecs.bucket(),
              Typespecs.object(),
              Typespecs.upload_id(),
              [{Typespecs.part_num(), Typespecs.etag()}],
              Typespecs.headers()
            ) :: :ok | err_t()
      def complete_multipart_upload(bucket, object, upload_id, parts, headers \\ []) do
        delegate_multipart(:complete_multipart_upload, [bucket, object, upload_id, parts, headers])
      end

      @doc """
      AbortMultipartUpload接口用于取消MultipartUpload事件并删除对应的Part数据。

      Doc: https://help.aliyun.com/document_detail/31996.html

      ## Examples

          iex> abort_multipart_upload(bucket, "test.txt", "upload_id")
          :ok
      """
      @spec abort_multipart_upload(
              Typespecs.bucket(),
              Typespecs.object(),
              Typespecs.upload_id()
            ) :: :ok | err_t()
      def abort_multipart_upload(bucket, object, upload_id) do
        delegate_multipart(:abort_multipart_upload, [bucket, object, upload_id])
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
              Typespecs.bucket(),
              Typespecs.object(),
              Typespecs.upload_id(),
              Typespecs.params()
            ) ::
              {:ok, list(Typespecs.dict())} | err_t()
      def list_parts(bucket, object, upload_id, query_params \\ %{}) do
        delegate_multipart(:list_parts, [bucket, object, upload_id, query_params])
      end
    end
  end
end
