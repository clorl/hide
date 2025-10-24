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
		size.x = value.x - pos.x;
		size.y = value.y - pos.y;
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

	/**
	 * Returns a copy of itself where size is positive
	 */
	public function abs(): Rect2i {
		// Calculate new position components
		var newX = Math.min(this.pos.x, this.pos.x + this.size.x);
		var newY = Math.min(this.pos.y, this.pos.y + this.size.y);

		// Calculate new size components (always positive)
		var newSizeX = Math.abs(this.size.x);
		var newSizeY = Math.abs(this.size.y);

		// Return a new Rect2i instance
		return new Rect2i(
				Math.floor(newX), 
				Math.floor(newY), 
				Math.floor(newSizeX), 
				Math.floor(newSizeY));
	}

	public static function fromVec2i(vec: Vector2i): Rect2i {
		return new Rect2i(vec.x, vec.y, 0, 0);
	}

	public static function fromStartEnd(start: Vector2i, end: Vector2i) {
		var r = new Rect2i(start.x, start.y, 0, 0);
		r.end = end;
		return r;
	}
}

enum SheetCommand {
	Undo;
	Redo;
	SetSelection(sel: Array<Rect2i>);
	AddToSelection(sel: Array<Rect2i>);
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
	public var onMouseEvent = function(eName: String, e, isVertical: Bool, index: Int) {}

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
			elt.addEventListener("mousedown", function(e) { onMouseEventInternal("mousedown", e); });
			elt.addEventListener("mouseup", function(e) { onMouseEventInternal("mouseup", e); });
			elt.addEventListener("mousemove", function(e) { onMouseEventInternal("mousemove", e); });

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

	function onMouseEventInternal(name: String, e) {
		try {
			var mouseEvent = cast(e, js.html.MouseEvent);

			var indexStr = e.target.dataset.index;
			var index = Std.parseInt(indexStr);
			if (index == null) { return; }

			onMouseEvent(name, mouseEvent, isVertical, index);
		} catch (err) {};
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

/**
 * Manages logic and display of sheet's cell selection
 */
class SheetSelection extends NativeComponent {
	final POOL_SIZE = 10;

	public var data(default,null): Array<Rect2i>;
	var activeCell: Null<Vector2i>;
	var getCellBounds = function(cell: Vector2i): Rect2i { return new Rect2i(0, 0, 0, 0); }

	public var length(get, null): Int;
	function get_length() {
		return data.length;
	}

	var handle: HTMLElement;

	public var offset: Vector2i;
	var selectionRegions = new Array<HTMLElement>();

	/**
	 * @param callback A callback function that takes cell coordinates and returns a Rect2i representing the screen coordinates
	 */
	public function new(callback, ?parent) {
		super(parent, null);
		// Init state
		data = new Array<Rect2i>();
		getCellBounds = callback;

		// Init UI
		element.classList.add("active-cell");
		element.classList.add("hidden");

		handle = el('<div class="handle"></div>', element);

		for (i in 0...POOL_SIZE) {
			var e = el('<div class="hidden selection-region"></div>', parent);
			selectionRegions.push(e);
		}
	}

	public function replace(newSel: Array<Rect2i>) {
		data = newSel;
		refresh();
	}

	public function add(val: Rect2i) {
		data.push(val);
		showRegion(getSelectionBounds(val));
	}

	/**
	 * @param withActive: Boolean Should the active cell be reset as well
	 */
	public function clear(withActive = false) {
		data = new Array<Rect2i>();
		clearRegions();
		if (withActive) {
			activeCell = null;
			element.classList.add("hidden");
		}
	}

	/**
	 * Sets the last element of the selection array to be a region going from the active cell to the provided cell
	 */
	public function setRegionEnd(cell: Vector2i) {
		if (activeCell == null) { return; }
		if (data.length <= 0) { return; }
		data[data.length - 1] = Rect2i.fromStartEnd(activeCell, cell);
		trace(data[data.length - 1]);
		refresh();
	}

	public function setActiveCell(cell: Null<Vector2i>) {
		activeCell = cell;
		if (activeCell == null) {
			element.classList.add("hidden");
			return;
		}
		var rect = getCellBounds(activeCell);
		element.classList.remove("hidden");
		element.style.top = '${rect.pos.y + offset.y}px';
		element.style.left = '${rect.pos.x + offset.x}px';
		element.style.width = '${rect.size.x}px';
		element.style.height = '${rect.size.y}px';
		//element.append(handle);
	}

	function refresh() {
		clearRegions();
		if (data.length == 1) {
			if (data[0].size.x == 0 && data[0].size.y == 0) {
				return;
			}
		}
		for (elt in data) {
			showRegion(getSelectionBounds(elt));
		}
	}

	function getSelectionBounds(rect: Rect2i): Rect2i {
		if (rect.size.x == 0 && rect.size.y == 0) {
			return getCellBounds(rect.pos);
		}

		if (rect.size.x < 0 || rect.size.y < 0) {
			rect = rect.abs();
		}
		var start = getCellBounds(rect.pos);
		var end = getCellBounds(rect.end);
		return Rect2i.fromStartEnd(start.pos, end.end);
	}

	function showRegion(rect: Rect2i) {
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
				}
			} else {
				var elt = el('<div class="selection-region"></div>', parent);
				selectionRegions.push(elt);
				elt.style.top = '${rect.pos.y + offset.y}px';
				elt.style.left = '${rect.pos.x + offset.x}px';
				elt.style.width = '${rect.size.x}px';
				elt.style.height = '${rect.size.y}px';
				done = true;
			}
			++i; 
		}
	}

	function clearRegions() {
		for (r in selectionRegions) {
			r.classList.add("hidden");
		}
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
	var selection: SheetSelection;

	// State
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
		rows.onMouseEvent = onHeaderEvent;
		//rows.onDrag = onDragAnywhere;

		// Col headers
		size.x = CELL_SIZE.w;
		cols = new SheetHeader(size, count.cols, false, root);
		cols .element.classList.add("grid-b");
		cols.onResize = function(newSize) {
			refresh();
		}
		cols.onMouseEvent = onHeaderEvent;
		
		// Selection indicator
		selection = new SheetSelection(getCellBounds, root);
		selection.offset = {
			x: CELL_SIZE.wsmall - 1,
			y: CELL_SIZE.h - 1
		};

		// Grid canvas
		canvas = Browser.document.createCanvasElement();
		canvas.classList.add("grid-c");
		root.append(canvas);

		// Register event listeners here
		listen(canvas, "mousedown");
		listen(canvas, "mousemove");
		listen(document.body, "mouseup");
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
	var pendingSelection = false;
	function onEvent(name: String, e) {
		switch (name) {
			case "mousedown":
				if (e.target == canvas) {
					var mouseEvent = cast(e, js.html.MouseEvent);
					var pos = getRelativeMousePos(canvas, e);
					var cell = getCellAtPos(pos.x, pos.y);

					if (mouseEvent.button == 0) {
						if (!mouseEvent.ctrlKey) {
							selection.clear();
						}
						pendingSelection = true;
						selection.setActiveCell(cell);
						selection.add(Rect2i.fromVec2i(cell));
					}
				}
			case "mouseup":
				var mouseEvent = cast(e, js.html.MouseEvent);

				if (mouseEvent.button == 0 && pendingSelection) {
					pendingSelection = false;
					//if (mouseEvent.ctrlKey) {
					//} else {
					//	// Replace selection
					//	var last = selection.data[selection.data.length - 1];
					//	selection.replace([last]);
					//}
				}

			case "mousemove":
				var mouseEvent = cast(e, js.html.MouseEvent);
				if (pendingSelection) {
					var pos = getRelativeMousePos(canvas, e);
					var cell = getCellAtPos(pos.x, pos.y);
					selection.setRegionEnd(cell);
				}

			case "keydown":
					var keyEvent = cast(e, js.html.KeyboardEvent);
					switch keyEvent.key {
						case "Z":
							if (keyEvent.ctrlKey && keyEvent.shiftKey) {
								runCommand(Redo);
							} else if (keyEvent.ctrlKey) {
								runCommand(Undo);
							}
					}
		}


		//trace("Event", name, e);
	}

	function onHeaderEvent(name: String, e: js.html.MouseEvent, isVertical: Bool, index: Int) {
		switch (name) {
			case "mousedown":
				if (e.button == 0) {
					if (!e.ctrlKey) {
						selection.clear();
					}
					selection.setActiveCell(null);
					if (isVertical) {
						selection.add(new Rect2i(0, index, cols.count-1, 0));
					} else {
						selection.add(new Rect2i(index, 0, 0, rows.count -1));
					}
				}
		}
	}


	function runCommand(cmd: SheetCommand, redo = false) {
		var shouldRefresh = false;
		var undoable = true;
		trace("Command", cmd);

		switch (cmd) {
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
	function getCellAtPos(x: Int, y: Int): Vector2i {
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
	function getCellBounds(cell: Vector2i): Rect2i {
		var curCol = -1;
		var x = 0;
		var w = 0;
		while(x < canvas.width && curCol < cols.count) {
			curCol += 1;
			if (curCol == cell.x) {
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
			if (curRow == cell.y) {
				h = getRowSize(curRow);
				break;
			}
			y += getRowSize(curRow);
		}

		return new Rect2i(x, y, w, h);
	}
}
