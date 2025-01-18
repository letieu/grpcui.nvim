local GrpcUi = {}
local UI = require('grpcui.ui')

local H = {}

--- @class NamespaceConfig
--- @field endpoint string
--- @field proto_paths string[]
--- @field folder NamespaceFolder

--- @class NamespaceFolder
--- @field search string
--- @field schema string
--- @field payload string

--- Get the configuration for a given namespace.
--- @param name_space string: The namespace to get the configuration for.
--- @return NamespaceConfig: The configuration table for the given namespace.
H.get_name_space_config = function(name_space)
  return {
    endpoint = 'http://localhost:8080',
    proto_paths = {
      '/home/tieu/code/ONE/om-protobuf/proto',
    },
    folder = {
      search = '/home/tieu/code/ONE/om-protobuf/proto/chorus/com/',
      schema = '/tmp/grpcui.nvim/data/' .. name_space .. '/schemas',
      payload = '/tmp/grpcui.nvim/data/' .. name_space .. '/payloads',
    },
  }
end

--- @class RpcMethod
--- @field name string
--- @field request string
--- @field response string

--- Parse a method definition string into a table.
--- @param method_def string: The method definition string to parse.
--- @return RpcMethod: The parsed method definition.
H.parse_method_def = function(method_def)
  local name = method_def:match('rpc (%w+)')
  local request = method_def:match('%((%w+)%)')
  local response = method_def:match('returns %(([^)]+)%)')

  -- trim
  name = name:gsub('^%s*(.-)%s*$', '%1')
  request = request:gsub('^%s*(.-)%s*$', '%1')
  response = response:gsub('^%s*(.-)%s*$', '%1')

  return {
    name = name,
    request = request,
    response = response,
  }
end

--- Setup keybindings for the method buffer.
--- @param name_space_config NamespaceConfig: The configuration for the current namespace.
--- @param buf number: The buffer number to setup keybindings for.
H.setup_method_keys = function(name_space_config, buf)
  vim.api.nvim_buf_set_keymap(buf, 'n', 's', '', {
    noremap = true,
    callback = function()
      UI.open_select_proto(name_space_config.folder.search, function(proto_file, method_def)
        local method = H.parse_method_def(method_def)

        UI.render_method(buf, proto_file, method)
        H.compile_json_schema(
          name_space_config.folder.schema,
          name_space_config.folder.search,
          name_space_config.proto_paths,
          proto_file
        )
      end)
    end
  })
end

--- Compile JSON schema from a proto file to a folder.
--- @param schema_folder string: The folder to store the compiled schema.
--- @param proto_paths string[]: The proto paths to search for imports.
--- @param proto_file string: The proto file to compile.
--- @return string: The result of the compilation.
H.compile_json_schema = function(schema_folder, search_folder, proto_paths, proto_file)
  local target_folder = schema_folder .. '/' .. proto_file
  if vim.fn.isdirectory(target_folder) == 0 then
    vim.fn.mkdir(target_folder, 'p')
  end
  local full_path = search_folder .. '/' .. proto_file

  local cmd = string.format('protoc --jsonschema_out=%s --proto_path=%s %s', target_folder,
    table.concat(proto_paths, ' '), full_path)

  local result = vim.fn.system(cmd) -- TODO: handle error
  return result
end

GrpcUi.open = function(name_space)
  local name_space_config = H.get_name_space_config(name_space)
  local buffers, wins = UI.init_ui()
  H.setup_method_keys(name_space_config, buffers.method)

  vim.api.nvim_set_current_win(wins.method)
end

GrpcUi.setup = function()
end

return GrpcUi
