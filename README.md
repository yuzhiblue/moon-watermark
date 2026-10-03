# moon-watermark

> Image watermark library for MoonBit: **visible** + **invisible traceable** watermarks with `embed` / `extract` / `verify` APIs and a CLI.

面向版权保护、盗播溯源与内容防伪的 MoonBit 图像水印算法库。

## Features

- **Visible watermark**: semi-transparent text (timestamp / platform / viewer ID), reproducible random-dot overlay, logo alpha-blend, tiled anti-crop mode.
- **Invisible watermark**: PRNG-dot / LSB / DCT-domain embedding with key-based extraction and hash-based tracing.
- **Robustness**: verified against scaling, cropping, JPEG compression and brightness changes.
- **CLI**: `embed` / `extract` / `verify` commands with JSON config.

## Install

```bash
moon add yuzhiblue/moon-watermark
```

## Quick Start

```moonbit
// coming soon: embed / extract / verify examples
```

## Usage Scenarios

- Live-stream anti-piracy: dynamic random-dot watermark + viewer-ID invisible watermark.
- Image copyright protection: visible branding + invisible tracing payload.
- Content authenticity: hash-based trace of redistributed images.

## License

Apache-2.0
