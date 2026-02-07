script_name = "Mocha to Aegisub"
script_description = "Apply Mocha tracking data to subtitles"
script_version = "1.0.0"
script_author = "Custom"

-- Localization / Yerelleştirme
local translations = {
    en = {
        -- GUI
        paste_data_label = "Paste keyframe data:",
        use_scale = "Use scale data (\\fscx, \\fscy)",
        scale_border = "  ↳ Scale border too (\\bord)",
        scale_shadow = "  ↳ Scale shadow too (\\shad)",
        use_rotation = "Use rotation data (\\frz)",
        button_apply = "Apply",
        button_cancel = "Cancel",
        
        -- Settings
        settings_title = "Settings",
        language_label = "Language:",
        language_english = "English",
        language_turkish = "Türkçe",
        button_save = "Save",
        settings_saved = "Settings saved!",
        
        -- Trim settings
        settings_trim_section = "Trim Settings",
        trim_ffmpeg_path = "FFmpeg path:",
        trim_ffmpeg_hint = "Full path to ffmpeg.exe (Example: C:\\ffmpeg\\bin\\ffmpeg.exe)",
        trim_output_dir = "Output directory:",
        trim_output_hint = "Where to save trimmed files (use ?video for video directory)",
        trim_preset_label = "Output format:",
        trim_preset_mp4 = "MP4 video",
        trim_preset_png = "PNG sequence",
        
        -- Simple log messages
        error_no_position_data = "Error: No position data found!",
        error_not_dialogue = "Error: Selected line is not a dialogue line!",
        data_summary = "%d frames of tracking data loaded (FPS: %.3f)",
        warning_fps_mismatch = "⚠ WARNING: Video FPS (%.3f) doesn't match tracking FPS (%.3f) - difference: %.3f FPS",
        processing_frames = "Processing %d frames...",
        success_complete = "Complete! %d frames created.",
        reminder_sort = "Remember to sort lines: Subtitle > Sort Lines > All Lines, by Time",
    },
    
    tr = {
        -- GUI
        paste_data_label = "Keyframe verisini buraya yapıştırın:",
        use_scale = "Scale verisini kullan (\\fscx, \\fscy)",
        scale_border = "  ↳ Border'ı da scale et (\\bord)",
        scale_shadow = "  ↳ Shadow'u da scale et (\\shad)",
        use_rotation = "Rotation verisini kullan (\\frz)",
        button_apply = "Uygula",
        button_cancel = "İptal",
        
        -- Settings
        settings_title = "Ayarlar",
        language_label = "Dil:",
        language_english = "English",
        language_turkish = "Türkçe",
        button_save = "Kaydet",
        settings_saved = "Ayarlar kaydedildi!",
        
        -- Trim settings
        settings_trim_section = "Kesim Ayarları",
        trim_ffmpeg_path = "FFmpeg yolu:",
        trim_ffmpeg_hint = "ffmpeg.exe'nin tam yolu (Örnek: C:\\ffmpeg\\bin\\ffmpeg.exe)",
        trim_output_dir = "Çıktı klasörü:",
        trim_output_hint = "Kesilen dosyaların kaydedileceği yer (?video = video klasörü)",
        trim_preset_label = "Çıktı formatı:",
        trim_preset_mp4 = "MP4 video",
        trim_preset_png = "PNG dizisi",
        
        -- Simple log messages
        error_no_position_data = "Hata: Position verisi bulunamadı!",
        error_not_dialogue = "Hata: Seçili satır bir dialogue değil!",
        data_summary = "%d frame tracking verisi yüklendi (FPS: %.3f)",
        warning_fps_mismatch = "⚠ UYARI: Video FPS (%.3f) ile tracking FPS (%.3f) uyuşmuyor - fark: %.3f FPS",
        processing_frames = "%d frame işleniyor...",
        success_complete = "Tamamlandı! %d frame oluşturuldu.",
        reminder_sort = "Satırları sıralamayı unutmayınız: Subtitle > Sort Lines > All Lines, by Time",
    }
}

-- Config system
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
        
        -- Simple JSON parse for our simple config
        local lang = content:match('"language"%s*:%s*"(%w+)"')
        if lang and (lang == "en" or lang == "tr") then
            config.language = lang
        end
        
        -- Parse trim settings
        local ffmpeg = content:match('"ffmpeg_path"%s*:%s*"([^"]*)"')
        if ffmpeg then
            config.trim = config.trim or {}
            -- Unescape JSON backslashes
            config.trim.ffmpeg_path = ffmpeg:gsub("\\\\", "\\")
        end
        
        local outdir = content:match('"output_dir"%s*:%s*"([^"]*)"')
        if outdir then
            config.trim = config.trim or {}
            -- Unescape JSON backslashes
            config.trim.output_dir = outdir:gsub("\\\\", "\\")
        end
        
        local preset = content:match('"preset"%s*:%s*"([^"]*)"')
        if preset and (preset == "mp4" or preset == "png") then
            config.trim = config.trim or {}
            config.trim.preset = preset
        end
    end
end

-- Save config
local function save_config()
    local file = io.open(config_file, "w")
    if file then
        -- Escape backslashes for JSON
        local ffmpeg_escaped = (config.trim.ffmpeg_path or ""):gsub("\\", "\\\\")
        local outdir_escaped = (config.trim.output_dir or "?video"):gsub("\\", "\\\\")
        local preset = config.trim.preset or "mp4"
        
        local json = string.format([[{
    "language": "%s",
    "trim": {
        "ffmpeg_path": "%s",
        "output_dir": "%s",
        "preset": "%s"
    }
}]], config.language, ffmpeg_escaped, outdir_escaped, preset)
        
        file:write(json)
        file:close()
        return true
    end
    return false
end

-- Get translation
local function t(key)
    return translations[config.language][key] or translations["en"][key] or key
end

-- Load config on startup
load_config()
-- Menu titles based on language

local menu_apply = (config.language == "tr") and "Uygula" or "Apply"
local menu_settings = (config.language == "tr") and "Ayarlar" or "Settings"
local menu_settings_desc = (config.language == "tr") and "Dil ve ayarları değiştir" or "Change language and settings"

-- After Effects keyframe verisini parse et
local parse_ae_keyframes
parse_ae_keyframes = function(ae_text)
    local data = {
        fps = 23.976,
        position = {},
        scale = {},
        rotation = {}
    }
    
    local current_section = nil
    
    for line in ae_text:gmatch("[^\r\n]+") do
        -- FPS değerini al
        local fps = line:match("Units Per Second%s+([%d%.]+)")
        if fps then
            data.fps = tonumber(fps)
        else
            -- Hangi bölümdeyiz?
            if line:match("Transform%s+Position") then
                current_section = "position"
            elseif line:match("Transform%s+Scale") then
                current_section = "scale"
            elseif line:match("Transform%s+Rotation") or line:match("Transform%s+Z Rotation") then
                current_section = "rotation"
            else
                -- Frame verisini parse et
                if current_section then
                    if current_section == "rotation" then
                        -- Rotation için tek değer: Frame Degrees
                        local frame, degrees = line:match("^%s*(%d+)%s+([%d%.%-]+)")
                        if frame and degrees then
                            data.rotation[tonumber(frame)] = tonumber(degrees)
                        end
                    else
                        -- Position ve Scale için: Frame X Y Z
                        local frame, x, y, z = line:match("^%s*(%d+)%s+([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)")
                        
                        if frame and x and y then
                            local frame_num = tonumber(frame)
                            
                            if current_section == "position" then
                                data.position[frame_num] = {
                                    x = tonumber(x),
                                    y = tonumber(y)
                                }
                            elseif current_section == "scale" then
                                data.scale[frame_num] = {
                                    x = tonumber(x),
                                    y = tonumber(y)
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    
    return data
end

-- İki değer arasında interpolasyon yap
local interpolate_value
interpolate_value = function(v1, v2, ratio)
    return v1 + (v2 - v1) * ratio
end

-- Verilen frame için position/scale bul (interpolasyon ile)
local get_value_at_frame
get_value_at_frame = function(data_table, frame)
    -- Tam frame varsa direkt döndür
    if data_table[frame] then
        return data_table[frame]
    end
    
    -- En yakın frame'leri bul
    local frames = {}
    for k in pairs(data_table) do
        table.insert(frames, k)
    end
    table.sort(frames)
    
    if #frames == 0 then
        return nil
    end
    
    if frame <= frames[1] then
        return data_table[frames[1]]
    end
    
    if frame >= frames[#frames] then
        return data_table[frames[#frames]]
    end
    
    -- İki frame arasında interpolasyon
    for i = 1, #frames - 1 do
        if frame >= frames[i] and frame <= frames[i + 1] then
            local f1, f2 = frames[i], frames[i + 1]
            local ratio = (frame - f1) / (f2 - f1)
            
            local v1, v2 = data_table[f1], data_table[f2]
            return {
                x = interpolate_value(v1.x, v2.x, ratio),
                y = interpolate_value(v1.y, v2.y, ratio)
            }
        end
    end
    
    return data_table[frames[1]]
end

-- Verilen frame için rotation bul (tek değer için)
local get_rotation_at_frame
get_rotation_at_frame = function(data_table, frame)
    -- Tam frame varsa direkt döndür
    if data_table[frame] then
        return data_table[frame]
    end
    
    -- En yakın frame'leri bul
    local frames = {}
    for k in pairs(data_table) do
        table.insert(frames, k)
    end
    table.sort(frames)
    
    if #frames == 0 then
        return nil
    end
    
    if frame <= frames[1] then
        return data_table[frames[1]]
    end
    
    if frame >= frames[#frames] then
        return data_table[frames[#frames]]
    end
    
    -- İki frame arasında interpolasyon
    for i = 1, #frames - 1 do
        if frame >= frames[i] and frame <= frames[i + 1] then
            local f1, f2 = frames[i], frames[i + 1]
            local ratio = (frame - f1) / (f2 - f1)
            return interpolate_value(data_table[f1], data_table[f2], ratio)
        end
    end
    
    return data_table[frames[1]]
end

-- Tracking verisini subtitle'a uygula (frame-by-frame)
local apply_tracking
apply_tracking = function(sub, sel, ae_text, use_scale, use_rotation, scale_border, scale_shadow)
    if use_scale == nil then use_scale = true end
    if use_rotation == nil then use_rotation = true end
    if scale_border == nil then scale_border = true end
    if scale_shadow == nil then scale_shadow = true end
    
    local data = parse_ae_keyframes(ae_text)
    
    if not next(data.position) then
        aegisub.log(t("error_no_position_data") .. "\n")
        return sel
    end
    
    local pos_count = 0
    for _ in pairs(data.position) do pos_count = pos_count + 1 end
    
    aegisub.log(string.format(t("data_summary"), pos_count, data.fps) .. "\n")
    
    -- Video FPS kontrolü (sadece uyarı varsa göster)
    local video_fps = aegisub.video_size()
    if video_fps then
        local ms_per_frame = aegisub.ms_from_frame(1) - aegisub.ms_from_frame(0)
        video_fps = 1000 / ms_per_frame
        
        local fps_diff = math.abs(video_fps - data.fps)
        if fps_diff > 0.1 then
            aegisub.log(string.format(t("warning_fps_mismatch"), video_fps, data.fps, fps_diff) .. "\n")
        end
    end
    
    if use_rotation and next(data.rotation) then
        -- Rotation verisi var, sessizce kullan
    end
    
    -- Sadece ilk satırı işle
    local si = sel[1]
    local line = sub[si]
    
    if line.class ~= "dialogue" then
        aegisub.log(t("error_not_dialogue") .. "\n")
        return sel
    end
    
    -- Satırın başlangıç ve bitiş frame'lerini hesapla
    local start_frame = aegisub.frame_from_ms(line.start_time)
    local end_frame = aegisub.frame_from_ms(line.end_time)
    
    local total_frames = end_frame - start_frame + 1
    aegisub.log(string.format(t("processing_frames"), total_frames) .. "\n")
    
    -- Orijinal text'ten override tag'leri temizle
    local clean_text = line.text:gsub("\\pos%([^%)]*%)", "")
    clean_text = clean_text:gsub("\\move%([^%)]*%)", "")
    
    -- Orijinal border ve shadow değerlerini al (scale için)
    local original_border = nil
    local original_shadow = nil
    
    if use_scale and scale_border then
        local bord_match = line.text:match("\\bord([%d%.]+)")
        if bord_match then
            original_border = tonumber(bord_match)
        end
    end
    
    if use_scale and scale_shadow then
        local shad_match = line.text:match("\\shad([%d%.%-]+)")
        if shad_match then
            original_shadow = tonumber(shad_match)
        end
    end
    
    if use_scale then
        clean_text = clean_text:gsub("\\fscx[%d%.]+", "")
        clean_text = clean_text:gsub("\\fscy[%d%.]+", "")
        
        if scale_border then
            clean_text = clean_text:gsub("\\bord[%d%.]+", "")
        end
        
        if scale_shadow then
            clean_text = clean_text:gsub("\\shad[%d%.%-]+", "")
        end
    end
    
    if use_rotation then
        clean_text = clean_text:gsub("\\frz%-?[%d%.]+", "")
        clean_text = clean_text:gsub("\\fr[xyz]%-?[%d%.]+", "")
    end
    
    -- Orijinal satırın pozisyonunu al (offset hesabı için)
    local original_x, original_y = nil, nil
    
    -- \pos tag'ini ara
    local pos_pattern = "\\pos%(([%d%.%-]+),([%d%.%-]+)%)"
    local pos_x_str, pos_y_str = line.text:match(pos_pattern)
    if pos_x_str and pos_y_str then
        original_x = tonumber(pos_x_str)
        original_y = tonumber(pos_y_str)
    end
    
    -- Eğer \pos yoksa, \move tag'inden al
    if not original_x then
        local move_pattern = "\\move%(([%d%.%-]+),([%d%.%-]+)"
        local move_x_str, move_y_str = line.text:match(move_pattern)
        if move_x_str and move_y_str then
            original_x = tonumber(move_x_str)
            original_y = tonumber(move_y_str)
        end
    end
    
    -- Offset hesapla
    local offset_x, offset_y = 0, 0
    if original_x and original_y then
        local first_tracking_pos = get_value_at_frame(data.position, 0)
        if first_tracking_pos then
            offset_x = original_x - first_tracking_pos.x
            offset_y = original_y - first_tracking_pos.y
        end
    end
    
    local new_lines = {}
    local frame_count = 0
    
    -- Her frame için satır oluştur (memory'de)
    for frame = start_frame, end_frame do
        -- CRITICAL: Absolute frame'i relative frame'e çevir
        -- Tracking verisi 0'dan başlıyor, bizim frame'lerimiz start_frame'den başlıyor
        local relative_frame = frame - start_frame
        
        -- Position al
        local pos = get_value_at_frame(data.position, relative_frame)
        
        if pos then
            frame_count = frame_count + 1
            
            -- Timing hesapla
            local frame_start = aegisub.ms_from_frame(frame)
            local frame_end = aegisub.ms_from_frame(frame + 1)
            
            -- Offset'i rotation ve scale'e göre transform et
            local transformed_offset_x = offset_x
            local transformed_offset_y = offset_y
            
            -- İlk frame DEĞİLSE, offset'i transform et
            -- (Çünkü offset ilk frame'e göre hesaplandı)
            if relative_frame > 0 then
                -- Scale değişimini hesapla
                local current_scale_ratio = 1.0
                if use_scale and next(data.scale) then
                    local current_scale = get_value_at_frame(data.scale, relative_frame)
                    local first_scale = get_value_at_frame(data.scale, 0)
                    if current_scale and first_scale then
                        current_scale_ratio = current_scale.x / first_scale.x
                        transformed_offset_x = offset_x * current_scale_ratio
                        transformed_offset_y = offset_y * current_scale_ratio
                    end
                end
                
                -- Rotation değişimini hesapla
                if use_rotation and next(data.rotation) then
                    local current_rotation = get_rotation_at_frame(data.rotation, relative_frame)
                    local first_rotation = get_rotation_at_frame(data.rotation, 0)
                    if current_rotation and first_rotation then
                        -- İlk rotation'a göre farkı hesapla
                        local rotation_diff = current_rotation - first_rotation
                        local rotation_rad = math.rad(-rotation_diff)  -- AE ters yönde
                        
                        -- Offset vektörünü döndür
                        local cos_r = math.cos(rotation_rad)
                        local sin_r = math.sin(rotation_rad)
                        
                        local rotated_x = transformed_offset_x * cos_r - transformed_offset_y * sin_r
                        local rotated_y = transformed_offset_x * sin_r + transformed_offset_y * cos_r
                        
                        transformed_offset_x = rotated_x
                        transformed_offset_y = rotated_y
                    end
                end
            end
            
            -- Tag'leri oluştur - Transform edilmiş offset uygula
            local final_x = pos.x + transformed_offset_x
            local final_y = pos.y + transformed_offset_y
            local tags = string.format("\\pos(%.2f,%.2f)", final_x, final_y)
            
            -- Scale varsa ekle
            if use_scale and next(data.scale) then
                local scale = get_value_at_frame(data.scale, relative_frame)
                if scale then
                    local scale_ratio = scale.x / 100
                    tags = tags .. string.format("\\fscx%.2f\\fscy%.2f", scale.x, scale.y)
                    
                    -- Border scaling
                    if scale_border and original_border then
                        local scaled_border = original_border * scale_ratio
                        tags = tags .. string.format("\\bord%.2f", scaled_border)
                    end
                    
                    -- Shadow scaling
                    if scale_shadow and original_shadow then
                        local scaled_shadow = original_shadow * scale_ratio
                        tags = tags .. string.format("\\shad%.2f", scaled_shadow)
                    end
                end
            end
            
            -- Rotation varsa ekle (işareti ters çevir: AE saat yönü tersine, Aegisub saat yönünde)
            if use_rotation and next(data.rotation) then
                local rotation = get_rotation_at_frame(data.rotation, relative_frame)
                if rotation then
                    tags = tags .. string.format("\\frz%.2f", -rotation)  -- Negatif işaret!
                end
            end
            
            -- Text'i hazırla
            local final_text
            if clean_text:match("^{.*}") then
                final_text = clean_text:gsub("^{", "{" .. tags)
            else
                final_text = "{" .. tags .. "}" .. clean_text
            end
            
            -- Yeni satırı oluştur
            local new_line = {
                class = "dialogue",
                layer = line.layer,
                start_time = frame_start,
                end_time = frame_end,
                style = line.style,
                actor = line.actor,
                margin_l = line.margin_l,
                margin_r = line.margin_r,
                margin_t = line.margin_t,
                effect = line.effect,
                text = final_text
            }
            
            table.insert(new_lines, new_line)
        end
    end
    
    aegisub.log("Toplam " .. frame_count .. " frame hazırlandı. Şimdi ekleniyor...\n")
    
    if #new_lines > 0 then
        -- İlk satırı değiştir
        local first_line = new_lines[1]
        line.start_time = first_line.start_time
        line.end_time = first_line.end_time
        line.text = first_line.text
        sub[si] = line
        aegisub.log("Satır " .. si .. " güncellendi (frame 1/" .. #new_lines .. ")\n")
        
        -- Geri kalan satırları ekle - orijinal satırı klonlayıp new_lines'dan değerleri al
        for i = 2, #new_lines do
            -- Orijinal satırı klonla (Aegisub'ın ihtiyaç duyduğu internal field'lar için)
            local clone = {}
            for k, v in pairs(line) do
                clone[k] = v
            end
            
            -- new_lines[i]'den değerleri al
            clone.start_time = new_lines[i].start_time
            clone.end_time = new_lines[i].end_time
            clone.text = new_lines[i].text
            
            sub.append(clone)
        end
    end
    
    aegisub.log("\n" .. string.format(t("success_complete"), frame_count) .. "\n")
    aegisub.log(t("reminder_sort") .. "\n")
    
    return {}
end

-- GUI dialog
local show_dialog
show_dialog = function(sub, sel)
    local dialog = {
        {
            class = "label",
            label = t("paste_data_label"),
            x = 0, y = 0, width = 2, height = 1
        },
        {
            class = "textbox",
            name = "ae_data",
            text = "",
            x = 0, y = 1, width = 2, height = 10
        },
        {
            class = "checkbox",
            name = "use_scale",
            label = t("use_scale"),
            value = true,
            x = 0, y = 11, width = 2, height = 1
        },
        {
            class = "checkbox",
            name = "scale_border",
            label = t("scale_border"),
            value = true,
            x = 0, y = 12, width = 2, height = 1
        },
        {
            class = "checkbox",
            name = "scale_shadow",
            label = t("scale_shadow"),
            value = true,
            x = 0, y = 13, width = 2, height = 1
        },
        {
            class = "checkbox",
            name = "use_rotation",
            label = t("use_rotation"),
            value = true,
            x = 0, y = 14, width = 2, height = 1
        }
    }
    
    local buttons = {t("button_apply"), t("button_cancel")}
    
    local button, result = aegisub.dialog.display(dialog, buttons)
    
    if button == false or button == t("button_cancel") then
        return sel
    end
    
    return apply_tracking(sub, sel, result.ae_data, result.use_scale, result.use_rotation, result.scale_border, result.scale_shadow)
end

-- Settings dialog
local show_settings
show_settings = function(sub, sel)
    local dialog = {
        {
            class = "label",
            label = t("language_label"),
            x = 0, y = 0, width = 1, height = 1
        },
        {
            class = "dropdown",
            name = "language",
            items = {t("language_english"), t("language_turkish")},
            value = config.language == "tr" and t("language_turkish") or t("language_english"),
            x = 1, y = 0, width = 2, height = 1
        },
        {
            class = "label",
            label = "──────────────── " .. t("settings_trim_section") .. " ────────────────",
            x = 0, y = 1, width = 3, height = 1
        },
        {
            class = "label",
            label = t("trim_ffmpeg_path"),
            x = 0, y = 2, width = 1, height = 1
        },
        {
            class = "edit",
            name = "ffmpeg_path",
            text = config.trim.ffmpeg_path or "",
            hint = t("trim_ffmpeg_hint"),
            x = 1, y = 2, width = 2, height = 1
        },
        {
            class = "label",
            label = t("trim_output_dir"),
            x = 0, y = 3, width = 1, height = 1
        },
        {
            class = "edit",
            name = "output_dir",
            text = config.trim.output_dir or "?video",
            hint = t("trim_output_hint"),
            x = 1, y = 3, width = 2, height = 1
        },
        {
            class = "label",
            label = t("trim_preset_label"),
            x = 0, y = 4, width = 1, height = 1
        },
        {
            class = "dropdown",
            name = "trim_preset",
            items = {t("trim_preset_mp4"), t("trim_preset_png")},
            value = (config.trim.preset == "png") and t("trim_preset_png") or t("trim_preset_mp4"),
            x = 1, y = 4, width = 2, height = 1
        }
    }
    
    local buttons = {t("button_save"), t("button_cancel")}
    
    local button, result = aegisub.dialog.display(dialog, buttons, {close = t("button_cancel")})
    
    if button == t("button_save") then
        -- Save language
        if result.language == t("language_turkish") or result.language == "Türkçe" then
            config.language = "tr"
        else
            config.language = "en"
        end
        
        -- Save trim settings
        config.trim = config.trim or {}
        config.trim.ffmpeg_path = result.ffmpeg_path
        config.trim.output_dir = result.output_dir
        
        -- Determine preset from dropdown
        if result.trim_preset == t("trim_preset_png") then
            config.trim.preset = "png"
        else
            config.trim.preset = "mp4"
        end
        
        if save_config() then
            aegisub.log(t("settings_saved") .. "\n")
            aegisub.log("Config file: " .. config_file .. "\n")
            aegisub.log("FFmpeg path: " .. (config.trim.ffmpeg_path or "(empty)") .. "\n")
            aegisub.log("Output dir: " .. (config.trim.output_dir or "(empty)") .. "\n")
            aegisub.log("Preset: " .. (config.trim.preset or "(empty)") .. "\n")
        else
            aegisub.log("ERROR: Could not write config file!\n")
        end
    end
    
    return sel
end

-- Aegisub'a kaydet
aegisub.register_macro(script_name .. "/" .. menu_apply, script_description, show_dialog)
aegisub.register_macro(script_name .. "/" .. menu_settings, menu_settings_desc, show_settings)
