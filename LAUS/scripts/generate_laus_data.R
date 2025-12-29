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

input_file_path_for_county_data <- "LAUS/inputs/laucntycur14/laucntycur14.xlsx"
output_file_path_for_tabular_county_data <- "LAUS/outputs/county_unemployment_rates.xlsx"
output_file_path_for_tabular_metro_data <- "LAUS/outputs/metro_unemployment_rates.xlsx"

output_file_path_for_spatial_county_data <- "C:/Users/ianwe/Downloads/ArcGIS projects for github/bls/LAUS/shapefiles/county_unemployment_rates.shp"
output_file_path_for_spatial_metro_data <- "C:/Users/ianwe/Downloads/ArcGIS projects for github/bls/LAUS/shapefiles/metro_unemployment_rates.shp"

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

county_data <- read.xlsx(input_file_path_for_county_data)

names(county_data) <- county_data[1,]
county_data <- county_data[-1,]

county_data <- janitor::clean_names(county_data) %>%
  rename(county_name = county_name_state_abbreviation, unemployment_rate = unemploy_ment_rate_percent,
         month = period) 

county_data <- county_data %>%
  mutate(county_fips_code = paste0(state_fips_code, county_fips_code),
         month = as.Date(paste0("01-", month), format = "%d-%b-%y"),
         unemployment_rate = as.numeric(unemployment_rate),
         employed = as.numeric(employed),
         unemployed = as.numeric(unemployed),
         labor_force = as.numeric(labor_force))

# Join shp files ----

county_data <- county_data %>%
  left_join(county_shp, by = "county_fips_code")

county_data <- county_data %>%
  select(county_name.y, county_name_long, county_fips_code, state, state_fips_code, month, everything()) %>%
  select(-c(county_name.x, laus_code)) %>%
  rename(county_name = county_name.y)

county_data_tabular <- county_data %>%
  select(-geometry)

# Output tabular data ----

write.xlsx(county_data_tabular, output_file_path_for_tabular_metro_data)

# Output spatial data ----

county_data <- county_data %>%
  mutate(month = as.character(month))

arc.check_product()

arc.write(county_data, path = output_file_path_for_spatial_county_data, overwrite = T, validate = T)
