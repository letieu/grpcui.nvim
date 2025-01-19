local GrpcUi = {}
local UI = require('grpcui.ui')
local Grpc = require('grpcui.grpc')

local default_workspace_config = function(name_space)
  return {
    endpoint = 'localhost:5000',
    import_path = '/home/tieu/code/playground/nest-rpc/src/hero/',
    folder = {
      search = '/home/tieu/code/playground/nest-rpc/src/',
      schema = '/tmp/grpcui.nvim/data/' .. name_space .. '/schemas',
      payload = '/tmp/grpcui.nvim/data/' .. name_space .. '/payloads',
    },
  }
end

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
--- @field import_path string
--- @field folder NamespaceFolder

--- @class NamespaceFolder
--- @field search string
--- @field schema string
--- @field payload string

--- Get the configuration for a given namespace.
--- @param name_space string: The namespace to get the configuration for.
--- @return NamespaceConfig: The configuration table for the given namespace.
H.get_name_space_config = function(name_space)
  local config_file = H.get_workspace_config_file_path(name_space)
  if vim.fn.filereadable(config_file) == 0 then
    vim.fn.writefile({ vim.fn.json_encode(default_workspace_config(name_space)) }, config_file)
  end

  local success, json_config = pcall(vim.fn.json_decode, vim.fn.join(vim.fn.readfile(config_file)) or '{}')
  if not success then
    vim.notify('Failed to parse config file: ' .. config_file)
    return {
      "Failed to parse config file: " .. config_file
    }
  end

  return json_config
end

H.get_workspace_config_file_path = function(name_space)
  return '/tmp/grpcui.nvim/data/' .. name_space .. '/config.json'
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
--- @field full_name string

--- Parse a method definition string into a table.
--- @param method_def string: The method definition string to parse.
--- @return RpcMethod: The parsed method definition.
H.parse_method_def = function(method_def, proto_content)
  local name = method_def:match('rpc (%w+)')
  local request = method_def:match('%((%w+)%)')
  local response = method_def:match('returns %(([^)]+)%)')

  -- trim
  name = name:gsub('^%s*(.-)%s*$', '%1')
  request = request:gsub('^%s*(.-)%s*$', '%1')
  response = response:gsub('^%s*(.-)%s*$', '%1')

  -- Extract service and package from proto_file
  local service = proto_content:match('service (%w+)')
  local package = proto_content:match('package ([%w%.]+)')

  return {
    name = name,
    full_name = package .. '.' .. service .. '.' .. name,
    request = request,
    response = response,
  }
end

H.read_file_content = function(file_path)
  local file = io.open(file_path, "r")
  if not file then return nil end
  local content = file:read("*all")
  file:close()
  return content
end

H.get_schema_file = function(schema_folder, proto_file, method)
  return vim.fs.joinpath(schema_folder, proto_file, method.request) .. '.json'
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

  local current_buf = vim.api.nvim_get_current_buf()
  UI.show_payload_help_text(current_buf)
end

--- Compile JSON schema from a proto file to a folder.
--- @param schema_folder string: The folder to store the compiled schema.
--- @param import_path string: The proto path to search for imports.
--- @param proto_file string: The proto file to compile.
--- @return string: The result of the compilation.
H.compile_json_schema = function(schema_folder, search_folder, import_path, proto_file)
  local target_folder = vim.fs.joinpath(schema_folder, proto_file)
  H.try_create_folder(target_folder)

  local full_path = vim.fs.joinpath(search_folder, proto_file)

  local cmd = string.format(
    'protoc --jsonschema_out=%s --proto_path=%s %s',
    target_folder,
    import_path,
    full_path
  )

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

      ---@diagnostic disable-next-line: missing-fields
      vim.lsp.start(config, {
        bufnr = ev.buf
      })
    end,
  })
end

H.get_payload = function(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  return table.concat(lines, '\n')
end

H.setup_global_keys = function(name_space_config, bufs, wins)
  -- Select a rpc method
  vim.api.nvim_set_keymap('n', '<leader>s', '', {
    noremap = true,
    callback = function()
      UI.open_select_proto(name_space_config.folder.search, function(proto_file, method_def)
        local proto_content = H.read_file_content(
          vim.fs.joinpath(name_space_config.folder.search, proto_file)
        )
        local method = H.parse_method_def(method_def, proto_content)

        UI.render_method(bufs.method, proto_file, method)

        vim.api.nvim_win_set_var(wins.method, 'method', method.full_name)
        local file_path = vim.fs.joinpath(name_space_config.folder.search, proto_file)
        vim.api.nvim_win_set_var(wins.method, 'proto_file', file_path)

        H.compile_json_schema(
          name_space_config.folder.schema,
          name_space_config.folder.search,
          name_space_config.import_path,
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

  -- Send the request
  vim.api.nvim_set_keymap('n', '<leader>r', '', {
    noremap = true,
    callback = function()
      local method = vim.api.nvim_win_get_var(wins.method, 'method')
      local proto_file = vim.api.nvim_win_get_var(wins.method, 'proto_file')
      local payload = H.get_payload(bufs.payload)

      Grpc.call(
        name_space_config.endpoint,
        {
          import_path = name_space_config.import_path,
          proto = proto_file,
        },
        method,
        payload,
        {
          on_start = function()
            UI.render_response(bufs.response, 'Loading...')
          end,
          on_data = function(data)
            vim.schedule(function()
              UI.render_response(bufs.response, data)
            end)
          end,
          on_error = function(error)
            vim.schedule(function()
              UI.render_response(bufs.response, error)
            end)
          end,
        })
    end
  })
end

GrpcUi.open = function(name_space)
  if not name_space then
    name_space = 'default'
  end

  local name_space_config = H.get_name_space_config(name_space)

  local buffers, wins, tab_id = UI.init_ui()

  H.setup_global_keys(name_space_config, buffers, wins)

  H.setup_lsp(H.get_lsp_config())

  vim.api.nvim_set_keymap('n', '<leader>q', '', {
    noremap = true,
    callback = function()
      H.close(tab_id)
    end
  })

  vim.api.nvim_set_keymap('n', '<leader>c', '', {
    noremap = true,
    callback = function()
      UI.show_config_float(
        H.get_workspace_config_file_path(name_space),
        function()
          H.close(tab_id)
          GrpcUi.open(name_space)
        end
      )
    end
  })

  vim.api.nvim_set_current_win(wins.method)
end

H.close = function(tab_id)
  local current_tab = vim.api.nvim_get_current_tabpage()
  if current_tab == tab_id then
    vim.api.nvim_command('tabclose')
  end
end

return GrpcUi
