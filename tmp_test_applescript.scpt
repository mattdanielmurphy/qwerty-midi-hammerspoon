property minBPM : 5
property maxBPM : 990
on setExactBPM(targetBPM)
  set targetBPM to targetBPM as integer
  tell application "System Events"
    tell process "Logic Pro"
      set tempoSlider to slider 1 of group 1 of group 1 of window 1
      return value of tempoSlider
    end tell
  end tell
end setExactBPM
setExactBPM(140)
