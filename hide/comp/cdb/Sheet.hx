package hide.comp.cdb;
import hide.datatypes.History;
import hide.Element;
import hide.Element.el;
import js.Browser;
import js.Browser.document;

typedef Map2D<T, U> = Map<T,Map<T,U>>;

typedef Vector2<T> = {
	var x: T;
	var y: T;
}
typedef Vector2i = Vector2<Int>;
typedef Vector2f = Vector2<Float>;

typedef CellData = {
	var width: Int;
	var height: Int;
}

class Rect2i {
	public var pos: Vector2<Int>;
	public var size: Vector2<Int>;
	public var end(get,set): Vector2<Int>;
	function get_end() {
		return {
			x: pos.x + size.x,
			y: pos.y + size.y
		};
	}
	function set_end(value: Vector2<Int>) {
		var oldPos = pos;
		var endTmp = value;

		pos.x = Math.floor(Math.min(oldPos.x, value.x));
		pos.y = Math.floor(Math.min(oldPos.y, value.y));
		endTmp.x = Math.floor(Math.max(oldPos.x, value.x));
		endTmp.y = Math.floor(Math.max(oldPos.y, value.y));

		size.x = Math.floor(endTmp.x - pos.x);
		size.y = Math.floor(endTmp.y - pos.y);
		return this.end;
	}

	public function new(x: Int, y: Int, sizeX: Int, sizeY: Int) {
		this.pos = {x: x, y: y};
		this.size = {x: sizeX, y: sizeY };
	}

	/**
	 * @param point: Vector2i
	 * @param strict: Boolean Strict means a point on an edge of the rect will not be considered inside
	 */
	public function contains(point: Vector2i, strict = false): Bool {
		var dx = point.x - pos.x;
		var dy = point.y - pos.y;

		var isInsideX = strict ? 0 < dx && dx < size.x : 0 <= dx && dx <= size.x;
		var isInsideY = strict ? 0 < dy && dy < size.y : 0 <= dy && dy <= size.y;
		return isInsideX && isInsideY;
	}
}

enum SheetCommand {
	Undo;
	Redo;
	SetSelection(sel: Array<Rect2i>);
	AddToSelection(sel: Array<Rect2i>);
	SelectRegion(start: Rect2i);
	RemoveFromSelection(sel: Array<Rect2i>);
}

class SheetHeader extends NativeComponent {
	static final MIN_SIZE = 10;

	var headerCells = new Array<HTMLElement>();
	var resizeHint: HTMLElement;
	var isVertical: Bool;
	var cellSize: Int;
	public var count: Int;

	// State
	var resizedElement: HTMLElement;
	var cellSizes = new Map<Int, Int>();

	// Callbacks
	public var onDrag = function(e) {}
	public var onResize = function(newSize) {}

	public function new(size: Vector2i, count: Int, isVertical: Bool, ?parent, ?elt) {
		super(parent, null);
		this.isVertical = isVertical;
		this.cellSize = isVertical ? size.y : size.x;
		this.count = count;
		element.classList.add(isVertical ? "vgroup" : "hgroup");
		for (i in 0...count) {
			var elt = el('
					<div class="cell-header ${isVertical ? "row-header" : "col-header"} center" data-index="$i">
						<span>${isVertical ? Std.string(i + 1) : getColName(i)}</span>
					</div>', element);
			elt.style.height = '${size.y}px';
			elt.style.width = '${size.x}px';

			var sep = el('<div class="${isVertical ? "vresize-handle" : "hresize-handle"}" draggable="true"></div>', element);
			sep.addEventListener("drag", onDragInternal);

			headerCells.push(elt);
		}

		resizeHint = el('<div class="${isVertical ? "vresize-hint" : "hresize-hint"} hidden"></div>', parent);
		resizeHint.style.top = "0";
		resizeHint.style.left = "0";

		if (document != null) {
			document.body.addEventListener("drop", onDrop);
		}
	}

	public function refresh() {
	}

	function onDragInternal(e) {
		onDrag(e);

		var bounds = parent.getBoundingClientRect();
		if (isVertical) {
			var top = e.clientY - bounds.top;
			resizeHint.style.top = '${top}px';
		} else {
			var left = e.clientX - bounds.left;
			resizeHint.style.left = '${left}px';
		}
		if (resizeHint.classList.contains("hidden")) {
			resizeHint.classList.remove("hidden");
		}
		resizedElement = e.target.previousElementSibling;
	}

	function onDrop(e) {
		if (resizedElement == null) {
			return;
		}

		var newSize: Int = -1;

		if (isVertical) {
			newSize = Math.floor(e.clientY - resizedElement.getBoundingClientRect().y);
			newSize = newSize < MIN_SIZE ? MIN_SIZE : newSize;
			resizedElement.style.height = '${newSize}px';
		} else {
			newSize = Math.floor(e.clientX - resizedElement.getBoundingClientRect().x);
			newSize = newSize < MIN_SIZE ? MIN_SIZE : newSize;
			resizedElement.style.width = '${newSize}px';
		}

		// Store in internal state
		var indexStr = resizedElement.dataset.index;
		var index = Std.parseInt(indexStr);
		if (index != null && newSize >= 0) {
			cellSizes.set(index, newSize);
		}

		if (!resizeHint.classList.contains("hidden")) {
			resizeHint.classList.add("hidden");
		}
		resizedElement = null;
		onResize(getTotalSize());
	}


	function getColName(index: Int): String {
		var tempIndex = index; 
		var columnName = "";

		while (tempIndex >= 0) {
			var remainder = tempIndex % 26;
			var charCode = 65 + remainder;
			var character = String.fromCharCode(charCode);
			columnName = character + columnName;
			tempIndex = Std.int((tempIndex - remainder) / 26) - 1;
		}

		return columnName;
	}

	public function getTotalSize(): Int {
		var modifiedCount = 0;
		var sum = 0;
		for (k => v in cellSizes.keyValueIterator()) {
			sum += v;
			modifiedCount += 1;
		}

		return cellSize * (count -  modifiedCount) + sum;
	}

	public function getSize(index: Int): Int {
		var found = cellSizes[index];
		if (found == null) {
			return cellSize;
		} else {
			return found;
		}
	}
}

class SelectionIndicator extends NativeComponent {
	final POOL_SIZE = 10;

	var handle: HTMLElement;

	public var onHandleDrag = function(e) {}
	public var offset: Vector2i;
	var selectionRegions = new Array<HTMLElement>();

	public function new(?parent, ?elt) {
		super(parent, null);
		element.classList.add("active-cell");
		element.classList.add("hidden");

		handle = el('<div class="handle"></div>', element);
		handle.addEventListener("drag", onDragInternal);

		for (i in 0...POOL_SIZE) {
			var e = el('<div class="hidden selection-region"></div>', parent);
			selectionRegions.push(e);
		}
	}

	public function setSelection(sel: Array<Rect2i>) {
		clearRegions();

		if (sel.length == 1) {
			setActiveCell(sel[0]);
			return;
		}

		for (i in 0...sel.length) {
			showRegion(sel[i], i == sel.length - 1);
		}
	}

	public function setActiveCell(rect: Rect2i) {
		element.classList.remove("hidden");
		element.style.top = '${rect.pos.y + offset.y}px';
		element.style.left = '${rect.pos.x + offset.x}px';
		element.style.width = '${rect.size.x}px';
		element.style.height = '${rect.size.y}px';
		element.append(handle);
	}

	public function showRegion(rect: Rect2i, withHandle = false) {
		var done = false;
		var i = 0;
		while (!done) {
			if (i < selectionRegions.length) {
				var elt = selectionRegions[i];
				if (elt.classList.contains("hidden")) {
					elt.style.top = '${rect.pos.y + offset.y}px';
					elt.style.left = '${rect.pos.x + offset.x}px';
					elt.style.width = '${rect.size.x}px';
					elt.style.height = '${rect.size.y}px';
					elt.classList.remove("hidden");
					done = true;
					if (withHandle)
						elt.append(handle);
				}
			} else {
				var elt = el('<div class="selection-region"></div>', parent);
				selectionRegions.push(elt);
				elt.style.top = '${rect.pos.y + offset.y}px';
				elt.style.left = '${rect.pos.x + offset.x}px';
				elt.style.width = '${rect.size.x}px';
				elt.style.height = '${rect.size.y}px';
				done = true;
				if (withHandle)
					elt.append(handle);
			}
			++i; 
		}
	}

	public function clearRegions() {
		for (r in selectionRegions) {
			r.classList.add("hidden");
		}
	}

	public function setMultiSelection(multi: Bool) {
		if (multi) {
			element.classList.add("with-bg");
		} else {
			element.classList.remove("with-bg");
		}
	}

	function onDragInternal(e) {
		onHandleDrag(e);
	}
}


// Sheet is a Component, not a NativeComponent so it can hook to the rest of the code, but every component inside of it should be a NativeComponent
class Sheet extends Component {

	final CELL_SIZE = {
		w: 100,
		wsmall: 40,
		h: 20,
		min: 10
	};

	final BORDER_SIZE = 1;
	final RESIZE_MARGIN = 6;

	public var count = {
		cols: 20,
		rows: 50
	};

	// UI
	var root: HTMLElement;
	var canvas : js.html.CanvasElement;

	var cols : SheetHeader;
	var rows : SheetHeader;
	var selIndicator: SelectionIndicator;

	// State
	var selection = new Array<Rect2i>();
	var cmdHistory = new History<SheetCommand>(100);

	public function new(parent) {
		var elt = new Element('<div class="sheet"></div>');
		super(parent, elt);
		root = elt.get(0); // "Cast" from jquery object to HTMLElement
		build();
		refresh();
	}

	public function build() {
		// Origin
		var origin = el('<div class="cell-header row-header grid-d"></div>', root);
		origin.style.width = '${CELL_SIZE.wsmall}px';
		origin.style.height = '${CELL_SIZE.h}px';
		
		// Row Headers
		var size: Vector2i = {
			x: CELL_SIZE.wsmall,
			y: CELL_SIZE.h
		}
		rows = new SheetHeader(size, count.rows, true, root);
		rows.element.classList.add("grid-a");
		rows.onResize = function(newSize) {
			refresh();
		}
		//rows.onDrag = onDragAnywhere;

		// Col headers
		size.x = CELL_SIZE.w;
		cols = new SheetHeader(size, count.cols, false, root);
		cols .element.classList.add("grid-b");
		cols.onResize = function(newSize) {
			refresh();
		}
		
		// Selection indicator
		selIndicator = new SelectionIndicator(root);
		selIndicator.offset = {
			x: CELL_SIZE.wsmall - 1,
			y: CELL_SIZE.h - 1
		};

		// Grid canvas
		canvas = Browser.document.createCanvasElement();
		canvas.classList.add("grid-c");
		root.append(canvas);

		// Register event listeners here
		listen(canvas, "mousedown");
		listen(canvas, "drag");
		listen(document.body, "drop");
		listen(document.body, "keydown");
		listen(document.body, "keypress");
		listen(document.body, "keyup");

		refresh();
	}

	/**
	 * Applies the state to the visual UI in a retained manner. Should be called everytime any state-related property is modified.
	 */
	public function refresh() {
		if (canvas == null) {
			return;
		}

		canvas.height = rows.getTotalSize();
		canvas.width = cols.getTotalSize();

		// Selection
		if (selection.length > 0) {
			var bounds = new Array<Rect2i>();
			for (elt in selection) {
				if (elt.size.x > 0 && elt.size.y > 0) {
					var start = getCellBounds(elt.pos.x, elt.pos.y).pos;
					var end = getCellBounds(elt.end.x, elt.end.y).end;
					var b = new Rect2i(0,0,0,0);
					b.pos = start;
					b.end = end;
					bounds.push(b);
				} else {
					bounds.push(getCellBounds(elt.pos.x, elt.pos.y));
				}
			}
			selIndicator.setSelection(bounds);
		} else {
			selIndicator.element.classList.add("hidden");
		}

		var ctx = canvas.getContext("2d");
		if (ctx == null) {
			return;
		}
		ctx.clearRect(0, 0, canvas.width, canvas.height);
		ctx.lineWidth = 1;
		ctx.strokeStyle = "#444444";
		var curX = 0;
		for (x in 0...cols.count) {
			curX += getColSize(x);
			ctx.beginPath();
			ctx.moveTo(curX, 0);
			ctx.lineTo(curX, canvas.height);
			ctx.closePath();
			ctx.stroke();
		}

		var curY = 0;
		for (y in 0...rows.count) {
			curY += getRowSize(y);
			ctx.beginPath();
			ctx.moveTo(0, curY);
			ctx.lineTo(canvas.width, curY);
			ctx.closePath();
			ctx.stroke();
		}
	}

	//https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model/Events
	//https://developer.mozilla.org/en-US/docs/Web/API/Event#interfaces_based_on_event
	//https://developer.mozilla.org/en-US/docs/Web/API/UI_Events
	function onEvent(name: String, e) {
		var handled = false;

		switch (name) {
			case "mousedown":
				if (!handled && e.target == canvas) {
					var mouseEvent = cast(e, js.html.MouseEvent);
					var pos = getRelativeMousePos(canvas, e);
					var cell = getCellAtScreenPos(pos.x, pos.y);

					if (mouseEvent.button == 0) {
						if (mouseEvent.ctrlKey) {
							runCommand(AddToSelection([new Rect2i(cell.x, cell.y, 0, 0)]));
						} else {
							runCommand(SetSelection([new Rect2i(cell.x, cell.y, 0, 0)]));
						}
						selIndicator.setActiveCell(getCellBounds(cell.x, cell.y));
					}

					handled = true;
				}
			case "mouseup":

			case "keydown":
				if (!handled) {
					var keyEvent = cast(e, js.html.KeyboardEvent);
					switch keyEvent.key {
						case "Z":
							if (keyEvent.ctrlKey && keyEvent.shiftKey) {
								runCommand(Redo);
								handled = true;
							} else if (keyEvent.ctrlKey) {
								runCommand(Undo);
								handled = true;
							}
					}
				}
		}


		if (!handled) 
			trace("Unhandled event", name, e);
	}


	function runCommand(cmd: SheetCommand, redo = false) {
		var shouldRefresh = false;
		var undoable = true;

		switch (cmd) {
			case SetSelection(newSel):
				if (newSel == selection) {
					return;
				}
				selection = newSel;
				shouldRefresh = true;
				undoable = false;
			case AddToSelection(sel):
				undoable = false;
				if (selection.length == 1 && sel.length == 1) {
					if (sel[0] == selection[0]) {
						return;
					}
				}
				selection = selection.concat(sel);
				shouldRefresh = true;
			case Undo: 
				var otherCmd = cmdHistory.pop();
				if (otherCmd != null) {
					undoCommand(otherCmd);
					shouldRefresh = true;
				}
				undoable = false;
			case Redo:
				var otherCmd = cmdHistory.unpop();
				runCommand(otherCmd, true);
				undoable = false;
			case _: trace("Unhandled command", cmd);
		}


		if (redo) {
			cmdHistory.unpop();
		} else if (undoable) {
			cmdHistory.push(cmd);
		}
		trace(cmdHistory);

		if (shouldRefresh)
			refresh();
	}

	// Undo command handling is split into another function
	function undoCommand(cmd: SheetCommand) {
		if (cmd == Undo || cmd == Redo) return;
		switch (cmd) {
			case SetSelection(newSel):
				trace("Undo SetSelection");
			default: {}
		}
	}

	function listen(elt: HTMLElement, ev: String) {
		elt.addEventListener(ev, function(e) { onEvent(ev, e); });
	}

	// 
	// Helpers
	//

	/**
	 * @return The mouse position relative to the given element, can be negative
	 */
	function getRelativeMousePos(elt: HTMLElement, e): Vector2i {
		var bounds = elt.getBoundingClientRect();
		var mouseX = Math.floor(e.clientX - bounds.left);
		var mouseY = Math.floor(e.clientY - bounds.top);
		return { x: mouseX, y: mouseY };
	}
	
	function getRowSize(index: Int): Int {
		return rows.getSize(index);
	}

	function getColSize(index: Int): Int {
		return cols.getSize(index);
	}

	function getCellSize(x: Int, y: Int): Vector2i {
		var width = cols.getSize(x);
		var height = rows.getSize(y);
		return {x: width, y: height};
	}

	/**
	 * @returns Coordinates of the cell in the sheet
	 */
	function getCellAtScreenPos(x: Int, y: Int): Vector2i {
		var col = -1;
		var curX = 0;
		while (curX < canvas.width && col < cols.count) {
			col += 1;
			if (x < curX) {
				col -= 1;
				break;
			}
			curX += getColSize(col);
		}

		var row = -1;
		var curY = 0;
		while (curY < canvas.height && row < rows.count) {
			row += 1;
			if (y < curY) {
				row -= 1;
				break;
			}
			curY += getRowSize(row);
		}

		return { x: col, y: row }
	}

	/**
	 * Return the screen bounds of the cell at grid index specified by col and row
	 */
	function getCellBounds(col: Int, row: Int): Rect2i {
		var curCol = -1;
		var x = 0;
		var w = 0;
		while(x < canvas.width && curCol < cols.count) {
			curCol += 1;
			if (curCol == col) {
				w = getColSize(curCol);
				break;
			}
			x += getColSize(curCol);
		}

		var curRow = -1;
		var y = 0;
		var h = 0;
		while(y < canvas.height && curRow < rows.count) {
			curRow += 1;
			if (curRow == row) {
				h = getRowSize(curRow);
				break;
			}
			y += getRowSize(curRow);
		}

		return new Rect2i(x, y, w, h);
	}
}
