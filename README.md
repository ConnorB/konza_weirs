# Konza Prairie Weirs

Fetches and saves weir monitoring images from the [Konza Prairie LTER](https://lter.konza.ksu.edu/) stream gauging stations. The script checks the server's `Last-Modified` header before downloading and skips the download if the local files are already current.

## Latest Discharge

![](pics/20260619_weir_discharge.png 'Discharge for the four weirs at Konza Prairie LTER (N01B, N02B, N04D, and N20B)')

## Overview

`weir_download.R` does three things:

1. **Check** — sends a HEAD request to the server and reads the `Last-Modified` header for the stage image.
2. **Compare** — finds the most recently saved `*_weir_stage.png` in `pics/` and compares its filesystem mtime to the server timestamp.
3. **Download** — only fetches both images (stage and discharge) if the server has newer data, then saves them as dated PNGs (`YYYYMMDD_weir_stage.png` / `YYYYMMDD_weir_discharge.png`) and stamps the files with the server's modification time.

## Dependencies

```r
if (!requireNamespace("pak", quietly = TRUE)) {
  install.packages("pak")
}

pak::pak(c(
  "cli",
  "magick",
  "httr2",
  "lubridate"
))
```

## Usage

```r
source("weir_download.R")
```

Output files are written to `pics/`.
