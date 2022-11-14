defmodule ExRabbitMQAdmin.VHostTest do
  use ExRabbitMQAdmin.TestCase, async: true
  import ExUnit.CaptureLog

  alias ExRabbitMQAdmin.VHost

  setup do
    mock(fn
      %{method: :get, url: "https://rabbitmq.example.com:5672/api/vhosts"} ->
        %Tesla.Env{status: 200, body: read_json("list_vhosts.json")}

      %{method: :get, url: "https://rabbitmq.example.com:5672/api/vhosts/my-vhost"} ->
        %Tesla.Env{status: 200, body: read_json("get_vhost.json")}

      %{method: :get, url: "https://rabbitmq.example.com:5672/api/vhosts/my-vhost/connections"} ->
        %Tesla.Env{status: 200}

      %{method: :get, url: "https://rabbitmq.example.com:5672/api/vhosts/my-vhost/permissions"} ->
        %Tesla.Env{status: 200, body: read_json("get_vhost_permissions.json")}

      %{
        method: :get,
        url: "https://rabbitmq.example.com:5672/api/vhosts/my-vhost/topic-permissions"
      } ->
        %Tesla.Env{status: 200}

      %{method: :put, url: "https://rabbitmq.example.com:5672/api/vhosts/my-vhost"} ->
        %Tesla.Env{status: 204}

      %{method: :delete, url: "https://rabbitmq.example.com:5672/api/vhosts/my-vhost"} ->
        %Tesla.Env{status: 204}

      %{
        method: :post,
        url: "https://rabbitmq.example.com:5672/api/vhosts/my-vhost/start/rabbit@rabbitmq"
      } ->
        %Tesla.Env{status: 204}
    end)
  end

  test "can list vhosts" do
    assert {:ok, %Tesla.Env{status: 200, body: [%{"name" => "/"}, %{"name" => "my-vhost"}]}} =
             Client.client() |> VHost.list_vhosts()
  end

  test "can get a single vhost by name" do
    assert {:ok,
            %Tesla.Env{
              status: 200,
              body: %{
                "cluster_state" => %{"rabbit@rabbitmq" => "running"},
                "default_queue_type" => "undefined",
                "description" => "a vhost for myself",
                "metadata" => %{
                  "description" => "a vhost for myself",
                  "tags" => ["personal", "other-tag"]
                },
                "name" => "my-vhost",
                "tags" => ["personal", "other-tag"],
                "tracing" => false
              }
            }} = Client.client() |> VHost.get_vhost("my-vhost")
  end

  test "can list vhost connections" do
    assert {:ok, %Tesla.Env{status: 200}} =
             Client.client() |> VHost.list_vhost_connections("my-vhost")

    {result, log} =
      with_log(fn ->
        Client.client() |> VHost.list_vhost_connections("my-vhost", page: 10, page_size: 50)
      end)

    assert {:ok, %Tesla.Env{status: 200}} = result
    assert log =~ "Query: use_regex: false\nQuery: page: 10\nQuery: page_size: 50"

    assert_raise ArgumentError,
                 "unknown options [:invalid_option], valid options are: [:page, :page_size, :name, :use_regex]",
                 fn ->
                   Client.client()
                   |> VHost.list_vhost_connections("my-vhost", invalid_option: true)
                 end
  end

  test "can list vhost channels" do
    assert {:ok, %Tesla.Env{status: 200}} =
             Client.client() |> VHost.list_vhost_channels("my-vhost")

    {result, log} =
      with_log(fn ->
        Client.client() |> VHost.list_vhost_channels("my-vhost", page: 10, page_size: 50)
      end)

    assert {:ok, %Tesla.Env{status: 200}} = result
    assert log =~ "Query: use_regex: false\nQuery: page: 10\nQuery: page_size: 50"

    assert_raise ArgumentError,
                 "unknown options [:invalid_option], valid options are: [:page, :page_size, :name, :use_regex]",
                 fn ->
                   Client.client()
                   |> VHost.list_vhost_channels("my-vhost", invalid_option: true)
                 end
  end

  test "can list vhost permissions" do
    assert {:ok,
            %Tesla.Env{
              status: 200,
              body: [
                %{
                  "configure" => ".*",
                  "read" => ".*",
                  "user" => "guest",
                  "vhost" => "my-vhost",
                  "write" => ".*"
                }
              ]
            }} = Client.client() |> VHost.list_vhost_permissions("my-vhost")
  end

  test "can list vhost topic permissions" do
    assert {:ok, %Tesla.Env{status: 200}} =
             Client.client() |> VHost.list_vhost_topic_permissions("my-vhost")
  end

  test "can put a new vhost" do
    assert {:ok, %Tesla.Env{status: 204}} =
             Client.client()
             |> VHost.put_vhost("my-vhost")

    assert {:ok, %Tesla.Env{status: 204}} =
             Client.client()
             |> VHost.put_vhost("my-vhost",
               description: "my fine virtual host",
               tags: "production"
             )

    assert_raise ArgumentError,
                 "unknown options [:invalid_option], valid options are: [:description, :tags]",
                 fn ->
                   Client.client() |> VHost.put_vhost("my-vhost", invalid_option: true)
                 end
  end

  test "can delete a vhost" do
    assert {:ok, %Tesla.Env{status: 204}} = Client.client() |> VHost.delete_vhost("my-vhost")
  end

  test "can start a vhost on node" do
    assert {:ok, %Tesla.Env{status: 204}} =
             Client.client() |> VHost.start_vhost("my-vhost", "rabbit@rabbitmq")
  end
end
