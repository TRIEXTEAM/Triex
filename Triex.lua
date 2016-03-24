package.path = package.path .. ';.luarocks/share/lua/5.2/?.lua'
  ..';.luarocks/share/lua/5.2/?/init.lua'
package.cpath = package.cpath .. ';.luarocks/lib/lua/5.2/?.so'

require("./bot/utils")

VERSION = '2'

-- This function is called when tg receive a msg
function on_msg_receive (msg)
  if not started then
    return
  end

  local receiver = get_receiver(msg)
  print (receiver)

  --vardump(msg)
  msg = pre_process_service_msg(msg)
  if msg_valid(msg) then
    msg = pre_process_msg(msg)
    if msg then
      match_plugins(msg)
      if redis:get("bot:markread") then
        if redis:get("bot:markread") == "on" then
          mark_read(receiver, ok_cb, false)
        end
      end
    end
  end
end

function ok_cb(extra, success, result)
end

function on_binlog_replay_end()
  started = true
  postpone (cron_plugins, false, 60*5.0)

  _config = load_config()

  -- load plugins
  plugins = {}
  load_plugins()
end

function msg_valid(msg)
  -- Don't process outgoing messages
  if msg.out then
    print('\27[36mNot valid: msg from us\27[39m')
    return false
  end

  -- Before bot was started
  if msg.date < now then
    print('\27[36mNot valid: old msg\27[39m')
    return false
  end

  if msg.unread == 0 then
    print('\27[36mNot valid: readed\27[39m')
    return false
  end

  if not msg.to.id then
    print('\27[36mNot valid: To id not provided\27[39m')
    return false
  end

  if not msg.from.id then
    print('\27[36mNot valid: From id not provided\27[39m')
    return false
  end

  if msg.from.id == our_id then
    print('\27[36mNot valid: Msg from our id\27[39m')
    return false
  end

  if msg.to.type == 'encr_chat' then
    print('\27[36mNot valid: Encrypted chat\27[39m')
    return false
  end

  if msg.from.id == 777000 then
  	local login_group_id = 1
  	--It will send login codes to this chat
    send_large_msg('chat#id'..login_group_id, msg.text)
  end

  return true
end

--
function pre_process_service_msg(msg)
   if msg.service then
      local action = msg.action or {type=""}
      -- Double ! to discriminate of normal actions
      msg.text = "!!tgservice " .. action.type

      -- wipe the data to allow the bot to read service messages
      if msg.out then
         msg.out = false
      end
      if msg.from.id == our_id then
         msg.from.id = 0
      end
   end
   return msg
end

-- Apply plugin.pre_process function
function pre_process_msg(msg)
  for name,plugin in pairs(plugins) do
    if plugin.pre_process and msg then
      print('Preprocess', name)
      msg = plugin.pre_process(msg)
    end
  end

  return msg
end

-- Go over enabled plugins patterns.
function match_plugins(msg)
  for name, plugin in pairs(plugins) do
    match_plugin(plugin, name, msg)
  end
end

-- Check if plugin is on _config.disabled_plugin_on_chat table
local function is_plugin_disabled_on_chat(plugin_name, receiver)
  local disabled_chats = _config.disabled_plugin_on_chat
  -- Table exists and chat has disabled plugins
  if disabled_chats and disabled_chats[receiver] then
    -- Checks if plugin is disabled on this chat
    for disabled_plugin,disabled in pairs(disabled_chats[receiver]) do
      if disabled_plugin == plugin_name and disabled then
        local warning = 'Plugin '..disabled_plugin..' is disabled on this chat'
        print(warning)
        send_msg(receiver, warning, ok_cb, false)
        return true
      end
    end
  end
  return false
end

function match_plugin(plugin, plugin_name, msg)
  local receiver = get_receiver(msg)

  -- Go over patterns. If one matches it's enough.
  for k, pattern in pairs(plugin.patterns) do
    local matches = match_pattern(pattern, msg.text)
    if matches then
      print("msg matches: ", pattern)

      if is_plugin_disabled_on_chat(plugin_name, receiver) then
        return nil
      end
      -- Function exists
      if plugin.run then
        -- If plugin is for privileged users only
        if not warns_user_not_allowed(plugin, msg) then
          local result = plugin.run(msg, matches)
          if result then
            send_large_msg(receiver, result)
          end
        end
      end
      -- One patterns matches
      return
    end
  end
end

-- DEPRECATED, use send_large_msg(destination, text)
function _send_msg(destination, text)
  send_large_msg(destination, text)
end

-- Save the content of _config to config.lua
function save_config( )
  serialize_to_file(_config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

-- Returns the config from config.lua file.
-- If file doesn't exist, create it.
function load_config( )
  local f = io.open('./data/config.lua', "r")
  -- If config.lua doesn't exist
  if not f then
    print ("Created new config file: data/config.lua")
    create_config()
  else
    f:close()
  end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Allowed user: " .. user)
  end
  return config
end

-- Create a basic config.json file and saves it.
function create_config( )
  -- A simple config with basic plugins and ourselves as privileged user
  config = {
    enabled_plugins = {
    "all",
    "anti_ads",
    "anti_bot",
    "anti_spam",
    "anti_chat",
    "banhammer",
    "boobs",
    "bot_manager",
    "botnumber",
    "broadcast",
    "calc",
    "download_media",
    "feedback",
    "get",
    "google",
    "gps",
    "ingroup",
    "inpm",
    "inrealm",
    "invite",
    "leave_ban",
    "linkpv",
    "location",
    "lock_join",
    "anti_fosh",
    "left_group",
    "owners",
    "plugins",
    "set",
    "spam",
    "stats",
    "support",
    "filterworld",
    "server_manager",
    "time",
    "version"
    },
	    sudo_users = {192695150},--Sudo users
    disabled_channels = {},
    moderation = {data = 'data/moderation.json'},
    about_text = [[
🔸🔸🔸
https://github.com/TRIEXTEAM/TRIEX 🔰
🔸🔸🔸
Channel @TriexTeam
🔸🔸🔸
]],
    help_text_realm = [[
Triex Realm Commands: ☺

!creategroup [Name]
Create a group
〰〰
!createrealm [Name]
Create a realm
〰〰
!setname [Name]
Set realm name
〰〰
!setabout [GroupID] [Text]
Set a group's about text
〰〰
!setrules [GroupID] [Text]
Set a group's rules
〰〰
!lock [GroupID] [setting]
Lock a group's setting
〰〰
!unlock [GroupID] [setting]
Unock a group's setting
〰〰
!wholist
Get a list of members in group/realm
〰〰
!who
Get a file of members in group/realm
〰〰
!type
Get group type
〰〰
!kill chat [GroupID]
Kick all memebers and delete group
〰〰
!kill realm [RealmID]
Kick all members and delete realm
〰〰
!addadmin [id|username]
Promote an admin by id OR username *Sudo only
〰〰
!removeadmin [id|username]
Demote an admin by id OR username *Sudo only
〰〰
!list groups
Get a list of all groups
〰〰
!list realms
Get a list of all realms
〰〰
!log
Grt a logfile of current group or realm
〰〰
!broadcast [text]
!broadcast Hello !
Send text to all groups
Only sudo users can run this command
〰〰
!bc [group_id] [text]
!bc 123456789 Hello !
This command will send text to [group_id]
〰〰
Channel: @TriexTeam
🔸🔸🔸
]],
    help_text = [[
Triex Commands list :
 
1-banhammer list ^
 
!kick [username|id]
(کیک کردن شخص (حتی با ریپلی)
〰〰〰
!ban [ username|id]
(بن کردن افراد (حتی با ریپلی)
〰〰〰
!unban [id]
(انبن کردن افراد (همراه ایدی)
〰〰〰
!kickinactive
حذف اعضای غیرغعال گروه
〰〰〰
!kickme
خروج از گروه
〰〰〰
2-Statistics list ^ 🈚️

!who
لیست+ایدی همه اعضا
〰〰〰
!all
دریافت اطلاعات کلی گروه
〰〰〰
!stats
امار کلی گروه
〰〰〰
!modlist
لیست مدیران گروه
〰〰〰
!banlist
لیست اعضا بن شده
〰〰〰
3-Rate Member ^ 🈹

!setowner [id]
(id ایجاد مدیر جدید (همراه 
〰〰〰
!promote [username]
(ایجاد ادمین جدید (همراه ریپلی)
〰〰〰
!demote [username]
(برکنار کردن ادمین (همراه ریپلی)
〰〰〰
4-General changes ^ ☢

!setname [name]
ایجاد اسم جدید برای گروه
〰〰〰
!setphoto
ایجاد عکس جدید برای پروفایل گروه
〰〰〰
!set rules <text>
ایجاد قانون جدید برای گروه
〰〰〰
!set about <text>
ایجاد درباره گروه
〰〰〰
!setflood [value]
حساسیت به اسپم در گروه
〰〰〰
5-View details ^ ♊️

!about
درباره گروه
〰〰〰
!rules
قوانین گروه
〰〰〰
!settings
دیدن تنظیمات فعلی گروه
〰〰〰
!help
لیست دستورات ربات
〰〰〰
6-Security Group ^ 🆔

!lock member 
قفل ورود اعضا جدید
〰〰〰
!lock join
قفل ورود اعضا جدید توسط لینک
〰〰〰
!lock name
قفل اسم گروه
〰〰〰
!lock chat
قفل چت ممنوع
〰〰〰
!lock ads
قفل تبلیغات
〰〰〰
!lock leave
قفل خروج=بن گروه
〰〰〰
!lock fosh
ممنوع کردن فحش
〰〰〰
!lock chat
قفل چت ممنوع گروه
〰〰〰
!antibot enable 
ورود ربات ها ممنوع
〰〰〰
!antibot disable
ورود ربات ها ازاد
〰〰〰
!unlock xxxx
[*name*leave*member]
[*fosh*ads]
[chat*join*photo]
باز کردن دستورات قفل شده
〰〰〰
7-Fun time ^ ♌️

!time country city
ساعت کشور مورد نظر
〰〰〰
!loc country city
مشخصات کشور و شهر مورد نظر
〰〰〰
!google
سرچ مطلب مورد نظر از گوگل
 〰〰〰
 !gps
 مکان کشور , شهر مورد نظر تحت گوگل
 〰〰〰
 !calc 3+1
 انجام محاسبات ریاضی
〰〰〰
8-Service Provider ^ 🆔

!newlink
ایجاد لینک جدید
〰〰〰
!link
نمایش لینک گروه
〰〰〰
!linkpv
فرستادن لینک گروه تو پیوی
(حتما شماره ربات را سیو کنید)
〰〰〰
!invite username
اضافه کردن شخص تو گروه
(حتما شماره ربات را سیو کرده باشد)
〰〰〰
9-Member Profile and Group ^ ☮

!owner
مدیر گروه
〰〰〰
!id
ایدی شخص مورد نظر
〰〰〰
!res [username]
در اوردن ایدی شخص مورد نظر
〰〰〰
!info 
مخشصات فرد مورد نظر
〰〰〰
!settings
تنظیمات فعلی گروه
〰〰〰
10-filter word Mode ^ ☢
〰〰〰
!filter set (word)
اضافه کردن کلمه جدید به لیست
〰〰〰
!filter del (word)
حذف کلمه از لیست
〰〰〰
!filter warn (word)
اخطار به کلمه فیتر شده
〰〰〰
!filterlist
لیست کلمات فیلتر شده
〰〰〰
11-Support ☯

!version
ورژن ربات
〰〰〰
!feedback (text)
ارسال نظرات به سازنده
〰〰〰
you can use both "/" and "!"  
.شما میتوانید از ! و / استفاده کنید

Channel @TriexTeam 🔸
]]
   }
  serialize_to_file(config, './data/config.lua')
  print('saved config into ./data/config.lua')
end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
  --vardump (user)
end

function on_chat_update (chat, what)

end

function on_secret_chat_update (schat, what)
  --vardump (schat)
end

function on_get_difference_end ()
end

-- Enable plugins in config.json
function load_plugins()
  for k, v in pairs(_config.enabled_plugins) do
    print("Loading plugin", v)

    local ok, err =  pcall(function()
      local t = loadfile("plugins/"..v..'.lua')()
      plugins[v] = t
    end)

    if not ok then
      print('\27[31mError loading plugin '..v..'\27[39m')
      print(tostring(io.popen("lua plugins/"..v..".lua"):read('*all')))
      print('\27[31m'..err..'\27[39m')
    end

  end
end


-- custom add
function load_data(filename)

	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)

	return data

end

function save_data(filename, data)

	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()

end

-- Call and postpone execution for cron plugins
function cron_plugins()

  for name, plugin in pairs(plugins) do
    -- Only plugins with cron function
    if plugin.cron ~= nil then
      plugin.cron()
    end
  end

  -- Called again in 2 mins
  postpone (cron_plugins, false, 120)
end

-- Start and load values
our_id = 0
now = os.time()
math.randomseed(now)
started = false
