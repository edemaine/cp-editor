margin = 0.1

class Editor
  constructor: (@svg) ->
    @page =
      xMin: 0
      yMin: 0
      xMax: 4
      yMax: 4
    @gridGroup = @svg.group()
    .addClass 'grid'
    @creaseGroup = @svg.group()
    .addClass 'crease'
    @updateGrid()
    @lineDrawMode()

  updateGrid: ->
    @gridGroup.clear()
    for x in [0..@page.xMax]
      @gridGroup.line x, @page.yMin, x, @page.yMax
    for y in [0..@page.yMax]
      @gridGroup.line @page.xMin, y, @page.xMax, y
    @svg.viewbox @page.xMin - margin, @page.yMin - margin, @page.xMax - @page.xMin + 2*margin, @page.yMax - @page.yMin + 2*margin

  nearestFeature: (pt) ->
    x: Math.round pt.x
    y: Math.round pt.y

  nullMode: ->
    @svg.mousemove null

  lineDrawMode: ->
    @nullMode()
    which = 0
    points = {}
    circles = []
    crease = null
    @svg.mousemove move = (e) =>
      points[which] = @nearestFeature @svg.point e.clientX, e.clientY
      unless which < circles.length
        circles.push(
          @svg.circle 0.3
          .addClass 'drag'
        )
      circles[which].center points[which].x, points[which].y
      if which == 1
        crease ?= @creaseGroup.line().addClass 'drag'
        crease.plot points[0].x, points[0].y, points[1].x, points[1].y
    @svg.mousedown (e) =>
      move e
      which++
    @svg.mouseup (e) =>
      move e
      # add crease
      crease.removeClass 'drag'
      crease = null
      circles.pop().remove() while circles.length
      which = 0
      move e

editor = null
window?.onload = ->
  svg = SVG 'interface'
  editor = new Editor svg
