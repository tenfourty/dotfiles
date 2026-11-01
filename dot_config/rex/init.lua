-- Paste a clipboard image into a pane as a file path, copying it to that pane's machine first.
-- Vendored in dotfiles at commit 1d883ef with one local change; read before upgrading.
-- Not upstream's Cmd+Shift+V, which Raycast's clipboard history takes on this Mac.
require("rex-image-paste").setup()
rex.bind("ctrl+cmd+v", "image_paste")
