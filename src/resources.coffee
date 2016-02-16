# Description
#   A hubot script that manages limited resources, primarily staging servers that
#   you can deploy to. It's also useful for other limited resources, to know who
#   has it and who gets to use it next.
#
# Configuration:
#   LIST_OF_ENV_VARS_TO_SET
#
# Commands:
#   hubot John is using the_resource - <assigns a resource to someone else>
#   who has the_resource - <find out who has the resource>
#   what's up with the_resource - <find out who has the resource>
#   the_resource is (all) (free|clear) - <clears out the resource if you have it>
#   can I (have|use) the_resource - <claims the resource if it's available>
#   I can haz the_resource - <claims the resource if it's available>
#   Hostile takeover the_resource - <steals the resource from someone else>
#   hubot would you please release the_resource - <clears someone else from the resource>
#   dibs on the_resource - <claim your next-in-line spot for a resource (alternate word: shotgun)>
#   I give up my dibs - <clear your dibs to every resource>
#   (clear|bump|boot) dibs on the_resource - <clear someone else's dibs on a resource>
#   hubot create a resource the_resource - <creates a new resource>
#   hubot destroy the resource the_resource - <blow away the resource>
#   hubot watch for the_repo deploys (to|on) the_resource - <remember branches of the_repo deployed to the_resource>
#   hubot ignore the_repo deploys to|on the_resource - <stop remembering branches of the_repo deployed to the_resource>
#   what (branch is|branches are) on the_resource - <ask for a list of deployed branches>
#   list deployed the_repo? branches - <lists deployed branches, optionally filtered by repo>
#
# Notes:
#   <Make sure you add 'moment' and 'moment-timezone' to your package.json>
#
# Author:
#   Chris Dwan <radixhound@gmail.com>

moment = require('moment-timezone')

module.exports = (robot) ->

  getResourceOwner = (users, resource) ->
    for own key, user of users
      roles = user.roles or []
      if ///using\s#{resource}///.test roles.join(" ")
        resourceOwner = user
    resourceOwner

  getResourceBackup = (users, resource) ->
    for own key, user of users
      roles = user.roles or []
      if ///has\sdibs\son\s#{resource}///.test roles.join(" ")
        resourceBackup = user
    resourceBackup

  clearResourceOwner = (data, resource) ->
    for own key, user of data.users
      roles = user.roles or [ ]
      user.roles = (role for role in roles when role isnt "using #{resource}")

  clearResourceBackup = (data, resource) ->
    for own key, user of data.users
      roles = user.roles or [ ]
      user.roles = (role for role in roles when role isnt "has dibs on #{resource}")

  clearAllResourceBackups = (name) ->
    users = robot.brain.usersForFuzzyName(name)
    if users.length is 1
      user = users[0]
      roles = user.roles or [ ]
      user.roles = (role for role in roles when role isnt ///has\sdibs\son.*///)

  setResourceOwner = (data, resource, name) ->
    users = robot.brain.usersForFuzzyName(name)
    if users.length is 1
      user = users[0]
      user.roles = user.roles or [ ]
      if "using #{resource}" not in user.roles
        user.roles.push("using #{resource}")

  setResourceBackup = (data, resource, name) ->
    users = robot.brain.usersForFuzzyName(name)
    if users.length is 1
      user = users[0]
      user.roles = user.roles or [ ]
      if "has dibs on #{resource}" not in user.roles
        user.roles.push("has dibs on #{resource}")

  appendResource = (brain, team, resource) ->
    resources = brain.data.resources || {}
    if resources[resource]
      false
    else
      resources[resource] = {team: team}
      brain.data.resources = resources
      true

  removeResource = (brain, resource) ->
    resources = brain.data.resources || {}
    if resources[resource]
      delete resources[resource]
      brain.data.resources = resources
      true
    else
      false

  associateRepo = (brain, resource, repo) ->
    resources = brain.data.resources || {}
    relevantResource = resources[resource]
    if relevantResource
      branches = relevantResource.branches || []
      relevantBranch = false
      for branch in branches
        relevantBranch = branch if branch.repo is repo
      if !relevantBranch
        branches.push { repo: repo }
      relevantResource.branches = branches
      true
    else
      false

  dissociateRepo = (brain, resource, repo) ->
    resources = brain.data.resources || {}
    relevantResource = resources[resource]
    if relevantResource
      branches = relevantResource.branches || []
      branches = branches.filter (branch) -> (branch.repo isnt repo)
      relevantResource.branches = branches
      true
    else
      false

  getResourceBranches = (brain, resource) ->
    resources = brain.data.resources || {}
    relevantResource = resources[resource]
    if relevantResource
      relevantResource.branches
    else
      false

  findResourceRepoBranch = (brain, resource, repo) ->
    branches = getResourceBranches brain, resource
    if branches
      targetBranch = false
      for branch in branches
        targetBranch = branch if branch.repo is repo
      targetBranch
    else
      false

  replaceMention = (text, user) ->
    replacement = "";
    if user.mention_name
      replacement = "@#{user.mention_name}"
    else if user.id
      replacement = "<@#{user.id}>"
    else
      replacement = "@#{user.name}"

    return text.replace("#MENTION#", replacement)

  ####################### RESOURCE CLAIMING ############################

  # inquire who is using a resource
  robot.hear /(?:who has|who is using|what\Ws up with) ([\w.-]+)?/i, (msg) ->
    resource = msg.match[1].trim()
    if robot.brain.data.resources[resource]
      resourceOwner = getResourceOwner(robot.brain.data.users, resource)
      if resourceOwner
        msg.send replaceMention("#MENTION# has #{resource}", resourceOwner)
      else
        msg.send "No one has told me they have #{resource}."
      resourceBackup = getResourceBackup(robot.brain.data.users, resource)
      if resourceBackup
        msg.send "#{resourceBackup.name} has dibs on #{resource}"
    else
      msg.send "/me scratches its virtual robotic head with a virtual robotic finger"

  # Take a resource
  robot.hear /Hostile takeover ([\w.-]+)!/i, (msg) ->
    EMPTY = {}
    resource = msg.match[1].trim()
    if robot.brain.data.resources[resource]
      stagingOwner = getResourceOwner(robot.brain.data.users, resource) || EMPTY
      if stagingOwner isnt EMPTY
        clearResourceOwner(robot.brain.data, resource)
        resourceBackup = getResourceBackup(robot.brain.data.users, resource) || EMPTY
        setResourceOwner(robot.brain.data, resource, msg.message.user.name)
        if resourceBackup isnt EMPTY
          msg.send replaceMention("ok... but #MENTION# isn't going to like it!", resourceBackup);
        else
          msg.send replaceMention("So #MENTION#, #{msg.message.user.name} like totally broke in and tossed you out of the drivers' seat for #{resource}. Sucks dude. Have a doughnut :doughnut:.", stagingOwner)
      else
        msg.send "Why kick down the door when it's unlocked, #{msg.message.user.name}?"
    else
      odd_things = ["a box of doughnuts", "the library", "a yoga studio", "the alphabet", "the toilet", "the espresso machine"]
      msg.send "That's not going to work. Maybe try a hostile takeover of #{msg.random odd_things}? You might have more success."

  robot.hear /Hostile takeover ([\w.-]+)$/i, (msg) ->
    msg.send "Bang bang, you're dead. Try again with more conviction eh?"

  # Free a resource that you own
  robot.hear /([\w.-]+) is(?: all | )(?:free|clear)/i, (msg) ->
    EMPTY = {}
    resource = msg.match[1].trim()
    if robot.brain.data.resources[resource]
      stagingOwner = getResourceOwner(robot.brain.data.users, resource) || EMPTY
      if stagingOwner isnt EMPTY
        if msg.message.user.name == stagingOwner.name
          clearResourceOwner(robot.brain.data, resource)
          resourceBackup = getResourceBackup(robot.brain.data.users, resource) || EMPTY
          if resourceBackup isnt EMPTY
            clearResourceBackup(robot.brain.data, resource)
            setResourceOwner(robot.brain.data, resource, resourceBackup.name)
            msg.send replaceMention("ok #MENTION# now has #{resource}", resourceBackup);
          else
            msg.send "As you wish. #{resource} is now clear"
        else
          msg.send "I'm sorry but only #{stagingOwner.name} can make that call, Richard."
      else
        msg.send "Yes, I know. Why must you state the obvious?"
    else
      odd_things = ["my left nut", "a dirty sock", "my roommate's undies", "Mark's beard", "Adam's apple", "a squeeze of a jersey cow's udder", "a couch almond"]
      msg.send "Are you sure? I'm pretty sure I traded #{msg.random odd_things} for one once..."

  # free a resource someone else owns
  robot.respond /would you please release ([\w.-]+)?/i, (msg) ->
    EMPTY = {}
    resource = msg.match[1].trim()
    if robot.brain.data.resources[resource]
      clearResourceOwner(robot.brain.data, resource)
      resourceBackup = getResourceBackup(robot.brain.data.users, resource) || EMPTY
      if resourceBackup isnt EMPTY
        clearResourceBackup(robot.brain.data, resource)
        setResourceOwner(robot.brain.data, resource, resourceBackup.name)
        msg.send replaceMention("ok #MENTION# now has #{resource}", resourceBackup);
      else
        msg.send "okay #{resource} is clear."
    else
      msg.send "/me goes looking for a #{resource}"

  robot.respond /release ([\w.-]+)?/i, (msg) ->
    msg.send "Did your parents even teach you the magic word?"

  # claim a resource
  robot.hear /(?:I can|can [iI]|gimme) (?:have|haz|use|some) ([\w.-]+)\??/i, (msg) ->
    EMPTY = {}
    resource = msg.match[1].trim()
    if robot.brain.data.resources[resource]
      stagingOwner = getResourceOwner(robot.brain.data.users, resource) || EMPTY
      if stagingOwner isnt EMPTY
        if msg.message.user.name == stagingOwner.name
          msg.send "You already have it my little pumpkin pie."
        else
          friendly_things = ["the lovely", "my sweet little", "my darling", "the fabulous", "the amazing"]
          msg.send replaceMention("Sorry #{msg.random friendly_things} #MENTION# has #{resource}", stagingOwner);
          resourceBackup = getResourceBackup(robot.brain.data.users, resource) || EMPTY
          if resourceBackup isnt EMPTY
            msg.send "And #{resourceBackup.name} has dibs."
          else
          msg.send "But you can have dibs if you want it."
      else
        setResourceOwner(robot.brain.data, resource, msg.message.user.name)
        msg.send "You got it Kimosabe"
    else
      silly_things = ["the barn", "the kumquat", "that wookie", "the star port", "the dinghy", "your marbles", "the prisoner", "the llama massage booth", "the... I don't know, you silly human.", "the lost boys"]
      msg.send "I don't have a #{resource}. Maybe you should look out back by #{msg.random silly_things}?"

  robot.hear /What are dibs\??/i, (msg) ->
    msg.send "Dibs as in _rights, claims_. e.g. 'I have dibs on the car when Johnny brings it back.'"

  # claim dibs on resource
  robot.hear /^(?:I call dibs|dibs|shotgun) on ([\w.-]+)\??/i, (msg) ->
    EMPTY = {}
    resource = msg.match[1].trim()
    if robot.brain.data.resources[resource]
      resourceOwner = getResourceOwner(robot.brain.data.users, resource) || EMPTY
      if resourceOwner isnt EMPTY
        resourceBackup = getResourceBackup(robot.brain.data.users, resource) || EMPTY
        if resourceBackup isnt EMPTY
          if msg.message.user.name == resourceBackup.name
            msg.send "Well shewt, ya don't have ta keep tellin me!"
          else
            friendly_things = ["The beefy", "The mighty", "The patient", "The gracious", "The delightful", "One fantastic"]
            msg.send "Denied. #{msg.random friendly_things} #{resourceBackup.name} has dibs."
        else
          setResourceBackup(robot.brain.data, resource, msg.message.user.name)
          msg.send "You are now on deck"
      else
        msg.send "Why are you calling dibs? You can have it silly."
    else
      silly_things = ["tabanus nippontucki", 'heerz tooya', 'heerz lukenatcha', 'verae peculya', 'greasy spoon', 'troglodyte', 'furry faced hobbit', 'smiley faced fool', 'faulty flatulent feline friend', 'sweet little buttercup', 'bag of mostly watter']
      msg.send "You can't call dibs on #{resource} you silly little #{msg.random silly_things}"

  robot.hear /I give up all my dibs/i, (msg) ->
    clearAllResourceBackups(msg.message.user.name)
    msg.send "Ok #{msg.message.user.name}, your dibs are all cleared out."

  # remove from dibs queue
  robot.hear /(?:Remove|Delete) me from (?:dibs|shotgun) on ([\w.-]+)\??/i, (msg) ->
    EMPTY = {}
    resource = msg.match[1].trim()
    if robot.brain.data.resources[resource]
      resourceBackup = getResourceBackup(robot.brain.data.users, resource) || EMPTY
      if resourceBackup isnt EMPTY
        if msg.message.user.name is resourceBackup.name
          clearResourceBackup(robot.brain.data, resource)
          msg.send "You are no longer calling dibs for #{resource}."
        else
          msg.send "#{resourceBackup.name} has already got dibs on #{resource}."
      else
        msg.send "Silly Human, no one is... oh nevermind, why do I bother explaining?"
    else
      msg.send "#{resource}? We don't have no stinking #{resource}."

  # clear dibs queue
  robot.hear /(?:bump|boot|clear) dibs for ([\w.-]+)/i, (msg) ->
    EMPTY = {}
    resource = msg.match[1].trim()
    if robot.brain.data.resources[resource]
      resourceBackup = getResourceBackup(robot.brain.data.users, resource) || EMPTY
      if resourceBackup isnt EMPTY
        clearResourceBackup(robot.brain.data, resource)
        msg.send replaceMention("okay booting #MENTION# from dibs on #{resource}", resourceBackup);
      else
        msg.send "I'm gonna go all Skynet on y'all if ya keep talking nonsense."
    else
      msg.send "#{resource}? We don't have no stinking #{resource}."

  ####################### RESOURCES: CREATE/DESTROY/LIST ############################

  # robot resource creation commands
  robot.respond /(?:give me|create)(?: a)?(?: new)? resource ([\w.-]+) for the ([\w.-]+) team$/i, (msg) ->
    resource = msg.match[1]
    team = msg.match[2]
    if appendResource robot.brain, team, resource
      affections = ["have such cute stubby toes", "are such good friends to mice", "need so much help", "have great hygiene", "offered to clean my redis store", "generally suck more than most", "tend to smell less than you", "don't annoy me as much as you do", "are so predictable", "could hold their own in a zombie apocalypse"]
      msg.send "Because #{team} #{msg.random affections}, I have carefully crafted the best #{resource} in the history of the world."
    else
      msg.send "Meh. Seen it before"

  # robot resource destruction commands
  robot.respond /(?:destroy|blow away|get rid of)(?: the)? resource ([\w.-]+)$/i, (msg) ->
    resource = msg.match[1]
    if removeResource robot.brain, resource
      clearResourceOwner(robot.brain.data, resource)
      msg.send "Muahahahaha (boom) (boom) (awyeah)"
    else
      msg.send "WAT? (wat)"

  # lists resources
  robot.hear /list\s?([\w.-]+)? resources?/i, (msg) ->
    resourceStatuses = {}
    team = msg.match[1]
    for own resource, data of robot.brain.data.resources
      resourceStatuses[data.team] = [ ] unless resourceStatuses[data.team]
      owner = getResourceOwner(robot.brain.data.users, resource)
      if owner
        resourceStatuses[data.team].push "#{resource} [#{owner.name}]"
      else
        resourceStatuses[data.team].push "#{resource} [] "
    if team = msg.match[1]
      msg.send "#{resourceStatuses[data.team].join(', ')}"
    else
      for own team, statuses of resourceStatuses
        msg.send "#{team}: #{statuses.join(', ')}"

  ####################### WATCHES FOR REPO/BRANCH DEPLOYS  ############################

  # robot repo deploy watch commands
  robot.respond /watch for (\w+) deploys (to|on) (.+)/i, (msg) ->
    repo = msg.match[1]
    resources = msg.match[3].split(",")
    for resource in resources
      resource = resource.trim()
      if associateRepo robot.brain, resource, repo
        msg.send "Well then, I'll be watching for #{repo} deploys #{msg.match[2]} #{resource}"
      else
        msg.send "Weird... I don't know about a #{resource}"

  # robot repo deploy ignore watch commands
  robot.respond /ignore (\w+) deploys (to|on) (.+)/i, (msg) ->
    repo = msg.match[1]
    resources = msg.match[3].split(",")
    for resource in resources
      resource = resource.trim()
      if dissociateRepo robot.brain, resource, repo
        msg.send "Alright, consider #{repo} dead to #{resource}"
      else
        msg.send "To be honest, I don't think #{resource} ever cared about #{repo} to begin with!"

  # listen for deploys of a watched repo to a given resource
  robot.hear /(.+) finished deploying (\w+)\/([A-Za-z0-9_-]+) (?:\((.+)\)\s)?to (?:(?:\W+)?(\w+)(?:\W+)?).*/i, (msg) ->
    branch = findResourceRepoBranch robot.brain, msg.match[5], msg.match[2]
    if branch
      branch.deployer = msg.match[1]
      branch.timestamp = moment().tz('US/Pacific').format('h:mmA on YYYY/MM/DD')
      branch.branch = msg.match[3]
      branch.commit = msg.match[4]

  # inquire what branches are on a given resource
  robot.hear /(?:what branch is|what branches are) on ([\w.-]+)?/i, (msg) ->
    resource = msg.match[1].trim()
    if robot.brain.data.resources[resource]
      resourceBranches = getResourceBranches robot.brain, resource
      if resourceBranches and resourceBranches.length
        for branch in resourceBranches
          if branch.branch
            message = "#{branch.repo}/#{branch.branch}"
            if branch.commit
              message = message + " (#{branch.commit})"
            message = message + " is on #{resource} (deployed by #{branch.deployer} at #{branch.timestamp})"
            msg.send message
      else
        msg.send "/me doesn't know of any branches deployed to #{resource}"
    else
      msg.send "/me didn't know it was supposed to be watching deploys to #{resource}"

  # list all deployed branches
  robot.hear /list deployed ([A-Za-z0-9_-]+) branches/i, (msg) ->
    for resource of robot.brain.data.resources
      branches = getResourceBranches robot.brain, resource
      if branches and branches.length
        for branch in branches
          if msg.match[1] and msg.match[1].trim() isnt branch.repo
            continue
          if branch.branch
            message = "#{branch.repo}/#{branch.branch}"
            if branch.commit
              message = message + " (#{branch.commit})"
            message = message + " is on #{resource} (deployed by #{branch.deployer} at #{branch.timestamp})"
            msg.send message
