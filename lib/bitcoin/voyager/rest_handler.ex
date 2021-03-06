defmodule Bitcoin.Voyager.RESTHandler do
  alias Bitcoin.Voyager.Util
  alias Bitcoin.Voyager.Cache

  require Logger

  def init(req, [module]) when is_atom(module) do
    {params, req} = extract_request_params(req)
    case module.transform_args(params) do
      {:error, reason} ->
        {:ok, req} = :cowboy_req.reply(400, [], to_string(reason), req)
        {:shutdown, req, nil}
      {:ok, transformed_params} ->
         do_command(module, params, transformed_params, req)
    end
  end

  def info({:libbitcoin_client, _command, ref, reply}, req, %{ref: ref, params: params, module: module} = state) do
    case module.transform_reply(reply) do
      {:ok, transformed_reply} ->
        {:ok, json} = JSX.encode(transformed_reply)
        req = :cowboy_req.reply(200, [], json, req)
        :ok = Cache.put(module, params, reply)
        {:stop, req, state}
      {:error, reason} ->
        Logger.debug "transform error #{module}"
        {:ok, json} = JSX.encode(%{error: reason})
        req = :cowboy_req.reply(500, [], json, req)
        {:stop, req, state}
    end
  end
  def info({:libbitcoin_client_error, command, ref, :timeout}, req, %{ref: ref} = state) do
    Logger.debug "timeout response  #{command}"
    {:ok, json} = JSX.encode(%{error: "timeout"})
    req = :cowboy_req.reply(408, [], json, req)
    {:stop, req, state}
  end
  def info({:libbitcoin_client_error, command, ref, error}, req, %{ref: ref} = state) do
    Logger.debug "error response  #{command} #{error}"
    {:ok, json} = JSX.encode(%{error: error})
    req = :cowboy_req.reply(500, [], json, req)
    {:stop, req, state}
  end

  def terminate(_reason, _req, _state) do
    :ok
  end

  def do_command(module, params, transformed_params, req) do
    case Cache.get(module, params, transformed_params) do
      {:ok, value} ->
        {:ok, json} = JSX.encode(value)
        req = :cowboy_req.reply(200, [], json, req)
        {:ok, req, %{}}
      :not_found ->
        {:ok, ref} = send_command(module.command, transformed_params)
        {:cowboy_loop, req, %{ref: ref, params: transformed_params, module: module}, 2000}
    end
  end

  def send_command(command, args) when is_function command do
    client = :pg2.get_closest_pid(Bitcoin.Voyager.Client)
    apply command, [client] ++ args ++ [self]
  end
  def send_command(command, args) do
    client = :pg2.get_closest_pid(Bitcoin.Voyager.Client)
    apply Libbitcoin.Client, command, [client] ++ args ++ [self]
  end

  defp extract_request_params(req) do
    extract_request_params(req, :cowboy_req.method(req))
  end
  defp extract_request_params(req, "GET") do
    bindings = :cowboy_req.bindings(req)
    qs = :cowboy_req.parse_qs(req)
    bindings_map = Enum.into(bindings, %{})
    qs_map = Enum.into(qs, %{}) |> Util.atomify
    args = Map.merge(qs_map, bindings_map)
    {args, req}
  end
  defp extract_request_params(req, "POST") do
    {:ok, form_data, req} = :cowboy_req.body_qs(req)
    args = Enum.into(form_data, %{}) |> Util.atomify
    {args, req}
  end
  defp extract_request_params(req, _) do
    {%{}, req}
  end



end
