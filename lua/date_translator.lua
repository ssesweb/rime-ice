-- 日期时间，可在方案中配置触发关键字。

-- 原有的原因：因为在方案中设置了大于 1 的 initial_quality，导致 rq sj xq dt ts 产出的候选项在所有词语的最后。
-- 现有降低权重为0的原因，已指定具体的拼音触发逻辑，但可能出现错误触发，此时修改为拼音并降低权重有助于减少错误触发。  
local function yield_cand(seg, text)
    local cand = Candidate('', seg.start, seg._end, text, '')
    cand.quality = 0
    yield(cand)
end

-- 获取本周的开始和结束日期（周一为开始，周日为结束）
local function get_week_range()
    local current_time = os.time()
    local weekday = tonumber(os.date('%w', current_time)) -- 0=周日,1=周一,...,6=周六
    
    -- 计算周一的时间（如果今天是周日，weekday=0，需要减去6天）
    local monday_offset = (weekday == 0 and -6 or 1 - weekday) * 86400
    local monday = os.date('%Y-%m-%d', current_time + monday_offset)
    
    -- 计算周日的时间
    local sunday_offset = (weekday == 0 and 0 or 7 - weekday) * 86400
    local sunday = os.date('%Y-%m-%d', current_time + sunday_offset)
    
    return monday, sunday
end

-- 获取上周的开始和结束日期
local function get_last_week_range()
    local current_time = os.time()
    local weekday = tonumber(os.date('%w', current_time))
    -- 计算上周一：(本周已过天数 + 7) * 秒数
    local last_monday_offset = ((weekday == 0 and 6 or weekday - 1) + 7) * -86400
    local last_monday = os.date('%Y-%m-%d', current_time + last_monday_offset)
    local last_sunday = os.date('%Y-%m-%d', current_time + last_monday_offset + 6 * 86400)
    return last_monday, last_sunday
end

-- 获取上月的开始和结束日期
local function get_last_month_range()
    local now = os.date("*t")
    local last_month_year = now.year
    local last_month = now.month - 1
    if last_month == 0 then
        last_month = 12
        last_month_year = last_month_year - 1
    end
    -- 上月第一天
    local first_day = os.date('%Y-%m-01', os.time{year=last_month_year, month=last_month, day=1})
    -- 上月最后一天（本月第一天减去一天）
    local last_day = os.date('%Y-%m-%d', os.time{year=now.year, month=now.month, day=1} - 86400)
    return first_day, last_day
end

-- 获取本月的开始和结束日期
local function get_month_range()
    local current_time = os.time()
    local year = tonumber(os.date('%Y', current_time))
    local month = tonumber(os.date('%m', current_time))
    
    -- 本月第一天
    local first_day = os.date('%Y-%m-01', current_time)
    
    -- 下个月第一天
    local next_month = month + 1
    local next_year = year
    if next_month > 12 then
        next_month = 1
        next_year = year + 1
    end
    
    -- 本月最后一天（下个月第一天减去1天）
    local next_month_first_day = os.time{year=next_year, month=next_month, day=1}
    local last_day_timestamp = next_month_first_day - 86400
    local last_day = os.date('%Y-%m-%d', last_day_timestamp)
    
    return first_day, last_day
end

local M = {}

function M.init(env)
    local config = env.engine.schema.config
    env.name_space = env.name_space:gsub('^*', '')
    M.date = config:get_string(env.name_space .. '/date') or 'rq'
    M.time = config:get_string(env.name_space .. '/time') or 'sj'
    M.week = config:get_string(env.name_space .. '/week') or 'xq'
    M.datetime = config:get_string(env.name_space .. '/datetime') or 'dt'
    M.timestamp = config:get_string(env.name_space .. '/timestamp') or 'ts'
    -- 新增：本周范围和本月范围的触发词
    M.week_range = config:get_string(env.name_space .. '/week_range') or 'bz'
    M.month_range = config:get_string(env.name_space .. '/month_range') or 'by'
    -- 新增：上周范围和上月范围的触发词
    M.last_week_range = config:get_string(env.name_space .. '/last_week_range') or 'shangzhou'
    M.last_month_range = config:get_string(env.name_space .. '/last_month_range') or 'shangyue'
end

function M.func(input, seg, env)
    -- 日期
    if (input == M.date) then
        local current_time = os.time()
        yield_cand(seg, os.date('%Y-%m-%d', current_time))
        yield_cand(seg, os.date('%Y/%m/%d', current_time))
        yield_cand(seg, os.date('%Y.%m.%d', current_time))
        yield_cand(seg, os.date('%Y%m%d', current_time))
        yield_cand(seg, os.date('%Y年%m月%d日', current_time):gsub('年0', '年'):gsub('月0','月'))

    -- 时间
    elseif (input == M.time) then
        local current_time = os.time()
        yield_cand(seg, os.date('%H:%M', current_time))
        yield_cand(seg, os.date('%H:%M:%S', current_time))

    -- 星期
    elseif (input == M.week) then
        local current_time = os.time()
        local week_tab = {'日', '一', '二', '三', '四', '五', '六'}
        local text = week_tab[tonumber(os.date('%w', current_time)) + 1]
        yield_cand(seg, '星期' .. text)
        yield_cand(seg, '礼拜' .. text)
        yield_cand(seg, '周' .. text)

    -- ISO 8601/RFC 3339 的时间格式 （固定东八区）（示例 2022-01-07T20:42:51+08:00）
    elseif (input == M.datetime) then
        local current_time = os.time()
        yield_cand(seg, os.date('%Y-%m-%dT%H:%M:%S+08:00', current_time))
        yield_cand(seg, os.date('%Y-%m-%d %H:%M:%S', current_time))
        yield_cand(seg, os.date('%Y%m%d%H%M%S', current_time))

    -- 时间戳（十位数，到秒，示例 1650861664）
    elseif (input == M.timestamp) then
        local current_time = os.time()
        yield_cand(seg, string.format('%d', current_time))
        
    -- 本周范围
    elseif (input == M.week_range) then
        local monday, sunday = get_week_range()
        yield_cand(seg, monday .. '~' .. sunday)
        yield_cand(seg, monday .. ' 至 ' .. sunday)
        yield_cand(seg, os.date('%Y/%m/%d', os.time{year=tonumber(monday:sub(1,4)), month=tonumber(monday:sub(6,7)), day=tonumber(monday:sub(9,10))}) .. '~' .. os.date('%Y/%m/%d', os.time{year=tonumber(sunday:sub(1,4)), month=tonumber(sunday:sub(6,7)), day=tonumber(sunday:sub(9,10))}))
        
    -- 上周范围
    elseif (input == M.last_week_range) then
        local monday, sunday = get_last_week_range()
        yield_cand(seg, monday .. '~' .. sunday)
        yield_cand(seg, monday .. ' 至 ' .. sunday)
        yield_cand(seg, os.date('%Y/%m/%d', os.time{year=tonumber(monday:sub(1,4)), month=tonumber(monday:sub(6,7)), day=tonumber(monday:sub(9,10))}) .. '~' .. os.date('%Y/%m/%d', os.time{year=tonumber(sunday:sub(1,4)), month=tonumber(sunday:sub(6,7)), day=tonumber(sunday:sub(9,10))}))
        
    -- 本月范围
    elseif (input == M.month_range) then
        local first_day, last_day = get_month_range()
        yield_cand(seg, first_day .. '~' .. last_day)
        yield_cand(seg, first_day .. ' 至 ' .. last_day)
        yield_cand(seg, os.date('%Y/%m/%d', os.time{year=tonumber(first_day:sub(1,4)), month=tonumber(first_day:sub(6,7)), day=tonumber(first_day:sub(9,10))}) .. '~' .. os.date('%Y/%m/%d', os.time{year=tonumber(last_day:sub(1,4)), month=tonumber(last_day:sub(6,7)), day=tonumber(last_day:sub(9,10))}))

    -- 上月范围
    elseif (input == M.last_month_range) then
        local first_day, last_day = get_last_month_range()
        yield_cand(seg, first_day .. '~' .. last_day)
        yield_cand(seg, first_day .. ' 至 ' .. last_day)
        yield_cand(seg, os.date('%Y/%m/%d', os.time{year=tonumber(first_day:sub(1,4)), month=tonumber(first_day:sub(6,7)), day=tonumber(first_day:sub(9,10))}) .. '~' .. os.date('%Y/%m/%d', os.time{year=tonumber(last_day:sub(1,4)), month=tonumber(last_day:sub(6,7)), day=tonumber(last_day:sub(9,10))}))
    end
end

return M
