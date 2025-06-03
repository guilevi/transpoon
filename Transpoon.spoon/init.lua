local inspect = hs.inspect

local Transpoon={}

Transpoon.name="Transpoon"
Transpoon.version=1.0
Transpoon.author="Guillem Leon <guilevi2000@gmail.com>"
Transpoon.license="UnLicense"
Transpoon.autoTranslate = false

local lastPhrase = "meow"
local lastTranslatedText = "meow"

local lastPhraseScript = [[
global spokenPhrase

tell application "VoiceOver"
	set spokenPhrase to the content of the last phrase
end tell

spokenPhrase
]]

local function getLastPhrase()
	if hs.application.get("VoiceOver") == nil then
		print("DEBUG: VoiceOver application not found")
		return
	end

    success, result, output = hs.osascript.applescript(lastPhraseScript)
    if not success then
        print("DEBUG: AppleScript failed:", inspect(output))
        return
    end

    if result:match("^%s*$") then
        print("DEBUG: Empty or whitespace-only result")
        return
    end

    print("DEBUG: Got phrase from VoiceOver:", inspect(result))
    return result
end

local function translateText(text,from,to)
    local query=hs.http.encodeForQuery(text)
    local url = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl='..from..'&tl='..to..'&dt=t&q='..query
    local headers={}
    headers["User-agent"]='Mozilla/5.0'
    local response, result, headers = hs.http.get(url, headers)
    local json = hs.json.decode(result)
    local translationResult = ""
    for k, v in pairs(json[1]) do
        translationResult = translationResult .. v[1]
    end
    return translationResult
end


local autoTranslateTimer

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
    
    -- Store the translated text we're about to speak to avoid retranslating it
    lastTranslatedText = text
    
    local script = speakScript:gsub("MESSAGE", function ()
        return text
    end)

	if text:match("^%s*$") then
		return
	end

    success, _, output = hs.osascript.applescript(script)
    if not success then
        print(inspect(output))
    end
end

local function checkLastPhrase()
    local phrase = getLastPhrase()
    
    if not phrase or phrase == lastPhrase then
        return
    end

    -- Check if this phrase is the same as our last translated text
    -- If so, don't translate it again to avoid infinite loops
    if phrase == lastTranslatedText then
        lastPhrase = phrase  -- Update lastPhrase to prevent continuous checking
        return
    end

    if not Transpoon.autoTranslate then
        print("DEBUG: Auto translate disabled")
        return
    end

    print("DEBUG: Proceeding with translation for phrase:", inspect(phrase))

    speak(" ￼ ") -- stop VO from speaking the last untranslated phrase
    lastPhrase = phrase
    speak(translateText(phrase, hs.settings.get('transpoon.sourceLanguage'), hs.settings.get('transpoon.destinationLanguage')))
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
local autoTranslateHotkey = hs.hotkey.new("ctrl-shift", "a", function()
    Transpoon.autoTranslate = not Transpoon.autoTranslate
    -- speak state
    speak("Auto translation is now " .. (Transpoon.autoTranslate and "enabled" or "disabled"))
    -- if active, run the thing
    checkLastPhrase()
    -- start the timer if enabled, stop it if disabled
    if Transpoon.autoTranslate then
        if not autoTranslateTimer then
            autoTranslateTimer = hs.timer.doEvery(0.05, checkLastPhrase)
        end
        autoTranslateTimer:start()
    else
        if autoTranslateTimer then
            autoTranslateTimer:stop()
            autoTranslateTimer = nil
        end
    end 
end)

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
    autoTranslateHotkey:enable()
    clipTransHotkey:enable()
    toLangHotkey:enable()
    
    -- Only start the auto-translate timer if auto-translate is enabled
    if Transpoon.autoTranslate then
        if not autoTranslateTimer then
            autoTranslateTimer = hs.timer.doEvery(0.1, checkLastPhrase)
        end
        autoTranslateTimer:start()
    end
end

function Transpoon.stop()
    transHotkey:disable()
    clipTransHotkey:disable()
    toLangHotkey:disable()
    
    -- Stop the auto-translate timer
    if autoTranslateTimer then
        autoTranslateTimer:stop()
    end
end

return Transpoon