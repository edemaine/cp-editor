# Crease Pattern Editor

This is a draft of a web software tool for drawing quick crease/slit patterns.
Currently it works well for crease patterns that fit on an integer grid.

## Features So Far

* **Graph-based**: Always maintain a planar graph, automatically subdividing
  and merging together touching vertices
* **Draw a crease** with two clicks or with dragging
* **Recolor** existing creases as different types by dragging over them
  (easily recoloring just part of a line)
* **Fold angle** support: enter degrees (or formula for degrees)
  to adjust mountain/valley fold amount (drawn via opacity)
* **Erase** existing creases by dragging over them
* **Move vertices** by dragging them (bringing all connected edges with them)
* **Snapping** to grid or existing vertex (e.g. from intersection)
* **Cleanup** to remove extra degree-0 or -2 vertices
* **Undo/redo**
* **Save/export** to .fold/.svg, including cutting (unwelding) of slits
* **CLI** for bulk conversion: `node cpedit.js --cleanup --fold --svg filename.cp`
* **Title** setting for document (`file_title` in fold format)
* **Page size** setting (width and height)
* **Transform** document by reflection or 90&deg; rotation
* **Keyboard shortcuts**:
  * Escape key cancels current operation
  * `z` for undo, `Z` or `y` for redo
  * Modes and line types list their key shortcut

## Installation
* Type `npm install` to do the necessary preparation
* Type `git submodule update --init --recursive` to use Origami Simulator integration
* Open `cpedit.html` in a web browser such as Chrome
