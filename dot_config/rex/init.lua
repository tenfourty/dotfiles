-- Paste a clipboard image into a pane as a file path, copying it to that pane's machine first.
-- Vendored in dotfiles at commit 1d883ef with one local change; read before upgrading.
require("rex-image-paste").setup()
rex.bind("cmd+shift+v", "image_paste")
