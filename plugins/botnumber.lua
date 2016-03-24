do

function run(msg, matches)
send_contact(get_receiver(msg), "خودت پیدا کن ☺", "Triex", "BOT", ok_cb, false)
end

return {
patterns = {
"^!botnumber$"

},
run = run
}

end
