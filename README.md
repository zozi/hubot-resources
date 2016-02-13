# hubot-resources

A hubot script that manages limited resources, primarily staging servers that
you can deploy to. It's also useful for other limited resources, to know who
has it and who gets to use it next.

See [`src/resources.coffee`](src/resources.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-resources --save`

Then add **hubot-resources** to your `external-scripts.json`:

```json
[
  "hubot-resources"
]
```

## Sample Interaction

```
user1>> hubot create a new resource staging
hubot>> Yeehaw! Oh boy this will be the best staging you ever did see.
user1>> I can haz staging?
hubot>> You got it kimosabe.
user1>> staging is all clear
user2>> dibs on staging
hubot>> You are now on deck
hubot>> ok @user1 now has staging
```
