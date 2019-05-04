function LogVariables(x, depth, name)
  for k, v in pairs(x) do
    if (depth > 0) or ((string.find(k, "device") ~= nil) or (string.find(k, "variable") ~= nil) or 
                      (string.sub(k, 1, 4) == "time") or (string.sub(k, 1, 8) == "security")) then
      if type(v) == "string" then print(name .. "['" .. k .. "'] = '" .. v .. "'") end
      if type(v) == "number" then print(name .. "['" .. k .. "'] = " .. v) end
      if type(v) == "boolean" then print(name .. "['" .. k .. "'] = " .. tostring(v)) end
      if type(v) == "table" then LogVariables(v, depth+1, k); end
    end
  end
end

function read_file(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read "*a" 
  file:close()
  return content
end

function write_file(path, value)
  local file = io.open(path, "w")
  file:write(value)
  file:close()
end

function append_file(path, value)
  local file = io.open(path, "a")
  file:write(value)
  file:close()
end

function notify(priority, title, message)
  runcommand = "curl -s --form-string 'token=<MAIN_TOKEN>' --form-string 'user=<MAIN_USER>' --form-string 'priority=" .. priority .. "' --form-string 'title=" .. title .. "' --form-string 'message=" .. message .. "' https://api.pushover.net/1/messages.json >> /tmp/notification.log 2>&1 &"
  append_file("/tmp/notification.log", "\n")
  os.execute(runcommand)
end

function lua_print(message)
  print(message)
  append_file("/tmp/lua_scripts.log", os.date("%c") .. " " .. message .. "\n")
end

function load()
  startmorning = 6 * 60 + 30
  endmorning = 8 * 60 + 30
  startevening = timeofday["SunsetInMinutes"]
  endevening = 23 * 60 + 30
  openblinds = 7 * 60 + 5
  closeblinds = timeofday["SunsetInMinutes"] + 15

  luxlevel = 12
  now = os.date("*t")
  wday = now.wday
  minutes = now.min + now.hour * 60

  if (wday == 1 or wday == 7) then
    startmorning = startmorning + 1 * 60
    endmorning = endmorning + 1 * 60
    openblinds = openblinds + 1 * 60
  end

  if (closeblinds < (18 * 60)) then
    closeblinds = 18 * 60
  elseif (closeblinds > (19 * 60)) then 
    closeblinds = 19 * 60
  end

  if ((minutes >= startmorning and minutes <= endmorning) or (minutes >= startevening and minutes <= endevening)) then
    period = "true"
  else
    period = "false"
  end

  jeroenpresent = otherdevices["Jeroen"]
  kimpresent = otherdevices["Kim"]

  if (jeroenpresent == "On" or kimpresent == "On") then
    present = "true"
  else
    present = "false"
  end
end

function check_contacts()
  DomDevices = {"Voordeur", "Tuindeur", "Achterdeur", "Garage Voor", "Garage Achter", "Deur Balkon", "Raam Jens", "Raam Kledingkamer", "Raam Milan L", "Raam Milan R"}
  totalmessage = ""

  for i = 1, #DomDevices, 1 do
    CheckDevice = DomDevices[i]
    if (otherdevices[CheckDevice] ~= "Closed") then
      totalmessage = totalmessage .. CheckDevice .. ", "
      return CheckDevice
    end
  end

  if (totalmessage ~= "") then
    totalmessage = s:gsub("^%s*(.-)%s*$", totalmessage)
    totalmessage = s:gsub("^(.-),$", totalmessage)
  end

  return totalmessage
end

function debugmessage()
  if (debug) then
    print ("***********************************************")
    print ("Changed Device: " .. changeddevice .. " / Changed Status: " .. changedstatus)
    print ("Stored Scene Status: " .. uservariables["last_scene"])
    print ("Stored Lux Status: " .. uservariables["last_lux"])
    print ("Jeroen Present: " .. jeroenpresent .. " / Kim Present: " .. kimpresent)
    print ("Current Present: " .. present)
    print ("Stored Present: " .. uservariables["last_present"])
    print ("Now: " .. minutes)
    print ("Morning: " .. startmorning .. " - " .. endmorning)
    print ("Morning: " .. startevening .. " - " .. endevening)
    print ("Open blinds: " .. openblinds .. " / Close blinds: " .. closeblinds)  
    print ("In period: " .. period)
    print ("***********************************************")
  end

  if (fulldebug) then
    LogVariables(_G, 0, "")
  end
end