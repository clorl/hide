package hide.datatypes;

/**
 * Data structure that represents an undo/redo history
 */
class History<T> {
	private var data: Array<T>;
	private var length(get, null): Int;
	function get_length() {
		return this.commit -1; 
	};
	private var capacity: Int;
	private var current: Int;
	private var commit: Int;

	public function new(capacity: Int) {
		this.capacity = capacity;
		this.data = new Array<T>();
		this.current = -1;
		this.commit = -1;
	}

	/**
	 * Pushes a new element, overwriting what is after the currentIndex and resetting commitIndex
	 */
	public function push(elt: T) {
		if (current < data.length - 1) {
			data.splice(current + 1, data.length - (current + 1)); // Removes one element
		}

		data.push(elt);

		current ++;
		commit = current;

		if (data.length > capacity) {
			data.shift();
			this.current --;
			this.commit --;
		}
	}

	/**
	 * Moves currentIndex back and returns the element. It can now be overwritten if anything is pushed.
	 * Equivalent to undo.
	 */
	public function pop(): Null<T> {
		if (current < 0) {
			return null;
		}
		current--;
		return data[current - 1];
	}

	/**
	 * Reverts the pop operation. Equivalent to redo.
	 */
	public function unpop(): Null<T> {
		if (current < commit) {
			current ++;
			return data[current];
		}
		return null;
	}

	/**
	 * Returns the internal array (use for debug only)
	 */
	public function getData(): Array<T> {
		return data;
	}

	/**
	 * Removes all data
	 */
	public function clear() {
		this.data = new Array<T>();
		this.commit = -1;
		this.current = -1;
	}

	public function toString(): String {
		var str = "";
		var i = 0;
		for (elt in data) {
			str += Std.string(elt);
			if (i == commit) {
				str += " << commit";
			}
			if (i == current) {
				str += " << current";
			}
			str += "\n";
			i++;
		}
		return str;
	}
}
