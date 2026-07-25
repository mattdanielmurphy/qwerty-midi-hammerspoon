tell application "System Events"
  tell process "Logic Pro"
    return properties of UI elements of group 1 of window 1
  end tell
end tell
