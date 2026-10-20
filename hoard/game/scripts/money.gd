class_name Money
## Formatting only. The game never does money math; the backend does.


static func fmt(cents: int) -> String:
	var sign := "-" if cents < 0 else ""
	var c := absi(cents)
	var dollars := str(c / 100)
	var grouped := ""
	while dollars.length() > 3:
		grouped = "," + dollars.substr(dollars.length() - 3) + grouped
		dollars = dollars.substr(0, dollars.length() - 3)
	return "%s$%s%s.%02d" % [sign, dollars, grouped, c % 100]
