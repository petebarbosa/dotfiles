return {
	"yetone/avante.nvim",
	build = vim.fn.has("win32") and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
		or "make",
	event = "VeryLazy",
	version = false,
	opts = {
		provider = "claude",
		providers = {
			claude = {
				endpoint = "https://api.anthropic.com",
				model = "claude-sonnet-4-20250514",
				timeout = 30000,
				extra_request_body = {
					temperature = 0.75,
					max_tokens = 20480,
				},
			},
		},
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"echasnovski/mini.pick", -- for file_selector provider mini.pick
		"nvim-telescope/telescope.nvim", -- for file_selector provider telescope
		"hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
		"ibhagwan/fzf-lua", -- for file_selector provider fzf
		"stevearc/dressing.nvim", -- for input provider dressing
		"folke/snacks.nvim", -- for input provider snacks
		"nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
		"zbirenbaum/copilot.lua", -- for providers='copilot'
		{
			-- support for image pasting
			"HakonHarnes/img-clip.nvim",
			event = "VeryLazy",
			opts = {
				-- recommended settings
				default = {
					embed_image_as_base64 = false,
					prompt_for_file_name = false,
					drag_and_drop = {
						insert_mode = true,
					},
				},
			},
		},
		{
			"MeanderingProgrammer/render-markdown.nvim",
			opts = {
				file_types = { "markdown", "Avante" },
			},
			ft = { "markdown", "Avante" },
		},
	},
}
