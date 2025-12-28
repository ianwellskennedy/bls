# Packages ----

# Set the packages to read in
packages <- c("tidyverse", "tidycensus", "sf", "openxlsx", "arcgisbinding", "conflicted", "zoo", "blsAPI", "jsonlite")

# Install packages that are not yet installed
installed_packages <- packages %in% rownames(installed.packages())

if (any(installed_packages == FALSE)) {
  install.packages(packages[!installed_packages])
}

# Load the packages
invisible(lapply(packages, library, character.only = TRUE))

# Remove unneeded variables
rm(packages, installed_packages)

# Prefer certain packages for certain functions
conflicts_prefer(dplyr::filter, dplyr::lag, lubridate::year, base::`||`, base::is.character, base::`&&`, stats::cor, base::as.numeric)

# Setting file paths / environment variables ----

county_shp_file_path <- "C:/Users/ianwe/Downloads/shapefiles/2024/Counties/cb_2024_us_county_5m.shp"
metro_shp_file_path <- "C:/Users/ianwe/Downloads/shapefiles/2024/CBSAs/cb_2024_us_cbsa_5m.shp"

# Reading in shp files ----

county_shp <- st_read(county_shp_file_path)

county_shp <- county_shp %>%
  filter(as.numeric(STATEFP) <= 56) %>%
  select(NAME, NAMELSAD, GEOID, STUSPS) %>%
  rename(county_name = NAME, county_name_long = NAMELSAD, county_fips_code = GEOID, state = STUSPS)

counties <- unique(county_shp$county_fips_code)

metro_shp <- st_read(metro_shp_file_path)

metro_shp <- metro_shp %>%
  select(NAME, NAMELSAD, GEOID) %>%
  rename(metro_name = NAME, metro_name_long = NAMELSAD, metro_fips_code = GEOID)

metros <- unique(metro_shp$metro_fips_code)

# Read in data ----

metro_data_final <- data.frame()

for (county in counties) {
  
  Sys.sleep(0.5)  # 👈 rate limit protection (important)
  
  series_id <- paste0("LAUCN", county, "0000000003")
  
  raw_response <- tryCatch(
    blsAPI(list(
      seriesid  = series_id,
      startyear = "2025",
      endyear   = "2025"
    )),
    error = function(e) return(NULL)
  )
  
  # Skip if request failed
  if (is.null(raw_response)) {
    message("Skipping ", county, ": API call failed")
    next
  }
  
  # Skip if response is NOT JSON (rate limit message)
  if (!startsWith(trimws(raw_response), "{")) {
    message("Skipping ", county, ": rate limit hit")
    next
  }
  
  json_data <- fromJSON(raw_response)
  
  # Skip if no data
  if (is.null(json_data$Results$series[[1]]$data)) {
    message("Skipping ", county, ": no data returned")
    next
  }
  
  data_cleaned <- json_data$Results$series[[1]]$data %>%
    as_tibble() %>%
    rename(month = period) %>%
    mutate(
      month = as.Date(paste0(year, "-", str_remove(month, "^M"), "-01")),
      value = as.numeric(value),
      county_fips_code = county
    ) %>%
    select(month, county_fips_code, value) %>%
    arrange(month)
  
  metro_data_final <- bind_rows(metro_data_final, data_cleaned)
}
