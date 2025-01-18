local UI = {}

local label_pad = function(label)
  local label_width = 10
  return label .. string.rep(' ', label_width - #label)
end

local get_ns_id = (function()
  local ns_id = nil

  local get_ns_id = function()
    if ns_id then
      return ns_id
    else
      ns_id = vim.api.nvim_create_namespace('grpcui')
      return ns_id
    end
  end

  return get_ns_id
end)()

UI.init_ui = function()
  vim.api.nvim_command('tabnew')

  local buffers = {}
  buffers.payload = vim.api.nvim_create_buf(true, true)
  buffers.method = vim.api.nvim_create_buf(false, true)
  buffers.response = vim.api.nvim_create_buf(false, true)

  local wins = {}
  wins.payload = vim.api.nvim_get_current_win()
  wins.method = vim.api.nvim_open_win(0, false, {
    split = 'above',
    height = 4,
  })
  wins.response = vim.api.nvim_open_win(0, true, {
    split = 'right',
    width = 80,
  })

  vim.api.nvim_win_set_buf(wins.method, buffers.method)
  vim.api.nvim_win_set_buf(wins.payload, buffers.payload)
  vim.api.nvim_win_set_buf(wins.response, buffers.response)

  vim.api.nvim_buf_set_name(buffers.method, 'Method')
  vim.api.nvim_buf_set_name(buffers.payload, 'Payload')
  vim.api.nvim_buf_set_name(buffers.response, 'Response')

  vim.api.nvim_set_option_value('spell', false, { win = wins.method })
  vim.api.nvim_set_option_value('modifiable', false, { buf = buffers.method })
  vim.api.nvim_set_option_value('modifiable', true, { buf = buffers.payload })

  vim.api.nvim_buf_set_extmark(
    buffers.method,
    get_ns_id(),
    0,
    0,
    {
      virt_text = {
        { "Select a method by pressing 's'", "Comment" },
      },
    }
  )

  return buffers, wins
end

--- Open a fzf window to select a proto file and method.
--- @param folder string: The folder to search for proto files.
--- @param on_select fun(proto_file: string, method_def: string) The callback to call when a method is selected.
UI.open_select_proto = function(folder, on_select)
  require('fzf-lua').grep({
    search = 'rpc ',
    file_icons = false,
    cwd = folder,
    actions = {
      ['default'] = function(selected)
        if #selected == 0 then
          return
        end
        selected = selected[1]
        local proto_file = selected:match('([^:]+):')
        local method_def = selected:match('rpc .+')
        on_select(proto_file, method_def)
      end
    }
  })
end

--- Render the method buffer with the given file and method.
--- @param buf number: The buffer number to render the method in.
--- @param file string: The proto file name.
--- @param method RpcMethod: The method to render.
UI.render_method = function(buf, file, method)
  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
  vim.api.nvim_buf_clear_namespace(buf, get_ns_id(), 0, -1)

  local label_width = 10

  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { label_pad("proto") .. file })
  vim.api.nvim_buf_add_highlight(buf, -1, 'Comment', 0, 0, label_width)
  vim.api.nvim_buf_add_highlight(buf, -1, 'Class', 0, label_width, -1)

  vim.api.nvim_buf_set_lines(buf, 1, 2, false, { label_pad("method") .. method.name })
  vim.api.nvim_buf_add_highlight(buf, -1, 'Comment', 1, 0, label_width)
  vim.api.nvim_buf_add_highlight(buf, -1, 'Function', 1, label_width, -1)

  vim.api.nvim_buf_set_lines(buf, 2, 3, false, { label_pad("Request") .. method.request })
  vim.api.nvim_buf_add_highlight(buf, -1, 'Comment', 2, 0, label_width)
  vim.api.nvim_buf_add_highlight(buf, -1, 'Type', 2, label_width, -1)

  vim.api.nvim_buf_set_lines(buf, 3, 4, false, { label_pad("Response") .. method.response })
  vim.api.nvim_buf_add_highlight(buf, -1, 'Comment', 3, 0, label_width)
  vim.api.nvim_buf_add_highlight(buf, -1, 'Type', 3, label_width, -1)

  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
end

return UI
