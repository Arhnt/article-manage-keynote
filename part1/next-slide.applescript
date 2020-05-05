tell application "Keynote"
    activate
    try
    if playing is false then start the front document
    end try
    tell the front document -- or "tell document 1"
    -- my console_log("slide number of current slide: " & slide number of current slide, "my_log")
    -- my console_log("slide number of last slide: " & slide number of last slide, "my_log")
    if slide number of current slide is less than slide number of last slide then
        show next
    end if
    end tell
    
end tell
