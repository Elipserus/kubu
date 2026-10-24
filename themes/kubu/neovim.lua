-- Tema kubu: Tokyo Night con el fondo azul noche y acentos naranja/azul
return {
	{
		"folke/tokyonight.nvim",
		opts = {
			style = "night",
			on_colors = function(c)
				c.bg = "#0b1220"
				c.bg_dark = "#080e1a"
				c.orange = "#ff8700"
				c.blue = "#0087ff"
				c.yellow = "#ffaf5f"
			end,
			on_highlights = function(hl, c)
				hl.CursorLineNr = { fg = c.orange, bold = true }
				hl.LineNr = { fg = "#4a5a75" }
			end,
		},
	},
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "tokyonight",
		},
	},
}
