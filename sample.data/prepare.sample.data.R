require(rgdal)
require(sp)
require(raster)
require(rgeos)  # to perform a union of features on the zones file

message("Loading data from URL")
load(url("https://www.dropbox.com/s/oeol5opggniyhic/ALX_NMTK_Shapes2.RData?dl=1"))
# load("ALX_NMTK_Shapes2.RData")

dir.create("../static/AccessR") # issue warning but not error if directory exists
setwd("../static/AccessR")

# Create an NMTK-friendly CRS equivalent to the source data
output.CRS <- CRS("+init=epsg:4326")

# Dump a couple of spatial files as samples
# Create an NMTK-friendly CRS equivalent to the source data
# Dump a couple of spatial files as samples
message("Writing roads")
alx.network.nice <- spTransform(alx.network.nice,output.CRS)
roadfile <- "SampleRoads.geojson"
unlink(roadfile)
writeOGR(alx.network.nice, roadfile, layer="OGRGeoJSON", driver="GeoJSON")

message("Writing points")
alx.points <- spTransform(alx.stations[c(1,3,5),],output.CRS)
pointfile = "SamplePoints.geojson"
unlink(pointfile)
writeOGR(alx.points, pointfile, layer="OGRGeoJSON", driver="GeoJSON")

# Prepare study area from the zones file and save the vector version
message("Writing study area vector")
lst <- data.frame(access=3)
studyarea <- gUnaryUnion(alx.study.zones)
studyarea <- SpatialPolygonsDataFrame(studyarea,data=lst)
studyarea <- spTransform(studyarea,output.CRS)
studyareafile <- "StudyArea_Vector.geojson"
unlink(studyareafile)
writeOGR(studyarea, studyareafile, "OGRGeoJSON", driver="GeoJSON")

# Prepare the study area and save it as a sample raster
message("Rasterizing study area")
ex <- extent(studyarea)
pixels_x <- 300
pixels_y <- 300
value <- 1.000000

r.study <- raster(ex,pixels_x,pixels_y,crs=output.CRS)
StudyArea <- rasterize(studyarea,r.study,field=value)

# Construct a full accessibility map
# The correct strategy is to use "0" for inaccessible, and then build
# up from there through the better and better layers
Accessibility <- StudyArea

##################################################
# Add Accessibility layers
##################################################

# Ugly Roads (0)
message("Rasterizing ugly roads")
alx.network.ugly <- spTransform(alx.network.ugly,output.CRS)
r.ugly <- rasterize(alx.network.ugly,r.study,field=0.0)
Accessibility <- overlay(Accessibility,r.ugly,fun=function(x,y) pmin(x,y,na.rm=TRUE))

# Buildings (0)
message("Rasterizing buildings")
alx.buildings <- spTransform(alx.buildings,output.CRS)
r.buildings <- rasterize(alx.buildings,r.study,field=0.0,silent=TRUE)
Accessibility <- overlay(Accessibility,r.buildings,fun=function(x,y) pmin(x,y,na.rm=TRUE))

# Nice Roads (increment)
message("Rasterizing nice roads") # already spatially transformed
r.nice <- rasterize(alx.network.nice,r.study,field=2.0)
Accessibility <- overlay(Accessibility,r.nice,fun=function(x,y) pmax(x,y,na.rm=TRUE))

# Bike Facilities (on-road)
message("Rasterizing bike lanes")
alx.bike.lanes <- spTransform(alx.bike.lanes,output.CRS)
r.bikelanes <- rasterize(alx.bike.lanes,r.study,field=3.0)
Accessibility <- overlay(Accessibility,r.bikelanes,fun=function(x,y) pmax(x,y,na.rm=TRUE))

# Bike Trails (off-road)
message("Rasterizing trails")
alx.bike.trails <- spTransform(alx.bike.trails,output.CRS)
r.bikepaths <- rasterize(alx.bike.trails,r.study,field=4.0)
Accessibility <- overlay(Accessibility,r.bikepaths,fun=function(x,y) pmax(x,y,na.rm=TRUE))

# Sidewalks
message("Rasterizing sidewalks - Takes a LONG time!")
value = 4.0
alx.sidewalks <- spTransform(alx.sidewalks,output.CRS)
r.sidewalks <- rasterize(alx.sidewalks,r.study,getCover=TRUE) # field ignored with getCover
r.sidewalks <- calc(r.sidewalks,function(x){ pmin(x,50) * value / 50.0 })
Accessibility <- overlay(Accessibility,r.sidewalks,fun=function(x,y) pmax(x,y,na.rm=TRUE))

# Clip back to study area
Accessibility <- overlay(Accessibility,StudyArea,fun=function(x,y) ifelse(is.na(y),NA,x))

# Save the raster files
message("Writing Study Area raster")
studyarearasterfile <- "StudyArea_Raster.tif"
writeRaster(StudyArea,filename=studyarearasterfile,format="GTiff",overwrite=TRUE)
message("Writing Accessibility raster")
accessibilityrasterfile <- "AccessibilityDemo.tif"

writeRaster(Accessibility,filename=accessibilityrasterfile,format="GTiff",overwrite=TRUE)

# Create a "buggy" raster
message("Writing projected Study Area raster")
projected.raster <- projectRaster(StudyArea,crs=CRS("+init=epsg:26918"))
BuggyFile <- "StudyArea_Projected.tif"
writeRaster(projected.raster,filename=BuggyFile,format="GTiff",overwrite=TRUE)

# Compute sample file checksums
message("Computing checksums")
system("sha1sum *.geojson *.tif > checksums.txt")

# Re-read the output files to ensure they are accessible
message("Rereading output files")
message("Roads...",appendLF=FALSE)
t <- readOGR(roadfile,layer="OGRGeoJSON")
message("Points...",appendLF=FALSE)
t <- readOGR(pointfile,layer="OGRGeoJSON")
message("Study Area Vector...",appendLF=FALSE)
t <- readOGR(studyareafile,layer="OGRGeoJSON")
message("Study Area Raster...",appendLF=FALSE)
t <- raster(studyarearasterfile)
message("Accessibility Raster")
t <- raster(accessibilityrasterfile)
message("Projected Study Area Raster")
t <- raster(BuggyFile)
message("All done.")
