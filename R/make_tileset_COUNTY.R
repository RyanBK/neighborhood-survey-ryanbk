# STATE = "TN" # "MA"
# COUNTIES = "Davidson" # c("Suffolk", "Middlesex", "Norfolk", "Essex", "Plymouth")
# TILESET_ID = "tennessee_september"
# MAPBOX_SECRET_TOKEN = rstudioapi::askForPassword()
# MAPBOX_USERNAME = "rbaxterk"

# STATE = "MA" # "MA"
# COUNTIES = "Middlesex" # c("Suffolk", "Middlesex", "Norfolk", "Essex", "Plymouth")
# TILESET_ID = "middlesex_september"
# MAPBOX_SECRET_TOKEN = rstudioapi::askForPassword()
# MAPBOX_USERNAME = "rbaxterk"

# STATE = "CA" # "MA"
# COUNTIES = "Los Angeles" # c("Suffolk", "Middlesex", "Norfolk", "Essex", "Plymouth")
# TILESET_ID = "los_angeles_september"
# MAPBOX_SECRET_TOKEN = rstudioapi::askForPassword()
# MAPBOX_USERNAME = "rbaxterk"

# STATE = "NY" # "MA"
# COUNTIES = "Kings" # c("Suffolk", "Middlesex", "Norfolk", "Essex", "Plymouth")
# TILESET_ID = "ny_brooklyn_september"
# MAPBOX_SECRET_TOKEN = rstudioapi::askForPassword()
# MAPBOX_USERNAME = "rbaxterk"

STATE = "NV" # "MA"
COUNTIES = "Washoe" # c("Suffolk", "Middlesex", "Norfolk", "Essex", "Plymouth")
TILESET_ID = "nv_washoe_september"
MAPBOX_SECRET_TOKEN = rstudioapi::askForPassword()
MAPBOX_USERNAME = "rbaxterk"

library(tidycensus)
library(tidyverse)
library(sf)
library(spdep)
library(jsonlite)
library(mapboxapi)

# helper: if x is a length-1 vector/list, unwrap to a scalar
unbox1 <- function(x) {
  if (is.list(x) && length(x) == 1) return(unbox1(x[[1]]))
  if (is.atomic(x) && length(x) == 1) return(x)
  x
}

# Census variables you wish to include in the tileset
vars = c(pop="P009001", pop_white="P009005", pop_black="P009006",
         pop_hisp="P009002")

d = get_decennial("block", 
                  year = 2010, # Added, should change to 2020
                  variables=vars, state=STATE, county=COUNTIES,
                  output="wide", geometry=T)
cat("Census data downloaded.\n")

{
  g = poly2nb(d, queen=F)
  ids = d$GEOID
  class(g) = "list"
  names(g) = ids
  g = map(g, ~ ids[.])
  
  write_json(g, paste0("assets/", TILESET_ID, "_graph.json"))
}
cat("Adjacency graph created.\n")

mbtile_name = paste0("R/data/", TILESET_ID, ".mbtiles")
tippecanoe(d, mbtile_name, layer_name="blocks",
           min_zoom=10, max_zoom=12,
           other_options="--coalesce-densest-as-needed --detect-shared-borders --use-attribute-for-id=GEOID")
cat("Vector tiles created.\n")


upload_tiles(input=mbtile_name, access_token=MAPBOX_SECRET_TOKEN,
             username=MAPBOX_USERNAME, tileset_id=TILESET_ID,
             tileset_name=paste0(TILESET_ID, "_z10_z12"), multipart=TRUE)
cat("Tileset uploaded.\n")

# spec = read_json("assets/boston.json", simplifyVector=T) # SHOULD THIS BE CHANGED?
spec = read_json(str_glue("assets/template.json"), simplifyVector=T) # RENAMED boston.json to template.json
spec$units$bounds = matrix(st_bbox(d), nrow=2, byrow=T)
# spec$units$tilesets$source.url = str_glue("mapbox://{MAPBOX_USERNAME}.{TILESET_ID}")
spec$units$tileset$source$url = str_glue("mapbox://{MAPBOX_USERNAME}.{TILESET_ID}")

# Normalize fields the embed expects to be scalars not arrays
spec$units$name                       <- unbox1(spec$units$name)
spec$units$id                         <- unbox1(spec$units$id)
spec$units$idColumn$key               <- unbox1(spec$units$idColumn$key)
spec$units$idColumn$name              <- unbox1(spec$units$idColumn$name)
spec$units$zoomTo                     <- unbox1(spec$units$zoomTo)
spec$units$tileset$type               <- unbox1(spec$units$tileset$type)
spec$units$tileset$source$type        <- unbox1(spec$units$tileset$source$type)
spec$units$tileset$source$url         <- unbox1(spec$units$tileset$source$url)
spec$units$tileset$sourceLayer        <- unbox1(spec$units$tileset$sourceLayer)

# write_json(spec, paste0("assets/", TILESET_ID, ".json"), )

# Create pretty JSON string
json_text <- toJSON(spec, pretty = TRUE, auto_unbox = TRUE)

# Write to file
writeLines(json_text, paste0("assets/", TILESET_ID, ".json"))

cat("Specification written.\n")
