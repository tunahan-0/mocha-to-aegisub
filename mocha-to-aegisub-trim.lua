-- Mocha to Aegisub - Trim Module
-- Trims video clips for motion tracking using FFmpeg

script_name = "Mocha to Aegisub"
script_description = "Video Trim Module for Mocha to Aegisub"
script_version = "1.0.0"

-- Shared config with main script
local config_file = aegisub.decode_path("?user/mocha_tracker_config.json")
local config = {
    language = "en",
    trim = {
        ffmpeg_path = "",
        output_dir = "?video",
        preset = "mp4"  -- "mp4" or "png"
    }
}

-- Load config
local function load_config()
    local file = io.open(config_file, "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        local lang = content:match('"language"%s*:%s*"(%w+)"')
        if lang then config.language = lang end
        
        local ffmpeg = content:match('"ffmpeg_path"%s*:%s*"([^"]*)"')
        if ffmpeg then 
            -- Unescape JSON backslashes
            config.trim.ffmpeg_path = ffmpeg:gsub("\\\\", "\\")
        end
        
        local outdir = content:match('"output_dir"%s*:%s*"([^"]*)"')
        if outdir and outdir ~= "" then 
            -- Unescape JSON backslashes
            config.trim.output_dir = outdir:gsub("\\\\", "\\")
        end
        
        local preset = content:match('"preset"%s*:%s*"([^"]*)"')
        if preset and (preset == "mp4" or preset == "png") then 
            config.trim.preset = preset 
        end
    end
end

-- Translations
local translations = {
    en = {
        error_no_video = "Error: No video loaded!",
        error_no_ffmpeg = "Error: FFmpeg path not set! Please configure in Settings.",
        error_no_selection = "Error: Select a subtitle line to define trim range!",
        trimming = "Trimming %d frames (%d → %d)...",
        success = "✓ Trim complete!",
        failed = "✗ Trim failed.",
    },
    tr = {
        error_no_video = "Hata: Video yüklü değil!",
        error_no_ffmpeg = "Hata: FFmpeg yolu ayarlanmamış! Lütfen Ayarlar'dan yapılandırın.",
        error_no_selection = "Hata: Kesim aralığını belirlemek için bir altyazı satırı seçin!",
        trimming = "%d frame kesiliyor (%d → %d)...",
        success = "✓ Kesim tamamlandı!",
        failed = "✗ Kesim başarısız.",
    }
}

local function t(key)
    return translations[config.language][key] or translations["en"][key] or key
end

load_config()

-- Menu title based on language
local menu_trim = (config.language == "tr") and "Kes" or "Trim"

-- Main trim function
local function perform_trim(sub, sel)
    -- Check video
    local video_props = aegisub.project_properties()
    if not video_props.video_file or video_props.video_file == "" then
        aegisub.log(t("error_no_video") .. "\n")
        return sel
    end
    
    -- Check FFmpeg
    if config.trim.ffmpeg_path == "" then
        aegisub.log(t("error_no_ffmpeg") .. "\n")
        return sel
    end
    
    -- Check selection
    if #sel == 0 then
        aegisub.log(t("error_no_selection") .. "\n")
        return sel
    end
    
    -- Get frame range
    local start_frame = aegisub.frame_from_ms(sub[sel[1]].start_time)
    local end_frame = aegisub.frame_from_ms(sub[sel[#sel]].end_time)
    local total_frames = end_frame - start_frame  -- end_frame is exclusive
    
    -- Get time range (for FFmpeg -ss and -t parameters)
    local start_time = sub[sel[1]].start_time
    local end_time = sub[sel[#sel]].end_time
    
    -- Prepare output
    local output_dir = aegisub.decode_path(config.trim.output_dir)
    
    -- Normalize to backslash on Windows
    if jit.os == "Windows" then
        output_dir = output_dir:gsub("/", "\\")
    end
    
    -- Create directory
    if jit.os == "Windows" then
        os.execute('mkdir "' .. output_dir .. '" 2>nul')
    else
        os.execute('mkdir -p "' .. output_dir .. '" 2>/dev/null')
    end
    
    -- Calculate time in seconds for FFmpeg
    local start_sec = start_time / 1000  -- ms to seconds
    local duration = (end_time - start_time) / 1000  -- ms to seconds
    
    -- Build FFmpeg command based on preset
    local output_file
    local cmd
    if config.trim.preset == "png" then
        -- PNG sequence
        output_file = output_dir .. "\\frame-%05d.png"
        cmd = string.format(
            '"%s" -ss %.3f -i "%s" -t %.3f -q:v 1 -vsync 0 "%s"',
            config.trim.ffmpeg_path,
            start_sec,
            video_props.video_file,
            duration,
            output_file
        )
    else
        -- MP4 video
        output_file = output_dir .. "\\trimmed_" .. start_frame .. "-" .. end_frame .. ".mp4"
        cmd = string.format(
            '"%s" -ss %.3f -i "%s" -t %.3f -c:v libx264 -crf 18 -preset ultrafast "%s"',
            config.trim.ffmpeg_path,
            start_sec,
            video_props.video_file,
            duration,
            output_file
        )
    end
    
    aegisub.log(string.format(t("trimming"), total_frames, start_frame, end_frame - 1) .. "\n")
    
    -- Write command to batch file (avoids escaping issues)
    local temp_dir = aegisub.decode_path("?temp")
    
    -- Remove trailing slash/backslash if present
    if temp_dir:sub(-1) == "\\" or temp_dir:sub(-1) == "/" then
        temp_dir = temp_dir:sub(1, -2)
    end
    
    local batch_file = temp_dir .. "\\mocha_trim.bat"
    local log_file = temp_dir .. "\\mocha_trim.log"
    
    local batch = io.open(batch_file, "w")
    if batch then
        batch:write("@echo off\n")
        batch:write(cmd .. " 2>&1\n")
        batch:close()
        
        -- Execute batch file silently using cmd /c
        local exec_cmd = 'start /B /WAIT cmd /c "' .. batch_file .. '" > "' .. log_file .. '" 2>&1'
        os.execute(exec_cmd)
        
        -- Wait for FFmpeg to complete
        os.execute("ping -n 3 127.0.0.1 > nul")
        
        -- Read log file for errors
        local logf = io.open(log_file, "r")
        if logf then
            local log_content = logf:read("*a")
            logf:close()
            
            -- Check for common FFmpeg errors
            if log_content:match("Error") or log_content:match("Invalid") or log_content:match("failed") then
                aegisub.log("\n" .. t("failed") .. "\n")
                aegisub.log("FFmpeg error:\n" .. log_content:sub(1, 500) .. "\n")
                return sel
            end
        end
    else
        aegisub.log("ERROR: Could not create batch file!\n")
        return sel
    end
    
    -- Check if output file was created
    local output_check = io.open(output_file, "r")
    if output_check then
        output_check:close()
        aegisub.log("\n" .. t("success") .. "\n")
        aegisub.log(output_file .. "\n")
    else
        aegisub.log("\n" .. t("failed") .. "\n")
    end
    
    return sel
end

-- Register
aegisub.register_macro(script_name .. "/" .. menu_trim, script_description, perform_trim)
