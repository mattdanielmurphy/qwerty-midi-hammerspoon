      property minBPM : 5
      property maxBPM : 990

      on setExactBPM(targetBPM)
        set targetBPM to targetBPM as integer
        
        if targetBPM < minBPM then set targetBPM to minBPM
        if targetBPM > maxBPM then set targetBPM to maxBPM
        
        tell application "System Events"
          if not (exists process "Logic Pro") then return targetBPM
          tell process "Logic Pro"
            if not (exists window 1) then return targetBPM
            if not (exists group 1 of window 1) then return targetBPM
            set ctrlBar to ui element 1 of group 1 of window 1
            if not (exists ctrlBar) then return targetBPM
            
            set tempoSlider to missing value
            repeat with elem in (ui elements of ctrlBar)
              if description of elem is "Tempo" then
                set tempoSlider to elem
                exit repeat
              end if
            end repeat
            
            if tempoSlider is missing value then return targetBPM
            
            repeat 20 times
              set currentBPM to (value of tempoSlider) as integer
              set deltaBPM to targetBPM - currentBPM
              
              if deltaBPM = 0 then return currentBPM
              
              if deltaBPM > 0 then
                set goingUp to true
                set amountLeft to deltaBPM
              else
                set goingUp to false
                set amountLeft to -deltaBPM
              end if
              
              set tenSteps to amountLeft div 10
              repeat tenSteps times
                if goingUp then
                  perform action "AXIncrement" of tempoSlider
                else
                  perform action "AXDecrement" of tempoSlider
                end if
              end repeat
              
              set oneSteps to amountLeft mod 10
              repeat oneSteps times
                if goingUp then
                  perform action "AXIncrement" of tempoSlider
                else
                  perform action "AXDecrement" of tempoSlider
                end if
              end repeat
            end repeat
            return (value of tempoSlider) as integer
          end tell
        end tell
      end setExactBPM

      setExactBPM(140)
