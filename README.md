# Crease Pattern Editor

This is a draft of a web software tool for drawing quick crease/slit patterns.

## Features So Far
* **Graph-based**: Always maintain a planar graph, automatically subdividing
  and merging together touching vertices
* **Draw a crease** with two clicks or with dragging
* **Recolor** existing creases as different types by dragging over them
  (easily recoloring just part of a line)
* **Move vertices** by dragging them (bringing all connected edges with them)
* **Undo/redo**
* **Escape key** cancels current operation
* **Snapping** to grid or existing vertex (e.g. from intersection)
* **Save/export** to .fold/svg, including cutting (unwelding) of slits

## Installation
* Type `npm install` to do the necessary preparation
* Open `cpedit.html` in a web browser such as Chrome