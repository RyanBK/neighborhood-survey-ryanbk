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

STATE = "MA" # "MA"
COUNTIES = c("Suffolk", "Middlesex", "Norfolk", "Essex", "Plymouth")
TILESET_ID = "massachusetts_september_COUNTIES"
MAPBOX_SECRET_TOKEN = rstudioapi::askForPassword()
MAPBOX_USERNAME = "rbaxterk"

library(tidycensus)
library(tidyverse)
library(sf)
library(spdep)
library(jsonlite)
library(mapboxapi)

# Census variables you wish to include in the tileset
# DO THESE NEED TO BE DROPPED? DO THEY EXIST FOR COUNTY OR JUST BLOCKED?
vars = c(pop="P009001", pop_white="P009005", pop_black="P009006",
         pop_hisp="P009002")

d = get_decennial("county", 
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
tippecanoe(d, mbtile_name, layer_name="counties",
           min_zoom=6, max_zoom=9,
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
write_json(spec, paste0("assets/", TILESET_ID, ".json"))
cat("Specification written.\n")
