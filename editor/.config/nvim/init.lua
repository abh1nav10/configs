vim.keymap.set("n", "<Space>", "<Nop>", { silent = true })
vim.g.mapleader = " "

-- In order to make nvim use the exact hexcode instead of picking out 
-- of the limited 256 colors pallette
vim.opt.termguicolors = true

-- Copy directly into the system clipboard instead of the nvim buffer using 'xclip'
vim.opt.clipboard = "unnamedplus"

vim.opt.scrolloff = 2
vim.opt.wrap = false
vim.opt.signcolumn='yes'
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.keymap.set('', 'H', '^')
vim.keymap.set('', 'L', '$')

-- TODO: Integrate system clipboard

-- No arrow keys(allowing them in insert mode for now)!!
vim.keymap.set('n', '<up>', '<nop>')
vim.keymap.set('n', '<down>', '<nop>')
vim.keymap.set('n', '<left>', '<nop>')
vim.keymap.set('n', '<right>', '<nop>')
--vim.keymap.set('i', '<up>', '<nop>')
--vim.keymap.set('i', '<down>', '<nop>')
--vim.keymap.set('i', '<left>', '<nop>')
--vim.keymap.set('i', '<right>', '<nop>')

-- Always good to highlight yanked text
vim.api.nvim_create_autocmd(
	'TextYankPost',
	{
		pattern = '*',
		command = 'silent! lua vim.highlight.on_yank({ timeout = 300 })'
	}
)

-- Always good to jump to the last edit position on opening file
vim.api.nvim_create_autocmd(
	'BufReadPost',
	{
		pattern = '*',
		callback = function(ev)
			if vim.fn.line("'\"") > 1 and vim.fn.line("'\"") <= vim.fn.line("$") then
				if not vim.fn.expand('%:p'):find('.git', 1, true) then
					vim.cmd('exe "normal! g\'\\""')
				end
			end
		end
	}
)

-- Always good to leave paste mode when leaving insert mode if it was on in the first place
vim.api.nvim_create_autocmd('InsertLeave', { pattern = '*', command = 'set nopaste' })


-- Checking whether the plugin manager, lazy.nvim is there.. if not clone it from git
-- and put it at the lazypath and then the lazypath is loaded eagerly onto
-- the runtime path.. only the lazypath is loaded eagerly and rest everything 
-- loaded lazily by lazy.nvim itself
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- setting up(taken from Jon's configuration)
require("lazy").setup({
	-- main color scheme
	{
		"wincent/base16-nvim",
		lazy = false, -- load at start
		priority = 1000, -- load first
		config = function()
			-- TODO: Decide colorscheme as gruvbox-dark-hard is not working as intended
			vim.cmd([[colorscheme gruvbox-dark-hard]])
			vim.o.background = 'dark'
			vim.cmd([[hi Normal ctermbg=NONE]])
			vim.api.nvim_set_hl(0, "WinSeparator", { fg = 1250067 })
			local bools = vim.api.nvim_get_hl(0, { name = 'Boolean' })
			vim.api.nvim_set_hl(0, 'Comment', bools)
			local marked = vim.api.nvim_get_hl(0, { name = 'PMenu' })
			vim.api.nvim_set_hl(0, 'LspSignatureActiveParameter', { fg = marked.fg, bg = marked.bg, ctermfg = marked.ctermfg, ctermbg = marked.ctermbg, bold = true })
		end
	},

	-- bar at the bottom
	{
		'itchyny/lightline.vim',
		lazy = false, 
		config = function()
			-- no need to also show mode in cmd line when we have bar
			vim.o.showmode = false
			vim.g.lightline = {
				active = {
					left = {
						{ 'mode', 'paste' },
						{ 'readonly', 'filename', 'modified' }
					},
					right = {
						{ 'lineinfo' },
						{ 'percent' },
						{ 'fileencoding', 'filetype' }
					},
				},
				component_function = {
					filename = 'LightlineFilename'
				},
			}
			function LightlineFilenameInLua(opts)
				if vim.fn.expand('%:t') == '' then
					return '[No Name]'
				else
					return vim.fn.getreg('%')
				end
			end
			vim.api.nvim_exec(
				[[
				function! g:LightlineFilename()
				return v:lua.LightlineFilenameInLua()
				endfunction
				]],
				true
			)
		end
	},

	-- quick navigation
	{
		'ggandor/leap.nvim',
		config = function()
			vim.keymap.set({'n', 'x', 'o'}, 's', '<Plug>(leap)')
			vim.keymap.set('n',             'S', '<Plug>(leap-from-window)')
		end
	},


	-- LSP config for rust
	{
		'neovim/nvim-lspconfig',
		config = function()
			-- Setup language servers.

			-- Rust
			vim.lsp.config('rust_analyzer', {
				-- Server-specific settings. See `:help lspconfig-setup`
				settings = {
					["rust-analyzer"] = {
						cargo = {
							features = "all",
						},
						checkOnSave = {
							enable = true,
						},
						check = {
							command = "clippy",
						},
						imports = {
							group = {
								enable = false,
							},
						},
						completion = {
							postfix = {
								enable = false,
							},
						},
					},
				},
			})
			vim.lsp.enable('rust_analyzer')

			-- Autoformat on save

			vim.api.nvim_create_autocmd('LspAttach', {
				group = vim.api.nvim_create_augroup('UserLspFormat', { clear = true }),
				callback = function(args)
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					local bufnr = args.buf

					if client.server_capabilities.documentFormattingProvider then
						vim.api.nvim_create_autocmd("BufWritePre", {
							buffer = bufnr,
							callback = function()
								vim.lsp.buf.format({ bufnr = bufnr, async = false })
							end,
						})
					end
				end,
			})

		end
	},

	-- LSP based code completion
	{
		"hrsh7th/nvim-cmp",
		-- load cmp on InsertEnter
		event = "InsertEnter",
		-- these dependencies will only be loaded when cmp loads
		-- dependencies are always lazy-loaded unless specified otherwise
		dependencies = {
			'neovim/nvim-lspconfig',
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
		},
		config = function()
			local cmp = require'cmp'
			cmp.setup({
				snippet = {
					-- REQUIRED by nvim-cmp. get rid of it once we can
					expand = function(args)
						vim.snippet.expand(args.body)
					end,
				},
				mapping = cmp.mapping.preset.insert({
					['<C-b>'] = cmp.mapping.scroll_docs(-4),
					['<C-f>'] = cmp.mapping.scroll_docs(4),
					['<C-Space>'] = cmp.mapping.complete(),
					['<C-e>'] = cmp.mapping.abort(),
					-- Accept currently selected item.
					-- Set `select` to `false` to only confirm explicitly selected items.
					['<CR>'] = cmp.mapping.confirm({ select = true, behavior = cmp.ConfirmBehavior.Insert }),
				}),
				sources = cmp.config.sources({
					{ name = 'nvim_lsp' },
				}, {
					{ name = 'path' },
				}),
				experimental = {
					ghost_text = true,
				},
			})

		end	
	},
})


