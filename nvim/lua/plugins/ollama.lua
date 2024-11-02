return {
  "David-Kunz/gen.nvim",
  opts = {
    model = "mistral-nemo", -- The default model to use.
    display_mode = "split", -- The display mode. Can be "float" or "split" or "horizontal-split".
    show_prompt = true, -- Shows the prompt submitted to Ollama.
    init = function(options)
      pcall(io.popen, "ollama serve > /dev/null 2>&1 &")
    end,
    -- Function to initialize Ollama
    command = function(options)
      local body = { model = options.model, stream = true }
      return "curl --silent --no-buffer -X POST http://" .. options.host .. ":" .. options.port .. "/api/chat -d $body"
    end,
    debug = false, -- Prints errors and the command which is run.
  },
}
