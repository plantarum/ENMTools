#' enmtools.ecospat.bg, Runs an ecospat background/similarity test using enmtool.species objects.
#'
#' @param species.1 An enmtools.species object
#' @param species.2 An enmtools.species object
#' @param env A set of environmental layers
#' @param nreps The number of pseudoreplicates to perform
#' @param layers A vector of length 2 containing the names of the layers to be used.
#' @param test.type Symmetric or asymmetric test.  An asymmetric test is bguivalent to the "one.sided" option in the ecospat documentation, while a symmetric one would be two-sided.
#' @param th.sp Quantile of species densities used as a threshold to exclude low species density values.  See documentation for ecospat.grid.clim.dyn.
#' @param th.env Quantile of environmental densities across studye sites used as threshold to exclude low
#' environmental density values.  See documentation for ecospat.grid.clim.dyn.
#' @param R Resolution of the grid. See documentation for ecospat.grid.clim.dyn.
#'
#' @return results Some results, once I figure out what results to return
#'
#' @keywords niche plot sdm enm
#'
#' @export enmtools.ecospat.bg
#' @export summary.ecospat.bg.test
#' @export print.ecospat.bg.test
#' @export plot.ecospat.bg.test
#'
#' @examples
#' enmtools.ecospat.bg(ahli, allogus)

enmtools.ecospat.bg <- function(species.1, species.2, env, nreps = 99, layers = NULL, test.type = "asymmetric", th.sp=0, th.env=0, R=100, ...){

  species.1 <- check.bg(species.1, env, ...)
  species.2 <- check.bg(species.2, env, ...)

  if(length(names(env)) == 2){
    layers <- names(env)
  }

  ecospat.bg.precheck(species.1, species.2, env, nreps, layers)

  #Grabbing environmental data for species 1 points
  sp1.env <- extract(env, species.1$presence.points)
  sp1.env <- cbind(rep(species.1$species.name, nrow(species.1$presence.points)),
                   species.1$presence.points,
                   sp1.env[complete.cases(sp1.env),])
  colnames(sp1.env) <- c("Species", colnames(species.1$presence.points), layers)

  #Grabbing environmental data for species 1 background points
  sp1.bg.env <- extract(env, species.1$background.points)
  sp1.bg.env <- cbind(rep(paste0(species.1$species.name, ".bg"), nrow(species.1$background.points)),
                      species.1$background.points,
                      sp1.bg.env[complete.cases(sp1.bg.env),])
  colnames(sp1.bg.env) <- c("Species", colnames(species.1$background.points), layers)

  #Grabbing environmental data for species 2 points
  sp2.bg.env <- extract(env, species.2$background.points)
  sp2.bg.env <- cbind(rep(species.2$species.name, nrow(species.2$background.points)),
                      species.2$background.points,
                      sp2.bg.env[complete.cases(sp2.bg.env),])
  colnames(sp2.bg.env) <- c("Species", colnames(species.2$background.points), layers)


  #Grabbing environmental data for species 2 background points
  sp2.env <- extract(env, species.2$presence.points)
  sp2.env <- cbind(rep(paste0(species.2$species.name, ".bg"), nrow(species.2$presence.points)),
                   species.2$presence.points,
                   sp2.env[complete.cases(sp2.env),])
  colnames(sp2.env) <- c("Species", colnames(species.2$presence.points), layers)


  #Extracting background env data at all points for env
  background.env <- as.data.frame(rasterToPoints(env))
  background.env <- cbind(rep("background", length(background.env[,1])), background.env)
  colnames(background.env) <- c("Species", colnames(species.1$presence.points), names(env))
  background.env <- background.env[complete.cases(background.env),]

  sp1.niche <- ecospat.grid.clim.dyn(background.env[,4:5], sp1.bg.env[,4:5], sp1.env[,4:5], th.sp=th.sp, th.env=th.env, R=R)
  sp2.niche <- ecospat.grid.clim.dyn(background.env[,4:5], sp2.bg.env[,4:5], sp2.env[,4:5], th.sp=th.sp, th.env=th.env, R=R)

  if(test.type == "symmetric"){
    one.sided <- FALSE
  } else {
    one.sided <- TRUE
  }

  bg <- ecospat.niche.similarity.test(sp1.niche, sp2.niche, rep=nreps, one.sided = one.sided, ...)

  p.values <- c(bg$p.D, bg$p.I)
  names(p.values) <- c("D", "I")

  d.plot <- qplot(bg$sim[,"D"], geom = "density", fill = "density", alpha = 0.5) +
    geom_vline(xintercept = bg$obs$D, linetype = "longdash") +
    xlim(0,1) + guides(fill = FALSE, alpha = FALSE) + xlab("D") +
    ggtitle(paste("Ecospat background test:", species.1$species.name, "vs.", species.2$species.name))

  i.plot <- qplot(bg$sim[,"I"], geom = "density", fill = "density", alpha = 0.5) +
    geom_vline(xintercept = bg$obs$I, linetype = "longdash") +
    xlim(0,1) + guides(fill = FALSE, alpha = FALSE) + xlab("I") +
    ggtitle(paste("Ecospat background test:", species.1$species.name, "vs.", species.2$species.name))


  sp1.bg.points <- data.frame(rasterToPoints(raster(sp1.niche$Z)))
  colnames(sp1.bg.points) <- c("X", "Y", "Density")
  sp1.bg.plot <-  ggplot(data = sp1.bg.points, aes(y = Y, x = X)) +
    geom_raster(aes(fill = Density)) +
    scale_fill_viridis(option = "B", guide = guide_colourbar(title = "Density")) +
    coord_fixed() + theme_classic() +
    ggtitle(paste(species.1$species.name, "available environment"))

  sp1.env.points <- data.frame(rasterToPoints(raster(sp1.niche$z.uncor)))
  colnames(sp1.env.points) <- c("X", "Y", "Density")
  sp1.env.plot <-  ggplot(data = sp1.env.points, aes(y = Y, x = X)) +
    geom_raster(aes(fill = Density)) +
    scale_fill_viridis(option = "B", guide = guide_colourbar(title = "Density")) +
    coord_fixed() + theme_classic() +
    ggtitle(paste(species.1$species.name, "occurrence in environment space"))

  sp1.env.corr.points <- data.frame(rasterToPoints(raster(sp1.niche$z.cor)))
  colnames(sp1.env.corr.points) <- c("X", "Y", "Density")
  sp1.env.plot.corr <-  ggplot(data = sp1.env.corr.points, aes(y = Y, x = X)) +
    geom_raster(aes(fill = Density)) +
    scale_fill_viridis(option = "B", guide = guide_colourbar(title = "Density")) +
    coord_fixed() + theme_classic() +
    ggtitle(paste(species.1$species.name, "density in environment space, scaled by availability"))

  sp2.bg.points <- data.frame(rasterToPoints(raster(sp2.niche$Z)))
  colnames(sp2.bg.points) <- c("X", "Y", "Density")
  sp2.bg.plot <-  ggplot(data = sp2.bg.points, aes(y = Y, x = X)) +
    geom_raster(aes(fill = Density)) +
    scale_fill_viridis(option = "B", guide = guide_colourbar(title = "Density")) +
    coord_fixed() + theme_classic() +
    ggtitle(paste(species.2$species.name, "available environment"))

  sp2.env.points <- data.frame(rasterToPoints(raster(sp2.niche$z.uncor)))
  colnames(sp2.env.points) <- c("X", "Y", "Density")
  sp2.env.plot <-  ggplot(data = sp2.env.points, aes(y = Y, x = X)) +
    geom_raster(aes(fill = Density)) +
    scale_fill_viridis(option = "B", guide = guide_colourbar(title = "Density")) +
    coord_fixed() + theme_classic() +
    ggtitle(paste(species.2$species.name, "occurrence in environment space"))

  sp2.env.corr.points <- data.frame(rasterToPoints(raster(sp2.niche$z.cor)))
  colnames(sp2.env.corr.points) <- c("X", "Y", "Density")
  sp2.env.plot.corr <-  ggplot(data = sp2.env.corr.points, aes(y = Y, x = X)) +
    geom_raster(aes(fill = Density)) +
    scale_fill_viridis(option = "B", guide = guide_colourbar(title = "Density")) +
    coord_fixed() + theme_classic() +
    ggtitle(paste(species.2$species.name, "density in environment space, scaled by availability"))



#   image(log(chlor$Z), main="Chlorocyanus environment", col=rainbow(10))
#   #points(chlorpoints[,4:5], pch=3)
#   image(log(chlor$z.uncor), main="Chlorocyanus density", col=rainbow(10))
#   #points(chlorpoints[,4:5], pch=3)
#   image(log(chlor$z.cor), main="Chlorocyanus occupancy", col=rainbow(10))
#   points(chlorpoints[,4:5], pch=3)

  output <- list(description = paste("\n\nEcospat background test", test.type, species.1$species.name, "vs.", species.2$species.name),
                 sp1.env = sp1.env,
                 sp2.env = sp2.env,
                 sp1.bg.env = sp1.bg.env,
                 sp2.bg.env = sp2.bg.env,
                 background.env = background.env,
                 sp1.niche = sp1.niche,
                 sp2.niche = sp2.niche,
                 sp1.bg.plot = sp1.bg.plot,
                 sp1.env.plot = sp1.env.plot,
                 sp1.env.plot.corr = sp1.env.plot.corr,
                 sp2.bg.plot = sp2.bg.plot,
                 sp2.env.plot = sp2.env.plot,
                 sp2.env.plot.corr = sp2.env.plot.corr,
                 test.results = bg,
                 p.values = p.values,
                 d.plot = d.plot,
                 i.plot = i.plot)
  class(output) <- "ecospat.bg.test"

  return(output)

}


ecospat.bg.precheck <- function(species.1, species.2, env, nreps, layers){

  if(!inherits(species.1, "enmtools.species")){
    stop("Species.1 is not an enmtools.species object!")
  }

  if(!inherits(species.2, "enmtools.species")){
    stop("Species.2 is not an enmtools.species object!")
  }

  if(!inherits(env, c("raster", "RasterLayer", "RasterStack", "RasterBrick"))){
    stop("Environmental layers are not a RasterLayer or RasterStack object!")
  }

  check.species(species.1)

  if(!inherits(species.1$presence.points, "data.frame")){
    stop("Species 1 presence.points do not appear to be an object of class data.frame")
  }

  if(!inherits(species.1$background.points, "data.frame")){
    stop("Species 1 background.points do not appear to be an object of class data.frame")
  }

  check.species(species.2)

  if(!inherits(species.2$presence.points, "data.frame")){
    stop("Species 2 presence.points do not appear to be an object of class data.frame")
  }

  if(!inherits(species.2$background.points, "data.frame")){
    stop("Species 2 background.points do not appear to be an object of class data.frame")
  }

  if(any(!colnames(species.1$background.points) %in% colnames(species.2$background.points))){
    stop("Column names for species background points do not match!")
  }

  if(any(!colnames(species.1$presence.points) %in% colnames(species.2$presence.points))){
    stop("Column names for species presence points do not match!")
  }

  if(is.na(species.1$species.name)){
    stop("Species 1 does not have a species.name set!")
  }

  if(is.na(species.2$species.name)){
    stop("Species 2 does not have a species.name set!")
  }

  if(is.null(layers)){
    stop("You must provide either a stack containing two layers, or a vector of two layer names to use for overlaps!")
  }

  if(length(layers) != 2){
    stop("You must specify which two layers to use for overlaps!")
  }

}


summary.ecospat.bg.test <- function(id){
  cat(paste("\n\n", id$description))

  print(kable(head(id$sp1.env)))
  print(kable(head(id$sp1.bg.env)))
  print(kable(head(id$sp2.env)))
  print(kable(head(id$sp2.bg.env)))
  print(kable(head(id$background.env)))


  cat("\n\necospat.bg test p-values:\n")
  print(id$p.values)

  plot(id)

}

print.ecospat.bg.test <- function(id){

  print(summary(id))

}

plot.ecospat.bg.test <- function(id){
  grid.arrange(id$d.plot, id$i.plot, nrow = 2)
  grid.arrange(id$sp1.bg.plot, id$sp2.bg.plot,
               id$sp1.env.plot, id$sp2.env.plot,
               id$sp1.env.plot.corr, id$sp2.env.plot.corr, ncol = 2)
}
