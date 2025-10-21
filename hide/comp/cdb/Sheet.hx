package hide.comp.cdb;
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

class SheetHeader extends NativeComponent {
	static final MIN_SIZE = 10;

	var headerCells = new Array<HTMLElement>();
	var resizeHint: HTMLElement;
	var isVertical: Bool;
	var cellSize: Int;
	var cellCount: Int;

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
		this.cellCount = count;
		element.classList.add(isVertical ? "vgroup" : "hgroup");
		for (i in 0...count) {
			var elt = el('
					<div class="cell-header ${isVertical ? "row-header" : "col-header"} center" data-index="$i">
						<span>${isVertical ? Std.string(i) : getColName(i)}</span>
					</div>', element);
			elt.style.height = '${size.y}px';
			elt.style.width = '${size.x}px';

			var sep = el('<div class="${isVertical ? "vresize-handle" : "hresize-handle"}" draggable="true"></div>', element);
			//rowHeadersSeparators.push(sep);
			if (!isVertical || (isVertical && i > 0)) {
				sep.addEventListener("drag", onDragInternal);
			}

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
		onResize(getTotalSize());
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
		refresh();
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

	function getTotalSize(): Int {
		var modifiedCount = 0;
		var sum = 0;
		for (k => v in cellSizes.keyValueIterator()) {
			sum += v;
			modifiedCount += 1;
		}


		if (isVertical) {
			return cellSize * (cellCount - 1 - modifiedCount) + sum;
		} else {
			return cellSize * (cellCount - modifiedCount) + sum;
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

	public var cellCount = {
		cols: 20,
		rows: 50
	};

	// State
	var cellData: Map2D<Int,CellData>;

	// UI
	var root: HTMLElement;
	var canvas : js.html.CanvasElement;

	var colHeadersGroup : SheetHeader;
	var rowHeadersGroup : SheetHeader;

	public function new(parent) {
		var elt = new Element('<div class="sheet"></div>');
		super(parent, elt);
		root = elt.get(0); // "Cast" from jquery object to HTMLElement
		build();
		refresh();
	}

	public function build() {
		// Row Headers
		var size: Vector2i = {
			x: CELL_SIZE.wsmall,
			y: CELL_SIZE.h
		}
		rowHeadersGroup = new SheetHeader(size, cellCount.rows, true, root);
		rowHeadersGroup.element.classList.add("grid-a");
		rowHeadersGroup.onResize = function(newSize) {
			canvas.height = newSize;
			refresh();
		}
		//rowHeadersGroup.onDrag = onDragAnywhere;

		// Col headers
		size.x = CELL_SIZE.w;
		colHeadersGroup = new SheetHeader(size, cellCount.cols, false, root);
		colHeadersGroup .element.classList.add("grid-b");
		colHeadersGroup.onResize = function(newSize) {
			canvas.width = newSize;
			refresh();
		}
		//colHeadersGroup.onDrag = onDragAnywhere;

		// Grid canvas
		canvas = Browser.document.createCanvasElement();
		canvas.classList.add("grid-c");
		root.append(canvas);
		rowHeadersGroup.refresh();
		colHeadersGroup.refresh();
	}

	/**
	 * Applies the state to the visual UI in a retained manner. Should be called everytime any state-related property is modified.
	 */
	public function refresh() {
		if (canvas == null) {
			return;
		}

		var ctx = canvas.getContext("2d");
		if (ctx == null) {
			return;
		}
	}

	// Helpers

	function getCellSize(x: Int, y: Int) {
		
	}

	// Components
}
