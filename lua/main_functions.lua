function append_file(path, value)
  local file = io.open(path, "a")
  file:write(value)
  file:close()
end

function lua_print(message)
  print(message)
  append_file("/tmp/lua_scripts.log", os.date("%c") .. " " .. message .. "\n")
end

function notify(priority, title, message)
  runcommand = "curl -s --form-string 'token=<PUSHOVER_TOKEN>' --form-string 'user=<PUSHOVER_USER>' --form-string 'priority=" .. priority .. "' --form-string 'title=" .. title .. "' --form-string 'message=" .. message .. "' https://api.pushover.net/1/messages.json >> /tmp/notification.log 2>&1 &"
  append_file("/tmp/notification.log", "\n")
  os.execute(runcommand)
end