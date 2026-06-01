# Load libraries
library(cli)
library(magick)
library(httr2)
library(lubridate)
# Make sure output dir exist
dir.create("pics", showWarnings = FALSE)

# Base URL for the Konza Prairie LTER weir data
# Note: server rejects HTTPS GET requests for these GIFs; HEAD works but GET does not
base_url <- "http://www.konza.ksu.edu/ramps/genomics/weir"

# ── Check Modified Time ─────────────────────────────────────────────────────

#' Get the last modified timestamp for a weir image
#'
#' @param name Character string. The image name without extension ("stage" or "volume")
#' @return A POSIXct datetime object in America/Chicago timezone
#'
#' @details This function:
#'   1. Sends a HEAD request (gets metadata without downloading the file)
#'   2. Extracts the "last-modified" HTTP header
#'   3. Parses the date string (removing weekday prefix like "Tue, ")
#'   4. Converts to GMT then shifts to Central Time
get_last_modified <- function(name) {
  # Construct the full URL (e.g., https://.../weir/stage.gif)
  url <- paste0(base_url, "/", name, ".gif")

  # Send HEAD request to get only response headers, not the file body
  res <- httr2::request(url) |> # Create HTTP request object
    httr2::req_method("HEAD") |> # Change from default GET to HEAD
    httr2::req_perform() # Execute the request

  # Extract and parse the Last-Modified header
  httr2::resp_header(res, "last-modified") |> # Get header value (e.g., "Tue, 25 May 2026 14:30:00 GMT")
    sub("^[A-Za-z]{3}, ", "", x = _) |> # Remove weekday prefix (e.g., "Tue, " → "")
    lubridate::dmy_hms(tz = "GMT") |> # Parse as "day month year hour:min:sec" in GMT
    lubridate::with_tz("America/Chicago") # Convert to Central Time
}

# ── Download ────────────────────────────────────────────────────────────────

#' Download a weir image from the server
#'
#' @param name Character string. The image name without extension ("stage" or "volume")
#' @return A magick image object ready for processing/saving
#'
#' @details Downloads via httr2 then parses
#'   with magick. Using httr2 avoids connection resets that occur when magick's
#'   internal curl fetches directly from this server.
fetch_weir_image <- function(name) {
  url <- paste0(base_url, "/", name, ".gif")
  raw_bytes <- httr2::request(url) |>
    httr2::req_perform() |>
    httr2::resp_body_raw()
  magick::image_read(raw_bytes)
}

# ── Check Whether Download Is Needed ────────────────────────────────────────

modified_time <- get_last_modified("stage")
file_date <- format(modified_time, "%Y%m%d")

# Find the most recently saved stage file to compare against.
# Compare against the date embedded in the filename, not file mtime: git does
# not preserve modification times, so on each Actions checkout every file's
# mtime is reset to "now", which would make the script think it is always
# up to date and never download.
existing_files <- list.files(
  "pics",
  pattern = "_weir_stage\\.png$",
  full.names = FALSE
)

needs_update <- if (length(existing_files) == 0) {
  TRUE
} else {
  latest_date <- max(substr(existing_files, 1, 8))
  file_date > latest_date
}

if (!needs_update) {
  cli::cli_alert_info(
    "Images are up to date (server date: {file_date}). Skipping download."
  )
} else {
  # ── Download ───────────────────────────────────────────────────────────────

  stage_img <- fetch_weir_image("stage")
  discharge_img <- fetch_weir_image("volume")

  # ── Create Output Filenames ────────────────────────────────────────────────

  stage_file <- paste0("pics/", file_date, "_weir_stage.png")
  discharge_file <- paste0("pics/", file_date, "_weir_discharge.png")

  # ── Save ───────────────────────────────────────────────────────────────────

  magick::image_write(stage_img, path = stage_file, format = "png")
  magick::image_write(discharge_img, path = discharge_file, format = "png")

  # ── Set File Times ─────────────────────────────────────────────────────────

  Sys.setFileTime(stage_file, modified_time)
  Sys.setFileTime(discharge_file, modified_time)

  # ── Update README ──────────────────────────────────────────────────────────

  readme <- readLines("README.md")
  readme <- sub(
    "^!\\[\\]\\(pics/.*\\)",
    paste0(
      "![](",
      discharge_file,
      " 'Discharge for the four weirs at Konza Prairie LTER (N01B, N02B, N04D, and N20B)')"
    ),
    readme
  )
  writeLines(readme, "README.md")

  cli::cli_alert_success("Saved {stage_file} and {discharge_file}.")
}
