defmodule Open890.RadioConnectionRepo do
  @select_all [{:"$1", [], [:"$1"]}]

  require Logger

  alias Open890.RadioConnection
  alias Uniq.UUID

  def all do
    table_name()
    |> :dets.select(@select_all)
    |> Enum.map(fn {_id, conn} -> conn end)
  end

  def find(id) do
    table_name()
    |> :dets.lookup(id)
    |> case do
      [
        {
          ^id,
          %RadioConnection{} = conn
        }
      ] ->
        {:ok, conn}

      _ ->
        {:error, :not_found}
    end
  end

  def all_raw do
    table_name()
    |> :dets.select(@select_all)
  end

  def init do
    Logger.debug("RadioConnectionRepo.init()")

    if !File.exists?("db/") do
      Logger.debug("db/ directory doesn't exist, creating")
      File.mkdir!("db")
    else
      Logger.debug("db/ exists, skipping")
    end

    {:ok, table} = :dets.open_file(table_name(), type: :set)
    {:ok, table}
  end

  def close do
    Logger.info("Closing dets table: #{table_name()}")
    :ok = :dets.close(table_name())
  end

  def destroy_repo!(opts \\ []) do
    forced = opts |> Keyword.get(:force, false)

    if forced do
      Logger.warn("Forcefully destroying database: #{table_name()}")
      :ok = File.rm!(table_name() |> to_string())
    else
      Logger.info(
        "destroy_repo!: force: true was not passed, not destroying table #{table_name()}"
      )
    end
  end

  def insert(
        %{
          "name" => name,
          "ip_address" => ip_address,
          "tcp_port" => tcp_port,
          "user_name" => user_name,
          "password" => password,
          "auto_start" => auto_start,
          "user_is_admin" => user_is_admin,
          "cloudlog_enabled" => cloudlog_enabled,
          "cloudlog_url" => cloudlog_url,
          "cloudlog_api_key" => cloudlog_api_key
        } = _params
      ) do
    %RadioConnection{
      id: nil,
      type: :tcp,
      name: name,
      ip_address: ip_address,
      tcp_port: tcp_port,
      auto_start: auto_start,
      user_name: user_name,
      password: password,
      user_is_admin: user_is_admin,
      cloudlog_enabled: cloudlog_enabled,
      cloudlog_url: cloudlog_url |> to_string() |> String.trim() |> String.trim_trailing("/"),
      cloudlog_api_key: cloudlog_api_key |> to_string() |> String.trim(),
      user_markers: []
    }
    |> insert()
  end

  def insert(%RadioConnection{id: nil} = conn) do
    id = UUID.uuid4()
    conn = %{conn | id: id}

    table_name()
    |> :dets.insert_new({id, conn})
    |> case do
      true -> {:ok, conn}
      _ -> {:error, :dets_key_exists}
    end
  end

  def update(%RadioConnection{id: id} = conn) when not is_nil(id) do
    conn |> IO.inspect(label: "ConnectionRepo.update, conn")
    table_name() |> :dets.insert({id, conn})
  end

  def delete(%RadioConnection{id: id} = _conn) do
    id |> __delete()
  end

  def count do
    table_name()
    |> :dets.info()
    |> Keyword.get(:count) || 0
  end

  def __delete(id) do
    table_name() |> :dets.delete(id)
  end

  def delete_all do
    table_name() |> :dets.delete_all_objects()
  end

  defp table_name do
    :open890
    |> Application.get_env(Open890.RadioConnectionRepo)
    |> Keyword.fetch!(:database)
  end
end
