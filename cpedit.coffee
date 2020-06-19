margin = 0.5
defaultPage = ->
  xMin: 0
  yMin: 0
  xMax: 4
  yMax: 4

FOLD = require 'fold'

foldAngleToOpacity = (foldAngle, assignment) ->
  if assignment in ['M', 'V']
    Math.max 0.1, (Math.abs foldAngle ? 180) / 180
  else
    1

class Editor
  constructor: (@svg) ->
    @undoStack = []
    @redoStack = []
    @updateUndoStack()
    @fold =
      file_spec: 1.1
      file_creator: 'Crease Pattern Editor'
      file_classes: ['singleModel']
      frame_classes: ['creasePattern']
      vertices_coords: []
      edges_vertices: []
      edges_assignment: []
      edges_foldAngle: []
      "cpedit:page": defaultPage()
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
    # Call whenever page dimensions change
    page = @fold["cpedit:page"]
    document.getElementById('width')?.innerHTML = page.xMax
    document.getElementById('height')?.innerHTML = page.yMax
    @gridGroup.clear()
    for x in [0..page.xMax]
      @gridGroup.line x, page.yMin, x, page.yMax
    for y in [0..page.yMax]
      @gridGroup.line page.xMin, y, page.xMax, y
    @svg.viewbox page.xMin - margin, page.yMin - margin, page.xMax - page.xMin + 2*margin, page.yMax - page.yMin + 2*margin

  nearestFeature: (pt) ->
    p = [pt.x, pt.y]
    page = @fold["cpedit:page"]
    closest =
      [
        Math.max page.xMin, Math.min page.xMax, Math.round pt.x
        Math.max page.yMin, Math.min page.yMax, Math.round pt.y
      ]
    v = FOLD.geom.closestIndex p, @fold.vertices_coords
    if v?
      vertex = @fold.vertices_coords[v]
      if FOLD.geom.dist(vertex, p) < FOLD.geom.dist(closest, p)
        closest = vertex
    x: closest[0]
    y: closest[1]

  setTitle: (title) ->
    @fold['file_title'] = title

  setMode: (mode) ->
    @mode?.exit @
    @mode = mode
    @mode.enter @
  setLineType: (@lineType) ->
  setAbsFoldAngle: (@absFoldAngle) ->
  getFoldAngle: ->
    if @lineType == 'V'
      @absFoldAngle
    else if @lineType == 'M'
      -@absFoldAngle
    else
      0
  escape: ->
    @mode?.escape? @

  addVertex: (v) ->
    [i, changedEdges] =
      FOLD.filter.addVertexAndSubdivide @fold, [v.x, v.y], FOLD.geom.EPS
    @drawVertex i if i == @fold.vertices_coords.length - 1  # new vertex
    @drawEdge e for e in changedEdges
    i
  addCrease: (p1, p2, assignment, foldAngle) ->
    p1 = @addVertex p1
    p2 = @addVertex p2
    newVertices = @fold.vertices_coords.length
    changedEdges = FOLD.filter.addEdgeAndSubdivide @fold, p1, p2, FOLD.geom.EPS
    for e in changedEdges[0]
      @fold.edges_assignment[e] = assignment
      @fold.edges_foldAngle[e] = foldAngle
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
    @updateUndoStack()
  undo: ->
    return unless @undoStack.length
    @redoStack.push @fold
    @fold = @undoStack.pop()
    @loadCP @fold
    @updateUndoStack()
  redo: ->
    return unless @redoStack.length
    @undoStack.push @fold
    @fold = @redoStack.pop()
    @loadCP @fold
    @updateUndoStack()
  updateUndoStack: ->
    document.getElementById('undo')?.disabled = (@undoStack.length == 0)
    document.getElementById('redo')?.disabled = (@redoStack.length == 0)

  transform: (matrix, integerize = true) ->
    ###
    Main transforms we care about (reflection and 90-degree rotation) should
    preserve integrality of coordinates.  Force this when integerize is true.
    ###
    @saveForUndo()
    integers = (Number.isInteger(x) for x in coords \
                for coords in @fold.vertices_coords) if integerize
    FOLD.filter.transform @fold, matrix
    if integerize
      for ints, v in integers
        for int, i in ints when int
          @fold.vertices_coords[v][i] = Math.round @fold.vertices_coords[v][i]
    @loadCP @fold
  reflectX: ->
    {xMin, xMax} = @fold['cpedit:page']
    @transform FOLD.geom.matrixReflectAxis 0, 2, (xMin + xMax) / 2
  reflectY: ->
    {yMin, yMax} = @fold['cpedit:page']
    @transform FOLD.geom.matrixReflectAxis 1, 2, (yMin + yMax) / 2
  rotate90: (cw) ->
    {xMin, xMax, yMin, yMax} = @fold['cpedit:page']
    if cw
      angle = Math.PI/2
    else
      angle = -Math.PI/2
    @transform FOLD.geom.matrixRotate2D angle,
      [(xMin + xMax) / 2, (yMin + yMax) / 2]
  rotateCW: -> @rotate90 true
  rotateCCW: -> @rotate90 false

  loadCP: (@fold) ->
    @mode.exit @
    @drawVertices()
    @fold.edges_foldAngle ?=
      for assignment in @fold.edges_assignment
        switch assignment
          when 'V'
            180    # "The fold angle is positive for valley folds,"
          when 'M'
            -180   # "negative for mountain folds, and"
          else
            0      # "zero for flat, unassigned, and border folds"
    @drawEdges()
    @fold["cpedit:page"] ?=
      if @fold.vertices_coords?.length
        xMin: Math.min ...(v[0] for v in @fold.vertices_coords)
        yMin: Math.min ...(v[1] for v in @fold.vertices_coords)
        xMax: Math.max ...(v[0] for v in @fold.vertices_coords)
        yMax: Math.max ...(v[1] for v in @fold.vertices_coords)
      else
        defaultPage()
    @updateGrid()
    document.getElementById('title').value = @fold.file_title ? ''
    @mode.enter @
  drawVertices: ->
    @vertexGroup.clear()
    @drawVertex v for v in [0...@fold.vertices_coords.length]
  drawEdges: ->
    @creaseGroup.clear()
    @drawEdge e for e in [0...@fold.edges_vertices.length]
  drawVertex: (v) ->
    @vertexCircle[v]?.remove()
    @vertexCircle[v] = @vertexGroup.circle 0.2
    .center ...(@fold.vertices_coords[v])
    .attr 'data-index', v
  drawEdge: (e) ->
    @creaseLine[e]?.remove()
    coords = (@fold.vertices_coords[v] for v in @fold.edges_vertices[e])
    @creaseLine[e] =
    l = @creaseGroup.line coords[0][0], coords[0][1], coords[1][0], coords[1][1]
    .addClass @fold.edges_assignment[e]
    .attr 'stroke-opacity',
      foldAngleToOpacity @fold.edges_foldAngle[e], @fold.edges_assignment[e]
    .attr 'data-index', e

  downloadCP: ->
    json = FOLD.convert.toJSON @fold
    a = document.getElementById 'cplink'
    a.href = URL.createObjectURL new Blob [json], type: "application/json"
    a.download = (@fold.file_title or 'creasepattern') + '.cp'
    a.click()
  convertToFold: ->
    ## Add face structure to @fold
    fold = FOLD.convert.deepCopy @fold
    FOLD.convert.edges_vertices_to_vertices_edges_sorted fold
    FOLD.filter.cutEdges fold, FOLD.filter.edgesAssigned fold, 'C'
    #console.log 'cut', fold
    FOLD.convert.vertices_edges_to_faces_vertices_edges fold
    #console.log fold
    fold
  downloadFold: ->
    ## Export and download
    json = FOLD.convert.toJSON @convertToFold()
    a = document.getElementById 'foldlink'
    a.href = URL.createObjectURL new Blob [json], type: "application/json"
    a.download = (@fold.file_title or 'creasepattern') + '.fold'
    a.click()
  downloadSVG: ->
    svg = SVG tempSVG
    svg.svg @svg.svg()
    svg.select('.M').each -> @stroke {color: '#ff0000', width: 0.1}
    svg.select('.V').each -> @stroke {color: '#0000ff', width: 0.1}
    svg.select('.B').each -> @stroke {color: '#000000', width: 0.1}
    svg.select('.C').each -> @stroke {color: '#00ff00', width: 0.1}
    svg.select('.grid, .vertex, .drag').each -> @remove()
    svg = svg.svg()
    a = document.getElementById 'svglink'
    a.href = URL.createObjectURL new Blob [svg], type: "image/svg+xml"
    a.download = (@fold.file_title or 'creasepattern') + '.svg'
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
        .attr 'stroke-opacity',
          foldAngleToOpacity editor.getFoldAngle(), editor.lineType
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
          editor.addCrease @points[0], @points[1],
            editor.lineType, editor.getFoldAngle()
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

class LinePaintMode extends Mode
  enter: (editor) ->
    svg = editor.svg
    svg.mousedown change = (e) =>
      return unless e.buttons
      return unless e.target.tagName == 'line'
      edge = parseInt e.target.getAttribute 'data-index'
      return if isNaN edge
      @paint editor, edge
    svg.mouseover change  # painting
  exit: (editor) ->
    editor.svg
    .mousedown null
    .mouseover null

class LineAssignMode extends LinePaintMode
  paint: (editor, edge) ->
    unless editor.fold.edges_assignment[edge] == editor.lineType and
           editor.fold.edges_foldAngle[edge] == editor.getFoldAngle()
      editor.saveForUndo()
      editor.fold.edges_assignment[edge] = editor.lineType
      editor.fold.edges_foldAngle[edge] = editor.getFoldAngle()
      editor.drawEdge edge

class LineEraseMode extends LinePaintMode
  paint: (editor, edge) ->
    editor.saveForUndo()
    vertices = editor.fold.edges_vertices[edge]
    FOLD.filter.removeEdge editor.fold, edge
    editor.drawEdges()
    # Remove any now-isolated vertices
    incident = {}
    for edgeVertices in editor.fold.edges_vertices
      for vertex in edgeVertices
        incident[vertex] = true
    for vertex in vertices
      unless incident[vertex]
        FOLD.filter.removeVertex editor.fold, vertex
        editor.drawVertices() # might get called twice

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
    .select '.vertex circle.drag'
    .each -> @removeClass 'drag'
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
  eraseLine: new LineEraseMode
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
      when 'e', 'E'
        document.getElementById('eraseLine').click()
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
  for id in ['undo', 'redo', 'reflectX', 'reflectY', 'rotateCCW', 'rotateCW']
    do (id) ->
      document.getElementById(id).addEventListener 'click', (e) ->
        e.stopPropagation()
        editor[id]()
  document.getElementById('loadCP').addEventListener 'click', (e) ->
    e.stopPropagation()
    document.getElementById('fileCP').click()
  document.getElementById('fileCP').addEventListener 'input', (e) ->
    e.stopPropagation()
    return unless e.target.files.length
    file = e.target.files[0]
    reader = new FileReader
    reader.onload = ->
      editor.loadCP JSON.parse reader.result
    reader.readAsText file
  document.getElementById('downloadCP').addEventListener 'click', (e) ->
    e.stopPropagation()
    editor.downloadCP()
  document.getElementById('downloadFold').addEventListener 'click', (e) ->
    e.stopPropagation()
    editor.downloadFold()
  document.getElementById('downloadSVG').addEventListener 'click', (e) ->
    e.stopPropagation()
    editor.downloadSVG()
  for [size, dim] in [['width', 'x'], ['height', 'y']]
    for [delta, op] in [[-1, 'Dec'], [+1, 'Inc']]
      do (size, dim, delta, op) ->
        document.getElementById(size+op).addEventListener 'click', (e) ->
          e.stopPropagation()
          editor.saveForUndo()
          editor.fold["cpedit:page"][dim + 'Max'] += delta
          editor.updateGrid()
  document.getElementById('title').addEventListener 'input', (e) ->
    editor.setTitle document.getElementById('title').value
  ## Fold angle
  angleInput = document.getElementById 'angle'
  angle = null
  setAngle = (value) ->
    return unless typeof value == 'number'
    return if isNaN value
    angle = value
    angle = Math.max angle, 0
    angle = Math.min angle, 180
    angleInput.value = angle
    editor.setAbsFoldAngle angle
  setAngle parseFloat angleInput.value  # initial value
  angleInput.addEventListener 'change', (e) ->
    setAngle eval angleInput.value  # allow formulas via eval
  for [sign, op] in [[+1, 'Add'], [-1, 'Sub']]
    for amt in [1, 90]
      document.getElementById("angle#{op}#{amt}").addEventListener 'click',
        do (sign, amt) -> (e) ->
          setAngle angle + sign * amt
  ## Origami Simulator
  simulator = null
  ready = false
  onReady = null
  checkReady = ->
    if ready
      onReady?()
      onReady = null
  window.addEventListener 'message', (e) ->
    if e.data and e.data.from == 'OrigamiSimulator' and e.data.status == 'ready'
      ready = true
      checkReady()
  document.getElementById('simulate').addEventListener 'click', (e) ->
    if simulator? and not simulator.closed
      simulator.focus()
    else
      ready = false
      simulator = window.open 'OrigamiSimulator/?model=', 'simulator'
    fold = editor.convertToFold()
    ## Origami Simulator wants 'F' for unfolded (facet) creases;
    ## it uses 'U' for undriven creases. :-/
    fold.edges_assignment =
      for assignment in fold.edges_assignment
        if assignment == 'U'
          'F'
        else
          assignment
    onReady = -> simulator.postMessage
      op: 'importFold'
      fold: fold
    , '*'
    checkReady()
