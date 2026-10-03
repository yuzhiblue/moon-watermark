// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "yuzhiblue/moon-watermark"

version = "0.1.2"

readme = "README.md"

repository = "https://github.com/yuzhiblue/moon-watermark.git"

license = "Apache-2.0"

keywords = [ "watermark", "image", "security", "anti-piracy", "steganography" ]

preferred_target = "wasm"

description = "Image watermark library for MoonBit: visible and invisible traceable watermarks with embed/extract/verify APIs and a CLI."

import {
  "mizchi/image@0.4.3",
  "mizchi/json@0.4.0",
}
