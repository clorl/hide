package hide.comp;
import hide.Element;
import js.Browser.document;

class NativeComponent {
	public static function el(html: String, ?parent: HTMLElement) {
		var elt = new HTMLElement();
		elt.outerHTML = html;
		if (parent != null) {
			parent.append(elt);
		}
		return elt;
	}

	public var element: HTMLElement;
	public var parent: HTMLElement;
	public function new(?parent: HTMLElement, ?el: HTMLElement) {
		if (el != null) {
			element = el;
		} else {
			element = document.createElement("div");
		}

		if (parent != null) {
			parent.append(element);
		}
	}
}
