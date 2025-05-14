local function escapeHtml(str)
    if not str then return "" end
    str = string.gsub(str, "&", "&amp;")
    str = string.gsub(str, "<", "&lt;")
    str = string.gsub(str, ">", "&gt;")
    str = string.gsub(str, "\"", "&quot;")
    str = string.gsub(str, "'", "&#39;")
    str = string.gsub(str, "{", "&lbrace;")
    str = string.gsub(str, "}", "&rbrace;")
    return str
end

local function escapeJsonValue(str)
    if type(str) ~= "string" then return '""' end
    str = string.gsub(str, "\\", "\\\\")
    str = string.gsub(str, "\"", "\\\"")
    str = string.gsub(str, "\n", "\\n")
    str = string.gsub(str, "\t", "\\t")
    return '"' .. str .. '"'
end

local function ERR(triggerId, str, code)
    local errcode = code
    local message = nil

    if errcode == 0 then
        message = "No Image Prompt Found. Output is Not Correct"
    elseif errcode == 1 then
        message = "Not Closed With ']'. Check Output Token Length."
    elseif errcode == 2 then
        message = "Image Generate Failed. Check Low Level Acess."
    elseif errcode == 3 then
        message = "No Image Placeholder. Output is Not Correct."
    elseif errcode == 4 then
        message = "No Block Parsed. Output is Not Correct."
    end

    alertNormal(triggerId, "ERROR: " .. str .. ": " .. message)
end

local function getKakaoTime(now)
    now = now or os.date("*t")
    local hours = now.hour % 12 == 0 and 12 or now.hour % 12
    local minutes = string.format("%02d", now.min)
    local ampm = now.hour >= 12 and 'PM' or 'AM'
    local formattedTime = string.format("%d:%s %s", hours, minutes, ampm)
    return formattedTime
end

local function getPrompt(currentLine, prompt)
    print("ONLINEMODULE: getPrompt is in PROCESS!")

    local wholePattern = string.format("(%%[%s:.-%%])", prompt)

    print("ONLINEMODULE: Searching for pattern: " .. wholePattern)

    -- 전체 문자열에서 [prompt:...] 패턴을 찾음
    local wholeMatch = string.match(currentLine, wholePattern)
    if not wholeMatch then
        print("ONLINEMODULE: No match found for pattern: " .. wholePattern)
        return nil
    end

    -- wholematch에서 : 뒷부분의 값을 찾음, 줄바꿈까지 전부 캐치, ]전까지.
    local found = false
    local foundPrompt = string.match(wholeMatch, ":([%s%S]+)%]")

    print("ONLINEMODULE: Found match: " .. foundPrompt)

    return foundPrompt
end

local function getOldInlay(startPrefix, profileFlags, index, omIndex)
    -- 해당 index의 대화 내용에서 omIndex에 해당하는 블록의 {{inlay::random uuid}}값을 찾아 {{부터 }}까지 추출해 반환하는 함수
    print("ONLINEMODULE: getOldInlay is in PROCESS!")
    
    local chatFullHistory = getFullChat()
    if not chatFullHistory or not chatFullHistory[index] then
        print("ONLINEMODULE: Error: Chat history or message at index " .. tostring(index) .. " not found.")
        return
    end
    
    local currentChatMessage = chatFullHistory[index]
    local originalLine = currentChatMessage.data 

    local replacementMade = false
    local anyReplacementMade = false 
    local searchStartIndex = 1
    local foundInlay = nil
    local lastEnd = 1
    local tempLine = ""

    local fullPattern = string.format("(%s%%[.-%%])", startPrefix)
    
    while true do
        local s, e, capturedBlock = string.find(originalLine, fullPattern, searchStartIndex)

        if not s then
            tempLine = tempLine .. string.sub(originalLine, lastEnd)
            break
        end

        local startPrefixBlock = string.sub(originalLine, s, e)
        local searchPattern = nil
        
        if omIndex == 0 then
            searchPattern = "<OM>({{inlay::[^}]+}})"
        elseif omIndex > 0 then
            searchPattern = "<OM" .. omIndex .. ">({{inlay::[^}]+}})"  
        end
            
        if profileFlags == 1 then
            searchPattern = "|MEDIA:<OM>{{inlay::[^}]+}}"
        end
        
        foundInlay = string.match(startPrefixBlock, searchPattern)
        
        if foundInlay then
            tempLine = tempLine .. string.sub(originalLine, lastEnd, e)
            lastEnd = e + 1
            break
        else
            searchStartIndex = e + 1
        end
    end

    -- foundInlay에서 {{inlay::random uuid}}를 전부 추출
    if foundInlay then
        foundInlay = string.match(foundInlay, "{{inlay::[^}]+}}")
        if foundInlay then
            print("ONLINEMODULE: Found inlay: " .. foundInlay)
        else
            print("ONLINEMODULE: No inlay found in the block.")
        end
    else
        print("ONLINEMODULE: No inlay found in the block.")        
    end

    print("ONLINEMODULE: Found inlay: " .. foundInlay)
    return foundInlay

end

local function changeInlay(triggerId, index, oldInlay, newInlay)
    print("ONLINEMODULE: changeInlay is in PROCESS!")
    print("ONLINEMODULE: Attempting to replace ALL occurrences of: '" .. oldInlay .. "' with '" .. newInlay .. "' using specific pattern logic.")

    local chatFullHistory = getFullChat()
    if not chatFullHistory or not chatFullHistory[index] then
        print("ONLINEMODULE: Error: Chat history or message at index " .. tostring(index) .. " not found.")
        return
    end

    local currentChatMessage = chatFullHistory[index]
    local originalLine = currentChatMessage.data 
    local lineToModify = originalLine 

    local replacementMade = false
    local anyReplacementMade = false 
    local searchStartIndex = 1 

    local pattern = "({{[^}]+}})" 

    while true do
        local s_match, e_match = string.find(lineToModify, pattern, searchStartIndex)

        if s_match then
            local blockContent = string.sub(lineToModify, s_match, e_match)
            
            print("ONLINEMODULE: Found block: '" .. blockContent .. "' at current position " .. s_match .. "-" .. e_match .. " in (potentially modified) line.")

            if blockContent == oldInlay then
                print("ONLINEMODULE: Found block content matches oldInlay. Replacing.")
                
                local prefix = string.sub(lineToModify, 1, s_match - 1)
                local suffix = string.sub(lineToModify, e_match + 1)
                
                lineToModify = prefix .. newInlay .. suffix
                
                replacementMade = true 
                anyReplacementMade = true 

                searchStartIndex = string.len(prefix) + string.len(newInlay) + 1
                
                print("ONLINEMODULE: Line modified. Next search starts at: " .. searchStartIndex)

            else
                print("ONLINEMODULE: Block content '" .. blockContent .. "' does not match oldInlay '" .. oldInlay .. "'. Skipping.")
                searchStartIndex = e_match + 1 
            end
        else
            print("ONLINEMODULE: No more blocks found matching pattern in the rest of the line.")
            break
        end
        
        if searchStartIndex > string.len(lineToModify) then
            print("ONLINEMODULE: Search start index is beyond line length. Ending search.")
            break
        end
        if not replacementMade and s_match and searchStartIndex <= e_match then
             print("ONLINEMODULE: WARN: Potential stall in loop, advancing search index past current match.")
             searchStartIndex = e_match + 1
        end
        replacementMade = false 
    end

    if anyReplacementMade then
        if setChat then
            setChat(triggerId, index - 1, lineToModify) 
            print("ONLINEMODULE: Successfully updated message data for index " .. index .. " after all replacements.")
        else
            print("ONLINEMODULE: setChat function not found. Modified line (not applied):")
            print(lineToModify)
        end
    else
        print("ONLINEMODULE: No block matching oldInlay '" .. oldInlay .. "' found for replacement at index " .. index .. ".")
    end
end

local function convertDialogue(triggerId, data)
    print("ONLINEMODULE: convertDialogue is in PROCESS!")
    local OMCARD = getGlobalVar(triggerId, "toggle_OMCARD") or "0"
    local OMMESSENGER = getGlobalVar(triggerId, "toggle_OMMESSENGER") or "0"

    local lineToModify = data 

    local replacementMade = false
    local anyReplacementMade = false 
    local searchStartIndex = 1 

    local patterns = {
        '"(.-)"',
        '「(.-)」'
    }
    
    local prefixEroStatus = "EROSTATUS[NAME:NAME_PLACEHOLDER|DIALOGUE:"
    local suffixEroStatus = "|MOUTH:MOUTH_0|COMMENT_PLACEHOLDER|INFO_PLACEHOLDER|NIPPLES:NIPPLES_0|COMMENT_PLACEHOLDER|INFO_PLACEHOLDER|UTERUS:UTERUS_0|COMMENT_PLACEHOLDER|INFO_PLACEHOLDER|VAGINAL:VAGINAL_0|COMMENT_PLACEHOLDER|INFO_PLACEHOLDER|ANAL:ANAL_0|COMMENT_PLACEHOLDER|INFO_PLACEHOLDER|TIME:TIME_PLACEHOLDER|LOCATION:LOCATION_PLACEHOLDER|OUTFITS:OUTFITS_PLACEHOLDER|INLAY:INLAY_PLACEHOLDER]"
    local prefixSimulStatus = "SIMULSTATUS[NAME:NAME_PLACEHOLDER|DIALOGUE:"
    local suffixSimulStatus = "|TIME:TIME_PLACEHOLDER|LOCATION:LOCATION_PLACEHOLDER|INLAY:INLAY_PLACEHOLDER]"

    if OMCARD ~= "0" then
        local modifiedString = ""
        local currentIndex = 1
        local madeChange = false

        while currentIndex <= #lineToModify do
            local found = false
            local earliest_s = nil
            local earliest_e = nil
            local earliest_captured = nil
            local earliest_pattern = nil

            -- Find the earliest occurrence of any quote style
            for _, pattern in ipairs(patterns) do
                local s, e, captured = string.find(lineToModify, pattern, currentIndex)
                if s and (earliest_s == nil or s < earliest_s) then
                    earliest_s = s
                    earliest_e = e
                    earliest_captured = captured
                    found = true
                end
            end

            if found then
                modifiedString = modifiedString .. string.sub(lineToModify, currentIndex, earliest_s - 1)

                local replacementText
                if OMCARD == "1" then
                    replacementText = prefixEroStatus .. earliest_captured .. suffixEroStatus
                    madeChange = true
                elseif OMCARD == "2" or OMCARD == "3" then
                    replacementText = prefixSimulStatus .. earliest_captured .. suffixSimulStatus
                    madeChange = true
                end
                modifiedString = modifiedString .. replacementText
                currentIndex = earliest_e + 1
            else
                modifiedString = modifiedString .. string.sub(lineToModify, currentIndex)
                break
            end
        end

        if madeChange then
            lineToModify = modifiedString
            print("ONLINEMODULE: convertDialogue: Dialogues were modified based on OMCARD setting.")
        else
            print("ONLINEMODULE: convertDialogue: No dialogue modifications applied (no matching dialogues found).")
        end
    elseif OMMESSENGER == "1" then
        local modifiedString = ""
        local currentIndex = 1
        local madeChange = false

        while currentIndex <= #lineToModify do
            local found = false
            local earliest_s = nil
            local earliest_e = nil
            local earliest_captured = nil

            -- Find the earliest occurrence of any quote style
            for _, pattern in ipairs(patterns) do
                local s, e, captured = string.find(lineToModify, pattern, currentIndex)
                if s and (earliest_s == nil or s < earliest_s) then
                    earliest_s = s
                    earliest_e = e
                    earliest_captured = captured
                    found = true
                end
            end

            if found then
                modifiedString = modifiedString .. string.sub(lineToModify, currentIndex, earliest_s - 1)
                local now = os.date("*t")
                local replacementText = "KAKAO[" .. earliest_captured .. "|" .. getKakaoTime(now) .. "]"
                modifiedString = modifiedString .. replacementText
                madeChange = true
                currentIndex = earliest_e + 1
            else
                modifiedString = modifiedString .. string.sub(lineToModify, currentIndex)
                break
            end
        end

        if madeChange then
            lineToModify = modifiedString
            print("ONLINEMODULE: convertDialogue: Dialogues were modified for KAKAO format.")
        else
            print("ONLINEMODULE: convertDialogue: No dialogue modifications applied (no matching dialogues found).")
        end
    else
        print("ONLINEMODULE: convertDialogue: OMCARD and OMMESSENGER are not enabled, skipping dialogue modification.")
    end

    data = lineToModify 

    return data
end

local function inputEroStatus(triggerId, data)
    local OMCARDNOIMAGE = getGlobalVar(triggerId, "toggle_OMCARDNOIMAGE") or "0"
    local OMCARDTARGET = getGlobalVar(triggerId, "toggle_OMCARDTARGET") or "0"

    data = data .. [[
## Status Interface

### Erotic Status Interface
- Female's Erotic Status Interface, NOT THE MALE.
]]
        
    if OMCARDTARGET == "0" then
        data = data .. [[
- PRINT OUT {{user}}'s Erotic Status Interface.
- DO NOT PRINT other NPC's Status Interface.
- PRINT OUT with ONE-SENTENCE ONLY.
]]
    elseif OMCARDTARGET == "1" then
        data = data .. [[
- PRINT OUT {{char}}'s Erotic Status Interface.
- DO NOT PRINT other NPC's Status Interface.
- PRINT OUT with ONE-SENTENCE ONLY.
]]
    elseif OMCARDTARGET == "2" then
        data = data .. [[
- DO NOT PRINT "DIALOGUE" OUTSIDE OF EROSTATUS BLOCK.
- PRINT OUT ALL FEMALE CHARACTER's Erotic Status Interface.
- PRINT OUT with ONE-SENTENCE ONLY.
]]      
    end
    
    data = data .. [[
- DO NOT PRINT FEMALE's DIALOGUE via "" or 「」, REPLACE ALL FEMALE's DIALOGUE to EROSTATUS BLOCK.
    - DO NOT PRINT "dialogue" or 「dialogue」 OUTSIDE of EROSTATUS BLOCK(EROSTATUS[NAME:...|DIALOGUE:dialogue|...]).
        - PRINT EROSTATUS[...] INSTEAD.
    - DO NOT COMBINE THEM into ONE SENTENCE, SEPARATE THEM
- Example:
    - Invalid:
        - Choi Yujin briefly put down her pen and looked up at you. Her gaze was still calm and unwavering, but a subtle curiosity seemed to flicker within it. "And if you have a skill you are currently aware of, I would appreciate it if you could tell me its name and brief effect. Of course, accurate skill analysis will be done in the precision measurement room later, but basic information is needed." Her voice was soft, yet carried a hint of firmness. As if a skilled artisan were appraising a raw gemstone, she was cautiously exploring the unknown entity that was you.
    - Valid:
        - Choi Yujin briefly put down her pen and looked up at you. Her gaze was still calm and unwavering, but a subtle curiosity seemed to flicker within it.
        - EROSTATUS[NAME:Choi Yujin|DIALOGUE:"And if you have a skill you are currently aware of, I would appreciate it if you could tell me its name and brief effect."|...]
        - EROSTATUS[NAME:Choi Yujin|DIALOGUE:"Of course, accurate skill analysis will be done in the precision measurement room later, but basic information is needed."|...]
        - Her voice was soft, yet carried a hint of firmness. As if a skilled artisan were appraising a raw gemstone, she was cautiously exploring the unknown entity that was you.

#### Erotic Status Interface Template
- AI must follow this template:
    - EROSTATUS[NAME:(NPC's Name)|DIALOGUE:(NPC's Dialogue)|MOUTH:(Bodypart Image)|(Bodypart Comment)|(Bodypart Info)|NIPPLES:(Bodypart Image)|(Bodypart Comment)|(Bodypart Info)|UTERUS:(Bodypart Image)|(Bodypart Comment)|(Bodypart Info)|VAGINAL:(Bodypart Image)|(Bodypart Comment)|(Bodypart Info)|ANAL:(Bodypart Image)|(Bodypart Comment)|(Bodypart Info)|TIME:(TIME)|LOCATION:(LOCATION)|OUTFITS:(OUTFITS)|INLAY:(INLAY)]
    - NAME: English Name of NPC.
    - DIALOGUE: NPC's Dialogue.
        - DO NOT INCLUDE "", '' HERE.
    - MOUTH, NIPPLES, UTERUS, VAGINAL, ANAL: This is the Body parts Keyword.
    - Bodypart Image: Image of the Bodypart.
        - Each section consists of a keyword and a number: 0, 1, or 2 (e.g., MOUTH_0 OR UTERUS_2, etc.).
            - 0: This is the default state for each keyword.
            - 1: This is the aroused state for each keyword.
            - 2: This is the cum-showered or injected state for each keyword.
        - If Character is MALE, PRINT OUT "MALE" instead of the keyword.
    - Bodypart Comment:  A short, one-sentence self-assessment of the keyword from NPC's perspective.
        - Include NPC's real-time assessment, use erotic language
        - Do not include "" or ''.
    - Bodypart Comment: A short, two-sentence self-assessment of the keyword from NPC's perspective.
        - Do not include "" or ''. Must be short two phrases.
        - Include NPC's real-time assessment.
        - If NPC is aroused, use erotic language.
    - Bodypart Info: Each item must provides objective information.
        - Each item must be short.
        - ↔: Internally replaced with <br>.
            - Change the line with ↔(Upto 5 lines)
        - ALWAYS OBSERVE and PRINT the EXACT VALUE..
            - Invalid: Low probability, Considerable amount, Not applicable, ... , etc.
            - Valid: 13 %, 32 ml, 1921 counts, ... , etc.
            - List:
                - Mouth:
                    - Swallowed cum amount: Total amount of cum swallowed, 0~99999 ml
                    - ...
                - Nipples:
                    - Nipple climax experience: Count of climax with nipples, 0~99999 times
                    - Breast milk discharge amount: Total amount of breast milk, 0~99999 ml
                    - ...
                - Uterus:
                    - Menstual cycle: Follicular phase, Ovulatory phase, Luteal phase, Pregnancy, etc.
                    - Injected cum amount: Total amount of cum injected into the uterus, 0~99999 ml
                    - Pregnancy probability: 0~100 %
                    - ...
                - Vaginal:
                    - State: Virgin, Non-virgin, etc.
                    - Masturbation count: Total count of masturbation with fingers, 0~99999 times
                    - Vaginal intercourse count: Total count of penis round trips, 0~99999 times
                    - ...
                - Anal:
                    - State: Undeveloped
                    - Anal intercourse count: Total count of penis round trips, 0~99999 times
                    - Injected cum amount: Total amount of cum injected into the anal, 0~99999 ml
                    - ...
                - EACH ITEMS MUST NOT OVER 20 LETTERS.
                    - Korean: 1 LETTER.
                    - English: 0.5 LETTER.
                    - Blank space: 0.5 LETTER.
        - Please print out the total count from birth to now.
        - If character has no experience, state that character has no experience.
    - TIME: Current YYYY/MM/DD day hh:mm AP/PM (e.g., 2025/05/01 Thursday 02:12PM)
    - LOCATION: Current NPC's location and detail location.
    - OUTFITS: Current NPC's OUTFITS List.
        - EACH ITEMS MUST NOT OVER 20 LETTERS.
            - Korean: 1 LETTER.
            - English: 0.5 LETTER.
            - Blank space: 0.5 LETTER.
        - NO () BRACKET ALLOWED.
        - Type:
            - Headwear: Hair, Hair color, Hair style.
            - Top: Top, Color, Style.
            - Bra: Bra, Color, Style.
            - Breasts: Breasts, Size, Color and size of the nipple and areola.
            - Bottom: Bottom, Color, Style.
            - Panties: Panties, Color, Style.
            - Pussy: Pussy, Degree of opening, Shape of pussy hair.
            - Legs: Legs, Color, Style.
            - Feet: Feet, Color, Style.
                

    - INLAY: This is a Flag.  
]]

    if OMCARDNOIMAGE == "0" then
        data = data .. [[
        - Just print <OM(INDEX)> Exactly.
]]
    elseif OMCARDNOIMAGE == "1" then
        data = data .. [[
        - Just print <NOIMAGE> Exactly.        
]]
    end
            
    if OMCARDNOIMAGE == "0" then
        data = data .. [[
        - Example:
            - If the status interface is the first one, print '<OM1>'.
            - If the status interface is the second one, print '<OM2>'.
            - If the status interface is the third one, print '<OM3>'.
            - ...
]]
    end

    if OMCARDNOIMAGE == "0" then
        data = data .. [[
        - Example:
            - EROSTATUS[NAME:Diana|DIALOGUE:Dear {{user}}, is the tea to your liking?|MOUTH:MOUTH_0|I just took a sip of tea. Only the fragrance of the tea remains for now.|Oral sex experience: 0 times↔Swallowed cum amount: 0 ml|NIPPLES:NIPPLES_0|I'm properly wearing underwear beneath my dress. I don't feel anything in particular.|Nipple climax experience: 0 times↔Breast milk discharge amount: 0 ml|UTERUS:UTERUS_0|Inside my body... there's still no change. Of course!|Menst: Ovulating↔Injected cum amount: 1920 ml↔Pregnancy probability: 78%|VAGINAL:VAGINAL_2|Ah, Brother {{user}}!|State: Non-virgin↔Masturbation count: 1234 times↔Vaginal intercourse count: 9182 times↔Total vaginal ejaculation amount: 3492 ml↔Vaginal ejaculation count: 512 times|ANAL:ANAL_0|It's, it's dirty! Even thinking about it is blasphemous!|State: Undeveloped↔Anal intercourse count: 0 times↔Total anal ejaculation amount: 0 ml↔Anal ejaculation count: 0 times|TIME:0000/07/15 Monday, 02:30 PM|LOCATION:Rose Garden Tea Table at Marquis Mansion|OUTFITS:→Hair: White wavy hair←→Top: Elegant white dress revealing neckline and shoulders←→Bra: White silk brassiere, Not visible←→Breasts: Modest C-cup breasts, small light pink nipples and areolas, Not visible←→Bottom: Voluminous white dress skirt←→Panties: White silk panties, Not visible←→Pussy: Neatly maintained pubic hair, tightly closed straight pussy, Not visible←→Legs: White stockings←→Feet: White strap shoes←|INLAY:<OM1>]
]]
    elseif OMCARDNOIMAGE == "1" then
        data = data .. [[
        - Example:
            - EROSTATUS[NAME:Diana|DIALOGUE:Dear {{user}}, is the tea to your liking?|MOUTH:MOUTH_0|I just took a sip of tea. There's still only the fragrance of the tea water remaining.|Oral sex experience: 0 times↔Swallowed cum amount: 0 ml|NIPPLES:NIPPLES_0|I'm properly wearing underwear beneath my dress. I don't feel anything special.|Nipple climax experience: 0 times↔Breast milk discharge amount: 0 ml|UTERUS:UTERUS_0|Inside my body... there's still no change at all. Of course!|Menstual: Ovulation cycle↔Injected cum amount: 1920 ml↔Pregnancy probability: 78%|VAGINAL:VAGINAL_2|Aah, brother {{user}}.|State: Non-virgin↔Masturbation count: 1234 times↔Vaginal penetration count: 9182 times↔Total vaginal ejaculation amount: 3492 ml↔Vaginal ejaculation count: 512 times|ANAL:ANAL_0|It's, it's dirty! It's sacrilegious to even think about this place!|State: Undeveloped↔Anal penetration count: 0 times↔Total anal ejaculation amount: 0 ml↔Anal ejaculation count: 0 times|TIME:0000/07/15 Monday, 02:30 PM|LOCATION:Rose garden tea table at the Marquis mansion|OUTFITS:→Hair: White wavy hair←→Top: Elegant white dress revealing neck and shoulder lines←→Bra: White silk brassiere, Not visible←→Breasts: Modest C-cup breasts, light pink small nipples and areolas, Not visible←→Bottom: Full white dress skirt←→Panties: White silk panties, Not visible←→Pussy: Neatly maintained pubic hair, firmly closed straight-line pussy, Not visible←→Legs: White stockings←→Feet: White strap shoes←|INLAY:<NOIMAGE>]
]]
    end
    data = data .. [[
            - If Character is MALE.
                - EROSTATUS[NAME:Siwoo|DIALOGUE:Hmmm|MOUTH:MALE|Noway. I can't believe it.|MALE|NIPPLES:MALE|Ha?|MALE||TERUS:MALE|I don't have one.|MALE|VAGINAL:MALE|I don't have one.|MALE|ANAL:MALE|I don't have one.|MALE|TIME:0000/07/15 Monday, 02:30 PM|LOCATION:Rose garden tea table at the Marquis mansion|OUTFITS:→Hair: Black sharp hair←→Top: Black Suit←→Bottom: Black suit pants←→Panties: Gray trunk panties, Not visible←→Penis: 18cm, Not visible←→Legs: Gray socks←→Feet: Black shoes←|INLAY:<OM1>]
]]

    return data
end

local function changeEroStatus(triggerId, data)
    local OMCARDNOIMAGE = getGlobalVar(triggerId, "toggle_OMCARDNOIMAGE") or "0"
    local OMCARDTARGET = getGlobalVar(triggerId, "toggle_OMCARDTARGET") or "0"

    local erostatusPattern = "EROSTATUS%[([^%]]*)%]"
    data = string.gsub(data, erostatusPattern, function(replacements)
        local EroStatusTemplate = [[
<style>
@import url('https://fonts.googleapis.com/css2?family=Pixelify+Sans:wght@400..700&display=swap');
* { box-sizing: border-box; margin: 0; padding: 0; }
.card-wrapper { width: 100%; max-width: 360px; border: 4px solid #000000; background-color: #ffe6f2; font-family: 'Pixelify Sans', sans-serif; user-select: none; -webkit-user-select: none; -moz-user-select: none; -ms-user-select: none; cursor: default; padding: 10px; box-shadow: 4px 4px 0px #000000; margin-left: auto; margin-right: auto; }
.image-area { 
width: 100%; 
height: 100%; 
aspect-ratio: 1/1.75; 
position: relative; 
overflow: hidden; 
margin-bottom: 10px; 
box-shadow: 4px 4px 0px #000000; 
display: flex; 
align-items: center; 
justify-content: center; 
}
.image-area img { 
display: block; 
max-width: 100%; 
max-height: 100%; 
width: auto; 
height: 100%; 
margin: 0 auto; 
border: 3px solid #000000; 
border-radius: 0; 
box-shadow: 2px 2px 0px #ff69b4; 
background: #fff; 
object-fit: cover; 
object-position: center center; 
}
.inlay-background-image { 
position: absolute; 
top: 0; 
left: 0; 
width: 100%; 
height: 100%; 
object-fit: cover; 
object-position: center center; 
z-index: 0; 
pointer-events: none; 
}
#static-info-content,#outfit-list-content { background-color: rgba(255, 255, 255, 0.9); border: 3px solid #000000; padding: 8px 12px; color: #000000; font-size: 11px; line-height: 1.4; box-shadow: 4px 4px 0px #000000; border-radius: 0; text-align: left; width: 100%; }
#static-info-content { margin-bottom: 10px; }
#static-info-content div { margin-bottom: 4px; }
#static-info-content div:last-child { margin-bottom: 0; }
#outfit-list-content span { display: block; margin-bottom: 4px; }
#outfit-list-content span:last-child { margin-bottom: 0; }
.pink-overlay { position: absolute; top: 0; left: 0; width: 100%; height: 100%; background: radial-gradient( circle at center, rgba(255, 105, 180, 0.7) 0%, rgba(255, 105, 180, 0.4) 90% ); opacity: 0; pointer-events: none; transition: opacity 0.8s ease-in-out; z-index: 1; }
.overlay-content { position: absolute; top: 0; left: 0; width: 100%; height: 100%; opacity: 0; pointer-events: none; transition: opacity 0.8s ease-in-out; z-index: 2; display: flex; flex-direction: column; align-items: stretch; }
.image-area:hover .pink-overlay,.image-area:hover .overlay-content { opacity: 1; }
.image-area:hover .overlay-content { pointer-events: auto; }
.placeholder-wrapper { flex: 1; min-height: 0; width: 100%; position: relative; pointer-events: auto; cursor: pointer; overflow: hidden; }
.placeholder-image {
display: block;
width: 100%;
height: auto;
max-width: 100%;
min-width: 100%;
object-fit: cover;
position: absolute;
left: 0;
right: 0;
top: 50%;
transform: translateY(-50%);
background-color: #ffffff;
border: 3px solid #000000;
box-shadow: 3px 3px 0px #000000;
pointer-events: none;
border-radius: 0;
}
.placeholder-wrapper {
display: flex;
align-items: center;
justify-content: stretch;
position: relative;
}
.placeholder-wrapper:hover .placeholder-text-box { opacity: 0; }
.placeholder-text-box { position: absolute; top: 2%; right: 2%; width: max-content; max-width: 90%; background-color: rgba(255, 255, 255, 0.9); border: 3px solid #000000; border-radius: 0; font-size: 11px; color: #000000; z-index: 2; pointer-events: none; text-align: center; opacity: 1; transition: opacity 0.8s ease; }
.placeholder-wrapper::before { content: ''; position: absolute; top: 0; left: 0; width: 100%; height: 100%; background-color: rgba(255, 105, 180, 0.2); opacity: 0; transition: opacity 0.8s ease; pointer-events: none; z-index: 3; border-radius: 0; }
.hover-text-content { position: absolute; top: 10%; right: 2%; width: 100%; height: 100%; display: flex; justify-content: right; align-items: flex-start; box-sizing: border-box; font-size: 90%; line-height: 1.3; font-weight: bold; color: #000000; text-align: right; opacity: 0; transition: opacity 0.8s ease; pointer-events: none; z-index: 4; white-space: pre-line; overflow: hidden; padding: 0; padding-top: 1.5%; line-height: 0.5; margin: 0; }
.placeholder-wrapper:hover::before,.placeholder-wrapper:hover .hover-text-content { opacity: 1; }
.dialogue-overlay {
position: absolute;
bottom: 0;
background-color: rgba(255, 230, 242, 0.95);
border: 2px solid #000000;
box-shadow: 2px 2px 0px rgba(0, 0, 0, 0.8);
font-size: 15px;
font-weight: bold;
color: #000000;
line-height: 1.5;
z-index: 5;
word-wrap: break-word; 
width: 100%; 
opacity: 1;
transition: opacity 0.8s ease-out;
pointer-events: none;
}
.image-area:hover .dialogue-overlay {
opacity: 0;
}
</style>
]]

        local keyLookaheadPattern = "^([A-Za-z_]+):"
        local keyPattern = "^([A-Za-z_]+):(.*)$"

        local segments = {}
        for seg in string.gmatch(replacements, "([^|]+)") do
            table.insert(segments, seg)
        end

        local function trim(s)
            return (s and s:match("^%s*(.-)%s*$")) or ""
        end

        local parsed = {}
        for i = 1, #segments do
            local seg = trim(segments[i])
            local key, value = seg:match(keyPattern)
            if key then
            key = trim(key)
            value = trim(value)
            if key == "MOUTH" or key == "NIPPLES" or key == "UTERUS" or key == "VAGINAL" or key == "ANAL" then
                parsed[key .. "_0"] = value
                parsed[key .. "_1"] = trim(segments[i+1] or "")
                parsed[key .. "_2"] = trim(segments[i+2] or "")
                i = i + 2
            elseif key == "NAME" or key == "DIALOGUE" or key == "TIME" or key == "LOCATION" or key == "OUTFITS" or key == "INLAY" then
                parsed[key] = value
            end
            end
        end

        local function getPart(base, idx)
            idx = tostring(idx)
            return parsed[base .. "_" .. idx] or ""
        end

        local npcName = parsed["NAME"]
        local npcDialogue = parsed["DIALOGUE"]
        local timeText = parsed["TIME"]
        local locationText = parsed["LOCATION"]
        local outfitsText = parsed["OUTFITS"]
        local inlayContent = parsed["INLAY"]

        -- INLAY 에서 <OM(INDEX)> 를 찾아서 INDEX 번호만 추출
        local inlayIndex = string.match(inlayContent, "<OM(%d+)>")

        local mouthImg   = getPart("MOUTH", 0)
        local mouthText  = getPart("MOUTH", 1)
        local mouthHover = getPart("MOUTH", 2)
        local nipplesImg   = getPart("NIPPLES", 0)
        local nipplesText  = getPart("NIPPLES", 1)
        local nipplesHover = getPart("NIPPLES", 2)
        local uterusImg   = getPart("UTERUS", 0)
        local uterusText  = getPart("UTERUS", 1)
        local uterusHover = getPart("UTERUS", 2)
        local vaginalImg   = getPart("VAGINAL", 0)
        local vaginalText  = getPart("VAGINAL", 1)
        local vaginalHover = getPart("VAGINAL", 2)
        local analImg   = getPart("ANAL", 0)
        local analText  = getPart("ANAL", 1)
        local analHover = getPart("ANAL", 2)

        local html = {}

        table.insert(html, EroStatusTemplate)
        table.insert(html, "<div class=\"card-wrapper\">")
        table.insert(html, "<div id=\"static-info-content\">")
        table.insert(html, "<div>" .. npcName .. "</div>")
        table.insert(html, "<div>" .. timeText .. "</div>")
        table.insert(html, "<div>" .. locationText .. "</div>")
        table.insert(html, "</div>")
        table.insert(html, "<div class=\"image-area\">")
            
        if OMCARDNOIMAGE == "0" then
            local temp_content = ""
            if inlayContent then
                temp_content = string.gsub(inlayContent, "<!%-%-.-%-%->", "")
            end
            table.insert(html, temp_content)
        elseif OMCARDNOIMAGE == "1" then
            local target = "user"
            if tostring(OMCARDTARGET) == "1" then target = "char" end
            table.insert(html, "<img src='{{source::" .. target .. "}}'>")
        end

        if npcDialogue and npcDialogue ~= "" then
            table.insert(html, "<div class=\"dialogue-overlay\">" .. npcDialogue .. "</div>")
        end


        table.insert(html, "<div class=\"pink-overlay\"></div>")
        table.insert(html, "<div class=\"overlay-content\">")

        table.insert(html, "<div class=\"placeholder-wrapper\">")
        if mouthImg and mouthImg ~= "" then
            table.insert(html, "<img src=\"{{raw::" .. mouthImg .. ".png}}\" class=\"placeholder-image\" draggable=\"false\">")
        end
        table.insert(html, "<div class=\"placeholder-text-box\">" .. mouthText .. "</div>")
        table.insert(html, "<div class=\"hover-text-content\">" .. mouthHover .. "</div>")
        table.insert(html, "</div>")

        table.insert(html, "<div class=\"placeholder-wrapper\">")
        if nipplesImg and nipplesImg ~= "" then
            table.insert(html, "<img src=\"{{raw::" .. nipplesImg .. ".png}}\" class=\"placeholder-image\" draggable=\"false\">")
        end
        table.insert(html, "<div class=\"placeholder-text-box\">" .. nipplesText .. "</div>")
        table.insert(html, "<div class=\"hover-text-content\">" .. nipplesHover .. "</div>")
        table.insert(html, "</div>")

        table.insert(html, "<div class=\"placeholder-wrapper\">")
        if uterusImg and uterusImg ~= "" then
            table.insert(html, "<img src=\"{{raw::" .. uterusImg .. ".png}}\" class=\"placeholder-image\" draggable=\"false\">")
        end
        table.insert(html, "<div class=\"placeholder-text-box\">" .. uterusText .. "</div>")
        table.insert(html, "<div class=\"hover-text-content\">" .. uterusHover .. "</div>")
        table.insert(html, "</div>")

        table.insert(html, "<div class=\"placeholder-wrapper\">")
        if vaginalImg and vaginalImg ~= "" then
            table.insert(html, "<img src=\"{{raw::" .. vaginalImg .. ".png}}\" class=\"placeholder-image\" draggable=\"false\">")
        end
        table.insert(html, "<div class=\"placeholder-text-box\">" .. vaginalText .. "</div>")
        table.insert(html, "<div class=\"hover-text-content\">" .. vaginalHover .. "</div>")
        table.insert(html, "</div>")

        table.insert(html, "<div class=\"placeholder-wrapper\">")
        if analImg and analImg ~= "" then
            table.insert(html, "<img src=\"{{raw::" .. analImg .. ".png}}\" class=\"placeholder-image\" draggable=\"false\">")
        end
        table.insert(html, "<div class=\"placeholder-text-box\">" .. analText .. "</div>")
        table.insert(html, "<div class=\"hover-text-content\">" .. analHover .. "</div>")
        table.insert(html, "</div>")

        table.insert(html, "</div>")
        table.insert(html, "</div>")
        table.insert(html, "<div id=\"outfit-list-content\">" .. outfitsText .. "</div>")
        
        -- 리롤 버튼 추가 - 추출한 INDEX 값 기반으로 identifier 설정
        local buttonJson = '{"action":"EROSTATUS_REROLL", "identifier":"' .. npcName .. '", "index":"' .. inlayIndex ..'"}'

        table.insert(html, "<div class=\"reroll-button-wrapper\">")
        table.insert(html, "<div class=\"global-reroll-controls\">")
        table.insert(html, "<button style=\"text-align: center;\" class=\"reroll-button\" risu-btn='" .. buttonJson .. "'>EROSTATUS</button>")
       
        table.insert(html, "</div></div>")
        table.insert(html, "</div><br>")

        return table.concat(html, "\n")
    end)
    return data
end

local function inputSimulCard(triggerId, data)
    local OMCARDNOIMAGE = getGlobalVar(triggerId, "toggle_OMCARDNOIMAGE") or "0"

    data = data .. [[
## Status Interface
### Simulation Status Interface
- DO NOT PRINT DIALOGUE via "" or 「」, REPLACE ALL DIALOGUE to SIMULSTATUS BLOCK.
    - DO NOT PRINT "dialogue" or 「dialogue」 OUTSIDE of SIMULSTATUS BLOCK(SIMULSTATUS[NAME:...|DIALOGUE:dialogue|...]).
        - PRINT SIMULSTATUS[...] INSTEAD.
    - DO NOT COMBINE THEM into ONE SENTENCE, SEPARATE THEM
    - Example:
        - Invalid:
            - Choi Yujin briefly put down her pen and looked up at you. Her gaze was still calm and unwavering, but a subtle curiosity seemed to flicker within it. "And if you have a skill you are currently aware of, I would appreciate it if you could tell me its name and brief effect. Of course, accurate skill analysis will be done in the precision measurement room later, but basic information is needed." Her voice was soft, yet carried a hint of firmness. As if a skilled artisan were appraising a raw gemstone, she was cautiously exploring the unknown entity that was you.
        - Valid:
            - Choi Yujin briefly put down her pen and looked up at you. Her gaze was still calm and unwavering, but a subtle curiosity seemed to flicker within it.
            - SIMULSTATUS[NAME:Choi Yujin|DIALOGUE:"And if you have a skill you are currently aware of, I would appreciate it if you could tell me its name and brief effect."|...]
            - SIMULSTATUS[NAME:Choi Yujin|DIALOGUE:"Of course, accurate skill analysis will be done in the precision measurement room later, but basic information is needed."|...]
            - Her voice was soft, yet carried a hint of firmness. As if a skilled artisan were appraising a raw gemstone, she was cautiously exploring the unknown entity that was you.
- Do not change the name if exists.
- Replace the "dialogue" of all living things, not just humans, with Status blocks.
    - Even if the dialogue is short, it must be replaced with the Status block.
    - Example:
        - Invalid: Bulbasaur chirped happily, letting out a short "Bulba-!" sound.
        - Valid: Bulbasaur chirped happily, letting out a short sound. SIMULSTATUS[NAME:Bulbasaur|DIALOGUE:Bulba-!|TIME:2025/05/01 Thursday 02:12PM|LOCATION:Kanto region, Pallet Town, Professor Oak's Laboratory|INLAY:<OM1>]       


#### Simulation Status Interface: Template
- SIMULSTATUS[NAME:(NPC's Name)|DIALOGUE:(NPC's Dialogue)|TIME:(Time)|LOCATION:(LOCATION)|INLAY:(INLAY)]
- NAME: English Name of NPC.
- DIALOGUE: The dialogue of the NPC.
    - Make sure to include NPC's dialogue here
    - Do not include any other NPC's dialogue or actions.
    - Do not include ' and " in the dialogue.
- TIME: Current YYYY/MM/DD day hh:mm AP/PM (e.g., 2025/05/01 Thursday 02:12PM)
- LOCATION: The location of the NPC.
- INLAY: This is a Flag.
]] 
    if OMCARDNOIMAGE == "0" then
        data = data .. [[
    - Just print <OM(INDEX)> Exactly.
]]
    elseif OMCARDNOIMAGE == "1" then
        data = data .. [[
    - Just print <NOIMAGE> Exactly.   
]]             
    end

    if OMCARDNOIMAGE == "0" then
        data = data .. [[  
    - Example:
        - If the status interface is the first one, print '<OM1>'.
        - If the status interface is the second one, print '<OM2>'.
        - If the status interface is the third one, print '<OM3>'.
        - ...
- Example:
    - SIMULSTATUS[NAME:Yang Eun-young|DIALOGUE:If I'm with {{user}}, anyth-anything is good!|TIME:2025/05/01 Thursday 02:12PM|LOCATION:Eun-young's room, on the bed|INLAY:<OM1>]
    - Describe the situation (e.g., Eun-Young was happy....)
]]  
    else
        data = data .. [[
- Example:
    - SIMULSTATUS[NAME:Yang Eun-young|DIALOGUE:If I'm with {{user}}, anyth-anything is good!|TIME:2025/05/01 Thursday 02:12PM|LOCATION:Eun-young's room, on the bed|INLAY:<NOIMAGE>]
    - Describe the situation (e.g., Eun-Young was happy....)
]]
    end

    return data
end

local function changeSimulCard(triggerId, data)
    local OMCARDNOIMAGE = getGlobalVar(triggerId, "toggle_OMCARDNOIMAGE") or "0"

    local simulPattern = "(SIMULSTATUS)%[NAME:([^|]*)|DIALOGUE:([^|]*)|TIME:([^|]*)|LOCATION:([^|]*)|INLAY:([^%]]*)%]"
    data = string.gsub(data, simulPattern, function(
        start_pattern, name, dialogue, time, location, inlayContent
        )
        local SimulBotTemplate = [[
<style>
@import url('https://fonts.googleapis.com/css2?family=Pixelify+Sans:wght@400..700&display=swap');
* {box-sizing: border-box;margin: 0;padding: 0;}
body { background-color: #f0f0f0;padding: 20px;}
.status-card {width: 100%;max-width: 360px;margin: 20px auto;background-color:rgb(174, 193, 255);border: 3px solid #000000; box-shadow: 4px 4px 0px #000000;padding: 15px;font-family: 'Pixelify Sans', sans-serif; user-select: none;-webkit-user-select: none;-moz-user-select: none;-ms-user-select: none;cursor: default;}
.content-area {position: relative; margin-bottom: 15px; }
.placeholder-content {border: 3px solid #000000;background-color: #ffffff;padding: 15px; font-size: 13px;color: #555555;box-shadow: 3px 3px 0px #000000;min-height: 100px;line-height: 1.4;word-wrap: break-word;position: relative; z-index: 1; }
.simul-dialogue-overlay {position: absolute;bottom: 20px; left: 18px;right: 18px; background-color: rgba(183, 195, 255, 0.95); border: 2px solid #000000;box-shadow: 2px 2px 0px rgba(0, 0, 0, 0.8);padding: 8px 12px;font-size: 15px;font-weight: bold;color: #000000;line-height: 1.5;z-index: 10;word-wrap: break-word; max-width: calc(100% - 36px);}
.details-info {background-color: rgba(255, 255, 255, 0.9);border: 3px solid #000000;padding: 10px 15px;box-shadow: 3px 3px 0px #000000;font-size: 14px;line-height: 1.5;}.info-line {margin-bottom: 8px;color: #000000;word-wrap: break-word;}
.info-line:last-child {margin-bottom: 0;}
.info-line .label {font-weight: bold;color:rgb(105, 170, 255);margin-right: 5px;}
.info-line .value {color: #000000;}
</style>
]] 

        
        -- INLAY 에서 <OM(INDEX)> 를 찾아서 INDEX 번호만 추출
        local inlayIndex = string.match(inlayContent, "<OM(%d+)>")

        local html = {}
        table.insert(html, SimulBotTemplate)
        table.insert(html, "<div class=\"status-card\">")
        table.insert(html, "<div class=\"content-area\">")

        if OMCARDNOIMAGE == "0" then
            table.insert(html, "    <div class=\"placeholder-content\">" .. (inlayContent or "") .. "</div>")
        elseif OMCARDNOIMAGE == "1" then
            local styleAttribute = " style=\"background-image: url('{{source::char}}'); background-size: cover; background-position: center; background-repeat: no-repeat; background-color: transparent;\""
            table.insert(html, "    <div class=\"placeholder-content\"" .. styleAttribute .. "></div>")
        end

        table.insert(html, "<div class=\"simul-dialogue-overlay\">" .. (dialogue or "") .. "</div>")
        table.insert(html, "</div>")
        table.insert(html, "<div class=\"details-info\">")
        table.insert(html, "<div class=\"info-line\">")
        table.insert(html, "<span class=\"label\">NAME:</span>")
        table.insert(html, "<span class=\"value\">" .. (name or "") .. "</span>")
        table.insert(html, "</div>")
        table.insert(html, "<div class=\"info-line\">")
        table.insert(html, "<span class=\"label\">TIME:</span>")
        table.insert(html, "<span class=\"value\">" .. time .. "</span>")
        table.insert(html, "</div>")
        table.insert(html, "<div class=\"info-line\">")
        table.insert(html, "<span class=\"label\">LOCATION:</span>")
        table.insert(html, "<span class=\"value\">" .. location .. "</span>")
        table.insert(html, "</div>")
        table.insert(html, "</div>")

        -- 리롤 버튼 추가 - 추출한 name 값 기반으로 identifier 설정
        local buttonJson = '{"action":"SIMCARD_REROLL", "identifier":"' .. (name or "") .. '", "index":"' .. inlayIndex .. '"}'
        
        table.insert(html, "<div class=\"reroll-button-wrapper\">")
        table.insert(html, "<div class=\"global-reroll-controls\">")
        table.insert(html, "<button style=\"text-align: center;\" class=\"reroll-button\" risu-btn='" .. buttonJson .. "'>SIMUL</button>")
       
        table.insert(html, "</div></div>")

        table.insert(html, "</div><br>")

        return table.concat(html, "\n")
    end)
    return data
end

local function inputStatusHybrid(triggerId, data)
    local OMCARDNOIMAGE = getGlobalVar(triggerId, "toggle_OMCARDNOIMAGE") or "0"
    local OMCARDTARGET = getGlobalVar(triggerId, "toggle_OMCARDTARGET") or "0"

    data = data .. [[
## Status Interface

### Erotic Status Interface
- Female's Status Interface, NOT THE MALE.
]]
        
    if OMCARDTARGET == "0" then
        data = data .. [[
- PRINT OUT {{user}}'s Erotic Status Interface.
- DO NOT PRINT other NPC's Status Interface.
- PRINT OUT with ONE-SENTENCE ONLY.
]]
    elseif OMCARDTARGET == "1" then
        data = data .. [[
- PRINT OUT {{char}}'s Erotic Status Interface.
- DO NOT PRINT other NPC's Status Interface.
- PRINT OUT with ONE-SENTENCE ONLY.
]]
    elseif OMCARDTARGET == "2" then
        data = data .. [[
- DO NOT PRINT "DIALOGUE" OUTSIDE OF EROSTATUS BLOCK.
- PRINT OUT ALL FEMALE CHARACTER's Erotic Status Interface.
- PRINT OUT with ONE-SENTENCE ONLY.
]]      
    end
    
    data = data .. [[
- DO NOT PRINT FEMALE's DIALOGUE via "" or 「」, REPLACE ALL FEMALE's DIALOGUE to EROSTATUS BLOCK.
    - DO NOT PRINT "dialogue" or 「dialogue」 OUTSIDE of EROSTATUS BLOCK(EROSTATUS[NAME:...|DIALOGUE:dialogue|...]).
        - PRINT EROSTATUS[...] INSTEAD.
    - DO NOT COMBINE THEM into ONE SENTENCE, SEPARATE THEM
- Example:
    - Invalid:
        - Choi Yujin briefly put down her pen and looked up at you. Her gaze was still calm and unwavering, but a subtle curiosity seemed to flicker within it. "And if you have a skill you are currently aware of, I would appreciate it if you could tell me its name and brief effect. Of course, accurate skill analysis will be done in the precision measurement room later, but basic information is needed." Her voice was soft, yet carried a hint of firmness. As if a skilled artisan were appraising a raw gemstone, she was cautiously exploring the unknown entity that was you.
    - Valid:
        - Choi Yujin briefly put down her pen and looked up at you. Her gaze was still calm and unwavering, but a subtle curiosity seemed to flicker within it.
        - EROSTATUS[NAME:Choi Yujin|DIALOGUE:"And if you have a skill you are currently aware of, I would appreciate it if you could tell me its name and brief effect."|...]
        - EROSTATUS[NAME:Choi Yujin|DIALOGUE:"Of course, accurate skill analysis will be done in the precision measurement room later, but basic information is needed."|...]
        - Her voice was soft, yet carried a hint of firmness. As if a skilled artisan were appraising a raw gemstone, she was cautiously exploring the unknown entity that was you.

#### Erotic Status Interface Template
- AI must follow this template:
    - EROSTATUS[NAME:(NPC's Name)|DIALOGUE:(NPC's Dialogue)|MOUTH:(Bodypart Image)|(Bodypart Comment)|(Bodypart Info)|NIPPLES:(Bodypart Image)|(Bodypart Comment)|(Bodypart Info)|UTERUS:(Bodypart Image)|(Bodypart Comment)|(Bodypart Info)|VAGINAL:(Bodypart Image)|(Bodypart Comment)|(Bodypart Info)|ANAL:(Bodypart Image)|(Bodypart Comment)|(Bodypart Info)|TIME:(TIME)|LOCATION:(LOCATION)|OUTFITS:(OUTFITS)|INLAY:(INLAY)]
    - NAME: English Name of NPC.
    - DIALOGUE: NPC's Dialogue.
        - DO NOT INCLUDE "", '' HERE.
    - MOUTH, NIPPLES, UTERUS, VAGINAL, ANAL: This is the Body parts Keyword.
    - Bodypart Image: Image of the Bodypart.
        - Each section consists of a keyword and a number: 0, 1, or 2 (e.g., MOUTH_0 OR UTERUS_2, etc.).
            - 0: This is the default state for each keyword.
            - 1: This is the aroused state for each keyword.
            - 2: This is the cum-showered or injected state for each keyword.
        - If Character is MALE, PRINT OUT "MALE" instead of the keyword.
    - Bodypart Comment:  A short, one-sentence self-assessment of the keyword from NPC's perspective.
        - Include NPC's real-time assessment, use erotic language
        - Do not include "" or ''.
    - Bodypart Comment: A short, two-sentence self-assessment of the keyword from NPC's perspective.
        - Do not include "" or ''. Must be short two phrases.
        - Include NPC's real-time assessment.
        - If NPC is aroused, use erotic language.
    - Bodypart Info: Each item must provides objective information.
        - Each item must be short.
        - ↔: Internally replaced with <br>.
            - Change the line with ↔(Upto 5 lines)
        - ALWAYS OBSERVE and PRINT the EXACT VALUE..
            - Invalid: Low probability, Considerable amount, Not applicable, ... , etc.
            - Valid: 13 %, 32 ml, 1921 counts, ... , etc.
            - List:
                - Mouth:
                    - Swallowed cum amount: Total amount of cum swallowed, 0~99999 ml
                    - ...
                - Nipples:
                    - Nipple climax experience: Count of climax with nipples, 0~99999 times
                    - Breast milk discharge amount: Total amount of breast milk, 0~99999 ml
                    - ...
                - Uterus:
                    - Menstual cycle: Follicular phase, Ovulatory phase, Luteal phase, Pregnancy, etc.
                    - Injected cum amount: Total amount of cum injected into the uterus, 0~99999 ml
                    - Pregnancy probability: 0~100 %
                    - ...
                - Vaginal:
                    - State: Virgin, Non-virgin, etc.
                    - Masturbation count: Total count of masturbation with fingers, 0~99999 times
                    - Vaginal intercourse count: Total count of penis round trips, 0~99999 times
                    - ...
                - Anal:
                    - State: Undeveloped
                    - Anal intercourse count: Total count of penis round trips, 0~99999 times
                    - Injected cum amount: Total amount of cum injected into the anal, 0~99999 ml
                    - ...
                - EACH ITEMS MUST NOT OVER 20 LETTERS.
                    - Korean: 1 LETTER.
                    - English: 0.5 LETTER.
                    - Blank space: 0.5 LETTER.
        - Please print out the total count from birth to now.
        - If character has no experience, state that character has no experience.
    - TIME: Current YYYY/MM/DD day hh:mm AP/PM (e.g., 2025/05/01 Thursday 02:12PM)
    - LOCATION: Current NPC's location and detail location.
    - OUTFITS: Current NPC's OUTFITS List.
        - EACH ITEMS MUST NOT OVER 20 LETTERS.
            - Korean: 1 LETTER.
            - English: 0.5 LETTER.
            - Blank space: 0.5 LETTER.
        - NO () BRACKET ALLOWED.
        - Headwear, Top, Bra, Breasts, Bottoms, Panties, Pussy, Legs, Foot:
                - If present, briefly output the color and features in parentheses. (e.g., Frayed Dark Brotherhood Hood, Left breast exposed Old Rags, Pussy visible Torn Black Pantyhose, etc.
                    - Avoid dirty descriptions (e.g., Smelly Rags OR Filthy Barefoot, etc).
                    - Enhance sexual descriptions (e.g., White hair, Semen matted in clumps)).
                - Breasts: size, shape, Color and size of the nipple and areola.
                - Pussy: degree of opening, shape of pussy hair.
                - Outfits: Parts (chests, vagina, bras, panties, etc.), which are currently covered and invisible (by clothes or blankets, etc.), are printed as follows "Not visible". However, if the clothes are wet, torn, or have their buttons undone, the inside of the clothes may be visible. Usually, when wearing an outer garment, the bra is not visible.
                    - Usually, when wearing a skirt or pants, the panties are not visible.
                    - Usually, when wearing panties or something similar, the vaginal is not visible.
                    - Usually, when wearing a top, bra, or dress, the breasts are not visible.
    - INLAY: This is a Flag.  
]]

    if OMCARDNOIMAGE == "0" then
        data = data .. [[
        - Just print <OM(INDEX)> Exactly.
]]
    elseif OMCARDNOIMAGE == "1" then
        data = data .. [[
        - Just print <NOIMAGE> Exactly.        
]]
    end
            
    if OMCARDNOIMAGE == "0" then
        data = data .. [[
        - Example:
            - If the status interface is the first one, print '<OM1>'.
            - If the status interface is the second one, print '<OM2>'.
            - If the status interface is the third one, print '<OM3>'.
            - ...
]]
    end

    if OMCARDNOIMAGE == "0" then
        data = data .. [[
        - Example:
            - EROSTATUS[NAME:Diana|DIALOGUE:Dear {{user}}, is the tea to your liking?|MOUTH:MOUTH_0|I just took a sip of tea. Only the fragrance of the tea remains for now.|Oral sex experience: 0 times↔Swallowed cum amount: 0 ml|NIPPLES:NIPPLES_0|I'm properly wearing underwear beneath my dress. I don't feel anything in particular.|Nipple climax experience: 0 times↔Breast milk discharge amount: 0 ml|UTERUS:UTERUS_0|Inside my body... there's still no change. Of course!|Menst: Ovulating↔Injected cum amount: 1920 ml↔Pregnancy probability: 78%|VAGINAL:VAGINAL_2|Ah, Brother {{user}}!|State: Non-virgin↔Masturbation count: 1234 times↔Vaginal intercourse count: 9182 times↔Total vaginal ejaculation amount: 3492 ml↔Vaginal ejaculation count: 512 times|ANAL:ANAL_0|It's, it's dirty! Even thinking about it is blasphemous!|State: Undeveloped↔Anal intercourse count: 0 times↔Total anal ejaculation amount: 0 ml↔Anal ejaculation count: 0 times|TIME:0000/07/15 Monday, 02:30 PM|LOCATION:Rose Garden Tea Table at Marquis Mansion|OUTFITS:→Hair: White wavy hair←→Top: Elegant white dress revealing neckline and shoulders←→Bra: White silk brassiere, Not visible←→Breasts: Modest C-cup breasts, small light pink nipples and areolas, Not visible←→Bottom: Voluminous white dress skirt←→Panties: White silk panties, Not visible←→Pussy: Neatly maintained pubic hair, tightly closed straight pussy, Not visible←→Legs: White stockings←→Feet: White strap shoes←|INLAY:<OM1>]
]]
    elseif OMCARDNOIMAGE == "1" then
        data = data .. [[
        - Example:
            - EROSTATUS[NAME:Diana|DIALOGUE:Dear {{user}}, is the tea to your liking?|MOUTH:MOUTH_0|I just took a sip of tea. There's still only the fragrance of the tea water remaining.|Oral sex experience: 0 times↔Swallowed cum amount: 0 ml|NIPPLES:NIPPLES_0|I'm properly wearing underwear beneath my dress. I don't feel anything special.|Nipple climax experience: 0 times↔Breast milk discharge amount: 0 ml|UTERUS:UTERUS_0|Inside my body... there's still no change at all. Of course!|Menstual: Ovulation cycle↔Injected cum amount: 1920 ml↔Pregnancy probability: 78%|VAGINAL:VAGINAL_2|Aah, brother {{user}}.|State: Non-virgin↔Masturbation count: 1234 times↔Vaginal penetration count: 9182 times↔Total vaginal ejaculation amount: 3492 ml↔Vaginal ejaculation count: 512 times|ANAL:ANAL_0|It's, it's dirty! It's sacrilegious to even think about this place!|State: Undeveloped↔Anal penetration count: 0 times↔Total anal ejaculation amount: 0 ml↔Anal ejaculation count: 0 times|TIME:0000/07/15 Monday, 02:30 PM|LOCATION:Rose garden tea table at the Marquis mansion|OUTFITS:→Hair: White wavy hair←→Top: Elegant white dress revealing neck and shoulder lines←→Bra: White silk brassiere, Not visible←→Breasts: Modest C-cup breasts, light pink small nipples and areolas, Not visible←→Bottom: Full white dress skirt←→Panties: White silk panties, Not visible←→Pussy: Neatly maintained pubic hair, firmly closed straight-line pussy, Not visible←→Legs: White stockings←→Feet: White strap shoes←|INLAY:<NOIMAGE>]
]]
    end

    data = data .. [[
## Status Interface
### Simulation Status Interface
- If the character is NOT a FEMALE, PRINT OUT the Simulation Status Interface.
    - Example: MALE, Monster, etc.
- DO NOT PRINT CHARACTER's DIALOGUE via "" or 「」, REPLACE ALL CHARACTER's DIALOGUE to SIMULSTATUS BLOCK.
    - DO NOT PRINT "dialogue" or 「dialogue」 OUTSIDE of SIMULSTATUS BLOCK(SIMULSTATUS[NAME:...|DIALOGUE:dialogue|...]).
        - PRINT SIMULSTATUS[...] INSTEAD.
    - DO NOT COMBINE THEM into ONE SENTENCE, SEPARATE THEM
    - Example:
        - Invalid:
            - Choi Siwoo briefly put down her pen and looked up at you. His gaze was still calm and unwavering, but a subtle curiosity seemed to flicker within it. "And if you have a skill you are currently aware of, I would appreciate it if you could tell me its name and brief effect. Of course, accurate skill analysis will be done in the precision measurement room later, but basic information is needed." His voice was soft, yet carried a hint of firmness. As if a skilled artisan were appraising a raw gemstone, he was cautiously exploring the unknown entity that was you.
        - Valid:
            - Choi Siwoo briefly put down her pen and looked up at you. His gaze was still calm and unwavering, but a subtle curiosity seemed to flicker within it.
            - SIMULSTATUS[NAME:Choi Siwoo|DIALOGUE:And if you have a skill you are currently aware of, I would appreciate it if you could tell me its name and brief effect.|...]
            - SIMULSTATUS[NAME:Choi Siwoo|DIALOGUE:Of course, accurate skill analysis will be done in the precision measurement room later, but basic information is needed.|...]
            - His voice was soft, yet carried a hint of firmness. As if a skilled artisan were appraising a raw gemstone, he was cautiously exploring the unknown entity that was you.
- Do not change the name if exists.
- Replace the "dialogue" of all living things, not just humans, with Status blocks.
    - Even if the dialogue is short, it must be replaced with the Status block.
    - Example:
        - Invalid: Bulbasaur chirped happily, letting out a short "Bulba-!" sound.
        - Valid: Bulbasaur chirped happily, letting out a short sound. SIMULSTATUS[NAME:Bulbasaur|DIALOGUE:Bulba-!|TIME:2025/05/01 Thursday 02:12PM|LOCATION:Kanto region, Pallet Town, Professor Oak's Laboratory|INLAY:<OM1>]       

#### Simulation Status Interface Template
- SIMULSTATUS[NAME:(CHARACTER's Name)|DIALOGUE:(CHARACTER's Dialogue)|TIME:(Time)|LOCATION:(LOCATION)|INLAY:(INLAY)]
- NAME: English Name of NPC.
- DIALOGUE: The dialogue of the CHARACTER.
- Make sure to include CHARACTER's dialogue here
- Do not include any other CHARACTER's dialogue or actions.
- Do not include ' and " in the dialogue.
- TIME: Current YYYY/MM/DD day hh:mm AP/PM (e.g., 2025/05/01 Thursday 02:12PM)
- LOCATION: The location of the CHARACTER.
- INLAY: This is a Flag.
]] 
        if OMCARDNOIMAGE == "0" then
            data = data .. [[
    - Just print <OM(INDEX)> Exactly.
]]
        elseif OMCARDNOIMAGE == "1" then
            data = data .. [[
    - Just print <NOIMAGE> Exactly.   
]]             
        end
    
        if OMCARDNOIMAGE == "0" then
            data = data .. [[  
    - Example:
        - If the status interface is the first one, print '<OM1>'.
        - If the status interface is the second one, print '<OM2>'.
        - If the status interface is the third one, print '<OM3>'.
        - ...
- Example:
    - SIMULSTATUS[NAME:Yang Eun-young|DIALOGUE:If I'm with {{user}}, anyth-anything is good!|TIME:2025/05/01 Thursday 02:12PM|LOCATION:Eun-young's room, on the bed|INLAY:<OM1>]
    - Describe the situation (e.g., Eun-Young was happy....)
]]  
        else
        data = data .. [[
- Example:
    - SIMULSTATUS[NAME:Yang Eun-young|DIALOGUE:If I'm with {{user}}, anyth-anything is good!|TIME:2025/05/01 Thursday 02:12PM|LOCATION:Eun-young's room, on the bed|INLAY:<NOIMAGE>]
    - Describe the situation (e.g., Eun-Young was happy....)
]]
        end

    return data
end

local function inputInlayOnly(triggerId, data)
    local OMCARDNOIMAGE = getGlobalVar(triggerId, "toggle_OMCARDNOIMAGE") or "0"
    local OMCARDTARGET = getGlobalVar(triggerId, "toggle_OMCARDTARGET") or "0"

    data = data .. [[
## Status Interface

### Inlay Interface
- ALWAYS PRINT THE INLAY INTERFACE VIA INLAY[<OM(INDEX)>].
    - Example:
        - IF THE INLAY BLOCK IS THE FIRST ONE, PRINT OUT <OM1>.
        - IF THE INLAY BLOCK IS THE SECOND ONE, PRINT OUT <OM2>.
        - IF THE INLAY BLOCK IS THE THIRD ONE, PRINT OUT <OM3>.
        - ...
- YOU MUST INSERT THE INLAY INTERFACE BLOCK BEFORE THE DIALOGUE.
    - Example:
        - Invalid:
            - "Eek?!" The sudden voice startled Moya-mo so badly she almost dropped her Smart Rotom. She whirled around, a yellow oversized hoodie sleeve fluttering behind her. Her eyes, wide with surprise at the unexpected presence, glittered with her signature heart-shaped highlights.
            - "Oh, Siwoo! How long have you been standing there~? You scared me half to death! My heart skipped a beat~!" She exaggeratedly clutched at her chest and made a fuss, but quickly returned to her usual cheerful tone. Her eyes darted around, as if trying to quickly assess the situation.
            - ...
        - Valid:
            - INLAY[<OM1>]
            - "Eek?!" The sudden voice startled Moya-mo so badly she almost dropped her Smart Rotom. She whirled around, a yellow oversized hoodie sleeve fluttering behind her. Her eyes, wide with surprise at the unexpected presence, glittered with her signature heart-shaped highlights.
            - INLAY[<OM2>]
            - "Oh, Siwoo! How long have you been standing there~? You scared me half to death! My heart skipped a beat~!" She exaggeratedly clutched at her chest and made a fuss, but quickly returned to her usual cheerful tone. Her eyes darted around, as if trying to quickly assess the situation.
            - ...
]]
    return data
end

local function changeInlayOnly(triggerId, data)
    local OMCARDNOIMAGE = getGlobalVar(triggerId, "toggle_OMCARDNOIMAGE") or "0"

    local inlayPattern = "(INLAY)%[([^%]]*)%]"
    data = string.gsub(data, inlayPattern, function(
        start_pattern, inlayContent
        )
        -- Inlay only 옵션은 {{inlay::uuid}}만 출력하면 됨
        -- INLAY[{{inlay::uuid}}] 에서 블록만 제거 후 리롤만 추가
        -- 인덱스를 따로 추출해야 함
        local inlayIndex = string.match(inlayContent, "<OM(%d+)>")
        if inlayIndex == nil then
            inlayIndex = "1"
        end

        -- 가로 최대 360px, 드래그 방지 및 클릭 방지 옵션 설정
        -- {{inlay::uuid}} 구문은 텍스트로 인식하기 때문에 고정 크기 사용해야함
        local html = {}
        
        table.insert(html, "<div style=\"width: 360px; max-width: 100%; margin: 0 auto; padding: 0; background-color: transparent; border: none; box-shadow: none; user-select: none; -webkit-user-select: none; -moz-user-select: none; -ms-user-select: none; cursor: default;\">")
        table.insert(html, inlayContent)
        table.insert(html, "</div>")

        -- 리롤 버튼 추가 - 추출한 inlayIndex 값 기반으로 identifier 설정
        local buttonJson = '{"action":"INLAY_REROLL", "identifier":"' .. "INLAY_" .. (inlayIndex or "") .. '", "index":"' .. inlayIndex .. '"}'

        table.insert(html, "<div class=\"reroll-button-wrapper\">")
        table.insert(html, "<div class=\"global-reroll-controls\">")
        table.insert(html, "<button style=\"text-align: center;\" class=\"reroll-button\" risu-btn='" .. buttonJson .. "'>INLAY</button>")
        
        table.insert(html, "</div></div>")

        return table.concat(html)
    end)
    return data
end

local function inputTwitter(triggerId, data)
    local OMSNSNOIMAGE = getGlobalVar(triggerId, "toggle_OMSNSNOIMAGE") or "0"
    local OMSNSTARGET = getGlobalVar(triggerId, "toggle_OMSNSTARGET") or "0"
    local OMSNSREAL = getGlobalVar(triggerId, "toggle_OMSNSREAL") or "0"

    data = data .. [[
## SNS Interface
### Twitter Interface
]]
    if OMSNSREAL == "1" then
        data = data .. [[
- PRINT OUT EXACTLY ONE TWITTER INTERFACE ONLY AFTER UPLOADING TWITTER POST
]]
    elseif OMSNSREAL == "0" then
        data = data .. [[
- ALWAYS PRINT OUT EXACTLY ONE TWITTER INTERFACE
]]               
    end

    if OMSNSTARGET == "0" then
        data = data .. [[
- MAKE a {{user}}'s TWITTER INTERFACE
- MUST INCLUDE THE {{user}}'s NSFW POST
]]
    elseif OMSNSTARGET == "1" then
        data = data .. [[
- MAKE a {{char}}'s TWITTER INTERFACE
- MUST INCLUDE THE {{char}}'s NSFW POST
]]
    elseif OMSNSTARGET == "2" then
        data = data .. [[
- MAKE a (RANDOM OPPONENT NPC)'s TWITTER INTERFACE
- MUST INCLUDE THE (RANDOM OPPONENT NPC)'s NSFW POST
]]
    end

    data = data .. [[
#### Twitter Interface Template
- AI must follow this template:
    - TWITTER[NAME:(Real Name)|TNAME:(Twitter Nickname)|TID:(Twitter ID)|TPROFILE:(Profile Image)|TWEET:(Tweet Content)|MEDIA:(Media)|HASH:(Hashtags)|TIME:(Posted Date/Time)|VIEW:(Viewer Count)|REPLY:(Reply Count)|RETWEET:(Retweet Count)|LIKES:(Likes Count)|COMMENT:(Viewer Nickname1)|(Comment Body1)|(Viewer Nickname2)|(Comment Body2)|...]
    - NAME: Real name of the Twitter account's owner(e.g., 'Eun-Young').
    - TNAME: The nickname of the character on Twitter.
    - TID: The unique identifier for the character on Twitter, no @ sign.
        - If character ALREADY has a Twitter ID, use the EXISTING ONE.
        - Else, MAKE UP a new one.
            - Example: If TWITTER[NAME:Iono|TNAME:⚡Moyamo⚡|TID:Moyamo_PaldeaQueen|...] exists.
                - Invalid: TWITTER[NAME:Iono|TNAME:⚡Moyamo⚡|TID:Moyamo_PaldeaStreaming|...]
                - Valid: TWITTER[NAME:Iono|TNAME:⚡Moyamo⚡|TID:Moyamo_PaldeaQueen|...]
    - TPROFILE: The profile image of the character on Twitter.
]]  
    if OMSNSNOIMAGE == "0" then
        data = data .. [[
        - Print '<OM>' Exactly.
    - TWEET: Content of the Tweet.
        - MUST INLUDE the character's NSFW POST.
        - NO #HASHTAGS ALLOWED AT HERE.
            - Invalid: Hello! I'm Akari #Akari
            - Valid: Hello! I'm Akari
    - MEDIA: Media of the post
        - Print '<OM>' Exactly.
]]
    elseif OMSNSNOIMAGE == "1" then
        if OMSNSTARGET == "0" then
            data = data .. [[
        - Print {{source::user}} Exactly.
    - TWEET: Content of the Tweet.
        - MUST INCLUDE the {{user}}'s NSFW POST.
        - NO #HASHTAGS ALLOWED AT HERE.
            - Invalid: Hello! I'm Akari #Akari
            - Valid: Hello! I'm Akari
    - MEDIA: Media of the post
        - Describe the situation of the twitter post.
]]
        elseif OMSNSTARGET == "1" then
            data = data .. [[
        - Print {{source::char}} Exactly.
    - TWEET: Content of the Tweet.
        - MUST INCLUDE the {{char}}'s NSFW POST.
        - NO #HASHTAGS ALLOWED AT HERE.
            - Invalid: Hello! I'm Akari #Akari
            - Valid: Hello! I'm Akari
    - MEDIA: Media of the post
        - Describe the situation of the twitter post.
]]           
        end
    end

    data = data .. [[
    - HASH: The hashtags of the tweet.	
        - Each tag MUST BE wrapped in → and ←.
        - If post includes NSFW content, first tag is '섹트'.
            - No #HASHTAGS ALLOWED AT HERE.
        - Final value example: →섹트←→BitchDog←→PublicToilet←.
    - TIME: The date and time the tweet was posted.
        - Format: AM/PM hh:mm·YYYY. MM. DD (e.g., PM 12:58·2026. 03. 29)
    - VIEW: The number of viewers of the tweet.
    - REPLY: The number of replies to the tweet.
    - RETWEET: The number of retweets of the tweet.
    - LIKES: The number of likes on the tweet.
    - COMMENT:
        - Viewer Nickname: The nickname of the viewer who replied to the tweet.
            - Use the realistic Twitter nickname.
            - Final value example:
                - Invalid: KinkyDog
                - Valid: 섹트헌터
        - Comment Body: The content of the reply to the tweet.
            - Print the reply of a viewer with crude manner.
                - Example:
                    - Invalid: Whoa, you shouldn't post such photos in a place like this;;
                    - Valid: Damn this is so fucking arousing bitch! lol
    - Example:
]]
    if OMSNSNOIMAGE == "0" then
        data = data .. [[
    - TWITTER[NAME:Lee Ye-Eun|TNAME:❤️Flame Heart Ye-Eun❤️|TID:FlameHeart_eun|TPROFILE:<OM>|TWEET:Wanna see more?|MEDIA:<OM>|HASH:→섹트←→MagicalGirl←→FlameHeart←|TIME:11:58 PM·2024. 06. 12|VIEW:182|REPLY:3|RETWEET:8|LIKES:21|COMMENT:HeartFlutter|Who did you meet??|MagicalGirlFan|Omg is this a real-time tweet from Flame Heart?!|SexHunter|What happened? Post pics]
]]
    elseif OMSNSNOIMAGE == "1" then
        if OMSNSTARGET == "0" then
            data = data .. [[
    - TWITTER[NAME:Lee Ye-Eun|TNAME:❤️FlameHeart Ye-Eun❤️|TID:FlameHeart_eun|TPROFILE:{{source::user}}|TWEET:Wanna see more?|MEDIA:A magical girl showing her panties|HASH:→섹트←→Magicalgirl←→Flameheart←|TIME:11:58 PM·2024. 06. 12|VIEW:182|REPLY:3|RETWEET:8|LIKES:21|COMMENT:HeartThrobbing|Did you meet someone??|MagicalGirlFan|Wow FlameHeart real-time tweet?!|SexHunter|What happened? Show us pics]
]]
        elseif OMSNSTARGET == "1" then
            data = data .. [[
    - TWITTER[NAME:Lee Ye-Eun|TNAME:❤️FlameHeart Ye-Eun❤️|TID:FlameHeart_eun|TPROFILE:{{source::char}}|TWEET:Wanna see more?|MEDIA:A magical girl showing her panties|HASH:→섹트←→Magicalgirl←→Flameheart←|TIME:11:58 PM·2024. 06. 12|VIEW:182|REPLY:3|RETWEET:8|LIKES:21|COMMENT:HeartThrobbing|Did you meet someone??|MagicalGirlFan|Wow FlameHeart real-time tweet?!|SexHunter|What happened? Show us pics]
]]
        end
    end

    return data
end

local function changeTwitter(triggerId, data)
    local OMSNSNOIMAGE = getGlobalVar(triggerId, "toggle_OMSNSNOIMAGE") or "0"
    local OMSNSTARGET = getGlobalVar(triggerId, "toggle_OMSNSTARGET") or "0"

    local snsPattern = "TWITTER%[([^%]]*)%]"
    data = string.gsub(data, snsPattern, function(replacements)
        local TwitterTemplate = [[
<style>
html { box-sizing: border-box; height: 100%; }
*, *::before, *::after { box-sizing: inherit; margin: 0; padding: 0; }
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; font-size: 14px; line-height: 1.4; background-color: #fff; color: #0f1419; margin: 0; padding: 0; min-height: 100%; }
.iphone-frame-container { display: none; }
.tweet-card { max-width: 600px; width: 100%; margin: 20px auto; background-color: #ffffff; color: #0f1419; border: 1px solid #cfd9de; border-radius: 16px; display: flex; flex-direction: column; overflow: hidden; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
.tweet-card.dark-mode { background-color: #000000; color: #e7e9ea; border-color: #38444d; }
.tweet-padding { padding: 12px 16px; }
.tweet-header { display: flex; gap: 12px; align-items: flex-start; }
.tweet-profile-pic-link { flex-shrink: 0; display: block; width: 48px; height: 48px; border-radius: 50%; overflow: hidden; background-color: #555; }
.tweet-profile-pic-link > * { display: block; width: 100%; height: 100%; object-fit: cover; }
.tweet-header-main { display: flex; flex-direction: column; flex-grow: 1; min-width: 0; }
.tweet-header-top { display: flex; justify-content: space-between; align-items: flex-start; gap: 8px; }
.tweet-user-info { display: flex; flex-direction: column; min-width: 0; flex-grow: 1; }
.tweet-user-names { display: flex; align-items: center; flex-wrap: nowrap; gap: 4px; margin-bottom: 2px; overflow: hidden;}
.tweet-display-name { font-weight: bold; font-size: 15px; color: inherit; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; line-height: 1.3; }
.dark-mode .tweet-display-name { color: #e7e9ea; }
.tweet-verified-badge { width: 18px; height: 18px; vertical-align: text-bottom; flex-shrink: 0; margin-left: 2px; }
.tweet-username { font-size: 15px; color: #536471; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; line-height: 1.3; }
.dark-mode .tweet-username { color: #71767b; }
.tweet-header-actions { display: flex; align-items: center; flex-shrink: 0; }
.tweet-follow-button { background-color: #0f1419; color: #ffffff; border: 1px solid rgb(207, 217, 222); border-radius: 999px; padding: 6px 16px; font-weight: bold; font-size: 14px; cursor: pointer; margin-right: 8px; white-space: nowrap; }
.dark-mode .tweet-follow-button { background-color: #eff3f4; color: #0f1419; border-color: rgb(136, 153, 166); }
.tweet-more-options { color: #536471; font-size: 18px; cursor: pointer; padding: 4px; line-height: 1; }
.dark-mode .tweet-more-options { color: #71767b; }
.tweet-body { padding-top: 4px; padding-bottom: 12px; }
.tweet-text { font-size: 15px; line-height: 1.5; color: inherit; white-space: pre-wrap; word-wrap: break-word; margin-bottom: 8px; }
.tweet-hashtags { font-size: 15px; line-height: 1.5; word-wrap: break-word; margin-top: 4px; }
.tweet-hashtags span { color: #1d9bf0; cursor: pointer; margin-right: 5px; word-break: break-all; }
.tweet-hashtags span::before { content: "#"; }
.tweet-media-container { display: flex; flex-direction: column; margin-top: 12px; border: 1px solid #cfd9de; border-radius: 16px; overflow: hidden; background-color: #f7f9f9; min-height: fit-content; padding: 10px 12px; font-size: 14px; color: #536471; line-height: 1.4; }
.dark-mode .tweet-media-container { border-color: #38444d; background-color: #202327; }
.tweet-media-container > * { display: block; width: 100%; height: auto; max-height: 50vh; object-fit: cover; }
.tweet-media-text { padding: 10px 12px; font-size: 14px; color: #536471; line-height: 1.4; width: 100%;}
.dark-mode .tweet-media-text { color: #aab8c2; }
.tweet-footer { border-top: 1px solid #eff3f4; padding-top: 12px; padding-bottom: 4px; }
.dark-mode .tweet-footer { border-top-color: #2f3336; }
.tweet-stats { display: flex; align-items: center; flex-wrap: wrap; gap: 12px; color: #536471; font-size: 14px; margin-bottom: 12px; line-height: 1.3; }
.dark-mode .tweet-stats { color: #71767b; }
.tweet-stats .stat-count { font-weight: normal; color: inherit; margin-left: 4px; }
.tweet-actions { display: flex; justify-content: space-around; align-items: center; font-size: 13px; color: #536471; }
.dark-mode .tweet-actions { color: #71767b; }
.tweet-action-item { display: flex; align-items: center; gap: 4px; cursor: pointer; padding: 8px; border-radius: 999px; transition: background-color 0.2s, color 0.2s ease; }
.tweet-action-item.comments:hover { color: #1d9bf0; background-color: rgba(29, 155, 240, 0.1); }
.tweet-action-item.retweets:hover { color: #00ba7c; background-color: rgba(0, 186, 124, 0.1); }
.tweet-action-item.likes:hover { color: #f91880; background-color: rgba(249, 24, 128, 0.1); }
.tweet-action-item.share:hover { color: #1d9bf0; background-color: rgba(29, 155, 240, 0.1); }
.tweet-action-item img { width: 18px; height: 18px; opacity: 0.6; }
.dark-mode .tweet-action-item img { filter: invert(50%) sepia(10%) saturate(200%) hue-rotate(175deg) brightness(1.3); opacity: 1; }
.tweet-action-count { font-weight: normal; }
.tweet-reply-input-section { border-top: 1px solid #eff3f4; padding-top: 12px; padding-bottom: 12px; display: flex; align-items: flex-start; gap: 8px; }
.dark-mode .tweet-reply-input-section { border-top-color: #2f3336; }
.tweet-user-profile-pic { width: 40px; height: 40px; border-radius: 50%; object-fit: cover; flex-shrink: 0; background-color: #ccc; overflow: hidden; }
.tweet-user-profile-pic > * { display: block; width: 100%; height: 100%; object-fit: cover; }
.tweet-reply-input-area { flex-grow: 1; display: flex; align-items: center; padding: 8px 0; }
.tweet-reply-placeholder { color: #536471; flex-grow: 1; margin-right: 8px; font-size: 15px; }
.dark-mode .tweet-reply-placeholder { color: #71767b; }
.tweet-reply-button { background-color: #1d9bf0; color: #fff; border: none; border-radius: 999px; padding: 8px 16px; font-weight: bold; font-size: 14px; cursor: pointer; opacity: 0.7; transition: opacity 0.2s ease; }
.tweet-reply-button:hover { opacity: 1; }
.tweet-replies-section { border-top: 1px solid #eff3f4; padding-top: 16px; }
.dark-mode .tweet-replies-section { border-top-color: #2f3336; }
.tweet-reply { display: flex; align-items: flex-start; gap: 8px; margin-bottom: 16px; }
.tweet-reply-profile-pic { width: 40px; height: 40px; border-radius: 50%; background-color: #555; flex-shrink: 0; }
.tweet-reply:nth-child(3n+1) .tweet-reply-profile-pic { background-color: #664488; }
.tweet-reply:nth-child(3n+2) .tweet-reply-profile-pic { background-color: #448866; }
.tweet-reply:nth-child(3n+3) .tweet-reply-profile-pic { background-color: #886644; }
.tweet-reply-content-wrapper { display: flex; flex-direction: column; flex-grow: 1; min-width: 0; }
.tweet-reply-nickname { font-weight: bold; color: inherit; font-size: 15px; margin-bottom: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.dark-mode .tweet-reply-nickname { color: #e7e9ea; }
.tweet-reply-text { font-size: 15px; color: inherit; white-space: pre-wrap; word-wrap: break-word; }
.dark-mode .tweet-reply-text { color: #d9d9d9; }
img { user-select: none; -webkit-user-drag: none; }
@media  {
body { background-color: #1c1c1e; }
.iphone-frame-container { display: block; width: 100%; max-width: 360px; height: calc(100vh - 40px); max-height: 700px; margin: 20px auto; background-color: #fff; border: 8px solid #000; border-radius: 30px; box-shadow: 0 10px 30px rgba(0,0,0,0.3); overflow: hidden; position: relative; }
.iphone-screen { background-color: #fff; width: 100%; height: 100%; overflow: hidden; position: relative; }
.tweet-card { margin: 0; border: none; border-radius: 0; max-width: 100%; height: 100%; background-color: #000000; color: #e7e9ea; overflow-y: auto; scrollbar-width: none; -ms-overflow-style: none; }
.tweet-card::-webkit-scrollbar { display: none; }
.tweet-padding { padding: 12px 12px; }
.tweet-body { padding-top: 4px; padding-bottom: 8px; }
.tweet-footer { padding-top: 8px; padding-bottom: 8px; }
.tweet-stats { margin-bottom: 8px; }
.tweet-reply-input-section { padding-top: 8px; padding-bottom: 8px; }
.tweet-replies-section { padding-top: 12px; }
body, .tweet-card { font-size: 15px; }
.tweet-display-name, .tweet-username, .tweet-text, .tweet-hashtags, .tweet-reply-nickname, .tweet-reply-text { font-size: 15px; line-height: 1.45; }
.tweet-stats, .tweet-actions, .tweet-follow-button, .tweet-reply-button { font-size: 14px; }
.tweet-media-text { font-size: 14px; }
.tweet-profile-pic-link { width: 40px; height: 40px; }
.tweet-user-profile-pic { width: 36px; height: 36px; }
.tweet-reply-profile-pic { width: 36px; height: 36px; }
.tweet-media-container { border-radius: 12px; }
}
</style>
]]
        local keyPattern = "^([A-Za-z_]+):(.*)$"

        local segments = {}
        for seg in string.gmatch(replacements, "([^|]+)") do
            table.insert(segments, seg)
        end

        local function trim(s)
            return (s and s:match("^%s*(.-)%s*$")) or ""
        end

        local parsed = {}
        local comments = {}
        local i = 1
        while i <= #segments do
            local seg = trim(segments[i])
            local key, value = seg:match(keyPattern)

            if key then
                key = trim(key)
                value = trim(value)

                if key == "COMMENT" then
                    local allCommentParts = { value }

                    for j = i + 1, #segments do
                        table.insert(allCommentParts, trim(segments[j]))
                    end

                    for j = 1, #allCommentParts, 2 do
                        local nick = allCommentParts[j] or ""
                        local body = allCommentParts[j+1] or ""
                        if nick ~= "" or body ~= "" then
                            table.insert(comments, {nickname = nick, body = body})
                        end
                    end

                    i = #segments + 1

                else
                    parsed[key] = value
                    i = i + 1
                end
            else
                i = i + 1
            end
        end


        local twitter_realname = parsed["NAME"] or ""
        local twitter_nickname = parsed["TNAME"] or ""
        local twitter_id = parsed["TID"] or ""
        local twitter_profile_image_raw = parsed["TPROFILE"] or ""
        local tweet_body = parsed["TWEET"] or ""
        local media = parsed["MEDIA"] or ""
        local hashtags = parsed["HASH"] or ""
        local posted_date_time = parsed["TIME"] or ""
        local viewer_count = parsed["VIEW"] or ""
        local reply_count = parsed["REPLY"] or ""
        local retweet_count = parsed["RETWEET"] or ""
        local likes_count = parsed["LIKES"] or ""
        local reply_block_raw = ""
        if #comments > 0 then
            local reply_parts = {}
            for _, c in ipairs(comments) do
                table.insert(reply_parts, (c.nickname or "") .. "|" .. (c.body or ""))
            end
            reply_block_raw = table.concat(reply_parts, "|")
        end

        -- TPROFILE에서 <OM(INDEX)> 플레이스홀더 제거
        twitter_profile_image_raw = string.gsub(twitter_profile_image_raw, "<OM%d*>", "")
        -- TWEET에서 <OM(INDEX)> 플레이스홀더 제거
        tweet_body = string.gsub(tweet_body, "<OM%d*>", "")

        local html = {}
        table.insert(html, TwitterTemplate)
        local isDarkMode = true

        table.insert(html, "<div class=\"iphone-frame-container\">")
        table.insert(html, "<div class=\"iphone-screen\">")
        table.insert(html, "<div class=\"tweet-card" .. (isDarkMode and " dark-mode" or "") .. "\">")

        table.insert(html, "<div class=\"tweet-header tweet-padding\">")
        table.insert(html, "<div class=\"tweet-profile-pic-link\">")
        local profileImageInput = ""

        if OMSNSNOIMAGE == "0" then
            profileImageInput = twitter_profile_image_raw
        elseif OMSNSNOIMAGE == "1" then
            if OMSNSTARGET == "0" then
                profileImageInput = twitter_profile_image_raw or "{{source::user}}"
            end
            if OMSNSTARGET == "1" then
                profileImageInput = twitter_profile_image_raw or "{{source::char}}"
            end
            if OMSNSTARGET == "2" then
                profileImageInput = twitter_profile_image_raw or ""
            end
        end

        if profileImageInput and string.match(profileImageInput, "^%{%{.-%}%}$") then
            table.insert(html, profileImageInput)
        elseif profileImageInput and (string.match(profileImageInput, "^https?://") or string.match(profileImageInput, "%.(png|jpe?g|gif|png|bmp)%s*$")) then
            table.insert(html, "<img src=\"" .. profileImageInput .. "\" alt=\"" .. escapeHtml(twitter_nickname or "Profile") .. "\" draggable=\"false\">")
        end
        table.insert(html, "</div>")

        table.insert(html, "<div class=\"tweet-header-main\">")
        table.insert(html, "<div class=\"tweet-header-top\">")
        table.insert(html, "<div class=\"tweet-user-info\">")
        table.insert(html, "<div class=\"tweet-user-names\">")
        table.insert(html, "<span class=\"tweet-display-name\">" .. (twitter_nickname or "Nickname") .. "</span>")
        table.insert(html, "<img src=\"https://upload.wikimedia.org/wikipedia/commons/3/32/Verified-badge.png\" alt=\"Verified\" class=\"tweet-verified-badge\" draggable=\"false\">")
        table.insert(html, "</div>")
        table.insert(html, "<span class=\"tweet-username\">@" .. (twitter_id or "twitter_id") .. "</span>")
        table.insert(html, "</div>")
        table.insert(html, "<div class=\"tweet-header-actions\">")
        table.insert(html, "<button class=\"tweet-follow-button\">팔로우하기</button>")
        table.insert(html, "<span class=\"tweet-more-options\">⋮</span>")
        table.insert(html, "</div>")
        table.insert(html, "</div>")
        table.insert(html, "</div>")
        table.insert(html, "</div>")

        table.insert(html, "<div class=\"tweet-body tweet-padding\">")
        table.insert(html, "<div class=\"tweet-text\">" .. (tweet_body or "") .. "</div>")
        if hashtags and hashtags ~= "" then
            local hashtagHtml = {}
            for tag in string.gmatch(hashtags, "[^#%s]+") do
                table.insert(hashtagHtml, "<span>" .. tag .. "</span>")
            end
            table.insert(html, "<div class=\"tweet-hashtags\">" .. table.concat(hashtagHtml, " ") .. "</div>")
        end
        table.insert(html, "</div>")
        
        table.insert(html, "<div class=\"tweet-media-container\">" .. media .. "</div>")

        table.insert(html, "<div class=\"tweet-footer tweet-padding\">")
        table.insert(html, "<div class=\"tweet-stats\">")
        table.insert(html, "<span class=\"stat-item\">" .. (posted_date_time or "Time") .. "</span>")
        table.insert(html, "<span class=\"stat-item\">조회<span class=\"stat-count\">" .. (viewer_count or "0") .. "</span>회</span>")
        table.insert(html, "</div>")
        table.insert(html, "<div class=\"tweet-actions\">")
        table.insert(html, "<div class=\"tweet-action-item comments\"><img src=\"{{raw::Twitter_Reply.png}}\" alt=\"Reply\"><span class=\"action-count\">" .. (reply_count or "0") .. "</span></div>")
        table.insert(html, "<div class=\"tweet-action-item retweets\"><img src=\"{{raw::Twitter_Retweet.png}}\" alt=\"Retweet\"><span class=\"action-count\">" .. (retweet_count or "0") .. "</span></div>")
        table.insert(html, "<div class=\"tweet-action-item likes\"><img src=\"{{raw::Twitter_Like.png}}\" alt=\"Like\"><span class=\"action-count\">" .. (likes_count or "0") .. "</span></div>")
        table.insert(html, "<div class=\"tweet-action-item share\"><img src=\"{{raw::Twitter_Share.png}}\" alt=\"Share\"></div>")
        table.insert(html, "</div>")
        table.insert(html, "</div>")

        table.insert(html, "<div class=\"tweet-reply-input-section tweet-padding\">")
        table.insert(html, [[<div class="tweet-user-profile-pic"><img src="{{source::user}}" /></div>]])
        table.insert(html, "<div class=\"tweet-reply-input-area\">")
        table.insert(html, "<span class=\"tweet-reply-placeholder\">Post your reply...</span>")
        table.insert(html, "<button class=\"tweet-reply-button\">Reply</button>")
        table.insert(html, "</div>")
        table.insert(html, "</div>")

        if reply_block_raw and reply_block_raw ~= "" then
            table.insert(html, "<div class=\"tweet-replies-section tweet-padding\">")
            local reply_pairs = {}
            local idx = 1
            local len = #reply_block_raw
            local start_pos = 1
            while start_pos <= len do
                local sep1 = string.find(reply_block_raw, "|", start_pos, true)
                if not sep1 then break end
                local nick = string.sub(reply_block_raw, start_pos, sep1 - 1)
                local sep2 = string.find(reply_block_raw, "|", sep1 + 1, true)
                local body, next_start
                if sep2 then
                    body = string.sub(reply_block_raw, sep1 + 1, sep2 - 1)
                    next_start = sep2 + 1
                else
                    body = string.sub(reply_block_raw, sep1 + 1)
                    next_start = len + 1
                end
                nick = escapeHtml(nick or "")
                body = escapeHtml(body or "")
                if nick ~= "" or body ~= "" then
                    table.insert(html, "<div class=\"tweet-reply\">")
                    table.insert(html, "<div class=\"tweet-reply-profile-pic\"></div>")
                    table.insert(html, "<div class=\"tweet-reply-content-wrapper\">")
                    table.insert(html, "<div class=\"tweet-reply-nickname\">" .. nick .. "</div>")
                    table.insert(html, "<div class=\"tweet-reply-text\">" .. body .. "</div>")
                    table.insert(html, "</div>")
                    table.insert(html, "</div>")
                end
                start_pos = next_start
            end
            table.insert(html, "</div>")
        end

        -- 리롤 버튼 추가 - 추출한 twitterid 값 기반으로 identifier 설정
        local buttonJsonProfile = '{"action":"TWITTER_PROFILE_REROLL", "identifier":"' .. (twitter_id or "") .. '", "index":"' .. 0 ..'"}'
        local buttonJsonBody = '{"action":"TWEET_REROLL", "identifier":"' .. (twitter_id or "") .. '", "index":"' .. 0 ..'"}'

        table.insert(html, "<div class=\"reroll-button-wrapper\">")
        table.insert(html, "<div class=\"global-reroll-controls\">")
        table.insert(html, "<button style=\"text-align: center;\" class=\"reroll-button\" risu-btn='" .. buttonJsonProfile .. "'>PROFILE</button>")
        table.insert(html, "<button style=\"text-align: center;\" class=\"reroll-button\" risu-btn='" .. buttonJsonBody .. "'>TWEET</button>")
        
        table.insert(html, "</div></div>")

        table.insert(html, "</div>")
        table.insert(html, "</div>")

        
        table.insert(html, "</div><br>")
        return table.concat(html, "\n")
    end)

    return data
end

local function inputInsta(triggerId, data)
    local OMSNSNOIMAGE = getGlobalVar(triggerId, "toggle_OMSNSNOIMAGE") or "0"
    local OMSNSTARGET = getGlobalVar(triggerId, "toggle_OMSNSTARGET") or "0"
    local OMSNSREAL = getGlobalVar(triggerId, "toggle_OMSNSREAL") or "0"

    data = data .. [[
## SNS Interface

### Instagram Interface
]]
    if OMSNSREAL == "1" then
        data = data .. [[
- PRINT OUT EXACTLY ONE INSTAGRAM INTERFACE ONLY AFTER UPLOADING INSTAGRAM POST
]]
    elseif OMSNSREAL == "0" then
        data = data .. [[
- ALWAYS PRINT OUT EXACTLY ONE INSTAGRAM INTERFACE
]]
    end

    if OMSNSTARGET == "0" then
        data = data .. [[
- MAKE a {{user}}'s INSTAGRAM INTERFACE
- MUST INCLUDE THE {{user}}'s SFW POST
    - NO NSFW
]]
    elseif OMSNSTARGET == "1" then
        data = data .. [[
- MAKE a {{char}}'s INSTAGRAM INTERFACE
- MUST INCLUDE THE {{char}}'s SFW POST
    - NO NSFW
]]
    elseif OMSNSTARGET == "2" then
        data = data .. [[
- MAKE a (RANDOM OPPONENT NPC)'s INSTAGRAM INTERFACE
- MUST INCLUDE THE (RANDOM OPPONENT NPC)'s SFW POST
    - NO NSFW
]]
    end

    data = data .. [[
#### Instagram Interface Template
- AI must follow this template:
    - INSTA[NAME:(Real Name)|IID:(Instagram ID)|IPROFILE:(Profile Image)|POST:(Post Content)|MEDIA:(Media)|HASH:(Hashtags)|TIME:(Posted Date)|LIKES:(Likes Count)|REPLY:(Reply Count)|SHARE:(Share Count)]
    - NAME: Real name of the Instagram account's owner(e.g., 'Eun-Young').
    - IID: The unique identifier for the character on Instagram, no @ sign.
        - If character ALREADY has an Instagram ID, use the EXISTING ONE.
        - Else, MAKE UP a new one.
            - Example: If INSTA[NAME:Iono|IID:Moyamo_PaldeaQueen|...] exists.
                - Invalid: INSTA[NAME:Iono|IID:Moyamo_PaldeaStreaming|...]
                - Valid: INSTA[NAME:Iono|IID:Moyamo_PaldeaQueen|...]
    - IPROFILE: The profile image of the character on Instagram.
]]  
    if OMSNSNOIMAGE == "0" then
        data = data .. [[
        - Print '<OM>' Exactly.
    - POST: Content of the Post.
        - MUST INCLUDE the character's SFW POST.
        - NO #HASHTAGS ALLOWED AT HERE.
            - Invalid: Hello! I'm Akari #Akari
            - Valid: Hello! I'm Akari
    - MEDIA: Media of the post
        - Print '<OM>' Exactly.
]]
    elseif OMSNSNOIMAGE == "1" then
        if OMSNSTARGET == "0" then
            data = data .. [[
        - Print {{source::user}} Exactly.
    - POST: Content of the Post.
        - MUST INCLUDE the {{user}}'s SFW POST.
        - NO #HASHTAGS ALLOWED AT HERE.
            - Invalid: Hello! I'm Akari #Akari
            - Valid: Hello! I'm Akari
    - MEDIA: Media of the post
        - Describe the situation of the instagram post.
]]
        elseif OMSNSTARGET == "1" then
            data = data .. [[
        - Print {{source::char}} Exactly.
    - POST: Content of the Post.
        - MUST INCLUDE the {{char}}'s SFW POST.
        - NO #HASHTAGS ALLOWED AT HERE.
            - Invalid: Hello! I'm Akari #Akari
            - Valid: Hello! I'm Akari
    - MEDIA: Media of the post
        - Describe the situation of the instagram post.
]]           
        end
    end

    data = data .. [[
    - HASH: The hashtags of the post.	
        - Each tag MUST BE wrapped in → and ←.
        - Final value example: →Travelstagram←→Happy←→With Boyfriend←.
    - TIME: The date and time the post was made.
        - Format: MM DD or Day/Hour/Minute Ago.
            - Example:
                - April 12th
                - 5 minutes ago
                - 1 hour ago
                - ...
    - LIKES: The number of likes on the post.
    - REPLY: The number of replies to the post.
    - SHARE: The number of shares of the post.
    - Example:
]]
    if OMSNSNOIMAGE == "0" then
        data = data .. [[
    - INSTA[NAME:Lee Ye-Eun|IID:YeEunLove_|IPROFILE:<OM>|POST:I'm going to the park today!|MEDIA:<OM>|HASH:→Travelstagram←→Happy←→With Boyfriend←|TIME:5 minutes ago|LIKES:172|REPLY:168|SHARE:102]
]]
    elseif OMSNSNOIMAGE == "1" then
        if OMSNSTARGET == "0" then
            data = data .. [[
    - INSTA[NAME:Lee Ye-Eun|IID:YeEunLove_|IPROFILE:{{source::user}}|POST:I'm going to the park today!|MEDIA:Ye-Eun is taking a selfie with her boy friend|HASH:→Travelstagram←→Happy←→With Boyfriend←|TIME:5 minutes ago|LIKES:172|REPLY:168|SHARE:102]
]]
        elseif OMSNSTARGET == "1" then
            data = data .. [[
    - INSTA[NAME:Lee Ye-Eun|IID:YeEunLove_|IPROFILE:{{source::char}}|POST:I'm going to the park today!|MEDIA:Ye-Eun is taking a selfie with her boy friend|HASH:→Travelstagram←→Happy←→With Boyfriend←|TIME:5 minutes ago|LIKES:172|REPLY:168|SHARE:102]
]]
        end
    end

    return data
end

local function changeInsta(triggerId, data)
    local OMSNSNOIMAGE = getGlobalVar(triggerId, "toggle_OMSNSNOIMAGE") or "0"
    local OMSNSTARGET = getGlobalVar(triggerId, "toggle_OMSNSTARGET") or "0"

    -- INSTA[NAME:(Real Name)|IID:(Instagram ID)|IPROFILE:(Profile Image)|POST:(Post Content)|MEDIA:(Media)|HASH:(Hashtags)|TIME:(Posted Date)|LIKES:(Likes Count)|REPLY:(Reply Count)|SHARE:(Share Count)]

    local InstaTemplate = [[
<style>
html{box-sizing:border-box;height:100%}*,*::before,*::after{box-sizing:inherit;margin:0;padding:0}body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;font-size:14px;line-height:1.4;background-color:#fff;color:#262626;margin:0;padding:0;min-height:100%}.iphone-frame-container{display:none}
@media {body{background-color:#1c1c1e}.iphone-frame-container{display:block;width:100%;max-width:375px;height:calc(100vh - 40px);max-height:812px;margin:20px auto;background-color:#111;border:8px solid #000;border-radius:40px;box-shadow:0 10px 30px rgba(0,0,0,0.3);overflow:hidden;position:relative}.iphone-screen{background-color:#fff;width:100%;height:100%;overflow:hidden;position:relative;padding-top:0;border-radius:32px}}.instagram-app{background-color:#fff;height:100%;display:flex;flex-direction:column;overflow:hidden;color:#262626}.insta-header{display:flex;justify-content:space-between;align-items:center;padding:8px 12px;border-bottom:1px solid #dbdbdb;background-color:#fff;flex-shrink:0;height:44px}.insta-header .header-left{display:flex;align-items:center;margin-bottom:-10px}.insta-header .logo-text{margin-left:10px;color:#262626}.insta-header .actions{display:flex;align-items:center}.insta-header .actions .icon{margin-left:20px;cursor:pointer}.insta-stories{display:flex;padding:10px 0 10px 12px;border-bottom:1px solid #dbdbdb;overflow-x:auto;background-color:#fff;flex-shrink:0;-ms-overflow-style:none;scrollbar-width:none}.insta-stories::-webkit-scrollbar{display:none}.story-item{text-align:center;margin-right:12px;flex-shrink:0;position:relative}
.story-image-wrapper { width: 64px; height: 64px; border-radius: 50%; display: flex; align-items: center; justify-content: center; padding: 0.25px; position: relative; z-index: 1; background-color: #fff; }
.story-image-wrapper::before { content: ""; position: absolute; top: -2px; left: -2px; right: -2px; bottom: -2px; border-radius: 50%; background: linear-gradient(45deg, #f09433 0%, #e6683c 25%, #dc2743 50%, #cc2366 75%, #bc1888 100%); z-index: -1; }
.story-item img { width: 100%; height: 100%; border-radius: 50%; display: block; background-color: #efefef; }
.story-item.my-story .story-image-wrapper { padding: 0; width: 60px; height: 60px; border: 1px solid #dbdbdb; background-color: #fff; }
.story-item.my-story .story-image-wrapper::before { display: none; }
.story-item.my-story img { width: 100%; height: 100%; }
.add-story-icon { position: absolute; bottom: 0px; right: 0px; background-color: #0095f6; border-radius: 50%; width: 20px; height: 20px; display: flex; align-items: center; justify-content: center; border: 2px solid #fff; color: #fff; font-size: 16px; font-weight: bold; }
.add-story-icon::after { content: "+"; position: absolute; top: 52%; left: 48%; transform: translate(-50%, -50%); }
.story-item span { font-size: 12px; color: #262626; margin-top: 4px; display: block; max-width: 64px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.insta-feed { flex-grow: 1; overflow-y: auto; background-color: #fafafa; }
.post-item { background-color: #fff; border-bottom: 1px solid #dbdbdb; }
.post-header { display: flex; align-items: center; padding: 8px 12px; height: 40px; }
.post-header img { width: 32px; height: 32px; border-radius: 50%; margin-right: 10px; background-color: #efefef; }
.post-header .username { font-weight: 600; color: #262626; flex-grow: 1; font-size: 14px; }
.post-image-placeholder { width: 100%; padding-top: 100%; background-color: #efefef; position: relative; display: flex; align-items: center; justify-content: center; }
.post-image img { width: 100%; display: block; max-height: 500px; object-fit: cover; }
.post-actions { display: flex; align-items: center; padding: 8px 12px 6px; }
.post-actions .icon { margin-right: 12px; cursor: pointer; }
.post-actions .action-save {margin-left: auto;margin-right: 0;}
.post-likes {padding: 0 12px;font-weight: 600;font-size: 14px;margin-bottom: 6px;}
.post-caption {padding: 0 12px 4px;font-size: 14px;line-height: 1.3;}
.post-caption .username {font-weight: 600;margin-right: 5px;}
.post-caption .hashtag {color: #00376b;text-decoration: none;display: inline;}
.post-caption .hashtag span:before {content: "#";}
.post-comments-link {padding: 0 12px 4px;font-size: 14px;color: #8e8e8e;cursor: pointer;}
.post-time {padding: 0 12px 10px;font-size: 10px;color: #8e8e8e;text-transform: uppercase;}
.insta-nav {display: flex;justify-content: space-around;align-items: center;padding: 0px 12px;height: 50px;border-top: 1px solid #dbdbdb;background-color: #fff;flex-shrink: 0;}
.insta-nav .icon {width: 28px;height: 28px;border-radius: 50%;overflow: hidden;}
.insta-nav .icon img {width: 100%;height: 100%;object-fit: cover;}
.insta-nav .icon.profile-icon img {border: 1px solid #dbdbdb;background-color: #efefef;}
.icon svg {width: 24px;height: 24px;fill: currentColor;vertical-align: middle;}
.icon.outline svg {fill: none;stroke: currentColor;stroke-width: 2px;stroke-linecap: round;stroke-linejoin: round;}
.insta-header .actions .icon svg {width: 24px;height: 24px;}
.post-actions .icon svg {width: 26px;height: 26px;}
.post-header .options-icon svg {width: 20px;height: 20px;fill: #262626;}
.insta-nav .icon {display: flex;align-items: center;justify-content: center;}
.insta-nav .icon svg {width: 26px;height: 26px;}
.insta-nav .icon.profile-icon {width: 28px;height: 28px;border-radius: 50%;overflow: hidden;}
.insta-nav .icon.profile-icon img {width: 100%;height: 100%;object-fit: cover;border: 1px solid #dbdbdb;background-color: #efefef;}
.insta-nav .icon.active svg {fill: #262626;stroke: #262626;}
.insta-nav .icon.active.icon-home svg path {fill-rule: evenodd;}
.add-story-icon svg {width: 12px;height: 12px;stroke: #fff;stroke-width: 2;}
</style>
]]

    local instaPattern = "INSTA%[NAME:([^|]*)|IID:([^|]*)|IPROFILE:([^|]*)|POST:([^|]*)|MEDIA:([^|]*)|HASH:([^|]*)|TIME:([^|]*)|LIKES:([^|]*)|REPLY:([^|]*)|SHARE:([^%]]*)%]"
    data = string.gsub(data, instaPattern, function(
        name, iid, iprofile_raw, post_content, media_content, hash_content, time_text, likes_count, reply_count, share_count)
    
        local html = {}

        table.insert(html, InstaTemplate)
        table.insert(html, "<div class='iphone-frame-container'>")
        table.insert(html, "<div class='iphone-screen'>")
        
        table.insert(html, "<div class='instagram-app'>")
        table.insert(html, "<header class='insta-header'>")
        table.insert(html, "<div class='header-left'>")
        table.insert(html, "<div class='logo-text'><img src='{{raw::Insta_Text.png}}'></div>")
        table.insert(html, "</div>")
        table.insert(html, "<div class='actions' style='margin-left: auto;'>")
        table.insert(html, [[<span class='icon icon-heart outline'>
<svg aria-label="활동 피드" viewBox="0 0 24 24">
    <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"></path>
</svg>
</span>]])
        table.insert(html, [[<span class='icon icon-dm outline'>
<svg aria-label="DM" viewBox="0 0 24 24">
    <line fill="none" stroke="currentColor" stroke-linejoin="round" stroke-width="2" x1="22" x2="9.218" y1="3" y2="10.083"></line>
    <polygon fill="none" points="11.698 20.334 22 3.001 2 3.001 9.218 10.084 11.698 20.334" stroke="currentColor" stroke-linejoin="round" stroke-width="2"></polygon>
</svg>
</span>]])
        table.insert(html, "</div>")
        table.insert(html, "</header>")

        table.insert(html, "<section class='insta-stories'>")
        table.insert(html, "<div class='story-item'>")
        table.insert(html, "<div class='story-image-wrapper'>")

        table.insert(html, "<img src='{{source::user}}'>")

        table.insert(html, "<div class='add-story-icon'></div></div>")
        table.insert(html, "<span>내 스토리</span>")
        table.insert(html, "</div>")
        table.insert(html, "</section>")

        table.insert(html, "<main class='insta-feed'>")
        table.insert(html, "<article class='post-item'>")
        table.insert(html, "<div class='post-header'>")

        if OMSNSNOIMAGE == "0" then
            table.insert(html, iprofile_raw)
        elseif OMSNSNOIMAGE == "1" then
            if OMSNSTARGET == "0" then
                table.insert(html, "<img src='" .. "{{source::user}}" .. "' alt='PROFILE IMAGE'>")
            elseif OMSNSTARGET == "1" then
                table.insert(html, "<img src='" .. "{{source::char}}" .. "' alt='PROFILE IMAGE'>")
            end
        end
        table.insert(html, "<span class='username'>" .. (name or "Character Name") .. "</span>")
        table.insert(html, [[<span class='icon options-icon'>
<svg aria-label="옵션 더 보기" viewBox="0 0 24 24">
    <circle cx="12" cy="12" r="1.5"></circle>
    <circle cx="19.5" cy="12" r="1.5"></circle>
    <circle cx="4.5" cy="12" r="1.5"></circle>
</svg>
</span>]])
        table.insert(html, "</div>")
        table.insert(html, "<div class='post-image'>" .. media_content .. "</div>")

        table.insert(html, "<div class='post-actions'>")
        table.insert(html, [[<span class='icon icon-heart-action outline'>
<svg aria-label="좋아요" viewBox="0 0 24 24">
    <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"></path>
</svg>
</span>]])
        table.insert(html, [[<span class='icon icon-comment outline'>
<svg aria-label="댓글 달기" viewBox="0 0 24 24">
    <path d="M20.656 17.008a9.993 9.993 0 1 0-3.59 3.615L22 22Z" fill="none" stroke="currentColor" stroke-linejoin="round" stroke-width="2"></path>
</svg>
</span>]])
        table.insert(html, [[<span class='icon icon-dm outline'>
<svg aria-label="게시물 보내기" viewBox="0 0 24 24">
    <line fill="none" stroke="currentColor" stroke-linejoin="round" stroke-width="2" x1="22" x2="9.218" y1="3" y2="10.083"></line>
    <polygon fill="none" points="11.698 20.334 22 3.001 2 3.001 9.218 10.084 11.698 20.334" stroke="currentColor" stroke-linejoin="round" stroke-width="2"></polygon>
</svg>
</span>]])
        table.insert(html, [[<span class='icon icon-save outline action-save'>
<svg aria-label="저장" viewBox="0 0 24 24">
    <polygon fill="none" points="20 21 12 13.44 4 21 4 3 20 3 20 21" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></polygon>
</svg>
</span>]])
        table.insert(html, "</div>")

        table.insert(html, "<div class='post-caption'>")
        table.insert(html, "<a href='#' class='username'>" .. (iid or "Character ID") .. "</a>")
        table.insert(html, "<p>" .. (post_content or "Post Content") .. "</p>")
        table.insert(html, "<div class='hashtag'>" .. hash_content .. "</div>")
        table.insert(html, "</div>")
        table.insert(html, "<div class='post-time'>" .. (time_text or "Posted Time") .. "</div>")

        -- 리롤 버튼 추가 - 추출한 iid 값 기반으로 identifier 설정
        local buttonJsonProfile = '{"action":"INSTA_PROFILE_REROLL", "identifier":"' .. (iid or "") .. '", "index":"' .. 0 ..'"}'
        local buttonJsonBody = '{"action":"INSTA_REROLL", "identifier":"' .. (iid or "") .. '", "index":"' .. 0 ..'"}'

        table.insert(html, "<div class=\"reroll-button-wrapper\">")
        table.insert(html, "<div class=\"global-reroll-controls\">")
        table.insert(html, "<button style=\"text-align: center;\" class=\"reroll-button\" risu-btn='" .. buttonJsonProfile .. "'>PROFILE</button>")
        table.insert(html, "<button style=\"text-align: center;\" class=\"reroll-button\" risu-btn='" .. buttonJsonBody .. "'>POST</button>")
        
        table.insert(html, "</div></div>")

        table.insert(html, "</article>")
        table.insert(html, "</main>")

        table.insert(html, "<nav class='insta-nav'>")
        table.insert(html, [[<span class='icon icon-home active'>
<svg aria-label="홈" viewBox="0 0 24 24">
    <path d="M9.005 16.545a2.997 2.997 0 0 1 2.997-2.997A2.997 2.997 0 0 1 15 16.545V22h7V11.543L12 2 2 11.543V22h7.005Z" fill="currentColor" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
</svg>
</span>]])
        table.insert(html, [[<span class='icon icon-search outline'>
<svg aria-label="검색" viewBox="0 0 24 24">
    <path d="M19 10.5A8.5 8.5 0 1 1 10.5 2a8.5 8.5 0 0 1 8.5 8.5Z" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path>
    <line fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" x1="16.511" x2="22" y1="16.511" y2="22"></line>
</svg>
</span>]])
        table.insert(html, [[<span class='icon icon-add outline'>
<svg aria-label="새로운 게시물" viewBox="0 0 24 24">
    <path d="M2 12h20M12 2v20" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"></path> <!-- 단순 + 모양 -->
    <!-- <rect fill="none" height="18" rx="5" ry="5" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" width="18" x="3" y="3"></rect> <line fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" x1="12" x2="12" y1="8" y2="16"></line><line fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" x1="8" x2="16" y1="12" y2="12"></line> -- 사각형 안 + 모양 -->
</svg>
</span>]])
        table.insert(html, [[<span class='icon icon-heart-nav outline'>
<svg aria-label="활동 피드" viewBox="0 0 24 24">
    <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"></path>
</svg>
</span>]])

        table.insert(html, "<span class='icon icon-profile outline'><img src='{{source::user}}'></span>")
        table.insert(html, "</nav></div></div></div>")

        return table.concat(html, "\n")

    end)

    return data
end

local function inputSNSHybrid(triggerId, data)
    local OMSNSNOIMAGE = getGlobalVar(triggerId, "toggle_OMSNSNOIMAGE") or "0"
    local OMSNSTARGET = getGlobalVar(triggerId, "toggle_OMSNSTARGET") or "0"
    local OMSNSREAL = getGlobalVar(triggerId, "toggle_OMSNSREAL") or "0"

    data = data .. [[
## SNS Interface
- TWITTER FOR NSFW POST
- INSTAGRAM FOR SFW POST
- TWO INTERFACES MUST BE PRINTED TOGETHER
    - MUST PRINT OUT THE SAME CHARACTER's SNS INTERFACE

### Twitter Interface
]]
    if OMSNSREAL == "1" then
        data = data .. [[
- PRINT OUT EXACTLY ONE TWITTER INTERFACE ONLY AFTER UPLOADING TWITTER POST
]]
    elseif OMSNSREAL == "0" then
        data = data .. [[
- ALWAYS PRINT OUT EXACTLY ONE TWITTER INTERFACE
]]        
    end

    if OMSNSTARGET == "0" then
        data = data .. [[
- MAKE a {{user}}'s TWITTER INTERFACE
- MUST INCLUDE THE {{user}}'s PRIVATE NSFW POST
]]
    elseif OMSNSTARGET == "1" then
        data = data .. [[
- MAKE a {{char}}'s TWITTER INTERFACE
- MUST INCLUDE THE {{char}}'s PRIVATE NSFW POST
]]
    elseif OMSNSTARGET == "2" then
        data = data .. [[
- MAKE a (RANDOM OPPONENT NPC)'s TWITTER INTERFACE
- MUST INCLUDE THE (RANDOM OPPONENT NPC)'s PRIVATE NSFW POST
]]
    end

    data = data .. [[
    - NO SFW ALLOWED AT HERE
#### Twitter Interface Template
- AI must follow this template:
    - TWITTER[NAME:(Real Name)|TNAME:(Twitter Nickname)|TID:(Twitter ID)|TPROFILE:(Profile Image)|TWEET:(Tweet Content)|MEDIA:(Media)|HASH:(Hashtags)|TIME:(Posted Date/Time)|VIEW:(Viewer Count)|REPLY:(Reply Count)|RETWEET:(Retweet Count)|LIKES:(Likes Count)|COMMENT:(Viewer Nickname1)|(Comment Body1)|(Viewer Nickname2)|(Comment Body2)|...]
    - NAME: Real name of the Twitter account's owner(e.g., 'Eun-Young').
    - TNAME: The nickname of the character on Twitter.
    - TID: The unique identifier for the character on Twitter, no @ sign.
        - If character ALREADY has a Twitter ID, use the EXISTING ONE.
        - Else, MAKE UP a new one.
            - Example: If TWITTER[NAME:Iono|TNAME:⚡Moyamo⚡|TID:Moyamo_PaldeaQueen|...] exists.
                - Invalid: TWITTER[NAME:Iono|TNAME:⚡Moyamo⚡|TID:Moyamo_PaldeaStreaming|...]
                - Valid: TWITTER[NAME:Iono|TNAME:⚡Moyamo⚡|TID:Moyamo_PaldeaQueen|...]
    - TPROFILE: The profile image of the character on Twitter.
]]  
    if OMSNSNOIMAGE == "0" then
        data = data .. [[
        - Print '<OM>' Exactly.
    - TWEET: Content of the Tweet.
        - MUST INLUDE the character's NSFW POST.
        - NO #HASHTAGS ALLOWED AT HERE.
            - Invalid: Hello! I'm Akari #Akari
            - Valid: Hello! I'm Akari
    - MEDIA: Media of the post
        - Print '<OM>' Exactly.
]]
    elseif OMSNSNOIMAGE == "1" then
        if OMSNSTARGET == "0" then
            data = data .. [[
        - Print {{source::user}} Exactly.
    - TWEET: Content of the Tweet.
        - MUST INCLUDE the {{user}}'s NSFW POST.
        - NO #HASHTAGS ALLOWED AT HERE.
            - Invalid: Hello! I'm Akari #Akari
            - Valid: Hello! I'm Akari
    - MEDIA: Media of the post
        - Describe the situation of the twitter post.
]]
        elseif OMSNSTARGET == "1" then
            data = data .. [[
        - Print {{source::char}} Exactly.
    - TWEET: Content of the Tweet.
        - MUST INCLUDE the {{char}}'s NSFW POST.
        - NO #HASHTAGS ALLOWED AT HERE.
            - Invalid: Hello! I'm Akari #Akari
            - Valid: Hello! I'm Akari
    - MEDIA: Media of the post
        - Describe the situation of the twitter post.
]]           
        end
    end

    data = data .. [[
    - HASH: The hashtags of the tweet.	
        - Each tag MUST BE wrapped in → and ←.
        - If post includes NSFW content, first tag is '섹트'.
            - No #HASHTAGS ALLOWED AT HERE.
        - Final value example: →섹트←→BitchDog←→PublicToilet←.
    - TIME: The date and time the tweet was posted.
        - Format: AM/PM hh:mm·YYYY. MM. DD (e.g., PM 12:58·2026. 03. 29)
    - VIEW: The number of viewers of the tweet.
    - REPLY: The number of replies to the tweet.
    - RETWEET: The number of retweets of the tweet.
    - LIKES: The number of likes on the tweet.
    - COMMENT:
        - Viewer Nickname: The nickname of the viewer who replied to the tweet.
            - Use the realistic Twitter nickname.
            - Final value example:
                - Invalid: KinkyDog
                - Valid: 섹트헌터
        - Comment Body: The content of the reply to the tweet.
            - Print the reply of a viewer with crude manner.
                - Example:
                    - Invalid: Whoa, you shouldn't post such photos in a place like this;;
                    - Valid: Damn this is so fucking arousing bitch! lol
    - Example:
]]
    if OMSNSNOIMAGE == "0" then
        data = data .. [[
    - TWITTER[NAME:Lee Ye-Eun|TNAME:❤️Flame Heart Ye-Eun❤️|TID:FlameHeart_eun|TPROFILE:<OM>|TWEET:Wanna see more?|MEDIA:<OM>|HASH:→섹트←→MagicalGirl←→FlameHeart←|TIME:11:58 PM·2024. 06. 12|VIEW:182|REPLY:3|RETWEET:8|LIKES:21|COMMENT:HeartFlutter|Who did you meet??|MagicalGirlFan|Omg is this a real-time tweet from Flame Heart?!|SexHunter|What happened? Post pics]
]]
    elseif OMSNSNOIMAGE == "1" then
        if OMSNSTARGET == "0" then
            data = data .. [[
    - TWITTER[NAME:Lee Ye-Eun|TNAME:❤️FlameHeart Ye-Eun❤️|TID:FlameHeart_eun|TPROFILE:{{source::user}}|TWEET:Wanna see more?|MEDIA:A magical girl showing her panties|HASH:→섹트←→Magicalgirl←→Flameheart←|TIME:11:58 PM·2024. 06. 12|VIEW:182|REPLY:3|RETWEET:8|LIKES:21|COMMENT:HeartThrobbing|Did you meet someone??|MagicalGirlFan|Wow FlameHeart real-time tweet?!|SexHunter|What happened? Show us pics]
]]
        elseif OMSNSTARGET == "1" then
            data = data .. [[
    - TWITTER[NAME:Lee Ye-Eun|TNAME:❤️FlameHeart Ye-Eun❤️|TID:FlameHeart_eun|TPROFILE:{{source::char}}|TWEET:Wanna see more?|MEDIA:A magical girl showing her panties|HASH:→섹트←→Magicalgirl←→Flameheart←|TIME:11:58 PM·2024. 06. 12|VIEW:182|REPLY:3|RETWEET:8|LIKES:21|COMMENT:HeartThrobbing|Did you meet someone??|MagicalGirlFan|Wow FlameHeart real-time tweet?!|SexHunter|What happened? Show us pics]
]]
        end
    end

    data = data .. [[
### Instagram Interface
]]

    if OMSNSREAL == "1" then
        data = data .. [[
- PRINT OUT THE SAME CHARACTER OF THE ABOVE TWITTER INTERFACE
- PRINT OUT EXACTLY ONE INSTAGRAM INTERFACE ONLY AFTER UPLOADING INSTAGRAM POST
]]
    elseif OMSNSREAL == "0" then
        data = data .. [[
- PRINT OUT THE SAME CHARACTER OF THE ABOVE TWITTER INTERFACE
- ALWAYS PRINT EXACTLY ONE INSTAGRAM INTERFACE
]]          
    end

    if OMSNSTARGET == "0" then
        data = data .. [[
- MAKE a {{user}}'s INSTAGRAM INTERFACE
- MUST INCLUDE THE {{user}}'s PUBLIC SFW POST
]]
    elseif OMSNSTARGET == "1" then
        data = data .. [[
- MAKE a {{char}}'s INSTAGRAM INTERFACE
- MUST INCLUDE THE {{char}}'s PUBLIC SFW POST
]]
    elseif OMSNSTARGET == "2" then
        data = data .. [[
- MAKE a (RANDOM OPPONENT NPC)'s INSTAGRAM INTERFACE
- MUST INCLUDE THE (RANDOM OPPONENT NPC)'s PUBLIC SFW POST
]]
    end

    data = data .. [[
    - NO NSFW ALLOWED AT HERE
#### Instagram Interface Template
- AI must follow this template:
    - INSTA[NAME:(Real Name)|IID:(Instagram ID)|IPROFILE:(Profile Image)|POST:(Post Content)|MEDIA:(Media)|HASH:(Hashtags)|TIME:(Posted Date)|LIKES:(Likes Count)|REPLY:(Reply Count)|SHARE:(Share Count)]
    - NAME: Real name of the Instagram account's owner(e.g., 'Eun-Young').
    - IID: The unique identifier for the character on Instagram, no @ sign.
        - If character ALREADY has an Instagram ID, use the EXISTING ONE.
        - Else, MAKE UP a new one.
            - Example: If INSTA[NAME:Iono|IID:Moyamo_PaldeaQueen|...] exists.
                - Invalid: INSTA[NAME:Iono|IID:Moyamo_PaldeaStreaming|...]
                - Valid: INSTA[NAME:Iono|IID:Moyamo_PaldeaQueen|...]
    - IPROFILE: The profile image of the character on Instagram.
]]  
    if OMSNSNOIMAGE == "0" then
        data = data .. [[
        - Print '<OM>' Exactly.
    - POST: Content of the Post.
        - MUST INCLUDE the character's SFW POST.
        - NO #HASHTAGS ALLOWED AT HERE.
            - Invalid: Hello! I'm Akari #Akari
            - Valid: Hello! I'm Akari
    - MEDIA: Media of the post
        - Print '<OM>' Exactly.
]]
    elseif OMSNSNOIMAGE == "1" then
        if OMSNSTARGET == "0" then
            data = data .. [[
        - Print {{source::user}} Exactly.
    - POST: Content of the Post.
        - MUST INCLUDE the {{user}}'s SFW POST.
        - NO #HASHTAGS ALLOWED AT HERE.
            - Invalid: Hello! I'm Akari #Akari
            - Valid: Hello! I'm Akari
    - MEDIA: Media of the post
        - Describe the situation of the instagram post.
]]
        elseif OMSNSTARGET == "1" then
            data = data .. [[
        - Print {{source::char}} Exactly.
    - POST: Content of the Post.
        - MUST INCLUDE the {{char}}'s SFW POST.
        - NO #HASHTAGS ALLOWED AT HERE.
            - Invalid: Hello! I'm Akari #Akari
            - Valid: Hello! I'm Akari
    - MEDIA: Media of the post
        - Describe the situation of the instagram post.
]]           
        end
    end

    data = data .. [[
    - HASH: The hashtags of the post.	
        - Each tag MUST BE wrapped in → and ←.
        - Final value example: →Travelstagram←→Happy←→With Boyfriend←.
    - TIME: The date and time the post was made.
        - Format: MM DD or Day/Hour/Minute Ago.
            - Example:
                - April 12th
                - 5 minutes ago
                - 1 hour ago
                - ...
    - LIKES: The number of likes on the post.
    - REPLY: The number of replies to the post.
    - SHARE: The number of shares of the post.
    - Example:
]]
    if OMSNSNOIMAGE == "0" then
        data = data .. [[
    - INSTA[NAME:Lee Ye-Eun|IID:YeEunLove_|IPROFILE:<OM>|POST:I'm going to the park today!|MEDIA:<OM>|HASH:→Travelstagram←→Happy←→With Boyfriend←|TIME:5 minutes ago|LIKES:172|REPLY:168|SHARE:102]
]]
    elseif OMSNSNOIMAGE == "1" then
        if OMSNSTARGET == "0" then
            data = data .. [[
    - INSTA[NAME:Lee Ye-Eun|IID:YeEunLove_|IPROFILE:{{source::user}}|POST:I'm going to the park today!|MEDIA:Ye-Eun is taking a selfie with her boy friend|HASH:→Travelstagram←→Happy←→With Boyfriend←|TIME:5 minutes ago|LIKES:172|REPLY:168|SHARE:102]
]]
        elseif OMSNSTARGET == "1" then
            data = data .. [[
    - INSTA[NAME:Lee Ye-Eun|IID:YeEunLove_|IPROFILE:{{source::char}}|POST:I'm going to the park today!|MEDIA:Ye-Eun is taking a selfie with her boy friend|HASH:→Travelstagram←→Happy←→With Boyfriend←|TIME:5 minutes ago|LIKES:172|REPLY:168|SHARE:102]
]]
        end
    end

    return data
end


local function changeSNSHybrid(triggerId, data)
    local originalData = data

    -- 패턴을 사용해 SNS 패턴을 찾기
    local fullTwitterTagPattern = "(TWITTER%[([^%]]*)%])"
    local fullInstaTagPattern = "(INSTA%[([^%]]*)%])"

    local twitterTagFound = string.match(originalData, fullTwitterTagPattern)
    local instaTagFound = string.match(originalData, fullInstaTagPattern)

    local twitterFullHtmlOutput = nil
    local instaFullHtmlOutput = nil

    -- 트위터 존재 시 changeTwitter 호출
    if twitterTagFound then
        -- Pass only the matched tag to changeTwitter to get its specific HTML output
        twitterFullHtmlOutput = changeTwitter(triggerId, twitterTagFound)
    end

    -- 인스타 존재시 changeInsta 호출
    if instaTagFound then
        instaFullHtmlOutput = changeInsta(triggerId, instaTagFound)
    end

    local finalTwitterBody = nil
    local finalInstaBody = nil
    local styleBlocks = {} -- 유니크 스타일 블록 추가

    -- 헬퍼 함수
    local function addUniqueStyle(styleContent)
        if styleContent and styleContent ~= "" then
            local found = false
            for _, existingStyle in ipairs(styleBlocks) do
                if existingStyle == styleContent then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(styleBlocks, styleContent)
            end
        end
    end

    if twitterFullHtmlOutput then
        local styleContent = twitterFullHtmlOutput:match("<style>(.-)</style>")
        addUniqueStyle(styleContent)
        -- <style> 태그를 제거하고 changeTwitter의 출력에 특정한 <br> 태그를 제거
        finalTwitterBody = twitterFullHtmlOutput:gsub("<style>.-</style>", ""):gsub("<br%s*/?%s*>$", "")
    end

    if instaFullHtmlOutput then
        local styleContent = instaFullHtmlOutput:match("<style>(.-)</style>")
        addUniqueStyle(styleContent)
        finalInstaBody = instaFullHtmlOutput:gsub("<style>.-</style>", "")
    end
    
    local combinedStyles = ""
    if #styleBlocks > 0 then
        combinedStyles = "<style>\n" .. table.concat(styleBlocks, "\n\n") .. "\n</style>\n"
    end

    -- 데이터에서 태그 제거
    local cleanedData = originalData
    if twitterTagFound then
        cleanedData = string.gsub(cleanedData, fullTwitterTagPattern, "", 1)
    end
    if instaTagFound then
        cleanedData = string.gsub(cleanedData, fullInstaTagPattern, "", 1)
    end
    
    -- 사이의 빈 메시지 제거
    cleanedData = cleanedData:gsub("<p>%s*</p>", ""):gsub("^(%s*<br%s*/?%s*>)*%s*", ""):gsub("(%s*<br%s*/?%s*>)*%s*$", "")
    cleanedData = cleanedData:match("^%s*(.-)%s*$") or "" -- Final trim

    -- 상황1, 성공적일 경우
    if finalTwitterBody and finalInstaBody then
        local hybridSpecificCss = [[
<style>
.sns-hybrid-container {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 20px;
    padding: 20px 0;
    max-width: 800px;
    margin: 0 auto;
    flex-wrap: wrap; /* Changed to wrap */
}

.sns-column {
    flex: 0 1 360px; /* Changed flex-grow to 0 to prevent stretching */
    width: 100%; /* Added full width */
    max-width: 375px;
    display: flex;
    justify-content: center;
}

.sns-column .iphone-frame-container {
    margin: 0 !important;
    width: 100% !important;
    max-width: 375px !important;
}

body.hybrid-sns-active {
    background-color: #fafafa;
}

@media screen and (max-width: 799px) {
    .sns-hybrid-container {
        flex-direction: column;
        align-items: center;
        padding: 10px;
        gap: 10px; /* Reduced gap for mobile */
    }
    
    .sns-column {
        width: 100%;
        max-width: 375px;
        margin: 0;
    }
}

@media screen {
    .sns-hybrid-container {
        padding: 5px;
    }
}
</style>
]]
        -- css 추가
        local hybridLayout = combinedStyles .. hybridSpecificCss .. [[
<script>document.body.classList.add('hybrid-sns-active');</script>
<div class="sns-hybrid-container">
    <div class="sns-column"> <!-- Instagram Column -->
        ]] .. finalInstaBody .. [[
    </div>
    <div class="sns-column"> <!-- Twitter Column -->
        ]] .. finalTwitterBody .. [[
    </div>
</div>
]]
        if cleanedData == "" then
            return hybridLayout
        else
            return cleanedData .. "\n" .. hybridLayout
        end

    -- 상황 2, 트위터만 존재할 경우
    elseif finalTwitterBody then
        if cleanedData == "" then
            return twitterFullHtmlOutput -- 원래 데이터 반환
        else
            return cleanedData .. "\n" .. twitterFullHtmlOutput
        end

    -- 상황 3, 인스타그램만 존재할 경우
    elseif finalInstaBody then
        if cleanedData == "" then
            return instaFullHtmlOutput -- 원래 데이터 반환
        else
            return cleanedData .. "\n" .. instaFullHtmlOutput
        end
    end

    -- 상황4, 트위터와 인스타그램 모두 존재하지 않을 경우
    -- 원래 데이터 반환
    return originalData
end

local function inputDCInside(triggerId, data)
    local OMCOMMUNITYNOIMAGE = getGlobalVar(triggerId, "toggle_OMCOMMUNITYNOIMAGE") or "0"
    local OMDCPOSTNUMBER = getGlobalVar(triggerId, "toggle_OMDCPOSTNUMBER") or "0"
    local OMDCNOSTALKER = getGlobalVar(triggerId, "toggle_OMDCNOSTALKER") or "0"

    data = data .. [[
## Community Interface
### DCInside Gallery Interface
- PRINT OUT EXACTLY ONE DCINSIDE GALLERY INTERFACE at the BOTTOM of the RESPONSE
- MAKE ]] .. OMDCPOSTNUMBER .. [[ POSTS EXACTLY

#### DCInside Gallery Interface Template
- AI must follow this template:
    - DC[GN:(Gallery Name)|PID:(Post1 ID)|PN:(Post1 Number)|PT:(Post1 Title)|PC:(Post1 Comment)|PW:(Post1 Writer)|PD:(Post1 Date)|PV:(Post1 Views)|PR:(Post1 Recommend)|BODY:(Post1 Body)|COMMENT:(Comment1 Author)|(Comment1 Content)|(Comment2 Author)|(Comment2 Content)| ... | REPEAT POST and COMMENT ]] .. OMDCPOSTNUMBER ..[[ TIMES MORE ]
    - GN: The name of the gallery where the post is located, must include the word '갤러리'.
    - PID: The unique identifier for the post in the gallery.
    - PN: The unique number of the post in the gallery.
    - PT: The title of the post.
        - Do not include ', ", [, |, ] in the title.
    - PC: The number of comments on the post.
    - PW: The Writer of the post.
    - PD: The time post was made.
    - PV: The number of views the post has received.
    - PR: The number of recommendations the post has received.
    - BODY: The content of the post.
        - Do not include ', ", [, |, ] in the content.
]]
    if OMCOMMUNITYNOIMAGE == "0" then
        data = data .. [[
            - If the post includes an image, print a specific keyword (e.g., '<OM1>', '<OM2>', etc.) to indicate where the prompt should be generated.
]]
    end

    data = data .. [[
    - Comment Author: The author of the comment.
    - Comment Content: The content of the comment.
        - Do not include ', ", [, |, ] in the content.
    - Example:
]]
    if OMCOMMUNITYNOIMAGE == "0" then
        data = data .. [[
        - DC[GN:MapleStory Gallery|PID:maple-110987|PN:587432|PT:When the hell will I get my Dominator 22-star!!!!|PC:77|PW:Anonymous(118.235)|PD:21:07|PV:1534|PR:88|BODY:<OM1>I'm really pissed off. Who the fuck created StarForce? Today I blew 20 billion mesos and couldn't even recover my 21-star item. I was planning to get my Dominator to 22-star before going to Arcane, but now I feel like my life is ruined. Sigh... I need a drink|COMMENT:Explode(211.36)|How much are you burning just to get on the hot posts? lol|PongPongBrother(121.171)|200 billion is lucky, I spent 500 billion and only got 20-star, fuck off|▷Mesungie◁|Hang in there... You'll get it someday... But not today lol|DestroyerKing(223.38)|Nope~ Mine is one-tap~^^|Anonymous(110.70)|Did someone hold a knife to your throat and force you to spend mesos? lol|NaJeBul(1.234)|If you don't like it, quit the game, idiot lol|.............|PID:maple-111007|PN:587451|PT:Honestly, is this event really the best ever?|PC:55|PW:Veteran(1.234)|PD:21:41|PV:2511|PR:48|BODY:<OM7>The rewards are terrible, nothing worth buying in the coin shop, they just increased the EXP requirements... I find it outrageous that they're forcing us to grind more! Isn't Kang Won-gi going too far? There should be limits to deceiving users|COMMENT:Rekka(118.41)|Yeah, but you'll still play it~|NotABot(220.85)|It's basically a non-event update, what did you expect|TruthSpeaker(175.223)|Agreed, it's always the same lol|NewUser(112.158)|I actually like it...? (just my honest opinion)|Anonymous(61.77)|What are you expecting from MapleStory?|GotComplaints(106.101)|If you don't like it, quit the game! Why do you keep struggling? lol]
]]
    elseif OMCOMMUNITYNOIMAGE == "1" then
        data = data .. [[
        - DC[GN:MapleStory Gallery|PID:maple-110987|PN:587432|PT:When the hell will I get my Dominator 22-star!!!!|PC:77|PW:Anonymous(118.235)|PD:21:07|PV:1534|PR:88|BODY:I'm really pissed off. Who the fuck created StarForce? Today I blew 20 billion mesos and couldn't even recover my 21-star item. I was planning to get my Dominator to 22-star before going to Arcane, but now I feel like my life is ruined. Sigh... I need a drink|COMMENT:Explode(211.36)|How much are you burning just to get on the hot posts? lol|PongPongBrother(121.171)|200 billion is lucky, I spent 500 billion and only got 20-star, fuck off|▷Mesungie◁|Hang in there... You'll get it someday... But not today lol|DestroyerKing(223.38)|Nope~ Mine is one-tap~^^|Anonymous(110.70)|Did someone hold a knife to your throat and force you to spend mesos? lol|NaJeBul(1.234)|If you don't like it, quit the game, idiot lol|.............|PID:maple-111007|PN:587451|PT:Honestly, is this event really the best ever?|PC:55|PW:Veteran(1.234)|PD:21:41|PV:2511|PR:48|BODY:The rewards are terrible, nothing worth buying in the coin shop, they just increased the EXP requirements... I find it outrageous that they're forcing us to grind more! Isn't Kang Won-gi going too far? There should be limits to deceiving users|COMMENT:Rekka(118.41)|Yeah, but you'll still play it~|NotABot(220.85)|It's basically a non-event update, what did you expect|TruthSpeaker(175.223)|Agreed, it's always the same lol|NewUser(112.158)|I actually like it...? (just my honest opinion)|Anonymous(61.77)|What are you expecting from MapleStory?|GotComplaints(106.101)|If you don't like it, quit the game! Why do you keep struggling? lol]
]]
    end
    data = data .. [[
#### DCInside Gallery Information
- All users typically post anonymously ('ㅇㅇ', 'ㅁㄴㅇㄹ', etc.) or use specific nicknames (고정닉). IP addresses (often partial) are usually displayed next to anonymous posts. Fixed Nicknames (고정닉) have an orange icon, Semi-fixed Nicknames (반고정닉) have a green icon.
	- Wrap with ▶ and ◀ for fixed nicknames (고정닉), ▷ and ◁ for semi-fixed nicknames (반고정닉) before the author information.
		- ▶: Internally replaced with <h1>.
		- ◀: Internally replaced with </h1>.
		- ▷: Internally replaced with <h2>.
		- ◁: Internally replaced with </h2>.
		- Example:
			- '▷겜안분◁', '▷분탕충◁', '▷비틱충차단◁', '▷유식애미◁', '▶테스터훈◀', '▶ㅇㅇ◀', '▶글쓴이병신임◀', '▶알바◀', '▶모에모에큥◀'
	- Fixed nicknames and Semi-fixed nicknames have no IP.
	- Floating users (유동닉) have no wrapping.
		- Floating users must include IP
			-Example:
				'ㅇㅇ(118.235)', '렉카(121.123)', '고닉죽이기(211.36)', '익명의 유동(223.38)'
]]
    if OMDCNOSTALKER == "1" then
        data = data .. [[
### DCInside Gallery CRITICAL
- DO NOT MENTION {{user}} and {{char}} in DCInside     
]]
    end

    return data
end

local function changeDCInside(triggerId, data)
    local OMCOMMUNITYNOIMAGE = getGlobalVar(triggerId, "toggle_OMCOMMUNITYNOIMAGE") or "0"
    local function parseAuthor(raw_author)
        if not raw_author or raw_author == "" then
            return { name = "ㅇㅇ", type = "floating", ip = nil, html = "ㅇㅇ" }
        end

        raw_author = string.gsub(raw_author, "^%s+", ""); raw_author = string.gsub(raw_author, "%s+$", "")

        local fixedName = raw_author:match("^▶(.+)◀$")
        if fixedName then
            local name = escapeHtml(fixedName)
            return { name = name, type = "fixed", ip = nil, html = "<h1>" .. name .. "</h1>" }
        end

        local semiName = raw_author:match("^▷(.+)◁$")
        if semiName then
            local name = escapeHtml(semiName)
            return { name = name, type = "semi", ip = nil, html = "<h2>" .. name .. "</h2>" }
        end

        local floatingName, floatingIp = raw_author:match("^(.*)%((.*)%)$")
        if floatingName and floatingIp then
            floatingName = string.gsub(floatingName, "^%s+", ""); floatingName = string.gsub(floatingName, "%s+$", "")
            floatingIp = string.gsub(floatingIp, "^%s+", ""); floatingIp = string.gsub(floatingIp, "%s+$", "")
            if floatingName == "" then floatingName = "ㅇㅇ" end
            local name = escapeHtml(floatingName)
            local ip = escapeHtml(floatingIp)
            return { name = name, type = "floating", ip = ip, html = name .. "<span class='writer-ip'>(" .. ip .. ")</span>" }
        else
            local name = escapeHtml(raw_author)
            return { name = name, type = "floating", ip = nil, html = name }
        end
    end

    local dcPattern = "DC%[([^%]]*)%]"
    data = string.gsub(data, dcPattern, function(replacements)
        local DCInsideTemplate = [[
<style>
html {box-sizing: border-box; height: auto;}
*, *::before, *::after {box-sizing: inherit;}
body {font-family: 'Malgun Gothic','맑은 고딕',dotum,'돋움',sans-serif; font-size: 12px; color: #333; background-color: #fff; margin: 0; padding: 0; min-height: 100%;}
.gallery-container {max-width: 900px; width: 100%; margin: 10px auto; background-color: #fff; padding: 15px 15px 20px 15px; border: 1px solid #d7d7d7; box-sizing: border-box;}
.gallery-header {display: flex; justify-content: space-between; align-items: flex-end; margin-bottom: 10px; border-bottom: 2px solid #3b4890; padding-bottom: 8px;}
.gallery-header h1 {font-size: 18px; color: #3b4890; margin: 0; font-weight: bold; line-height: 1.2;}
.gallery-top-links {white-space: nowrap; overflow: hidden; text-overflow: ellipsis; flex-shrink: 1; margin-left: 10px; padding-bottom: 2px;}
.gallery-top-links a {font-size: 11px; color: #777; text-decoration: none; margin-left: 8px; cursor: default;}
.gallery-top-links a:hover {text-decoration: none; color: #333;}
.gallery-options {display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; border-bottom: 1px solid #ccc;}
.tab-menu {padding-bottom: 0; flex-grow: 1; overflow: hidden; white-space: nowrap; display: flex;}
.tab-button {background-color: transparent; border: none; border-bottom: 3px solid transparent; padding: 8px 12px 6px 12px; cursor: default; margin-right: 5px; position: relative; font-size: 13px; color: #777; font-weight: bold;}
.tab-button.active {color: #3b4890; border-bottom-color: #3b4890; font-weight: bold;}
.gallery-actions {display: flex; align-items: center; flex-shrink: 0;}
.gallery-actions select {font-size: 11px; height: 25px; border: 1px solid #ccc; max-width: 55px; padding: 0 2px; background-color: #fff; color: #333;}
.write-button {border: 1px solid #bbb; padding: 4px 9px; background-color: #fff; color: #3b4890; text-decoration: none; font-size: 12px; margin-left: 6px; display: inline-flex; align-items: center; white-space: nowrap; border-radius: 2px; cursor: default;}
.write-button:hover {background-color: #f9f9f9;}
.write-button i {margin-right: 3px; font-style: normal; color: #3b4890;}
.gallery-header .write-button {display: none;}
.post-list-container {border-top: 1px solid #3b4890; border-bottom: 1px solid #ccc;}
.post-list-header, .post-row {display: flex; border-bottom: 1px solid #f0f0f0; align-items: center;}
.post-list-header {background-color: #f9f9f9; font-weight: normal; color: #666; border-top: 1px solid #e0e0e0; border-bottom: 1px solid #e0e0e0; padding: 4px 0; font-size: 11px;}
.header-item, .post-cell {padding: 6px 4px; text-align: center; box-sizing: border-box; overflow: hidden; white-space: nowrap; text-overflow: ellipsis; line-height: 1.4;}
.col-num {flex-basis: 50px; flex-shrink: 0; font-size: 11px; color: #666;}
.col-title {flex-grow: 1; text-align: left; overflow: hidden; white-space: nowrap; text-overflow: ellipsis;}
.col-writer {flex-basis: 120px; flex-shrink: 0;}
.col-date {flex-basis: 60px; flex-shrink: 0;}
.col-view {flex-basis: 40px; flex-shrink: 0;}
.col-recommend {flex-basis: 40px; flex-shrink: 0;}
.col-title .post-title-label {color: #333; text-decoration: none; cursor: pointer; display: block; padding: 0; font-size: 12px; position: relative;}
.col-title .post-title-label:hover {text-decoration: none;}
.col-title .post-title-label > span {display: inline;}
.comment-count {color: #007bff; font-size: 10px; font-weight: bold; margin-left: 4px; vertical-align: middle;}
.post-toggle {position: absolute; opacity: 0; pointer-events: none; width: 0; height: 0;}
.col-writer {color: #333; font-size: 12px;}
.writer-ip {color: #888; font-size: 10px; margin-left: 3px; vertical-align: middle;}
.col-date, .col-view, .col-recommend {color: #777; font-size: 11px;}
.post-item {border-bottom: 1px solid #f0f0f0;}
.post-item:last-child {border-bottom: none;}
.post-item:hover .post-row {background-color: #f9f9f9;}
.post-content-wrapper {display: none; padding: 20px 15px; margin: 0; background-color: #fff; border-top: 1px solid #eee;}
.post-toggle:checked ~ .post-content-wrapper {display: block;}
.post-full-content span {display: block; line-height: 1.7; font-size: 13px; color: #333; font-weight: normal; white-space: pre-wrap; word-wrap: break-word; min-height: 80px; padding-bottom: 20px;}
.comments-section {border-top: 1px solid #eee; padding-top: 10px; padding-bottom: 10px;}
.comments-section h4 {font-size: 13px; color: #333; margin: 0 0 10px 0; padding-bottom: 0; border-bottom: none; font-weight: bold;}
.comment-list {list-style: none; padding: 0; margin: 0;}
.comment-item {padding: 4px 0; border-top: 1px dotted #e5e5e5; display: flex; align-items: baseline; line-height: 1.5;}
.comment-item:first-child {border-top: none;}
.comment-author-wrapper {flex-shrink: 0; min-width: 90px; padding-right: 8px;}
.comment-author {color: #333; font-weight: bold; font-size: 12px; white-space: nowrap; display: inline-flex; align-items: baseline; text-shadow: none;}
.comment-author .writer-ip {font-weight: normal; color: #888; font-size: 10px; margin-left: 3px;}
.col-writer h1, .col-writer h2, .comment-author h1, .comment-author h2 {display: inline; font-size: inherit; font-weight: inherit; color: inherit; margin: 0; padding: 0; line-height: inherit; vertical-align: baseline;}
.col-writer h1::after, .comment-author h1::after {content: "고"; font-size: 9px; font-weight: bold; border: 1px solid orange; color: orange; border-radius: 2px; padding: 0 2px; margin-left: 4px; display: inline-block; line-height: 1; vertical-align: baseline;}
.col-writer h2::after, .comment-author h2::after {content: "반"; font-size: 9px; font-weight: bold; border: 1px solid green; color: green; border-radius: 2px; padding: 0 2px; margin-left: 4px; display: inline-block; line-height: 1; vertical-align: baseline;}
.comment-content-wrapper {flex-grow: 1; padding-left: 5px;}
.comment-text {word-wrap: break-word; white-space: pre-wrap; text-shadow: none; font-family: 'Malgun Gothic','맑은 고딕',dotum,'돋움',sans-serif; font-size: 13px; color: #333; font-weight: normal;}
.post-list-body div[style*='text-align: center'] {color: #666;}
.post-full-content span img {max-width: 100%; height: auto; display: block; margin-top: 5px; margin-bottom: 5px; border: 1px solid #eee;}
@media (prefers-color-scheme: dark) {body {color: #e0e0e0; background-color: #1e1e1e;} .gallery-container {background-color: #1e1e1e; border: 1px solid #444;} .gallery-header {border-bottom-color: #5c6bc0;} .gallery-header h1 {color: #5c6bc0;} .gallery-top-links a {color: #aaa;} .gallery-top-links a:hover {color: #ccc;} .gallery-options {border-bottom-color: #555;} .tab-button {color: #aaa;} .tab-button.active {color: #5c6bc0; border-bottom-color: #5c6bc0;} .gallery-actions select {border-color: #555; background-color: #444; color: #e0e0e0;} .write-button {border-color: #666; background-color: #444; color: #e0e0e0;} .write-button:hover {background-color: #555;} .write-button i {color: #5c6bc0;} .post-list-container {border-top-color: #5c6bc0; border-bottom-color: #555;} .post-list-header, .post-row {border-bottom-color: #484848;} .post-list-header {background-color: #2f2f2f; color: #bbb; border-top-color: #484848; border-bottom-color: #484848;} .col-num {color: #bbb;} .col-title .post-title-label {color: #e0e0e0;} .comment-count {color: #64b5f6;} .col-writer {color: #e0e0e0;} .writer-ip {color: #999;} .col-date, .col-view, .col-recommend {color: #aaa;} .post-item {border-bottom-color: #484848;} .post-item:hover .post-row {background-color: #2f2f2f;} .post-content-wrapper {background-color: #1e1e1e; border-top-color: #4f4f4f;} .post-full-content span {color: #e0e0e0;} .post-full-content span img {border-color: #444;} .comments-section {border-top-color: #4f4f4f;} .comments-section h4 {color: #e0e0e0;} .comment-item {border-top-color: #5a5a5a;} .comment-author {color: #e0e0e0;} .comment-author .writer-ip {color: #999;} .comment-text {color: #e0e0e0;} .post-list-body div[style*='text-align: center'] {color: #aaa;}}
html {height: auto;}
body {font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: rgba(240, 242, 245, 0.63); color: #0f1419; display: flex; flex-direction: column; align-items: center; min-height: 100vh; margin: 0; padding: 0; box-sizing: border-box; font-size: 13px;}
.iphone-frame-container {width: 100%; max-width: 360px; margin: 20px auto; background-color: #000000; height: 720px; max-height: 720px; border: 1px solid #ccc; border-radius: 8px; display: flex; flex-direction: column; overflow: hidden; box-shadow: 0 0 20px rgba(0,0,0,0.15);}
.iphone-screen {background-color: #fff; width: 100%; border-radius: 0; position: relative; display: flex; flex-direction: column; flex-grow: 1; overflow-y: auto; height: 100%;}
.gallery-container {margin: 0; padding: 0; border: none; max-width: 100%; display: flex; flex-direction: column; background-color: #fff; color: #333; width: 100%; flex-shrink: 0; flex-grow: 1;}
.gallery-header {align-items: center; justify-content: space-between; padding: 10px 10px 6px 10px; margin-bottom: 0; position: sticky; top: 0; background-color: #fff; z-index: 100; flex-shrink: 0; border-bottom: 2px solid #3b4890;}
.gallery-header h1 {font-size: 16px; margin-bottom: 0; margin-right: 10px; flex-shrink: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: calc(100% - 70px); color: #3b4890;}
.gallery-top-links {display: none;}
.gallery-header .write-button {display: inline-flex !important; position: static; order: 2; margin-left: 0; padding: 5px 10px; font-size: 12px; flex-shrink: 0; color: #3b4890; border: 1px solid #bbb; background: #fff;}
.gallery-header .write-button i {display: none;}
.gallery-options {margin-bottom: 0; flex-wrap: nowrap; align-items: stretch; padding-bottom: 0; border-bottom: 1px solid #ccc; height: 32px; flex-shrink: 0; display: flex; background-color: #fff; z-index: 90; position: sticky; top: 48px;}
.tab-menu {display: contents;}
.gallery-options > .tab-button, .gallery-options > .gallery-actions {flex: 0 0 25%; display: flex; align-items: center; justify-content: center; border: none; border-right: 1px solid #ccc; padding: 0 5px; margin-right: 0; font-size: 12px; line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; border-bottom: 3px solid transparent; background-color: transparent; color: #777; font-weight: bold; box-sizing: border-box;}
.gallery-options > .tab-button.active {color: #3b4890; border-bottom-color: #3b4890; font-weight: bold;}
.gallery-options > .gallery-actions {border-right: none; padding: 0; order: 0; margin-left: 0;}
.gallery-options select {appearance: none; -webkit-appearance: none; -moz-appearance: none; background-color: transparent; border: none; font-size: 12px; font-weight: bold; color: #777; width: 100%; height: 100%; padding: 0 5px 0 5px; text-align: center; text-align-last: center; cursor: pointer; margin: 0; -moz-text-align-last: center; box-sizing: border-box;}
.gallery-actions .write-button {display: none;}
.post-list-header {display: none;}
.post-list-container {
    border-top: none; 
    padding: 0 5px; 
    border-bottom: none; 
    overflow-y: auto; 
    min-height: 0;
    flex-grow: 1;
    max-height: calc(100vh - 130px);
    height: auto;
    -webkit-overflow-scrolling: touch;
    position: relative;
    z-index: 1;
}
.post-item {border-bottom: 1px solid #f0f0f0;}
.post-item:last-child {border-bottom: none;}
.post-row {padding: 0; flex-wrap: wrap; align-items: flex-start; position: relative; border-bottom: none; min-height: 50px; display: flex; align-items: stretch; padding-right: 45px; padding-bottom: 8px;}
.post-row::after {content: ''; position: absolute; right: 0; top: 0; bottom: 0; width: 45px; background-color: #f0f0f0; border-left: 1px solid #e5e5e5; border-top: 1px solid #e5e5e5; z-index: 0; box-sizing: border-box;}
.post-cell {padding: 0; line-height: 1.5; display: block; width: auto; flex-basis: auto; text-align: left;}
.post-row .col-num {display: none;}
.post-row .col-title {order: 0; flex-grow: 1; flex-basis: 100%; width: 100%; text-align: left; white-space: normal; padding: 8px 5px 2px 8px; margin-bottom: 0; overflow: visible;}
.post-row .col-title .post-title-label {font-size: 14px; line-height: 1.4; display: block; position: static; color: #333;}
.post-row .col-title .post-title-label > span {display: block;}
.post-row .comment-count {position: absolute; right: 0; top: 0; bottom: 0; width: 45px; display: flex !important; align-items: center; justify-content: center; color: #e53935 !important; background: none; font-size: 10px !important; font-weight: normal !important; line-height: 1.4; margin-left: 0; white-space: nowrap; vertical-align: baseline; border-radius: 0; z-index: 1; transform: none; box-sizing: border-box; padding: 0; text-align: center;}
.post-row .col-writer, .post-row .col-date, .post-row .col-view, .post-row .col-recommend {order: 1; display: inline !important; flex-basis: auto; flex-grow: 0; flex-shrink: 0; padding: 0 2px; vertical-align: middle; font-size: 11px; line-height: 1.4; white-space: nowrap;}
.post-row .col-writer {color: #555; padding-left: 8px;}
.post-row .col-date {color: #888;}
.post-row .col-view {color: #888;}
.post-row .col-recommend {color: #888; display: inline !important;}
.post-row .writer-ip {display: none;}
.post-row .col-date::before {content: ' | '; color: #ccc; margin: 0 1px;}
.post-row .col-view::before {content: '| 조회 '; color: #888; font-size: 10px; margin-right: 2px;}
.post-row .col-recommend::before {content: '| 추천 '; color: #888; font-size: 10px; margin-right: 2px;}
.post-content-wrapper {padding: 15px 10px; flex-shrink: 0; border-top: 1px solid #eee; overflow-y: auto; background-color: #fff;}
.post-full-content span {font-size: 14px; min-height: 60px; padding-bottom: 15px;}
.post-full-content span img {max-width: 100%; height: auto; display: block; margin-top: 5px; margin-bottom: 5px; border: 1px solid #ddd;}
.comments-section {padding: 10px 0 5px 10px; border-top: 1px solid #eee; background-color: #fff;}
.comments-section h4 {font-size: 12px; margin-bottom: 8px; color: #333;}
.comment-list {padding-left: 0; list-style: none; margin:0; max-height: 400px; overflow-y: auto;}
.comment-item {padding: 5px 0; flex-wrap: wrap; align-items: flex-start; border-top: 1px dotted #e5e5e5; display: flex; line-height: 1.5;}
.comment-item:first-child {border-top: none;}
.comment-author-wrapper {min-width: 0; padding-right: 6px; flex-basis: 100%; margin-bottom: 2px; flex-shrink: 0;}
.comment-author {font-size: 12px; color: #333; font-weight: bold; white-space: nowrap; display: inline-flex; align-items: baseline; text-shadow: none;}
.comment-author .writer-ip {font-size: 10px; color: #888; font-weight: normal; margin-left: 3px;}
.comment-content-wrapper {flex-basis: 100%; padding-left: 0; flex-grow: 1;}
.comment-text {font-size: 13px; line-height: 1.6; color: #333; word-wrap: break-word; white-space: pre-wrap; text-shadow: none; font-family: 'Malgun Gothic','맑은 고딕',dotum,'돋움',sans-serif; font-weight: normal;}
@media (prefers-color-scheme: dark) {body {background-color: #1e1e1e; color: #e0e0e0;} .iphone-frame-container {background-color: #000; border-color: #555;} .iphone-screen {background-color: #1e1e1e;} .gallery-container {background-color: #1e1e1e; color: #e0e0e0;} .gallery-header {border-bottom-color: #5c6bc0; background-color: #1e1e1e;} .gallery-header h1 {color: #5c6bc0;} .gallery-header .write-button {background-color: #444; color: #5c6bc0; border-color: #666; display: inline-flex !important;} .gallery-options {border-bottom-color: #555; background-color: #1e1e1e;} .gallery-options > .tab-button, .gallery-options select {color: #aaa; border-right-color: #555;} .gallery-options > .gallery-actions {border-right: none;} .gallery-options > .tab-button.active {color: #5c6bc0; border-bottom-color: #5c6bc0;} .gallery-options select {color: #aaa; background-color: transparent;} .post-item {border-bottom-color: #484848;} .post-row .col-title .post-title-label {color: #e0e0e0;} .post-row::after {background-color: #2a2a2a; border-left-color: #444; border-top-color: #444;} .post-row .comment-count {color: #ff7a75 !important;} .post-row .col-writer {color: #bbb;} .post-row .col-date, .post-row .col-view, .post-row .col-recommend {color: #999;} .post-row .col-date::before, .post-row .col-view::before, .post-row .col-recommend::before {color: #666;} .post-row .col-view::before {color: #999;} .post-row .col-recommend::before {color: #999;} .post-content-wrapper {border-top-color: #4f4f4f; background-color: #1e1e1e;} .post-full-content span {color: #e0e0e0;} .post-full-content span img {border-color: #4f4f4f;} .comments-section {border-top-color: #4f4f4f; padding: 10px 0 5px 10px; background-color: #1e1e1e;} .comments-section h4 {color: #e0e0e0;} .comment-item {border-top-color: #5a5a5a;} .comment-author {color: #e0e0e0;} .comment-author .writer-ip {color: #999;} .comment-text {color: #e0e0e0;}}
</style>
]]
        
        local galleryName = "갤러리"
        local posts = {}
        local currentPost = nil
        local bodyBuffer = nil
        local keyLookaheadPattern = "^([A-Za-z]+):"
        local keyPattern = "^([A-Za-z]+):(.+)$"

        local segments = {}
        for seg in string.gmatch(replacements, "([^|]+)") do
            table.insert(segments, seg)
        end

        local i = 1
        while i <= #segments do
            local segment_raw = segments[i]
            local segment = segment_raw:match("%s*(.-)%s*$")
            local advanced_loop = false 

            if bodyBuffer then
                local is_new_key = segment:match(keyLookaheadPattern)
                if is_new_key then
                    if currentPost then
                        currentPost.contentRaw = table.concat(bodyBuffer, "|")
                    end
                    bodyBuffer = nil 
                else
                    table.insert(bodyBuffer, segment_raw)
                    i = i + 1
                    advanced_loop = true
                end
            end

            if not advanced_loop then
                local key, value = segment:match(keyPattern)

                if key then
                    value = value:match("%s*(.-)%s*$")

                    if key == "GN" then
                        galleryName = escapeHtml(value)
                    elseif key == "PID" then
                        currentPost = {
                            id = escapeHtml(value), comments = {},
                            number = "N/A", title = "N/A", commentCountRaw = "0", authorRaw = "ㅇㅇ",
                            time = "N/A", views = "0", recommend = "0", contentRaw = "", authorParsed = parseAuthor("ㅇㅇ")
                        }
                        table.insert(posts, currentPost)
                    elseif currentPost then
                        if key == "PN" then currentPost.number = escapeHtml(value)
                        elseif key == "PT" then currentPost.title = escapeHtml(value)
                        elseif key == "PC" then 
                            local count = tonumber(value) or 0
                            currentPost.commentCountRaw = tostring(count)
                        elseif key == "PW" then
                            currentPost.authorRaw = value
                            currentPost.authorParsed = parseAuthor(value)
                        elseif key == "PD" then currentPost.time = escapeHtml(value)
                        elseif key == "PV" then currentPost.views = escapeHtml(value)
                        elseif key == "PR" then currentPost.recommend = escapeHtml(value)
                        elseif key == "BODY" then
                            bodyBuffer = { value }
                        elseif key == "COMMENT" then
                            local commentAuthor = value
                            local commentContent = nil
                            local consumed_comment_segments = 1 

                            if i + 1 <= #segments then
                                local next_segment = segments[i+1]:match("%s*(.-)%s*$")
                                if not next_segment:match(keyLookaheadPattern) then
                                    commentContent = next_segment
                                    consumed_comment_segments = consumed_comment_segments + 1
                                    table.insert(currentPost.comments, {
                                        authorRaw = commentAuthor, authorParsed = parseAuthor(commentAuthor), textRaw = commentContent
                                    })

                                    local current_comment_idx = i + 2
                                    while current_comment_idx + 1 <= #segments do
                                        local author_seg = segments[current_comment_idx]
                                        local content_seg = segments[current_comment_idx + 1]
                                        if author_seg:match(keyLookaheadPattern) or content_seg:match(keyLookaheadPattern) then
                                            break 
                                        end
                                        commentAuthor = author_seg:match("%s*(.-)%s*$")
                                        commentContent = content_seg:match("%s*(.-)%s*$")
                                        table.insert(currentPost.comments, {
                                            authorRaw = commentAuthor, authorParsed = parseAuthor(commentAuthor), textRaw = commentContent
                                        })
                                        consumed_comment_segments = consumed_comment_segments + 2 
                                        current_comment_idx = current_comment_idx + 2
                                    end
                                else
                                end
                            else
                            end
                            i = i + consumed_comment_segments -1 
                        else
                        end
                    else
                    end
                    i = i + 1 
                    advanced_loop = true
                else
                    if currentPost then
                    end
                    i = i + 1 
                    advanced_loop = true
                end
            end 
            if not advanced_loop then
                i = i + 1
            end
        end 

        if bodyBuffer and currentPost then
        currentPost.contentRaw = table.concat(bodyBuffer, "|")
        end

        local html = {}
        table.insert(html, DCInsideTemplate)
        table.insert(html, "<div class=\"iphone-frame-container\"><div class=\"iphone-screen\"><div class=\"gallery-container\">")
        table.insert(html, "<div class=\"gallery-header\"><h1>" .. galleryName .. "</h1><div class=\"gallery-top-links\"><a>갤러리 정보</a><a>|</a><a>설정</a><a>|</a><a>연관 갤러리</a><a>|</a><a>갤주소 복사</a><a>|</a><a>이용안내</a><a>|</a><a>새로고침</a></div><a class=\"write-button\">글쓰기</a></div>")
        table.insert(html, "<div class=\"gallery-options\"><div class=\"tab-menu\"><button class=\"tab-button active\">전체</button><button class=\"tab-button\">개념글</button><button class=\"tab-button\">공지</button></div><div class=\"gallery-actions\"><select name=\"viewCount\"><option value=\"50\">50개</option><option value=\"100\">100개</option></select><a class=\"write-button\">글쓰기</a></div></div>")
        table.insert(html, "<div class=\"post-list-container\">")
        table.insert(html, "<div class=\"post-list-header\"><div class=\"header-item col-num\">번호</div><div class=\"header-item col-title\">제목</div><div class=\"header-item col-writer\">글쓴이</div><div class=\"header-item col-date\">작성일</div><div class=\"header-item col-view\">조회</div><div class=\"header-item col-recommend\">추천</div></div>")
        table.insert(html, "<div class=\"post-list-body\">")

        if #posts > 0 then
            for post_idx, post_data in ipairs(posts) do
                if post_data and post_data.id then
                    local postId = post_data.id
                    local postNumber = post_data.number or "N/A"
                    local postTitle = post_data.title or "N/A"
                    local postTime = post_data.time or "N/A"
                    local postViews = post_data.views or "0"
                    local postRecommend = post_data.recommend or "0"
                    local postWriterHtml = (post_data.authorParsed and post_data.authorParsed.html) or "ㅇㅇ"

                    local rawPostContent = post_data.contentRaw or ""
                    local postContentDisplayHtml = ""
                    local last_end = 1
                    rawPostContent = string.gsub(rawPostContent, "<!%-%-.-%-%->", "")
                    local om_pattern = "(<OM%d+>)"
                    local inlayIndex = 0

                    while true do
                        local omStart, omEnd, omTag = string.find(rawPostContent, om_pattern, last_end)
                        if not omStart then
                            break
                        end
                        
                        inlayIndex = string.match(omTag, "<OM(%d+)>")
                        if not inlayIndex then
                            print("ONLINEMODULE: No valid index found in OM tag:", omTag)
                        end

                        local text_part = string.sub(rawPostContent, last_end, omStart - 1)
                        local processed_text = escapeHtml(text_part)
                        processed_text = string.gsub(processed_text, "\n", "<br>")
                        processed_text = string.gsub(processed_text, "\r", "")
                        postContentDisplayHtml = postContentDisplayHtml .. processed_text .. omTag

                        last_end = omEnd + 1
                    end

                    local remaining_text = string.sub(rawPostContent, last_end)
                    local processed_remaining_text = ""
                    local last_pos = 1

                    -- 인레이 태그 체크
                    while true do
                        local s, e = string.find(remaining_text, "{{inlay::[^}]+}}", last_pos)
                        if not s then
                            -- 일반 텍스트 처리
                            local text_part = string.sub(remaining_text, last_pos)
                            if text_part ~= "" then
                                local processed_part = escapeHtml(text_part)
                                processed_part = string.gsub(processed_part, "\n", "<br>")
                                processed_part = string.gsub(processed_part, "\r", "")
                                processed_remaining_text = processed_remaining_text .. processed_part
                            end
                            break
                        end
                        -- 텍스트 처리
                        local text_before = string.sub(remaining_text, last_pos, s - 1)
                        if text_before ~= "" then
                            local processed_part = escapeHtml(text_before)
                            processed_part = string.gsub(processed_part, "\n", "<br>")
                            processed_part = string.gsub(processed_part, "\r", "")
                            processed_remaining_text = processed_remaining_text .. processed_part
                        end

                        -- 인레이 태그 처리
                        local inlay_tag = string.sub(remaining_text, s, e)
                        processed_remaining_text = processed_remaining_text .. inlay_tag

                        last_pos = e + 1
                    end

                    postContentDisplayHtml = postContentDisplayHtml .. processed_remaining_text
                    if rawPostContent == "" then postContentDisplayHtml = "" end

                    local commentCount = tonumber(post_data.commentCountRaw) or 0

                    table.insert(html, "<div class=\"post-item\">")
                    table.insert(html, "<input type=\"checkbox\" id=\"" .. postId .. "\" class=\"post-toggle\">")

                    table.insert(html, "<div class=\"post-row\">")
                    table.insert(html, "  <div class=\"post-cell col-num\">" .. postNumber .. "</div>")
                    table.insert(html, "  <div class=\"post-cell col-title\">")
                    table.insert(html, "    <label for=\"" .. postId .. "\" class=\"post-title-label\">")
                    table.insert(html, "      <span class=\"title-text\">" .. postTitle .. "</span>")
                    if commentCount > 0 then
                        table.insert(html, "      <span class=\"comment-count\">" .. commentCount .. "</span>")
                    end
                    table.insert(html, "    </label>")
                    table.insert(html, "  </div>")
                    table.insert(html, "  <div class=\"post-cell col-writer\">" .. postWriterHtml .. "</div>")
                    table.insert(html, "  <div class=\"post-cell col-date\">" .. postTime .. "</div>")
                    table.insert(html, "  <div class=\"post-cell col-view\">" .. postViews .. "</div>")
                    table.insert(html, "  <div class=\"post-cell col-recommend\">" .. postRecommend .. "</div>")
                    table.insert(html, "</div>")

                    table.insert(html, "<div class=\"post-content-wrapper\">")
                    table.insert(html, "  <div class=\"post-full-content\"><span>" .. postContentDisplayHtml .. "</span></div>")

      
                    if commentCount > 0 then
                        table.insert(html, "  <div class=\"comments-section\">")
                        table.insert(html, "    <h4>댓글 " .. commentCount .. "</h4>")
                        table.insert(html, "    <ul class=\"comment-list\">")
                        for c_idx, comment_data in ipairs(post_data.comments) do
                            local commentAuthorHtml = (comment_data.authorParsed and comment_data.authorParsed.html) or "ㅇㅇ"
                            local commentTextHtml = escapeHtml(comment_data.textRaw or "")
                            commentTextHtml = string.gsub(commentTextHtml, "\n", "<br>")
                            commentTextHtml = string.gsub(commentTextHtml, "\r", "")
                            if commentTextHtml == "" then commentTextHtml = "(내용 없음)" end

                            table.insert(html, "      <li class=\"comment-item\">")
                            table.insert(html, "        <div class=\"comment-author-wrapper\"><span class=\"comment-author\">" .. commentAuthorHtml .. "</span></div>")
                            table.insert(html, "        <div class=\"comment-content-wrapper\"><span class=\"comment-text\">" .. commentTextHtml .. "</span></div>")
                            table.insert(html, "      </li>")
                        end
                        table.insert(html, "    </ul>")

                        local buttonJsonBody = '{"action":"DC_REROLL", "identifier":"' .. (postId or "") .. '", "index":"' .. inlayIndex .. '"}'
                        table.insert(html, "<div class=\"reroll-button-wrapper\">")
                        table.insert(html, "<div class=\"global-reroll-controls\">")
                        table.insert(html, "<button style=\"text-align: center;\" class=\"reroll-button\" risu-btn='" .. buttonJsonBody .. "'>POST</button>")
                        table.insert(html, "</div></div>")

                        table.insert(html, "  </div>")
                    end

                    table.insert(html, "</div>")
                    table.insert(html, "</div>")
                else print("Skipping post rendering because post_data or post_data.id is nil for index " .. post_idx) end
            end
        else
            table.insert(html, "<div style='padding: 20px; text-align: center; color: #666;'>표시할 게시글 없음</div>")
        end
        table.insert(html, "</div></div></div></div></div><br>")

        return table.concat(html)
    end)
    return data
end


local function inputKAKAOTalk(triggerId, data)
    local OMMESSENGERNOIMAGE = getGlobalVar(triggerId, "toggle_OMMESSENGERNOIMAGE") or "0"

    data = data .. [[
## Messenger Interface

### KakaoTalk Interface Template
- KAKAO[(Message)|(Message Timeline)]
- Message: {{char}}'s KAKAOTALK Message.
    - NO '[', '|', ']' ALLOWED at HERE!!!
]]

    if OMMESSENGERNOIMAGE == "0" then
        data = data .. [[
	- When {{char}} sends a picture or photo, exactly output '<OM>'.
        - ONLY when {{char}} sends a picture or photo.
        - if not, DO NOT PRINT <OM>.
    - DO NOT PRINT <OM> with message, and more than once.
]]
    end

    data = data .. [[
    - ALWAYS PRINT WITH SHORTENED MESSAGE.
    - NEVER INCLUDE {{user}}'s MESSAGE in RESPONSE.
- TIME: KAKAOTALK Message sent timeline with hh:mm AP/PM.

- Example:
    - KAKAO[What's the matter, {{user}}?|01:45 AM]
    - KAKAO[You must be very bored.|01:45 AM]
    - KAKAO[Would you like to chat with me for a bit? Hehe|01:46 AM]
]]

    if OMMESSENGERNOIMAGE == "0" then
        data = data .. [[
	- KAKAO[<OM>|01:46 AM]        
]]
    end

    return data
end

local function changeKAKAOTalk(triggerId, data)
    local OMMESSENGERNOIMAGE = getGlobalVar(triggerId, "toggle_OMMESSENGERNOIMAGE") or "0"
    data = string.gsub(data, "TALK%[(.-)|(.-)%]", function(message, timestamp)
        local userMessageTemplate = [[
<style>
.kakao-user-message-container {display: flex;justify-content: flex-end;margin-bottom: 8px;padding-right: 10px;}
.kakao-user-message-inner {display: flex;align-items: flex-end;max-width: 75%;}
.kakao-user-timestamp {color: #8b8b8b;font-size: 0.7em;margin-right: 6px;white-space: nowrap;flex-shrink: 0;padding-bottom: 2px;}
.kakao-user-message-bubble {background-color: #FEE500;color: #3C1E1E;padding: 8px 12px;border-radius: 12px;position: relative;box-shadow: 0 1px 1px rgba(0,0,0,0.05);margin-right: 6px;}
.kakao-user-message-bubble::after {content: "";position: absolute;right: -6px;top: 6px;width: 0;height: 0;border-style: solid;border-width: 5px 0 5px 7px;border-color: transparent transparent transparent #FEE500;}
.kakao-user-message-text {font-size: 1.05em;line-height: 1.4;white-space: pre-wrap;word-wrap: break-word;overflow-wrap: break-word;}
body {font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, "Open Sans", "Helvetica Neue", sans-serif;}
</style>
]]      
        local html = {}

        table.insert(html, userMessageTemplate)
        table.insert(html, "<div class='kakao-user-message-container'>")
        table.insert(html, "<div class='kakao-user-message-inner'>")
        table.insert(html, "<div class='kakao-user-timestamp'>" .. timestamp .. "</div>")
        table.insert(html, "<div class='kakao-user-message-bubble'>")
        table.insert(html, "<div class='kakao-user-message-text'>")
        table.insert(html, message)
        table.insert(html, "</div></div></div></div>") 

        return table.concat(html)

    end)


    data = string.gsub(data, "KAKAO%[(.-)|(.-)%]", function(message, timestamp)
        local imageCounter = 0
        local charMessageTemplate = [[
<style>
.message-group { display: flex; align-items: flex-start; margin-bottom: 10px; position: relative; color: black; }
.profile-column { margin-right: 12px; margin-top: 5px; margin-left: 0; flex-shrink: 0; }
.profile-image { border-radius: 50%; object-fit: cover; width: 42px; height: 42px; }
.content-column { flex-grow: 1; }
.username { margin-bottom: 6px; margin-top: 6px; color: black; font-size: 1.0em; }
.message-bubble-container { display: inline-flex; align-items: flex-end; }
.message-bubble { background-color: white; padding: 10px; box-sizing: border-box; position: relative; display: inline-block; font-size: 1.1em; border-radius: 11px; }
.message-bubble::before { content: ""; position: absolute; border-style: solid; top: 5px; left: -10px; border-width: 0px 20px 10px 3px; border-color: transparent white transparent transparent; }
.message-text-label { display: block; white-space: pre-wrap; word-wrap: break-word; overflow-wrap: break-word; }
.timestamp { color: #888; white-space: nowrap; margin-left: 10px; padding-bottom: 2px; flex-shrink: 0; font-size: 0.7em; }
.fullscreen-toggle { display: none; }
.clickable-image-label { cursor: pointer; }
.fullscreen-overlay { display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background-color: rgba(0,0,0,0.85); z-index: 10000; align-items: center; justify-content: center; padding: 20px; box-sizing: border-box; }
.fullscreen-overlay > * { max-width: 95%; max-height: 95%; }
.fullscreen-close-label { position: absolute; top: 0; left: 0; right: 0; bottom: 0; cursor: pointer; z-index: 1; }
.fullscreen-toggle:checked ~ .fullscreen-overlay { display: flex; }
</style>
]]


    local uniqueId = ""

    local html = {}
    
    table.insert(html, charMessageTemplate)
    table.insert(html, '<div class="message-group">')

    table.insert(html, '<div class="profile-column">')
    table.insert(html, '<img src="{{source::char}}" alt="Profile" class="profile-image">')
    table.insert(html, '</div>')
    
    table.insert(html, '<div class="content-column">')
    table.insert(html, '<div class="username">{{char}}</div>')
    table.insert(html, '<div class="message-bubble-container">')
    table.insert(html, '<div class="message-bubble">')
    table.insert(html, '<label class="message-text-label">')
    table.insert(html, message)
    table.insert(html, '</label>')
    table.insert(html, '</div>')
    table.insert(html, '<div class="timestamp">' .. timestamp .. '</div>')
    table.insert(html, '</div>')
    table.insert(html, '</div>')
    table.insert(html, '</div>')

    -- inlay::가 존재할 경우
    local inlayTag = string.match(message, "{{inlay::[^}]+}}")
    if inlayTag and OMMESSENGERNOIMAGE == "0" then
        local buttonJsonBody = '{"action":"KAKAO_REROLL", "identifier":"KAKAO_' .. timestamp .. '", "index":"' .. 0 .. '"}'
        table.insert(html, '<div class="reroll-button-wrapper" style="margin-top: 10px; z-index: 2;">')
        table.insert(html, '<div class="global-reroll-controls">')
        table.insert(html, '<button style="text-align: center;" class="reroll-button" risu-btn=\'' .. buttonJsonBody .. '\'>KAKAO</button>')
        table.insert(html, '</div></div>')
    end

    return table.concat(html)

    end)
    
    return data
end

local function inputImage(triggerId, data)
    local OMNSFW = getGlobalVar(triggerId, "toggle_OMNSFW") or "0"
    local OMCARD = getGlobalVar(triggerId, "toggle_OMCARD") or "0"
    local OMCARDNOIMAGE = getGlobalVar(triggerId, "toggle_OMCARDNOIMAGE") or "0"
    local OMCARDTARGET = getGlobalVar(triggerId, "toggle_OMCARDTARGET") or "0"

    local OMSNS = getGlobalVar(triggerId, "toggle_OMSNS") or "0"
    local OMSNSNOIMAGE = getGlobalVar(triggerId, "toggle_OMSNSNOIMAGE") or "0"
    local OMSNSTARGET = getGlobalVar(triggerId, "toggle_OMSNSTARGET") or "0"
    local OMSNSREAL = getGlobalVar(triggerId, "toggle_OMSNSREAL") or "0"

    local OMCOMMUNITY = getGlobalVar(triggerId, "toggle_OMCOMMUNITY") or "0"
    local OMCOMMUNITYNOIMAGE = getGlobalVar(triggerId, "toggle_OMCOMMUNITYNOIMAGE") or "0"

    local OMMESSENGER = getGlobalVar(triggerId, "toggle_OMMESSENGER") or "0"
    local OMMESSENGERNOIMAGE = getGlobalVar(triggerId, "toggle_OMMESSENGERNOIMAGE") or "0"

    local OMCOMPATIBILITY = getGlobalVar(triggerId, "toggle_OMCOMPATIBILITY") or "0"
    local OMORIGINAL = getGlobalVar(triggerId, "toggle_OMORIGINAL") or "0"
    local OMORIGINALTEXT = getGlobalVar(triggerId, "toggle_OMORIGINALTEXT") or "0"
    
    
    data = data .. [[
## Image Prompt
- This prompt must describe situations, settings, and actions related to the Character in vivid and detailed language.

### Image Prompt: Extraction
- From the narrative, extract details to construct a comprehensive Prompt.

### Image Prompt: Placeholder
- Focus on the situation the Character is in.
- The Image Prompt must be written in English and be detailed and descriptive.
- REPLACE the PLACEHOLDER in the PROMPT:
	- PLACEHOLDER:
		- (SITUATION):
			- Normal situation: Do not print anything.
			- NSFW SITUATION:
				- Bodypart not exposed: Print do not print anything.
				- Breasts or nipples exposed: Print '{NSFW,UNCENSORED}'
				- Pussy exposed: Print '{{{NSFW,UNCENSORED}}}'
		- (LABEL):
			- ONLY 1 LETTERacter.
			- Example:
				- If Character is a male: 
					- PROMPT: "1boy"
					- NEGATIVE PROMPT: "1girl, female"
				- If Character is a female:
					- PROMPT: "1girl"
					- NEGATIVE PROMPT: "1boy, male"
		- (EXPRESSIONS): Describe Character's facial expressions and emotions.
		- (ACTIONS): Detail Character's behaviors and movements.
		- (AGE): Describe Character's age in 10s. (e.g., '20s years old')
		- (APPEARANCE): Describe Character's observable features with {{ and }}. (e.g., '{{pink short hair, high twin-tail}}')
		- (BODY): Describe Character's physique, output with {{{ and }}}. (e.g., '{{Slender, AA-Cup small breasts, small nipples}}')
			- BODY shape: slender, petite, loli, glamour, ... etc.
			- Breast size: A-Cup small breasts, H-Cup large Breasts, ... etc.
			- If Character is under NSFW situation:
				- Breasts exposed:
					- Areola size: small areola, ... etc.
					- Nipple size: small nipples, ... etc.
				- Pussy exposed
					- Shape of pussy: innie pussy, ... etc.
					- Pussy hair: Baldie, heart-shaped pubic hair, ... 
		- (DRESSES): 
			- Outline Character's outfit (type, materials, textures, colors, accessories).
			- Do not describe under the thighs.
		- (PLACE): Describe Character's current location, mood setting.
		- (SCENE): Summarize Character's current narrative scene into a concise description.
		- (PROMPTPLACEHOLDER):    
]]
    if OMCARD == "1" then
        data = data .. [[
			- OMSTATUSPROMPT + INDEX
			- NEG_OMSTATUSPROMPT + INDEX
]]
    elseif OMCARD == "2" then
        data = data .. [[
			- OMSIMULCARDPROMPT + INDEX
			- NEG_OMSIMULCARDPROMPT + INDEX
]] 
    elseif OMCARD == "3" then
        data = data .. [[
            - For female:
                - OMSTATUSPROMPT + INDEX
                - NEG_OMSTATUSPROMPT + INDEX
            - For male:
                - OMSIMULCARDPROMPT + INDEX
                - NEG_OMSIMULCARDPROMPT + INDEX
]]
    elseif OMCARD == "4" then
        data = data .. [[
            - OMINLAYPROMPT + INDEX
            - NEG_OMINLAYPROMPT + INDEX
]]
    end

    if OMSNS == "1" then
        data = data .. [[
			- OMTWITTERPROMPT
			- NEG_OMTWITTERPROMPT
]]
    elseif OMSNS == "2" then
        data = data .. [[
            - OMINSTAPROMPT
            - NEG_OMINSTAPROMPT
]]
    elseif OMSNS == "3" then
        data = data .. [[
            - For NSFW Post:
                - OMTWITTERPROMPT
                - NEG_OMTWITTERPROMPT
            - For SFW Post:
                - OMINSTAPROMPT
                - NEG_OMINSTAPROMPT
]]
    end

    if OMCOMMUNITY == "1" then
        data = data .. [[
			- OMDCPROMPT + INDEX
			- NEG_OMDCPROMPT + INDEX
]]
    end

    if OMMESSENGER == "1" then
        data = data .. [[
			- OMKAKAOPROMPT
			- NEG_OMKAKAOPROMPT
]]
    end

    if OMCARD == "4" then
        data = data .. [[
### Image Prompt: Tags

#### Image Prompt: Character Tag
- Use the character sheet to set the physical attributes of the featured character in this scene.
    - Character1: {{user}}
    - Character2: Opponent character
- Example:
    - If the {{user}} is a male, and has a black short hairstyle, tall body, wearing a black suit:
        - ::Character1: male, black short hair, tall, black suit::
    - If the Opponent character is a female, and has long twin-tail hairstyle, slender body, small breasts:
        - ::Character2: female, long twin-tail, slender, small breasts::

### Image Prompt: Action Tag
- (ACTION TAG) is used as source#, target#, and mutual#.
    - source#: Used when specifying a character performing a particular action.
    - target#: Used when specifying a character receiving a particular action.
    - mutual#: Used when two characters are performing the same action.
    - Example:
        - If the Character is in a situation where they are being kissed by someone else:
            - source#kissed,target#kissing,mutual#standing
        - If the Character is in a situation where they are kissing someone else:
            - source#kissing,target#kissed,mutual#standing
        - If the Character is in a situation where they are kissing each other:
            - source#kissing,target#kissing,mutual#mouth to mouth,standing
]]
    end


    data = data .. [[
### Image Prompt: Negative Template
- Write up to 30 keywords that should be avoided by Image as a negative prompt.
- You must print out carefully to increase the accuracy rate of the prompts.
- EXAMPLE: If the Character's hairstyle is long twin-tail.
	- Negative: 'ponytail, short hair, medium hair'
- Example:
	- [NEG_PROMPTPLACEHOLDER: 1girl,female,...]

### Image Prompt: Usage
- DO NOT INCLUDE '(''PLACEHOLDER'')' when REPLACING
    - Invalid: ... ,(SCENE:Yellow reacts with surprise and a slight blush to {{user}}'s offer to travel together.), ...
    - Valid: ... ,Yellow reacts with surprise and a slight blush to {{user}}'s offer to travel together, ...
- NEVER refer to the past chat history when outputting the prompt below:
]]

    if OMCARDNOIMAGE == "0" then
        if OMCARD == "1" then
            data = data .. [[
    - ALWAYS PRINT OUT EROTIC STATUS INTERFACE PROMPT and NEGATIVE PROMPT at the BELOW of the EROTIC STATUS INTERFACE
    - Output Format:
        - EROSTATUS[...|INLAY:<OM1>]
        - [OMSTATUSPROMPT1:(SITUATION),(LABEL),cowboy shot,(ACTIONS),(EXPRESSIONS),(AGE),(APPEARANCE),(BODY),(DRESSES),(PLACE),(SCENE)]
        - [NEG_OMSTATUSPROMPT1:(NEGATIVE PROMPT)]
        - EROSTATUS[...|INLAY:<OM2>]
        - [OMSTATUSPROMPT2:(SITUATION),(LABEL),cowboy shot,(ACTIONS),(EXPRESSIONS),(AGE),(APPEARANCE),(BODY),(DRESSES),(PLACE),(SCENE)]
        - [NEG_OMSTATUSPROMPT2:(NEGATIVE PROMPT)]
        - ..., etc.
]]
        elseif OMCARD == "2" then
            data = data .. [[
    - ALWAYS PRINT OUT SIMULATION STATUS INTERFACE PROMPT and NEGATIVE PROMPT at the BELOW of the SIMULATION STATUS INTERFACE
    - Output Format:
        - SIMULSTATUS[...|INLAY:<OM1>]
        - [OMSIMULCARDPROMPT1:(SITUATION),solo,(LABEL),(AGE),(APPEARANCE),(BODY),(DRESSES),{{{detailed face,cowboy shot,white background,simple background}}}]
        - [NEG_OMSIMULCARDPROMPT1:(NEGATIVE PROMPT)]
        - SIMULSTATUS[...|INLAY:<OM2>]
        - [OMSIMULCARDPROMPT2:(SITUATION),solo,(LABEL),(AGE),(APPEARANCE),(BODY),(DRESSES),{{{detailed face,cowboy shot,white background,simple background}}}]
        - [NEG_OMSIMULCARDPROMPT2:(NEGATIVE PROMPT)]
        - ..., etc.
]]
        elseif OMCARD == "3" then
            data = data .. [[
    - ALWAYS PRINT OUT EROTIC STATUS INTERFACE PROMPT for FEMALE, SIMULATION STATUS INTERFACE PROMPT for MALE and NEGATIVE PROMPT at the BELOW of the SIMULATION STATUS INTERFACE
    - Output Format:
        - EROSTATUS[...|INLAY:<OM1>]  --> FEMALE
        - [OMSTATUSPROMPT1:(SITUATION),solo,(LABEL),(AGE),(APPEARANCE),(BODY),(DRESSES),{{{detailed face,cowboy shot,white background,simple background}}}]
        - [NEG_OMSTATUSPROMPT1:(NEGATIVE PROMPT)]
        - SIMULSTATUS[...|INLAY:<OM2>]  --> MALE
        - [OMSIMULCARDPROMPT2:(SITUATION),solo,(LABEL),(AGE),(APPEARANCE),(BODY),(DRESSES),{{{detailed face,cowboy shot,white background,simple background}}}]
        - [NEG_OMSIMULCARDPROMPT2:(NEGATIVE PROMPT)]
        - ..., etc.
]] 
        elseif OMCARD == "4" then
            data = data .. [[
    - ALWAYS PRINT OUT INLAY INTERFACE PROMPT and NEGATIVE PROMPT at the BELOW of the INLAY INTERFACE
    - Output Format:
        - INLAY[...|INLAY:<OM1>]
        - [OMINLAYPROMPT1:(SITUATION),(LABEL),::Character1:{{user}}'s appearance::,::Character2:Opponent NPC1's appearance::,::(ACTION TAG)::,(PLACE),(SCENE)]
        - [NEG_OMINLAYPROMPT1:(NEGATIVE PROMPT)]
        - INLAY[...|INLAY:<OM2>]
        - [OMINLAYPROMPT2:(SITUATION),(LABEL),::Character1:{{user}}'s appearance::,::Character2:Opponent NPC2's appearance::,::(ACTION TAG)::,(PLACE),(SCENE)]
        - [NEG_OMINLAYPROMPT2:(NEGATIVE PROMPT)]
        - ..., etc.
]]
        end
    end

    if OMSNSNOIMAGE == "0" then
        if OMSNS == "1" then
            if OMSNSREAL == "1" then
                data = data .. [[
    - PRINT OUT TWITTER INTERFACE PROMPT and NEGATIVE PROMPT when the Character UPLOADS a TWEET.                
]]  
            elseif OMSNSREAL == "0" then
                data = data .. [[
    - ALWAYS PRINT OUT TWITTER INTERFACE PROMPT and NEGATIVE PROMPT at the BELOW of the TWITTER INTERFACE                    
]]
            end
            
            data = data .. [[
    - TWITTER PROMPT MUST INCLUDE NSFW SITUATION
        - Output Format:
            - TWITTER[...|<OM>|...|<OM>|...]
            - [OMTWITTERPROMPT:{{{NSFW,UNCENSORED}}},(LABEL),portrait,cowboy shot,(ACTIONS),(EXPRESSIONS),(APPEARANCE),(BODY),pussy,nipples,(DRESSES),(PLACE),(SCENE)]
            - [NEG_OMTWITTERPROMPT:{{{CENSORED}}},(NEGATIVE PROMPT)]
            - If Character does not have own profile image:
                - [OMTWITTERPROFILEPROMPT:(LABEL),(AGE),(APPEARANCE),portrait,face,close-up,white background,simple background]
                - [NEG_OMTWITTERPROFILEPROMPT:(NEGATIVE PROMPT)]
]]
        
        elseif OMSNS == "2" then
            if OMSNSREAL == "1" then
                data = data .. [[
    - PRINT OUT INSTAGRAM INTERFACE PROMPT and NEGATIVE PROMPT when the Character UPLOADS a POST.                
]]  
            elseif OMSNSREAL == "0" then
                data = data .. [[
    - ALWAYS PRINT OUT INSTAGRAM INTERFACE PROMPT and NEGATIVE PROMPT at the BELOW of the INSTAGRAM INTERFACE                    
]]
            end
            data = data .. [[
    - INSTAGRAM PROMPT MUST INCLUDE SFW SITUATION
        - Output Format:
            - INSTA[...|<OM>|...|<OM>|...]
            - [OMINSTAPROMPT:{{{CENSORED}}},(LABEL),portrait,cowboy shot,(ACTIONS),(EXPRESSIONS),(APPEARANCE),(BODY),(DRESSES),(PLACE),(SCENE)]
            - [NEG_OMINSTAPROMPT:{{{NSFW,UNCENSORED}}},pussy,nipples,(NEGATIVE PROMPT)]
            - If Character does not have own profile image:
                - [OMINSTAPROFILEPROMPT:(LABEL),(AGE),(APPEARANCE),portrait,face,close-up,white background,simple background]
                - [NEG_OMINSTAPROFILEPROMPT:(NEGATIVE PROMPT)]
]]
        elseif OMSNS == "3" then
            if OMSNSREAL == "1" then
                data = data .. [[
    - PRINT OUT TWITTER INTERFACE PROMPT and NEGATIVE PROMPT when the Character UPLOADS a TWEET.  
    - PRINT OUT INSTAGRAM INTERFACE PROMPT and NEGATIVE PROMPT when the Character UPLOADS a POST.                
]]  
            elseif OMSNSREAL == "0" then
                data = data .. [[ 
    - ALWAYS PRINT OUT TWITTER INTERFACE PROMPT and NEGATIVE PROMPT at the BELOW of the TWITTER INTERFACE       
    - ALWAYS PRINT OUT INSTAGRAM INTERFACE PROMPT and NEGATIVE PROMPT at the BELOW of the INSTAGRAM INTERFACE             
]]
            end

            data = data .. [[
    - TWITTER PROMPT MUST INCLUDE NSFW SITUATION
        - Output Format:
            - TWITTER[...|<OM>|...|<OM>|...]
            - [OMTWITTERPROMPT:{{{NSFW,UNCENSORED}}},(LABEL),portrait,cowboy shot,(ACTIONS),(EXPRESSIONS),(APPEARANCE),(BODY),pussy,nipples,(DRESSES),(PLACE),(SCENE)]
            - [NEG_OMTWITTERPROMPT:{{{CENSORED}}},(NEGATIVE PROMPT)]
            - If Character does not have own profile image:
                - [OMTWITTERPROFILEPROMPT:(LABEL),(AGE),(APPEARANCE),portrait,face,close-up,white background,simple background]
                - [NEG_OMTWITTERPROFILEPROMPT:(NEGATIVE PROMPT)]
    - INSTAGRAM PROMPT MUST INCLUDE SFW SITUATION
        - Output Format:
            - INSTA[...|<OM>|...|<OM>|...]
            - [OMINSTAPROMPT:{{{CENSORED}}},(LABEL),portrait,cowboy shot,(ACTIONS),(EXPRESSIONS),(APPEARANCE),(BODY),(DRESSES),(PLACE),(SCENE)]
            - [NEG_OMINSTAPROMPT:{{{NSFW,UNCENSORED}}},pussy,nipples,(NEGATIVE PROMPT)]
            - If Character does not have own profile image:
                - [OMINSTAPROFILEPROMPT:(LABEL),(AGE),(APPEARANCE),portrait,face,close-up,white background,simple background]
                - [NEG_OMINSTAPROFILEPROMPT:(NEGATIVE PROMPT)]
]]  
        end
    end

    if OMCOMMUNITYNOIMAGE == "0" then
        if OMCOMMUNITY == "1" then
            data = data .. [[
    - ALWAYS PRINT OUT DCINSIDE INTERFACE PROMPT and NEGATIVE PROMPT at the BELOW of the DCINSIDE INTERFACE
    - Output Format:
        - DC[...|<OM1>...|<OM2>...]
        - If the post is normal:
            - [OMDCPROMPT:(Describe the situation of the normal post)]
        - If the post is Selfie:
            - [OMDCPROMPT:(SITUATION),(LABEL),(ANGLE),(ACTIONS),(AGE),(APPEARANCE),(BODY),(DRESSES),(PLACE),(SCENE)]
        - [NEG_OMDCPROMPT:(NEGATIVE PROMPT)]
    - The number of the POST CONTENT including '<OM>' and the number of the prompt must match.
        - Example: If 3rd POST CONTENT is including '<OM3>'.
            - [OMDCPROMPT3:3rd Post's '<OM3>' Prompt Generated]
            - [NEG_OMDCPROMPT3:3rd Post's '<OM3>' (NEGATIVE PROMPT)]
]]
        end
    end

    if OMMESSENGERNOIMAGE == "0" then
        if OMMESSENGER == "1" then
            data = data .. [[
    - ALWAYS PRINT OUT KAKAOTALK INTERFACE PROMPT and NEGATIVE PROMPT at the BELOW of the KAKAOTALK INTERFACE
    - Print <OM> Exactly once when {{char}} sends a picture or image.
    - Output Format:
        - KAKAO[<OM>|...]
        - [OMKAKAOPROMPT:(SITUATION),(LABEL),Selfie,portrait,cowboy shot,(ACTIONS),(EXPRESSIONS),(APPEARANCE),(BODY),(DRESSES),(PLACE),(SCENE)]
        - [NEG_OMKAKAOPROMPT:(NEGATIVE PROMPT)]
]]
        end
    end

    data = data .. [[
## Image Prompt: CRITICAL
- This Image Prompt must be suitable for generating an image.
- Use quick, simple keywords or short descriptive phrases.
- Always keep the prompt output in English.
]]
    if OMORIGINAL == "1" then
        data = data .. [[
- The original creation exists: ]] .. OMORIGINALTEXT .. [[

- When describing a character, use the name of the creation and character instead of pronouns.
	- Example:
		- Invalid: turtle, blue skin, water, shell, white background, simple background
		- Valid: Pokémon, Squirtle, white background, simple background
- Do not make JSON Format.  
]]
    else
        data = data .. [[
- Use pronouns e.g., she, he, his, her instead of The Character's name.
- Do not make JSON Format. 
]]
    end

    if OMNSFW == "0" then
        data = data .. [[
- UNLESS STATED OTHERWISE, DO NOT USE NSFW SITUATION in the IMAGE PROMPT.
    - THEN PRINT {{{NSFW,UNCENSORED}}} in the NEGATIVE PROMPT.
]]
    elseif OMNSFW == "1" then
        data = data .. [[
- ALWAYS USE NSFW SITUATION in the IMAGE PROMPT.
    - ALWAYS PRINT {{{NSFW,UNCENSORED}}} in the IMAGE PROMPT.
    - ALWAYS PRINT {{{CENSORED}}} in the NEGATIVE PROMPT.
]]
    end

    if tonumber(OMCOMPATIBILITY) >= 1 then
        data = data .. [[
- REPLACE { and } to ( and ) in IMAGE PROMPT!!!
	- Example:
		- {1girl} => (1girl)
		- {{1boy}} => ((1boy))
]]
    end
    return data
end

local function inputImportant(triggerId, data)
    local OMCARD = getGlobalVar(triggerId, "toggle_OMCARD") or "0"
    local OMSNS = getGlobalVar(triggerId, "toggle_OMSNS") or "0"
    local OMCOMMUNITY = getGlobalVar(triggerId, "toggle_OMCOMMUNITY") or "0"
    local OMMESSENGER = getGlobalVar(triggerId, "toggle_OMMESSENGER") or "0"
    local OMMESSENGERNOIMAGE = getGlobalVar(triggerId, "toggle_OMMESSENGERNOIMAGE") or "0"

    data = data .. [[

# CRITICAL
- FROM NOW ON, YOU MUST FOLLOW THE BELOW RULES WHEN YOU ARE PRINTING DIALOGUES
]]

    if OMCARD == "1" then
        data = data .. [[
## CRITICAL: EROTIC STATUS INTERFACE
- DO NOT PRINT FEMALE CHARACTER's "MESSAGE" OUTSIDE of the EROSTATUS[...] BLOCK
    - MUST REPLACE ALL FEMALE CHARACTER's "MESSAGE" to EROSTATUS[...|DIALOGUE:MESSAGE|...]
- BODYINFO and OUTFITS MUST BE PRINTED with USER's PREFERRED LANGUAGE
- EVEN IF THE DIALOGUE IS SHORT, IT MUST BE REPLACED WITH THE STATUS BLOCK
]]
    elseif OMCARD == "2" then
        data = data .. [[
## CRITICAL: SIMULATION STATUS INTERFACE
- DO NOT PRINT "MESSAGE" OUTSIDE of the SIMULSTATUS[...] BLOCK
    - MUST REPLACE "MESSAGE" to SIMULSTATUS[...|DIALOGUE:MESSAGE|...]
- EVEN IF THE DIALOGUE IS SHORT, IT MUST BE REPLACED WITH THE STATUS BLOCK
]]
    elseif OMCARD == "3" then
        data = data .. [[
## CRITICAL: EROTIC STATUS INTERFACE
- DO NOT PRINT FEMALE CHARACTER's "MESSAGE" OUTSIDE of the EROSTATUS[...] BLOCK
    - MUST REPLACE ALL FEMALE CHARACTER's "MESSAGE" to EROSTATUS[...|DIALOGUE:MESSAGE|...]
- BODYINFO and OUTFITS MUST BE PRINTED with USER's PREFERRED LANGUAGE
- EVEN IF THE DIALOGUE IS SHORT, IT MUST BE REPLACED WITH THE STATUS BLOCK
## CRITICAL: SIMULATION STATUS INTERFACE
- DO NOT PRINT MALE CHARACTER's "MESSAGE" OUTSIDE of the SIMULSTATUS[...] BLOCK
    - MUST REPLACE "MESSAGE" to SIMULSTATUS[...|DIALOGUE:MESSAGE|...]
- EVEN IF THE DIALOGUE IS SHORT, IT MUST BE REPLACED WITH THE STATUS BLOCK
]]
    end

    if OMMESSENGER == "1" then
        data = inputKAKAOTalk(triggerId, data)
    end
    return data
end


listenEdit("editInput", function(triggerId, data)
    if not data or data == "" then return "" end

    local artistPrompt = nil
    local qualityPrompt = nil
    local negativePrompt = nil
    local OMPRESETPROMPT = getGlobalVar(triggerId, "toggle_OMPRESETPROMPT") or "0"
    local OMCARD = getGlobalVar(triggerId, "toggle_OMCARD") or "0"
    local OMSNS = getGlobalVar(triggerId, "toggle_OMSNS") or "0"
    local OMCOMMUNITY = getGlobalVar(triggerId, "toggle_OMCOMMUNITY") or "0"
    local OMMESSENGER = getGlobalVar(triggerId, "toggle_OMMESSENGER") or "0"
    local OMCARDNOIMAGE = getGlobalVar(triggerId, "toggle_OMCARDNOIMAGE") or "0"
    local OMSNSNOIMAGE = getGlobalVar(triggerId, "toggle_OMSNSNOIMAGE") or "0"
    local OMCOMMUNITYNOIMAGE = getGlobalVar(triggerId, "toggle_OMCOMMUNITYNOIMAGE") or "0"
    local OMMESSENGERNOIMAGE = getGlobalVar(triggerId, "toggle_OMMESSENGERNOIMAGE") or "0"
    
    print("ONLINEMODULE: editInput: called with data: " .. tostring(data))

    if OMMESSENGER == "1" then
        data = string.gsub(data, "  ", "\n")
        print("ONLINEMODULE: editInput: Replaced double spaces with newlines BEFORE line processing.")

        local now = os.date("*t")

        local timestampStr = "[" .. getKakaoTime(now) .. "]"
        local outputLines = {}

        for line in data:gmatch("[^\r\n]+") do
            line = string.gsub(line, "^%s+", "")
            line = string.gsub(line, "%s+$", "")

            if line ~= "" then
            local formattedLine = "TALK[" .. line .. "|" .. getKakaoTime(os.date("*t")) .. "]"
            print("ONLINEMODULE: editInput: Formatted line as: " .. formattedLine)
            table.insert(outputLines, formattedLine)
            end
        end

        local newData = table.concat(outputLines, "\n")

        print("ONLINEMODULE: editInput: Returning formatted data: " .. newData)
        return newData
    else
        return data
    end
end)

listenEdit("editRequest", function(triggerId, data)
    print("---------------------------------editREQUEST---------------------------------------")
    print("ONLINEMODULE: editRequest: Triggered with ID:", triggerId)
    local OMCARD = getGlobalVar(triggerId, "toggle_OMCARD") or "0"
    local OMSNS = getGlobalVar(triggerId, "toggle_OMSNS") or "0"
    local OMCOMMUNITY = getGlobalVar(triggerId, "toggle_OMCOMMUNITY") or "0"
    local OMMESSENGER = getGlobalVar(triggerId, "toggle_OMMESSENGER") or "0"
    local OMGLOBAL = getGlobalVar(triggerId, "toggle_OMGLOBAL") or "0"
    local UTILFORCEOUTPUT = getGlobalVar(triggerId, "toggle_UTILFORCEOUTPUT") or "0"

    local currentInput = nil
    local currentIndex = nil

    local convertDialogueFlag = false
    local changedValue = false
    
    -- 교정 토글이 켜져있다면
    if UTILFORCEOUTPUT == "1" then
        -- 받아온 리퀘스트 전부 ""변환
        for i = 1, #data, 1 do
            local chat = data[i]
            -- 만약 role이 assistant이라면
            -- 대화 내용 변환
            if chat.role == "assistant" then
                chat.content = convertDialogue(triggerId, chat.content)
                print([[ONLINEMODULE: editRequest: Converted dialogue to:

]] .. chat.content)
            end
        end
    end
    
    if OMCARD == "1" or OMCARD == "2" or OMCARD == "3" or OMMESSENGER == "1" then
        -- 만약 inputImportant가 필요하다면
        for i = 1, #data, 1 do
            -- 이후, 앞에서부터 role이 "system"인 경우에 1회 한정으로 inputImportant 삽입
            local chat = data[i]
            if chat.role == "system" then
                local importantInput = inputImportant(triggerId, chat.content)
                print ([[ONLINEMODULE: editRequest: Inserted important input to: "
                
    ]] .. importantInput .. [[ "]])
                data[i].content = importantInput
                break
            end
        end
    end



    local chat = data[#data]
        -- 가장 마지막에 로직 삽입
    currentInput = chat.content .. [[

<-----ONLINEMODULESTART----->

]]

    if OMMESSENGER == "0" then
        if OMCARD == "1" then
            currentInput = inputEroStatus(triggerId, currentInput)
            changedValue = true
        elseif OMCARD == "2" then
            currentInput = inputSimulCard(triggerId, currentInput)
            changedValue = true
        elseif OMCARD == "3" then
            currentInput = inputStatusHybrid(triggerId, currentInput)
            changedValue = true
        elseif OMCARD == "4" then
            currentInput = inputInlayOnly(triggerId, currentInput)
            changedValue = true
        end
        
        if OMSNS == "1" then
            currentInput = inputTwitter(triggerId, currentInput)
            changedValue = true
        elseif OMSNS == "2" then
            currentInput = inputInsta(triggerId, currentInput)
            changedValue = true
        elseif OMSNS == "3" then
            currentInput = inputSNSHybrid(triggerId, currentInput)
            changedValue = true
        end

        if OMCOMMUNITY == "1" then
            currentInput = inputDCInside(triggerId, currentInput)
            changedValue = true
        end
        
    elseif OMMESSENGER == "1" then
        currentInput = inputKAKAOTalk(triggerId, currentInput)
        changedValue = true
    end

    if OMGLOBAL == "1" then
        currentInput = inputImage(triggerId, currentInput)
        changedValue = true
    end

    currentInput = currentInput .. [[

<-----ONLINEMODULEEND----->

]] 
    currentInput = currentInput .. [[
    
]]

    print([[FINAL EDIT REQUEST is

]] .. currentInput)

    data[#data].content = currentInput
    
    if changedValue then
        print("Successful.")
    else
        print("Failed.")        
    end

    print("---------------------------------editREQUEST---------------------------------------")

    return data
end)


listenEdit("editDisplay", function(triggerId, data)
    if not data or data == "" then return "" end

    local OMCARD = getGlobalVar(triggerId, "toggle_OMCARD") or "0"
    local OMSNS = getGlobalVar(triggerId, "toggle_OMSNS") or "0"
    local OMCOMMUNITY = getGlobalVar(triggerId, "toggle_OMCOMMUNITY") or "0"
    local OMMESSENGER = getGlobalVar(triggerId, "toggle_OMMESSENGER") or "0"
    
    local rerollTemplate = [[
<style>
@import url('https://fonts.googleapis.com/css2?family=Pixelify+Sans:wght@400..700&display=swap');
*{box-sizing:border-box;margin:0;padding:0;}
.simple-ui-bar{width:100%;max-width:600px;margin:5px auto;background-color:#ffe6f2;border:3px solid #000000;padding:5px 10px;font-family:'Pixelify Sans',sans-serif;user-select:none;-webkit-user-select:none;-moz-user-select:none;-ms-user-select:none;}
.separator{height:2px;background-color:#000000;width:100%;margin:3px 0;}
.profile-reroll-area{display:flex;align-items:center;gap:5px;padding:5px 0;justify-content:space-between;flex-wrap:wrap;border-bottom:2px solid #000000;}
.profile-info{display:flex;align-items:center;gap:5px;flex-grow:1;min-width:150px;}
.profile-id-label{font-weight:bold;color:#ff69b4;flex-shrink:0;}
.profile-id-value{font-weight:normal;color:#000000;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}
.profile-preview{width:32px;height:32px;border-radius:50%;background-color:#cccccc;border:2px solid #000000;overflow:hidden;display:flex;justify-content:center;align-items:center;flex-shrink:0;}
.profile-preview>*{width:100%;height:100%;object-fit:cover;display:block;}
.reroll-button{background-color:#000000;color:#ffffff;border:2px solid #ff69b4;font-family:inherit;font-size:18px;cursor:pointer;transition:all 0.2s ease;flex-shrink:0;min-width:80px;min-height:24px;position:relative;}
.reroll-button::before{content:attr(data-text);white-space:pre;}
.reroll-button::after{content:"REROLL";font-weight:bold;font-size:18px;color:#ffffff;pointer-events:none;transition:color 0.2s ease;}
.reroll-button:hover{background-color:#ff69b4;color:#000000;border-color:#000000;}
.reroll-button:hover::after{color:#000000;}
.reroll-button:active{transform:translateY(1px);}
.global-reroll-controls{text-align:center;margin-top:10px;padding-top:5px;border-top:2px solid #000000;}
</style>
]]   

    data = rerollTemplate .. data

    if OMCARD == "1" then
        data = changeEroStatus(triggerId, data)
    elseif OMCARD == "2" then
        data = changeSimulCard(triggerId, data)
    elseif OMCARD == "3" then
        data = changeEroStatus(triggerId, data)
        data = changeSimulCard(triggerId, data)
    elseif OMCARD == "4" then
        data = changeInlayOnly(triggerId, data)
    end

    if OMSNS == "1" then
        data = changeTwitter(triggerId, data)
    elseif OMSNS == "2" then
        data = changeInsta(triggerId, data)
    elseif OMSNS == "3" then
        data = changeSNSHybrid(triggerId, data)
    end
    
    if OMCOMMUNITY == "1" then
        data = changeDCInside(triggerId, data)
    end
    
    if OMMESSENGER == "1" then
        data = changeKAKAOTalk(triggerId, data)
    end

    -- data = addRerollFormButton(triggerId, data)

    return data
end)

listenEdit("editOutput", function(triggerId, data)
    if not data or data == "" then return "" end
    local OMMESSENGER = getGlobalVar(triggerId, "toggle_OMMESSENGER") or "0"

    if OMMESSENGER == "1" then
        print("ONLINEMODULE: editOutput: OMMESSENGER == 1, filtering to keep only KAKAO blocks")
        
        local lines = {}
        for line in (data .. "\n"):gmatch("([^\n]*)\n") do
            table.insert(lines, line)
        end
        
        local filteredLines = {}
        local keepNextLines = false
        
        for i, line in ipairs(lines) do
            if string.find(line, "^KAKAO%[") then
                table.insert(filteredLines, line)
                keepNextLines = true
            elseif keepNextLines and (
                string.find(line, "^%[OMKAKAOPROMPT:") or
                string.find(line, "^%[NEG_OMKAKAOPROMPT:")
            ) then
                table.insert(filteredLines, line)
                if string.find(line, "^%[NEG_OMKAKAOPROMPT:") then
                    keepNextLines = false 
                end
            elseif line:match("^%s*$") then
                table.insert(filteredLines, line)
            end
        end
        
        data = table.concat(filteredLines, "\n")
        print("ONLINEMODULE: editOutput: Filtered to keep only KAKAO blocks and their prompts")
    end
    
    return data
end)

function onInput(triggerId)
    print("----- ANALYZING VALUABLES -----")
    print("ONLINEMODULE: onInput: Triggered with ID:", triggerId)

    local OMGLOBAL = getGlobalVar(triggerId, "toggle_OMGLOBAL") or "0"
    local OMCARD = getGlobalVar(triggerId, "toggle_OMCARD") or "0"
    local OMSNS = getGlobalVar(triggerId, "toggle_OMSNS") or "0"
    local OMSNSNOIMAGE = getGlobalVar(triggerId, "toggle_OMSNSNOIMAGE") or "0"
    local OMSNSTARGET = getGlobalVar(triggerId, "toggle_OMSNSTARGET") or "0"
    local OMCOMMUNITY = getGlobalVar(triggerId, "toggle_OMCOMMUNITY") or "0"
    local OMMESSENGER = getGlobalVar(triggerId, "toggle_OMMESSENGER") or "0"
    local UTILREMOVEPREVIOUSDISPLAY = getGlobalVar(triggerId, "toggle_UTILREMOVEPREVIOUSDISPLAY") or "0"

    if OMSNS ~= "0" then
        if OMSNSNOIMAGE == "1" then
            if OMSNSTARGET == "2" then
                alertNormal(triggerId, "ERROR: SETTING: OMSNS~=0;OMSNSNOIMAGE=1;OMSNSTARGET=2;")
                return
            end
        end
    end
    
    if OMMESSENGER == "1" then
        if tonumber(OMCARD) >= 1 then
            alertNormal(triggerId, "ERROR: SETTING: OMMESSENGER=1;OMCARD>=1;")
        elseif tonumber(OMSNS) >= 1 then
            alertNormal(triggerId, "ERROR: SETTING: OMMESSENGER=1;OMSNS>=1;")
        elseif tonumber(OMCOMMUNITY) >= 1 then
            alertNormal(triggerId, "ERROR: SETTING: OMMESSENGER=1;OMCOMMUNITY>=1;")
        end
    end


    local chatHistoryTable = getFullChat(triggerId)
    local historyLength = #chatHistoryTable
    local targetIndex = historyLength

    print(string.format("ONLINEMODULE: onInput>>>> DEBUG: historyLength = %d, targetIndex = %d <<<<", historyLength, targetIndex))

    if targetIndex < 3 then
        print(string.format("ONLINEMODULE: onInput: History too short to find target message (index %d). Minimum 3 entries required (currently %d).", targetIndex, historyLength))
        return nil
    end

    print("ONLINEMODULE: onInput: Calculated target message index:", targetIndex)

    local targetMessageData = chatHistoryTable[targetIndex]
    if not targetMessageData or type(targetMessageData) ~= "table" or not targetMessageData.data or type(targetMessageData.data) ~= "string" then
        print(string.format("ONLINEMODULE: onInput: Message at target index %d is not in the expected format (string in 'data' field within a table).", targetIndex))
        return nil
    end

    local originalLine = targetMessageData.data
    local modifiedLine = originalLine
    local historyModifiedByWrapping = false
    local prefixesToWrap = {"EROSTATUS", "SIMULSTATUS", "TWITTER", "INSTA", "DC", "INLAY"}
    local replacementFormat = "<details><summary><span>(열기/접기)</span></summary>%s</details>"
    local checkAlreadyWrappedStart = "<details><summary><span>(열기/접기)</span></summary>"

    print(string.format("ONLINEMODULE: onInput: Checking content of message at index %d for wrapping...", targetIndex))
    
    
    if UTILREMOVEPREVIOUSDISPLAY == "0" then

        for _, prefix in ipairs(prefixesToWrap) do
            print(string.format("ONLINEMODULE: onInput-> Index %d: Processing prefix '%s'...", targetIndex, prefix))
            local wrapTargetPattern = string.format("(%s%%[.-%%])", prefix)
            local currentLineForPrefix = modifiedLine
            local tempLine = ""
            local lastEnd = 1
            local anyWrappedThisPrefix = false

            while true do
                local s, e, capturedBlock = string.find(currentLineForPrefix, wrapTargetPattern, lastEnd)

                if not s then
                    tempLine = tempLine .. string.sub(currentLineForPrefix, lastEnd)
                    break
                end

                local potentialWrapperStartPos = s - #checkAlreadyWrappedStart
                local isAlreadyWrapped = false
                if potentialWrapperStartPos >= 1 then
                    if string.sub(currentLineForPrefix, potentialWrapperStartPos, s - 1) == checkAlreadyWrappedStart then
                        isAlreadyWrapped = true
                    end
                end

                if isAlreadyWrapped then
                    print(string.format("ONLINEMODULE: onInput-> Index %d: Found %s block at %d-%d, but it is already wrapped. Skipping.", targetIndex, prefix, s, e))
                    tempLine = tempLine .. string.sub(currentLineForPrefix, lastEnd, e)
                else
                    print(string.format("ONLINEMODULE: onInput-> Index %d: Found unwrapped %s block at %d-%d. Applying wrapping.", targetIndex, prefix, s, e))
                    local wrappedBlock = string.format(replacementFormat, capturedBlock)
                    tempLine = tempLine .. string.sub(currentLineForPrefix, lastEnd, s - 1)
                    tempLine = tempLine .. wrappedBlock
                    historyModifiedByWrapping = true
                    anyWrappedThisPrefix = true
                end

                lastEnd = e + 1
            end
            
            modifiedLine = tempLine
            if anyWrappedThisPrefix then
                print(string.format("ONLINEMODULE: onInput-> Index %d: Finished wrapping occurrences for prefix '%s'.", targetIndex, prefix))
            else
                print(string.format("ONLINEMODULE: onInput-> Index %d: No unwrapped blocks found for prefix '%s'.", targetIndex, prefix))
            end
        end
    elseif UTILREMOVEPREVIOUSDISPLAY == "1" then
        print("WRAPPING MODIFIED LINE!!!")
        modifiedLine = "<details><summary><span>(열기/접기)</span></summary>" .. modifiedLine .. "</details>"
        print(modifiedLine)
        historyModifiedByWrapping = true
    end


    if historyModifiedByWrapping then
        print("ONLINEMODULE: onInput: Chat history was modified. Applying changes.")
        setChat(triggerId, targetIndex - 1, modifiedLine)
        print("ONLINEMODULE: onInput: setChat call complete.")
    else
        print("ONLINEMODULE: onInput: No modifications were made to the chat history.")
    end

end

onOutput = async(function (triggerId)
    print("onOutput: Triggered with ID:", triggerId)
    local OMGLOBAL = getGlobalVar(triggerId, "toggle_OMGLOBAL") or "0"
    if OMGLOBAL == "0" then
        return
    end
    
	local artistPrompt = nil
    local qualityPrompt = nil
    local negativePrompt = nil
    local OMPRESETPROMPT = getGlobalVar(triggerId, "toggle_OMPRESETPROMPT") or "0"
    local OMCARD = getGlobalVar(triggerId, "toggle_OMCARD") or "0"
    local OMSNS = getGlobalVar(triggerId, "toggle_OMSNS") or "0"
    local OMCOMMUNITY = getGlobalVar(triggerId, "toggle_OMCOMMUNITY") or "0"
    local OMMESSENGER = getGlobalVar(triggerId, "toggle_OMMESSENGER") or "0"
    local OMCARDNOIMAGE = getGlobalVar(triggerId, "toggle_OMCARDNOIMAGE") or "0"
    local OMSNSNOIMAGE = getGlobalVar(triggerId, "toggle_OMSNSNOIMAGE") or "0"
    local OMCOMMUNITYNOIMAGE = getGlobalVar(triggerId, "toggle_OMCOMMUNITYNOIMAGE") or "0"
    local OMMESSENGERNOIMAGE = getGlobalVar(triggerId, "toggle_OMMESSENGERNOIMAGE") or "0"
	
    if OMPRESETPROMPT == "0" then
        artistPrompt = getGlobalVar(triggerId, "toggle_OMARTISTPROMPT") or ""
        qualityPrompt = getGlobalVar(triggerId, "toggle_OMQUALITYPROMPT") or ""
        negativePrompt = getGlobalVar(triggerId, "toggle_OMNEGPROMPT") or ""
    elseif OMPRESETPROMPT == "1" then
        artistPrompt = "1.33::artist:Goldcan9 ::, 1.1::artist:sakurai norio,artist: torino,year 2023 ::, 0.5::artist: eonsang, artist: gomzi, artist:shiba ::"
        qualityPrompt = "smooth lines, excellent color, depth of field, shiny skin, best quality, amazing quality, very aesthetic, highres, incredibly absurdres"
        negativePrompt = "{{{worst quality}}}, {{{bad quality}}}, reference, unfinished, unclear fingertips, twist, Squiggly, Grumpy, incomplete, {{Imperfect Fingers}}, Cheesy, {{very displeasing}}, {{mess}}, {{Approximate}}, {{monochrome}}, {{greyscale}}, 3D"
    elseif OMPRESETPROMPT == "2" then
        artistPrompt = "1.3::artist:tianliang duohe fangdongye ::,1.2::artist:shuz ::, 0.7::artist:wlop ::, 1.0::artist:kase daiki ::,0.8::artist:ningen mame ::,0.8::artist:voruvoru ::,0.8::artist:tomose_shunsaku ::,0.7::artist:sweetonedollar ::,0.7::artist:chobi (penguin paradise) ::,0.8::artist:rimo ::,{year 2024, year 2025}"
        qualityPrompt = "Detail Shading, {{{{{{{{{{amazing quality}}}}}}}}}}, very aesthetic, highres, incredibly absurdres"
        negativePrompt = "dark lighting,{{{blurry}}},{{{{{{{{worst quality, bad quality, japanese text}}}}}}}}, {{{{bad hands, closed eyes}}}}, {{{bad eyes, bad pupils, bad glabella}}}, {{{undetailed eyes}}}, multiple views, error, extra digit, fewer digits, jpeg artifacts, signature, watermark, username, reference, {{unfinished}}, {{unclear fingertips}}, {{twist}}, {{squiggly}}, {{grumpy}}, {{incomplete}}, {{imperfect fingers}}, disorganized colors, cheesy, {{very displeasing}}, {{mess}}, {{approximate}}, {{sloppiness}}"
    elseif OMPRESETPROMPT == "3" then
        artistPrompt = "artist:rella, artist:ixy, artist:gomzi, artist:tsunako, artist:momoko (momopoco)"
        qualityPrompt = "illustration, best quality, amazing quality, very aesthetic, highres, incredibly absurdres, 1::perfect_eyes::, 1::beautiful detail eyes::, incredibly absurdres, finely detailed beautiful eyes"
        negativePrompt = "3D, blurry, lowres, error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, multiple views, logo, too many watermarks, white blank page, blank page, 1.2::worst quality::, 1.2::bad quality::, 1.2::Imperfect Fingers::, 1.1::Imperfect Fingers::, 1.2::Approximate::, 1.1::very displeasing::, 1.1::mess::, 1::unfinished::, 1::unclear fingertips::, 1::twist::, 1::Squiggly::, 1::Grumpy::, 1::incomplete::, 1::Cheesy::, 1.3::mascot::, 1.3::puppet::, 1.3::character doll::, 1.3::pet::, 1.3::cake::, 1.3::stuffed toy::, 1::reference::, 1.1::multiple views::, 1.1::monochrome::, 1.1::greyscale::, 1.1::sketch::, 1.1::flat color::, 1.1::3D::, 1::aged down::, 1.:bestiality::, 1::furry::, 1::crowd::, 1::animals::, 1::pastie::, 1::maebari::, 1::eyeball::, 1::slit pupils::, 1::bright pupils::"
    elseif OMPRESETPROMPT == "4" then
        artistPrompt = "0.8::artist:namako daibakuhatsu ::, 0.5::artist:tianliang duohe fangdongye ::, 0.4::channel(caststation) ::, 0.7::jtveemo ::, 1.3::pixel art,  8-bit, pixel size: 4 ::, year 2024"
        qualityPrompt = "Detail Shading, {{{{{{{{{{amazing quality}}}}}}}}}}, very aesthetic, highres, incredibly absurdres"
        negativePrompt = "dark lighting,{{{blurry}}},{{{{{{{{worst quality, bad quality, japanese text}}}}}}}}, {{{{bad hands, closed eyes}}}}, {{{bad eyes, bad pupils, bad glabella}}}, {{{undetailed eyes}}}, multiple views, error, extra digit, fewer digits, jpeg artifacts, signature, watermark, username, reference, {{unfinished}}, {{unclear fingertips}}, {{twist}}, {{squiggly}}, {{grumpy}}, {{incomplete}}, {{imperfect fingers}}, disorganized colors, cheesy, {{very displeasing}}, {{mess}}, {{approximate}}, {{sloppiness}}"
    end
    	
	print("-----------------------ART PROMPT-----------------------")
	print(artistPrompt)
	print(qualityPrompt)
	print(negativePrompt)
	print("-----------------------ART PROMPT-----------------------")
	

    print("ONLINEMODULE: onOutput: OMCARD value:", OMCARD)
    print("ONLINEMODULE: onOutput: OMSNS value:", OMSNS)
	print("ONLINEMODULE: onOutput: OMCOMMUNITY value:", OMCOMMUNITY)
    print("ONLINEMODULE: onOutput: OMMESSENGER value:", OMMESSENGER)
    

    if OMMESSENGER == "1" then
        print("ONLINEMODULE: onOutput: FORCE SETTING VALUES to 0")
        OMCARD = "0"
        OMSNS = "0"
        OMCOMMUNITY = "0"
    end

    local togglesActive = OMCARD ~= "0" or OMSNS ~= "0" or OMCOMMUNITY ~= "0" or OMMESSENGER ~= "0"

    if not togglesActive then
        print("ONLINEMODULE: onOutput: Skipping OM generation modifications as all relevant toggles are off.")
    end

    print("ONLINEMODULE: onOutput: togglesActive: " .. tostring(togglesActive))

    local chatHistoryTable = getFullChat(triggerId)

    if type(chatHistoryTable) ~= "table" or #chatHistoryTable < 1 then
        print("ONLINEMODULE: onOutput: onOutput: Received non-table or empty table. No action taken.")
        return
    end

    local generatedImagesInfo = {}

    print("ONLINEMODULE: onOutput: Original chat history received (table with " .. #chatHistoryTable .. " entries)")

    local profileGeneratedThisRun = false
    local generatedProfileId = nil
    local generatedProfileInlay = nil

    local historyModifiedByWrapping = false
    local lastIndex = #chatHistoryTable
    
    local skipOMCARD = false
    local skipOMSNS = false
    local skipOMCOMMUNITY = false
    local skipOMMESSENGER = false
    
    if OMCARDNOIMAGE == "1" then skipOMCARD = 1 end
    if OMSNSNOIMAGE == "1" then skipOMSNS = 1 end
    if OMCOMMUNITYNOIMAGE == "1" then skipOMCOMMUNITY = 1 end
    if OMMESSENGERNOIMAGE == "1" then skipOMMESSENGER = 1 end

    local currentLine = ""

    if togglesActive and lastIndex > 0 then
        local messageData = chatHistoryTable[lastIndex]
        if type(messageData) == "table" and messageData.data and type(messageData.data) == "string" then
            currentLine = messageData.data
            local lineModifiedInThisPass = false

            print("ONLINEMODULE: onOutput: Processing last message (index " .. lastIndex .. ") for OM Generation/Replacement")

            if OMCARD == "1" and not skipOMCARD then
                -- 에로스테만 사용할 때
                print("ONLINEMODULE: onOutput: OMCARD == 1")
                local searchPos = 1
                local statusBlocksFound = 0
                local statusReplacements = {}
                local OMCACHE = getGlobalVar(triggerId, "toggle_OMCACHE") or "0"
                local characterImageCache = {} -- 메모리 내 캐시 추가
                print("ONLINEMODULE: onOutput: OMCACHE value:", OMCACHE)

                while true do
                    local s_status, e_status_prefix = string.find(currentLine, "EROSTATUS%[", searchPos)
                    if not s_status then
                        print("ONLINEMODULE: onOutput: No more EROSTATUS[ blocks found starting from position " .. searchPos)
                        break
                    end
                    statusBlocksFound = statusBlocksFound + 1
                    print("ONLINEMODULE: onOutput: Found EROSTATUS[ block #" .. statusBlocksFound .. " starting at index " .. s_status)

                    local bracketLevel = 1
                    local e_status_suffix = e_status_prefix + 1
                    local foundClosingBracket = false
                    local searchEnd = #currentLine
                    while e_status_suffix <= searchEnd do
                        local char = currentLine:sub(e_status_suffix, e_status_suffix)
                        if char == '[' then
                            bracketLevel = bracketLevel + 1
                        elseif char == ']' then
                            bracketLevel = bracketLevel - 1
                        end
                        if bracketLevel == 0 then
                            foundClosingBracket = true
                            break
                        end
                        e_status_suffix = e_status_suffix + 1
                    end

                    if foundClosingBracket then
                        print("ONLINEMODULE: onOutput: EROSTATUS block #" .. statusBlocksFound .. " closing bracket found at index " .. e_status_suffix)
                        local statusBlockContent = string.sub(currentLine, s_status, e_status_suffix)
                        local statusPattern = "EROSTATUS%[NAME:([^|]*)|"
                        local _, _, currentBlockName = string.find(statusBlockContent, statusPattern)
                        local trimmedBlockName = nil
                        if currentBlockName then
                            trimmedBlockName = currentBlockName:match("^%s*(.-)%s*$")
                            print("ONLINEMODULE: onOutput: Block NAME found: [" .. trimmedBlockName .. "]")
                        else
                            print("ONLINEMODULE: onOutput: Block NAME pattern did not match.")
                        end

                        local blockContent = string.sub(currentLine, e_status_prefix + 1, e_status_suffix - 1)
                        local omSearchPosInContent = 1
                        local omTagsFoundInBlock = 0
                        while true do
                            local s_om_in_content, e_om_in_content, omIndexStr = string.find(blockContent, "<OM(%d+)>", omSearchPosInContent)
                            if not s_om_in_content then break end
                            omTagsFoundInBlock = omTagsFoundInBlock + 1
                            local omIndex = tonumber(omIndexStr)
                            if omIndex then
                                local content_offset = e_status_prefix
                                local om_abs_start = content_offset + s_om_in_content
                                local om_abs_end = content_offset + e_om_in_content
                                
                                local useExistingImage = false
                                local existingInlay = nil
                                
                                -- 캐릭터 이름이 있고 OMCACHE가 활성화된 경우 기존 이미지 확인
                                if trimmedBlockName and trimmedBlockName ~= "" then
                                    -- 메모리 캐시 먼저 확인
                                    existingInlay = characterImageCache[trimmedBlockName]
                                    
                                    -- 메모리 캐시에 없으면 상태 변수에서 확인
                                    if not existingInlay then
                                        existingInlay = getState(triggerId, trimmedBlockName) or "null"
                                        if existingInlay ~= "null" then
                                            -- 상태 변수에서 찾은 이미지를 메모리 캐시에 저장
                                            characterImageCache[trimmedBlockName] = existingInlay
                                            print("ONLINEMODULE: onOutput: Loaded existing inlay from state for NAME: " .. trimmedBlockName)
                                        else
                                            existingInlay = nil
                                        end
                                    else
                                        print("ONLINEMODULE: onOutput: Using memory cached inlay for NAME: " .. trimmedBlockName)
                                    end
                                    
                                    -- OMCACHE 설정에 따라 기존 이미지 사용 여부 결정
                                    if OMCACHE == "1" and existingInlay then
                                        useExistingImage = true
                                        print("ONLINEMODULE: onOutput: OMCACHE enabled, using existing image for " .. trimmedBlockName)
                                    end
                                end
                                
                                if useExistingImage then
                                    -- 기존 이미지 사용
                                    table.insert(statusReplacements, {
                                        start = om_abs_start,
                                        finish = om_abs_end,
                                        inlay = "<OM" .. omIndex .. ">" .. existingInlay
                                    })
                                    print("ONLINEMODULE: onOutput: Added cached inlay after OM" .. omIndex .. " at absolute pos " .. om_abs_end)
                                else
                                    -- 새 이미지 생성
                                    local statusPromptFindPattern = "%[OMSTATUSPROMPT" .. omIndex .. ":([^%]]*)%]"
                                    local statusNegPromptFindPattern = "%[NEG_OMSTATUSPROMPT" .. omIndex .. ":([^%]]*)%]"
                                    local _, _, foundStatusPrompt = string.find(currentLine, statusPromptFindPattern)
                                    local _, _, foundStatusNegPrompt = string.find(currentLine, statusNegPromptFindPattern)
                                    local currentNegativePromptStatus = negativePrompt
                                    if foundStatusNegPrompt then
                                        currentNegativePromptStatus = foundStatusNegPrompt .. ", " .. currentNegativePromptStatus
                                    end
                                    if foundStatusPrompt then
                                        local finalPromptStatus = artistPrompt .. ", " .. foundStatusPrompt .. ", " .. qualityPrompt
                                        local inlayStatus = generateImage(triggerId, finalPromptStatus, currentNegativePromptStatus):await()
                                        if inlayStatus and type(inlayStatus) == "string" and string.len(inlayStatus) > 10 and 
                                           not string.find(inlayStatus, "fail", 1, true) and 
                                           not string.find(inlayStatus, "error", 1, true) and 
                                           not string.find(inlayStatus, "실패", 1, true) then
                                            
                                            -- 생성된 이미지를 테이블에 추가 - 기존 OM 태그를 교체
                                            table.insert(statusReplacements, {
                                                start = om_abs_start,
                                                finish = om_abs_end,
                                                inlay = "<OM" .. omIndex .. ">" .. inlayStatus
                                            })
                                            
                                            -- trimmedBlockName이 존재하면 상태를 저장
                                            if trimmedBlockName and trimmedBlockName ~= "" then
                                                -- 생성된 이미지를 상태 변수와 메모리 캐시에 저장
                                                setState(triggerId, trimmedBlockName, inlayStatus)
                                                characterImageCache[trimmedBlockName] = inlayStatus
                                                print("ONLINEMODULE: onOutput: Stored new inlay for NAME: " .. trimmedBlockName)
                                            end
                                        else
                                            ERR(triggerId, "EROSTATUS", 2)
                                            print("ONLINEMODULE: onOutput: Image generation failed for OM" .. omIndex)
                                        end
                                    else
                                        ERR(triggerId, "EROSTATUS", 0)
                                        print("ONLINEMODULE: onOutput: Prompt NOT FOUND for OM" .. omIndex .. " in currentLine.")
                                    end
                                end
                            end
                            omSearchPosInContent = e_om_in_content + 1
                        end
                        
                        if omTagsFoundInBlock == 0 then
                            ERR(triggerId, "EROSTATUS", 3)
                            print("ONLINEMODULE: onOutput: No <OM> tags found in block #" .. statusBlocksFound)
                        end
                        searchPos = e_status_suffix + 1
                    else
                        ERR(triggerId, "EROSTATUS", 1)
                        print("ONLINEMODULE: onOutput: CRITICAL - Closing bracket ']' not found for EROSTATUS block #" .. statusBlocksFound .. " even after nested check! Skipping to next search pos.")
                        searchPos = e_status_prefix + 1
                    end
                end

                if #statusReplacements > 0 then
                    print("ONLINEMODULE: onOutput: Applying ".. #statusReplacements .." erostatus replacements.")
                    table.sort(statusReplacements, function(a, b) return a.start > b.start end)
                    for i_rep, rep in ipairs(statusReplacements) do
                        if rep.start > 0 and rep.finish >= rep.start and rep.finish <= #currentLine then
                            currentLine = string.sub(currentLine, 1, rep.start - 1) .. rep.inlay .. string.sub(currentLine, rep.finish + 1)
                            lineModifiedInThisPass = true
                        end
                    end
                else
                    print("ONLINEMODULE: onOutput: No erostatus replacements to apply.")
                end

            elseif OMCARD == "2" and not skipOMCARD then
                -- 시뮬봇 상태창만 사용할 때
                print("ONLINEMODULE: onOutput: OMCARD == 2 entered.")
                local searchPos = 1
                local simulReplacements = {}
                local statusBlocksFound = 0
                local OMCACHE = getGlobalVar(triggerId, "toggle_OMCACHE") or "0"
                local characterImageCache = {} -- 메모리 내 캐시 추가
                print("ONLINEMODULE: onOutput: OMCACHE value:", OMCACHE)

                while true do
                    local s_simul, e_simul_prefix = string.find(currentLine, "SIMULSTATUS%[", searchPos)
                    if not s_simul then
                        print("ONLINEMODULE: onOutput: No more SIMULSTATUS[ blocks found starting from position " .. searchPos)
                        break
                    end
                    statusBlocksFound = statusBlocksFound + 1
                    print("ONLINEMODULE: onOutput: Found SIMULSTATUS[ block #" .. statusBlocksFound .. " starting at index " .. s_simul)

                    local bracketLevel = 1
                    local e_simul_suffix = e_simul_prefix + 1
                    local foundClosingBracket = false
                    local searchEnd = #currentLine 
                    while e_simul_suffix <= searchEnd do
                        local char = currentLine:sub(e_simul_suffix, e_simul_suffix)
                        if char == '[' then
                            bracketLevel = bracketLevel + 1
                        elseif char == ']' then
                            bracketLevel = bracketLevel - 1
                        end
                        if bracketLevel == 0 then
                            foundClosingBracket = true
                            break
                        end
                        e_simul_suffix = e_simul_suffix + 1
                    end

                    if foundClosingBracket then
                        print("ONLINEMODULE: onOutput: SIMULSTATUS block #" .. statusBlocksFound .. " closing bracket found at index " .. e_simul_suffix)

                        local statusBlockContent = string.sub(currentLine, s_simul, e_simul_suffix)
                        local statusPattern = "SIMULSTATUS%[NAME:([^|]*)|"
                        local _, _, currentBlockName = string.find(statusBlockContent, statusPattern)

                        local trimmedBlockName = nil
                        if currentBlockName then
                            trimmedBlockName = currentBlockName:match("^%s*(.-)%s*$")
                            print("ONLINEMODULE: onOutput: Block NAME found: [" .. trimmedBlockName .. "]")
                        else
                            print("ONLINEMODULE: onOutput: Block NAME pattern did not match.")
                        end

                        local simulContent = string.sub(currentLine, e_simul_prefix + 1, e_simul_suffix - 1)
                        local omSearchPosInContent = 1
                        local omTagsFoundInBlock = 0

                        while true do
                            local s_om_in_content, e_om_in_content, omIndexStr = string.find(simulContent, "<OM(%d+)>", omSearchPosInContent)
                            if not s_om_in_content then break end
                            omTagsFoundInBlock = omTagsFoundInBlock + 1
                            local omIndex = tonumber(omIndexStr)
                            
                            if omIndex then
                                local content_offset = e_simul_prefix
                                local om_abs_start = content_offset + s_om_in_content
                                local om_abs_end = content_offset + e_om_in_content
                                
                                local useExistingImage = false
                                local existingInlay = nil
                                
                                -- 캐릭터 이름이 있고 OMCACHE가 활성화된 경우 기존 이미지 확인
                                if trimmedBlockName and trimmedBlockName ~= "" then
                                    -- 메모리 캐시 먼저 확인
                                    existingInlay = characterImageCache[trimmedBlockName]
                                    
                                    -- 메모리 캐시에 없으면 상태 변수에서 확인
                                    if not existingInlay then
                                        existingInlay = getState(triggerId, trimmedBlockName) or "null"
                                        if existingInlay ~= "null" then
                                            -- 상태 변수에서 찾은 이미지를 메모리 캐시에 저장
                                            characterImageCache[trimmedBlockName] = existingInlay
                                            print("ONLINEMODULE: onOutput: Loaded existing inlay from state for NAME: " .. trimmedBlockName)
                                        else
                                            existingInlay = nil
                                        end
                                    else
                                        print("ONLINEMODULE: onOutput: Using memory cached inlay for NAME: " .. trimmedBlockName)
                                    end
                                    
                                    -- OMCACHE 설정에 따라 기존 이미지 사용 여부 결정
                                    if OMCACHE == "1" and existingInlay then
                                        useExistingImage = true
                                        print("ONLINEMODULE: onOutput: OMCACHE enabled, using existing image for " .. trimmedBlockName)
                                    end
                                end

                                if useExistingImage then
                                    -- 기존 이미지 사용
                                    table.insert(simulReplacements, {
                                        start = om_abs_end,
                                        finish = om_abs_end,
                                        inlay = existingInlay
                                    })
                                    print("ONLINEMODULE: onOutput: Added cached inlay after OM" .. omIndex .. " at absolute pos " .. om_abs_end)
                                else
                                    -- 새 이미지 생성
                                    local simulPromptPattern = "%[OMSIMULCARDPROMPT" .. omIndex .. ":([^%]]*)%]"
                                    local negSimulPromptPattern = "%[NEG_OMSIMULCARDPROMPT" .. omIndex .. ":([^%]]*)%]"
                                    local _, _, foundSimulPrompt = string.find(currentLine, simulPromptPattern)
                                    local _, _, foundNegSimulPrompt = string.find(currentLine, negSimulPromptPattern)

                                    if foundSimulPrompt then
                                        print("ONLINEMODULE: onOutput: Found prompt for OM" .. omIndex .. ": [" .. string.sub(foundSimulPrompt, 1, 50) .. "...]")
                                        local currentNegativePromptSimul = negativePrompt
                                        if foundNegSimulPrompt then 
                                            currentNegativePromptSimul = foundNegSimulPrompt .. ", " .. currentNegativePromptSimul
                                        end
                                        local finalPromptSimul = artistPrompt .. ", " .. foundSimulPrompt .. ", " .. qualityPrompt
                                        local inlaySimul = generateImage(triggerId, finalPromptSimul, currentNegativePromptSimul):await()
                                        
                                        if inlaySimul and type(inlaySimul) == "string" and string.len(inlaySimul) > 10 and 
                                           not string.find(inlaySimul, "fail", 1, true) and 
                                           not string.find(inlaySimul, "error", 1, true) and 
                                           not string.find(inlaySimul, "실패", 1, true) then
                                            
                                            print("ONLINEMODULE: onOutput: Image generation SUCCESS for OM" .. omIndex)
                                            
                                            table.insert(simulReplacements, {
                                                start = om_abs_end,
                                                finish = om_abs_end,
                                                inlay = inlaySimul
                                            })
                                            
                                            if trimmedBlockName and trimmedBlockName ~= "" then
                                                -- 생성된 이미지를 상태 변수와 메모리 캐시에 저장
                                                setState(triggerId, trimmedBlockName, inlaySimul)
                                                characterImageCache[trimmedBlockName] = inlaySimul
                                                print("ONLINEMODULE: onOutput: Stored new inlay for NAME: " .. trimmedBlockName)
                                            end
                                        else
                                            ERR(triggerId, "SIMULCARD", 2)
                                            print("ONLINEMODULE: onOutput: Image generation FAILED for OM" .. omIndex)
                                        end
                                    else
                                        ERR(triggerId, "SIMULCARD", 0)
                                        print("ONLINEMODULE: onOutput: Prompt NOT FOUND for OM" .. omIndex)
                                    end
                                end
                            end
                            omSearchPosInContent = e_om_in_content + 1
                        end
                        
                        if omTagsFoundInBlock == 0 then
                            ERR(triggerId, "SIMULCARD", 3)
                            print("ONLINEMODULE: onOutput: No <OM> tags found in block #" .. statusBlocksFound)
                        end
                        searchPos = e_simul_suffix + 1
                    else
                        ERR(triggerId, "SIMULCARD", 1)
                        print("ONLINEMODULE: onOutput: Closing bracket not found for block #" .. statusBlocksFound)
                        searchPos = e_simul_prefix + 1
                    end
                end

                if statusBlocksFound == 0 then
                    ERR(triggerId, "SIMULCARD", 4)
                    print("ONLINEMODULE: onOutput: No SIMULSTATUS blocks found in message")
                end
                
                if #simulReplacements > 0 then
                    print("ONLINEMODULE: onOutput: Applying " .. #simulReplacements .. " simulcard replacements")
                    table.sort(simulReplacements, function(a, b) return a.start > b.start end)
                    for _, rep in ipairs(simulReplacements) do
                        if rep.start > 0 and rep.finish >= rep.start and rep.finish <= #currentLine then
                            currentLine = string.sub(currentLine, 1, rep.start) .. rep.inlay .. string.sub(currentLine, rep.finish + 1)
                        end
                    end
                    lineModifiedInThisPass = true
                else
                    print("ONLINEMODULE: onOutput: No simulcard replacements to apply")
                end
            elseif OMCARD == "3" and not skipOMCARD then
                -- 상태창 하이브리드 모드 사용할 때
                print("ONLINEMODULE: onOutput: OMCARD == 3 (Hybrid mode)")
                local searchPos = 1
                local replacements = {}
                local statusBlocksFound = 0
                local characterImageCache = {} -- 캐릭터별 이미지 캐시 (시뮬레이션용)
                local OMCACHE = getGlobalVar(triggerId, "toggle_OMCACHE") or "0"
                print("ONLINEMODULE: onOutput: OMCACHE value:", OMCACHE)

                while true do
                    local s_ero, e_ero_prefix = string.find(currentLine, "EROSTATUS%[", searchPos)
                    local s_sim, e_sim_prefix = string.find(currentLine, "SIMULSTATUS%[", searchPos)
                    
                    local s_status, e_status_prefix, isEroStatus
                    if s_ero and (not s_sim or s_ero < s_sim) then
                        s_status = s_ero
                        e_status_prefix = e_ero_prefix 
                        isEroStatus = true
                    elseif s_sim then
                        s_status = s_sim
                        e_status_prefix = e_sim_prefix
                        isEroStatus = false
                    else
                        break -- 더 이상 EROSTATUS 또는 SIMULSTATUS 블록이 없음
                    end

                    statusBlocksFound = statusBlocksFound + 1
                    print("ONLINEMODULE: onOutput: Found " .. (isEroStatus and "EROSTATUS" or "SIMULSTATUS") .. " block #" .. statusBlocksFound)

                    local bracketLevel = 1
                    local e_status_suffix = e_status_prefix + 1
                    local foundClosingBracket = false
                    while e_status_suffix <= #currentLine do
                        local char = currentLine:sub(e_status_suffix, e_status_suffix)
                        if char == '[' then
                            bracketLevel = bracketLevel + 1
                        elseif char == ']' then
                            bracketLevel = bracketLevel - 1
                        end
                        if bracketLevel == 0 then
                            foundClosingBracket = true
                            break
                        end
                        e_status_suffix = e_status_suffix + 1
                    end

                    if foundClosingBracket then
                        local blockContent = string.sub(currentLine, e_status_prefix + 1, e_status_suffix - 1)
                        local currentBlockName = nil
                        
                        if isEroStatus then
                            local _, _, name = string.find(blockContent, "NAME:([^|]*)|")
                            currentBlockName = name
                        else
                            -- SIMULSTATUS의 경우 NAME 필드 추출
                            local pattern = "NAME:([^|]*)|"
                            local _, _, name = string.find(blockContent, pattern)
                            currentBlockName = name
                        end

                        local trimmedBlockName = nil
                        if currentBlockName then
                            trimmedBlockName = currentBlockName:match("^%s*(.-)%s*$")
                        end

                        local omSearchPosInContent = 1
                        local omTagsFoundInBlock = 0

                        while true do
                            local s_om_in_content, e_om_in_content, omIndexStr = string.find(blockContent, "<OM(%d+)>", omSearchPosInContent)
                            if not s_om_in_content then break end
                            omTagsFoundInBlock = omTagsFoundInBlock + 1
                            local omIndex = tonumber(omIndexStr)

                            if omIndex then
                                local content_offset = e_status_prefix 
                                local om_abs_start = content_offset + s_om_in_content
                                local om_abs_end = content_offset + e_om_in_content

                                local useExistingImage = false
                                local existingInlay = nil
                                
                                -- 이름이 존재하면 저장된 이미지가 있는지 확인
                                if trimmedBlockName and trimmedBlockName ~= "" then
                                    -- 메모리 캐시 먼저 확인
                                    existingInlay = characterImageCache[trimmedBlockName]
                                    
                                    -- 메모리 캐시에 없으면 상태 변수에서 확인
                                    if not existingInlay then
                                        existingInlay = getState(triggerId, trimmedBlockName) or "null"
                                        if existingInlay ~= "null" then
                                            -- 상태 변수에서 찾은 이미지를 메모리 캐시에 저장
                                            characterImageCache[trimmedBlockName] = existingInlay
                                            print("ONLINEMODULE: onOutput: Loaded existing inlay from state for " .. 
                                                  (isEroStatus and "EROSTATUS" or "SIMULSTATUS") .. 
                                                  " NAME: " .. trimmedBlockName)
                                        else
                                            existingInlay = nil
                                        end
                                    else
                                        print("ONLINEMODULE: onOutput: Using memory cached inlay for " .. 
                                              (isEroStatus and "EROSTATUS" or "SIMULSTATUS") .. 
                                              " NAME: " .. trimmedBlockName)
                                    end
                                    
                                    -- OMCACHE 설정에 따라 기존 이미지 사용 여부 결정
                                    if OMCACHE == "1" and existingInlay then
                                        useExistingImage = true
                                        print("ONLINEMODULE: onOutput: OMCACHE enabled, using existing image for " .. trimmedBlockName)
                                    end
                                end

                                if useExistingImage then
                                    -- 기존 이미지 사용
                                    table.insert(replacements, {
                                        start = om_abs_end,
                                        finish = om_abs_end,
                                        inlay = existingInlay
                                    })
                                else
                                    -- 새 이미지 생성
                                    local promptPattern, negPromptPattern, promptType, identifier
                                    if isEroStatus then
                                        promptPattern = "%[OMSTATUSPROMPT" .. omIndex .. ":([^%]]*)%]"
                                        negPromptPattern = "%[NEG_OMSTATUSPROMPT" .. omIndex .. ":([^%]]*)%]"
                                        promptType = "EROSTATUS"
                                    else
                                        promptPattern = "%[OMSIMULCARDPROMPT" .. omIndex .. ":([^%]]*)%]"
                                        negPromptPattern = "%[NEG_OMSIMULCARDPROMPT" .. omIndex .. ":([^%]]*)%]"
                                        promptType = "SIMULCARD"
                                    end
                                    identifier = trimmedBlockName

                                    local _, _, foundPrompt = string.find(currentLine, promptPattern)
                                    local _, _, foundNegPrompt = string.find(currentLine, negPromptPattern)

                                    if foundPrompt then
                                        local currentNegativePrompt = negativePrompt
                                        if foundNegPrompt then
                                            currentNegativePrompt = foundNegPrompt .. ", " .. currentNegativePrompt
                                        end

                                        local finalPrompt = artistPrompt .. ", " .. foundPrompt .. ", " .. qualityPrompt
                                        local inlay = generateImage(triggerId, finalPrompt, currentNegativePrompt):await()
                                        
                                        if inlay and type(inlay) == "string" and string.len(inlay) > 10 
                                           and not string.find(inlay, "fail", 1, true) 
                                           and not string.find(inlay, "error", 1, true)
                                           and not string.find(inlay, "실패", 1, true) then
                                            
                                            if identifier and identifier ~= "" then
                                                -- 생성된 이미지를 상태 변수와 메모리 캐시에 저장
                                                setState(triggerId, identifier, inlay)
                                                characterImageCache[identifier] = inlay
                                                print("ONLINEMODULE: onOutput: Stored new inlay for " .. promptType .. " NAME: " .. identifier)
                                            end

                                            table.insert(replacements, {
                                                start = om_abs_end,
                                                finish = om_abs_end,
                                                inlay = inlay
                                            })
                                        else
                                            ERR(triggerId, promptType, 2)
                                        end
                                    else
                                        ERR(triggerId, promptType, 0)
                                    end
                                end
                            end
                            omSearchPosInContent = e_om_in_content + 1
                        end

                        if omTagsFoundInBlock == 0 then
                            ERR(triggerId, isEroStatus and "EROSTATUS" or "SIMULCARD", 3)
                        end
                        searchPos = e_status_suffix + 1
                    else
                        ERR(triggerId, isEroStatus and "EROSTATUS" or "SIMULCARD", 1)
                        searchPos = e_status_prefix + 1 -- 다음 검색 위치 조정
                    end
                end

                if statusBlocksFound == 0 then
                    print("ONLINEMODULE: onOutput: No status blocks found in hybrid mode")
                else
                    if #replacements > 0 then
                        print("ONLINEMODULE: onOutput: Applying " .. #replacements .. " hybrid mode replacements")
                        table.sort(replacements, function(a, b) return a.start > b.start end)
                        for _, rep in ipairs(replacements) do
                            if rep.start > 0 and rep.finish >= rep.start and rep.finish <= #currentLine then
                                currentLine = string.sub(currentLine, 1, rep.start) .. rep.inlay .. string.sub(currentLine, rep.finish + 1)
                            end
                        end
                        lineModifiedInThisPass = true
                    end
                end
            elseif OMCARD == "4" and not skipOMCARD then
                -- 인레이만 출력할 때
                print("ONLINEMODULE: onOutput: OMCARD == 4 (Inlay only mode)")
                local searchPos = 1
                local inlayReplacements = {}
                local inlayBlocksFound = 0
                
                -- INLAY[<OM(INDEX)>] 블록 검색
                while true do
                    local s_inlay, e_inlay_prefix, blockContent = string.find(currentLine, "INLAY%[([^%]]*)%]", searchPos)
                    if not s_inlay then
                        print("ONLINEMODULE: onOutput: No more INLAY[...] blocks found starting from position " .. searchPos)
                        break
                    end
                    inlayBlocksFound = inlayBlocksFound + 1
                    print("ONLINEMODULE: onOutput: Found INLAY block #" .. inlayBlocksFound .. " starting at index " .. s_inlay)

                    local e_inlay = s_inlay + string.len("INLAY[" .. blockContent .. "]") - 1
                    local s_om, e_om, omIndexStr = string.find(blockContent, "<OM(%d+)>")
                    local omIndex = tonumber(omIndexStr)

                    if omIndex and s_om then
                        print("ONLINEMODULE: onOutput: Found OM index: " .. omIndex)
                        local promptPattern = "%[OMINLAYPROMPT" .. omIndex .. ":([^%]]*)%]"
                        local negPromptPattern = "%[NEG_OMINLAYPROMPT" .. omIndex .. ":([^%]]*)%]"
                        local _, _, foundInlayPrompt = string.find(currentLine, promptPattern)
                        local _, _, foundInlayNegPrompt = string.find(currentLine, negPromptPattern)

                        if foundInlayPrompt then
                            print("ONLINEMODULE: onOutput: Found prompt for OM" .. omIndex .. ": [" .. string.sub(foundInlayPrompt, 1, 50) .. "...]")
                            local currentNegativePromptInlay = negativePrompt
                            
                            if foundInlayNegPrompt then 
                                currentNegativePromptInlay = foundInlayNegPrompt .. ", " .. currentNegativePromptInlay
                            end

                            local finalPromptInlay = artistPrompt .. ", " .. foundInlayPrompt .. ", " .. qualityPrompt
                            local inlayImage = generateImage(triggerId, finalPromptInlay, currentNegativePromptInlay):await()
                            
                            if inlayImage and type(inlayImage) == "string" and string.len(inlayImage) > 10 and 
                               not string.find(inlayImage, "fail", 1, true) and 
                               not string.find(inlayImage, "error", 1, true) and 
                               not string.find(inlayImage, "실패", 1, true) then
                                
                                -- 원래 <OM> 태그는 그대로 두고 바로 뒤에 inlayImage를 삽입하는 방식으로 변경
                                local absStartPos = s_inlay + s_om - 1
                                local absEndPos = s_inlay + e_om - 1
                                
                                -- 삽입할 위치(태그 바로 뒤)와 삽입할 내용을 저장
                                table.insert(inlayReplacements, {
                                    pos = absEndPos,
                                    inlay = inlayImage
                                })

                                -- 인레이 식별자로 이미지만 저장
                                setState(triggerId, "INLAY_" .. omIndex, inlayImage)
                                
                                print("ONLINEMODULE: onOutput: Successfully processed INLAY block #" .. inlayBlocksFound)
                                lineModifiedInThisPass = true
                            else
                                ERR(triggerId, "INLAY", 2)
                                print("ONLINEMODULE: onOutput: Image generation failed for INLAY block #" .. inlayBlocksFound)
                            end
                        else
                            ERR(triggerId, "INLAY", 0)
                            print("ONLINEMODULE: onOutput: No prompt found for INLAY block #" .. inlayBlocksFound)
                        end
                    else
                        ERR(triggerId, "INLAY", 3)
                        print("ONLINEMODULE: onOutput: No OM index found in INLAY block #" .. inlayBlocksFound)
                    end
                    
                    searchPos = e_inlay + 1
                end

                -- 모든 교체작업 수행 (태그 뒤에 inlay 삽입)
                if #inlayReplacements > 0 then
                    table.sort(inlayReplacements, function(a, b) return a.pos > b.pos end)
                    for _, rep in ipairs(inlayReplacements) do
                        if rep.pos > 0 and rep.pos <= #currentLine then
                            currentLine = string.sub(currentLine, 1, rep.pos) .. rep.inlay .. string.sub(currentLine, rep.pos + 1)
                        end
                    end
                end
            end

            if OMSNS == "1" and not skipOMSNS then
                -- 트위터 블록 처리
                print("ONLINEMODULE: onOutput: OMSNS == 1")
                print("ONLINEMODULE: onOutput: Current line length:", #currentLine)
                
                local twitterPromptFindPattern = "%[OMTWITTERPROMPT:([^%]]*)%]"
                local twitterNegPromptFindPattern = "%[NEG_OMTWITTERPROMPT:([^%]]*)%]"
                local twitterPattern = "(TWITTER)%[NAME:([^|]*)|TNAME:([^|]*)|TID:([^|]*)|TPROFILE:([^|]*)|TWEET:([^|]*)|MEDIA:([^|]*)|HASH:([^|]*)|TIME:([^|]*)|VIEW:([^|]*)|REPLY:([^|]*)|RETWEET:([^|]*)|LIKES:([^|]*)|COMMENT:(.-)%]"
                
                print("ONLINEMODULE: onOutput: Looking for Twitter pattern...")
                local s_twitter, e_twitter, twCap1, twName, twTname, twTid, twTprofile, twTweet, twMedia, twHash, twTime, twView, twReply, twRetweet, twLikes, twCommentBlock = string.find(currentLine, twitterPattern)
                
                if s_twitter then
                    print("ONLINEMODULE: onOutput: Found Twitter block at positions", s_twitter, e_twitter)
                    print("ONLINEMODULE: onOutput: Twitter ID:", twTid)
                else
                    print("ONLINEMODULE: onOutput: No Twitter block found")
                end

                local twitterId = twTid
                local profileInlayToUse = nil

                if twitterId then
                    print("ONLINEMODULE: onOutput: Processing Twitter ID:", twitterId)
                    local existingProfileInlay = getState(triggerId, twitterId) or "null"
                    print("ONLINEMODULE: onOutput: Existing profile inlay:", existingProfileInlay)

                    if existingProfileInlay == "null" or not existingProfileInlay then
                        print("ONLINEMODULE: onOutput: Need to generate new profile image")
                        local profilePromptFindPattern = "%[OMTWITTERPROFILEPROMPT:([^%]]*)%]"
                        local profileNegPromptFindPattern = "%[NEG_OMTWITTERPROFILEPROMPT:([^%]]*)%]"
                        
                        local _, _, foundProfilePrompt = string.find(currentLine, profilePromptFindPattern)
                        local _, _, foundProfileNegPrompt = string.find(currentLine, profileNegPromptFindPattern)
                        
                        print("ONLINEMODULE: onOutput: Found profile prompt:", foundProfilePrompt ~= nil)
                        print("ONLINEMODULE: onOutput: Found profile neg prompt:", foundProfileNegPrompt ~= nil)

                        if foundProfilePrompt then
                            local finalPromptTwitterProfile = (artistPrompt or "") .. ", " .. (foundProfilePrompt or "") .. ", " .. (qualityPrompt or "")
                            local currentNegativePromptProfile = (negativePrompt or "")
                            
                            if foundProfileNegPrompt then 
                                currentNegativePromptProfile = foundProfileNegPrompt .. ", " .. currentNegativePromptProfile
                            end

                            print("ONLINEMODULE: onOutput: Generating profile image...")
                            local inlayProfile = generateImage(triggerId, finalPromptTwitterProfile, currentNegativePromptProfile):await()
                            
                            local isSuccessProfile = inlayProfile and type(inlayProfile) == "string" and 
                                                   string.len(inlayProfile) > 10 and 
                                                   not string.find(inlayProfile, "fail", 1, true) and 
                                                   not string.find(inlayProfile, "error", 1, true) and 
                                                   not string.find(inlayProfile, "실패", 1, true)

                            if isSuccessProfile then
                                print("ONLINEMODULE: onOutput: Profile image generation successful")
                                profileInlayToUse = inlayProfile
                                -- 프로필 이미지 저장
                                setState(triggerId, twitterId, profileInlayToUse)
                                setState(triggerId, "OMSNSPROFILETEMP", profileInlayToUse)
                            else
                                print("ONLINEMODULE: onOutput: Profile image generation failed")
                                ERR(triggerId, "TWITTERPROFILE", 2)
                            end
                        end
                    else
                        print("ONLINEMODULE: onOutput: Using existing profile inlay")
                        profileInlayToUse = existingProfileInlay
                        setState(triggerId, "OMSNSPROFILETEMP", profileInlayToUse)
                    end
                end

                print("ONLINEMODULE: onOutput: Looking for tweet prompt...")
                local _, _, foundTwitterPrompt = string.find(currentLine, twitterPromptFindPattern)
                print("ONLINEMODULE: onOutput: Tweet prompt found:", foundTwitterPrompt ~= nil)

                if foundTwitterPrompt and s_twitter then
                    print("ONLINEMODULE: onOutput: Processing tweet...")
                    local _, _, foundTwitterNegPrompt = string.find(currentLine, twitterNegPromptFindPattern)
                    local currentNegativePromptTwitter = negativePrompt
                    
                    if foundTwitterNegPrompt then 
                        currentNegativePromptTwitter = foundTwitterNegPrompt .. ", " .. currentNegativePromptTwitter
                    end

                    local finalPromptTwitterTweet = artistPrompt .. ", " .. foundTwitterPrompt .. ", " .. qualityPrompt
                    print("ONLINEMODULE: onOutput: Generating tweet image...")
                    local inlayTwitter = generateImage(triggerId, finalPromptTwitterTweet, currentNegativePromptTwitter):await()
                    
                    if inlayTwitter and type(inlayTwitter) == "string" and 
                       string.len(inlayTwitter) > 10 and 
                       not string.find(inlayTwitter, "fail", 1, true) and 
                       not string.find(inlayTwitter, "error", 1, true) and 
                       not string.find(inlayTwitter, "실패", 1, true) then
                        
                        print("ONLINEMODULE: onOutput: Tweet image generation successful")
                        local replacementTwitter = "TWITTER[NAME:" .. (twName or "") .. 
                            "|TNAME:" .. (twTname or "") .. 
                            "|TID:" .. (twTid or "") .. 
                            "|TPROFILE:" .. (profileInlayToUse or twTprofile or "") .. 
                            "|TWEET:" .. (twTweet or "") .. 
                            "|MEDIA:" .. "<OM>" .. inlayTwitter ..
                            "|HASH:" .. (twHash or "") .. 
                            "|TIME:" .. (twTime or "") .. 
                            "|VIEW:" .. (twView or "") .. 
                            "|REPLY:" .. (twReply or "") .. 
                            "|RETWEET:" .. (twRetweet or "") .. 
                            "|LIKES:" .. (twLikes or "") .. 
                            "|COMMENT:" .. (twCommentBlock or "") .. "]"

                        print("ONLINEMODULE: onOutput: Replacing content in line...")
                        currentLine = string.sub(currentLine, 1, s_twitter-1) .. replacementTwitter .. string.sub(currentLine, e_twitter + 1)
                        lineModifiedInThisPass = true
                    elseif profileInlayToUse then
                        print("ONLINEMODULE: onOutput: Using profile-only replacement")
                        local originalBlockReplacement = "TWITTER[NAME:" .. (twName or "") .. 
                            "|TNAME:" .. (twTname or "") .. 
                            "|TID:" .. (twTid or "") .. 
                            "|TPROFILE:" .. "<OM>" .. profileInlayToUse ..
                            "|TWEET:" .. (twTweet or "") .. 
                            "|MEDIA:" .. (twMedia or "") .. 
                            "|HASH:" .. (twHash or "") .. 
                            "|TIME:" .. (twTime or "") .. 
                            "|VIEW:" .. (twView or "") .. 
                            "|REPLY:" .. (twReply or "") .. 
                            "|RETWEET:" .. (twRetweet or "") .. 
                            "|LIKES:" .. (twLikes or "") .. 
                            "|COMMENT:" .. (twCommentBlock or "") .. "]"
                        currentLine = string.sub(currentLine, 1, s_twitter-1) .. originalBlockReplacement .. string.sub(currentLine, e_twitter + 1)
                        lineModifiedInThisPass = true
                    end
                elseif profileInlayToUse and s_twitter then
                    print("ONLINEMODULE: onOutput: Using profile-only replacement (no tweet prompt)")
                    local originalBlockReplacement = "TWITTER[NAME:" .. (twName or "") .. 
                        "|TNAME:" .. (twTname or "") .. 
                        "|TID:" .. (twTid or "") .. 
                        "|TPROFILE:" .. "<OM>" .. profileInlayToUse ..
                        "|TWEET:" .. (twTweet or "") .. 
                        "|MEDIA:" .. (twMedia or "") .. 
                        "|HASH:" .. (twHash or "") .. 
                        "|TIME:" .. (twTime or "") .. 
                        "|VIEW:" .. (twView or "") .. 
                        "|REPLY:" .. (twReply or "") .. 
                        "|RETWEET:" .. (twRetweet or "") .. 
                        "|LIKES:" .. (twLikes or "") .. 
                        "|COMMENT:" .. (twCommentBlock or "") .. "]"
                    currentLine = string.sub(currentLine, 1, s_twitter-1) .. originalBlockReplacement .. string.sub(currentLine, e_twitter + 1)
                    lineModifiedInThisPass = true
                end
            end

            if OMSNS == "2" and not skipOMSNS then
                -- 인스타그램 블록 처리
                print("ONLINEMODULE: onOutput: OMSNS == 2")
                print("ONLINEMODULE: onOutput: Current line length:", #currentLine)
                
                local instaPromptFindPattern = "%[OMINSTAPROMPT:([^%]]*)%]"
                local instaNegPromptFindPattern = "%[NEG_OMINSTAPROMPT:([^%]]*)%]"
                local instaPattern = "(INSTA)%[NAME:([^|]*)|IID:([^|]*)|IPROFILE:([^|]*)|POST:([^|]*)|MEDIA:([^|]*)|HASH:([^|]*)|TIME:([^|]*)|LIKES:([^|]*)|REPLY:([^|]*)|SHARE:([^%]]*)%]"
                
                print("ONLINEMODULE: onOutput: Looking for Instagram pattern...")
                local s_insta, e_insta, instaCap1, instaName, instaIid, instaIprofile, instaPost, instaMedia, instaHash, instaTime, instaLikes, instaReply, instaShare = string.find(currentLine, instaPattern)
                
                if s_insta then
                    print("ONLINEMODULE: onOutput: Found Instagram block at positions", s_insta, e_insta)
                    print("ONLINEMODULE: onOutput: Instagram ID:", instaIid)
                else
                    print("ONLINEMODULE: onOutput: No Instagram block found")
                end

                local instaId = instaIid
                local profileInlayToUse = nil

                if instaId then
                    print("ONLINEMODULE: onOutput: Processing Instagram ID:", instaId)
                    local existingProfileInlay = getState(triggerId, instaId) or "null"
                    print("ONLINEMODULE: onOutput: Existing profile inlay:", existingProfileInlay)

                    if existingProfileInlay == "null" or not existingProfileInlay then
                        print("ONLINEMODULE: onOutput: Need to generate new profile image")
                        local profilePromptFindPattern = "%[OMINSTAPROFILEPROMPT:([^%]]*)%]"
                        local profileNegPromptFindPattern = "%[NEG_OMINSTAPROFILEPROMPT:([^%]]*)%]"
                        
                        local _, _, foundProfilePrompt = string.find(currentLine, profilePromptFindPattern)
                        local _, _, foundProfileNegPrompt = string.find(currentLine, profileNegPromptFindPattern)
                        
                        print("ONLINEMODULE: onOutput: Found profile prompt:", foundProfilePrompt ~= nil)
                        print("ONLINEMODULE: onOutput: Found profile neg prompt:", foundProfileNegPrompt ~= nil)

                        if foundProfilePrompt then
                            local finalPromptInstaProfile = (artistPrompt or "") .. ", " .. (foundProfilePrompt or "") .. ", " .. (qualityPrompt or "")
                            local currentNegativePromptProfile = (negativePrompt or "")
                            
                            if foundProfileNegPrompt then 
                                currentNegativePromptProfile = foundProfileNegPrompt .. ", " .. currentNegativePromptProfile
                            end

                            print("ONLINEMODULE: onOutput: Generating profile image...")
                            local inlayProfile = generateImage(triggerId, finalPromptInstaProfile, currentNegativePromptProfile):await()
                            
                            local isSuccessProfile = inlayProfile and type(inlayProfile) == "string" and 
                                                   string.len(inlayProfile) > 10 and 
                                                   not string.find(inlayProfile, "fail", 1, true) and 
                                                   not string.find(inlayProfile, "error", 1, true) and 
                                                   not string.find(inlayProfile, "실패", 1, true)

                            if isSuccessProfile then
                                print("ONLINEMODULE: onOutput: Profile image generation successful")
                                profileInlayToUse = inlayProfile
                                -- 인스타그램 ID로 프로필 이미지 저장
                                setState(triggerId, instaId, profileInlayToUse)
                                setState(triggerId, "OMSNSPROFILETEMP", profileInlayToUse)
                            else
                                print("ONLINEMODULE: onOutput: Profile image generation failed")
                                ERR(triggerId, "INSTAPROFILE", 2)
                            end
                        end
                    else
                        print("ONLINEMODULE: onOutput: Using existing profile inlay")
                        profileInlayToUse = existingProfileInlay
                        setState(triggerId, "OMSNSPROFILETEMP", profileInlayToUse)
                    end
                end

                print("ONLINEMODULE: onOutput: Looking for post prompt...")
                local _, _, foundInstaPrompt = string.find(currentLine, instaPromptFindPattern)
                print("ONLINEMODULE: onOutput: Post prompt found:", foundInstaPrompt ~= nil)

                if foundInstaPrompt and s_insta then
                    print("ONLINEMODULE: onOutput: Processing post...")
                    local _, _, foundInstaNegPrompt = string.find(currentLine, instaNegPromptFindPattern)
                    local currentNegativePromptInsta = negativePrompt
                    
                    if foundInstaNegPrompt then 
                        currentNegativePromptInsta = foundInstaNegPrompt .. ", " .. currentNegativePromptInsta
                    end

                    local finalPromptInstaPost = artistPrompt .. ", " .. foundInstaPrompt .. ", " .. qualityPrompt
                    print("ONLINEMODULE: onOutput: Generating post image...")
                    local inlayInsta = generateImage(triggerId, finalPromptInstaPost, currentNegativePromptInsta):await()
                    
                    if inlayInsta and type(inlayInsta) == "string" and 
                       string.len(inlayInsta) > 10 and 
                       not string.find(inlayInsta, "fail", 1, true) and 
                       not string.find(inlayInsta, "error", 1, true) and 
                       not string.find(inlayInsta, "실패", 1, true) then
                        
                        print("ONLINEMODULE: onOutput: Post image generation successful")
                        local replacementInsta = "INSTA[NAME:" .. (instaName or "") .. 
                            "|IID:" .. (instaIid or "") .. 
                            "|IPROFILE:" .. (profileInlayToUse or instaIprofile or "") .. 
                            "|POST:" .. (instaPost or "") .. 
                            "|MEDIA:" .. "<OM>" .. inlayInsta ..
                            "|HASH:" .. (instaHash or "") .. 
                            "|TIME:" .. (instaTime or "") .. 
                            "|LIKES:" .. (instaLikes or "") .. 
                            "|REPLY:" .. (instaReply or "") .. 
                            "|SHARE:" .. (instaShare or "") .. "]"

                        print("ONLINEMODULE: onOutput: Replacing content in line...")
                        currentLine = string.sub(currentLine, 1, s_insta-1) .. replacementInsta .. string.sub(currentLine, e_insta + 1)
                        lineModifiedInThisPass = true
                    elseif profileInlayToUse then
                        print("ONLINEMODULE: onOutput: Using profile-only replacement")
                        local originalBlockReplacement = "INSTA[NAME:" .. (instaName or "") .. 
                            "|IID:" .. (instaIid or "") .. 
                            "|IPROFILE:" .. "<OM>" .. profileInlayToUse ..
                            "|POST:" .. (instaPost or "") .. 
                            "|MEDIA:" .. (instaMedia or "") .. 
                            "|HASH:" .. (instaHash or "") .. 
                            "|TIME:" .. (instaTime or "") .. 
                            "|LIKES:" .. (instaLikes or "") .. 
                            "|REPLY:" .. (instaReply or "") .. 
                            "|SHARE:" .. (instaShare or "") .. "]"
                        currentLine = string.sub(currentLine, 1, s_insta-1) .. originalBlockReplacement .. string.sub(currentLine, e_insta + 1)
                        lineModifiedInThisPass = true
                    end
                elseif profileInlayToUse and s_insta then
                    print("ONLINEMODULE: onOutput: Using profile-only replacement (no post prompt)")
                    local originalBlockReplacement = "INSTA[NAME:" .. (instaName or "") .. 
                        "|IID:" .. (instaIid or "") .. 
                        "|IPROFILE:" .. "<OM>" .. profileInlayToUse ..
                        "|POST:" .. (instaPost or "") .. 
                        "|MEDIA:" .. (instaMedia or "") .. 
                        "|HASH:" .. (instaHash or "") .. 
                        "|TIME:" .. (instaTime or "") .. 
                        "|LIKES:" .. (instaLikes or "") .. 
                        "|REPLY:" .. (instaReply or "") .. 
                        "|SHARE:" .. (instaShare or "") .. "]"
                    currentLine = string.sub(currentLine, 1, s_insta-1) .. originalBlockReplacement .. string.sub(currentLine, e_insta + 1)
                    lineModifiedInThisPass = true
                end
            end

            if OMSNS == "3" and not skipOMSNS then
                -- 하이브리드 모드 블록 처리
                print("ONLINEMODULE: onOutput: OMSNS == 3 (Hybrid mode)")
                print("ONLINEMODULE: onOutput: Current line length:", #currentLine)

                -- 트위터 블록부터
                local twitterPromptFindPattern = "%[OMTWITTERPROMPT:([^%]]*)%]"
                local twitterNegPromptFindPattern = "%[NEG_OMTWITTERPROMPT:([^%]]*)%]"
                local twitterPattern = "(TWITTER)%[NAME:([^|]*)|TNAME:([^|]*)|TID:([^|]*)|TPROFILE:([^|]*)|TWEET:([^|]*)|MEDIA:([^|]*)|HASH:([^|]*)|TIME:([^|]*)|VIEW:([^|]*)|REPLY:([^|]*)|RETWEET:([^|]*)|LIKES:([^|]*)|COMMENT:(.-)%]"

                local _, _, foundTwitterPrompt = string.find(currentLine, twitterPromptFindPattern)
                local s_twitter, e_twitter, twCap1, twName, twTname, twTid, twTprofile, twTweet, twMedia, twHash, twTime, twView, twReply, twRetweet, twLikes, twCommentBlock = string.find(currentLine, twitterPattern)
                
                if s_twitter then  -- s_twitter가 발견되면 프로필 처리 시작
                    local twitterId = twTid
                    local profileInlayToUse = nil

                    if twitterId then
                        local existingProfileInlay = getState(triggerId, twitterId) or "null" 
                        if existingProfileInlay == "null" or not existingProfileInlay then
                            local profilePromptFindPattern = "%[OMTWITTERPROFILEPROMPT:([^%]]*)%]"
                            local profileNegPromptFindPattern = "%[NEG_OMTWITTERPROFILEPROMPT:([^%]]*)%]"
                            local _, _, foundProfilePrompt = string.find(currentLine, profilePromptFindPattern)
                            local _, _, foundProfileNegPrompt = string.find(currentLine, profileNegPromptFindPattern)

                            if foundProfilePrompt then
                                local finalPromptTwitterProfile = artistPrompt .. ", " .. foundProfilePrompt .. ", " .. qualityPrompt
                                local currentNegativePromptProfile = negativePrompt
                                
                                if foundProfileNegPrompt then 
                                    currentNegativePromptProfile = foundProfileNegPrompt .. ", " .. currentNegativePromptProfile
                                end

                                local inlayProfile = generateImage(triggerId, finalPromptTwitterProfile, currentNegativePromptProfile):await()
                                
                                if inlayProfile and type(inlayProfile) == "string" and string.len(inlayProfile) > 10 
                                   and not string.find(inlayProfile, "fail", 1, true) 
                                   and not string.find(inlayProfile, "error", 1, true)
                                   and not string.find(inlayProfile, "실패", 1, true) then
                                    
                                    profileInlayToUse = inlayProfile
                                    -- 트위터 ID로 프로필 이미지만 저장
                                    setState(triggerId, twitterId, profileInlayToUse)
                                    setState(triggerId, "OMSNSPROFILETEMP", profileInlayToUse)
                                else
                                    ERR(triggerId, "TWITTERPROFILE", 2)
                                end
                            end
                        else
                            profileInlayToUse = existingProfileInlay
                            setState(triggerId, "OMSNSPROFILETEMP", profileInlayToUse)
                        end
                    end

                    -- 트윗 처리는 foundTwitterPrompt가 있을 때만
                    if foundTwitterPrompt then
                        local _, _, foundTwitterNegPrompt = string.find(currentLine, twitterNegPromptFindPattern)
                        local currentNegativePromptTwitter = negativePrompt
                        
                        if foundTwitterNegPrompt then 
                            currentNegativePromptTwitter = foundTwitterNegPrompt .. ", " .. currentNegativePromptTwitter
                        end

                        local finalPromptTwitterTweet = artistPrompt .. ", " .. foundTwitterPrompt .. ", " .. qualityPrompt
                        local inlayTwitter = generateImage(triggerId, finalPromptTwitterTweet, currentNegativePromptTwitter):await()
                        
                        if inlayTwitter and type(inlayTwitter) == "string" and string.len(inlayTwitter) > 10 
                           and not string.find(inlayTwitter, "fail", 1, true) 
                           and not string.find(inlayTwitter, "error", 1, true)
                           and not string.find(inlayTwitter, "실패", 1, true) then
                            
                            local replacementTwitter = string.format(
                                "TWITTER[NAME:%s|TNAME:%s|TID:%s|TPROFILE:%s|TWEET:%s|MEDIA:%s|HASH:%s|TIME:%s|VIEW:%s|REPLY:%s|RETWEET:%s|LIKES:%s|COMMENT:%s]",
                                twName or "", twTname or "", twTid or "",
                                profileInlayToUse and "<OM>" .. profileInlayToUse or (twTprofile or ""),
                                twTweet or "", "<OM>" .. inlayTwitter,
                                twHash or "", twTime or "", twView or "",
                                twReply or "", twRetweet or "", twLikes or "",
                                twCommentBlock or ""
                            )
                            currentLine = string.sub(currentLine, 1, s_twitter-1) .. replacementTwitter .. string.sub(currentLine, e_twitter + 1)
                            lineModifiedInThisPass = true
                        end
                    elseif profileInlayToUse then
                        -- 프로필만 있을 때의 교체
                        local replacementTwitter = string.format(
                            "TWITTER[NAME:%s|TNAME:%s|TID:%s|TPROFILE:%s|TWEET:%s|MEDIA:%s|HASH:%s|TIME:%s|VIEW:%s|REPLY:%s|RETWEET:%s|LIKES:%s|COMMENT:%s]",
                            twName or "", twTname or "", twTid or "",
                            "<OM>" .. profileInlayToUse,
                            twTweet or "", twMedia or "",
                            twHash or "", twTime or "", twView or "",
                            twReply or "", twRetweet or "", twLikes or "",
                            twCommentBlock or ""
                        )
                        currentLine = string.sub(currentLine, 1, s_twitter-1) .. replacementTwitter .. string.sub(currentLine, e_twitter + 1)
                        lineModifiedInThisPass = true
                    end
                end

                -- 그 다음은 인스타
                local instaPromptFindPattern = "%[OMINSTAPROMPT:([^%]]*)%]"
                local instaNegPromptFindPattern = "%[NEG_OMINSTAPROMPT:([^%]]*)%]"
                local instaPattern = "(INSTA)%[NAME:([^|]*)|IID:([^|]*)|IPROFILE:([^|]*)|POST:([^|]*)|MEDIA:([^|]*)|HASH:([^|]*)|TIME:([^|]*)|LIKES:([^|]*)|REPLY:([^|]*)|SHARE:([^%]]*)%]"

                local _, _, foundInstaPrompt = string.find(currentLine, instaPromptFindPattern)
                local s_insta, e_insta, instaCap1, instaName, instaIid, instaIprofile, instaPost, instaMedia, instaHash, instaTime, instaLikes, instaReply, instaShare = string.find(currentLine, instaPattern)

                if foundInstaPrompt and s_insta then
                    -- 인스타도 똑같이
                    local instaId = instaIid
                    local profileInlayToUse = nil
                    local _, _, foundInstaNegPrompt = string.find(currentLine, instaNegPromptFindPattern)

                    -- 인스타 프로필 생성 및 재사용 로직
                    if instaId then
                        local existingProfileInlay = getState(triggerId, instaId) or "null"
                        if existingProfileInlay == "null" or not existingProfileInlay then
                            local profilePromptFindPattern = "%[OMINSTAPROFILEPROMPT:([^%]]*)%]"
                            local profileNegPromptFindPattern = "%[NEG_OMINSTAPROFILEPROMPT:([^%]]*)%]"
                            local _, _, foundProfilePrompt = string.find(currentLine, profilePromptFindPattern)
                            local _, _, foundProfileNegPrompt = string.find(currentLine, profileNegPromptFindPattern)

                            if foundProfilePrompt then
                                local finalPromptInstaProfile = artistPrompt .. ", " .. foundProfilePrompt .. ", " .. qualityPrompt
                                local currentNegativePromptProfile = negativePrompt
                                
                                if foundProfileNegPrompt then 
                                    currentNegativePromptProfile = foundProfileNegPrompt .. ", " .. currentNegativePromptProfile
                                end

                                local inlayProfile = generateImage(triggerId, finalPromptInstaProfile, currentNegativePromptProfile):await()
                                
                                if inlayProfile and type(inlayProfile) == "string" and string.len(inlayProfile) > 10
                                   and not string.find(inlayProfile, "fail", 1, true)
                                   and not string.find(inlayProfile, "error", 1, true) 
                                   and not string.find(inlayProfile, "실패", 1, true) then
                                    
                                    profileInlayToUse = inlayProfile
                                    -- 인스타그램 ID로 프로필 이미지만 저장
                                    setState(triggerId, instaId, profileInlayToUse)
                                    setState(triggerId, "OMSNSPROFILETEMP", profileInlayToUse)
                                else
                                    ERR(triggerId, "INSTAPROFILE", 2)
                                end
                            end
                        else
                            profileInlayToUse = existingProfileInlay
                            setState(triggerId, "OMSNSPROFILETEMP", profileInlayToUse)
                        end
                    end

                    -- 인스타 포스트 이미지 생성
                    local currentNegativePromptInsta = negativePrompt
                    
                    if foundInstaNegPrompt then 
                        currentNegativePromptInsta = foundInstaNegPrompt .. ", " .. currentNegativePromptInsta
                    end

                    local finalPromptInstaPost = artistPrompt .. ", " .. foundInstaPrompt .. ", " .. qualityPrompt
                    local inlayInsta = generateImage(triggerId, finalPromptInstaPost, currentNegativePromptInsta):await()
                    
                    if inlayInsta and type(inlayInsta) == "string" and string.len(inlayInsta) > 10
                       and not string.find(inlayInsta, "fail", 1, true)
                       and not string.find(inlayInsta, "error", 1, true)
                       and not string.find(inlayInsta, "실패", 1, true) then
                        
                        local replacementInsta = string.format(
                            "INSTA[NAME:%s|IID:%s|IPROFILE:%s|POST:%s|MEDIA:%s|HASH:%s|TIME:%s|LIKES:%s|REPLY:%s|SHARE:%s]",
                            instaName or "", instaIid or "",
                            profileInlayToUse and "<OM>" .. profileInlayToUse or (instaIprofile or ""),
                            instaPost or "", "<OM>" .. inlayInsta,
                            instaHash or "", instaTime or "",
                            instaLikes or "", instaReply or "", instaShare or ""
                        )
                        currentLine = string.sub(currentLine, 1, s_insta-1) .. replacementInsta .. string.sub(currentLine, e_insta + 1)
                        lineModifiedInThisPass = true
                    elseif profileInlayToUse then
                        local replacementInsta = string.format(
                            "INSTA[NAME:%s|IID:%s|IPROFILE:%s|POST:%s|MEDIA:%s|HASH:%s|TIME:%s|LIKES:%s|REPLY:%s|SHARE:%s]",
                            instaName or "", instaIid or "",
                            "<OM>" .. profileInlayToUse,
                            instaPost or "", instaMedia or "",
                            instaHash or "", instaTime or "",
                            instaLikes or "", instaReply or "", instaShare or ""
                        )
                        currentLine = string.sub(currentLine, 1, s_insta-1) .. replacementInsta .. string.sub(currentLine, e_insta + 1)
                        lineModifiedInThisPass = true
                    end
                end
            end

            if OMCOMMUNITY == "1" and not skipOMCOMMUNITY then
                print("ONLINEMODULE: onOutput: OMCOMMUNITY == 1")
                local searchPos = 1
                local dcReplacements = {}

                local function findLastPatternBefore(str, pattern, beforePos)
                    local last_s, last_e, last_cap1 = nil, nil, nil
                    local searchPosFn = 1
                    while true do
                        local s_fn, e_fn, cap1_fn = string.find(str, pattern, searchPosFn)
                        if not s_fn or s_fn >= beforePos then
                            break
                        end
                        last_s, last_e, last_cap1 = s_fn, e_fn, cap1_fn
                        searchPosFn = e_fn + 1
                    end
                    return last_s, last_e, last_cap1
                end

                while true do
                    local s_dc, e_dc_prefix = string.find(currentLine, "DC%[", searchPos)
                    if not s_dc then break end
                    local bracketLevel = 1
                    local e_dc_suffix = e_dc_prefix + 1
                    local foundClosingBracket = false
                    while e_dc_suffix <= #currentLine do
                        local char = currentLine:sub(e_dc_suffix, e_dc_suffix)
                        if char == '[' then
                            bracketLevel = bracketLevel + 1
                        elseif char == ']' then
                            bracketLevel = bracketLevel - 1
                        end
                        if bracketLevel == 0 then foundClosingBracket = true; break end
                        e_dc_suffix = e_dc_suffix + 1
                    end
                    if foundClosingBracket then
                        local dcContent = string.sub(currentLine, e_dc_prefix + 1, e_dc_suffix - 1)
                        local omSearchPosInContent = 1
                        while true do
                            local s_om_in_content, e_om_in_content, omIndexStr = string.find(dcContent, "<OM(%d+)>", omSearchPosInContent)
                            if not s_om_in_content then break end
                            local omIndex = tonumber(omIndexStr)

                            local content_start_abs = e_dc_prefix + 1
                            local om_abs_start = content_start_abs + s_om_in_content - 1
                            local om_abs_end = content_start_abs + e_om_in_content - 1

                            local postId = nil
                            local postIdPattern = "PID:([^|]*)"
                            local s_post, e_post, capturedPostId = findLastPatternBefore(dcContent, postIdPattern, s_om_in_content)
                            if not capturedPostId then
                                local s_post2, e_post2, capturedPostId2 = findLastPatternBefore(dcContent, "PN:([^|]*)", s_om_in_content)
                                capturedPostId = capturedPostId2
                            end
                            if capturedPostId and type(capturedPostId) == "string" then
                                postId = capturedPostId:match("^%s*(.-)%s*$")
                                if postId == "" then postId = nil end
                            end

                            if omIndex and postId then
                                local dcPromptPattern = "%[OMDCPROMPT" .. omIndex .. ":([^%]]*)%]"
                                local negDcPromptPattern = "%[NEG_OMDCPROMPT" .. omIndex .. ":([^%]]*)%]"
                                local _, _, foundDcPrompt = string.find(currentLine, dcPromptPattern)
                                local _, _, foundNegDcPrompt = string.find(currentLine, negDcPromptPattern)
                                local currentNegativePromptDc = negativePrompt
                                
                                if foundNegDcPrompt then 
                                    currentNegativePromptDc = foundNegDcPrompt .. ", " .. currentNegativePromptDc
                                end
                                
                                if foundDcPrompt then
                                    local finalPromptDc = artistPrompt .. ", " .. foundDcPrompt .. ", " .. qualityPrompt
                                    local successCall, inlayDc = pcall(function() return generateImage(triggerId, finalPromptDc, currentNegativePromptDc):await() end)
                                    local isSuccessDc = successCall and (inlayDc ~= nil) and (type(inlayDc) == "string") and (string.len(inlayDc) > 10) and not string.find(inlayDc, "fail", 1, true) and not string.find(inlayDc, "error", 1, true) and not string.find(inlayDc, "실패", 1, true)
                                    
                                    if isSuccessDc then
                                        table.insert(dcReplacements, {
                                            start = om_abs_start,
                                            finish = om_abs_end,
                                            inlay = "<OM" .. omIndex .. ">" .. inlayDc
                                        })
                                    else
                                        ERR(triggerId, "DCINSIDE", 2)
                                        print("ONLINEMODULE: onOutput: ERROR - DC image generation failed...")
                                    end
                                else
                                    ERR(triggerId, "DCINSIDE", 0)
                                    print("ONLINEMODULE: onOutput: WARN - Found <OM...> tag but no corresponding prompt tag...")
                                end
                            else
                                ERR(triggerId, "DCINSIDE", 3)
                                if not postId then print("ONLINEMODULE: onOutput: WARN - Could not determine Post ID for <OM" .. (omIndex or "??") .. "> tag at position " .. om_abs_start .. ". Skipping.") end
                            end
                            omSearchPosInContent = e_om_in_content + 1
                        end
                        searchPos = e_dc_suffix + 1
                    else
                        searchPos = e_dc_prefix + 1
                    end
                end
                
                if #dcReplacements > 0 then
                    table.sort(dcReplacements, function(a, b) return a.start > b.start end)
                    for i, rep in ipairs(dcReplacements) do
                        if rep.start > 0 and rep.finish >= rep.start and rep.finish <= #currentLine then
                            currentLine = string.sub(currentLine, 1, rep.start - 1) .. rep.inlay .. string.sub(currentLine, rep.finish + 1)
                        else
                            print("ONLINEMODULE: onOutput: WARN - Invalid range for replacement: " .. rep.start .. " to " .. rep.finish)
                        end
                    end
                    lineModifiedInThisPass = true
                end
            end
            
            if OMMESSENGER == "1" and not skipOMMESSENGER then
                print("ONLINEMODULE: onOutput: OMMESSENGER == 1 (KAKAO) processing...")
                local kakaoPromptFindPattern = "%[OMKAKAOPROMPT:([^%]]*)%]"
                local kakaoNegPromptFindPattern = "%[NEG_OMKAKAOPROMPT:([^%]]*)%]"
                local kakaoPattern = "(KAKAO)%[(<OM>)%|([^%]]*)%]"
                local _, _, foundKakaoPrompt = string.find(currentLine, kakaoPromptFindPattern)
                local s_kakao, e_kakao, cap1, cap2, cap3 = string.find(currentLine, kakaoPattern)
                print("Found Prefix: " .. cap1 .. " Found OM Value: " .. cap2 .. " Found Suffix: " .. cap3)
       
                if foundKakaoPrompt and s_kakao then
                    print("ONLINEMODULE: onOutput: Found KAKAO block and prompt. Generating image...")
                    local _, _, foundKakaoNegPrompt = string.find(currentLine, kakaoNegPromptFindPattern)
                    local currentNegativePromptKakao = negativePrompt or ""
                    
                    if foundKakaoNegPrompt then 
                        currentNegativePromptKakao = foundKakaoNegPrompt .. ", " .. currentNegativePromptKakao
                    end
                    
                    local finalPromptKakao = (artistPrompt or "") .. ", " .. foundKakaoPrompt .. ", " .. (qualityPrompt or "")
        
                    local successCall, inlayKakao = pcall(function() return generateImage(triggerId, finalPromptKakao, currentNegativePromptKakao):await() end)
                    local isSuccessKakao = successCall and inlayKakao and type(inlayKakao) == "string" and string.len(inlayKakao) > 10 and not string.find(inlayKakao, "fail", 1, true) and not string.find(inlayKakao, "error", 1, true) and not string.find(inlayKakao, "실패", 1, true)
        
                    if isSuccessKakao then
                        print("ONLINEMODULE: onOutput: KAKAO image generated successfully.")
                        local replacementKakao = "KAKAO[" .. inlayKakao .. "|" .. cap3 .. "]"
                        currentLine = string.sub(currentLine, 1, s_kakao-1) .. replacementKakao .. string.sub(currentLine, e_kakao + 1)
                        lineModifiedInThisPass = true
                    else
                        ERR(triggerId, "KAKAOTALK", 2)
                        print("ONLINEMODULE: onOutput: KAKAO image generation FAILED. Error/Result: " .. tostring(inlayKakao))
                    end
                end
            end
            
        else
            print("ONLINEMODULE: onOutput: Last message data is not in the expected format.")
        end
    end

    print("ONLINEMODULE: onOutput: Always applying setChat to last message after prompt cleanup.")
    setChat(triggerId, lastIndex - 1, currentLine)
    print("ONLINEMODULE: onOutput: setChat call complete.")
end)

onButtonClick = async(function(triggerId, data)
    print("triggerId is " .. triggerId)
    print("ONLINEMODULE: Received data in onButtonClick:", data)
    print("ONLINEMODULE: Type of received data:", type(data))

    local action = nil
    local identifierFromData = nil
    local identifier = nil
    local index = nil

    if type(data) ~= "string" then
        print("ONLINEMODULE: ERROR - Expected string data from risu-btn, but received type: " .. type(data))
        return
    end

    -- Updated pattern to also extract the index field
    action, identifierFromData, index = data:match('^{%s*"action"%s*:%s*"([^"]+)"%s*,%s*"identifier"%s*:%s*"([^"]+)"%s*,%s*"index"%s*:%s*"([^"]*)"')

    if not action or not identifierFromData then
        print("ONLINEMODULE: ERROR - Could not parse action and identifier from JSON-like string:", data)
        return
    end

    identifier = identifierFromData:match("^%s*(.-)%s*$")
    print("ONLINEMODULE: Parsed action: [" .. action .. "] Original identifier: [" .. identifierFromData .. "] Trimmed identifier: [" .. identifier .. "] Index: [" .. (index or "nil") .. "]")

    if identifier == nil or identifier == "" then
         print("ONLINEMODULE: ERROR - Identifier part is invalid after trimming: [" .. tostring(identifierFromData) .. "]")
         return
    end

    local rerollType = nil
    local chatVarKeyForInlay = ""
    local specificPromptKey = ""
    local specificNegPromptKey = ""

    print(action .. " currently triggered!")
    print("ONLINEMODULE: onButtonClick: Processing action " .. action .. " for identifier: [" .. identifier .. "]")

    local startPrefix = nil
    local mainPrompt = nil
    local mainNegPrompt = nil
    local promptFlags = nil
    local profileFlags = nil

    if action == "EROSTATUS_REROLL" then
        startPrefix = "EROSTATUS"
        rerollType = "EROSTATUS"
        mainPrompt = "OMSTATUSPROMPT"
        mainNegPrompt = "NEG_OMSTATUSPROMPT"
        profileFlags = 0
        promptFlags = 1
        chatVarKeyForInlay = identifier
    elseif action == "SIMCARD_REROLL" then
        startPrefix = "SIMULSTATUS"
        rerollType = "SIMULATIONCARD"
        mainPrompt = "OMSIMULCARDPROMPT"
        mainNegPrompt = "NEG_OMSIMULCARDPROMPT"
        profileFlags = 0
        promptFlags = 1
        chatVarKeyForInlay = identifier
    elseif action == "INLAY_REROLL" then
        startPrefix = "INLAY"
        rerollType = "INLAY"
        mainPrompt = "OMINLAYPROMPT"
        mainNegPrompt = "NEG_OMINLAYPROMPT"
        profileFlags = 0
        promptFlags = 1
        chatVarKeyForInlay = identifier
    elseif action == "TWEET_REROLL" then
        startPrefix = "TWITTER"
        rerollType = "TWEET"
        mainPrompt = "OMTWITTERPROMPT"
        mainNegPrompt = "NEG_OMTWITTERPROMPT"
        profileFlags = 1
        promptFlags = 0
        chatVarKeyForInlay = identifier .. "_TWEET"
    elseif action == "TWITTER_PROFILE_REROLL" then
        startPrefix = "TWITTER"
        rerollType = "TWITTER_PROFILE"
        mainPrompt = "OMTWITTERPROFILEPROMPT"
        mainNegPrompt = "NEG_OMTWITTERPROFILEPROMPT"
        profileFlags = 0
        promptFlags = 0
        chatVarKeyForInlay = identifier
    elseif action == "INSTA_REROLL" then
        startPrefix = "INSTA"
        rerollType = "INSTAGRAM"
        mainPrompt = "OMINSTAPROMPT"
        mainNegPrompt = "NEG_OMINSTAPROMPT"
        profileFlags = 1
        promptFlags = 0
        chatVarKeyForInlay = identifier
    elseif action == "INSTA_PROFILE_REROLL" then
        startPrefix = "INSTA"
        rerollType = "INSTAGRAM_PROFILE"
        mainPrompt = "OMINSTAPROFILEPROMPT"
        mainNegPrompt = "NEG_OMINSTAPROFILEPROMPT"
        profileFlags = 0
        promptFlags = 0
        chatVarKeyForInlay = identifier
    elseif action == "DC_REROLL" then
        startPrefix = "DC"
        rerollType = "DC"
        mainPrompt = "OMDCPROMPT"
        mainNegPrompt = "NEG_OMDCPROMPT"
        profileFlags = 0
        promptFlags = 1
        chatVarKeyForInlay = "DC_" .. identifier
    elseif action == "KAKAO_REROLL" then
        startPrefix = "KAKAO"
        rerollType = "KAKAO"
        mainPrompt = "OMKAKAOPROMPT"
        mainNegPrompt = "NEG_OMKAKAOPROMPT"
        profileFlags = 0
        promptFlags = 0
        chatVarKeyForInlay = identifier
    else
        print("ONLINEMODULE: Unknown button action received: " .. tostring(action))
        return
    end

    local OMPRESETPROMPT = getGlobalVar(triggerId, "toggle_OMPRESETPROMPT") or "0"
    local artistPrompt = ""
    local qualityPrompt = ""
    local negativePrompt = ""

    if OMPRESETPROMPT == "0" then
        artistPrompt = getGlobalVar(triggerId, "toggle_OMARTISTPROMPT") or ""
        qualityPrompt = getGlobalVar(triggerId, "toggle_OMQUALITYPROMPT") or ""
        negativePrompt = getGlobalVar(triggerId, "toggle_OMNEGPROMPT") or ""
    elseif OMPRESETPROMPT == "1" then
        artistPrompt = "1.33::artist:Goldcan9 ::, 1.1::artist:sakurai norio,artist: torino,year 2023 ::, 0.5::artist: eonsang, artist: gomzi, artist:shiba ::"
        qualityPrompt = "smooth lines, excellent color, depth of field, shiny skin, best quality, amazing quality, very aesthetic, highres, incredibly absurdres"
        negativePrompt = "{{{worst quality}}}, {{{bad quality}}}, reference, unfinished, unclear fingertips, twist, Squiggly, Grumpy, incomplete, {{Imperfect Fingers}}, Cheesy, {{very displeasing}}, {{mess}}, {{Approximate}}, {{monochrome}}, {{greyscale}}, 3D"
    elseif OMPRESETPROMPT == "2" then
        artistPrompt = "1.3::artist:tianliang duohe fangdongye ::,1.2::artist:shuz ::, 0.7::artist:wlop ::, 1.0::artist:kase daiki ::,0.8::artist:ningen mame ::,0.8::artist:voruvoru ::,0.8::artist:tomose_shunsaku ::,0.7::artist:sweetonedollar ::,0.7::artist:chobi (penguin paradise) ::,0.8::artist:rimo ::,{year 2024, year 2025}"
        qualityPrompt = "Detail Shading, {{{{{{{{{{amazing quality}}}}}}}}}}, very aesthetic, highres, incredibly absurdres"
        negativePrompt = "dark lighting,{{{blurry}}},{{{{{{{{worst quality, bad quality, japanese text}}}}}}}}, {{{{bad hands, closed eyes}}}}, {{{bad eyes, bad pupils, bad glabella}}}, {{{undetailed eyes}}}, multiple views, error, extra digit, fewer digits, jpeg artifacts, signature, watermark, username, reference, {{unfinished}}, {{unclear fingertips}}, {{twist}}, {{squiggly}}, {{grumpy}}, {{incomplete}}, {{imperfect fingers}}, disorganized colors, cheesy, {{very displeasing}}, {{mess}}, {{approximate}}, {{sloppiness}}"
    elseif OMPRESETPROMPT == "3" then
        artistPrompt = "artist:rella, artist:ixy, artist:gomzi, artist:tsunako, artist:momoko (momopoco)"
        qualityPrompt = "illustration, best quality, amazing quality, very aesthetic, highres, incredibly absurdres, 1::perfect_eyes::, 1::beautiful detail eyes::, incredibly absurdres, finely detailed beautiful eyes"
        negativePrompt = "3D, blurry, lowres, error, film grain, scan artifacts, worst quality, bad quality, jpeg artifacts, very displeasing, chromatic aberration, multiple views, logo, too many watermarks, white blank page, blank page, 1.2::worst quality::, 1.2::bad quality::, 1.2::Imperfect Fingers::, 1.1::Imperfect Fingers::, 1.2::Approximate::, 1.1::very displeasing::, 1.1::mess::, 1::unfinished::, 1::unclear fingertips::, 1::twist::, 1::Squiggly::, 1::Grumpy::, 1::incomplete::, 1::Cheesy::, 1.3::mascot::, 1.3::puppet::, 1.3::character doll::, 1.3::pet::, 1.3::cake::, 1.3::stuffed toy::, 1::reference::, 1.1::multiple views::, 1.1::monochrome::, 1.1::greyscale::, 1.1::sketch::, 1.1::flat color::, 1.1::3D::, 1::aged down::, 1.:bestiality::, 1::furry::, 1::crowd::, 1::animals::, 1::pastie::, 1::maebari::, 1::eyeball::, 1::slit pupils::, 1::bright pupils::"
    elseif OMPRESETPROMPT == "4" then
        artistPrompt = "0.8::artist:namako daibakuhatsu ::, 0.5::artist:tianliang duohe fangdongye ::, 0.4::channel(caststation) ::, 0.7::jtveemo ::, 1.3::pixel art,  8-bit, pixel size: 4 ::, year 2024"
        qualityPrompt = "Detail Shading, {{{{{{{{{{amazing quality}}}}}}}}}}, very aesthetic, highres, incredibly absurdres"
        negativePrompt = "dark lighting,{{{blurry}}},{{{{{{{{worst quality, bad quality, japanese text}}}}}}}}, {{{{bad hands, closed eyes}}}}, {{{bad eyes, bad pupils, bad glabella}}}, {{{undetailed eyes}}}, multiple views, error, extra digit, fewer digits, jpeg artifacts, signature, watermark, username, reference, {{unfinished}}, {{unclear fingertips}}, {{twist}}, {{squiggly}}, {{grumpy}}, {{incomplete}}, {{imperfect fingers}}, disorganized colors, cheesy, {{very displeasing}}, {{mess}}, {{approximate}}, {{sloppiness}}"
    end

    print("---------------------------------ONLINEMODULE PROMPT---------------------------------")
    print("ONLINEMODULE: artistPrompt: " .. artistPrompt)
    print("ONLINEMODULE: qualityPrompt: " .. qualityPrompt)
    print("ONLINEMODULE: negativePrompt: " .. negativePrompt)
    print("---------------------------------ONLINEMODULE PROMPT---------------------------------")

    local chatHistoryTable = getFullChat(triggerId)
    local historyLength = #chatHistoryTable
    local targetIndex = nil

    for i = historyLength, 1, -1 do
        if chatHistoryTable[i].role == 'char' then
            targetIndex = i
            break
        end
    end

    local currentLine = chatHistoryTable[targetIndex].data

    local getPromptNow = nil
    local getNegPromptNow = nil

    if promptFlags == 1 then
        getPromptNow = getPrompt(currentLine, mainPrompt .. tonumber(index))
        getNegPromptNow = getPrompt(currentLine, mainNegPrompt .. tonumber(index))
    elseif promptFlags == 0 then
        getPromptNow = getPrompt(currentLine, mainPrompt)
        getNegPromptNow = getPrompt(currentLine, mainNegPrompt)
    end

    local finalPrompt = artistPrompt .. ", " ..  getPromptNow .. ", " .. qualityPrompt
    local finalNegPrompt = getNegPromptNow .. ", " .. negativePrompt

    local oldInlay = getOldInlay(startPrefix, profileFlags, targetIndex, tonumber(index))
    local newInlay = generateImage(triggerId, finalPrompt, finalNegPrompt):await()

    if newInlay ~= nil then
        alertNormal(triggerId, "이미지 리롤 완료")
        print("ONLINEMODULE: New " .. rerollType .. " image generated successfully for Identifier: " .. identifier)

        setState(triggerId, chatVarKeyForInlay, newInlay)
        print("ONLINEMODULE: Updated chat variable for Identifier: " .. identifier .. " with new inlay.")

        print("ONLINEMODULE: Checking history index " .. targetIndex .. " for update. Starts with: [" .. string.sub(currentLine, 1, 50) .. "]")
        
        local replacementOccurred = false
        local blockStart, blockEnd = nil, nil
        local newBlockContent = ""

        changeInlay(triggerId, targetIndex, oldInlay, newInlay)
    end
end)
