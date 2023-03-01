local inspect = hs.inspect

local Transpoon={}

Transpoon.name="Transpoon"
Transpoon.version=1.0
Transpoon.author="Guillem Leon <guilevi2000@gmail.com>"
Transpoon.license="UnLicense"

local lastPhraseScript = [[
global spokenPhrase

tell application "VoiceOver"
	set spokenPhrase to the content of the last phrase
end tell

spokenPhrase
]]

local function getLastPhrase()
	if hs.application.get("VoiceOver") == nil then
		return
	end

    success, result, output = hs.osascript.applescript(lastPhraseScript)
    if not success then
        print(inspect(output))
        return
    end

    if result:match("^%s*$") then
        return
    end

    return result
end

local speakScript = [[
tell application "VoiceOver"
	output "MESSAGE"
end tell
]]

local function speak(text)
    -- We can't pass the supplied message to string.gsub directly,
    -- because gsub uses '%' characters in the replacement string for capture groups
    -- and we can't guarantee that our message doesn't contain any of those.
print('speaking',inspect(text),'which is a ',type(text))
    local script = speakScript:gsub("MESSAGE", function ()
        return text:gsub("\"", "\\\"")
    end)

	if result:match("^%s*$") then
		return
	end

    success, _, output = hs.osascript.applescript(script)
    if not success then
        print(inspect(output))
    end
end

local function translateText(text,from,to)
    local query=hs.http.encodeForQuery(text)
    local url = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl='..from..'&tl='..to..'&dt=t&q='..query
headers={}
headers["User-agent"]='Mozilla/5.0'
 response, result, headers = hs.http.get(url, headers)
	local json = hs.json.decode(result)
	local translationResult = ""
	for k, v in pairs(json[1]) do
		translationResult = translationResult .. v[1]
	end
	return translationResult
end

local function transLastPhrase()
return speak(translateText(getLastPhrase(), hs.settings.get('transpoon.sourceLanguage'), hs.settings.get('transpoon.destinationLanguage')))
end

local function transClipboard()
    return speak(translateText(hs.pasteboard.getContents(), hs.settings.get('transpoon.sourceLanguage'), hs.settings.get('transpoon.destinationLanguage')))
    end

    local function setDestLanguage()
btn, text = hs.dialog.textPrompt('Destination language', 'Enter the code for the language to translate into',hs.settings.get('transpoon.destinationLanguage') or "",'Set','Open language code reference')
if btn == 'Open language code reference' then
        return hs.urlevent.openURL("https://cloud.google.com/translate/docs/languages")
end
return hs.settings.set('transpoon.destinationLanguage', text)
    end



local transHotkey = hs.hotkey.new("ctrl-shift", "t", transLastPhrase)
local clipTransHotkey = hs.hotkey.new("ctrl-shift", "y", transClipboard)
local toLangHotkey = hs.hotkey.new("ctrl-shift", "d", setDestLanguage)

function Transpoon.init()
    if not hs.settings.get('transpoon.sourceLanguage') then
hs.settings.set('transpoon.sourceLanguage', 'auto')
    end
    if not hs.settings.get('transpoon.destinationLanguage') then
        hs.settings.set('transpoon.destinationLanguage', hs.host.locale.details().languageCode)
            end
end

function Transpoon.start()
    transHotkey:enable()
    clipTransHotkey:enable()
    toLangHotkey:enable()
end

function Transpoon.stop()
    transHotkey:disable()
    clipTransHotkey:disable()
    toLangHotkey:enable()
end

return Transpoon