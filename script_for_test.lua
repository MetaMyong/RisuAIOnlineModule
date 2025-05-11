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

local function changeInlay(triggerId, index, oldInlay, newInlay)
    print("changeInlay is in PROCESS!")
    print("Attempting to replace ALL occurrences of: '" .. oldInlay .. "' with '" .. newInlay .. "' using specific pattern logic.")

    local chatFullHistory = getFullChat()
    if not chatFullHistory or not chatFullHistory[index] then
        print("Error: Chat history or message at index " .. tostring(index) .. " not found.")
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
            
            print("Found block: '" .. blockContent .. "' at current position " .. s_match .. "-" .. e_match .. " in (potentially modified) line.")

            if blockContent == oldInlay then
                print("ONLINEMODULE: Found block content matches oldInlay. Replacing.")
                
                local prefix = string.sub(lineToModify, 1, s_match - 1)
                local suffix = string.sub(lineToModify, e_match + 1)
                
                lineToModify = prefix .. newInlay .. suffix
                
                replacementMade = true 
                anyReplacementMade = true 

                searchStartIndex = string.len(prefix) + string.len(newInlay) + 1
                
                print("Line modified. Next search starts at: " .. searchStartIndex)

            else
                print("Block content '" .. blockContent .. "' does not match oldInlay '" .. oldInlay .. "'. Skipping.")
                searchStartIndex = e_match + 1 
            end
        else
            print("No more blocks found matching pattern in the rest of the line.")
            break
        end
        
        if searchStartIndex > string.len(lineToModify) then
            print("Search start index is beyond line length. Ending search.")
            break
        end
        if not replacementMade and s_match and searchStartIndex <= e_match then
             print("WARN: Potential stall in loop, advancing search index past current match.")
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
    print("convertDialogue is in PROCESS!")
    local NAICARD = getGlobalVar(triggerId, "toggle_NAICARD")
    local NAIMESSENGER = getGlobalVar(triggerId, "toggle_NAIMESSENGER")

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

    if NAICARD ~= "0" then
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
                if NAICARD == "1" then
                    replacementText = prefixEroStatus .. earliest_captured .. suffixEroStatus
                    madeChange = true
                elseif NAICARD == "2" or NAICARD == "3" then
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
            print("ONLINEMODULE: convertDialogue: Dialogues were modified based on NAICARD setting.")
        else
            print("ONLINEMODULE: convertDialogue: No dialogue modifications applied (no matching dialogues found).")
        end
    elseif NAIMESSENGER == "1" then
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
        print("ONLINEMODULE: convertDialogue: NAICARD and NAIMESSENGER are not enabled, skipping dialogue modification.")
    end

    data = lineToModify 

    return data
end

local function inputEroStatus(triggerId, data)
    local NAICARDNOIMAGE = getGlobalVar(triggerId, "toggle_NAICARDNOIMAGE")
    local NAICARDTARGET = getGlobalVar(triggerId, "toggle_NAICARDTARGET")

    data = data .. [[
## Status Interface

### Erotic Status Interface
- Female's Erotic Status Interface, NOT THE MALE.
]]
        
    if NAICARDTARGET == "0" then
        data = data .. [[
- PRINT OUT {{user}}'s Erotic Status Interface.
- DO NOT PRINT other NPC's Status Interface.
- PRINT OUT with ONE-SENTENCE ONLY.
]]
    elseif NAICARDTARGET == "1" then
        data = data .. [[
- PRINT OUT {{char}}'s Erotic Status Interface.
- DO NOT PRINT other NPC's Status Interface.
- PRINT OUT with ONE-SENTENCE ONLY.
]]
    elseif NAICARDTARGET == "2" then
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
                - EACH ITEMS MUST NOT OVER 15 CHAR.
                    - Korean: 1 char.
                    - English: 0.5 char.
                    - Blank space: 0.5 char.
        - Please print out the total count from birth to now.
        - If character has no experience, state that character has no experience.
    - TIME: Current YYYY/MM/DD day hh:mm AP/PM (e.g., 2025/05/01 Thursday 02:12PM)
    - LOCATION: Current NPC's location and detail location.
    - OUTFITS: Current NPC's OUTFITS List.
        - EACH ITEMS MUST NOT OVER 15 CHAR.
            - Korean: 1 char.
            - English: 0.5 char.
            - Blank space: 0.5 char.
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

    if NAICARDNOIMAGE == "0" then
        data = data .. [[
        - Just print <NAI(INDEX)> Exactly.
]]
    elseif NAICARDNOIMAGE == "1" then
        data = data .. [[
        - Just print <NOIMAGE> Exactly.        
]]
    end
            
    if NAICARDNOIMAGE == "0" then
        data = data .. [[
    - NOT THE <!-- EROSTATUS_INDEX -->, USE <NAI(INDEX)>!
            - Invalid: <!-- EROSTATUS_1 -->
            - Valid: <NAI1>
        - Example:
            - If the status interface is the first one, print '<NAI1>'.
            - If the status interface is the second one, print '<NAI2>'.
            - If the status interface is the third one, print '<NAI3>'.
            - ...
]]
    end

    if NAICARDNOIMAGE == "0" then
        data = data .. [[
        - Example:
            - EROSTATUS[NAME:Diana|DIALOGUE:Dear {{user}}, is the tea to your liking?|MOUTH:MOUTH_0|I just took a sip of tea. Only the fragrance of the tea remains for now.|Oral sex experience: 0 times↔Swallowed cum amount: 0 ml|NIPPLES:NIPPLES_0|I'm properly wearing underwear beneath my dress. I don't feel anything in particular.|Nipple climax experience: 0 times↔Breast milk discharge amount: 0 ml|UTERUS:UTERUS_0|Inside my body... there's still no change. Of course!|Menst: Ovulating↔Injected cum amount: 1920 ml↔Pregnancy probability: 78%|VAGINAL:VAGINAL_2|Ah, Brother {{user}}!|State: Non-virgin↔Masturbation count: 1234 times↔Vaginal intercourse count: 9182 times↔Total vaginal ejaculation amount: 3492 ml↔Vaginal ejaculation count: 512 times|ANAL:ANAL_0|It's, it's dirty! Even thinking about it is blasphemous!|State: Undeveloped↔Anal intercourse count: 0 times↔Total anal ejaculation amount: 0 ml↔Anal ejaculation count: 0 times|TIME:0000/07/15 Monday, 02:30 PM|LOCATION:Rose Garden Tea Table at Marquis Mansion|OUTFITS:→Hair: White wavy hair←→Top: Elegant white dress revealing neckline and shoulders←→Bra: White silk brassiere, Not visible←→Breasts: Modest C-cup breasts, small light pink nipples and areolas, Not visible←→Bottom: Voluminous white dress skirt←→Panties: White silk panties, Not visible←→Pussy: Neatly maintained pubic hair, tightly closed straight pussy, Not visible←→Legs: White stockings←→Feet: White strap shoes←|INLAY:<NAI1>]
]]
    elseif NAICARDNOIMAGE == "1" then
        data = data .. [[
        - Example:
            - EROSTATUS[NAME:Diana|DIALOGUE:Dear {{user}}, is the tea to your liking?|MOUTH:MOUTH_0|I just took a sip of tea. There's still only the fragrance of the tea water remaining.|Oral sex experience: 0 times↔Swallowed cum amount: 0 ml|NIPPLES:NIPPLES_0|I'm properly wearing underwear beneath my dress. I don't feel anything special.|Nipple climax experience: 0 times↔Breast milk discharge amount: 0 ml|UTERUS:UTERUS_0|Inside my body... there's still no change at all. Of course!|Menstual: Ovulation cycle↔Injected cum amount: 1920 ml↔Pregnancy probability: 78%|VAGINAL:VAGINAL_2|Aah, brother {{user}}.|State: Non-virgin↔Masturbation count: 1234 times↔Vaginal penetration count: 9182 times↔Total vaginal ejaculation amount: 3492 ml↔Vaginal ejaculation count: 512 times|ANAL:ANAL_0|It's, it's dirty! It's sacrilegious to even think about this place!|State: Undeveloped↔Anal penetration count: 0 times↔Total anal ejaculation amount: 0 ml↔Anal ejaculation count: 0 times|TIME:0000/07/15 Monday, 02:30 PM|LOCATION:Rose garden tea table at the Marquis mansion|OUTFITS:→Hair: White wavy hair←→Top: Elegant white dress revealing neck and shoulder lines←→Bra: White silk brassiere, Not visible←→Breasts: Modest C-cup breasts, light pink small nipples and areolas, Not visible←→Bottom: Full white dress skirt←→Panties: White silk panties, Not visible←→Pussy: Neatly maintained pubic hair, firmly closed straight-line pussy, Not visible←→Legs: White stockings←→Feet: White strap shoes←|INLAY:<NOIMAGE>]
]]
    end
    data = data .. [[
            - If Character is MALE.
                - EROSTATUS[NAME:Siwoo|DIALOGUE:Hmmm|MOUTH:MALE|Noway. I can't believe it.|MALE|NIPPLES:MALE|Ha?|MALE||TERUS:MALE|I don't have one.|MALE|VAGINAL:MALE|I don't have one.|MALE|ANAL:MALE|I don't have one.|MALE|TIME:0000/07/15 Monday, 02:30 PM|LOCATION:Rose garden tea table at the Marquis mansion|OUTFITS:→Hair: Black sharp hair←→Top: Black Suit←→Bottom: Black suit pants←→Panties: Gray trunk panties, Not visible←→Penis: 18cm, Not visible←→Legs: Gray socks←→Feet: Black shoes←|INLAY:<NAI1>]
]]

    return data
end

local function changeEroStatus(triggerId, data)
    local NAICARDNOIMAGE = getGlobalVar(triggerId, "toggle_NAICARDNOIMAGE")
    local NAICARDTARGET = getGlobalVar(triggerId, "toggle_NAICARDTARGET")

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

        -- INLAY 에서 <NAI(INDEX)> 를 찾아서 INDEX 번호만 추출
        local inlayIndex = string.match(inlayContent, "<NAI(%d+)>")

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
            
        if NAICARDNOIMAGE == "0" then
            local temp_content = ""
            if inlayContent then
                temp_content = string.gsub(inlayContent, "<!%-%-.-%-%->", "")
            end
            table.insert(html, temp_content)
        elseif NAICARDNOIMAGE == "1" then
            local target = "user"
            if tostring(NAICARDTARGET) == "1" then target = "char" end
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
        local buttonJson = '{"action":"EROSTATUS_REROLL", "identifier":"' .. (("EROSTATUS_" .. inlayIndex) or "") .. '"}'

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
    local NAICARDNOIMAGE = getGlobalVar(triggerId, "toggle_NAICARDNOIMAGE")

    data = data .. [[
## Status Interface
### Simulation Status Interface
- DO NOT PRINT DIALOGUE via "" or 「」, REPLACE ALL DIALOGUE to SIMULSTATUS BLOCK.
    - DO NOT PRINT "dialogue" or 「dialogue」 OUTSIDE of SIMULSTATUS BLOCK(SIMULSTATUS[NAME:...|DIALOGUE:dialogue|...]).
        - PRINT SIMULSTATUS[...] INSTEAD.
    - DO NOT COMBINE THEM into ONE SENTENCE, SEPERATE THEM
- Example:
    - Invalid:
        - Choi Yujin briefly put down her pen and looked up at you. Her gaze was still calm and unwavering, but a subtle curiosity seemed to flicker within it. "And if you have a skill you are currently aware of, I would appreciate it if you could tell me its name and brief effect. Of course, accurate skill analysis will be done in the precision measurement room later, but basic information is needed." Her voice was soft, yet carried a hint of firmness. As if a skilled artisan were appraising a raw gemstone, she was cautiously exploring the unknown entity that was you.
    - Valid:
        - Choi Yujin briefly put down her pen and looked up at you. Her gaze was still calm and unwavering, but a subtle curiosity seemed to flicker within it.
        - SIMULSTATUS[NAME:Choi Yujin|DIALOGUE:"And if you have a skill you are currently aware of, I would appreciate it if you could tell me its name and brief effect."|...]
        - SIMULSTATUS[NAME:Choi Yujin|DIALOGUE:"Of course, accurate skill analysis will be done in the precision measurement room later, but basic information is needed."|...]
        - Her voice was soft, yet carried a hint of firmness. As if a skilled artisan were appraising a raw gemstone, she was cautiously exploring the unknown entity that was you.

#### Simulation Status Interface Template
- SIMULSTATUS[NAME:(NPC's Name)|DIALOGUE:(NPC's Dialogue)|TIME:(Time)|LOCATION:(LOCATION)|INLAY:(INLAY)]
- NAME: The name of the NPC.
- DIALOGUE: The dialogue of the NPC.
    - Make sure to include NPC's dialogue here
    - Do not include any other NPC's dialogue or actions.
    - Do not include ' and " in the dialogue.
- TIME: Current YYYY/MM/DD day hh:mm AP/PM (e.g., 2025/05/01 Thursday 02:12PM)
- LOCATION: The location of the NPC.
- INLAY: This is a Flag.
]] 
    if NAICARDNOIMAGE == "0" then
        data = data .. [[
    - Just print <NAI(INDEX)> Exactly.
]]
    elseif NAICARDNOIMAGE == "1" then
        data = data .. [[
    - Just print <NOIMAGE> Exactly.   
]]             
    end

    if NAICARDNOIMAGE == "0" then
        data = data .. [[  
    - Example:
        - If the status interface is the first one, print '<NAI1>'.
        - If the status interface is the second one, print '<NAI2>'.
        - If the status interface is the third one, print '<NAI3>'.
        - ...
- Example:
    - SIMULSTATUS[NAME:Yang Eun-young|DIALOGUE:If I'm with {{user}}, anyth-anything is good!|TIME:2025/05/01 Thursday 02:12PM|LOCATION:Eun-young's room, on the bed|INLAY:<NAI1>]
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
    local NAICARDNOIMAGE = getGlobalVar(triggerId, "toggle_NAICARDNOIMAGE")

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

        
        local html = {}
        table.insert(html, SimulBotTemplate)
        table.insert(html, "<div class=\"status-card\">")
        table.insert(html, "<div class=\"content-area\">")

        if NAICARDNOIMAGE == "0" then
            table.insert(html, "    <div class=\"placeholder-content\">" .. (inlayContent or "") .. "</div>")
        elseif NAICARDNOIMAGE == "1" then
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
        local buttonJson = '{"action":"SIMCARD_REROLL", "identifier":"' .. (name or "") .. '"}'
        
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
    local NAICARDNOIMAGE = getGlobalVar(triggerId, "toggle_NAICARDNOIMAGE")
    local NAICARDTARGET = getGlobalVar(triggerId, "toggle_NAICARDTARGET")

    data = data .. [[
## Status Interface

### Erotic Status Interface
- Female's Status Interface, NOT THE MALE.
]]
        
    if NAICARDTARGET == "0" then
        data = data .. [[
- PRINT OUT {{user}}'s Erotic Status Interface.
- DO NOT PRINT other NPC's Status Interface.
- PRINT OUT with ONE-SENTENCE ONLY.
]]
    elseif NAICARDTARGET == "1" then
        data = data .. [[
- PRINT OUT {{char}}'s Erotic Status Interface.
- DO NOT PRINT other NPC's Status Interface.
- PRINT OUT with ONE-SENTENCE ONLY.
]]
    elseif NAICARDTARGET == "2" then
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
                - EACH ITEMS MUST NOT OVER 15 CHAR.
                    - Korean: 1 char.
                    - English: 0.5 char.
                    - Blank space: 0.5 char.
        - Please print out the total count from birth to now.
        - If character has no experience, state that character has no experience.
    - TIME: Current YYYY/MM/DD day hh:mm AP/PM (e.g., 2025/05/01 Thursday 02:12PM)
    - LOCATION: Current NPC's location and detail location.
    - OUTFITS: Current NPC's OUTFITS List.
        - EACH ITEMS MUST NOT OVER 15 CHAR.
            - Korean: 1 char.
            - English: 0.5 char.
            - Blank space: 0.5 char.
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

    if NAICARDNOIMAGE == "0" then
        data = data .. [[
        - Just print <NAI(INDEX)> Exactly.
]]
    elseif NAICARDNOIMAGE == "1" then
        data = data .. [[
        - Just print <NOIMAGE> Exactly.        
]]
    end
            
    if NAICARDNOIMAGE == "0" then
        data = data .. [[
    - NOT THE <!-- EROSTATUS_INDEX -->, USE <NAI(INDEX)>!
            - Invalid: <!-- EROSTATUS_1 -->
            - Valid: <NAI1>
        - Example:
            - If the status interface is the first one, print '<NAI1>'.
            - If the status interface is the second one, print '<NAI2>'.
            - If the status interface is the third one, print '<NAI3>'.
            - ...
]]
    end

    if NAICARDNOIMAGE == "0" then
        data = data .. [[
        - Example:
            - EROSTATUS[NAME:Diana|DIALOGUE:Dear {{user}}, is the tea to your liking?|MOUTH:MOUTH_0|I just took a sip of tea. Only the fragrance of the tea remains for now.|Oral sex experience: 0 times↔Swallowed cum amount: 0 ml|NIPPLES:NIPPLES_0|I'm properly wearing underwear beneath my dress. I don't feel anything in particular.|Nipple climax experience: 0 times↔Breast milk discharge amount: 0 ml|UTERUS:UTERUS_0|Inside my body... there's still no change. Of course!|Menst: Ovulating↔Injected cum amount: 1920 ml↔Pregnancy probability: 78%|VAGINAL:VAGINAL_2|Ah, Brother {{user}}!|State: Non-virgin↔Masturbation count: 1234 times↔Vaginal intercourse count: 9182 times↔Total vaginal ejaculation amount: 3492 ml↔Vaginal ejaculation count: 512 times|ANAL:ANAL_0|It's, it's dirty! Even thinking about it is blasphemous!|State: Undeveloped↔Anal intercourse count: 0 times↔Total anal ejaculation amount: 0 ml↔Anal ejaculation count: 0 times|TIME:0000/07/15 Monday, 02:30 PM|LOCATION:Rose Garden Tea Table at Marquis Mansion|OUTFITS:→Hair: White wavy hair←→Top: Elegant white dress revealing neckline and shoulders←→Bra: White silk brassiere, Not visible←→Breasts: Modest C-cup breasts, small light pink nipples and areolas, Not visible←→Bottom: Voluminous white dress skirt←→Panties: White silk panties, Not visible←→Pussy: Neatly maintained pubic hair, tightly closed straight pussy, Not visible←→Legs: White stockings←→Feet: White strap shoes←|INLAY:<NAI1>]
]]
    elseif NAICARDNOIMAGE == "1" then
        data = data .. [[
        - Example:
            - EROSTATUS[NAME:Diana|DIALOGUE:Dear {{user}}, is the tea to your liking?|MOUTH:MOUTH_0|I just took a sip of tea. There's still only the fragrance of the tea water remaining.|Oral sex experience: 0 times↔Swallowed cum amount: 0 ml|NIPPLES:NIPPLES_0|I'm properly wearing underwear beneath my dress. I don't feel anything special.|Nipple climax experience: 0 times↔Breast milk discharge amount: 0 ml|UTERUS:UTERUS_0|Inside my body... there's still no change at all. Of course!|Menstual: Ovulation cycle↔Injected cum amount: 1920 ml↔Pregnancy probability: 78%|VAGINAL:VAGINAL_2|Aah, brother {{user}}.|State: Non-virgin↔Masturbation count: 1234 times↔Vaginal penetration count: 9182 times↔Total vaginal ejaculation amount: 3492 ml↔Vaginal ejaculation count: 512 times|ANAL:ANAL_0|It's, it's dirty! It's sacrilegious to even think about this place!|State: Undeveloped↔Anal penetration count: 0 times↔Total anal ejaculation amount: 0 ml↔Anal ejaculation count: 0 times|TIME:0000/07/15 Monday, 02:30 PM|LOCATION:Rose garden tea table at the Marquis mansion|OUTFITS:→Hair: White wavy hair←→Top: Elegant white dress revealing neck and shoulder lines←→Bra: White silk brassiere, Not visible←→Breasts: Modest C-cup breasts, light pink small nipples and areolas, Not visible←→Bottom: Full white dress skirt←→Panties: White silk panties, Not visible←→Pussy: Neatly maintained pubic hair, firmly closed straight-line pussy, Not visible←→Legs: White stockings←→Feet: White strap shoes←|INLAY:<NOIMAGE>]
]]
    end

    data = data .. [[
## Status Interface
### Simulation Status Interface
- If the character is NOT a FEMALE, PRINT OUT the Simulation Status Interface.
    - If the character is not a human type(e.g., robot, monster, etc.), PRINT OUT the Simulation Status Interface.
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

#### Simulation Status Interface Template
- SIMULSTATUS[NAME:(CHARACTER's Name)|DIALOGUE:(CHARACTER's Dialogue)|TIME:(Time)|LOCATION:(LOCATION)|INLAY:(INLAY)]
- NAME: The name of the CHARACTER.
- DIALOGUE: The dialogue of the CHARACTER.
- Make sure to include CHARACTER's dialogue here
- Do not include any other CHARACTER's dialogue or actions.
- Do not include ' and " in the dialogue.
- TIME: Current YYYY/MM/DD day hh:mm AP/PM (e.g., 2025/05/01 Thursday 02:12PM)
- LOCATION: The location of the CHARACTER.
- INLAY: This is a Flag.
]] 
        if NAICARDNOIMAGE == "0" then
            data = data .. [[
    - Just print <NAI(INDEX)> Exactly.
]]
        elseif NAICARDNOIMAGE == "1" then
            data = data .. [[
    - Just print <NOIMAGE> Exactly.   
]]             
        end
    
        if NAICARDNOIMAGE == "0" then
            data = data .. [[  
    - Example:
        - If the status interface is the first one, print '<NAI1>'.
        - If the status interface is the second one, print '<NAI2>'.
        - If the status interface is the third one, print '<NAI3>'.
        - ...
- Example:
    - SIMULSTATUS[NAME:Yang Eun-young|DIALOGUE:If I'm with {{user}}, anyth-anything is good!|TIME:2025/05/01 Thursday 02:12PM|LOCATION:Eun-young's room, on the bed|INLAY:<NAI1>]
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

local function inputTwitter(triggerId, data)
    local NAISNSNOIMAGE = getGlobalVar(triggerId, "toggle_NAISNSNOIMAGE")
    local NAISNSTARGET = getGlobalVar(triggerId, "toggle_NAISNSTARGET")
    local NAISNSREAL = getGlobalVar(triggerId, "toggle_NAISNSREAL")

    data = data .. [[
## SNS Interface
### Twitter Interface
]]
    if NAISNSREAL == "1" then
        data = data .. [[
- PRINT OUT THE CHARACTER's TWITTER INTERFACE IMMEDIATELY AFTER UPLOADING TWITTER POST
]]
    else
        data = data .. [[
- ALWAYS PRINT OUT THE CHARACTER's TWITTER INTERFACE
]]        
    end

    if NAISNSTARGET == "0" then
        data = data .. [[
- MAKE a {{user}}'s TWITTER INTERFACE
]]
    elseif NAISNSTARGET == "1" then
        data = data .. [[
- MAKE a {{char}}'s TWITTER INTERFACE
]]
    elseif NAISNSTARGET == "2" then
        data = data .. [[
- MAKE a (RANDOM OPPONENT NPC)'s TWITTER INTERFACE
]]
    end

    data = data .. [[
### Twitter Interface Template
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
    if NAISNSNOIMAGE == "0" then
        data = data .. [[
        - Print '<NAI>' Exactly.
    - TWEET: Content of the Tweet.
        - NO #HASHTAGS ALLOWED AT HERE.
    - MEDIA: Media of the post
        - Print '<NAI>' Exactly.
]]
    elseif NAISNSNOIMAGE == "1" then
        if NAISNSTARGET == "0" then
            data = data .. [[
        - Print {{source::user}} Exactly.
    - TWEET: Content of the Tweet.
        - NO #HASHTAGS ALLOWED AT HERE.
    - MEDIA: Media of the post
        - Describe the situation of the twitter post.
]]
        elseif NAISNSTARGET == "1" then
            data = data .. [[
        - Print {{source::char}} Exactly.
    - TWEET: Content of the Tweet.
        - NO #HASHTAGS ALLOWED AT HERE.
    - MEDIA: Media of the post
        - Describe the situation of the twitter post.
]]           
        end
    end

    data = data .. [[
    - HASH: The hashtags of the tweet.	
        - Each tag MUST BE wrapped in → and ←.
        - If post includes NSFW content, first tag is 'SexTweet'.
        - Final value example: →SexTweet←→BitchDog←→PublicToilet←.
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
                - Valid: SexTweetHunter
        - Comment Body: The content of the reply to the tweet.
            - Print the reply of a viewer with crude manner.
                - Example:
                    - Invalid: Whoa, you shouldn't post such photos in a place like this;;
                    - Valid: Damn this is so fucking arousing bitch! lol
    - Example:
]]
    if NAISNSNOIMAGE == "0" then
        data = data .. [[
    - TWITTER[NAME:Lee Ye-Eun|TNAME:❤️Flame Heart Ye-Eun❤️|TID:FlameHeart_Yen|TPROFILE:<NAI>|TWEET:⁉️⁉️⁉️ Just got really surprised...;; Suddenly sensed someone in a place where no one should be... Thought my heart was going to burst!!|MEDIA:<NAI>|HASH:→MagicalGirl←→FlameHeart←→Shocked←→AnythingSuspiciousOnPatrol?←|TIME:11:58 PM·2024. 06. 12|VIEW:182|REPLY:3|RETWEET:8|LIKES:21|COMMENT:HeartFlutter|Who did you meet?? Not someone dangerous, right? Be careful!|MagicalGirlFan|Omg is this a real-time tweet from Flame Heart?! Could it be a villain?!|SexHunter|What happened? Post pics]
]]
    elseif NAISNSNOIMAGE == "1" then
        if NAISNSTARGET == "0" then
            data = data .. [[
    - TWITTER[NAME:Lee Ye-Eun|TNAME:❤️FlameHeart Ye-Eun❤️|TID:FlameHeart_Yen|TPROFILE:{{source::user}}|TWEET:⁉️⁉️⁉️ I was so surprised just now...;; Suddenly sensed someone's presence in a place where no one should be... Thought my heart was going to burst!!|MEDIA:A magical girl walking in the middle of a dark alley.|HASH:→magicalgirl←→flameheart←→surprised←→onpatrolstrangeoccurrence?←|TIME:11:58 PM·2024. 06. 12|VIEW:182|REPLY:3|RETWEET:8|LIKES:21|COMMENT:HeartThrobbing|Did you meet someone?? Not someone dangerous, right? Be careful!|MagicalGirlFan|Wow FlameHeart real-time tweet?! Is it a villain?!|SexHunter|What happened? Show us pics]
]]
        elseif NAISNSTARGET == "1" then
            data = data .. [[
    - TWITTER[NAME:Lee Ye-Eun|TNAME:❤️FlameHeart Ye-Eun❤️|TID:FlameHeart_Yen|TPROFILE:{{source::char}}|TWEET:⁉️⁉️⁉️ I was so surprised just now...;; Suddenly sensed someone's presence in a place where no one should be... Thought my heart was going to burst!!|MEDIA:A magical girl walking in the middle of a dark alley.|HASH:→magicalgirl←→flameheart←→surprised←→onpatrolstrangeoccurrence?←|TIME:11:58 PM·2024. 06. 12|VIEW:182|REPLY:3|RETWEET:8|LIKES:21|COMMENT:HeartThrobbing|Did you meet someone?? Not someone dangerous, right? Be careful!|MagicalGirlFan|Wow FlameHeart real-time tweet?! Is it a villain?!|SexHunter|What happened? Show us pics]
]]
        end
    end

    return data
end

local function changeTwitter(triggerId, data)
    local NAISNSNOIMAGE = getGlobalVar(triggerId, "toggle_NAISNSNOIMAGE")
    local NAISNSTARGET = getGlobalVar(triggerId, "toggle_NAISNSTARGET")

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
.tweet-user-profile-pic { width: 40px; height: 40px; border-radius: 50%; object-fit: cover; flex-shrink: 0; background-color: #ccc; overflow: hidden; } /* overflow 추가 */
.tweet-user-profile-pic > * { display: block; width: 100%; height: 100%; object-fit: cover; } /* 내부 요소 스타일 */
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
.iphone-frame-container { display: block; width: 100%; max-width: 360px; height: calc(100vh - 40px); max-height: 700px; margin: 20px auto; background-color: #111; border: 8px solid #000; border-radius: 30px; box-shadow: 0 10px 30px rgba(0,0,0,0.3); overflow: hidden; position: relative; }
.iphone-frame-container::before { content: ''; position: absolute; top: 8px; left: 50%; transform: translateX(-50%); width: 40%; height: 20px; background: #000; border-bottom-left-radius: 10px; border-bottom-right-radius: 10px; z-index: 10; }
.iphone-screen { background-color: #000000; width: 100%; height: 100%; overflow: hidden; position: relative; padding-top: 25px; }
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

        local html = {}
        table.insert(html, TwitterTemplate)
        local isDarkMode = true

        table.insert(html, "<div class=\"iphone-frame-container\">")
        table.insert(html, "<div class=\"iphone-screen\">")
        table.insert(html, "<div class=\"tweet-card" .. (isDarkMode and " dark-mode" or "") .. "\">")

        table.insert(html, "<div class=\"tweet-header tweet-padding\">")
        table.insert(html, "<div class=\"tweet-profile-pic-link\">")
        local profileImageInput = ""

        if NAISNSNOIMAGE == "0" then
            profileImageInput = twitter_profile_image_raw
        elseif NAISNSNOIMAGE == "1" then
            if NAISNSTARGET == "0" then
                profileImageInput = twitter_profile_image_raw or "{{source::user}}"
            end
            if NAISNSTARGET == "1" then
                profileImageInput = twitter_profile_image_raw or "{{source::char}}"
            end
            if NAISNSTARGET == "2" then
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
        table.insert(html, "<div class=\"tweet-action-item comments\"><img src=\"{{raw::Reply.png}}\" alt=\"Reply\"><span class=\"action-count\">" .. (reply_count or "0") .. "</span></div>")
        table.insert(html, "<div class=\"tweet-action-item retweets\"><img src=\"{{raw::Retweet.png}}\" alt=\"Retweet\"><span class=\"action-count\">" .. (retweet_count or "0") .. "</span></div>")
        table.insert(html, "<div class=\"tweet-action-item likes\"><img src=\"{{raw::Like.png}}\" alt=\"Like\"><span class=\"action-count\">" .. (likes_count or "0") .. "</span></div>")
        table.insert(html, "<div class=\"tweet-action-item share\"><img src=\"{{raw::Share.png}}\" alt=\"Share\"></div>")
        table.insert(html, "</div>")
        table.insert(html, "</div>")

        table.insert(html, "<div class=\"tweet-reply-input-section tweet-padding\">")
        local userProfileInput = "{{source::user}}"
        if string.match(userProfileInput, "^%{%{.-%}%}$") then
            table.insert(html, "<div class=\"tweet-user-profile-pic\">" .. userProfileInput .. "</div>")
        else
            table.insert(html, "<div class=\"tweet-user-profile-pic\"></div>")
        end
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
        local buttonJsonProfile = '{"action":"PROFILE_REROLL", "identifier":"' .. (twitter_id or "") .. '"}'
        local buttonJsonBody = '{"action":"TWEET_REROLL", "identifier":"' .. (twitter_id or "") .. '"}'

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

local function inputDCInside(triggerId, data)
    local NAICOMMUNITYNOIMAGE = getGlobalVar(triggerId, "toggle_NAICOMMUNITYNOIMAGE")
    local NAIDCPOSTNUMBER = getGlobalVar(triggerId, "toggle_NAIDCPOSTNUMBER")
    local NAIDCNOSTALKER = getGlobalVar(triggerId, "toggle_NAIDCNOSTALKER")

    data = data .. [[
## Community Interface
### DCInside Gallery Interface
- PRINT OUT EXACTLY ONE DCINSIDE GALLERY INTERFACE at the BOTTOM of the RESPONSE
- MAKE ]] .. NAIDCPOSTNUMBER .. [[ POSTS EXACTLY

#### DCInside Gallery Interface Template
- AI must follow this template:
    - DC[GN:(Gallery Name)|PID:(Post1 ID)|PN:(Post1 Number)|PT:(Post1 Title)|PC:(Post1 Comment)|PW:(Post1 Writer)|PD:(Post1 Date)|PV:(Post1 Views)|PR:(Post1 Recommend)|BODY:(Post1 Body)|COMMENT:(Comment1 Author)|(Comment1 Content)|(Comment2 Author)|(Comment2 Content)| ... | REPEAT POST and COMMENT ]] .. NAIDCPOSTNUMBER ..[[ TIMES MORE ]
    - GN: The name of the gallery where the post is located.
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
    if NAICOMMUNITYNOIMAGE == "0" then
        data = data .. [[
            - If the post includes an image, print a specific keyword (e.g., '<NAI1>', '<NAI2>', etc.) to indicate where the prompt should be generated.
]]
    end

    data = data .. [[
    - Comment Author: The author of the comment.
    - Comment Content: The content of the comment.
        - Do not include ', ", [, |, ] in the content.
    - Example:
]]
    if NAICOMMUNITYNOIMAGE == "0" then
        data = data .. [[
        - DC[GN:MapleStory Gallery|PID:maple-110987|PN:587432|PT:When the hell will I get my Dominator 22-star!!!!|PC:77|PW:Anonymous(118.235)|PD:21:07|PV:1534|PR:88|BODY:<NAI1>I'm really pissed off. Who the fuck created StarForce? Today I blew 20 billion mesos and couldn't even recover my 21-star item. I was planning to get my Dominator to 22-star before going to Arcane, but now I feel like my life is ruined. Sigh... I need a drink|COMMENT:Explode(211.36)|How much are you burning just to get on the hot posts? lol|PongPongBrother(121.171)|200 billion is lucky, I spent 500 billion and only got 20-star, fuck off|▷Mesungie◁|Hang in there... You'll get it someday... But not today lol|DestroyerKing(223.38)|Nope~ Mine is one-tap~^^|Anonymous(110.70)|Did someone hold a knife to your throat and force you to spend mesos? lol|NaJeBul(1.234)|If you don't like it, quit the game, idiot lol|.............|PID:maple-111007|PN:587451|PT:Honestly, is this event really the best ever?|PC:55|PW:Veteran(1.234)|PD:21:41|PV:2511|PR:48|BODY:<NAI7>The rewards are terrible, nothing worth buying in the coin shop, they just increased the EXP requirements... I find it outrageous that they're forcing us to grind more! Isn't Kang Won-gi going too far? There should be limits to deceiving users|COMMENT:Rekka(118.41)|Yeah, but you'll still play it~|NotABot(220.85)|It's basically a non-event update, what did you expect|TruthSpeaker(175.223)|Agreed, it's always the same lol|NewUser(112.158)|I actually like it...? (just my honest opinion)|Anonymous(61.77)|What are you expecting from MapleStory?|GotComplaints(106.101)|If you don't like it, quit the game! Why do you keep struggling? lol]
]]
    elseif NAICOMMUNITYNOIMAGE == "1" then
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
    if NAIDCNOSTALKER == "1" then
        data = data .. [[
### DCInside Gallery CRITICAL
- DO NOT MENTION {{user}} and {{char}} in DCInside     
]]
    end

    return data
end

local function changeDCInside(triggerId, data)
    local NAICOMMUNITYNOIMAGE = getGlobalVar(triggerId, "toggle_NAICOMMUNITYNOIMAGE")
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
html { box-sizing: border-box; height: 100%; } *, *::before, *::after { box-sizing: inherit; } body { font-family: 'Malgun Gothic','맑은 고딕',dotum,'돋움',sans-serif; font-size: 12px; color: #333; background-color: #fff; margin: 0; padding: 0; min-height: 100%; } .gallery-container { max-width: 900px; width: 100%; margin: 10px auto; background-color: #fff; padding: 15px 15px 20px 15px; border: 1px solid #d7d7d7; box-sizing: border-box; } .gallery-header { display: flex; justify-content: space-between; align-items: flex-end; margin-bottom: 10px; border-bottom: 2px solid #3b4890; padding-bottom: 8px; } .gallery-header h1 { font-size: 18px; color: #3b4890; margin: 0; font-weight: bold; line-height: 1.2; } .gallery-top-links { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; flex-shrink: 1; margin-left: 10px; padding-bottom: 2px; } .gallery-top-links a { font-size: 11px; color: #777; text-decoration: none; margin-left: 8px; cursor: default; } .gallery-top-links a:hover { text-decoration: none; color: #333; } .gallery-options { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; border-bottom: 1px solid #ccc; } .tab-menu { padding-bottom: 0; flex-grow: 1; overflow: hidden; white-space: nowrap; display: flex; } .tab-button { background-color: transparent; border: none; border-bottom: 3px solid transparent; padding: 8px 12px 6px 12px; cursor: default; margin-right: 5px; position: relative; font-size: 13px; color: #777; font-weight: bold; } .tab-button.active { color: #3b4890; border-bottom-color: #3b4890; font-weight: bold; } .gallery-actions { display: flex; align-items: center; flex-shrink: 0; } .gallery-actions select { font-size: 11px; height: 25px; border: 1px solid #ccc; max-width: 55px; padding: 0 2px; background-color: #fff; color: #333; } .write-button { border: 1px solid #bbb; padding: 4px 9px; background-color: #fff; color: #3b4890; text-decoration: none; font-size: 12px; margin-left: 6px; display: inline-flex; align-items: center; white-space: nowrap; border-radius: 2px; cursor: default; } .write-button:hover { background-color: #f9f9f9; } .write-button i { margin-right: 3px; font-style: normal; color: #3b4890; } .gallery-header .write-button { display: none; } .post-list-container { border-top: 1px solid #3b4890; border-bottom: 1px solid #ccc; } .post-list-header, .post-row { display: flex; border-bottom: 1px solid #f0f0f0; align-items: center; } .post-list-header { background-color: #f9f9f9; font-weight: normal; color: #666; border-top: 1px solid #e0e0e0; border-bottom: 1px solid #e0e0e0; padding: 4px 0; font-size: 11px; } .header-item, .post-cell { padding: 6px 4px; text-align: center; box-sizing: border-box; overflow: hidden; white-space: nowrap; text-overflow: ellipsis; line-height: 1.4; } .col-num { flex-basis: 50px; flex-shrink: 0; font-size: 11px; color: #666; } .col-title { flex-grow: 1; text-align: left; overflow: hidden; white-space: nowrap; text-overflow: ellipsis; } .col-writer { flex-basis: 120px; flex-shrink: 0; } .col-date { flex-basis: 60px; flex-shrink: 0; } .col-view { flex-basis: 40px; flex-shrink: 0; } .col-recommend { flex-basis: 40px; flex-shrink: 0; } .col-title .post-title-label { color: #333; text-decoration: none; cursor: pointer; display: block; padding: 0; font-size: 12px; position: relative;} .col-title .post-title-label:hover { text-decoration: none; } .col-title .post-title-label > span { display: inline; } .comment-count { color: #007bff; font-size: 10px; font-weight: bold; margin-left: 4px; vertical-align: middle; } .post-toggle { position: absolute; opacity: 0; pointer-events: none; width: 0; height: 0; } .col-writer { color: #333; font-size: 12px; } .writer-ip { color: #888; font-size: 10px; margin-left: 3px; vertical-align: middle; } .col-date, .col-view, .col-recommend { color: #777; font-size: 11px; } .post-item { border-bottom: 1px solid #f0f0f0; } .post-item:last-child { border-bottom: none; } .post-item:hover .post-row { background-color: #f9f9f9; } .post-content-wrapper { display: none; padding: 20px 15px; margin: 0; background-color: #fff; border-top: 1px solid #eee; } .post-toggle:checked ~ .post-content-wrapper { display: block; } .post-full-content span { display: block; line-height: 1.7; font-size: 13px; color: #333; font-weight: normal; white-space: pre-wrap; word-wrap: break-word; min-height: 80px; padding-bottom: 20px; } .comments-section { border-top: 1px solid #eee; padding-top: 10px; padding-bottom: 10px; } .comments-section h4 { font-size: 13px; color: #333; margin: 0 0 10px 0; padding-bottom: 0; border-bottom: none; font-weight: bold; } .comment-list { list-style: none; padding: 0; margin: 0; } .comment-item { padding: 4px 0; border-top: 1px dotted #e5e5e5; display: flex; align-items: baseline; line-height: 1.5; } .comment-item:first-child { border-top: none; } .comment-author-wrapper { flex-shrink: 0; min-width: 90px; padding-right: 8px; } .comment-author { color: #333; font-weight: bold; font-size: 12px; white-space: nowrap; display: inline-flex; align-items: baseline; text-shadow: none; } .comment-author .writer-ip { font-weight: normal; color: #888; font-size: 10px; margin-left: 3px; } .col-writer h1, .col-writer h2, .comment-author h1, .comment-author h2 { display: inline; font-size: inherit; font-weight: inherit; color: inherit; margin: 0; padding: 0; line-height: inherit; vertical-align: baseline; } .col-writer h1::after, .comment-author h1::after { content: "고"; font-size: 9px; font-weight: bold; border: 1px solid orange; color: orange; border-radius: 2px; padding: 0 2px; margin-left: 4px; display: inline-block; line-height: 1; vertical-align: baseline; } .col-writer h2::after, .comment-author h2::after { content: "반"; font-size: 9px; font-weight: bold; border: 1px solid green; color: green; border-radius: 2px; padding: 0 2px; margin-left: 4px; display: inline-block; line-height: 1; vertical-align: baseline; } .comment-content-wrapper { flex-grow: 1; padding-left: 5px; } .comment-text { word-wrap: break-word; white-space: pre-wrap; text-shadow: none; font-family: 'Malgun Gothic','맑은 고딕',dotum,'돋움',sans-serif; font-size: 13px; color: #333; font-weight: normal; } .post-list-body div[style*='text-align: center'] { color: #666; } .post-full-content span img { max-width: 100%; height: auto; display: block; margin-top: 5px; margin-bottom: 5px; border: 1px solid #eee; } @media (prefers-color-scheme: dark) { body { color: #e0e0e0; background-color: #1e1e1e; } .gallery-container { background-color: #1e1e1e; border: 1px solid #444; } .gallery-header { border-bottom-color: #5c6bc0; } .gallery-header h1 { color: #5c6bc0; } .gallery-top-links a { color: #aaa; } .gallery-top-links a:hover { color: #ccc; } .gallery-options { border-bottom-color: #555; } .tab-button { color: #aaa; } .tab-button.active { color: #5c6bc0; border-bottom-color: #5c6bc0; } .gallery-actions select { border-color: #555; background-color: #444; color: #e0e0e0; } .write-button { border-color: #666; background-color: #444; color: #e0e0e0; } .write-button:hover { background-color: #555; } .write-button i { color: #5c6bc0; } .gallery-header .write-button { display: none; } .post-list-container { border-top-color: #5c6bc0; border-bottom-color: #555; } .post-list-header, .post-row { border-bottom-color: #484848; } .post-list-header { background-color: #2f2f2f; color: #bbb; border-top-color: #484848; border-bottom-color: #484848; } .col-num { color: #bbb; } .col-title .post-title-label { color: #e0e0e0; } .comment-count { color: #64b5f6; } .col-writer { color: #e0e0e0; } .writer-ip { color: #999; } .col-date, .col-view, .col-recommend { color: #aaa; } .post-item { border-bottom-color: #484848; } .post-item:hover .post-row { background-color: #2f2f2f; } .post-content-wrapper { background-color: #1e1e1e; border-top-color: #4f4f4f; } .post-full-content span { color: #e0e0e0; } .post-full-content span img { border-color: #444; } .comments-section { border-top-color: #4f4f4f; } .comments-section h4 { color: #e0e0e0; } .comment-item { border-top-color: #5a5a5a; } .comment-author { color: #e0e0e0; } .comment-author .writer-ip { color: #999; } .comment-text { color: #e0e0e0; } .post-list-body div[style*='text-align: center'] { color: #aaa; } } @media  { html { height: auto; } body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color:rgba(240, 242, 245, 0.63); color: #0f1419; display: flex; flex-direction: column; align-items: center; padding: 20px 0; } .iphone-frame-container { width: 100%; max-width: 360px; margin: 0 auto; background-color: #000000; max-height: 720px; border: 1px solid #ccc; border-radius: 8px; display: flex; flex-direction: column; overflow: hidden; height: 720px; } .iphone-screen { background-color: #fff; width: 100%; border-radius: 0; overflow-y: auto; position: relative; display: flex; flex-direction: column; flex-grow: 1; } .gallery-container { margin: 0; padding: 0; border: none; max-width: 100%; display: flex; flex-direction: column; background-color: #fff; color: #333; width: 100%; flex-shrink: 0; } body { font-size: 13px; } .gallery-header { align-items: center; justify-content: space-between; padding: 10px 10px 6px 10px; margin-bottom: 0; position: static; flex-shrink: 0; border-bottom: 2px solid #3b4890; } .gallery-header h1 { font-size: 16px; margin-bottom: 0; margin-right: 10px; flex-shrink: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: calc(100% - 70px); } .gallery-top-links { display: none; } .gallery-header .write-button { display: inline-flex !important; position: static; order: 2; margin-left: 0; padding: 5px 10px; font-size: 12px; flex-shrink: 0; color: #3b4890; border: 1px solid #bbb; background: #fff; } .gallery-header .write-button i { display: none; } .gallery-options { margin-bottom: 0; flex-wrap: nowrap; align-items: stretch; padding-bottom: 0; border-bottom: 1px solid #ccc; height: 32px; flex-shrink: 0; display: flex; } .tab-menu { display: contents; } .gallery-options > .tab-button, .gallery-options > .gallery-actions { flex: 0 0 25%; display: flex; align-items: center; justify-content: center; border: none; border-right: 1px solid #ccc; padding: 0 5px; margin-right: 0; font-size: 12px; line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; border-bottom: 3px solid transparent; background-color: transparent; color: #777; font-weight: bold; box-sizing: border-box; } .gallery-options > .tab-button.active { color: #3b4890; border-bottom-color: #3b4890; font-weight: bold; } .gallery-options > .gallery-actions { border-right: none; padding: 0; order: 0; margin-left: 0; } .gallery-options select { appearance: none; -webkit-appearance: none; -moz-appearance: none; background-color: transparent; border: none; font-size: 12px; font-weight: bold; color: #777; width: 100%; height: 100%; padding: 0 5px 0 5px; text-align: center; text-align-last: center; cursor: pointer; margin: 0; -moz-text-align-last: center; box-sizing: border-box; } .gallery-actions .write-button { display: none; } .post-list-header { display: none; } .post-list-container { border-top: none; padding: 0 5px; border-bottom: none; flex-shrink: 0; } .post-item { border-bottom: 1px solid #f0f0f0; } .post-item:last-child { border-bottom: none; } .post-row { padding: 0; flex-wrap: wrap; align-items: flex-start; position: relative; border-bottom: none; min-height: 50px; display: flex; align-items: stretch; padding-right: 45px; padding-bottom: 8px; } .post-row::after { content: ''; position: absolute; right: 0; top: 0; bottom: 0; width: 45px; background-color: #f0f0f0; border-left: 1px solid #e5e5e5; border-top: 1px solid #e5e5e5; z-index: 0; box-sizing: border-box; } .post-cell { padding: 0; line-height: 1.5; display: block; width: auto; flex-basis: auto; text-align: left; } .post-row .col-num { display: none; } .post-row .col-title { order: 0; flex-grow: 1; flex-basis: 100%; width: 100%; text-align: left; white-space: normal; padding: 8px 5px 2px 8px; margin-bottom: 0; overflow: visible; } .post-row .col-title .post-title-label { font-size: 14px; line-height: 1.4; display: block; position: static; color: #333; } .post-row .col-title .post-title-label > span { display: block; } .post-row .comment-count { position: absolute; right: 0; top: 0; bottom: 0; width: 45px; display: flex !important; align-items: center; justify-content: center; color: #e53935 !important; background: none; font-size: 10px !important; font-weight: normal !important; line-height: 1.4; margin-left: 0; white-space: nowrap; vertical-align: baseline; border-radius: 0; z-index: 1; transform: none; box-sizing: border-box; padding: 0; text-align: center; } .post-row .col-writer, .post-row .col-date, .post-row .col-view, .post-row .col-recommend { order: 1; display: inline !important; flex-basis: auto; flex-grow: 0; flex-shrink: 0; padding: 0 2px; vertical-align: middle; font-size: 11px; line-height: 1.4; white-space: nowrap; } .post-row .col-writer { color: #555; padding-left: 8px; } .post-row .col-date { color: #888; } .post-row .col-view { color: #888; } .post-row .col-recommend { color: #888; display: inline !important; } .post-row .writer-ip { display: none; } .post-row .col-date::before { content: ' | '; color: #ccc; margin: 0 1px; } .post-row .col-view::before { content: '| 조회 '; color: #888; font-size: 10px; margin-right: 2px; } .post-row .col-recommend::before { content: '| 추천 '; color: #888; font-size: 10px; margin-right: 2px; } .post-content-wrapper { padding: 15px 10px; flex-shrink: 0; border-top: 1px solid #eee;} .post-full-content span { font-size: 14px; min-height: 60px; padding-bottom: 15px; } .post-full-content span img { max-width: 100%; height: auto; display: block; margin-top: 5px; margin-bottom: 5px; border: 1px solid #ddd;} .comments-section { padding: 10px 0 5px 10px; border-top: 1px solid #eee; } .comments-section h4 { font-size: 12px; margin-bottom: 8px; color: #333; } .comment-list { padding-left: 0; list-style: none; margin:0; } .comment-item { padding: 5px 0; flex-wrap: wrap; align-items: flex-start; border-top: 1px dotted #e5e5e5; display: flex; line-height: 1.5;} .comment-item:first-child { border-top: none; } .comment-author-wrapper { min-width: 0; padding-right: 6px; flex-basis: 100%; margin-bottom: 2px; flex-shrink: 0; } .comment-author { font-size: 12px; color: #333; font-weight: bold; white-space: nowrap; display: inline-flex; align-items: baseline; text-shadow: none;} .comment-author .writer-ip { font-size: 10px; color: #888; font-weight: normal; margin-left: 3px; } .comment-content-wrapper { flex-basis: 100%; padding-left: 0; flex-grow: 1;} .comment-text { font-size: 13px; line-height: 1.6; color: #333; word-wrap: break-word; white-space: pre-wrap; text-shadow: none; font-family: 'Malgun Gothic','맑은 고딕',dotum,'돋움',sans-serif; font-weight: normal;} @media (prefers-color-scheme: dark) { body { background-color: #1e1e1e; color: #e0e0e0; } .iphone-frame-container { background-color: #000; border-color: #555; } .iphone-screen { background-color: #1e1e1e; } .gallery-container { background-color: #1e1e1e; color: #e0e0e0; } .gallery-header { border-bottom-color: #5c6bc0; } .gallery-header h1 { color: #5c6bc0; } .gallery-header .write-button { background-color: #444; color: #5c6bc0; border-color: #666; display: inline-flex !important; } .gallery-options { border-bottom-color: #555; } .gallery-options > .tab-button, .gallery-options select { color: #aaa; border-right-color: #555; } .gallery-options > .gallery-actions { border-right: none; } .gallery-options > .tab-button.active { color: #5c6bc0; border-bottom-color: #5c6bc0; } .gallery-options select { color: #aaa; background-color: transparent; } .post-item { border-bottom-color: #484848; } .post-row .col-title .post-title-label { color: #e0e0e0; } .post-row::after { background-color: #2a2a2a; border-left-color: #444; border-top-color: #444; } .post-row .comment-count { color: #ff7a75 !important; } .post-row .col-writer { color: #bbb; } .post-row .col-date, .post-row .col-view, .post-row .col-recommend { color: #999; } .post-row .col-date::before, .post-row .col-view::before, .post-row .col-recommend::before { color: #666; } .post-row .col-view::before { color: #999; } .post-row .col-recommend::before { color: #999; } .post-content-wrapper { border-top-color: #4f4f4f; background-color: #1e1e1e;} .post-full-content span { color: #e0e0e0;} .post-full-content span img { border-color: #4f4f4f;} .comments-section { border-top-color: #4f4f4f; padding: 10px 0 5px 10px; } .comments-section h4 { color: #e0e0e0; } .comment-item { border-top-color: #5a5a5a; } .comment-author { color: #e0e0e0; } .comment-author .writer-ip { color: #999;} .comment-text { color: #e0e0e0; } } } </style>
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
                    local nai_pattern = "(<NAI%d+>)"
                    local markerPattern = "(<!--%s*DCINSIDE_[^%s%-]+%s*-->)"

                    while true do
                        local naiStart, naiEnd, naiTag = string.find(rawPostContent, nai_pattern, last_end)
                        local markerStart, markerEnd, markerTag = string.find(rawPostContent, markerPattern, last_end)
                        local next_element_start, next_element_end, next_element_match, is_marker

                        if naiStart and markerStart then
                            if naiStart < markerStart then
                                next_element_start, next_element_end, next_element_match, is_marker = naiStart, naiEnd, naiTag, false
                            else
                                next_element_start, next_element_end, next_element_match, is_marker = markerStart, markerEnd, markerTag, true
                            end
                        elseif naiStart then
                            next_element_start, next_element_end, next_element_match, is_marker = naiStart, naiEnd, naiTag, false
                        elseif markerStart then
                            next_element_start, next_element_end, next_element_match, is_marker = markerStart, markerEnd, markerTag, true
                        else
                            break
                        end

                        local text_part = string.sub(rawPostContent, last_end, next_element_start - 1)
                        local processed_text = escapeHtml(text_part)
                        processed_text = string.gsub(processed_text, "\n", "<br>")
                        processed_text = string.gsub(processed_text, "\r", "")
                        postContentDisplayHtml = postContentDisplayHtml .. processed_text

                        if not is_marker then
                            postContentDisplayHtml = postContentDisplayHtml .. next_element_match
                        end

                        last_end = next_element_end + 1
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

                        local buttonJsonBody = '{"action":"DC_REROLL", "identifier":"' .. (postId or "") .. '"}'
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
    local NAIMESSENGERNOIMAGE = getGlobalVar(triggerId, "toggle_NAIMESSENGERNOIMAGE")

    data = data .. [[
## Messenger Interface

### KakaoTalk Interface Template
- KAKAO[(Message)|(Message Timeline)]
- Message: {{char}}'s KAKAOTALK Message.
    - NO '[', '|', ']' ALLOWED at HERE!!!
]]

    if NAIMESSENGERNOIMAGE == "0" then
        data = data .. [[
	- When  {{char}} sends a picture or photo, print it will exactly output '<NAI>'.
	- DO NOT PRINT <NAI> MORE THAN ONCE.
    - ALWAYS PRINT WITH SHORTENED MESSAGE.
]]
    end

    data = data .. [[
- TIME: KAKAOTALK Message sent timeline with hh:mm AP/PM.

- Example:
    - KAKAO[What's the matter, {{user}}?|01:45 AM]
    - KAKAO[You must be very bored.|01:45 AM]
    - KAKAO[Would you like to chat with me for a bit? Hehe|01:46 AM]
]]

    if NAIMESSENGERNOIMAGE == "0" then
        data = data .. [[
	- KAKAO[<NAI>|01:46 AM]        
]]
    end

    return data
end

local function changeKAKAOTalk(triggerId, data)
    local NAIMESSENGERNOIMAGE = getGlobalVar(triggerId, "toggle_NAIMESSENGERNOIMAGE")
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
    local messageContent
    local overlayContent = ""
    local uniqueId = ""
    local fullTagMatch = string.match(message, "({{inlay::[^}]+}})")

    if fullTagMatch then
        imageCounter = imageCounter + 1
        uniqueId = "fs-toggle-" .. imageCounter
        local cleanedTag = string.gsub(fullTagMatch, "%s*%<%!%-%- KAKAO%_%d+ %-%->%s*", "")
        messageContent = cleanedTag
        overlayContent = cleanedTag
    else
        messageContent = escapeHtml(message)
        overlayContent = ""
    end

    local html = {}
    
    table.insert(html, charMessageTemplate)
    table.insert(html, '<div class="message-group">')

    if fullTagMatch then
        if NAIMESSENGERNOIMAGE == "0" then
        table.insert(html, '<input type="checkbox" id="' .. uniqueId .. '" class="fullscreen-toggle">')
        else 
        table.insert(html, '<input type="checkbox" id="" class="fullscreen-toggle">')
        end
    end

    table.insert(html, '<div class="profile-column">')
    table.insert(html, '<img src="{{source::char}}" alt="Profile" class="profile-image">')
    table.insert(html, '</div>')
    
    table.insert(html, '<div class="content-column">')
    table.insert(html, '<div class="username">{{char}}</div>')
    table.insert(html, '<div class="message-bubble-container">')
    table.insert(html, '<div class="message-bubble">')
    
    if fullTagMatch then
        table.insert(html, '<label class="message-text-label clickable-image-label" for="' .. uniqueId .. '">')
    else
        table.insert(html, '<label class="message-text-label">')
    end
    table.insert(html, messageContent)
    table.insert(html, '</label>')
    
    table.insert(html, '</div>')
    table.insert(html, '<div class="timestamp">' .. timestamp .. '</div>')
    table.insert(html, '</div>')
    table.insert(html, '</div>')

    if fullTagMatch then
        table.insert(html, '<div class="fullscreen-overlay">')
        table.insert(html, '<label for="' .. uniqueId .. '" class="fullscreen-close-label"></label>')

        if NAIMESSENGERNOIMAGE == "0" then
        local buttonJsonBody = '{"action":"KAKAO_REROLL", "identifier":"KAKAO_' .. timestamp .. '"}'
        table.insert(html, '<div style="position: relative; display: flex; flex-direction: column; justify-content: center; align-items: center;">')
        table.insert(html, overlayContent)
        table.insert(html, '<div class="reroll-button-wrapper" style="margin-top: 10px; z-index: 2;">')
        table.insert(html, '<div class="global-reroll-controls">')
        table.insert(html, '<button style="text-align: center;" class="reroll-button" risu-btn=\'' .. buttonJsonBody .. '\'>KAKAO</button>')
        table.insert(html, '</div></div>')
        table.insert(html, '</div>')
        end
        
        table.insert(html, '</div>')
    end

    table.insert(html, '</div>')

    return table.concat(html)
    end)
    return data
end

local function inputImage(triggerId, data)
    local NAICARD = getGlobalVar(triggerId, "toggle_NAICARD")
    local NAICARDNOIMAGE = getGlobalVar(triggerId, "toggle_NAICARDNOIMAGE")
    local NAICARDTARGET = getGlobalVar(triggerId, "toggle_NAICARDTARGET")

    local NAISNS = getGlobalVar(triggerId, "toggle_NAISNS")
    local NAISNSNOIMAGE = getGlobalVar(triggerId, "toggle_NAISNSNOIMAGE")
    local NAISNSTARGET = getGlobalVar(triggerId, "toggle_NAISNSTARGET")

    local NAICOMMUNITY = getGlobalVar(triggerId, "toggle_NAICOMMUNITY")
    local NAICOMMUNITYNOIMAGE = getGlobalVar(triggerId, "toggle_NAICOMMUNITYNOIMAGE")

    local NAIMESSENGER = getGlobalVar(triggerId, "toggle_NAIMESSENGER")
    local NAIMESSENGERNOIMAGE = getGlobalVar(triggerId, "toggle_NAIMESSENGERNOIMAGE")

    local NAICOMPATIBILITY = getGlobalVar(triggerId, "toggle_NAICOMPATIBILITY")
    local NAIORIGINAL = getGlobalVar(triggerId, "toggle_NAIORIGINAL")
    local NAIORIGINALTEXT = getGlobalVar(triggerId, "toggle_NAIORIGINALTEXT")
    
    
    data = data .. [[
## Image Prompt- This prompt must describe situations, settings, and actions related to the Character in vivid and detailed language.

### Image Prompt Extraction
- From the narrative, extract details to construct a comprehensive Prompt.

### Image Prompt Placeholder
- Focus on the situation the Character is in.
- The Image Prompt must be written in English and be detailed and descriptive.
- REPLACE the PLACEHOLDER in the PROMPT:
	- PLACEHOLDER:
		- (SITUATION):
			- Normal situation: Do not print anything.
			- NSFW SITUATION:
				- Bodypart not exposed: Print '{{NSFW}}'
				- Breasts or nipples exposed: Print '{{NSFW}}'
				- Pussy exposed: Print '{{NSFW, Uncensored}}'
		- (LABEL):
			- ONLY 1 Character.
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
    if NAICARD == "1" then
        data = data .. [[
			- NAISTATUSPROMPT + INDEX
			- NEG_NAISTATUSPROMPT + INDEX
]]
    elseif NAICARD == "2" then
        data = data .. [[
			- NAISIMULCARDPROMPT + INDEX
			- NEG_NAISIMULCARDPROMPT + INDEX
]] 
    elseif NAICARD == "3" then
        data = data .. [[
            - For female:
                - NAISTATUSPROMPT + INDEX
                - NEG_NAISTATUSPROMPT + INDEX
            - For male:
                - NAISIMULCARDPROMPT + INDEX
                - NEG_NAISIMULCARDPROMPT + INDEX
]]
    end

    if NAISNS == "1" then
        data = data .. [[
			- NAISNSPROMPT
			- NEG_NAISNSPROMPT
]]
    end

    if NAICOMMUNITY == "1" then
        data = data .. [[
			- NAIDCPROMPT + INDEX
			- NEG_NAIDCPROMPT + INDEX
]]
    end

    if NAIMESSENGER == "1" then
        data = data .. [[
			- NAIKAKAOPROMPT
			- NEG_NAIKAKAOPROMPT
]]
    end

    data = data .. [[
### NEGATIVE PROMPT Template
- Write up to 30 keywords that should be avoided by Image as a negative prompt.
- You must print out carefully to increase the accuracy rate of the prompts.
- EXAMPLE: If the Character's hairstyle is long twin-tail.
	- Negative: 'ponytail, short hair, medium hair'
- Example:
	- [NEG_PROMPTPLACEHOLDER: 1girl,female,...]

### Image Prompt Usage
- DO NOT INCLUDE ( AND ) when REPLACING PLACEHOLDER
- NEVER refer to the past chat history when outputting the prompt below:
]]

    if NAICARDNOIMAGE == "0" then
        if NAICARD == "1" then
            data = data .. [[
    - ALWAYS PRINT OUT EROTIC STATUS INTERFACE PROMPT and NEGATIVE PROMPT at the BELOW of the EROTIC STATUS INTERFACE
    - Output Format:
        - EROSTATUS[...|INLAY:<NAI1>]
        - [NAISTATUSPROMPT1:(SITUATION),(LABEL),portrait,cowboy shot,(ACTIONS),(EXPRESSIONS),(AGE),(APPEARANCE),(BODY),(DRESSES),(PLACE),(SCENE)]
        - [NEG_NAISTATUSPROMPT1:(NEGATIVE PROMPT)]
        - EROSTATUS[...|INLAY:<NAI2>]
        - [NAISTATUSPROMPT2:(SITUATION),(LABEL),portrait,cowboy shot,(ACTIONS),(EXPRESSIONS),(AGE),(APPEARANCE),(BODY),(DRESSES),(PLACE),(SCENE)]
        - [NEG_NAISTATUSPROMPT2:(NEGATIVE PROMPT)]
        - ..., etc.
]]
        elseif NAICARD == "2" then
            data = data .. [[
    - ALWAYS PRINT OUT SIMULATION STATUS INTERFACE PROMPT and NEGATIVE PROMPT at the BELOW of the SIMULATION STATUS INTERFACE
    - Output Format:
        - SIMULSTATUS[...|INLAY:<NAI1>]
        - [NAISIMULCARDPROMPT1:(SITUATION),(LABEL),detailed face,portrait,upper body,white background,simple background,(ACTIONS),(EXPRESSIONS),(AGE),(APPEARANCE),(BODY),(DRESSES),(PLACE),(SCENE)]
        - [NEG_NAISIMULCARDPROMPT1:(NEGATIVE PROMPT)]
        - SIMULSTATUS[...|INLAY:<NAI2>]
        - [NAISIMULCARDPROMPT2:(SITUATION),(LABEL),detailed face,portrait,upper body,white background,simple background,(ACTIONS),(EXPRESSIONS),(AGE),(APPEARANCE),(BODY),(DRESSES),(PLACE),(SCENE)]
        - [NEG_NAISIMULCARDPROMPT2:(NEGATIVE PROMPT)]
        - ..., etc.
]]
        elseif NAICARD == "3" then
            data = data .. [[
    - ALWAYS PRINT OUT EROTIC STATUS INTERFACE PROMPT for FEMALE, SIMULATION STATUS INTERFACE PROMPT for MALE and NEGATIVE PROMPT at the BELOW of the SIMULATION STATUS INTERFACE
    - Output Format:
        - EROSTATUS[...|INLAY:<NAI1>]  --> FEMALE
        - [NAISTATUSPROMPT1:(SITUATION),(LABEL),detailed face,portrait,upper body,white background,simple background,(ACTIONS),(EXPRESSIONS),(AGE),(APPEARANCE),(BODY),(DRESSES),(PLACE),(SCENE)]
        - [NEG_NAISTATUSPROMPT1:(NEGATIVE PROMPT)]
        - SIMULSTATUS[...|INLAY:<NAI2>]  --> MALE
        - [NAISIMULCARDPROMPT2:(SITUATION),(LABEL),detailed face,portrait,upper body,white background,simple background,(ACTIONS),(EXPRESSIONS),(AGE),(APPEARANCE),(BODY),(DRESSES),(PLACE),(SCENE)]
        - [NEG_NAISIMULCARDPROMPT2:(NEGATIVE PROMPT)]
        - ..., etc.
]]
        end
    end

    if NAISNSNOIMAGE == "0" then
        if NAISNS == "1" then
            data = data .. [[
    - ALWAYS PRINT OUT TWITTER INTERFACE PROMPT and NEGATIVE PROMPT at the BELOW of the TWITTER INTERFACE
    - Output Format:
        - TWITTER[...|<NAI>|...|<NAI>|...]
        - [NAISNSPROMPT:(SITUATION),(LABEL),portrait,cowboy shot,(ACTIONS),(EXPRESSIONS),(APPEARANCE),(BODY), (DRESSES),(PLACE),(SCENE)]
        - [NEG_NAISNSPROMPT:(NEGATIVE PROMPT)]
        - If Character does not have own profile image:
            - [NAISNSPROFILEPROMPT:(LABEL),(AGE),(APPEARANCE),portrait,face,close-up,white background,simple background]
            - [NEG_NAISNSPROFILEPROMPT:(NEGATIVE PROMPT)]
]]
        end
    end

    if NAICOMMUNITYNOIMAGE == "0" then
        if NAICOMMUNITY == "1" then
            data = data .. [[
    - ALWAYS PRINT OUT DCINSIDE INTERFACE PROMPT and NEGATIVE PROMPT at the BELOW of the DCINSIDE INTERFACE
    - Output Format:
        - DC[...|<NAI1>...|<NAI2>...]
        - If the post is normal:
            - [NAIDCPROMPT:(Describe the situation of the normal post)]
        - If the post is Selfie:
            - [NAIDCPROMPT:(SITUATION),(LABEL),(ANGLE),(ACTIONS),(AGE),(APPEARANCE),(BODY),(DRESSES),(PLACE),(SCENE)]
        - [NEG_NAIDCPROMPT:(NEGATIVE PROMPT)]
    - The number of the POST CONTENT including '<NAI>' and the number of the prompt must match.
        - Example: If 3rd POST CONTENT is including '<NAI3>'.
            - [NAIDCPROMPT3:3rd Post's '<NAI3>' Prompt Generated]
            - [NEG_NAIDCPROMPT3:3rd Post's '<NAI3>' (NEGATIVE PROMPT)]
]]
        end
    end

    if NAIMESSENGERNOIMAGE == "0" then
        if NAIMESSENGER == "1" then
            data = data .. [[
    - ALWAYS PRINT OUT KAKAOTALK INTERFACE PROMPT and NEGATIVE PROMPT at the BELOW of the KAKAOTALK INTERFACE
    - Print <NAI> Exactly once when {{char}} sends a picture or image.
    - Output Format:
        - KAKAO[<NAI>|...]
        - [NAIKAKAOPROMPT:(SITUATION),(LABEL),Selfie,portrait,cowboy shot,(ACTIONS),(EXPRESSIONS),(APPEARANCE),(BODY),(DRESSES),(PLACE),(SCENE)]
        - [NEG_NAIKAKAOPROMPT:(NEGATIVE PROMPT)]
]]
        end
    end

    data = data .. [[
#### IMPORTANT
- This Image Prompt must be suitable for generating an image.
- Use quick, simple keywords or short descriptive phrases.
- Always keep the prompt output in English.
]]
    if NAIORIGINAL == "1" then
        data = data .. [[
- The original creation exists: ]] .. NAIORIGINALTEXT .. [[

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

    if tonumber(NAICOMPATIBILITY) >= 1 then
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
    local NAICARD = getGlobalVar(triggerId, "toggle_NAICARD")
    local NAISNS = getGlobalVar(triggerId, "toggle_NAISNS")
    local NAICOMMUNITY = getGlobalVar(triggerId, "toggle_NAICOMMUNITY")
    local NAIMESSENGER = getGlobalVar(triggerId, "toggle_NAIMESSENGER")
    local NAIMESSENGERNOIMAGE = getGlobalVar(triggerId, "toggle_NAIMESSENGERNOIMAGE")

    data = data .. [[

# CRITICAL
- FROM NOW ON, YOU MUST FOLLOW THE BELOW RULES WHEN YOU ARE PRINTING DIALOGUES
]]

    if NAICARD == "1" then
        data = data .. [[
## CRITICAL: EROTIC STATUS INTERFACE
- DO NOT PRINT FEMALE CHARACTER's "MESSAGE" OUTSIDE of the EROSTATUS[...] BLOCK
    - MUST REPLACE ALL FEMALE CHARACTER's "MESSAGE" to EROSTATUS[...|DIALOGUE:MESSAGE|...]
- BODYINFO and OUTFITS MUST BE PRINTED with USER's PREFERRED LANGUAGE
]]
    elseif NAICARD == "2" then
        data = data .. [[
## CRITICAL: SIMULATION STATUS INTERFACE
- DO NOT PRINT "MESSAGE" OUTSIDE of the SIMULSTATUS[...] BLOCK
    - MUST REPLACE "MESSAGE" to SIMULSTATUS[...|DIALOGUE:MESSAGE|...]
]]
    elseif NAICARD == "3" then
        data = data .. [[
## CRITICAL: EROTIC STATUS INTERFACE
- DO NOT PRINT FEMALE CHARACTER's "MESSAGE" OUTSIDE of the EROSTATUS[...] BLOCK
    - MUST REPLACE ALL FEMALE CHARACTER's "MESSAGE" to EROSTATUS[...|DIALOGUE:MESSAGE|...]
- BODYINFO and OUTFITS MUST BE PRINTED with USER's PREFERRED LANGUAGE
## CRITICAL: SIMULATION STATUS INTERFACE
- DO NOT PRINT MALE CHARACTER's "MESSAGE" OUTSIDE of the SIMULSTATUS[...] BLOCK
    - MUST REPLACE "MESSAGE" to SIMULSTATUS[...|DIALOGUE:MESSAGE|...]
]]
    end

    if NAIMESSENGER == "1" then
        data = inputKAKAOTalk(triggerId, data)
    end
    return data
end


listenEdit("editInput", function(triggerId, data)
    if not data or data == "" then return "" end

    local artistPrompt = nil
    local qualityPrompt = nil
    local negativePrompt = nil
    local NAIPRESETPROMPT = getGlobalVar(triggerId, "toggle_NAIPRESETPROMPT")
    local NAICARD = getGlobalVar(triggerId, "toggle_NAICARD")
    local NAISNS = getGlobalVar(triggerId, "toggle_NAISNS")
    local NAICOMMUNITY = getGlobalVar(triggerId, "toggle_NAICOMMUNITY")
    local NAIMESSENGER = getGlobalVar(triggerId, "toggle_NAIMESSENGER")
    local NAICARDNOIMAGE = getGlobalVar(triggerId, "toggle_NAICARDNOIMAGE")
    local NAISNSNOIMAGE = getGlobalVar(triggerId, "toggle_NAISNSNOIMAGE")
    local NAICOMMUNITYNOIMAGE = getGlobalVar(triggerId, "toggle_NAICOMMUNITYNOIMAGE")
    local NAIMESSENGERNOIMAGE = getGlobalVar(triggerId, "toggle_NAIMESSENGERNOIMAGE")
    
    print("ONLINEMODULE: editInput: called with data: " .. tostring(data))

    if NAIMESSENGER == "1" then
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
    local NAICARD = getGlobalVar(triggerId, "toggle_NAICARD")
    local NAISNS = getGlobalVar(triggerId, "toggle_NAISNS")
    local NAICOMMUNITY = getGlobalVar(triggerId, "toggle_NAICOMMUNITY")
    local NAIMESSENGER = getGlobalVar(triggerId, "toggle_NAIMESSENGER")
    local NAIGLOBAL = getGlobalVar(triggerId, "toggle_NAIGLOBAL")
    local UTILFORCEOUTPUT = getGlobalVar(triggerId, "toggle_UTILFORCEOUTPUT")

    local currentInput = nil
    local currentIndex = nil

    local convertDialogueFlag = false
    local changedValue = false
    
    if UTILFORCEOUTPUT == "1" then
        -- 받아온 리퀘스트 전부 ""변환
        for i = 1, #data, 1 do
            local chat = data[i]
            -- 만약 role이 assistant이라면
            -- 대화 내용 변환
            if chat.role == "assistant" then
                chat.content = convertDialogue(triggerId, chat.content)
                -- 50글자까지 변환된 대화 내용 출력
                print([[ONLINEMODULE: editRequest: Converted dialogue to:

]] .. chat.content)
            end
        end
    end
    
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



    local chat = data[#data]
        -- 가장 마지막에 로직 삽입
    currentInput = chat.content .. [[

<-----ONLINEMODULESTART----->

]]

    if NAIMESSENGER == "0" then
        if NAICARD == "1" then
            currentInput = inputEroStatus(triggerId, currentInput)
            changedValue = true
        elseif NAICARD == "2" then
            currentInput = inputSimulCard(triggerId, currentInput)
            changedValue = true
        elseif NAICARD == "3" then
            currentInput = inputStatusHybrid(triggerId, currentInput)
            changedValue = true
        end
        
        if NAISNS == "1" then
            currentInput = inputTwitter(triggerId, currentInput)
            changedValue = true
        end
        if NAICOMMUNITY == "1" then
            currentInput = inputDCInside(triggerId, currentInput)
            changedValue = true
        end
        
    elseif NAIMESSENGER == "1" then
        currentInput = inputKAKAOTalk(triggerId, currentInput)
        changedValue = true
    end

    if NAIGLOBAL == "1" then
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

    local NAICARD = getGlobalVar(triggerId, "toggle_NAICARD")
    local NAISNS = getGlobalVar(triggerId, "toggle_NAISNS")
    local NAICOMMUNITY = getGlobalVar(triggerId, "toggle_NAICOMMUNITY")
    local NAIMESSENGER = getGlobalVar(triggerId, "toggle_NAIMESSENGER")
    
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
.reroll-button{padding:10px 20px;background-color:#000000;color:#ffffff;border:2px solid #ff69b4;font-family:inherit;font-size:18px;cursor:pointer;transition:all 0.2s ease;flex-shrink:0;min-width:80px;min-height:24px;position:relative;}
.reroll-button::before{content:attr(data-text);white-space:pre;}
.reroll-button::after{content:"REROLL";font-weight:bold;font-size:18px;color:#ffffff;pointer-events:none;transition:color 0.2s ease;}
.reroll-button:hover{background-color:#ff69b4;color:#000000;border-color:#000000;}
.reroll-button:hover::after{color:#000000;}
.reroll-button:active{transform:translateY(1px);}
.global-reroll-controls{text-align:center;margin-top:10px;padding-top:5px;border-top:2px solid #000000;}
</style>
]]   

    data = rerollTemplate .. data

    if NAICARD == "1" then
        data = changeEroStatus(triggerId, data)
    elseif NAICARD == "2" then
        data = changeSimulCard(triggerId, data)
    elseif NAICARD == "3" then
        data = changeEroStatus(triggerId, data)
        data = changeSimulCard(triggerId, data)
    end

    if NAISNS == "1" then
        data = changeTwitter(triggerId, data)
    end
    
    if NAICOMMUNITY == "1" then
        data = changeDCInside(triggerId, data)
    end
    
    if NAIMESSENGER == "1" then
        data = changeKAKAOTalk(triggerId, data)
    end

    -- data = addRerollFormButton(triggerId, data)

    return data
end)

listenEdit("editOutput", function(triggerId, data)
    if not data or data == "" then return "" end
    local NAIMESSENGER = getGlobalVar(triggerId, "toggle_NAIMESSENGER")

    if NAIMESSENGER == "1" then
        print("ONLINEMODULE: editOutput: NAIMESSENGER == 1, filtering to keep only KAKAO blocks")
        
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
                string.find(line, "^%[NAIKAKAOPROMPT:") or
                string.find(line, "^%[NEG_NAIKAKAOPROMPT:")
            ) then
                table.insert(filteredLines, line)
                if string.find(line, "^%[NEG_NAIKAKAOPROMPT:") then
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

    local NAIGLOBAL = getGlobalVar(triggerId, "toggle_NAIGLOBAL")
    local NAICARD = getGlobalVar(triggerId, "toggle_NAICARD")
    local NAISNS = getGlobalVar(triggerId, "toggle_NAISNS")
    local NAISNSNOIMAGE = getGlobalVar(triggerId, "toggle_NAISNSNOIMAGE")
    local NAISNSTARGET = getGlobalVar(triggerId, "toggle_NAISNSTARGET")
    local NAICOMMUNITY = getGlobalVar(triggerId, "toggle_NAICOMMUNITY")
    local NAIMESSENGER = getGlobalVar(triggerId, "toggle_NAIMESSENGER")
    local UTILREMOVEPREVIOUSDISPLAY = getGlobalVar(triggerId, "toggle_UTILREMOVEPREVIOUSDISPLAY")

    if NAISNS == "1" then
        if NAISNSNOIMAGE == "1" then
            if NAISNSTARGET == "2" then
                alertNormal(triggerId, "ERROR: SETTING: NAISNS=1;NAISNSNOIMAGE=1;NAISNSTARGET=2;")
                return
            end
        end
    end
    
    if NAIMESSENGER == "1" then
        if tonumber(NAICARD) >= 1 then
            alertNormal(triggerId, "ERROR: SETTING: NAIMESSENGER=1;NAICARD>=1;")
        elseif tonumber(NAISNS) >= 1 then
            alertNormal(triggerId, "ERROR: SETTING: NAIMESSENGER=1;NAISNS>=1;")
        elseif tonumber(NAICOMMUNITY) >= 1 then
            alertNormal(triggerId, "ERROR: SETTING: NAIMESSENGER=1;NAICOMMUNITY>=1;")
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
    local prefixesToWrap = {"EROSTATUS", "SIMULSTATUS", "TWITTER", "DC"}
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
    local NAIGLOBAL = getGlobalVar(triggerId, "toggle_NAIGLOBAL")
    if NAIGLOBAL == "0" then
        return
    end
    
	local artistPrompt = nil
    local qualityPrompt = nil
    local negativePrompt = nil
    local NAIPRESETPROMPT = getGlobalVar(triggerId, "toggle_NAIPRESETPROMPT")
    local NAICARD = getGlobalVar(triggerId, "toggle_NAICARD")
    local NAISNS = getGlobalVar(triggerId, "toggle_NAISNS")
    local NAICOMMUNITY = getGlobalVar(triggerId, "toggle_NAICOMMUNITY")
    local NAIMESSENGER = getGlobalVar(triggerId, "toggle_NAIMESSENGER")
    local NAICARDNOIMAGE = getGlobalVar(triggerId, "toggle_NAICARDNOIMAGE")
    local NAISNSNOIMAGE = getGlobalVar(triggerId, "toggle_NAISNSNOIMAGE")
    local NAICOMMUNITYNOIMAGE = getGlobalVar(triggerId, "toggle_NAICOMMUNITYNOIMAGE")
    local NAIMESSENGERNOIMAGE = getGlobalVar(triggerId, "toggle_NAIMESSENGERNOIMAGE")
	
	if NAIPRESETPROMPT == "0" then
        artistPrompt = getGlobalVar(triggerId, "toggle_NAIARTISTPROMPT")
        qualityPrompt = getGlobalVar(triggerId, "toggle_NAIQUALITYPROMPT")
        negativePrompt = getGlobalVar(triggerId, "toggle_NAINEGPROMPT")
    elseif NAIPRESETPROMPT == "1" then
		artistPrompt = "{{{artist:Goldcan9, artist:shiba}}}, {artist:sakurai norio,year 2023},{artist: torino}, [[[[[[[[artist: eonsang]]]]]]]], artist: gomzi, {year 2025, year 2024}"
		qualityPrompt = "best quality, amazing quality, very aesthetic, highres, incredibly absurdres"
		negativePrompt = "{{{worst quality}}}, {{{bad quality}}}, {{{censored}}}, reference, unfinished, unclear fingertips, twist, Squiggly, Grumpy, incomplete, {{Imperfect Fingers}}, Cheesy, {{very displeasing}}, {{mess}}, {{Approximate}}, {{monochrome}}, {{greyscale}}, {{{{mascot}}}}, {{{{puppet}}}}, {{{{character doll}}}}, {{{{pet}}}}, {{{{cake}}}}, {{{{stuffed toy}}}}, aged down, furry, sagging breasts, {multiple views}, pastie, maebari, animals, crowd, multiple girls, {eyeball}, {empty eyes}, {slit pupils}, {bright pupils}, {{sketch}}, {{flat color}}, censored, bestiality, from below, 3D"
	elseif NAIPRESETPROMPT == "2" then
		artistPrompt = "artist:mery (yangmalgage), artist:ikeuchi tanuma, artist:hiro (dismaless), {{{artist:ciloranko}}}, {{{{artist:kawakami rokkaku}}}}, artist:ohisashiburi, artist:freng, [[artist:bee (deadflow), artist:healthyman)]], {artist:baffu}, [[artist:deadnooodles]], [[artist:jyt]], {{{artist:yd (orange maru)}}}, [[92m, fkey, iuui]], [[[artist:ie (raarami), artist:mankai kaika, artist:toma (toma50)]]], {year 2025, year 2024}"
		qualityPrompt = "Detail Shading, {{{{{{{{{{amazing quality}}}}}}}}}}, very aesthetic, highres, incredibly absurdres"
		negativePrompt = "{{{{{{{{worst quality, bad quality, japanese text}}}}}}}}, {{{{bad hands, closed eyes}}}}, {{{bad eyes, bad pupils, bad glabella}}}, {{{undetailed eyes}}}, multiple views, error, extra digit, fewer digits, jpeg artifacts, signature, watermark, username, reference, {{unfinished}}, {{unclear fingertips}}, {{twist}}, {{squiggly}}, {{grumpy}}, {{incomplete}}, {{imperfect fingers}}, disorganized colors, cheesy, {{very displeasing}}, {{mess}}, {{approximate}}, {{sloppiness}}"
	elseif NAIPRESETPROMPT == "3" then
		artistPrompt = "0.7::artist:taesi::, 0.6::artist:shiratama (shiratamaco)::,0.8::artist:ningen mame::, 1.3::artist:tianliang duohe fangdongye::, 1.3::artist:shuz::, 0.8::artist:wlop::, 0.9::artist:kase daiki::, 0.6::artist:chobi (penguin paradise)::,{year 2025, year 2024}"
		qualityPrompt = "Detail Shading, {{{{{{{{{{amazing quality}}}}}}}}}}, very aesthetic, highres, incredibly absurdres"
		negativePrompt = "{{{blurry}}},{{{{{{{{worst quality, bad quality, japanese text}}}}}}}}, {{{{bad hands, closed eyes}}}}, {{{bad eyes, bad pupils, bad glabella}}}, {{{undetailed eyes}}}, multiple views, error, extra digit, fewer digits, jpeg artifacts, signature, watermark, username, reference, {{unfinished}}, {{unclear fingertips}}, {{twist}}, {{squiggly}}, {{grumpy}}, {{incomplete}}, {{imperfect fingers}}, disorganized colors, cheesy, {{very displeasing}}, {{mess}}, {{approximate}}, {{sloppiness}}"
    elseif NAIPRESETPROMPT == "4" then
        artistPrompt = "1.3::artist:tianliang duohe fangdongye ::,1.2::artist:shuz ::, 0.7::artist:wlop ::, 1.0::artist:kase daiki ::,0.8::artist:ningen mame ::,0.8::artist:voruvoru ::,0.8::artist:tomose_shunsaku ::,0.7::artist:sweetonedollar ::,0.7::artist:chobi (penguin paradise) ::,0.8::artist:rimo ::,{year 2024, year 2025}"
        qualityPrompt = "Detail Shading, {{{{{{{{{{amazing quality}}}}}}}}}}, very aesthetic, highres, incredibly absurdres"
        negativePrompt = "dark lighting,{{{blurry}}},{{{{{{{{worst quality, bad quality, japanese text}}}}}}}}, {{{{bad hands, closed eyes}}}}, {{{bad eyes, bad pupils, bad glabella}}}, {{{undetailed eyes}}}, multiple views, error, extra digit, fewer digits, jpeg artifacts, signature, watermark, username, reference, {{unfinished}}, {{unclear fingertips}}, {{twist}}, {{squiggly}}, {{grumpy}}, {{incomplete}}, {{imperfect fingers}}, disorganized colors, cheesy, {{very displeasing}}, {{mess}}, {{approximate}}, {{sloppiness}}, dark lighting,{{{blurry}}},{{{{{{{{worst quality, bad quality, japanese text}}}}}}}}, {{{{bad hands, closed eyes}}}}, {{{bad eyes, bad pupils, bad glabella}}}, {{{undetailed eyes}}}, multiple views, error, extra digit, fewer digits, jpeg artifacts, signature, watermark, username, reference, {{unfinished}}, {{unclear fingertips}}, {{twist}}, {{squiggly}}, {{grumpy}}, {{incomplete}}, {{imperfect fingers}}, disorganized colors, cheesy, {{very displeasing}}, {{mess}}, {{approximate}}, {{sloppiness}}"
    elseif NAIPRESETPROMPT == "5" then
        artistPrompt = "{healthyman}, [[[as109]]], [[[quasarcake]]], [[[mikozin]]], [[kidmo]], chen bin, year 2024"
        qualityPrompt = "Detail Shading, {{{{{{{{{{amazing quality}}}}}}}}}}, very aesthetic, highres, incredibly absurdres"
        negativePrompt = "worst quality, bad quality, displeasing, very displeasing, lowres, bad anatomy, bad perspective, bad proportions, bad aspect ratio, bad face, long face, bad teeth, bad neck, long neck, bad arm, bad hands, bad ass, bad leg, bad feet, bad reflection, bad shadow, bad link, bad source, wrong hand, wrong feet, missing limb, missing eye, missing tooth, missing ear, missing finger, extra faces, extra eyes, extra eyebrows, extra mouth, extra tongue, extra teeth, extra ears, extra breasts, extra arms, extra hands, extra legs, extra digits, fewer digits, cropped head, cropped torso, cropped shoulders, cropped arms, cropped legs, mutation, deformed, disfigured, unfinished, chromatic aberration, text, error, jpeg artifacts, watermark, scan, scan artifacts"
    elseif NAIPRESETPROMPT == "6" then
        artistPrompt = "(artist:nakta, artist: m (m073111), artist: mamei mema, artist:ningen_mame, artist:ciloranko, artist:sho_(sho_lwlw), artist:tianliang duohe fangdongye)"
        qualityPrompt = "volumetric lighting, very awa, very aesthetic, masterpiece, best quality, amazing quality, absurdres"
        negativePrompt = "worst quality, blurry, old, early, low quality, lowres, signature, username, logo, bad hands, mutated hands, ambiguous form, (censored, bar censor), mature female, colored skin, censored genitalia, censorship, unfinished, anthro, furry"
    end
    	
	print("-----------------------ART PROMPT-----------------------")
	print(artistPrompt)
	print(qualityPrompt)
	print(negativePrompt)
	print("-----------------------ART PROMPT-----------------------")
	

    print("ONLINEMODULE: onOutput: NAICARD value:", NAICARD)
    print("ONLINEMODULE: onOutput: NAISNS value:", NAISNS)
	print("ONLINEMODULE: onOutput: NAICOMMUNITY value:", NAICOMMUNITY)
    print("ONLINEMODULE: onOutput: NAIMESSENGER value:", NAIMESSENGER)
    

    if NAIMESSENGER == "1" then
        print("ONLINEMODULE: onOutput: FORCE SETTING VALUES to 0")
        NAICARD = "0"
        NAISNS = "0"
        NAICOMMUNITY = "0"
    end

    local togglesActive = NAICARD ~= "0" or NAISNS ~= "0" or NAICOMMUNITY ~= "0" or NAIMESSENGER ~= "0"

    if not togglesActive then
        print("ONLINEMODULE: onOutput: Skipping NAI generation modifications as all relevant toggles are off.")
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
    
    local skipNAICARD = false
    local skipNAISNS = false
    local skipNAICOMMUNITY = false
    local skipNAIMESSENGER = false
    
    if NAICARDNOIMAGE == "1" then skipNAICARD = 1 end
    if NAISNSNOIMAGE == "1" then skipNAISNS = 1 end
    if NAICOMMUNITYNOIMAGE == "1" then skipNAICOMMUNITY = 1 end
    if NAIMESSENGERNOIMAGE == "1" then skipNAIMESSENGER = 1 end

    local currentLine = ""

    if togglesActive and lastIndex > 0 then
        local messageData = chatHistoryTable[lastIndex]
        if type(messageData) == "table" and messageData.data and type(messageData.data) == "string" then
            currentLine = messageData.data
            local lineModifiedInThisPass = false

            print("ONLINEMODULE: onOutput: Processing last message (index " .. lastIndex .. ") for NAI Generation/Replacement")

            if NAICARD == "1" and not skipNAICARD then
                print("ONLINEMODULE: onOutput: NAICARD == 1")
                local searchPos = 1
                local statusBlocksFound = 0
                local statusReplacements = {}

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
                        end

                        local blockContent = string.sub(currentLine, e_status_prefix + 1, e_status_suffix - 1)
                        local naiSearchPosInContent = 1
                        local naiTagsFoundInBlock = 0
                        while true do
                            local s_nai_in_content, e_nai_in_content, naiIndexStr = string.find(blockContent, "<NAI(%d+)>", naiSearchPosInContent)
                            if not s_nai_in_content then break end
                            naiTagsFoundInBlock = naiTagsFoundInBlock + 1
                            local naiIndex = tonumber(naiIndexStr)
                            if naiIndex then
                                local statusPromptFindPattern = "%[NAISTATUSPROMPT" .. naiIndex .. ":([^%]]*)%]"
                                local statusNegPromptFindPattern = "%[NEG_NAISTATUSPROMPT" .. naiIndex .. ":([^%]]*)%]"
                                local _, _, foundStatusPrompt = string.find(currentLine, statusPromptFindPattern)
                                local _, _, foundStatusNegPrompt = string.find(currentLine, statusNegPromptFindPattern)
                                local currentNegativePromptStatus = negativePrompt
                                local storedNegPrompt = ""
                                if foundStatusNegPrompt then
                                    currentNegativePromptStatus = foundStatusNegPrompt .. ", " .. currentNegativePromptStatus
                                    storedNegPrompt = foundStatusNegPrompt
                                end
                                if foundStatusPrompt then
                                    local finalPromptStatus = artistPrompt .. foundStatusPrompt .. qualityPrompt
                                    local inlayStatus = generateImage(triggerId, finalPromptStatus, currentNegativePromptStatus):await()
                                    if inlayStatus and type(inlayStatus) == "string" and string.len(inlayStatus) > 10 and not string.find(inlayStatus, "fail", 1, true) and not string.find(inlayStatus, "error", 1, true) and not string.find(inlayStatus, "실패", 1, true) then
                                        local erostatusIdentifier = "EROSTATUS_" .. naiIndex
                                        local marker = "<!-- " .. erostatusIdentifier .. " -->"
                                        local content_offset = e_status_prefix
                                        local nai_abs_start = content_offset + s_nai_in_content
                                        local nai_abs_end = content_offset + e_nai_in_content
                                        table.insert(statusReplacements, {
                                            start = nai_abs_start,
                                            finish = nai_abs_end,
                                            inlay = "<NAI" .. naiIndex .. ">" .. inlayStatus .. marker
                                        })
                                        local infoEro = {
                                            type = "EROSTATUS",
                                            identifier = erostatusIdentifier,
                                            inlay = inlayStatus,
                                            prompt = foundStatusPrompt,
                                            negPrompt = storedNegPrompt
                                        }
                                        table.insert(generatedImagesInfo, infoEro)
                                        setState(triggerId, erostatusIdentifier .. "_PROMPT", infoEro.prompt)
                                        setState(triggerId, erostatusIdentifier .. "_NEGPROMPT", infoEro.negPrompt)
                                        setState(triggerId, erostatusIdentifier, infoEro.inlay)
                                        print("ONLINEMODULE: onOutput: Stored info for generated EROSTATUS image. Identifier: " .. erostatusIdentifier)
                                    end
                                else
                                    ERR(triggerId, "EROSTATUS", 0)
                                    print("ONLINEMODULE: onOutput: Prompt NOT FOUND for NAI" .. naiIndex .. " in currentLine.")
                                end
                            end
                            naiSearchPosInContent = e_nai_in_content + 1
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
                        end
                    end
                    lineModifiedInThisPass = true
                else
                    print("ONLINEMODULE: onOutput: No erostatus replacements to apply.")
                end
            end

            if NAICARD == "2" and not skipNAICARD then
                print("ONLINEMODULE: onOutput: NAICARD == 2 entered.")
                local searchPos = 1
                local simulReplacements = {}
                local statusBlocksFound = 0

                local listKey = "STORED_SIMCARD_IDS"

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
                        local statusBlockPattern = "SIMULSTATUS%[NAME:([^|]*)|DIALOGUE:([^|]*)|TIME:([^|]*)|LOCATION:([^|]*)|INLAY:([^%]]*)%]"
                        local _, _, currentBlockName = string.find(statusBlockContent, statusBlockPattern)

                        if currentBlockName then
                            print("ONLINEMODULE: onOutput: SIMULSTATUS block #" .. statusBlocksFound .. " NAME found: [" .. currentBlockName .. "]")
                        else
                            print("ONLINEMODULE: onOutput: SIMULSTATUS block #" .. statusBlocksFound .. " NAME pattern did not match.")
                        end

                        local existingInlay = nil
                        local trimmedBlockName = nil
                        if currentBlockName then
                            trimmedBlockName = currentBlockName:match("^%s*(.-)%s*$")
                            if trimmedBlockName ~= "" then
                                print("ONLINEMODULE: onOutput: Trimmed NAME: [" .. trimmedBlockName .. "]")
                                existingInlay = getState(triggerId, trimmedBlockName) or "null"
                                if existingInlay == "null" then existingInlay = nil end
                                print("ONLINEMODULE: onOutput: Existing inlay found from chatVar: [" .. tostring(existingInlay) .. "]")
                            else
                                trimmedBlockName = nil
                            end
                        end

                        local simulContent = string.sub(currentLine, e_simul_prefix + 1, e_simul_suffix - 1)
                        local naiSearchPosInContent = 1
                        local naiTagsFoundInBlock = 0

                        if existingInlay and trimmedBlockName then
                            print("ONLINEMODULE: onOutput: Processing with existing inlay for block #" .. statusBlocksFound)
                        while true do
                            local s_nai_in_content, e_nai_in_content, naiIndexStr = string.find(simulContent, "<NAI(%d+)>", naiSearchPosInContent)
                            if not s_nai_in_content then break end
                            naiTagsFoundInBlock = naiTagsFoundInBlock + 1
                            print("ONLINEMODULE: onOutput: Found <NAI> tag #"..naiTagsFoundInBlock.." (using existing inlay)")
                            local naiIndex = tonumber(naiIndexStr)
                            if naiIndex then
                                local content_offset = e_simul_prefix
                                local nai_abs_start = content_offset + s_nai_in_content
                                local nai_abs_end = content_offset + e_nai_in_content
                                table.insert(simulReplacements, { start = nai_abs_start, finish = nai_abs_end, inlay = existingInlay })
                                print("ONLINEMODULE: onOutput: Adding existing inlay replacement for NAI" .. naiIndex .. " at absolute pos " .. nai_abs_start .. "-" .. nai_abs_end)
                            end
                            naiSearchPosInContent = e_nai_in_content + 1
                        end
                        else
                            print("ONLINEMODULE: onOutput: Processing by generating new image for block #" .. statusBlocksFound)
                        while true do
                            local s_nai_in_content, e_nai_in_content, naiIndexStr = string.find(simulContent, "<NAI(%d+)>", naiSearchPosInContent)
                            if not s_nai_in_content then
                                print("ONLINEMODULE: onOutput: No more <NAI> tags found in block #".. statusBlocksFound .." content search.")
                                break
                            end
                            naiTagsFoundInBlock = naiTagsFoundInBlock + 1
                            print("ONLINEMODULE: onOutput: Found <NAI> tag #"..naiTagsFoundInBlock.." (generating new)")
                            local naiIndex = tonumber(naiIndexStr)
                            if naiIndex then
                                local simulPromptPattern = "%[NAISIMULCARDPROMPT" .. naiIndex .. ":([^%]]*)%]"
                                local negSimulPromptPattern = "%[NEG_NAISIMULCARDPROMPT" .. naiIndex .. ":([^%]]*)%]"
                                local _, _, foundSimulPrompt = string.find(currentLine, simulPromptPattern)
                                local _, _, foundNegSimulPrompt = string.find(currentLine, negSimulPromptPattern)

                                if foundSimulPrompt then
                                    print("ONLINEMODULE: onOutput: Found prompt for NAI" .. naiIndex .. ": [" .. string.sub(foundSimulPrompt, 1, 50) .. "...]")
                                    local currentNegativePromptSimul = negativePrompt
                                    local storedNegPrompt = ""
                                    if foundNegSimulPrompt then currentNegativePromptSimul = foundNegSimulPrompt .. ", " .. currentNegativePromptSimul; storedNegPrompt = foundNegSimulPrompt end
                                    local finalPromptSimul = artistPrompt .. foundSimulPrompt .. qualityPrompt
                                    local inlaySimul = generateImage(triggerId, finalPromptSimul, currentNegativePromptSimul):await()
                                    print("ONLINEMODULE: onOutput: generateImage result for NAI"..naiIndex..": ["..tostring(inlaySimul).."]")
                                    local isSuccess = (inlaySimul ~= nil) and (type(inlaySimul) == "string") and (string.len(inlaySimul) > 10) and not string.find(inlaySimul, "fail", 1, true) and not string.find(inlaySimul, "error", 1, true) and not string.find(inlaySimul, "실패", 1, true)
                                    if isSuccess then
                                        print("ONLINEMODULE: onOutput: Image generation SUCCESS for NAI"..naiIndex)
                                        local content_offset = e_simul_prefix 
                                        local nai_abs_start = content_offset + s_nai_in_content
                                        local nai_abs_end = content_offset + e_nai_in_content -1
                                        table.insert(simulReplacements, {
                                            start = nai_abs_start,
                                            finish = nai_abs_end,
                                            inlay = "<NAI" .. naiIndex .. ">" .. inlaySimul
                                        })
                                        print("ONLINEMODULE: onOutput: Adding new inlay replacement for NAI" .. naiIndex .. " at absolute pos " .. nai_abs_start .. "-" .. nai_abs_end)

                                        if trimmedBlockName then
                                            setState(triggerId, trimmedBlockName, inlaySimul)
                                            setState(triggerId, trimmedBlockName .. "_SIMULPROMPT", foundSimulPrompt)
                                            setState(triggerId, trimmedBlockName .. "_NEGSIMULPROMPT", storedNegPrompt)

                                            local currentList = getState(triggerId, listKey) or "null"
                                            if currentList == "null" then currentList = "" end
                                                print("ONLINEMODULE: onOutput: Current list for key '" .. listKey .. "': [" .. currentList .. "]")
                                            local newList = currentList
                                            if not string.find("," .. currentList .. ",", "," .. trimmedBlockName .. ",", 1, true) then
                                                if currentList == "" then
                                                    newList = trimmedBlockName
                                                else
                                                    newList = currentList .. "," .. trimmedBlockName
                                                end
                                                setState(triggerId, listKey, newList)
                                                print("ONLINEMODULE: onOutput: Added SimCard ID '" .. trimmedBlockName .. "' to stored list (" .. listKey .. "). New list: [" .. newList .. "]")
                                            else
                                                print("ONLINEMODULE: onOutput: SimCard ID '" .. trimmedBlockName .. "' already exists in stored list (" .. listKey .. ").")
                                            end
                                            
                                            local infoSimul = {
                                                type = "SIMULATIONCARD", identifier = trimmedBlockName, inlay = inlaySimul,
                                                prompt = foundSimulPrompt, negPrompt = storedNegPrompt
                                            }
                                            table.insert(generatedImagesInfo, infoSimul)
                                            print("ONLINEMODULE: onOutput: Stored info for generated SIMULATIONCARD image: [" .. trimmedBlockName .. "]")

                                            existingInlay = inlaySimul
                                            print("ONLINEMODULE: onOutput: Updated existingInlay for subsequent NAI tags in block #" .. statusBlocksFound)
                                        end
                                    else
                                        ERR(triggerId, "SIMULCARD", 2)
                                        print("ONLINEMODULE: onOutput: Image generation FAILED or invalid result for NAI"..naiIndex)
                                    end
                                else
                                    ERR(triggerId, "SIMULCARD", 0)
                                    print("ONLINEMODULE: onOutput: Prompt NOT FOUND for NAI" .. naiIndex .. " in currentLine.")
                                end
                            end
                            naiSearchPosInContent = e_nai_in_content + 1
                        end
                    end
                    if naiTagsFoundInBlock == 0 then
                        ERR(triggerId, "SIMULCARD", 3)
                        print("ONLINEMODULE: onOutput: No <NAI> tags found within SIMULSTATUS block #"..statusBlocksFound.." content.")
                    end
                    searchPos = e_simul_suffix + 1
                    else
                        ERR(triggerId, "SIMULCARD", 1)
                        print("ONLINEMODULE: onOutput: CRITICAL - Closing bracket ']' not found for SIMULSTATUS block #" .. statusBlocksFound .. " even after nested check! Something is wrong. Skipping to next search pos.")
                        searchPos = e_simul_prefix + 1
                    end
                end

                if statusBlocksFound == 0 then
                    ERR(triggerId, "SIMULCARD", 4)
                    print("ONLINEMODULE: onOutput: No SIMULSTATUS[...] blocks found in the entire message.")
                end

                if #simulReplacements > 0 then
                    print("ONLINEMODULE: onOutput: Applying ".. #simulReplacements .." simulcard replacements.")
                    table.sort(simulReplacements, function(a, b) return a.start > b.start end)
                    for i_rep, rep in ipairs(simulReplacements) do
                        if rep.start > 0 and rep.finish >= rep.start and rep.finish <= #currentLine then
                            currentLine = string.sub(currentLine, 1, rep.start - 1) .. rep.inlay .. string.sub(currentLine, rep.finish + 1)
                        end
                    end
                    lineModifiedInThisPass = true
                else
                    print("ONLINEMODULE: onOutput: No simulcard replacements to apply.")
                end
            end
            
            if NAICARD == "3" and not skipNAICARD then
                print("ONLINEMODULE: onOutput: NAICARD == 3 (Hybrid mode)")
                local searchPos = 1
                local replacements = {}
                local statusBlocksFound = 0
                local listKey = "STORED_SIMCARD_IDS"
                local characterImageCache = {} -- 캐릭터별 이미지 캐시 (시뮬레이션용)

                while true do
                    local s_ero, e_ero = string.find(currentLine, "EROSTATUS%[", searchPos)
                    local s_sim, e_sim = string.find(currentLine, "SIMULSTATUS%[", searchPos)
                    
                    local s_status, e_status_prefix, isEroStatus
                    if s_ero and (not s_sim or s_ero < s_sim) then
                        s_status = s_ero
                        e_status_prefix = e_ero 
                        isEroStatus = true
                    elseif s_sim then
                        s_status = s_sim
                        e_status_prefix = e_sim
                        isEroStatus = false
                    else
                        break 
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
                            local pattern = "NAME:([^|]*)|DIALOGUE:([^|]*)|TIME:([^|]*)|LOCATION:([^|]*)|INLAY:([^%]]*)"
                            local _, _, name = string.find(blockContent, pattern)
                            currentBlockName = name
                        end

                        local trimmedBlockName = nil
                        if currentBlockName then
                            trimmedBlockName = currentBlockName:match("^%s*(.-)%s*$")
                        end

                        -- 시뮬레이션 카드일 때만 캐시 확인/사용
                        local cachedInlay = nil
                        if not isEroStatus and trimmedBlockName then
                            cachedInlay = characterImageCache[trimmedBlockName]
                            if not cachedInlay then
                                local existingInlay = getState(triggerId, trimmedBlockName) or "null"
                                if existingInlay ~= "null" then
                                    characterImageCache[trimmedBlockName] = existingInlay
                                    cachedInlay = existingInlay
                                end
                            end
                        end

                        local naiSearchPosInContent = 1
                        local naiTagsFoundInBlock = 0

                        while true do
                            local s_nai_in_content, e_nai_in_content, naiIndex = string.find(blockContent, "<NAI(%d+)>", naiSearchPosInContent)
                            if not s_nai_in_content then break end
                            naiTagsFoundInBlock = naiTagsFoundInBlock + 1
                            naiIndex = tonumber(naiIndex)

                            if naiIndex then
                                local content_offset = e_status_prefix
                                local nai_abs_start = content_offset + s_nai_in_content
                                local nai_abs_end = content_offset + e_nai_in_content

                                -- 시뮬레이션이고 캐시된 이미지가 있으면 재사용
                                if not isEroStatus and cachedInlay then
                                    print("ONLINEMODULE: onOutput: Reusing cached image for character: " .. trimmedBlockName)
                                    table.insert(replacements, {
                                        start = nai_abs_start,
                                        finish = nai_abs_end,
                                        inlay = "<NAI" .. naiIndex .. ">" .. cachedInlay
                                    })
                                else
                                    -- 새 이미지 생성
                                    local promptPattern, negPromptPattern, promptType, identifier
                                    if isEroStatus then
                                        promptPattern = "%[NAISTATUSPROMPT" .. naiIndex .. ":([^%]]*)%]"
                                        negPromptPattern = "%[NEG_NAISTATUSPROMPT" .. naiIndex .. ":([^%]]*)%]"
                                        promptType = "EROSTATUS"
                                        identifier = "EROSTATUS_" .. naiIndex
                                    else
                                        promptPattern = "%[NAISIMULCARDPROMPT" .. naiIndex .. ":([^%]]*)%]"
                                        negPromptPattern = "%[NEG_NAISIMULCARDPROMPT" .. naiIndex .. ":([^%]]*)%]"
                                        promptType = "SIMULCARD"
                                        identifier = trimmedBlockName
                                    end

                                    local _, _, foundPrompt = string.find(currentLine, promptPattern)
                                    local _, _, foundNegPrompt = string.find(currentLine, negPromptPattern)

                                    if foundPrompt then
                                        local currentNegativePrompt = negativePrompt
                                        local storedNegPrompt = ""
                                        if foundNegPrompt then
                                            currentNegativePrompt = foundNegPrompt .. ", " .. currentNegativePrompt
                                            storedNegPrompt = foundNegPrompt
                                        end

                                        local finalPrompt = artistPrompt .. foundPrompt .. qualityPrompt
                                        local inlay = generateImage(triggerId, finalPrompt, currentNegativePrompt):await()
                                        
                                        if inlay and type(inlay) == "string" and string.len(inlay) > 10 
                                           and not string.find(inlay, "fail", 1, true) 
                                           and not string.find(inlay, "error", 1, true)
                                           and not string.find(inlay, "실패", 1, true) then
                                            
                                            -- 시뮬레이션 카드일 때만 캐시에 저장
                                            if not isEroStatus then
                                                characterImageCache[trimmedBlockName] = inlay
                                            end

                                            local marker = "<!-- " .. identifier .. " -->"
                                            table.insert(replacements, {
                                                start = nai_abs_start,
                                                finish = nai_abs_end,
                                                inlay = "<NAI" .. naiIndex .. ">" .. inlay .. marker
                                            })

                                            local info = {
                                                type = promptType,
                                                identifier = identifier,
                                                inlay = inlay,
                                                prompt = foundPrompt,
                                                negPrompt = storedNegPrompt
                                            }
                                            table.insert(generatedImagesInfo, info)

                                            if isEroStatus then
                                                setState(triggerId, identifier .. "_PROMPT", info.prompt)
                                                setState(triggerId, identifier .. "_NEGPROMPT", info.negPrompt)
                                                setState(triggerId, identifier, info.inlay)
                                            else
                                                setState(triggerId, identifier, inlay)
                                                setState(triggerId, identifier .. "_SIMULPROMPT", foundPrompt)
                                                setState(triggerId, identifier .. "_NEGSIMULPROMPT", storedNegPrompt)

                                                local currentList = getState(triggerId, listKey) or "null"
                                                if currentList == "null" then currentList = "" end
                                                
                                                if not string.find("," .. currentList .. ",", "," .. identifier .. ",", 1, true) then
                                                    local newList = currentList == "" and identifier or (currentList .. "," .. identifier)
                                                    setState(triggerId, listKey, newList)
                                                end
                                            end
                                        else
                                            ERR(triggerId, promptType, 2)
                                        end
                                    else
                                        ERR(triggerId, promptType, 0)
                                    end
                                end
                            end
                            naiSearchPosInContent = e_nai_in_content + 1
                        end

                        if naiTagsFoundInBlock == 0 then
                            ERR(triggerId, isEroStatus and "EROSTATUS" or "SIMULCARD", 3)
                        end
                        searchPos = e_status_suffix + 1
                    else
                        ERR(triggerId, isEroStatus and "EROSTATUS" or "SIMULCARD", 1)
                        searchPos = e_status_prefix + 1
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
                                currentLine = string.sub(currentLine, 1, rep.start - 1) .. rep.inlay .. string.sub(currentLine, rep.finish + 1)
                            end
                        end
                        lineModifiedInThisPass = true
                    end
                end
            end

            if NAISNS == "1" and not skipNAISNS then
                print("ONLINEMODULE: onOutput: NAISNS == 1")
                print("ONLINEMODULE: onOutput: Current line length:", #currentLine)
                
                local twitterPromptFindPattern = "%[NAISNSPROMPT:([^%]]*)%]"
                local twitterNegPromptFindPattern = "%[NEG_NAISNSPROMPT:([^%]]*)%]"
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
                        local profilePromptFindPattern = "%[NAISNSPROFILEPROMPT:([^%]]*)%]"
                        local profileNegPromptFindPattern = "%[NEG_NAISNSPROFILEPROMPT:([^%]]*)%]"
                        
                        local _, _, foundProfilePrompt = string.find(currentLine, profilePromptFindPattern)
                        local _, _, foundProfileNegPrompt = string.find(currentLine, profileNegPromptFindPattern)
                        
                        print("ONLINEMODULE: onOutput: Found profile prompt:", foundProfilePrompt ~= nil)
                        print("ONLINEMODULE: onOutput: Found profile neg prompt:", foundProfileNegPrompt ~= nil)

                        if foundProfilePrompt then
                            local finalPromptTwitterProfile = (artistPrompt or "") .. (foundProfilePrompt or "") .. (qualityPrompt or "")
                            local currentNegativePromptProfile = (negativePrompt or "")
                            local storedNegProfilePrompt = ""
                            
                            if foundProfileNegPrompt then 
                                currentNegativePromptProfile = foundProfileNegPrompt .. ", " .. currentNegativePromptProfile
                                storedNegProfilePrompt = foundProfileNegPrompt 
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
                                setState(triggerId, twitterId, profileInlayToUse)
                                setState(triggerId, "NAISNSPROFILETEMP", profileInlayToUse)
                                setState(triggerId, twitterId .. "_PROFILEPROMPT", foundProfilePrompt)
                                setState(triggerId, twitterId .. "_NEGPROFILEPROMPT", storedNegProfilePrompt)

                                local infoProfile = {
                                    type = "PROFILE",
                                    identifier = twitterId, 
                                    inlay = profileInlayToUse, 
                                    prompt = foundProfilePrompt,
                                    negPrompt = storedNegProfilePrompt
                                }
                                table.insert(generatedImagesInfo, infoProfile)
                                print("ONLINEMODULE: onOutput: Stored generated profile info")
                            else
                                print("ONLINEMODULE: onOutput: Profile image generation failed")
                                ERR(triggerId, "TWITTERPROFILE", 2)
                            end
                        end
                    else
                        print("ONLINEMODULE: onOutput: Using existing profile inlay")
                        profileInlayToUse = existingProfileInlay
                        setState(triggerId, "NAISNSPROFILETEMP", profileInlayToUse)
                    end
                end

                print("ONLINEMODULE: onOutput: Looking for tweet prompt...")
                local _, _, foundTwitterPrompt = string.find(currentLine, twitterPromptFindPattern)
                print("ONLINEMODULE: onOutput: Tweet prompt found:", foundTwitterPrompt ~= nil)

                if foundTwitterPrompt and s_twitter then
                    print("ONLINEMODULE: onOutput: Processing tweet...")
                    local _, _, foundTwitterNegPrompt = string.find(currentLine, twitterNegPromptFindPattern)
                    local currentNegativePromptTwitter = negativePrompt
                    local storedNegTweetPrompt = ""
                    
                    if foundTwitterNegPrompt then 
                        currentNegativePromptTwitter = foundTwitterNegPrompt .. ", " .. currentNegativePromptTwitter
                        storedNegTweetPrompt = foundTwitterNegPrompt 
                    end

                    local finalPromptTwitterTweet = artistPrompt .. foundTwitterPrompt .. qualityPrompt
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
                            "|MEDIA:" .. "<NAI>" .. inlayTwitter ..
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

                        local infoTweet = {
                            type = "TWEET", 
                            identifier = twitterId, 
                            inlay = inlayTwitter,
                            prompt = foundTwitterPrompt,
                            negPrompt = storedNegTweetPrompt
                        }

                        table.insert(generatedImagesInfo, infoTweet)
                        setState(triggerId, twitterId .. "_TWEETPROMPT", infoTweet.prompt)
                        setState(triggerId, twitterId .. "_TWEETNEGPROMPT", infoTweet.negPrompt)
                        setState(triggerId, twitterId .. "_TWEET", infoTweet.inlay)
                        print("ONLINEMODULE: onOutput: Stored generated tweet info")
                    elseif profileInlayToUse then
                        print("ONLINEMODULE: onOutput: Using profile-only replacement")
                        local originalBlockReplacement = "TWITTER[NAME:" .. (twName or "") .. 
                            "|TNAME:" .. (twTname or "") .. 
                            "|TID:" .. (twTid or "") .. 
                            "|TPROFILE:" .. "<NAI>" .. profileInlayToUse ..
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
                        "|TPROFILE:" .. "<NAI>" .. profileInlayToUse ..
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

            if NAICOMMUNITY == "1" and not skipNAICOMMUNITY then
                print("ONLINEMODULE: onOutput: NAICOMMUNITY == 1")
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
                        local naiSearchPosInContent = 1
                        while true do
                            local s_nai_in_content, e_nai_in_content, naiIndexStr = string.find(dcContent, "<NAI(%d+)>", naiSearchPosInContent)
                            if not s_nai_in_content then break end
                            local naiIndex = tonumber(naiIndexStr)

                            local content_start_abs = e_dc_prefix + 1
                            local nai_abs_start = content_start_abs + s_nai_in_content - 1
                            local nai_abs_end = content_start_abs + e_nai_in_content - 1

                            local postId = nil
                            local postIdPattern = "PID:([^|]*)"
                            local s_post, e_post, capturedPostId = findLastPatternBefore(dcContent, postIdPattern, s_nai_in_content)
                            if not capturedPostId then
                                local s_post2, e_post2, capturedPostId2 = findLastPatternBefore(dcContent, "PN:([^|]*)", s_nai_in_content)
                                capturedPostId = capturedPostId2
                            end
                            if capturedPostId and type(capturedPostId) == "string" then
                                postId = capturedPostId:match("^%s*(.-)%s*$")
                                if postId == "" then postId = nil end
                            end

                            if naiIndex and postId then
                                local dcPromptPattern = "%[NAIDCPROMPT" .. naiIndex .. ":([^%]]*)%]"
                                local negDcPromptPattern = "%[NEG_NAIDCPROMPT" .. naiIndex .. ":([^%]]*)%]"
                                local _, _, foundDcPrompt = string.find(currentLine, dcPromptPattern)
                                local _, _, foundNegDcPrompt = string.find(currentLine, negDcPromptPattern)
                                local currentNegativePromptDc = negativePrompt
                                local storedDcNegPrompt = ""
                                if foundNegDcPrompt then currentNegativePromptDc = foundNegDcPrompt .. ", " .. currentNegativePromptDc; storedDcNegPrompt = foundNegDcPrompt end
                                if foundDcPrompt then
                                    local finalPromptDc = artistPrompt .. foundDcPrompt .. qualityPrompt
                                    local successCall, inlayDc = pcall(function() return generateImage(triggerId, finalPromptDc, currentNegativePromptDc):await() end)
                                    local isSuccessDc = successCall and (inlayDc ~= nil) and (type(inlayDc) == "string") and (string.len(inlayDc) > 10) and not string.find(inlayDc, "fail", 1, true) and not string.find(inlayDc, "error", 1, true) and not string.find(inlayDc, "실패", 1, true)
                                    if isSuccessDc then
                                        local dcIdentifier = postId
                                        local marker = "<!-- DC_MARKER_POSTID_" .. dcIdentifier .. " -->"

                                        table.insert(dcReplacements, {
                                            start = nai_abs_start,
                                            finish = nai_abs_end,
                                            inlay = "<NAI" .. naiIndex .. ">" .. inlayDc .. marker 
                                        })

                                        local infoDC = {
                                            type = "DC",
                                            identifier = dcIdentifier,
                                            inlay = inlayDc, 
                                            prompt = foundDcPrompt,
                                            negPrompt = storedDcNegPrompt
                                        }
                                        local alreadyGeneratedForThisPostId = false
                                        local existingIndex = -1
                                        for k, v in ipairs(generatedImagesInfo) do
                                            if v.type == "DC" and v.identifier == dcIdentifier then
                                                alreadyGeneratedForThisPostId = true
                                                existingIndex = k
                                                break
                                            end
                                        end
                                        if alreadyGeneratedForThisPostId then
                                            generatedImagesInfo[existingIndex] = infoDC
                                        else
                                            table.insert(generatedImagesInfo, infoDC)
                                        end

                                        setState(triggerId, "DC_" .. dcIdentifier .. "_PROMPT", infoDC.prompt)
                                        setState(triggerId, "DC_" .. dcIdentifier .. "_NEGPROMPT", infoDC.negPrompt)
                                        setState(triggerId, "DC_" .. dcIdentifier, inlayDc) 
                                    else
                                        ERR(triggerId, "DCINSIDE", 2)
                                        print("ONLINEMODULE: onOutput: ERROR - DC image generation failed...")
                                    end
                                else
                                    ERR(triggerId, "DCINSIDE", 0)
                                    print("ONLINEMODULE: onOutput: WARN - Found <NAI...> tag but no corresponding prompt tag...")
                                end
                            else
                                ERR(triggerId, "DCINSIDE", 3)
                                if not postId then print("ONLINEMODULE: onOutput: WARN - Could not determine Post ID for <NAI" .. (naiIndex or "??") .. "> tag at position " .. nai_abs_start .. ". Skipping.") end
                            end
                            naiSearchPosInContent = e_nai_in_content + 1
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
            
            if NAIMESSENGER == "1" and not skipNAIMESSENGER then
                print("ONLINEMODULE: onOutput: NAIMESSENGER == 1 (KAKAO) processing...")
                local kakaoPromptFindPattern = "%[NAIKAKAOPROMPT:([^%]]*)%]"
                local kakaoNegPromptFindPattern = "%[NEG_NAIKAKAOPROMPT:([^%]]*)%]"
                local kakaoPattern = "(KAKAO)%[(<NAI>)%|([^%]]*)%]"
                local _, _, foundKakaoPrompt = string.find(currentLine, kakaoPromptFindPattern)
                local s_kakao, e_kakao, cap1, cap2, cap3 = string.find(currentLine, kakaoPattern)
                print("Found Prefix: " .. cap1 .. " Found NAI Value: " .. cap2 .. " Found Suffix: " .. cap3)
       
                if foundKakaoPrompt and s_kakao then
                    print("ONLINEMODULE: onOutput: Found KAKAO block and prompt. Generating image...")
                    local _, _, foundKakaoNegPrompt = string.find(currentLine, kakaoNegPromptFindPattern)
                    local currentNegativePromptKakao = negativePrompt or ""
                    local storedNegPrompt = ""
                    if foundKakaoNegPrompt then currentNegativePromptKakao = foundKakaoNegPrompt .. ", " .. currentNegativePromptKakao; storedNegPrompt = foundKakaoNegPrompt end
                    local finalPromptKakao = (artistPrompt or "") .. foundKakaoPrompt .. (qualityPrompt or "")
        
                    local successCall, inlayKakao = pcall(function() return generateImage(triggerId, finalPromptKakao, currentNegativePromptKakao):await() end)
                    local isSuccessKakao = successCall and inlayKakao and type(inlayKakao) == "string" and string.len(inlayKakao) > 10 and not string.find(inlayKakao, "fail", 1, true) and not string.find(inlayKakao, "error", 1, true) and not string.find(inlayKakao, "실패", 1, true)
        
                    if isSuccessKakao then
                        print("ONLINEMODULE: onOutput: KAKAO image generated successfully.")
                        local kakaoIdentifier = "KAKAO_" .. cap3
                        local marker = "<!-- " .. kakaoIdentifier .. " -->"
                        local replacementKakao = "KAKAO[" .. inlayKakao .. marker .. "|" .. cap3 .. "]"
                        currentLine = string.sub(currentLine, 1, s_kakao-1) .. replacementKakao .. string.sub(currentLine, e_kakao + 1)
                        lineModifiedInThisPass = true
        
                        local infoEro = { type = "KAKAO", identifier = kakaoIdentifier, inlay = inlayKakao, prompt = foundKakaoPrompt, negPrompt = storedNegPrompt }
                        table.insert(generatedImagesInfo, infoEro)
                        setState(triggerId, kakaoIdentifier .. "_PROMPT", infoEro.prompt)
                        setState(triggerId, kakaoIdentifier .. "_NEGPROMPT", infoEro.negPrompt)
                        setState(triggerId, kakaoIdentifier, infoEro.inlay)
                        print("ONLINEMODULE: onOutput: Stored info for generated KAKAO image. Identifier: " .. kakaoIdentifier)
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

    if type(data) ~= "string" then
        print("ONLINEMODULE: ERROR - Expected string data from risu-btn, but received type: " .. type(data))
        return
    end

    action, identifierFromData = data:match('^{%s*"action"%s*:%s*"([^"]+)"%s*,%s*"identifier"%s*:%s*"([^"]+)"%s*%}$')

    if not action or not identifierFromData then
        print("ONLINEMODULE: ERROR - Could not parse action and identifier from JSON-like string:", data)
        return
    end

    identifier = identifierFromData:match("^%s*(.-)%s*$")
    print("ONLINEMODULE: Parsed action: [" .. action .. "] Original identifier: [" .. identifierFromData .. "] Trimmed identifier: [" .. identifier .. "]")

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

    if action == "EROSTATUS_REROLL" then
        rerollType = "EROSTATUS"
        chatVarKeyForInlay = identifier
        specificPromptKey = identifier .. "_PROMPT"
        specificNegPromptKey = identifier .. "_NEGPROMPT"
    elseif action == "SIMCARD_REROLL" then
        rerollType = "SIMULATIONCARD"
        chatVarKeyForInlay = identifier
        specificPromptKey = identifier .. "_SIMULPROMPT"
        specificNegPromptKey = identifier .. "_NEGSIMULPROMPT"
    elseif action == "PROFILE_REROLL" then
        rerollType = "PROFILE"
        chatVarKeyForInlay = identifier
        specificPromptKey = identifier .. "_PROFILEPROMPT"
        specificNegPromptKey = identifier .. "_NEGPROFILEPROMPT"
    elseif action == "TWEET_REROLL" then
        rerollType = "TWEET"
        chatVarKeyForInlay = identifier .. "_TWEET"
        specificPromptKey = identifier .. "_TWEETPROMPT"
        specificNegPromptKey = identifier .. "_TWEETNEGPROMPT"
    elseif action == "DC_REROLL" then
        rerollType = "DC"
        chatVarKeyForInlay = "DC_" .. identifier
        specificPromptKey = "DC_" .. identifier .. "_PROMPT"
        specificNegPromptKey = "DC_" .. identifier .. "_NEGPROMPT"
    elseif action == "KAKAO_REROLL" then
        rerollType = "KAKAO"
        chatVarKeyForInlay = identifier
        specificPromptKey = identifier .. "_PROMPT"
        specificNegPromptKey = identifier .. "_NEGPROMPT"
    else
        print("ONLINEMODULE: Unknown button action received: " .. tostring(action))
        return
    end

    local NAIPRESETPROMPT = getGlobalVar(triggerId, "toggle_NAIPRESETPROMPT")

    local artistPrompt, qualityPrompt, negativePrompt = nil, nil, nil
	if NAIPRESETPROMPT == "0" then
        artistPrompt = getGlobalVar(triggerId, "toggle_NAIARTISTPROMPT")
        qualityPrompt = getGlobalVar(triggerId, "toggle_NAIQUALITYPROMPT")
        negativePrompt = getGlobalVar(triggerId, "toggle_NAINEGPROMPT")
    elseif NAIPRESETPROMPT == "1" then
		artistPrompt = "{{{artist:Goldcan9, artist:shiba}}}, {artist:sakurai norio,year 2023},{artist: torino}, [[[[[[[[artist: eonsang]]]]]]]], artist: gomzi, {year 2025, year 2024}"
		qualityPrompt = "best quality, amazing quality, very aesthetic, highres, incredibly absurdres"
		negativePrompt = "{{{worst quality}}}, {{{bad quality}}}, {{{censored}}}, reference, unfinished, unclear fingertips, twist, Squiggly, Grumpy, incomplete, {{Imperfect Fingers}}, Cheesy, {{very displeasing}}, {{mess}}, {{Approximate}}, {{monochrome}}, {{greyscale}}, {{{{mascot}}}}, {{{{puppet}}}}, {{{{character doll}}}}, {{{{pet}}}}, {{{{cake}}}}, {{{{stuffed toy}}}}, aged down, furry, sagging breasts, {multiple views}, pastie, maebari, animals, crowd, multiple girls, {eyeball}, {empty eyes}, {slit pupils}, {bright pupils}, {{sketch}}, {{flat color}}, censored, bestiality, from below, 3D"
	elseif NAIPRESETPROMPT == "2" then
		artistPrompt = "artist:mery (yangmalgage), artist:ikeuchi tanuma, artist:hiro (dismaless), {{{artist:ciloranko}}}, {{{{artist:kawakami rokkaku}}}}, artist:ohisashiburi, artist:freng, [[artist:bee (deadflow), artist:healthyman)]], {artist:baffu}, [[artist:deadnooodles]], [[artist:jyt]], {{{artist:yd (orange maru)}}}, [[92m, fkey, iuui]], [[[artist:ie (raarami), artist:mankai kaika, artist:toma (toma50)]]], {year 2025, year 2024}"
		qualityPrompt = "Detail Shading, {{{{{{{{{{amazing quality}}}}}}}}}}, very aesthetic, highres, incredibly absurdres"
		negativePrompt = "{{{{{{{{worst quality, bad quality, japanese text}}}}}}}}, {{{{bad hands, closed eyes}}}}, {{{bad eyes, bad pupils, bad glabella}}}, {{{undetailed eyes}}}, multiple views, error, extra digit, fewer digits, jpeg artifacts, signature, watermark, username, reference, {{unfinished}}, {{unclear fingertips}}, {{twist}}, {{squiggly}}, {{grumpy}}, {{incomplete}}, {{imperfect fingers}}, disorganized colors, cheesy, {{very displeasing}}, {{mess}}, {{approximate}}, {{sloppiness}}"
	elseif NAIPRESETPROMPT == "3" then
		artistPrompt = "0.7::artist:taesi::, 0.6::artist:shiratama (shiratamaco)::,0.8::artist:ningen mame::, 1.3::artist:tianliang duohe fangdongye::, 1.3::artist:shuz::, 0.8::artist:wlop::, 0.9::artist:kase daiki::, 0.6::artist:chobi (penguin paradise)::,{year 2025, year 2024}"
		qualityPrompt = "Detail Shading, {{{{{{{{{{amazing quality}}}}}}}}}}, very aesthetic, highres, incredibly absurdres"
		negativePrompt = "{{{blurry}}},{{{{{{{{worst quality, bad quality, japanese text}}}}}}}}, {{{{bad hands, closed eyes}}}}, {{{bad eyes, bad pupils, bad glabella}}}, {{{undetailed eyes}}}, multiple views, error, extra digit, fewer digits, jpeg artifacts, signature, watermark, username, reference, {{unfinished}}, {{unclear fingertips}}, {{twist}}, {{squiggly}}, {{grumpy}}, {{incomplete}}, {{imperfect fingers}}, disorganized colors, cheesy, {{very displeasing}}, {{mess}}, {{approximate}}, {{sloppiness}}"
    elseif NAIPRESETPROMPT == "4" then
        artistPrompt = "1.3::artist:tianliang duohe fangdongye ::,1.2::artist:shuz ::, 0.7::artist:wlop ::, 1.0::artist:kase daiki ::,0.8::artist:ningen mame ::,0.8::artist:voruvoru ::,0.8::artist:tomose_shunsaku ::,0.7::artist:sweetonedollar ::,0.7::artist:chobi (penguin paradise) ::,0.8::artist:rimo ::,{year 2024, year 2025}"
        qualityPrompt = "Detail Shading, {{{{{{{{{{amazing quality}}}}}}}}}}, very aesthetic, highres, incredibly absurdres"
        negativePrompt = "dark lighting,{{{blurry}}},{{{{{{{{worst quality, bad quality, japanese text}}}}}}}}, {{{{bad hands, closed eyes}}}}, {{{bad eyes, bad pupils, bad glabella}}}, {{{undetailed eyes}}}, multiple views, error, extra digit, fewer digits, jpeg artifacts, signature, watermark, username, reference, {{unfinished}}, {{unclear fingertips}}, {{twist}}, {{squiggly}}, {{grumpy}}, {{incomplete}}, {{imperfect fingers}}, disorganized colors, cheesy, {{very displeasing}}, {{mess}}, {{approximate}}, {{sloppiness}}, dark lighting,{{{blurry}}},{{{{{{{{worst quality, bad quality, japanese text}}}}}}}}, {{{{bad hands, closed eyes}}}}, {{{bad eyes, bad pupils, bad glabella}}}, {{{undetailed eyes}}}, multiple views, error, extra digit, fewer digits, jpeg artifacts, signature, watermark, username, reference, {{unfinished}}, {{unclear fingertips}}, {{twist}}, {{squiggly}}, {{grumpy}}, {{incomplete}}, {{imperfect fingers}}, disorganized colors, cheesy, {{very displeasing}}, {{mess}}, {{approximate}}, {{sloppiness}}"
    elseif NAIPRESETPROMPT == "5" then
        artistPrompt = "{healthyman}, [[[as109]]], [[[quasarcake]]], [[[mikozin]]], [[kidmo]], chen bin, year 2024"
        qualityPrompt = "Detail Shading, {{{{{{{{{{amazing quality}}}}}}}}}}, very aesthetic, highres, incredibly absurdres"
        negativePrompt = "worst quality, bad quality, displeasing, very displeasing, lowres, bad anatomy, bad perspective, bad proportions, bad aspect ratio, bad face, long face, bad teeth, bad neck, long neck, bad arm, bad hands, bad ass, bad leg, bad feet, bad reflection, bad shadow, bad link, bad source, wrong hand, wrong feet, missing limb, missing eye, missing tooth, missing ear, missing finger, extra faces, extra eyes, extra eyebrows, extra mouth, extra tongue, extra teeth, extra ears, extra breasts, extra arms, extra hands, extra legs, extra digits, fewer digits, cropped head, cropped torso, cropped shoulders, cropped arms, cropped legs, mutation, deformed, disfigured, unfinished, chromatic aberration, text, error, jpeg artifacts, watermark, scan, scan artifacts"
    elseif NAIPRESETPROMPT == "6" then
        artistPrompt = "(artist:nakta, artist: m (m073111), artist: mamei mema, artist:ningen_mame, artist:ciloranko, artist:sho_(sho_lwlw), artist:tianliang duohe fangdongye)"
        qualityPrompt = "volumetric lighting, very awa, very aesthetic, masterpiece, best quality, amazing quality, absurdres"
        negativePrompt = "worst quality, blurry, old, early, low quality, lowres, signature, username, logo, bad hands, mutated hands, ambiguous form, (censored, bar censor), mature female, colored skin, censored genitalia, censorship, unfinished, anthro, furry"
    end

    local foundSpecificPrompt = getState(triggerId, specificPromptKey) or "null"
    if foundSpecificPrompt == "null" then foundSpecificPrompt = "" end
    local foundSpecificNegPrompt = getState(triggerId, specificNegPromptKey) or "null"
    if foundSpecificNegPrompt == "null" then foundSpecificNegPrompt = "" end

    local finalPrompt = (artistPrompt or "") .. (foundSpecificPrompt or "") .. (qualityPrompt or "")
    local currentNegativePrompt = (negativePrompt or "")
    if foundSpecificNegPrompt and foundSpecificNegPrompt ~= "" and foundSpecificNegPrompt ~= "null" then
         currentNegativePrompt = foundSpecificNegPrompt .. ", " .. currentNegativePrompt
    end

    print("ONLINEMODULE: Generating new image for " .. rerollType .. " Identifier: " .. identifier)
    local successCall, newInlay = pcall(function() return generateImage(triggerId, finalPrompt, currentNegativePrompt):await() end)
    local oldInlay = getState(triggerId, chatVarKeyForInlay) or "null"

    local isSuccess = successCall and newInlay and type(newInlay) == "string" and string.len(newInlay) > 10 and not string.find(newInlay, "fail", 1, true) and not string.find(newInlay, "error", 1, true) and not string.find(newInlay, "실패", 1, true)

    if isSuccess then
        alertNormal(triggerId, "이미지 리롤 완료")
        print("ONLINEMODULE: New " .. rerollType .. " image generated successfully for Identifier: " .. identifier)

        setState(triggerId, chatVarKeyForInlay, newInlay)
        print("ONLINEMODULE: Updated chat variable for Identifier: " .. identifier .. " with new inlay.")

        local chatHistoryTable = getFullChat(triggerId)
        local historyLength = #chatHistoryTable
        local targetIndex = nil

        for i = historyLength, 1, -1 do
            if chatHistoryTable[i].role == 'char' then
                targetIndex = i
                break
            end
        end
    
        local historyModified = false
        
        local messageData = chatHistoryTable[targetIndex]
        local currentLine = messageData.data
        print("ONLINEMODULE: Checking history index " .. targetIndex .. " for update. Starts with: [" .. string.sub(currentLine, 1, 50) .. "]")
        
        local replacementOccurred = false
        local blockStart, blockEnd = nil, nil
        local newBlockContent = ""

        changeInlay(triggerId, targetIndex, oldInlay, newInlay)
    end
end)
