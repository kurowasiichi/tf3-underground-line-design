-- Registers the line manager hooks of the underground view (see replacement.script.tl).
function data()
	return {
		type = "react-replacement-config",
		data = {
			filePath = "underground_line_design::/gui/underground_line_design/replacement.script",
			doReplaceFn = "doReplaceFn",
		},
	}
end
