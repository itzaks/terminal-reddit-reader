createCharm = require("charm")
inherits = require("inherits")
EventEmitter = require("events").EventEmitter
resumer = require("resumer")

class Visual extends EventEmitter
  x: 1
  y: 1

  width: 100

  colors:
    fg: "white"
    bg: "blue"

  items: []
  lines: {}
  selected: 0

  constructor: ->
    @size = x: @width
    @init = x: @x, y: @y

    @charm = createCharm()
    @stream = @charm.pipe resumer()

    @charm.display "reset"
    @charm.display "bright"

    process.nextTick =>
      @charm.cursor false
      @draw()

    process.stdin.on "data", @ondata
    process.stdin.setRawMode true
    process.stdin.resume()

  add: (label, callback) ->
    index = @items.length

    if callback
      @on "select", (x, ix) -> (callback x, ix) if ix is index

    @items.push
      x: @x
      y: @y
      label: label

    @fillLine @y
    @y++

  reset: -> @charm.reset()
  createStream: -> @stream

  fillLine: (y) ->
    unless @lines[y]
      @charm.position @init.x, y
      @charm.write Array(1 + @size.x).join(" ")
      @lines[y] = true

  close: ->
    process.stdin.setRawMode false
    process.stdin.removeListener "data", @ondata

    @charm.cursor true
    @charm.display "reset"
    @charm.position 1, @y + 1
    @charm.end()

    process.stdin.destroy()

  write: (msg) ->
    @charm.background @colors.bg
    @charm.foreground @colors.fg

    @fillLine @y

    parts = msg.split("\n")
    i = 0

    while i < parts.length
      if parts[i].length
        @charm.position @x, @y
        @charm.write parts[i] + Array(Math.max(0, @width - parts[i].length)).join(' ')

      if i isnt parts.length - 1
        @x = @init.x
        @fillLine @y
        @y++

      i++

  draw: -> @drawRow i for i in [0..@items.length]

  drawRow: (index) ->
    index = (index + @items.length) % @items.length

    item = @items[index]

    return unless item

    @charm.position item.x, item.y

    if @selected is index
      @charm.background @colors.fg
      @charm.foreground @colors.bg
    else
      @charm.background @colors.bg
      @charm.foreground @colors.fg

    @charm.write item.label + Array(Math.max(0, @width - item.label.length)).join(' ')

  ondata: (buf) =>
    switch [].join.call(buf, ".")
      when "27.91.65", "107" #up
        @selected = (@selected - 1 + @items.length) % @items.length
        @drawRow @selected + 1
        @drawRow @selected

      when "27.91.66", "106" # down || j
        @selected = (@selected + 1) % @items.length
        @drawRow @selected - 1
        @drawRow @selected

      when "3", "113" # ^C || q
        process.stdin.setRawMode false
        @charm.reset()
        process.exit()

      when '13' then @emit 'select', @items[@selected].label, @selected


Reddit = require('handson-reddit')
reddit = new Reddit()
menu = new Visual()

menu.reset()
menu.createStream().pipe(process.stdout)
menu.on 'select', (label) ->
  menu.y = 0
  menu.reset()
  menu.write('SELECTED: ' + label)
  menu.draw()

menu.write("--- loading stuff ----\n")

reddit.r 'all', (err, data) ->
  menu.reset()
  menu.y = 1
  json = JSON.parse data.body
  menu.write("--- REDDIT OMG LOL HAX: #{ json.data.children.length }----\n")
  menu.write('-------------------------\n')

  for item in json.data.children.slice 0, 15
    menu.add item.data.title.substr(0, 100)
    menu.write('-------------------------\n')

  menu.draw()
