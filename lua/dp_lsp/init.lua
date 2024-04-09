local M = {}

local B = require 'dp_base'

Data = vim.fn.stdpath 'data' .. '\\'

DataSub = Data .. 'DataSub'

DataSubMason = DataSub .. '\\Mason'

local lspconfig = require 'lspconfig'
local nls = require 'null-ls'
local capabilities = vim.lsp.protocol.make_client_capabilities()

capabilities = require 'cmp_nvim_lsp'.default_capabilities(capabilities)

require 'mason'.setup {
  install_root_dir = DataSubMason,
  pip = {
    upgrade_pip = true,
    install_args = { '-i', 'https://pypi.tuna.tsinghua.edu.cn/simple', '--trusted-host', 'mirrors.aliyun.com', },
  },
}

require 'mason-lspconfig'.setup {
  ensure_installed = {
    'clangd',
    'pyright',
    'lua_ls',
  },
  automatic_installation = true,
}

require 'mason-null-ls'.setup {
  ensure_installed = {
    'black', 'isort', -- python
    'clang_format',   -- clang_format
    'trim_newlines',
    'trim_whitespace',
  },
  automatic_installation = true,
}

nls.setup {
  sources = {
    nls.builtins.formatting.clang_format.with { filetypes = { 'c', 'cpp', '*.h', }, },
    nls.builtins.formatting.black.with { extra_args = { '--fast', }, filetypes = { 'python', }, },
    nls.builtins.formatting.isort.with { extra_args = { '--profile', 'black', }, filetypes = { 'python', }, },
    nls.builtins.formatting.trim_newlines.with {},
    nls.builtins.formatting.trim_whitespace.with {},
  },
}

B.aucmd('LspAttach', 'LspAttach', {
  callback = function(ev)
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
    B.lazy_map { { 'K', vim.lsp.buf.definition, mode = { 'n', 'v', }, buffer = ev.buf, desc = 'vim.lsp.buf.definition', }, }
  end,
})

function M.root_dir(root_files)
  return function(fname)
    local util = require 'lspconfig.util'
    return util.root_pattern(unpack(root_files))(fname) or util.find_git_ancestor(fname)
  end
end

lspconfig.pyright.setup {
  capabilities = capabilities,
  root_dir = M.root_dir {
    '.git',
  },
}

lspconfig.clangd.setup {
  capabilities = {
    textDocument = {
      completion = {
        editsNearCursor = true,
      },
    },
    offsetEncoding = 'utf-16',
  },
  root_dir = M.root_dir {
    'build',
    '.cache',
    'compile_commands.json',
    'CMakeLists.txt',
    '.git',
  },
}

require 'neodev'.setup()

lspconfig.lua_ls.setup {
  capabilities = capabilities,
  root_dir = M.root_dir {
    '.git',
  },
  single_file_support = true,
  settings = {
    Lua = {
      diagnostics = {
        globals = { 'vim', },
        disable = {
          'incomplete-signature-doc',
          'undefined-global',
        },
        groupSeverity = {
          strong = 'Warning',
          strict = 'Warning',
        },
      },
      runtime = {
        version = 'LuaJIT',
      },
      workspace = {
        library = {},
        checkThirdParty = false,
      },
      telemetry = {
        enable = false,
      },
      completion = {
        workspaceWord = true,
        callSnippet = 'Both',
      },
      misc = {
        parameters = {
          '--log-level=trace',
        },
      },
      format = {
        enable = true,
        defaultConfig = {
          max_line_length          = '200',
          indent_size              = '2',
          call_arg_parentheses     = 'remove',
          trailing_table_separator = 'always',
          quote_style              = 'single',
        },
      },
    },
  },
}

require 'inc_rename'.setup()

for name, icon in pairs(require 'lazyvim.config'.icons.diagnostics) do
  name = 'DiagnosticSign' .. name
  vim.fn.sign_define(name, { text = icon, texthl = name, numhl = '', })
end

vim.diagnostic.config {
  underline = true,
  update_in_insert = false,
  virtual_text = {
    spacing = 0,
    source = 'if_many',
    prefix = '●',
  },
  severity_sort = true,
}

-- functions
function M.stop_all() vim.lsp.stop_client(vim.lsp.get_active_clients(), true) end

function M.rename() vim.fn.feedkeys(':IncRename ' .. vim.fn.expand '<cword>') end

function M.diagnostic_open_float() vim.diagnostic.open_float() end

function M.diagnostic_setloclist() vim.diagnostic.setloclist() end

function M.diagnostic_goto_prev() vim.diagnostic.goto_prev() end

function M.diagnostic_goto_next() vim.diagnostic.goto_next() end

function M.diagnostic_enable() vim.diagnostic.enable() end

function M.diagnostic_disable() vim.diagnostic.disable() end

function M.definition() vim.lsp.buf.definition() end

function M.declaration() vim.lsp.buf.declaration() end

function M.hover() vim.lsp.buf.hover() end

function M.implementation() vim.lsp.buf.implementation() end

function M.signature_help() vim.lsp.buf.signature_help() end

function M.references() vim.lsp.buf.references() end

function M.type_definition() vim.lsp.buf.type_definition() end

function M.code_action() vim.lsp.buf.code_action() end

function M.LspStart() vim.cmd 'LspStart' end

function M.LspRestart() vim.cmd 'LspRestart' end

function M.LspInfo() vim.cmd 'LspInfo' end

function M.feedkeys_LspStop() vim.fn.feedkeys ':LspStop ' end

function M.ClangdSwitchSourceHeader() vim.cmd 'ClangdSwitchSourceHeader' end

function M.retab_erase_bad_white_space()
  vim.cmd 'retab'
  pcall(vim.cmd, [[%s/\s\+$//]])
end

function M.format()
  require 'config.my.markdown'.align_table()
  vim.lsp.buf.format {
    async = true,
    filter = function(client)
      return client.name ~= 'clangd' -- clang-format nedd to check pyvenv.cfg
    end,
  }
end

function M.format_paragraph()
  local save_cursor = vim.fn.getpos '.'
  vim.cmd 'norm =ap'
  pcall(vim.fn.setpos, '.', save_cursor)
end

function M.format_input()
  local dirs = B.get_file_dirs_till_git()
  for _, dir in ipairs(dirs) do
    local _clang_format_path = require 'plenary.path':new(B.rep_slash_lower(dir)):joinpath '.clang-format'
    if _clang_format_path:exists() then
      B.cmd('e %s', _clang_format_path.filename)
      break
    end
  end
end

require 'which-key'.register {
  ['<leader>f'] = { name = 'lsp', },
  ['<leader>fv'] = { name = 'lsp.move', },
  ['<leader>fC'] = { function() M.format_input() end, 'config.nvim.lsp: format_input', mode = { 'n', 'v', }, },
  ['<leader>fD'] = { function() M.feedkeys_LspStop() end, 'config.nvim.lsp: feedkeys_LspStop', mode = { 'n', 'v', }, },
  ['<leader>fn'] = { function() M.rename() end, 'lsp: rename', mode = { 'n', 'v', }, },
  ['<leader>ff'] = { function() M.format() end, 'lsp: format', mode = { 'n', 'v', }, silent = true, },
  ['<leader>fl'] = { function() require 'config.nvim.telescope'.lsp_document_symbols() end, 'telescope.lsp: document_symbols', mode = { 'n', 'v', }, silent = true, },
  ['<leader>fr'] = { function() require 'config.nvim.telescope'.lsp_references() end, 'telescope.lsp: references', mode = { 'n', 'v', }, silent = true, },
  ['<leader>f<c-f>'] = { function() M.LspInfo() end, 'config.nvim.lsp: LspInfo', mode = { 'n', 'v', }, },
  ['<leader>f<c-r>'] = { function() M.LspRestart() end, 'config.nvim.lsp: LspRestart', mode = { 'n', 'v', }, },
  ['<leader>f<c-s>'] = { function() M.LspStart() end, 'config.nvim.lsp: LspStart', mode = { 'n', 'v', }, },
  ['<leader>f<c-w>'] = { function() M.stop_all() end, 'config.nvim.lsp: stop_all', mode = { 'n', 'v', }, },
  ['<leader>fc'] = { function() M.code_action() end, 'config.nvim.lsp: code_action', mode = { 'n', 'v', }, },
  ['<leader>fi'] = { function() M.implementation() end, 'config.nvim.lsp: implementation', mode = { 'n', 'v', }, },
  ['<leader>fp'] = { function() M.format_paragraph() end, 'config.nvim.lsp: format_paragraph', mode = { 'n', 'v', }, },
  ['<leader>fs'] = { function() M.signature_help() end, 'config.nvim.lsp: signature_help', mode = { 'n', 'v', }, },
  ['<leader>fq'] = { function() M.diagnostic_enable() end, 'config.nvim.lsp: diagnostic_enable', mode = { 'n', 'v', }, },
  ['<leader>fvq'] = { function() M.diagnostic_disable() end, 'config.nvim.lsp: diagnostic_disable', mode = { 'n', 'v', }, },
  ['<leader>fve'] = { function() M.retab_erase_bad_white_space() end, 'config.nvim.lsp: retab_erase_bad_white_space', mode = { 'n', 'v', }, },
  ['<leader>fvd'] = { function() M.type_definition() end, 'config.nvim.lsp: type_definition', mode = { 'n', 'v', }, },
  ['[d'] = { function() M.diagnostic_goto_prev() end, 'config.nvim.lsp: diagnostic_goto_prev', mode = { 'n', 'v', }, },
  ['[f'] = { function() M.diagnostic_open_float() end, 'config.nvim.lsp: diagnostic_open_float', mode = { 'n', 'v', }, },
  [']d'] = { function() M.diagnostic_goto_next() end, 'config.nvim.lsp: iagnostic_goto_next', mode = { 'n', 'v', }, },
  [']f'] = { function() M.diagnostic_setloclist() end, 'config.nvim.lsp: diagnostic_setloclist', mode = { 'n', 'v', }, },
  ['<leader>fo'] = { function() M.declaration() end, 'config.nvim.lsp: declaration', mode = { 'n', 'v', }, },
  ['<leader>fw'] = { function() M.ClangdSwitchSourceHeader() end, 'config.nvim.lsp: ClangdSwitchSourceHeader', mode = { 'n', 'v', }, },
  ['<leader>fd'] = { function() M.definition() end, 'config.nvim.lsp: definition', mode = { 'n', 'v', }, },
  ['<leader>fe'] = { function() M.references() end, 'config.nvim.lsp: references', mode = { 'n', 'v', }, },
  ['<leader>fh'] = { function() M.hover() end, 'config.nvim.lsp: hover', mode = { 'n', 'v', }, },
}

return M
