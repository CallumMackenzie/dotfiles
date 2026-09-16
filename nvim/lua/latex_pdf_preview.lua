local M = {}

local function remove_file(path)
  if path then
    vim.uv.fs_unlink(path)
  end
end

local function get_page_count(pdf)
  local result = vim.system({
    "gs",
    "-q",
    "-dNODISPLAY",
    "-dNOSAFER",
    "-sPDFFile=" .. pdf,
    "-c",
    "PDFFile (r) file runpdfbegin pdfpagecount = quit",
  }, { text = true }):wait()

  return tonumber(vim.trim(result.stdout or "")) or 1
end

local function get_file_stamp(path)
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return nil
  end

  return table.concat({ stat.mtime.sec, stat.mtime.nsec, stat.size }, ":")
end

function M.open()
  if vim.bo.filetype ~= "tex" and vim.bo.filetype ~= "plaintex" then
    vim.notify("Terminal PDF preview is only available in LaTeX buffers", vim.log.levels.WARN)
    return
  end

  if not vim.b.vimtex or not vim.b.vimtex.compiler then
    vim.notify("VimTeX is not initialized for this buffer", vim.log.levels.ERROR)
    return
  end

  local ok, pdf = pcall(vim.api.nvim_eval, "b:vimtex.compiler.get_file('pdf')")
  if not ok or type(pdf) ~= "string" or vim.fn.filereadable(pdf) ~= 1 then
    vim.notify("No compiled PDF found; run Space l l first", vim.log.levels.WARN)
    return
  end

  local page_count = get_page_count(pdf)
  local source_buffer = vim.api.nvim_get_current_buf()

  vim.cmd("botright vsplit")
  local window = vim.api.nvim_get_current_win()
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(window, buffer)
  vim.api.nvim_buf_set_name(
    buffer,
    "PDF Preview: " .. vim.fn.fnamemodify(pdf, ":t") .. " [" .. buffer .. "]"
  )
  vim.bo[buffer].buftype = "nowrite"
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].filetype = "image_nvim"
  vim.bo[buffer].modifiable = false
  vim.wo[window].colorcolumn = "0"
  vim.wo[window].cursorline = false
  vim.wo[window].number = false
  vim.wo[window].relativenumber = false
  vim.wo[window].signcolumn = "no"

  local state = {
    page = 1,
    image = nil,
    preview = nil,
    busy = false,
    closed = false,
    pdf_stamp = get_file_stamp(pdf),
    refresh_generation = 0,
  }

  local function render_page(page, quiet)
    if state.closed or state.busy then
      return
    end
    if page < 1 then
      vim.notify("Already at the first PDF page", vim.log.levels.INFO)
      return
    end
    if page > page_count then
      vim.notify("Already at the last PDF page", vim.log.levels.INFO)
      return
    end

    state.busy = true
    local next_preview = vim.fn.tempname() .. ".png"
    if not quiet then
      vim.notify(("Rendering PDF page %d/%d..."):format(page, page_count))
    end
    vim.system({
      "magick",
      "-density",
      "160",
      pdf .. "[" .. (page - 1) .. "]",
      "-background",
      "white",
      "-alpha",
      "remove",
      "-alpha",
      "off",
      next_preview,
    }, { text = true }, function(result)
      vim.schedule(function()
        state.busy = false
        if state.closed or not vim.api.nvim_buf_is_valid(buffer) then
          remove_file(next_preview)
          return
        end
        if result.code ~= 0 then
          remove_file(next_preview)
          local message = vim.trim(result.stderr or result.stdout or "Unknown ImageMagick error")
          vim.notify("PDF preview failed: " .. message, vim.log.levels.ERROR)
          return
        end

        local rendered, next_image = pcall(function()
          local image = require("image").from_file(next_preview, {
            window = window,
            buffer = buffer,
            max_width_window_percentage = 100,
            max_height_window_percentage = 100,
          })
          assert(image, "image.nvim rejected the rasterized PDF page")
          if state.image then
            state.image:clear()
          end
          image:render()
          return image
        end)
        if not rendered then
          remove_file(next_preview)
          vim.notify("The terminal could not render the PDF preview: " .. tostring(next_image), vim.log.levels.ERROR)
          return
        end

        remove_file(state.preview)
        state.image = next_image
        state.preview = next_preview
        state.page = page
        if not quiet then
          vim.notify(("PDF page %d/%d · j next · k previous · q close"):format(page, page_count))
        end
      end)
    end)
  end

  local keymap = vim.keymap.set
  keymap("n", "j", function() render_page(state.page + 1) end, {
    buffer = buffer,
    desc = "Next PDF page",
  })
  keymap("n", "k", function() render_page(state.page - 1) end, {
    buffer = buffer,
    desc = "Previous PDF page",
  })
  keymap("n", "q", "<cmd>close<cr>", { buffer = buffer, desc = "Close PDF preview" })

  local function refresh_after_compile(delay_ms, attempts)
    state.refresh_generation = state.refresh_generation + 1
    local generation = state.refresh_generation

    local function check_pdf()
      if state.closed or generation ~= state.refresh_generation then
        return
      end

      local stamp = get_file_stamp(pdf)
      if stamp and stamp ~= state.pdf_stamp and not state.busy then
        state.pdf_stamp = stamp
        page_count = get_page_count(pdf)
        render_page(math.min(state.page, page_count), true)
        return
      end

      attempts = attempts - 1
      if attempts > 0 then
        vim.defer_fn(check_pdf, 100)
      end
    end

    vim.defer_fn(check_pdf, delay_ms)
  end

  local restore_group = vim.api.nvim_create_augroup("LatexPdfPreview" .. buffer, { clear = true })

  local function restore_preview()
    vim.schedule(function()
      if
        state.closed
        or not state.image
        or not vim.api.nvim_win_is_valid(window)
        or vim.api.nvim_win_get_buf(window) ~= buffer
        or vim.api.nvim_win_get_tabpage(window) ~= vim.api.nvim_get_current_tabpage()
      then
        return
      end

      state.image:clear(true)
      state.image:render()
    end)
  end

  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
    group = restore_group,
    buffer = buffer,
    callback = restore_preview,
    desc = "Restore terminal PDF preview when its window becomes visible",
  })

  vim.api.nvim_create_autocmd("TabEnter", {
    group = restore_group,
    callback = restore_preview,
    desc = "Restore terminal PDF preview when its Neovim tab becomes visible",
  })

  vim.api.nvim_create_autocmd("User", {
    group = restore_group,
    pattern = "VimtexEventCompileSuccess",
    callback = function()
      local event_pdf_ok, event_pdf = pcall(vim.api.nvim_eval, "b:vimtex.compiler.get_file('pdf')")
      if
        not event_pdf_ok
        or type(event_pdf) ~= "string"
        or vim.fs.normalize(event_pdf) ~= vim.fs.normalize(pdf)
      then
        return
      end

      refresh_after_compile(0, 20)
    end,
    desc = "Refresh an open terminal PDF preview after successful compilation",
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = restore_group,
    buffer = source_buffer,
    callback = function()
      refresh_after_compile(100, 150)
    end,
    desc = "Refresh an open terminal PDF preview after an on-save build",
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buffer,
    once = true,
    callback = function()
      state.closed = true
      if state.image then
        state.image:clear()
      end
      remove_file(state.preview)
      pcall(vim.api.nvim_del_augroup_by_id, restore_group)
    end,
  })

  render_page(1)
end

return M
