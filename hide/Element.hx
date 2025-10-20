package hide;

typedef Element = #if hl hltml.JQuery #else js.jquery.JQuery #end;
typedef Event = #if hl hltml.Event #else js.jquery.Event #end;
typedef HTMLElement = #if hl hltml.Element #else js.html.Element #end;

#if js
function el(html: String, ?parent: HTMLElement) {
	// This is the only way natively to create an element from an html string
	var element = js.Browser.document.createElement("div");
	element.innerHTML = html;
	var res = element.firstElementChild;

	if (parent != null) {
		parent.append(res);
	}
	return res;
}
#else
function el(html: String, ?parent: HTMLElement) {
	throw new Exception("hltml is not supported");
}
#end;

function getVal( e : Element ) {
	return #if js e.val() #else e.getValue() #end;
}
