local function setLogicBpm(bpmStr)
  local script = [[
    var pos = null;
    try {
      var se = Application('System Events');
      var logic = se.processes['Logic Pro'];
      if (logic && logic.exists()) {
        logic.frontmost = true;
        var win = logic.windows[0];
        if (win && win.exists()) {
          var grp = win.groups[0];
          if (grp && grp.exists()) {
            var ctrlBar = grp.uiElements[0];
            if (ctrlBar && ctrlBar.exists()) {
              var elems = ctrlBar.uiElements();
              for (var i = 0; i < elems.length; i++) {
                if (elems[i].description() === 'Tempo') {
                  pos = elems[i].position();
                  var size = elems[i].size();
                  pos = {x: pos[0] + size[0]/2, y: pos[1] + size[1]/2};
                  break;
                }
              }
            }
          }
        }
      }
    } catch(e) {}
    JSON.stringify(pos);
  ]]

  local exitCode, stdOut = hs.execute("/usr/bin/osascript -l JavaScript -e " .. string.format("%q", script))
  if exitCode == 0 and stdOut then
    local posStr = stdOut:match("({.-})")
    if posStr then
      local pos = hs.json.decode(posStr)
      if pos and pos.x and pos.y then
        local pt = hs.geometry.point(pos.x, pos.y)
        hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDown, pt):post()
        hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseUp, pt):post()
        hs.timer.usleep(50000) -- 50ms
        hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDown, pt):post()
        hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseUp, pt):post()
        
        hs.timer.usleep(100000) -- 100ms
        hs.eventtap.keyStrokes(bpmStr)
        hs.timer.usleep(50000)
        hs.eventtap.keyStroke({}, "return")
        return true
      end
    end
  end
  return false
end

print(setLogicBpm("126"))
