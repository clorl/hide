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

	// State
	var resizedElement: HTMLElement;

	public function new(size: Vector2i, count: Int, isVertical: Bool, ?parent, ?elt) {
		super(parent, null);
		this.isVertical = isVertical;
		element.classList.add(isVertical ? "vgroup" : "hgroup");
		for (i in 0...count) {
			var elt = el('
					<div class="cell-header ${isVertical ? "row-header" : "col-header"} center" data-index="$i">
						<span>${isVertical ? Std.string(i) : getColName(i)}</span>
					</div>', element);
			elt.style.height = '${size.y}px';
			elt.style.width = '${size.x}px';

			var sep = el('<div class="${isVertical ? "vresize-handle" : "hresize-handle"}" draggable="true" 
					data-index="$i"></div>', element);
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

		if (isVertical) {
			var newHeight = e.clientY - resizedElement.getBoundingClientRect().y;
			newHeight = newHeight < MIN_SIZE ? MIN_SIZE : newHeight;
			resizedElement.style.height = '${newHeight}px';
		} else {
			var newWidth = e.clientX - resizedElement.getBoundingClientRect().x;
			newWidth = newWidth < MIN_SIZE ? MIN_SIZE : newWidth;
			resizedElement.style.width = '${newWidth}px';
		}
		if (!resizeHint.classList.contains("hidden")) {
			resizeHint.classList.add("hidden");
		}
		resizedElement = null;
		// TODO Store internal state
	}

	public var onDrag = function(e) {
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
}

// Sheet is a Component, not a NativeComponent so it can hook to the rest of the code, but every component inside of it should be
// NativeComponent
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
	var draggedElt: Null<HTMLElement>;
	var cellData: Map2D<Int,CellData>;
	// These fields will be stored and used upon reloading the app to avoid costly DOM queries
	var rowSizes = new Map<Int, Int>();
	var colSizes = new Map<Int, Int>();

	// UI
	var root: HTMLElement;
	var canvas : js.html.CanvasElement;

	var cellResizeHintH: HTMLElement;
	var cellResizeHintV: HTMLElement;

	var colHeadersGroup : SheetHeader;
	var rowHeadersGroup : SheetHeader;

	// Misc
	var curCanvasSize: Vector2<Int> = {
		x: 0,
		y: 0
	};

	public function new(parent) {
		var elt = new Element('<div class="sheet"></div>');
		super(parent, elt);
		root = elt.get(0); // "Cast" from jquery object to HTMLElement
		build();
		refresh();
	}

	public function build() {
		// General setup
		document.body.addEventListener("drop", onDropAnywhere);

		// Row Headers
		var size: Vector2i = {
			x: CELL_SIZE.wsmall,
			y: CELL_SIZE.h
		}
		rowHeadersGroup = new SheetHeader(size, cellCount.rows, true, root);
		rowHeadersGroup.element.classList.add("grid-a");
		//rowHeadersGroup.onDrag = onDragAnywhere;

		// Col headers
		size.x = CELL_SIZE.w;
		colHeadersGroup = new SheetHeader(size, cellCount.cols, false, root);
		colHeadersGroup .element.classList.add("grid-b");
		//colHeadersGroup.onDrag = onDragAnywhere;

		// Grid canvas
		canvas = Browser.document.createCanvasElement();
		canvas.classList.add("grid-c");
		root.append(canvas);
		
		cellResizeHintH = el('<div class="hresize-hint"></div>', root);
		cellResizeHintH.style.top = "0";
		cellResizeHintH.style.left = "0";
		cellResizeHintV = el('<div class="vresize-hint"></div>', root);
		cellResizeHintV.style.top = "0";
		cellResizeHintV.style.left = "0";

	}

	/**
	 * Applies the state to the visual UI in a retained manner. Should be called everytime any state-related property is modified.
	 */
	public function refresh() {
		// Update drag hint
		if (draggedElt == null) {
			cellResizeHintH.classList.add("hidden");
			cellResizeHintV.classList.add("hidden");
		} else {
			var dragEvent = draggedElt.dataset.dragEvent;
			if (dragEvent != null) {
				switch dragEvent {
					case "hresize":
						cellResizeHintH.classList.remove("hidden");
						cellResizeHintV.classList.add("hidden");
					case "vresize":
						cellResizeHintH.classList.add("hidden");
						cellResizeHintV.classList.remove("hidden");
					default:
				}
			}
		}

		if (canvas == null) {
			return;
		}

		var newSize = getCanvasSize();
		if (newSize.x != curCanvasSize.x && newSize.y != curCanvasSize.y) {
			curCanvasSize = newSize;
			canvas.height = newSize.y;
			canvas.width = newSize.x;
		}

		var ctx = canvas.getContext("2d");
		if (ctx == null) {
			return;
		}
	}

	function onDragAnywhere(e) {
		return;
		if (draggedElt == null) {
			draggedElt = e.target;
		}

		var dragEvent = draggedElt.dataset.dragEvent;
		if (dragEvent == null) {
			return;
		}

		// Element here should be the parent from which the resize hints are absolute positioned
		var bounds = root.getBoundingClientRect();

		switch dragEvent {
			case "vresize":
				var top = e.clientY - bounds.top;
				cellResizeHintV.style.top = '${top}px';
			case "hresize":
				var left = e.clientX - bounds.left;
				cellResizeHintH.style.left = '${left}px';
			default: trace('No dragEvent defined on ${e.target}');
		}
		refresh();
	}

	// Event handlers (they should all call refresh at some point)
	function onDropAnywhere(e) {
			if (draggedElt == null) {
				return;
			}

			var dragEvent = draggedElt.dataset.dragEvent;
			var indexStr = draggedElt.dataset.index;
			var index = Std.parseInt(indexStr);
			if (dragEvent == null || index == null) {
				return;
			}

			switch dragEvent {
				case "vresize":
						var newHeight = e.clientY - draggedElt.previousElementSibling.getBoundingClientRect().y;
						newHeight = newHeight < 10 ? 10 : newHeight; //TODO Magic number
						draggedElt.previousElementSibling.style.height = '${newHeight}px';
						//rowSizes.set(index, Math.floor(newHeight));
				case "hresize":
						var newWidth = e.clientX - draggedElt.previousElementSibling.getBoundingClientRect().x;
						newWidth = newWidth < 10 ? 10 : newWidth; //TODO Magic number
						draggedElt.previousElementSibling.style.width = '${newWidth}px';
						//colSizes.set(index, Math.floor(newWidth));
				default: trace('No dragEvent defined on ${e.target}');
			}

			draggedElt = null;
			refresh();
	}

	// Helpers
	
	function getCanvasSize(): Vector2i {
		var baseHeight = CELL_SIZE.h * (cellCount.rows - 1);
		var baseWidth = CELL_SIZE.w * cellCount.cols + Math.floor(CELL_SIZE.wsmall / 2);
		for (k in rowSizes.keys()) {
			baseHeight += rowSizes.get(k);
		}

		for (k in colSizes.keys()) {
			baseWidth += colSizes.get(k);
		}

		return {
			x: baseWidth,
			y: baseHeight
		}
	}

	function getCellSize(x: Int, y: Int) {
		
	}

	// Components
}
