margin = 0.2

FOLD = require 'fold'

class Editor
  constructor: (@svg) ->
    @page =
      xMin: 0
      yMin: 0
      xMax: 4
      yMax: 4
    @fold =
      vertices_coords: []
      edges_vertices: []
      edges_assignment: []
    @gridGroup = @svg.group()
    .addClass 'grid'
    @creaseGroup = @svg.group()
    .addClass 'crease'
    @vertexGroup = @svg.group()
    .addClass 'vertex'
    @updateGrid()

  updateGrid: ->
    @gridGroup.clear()
    for x in [0..@page.xMax]
      @gridGroup.line x, @page.yMin, x, @page.yMax
    for y in [0..@page.yMax]
      @gridGroup.line @page.xMin, y, @page.xMax, y
    @svg.viewbox @page.xMin - margin, @page.yMin - margin, @page.xMax - @page.xMin + 2*margin, @page.yMax - @page.yMin + 2*margin

  nearestFeature: (pt) ->
    x: Math.max @page.xMin, Math.min @page.xMax, Math.round pt.x
    y: Math.max @page.yMin, Math.min @page.yMax, Math.round pt.y

  setMode: (mode) ->
    @mode?.exit @
    @mode = mode
    @mode.enter @
  escape: ->
    @mode?.escape? @

  addVertex: (v) ->
    i = FOLD.filter.addVertex @fold, [v.x, v.y]
    if i == @fold.vertices_coords.length - 1
      @vertexGroup.circle 0.2
      .center v.x, v.y
    i
  addCrease: (p1, p2, assignment) ->
    p1 = @addVertex p1
    p2 = @addVertex p2
    newVertices = @fold.vertices_coords.length
    for e in FOLD.filter.addEdge @fold, p1, p2, FOLD.geom.EPS
      @fold.edges_assignment[e] = assignment
      coords = (@fold.vertices_coords[v] for v in @fold.edges_vertices[e])
      @creaseGroup.line coords[0][0], coords[0][1], coords[1][0], coords[1][1]
      .addClass assignment
    for v in @fold.vertices_coords[newVertices..]
      @vertexGroup.circle 0.2
      .center ...v

class Mode
  enter: ->
  exit: (editor) ->
    editor.svg
    .mousemove null
    .mousedown null
    .mouseup null
    .mouseenter null

class LineDrawMode extends Mode
  constructor: (@lineType) ->
    super()
  enter: (editor) ->
    svg = editor.svg
    @which = 0 ## 0 = first point, 1 = second point
    @points = {}
    @circles = []
    @crease = @line = null
    @dragging = false
    svg.mousemove move = (e) =>
      point = editor.nearestFeature svg.point e.clientX, e.clientY
      ## Wait for distance threshold in drag before triggering drag
      if e.buttons
        if @points.down?
          unless point.x == @points.down.x and
                 point.y == @points.down.y
            @dragging = true
            @which = 1
        else if @points.down == null
          @points.down = point
      @points[@which] = point
      unless @which < @circles.length
        @circles.push(
          svg.circle 0.3
          .addClass 'drag'
        )
      @circles[@which].center @points[@which].x, @points[@which].y
      if @which == 1
        @line ?= editor.creaseGroup.line().addClass 'drag'
        @crease ?= editor.creaseGroup.line().addClass @lineType
        @line.plot @points[0].x, @points[0].y, @points[1].x, @points[1].y
        @crease.plot @points[0].x, @points[0].y, @points[1].x, @points[1].y
    svg.mousedown (e) =>
      @points.down = null # special value meaning 'set'
      move e
    svg.mouseup (e) =>
      move e
      ## Click, click style line drawing: advance to second point if not
      ## currently in drag mode, and didn't just @escape (no "down" point).
      if @which == 0 and not @dragging and @points.down != undefined
        @which = 1
      else
        ## Commit new crease, unless it's zero length.
        unless @points[0].x == @points[1].x and
               @points[0].y == @points[1].y
          editor.addCrease @points[0], @points[1], @lineType
          @crease = null  # prevent removal in @escape
        @escape editor
        move e
    svg.mouseenter (e) =>
      ## Cancel crease if user exits, lets go of button, and re-enters
      @escape editor if @dragging and e.buttons == 0
      move e
  escape: (editor) ->
    @circles.pop().remove() while @circles.length
    @crease?.remove()
    @line?.remove()
    @crease = @line = null
    @which = 0
    @dragging = false
    @points.down = undefined
  exit: (editor) ->
    super editor
    @escape editor

window?.onload = ->
  svg = SVG 'interface'
  editor = new Editor svg
  for input in document.getElementsByTagName 'input'
    do (input) ->
      if input.checked
        editor.setMode new LineDrawMode input.id
      input.addEventListener 'change', (e) ->
        return unless e.target.checked
        editor.setMode new LineDrawMode e.target.id
      input.parentElement.addEventListener 'click', ->
        input.click()
  window.addEventListener 'keyup', (e) =>
    switch e.key
      when 'b', 'B'
        document.getElementById('boundary').click()
      when 'm', 'M'
        document.getElementById('mountain').click()
      when 'v', 'V'
        document.getElementById('valley').click()
      when 'u', 'U'
        document.getElementById('unfolded').click()
      when 'c', 'C'
        document.getElementById('cut').click()
      when 'Escape'
        editor.escape()
