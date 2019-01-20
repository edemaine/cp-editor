margin = 0.5

FOLD = require 'fold'

class Editor
  constructor: (@svg) ->
    @page =
      xMin: 0
      yMin: 0
      xMax: 4
      yMax: 4
    @fold =
      file_spec: 1.1
      file_creator: 'Crease Pattern Editor'
      file_classes: ['singleModel']
      frame_classes: ['creasePattern']
      vertices_coords: []
      edges_vertices: []
      edges_assignment: []
    @gridGroup = @svg.group()
    .addClass 'grid'
    @creaseGroup = @svg.group()
    .addClass 'crease'
    @creaseLine = {}
    @vertexGroup = @svg.group()
    .addClass 'vertex'
    @vertexCircle = {}
    @dragGroup = @svg.group()
    .addClass 'drag'
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
    [i, changedEdges] =
      FOLD.filter.addVertexAndSubdivide @fold, [v.x, v.y], FOLD.geom.EPS
    @drawVertex i if i == @fold.vertices_coords.length - 1  # new vertex
    @drawEdge e for e in changedEdges
    i
  addCrease: (p1, p2, assignment) ->
    p1 = @addVertex p1
    p2 = @addVertex p2
    newVertices = @fold.vertices_coords.length
    changedEdges = FOLD.filter.addEdgeAndSubdivide @fold, p1, p2, FOLD.geom.EPS
    for e in changedEdges[0]
      @fold.edges_assignment[e] = assignment
    @drawEdge e for e in changedEdges[i] for i in [0, 1]
    @drawVertex v for v in [newVertices ... @fold.vertices_coords.length]
    console.log @fold
    #@loadCP @fold

  loadCP: (@fold) ->
    @vertexGroup.clear()
    @drawVertex v for v in [0...@fold.vertices_coords.length]
    @creaseGroup.clear()
    @drawEdge v for v in [0...@fold.edges_vertices.length]
  drawVertex: (v) ->
    @vertexCircle[v]?.remove()
    @vertexCircle[v] = @vertexGroup.circle 0.2
    .center ...(@fold.vertices_coords[v])
  drawEdge: (e) ->
    @creaseLine[e]?.remove()
    coords = (@fold.vertices_coords[v] for v in @fold.edges_vertices[e])
    @creaseLine[e] =
    @creaseGroup.line coords[0][0], coords[0][1], coords[1][0], coords[1][1]
    .addClass @fold.edges_assignment[e]

  downloadCP: ->
    json = FOLD.convert.toJSON @fold
    a = document.getElementById 'cplink'
    a.href = URL.createObjectURL new Blob [json], type: "application/json"
    a.download = 'creasepattern.cp'
    a.click()
  downloadFold: ->
    ## Add face structure to @fold
    fold = FOLD.convert.deepCopy @fold
    FOLD.convert.edges_vertices_to_vertices_edges_sorted fold
    FOLD.filter.cutEdges fold, FOLD.filter.edgesAssigned fold, 'C'
    console.log 'cut', fold
    FOLD.convert.vertices_edges_to_faces_vertices_edges fold
    console.log fold
    
    ## Export and download
    json = FOLD.convert.toJSON fold
    a = document.getElementById 'foldlink'
    a.href = URL.createObjectURL new Blob [json], type: "application/json"
    a.download = 'creasepattern.fold'
    a.click()
  downloadSVG: ->
    svg = SVG tempSVG
    svg.svg @svg.svg()
    svg.select('.M').each -> @stroke {color: '#ff0000', width: 0.1}
    svg.select('.V').each -> @stroke {color: '#0000ff', width: 0.1}
    svg.select('.B').each -> @stroke {color: '#000000', width: 0.1}
    svg.select('.C').each -> @stroke {color: '#ffff00', width: 0.1}
    svg.select('.grid, .vertex, .drag').each -> @remove()
    svg = svg.svg()
    a = document.getElementById 'svglink'
    a.href = URL.createObjectURL new Blob [svg], type: "image/svg+xml"
    a.download = 'creasepattern.svg'
    a.click()

class Mode
  enter: ->
  exit: (editor) ->
    editor.svg
    .mousemove null
    .mousedown null
    .mouseup null
    .mouseenter null
    .mouseleave null

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
        @circles.push editor.dragGroup.circle 0.3
      @circles[@which].center @points[@which].x, @points[@which].y
      if @which == 1
        @line ?= editor.dragGroup.line().addClass 'drag'
        @crease ?= editor.dragGroup.line().addClass @lineType
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
    svg.mouseleave (e) =>
      if @circles.length == @which + 1
        @circles.pop().remove()
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
  for input in document.getElementsByClassName 'lineType'
    do (input) ->
      if input.checked
        editor.setMode new LineDrawMode input.value
      input.addEventListener 'change', (e) ->
        return unless e.target.checked
        editor.setMode new LineDrawMode e.target.value
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
  document.getElementById('loadCP').addEventListener 'click', ->
    document.getElementById('fileCP').click()
  document.getElementById('fileCP').addEventListener 'change', (e) ->
    return unless e.target.files.length
    file = e.target.files[0]
    reader = new FileReader
    reader.onload = ->
      editor.loadCP JSON.parse reader.result
    reader.readAsText file
  document.getElementById('downloadCP').addEventListener 'click', ->
    editor.downloadCP()
  document.getElementById('downloadFold').addEventListener 'click', ->
    editor.downloadFold()
  document.getElementById('downloadSVG').addEventListener 'click', ->
    editor.downloadSVG()
