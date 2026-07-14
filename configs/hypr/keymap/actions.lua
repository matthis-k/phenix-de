local actions = {}

function actions.dispatch(action)
    return function()
        if type(action) == "function" then
            action()
        elseif action ~= nil and hl ~= nil and hl.dispatch ~= nil then
            hl.dispatch(action)
        end
    end
end

function actions.exec(command)
    return hl.dsp.exec_cmd(command)
end

return actions
