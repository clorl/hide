package hide.comp;
import hide.Element;
import js.Browser.document;
import hide.Element.el;

class NativeComponent {
	public var element(default,null) : HTMLElement;
	public var parent(default,null) : HTMLElement;

	function new(parent:HTMLElement,elt:HTMLElement) {
		if( elt == null )
			elt = el('<div></div>');
		this.element = elt;
		if( parent != null ) {
			parent.append(element);
			this.parent = parent;
		}
	}

	public function remove() {
		element.remove();
	}
}
