package hide.comp.cdb;
import hide.Element;
import hide.Element.el;
import js.Browser;
import js.Browser.document;

typedef Map2D<T, U> = Map<T,Map<T,U>>;

typedef Vector2i = {
	var x: Int;
	var y: Int;
}

typedef CellData = {
	var width: Int;
	var height: Int;
}

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
	var rowSizes: Map<Int, Int>;
	var colSizes: Map<Int, Int>;

	// UI
	var root: HTMLElement;
	var canvas : js.html.CanvasElement;

	var cellResizeHintH: HTMLElement;
	var cellResizeHintV: HTMLElement;

	var colHeadersGroup : HTMLElement;
	var colHeaders = new Array();
	var colHeadersSeparators = new Array();

	var rowHeadersGroup : HTMLElement;
	var rowHeaders = new Array();
	var rowHeadersSeparators = new Array();

	// Misc
	var once = true;

	public function new(parent) {
		var elt = new Element('<div class="sheet"></div>');
		super(parent, elt);
		root = elt.get(0); // "Cast" from jquery object to HTMLElement
		build();
		refresh();
		once = false;
	}

	public function build() {
		// General setup
		document.body.addEventListener("drop", onDropAnywhere);

		// Row Headers
		rowHeadersGroup = el('<div class="vgroup grid-a sticky"></div>', root);
		for (i in 0...cellCount.rows) {
			var elt = el('
					<div class="cell-header row-header center" data-index="$i">
						<span>$i</span>
					</div>', rowHeadersGroup);
			elt.style.height = '${CELL_SIZE.h}px';
			elt.style.width = '${CELL_SIZE.wsmall}px';

			var sep = el('<div class="vresize-handle" draggable="true" data-drag-event="vresize" data-index="$i"></div>', rowHeadersGroup);
			rowHeadersSeparators.push(sep);
			sep.addEventListener("drag", onDragAnywhere);

			if (i > 0) {
				rowHeaders.push(elt);
			}
		}

		// Col headers
		colHeadersGroup = el('<div class="hgroup grid-b"></div>', root);
		for (i in 0...cellCount.cols) {
			var elt = el('
					<div class="cell-header col-header center" data-index="$i">
						<span>${getColName(i)}</span>
					</div>', colHeadersGroup);
			elt.style.height = '${CELL_SIZE.h}px';
			elt.style.width = '${CELL_SIZE.w}px';

			var sep = el('<div class="hresize-handle" draggable="true" data-drag-event="hresize" data-index="$i"></div>', colHeadersGroup);
			sep.addEventListener("drag", onDragAnywhere);

			colHeadersSeparators.push(sep);

			colHeaders.push(elt);
		}

		// Grid canvas
		canvas = Browser.document.createCanvasElement();
		canvas.classList.add("grid-c");
		//canvas.width = 200;
		//canvas.style.backgroundColor = COLORS.fg;
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

		if (once) {
			canvas.height = CELL_SIZE.h * (cellCount.rows - 1);
			canvas.width = CELL_SIZE.w * cellCount.cols + Math.floor(CELL_SIZE.wsmall / 2);
		}

		var ctx = canvas.getContext("2d");
		if (ctx == null) {
			return;
		}
	}

	function onDragAnywhere(e) {
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
						rowSizes.set(index, Math.floor(newHeight));
				case "hresize":
						var newWidth = e.clientX - draggedElt.previousElementSibling.getBoundingClientRect().x;
						newWidth = newWidth < 10 ? 10 : newWidth; //TODO Magic number
						draggedElt.previousElementSibling.style.width = '${newWidth}px';
						colSizes.set(index, Math.floor(newWidth));
				default: trace('No dragEvent defined on ${e.target}');
			}

			draggedElt = null;
			refresh();
	}

	// Helpers
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


	// Components
}
