local Grpc = {}

--- @class GrpcCallbacks
--- @field on_start fun() Called when the gRPC call is started
--- @field on_data fun(data: string) Called when data is received from the gRPC call
--- @field on_error fun(error: string) Called when an error is received from the gRPC call

--- @class GrpcProto
--- @field import_path string
--- @field proto string

--- Call a gRPC method
--- @param url string
--- @param proto GrpcProto
--- @param method string: The gRPC method to call. Example: "grpcui.GrpcUi.GetServices"
--- @param payload string: The payload to send to the gRPC method
--- @param callbacks GrpcCallbacks
Grpc.call = function(url, proto, method, payload, callbacks)
  local stdout = vim.uv.new_pipe(false)
  local stderr = vim.uv.new_pipe(false)

  if not stdout or not stderr then
    error('Failed to create pipes')
  end

  callbacks.on_start()

  -- local cmd = string.format('grpcurl -plaintext -d \'%s\' %s %s', payload, url, method)

  local handle
  handle, _ = vim.uv.spawn(
    'grpcurl',
    ---@diagnostic disable-next-line: missing-fields
    {
      args = {
        '-plaintext',
        '-import-path',
        proto.import_path,
        '-proto',
        proto.proto,
        '-d',
        payload,
        url,
        method,
      },
      stdio = { nil, stdout, stderr }
    },
    vim.schedule_wrap(function()
      stdout:read_stop()
      stderr:read_stop()
      stdout:close()
      stderr:close()
      handle:close()
    end))

  vim.uv.read_start(stdout, function(err, data)
    if data ~= nil then
      callbacks.on_data(data)
    end
  end)
  vim.uv.read_start(stderr, function(err, data)
    if err ~= nil then
      callbacks.on_error(err)
    end
    if data ~= nil then
      callbacks.on_error(data)
    end
  end)

  vim.uv.run('once')
end

return Grpc
