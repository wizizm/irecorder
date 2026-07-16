tell application "Cursor" to activate
delay 0.8
tell application "System Events"
	set proc to first process whose frontmost is true
	set appName to name of proc
	try
		set fe to value of attribute "AXFocusedUIElement" of proc
		set r to role of fe
		set v to ""
		try
			set v to value of fe as text
		end try
		set vlen to length of v
		return "app=" & appName & " role=" & r & " valueLen=" & (vlen as text)
	on error errMsg
		return "app=" & appName & " err=" & errMsg
	end try
end tell
