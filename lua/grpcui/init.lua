local GrpcUi = {}
local UI = require('grpcui.ui')

local H = {}

--- @class Bffers
--- @field payload integer
--- @field method integer
--- @field response integer

--- @class Wins
--- @field payload integer
--- @field method integer
--- @field response integer

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

H.get_lsp_config = function()
  local client_capabilities = vim.lsp.protocol.make_client_capabilities()
  client_capabilities.textDocument.completion.completionItem.snippetSupport = true

  return { --- @type vim.lsp.ClientConfig
    name = "protobuf_jsonls",
    cmd = { '/home/tieu/.local/share/nvim/mason/bin/vscode-json-language-server', '--stdio' },
    init_options = {
      provideFormatter = true,
    },
    root_dir = nil,
    workspace_folders = nil,
    capabilities = client_capabilities,
    settings = {
      json = {
        schemas = {},
        validate = { enable = true },
      },
    },
    single_file_support = true,
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
--- @param bufs Bffers: list of buffers.
--- @param wins Wins: list of wins.
H.setup_method_keys = function(name_space_config, bufs, wins)
  vim.api.nvim_buf_set_keymap(bufs.method, 'n', 's', '', {
    noremap = true,
    callback = function()
      UI.open_select_proto(name_space_config.folder.search, function(proto_file, method_def)
        local method = H.parse_method_def(method_def)

        UI.render_method(bufs.method, proto_file, method)

        H.compile_json_schema(
          name_space_config.folder.schema,
          name_space_config.folder.search,
          name_space_config.proto_paths,
          proto_file
        )

        local payload_file = name_space_config.folder.payload .. '/' .. method.request .. '.json'
        H.try_create_folder(name_space_config.folder.payload)
        H.try_create_file(payload_file)
        H.open_payload_file(
          wins.payload,
          payload_file,
          H.get_schema_file(name_space_config.folder.schema, proto_file, method)
        )
      end)
    end
  })
end

H.get_schema_file = function(schema_folder, proto_file, method)
  return schema_folder .. '/' .. proto_file .. '/' .. method.request .. '.json'
end

H.try_create_folder = function(folder)
  if vim.fn.isdirectory(folder) == 0 then
    vim.fn.mkdir(folder, 'p')
  end
end

H.try_create_file = function(file_path)
  if vim.fn.filereadable(file_path) == 0 then
    vim.fn.writefile({}, file_path)
  end
end

--- open payload json file in a window
--- @param win integer
--- @param file_path string
H.open_payload_file = function(win, file_path, schema_file)
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_command('edit ' .. file_path)

  local request_file_name = vim.fn.fnamemodify(file_path, ':t')

  vim.api.nvim_exec_autocmds('User', {
    pattern = 'ProtoBufPayloadOpen',
    data = {
      schema_file = schema_file,
      file_name = request_file_name,
    },
  })
end

--- Compile JSON schema from a proto file to a folder.
--- @param schema_folder string: The folder to store the compiled schema.
--- @param proto_paths string[]: The proto paths to search for imports.
--- @param proto_file string: The proto file to compile.
--- @return string: The result of the compilation.
H.compile_json_schema = function(schema_folder, search_folder, proto_paths, proto_file)
  local target_folder = schema_folder .. '/' .. proto_file
  H.try_create_folder(target_folder)

  local full_path = search_folder .. '/' .. proto_file

  local cmd = string.format('protoc --jsonschema_out=%s --proto_path=%s %s', target_folder,
    table.concat(proto_paths, ' '), full_path)

  local result = vim.fn.system(cmd) -- TODO: handle error
  return result
end

--- init lsp setup
--- @param lsp_config vim.lsp.ClientConfig
H.setup_lsp = function(lsp_config)
  vim.api.nvim_create_autocmd('User', {
    pattern = 'ProtoBufPayloadOpen',
    callback = function(ev)
      local config = vim.deepcopy(lsp_config)
      local file_name = ev.data.file_name
      local schema_file = ev.data.schema_file

      table.insert(config.settings.json.schemas, {
        fileMatch = { file_name },
        url = 'file://' .. schema_file,
      })

      -- TODO: try stop old
      vim.lsp.start(config, {
        bufnr = ev.buf
      })
    end,
  })
end

GrpcUi.open = function(name_space)
  local name_space_config = H.get_name_space_config(name_space)
  local buffers, wins = UI.init_ui()

  H.setup_method_keys(name_space_config, buffers, wins)
  H.setup_lsp(H.get_lsp_config())

  vim.api.nvim_set_current_win(wins.method)
end

GrpcUi.setup = function()
end

return GrpcUi
