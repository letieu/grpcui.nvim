# GrpcUI.nvim

Interactive gRPC client for neovim

![image](https://github.com/user-attachments/assets/7d71426b-47e9-45d7-a565-f0ef62529780)

> [!CAUTION]
> Currently, this plugin is under development. It may not work as expected.

## Feature:
- Autocomplete json payload
- Easy to select, change the rpc method to run with `fzf-lua`

## Installation

* Requirements:
    - `protoc`: https://grpc.io/docs/protoc-installation/
    - `protoc-gen-jsonschema`: https://github.com/chrusty/protoc-gen-jsonschema
    - `grpcurl`: https://github.com/fullstorydev/grpcurl

* With **lazy.nvim**
```lua
{
  "letieu/grpcui.nvim",
  dependencies = {
    'ibhagwan/fzf-lua'
  },
}
```

## Usage

1. Open: `require('grpcui).open('MyProject')` (Open with namespace `MyProject`)
2. Update `config.json` file:
    - `import_path`: is **folder** that import relate proto file
    - `search`: is **folder** that start search `*.proto` file from. Can be same with `import_path`
3. Search and select the rpc method to run by press: `<leader>s`
3. Run the query: `<leader>r`

```lua
-- Open new Grpcui with namespace `MyProject`
require('grpcui').open("MyProject")
```

* example  `config.json` file
```json
{
  "endpoint": "localhost:5000",
  "search": "/home/me/my-project/protos",
  "import_path": "/home/me/my-project/protos"
}

```

## Config

**Default config**

```lua
-- TODO:
require('grpcui').setup({
    prefix_path = vim.fn.stdpath('data') .. '/grpcui.nvim',
})

```
