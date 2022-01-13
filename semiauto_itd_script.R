library(lidR)

# path and name of each LAS file
path <- "C:\\Users\\halassiter\\desktop\\las\\"
name <- "t0wg4"

# input LAS file, and plot to inspect
filename <- paste(path, name, ".las", sep="")
las <- readLAS(filename)
plot(las, color="Z")

# generate CHM using pit-free algorithm (Khosravipour et al.)
chm <- grid_canopy(las, 
                   res = 0.1,  # resolution in meters
                   pitfree(thresholds = c(0,2,5,10,15),  #recommended thresholds
                           max_edge = c(0,1),
                           subcircle = 0))

# smooth the canopy height model with a mean filter
kernel <- matrix(1, nrow=9, ncol=9)  # 9x9 works pretty well
chm.smooth <- raster::focal(chm, w=kernel, fun=mean, na.rm=TRUE)

# first, automatic detection of treetops
treetops <- tree_detection(chm.smooth, lmf(1.5, hmin=8, shape="square"))

# next, QA: manual correction of automatic detection results
# the GUI for this is a little tricky, takes some practice
treetops.qa <- tree_detection(las, 
                              manual(detected = treetops,
                                     radius=0.5,
                                     color="red"))

# tree segmentation (Silva et al. 2016)
crowns <- silva2016(chm.smooth,
                    treetops.qa,
                    max_cr_factor = 0.3,
                    exclusion = 0.3,
                    ID = "treeID")

# plot treetop locations over the smoothed CHM
filename <- paste(path, name, "_treetops.png", sep="")
png(filename, width=800, height=800)
plot(chm.smooth)
title(main=name, xlab="Easting [m]", ylab="Northing [m]")
plot(treetops, pch=16, add=TRUE)
plot(treetops.qa, pch=16, add=TRUE, col="red")
dev.off()

# create LAS object segmented with crowns function above
# adds treeID attribute
las2 <- lastrees(las, crowns)

# plot segmented trees to inspect (take a scrrencap here!)
col <- random.colors(100)
plot(las2, color="treeID", colorPalette=col)

# treetops data frame
# (treetop XY location seems to be more accurate than crown hull location)
ttops <- data.frame("treeID" = treetops.qa$treeID, 
                    "Z_smooth" = treetops.qa$Z, 
                    "X" = treetops.qa$X,
                    "Y" = treetops.qa$Y)

# crown hulls data
metric = tree_metrics(las2, .stdtreemetrics)
hulls  = tree_hulls(las2)
hulls@data = dplyr::left_join(hulls@data, metric@data)

# plot hulls, colored by height
filename <- paste(path, name, "_hullsZ.png", sep="")
png(filename, width=800, height=800)
spplot(hulls, 
       "Z", 
       main=list(label=name), 
       xlab="Easting [m]", 
       ylab="Northing [m]")
dev.off()

# plot hulls again, this time colored by crown area
filename <- paste(path, name, "_hullsCA.png", sep="")
png(filename, width=800, height=800)
spplot(hulls, 
       "convhull_area", 
       main=list(label=name), 
       xlab="Easting [m]", 
       ylab="Northing [m]")
dev.off()

# join ttops and hull dataframes for final CSV
hull.data = hulls@data[order(hulls@data$treeID),]
all <- cbind(hull.data, ttops)
filename <- paste(path, name, ".csv", sep="")
write.csv(all, file=filename)
