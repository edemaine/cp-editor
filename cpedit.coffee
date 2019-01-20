margin = 0.5

FOLD = require 'fold'

class Editor
  constructor: (@svg) ->
    @undoStack = []
    @redoStack = []
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
    p = [pt.x, pt.y]
    closest =
      [
        Math.max @page.xMin, Math.min @page.xMax, Math.round pt.x
        Math.max @page.yMin, Math.min @page.yMax, Math.round pt.y
      ]
    v = FOLD.geom.closestIndex p, @fold.vertices_coords
    if v?
      vertex = @fold.vertices_coords[v]
      if FOLD.geom.dist(vertex, p) < FOLD.geom.dist(closest, p)
        closest = vertex
    x: closest[0]
    y: closest[1]

  setMode: (mode) ->
    @mode?.exit @
    @mode = mode
    @mode.enter @
  setLineType: (@lineType) ->
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
    #console.log @fold
    #@loadCP @fold
  subdivide: ->
    FOLD.filter.collapseNearbyVertices @fold, FOLD.geom.EPS
    FOLD.filter.subdivideCrossingEdges_vertices @fold, FOLD.geom.EPS
    @loadCP @fold

  saveForUndo: ->
    @undoStack.push FOLD.convert.deepCopy @fold
    @redoStack = []
  undo: ->
    return unless @undoStack.length
    @redoStack.push @fold
    @fold = @undoStack.pop()
    @loadCP @fold
  redo: ->
    return unless @redoStack.length
    @undoStack.push @fold
    @fold = @redoStack.pop()
    @loadCP @fold

  loadCP: (@fold) ->
    @mode.exit @
    @vertexGroup.clear()
    @drawVertex v for v in [0...@fold.vertices_coords.length]
    @creaseGroup.clear()
    @drawEdge v for v in [0...@fold.edges_vertices.length]
    @mode.enter @
  drawVertex: (v) ->
    @vertexCircle[v]?.remove()
    @vertexCircle[v] = @vertexGroup.circle 0.2
    .center ...(@fold.vertices_coords[v])
    .attr 'data-index', v
  drawEdge: (e) ->
    @creaseLine[e]?.remove()
    coords = (@fold.vertices_coords[v] for v in @fold.edges_vertices[e])
    @creaseLine[e] =
    @creaseGroup.line coords[0][0], coords[0][1], coords[1][0], coords[1][1]
    .addClass @fold.edges_assignment[e]
    .attr 'data-index', e

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
    #console.log 'cut', fold
    FOLD.convert.vertices_edges_to_faces_vertices_edges fold
    #console.log fold
    
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

class LineDrawMode extends Mode
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
        if @down?
          unless point.x == @down.x and
                 point.y == @down.y
            @dragging = true
            @which = 1
        else if @down == null
          @down = point
      @points[@which] = point
      unless @which < @circles.length
        @circles.push editor.dragGroup.circle 0.3
      @circles[@which].center @points[@which].x, @points[@which].y
      if @which == 1
        @line ?= editor.dragGroup.line().addClass 'drag'
        @crease ?= editor.dragGroup.line().addClass editor.lineType
        @line.plot @points[0].x, @points[0].y, @points[1].x, @points[1].y
        @crease.plot @points[0].x, @points[0].y, @points[1].x, @points[1].y
    svg.mousedown (e) =>
      @down = null # special value meaning 'set'
      move e
    svg.mouseup (e) =>
      move e
      ## Click, click style line drawing: advance to second point if not
      ## currently in drag mode, and didn't just @escape (no "down" point).
      if @which == 0 and not @dragging and @down != undefined
        @which = 1
      else
        ## Commit new crease, unless it's zero length.
        unless @points[0].x == @points[1].x and
               @points[0].y == @points[1].y
          editor.saveForUndo()
          editor.addCrease @points[0], @points[1], editor.lineType
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
    @down = undefined
  exit: (editor) ->
    @escape editor
    editor.svg
    .mousemove null
    .mousedown null
    .mouseup null
    .mouseenter null
    .mouseleave null

class LineAssignMode extends Mode
  enter: (editor) ->
    svg = editor.svg
    svg.mousedown change = (e) =>
      return unless e.buttons
      return unless e.target.tagName == 'line'
      edge = e.target.getAttribute 'data-index'
      return unless edge
      unless editor.fold.edges_assignment[edge] == editor.lineType
        editor.saveForUndo()
        editor.fold.edges_assignment[edge] = editor.lineType
      editor.drawEdge edge
    svg.mouseover change  # painting
  exit: (editor) ->
    editor.svg
    .mousedown null
    .mouseover null

class VertexMoveMode extends Mode
  enter: (editor) ->
    svg = editor.svg
    svg.mousemove move = (e) =>
      @point = editor.nearestFeature svg.point e.clientX, e.clientY
      if @vertex?
        @drag editor
    svg.mousedown (e) =>
      @vertex = parseInt e.target.getAttribute 'data-index'
      if e.target.tagName == 'circle' and @vertex?
        @circle = SVG.get e.target.id
        .addClass 'drag'
        @down = null # special value meaning 'set'
        move e
      else
        @circle = @vertex = null
    svg.mouseup (e) =>
      move e
      if @vertex?
        ## Commit new location
        unless @point.x == editor.fold.vertices_coords[@vertex][0] and
               @point.y == editor.fold.vertices_coords[@vertex][1]
          editor.saveForUndo()
          editor.fold.vertices_coords[@vertex][0] = @point.x
          editor.fold.vertices_coords[@vertex][1] = @point.y
          @vertex = null
          editor.subdivide()
          #editor.drawVertex @vertex
          #for vertices, edge in editor.fold.edges_vertices
          #  editor.drawEdge edge if @vertex in vertices
        @escape editor
    svg.mouseover (e) =>
      return if @vertex?
      return unless e.target.tagName == 'circle' and e.target.getAttribute 'data-index'
      SVG.get(e.target.id).addClass 'drag'
    svg.mouseout (e) =>
      return unless e.target.tagName == 'circle' and e.target.getAttribute 'data-index'
      return if @vertex == parseInt e.target.getAttribute 'data-index'
      SVG.get(e.target.id).removeClass 'drag'
    #svg.mouseenter (e) =>
    #  ## Cancel crease if user exits, lets go of button, and re-enters
    #  @escape editor if @dragging and e.buttons == 0
    #  move e
    #svg.mouseleave (e) =>
    #  if @circles.length == @which + 1
    #    @circles.pop().remove()
  escape: (editor) ->
    if @vertex?
      @circle.removeClass 'drag'
      @point =
        x: editor.fold.vertices_coords[@vertex][0]
        y: editor.fold.vertices_coords[@vertex][1]
      @drag editor
    @circle = @vertex = null
  exit: (editor) ->
    @escape editor
    editor.svg
    .mousemove null
    .mousedown null
    .mouseup null
    .mouseenter null
    .mouseleave null
  drag: (editor) ->
    @circle.center @point.x, @point.y
    vertex = @vertex
    point = @point
    editor.svg.select '.crease line'
    .each ->
      edge = @attr 'data-index'
      i = editor.fold.edges_vertices[edge].indexOf vertex
      if i >= 0
        @attr "x#{i+1}", point.x
        @attr "y#{i+1}", point.y

modes =
  drawLine: new LineDrawMode
  assignLine: new LineAssignMode
  moveVertex: new VertexMoveMode

window?.onload = ->
  svg = SVG 'interface'
  editor = new Editor svg
  for input in document.getElementsByTagName 'input'
    do (input) ->
      switch input.getAttribute 'name'
        when 'mode'
          if input.checked
            editor.setMode modes[input.id]
          input.addEventListener 'change', (e) ->
            return unless input.checked
            if input.id of modes
              editor.setMode modes[input.id]
            else
              console.warn "Unrecognized mode #{input.id}"
        when 'line'
          if input.checked
            editor.setLineType input.value
          input.addEventListener 'change', (e) ->
            return unless input.checked
            editor.setLineType input.value
      input.parentElement.addEventListener 'click', ->
        input.click()
  window.addEventListener 'keyup', (e) =>
    switch e.key
      when 'd', 'D'
        document.getElementById('drawLine').click()
      when 'a', 'A'
        document.getElementById('assignLine').click()
      when 'm'
        document.getElementById('moveVertex').click()
      when 'b', 'B'
        document.getElementById('boundary').click()
      when 'M'
        document.getElementById('mountain').click()
      when 'V'
        document.getElementById('valley').click()
      when 'u', 'U'
        document.getElementById('unfolded').click()
      when 'c', 'C'
        document.getElementById('cut').click()
      when 'Escape'
        editor.escape()
      when 'z'
        editor.undo()
      when 'y', 'Z'
        editor.redo()
  document.getElementById('undo').addEventListener 'click', ->
    editor.undo()
  document.getElementById('redo').addEventListener 'click', ->
    editor.redo()
  document.getElementById('loadCP').addEventListener 'click', (e) ->
    e.stopPropagation()
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
