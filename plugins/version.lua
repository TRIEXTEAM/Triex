do

function run(msg, matches)
  return 'Triex'.. VERSION .. [[ 
 
 ❕ Developers : @ArianTriex / @IliyaTriex / @MersadTriex
  
 🔱 Channel : @TriexTeam
  
 ⌚ Open git : https://github.com/TRIEXTEAM/Triex
  
  🔰 Triex ⓒ CopyRight Triex Team
  
  __________________]]
end

return {
  description = "Shows bot version", 
  usage = "!version: Shows bot version",
  patterns = {
    "^!version$"
  }, 
  run = run 
}

end
