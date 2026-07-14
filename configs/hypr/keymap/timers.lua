local Timers = {}
Timers.__index = Timers

function Timers.new()
    return setmetatable({
        next_id = 1,
        entries = {},
    }, Timers)
end

function Timers:schedule(at, kind, owner_type, owner_id, data)
    local id = self.next_id
    self.next_id = self.next_id + 1

    self.entries[id] = {
        id = id,
        at = at,
        kind = kind,
        owner_type = owner_type,
        owner_id = owner_id,
        data = data or {},
        cancelled = false,
    }

    return id
end

function Timers:cancel(id)
    local timer = self.entries[id]

    if timer ~= nil then
        timer.cancelled = true
        self.entries[id] = nil
    end
end

function Timers:cancel_owner(owner_type, owner_id)
    for id, timer in pairs(self.entries) do
        if timer.owner_type == owner_type and timer.owner_id == owner_id then
            timer.cancelled = true
            self.entries[id] = nil
        end
    end
end

function Timers:next_due(now)
    local selected = nil

    for _, timer in pairs(self.entries) do
        if not timer.cancelled and timer.at <= now and (selected == nil or timer.at < selected.at) then
            selected = timer
        end
    end

    if selected ~= nil then
        self.entries[selected.id] = nil
    end

    return selected
end

function Timers:next_at()
    local selected = nil

    for _, timer in pairs(self.entries) do
        if not timer.cancelled and (selected == nil or timer.at < selected) then
            selected = timer.at
        end
    end

    return selected
end

return Timers
