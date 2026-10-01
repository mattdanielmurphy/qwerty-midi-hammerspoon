local hsWebview = require("hs.webview")
local HTML = require("keystep_ui_html")

local Monitor = {}
Monitor.__index = Monitor

local function nowSeconds()
  return hs.timer.absoluteTime() / 1000000000
end

function Monitor.new()
  return setmetatable({
    webview = nil,
    lastRenderAt = 0,
    pendingState = nil,
    renderTimer = nil,
  }, Monitor)
end

function Monitor:ensureWebview()
  if self.webview then return self.webview end

  local screen = hs.screen.mainScreen():frame()
  local width, height = 530, 420
  self.webview = hsWebview.new({
    x = screen.x + screen.w - width - 26,
    y = screen.y + 56,
    w = width,
    h = height,
  }, { developerExtrasEnabled = true })
    :windowStyle({ "titled", "closable", "utility" })
    :windowTitle("KeyStep Monitor")
    :allowTextEntry(false)
    :html(HTML)
    :deleteOnClose(false)

  return self.webview
end

function Monitor:render()
  self.renderTimer = nil
  self.lastRenderAt = nowSeconds()
  local state = self.pendingState
  self.pendingState = nil
  if not state or not self.webview then return end

  local encoded = hs.json.encode(state)
  if encoded then
    pcall(function()
      self.webview:evaluateJavaScript("window.updateKeyStepMonitor(" .. encoded .. ")")
    end)
  end
end

function Monitor:update(state)
  self:ensureWebview()
  self.pendingState = state
  local delay = math.max(0, 0.1 - (nowSeconds() - self.lastRenderAt))
  if self.renderTimer then return end
  if delay == 0 then
    self:render()
  else
    self.renderTimer = hs.timer.doAfter(delay, function() self:render() end)
  end
end

function Monitor:show(state)
  self:ensureWebview():show()
  self:update(state)
end

function Monitor:hide()
  if self.webview then self.webview:hide() end
end

function Monitor:toggle(state)
  self:ensureWebview()
  if self.webview:isVisible() then
    self:hide()
  else
    self:show(state)
  end
end

function Monitor:destroy()
  if self.renderTimer then self.renderTimer:stop() end
  self.renderTimer = nil
  if self.webview then self.webview:delete() end
  self.webview = nil
end

return Monitor
