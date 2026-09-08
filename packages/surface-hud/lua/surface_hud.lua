-- packages/surface-hud/lua/surface_hud.lua
-- Standalone, generic Surface HUD framework for Hammerspoon.
-- Renders customizable hardware surfaces (keys, pads, knobs) in a high-DPI WKWebView
-- with sub-millisecond IPC, 30 FPS coalescing, and WebKit anti-suspension audio sentinels.

local hsWebview = require("hs.webview")
local hsUsercontent = require("hs.webview.usercontent")

local SurfaceHUD = {}
SurfaceHUD.__index = SurfaceHUD

local function log(msg)
  print("[SurfaceHUD]: " .. tostring(msg))
end

function SurfaceHUD.new(opts)
  opts = opts or {}
  local self = setmetatable({}, SurfaceHUD)
  self.id = opts.id or "surface_hud"
  self.title = opts.title or "Surface HUD"
  self.baseWidth = opts.baseWidth or 980
  self.baseHeight = opts.baseHeight or 320
  self.scale = opts.scale or 1.0
  self.devServerUrl = opts.devServerUrl or "http://localhost:5173"
  self.useDevServer = (opts.useDevServer == true)
  self.onEventCallback = opts.onEvent or function() end
  self.activeLayer = "base"
  self.domReady = false
  self.webview = nil
  self.userContent = nil
  self.frame = nil
  self.lastFrameScale = nil

  return self
end

function SurfaceHUD:evaluateJS(js)
  if not self.webview then return false end
  local ok, err = pcall(function()
    self.webview:evaluateJavaScript(js)
  end)
  if not ok then
    log("evaluateJS error: " .. tostring(err))
  end
  return ok
end

function SurfaceHUD:updateControlState(id, pressed, active, extraClass)
  if not self.webview or not self.domReady then return end
  local js = string.format("if (window.updateControlState) window.updateControlState(%s, %s, %s, %s);",
    hs.json.encode(id),
    pressed and "true" or "false",
    active and "true" or "false",
    extraClass and hs.json.encode(extraClass) or "null"
  )
  self:evaluateJS(js)
end

function SurfaceHUD:setLayer(layerName)
  self.activeLayer = layerName or "base"
  if self.webview and self.domReady then
    self:evaluateJS(string.format("if (window.setActiveLayer) window.setActiveLayer(%s);", hs.json.encode(self.activeLayer)))
  end
end

function SurfaceHUD:renderState(statePayload)
  if not self.webview or not self.domReady then return end
  local jsonStr = hs.json.encode(statePayload or {})
  self:evaluateJS("if (window.renderSurfaceHud) window.renderSurfaceHud(" .. jsonStr .. ");")
end

function SurfaceHUD:loadLayout(layoutPayload)
  if not self.webview or not self.domReady then return end
  local jsonStr = hs.json.encode(layoutPayload or {})
  self:evaluateJS("if (window.loadSurfaceLayout) window.loadSurfaceLayout(" .. jsonStr .. ");")
end

function SurfaceHUD:createWebview()
  if self.webview then return self.webview end

  self.userContent = hsUsercontent.new("surfaceHudUC_" .. self.id)
  
  self.userContent:setCallback(function(body)
    if type(body) ~= "table" then return end

    if body.type == "domReady" then
      self.domReady = true
      log("DOM is ready in " .. self.id)
      if self.onDomReadyCallback then self.onDomReadyCallback() end
    elseif body.type == "controlAction" then
      self.onEventCallback("controlAction", body)
    elseif body.type == "controlClick" then
      self.onEventCallback("controlClick", body)
    elseif body.type == "layerChange" then
      self.activeLayer = body.layer
      self.onEventCallback("layerChange", body)
    elseif body.type == "ping" then
      -- Keepalive pong
      self:evaluateJS("if (window.onPong) window.onPong();")
    else
      self.onEventCallback(body.type or "unknown", body)
    end
  end)

  local screen = hs.screen.mainScreen():frame()
  local w = math.floor(self.baseWidth * self.scale)
  local h = math.floor(self.baseHeight * self.scale)
  local x = math.floor((screen.w - w) / 2)
  local y = math.floor(screen.h - h - 40)

  local rect = { x = x, y = y, w = w, h = h }

  local mask = hsWebview.masks.nonactivating |
               hsWebview.masks.titled |
               hsWebview.masks.closable |
               hsWebview.masks.utility |
               hsWebview.masks.HUD |
               hsWebview.masks.resizable

  self.webview = hsWebview.new(rect, {
    developerExtrasEnabled = true
  }, self.userContent)

  self.webview:windowStyle(mask)
  self.webview:closeOnEscape(false)
  self.webview:shadow(true)
  self.webview:level(hsWebview.levels.floating)
  self.webview:allowTextEntry(true)
  self.webview:transparent(true)

  -- Try Vite dev server first if configured, else fall back to bundled HTML
  local loaded = false
  if self.useDevServer then
    pcall(function()
      self.webview:url(self.devServerUrl)
      loaded = true
    end)
  end

  if not loaded then
    local ok, uiHtml = pcall(require, "ui_html")
    if ok and type(uiHtml) == "string" then
      self.webview:html(uiHtml)
    end
  end

  return self.webview
end

function SurfaceHUD:show()
  local wv = self:createWebview()
  if wv then wv:show() end
end

function SurfaceHUD:hide()
  if self.webview then self.webview:hide() end
end

function SurfaceHUD:toggle()
  if self.webview and self.webview:isVisible() then
    self:hide()
  else
    self:show()
  end
end

function SurfaceHUD:destroy()
  if self.webview then
    self.webview:delete()
    self.webview = nil
  end
  self.domReady = false
end

return SurfaceHUD
