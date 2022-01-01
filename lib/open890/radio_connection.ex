defmodule Open890.RadioConnection do
  @moduledoc """
  Radio Connection Context Module
  """

  @derive {Inspect, except: [:password]}
  @default_tcp_port "60000"

  defstruct id: nil,
            name: nil,
            ip_address: nil,
            tcp_port: @default_tcp_port,
            user_name: nil,
            password: nil,
            user_is_admin: false,
            auto_start: true,
            type: nil

  require Logger

  alias Open890.RadioConnectionSupervisor
  alias Open890.RadioConnectionRepo, as: Repo

  def tcp_port(%__MODULE__{} = connection) do
    connection
    |> Map.get(:tcp_port, @default_tcp_port)
    |> case do
      "" -> @default_tcp_port
      str when is_binary(str) -> String.to_integer(str)
    end
  end

  def find(id) do
    id |> repo().find()
  end

  def all do
    repo().all()
  end

  def create(params) when is_map(params) do
    params |> repo().insert()
  end

  def delete_connection(%__MODULE__{id: id}) when is_integer(id) do
    id |> String.to_integer() |> delete_connection()
  end

  def delete_connection(id) do
    id |> repo().delete()
  end

  def delete_all do
    repo().delete_all()
  end

  def update_connection(%__MODULE__{} = conn, params) when is_map(params) do
    # TODO: this should use a changeset
    new_connection =
      conn
      |> Map.merge(%{
        name: params["name"],
        ip_address: params["ip_address"],
        tcp_port: params["tcp_port"],
        user_name: params["user_name"],
        password: params["password"],
        user_is_admin: params["user_is_admin"],
        auto_start: params["auto_start"]
      })

    new_connection |> repo().update()
  end

  def count_connections do
    repo().count()
  end

  def start(id) when is_integer(id) or is_binary(id) do
    with {:ok, conn} <- find(id) do
      conn |> start()
    end
  end

  def start(%__MODULE__{} = connection) do
    broadcast_connection_state(connection, :starting)

    connection
    |> RadioConnectionSupervisor.start_connection()
    |> case do
      {:ok, _pid} ->
        {:ok, connection}

      {:error, {:already_started, _pid}} ->
        {:error, :already_started}

      other ->
        other
    end
  end

  def stop(id) when is_integer(id) or is_binary(id) do
    with {:ok, conn} <- find(id) do
      conn |> stop()
    end
  end

  def stop(%__MODULE__{id: id} = connection) do
    Registry.lookup(:radio_connection_registry, {:tcp, id})
    |> case do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(RadioConnectionSupervisor, pid)
        broadcast_connection_state(connection, :stopped)

      _ ->
        Logger.debug("Unable to find process for connection id #{id}")
        {:error, :not_found}
    end
  end

  def cmd(%__MODULE__{} = connection, command) when is_binary(command) do
    connection
    |> get_connection_pid()
    |> case do
      {:ok, pid} ->
        pid |> cast_cmd(command)

      {:error, _reason} ->
        Logger.warn(
          "Unable to send command to connection #{inspect(connection)}, pid not found. Is the connection up?"
        )
    end

    connection
  end

  defp cast_cmd(pid, command) when is_pid(pid) and is_binary(command) do
    pid |> GenServer.cast({:send_command, command})
  end

  def process_exists?(%__MODULE__{} = conn) do
    conn
    |> get_connection_pid()
    |> case do
      {:ok, _} -> true
      _ -> false
    end
  end

  def broadcast_connection_state(%__MODULE__{id: id}, state) do
    Open890Web.Endpoint.broadcast("connection:#{id}", "connection_state", state)
  end

  def broadcast_band_scope(%__MODULE__{id: connection_id}, band_scope_data) do
    Open890Web.Endpoint.broadcast("radio:band_scope:#{connection_id}", "band_scope_data", %{
      payload: band_scope_data
    })
  end

  def broadcast_audio_scope(%__MODULE__{id: connection_id}, audio_scope_data) do
    Open890Web.Endpoint.broadcast("radio:audio_scope:#{connection_id}", "scope_data", %{payload: audio_scope_data})
  end

  def broadcast_message(%__MODULE__{id: connection_id}, msg) do
    Open890Web.Endpoint.broadcast("radio:state:#{connection_id}", "radio_state_data", %{msg: msg})
  end

  # bundles up all the knowledge of which topics to subscribe a topic to
  def subscribe(target, connection_id) do
    Phoenix.PubSub.subscribe(target, "radio:state:#{connection_id}")
    Phoenix.PubSub.subscribe(target, "radio:audio_scope:#{connection_id}")
    Phoenix.PubSub.subscribe(target, "radio:band_scope:#{connection_id}")
    Phoenix.PubSub.subscribe(target, "connection:#{connection_id}")
  end

  defp get_connection_pid(%__MODULE__{id: id}) do
    Registry.lookup(:radio_connection_registry, {:tcp, id})
    |> case do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  def repo do
    Repo
  end
end
