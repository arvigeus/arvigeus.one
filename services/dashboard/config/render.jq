# Renders sorted dashboard entries as static HTML fragments.
# Input: JSON stream of entries {name, subtitle, category, logo, url, order, category_rank}
def esc(f): f | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;") | gsub("\""; "&quot;");

def card:
	"<a class=\"card\" href=\"\(esc(if .url == "" then "#" else .url end))\""
	+ (if .url == "" then "" else " target=\"_blank\" rel=\"noopener\"" end)
	+ ">"
	+ (if .logo == ""
		then "<span class=\"fallback\">\(esc(.name[0:1] | ascii_upcase))</span>"
		else "<img class=\"icon\" src=\"\(esc(.logo))\" alt=\"\" loading=\"lazy\">"
		end)
	+ "<div><div class=\"name\">\(esc(.name))</div>"
	+ (if .subtitle == "" then "" else "<div class=\"subtitle\">\(esc(.subtitle))</div>" end)
	+ "</div></a>";

group_by(.category_rank)
| .[]
| .[0].category as $category
| sort_by([.order, .name]) as $items
| "<h2>\(esc($category))</h2>\n<div class=\"grid\">\n"
+ ([$items[] | card] | join("\n"))
+ "\n</div>"
